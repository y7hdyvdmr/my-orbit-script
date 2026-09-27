--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   ОРБИТА ФИГУР v14.0 (Delta Edition - ULTIMATE)          ║
    ║   + 20+ фигур (включая новые: МЕЧ, ЩИТ, КОРОНА, ГЛАЗ...) ║
    ║   + 7 орбитальных узоров (спираль, волна, восьмёрка...)  ║
    ║   + Аура вокруг игрока                                   ║
    ║   + Система уведомлений                                  ║
    ║   + Статистика FPS / фигур / времени                     ║
    ║   + Автосмена фигур                                      ║
    ║   + Градиент-цвета                                       ║
    ║   + Секции в UI                                          ║
    ║   + Автосохранение                                       ║
    ╚══════════════════════════════════════════════════════════╝
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ==================== МЕШИ ====================
local MESH_CONFIG = {
    HandMeshId          = "",
    HandTextureId        = "",
    BlasterMeshId        = "",
    BlasterTextureId      = "",
}

-- ==================== МУЗЫКА ====================
local musicEnabled = false
local musicSound = nil
local savedMusicId = ""
local musicVolume = 0.5

local function createMusicSound()
    if musicSound then return end
    musicSound = Instance.new("Sound")
    musicSound.Name = "OrbitMusic"
    musicSound.Volume = musicVolume
    musicSound.Looped = true
    musicSound.Parent = SoundService
end

local function setMusicId(idText)
    createMusicSound()
    local clean = tostring(idText or ""):gsub("%s", "")
    if clean == "" then return false, "Пустое поле" end
    local num = clean:match("(%d+)")
    if not num then return false, "Не найден ID" end
    local fullId = "rbxassetid://" .. num
    if musicSound.SoundId == fullId then
        if musicEnabled then musicSound:Play() end
        return true
    end
    musicSound.SoundId = fullId
    savedMusicId = num
    if musicEnabled then musicSound:Play() end
    return true
end

-- ==================== СИСТЕМА УВЕДОМЛЕНИЙ ====================
local NOTIF_QUEUE = {}

local function notify(text, color, duration)
    table.insert(NOTIF_QUEUE, {
        text = text,
        color = color or Color3.fromRGB(140, 255, 200),
        duration = duration or 2,
    })
end

-- ==================== НАСТРОЙКИ ====================
local DEFAULT_SETTINGS = {
    BlockCount = 8,
    BaseShapeSize = 1.5,
    OrbitSpeed = 60,
    SpinSpeed = 120,
    SpeedMultiplier = 1.0,
    SpinSpeedMultiplier = 1.0,
    BobAmplitude = 0.8,
    Material = Enum.Material.Neon,
    Transparency = 0.1,
    LightRange = 6,
    LightLimit = 20,
    LightEnabled = true,
    Rainbow = true,
    FixedColor = Color3.fromRGB(0, 180, 255),
    ShowBlockNames = false,
    NameColor = Color3.fromRGB(255, 255, 255),
    LerpSpeed = 5.0,
    TrailEnabled = false,
    TrailLength = 0.5,
    TrailWidth = 0.8,
    PulseEnabled = false,
    PulseAmplitude = 0.15,
    PulseSpeed = 4.0,
    WaveEnabled = false,
    WaveSpeed = 3.0,
    WaveLength = 2.0,
    WaveAmplitude = 2.5,
    ExplosionEnabled = false,
    ExplosionSpeed = 0.4,
    ExplosionPower = 0.7,
    HeartScale = 0.65,
    -- НОВЫЕ:
    OrbitPattern = "Круг",       -- Круг / Спираль / Волна / Восьмёрка / Зигзаг / Лиссажу / Хаос
    OrbitPatternParam = 1.0,
    AuraEnabled = false,
    AuraType = "Кольцо",          -- Кольцо / Частицы / Оба
    AuraSize = 3.5,
    AuraThickness = 0.15,
    AuraColor = Color3.fromRGB(150, 100, 255),
    AutoShapeSwap = false,
    AutoShapeSwapInterval = 15,
    GradientEnabled = false,
    GradientSpeed = 0.5,
    GlowEnabled = true,
    GlowIntensity = 2,
}
local SETTINGS = table.clone(DEFAULT_SETTINGS)

-- ==================== ПРЕСЕТЫ ====================
local SPIN_SPEED_PRESETS = {
    { name = "0.5x", value = 0.5 },
    { name = "1x",   value = 1.0 },
    { name = "2x",   value = 2.0 },
    { name = "3x",   value = 3.0 },
    { name = "5x",   value = 5.0 },
    { name = "10x",  value = 10.0 },
}
local spinSpeedIndex = 2

local SPREAD_PRESETS = {
    { name = "1x  плотно", mult = 1.0 },
    { name = "1.5x", mult = 1.5 },
    { name = "2x  средне", mult = 2.0 },
    { name = "3x  широко", mult = 3.0 },
    { name = "5x  максимально", mult = 5.0 },
}
local spreadIndex = 2

local HEIGHT_PRESETS = {
    { name = "Очень низко", offset = -12 },
    { name = "Низко", offset = -6 },
    { name = "Средне", offset = 0 },
    { name = "Высоко", offset = 8 },
    { name = "Очень высоко", offset = 18 },
    { name = "Небо", offset = 35 },
    { name = "Космос", offset = 60 },
}
local heightIndex = 3

local SPEED_PRESETS = {
    { name = "0.5x", value = 0.5 },
    { name = "1x", value = 1.0 },
    { name = "1.5x", value = 1.5 },
    { name = "2x", value = 2.0 },
    { name = "3x", value = 3.0 },
    { name = "5x", value = 5.0 },
    { name = "10x", value = 10.0 },
}
local speedIndex = 2

local SPEED_MODE_PRESETS = {
    { name = "Разная", mults = { 1.0, 1.3, 0.7, 1.6, 0.5 } },
    { name = "Одинаковая", mults = { 1.0, 1.0, 1.0, 1.0, 1.0 } },
}
local speedModeIndex = 1

local DIRECTION_PRESETS = {
    { name = "Чередование", dirs = { 1, -1, 1, -1, 1 } },
    { name = "Все ↻", dirs = { 1, 1, 1, 1, 1 } },
    { name = "Все ↺", dirs = { -1, -1, -1, -1, -1 } },
    { name = "Попарно", dirs = { 1, 1, -1, -1, 1 } },
}
local directionIndex = 1

local FORM_MODES = {
    { name = "Одинаковая" },
    { name = "Разные" },
}
local formModeIndex = 1

local ORBIT_PRESETS = {
    { name = "S", radius = 5, height = 2 },
    { name = "M", radius = 8, height = 3 },
    { name = "L", radius = 12, height = 4 },
    { name = "XL", radius = 18, height = 6 },
    { name = "XXL", radius = 25, height = 8 },
}
local orbitIndex = 2

local SHAPE_SIZE_PRESETS = {
    { name = "XS", factor = 0.5 },
    { name = "S", factor = 0.75 },
    { name = "M", factor = 1.0 },
    { name = "L", factor = 1.5 },
    { name = "XL", factor = 2.2 },
    { name = "XXL", factor = 3.0 },
}
local shapeSizeIndex = 3

local ORBIT_PATTERNS = {
    { name = "Круг" },
    { name = "Спираль" },
    { name = "Волна" },
    { name = "Восьмёрка" },
    { name = "Зигзаг" },
    { name = "Лиссажу" },
    { name = "Хаос" },
}
local orbitPatternIndex = 1

local AURA_TYPES = {
    { name = "Кольцо" },
    { name = "Частицы" },
    { name = "Оба" },
}
local auraTypeIndex = 1

local COLOR_PRESETS = {
    { name = "РАДУГА", rainbow = true, color = nil },
    { name = "КРАСНЫЙ", rainbow = false, color = Color3.fromRGB(255, 50, 50) },
    { name = "ОРАНЖЕВЫЙ", rainbow = false, color = Color3.fromRGB(255, 140, 40) },
    { name = "ЖЁЛТЫЙ", rainbow = false, color = Color3.fromRGB(255, 230, 60) },
    { name = "ЗЕЛЁНЫЙ", rainbow = false, color = Color3.fromRGB(0, 255, 120) },
    { name = "ГОЛУБОЙ", rainbow = false, color = Color3.fromRGB(0, 180, 255) },
    { name = "СИНИЙ", rainbow = false, color = Color3.fromRGB(40, 80, 255) },
    { name = "ФИОЛЕТОВЫЙ", rainbow = false, color = Color3.fromRGB(160, 80, 255) },
    { name = "РОЗОВЫЙ", rainbow = false, color = Color3.fromRGB(255, 90, 180) },
    { name = "НЕОН-РОЗОВЫЙ", rainbow = false, color = Color3.fromRGB(255, 0, 200) },
    { name = "НЕОН-ЗЕЛЁНЫЙ", rainbow = false, color = Color3.fromRGB(80, 255, 80) },
    { name = "НЕОН-ГОЛУБОЙ", rainbow = false, color = Color3.fromRGB(0, 255, 255) },
    { name = "НЕОН-ЖЁЛТЫЙ", rainbow = false, color = Color3.fromRGB(255, 255, 0) },
    { name = "НЕОН-ОРАНЖ", rainbow = false, color = Color3.fromRGB(255, 120, 0) },
    { name = "НЕОН-ФИОЛЕТ", rainbow = false, color = Color3.fromRGB(200, 0, 255) },
    { name = "ПАСТЕЛЬ-РОЗА", rainbow = false, color = Color3.fromRGB(255, 180, 200) },
    { name = "ПАСТЕЛЬ-ГОЛУБ", rainbow = false, color = Color3.fromRGB(180, 220, 255) },
    { name = "ПАСТЕЛЬ-ЛИМОН", rainbow = false, color = Color3.fromRGB(255, 250, 180) },
    { name = "ПАСТЕЛЬ-МЯТА", rainbow = false, color = Color3.fromRGB(180, 255, 220) },
    { name = "ПАСТЕЛЬ-СИРЕН", rainbow = false, color = Color3.fromRGB(210, 180, 255) },
    { name = "ЗОЛОТОЙ", rainbow = false, color = Color3.fromRGB(255, 200, 40) },
    { name = "СЕРЕБРЯНЫЙ", rainbow = false, color = Color3.fromRGB(220, 220, 230) },
    { name = "БРОНЗОВЫЙ", rainbow = false, color = Color3.fromRGB(205, 127, 50) },
    { name = "МЕДНЫЙ", rainbow = false, color = Color3.fromRGB(184, 115, 51) },
    { name = "ОГОНЬ", rainbow = false, color = Color3.fromRGB(255, 90, 0) },
    { name = "ЛАВА", rainbow = false, color = Color3.fromRGB(200, 40, 0) },
    { name = "ЛЁД", rainbow = false, color = Color3.fromRGB(180, 230, 255) },
    { name = "ТРАВА", rainbow = false, color = Color3.fromRGB(90, 200, 80) },
    { name = "НЕБО", rainbow = false, color = Color3.fromRGB(120, 190, 255) },
    { name = "БИРЮЗОВЫЙ", rainbow = false, color = Color3.fromRGB(64, 224, 208) },
    { name = "ИЗУМРУД", rainbow = false, color = Color3.fromRGB(80, 200, 120) },
    { name = "РУБИН", rainbow = false, color = Color3.fromRGB(220, 20, 90) },
    { name = "САПФИР", rainbow = false, color = Color3.fromRGB(15, 82, 186) },
    { name = "КОРАЛЛ", rainbow = false, color = Color3.fromRGB(255, 127, 80) },
    { name = "ЛАВАНДА", rainbow = false, color = Color3.fromRGB(180, 130, 255) },
    { name = "БЕЛЫЙ", rainbow = false, color = Color3.fromRGB(245, 245, 255) },
    { name = "СЕРЫЙ", rainbow = false, color = Color3.fromRGB(150, 150, 160) },
    { name = "ЧЁРНЫЙ", rainbow = false, color = Color3.fromRGB(25, 25, 30) },
    { name = "МАЛИНОВЫЙ", rainbow = false, color = Color3.fromRGB(200, 0, 80) },
    { name = "ИНДИГО", rainbow = false, color = Color3.fromRGB(75, 0, 130) },
    { name = "ХАКИ", rainbow = false, color = Color3.fromRGB(189, 183, 107) },
}
local colorIndex = 1

