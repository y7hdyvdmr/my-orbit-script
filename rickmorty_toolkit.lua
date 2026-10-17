-- Rick & Morty Toolkit v2.0 (standalone)
-- Скины (замена частей тела), портальная пушка, мобильный прицел.
-- Без 18+ контента.
-- Правила: DisplayOrder ≤ 65, getSafeParent, страховка в destroy, коннекты в conns.

local GENV = rawget(_G, "getgenv") and getgenv() or _G
local RM = {}
GENV.RickMorty = RM
RM._version = "2.0"

-- Защита от повторного запуска
if GENV._RM_BUSY and os.clock() - (GENV._RM_BUSY_T or 0) < 30 then
    warn("[RickMorty] повторный запуск проигнорирован")
    return
end
GENV._RM_BUSY = true
GENV._RM_BUSY_T = os.clock()

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local Workspace    = game:GetService("Workspace")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

RM.Players = Players
RM.RunService = RunService
RM.TweenService = TweenService
RM.UIS = UIS
RM.Workspace = Workspace
RM.LocalPlayer = LocalPlayer
RM.HAS_FS = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
RM.SAVE_FILE = "rickmorty_v2.json"

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

local conns = {}
local function track(c) conns[#conns + 1] = c; return c end
RM._conns = conns
local alive = true

-- Настройки
RM.SETTINGS = {
    SoundEnabled = true,
    NotificationsEnabled = true,
    NotifDuration = 2,
    MenuKey = "RightShift",
    LaserColor = { R = 0, G = 255, B = 100 },
    ActiveSkin = nil,
    PortalColor = { R = 80, G = 255, B = 80 }, -- зелёный, как на фото
    AimSensitivity = 1.0,
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

-- Звуки
local sfxFolder = Instance.new("Folder")
sfxFolder.Name = "RM_Sfx_" .. tostring(math.random(100000, 999999))
sfxFolder.Parent = game:GetService("SoundService")
RM.sfxFolder = sfxFolder

local SFX_IDS = {
    portal = "rbxassetid://3314038600",
    laser  = "rbxassetid://12221967",
    click  = "rbxasset://sounds/button.wav",
    notify = "rbxasset://sounds/electronicpingshort.wav",
    shoot  = "rbxasset://sounds/snap.mp3",
}
local function playSound(idName, vol, pitch)
    if not RM.SETTINGS.SoundEnabled then return end
    local id = SFX_IDS[idName]
    if not id then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = vol or 0.5
        s.PlaybackSpeed = pitch or 1
        s.Parent = sfxFolder
        s:Play()
        task.delay(4, function() pcall(function() s:Destroy() end) end)
    end)
end
RM.playSound = playSound

-- Уведомления
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

-- Цвета стиля
local C = {
    bg      = Color3.fromRGB(18, 14, 28),
    bg2     = Color3.fromRGB(28, 22, 42),
    accent  = Color3.fromRGB(100, 255, 140),
    accent2 = Color3.fromRGB(150, 90, 255),
    accent3 = Color3.fromRGB(120, 220, 255),
    text    = Color3.fromRGB(240, 235, 255),
    textDim = Color3.fromRGB(150, 140, 180),
    danger  = Color3.fromRGB(255, 100, 120),
    success = Color3.fromRGB(120, 255, 160),
    stroke  = Color3.fromRGB(120, 90, 220),
}

-- Корневой GUI
local gui = Instance.new("ScreenGui")
gui.Name = "_RickMorty_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 65
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(gui)
local okp = pcall(function() gui.Parent = getSafeParent() end)
if not okp or not gui.Parent then gui.Parent = PlayerGui end
RM.gui = gui

-- Кнопка меню
local mainBtn = Instance.new("TextButton")
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
    gr.Color = ColorSequence.new(C.accent, C.accent3, C.accent2)
    gr.Rotation = 45
end

-- Меню
local WINDOW_W, WINDOW_H = 380, 500
local window = Instance.new("Frame")
window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
window.Position = UDim2.fromOffset(90, 80)
window.BackgroundColor3 = C.bg
window.BackgroundTransparency = 0.02
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

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundTransparency = 1
header.ZIndex = 41
header.Parent = window
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "🌀 RICK & MORTY v2.0"
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
closeBtn.MouseButton1Click:Connect(function() window.Visible = false end)

local tabsBar = Instance.new("Frame")
tabsBar.Size = UDim2.new(1, -16, 0, 38)
tabsBar.Position = UDim2.fromOffset(8, 48)
tabsBar.BackgroundTransparency = 1
tabsBar.ZIndex = 41
tabsBar.Parent = window
local tabList = Instance.new("UIListLayout", tabsBar)
tabList.FillDirection = Enum.FillDirection.Horizontal
tabList.Padding = UDim.new(0, 4)

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -16, 1, -140)
content.Position = UDim2.fromOffset(8, 90)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = C.accent
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ZIndex = 41
content.Parent = window
local contentList = Instance.new("UIListLayout", content)
contentList.Padding = UDim.new(0, 6)
contentList.SortOrder = Enum.SortOrder.LayoutOrder

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -20, 0, 16)
footer.Position = UDim2.new(0, 10, 1, -22)
footer.BackgroundTransparency = 1
footer.Text = "v" .. RM._version .. " | мобильный прицел | без 18+"
footer.TextColor3 = C.textDim
footer.Font = Enum.Font.Code
footer.TextSize = 9
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = window

