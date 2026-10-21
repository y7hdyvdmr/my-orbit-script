-- ============================================================
--  Rick & Morty Toolkit v4.1 (standalone, один файл)
--  Скины на Motor6D, мимика, движения, портальная пушка,
--  большие порталы, замораживатель времени, ящик Мисиксов (бой),
--  батарея микровселенной, космический крейсер, эффект перехода.
--  Всё создаётся локально: видишь только ты.
-- ============================================================
local G = rawget(_G, "getgenv") and getgenv() or _G
if G.RickMorty and G.RickMorty.unload then pcall(G.RickMorty.unload) end
local RM = { _version = "4.1" }
G.RickMorty = RM

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local V3, RGB = Vector3.new, Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

local conns = {}
local function track(c) conns[#conns + 1] = c return c end

-- общее состояние
local RIG, HOLDING, RIDING, EMOTE = nil, false, false, nil
local ITEM_ACT, heldTool, heldDef, gripW, gripC, batLabel = nil, nil, nil, nil, nil, nil
local PA, PB, tpCd = nil, nil, 0
local ship, helpers, zones = nil, {}, {}
local TIMESTOP_UNTIL, TS_CD, BAT, inZone = 0, 0, 100, false
local rideKeys = { up = false, down = false }
local PORTAL_LIFE = 60
local PORTAL_R = 6 -- радиус портала в стадах (диаметр 12)
local detachHand, attachHand, refreshGrip, board, dismount -- объявлены заранее

local function copy(t)
  local n = {}
  for k, v in pairs(t) do n[k] = v end
  return n
end
local function getChar()
  local ch = LP.Character
  return ch, ch and ch:FindFirstChildOfClass("Humanoid"), ch and ch:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
--  НАСТРОЙКИ (сохраняются в файл, если executor умеет writefile)
-- ============================================================
local HAS_FS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
local FILE = "rickmorty_v41.json"
local ST = {
  SoundEnabled = true, NotificationsEnabled = true, NotifDuration = 2, MenuKey = "RightShift",
  PortalColor = { R = 50, G = 255, B = 50 }, ActiveSkin = "", AimSize = 64, Emotion = "normal", DimFx = true,
}
RM.SETTINGS = ST
local function save()
  if HAS_FS then pcall(writefile, FILE, HttpService:JSONEncode(ST)) end
end
if HAS_FS then
  pcall(function()
    if isfile(FILE) then
      local d = HttpService:JSONDecode(readfile(FILE))
      if type(d) == "table" then
        for k, v in pairs(d) do
          if ST[k] ~= nil then ST[k] = v end
        end
      end
    end
  end)
end

-- ============================================================
--  ЗВУКИ
-- ============================================================
local sfx = Instance.new("Folder")
sfx.Name = "RM_Sfx"
sfx.Parent = SoundService
local SFX = {
  shoot = "rbxassetid://12221967", click = "rbxasset://sounds/button.wav",
  notify = "rbxasset://sounds/electronicpingshort.wav", teleport = "rbxassetid://3314038600",
}
local function snd(name, vol, pitch)
  if not ST.SoundEnabled or not SFX[name] then return end
  pcall(function()
    local s = Instance.new("Sound")
    s.SoundId = SFX[name]
    s.Volume = vol or .5
    s.PlaybackSpeed = pitch or 1
    s.Parent = sfx
    s:Play()
    task.delay(4, function() s:Destroy() end)
  end)
end

-- ============================================================
--  UI: ХЕЛПЕРЫ И ЦВЕТА
-- ============================================================
local C = {
  bg = RGB(18, 14, 28), bg2 = RGB(28, 22, 42), ac = RGB(100, 255, 140), ac2 = RGB(150, 90, 255),
  ac3 = RGB(120, 220, 255), tx = RGB(240, 235, 255), dim = RGB(150, 140, 180),
  dg = RGB(255, 100, 120), ok = RGB(120, 255, 160), st = RGB(120, 90, 220),
}
local function I(class, props, parent)
  local o = Instance.new(class)
  for k, v in pairs(props) do o[k] = v end
  o.Parent = parent
  return o
end
local function cr(o, r) return I("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function sk(o, col, th, tr) return I("UIStroke", { Color = col, Thickness = th, Transparency = tr }, o) end

local function safeParent()
  local f = rawget(G, "gethui")
  if type(f) == "function" then
    local ok, h = pcall(f)
    if ok and h then return h end
  end
  local ok, cg = pcall(function() return game:GetService("CoreGui") end)
  if ok and cg then return cg end
  return PlayerGui
end

local gui = I("ScreenGui", {
  Name = "_RM_" .. math.random(100000, 999999), ResetOnSpawn = false, IgnoreGuiInset = true,
  DisplayOrder = 65, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
do
  local sy = rawget(G, "syn")
  if type(sy) == "table" and type(sy.protect_gui) == "function" then
    pcall(sy.protect_gui, gui)
  elseif type(rawget(G, "protect_gui")) == "function" then
    pcall(G.protect_gui, gui)
  end
end
if not pcall(function() gui.Parent = safeParent() end) or not gui.Parent then gui.Parent = PlayerGui end

-- перетаскивание (мышь и палец)
local function drag(frame, area)
  area = area or frame
  local dragging, dStart, sPos, dInput = false, nil, nil, nil
  area.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      dStart = i.Position
      sPos = frame.Position
      i.Changed:Connect(function()
        if i.UserInputState == Enum.UserInputState.End then dragging = false end
      end)
    end
  end)
  area.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
      dInput = i
    end
  end)
  track(UIS.InputChanged:Connect(function(i)
    if i == dInput and dragging then
      local d = i.Position - dStart
      frame.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
    end
  end))
end

-- уведомления
local nh = I("Frame", {
  Size = UDim2.fromOffset(260, 300), Position = UDim2.new(1, -280, 1, -320),
  BackgroundTransparency = 1, ZIndex = 60,
}, gui)
I("UIListLayout", {
  VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
  Padding = UDim.new(0, 4),
}, nh)
local function notify(text, col, dur)
  if not ST.NotificationsEnabled then return end
  col = col or C.ok
  dur = dur or ST.NotifDuration
  local ch = nh:GetChildren()
  if #ch > 9 then ch[2]:Destroy() end
  local f = I("Frame", {
    Size = UDim2.fromOffset(250, 32), BackgroundColor3 = C.bg, BackgroundTransparency = .1, ZIndex = 61,
  }, nh)
  cr(f, 8)
  sk(f, col, 1.5, .2)
  I("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
    Text = tostring(text), TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 62,
  }, f)
  snd("notify", .4)
  task.delay(dur, function() if f.Parent then f:Destroy() end end)
end
RM.notify = notify

local function safe(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    warn("[RickMorty] " .. tostring(err))
    notify("⚠ " .. tostring(err):sub(1, 70), C.dg, 4)
  end
  return ok
end

-- ============================================================
--  ОКНО, ВКЛАДКИ
-- ============================================================
local mainBtn = I("TextButton", {
  Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(20, 120), BackgroundColor3 = C.bg,
  BackgroundTransparency = .05, TextColor3 = C.ac, Font = Enum.Font.GothamBold, TextSize = 30,
  Text = "🌀", AutoButtonColor = false, ZIndex = 50,
}, gui)
cr(mainBtn, 16)
drag(mainBtn)
do
  local s = sk(mainBtn, C.ac, 2, .2)
  I("UIGradient", {
    Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, C.ac), ColorSequenceKeypoint.new(.5, C.ac3), ColorSequenceKeypoint.new(1, C.ac2),
    }), Rotation = 45,
  }, s)
end

local vp = Workspace.CurrentCamera.ViewportSize
local WW, WH = math.min(380, vp.X - 20), math.min(520, vp.Y - 30)
local win = I("Frame", {
  Size = UDim2.fromOffset(WW, WH), Position = UDim2.fromOffset((vp.X - WW) / 2, 15), BackgroundColor3 = C.bg,
  BackgroundTransparency = .02, Visible = false, ZIndex = 40,
}, gui)
cr(win, 16)
sk(win, C.st, 1.5, .25)
I("UIGradient", { Color = ColorSequence.new(C.bg2, C.bg), Rotation = 90 }, win)

local header = I("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 41 }, win)
drag(win, header)
I("TextLabel", {
  Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1,
  Text = "🌀 RICK & MORTY v" .. RM._version, TextColor3 = C.ac, Font = Enum.Font.GothamBold, TextSize = 14,
  TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42,
}, header)
local closeBtn = I("TextButton", {
  Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0, 7), BackgroundColor3 = C.dg,
  BackgroundTransparency = .5, TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 14, Text = "✕", ZIndex = 42,
}, header)
cr(closeBtn, 8)
closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)
mainBtn.MouseButton1Click:Connect(function() win.Visible = not win.Visible end)

-- панель вкладок с горизонтальной прокруткой
local tabsBar = I("ScrollingFrame", {
  Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 48), BackgroundTransparency = 1,
  ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
  ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 41,
}, win)
I("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, tabsBar)
local content = I("ScrollingFrame", {
  Size = UDim2.new(1, -16, 1, -120), Position = UDim2.fromOffset(8, 90), BackgroundTransparency = 1,
  ScrollBarThickness = 3, ScrollBarImageColor3 = C.ac, CanvasSize = UDim2.new(),
  AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 41,
}, win)
I("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
I("TextLabel", {
  Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -22), BackgroundTransparency = 1,
  Text = "v" .. RM._version .. " | скины | предметы | порталы", TextColor3 = C.dim, Font = Enum.Font.Code,
  TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
}, win)

local function newBtn(parent, text, col, fn, h)
  local b = I("TextButton", {
    Size = UDim2.new(1, -8, 0, h or 36), BackgroundColor3 = col or C.bg2, BackgroundTransparency = .1,
    TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 12, Text = text, TextWrapped = true, ZIndex = 42,
  }, parent)
  cr(b, 8)
  sk(b, C.st, 1, .7)
  if fn then
    b.MouseButton1Click:Connect(function()
      snd("click", .3)
      safe(fn)
    end)
  end
  return b
end
local function newSec(parent, text)
  return I("TextLabel", {
    Size = UDim2.new(1, -8, 0, 22), BackgroundTransparency = 1, Text = "▸ " .. text, TextColor3 = C.ac3,
    Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42,
  }, parent)
end
local function newInfo(parent, text, h)
  local l = I("TextLabel", {
    Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = C.bg2, BackgroundTransparency = .2, Text = text,
    TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true, ZIndex = 42,
  }, parent)
  cr(l, 8)
  return l
end
local function newGrid(parent, cols)
  local g = I("Frame", {
    Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 41,
  }, parent)
  I("UIGridLayout", {
    CellSize = UDim2.new(1 / cols, -4, 0, 34), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder,
  }, g)
  return g
end

local TABS = {
  { "skins", "🎭 СКИНЫ", 84 }, { "moves", "🕺 ДВИЖЕНИЯ", 100 }, { "items", "🧰 ПРЕДМЕТЫ", 100 },
  { "portal", "🌀 ПОРТАЛ", 84 }, { "settings", "⚙️", 40 },
}
local tabBtns, tabFrames = {}, {}
local function switchTab(id)
  for k, f in pairs(tabFrames) do f.Visible = (k == id) end
  for k, b in pairs(tabBtns) do
    local on = (k == id)
    b.BackgroundColor3 = on and C.ac or C.bg2
    b.TextColor3 = on and C.bg or C.tx
    b.BackgroundTransparency = on and 0 or .2
  end
  content.CanvasPosition = Vector2.zero
end
for _, t in ipairs(TABS) do
  local b = I("TextButton", {
    Size = UDim2.fromOffset(t[3], 32), BackgroundColor3 = C.bg2, BackgroundTransparency = .2, TextColor3 = C.tx,
    Font = Enum.Font.GothamBold, TextSize = 10, Text = t[2], ZIndex = 42,
  }, tabsBar)
  cr(b, 8)
  tabBtns[t[1]] = b
  b.MouseButton1Click:Connect(function() snd("click", .3) switchTab(t[1]) end)
  local f = I("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    Visible = false, ZIndex = 41,
  }, content)
  I("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
  tabFrames[t[1]] = f
end
track(UIS.InputBegan:Connect(function(i, gpe)
  if not gpe and i.KeyCode.Name == ST.MenuKey then win.Visible = not win.Visible end
end))

-- ============================================================
--  ПРИЦЕЛ
-- ============================================================
local mob = UIS.TouchEnabled and not UIS.MouseEnabled
local aimF, aimL, aimE, cross
local function screenPoint()
  if mob then return cross or Workspace.CurrentCamera.ViewportSize / 2 end
  return UIS:GetMouseLocation()
end
function RM.getAimDirection()
  local p = screenPoint()
  local r = Workspace.CurrentCamera:ViewportPointToRay(p.X, p.Y)
  return r.Direction, r.Origin
end
local function mkAim()
  local z, col = ST.AimSize, C.ac
  aimF = I("Frame", {
    Name = "RM_Aim", Size = UDim2.fromOffset(z, z), AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1, Active = mob, ZIndex = 55,
  }, gui)
  local ring = I("Frame", {
    Size = UDim2.fromScale(.8, .8), Position = UDim2.fromScale(.5, .5), AnchorPoint = Vector2.new(.5, .5),
    BackgroundTransparency = 1, ZIndex = 55,
  }, aimF)
  cr(ring, 999)
  aimE = { sk(ring, col, 1.5, .5) }
  local function box(size, pos)
    local f = I("Frame", {
      Size = size, Position = pos, AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = col,
      BorderSizePixel = 0, ZIndex = 56,
    }, aimF)
    aimE[#aimE + 1] = f
    return f
  end
  cr(box(UDim2.fromOffset(4, 4), UDim2.fromScale(.5, .5)), 99)
  box(UDim2.new(0, 2, .19, 0), UDim2.fromScale(.5, .28))
  box(UDim2.new(0, 2, .19, 0), UDim2.fromScale(.5, .72))
  box(UDim2.new(.19, 0, 0, 2), UDim2.fromScale(.28, .5))
  box(UDim2.new(.19, 0, 0, 2), UDim2.fromScale(.72, .5))
  aimL = I("TextLabel", {
    Size = UDim2.fromOffset(150, 20), Position = UDim2.fromScale(.5, 1.25), AnchorPoint = Vector2.new(.5, 0),
    BackgroundTransparency = 1, TextColor3 = col, Font = Enum.Font.Code, TextSize = 12, Text = "0 st", ZIndex = 57,
  }, aimF)
  local dg = false
  aimF.InputBegan:Connect(function(i)
    if mob and i.UserInputType == Enum.UserInputType.Touch then dg = true end
  end)
  track(UIS.InputChanged:Connect(function(i)
    if dg and i.UserInputType == Enum.UserInputType.Touch then cross = i.Position end
  end))
  track(UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then dg = false end
  end))
  if mob then
    local fb = I("TextButton", {
      Name = "RM_Fire", Size = UDim2.fromOffset(70, 70), Position = UDim2.new(1, -90, 1, -130),
      BackgroundColor3 = RGB(255, 60, 80), BackgroundTransparency = .2, Text = "🔥", TextColor3 = WHITE,
      Font = Enum.Font.GothamBold, TextSize = 35, ZIndex = 55,
    }, gui)
    cr(fb, 99)
    sk(fb, col, 2, .3)
    drag(fb)
    fb.MouseButton1Click:Connect(function()
      if RM.fireFromAim then safe(RM.fireFromAim) end
      fb.Size = UDim2.fromOffset(60, 60)
      task.delay(.1, function() fb.Size = UDim2.fromOffset(70, 70) end)
    end)
  end
end
mkAim()
do
  local acc = 0
  track(RunService.RenderStepped:Connect(function(dt)
    if not aimF then return end
    local p = screenPoint()
    aimF.Position = UDim2.fromOffset(p.X, p.Y)
    acc = acc + dt
    if acc < .1 then return end
    acc = 0
    local ch, _, hr = getChar()
    if not hr then return end
    local r = Workspace.CurrentCamera:ViewportPointToRay(p.X, p.Y)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { ch }
    local res = Workspace:Raycast(r.Origin, r.Direction * 1000, rp)
    local tp = res and res.Position or r.Origin + r.Direction * 1000
    aimL.Text = math.floor((tp - hr.Position).Magnitude) .. " st"
    local m = res and res.Instance:FindFirstAncestorOfClass("Model")
    local hit = m and Players:GetPlayerFromCharacter(m)
    local col = hit and RGB(255, 80, 80) or C.ac
    aimL.TextColor3 = col
    for _, e in ipairs(aimE) do
      if e:IsA("UIStroke") then e.Color = col else e.BackgroundColor3 = col end
    end
  end))
end

-- ============================================================
--  ЭФФЕКТЫ
-- ============================================================
local function pcol()
  local c = ST.PortalColor
  return RGB(c.R, c.G, c.B)
end
local function burst(pos, col, count)
  local p = I("Part", {
    Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
    Size = V3(.2, .2, .2), Position = pos,
  }, Workspace)
  local e = I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0, Lifetime = NumberRange.new(.3, .7),
    Speed = NumberRange.new(8, 20), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(1.2, 0),
    LightEmission = 1, Color = ColorSequence.new(col),
  }, p)
  e:Emit(count or 24)
  task.delay(1.2, function() p:Destroy() end)
