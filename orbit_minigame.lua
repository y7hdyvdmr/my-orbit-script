--[[ ОРБИТА v23.0 — МИНИ-ИГРА «ЛОВЛЯ ЗВЁЗД» v3.0
     🆕 3 сложности: ОБЫЧНАЯ / СЛОЖНАЯ / ХАРДКОР
     🆕 УЛЬТРА-НАГРАДА на Хардкоре — 24 кольца с разными фигурами
     🆕 Разные награды за каждую сложность
     🐛 Фикс math.random с дробными, убран task.wait в Heartbeat
]]
--[[ ИЗМЕНЕНИЯ (общий релиз v23.5): кнопки закрытия / сложности / старта теперь через onClick
     (на Android .Activated мог не срабатывать). Логика игры не менялась. ]]
--[[ ФИКСЫ v23.6:
  🐛 onClick не играл ORBIT.playClick — кнопки мини-игры молчали. Добавлено.
  🐛 minigameGui:FindFirstChild("_PlayField", true) вызывался при КАЖДОМ спавне звезды,
     а FindFirstChild("_TimerLbl", true) — в КАЖДОМ кадре Heartbeat. Рекурсивный обход всего
     дерева GUI на мобилке заметно просаживал FPS. Ссылки на _PlayField / _ProgressLbl /
     _TimerLbl / _WinBanner теперь кэшируются в MINIGAME.Fields.
  🐛 при быстром перезапуске (СТАРТ → СТАРТ) отложенный task.delay(diff.TimeLimit + 1)
     от ПЕРВОЙ игры срабатывал во время ВТОРОЙ и менял текст кнопки на «ИГРАТЬ СНОВА».
     Введён RunId: обработчик проверяет, что игра та же самая, иначе молчит.
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit MiniGame] ORBIT не найден!"); return end

-- ============================================================
--  onClick: Down + Touch + Activated (Android / Delta).
--  Внутри ScrollingFrame кнопка срабатывает при ОТПУСКАНИИ пальца (если он почти не двигался),
--  иначе свайп для прокрутки нажимал бы кнопки под пальцем. Атрибут ReleaseOnly = true
--  включает этот режим принудительно (например, для перетаскиваемых кнопок).
-- ============================================================
local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        -- 🐛 ФИКС v23.6: играем клик, чтобы кнопки не были «молчаливыми»
        if ORBIT.playClick then pcall(ORBIT.playClick) end
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

if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit MiniGame] UI не готов!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local TweenService = ORBIT.TweenService
local Workspace    = ORBIT.Workspace
local LocalPlayer  = ORBIT.LocalPlayer

local SETTINGS      = ORBIT.SETTINGS
local P             = ORBIT.P
local rings         = ORBIT.rings
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS
local screenGui     = ORBIT.ui.screenGui

local IS_MOBILE = (ORBIT.PLATFORM == "mobile")

-- ============================================================
--         СПИСОК ДОСТУПНЫХ ФИГУР
-- ============================================================
local AVAILABLE_SHAPES = {}
for k in pairs(SHAPE_PRESETS) do
    if type(k) == "number" then
        table.insert(AVAILABLE_SHAPES, k)
    end
end
table.sort(AVAILABLE_SHAPES)
local SHAPE_COUNT = #AVAILABLE_SHAPES
warn("[Orbit MiniGame] Доступно фигур: " .. SHAPE_COUNT)

-- ============================================================
--         СЛОЖНОСТИ
-- ============================================================
local DIFFICULTIES = {
    {
        name = "ОБЫЧНАЯ",
        icon = "🌱",
        TargetCount  = 10,
        TimeLimit    = 20,
        StarLifetime = 1.4,
        StarMinSize  = 40,
        StarMaxSize  = 70,
        SpawnRate    = 2.5,
        CoinsReward  = 500,
        GiveUltra    = false,
        Color = Color3.fromRGB(120, 220, 150),
    },
    {
        name = "СЛОЖНАЯ",
        icon = "🔥",
        TargetCount  = 15,
        TimeLimit    = 15,
        StarLifetime = 1.0,
        StarMinSize  = 32,
        StarMaxSize  = 55,
        SpawnRate    = 2.0,
        CoinsReward  = 1000,
        GiveUltra    = false,
        Color = Color3.fromRGB(255, 180, 100),
    },
    {
        name = "ХАРДКОР",
        icon = "💀",
        TargetCount  = 20,
        TimeLimit    = 12,
        StarLifetime = 0.75,
        StarMinSize  = 26,
        StarMaxSize  = 44,
        SpawnRate    = 1.6,
        CoinsReward  = 2000,
        GiveUltra    = true,   -- 🆕 запускает 24-кольцевую орбиту
        Color = Color3.fromRGB(255, 90, 120),
    },
}
local difficultyIndex = 1
local function getDifficulty() return DIFFICULTIES[difficultyIndex] end

