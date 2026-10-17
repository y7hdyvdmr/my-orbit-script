-- Rick & Morty Multiverse Toolkit v1.0 | standalone (не связан с ORBIT)
-- Оружие, гаджеты и скины по мотивам мультсериала «Рик и Морти».
-- БЕЗ 18+ контента: без крови, расчленёнки, взрослого юмора.
-- Все эффекты — клиентские, без серверного урона.
--
-- Использование:
--   loadstring(game:HttpGet("URL_на_этот_файл"))()
--
-- Правила (по духу проекта ORBIT):
--   * loadstring/HttpGet — только в loader'е, в этом файле их нет.
--   * Instance.new не подменяется.
--   * DisplayOrder ≤ 65.
--   * getSafeParent() с fallback на PlayerGui.
--   * В destroy — страховка FindFirstChild.
--   * Все коннекты собираются в таблицу conns и отписываются в unload.
--   * Комментарии русские, идентификаторы латиницей.

local GENV = rawget(_G, "getgenv") and getgenv() or _G
local RM = {}
GENV.RickMorty = RM
RM._version = "1.0"
RM._started = os.clock()

-- Защита от повторного запуска
if GENV._RM_BUSY and os.clock() - (GENV._RM_BUSY_T or 0) < 30 then
    warn("[RickMorty] повторный запуск проигнорирован (прошло " ..
        string.format("%.1f", os.clock() - (GENV._RM_BUSY_T or 0)) .. " сек)")
    return
end
GENV._RM_BUSY = true
GENV._RM_BUSY_T = os.clock()

-- ============================================================
--  СЕРВИСЫ
-- ============================================================
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local Workspace    = game:GetService("Workspace")
local Lighting     = game:GetService("Lighting")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

RM.Players = Players
RM.RunService = RunService
RM.TweenService = TweenService
RM.UIS = UIS
RM.Workspace = Workspace
RM.LocalPlayer = LocalPlayer
RM.HAS_FS = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
RM.SAVE_FILE = "rickmorty_settings.json"

-- ============================================================
--  getSafeParent / protectGui
-- ============================================================
local function getSafeParent()
    local gethuiFn = rawget(GENV, "gethui")
    if type(gethuiFn) == "function" then
        local ok, hui = pcall(gethuiFn)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return PlayerGui
end
RM.getSafeParent = getSafeParent

local function protectGui(gui)
    if not gui then return end
    local synTbl = rawget(GENV, "syn")
    if type(synTbl) == "table" and type(synTbl.protect_gui) == "function" then
        pcall(synTbl.protect_gui, gui); return
    end
    local protectFn = rawget(GENV, "protect_gui")
    if type(protectFn) == "function" then pcall(protectFn, gui); return end
end
RM.protectGui = protectGui

-- ============================================================
--  КОННЕКТЫ / CLEANUP
-- ============================================================
local conns = {}
local function track(c) conns[#conns + 1] = c; return c end
RM._conns = conns

local alive = true

-- ============================================================
--  НАСТРОЙКИ (с сохранением)
-- ============================================================
RM.SETTINGS = {
    SoundEnabled = true,
    NotificationsEnabled = true,
    NotifDuration = 2,
    MenuKey = "RightShift",
    -- оружие
    LaserColor = { R = 0, G = 255, B = 100 },
    -- гаджеты
    SpeedBoost = 60,
    JumpBoost = 80,
    InvisDuration = 8,
    -- скины
    ActiveSkin = nil,
}

local function saveSettings()
    if not RM.HAS_FS then return end
    pcall(function()
        local data = {}
        for k, v in pairs(RM.SETTINGS) do
            if type(v) ~= "table" or v.R == nil then data[k] = v
            else data[k] = { R = v.R, G = v.G, B = v.B } end
        end
        writefile(RM.SAVE_FILE, HttpService:JSONEncode(data))
    end)
end
local function loadSettings()
    if not RM.HAS_FS then return end
    pcall(function()
        if isfile(RM.SAVE_FILE) then
            local txt = readfile(RM.SAVE_FILE)
            if txt and #txt > 2 then
                local d = HttpService:JSONDecode(txt)
                if type(d) == "table" then
                    for k, v in pairs(d) do
                        if RM.SETTINGS[k] ~= nil then RM.SETTINGS[k] = v end
                    end
                end
            end
        end
    end)
end
loadSettings()
RM.saveSettings = saveSettings

-- ============================================================
--  ЗВУКИ
-- ============================================================
local sfxFolder = Instance.new("Folder")
sfxFolder.Name = "RM_Sfx_" .. tostring(math.random(100000, 999999))
sfxFolder.Parent = game:GetService("SoundService")
RM.sfxFolder = sfxFolder

local SFX_IDS = {
    portal   = "rbxassetid://3314038600",   -- телепорт
    laser    = "rbxassetid://12221967",     -- лазер
    click    = "rbxasset://sounds/button.wav",
    notify   = "rbxasset://sounds/electronicpingshort.wav",
    open     = "rbxasset://sounds/switch.wav",
    close    = "rbxasset://sounds/switch.wav",
}

local function playSound(idName, vol, pitch)
    if not RM.SETTINGS.SoundEnabled then return end
    local id = SFX_IDS[idName]
    if not id then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.Name = "RM_" .. idName
        s.SoundId = id
        s.Volume = vol or 0.5
        s.PlaybackSpeed = pitch or 1
        s.Parent = sfxFolder
        s:Play()
        task.delay(4, function() pcall(function() s:Destroy() end) end)
    end)
end
RM.playSound = playSound

-- ============================================================
--  УВЕДОМЛЕНИЯ
-- ============================================================
local notifQueue = {}
local function notify(text, color, duration)
    if not RM.SETTINGS.NotificationsEnabled then return end
    table.insert(notifQueue, {
        text = tostring(text),
        color = color or Color3.fromRGB(120, 255, 160),
        duration = duration or RM.SETTINGS.NotifDuration,
    })
    while #notifQueue > 30 do table.remove(notifQueue, 1) end
    playSound("notify", 0.4, 1)
end
RM.notify = notify

-- ============================================================
--  ЦВЕТА СТИЛЯ
-- ============================================================
local C = {
    bg          = Color3.fromRGB(18, 14, 28),
    bg2         = Color3.fromRGB(28, 22, 42),
    accent      = Color3.fromRGB(100, 255, 140),   -- портальный зелёный
    accent2     = Color3.fromRGB(150, 90, 255),    -- фиолетовый
    accent3     = Color3.fromRGB(120, 220, 255),   -- циан
    text        = Color3.fromRGB(240, 235, 255),
    textDim     = Color3.fromRGB(150, 140, 180),
    danger      = Color3.fromRGB(255, 100, 120),
    success     = Color3.fromRGB(120, 255, 160),
    stroke      = Color3.fromRGB(120, 90, 220),
}

-- ============================================================
--  КОРНЕВОЙ GUI
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "_RickMorty_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 65
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(gui)
do
    local okp = pcall(function() gui.Parent = getSafeParent() end)
    if not okp or not gui.Parent then gui.Parent = PlayerGui end
end
RM.gui = gui

-- ============================================================
--  КНОПКА ОТКРЫТИЯ (перетаскиваемая)
-- ============================================================
local mainBtn = Instance.new("TextButton")
mainBtn.Name = "RM_MainButton"
mainBtn.Size = UDim2.fromOffset(60, 60)
mainBtn.Position = UDim2.fromOffset(20, 120)
mainBtn.BackgroundColor3 = C.bg
mainBtn.BackgroundTransparency = 0.05
mainBtn.TextColor3 = C.accent
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 30
mainBtn.Text = "🌀"
mainBtn.AutoButtonColor = false
mainBtn.ZIndex = 50
mainBtn.Parent = gui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 16)
do
    local st = Instance.new("UIStroke", mainBtn)
    st.Color = C.accent
    st.Thickness = 2
    st.Transparency = 0.2
    local gr = Instance.new("UIGradient", st)
    gr.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(0.5, C.accent3),
        ColorSequenceKeypoint.new(1, C.accent2),
    })
    gr.Rotation = 45