end

local ccFx, fovBusy = nil, false
local function flicker(R)
  if not R then return end
  task.spawn(function()
    for i = 1, 6 do
      local on = (i % 2 == 0)
      for _, p in ipairs(R.all) do
        if p.Parent then p.Transparency = on and 0 or .85 end
      end
      task.wait(.05)
    end
  end)
end
local function dimFx(col, power)
  if not ST.DimFx then return end
  power = power or 1
  col = col or pcol()
  if not ccFx or not ccFx.Parent then ccFx = I("ColorCorrectionEffect", { Name = "RM_DimFx" }, Lighting) end
  TweenService:Create(ccFx, TweenInfo.new(.15), {
    TintColor = col:Lerp(WHITE, .35), Saturation = 1.2 * power, Contrast = .35 * power, Brightness = .12 * power,
  }):Play()
  task.delay(.18, function()
    if ccFx and ccFx.Parent then
      TweenService:Create(ccFx, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TintColor = WHITE, Saturation = 0, Contrast = 0, Brightness = 0,
      }):Play()
    end
  end)
  local fl = I("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = col:Lerp(WHITE, .6), BackgroundTransparency = .35,
    BorderSizePixel = 0, ZIndex = 90,
  }, gui)
  TweenService:Create(fl, TweenInfo.new(.6), { BackgroundTransparency = 1 }):Play()
  task.delay(.7, function() fl:Destroy() end)
  for i = 1, 3 do
    task.delay((i - 1) * .09, function()
      local r = I("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1, ZIndex = 91,
      }, gui)
      cr(r, 999)
      local s = sk(r, col:Lerp(WHITE, i * .15), 4, 0)
      TweenService:Create(r, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(1800, 1800),
      }):Play()
      TweenService:Create(s, TweenInfo.new(.7), { Transparency = 1 }):Play()
      task.delay(.8, function() r:Destroy() end)
    end)
  end
  local camObj = Workspace.CurrentCamera
  if camObj and not fovBusy then
    fovBusy = true
    local base = camObj.FieldOfView
    TweenService:Create(camObj, TweenInfo.new(.12), { FieldOfView = base + 18 }):Play()
    task.delay(.14, function()
      TweenService:Create(camObj, TweenInfo.new(.55, Enum.EasingStyle.Quad), { FieldOfView = base }):Play()
    end)
    task.delay(.8, function() fovBusy = false end)
  end
  flicker(RIG)
end
RM.dimFx = dimFx

local function bubble(adornee, text, secs)
  if not adornee or not adornee.Parent then return end
  local old = adornee:FindFirstChild("RM_Bubble")
  if old then old:Destroy() end
  local bb = I("BillboardGui", {
    Name = "RM_Bubble", Size = UDim2.fromOffset(190, 44), StudsOffset = V3(0, 2.6, 0), AlwaysOnTop = true,
    LightInfluence = 0, MaxDistance = 90,
  }, adornee)
  local f = I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(250, 250, 255), BackgroundTransparency = .05 }, bb)
  cr(f, 10)
  sk(f, RGB(30, 30, 40), 2, 0)
  I("TextLabel", {
    Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), BackgroundTransparency = 1, Text = text,
    TextColor3 = RGB(25, 25, 35), Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true,
  }, f)
  task.delay(secs or 3, function() if bb.Parent then bb:Destroy() end end)
end

-- ============================================================
--  ДЕТАЛИ, СУСТАВЫ
-- ============================================================
local function mkp(name, size, color, material, shape)
  local p = Instance.new("Part")
  if shape then p.Shape = shape end
  p.Name = name
  p.Size = size
  p.Color = color
  p.Material = material or Enum.Material.SmoothPlastic
  p.CanCollide = false
  p.CanQuery = false
  p.CanTouch = false
  p.CastShadow = false
  p.Massless = true
  p.TopSurface = Enum.SurfaceType.Smooth
  p.BottomSurface = Enum.SurfaceType.Smooth
  return p
end
local function motor(a, b, c0, c1)
  c1 = c1 or CFrame.identity
  local m = Instance.new("Motor6D")
  m.Part0 = a
  m.Part1 = b
  m.C0 = c0
  m.C1 = c1
  b.CFrame = a.CFrame * c0 * c1:Inverse()
  m.Parent = b
  return m
end

-- ============================================================
--  СКИНЫ: данные
-- ============================================================
local SK = {
  rick = {
    name = "Рик Санчес", ico = "🧪", desc = "Халат со складками, шипы, зубы, пальцы",
    skin = RGB(190, 180, 180), hair = RGB(165, 205, 240), shirt = RGB(150, 215, 205), coat = RGB(245, 245, 248),
    fold = RGB(208, 210, 222), up = RGB(245, 245, 248), fo = RGB(245, 245, 248), cuff = RGB(150, 215, 205),
    pants = RGB(108, 96, 50), shoe = RGB(78, 83, 92), sock = RGB(245, 245, 245), belt = RGB(60, 45, 30),
    buckle = RGB(235, 190, 40), hs = V3(1.4, 1.5, 1.25), ey = .15, ex = .3, er = .52, pr = .1, nl = .4, ny = -.05,
    open = true, brow = .3, hstyle = "spikes",
  },
  morty = {
    name = "Морти Смит", ico = "😰", desc = "Жёлтая футболка, большие глаза",
    skin = RGB(238, 196, 156), hair = RGB(125, 85, 52), shirt = RGB(236, 226, 98), up = RGB(236, 226, 98),
    fo = RGB(238, 196, 156), pants = RGB(48, 66, 112), shoe = RGB(240, 240, 240), hs = V3(1.6, 1.65, 1.4),
    ey = .05, ex = .33, er = .64, pr = .13, nl = .18, ny = -.2, hstyle = "morty",
  },
  rick_prime = {
    name = "Рик Прайм", ico = "💀", desc = "Куртка, полоски, ботинки, кобура",
    skin = RGB(205, 195, 200), hair = RGB(165, 205, 240), shirt = RGB(112, 102, 148), jacket = true,
    pad = RGB(160, 170, 200), stripe = RGB(225, 50, 95), up = RGB(48, 48, 78), fo = RGB(48, 48, 78),
    cuff = RGB(112, 102, 148), pants = RGB(34, 34, 56), shoe = RGB(82, 88, 118), belt = RGB(70, 72, 100),
    holster = true, boot = true, hs = V3(1.4, 1.5, 1.25), ey = .15, ex = .3, er = .55, pr = .11, nl = .35,
    ny = -.05, open = true, brow = .1, hstyle = "spikes",
  },
  jerry = {
    name = "Джерри Смит", ico = "🙂", desc = "Голубая рубашка, добрые глаза",
    skin = RGB(238, 200, 170), hair = RGB(110, 80, 55), shirt = RGB(120, 170, 215), up = RGB(120, 170, 215),
    fo = RGB(120, 170, 215), pants = RGB(135, 120, 90), shoe = RGB(70, 60, 50), hs = V3(1.5, 1.6, 1.35),
    ey = .08, ex = .32, er = .5, pr = .1, nl = .32, ny = -.15, hstyle = "morty", brow = .05,
  },
  summer = {
    name = "Саммер Смит", ico = "🧡", desc = "Рыжие длинные волосы, светлый топ",
    skin = RGB(240, 200, 170), hair = RGB(215, 105, 55), shirt = RGB(245, 225, 235), up = RGB(245, 225, 235),
    fo = RGB(240, 200, 170), pants = RGB(60, 90, 150), shoe = RGB(240, 240, 240), hs = V3(1.5, 1.6, 1.35),
    ey = .08, ex = .32, er = .56, pr = .11, nl = .16, ny = -.2, hstyle = "morty", longhair = true,
  },
  meeseeks = {
    name = "Мистер Мисикс", ico = "🟦", desc = "Голубой, лысый, огромная улыбка",
    skin = RGB(120, 190, 235), hair = RGB(90, 150, 200), shirt = RGB(120, 190, 235), up = RGB(120, 190, 235),
    fo = RGB(120, 190, 235), pants = RGB(60, 120, 180), shoe = RGB(100, 170, 220), hs = V3(1.5, 1.6, 1.3),
    ey = .2, ex = .32, er = .62, pr = .12, nl = .14, ny = -.15, open = true, hstyle = "none", brow = .05,
  },
  pickle = {
    name = "Огурчик Рик", ico = "🥒", desc = "Зелёный Рик с бородавками",
    skin = RGB(120, 165, 60), hair = RGB(80, 125, 45), shirt = RGB(105, 150, 52), up = RGB(105, 150, 52),
    fo = RGB(105, 150, 52), pants = RGB(95, 140, 48), shoe = RGB(80, 120, 40), hs = V3(1.4, 1.5, 1.25),
    ey = .15, ex = .3, er = .52, pr = .1, nl = .4, ny = -.05, open = true, brow = .45, hstyle = "none",
    warts = true, wart = RGB(70, 105, 35),
  },
}
SK.evil_morty = copy(SK.morty)
SK.evil_morty.name = "Злой Морти"
SK.evil_morty.ico = "🖤"
SK.evil_morty.desc = "Повязка, руки в боки"
SK.evil_morty.patch = true
SK.evil_morty.hips = true
SK.evil_morty.brow = .2
local SKIN_ORDER = { "rick", "morty", "evil_morty", "rick_prime", "jerry", "summer", "meeseeks", "pickle" }

local EM = {
  { "normal", "😐 Обычный", {} },
  { "happy", "😄 Весёлый", { eh = .85, by = .05, br = -.12, mw = 1.35, mo = .3, cr = .6, cy = .08, te = 1, tg = 0, hx = -.05 } },
  { "sad", "😢 Грустный", { eh = .85, by = .04, br = -.55, mw = .75, mo = .02, cr = -.55, cy = -.07, te = 0, tg = 0, py = -.05, tr = 1, hx = .18, hz = .06 } },
  { "angry", "😡 Злой", { eh = .65, by = -.09, br = .75, mw = 1.1, mo = .16, cr = -.35, cy = -.04, te = 1, tg = 0, hx = .1 } },
  { "surprised", "😲 Удивлён", { eh = 1.35, pr = .6, by = .2, br = 0, mw = .6, mo = .5, cr = 0, te = 0, tg = 0, hx = -.08 } },
  { "scared", "😱 Испуган", { eh = 1.3, pr = .55, by = .16, br = -.45, mw = 1, mo = .22, cr = -.2, te = 1, tg = 0, sh = 1 } },
  { "crazy", "🤪 Псих", { eh = 1.4, pr = .5, by = .1, br = .3, bq = .12, mw = 1.4, mo = .4, cr = .5, cy = .05, te = 1, tg = 1, px = .1, hz = .12 } },
  { "sleepy", "😴 Сонный", { eh = .22, by = -.05, br = -.1, mw = .6, mo = .08, cr = -.05, te = 0, tg = 0, hx = .25, hz = .1 } },
  { "smirk", "😏 Хитрый", { eh = .85, br = .25, bq = .1, mw = .9, mo = .02, cr = .45, cs = .09, te = 0, tg = 0, hz = -.08 } },
  { "derp", "🥴 Пьяный", { eh = .6, pr = .8, by = -.02, br = -.15, bq = .1, mw = 1.1, mo = .18, cr = .1, cs = -.07, te = 0, tg = 1, px = .05, py = .03, hz = .15 } },
  { "wink", "😉 Подмигнуть", { mw = 1.1, mo = .02, cr = .5, cy = .04, te = 0, tg = 0, wk = 1, hz = -.05 } },
  { "grimace", "😬 Оскал", { eh = 1.1, br = .1, mw = 1.5, mo = .14, cr = -.05, te = 1, tg = 0 } },
}
local function dflt(S)
  return {
    eh = 1, pr = 1, by = 0, br = S.brow or 0, mw = 1, mo = S.open and .3 or .02, cr = S.open and .15 or 0,
    cy = 0, cs = 0, bq = 0, te = S.open and 1 or 0, tg = S.open and 1 or 0, tr = 0, px = 0, py = 0,
    sh = 0, wk = 0, hx = 0, hz = 0, w = S.open and .62 or .34,
  }
end
local function ftar(S, id)
  local t = dflt(S)
  for _, e in ipairs(EM) do
    if e[1] == id then
      for k, v in pairs(e[3]) do t[k] = v end
    end
  end
  return t
end

