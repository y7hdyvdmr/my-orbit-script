--[[ ОРБИТА v23.0 — EXTRAS
     🆕 Атмосфера: 7 типов частиц вокруг игрока
     🆕 Трейл-шлейф за игроком
     🆕 Реактивные искры (прыжок / бег / урон)
     Все настройки сохраняются в общий конфиг
     Не требует правок p3/p4 — добавляет кнопки в существующую панель
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Extras] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.panel then warn("[Orbit Extras] UI не готов!"); return end

local Players     = ORBIT.Players
local RunService  = ORBIT.RunService
local Workspace   = ORBIT.Workspace
local TweenService = ORBIT.TweenService
local LocalPlayer = ORBIT.LocalPlayer

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local panel    = ORBIT.ui.panel
local IS_MOBILE = (ORBIT.PLATFORM == "mobile")

-- ============================================================
--       ДЕФОЛТНЫЕ НАСТРОЙКИ EXTRAS
-- ============================================================
SETTINGS.AtmoEnabled        = SETTINGS.AtmoEnabled or false
SETTINGS.AtmoType           = SETTINGS.AtmoType or "Снег"
SETTINGS.AtmoIntensity      = SETTINGS.AtmoIntensity or "Средняя"
SETTINGS.AtmoSize           = SETTINGS.AtmoSize or "Средний"
SETTINGS.TrailStreamEnabled = SETTINGS.TrailStreamEnabled or false
SETTINGS.TrailStreamColorMode = SETTINGS.TrailStreamColorMode or "Радуга"
SETTINGS.ReactSparksEnabled = SETTINGS.ReactSparksEnabled or false

local ATMO_TYPES = {
    {
        name = "Снег", icon = "❄️",
        texture = "rbxasset://textures/particles/sparkles_main.dds",
        colors = {Color3.fromRGB(230, 245, 255), Color3.fromRGB(200, 230, 255)},
        speed = {-3, -1}, spread = Vector2.new(30, 30), rotSpeed = {-20, 20},
        gravity = 0.15,
    },
    {
        name = "Дождь", icon = "🌧️",
        texture = "rbxasset://textures/particles/sparkles_main.dds",
        colors = {Color3.fromRGB(140, 180, 255), Color3.fromRGB(100, 150, 220)},
        speed = {-20, -10}, spread = Vector2.new(8, 8), rotSpeed = {0, 0},
        gravity = 0.5,
    },
    {
        name = "Лепестки", icon = "🌸",
        texture = "rbxasset://textures/particles/sparkles_main.dds",
        colors = {Color3.fromRGB(255, 180, 220), Color3.fromRGB(255, 140, 200)},
        speed = {-2, -0.5}, spread = Vector2.new(180, 180), rotSpeed = {-60, 60},
        gravity = 0.1,
    },
    {
        name = "Искры", icon = "✨",
        texture = "rbxasset://textures/particles/sparkles_main.dds",
        colors = {Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 180, 40)},
        speed = {3, 6}, spread = Vector2.new(180, 180), rotSpeed = {-180, 180},
        gravity = -0.05,
    },
    {
        name = "Звёзды", icon = "⭐",
        texture = "rbxasset://textures/particles/sparkles_main.dds",
        colors = {Color3.fromRGB(255, 255, 220), Color3.fromRGB(220, 230, 255)},
        speed = {0.5, 2}, spread = Vector2.new(180, 180), rotSpeed = {0, 0},
        gravity = -0.02,
    },
    {
        name = "Пузыри", icon = "💧",
        texture = "rbxasset://textures/particles/sparkles_main.dds",
        colors = {Color3.fromRGB(140, 200, 255), Color3.fromRGB(80, 160, 240)},
        speed = {2, 5}, spread = Vector2.new(30, 30), rotSpeed = {0, 0},
        gravity = -0.1,
    },
    {
        name = "Пепел", icon = "🔥",
        texture = "rbxasset://textures/particles/sparkles_main.dds",
        colors = {Color3.fromRGB(255, 100, 40), Color3.fromRGB(200, 60, 20)},
        speed = {-2, -0.5}, spread = Vector2.new(180, 180), rotSpeed = {-30, 30},
        gravity = 0.1,
    },
}
local atmoTypeIndex = 1
for i, t in ipairs(ATMO_TYPES) do
    if t.name == SETTINGS.AtmoType then atmoTypeIndex = i; break end