end

-- ============================================================
--  ГЛАВНОЕ ОКНО
-- ============================================================
local WINDOW_W = 380
local WINDOW_H = 500

local window = Instance.new("Frame")
window.Name = "RM_Window"
window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
window.Position = UDim2.fromOffset(90, 80)
window.BackgroundColor3 = C.bg
window.BackgroundTransparency = 0.02
window.BorderSizePixel = 0
window.Visible = false
window.ZIndex = 40
window.Parent = gui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 16)
do
    local gr = Instance.new("UIGradient", window)
    gr.Color = ColorSequence.new(C.bg2, C.bg)
    gr.Rotation = 90
    local st = Instance.new("UIStroke", window)
    st.Color = C.stroke; st.Thickness = 1.5; st.Transparency = 0.25
end

-- Шапка
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundTransparency = 1
header.ZIndex = 41
header.Parent = window

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "🌀 RICK & MORTY TOOLKIT"
title.TextColor3 = C.accent
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 42
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(30, 30)
closeBtn.Position = UDim2.new(1, -38, 0, 7)
closeBtn.BackgroundColor3 = C.danger
closeBtn.BackgroundTransparency = 0.5
closeBtn.TextColor3 = C.text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Text = "✕"
closeBtn.ZIndex = 42
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- Вкладки
local tabsBar = Instance.new("Frame")
tabsBar.Name = "Tabs"
tabsBar.Size = UDim2.new(1, -16, 0, 38)
tabsBar.Position = UDim2.fromOffset(8, 48)
tabsBar.BackgroundTransparency = 1
tabsBar.ZIndex = 41
tabsBar.Parent = window

local tabList = Instance.new("UIListLayout", tabsBar)
tabList.FillDirection = Enum.FillDirection.Horizontal
tabList.Padding = UDim.new(0, 4)
tabList.VerticalAlignment = Enum.VerticalAlignment.Center
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Left

-- Контент (вкладки)
local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Size = UDim2.new(1, -16, 1, -140)
content.Position = UDim2.fromOffset(8, 90)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = C.accent
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ZIndex = 41
content.Parent = window

local contentList = Instance.new("UIListLayout", content)
contentList.FillDirection = Enum.FillDirection.Vertical
contentList.Padding = UDim.new(0, 6)
contentList.SortOrder = Enum.SortOrder.LayoutOrder

-- Подвал
local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -20, 0, 16)
footer.Position = UDim2.new(0, 10, 1, -22)
footer.BackgroundTransparency = 1
footer.Text = "  v" .. RM._version .. "  |  портальный портал открыт  |  без 18+"
footer.TextColor3 = C.textDim
footer.Font = Enum.Font.Code
footer.TextSize = 9
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.ZIndex = 42
footer.Parent = window

-- ============================================================
--  ХЕЛПЕРЫ UI
-- ============================================================
local function newButton(parent, text, color, onClick, height)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -8, 0, height or 36)
    b.BackgroundColor3 = color or C.bg2
    b.BackgroundTransparency = 0.1
    b.TextColor3 = C.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.BorderSizePixel = 0
    b.ZIndex = 42
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    do
        local st = Instance.new("UIStroke", b)
        st.Color = C.stroke; st.Thickness = 1; st.Transparency = 0.7
    end
    if onClick then
        b.MouseButton1Click:Connect(function()
            playSound("click", 0.3)
            pcall(onClick)
        end)
    end
    return b
end
RM.newButton = newButton

local function newSection(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -8, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "▸ " .. text
    lbl.TextColor3 = C.accent3
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 42
    lbl.Parent = parent
    return lbl
end
RM.newSection = newSection

-- ============================================================
--  ВКЛАДКИ (5)
-- ============================================================
local TABS = {
    { id = "portal",  label = "🌀 ПОРТАЛ",  color = C.accent },
    { id = "weapons", label = "🔫 ОРУЖИЕ", color = C.accent2 },
    { id = "gadgets", label = "🧪 ГАДЖЕТЫ", color = C.accent3 },
    { id = "skins",   label = "🎭 СКИНЫ",  color = C.accent },
    { id = "settings",label = "⚙️",         color = C.textDim },
}
local tabButtons = {}
local activeTab = "portal"
local tabFrames = {}

local function switchTab(id)
    activeTab = id
    for tabId, frame in pairs(tabFrames) do
        frame.Visible = (tabId == id)
    end
    for tabId, btn in pairs(tabButtons) do
        if tabId == id then
            btn.BackgroundColor3 = C.accent
            btn.TextColor3 = C.bg
            btn.BackgroundTransparency = 0
        else
            btn.BackgroundColor3 = C.bg2
            btn.TextColor3 = C.text
            btn.BackgroundTransparency = 0.2
        end
    end
    content.CanvasPosition = Vector2.new(0, 0)
end
RM.switchTab = switchTab

for _, t in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(t.id == "settings" and 40 or 68, 32)
    btn.BackgroundColor3 = C.bg2
    btn.BackgroundTransparency = 0.2
    btn.TextColor3 = C.text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Text = t.label
    btn.AutoButtonColor = true
    btn.ZIndex = 42
    btn.Parent = tabsBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    tabButtons[t.id] = btn
    btn.MouseButton1Click:Connect(function()
        playSound("click", 0.3)
        switchTab(t.id)
    end)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.Visible = (t.id == "portal")
    frame.ZIndex = 41
    frame.Parent = content
    tabFrames[t.id] = frame
    local fl = Instance.new("UIListLayout", frame)
    fl.Padding = UDim.new(0, 6)
    fl.SortOrder = Enum.SortOrder.LayoutOrder
end

-- ============================================================
--  ОТКРЫТИЕ / ЗАКРЫТИЕ
-- ============================================================
local function openMenu()
    if window.Visible then return end
    window.Visible = true
    playSound("open", 0.4)
    window.Size = UDim2.fromOffset(WINDOW_W * 0.9, WINDOW_H * 0.9)
    TweenService:Create(window, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(WINDOW_W, WINDOW_H) }):Play()
end
local function closeMenu()
    if not window.Visible then return end
    playSound("close", 0.4)
    TweenService:Create(window, TweenInfo.new(0.15),
        { Size = UDim2.fromOffset(WINDOW_W * 0.9, WINDOW_H * 0.9) }):Play()
    task.delay(0.16, function()
        if not window.Visible then return end
        window.Visible = false
    end)
end
RM.openMenu = openMenu
RM.closeMenu = closeMenu

closeBtn.MouseButton1Click:Connect(closeMenu)

-- клик по главной кнопке (с защитой от перетаскивания)
local dragging, dragStart, startPos, dragged = false, nil, nil, false

mainBtn.MouseButton1Down:Connect(function()
    dragging = true
    dragged = false
    dragStart = UIS:GetMouseLocation()
    startPos = mainBtn.Position
end)
mainBtn.MouseButton1Click:Connect(function()
    if dragged then return end
    if window.Visible then closeMenu() else openMenu() end
end)
track(UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
       and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local cur = UIS:GetMouseLocation()
    local delta = cur - dragStart
    if delta.Magnitude > 4 then dragged = true end
    if not dragged then return end
    local abs = gui.AbsoluteSize
    mainBtn.Position = UDim2.fromOffset(
        math.clamp(startPos.X.Offset + delta.X, 0, math.max(0, abs.X - 60)),
        math.clamp(startPos.Y.Offset + delta.Y, 0, math.max(0, abs.Y - 60))
    )
end))
track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

