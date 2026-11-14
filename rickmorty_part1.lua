-- ============================================================
--  Rick & Morty Toolkit v5.0 (standalone, один файл)
--  v5.0: новые порталы, 3 новые пушки с анимацией выстрела, новые предметы
--  (генератор Мисиксов, шлем Рика, энергощит), надёжная выгрузка, проверка настроек
--  Скины на Motor6D, мимика, движения, портальная пушка,
--  большие порталы с мгновенным касанием, замораживатель времени,
--  ящик Мисиксов, батарея микровселенной, космический крейсер,
--  эффект перехода между измерениями. Без 18+.
--  Всё создаётся локально: видишь только ты.
-- ============================================================
local G = rawget(_G, "getgenv") and getgenv() or _G
if G.RickMorty and G.RickMorty.unload then pcall(G.RickMorty.unload) end
local RM = { _version = "5.0" }
local TK = {} -- общее хранилище функций и состояния (все части скрипта работают через него)
G.RickMorty = RM

TK.Players = game:GetService("Players")
TK.RunService = game:GetService("RunService")
TK.TweenService = game:GetService("TweenService")
TK.UIS = game:GetService("UserInputService")
TK.HttpService = game:GetService("HttpService")
TK.Workspace = game:GetService("Workspace")
TK.SoundService = game:GetService("SoundService")
TK.Lighting = game:GetService("Lighting")
TK.LP = TK.Players.LocalPlayer
TK.PlayerGui = TK.LP:WaitForChild("PlayerGui")
TK.V3, TK.RGB = Vector3.new, Color3.fromRGB
TK.WHITE, TK.BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

TK.conns = {}
function TK.track(c) TK.conns[#TK.conns + 1] = c return c end
TK.X, TK.ITM, TK.DYING, TK.DEAD = {}, {}, {}, false -- X: мелкое состояние v5; ITM: новые предметы; DYING: закрывающиеся порталы
TK.fxFolder = Instance.new("Folder") -- все временные эффекты лежат тут и чистятся при выгрузке
TK.fxFolder.Name = "RM_Fx"
TK.fxFolder.Parent = TK.Workspace

-- общее состояние
TK.RIG, TK.HOLDING, TK.RIDING, TK.EMOTE = nil, false, false, nil
TK.ITEM_ACT, TK.heldTool, TK.heldDef, TK.gripW, TK.gripC, TK.batLabel = nil, nil, nil, nil, nil, nil
TK.PA, TK.PB, TK.tpCd = nil, nil, 0
TK.ship, TK.helpers, TK.zones = nil, {}, {}
TK.TIMESTOP_UNTIL, TK.TS_CD, TK.BAT, TK.inZone = 0, 0, 100, false
TK.rideKeys = { up = false, down = false }
TK.PORTAL_LIFE = 60
TK.CB = {} -- боевой модуль (заполняется ниже)
TK.SH = { fireCd = 0, hyperCd = 0, side = 1, held = false } -- функции и состояние крейсера
TK.PORTAL_R = 6 -- радиус портала в стадах (диаметр 12)
TK.detachHand, TK.attachHand, TK.refreshGrip, TK.board, TK.dismount, TK.giveItem = nil, nil, nil, nil, nil, nil  -- объявлены заранее

function TK.copy(t)
  local n = {}
  for k, v in pairs(t) do n[k] = v end
  return n
end
function TK.getChar()
  local ch = TK.LP.Character
  return ch, ch and ch:FindFirstChildOfClass("Humanoid"), ch and ch:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
--  НАСТРОЙКИ (сохраняются в файл, если executor умеет writefile)
-- ============================================================
TK.HAS_FS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
TK.FILE = "rickmorty_v40.json"
TK.ST = {
  SoundEnabled = true, NotificationsEnabled = true, NotifDuration = 2, MenuKey = "RightShift",
  PortalColor = { R = 50, G = 255, B = 50 }, ActiveSkin = "", AimSize = 64, Emotion = "normal", DimFx = true,
  ShipSpeed = 150, AttackPlayers = true,
}
RM.SETTINGS = TK.ST
function TK.save()
  if TK.HAS_FS then pcall(writefile, TK.FILE, TK.HttpService:JSONEncode(TK.ST)) end
end
TK.DEFAULTS = TK.copy(TK.ST)
TK.DEFAULTS.PortalColor = TK.copy(TK.ST.PortalColor)
function TK.validSetting(k, v) -- nil = значение не подходит, оставляем по умолчанию
  local dv = TK.DEFAULTS[k]
  if dv == nil or type(v) ~= type(dv) then return nil end
  if type(v) == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return nil end
    if k == "AimSize" then return math.clamp(v, 24, 200) end
    if k == "NotifDuration" then return math.clamp(v, .5, 10) end
    if k == "ShipSpeed" then return math.clamp(v, 50, 1000) end
    return v
  elseif type(v) == "table" then
    if k ~= "PortalColor" then return nil end
    local r, g, b = tonumber(v.R), tonumber(v.G), tonumber(v.B)
    if not (r and g and b) then return nil end
    return { R = math.clamp(math.floor(r), 0, 255), G = math.clamp(math.floor(g), 0, 255), B = math.clamp(math.floor(b), 0, 255) }
  elseif type(v) == "string" then
    if #v > 40 then return nil end
  end
  return v
end
function TK.resetSettings()
  for k, v in pairs(TK.DEFAULTS) do
    TK.ST[k] = type(v) == "table" and TK.copy(v) or v
  end
end
if TK.HAS_FS then
  pcall(function()
    if isfile(TK.FILE) then
      local d = TK.HttpService:JSONDecode(readfile(TK.FILE))
      if type(d) == "table" then
        for k, v in pairs(d) do
          local ok = TK.validSetting(k, v)
          if ok ~= nil then TK.ST[k] = ok end
        end
      end
    end
  end)
end

-- ============================================================
--  ЗВУКИ
-- ============================================================
TK.sfx = Instance.new("Folder")
TK.sfx.Name = "RM_Sfx"
TK.sfx.Parent = TK.SoundService
TK.SFX = {
  shoot = "rbxassetid://12221967", click = "rbxasset://sounds/button.wav",
  notify = "rbxasset://sounds/electronicpingshort.wav", teleport = "rbxassetid://3314038600",
}
TK.SFX_ALIAS = { -- новые звуки = существующие с другим тоном
  open = { "teleport", 1.25 }, close = { "teleport", .75 }, pop = { "click", 1.7 }, vanish = { "teleport", 1.6 },
  equip = { "click", .85 },
}
function TK.snd(name, vol, pitch)
  if not TK.ST.SoundEnabled or TK.DEAD then return end
  local id = TK.SFX[name]
  if not id and TK.SFX_ALIAS[name] then
    id = TK.SFX[TK.SFX_ALIAS[name][1]]
    pitch = (pitch or 1) * TK.SFX_ALIAS[name][2]
  end
  if not id then return end
  pcall(function()
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = vol or .5
    s.PlaybackSpeed = pitch or 1
    s.Parent = TK.sfx
    s:Play()
    task.delay(4, function() s:Destroy() end)
  end)
end

-- ============================================================
--  UI: ХЕЛПЕРЫ И ЦВЕТА
-- ============================================================
TK.C = {
  bg = TK.RGB(18, 14, 28), bg2 = TK.RGB(28, 22, 42), ac = TK.RGB(100, 255, 140), ac2 = TK.RGB(150, 90, 255),
  ac3 = TK.RGB(120, 220, 255), tx = TK.RGB(240, 235, 255), dim = TK.RGB(150, 140, 180),
  dg = TK.RGB(255, 100, 120), ok = TK.RGB(120, 255, 160), st = TK.RGB(120, 90, 220),
}
function TK.I(class, props, parent)
  local o = Instance.new(class)
  for k, v in pairs(props) do o[k] = v end
  o.Parent = parent
  return o
end
function TK.cr(o, r) return TK.I("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
function TK.sk(o, col, th, tr) return TK.I("UIStroke", { Color = col, Thickness = th, Transparency = tr }, o) end

function TK.safeParent()
  local f = rawget(G, "gethui")
  if type(f) == "function" then
    local ok, h = pcall(f)
    if ok and h then return h end
  end
  local ok, cg = pcall(function() return game:GetService("CoreGui") end)
  if ok and cg then return cg end
  return TK.PlayerGui
end

TK.gui = TK.I("ScreenGui", {
  Name = "_RM_" .. math.random(100000, 999999), ResetOnSpawn = false, IgnoreGuiInset = true,
  DisplayOrder = 65, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
do
  local sy = rawget(G, "syn")
  if type(sy) == "table" and type(sy.protect_gui) == "function" then
    pcall(sy.protect_gui, TK.gui)
  elseif type(rawget(G, "protect_gui")) == "function" then
    pcall(G.protect_gui, TK.gui)
  end
end
if not pcall(function() TK.gui.Parent = TK.safeParent() end) or not TK.gui.Parent then TK.gui.Parent = TK.PlayerGui end

-- перетаскивание (мышь и палец)
function TK.drag(frame, area)
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
  TK.track(TK.UIS.InputChanged:Connect(function(i)
    if i == dInput and dragging then
      local d = i.Position - dStart
      frame.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
    end
  end))
end

-- уведомления
TK.nh = TK.I("Frame", {
  Size = UDim2.fromOffset(260, 300), Position = UDim2.new(1, -280, 1, -320),
  BackgroundTransparency = 1, ZIndex = 60,
}, TK.gui)
TK.I("UIListLayout", {
  VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
  Padding = UDim.new(0, 4),
}, TK.nh)
function TK.notify(text, col, dur)
  if not TK.ST.NotificationsEnabled then return end
  col = col or TK.C.ok
  dur = dur or TK.ST.NotifDuration
  local ch = TK.nh:GetChildren()
  if #ch > 9 then ch[2]:Destroy() end
  local f = TK.I("Frame", {
    Size = UDim2.fromOffset(250, 32), BackgroundColor3 = TK.C.bg, BackgroundTransparency = .1, ZIndex = 61,
  }, TK.nh)
  TK.cr(f, 8)
  TK.sk(f, col, 1.5, .2)
  TK.I("TextLabel", {
    Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
    Text = tostring(text), TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 62,
  }, f)
  TK.snd("notify", .4)
  task.delay(dur, function() if f.Parent then f:Destroy() end end)
end
RM.notify = TK.notify

-- запуск с показом ошибок (раньше ошибки молча глотались)
function TK.safe(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    warn("[RickMorty] " .. tostring(err))
    TK.notify("⚠ " .. tostring(err):sub(1, 70), TK.C.dg, 4)
  end
  return ok
end

-- ============================================================
--  ОКНО, ВКЛАДКИ
-- ============================================================
TK.mainBtn = TK.I("TextButton", {
  Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(20, 120), BackgroundColor3 = TK.C.bg,
  BackgroundTransparency = .05, TextColor3 = TK.C.ac, Font = Enum.Font.GothamBold, TextSize = 30,
  Text = "🌀", AutoButtonColor = false, ZIndex = 50,
}, TK.gui)
TK.cr(TK.mainBtn, 16)
TK.drag(TK.mainBtn)
do
  local s = TK.sk(TK.mainBtn, TK.C.ac, 2, .2)
  TK.I("UIGradient", {
    Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, TK.C.ac), ColorSequenceKeypoint.new(.5, TK.C.ac3), ColorSequenceKeypoint.new(1, TK.C.ac2),
    }), Rotation = 45,
  }, s)
end

TK.vp = TK.Workspace.CurrentCamera.ViewportSize
TK.WW, TK.WH = math.min(380, TK.vp.X - 20), math.min(520, TK.vp.Y - 30)
TK.win = TK.I("Frame", {
  Size = UDim2.fromOffset(TK.WW, TK.WH), Position = UDim2.fromOffset((TK.vp.X - TK.WW) / 2, 15), BackgroundColor3 = TK.C.bg,
  BackgroundTransparency = .02, Visible = false, ZIndex = 40,
}, TK.gui)
TK.cr(TK.win, 16)
TK.sk(TK.win, TK.C.st, 1.5, .25)
TK.I("UIGradient", { Color = ColorSequence.new(TK.C.bg2, TK.C.bg), Rotation = 90 }, TK.win)

TK.header = TK.I("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 41 }, TK.win)
TK.drag(TK.win, TK.header)
TK.I("TextLabel", {
  Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1,
  Text = "🌀 RICK & MORTY v" .. RM._version, TextColor3 = TK.C.ac, Font = Enum.Font.GothamBold, TextSize = 14,
  TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42,
}, TK.header)
TK.closeBtn = TK.I("TextButton", {
  Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0, 7), BackgroundColor3 = TK.C.dg,
  BackgroundTransparency = .5, TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 14, Text = "✕", ZIndex = 42,
}, TK.header)
TK.cr(TK.closeBtn, 8)
TK.winScale = TK.I("UIScale", { Scale = 1 }, TK.win)
TK.winWant, TK.winTick = false, 0
function TK.setWin(v)
  TK.winWant = v
  TK.winTick = TK.winTick + 1
  local id = TK.winTick
  if v then
    TK.win.Visible = true
    TK.winScale.Scale = .92
    TK.TweenService:Create(TK.winScale, TweenInfo.new(.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
  else
    TK.TweenService:Create(TK.winScale, TweenInfo.new(.15, Enum.EasingStyle.Quad), { Scale = .92 }):Play()
    task.delay(.16, function() if id == TK.winTick then TK.win.Visible = false end end)
  end
end
TK.closeBtn.MouseButton1Click:Connect(function() TK.setWin(false) end)
TK.mainBtn.MouseButton1Click:Connect(function() TK.setWin(not TK.winWant) end)

-- панель вкладок с горизонтальной прокруткой
TK.tabsBar = TK.I("ScrollingFrame", {
  Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 48), BackgroundTransparency = 1,
  ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
  ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 41,
}, TK.win)
TK.I("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, TK.tabsBar)
TK.content = TK.I("ScrollingFrame", {
  Size = UDim2.new(1, -16, 1, -120), Position = UDim2.fromOffset(8, 90), BackgroundTransparency = 1,
  ScrollBarThickness = 3, ScrollBarImageColor3 = TK.C.ac, CanvasSize = UDim2.new(),
  AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 41,
}, TK.win)
TK.I("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, TK.content)
TK.I("TextLabel", {
  Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -22), BackgroundTransparency = 1,
  Text = "v" .. RM._version .. " | скины | предметы | порталы", TextColor3 = TK.C.dim, Font = Enum.Font.Code,
  TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
}, TK.win)

function TK.newBtn(parent, text, col, fn, h)
  local b = TK.I("TextButton", {
    Size = UDim2.new(1, -8, 0, h or 36), BackgroundColor3 = col or TK.C.bg2, BackgroundTransparency = .1,
    TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 12, Text = text, TextWrapped = true, ZIndex = 42,
  }, parent)
  TK.cr(b, 8)
  TK.sk(b, TK.C.st, 1, .7)
  if fn then
    b.MouseButton1Click:Connect(function()
      TK.snd("click", .3)
      TK.safe(fn)
    end)
  end
  return b
end
function TK.newSec(parent, text)
  return TK.I("TextLabel", {
    Size = UDim2.new(1, -8, 0, 22), BackgroundTransparency = 1, Text = "▸ " .. text, TextColor3 = TK.C.ac3,
    Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42,
  }, parent)
end
function TK.newInfo(parent, text, h)
  local l = TK.I("TextLabel", {
    Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = TK.C.bg2, BackgroundTransparency = .2, Text = text,
    TextColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true, ZIndex = 42,
  }, parent)
  TK.cr(l, 8)
  return l
end
function TK.newGrid(parent, cols)
  local g = TK.I("Frame", {
    Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 41,
  }, parent)
  TK.I("UIGridLayout", {
    CellSize = UDim2.new(1 / cols, -4, 0, 34), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder,
  }, g)
  return g
end

-- ползунок со значениями + кнопки - и +
function TK.newSlider(parent, label, minV, maxV, value, onChange, onDone)
  local row = TK.I("Frame", {
    Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = TK.C.bg2, BackgroundTransparency = .1, ZIndex = 42,
  }, parent)
  TK.cr(row, 8)
  local lbl = TK.I("TextLabel", {
    Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 4), BackgroundTransparency = 1, Text = "",
    TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
  }, row)
  local bar = TK.I("Frame", {
    Size = UDim2.new(1, -90, 0, 12), Position = UDim2.fromOffset(45, 38), BackgroundColor3 = TK.C.bg, ZIndex = 43,
  }, row)
  TK.cr(bar, 6)
  local fill = TK.I("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = TK.C.ac, BorderSizePixel = 0, ZIndex = 44 }, bar)
  TK.cr(fill, 6)
  local knob = TK.I("Frame", {
    Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(0, .5),
    BackgroundColor3 = TK.WHITE, ZIndex = 45,
  }, bar)
  TK.cr(knob, 11)
  local function apply(v)
    local cur = math.clamp(math.floor(v / 10 + .5) * 10, minV, maxV)
    local a = (cur - minV) / (maxV - minV)
    fill.Size = UDim2.fromScale(a, 1)
    knob.Position = UDim2.fromScale(a, .5)
    lbl.Text = label .. ": " .. cur
    onChange(cur)
    return cur
  end
  local cur = apply(value)
  local function fromX(x)
    local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
    cur = apply(minV + (maxV - minV) * a)
  end
  local hit = TK.I("TextButton", {
    Size = UDim2.new(1, -90, 0, 34), Position = UDim2.fromOffset(45, 27), BackgroundTransparency = 1, Text = "", ZIndex = 46,
  }, row)
  local dragging = false
  hit.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      fromX(i.Position.X)
    end
  end)
  TK.track(TK.UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
      fromX(i.Position.X)
    end
  end))
  TK.track(TK.UIS.InputEnded:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
      dragging = false
      if onDone then onDone() end
    end
  end))
  local function stepBtn(txt, pos, d)
    local b = TK.I("TextButton", {
      Size = UDim2.fromOffset(34, 28), Position = pos, BackgroundColor3 = TK.C.bg, TextColor3 = TK.C.tx,
      Font = Enum.Font.GothamBold, TextSize = 18, Text = txt, ZIndex = 43,
    }, row)
    TK.cr(b, 8)
    b.MouseButton1Click:Connect(function()
      TK.snd("click", .3)
      cur = apply(cur + d)
      if onDone then onDone() end
    end)
  end
  stepBtn("−", UDim2.fromOffset(6, 30), -50)
  stepBtn("+", UDim2.new(1, -40, 0, 30), 50)
  return row
end

TK.TABS = {
  { "skins", "🎭 СКИНЫ", 84 }, { "moves", "🕺 ДВИЖЕНИЯ", 100 }, { "items", "🧰 ПРЕДМЕТЫ", 100 },
  { "portal", "🌀 ПОРТАЛ", 84 }, { "settings", "⚙️", 40 },
}
TK.tabBtns, TK.tabFrames = {}, {}
function TK.switchTab(id)
  for k, f in pairs(TK.tabFrames) do f.Visible = (k == id) end
  for k, b in pairs(TK.tabBtns) do
    local on = (k == id)
    b.BackgroundColor3 = on and TK.C.ac or TK.C.bg2
    b.TextColor3 = on and TK.C.bg or TK.C.tx
    b.BackgroundTransparency = on and 0 or .2
  end
  TK.content.CanvasPosition = Vector2.zero
end
for _, t in ipairs(TK.TABS) do
  local b = TK.I("TextButton", {
    Size = UDim2.fromOffset(t[3], 32), BackgroundColor3 = TK.C.bg2, BackgroundTransparency = .2, TextColor3 = TK.C.tx,
    Font = Enum.Font.GothamBold, TextSize = 10, Text = t[2], ZIndex = 42,
  }, TK.tabsBar)
  TK.cr(b, 8)
  TK.tabBtns[t[1]] = b
  b.MouseButton1Click:Connect(function() TK.snd("click", .3) TK.switchTab(t[1]) end)
  local f = TK.I("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    Visible = false, ZIndex = 41,
  }, TK.content)
  TK.I("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
  TK.tabFrames[t[1]] = f
end
TK.track(TK.UIS.InputBegan:Connect(function(i, gpe)
  if not gpe and i.KeyCode.Name == TK.ST.MenuKey then TK.setWin(not TK.winWant) end
end))

-- ============================================================
--  ПРИЦЕЛ (кнопка 🔥 на телефоне стреляет текущим предметом)
-- ============================================================
TK.mob = TK.UIS.TouchEnabled and not TK.UIS.MouseEnabled
TK.aimF, TK.aimL, TK.aimE, TK.cross = nil, nil, nil, nil
function TK.screenPoint()
  if TK.mob then return TK.cross or TK.Workspace.CurrentCamera.ViewportSize / 2 end
  return TK.UIS:GetMouseLocation()
end
function RM.getAimDirection()
  local p = TK.screenPoint()
  local r = TK.Workspace.CurrentCamera:ViewportPointToRay(p.X, p.Y)
  return r.Direction, r.Origin
end
function TK.mkAim()
  local z, col = TK.ST.AimSize, TK.C.ac
  TK.aimF = TK.I("Frame", {
    Name = "RM_Aim", Size = UDim2.fromOffset(z, z), AnchorPoint = Vector2.new(.5, .5),
    Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1, Active = TK.mob, ZIndex = 55,
  }, TK.gui)
  local ring = TK.I("Frame", {
    Size = UDim2.fromScale(.8, .8), Position = UDim2.fromScale(.5, .5), AnchorPoint = Vector2.new(.5, .5),
    BackgroundTransparency = 1, ZIndex = 55,
  }, TK.aimF)
  TK.cr(ring, 999)
  TK.aimE = { TK.sk(ring, col, 1.5, .5) }
  local function box(size, pos)
    local f = TK.I("Frame", {
      Size = size, Position = pos, AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = col,
      BorderSizePixel = 0, ZIndex = 56,
    }, TK.aimF)
    TK.aimE[#TK.aimE + 1] = f
    return f
  end
  TK.cr(box(UDim2.fromOffset(4, 4), UDim2.fromScale(.5, .5)), 99)
  box(UDim2.new(0, 2, .19, 0), UDim2.fromScale(.5, .28))
  box(UDim2.new(0, 2, .19, 0), UDim2.fromScale(.5, .72))
  box(UDim2.new(.19, 0, 0, 2), UDim2.fromScale(.28, .5))
  box(UDim2.new(.19, 0, 0, 2), UDim2.fromScale(.72, .5))
  TK.aimL = TK.I("TextLabel", {
    Size = UDim2.fromOffset(150, 20), Position = UDim2.fromScale(.5, 1.25), AnchorPoint = Vector2.new(.5, 0),
    BackgroundTransparency = 1, TextColor3 = col, Font = Enum.Font.Code, TextSize = 12, Text = "0 st", ZIndex = 57,
  }, TK.aimF)
  local dg = false
  TK.aimF.InputBegan:Connect(function(i)
    if TK.mob and i.UserInputType == Enum.UserInputType.Touch then dg = true end
  end)
  TK.track(TK.UIS.InputChanged:Connect(function(i)
    if dg and i.UserInputType == Enum.UserInputType.Touch then TK.cross = i.Position end
  end))
  TK.track(TK.UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch then dg = false end
  end))
  if TK.mob then
    local fb = TK.I("TextButton", {
      Name = "RM_Fire", Size = UDim2.fromOffset(70, 70), Position = UDim2.new(1, -90, 1, -130),
      BackgroundColor3 = TK.RGB(255, 60, 80), BackgroundTransparency = .2, Text = "🔥", TextColor3 = TK.WHITE,
      Font = Enum.Font.GothamBold, TextSize = 35, ZIndex = 55,
    }, TK.gui)
    TK.cr(fb, 99)
    TK.sk(fb, col, 2, .3)
    TK.drag(fb)
    fb.MouseButton1Click:Connect(function()
      if RM.fireFromAim then TK.safe(RM.fireFromAim) end
      fb.Size = UDim2.fromOffset(60, 60)
      task.delay(.1, function() fb.Size = UDim2.fromOffset(70, 70) end)
    end)
  end
end
TK.mkAim()
do
  local acc = 0
  TK.track(TK.RunService.RenderStepped:Connect(function(dt)
    if not TK.aimF then return end
    local p = TK.screenPoint()
    TK.aimF.Position = UDim2.fromOffset(p.X, p.Y)
    acc = acc + dt
    if acc < .1 then return end
    acc = 0
    local ch, _, hr = TK.getChar()
    if not hr then return end
    local r = TK.Workspace.CurrentCamera:ViewportPointToRay(p.X, p.Y)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { ch }
    local res = TK.Workspace:Raycast(r.Origin, r.Direction * 1000, rp)
    local tp = res and res.Position or r.Origin + r.Direction * 1000
    TK.aimL.Text = math.floor((tp - hr.Position).Magnitude) .. " st"
    local m = res and res.Instance:FindFirstAncestorOfClass("Model")
    local hit = m and TK.Players:GetPlayerFromCharacter(m)
    local col = hit and TK.RGB(255, 80, 80) or TK.C.ac
    TK.aimL.TextColor3 = col
    for _, e in ipairs(TK.aimE) do
      if e:IsA("UIStroke") then e.Color = col else e.BackgroundColor3 = col end
    end
  end))
end

-- ============================================================
--  ЭФФЕКТЫ: искры, ПЕРЕХОД МЕЖДУ ИЗМЕРЕНИЯМИ, пузыри речи
-- ============================================================
-- Пушка по скинам (v4.2): дальность и цвет порталов, пока скин активен
TK.GUN_CFG = {
  rick = { range = 1000, col = TK.RGB(50, 255, 50) },
  rick_prime = { range = 10000, col = TK.RGB(50, 255, 50) },
  evil_morty = { range = 700, col = TK.RGB(255, 220, 50) },
}
function TK.gunCfg()
  return TK.GUN_CFG[TK.ST.ActiveSkin]
end
function TK.pcol()
  local g = TK.gunCfg()
  if g and g.col then return g.col end
  local c = TK.ST.PortalColor
  return TK.RGB(c.R, c.G, c.B)
end
function TK.burst(pos, col, count)
  local p = TK.I("Part", {
    Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
    Size = TK.V3(.2, .2, .2), Position = pos,
  }, TK.fxFolder)
  local e = TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0, Lifetime = NumberRange.new(.3, .7),
    Speed = NumberRange.new(8, 20), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(1.2, 0),
    LightEmission = 1, Color = ColorSequence.new(col),
  }, p)
  e:Emit(count or 24)
  task.delay(1.2, function() p:Destroy() end)