end

local ATMO_INTENSITY = {
    { name = "Очень слабая", rate = 20 },
    { name = "Слабая",       rate = 50 },
    { name = "Средняя",      rate = 90 },
    { name = "Сильная",      rate = 150 },
    { name = "Очень сильная", rate = 250 },
}
local atmoIntensityIndex = 3
for i, t in ipairs(ATMO_INTENSITY) do
    if t.name == SETTINGS.AtmoIntensity then atmoIntensityIndex = i; break end
end

local ATMO_SIZE = {
    { name = "Крошка",   min = 0.15, max = 0.3 },
    { name = "Мелкий",   min = 0.25, max = 0.5 },
    { name = "Средний",  min = 0.4,  max = 0.8 },
    { name = "Крупный",  min = 0.7,  max = 1.3 },
    { name = "Огромный", min = 1.2,  max = 2.0 },
}
local atmoSizeIndex = 3
for i, t in ipairs(ATMO_SIZE) do
    if t.name == SETTINGS.AtmoSize then atmoSizeIndex = i; break end
end

local TRAIL_STREAM_COLOR_MODES = { "Радуга", "Фикс цвет", "Как у колец" }
local trailStreamColorIndex = 1
for i, m in ipairs(TRAIL_STREAM_COLOR_MODES) do
    if m == SETTINGS.TrailStreamColorMode then trailStreamColorIndex = i; break end
end

-- ============================================================
--       СОСТОЯНИЕ
-- ============================================================
local atmoFolder = nil
local atmoEmitter = nil
local atmoConn = nil
local atmoSeed = 0

local trailStreamFolder = nil
local trailStreamPart = nil
local trailStreamTrail = nil
local trailStreamAttach0 = nil
local trailStreamAttach1 = nil

local reactSparksFolder = nil
local reactSparksConn = nil
local reactLastJump = 0
local reactLastRun = 0
local reactLastHealth = 100
local reactPrevY = 0

-- ============================================================
--       АТМОСФЕРА
-- ============================================================
local function buildAtmoEmitter()
    if atmoFolder then atmoFolder:Destroy(); atmoFolder = nil end
    atmoEmitter = nil
    if not SETTINGS.AtmoEnabled then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    atmoFolder = Instance.new("Folder")
    atmoFolder.Name = "OrbitAtmo_" .. tostring(math.random(1, 999999))
    atmoFolder.Parent = Workspace

    local emitterPart = Instance.new("Part")
    emitterPart.Name = "AtmoEmitter"
    emitterPart.Size = Vector3.new(0.1, 0.1, 0.1)
    emitterPart.Transparency = 1
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.CastShadow = false
    emitterPart.CanQuery = false
    emitterPart.CanTouch = false
    emitterPart.CFrame = hrp.CFrame
    emitterPart.Parent = atmoFolder
    atmoEmitter = emitterPart

    local cfg = ATMO_TYPES[atmoTypeIndex]
    local int = ATMO_INTENSITY[atmoIntensityIndex]
    local size = ATMO_SIZE[atmoSizeIndex]

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = cfg.texture
    pe.Rate = int.rate
    pe.Lifetime = NumberRange.new(2.5, 4.5)
    pe.Speed = NumberRange.new(cfg.speed[1], cfg.speed[2])
    pe.SpreadAngle = cfg.spread
    pe.RotSpeed = NumberRange.new(cfg.rotSpeed[1], cfg.rotSpeed[2])
    pe.Rotation = NumberRange.new(0, 360)
    pe.Acceleration = Vector3.new(0, -cfg.gravity * 20, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size.min),
        NumberSequenceKeypoint.new(0.5, (size.min + size.max) / 2),
        NumberSequenceKeypoint.new(1, size.max),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.7, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.LightEmission = 0.5
    pe.LightInfluence = 0
    -- Цветовая последовательность из 2 цветов
    local c1 = cfg.colors[1]
    local c2 = cfg.colors[2]
    pe.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(0.5, c2),
        ColorSequenceKeypoint.new(1, c1),
    })
    pe.Parent = emitterPart
