--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   ОРБИТА ФИГУР v15.3 (Delta Edition - MESH + SMOOTH)     ║
    ║   + 27 фигур с улучшенными деталями                      ║
    ║   + MESH_CONFIG для своих 3D-моделей                     ║
    ║   + 7 орбитальных узоров                                 ║
    ║   + Аура: кольцо / частицы / мини-кольцо из фигур        ║
    ║   + Вкладка "Люди и кольца" - копия кольца на игрока     ║
    ║   + Система уведомлений / статистика / автосмена         ║
    ║   + Сохранение в файл + автосохранение 30 сек            ║
    ╚══════════════════════════════════════════════════════════╝
--]]

-- ==================== DELTA / EXECUTOR ====================
local getgenv_fn = rawget(_G, "getgenv") or function() return _G end
local GENV = getgenv_fn()

if GENV.OrbitFX_Unload then pcall(GENV.OrbitFX_Unload) end

local function getSafeParent()
    if rawget(GENV, "gethui") then
        local ok, hui = pcall(GENV.gethui)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local function protectGui(gui)
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui)
    elseif rawget(GENV, "protect_gui") then pcall(GENV.protect_gui, gui) end
end

-- ==================== СЕРВИСЫ ====================
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local SAVE_FILE = "orbit_v15_settings.json"
local HAS_FS = (writefile and readfile and isfile and type(writefile) == "function")

-- ==================== МЕШИ ====================
local MESH_CONFIG = {
    ["БЛОК"] = { MeshId = "", TextureId = "" },
    ["ШАР"] = { MeshId = "", TextureId = "" },
    ["ЦИЛИНДР"] = { MeshId = "", TextureId = "" },
    ["КЛИН"] = { MeshId = "", TextureId = "" },
    ["ГОЛОВА"] = { MeshId = "", TextureId = "" },
    ["СЕРДЦЕ"] = { MeshId = "", TextureId = "" },
    ["ЗВЕЗДА"] = { MeshId = "", TextureId = "" },
    ["ТРЕУГОЛЬНИК"] = { MeshId = "", TextureId = "" },
    ["РОМБ"] = { MeshId = "", TextureId = "" },
    ["КРЕСТ"] = { MeshId = "", TextureId = "" },
    ["ЧЕРЕП"] = { MeshId = "", TextureId = "" },
    ["МОЛНИЯ"] = { MeshId = "", TextureId = "" },
    ["РУКА"] = { MeshId = "", TextureId = "" },
    ["РУКА-СЕРДЦЕ"] = { MeshId = "", TextureId = "" },
    ["ГАСТЕР БЛАСТЕР"] = { MeshId = "", TextureId = "" },
    ["МЕЧ"] = { MeshId = "", TextureId = "" },
    ["ЩИТ"] = { MeshId = "", TextureId = "" },
    ["КОРОНА"] = { MeshId = "", TextureId = "" },
    ["КОСТЬ"] = { MeshId = "", TextureId = "" },
    ["КРИСТАЛЛ"] = { MeshId = "", TextureId = "" },
    ["ПИРАМИДА"] = { MeshId = "", TextureId = "" },
    ["ИНЬ-ЯН"] = { MeshId = "", TextureId = "" },
    ["ГЛАЗ"] = { MeshId = "", TextureId = "" },
    ["РУНА"] = { MeshId = "", TextureId = "" },
    ["СПИРАЛЬ"] = { MeshId = "", TextureId = "" },
    ["КРЫЛЬЯ"] = { MeshId = "", TextureId = "" },
    ["ЩУПАЛЬЦЕ"] = { MeshId = "", TextureId = "" },
}

-- ==================== МУЗЫКА ====================
local musicEnabled = false
local musicSound = nil
local savedMusicId = ""
local musicVolume = 0.5

local function createMusicSound()
    if musicSound and musicSound.Parent then return end
    musicSound = Instance.new("Sound")
    musicSound.Name = "OrbitMusic_" .. tostring(math.random(1, 999999))
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

-- ==================== УВЕДОМЛЕНИЯ ====================
local NOTIF_QUEUE = {}
local function notify(text, color, duration)
    table.insert(NOTIF_QUEUE, { text = text, color = color or Color3.fromRGB(140, 255, 200), duration = duration or 2 })
end

-- ==================== НАСТРОЙКИ ====================
local DEFAULT_SETTINGS = {
    BlockCount = 8, BaseShapeSize = 1.5, OrbitSpeed = 60, SpinSpeed = 120,
    SpeedMultiplier = 1.0, SpinSpeedMultiplier = 1.0, BobAmplitude = 0.8,
    Material = Enum.Material.Neon, Transparency = 0.1, LightRange = 6, LightLimit = 20,
    LightEnabled = true, Rainbow = true, FixedColor = Color3.fromRGB(0, 180, 255),
    ShowBlockNames = false, NameColor = Color3.fromRGB(255, 255, 255), LerpSpeed = 5.0,
    TrailEnabled = false, TrailLength = 0.5, TrailWidth = 0.8,
    PulseEnabled = false, PulseAmplitude = 0.15, PulseSpeed = 4.0,
    WaveEnabled = false, WaveSpeed = 3.0, WaveLength = 2.0, WaveAmplitude = 2.5,
    ExplosionEnabled = false, ExplosionSpeed = 0.4, ExplosionPower = 0.7,
    HeartScale = 0.65, OrbitPattern = "Круг",
    AuraEnabled = false, AuraType = "Кольцо", AuraSize = 3.5, AuraThickness = 0.15,
    AuraColor = Color3.fromRGB(150, 100, 255),
    AutoShapeSwap = false, AutoShapeSwapInterval = 15,
    GradientEnabled = false, GradientSpeed = 0.5, GlowEnabled = true, GlowIntensity = 2,
}
local SETTINGS = table.clone(DEFAULT_SETTINGS)

-- ==================== ПРЕСЕТЫ ====================
local SPIN_SPEED_PRESETS = {
    { name = "0.5x", value = 0.5 }, { name = "1x", value = 1.0 }, { name = "2x", value = 2.0 },
    { name = "3x", value = 3.0 }, { name = "5x", value = 5.0 }, { name = "10x", value = 10.0 },
}
local spinSpeedIndex = 2

local SPREAD_PRESETS = {
    { name = "1x плотно", mult = 1.0 }, { name = "1.5x", mult = 1.5 }, { name = "2x средне", mult = 2.0 },
    { name = "3x широко", mult = 3.0 }, { name = "5x максимально", mult = 5.0 },
}
local spreadIndex = 2

local HEIGHT_PRESETS = {
    { name = "Возле (у ног)", offset = -3.0 }, { name = "Ноги", offset = -1.0 },
    { name = "Низко", offset = 0.5 }, { name = "Середина", offset = 2.0 },
    { name = "Туловище", offset = 3.0 }, { name = "Голова", offset = 4.5 },
    { name = "Высоко", offset = 6.5 }, { name = "Небо", offset = 35.0 }, { name = "Космос", offset = 60.0 },
}
local heightIndex = 4

