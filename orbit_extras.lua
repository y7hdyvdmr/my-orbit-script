--[[ ОРБИТА v23.1 — EXTRAS
     🆕 Атмосфера: 7 типов + выбор из 50 цветов
     🆕 Трейл-шлейф за игроком + 50 цветов
     🆕 Реактивные искры + 50 цветов
     Все настройки сохраняются в общий конфиг
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
--       ДЕФОЛТНЫЕ НАСТРОЙКИ
-- ============================================================
SETTINGS.AtmoEnabled        = SETTINGS.AtmoEnabled or false
SETTINGS.AtmoType           = SETTINGS.AtmoType or "Снег"
SETTINGS.AtmoIntensity      = SETTINGS.AtmoIntensity or "Средняя"
SETTINGS.AtmoSize           = SETTINGS.AtmoSize or "Средний"
SETTINGS.AtmoColorMode      = SETTINGS.AtmoColorMode or "Авто"
SETTINGS.AtmoColorIndex     = SETTINGS.AtmoColorIndex or 1
SETTINGS.TrailStreamEnabled = SETTINGS.TrailStreamEnabled or false
SETTINGS.TrailStreamColorMode = SETTINGS.TrailStreamColorMode or "Радуга"
SETTINGS.TrailStreamColorIndex = SETTINGS.TrailStreamColorIndex or 1
SETTINGS.ReactSparksEnabled = SETTINGS.ReactSparksEnabled or false
SETTINGS.ReactSparksColorIndex = SETTINGS.ReactSparksColorIndex or 1

-- ============================================================
--       СПИСОК 50 ЦВЕТОВ (берём из ORBIT.P.COLORS)
-- ============================================================
local COLORS_LIST = P and P.COLORS or {
    {name="РАДУГА",rainbow=true},
    {name="КРАСНЫЙ",c=Color3.fromRGB(255,50,50)},
    {name="ЗЕЛЁНЫЙ",c=Color3.fromRGB(0,255,120)},
    {name="СИНИЙ",c=Color3.fromRGB(40,80,255)},
}
local function getColorByIndex(i)
    if not COLORS_LIST or #COLORS_LIST == 0 then return Color3.fromRGB(255,255,255) end
    local c = COLORS_LIST[((i - 1) % #COLORS_LIST) + 1]
    if c.rainbow then
        return Color3.fromHSV((tick() * 0.2) % 1, 0.9, 1)
    end
    return c.c or Color3.fromRGB(255,255,255)
end
local function getColorNameByIndex(i)
    if not COLORS_LIST or #COLORS_LIST == 0 then return "?" end
    return COLORS_LIST[((i - 1) % #COLORS_LIST) + 1].name or "?"
end

-- ============================================================
--       ТИПЫ АТМОСФЕРЫ
-- ============================================================
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

local TRAIL_STREAM_COLOR_MODES = { "Радуга", "Из списка 50", "Как у колец" }
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

    -- 🆕 Режим цвета
    if SETTINGS.AtmoColorMode == "Авто" then
        local c1 = cfg.colors[1]
        local c2 = cfg.colors[2]
        pe.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c1),
            ColorSequenceKeypoint.new(0.5, c2),
            ColorSequenceKeypoint.new(1, c1),
        })
    else
        -- Из 50 цветов
        local col = getColorByIndex(SETTINGS.AtmoColorIndex)
        pe.Color = ColorSequence.new(col)
    end
    pe.Parent = emitterPart
end

local function updateAtmo()
    if not atmoEmitter or not atmoEmitter.Parent then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    atmoSeed = atmoSeed + 1
    local offset = Vector3.new(
        math.sin(atmoSeed * 0.7) * 8,
        12 + math.sin(atmoSeed * 0.3) * 4,
        math.cos(atmoSeed * 0.5) * 8
    )
    atmoEmitter.CFrame = CFrame.new(hrp.Position + offset)

    -- 🆕 Обновляем цвет каждый кадр, если не Авто
    if SETTINGS.AtmoColorMode ~= "Авто" then
        local pe = atmoEmitter:FindFirstChildOfClass("ParticleEmitter")
        if pe then
            local col = getColorByIndex(SETTINGS.AtmoColorIndex)
            pe.Color = ColorSequence.new(col)
        end
    end
end

local function setupAtmo()
    buildAtmoEmitter()
    if atmoConn then atmoConn:Disconnect(); atmoConn = nil end
    if SETTINGS.AtmoEnabled then
        atmoConn = RunService.Heartbeat:Connect(updateAtmo)
    end
end

-- ============================================================
--       ТРЕЙЛ-ШЛЕЙФ
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
    local col
    if mode == "Радуга" then
        col = Color3.fromHSV((tick() * 0.2) % 1, 0.9, 1)
    elseif mode == "Из списка 50" then
        col = getColorByIndex(SETTINGS.TrailStreamColorIndex)
    else
        col = SETTINGS.FixedColor or Color3.fromRGB(0, 180, 255)
    end
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
            elseif mode == "Из списка 50" then
                local c = getColorByIndex(SETTINGS.TrailStreamColorIndex)
                trailStreamTrail.Color = ColorSequence.new(c)
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

    reactSparksConn = RunService.Heartbeat:Connect(function(dt)
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        local now = tick()
        local sparkColor = getColorByIndex(SETTINGS.ReactSparksColorIndex)

        -- 1) Прыжок
        local vy = hrp.AssemblyLinearVelocity.Y
        if vy > 25 and (now - reactLastJump) > 1.2 then
            reactLastJump = now
            reactBurst(hrp.Position - Vector3.new(0, 2.5, 0),
                sparkColor, 18, Vector2.new(180, 180))
        end

        -- 2) Бег
        local speedXZ = math.sqrt(hrp.AssemblyLinearVelocity.X^2 + hrp.AssemblyLinearVelocity.Z^2)
        if speedXZ > 12 and (now - reactLastRun) > 0.35 then
            reactLastRun = now
            reactBurst(hrp.Position - Vector3.new(0, 2.7, 0),
                sparkColor, 6, Vector2.new(40, 40))
        end

        -- 3) Урон
        if hum.Health < reactLastHealth - 5 then
            reactBurst(hrp.Position, Color3.fromRGB(255, 60, 80), 30, Vector2.new(180, 180))
        end
        reactLastHealth = hum.Health
    end)