local TRAIL_LENGTH_PRESETS = {
    { name = "Короткий", value = 0.25 },
    { name = "Средний", value = 0.5 },
    { name = "Длинный", value = 0.9 },
    { name = "Очень длинный", value = 1.6 },
    { name = "Гигантский", value = 2.5 },
}
local trailLengthIndex = 2

local TRAIL_WIDTH_PRESETS = {
    { name = "Тонкий", value = 0.3 },
    { name = "Средний", value = 0.8 },
    { name = "Толстый", value = 1.5 },
    { name = "Широкий", value = 2.5 },
    { name = "Огромный", value = 4.0 },
}
local trailWidthIndex = 2

-- ==================== СОСТОЯНИЕ ====================
local enabled = true
local spinResetting = false
local updateConn = nil
local startTime = tick()
local activeLightCount = 0
local currentRadius, currentHeight, currentSpeed, currentSpin = {}, {}, {}, {}
local currentOrbitAngle, currentSpinAngle, currentBobPhase = {}, {}, {}
local lastAutoSwap = tick()
local currentAutoShapeIndex = 1
local statsData = {
    totalShapes = 0,
    sessionTime = 0,
    lastFPS = 60,
    fpsFrames = 0,
    fpsLastCheck = tick(),
}
local auraFolder = nil
local auraParts = {}

local RING_STEP = 5
local rings = {
    [1] = { enabled = true, shapeIndex = 1, folder = nil, blocks = {}, radiusOffset = 0, heightOffset = 0, direction = 1, speedMult = 1.0, angleShift = 0, colorShift = 0 },
    [2] = { enabled = false, shapeIndex = 2, folder = nil, blocks = {}, radiusOffset = 1, heightOffset = -0.5, direction = -1, speedMult = 1.3, angleShift = 22.5, colorShift = 0.2 },
    [3] = { enabled = false, shapeIndex = 3, folder = nil, blocks = {}, radiusOffset = 2, heightOffset = 0.5, direction = 1, speedMult = 0.7, angleShift = 45, colorShift = 0.4 },
    [4] = { enabled = false, shapeIndex = 4, folder = nil, blocks = {}, radiusOffset = 3, heightOffset = -1, direction = -1, speedMult = 1.6, angleShift = 67.5, colorShift = 0.6 },
    [5] = { enabled = false, shapeIndex = 5, folder = nil, blocks = {}, radiusOffset = 4, heightOffset = 1, direction = 1, speedMult = 0.5, angleShift = 90, colorShift = 0.8 },
}

for ri in pairs(rings) do
    currentRadius[ri] = 8
    currentHeight[ri] = 3
    currentSpeed[ri] = 60
    currentSpin[ri] = 120
    currentOrbitAngle[ri] = 0
    currentSpinAngle[ri] = 0
    currentBobPhase[ri] = 0
end

-- ==================== ХЕЛПЕРЫ ====================
local function newPart(parent, name, size, cf, color, noRecolor)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = color or Color3.fromRGB(255, 255, 255)
    if noRecolor then p:SetAttribute("NoRecolor", true) end
    p.Parent = parent
    return p
end

local function newModelShell(name)
    local model = Instance.new("Model")
    model.Name = name
    local root = Instance.new("Part")
    root.Name = "Root"
    root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.Transparency = 1
    root.Anchored = true
    root.CanCollide = false
    root.CastShadow = false
    root.Parent = model
    model.PrimaryPart = root
    return model, root
end

local function makeRod(parent, a, b, thickness, depth, color)
    local mid = (a + b) * 0.5
    local diff = b - a
    local part = Instance.new("Part")
    part.Name = "Rod"
    part.Size = Vector3.new(depth, thickness, diff.Magnitude)
    part.CFrame = CFrame.lookAt(mid, mid + diff.Unit)
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Parent = parent
    return part
end

local function createPalmPlate(model, bodies, cf, size, color)
    local half = size * 0.5
    local cornerR = size * 0.22
    local holeR = size * 0.26
    local depth = size * 0.22
    local segments = 44

    for i = 1, segments do
        local a0 = (i - 1) / segments * math.pi * 2
        local a1 = i / segments * math.pi * 2
        local mid = (a0 + a1) / 2

        local cosA, sinA = math.cos(mid), math.sin(mid)
        local maxCoord = math.max(math.abs(cosA), math.abs(sinA))
        local outerR = (maxCoord > 0) and (half / maxCoord) or half
        local cx = math.clamp(cosA * outerR, -(half - cornerR), half - cornerR)
        local cy = math.clamp(sinA * outerR, -(half - cornerR), half - cornerR)
        local dx, dy = cosA * outerR - cx, sinA * outerR - cy
        local dlen = math.sqrt(dx*dx + dy*dy)
        if dlen > 0.001 then
            cx = cx + dx / dlen * cornerR
            cy = cy + dy / dlen * cornerR
        end
        local outerPt = Vector3.new(cx, cy, 0)
        local innerPt = Vector3.new(math.cos(mid) * holeR, math.sin(mid) * holeR, 0)

        local midPt = (outerPt + innerPt) * 0.5
        local segLen = (outerPt - innerPt).Magnitude
        local angle = math.atan2(outerPt.Y - innerPt.Y, outerPt.X - innerPt.X)
        local tangentLen = 2 * math.pi * (half * 0.7) / segments * 1.4
        local partCF = cf * CFrame.new(midPt.X, midPt.Y, 0) * CFrame.Angles(0, 0, angle)
        table.insert(bodies, newPart(model, "Palm",
            Vector3.new(segLen, tangentLen, depth), partCF, color))
    end

    local spikeLen = holeR * 0.65
    local spikeW = holeR * 0.38
    for k = 0, 3 do
        local ang = math.rad(k * 90 + 45)
        local spikeCF = cf
            * CFrame.new(math.cos(ang) * (holeR - spikeLen * 0.3), math.sin(ang) * (holeR - spikeLen * 0.3), 0)
            * CFrame.Angles(0, 0, ang - math.pi / 2)
        local w = Instance.new("WedgePart")
        w.Name = "Spike"
        w.Size = Vector3.new(spikeW, spikeLen, depth * 0.75)
        w.CFrame = spikeCF
        w.Anchored = true
        w.CanCollide = false
        w.CastShadow = false
        w.Material = Enum.Material.Neon
        w.Color = color
        w.Parent = model
        table.insert(bodies, w)
    end
end

local function createFinger(model, bodies, baseCF, length, width, color)
    local seg1 = length * 0.30
    local seg2 = length * 0.38
    local seg3 = length * 0.32

    local w1 = width
    local w2 = width * 0.75
    local w3 = width * 0.35
    local w4 = width * 0.05

    table.insert(bodies, newPart(model, "F1",
        Vector3.new(w1, seg1, w1 * 0.5),
        baseCF * CFrame.new(0, seg1 / 2, 0), color))

    table.insert(bodies, newPart(model, "F2",
        Vector3.new(w2, seg2, w2 * 0.5),
        baseCF * CFrame.new(0, seg1 + seg2 / 2, 0), color))

    table.insert(bodies, newPart(model, "F3",
        Vector3.new(w3, seg3 * 0.55, w3 * 0.45),
        baseCF * CFrame.new(0, seg1 + seg2 + seg3 * 0.275, 0), color))
    table.insert(bodies, newPart(model, "F4",
        Vector3.new(w4, seg3 * 0.45, w4 * 0.45),
        baseCF * CFrame.new(0, seg1 + seg2 + seg3 * 0.55 + seg3 * 0.225, 0), color))
end

-- ==================== БАЗОВЫЕ ФИГУРЫ ====================
local function create3DStar(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local R, r = size * 0.85, size * 0.85 * 0.382
    local t, d = size * 0.14, size * 0.24
    local verts = {}
    for k = 0, 9 do
        local angle = math.rad(90 + k * 36)
        local radius = (k % 2 == 0) and R or r
        table.insert(verts, Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0))
    end
    for k = 1, 10 do
        table.insert(bodies, makeRod(model, verts[k], verts[(k % 10) + 1], t, d, color))
    end
    table.insert(bodies, newPart(model, "C", Vector3.new(size * 0.15, size * 0.15, d * 0.6), CFrame.new(), color))
    return model, root, bodies
end