local SPEED_PRESETS = {
    { name = "0.5x", value = 0.5 }, { name = "1x", value = 1.0 }, { name = "1.5x", value = 1.5 },
    { name = "2x", value = 2.0 }, { name = "3x", value = 3.0 }, { name = "5x", value = 5.0 },
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

local FORM_MODES = { { name = "Одинаковая" }, { name = "Разные" } }
local formModeIndex = 1

local ORBIT_PRESETS = {
    { name = "S", radius = 5, height = 2 }, { name = "M", radius = 8, height = 3 },
    { name = "L", radius = 12, height = 4 }, { name = "XL", radius = 18, height = 6 },
    { name = "XXL", radius = 25, height = 8 },
}
local orbitIndex = 2

local SHAPE_SIZE_PRESETS = {
    { name = "XS", factor = 0.5 }, { name = "S", factor = 0.75 }, { name = "M", factor = 1.0 },
    { name = "L", factor = 1.5 }, { name = "XL", factor = 2.2 }, { name = "XXL", factor = 3.0 },
}
local shapeSizeIndex = 3

local ORBIT_PATTERNS = {
    { name = "Круг" }, { name = "Спираль" }, { name = "Волна" }, { name = "Восьмёрка" },
    { name = "Зигзаг" }, { name = "Лиссажу" }, { name = "Хаос" },
}
local orbitPatternIndex = 1

local AURA_TYPES = {
    { name = "Кольцо" }, { name = "Частицы" }, { name = "Фигуры" }, { name = "Оба" }, { name = "Всё" },
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
local auraColorIndex = 1

local TRAIL_LENGTH_PRESETS = {
    { name = "Короткий", value = 0.25 }, { name = "Средний", value = 0.5 },
    { name = "Длинный", value = 0.9 }, { name = "Очень длинный", value = 1.6 },
    { name = "Гигантский", value = 2.5 },
}
local trailLengthIndex = 2

local TRAIL_WIDTH_PRESETS = {
    { name = "Тонкий", value = 0.3 }, { name = "Средний", value = 0.8 },
    { name = "Толстый", value = 1.5 }, { name = "Широкий", value = 2.5 },
    { name = "Огромный", value = 4.0 },
}
local trailWidthIndex = 2

-- ==================== СОСТОЯНИЕ ====================
local enabled = true
local spinResetting = false
local spinAxisEnabled = true
local spinAxisDir = "X"
local updateConn = nil
local startTime = tick()
local activeLightCount = 0
local currentRadius, currentHeight, currentSpeed, currentSpin = {}, {}, {}, {}
local currentOrbitAngle, currentSpinAngle, currentBobPhase = {}, {}, {}
local lastAutoSwap = tick()
local currentAutoShapeIndex = 1
local statsData = {
    totalShapes = 0, sessionTime = 0, lastFPS = 60,
    fpsFrames = 0, fpsLastCheck = tick(),
}
local auraFolder = nil
local auraParts = {}
local auraBlocks = {}
local auraAngle = 0
local auraShapeIndex = 1

-- Кольца на других игроках
local targetRings = {}
local peopleButtons = {}

-- ==================== FORWARD DECLARATIONS ====================
-- Эти функции объявлены в секции УТИЛИТЫ ниже, но используются
-- в setupAura/buildTargetRings/updateTargetRings, объявленных раньше.
local getCurrentShapeSize, getTargetRadius, getHeightOffset, getTargetHeight, getTargetSpeed, getTargetSpin

local RING_STEP = 5
local rings = {
    [1] = { enabled = true,  shapeIndex = 1, folder = nil, blocks = {}, radiusOffset = 0, heightOffset = 0,   direction = 1,  speedMult = 1.0, angleShift = 0,   colorShift = 0   },
    [2] = { enabled = false, shapeIndex = 2, folder = nil, blocks = {}, radiusOffset = 1, heightOffset = -0.5, direction = -1, speedMult = 1.3, angleShift = 22.5, colorShift = 0.2 },
    [3] = { enabled = false, shapeIndex = 3, folder = nil, blocks = {}, radiusOffset = 2, heightOffset = 0.5,  direction = 1,  speedMult = 0.7, angleShift = 45,  colorShift = 0.4 },
    [4] = { enabled = false, shapeIndex = 4, folder = nil, blocks = {}, radiusOffset = 3, heightOffset = -1,   direction = -1, speedMult = 1.6, angleShift = 67.5, colorShift = 0.6 },
    [5] = { enabled = false, shapeIndex = 5, folder = nil, blocks = {}, radiusOffset = 4, heightOffset = 1,    direction = 1,  speedMult = 0.5, angleShift = 90,  colorShift = 0.8 },
}

for ri in pairs(rings) do
    currentRadius[ri], currentHeight[ri], currentSpeed[ri], currentSpin[ri] = 8, 3, 60, 120
    currentOrbitAngle[ri], currentSpinAngle[ri], currentBobPhase[ri] = 0, 0, 0
end

-- ==================== ХЕЛПЕРЫ ====================
local function newPart(parent, name, size, cf, color, noRecolor)
    local p = Instance.new("Part")
    p.Name = name; p.Size = size; p.CFrame = cf
    p.Anchored = true; p.CanCollide = false; p.CastShadow = false
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
    root.Name = "Root"; root.Size = Vector3.new(0.1, 0.1, 0.1); root.Transparency = 1
    root.Anchored = true; root.CanCollide = false; root.CastShadow = false
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
    part.Anchored = true; part.CanCollide = false; part.CastShadow = false
    part.Material = Enum.Material.Neon; part.Color = color; part.Parent = parent
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
        if dlen > 0.001 then cx = cx + dx / dlen * cornerR; cy = cy + dy / dlen * cornerR end
        local outerPt = Vector3.new(cx, cy, 0)
        local innerPt = Vector3.new(math.cos(mid) * holeR, math.sin(mid) * holeR, 0)
        local midPt = (outerPt + innerPt) * 0.5
        local segLen = (outerPt - innerPt).Magnitude
        local angle = math.atan2(outerPt.Y - innerPt.Y, outerPt.X - innerPt.X)
        local tangentLen = 2 * math.pi * (half * 0.7) / segments * 1.4
        local partCF = cf * CFrame.new(midPt.X, midPt.Y, 0) * CFrame.Angles(0, 0, angle)
        table.insert(bodies, newPart(model, "Palm", Vector3.new(segLen, tangentLen, depth), partCF, color))
    end
    local spikeLen = holeR * 0.65
    local spikeW = holeR * 0.38
    for k = 0, 3 do
        local ang = math.rad(k * 90 + 45)
        local spikeCF = cf
            * CFrame.new(math.cos(ang) * (holeR - spikeLen * 0.3), math.sin(ang) * (holeR - spikeLen * 0.3), 0)
            * CFrame.Angles(0, 0, ang - math.pi / 2)
        local w = Instance.new("WedgePart")
        w.Name = "Spike"; w.Size = Vector3.new(spikeW, spikeLen, depth * 0.75); w.CFrame = spikeCF
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
        w.Material = Enum.Material.Neon; w.Color = color; w.Parent = model
        table.insert(bodies, w)
    end
end

local function createFinger(model, bodies, baseCF, length, width, color)
    local seg1, seg2, seg3 = length * 0.30, length * 0.38, length * 0.32
    local w1, w2, w3, w4 = width, width * 0.75, width * 0.35, width * 0.05
    table.insert(bodies, newPart(model, "F1", Vector3.new(w1, seg1, w1 * 0.5), baseCF * CFrame.new(0, seg1 / 2, 0), color))
    table.insert(bodies, newPart(model, "F2", Vector3.new(w2, seg2, w2 * 0.5), baseCF * CFrame.new(0, seg1 + seg2 / 2, 0), color))
    table.insert(bodies, newPart(model, "F3", Vector3.new(w3, seg3 * 0.55, w3 * 0.45), baseCF * CFrame.new(0, seg1 + seg2 + seg3 * 0.275, 0), color))
    table.insert(bodies, newPart(model, "F4", Vector3.new(w4, seg3 * 0.45, w4 * 0.45), baseCF * CFrame.new(0, seg1 + seg2 + seg3 * 0.55 + seg3 * 0.225, 0), color))
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
    for k = 1, 10 do table.insert(bodies, makeRod(model, verts[k], verts[(k % 10) + 1], t, d, color)) end
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
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
        table.insert(bodies, p); return p
    end
    local function block(sz, cf, col, noRecolor)
        local p = newPart(model, "B", sz, cf, col, noRecolor)
        p.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, p); return p
    end
    ellipsoid(Vector3.new(1.15*s, 1.10*s, 1.10*s), CFrame.new(0, 0.30*s, 0.08*s), bone)
    ellipsoid(Vector3.new(0.85*s, 0.70*s, 0.75*s), CFrame.new(0, -0.16*s, -0.08*s), bone)
    ellipsoid(Vector3.new(0.90*s, 0.16*s, 0.30*s), CFrame.new(0, 0.16*s, -0.36*s), bone)
    for _, side in ipairs({-1, 1}) do
        ellipsoid(Vector3.new(0.34*s, 0.30*s, 0.20*s), CFrame.new(side*0.30*s, 0.26*s, -0.34*s), socketShade, true)
    end
    for _, side in ipairs({-1, 1}) do
        ellipsoid(Vector3.new(0.30*s, 0.26*s, 0.30*s), CFrame.new(side*0.43*s, -0.02*s, -0.18*s), bone)
        ellipsoid(Vector3.new(0.42*s, 0.40*s, 0.14*s), CFrame.new(side*0.25*s, 0.03*s, -0.41*s), bone)
        ellipsoid(Vector3.new(0.32*s, 0.30*s, 0.14*s), CFrame.new(side*0.25*s, 0.03*s, -0.44*s), dark, true)
        block(Vector3.new(0.09*s, 0.62*s, 0.30*s), CFrame.new(side*0.42*s, -0.35*s, 0.02*s), bone)
    end
    local nose = newPart(model, "N", Vector3.new(0.20*s, 0.26*s, 0.14*s),
        CFrame.new(0, -0.22*s, -0.42*s) * CFrame.Angles(math.rad(180), 0, 0), dark, true)
    local nm = Instance.new("SpecialMesh"); nm.MeshType = Enum.MeshType.Pyramid; nm.Parent = nose
    table.insert(bodies, nose)
    ellipsoid(Vector3.new(0.80*s, 0.46*s, 0.62*s), CFrame.new(0, -0.62*s, -0.10*s), bone)
    block(Vector3.new(0.62*s, 0.05*s, 0.20*s), CFrame.new(0, -0.47*s, -0.30*s), dark, true)
    for i = 1, 8 do
        local x = (i - 4.5) * 0.085 * s
        local k = x / (0.3 * s)
        block(Vector3.new(0.08*s, 0.13*s, 0.09*s), CFrame.new(x, -0.40*s, (-0.37 + k*k*0.08)*s), toothColor, true)
        block(Vector3.new(0.075*s, 0.12*s, 0.09*s), CFrame.new(x, -0.53*s, (-0.35 + k*k*0.08)*s), toothColor, true)
    end
    return model, root, bodies
end

local function addTriangle(parent, a, b, c, thickness, color, bodies)
    local ab, ac, bc = b - a, c - a, c - b
    local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
    if abd > acd and abd > bcd then c, a = a, c
    elseif acd > bcd and acd > abd then a, b = b, a end
    ab, ac, bc = b - a, c - a, c - b
    local right = ac:Cross(ab).Unit
    local up = bc:Cross(right).Unit
    local back = bc.Unit
    local height = math.abs(ab:Dot(up))
    local function wedge(lenZ, cf)
        local w = Instance.new("WedgePart")
        w.Name = "W"; w.Size = Vector3.new(thickness, height, lenZ); w.CFrame = cf
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
        w.Material = Enum.Material.SmoothPlastic; w.Color = color; w.Parent = parent
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
    local p1, p2, p3 = P(-15, 115), P(68, 115), P(28, 20)
    local p4, p5, p6, p7 = P(55, 20), P(-42, -112), P(2, 20), P(-55, 20)
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
    local vT, vR = Vector3.new(0, R, 0), Vector3.new(R * 0.75, 0, 0)
    local vB, vL = Vector3.new(0, -R, 0), Vector3.new(-R * 0.75, 0, 0)
    table.insert(bodies, makeRod(model, vT, vR, t, d, color))
    table.insert(bodies, makeRod(model, vR, vB, t, d, color))
    table.insert(bodies, makeRod(model, vB, vL, t, d, color))
    table.insert(bodies, makeRod(model, vL, vT, t, d, color))
    return model, root, bodies
end

local HEART_PATTERN = { "11011", "11111", "11111", "01110", "00100" }
local function createPixelHeart(sizeStuds, color, name)
    local rows, cols = #HEART_PATTERN, #HEART_PATTERN[1]
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
            else c = c + 1 end
        end
    end
    return model, root, bodies
end

local HEART_COLORS = {
    Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 230, 60),
    Color3.fromRGB(255, 0, 200), Color3.fromRGB(220, 20, 60),
    Color3.fromRGB(0, 255, 120), Color3.fromRGB(0, 220, 220), Color3.fromRGB(40, 80, 255),
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
    table.insert(bodies, newPart(model, "Wrap1", Vector3.new(s*2.4, s*0.26, s*0.40),
        palmCF * CFrame.new(0, wrapY, 0) * CFrame.Angles(0, 0, math.rad(14)), color))
    table.insert(bodies, newPart(model, "Wrap2", Vector3.new(s*2.4, s*0.26, s*0.40),
        palmCF * CFrame.new(0, wrapY, 0) * CFrame.Angles(0, 0, math.rad(-14)), color))
    local fingerBaseY = s * 0.88
    local fingers = {
        { len = 2.20, w = 0.36, offsetX = -0.78 },
        { len = 2.75, w = 0.42, offsetX = -0.26 },
        { len = 2.75, w = 0.42, offsetX =  0.26 },
        { len = 2.20, w = 0.36, offsetX =  0.78 },
    }
    for _, f in ipairs(fingers) do
        createFinger(model, bodies, CFrame.new(f.offsetX * s, fingerBaseY, 0), s * f.len, s * f.w, color)
    end
    createFinger(model, bodies, CFrame.new(s * 1.15, -s * 0.10, 0) * CFrame.Angles(0, 0, math.rad(-42)), s * 1.70, s * 0.46, color)
    return model, root, bodies
end

local function createMeshShape(meshId, textureId, size, name, color)
    local model, root = newModelShell(name)
    local mp = Instance.new("MeshPart")
    mp.Name = "Mesh"; mp.MeshId = meshId
    if textureId ~= "" then mp.TextureID = textureId end
    mp.Anchored = true; mp.CanCollide = false; mp.CastShadow = false
    mp.Material = Enum.Material.Neon
    mp.Color = color or Color3.fromRGB(235, 230, 215)
    mp.Size = Vector3.new(size * 3, size * 3, size * 3)
    mp.CFrame = CFrame.new(); mp.Parent = model
    return model, root, { mp }
end

local function isValidMesh(meshId)
    return type(meshId) == "string" and meshId:match("^rbxassetid://%d+$") ~= nil
end

local function createSword(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local gripColor = Color3.fromRGB(90, 60, 40)
    local function metalPart(nm, sz, cf, col, noRecolor)
        local p = newPart(model, nm, sz, cf, col, noRecolor)
        p.Material = Enum.Material.Metal
        table.insert(bodies, p); return p
    end
    metalPart("Blade", Vector3.new(s*0.16, s*2.9, s*0.09), CFrame.new(0, s*0.75, 0), color)
    metalPart("Fuller", Vector3.new(s*0.04, s*2.55, s*0.02), CFrame.new(0, s*0.75, s*0.045), Color3.fromRGB(150, 160, 175), true)
    local tip = Instance.new("WedgePart")
    tip.Name = "Tip"; tip.Size = Vector3.new(s*0.16, s*0.55, s*0.09)
    tip.CFrame = CFrame.new(0, s*2.475, 0) * CFrame.Angles(0, 0, math.rad(180))
    tip.Anchored = true; tip.CanCollide = false; tip.CastShadow = false
    tip.Material = Enum.Material.Metal; tip.Color = color; tip.Parent = model
    table.insert(bodies, tip)
    metalPart("Guard", Vector3.new(s*1.3, s*0.14, s*0.22), CFrame.new(0, -s*0.75, 0), color)
    local guardL = metalPart("GuardKnobL", Vector3.new(s*0.17, s*0.17, s*0.17), CFrame.new(-s*0.65, -s*0.75, 0), color)
    local gkl = Instance.new("SpecialMesh"); gkl.MeshType = Enum.MeshType.Sphere; gkl.Parent = guardL
    local guardR = metalPart("GuardKnobR", Vector3.new(s*0.17, s*0.17, s*0.17), CFrame.new(s*0.65, -s*0.75, 0), color)
    local gkr = Instance.new("SpecialMesh"); gkr.MeshType = Enum.MeshType.Sphere; gkr.Parent = guardR
    local grip = newPart(model, "Handle", Vector3.new(s*0.18, s*0.85, s*0.18), CFrame.new(0, -s*1.2, 0), gripColor, true)
    grip.Material = Enum.Material.Fabric
    table.insert(bodies, grip)
    for i = 1, 4 do
        local wrap = newPart(model, "Wrap", Vector3.new(s*0.20, s*0.03, s*0.20),
            CFrame.new(0, -s*(0.85 + i*0.16), 0), Color3.fromRGB(60, 40, 25), true)
        wrap.Material = Enum.Material.Fabric
        table.insert(bodies, wrap)
    end
    local pommel = metalPart("Pommel", Vector3.new(s*0.30, s*0.30, s*0.30), CFrame.new(0, -s*1.72, 0), color)
    local pm = Instance.new("SpecialMesh"); pm.MeshType = Enum.MeshType.Sphere; pm.Parent = pommel
    return model, root, bodies
end

local function createShield(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local rows, H, maxW, depth, roundFrac = 22, s*2.2, s*1.5, s*0.16, 0.24
    for r = 1, rows do
        local t = (r - 0.5) / rows
        local y = H * 0.5 - t * H
        local width
        if t < roundFrac then
            local k = 1 - (t / roundFrac)
            width = maxW * math.sqrt(math.max(0, 1 - k * k))
        else
            local k = (t - roundFrac) / (1 - roundFrac)
            width = maxW * (1 - k)
        end
        if width > s * 0.03 then
            local p = newPart(model, "Row", Vector3.new(width, (H / rows) * 1.08, depth), CFrame.new(0, y, 0), color)
            p.Material = Enum.Material.Metal
            table.insert(bodies, p)
        end
    end
    local goldAccent = Color3.fromRGB(230, 190, 70)
    local crossV = newPart(model, "CrossV", Vector3.new(s*0.14, H*0.72, depth*1.7), CFrame.new(0, s*0.05, -depth*0.45), goldAccent, true)
    crossV.Material = Enum.Material.Metal; table.insert(bodies, crossV)
    local crossH = newPart(model, "CrossH", Vector3.new(maxW*0.6, s*0.14, depth*1.7), CFrame.new(0, s*0.35, -depth*0.45), goldAccent, true)
    crossH.Material = Enum.Material.Metal; table.insert(bodies, crossH)
    local boss = newPart(model, "Boss", Vector3.new(s*0.36, s*0.36, s*0.28), CFrame.new(0, s*0.35, -depth*0.55), goldAccent, true)
    boss.Material = Enum.Material.Metal
    local bm = Instance.new("SpecialMesh"); bm.MeshType = Enum.MeshType.Sphere; bm.Parent = boss
    table.insert(bodies, boss)
    return model, root, bodies
end

local function createCrown(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local bandH, bandR = s*0.30, s*0.95
    local function metalMesh(nm, sz, cf, col, meshType, noRecolor)
        local p = newPart(model, nm, sz, cf, col, noRecolor)
        p.Material = Enum.Material.Metal
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = meshType; mesh.Parent = p
        table.insert(bodies, p); return p
    end
    metalMesh("Band", Vector3.new(bandH, bandR*2, bandR*2), CFrame.Angles(0, 0, math.rad(90)), color, Enum.MeshType.Cylinder)
    metalMesh("Rim", Vector3.new(bandH*0.4, bandR*2 + s*0.12, bandR*2 + s*0.12),
        CFrame.new(0, -bandH*0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.MeshType.Cylinder)
    local points = 6
    local bandTop = bandH * 0.5
    for i = 1, points do
        local angle = (i - 1) / points * math.pi * 2
        local x, z = math.cos(angle) * bandR * 0.82, math.sin(angle) * bandR * 0.82
        local main = (i % 2 == 1)
        local h, w = main and s*1.5 or s*0.85, main and s*0.34 or s*0.22
        metalMesh("Spike", Vector3.new(w, h, w), CFrame.new(x, bandTop + h*0.5, z), color, Enum.MeshType.Pyramid)
        if main then
            local gem = newPart(model, "Gem", Vector3.new(s*0.16, s*0.22, s*0.16),
                CFrame.new(x, bandTop + h*0.85, z), Color3.fromRGB(200, 30, 70), true)
            gem.Material = Enum.Material.Glass
            local gm = Instance.new("SpecialMesh"); gm.MeshType = Enum.MeshType.Pyramid; gm.Parent = gem
            table.insert(bodies, gem)
        end
    end
    local mainGem = newPart(model, "MainGem", Vector3.new(s*0.26, s*0.26, s*0.16),
        CFrame.new(0, 0, bandR), Color3.fromRGB(200, 30, 70), true)
    mainGem.Material = Enum.Material.Glass
    local mgm = Instance.new("SpecialMesh"); mgm.MeshType = Enum.MeshType.Sphere; mgm.Parent = mainGem
    table.insert(bodies, mainGem)
    return model, root, bodies
end

local function createBone(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    table.insert(bodies, newPart(model, "Shaft", Vector3.new(s*0.3, s*1.8, s*0.3), CFrame.new(0, 0, 0), color))
    for _, side in ipairs({-1, 1}) do
        local top = newPart(model, "Top", Vector3.new(s*0.5, s*0.4, s*0.5), CFrame.new(side*s*0.25, s*1.0, 0), color)
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = top
        table.insert(bodies, top)
        local bottom = newPart(model, "Bot", Vector3.new(s*0.5, s*0.4, s*0.5), CFrame.new(side*s*0.25, -s*1.0, 0), color)
        local m2 = Instance.new("SpecialMesh"); m2.MeshType = Enum.MeshType.Sphere; m2.Parent = bottom
        table.insert(bodies, bottom)
    end
    return model, root, bodies
end

local function createCrystal(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local function gem(nm, cx, cy, cz, w, hTop, hBot, col, transp, cf)
        cf = cf or CFrame.new()
        local top = newPart(model, nm .. "Top", Vector3.new(w, hTop, w), cf * CFrame.new(cx, cy + hTop * 0.5, cz), col)
        top.Material = Enum.Material.Glass; top.Transparency = transp
        local tm = Instance.new("SpecialMesh"); tm.MeshType = Enum.MeshType.Pyramid; tm.Parent = top
        table.insert(bodies, top)
        local bot = newPart(model, nm .. "Bot", Vector3.new(w, hBot, w),
            cf * CFrame.new(cx, cy - hBot * 0.5, cz) * CFrame.Angles(math.rad(180), 0, 0), col)
        bot.Material = Enum.Material.Glass; bot.Transparency = transp
        local bm = Instance.new("SpecialMesh"); bm.MeshType = Enum.MeshType.Pyramid; bm.Parent = bot
        table.insert(bodies, bot)
    end
    gem("Main", 0, 0, 0, s*0.9, s*1.5, s*0.9, color, 0.05)
    for i = 1, 5 do
        local angle = (i - 1) / 5 * math.pi * 2 + 0.4
        local dist = s * 0.68
        local x, z = math.cos(angle) * dist, math.sin(angle) * dist
        local w = s * (0.34 + (i % 3) * 0.08)
        local tilt = CFrame.Angles(math.rad(20) * math.cos(angle), 0, math.rad(20) * math.sin(angle))
        gem("Sat" .. i, x, -s*0.55, z, w, w*1.6, w*0.9, color, 0.08, tilt)
    end
    return model, root, bodies
end

local function createPyramid(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local tiers, totalH, baseW = 5, s*1.8, s*1.7
    local tierH = totalH / tiers
    for i = 1, tiers do
        local t = (i - 1) / tiers
        local w = baseW * (1 - t)
        local y = -totalH * 0.5 + (i - 0.5) * tierH
        local block = newPart(model, "Tier", Vector3.new(w, tierH*0.96, w), CFrame.new(0, y, 0), color)
        block.Material = Enum.Material.Sand
        table.insert(bodies, block)
    end
    local capH = tierH * 0.9
    local cap = newPart(model, "Capstone", Vector3.new(s*0.22, capH, s*0.22),
        CFrame.new(0, totalH*0.5 + capH*0.5, 0), Color3.fromRGB(255, 220, 120), true)
    cap.Material = Enum.Material.Metal
    local cm = Instance.new("SpecialMesh"); cm.MeshType = Enum.MeshType.Pyramid; cm.Parent = cap
    table.insert(bodies, cap)
    return model, root, bodies
end

local function createYinYang(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local R = s * 0.95
    local depth = s * 0.22
    local whiteColor = Color3.fromRGB(245, 245, 250)
    local blackColor = Color3.fromRGB(20, 20, 25)
    local rows = 34
    local pixel = (R * 2) / rows
    local function classify(x, y)
        local dist = math.sqrt(x*x + y*y)
        if dist > R then return nil end
        local halfR = R * 0.5
        if y >= 0 then
            local dUp = math.sqrt(x*x + (y - halfR)^2)
            if dUp <= halfR then return "black" else return "white" end
        else
            local dDown = math.sqrt(x*x + (y + halfR)^2)
            if dDown <= halfR then return "white" else return "black" end
        end
    end
    for r = 1, rows do
        local y = ((rows + 1) / 2 - r) * pixel
        local c = 1
        while c <= rows do
            local x = (c - (rows + 1) / 2) * pixel
            local col = classify(x, y)
            if col then
                local sc = c
                while c <= rows do
                    local x2 = (c - (rows + 1) / 2) * pixel
                    if classify(x2, y) ~= col then break end
                    c = c + 1
                end
                local ec = c - 1
                local width = (ec - sc + 1) * pixel
                local cc = (sc + ec) / 2
                local px = (cc - (rows + 1) / 2) * pixel
                local partColor = (col == "white") and whiteColor or blackColor
                local p = newPart(model, col, Vector3.new(width, pixel, depth), CFrame.new(px, y, 0), partColor, true)
                p.Material = Enum.Material.SmoothPlastic
                table.insert(bodies, p)
            else c = c + 1 end
        end
    end
    return model, root, bodies
end

local function createEye(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local sclera = newPart(model, "Sclera", Vector3.new(s*1.5, s*1.0, s*0.7), CFrame.new(0, 0, 0), Color3.fromRGB(250, 248, 245), true)
    sclera.Material = Enum.Material.SmoothPlastic
    local scMesh = Instance.new("SpecialMesh"); scMesh.MeshType = Enum.MeshType.Sphere; scMesh.Parent = sclera
    table.insert(bodies, sclera)
    local iris = newPart(model, "Iris", Vector3.new(s*0.62, s*0.62, s*0.18),
        CFrame.new(0, 0, s*0.32) * CFrame.Angles(math.rad(90), 0, 0), color)
    iris.Material = Enum.Material.SmoothPlastic
    local irMesh = Instance.new("SpecialMesh"); irMesh.MeshType = Enum.MeshType.Cylinder; irMesh.Parent = iris
    table.insert(bodies, iris)
    local pupil = newPart(model, "Pupil", Vector3.new(s*0.28, s*0.28, s*0.11),
        CFrame.new(0, 0, s*0.40) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(10, 10, 12), true)
    pupil.Material = Enum.Material.SmoothPlastic
    local puMesh = Instance.new("SpecialMesh"); puMesh.MeshType = Enum.MeshType.Cylinder; puMesh.Parent = pupil
    table.insert(bodies, pupil)
    local glint = newPart(model, "Glint", Vector3.new(s*0.10, s*0.10, s*0.06),
        CFrame.new(s*0.14, s*0.14, s*0.46), Color3.fromRGB(255, 255, 255), true)
    glint.Material = Enum.Material.Neon
    local glMesh = Instance.new("SpecialMesh"); glMesh.MeshType = Enum.MeshType.Sphere; glMesh.Parent = glint
    table.insert(bodies, glint)
    for _, sign in ipairs({1, -1}) do
        local lid = newPart(model, "Lid", Vector3.new(s*1.65, s*0.18, s*0.55),
            CFrame.new(0, sign*s*0.5, s*0.05), Color3.fromRGB(225, 205, 185), true)
        lid.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, lid)
    end
    return model, root, bodies
end

local function createRune(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local plate = newPart(model, "Plate", Vector3.new(s*0.5, s*1.9, s*1.9),
        CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 68, 66), true)
    plate.Material = Enum.Material.Slate
    local pm = Instance.new("SpecialMesh"); pm.MeshType = Enum.MeshType.Cylinder; pm.Parent = plate
    table.insert(bodies, plate)
    local t, d = s*0.09, s*0.16
    local top, mid, bottom = Vector3.new(0, s*0.78, s*0.1), Vector3.new(0, -s*0.1, s*0.1), Vector3.new(0, -s*0.78, s*0.1)
    local armL, armR = Vector3.new(-s*0.55, s*0.42, s*0.1), Vector3.new(s*0.55, s*0.42, s*0.1)
    for _, seg in ipairs({ { mid, bottom }, { mid, top }, { mid, armL }, { mid, armR } }) do
        table.insert(bodies, makeRod(model, seg[1], seg[2], t, d, color))
    end
    return model, root, bodies
end

local function createSpiral(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local turns, segments = 3, 48
    local radius, height, thickness = s*0.55, s*2.0, s*0.10
    local function point(i)
        local t = i / segments
        local angle = t * math.pi * 2 * turns
        return Vector3.new(math.cos(angle)*radius, -height*0.5 + t*height, math.sin(angle)*radius)
    end
    local prev = point(0)
    for i = 1, segments do
        local cur = point(i)
        table.insert(bodies, makeRod(model, prev, cur, thickness, thickness, color))
        prev = cur
    end
    return model, root, bodies
end

local function createWings(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local function feather(cx, cy, side, len, w, spreadDeg, droopDeg)
        local cf = CFrame.new(cx, cy, 0)
            * CFrame.Angles(0, math.rad(side * spreadDeg), 0)
            * CFrame.Angles(math.rad(-droopDeg), 0, 0)
            * CFrame.new(0, 0, -len * 0.5)
        local f = Instance.new("WedgePart")
        f.Name = "Feather"; f.Size = Vector3.new(w, s*0.06, len); f.CFrame = cf
        f.Anchored = true; f.CanCollide = false; f.CastShadow = false
        f.Material = Enum.Material.SmoothPlastic; f.Color = color; f.Parent = model
        table.insert(bodies, f)
    end
    for _, side in ipairs({-1, 1}) do
        local boneSegments = 5
        local prevPos = Vector3.new(side*s*0.15, 0, 0)
        for seg = 1, boneSegments do
            local t = seg / boneSegments
            local arcAngle = t * math.rad(75)
            local bx = side * (s*0.15 + math.sin(arcAngle) * s*1.5)
            local by = math.cos(arcAngle) * s*0.4 + t*s*0.3
            local pos = Vector3.new(bx, by, 0)
            local rod = makeRod(model, prevPos, pos, s*0.16, s*0.12, color)
            rod.Material = Enum.Material.SmoothPlastic
            table.insert(bodies, rod)
            prevPos = pos
        end
        for i = 1, 8 do
            local t = (i - 1) / 7
            local arcAngle = t * math.rad(75)
            local bx = side * (s*0.15 + math.sin(arcAngle) * s*1.5)
            local by = math.cos(arcAngle) * s*0.4 + t*s*0.3
            feather(bx, by, side, s*(2.0 - t*1.2), s*(0.30 - t*0.13), 22 + t*48, t*22)
        end
        for i = 1, 6 do
            local t = (i - 1) / 5
            local arcAngle = 0.15 + t * math.rad(45)
            local bx = side * (s*0.15 + math.sin(arcAngle) * s*0.9)
            local by = (math.cos(arcAngle) * s*0.25 + t*s*0.15) * 0.4 + s*0.15
            feather(bx, by, side, s*0.75, s*0.22, 10 + t*20, t*10)
        end
    end
    return model, root, bodies
end

local function createTentacle(size, color, name)
    local model, root = newModelShell(name)
    local bodies = {}
    local s = size
    local segments = 10
    local function point(i)
        local t = i / segments
        local curl = t * t * math.rad(200)
        local x = math.sin(curl) * s * 0.9 * t
        local z = (1 - math.cos(curl)) * s * 0.5 * t
        local y = -s * 0.9 + t * s * 1.8
        return Vector3.new(x, y, z), t
    end
    local prevPos = point(0)
    for i = 1, segments do
        local pos, t = point(i)
        local thickness = s * 0.42 * (1 - t * 0.75) + s * 0.05
        local seg = newPart(model, "Seg", Vector3.new(thickness, thickness, thickness), CFrame.new(pos), color)
        seg.Material = Enum.Material.SmoothPlastic
        local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = seg
        table.insert(bodies, seg)
        if i % 2 == 0 and t < 0.85 then
            local sucker = newPart(model, "Sucker", Vector3.new(thickness*0.55, thickness*0.55, thickness*0.2),
                CFrame.new(pos) * CFrame.new(0, 0, thickness*0.4), Color3.fromRGB(255, 200, 210), true)
            sucker.Material = Enum.Material.SmoothPlastic
            local suM = Instance.new("SpecialMesh"); suM.MeshType = Enum.MeshType.Cylinder; suM.Parent = sucker
            table.insert(bodies, sucker)
        end
        if i > 1 then
            local rod = makeRod(model, prevPos, pos, thickness*0.85, thickness*0.85, color)
            rod.Material = Enum.Material.SmoothPlastic
            table.insert(bodies, rod)
        end
        prevPos = pos
    end
    return model, root, bodies
end

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
        table.insert(bodies, p); return p
    end
    local function ellipsoid(sz, cf, col, noRecolor)
        local p = block(sz, cf, col, noRecolor)
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
        return p
    end
    local function wedge(sz, cf, col, noRecolor)
        local w = Instance.new("WedgePart")
        w.Name = "W"; w.Size = sz; w.CFrame = cf
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
        w.Material = Enum.Material.SmoothPlastic; w.Color = col
        if noRecolor then w:SetAttribute("NoRecolor", true) end
        w.Parent = model; table.insert(bodies, w); return w
    end
    local function tooth(cf, w, h, col)
        local p = newPart(model, "Tooth", Vector3.new(w, h, w), cf, col, true)
        p.Material = Enum.Material.SmoothPlastic
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Pyramid; m.Parent = p
        table.insert(bodies, p); return p
    end
    local function addLight(part, col, range, bright)
        if SETTINGS.LightEnabled and activeLightCount < SETTINGS.LightLimit then
            local light = Instance.new("PointLight")
            light.Range = range * s; light.Brightness = bright; light.Color = col
            light.Parent = part; activeLightCount = activeLightCount + 1
        end
    end
    ellipsoid(Vector3.new(1.45*s, 1.00*s, 1.35*s), CFrame.new(0, 0.28*s, 1.00*s), bone)
    ellipsoid(Vector3.new(1.30*s, 0.88*s, 1.20*s), CFrame.new(0, 0.24*s, 0.15*s), bone)
    ellipsoid(Vector3.new(1.00*s, 0.68*s, 1.10*s), CFrame.new(0, 0.18*s, -0.75*s), bone)
    ellipsoid(Vector3.new(0.62*s, 0.46*s, 0.85*s), CFrame.new(0, 0.12*s, -1.55*s), bone)
    for _, side in ipairs({-1, 1}) do
        ellipsoid(Vector3.new(0.42*s, 0.16*s, 0.55*s),
            CFrame.new(side*0.40*s, 0.52*s, -0.35*s) * CFrame.Angles(math.rad(-8), 0, math.rad(side*6)), bone)
    end
    for _, side in ipairs({-1, 1}) do
        ellipsoid(Vector3.new(0.10*s, 0.10*s, 0.14*s), CFrame.new(side*0.18*s, 0.06*s, -1.92*s), dark, true)
    end
    ellipsoid(Vector3.new(1.10*s, 0.42*s, 1.35*s), CFrame.new(0, -0.40*s, 0.55*s), bone)
    ellipsoid(Vector3.new(0.72*s, 0.30*s, 1.00*s), CFrame.new(0, -0.30*s, -0.55*s), bone)
    ellipsoid(Vector3.new(0.42*s, 0.20*s, 0.60*s), CFrame.new(0, -0.24*s, -1.30*s), bone)
    block(Vector3.new(0.68*s, 0.34*s, 1.55*s), CFrame.new(0, -0.05*s, -0.50*s), dark, true)
    local core = ellipsoid(Vector3.new(0.22*s, 0.22*s, 0.22*s), CFrame.new(0, -0.05*s, -0.85*s), bone)
    addLight(core, bone, 8, 4)
    for _, side in ipairs({-1, 1}) do
        tooth(CFrame.new(side*0.42*s, -0.02*s, -0.35*s) * CFrame.Angles(math.rad(180), 0, 0), 0.16*s, 0.30*s, toothColor)
        tooth(CFrame.new(side*0.38*s, -0.10*s, -0.30*s), 0.14*s, 0.24*s, toothColor)
    end
    for i = 1, 4 do
        local z = -1.10*s + (i - 1) * 0.20*s
        tooth(CFrame.new((i % 2 == 0 and 0.24 or -0.24)*s, -0.06*s, z) * CFrame.Angles(math.rad(180), 0, 0), 0.12*s, 0.16*s, toothColor)
    end
    for i = 1, 3 do
        local z = -0.95*s + (i - 1) * 0.20*s
        tooth(CFrame.new((i % 2 == 0 and -0.20 or 0.20)*s, -0.12*s, z), 0.11*s, 0.14*s, toothColor)
    end
    for _, side in ipairs({-1, 1}) do
        ellipsoid(Vector3.new(0.38*s, 0.34*s, 0.30*s), CFrame.new(side*0.46*s, 0.32*s, -0.42*s), dark, true)
        local eye = ellipsoid(Vector3.new(0.15*s, 0.15*s, 0.10*s), CFrame.new(side*0.46*s, 0.32*s, -0.52*s), bone)
        addLight(eye, bone, 6, 3)
    end
    for i = 1, 3 do
        local z = 1.35*s - (i - 1) * 0.35*s
        local h = 0.70*s - (i - 1) * 0.16*s
        wedge(Vector3.new(0.18*s, h, 0.30*s),
            CFrame.new(0, 0.55*s + h*0.35, z) * CFrame.Angles(math.rad(-18), math.rad(90), 0), bone)
    end
    for _, side in ipairs({-1, 1}) do
        wedge(Vector3.new(0.12*s, 0.65*s, 0.55*s),
            CFrame.new(side*0.78*s, 0.42*s, 0.85*s) * CFrame.Angles(math.rad(-10), 0, math.rad(side * -55)), bone)
        wedge(Vector3.new(0.10*s, 0.42*s, 0.38*s),
            CFrame.new(side*0.95*s, 0.62*s, 0.65*s) * CFrame.Angles(math.rad(-10), 0, math.rad(side * -75)), bone)
    end
    return model, root, bodies
end

-- ==================== СПИСОК ФИГУР ====================
local SHAPE_PRESETS = {
    { name = "БЛОК", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Block; p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    { name = "ШАР", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    { name = "ЦИЛИНДР", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Cylinder; p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    { name = "КЛИН", create = function(size, name)
        local p = Instance.new("WedgePart"); p.Name = name; p.Size = Vector3.new(size, size, size)
        return { part = p }
    end },
    { name = "ГОЛОВА", create = function(size, name)
        local m, r, b = createHead(size, Color3.fromRGB(255, 220, 60), name)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = size }
    end },
    { name = "СЕРДЦЕ", create = function(size, name)
        local hs = size * 1.8
        local m, r, b = createPixelHeart(hs, Color3.fromRGB(255, 60, 120), name)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = hs }
    end },
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
    { name = "РУКА", create = function(s, n)
        local m, r, b = create3DHand(s, Color3.fromRGB(235, 230, 215), n, false)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.2 }
    end },
    { name = "РУКА-СЕРДЦЕ", create = function(s, n, idx)
        local hc = HEART_COLORS[((idx or 1) - 1) % #HEART_COLORS + 1]
        local m, r, b = create3DHand(s, Color3.fromRGB(235, 230, 215), n, true, hc)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 3.2 }
    end },
    { name = "ГАСТЕР БЛАСТЕР", create = function(s, n)
        local m, r, b = create3DBlasterPlaceholder(s, Color3.fromRGB(240, 240, 245), n)
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 2.6 }
    end },
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

-- ==================== УТИЛИТЫ (без local — forward declared выше) ====================
function getCurrentShapeSize() return SETTINGS.BaseShapeSize * SHAPE_SIZE_PRESETS[shapeSizeIndex].factor end
function getTargetRadius(ri) return ORBIT_PRESETS[orbitIndex].radius + rings[ri].radiusOffset * RING_STEP * SPREAD_PRESETS[spreadIndex].mult end
function getHeightOffset() return HEIGHT_PRESETS[heightIndex].offset end
function getTargetHeight(ri) return ORBIT_PRESETS[orbitIndex].height + rings[ri].heightOffset * SPREAD_PRESETS[spreadIndex].mult + getHeightOffset() end
function getTargetSpeed() return SETTINGS.OrbitSpeed * SETTINGS.SpeedMultiplier end
function getTargetSpin() return SETTINGS.SpinSpeed * SETTINGS.SpeedMultiplier * SETTINGS.SpinSpeedMultiplier end

-- ==================== АУРА ====================
local function getAuraColor(i, total)
    local p = COLOR_PRESETS[auraColorIndex]
    if p.rainbow then
        local t = tick() - startTime
        local hue = (t * 0.2 + i / math.max(total, 1)) % 1
        return Color3.fromHSV(hue, 0.9, 1)
    end
    return p.color or SETTINGS.AuraColor
end

local function setupAura()
    if auraFolder then auraFolder:Destroy(); auraFolder = nil end
    auraParts = {}
    auraBlocks = {}
    if not SETTINGS.AuraEnabled then return end

    auraFolder = Instance.new("Folder")
    auraFolder.Name = "OrbitAura_" .. tostring(math.random(1, 999999))
    auraFolder.Parent = Workspace

    local t = SETTINGS.AuraType
    local needRing = (t == "Кольцо" or t == "Оба" or t == "Всё")
    local needParticles = (t == "Частицы" or t == "Оба" or t == "Всё")
    local needShapes = (t == "Фигуры" or t == "Всё")

    if needRing then
        local ring = Instance.new("Part")
        ring.Name = "AuraRing"; ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(SETTINGS.AuraThickness, SETTINGS.AuraSize*2, SETTINGS.AuraSize*2)
        ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
        ring.Material = Enum.Material.Neon
        ring.Color = getAuraColor(1, 1)
        ring.Transparency = 0.3
        ring.Parent = auraFolder
        table.insert(auraParts, ring)
    end

    if needParticles then
        local emitter = Instance.new("Part")
        emitter.Name = "AuraEmitter"
        emitter.Size = Vector3.new(0.1, 0.1, 0.1); emitter.Transparency = 1
        emitter.Anchored = true; emitter.CanCollide = false; emitter.CastShadow = false
        emitter.Parent = auraFolder
        local col = getAuraColor(1, 1)

        local p1 = Instance.new("ParticleEmitter")
        p1.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        p1.Rate = 150; p1.Lifetime = NumberRange.new(1.0, 2.0)
        p1.Speed = NumberRange.new(3, 6); p1.SpreadAngle = Vector2.new(180, 180)
        p1.RotSpeed = NumberRange.new(-180, 180)
        p1.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 0.2)
        })
        p1.Color = ColorSequence.new(col)
        p1.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)
        })
        p1.Parent = emitter

        local p2 = Instance.new("ParticleEmitter")
        p2.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        p2.Rate = 100; p2.Lifetime = NumberRange.new(0.6, 1.2)
        p2.Speed = NumberRange.new(5, 9); p2.SpreadAngle = Vector2.new(20, 20)
        p2.Size = NumberSequence.new(0.5)
        p2.Color = ColorSequence.new(col)
        p2.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)
        })
        p2.Parent = emitter

        local p3 = Instance.new("ParticleEmitter")
        p3.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        p3.Rate = 80; p3.Lifetime = NumberRange.new(1.2, 2.5)
        p3.Speed = NumberRange.new(1, 3); p3.SpreadAngle = Vector2.new(180, 180)
        p3.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.3)
        })
        p3.Color = ColorSequence.new(col)
        p3.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)
        })
        p3.Parent = emitter

        table.insert(auraParts, emitter)
    end

    if needShapes then
        local folder = Instance.new("Folder")
        folder.Name = "AuraShapes"
        folder.Parent = auraFolder
        local shape = SHAPE_PRESETS[auraShapeIndex] or SHAPE_PRESETS[1]
        local size = getCurrentShapeSize() * 0.6
        local count = math.max(4, math.floor(SETTINGS.BlockCount * 0.75))
        for i = 1, count do
            local data = shape.create(size, "Aura_" .. i)
            local refPart = data.part
            if not data.isModel then
                refPart.Material = SETTINGS.Material
                refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
                refPart.Transparency = SETTINGS.Transparency
                refPart.Color = getAuraColor(i, count)
            end
            if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
            table.insert(auraBlocks, {
                part = refPart, model = data.model, isModel = data.isModel or false,
                bodyParts = data.bodyParts, index = i, total = count,
            })
        end
    end
