-- Rick & Morty Toolkit v2.3 (standalone)
-- Скины, портальная пушка (2 портала), продвинутый прицел, перетаскиваемый UI.
-- Без 18+ контента.

local GENV = rawget(_G, "getgenv") and getgenv() or _G
local RM = {}
GENV.RickMorty = RM
RM._version = "2.3"

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
local Camera       = Workspace.CurrentCamera

RM.Players = Players
RM.RunService = RunService
RM.TweenService = TweenService
RM.UIS = UIS
RM.Workspace = Workspace
RM.LocalPlayer = LocalPlayer
RM.HAS_FS = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")
RM.SAVE_FILE = "rickmorty_v23.json"

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
    PortalColor = { R = 50, G = 255, B = 50 },
    ActiveSkin = nil,
    AimSize = 64,
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
    shoot  = "rbxassetid://12221967",
    click  = "rbxasset://sounds/button.wav",
    notify = "rbxasset://sounds/electronicpingshort.wav",
    teleport = "rbxassetid://3314038600",
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

-- Стиль
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

-- Функция перетаскивания
local function makeDraggable(frame, dragArea)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local dragTarget = dragArea or frame

    dragTarget.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragTarget.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

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
makeDraggable(mainBtn)
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
local WINDOW_W, WINDOW_H = 380, 520
local window = Instance.new("Frame")
window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
window.Position = UDim2.fromOffset(90, 70)
window.BackgroundColor3 = C.bg
window.BackgroundTransparency = 0.02
window.Visible = false
window.ZIndex = 40
window.Parent = gui
makeDraggable(window)
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
title.Text = "🌀 RICK & MORTY v2.3"
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
footer.Text = "v" .. RM._version .. " | 2 портала | продвинутый прицел"
footer.TextColor3 = C.textDim
footer.Font = Enum.Font.Code
footer.TextSize = 9
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = window

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

local TABS = {
    { id = "skins",    label = "🎭 СКИНЫ",   color = C.accent },
    { id = "portal",   label = "🌀 ПОРТАЛ",  color = C.accent3 },
    { id = "settings", label = "⚙️",         color = C.textDim },
}
local tabButtons = {}
local tabFrames = {}

local function switchTab(id)
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

mainBtn.MouseButton1Click:Connect(function()
    window.Visible = not window.Visible
end)

track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if tostring(input.KeyCode):find(RM.SETTINGS.MenuKey) then
        window.Visible = not window.Visible
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
--  ПРОДВИНУТЫЙ ПРИЦЕЛ (УЛУЧШЕННЫЙ)
-- ============================================================
local isMobile = UIS.TouchEnabled and not UIS.MouseEnabled
local aiming = true
local crossPos = nil
local aimFrame = nil
local aimLabel = nil
local fireBtn = nil

local function createAimUI()
    local size = RM.SETTINGS.AimSize
    
    aimFrame = Instance.new("Frame")
    aimFrame.Name = "RM_Aim"
    aimFrame.Size = UDim2.fromOffset(size, size)
    aimFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    aimFrame.Position = UDim2.fromScale(0.5, 0.5)
    aimFrame.BackgroundTransparency = 1
    aimFrame.Visible = aiming
    aimFrame.Active = true
    aimFrame.ZIndex = 55
    aimFrame.Parent = gui

    local circle = Instance.new("Frame")
    circle.Size = UDim2.fromScale(0.8, 0.8)
    circle.Position = UDim2.fromScale(0.5, 0.5)
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1
    circle.ZIndex = 55
    circle.Parent = aimFrame
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    local cStroke = Instance.new("UIStroke", circle)
    cStroke.Color = Color3.fromRGB(100, 255, 140)
    cStroke.Thickness = 1.5
    cStroke.Transparency = 0.5

    local color = Color3.fromRGB(100, 255, 140)

    local function makeLine(x, y, w, h)
        local f = Instance.new("Frame")
        f.Position = UDim2.fromOffset(x, y)
        f.Size = UDim2.fromOffset(w, h)
        f.BackgroundColor3 = color
        f.BorderSizePixel = 0
        f.ZIndex = 56
        f.Parent = aimFrame
        return f
    end
    
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(4, 4)
    dot.Position = UDim2.fromScale(0.5, 0.5)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.ZIndex = 57
    dot.Parent = aimFrame
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local half = size / 2
    local gap = 8
    local len = 12
    local t = 2
    makeLine(half - t/2, half - gap - len, t, len)
    makeLine(half - t/2, half + gap, t, len)
    makeLine(half - gap - len, half - t/2, len, t)
    makeLine(half + gap, half - t/2, len, t)

    aimLabel = Instance.new("TextLabel")
    aimLabel.Size = UDim2.new(0, 150, 0, 20)
    aimLabel.Position = UDim2.fromScale(0.5, 1.3)
    aimLabel.AnchorPoint = Vector2.new(0.5, 0)
    aimLabel.BackgroundTransparency = 1
    aimLabel.TextColor3 = color
    aimLabel.Font = Enum.Font.Code
    aimLabel.TextSize = 12
    aimLabel.Text = "0 st"
    aimLabel.ZIndex = 57
    aimLabel.Parent = aimFrame

    local draggingAim = false
    aimFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingAim = true
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if draggingAim and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local sp = input.Position
            aimFrame.Position = UDim2.fromOffset(sp.X, sp.Y)
            crossPos = sp
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingAim = false
        end
    end)

    if isMobile then
        fireBtn = Instance.new("TextButton")
        fireBtn.Name = "RM_Fire"
        fireBtn.Size = UDim2.fromOffset(70, 70)
        fireBtn.Position = UDim2.new(1, -90, 1, -130)
        fireBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
        fireBtn.BackgroundTransparency = 0.2
        fireBtn.Text = "🔥"
        fireBtn.TextColor3 = Color3.new(1, 1, 1)
        fireBtn.Font = Enum.Font.GothamBold
        fireBtn.TextSize = 35
        fireBtn.ZIndex = 55
        fireBtn.Parent = gui
        Instance.new("UICorner", fireBtn).CornerRadius = UDim.new(1, 0)
        local st = Instance.new("UIStroke", fireBtn)
        st.Color = color; st.Thickness = 2; st.Transparency = 0.3
        makeDraggable(fireBtn)

        fireBtn.MouseButton1Click:Connect(function()
            playSound("shoot", 0.5, 1)
            if RM.fireFromAim then pcall(RM.fireFromAim) end
            fireBtn.Size = UDim2.fromOffset(60, 60)
            task.delay(0.1, function()
                if fireBtn then fireBtn.Size = UDim2.fromOffset(70, 70) end
            end)
        end)
    end