local function create3DCross(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local bt, bd = size * 0.32, size * 0.28
    table.insert(bodies, newPart(model, "V", Vector3.new(bt, size * 2.0, bd), CFrame.new(), color))
    table.insert(bodies, newPart(model, "H", Vector3.new(size * 1.3, bt, bd), CFrame.new(0, size * 0.35, 0), color))
    return model, root, bodies
end

local function create3DSkull(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local bone = color or Color3.fromRGB(235, 230, 215)
    local socketShade = Color3.fromRGB(205, 197, 182)
    local dark = Color3.fromRGB(18, 14, 12)
    local toothColor = Color3.fromRGB(250, 248, 240)

    local function ellipsoid(sz, cf, col, noRecolor)
        local p = newPart(model, "E", sz, cf, col, noRecolor)
        p.Material = Enum.Material.SmoothPlastic
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.Sphere
        m.Parent = p
        table.insert(bodies, p)
        return p
    end
    local function block(sz, cf, col, noRecolor)
        local p = newPart(model, "B", sz, cf, col, noRecolor)
        p.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, p)
        return p
    end

    ellipsoid(Vector3.new(1.15 * s, 1.10 * s, 1.10 * s), CFrame.new(0, 0.30 * s, 0.08 * s), bone)
    ellipsoid(Vector3.new(0.85 * s, 0.70 * s, 0.75 * s), CFrame.new(0, -0.16 * s, -0.08 * s), bone)
    ellipsoid(Vector3.new(0.90 * s, 0.16 * s, 0.30 * s), CFrame.new(0, 0.16 * s, -0.36 * s), bone)

    for _, side in ipairs({ -1, 1 }) do
        ellipsoid(Vector3.new(0.34 * s, 0.30 * s, 0.20 * s), CFrame.new(side * 0.30 * s, 0.26 * s, -0.34 * s), socketShade, true)
    end

    for _, side in ipairs({ -1, 1 }) do
        ellipsoid(Vector3.new(0.30 * s, 0.26 * s, 0.30 * s), CFrame.new(side * 0.43 * s, -0.02 * s, -0.18 * s), bone)
        ellipsoid(Vector3.new(0.42 * s, 0.40 * s, 0.14 * s), CFrame.new(side * 0.25 * s, 0.03 * s, -0.41 * s), bone)
        ellipsoid(Vector3.new(0.32 * s, 0.30 * s, 0.14 * s), CFrame.new(side * 0.25 * s, 0.03 * s, -0.44 * s), dark, true)
        block(Vector3.new(0.09 * s, 0.62 * s, 0.30 * s), CFrame.new(side * 0.42 * s, -0.35 * s, 0.02 * s), bone)
    end

    local nose = newPart(model, "N", Vector3.new(0.20 * s, 0.26 * s, 0.14 * s),
        CFrame.new(0, -0.22 * s, -0.42 * s) * CFrame.Angles(math.rad(180), 0, 0), dark, true)
    local nm = Instance.new("SpecialMesh")
    nm.MeshType = Enum.MeshType.Pyramid
    nm.Parent = nose
    table.insert(bodies, nose)

    ellipsoid(Vector3.new(0.80 * s, 0.46 * s, 0.62 * s), CFrame.new(0, -0.62 * s, -0.10 * s), bone)
    block(Vector3.new(0.62 * s, 0.05 * s, 0.20 * s), CFrame.new(0, -0.47 * s, -0.30 * s), dark, true)

    for i = 1, 8 do
        local x = (i - 4.5) * 0.085 * s
        local k = x / (0.3 * s)
        block(Vector3.new(0.08 * s, 0.13 * s, 0.09 * s),
            CFrame.new(x, -0.40 * s, (-0.37 + k * k * 0.08) * s), toothColor, true)
        block(Vector3.new(0.075 * s, 0.12 * s, 0.09 * s),
            CFrame.new(x, -0.53 * s, (-0.35 + k * k * 0.08) * s), toothColor, true)
    end

    return model, root, bodies
end

local function addTriangle(parent, a, b, c, thickness, color, bodies)
    local ab, ac, bc = b - a, c - a, c - b
    local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
    if abd > acd and abd > bcd then
        c, a = a, c
    elseif acd > bcd and acd > abd then
        a, b = b, a
    end
    ab, ac, bc = b - a, c - a, c - b

    local right = ac:Cross(ab).Unit
    local up = bc:Cross(right).Unit
    local back = bc.Unit
    local height = math.abs(ab:Dot(up))

    local function wedge(lenZ, cf)
        local w = Instance.new("WedgePart")
        w.Name = "W"
        w.Size = Vector3.new(thickness, height, lenZ)
        w.CFrame = cf
        w.Anchored = true
        w.CanCollide = false
        w.CastShadow = false
        w.Material = Enum.Material.SmoothPlastic
        w.Color = color
        w.Parent = parent
        table.insert(bodies, w)
    end

    wedge(math.abs(ab:Dot(back)), CFrame.fromMatrix((a + b) / 2, right, up, back))
    wedge(math.abs(ac:Dot(back)), CFrame.fromMatrix((a + c) / 2, -right, up, -back))
end

local function create3DLightning(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}

    local u = size * 2.0 / 227
    local depth = size * 0.28
    local function P(x, y) return Vector3.new(x * u, y * u, 0) end

    local p1 = P(-15, 115)
    local p2 = P(68, 115)
    local p3 = P(28, 20)
    local p4 = P(55, 20)
    local p5 = P(-42, -112)
    local p6 = P(2, 20)
    local p7 = P(-55, 20)

    addTriangle(model, p7, p3, p1, depth, color, bodies)
    addTriangle(model, p1, p3, p2, depth, color, bodies)
    addTriangle(model, p6, p4, p5, depth, color, bodies)

    return model, root, bodies
end

local function createHead(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local head = newPart(model, "H", Vector3.new(size, size, size), CFrame.new(), color)
    head.Material = Enum.Material.SmoothPlastic
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Head
    mesh.Scale = Vector3.new(size, size, size)
    mesh.Parent = head
    local face = Instance.new("Decal")
    face.Face = Enum.NormalId.Front
    face.Texture = "rbxasset://textures/face.png"
    face.Parent = head
    table.insert(bodies, head)
    return model, root, bodies
end

local function create3DTriangle(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local R = size * 0.75
    local t, d = size * 0.13, size * 0.28
    local v1 = Vector3.new(0, R, 0)
    local v2 = Vector3.new(math.cos(math.rad(210)) * R, math.sin(math.rad(210)) * R, 0)
    local v3 = Vector3.new(math.cos(math.rad(330)) * R, math.sin(math.rad(330)) * R, 0)
    table.insert(bodies, makeRod(model, v1, v2, t, d, color))
    table.insert(bodies, makeRod(model, v2, v3, t, d, color))
    table.insert(bodies, makeRod(model, v3, v1, t, d, color))
    return model, root, bodies
end

local function create3DDiamond(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local R = size * 0.75
    local t, d = size * 0.13, size * 0.28
    local vT = Vector3.new(0, R, 0)
    local vR = Vector3.new(R * 0.75, 0, 0)
    local vB = Vector3.new(0, -R, 0)
    local vL = Vector3.new(-R * 0.75, 0, 0)
    table.insert(bodies, makeRod(model, vT, vR, t, d, color))
    table.insert(bodies, makeRod(model, vR, vB, t, d, color))
    table.insert(bodies, makeRod(model, vB, vL, t, d, color))
    table.insert(bodies, makeRod(model, vL, vT, t, d, color))
    return model, root, bodies
end

local HEART_PATTERN = { "11011", "11111", "11111", "01110", "00100" }
local function createPixelHeart(sizeStuds, color, name)
    local rows = #HEART_PATTERN
    local cols = #HEART_PATTERN[1]
    local pixel = sizeStuds / cols
    local model, root = newModelShell(name)
    local bodies = {}
    for r = 1, rows do
        local row = HEART_PATTERN[r]
        local c = 1
        while c <= cols do
            if row:sub(c, c) == "1" then
                local sc = c
                while c <= cols and row:sub(c, c) == "1" do c = c + 1 end
                local ec = c - 1
                local width = (ec - sc + 1) * pixel
                local cc = (sc + ec) / 2
                local x = (cc - (cols + 1) / 2) * pixel
                local y = ((rows + 1) / 2 - r) * pixel
                table.insert(bodies, newPart(model, "P", Vector3.new(width, pixel, pixel), CFrame.new(x, y, 0), color))
            else
                c = c + 1
            end
        end
    end
    return model, root, bodies
end

local HEART_COLORS = {
    Color3.fromRGB(255, 140, 40),
    Color3.fromRGB(255, 230, 60),
    Color3.fromRGB(255, 0, 200),
    Color3.fromRGB(220, 20, 60),
    Color3.fromRGB(0, 255, 120),
    Color3.fromRGB(0, 220, 220),
    Color3.fromRGB(40, 80, 255),
}

local function create3DHand(size, color, name, withHeart, heartColor)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size

    local palmCF = CFrame.new(0, -s * 0.10, 0)
    createPalmPlate(model, bodies, palmCF, s * 2.2, color)

    if withHeart then
        local hc = heartColor or Color3.fromRGB(255, 40, 95)
        local heartSize = s * 1.8 * SETTINGS.HeartScale
        local hModel = select(1, createPixelHeart(heartSize, hc, "Heart"))
        hModel.Parent = model
        hModel:PivotTo(palmCF * CFrame.new(0, 0, s * 0.02))
    end

    local wrapY = -s * 1.20
    table.insert(bodies, newPart(model, "Wrap1",
        Vector3.new(s * 2.4, s * 0.26, s * 0.40),
        palmCF * CFrame.new(0, wrapY, 0) * CFrame.Angles(0, 0, math.rad(14)), color))
    table.insert(bodies, newPart(model, "Wrap2",
        Vector3.new(s * 2.4, s * 0.26, s * 0.40),
        palmCF * CFrame.new(0, wrapY, 0) * CFrame.Angles(0, 0, math.rad(-14)), color))

    local fingerBaseY = s * 0.88
    local fingers = {
        { len = 2.20, w = 0.36, offsetX = -0.78 },
        { len = 2.75, w = 0.42, offsetX = -0.26 },
        { len = 2.75, w = 0.42, offsetX =  0.26 },
        { len = 2.20, w = 0.36, offsetX =  0.78 },
    }
    for _, f in ipairs(fingers) do
        local baseCF = CFrame.new(f.offsetX * s, fingerBaseY, 0)
        createFinger(model, bodies, baseCF, s * f.len, s * f.w, color)
    end

    local thumbCF = CFrame.new(s * 1.15, -s * 0.10, 0) * CFrame.Angles(0, 0, math.rad(-42))
    createFinger(model, bodies, thumbCF, s * 1.70, s * 0.46, color)

    return model, root, bodies
end

local function createMeshShape(meshId, textureId, size, name, color)
    local model, root = newModelShell(name)
    local mp = Instance.new("MeshPart")
    mp.Name = "Mesh"
    mp.MeshId = meshId
    if textureId ~= "" then mp.TextureID = textureId end
    mp.Anchored = true
    mp.CanCollide = false
    mp.CastShadow = false
    mp.Material = Enum.Material.Neon
    mp.Color = color or Color3.fromRGB(235, 230, 215)
    mp.Size = Vector3.new(size * 3, size * 3, size * 3)
    mp.CFrame = CFrame.new()
    mp.Parent = model
    return model, root, { mp }
end

-- ==================== НОВЫЕ ФИГУРЫ ====================

-- ★ МЕЧ (Sword)
local function createSword(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Лезвие
    table.insert(bodies, newPart(model, "Blade",
        Vector3.new(s * 0.18, s * 3.5, s * 0.10),
        CFrame.new(0, s * 0.9, 0), color))
    -- Остриё (пирамидка сверху)
    local tip = newPart(model, "Tip", Vector3.new(s * 0.18, s * 0.4, s * 0.10),
        CFrame.new(0, s * 2.85, 0), color)
    table.insert(bodies, tip)
    -- Гарда (крестовина)
    table.insert(bodies, newPart(model, "Guard",
        Vector3.new(s * 1.4, s * 0.15, s * 0.20),
        CFrame.new(0, -s * 0.85, 0), color))
    -- Рукоять
    table.insert(bodies, newPart(model, "Handle",
        Vector3.new(s * 0.20, s * 0.9, s * 0.20),
        CFrame.new(0, -s * 1.35, 0), color))
    -- Навершие (шарик)
    local pommel = newPart(model, "Pommel", Vector3.new(s * 0.30, s * 0.30, s * 0.30),
        CFrame.new(0, -s * 1.90, 0), color)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Sphere
    m.Parent = pommel
    table.insert(bodies, pommel)
    return model, root, bodies
end

-- ★ ЩИТ (Shield)
local function createShield(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Основа щита (ромб)
    local shield = newPart(model, "Base", Vector3.new(s * 1.6, s * 2.0, s * 0.18),
        CFrame.new(0, 0, 0), color)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Wedge
    m.Parent = shield
    table.insert(bodies, shield)
    -- Крест по центру
    table.insert(bodies, newPart(model, "CrossV",
        Vector3.new(s * 0.15, s * 1.5, s * 0.22),
        CFrame.new(0, 0, -s * 0.06), color))
    table.insert(bodies, newPart(model, "CrossH",
        Vector3.new(s * 1.2, s * 0.15, s * 0.22),
        CFrame.new(0, s * 0.20, -s * 0.06), color))
    -- Умбо (центр)
    local umbo = newPart(model, "Umbo", Vector3.new(s * 0.4, s * 0.4, s * 0.25),
        CFrame.new(0, 0, -s * 0.12), color)
    local m2 = Instance.new("SpecialMesh")
    m2.MeshType = Enum.MeshType.Sphere
    m2.Parent = umbo
    table.insert(bodies, umbo)
    return model, root, bodies
end

-- ★ КОРОНА (Crown)
local function createCrown(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Обод
    local ring = newPart(model, "Ring", Vector3.new(s * 2.0, s * 0.4, s * 2.0),
        CFrame.new(0, 0, 0), color)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Cylinder
    m.Parent = ring
    table.insert(bodies, ring)
    -- Зубцы (7 штук)
    local spikes = 7
    for i = 1, spikes do
        local angle = (i - 1) / spikes * math.pi * 2
        local x = math.cos(angle) * s * 0.85
        local z = math.sin(angle) * s * 0.85
        local spike = newPart(model, "Spike", Vector3.new(s * 0.25, s * 0.7, s * 0.20),
            CFrame.new(x, s * 0.5, z), color)
        local sm = Instance.new("SpecialMesh")
        sm.MeshType = Enum.MeshType.Pyramid
        sm.Parent = spike
        table.insert(bodies, spike)
        -- Шарик на конце
        local ball = newPart(model, "Ball", Vector3.new(s * 0.20, s * 0.20, s * 0.20),
            CFrame.new(x, s * 0.9, z), color)
        local bm = Instance.new("SpecialMesh")
        bm.MeshType = Enum.MeshType.Sphere
        bm.Parent = ball
        table.insert(bodies, ball)
    end
    return model, root, bodies
end

-- ★ КОСТЬ (Bone)
local function createBone(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Стержень кости
    table.insert(bodies, newPart(model, "Shaft",
        Vector3.new(s * 0.3, s * 1.8, s * 0.3),
        CFrame.new(0, 0, 0), color))
    -- Верхние шишки
    for _, side in ipairs({-1, 1}) do
        local top = newPart(model, "Top", Vector3.new(s * 0.5, s * 0.4, s * 0.5),
            CFrame.new(side * s * 0.25, s * 1.0, 0), color)
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.Sphere
        m.Parent = top
        table.insert(bodies, top)
        local bottom = newPart(model, "Bot", Vector3.new(s * 0.5, s * 0.4, s * 0.5),
            CFrame.new(side * s * 0.25, -s * 1.0, 0), color)
        local m2 = Instance.new("SpecialMesh")
        m2.MeshType = Enum.MeshType.Sphere
        m2.Parent = bottom
        table.insert(bodies, bottom)
    end
    return model, root, bodies
end

-- ★ КРИСТАЛЛ (Crystal)
local function createCrystal(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Основной кристалл
    local main = newPart(model, "Main", Vector3.new(s * 0.6, s * 2.0, s * 0.6),
        CFrame.new(0, 0, 0), color)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Pyramid
    m.Parent = main
    table.insert(bodies, main)
    -- Побочные кристаллы
    for i = 1, 4 do
        local angle = (i - 1) / 4 * math.pi * 2
        local x = math.cos(angle) * s * 0.4
        local z = math.sin(angle) * s * 0.4
        local side = newPart(model, "Side", Vector3.new(s * 0.3, s * 1.2, s * 0.3),
            CFrame.new(x, -s * 0.3, z) * CFrame.Angles(math.rad(15), 0, 0), color)
        local sm = Instance.new("SpecialMesh")
        sm.MeshType = Enum.MeshType.Pyramid
        sm.Parent = side
        table.insert(bodies, side)
    end
    return model, root, bodies
end

-- ★ ПИРАМИДА
local function createPyramid(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local pyramid = newPart(model, "Pyr", Vector3.new(s * 1.5, s * 1.5, s * 1.5),
        CFrame.new(0, 0, 0), color)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Pyramid
    m.Parent = pyramid
    table.insert(bodies, pyramid)
    return model, root, bodies
end

-- ★ ИНЬ-ЯН
local function createYinYang(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Основа
    local base = newPart(model, "Base", Vector3.new(s * 1.8, s * 0.3, s * 1.8),
        CFrame.new(0, 0, 0), color)
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Cylinder
    m.Parent = base
    table.insert(bodies, base)
    -- Большая точка (светлая)
    local white = newPart(model, "White", Vector3.new(s * 0.5, s * 0.4, s * 0.5),
        CFrame.new(0, s * 0.2, s * 0.5), color)
    local wm = Instance.new("SpecialMesh")
    wm.MeshType = Enum.MeshType.Sphere
    wm.Parent = white
    table.insert(bodies, white)
    -- Большая точка (тёмная)
    local black = newPart(model, "Black", Vector3.new(s * 0.5, s * 0.4, s * 0.5),
        CFrame.new(0, s * 0.2, -s * 0.5), color)
    local bm = Instance.new("SpecialMesh")
    bm.MeshType = Enum.MeshType.Sphere
    bm.Parent = black
    table.insert(bodies, black)
    -- Маленькие точки
    local wsmall = newPart(model, "WS", Vector3.new(s * 0.2, s * 0.3, s * 0.2),
        CFrame.new(0, s * 0.3, -s * 0.5), color)
    local wsm = Instance.new("SpecialMesh")
    wsm.MeshType = Enum.MeshType.Sphere
    wsm.Parent = wsmall
    table.insert(bodies, wsmall)
    local bsmall = newPart(model, "BS", Vector3.new(s * 0.2, s * 0.3, s * 0.2),
        CFrame.new(0, s * 0.3, s * 0.5), color)
    local bsm = Instance.new("SpecialMesh")
    bsm.MeshType = Enum.MeshType.Sphere
    bsm.Parent = bsmall
    table.insert(bodies, bsmall)
    return model, root, bodies
end

-- ★ ГЛАЗ (Eye of Sauron style)
local function createEye(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Веко-обод
    local ring = newPart(model, "Ring", Vector3.new(s * 1.6, s * 0.4, s * 1.6),
        CFrame.new(0, 0, 0), color)
    local rm = Instance.new("SpecialMesh")
    rm.MeshType = Enum.MeshType.Cylinder
    rm.Parent = ring
    table.insert(bodies, ring)
    -- Яблоко
    local apple = newPart(model, "Apple", Vector3.new(s * 1.2, s * 0.9, s * 1.2),
        CFrame.new(0, 0, 0), color)
    local am = Instance.new("SpecialMesh")
    am.MeshType = Enum.MeshType.Sphere
    am.Parent = apple
    table.insert(bodies, apple)
    -- Зрачок
    local pupil = newPart(model, "Pupil", Vector3.new(s * 0.4, s * 0.4, s * 0.4),
        CFrame.new(0, 0, 0), color)
    pupil:SetAttribute("NoRecolor", true)
    pupil.Color = Color3.fromRGB(15, 5, 5)
    local pm = Instance.new("SpecialMesh")
    pm.MeshType = Enum.MeshType.Sphere
    pm.Parent = pupil
    table.insert(bodies, pupil)
    return model, root, bodies
end

-- ★ РУНА (Magic circle)
local function createRune(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    -- Внешнее кольцо
    local outer = newPart(model, "Outer", Vector3.new(s * 2.0, s * 0.15, s * 2.0),
        CFrame.new(0, 0, 0), color)
    local om = Instance.new("SpecialMesh")
    om.MeshType = Enum.MeshType.Cylinder
    om.Parent = outer
    table.insert(bodies, outer)
    -- Внутреннее кольцо
    local inner = newPart(model, "Inner", Vector3.new(s * 1.2, s * 0.2, s * 1.2),
        CFrame.new(0, 0, 0), color)
    local im = Instance.new("SpecialMesh")
    im.MeshType = Enum.MeshType.Cylinder
    im.Parent = inner
    table.insert(bodies, inner)
    -- Лучи (6 штук)
    for i = 1, 6 do
        local angle = (i - 1) / 6 * math.pi * 2
        local x = math.cos(angle) * s * 0.8
        local z = math.sin(angle) * s * 0.8
        local rod = newPart(model, "Rod", Vector3.new(s * 0.08, s * 0.25, s * 0.4),
            CFrame.new(x, 0, z) * CFrame.Angles(0, -angle, 0), color)
        table.insert(bodies, rod)
    end
    return model, root, bodies
end

-- ★ СПИРАЛЬ
local function createSpiral(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local segments = 20
    for i = 1, segments do
        local t = i / segments
        local angle = t * math.pi * 4
        local radius = t * s * 0.9
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius
        local cube = newPart(model, "Seg", Vector3.new(s * 0.25, s * 0.25, s * 0.25),
            CFrame.new(x, 0, z), color)
        table.insert(bodies, cube)
    end
    return model, root, bodies
end

-- ★ КРЫЛЬЯ
local function createWings(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    for _, side in ipairs({-1, 1}) do
        -- 3 пера
        for i = 1, 3 do
            local len = s * (1.6 - (i-1) * 0.3)
            local feather = newPart(model, "Feather", Vector3.new(s * 0.15, s * 0.15, len),
                CFrame.new(side * s * 0.4, (i-1) * s * 0.3 - s * 0.3, 0)
                * CFrame.Angles(0, math.rad(side * 20), 0), color)
            table.insert(bodies, feather)
        end
        -- Основание
        local base = newPart(model, "Base", Vector3.new(s * 0.4, s * 0.5, s * 0.3),
            CFrame.new(side * s * 0.2, 0, 0), color)
        table.insert(bodies, base)
    end
    return model, root, bodies
end

-- ★ ЩУПАЛЬЦЕ
local function createTentacle(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local segments = 8
    for i = 1, segments do
        local t = i / segments
        local angle = t * math.pi * 2
        local x = math.sin(angle) * t * s * 0.5
        local y = t * s * 1.8 - s * 0.5
        local thickness = s * 0.3 * (1 - t * 0.7)
        local seg = newPart(model, "Seg", Vector3.new(thickness, s * 0.3, thickness),
            CFrame.new(x, y, 0), color)
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.Sphere
        m.Parent = seg
        table.insert(bodies, seg)
    end
    return model, root, bodies
end

-- ★ ГАСТЕР БЛАСТЕР (заглушка)
local function create3DBlasterPlaceholder(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local bone = color or Color3.fromRGB(235, 230, 215)
    local dark = Color3.fromRGB(10, 9, 9)
    local toothColor = Color3.fromRGB(250, 248, 240)

    local function block(sz, cf, col, noRecolor)
        local p = newPart(model, "B", sz, cf, col, noRecolor)
        p.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, p)
        return p
    end
    local function ellipsoid(sz, cf, col, noRecolor)
        local p = block(sz, cf, col, noRecolor)
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.Sphere
        m.Parent = p
        return p
    end
    local function wedge(sz, cf, col, noRecolor)
        local w = Instance.new("WedgePart")
        w.Name = "W"
        w.Size = sz
        w.CFrame = cf
        w.Anchored = true
        w.CanCollide = false
        w.CastShadow = false
        w.Material = Enum.Material.SmoothPlastic
        w.Color = col
        if noRecolor then w:SetAttribute("NoRecolor", true) end
        w.Parent = model
        table.insert(bodies, w)
        return w
    end
    local function tooth(cf, w, h, col)
        local p = newPart(model, "Tooth", Vector3.new(w, h, w), cf, col, true)
        p.Material = Enum.Material.SmoothPlastic
        local m = Instance.new("SpecialMesh")
        m.MeshType = Enum.MeshType.Pyramid
        m.Parent = p
        table.insert(bodies, p)
        return p
    end
    local function addLight(part, col, range, bright)
        if SETTINGS.LightEnabled and activeLightCount < SETTINGS.LightLimit then
            local light = Instance.new("PointLight")
            light.Range = range * s
            light.Brightness = bright
            light.Color = col
            light.Parent = part
            activeLightCount = activeLightCount + 1
        end
    end

    ellipsoid(Vector3.new(1.45 * s, 1.00 * s, 1.35 * s), CFrame.new(0, 0.28 * s, 1.00 * s), bone)
    ellipsoid(Vector3.new(1.30 * s, 0.88 * s, 1.20 * s), CFrame.new(0, 0.24 * s, 0.15 * s), bone)
    ellipsoid(Vector3.new(1.00 * s, 0.68 * s, 1.10 * s), CFrame.new(0, 0.18 * s, -0.75 * s), bone)
    ellipsoid(Vector3.new(0.62 * s, 0.46 * s, 0.85 * s), CFrame.new(0, 0.12 * s, -1.55 * s), bone)

    for _, side in ipairs({ -1, 1 }) do
        ellipsoid(Vector3.new(0.42 * s, 0.16 * s, 0.55 * s),
            CFrame.new(side * 0.40 * s, 0.52 * s, -0.35 * s) * CFrame.Angles(math.rad(-8), 0, math.rad(side * 6)), bone)
    end

    for _, side in ipairs({ -1, 1 }) do
        ellipsoid(Vector3.new(0.10 * s, 0.10 * s, 0.14 * s),
            CFrame.new(side * 0.18 * s, 0.06 * s, -1.92 * s), dark, true)
    end

    ellipsoid(Vector3.new(1.10 * s, 0.42 * s, 1.35 * s), CFrame.new(0, -0.40 * s, 0.55 * s), bone)
    ellipsoid(Vector3.new(0.72 * s, 0.30 * s, 1.00 * s), CFrame.new(0, -0.30 * s, -0.55 * s), bone)
    ellipsoid(Vector3.new(0.42 * s, 0.20 * s, 0.60 * s), CFrame.new(0, -0.24 * s, -1.30 * s), bone)

    block(Vector3.new(0.68 * s, 0.34 * s, 1.55 * s), CFrame.new(0, -0.05 * s, -0.50 * s), dark, true)

    local core = ellipsoid(Vector3.new(0.22 * s, 0.22 * s, 0.22 * s), CFrame.new(0, -0.05 * s, -0.85 * s), bone)
    addLight(core, bone, 8, 4)

    for _, side in ipairs({ -1, 1 }) do
        tooth(CFrame.new(side * 0.42 * s, -0.02 * s, -0.35 * s) * CFrame.Angles(math.rad(180), 0, 0),
            0.16 * s, 0.30 * s, toothColor)
        tooth(CFrame.new(side * 0.38 * s, -0.10 * s, -0.30 * s), 0.14 * s, 0.24 * s, toothColor)
    end
    for i = 1, 4 do
        local z = -1.10 * s + (i - 1) * 0.20 * s
        tooth(CFrame.new((i % 2 == 0 and 0.24 or -0.24) * s, -0.06 * s, z) * CFrame.Angles(math.rad(180), 0, 0),
            0.12 * s, 0.16 * s, toothColor)
    end
    for i = 1, 3 do
        local z = -0.95 * s + (i - 1) * 0.20 * s
        tooth(CFrame.new((i % 2 == 0 and -0.20 or 0.20) * s, -0.12 * s, z), 0.11 * s, 0.14 * s, toothColor)
    end

    for _, side in ipairs({ -1, 1 }) do
        ellipsoid(Vector3.new(0.38 * s, 0.34 * s, 0.30 * s), CFrame.new(side * 0.46 * s, 0.32 * s, -0.42 * s), dark, true)
        local eye = ellipsoid(Vector3.new(0.15 * s, 0.15 * s, 0.10 * s), CFrame.new(side * 0.46 * s, 0.32 * s, -0.52 * s), bone)
        addLight(eye, bone, 6, 3)
    end

    for i = 1, 3 do
        local z = 1.35 * s - (i - 1) * 0.35 * s
        local h = 0.70 * s - (i - 1) * 0.16 * s
        wedge(Vector3.new(0.18 * s, h, 0.30 * s),
            CFrame.new(0, 0.55 * s + h * 0.35, z) * CFrame.Angles(math.rad(-18), math.rad(90), 0), bone)
    end

    for _, side in ipairs({ -1, 1 }) do
        wedge(Vector3.new(0.12 * s, 0.65 * s, 0.55 * s),
            CFrame.new(side * 0.78 * s, 0.42 * s, 0.85 * s) * CFrame.Angles(math.rad(-10), 0, math.rad(side * -55)), bone)
        wedge(Vector3.new(0.10 * s, 0.42 * s, 0.38 * s),
            CFrame.new(side * 0.95 * s, 0.62 * s, 0.65 * s) * CFrame.Angles(math.rad(-10), 0, math.rad(side * -75)), bone)
    end

    return model, root, bodies
end

-- ==================== СПИСОК ФИГУР ====================
local SHAPE_PRESETS = {
    -- 1-4: базовые
    { name = "БЛОК", create = function(size, name)
        local p = Instance.new("Part")
        p.Name = name; p.Shape = Enum.PartType.Block
        p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    { name = "ШАР", create = function(size, name)
        local p = Instance.new("Part")
        p.Name = name; p.Shape = Enum.PartType.Ball
        p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    { name = "ЦИЛИНДР", create = function(size, name)
        local p = Instance.new("Part")
        p.Name = name; p.Shape = Enum.PartType.Cylinder
        p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    { name = "КЛИН", create = function(size, name)
        local p = Instance.new("WedgePart")
        p.Name = name; p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    -- 5-6
    { name = "ГОЛОВА", create = function(size, name)
        local m, r, b = createHead(size, Color3.fromRGB(255, 220, 60), name)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = size }
    end },
    { name = "СЕРДЦЕ", create = function(size, name)
        local hs = size * 1.8
        local m, r, b = createPixelHeart(hs, Color3.fromRGB(255, 60, 120), name)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = hs }
    end },
    -- 7-12
    { name = "ЗВЕЗДА", create = function(s, n)
        local m, r, b = create3DStar(s, Color3.fromRGB(255, 200, 40), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s }
    end },
    { name = "ТРЕУГОЛЬНИК", create = function(s, n)
        local m, r, b = create3DTriangle(s, Color3.fromRGB(0, 255, 120), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.5 }
    end },
    { name = "РОМБ", create = function(s, n)
        local m, r, b = create3DDiamond(s, Color3.fromRGB(0, 200, 255), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.5 }
    end },
    { name = "КРЕСТ", create = function(s, n)
        local m, r, b = create3DCross(s, Color3.fromRGB(230, 220, 200), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.8 }
    end },
    { name = "ЧЕРЕП", create = function(s, n)
        local m, r, b = create3DSkull(s, Color3.fromRGB(235, 230, 215), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.4 }
    end },
    { name = "МОЛНИЯ", create = function(s, n)
        local m, r, b = create3DLightning(s, Color3.fromRGB(255, 230, 60), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.5 }
    end },
    -- 13-14: рука
    { name = "РУКА", create = function(s, n)
        if MESH_CONFIG.HandMeshId ~= "" then
            local m, r, b = createMeshShape(MESH_CONFIG.HandMeshId, MESH_CONFIG.HandTextureId, s, n, Color3.fromRGB(235, 230, 215))
            return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.2 }
        end
        local m, r, b = create3DHand(s, Color3.fromRGB(235, 230, 215), n, false)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.2 }
    end },
    { name = "РУКА-СЕРДЦЕ", create = function(s, n, idx)
        local hc = HEART_COLORS[((idx or 1) - 1) % #HEART_COLORS + 1]
        if MESH_CONFIG.HandMeshId ~= "" then
            local m, r, b = createMeshShape(MESH_CONFIG.HandMeshId, MESH_CONFIG.HandTextureId, s, n, Color3.fromRGB(235, 230, 215))
            local heartSize = s * 1.8 * SETTINGS.HeartScale
            local hModel = select(1, createPixelHeart(heartSize, hc, "Heart"))
            hModel.Parent = m
            hModel:PivotTo(CFrame.new(0, 0, s * 0.3))
            return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.2 }
        end
        local m, r, b = create3DHand(s, Color3.fromRGB(235, 230, 215), n, true, hc)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.2 }
    end },
    -- 15: бластер
    { name = "ГАСТЕР БЛАСТЕР", create = function(s, n)
        if MESH_CONFIG.BlasterMeshId ~= "" then
            local m, r, b = createMeshShape(MESH_CONFIG.BlasterMeshId, MESH_CONFIG.BlasterTextureId, s, n, Color3.fromRGB(240, 240, 245))
            return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.0 }
        end
        local m, r, b = create3DBlasterPlaceholder(s, Color3.fromRGB(240, 240, 245), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.6 }
    end },
    -- 16-20: НОВЫЕ
    { name = "МЕЧ", create = function(s, n)
        local m, r, b = createSword(s, Color3.fromRGB(220, 230, 245), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.0 }
    end },
    { name = "ЩИТ", create = function(s, n)
        local m, r, b = createShield(s, Color3.fromRGB(200, 220, 240), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.2 }
    end },
    { name = "КОРОНА", create = function(s, n)
        local m, r, b = createCrown(s, Color3.fromRGB(255, 215, 0), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.2 }
    end },
    { name = "КОСТЬ", create = function(s, n)
        local m, r, b = createBone(s, Color3.fromRGB(245, 240, 220), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.8 }
    end },
    { name = "КРИСТАЛЛ", create = function(s, n)
        local m, r, b = createCrystal(s, Color3.fromRGB(150, 230, 255), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.0 }
    end },
    -- 21-25: ещё больше
    { name = "ПИРАМИДА", create = function(s, n)
        local m, r, b = createPyramid(s, Color3.fromRGB(255, 200, 100), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.6 }
    end },
    { name = "ИНЬ-ЯН", create = function(s, n)
        local m, r, b = createYinYang(s, Color3.fromRGB(220, 220, 240), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.8 }
    end },
    { name = "ГЛАЗ", create = function(s, n)
        local m, r, b = createEye(s, Color3.fromRGB(255, 200, 200), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.6 }
    end },
    { name = "РУНА", create = function(s, n)
        local m, r, b = createRune(s, Color3.fromRGB(180, 150, 255), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.0 }
    end },
    { name = "СПИРАЛЬ", create = function(s, n)
        local m, r, b = createSpiral(s, Color3.fromRGB(120, 200, 255), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.8 }
    end },
    -- 26-27: крылья и щупальце
    { name = "КРЫЛЬЯ", create = function(s, n)
        local m, r, b = createWings(s, Color3.fromRGB(240, 240, 255), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.2 }
    end },
    { name = "ЩУПАЛЬЦЕ", create = function(s, n)
        local m, r, b = createTentacle(s, Color3.fromRGB(150, 80, 180), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.0 }
    end },
}
local shapeIndex = 1

-- ==================== АУРА ====================
local function setupAura()
    if auraFolder then auraFolder:Destroy(); auraFolder = nil end
    auraParts = {}
    if not SETTINGS.AuraEnabled then return end

    auraFolder = Instance.new("Folder")
    auraFolder.Name = "OrbitAura"
    auraFolder.Parent = Workspace

    if SETTINGS.AuraType == "Кольцо" or SETTINGS.AuraType == "Оба" then
        local ring = Instance.new("Part")
        ring.Name = "AuraRing"
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(SETTINGS.AuraThickness, SETTINGS.AuraSize * 2, SETTINGS.AuraSize * 2)
        ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
        ring.Material = Enum.Material.Neon
        ring.Color = SETTINGS.AuraColor
        ring.Transparency = 0.3
        ring.Parent = auraFolder
        table.insert(auraParts, ring)
    end

    if SETTINGS.AuraType == "Частицы" or SETTINGS.AuraType == "Оба" then
        local emitter = Instance.new("Part")
        emitter.Name = "AuraEmitter"
        emitter.Size = Vector3.new(0.1, 0.1, 0.1)
        emitter.Transparency = 1
        emitter.Anchored = true; emitter.CanCollide = false; emitter.CastShadow = false
        emitter.Parent = auraFolder
        local particle = Instance.new("ParticleEmitter")
        particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        particle.Rate = 30
        particle.Lifetime = NumberRange.new(0.8, 1.5)
        particle.Speed = NumberRange.new(2, 4)
        particle.SpreadAngle = Vector2.new(180, 180)
        particle.Size = NumberSequence.new(0.5)
        particle.Color = ColorSequence.new(SETTINGS.AuraColor)
        particle.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        particle.Parent = emitter
        table.insert(auraParts, emitter)
    end
end

local function updateAura()
    if not auraFolder then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, part in ipairs(auraParts) do
        if part.Name == "AuraRing" then
            part.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0))
                * CFrame.Angles(0, 0, math.rad(90))
        elseif part.Name == "AuraEmitter" then
            part.CFrame = hrp.CFrame
        end
    end
end

-- ==================== ОРБИТАЛЬНЫЕ УЗОРЫ ====================
local function applyOrbitPattern(ri, baseAngle, baseRadius, baseHeight)
    local pattern = SETTINGS.OrbitPattern
    local t = baseAngle
    local param = SETTINGS.OrbitPatternParam

    if pattern == "Круг" then
        return math.cos(t) * baseRadius, baseHeight, math.sin(t) * baseRadius
    elseif pattern == "Спираль" then
        local spiralFactor = (math.sin(t * 0.3) + 1) * 0.5
        local r = baseRadius * (0.4 + 0.6 * spiralFactor)
        local h = baseHeight + math.sin(t * 0.5) * 3
        return math.cos(t) * r, h, math.sin(t) * r
    elseif pattern == "Волна" then
        local h = baseHeight + math.sin(t * 2) * 4
        return math.cos(t) * baseRadius, h, math.sin(t) * baseRadius
    elseif pattern == "Восьмёрка" then
        local x = math.sin(t) * baseRadius
        local z = math.sin(t * 2) * baseRadius * 0.5
        return x, baseHeight, z
    elseif pattern == "Зигзаг" then
        local seg = math.floor(t / (math.pi / 3))
        local dir = (seg % 2 == 0) and 1 or -1
        local x = math.cos(t) * baseRadius
        local z = math.sin(t) * baseRadius
        local h = baseHeight + dir * 2
        return x, h, z
    elseif pattern == "Лиссажу" then
        local a, b = 3, 2
        local x = math.sin(a * t) * baseRadius
        local z = math.sin(b * t + math.pi/2) * baseRadius
        return x, baseHeight, z
    elseif pattern == "Хаос" then
        local r = baseRadius * (0.7 + math.sin(t * 7.3 + ri) * 0.3)
        local h = baseHeight + math.sin(t * 5.1 + ri * 2) * 3
        return math.cos(t) * r, h, math.sin(t) * r
    end
    return math.cos(t) * baseRadius, baseHeight, math.sin(t) * baseRadius
end

-- ==================== УТИЛИТЫ ====================
local function getCurrentShapeSize()
    return SETTINGS.BaseShapeSize * SHAPE_SIZE_PRESETS[shapeSizeIndex].factor
end
local function getTargetRadius(ri)
    return ORBIT_PRESETS[orbitIndex].radius + rings[ri].radiusOffset * RING_STEP * SPREAD_PRESETS[spreadIndex].mult
end
local function getHeightOffset() return HEIGHT_PRESETS[heightIndex].offset end
local function getTargetHeight(ri)
    return ORBIT_PRESETS[orbitIndex].height + rings[ri].heightOffset * SPREAD_PRESETS[spreadIndex].mult + getHeightOffset()
end
local function getTargetSpeed() return SETTINGS.OrbitSpeed * SETTINGS.SpeedMultiplier end
local function getTargetSpin() return SETTINGS.SpinSpeed * SETTINGS.SpeedMultiplier * SETTINGS.SpinSpeedMultiplier end

local function countActiveLights()
    local count = 0
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.light and data.light.Parent then count = count + 1 end
        end
    end
    activeLightCount = count
end

local function applyTrailSettings(trail)
    if not trail then return end
    trail.Lifetime = SETTINGS.TrailLength
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, SETTINGS.TrailWidth),
        NumberSequenceKeypoint.new(1, 0),
    })
end
local function refreshAllTrails()
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.trail then applyTrailSettings(data.trail) end
        end
    end
end
local function applyDirectionPreset()
    local preset = DIRECTION_PRESETS[directionIndex]
    for ri = 1, 5 do rings[ri].direction = preset.dirs[ri] end
end
local function applySpeedModePreset()
    local preset = SPEED_MODE_PRESETS[speedModeIndex]
    for ri = 1, 5 do rings[ri].speedMult = preset.mults[ri] end
end

local function applyShapes()
    if formModeIndex == 1 then
        for ri = 1, 5 do rings[ri].shapeIndex = shapeIndex end
    else
        for ri = 1, 5 do
            rings[ri].shapeIndex = ((shapeIndex + ri - 2) % #SHAPE_PRESETS) + 1
        end
    end
end

local function buildRing(ri)
    local ring = rings[ri]
    if not ring then return end
    if ring.folder then ring.folder:Destroy(); ring.folder = nil end
    ring.blocks = {}

    local folder = Instance.new("Folder")
    folder.Name = "OrbitRing_" .. ri
    folder.Parent = Workspace
    ring.folder = folder

    local shape = SHAPE_PRESETS[ring.shapeIndex] or SHAPE_PRESETS[1]
    local size = getCurrentShapeSize()

    for i = 1, SETTINGS.BlockCount do
        local blockName = "R" .. ri .. "_S" .. i
        local data = shape.create(size, blockName, i)
        local refPart = data.part
        local visualSize = data.visualSize or size

        if not data.isModel then
            refPart.Material = SETTINGS.Material
            refPart.CanCollide = false
            refPart.Anchored = true
            refPart.CastShadow = false
            refPart.Transparency = SETTINGS.Transparency
            refPart.Color = SETTINGS.FixedColor
        end
        if data.isModel then data.model.Parent = folder else refPart.Parent = folder end

        local light = nil
        if SETTINGS.LightEnabled and activeLightCount < SETTINGS.LightLimit then
            light = Instance.new("PointLight")
            light.Name = blockName .. "_Light"
            light.Color = SETTINGS.FixedColor
            light.Range = SETTINGS.LightRange
            light.Brightness = SETTINGS.GlowIntensity
            light.Parent = refPart
            activeLightCount = activeLightCount + 1
        end

        local trail = nil
        if SETTINGS.TrailEnabled then
            local span = visualSize * 0.35
            local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(-span, 0, 0); a0.Parent = refPart
            local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(span, 0, 0); a1.Parent = refPart
            trail = Instance.new("Trail")
            trail.Attachment0 = a0; trail.Attachment1 = a1
            trail.Color = ColorSequence.new(SETTINGS.FixedColor)
            trail.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            })
            applyTrailSettings(trail)
            trail.Parent = refPart
        end

        local nameGui = Instance.new("BillboardGui")
        nameGui.Size = UDim2.new(0, 140, 0, 30)
        nameGui.StudsOffset = Vector3.new(0, visualSize * 0.9 + 1, 0)
        nameGui.AlwaysOnTop = true
        nameGui.LightInfluence = 0
        nameGui.Adornee = refPart
        nameGui.Enabled = SETTINGS.ShowBlockNames
        nameGui.Parent = refPart

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = blockName
        nameLabel.TextScaled = true
        nameLabel.TextColor3 = SETTINGS.NameColor
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextStrokeTransparency = 0.3
        nameLabel.Parent = nameGui

        table.insert(ring.blocks, {
            part = refPart, model = data.model, isModel = data.isModel or false,
            bodyParts = data.bodyParts, light = light, trail = trail, lastTrailUpdate = 0,
            nameGui = nameGui, nameLabel = nameLabel, visualSize = visualSize,
            angleOffset = (i - 1) * (360 / SETTINGS.BlockCount) + ring.angleShift,
        })
    end
    statsData.totalShapes = statsData.totalShapes + #ring.blocks
end

local function destroyRing(ri)
    local ring = rings[ri]
    if not ring then return end
    if ring.folder then ring.folder:Destroy(); ring.folder = nil end
    ring.blocks = {}
end

local function applyColorToBlock(data, c)
    if data.light then data.light.Color = c end
    if data.bodyParts then
        for _, p in ipairs(data.bodyParts) do
            if not p:GetAttribute("NoRecolor") then p.Color = c end
        end
    elseif data.part then data.part.Color = c end
    if data.trail then data.trail.Color = ColorSequence.new(c) end
end

local function applyColor()
    local p = COLOR_PRESETS[colorIndex]
    if p.rainbow then
        SETTINGS.Rainbow = true
    else
        SETTINGS.Rainbow = false
        SETTINGS.FixedColor = p.color
        for _, ring in pairs(rings) do
            for _, data in ipairs(ring.blocks) do
                applyColorToBlock(data, SETTINGS.FixedColor)
            end
        end
    end
end

local function applyNameVisibility()
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.nameGui then data.nameGui.Enabled = SETTINGS.ShowBlockNames end
        end
    end
end

local function rebuildAllRings()
    if not enabled then return end
    statsData.totalShapes = 0
    for ri, ring in pairs(rings) do
        if ring.enabled then destroyRing(ri) end
    end
    countActiveLights()
    for ri, ring in pairs(rings) do
        if ring.enabled then buildRing(ri) end
    end
    applyColor()
    applyNameVisibility()
end

-- ==================== ОБНОВЛЕНИЕ ====================
local function startUpdateLoop()
    if updateConn then return end
    startTime = tick()

    updateConn = RunService.Heartbeat:Connect(function(dt)
        if not enabled then return end
        local character = LocalPlayer.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local t = tick() - startTime
        local globalMult = SETTINGS.SpeedMultiplier
        local lerpFactor = math.clamp(dt * SETTINGS.LerpSpeed, 0, 1)
        local baseSize = getCurrentShapeSize()

        -- FPS счётчик
        statsData.fpsFrames = statsData.fpsFrames + 1
        if t - statsData.fpsLastCheck >= 1 then
            statsData.lastFPS = math.floor(statsData.fpsFrames / (t - statsData.fpsLastCheck))
            statsData.fpsFrames = 0
            statsData.fpsLastCheck = t
        end
        statsData.sessionTime = t

        -- Аура
        updateAura()

        -- Автосмена фигур
        if SETTINGS.AutoShapeSwap and (tick() - lastAutoSwap) > SETTINGS.AutoShapeSwapInterval then
            lastAutoSwap = tick()
            currentAutoShapeIndex = currentAutoShapeIndex + 1
            if currentAutoShapeIndex > #SHAPE_PRESETS then currentAutoShapeIndex = 1 end
            shapeIndex = currentAutoShapeIndex
            applyShapes()
            rebuildAllRings()
            notify("🎭 Автосмена: " .. SHAPE_PRESETS[shapeIndex].name, Color3.fromRGB(220, 200, 255))
        end

        for ri, ring in pairs(rings) do
            currentRadius[ri] = currentRadius[ri] + (getTargetRadius(ri) - currentRadius[ri]) * lerpFactor
            currentHeight[ri] = currentHeight[ri] + (getTargetHeight(ri) - currentHeight[ri]) * lerpFactor
            currentSpeed[ri] = currentSpeed[ri] + (getTargetSpeed() * ring.speedMult * ring.direction - currentSpeed[ri]) * lerpFactor
            currentSpin[ri] = currentSpin[ri] + (getTargetSpin() * ring.speedMult * ring.direction - currentSpin[ri]) * lerpFactor

            currentOrbitAngle[ri] = currentOrbitAngle[ri] + currentSpeed[ri] * dt
            currentBobPhase[ri] = currentBobPhase[ri] + 2 * (globalMult * ring.speedMult) * dt

            if spinResetting then
                local returnSpeed = 3.0
                local backLerp = math.clamp(dt * returnSpeed, 0, 1)
                currentSpinAngle[ri] = currentSpinAngle[ri] + (0 - currentSpinAngle[ri]) * backLerp
                if math.abs(currentSpinAngle[ri]) < 0.01 then
                    currentSpinAngle[ri] = 0
                end
            elseif spinAxisEnabled then
                currentSpinAngle[ri] = currentSpinAngle[ri] + currentSpin[ri] * dt
            end
        end

        local explosionMul = 1.0
        if SETTINGS.ExplosionEnabled then
            local phase = (t * SETTINGS.ExplosionSpeed) % 1
            explosionMul = 1 + math.sin(phase * math.pi * 2) * SETTINGS.ExplosionPower
        end

        local now = tick()

        for ri, ring in pairs(rings) do
            if not ring.enabled then continue end
            local radius = currentRadius[ri] * explosionMul
            local height = currentHeight[ri]
            local orbitAngle = currentOrbitAngle[ri]
            local spinAngle = currentSpinAngle[ri]
            local bobPhase = currentBobPhase[ri]

            for i, data in ipairs(ring.blocks) do
                if not data.part.Parent then continue end
                local angle = math.rad(orbitAngle + data.angleOffset)

                local yBob
                if SETTINGS.WaveEnabled then
                    yBob = math.sin(t * SETTINGS.WaveSpeed - (angle + orbitAngle * 0.002) * SETTINGS.WaveLength) * SETTINGS.WaveAmplitude
                else
                    yBob = math.sin(bobPhase + i + ri * 0.5) * SETTINGS.BobAmplitude
                end

                -- Орбитальный узор
                local px, py, pz = applyOrbitPattern(ri, angle, radius, height + yBob)
                local offset = Vector3.new(px, py, pz)

                local targetCF
                if spinAxisDir == "X" then
                    targetCF = CFrame.new(root.Position + offset)
                        * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle) * 0.7, 0)
                else
                    targetCF = CFrame.new(root.Position + offset)
                        * CFrame.Angles(0, math.rad(spinAngle), 0)
                end

                if data.isModel and data.model then
                    data.model:PivotTo(targetCF)
                else
                    data.part.CFrame = targetCF
                end

                local pulseScale = 1.0
                if SETTINGS.PulseEnabled then
                    pulseScale = 1.0 + math.sin(t * SETTINGS.PulseSpeed + i + ri) * SETTINGS.PulseAmplitude
                end

                if data.isModel and data.model then
                    local target = SETTINGS.PulseEnabled and pulseScale or 1
                    local cur = data.model:GetAttribute("Scale") or 1
                    if math.abs(cur - target) > 0.005 then
                        data.model:ScaleTo(target)
                        data.model:SetAttribute("Scale", target)
                    end
                elseif data.part then
                    local ps = baseSize * pulseScale
                    if math.abs(data.part.Size.X - ps) > 0.001 then
                        data.part.Size = Vector3.new(ps, ps, ps)
                    end
                end

                if SETTINGS.Rainbow then
                    local hue = (t * 0.15 * globalMult * ring.speedMult + i / SETTINGS.BlockCount + ring.colorShift) % 1
                    local c = Color3.fromHSV(hue, 0.9, 1)
                    applyColorToBlock(data, c)
                    if data.trail and (now - data.lastTrailUpdate) > 0.1 then
                        data.trail.Color = ColorSequence.new(c)
                        data.lastTrailUpdate = now
                    end
                elseif SETTINGS.GradientEnabled then
                    local hue = (t * SETTINGS.GradientSpeed + i / SETTINGS.BlockCount) % 1
                    local c = Color3.fromHSV(hue, 0.85, 1)
                    applyColorToBlock(data, c)
                end
            end
        end
    end)
end

local function stopUpdateLoop()
    if updateConn then updateConn:Disconnect(); updateConn = nil end
end

local function setEnabled(state)
    enabled = state
    if enabled then
        countActiveLights()
        for ri, ring in pairs(rings) do
            if ring.enabled then buildRing(ri) end
        end
        applyColor()
        applyNameVisibility()
        startUpdateLoop()
        notify("🟢 Скрипт включён", Color3.fromRGB(100, 255, 150))
    else
        stopUpdateLoop()
        for ri in pairs(rings) do destroyRing(ri) end
        activeLightCount = 0
        if auraFolder then auraFolder:Destroy(); auraFolder = nil end
        notify("🔴 Скрипт выключен", Color3.fromRGB(255, 100, 100))
    end
end

local function setRingEnabled(ri, state)
    local ring = rings[ri]
    if not ring then return end
    ring.enabled = state
    if not enabled then return end
    if state then
        countActiveLights()
        buildRing(ri)
        applyColor()
        applyNameVisibility()
    else
        destroyRing(ri)
        countActiveLights()
    end
end

local function setupRespawnHook()
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if enabled then
            for ri, ring in pairs(rings) do
                if ring.enabled then destroyRing(ri) end
            end
            countActiveLights()
            for ri, ring in pairs(rings) do
                if ring.enabled then buildRing(ri) end
            end
            applyColor()
            applyNameVisibility()
            setupAura()
        end
    end)
end

-- ==================== СОХРАНЕНИЕ / ЗАГРУЗКА ====================
local SAVE_FILE = "OrbitFX_v14_save.json"

local function collectSaveData()
    local ringShapes, ringEnabled = {}, {}
    for ri = 1, 5 do
        ringShapes[ri] = rings[ri].shapeIndex
        ringEnabled[ri] = rings[ri].enabled
    end
    return {
        spreadIndex = spreadIndex, speedIndex = speedIndex, orbitIndex = orbitIndex,
        shapeSizeIndex = shapeSizeIndex, colorIndex = colorIndex,
        trailLengthIndex = trailLengthIndex, trailWidthIndex = trailWidthIndex,
        directionIndex = directionIndex, speedModeIndex = speedModeIndex,
        heightIndex = heightIndex, shapeIndex = shapeIndex, formModeIndex = formModeIndex,
        orbitPatternIndex = orbitPatternIndex, auraTypeIndex = auraTypeIndex,
        ringShapes = ringShapes, ringEnabled = ringEnabled,
        lightEnabled = SETTINGS.LightEnabled, trailEnabled = SETTINGS.TrailEnabled,
        pulseEnabled = SETTINGS.PulseEnabled, showNames = SETTINGS.ShowBlockNames,
        waveEnabled = SETTINGS.WaveEnabled, explosionEnabled = SETTINGS.ExplosionEnabled,
        auraEnabled = SETTINGS.AuraEnabled, auraSize = SETTINGS.AuraSize,
        autoShapeSwap = SETTINGS.AutoShapeSwap,
        autoShapeSwapInterval = SETTINGS.AutoShapeSwapInterval,
        gradientEnabled = SETTINGS.GradientEnabled,
        spinResetting = spinResetting,
        spinAxisEnabled = spinAxisEnabled,
        spinAxisDir = spinAxisDir,
        spinSpeedIndex = spinSpeedIndex,
        heartScale = SETTINGS.HeartScale,
        musicEnabled = musicEnabled, musicId = savedMusicId,
        musicVolume = musicVolume,
    }
end

local function saveSettings()
    if not writefile then return false, "no writefile" end
    local ok, json = pcall(function() return HttpService:JSONEncode(collectSaveData()) end)
    if not ok then return false, "encode" end
    local ok2 = pcall(function() writefile(SAVE_FILE, json) end)
    return ok2
end

local function loadSettings()
    if not isfile or not readfile then return false end
    if not isfile(SAVE_FILE) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
    if not ok or type(data) ~= "table" then return false end

    if data.spreadIndex then spreadIndex = data.spreadIndex end
    if data.speedIndex then speedIndex = data.speedIndex end
    if data.orbitIndex then orbitIndex = data.orbitIndex end
    if data.shapeSizeIndex then shapeSizeIndex = data.shapeSizeIndex end
    if data.colorIndex then colorIndex = data.colorIndex end
    if data.trailLengthIndex then trailLengthIndex = data.trailLengthIndex end
    if data.trailWidthIndex then trailWidthIndex = data.trailWidthIndex end
    if data.directionIndex then directionIndex = data.directionIndex end
    if data.speedModeIndex then speedModeIndex = data.speedModeIndex end
    if data.heightIndex then heightIndex = data.heightIndex end
    if data.shapeIndex then shapeIndex = data.shapeIndex end
    if data.formModeIndex then formModeIndex = data.formModeIndex end
    if data.orbitPatternIndex then orbitPatternIndex = data.orbitPatternIndex end
    if data.auraTypeIndex then auraTypeIndex = data.auraTypeIndex end
    if data.spinResetting ~= nil then spinResetting = data.spinResetting end
    if data.spinAxisEnabled ~= nil then spinAxisEnabled = data.spinAxisEnabled end
    if data.spinAxisDir ~= nil then spinAxisDir = data.spinAxisDir end
    if data.spinSpeedIndex then
        spinSpeedIndex = data.spinSpeedIndex
        SETTINGS.SpinSpeedMultiplier = SPIN_SPEED_PRESETS[spinSpeedIndex].value
    end
    if data.heartScale then SETTINGS.HeartScale = data.heartScale end
    if data.auraEnabled ~= nil then SETTINGS.AuraEnabled = data.auraEnabled end
    if data.auraSize then SETTINGS.AuraSize = data.auraSize end
    if data.autoShapeSwap ~= nil then SETTINGS.AutoShapeSwap = data.autoShapeSwap end
    if data.autoShapeSwapInterval then SETTINGS.AutoShapeSwapInterval = data.autoShapeSwapInterval end
    if data.gradientEnabled ~= nil then SETTINGS.GradientEnabled = data.gradientEnabled end
    if data.musicVolume then musicVolume = data.musicVolume end

    if data.ringShapes then
        for ri = 1, 5 do if data.ringShapes[ri] then rings[ri].shapeIndex = data.ringShapes[ri] end end
    end
    if data.ringEnabled then
        for ri = 1, 5 do
            if data.ringEnabled[ri] ~= nil then
                if rings[ri].enabled and not data.ringEnabled[ri] then destroyRing(ri) end
                rings[ri].enabled = data.ringEnabled[ri]
            end
        end
    end

    if data.lightEnabled ~= nil then SETTINGS.LightEnabled = data.lightEnabled end
    if data.trailEnabled ~= nil then SETTINGS.TrailEnabled = data.trailEnabled end
    if data.pulseEnabled ~= nil then SETTINGS.PulseEnabled = data.pulseEnabled end
    if data.showNames ~= nil then SETTINGS.ShowBlockNames = data.showNames end
    if data.waveEnabled ~= nil then SETTINGS.WaveEnabled = data.waveEnabled end
    if data.explosionEnabled ~= nil then SETTINGS.ExplosionEnabled = data.explosionEnabled end
    if data.musicEnabled ~= nil then musicEnabled = data.musicEnabled end
    if data.musicId then
        savedMusicId = data.musicId
        setMusicId(data.musicId)
    end

    return true
end

-- ==================== АВТОСОХРАНЕНИЕ ====================
task.spawn(function()
    while task.wait(30) do
        pcall(saveSettings)
    end
end)

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrbitFX_UI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.Parent = game.CoreGui

local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, 56, 0, 56)
mainBtn.Position = UDim2.new(0, 20, 0, 100)
mainBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainBtn.BackgroundTransparency = 0.1
mainBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 24
mainBtn.Text = "✨"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke", mainBtn)
mainStroke.Color = Color3.fromRGB(120, 120, 255)
mainStroke.Thickness = 1.5

local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 270, 0, 700)
panel.Position = UDim2.new(0, 90, 0, 5)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 2000)
panel.ScrollBarThickness = 3
panel.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(120, 120, 255)
panelStroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 24)
title.Position = UDim2.new(0, 0, 0, 8)
title.BackgroundTransparency = 1
title.Text = "✨ ОРБИТА v14.0 ULTIMATE"
title.TextColor3 = Color3.fromRGB(200, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = panel

-- Функция для создания секции (заголовок)
local function makeSection(text, y, color)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -20, 0, 20)
    s.Position = UDim2.new(0, 10, 0, y)
    s.BackgroundTransparency = 0.6
    s.BackgroundColor3 = color or Color3.fromRGB(50, 50, 80)
    s.BorderSizePixel = 0
    s.Text = "▸ " .. text
    s.TextColor3 = Color3.fromRGB(220, 220, 255)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 11
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = panel
    Instance.new("UICorner", s).CornerRadius = UDim.new(0, 6)
    return s
end

local function makeButton(text, y, h, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or 30)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(40, 40, 55)
    b.TextColor3 = textColor or Color3.fromRGB(230, 230, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

-- СЕКЦИЯ: Основное
makeSection("⚡ ОСНОВНОЕ", 36, Color3.fromRGB(60, 60, 100))
local toggleBtn     = makeButton("🟢 ВКЛЮЧЕНО", 60, 30, Color3.fromRGB(40, 40, 55), Color3.fromRGB(0, 255, 120))
local allRingsBtn   = makeButton("⭕ Все кольца: ВКЛ", 93, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring2Btn      = makeButton("➕ Кольцо 2", 126, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring3Btn      = makeButton("➕ Кольцо 3", 159, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring4Btn      = makeButton("➕ Кольцо 4", 192, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring5Btn      = makeButton("➕ Кольцо 5", 225, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))

-- СЕКЦИЯ: Форма
makeSection("🔷 ФОРМА И ФИГУРЫ", 262, Color3.fromRGB(60, 80, 100))
local shapeBtn      = makeButton("🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name, 286, 30)
local shapeModeBtn  = makeButton("🎭 Формы: " .. FORM_MODES[formModeIndex].name, 319, 30, Color3.fromRGB(50, 40, 65), Color3.fromRGB(220, 200, 255))
local shapeSizeBtn  = makeButton("🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name, 352, 30)
local heartSizeBtn  = makeButton("💗 Сердце: 100%", 385, 30, Color3.fromRGB(70, 30, 55), Color3.fromRGB(255, 160, 200))
local autoSwapBtn   = makeButton("🎭 Автосмена: ВЫКЛ", 418, 30, Color3.fromRGB(50, 50, 70), Color3.fromRGB(200, 200, 255))

-- СЕКЦИЯ: Орбита
makeSection("🛰️ ОРБИТА И ДВИЖЕНИЕ", 455, Color3.fromRGB(60, 100, 80))
local orbitBtn      = makeButton("📏 Орбита: " .. ORBIT_PRESETS[orbitIndex].name, 479, 30)
local spreadBtn     = makeButton("📐 Разлёт: " .. SPREAD_PRESETS[spreadIndex].name, 512, 30, Color3.fromRGB(55, 30, 55), Color3.fromRGB(255, 180, 255))
local heightBtn     = makeButton("⬆️ Высота: " .. HEIGHT_PRESETS[heightIndex].name, 545, 30, Color3.fromRGB(35, 55, 65), Color3.fromRGB(140, 220, 255))
local speedBtn      = makeButton("⚡ Множитель: " .. SPEED_PRESETS[speedIndex].name, 578, 30, Color3.fromRGB(55, 45, 20), Color3.fromRGB(255, 220, 100))
local speedModeBtn  = makeButton("⚙️ Скорость: " .. SPEED_MODE_PRESETS[speedModeIndex].name, 611, 30, Color3.fromRGB(45, 50, 65), Color3.fromRGB(180, 220, 255))
local directionBtn  = makeButton("🔃 Направление: " .. DIRECTION_PRESETS[directionIndex].name, 644, 30, Color3.fromRGB(45, 35, 60), Color3.fromRGB(200, 180, 255))
local orbitPatternBtn = makeButton("🌀 Узор: " .. ORBIT_PATTERNS[orbitPatternIndex].name, 677, 30, Color3.fromRGB(60, 40, 90), Color3.fromRGB(220, 180, 255))

-- СЕКЦИЯ: Кручение
makeSection("🔄 КРУЧЕНИЕ", 714, Color3.fromRGB(100, 60, 80))
local spinBtn       = makeButton("↩️ Вращение в 0", 738, 30, Color3.fromRGB(50, 40, 60), Color3.fromRGB(200, 180, 255))
local spinAxisBtn   = makeButton("🔄 Кручение оси: ВКЛ", 771, 30, Color3.fromRGB(35, 55, 55), Color3.fromRGB(140, 255, 220))
local spinDirBtn    = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 804, 30, Color3.fromRGB(45, 55, 75), Color3.fromRGB(180, 220, 255))
local spinSpeedBtn  = makeButton("🌀 Скорость кручения: 1x", 837, 30, Color3.fromRGB(55, 35, 75), Color3.fromRGB(220, 180, 255))

-- СЕКЦИЯ: Эффекты
makeSection("✨ ЭФФЕКТЫ", 874, Color3.fromRGB(100, 80, 60))
local trailBtn      = makeButton("🌠 Трейлы: ВЫКЛ", 898, 30, Color3.fromRGB(35, 35, 50))
local trailLenBtn   = makeButton("📏 Трейл: " .. TRAIL_LENGTH_PRESETS[trailLengthIndex].name, 931, 30, Color3.fromRGB(35, 45, 60), Color3.fromRGB(180, 220, 255))
local trailWidBtn   = makeButton("🎚️ Толщина: " .. TRAIL_WIDTH_PRESETS[trailWidthIndex].name, 964, 30, Color3.fromRGB(35, 45, 60), Color3.fromRGB(180, 220, 255))
local waveBtn       = makeButton("🌊 Волна: ВЫКЛ", 997, 30, Color3.fromRGB(30, 55, 75), Color3.fromRGB(140, 220, 255))
local explosionBtn  = makeButton("💥 Взрыв: ВЫКЛ", 1030, 30, Color3.fromRGB(70, 40, 30), Color3.fromRGB(255, 180, 120))
local pulseBtn      = makeButton("💓 Пульсация: ВЫКЛ", 1063, 30, Color3.fromRGB(35, 35, 50))
local gradientBtn   = makeButton("🌈 Градиент: ВЫКЛ", 1096, 30, Color3.fromRGB(55, 35, 75), Color3.fromRGB(255, 180, 255))

-- СЕКЦИЯ: Аура
makeSection("🌀 АУРА", 1133, Color3.fromRGB(80, 60, 120))
local auraBtn       = makeButton("🌀 Аура: ВЫКЛ", 1157, 30, Color3.fromRGB(50, 40, 70), Color3.fromRGB(200, 180, 255))
local auraTypeBtn   = makeButton("🔮 Тип: " .. AURA_TYPES[auraTypeIndex].name, 1190, 30, Color3.fromRGB(50, 40, 70), Color3.fromRGB(200, 180, 255))

-- СЕКЦИЯ: Цвет и свет
makeSection("🎨 ЦВЕТ И СВЕТ", 1227, Color3.fromRGB(100, 100, 50))
local colorBtn      = makeButton("🎨 Цвет: " .. COLOR_PRESETS[colorIndex].name, 1251, 30)
local lightBtn      = makeButton("💡 Свет: ВКЛ", 1284, 30, Color3.fromRGB(35, 50, 35), Color3.fromRGB(160, 255, 160))
local nameBtn       = makeButton("🏷️ Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ"), 1317, 30)

-- СЕКЦИЯ: Статистика
makeSection("📊 СТАТИСТИКА", 1354, Color3.fromRGB(60, 60, 90))
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 50)
statsLabel.Position = UDim2.new(0, 10, 0, 1378)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "FPS: -- | Фигур: 0 | Время: 0 сек"
statsLabel.Parent = panel
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)

-- СЕКЦИЯ: Музыка
makeSection("🎵 МУЗЫКА", 1438, Color3.fromRGB(80, 60, 100))
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -20, 0, 32)
musicInput.Position = UDim2.new(0, 10, 0, 1462)
musicInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
musicInput.BackgroundTransparency = 0.1
musicInput.TextColor3 = Color3.fromRGB(240, 230, 255)
musicInput.Font = Enum.Font.GothamBold
musicInput.TextSize = 12
musicInput.PlaceholderText = "Пример: 1839246711"
musicInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
musicInput.Text = ""
musicInput.ClearTextOnFocus = false
musicInput.Parent = panel
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 8)
local inputStroke = Instance.new("UIStroke", musicInput)
inputStroke.Color = Color3.fromRGB(180, 140, 255)
inputStroke.Thickness = 1

local applyIdBtn = makeButton("✅ Применить ID", 1500, 30, Color3.fromRGB(55, 80, 55), Color3.fromRGB(180, 255, 180))
local musicBtn      = makeButton("🎵 Музыка: ВЫКЛ", 1533, 30, Color3.fromRGB(50, 35, 60), Color3.fromRGB(220, 180, 255))

-- СЕКЦИЯ: Система
makeSection("💾 СИСТЕМА", 1570, Color3.fromRGB(60, 60, 80))
local saveBtn       = makeButton("💾 Сохранить", 1594, 30, Color3.fromRGB(35, 60, 45), Color3.fromRGB(160, 255, 180))
local loadBtn       = makeButton("📂 Загрузить", 1627, 30, Color3.fromRGB(35, 50, 60), Color3.fromRGB(180, 220, 255))
local resetBtn      = makeButton("🔄 Сброс", 1660, 30, Color3.fromRGB(50, 30, 30), Color3.fromRGB(255, 180, 180))

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Text = "✖"
closeBtn.AutoButtonColor = true
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- ==================== ОБРАБОТЧИКИ UI ====================
local ringButtons = { [2] = ring2Btn, [3] = ring3Btn, [4] = ring4Btn, [5] = ring5Btn }

local function refreshRingButton(ri)
    local btn = ringButtons[ri]
    if not btn then return end
    if rings[ri].enabled then
        btn.Text = "➖ Убрать кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(55, 40, 40)
        btn.TextColor3 = Color3.fromRGB(255, 160, 160)
    else
        btn.Text = "➕ Кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(40, 55, 40)
        btn.TextColor3 = Color3.fromRGB(160, 255, 160)
    end
end

local function refreshSpinSpeedBtn()
    local p = SPIN_SPEED_PRESETS[spinSpeedIndex]
    spinSpeedBtn.Text = "🌀 Скорость кручения: " .. p.name
    if p.value <= 1.0 then
        spinSpeedBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 75)
        spinSpeedBtn.TextColor3 = Color3.fromRGB(180, 200, 255)
    elseif p.value <= 3.0 then
        spinSpeedBtn.BackgroundColor3 = Color3.fromRGB(55, 45, 85)
        spinSpeedBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
    else
        spinSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 90)
        spinSpeedBtn.TextColor3 = Color3.fromRGB(255, 160, 255)
    end