end

local function updateAura(dt)
    if not auraFolder then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local t = SETTINGS.AuraType
    local needShapes = (t == "Фигуры" or t == "Всё")
    local baseCol = getAuraColor(1, 1)

    for _, part in ipairs(auraParts) do
        if part.Name == "AuraRing" then
            part.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
            if COLOR_PRESETS[auraColorIndex].rainbow then
                part.Color = baseCol
            else
                part.Color = COLOR_PRESETS[auraColorIndex].color or SETTINGS.AuraColor
            end
        elseif part.Name == "AuraEmitter" then
            part.CFrame = hrp.CFrame
            if COLOR_PRESETS[auraColorIndex].rainbow then
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("ParticleEmitter") then
                        child.Color = ColorSequence.new(baseCol)
                    end
                end
            end
        end
    end

    if needShapes and #auraBlocks > 0 then
        local auraSpeed = SETTINGS.OrbitSpeed * SETTINGS.SpeedMultiplier * 0.7
        auraAngle = auraAngle + auraSpeed * dt
        local radius = SETTINGS.AuraSize
        local height = 0.5
        for _, data in ipairs(auraBlocks) do
            if not data.part.Parent then continue end
            local angle = math.rad(auraAngle + (data.index - 1) * (360 / data.total))
            local px = math.cos(angle) * radius
            local pz = math.sin(angle) * radius
            local pos = hrp.Position + Vector3.new(px, height, pz)
            local cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi / 2, 0)
            if data.isModel and data.model then
                data.model:PivotTo(cf)
            else
                data.part.CFrame = cf
            end
            local col = getAuraColor(data.index, data.total)
            if data.bodyParts then
                for _, p in ipairs(data.bodyParts) do
                    if not p:GetAttribute("NoRecolor") then p.Color = col end
                end
            elseif data.part then
                data.part.Color = col
            end
        end
    end