-- Хелперы UI
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
    b.ZIndex = 42
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local st = Instance.new("UIStroke", b)
    st.Color = C.stroke; st.Thickness = 1; st.Transparency = 0.7
    if onClick then
        b.MouseButton1Click:Connect(function()
            playSound("click", 0.3)
            pcall(onClick)
        end)
    end
    return b
end

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

-- Вкладки
local TABS = {
    { id = "skins",    label = "🎭 СКИНЫ",   color = C.accent },
    { id = "portal",   label = "🌀 ПОРТАЛ",  color = C.accent3 },
    { id = "settings", label = "⚙️",         color = C.textDim },
}
local tabButtons = {}
local tabFrames = {}
local activeTab = "skins"

local function switchTab(id)
    activeTab = id
    for tabId, frame in pairs(tabFrames) do frame.Visible = (tabId == id) end
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
    btn.Size = UDim2.fromOffset(t.id == "settings" and 40 or 90, 32)
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
    frame.Visible = (t.id == "skins")
    frame.ZIndex = 41
    frame.Parent = content
    tabFrames[t.id] = frame
    local fl = Instance.new("UIListLayout", frame)
    fl.Padding = UDim.new(0, 6)
    fl.SortOrder = Enum.SortOrder.LayoutOrder
end

-- Открытие/закрытие меню
local function openMenu() window.Visible = true end
local function closeMenu() window.Visible = false end
RM.openMenu = openMenu
RM.closeMenu = closeMenu

mainBtn.MouseButton1Click:Connect(function()
    if window.Visible then closeMenu() else openMenu() end
end)

track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if tostring(input.KeyCode):find(RM.SETTINGS.MenuKey) then
        if window.Visible then closeMenu() else openMenu() end
    end
end))

-- Уведомления UI
local notifHolder = Instance.new("Frame")
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
            f.ZIndex = 61
            f.Parent = notifHolder
            Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
            local st = Instance.new("UIStroke", f)
            st.Color = n.color; st.Thickness = 1.5; st.Transparency = 0.2
            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(0, 3, 1, -8)
            bar.Position = UDim2.fromOffset(4, 4)
            bar.BackgroundColor3 = n.color
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
--  МОБИЛЬНОЕ УПРАВЛЕНИЕ: ПРИЦЕЛ И КНОПКА ВЫСТРЕЛА
-- ============================================================
local isMobile = UIS.TouchEnabled and not UIS.MouseEnabled
local aimPos = Vector2.new(0.5, 0.5) -- относительные координаты (0..1)
local aimActive = false
local aimFrame = nil
local fireBtn = nil

local function createAimUI()
    if not isMobile then return end

    -- Прицел
    aimFrame = Instance.new("Frame")
    aimFrame.Name = "RM_Aim"
    aimFrame.Size = UDim2.fromOffset(60, 60)
    aimFrame.Position = UDim2.fromScale(aimPos.X, aimPos.Y)
    aimFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    aimFrame.BackgroundTransparency = 1
    aimFrame.ZIndex = 55
    aimFrame.Parent = gui
    -- Круг
    local circle = Instance.new("ImageLabel")
    circle.Size = UDim2.fromScale(1, 1)
    circle.BackgroundTransparency = 1
    circle.Image = "rbxassetid://3570695787" -- круг
    circle.ImageColor3 = C.accent
    circle.ImageTransparency = 0.3
    circle.ZIndex = 55
    circle.Parent = aimFrame
    -- Центральная точка
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(6, 6)
    dot.Position = UDim2.fromScale(0.5, 0.5)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = C.accent
    dot.BorderSizePixel = 0
    dot.ZIndex = 56
    dot.Parent = aimFrame
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    -- Кнопка выстрела
    fireBtn = Instance.new("TextButton")
    fireBtn.Name = "RM_Fire"
    fireBtn.Size = UDim2.fromOffset(80, 80)
    fireBtn.Position = UDim2.new(1, -100, 1, -140)
    fireBtn.BackgroundColor3 = C.danger
    fireBtn.BackgroundTransparency = 0.2
    fireBtn.Text = "🔥"
    fireBtn.TextColor3 = Color3.new(1,1,1)
    fireBtn.Font = Enum.Font.GothamBold
    fireBtn.TextSize = 40
    fireBtn.ZIndex = 55
    fireBtn.Parent = gui
    Instance.new("UICorner", fireBtn).CornerRadius = UDim.new(1, 0)
    local st = Instance.new("UIStroke", fireBtn)
    st.Color = C.accent
    st.Thickness = 3
    st.Transparency = 0.3

    -- Обработка прицела (перетаскивание)
    aimFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            aimActive = true
        end
    end)
    aimFrame.InputChanged:Connect(function(input)
        if aimActive and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local abs = gui.AbsoluteSize
            local newX = math.clamp(input.Position.X / abs.X, 0, 1)
            local newY = math.clamp(input.Position.Y / abs.Y, 0, 1)
            aimPos = Vector2.new(newX, newY)
            aimFrame.Position = UDim2.fromScale(newX, newY)
        end
    end)
    aimFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            aimActive = false
        end
    end)

    -- Выстрел
    fireBtn.MouseButton1Click:Connect(function()
        playSound("shoot", 0.5, 1)
        if RM.fireFromAim then
            pcall(RM.fireFromAim)
        end
        -- анимация кнопки
        fireBtn.Size = UDim2.fromOffset(70, 70)
        task.delay(0.1, function()
            if fireBtn then fireBtn.Size = UDim2.fromOffset(80, 80) end
        end)
    end)
end