end

TK.ccFx, TK.fovBusy = nil, false
function TK.flicker(R) -- мерцание скина при переходе
  if not R then return end
  task.spawn(function()
    for i = 1, 6 do
      local on = (i % 2 == 0)
      for _, p in ipairs(R.all) do
        if p.Parent then p.LocalTransparencyModifier = on and 0 or .85 end
      end
      task.wait(.05)
    end
    for _, p in ipairs(R.all) do
      if p.Parent then p.LocalTransparencyModifier = 0 end
    end
  end)
end
-- вспышка, расходящиеся кольца, цветокоррекция, рывок FOV, мерцание тела
function TK.dimFx(col, power)
  if not TK.ST.DimFx then return end
  power = power or 1
  col = col or TK.pcol()
  if not TK.ccFx or not TK.ccFx.Parent then TK.ccFx = TK.I("ColorCorrectionEffect", { Name = "RM_DimFx" }, TK.Lighting) end
  TK.TweenService:Create(TK.ccFx, TweenInfo.new(.15), {
    TintColor = col:Lerp(TK.WHITE, .35), Saturation = 1.2 * power, Contrast = .35 * power, Brightness = .12 * power,
  }):Play()
  task.delay(.18, function()
    if TK.ccFx and TK.ccFx.Parent then
      TK.TweenService:Create(TK.ccFx, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TintColor = TK.WHITE, Saturation = 0, Contrast = 0, Brightness = 0,
      }):Play()
    end
  end)
  local fl = TK.I("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = col:Lerp(TK.WHITE, .6), BackgroundTransparency = .35,
    BorderSizePixel = 0, ZIndex = 90,
  }, TK.gui)
  TK.TweenService:Create(fl, TweenInfo.new(.6), { BackgroundTransparency = 1 }):Play()
  task.delay(.7, function() fl:Destroy() end)
  for i = 1, 3 do
    task.delay((i - 1) * .09, function()
      local r = TK.I("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1, ZIndex = 91,
      }, TK.gui)
      TK.cr(r, 999)
      local s = TK.sk(r, col:Lerp(TK.WHITE, i * .15), 4, 0)
      TK.TweenService:Create(r, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(1800, 1800),
      }):Play()
      TK.TweenService:Create(s, TweenInfo.new(.7), { Transparency = 1 }):Play()
      task.delay(.8, function() r:Destroy() end)
    end)
  end
  local camObj = TK.Workspace.CurrentCamera
  if camObj and not TK.fovBusy then
    TK.fovBusy = true
    local base = camObj.FieldOfView
    TK.TweenService:Create(camObj, TweenInfo.new(.12), { FieldOfView = base + 18 }):Play()
    task.delay(.14, function()
      TK.TweenService:Create(camObj, TweenInfo.new(.55, Enum.EasingStyle.Quad), { FieldOfView = base }):Play()
    end)
    task.delay(.8, function() TK.fovBusy = false end)
  end
  TK.flicker(TK.RIG)
end
RM.dimFx = TK.dimFx

function TK.bubble(adornee, text, secs) -- пузырь с репликой над головой
  if not adornee or not adornee.Parent then return end
  local old = adornee:FindFirstChild("RM_Bubble")
  if old then old:Destroy() end
  local bb = TK.I("BillboardGui", {
    Name = "RM_Bubble", Size = UDim2.fromOffset(190, 44), StudsOffset = TK.V3(0, 2.6, 0), AlwaysOnTop = true,
    LightInfluence = 0, MaxDistance = 90,
  }, adornee)
  local f = TK.I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = TK.RGB(250, 250, 255), BackgroundTransparency = .05 }, bb)
  TK.cr(f, 10)
  TK.sk(f, TK.RGB(30, 30, 40), 2, 0)
  TK.I("TextLabel", {
    Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), BackgroundTransparency = 1, Text = text,
    TextColor3 = TK.RGB(25, 25, 35), Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true,
  }, f)
  task.delay(secs or 3, function() if bb.Parent then bb:Destroy() end end)
end

-- ============================================================
--  ДЕТАЛИ, СУСТАВЫ
-- ============================================================
function TK.mkp(name, size, color, material, shape)
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
function TK.motor(a, b, c0, c1)
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
--  СКИНЫ: данные персонажей
-- ============================================================
TK.SK = {
  rick = {
    name = "Рик Санчес", ico = "🧪", desc = "Халат со складками, шипы, зубы, пальцы",
    skin = TK.RGB(190, 180, 180), hair = TK.RGB(165, 205, 240), shirt = TK.RGB(150, 215, 205), coat = TK.RGB(245, 245, 248),
    fold = TK.RGB(208, 210, 222), up = TK.RGB(245, 245, 248), fo = TK.RGB(245, 245, 248), cuff = TK.RGB(150, 215, 205),
    pants = TK.RGB(108, 96, 50), shoe = TK.RGB(78, 83, 92), sock = TK.RGB(245, 245, 245), belt = TK.RGB(60, 45, 30),
    buckle = TK.RGB(235, 190, 40), hs = TK.V3(1.4, 1.5, 1.25), ey = .15, ex = .3, er = .52, pr = .1, nl = .4, ny = -.05,
    open = true, brow = .3, hstyle = "spikes", pin = TK.RGB(255, 90, 90),
  },
  morty = {
    name = "Морти Смит", ico = "😰", desc = "Жёлтая футболка, большие глаза",
    skin = TK.RGB(238, 196, 156), hair = TK.RGB(125, 85, 52), shirt = TK.RGB(236, 226, 98), up = TK.RGB(236, 226, 98),
    fo = TK.RGB(238, 196, 156), pants = TK.RGB(48, 66, 112), shoe = TK.RGB(240, 240, 240), hs = TK.V3(1.6, 1.65, 1.4),
    ey = .05, ex = .33, er = .64, pr = .13, nl = .18, ny = -.2, hstyle = "morty", pack = TK.RGB(70, 100, 78),
  },
  rick_prime = {
    name = "Рик Прайм", ico = "💀", desc = "Куртка, полоски, ботинки, кобура",
    skin = TK.RGB(205, 195, 200), hair = TK.RGB(165, 205, 240), shirt = TK.RGB(112, 102, 148), jacket = true,
    pad = TK.RGB(160, 170, 200), stripe = TK.RGB(225, 50, 95), up = TK.RGB(48, 48, 78), fo = TK.RGB(48, 48, 78),
    cuff = TK.RGB(112, 102, 148), pants = TK.RGB(34, 34, 56), shoe = TK.RGB(82, 88, 118), belt = TK.RGB(70, 72, 100),
    holster = true, boot = true, hs = TK.V3(1.4, 1.5, 1.25), ey = .15, ex = .3, er = .55, pr = .11, nl = .35,
    ny = -.05, open = true, brow = .1, hstyle = "spikes",
  },
  jerry = {
    name = "Джерри Смит", ico = "🙂", desc = "Голубая рубашка, добрые глаза",
    skin = TK.RGB(238, 200, 170), hair = TK.RGB(110, 80, 55), shirt = TK.RGB(120, 170, 215), up = TK.RGB(120, 170, 215),
    fo = TK.RGB(120, 170, 215), pants = TK.RGB(135, 120, 90), shoe = TK.RGB(70, 60, 50), hs = TK.V3(1.5, 1.6, 1.35),
    ey = .08, ex = .32, er = .5, pr = .1, nl = .32, ny = -.15, hstyle = "morty", brow = .05,
  },
  summer = {
    name = "Саммер Смит", ico = "🧡", desc = "Рыжие длинные волосы, светлый топ",
    skin = TK.RGB(240, 200, 170), hair = TK.RGB(215, 105, 55), shirt = TK.RGB(245, 225, 235), up = TK.RGB(245, 225, 235),
    fo = TK.RGB(240, 200, 170), pants = TK.RGB(60, 90, 150), shoe = TK.RGB(240, 240, 240), hs = TK.V3(1.5, 1.6, 1.35),
    ey = .08, ex = .32, er = .56, pr = .11, nl = .16, ny = -.2, hstyle = "morty", longhair = true,
  },
  meeseeks = {
    name = "Мистер Мисикс", ico = "🟦", desc = "Голубой, лысый, огромная улыбка",
    skin = TK.RGB(120, 190, 235), hair = TK.RGB(90, 150, 200), shirt = TK.RGB(120, 190, 235), up = TK.RGB(120, 190, 235),
    fo = TK.RGB(120, 190, 235), pants = TK.RGB(60, 120, 180), shoe = TK.RGB(100, 170, 220), hs = TK.V3(1.5, 1.6, 1.3),
    ey = .2, ex = .32, er = .62, pr = .12, nl = .14, ny = -.15, open = true, hstyle = "none", brow = .05,
  },
  pickle = {
    name = "Огурчик Рик", ico = "🥒", desc = "Зелёный Рик с бородавками",
    skin = TK.RGB(120, 165, 60), hair = TK.RGB(80, 125, 45), shirt = TK.RGB(105, 150, 52), up = TK.RGB(105, 150, 52),
    fo = TK.RGB(105, 150, 52), pants = TK.RGB(95, 140, 48), shoe = TK.RGB(80, 120, 40), hs = TK.V3(1.4, 1.5, 1.25),
    ey = .15, ex = .3, er = .52, pr = .1, nl = .4, ny = -.05, open = true, brow = .45, hstyle = "none",
    warts = true, wart = TK.RGB(70, 105, 35),
  },
}
TK.SK.evil_morty = TK.copy(TK.SK.morty)
TK.SK.evil_morty.name = "Злой Морти"
TK.SK.evil_morty.ico = "🖤"
TK.SK.evil_morty.desc = "Повязка, руки в боки"
TK.SK.evil_morty.patch = true
TK.SK.evil_morty.hips = true
TK.SK.evil_morty.brow = .2
for id, S in pairs(TK.SK) do S.id = id end
TK.SKIN_ORDER = { "rick", "morty", "evil_morty", "rick_prime", "jerry", "summer", "meeseeks", "pickle" }