end

local HEART_SCALE_STEPS = {
    0.1625,   -- 25%
    0.325,    -- 50%
    0.455,    -- 70%
    0.65,     -- 100%
    0.975,    -- 150%
    1.3,      -- 200%
    1.625,    -- 250%
    1.95,     -- 300%
}
local heartScaleIndex = 4

local function refreshHeartSizeBtn()
    local pct = math.floor(SETTINGS.HeartScale / 0.65 * 100 + 0.5)
    heartSizeBtn.Text = "💗 Сердце: " .. pct .. "%"
    if pct <= 50 then
        heartSizeBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
        heartSizeBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
    elseif pct <= 100 then
        heartSizeBtn.BackgroundColor3 = Color3.fromRGB(60, 35, 65)
        heartSizeBtn.TextColor3 = Color3.fromRGB(255, 180, 220)
    elseif pct <= 200 then
        heartSizeBtn.BackgroundColor3 = Color3.fromRGB(75, 30, 60)
        heartSizeBtn.TextColor3 = Color3.fromRGB(255, 160, 210)
    else
        heartSizeBtn.BackgroundColor3 = Color3.fromRGB(90, 25, 55)
        heartSizeBtn.TextColor3 = Color3.fromRGB(255, 130, 200)
    end
end

-- Обработчики
mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)
closeBtn.Activated:Connect(function() panel.Visible = false end)

