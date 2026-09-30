--[[ ОРБИТА — МИНИ-ИГРА «ЛОВЛЯ ЗВЁЗД» v2.1
     25 слотов = 5 колец × 5 волн. Авто-стоп через 30 сек.
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit MiniGame] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit MiniGame] UI не готов!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local TweenService = ORBIT.TweenService
local LocalPlayer  = ORBIT.LocalPlayer
local SETTINGS     = ORBIT.SETTINGS
local P            = ORBIT.P
local rings        = ORBIT.rings
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS
local screenGui    = ORBIT.ui.screenGui

-- Список доступных фигур
local AVAILABLE_SHAPES = {}
for k in pairs(SHAPE_PRESETS) do
    if type(k) == "number" then table.insert(AVAILABLE_SHAPES, k) end
end
table.sort(AVAILABLE_SHAPES)
local SHAPE_COUNT = #AVAILABLE_SHAPES
warn("[Orbit MiniGame] Доступно фигур: " .. SHAPE_COUNT)

local GAME = {
    TargetCount  = 10,
    TimeLimit    = 20,
    StarLifetime = 1.4,
    StarMinSize  = 40,
    StarMaxSize  = 70,
}

local REWARD = {
    SwapInterval = 2.0,
    WavesPerLoop = 5,
    MaxLoops     = 3,
    Active       = false,
    Wave         = 0,
    LoopsDone    = 0,
    LastSwap     = 0,
}

local function getShapeIndex(wave, ring)
    if SHAPE_COUNT == 0 then return nil end
    local slot = ((wave - 1) * 5 + (ring - 1)) % SHAPE_COUNT + 1
    return AVAILABLE_SHAPES[slot]
end

local function applyRewardStep()
    if SHAPE_COUNT == 0 then return end
    for ri = 1, 5 do
        local shapeIdx = getShapeIndex(REWARD.Wave, ri)
        if shapeIdx and SHAPE_PRESETS[shapeIdx] then
            rings[ri].shapeIndex = shapeIdx
            rings[ri].enabled = true
        end
    end
    for ri = 1, 5 do
        if rings[ri].enabled then
            if ORBIT.destroyRing then pcall(ORBIT.destroyRing, ri) end
            if ORBIT.buildRing then pcall(ORBIT.buildRing, ri) end
        end
    end
    if ORBIT.applyColor then pcall(ORBIT.applyColor) end
    if ORBIT.applyNameVisibility then pcall(ORBIT.applyNameVisibility) end
end

local function startRewardAnimation()
    SETTINGS.Rainbow = true
    SETTINGS.LightEnabled = true
    SETTINGS.TrailEnabled = true
    SETTINGS.PulseEnabled = true
    SETTINGS.WaveEnabled = true
    SETTINGS.GradientEnabled = true
    SETTINGS.AutoShapeSwap = false
    SETTINGS.Transparency = 0.05
    SETTINGS.LightLimit = 40

    P.colorIndex = 1
    P.orbitIndex = 4
    P.heightIndex = 4
    P.spreadIndex = 3
    SETTINGS.OrbitPattern = "Спираль"

    for ri = 1, 5 do
        rings[ri].radiusOffset = (ri - 1) * 0.8
        rings[ri].heightOffset = (ri - 3) * 0.6
        rings[ri].direction = (ri % 2 == 0) and -1 or 1
        rings[ri].speedMult = 0.8 + (ri - 1) * 0.15
        rings[ri].angleShift = (ri - 1) * (360 / 5)
        rings[ri].colorShift = (ri - 1) * 0.2
    end

    REWARD.Wave = 1
    REWARD.LoopsDone = 0
    REWARD.LastSwap = tick()
    REWARD.Active = true
    applyRewardStep()

    ORBIT.notify("🏆 ЛЕГЕНДАРНАЯ НАГРАДА!", Color3.fromRGB(255, 215, 0), 5)
    ORBIT.notify("🌀 " .. SHAPE_COUNT .. " ФИГУР СМЕНЯЮТСЯ", Color3.fromRGB(255, 220, 120), 5)
    warn("[Orbit MiniGame] Награда стартовала. Фигур: " .. SHAPE_COUNT)
end

local function stopRewardAnimation()
    REWARD.Active = false
    warn("[Orbit MiniGame] Награда остановлена")
end