end

-- ==================== КОЛЬЦА НА ДРУГИХ ИГРОКАХ ====================
local function buildTargetRings(player)
    if targetRings[player] then
        pcall(function() targetRings[player].folder:Destroy() end)
        targetRings[player] = nil
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local folder = Instance.new("Folder")
    folder.Name = "TargetRing_" .. tostring(math.random(1, 999999))
    folder.Parent = Workspace

    local shape = SHAPE_PRESETS[shapeIndex] or SHAPE_PRESETS[1]
    local size = getCurrentShapeSize()
    local blocks = {}

    for i = 1, SETTINGS.BlockCount do
        local data = shape.create(size, "T_" .. i, i)
        local refPart = data.part
        if not data.isModel then
            refPart.Material = SETTINGS.Material
            refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
            refPart.Transparency = SETTINGS.Transparency
            refPart.Color = SETTINGS.FixedColor
        end
        if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
        table.insert(blocks, {
            part = refPart, model = data.model, isModel = data.isModel or false,
            bodyParts = data.bodyParts,
            angleOffset = (i - 1) * (360 / SETTINGS.BlockCount),
            index = i,
        })
    end
    targetRings[player] = { folder = folder, blocks = blocks, angle = 0 }
end

local function removeTargetRings(player)
    if targetRings[player] then
        pcall(function() targetRings[player].folder:Destroy() end)
        targetRings[player] = nil
    end