-- Горячая клавиша
track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local key = input.KeyCode
    local want = RM.SETTINGS.MenuKey
    if type(want) == "string" and tostring(key):find(want) then
        if window.Visible then closeMenu() else openMenu() end
    end
end))

-- ============================================================
--  СИСТЕМА УВЕДОМЛЕНИЙ (UI)
-- ============================================================
local notifHolder = Instance.new("Frame")
notifHolder.Name = "RM_Notifs"
notifHolder.Size = UDim2.fromOffset(260, 300)
notifHolder.Position = UDim2.new(1, -280, 1, -320)
notifHolder.BackgroundTransparency = 1
notifHolder.ZIndex = 60
notifHolder.Parent = gui
local nl = Instance.new("UIListLayout", notifHolder)
nl.VerticalAlignment = Enum.VerticalAlignment.Bottom
nl.HorizontalAlignment = Enum.HorizontalAlignment.Right
nl.Padding = UDim.new(0, 4)

task.spawn(function()
    while alive do
        task.wait(0.1)
        while #notifQueue > 0 do
            local n = table.remove(notifQueue, 1)
            local f = Instance.new("Frame")
            f.Size = UDim2.fromOffset(250, 32)
            f.BackgroundColor3 = C.bg
            f.BackgroundTransparency = 0.1
            f.BorderSizePixel = 0
            f.ZIndex = 61
            f.Parent = notifHolder
            Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
            local st = Instance.new("UIStroke", f)
            st.Color = n.color; st.Thickness = 1.5; st.Transparency = 0.2
            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(0, 3, 1, -8)
            bar.Position = UDim2.fromOffset(4, 4)
            bar.BackgroundColor3 = n.color
            bar.BorderSizePixel = 0
            bar.ZIndex = 62
            bar.Parent = f
            Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -16, 1, 0)
            lbl.Position = UDim2.fromOffset(12, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = n.text
            lbl.TextColor3 = C.text
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.ZIndex = 62
            lbl.Parent = f
            task.delay(n.duration, function()
                if f and f.Parent then
                    TweenService:Create(f, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                    for _, ch in ipairs(f:GetDescendants()) do
                        if ch:IsA("TextLabel") then
                            TweenService:Create(ch, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
                        elseif ch:IsA("Frame") and ch ~= f then
                            TweenService:Create(ch, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
                        elseif ch:IsA("UIStroke") then
                            TweenService:Create(ch, TweenInfo.new(0.2), { Transparency = 1 }):Play()
                        end
                    end
                    task.delay(0.25, function() pcall(function() f:Destroy() end) end)
                end
            end)
        end
    end
end)

-- ============================================================
--  UNLOAD
-- ============================================================
RM._cleanup = {}

function RM.unload()
    alive = false
    GENV._RM_BUSY = nil
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    conns = {}
    for _, fn in ipairs(RM._cleanup) do pcall(fn) end
    RM._cleanup = {}
    if sfxFolder then pcall(function() sfxFolder:Destroy() end) end
    if gui then
        local gname = gui.Name
        local p = gui.Parent
        if p and p:FindFirstChild(gname) then
            p:FindFirstChild(gname):Destroy()
        end
        if PlayerGui and PlayerGui:FindFirstChild(gname) then
            PlayerGui:FindFirstChild(gname):Destroy()
        end
    end
    GENV.RickMorty = nil
    warn("[RickMorty] Скрипт выгружен")
end
RM._cleanup[#RM._cleanup + 1] = function() end

notify("🌀 Rick & Morty Toolkit загружен", C.accent, 3)
warn("[RickMorty v" .. RM._version .. "] UI загружен. Кнопка 🌀 слева сверху. Клавиша " .. tostring(RM.SETTINGS.MenuKey))
-- ============================================================
--  ХЕЛПЕРЫ: направление, луч, урон, эффекты
-- ============================================================
local Camera = Workspace.CurrentCamera

local function getAimDir()
    -- Направление камеры + продвижение вперёд
    local ok, dir = pcall(function() return Camera.CFrame.LookVector end)
    if ok and dir then return dir end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame.LookVector end
    return Vector3.new(0, 0, -1)
end

local function getHandPos()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local right = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or hrp
    return (right.Position or right.CFrame.Position), hrp
end

local function isPlayerTarget(model)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

-- Создаёт луч из start в направлении dir на длину length
local function spawnBeam(startPos, dir, length, color, thickness, duration)
    color = color or Color3.fromRGB(0, 255, 100)
    thickness = thickness or 0.6
    duration = duration or 0.18
    local beam = Instance.new("Part")
    beam.Name = "RM_Beam"
    beam.Anchored = true
    beam.CanCollide = false
    beam.CastShadow = false
    beam.Material = Enum.Material.Neon
    beam.Color = color
    beam.Size = Vector3.new(thickness, thickness, length)
    beam.CFrame = CFrame.new(startPos + dir * (length * 0.5), startPos + dir * (length * 0.5) + dir)
    beam.Parent = Workspace
    local glow = Instance.new("PointLight", beam)
    glow.Color = color
    glow.Range = 8
    glow.Brightness = 1.5
    glow.Shadows = false
    task.delay(duration, function()
        pcall(function() beam:Destroy() end)
    end)
    return beam
end

-- Частицы (эмиттер на короткое время)
local function spawnBurst(pos, color, amount, speed)
    local p = Instance.new("Part")
    p.Name = "RM_Burst"
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.CFrame = CFrame.new(pos)
    p.Parent = Workspace
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 0
    pe.Lifetime = NumberRange.new(0.4, 0.9)
    pe.Speed = NumberRange.new((speed or 15) * 0.5, speed or 15)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    pe.Color = ColorSequence.new(color or Color3.fromRGB(0, 255, 100))
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = p
    pe:Emit(amount or 20)
    task.delay(1.5, function() pcall(function() p:Destroy() end) end)
end

-- Клиентский урон по ближайшей NPC-модели в радиусе (только не игроки)
local function damageNearest(pos, radius, dmg)
    local best, bestDist = nil, radius
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m ~= LocalPlayer.Character and not isPlayerTarget(m) then
            local hum = m:FindFirstChildOfClass("Humanoid")
            local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m.PrimaryPart
            if hum and root and hum.Health > 0 then
                local d = (root.Position - pos).Magnitude
                if d < bestDist then
                    best, bestDist = m, d
                end
            end
        end
    end
    if best then
        local hum = best:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum:TakeDamage(dmg or 25) end)
        end
        return best
    end
    return nil
end

-- ============================================================
--  ХРАНИЛИЩЕ АКТИВНЫХ ЭФФЕКТОВ (для unload)
-- ============================================================
local activeFx = {}
local function pushFx(inst)
    if inst then activeFx[#activeFx + 1] = inst end
end
RM._cleanup[#RM._cleanup + 1] = function()
    for _, inst in ipairs(activeFx) do
        pcall(function() if inst and inst.Parent then inst:Destroy() end end)
    end
    activeFx = {}
end

-- ============================================================
--  КУЛДАУНЫ
-- ============================================================
local cooldowns = {}
local function isOnCD(id)
    local t = cooldowns[id] or 0
    return os.clock() < t, math.max(0, t - os.clock())
end
local function setCD(id, sec)
    cooldowns[id] = os.clock() + sec
end

-- ============================================================
--  ОРУЖИЕ
-- ============================================================
local function getLaserColor()
    local c = RM.SETTINGS.LaserColor
    return Color3.fromRGB(c.R, c.G, c.B)
end

local function doLaserPistol()
    local pos, hrp = getHandPos()
    if not pos then notify("Нет персонажа", C.danger); return false end
    local dir = getAimDir()
    local length = 120
    local beam = spawnBeam(pos, dir, length, getLaserColor(), 0.5, 0.15)
    pushFx(beam)
    spawnBurst(pos, getLaserColor(), 15, 20)
    local endPos = pos + dir * length
    local hit = damageNearest(endPos, 8, 25)
    if hit then spawnBurst(endPos, getLaserColor(), 25, 25) end
    playSound("laser", 0.5, 1.2)
    return true
end

local function doFreezeRay()
    local pos, hrp = getHandPos()
    if not pos then return false end
    local dir = getAimDir()
    local length = 100
    local beam = spawnBeam(pos, dir, length, Color3.fromRGB(150, 220, 255), 0.7, 0.25)
    pushFx(beam)
    spawnBurst(pos, Color3.fromRGB(150, 220, 255), 20, 18)
    local endPos = pos + dir * length
    local hit = damageNearest(endPos, 10, 8)
    if hit then
        -- визуальная заморозка (Ice + синеватый цвет)
        local parts = {}
        for _, d in ipairs(hit:GetDescendants()) do
            if d:IsA("BasePart") then
                table.insert(parts, { p = d, mat = d.Material, col = d.Color })
                d.Material = Enum.Material.Ice
                d.Color = Color3.fromRGB(180, 220, 255)
            end
        end
        spawnBurst(endPos, Color3.fromRGB(180, 240, 255), 40, 25)
        task.delay(3, function()
            for _, q in ipairs(parts) do
                pcall(function()
                    q.p.Material = q.mat
                    q.p.Color = q.col
                end)
            end
        end)
    end
    playSound("laser", 0.4, 0.7)
    return true
end

local function doMultiLaser()
    local pos, hrp = getHandPos()
    if not pos then return false end
    local dir = getAimDir()
    local length = 100
    local angles = { -15, 0, 15 }
    for _, deg in ipairs(angles) do
        local rot = CFrame.Angles(0, math.rad(deg), 0)
        local d = (CFrame.new(Vector3.zero, dir) * rot).LookVector
        local beam = spawnBeam(pos, d, length, getLaserColor(), 0.35, 0.15)
        pushFx(beam)
        task.delay(0.02 * #angles, function()
            damageNearest(pos + d * length, 6, 12)
        end)
    end
    spawnBurst(pos, getLaserColor(), 30, 22)
    playSound("laser", 0.5, 1.0)
    return true
end

local function doBlaster()
    local pos, hrp = getHandPos()
    if not pos then return false end
    local dir = getAimDir()
    local length = 90
    local beam = spawnBeam(pos, dir, length, Color3.fromRGB(255, 150, 50), 1.6, 0.35)
    pushFx(beam)
    spawnBurst(pos, Color3.fromRGB(255, 150, 50), 40, 25)
    local endPos = pos + dir * length
    local hit = damageNearest(endPos, 14, 45)
    if hit then
        spawnBurst(endPos, Color3.fromRGB(255, 200, 100), 50, 30)
        -- визуальное отбрасывание NPC
        local root = hit:FindFirstChild("HumanoidRootPart")
        if root then
            local vel = Instance.new("BodyVelocity")
            vel.Velocity = dir * 60 + Vector3.new(0, 30, 0)
            vel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            vel.Parent = root
            task.delay(0.3, function() pcall(function() vel:Destroy() end) end)
        end
    end
    playSound("laser", 0.7, 0.6)
    return true
end

local function doSword()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local dir = hrp.CFrame.LookVector
    -- энергетический клинок на 0.3 сек
    local blade = Instance.new("Part")
    blade.Name = "RM_Blade"
    blade.Anchored = false
    blade.CanCollide = false
    blade.CastShadow = false
    blade.Material = Enum.Material.Neon
    blade.Color = Color3.fromRGB(80, 255, 200)
    blade.Size = Vector3.new(0.15, 0.15, 5)
    blade.CFrame = hrp.CFrame * CFrame.new(1, 0, -2.5)
    blade.Parent = Workspace
    pushFx(blade)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hrp
    weld.Part1 = blade
    weld.Parent = blade
    spawnBurst(hrp.Position + dir * 3, Color3.fromRGB(80, 255, 200), 25, 15)
    damageNearest(hrp.Position + dir * 3, 4, 35)
    playSound("laser", 0.4, 1.6)
    task.delay(0.35, function() pcall(function() blade:Destroy() end) end)
    return true
end

-- ============================================================
--  ПОРТАЛЬНАЯ ПУШКА
-- ============================================================
local function makePortalRing(pos, cframe, color, size)
    local folder = Instance.new("Folder")
    folder.Name = "RM_Portal"
    folder.Parent = Workspace
    local segs = 28
    local radius = size or 4.5
    for i = 1, segs do
        local a = (i - 1) / segs * math.pi * 2
        local seg = Instance.new("Part")
        seg.Name = "Ring"
        seg.Anchored = true
        seg.CanCollide = false
        seg.CastShadow = false
        seg.Material = Enum.Material.Neon
        seg.Color = color
        seg.Size = Vector3.new(0.25, radius * 2 * math.pi / segs * 0.95, 0.25)
        seg.CFrame = cframe
            * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)
            * CFrame.Angles(0, 0, a + math.pi / 2)
        seg.Parent = folder
    end
    -- центральный диск
    local disc = Instance.new("Part")
    disc.Name = "Disc"
    disc.Anchored = true
    disc.CanCollide = false
    disc.CastShadow = false
    disc.Material = Enum.Material.Neon
    disc.Color = color
    disc.Size = Vector3.new(radius * 1.6, radius * 1.6, 0.1)
    disc.CFrame = cframe
    disc.Transparency = 0.55
    disc.Shape = Enum.PartType.Ball
    disc.Parent = folder
    -- искры
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 40
    pe.Lifetime = NumberRange.new(0.4, 1.0)
    pe.Speed = NumberRange.new(2, 6)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
    pe.Color = ColorSequence.new(color)
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = disc
    pushFx(folder)
    return folder, disc
end

local function doPortalGun()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then notify("Нет персонажа", C.danger); return false end
    local camPos = Camera.CFrame.Position
    local dir = getAimDir()
    local targetPos = camPos + dir * 30
    -- ставим портал там, куда смотрит игрок
    local lookCF = Camera.CFrame
    local blue = Color3.fromRGB(60, 160, 255)
    local orange = Color3.fromRGB(255, 130, 40)
    local folderA, discA = makePortalRing(targetPos, lookCF, blue, 4.5)
    local folderB, discB = makePortalRing(hrp.Position + Vector3.new(0, 3, 0), lookCF, orange, 3.5)
    spawnBurst(targetPos, blue, 40, 25)
    spawnBurst(hrp.Position + Vector3.new(0, 3, 0), orange, 40, 25)
    playSound("portal", 0.7, 1)
    notify("🌀 Портал открыт — вход " .. math.floor(targetPos.X) .. "," .. math.floor(targetPos.Y) .. "," .. math.floor(targetPos.Z),
        Color3.fromRGB(120, 200, 255), 3)
    -- Удаляем оба портала через 6 секунд
    task.delay(6, function()
        pcall(function()
            for _, ch in ipairs(folderA:GetChildren()) do
                if ch:IsA("BasePart") then
                    TweenService:Create(ch, TweenInfo.new(0.4), { Transparency = 1 }):Play()
                end
            end
            for _, ch in ipairs(folderB:GetChildren()) do
                if ch:IsA("BasePart") then
                    TweenService:Create(ch, TweenInfo.new(0.4), { Transparency = 1 }):Play()
                end
            end
            task.wait(0.5)
            folderA:Destroy()
            folderB:Destroy()
        end)
    end)
    return true
end

-- ============================================================
--  РЕЕСТР ОРУЖИЯ
-- ============================================================
RM.WEAPONS = {
    { id = "portal_gun",  name = "🌀 Портальная пушка",  desc = "Открывает портал в направлении камеры", cd = 6,  fire = doPortalGun,    color = C.accent },
    { id = "laser_pistol",name = "🔫 Лазерный пистолет", desc = "Энергетический луч на 120 studs",        cd = 1.2, fire = doLaserPistol,  color = C.accent },
    { id = "freeze_ray",  name = "❄️ Замораживающий луч", desc = "Замораживает NPC на 3 сек",              cd = 3,  fire = doFreezeRay,    color = Color3.fromRGB(150, 220, 255) },
    { id = "multi_laser", name = "🔱 Мульти-лазер",      desc = "Три луча веером",                          cd = 1.5, fire = doMultiLaser,  color = C.accent3 },
    { id = "blaster",     name = "💥 Бластер",           desc = "Мощный выстрел с отбрасыванием",           cd = 2.5, fire = doBlaster,      color = Color3.fromRGB(255, 150, 50) },
    { id = "ai_sword",    name = "⚔️ AI-меч",            desc = "Энергетический клинок для ближнего боя",     cd = 0.8, fire = doSword,        color = Color3.fromRGB(80, 255, 200) },
}

-- ============================================================
--  UI: ВКЛАДКА «ОРУЖИЕ»
-- ============================================================
do
    local frame = tabFrames["weapons"]
    newSection(frame, "ОРУЖИЕ")
    for _, w in ipairs(RM.WEAPONS) do
        local btn = newButton(frame, w.name .. "   [" .. w.id .. "]", C.bg2, nil, 40)
        local lblName = Instance.new("TextLabel")
        lblName.Size = UDim2.new(1, -20, 0, 14)
        lblName.Position = UDim2.fromOffset(10, 3)
        lblName.BackgroundTransparency = 1
        lblName.Text = w.name
        lblName.TextColor3 = C.text
        lblName.Font = Enum.Font.GothamBold
        lblName.TextSize = 11
        lblName.TextXAlignment = Enum.TextXAlignment.Left
        lblName.ZIndex = 43
        lblName.Parent = btn
        local lblDesc = Instance.new("TextLabel")
        lblDesc.Size = UDim2.new(1, -20, 0, 12)
        lblDesc.Position = UDim2.fromOffset(10, 20)
        lblDesc.BackgroundTransparency = 1
        lblDesc.Text = w.desc
        lblDesc.TextColor3 = C.textDim
        lblDesc.Font = Enum.Font.Gotham
        lblDesc.TextSize = 9
        lblDesc.TextXAlignment = Enum.TextXAlignment.Left
        lblDesc.ZIndex = 43
        lblDesc.Parent = btn
        btn.Text = ""

        -- индикатор кулдауна
        local cdBar = Instance.new("Frame")
        cdBar.Size = UDim2.new(0, 0, 0, 3)
        cdBar.Position = UDim2.new(0, 4, 1, -4)
        cdBar.BackgroundColor3 = w.color
        cdBar.BorderSizePixel = 0
        cdBar.ZIndex = 44
        cdBar.Parent = btn
        Instance.new("UICorner", cdBar).CornerRadius = UDim.new(0, 2)

        btn.MouseButton1Click:Connect(function()
            local onCD, remaining = isOnCD(w.id)
            if onCD then
                notify("⏳ " .. w.name .. " перезарядка " .. string.format("%.1f", remaining) .. "с", C.textDim, 1.5)
                return
            end
            local ok, err = pcall(w.fire)
            if ok then
                setCD(w.id, w.cd)
                -- запускаем заполнение cdBar
                cdBar.Size = UDim2.new(1, -8, 0, 3)
                TweenService:Create(cdBar, TweenInfo.new(w.cd, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()
                notify("✅ " .. w.name, w.color, 1.5)
            else
                notify("❌ Ошибка: " .. tostring(err), C.danger, 3)
            end
        end)
    end

    newSection(frame, "СОВЕТ")
    local tip = Instance.new("TextLabel")
    tip.Size = UDim2.new(1, -8, 0, 40)
    tip.BackgroundColor3 = C.bg2
    tip.BackgroundTransparency = 0.2
    tip.Text = "  🎯 Направление = куда смотрит камера.\n  Наведись на цель и жми кнопку."
    tip.TextColor3 = C.textDim
    tip.Font = Enum.Font.Gotham
    tip.TextSize = 10
    tip.TextXAlignment = Enum.TextXAlignment.Left
    tip.TextWrapped = true
    tip.ZIndex = 42
    tip.Parent = frame
    Instance.new("UICorner", tip).CornerRadius = UDim.new(0, 8)
    local tp = Instance.new("UIPadding", tip)
    tp.PaddingTop = UDim.new(0, 4)
end
-- ============================================================
--  ГАДЖЕТЫ
-- ============================================================

-- 1) Реактивные ботинки — временное ускорение + прыжок
local boostState = { active = false, endsAt = 0, origWalk = 16, origJump = 50 }
local function doJetBoots()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then notify("Нет персонажа", C.danger); return false end
    -- снимаем старый буст если был
    if boostState.active then
        hum.WalkSpeed = boostState.origWalk
        hum.JumpPower = boostState.origJump
    end
    boostState.origWalk = hum.WalkSpeed
    boostState.origJump = hum.JumpPower
    boostState.active = true
    local dur = 8
    boostState.endsAt = os.clock() + dur
    hum.WalkSpeed = RM.SETTINGS.SpeedBoost
    hum.JumpPower = RM.SETTINGS.JumpBoost
    -- визуал: огоньки под ногами
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        spawnBurst(hrp.Position - Vector3.new(0, 3, 0), Color3.fromRGB(120, 200, 255), 30, 12)
    end
    notify("🚀 Реактивные ботинки: " .. dur .. "с", C.accent3, 2)
    task.delay(dur, function()
        if not boostState.active then return end
        boostState.active = false
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            h.WalkSpeed = boostState.origWalk
            h.JumpPower = boostState.origJump
        end
    end)
    return true
end

-- 2) Перчатка антигравитации — подкидывает ближайший NPC
local function doAntiGrav()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local pos = hrp.Position
    local best, bestDist = nil, 40
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m ~= char and not isPlayerTarget(m) then
            local root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso") or m.PrimaryPart
            if root then
                local d = (root.Position - pos).Magnitude
                if d < bestDist then best, bestDist = m, d end
            end
        end
    end
    if not best then notify("Никого рядом (радиус 40)", C.textDim, 2); return false end
    local root = best:FindFirstChild("HumanoidRootPart") or best:FindFirstChild("Torso") or best.PrimaryPart
    if not root then return false end
    -- подбрасываем
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 120, 0)
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Parent = root
    spawnBurst(root.Position, Color3.fromRGB(180, 120, 255), 40, 25)
    task.delay(0.7, function() pcall(function() bv:Destroy() end) end)
    notify("✨ Антигравитация: " .. (best.Name or "?"), C.accent2, 2)
    return true
end

-- 3) Пояс невидимости — делает локального игрока полупрозрачным
local invisState = { active = false, saved = {} }
local function doInvisibility()
    local char = LocalPlayer.Character
    if not char then return false end
    if invisState.active then
        -- снять невидимость
        for part, t in pairs(invisState.saved) do
            pcall(function()
                if part and part.Parent then part.Transparency = t end
            end)
        end
        invisState.active = false
        invisState.saved = {}
        notify("👁 Видимость восстановлена", C.accent, 2)
        return true
    end
    invisState.saved = {}
    invisState.active = true
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            invisState.saved[d] = d.Transparency
            pcall(function() d.Transparency = 0.85 end)
        end
    end
    local dur = RM.SETTINGS.InvisDuration
    notify("👻 Невидимость: " .. dur .. "с", C.accent2, 2)
    task.delay(dur, function()
        if not invisState.active then return end
        for part, t in pairs(invisState.saved) do
            pcall(function()
                if part and part.Parent then part.Transparency = t end
            end)
        end
        invisState.saved = {}
        invisState.active = false
    end)
    return true
end

-- 4) Часы с частичным лучом — короткий телепорт вперёд
local function doBlink()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local dir = getAimDir()
    dir = Vector3.new(dir.X, 0, dir.Z).Unit
    if dir.Magnitude < 0.1 then dir = hrp.CFrame.LookVector end
    local from = hrp.Position
    local to = from + dir * 25
    spawnBurst(from, Color3.fromRGB(120, 200, 255), 30, 20)
    hrp.CFrame = CFrame.new(to, to + hrp.CFrame.LookVector)
    spawnBurst(to, Color3.fromRGB(120, 200, 255), 30, 20)
    notify("⏱ Телепорт на 25 studs", C.accent3, 1.5)
    return true
end

-- 5) Кнопка сохранения — сохраняет точку, потом возвращает
local savePoint = nil
local function doSavePoint()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if savePoint then
        -- возврат к точке
        local from = hrp.Position
        spawnBurst(from, Color3.fromRGB(255, 220, 100), 40, 20)
        hrp.CFrame = savePoint
        spawnBurst(savePoint.Position, Color3.fromRGB(255, 220, 100), 40, 20)
        notify("↩ Возврат к точке", C.accent, 2)
        savePoint = nil
    else
        savePoint = hrp.CFrame
        notify("💾 Точка сохранена — нажми ещё раз чтобы вернуться", C.success, 2)
    end
    return true