-- Функция получения направления от прицела (если мобильный) или камеры
local Camera = Workspace.CurrentCamera
local function getAimDirection()
    if isMobile and aimFrame then
        -- Преобразуем позицию на экране в 3D-луч
        local vpSize = Camera.ViewportSize
        local screenPos = Vector2.new(aimPos.X * vpSize.X, aimPos.Y * vpSize.Y)
        local ray = Camera:ViewportPointToRay(screenPos.X, screenPos.Y)
        return ray.Direction, ray.Origin
    else
        return Camera.CFrame.LookVector, Camera.CFrame.Position
    end
end
RM.getAimDirection = getAimDirection

-- Вызов при создании UI
task.spawn(createAimUI)

-- Заглушка для стрельбы (будет переопределена в части 3)
RM.fireFromAim = function() end

notify("🌀 Rick & Morty v2.0 загружен", C.accent, 3)

warn("[RickMorty v2.0] Мобильный прицел: " .. (isMobile and "ВКЛ" or "ВЫКЛ"))
-- ============================================================
--  СКИНЫ: КАСТОМНЫЕ МОДЕЛИ
-- ============================================================

-- Хелпер для создания части
local function createPart(name, size, cf, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Color = color or Color3.fromRGB(255, 255, 255)
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = false
    p.CanCollide = false
    p.CastShadow = false
    p.CanQuery = false
    p.CanTouch = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    return p
end

-- Хелпер для приваривания части к корню
local function weldToRoot(part, root, offsetCF)
    part.CFrame = root.CFrame * offsetCF
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = part
    return part
end

-- ============================================================
--  ГЕНЕРАТОРЫ СКИНОВ (из частей)
-- ============================================================

local function buildRick(root, model)
    local C_SKIN = Color3.fromRGB(190, 210, 220)
    local C_HAIR = Color3.fromRGB(180, 210, 250)
    local C_COAT = Color3.fromRGB(245, 245, 250)
    local C_SHIRT = Color3.fromRGB(150, 220, 220)
    local C_PANTS = Color3.fromRGB(80, 75, 50)
    local C_SHOE = Color3.fromRGB(40, 40, 45)
    
    -- Торс (халат + рубашка)
    local torso = createPart("Torso", Vector3.new(2, 2, 1), CFrame.new(), C_COAT)
    torso.Parent = model
    weldToRoot(torso, root, CFrame.new(0, 0, 0))
    
    local shirt = createPart("Shirt", Vector3.new(1, 1.6, 1.05), CFrame.new(), C_SHIRT)
    shirt.Parent = model
    weldToRoot(shirt, root, CFrame.new(0, 0, 0))
    
    -- Голова
    local head = createPart("Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(), C_SKIN)
    head.Parent = model
    weldToRoot(head, root, CFrame.new(0, 1.75, 0))
    
    -- Глаза (простые)
    local eyeL = createPart("EyeL", Vector3.new(0.3, 0.3, 0.1), CFrame.new(), Color3.new(1,1,1))
    eyeL.Parent = model
    weldToRoot(eyeL, root, CFrame.new(-0.3, 1.85, -0.76))
    local pupilL = createPart("PupilL", Vector3.new(0.1, 0.1, 0.12), CFrame.new(), Color3.new(0,0,0))
    pupilL.Parent = model
    weldToRoot(pupilL, root, CFrame.new(-0.3, 1.85, -0.77))
    
    local eyeR = createPart("EyeR", Vector3.new(0.3, 0.3, 0.1), CFrame.new(), Color3.new(1,1,1))
    eyeR.Parent = model
    weldToRoot(eyeR, root, CFrame.new(0.3, 1.85, -0.76))
    local pupilR = createPart("PupilR", Vector3.new(0.1, 0.1, 0.12), CFrame.new(), Color3.new(0,0,0))
    pupilR.Parent = model
    weldToRoot(pupilR, root, CFrame.new(0.3, 1.85, -0.77))
    
    -- Брови (одна сплошная)
    local brow = createPart("Brow", Vector3.new(0.8, 0.1, 0.1), CFrame.new(), Color3.fromRGB(100, 180, 240))
    brow.Parent = model
    weldToRoot(brow, root, CFrame.new(0, 2.05, -0.76))
    
    -- Рот
    local mouth = createPart("Mouth", Vector3.new(0.4, 0.1, 0.1), CFrame.new(), Color3.fromRGB(50, 20, 20))
    mouth.Parent = model
    weldToRoot(mouth, root, CFrame.new(0, 1.55, -0.76))
    
    -- Волосы (шипы)
    local hairPositions = {
        Vector3.new(0, 2.65, 0), -- центр
        Vector3.new(-0.6, 2.5, 0), Vector3.new(0.6, 2.5, 0),
        Vector3.new(-0.8, 2.2, 0), Vector3.new(0.8, 2.2, 0),
        Vector3.new(-0.4, 2.6, 0), Vector3.new(0.4, 2.6, 0)
    }
    for i, pos in ipairs(hairPositions) do
        local spike = createPart("Hair", Vector3.new(0.3, 0.8, 0.3), CFrame.new(), C_HAIR)
        spike.Parent = model
        local cf = CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-20,20)), 0, math.rad(math.random(-20,20)))
        weldToRoot(spike, root, cf)
    end
    
    -- Руки
    local armL = createPart("ArmL", Vector3.new(1, 2, 1), CFrame.new(), C_COAT)
    armL.Parent = model
    weldToRoot(armL, root, CFrame.new(-1.5, 0, 0))
    local handL = createPart("HandL", Vector3.new(0.8, 0.5, 0.8), CFrame.new(), C_SKIN)
    handL.Parent = model
    weldToRoot(handL, root, CFrame.new(-1.5, -1.2, 0))
    
    local armR = createPart("ArmR", Vector3.new(1, 2, 1), CFrame.new(), C_COAT)
    armR.Parent = model
    weldToRoot(armR, root, CFrame.new(1.5, 0, 0))
    local handR = createPart("HandR", Vector3.new(0.8, 0.5, 0.8), CFrame.new(), C_SKIN)
    handR.Parent = model
    weldToRoot(handR, root, CFrame.new(1.5, -1.2, 0))
    
    -- Ноги
    local legL = createPart("LegL", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legL.Parent = model
    weldToRoot(legL, root, CFrame.new(-0.5, -2, 0))
    local shoeL = createPart("ShoeL", Vector3.new(1, 0.5, 1.2), CFrame.new(), C_SHOE)
    shoeL.Parent = model
    weldToRoot(shoeL, root, CFrame.new(-0.5, -3.2, -0.1))
    
    local legR = createPart("LegR", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legR.Parent = model
    weldToRoot(legR, root, CFrame.new(0.5, -2, 0))
    local shoeR = createPart("ShoeR", Vector3.new(1, 0.5, 1.2), CFrame.new(), C_SHOE)
    shoeR.Parent = model
    weldToRoot(shoeR, root, CFrame.new(0.5, -3.2, -0.1))
end

local function buildMorty(root, model)
    local C_SKIN = Color3.fromRGB(245, 210, 180)
    local C_HAIR = Color3.fromRGB(120, 80, 50)
    local C_SHIRT = Color3.fromRGB(245, 230, 100)
    local C_PANTS = Color3.fromRGB(60, 80, 140)
    local C_SHOE = Color3.fromRGB(245, 245, 245)
    
    local torso = createPart("Torso", Vector3.new(2, 2, 1), CFrame.new(), C_SHIRT)
    torso.Parent = model
    weldToRoot(torso, root, CFrame.new(0, 0, 0))
    
    local head = createPart("Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(), C_SKIN)
    head.Parent = model
    weldToRoot(head, root, CFrame.new(0, 1.75, 0))
    
    -- Глаза (большие)
    local eyeL = createPart("EyeL", Vector3.new(0.4, 0.4, 0.1), CFrame.new(), Color3.new(1,1,1))
    eyeL.Parent = model
    weldToRoot(eyeL, root, CFrame.new(-0.35, 1.85, -0.76))
    local pupilL = createPart("PupilL", Vector3.new(0.15, 0.15, 0.12), CFrame.new(), Color3.new(0,0,0))
    pupilL.Parent = model
    weldToRoot(pupilL, root, CFrame.new(-0.35, 1.85, -0.77))
    
    local eyeR = createPart("EyeR", Vector3.new(0.4, 0.4, 0.1), CFrame.new(), Color3.new(1,1,1))
    eyeR.Parent = model
    weldToRoot(eyeR, root, CFrame.new(0.35, 1.85, -0.76))
    local pupilR = createPart("PupilR", Vector3.new(0.15, 0.15, 0.12), CFrame.new(), Color3.new(0,0,0))
    pupilR.Parent = model
    weldToRoot(pupilR, root, CFrame.new(0.35, 1.85, -0.77))
    
    -- Волосы (шапка)
    local hair = createPart("Hair", Vector3.new(1.6, 0.6, 1.6), CFrame.new(), C_HAIR)
    hair.Parent = model
    weldToRoot(hair, root, CFrame.new(0, 2.4, 0.1))
    
    -- Руки (короткие рукава)
    local armL = createPart("ArmL", Vector3.new(1, 1, 1), CFrame.new(), C_SHIRT)
    armL.Parent = model
    weldToRoot(armL, root, CFrame.new(-1.5, 0.5, 0))
    local handL = createPart("HandL", Vector3.new(0.8, 1.5, 0.8), CFrame.new(), C_SKIN)
    handL.Parent = model
    weldToRoot(handL, root, CFrame.new(-1.5, -0.75, 0))
    
    local armR = createPart("ArmR", Vector3.new(1, 1, 1), CFrame.new(), C_SHIRT)
    armR.Parent = model
    weldToRoot(armR, root, CFrame.new(1.5, 0.5, 0))
    local handR = createPart("HandR", Vector3.new(0.8, 1.5, 0.8), CFrame.new(), C_SKIN)
    handR.Parent = model
    weldToRoot(handR, root, CFrame.new(1.5, -0.75, 0))
    
    -- Ноги
    local legL = createPart("LegL", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legL.Parent = model
    weldToRoot(legL, root, CFrame.new(-0.5, -2, 0))
    local shoeL = createPart("ShoeL", Vector3.new(1, 0.5, 1.2), CFrame.new(), C_SHOE)
    shoeL.Parent = model
    weldToRoot(shoeL, root, CFrame.new(-0.5, -3.2, -0.1))
    
    local legR = createPart("LegR", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legR.Parent = model
    weldToRoot(legR, root, CFrame.new(0.5, -2, 0))
    local shoeR = createPart("ShoeR", Vector3.new(1, 0.5, 1.2), CFrame.new(), C_SHOE)
    shoeR.Parent = model
    weldToRoot(shoeR, root, CFrame.new(0.5, -3.2, -0.1))
end

local function buildEvilMorty(root, model)
    -- База Морти
    buildMorty(root, model)
    -- Добавляем повязку
    local patch = createPart("EyePatch", Vector3.new(0.5, 0.5, 0.1), CFrame.new(), Color3.fromRGB(20, 20, 20))
    patch.Parent = model
    weldToRoot(patch, root, CFrame.new(-0.35, 1.85, -0.77))
    -- Ремешок
    local strap = createPart("Strap", Vector3.new(1.6, 0.1, 0.1), CFrame.new(), Color3.fromRGB(20, 20, 20))
    strap.Parent = model
    weldToRoot(strap, root, CFrame.new(0, 1.95, -0.76))
end

local function buildRickPrime(root, model)
    local C_SKIN = Color3.fromRGB(190, 210, 220)
    local C_HAIR = Color3.fromRGB(180, 210, 250)
    local C_COAT = Color3.fromRGB(40, 40, 50) -- Тёмный халат
    local C_SHIRT = Color3.fromRGB(180, 40, 40) -- Красная рубашка
    local C_PANTS = Color3.fromRGB(30, 30, 35)
    local C_SHOE = Color3.fromRGB(10, 10, 10)
    
    local torso = createPart("Torso", Vector3.new(2, 2, 1), CFrame.new(), C_COAT)
    torso.Parent = model
    weldToRoot(torso, root, CFrame.new(0, 0, 0))
    
    local shirt = createPart("Shirt", Vector3.new(1, 1.6, 1.05), CFrame.new(), C_SHIRT)
    shirt.Parent = model
    weldToRoot(shirt, root, CFrame.new(0, 0, 0))
    
    local head = createPart("Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(), C_SKIN)
    head.Parent = model
    weldToRoot(head, root, CFrame.new(0, 1.75, 0))
    
    -- Злые глаза
    local eyeL = createPart("EyeL", Vector3.new(0.3, 0.2, 0.1), CFrame.new(), Color3.new(1,1,1))
    eyeL.Parent = model
    weldToRoot(eyeL, root, CFrame.new(-0.3, 1.85, -0.76))
    
    local eyeR = createPart("EyeR", Vector3.new(0.3, 0.2, 0.1), CFrame.new(), Color3.new(1,1,1))
    eyeR.Parent = model
    weldToRoot(eyeR, root, CFrame.new(0.3, 1.85, -0.76))
    
    -- Волосы
    local hairPositions = {
        Vector3.new(0, 2.65, 0),
        Vector3.new(-0.6, 2.5, 0), Vector3.new(0.6, 2.5, 0),
        Vector3.new(-0.8, 2.2, 0), Vector3.new(0.8, 2.2, 0),
    }
    for i, pos in ipairs(hairPositions) do
        local spike = createPart("Hair", Vector3.new(0.3, 0.8, 0.3), CFrame.new(), C_HAIR)
        spike.Parent = model
        local cf = CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-20,20)), 0, math.rad(math.random(-20,20)))
        weldToRoot(spike, root, cf)
    end
    
    -- Руки
    local armL = createPart("ArmL", Vector3.new(1, 2, 1), CFrame.new(), C_COAT)
    armL.Parent = model
    weldToRoot(armL, root, CFrame.new(-1.5, 0, 0))
    local handL = createPart("HandL", Vector3.new(0.8, 0.5, 0.8), CFrame.new(), C_SKIN)
    handL.Parent = model
    weldToRoot(handL, root, CFrame.new(-1.5, -1.2, 0))
    
    local armR = createPart("ArmR", Vector3.new(1, 2, 1), CFrame.new(), C_COAT)
    armR.Parent = model
    weldToRoot(armR, root, CFrame.new(1.5, 0, 0))
    local handR = createPart("HandR", Vector3.new(0.8, 0.5, 0.8), CFrame.new(), C_SKIN)
    handR.Parent = model
    weldToRoot(handR, root, CFrame.new(1.5, -1.2, 0))
    
    -- Ноги
    local legL = createPart("LegL", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legL.Parent = model
    weldToRoot(legL, root, CFrame.new(-0.5, -2, 0))
    local shoeL = createPart("ShoeL", Vector3.new(1, 0.5, 1.2), CFrame.new(), C_SHOE)
    shoeL.Parent = model
    weldToRoot(shoeL, root, CFrame.new(-0.5, -3.2, -0.1))
    
    local legR = createPart("LegR", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legR.Parent = model
    weldToRoot(legR, root, CFrame.new(0.5, -2, 0))
    local shoeR = createPart("ShoeR", Vector3.new(1, 0.5, 1.2), CFrame.new(), C_SHOE)
    shoeR.Parent = model
    weldToRoot(shoeR, root, CFrame.new(0.5, -3.2, -0.1))
end

-- ============================================================
--  ПРИМЕНЕНИЕ И СНЯТИЕ СКИНА
-- ============================================================
local currentSkinModel = nil
local savedCharacterParts = {} -- сохраняем оригинальные части и их прозрачность

local function clearCurrentSkin()
    if currentSkinModel then
        pcall(function() currentSkinModel:Destroy() end)
        currentSkinModel = nil
    end
    -- Восстанавливаем прозрачность
    for part, origTransparency in pairs(savedCharacterParts) do
        if part and part.Parent then
            part.Transparency = origTransparency
        end
    end
    savedCharacterParts = {}
end

local function applySkin(skinId)
    local char = LocalPlayer.Character
    if not char then notify("Нет персонажа", C.danger); return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then notify("Нет HumanoidRootPart", C.danger); return end
    
    -- Очищаем предыдущий
    clearCurrentSkin()
    
    -- Скрываем стандартное тело (кроме HRP, чтобы камера не глючила)
    savedCharacterParts = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d ~= root then
            savedCharacterParts[d] = d.Transparency
            d.Transparency = 1
        end
    end
    
    -- Создаём модель скина
    local model = Instance.new("Model")
    model.Name = "RM_Skin_" .. skinId
    model.Parent = char
    
    if skinId == "rick" then
        buildRick(root, model)
    elseif skinId == "morty" then
        buildMorty(root, model)
    elseif skinId == "evil_morty" then
        buildEvilMorty(root, model)
    elseif skinId == "rick_prime" then
        buildRickPrime(root, model)
    end
    
    currentSkinModel = model
    RM.SETTINGS.ActiveSkin = skinId
    saveSettings()
    notify("🎭 Скин надет: " .. skinId, C.accent, 2)
end

local function removeSkin()
    clearCurrentSkin()
    RM.SETTINGS.ActiveSkin = nil
    saveSettings()
    notify("🎭 Скин снят", C.text, 2)
end

-- Обновление при респавне
track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if RM.SETTINGS.ActiveSkin then
        applySkin(RM.SETTINGS.ActiveSkin)
    end
end))

-- ============================================================
--  UI: ВКЛАДКА «СКИНЫ»
-- ============================================================
do
    local frame = tabFrames["skins"]
    newSection(frame, "ЗАМЕНА ТЕЛА")
    
    local SKINS = {
        { id = "rick", name = "🧪 Рик Санчес", desc = "Халат, синие волосы" },
        { id = "morty", name = "😰 Морти Смит", desc = "Жёлтая футболка" },
        { id = "evil_morty", name = "🖤 Злой Морти", desc = "С повязкой на глазу" },
        { id = "rick_prime", name = "💀 Рик Прайм", desc = "Тёмный халат, красная рубашка" },
    }
    
    for _, s in ipairs(SKINS) do
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
    local resetBtn = newButton(frame, "↩ Вернуть своё тело", C.bg2, nil, 34)
    resetBtn.TextColor3 = C.danger
    resetBtn.MouseButton1Click:Connect(removeSkin)
end

-- Восстанавливаем скин из сохранения при загрузке
if RM.SETTINGS.ActiveSkin then
    task.spawn(function()
        task.wait(2)
        applySkin(RM.SETTINGS.ActiveSkin)
    end)
end

-- Восстанавливаем прозрачность при выгрузке
RM._cleanup = RM._cleanup or {}
RM._cleanup[#RM._cleanup + 1] = function()
    clearCurrentSkin()
end
-- ============================================================
--  ПОРТАЛЬНАЯ ПУШКА (МОДЕЛЬ В РУКЕ)
-- ============================================================
local activePortalGun = nil

local function buildPortalGun()
    local tool = Instance.new("Tool")
    tool.Name = "Portal Gun"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ToolTip = "ЛКМ / кнопка 🔥 — открыть портал"
    tool.GripForward = Vector3.new(0, 0, -1)
    tool.GripRight = Vector3.new(1, 0, 0)
    tool.GripUp = Vector3.new(0, 1, 0)

    -- Ручка
    local handle = createPart("Handle", Vector3.new(0.4, 1.2, 0.4), CFrame.new(), Color3.fromRGB(60, 60, 65))
    handle.Parent = tool
    
    -- Тело пушки
    local body = createPart("Body", Vector3.new(0.8, 0.8, 1.6), CFrame.new(), Color3.fromRGB(220, 220, 225))
    body.Parent = tool
    local w1 = Instance.new("WeldConstraint"); w1.Part0 = handle; w1.Part1 = body; w1.Parent = body
    body.CFrame = handle.CFrame * CFrame.new(0, 0.6, -0.4)
    
    -- Зелёная колба (стекло)
    local orb = createPart("Orb", Vector3.new(0.5, 0.7, 0.5), CFrame.new(), Color3.fromRGB(50, 255, 50), Enum.Material.Glass)
    orb.Transparency = 0.2
    orb.Parent = tool
    local w2 = Instance.new("WeldConstraint"); w2.Part0 = body; w2.Part1 = orb; w2.Parent = orb
    orb.CFrame = body.CFrame * CFrame.new(0, 0.5, -0.2)
    
    local orbLight = Instance.new("PointLight", orb)
    orbLight.Color = Color3.fromRGB(50, 255, 50)
    orbLight.Range = 6
    orbLight.Brightness = 2
    orbLight.Shadows = false
    
    -- Экранчик (красный)
    local screen = createPart("Screen", Vector3.new(0.4, 0.2, 0.05), CFrame.new(), Color3.fromRGB(200, 30, 30))
    screen.Material = Enum.Material.Neon
    screen.Parent = tool
    local w3 = Instance.new("WeldConstraint"); w3.Part0 = body; w3.Part1 = screen; w3.Parent = screen
    screen.CFrame = body.CFrame * CFrame.new(0, 0.1, 0.81)
    
    tool.Parent = LocalPlayer.Backpack
    return tool
end

local function equipPortalGun()
    if activePortalGun and activePortalGun.Parent then
        pcall(function() activePortalGun:Destroy() end)
    end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    activePortalGun = buildPortalGun()
    if hum:FindFirstChild("RightHand") or hum:FindFirstChild("Right Arm") then
        hum:EquipTool(activePortalGun)
    end
    notify("🌀 Портальная пушка экипирована", C.accent, 2)
end

-- ============================================================
--  ЗЕЛЁНЫЙ СПИРАЛЬНЫЙ ПОРТАЛ
-- ============================================================
local currentPortal = nil
local portalSpinnerConn = nil

local function createPortal(position, normal)
    if currentPortal then
        pcall(function() currentPortal:Destroy() end)
        if portalSpinnerConn then
            pcall(function() portalSpinnerConn:Disconnect() end)
            portalSpinnerConn = nil
        end
    end
    
    local c = RM.SETTINGS.PortalColor
    local pColor = Color3.fromRGB(c.R, c.G, c.B)
    
    local model = Instance.new("Model")
    model.Name = "RM_Portal"
    model.Parent = Workspace
    
    local center = CFrame.new(position, position + normal)
    
    -- Внешнее кольцо
    local ring1 = createPart("Ring1", Vector3.new(0.2, 8, 8), center, pColor, Enum.Material.Neon)
    ring1.Shape = Enum.PartType.Cylinder
    ring1.Transparency = 0.2
    ring1.CFrame = center * CFrame.Angles(0, math.rad(90), 0)
    ring1.Parent = model
    
    -- Внутреннее кольцо (меньше)
    local ring2 = createPart("Ring2", Vector3.new(0.2, 6, 6), center, pColor, Enum.Material.Neon)
    ring2.Shape = Enum.PartType.Cylinder
    ring2.Transparency = 0.5
    ring2.CFrame = center * CFrame.Angles(0, math.rad(90), 0)
    ring2.Parent = model
    
    -- Ядро (светящаяся сфера)
    local core = createPart("Core", Vector3.new(5, 5, 5), center, Color3.fromRGB(150, 255, 150), Enum.Material.Neon)
    core.Shape = Enum.PartType.Ball
    core.Transparency = 0.6
    core.Parent = model
    
    -- Частицы
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 50
    pe.Lifetime = NumberRange.new(0.5, 1.5)
    pe.Speed = NumberRange.new(2, 5)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
    pe.Color = ColorSequence.new(pColor)
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = core
    
    local light = Instance.new("PointLight", core)
    light.Color = pColor
    light.Range = 15
    light.Brightness = 3
    light.Shadows = false
    
    -- Анимация вращения
    local angle = 0
    portalSpinnerConn = RunService.Heartbeat:Connect(function(dt)
        angle = angle + dt * 2
        ring1.CFrame = center * CFrame.Angles(math.rad(angle), math.rad(90), 0)
        ring2.CFrame = center * CFrame.Angles(math.rad(-angle*1.5), math.rad(90), 0)
    end)
    
    currentPortal = model
    playSound("portal", 0.8, 0.8)
    
    task.delay(10, function()
        if currentPortal == model then
            if portalSpinnerConn then portalSpinnerConn:Disconnect(); portalSpinnerConn = nil end
            model:Destroy()
            currentPortal = nil
        end
    end)
end

-- ============================================================
--  СТРЕЛЬБА ИЗ ПУШКИ
-- ============================================================
local function shootPortal()
    local dir, origin = RM.getAimDirection()
    if not dir or not origin then return end
    
    -- Если стоим вплотную к стене, смещаем origin вперед
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        origin = hrp.Position + dir * 2
    end
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {char, currentPortal}
    
    local result = Workspace:Raycast(origin, dir * 500, raycastParams)
    
    local spawnPos, spawnNormal
    if result then
        spawnPos = result.Position
        spawnNormal = result.Normal
    else
        spawnPos = origin + dir * 50
        spawnNormal = -dir
    end
    
    createPortal(spawnPos, spawnNormal)
    
    -- Визуальный луч от пушки к порталу (если пушка в руках)
    if activePortalGun and char then
        local handle = activePortalGun:FindFirstChild("Handle")
        if handle then
            local beamPart = createPart("BeamFx", Vector3.new(0.2, 0.2, (spawnPos - handle.Position).Magnitude), CFrame.new(handle.Position, spawnPos) * CFrame.new(0, 0, -(spawnPos - handle.Position).Magnitude/2), Color3.fromRGB(50, 255, 50), Enum.Material.Neon)
            beamPart.Parent = Workspace
            task.delay(0.15, function() pcall(function() beamPart:Destroy() end) end)
        end
    end
end

-- Переопределяем функцию стрельбы из части 1 (привязка к кнопке 🔥)
RM.fireFromAim = shootPortal

-- ============================================================
--  UI: ВКЛАДКА «ПОРТАЛ»
-- ============================================================
do
    local frame = tabFrames["portal"]
    newSection(frame, "ПОРТАЛЬНАЯ ПУШКА")
    
    local equipBtn = newButton(frame, "🌀 Экипировать пушку", C.accent, nil, 40)
    equipBtn.MouseButton1Click:Connect(equipPortalGun)
    
    local shootBtn = newButton(frame, "🔥 Выстрелить (ПКМ)", C.bg2, nil, 40)
    shootBtn.MouseButton1Click:Connect(shootPortal)
    
    newSection(frame, "УПРАВЛЕНИЕ")
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -8, 0, 60)
    info.BackgroundColor3 = C.bg2
    info.BackgroundTransparency = 0.2
    info.Text = "\n  ПК: ЛКМ по экрану или кнопка «Выстрелить»\n  Мобилка: двигай прицел пальцем, жми 🔥\n  Пушка стреляет туда, куда смотрит камера/прицел."
    info.TextColor3 = C.textDim
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextWrapped = true
    info.Parent = frame
    Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)
end

-- ============================================================
--  СТРЕЛЬБА ЧЕРЕЗ ИНСТРУМЕНТ (Tool.Activated)
-- ============================================================
local function onToolActivated()
    shootPortal()
end

-- Следим за экипировкой пушки, чтобы повесить Activated
track(LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if activePortalGun then
        equipPortalGun()
    end
end))

local function bindToolActivated()
    if activePortalGun then
        pcall(function()
            activePortalGun.Activated:Connect(onToolActivated)
        end)
    end
end

-- Переопределим equipPortalGun, чтобы сразу вешать Activated
local oldEquip = equipPortalGun
equipPortalGun = function()
    oldEquip()
    bindToolActivated()
end

-- ============================================================
--  UI: ВКЛАДКА «НАСТРОЙКИ»
-- ============================================================
do
    local frame = tabFrames["settings"]
    
    newSection(frame, "ЗВУК")
    local soundBtn = newButton(frame, "🔊 Звуки: " .. (RM.SETTINGS.SoundEnabled and "ВКЛ" or "ВЫКЛ"), C.bg2, nil, 32)
    soundBtn.MouseButton1Click:Connect(function()
        RM.SETTINGS.SoundEnabled = not RM.SETTINGS.SoundEnabled
        soundBtn.Text = "🔊 Звуки: " .. (RM.SETTINGS.SoundEnabled and "ВКЛ" or "ВЫКЛ")
        saveSettings()
    end)
    
    newSection(frame, "ЦВЕТ ПОРТАЛА")
    local PORTAL_COLORS = {
        { name = "🟢 Зелёный", c = { R = 50, G = 255, B = 50 } },
        { name = "🔵 Синий",   c = { R = 50, G = 150, B = 255 } },
        { name = "🟣 Фиолет",  c = { R = 180, G = 50, B = 255 } },
        { name = "🟡 Жёлтый",  c = { R = 255, G = 220, B = 50 } },
    }
    local pIdx = 1
    for i, p in ipairs(PORTAL_COLORS) do
        if p.c.R == RM.SETTINGS.PortalColor.R and p.c.G == RM.SETTINGS.PortalColor.G then pIdx = i; break end
    end
    local pBtn = newButton(frame, "🎨 " .. PORTAL_COLORS[pIdx].name, C.bg2, nil, 32)
    pBtn.MouseButton1Click:Connect(function()
        pIdx = pIdx % #PORTAL_COLORS + 1
        RM.SETTINGS.PortalColor = PORTAL_COLORS[pIdx].c
        pBtn.Text = "🎨 " .. PORTAL_COLORS[pIdx].name
        saveSettings()
    end)
    
    newSection(frame, "ИНТЕРФЕЙС")
    local resetBtn = newButton(frame, "🔄 Сбросить всё", C.danger, nil, 34)
    resetBtn.MouseButton1Click:Connect(function()
        RM.SETTINGS.SoundEnabled = true
        RM.SETTINGS.NotificationsEnabled = true
        RM.SETTINGS.PortalColor = { R = 50, G = 255, B = 50 }
        RM.SETTINGS.ActiveSkin = nil
        saveSettings()
        removeSkin()
        soundBtn.Text = "🔊 Звуки: ВКЛ"
        pBtn.Text = "🎨 " .. PORTAL_COLORS[1].name
        notify("🔄 Настройки сброшены", C.success, 2)
    end)
    
    newSection(frame, "ВЫХОД")
    local unloadBtn = newButton(frame, "❌ ВЫГРУЗИТЬ СКРИПТ", C.danger, nil, 36)
    unloadBtn.MouseButton1Click:Connect(function()
        RM.unload()
    end)
    
    newSection(frame, "О СКРИПТЕ")
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -8, 0, 70)
    info.BackgroundColor3 = C.bg2
    info.BackgroundTransparency = 0.2
    info.Text = "\n  Rick & Morty Toolkit v" .. RM._version .. "\n  Скины: 4  |  Пушка: 1  |  Портал: 1\n  Всё локально, без серверного урона.\n  Без 18+ контента."
    info.TextColor3 = C.textDim
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextWrapped = true
    info.Parent = frame
    Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)