end

local function updateAtmo()
    if not atmoEmitter or not atmoEmitter.Parent then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Область эмита вокруг игрока радиусом 25
    atmoSeed = atmoSeed + 1
    local offset = Vector3.new(
        math.sin(atmoSeed * 0.7) * 8,
        12 + math.sin(atmoSeed * 0.3) * 4,
        math.cos(atmoSeed * 0.5) * 8
    )
    atmoEmitter.CFrame = CFrame.new(hrp.Position + offset)
end

local function setupAtmo()
    buildAtmoEmitter()
    if atmoConn then atmoConn:Disconnect(); atmoConn = nil end
    if SETTINGS.AtmoEnabled then
        atmoConn = RunService.Heartbeat:Connect(updateAtmo)
    end
end

-- ============================================================
--       ТРЕЙЛ-ШЛЕЙФ ЗА ИГРОКОМ
-- ============================================================
local function buildTrailStream()
    if trailStreamFolder then trailStreamFolder:Destroy(); trailStreamFolder = nil end
    trailStreamPart = nil; trailStreamTrail = nil; trailStreamAttach0 = nil; trailStreamAttach1 = nil
    if not SETTINGS.TrailStreamEnabled then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    trailStreamFolder = Instance.new("Folder")
    trailStreamFolder.Name = "OrbitTrailStream_" .. tostring(math.random(1, 999999))
    trailStreamFolder.Parent = Workspace

    local p = Instance.new("Part")
    p.Name = "TrailAnchor"
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.CanQuery = false
    p.CanTouch = false
    p.CFrame = hrp.CFrame
    p.Parent = trailStreamFolder
    trailStreamPart = p

    trailStreamAttach0 = Instance.new("Attachment")
    trailStreamAttach0.Position = Vector3.new(0, -1.2, 0)
    trailStreamAttach0.Parent = p

    trailStreamAttach1 = Instance.new("Attachment")
    trailStreamAttach1.Position = Vector3.new(0, 1.2, 0)
    trailStreamAttach1.Parent = p

    trailStreamTrail = Instance.new("Trail")
    trailStreamTrail.Attachment0 = trailStreamAttach0
    trailStreamTrail.Attachment1 = trailStreamAttach1
    trailStreamTrail.Lifetime = SETTINGS.TrailLength or 0.5
    trailStreamTrail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, SETTINGS.TrailWidth or 0.8),
        NumberSequenceKeypoint.new(0.7, (SETTINGS.TrailWidth or 0.8) * 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    trailStreamTrail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    trailStreamTrail.FaceCamera = true
    trailStreamTrail.LightEmission = 1
    trailStreamTrail.Parent = p

    local mode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
    local col = SETTINGS.FixedColor or Color3.fromRGB(0, 180, 255)
    if mode == "Радуга" then col = Color3.fromHSV((tick() * 0.2) % 1, 0.9, 1) end
    trailStreamTrail.Color = ColorSequence.new(col)
end

local trailStreamConn = nil
local function setupTrailStream()
    buildTrailStream()
    if trailStreamConn then trailStreamConn:Disconnect(); trailStreamConn = nil end
    if not SETTINGS.TrailStreamEnabled then return end

    trailStreamConn = RunService.Heartbeat:Connect(function(dt)
        if not trailStreamPart or not trailStreamPart.Parent then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        trailStreamPart.CFrame = hrp.CFrame
        local mode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
        if trailStreamTrail then
            if mode == "Радуга" then
                local c = Color3.fromHSV((tick() * 0.2) % 1, 0.9, 1)
                trailStreamTrail.Color = ColorSequence.new(c)
            elseif mode == "Фикс цвет" then
                trailStreamTrail.Color = ColorSequence.new(SETTINGS.FixedColor or Color3.fromRGB(0, 180, 255))
            elseif mode == "Как у колец" then
                local p = P.COLORS[P.colorIndex]
                if p and not p.rainbow then
                    trailStreamTrail.Color = ColorSequence.new(p.c)
                else
                    local c = Color3.fromHSV((tick() * (SETTINGS.RainbowSpeed or 0.15)) % 1, 0.9, 1)
                    trailStreamTrail.Color = ColorSequence.new(c)
                end
            end
        end
    end)
end

-- ============================================================
--       РЕАКТИВНЫЕ ИСКРЫ
-- ============================================================
local function reactBurst(position, color3, count, spread)
    if not reactSparksFolder then
        reactSparksFolder = Instance.new("Folder")
        reactSparksFolder.Name = "OrbitReactSparks"
        reactSparksFolder.Parent = Workspace
    end
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CFrame = CFrame.new(position)
    p.Parent = reactSparksFolder

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 0
    pe.Lifetime = NumberRange.new(0.4, 0.9)
    pe.Speed = NumberRange.new(8, 16)
    pe.SpreadAngle = spread or Vector2.new(180, 180)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    pe.Color = ColorSequence.new(color3 or Color3.fromRGB(255, 220, 100))
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = p
    pe:Emit(count or 20)
    task.delay(1.5, function() pcall(function() p:Destroy() end) end)
end

local function setupReactSparks()
    if reactSparksConn then reactSparksConn:Disconnect(); reactSparksConn = nil end
    if not SETTINGS.ReactSparksEnabled then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    reactLastHealth = hum and hum.Health or 100
    local hrp0 = char and char:FindFirstChild("HumanoidRootPart")
    reactPrevY = hrp0 and hrp0.Position.Y or 0

    reactSparksConn = RunService.Heartbeat:Connect(function(dt)
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        local now = tick()

        -- 1) Прыжок
        local vy = hrp.AssemblyLinearVelocity.Y
        if vy > 25 and (now - reactLastJump) > 1.2 then
            reactLastJump = now
            reactBurst(hrp.Position - Vector3.new(0, 2.5, 0),
                Color3.fromRGB(180, 220, 255), 18, Vector2.new(180, 180))
        end

        -- 2) Бег — искры из-под ног
        local speedXZ = math.sqrt(hrp.AssemblyLinearVelocity.X^2 + hrp.AssemblyLinearVelocity.Z^2)
        if speedXZ > 12 and (now - reactLastRun) > 0.35 then
            reactLastRun = now
            reactBurst(hrp.Position - Vector3.new(0, 2.7, 0),
                Color3.fromRGB(255, 200, 100), 6, Vector2.new(40, 40))
        end

        -- 3) Урон
        if hum.Health < reactLastHealth - 5 then
            reactBurst(hrp.Position, Color3.fromRGB(255, 60, 80), 30, Vector2.new(180, 180))
        end
        reactLastHealth = hum.Health
    end)