end

RM.GADGETS = {
    { id = "jet_boots",   name = "🚀 Реактивные ботинки", desc = "Скорость " .. RM.SETTINGS.SpeedBoost .. " + прыжок на 8с", cd = 10, fire = doJetBoots,    color = C.accent3 },
    { id = "anti_grav",   name = "🧤 Перчатка антиграв",  desc = "Подкидывает ближайшего NPC",                     cd = 4,  fire = doAntiGrav,    color = C.accent2 },
    { id = "invis_belt",  name = "👻 Пояс невидимости",   desc = "Полупрозрачность " .. RM.SETTINGS.InvisDuration .. "с", cd = 12, fire = doInvisibility, color = C.accent2 },
    { id = "blink_watch", name = "⏱ Часы-блинк",         desc = "Телепорт вперёд на 25 studs",                    cd = 3,  fire = doBlink,       color = C.accent3 },
    { id = "save_point",  name = "💾 Кнопка сохранения",  desc = "Запомнить и вернуться",                          cd = 1,  fire = doSavePoint,   color = C.success },
}

-- ============================================================
--  UI: ВКЛАДКА «ГАДЖЕТЫ»
-- ============================================================
do
    local frame = tabFrames["gadgets"]
    newSection(frame, "ГАДЖЕТЫ")
    for _, g in ipairs(RM.GADGETS) do
        local btn = newButton(frame, g.name, C.bg2, nil, 40)
        local lblName = Instance.new("TextLabel")
        lblName.Size = UDim2.new(1, -20, 0, 14)
        lblName.Position = UDim2.fromOffset(10, 3)
        lblName.BackgroundTransparency = 1
        lblName.Text = g.name
        lblName.TextColor3 = C.text
        lblName.Font = Enum.Font.GothamBold
        lblName.TextSize = 11
        lblName.TextXAlignment = Enum.TextXAlignment.Left
        lblName.ZIndex = 43
        lblName.Parent = btn
        local lblDesc = Instance.new("TextLabel")
        lblDesc.Size = UDim2.new(1, -20, 0, 12)
        lblDesc.Position = UDim2.fromOffset(10, 20)
        lblDesc.BackgroundTransparency = 1
        lblDesc.Text = g.desc
        lblDesc.TextColor3 = C.textDim
        lblDesc.Font = Enum.Font.Gotham
        lblDesc.TextSize = 9
        lblDesc.TextXAlignment = Enum.TextXAlignment.Left
        lblDesc.ZIndex = 43
        lblDesc.Parent = btn
        btn.Text = ""

        local cdBar = Instance.new("Frame")
        cdBar.Size = UDim2.new(0, 0, 0, 3)
        cdBar.Position = UDim2.new(0, 4, 1, -4)
        cdBar.BackgroundColor3 = g.color
        cdBar.BorderSizePixel = 0
        cdBar.ZIndex = 44
        cdBar.Parent = btn
        Instance.new("UICorner", cdBar).CornerRadius = UDim.new(0, 2)

        btn.MouseButton1Click:Connect(function()
            local onCD, remaining = isOnCD(g.id)
            if onCD then
                notify("⏳ " .. g.name .. " — " .. string.format("%.1f", remaining) .. "с", C.textDim, 1.2)
                return
            end
            local ok, err = pcall(g.fire)
            if ok then
                setCD(g.id, g.cd)
                cdBar.Size = UDim2.new(1, -8, 0, 3)
                TweenService:Create(cdBar, TweenInfo.new(g.cd, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) }):Play()
            else
                notify("❌ Ошибка: " .. tostring(err), C.danger, 3)
            end
        end)
    end