-- Старая награда «25 фигур × 5 волн» (для совместимости)
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
    SETTINGS.Rainbow         = true
    SETTINGS.LightEnabled    = true
    SETTINGS.TrailEnabled    = true
    SETTINGS.PulseEnabled    = true
    SETTINGS.WaveEnabled     = true
    SETTINGS.GradientEnabled = true
    SETTINGS.AutoShapeSwap   = false
    SETTINGS.Transparency    = 0.05
    SETTINGS.LightLimit      = 40

    P.colorIndex = 1
    P.orbitIndex = 4
    P.heightIndex = 4
    P.spreadIndex = 3
    SETTINGS.OrbitPattern = "Спираль"

    for ri = 1, 5 do
        rings[ri].radiusOffset = (ri - 1) * 0.8
        rings[ri].heightOffset = (ri - 3) * 0.6
        rings[ri].direction    = (ri % 2 == 0) and -1 or 1
        rings[ri].speedMult    = 0.8 + (ri - 1) * 0.15
        rings[ri].angleShift   = (ri - 1) * (360 / 5)
        rings[ri].colorShift   = (ri - 1) * 0.2
    end

    REWARD.Wave = 1
    REWARD.LoopsDone = 0
    REWARD.LastSwap = tick()
    REWARD.Active = true
    applyRewardStep()

    ORBIT.notify("🏆 ЛЕГЕНДАРНАЯ НАГРАДА!", Color3.fromRGB(255, 215, 0), 5)
    ORBIT.notify("🌀 " .. SHAPE_COUNT .. " ФИГУР СМЕНЯЮТСЯ", Color3.fromRGB(255, 220, 120), 5)
end

local function stopRewardAnimation()
    REWARD.Active = false
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

-- ============================================================
--  🆕 УЛЬТРА-НАГРАДА: 24 КОЛЬЦА С РАЗНЫМИ ФИГУРАМИ
-- ============================================================
local ULTRA = {
    Active = false,
    Folder = nil,
    Blocks = {},          -- плоский список блоков для обновления
    Conn = nil,
    StartTime = 0,
    Duration = 60,        -- длится 60 секунд
}

local function stopUltra()
    ULTRA.Active = false
    if ULTRA.Conn then pcall(function() ULTRA.Conn:Disconnect() end); ULTRA.Conn = nil end
    if ULTRA.Folder then pcall(function() ULTRA.Folder:Destroy() end); ULTRA.Folder = nil end
    ULTRA.Blocks = {}
    warn("[Orbit MiniGame] Ультра-орбита остановлена")
end