end

-- ============================================================
--       ПОСТРОЕНИЕ UI (добавляем в panel)
-- ============================================================
local panel = ORBIT.ui.panel
local finalY = panel.CanvasSize.Y.Offset + 12

local BTN_H = IS_MOBILE and 34 or 30

local function makeBigSection(text, y, color)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -20, 0, 26)
    holder.Position = UDim2.new(0, 10, 0, y)
    holder.BackgroundColor3 = color or Color3.fromRGB(55, 55, 90)
    holder.BackgroundTransparency = 0.35
    holder.BorderSizePixel = 0
    holder.ZIndex = 2
    holder.Parent = panel
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)
    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -6)
    stripe.Position = UDim2.new(0, 3, 0, 3)
    stripe.BackgroundColor3 = color or Color3.fromRGB(140, 140, 220)
    stripe.BorderSizePixel = 0
    stripe.ZIndex = 3
    stripe.Parent = holder
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 2)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -14, 1, 0)
    s.Position = UDim2.new(0, 12, 0, 0)
    s.BackgroundTransparency = 1
    s.Text = text
    s.TextColor3 = Color3.fromRGB(240, 240, 255)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 12
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.ZIndex = 3
    s.Parent = holder
    return holder
end

local function makeButton(text, y, h, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or BTN_H)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(45, 45, 62)
    b.TextColor3 = textColor or Color3.fromRGB(235, 235, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = IS_MOBILE and 12 or 11
    b.Text = text
    b.AutoButtonColor = true
    b.ZIndex = 2
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = bgColor or Color3.fromRGB(80, 80, 120)
    stroke.Thickness = 1
    stroke.Transparency = 0.65
    b.MouseButton1Down:Connect(function()
        if ORBIT.playClick then ORBIT.playClick() end
    end)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if ORBIT.playClick then ORBIT.playClick() end
        end
    end)
    return b