end

local function updateTargetRings(dt)
    local t = tick() - startTime
    local baseCol = SETTINGS.FixedColor
    if COLOR_PRESETS[colorIndex] and not COLOR_PRESETS[colorIndex].rainbow then
        baseCol = COLOR_PRESETS[colorIndex].color or baseCol
    end

    for player, data in pairs(targetRings) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        data.angle = data.angle + getTargetSpeed() * dt
        local radius = getTargetRadius(1)
        local height = getTargetHeight(1)
        local spinAngle = 0
        if spinAxisEnabled and not spinResetting then spinAngle = t * 3 end

        for _, b in ipairs(data.blocks) do
            local ref = b.isModel and b.model or b.part
            if not ref or not ref.Parent then continue end
            local angle = math.rad(data.angle + b.angleOffset)
            local px = math.cos(angle) * radius
            local pz = math.sin(angle) * radius
            local targetCF
            if spinAxisDir == "X" then
                targetCF = CFrame.new(hrp.Position + Vector3.new(px, height, pz))
                    * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle) * 0.7, 0)
            else
                targetCF = CFrame.new(hrp.Position + Vector3.new(px, height, pz))
                    * CFrame.Angles(0, math.rad(spinAngle), 0)
            end
            if b.isModel and b.model then
                b.model:PivotTo(targetCF)
            else
                b.part.CFrame = targetCF
            end
            local col = baseCol
            if SETTINGS.Rainbow then
                local hue = (t * 0.15 * SETTINGS.SpeedMultiplier + b.index / SETTINGS.BlockCount) % 1
                col = Color3.fromHSV(hue, 0.9, 1)
            end
            if b.bodyParts then
                for _, p in ipairs(b.bodyParts) do
                    if not p:GetAttribute("NoRecolor") then p.Color = col end
                end
            elseif b.part then
                b.part.Color = col
            end
        end
    end
end

local function cleanupAllTargetRings()
    for player in pairs(targetRings) do removeTargetRings(player) end
    for _, btn in pairs(peopleButtons) do pcall(function() btn:Destroy() end) end
    peopleButtons = {}
end

local function toggleTargetRings(player)
    if targetRings[player] then
        removeTargetRings(player)
        local btn = peopleButtons[player]
        if btn then
            btn.Text = "🔷 " .. player.Name
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            btn.TextColor3 = Color3.fromRGB(220, 220, 255)
        end
        notify("➖ Убрано у " .. player.Name, Color3.fromRGB(255, 150, 150))
    else
        buildTargetRings(player)
        local btn = peopleButtons[player]
        if btn then
            btn.Text = "✅ " .. player.Name
            btn.BackgroundColor3 = Color3.fromRGB(80, 40, 100)
            btn.TextColor3 = Color3.fromRGB(255, 200, 255)
        end
        notify("➕ Кольцо у " .. player.Name, Color3.fromRGB(200, 150, 255))
    end
end

local function rebuildAllTargetRings()
    local targets = {}
    for p in pairs(targetRings) do table.insert(targets, p) end
    for _, p in ipairs(targets) do
        removeTargetRings(p)
        buildTargetRings(p)
    end
end

-- ==================== ОРБИТАЛЬНЫЕ УЗОРЫ ====================
local function applyOrbitPattern(ri, baseAngle, baseRadius, baseHeight)
    local pattern = SETTINGS.OrbitPattern
    local t = baseAngle
    if pattern == "Круг" then
        return math.cos(t) * baseRadius, baseHeight, math.sin(t) * baseRadius
    elseif pattern == "Спираль" then
        local sf = (math.sin(t * 0.3) + 1) * 0.5
        local r = baseRadius * (0.4 + 0.6 * sf)
        local h = baseHeight + math.sin(t * 0.5) * 3
        return math.cos(t) * r, h, math.sin(t) * r
    elseif pattern == "Волна" then
        local h = baseHeight + math.sin(t * 2) * 4
        return math.cos(t) * baseRadius, h, math.sin(t) * baseRadius
    elseif pattern == "Восьмёрка" then
        return math.sin(t) * baseRadius, baseHeight, math.sin(t * 2) * baseRadius * 0.5
    elseif pattern == "Зигзаг" then
        local seg = math.floor(t / (math.pi / 3))
        local dir = (seg % 2 == 0) and 1 or -1
        return math.cos(t) * baseRadius, baseHeight + dir * 2, math.sin(t) * baseRadius
    elseif pattern == "Лиссажу" then
        return math.sin(3 * t) * baseRadius, baseHeight, math.sin(2 * t + math.pi/2) * baseRadius
    elseif pattern == "Хаос" then
        local r = baseRadius * (0.7 + math.sin(t * 7.3 + ri) * 0.3)
        local h = baseHeight + math.sin(t * 5.1 + ri * 2) * 3
        return math.cos(t) * r, h, math.sin(t) * r
    end
    return math.cos(t) * baseRadius, baseHeight, math.sin(t) * baseRadius
end

-- ==================== ДОП. УТИЛИТЫ ====================
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
        for ri = 1, 5 do rings[ri].shapeIndex = ((shapeIndex + ri - 2) % #SHAPE_PRESETS) + 1 end
    end
end

local function buildRing(ri)
    local ring = rings[ri]
    if not ring then return end
    if ring.folder then ring.folder:Destroy(); ring.folder = nil end
    ring.blocks = {}
    local folder = Instance.new("Folder")
    folder.Name = "OrbitRing_" .. ri .. "_" .. tostring(math.random(1, 999999))
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
            refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
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
                NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1),
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

        statsData.fpsFrames = statsData.fpsFrames + 1
        if t - statsData.fpsLastCheck >= 1 then
            statsData.lastFPS = math.floor(statsData.fpsFrames / (t - statsData.fpsLastCheck))
            statsData.fpsFrames = 0
            statsData.fpsLastCheck = t
        end
        statsData.sessionTime = t

        updateAura(dt)
        updateTargetRings(dt)

        if SETTINGS.AutoShapeSwap and (tick() - lastAutoSwap) > SETTINGS.AutoShapeSwapInterval then
            lastAutoSwap = tick()
            currentAutoShapeIndex = currentAutoShapeIndex + 1
            if currentAutoShapeIndex > #SHAPE_PRESETS then currentAutoShapeIndex = 1 end
            shapeIndex = currentAutoShapeIndex
            applyShapes()
            rebuildAllRings()
            rebuildAllTargetRings()
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
                local backLerp = math.clamp(dt * 3.0, 0, 1)
                currentSpinAngle[ri] = currentSpinAngle[ri] + (0 - currentSpinAngle[ri]) * backLerp
                if math.abs(currentSpinAngle[ri]) < 0.01 then currentSpinAngle[ri] = 0 end
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
                local px, py, pz = applyOrbitPattern(ri, angle, radius, height + yBob)
                local offset = Vector3.new(px, py, pz)
                local targetCF
                if spinAxisDir == "X" then
                    targetCF = CFrame.new(root.Position + offset) * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle) * 0.7, 0)
                else
                    targetCF = CFrame.new(root.Position + offset) * CFrame.Angles(0, math.rad(spinAngle), 0)
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
                    applyColorToBlock(data, Color3.fromHSV(hue, 0.85, 1))
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
        cleanupAllTargetRings()
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