-- ============================================================
--  РИГ: сборка скелета на Motor6D
-- ============================================================
local function newRig(root, S, K)
  local R = {
    S = S, K = K, root = root, mot = {}, base = {}, fp = {}, all = {}, st = {}, lz = {}, parts = {},
    t = 0, ph = 0, nextBlink = 2, blinkEnd = 0,
  }
  local model = Instance.new("Model")
  model.Name = "RM_Rig"
  R.model = model
  local mot, base = R.mot, R.base
  local function kcf(o)
    if typeof(o) == "Vector3" then return CFrame.new(o * K) end
    return CFrame.new(o.Position * K) * o.Rotation
  end
  local function part(n, sz, col, mat, shape)
    local p = mkp(n, sz * K, col, mat, shape)
    p.Parent = model
    R.all[#R.all + 1] = p
    return p
  end
  local function fixed(par, n, sz, col, o, mat, shape)
    local p = part(n, sz, col, mat, shape)
    motor(par, p, kcf(o))
    return p
  end
  local function face(n, par, sz, col, o, mat, shape)
    local p = part(n, sz, col, mat, shape)
    local m = motor(par, p, kcf(o))
    mot[n] = m
    base[n] = m.C0
    R.fp[n] = p
    return p
  end
  local function limb(par, n, sz, col, o, mat, zo)
    local p = part(n, sz, col, mat)
    local m = motor(par, p, kcf(o), CFrame.new(0, sz.Y / 2 * K, (zo or 0) * K))
    mot[n] = m
    base[n] = m.C0
    return p
  end

  local sc, hs = S.skin, S.hs
  local T = part("Torso", V3(1.8, 2, .9), S.shirt)
  mot.Torso = motor(root, T, kcf(V3(0, -.6, 0)), CFrame.new(0, -K, 0))
  base.Torso = mot.Torso.C0
  R.parts.Torso = T
  if S.belt then
    fixed(T, "Belt", V3(1.86, .22, .96), S.belt, V3(0, -.88, 0))
    fixed(T, "Buckle", V3(.3, .2, .05), S.buckle or S.belt, V3(0, -.88, -.5))
  end
  fixed(T, "Neck", V3(.5, .3, .5), sc, V3(0, 1.05, 0))
  if S.warts then
    for i = 1, 6 do
      local a = i * 2.1
      fixed(T, "Wart", V3(.2, .2, .14), S.wart or sc, V3(math.sin(a) * .7, math.cos(a * 1.7) * .8, -.46))
    end
  end

  local H = part("Head", hs, sc)
  mot.Head = motor(T, H, kcf(V3(0, 1, 0)), CFrame.new(0, -hs.Y / 2 * K, 0))
  base.Head = mot.Head.C0
  R.parts.Head = H
  local fz = -hs.Z / 2
  for _, s in ipairs({ -1, 1 }) do
    local n = s < 0 and "L" or "R"
    face("fE" .. n, H, V3(.08, S.er, S.er), RGB(255, 255, 255),
      CFrame.new(s * S.ex, S.ey, fz - .02) * CFrame.Angles(0, math.rad(90), 0), nil, Enum.PartType.Cylinder)
    face("fP" .. n, H, V3(1, 1, 1) * S.pr, RGB(0, 0, 0), V3(s * S.ex - s * .05, S.ey, fz - .08), nil, Enum.PartType.Ball)
    face("fB" .. n, H, V3(S.ex * 1.4, .1, .1), S.hair, V3(s * S.ex, S.ey + S.er / 2 + .12, fz - .03))
    face("fT" .. n, H, V3(.09, .13, .06), RGB(130, 205, 255), V3(s * S.ex, S.ey - S.er / 2, fz - .06), nil,
      Enum.PartType.Ball).Transparency = 1
    fixed(H, "Ear", V3(.14, .42, .28), sc, V3(s * (hs.X / 2 + .04), -.05, .05))
  end
  fixed(H, "Nose", V3(.16, S.nl, .2), sc, V3(0, S.ny, fz - .08))
  local my = S.open and -.42 or -.45
  local mcol = S.open and RGB(90, 20, 25) or RGB(110, 50, 50)
  face("fMC", H, V3(.3, .1, .05), mcol, V3(0, my, fz - .02))
  face("fML", H, V3(.2, .09, .05), mcol, V3(-.15, my, fz - .025))
  face("fMR", H, V3(.2, .09, .05), mcol, V3(.15, my, fz - .025))
  face("fTe", H, V3(.4, .08, .05), S.open and RGB(215, 200, 120) or RGB(240, 240, 235), V3(0, my, fz - .05))
  face("fTg", H, V3(.22, .1, .05), RGB(220, 70, 90), V3(.08, my, fz - .05))

  local hst = S.hstyle or "morty"
  if hst == "spikes" then
    for i = 0, 12 do
      local a = math.rad(-120 + i * 20)
      local big = (i % 2 == 0)
      local d = V3(math.sin(a), 0, math.cos(a))
      local p = d * V3(hs.X * .42, 0, hs.Z * .42) + V3(0, hs.Y * (big and .36 or .1), 0)
      local u = (d * (big and .5 or 1.1) + V3(0, big and 1 or .45, 0)).Unit
      local L = (big and 1 or .8) + .2 * math.sin(i * 2.3)
      fixed(H, "Hair", V3(.3, .3, L), S.hair, CFrame.lookAt(p, p + u) * CFrame.new(0, 0, -L / 2))
    end
    for _, x in ipairs({ -.35, 0, .35 }) do
      local p = V3(x, hs.Y * .45, .15)
      local u = V3(x * 1.4, 1, .1).Unit
      fixed(H, "Hair", V3(.3, .3, .8), S.hair, CFrame.lookAt(p, p + u) * CFrame.new(0, 0, -.4))
    end
  elseif hst == "morty" then
    local back = S.longhair and 1.7 or .9
    local sideL = S.longhair and 1.3 or .5
    fixed(H, "Hair", V3(hs.X + .1, .42, hs.Z + .1), S.hair, V3(0, hs.Y / 2 - .12, .04))
    fixed(H, "Fringe", V3(hs.X + .1, .22, .3), S.hair, V3(0, hs.Y / 2 - .2, fz + .1))
    fixed(H, "HairB", V3(hs.X + .1, back, .25), S.hair, V3(0, hs.Y / 2 - back / 2 - .1, hs.Z / 2))
    for _, s in ipairs({ -1, 1 }) do
      fixed(H, "Sideburn", V3(.12, sideL, .45), S.hair, V3(s * (hs.X / 2 + .03), hs.Y / 2 - sideL / 2 - .1, .15))
    end
  end
  if S.patch then
    local dk = RGB(12, 12, 12)
    fixed(H, "Patch", V3(.1, .7, .7), dk, CFrame.new(S.ex, S.ey, fz - .07) * CFrame.Angles(0, math.rad(90), 0), nil, Enum.PartType.Cylinder)
    fixed(H, "StrapF", V3(hs.X + .08, .09, .07), dk, CFrame.new(0, S.ey + .1, fz - .03) * CFrame.Angles(0, 0, -.3))
    fixed(H, "StrapB", V3(hs.X + .08, .09, .07), dk, V3(0, S.ey + .1, hs.Z / 2 + .03))
    for _, s in ipairs({ -1, 1 }) do
      fixed(H, "StrapS", V3(.07, .09, hs.Z + .06), dk, V3(s * (hs.X / 2 + .04), S.ey + .1, 0))
    end
  end

  if S.coat then
    local c = S.coat
    for _, s in ipairs({ -1, 1 }) do
      fixed(T, "CoatS", V3(.14, 2, 1.05), c, V3(s * .95, 0, .02))
      fixed(T, "Lapel", V3(.38, 1.5, .08), c, CFrame.new(s * .5, .2, -.5) * CFrame.Angles(0, 0, s * .1))
      limb(T, s < 0 and "TL" or "TR", V3(.14, 1.35, 1), c, V3(s * .95, -.95, .02))
    end
    fixed(T, "CoatB", V3(1.95, 2, .14), c, V3(0, 0, .5))
    fixed(T, "Collar", V3(1.9, .26, .3), c, V3(0, .95, .35))
    limb(T, "TB", V3(1.95, 1.35, .14), c, V3(0, -.95, .5))
    for _, x in ipairs({ -.45, .1, .55 }) do
      fixed(T, "Fold", V3(.05, 1.7, .04), S.fold, V3(x, 0, .58))
    end
  end
  if S.jacket then
    fixed(T, "Hood", V3(1.5, .4, .55), S.pad, V3(0, .98, .2))
    fixed(T, "Zip", V3(.06, 1.8, .04), RGB(200, 195, 225), V3(0, 0, -.46))
    for _, s in ipairs({ -1, 1 }) do
      fixed(T, "Stripe", V3(.5, .14, .05), S.stripe, CFrame.new(s * .5, .55, -.46) * CFrame.Angles(0, 0, s * .25))
      fixed(T, "Pocket", V3(.5, .7, .05), S.pad, V3(s * .55, -.45, -.46))
    end
  end

  for _, s in ipairs({ -1, 1 }) do
    local n = s < 0 and "L" or "R"
    local au = limb(T, "A" .. n, V3(.5, 1, .5), S.up, V3(s * 1.15, .82, 0))
    local fa = limb(au, "E" .. n, V3(.45, .95, .45), S.fo, V3(0, -.5, 0))
    if S.cuff then fixed(fa, "Cuff", V3(.5, .16, .5), S.cuff, V3(0, -.4, 0)) end
    if S.fold then
      fixed(au, "Fold", V3(.52, .05, .52), S.fold, V3(0, -.15, 0))
      fixed(fa, "Fold", V3(.47, .05, .47), S.fold, V3(0, .2, 0))
    end
    if S.pad then fixed(au, "Pad", V3(.66, .2, .66), S.pad, V3(0, .5, 0)) end
    local pm = limb(fa, "W" .. n, V3(.5, .34, .32), sc, V3(0, -.475, 0))
    for i = 0, 3 do
      fixed(pm, "Finger", V3(.1, .3, .12), sc, CFrame.new(-.18 + i * .12, -.3, -.03) * CFrame.Angles(.4, 0, 0))
    end
    fixed(pm, "Thumb", V3(.12, .26, .12), sc, CFrame.new(-s * .29, -.05, -.1) * CFrame.Angles(.5, 0, -s * .3))
    if s > 0 then R.hand = pm end
    local th = limb(root, "H" .. n, V3(.62, 1.25, .62), S.pants, V3(s * .45, -.6, 0))
    if S.holster and s > 0 then fixed(th, "Holster", V3(.2, .6, .42), RGB(70, 75, 95), V3(.38, -.1, 0)) end
    local sh = limb(th, "K" .. n, V3(.56, .85, .56), S.pants, V3(0, -.625, 0))
    if S.sock then fixed(sh, "Sock", V3(.5, .22, .5), S.sock, V3(0, -.3, 0)) end
    if S.boot then
      fixed(sh, "Boot", V3(.64, .6, .64), S.shoe, V3(0, -.12, 0))
      fixed(sh, "BStripe", V3(.66, .09, .66), S.stripe, V3(0, .05, 0))
    end
    local ft = limb(sh, "F" .. n, V3(.7, .3, 1.15), S.shoe, V3(0, -.425, 0), nil, .25)
    fixed(ft, "Toe", V3(.7, .22, .45), S.shoe, V3(0, .04, -.45))
  end
  R.FT = ftar(S, "normal")
  R.FC = copy(R.FT)
  return R
end

-- ============================================================
--  АНИМАТОР
-- ============================================================
local function smooth(st, key, v, a)
  local c = st[key] or v
  c = c + (v - c) * a
  st[key] = c
  return c
end

local function stepRig(R, dt, inp)
  local mot, base, fp, K, S, st = R.mot, R.base, R.fp, R.K, R.S, R.st
  local tm = mot.Torso
  if not tm or not tm.Parent then return end
  local F, FT = R.FC, R.FT
  R.t = R.t + dt
  local t = R.t
  local v, air = inp.speed, inp.air
  local a = math.min(1, dt * 12)
  local w = (air or v < .4) and 0 or math.clamp(v / math.max(inp.walkSpeed, 1), 0, 1.4)
  w = smooth(st, "w", w, a)
  local ag = smooth(st, "a", air and 1 or 0, a)
  R.ph = R.ph + dt * math.min(v, 40) * .55
  local ph = R.ph
  local s, c = math.sin(ph), math.cos(ph)
  local idle = 1 - math.min(1, w * 3)
  local br = math.sin(t * 1.9)
  local hips = (S.hips and 1 or 0) * idle * (1 - ag)

  local J = {}
  local function set(n, x, y, z) J[n] = { x or 0, y or 0, z or 0 } end

  local bob = br * .03 * idle + math.abs(c) * .07 * w
  local trx, try, trz = -.1 * w + br * .02 * idle, -s * .12 * w, 0
  set("Head", .08 * w - br * .02 * idle + ag * .15 + F.hx,
    math.sin(t * .7) * .1 * idle + math.sin(t * 40) * .05 * F.sh,
    math.sin(t * .5) * .03 * idle + F.hz)
  local swg = .75 * w
  local lh = s * swg * (1 - ag) + .45 * ag
  local rh = -s * swg * (1 - ag) - .15 * ag
  local lk = -math.max(0, c) * .9 * w * (1 - ag) - .7 * ag
  local rk = -math.max(0, -c) * .9 * w * (1 - ag) - .3 * ag
  set("HL", lh, 0, -.03)
  set("HR", rh, 0, .03)
  set("KL", lk)
  set("KR", rk)
  set("FL", -(lh + lk) * .6)
  set("FR", -(rh + rk) * .6)
  local sa = .7 * w * (1 - ag)
  local ar, al = s * sa, -s * sa
  local z = .07 + br * .03 * idle + .9 * ag + .5 * hips
  local eb = .15 + br * .03 * idle
  set("AR", ar, 0, z)
  set("AL", al, 0, -z)
  set("ER", eb + math.max(0, ar) * .6, 0, -1.3 * hips)
  set("EL", eb + math.max(0, al) * .6, 0, 1.3 * hips)
  local tl = -(.06 + .3 * w * (.5 + .5 * math.sin(ph * 2))) + ag * .1
  set("TB", tl)
  set("TL", tl, 0, -.04 - .1 * w)
  set("TR", tl, 0, .04 + .1 * w)

  if inp.ride then
    trx, try = -.05, 0
    set("HL", 1.45, 0, -.08)
    set("HR", 1.45, 0, .08)
    set("KL", -1.45)
    set("KR", -1.45)
    set("FL", .2)
    set("FR", .2)
    set("AR", .9, 0, .12)
    set("AL", .9, 0, -.12)
    set("ER", .5)
    set("EL", .5)
  end
  if inp.hold then
    set("AR", 1.35, 0, .05)
    set("ER", .25)
  end

  if inp.emote then R.curEm = inp.emote end
  local want = (inp.emote ~= nil) and idle > .5 and not air and not inp.ride
  local ew = smooth(st, "em", want and 1 or 0, math.min(1, dt * 8))
  if ew > .01 and R.curEm then
    local e = R.curEm
    local function bl(n, x, y, zz)
      local j = J[n] or { 0, 0, 0 }
      J[n] = { j[1] + ((x or 0) - j[1]) * ew, j[2] + ((y or 0) - j[2]) * ew, j[3] + ((zz or 0) - j[3]) * ew }
    end
    local function tor(x, y, zz, b)
      trx = trx + (x - trx) * ew
      try = try + (y - try) * ew
      trz = trz + (zz - trz) * ew
      bob = bob + (b - bob) * ew
    end
    if e == "wave" then
      bl("AR", 0, 0, 2.7)
      bl("ER", 0, 0, .4 + math.sin(t * 10) * .55)
      bl("Head", 0, .2, -.08)
    elseif e == "dance" then
      local d = math.sin(t * 4)
      tor(0, d * .3, d * .12, math.abs(d) * .14)
      bl("AR", math.sin(t * 2) * .5, 0, 1.2 + d * .8)
      bl("AL", math.sin(t * 2 + 1) * .5, 0, -(1.2 - d * .8))
      bl("ER", .6)
      bl("EL", .6)
      bl("HL", d * .35, 0, -.05)
      bl("HR", -d * .35, 0, .05)
      bl("KL", -math.max(0, d) * .7)
      bl("KR", -math.max(0, -d) * .7)
      bl("Head", 0, math.sin(t * 2) * .3, d * .1)
    elseif e == "drunk" then
      tor(.1 + math.sin(t * .9) * .12, 0, math.sin(t * 1.3) * .15, 0)
      bl("Head", .2, math.sin(t * .8) * .25, math.sin(t * 1.1) * .25)
      bl("AR", math.sin(t * 1.3) * .4, 0, .35 + math.sin(t * 1.7) * .3)
      bl("AL", math.sin(t * 1.3 + 2) * .4, 0, -(.35 + math.sin(t * 1.5) * .3))
      bl("HL", math.sin(t * 1.3) * .15, 0, -.1)
      bl("HR", -math.sin(t * 1.3) * .15, 0, .1)
    elseif e == "think" then
      bl("AR", 1.0, 0, -.2)
      bl("ER", 1.9)
      bl("AL", .7, 0, -.1)
      bl("EL", 1.0)
      bl("Head", .12, .15, .05)
    elseif e == "victory" then
      tor(-.1, 0, 0, math.abs(math.sin(t * 6)) * .1)
      bl("AR", 0, 0, 2.8)
      bl("AL", 0, 0, -2.8)
      bl("ER", 0, 0, -.15)
      bl("EL", 0, 0, .15)
      bl("Head", -.25)
    elseif e == "facepalm" then
      tor(.12, 0, 0, 0)
      bl("AR", 1.0)
      bl("ER", 2.4)
      bl("AL", 0, 0, -.15)
      bl("Head", .3)
    end
  end

  tm.C0 = CFrame.new(0, bob * K, 0) * base.Torso * CFrame.Angles(trx, try, trz)
  for n, j in pairs(J) do
    local m = mot[n]
    if m then m.C0 = base[n] * CFrame.Angles(j[1], j[2], j[3]) end
  end

  local fa = math.min(1, dt * 9)
  for k, vv in pairs(FT) do F[k] = F[k] + (vv - F[k]) * fa end
  if t > R.nextBlink then
    R.blinkEnd = t + .13
    R.nextBlink = t + 2.5 + math.random() * 3
  end
  local blink = t < R.blinkEnd and .12 or 1
  local mo, mw = F.mo, F.w * F.mw
  local mh = .09 + mo
  local lz = R.lz
  local function sz(p, x, y, zz)
    local l = lz[p]
    if not l or math.abs(l.X - x) + math.abs(l.Y - y) + math.abs(l.Z - zz) > .003 then
      l = V3(x, y, zz)
      lz[p] = l
      p.Size = l
    end
  end
  for _, n in ipairs({ "L", "R" }) do
    local r = (n == "R")
    local h = F.eh * blink * ((r and F.wk > .5) and .1 or 1)
    sz(fp["fE" .. n], .08 * K, S.er * h * K, S.er * K)
    local ps = S.pr * F.pr * K
    sz(fp["fP" .. n], ps, ps * math.min(1, math.max(.05, h * 1.5)), ps)
    mot["fP" .. n].C0 = base["fP" .. n] * CFrame.new((r and -1 or 1) * F.px * K, F.py * K, 0)
    mot["fB" .. n].C0 = base["fB" .. n] * CFrame.new(0, (F.by + (r and F.bq or 0)) * K, 0) * CFrame.Angles(0, 0, (r and 1 or -1) * F.br)
    fp["fT" .. n].Transparency = 1 - F.tr * .85
    mot["fT" .. n].C0 = base["fT" .. n] * CFrame.new(0, -((t * .9 + (r and .5 or 0)) % 1) * .45 * K, 0)
    mot["fM" .. n].C0 = base["fM" .. n] * CFrame.new((r and 1 or -1) * (mw / 2 - .15) * K, (F.cy + (r and F.cs or -F.cs)) * K, 0)
      * CFrame.Angles(0, 0, (r and 1 or -1) * F.cr)
  end
  sz(fp.fMC, mw * K, mh * K, .05 * K)
  local tw = math.min(1, mo * 8)
  sz(fp.fTe, mw * .85 * K, .08 * K, .05 * K)
  mot.fTe.C0 = base.fTe * CFrame.new(0, (mh / 2 - .05) * K, 0)
  fp.fTe.Transparency = 1 - F.te * tw
  mot.fTg.C0 = base.fTg * CFrame.new(0, (-mh / 2 + .06) * K, 0)
  fp.fTg.Transparency = 1 - F.tg * tw
end

-- ============================================================
--  ПРИМЕНЕНИЕ И СНЯТИЕ СКИНА
-- ============================================================
local animC, hidden = nil, {}
local function playerInput(hum, root)
  local vl = root.AssemblyLinearVelocity
  local sp = V3(vl.X, 0, vl.Z).Magnitude
  if EMOTE and sp > 1.5 then EMOTE = nil end
  return {
    speed = sp, walkSpeed = hum.WalkSpeed, air = (not RIDING) and hum.FloorMaterial == Enum.Material.Air,
    hold = HOLDING, ride = RIDING, emote = EMOTE,
  }
end
local function clearSkin()
  if animC then animC:Disconnect() animC = nil end
  if RIG and RIG.model then pcall(function() RIG.model:Destroy() end) end
  RIG = nil
  detachHand()
  for p, tr in pairs(hidden) do
    if p.Parent then p.Transparency = tr end
  end
  hidden = {}
end
local function applySkin(id)
  local S = SK[id]
  if not S then return end
  local ch, hum, root = getChar()
  if not root or not hum then notify("Нет персонажа", C.dg) return end
  clearSkin()
  for _, d in ipairs(ch:GetDescendants()) do
    if d:IsA("BasePart") and d ~= root and not d:FindFirstAncestorOfClass("Tool") then
      hidden[d] = d.Transparency
      d.Transparency = 1
    end
  end
  local gy = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + root.Size.Y / 2) or 3
  local R = newRig(root, S, math.clamp(gy / 3, .5, 3))
  R.model.Name = "RM_Skin_" .. id
  R.model.Parent = ch
  R.FT = ftar(S, ST.Emotion)
  R.FC = copy(R.FT)
  RIG = R
  animC = RunService.RenderStepped:Connect(function(dt)
    if not RIG or not root.Parent or not hum.Parent then return end
    stepRig(RIG, dt, playerInput(hum, root))
  end)
  ST.ActiveSkin = id
  save()
  notify("🎭 Скин: " .. S.name, C.ac)
  dimFx(nil, .8)
  local tl = ch:FindFirstChildOfClass("Tool")
  if tl and tl == heldTool and heldDef then attachHand(tl, heldDef.grip) end