-- выражения лица (переопределяют значения по умолчанию)
TK.EM = {
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
function TK.dflt(S)
  return {
    eh = 1, pr = 1, by = 0, br = S.brow or 0, mw = 1, mo = S.open and .3 or .02, cr = S.open and .15 or 0,
    cy = 0, cs = 0, bq = 0, te = S.open and 1 or 0, tg = S.open and 1 or 0, tr = 0, px = 0, py = 0,
    sh = 0, wk = 0, hx = 0, hz = 0, w = S.open and .62 or .34,
  }
end
function TK.ftar(S, id)
  local t = TK.dflt(S)
  for _, e in ipairs(TK.EM) do
    if e[1] == id then
      for k, v in pairs(e[3]) do t[k] = v end
    end
  end
  return t
end

-- ============================================================
--  РИГ: сборка скелета на Motor6D (работает и для тебя, и для Мисиксов)
-- ============================================================
function TK.newRig(root, S, K)
  local R = {
    S = S, K = K, root = root, mot = {}, base = {}, fp = {}, all = {}, st = {}, lz = {}, parts = {},
    t = 0, ph = 0, nextBlink = 2, blinkEnd = 0,
  }
  local model = Instance.new("Model")
  model.Name = "RM_Rig"
  R.model = model
  local mot, base = R.mot, R.base
  local function kcf(o) -- смещение в стадах -> масштабированный CFrame
    if typeof(o) == "Vector3" then return CFrame.new(o * K) end
    return CFrame.new(o.Position * K) * o.Rotation
  end
  local function part(n, sz, col, mat, shape)
    local p = TK.mkp(n, sz * K, col, mat, shape)
    p.Parent = model
    R.all[#R.all + 1] = p
    return p
  end
  local function fixed(par, n, sz, col, o, mat, shape) -- неподвижная деталь
    local p = part(n, sz, col, mat, shape)
    TK.motor(par, p, kcf(o))
    return p
  end
  local function face(n, par, sz, col, o, mat, shape) -- подвижная деталь лица
    local p = part(n, sz, col, mat, shape)
    local m = TK.motor(par, p, kcf(o))
    mot[n] = m
    base[n] = m.C0
    R.fp[n] = p
    return p
  end
  local function limb(par, n, sz, col, o, mat, zo) -- сустав: деталь свисает вниз
    local p = part(n, sz, col, mat)
    local m = TK.motor(par, p, kcf(o), CFrame.new(0, sz.Y / 2 * K, (zo or 0) * K))
    mot[n] = m
    base[n] = m.C0
    return p
  end

  local sc, hs = S.skin, S.hs
  local T = part("Torso", TK.V3(1.8, 2, .9), S.shirt)
  mot.Torso = TK.motor(root, T, kcf(TK.V3(0, -.6, 0)), CFrame.new(0, -K, 0))
  base.Torso = mot.Torso.C0
  R.parts.Torso = T
  if S.belt then
    fixed(T, "Belt", TK.V3(1.86, .22, .96), S.belt, TK.V3(0, -.88, 0))
    fixed(T, "Buckle", TK.V3(.3, .2, .05), S.buckle or S.belt, TK.V3(0, -.88, -.5))
  end
  fixed(T, "Neck", TK.V3(.5, .3, .5), sc, TK.V3(0, 1.05, 0))
  if S.pin then -- значок на груди
    fixed(T, "Pin", TK.V3(.2, .2, .08), S.pin, TK.V3(-.55, .6, -.5), Enum.Material.Neon, Enum.PartType.Ball)
  end
  if S.pack then -- рюкзак за спиной + лямки
    fixed(T, "Pack", TK.V3(1.2, 1.5, .36), S.pack, TK.V3(0, .1, .66))
    for _, sx in ipairs({ -1, 1 }) do
      fixed(T, "Strap", TK.V3(.16, 1.7, .06), S.pack:Lerp(TK.BLACK, .5), TK.V3(sx * .6, .1, -.47))
    end
  end
  if S.warts then
    for i = 1, 6 do
      local a = i * 2.1
      fixed(T, "Wart", TK.V3(.2, .2, .14), S.wart or sc, TK.V3(math.sin(a) * .7, math.cos(a * 1.7) * .8, -.46))
    end
  end

  -- голова и лицо
  local H = part("Head", hs, sc)
  mot.Head = TK.motor(T, H, kcf(TK.V3(0, 1, 0)), CFrame.new(0, -hs.Y / 2 * K, 0))
  base.Head = mot.Head.C0
  R.parts.Head = H
  local fz = -hs.Z / 2
  for _, s in ipairs({ -1, 1 }) do
    local n = s < 0 and "L" or "R"
    face("fE" .. n, H, TK.V3(.08, S.er, S.er), TK.RGB(255, 255, 255),
      CFrame.new(s * S.ex, S.ey, fz - .02) * CFrame.Angles(0, math.rad(90), 0), nil, Enum.PartType.Cylinder)
    face("fP" .. n, H, TK.V3(1, 1, 1) * S.pr, TK.RGB(0, 0, 0), TK.V3(s * S.ex - s * .05, S.ey, fz - .08), nil, Enum.PartType.Ball)
    face("fB" .. n, H, TK.V3(S.ex * 1.4, .1, .1), S.hair, TK.V3(s * S.ex, S.ey + S.er / 2 + .12, fz - .03))
    face("fT" .. n, H, TK.V3(.09, .13, .06), TK.RGB(130, 205, 255), TK.V3(s * S.ex, S.ey - S.er / 2, fz - .06), nil,
      Enum.PartType.Ball).Transparency = 1
    fixed(H, "Ear", TK.V3(.14, .42, .28), sc, TK.V3(s * (hs.X / 2 + .04), -.05, .05))
  end
  fixed(H, "Nose", TK.V3(.16, S.nl, .2), sc, TK.V3(0, S.ny, fz - .08))
  local my = S.open and -.42 or -.45
  local mcol = S.open and TK.RGB(90, 20, 25) or TK.RGB(110, 50, 50)
  face("fMC", H, TK.V3(.3, .1, .05), mcol, TK.V3(0, my, fz - .02))
  face("fML", H, TK.V3(.2, .09, .05), mcol, TK.V3(-.15, my, fz - .025))
  face("fMR", H, TK.V3(.2, .09, .05), mcol, TK.V3(.15, my, fz - .025))
  face("fTe", H, TK.V3(.4, .08, .05), S.open and TK.RGB(215, 200, 120) or TK.RGB(240, 240, 235), TK.V3(0, my, fz - .05))
  face("fTg", H, TK.V3(.22, .1, .05), TK.RGB(220, 70, 90), TK.V3(.08, my, fz - .05))

  -- причёска
  local hst = S.hstyle or "morty"
  if hst == "spikes" then
    for i = 0, 12 do
      local a = math.rad(-120 + i * 20)
      local big = (i % 2 == 0)
      local d = TK.V3(math.sin(a), 0, math.cos(a))
      local p = d * TK.V3(hs.X * .42, 0, hs.Z * .42) + TK.V3(0, hs.Y * (big and .36 or .1), 0)
      local u = (d * (big and .5 or 1.1) + TK.V3(0, big and 1 or .45, 0)).Unit
      local L = (big and 1 or .8) + .2 * math.sin(i * 2.3)
      fixed(H, "Hair", TK.V3(.3, .3, L), S.hair, CFrame.lookAt(p, p + u) * CFrame.new(0, 0, -L / 2))
    end
    for _, x in ipairs({ -.35, 0, .35 }) do
      local p = TK.V3(x, hs.Y * .45, .15)
      local u = TK.V3(x * 1.4, 1, .1).Unit
      fixed(H, "Hair", TK.V3(.3, .3, .8), S.hair, CFrame.lookAt(p, p + u) * CFrame.new(0, 0, -.4))
    end
  elseif hst == "morty" then
    local back = S.longhair and 1.7 or .9
    local sideL = S.longhair and 1.3 or .5
    fixed(H, "Hair", TK.V3(hs.X + .1, .42, hs.Z + .1), S.hair, TK.V3(0, hs.Y / 2 - .12, .04))
    fixed(H, "Fringe", TK.V3(hs.X + .1, .22, .3), S.hair, TK.V3(0, hs.Y / 2 - .2, fz + .1))
    fixed(H, "HairB", TK.V3(hs.X + .1, back, .25), S.hair, TK.V3(0, hs.Y / 2 - back / 2 - .1, hs.Z / 2))
    for _, s in ipairs({ -1, 1 }) do
      fixed(H, "Sideburn", TK.V3(.12, sideL, .45), S.hair, TK.V3(s * (hs.X / 2 + .03), hs.Y / 2 - sideL / 2 - .1, .15))
    end
  end
  if S.patch then -- повязка Злого Морти
    local dk = TK.RGB(12, 12, 12)
    fixed(H, "Patch", TK.V3(.1, .7, .7), dk, CFrame.new(S.ex, S.ey, fz - .07) * CFrame.Angles(0, math.rad(90), 0), nil, Enum.PartType.Cylinder)
    fixed(H, "StrapF", TK.V3(hs.X + .08, .09, .07), dk, CFrame.new(0, S.ey + .1, fz - .03) * CFrame.Angles(0, 0, -.3))
    fixed(H, "StrapB", TK.V3(hs.X + .08, .09, .07), dk, TK.V3(0, S.ey + .1, hs.Z / 2 + .03))
    for _, s in ipairs({ -1, 1 }) do
      fixed(H, "StrapS", TK.V3(.07, .09, hs.Z + .06), dk, TK.V3(s * (hs.X / 2 + .04), S.ey + .1, 0))
    end
  end

  -- халат (полы качаются при ходьбе)
  if S.coat then
    local c = S.coat
    for _, s in ipairs({ -1, 1 }) do
      fixed(T, "CoatS", TK.V3(.14, 2, 1.05), c, TK.V3(s * .95, 0, .02))
      fixed(T, "Lapel", TK.V3(.38, 1.5, .08), c, CFrame.new(s * .5, .2, -.5) * CFrame.Angles(0, 0, s * .1))
      limb(T, s < 0 and "TL" or "TR", TK.V3(.14, 1.35, 1), c, TK.V3(s * .95, -.95, .02))
    end
    fixed(T, "CoatB", TK.V3(1.95, 2, .14), c, TK.V3(0, 0, .5))
    fixed(T, "Collar", TK.V3(1.9, .26, .3), c, TK.V3(0, .95, .35))
    limb(T, "TB", TK.V3(1.95, 1.35, .14), c, TK.V3(0, -.95, .5))
    for _, x in ipairs({ -.45, .1, .55 }) do
      fixed(T, "Fold", TK.V3(.05, 1.7, .04), S.fold, TK.V3(x, 0, .58))
    end
  end
  if S.jacket then -- куртка Рика Прайма
    fixed(T, "Hood", TK.V3(1.5, .4, .55), S.pad, TK.V3(0, .98, .2))
    fixed(T, "Zip", TK.V3(.06, 1.8, .04), TK.RGB(200, 195, 225), TK.V3(0, 0, -.46))
    for _, s in ipairs({ -1, 1 }) do
      fixed(T, "Stripe", TK.V3(.5, .14, .05), S.stripe, CFrame.new(s * .5, .55, -.46) * CFrame.Angles(0, 0, s * .25))
      fixed(T, "Pocket", TK.V3(.5, .7, .05), S.pad, TK.V3(s * .55, -.45, -.46))
    end
  end

  -- руки (плечо, локоть, кисть, пальцы) и ноги (бедро, колено, стопа)
  for _, s in ipairs({ -1, 1 }) do
    local n = s < 0 and "L" or "R"
    local au = limb(T, "A" .. n, TK.V3(.5, 1, .5), S.up, TK.V3(s * 1.15, .82, 0))
    local fa = limb(au, "E" .. n, TK.V3(.45, .95, .45), S.fo, TK.V3(0, -.5, 0))
    if S.cuff then fixed(fa, "Cuff", TK.V3(.5, .16, .5), S.cuff, TK.V3(0, -.4, 0)) end
    if S.fold then
      fixed(au, "Fold", TK.V3(.52, .05, .52), S.fold, TK.V3(0, -.15, 0))
      fixed(fa, "Fold", TK.V3(.47, .05, .47), S.fold, TK.V3(0, .2, 0))
    end
    if S.pad then fixed(au, "Pad", TK.V3(.66, .2, .66), S.pad, TK.V3(0, .5, 0)) end
    local pm = limb(fa, "W" .. n, TK.V3(.5, .34, .32), sc, TK.V3(0, -.475, 0))
    for i = 0, 3 do
      fixed(pm, "Finger", TK.V3(.1, .3, .12), sc, CFrame.new(-.18 + i * .12, -.3, -.03) * CFrame.Angles(.4, 0, 0))
    end
    fixed(pm, "Thumb", TK.V3(.12, .26, .12), sc, CFrame.new(-s * .29, -.05, -.1) * CFrame.Angles(.5, 0, -s * .3))
    if s > 0 then R.hand = pm end
    local th = limb(root, "H" .. n, TK.V3(.62, 1.25, .62), S.pants, TK.V3(s * .45, -.6, 0))
    if S.holster and s > 0 then fixed(th, "Holster", TK.V3(.2, .6, .42), TK.RGB(70, 75, 95), TK.V3(.38, -.1, 0)) end
    local sh = limb(th, "K" .. n, TK.V3(.56, .85, .56), S.pants, TK.V3(0, -.625, 0))
    if S.sock then fixed(sh, "Sock", TK.V3(.5, .22, .5), S.sock, TK.V3(0, -.3, 0)) end
    if S.boot then
      fixed(sh, "Boot", TK.V3(.64, .6, .64), S.shoe, TK.V3(0, -.12, 0))
      fixed(sh, "BStripe", TK.V3(.66, .09, .66), S.stripe, TK.V3(0, .05, 0))
    end
    local ft = limb(sh, "F" .. n, TK.V3(.7, .3, 1.15), S.shoe, TK.V3(0, -.425, 0), nil, .25)
    fixed(ft, "Toe", TK.V3(.7, .22, .45), S.shoe, TK.V3(0, .04, -.45))
  end
  R.FT = TK.ftar(S, "normal")
  R.FC = TK.copy(R.FT)
  return R
end

-- ============================================================
--  АНИМАТОР: idle, ходьба, бег, прыжок, хват предмета, посадка, эмоции тела, мимика
-- ============================================================
function TK.smooth(st, key, v, a)
  local c = st[key] or v
  c = c + (v - c) * a
  st[key] = c
  return c
end

-- v4.5: случайные жесты в покое: { имя, длительность }
TK.ACT = {
  rick = { { "burp", 1.3 }, { "sip", 2.2 } },
  pickle = { { "burp", 1.3 } },
  morty = { { "stutter", 1.8 } },
  evil_morty = { { "glance", 2.2 }, { "patch", 1.6 } },
  rick_prime = { { "gunchk", 1.6 } },
  jerry = { { "shrug", 1.3 } },
  summer = { { "flick", 1.4 } },
  meeseeks = { { "wave", 1.6 } },
}
TK.ACT_TXT = {
  burp = "*ррр-ыгх!*", stutter = "А-а-ай... г-геез!", gunchk = "Хм.", shrug = "Э-э... ну ладно!",
  flick = "Ну-у, типа...", wave = "Смотрите на меня!",
}
function TK.stepRig(R, dt, inp)
  local mot, base, fp, K, S, st = R.mot, R.base, R.fp, R.K, R.S, R.st
  local tm = mot.Torso
  if not tm or not tm.Parent then return end
  local F, FT = R.FC, R.FT
  R.t = R.t + dt
  local t = R.t
  local v, air = inp.speed, inp.air
  local a = math.min(1, dt * 12)
  local w = (air or v < .4) and 0 or math.clamp(v / math.max(inp.walkSpeed, 1), 0, 1.4)
  w = TK.smooth(st, "w", w, a)
  local ag = TK.smooth(st, "a", air and 1 or 0, a)
  R.ph = R.ph + dt * math.min(v, 40) * .55
  local ph = R.ph
  local s, c = math.sin(ph), math.cos(ph)
  local idle = 1 - math.min(1, w * 3)
  local br = math.sin(t * 1.9)
  local hips = (S.hips and 1 or 0) * idle * (1 - ag)

  local J = {} -- углы суставов
  local function set(n, x, y, z) J[n] = { x or 0, y or 0, z or 0 } end

  -- торс
  local bob = br * .03 * idle + math.abs(c) * .07 * w
  local trx, try, trz = -.1 * w + br * .02 * idle, -s * .12 * w, 0
  -- голова
  set("Head", .08 * w - br * .02 * idle + ag * .15 + F.hx,
    math.sin(t * .7) * .1 * idle + math.sin(t * 40) * .05 * F.sh,
    math.sin(t * .5) * .03 * idle + F.hz)
  -- ноги
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
  -- руки
  local sa = .7 * w * (1 - ag)
  local ar, al = s * sa, -s * sa
  local z = .07 + br * .03 * idle + .9 * ag + .5 * hips
  local eb = .15 + br * .03 * idle
  set("AR", ar, 0, z)
  set("AL", al, 0, -z)
  set("ER", eb + math.max(0, ar) * .6, 0, -1.3 * hips)
  set("EL", eb + math.max(0, al) * .6, 0, 1.3 * hips)
  -- полы халата
  local tl = -(.06 + .3 * w * (.5 + .5 * math.sin(ph * 2))) + ag * .1
  set("TB", tl)
  set("TL", tl, 0, -.04 - .1 * w)
  set("TR", tl, 0, .04 + .1 * w)

  -- v4.5: характер скина (idle-позы), случайные жесты, приземление
  local pid = S.id
  local pw = idle * (1 - ag) * (inp.ride and 0 or 1) * (inp.emote and 0 or 1)
  local awR = pw * (inp.hold and 0 or 1) -- правая рука занята предметом
  local xmo = 0
  local function add(n, x, y, zz)
    local j = J[n]
    if j then
      j[1] = j[1] + (x or 0)
      j[2] = j[2] + (y or 0)
      j[3] = j[3] + (zz or 0)
    end
  end
  local function jb(n, x, y, zz, k)
    local j = J[n]
    if j and k > 0 then
      j[1] = j[1] + ((x or 0) - j[1]) * k
      j[2] = j[2] + ((y or 0) - j[2]) * k
      j[3] = j[3] + ((zz or 0) - j[3]) * k
    end
  end
  if pw > .01 then
    if pid == "rick" or pid == "pickle" then
      trx = trx + .07 * pw
      try = try + math.sin(t * .4) * .05 * pw
      add("Head", 0, 0, math.sin(t * .6) * .06 * pw)
      add("HL", 0, 0, -.05 * pw)
      add("HR", 0, 0, .05 * pw)
      add("AL", math.sin(t * .8) * .08 * pw, 0, 0)
      if pid == "pickle" then
        trz = trz + math.sin(t * 7) * .06 * pw
        add("Head", 0, 0, math.sin(t * 7 + 1) * .1 * pw)
      end
    elseif pid == "morty" then
      local tw = math.max(0, math.sin(t * .7)) ^ 6
      add("Head", 0, math.sin(t * 25) * .05 * tw * pw, 0)
      add("AL", .45 * pw, 0, 0)
      add("EL", (.6 + math.sin(t * 8) * .1) * pw, 0, 0)
      add("AR", .45 * awR, 0, -.1 * awR)
      add("ER", (.6 + math.sin(t * 8 + 1) * .1) * awR, 0, 0)
    elseif pid == "evil_morty" then
      add("Head", -.06 * pw, math.sin(t * .35) * .3 * pw, 0)
      trx = trx - .03 * pw
    elseif pid == "rick_prime" then
      add("AR", 0, 0, .5 * awR)
      add("ER", 0, 0, -1.3 * awR)
      add("Head", -.07 * pw, 0, 0)
      try = try + math.sin(t * .3) * .04 * pw
      add("HL", 0, 0, -.07 * pw)
      add("HR", 0, 0, .07 * pw)
    elseif pid == "jerry" then
      local sh = math.max(0, math.sin(t * .5))
      add("AR", 0, 0, .12 * sh * awR)
      add("AL", 0, 0, -.12 * sh * pw)
      add("Head", 0, 0, .05 * math.sin(t * .5) * pw)
    elseif pid == "summer" then
      trz = trz + math.sin(t * .8) * .05 * pw
      add("Head", 0, 0, .08 * pw)
      add("AL", 0, 0, -.5 * pw)
      add("EL", 0, 0, 1.3 * pw)
    elseif pid == "meeseeks" then
      bob = bob + math.abs(math.sin(t * 5)) * .06 * pw
      add("AR", 0, 0, (.5 + math.sin(t * 6) * .15) * awR)
      add("AL", 0, 0, -(.5 + math.sin(t * 6 + 1) * .15) * pw)
    end
  end
  -- случайный жест раз в 8-16 секунд (только у твоего скина)
  local act = R.act
  if act and pw < .3 then
    R.act = nil
    act = nil
  end
  if not act and R.isMain and pw > .9 and t > (R.nextAct or 5) then
    local pool = TK.ACT[pid]
    if pool then
      local pick = pool[math.random(#pool)]
      act = { n = pick[1], d = pick[2], t0 = t }
      R.act = act
    end
    R.nextAct = t + 8 + math.random() * 8
  end
  if act then
    local u = (t - act.t0) / act.d
    if u >= 1 then
      R.act = nil
    else
      local k = math.min(1, math.sin(math.pi * u) * 1.6) * pw
      local kr = k * (inp.hold and 0 or 1)
      local an = act.n
      if not act.fx and u > .35 then
        act.fx = true
        local txt = TK.ACT_TXT[an]
        if txt then TK.bubble(R.root, txt, 1.8) end
        if an == "burp" then
          local hp = mot.Head and mot.Head.Part1
          if hp then TK.burst(hp.Position + hp.CFrame.LookVector * .8, TK.RGB(150, 255, 120), 14) end
        end
      end
      if an == "burp" then
        trx = trx - .16 * k
        jb("Head", -.5, 0, 0, k)
        xmo = .55 * k
      elseif an == "sip" then
        jb("AR", 2.4, 0, .1, kr)
        jb("ER", 2.2, 0, 0, kr)
        jb("Head", -.2, 0, 0, k)
      elseif an == "stutter" then
        add("Head", 0, math.sin(t * 28) * .1 * k, 0)
        jb("AL", .8, 0, 0, k)
        jb("EL", 1.3, 0, 0, k)
        jb("AR", .8, 0, 0, kr)
        jb("ER", 1.3, 0, 0, kr)
      elseif an == "glance" then
        jb("Head", 0, .9, 0, k)
      elseif an == "patch" then
        jb("AR", 2.5, 0, .15, kr)
        jb("ER", 1.8, 0, 0, kr)
      elseif an == "gunchk" then
        jb("AR", 0, 0, .9, kr)
        jb("ER", 0, 0, -1.4, kr)
      elseif an == "shrug" then
        jb("AR", 0, 0, .55, kr)
        jb("AL", 0, 0, -.55, k)
        jb("Head", 0, 0, .15, k)
      elseif an == "flick" then
        jb("AR", 2.6, 0, .3, kr)
        jb("ER", 1.5, 0, 0, kr)
        jb("Head", 0, 0, .2, k)
      elseif an == "wave" then
        jb("AR", 0, 0, 2.8, kr)
        jb("ER", 0, 0, .3 + math.sin(t * 10) * .5, kr)
      end
    end
  end
  -- приземление: короткий присед
  if st.wasAir and not air and not inp.ride then R.landT = t end
  st.wasAir = air and true or false
  local lw = math.max(0, 1 - (t - (R.landT or -9)) / .3) * (1 - math.min(w, 1) * .7)
  if lw > 0 then
    trx = trx + .16 * lw
    bob = bob - .15 * lw
    jb("KL", -.8, 0, 0, lw)
    jb("KR", -.8, 0, 0, lw)
    jb("HL", .5, 0, -.03, lw)
    jb("HR", .5, 0, .03, lw)
  end

  -- посадка (крейсер)
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
  -- посадка/высадка: прыжок с поднятыми руками и поджатыми ногами
  if inp.boarding then
    local bw = inp.boarding
    local function bm(n, x, y, zz)
      local j = J[n] or { 0, 0, 0 }
      J[n] = { j[1] + ((x or 0) - j[1]) * bw, j[2] + ((y or 0) - j[2]) * bw, j[3] + ((zz or 0) - j[3]) * bw }
    end
    trx = trx + (-.2 - trx) * bw
    bm("HL", 1.1, 0, -.1)
    bm("HR", .6, 0, .1)
    bm("KL", -1.3)
    bm("KR", -.8)
    bm("AR", 2.3, 0, .5)
    bm("AL", 2.3, 0, -.5)
    bm("ER", .3)
    bm("EL", .3)
    bm("Head", -.2)
  end
  -- хват предмета: правая рука вперёд (вперёд = положительный угол)
  if inp.hold then
    set("AR", 1.35, 0, .05)
    set("ER", .25)
  end

  -- эмоции тела
  if inp.emote then R.curEm = inp.emote end
  local want = (inp.emote ~= nil) and idle > .5 and not air and not inp.ride
  local ew = TK.smooth(st, "em", want and 1 or 0, math.min(1, dt * 8))
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

  -- мимика: плавный переход к целевому выражению + моргание
  local fa = math.min(1, dt * 9)
  for k, vv in pairs(FT) do F[k] = F[k] + (vv - F[k]) * fa end
  if t > R.nextBlink then
    R.blinkEnd = t + .13
    R.nextBlink = t + 2.5 + math.random() * 3
  end
  local blink = t < R.blinkEnd and .12 or 1
  local mo, mw = F.mo + xmo, F.w * F.mw
  local mh = .09 + mo
  local lz = R.lz
  local function sz(p, x, y, zz)
    local l = lz[p]
    if not l or math.abs(l.X - x) + math.abs(l.Y - y) + math.abs(l.Z - zz) > .003 then
      l = TK.V3(x, y, zz)
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
TK.animC, TK.hidden = nil, {}
function TK.playerInput(hum, root)
  local vl = root.AssemblyLinearVelocity
  local sp = TK.V3(vl.X, 0, vl.Z).Magnitude
  if TK.EMOTE and sp > 1.5 then TK.EMOTE = nil end
  local boarding = TK.ship and TK.ship.board and TK.ship.boardW or nil
  return {
    speed = sp, walkSpeed = hum.WalkSpeed,
    air = (not TK.RIDING) and (not boarding) and (not TK.SH.onDeck) and hum.FloorMaterial == Enum.Material.Air,
    hold = TK.HOLDING, ride = TK.RIDING, emote = TK.EMOTE, boarding = boarding,
  }
end
-- Портальные пушки имеют собственные модели и не меняются при переключении скина.
function TK.regun()
  -- Пересборка больше не нужна: выбранный скин не влияет на тип пушки.
end

function TK.fixCam() -- v4.7: камера всегда смотрит на твоего персонажа
  local cam = TK.Workspace.CurrentCamera
  local _, h = TK.getChar()
  if cam and h and cam.CameraSubject ~= h then
    cam.CameraSubject = h
    cam.CameraType = Enum.CameraType.Custom
  end
end

-- v4.5: лёгкая аура-частицы у каждого скина
TK.AURA = {
  rick = { col = TK.RGB(140, 255, 140), rate = 3, spd = 2 },
  pickle = { col = TK.RGB(150, 230, 90), rate = 5, spd = 2 },
  rick_prime = { col = TK.RGB(225, 50, 95), rate = 5, spd = 3, light = TK.RGB(225, 50, 95) },
  evil_morty = { col = TK.RGB(120, 80, 170), rate = 6, spd = 2, light = TK.RGB(120, 60, 160) },
  meeseeks = { col = TK.RGB(150, 220, 255), rate = 8, spd = 3 },
  summer = { col = TK.RGB(255, 170, 190), rate = 3, spd = 1.5 },
}
function TK.skinAura(R)
  local cfg = TK.AURA[R.S.id]
  local tm = R.mot.Torso and R.mot.Torso.Part1
  if not cfg or not tm then return end
  R.aura = TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = cfg.rate, Lifetime = NumberRange.new(1, 1.8),
    Speed = NumberRange.new(cfg.spd * .5, cfg.spd), SpreadAngle = Vector2.new(180, 180),
    Size = NumberSequence.new(.5, 0), Transparency = NumberSequence.new(.3, 1), LightEmission = .8,
    Color = ColorSequence.new(cfg.col), Acceleration = TK.V3(0, 1.5, 0),
  }, tm)
  if cfg.light then TK.I("PointLight", { Color = cfg.light, Range = 10, Brightness = .8, Shadows = false }, tm) end
end
function TK.clearSkin()
  if TK.animC then TK.animC:Disconnect() TK.animC = nil end
  if TK.RIG and TK.RIG.model then pcall(function() TK.RIG.model:Destroy() end) end
  TK.RIG = nil
  TK.detachHand()
  for p, tr in pairs(TK.hidden) do
    if p.Parent then p.Transparency = tr end
  end
  TK.hidden = {}
end
function TK.applySkin(id)
  local S = TK.SK[id]
  if not S then return end
  local ch, hum, root = TK.getChar()
  if not root or not hum then TK.notify("Нет персонажа", TK.C.dg) return end
  local cp = G.RM_AvatarCopier -- v4.8: снять копию аватара, чтобы скины не наложились
  if cp and cp.restoreSync then pcall(cp.restoreSync) end
  TK.clearSkin()
  for _, d in ipairs(ch:GetDescendants()) do
    if d:IsA("BasePart") and d ~= root and not d:FindFirstAncestorOfClass("Tool") then
      TK.hidden[d] = d.Transparency
      d.Transparency = 1
    end
  end
  local gy = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + root.Size.Y / 2) or 3
  local R = TK.newRig(root, S, math.clamp(gy / 3, .5, 3))
  R.model.Name = "RM_Skin_" .. id
  R.model.Parent = ch
  R.FT = TK.ftar(S, TK.ST.Emotion)
  R.FC = TK.copy(R.FT)
  TK.RIG = R
  R.isMain = true
  TK.safe(TK.skinAura, R)
  TK.animC = TK.RunService.RenderStepped:Connect(function(dt)
    if not TK.RIG or not root.Parent or not hum.Parent then return end
    TK.stepRig(TK.RIG, dt, TK.playerInput(hum, root))
  end)
  TK.ST.ActiveSkin = id
  TK.save()
  TK.notify("🎭 Скин: " .. S.name, TK.C.ac)
  TK.dimFx(nil, .8)
  local tl = ch:FindFirstChildOfClass("Tool")
  if tl and tl == TK.heldTool and TK.heldDef then TK.attachHand(tl, TK.heldDef.grip) end
  TK.regun()
  TK.safe(TK.fixCam)
end
function TK.removeSkin()
  TK.clearSkin()
  TK.ST.ActiveSkin = ""
  TK.save()
  TK.refreshGrip()
  TK.regun()
  TK.safe(TK.fixCam)
  TK.notify("🎭 Скин снят", TK.C.tx)
end
RM.removeSkin = TK.removeSkin -- v4.8: вызывает копир аватара
function TK.setEmo(id)
  TK.ST.Emotion = id
  TK.save()
  if TK.RIG then TK.RIG.FT = TK.ftar(TK.RIG.S, id) else TK.notify("Сначала надень скин", TK.C.dg, 2) end
  for _, e in ipairs(TK.EM) do
    if e[1] == id then TK.notify("Лицо: " .. e[2], TK.C.ac, 1.5) end
  end
end
function TK.say(text)
  local head = TK.RIG and TK.RIG.parts.Head
  if not head then
    local ch = TK.LP.Character
    head = ch and ch:FindFirstChild("Head")
  end
  TK.bubble(head, text, 3.5)
end
TK.track(TK.LP.CharacterAdded:Connect(function()
  TK.RIDING = false
  TK.EMOTE = nil
  TK.rideKeys.up, TK.rideKeys.down = false, false
  if TK.ship then TK.ship.board = nil end
  task.wait(1)
  if TK.ST.ActiveSkin ~= "" then TK.safe(TK.applySkin, TK.ST.ActiveSkin) end
end))

-- ============================================================
--  МИР: луч прицела, земля
-- ============================================================
function TK.aimHit(maxDist, farDist)
  local d, o = RM.getAimDirection()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { TK.LP.Character, TK.ship and TK.ship.model }
  local r = TK.Workspace:Raycast(o, d * maxDist, rp)
  if r then return r.Position, r.Normal end
  return o + d * math.min(maxDist, farDist or 50), -d
end
function TK.groundAt(pos)
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { TK.LP.Character, TK.ship and TK.ship.model }
  local r = TK.Workspace:Raycast(pos + TK.V3(0, 6, 0), TK.V3(0, -80, 0), rp)
  return r and r.Position.Y or nil
end

-- ============================================================
--  ПОРТАЛЫ: большие, мгновенное касание
-- ============================================================
function TK.pl(par, x, y, w, h, rot, col) -- скруглённая «таблетка» в SurfaceGui
  local f = TK.I("Frame", {
    AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
    Rotation = rot or 0, BackgroundColor3 = col, BorderSizePixel = 0,
  }, par)
  TK.I("UICorner", { CornerRadius = UDim.new(.5, 0) }, f)
  return f
end
function TK.killPortal(P, instant) -- закрытие: сжатие + вращение; instant = сразу убрать
  if not P or P.dead then return end
  P.dead = true
  if instant or not (P.d and P.d.Parent) then
    pcall(function() P.mo:Destroy() end)
    return
  end
  P.dying, P.dt0 = true, os.clock()
  P.s0 = P.d.Size.X
  if P.em then pcall(function() P.em.Enabled = false end) end
  TK.DYING[#TK.DYING + 1] = P
  TK.snd("close", .45)
end
function TK.portalRings(at, n, col) -- ударные кольца и вспышка при открытии портала
  local up = math.abs(n.Y) > .9 and Vector3.xAxis or Vector3.yAxis
  for i = 1, 2 do
    task.delay((i - 1) * .18, function()
      if TK.DEAD then return end
      local r = TK.I("Part", {
        Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = .2,
        Size = TK.V3(.15, TK.PORTAL_R * .6, TK.PORTAL_R * .6),
        CFrame = CFrame.lookAt(at, at + n, up) * CFrame.Angles(0, math.rad(90), 0),
      }, TK.fxFolder)
      TK.TweenService:Create(r, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = TK.V3(.15, TK.PORTAL_R * 2.8, TK.PORTAL_R * 2.8), Transparency = 1,
      }):Play()
      task.delay(.8, function() r:Destroy() end)
    end)
  end
  local fl = TK.I("Part", {
    Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.Neon, Color = col:Lerp(TK.WHITE, .6), Transparency = .3,
    Size = TK.V3(1, 1, 1), Position = at + n * .5,
  }, TK.fxFolder)
  TK.TweenService:Create(fl, TweenInfo.new(.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = TK.V3(TK.PORTAL_R * 1.8, TK.PORTAL_R * 1.8, TK.PORTAL_R * 1.8), Transparency = 1,
  }):Play()
  task.delay(.4, function() fl:Destroy() end)
  TK.burst(at + n, col, 36)
end
function TK.outBack(x) -- «перелёт» при открытии
  x = math.clamp(x, 0, 1)
  return 1 + 2.3 * (x - 1) ^ 3 + 1.3 * (x - 1) ^ 2
end
function TK.newPortal(pos, n, col)
  local up = math.abs(n.Y) > .9 and Vector3.xAxis or Vector3.yAxis
  local at = pos + n * .12
  local P = { pos = at, n = n, R = TK.PORTAL_R, L = {}, t0 = os.clock(), locked = false, mo = TK.I("Model", { Name = "RM_Portal" }, TK.Workspace) }
  local base = CFrame.lookAt(at, at + n, up)
  P.base = base
  local d = TK.mkp("Disc", TK.V3(.1, .1, .2), col)
  d.Anchored = true
  d.Transparency = 1
  d.CFrame = base
  d.Parent = P.mo
  P.d = d
  local dk, md, lt, wh = col:Lerp(TK.BLACK, .7), col:Lerp(TK.BLACK, .35), col:Lerp(TK.WHITE, .45), col:Lerp(TK.WHITE, .88)
  -- светящийся обод и мягкое гало (цилиндры осью вдоль нормали, за плоскостью воронки)
  local function ringPart(name, thick, mult, transp, c)
    local r = TK.I("Part", {
      Name = name, Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false,
      CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = c, Transparency = transp,
      Size = TK.V3(thick, .1, .1),
    }, P.mo)
    r.CFrame = CFrame.lookAt(at + n * .02, at + n * 1.02, up) * CFrame.Angles(0, math.rad(90), 0)
    return r
  end
  P.rim = ringPart("Rim", .22, 1, .05, col:Lerp(TK.WHITE, .25))
  P.halo = ringPart("Halo", .08, 1.3, .82, col)
  local g = TK.I("SurfaceGui", {
    Face = Enum.NormalId.Front, CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Brightness = 1.3,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  }, d)
  local function lay(spd) -- вращающийся слой
    local f = TK.I("Frame", {
      AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1),
      BackgroundTransparency = 1,
    }, g)
    P.L[#P.L + 1] = { f, spd }
    return f
  end
  for i, s in ipairs({ .88, .72, .56, .4, .24 }) do -- градиент от светлого края к тёмному центру (глубина)
    TK.pl(g, .5, .5, s, s, 0, md:Lerp(dk, (i - 1) * .22))
  end
  TK.pl(g, .5, .5, .1, .1, 0, TK.BLACK) -- тёмная «дыра» в центре
  for k, cfg in ipairs({ { 14, -14 }, { 11, 19 } }) do -- два слоя «рваных» кругов по краю
    local f = lay(cfg[2])
    for i = 1, cfg[1] do
      local a = i / cfg[1] * 6.283 + k
      local s = .17 * (.75 + .25 * (i % 3))
      TK.pl(f, .5 + .385 * math.cos(a), .5 + .385 * math.sin(a), s, s, 0, k == 1 and md or md:Lerp(lt, .4))
    end
  end
  local f = lay(38) -- 5 спиральных рукавов
  for arm = 0, 4 do
    for j = 0, 4 do
      local r, an = .41 - j * .07, arm * 1.2566 + j * .6
      TK.pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .2 - j * .025, .045, math.deg(an) + 108, j % 2 == 0 and lt or md:Lerp(lt, .5))
    end
  end
  f = lay(52) -- белые мазки
  for i = 0, 15 do
    local r, an = .26 + .14 * ((i * 3) % 5) / 4, i * 2.4
    TK.pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .12 + .08 * ((i * 5) % 3) / 2, .035, math.deg(an) + 102, wh)
  end
  f = lay(95) -- быстрый внутренний слой
  for i = 0, 5 do
    local r, an = .1 + i * .03, i * 1.1
    TK.pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .13, .04, math.deg(an) + 105, lt)
  end
  local g2 = g:Clone() -- обратная сторона (статичная копия)
  g2.Face = Enum.NormalId.Back
  g2.Parent = d
  P.light = TK.I("PointLight", { Color = col, Range = 24, Brightness = 2, Shadows = false }, d)
  local e = TK.I("ParticleEmitter", {
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
  P.em = e
  task.spawn(TK.portalRings, at, n, col)
  TK.snd("open", .5)
  return P
end
function TK.sizeRings(P, s, rimT, haloT) -- размеры обода и гало вслед за порталом
  if P.rim and P.rim.Parent then
    P.rim.Size = TK.V3(.22, s * 1.02, s * 1.02)
    P.rim.Transparency = rimT
  end
  if P.halo and P.halo.Parent then
    P.halo.Size = TK.V3(.08, s * 1.3, s * 1.3)
    P.halo.Transparency = haloT
  end
end
function TK.updPortal(P, t)
  if P.dying then return end
  local s = 2 * P.R
  if not P.done then
    local x = math.min(1, t / .5)
    s = 2 * P.R * math.max(TK.outBack(x), .03)
    P.d.Size = TK.V3(s, s, .2)
    P.done = x >= 1
  end
  local life = TK.PORTAL_LIFE - t
  local pulse = math.sin(t * 5)
  local blink = life < 4 and (math.floor(t * 8) % 2 == 0) -- в последние секунды мигает
  TK.sizeRings(P, s * (1 + pulse * .015), blink and .5 or .05, math.clamp(.82 + pulse * .08, 0, 1))
  for _, l in ipairs(P.L) do l[1].Rotation = t * l[2] end
  if P.light then P.light.Brightness = (blink and 1 or 2) + pulse * .8 end
end
function TK.stepDying(now) -- анимация закрытия порталов
  for i = #TK.DYING, 1, -1 do
    local P = TK.DYING[i]
    local k = (now - P.dt0) / .5
    if k >= 1 or not (P.d and P.d.Parent) then
      pcall(function() P.mo:Destroy() end)
      table.remove(TK.DYING, i)
    else
      local s = math.max(P.s0 * (1 - k * k), .05)
      P.d.Size = TK.V3(s, s, .2)
      TK.sizeRings(P, s, .05 + k * .9, .82 + k * .18)
      local t = now - P.t0
      for _, l in ipairs(P.L) do l[1].Rotation = t * l[2] * (1 + k * 6) end
      if P.light then P.light.Brightness = 2 * (1 - k) end
    end
  end
end
-- зона касания: почти весь диск портала, глубина ~5 стадов; проверяем корпус и ступни
function TK.inPortal(P, pos)
  local off = pos - P.pos
  local dep = off:Dot(P.n)
  local lat = (off - P.n * dep).Magnitude
  return math.abs(dep) < P.R * .8 and lat < P.R * 1.05
end
function TK.playerInPortal(P, hr)
  return TK.inPortal(P, hr.Position) or TK.inPortal(P, hr.Position - TK.V3(0, 2.6, 0))
end
function TK.teleportTo(hr, from, to)
  TK.tpCd = os.clock() + .3
  to.locked = true -- пока не выйдешь из зоны выходного портала, он не сработает
  local col = TK.pcol()
  TK.burst(hr.Position, col, 30)
  local ex = to.pos + to.n * 4
  local lk = TK.V3(to.n.X, 0, to.n.Z)
  if lk.Magnitude < .1 then lk = hr.CFrame.LookVector else lk = lk.Unit end
  hr.CFrame = CFrame.lookAt(ex, ex + TK.V3(lk.X, 0, lk.Z))
  hr.AssemblyLinearVelocity = to.n * 24
  TK.burst(ex, col, 30)
  TK.snd("teleport", .8, 1.2)
  TK.dimFx(col, .8)
end
-- ============================================================
--  ВЫСТРЕЛ: у каждой пушки своя анимация
-- ============================================================
TK.FXO = setmetatable({}, { __mode = "k" }) -- исходные цвет/прозрачность деталей пушки
function TK.pulsePart(p, dur, col)
  if not p or not p.Parent then return end
  local o = TK.FXO[p]
  if not o then o = { p.Color, p.Transparency } TK.FXO[p] = o end
  p.Color = col or TK.WHITE
  p.Transparency = 0
  TK.TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = o[1], Transparency = o[2] }):Play()