end

-- ============================================================
--  СКИНЫ (изменение BodyColors локального игрока)
-- ============================================================

-- Сохраняем оригинальные цвета персонажа при первом применении скина
local origColors = nil

local function captureOrigColors()
    local char = LocalPlayer.Character
    if not char then return end
    local bc = char:FindFirstChild("BodyColors")
    if not bc then return end
    if not origColors then
        origColors = {
            Head = bc.HeadColor3,
            Torso = bc.TorsoColor3,
            LeftArm = bc.LeftArmColor3,
            RightArm = bc.RightArmColor3,
            LeftLeg = bc.LeftLegColor3,
            RightLeg = bc.RightLegColor3,
        }
    end
end

local function applyColors(palette)
    local char = LocalPlayer.Character
    if not char then return end
    captureOrigColors()
    local bc = char:FindFirstChild("BodyColors")
    if not bc then return end
    if palette.Head then bc.HeadColor3 = palette.Head end
    if palette.Torso then bc.TorsoColor3 = palette.Torso end
    if palette.LeftArm then bc.LeftArmColor3 = palette.LeftArm end
    if palette.RightArm then bc.RightArmColor3 = palette.RightArm end
    if palette.LeftLeg then bc.LeftLegColor3 = palette.LeftLeg end
    if palette.RightLeg then bc.RightLegColor3 = palette.RightLeg end