end
local function removeSkin()
  clearSkin()
  ST.ActiveSkin = ""
  save()
  refreshGrip()
  notify("🎭 Скин снят", C.tx)
end
local function setEmo(id)
  ST.Emotion = id
  save()
  if RIG then RIG.FT = ftar(RIG.S, id) else notify("Сначала надень скин", C.dg, 2) end
  for _, e in ipairs(EM) do
    if e[1] == id then notify("Лицо: " .. e[2], C.ac, 1.5) end
  end
end
local function say(text)
  local head = RIG and RIG.parts.Head
  if not head then
    local ch = LP.Character
    head = ch and ch:FindFirstChild("Head")
  end
  bubble(head, text, 3.5)
end
track(LP.CharacterAdded:Connect(function()
  RIDING = false
  EMOTE = nil
  rideKeys.up, rideKeys.down = false, false
  task.wait(1)
  if ST.ActiveSkin ~= "" then safe(applySkin, ST.ActiveSkin) end
end))

-- ============================================================
--  МИР: луч прицела, земля
-- ============================================================
local function aimHit(maxDist)
  local d, o = RM.getAimDirection()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { LP.Character }
  local r = Workspace:Raycast(o, d * maxDist, rp)
  if r then return r.Position, r.Normal end
  return o + d * math.min(maxDist, 50), -d
end
local function groundAt(pos)
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { LP.Character }
  local r = Workspace:Raycast(pos + V3(0, 6, 0), V3(0, -80, 0), rp)
  return r and r.Position.Y or nil
end

-- ============================================================
--  ПОРТАЛЫ
-- ============================================================
local function pl(par, x, y, w, h, rot, col)
  local f = I("Frame", {
    AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
    Rotation = rot or 0, BackgroundColor3 = col, BorderSizePixel = 0,
  }, par)
  I("UICorner", { CornerRadius = UDim.new(.5, 0) }, f)
  return f
end
local function killPortal(P)
  if P and P.mo then pcall(function() P.mo:Destroy() end) end
end
local function newPortal(pos, n, col)
  local up = math.abs(n.Y) > .9 and Vector3.xAxis or Vector3.yAxis
  local at = pos + n * .12
  local P = { pos = at, n = n, R = PORTAL_R, L = {}, t0 = os.clock(), locked = false, mo = I("Model", { Name = "RM_Portal" }, Workspace) }
  local d = mkp("Disc", V3(.1, .1, .2), col)
  d.Anchored = true
  d.Transparency = 1
  d.CFrame = CFrame.lookAt(at, at + n, up)
  d.Parent = P.mo
  P.d = d
  local dk, md, lt, wh = col:Lerp(BLACK, .7), col:Lerp(BLACK, .35), col:Lerp(WHITE, .45), col:Lerp(WHITE, .88)
  local g = I("SurfaceGui", {
    Face = Enum.NormalId.Front, CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Brightness = 1.3,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  }, d)
  local function lay(spd)
    local f = I("Frame", {
      AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1),
      BackgroundTransparency = 1,
    }, g)
    P.L[#P.L + 1] = { f, spd }
    return f
  end
  for i, s in ipairs({ .88, .72, .56, .4, .24 }) do
    pl(g, .5, .5, s, s, 0, md:Lerp(dk, (i - 1) * .22))
  end
  for k, cfg in ipairs({ { 14, -14 }, { 11, 19 } }) do
    local f = lay(cfg[2])
    for i = 1, cfg[1] do
      local a = i / cfg[1] * 6.283 + k
      local s = .17 * (.75 + .25 * (i % 3))
      pl(f, .5 + .385 * math.cos(a), .5 + .385 * math.sin(a), s, s, 0, k == 1 and md or md:Lerp(lt, .4))
    end
  end
  local f = lay(38)
  for arm = 0, 4 do
    for j = 0, 4 do
      local r, an = .41 - j * .07, arm * 1.2566 + j * .6
      pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .2 - j * .025, .045, math.deg(an) + 108, j % 2 == 0 and lt or md:Lerp(lt, .5))
    end
  end
  f = lay(52)
  for i = 0, 15 do
    local r, an = .26 + .14 * ((i * 3) % 5) / 4, i * 2.4
    pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .12 + .08 * ((i * 5) % 3) / 2, .035, math.deg(an) + 102, wh)
  end
  f = lay(95)
  for i = 0, 5 do
    local r, an = .1 + i * .03, i * 1.1
    pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .13, .04, math.deg(an) + 105, lt)
  end
  local g2 = g:Clone()
  g2.Face = Enum.NormalId.Back
  g2.Parent = d
  I("PointLight", { Color = col, Range = 24, Brightness = 2, Shadows = false }, d)
  local e = I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 16, Lifetime = NumberRange.new(.7, 1),
    Speed = NumberRange.new(4, 5), SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(.6, 0),
    Transparency = NumberSequence.new(.1, 1), LightEmission = 1, Color = ColorSequence.new(lt),
    EmissionDirection = Enum.NormalId.Front,
  }, d)
  pcall(function()
    e.Shape = Enum.ParticleEmitterShape.Disc
    e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
    e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
  end)
  return P
end
local function updPortal(P, t)
  if not P.done then
    local o = math.min(1, t / .45)
    o = 1 - (1 - o) ^ 3
    local s = 2 * P.R * math.max(o, .03)
    P.d.Size = V3(s, s, .2)
    P.done = o >= 1
  end
  for _, l in ipairs(P.L) do l[1].Rotation = t * l[2] end
end
local function inPortal(P, pos)
  local off = pos - P.pos
  local dep = off:Dot(P.n)
  local lat = (off - P.n * dep).Magnitude
  return math.abs(dep) < P.R * .8 and lat < P.R * 1.05
end
local function playerInPortal(P, hr)
  return inPortal(P, hr.Position) or inPortal(P, hr.Position - V3(0, 2.6, 0))
end
local function teleportTo(hr, from, to)
  tpCd = os.clock() + .3
  to.locked = true
  local col = pcol()
  burst(hr.Position, col, 30)
  local ex = to.pos + to.n * 4
  local lk = V3(to.n.X, 0, to.n.Z)
  if lk.Magnitude < .1 then lk = hr.CFrame.LookVector else lk = lk.Unit end
  hr.CFrame = CFrame.lookAt(ex, ex + V3(lk.X, 0, lk.Z))
  hr.AssemblyLinearVelocity = to.n * 24
  burst(ex, col, 30)
  snd("teleport", .8, 1.2)
  dimFx(col, .8)
end
local function shootPortal()
  local pos, n = aimHit(500)
  local col = pcol()
  if not PA then
    PA = newPortal(pos, n, col)
    notify("🌀 Портал A", col)
  elseif not PB then
    PB = newPortal(pos, n, col)
    notify("🌀 Портал B", col)
  elseif PA.t0 <= PB.t0 then
    killPortal(PA)
    PA = newPortal(pos, n, col)
    notify("🌀 Портал A пересоздан", col)
  else
    killPortal(PB)
    PB = newPortal(pos, n, col)
    notify("🌀 Портал B пересоздан", col)
  end
  local dome = heldTool and heldTool:FindFirstChild("DomeTop")
  if dome then
    local a = dome.Position
    local dist = (pos - a).Magnitude
    local b = mkp("Beam", V3(.25, .25, dist), col, Enum.Material.Neon)
    b.Anchored = true
    b.CFrame = CFrame.lookAt(a, pos) * CFrame.new(0, 0, -dist / 2)
    b.Parent = Workspace
    TweenService:Create(b, TweenInfo.new(.25), { Transparency = 1 }):Play()
    task.delay(.3, function() b:Destroy() end)
  end
  snd("shoot", .6)
end
RM.shootPortal = shootPortal

-- ============================================================
--  ПРЕДМЕТЫ
-- ============================================================
local function toolPart(tool, handle, name, size, color, offset, material, shape)
  local p = mkp(name, size, color, material, shape)
  p.Parent = tool
  local w = Instance.new("Weld")
  w.Part0 = handle
  w.Part1 = p
  w.C0 = offset
  p.CFrame = handle.CFrame * offset
  w.Parent = p
  return p