toggleBtn.Activated:Connect(function()
    setEnabled(not enabled)
    if enabled then
        toggleBtn.Text = "🟢 ВКЛЮЧЕНО"
        toggleBtn.TextColor3 = Color3.fromRGB(0, 255, 120)
    else
        toggleBtn.Text = "🔴 ВЫКЛЮЧЕНО"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

allRingsBtn.Activated:Connect(function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local newState = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= newState then setRingEnabled(ri, newState) end end
    for ri = 2, 5 do refreshRingButton(ri) end
    if newState then
        allRingsBtn.Text = "⭕ Все кольца: ВЫКЛ"
        allRingsBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
        allRingsBtn.BackgroundColor3 = Color3.fromRGB(55, 40, 40)
    else
        allRingsBtn.Text = "⭕ Все кольца: ВКЛ"
        allRingsBtn.TextColor3 = Color3.fromRGB(160, 255, 160)
        allRingsBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 40)
    end
end)

for ri, btn in pairs(ringButtons) do
    btn.Activated:Connect(function()
        local ns = not rings[ri].enabled
        setRingEnabled(ri, ns)
        refreshRingButton(ri)
    end)
end

shapeBtn.Activated:Connect(function()
    shapeIndex = shapeIndex + 1
    if shapeIndex > #SHAPE_PRESETS then shapeIndex = 1 end
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name
    applyShapes()
    rebuildAllRings()
    notify("🔷 " .. SHAPE_PRESETS[shapeIndex].name, Color3.fromRGB(180, 220, 255))
end)