task.spawn(function()
    while task.wait(0.2) do
        if REWARD.Active and (tick() - REWARD.LastSwap) >= REWARD.SwapInterval then
            REWARD.LastSwap = tick()
            REWARD.Wave = REWARD.Wave + 1
            if REWARD.Wave > REWARD.WavesPerLoop then
                REWARD.Wave = 1
                REWARD.LoopsDone = REWARD.LoopsDone + 1
                if REWARD.LoopsDone >= REWARD.MaxLoops then
                    stopRewardAnimation()
                    ORBIT.notify("✨ Цикл 25 фигур завершён", Color3.fromRGB(200, 200, 255), 4)
                    continue
                end
            end
            applyRewardStep()
        end
    end
end)

local function giveReward()
    startRewardAnimation()
    ORBIT.COINS = (ORBIT.COINS or 0) + 500
    if ORBIT.HAS_FS then
        pcall(function()
            writefile(ORBIT.COINS_FILE or "orbit_v21_coins.json", tostring(ORBIT.COINS))
        end)
    end
    pcall(function() ORBIT.saveSettings() end)
    ORBIT.notify("💰 +500 монет", Color3.fromRGB(255, 220, 120), 4)
end

local MINIGAME = {
    Open = false, Playing = false, Caught = 0,
    TimeLeft = GAME.TimeLimit, Stars = {}, Conn = nil,
}
local minigameGui

local function spawnStar()
    if not minigameGui or not MINIGAME.Playing then return end
    local field = minigameGui:FindFirstChild("_PlayField", true)
    if not field then return end

    local starSize = math.random(GAME.StarMinSize, GAME.StarMaxSize)
    local btn = Instance.new("TextButton")
    btn.Name = "_Star"
    btn.Size = UDim2.new(0, starSize, 0, starSize)
    btn.BackgroundTransparency = 1
    btn.Text = "⭐"
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.fromHSV(math.random(), 0.8, 1)
    btn.AutoButtonColor = false
    btn.ZIndex = 15

    local fieldSize = field.AbsoluteSize
    if fieldSize.X < 100 or fieldSize.Y < 100 then
        task.wait(0.1)
        fieldSize = field.AbsoluteSize
    end

    local margin = starSize * 0.5
    local maxX = math.max(1, fieldSize.X - starSize - margin)
    local maxY = math.max(1, fieldSize.Y - starSize - margin)
    local x = math.random(margin, maxX)
    local y = math.random(margin, maxY)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.Parent = field
    btn.TextTransparency = 1
    TweenService:Create(btn, TweenInfo.new(0.15), {TextTransparency = 0}):Play()

    local data = {
        frame = btn, born = tick(),
        duration = GAME.StarLifetime + math.random() * 0.6, caught = false,
    }
    table.insert(MINIGAME.Stars, data)

    local function catch()
        if data.caught or not MINIGAME.Playing then return end
        data.caught = true
        MINIGAME.Caught = MINIGAME.Caught + 1

        btn.Text = "✨"
        btn.TextColor3 = Color3.fromRGB(255, 255, 100)
        TweenService:Create(btn, TweenInfo.new(0.2), {
            Size = UDim2.new(0, starSize * 2, 0, starSize * 2),
            TextTransparency = 1,
            Position = UDim2.new(0, x - starSize * 0.5, 0, y - starSize * 0.5),
        }):Play()

        if ORBIT.playClick then ORBIT.playClick() end
        local progressLbl = minigameGui and minigameGui:FindFirstChild("_ProgressLbl", true)
        if progressLbl then
            progressLbl.Text = "⭐ " .. MINIGAME.Caught .. " / " .. GAME.TargetCount
        end
        task.delay(0.3, function() pcall(function() btn:Destroy() end) end)

        if MINIGAME.Caught >= GAME.TargetCount then
            MINIGAME.Playing = false
            if ORBIT.playDodge then ORBIT.playDodge() end
            task.wait(0.5)
            giveReward()
            local winBanner = minigameGui and minigameGui:FindFirstChild("_WinBanner", true)
            if winBanner then
                winBanner.Visible = true
                winBanner.Text = "🏆 ПОБЕДА! 🏆\n25 ФИГУР + 500 МОНЕТ"
                winBanner.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
        end
    end

    btn.MouseButton1Down:Connect(catch)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then catch() end
    end)
end

