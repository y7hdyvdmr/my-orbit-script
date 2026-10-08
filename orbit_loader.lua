-- ORBIT v24.0 | orbit_loader.lua
-- Главный загрузчик: стаб ORBIT, выбор платформы и режима, загрузка 16 файлов с прогрессом
-- v24.0-fix1: readSavedMode сначала смотрит orbit_v21_settings.json (правильное имя).

local GENV = rawget(_G, "getgenv") and getgenv() or _G

-- повторный запуск: выгружаем старое
if GENV._OrbitLoaderGui then
    pcall(function() GENV._OrbitLoaderGui:Destroy() end)
    GENV._OrbitLoaderGui = nil
end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local Stats        = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local Lighting     = game:GetService("Lighting")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== стаб ORBIT ====================
local ORBIT = {
    stub = true, version = "v24.0", started = false,
    PLATFORM = nil,
    loaded = {},
    saveData = {},
    LocalPlayer = LocalPlayer, Players = Players, Workspace = Workspace,
    RunService = RunService, TweenService = TweenService, HttpService = HttpService,
    notify = function() end,
    start = function() warn("[ORBIT] start: ядро не загружено") end,
    unload = function() end,
}
shared.ORBIT = ORBIT
rawset(_G, "ORBIT", ORBIT)
GENV.ORBIT = ORBIT

-- флаг: p4 не грузит shop/minigame сам
GENV._OrbitV24Loader = true

-- ==================== адреса ====================
local BASE = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local V24  = BASE .. "v24/"

local FILES = {
    { "orbit_p1.lua", BASE, false },
    { "orbit_p2.lua", BASE, false },
    { "orbit_p3.lua", BASE, false },
    { "orbit_p4.lua", BASE, false },
    { "orbit_sans.lua", V24, true },
    { "orbit_abilities.lua", V24, true },
    { "orbit_animations.lua", V24, true },
    { "orbit_death_fx.lua", V24, true },
    { "orbit_gaster.lua", V24, true },
    { "orbit_new_figures.lua", V24, true },
    { "orbit_p4_shop.lua", BASE, false },
    { "orbit_editor3d.lua", BASE, false },
    { "orbit_minigame.lua", BASE, false },
    { "orbit_extras.lua", V24, true },
    { "orbit_tools.lua", V24, true },
    { "orbit_anticheat.lua", V24, true },
}
local TOTAL = #FILES

-- ==================== окружение ====================
local function curOrbit()
    local ok, o = pcall(function() return GENV.ORBIT or shared.ORBIT or rawget(_G, "ORBIT") end)
    if ok and type(o) == "table" then return o end
    return ORBIT
end

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

-- v24.0-fix1: сначала правильное имя файла, потом fallback
local function readSavedMode()
    local saved = nil
    pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" then
            for _, fname in ipairs({ "orbit_v21_settings.json", "orbit_settings.json", "orbit_save.json", "orbit_data.json" }) do
                if isfile(fname) then
                    local d = HttpService:JSONDecode(readfile(fname))
                    local m = d.playerMode or (d.saveData and d.saveData.playerMode)
                    if m == "sans" or m == "normal" then saved = m; break end
                end
            end
        end
    end)
    return saved
end

-- ==================== onClick ====================
local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        local ok, err = pcall(fn)
        if not ok then warn("[Orbit] " .. tostring(err)) end
    end
    local function inScroll()
        return releaseOnly or btn:GetAttribute("ReleaseOnly")
            or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil
    end
    btn.MouseButton1Down:Connect(function() if not inScroll() then call() end end)
    btn.MouseButton1Click:Connect(function() if inScroll() then call() end end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchStart = input.Position
            if not inScroll() then call() end
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and touchStart then
            local moved = (input.Position - touchStart).Magnitude
            touchStart = nil
            if inScroll() and moved < 12 then call() end
        end
    end)
    btn.Activated:Connect(call)
end