-- ==================== СОХРАНЕНИЕ ====================
local SAVED_DATA = nil

local function encodeData(data)
    local function enc(v)
        if type(v) == "table" then
            local out = {}
            for k, val in pairs(v) do out[k] = enc(val) end
            return out
        elseif typeof(v) == "Color3" then
            return { __t = "c3", R = v.R, G = v.G, B = v.B }
        elseif typeof(v) == "Vector3" then
            return { __t = "v3", X = v.X, Y = v.Y, Z = v.Z }
        else
            return v
        end
    end
    return enc(data)
end

local function decodeData(data)
    local function dec(v)
        if type(v) == "table" then
            if v.__t == "c3" then return Color3.new(v.R, v.G, v.B) end
            if v.__t == "v3" then return Vector3.new(v.X, v.Y, v.Z) end
            local out = {}
            for k, val in pairs(v) do out[k] = dec(val) end
            return out
        end
        return v
    end
    return dec(data)
end

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
        auraColorIndex = auraColorIndex, auraShapeIndex = auraShapeIndex,
        ringShapes = ringShapes, ringEnabled = ringEnabled,
        lightEnabled = SETTINGS.LightEnabled, trailEnabled = SETTINGS.TrailEnabled,
        pulseEnabled = SETTINGS.PulseEnabled, showNames = SETTINGS.ShowBlockNames,
        waveEnabled = SETTINGS.WaveEnabled, explosionEnabled = SETTINGS.ExplosionEnabled,
        auraEnabled = SETTINGS.AuraEnabled, auraSize = SETTINGS.AuraSize,
        autoShapeSwap = SETTINGS.AutoShapeSwap,
        autoShapeSwapInterval = SETTINGS.AutoShapeSwapInterval,
        gradientEnabled = SETTINGS.GradientEnabled,
        spinResetting = spinResetting, spinAxisEnabled = spinAxisEnabled, spinAxisDir = spinAxisDir,
        spinSpeedIndex = spinSpeedIndex, heartScale = SETTINGS.HeartScale,
        musicEnabled = musicEnabled, musicId = savedMusicId, musicVolume = musicVolume,
    }
end

local function saveSettings()
    SAVED_DATA = collectSaveData()
    if HAS_FS then
        pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(encodeData(SAVED_DATA))) end)
    end
    return true
end

local function loadSettings()
    if not SAVED_DATA and HAS_FS then
        pcall(function()
            if isfile(SAVE_FILE) then
                local txt = readfile(SAVE_FILE)
                if txt and #txt > 0 then
                    SAVED_DATA = decodeData(HttpService:JSONDecode(txt))
                end
            end
        end)
    end
    if not SAVED_DATA then return false end
    local data = SAVED_DATA
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
    if data.auraColorIndex then auraColorIndex = data.auraColorIndex end
    if data.auraShapeIndex then auraShapeIndex = data.auraShapeIndex end
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
    if COLOR_PRESETS[auraColorIndex] and COLOR_PRESETS[auraColorIndex].color then
        SETTINGS.AuraColor = COLOR_PRESETS[auraColorIndex].color
    end
    return true
end

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "_" .. tostring(math.random(100000, 999999))
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

protectGui(screenGui)
local okParent = pcall(function() screenGui.Parent = getSafeParent() end)
if not okParent or not screenGui.Parent then screenGui.Parent = PlayerGui end

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
panel.CanvasSize = UDim2.new(0, 0, 0, 2450)
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
title.Text = "✨ ОРБИТА v15.3 DELTA"
title.TextColor3 = Color3.fromRGB(200, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.Parent = panel

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

makeSection("⚡ ОСНОВНОЕ", 36, Color3.fromRGB(60, 60, 100))
local toggleBtn     = makeButton("🟢 ВКЛЮЧЕНО", 60, 30, Color3.fromRGB(40, 40, 55), Color3.fromRGB(0, 255, 120))
local allRingsBtn   = makeButton("⭕ Все кольца: ВКЛ", 93, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring2Btn      = makeButton("➕ Кольцо 2", 126, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring3Btn      = makeButton("➕ Кольцо 3", 159, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring4Btn      = makeButton("➕ Кольцо 4", 192, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring5Btn      = makeButton("➕ Кольцо 5", 225, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))

makeSection("🔷 ФОРМА И ФИГУРЫ", 262, Color3.fromRGB(60, 80, 100))
local shapeBtn      = makeButton("🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name, 286, 30)
local shapeModeBtn  = makeButton("🎭 Формы: " .. FORM_MODES[formModeIndex].name, 319, 30, Color3.fromRGB(50, 40, 65), Color3.fromRGB(220, 200, 255))
local shapeSizeBtn  = makeButton("🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name, 352, 30)
local heartSizeBtn  = makeButton("💗 Сердце: 100%", 385, 30, Color3.fromRGB(70, 30, 55), Color3.fromRGB(255, 160, 200))
local autoSwapBtn   = makeButton("🎭 Автосмена: ВЫКЛ", 418, 30, Color3.fromRGB(50, 50, 70), Color3.fromRGB(200, 200, 255))

makeSection("🛰️ ОРБИТА И ДВИЖЕНИЕ", 455, Color3.fromRGB(60, 100, 80))
local orbitBtn      = makeButton("📏 Орбита: " .. ORBIT_PRESETS[orbitIndex].name, 479, 30)
local spreadBtn     = makeButton("📐 Разлёт: " .. SPREAD_PRESETS[spreadIndex].name, 512, 30, Color3.fromRGB(55, 30, 55), Color3.fromRGB(255, 180, 255))
local heightBtn     = makeButton("⬆️ Высота: " .. HEIGHT_PRESETS[heightIndex].name, 545, 30, Color3.fromRGB(35, 55, 65), Color3.fromRGB(140, 220, 255))
local speedBtn      = makeButton("⚡ Множитель: " .. SPEED_PRESETS[speedIndex].name, 578, 30, Color3.fromRGB(55, 45, 20), Color3.fromRGB(255, 220, 100))
local speedModeBtn  = makeButton("⚙️ Скорость: " .. SPEED_MODE_PRESETS[speedModeIndex].name, 611, 30, Color3.fromRGB(45, 50, 65), Color3.fromRGB(180, 220, 255))
local directionBtn  = makeButton("🔃 Направление: " .. DIRECTION_PRESETS[directionIndex].name, 644, 30, Color3.fromRGB(45, 35, 60), Color3.fromRGB(200, 180, 255))
local orbitPatternBtn = makeButton("🌀 Узор: " .. ORBIT_PATTERNS[orbitPatternIndex].name, 677, 30, Color3.fromRGB(60, 40, 90), Color3.fromRGB(220, 180, 255))

makeSection("🔄 КРУЧЕНИЕ", 714, Color3.fromRGB(100, 60, 80))
local spinBtn       = makeButton("↩️ Вращение в 0", 738, 30, Color3.fromRGB(50, 40, 60), Color3.fromRGB(200, 180, 255))
local spinAxisBtn   = makeButton("🔄 Кручение оси: ВКЛ", 771, 30, Color3.fromRGB(35, 55, 55), Color3.fromRGB(140, 255, 220))
local spinDirBtn    = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 804, 30, Color3.fromRGB(45, 55, 75), Color3.fromRGB(180, 220, 255))
local spinSpeedBtn  = makeButton("🌀 Скорость кручения: 1x", 837, 30, Color3.fromRGB(55, 35, 75), Color3.fromRGB(220, 180, 255))

makeSection("✨ ЭФФЕКТЫ", 874, Color3.fromRGB(100, 80, 60))
local trailBtn      = makeButton("🌠 Трейлы: ВЫКЛ", 898, 30, Color3.fromRGB(35, 35, 50))
local trailLenBtn   = makeButton("📏 Трейл: " .. TRAIL_LENGTH_PRESETS[trailLengthIndex].name, 931, 30, Color3.fromRGB(35, 45, 60), Color3.fromRGB(180, 220, 255))
local trailWidBtn   = makeButton("🎚️ Толщина: " .. TRAIL_WIDTH_PRESETS[trailWidthIndex].name, 964, 30, Color3.fromRGB(35, 45, 60), Color3.fromRGB(180, 220, 255))
local waveBtn       = makeButton("🌊 Волна: ВЫКЛ", 997, 30, Color3.fromRGB(30, 55, 75), Color3.fromRGB(140, 220, 255))
local explosionBtn  = makeButton("💥 Взрыв: ВЫКЛ", 1030, 30, Color3.fromRGB(70, 40, 30), Color3.fromRGB(255, 180, 120))
local pulseBtn      = makeButton("💓 Пульсация: ВЫКЛ", 1063, 30, Color3.fromRGB(35, 35, 50))
local gradientBtn   = makeButton("🌈 Градиент: ВЫКЛ", 1096, 30, Color3.fromRGB(55, 35, 75), Color3.fromRGB(255, 180, 255))

makeSection("🌀 АУРА (мини-кольцо)", 1133, Color3.fromRGB(80, 60, 120))
local auraBtn       = makeButton("🌀 Аура: ВЫКЛ", 1157, 30, Color3.fromRGB(50, 40, 70), Color3.fromRGB(200, 180, 255))
local auraTypeBtn   = makeButton("🔮 Тип: " .. AURA_TYPES[auraTypeIndex].name, 1190, 30, Color3.fromRGB(50, 40, 70), Color3.fromRGB(200, 180, 255))
local auraShapeBtn  = makeButton("🔷 Форма ауры: " .. SHAPE_PRESETS[auraShapeIndex].name, 1223, 30, Color3.fromRGB(60, 40, 80), Color3.fromRGB(220, 180, 255))
local auraColorBtn  = makeButton("🎨 Цвет ауры: " .. COLOR_PRESETS[auraColorIndex].name, 1256, 30, Color3.fromRGB(60, 40, 80), Color3.fromRGB(220, 180, 255))

makeSection("🎨 ЦВЕТ И СВЕТ", 1293, Color3.fromRGB(100, 100, 50))
local colorBtn      = makeButton("🎨 Цвет: " .. COLOR_PRESETS[colorIndex].name, 1317, 30)
local lightBtn      = makeButton("💡 Свет: ВКЛ", 1350, 30, Color3.fromRGB(35, 50, 35), Color3.fromRGB(160, 255, 160))
local nameBtn       = makeButton("🏷️ Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ"), 1383, 30)

makeSection("👥 ЛЮДИ И КОЛЬЦА", 1420, Color3.fromRGB(80, 40, 100))

local peopleContainer = Instance.new("ScrollingFrame")
peopleContainer.Size = UDim2.new(1, -20, 0, 160)
peopleContainer.Position = UDim2.new(0, 10, 0, 1446)
peopleContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
peopleContainer.BorderSizePixel = 0
peopleContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
peopleContainer.ScrollBarThickness = 3
peopleContainer.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 200)
peopleContainer.ScrollingDirection = Enum.ScrollingDirection.Y
peopleContainer.Parent = panel
Instance.new("UICorner", peopleContainer).CornerRadius = UDim.new(0, 8)

local peopleLayout = Instance.new("UIListLayout")
peopleLayout.SortOrder = Enum.SortOrder.LayoutOrder
peopleLayout.Padding = UDim.new(0, 4)
peopleLayout.Parent = peopleContainer

local peoplePadding = Instance.new("UIPadding")
peoplePadding.PaddingTop = UDim.new(0, 4)
peoplePadding.PaddingBottom = UDim.new(0, 4)
peoplePadding.PaddingLeft = UDim.new(0, 4)
peoplePadding.PaddingRight = UDim.new(0, 4)
peoplePadding.Parent = peopleContainer

makeSection("📊 СТАТИСТИКА", 1620, Color3.fromRGB(60, 60, 90))
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 50)
statsLabel.Position = UDim2.new(0, 10, 0, 1644)
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

makeSection("🎵 МУЗЫКА", 1704, Color3.fromRGB(80, 60, 100))
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -20, 0, 32)
musicInput.Position = UDim2.new(0, 10, 0, 1728)
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

local applyIdBtn = makeButton("✅ Применить ID", 1766, 30, Color3.fromRGB(55, 80, 55), Color3.fromRGB(180, 255, 180))
local musicBtn      = makeButton("🎵 Музыка: ВЫКЛ", 1799, 30, Color3.fromRGB(50, 35, 60), Color3.fromRGB(220, 180, 255))

makeSection("💾 СИСТЕМА", 1836, Color3.fromRGB(60, 60, 80))
local saveBtn       = makeButton("💾 Сохранить", 1860, 30, Color3.fromRGB(35, 60, 45), Color3.fromRGB(160, 255, 180))
local loadBtn       = makeButton("📂 Загрузить", 1893, 30, Color3.fromRGB(35, 50, 60), Color3.fromRGB(180, 220, 255))
local resetBtn      = makeButton("🔄 Сброс", 1926, 30, Color3.fromRGB(50, 30, 30), Color3.fromRGB(255, 180, 180))

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

local HEART_SCALE_STEPS = { 0.1625, 0.325, 0.455, 0.65, 0.975, 1.3, 1.625, 1.95 }
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

local function refreshAuraColorBtn()
    local ac = COLOR_PRESETS[auraColorIndex]
    auraColorBtn.Text = "🎨 Цвет ауры: " .. ac.name
    if ac.rainbow then
        auraColorBtn.TextColor3 = Color3.fromRGB(255, 200, 255)
        auraColorBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 90)
    else
        auraColorBtn.TextColor3 = ac.color
        auraColorBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
    end