shapeModeBtn.Activated:Connect(function()
    formModeIndex = formModeIndex + 1
    if formModeIndex > #FORM_MODES then formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Формы: " .. FORM_MODES[formModeIndex].name
    applyShapes()
    rebuildAllRings()
end)

shapeSizeBtn.Activated:Connect(function()
    shapeSizeIndex = shapeSizeIndex + 1
    if shapeSizeIndex > #SHAPE_SIZE_PRESETS then shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name
    rebuildAllRings()
end)

heartSizeBtn.Activated:Connect(function()
    heartScaleIndex = heartScaleIndex + 1
    if heartScaleIndex > #HEART_SCALE_STEPS then heartScaleIndex = 1 end
    SETTINGS.HeartScale = HEART_SCALE_STEPS[heartScaleIndex]
    refreshHeartSizeBtn()
    rebuildAllRings()
    notify("💗 Сердце: " .. math.floor(SETTINGS.HeartScale / 0.65 * 100) .. "%", Color3.fromRGB(255, 180, 220))
end)

autoSwapBtn.Activated:Connect(function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "🎭 Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then
        autoSwapBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
        autoSwapBtn.TextColor3 = Color3.fromRGB(255, 200, 255)
        lastAutoSwap = tick()
        notify("🎭 Автосмена: ВКЛ (каждые " .. SETTINGS.AutoShapeSwapInterval .. " сек)", Color3.fromRGB(220, 180, 255))
    else
        autoSwapBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        autoSwapBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
    end
end)