-- ==================== GUI: каркас ====================
local gui = Instance.new("ScreenGui")
gui.Name = "_OrbitLoader_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
do
    local synTbl = rawget(GENV, "syn")
    if type(synTbl) == "table" and type(synTbl.protect_gui) == "function" then pcall(synTbl.protect_gui, gui) end
end
local okP = pcall(function() gui.Parent = getSafeParent() end)
if not okP or not gui.Parent then gui.Parent = PlayerGui end
GENV._OrbitLoaderGui = gui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(5, 5, 12)
dim.BackgroundTransparency = 0.25
dim.BorderSizePixel = 0
dim.Parent = gui

local W, H = 460, 340
local main = Instance.new("Frame")
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(W, H)
main.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", main)
mainStroke.Color = Color3.fromRGB(120, 90, 255)
mainStroke.Thickness = 1.5

local mainScale = Instance.new("UIScale", main)
local function fitScale()
    local vp = gui.AbsoluteSize
    if vp.X > 0 and vp.Y > 0 then
        mainScale.Scale = math.clamp(math.min(vp.X / (W + 30), vp.Y / (H + 30)), 0.5, 1.2)
    end
end
fitScale()
local fitConn = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitScale)

-- шапка с анимированным градиентом
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 52)
header.BorderSizePixel = 0
header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
header.Parent = main
local headGrad = Instance.new("UIGradient", header)
headGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 60, 220)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 70, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 140, 255)),
})
local headLbl = Instance.new("TextLabel")
headLbl.Size = UDim2.new(1, 0, 1, 0)
headLbl.BackgroundTransparency = 1
headLbl.Text = "🪐  О Р Б И Т А  v24.0"
headLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
headLbl.Font = Enum.Font.GothamBold
headLbl.TextSize = 22
headLbl.Parent = header

-- экраны
local function mkScreen()
    local f = Instance.new("Frame")
    f.Position = UDim2.new(0, 0, 0, 52)
    f.Size = UDim2.new(1, 0, 1, -52)
    f.BackgroundTransparency = 1
    f.Parent = main
    return f
end
local scrPlat, scrMode, scrLoad = mkScreen(), mkScreen(), mkScreen()
scrMode.Position = UDim2.new(1, 0, 0, 52)
scrLoad.Position = UDim2.new(1, 0, 0, 52)

local function slideTo(from, to)
    TweenService:Create(from, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(-1, 0, 0, 52) }):Play()
    to.Position = UDim2.new(1, 0, 0, 52)
    TweenService:Create(to, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, 52) }):Play()
end

local function mkLabel(parent, text, size, pos, sz, color, font, ts)
    local l = Instance.new("TextLabel")
    l.Position = pos
    l.Size = sz
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.fromRGB(230, 230, 255)
    l.Font = font or Enum.Font.GothamBold
    l.TextSize = ts or size or 14
    l.TextWrapped = true
    l.Parent = parent
    return l
end

-- карточка выбора
local CARD_BG = Color3.fromRGB(30, 30, 46)
local CARD_SEL = Color3.fromRGB(35, 90, 55)

local function mkCard(parent, xScale, icon, title, desc)
    local c = Instance.new("TextButton")
    c.AutoButtonColor = false
    c.Text = ""
    c.AnchorPoint = Vector2.new(0.5, 0)
    c.Position = UDim2.new(xScale, 0, 0, 62)
    c.Size = UDim2.new(0.44, 0, 0, 150)
    c.BackgroundColor3 = CARD_BG
    c.Parent = parent
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", c)
    st.Color = Color3.fromRGB(90, 90, 140)
    st.Thickness = 1.5
    mkLabel(c, icon, 40, UDim2.new(0, 0, 0, 8), UDim2.new(1, 0, 0, 50), nil, Enum.Font.GothamBold, 38)
    mkLabel(c, title, 15, UDim2.new(0, 6, 0, 62), UDim2.new(1, -12, 0, 22), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 15)
    mkLabel(c, desc, 11, UDim2.new(0, 8, 0, 88), UDim2.new(1, -16, 0, 56), Color3.fromRGB(180, 185, 210), Enum.Font.Gotham, 11)
    c:SetAttribute("Stroke", true)
    return c, st