end

local function refreshAuraShapeBtn()
    auraShapeBtn.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[auraShapeIndex].name
end

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
        setRingEnabled(ri, not rings[ri].enabled)
        refreshRingButton(ri)
    end)
end

shapeBtn.Activated:Connect(function()
    shapeIndex = shapeIndex + 1
    if shapeIndex > #SHAPE_PRESETS then shapeIndex = 1 end
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name
    applyShapes()
    rebuildAllRings()
    rebuildAllTargetRings()
    notify("🔷 " .. SHAPE_PRESETS[shapeIndex].name, Color3.fromRGB(180, 220, 255))
end)

shapeModeBtn.Activated:Connect(function()
    formModeIndex = formModeIndex + 1
    if formModeIndex > #FORM_MODES then formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Формы: " .. FORM_MODES[formModeIndex].name
    applyShapes()
    rebuildAllRings()
    rebuildAllTargetRings()
end)

shapeSizeBtn.Activated:Connect(function()
    shapeSizeIndex = shapeSizeIndex + 1
    if shapeSizeIndex > #SHAPE_SIZE_PRESETS then shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name
    rebuildAllRings()
    rebuildAllTargetRings()
end)

heartSizeBtn.Activated:Connect(function()
    heartScaleIndex = heartScaleIndex + 1
    if heartScaleIndex > #HEART_SCALE_STEPS then heartScaleIndex = 1 end
    SETTINGS.HeartScale = HEART_SCALE_STEPS[heartScaleIndex]
    refreshHeartSizeBtn()
    rebuildAllRings()
    rebuildAllTargetRings()
end)

autoSwapBtn.Activated:Connect(function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "🎭 Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then
        autoSwapBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
        autoSwapBtn.TextColor3 = Color3.fromRGB(255, 200, 255)
        lastAutoSwap = tick()
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
    if orbitPatternIndex > #ORBIT_PATTERNS then orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = ORBIT_PATTERNS[orbitPatternIndex].name
    orbitPatternBtn.Text = "🌀 Узор: " .. ORBIT_PATTERNS[orbitPatternIndex].name
    notify("🌀 Узор: " .. ORBIT_PATTERNS[orbitPatternIndex].name, Color3.fromRGB(200, 180, 255))
end)

spinBtn.Activated:Connect(function()
    spinResetting = not spinResetting
    if spinResetting then
        spinBtn.Text = "↩️ Вращение: ВОЗВРАТ"
        spinBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
        spinBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
    else
        spinBtn.Text = "↩️ Вращение в 0"
        spinBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
        spinBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
    end
end)

spinAxisBtn.Activated:Connect(function()
    spinAxisEnabled = not spinAxisEnabled
    if spinAxisEnabled then
        spinAxisBtn.Text = "🔄 Кручение оси: ВКЛ"
        spinAxisBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 55)
        spinAxisBtn.TextColor3 = Color3.fromRGB(140, 255, 220)
    else
        spinAxisBtn.Text = "🔄 Кручение оси: ВЫКЛ"
        spinAxisBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 35)
        spinAxisBtn.TextColor3 = Color3.fromRGB(200, 160, 160)
    end
end)

spinDirBtn.Activated:Connect(function()
    if spinAxisDir == "X" then
        spinAxisDir = "Y"
        spinDirBtn.Text = "↔️ Ось: ВЛЕВО/ВПРАВО"
        spinDirBtn.BackgroundColor3 = Color3.fromRGB(75, 55, 45)
        spinDirBtn.TextColor3 = Color3.fromRGB(255, 200, 180)
    else
        spinAxisDir = "X"
        spinDirBtn.Text = "↕️ Ось: ВЕРХ/ВНИЗ"
        spinDirBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
        spinDirBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
    end
end)

spinSpeedBtn.Activated:Connect(function()
    spinSpeedIndex = spinSpeedIndex + 1
    if spinSpeedIndex > #SPIN_SPEED_PRESETS then spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = SPIN_SPEED_PRESETS[spinSpeedIndex].value
    refreshSpinSpeedBtn()
end)

trailBtn.Activated:Connect(function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    trailBtn.TextColor3 = SETTINGS.TrailEnabled and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(230, 230, 255)
    rebuildAllRings()
end)

trailLenBtn.Activated:Connect(function()
    trailLengthIndex = trailLengthIndex + 1
    if trailLengthIndex > #TRAIL_LENGTH_PRESETS then trailLengthIndex = 1 end
    SETTINGS.TrailLength = TRAIL_LENGTH_PRESETS[trailLengthIndex].value
    trailLenBtn.Text = "📏 Трейл: " .. TRAIL_LENGTH_PRESETS[trailLengthIndex].name
    refreshAllTrails()
end)

trailWidBtn.Activated:Connect(function()
    trailWidthIndex = trailWidthIndex + 1
    if trailWidthIndex > #TRAIL_WIDTH_PRESETS then trailWidthIndex = 1 end
    SETTINGS.TrailWidth = TRAIL_WIDTH_PRESETS[trailWidthIndex].value
    trailWidBtn.Text = "🎚️ Толщина: " .. TRAIL_WIDTH_PRESETS[trailWidthIndex].name
    refreshAllTrails()
end)

waveBtn.Activated:Connect(function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    waveBtn.Text = "🌊 Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
    waveBtn.TextColor3 = SETTINGS.WaveEnabled and Color3.fromRGB(100, 220, 255) or Color3.fromRGB(180, 220, 255)
end)

explosionBtn.Activated:Connect(function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    explosionBtn.Text = "💥 Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
    explosionBtn.TextColor3 = SETTINGS.ExplosionEnabled and Color3.fromRGB(255, 120, 60) or Color3.fromRGB(255, 180, 120)
end)

pulseBtn.Activated:Connect(function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    pulseBtn.Text = "💓 Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
    pulseBtn.TextColor3 = SETTINGS.PulseEnabled and Color3.fromRGB(255, 100, 180) or Color3.fromRGB(230, 230, 255)
end)

gradientBtn.Activated:Connect(function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    gradientBtn.Text = "🌈 Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then
        gradientBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 90)
        gradientBtn.TextColor3 = Color3.fromRGB(255, 180, 255)
        SETTINGS.Rainbow = false
    end
    rebuildAllRings()
end)

auraBtn.Activated:Connect(function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    auraBtn.Text = "🌀 Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then
        auraBtn.BackgroundColor3 = Color3.fromRGB(70, 50, 100)
        auraBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
        setupAura()
    else
        auraBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
        auraBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
        if auraFolder then auraFolder:Destroy(); auraFolder = nil end
    end
end)

auraTypeBtn.Activated:Connect(function()
    auraTypeIndex = auraTypeIndex + 1
    if auraTypeIndex > #AURA_TYPES then auraTypeIndex = 1 end
    SETTINGS.AuraType = AURA_TYPES[auraTypeIndex].name
    auraTypeBtn.Text = "🔮 Тип: " .. AURA_TYPES[auraTypeIndex].name
    if SETTINGS.AuraEnabled then setupAura() end
end)

auraShapeBtn.Activated:Connect(function()
    auraShapeIndex = auraShapeIndex + 1
    if auraShapeIndex > #SHAPE_PRESETS then auraShapeIndex = 1 end
    refreshAuraShapeBtn()
    if SETTINGS.AuraEnabled then setupAura() end
    notify("🔷 Аура: " .. SHAPE_PRESETS[auraShapeIndex].name, Color3.fromRGB(220, 180, 255))
end)

auraColorBtn.Activated:Connect(function()
    auraColorIndex = auraColorIndex + 1
    if auraColorIndex > #COLOR_PRESETS then auraColorIndex = 1 end
    local ac = COLOR_PRESETS[auraColorIndex]
    if ac.color then SETTINGS.AuraColor = ac.color end
    refreshAuraColorBtn()
    if SETTINGS.AuraEnabled then setupAura() end
    notify("🎨 Аура: " .. ac.name, ac.color or Color3.fromRGB(220, 180, 255))
end)

colorBtn.Activated:Connect(function()
    colorIndex = colorIndex + 1
    if colorIndex > #COLOR_PRESETS then colorIndex = 1 end
    applyColor()
    colorBtn.Text = "🎨 Цвет: " .. COLOR_PRESETS[colorIndex].name
end)

lightBtn.Activated:Connect(function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    lightBtn.TextColor3 = SETTINGS.LightEnabled and Color3.fromRGB(160, 255, 160) or Color3.fromRGB(255, 160, 160)
    rebuildAllRings()
end)

nameBtn.Activated:Connect(function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "🏷️ Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    applyNameVisibility()
end)

applyIdBtn.Activated:Connect(function()
    local ok, err = setMusicId(musicInput.Text)
    if ok then
        applyIdBtn.Text = "✅ Применено!"
        task.wait(1.2)
        applyIdBtn.Text = "✅ Применить ID"
        notify("🎵 ID применён", Color3.fromRGB(180, 255, 180))
    else
        applyIdBtn.Text = "❌ " .. (err or "Ошибка")
        task.wait(1.5)
        applyIdBtn.Text = "✅ Применить ID"
    end
end)

musicBtn.Activated:Connect(function()
    if not musicSound or musicSound.SoundId == "" then
        musicBtn.Text = "❌ Вставь ID!"
        task.wait(1.2)
        musicBtn.Text = "🎵 Музыка: ВЫКЛ"
        return
    end
    musicEnabled = not musicEnabled
    if musicEnabled then
        musicSound:Play()
        musicBtn.Text = "🎵 Музыка: ВКЛ"
        musicBtn.BackgroundColor3 = Color3.fromRGB(70, 45, 90)
    else
        musicSound:Stop()
        musicBtn.Text = "🎵 Музыка: ВЫКЛ"
        musicBtn.BackgroundColor3 = Color3.fromRGB(50, 35, 60)
    end
end)

saveBtn.Activated:Connect(function()
    if musicInput.Text ~= "" then setMusicId(musicInput.Text) end
    if saveSettings() then
        saveBtn.Text = "✅ Сохранено!"
        task.wait(1.5)
        saveBtn.Text = "💾 Сохранить"
        notify(HAS_FS and "💾 Сохранено в файл" or "💾 Сохранено в памяти", Color3.fromRGB(160, 255, 180))
    else
        saveBtn.Text = "❌ Ошибка"
        task.wait(1.5)
        saveBtn.Text = "💾 Сохранить"
    end
end)