end
function TK.pulseByName(tool, names, dur, col, step)
  local i = 0
  for _, d in ipairs(tool:GetDescendants()) do
    if names[d.Name] then
      i = i + 1
      local p = d
      if step and step > 0 then
        task.delay((i - 1) * step, function() TK.pulsePart(p, dur, col) end)
      else
        TK.pulsePart(p, dur, col)
      end
    end
  end
end
function TK.lightSpike(tool, peak)
  for _, d in ipairs(tool:GetDescendants()) do
    if d:IsA("PointLight") then
      local o = TK.FXO[d] or d.Brightness
      TK.FXO[d] = o
      d.Brightness = peak
      TK.TweenService:Create(d, TweenInfo.new(.3), { Brightness = o }):Play()
    end
  end
end
function TK.recoil(k, a, dur) -- отдача: сдвигаем предмет в руке и возвращаем
  local w = TK.gripW
  if not w or not w.Parent or not TK.X.gripC1 then return end
  local base = TK.X.gripC1
  TK.X.rec = (TK.X.rec or 0) + 1
  local id = TK.X.rec
  task.spawn(function()
    local t0 = os.clock()
    while id == TK.X.rec and not TK.DEAD and w.Parent do
      local x = (os.clock() - t0) / dur
      if x >= 1 then break end
      local env = (x < .2) and (x / .2) or (1 - (x - .2) / .8) ^ 2
      w.C1 = (CFrame.new(0, 0, k * env) * CFrame.Angles(a * env, 0, 0)):Inverse() * base
      task.wait()
    end
    if id == TK.X.rec and w.Parent then w.C1 = base end
  end)
end
TK.GUNFX = {}
function TK.GUNFX.rick(tool, mz)
  TK.recoil(.35, .12, .22)
  TK.pulseByName(tool, { Core = 1, CoreTop = 1 }, .35, TK.RGB(220, 255, 220))
  TK.pulseByName(tool, { Bubble1 = 1, Bubble2 = 1, Bubble3 = 1 }, .5, TK.WHITE, .05)
  TK.lightSpike(tool, 6)
  if mz then TK.burst(mz.Position, TK.RGB(60, 255, 90), 12) end
end
function TK.GUNFX.rick_prime(tool, mz)
  TK.recoil(.2, .05, .3)
  local dots = {}
  for r = 0, 2 do
    for c = 0, 2 do dots["Dot_" .. r .. "_" .. c] = true end
  end
  TK.pulseByName(tool, dots, .4, TK.WHITE, .035) -- волна по панели точек
  TK.pulseByName(tool, { PinkLine = 1, Corner = 1, FlangeGlow = 1, EmitGlow = 1, RingGlow = 1 }, .45, TK.RGB(255, 120, 180))
  TK.lightSpike(tool, 5)
  if mz then TK.burst(mz.Position, TK.RGB(255, 80, 150), 10) TK.burst(mz.Position, TK.RGB(60, 255, 90), 10) end
end
function TK.GUNFX.evil_morty(tool, mz)
  TK.recoil(.55, .2, .4)
  TK.pulseByName(tool, { Orb = 1, Core = 1 }, .5, TK.WHITE)
  TK.pulseByName(tool, { LensCore = 1 }, .6, TK.RGB(200, 235, 255))
  TK.lightSpike(tool, 6)
  if mz then TK.burst(mz.Position, TK.RGB(255, 225, 80), 16) end
end
function TK.gunFx(id)
  local tool = TK.heldTool
  if not tool or not tool.Parent then return end
  local f = TK.GUNFX[id]
  if f then pcall(f, tool, tool:FindFirstChild("Muzzle")) end
end
function TK.shootPortal(gunId)
  local now = os.clock()
  if now - (TK.X.lastShot or 0) < .25 then return end -- защита от спама
  TK.X.lastShot = now
  -- Если выстрел сделан конкретной пушкой, её характеристики не зависят от выбранного скина.
  local g = (gunId and TK.GUN_CFG[gunId]) or TK.gunCfg()
  local range = g and g.range or 500
  local pos, n = TK.aimHit(range, g and g.range or 50)
  local col = (g and g.col) or TK.pcol()
  if not TK.PA then
    TK.PA = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал A", col)
  elseif not TK.PB then
    TK.PB = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал B", col)
  elseif TK.PA.t0 <= TK.PB.t0 then
    TK.killPortal(TK.PA)
    TK.PA = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал A пересоздан", col)
  else
    TK.killPortal(TK.PB)
    TK.PB = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал B пересоздан", col)
  end
  local mz = TK.heldTool and TK.heldTool:FindFirstChild("Muzzle", true)
  if mz then
    local a = mz.Position
    local dist = (pos - a).Magnitude
    if dist > 1 then
      local b = TK.mkp("Beam", TK.V3(.25, .25, dist), col, Enum.Material.Neon)
      b.Anchored = true
      b.CFrame = CFrame.lookAt(a, pos) * CFrame.new(0, 0, -dist / 2)
      b.Parent = TK.fxFolder
      TK.TweenService:Create(b, TweenInfo.new(.25), { Transparency = 1 }):Play()
      task.delay(.3, function() b:Destroy() end)
    end
  end
  TK.gunFx(gunId)
  TK.snd("shoot", .6)
end
RM.shootPortal = TK.shootPortal

-- ============================================================
--  ПРЕДМЕТЫ: сборка моделей и хват рукой скина
-- ============================================================
function TK.toolPart(tool, handle, name, size, color, offset, material, shape)
  local p = TK.mkp(name, size, color, material, shape)
  p.Parent = tool
  local w = Instance.new("Weld")
  w.Part0 = handle
  w.Part1 = p
  w.C0 = offset
  p.CFrame = handle.CFrame * offset
  w.Parent = p
  return p
end
TK.R90 = CFrame.Angles(0, 0, math.rad(90)) -- ось цилиндра: X -> вертикаль
TK.RZ = CFrame.Angles(0, math.rad(90), 0)  -- ось цилиндра: X -> вдоль Z

-- портальная пушка по фото
-- пушки по фото (v4.6): Рик (мультяшная), Рик Прайм (диск с ручкой, панель точек), Злой Морти (золотая)
function TK.gunBase()
  local tool = TK.I("Tool", { Name = "Портальная пушка", RequiresHandle = true, CanBeDropped = false, ToolTip = "Открыть портал" })
  local h = TK.mkp("Handle", TK.V3(.45, 1.3, .6), TK.RGB(214, 217, 222))
  h.Transparency = 1
  h.Parent = tool
  return tool, function(...) return TK.toolPart(tool, h, ...) end