end

local function resetColors()
    local char = LocalPlayer.Character
    if not char or not origColors then return end
    local bc = char:FindFirstChild("BodyColors")
    if not bc then return end
    bc.HeadColor3 = origColors.Head
    bc.TorsoColor3 = origColors.Torso
    bc.LeftArmColor3 = origColors.LeftArm
    bc.RightArmColor3 = origColors.RightArm
    bc.LeftLegColor3 = origColors.LeftLeg
    bc.RightLegColor3 = origColors.RightLeg
    RM.SETTINGS.ActiveSkin = nil
    saveSettings()
end

-- Скины как палитры (без модификации модели, только цвет)
RM.SKINS = {
    {
        id = "rick",
        name = "🧪 Рик Санчес",
        desc = "Белый халат, синие волосы, кожа",
        palette = {
            Head = Color3.fromRGB(255, 220, 180),
            Torso = Color3.fromRGB(240, 240, 245),
            LeftArm = Color3.fromRGB(240, 240, 245),
            RightArm = Color3.fromRGB(240, 240, 245),
            LeftLeg = Color3.fromRGB(80, 110, 180),
            RightLeg = Color3.fromRGB(80, 110, 180),
        },
    },
    {
        id = "morty",
        name = "😰 Морти Смит",
        desc = "Жёлтая футболка, джинсы",
        palette = {
            Head = Color3.fromRGB(250, 215, 180),
            Torso = Color3.fromRGB(245, 230, 90),
            LeftArm = Color3.fromRGB(250, 215, 180),
            RightArm = Color3.fromRGB(250, 215, 180),
            LeftLeg = Color3.fromRGB(60, 80, 140),
            RightLeg = Color3.fromRGB(60, 80, 140),
        },
    },
    {
        id = "summer",
        name = "💗 Саммер Смит",
        desc = "Розовая футболка, джинсы",
        palette = {
            Head = Color3.fromRGB(255, 210, 190),
            Torso = Color3.fromRGB(255, 140, 180),
            LeftArm = Color3.fromRGB(255, 210, 190),
            RightArm = Color3.fromRGB(255, 210, 190),
            LeftLeg = Color3.fromRGB(70, 100, 160),
            RightLeg = Color3.fromRGB(70, 100, 160),
        },
    },
    {
        id = "pickle",
        name = "🥒 Пикл Рик",
        desc = "Огуречно-зелёный",
        palette = {
            Head = Color3.fromRGB(110, 180, 80),
            Torso = Color3.fromRGB(110, 180, 80),
            LeftArm = Color3.fromRGB(110, 180, 80),
            RightArm = Color3.fromRGB(110, 180, 80),
            LeftLeg = Color3.fromRGB(90, 150, 65),
            RightLeg = Color3.fromRGB(90, 150, 65),
        },
    },
    {
        id = "meeseeks",
        name = "💙 Мистер Миссикс",
        desc = "Голубая кожа",
        palette = {
            Head = Color3.fromRGB(100, 180, 240),
            Torso = Color3.fromRGB(100, 180, 240),
            LeftArm = Color3.fromRGB(100, 180, 240),
            RightArm = Color3.fromRGB(100, 180, 240),
            LeftLeg = Color3.fromRGB(100, 180, 240),
            RightLeg = Color3.fromRGB(100, 180, 240),
        },
    },
    {
        id = "rick_prime",
        name = "🖤 Рик Прайм",
        desc = "Тёмный халат",
        palette = {
            Head = Color3.fromRGB(230, 200, 170),
            Torso = Color3.fromRGB(60, 60, 75),
            LeftArm = Color3.fromRGB(60, 60, 75),
            RightArm = Color3.fromRGB(60, 60, 75),
            LeftLeg = Color3.fromRGB(30, 30, 40),
            RightLeg = Color3.fromRGB(30, 30, 40),
        },
    },
    {
        id = "mecha_morty",
        name = "🤖 Меха-Морти",
        desc = "Серый металл",
        palette = {
            Head = Color3.fromRGB(160, 160, 170),
            Torso = Color3.fromRGB(160, 160, 170),
            LeftArm = Color3.fromRGB(140, 140, 150),
            RightArm = Color3.fromRGB(140, 140, 150),
            LeftLeg = Color3.fromRGB(140, 140, 150),
            RightLeg = Color3.fromRGB(140, 140, 150),
        },
    },
}