end

-- ============================================================
--       UI (добавляем в panel)
-- ============================================================
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
finalY = finalY + BTN_H + 8
local atmoTypeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + S_STEP or (finalY + BTN_H + 4)
local atmoIntBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local atmoSizeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
-- 🆕 Режим цвета
local atmoColorModeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 4
-- 🆕 Выбор цвета из 50
local atmoColorBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 10

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
    atmoColorModeBtn.Text = "🎨 Режим: " .. SETTINGS.AtmoColorMode
    local cname = getColorNameByIndex(SETTINGS.AtmoColorIndex)
    local ccol = getColorByIndex(SETTINGS.AtmoColorIndex)
    atmoColorBtn.Text = "🌈 Цвет: " .. cname
    atmoColorBtn.TextColor3 = ccol
    if SETTINGS.AtmoColorMode == "Авто" then
        atmoColorBtn.BackgroundTransparency = 0.7
    else
        atmoColorBtn.BackgroundTransparency = 0
        atmoColorBtn.BackgroundColor3 = Color3.new(ccol.R*0.3, ccol.G*0.3, ccol.B*0.3)
    end
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

-- 🆕 Режим цвета: Авто / Из списка 50
local ATMO_COLOR_MODES = {"Авто", "Из списка 50"}
local atmoColorModeIndex = 1
for i, m in ipairs(ATMO_COLOR_MODES) do
    if m == SETTINGS.AtmoColorMode then atmoColorModeIndex = i; break end
end
atmoColorModeBtn.Activated:Connect(function()
    atmoColorModeIndex = atmoColorModeIndex + 1
    if atmoColorModeIndex > #ATMO_COLOR_MODES then atmoColorModeIndex = 1 end
    SETTINGS.AtmoColorMode = ATMO_COLOR_MODES[atmoColorModeIndex]
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)