end
local R90 = CFrame.Angles(0, 0, math.rad(90))
local RZ = CFrame.Angles(0, math.rad(90), 0)

local function buildGun()
  local tool = I("Tool", { Name = "Портальная пушка", RequiresHandle = true, CanBeDropped = false, ToolTip = "Открыть портал" })
  local h = mkp("Handle", V3(.45, 1.3, .6), RGB(214, 217, 222))
  h.Parent = tool
  local function P(...) return toolPart(tool, h, ...) end
  local GR = RGB(60, 255, 90)
  P("Body", V3(1.15, .3, 2.2), RGB(228, 230, 233), CFrame.new(0, .8, -.75))
  P("Under", V3(.95, .14, 1.7), RGB(140, 145, 152), CFrame.new(0, .63, -.9))
  P("Nozzle", V3(.5, .2, .35), RGB(95, 100, 108), CFrame.new(0, .82, -1.95))
  P("GripEnd", V3(.5, .32, .66), RGB(150, 155, 160), CFrame.new(0, -.62, .03))
  P("Ring", V3(.12, .95, .95), RGB(140, 215, 175), CFrame.new(0, .99, -1.2) * R90, Enum.Material.Fabric, Enum.PartType.Cylinder)
  P("Dome", V3(.9, .6, .6), GR, CFrame.new(0, 1.5, -1.2) * R90, Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = .35
  P("DomeTop", V3(.6, .6, .6), GR, CFrame.new(0, 1.95, -1.2), Enum.Material.Glass, Enum.PartType.Ball).Transparency = .35
  local core = P("Core", V3(.9, .38, .38), RGB(110, 255, 110), CFrame.new(0, 1.5, -1.2) * R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  core.Transparency = .25
  P("CoreTop", V3(.38, .38, .38), RGB(110, 255, 110), CFrame.new(0, 1.95, -1.2), Enum.Material.Neon, Enum.PartType.Ball).Transparency = .25
  I("PointLight", { Color = GR, Range = 9, Brightness = 2, Shadows = false }, core)
  local led = P("Led", V3(.8, .05, .34), RGB(14, 14, 16), CFrame.new(0, .97, -.25))
  local sg = I("SurfaceGui", { Face = Enum.NormalId.Top, CanvasSize = Vector2.new(160, 68), LightInfluence = 0, Brightness = 2 }, led)
  I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "C-137", TextColor3 = RGB(255, 40, 40),
    Font = Enum.Font.Code, TextScaled = true,
  }, sg)
  P("Btn", V3(.1, .4, .4), RGB(28, 28, 30), CFrame.new(0, .99, .12) * R90, nil, Enum.PartType.Cylinder)
  local function cable(pts, col)
    for i = 1, #pts - 1 do
      local a, b = pts[i], pts[i + 1]
      P("Wire", V3((b - a).Magnitude, .07, .07), col, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), nil, Enum.PartType.Cylinder)
    end
  end
  cable({ V3(.32, 1.02, -1.4), V3(.52, 1.08, -1), V3(.55, 1, -.5), V3(.42, .9, .05) }, RGB(30, 30, 34))
  cable({ V3(-.32, 1.02, -1.4), V3(-.52, 1.08, -1), V3(-.55, 1, -.5), V3(-.42, .9, .05) }, RGB(60, 62, 70))
  return tool
end