local function applySkin(skinId)
    for _, s in ipairs(RM.SKINS) do
        if s.id == skinId then
            applyColors(s.palette)
            RM.SETTINGS.ActiveSkin = skinId
            saveSettings()
            notify("🎭 Скин: " .. s.name, C.accent, 2)
            return true
        end
    end
    return false
end

-- Обновление при респавне (скин держится)
track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    origColors = nil
    if RM.SETTINGS.ActiveSkin then
        applySkin(RM.SETTINGS.ActiveSkin)
    end
end))

-- ============================================================
--  UI: ВКЛАДКА «СКИНЫ»
-- ============================================================
do
    local frame = tabFrames["skins"]
    newSection(frame, "СКИНЫ (только цвета, без загрузки моделей)")
    for _, s in ipairs(RM.SKINS) do
        local btn = newButton(frame, s.name, C.bg2, nil, 40)
        local lblName = Instance.new("TextLabel")
        lblName.Size = UDim2.new(1, -20, 0, 14)
        lblName.Position = UDim2.fromOffset(10, 3)
        lblName.BackgroundTransparency = 1
        lblName.Text = s.name
        lblName.TextColor3 = C.text
        lblName.Font = Enum.Font.GothamBold
        lblName.TextSize = 11
        lblName.TextXAlignment = Enum.TextXAlignment.Left
        lblName.ZIndex = 43
        lblName.Parent = btn
        local lblDesc = Instance.new("TextLabel")
        lblDesc.Size = UDim2.new(1, -20, 0, 12)
        lblDesc.Position = UDim2.fromOffset(10, 20)
        lblDesc.BackgroundTransparency = 1
        lblDesc.Text = s.desc
        lblDesc.TextColor3 = C.textDim
        lblDesc.Font = Enum.Font.Gotham
        lblDesc.TextSize = 9
        lblDesc.TextXAlignment = Enum.TextXAlignment.Left
        lblDesc.ZIndex = 43
        lblDesc.Parent = btn
        btn.Text = ""

        btn.MouseButton1Click:Connect(function()
            applySkin(s.id)
        end)
    end

    newSection(frame, "")
    local resetBtn = newButton(frame, "↩ Сбросить скин", C.bg2, nil, 34)
    resetBtn.TextColor3 = C.danger
    resetBtn.MouseButton1Click:Connect(function()
        resetColors()
        notify("🎭 Скин сброшен", C.text, 2)
    end)

    if RM.SETTINGS.ActiveSkin then
        task.spawn(function()
            task.wait(1.5)
            local ok, s = pcall(function()
                for _, sk in ipairs(RM.SKINS) do
                    if sk.id == RM.SETTINGS.ActiveSkin then return sk end
                end
            end)
            if ok and s then
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, -8, 0, 22)
                lbl.BackgroundTransparency = 1
                lbl.Text = "  ✨ Активен: " .. s.name
                lbl.TextColor3 = C.success
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 10
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.ZIndex = 42
                lbl.Parent = frame
            end
        end)
    end
end