local function startGameLoop()
    if MINIGAME.Conn then MINIGAME.Conn:Disconnect() end
    MINIGAME.Conn = RunService.Heartbeat:Connect(function(dt)
        if not MINIGAME.Playing then return end
        MINIGAME.TimeLeft = MINIGAME.TimeLeft - dt
        local timerLbl = minigameGui and minigameGui:FindFirstChild("_TimerLbl", true)
        if timerLbl then
            timerLbl.Text = "⏱️ " .. string.format("%.1f", math.max(0, MINIGAME.TimeLeft)) .. "с"
            timerLbl.TextColor3 = MINIGAME.TimeLeft <= 5 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 220, 120)
        end
        if MINIGAME.TimeLeft <= 0 then
            MINIGAME.Playing = false
            local winBanner = minigameGui and minigameGui:FindFirstChild("_WinBanner", true)
            if winBanner then
                winBanner.Visible = true
                winBanner.Text = "⏰ ВРЕМЯ ВЫШЛО! Поймано: " .. MINIGAME.Caught
                winBanner.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
            return
        end
        local now = tick()
        local activeStars = 0
        for i = #MINIGAME.Stars, 1, -1 do
            local s = MINIGAME.Stars[i]
            if not s.frame or not s.frame.Parent then
                table.remove(MINIGAME.Stars, i)
            elseif s.caught then
            elseif now - s.born > s.duration then
                pcall(function() s.frame:Destroy() end)
                table.remove(MINIGAME.Stars, i)
            else
                activeStars = activeStars + 1
            end
        end
        if activeStars < 3 and math.random() < dt * 2.5 then spawnStar() end
    end)
end

local function closeMiniGame()
    MINIGAME.Open = false
    MINIGAME.Playing = false
    if MINIGAME.Conn then MINIGAME.Conn:Disconnect(); MINIGAME.Conn = nil end
    for _, s in ipairs(MINIGAME.Stars) do
        pcall(function() if s.frame then s.frame:Destroy() end end)
    end
    MINIGAME.Stars = {}
    if minigameGui then
        pcall(function() minigameGui:Destroy() end)
        minigameGui = nil
    end
end