local function buildFreezer()
  local tool = I("Tool", { Name = "Замораживатель времени", RequiresHandle = true, CanBeDropped = false, ToolTip = "Остановить время" })
  local h = mkp("Handle", V3(.5, 1.2, .5), RGB(60, 64, 74))
  h.Parent = tool
  local function P(...) return toolPart(tool, h, ...) end
  local BL = RGB(90, 200, 255)
  P("Body", V3(.9, .75, 1.3), RGB(225, 230, 235), CFrame.new(0, .75, -.45))
  P("LensRing", V3(.12, 1.15, 1.15), RGB(50, 54, 62), CFrame.new(0, .75, -1.12) * RZ, nil, Enum.PartType.Cylinder)
  P("Lens", V3(.4, .9, .9), BL, CFrame.new(0, .75, -1.2) * RZ, Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = .3
  local core = P("Core", V3(.5, .5, .5), RGB(200, 245, 255), CFrame.new(0, .75, -1.15) * RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  core.Transparency = .2
  I("PointLight", { Color = BL, Range = 9, Brightness = 2, Shadows = false }, core)
  local btn = P("Button", V3(.12, .5, .5), RGB(50, 120, 200), CFrame.new(0, 1.18, -.3) * R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  I("PointLight", { Color = BL, Range = 5, Brightness = 1, Shadows = false }, btn)
  for _, s in ipairs({ -1, 1 }) do
    P("Fin", V3(.1, .5, .8), RGB(150, 160, 170), CFrame.new(s * .5, .75, -.4))
  end
  return tool
end

local function buildMeeseeksBox()
  local tool = I("Tool", { Name = "Ящик Мисиксов", RequiresHandle = true, CanBeDropped = false, ToolTip = "Нажми кнопку — помощник" })
  local h = mkp("Handle", V3(1.5, 1.5, 1.5), RGB(30, 66, 64), Enum.Material.Metal)
  h.Parent = tool
  local function P(...) return toolPart(tool, h, ...) end
  local GREEN, DKG = RGB(120, 250, 180), RGB(40, 190, 130)
  P("Top", V3(1.3, .12, 1.3), RGB(84, 130, 130), CFrame.new(0, .78, 0), Enum.Material.Metal)
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("Post", V3(.14, 1.56, .14), RGB(62, 112, 110), CFrame.new(sx * .72, 0, sz * .72), Enum.Material.Metal)
    end
  end
  P("ButtonBase", V3(.1, .66, .66), RGB(8, 24, 24), CFrame.new(0, .86, 0) * R90, nil, Enum.PartType.Cylinder)
  local btn = P("Button", V3(.24, .5, .5), RGB(70, 170, 240), CFrame.new(0, .97, 0) * R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  I("PointLight", { Color = RGB(70, 170, 240), Range = 8, Brightness = 1.5, Shadows = false }, btn)
  for i = 0, 3 do
    local side = CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(0, -.02, -.755)
    P("WinA", V3(.86, .5, .05), GREEN, side, Enum.Material.Neon)
    P("WinB", V3(.5, .86, .05), GREEN, side, Enum.Material.Neon)
    P("WinC", V3(.62, .62, .05), GREEN, side * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon)
    P("Line", V3(.03, .7, .06), DKG, side * CFrame.new(-.12, 0, -.02))
    P("Line", V3(.03, .7, .06), DKG, side * CFrame.new(.12, 0, -.02))
  end
  return tool
end

local function buildBattery()
  local tool = I("Tool", { Name = "Батарея микровселенной", RequiresHandle = true, CanBeDropped = false, ToolTip = "Зона энергии" })
  local h = mkp("Handle", V3(1.2, .8, .8), RGB(170, 60, 230), Enum.Material.Neon)
  h.Transparency = .15
  h.Parent = tool
  local function P(...) return toolPart(tool, h, ...) end
  local dk = RGB(22, 22, 26)
  P("Glass", V3(1.4, 1, 1), RGB(215, 140, 255), CFrame.new(), Enum.Material.Glass).Transparency = .6
  for _, sy in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("BarX", V3(1.5, .1, .1), dk, CFrame.new(0, sy * .5, sz * .5), Enum.Material.Metal)
    end
  end
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("BarY", V3(.1, 1.1, .1), dk, CFrame.new(sx * .7, 0, sz * .5), Enum.Material.Metal)
    end
    for _, sy in ipairs({ -1, 1 }) do
      P("BarZ", V3(.1, .1, 1.1), dk, CFrame.new(sx * .7, sy * .5, 0), Enum.Material.Metal)
    end
  end
  P("Panel", V3(.6, .7, .06), dk, CFrame.new(-.35, 0, -.53), Enum.Material.Metal)
  for i = 0, 2 do
    local ex = -.5 + i * .15
    local ey = (i == 1) and .22 or .15
    P("Eye", V3(.16, .16, .16), RGB(240, 240, 240), CFrame.new(ex, ey, -.58), nil, Enum.PartType.Ball)
    P("Pupil", V3(.08, .08, .08), RGB(0, 0, 0), CFrame.new(ex, ey, -.63), nil, Enum.PartType.Ball)
  end
  P("Door", V3(.18, .28, .04), RGB(70, 74, 82), CFrame.new(-.35, -.2, -.57))
  P("Blob", V3(.2, .2, .2), RGB(255, 150, 255), CFrame.new(.15, .15, -.1), Enum.Material.Neon, Enum.PartType.Ball).Transparency = .2
  P("Blob", V3(.12, .12, .12), RGB(255, 200, 255), CFrame.new(-.1, .05, .15), Enum.Material.Neon, Enum.PartType.Ball).Transparency = .2
  local scr = P("Screen", V3(.5, .18, .05), RGB(10, 14, 10), CFrame.new(.3, -.2, -.53))
  local sg = I("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(120, 40), LightInfluence = 0, Brightness = 2 }, scr)
  local lbl = I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "100%", TextColor3 = RGB(120, 255, 140),
    Font = Enum.Font.Code, TextScaled = true,
  }, sg)
  I("PointLight", { Color = RGB(190, 80, 255), Range = 9, Brightness = 2, Shadows = false }, h)
  return tool, lbl
end

local function buildRemote()
  local tool = I("Tool", { Name = "Пульт крейсера", RequiresHandle = true, CanBeDropped = false, ToolTip = "Вызвать / сесть / слезть" })
  local h = mkp("Handle", V3(.5, 1, .3), RGB(55, 60, 68), Enum.Material.Metal)
  h.Parent = tool
  local function P(...) return toolPart(tool, h, ...) end
  local scr = P("Screen", V3(.38, .3, .04), RGB(10, 20, 14), CFrame.new(0, .22, -.17), Enum.Material.Neon)
  scr.Color = RGB(60, 255, 120)
  local sg = I("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(120, 90), LightInfluence = 0, Brightness = 2 }, scr)
  I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "SHIP", TextColor3 = RGB(5, 40, 15),
    Font = Enum.Font.Code, TextScaled = true,
  }, sg)
  P("Button", V3(.14, .22, .22), RGB(255, 140, 40), CFrame.new(0, -.2, -.17) * RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  P("Antenna", V3(.7, .05, .05), RGB(30, 30, 34), CFrame.new(.15, .85, 0) * R90, nil, Enum.PartType.Cylinder)
  P("Tip", V3(.1, .1, .1), RGB(255, 80, 80), CFrame.new(.15, 1.2, 0), Enum.Material.Neon, Enum.PartType.Ball)
  return tool
end

function detachHand()
  HOLDING = false
  if gripW then pcall(function() gripW:Destroy() end) gripW = nil end
  if gripC then gripC:Disconnect() gripC = nil end
end
function attachHand(tool, off)
  detachHand()
  if not RIG or not RIG.hand then return end
  local handle = tool:FindFirstChild("Handle")
  local ch = LP.Character
  if not handle or not ch then return end
  for _, o in ipairs(ch:GetDescendants()) do
    if o.Name == "RightGrip" then o:Destroy() end
  end
  gripC = ch.DescendantAdded:Connect(function(o)
    if o.Name == "RightGrip" then task.defer(function() pcall(function() o:Destroy() end) end) end
  end)
  gripW = Instance.new("Weld")
  gripW.Name = "RM_Grip"
  gripW.Part0 = RIG.hand
  gripW.Part1 = handle
  gripW.C0 = CFrame.new(off or V3()) * CFrame.Angles(-math.pi / 2, 0, 0)
  gripW.Parent = RIG.hand
  HOLDING = true
end
function refreshGrip()
  detachHand()
  local ch, hum = getChar()
  if hum and heldTool and heldTool.Parent == ch then
    task.defer(function()
      hum:UnequipTools()
      hum:EquipTool(heldTool)
    end)
  end
end

local ccStop
local function timeStop()
  local now = os.clock()
  if now < TS_CD then notify("❄ Перезарядка " .. math.ceil(TS_CD - now) .. " с", C.dg, 1) return end
  local _, _, hr = getChar()
  if not hr then return end
  TS_CD = now + 10
  TIMESTOP_UNTIL = now + 4
  local bub = I("Part", {
    Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.ForceField, Color = RGB(120, 200, 255), Transparency = .25,
    Size = V3(2, 2, 2), CFrame = hr.CFrame,
  }, Workspace)
  TweenService:Create(bub, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = V3(44, 44, 44) }):Play()
  task.delay(3.5, function()
    TweenService:Create(bub, TweenInfo.new(.5), { Transparency = 1 }):Play()
    task.delay(.55, function() bub:Destroy() end)
  end)
  if not ccStop or not ccStop.Parent then ccStop = I("ColorCorrectionEffect", { Name = "RM_TimeStop" }, Lighting) end
  TweenService:Create(ccStop, TweenInfo.new(.3), { Saturation = -.85, Contrast = .2, TintColor = RGB(185, 225, 255) }):Play()
  task.delay(4, function()
    if ccStop and ccStop.Parent then
      TweenService:Create(ccStop, TweenInfo.new(.6), { Saturation = 0, Contrast = 0, TintColor = WHITE }):Play()
    end
  end)
  for _, hp in ipairs(helpers) do
    local hl = I("Highlight", {
      FillColor = RGB(150, 220, 255), FillTransparency = .5, OutlineColor = WHITE, Adornee = hp.R.model,
    }, hp.R.model)
    task.delay(4, function() if hl.Parent then hl:Destroy() end end)
  end
  snd("teleport", .7, .6)
  notify("⏱ Время остановлено на 4 с", RGB(150, 230, 255), 2)
end

local helperFolder = I("Folder", { Name = "RM_Helpers" }, Workspace)
local MEE_CATCH = {
  "Я Мистер Мисикс, посмотри на меня!", "Ооо, да, можно!", "Существование — это боль!",
  "Я выполню задание!", "Дай мне исчезнуть!",
}
local function spawnMeeseeks()
  if #helpers >= 3 then notify("Максимум 3 Мисикса сразу", C.dg, 1.5) return end
  local _, _, hr = getChar()
  if not hr then return end
  local target = aimHit(120)
  local far = target and (target - hr.Position).Magnitude > 8
  local lv = V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
  lv = lv.Magnitude > .01 and lv.Unit or V3(0, 0, -1)
  local ahead = hr.Position + lv * 5
  local gy = groundAt(ahead) or (hr.Position.Y - 3)
  local pos = V3(ahead.X, gy + 3, ahead.Z)
  local root = mkp("MRoot", V3(2, 2, 1), WHITE)
  root.Transparency = 1
  root.Anchored = true
  root.CFrame = CFrame.lookAt(pos, pos + lv)
  local R = newRig(root, SK.meeseeks, 1)
  R.FT = ftar(SK.meeseeks, "happy")
  R.FC = copy(R.FT)
  root.Parent = R.model
  R.model.Parent = helperFolder
  burst(pos, RGB(90, 170, 255), 30)
  helpers[#helpers + 1] = {
    R = R, root = root, born = os.clock(), face = lv, state = far and "go" or "follow",
    target = target, life = far and 22 or 14,
  }
  bubble(R.parts.Head, MEE_CATCH[math.random(#MEE_CATCH)], 2.8)
  snd("teleport", .5, 1.6)
end
local function stepHelper(h, dt)
  local R, root = h.R, h.root
  if not root.Parent then return false end
  local _, _, hr = getChar()
  if not hr then return true end
  local now = os.clock()
  if now < TIMESTOP_UNTIL then
    h.born = h.born + dt
    return true
  end
  local pos = root.Position
  local goal, stopD, speed = nil, 5, 18
  if h.state == "go" then
    goal, stopD = h.target, 2.5
  elseif h.state == "follow" or h.state == "back" then
    goal = hr.Position
  end
  local moving = false
  if goal then
    local flat = V3(goal.X - pos.X, 0, goal.Z - pos.Z)
    local dist = flat.Magnitude
    if dist > stopD then
      local dirv = flat.Unit
      pos = pos + dirv * math.min(dist - stopD, speed * dt)
      h.face = dirv
      moving = true
    elseif h.state == "go" then
      h.state = "work"
      h.workEnd = now + 2.4
      bubble(R.parts.Head, "Готово! Можно мне исчезнуть?", 2.4)
    end
  end
  if h.state == "work" and now > h.workEnd then h.state = "back" end
  local gy = groundAt(pos)
  local jump = (h.state == "work") and math.abs(math.sin(now * 7)) * 1.4 or 0
  local ty = (gy and gy + 3 or pos.Y) + jump
  pos = V3(pos.X, pos.Y + (ty - pos.Y) * math.min(1, dt * 14), pos.Z)
  root.CFrame = CFrame.lookAt(pos, pos + V3(h.face.X, 0, h.face.Z))
  stepRig(R, dt, {
    speed = moving and speed or 0, walkSpeed = 16, air = false, emote = (h.state == "work") and "dance" or nil,
  })
  if now - h.born > h.life then
    burst(pos, RGB(90, 170, 255), 30)
    return false
  end
  return true
end

-- ===== БЛОК A: бой и приказы Мисиксов =====
do
  local hpOf, deadUntil, dummies = {}, {}, {}
  local FIGHT_CATCH = { "Получай!", "За Рика!", "Ооо, дерёмся!", "Я тебя уничтожу!" }
  local ORDER_TEXT = {
    guard = "Я тебя защищу!", attack = "Я его побью!", move = "Иду туда!",
    follow = "Иду за тобой!", stay = "Стою на месте!", vanish = "Наконец-то!",
  }
  local ORDER_NAMES = {
    guard = "🛡 Мисиксы защищают", attack = "⚔ Мисиксы атакуют", move = "📍 Мисиксы идут на точку",
    follow = "🚶 Мисиксы идут за тобой", stay = "🛑 Мисиксы стоят", vanish = "💨 Мисиксы исчезают",
  }

  -- цель жива? (у NPC смотрим Health, у мишени свой счётчик)
  local function alive(tg)
    if not tg or not tg.model or not tg.model.Parent or not tg.root or not tg.root.Parent then return false end
    local du = deadUntil[tg.model]
    if du then
      if os.clock() < du then return false end
      deadUntil[tg.model], hpOf[tg.model] = nil, nil
    end
    if tg.kind == "npc" then
      local hum = tg.model:FindFirstChildOfClass("Humanoid")
      if not hum or hum.Health <= 0 then return false end
    end
    return true
  end

  -- поиск целей: мишени + NPC с Humanoid (игроки исключены)
  local op = OverlapParams.new()
  op.FilterType = Enum.RaycastFilterType.Exclude
  local function scan(center, radius)
    local list = {}
    for _, d in ipairs(dummies) do
      if alive(d) and (d.root.Position - center).Magnitude <= radius then list[#list + 1] = d end
    end
    op.FilterDescendantsInstances = { LP.Character, helperFolder }
    local ok, parts = pcall(function() return Workspace:GetPartBoundsInRadius(center, radius, op) end)
    if ok then
      local seen = {}
      for _, p in ipairs(parts) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m and not seen[m] then
          seen[m] = true
          if not Players:GetPlayerFromCharacter(m) then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local root = m:FindFirstChild("HumanoidRootPart")
            if hum and root then
              local tg = { model = m, root = root, kind = "npc" }
              if alive(tg) then list[#list + 1] = tg end
            end
          end
        end
      end
    end
    return list
  end
  local function nearest(list, pos)
    local best, bd = nil, 1e9
    for _, tg in ipairs(list) do
      local d = (tg.root.Position - pos).Magnitude
      if d < bd then best, bd = tg, d end
    end
    return best
  end

  -- эффекты удара
  local function dmgText(adornee, amount)
    local bb = I("BillboardGui", {
      Size = UDim2.fromOffset(60, 24), StudsOffset = V3((math.random() - .5) * 1.5, 2.5, 0),
      AlwaysOnTop = true, LightInfluence = 0,
    }, adornee)
    local l = I("TextLabel", {
      Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "-" .. amount,
      TextColor3 = RGB(255, 80, 80), TextStrokeTransparency = 0, Font = Enum.Font.GothamBold, TextSize = 18,
    }, bb)
    TweenService:Create(bb, TweenInfo.new(.6), { StudsOffset = bb.StudsOffset + V3(0, 2.5, 0) }):Play()
    TweenService:Create(l, TweenInfo.new(.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    task.delay(.65, function() bb:Destroy() end)
  end
  local function koDummy(d) -- мишень падает и через 5 с встаёт
    d.ko = true
    d.model:PivotTo(d.cf * CFrame.new(0, -2.9, 0) * CFrame.Angles(-1.45, 0, 0))
    task.delay(5, function()
      d.ko = false
      if d.model.Parent then d.model:PivotTo(d.cf) end
    end)
  end
  local function hitFx(tg) -- true, если цель добита
    local dmg = math.random(8, 15)
    hpOf[tg.model] = (hpOf[tg.model] or 100) - dmg
    dmgText(tg.root, dmg)
    burst(tg.root.Position, RGB(255, 200, 80), 8)
    local hl = I("Highlight", {
      FillColor = RGB(255, 70, 70), FillTransparency = .4, OutlineTransparency = 1, Adornee = tg.model,
    }, tg.model)
    task.delay(.12, function() if hl.Parent then hl:Destroy() end end)
    if tg.kind == "dummy" and not tg.ko then
      tg.model:PivotTo(tg.cf * CFrame.new((math.random() - .5) * .4, 0, (math.random() - .5) * .4))
      task.delay(.08, function() if tg.model.Parent and not tg.ko then tg.model:PivotTo(tg.cf) end end)
    end
    snd("click", .4, 1.4)
    return hpOf[tg.model] <= 0
  end

  -- мишень для тренировки (стоит там, куда смотришь)
  local function spawnDummy()
    if #dummies >= 3 then notify("Максимум 3 мишени", C.dg, 1.5) return end
    local pos = aimHit(60)
    local g = groundAt(pos)
    pos = V3(pos.X, g or pos.Y, pos.Z)
    local mo = I("Model", { Name = "RM_Dummy" }, helperFolder)
    local function add(n, sz, col, rel, mat, shape)
      local p = mkp(n, sz, col, mat, shape)
      p.Anchored = true
      p.CFrame = CFrame.new(pos) * rel
      p.Parent = mo
      return p
    end
    add("Base", V3(.4, 2.4, 2.4), RGB(90, 70, 50), CFrame.new(0, .2, 0) * R90, nil, Enum.PartType.Cylinder)
    add("Post", V3(.5, 3.2, .5), RGB(150, 110, 70), CFrame.new(0, 1.8, 0), Enum.Material.Wood)
    local body = add("Body", V3(1.8, 2, .9), RGB(205, 170, 90), CFrame.new(0, 3.6, 0), Enum.Material.Fabric)
    add("Arms", V3(3.2, .4, .4), RGB(150, 110, 70), CFrame.new(0, 4.1, 0), Enum.Material.Wood)
    add("Head", V3(1.1, 1.1, 1.1), RGB(220, 190, 120), CFrame.new(0, 5.1, 0), Enum.Material.Fabric, Enum.PartType.Ball)
    add("Ring1", V3(.1, 1.2, 1.2), RGB(220, 40, 40), CFrame.new(0, 3.6, -.46) * RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
    add("Ring2", V3(.1, .8, .8), WHITE, CFrame.new(0, 3.6, -.5) * RZ, nil, Enum.PartType.Cylinder)
    add("Ring3", V3(.1, .35, .35), RGB(220, 40, 40), CFrame.new(0, 3.6, -.53) * RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
    mo.PrimaryPart = body
    dummies[#dummies + 1] = { model = mo, root = body, kind = "dummy", cf = mo:GetPivot() }
    burst(pos + V3(0, 2, 0), RGB(255, 200, 80), 20)
    notify("🎯 Мишень поставлена", C.ac, 1.5)
  end
  RM.spawnDummy = function() safe(spawnDummy) end
  RM.clearDummies = function()
    for i = #dummies, 1, -1 do
      pcall(function() dummies[i].model:Destroy() end)
      table.remove(dummies, i)
    end
  end

  -- ящик теперь вызывает Мисикса-охранника
  spawnMeeseeks = function()
    if #helpers >= 3 then notify("Максимум 3 Мисикса сразу", C.dg, 1.5) return end
    local _, _, hr = getChar()
    if not hr then return end
    local lv = V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
    lv = lv.Magnitude > .01 and lv.Unit or V3(0, 0, -1)
    local ahead = hr.Position + lv * 5
    local gy = groundAt(ahead) or (hr.Position.Y - 3)
    local pos = V3(ahead.X, gy + 3, ahead.Z)
    local root = mkp("MRoot", V3(2, 2, 1), WHITE)
    root.Transparency = 1
    root.Anchored = true
    root.CFrame = CFrame.lookAt(pos, pos + lv)
    local R = newRig(root, SK.meeseeks, 1)
    R.FT = ftar(SK.meeseeks, "happy")
    R.FC = copy(R.FT)
    root.Parent = R.model
    R.model.Parent = helperFolder
    burst(pos, RGB(90, 170, 255), 30)
    helpers[#helpers + 1] = {
      R = R, root = root, born = os.clock(), face = lv, order = "guard", life = 90,
      slot = #helpers, nextScan = 0, nextHit = 0,
    }
    bubble(R.parts.Head, "Я Мистер Мисикс! Я тебя защищу!", 2.8)
    snd("teleport", .5, 1.6)
  end

  -- поведение помощника: приказы, поиск врагов, бой
  local function step(h, dt)
    local R, root = h.R, h.root
    if not root.Parent then return false end
    local _, _, hr = getChar()
    if not hr then return true end
    local now = os.clock()
    if now < TIMESTOP_UNTIL then
      h.born = h.born + dt
      return true
    end
    local pos, P = root.Position, hr.Position
    local order = h.order
    -- поиск цели
    if (order == "guard" or order == "attack") and not alive(h.target) then
      h.target = nil
      if now >= h.nextScan then
        h.nextScan = now + .6
        local center, radius = P, 32
        if order == "attack" then center, radius = h.orderPos or P, 26 end
        h.target = nearest(scan(center, radius), pos)
        if h.target then bubble(R.parts.Head, FIGHT_CATCH[math.random(#FIGHT_CATCH)], 1.8) end
      end
    end
    local tg = h.target
    -- слишком далеко от хозяина: возвращаем к нему
    if (order == "guard" or order == "follow") and (pos - P).Magnitude > 80 then
      local a = h.slot * 2.094
      pos = P + V3(math.cos(a), 0, math.sin(a)) * 6
      burst(pos, RGB(90, 170, 255), 20)
      h.target, tg = nil, nil
    end
    -- куда идти
    local goal, stopD, speed = nil, 1.5, 20
    if tg then
      goal, stopD, speed = tg.root.Position, 3.2, 24
    elseif order == "guard" then
      local a = h.slot * 2.094
      goal = P + V3(math.cos(a), 0, math.sin(a)) * 6
    elseif order == "follow" then
      goal, stopD = P, 5
    elseif order == "attack" or order == "move" then
      goal, stopD = h.orderPos or P, 2.5
    end
    local moving, inRange = false, false
    if goal then
      local flat = V3(goal.X - pos.X, 0, goal.Z - pos.Z)
      local dist = flat.Magnitude
      if dist > stopD then
        local dirv = flat.Unit
        pos = pos + dirv * math.min(dist - stopD, speed * dt)
        h.face = dirv
        moving = true
      else
        inRange = true
        if tg and dist > .05 then h.face = flat.Unit end
      end
    end
    -- пришёл на место
    if inRange and not tg then
      if order == "move" then
        h.order = "stay"
        bubble(R.parts.Head, "Я на месте!", 2)
      elseif order == "attack" then
        h.order = "guard"
        bubble(R.parts.Head, h.fought and "Победа! Возвращаюсь!" or "Тут никого нет...", 2.2)
        h.fought = false
      end
    end
    -- удар
    local fighting = tg ~= nil and inRange
    if fighting and now >= h.nextHit then
      h.nextHit = now + .45
      if hitFx(tg) then
        deadUntil[tg.model] = now + (tg.kind == "dummy" and 5 or 12)
        burst(tg.root.Position, RGB(255, 200, 80), 24)
        if tg.kind == "dummy" then koDummy(tg) end
        bubble(R.parts.Head, "Победа!", 1.6)
        h.target = nil
        h.fought = true
      end
    end
    -- земля, поворот, анимация
    local gy = groundAt(pos)
    local ty = gy and gy + 3 or pos.Y
    pos = V3(pos.X, pos.Y + (ty - pos.Y) * math.min(1, dt * 14), pos.Z)
    root.CFrame = CFrame.lookAt(pos, pos + V3(h.face.X, 0, h.face.Z))
    stepRig(R, dt, { speed = moving and speed or 0, walkSpeed = 16, air = false })
    if fighting then -- кулаки: руки бьют по очереди
      local ph = now * 7 + h.slot
      local p1, p2 = math.max(0, math.sin(ph)), math.max(0, math.sin(ph + math.pi))
      local mt, bs = R.mot, R.base
      mt.AR.C0 = bs.AR * CFrame.Angles(.2 + 1.4 * p1, 0, .1)
      mt.ER.C0 = bs.ER * CFrame.Angles(.3 - .3 * p1, 0, 0)
      mt.AL.C0 = bs.AL * CFrame.Angles(.2 + 1.4 * p2, 0, -.1)
      mt.EL.C0 = bs.EL * CFrame.Angles(.3 - .3 * p2, 0, 0)
      mt.Torso.C0 = mt.Torso.C0 * CFrame.Angles(0, (p2 - p1) * .35, 0)
    end
    if now - h.born > h.life then
      burst(pos, RGB(90, 170, 255), 30)
      return false
    end
    return true
  end
  stepHelper = function(h, dt)
    local ok, res = pcall(step, h, dt)
    if not ok then
      warn("[RickMorty] Мисикс: " .. tostring(res))
      return false
    end
    return res
  end

  -- приказ всем Мисиксам (цель = точка прицела)
  RM.helperOrder = function(order)
    if #helpers == 0 then notify("Сначала вызови Мисикса ящиком", C.dg, 2) return end
    local pos = aimHit(120)
    local now = os.clock()
    local target = nil
    if order == "attack" then
      target = nearest(scan(pos, 26), pos)
      if not target then notify("Рядом с точкой прицела целей нет", C.dg, 2) end
    end
    for _, h in ipairs(helpers) do
      h.born, h.life = now, 90
      h.order, h.orderPos, h.target, h.fought, h.nextScan = order, pos, target, false, 0
      if order == "vanish" then
        h.born = now - 1000
      else
        bubble(h.R.parts.Head, ORDER_TEXT[order], 2)
      end
    end
    notify(ORDER_NAMES[order], C.ac, 1.5)
  end
end

-- 🔋 батарея: зона энергии 15 секунд, заряд 100%, расход 25% за использование
local function useBattery()
  if BAT < 25 then notify("🔋 Мало заряда (" .. math.floor(BAT) .. "%)", C.dg, 1.5) return end
  local _, _, hr = getChar()
  if not hr then return end
  BAT = BAT - 25
  local pos = aimHit(70)
  if (pos - hr.Position).Magnitude > 60 then pos = hr.Position + (pos - hr.Position).Unit * 60 end
  local g = groundAt(pos)
  pos = V3(pos.X, g or pos.Y, pos.Z)
  local col = RGB(190, 80, 255)
  local mo = I("Model", { Name = "RM_Zone" }, Workspace)
  local disc = mkp("Zone", V3(.3, 20, 20), col, Enum.Material.Neon, Enum.PartType.Cylinder)
  disc.Anchored = true
  disc.Transparency = .65
  disc.CFrame = CFrame.new(pos + V3(0, .2, 0)) * R90
  disc.Parent = mo
  local ring = mkp("ZoneRing", V3(.4, 20.6, 20.6), col:Lerp(WHITE, .4), Enum.Material.Neon, Enum.PartType.Cylinder)
  ring.Anchored = true
  ring.Transparency = .4
  ring.CFrame = disc.CFrame
  ring.Parent = mo
  local em = mkp("Emitter", V3(18, .2, 18), col)
  em.Anchored = true
  em.Transparency = 1
  em.CFrame = CFrame.new(pos + V3(0, .4, 0))
  em.Parent = mo
  I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 18, Lifetime = NumberRange.new(1.5, 2),
    Speed = NumberRange.new(4, 6), SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(.5, 0),
    Transparency = NumberSequence.new(.1, 1), LightEmission = 1, Color = ColorSequence.new(col),
    EmissionDirection = Enum.NormalId.Top,
  }, em)
  I("PointLight", { Color = col, Range = 22, Brightness = 2, Shadows = false }, disc)
  TweenService:Create(disc, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = .82 }):Play()
  zones[#zones + 1] = { mo = mo, disc = disc, radius = 10, untilT = os.clock() + 15 }
  burst(pos + V3(0, 1, 0), col, 30)
  snd("teleport", .6, .8)
  notify("🔋 Зона энергии на 15 с (заряд " .. math.floor(BAT) .. "%)", col, 2)
end
local function updateZones(hr, now)
  local inside = false
  for i = #zones, 1, -1 do
    local zn = zones[i]
    if now > zn.untilT then
      table.remove(zones, i)
      TweenService:Create(zn.disc, TweenInfo.new(.5), { Transparency = 1 }):Play()
      task.delay(.6, function() pcall(function() zn.mo:Destroy() end) end)
    elseif hr then
      local off = hr.Position - zn.disc.Position
      if V3(off.X, 0, off.Z).Magnitude < zn.radius and math.abs(off.Y) < 10 then inside = true end
    end
  end
  if inside ~= inZone then
    inZone = inside
    local aura = hr and hr:FindFirstChild("RM_Aura")
    if inside and hr then
      if not aura then
        I("PointLight", { Name = "RM_Aura", Color = RGB(200, 90, 255), Range = 14, Brightness = 3, Shadows = false }, hr)
      end
      notify("⚡ Ты в зоне энергии", RGB(200, 120, 255), 1.5)
    elseif aura then
      aura:Destroy()
    end
  end
end

local SHIP_H, SHIP_SPEED, SHIP_VSPEED = 3.7, 70, 45
local SEAT = CFrame.new(0, 1.75, .5)
local function ell(model, name, size, col, rel, mat)
  local p = mkp(name, size, col, mat)
  p.Anchored = true
  p.CFrame = rel
  I("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, p)
  p.Parent = model
  return p
end
local function buildShip()
  local model = I("Model", { Name = "RM_Cruiser" }, Workspace)
  local function add(name, size, col, rel, mat, shape)
    local p = mkp(name, size, col, mat, shape)
    p.Anchored = true
    p.CFrame = rel
    p.Parent = model
    return p
  end
  local GRAY, LIGHT, DARK, YEL = RGB(88, 96, 104), RGB(185, 192, 200), RGB(40, 44, 50), RGB(235, 190, 40)
  local hull = ell(model, "Hull", V3(11, 3.2, 11), GRAY, CFrame.new(0, -.2, 0), Enum.Material.Metal)
  model.PrimaryPart = hull
  add("Rim", V3(.9, 12, 12), LIGHT, CFrame.new(0, .3, 0) * R90, Enum.Material.Metal, Enum.PartType.Cylinder)
  ell(model, "Deck", V3(9.5, 1.8, 9.5), RGB(170, 176, 184), CFrame.new(0, .9, 0), Enum.Material.Metal)
  for _, s in ipairs({ -1, 1 }) do
    add("Stripe", V3(1.2, .1, 3.6), YEL, CFrame.new(s * 3.2, 1.3, -2.4) * CFrame.Angles(0, math.rad(-30 * s), 0))
    ell(model, "Vent", V3(1.4, .7, 1.1), RGB(200, 185, 140), CFrame.new(s * 2.6, 1.15, -3.6))
    add("Light", V3(.6, .2, .2), RGB(255, 240, 150), CFrame.new(s * 1.2, .5, -5.3), Enum.Material.Neon)
  end
  add("StripeBack", V3(3, .1, .9), YEL, CFrame.new(0, 1.15, 4.4))
  local dome = ell(model, "Dome", V3(5.2, 3.6, 6.4), RGB(190, 230, 255), CFrame.new(0, 2.4, -.6), Enum.Material.Glass)
  dome.Transparency = .5
  add("Seat", V3(1.5, .3, 1.5), RGB(70, 58, 52), CFrame.new(0, 1.15, .5))
  add("SeatBack", V3(1.5, 1.6, .3), RGB(70, 58, 52), CFrame.new(0, 2, 1.3))
  add("Console", V3(2.2, .5, .8), DARK, CFrame.new(0, 1.5, -1.7))
  for _, s in ipairs({ -1, 1 }) do
    add("Screen", V3(.5, .3, .05), RGB(90, 240, 220), CFrame.new(s * .6, 1.85, -2.05), Enum.Material.Neon)
    add("Lever", V3(.08, .7, .08), DARK, CFrame.new(s * .95, 1.9, -1.4))
  end
  add("Engine", V3(2.6, 2.4, 2.4), RGB(120, 126, 132), CFrame.new(0, 1, 5.7) * RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
  add("EngineIn", V3(.2, 1.8, 1.8), RGB(10, 10, 12), CFrame.new(0, 1, 7) * RZ, nil, Enum.PartType.Cylinder)
  local glow = add("EngineGlow", V3(.1, 1.2, 1.2), RGB(120, 200, 255), CFrame.new(0, 1, 7.05) * RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 15, Lifetime = NumberRange.new(.4, .7),
    Speed = NumberRange.new(6, 9), Size = NumberSequence.new(.9, 0), LightEmission = 1, Color = ColorSequence.new(RGB(120, 200, 255)),
    EmissionDirection = Enum.NormalId.Back,
  }, glow)
  add("Wing", V3(7, .25, 1.8), GRAY, CFrame.new(0, 3, 5.2))
  add("WingPanel", V3(2.2, .06, 1.2), RGB(240, 150, 40), CFrame.new(-2, 3.15, 5.2))
  for _, s in ipairs({ -1, 1 }) do
    add("Support", V3(.3, 1.6, .3), DARK, CFrame.new(s * 2.5, 2.2, 5.2))
  end
  for i = 0, 3 do
    local a = math.rad(45 + i * 90)
    local x, z = math.sin(a) * 3.8, math.cos(a) * 3.8
    add("Leg", V3(.35, 2.6, .35), DARK, CFrame.new(x, -1.9, z) * CFrame.Angles(math.sin(a) * .0, 0, 0))
    add("Foot", V3(.9, .4, 1.1), RGB(30, 32, 38), CFrame.new(x * 1.12, -3.25, z * 1.12) * CFrame.Angles(0, a, 0))
  end
  I("PointLight", { Color = RGB(180, 220, 255), Range = 18, Brightness = 1.5, Shadows = false }, hull)
  return model
end
local function summonShip()
  local _, _, hr = getChar()
  if not hr then return end
  if RIDING then dismount() end
  if ship then pcall(function() ship.model:Destroy() end) ship = nil end
  local lv = V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
  lv = lv.Magnitude > .01 and lv.Unit or V3(0, 0, -1)
  local ahead = hr.Position + lv * 18
  local gy = groundAt(ahead) or (hr.Position.Y - 3)
  local land = V3(ahead.X, gy + SHIP_H, ahead.Z)
  local model = buildShip()
  ship = {
    model = model, land = land, pos = land + V3(0, 60, 0), yaw = math.atan2(-lv.X, -lv.Z),
    vel = V3(), state = "landing", t = 0, cf = CFrame.new(land),
  }
  model:PivotTo(CFrame.new(ship.pos) * CFrame.Angles(0, ship.yaw, 0))
  dimFx(RGB(255, 170, 70), .6)
  notify("🚀 Крейсер прибывает...", C.ac, 2)
end
function board()
  local _, hum, hr = getChar()
  if not ship or RIDING or not hum or not hr then return end
  if ship.state ~= "idle" then notify("Крейсер ещё садится", C.dg, 1.5) return end
  if (hr.Position - ship.pos).Magnitude > 22 then notify("Крейсер далеко: вызови его", C.dg, 2) return end
  RIDING = true
  EMOTE = nil
  hum.PlatformStand = true
  ship.vel = V3()
  notify("🚀 Полёт: джойстик/WASD, ▲▼ или Space/Shift", C.ac, 3)
end
function dismount()
  if not RIDING then return end
  RIDING = false
  rideKeys.up, rideKeys.down = false, false
  local _, hum, hr = getChar()
  if hum then hum.PlatformStand = false end
  if hr and ship then
    hr.CFrame = ship.cf * CFrame.new(7, 2, 0)
    hr.AssemblyLinearVelocity = V3()
  end
end
local function shipAction()
  local _, _, hr = getChar()
  if not hr then return end
  if RIDING then dismount() return end
  if not ship then summonShip() return end
  if ship.state == "idle" and (hr.Position - ship.pos).Magnitude < 20 then board() else summonShip() end
end
local function stepShip(dt)
  if not ship or not ship.model.Parent then return end
  local _, hum, hr = getChar()
  if RIDING and (not hum or hum.Health <= 0 or not hr) then dismount() end
  local now = os.clock()
  local pitch, roll = 0, 0
  if ship.state == "landing" then
    ship.t = ship.t + dt
    local a = math.min(1, ship.t / 1.5)
    a = 1 - (1 - a) ^ 3
    ship.pos = V3(ship.land.X, ship.land.Y + (1 - a) * 60, ship.land.Z)
    if ship.t >= 1.5 then ship.state = "idle" end
  elseif RIDING then
    local md = hum.MoveDirection
    local vy = (rideKeys.up and 1 or 0) - (rideKeys.down and 1 or 0)
    local want = V3(md.X * SHIP_SPEED, vy * SHIP_VSPEED, md.Z * SHIP_SPEED)
    ship.vel = ship.vel:Lerp(want, math.min(1, dt * 2.5))
    ship.pos = ship.pos + ship.vel * dt
    local gy = groundAt(ship.pos)
    if gy and ship.pos.Y < gy + SHIP_H then
      ship.pos = V3(ship.pos.X, gy + SHIP_H, ship.pos.Z)
      if ship.vel.Y < 0 then ship.vel = V3(ship.vel.X, 0, ship.vel.Z) end
    end
    if md.Magnitude > .15 then
      local ty = math.atan2(-md.X, -md.Z)
      local diff = (ty - ship.yaw + math.pi) % (2 * math.pi) - math.pi
      ship.yaw = ship.yaw + diff * math.min(1, dt * 4)
    end
    local lv = CFrame.Angles(0, ship.yaw, 0):VectorToObjectSpace(ship.vel)
    pitch = lv.Z / SHIP_SPEED * .25
    roll = -lv.X / SHIP_SPEED * .3
  end
  local bobY = (ship.state == "idle" or RIDING) and math.sin(now * 2) * .12 or 0
  ship.cf = CFrame.new(ship.pos + V3(0, bobY, 0)) * CFrame.Angles(0, ship.yaw, 0) * CFrame.Angles(pitch, 0, roll)
  ship.model:PivotTo(ship.cf)
  if RIDING and hr then
    hr.CFrame = ship.cf * SEAT
    hr.AssemblyLinearVelocity = V3()
    hr.AssemblyAngularVelocity = V3()
  end
end
track(RunService.RenderStepped:Connect(function(dt) stepShip(dt) end))

local ridePanel = I("Frame", {
  Size = UDim2.fromOffset(70, 140), Position = UDim2.new(1, -90, 1, -290), BackgroundTransparency = 1,
  Visible = false, ZIndex = 58,
}, gui)
local function rideBtn(txt, y, key)
  local b = I("TextButton", {
    Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, y), BackgroundColor3 = C.bg, BackgroundTransparency = .15,
    TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 26, Text = txt, ZIndex = 59,
  }, ridePanel)
  cr(b, 16)
  sk(b, C.ac, 1.5, .3)
  b.MouseButton1Down:Connect(function() rideKeys[key] = true end)
  b.MouseButton1Up:Connect(function() rideKeys[key] = false end)
  b.MouseLeave:Connect(function() rideKeys[key] = false end)
end
rideBtn("▲", 0, "up")
rideBtn("▼", 72, "down")
local dismountBtn = I("TextButton", {
  Size = UDim2.fromOffset(120, 40), Position = UDim2.new(.5, -60, 0, 12), BackgroundColor3 = C.bg, BackgroundTransparency = .15,
  TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 13, Text = "🚪 Слезть", Visible = false, ZIndex = 59,
}, gui)
cr(dismountBtn, 10)
sk(dismountBtn, C.ac, 1.5, .3)
dismountBtn.MouseButton1Click:Connect(function() dismount() end)
track(UIS.InputBegan:Connect(function(i, gpe)
  if gpe then return end
  if i.KeyCode == Enum.KeyCode.Space then rideKeys.up = true end
  if i.KeyCode == Enum.KeyCode.LeftShift then rideKeys.down = true end
end))
track(UIS.InputEnded:Connect(function(i)
  if i.KeyCode == Enum.KeyCode.Space then rideKeys.up = false end
  if i.KeyCode == Enum.KeyCode.LeftShift then rideKeys.down = false end
end))

local ITEMS = {
  { id = "gun", ico = "🔫", name = "Портальная пушка", desc = "Два больших портала", build = buildGun, act = shootPortal, grip = V3(0, -.05, 0) },
  { id = "freeze", ico = "❄", name = "Замораживатель времени", desc = "Пузырь и стоп-кадр на 4 с", build = buildFreezer, act = timeStop, grip = V3(0, -.1, 0) },
  { id = "meeseeks", ico = "🟦", name = "Ящик Мисиксов", desc = "Вызывает помощника", build = buildMeeseeksBox, act = spawnMeeseeks, grip = V3(0, -.55, -.15) },
  { id = "battery", ico = "🔋", name = "Батарея микровселенной", desc = "Зона энергии 15 с", build = buildBattery, act = useBattery, grip = V3(0, -.5, -.1) },
  { id = "ship", ico = "🚀", name = "Пульт крейсера", desc = "Вызвать, сесть, лететь", build = buildRemote, act = shipAction, grip = V3(0, -.05, 0) },
}
local function giveItem(def)
  detachHand()
  if heldTool then pcall(function() heldTool:Destroy() end) end
  heldTool, heldDef, ITEM_ACT, batLabel = nil, nil, nil, nil
  local _, hum = getChar()
  if not hum then notify("Нет персонажа", C.dg) return end
  local tool, extra = def.build()
  heldTool, heldDef = tool, def
  if def.id == "battery" then batLabel = extra end
  tool.Parent = LP.Backpack
  tool.Activated:Connect(function() safe(def.act) end)
  tool.Equipped:Connect(function()
    ITEM_ACT = def.act
    task.defer(function() attachHand(tool, def.grip) end)
  end)
  tool.Unequipped:Connect(function()
    ITEM_ACT = nil
    detachHand()
  end)
  hum:EquipTool(tool)
  notify(def.ico .. " " .. def.name, C.ac)
end
RM.fireFromAim = function()
  if ITEM_ACT then ITEM_ACT() else shootPortal() end
end
local function clearAll()
  detachHand()
  if heldTool then pcall(function() heldTool:Destroy() end) end
  heldTool, heldDef, ITEM_ACT, batLabel = nil, nil, nil, nil
  for i = #helpers, 1, -1 do
    pcall(function() helpers[i].R.model:Destroy() end)
    table.remove(helpers, i)
  end
  for i = #zones, 1, -1 do
    pcall(function() zones[i].mo:Destroy() end)
    table.remove(zones, i)
  end
  if RIDING then dismount() end
  if ship then pcall(function() ship.model:Destroy() end) ship = nil end
  ridePanel.Visible = false
  dismountBtn.Visible = false
  killPortal(PA)
  killPortal(PB)
  PA, PB = nil, nil
end

do -- 🎭 СКИНЫ
  local f = tabFrames.skins
  newSec(f, "ЗАМЕНА ТЕЛА (Motor6D, 8 скинов)")
  for _, id in ipairs(SKIN_ORDER) do
    local S = SK[id]
    local b = newBtn(f, "", C.bg2, function() applySkin(id) end, 40)
    I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
      Text = S.ico .. " " .. S.name, TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 11,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
    I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 22), BackgroundTransparency = 1,
      Text = S.desc, TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 9,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
  end
  newSec(f, "ВЫРАЖЕНИЕ ЛИЦА")
  local gr = newGrid(f, 3)
  for _, e in ipairs(EM) do
    newBtn(gr, e[2], C.bg2, function() setEmo(e[1]) end, 32).TextSize = 11
  end
  newBtn(f, "↩ Вернуть своё тело", C.bg2, removeSkin, 34).TextColor3 = C.dg
end

do -- 🕺 ДВИЖЕНИЯ
  local f = tabFrames.moves
  newSec(f, "ЭМОЦИИ ТЕЛА (стой на месте)")
  local gr = newGrid(f, 2)
  local EMS = {
    { "wave", "👋 Махать" }, { "dance", "🕺 Танец" }, { "drunk", "🥴 Пьяная походка" },
    { "think", "🤔 Думать" }, { "victory", "🙌 Победа" }, { "facepalm", "🤦 Фейспалм" },
  }
  for _, e in ipairs(EMS) do
    newBtn(gr, e[2], C.bg2, function()
      if not RIG then notify("Сначала надень скин", C.dg, 2) return end
      EMOTE = e[1]
    end, 34)
  end
  newBtn(f, "⏹ Остановить движение", C.bg2, function() EMOTE = nil end, 32)
  newSec(f, "РЕПЛИКИ (пузырь над головой)")
  local pg = newGrid(f, 2)
  local PHR = {
    "Wubba lubba dub dub!", "И вот так, Морти!", "Aw jeez, Рик!", "Я Мистер Мисикс!",
    "Быстрее, в портал!", "Это не сон, это физика.",
  }
  for _, p in ipairs(PHR) do
    newBtn(pg, p, C.bg2, function() say(p) end, 38).TextSize = 10
  end
  newInfo(f, "\n  Ходьба, бег, прыжок, посадка в крейсер,\n  хват предмета и моргание включены всегда.\n  Эмоция тела сбрасывается, когда начинаешь идти.", 70)
end

do -- 🧰 ПРЕДМЕТЫ
  local f = tabFrames.items
  newSec(f, "ПРЕДМЕТЫ (держатся рукой скина)")
  for _, def in ipairs(ITEMS) do
    local b = newBtn(f, "", C.bg2, function() giveItem(def) end, 40)
    I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
      Text = def.ico .. " " .. def.name, TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 11,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
    I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 22), BackgroundTransparency = 1,
      Text = def.desc, TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 9,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
  end
  
  newSec(f, "ПРИКАЗЫ МИСИКСАМ (идут туда, куда смотришь)")
  local og = newGrid(f, 2)
  newBtn(og, "🛡 Защищай меня", C.ac, function() RM.helperOrder("guard") end, 36)
  newBtn(og, "⚔ Атакуй цель", C.bg2, function() RM.helperOrder("attack") end, 36)
  newBtn(og, "📍 Иди туда", C.bg2, function() RM.helperOrder("move") end, 36)
  newBtn(og, "🚶 За мной", C.bg2, function() RM.helperOrder("follow") end, 36)
  newBtn(og, "🛑 Стой", C.bg2, function() RM.helperOrder("stay") end, 36)
  newBtn(og, "💨 Исчезни", C.dg, function() RM.helperOrder("vanish") end, 36)
  newBtn(f, "🎯 Поставить мишень (куда смотришь)", C.bg2, function() RM.spawnDummy() end, 34)
  newBtn(f, "🗑 Убрать мишени", C.bg2, function() RM.clearDummies() end, 34)

  newSec(f, "КРЕЙСЕР")
  newBtn(f, "🚀 Вызвать крейсер", C.ac, summonShip, 36)
  newBtn(f, "🪑 Сесть", C.bg2, board, 34)
  newBtn(f, "🚪 Слезть", C.bg2, dismount, 34)
  newBtn(f, "🗑 Убрать всё (предметы, помощники, крейсер)", C.dg, function()
    clearAll()
    notify("🗑 Всё убрано", C.tx)
  end, 36)
  newInfo(f, "\n  Нажми на предмет, затем ЛКМ или 🔥 на экране.\n  Ящик Мисиксов: помощник бежит к точке прицела.\n  Батарея: зона энергии, расход 25% заряда.\n  Крейсер: пульт вызывает, второй клик садит.\n  Всё видишь только ты.", 100)
end

do -- 🌀 ПОРТАЛ
  local f = tabFrames.portal
  newSec(f, "ПОРТАЛЫ")
  newBtn(f, "🔫 Портальная пушка", C.ac, function() giveItem(ITEMS[1]) end, 40)
  newBtn(f, "🔥 Создать портал", C.bg2, shootPortal, 40)
  newBtn(f, "🗑 Удалить оба портала", C.dg, function()
    killPortal(PA)
    killPortal(PB)
    PA, PB = nil, nil
    notify("🗑 Порталы удалены", C.tx)
  end, 34)
  newBtn(f, "🌌 Тест эффекта перехода", C.bg2, function() dimFx(nil, 1) end, 34)
  newSec(f, "КАК РАБОТАЕТ")
  newInfo(f, "\n  Портал большой (диаметр 12 стадов).\n  Коснулся любой части портала — телепорт сразу.\n  1-й выстрел — A, 2-й — B, дальше заменяется старый.\n  Выходной портал не сработает, пока ты из него не выйдешь.\n  Порталы исчезают через 60 с.", 108)
end

do -- ⚙️ НАСТРОЙКИ
  local f = tabFrames.settings
  newSec(f, "ЗВУК")
  local sb
  sb = newBtn(f, "🔊 Звуки: " .. (ST.SoundEnabled and "ВКЛ" or "ВЫКЛ"), C.bg2, function()
    ST.SoundEnabled = not ST.SoundEnabled
    sb.Text = "🔊 Звуки: " .. (ST.SoundEnabled and "ВКЛ" or "ВЫКЛ")
    save()
  end, 32)
  newSec(f, "ЭФФЕКТ ПЕРЕХОДА")
  local fb
  fb = newBtn(f, "🌌 Эффект: " .. (ST.DimFx and "ВКЛ" or "ВЫКЛ"), C.bg2, function()
    ST.DimFx = not ST.DimFx
    fb.Text = "🌌 Эффект: " .. (ST.DimFx and "ВКЛ" or "ВЫКЛ")
    save()
  end, 32)
  newSec(f, "ЦВЕТ ПОРТАЛОВ")
  local PC = {
    { "🟢 Зелёный", { R = 50, G = 255, B = 50 } }, { "🔵 Синий", { R = 50, G = 150, B = 255 } },
    { "🟣 Фиолет", { R = 180, G = 50, B = 255 } }, { "🟡 Жёлтый", { R = 255, G = 220, B = 50 } },
    { "🔴 Красный", { R = 255, G = 60, B = 60 } },
  }
  local pi = 1
  for i, p in ipairs(PC) do
    if p[2].R == ST.PortalColor.R and p[2].G == ST.PortalColor.G then pi = i break end
  end
  local pb
  pb = newBtn(f, "🎨 " .. PC[pi][1], C.bg2, function()
    pi = pi % #PC + 1
    ST.PortalColor = PC[pi][2]
    pb.Text = "🎨 " .. PC[pi][1]
    save()
    notify("🎨 Цвет изменён", C.ac)
  end, 32)
  newSec(f, "ПРИЦЕЛ")
  local AS = { 50, 64, 80, 100 }
  local ai = 1
  for i, v in ipairs(AS) do
    if v == ST.AimSize then ai = i break end
  end
  local ab
  ab = newBtn(f, "🎯 Размер прицела: " .. ST.AimSize, C.bg2, function()
    ai = ai % #AS + 1
    ST.AimSize = AS[ai]
    ab.Text = "🎯 Размер прицела: " .. ST.AimSize
    aimF.Size = UDim2.fromOffset(ST.AimSize, ST.AimSize)
    save()
  end, 32)
  newSec(f, "СБРОС")
  newBtn(f, "🔄 Сбросить всё", C.dg, function()
    ST.SoundEnabled, ST.NotificationsEnabled, ST.DimFx = true, true, true
    ST.PortalColor = { R = 50, G = 255, B = 50 }
    ST.AimSize, ST.Emotion = 64, "normal"
    removeSkin()
    clearAll()
    sb.Text = "🔊 Звуки: ВКЛ"
    fb.Text = "🌌 Эффект: ВКЛ"
    pi, ai = 1, 2
    pb.Text = "🎨 " .. PC[1][1]
    ab.Text = "🎯 Размер прицела: 64"
    aimF.Size = UDim2.fromOffset(64, 64)
    save()
    notify("🔄 Сброшено", C.ok)
  end, 34)
  newSec(f, "ВЫХОД")
  newBtn(f, "❌ ВЫГРУЗИТЬ СКРИПТ", C.dg, function() RM.unload() end, 36)
  newSec(f, "О СКРИПТЕ")
  newInfo(f, "\n  Rick & Morty Toolkit v" .. RM._version .. "\n  8 скинов, 12 лиц, 6 эмоций тела, 5 предметов.\n  Всё локально: другие игроки этого не видят.", 80)
end
switchTab("skins")

do
  local acc, acc2 = 0, 0
  track(RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    local _, _, hr = getChar()
    if hr and PA and PB and now >= tpCd and not RIDING then
      local inA, inB = playerInPortal(PA, hr), playerInPortal(PB, hr)
      if not inA then PA.locked = false end
      if not inB then PB.locked = false end
      if now - PA.t0 > .25 and now - PB.t0 > .25 then
        if inA and not PA.locked then
          teleportTo(hr, PA, PB)
        elseif inB and not PB.locked then
          teleportTo(hr, PB, PA)
        end
      end
    end
    acc = acc + dt
    if acc >= .033 then
      acc = 0
      if PA then updPortal(PA, now - PA.t0) end
      if PB then updPortal(PB, now - PB.t0) end
    end
    if PA and now - PA.t0 > PORTAL_LIFE then killPortal(PA) PA = nil end
    if PB and now - PB.t0 > PORTAL_LIFE then killPortal(PB) PB = nil end
    for i = #helpers, 1, -1 do
      local h = helpers[i]
      local ok, alive = pcall(stepHelper, h, dt)
      if not ok or not alive then
        pcall(function() h.R.model:Destroy() end)
        table.remove(helpers, i)
      end
    end
    BAT = math.min(100, BAT + dt * 4)
    acc2 = acc2 + dt
    if acc2 >= .25 then
      acc2 = 0
      updateZones(hr, now)
      if batLabel and batLabel.Parent then batLabel.Text = math.floor(BAT) .. "%" end
      ridePanel.Visible = RIDING
      dismountBtn.Visible = RIDING
    end
  end))
end

function RM.unload()
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  conns = {}
  clearAll()
  clearSkin()
  pcall(function() helperFolder:Destroy() end)
  pcall(function() sfx:Destroy() end)
  pcall(function() gui:Destroy() end)
  if ccFx then pcall(function() ccFx:Destroy() end) end
  if ccStop then pcall(function() ccStop:Destroy() end) end
  local _, hum, hr = getChar()
  if hum then hum.PlatformStand = false end
  if hr then
    local aura = hr:FindFirstChild("RM_Aura")
    if aura then aura:Destroy() end
  end
  if G.RickMorty == RM then G.RickMorty = nil end
  warn("[RickMorty] выгружен")
end

if ST.ActiveSkin ~= "" then
  task.delay(2, function() safe(applySkin, ST.ActiveSkin) end)
end
notify("🌀 Rick & Morty v" .. RM._version .. " загружен", C.ac, 4)
warn("[RickMorty v" .. RM._version .. "] загружен. Прицел: " .. (mob and "мобильный" or "ПК"))
return RM