end

local function screenPoint()
    if isMobile then
        if crossPos then return crossPos end
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        return UIS:GetMouseLocation()
    end
end

local function getAimDirection()
    local sp = screenPoint()
    local ray = Camera:ViewportPointToRay(sp.X, sp.Y)
    return ray.Direction, ray.Origin
end
RM.getAimDirection = getAimDirection

local function aimPoint(origin)
    local sp = screenPoint()
    local ray = Camera:ViewportPointToRay(sp.X, sp.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    if result then return result.Position end
    return ray.Origin + ray.Direction * 1000
end
RM.aimPoint = aimPoint

task.spawn(function()
    while alive do
        task.wait(0.05)
        if aiming and aimFrame then
            local sp = screenPoint()
            if isMobile then
                aimFrame.Position = UDim2.fromOffset(sp.X, sp.Y)
            else
                aimFrame.Position = UDim2.fromOffset(sp.X, sp.Y)
            end
            
            if aimLabel then
                local origin = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if origin then
                    local sp = screenPoint()
                    local ray = Camera:ViewportPointToRay(sp.X, sp.Y)
                    local rParams = RaycastParams.new()
                    rParams.FilterType = Enum.RaycastFilterType.Exclude
                    rParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    local res = Workspace:Raycast(ray.Origin, ray.Direction * 1000, rParams)
                    local targetPos = res and res.Position or (ray.Origin + ray.Direction * 1000)
                    local dist = (targetPos - origin.Position).Magnitude
                    aimLabel.Text = math.floor(dist) .. " st"

                    local isTargetingPlayer = false
                    if res and res.Instance then
                        local parentModel = res.Instance:FindFirstAncestorOfClass("Model")
                        if parentModel and Players:GetPlayerFromCharacter(parentModel) then
                            isTargetingPlayer = true
                        end
                    end
                    
                    local targetColor = isTargetingPlayer and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(100, 255, 140)
                    aimLabel.TextColor3 = targetColor
                    for _, child in ipairs(aimFrame:GetDescendants()) do
                        if child:IsA("Frame") and child.BackgroundColor3 then
                            child.BackgroundColor3 = targetColor
                        elseif child:IsA("UIStroke") then
                            child.Color = targetColor
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(createAimUI)
RM.fireFromAim = function() end
-- ============================================================
--  ХЕЛПЕРЫ ДЛЯ СКИНОВ
-- ============================================================
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

local function weldToRoot(part, root, offsetCF)
    part.CFrame = root.CFrame * offsetCF
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = part
    return part
end

local function addHairSpikes(root, model, color)
    local spikes = {
        { pos = Vector3.new(0, 3.1, 0.1), rot = Vector3.new(0, 0, 0), size = Vector3.new(0.35, 1.0, 0.35) },
        { pos = Vector3.new(-0.5, 2.9, 0.1), rot = Vector3.new(0, 0, -15), size = Vector3.new(0.3, 0.9, 0.3) },
        { pos = Vector3.new(0.5, 2.9, 0.1), rot = Vector3.new(0, 0, 15), size = Vector3.new(0.3, 0.9, 0.3) },
        { pos = Vector3.new(-0.9, 2.6, 0.1), rot = Vector3.new(0, 0, -30), size = Vector3.new(0.25, 0.8, 0.25) },
        { pos = Vector3.new(0.9, 2.6, 0.1), rot = Vector3.new(0, 0, 30), size = Vector3.new(0.25, 0.8, 0.25) },
        { pos = Vector3.new(-0.6, 2.7, 0.5), rot = Vector3.new(20, 0, -15), size = Vector3.new(0.25, 0.7, 0.25) },
        { pos = Vector3.new(0.6, 2.7, 0.5), rot = Vector3.new(20, 0, 15), size = Vector3.new(0.25, 0.7, 0.25) },
        { pos = Vector3.new(-0.3, 2.7, -0.4), rot = Vector3.new(-25, 0, -20), size = Vector3.new(0.25, 0.7, 0.25) },
        { pos = Vector3.new(0.3, 2.7, -0.4), rot = Vector3.new(-25, 0, 20), size = Vector3.new(0.25, 0.7, 0.25) },
    }
    for _, s in ipairs(spikes) do
        local spike = createPart("Hair", s.size, CFrame.new(), color, Enum.Material.SmoothPlastic)
        spike.Parent = model
        local rot = CFrame.Angles(math.rad(s.rot.X), math.rad(s.rot.Y), math.rad(s.rot.Z))
        weldToRoot(spike, root, CFrame.new(s.pos) * rot)
    end
end

local function buildRick(root, model)
    local C_SKIN = Color3.fromRGB(190, 210, 220)
    local C_HAIR = Color3.fromRGB(180, 210, 250)
    local C_COAT = Color3.fromRGB(245, 245, 250)
    local C_SHIRT = Color3.fromRGB(150, 220, 220)
    local C_PANTS = Color3.fromRGB(80, 75, 50)
    local C_SHOE = Color3.fromRGB(40, 40, 45)
    local C_EYE_W = Color3.fromRGB(255, 255, 255)
    local C_EYE_B = Color3.fromRGB(0, 0, 0)

    local torso = createPart("Torso", Vector3.new(2, 2, 1), CFrame.new(), C_SHIRT)
    torso.Parent = model
    weldToRoot(torso, root, CFrame.new(0, 0, 0))

    local coatBack = createPart("CoatBack", Vector3.new(2.2, 2.2, 0.2), CFrame.new(), C_COAT)
    coatBack.Parent = model
    weldToRoot(coatBack, root, CFrame.new(0, 0, 0.55))

    local coatL = createPart("CoatL", Vector3.new(0.2, 2.2, 1.2), CFrame.new(), C_COAT)
    coatL.Parent = model
    weldToRoot(coatL, root, CFrame.new(-1.05, 0, 0))

    local coatR = createPart("CoatR", Vector3.new(0.2, 2.2, 1.2), CFrame.new(), C_COAT)
    coatR.Parent = model
    weldToRoot(coatR, root, CFrame.new(1.05, 0, 0))

    local coatTail = createPart("CoatTail", Vector3.new(2.2, 1.6, 0.2), CFrame.new(), C_COAT)
    coatTail.Parent = model
    weldToRoot(coatTail, root, CFrame.new(0, -1.8, 0.55))

    local head = createPart("Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(), C_SKIN)
    head.Parent = model
    weldToRoot(head, root, CFrame.new(0, 1.75, 0))

    local eyeL = createPart("EyeL", Vector3.new(0.45, 0.45, 0.1), CFrame.new(), C_EYE_W)
    eyeL.Parent = model
    weldToRoot(eyeL, root, CFrame.new(-0.32, 1.85, -0.76))
    local pupilL = createPart("PupilL", Vector3.new(0.12, 0.12, 0.12), CFrame.new(), C_EYE_B)
    pupilL.Parent = model
    weldToRoot(pupilL, root, CFrame.new(-0.32, 1.85, -0.77))

    local eyeR = createPart("EyeR", Vector3.new(0.45, 0.45, 0.1), CFrame.new(), C_EYE_W)
    eyeR.Parent = model
    weldToRoot(eyeR, root, CFrame.new(0.32, 1.85, -0.76))
    local pupilR = createPart("PupilR", Vector3.new(0.12, 0.12, 0.12), CFrame.new(), C_EYE_B)
    pupilR.Parent = model
    weldToRoot(pupilR, root, CFrame.new(0.32, 1.85, -0.77))

    local brow = createPart("Brow", Vector3.new(0.9, 0.12, 0.12), CFrame.new(), C_HAIR)
    brow.Parent = model
    weldToRoot(brow, root, CFrame.new(0, 2.15, -0.76))

    local mouth = createPart("Mouth", Vector3.new(0.5, 0.08, 0.1), CFrame.new(), Color3.fromRGB(100, 30, 30))
    mouth.Parent = model
    weldToRoot(mouth, root, CFrame.new(0, 1.55, -0.76))

    addHairSpikes(root, model, C_HAIR)

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

    local legL = createPart("LegL", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legL.Parent = model
    weldToRoot(legL, root, CFrame.new(-0.5, -2, 0))
    local shoeL = createPart("ShoeL", Vector3.new(1, 0.5, 1.3), CFrame.new(), C_SHOE)
    shoeL.Parent = model
    weldToRoot(shoeL, root, CFrame.new(-0.5, -3.2, -0.15))

    local legR = createPart("LegR", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legR.Parent = model
    weldToRoot(legR, root, CFrame.new(0.5, -2, 0))
    local shoeR = createPart("ShoeR", Vector3.new(1, 0.5, 1.3), CFrame.new(), C_SHOE)
    shoeR.Parent = model
    weldToRoot(shoeR, root, CFrame.new(0.5, -3.2, -0.15))
end

local function buildMorty(root, model)
    local C_SKIN = Color3.fromRGB(245, 210, 180)
    local C_HAIR = Color3.fromRGB(130, 90, 60)
    local C_SHIRT = Color3.fromRGB(245, 230, 100)
    local C_PANTS = Color3.fromRGB(60, 80, 140)
    local C_SHOE = Color3.fromRGB(245, 245, 245)
    local C_EYE_W = Color3.fromRGB(255, 255, 255)
    local C_EYE_B = Color3.fromRGB(0, 0, 0)

    local torso = createPart("Torso", Vector3.new(2, 2, 1), CFrame.new(), C_SHIRT)
    torso.Parent = model
    weldToRoot(torso, root, CFrame.new(0, 0, 0))

    local head = createPart("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(), C_SKIN)
    head.Parent = model
    weldToRoot(head, root, CFrame.new(0, 1.8, 0))

    local eyeL = createPart("EyeL", Vector3.new(0.5, 0.6, 0.1), CFrame.new(), C_EYE_W)
    eyeL.Parent = model
    weldToRoot(eyeL, root, CFrame.new(-0.38, 1.9, -0.81))
    local pupilL = createPart("PupilL", Vector3.new(0.15, 0.15, 0.12), CFrame.new(), C_EYE_B)
    pupilL.Parent = model
    weldToRoot(pupilL, root, CFrame.new(-0.38, 1.9, -0.82))

    local eyeR = createPart("EyeR", Vector3.new(0.5, 0.6, 0.1), CFrame.new(), C_EYE_W)
    eyeR.Parent = model
    weldToRoot(eyeR, root, CFrame.new(0.38, 1.9, -0.81))
    local pupilR = createPart("PupilR", Vector3.new(0.15, 0.15, 0.12), CFrame.new(), C_EYE_B)
    pupilR.Parent = model
    weldToRoot(pupilR, root, CFrame.new(0.38, 1.9, -0.82))

    local hair = createPart("Hair", Vector3.new(1.7, 0.7, 1.7), CFrame.new(), C_HAIR)
    hair.Parent = model
    weldToRoot(hair, root, CFrame.new(0, 2.45, 0.1))

    local nose = createPart("Nose", Vector3.new(0.15, 0.2, 0.15), CFrame.new(), C_SKIN)
    nose.Parent = model
    weldToRoot(nose, root, CFrame.new(0, 1.7, -0.81))

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

    local legL = createPart("LegL", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legL.Parent = model
    weldToRoot(legL, root, CFrame.new(-0.5, -2, 0))
    local shoeL = createPart("ShoeL", Vector3.new(1, 0.5, 1.3), CFrame.new(), C_SHOE)
    shoeL.Parent = model
    weldToRoot(shoeL, root, CFrame.new(-0.5, -3.2, -0.15))

    local legR = createPart("LegR", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legR.Parent = model
    weldToRoot(legR, root, CFrame.new(0.5, -2, 0))
    local shoeR = createPart("ShoeR", Vector3.new(1, 0.5, 1.3), CFrame.new(), C_SHOE)
    shoeR.Parent = model
    weldToRoot(shoeR, root, CFrame.new(0.5, -3.2, -0.15))
end

local function buildEvilMorty(root, model)
    buildMorty(root, model)
    local patch = createPart("EyePatch", Vector3.new(0.55, 0.55, 0.1), CFrame.new(), Color3.fromRGB(15, 15, 15))
    patch.Parent = model
    weldToRoot(patch, root, CFrame.new(-0.38, 1.9, -0.83))
    local strap1 = createPart("Strap1", Vector3.new(1.7, 0.1, 0.1), CFrame.new(), Color3.fromRGB(15, 15, 15))
    strap1.Parent = model
    weldToRoot(strap1, root, CFrame.new(0, 2.0, -0.81))
    local strap2 = createPart("Strap2", Vector3.new(1.7, 0.1, 0.1), CFrame.new(), Color3.fromRGB(15, 15, 15))
    strap2.Parent = model
    weldToRoot(strap2, root, CFrame.new(0, 1.85, 0.81))
end

local function buildRickPrime(root, model)
    local C_SKIN = Color3.fromRGB(190, 210, 220)
    local C_HAIR = Color3.fromRGB(180, 210, 250)
    local C_COAT = Color3.fromRGB(35, 35, 45)
    local C_SHIRT = Color3.fromRGB(180, 40, 40)
    local C_PANTS = Color3.fromRGB(25, 25, 30)
    local C_SHOE = Color3.fromRGB(10, 10, 10)
    local C_EYE_W = Color3.fromRGB(255, 255, 255)
    local C_EYE_B = Color3.fromRGB(0, 0, 0)

    local torso = createPart("Torso", Vector3.new(2, 2, 1), CFrame.new(), C_SHIRT)
    torso.Parent = model
    weldToRoot(torso, root, CFrame.new(0, 0, 0))

    local coatBack = createPart("CoatBack", Vector3.new(2.2, 2.2, 0.2), CFrame.new(), C_COAT)
    coatBack.Parent = model
    weldToRoot(coatBack, root, CFrame.new(0, 0, 0.55))

    local coatL = createPart("CoatL", Vector3.new(0.2, 2.2, 1.2), CFrame.new(), C_COAT)
    coatL.Parent = model
    weldToRoot(coatL, root, CFrame.new(-1.05, 0, 0))

    local coatR = createPart("CoatR", Vector3.new(0.2, 2.2, 1.2), CFrame.new(), C_COAT)
    coatR.Parent = model
    weldToRoot(coatR, root, CFrame.new(1.05, 0, 0))

    local head = createPart("Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(), C_SKIN)
    head.Parent = model
    weldToRoot(head, root, CFrame.new(0, 1.75, 0))

    local eyeL = createPart("EyeL", Vector3.new(0.4, 0.25, 0.1), CFrame.new(), C_EYE_W)
    eyeL.Parent = model
    weldToRoot(eyeL, root, CFrame.new(-0.32, 1.85, -0.76))
    local pupilL = createPart("PupilL", Vector3.new(0.1, 0.1, 0.12), CFrame.new(), C_EYE_B)
    pupilL.Parent = model
    weldToRoot(pupilL, root, CFrame.new(-0.32, 1.85, -0.77))

    local eyeR = createPart("EyeR", Vector3.new(0.4, 0.25, 0.1), CFrame.new(), C_EYE_W)
    eyeR.Parent = model
    weldToRoot(eyeR, root, CFrame.new(0.32, 1.85, -0.76))
    local pupilR = createPart("PupilR", Vector3.new(0.1, 0.1, 0.12), CFrame.new(), C_EYE_B)
    pupilR.Parent = model
    weldToRoot(pupilR, root, CFrame.new(0.32, 1.85, -0.77))

    local browL = createPart("BrowL", Vector3.new(0.45, 0.1, 0.1), CFrame.new(), C_HAIR)
    browL.Parent = model
    weldToRoot(browL, root, CFrame.new(-0.32, 2.05, -0.76) * CFrame.Angles(0, 0, math.rad(-15)))
    local browR = createPart("BrowR", Vector3.new(0.45, 0.1, 0.1), CFrame.new(), C_HAIR)
    browR.Parent = model
    weldToRoot(browR, root, CFrame.new(0.32, 2.05, -0.76) * CFrame.Angles(0, 0, math.rad(15)))

    addHairSpikes(root, model, C_HAIR)

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

    local legL = createPart("LegL", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legL.Parent = model
    weldToRoot(legL, root, CFrame.new(-0.5, -2, 0))
    local shoeL = createPart("ShoeL", Vector3.new(1, 0.5, 1.3), CFrame.new(), C_SHOE)
    shoeL.Parent = model
    weldToRoot(shoeL, root, CFrame.new(-0.5, -3.2, -0.15))

    local legR = createPart("LegR", Vector3.new(1, 2, 1), CFrame.new(), C_PANTS)
    legR.Parent = model
    weldToRoot(legR, root, CFrame.new(0.5, -2, 0))
    local shoeR = createPart("ShoeR", Vector3.new(1, 0.5, 1.3), CFrame.new(), C_SHOE)
    shoeR.Parent = model
    weldToRoot(shoeR, root, CFrame.new(0.5, -3.2, -0.15))
end
-- ============================================================
--  ПРИМЕНЕНИЕ И СНЯТИЕ СКИНА
-- ============================================================
local currentSkinModel = nil
local savedCharacterParts = {}

local function clearCurrentSkin()
    if currentSkinModel then
        pcall(function() currentSkinModel:Destroy() end)
        currentSkinModel = nil
    end
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

    clearCurrentSkin()

    savedCharacterParts = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d ~= root then
            savedCharacterParts[d] = d.Transparency
            d.Transparency = 1
        end
    end

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

track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if RM.SETTINGS.ActiveSkin then
        applySkin(RM.SETTINGS.ActiveSkin)
    end
end))

-- ============================================================
--  ПОРТАЛЬНАЯ ПУШКА (УЛУЧШЕННАЯ МОДЕЛЬ)
-- ============================================================
local activePortalGun = nil

local function buildPortalGun()
    local tool = Instance.new("Tool")
    tool.Name = "Portal Gun"
    tool.RequiresHandle = true
    tool.CanBeDropped = false
    tool.ToolTip = "ЛКМ / 🔥 — открыть портал"
    tool.GripForward = Vector3.new(0, 0, -1)
    tool.GripRight = Vector3.new(1, 0, 0)
    tool.GripUp = Vector3.new(0, 1, 0)

    -- Ручка
    local handle = createPart("Handle", Vector3.new(0.4, 1.2, 0.4), CFrame.new(), Color3.fromRGB(55, 55, 60))
    handle.Parent = tool

    -- Корпус
    local body = createPart("Body", Vector3.new(0.9, 0.8, 1.6), CFrame.new(), Color3.fromRGB(230, 230, 235))
    body.Parent = tool
    local w1 = Instance.new("WeldConstraint"); w1.Part0 = handle; w1.Part1 = body; w1.Parent = body
    body.CFrame = handle.CFrame * CFrame.new(0, 0.55, -0.35)

    -- Зеленая колба
    local orb = createPart("Orb", Vector3.new(0.55, 0.7, 0.55), CFrame.new(), Color3.fromRGB(50, 255, 50), Enum.Material.Glass)
    orb.Transparency = 0.15
    orb.Parent = tool
    local w2 = Instance.new("WeldConstraint"); w2.Part0 = body; w2.Part1 = orb; w2.Parent = orb
    orb.CFrame = body.CFrame * CFrame.new(0, 0.5, -0.35)

    local orbLight = Instance.new("PointLight", orb)
    orbLight.Color = Color3.fromRGB(50, 255, 50)
    orbLight.Range = 8
    orbLight.Brightness = 3
    orbLight.Shadows = false

    -- Табло (красный экран)
    local screen = createPart("Screen", Vector3.new(0.4, 0.2, 0.05), CFrame.new(), Color3.fromRGB(255, 30, 30))
    screen.Material = Enum.Material.Neon
    screen.Parent = tool
    local w3 = Instance.new("WeldConstraint"); w3.Part0 = body; w3.Part1 = screen; w3.Parent = screen
    screen.CFrame = body.CFrame * CFrame.new(0, 0.05, 0.81)

    local led = createPart("Led", Vector3.new(0.08, 0.08, 0.05), CFrame.new(), Color3.fromRGB(255, 50, 50))
    led.Material = Enum.Material.Neon
    led.Parent = tool
    local w4 = Instance.new("WeldConstraint"); w4.Part0 = screen; w4.Part1 = led; w4.Parent = led
    led.CFrame = screen.CFrame * CFrame.new(-0.12, 0, 0.03)

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
    hum:EquipTool(activePortalGun)
    activePortalGun.Activated:Connect(function()
        if RM.shootPortal then pcall(RM.shootPortal) end
    end)
    notify("🌀 Портальная пушка в руках", C.accent, 2)
end

-- ============================================================
--  ПОРТАЛЫ (УЛУЧШЕННАЯ ГРАФИКА)
-- ============================================================
local portalA = nil
local portalB = nil
local teleportCooldown = 0

local function createPortalModel(position, normal, color3)
    local model = Instance.new("Model")
    model.Name = "RM_Portal"
    model.Parent = Workspace

    local center = CFrame.new(position, position + normal)

    local ring1 = createPart("Ring1", Vector3.new(0.25, 9, 9), center, color3, Enum.Material.Neon)
    ring1.Shape = Enum.PartType.Cylinder
    ring1.Transparency = 0.15
    ring1.CFrame = center * CFrame.Angles(0, math.rad(90), 0)
    ring1.Parent = model

    local ring2 = createPart("Ring2", Vector3.new(0.2, 7, 7), center, color3, Enum.Material.Neon)
    ring2.Shape = Enum.PartType.Cylinder
    ring2.Transparency = 0.45
    ring2.CFrame = center * CFrame.Angles(0, math.rad(90), 0)
    ring2.Parent = model

    local spiral = Instance.new("Folder")
    spiral.Name = "Spiral"
    spiral.Parent = model
    for i = 1, 12 do
        local a = (i - 1) / 12 * math.pi * 2
        local r = 1.2 + (i / 12) * 2.2
        local seg = createPart("SpiralSeg", Vector3.new(0.15, 0.7, 0.15), CFrame.new(), color3, Enum.Material.Neon)
        seg.Transparency = 0.3
        seg.CFrame = center * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
        seg.Parent = spiral
    end

    local core = createPart("Core", Vector3.new(5.5, 5.5, 5.5), center, Color3.fromRGB(200, 255, 200), Enum.Material.Neon)
    core.Shape = Enum.PartType.Ball
    core.Transparency = 0.7
    core.Parent = model

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 80
    pe.Lifetime = NumberRange.new(0.4, 1.2)
    pe.Speed = NumberRange.new(2, 6)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
    pe.Color = ColorSequence.new(color3)
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = core

    local light = Instance.new("PointLight", core)
    light.Color = color3
    light.Range = 15
    light.Brightness = 3
    light.Shadows = false

    local trigger = createPart("Trigger", Vector3.new(8, 8, 0.5), center, Color3.new(1, 1, 1))
    trigger.Transparency = 1
    trigger.CanCollide = false
    trigger.CanTouch = true
    trigger.CFrame = center * CFrame.Angles(0, math.rad(90), 0)
    trigger.Parent = model

    local angle = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not model.Parent then
            conn:Disconnect()
            return
        end
        angle = angle + dt * 2.5
        ring1.CFrame = center * CFrame.Angles(math.rad(angle), math.rad(90), 0)
        ring2.CFrame = center * CFrame.Angles(math.rad(-angle * 1.5), math.rad(90), 0)
        spiral.CFrame = center * CFrame.Angles(math.rad(angle * 0.8), math.rad(90), 0)
    end)

    return {
        model = model,
        position = position,
        normal = normal,
        trigger = trigger,
        conn = conn,
        created = os.clock(),
    }
end

local function destroyPortal(portal)
    if not portal then return end
    pcall(function() if portal.conn then portal.conn:Disconnect() end end)
    pcall(function() if portal.model then portal.model:Destroy() end end)
end

local function getPortalColor()
    local c = RM.SETTINGS.PortalColor
    return Color3.fromRGB(c.R, c.G, c.B)
end

local function teleportPlayer(targetCF)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if os.clock() < teleportCooldown then return end
    teleportCooldown = os.clock() + 0.8

    playSound("teleport", 0.8, 1.2)
    spawnBurstPortal(hrp.Position, getPortalColor())
    hrp.CFrame = targetCF * CFrame.new(0, 0, -2)
    spawnBurstPortal(hrp.Position, getPortalColor())
end

function spawnBurstPortal(pos, color3)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.CFrame = CFrame.new(pos)
    p.Parent = Workspace
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 0
    pe.Lifetime = NumberRange.new(0.3, 0.8)
    pe.Speed = NumberRange.new(10, 25)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0) })
    pe.Color = ColorSequence.new(color3)
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = p
    pe:Emit(50)
    task.delay(1.5, function() pcall(function() p:Destroy() end) end)
end

local function shootPortal()
    local dir, origin = RM.getAimDirection()
    if not dir or not origin then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        origin = hrp.Position + dir * 2
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {char}
    if portalA and portalA.model then table.insert(ignore, portalA.model) end
    if portalB and portalB.model then table.insert(ignore, portalB.model) end
    raycastParams.FilterDescendantsInstances = ignore

    local result = Workspace:Raycast(origin, dir * 500, raycastParams)

    local spawnPos, spawnNormal
    if result then
        spawnPos = result.Position
        spawnNormal = result.Normal
    else
        spawnPos = origin + dir * 50
        spawnNormal = -dir
    end

    local color = getPortalColor()

    if not portalA then
        portalA = createPortalModel(spawnPos, spawnNormal, color)
        notify("🌀 Портал A создан", color, 2)
    elseif not portalB then
        portalB = createPortalModel(spawnPos, spawnNormal, color)
        notify("🌀 Портал B создан", color, 2)
    else
        destroyPortal(portalA)
        portalA = createPortalModel(spawnPos, spawnNormal, color)
        notify("🌀 Портал A пересоздан", color, 2)
    end

    if activePortalGun then
        local handle = activePortalGun:FindFirstChild("Handle")
        if handle then
            local dist = (spawnPos - handle.Position).Magnitude
            local beam = createPart("BeamFx", Vector3.new(0.2, 0.2, dist), CFrame.new(handle.Position, spawnPos) * CFrame.new(0, 0, -dist/2), color, Enum.Material.Neon)
            beam.Parent = Workspace
            task.delay(0.15, function() pcall(function() beam:Destroy() end) end)
        end
    end
    playSound("shoot", 0.6, 1)
end
RM.shootPortal = shootPortal
RM.fireFromAim = shootPortal
-- ============================================================
--  ДЕТЕКТОР ТЕЛЕПОРТАЦИИ
-- ============================================================
task.spawn(function()
    while alive do
        task.wait(0.05)
        if portalA and portalB and portalA.model and portalB.model then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                local dA = (pos - portalA.position).Magnitude
                local dB = (pos - portalB.position).Magnitude
                if dA < 3.5 then
                    teleportPlayer(CFrame.new(portalB.position, portalB.position + portalB.normal))
                elseif dB < 3.5 then
                    teleportPlayer(CFrame.new(portalA.position, portalA.position + portalA.normal))
                end
            end
        end
    end
end)

local function clearOldPortals()
    if portalA and os.clock() - portalA.created > 60 then
        destroyPortal(portalA); portalA = nil
    end
    if portalB and os.clock() - portalB.created > 60 then
        destroyPortal(portalB); portalB = nil
    end
end
task.spawn(function()
    while alive do
        task.wait(5)
        clearOldPortals()
    end
end)

-- ============================================================
--  UI: ВКЛАДКА «СКИНЫ»
-- ============================================================
do
    local frame = tabFrames["skins"]
    newSection(frame, "ЗАМЕНА ТЕЛА (детализированные)")

    local SKINS = {
        { id = "rick", name = "🧪 Рик Санчес", desc = "Халат с полами, шипы волос" },
        { id = "morty", name = "😰 Морти Смит", desc = "Жёлтая футболка, большие глаза" },
        { id = "evil_morty", name = "🖤 Злой Морти", desc = "Повязка, ремешок через голову" },
        { id = "rick_prime", name = "💀 Рик Прайм", desc = "Тёмный халат, сердитые брови" },
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

if RM.SETTINGS.ActiveSkin then
    task.spawn(function()
        task.wait(2)
        applySkin(RM.SETTINGS.ActiveSkin)
    end)
end

RM._cleanup = RM._cleanup or {}
RM._cleanup[#RM._cleanup + 1] = function()
    clearCurrentSkin()
end

-- ============================================================
--  UI: ВКЛАДКА «ПОРТАЛ»
-- ============================================================
do
    local frame = tabFrames["portal"]
    newSection(frame, "ПОРТАЛЬНАЯ ПУШКА")

    local equipBtn = newButton(frame, "🌀 Экипировать пушку", C.accent, nil, 40)
    equipBtn.MouseButton1Click:Connect(equipPortalGun)

    local shootBtn = newButton(frame, "🔥 Создать портал", C.bg2, nil, 40)
    shootBtn.MouseButton1Click:Connect(shootPortal)

    local clearBtn = newButton(frame, "🗑 Удалить оба портала", C.danger, nil, 34)
    clearBtn.MouseButton1Click:Connect(function()
        destroyPortal(portalA); portalA = nil
        destroyPortal(portalB); portalB = nil
        notify("🗑 Порталы удалены", C.text, 2)
    end)

    newSection(frame, "КАК РАБОТАЕТ")
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -8, 0, 90)
    info.BackgroundColor3 = C.bg2
    info.BackgroundTransparency = 0.2
    info.Text = "\n  1-й выстрел — портал A\n  2-й выстрел — портал B\n  3-й выстрел — перезаписывает A\n  Зайди в любой портал — вылетишь из другого.\n  Оба портала одного цвета."
    info.TextColor3 = C.textDim
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextWrapped = true
    info.Parent = frame
    Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)
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

    newSection(frame, "ЦВЕТ ПОРТАЛОВ (оба одинаковые)")
    local PORTAL_COLORS = {
        { name = "🟢 Зелёный",  c = { R = 50, G = 255, B = 50 } },
        { name = "🔵 Синий",    c = { R = 50, G = 150, B = 255 } },
        { name = "🟣 Фиолет",   c = { R = 180, G = 50, B = 255 } },
        { name = "🟡 Жёлтый",   c = { R = 255, G = 220, B = 50 } },
        { name = "🔴 Красный",  c = { R = 255, G = 60, B = 60 } },
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
        notify("🎨 Цвет порталов изменён", C.accent, 2)
    end)

    newSection(frame, "ПРИЦЕЛ")
    local AIM_SIZES = { 50, 64, 80, 100 }
    local aIdx = 1
    for i, v in ipairs(AIM_SIZES) do if v == RM.SETTINGS.AimSize then aIdx = i; break end end
    local aimBtn = newButton(frame, "🎯 Размер прицела: " .. RM.SETTINGS.AimSize, C.bg2, nil, 32)
    aimBtn.MouseButton1Click:Connect(function()
        aIdx = aIdx % #AIM_SIZES + 1
        RM.SETTINGS.AimSize = AIM_SIZES[aIdx]
        aimBtn.Text = "🎯 Размер прицела: " .. RM.SETTINGS.AimSize
        if aimFrame then
            aimFrame.Size = UDim2.fromOffset(RM.SETTINGS.AimSize, RM.SETTINGS.AimSize)
        end
        saveSettings()
    end)

    newSection(frame, "СБРОС")
    local resetBtn = newButton(frame, "🔄 Сбросить всё", C.danger, nil, 34)
    resetBtn.MouseButton1Click:Connect(function()
        RM.SETTINGS.SoundEnabled = true
        RM.SETTINGS.NotificationsEnabled = true
        RM.SETTINGS.PortalColor = { R = 50, G = 255, B = 50 }
        RM.SETTINGS.ActiveSkin = nil
        RM.SETTINGS.AimSize = 64
        saveSettings()
        removeSkin()
        soundBtn.Text = "🔊 Звуки: ВКЛ"
        pBtn.Text = "🎨 " .. PORTAL_COLORS[1].name
        aimBtn.Text = "🎯 Размер прицела: 64"
        if aimFrame then aimFrame.Size = UDim2.fromOffset(64, 64) end
        notify("🔄 Настройки сброшены", C.success, 2)
    end)

    newSection(frame, "ВЫХОД")
    local unloadBtn = newButton(frame, "❌ ВЫГРУЗИТЬ СКРИПТ", C.danger, nil, 36)
    unloadBtn.MouseButton1Click:Connect(function()
        RM.unload()
    end)

    newSection(frame, "О СКРИПТЕ")
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -8, 0, 80)
    info.BackgroundColor3 = C.bg2
    info.BackgroundTransparency = 0.2
    info.Text = "\n  Rick & Morty Toolkit v" .. RM._version .. "\n  Скины: 4  |  2 портала (один цвет)\n  Продвинутый прицел как в ORBIT.\n  Без 18+ контента."
    info.TextColor3 = C.textDim
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextWrapped = true
    info.Parent = frame
    Instance.new("UICorner", info).CornerRadius = UDim.new(0, 8)
end

-- ============================================================
--  UNLOAD
-- ============================================================
switchTab("skins")

function RM.unload()
    alive = false
    GENV._RM_BUSY = nil

    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}

    for _, fn in ipairs(RM._cleanup or {}) do pcall(fn) end

    destroyPortal(portalA); portalA = nil
    destroyPortal(portalB); portalB = nil

    if activePortalGun then pcall(function() activePortalGun:Destroy() end) end
    if sfxFolder then pcall(function() sfxFolder:Destroy() end) end

    clearCurrentSkin()

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

warn(string.format("[RickMorty v%s] Загружен. Скины: 4. Двойные порталы одного цвета. Прицел: %s",
    RM._version, isMobile and "ВКЛ" or "ВЫКЛ"))
notify("🌀 Rick & Morty v" .. RM._version .. " загружен", C.accent, 4)

GENV._RM_BUSY = nil

return RM