local function startUltra()
    if ULTRA.Active then stopUltra() end
    ULTRA.Active = true
    ULTRA.StartTime = tick()
    ULTRA.Folder = Instance.new("Folder")
    ULTRA.Folder.Name = "OrbitUltra_" .. tostring(math.random(1, 999999))
    ULTRA.Folder.Parent = Workspace
    ULTRA.Blocks = {}

    local count = SHAPE_COUNT           -- до 24 колец
    local blocksPerRing = IS_MOBILE and 3 or 4  -- бережём мобилку
    local shapeSize = 1.3

    for ri = 1, count do
        local shapeIdx = AVAILABLE_SHAPES[ri]
        local shape = SHAPE_PRESETS[shapeIdx]
        if not shape then continue end

        -- Радиус: 6 → 26, распределяем по спирали
        local radius = 6 + (ri - 1) * 0.85
        -- Высота: слой за слоем
        local height = -3 + math.floor((ri - 1) / 6) * 2.0 + (ri % 3) * 0.4
        -- Наклон всей орбиты
        local tiltX = math.rad((ri % 7 - 3) * 6)
        local tiltY = math.rad((ri % 5 - 2) * 8)
        -- Скорость вращения
        local speed = 25 + (ri % 8) * 12
        local dir = (ri % 2 == 0) and -1 or 1

        local ringFolder = Instance.new("Folder")
        ringFolder.Name = "Ring_" .. ri .. "_" .. shape.name
        ringFolder.Parent = ULTRA.Folder

        local ringData = {
            ri = ri, shapeIdx = shapeIdx,
            folder = ringFolder, blocks = {},
            angle = (ri - 1) * (360 / count),
            radius = radius, height = height,
            tiltX = tiltX, tiltY = tiltY,
            speed = speed, dir = dir,
            colorShift = (ri - 1) / count,
        }

        for bi = 1, blocksPerRing do
            local data = shape.create(shapeSize, "U_" .. ri .. "_" .. bi, bi)
            local refPart = data.part
            if not data.isModel then
                refPart.Material = Enum.Material.Neon
                refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
                refPart.CanQuery = false; refPart.CanTouch = false
                refPart.Transparency = 0.1
            end
            if data.bodyParts then
                for _, bp in ipairs(data.bodyParts) do
                    pcall(function()
                        bp.CanQuery = false; bp.CanTouch = false
                        bp.Transparency = 0.1
                    end)
                end
            end
            if data.isModel then data.model.Parent = ringFolder else refPart.Parent = ringFolder end

            table.insert(ringData.blocks, {
                part = refPart, model = data.model, isModel = data.isModel or false,
                bodyParts = data.bodyParts,
                angleOffset = (bi - 1) * (360 / blocksPerRing),
            })
        end

        table.insert(ULTRA.Blocks, ringData)
    end

    -- Обновление в Heartbeat
    ULTRA.Conn = RunService.Heartbeat:Connect(function(dt)
        if not ULTRA.Active then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local elapsed = tick() - ULTRA.StartTime
        if elapsed >= ULTRA.Duration then
            stopUltra()
            ORBIT.notify("⌛ Ультра-орбита завершена", Color3.fromRGB(200, 200, 255), 4)
            return
        end

        local t = elapsed
        for _, rd in ipairs(ULTRA.Blocks) do
            rd.angle = rd.angle + rd.speed * rd.dir * dt
            for _, b in ipairs(rd.blocks) do
                local ref = b.isModel and b.model or b.part
                if not ref or not ref.Parent then continue end
                local angle = math.rad(rd.angle + b.angleOffset)
                -- Локальная точка на кольце
                local lx = math.cos(angle) * rd.radius
                local ly = 0
                local lz = math.sin(angle) * rd.radius
                -- Наклон по X
                local y1 = ly * math.cos(rd.tiltX) - lz * math.sin(rd.tiltX)
                local z1 = ly * math.sin(rd.tiltX) + lz * math.cos(rd.tiltX)
                -- Наклон по Y
                local x2 = lx * math.cos(rd.tiltY) - z1 * math.sin(rd.tiltY)
                local z2 = lx * math.sin(rd.tiltY) + z1 * math.cos(rd.tiltY)
                local pos = hrp.Position + Vector3.new(x2, rd.height + y1, z2)

                local lookAngle = math.atan2(-(pos.X - hrp.Position.X), -(pos.Z - hrp.Position.Z))
                local cf = CFrame.new(pos) * CFrame.Angles(rd.tiltX, lookAngle + math.pi, rd.tiltY)
                if b.isModel and b.model then
                    b.model:PivotTo(cf)
                else
                    b.part.CFrame = cf
                end
                -- Радуга по кольцу и времени
                local hue = (t * 0.2 + rd.colorShift + angle / (math.pi * 2)) % 1
                local c = Color3.fromHSV(hue, 0.9, 1)
                if b.bodyParts then
                    for _, p in ipairs(b.bodyParts) do
                        if not p:GetAttribute("NoRecolor") then p.Color = c end
                    end
                elseif b.part then
                    b.part.Color = c
                end
            end
        end
    end)

    ORBIT.notify("💀 ХАРДКОР НАГРАДА!", Color3.fromRGB(255, 90, 120), 5)
    ORBIT.notify("🌈 24 КОЛЬЦА ВОКРУГ ТЕБЯ!", Color3.fromRGB(255, 180, 220), 5)
    ORBIT.notify("⏱️ Длится " .. ULTRA.Duration .. " секунд", Color3.fromRGB(200, 200, 255), 4)
    warn("[Orbit MiniGame] Ультра-орбита запущена! Колец: " .. #ULTRA.Blocks)
end

ORBIT.startUltra = startUltra
ORBIT.stopUltra = stopUltra

-- ============================================================
--              ВЫДАЧА НАГРАДЫ
-- ============================================================
local function giveReward()
    local diff = getDifficulty()
    ORBIT.COINS = (ORBIT.COINS or 0) + diff.CoinsReward

    if ORBIT.HAS_FS then
        pcall(function()
            writefile(ORBIT.COINS_FILE or "orbit_v21_coins.json", tostring(ORBIT.COINS))
        end)
    end
    pcall(function() if ORBIT.saveSettings then ORBIT.saveSettings() end end)

    ORBIT.notify("💰 +" .. diff.CoinsReward .. " монет", Color3.fromRGB(255, 220, 120), 4)

    if diff.GiveUltra then
        startUltra()
    else
        startRewardAnimation()
    end

    if ORBIT.playWin then pcall(ORBIT.playWin) end
    return true
end

-- ============================================================
--              СОСТОЯНИЕ ИГРЫ
-- ============================================================
local MINIGAME = {
    Open     = false,
    Playing  = false,
    Caught   = 0,
    TimeLeft = 20,
    Stars    = {},
    Conn     = nil,
    -- 🐛 ФИКС v23.6: кэш ссылок на элементы GUI (не дёргаем FindFirstChild с recursive=true)
    Fields   = {
        playField   = nil,
        progressLbl = nil,
        timerLbl    = nil,
        winBanner   = nil,
    },
    -- 🐛 ФИКС v23.6: идентификатор текущей игры — защита от «зависшего» task.delay
    RunId    = 0,
}

local minigameGui

-- ============================================================
--              СПАВН ЗВЁЗД
-- ============================================================
local function spawnStar()
    if not minigameGui or not MINIGAME.Playing then return end
    -- 🐛 ФИКС v23.6: используем кэш, не ищем рекурсивно
    local field = MINIGAME.Fields.playField
    if not field or not field.Parent then return end
    local diff = getDifficulty()

    local starSize = math.random(diff.StarMinSize, diff.StarMaxSize)

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
    if fieldSize.X < 10 or fieldSize.Y < 10 then return end

    local margin = math.floor(starSize * 0.5)
    local maxX = math.max(margin + 1, math.floor(fieldSize.X - starSize - margin))
    local maxY = math.max(margin + 1, math.floor(fieldSize.Y - starSize - margin))
    local x = math.random(margin, maxX)
    local y = math.random(margin, maxY)

    btn.Position = UDim2.new(0, x, 0, y)
    btn.Parent = field
    btn.TextTransparency = 1
    TweenService:Create(btn, TweenInfo.new(0.15), {TextTransparency = 0}):Play()

    local data = {
        frame = btn,
        born = tick(),
        duration = diff.StarLifetime + math.random() * 0.6,
        caught = false,
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

        -- 🐛 ФИКС v23.6: прогресс-лейбл из кэша
        local progressLbl = MINIGAME.Fields.progressLbl
        if progressLbl and progressLbl.Parent then
            progressLbl.Text = "⭐ " .. MINIGAME.Caught .. " / " .. diff.TargetCount
        end

        task.delay(0.3, function() pcall(function() btn:Destroy() end) end)

        if MINIGAME.Caught >= diff.TargetCount then
            MINIGAME.Playing = false
            if ORBIT.playDodge then ORBIT.playDodge() end
            task.delay(0.5, function()
                local rewarded = giveReward()
                -- 🐛 ФИКС v23.6: win-banner из кэша
                local winBanner = MINIGAME.Fields.winBanner
                if winBanner and winBanner.Parent and rewarded then
                    winBanner.Visible = true
                    winBanner.Text = diff.GiveUltra
                        and "💀 ХАРДКОР ПРОЙДЕН!\n🌈 24 КОЛЬЦА + " .. diff.CoinsReward .. " МОНЕТ"
                        or ("🏆 ПОБЕДА! 🏆\n" .. diff.CoinsReward .. " МОНЕТ")
                    winBanner.TextColor3 = diff.GiveUltra
                        and Color3.fromRGB(255, 120, 160)
                        or Color3.fromRGB(255, 215, 0)
                end
            end)
        end
    end

    btn.MouseButton1Down:Connect(catch)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then catch() end
    end)
end

-- ============================================================
--              ЦИКЛ ИГРЫ
-- ============================================================
local function startGameLoop()
    if MINIGAME.Conn then MINIGAME.Conn:Disconnect() end
    MINIGAME.Conn = RunService.Heartbeat:Connect(function(dt)
        if not MINIGAME.Playing then return end
        local diff = getDifficulty()

        MINIGAME.TimeLeft = MINIGAME.TimeLeft - dt
        -- 🐛 ФИКС v23.6: таймер-лейбл из кэша (раньше искали каждый кадр)
        local timerLbl = MINIGAME.Fields.timerLbl
        if timerLbl and timerLbl.Parent then
            timerLbl.Text = "⏱️ " .. string.format("%.1f", math.max(0, MINIGAME.TimeLeft)) .. "с"
            timerLbl.TextColor3 = MINIGAME.TimeLeft <= 5
                and Color3.fromRGB(255, 80, 80)
                or Color3.fromRGB(255, 220, 120)
        end

        if MINIGAME.TimeLeft <= 0 then
            MINIGAME.Playing = false
            -- 🐛 ФИКС v23.6: win-banner из кэша
            local winBanner = MINIGAME.Fields.winBanner
            if winBanner and winBanner.Parent then
                winBanner.Visible = true
                winBanner.Text = "⏰ ВРЕМЯ ВЫШЛО! Поймано: " .. MINIGAME.Caught .. "/" .. diff.TargetCount
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
                -- поймана
            elseif now - s.born > s.duration then
                pcall(function() s.frame:Destroy() end)
                table.remove(MINIGAME.Stars, i)
            else
                activeStars = activeStars + 1
            end
        end

        if activeStars < 3 and math.random() < dt * diff.SpawnRate then
            spawnStar()
        end
    end)
end

-- ============================================================
--              UI МИНИ-ИГРЫ
-- ============================================================
local function closeMiniGame()
    MINIGAME.Open = false
    MINIGAME.Playing = false
    MINIGAME.RunId = MINIGAME.RunId + 1      -- 🐛 ФИКС v23.6: гасим отложенные колбэки
    if MINIGAME.Conn then MINIGAME.Conn:Disconnect(); MINIGAME.Conn = nil end
    for _, s in ipairs(MINIGAME.Stars) do
        pcall(function() if s.frame then s.frame:Destroy() end end)
    end
    MINIGAME.Stars = {}
    -- 🐛 ФИКС v23.6: чистим кэш ссылок
    MINIGAME.Fields.playField   = nil
    MINIGAME.Fields.progressLbl = nil
    MINIGAME.Fields.timerLbl    = nil
    MINIGAME.Fields.winBanner   = nil
    if minigameGui then
        pcall(function() minigameGui:Destroy() end)
        minigameGui = nil
    end
end

local function openMiniGame()
    if MINIGAME.Open then return end
    MINIGAME.Open = true

    local mgW = IS_MOBILE and 340 or 500
    local mgH = IS_MOBILE and 520 or 490

    minigameGui = Instance.new("Frame")
    minigameGui.Name = "_OrbitMiniGame"
    minigameGui.Size = UDim2.new(0, mgW, 0, mgH)
    minigameGui.Position = UDim2.new(0.5, -mgW/2, 0.5, -mgH/2)
    minigameGui.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    minigameGui.BackgroundTransparency = 0.05
    minigameGui.BorderSizePixel = 0
    minigameGui.ZIndex = 30
    minigameGui.Parent = screenGui
    Instance.new("UICorner", minigameGui).CornerRadius = UDim.new(0, 16)
    local str = Instance.new("UIStroke", minigameGui)
    str.Color = Color3.fromRGB(200, 150, 255)
    str.Thickness = 2

    if ORBIT.ui.fitToScreen then
        ORBIT.ui.fitToScreen(minigameGui, mgW, mgH)
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 30)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🎮  ЛОВЛЯ ЗВЁЗД"
    title.TextColor3 = Color3.fromRGB(255, 220, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 31
    title.Parent = minigameGui

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 31
    closeBtn.Parent = minigameGui
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    onClick(closeBtn, closeMiniGame)

    -- Строка сложности
    local diffBtn = Instance.new("TextButton")
    diffBtn.Size = UDim2.new(1, -32, 0, 32)
    diffBtn.Position = UDim2.new(0, 16, 0, 42)
    diffBtn.BackgroundColor3 = Color3.fromRGB(45, 40, 70)
    diffBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
    diffBtn.Font = Enum.Font.GothamBold
    diffBtn.TextSize = 12
    diffBtn.ZIndex = 31
    diffBtn.Parent = minigameGui
    Instance.new("UICorner", diffBtn).CornerRadius = UDim.new(0, 8)

    local rules = Instance.new("TextLabel")
    rules.Size = UDim2.new(1, -32, 0, 34)
    rules.Position = UDim2.new(0, 16, 0, 80)
    rules.BackgroundTransparency = 1
    rules.TextColor3 = Color3.fromRGB(220, 200, 255)
    rules.Font = Enum.Font.Gotham
    rules.TextSize = 11
    rules.TextWrapped = true
    rules.TextXAlignment = Enum.TextXAlignment.Center
    rules.ZIndex = 31
    rules.Parent = minigameGui

    local progressLbl = Instance.new("TextLabel")
    progressLbl.Name = "_ProgressLbl"
    progressLbl.Size = UDim2.new(0, 200, 0, 24)
    progressLbl.Position = UDim2.new(0, 16, 0, 120)
    progressLbl.BackgroundColor3 = Color3.fromRGB(40, 60, 45)
    progressLbl.BorderSizePixel = 0
    progressLbl.Text = "⭐ 0 / 10"
    progressLbl.TextColor3 = Color3.fromRGB(180, 255, 180)
    progressLbl.Font = Enum.Font.GothamBold
    progressLbl.TextSize = 13
    progressLbl.ZIndex = 31
    progressLbl.Parent = minigameGui
    Instance.new("UICorner", progressLbl).CornerRadius = UDim.new(0, 8)

    local timerLbl = Instance.new("TextLabel")
    timerLbl.Name = "_TimerLbl"
    timerLbl.Size = UDim2.new(0, 200, 0, 24)
    timerLbl.Position = UDim2.new(1, -216, 0, 120)
    timerLbl.BackgroundColor3 = Color3.fromRGB(60, 45, 30)
    timerLbl.BorderSizePixel = 0
    timerLbl.Text = "⏱️ 20.0с"
    timerLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
    timerLbl.Font = Enum.Font.GothamBold
    timerLbl.TextSize = 13
    timerLbl.ZIndex = 31
    timerLbl.Parent = minigameGui
    Instance.new("UICorner", timerLbl).CornerRadius = UDim.new(0, 8)

    local playField = Instance.new("Frame")
    playField.Name = "_PlayField"
    playField.Size = UDim2.new(1, -32, 0, IS_MOBILE and 260 or 260)
    playField.Position = UDim2.new(0, 16, 0, 150)
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
    winBanner.Size = UDim2.new(1, -32, 0, 60)
    winBanner.Position = UDim2.new(0, 16, 0, 150 + 260 + 6)
    winBanner.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
    winBanner.BackgroundTransparency = 0.05
    winBanner.BorderSizePixel = 0
    winBanner.Text = ""
    winBanner.TextColor3 = Color3.fromRGB(255, 255, 255)
    winBanner.Font = Enum.Font.GothamBold
    winBanner.TextSize = 14
    winBanner.TextWrapped = true
    winBanner.Visible = false
    winBanner.ZIndex = 40
    winBanner.Parent = minigameGui
    Instance.new("UICorner", winBanner).CornerRadius = UDim.new(0, 12)
    local bannerStroke = Instance.new("UIStroke", winBanner)
    bannerStroke.Color = Color3.fromRGB(255, 220, 120)
    bannerStroke.Thickness = 2

    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(1, -32, 0, 40)
    startBtn.Position = UDim2.new(0, 16, 1, -50)
    startBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
    startBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 14
    startBtn.Text = "▶  СТАРТ"
    startBtn.ZIndex = 31
    startBtn.Parent = minigameGui
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)

    -- 🐛 ФИКС v23.6: сохраняем ссылки в кэш (используются в spawnStar / startGameLoop)
    MINIGAME.Fields.playField   = playField
    MINIGAME.Fields.progressLbl = progressLbl
    MINIGAME.Fields.timerLbl    = timerLbl
    MINIGAME.Fields.winBanner   = winBanner

    -- Функции обновления текстов по сложности
    local function refreshDifficultyUI()
        local diff = getDifficulty()
        diffBtn.Text = diff.icon .. " СЛОЖНОСТЬ: " .. diff.name .. "  →"
        diffBtn.BackgroundColor3 = Color3.fromRGB(
            math.floor(diff.Color.R * 80),
            math.floor(diff.Color.G * 80),
            math.floor(diff.Color.B * 80))
        diffBtn.TextColor3 = diff.Color
        rules.Text = "Поймай " .. diff.TargetCount .. " звёзд за " .. diff.TimeLimit .. " сек!\n"
            .. "🏆 Награда: " .. diff.CoinsReward .. " монет"
            .. (diff.GiveUltra and " + 🌈 24 КОЛЬЦА" or "")
        progressLbl.Text = "⭐ 0 / " .. diff.TargetCount
        timerLbl.Text = "⏱️ " .. diff.TimeLimit .. ".0с"
    end

    onClick(diffBtn, function()
        if MINIGAME.Playing then
            ORBIT.notify("⏳ Сложность не меняется во время игры", Color3.fromRGB(255, 200, 120), 2)
            return
        end
        difficultyIndex = difficultyIndex + 1
        if difficultyIndex > #DIFFICULTIES then difficultyIndex = 1 end
        refreshDifficultyUI()
        winBanner.Visible = false
    end)

    refreshDifficultyUI()

    onClick(startBtn, function()
        local diff = getDifficulty()
        MINIGAME.Playing = true
        MINIGAME.Caught = 0
        MINIGAME.TimeLeft = diff.TimeLimit
        -- 🐛 ФИКС v23.6: новая игра = новый RunId — старые отложенные колбэки перестанут срабатывать
        MINIGAME.RunId = MINIGAME.RunId + 1
        local myRunId = MINIGAME.RunId

        for _, s in ipairs(MINIGAME.Stars) do
            pcall(function() if s.frame then s.frame:Destroy() end end)
        end
        MINIGAME.Stars = {}

        winBanner.Visible = false
        progressLbl.Text = "⭐ 0 / " .. diff.TargetCount
        timerLbl.Text = "⏱️ " .. diff.TimeLimit .. ".0с"
        timerLbl.TextColor3 = Color3.fromRGB(255, 220, 120)

        startBtn.Text = "🎯 ИГРА ИДЁТ..."
        startBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        startBtn.TextColor3 = Color3.fromRGB(200, 200, 200)

        startGameLoop()

        task.delay(diff.TimeLimit + 1, function()
            -- 🐛 ФИКС v23.6: если запустилась новая игра или окно закрыто — молчим
            if MINIGAME.RunId ~= myRunId then return end
            if startBtn and startBtn.Parent then
                startBtn.Text = "▶  ИГРАТЬ СНОВА"
                startBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
                startBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
            end
        end)
    end)

    local tip = Instance.new("TextLabel")
    tip.Size = UDim2.new(1, -32, 0, 18)
    tip.Position = UDim2.new(0, 16, 1, -20)
    tip.BackgroundTransparency = 1
    tip.Text = "💀 Хардкор → 24 кольца вокруг тебя на 60 сек"
    tip.TextColor3 = Color3.fromRGB(255, 150, 180)
    tip.Font = Enum.Font.Gotham
    tip.TextSize = 10
    tip.ZIndex = 31
    tip.Parent = minigameGui
end

-- ============================================================
--              ЭКСПОРТ API
-- ============================================================
ORBIT.openMiniGame = openMiniGame
ORBIT.closeMiniGame = closeMiniGame
ORBIT.stopRewardAnimation = stopRewardAnimation
ORBIT.startRewardAnimation = startRewardAnimation
ORBIT.DIFFICULTIES = DIFFICULTIES

if ORBIT.notify then
    ORBIT.notify("🎮 Мини-игра v3.0 загружена (3 сложности)", Color3.fromRGB(220, 200, 255), 3)
end

warn("[Orbit MiniGame] Загружена ✅")

return true