local function openMiniGame()
    if MINIGAME.Open then return end
    MINIGAME.Open = true

    minigameGui = Instance.new("Frame")
    minigameGui.Name = "_OrbitMiniGame"
    minigameGui.Size = UDim2.new(0, 500, 0, 490)
    minigameGui.Position = UDim2.new(0.5, -250, 0.5, -245)
    minigameGui.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    minigameGui.BackgroundTransparency = 0.05
    minigameGui.BorderSizePixel = 0
    minigameGui.ZIndex = 30
    minigameGui.Parent = screenGui
    Instance.new("UICorner", minigameGui).CornerRadius = UDim.new(0, 16)
    local str = Instance.new("UIStroke", minigameGui)
    str.Color = Color3.fromRGB(200, 150, 255)
    str.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 32)
    title.Position = UDim2.new(0, 16, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🎮  ЛОВЛЯ ЗВЁЗД"
    title.TextColor3 = Color3.fromRGB(255, 220, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 31
    title.Parent = minigameGui

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -44, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 31
    closeBtn.Parent = minigameGui
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    closeBtn.Activated:Connect(closeMiniGame)

    local rules = Instance.new("TextLabel")
    rules.Size = UDim2.new(1, -32, 0, 46)
    rules.Position = UDim2.new(0, 16, 0, 46)
    rules.BackgroundTransparency = 1
    rules.Text = "Поймай " .. GAME.TargetCount .. " звёзд за " .. GAME.TimeLimit .. " секунд!\n🏆 Награда: 25 ФИГУР + 500 монет"
    rules.TextColor3 = Color3.fromRGB(220, 200, 255)
    rules.Font = Enum.Font.Gotham
    rules.TextSize = 12
    rules.TextWrapped = true
    rules.TextXAlignment = Enum.TextXAlignment.Center
    rules.ZIndex = 31
    rules.Parent = minigameGui

    local progressLbl = Instance.new("TextLabel")
    progressLbl.Name = "_ProgressLbl"
    progressLbl.Size = UDim2.new(0, 200, 0, 26)
    progressLbl.Position = UDim2.new(0, 16, 0, 100)
    progressLbl.BackgroundColor3 = Color3.fromRGB(40, 60, 45)
    progressLbl.BorderSizePixel = 0
    progressLbl.Text = "⭐ 0 / " .. GAME.TargetCount
    progressLbl.TextColor3 = Color3.fromRGB(180, 255, 180)
    progressLbl.Font = Enum.Font.GothamBold
    progressLbl.TextSize = 14
    progressLbl.ZIndex = 31
    progressLbl.Parent = minigameGui
    Instance.new("UICorner", progressLbl).CornerRadius = UDim.new(0, 8)

    local timerLbl = Instance.new("TextLabel")
    timerLbl.Name = "_TimerLbl"
    timerLbl.Size = UDim2.new(0, 200, 0, 26)
    timerLbl.Position = UDim2.new(1, -216, 0, 100)
    timerLbl.BackgroundColor3 = Color3.fromRGB(60, 45, 30)
    timerLbl.BorderSizePixel = 0
    timerLbl.Text = "⏱️ " .. GAME.TimeLimit .. ".0с"
    timerLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
    timerLbl.Font = Enum.Font.GothamBold
    timerLbl.TextSize = 14
    timerLbl.ZIndex = 31
    timerLbl.Parent = minigameGui
    Instance.new("UICorner", timerLbl).CornerRadius = UDim.new(0, 8)

    local playField = Instance.new("Frame")
    playField.Name = "_PlayField"
    playField.Size = UDim2.new(1, -32, 0, 300)
    playField.Position = UDim2.new(0, 16, 0, 136)
    playField.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
    playField.BackgroundTransparency = 0.05
    playField.BorderSizePixel = 0
    playField.ClipsDescendants = true
    playField.ZIndex = 20
    playField.Parent = minigameGui
    Instance.new("UICorner", playField).CornerRadius = UDim.new(0, 12)
    local fieldStroke = Instance.new("UIStroke", playField)
    fieldStroke.Color = Color3.fromRGB(120, 80, 200)
    fieldStroke.Thickness = 1.5
    fieldStroke.Transparency = 0.3

    local winBanner = Instance.new("TextLabel")
    winBanner.Name = "_WinBanner"
    winBanner.Size = UDim2.new(1, -32, 0, 70)
    winBanner.Position = UDim2.new(0, 16, 0, 210)
    winBanner.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
    winBanner.BackgroundTransparency = 0.05
    winBanner.BorderSizePixel = 0
    winBanner.Text = ""
    winBanner.TextColor3 = Color3.fromRGB(255, 255, 255)
    winBanner.Font = Enum.Font.GothamBold
    winBanner.TextSize = 18
    winBanner.TextWrapped = true
    winBanner.Visible = false
    winBanner.ZIndex = 40
    winBanner.Parent = minigameGui
    Instance.new("UICorner", winBanner).CornerRadius = UDim.new(0, 12)
    local bannerStroke = Instance.new("UIStroke", winBanner)
    bannerStroke.Color = Color3.fromRGB(255, 220, 120)
    bannerStroke.Thickness = 2

    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(1, -32, 0, 42)
    startBtn.Position = UDim2.new(0, 16, 1, -54)
    startBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
    startBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 15
    startBtn.Text = "▶  СТАРТ"
    startBtn.ZIndex = 31
    startBtn.Parent = minigameGui
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)

    startBtn.Activated:Connect(function()
        MINIGAME.Playing = true
        MINIGAME.Caught = 0
        MINIGAME.TimeLeft = GAME.TimeLimit
        for _, s in ipairs(MINIGAME.Stars) do
            pcall(function() if s.frame then s.frame:Destroy() end end)
        end
        MINIGAME.Stars = {}
        winBanner.Visible = false
        progressLbl.Text = "⭐ 0 / " .. GAME.TargetCount
        timerLbl.Text = "⏱️ " .. GAME.TimeLimit .. ".0с"
        timerLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
        startBtn.Text = "🎯 ИГРА ИДЁТ..."
        startBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        startBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        startGameLoop()
        task.delay(GAME.TimeLimit + 1, function()
            if startBtn and startBtn.Parent then
                startBtn.Text = "▶  ИГРАТЬ СНОВА"
                startBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
                startBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
            end
        end)
    end)

    local tip = Instance.new("TextLabel")
    tip.Size = UDim2.new(1, -32, 0, 20)
    tip.Position = UDim2.new(0, 16, 1, -22)
    tip.BackgroundTransparency = 1
    tip.Text = "⏳ Полный цикл 25 фигур ~30 секунд"
    tip.TextColor3 = Color3.fromRGB(180, 160, 220)
    tip.Font = Enum.Font.Gotham
    tip.TextSize = 10
    tip.ZIndex = 31
    tip.Parent = minigameGui
end

ORBIT.openMiniGame = openMiniGame
ORBIT.closeMiniGame = closeMiniGame
ORBIT.stopRewardAnimation = stopRewardAnimation
ORBIT.startRewardAnimation = startRewardAnimation

if ORBIT.notify then
    ORBIT.notify("🎮 Мини-игра v2.1 загружена!", Color3.fromRGB(220, 200, 255), 3)
end

return true