end

-- ============================================================
--  ФИНАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ И UNLOAD
-- ============================================================
switchTab("skins")

-- Функция очистки всего
function RM.unload()
    alive = false
    GENV._RM_BUSY = nil
    
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    conns = {}
    
    -- Чистим эффекты/модели
    for _, fn in ipairs(RM._cleanup or {}) do pcall(fn) end
    
    if activePortalGun then pcall(function() activePortalGun:Destroy() end) end
    if currentPortal then pcall(function() currentPortal:Destroy() end) end
    if portalSpinnerConn then pcall(function() portalSpinnerConn:Disconnect() end) end
    if sfxFolder then pcall(function() sfxFolder:Destroy() end) end
    
    -- Восстанавливаем тело (скин)
    clearCurrentSkin()
    
    -- Удаляем GUI
    if gui then
        local gname = gui.Name
        if gui.Parent and gui.Parent:FindFirstChild(gname) then
            gui.Parent:FindFirstChild(gname):Destroy()
        end
        if PlayerGui and PlayerGui:FindFirstChild(gname) then
            PlayerGui:FindFirstChild(gname):Destroy()
        end
    end
    
    GENV.RickMorty = nil
    warn("[RickMorty] Скрипт выгружен")
end

-- Финальный лог
warn(string.format("[RickMorty v%s] Загружен. Скины: 4. Пушка и портал готовы. Мобильный прицел: %s", RM._version, isMobile and "ВКЛ" or "ВЫКЛ"))
notify("🌀 Rick & Morty v" .. RM._version .. " загружен", C.accent, 4)

GENV._RM_BUSY = nil

return RM