end

local function selectCard(cards, picked)
    for _, it in ipairs(cards) do
        local on = (it.btn == picked)
        TweenService:Create(it.btn, TweenInfo.new(0.2), { BackgroundColor3 = on and CARD_SEL or CARD_BG }):Play()
        it.st.Color = on and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(90, 90, 140)
    end
end

-- ==================== экран 1: платформа ====================
mkLabel(scrPlat, "Выбери платформу", 16, UDim2.new(0, 0, 0, 12), UDim2.new(1, 0, 0, 30), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 17)
mkLabel(scrPlat, "От этого зависит управление и размер кнопок", 12, UDim2.new(0, 0, 0, 38), UDim2.new(1, 0, 0, 18), Color3.fromRGB(160, 165, 195), Enum.Font.Gotham, 12)

local cardMobile, stMobile = mkCard(scrPlat, 0.27, "📱", "ТЕЛЕФОН", "Сенсорное управление, крупные кнопки")
local cardPc, stPc = mkCard(scrPlat, 0.73, "💻", "КОМПЬЮТЕР", "Клавиатура и мышь, горячие клавиши")
local platCards = { { btn = cardMobile, st = stMobile }, { btn = cardPc, st = stPc } }

-- ==================== экран 2: режим ====================
mkLabel(scrMode, "Выбери режим", 16, UDim2.new(0, 0, 0, 12), UDim2.new(1, 0, 0, 30), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 17)
local cardSans, stSans = mkCard(scrMode, 0.27, "🎭", "🎭 РЕЖИМ САНСА", "Все фразы Санса, эмоции, реакции на атаки")
local cardNorm, stNorm = mkCard(scrMode, 0.73, "⚔️", "⚔️ ОБЫЧНЫЙ", "Только кольца и способности, без фраз")
local modeCards = { { btn = cardSans, st = stSans }, { btn = cardNorm, st = stNorm } }

local contBtn = Instance.new("TextButton")
contBtn.AnchorPoint = Vector2.new(0.5, 0)
contBtn.Position = UDim2.new(0.5, 0, 0, 228)
contBtn.Size = UDim2.new(0.6, 0, 0, 40)
contBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
contBtn.TextColor3 = Color3.fromRGB(150, 150, 170)
contBtn.Font = Enum.Font.GothamBold
contBtn.TextSize = 15
contBtn.Text = "Продолжить"
contBtn.AutoButtonColor = false
contBtn.Parent = scrMode
Instance.new("UICorner", contBtn).CornerRadius = UDim.new(0, 10)

-- ==================== экран 3: загрузка ====================
local statusLbl = mkLabel(scrLoad, "Подготовка...", 13, UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 20), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 13)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local barBg = Instance.new("Frame")
barBg.Position = UDim2.new(0, 14, 0, 30)
barBg.Size = UDim2.new(1, -28, 0, 12)
barBg.BackgroundColor3 = Color3.fromRGB(34, 34, 50)
barBg.BorderSizePixel = 0
barBg.ClipsDescendants = true
barBg.Parent = scrLoad
Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 6)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBg
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 6)
local barGrad = Instance.new("UIGradient", barFill)
barGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 140, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 120, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
})

-- скелетон-чипы (16 штук, сетка 8x2)
local chipHolder = Instance.new("Frame")
chipHolder.Position = UDim2.new(0, 14, 0, 50)
chipHolder.Size = UDim2.new(1, -28, 0, 56)
chipHolder.BackgroundTransparency = 1
chipHolder.Parent = scrLoad
local chipGrid = Instance.new("UIGridLayout", chipHolder)
chipGrid.CellSize = UDim2.new(0, 38, 0, 24)
chipGrid.CellPadding = UDim2.new(0, 6, 0, 8)
chipGrid.SortOrder = Enum.SortOrder.LayoutOrder
chipGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center