-- ============================================================
--  UI: ВКЛАДКА «НАСТРОЙКИ»
-- ============================================================
do
    local frame = tabFrames["settings"]

    -- звуки
    newSection(frame, "ЗВУК")
    local soundBtn = newButton(frame, "🔊 Звуки: " .. (RM.SETTINGS.SoundEnabled and "ВКЛ" or "ВЫКЛ"), C.bg2, nil, 32)
    soundBtn.MouseButton1Click:Connect(function()
        RM.SETTINGS.SoundEnabled = not RM.SETTINGS.SoundEnabled
        soundBtn.Text = "🔊 Звуки: " .. (RM.SETTINGS.SoundEnabled and "ВКЛ" or "ВЫКЛ")
        saveSettings()
    end)

    newSection(frame, "УВЕДОМЛЕНИЯ")
    local notifBtn = newButton(frame, "🔔 Уведомления: " .. (RM.SETTINGS.NotificationsEnabled and "ВКЛ" or "ВЫКЛ"), C.bg2, nil, 32)
    notifBtn.MouseButton1Click:Connect(function()
        RM.SETTINGS.NotificationsEnabled = not RM.SETTINGS.NotificationsEnabled
        notifBtn.Text = "🔔 Уведомления: " .. (RM.SETTINGS.NotificationsEnabled and "ВКЛ" or "ВЫКЛ")
        saveSettings()
    end)

    newSection(frame, "ЦВЕТ ЛАЗЕРА")
    local LASER_PRESETS = {
        { name = "🟢 Портал-зелёный", c = { R = 0, G = 255, B = 100 } },
        { name = "🔵 Циан",           c = { R = 120, G = 220, B = 255 } },
        { name = "🟣 Фиолет",         c = { R = 180, G = 100, B = 255 } },
        { name = "🔴 Красный",        c = { R = 255, G = 80, B = 80 } },
        { name = "🟡 Жёлтый",         c = { R = 255, G = 220, B = 50 } },
    }
    local laserIdx = 1
    for i, p in ipairs(LASER_PRESETS) do
        if p.c.R == RM.SETTINGS.LaserColor.R
           and p.c.G == RM.SETTINGS.LaserColor.G
           and p.c.B == RM.SETTINGS.LaserColor.B then
            laserIdx = i; break
        end
    end
    local laserBtn = newButton(frame, "🎨 " .. LASER_PRESETS[laserIdx].name, C.bg2, nil, 32)
    laserBtn.MouseButton1Click:Connect(function()
        laserIdx = laserIdx % #LASER_PRESETS + 1
        RM.SETTINGS.LaserColor = LASER_PRESETS[laserIdx].c
        laserBtn.Text = "🎨 " .. LASER_PRESETS[laserIdx].name
        saveSettings()
    end)

    newSection(frame, "ГАДЖЕТЫ")
    local SPEED_STEPS = { 30, 45, 60, 80, 100, 130 }
    local speedIdx = 1
    for i, v in ipairs(SPEED_STEPS) do if v == RM.SETTINGS.SpeedBoost then speedIdx = i; break end end
    local speedBtn = newButton(frame, "🚀 Скорость буста: " .. RM.SETTINGS.SpeedBoost, C.bg2, nil, 32)
    speedBtn.MouseButton1Click:Connect(function()
        speedIdx = speedIdx % #SPEED_STEPS + 1
        RM.SETTINGS.SpeedBoost = SPEED_STEPS[speedIdx]
        speedBtn.Text = "🚀 Скорость буста: " .. RM.SETTINGS.SpeedBoost
        saveSettings()
    end)

    local JUMP_STEPS = { 50, 80, 120, 150 }
    local jumpIdx = 1
    for i, v in ipairs(JUMP_STEPS) do if v == RM.SETTINGS.JumpBoost then jumpIdx = i; break end end
    local jumpBtn = newButton(frame, "🦘 Прыжок буста: " .. RM.SETTINGS.JumpBoost, C.bg2, nil, 32)
    jumpBtn.MouseButton1Click:Connect(function()
        jumpIdx = jumpIdx % #JUMP_STEPS + 1
        RM.SETTINGS.JumpBoost = JUMP_STEPS[jumpIdx]
        jumpBtn.Text = "🦘 Прыжок буста: " .. RM.SETTINGS.JumpBoost
        saveSettings()
    end)

    local INV_STEPS = { 4, 8, 12, 20 }
    local invIdx = 1
    for i, v in ipairs(INV_STEPS) do if v == RM.SETTINGS.InvisDuration then invIdx = i; break end end
    local invBtn = newButton(frame, "👻 Невидимость: " .. RM.SETTINGS.InvisDuration .. "с", C.bg2, nil, 32)
    invBtn.MouseButton1Click:Connect(function()
        invIdx = invIdx % #INV_STEPS + 1
        RM.SETTINGS.InvisDuration = INV_STEPS[invIdx]
        invBtn.Text = "👻 Невидимость: " .. RM.SETTINGS.InvisDuration .. "с"
        saveSettings()
    end)

    newSection(frame, "ИНТЕРФЕЙС")
    local keyBtn = newButton(frame, "⌨ Клавиша меню: " .. tostring(RM.SETTINGS.MenuKey), C.bg2, nil, 32)
    keyBtn.MouseButton1Click:Connect(function()
        notify("Клавиша по умолчанию: RightShift. Менять через файл сохранения.", C.textDim, 3)
    end)

    newSection(frame, "ДЕЙСТВИЯ")
    local resetBtn = newButton(frame, "🔄 Сбросить все настройки", C.bg2, nil, 34)
    resetBtn.TextColor3 = C.danger
    resetBtn.MouseButton1Click:Connect(function()
        RM.SETTINGS.SoundEnabled = true
        RM.SETTINGS.NotificationsEnabled = true
        RM.SETTINGS.LaserColor = { R = 0, G = 255, B = 100 }
        RM.SETTINGS.SpeedBoost = 60
        RM.SETTINGS.JumpBoost = 80
        RM.SETTINGS.InvisDuration = 8
        saveSettings()
        notify("🔄 Настройки сброшены", C.success, 2)
        soundBtn.Text = "🔊 Звуки: ВКЛ"
        notifBtn.Text = "🔔 Уведомления: ВКЛ"
        laserBtn.Text = "🎨 " .. LASER_PRESETS[1].name
        speedBtn.Text = "🚀 Скорость буста: 60"
        jumpBtn.Text = "🦘 Прыжок буста: 80"
        invBtn.Text = "👻 Невидимость: 8с"
    end)

    local unloadBtn = newButton(frame, "❌ ВЫГРУЗИТЬ СКРИПТ", C.bg2, nil, 36)
    unloadBtn.BackgroundColor3 = C.danger
    unloadBtn.BackgroundTransparency = 0.3
    unloadBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    unloadBtn.MouseButton1Click:Connect(function()
        RM.unload()
    end)

    newSection(frame, "О СКРИПТЕ")
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -8, 0, 80)
    info.BackgroundColor3 = C.bg2
    info.BackgroundTransparency = 0.2
    info.Text = "\n  Rick & Morty Toolkit v" .. RM._version .. "\n  Оружие: 6  |  Гаджеты: 5  |  Скины: 7\n  Всё локально, без серверного урона.\n  Без 18+ контента."
    info.TextColor3 = C.textDim
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextWrapped = true
    info.ZIndex = 42
    info.Parent = frame
    Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)
end

-- ============================================================
--  ИНИЦИАЛИЗАЦИЯ
-- ============================================================

-- Портальная вкладка: добавим кнопку описания (если ещё не)
do
    local frame = tabFrames["portal"]
    newSection(frame, "ПОРТАЛЬНАЯ ПУШКА")
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -8, 0, 70)
    info.BackgroundColor3 = C.bg2
    info.BackgroundTransparency = 0.2
    info.Text = "\n  Портальная пушка доступна во вкладке 🔫 ОРУЖИЕ.\n  Открывает два портала: синий (впереди) и\n  оранжевый (у тебя под ногами).\n  Через 6 секунд исчезают."
    info.TextColor3 = C.textDim
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextWrapped = true
    info.ZIndex = 42
    info.Parent = frame
    Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)

    local quickPortal = newButton(frame, "🌀 Открыть портал (быстро)", C.accent, nil, 40)
    quickPortal.MouseButton1Click:Connect(function()
        local ok, err = pcall(doPortalGun)
        if not ok then notify("❌ " .. tostring(err), C.danger, 3) end
    end)
end

switchTab("portal")

-- Восстановление скина из сохранения (если был)
if RM.SETTINGS.ActiveSkin then
    task.spawn(function()
        task.wait(2)
        applySkin(RM.SETTINGS.ActiveSkin)
    end)
end

-- Финальный warn
warn(string.format("[RickMorty v%s] Загружен. %d оружий, %d гаджетов, %d скинов. Кнопка 🌀 слева. Клавиша: %s",
    RM._version,
    #RM.WEAPONS,
    #RM.GADGETS,
    #RM.SKINS,
    tostring(RM.SETTINGS.MenuKey)))

GENV._RM_BUSY = nil

return RM
