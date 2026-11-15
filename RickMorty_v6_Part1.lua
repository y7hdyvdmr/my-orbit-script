-- ============================================================
--  Rick & Morty Toolkit v6.0 — ЧАСТЬ 1/5: ядро, настройки, интерфейс, 9 скинов, лицо, анимации
--  Части: 1 ядро+скины | 2 порталы+пушки+предметы+крейсер | 3 энергия+устройства
--         4 навигация+данные+измерения | 5 ИИ-компьютер+вкладки+главный цикл
--  Всё создаётся локально: видишь только ты. Без нападения на настоящих игроков.
-- ============================================================
local G = (type(getgenv) == "function" and getgenv()) or _G
for _, k in ipairs({ "RickMortyV6", "RickMorty" }) do
  if G[k] and type(G[k]) == "table" and G[k].unload then pcall(G[k].unload) end
end
local RM = { _version = "6.0" }
local TK = {} -- общее хранилище: все 5 частей работают через него
G.RickMorty = RM
G.RickMortyV6 = RM
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
TK.board, TK.dismount, TK.giveItem = nil, nil, nil -- заполняются в части 2
function TK.detachHand() end -- заглушки до части 2
function TK.attachHand() end
function TK.refreshGrip() end

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
TK.FILE = "rickmorty_v60.json"
TK.ST = {
  SoundEnabled = true, NotificationsEnabled = true, NotifDuration = 2, MenuKey = "RightShift",
  PortalColor = { R = 50, G = 255, B = 50 }, ActiveSkin = "", AimSize = 64, Emotion = "normal", DimFx = true,
  ShipSpeed = 150, GunSkin = "classic", ActiveGun = "gun_rick", DefaultEmote = "", Gfx = "Medium",
  OpenVol = 60, CloseVol = 60, PortalSize = 6, PortalLife = 60, UiScale = 100,
  EnergyMax = 100, EnergyRegen = 4, ShieldAlpha = 45, DomeRadius = 40, DomeColor = "cyan",
  JetPower = 60, ShrinkScale = 50, GravPower = 60, GravRadius = 40, EchoDelay = 15, EchoAlpha = 50,
  EchoLen = 8, DroneSpeed = 40, DroneHeight = 18, RadarRadius = 120, RobotLimit = 5, CloneLimit = 3,
  HoloAlpha = 30, HoloColor = "green", ArmLen = 12, ShieldColor = "cyan",
}
TK.RANGE = {
  AimSize = { 24, 200 }, NotifDuration = { .5, 10 }, ShipSpeed = { 50, 1000 }, OpenVol = { 0, 100 }, CloseVol = { 0, 100 },
  PortalSize = { 3, 10 }, PortalLife = { 10, 300 }, UiScale = { 60, 130 }, EnergyMax = { 50, 500 }, EnergyRegen = { 1, 30 },
  ShieldAlpha = { 10, 90 }, DomeRadius = { 20, 120 }, JetPower = { 20, 120 }, ShrinkScale = { 10, 90 }, GravPower = { 10, 150 },
  GravRadius = { 10, 120 }, EchoDelay = { 5, 60 }, EchoAlpha = { 10, 90 }, EchoLen = { 2, 20 }, DroneSpeed = { 10, 120 },
  DroneHeight = { 4, 60 }, RadarRadius = { 40, 400 }, RobotLimit = { 1, 8 }, CloneLimit = { 1, 5 }, HoloAlpha = { 0, 80 }, ArmLen = { 6, 30 },
}
TK.ENUMS = {
  Gfx = { Low = true, Medium = true, High = true }, DomeColor = { cyan = true, green = true, purple = true, gold = true, red = true },
  HoloColor = { green = true, cyan = true, purple = true, gold = true, red = true },
  ShieldColor = { cyan = true, green = true, purple = true, gold = true, red = true },
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
    local rg = TK.RANGE[k]
    if rg then return math.clamp(v, rg[1], rg[2]) end
    return v
  elseif type(v) == "table" then
    if k ~= "PortalColor" then return nil end
    local r, g, b = tonumber(v.R), tonumber(v.G), tonumber(v.B)
    if not (r and g and b) then return nil end
    return { R = math.clamp(math.floor(r), 0, 255), G = math.clamp(math.floor(g), 0, 255), B = math.clamp(math.floor(b), 0, 255) }
  elseif type(v) == "string" then
    if #v > 40 then return nil end
    if TK.ENUMS[k] and not TK.ENUMS[k][v] then return nil end
  end
  return v
end
function TK.resetSettings()
  for k, v in pairs(TK.DEFAULTS) do
    TK.ST[k] = type(v) == "table" and TK.copy(v) or v
  end
end
TK.OLD_FILE = "rickmorty_v40.json" -- файл V4/V5: совместимые настройки подхватываем один раз
if TK.HAS_FS then
  pcall(function()
    local src = isfile(TK.FILE) and TK.FILE or (isfile(TK.OLD_FILE) and TK.OLD_FILE or nil)
    if src then
      TK.MIGRATED = (src == TK.OLD_FILE)
      local d = TK.HttpService:JSONDecode(readfile(src))
      if type(d) == "table" then
        for k, v in pairs(d) do
          local ok = TK.validSetting(k, v)
          if ok ~= nil then TK.ST[k] = ok end
        end
      end
    end
  end)
end
TK.PORTAL_LIFE, TK.PORTAL_R = TK.ST.PortalLife, TK.ST.PortalSize
if not TK.HAS_FS then TK.NO_FS = true end -- настройки будут жить только до конца сессии

-- ============================================================
--  ЗВУКИ
-- ============================================================
TK.sfx = Instance.new("Folder")
TK.sfx.Name = "RM_Sfx"
TK.sfx.Parent = TK.SoundService
-- по заданию: звучат ТОЛЬКО открытие и закрытие портала (один источник, разный тон и громкость)
TK.SFX = { teleport = "rbxassetid://3314038600" }
TK.SFX_ALIAS = { open = { "teleport", 1.25, "OpenVol" }, close = { "teleport", .75, "CloseVol" } }
function TK.snd(name, vol, pitch)
  local al = TK.SFX_ALIAS[name]
  if not al or TK.DEAD or not TK.ST.SoundEnabled then return end -- все прочие звуки отключены
  local id = TK.SFX[al[1]]
  local v = (TK.ST[al[3]] or 60) / 100
  if v <= 0 then return end
  pcall(function()
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = v
    s.PlaybackSpeed = al[2]
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
TK.WW, TK.WH = math.min(400, TK.vp.X - 20), math.min(540, TK.vp.Y - 30)
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
    TK.TweenService:Create(TK.winScale, TweenInfo.new(.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = TK.ST.UiScale / 100 }):Play()
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
TK.I("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, TK.tabsBar)
TK.content = TK.I("ScrollingFrame", {
  Size = UDim2.new(1, -16, 1, -120), Position = UDim2.fromOffset(8, 90), BackgroundTransparency = 1,
  ScrollBarThickness = 3, ScrollBarImageColor3 = TK.C.ac, CanvasSize = UDim2.new(),
  AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 41,
}, TK.win)
TK.I("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, TK.content)
TK.I("TextLabel", {
  Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -22), BackgroundTransparency = 1,
  Text = "v" .. RM._version .. " | 17 разделов | 25 систем | всё локально", TextColor3 = TK.C.dim, Font = Enum.Font.Code,
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


-- ============================================================
--  17 РАЗДЕЛОВ МЕНЮ + РЕЕСТРЫ (вкладки, тики, выгрузка, системы)
-- ============================================================
TK.CATS = {
  { "home", "🏠 ГЛАВНАЯ", 84 }, { "chars", "🎭 ПЕРСОНАЖИ", 100 }, { "expr", "😀 ЛИЦА", 66 }, { "anim", "🕺 ДВИЖЕНИЯ", 96 },
  { "portals", "🌀 ПОРТАЛЫ", 88 }, { "guns", "🔫 ПУШКИ", 78 }, { "wskin", "🎨 СКИНЫ ПУШЕК", 112 }, { "items", "🧰 ПРЕДМЕТЫ", 92 },
  { "gadgets", "📟 ГАДЖЕТЫ", 92 }, { "robots", "🤖 РОБОТЫ", 82 }, { "ship", "🚀 КОРАБЛЬ", 86 }, { "energy", "🔋 ЭНЕРГИЯ", 84 },
  { "dims", "🌌 ИЗМЕРЕНИЯ", 100 }, { "newsys", "🧪 НОВЫЕ СИСТЕМЫ", 126 }, { "ai", "🧠 ИИ РИКА", 82 }, { "settings", "⚙️ НАСТРОЙКИ", 100 },
  { "diag", "🩺 ДИАГНОСТИКА", 110 },
}
TK.tabBtns, TK.tabFrames = {}, {}
function TK.switchTab(id)
  if not TK.tabFrames[id] then return end
  for k, f in pairs(TK.tabFrames) do f.Visible = (k == id) end
  for k, b in pairs(TK.tabBtns) do
    local on = (k == id)
    b.BackgroundColor3 = on and TK.C.ac or TK.C.bg2
    b.TextColor3 = on and TK.C.bg or TK.C.tx
    b.BackgroundTransparency = on and 0 or .2
  end
  TK.content.CanvasPosition = Vector2.zero
  TK.curTab = id
  if TK.tabOpen[id] then TK.safe(TK.tabOpen[id]) end
end
TK.tabOpen, TK.tabBuilt = {}, {}
-- регистрирует вкладку: builder(frame) наполняет её кнопками; onOpen вызывается при каждом открытии
function TK.regTab(id, builder, onOpen)
  local idx, meta
  for i, t in ipairs(TK.CATS) do
    if t[1] == id then idx, meta = i, t end
  end
  if not meta then warn("[RickMorty] неизвестная вкладка " .. tostring(id)) return end
  local b = TK.I("TextButton", {
    Size = UDim2.fromOffset(meta[3], 32), BackgroundColor3 = TK.C.bg2, BackgroundTransparency = .2, TextColor3 = TK.C.tx,
    Font = Enum.Font.GothamBold, TextSize = 10, Text = meta[2], ZIndex = 42, LayoutOrder = idx,
  }, TK.tabsBar)
  TK.cr(b, 8)
  TK.tabBtns[id] = b
  b.MouseButton1Click:Connect(function() TK.snd("click", .3) TK.switchTab(id) end)
  local f = TK.I("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
    Visible = false, ZIndex = 41, LayoutOrder = idx,
  }, TK.content)
  TK.I("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
  TK.tabFrames[id] = f
  local ok, err = pcall(builder, f)
  if not ok then
    warn("[RickMorty] вкладка " .. id .. ": " .. tostring(err))
    TK.newInfo(f, "⚠ Вкладка не собралась: " .. tostring(err):sub(1, 120), 60)
  else
    TK.tabBuilt[id] = true
  end
  TK.tabOpen[id] = onOpen
  return f
end
-- добавить секцию во вкладку (вкладка создаётся при первом обращении)
function TK.sect(id, fn)
  if not TK.tabFrames[id] then
    TK.regTab(id, function() end)
  end
  local f = TK.tabFrames[id]
  if not f then return end
  local ok, err = pcall(fn, f)
  if not ok then
    warn("[RickMorty] секция " .. id .. ": " .. tostring(err))
    TK.newInfo(f, "⚠ Секция не собралась: " .. tostring(err):sub(1, 100), 40)
  end
end
-- периодические задачи главного цикла (часть 5): TK.tick("имя", раз_в_секунду, fn(dt))
TK.ticks = {}
function TK.tick(name, hz, fn)
  TK.ticks[#TK.ticks + 1] = { name = name, step = 1 / hz, acc = 0, fn = fn, fails = 0 }
end
-- что сделать при выгрузке
TK.unloaders = {}
function TK.onUnload(fn) TK.unloaders[#TK.unloaders + 1] = fn end
-- реестр 25 систем: def = { n, name, tab, mode, note, keys, get()->bool, set(bool), avail()->ok,reason }
-- mode: "visual" (только визуал), "test" (только своя тестовая среда), "server" (нужна поддержка игры)
TK.SYSL, TK.SYSD = {}, {}
function TK.regSys(def)
  TK.SYSD[def.n] = def
  TK.SYSL[#TK.SYSL + 1] = def
end
TK.input = {} -- клавиши/кнопки: TK.input[name] = fn
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
  beth = {
    name = "Бет Смит", ico = "🐴", desc = "Светлые волосы, фиолетовый топ, добрые глаза",
    skin = TK.RGB(240, 205, 180), hair = TK.RGB(232, 205, 120), shirt = TK.RGB(150, 120, 200), up = TK.RGB(150, 120, 200),
    fo = TK.RGB(240, 205, 180), pants = TK.RGB(55, 70, 110), shoe = TK.RGB(70, 60, 80), hs = TK.V3(1.5, 1.6, 1.35),
    ey = .08, ex = .32, er = .54, pr = .11, nl = .22, ny = -.18, hstyle = "morty", longhair = true, brow = .05,
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
TK.SKIN_ORDER = { "rick", "morty", "evil_morty", "rick_prime", "jerry", "summer", "meeseeks", "pickle", "beth" }

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
  beth = { col = TK.RGB(200, 170, 255), rate = 3, spd = 1.5 },
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
  if TK.ST.DefaultEmote ~= "" then TK.EMOTE = TK.ST.DefaultEmote end
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
--  ОБЩИЕ ПОМОЩНИКИ ДЛЯ ВСЕХ СИСТЕМ (используют части 2–5)
-- ============================================================
TK.sysFolder = TK.I("Folder", { Name = "RM_Sys" }, TK.Workspace) -- модели новых систем (всё чистится при выгрузке)
TK.onUnload(function() pcall(function() TK.sysFolder:Destroy() end) end)
TK.GFX = { Low = 1, Medium = 2, High = 3 }
function TK.gfx() return TK.GFX[TK.ST.Gfx] or 2 end
function TK.fxRate(n) return math.max(1, math.floor(n * ({ .35, 1, 1.8 })[TK.gfx()])) end -- число частиц по режиму графики
TK.COL = {
  cyan = TK.RGB(90, 220, 255), green = TK.RGB(80, 255, 130), purple = TK.RGB(170, 100, 255),
  gold = TK.RGB(255, 210, 70), red = TK.RGB(255, 80, 90),
}
function TK.colOf(name) return TK.COL[name] or TK.COL.cyan end
TK.COLNAMES = { cyan = "бирюзовый", green = "зелёный", purple = "фиолетовый", gold = "золотой", red = "красный" }
TK.COLLIST = { "cyan", "green", "purple", "gold", "red" }

-- общая энергосистема Toolkit (система 10; настройки и интерфейс в части 3)
TK.EN = { cur = 100, over = 0, warned = 0 }
function TK.enOverloaded() return os.clock() < TK.EN.over end
function TK.enAdd(v) TK.EN.cur = math.clamp(TK.EN.cur + v, 0, TK.ST.EnergyMax) end
function TK.enUse(cost, what) -- разовый расход; возвращает true/false
  if TK.enOverloaded() then TK.notify("⚡ Перегрузка, подожди " .. math.ceil(TK.EN.over - os.clock()) .. " с", TK.C.dg, 1.2) return false end
  if TK.EN.cur < cost then TK.notify("⚡ Мало энергии" .. (what and (" для: " .. what) or ""), TK.C.dg, 1.2) return false end
  TK.EN.cur = TK.EN.cur - cost
  if TK.EN.cur <= 0 then TK.EN.over = os.clock() + 6 end
  return true
end
function TK.enDrain(rate, dt) -- непрерывный расход; false = энергии нет, устройство надо выключить
  if TK.enOverloaded() then return false end
  TK.EN.cur = TK.EN.cur - rate * dt
  if TK.EN.cur <= 0 then
    TK.EN.cur = 0
    TK.EN.over = os.clock() + 6
    TK.notify("⚡ Энергия кончилась: перегрузка 6 с", TK.C.dg, 2)
    return false
  end
  return true
end

-- обновление подписей и состояний кнопок
TK.refreshers = {}
function TK.addRefresh(fn) TK.refreshers[#TK.refreshers + 1] = fn end
function TK.runRefresh()
  for _, fn in ipairs(TK.refreshers) do pcall(fn) end
end

-- элементы интерфейса
function TK.newToggle(parent, label, get, set, h)
  local b
  local function paint()
    local on = get() and true or false
    b.Text = label .. ": " .. (on and "ВКЛ" or "ВЫКЛ")
    b.BackgroundColor3 = on and TK.C.st or TK.C.bg2
  end
  b = TK.newBtn(parent, label, TK.C.bg2, function() set(not get()) paint() end, h or 34)
  paint()
  TK.addRefresh(paint)
  return b
end
function TK.newNum(parent, label, key, step, onChange, suffix) -- число из TK.ST[key] с кнопками − и +
  local rg = TK.RANGE[key] or { 0, 100 }
  local row = TK.I("Frame", { Size = UDim2.new(1, -8, 0, 36), BackgroundColor3 = TK.C.bg2, BackgroundTransparency = .1, ZIndex = 42 }, parent)
  TK.cr(row, 8)
  local lbl = TK.I("TextLabel", {
    Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "",
    TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
  }, row)
  local function paint() lbl.Text = label .. ": " .. tostring(TK.ST[key]) .. (suffix or "") end
  local function add(d)
    local v = TK.validSetting(key, math.floor((TK.ST[key] + d) * 100 + .5) / 100)
    if v ~= nil then TK.ST[key] = v end
    paint()
    TK.save()
    if onChange then TK.safe(onChange, TK.ST[key]) end
  end
  for i, d in ipairs({ -step, step }) do
    local b = TK.I("TextButton", {
      Size = UDim2.fromOffset(34, 28), Position = i == 1 and UDim2.new(1, -78, 0, 4) or UDim2.new(1, -40, 0, 4),
      BackgroundColor3 = TK.C.bg, TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 18,
      Text = i == 1 and "−" or "+", ZIndex = 43,
    }, row)
    TK.cr(b, 8)
    b.MouseButton1Click:Connect(function() add(d) end)
  end
  paint()
  TK.addRefresh(paint)
  return row
end
function TK.newCycle(parent, label, key, list, names, onChange) -- выбор из списка строк (ST[key] = элемент списка)
  local b
  local function paint() b.Text = label .. ": " .. ((names and names[TK.ST[key]]) or tostring(TK.ST[key])) end
  b = TK.newBtn(parent, label, TK.C.bg2, function()
    local ix = 1
    for i, v in ipairs(list) do if v == TK.ST[key] then ix = i end end
    TK.ST[key] = list[ix % #list + 1]
    paint()
    TK.save()
    if onChange then onChange(TK.ST[key]) end
  end, 34)
  paint()
  TK.addRefresh(paint)
  return b
end
function TK.newStatus(parent, getText, h) -- подпись, которая сама обновляется
  local l = TK.newInfo(parent, "", h or 40)
  local function paint() l.Text = getText() end
  paint()
  TK.addRefresh(paint)
  return l
end
function TK.newCard(parent, title, sub, fn) -- карточка-кнопка с заголовком и описанием
  local b = TK.newBtn(parent, "", TK.C.bg2, fn, 40)
  TK.I("TextLabel", {
    Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1, Text = title,
    TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
  }, b)
  TK.I("TextLabel", {
    Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 22), BackgroundTransparency = 1, Text = sub or "",
    TextColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 43,
  }, b)
  return b
end

-- предпросмотр (ViewportFrame с медленным вращением)
TK.previews = {}
function TK.toolToModel(tool) -- Tool из V5 -> статичная модель для просмотра
  local m = Instance.new("Model")
  for _, d in ipairs(tool:GetDescendants()) do
    if d:IsA("BasePart") and not (d.Name == "Handle" and d.Transparency >= 1) then
      local c = d:Clone()
      for _, x in ipairs(c:GetChildren()) do
        if x:IsA("Weld") or x:IsA("SurfaceGui") then x:Destroy() end
      end
      c.Anchored = true
      c.Parent = m
    end
  end
  pcall(function() tool:Destroy() end)
  return m
end
function TK.newPreview(parent, h)
  local vp = TK.I("ViewportFrame", {
    Size = UDim2.new(1, -8, 0, h or 150), BackgroundColor3 = TK.C.bg2, BackgroundTransparency = .1,
    Ambient = TK.RGB(170, 170, 190), LightColor = TK.RGB(255, 255, 255), LightDirection = TK.V3(-1, -1, -1), ZIndex = 42,
  }, parent)
  TK.cr(vp, 8)
  local cam = TK.I("Camera", { FieldOfView = 40 }, vp)
  vp.CurrentCamera = cam
  local pv = { vp = vp, cam = cam, ang = 0, model = nil }
  function pv.set(model, note)
    if pv.model then pcall(function() pv.model:Destroy() end) end
    pv.model = nil
    if pv.lbl then pv.lbl:Destroy() pv.lbl = nil end
    if not model then return end
    pv.model = model
    model.Parent = vp
    local ok = pcall(function()
      local _, size = model:GetBoundingBox()
      model:PivotTo(CFrame.new())
      local d = math.max(size.X, size.Y, size.Z) * 1.75 + 1
      cam.CFrame = CFrame.lookAt(TK.V3(0, size.Y * .12, d), TK.V3())
    end)
    if not ok then pv.model = nil end
    if note then
      pv.lbl = TK.I("TextLabel", {
        Size = UDim2.new(1, -10, 0, 14), Position = UDim2.new(0, 5, 1, -16), BackgroundTransparency = 1, Text = note,
        TextColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 9, ZIndex = 44,
      }, vp)
    end
  end
  TK.previews[#TK.previews + 1] = pv
  return pv
end
TK.tick("preview", 20, function(dt)
  for _, pv in ipairs(TK.previews) do
    if pv.model and pv.model.Parent and pv.vp.Visible and pv.vp.AbsoluteSize.X > 0 then
      pv.ang = pv.ang + dt * .9
      pcall(function() pv.model:PivotTo(CFrame.Angles(0, pv.ang, 0)) end)
    end
  end
end)
function TK.skinModel(S) -- статичная модель скина для просмотра
  local root = TK.mkp("Root", TK.V3(2, 2, 1), TK.WHITE)
  root.Transparency = 1
  root.Anchored = true
  root.CFrame = CFrame.new(0, 0, 0)
  local R = TK.newRig(root, S, 1)
  local m = R.model
  for _, d in ipairs(m:GetDescendants()) do
    if d:IsA("BasePart") then d.Anchored = true end
  end
  root:Destroy()
  return m
end

-- ============================================================
--  ВКЛАДКИ ЧАСТИ 1: персонажи, лица, движения
-- ============================================================
TK.regTab("chars", function(f)
  TK.newSec(f, "ПЕРСОНАЖИ (9 скинов на Motor6D)")
  local pv = TK.newPreview(f, 170)
  local cur = TK.ST.ActiveSkin ~= "" and TK.ST.ActiveSkin or "rick"
  local btns = {}
  local function show(id)
    cur = id
    local ok, m = pcall(TK.skinModel, TK.SK[id])
    if ok and m then pv.set(m, TK.SK[id].name .. " — " .. TK.SK[id].desc) else pv.set(nil) end
    for k, b in pairs(btns) do b.BackgroundColor3 = (k == id) and TK.C.ac3 or ((TK.ST.ActiveSkin == k) and TK.C.st or TK.C.bg2) end
  end
  local gr = TK.newGrid(f, 2)
  for _, id in ipairs(TK.SKIN_ORDER) do
    local S = TK.SK[id]
    btns[id] = TK.newBtn(gr, S.ico .. " " .. S.name, TK.C.bg2, function() show(id) end, 34)
    btns[id].TextSize = 11
  end
  TK.newBtn(f, "✅ Надеть выбранного", TK.C.ac, function() TK.applySkin(cur) show(cur) end, 38)
  TK.newBtn(f, "↩ Вернуть своё тело", TK.C.bg2, function() TK.removeSkin() show(cur) end, 34).TextColor3 = TK.C.dg
  TK.newInfo(f, "\n  Все модели собраны из деталей (процедурно): FBX/OBJ из архива\n  нельзя загрузить в Delta, они служили только эталоном.\n  Бет Смит — собственная интерpретация по фото.", 70)
  TK.addRefresh(function()
    for k, b in pairs(btns) do b.BackgroundColor3 = (k == cur) and TK.C.ac3 or ((TK.ST.ActiveSkin == k) and TK.C.st or TK.C.bg2) end
  end)
  TK.tabOpenChars = function() show(cur) end
end, function() if TK.tabOpenChars then TK.tabOpenChars() end end)
TK.regTab("expr", function(f)
  TK.newSec(f, "ВЫРАЖЕНИЕ ЛИЦА (12) — нужен надетый скин")
  local btns = {}
  local gr = TK.newGrid(f, 3)
  for _, e in ipairs(TK.EM) do
    btns[e[1]] = TK.newBtn(gr, e[2], TK.C.bg2, function() TK.setEmo(e[1]) end, 34)
    btns[e[1]].TextSize = 10
  end
  TK.addRefresh(function()
    for id, b in pairs(btns) do b.BackgroundColor3 = (TK.ST.Emotion == id) and TK.C.st or TK.C.bg2 end
  end)
  TK.newInfo(f, "\n  Выбранное лицо сохраняется и применяется к любому скину.\n  Глаза, брови и рот плавно переходят, моргание работает всегда.", 62)
end)
TK.regTab("anim", function(f)
  TK.newSec(f, "ДВИЖЕНИЯ ТЕЛА (стой на месте)")
  local EMS = {
    { "wave", "👋 Махать" }, { "dance", "🕺 Танец" }, { "drunk", "🥴 Пьяная походка" },
    { "think", "🤔 Думать" }, { "victory", "🙌 Победа" }, { "facepalm", "🤦 Фейспалм" },
  }
  local gr = TK.newGrid(f, 2)
  for _, e in ipairs(EMS) do
    TK.newBtn(gr, e[2], TK.C.bg2, function()
      if not TK.RIG then TK.notify("Сначала надень скин", TK.C.dg, 2) return end
      TK.EMOTE = e[1]
    end, 34)
  end
  TK.newBtn(f, "⏹ Остановить движение", TK.C.bg2, function() TK.EMOTE = nil end, 32)
  TK.newSec(f, "ДВИЖЕНИЕ ПО УМОЛЧАНИЮ ПОСЛЕ НАДЕВАНИЯ СКИНА")
  local list = { "", "wave", "dance", "drunk", "think", "victory", "facepalm" }
  local names = { [""] = "нет", wave = "махать", dance = "танец", drunk = "пьяная", think = "думать", victory = "победа", facepalm = "фейспалм" }
  TK.newCycle(f, "▶ По умолчанию", "DefaultEmote", list, names)
  TK.newSec(f, "РЕПЛИКИ (пузырь над головой)")
  local pg = TK.newGrid(f, 2)
  for _, p in ipairs({ "Wubba lubba dub dub!", "И вот так, Морти!", "Aw jeez, Рик!", "Я Мистер Мисикс!", "Быстрее, в портал!", "Это не сон, это физика." }) do
    TK.newBtn(pg, p, TK.C.bg2, function() TK.say(p) end, 38).TextSize = 10
  end
  TK.newInfo(f, "\n  Ходьба, бег, прыжок, посадка в корабль, хват предмета\n  и моргание работают всегда. Движение сбрасывается, когда идёшь.", 62)
end)

-- ============================================================
--  ВЫГРУЗКА (общая для всех частей)
-- ============================================================
function RM.unload()
  if RM._unloaded then return end
  RM._unloaded = true
  TK.DEAD = true
  for i = #TK.unloaders, 1, -1 do pcall(TK.unloaders[i]) end
  for _, c in ipairs(TK.conns) do pcall(function() c:Disconnect() end) end
  TK.conns = {}
  if TK.clearAll then pcall(TK.clearAll) end
  pcall(TK.clearSkin)
  pcall(function() TK.fxFolder:Destroy() end)
  pcall(function() TK.sfx:Destroy() end)
  pcall(function() TK.gui:Destroy() end)
  local ch, hum = TK.getChar()
  if hum then pcall(function() hum.PlatformStand = false end) end
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
  if G.RickMortyV6 == RM then G.RickMortyV6 = nil end
  warn("[RickMorty] выгружен")
end

RM._TK = TK
RM._part1 = true