local chips = {}
local waveGrads = {}
for i = 1, TOTAL do
    local chip = Instance.new("Frame")
    chip.LayoutOrder = i
    chip.BackgroundColor3 = Color3.fromRGB(44, 44, 62)
    chip.BorderSizePixel = 0
    chip.Parent = chipHolder
    Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)
    local g = Instance.new("UIGradient", chip)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 150)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 150)),
    })
    g.Offset = Vector2.new(-1, 0)
    chips[i] = chip
    waveGrads[i] = g
end

-- лог (печатная машинка)
local logFrame = Instance.new("ScrollingFrame")
logFrame.Position = UDim2.new(0, 14, 0, 112)
logFrame.Size = UDim2.new(1, -28, 0, 110)
logFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 3
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = scrLoad
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 8)
local logLayout = Instance.new("UIListLayout", logFrame)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
local logPad = Instance.new("UIPadding", logFrame)
logPad.PaddingLeft = UDim.new(0, 6)
logPad.PaddingTop = UDim.new(0, 4)

local logN = 0
local alive = true
local function logLine(text, color)
    logN = logN + 1
    local l = Instance.new("TextLabel")
    l.LayoutOrder = logN
    l.Size = UDim2.new(1, -8, 0, 15)
    l.BackgroundTransparency = 1
    l.Text = ""
    l.TextColor3 = color or Color3.fromRGB(190, 200, 235)
    l.Font = Enum.Font.Code
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = logFrame
    task.spawn(function()
        local len = utf8.len(text) or #text
        for i = 1, len do
            if not alive or not l.Parent then return end
            local e = utf8.offset(text, i + 1)
            l.Text = string.sub(text, 1, (e or (#text + 1)) - 1)
            task.wait(0.008)
        end
        if l.Parent then l.Text = text end
    end)
    task.defer(function()
        pcall(function() logFrame.CanvasPosition = Vector2.new(0, 99999) end)
    end)
    while logN > 60 do
        local first = logFrame:FindFirstChildOfClass("TextLabel")
        if first then first:Destroy() else break end
        logN = logN - 1
    end
end

local perfLbl = mkLabel(scrLoad, "FPS: -- | Ping: --", 12, UDim2.new(0, 14, 0, 228), UDim2.new(1, -28, 0, 18), Color3.fromRGB(150, 220, 255), Enum.Font.Code, 12)
perfLbl.TextXAlignment = Enum.TextXAlignment.Left

-- ==================== анимации и FPS ====================
local fpsCount, fpsAcc, fpsShown = 0, 0, 60
local waveT = 0
local pendingFrom = 1
local animConn = RunService.RenderStepped:Connect(function(dt)
    if not alive then return end
    waveT = waveT + dt
    headGrad.Offset = Vector2.new(math.sin(waveT * 0.8) * 0.4, 0)
    headGrad.Rotation = (waveT * 20) % 360
    barGrad.Offset = Vector2.new(((waveT * 0.9) % 2) - 1, 0)
    for i = pendingFrom, TOTAL do
        local g = waveGrads[i]
        if g and g.Parent then
            g.Offset = Vector2.new(((waveT * 1.2 + i * 0.12) % 2) - 1, 0)
        end
    end
    fpsCount = fpsCount + 1
    fpsAcc = fpsAcc + dt
    if fpsAcc >= 0.5 then
        fpsShown = math.floor(fpsCount / fpsAcc + 0.5)
        fpsCount, fpsAcc = 0, 0
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        perfLbl.Text = "FPS: " .. fpsShown .. " | Ping: " .. ping .. " мс"
    end
end)

-- ==================== загрузка файлов ====================
local function httpGet(url)
    return game:HttpGet(url .. "?t=" .. os.time())
end

local function runUrl(url, name)
    local okGet, src = pcall(httpGet, url)
    if not okGet or type(src) ~= "string" or #src < 10 then
        return false, "нет ответа"
    end
    local fn, cerr = loadstring(src, "=" .. name)
    if not fn then return false, "синтаксис: " .. tostring(cerr) end
    local okRun, rerr = pcall(fn)
    if not okRun then return false, "ошибка: " .. tostring(rerr) end
    return true
end

local function fetchAndRun(url, name, tries)
    tries = tries or 3
    local lastErr = "?"
    for attempt = 1, tries do
        local ok, err = runUrl(url, name)
        if ok then return true end
        lastErr = err or "?"
        if attempt < tries then task.wait(0.6 * attempt) end
    end
    return false, lastErr
end

local failed = {}

local function loadAll()
    for i, f in ipairs(FILES) do
        if not alive then return end
        local name, root, hasFallback = f[1], f[2], f[3]
        statusLbl.Text = string.format("Загрузка %d/%d: %s", i, TOTAL, name)
        logLine("▶ " .. name)
        local ok, err = fetchAndRun(root .. name, name, 3)
        if not ok and hasFallback then
            logLine("  ↳ v24 не сработал, пробую корень", Color3.fromRGB(255, 210, 120))
            ok, err = fetchAndRun(BASE .. name, name, 3)
        end
        ORBIT = curOrbit()
        if i == 1 then
            ORBIT.PLATFORM = GENV._OrbitPlatform
            ORBIT.saveData = ORBIT.saveData or {}
            ORBIT.saveData.playerMode = GENV._OrbitMode
            ORBIT.mode = GENV._OrbitMode
        end
        if ok then
            chips[i].BackgroundColor3 = Color3.fromRGB(70, 210, 110)
            waveGrads[i].Enabled = false
            pendingFrom = i + 1
            logLine("  ✔ ок", Color3.fromRGB(130, 255, 160))
        else
            chips[i].BackgroundColor3 = Color3.fromRGB(220, 80, 80)
            waveGrads[i].Enabled = false
            pendingFrom = i + 1
            failed[#failed + 1] = name
            logLine("  ✘ ПРОВАЛ: " .. tostring(err), Color3.fromRGB(255, 130, 130))
        end
        TweenService:Create(barFill, TweenInfo.new(0.25), { Size = UDim2.new(i / TOTAL, 0, 1, 0) }):Play()
    end
end

-- ==================== финал: ✨ растёт, взлетает, исчезает ====================
local function finalFx()
    local star = Instance.new("TextLabel")
    star.AnchorPoint = Vector2.new(0.5, 0.5)
    star.Position = UDim2.new(0.5, 0, 0.55, 0)
    star.Size = UDim2.fromOffset(10, 10)
    star.BackgroundTransparency = 1
    star.Text = "✨"
    star.TextSize = 10
    star.Font = Enum.Font.GothamBold
    star.TextTransparency = 0
    star.ZIndex = 10
    star.Parent = scrLoad
    TweenService:Create(star, TweenInfo.new(0.5, Enum.EasingStyle.Back), { TextSize = 90, Size = UDim2.fromOffset(100, 100) }):Play()
    task.wait(0.6)
    local up = TweenService:Create(star, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, -0.8, 0), TextTransparency = 1 })
    up:Play()
    TweenService:Create(main, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
    task.wait(0.75)
    pcall(function() star:Destroy() end)
end

-- ==================== выгрузка ====================
local function cleanFolders()
    local prefixes = { "OrbitAbility_", "OrbitDeathFx_", "OrbitAtmo_", "OrbitSfx_", "OrbitGaster", "OrbitAnim" }
    local roots = { Workspace, SoundService, Lighting }
    for _, root in ipairs(roots) do
        for _, ch in ipairs(root:GetChildren()) do
            for _, pre in ipairs(prefixes) do
                if string.sub(ch.Name, 1, #pre) == pre then
                    pcall(function() ch:Destroy() end)
                    break
                end
            end
        end
    end
end

local function installUnload()
    local O = curOrbit()
    local prevUnload = O.unload
    O.unload = function()
        if prevUnload then pcall(prevUnload) end
        cleanFolders()
        alive = false
        pcall(function() if animConn then animConn:Disconnect() end end)
        pcall(function() if fitConn then fitConn:Disconnect() end end)
        pcall(function() gui:Destroy() end)
        GENV._OrbitV24Loader = nil
        GENV._OrbitLoaderGui = nil
        GENV._OrbitPlatform = nil
        GENV._OrbitMode = nil
        shared.ORBIT = nil
        rawset(_G, "ORBIT", nil)
        GENV.ORBIT = nil
    end
end

-- ==================== запуск загрузки ====================
local function beginLoad()
    slideTo(scrMode, scrLoad)
    task.spawn(function()
        task.wait(0.45)
        logLine("ОРБИТА v24.0 | платформа: " .. tostring(GENV._OrbitPlatform) .. " | режим: " .. tostring(GENV._OrbitMode))
        loadAll()
        if not alive then return end
        ORBIT = curOrbit()
        ORBIT.loaded = ORBIT.loaded or {}
        ORBIT.loaded.loader = true
        ORBIT.PLATFORM = GENV._OrbitPlatform
        ORBIT.saveData = ORBIT.saveData or {}
        ORBIT.saveData.playerMode = GENV._OrbitMode
        ORBIT.mode = GENV._OrbitMode
        installUnload()
        if #failed == 0 then
            statusLbl.Text = "✅ Всё загружено"
            logLine("Готово: 16/16", Color3.fromRGB(130, 255, 160))
        else
            statusLbl.Text = "⚠️ Загружено с ошибками: " .. #failed
            logLine("Не загрузились: " .. table.concat(failed, ", "), Color3.fromRGB(255, 130, 130))
        end
        ORBIT.stub = nil
        if ORBIT.start then pcall(ORBIT.start) end
        task.wait(0.4)
        finalFx()
        pcall(function() ORBIT.saveSettings() end)
        if gui.Parent then gui:Destroy() end
        GENV._OrbitLoaderGui = nil
        alive = false
        pcall(function() animConn:Disconnect() end)
    end)
end

-- ==================== логика выбора ====================
local chosenPlatform, chosenMode = nil, nil

onClick(cardMobile, function()
    chosenPlatform = "mobile"
    selectCard(platCards, cardMobile)
    ORBIT.PLATFORM = "mobile"
    GENV._OrbitPlatform = "mobile"
    task.delay(0.45, function() if alive then slideTo(scrPlat, scrMode) end end)
end)

onClick(cardPc, function()
    chosenPlatform = "pc"
    selectCard(platCards, cardPc)
    ORBIT.PLATFORM = "pc"
    GENV._OrbitPlatform = "pc"
    task.delay(0.45, function() if alive then slideTo(scrPlat, scrMode) end end)
end)

local function enableContinue()
    contBtn.BackgroundColor3 = Color3.fromRGB(50, 170, 90)
    contBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
end

local function pickMode(m, card)
    chosenMode = m
    selectCard(modeCards, card)
    ORBIT.mode = m
    ORBIT.saveData.playerMode = m
    GENV._OrbitMode = m
    enableContinue()
end

onClick(cardSans, function() pickMode("sans", cardSans) end)
onClick(cardNorm, function() pickMode("normal", cardNorm) end)

onClick(contBtn, function()
    if not chosenMode then return end
    contBtn.Active = false
    beginLoad()
end)

-- уже сохранённый режим: подсвечиваем как выбранный
do
    local saved = readSavedMode()
    if saved == "sans" then
        pickMode("sans", cardSans)
    elseif saved == "normal" then
        pickMode("normal", cardNorm)
    end
end

-- появление окна
main.Position = UDim2.fromScale(0.5, 0.58)
main.BackgroundTransparency = 1
TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back),
    { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0 }):Play()

ORBIT.loaded.loader = true
return true