end

-- ====== БЛОК: АТМОСФЕРА ======
makeBigSection("❄️  АТМОСФЕРА (вокруг тебя)", finalY, Color3.fromRGB(70, 100, 140))
finalY = finalY + 30

local atmoToggle = makeButton("", finalY, BTN_H + 4, nil, nil)
local atmoTypeBtn = makeButton("", finalY + BTN_H + 8, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
local atmoIntBtn = makeButton("", finalY + BTN_H*2 + 16, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
local atmoSizeBtn = makeButton("", finalY + BTN_H*3 + 24, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H*4 + 32

local function refreshAtmoUI()
    local cfg = ATMO_TYPES[atmoTypeIndex]
    local int = ATMO_INTENSITY[atmoIntensityIndex]
    local sz = ATMO_SIZE[atmoSizeIndex]
    atmoToggle.Text = "❄️ Атмосфера: " .. (SETTINGS.AtmoEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AtmoEnabled then
        atmoToggle.BackgroundColor3 = Color3.fromRGB(50,80,110)
        atmoToggle.TextColor3 = Color3.fromRGB(180,220,255)
    else
        atmoToggle.BackgroundColor3 = Color3.fromRGB(45,45,62)
        atmoToggle.TextColor3 = Color3.fromRGB(220,220,255)
    end
    atmoTypeBtn.Text = cfg.icon .. " Тип: " .. cfg.name
    atmoIntBtn.Text = "📊 Интенсивность: " .. int.name
    atmoSizeBtn.Text = "📏 Размер: " .. sz.name
end
refreshAtmoUI()

atmoToggle.Activated:Connect(function()
    SETTINGS.AtmoEnabled = not SETTINGS.AtmoEnabled
    SETTINGS.AtmoType = ATMO_TYPES[atmoTypeIndex].name
    SETTINGS.AtmoIntensity = ATMO_INTENSITY[atmoIntensityIndex].name
    SETTINGS.AtmoSize = ATMO_SIZE[atmoSizeIndex].name
    refreshAtmoUI()
    setupAtmo()
    ORBIT.notify("❄️ Атмосфера: " .. (SETTINGS.AtmoEnabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(180,220,255), 2)
end)

atmoTypeBtn.Activated:Connect(function()
    atmoTypeIndex = atmoTypeIndex + 1
    if atmoTypeIndex > #ATMO_TYPES then atmoTypeIndex = 1 end
    SETTINGS.AtmoType = ATMO_TYPES[atmoTypeIndex].name
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)

atmoIntBtn.Activated:Connect(function()
    atmoIntensityIndex = atmoIntensityIndex + 1
    if atmoIntensityIndex > #ATMO_INTENSITY then atmoIntensityIndex = 1 end
    SETTINGS.AtmoIntensity = ATMO_INTENSITY[atmoIntensityIndex].name
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)

atmoSizeBtn.Activated:Connect(function()
    atmoSizeIndex = atmoSizeIndex + 1
    if atmoSizeIndex > #ATMO_SIZE then atmoSizeIndex = 1 end
    SETTINGS.AtmoSize = ATMO_SIZE[atmoSizeIndex].name
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)

-- ====== БЛОК: ТРЕЙЛ-ШЛЕЙФ ======
makeBigSection("🌠  ТРЕЙЛ-ШЛЕЙФ", finalY, Color3.fromRGB(100, 70, 140))
finalY = finalY + 30

local trailStreamToggle = makeButton("", finalY, BTN_H + 4, nil, nil)
local trailStreamLenBtn = makeButton("", finalY + BTN_H + 8, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
local trailStreamWidBtn = makeButton("", finalY + BTN_H*2 + 16, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
local trailStreamColorBtn = makeButton("", finalY + BTN_H*3 + 24, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H*4 + 32

local function refreshTrailStreamUI()
    trailStreamToggle.Text = "🌠 Шлейф: " .. (SETTINGS.TrailStreamEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.TrailStreamEnabled then
        trailStreamToggle.BackgroundColor3 = Color3.fromRGB(75,50,100)
        trailStreamToggle.TextColor3 = Color3.fromRGB(230,200,255)
    else
        trailStreamToggle.BackgroundColor3 = Color3.fromRGB(45,45,62)
        trailStreamToggle.TextColor3 = Color3.fromRGB(220,220,255)
    end
    local len = P.TRAIL_LEN and P.TRAIL_LEN[P.trailLengthIndex]
    local wid = P.TRAIL_WID and P.TRAIL_WID[P.trailWidthIndex]
    trailStreamLenBtn.Text = "📏 Длина: " .. (len and len.name or "Средний")
    trailStreamWidBtn.Text = "🎚️ Толщина: " .. (wid and wid.name or "Средний")
    trailStreamColorBtn.Text = "🎨 Цвет: " .. TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
end
refreshTrailStreamUI()

trailStreamToggle.Activated:Connect(function()
    SETTINGS.TrailStreamEnabled = not SETTINGS.TrailStreamEnabled
    SETTINGS.TrailStreamColorMode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
    refreshTrailStreamUI()
    setupTrailStream()
    ORBIT.notify("🌠 Шлейф: " .. (SETTINGS.TrailStreamEnabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(230,200,255), 2)
end)

trailStreamLenBtn.Activated:Connect(function()
    if not P.TRAIL_LEN then return end
    P.trailLengthIndex = P.trailLengthIndex + 1
    if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    refreshTrailStreamUI()
    if trailStreamTrail then trailStreamTrail.Lifetime = SETTINGS.TrailLength end
end)
trailStreamWidBtn.Activated:Connect(function()
    if not P.TRAIL_WID then return end
    P.trailWidthIndex = P.trailWidthIndex + 1
    if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    refreshTrailStreamUI()
    if trailStreamTrail then
        trailStreamTrail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, SETTINGS.TrailWidth),
            NumberSequenceKeypoint.new(0.7, SETTINGS.TrailWidth * 0.5),
            NumberSequenceKeypoint.new(1, 0),
        })
    end
end)
trailStreamColorBtn.Activated:Connect(function()
    trailStreamColorIndex = trailStreamColorIndex + 1
    if trailStreamColorIndex > #TRAIL_STREAM_COLOR_MODES then trailStreamColorIndex = 1 end
    SETTINGS.TrailStreamColorMode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
    refreshTrailStreamUI()
end)

-- ====== БЛОК: РЕАКТИВНЫЕ ИСКРЫ ======
makeBigSection("💥  РЕАКТИВНЫЕ ИСКРЫ", finalY, Color3.fromRGB(140, 80, 50))
finalY = finalY + 30

local reactToggle = makeButton("", finalY, BTN_H + 4, nil, nil)
finalY = finalY + BTN_H + 12

local reactHint = Instance.new("TextLabel")
reactHint.Size = UDim2.new(1, -20, 0, 40)
reactHint.Position = UDim2.new(0, 10, 0, finalY)
reactHint.BackgroundColor3 = Color3.fromRGB(35, 25, 20)
reactHint.BackgroundTransparency = 0.3
reactHint.BorderSizePixel = 0
reactHint.Text = "Искры при прыжке / беге / получении урона"
reactHint.TextColor3 = Color3.fromRGB(220, 200, 180)
reactHint.Font = Enum.Font.Gotham
reactHint.TextSize = 10
reactHint.TextWrapped = true
reactHint.ZIndex = 2
reactHint.Parent = panel
Instance.new("UICorner", reactHint).CornerRadius = UDim.new(0, 6)
finalY = finalY + 46

local function refreshReactUI()
    reactToggle.Text = "💥 Реактивные искры: " .. (SETTINGS.ReactSparksEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.ReactSparksEnabled then
        reactToggle.BackgroundColor3 = Color3.fromRGB(110,60,40)
        reactToggle.TextColor3 = Color3.fromRGB(255,220,180)
    else
        reactToggle.BackgroundColor3 = Color3.fromRGB(45,45,62)
        reactToggle.TextColor3 = Color3.fromRGB(220,220,255)
    end
end
refreshReactUI()

reactToggle.Activated:Connect(function()
    SETTINGS.ReactSparksEnabled = not SETTINGS.ReactSparksEnabled
    refreshReactUI()
    setupReactSparks()
    ORBIT.notify("💥 Реактивные искры: " .. (SETTINGS.ReactSparksEnabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(255,200,140), 2)
end)

-- Обновляем CanvasSize
panel.CanvasSize = UDim2.new(0, 0, 0, finalY + 20)

-- ============================================================
--       ПОДПИСКА НА СМЕРТЬ/РЕСПАВН
-- ============================================================
local function rebuildOnChar()
    if SETTINGS.AtmoEnabled then setupAtmo() end
    if SETTINGS.TrailStreamEnabled then setupTrailStream() end
    if SETTINGS.ReactSparksEnabled then setupReactSparks() end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    rebuildOnChar()
end)

-- ============================================================
--       ИНИЦИАЛИЗАЦИЯ
-- ============================================================
if SETTINGS.AtmoEnabled then setupAtmo() end
if SETTINGS.TrailStreamEnabled then setupTrailStream() end
if SETTINGS.ReactSparksEnabled then setupReactSparks() end

-- Синхронизация при загрузке сохранений
local origLoad = ORBIT.loadSettings
if origLoad then
    ORBIT.loadSettings = function(...)
        local ok = origLoad(...)
        -- Перечитать настройки extras из SETTINGS
        for i, t in ipairs(ATMO_TYPES) do
            if t.name == SETTINGS.AtmoType then atmoTypeIndex = i; break end
        end
        for i, t in ipairs(ATMO_INTENSITY) do
            if t.name == SETTINGS.AtmoIntensity then atmoIntensityIndex = i; break end
        end
        for i, t in ipairs(ATMO_SIZE) do
            if t.name == SETTINGS.AtmoSize then atmoSizeIndex = i; break end
        end
        for i, m in ipairs(TRAIL_STREAM_COLOR_MODES) do
            if m == SETTINGS.TrailStreamColorMode then trailStreamColorIndex = i; break end
        end
        refreshAtmoUI(); refreshTrailStreamUI(); refreshReactUI()
        rebuildOnChar()
        return ok
    end
end

ORBIT.extras = {
    setupAtmo = setupAtmo,
    setupTrailStream = setupTrailStream,
    setupReactSparks = setupReactSparks,
    reactBurst = reactBurst,
}

if ORBIT.notify then
    ORBIT.notify("❄️ Extras v23.0: атмосфера, шлейф, искры", Color3.fromRGB(180,220,255), 3)
end

warn("[Orbit Extras] Загружен ✅")
return true