loadBtn.Activated:Connect(function()
    local ok = loadSettings()
    if ok then
        heightBtn.Text = "⬆️ Высота: " .. HEIGHT_PRESETS[heightIndex].name
        spreadBtn.Text = "📐 Разлёт: " .. SPREAD_PRESETS[spreadIndex].name
        speedBtn.Text = "⚡ Множитель: " .. SPEED_PRESETS[speedIndex].name
        directionBtn.Text = "🔃 Направление: " .. DIRECTION_PRESETS[directionIndex].name
        speedModeBtn.Text = "⚙️ Скорость: " .. SPEED_MODE_PRESETS[speedModeIndex].name
        shapeModeBtn.Text = "🎭 Формы: " .. FORM_MODES[formModeIndex].name
        shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name
        orbitBtn.Text = "📏 Орбита: " .. ORBIT_PRESETS[orbitIndex].name
        orbitPatternBtn.Text = "🌀 Узор: " .. ORBIT_PATTERNS[orbitPatternIndex].name
        shapeSizeBtn.Text = "🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name
        colorBtn.Text = "🎨 Цвет: " .. COLOR_PRESETS[colorIndex].name
        nameBtn.Text = "🏷️ Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
        trailBtn.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
        trailLenBtn.Text = "📏 Трейл: " .. TRAIL_LENGTH_PRESETS[trailLengthIndex].name
        trailWidBtn.Text = "🎚️ Толщина: " .. TRAIL_WIDTH_PRESETS[trailWidthIndex].name
        waveBtn.Text = "🌊 Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
        explosionBtn.Text = "💥 Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
        pulseBtn.Text = "💓 Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
        lightBtn.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
        gradientBtn.Text = "🌈 Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
        auraBtn.Text = "🌀 Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
        auraTypeBtn.Text = "🔮 Тип: " .. SETTINGS.AuraType
        autoSwapBtn.Text = "🎭 Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
        musicBtn.Text = "🎵 Музыка: " .. (musicEnabled and "ВКЛ" or "ВЫКЛ")
        if savedMusicId ~= "" then musicInput.Text = savedMusicId end
        refreshSpinSpeedBtn()
        refreshHeartSizeBtn()
        refreshAuraColorBtn()
        refreshAuraShapeBtn()
        for ri = 2, 5 do refreshRingButton(ri) end
        applyDirectionPreset()
        applySpeedModePreset()
        rebuildAllRings()
        rebuildAllTargetRings()
        setupAura()
        loadBtn.Text = "✅ Загружено!"
        task.wait(1.5)
        loadBtn.Text = "📂 Загрузить"
        notify("📂 Настройки загружены", Color3.fromRGB(180, 220, 255))
    else
        loadBtn.Text = "❌ Нет сохранения"
        task.wait(1.5)
        loadBtn.Text = "📂 Загрузить"
    end
end)

resetBtn.Activated:Connect(function()
    SETTINGS = table.clone(DEFAULT_SETTINGS)
    spreadIndex, speedIndex, orbitIndex = 2, 2, 2
    shapeSizeIndex, colorIndex, shapeIndex = 3, 1, 1
    trailLengthIndex, trailWidthIndex = 2, 2
    directionIndex, speedModeIndex, heightIndex, formModeIndex = 1, 1, 4, 1
    orbitPatternIndex, auraTypeIndex, auraColorIndex, auraShapeIndex = 1, 1, 1, 1
    spinResetting = false
    spinAxisEnabled = true
    spinAxisDir = "X"
    spinSpeedIndex = 2
    SETTINGS.SpinSpeedMultiplier = 1.0
    heartScaleIndex = 4
    SETTINGS.HeartScale = HEART_SCALE_STEPS[4]
    rings[1].shapeIndex = 1; rings[2].shapeIndex = 2; rings[3].shapeIndex = 3
    rings[4].shapeIndex = 4; rings[5].shapeIndex = 5
    heightBtn.Text = "⬆️ Высота: " .. HEIGHT_PRESETS[heightIndex].name
    spreadBtn.Text = "📐 Разлёт: " .. SPREAD_PRESETS[spreadIndex].name
    speedBtn.Text = "⚡ Множитель: " .. SPEED_PRESETS[speedIndex].name
    directionBtn.Text = "🔃 Направление: " .. DIRECTION_PRESETS[directionIndex].name
    speedModeBtn.Text = "⚙️ Скорость: " .. SPEED_MODE_PRESETS[speedModeIndex].name
    shapeModeBtn.Text = "🎭 Формы: " .. FORM_MODES[formModeIndex].name
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name
    orbitBtn.Text = "📏 Орбита: " .. ORBIT_PRESETS[orbitIndex].name
    orbitPatternBtn.Text = "🌀 Узор: " .. ORBIT_PATTERNS[orbitPatternIndex].name
    shapeSizeBtn.Text = "🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name
    colorBtn.Text = "🎨 Цвет: " .. COLOR_PRESETS[colorIndex].name
    nameBtn.Text = "🏷️ Имена: ВЫКЛ"
    trailBtn.Text = "🌠 Трейлы: ВЫКЛ"; trailBtn.TextColor3 = Color3.fromRGB(230, 230, 255)
    trailLenBtn.Text = "📏 Трейл: " .. TRAIL_LENGTH_PRESETS[trailLengthIndex].name
    trailWidBtn.Text = "🎚️ Толщина: " .. TRAIL_WIDTH_PRESETS[trailWidthIndex].name
    waveBtn.Text = "🌊 Волна: ВЫКЛ"; waveBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
    explosionBtn.Text = "💥 Взрыв: ВЫКЛ"; explosionBtn.TextColor3 = Color3.fromRGB(255, 180, 120)
    pulseBtn.Text = "💓 Пульсация: ВЫКЛ"; pulseBtn.TextColor3 = Color3.fromRGB(230, 230, 255)
    lightBtn.Text = "💡 Свет: ВКЛ"; lightBtn.TextColor3 = Color3.fromRGB(160, 255, 160)
    gradientBtn.Text = "🌈 Градиент: ВЫКЛ"
    auraBtn.Text = "🌀 Аура: ВЫКЛ"
    auraTypeBtn.Text = "🔮 Тип: " .. AURA_TYPES[auraTypeIndex].name
    autoSwapBtn.Text = "🎭 Автосмена: ВЫКЛ"
    spinBtn.Text = "↩️ Вращение в 0"
    spinBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
    spinBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
    spinAxisBtn.Text = "🔄 Кручение оси: ВКЛ"
    spinAxisBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 55)
    spinAxisBtn.TextColor3 = Color3.fromRGB(140, 255, 220)
    spinDirBtn.Text = "↕️ Ось: ВЕРХ/ВНИЗ"
    spinDirBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
    spinDirBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
    refreshSpinSpeedBtn()
    refreshHeartSizeBtn()
    refreshAuraColorBtn()
    refreshAuraShapeBtn()
    allRingsBtn.Text = "⭕ Все кольца: ВКЛ"
    allRingsBtn.TextColor3 = Color3.fromRGB(160, 255, 160)
    allRingsBtn.BackgroundColor3 = Color3.fromRGB(40, 55, 40)
    for ri = 2, 5 do
        if rings[ri].enabled then
            rings[ri].enabled = false
            refreshRingButton(ri)
        end
    end
    applyDirectionPreset()
    applySpeedModePreset()
    rebuildAllRings()
    rebuildAllTargetRings()
    if auraFolder then auraFolder:Destroy(); auraFolder = nil end
    notify("🔄 Сброс выполнен", Color3.fromRGB(255, 180, 180))
end)

-- ==================== СПИСОК ИГРОКОВ ====================
local function rebuildPeopleList()
    for _, btn in pairs(peopleButtons) do pcall(function() btn:Destroy() end) end
    peopleButtons = {}

    local idx = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            idx = idx + 1
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            btn.TextColor3 = Color3.fromRGB(220, 220, 255)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            btn.Text = "🔷 " .. player.Name
            btn.LayoutOrder = idx
            btn.AutoButtonColor = true
            btn.Parent = peopleContainer
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            peopleButtons[player] = btn
            btn.Activated:Connect(function() toggleTargetRings(player) end)
            if targetRings[player] then
                btn.Text = "✅ " .. player.Name
                btn.BackgroundColor3 = Color3.fromRGB(80, 40, 100)
                btn.TextColor3 = Color3.fromRGB(255, 200, 255)
            end
        end
    end

    if idx == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 28)
        empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140, 140, 170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.LayoutOrder = 1
        empty.Parent = peopleContainer
    end

    peopleContainer.CanvasSize = UDim2.new(0, 0, 0, idx * 32 + 12)
end

rebuildPeopleList()

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        task.wait(0.5)
        rebuildPeopleList()
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if p ~= LocalPlayer then
        removeTargetRings(p)
        task.wait(0.1)
        rebuildPeopleList()
    end
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            if targetRings[p] then
                task.wait(0.3)
                removeTargetRings(p)
                buildTargetRings(p)
            end
        end)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            if targetRings[p] then
                task.wait(0.3)
                removeTargetRings(p)
                buildTargetRings(p)
            end
        end)
    end
end)

-- ==================== УВЕДОМЛЕНИЯ (UI) ====================
local notifContainer = Instance.new("Frame")
notifContainer.Size = UDim2.new(0, 260, 0, 300)
notifContainer.Position = UDim2.new(1, -280, 0, 50)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

task.spawn(function()
    local activeNotifs = {}
    while screenGui and screenGui.Parent do
        if #NOTIF_QUEUE > 0 then
            local n = table.remove(NOTIF_QUEUE, 1)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 32)
            lbl.Position = UDim2.new(0, 0, 0, #activeNotifs * 38)
            lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
            lbl.BackgroundTransparency = 0.15
            lbl.BorderSizePixel = 0
            lbl.TextColor3 = n.color
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 12
            lbl.Text = " " .. n.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = notifContainer
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
            local stroke = Instance.new("UIStroke", lbl)
            stroke.Color = n.color; stroke.Thickness = 1; stroke.Transparency = 0.5
            table.insert(activeNotifs, lbl)
            task.spawn(function()
                task.wait(n.duration)
                local tween = TweenService:Create(lbl, TweenInfo.new(0.5), {
                    BackgroundTransparency = 1, TextTransparency = 1,
                })
                tween:Play()
                task.wait(0.5)
                for i, l in ipairs(activeNotifs) do
                    if l == lbl then table.remove(activeNotifs, i); break end
                end
                lbl:Destroy()
                for i, l in ipairs(activeNotifs) do
                    l.Position = UDim2.new(0, 0, 0, (i-1) * 38)
                end
            end)
        end
        task.wait(0.1)
    end
end)

-- ==================== СТАТИСТИКА ====================
task.spawn(function()
    while task.wait(0.5) do
        if statsLabel and statsLabel.Parent then
            local minutes = math.floor(statsData.sessionTime / 60)
            local seconds = math.floor(statsData.sessionTime % 60)
            statsLabel.Text = string.format(
                "📊 FPS: %d | 🔷 Фигур: %d\n⏱️ Время: %d:%02d | 🌀 Узор: %s",
                statsData.lastFPS, statsData.totalShapes, minutes, seconds, SETTINGS.OrbitPattern
            )
            local c = Color3.fromRGB(180, 220, 180)
            if statsData.lastFPS >= 50 then c = Color3.fromRGB(160, 255, 180)
            elseif statsData.lastFPS >= 30 then c = Color3.fromRGB(255, 220, 140)
            else c = Color3.fromRGB(255, 160, 160) end
            statsLabel.TextColor3 = c
        end
    end
end)

-- ==================== АВТОСОХРАНЕНИЕ ====================
task.spawn(function()
    while task.wait(30) do
        if enabled and HAS_FS then pcall(saveSettings) end
    end
end)

-- ==================== ПЕРЕТАСКИВАНИЕ ====================
local dragging, dragStart, startPos = false, nil, nil
mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainBtn.Position
    end
end)
mainBtn.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        mainBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
mainBtn.InputEnded:Connect(function() dragging = false end)

-- ==================== ВЫГРУЗКА ====================
GENV.OrbitFX_Unload = function()
    pcall(function() setEnabled(false) end)
    pcall(function() stopUpdateLoop() end)
    for ri in pairs(rings) do pcall(destroyRing, ri) end
    pcall(cleanupAllTargetRings)
    if auraFolder then pcall(function() auraFolder:Destroy() end); auraFolder = nil end
    if musicSound then pcall(function() musicSound:Destroy() end); musicSound = nil end
    if screenGui then pcall(function() screenGui:Destroy() end) end
    GENV.OrbitFX_Unload = nil
end

-- ==================== СТАРТ ====================
createMusicSound()
applyShapes()
setupRespawnHook()
refreshAuraColorBtn()
refreshAuraShapeBtn()
pcall(function() loadSettings() end)
setEnabled(true)
refreshSpinSpeedBtn()
refreshHeartSizeBtn()

notify("✨ ОРБИТА v15.3 DELTA загружена!", Color3.fromRGB(200, 200, 255), 3)
notify(HAS_FS and "💾 Файл: " .. SAVE_FILE or "💾 Только в памяти", Color3.fromRGB(180, 220, 255), 4)

return {
    Stop = function() setEnabled(false) end,
    Start = function() setEnabled(true) end,
    Unload = GENV.OrbitFX_Unload,
    Rings = rings,
    Settings = SETTINGS,
    Save = saveSettings,
    Load = loadSettings,
    ColorPresets = COLOR_PRESETS,
    HeightPresets = HEIGHT_PRESETS,
    ShapePresets = SHAPE_PRESETS,
    Stats = statsData,
}