orbitBtn.Activated:Connect(function()
    orbitIndex = orbitIndex + 1
    if orbitIndex > #ORBIT_PRESETS then orbitIndex = 1 end
    orbitBtn.Text = "📏 Орбита: " .. ORBIT_PRESETS[orbitIndex].name
end)

spreadBtn.Activated:Connect(function()
    spreadIndex = spreadIndex + 1
    if spreadIndex > #SPREAD_PRESETS then spreadIndex = 1 end
    spreadBtn.Text = "📐 Разлёт: " .. SPREAD_PRESETS[spreadIndex].name
end)

heightBtn.Activated:Connect(function()
    heightIndex = heightIndex + 1
    if heightIndex > #HEIGHT_PRESETS then heightIndex = 1 end
    heightBtn.Text = "⬆️ Высота: " .. HEIGHT_PRESETS[heightIndex].name
end)

speedBtn.Activated:Connect(function()
    speedIndex = speedIndex + 1
    if speedIndex > #SPEED_PRESETS then speedIndex = 1 end
    SETTINGS.SpeedMultiplier = SPEED_PRESETS[speedIndex].value
    speedBtn.Text = "⚡ Множитель: " .. SPEED_PRESETS[speedIndex].name
end)

speedModeBtn.Activated:Connect(function()
    speedModeIndex = speedModeIndex + 1
    if speedModeIndex > #SPEED_MODE_PRESETS then speedModeIndex = 1 end
    speedModeBtn.Text = "⚙️ Скорость: " .. SPEED_MODE_PRESETS[speedModeIndex].name
    applySpeedModePreset()
end)

directionBtn.Activated:Connect(function()
    directionIndex = directionIndex + 1
    if directionIndex > #DIRECTION_PRESETS then directionIndex = 1 end
    directionBtn.Text = "🔃 Направление: " .. DIRECTION_PRESETS[directionIndex].name
    applyDirectionPreset()
end)

orbitPatternBtn.Activated:Connect(function()
    orbitPatternIndex = orbitPatternIndex + 1
    if orbitPatternIndex > #ORBIT_P