end
function TK.buildGunRick()
  local tool, P = TK.gunBase()
  local H = math.rad
  P("HandleBar", TK.V3(.55, .42, 1.7), TK.RGB(190, 192, 196), CFrame.new(0, 0, .4))
  P("HandleCap", TK.V3(.55, .42, .55), TK.RGB(190, 192, 196), CFrame.new(0, 0, 1.25), nil, Enum.PartType.Ball)
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, -.05))
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, .3))
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, .65))
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, 1))
  P("Body", TK.V3(1.35, .5, 2.3), TK.RGB(205, 207, 210), CFrame.new(0, .02, -1.45))
  P("BodyTop", TK.V3(1.2, .05, 2), TK.RGB(222, 224, 227), CFrame.new(0, .285, -1.45))
  P("Under", TK.V3(1.25, .12, 2.1), TK.RGB(150, 152, 158), CFrame.new(0, -.22, -1.45))
  P("SideL", TK.V3(.04, .3, 1.9), TK.RGB(170, 172, 178), CFrame.new(-.69, .02, -1.45))
  P("SideR", TK.V3(.04, .3, 1.9), TK.RGB(170, 172, 178), CFrame.new(.69, .02, -1.45))
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(-.56, .31, -.6), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(-.56, .31, -1.45), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(-.56, .31, -2.3), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(.56, .31, -.6), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(.56, .31, -1.45), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(.56, .31, -2.3), nil, Enum.PartType.Ball)
  P("Vent", TK.V3(.55, .03, .06), TK.RGB(45, 46, 52), CFrame.new(0, .3, -.5))
  P("Vent", TK.V3(.55, .03, .06), TK.RGB(45, 46, 52), CFrame.new(0, .3, -.62))
  P("Vent", TK.V3(.55, .03, .06), TK.RGB(45, 46, 52), CFrame.new(0, .3, -.74))
  P("Emitter", TK.V3(.5, .2, .05), TK.RGB(30, 30, 34), CFrame.new(0, .02, -2.62))
  P("EmitRing", TK.V3(.07, .6, .6), TK.RGB(80, 84, 90), CFrame.new(0, .02, -2.63) * CFrame.Angles(H(0), H(90), H(0)), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("EmitGlow", TK.V3(.08, .4, .4), TK.RGB(60, 230, 90), CFrame.new(0, .02, -2.65) * CFrame.Angles(H(0), H(90), H(0)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .35
  end
  P("ButtonFrame", TK.V3(.72, .06, .52), TK.RGB(45, 46, 52), CFrame.new(0, .27, -.95))
  do
    local q = P("Button", TK.V3(.6, .09, .42), TK.RGB(215, 30, 40), CFrame.new(0, .31, -.95), Enum.Material.Neon)
    q.Transparency = .1
  end
  P("Led", TK.V3(.1, .1, .1), TK.RGB(110, 255, 110), CFrame.new(.5, .31, -.4), Enum.Material.Neon, Enum.PartType.Ball)
  P("Knob", TK.V3(.22, .5, .5), TK.RGB(35, 35, 38), CFrame.new(0, .36, -.35) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("KnobCap", TK.V3(.05, .36, .36), TK.RGB(70, 72, 78), CFrame.new(0, .63, -.35) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Ring", TK.V3(.1, .9, .9), TK.RGB(170, 172, 176), CFrame.new(0, .3, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("RingGlow", TK.V3(.04, .96, .96), TK.RGB(60, 255, 90), CFrame.new(0, .33, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .5
  end
  do
    local q = P("Dome", TK.V3(.8, .7, .7), TK.RGB(60, 255, 90), CFrame.new(0, .75, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Glass, Enum.PartType.Cylinder)
    q.Transparency = .25
  end
  do
    local q = P("DomeTop", TK.V3(.7, .7, .7), TK.RGB(60, 255, 90), CFrame.new(0, 1.15, -1.9), Enum.Material.Glass, Enum.PartType.Ball)
    q.Transparency = .25
  end
  do
    local q = P("Core", TK.V3(.75, .44, .44), TK.RGB(110, 255, 110), CFrame.new(0, .75, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .2
    TK.I("PointLight", { Color = TK.RGB(60, 255, 90), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  do
    local q = P("CoreTop", TK.V3(.44, .44, .44), TK.RGB(110, 255, 110), CFrame.new(0, 1.13, -1.9), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .2
  end
  do
    local q = P("Bubble1", TK.V3(.17, .17, .17), TK.RGB(190, 255, 190), CFrame.new(.12, .6, -1.82), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
  end
  do
    local q = P("Bubble2", TK.V3(.13, .13, .13), TK.RGB(190, 255, 190), CFrame.new(-.1, .9, -1.95), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
  end
  do
    local q = P("Bubble3", TK.V3(.1, .1, .1), TK.RGB(190, 255, 190), CFrame.new(.05, 1.05, -1.88), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
  end
  do
    local q = P("Muzzle", TK.V3(.1, .1, .1), TK.RGB(255, 255, 255), CFrame.new(0, .02, -2.8), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = 1
  end
  return tool
end
function TK.buildGunPrime()
  local tool, P = TK.gunBase()
  local H = math.rad
  P("Grip", TK.V3(.62, 1.55, .78), TK.RGB(205, 208, 213), CFrame.new(0, 0, .2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripDark", TK.V3(.5, 1, .2), TK.RGB(82, 85, 92), CFrame.new(0, -.42, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.15, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.37, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.59, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.81, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("Body", TK.V3(.95, .85, 1.95), TK.RGB(225, 228, 232), CFrame.new(0, 1.05, -.8))
  P("Slope", TK.V3(.66, .5, .95), TK.RGB(225, 228, 232), CFrame.new(0, 1.2, .38) * CFrame.Angles(H(14), H(0), H(0)))
  P("Strut", TK.V3(.55, .2, 1.75), TK.RGB(200, 203, 208), CFrame.new(0, 0, -.3) * CFrame.Angles(H(45), H(0), H(0)))
  P("Trigger", TK.V3(.14, .42, .2), TK.RGB(45, 45, 50), CFrame.new(0, .42, -.3) * CFrame.Angles(H(20), H(0), H(0)))
  do
    local q = P("Switch", TK.V3(.28, .16, .32), TK.RGB(225, 35, 35), CFrame.new(0, 1.45, .65), Enum.Material.Neon)
    q.Transparency = .1
  end
  do
    local q = P("PinkLine", TK.V3(.03, .05, 1.75), TK.RGB(255, 60, 130), CFrame.new(-.49, 1.36, -.8), Enum.Material.Neon)
    q.Transparency = .15
  end
  do
    local q = P("PinkLine", TK.V3(.03, .05, 1.75), TK.RGB(255, 60, 130), CFrame.new(.49, 1.36, -.8), Enum.Material.Neon)
    q.Transparency = .15
  end
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(-.3, 1.49, -1.5), nil, Enum.PartType.Ball)
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(-.3, 1.49, -.2), nil, Enum.PartType.Ball)
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(.3, 1.49, -1.5), nil, Enum.PartType.Ball)
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(.3, 1.49, -.2), nil, Enum.PartType.Ball)
  P("Panel", TK.V3(.86, .8, .03), TK.RGB(28, 28, 30), CFrame.new(0, 1.05, -1.79))
  P("BezelT", TK.V3(1, .07, .06), TK.RGB(95, 98, 105), CFrame.new(0, 1.47, -1.8), Enum.Material.Metal)
  P("BezelB", TK.V3(1, .07, .06), TK.RGB(95, 98, 105), CFrame.new(0, .63, -1.8), Enum.Material.Metal)
  P("BezelL", TK.V3(.07, .9, .06), TK.RGB(95, 98, 105), CFrame.new(-.46, 1.05, -1.8), Enum.Material.Metal)
  P("BezelR", TK.V3(.07, .9, .06), TK.RGB(95, 98, 105), CFrame.new(.46, 1.05, -1.8), Enum.Material.Metal)
  P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(-.5, .61, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
  P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(-.5, 1.49, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
  P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(.5, .61, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
  do
    local q = P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(.5, 1.49, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
    TK.I("PointLight", { Color = TK.RGB(255, 60, 130), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  P("Dot_0_0", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(-.27, .79, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_0_1", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(0, .79, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_0_2", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(.27, .79, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_1_0", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(-.27, 1.05, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_1_1", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(0, 1.05, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_1_2", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(.27, 1.05, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_2_0", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(-.27, 1.31, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_2_1", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(0, 1.31, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_2_2", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(.27, 1.31, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Flange", TK.V3(.1, .85, .85), TK.RGB(200, 204, 210), CFrame.new(0, 1.52, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("FlangeGlow", TK.V3(.04, .92, .92), TK.RGB(255, 60, 130), CFrame.new(0, 1.57, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .35
  end
  do
    local q = P("Dome", TK.V3(.75, .72, .72), TK.RGB(60, 255, 90), CFrame.new(0, 1.95, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Glass, Enum.PartType.Cylinder)
    q.Transparency = .25
  end
  do
    local q = P("DomeTop", TK.V3(.72, .72, .72), TK.RGB(60, 255, 90), CFrame.new(0, 2.32, -.95), Enum.Material.Glass, Enum.PartType.Ball)
    q.Transparency = .25
  end
  do
    local q = P("Core", TK.V3(.7, .46, .46), TK.RGB(110, 255, 110), CFrame.new(0, 1.95, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .2
    TK.I("PointLight", { Color = TK.RGB(60, 255, 90), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  do
    local q = P("CoreTop", TK.V3(.46, .46, .46), TK.RGB(110, 255, 110), CFrame.new(0, 2.3, -.95), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .2
  end
  P("DialRing", TK.V3(.07, .62, .62), TK.RGB(210, 213, 218), CFrame.new(.5, 1, -.55), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("DialTick", TK.V3(.09, .66, .66), TK.RGB(120, 124, 130), CFrame.new(.5, 1, -.55), nil, Enum.PartType.Cylinder)
    q.Transparency = 0
  end
  P("Dial", TK.V3(.09, .5, .5), TK.RGB(190, 194, 200), CFrame.new(.53, 1, -.55), nil, Enum.PartType.Cylinder)
  P("DialPtr", TK.V3(.07, .09, .4), TK.RGB(232, 235, 240), CFrame.new(.58, 1, -.55) * CFrame.Angles(H(35), H(0), H(0)))
  P("Hole1", TK.V3(.03, .1, .1), TK.RGB(20, 20, 22), CFrame.new(.49, 1.05, -1.25), nil, Enum.PartType.Cylinder)
  P("Hole2", TK.V3(.03, .1, .1), TK.RGB(20, 20, 22), CFrame.new(.49, .82, -1.25), nil, Enum.PartType.Cylinder)
  P("Toggle", TK.V3(.12, .05, .05), TK.RGB(190, 194, 200), CFrame.new(.52, 1.28, -1.25))
  do
    local q = P("Muzzle", TK.V3(.1, .1, .1), TK.RGB(255, 255, 255), CFrame.new(0, 1.05, -1.95), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = 1
  end
  return tool
end
function TK.buildGunEvil()
  local tool, P = TK.gunBase()
  local H = math.rad
  P("Grip", TK.V3(.5, 1.4, .6), TK.RGB(120, 115, 120), CFrame.new(0, 0, .1) * CFrame.Angles(H(-10), H(0), H(0)))
  P("GripWrap", TK.V3(.52, .16, .62), TK.RGB(80, 60, 40), CFrame.new(0, -.25, .1) * CFrame.Angles(H(-10), H(0), H(0)))
  P("GripWrap", TK.V3(.52, .16, .62), TK.RGB(80, 60, 40), CFrame.new(0, .1, .08) * CFrame.Angles(H(-10), H(0), H(0)))
  P("Trigger", TK.V3(.14, .45, .18), TK.RGB(30, 30, 34), CFrame.new(0, .45, -.3) * CFrame.Angles(H(15), H(0), H(0)))
  P("Slab", TK.V3(.75, .7, 2.6), TK.RGB(175, 150, 45), CFrame.new(0, .95, -.9))
  P("SlabEdge", TK.V3(.77, .06, 2.6), TK.RGB(215, 190, 75), CFrame.new(0, 1.3, -.9))
  P("SlabPlate", TK.V3(.55, .03, 1.9), TK.RGB(140, 118, 38), CFrame.new(0, 1.33, -.9))
  do
    local q = P("SlabLine", TK.V3(.03, .04, 2.4), TK.RGB(255, 225, 110), CFrame.new(-.39, 1.1, -.9), Enum.Material.Neon)
    q.Transparency = .35
  end
  do
    local q = P("SlabLine", TK.V3(.03, .04, 2.4), TK.RGB(255, 225, 110), CFrame.new(.39, 1.1, -.9), Enum.Material.Neon)
    q.Transparency = .35
  end
  P("Block", TK.V3(1.05, 1.1, 1.1), TK.RGB(150, 125, 35), CFrame.new(0, .95, -2.35))
  P("BlockEdge", TK.V3(1.07, .06, 1.1), TK.RGB(215, 190, 75), CFrame.new(0, 1.5, -2.35))
  P("VentSlot", TK.V3(.8, .03, .08), TK.RGB(40, 32, 12), CFrame.new(0, 1.52, -2.1))
  P("VentSlot", TK.V3(.8, .03, .08), TK.RGB(40, 32, 12), CFrame.new(0, 1.52, -2.3))
  P("VentSlot", TK.V3(.8, .03, .08), TK.RGB(40, 32, 12), CFrame.new(0, 1.52, -2.5))
  P("LensRing", TK.V3(.06, .78, .78), TK.RGB(35, 40, 35), CFrame.new(-.55, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, 1.37, -2.35))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, 1.247, -2.053) * CFrame.Angles(H(45), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .95, -1.93) * CFrame.Angles(H(90), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .653, -2.053) * CFrame.Angles(H(135), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .53, -2.35) * CFrame.Angles(H(180), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .653, -2.647) * CFrame.Angles(H(225), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .95, -2.77) * CFrame.Angles(H(270), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, 1.247, -2.647) * CFrame.Angles(H(315), H(0), H(0)))
  P("Lens", TK.V3(.08, .62, .62), TK.RGB(85, 100, 85), CFrame.new(-.57, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("LensCore", TK.V3(.1, .28, .28), TK.RGB(60, 170, 255), CFrame.new(-.6, .95, -2.35), Enum.Material.Neon, Enum.PartType.Cylinder)
  P("LensRing", TK.V3(.06, .78, .78), TK.RGB(35, 40, 35), CFrame.new(.55, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, 1.37, -2.35))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, 1.247, -2.053) * CFrame.Angles(H(45), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .95, -1.93) * CFrame.Angles(H(90), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .653, -2.053) * CFrame.Angles(H(135), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .53, -2.35) * CFrame.Angles(H(180), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .653, -2.647) * CFrame.Angles(H(225), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .95, -2.77) * CFrame.Angles(H(270), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, 1.247, -2.647) * CFrame.Angles(H(315), H(0), H(0)))
  P("Lens", TK.V3(.08, .62, .62), TK.RGB(85, 100, 85), CFrame.new(.57, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("LensCore", TK.V3(.1, .28, .28), TK.RGB(60, 170, 255), CFrame.new(.6, .95, -2.35), Enum.Material.Neon, Enum.PartType.Cylinder)
  do
    local q = P("Orb", TK.V3(.55, .55, .55), TK.RGB(255, 240, 140), CFrame.new(0, .95, -3), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
    TK.I("PointLight", { Color = TK.RGB(255, 220, 50), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  P("OrbCup", TK.V3(.12, .62, .62), TK.RGB(120, 100, 30), CFrame.new(0, .95, -2.92) * CFrame.Angles(H(0), H(90), H(0)), nil, Enum.PartType.Cylinder)
  do
    local q = P("Jar", TK.V3(.95, .5, .5), TK.RGB(255, 225, 80), CFrame.new(0, 1.75, -1.55) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Glass, Enum.PartType.Cylinder)
    q.Transparency = .4
  end
  do
    local q = P("DomeTop", TK.V3(.5, .5, .5), TK.RGB(255, 225, 80), CFrame.new(0, 2.25, -1.55), Enum.Material.Glass, Enum.PartType.Ball)
    q.Transparency = .4
  end
  do
    local q = P("Core", TK.V3(.8, .25, .25), TK.RGB(255, 240, 140), CFrame.new(0, 1.75, -1.55) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .3
    TK.I("PointLight", { Color = TK.RGB(255, 220, 50), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  P("JarBase", TK.V3(.1, .56, .56), TK.RGB(120, 100, 30), CFrame.new(0, 1.35, -1.55) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  P("GreyA", TK.V3(.45, .5, .5), TK.RGB(110, 118, 115), CFrame.new(0, 1.5, -.65))
  P("GreyB", TK.V3(.3, .35, .3), TK.RGB(130, 135, 130), CFrame.new(0, 1.45, -.25))
  P("VialTeal", TK.V3(.4, .22, .22), TK.RGB(60, 140, 125), CFrame.new(.2, 1.55, -.95) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("VialRust", TK.V3(.45, .2, .2), TK.RGB(150, 85, 50), CFrame.new(-.2, 1.55, -.3) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Canister", TK.V3(1, .4, .4), TK.RGB(110, 78, 50), CFrame.new(0, 1.75, .25) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Strap", TK.V3(.1, .44, .44), TK.RGB(70, 50, 35), CFrame.new(0, 1.9, .25) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Cable", TK.V3(.05, .05, .9), TK.RGB(30, 30, 34), CFrame.new(.22, 1.45, -1.3) * CFrame.Angles(H(0), H(20), H(0)))
  do
    local q = P("Muzzle", TK.V3(.1, .1, .1), TK.RGB(255, 255, 255), CFrame.new(0, .95, -3.2), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = 1
  end
  return tool
end

-- замораживатель времени (дизайн мой: картинки не было)
function TK.buildFreezer()
  local tool = TK.I("Tool", { Name = "Замораживатель времени", RequiresHandle = true, CanBeDropped = false, ToolTip = "Остановить время" })
  local h = TK.mkp("Handle", TK.V3(.5, 1.2, .5), TK.RGB(60, 64, 74))
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local BL = TK.RGB(90, 200, 255)
  P("Body", TK.V3(.9, .75, 1.3), TK.RGB(225, 230, 235), CFrame.new(0, .75, -.45))
  P("LensRing", TK.V3(.12, 1.15, 1.15), TK.RGB(50, 54, 62), CFrame.new(0, .75, -1.12) * TK.RZ, nil, Enum.PartType.Cylinder)
  P("Lens", TK.V3(.4, .9, .9), BL, CFrame.new(0, .75, -1.2) * TK.RZ, Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = .3
  local core = P("Core", TK.V3(.5, .5, .5), TK.RGB(200, 245, 255), CFrame.new(0, .75, -1.15) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  core.Transparency = .2
  TK.I("PointLight", { Color = BL, Range = 9, Brightness = 2, Shadows = false }, core)
  local btn = P("Button", TK.V3(.12, .5, .5), TK.RGB(50, 120, 200), CFrame.new(0, 1.18, -.3) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("PointLight", { Color = BL, Range = 5, Brightness = 1, Shadows = false }, btn)
  for _, s in ipairs({ -1, 1 }) do
    P("Fin", TK.V3(.1, .5, .8), TK.RGB(150, 160, 170), CFrame.new(s * .5, .75, -.4))
  end
  return tool
end

-- ящик Мисиксов по фото: тёмно-бирюзовый куб, зелёные окна, синяя кнопка сверху
function TK.buildMeeseeksBox()
  local tool = TK.I("Tool", { Name = "Ящик Мисиксов", RequiresHandle = true, CanBeDropped = false, ToolTip = "Нажми кнопку — помощник" })
  local h = TK.mkp("Handle", TK.V3(1.5, 1.5, 1.5), TK.RGB(30, 66, 64), Enum.Material.Metal)
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local GREEN, DKG = TK.RGB(120, 250, 180), TK.RGB(40, 190, 130)
  P("Top", TK.V3(1.3, .12, 1.3), TK.RGB(84, 130, 130), CFrame.new(0, .78, 0), Enum.Material.Metal)
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("Post", TK.V3(.14, 1.56, .14), TK.RGB(62, 112, 110), CFrame.new(sx * .72, 0, sz * .72), Enum.Material.Metal)
    end
  end
  P("ButtonBase", TK.V3(.1, .66, .66), TK.RGB(8, 24, 24), CFrame.new(0, .86, 0) * TK.R90, nil, Enum.PartType.Cylinder)
  local btn = P("Button", TK.V3(.24, .5, .5), TK.RGB(70, 170, 240), CFrame.new(0, .97, 0) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("PointLight", { Color = TK.RGB(70, 170, 240), Range = 8, Brightness = 1.5, Shadows = false }, btn)
  for i = 0, 3 do -- «восьмиугольные» окна на 4 гранях
    local side = CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(0, -.02, -.755)
    P("WinA", TK.V3(.86, .5, .05), GREEN, side, Enum.Material.Neon)
    P("WinB", TK.V3(.5, .86, .05), GREEN, side, Enum.Material.Neon)
    P("WinC", TK.V3(.62, .62, .05), GREEN, side * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon)
    P("Line", TK.V3(.03, .7, .06), DKG, side * CFrame.new(-.12, 0, -.02))
    P("Line", TK.V3(.03, .7, .06), DKG, side * CFrame.new(.12, 0, -.02))
  end
  return tool
end

-- батарея микровселенной по фото: фиолетовое желе в чёрной раме, три глаза, экран заряда
function TK.buildBattery()
  local tool = TK.I("Tool", { Name = "Батарея микровселенной", RequiresHandle = true, CanBeDropped = false, ToolTip = "Зона энергии" })
  local h = TK.mkp("Handle", TK.V3(1.2, .8, .8), TK.RGB(170, 60, 230), Enum.Material.Neon)
  h.Transparency = .15
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local dk = TK.RGB(22, 22, 26)
  P("Glass", TK.V3(1.4, 1, 1), TK.RGB(215, 140, 255), CFrame.new(), Enum.Material.Glass).Transparency = .6
  for _, sy in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("BarX", TK.V3(1.5, .1, .1), dk, CFrame.new(0, sy * .5, sz * .5), Enum.Material.Metal)
    end
  end
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("BarY", TK.V3(.1, 1.1, .1), dk, CFrame.new(sx * .7, 0, sz * .5), Enum.Material.Metal)
    end
    for _, sy in ipairs({ -1, 1 }) do
      P("BarZ", TK.V3(.1, .1, 1.1), dk, CFrame.new(sx * .7, sy * .5, 0), Enum.Material.Metal)
    end
  end
  P("Panel", TK.V3(.6, .7, .06), dk, CFrame.new(-.35, 0, -.53), Enum.Material.Metal)
  for i = 0, 2 do -- три глаза
    local ex = -.5 + i * .15
    local ey = (i == 1) and .22 or .15
    P("Eye", TK.V3(.16, .16, .16), TK.RGB(240, 240, 240), CFrame.new(ex, ey, -.58), nil, Enum.PartType.Ball)
    P("Pupil", TK.V3(.08, .08, .08), TK.RGB(0, 0, 0), CFrame.new(ex, ey, -.63), nil, Enum.PartType.Ball)
  end
  P("Door", TK.V3(.18, .28, .04), TK.RGB(70, 74, 82), CFrame.new(-.35, -.2, -.57))
  P("Blob", TK.V3(.2, .2, .2), TK.RGB(255, 150, 255), CFrame.new(.15, .15, -.1), Enum.Material.Neon, Enum.PartType.Ball).Transparency = .2
  P("Blob", TK.V3(.12, .12, .12), TK.RGB(255, 200, 255), CFrame.new(-.1, .05, .15), Enum.Material.Neon, Enum.PartType.Ball).Transparency = .2
  local scr = P("Screen", TK.V3(.5, .18, .05), TK.RGB(10, 14, 10), CFrame.new(.3, -.2, -.53))
  local sg = TK.I("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(120, 40), LightInfluence = 0, Brightness = 2 }, scr)
  local lbl = TK.I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "100%", TextColor3 = TK.RGB(120, 255, 140),
    Font = Enum.Font.Code, TextScaled = true,
  }, sg)
  TK.I("PointLight", { Color = TK.RGB(190, 80, 255), Range = 9, Brightness = 2, Shadows = false }, h)
  return tool, lbl
end

-- пульт вызова крейсера
function TK.buildRemote()
  local tool = TK.I("Tool", { Name = "Пульт крейсера", RequiresHandle = true, CanBeDropped = false, ToolTip = "Вызвать / сесть / слезть" })
  local h = TK.mkp("Handle", TK.V3(.5, 1, .3), TK.RGB(55, 60, 68), Enum.Material.Metal)
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local scr = P("Screen", TK.V3(.38, .3, .04), TK.RGB(10, 20, 14), CFrame.new(0, .22, -.17), Enum.Material.Neon)
  scr.Color = TK.RGB(60, 255, 120)
  local sg = TK.I("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(120, 90), LightInfluence = 0, Brightness = 2 }, scr)
  TK.I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "SHIP", TextColor3 = TK.RGB(5, 40, 15),
    Font = Enum.Font.Code, TextScaled = true,
  }, sg)
  P("Button", TK.V3(.14, .22, .22), TK.RGB(255, 140, 40), CFrame.new(0, -.2, -.17) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  P("Antenna", TK.V3(.7, .05, .05), TK.RGB(30, 30, 34), CFrame.new(.15, .85, 0) * TK.R90, nil, Enum.PartType.Cylinder)
  P("Tip", TK.V3(.1, .1, .1), TK.RGB(255, 80, 80), CFrame.new(.15, 1.2, 0), Enum.Material.Neon, Enum.PartType.Ball)
  return tool
end

-- хват: убираем стандартный RightGrip и привариваем предмет к ладони скина
function TK.detachHand()
  TK.HOLDING = false
  TK.X.rec = (TK.X.rec or 0) + 1
  TK.X.gripC1 = nil
  if TK.gripW then pcall(function() TK.gripW:Destroy() end) TK.gripW = nil end
  if TK.gripC then TK.gripC:Disconnect() TK.gripC = nil end
end
function TK.attachHand(tool, off)
  TK.detachHand()
  if not TK.RIG or not TK.RIG.hand then return end -- без скина работает стандартный хват Roblox
  local handle = tool:FindFirstChild("Handle")
  local ch = TK.LP.Character
  if not handle or not ch then return end
  for _, o in ipairs(ch:GetDescendants()) do
    if o.Name == "RightGrip" then o:Destroy() end
  end
  TK.gripC = ch.DescendantAdded:Connect(function(o)
    if o.Name == "RightGrip" then task.defer(function() pcall(function() o:Destroy() end) end) end
  end)
  TK.gripW = Instance.new("Weld")
  TK.gripW.Name = "RM_Grip"
  TK.gripW.Part0 = TK.RIG.hand
  TK.gripW.Part1 = handle
  -- рука вытянута вперёд: «вниз» кисти смотрит вперёд, «вперёд» кисти смотрит вверх
  TK.gripW.C0 = CFrame.new(off or TK.V3()) * CFrame.Angles(-math.pi / 2, 0, 0)
  TK.gripW.Parent = TK.RIG.hand
  TK.X.gripC1 = TK.gripW.C1
  TK.HOLDING = true
end
function TK.refreshGrip() -- вернуть стандартный хват после снятия скина
  TK.detachHand()
  local ch, hum = TK.getChar()
  if hum and TK.heldTool and TK.heldTool.Parent == ch then
    task.defer(function()
      hum:UnequipTools()
      hum:EquipTool(TK.heldTool)
    end)
  end
end

-- ============================================================
--  ПРЕДМЕТЫ: действия
-- ============================================================
-- ❄ замораживатель времени: пузырь, экран в серых тонах, помощники замирают на 4 с
TK.ccStop = nil
function TK.timeStop()
  local now = os.clock()
  if now < TK.TS_CD then TK.notify("❄ Перезарядка " .. math.ceil(TK.TS_CD - now) .. " с", TK.C.dg, 1) return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  TK.TS_CD = now + 10
  TK.TIMESTOP_UNTIL = now + 4
  local bub = TK.I("Part", {
    Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.ForceField, Color = TK.RGB(120, 200, 255), Transparency = .25,
    Size = TK.V3(2, 2, 2), CFrame = hr.CFrame,
  }, TK.fxFolder)
  TK.TweenService:Create(bub, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = TK.V3(44, 44, 44) }):Play()
  task.delay(3.5, function()
    TK.TweenService:Create(bub, TweenInfo.new(.5), { Transparency = 1 }):Play()
    task.delay(.55, function() bub:Destroy() end)
  end)
  if not TK.ccStop or not TK.ccStop.Parent then TK.ccStop = TK.I("ColorCorrectionEffect", { Name = "RM_TimeStop" }, TK.Lighting) end
  TK.TweenService:Create(TK.ccStop, TweenInfo.new(.3), { Saturation = -.85, Contrast = .2, TintColor = TK.RGB(185, 225, 255) }):Play()
  task.delay(4, function()
    if TK.ccStop and TK.ccStop.Parent then
      TK.TweenService:Create(TK.ccStop, TweenInfo.new(.6), { Saturation = 0, Contrast = 0, TintColor = TK.WHITE }):Play()
    end
  end)
  for _, hp in ipairs(TK.helpers) do
    local hl = TK.I("Highlight", {
      FillColor = TK.RGB(150, 220, 255), FillTransparency = .5, OutlineColor = TK.WHITE, Adornee = hp.R.model,
    }, hp.R.model)
    task.delay(4, function() if hl.Parent then hl:Destroy() end end)
  end
  TK.snd("teleport", .7, .6)
  TK.notify("⏱ Время остановлено на 4 с", TK.RGB(150, 230, 255), 2)
end

-- 🟦 ящик Мисиксов: помощник бежит к точке прицела, «выполняет задание» и исчезает
TK.helperFolder = TK.I("Folder", { Name = "RM_Helpers" }, TK.Workspace)
TK.MEE_CATCH = {
  "Я Мистер Мисикс, посмотри на меня!", "Ооо, да, можно!", "Существование — это боль!",
  "Я выполню задание!", "Дай мне исчезнуть!",
}
function TK.spawnMeeseeks()
  if #TK.helpers >= 3 then TK.notify("Максимум 3 Мисикса сразу", TK.C.dg, 1.5) return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  local target = TK.aimHit(120)
  local far = target and (target - hr.Position).Magnitude > 8
  local lv = TK.V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
  lv = lv.Magnitude > .01 and lv.Unit or TK.V3(0, 0, -1)
  local ahead = hr.Position + lv * 5
  local gy = TK.groundAt(ahead) or (hr.Position.Y - 3)
  local pos = TK.V3(ahead.X, gy + 3, ahead.Z)
  local root = TK.mkp("MRoot", TK.V3(2, 2, 1), TK.WHITE)
  root.Transparency = 1
  root.Anchored = true
  root.CFrame = CFrame.lookAt(pos, pos + lv)
  local R = TK.newRig(root, TK.SK.meeseeks, 1)
  R.FT = TK.ftar(TK.SK.meeseeks, "happy")
  R.FC = TK.copy(R.FT)
  root.Parent = R.model
  R.model.Parent = TK.helperFolder
  TK.burst(pos, TK.RGB(90, 170, 255), 30)
  TK.helpers[#TK.helpers + 1] = {
    R = R, root = root, born = os.clock(), face = lv, state = far and "go" or "follow",
    target = target, life = far and 22 or 14,
  }
  TK.bubble(R.parts.Head, TK.MEE_CATCH[math.random(#TK.MEE_CATCH)], 2.8)
  TK.snd("teleport", .5, 1.6)
end
function TK.stepHelper(h, dt) -- false = удалить помощника
  local R, root = h.R, h.root
  if not root.Parent then return false end
  local _, _, hr = TK.getChar()
  if not hr then return true end
  local now = os.clock()
  if now < TK.TIMESTOP_UNTIL then
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
    local flat = TK.V3(goal.X - pos.X, 0, goal.Z - pos.Z)
    local dist = flat.Magnitude
    if dist > stopD then
      local dirv = flat.Unit
      pos = pos + dirv * math.min(dist - stopD, speed * dt)
      h.face = dirv
      moving = true
    elseif h.state == "go" then
      h.state = "work"
      h.workEnd = now + 2.4
      TK.bubble(R.parts.Head, "Готово! Можно мне исчезнуть?", 2.4)
    end
  end
  if h.state == "work" and now > h.workEnd then h.state = "back" end
  local gy = TK.groundAt(pos)
  local jump = (h.state == "work") and math.abs(math.sin(now * 7)) * 1.4 or 0
  local ty = (gy and gy + 3 or pos.Y) + jump
  pos = TK.V3(pos.X, pos.Y + (ty - pos.Y) * math.min(1, dt * 14), pos.Z)
  root.CFrame = CFrame.lookAt(pos, pos + TK.V3(h.face.X, 0, h.face.Z))
  TK.stepRig(R, dt, {
    speed = moving and speed or 0, walkSpeed = 16, air = false, emote = (h.state == "work") and "dance" or nil,
  })
  if now - h.born > h.life then
    TK.burst(pos, TK.RGB(90, 170, 255), 30)
    return false
  end
  return true
end

-- ============================================================
--  БОЙ: приказы Мисиксам, мишени, урон (всё визуально, ничего настоящего не меняется)
-- ============================================================
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

  -- цель жива? (у NPC и игроков смотрим Health, у мишени свой счётчик)
  local function alive(tg)
    if not tg or not tg.model or not tg.model.Parent or not tg.root or not tg.root.Parent then return false end
    local du = deadUntil[tg.model]
    if du then
      if os.clock() < du then return false end
      deadUntil[tg.model], hpOf[tg.model] = nil, nil
    end
    if tg.kind ~= "dummy" then
      local hum = tg.model:FindFirstChildOfClass("Humanoid")
      if not hum or hum.Health <= 0 then return false end
    end
    return true
  end

  -- поиск целей: мишени, NPC и (если разрешено) игроки; себя не трогаем
  local op = OverlapParams.new()
  op.FilterType = Enum.RaycastFilterType.Exclude
  local function scan(center, radius, withPlayers)
    local list = {}
    for _, d in ipairs(dummies) do
      if alive(d) and (d.root.Position - center).Magnitude <= radius then list[#list + 1] = d end
    end
    op.FilterDescendantsInstances = { TK.LP.Character, TK.helperFolder }
    local ok, parts = pcall(function() return TK.Workspace:GetPartBoundsInRadius(center, radius, op) end)
    if ok then
      local seen = {}
      for _, p in ipairs(parts) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m and not seen[m] and m ~= TK.LP.Character then
          seen[m] = true
          local hum = m:FindFirstChildOfClass("Humanoid")
          local root = m:FindFirstChild("HumanoidRootPart")
          if hum and root then
            local isPlayer = TK.Players:GetPlayerFromCharacter(m) ~= nil
            if withPlayers or not isPlayer then
              local tg = { model = m, root = root, kind = isPlayer and "player" or "npc" }
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

  -- эффекты удара: цифра урона, красная подсветка, искры (видишь только ты)
  local function dmgText(adornee, amount)
    local bb = TK.I("BillboardGui", {
      Size = UDim2.fromOffset(60, 24), StudsOffset = TK.V3((math.random() - .5) * 1.5, 2.5, 0),
      AlwaysOnTop = true, LightInfluence = 0,
    }, adornee)
    local l = TK.I("TextLabel", {
      Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "-" .. amount,
      TextColor3 = TK.RGB(255, 80, 80), TextStrokeTransparency = 0, Font = Enum.Font.GothamBold, TextSize = 18,
    }, bb)
    TK.TweenService:Create(bb, TweenInfo.new(.6), { StudsOffset = bb.StudsOffset + TK.V3(0, 2.5, 0) }):Play()
    TK.TweenService:Create(l, TweenInfo.new(.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
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
  local function hitFx(tg, lo, hi) -- true, если цель добита (на экране)
    local dmg = math.random(lo or 8, hi or 15)
    hpOf[tg.model] = (hpOf[tg.model] or 100) - dmg
    dmgText(tg.root, dmg)
    TK.burst(tg.root.Position, TK.RGB(255, 200, 80), 8)
    local hl = TK.I("Highlight", {
      FillColor = TK.RGB(255, 70, 70), FillTransparency = .4, OutlineTransparency = 1, Adornee = tg.model,
    }, tg.model)
    task.delay(.12, function() if hl.Parent then hl:Destroy() end end)
    if tg.kind == "dummy" and not tg.ko then
      tg.model:PivotTo(tg.cf * CFrame.new((math.random() - .5) * .4, 0, (math.random() - .5) * .4))
      task.delay(.08, function() if tg.model.Parent and not tg.ko then tg.model:PivotTo(tg.cf) end end)
    end
    TK.snd("click", .4, 1.4)
    return hpOf[tg.model] <= 0
  end
  local function damage(tg, lo, hi) -- удар + обработка «победы»
    if not hitFx(tg, lo, hi) then return false end
    deadUntil[tg.model] = os.clock() + (tg.kind == "dummy" and 5 or 12)
    TK.burst(tg.root.Position, TK.RGB(255, 200, 80), 24)
    if tg.kind == "dummy" then koDummy(tg) end
    return true
  end
  TK.CB.scan, TK.CB.nearest, TK.CB.damage = scan, nearest, damage

  -- мишень для тренировки (стоит там, куда смотришь)
  local function spawnDummy()
    if #dummies >= 3 then TK.notify("Максимум 3 мишени", TK.C.dg, 1.5) return end
    local pos = TK.aimHit(60)
    local g = TK.groundAt(pos)
    pos = TK.V3(pos.X, g or pos.Y, pos.Z)
    local mo = TK.I("Model", { Name = "RM_Dummy" }, TK.helperFolder)
    local function add(n, sz, col, rel, mat, shape)
      local p = TK.mkp(n, sz, col, mat, shape)
      p.Anchored = true
      p.CFrame = CFrame.new(pos) * rel
      p.Parent = mo
      return p
    end
    add("Base", TK.V3(.4, 2.4, 2.4), TK.RGB(90, 70, 50), CFrame.new(0, .2, 0) * TK.R90, nil, Enum.PartType.Cylinder)
    add("Post", TK.V3(.5, 3.2, .5), TK.RGB(150, 110, 70), CFrame.new(0, 1.8, 0), Enum.Material.Wood)
    local body = add("Body", TK.V3(1.8, 2, .9), TK.RGB(205, 170, 90), CFrame.new(0, 3.6, 0), Enum.Material.Fabric)
    add("Arms", TK.V3(3.2, .4, .4), TK.RGB(150, 110, 70), CFrame.new(0, 4.1, 0), Enum.Material.Wood)
    add("Head", TK.V3(1.1, 1.1, 1.1), TK.RGB(220, 190, 120), CFrame.new(0, 5.1, 0), Enum.Material.Fabric, Enum.PartType.Ball)
    add("Ring1", TK.V3(.1, 1.2, 1.2), TK.RGB(220, 40, 40), CFrame.new(0, 3.6, -.46) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
    add("Ring2", TK.V3(.1, .8, .8), TK.WHITE, CFrame.new(0, 3.6, -.5) * TK.RZ, nil, Enum.PartType.Cylinder)
    add("Ring3", TK.V3(.1, .35, .35), TK.RGB(220, 40, 40), CFrame.new(0, 3.6, -.53) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
    mo.PrimaryPart = body
    dummies[#dummies + 1] = { model = mo, root = body, kind = "dummy", cf = mo:GetPivot() }
    TK.burst(pos + TK.V3(0, 2, 0), TK.RGB(255, 200, 80), 20)
    TK.notify("🎯 Мишень поставлена", TK.C.ac, 1.5)
  end
  RM.spawnDummy = function() TK.safe(spawnDummy) end
  RM.clearDummies = function()
    for i = #dummies, 1, -1 do
      pcall(function() dummies[i].model:Destroy() end)
      table.remove(dummies, i)
    end
  end

  -- ящик вызывает Мисикса-охранника
  TK.spawnMeeseeks = function()
    if #TK.helpers >= 3 then TK.notify("Максимум 3 Мисикса сразу", TK.C.dg, 1.5) return end
    local _, _, hr = TK.getChar()
    if not hr then return end
    local lv = TK.V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
    lv = lv.Magnitude > .01 and lv.Unit or TK.V3(0, 0, -1)
    local ahead = hr.Position + lv * 5
    local gy = TK.groundAt(ahead) or (hr.Position.Y - 3)
    local pos = TK.V3(ahead.X, gy + 3, ahead.Z)
    local root = TK.mkp("MRoot", TK.V3(2, 2, 1), TK.WHITE)
    root.Transparency = 1
    root.Anchored = true
    root.CFrame = CFrame.lookAt(pos, pos + lv)
    local R = TK.newRig(root, TK.SK.meeseeks, 1)
    R.FT = TK.ftar(TK.SK.meeseeks, "happy")
    R.FC = TK.copy(R.FT)
    root.Parent = R.model
    R.model.Parent = TK.helperFolder
    TK.burst(pos, TK.RGB(90, 170, 255), 30)
    TK.helpers[#TK.helpers + 1] = {
      R = R, root = root, born = os.clock(), face = lv, order = "guard", life = 90,
      slot = #TK.helpers, nextScan = 0, nextHit = 0,
    }
    TK.bubble(R.parts.Head, "Я Мистер Мисикс! Я тебя защищу!", 2.8)
    TK.snd("pop", .6)
    TK.ITM.spawnFx(pos)
  end

  -- поведение помощника: приказы, поиск врагов, бой
  local function step(h, dt)
    local R, root = h.R, h.root
    if not root.Parent then return false end
    local _, _, hr = TK.getChar()
    if not hr then return true end
    local now = os.clock()
    if now < TK.TIMESTOP_UNTIL then
      h.born = h.born + dt
      return true
    end
    local pos, P = root.Position, hr.Position
    local order = h.order
    -- поиск цели (охрана бьёт только NPC и мишени; игроков — только по приказу «Атакуй»)
    if (order == "guard" or order == "attack") and not alive(h.target) then
      h.target = nil
      if now >= h.nextScan then
        h.nextScan = now + .6
        local center, radius = P, 32
        if order == "attack" then center, radius = h.orderPos or P, 26 end
        h.target = nearest(scan(center, radius, order == "attack" and TK.ST.AttackPlayers), pos)
        if h.target then TK.bubble(R.parts.Head, FIGHT_CATCH[math.random(#FIGHT_CATCH)], 1.8) end
      end
    end
    local tg = h.target
    -- слишком далеко от хозяина: возвращаем к нему
    if (order == "guard" or order == "follow") and (pos - P).Magnitude > 80 then
      local a = h.slot * 2.094
      pos = P + TK.V3(math.cos(a), 0, math.sin(a)) * 6
      TK.burst(pos, TK.RGB(90, 170, 255), 20)
      h.target, tg = nil, nil
    end
    -- куда идти
    local goal, stopD, speed = nil, 1.5, 20
    if tg then
      goal, stopD, speed = tg.root.Position, 3.2, 24
    elseif order == "guard" then
      local a = h.slot * 2.094
      goal = P + TK.V3(math.cos(a), 0, math.sin(a)) * 6
    elseif order == "follow" then
      goal, stopD = P, 5
    elseif order == "attack" or order == "move" then
      goal, stopD = h.orderPos or P, 2.5
    end
    local moving, inRange = false, false
    if goal then
      local flat = TK.V3(goal.X - pos.X, 0, goal.Z - pos.Z)
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
        TK.bubble(R.parts.Head, "Я на месте!", 2)
      elseif order == "attack" then
        h.order = "guard"
        TK.bubble(R.parts.Head, h.fought and "Победа! Возвращаюсь!" or "Тут никого нет...", 2.2)
        h.fought = false
      end
    end
    -- удар
    local fighting = tg ~= nil and inRange
    if fighting and now >= h.nextHit then
      h.nextHit = now + .45
      if damage(tg, 8, 15) then
        TK.bubble(R.parts.Head, "Победа!", 1.6)
        h.target = nil
        h.fought = true
      end
    end
    -- земля, поворот, анимация
    local gy = TK.groundAt(pos)
    local ty = gy and gy + 3 or pos.Y
    pos = TK.V3(pos.X, pos.Y + (ty - pos.Y) * math.min(1, dt * 14), pos.Z)
    root.CFrame = CFrame.lookAt(pos, pos + TK.V3(h.face.X, 0, h.face.Z))
    TK.stepRig(R, dt, { speed = moving and speed or 0, walkSpeed = 16, air = false })
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
      TK.burst(pos, TK.RGB(90, 170, 255), 30)
      return false
    end
    return true
  end
  TK.stepHelper = function(h, dt)
    local ok, res = pcall(step, h, dt)
    if not ok then
      warn("[RickMorty] Мисикс: " .. tostring(res))
      return false
    end
    return res
  end

  -- приказ всем Мисиксам (цель = точка прицела)
  RM.helperOrder = function(order)
    if #TK.helpers == 0 then TK.notify("Сначала вызови Мисикса ящиком", TK.C.dg, 2) return end
    local pos = TK.aimHit(120)
    local now = os.clock()
    local target = nil
    if order == "attack" then
      target = nearest(scan(pos, 26, TK.ST.AttackPlayers), pos)
      if not target then TK.notify("Рядом с точкой прицела целей нет", TK.C.dg, 2) end
    end
    for _, h in ipairs(TK.helpers) do
      h.born, h.life = now, 90
      h.order, h.orderPos, h.target, h.fought, h.nextScan = order, pos, target, false, 0
      if order == "vanish" then
        h.born = now - 1000
      else
        TK.bubble(h.R.parts.Head, ORDER_TEXT[order], 2)
      end
    end
    TK.notify(ORDER_NAMES[order], TK.C.ac, 1.5)
  end
end

-- 🔋 батарея: зона энергии 15 секунд, заряд 100%, расход 25% за использование
function TK.useBattery()
  if TK.BAT < 25 then TK.notify("🔋 Мало заряда (" .. math.floor(TK.BAT) .. "%)", TK.C.dg, 1.5) return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  TK.BAT = TK.BAT - 25
  local pos = TK.aimHit(70)
  if (pos - hr.Position).Magnitude > 60 then pos = hr.Position + (pos - hr.Position).Unit * 60 end
  local g = TK.groundAt(pos)
  pos = TK.V3(pos.X, g or pos.Y, pos.Z)
  local col = TK.RGB(190, 80, 255)
  local mo = TK.I("Model", { Name = "RM_Zone" }, TK.Workspace)
  local disc = TK.mkp("Zone", TK.V3(.3, 20, 20), col, Enum.Material.Neon, Enum.PartType.Cylinder)
  disc.Anchored = true
  disc.Transparency = .65
  disc.CFrame = CFrame.new(pos + TK.V3(0, .2, 0)) * TK.R90
  disc.Parent = mo
  local ring = TK.mkp("ZoneRing", TK.V3(.4, 20.6, 20.6), col:Lerp(TK.WHITE, .4), Enum.Material.Neon, Enum.PartType.Cylinder)
  ring.Anchored = true
  ring.Transparency = .4
  ring.CFrame = disc.CFrame
  ring.Parent = mo
  local em = TK.mkp("Emitter", TK.V3(18, .2, 18), col)
  em.Anchored = true
  em.Transparency = 1
  em.CFrame = CFrame.new(pos + TK.V3(0, .4, 0))
  em.Parent = mo
  TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 18, Lifetime = NumberRange.new(1.5, 2),
    Speed = NumberRange.new(4, 6), SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(.5, 0),
    Transparency = NumberSequence.new(.1, 1), LightEmission = 1, Color = ColorSequence.new(col),
    EmissionDirection = Enum.NormalId.Top,
  }, em)
  TK.I("PointLight", { Color = col, Range = 22, Brightness = 2, Shadows = false }, disc)
  TK.TweenService:Create(disc, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = .82 }):Play()
  TK.zones[#TK.zones + 1] = { mo = mo, disc = disc, radius = 10, untilT = os.clock() + 15 }
  TK.burst(pos + TK.V3(0, 1, 0), col, 30)
  TK.snd("teleport", .6, .8)
  TK.notify("🔋 Зона энергии на 15 с (заряд " .. math.floor(TK.BAT) .. "%)", col, 2)
end
function TK.updateZones(hr, now)
  local inside = false
  for i = #TK.zones, 1, -1 do
    local zn = TK.zones[i]
    if now > zn.untilT then
      table.remove(TK.zones, i)
      TK.TweenService:Create(zn.disc, TweenInfo.new(.5), { Transparency = 1 }):Play()
      task.delay(.6, function() pcall(function() zn.mo:Destroy() end) end)
    elseif hr then
      local off = hr.Position - zn.disc.Position
      if TK.V3(off.X, 0, off.Z).Magnitude < zn.radius and math.abs(off.Y) < 10 then inside = true end
    end
  end
  if inside ~= TK.inZone then
    TK.inZone = inside
    local aura = hr and hr:FindFirstChild("RM_Aura")
    if inside and hr then
      if not aura then
        TK.I("PointLight", { Name = "RM_Aura", Color = TK.RGB(200, 90, 255), Range = 14, Brightness = 3, Shadows = false }, hr)
      end
      TK.notify("⚡ Ты в зоне энергии", TK.RGB(200, 120, 255), 1.5)
    elseif aura then
      aura:Destroy()
    end
  end
end

-- 🚀 космический крейсер по фото (серая тарелка, купол, жёлтые полосы, двигатель, ножки)
TK.SHIP_H = 3.7 -- высота центра корпуса над землёй (скорость берётся из ST.ShipSpeed)
TK.SEAT = CFrame.new(0, 1.75, .5)
function TK.ell(model, name, size, col, rel, mat) -- эллипсоид через SpecialMesh
  local p = TK.mkp(name, size, col, mat)
  p.Anchored = true
  p.CFrame = rel
  TK.I("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, p)
  p.Parent = model
  return p
end
function TK.buildShip()
  local model = TK.I("Model", { Name = "RM_Cruiser" }, TK.Workspace)
  local function add(name, size, col, rel, mat, shape)
    local p = TK.mkp(name, size, col, mat, shape)
    p.Anchored = true
    p.CFrame = rel
    p.Parent = model
    return p
  end
  local GRAY, LIGHT, DARK, YEL = TK.RGB(88, 96, 104), TK.RGB(185, 192, 200), TK.RGB(40, 44, 50), TK.RGB(235, 190, 40)
  local hull = TK.ell(model, "Hull", TK.V3(11, 3.2, 11), GRAY, CFrame.new(0, -.2, 0), Enum.Material.Metal)
  model.PrimaryPart = hull
  add("Rim", TK.V3(.9, 12, 12), LIGHT, CFrame.new(0, .3, 0) * TK.R90, Enum.Material.Metal, Enum.PartType.Cylinder)
  TK.ell(model, "Deck", TK.V3(9.5, 1.8, 9.5), TK.RGB(170, 176, 184), CFrame.new(0, .9, 0), Enum.Material.Metal)
  for _, s in ipairs({ -1, 1 }) do
    add("Stripe", TK.V3(1.2, .1, 3.6), YEL, CFrame.new(s * 3.2, 1.3, -2.4) * CFrame.Angles(0, math.rad(-30 * s), 0))
    TK.ell(model, "Vent", TK.V3(1.4, .7, 1.1), TK.RGB(200, 185, 140), CFrame.new(s * 2.6, 1.15, -3.6))
    add("Light", TK.V3(.6, .2, .2), TK.RGB(255, 240, 150), CFrame.new(s * 1.2, .5, -5.3), Enum.Material.Neon)
  end
  add("StripeBack", TK.V3(3, .1, .9), YEL, CFrame.new(0, 1.15, 4.4))
  local dome = TK.ell(model, "Dome", TK.V3(5.2, 3.6, 6.4), TK.RGB(190, 230, 255), CFrame.new(0, 2.4, -.6), Enum.Material.Glass)
  dome.Transparency = .5
  add("Seat", TK.V3(1.5, .3, 1.5), TK.RGB(70, 58, 52), CFrame.new(0, 1.15, .5))
  add("SeatBack", TK.V3(1.5, 1.6, .3), TK.RGB(70, 58, 52), CFrame.new(0, 2, 1.3))
  add("Console", TK.V3(2.2, .5, .8), DARK, CFrame.new(0, 1.5, -1.7))
  for _, s in ipairs({ -1, 1 }) do
    add("Screen", TK.V3(.5, .3, .05), TK.RGB(90, 240, 220), CFrame.new(s * .6, 1.85, -2.05), Enum.Material.Neon)
    add("Lever", TK.V3(.08, .7, .08), DARK, CFrame.new(s * .95, 1.9, -1.4))
  end
  add("Engine", TK.V3(2.6, 2.4, 2.4), TK.RGB(120, 126, 132), CFrame.new(0, 1, 5.7) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
  add("EngineIn", TK.V3(.2, 1.8, 1.8), TK.RGB(10, 10, 12), CFrame.new(0, 1, 7) * TK.RZ, nil, Enum.PartType.Cylinder)
  local glow = add("EngineGlow", TK.V3(.1, 1.2, 1.2), TK.RGB(120, 200, 255), CFrame.new(0, 1, 7.05) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 15, Lifetime = NumberRange.new(.4, .7),
    Speed = NumberRange.new(6, 9), Size = NumberSequence.new(.9, 0), LightEmission = 1, Color = ColorSequence.new(TK.RGB(120, 200, 255)),
    EmissionDirection = Enum.NormalId.Back,
  }, glow)
  add("Wing", TK.V3(7, .25, 1.8), GRAY, CFrame.new(0, 3, 5.2))
  add("WingPanel", TK.V3(2.2, .06, 1.2), TK.RGB(240, 150, 40), CFrame.new(-2, 3.15, 5.2))
  for _, s in ipairs({ -1, 1 }) do
    add("Support", TK.V3(.3, 1.6, .3), DARK, CFrame.new(s * 2.5, 2.2, 5.2))
  end
  for i = 0, 3 do -- четыре ножки с опорами
    local a = math.rad(45 + i * 90)
    local x, z = math.sin(a) * 3.8, math.cos(a) * 3.8
    add("Leg", TK.V3(.35, 2.6, .35), DARK, CFrame.new(x, -1.9, z) * CFrame.Angles(math.sin(a) * .0, 0, 0))
    add("Foot", TK.V3(.9, .4, 1.1), TK.RGB(30, 32, 38), CFrame.new(x * 1.12, -3.25, z * 1.12) * CFrame.Angles(0, a, 0))
  end
  TK.I("PointLight", { Color = TK.RGB(180, 220, 255), Range = 18, Brightness = 1.5, Shadows = false }, hull)
  -- большие пушки по бокам (дула смотрят вперёд)
  for _, s in ipairs({ -1, 1 }) do
    add("CannonBase", TK.V3(1.8, .9, 1.8), DARK, CFrame.new(s * 3.2, .35, -3.6), Enum.Material.Metal)
    add("Cannon", TK.V3(4.2, 1.3, 1.3), TK.RGB(70, 76, 86), CFrame.new(s * 3.2, .7, -4.8) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
    add("CannonRing", TK.V3(.5, 1.8, 1.8), YEL, CFrame.new(s * 3.2, .7, -6.7) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
    add("CannonGlow", TK.V3(.2, 1, 1), TK.RGB(255, 90, 60), CFrame.new(s * 3.2, .7, -6.95) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  end
  -- твёрдые части (на них можно стоять) и кликабельность всего корабля
  local solids = {}
  for _, p in ipairs(model:GetChildren()) do
    p.CanQuery = true
    local nm = p.Name
    if nm == "Hull" or nm == "Rim" or nm == "Deck" or nm == "Wing" or nm == "Engine" or nm == "Foot" then
      solids[#solids + 1] = p
    end
  end
  return model, dome, solids
end
function TK.summonShip()
  local _, _, hr = TK.getChar()
  if not hr then return end
  if TK.RIDING or (TK.ship and TK.ship.board) then TK.dismount(true) end
  if TK.ship then pcall(function() TK.ship.model:Destroy() end) TK.ship = nil end
  local lv = TK.V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
  lv = lv.Magnitude > .01 and lv.Unit or TK.V3(0, 0, -1)
  local ahead = hr.Position + lv * 18
  local gy = TK.groundAt(ahead) or (hr.Position.Y - 3)
  local land = TK.V3(ahead.X, gy + TK.SHIP_H, ahead.Z)
  local model, dome, solids = TK.buildShip()
  TK.ship = {
    model = model, dome = dome, solids = solids, land = land, pos = land + TK.V3(0, 60, 0),
    yaw = math.atan2(-lv.X, -lv.Z), vel = TK.V3(), state = "landing", t = 0, cf = CFrame.new(land),
  }
  model:PivotTo(CFrame.new(TK.ship.pos) * CFrame.Angles(0, TK.ship.yaw, 0))
  TK.dimFx(TK.RGB(255, 170, 70), .6)
  TK.notify("🚀 Крейсер прибывает...", TK.C.ac, 2)
end
-- твёрдость: пока корабль стоит, на него можно залезть и стоять на палубе
function TK.SH.solid(on) end -- физическая твёрдость отключена: корабль не толкает игроков
-- купол открывается на шарнире сзади (open: 0..1)
function TK.SH.dome(open)
  if not TK.ship or not TK.ship.dome or not TK.ship.dome.Parent then return end
  TK.ship.dome.CFrame = TK.ship.cf * CFrame.new(0, 2.4, -.6) * CFrame.new(0, 0, 3.2)
    * CFrame.Angles(open * .9, 0, 0) * CFrame.new(0, 0, -3.2)
end
-- пушки крейсера: красные болты в точку прицела, урон по цели рядом (визуально)
function TK.SH.fireOld()
  if not TK.RIDING or not TK.ship or TK.ship.board then return end
  local now = os.clock()
  if now < TK.SH.fireCd then return end
  TK.SH.fireCd = now + .22
  local pos = TK.aimHit(800)
  TK.SH.side = -TK.SH.side
  local muzzle = (TK.ship.cf * CFrame.new(TK.SH.side * 3.2, .2, -4.4)).Position
  local delta = pos - muzzle
  local dist = delta.Magnitude
  if dist < 2 then return end
  local dir = delta.Unit
  local len = math.min(dist, 7)
  local bolt = TK.mkp("Bolt", TK.V3(.4, .4, len), TK.RGB(255, 70, 70), Enum.Material.Neon)
  bolt.Anchored = true
  bolt.CFrame = CFrame.lookAt(muzzle, muzzle + dir) * CFrame.new(0, 0, -len / 2)
  bolt.Parent = TK.Workspace
  local fly = math.clamp(dist / 500, .05, .5)
  TK.TweenService:Create(bolt, TweenInfo.new(fly, Enum.EasingStyle.Linear), {
    CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, len / 2),
  }):Play()
  TK.snd("shoot", .5, 1.3)
  task.delay(fly, function()
    bolt:Destroy()
    TK.burst(pos, TK.RGB(255, 120, 60), 16)
    local tg = TK.CB.nearest(TK.CB.scan(pos, 7, TK.ST.AttackPlayers), pos)
    if tg then TK.CB.damage(tg, 20, 35) end
  end)
end
-- виртуальный пол палубы: ставит тебя на крышу корабля, не толкает ни тебя, ни других
TK.SH.onDeck = false
function TK.SH.deck(hr, hum)
  TK.SH.onDeck = false
  if not TK.ship or TK.ship.state ~= "idle" or TK.RIDING or TK.ship.board or not hr or not hum then return end
  local off = hr.Position - TK.ship.pos
  if TK.V3(off.X, 0, off.Z).Magnitude > 4.6 then return end
  local half = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + hr.Size.Y / 2) or 3
  local feet = hr.Position.Y - half
  local top = TK.ship.pos.Y + 1.8
  local vel = hr.AssemblyLinearVelocity
  if vel.Y <= 1 and feet >= top - .7 and feet <= top + .5 then
    hr.CFrame = hr.CFrame + TK.V3(0, top - feet, 0)
    if hum.Jump then
      local jv = hum.UseJumpPower and hum.JumpPower or math.sqrt(2 * TK.Workspace.Gravity * hum.JumpHeight)
      hr.AssemblyLinearVelocity = TK.V3(vel.X, jv, vel.Z)
    else
      hr.AssemblyLinearVelocity = TK.V3(vel.X, 0, vel.Z)
    end
    TK.SH.onDeck = true
  end
end
-- большие пушки: крупные болты, дальность x5, взрыв со сферой
function TK.SH.fire()
  if not TK.RIDING or not TK.ship or TK.ship.board then return end
  local now = os.clock()
  if now < TK.SH.fireCd then return end
  TK.SH.fireCd = now + .28
  local pos = TK.aimHit(4000, 250)
  TK.SH.side = -TK.SH.side
  local muzzle = (TK.ship.cf * CFrame.new(TK.SH.side * 3.2, .7, -7.2)).Position
  local delta = pos - muzzle
  local dist = delta.Magnitude
  if dist < 2 then return end
  local dir = delta.Unit
  local len = math.min(dist, 16)
  local bolt = TK.mkp("Bolt", TK.V3(1.3, 1.3, len), TK.RGB(255, 70, 70), Enum.Material.Neon)
  bolt.Anchored = true
  TK.I("PointLight", { Color = TK.RGB(255, 80, 60), Range = 22, Brightness = 4, Shadows = false }, bolt)
  bolt.CFrame = CFrame.lookAt(muzzle, muzzle + dir) * CFrame.new(0, 0, -len / 2)
  bolt.Parent = TK.Workspace
  local fly = math.clamp(dist / 900, .05, 1.2)
  TK.TweenService:Create(bolt, TweenInfo.new(fly, Enum.EasingStyle.Linear), {
    CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, len / 2),
  }):Play()
  TK.burst(muzzle, TK.RGB(255, 200, 80), 14)
  TK.snd("shoot", .7, .9)
  task.delay(fly, function()
    bolt:Destroy()
    TK.burst(pos, TK.RGB(255, 120, 60), 40)
    local ex = TK.mkp("Blast", TK.V3(2, 2, 2), TK.RGB(255, 140, 60), Enum.Material.Neon, Enum.PartType.Ball)
    ex.Anchored = true
    ex.Transparency = .3
    ex.Position = pos
    ex.Parent = TK.Workspace
    TK.TweenService:Create(ex, TweenInfo.new(.4), { Size = TK.V3(16, 16, 16), Transparency = 1 }):Play()
    task.delay(.45, function() ex:Destroy() end)
    local tg = TK.CB.nearest(TK.CB.scan(pos, 14, TK.ST.AttackPlayers), pos)
    if tg then TK.CB.damage(tg, 40, 70) end
  end)
end
-- гипер-прыжок: рывок вперёд с эффектом перехода между измерениями
function TK.SH.hyper()
  if not TK.RIDING or not TK.ship or TK.ship.board then return end
  local now = os.clock()
  if now < TK.SH.hyperCd then TK.notify("🌌 Гипер-прыжок через " .. math.ceil(TK.SH.hyperCd - now) .. " с", TK.C.dg, 1) return end
  TK.SH.hyperCd = now + 6
  local fwd = CFrame.Angles(0, TK.ship.yaw, 0).LookVector
  local dist = math.clamp(TK.ST.ShipSpeed * .8, 120, 600)
  local col = TK.RGB(160, 120, 255)
  TK.dimFx(col, 1.2)
  for i = 1, 6 do TK.burst(TK.ship.pos + fwd * (dist * i / 6), col, 10) end
  TK.ship.pos = TK.ship.pos + fwd * dist
  TK.ship.vel = fwd * math.max(TK.ship.vel.Magnitude, TK.ST.ShipSpeed * .5)
  TK.notify("🌌 Гипер-прыжок!", col, 1.5)
end

-- посадка: тап по кораблю или кнопка; персонаж прыгает в кабину, купол открывается
function TK.board()
  local _, hum, hr = TK.getChar()
  if not TK.ship or TK.RIDING or TK.ship.board or not hum or not hr then return end
  if TK.ship.state ~= "idle" then TK.notify("Крейсер ещё садится", TK.C.dg, 1.5) return end
  local dist = (hr.Position - TK.ship.pos).Magnitude
  if dist > 90 then TK.notify("Крейсер далеко: вызови его", TK.C.dg, 2) return end
  TK.EMOTE = nil
  hum.PlatformStand = true
  TK.SH.solid(false)
  TK.ship.vel = TK.V3()
  TK.ship.board = { kind = "in", t = 0, dur = .95, from = hr.CFrame, arc = 3 + dist * .04 }
  TK.snd("teleport", .5, 1.5)
  TK.notify("🚀 Полёт: джойстик/WASD, ▲▼, 🔥 — огонь, 🌌 — прыжок", TK.C.ac, 3)
end
-- высадка с прыжком; instant = мгновенно (смерть, пересоздание корабля)
function TK.dismount(instant)
  local _, hum, hr = TK.getChar()
  if not TK.ship then
    TK.RIDING = false
    if hum then hum.PlatformStand = false end
    return
  end
  if instant then
    TK.RIDING = false
    TK.ship.board = nil
    TK.rideKeys.up, TK.rideKeys.down = false, false
    if hum then hum.PlatformStand = false end
    if hr then
      hr.CFrame = CFrame.new(TK.ship.pos) * CFrame.Angles(0, TK.ship.yaw, 0) * CFrame.new(7, 2.2, 0)
      hr.AssemblyLinearVelocity = TK.V3()
    end
    TK.SH.solid(true)
    return
  end
  if not TK.RIDING or TK.ship.board or not hr then return end
  TK.RIDING = false
  TK.rideKeys.up, TK.rideKeys.down = false, false
  TK.ship.vel = TK.V3()
  TK.ship.board = {
    kind = "out", t = 0, dur = .85, from = hr.CFrame, arc = 3.5,
    to = CFrame.new(TK.ship.pos) * CFrame.Angles(0, TK.ship.yaw, 0) * CFrame.new(7, 2.2, 0),
  }
end
function TK.shipAction()
  local _, _, hr = TK.getChar()
  if not hr then return end
  if TK.RIDING then TK.dismount() return end
  if not TK.ship then TK.summonShip() return end
  if TK.ship.state == "idle" and (hr.Position - TK.ship.pos).Magnitude < 90 then TK.board() else TK.summonShip() end
end
function TK.stepShip(dt)
  if not TK.ship or not TK.ship.model.Parent then TK.SH.onDeck = false return end
  local _, hum, hr = TK.getChar()
  if (TK.RIDING or TK.ship.board) and (not hum or hum.Health <= 0 or not hr) then TK.dismount(true) end
  if TK.SH.held and TK.RIDING and not TK.ship.board then TK.SH.fire() end
  local now = os.clock()
  local pitch, roll = 0, 0
  if TK.ship.state == "landing" then
    TK.ship.t = TK.ship.t + dt
    local a = math.min(1, TK.ship.t / 1.5)
    a = 1 - (1 - a) ^ 3
    TK.ship.pos = TK.V3(TK.ship.land.X, TK.ship.land.Y + (1 - a) * 60, TK.ship.land.Z)
    if TK.ship.t >= 1.5 then
      TK.ship.state = "idle"
      TK.SH.solid(true)
    end
  elseif TK.RIDING and not TK.ship.board and hum then
    local speed = TK.ST.ShipSpeed
    local md = hum.MoveDirection
    local vy = (TK.rideKeys.up and 1 or 0) - (TK.rideKeys.down and 1 or 0)
    local want = TK.V3(md.X * speed, vy * math.max(40, speed * .6), md.Z * speed)
    TK.ship.vel = TK.ship.vel:Lerp(want, math.min(1, dt * 2.5))
    TK.ship.pos = TK.ship.pos + TK.ship.vel * dt
    local gy = TK.groundAt(TK.ship.pos)
    if gy and TK.ship.pos.Y < gy + TK.SHIP_H then
      TK.ship.pos = TK.V3(TK.ship.pos.X, gy + TK.SHIP_H, TK.ship.pos.Z)
      if TK.ship.vel.Y < 0 then TK.ship.vel = TK.V3(TK.ship.vel.X, 0, TK.ship.vel.Z) end
    end
    if md.Magnitude > .15 then
      local ty = math.atan2(-md.X, -md.Z)
      local diff = (ty - TK.ship.yaw + math.pi) % (2 * math.pi) - math.pi
      TK.ship.yaw = TK.ship.yaw + diff * math.min(1, dt * 4)
    end
    local lv = CFrame.Angles(0, TK.ship.yaw, 0):VectorToObjectSpace(TK.ship.vel)
    pitch = lv.Z / speed * .25
    roll = -lv.X / speed * .3
  end
  local bobY = TK.RIDING and math.sin(now * 2) * .12 or 0
  TK.ship.cf = CFrame.new(TK.ship.pos + TK.V3(0, bobY, 0)) * CFrame.Angles(0, TK.ship.yaw, 0) * CFrame.Angles(pitch, 0, roll)
  TK.ship.model:PivotTo(TK.ship.cf)
  TK.SH.deck(hr, hum)
  local open = 0
  local b = TK.ship.board
  if b and hr then
    -- анимация посадки/высадки: дуга прыжка, купол открывается и закрывается
    b.t = b.t + dt
    local u = math.min(1, b.t / b.dur)
    local e = u * u * (3 - 2 * u)
    local target = (b.kind == "in") and (TK.ship.cf * TK.SEAT) or b.to
    hr.CFrame = b.from:Lerp(target, e) + TK.V3(0, math.sin(math.pi * e) * b.arc, 0)
    hr.AssemblyLinearVelocity = TK.V3()
    open = (u < .2) and (u / .2) or ((u < .75) and 1 or (1 - u) / .25)
    TK.ship.boardW = math.sin(math.pi * u)
    if u >= 1 then
      TK.ship.board, TK.ship.boardW = nil, nil
      if b.kind == "in" then
        TK.RIDING = true
      else
        if hum then hum.PlatformStand = false end
        TK.SH.solid(true)
      end
    end
  elseif TK.RIDING and hr then
    hr.CFrame = TK.ship.cf * TK.SEAT
    hr.AssemblyLinearVelocity = TK.V3()
    hr.AssemblyAngularVelocity = TK.V3()
  end
  TK.SH.dome(open)
end
TK.track(TK.RunService.RenderStepped:Connect(function(dt)
  local ok, e = pcall(TK.stepShip, dt)
  if not ok then
    TK.SH.errs = (TK.SH.errs or 0) + 1
    if TK.SH.errs <= 3 then warn("[RickMorty] ошибка крейсера: " .. tostring(e)) end
  end
end))

-- панель управления полётом: ▲ ▼ 🌌 и кнопка слезть
TK.ridePanel = TK.I("Frame", {
  Size = UDim2.fromOffset(70, 212), Position = UDim2.new(1, -90, 1, -350), BackgroundTransparency = 1,
  Visible = false, ZIndex = 58,
}, TK.gui)
function TK.rideBtn(txt, y, key, fn)
  local b = TK.I("TextButton", {
    Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, y), BackgroundColor3 = TK.C.bg, BackgroundTransparency = .15,
    TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 26, Text = txt, ZIndex = 59,
  }, TK.ridePanel)
  TK.cr(b, 16)
  TK.sk(b, TK.C.ac, 1.5, .3)
  if key then
    b.MouseButton1Down:Connect(function() TK.rideKeys[key] = true end)
    b.MouseButton1Up:Connect(function() TK.rideKeys[key] = false end)
    b.MouseLeave:Connect(function() TK.rideKeys[key] = false end)
  end
  if fn then b.MouseButton1Click:Connect(fn) end
end
TK.rideBtn("▲", 0, "up")
TK.rideBtn("▼", 72, "down")
TK.rideBtn("🌌", 144, nil, function() TK.SH.hyper() end)
TK.dismountBtn = TK.I("TextButton", {
  Size = UDim2.fromOffset(120, 40), Position = UDim2.new(.5, -60, 0, 12), BackgroundColor3 = TK.C.bg, BackgroundTransparency = .15,
  TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 13, Text = "🚪 Слезть", Visible = false, ZIndex = 59,
}, TK.gui)
TK.cr(TK.dismountBtn, 10)
TK.sk(TK.dismountBtn, TK.C.ac, 1.5, .3)
TK.dismountBtn.MouseButton1Click:Connect(function() TK.dismount() end)
-- клавиши: Space/Shift — вверх/вниз, H — гипер-прыжок, зажатая ЛКМ — огонь
TK.track(TK.UIS.InputBegan:Connect(function(i, gpe)
  if gpe then return end
  if i.KeyCode == Enum.KeyCode.Space then TK.rideKeys.up = true end
  if i.KeyCode == Enum.KeyCode.LeftShift then TK.rideKeys.down = true end
  if i.KeyCode == Enum.KeyCode.H then TK.SH.hyper() end
  if i.UserInputType == Enum.UserInputType.MouseButton1 and TK.RIDING then TK.SH.held = true end
end))
TK.track(TK.UIS.InputEnded:Connect(function(i)
  if i.KeyCode == Enum.KeyCode.Space then TK.rideKeys.up = false end
  if i.KeyCode == Enum.KeyCode.LeftShift then TK.rideKeys.down = false end
  if i.UserInputType == Enum.UserInputType.MouseButton1 then TK.SH.held = false end
end))
-- тап/клик по кораблю: сразу садимся
TK.track(TK.UIS.InputBegan:Connect(function(i, gpe)
  if gpe or not TK.ship or TK.RIDING or TK.ship.board or TK.ship.state ~= "idle" then return end
  if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
  local r = TK.Workspace.CurrentCamera:ViewportPointToRay(i.Position.X, i.Position.Y)
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { TK.LP.Character }
  local res = TK.Workspace:Raycast(r.Origin, r.Direction * 300, rp)
  if res and res.Instance:IsDescendantOf(TK.ship.model) then TK.board() end
end))

-- ============================================================
--  ПРЕДМЕТЫ: список и выдача
-- ============================================================
-- ============================================================
--  НОВЫЕ ПРЕДМЕТЫ v5.0: генератор Мисиксов, шлем Рика, энергощит
-- ============================================================
function TK.miniTool(name, tip, hsize, hcol)
  local tool = TK.I("Tool", { Name = name, RequiresHandle = true, CanBeDropped = false, ToolTip = tip })
  local h = TK.mkp("Handle", hsize, hcol, Enum.Material.Metal)
  h.Parent = tool
  return tool, h, function(...) return TK.toolPart(tool, h, ...) end
end

-- 🟦 генератор Мисиксов: ручной излучатель с голубым ядром
function TK.ITM.buildGen()
  local tool, _, P = TK.miniTool("Генератор Мисиксов", "Создать помощника", TK.V3(.5, 1.1, .5), TK.RGB(40, 70, 72))
  local BL = TK.RGB(90, 180, 255)
  P("Body", TK.V3(.9, .8, 1.3), TK.RGB(60, 110, 108), CFrame.new(0, .7, -.45), Enum.Material.Metal)
  P("Ring", TK.V3(.14, 1.1, 1.1), TK.RGB(30, 40, 44), CFrame.new(0, .7, -1.15) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
  local core = P("Core", TK.V3(.3, .75, .75), BL, CFrame.new(0, .7, -1.2) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  core.Transparency = .15
  TK.I("PointLight", { Color = BL, Range = 9, Brightness = 2, Shadows = false }, core)
  P("Btn", TK.V3(.12, .4, .4), TK.RGB(120, 250, 180), CFrame.new(0, 1.15, -.3) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  for _, s in ipairs({ -1, 1 }) do
    P("Coil", TK.V3(.1, .6, .1), TK.RGB(150, 220, 255), CFrame.new(s * .5, .75, -.9), Enum.Material.Neon)
  end
  return tool
end
function TK.ITM.genFx(tool)
  if not tool then return end
  local c = tool:FindFirstChild("Core", true)
  if c then TK.pulsePart(c, .6, TK.WHITE) end
  TK.lightSpike(tool, 6)
end

-- 🪖 шлем Рика: надевается на голову скина (или персонажа), снимается второй активацией
function TK.headPart()
  if TK.RIG and TK.RIG.parts and TK.RIG.parts.Head and TK.RIG.parts.Head.Parent then return TK.RIG.parts.Head end
  local ch = TK.LP.Character
  return ch and ch:FindFirstChild("Head")
end
function TK.ITM.buildHelmetTool()
  local tool, h, P = TK.miniTool("Шлем Рика", "Надеть / снять шлем", TK.V3(.8, .8, .8), TK.RGB(170, 175, 185))
  h.Shape = Enum.PartType.Ball
  P("Glass", TK.V3(1.05, 1.05, 1.05), TK.RGB(150, 220, 255), CFrame.new(0, .05, 0), Enum.Material.Glass, Enum.PartType.Ball).Transparency = .6
  P("Collar", TK.V3(.12, 1, 1), TK.RGB(120, 125, 135), CFrame.new(0, -.45, 0) * TK.R90, Enum.Material.Metal, Enum.PartType.Cylinder)
  return tool
end
function TK.helmetModel(head)
  local m = TK.I("Model", { Name = "RM_Helmet" }, TK.Workspace)
  local root = TK.mkp("HRoot", TK.V3(.2, .2, .2), TK.WHITE)
  root.Transparency = 1
  root.Massless = true
  root.Parent = m
  local w = Instance.new("Weld")
  w.Part0, w.Part1, w.C0 = head, root, CFrame.new(0, .1, 0)
  w.Parent = root
  local function add(name, size, col, mat, shape, cf, tr)
    local p = TK.mkp(name, size, col, mat, shape)
    p.Massless = true
    if tr then p.Transparency = tr end
    p.CFrame = root.CFrame * cf
    local ww = Instance.new("Weld")
    ww.Part0, ww.Part1, ww.C0 = root, p, cf
    ww.Parent = p
    p.Parent = m
    return p
  end
  local hs = head.Size
  local r = math.max(hs.X, hs.Y, hs.Z) * 1.25
  add("Dome", TK.V3(r, r, r), TK.RGB(150, 220, 255), Enum.Material.Glass, Enum.PartType.Ball, CFrame.new(), .65)
  add("Collar", TK.V3(.25, r * .82, r * .82), TK.RGB(120, 125, 135), Enum.Material.Metal, Enum.PartType.Cylinder,
    CFrame.new(0, -r * .42, 0) * TK.R90)
  add("Light", TK.V3(.18, .18, .18), TK.RGB(255, 240, 150), Enum.Material.Neon, Enum.PartType.Ball, CFrame.new(r * .46, r * .1, -r * .18))
  add("Light", TK.V3(.18, .18, .18), TK.RGB(255, 240, 150), Enum.Material.Neon, Enum.PartType.Ball, CFrame.new(-r * .46, r * .1, -r * .18))
  TK.I("PointLight", { Color = TK.RGB(180, 230, 255), Range = 8, Brightness = 1, Shadows = false }, root)
  return m, root
end
function TK.ITM.removeHelmet(fast)
  local m = TK.X.helmet
  TK.X.helmet, TK.X.helmetHead = nil, nil
  if m and m.Parent then
    if fast then
      pcall(function() m:Destroy() end)
    else
      for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HRoot" then
          pcall(function() TK.TweenService:Create(d, TweenInfo.new(.25), { Transparency = 1 }):Play() end)
        end
      end
      task.delay(.3, function() pcall(function() m:Destroy() end) end)
    end
  end
end
function TK.ITM.wearHelmet()
  local head = TK.headPart()
  if not head then return false end
  TK.ITM.removeHelmet(true)
  TK.X.helmet = TK.helmetModel(head)
  TK.X.helmetHead = head
  return true
end
function TK.ITM.toggleHelmet()
  if TK.X.helmet and TK.X.helmet.Parent then
    TK.ITM.removeHelmet()
    TK.snd("equip", .4, .8)
    TK.notify("🪖 Шлем снят", TK.C.tx, 1.2)
  else
    if TK.ITM.wearHelmet() then
      local h = TK.headPart()
      if h then TK.burst(h.Position, TK.RGB(150, 220, 255), 14) end
      TK.snd("equip", .5, 1.1)
      TK.notify("🪖 Шлем надет", TK.C.ac, 1.2)
    else
      TK.notify("Нет головы для шлема", TK.C.dg, 1.5)
    end
  end
end
function TK.ITM.stepHelmet()
  if not TK.X.helmet then return end
  local head = TK.headPart()
  if not TK.X.helmet.Parent or not head then TK.ITM.removeHelmet(true) return end
  if head ~= TK.X.helmetHead then -- скин сменился: перевешиваем шлем на новую голову
    TK.ITM.wearHelmet()
  end
  local cam = TK.Workspace.CurrentCamera
  if cam and TK.X.helmet then -- от первого лица стекло не мешает
    local near = (cam.CFrame.Position - head.Position).Magnitude < 1.6
    for _, d in ipairs(TK.X.helmet:GetDescendants()) do
      if d:IsA("BasePart") then d.LocalTransparencyModifier = near and 1 or 0 end
    end
  end
end

-- 🛡 энергощит: прозрачный купол вокруг тебя на 8 с, перезарядка 12 с
function TK.ITM.buildShieldTool()
  local tool, _, P = TK.miniTool("Энергощит", "Включить щит на 8 с", TK.V3(.5, 1, .5), TK.RGB(45, 55, 80))
  local BL = TK.RGB(110, 190, 255)
  P("Body", TK.V3(.8, .7, .8), TK.RGB(80, 95, 130), CFrame.new(0, .6, -.2), Enum.Material.Metal)
  local o = P("Orb", TK.V3(.7, .7, .7), BL, CFrame.new(0, 1.15, -.2), Enum.Material.Neon, Enum.PartType.Ball)
  o.Transparency = .25
  TK.I("PointLight", { Color = BL, Range = 9, Brightness = 2, Shadows = false }, o)
  P("Ring", TK.V3(.1, 1, 1), TK.RGB(150, 220, 255), CFrame.new(0, .95, -.2) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  return tool
end
function TK.ITM.dropShield()
  local s = TK.X.shield
  TK.X.shield, TK.X.shieldUntil = nil, 0
  if s and s.Parent then
    TK.TweenService:Create(s, TweenInfo.new(.3), { Size = TK.V3(2, 2, 2), Transparency = 1 }):Play()
    task.delay(.35, function() pcall(function() s:Destroy() end) end)
  end
end
function TK.ITM.toggleShield()
  local now = os.clock()
  if TK.X.shield then TK.ITM.dropShield() TK.snd("close", .4) return end
  if now < (TK.X.shieldCd or 0) then TK.notify("🛡 Перезарядка " .. math.ceil(TK.X.shieldCd - now) .. " с", TK.C.dg, 1) return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  TK.X.shieldCd = now + 12
  TK.X.shieldUntil = now + 8
  local s = TK.I("Part", {
    Name = "RM_Shield", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false,
    CanTouch = false, CastShadow = false, Material = Enum.Material.ForceField, Color = TK.RGB(110, 190, 255),
    Transparency = .45, Size = TK.V3(2, 2, 2), CFrame = hr.CFrame,
  }, TK.Workspace)
  TK.X.shield = s
  TK.TweenService:Create(s, TweenInfo.new(.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = TK.V3(9, 9, 9) }):Play()
  TK.burst(hr.Position, TK.RGB(110, 190, 255), 16)
  TK.snd("open", .5, 1.3)
  TK.notify("🛡 Щит включён (8 с)", TK.RGB(150, 210, 255), 1.5)
end
function TK.ITM.stepShield(now, hr)
  local s = TK.X.shield
  if not s then return end
  if not s.Parent or not hr or now > TK.X.shieldUntil then TK.ITM.dropShield() return end
  s.CFrame = hr.CFrame
  if TK.X.shieldUntil - now < 1.5 then s.Transparency = .45 + (math.floor(now * 10) % 2) * .3 end
end

-- эффекты появления / исчезновения Мисикса
function TK.ITM.spawnFx(pos, col)
  col = col or TK.RGB(90, 170, 255)
  local beam = TK.I("Part", {
    Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = .3, Size = TK.V3(9, 4, 4),
    CFrame = CFrame.new(pos) * TK.R90,
  }, TK.fxFolder)
  TK.TweenService:Create(beam, TweenInfo.new(.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = TK.V3(9, .2, .2), Transparency = 1,
  }):Play()
  task.delay(.7, function() beam:Destroy() end)
  local ring = TK.I("Part", {
    Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = .2, Size = TK.V3(.15, 2, 2),
    CFrame = CFrame.new(pos - TK.V3(0, 2.5, 0)) * TK.R90,
  }, TK.fxFolder)
  TK.TweenService:Create(ring, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = TK.V3(.15, 12, 12), Transparency = 1,
  }):Play()
  task.delay(.8, function() ring:Destroy() end)
  TK.burst(pos, col, 30)
end
function TK.ITM.vanishFx(h)
  local ok, p = pcall(function() return h.root.Position end)
  if ok and p then
    TK.burst(p, TK.RGB(90, 170, 255), 28)
    TK.ITM.spawnFx(p)
    TK.snd("vanish", .4)
  end
end

TK.ITEMS = {
  { id = "gun_rick", ico = "🔫", name = "Портальная пушка Рика", desc = "Классическая пушка Рика", build = TK.buildGunRick, act = function() TK.shootPortal("rick") end, grip = TK.V3(0, -.05, 0) },
  { id = "gun_prime", ico = "🔫", name = "Портальная пушка Рика Прайма", desc = "Пушка Рика Прайма", build = TK.buildGunPrime, act = function() TK.shootPortal("rick_prime") end, grip = TK.V3(0, -.05, 0) },
  { id = "gun_evil", ico = "🔫", name = "Портальная пушка Злого Морти", desc = "Золотая пушка Злого Морти", build = TK.buildGunEvil, act = function() TK.shootPortal("evil_morty") end, grip = TK.V3(0, -.05, 0) },
  { id = "freeze", ico = "❄", name = "Замораживатель времени", desc = "Пузырь и стоп-кадр на 4 с", build = TK.buildFreezer, act = TK.timeStop, fx = function(t) TK.pulsePart(t:FindFirstChild("Core", true), .6, TK.WHITE) TK.lightSpike(t, 6) end, grip = TK.V3(0, -.1, 0) },
  { id = "meeseeks", ico = "🟦", name = "Ящик Мисиксов", desc = "Вызывает помощника", build = TK.buildMeeseeksBox, act = TK.spawnMeeseeks, grip = TK.V3(0, -.55, -.15) },
  { id = "battery", ico = "🔋", name = "Батарея микровселенной", desc = "Зона энергии 15 с", build = TK.buildBattery, act = TK.useBattery, fx = function(t) TK.lightSpike(t, 7) end, grip = TK.V3(0, -.5, -.1) },
  { id = "ship", ico = "🚀", name = "Пульт крейсера", desc = "Вызвать, сесть, лететь", build = TK.buildRemote, act = TK.shipAction, grip = TK.V3(0, -.05, 0) },
  { id = "mee_gen", ico = "🧪", name = "Генератор Мисиксов", desc = "Помощник с эффектом появления", build = TK.ITM.buildGen, act = TK.spawnMeeseeks, fx = TK.ITM.genFx, grip = TK.V3(0, -.1, 0) },
  { id = "helmet", ico = "🪖", name = "Шлем Рика", desc = "Надеть / снять (активация)", build = TK.ITM.buildHelmetTool, act = TK.ITM.toggleHelmet, grip = TK.V3(0, -.1, 0) },
  { id = "shield", ico = "🛡", name = "Энергощит", desc = "Купол на 8 с, откат 12 с", build = TK.ITM.buildShieldTool, act = TK.ITM.toggleShield, grip = TK.V3(0, -.1, 0) },
}
TK.createdTools, TK.toolByDef = {}, {}
function TK.dropTool(tool)
  local cs = TK.createdTools[tool]
  if cs then
    for _, c in ipairs(cs) do pcall(function() c:Disconnect() end) end
    TK.createdTools[tool] = nil
  end
  for id, t in pairs(TK.toolByDef) do
    if t == tool then TK.toolByDef[id] = nil end
  end
  if TK.heldTool == tool then
    TK.heldTool, TK.heldDef, TK.ITEM_ACT, TK.batLabel = nil, nil, nil, nil
    TK.detachHand()
  end
end
function TK.ITM.purge() -- забыть предметы, которые пропали (смерть, респавн, Destroy)
  for tool in pairs(TK.createdTools) do
    local par = tool.Parent
    if not par or (par ~= TK.LP.Backpack and par ~= TK.LP.Character) then
      TK.dropTool(tool)
    end
  end
  if TK.heldTool and not TK.heldTool.Parent then TK.dropTool(TK.heldTool) end
end
function TK.giveItem(def)
  local _, hum = TK.getChar()
  if not hum or hum.Health <= 0 then TK.notify("Нет персонажа", TK.C.dg) return end
  local old = TK.toolByDef[def.id]
  if old and old.Parent then -- предмет уже есть: просто берём в руку, дубли не создаём
    hum:EquipTool(old)
    TK.notify(def.ico .. " " .. def.name .. " (уже есть)", TK.C.tx, 1.2)
    return
  end
  local ok, tool, extra = pcall(def.build)
  if not ok or not tool then TK.notify("Не удалось создать предмет", TK.C.dg) return end
  tool.Name = def.name
  local cs = {}
  TK.createdTools[tool] = cs
  TK.toolByDef[def.id] = tool
  tool.Parent = TK.LP.Backpack
  cs[#cs + 1] = tool.Activated:Connect(function()
    if TK.heldTool == tool then
      TK.safe(def.act)
      if def.fx then TK.safe(def.fx, tool) end
    end
  end)
  cs[#cs + 1] = tool.Equipped:Connect(function()
    TK.heldTool, TK.heldDef, TK.ITEM_ACT = tool, def, def.act
    if def.id == "battery" then TK.batLabel = extra else TK.batLabel = nil end
    TK.snd("equip", .25)
    task.defer(function()
      if tool.Parent == TK.LP.Character then TK.attachHand(tool, def.grip) end
    end)
  end)
  cs[#cs + 1] = tool.Unequipped:Connect(function()
    if TK.heldTool == tool then
      TK.heldTool, TK.heldDef, TK.ITEM_ACT, TK.batLabel = nil, nil, nil, nil
      TK.detachHand()
    end
  end)
  hum:EquipTool(tool)
  TK.notify(def.ico .. " " .. def.name, TK.C.ac)
end
-- кнопка 🔥 на телефоне стреляет предметом в руке
RM.fireFromAim = function()
  if TK.RIDING then TK.SH.fire() return end
  if TK.ITEM_ACT then TK.ITEM_ACT() else TK.shootPortal() end
end
function TK.clearAll()
  if RM.clearDummies then pcall(RM.clearDummies) end
  TK.detachHand()
  for tool in pairs(TK.createdTools) do
    pcall(function() tool:Destroy() end)
    TK.dropTool(tool)
  end
  TK.toolByDef = {}
  TK.heldTool, TK.heldDef, TK.ITEM_ACT, TK.batLabel = nil, nil, nil, nil
  TK.ITM.removeHelmet(true)
  TK.ITM.dropShield()
  for i = #TK.helpers, 1, -1 do
    pcall(function() TK.helpers[i].R.model:Destroy() end)
    table.remove(TK.helpers, i)
  end
  for i = #TK.zones, 1, -1 do
    pcall(function() TK.zones[i].mo:Destroy() end)
    table.remove(TK.zones, i)
  end
  if TK.RIDING or (TK.ship and TK.ship.board) then pcall(TK.dismount, true) end
  if TK.ship then pcall(function() TK.ship.model:Destroy() end) TK.ship = nil end
  pcall(function()
    TK.ridePanel.Visible = false
    TK.dismountBtn.Visible = false
  end)
  TK.killPortal(TK.PA, true)
  TK.killPortal(TK.PB, true)
  TK.PA, TK.PB = nil, nil
  for i = #TK.DYING, 1, -1 do
    pcall(function() TK.DYING[i].mo:Destroy() end)
    table.remove(TK.DYING, i)
  end
  pcall(function() TK.fxFolder:ClearAllChildren() end)
end

-- ============================================================
--  ВЫГРУЗКА
-- ============================================================
function RM.unload()
  if RM._unloaded then return end -- повторный вызов безопасен
  RM._unloaded = true
  TK.DEAD = true
  for _, c in ipairs(TK.conns) do pcall(function() c:Disconnect() end) end
  TK.conns = {}
  pcall(TK.clearAll)
  pcall(TK.clearSkin)
  pcall(function() TK.helperFolder:Destroy() end)
  pcall(function() TK.fxFolder:Destroy() end)
  pcall(function() TK.sfx:Destroy() end)
  pcall(function() TK.gui:Destroy() end)
  if TK.ccFx then pcall(function() TK.ccFx:Destroy() end) end
  if TK.ccStop then pcall(function() TK.ccStop:Destroy() end) end
  local ch, hum = TK.getChar()
  if hum then pcall(function() hum.PlatformStand = false end) end
  -- подчистить всё, что осталось с префиксом RM_
  for _, par in ipairs({ TK.Workspace, TK.Lighting, TK.SoundService }) do
    pcall(function()
      for _, o in ipairs(par:GetChildren()) do
        if type(o.Name) == "string" and o.Name:sub(1, 3) == "RM_" then pcall(function() o:Destroy() end) end
      end
    end)
  end
  if ch then
    pcall(function()
      for _, o in ipairs(ch:GetDescendants()) do
        if type(o.Name) == "string" and o.Name:sub(1, 3) == "RM_" then pcall(function() o:Destroy() end) end
      end
    end)
  end
  if G.RickMorty == RM then G.RickMorty = nil end
  warn("[RickMorty] выгружен")
end

-- передаём общее хранилище второй части
RM._TK = TK
RM._part1 = true