-- 🆕 Выбор цвета из 50
atmoColorBtn.Activated:Connect(function()
    if SETTINGS.AtmoColorMode == "Авто" then
        -- Переключаемся в режим "Из списка 50" автоматически
        SETTINGS.AtmoColorMode = "Из списка 50"
        atmoColorModeIndex = 2
    end
    SETTINGS.AtmoColorIndex = ((SETTINGS.AtmoColorIndex) % #COLORS_LIST) + 1
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
    ORBIT.notify("🎨 Цвет атмосферы: " .. getColorNameByIndex(SETTINGS.AtmoColorIndex),
        getColorByIndex(SETTINGS.AtmoColorIndex), 1.5)
end)

-- ====== БЛОК: ТРЕЙЛ-ШЛЕЙФ ======
makeBigSection("🌠  ТРЕЙЛ-ШЛЕЙФ", finalY, Color3.fromRGB(100, 70, 140))
finalY = finalY + 30

local trailStreamToggle = makeButton("", finalY, BTN_H + 4, nil, nil)
finalY = finalY + BTN_H + 8
local trailStreamLenBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local trailStreamWidBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local trailStreamColorModeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
-- 🆕 Кнопка выбора цвета из 50
local trailStreamColorBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 10

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
    trailStreamColorModeBtn.Text = "🎨 Режим: " .. SETTINGS.TrailStreamColorMode
    local cname = getColorNameByIndex(SETTINGS.TrailStreamColorIndex)
    local ccol = getColorByIndex(SETTINGS.TrailStreamColorIndex)
    trailStreamColorBtn.Text = "🌈 Цвет: " .. cname
    trailStreamColorBtn.TextColor3 = ccol
    if SETTINGS.TrailStreamColorMode == "Из списка 50" then
        trailStreamColorBtn.BackgroundTransparency = 0
        trailStreamColorBtn.BackgroundColor3 = Color3.new(ccol.R*0.3, ccol.G*0.3, ccol.B*0.3)
    else
        trailStreamColorBtn.BackgroundTransparency = 0.7
    end
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
trailStreamColorModeBtn.Activated:Connect(function()
    trailStreamColorIndex = trailStreamColorIndex + 1
    if trailStreamColorIndex > #TRAIL_STREAM_COLOR_MODES then trailStreamColorIndex = 1 end
    SETTINGS.TrailStreamColorMode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
    refreshTrailStreamUI()
end)
-- 🆕 Выбор цвета из 50
trailStreamColorBtn.Activated:Connect(function()
    if SETTINGS.TrailStreamColorMode ~= "Из списка 50" then
        SETTINGS.TrailStreamColorMode = "Из списка 50"
        trailStreamColorIndex = 2
    end
    SETTINGS.TrailStreamColorIndex = ((SETTINGS.TrailStreamColorIndex) % #COLORS_LIST) + 1
    refreshTrailStreamUI()
    ORBIT.notify("🌈 Цвет шлейфа: " .. getColorNameByIndex(SETTINGS.TrailStreamColorIndex),
        getColorByIndex(SETTINGS.TrailStreamColorIndex), 1.5)
end)

-- ====== БЛОК: РЕАКТИВНЫЕ ИСКРЫ ======
makeBigSection("💥  РЕАКТИВНЫЕ ИСКРЫ", finalY, Color3.fromRGB(140, 80, 50))
finalY = finalY + 30

local reactToggle = makeButton("", finalY, BTN_H + 4, nil, nil)
finalY = finalY + BTN_H + 8
-- 🆕 Кнопка выбора цвета из 50
local reactColorBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 8

local reactHint = Instance.new("TextLabel")
reactHint.Size = UDim2.new(1, -20, 0, 40)
reactHint.Position = UDim2.new(0, 10, 0, finalY)
reactHint.BackgroundColor3 = Color3.fromRGB(35, 25, 20)
reactHint.BackgroundTransparency = 0.3
reactHint.BorderSizePixel = 0
reactHint.Text = "Искры при прыжке / беге (в момент урона — красные)"
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
    local cname = getColorNameByIndex(SETTINGS.ReactSparksColorIndex)
    local ccol = getColorByIndex(SETTINGS.ReactSparksColorIndex)
    reactColorBtn.Text = "🌈 Цвет искр: " .. cname
    reactColorBtn.TextColor3 = ccol
    reactColorBtn.BackgroundColor3 = Color3.new(ccol.R*0.3, ccol.G*0.3, ccol.B*0.3)
end
refreshReactUI()

reactToggle.Activated:Connect(function()
    SETTINGS.ReactSparksEnabled = not SETTINGS.ReactSparksEnabled
    refreshReactUI()
    setupReactSparks()
    ORBIT.notify("💥 Реактивные искры: " .. (SETTINGS.ReactSparksEnabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(255,200,140), 2)
end)

reactColorBtn.Activated:Connect(function()
    SETTINGS.ReactSparksColorIndex = ((SETTINGS.ReactSparksColorIndex) % #COLORS_LIST) + 1
    refreshReactUI()
    ORBIT.notify("💥 Цвет искр: " .. getColorNameByIndex(SETTINGS.ReactSparksColorIndex),
        getColorByIndex(SETTINGS.ReactSparksColorIndex), 1.5)
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

ORBIT.extras = {
    setupAtmo = setupAtmo,
    setupTrailStream = setupTrailStream,
    setupReactSparks = setupReactSparks,
    reactBurst = reactBurst,
    getColorByIndex = getColorByIndex,
    getColorNameByIndex = getColorNameByIndex,
}

if ORBIT.notify then
    ORBIT.notify("❄️ Extras v23.1: атмосфера + шлейф + искры с 50 цветами", Color3.fromRGB(180,220,255), 3)
end

warn("[Orbit Extras v23.1] Загружен ✅")
return true
