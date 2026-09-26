--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   ОРБИТА ФИГУР v12.6                                     ║
    ║   + Кнопка «Кручение»: вкл/выкл вращение вокруг оси      ║
    ║   + Большой палец торчит НАРУЖУ                          ║
    ║   + Сердце в руке: 0.65                                  ║
    ╚══════════════════════════════════════════════════════════╝
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ==================== МУЗЫКА ====================
local musicEnabled = false
local musicSound = nil
local savedMusicId = ""

local function createMusicSound()
    if musicSound then return end
    musicSound = Instance.new("Sound")
    musicSound.Name = "OrbitMusic"
    musicSound.Volume = 0.5
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

-- ==================== НАСТРОЙКИ ====================
local DEFAULT_SETTINGS = {
    BlockCount = 8,
    BaseShapeSize = 1.5,
    OrbitSpeed = 60,
    SpinSpeed = 120,
    SpeedMultiplier = 1.0,
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
}
local SETTINGS = table.clone(DEFAULT_SETTINGS)

-- ★ НОВОЕ: состояние кручения вокруг оси
local spinAxisEnabled = true

-- ==================== ПРЕСЕТЫ ====================
local SPREAD_PRESETS = {
    { name = "1x  плотно", mult = 1.0 }, { name = "1.5x", mult = 1.5 },
    { name = "2x  средне", mult = 2.0 }, { name = "3x  широко", mult = 3.0 },
    { name = "5x  максимально", mult = 5.0 },
}
local spreadIndex = 2

local HEIGHT_PRESETS = {
    { name = "Очень низко", offset = -12 }, { name = "Низко", offset = -6 },
    { name = "Средне", offset = 0 }, { name = "Высоко", offset = 8 },
    { name = "Очень высоко", offset = 18 }, { name = "Небо", offset = 35 },
}
local heightIndex = 3

local SPEED_PRESETS = {
    { name = "0.5x", value = 0.5 }, { name = "1x", value = 1.0 },
    { name = "1.5x", value = 1.5 }, { name = "2x", value = 2.0 },
    { name = "3x", value = 3.0 }, { name = "5x", value = 5.0 },
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
    { name = "S", radius = 5, height = 2 }, { name = "M", radius = 8, height = 3 },
    { name = "L", radius = 12, height = 4 }, { name = "XL", radius = 18, height = 6 },
}
local orbitIndex = 2

local SHAPE_SIZE_PRESETS = {
    { name = "XS", factor = 0.5 }, { name = "S", factor = 0.75 },
    { name = "M", factor = 1.0 }, { name = "L", factor = 1.5 },
    { name = "XL", factor = 2.2 },
}
local shapeSizeIndex = 3

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
}
local colorIndex = 1

local TRAIL_LENGTH_PRESETS = {
    { name = "Короткий", value = 0.25 }, { name = "Средний", value = 0.5 },
    { name = "Длинный", value = 0.9 }, { name = "Очень длинный", value = 1.6 },
}
local trailLengthIndex = 2

local TRAIL_WIDTH_PRESETS = {
    { name = "Тонкий", value = 0.3 }, { name = "Средний", value = 0.8 },
    { name = "Толстый", value = 1.5 }, { name = "Широкий", value = 2.5 },
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

local RING_STEP = 5
local rings = {
    [1] = { enabled = true, shapeIndex = 1, folder = nil, blocks = {}, radiusOffset = 0, heightOffset = 0, direction = 1, speedMult = 1.0, angleShift = 0, colorShift = 0 },
    [2] = { enabled = false, shapeIndex = 2, folder = nil, blocks = {}, radiusOffset = 1, heightOffset = -0.5, direction = -1, speedMult = 1.3, angleShift = 22.5, colorShift = 0.2 },
    [3] = { enabled = false, shapeIndex = 3, folder = nil, blocks = {}, radiusOffset = 2, heightOffset = 0.5, direction = 1, speedMult = 0.7, angleShift = 45, colorShift = 0.4 },
    [4] = { enabled = false, shapeIndex = 4, folder = nil, blocks = {}, radiusOffset = 3, heightOffset = -1, direction = -1, speedMult = 1.6, angleShift = 67.5, colorShift = 0.6 },
    [5] = { enabled = false, shapeIndex = 5, folder = nil, blocks = {}, radiusOffset = 4, heightOffset = 1, direction = 1, speedMult = 0.5, angleShift = 90, colorShift = 0.8 },
}

for ri in pairs(rings) do
    currentRadius[ri] = 8; currentHeight[ri] = 3
    currentSpeed[ri] = 60; currentSpin[ri] = 120
    currentOrbitAngle[ri] = 0; currentSpinAngle[ri] = 0; currentBobPhase[ri] = 0
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
    root.Name = "Root"; root.Size = Vector3.new(0.1, 0.1, 0.1)
    root.Transparency = 1; root.Anchored = true; root.CanCollide = false
    root.CastShadow = false; root.Parent = model
    model.PrimaryPart = root
    return model, root
end

local function makeRod(parent, a, b, thickness, depth, color)
    local mid = (a + b) * 0.5; local diff = b - a
    local part = Instance.new("Part")
    part.Name = "Rod"; part.Size = Vector3.new(depth, thickness, diff.Magnitude)
    part.CFrame = CFrame.lookAt(mid, mid + diff.Unit)
    part.Anchored = true; part.CanCollide = false; part.CastShadow = false
    part.Material = Enum.Material.Neon; part.Color = color
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
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
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

-- ==================== ФИГУРЫ ====================
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
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
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
    local R = size * 0.75; local t, d = size * 0.13, size * 0.28
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
    local R = size * 0.75; local t, d = size * 0.13, size * 0.28
    local vT = Vector3.new(0, R, 0); local vR = Vector3.new(R * 0.75, 0, 0)
    local vB = Vector3.new(0, -R, 0); local vL = Vector3.new(-R * 0.75, 0, 0)
    table.insert(bodies, makeRod(model, vT, vR, t, d, color))
    table.insert(bodies, makeRod(model, vR, vB, t, d, color))
    table.insert(bodies, makeRod(model, vB, vL, t, d, color))
    table.insert(bodies, makeRod(model, vL, vT, t, d, color))
    return model, root, bodies
end

local HEART_PATTERN = { "11011", "11111", "11111", "01110", "00100" }
local function createPixelHeart(sizeStuds, color, name)
    local rows = #HEART_PATTERN; local cols = #HEART_PATTERN[1]
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
        local heartSize = s * 0.65
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

local SHAPE_PRESETS = {
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
        return { model = m, part = r, isModel = true, bodyParts = b, visualSize = s * 1.0 }
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
}
local shapeIndex = 1

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
local function getTargetSpin() return SETTINGS.SpinSpeed * SETTINGS.SpeedMultiplier end

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
            light.Brightness = 2
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
        nameGui.AlwaysOnTop = true; nameGui.LightInfluence = 0
        nameGui.Adornee = refPart; nameGui.Enabled = SETTINGS.ShowBlockNames
        nameGui.Parent = refPart

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 1, 0); nameLabel.BackgroundTransparency = 1
        nameLabel.Text = blockName; nameLabel.TextScaled = true
        nameLabel.TextColor3 = SETTINGS.NameColor; nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextStrokeTransparency = 0.3; nameLabel.Parent = nameGui

        table.insert(ring.blocks, {
            part = refPart, model = data.model, isModel = data.isModel or false,
            bodyParts = data.bodyParts, light = light, trail = trail, lastTrailUpdate = 0,
            nameGui = nameGui, nameLabel = nameLabel, visualSize = visualSize,
            angleOffset = (i - 1) * (360 / SETTINGS.BlockCount) + ring.angleShift,
        })
    end
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

        for ri, ring in pairs(rings) do
            currentRadius[ri] = currentRadius[ri] + (getTargetRadius(ri) - currentRadius[ri]) * lerpFactor
            currentHeight[ri] = currentHeight[ri] + (getTargetHeight(ri) - currentHeight[ri]) * lerpFactor
            currentSpeed[ri] = currentSpeed[ri] + (getTargetSpeed() * ring.speedMult * ring.direction - currentSpeed[ri]) * lerpFactor
            currentSpin[ri] = currentSpin[ri] + (getTargetSpin() * ring.speedMult * ring.direction - currentSpin[ri]) * lerpFactor

            currentOrbitAngle[ri] = currentOrbitAngle[ri] + currentSpeed[ri] * dt
            currentBobPhase[ri] = currentBobPhase[ri] + 2 * (globalMult * ring.speedMult) * dt

            -- ★ Логика кручения вокруг своей оси
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

                local offset = Vector3.new(
                    math.cos(angle) * radius,
                    height + yBob,
                    math.sin(angle) * radius
                )
                local targetCF = CFrame.new(root.Position + offset)
                    * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle) * 0.7, 0)

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
    else
        stopUpdateLoop()
        for ri in pairs(rings) do destroyRing(ri) end
        activeLightCount = 0
    end
end

local function setRingEnabled(ri, state)
    local ring = rings[ri]
    if not ring then return end
    ring.enabled = state
    if not enabled then return end
    if state then
        countActiveLights(); buildRing(ri); applyColor(); applyNameVisibility()
    else
        destroyRing(ri); countActiveLights()
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
            applyColor(); applyNameVisibility()
        end
    end)
end

-- ==================== СОХРАНЕНИЕ / ЗАГРУЗКА ====================
local SAVE_FILE = "OrbitFX_v11_save.json"

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
        ringShapes = ringShapes, ringEnabled = ringEnabled,
        lightEnabled = SETTINGS.LightEnabled, trailEnabled = SETTINGS.TrailEnabled,
        pulseEnabled = SETTINGS.PulseEnabled, showNames = SETTINGS.ShowBlockNames,
        waveEnabled = SETTINGS.WaveEnabled, explosionEnabled = SETTINGS.ExplosionEnabled,
        spinResetting = spinResetting,
        spinAxisEnabled = spinAxisEnabled,
        musicEnabled = musicEnabled, musicId = savedMusicId,
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
    if data.spinResetting ~= nil then spinResetting = data.spinResetting end
    if data.spinAxisEnabled ~= nil then spinAxisEnabled = data.spinAxisEnabled end

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
panel.Size = UDim2.new(0, 250, 0, 700)
panel.Position = UDim2.new(0, 90, 0, 5)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 1213)
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
title.Text = "ОРБИТА v12.6"
title.TextColor3 = Color3.fromRGB(200, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = panel

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

local toggleBtn     = makeButton("🟢 ВКЛЮЧЕНО", 36, 30, Color3.fromRGB(40, 40, 55), Color3.fromRGB(0, 255, 120))
local allRingsBtn   = makeButton("⭕ Все кольца: ВКЛ", 69, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring2Btn      = makeButton("➕ Кольцо 2", 102, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring3Btn      = makeButton("➕ Кольцо 3", 135, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring4Btn      = makeButton("➕ Кольцо 4", 168, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local ring5Btn      = makeButton("➕ Кольцо 5", 201, 30, Color3.fromRGB(40, 55, 40), Color3.fromRGB(160, 255, 160))
local heightBtn     = makeButton("⬆️ Высота: " .. HEIGHT_PRESETS[heightIndex].name, 234, 30, Color3.fromRGB(35, 55, 65), Color3.fromRGB(140, 220, 255))
local speedModeBtn  = makeButton("⚙️ Скорость: " .. SPEED_MODE_PRESETS[speedModeIndex].name, 267, 30, Color3.fromRGB(45, 50, 65), Color3.fromRGB(180, 220, 255))
local directionBtn  = makeButton("🔃 Направление: " .. DIRECTION_PRESETS[directionIndex].name, 300, 30, Color3.fromRGB(45, 35, 60), Color3.fromRGB(200, 180, 255))
local spreadBtn     = makeButton("📐 Разлёт: " .. SPREAD_PRESETS[spreadIndex].name, 333, 30, Color3.fromRGB(55, 30, 55), Color3.fromRGB(255, 180, 255))
local speedBtn      = makeButton("⚡ Множитель: " .. SPEED_PRESETS[speedIndex].name, 366, 30, Color3.fromRGB(55, 45, 20), Color3.fromRGB(255, 220, 100))
local shapeModeBtn  = makeButton("🎭 Формы: " .. FORM_MODES[formModeIndex].name, 399, 30, Color3.fromRGB(50, 40, 65), Color3.fromRGB(220, 200, 255))
local shapeBtn      = makeButton("🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name, 432, 30)
local orbitBtn      = makeButton("📏 Орбита: " .. ORBIT_PRESETS[orbitIndex].name, 465, 30)
local shapeSizeBtn  = makeButton("🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name, 498, 30)
local colorBtn      = makeButton("🎨 Цвет: " .. COLOR_PRESETS[colorIndex].name, 531, 30)
local nameBtn       = makeButton("🏷️ Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ"), 564, 30)
local trailBtn      = makeButton("🌠 Трейлы: ВЫКЛ", 597, 30, Color3.fromRGB(35, 35, 50))
local trailLenBtn   = makeButton("📏 Трейл: " .. TRAIL_LENGTH_PRESETS[trailLengthIndex].name, 630, 30, Color3.fromRGB(35, 45, 60), Color3.fromRGB(180, 220, 255))
local trailWidBtn   = makeButton("🎚️ Толщина: " .. TRAIL_WIDTH_PRESETS[trailWidthIndex].name, 663, 30, Color3.fromRGB(35, 45, 60), Color3.fromRGB(180, 220, 255))
local waveBtn       = makeButton("🌊 Волна: ВЫКЛ", 696, 30, Color3.fromRGB(30, 55, 75), Color3.fromRGB(140, 220, 255))
local explosionBtn  = makeButton("💥 Взрыв: ВЫКЛ", 729, 30, Color3.fromRGB(70, 40, 30), Color3.fromRGB(255, 180, 120))
local pulseBtn      = makeButton("💓 Пульсация: ВЫКЛ", 762, 30, Color3.fromRGB(35, 35, 50))
local lightBtn      = makeButton("💡 Свет: ВКЛ", 795, 30, Color3.fromRGB(35, 50, 35), Color3.fromRGB(160, 255, 160))
local spinBtn       = makeButton("↩️ Вращение в 0", 828, 30, Color3.fromRGB(50, 40, 60), Color3.fromRGB(200, 180, 255))

-- ★ НОВАЯ КНОПКА: Кручение вокруг своей оси
local spinAxisBtn   = makeButton("🔄 Кручение оси: ВКЛ", 861, 30, Color3.fromRGB(35, 55, 55), Color3.fromRGB(140, 255, 220))

local musicSection = Instance.new("TextLabel")
musicSection.Size = UDim2.new(1, -20, 0, 20)
musicSection.Position = UDim2.new(0, 10, 0, 895)
musicSection.BackgroundTransparency = 1
musicSection.Text = "🎵 МУЗЫКА (вставь ID трека ниже)"
musicSection.TextColor3 = Color3.fromRGB(220, 180, 255)
musicSection.Font = Enum.Font.GothamBold
musicSection.TextSize = 11
musicSection.TextXAlignment = Enum.TextXAlignment.Left
musicSection.Parent = panel

local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -20, 0, 32)
musicInput.Position = UDim2.new(0, 10, 0, 917)
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

local musicHint = Instance.new("TextLabel")
musicHint.Size = UDim2.new(1, -20, 0, 44)
musicHint.Position = UDim2.new(0, 10, 0, 953)
musicHint.BackgroundTransparency = 1
musicHint.Text = "Как узнать ID:\n1) Открой roblox.com/library → Audio\n2) Найди трек → скопируй цифры из ссылки\n3) Вставь сюда → нажми «Применить»"
musicHint.TextColor3 = Color3.fromRGB(170, 170, 200)
musicHint.Font = Enum.Font.Gotham
musicHint.TextSize = 10
musicHint.TextWrapped = true
musicHint.TextXAlignment = Enum.TextXAlignment.Left
musicHint.TextYAlignment = Enum.TextYAlignment.Top
musicHint.Parent = panel

local applyIdBtn = makeButton("✅ Применить ID", 1003, 30, Color3.fromRGB(55, 80, 55), Color3.fromRGB(180, 255, 180))
local musicBtn      = makeButton("🎵 Музыка: ВЫКЛ", 1036, 30, Color3.fromRGB(50, 35, 60), Color3.fromRGB(220, 180, 255))
local saveBtn       = makeButton("💾 Сохранить", 1069, 30, Color3.fromRGB(35, 60, 45), Color3.fromRGB(160, 255, 180))
local loadBtn       = makeButton("📂 Загрузить", 1102, 30, Color3.fromRGB(35, 50, 60), Color3.fromRGB(180, 220, 255))
local resetBtn      = makeButton("🔄 Сброс", 1135, 30, Color3.fromRGB(50, 30, 30), Color3.fromRGB(255, 180, 180))

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

-- ==================== ОБРАБОТЧИКИ ====================
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

heightBtn.Activated:Connect(function()
    heightIndex = heightIndex + 1
    if heightIndex > #HEIGHT_PRESETS then heightIndex = 1 end
    heightBtn.Text = "⬆️ Высота: " .. HEIGHT_PRESETS[heightIndex].name
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

spreadBtn.Activated:Connect(function()
    spreadIndex = spreadIndex + 1
    if spreadIndex > #SPREAD_PRESETS then spreadIndex = 1 end
    spreadBtn.Text = "📐 Разлёт: " .. SPREAD_PRESETS[spreadIndex].name
end)

speedBtn.Activated:Connect(function()
    speedIndex = speedIndex + 1
    if speedIndex > #SPEED_PRESETS then speedIndex = 1 end
    SETTINGS.SpeedMultiplier = SPEED_PRESETS[speedIndex].value
    speedBtn.Text = "⚡ Множитель: " .. SPEED_PRESETS[speedIndex].name
end)

shapeModeBtn.Activated:Connect(function()
    formModeIndex = formModeIndex + 1
    if formModeIndex > #FORM_MODES then formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Формы: " .. FORM_MODES[formModeIndex].name
    applyShapes()
    rebuildAllRings()
end)

shapeBtn.Activated:Connect(function()
    shapeIndex = shapeIndex + 1
    if shapeIndex > #SHAPE_PRESETS then shapeIndex = 1 end
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[shapeIndex].name
    applyShapes()
    rebuildAllRings()
end)

orbitBtn.Activated:Connect(function()
    orbitIndex = orbitIndex + 1
    if orbitIndex > #ORBIT_PRESETS then orbitIndex = 1 end
    orbitBtn.Text = "📏 Орбита: " .. ORBIT_PRESETS[orbitIndex].name
end)

shapeSizeBtn.Activated:Connect(function()
    shapeSizeIndex = shapeSizeIndex + 1
    if shapeSizeIndex > #SHAPE_SIZE_PRESETS then shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "🔍 Фигура: " .. SHAPE_SIZE_PRESETS[shapeSizeIndex].name
    rebuildAllRings()
end)

colorBtn.Activated:Connect(function()
    colorIndex = colorIndex + 1
    if colorIndex > #COLOR_PRESETS then colorIndex = 1 end
    applyColor()
    colorBtn.Text = "🎨 Цвет: " .. COLOR_PRESETS[colorIndex].name
end)

nameBtn.Activated:Connect(function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "🏷️ Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    applyNameVisibility()
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

lightBtn.Activated:Connect(function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    lightBtn.TextColor3 = SETTINGS.LightEnabled and Color3.fromRGB(160, 255, 160) or Color3.fromRGB(255, 160, 160)
    rebuildAllRings()
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

-- ★ НОВЫЙ ОБРАБОТЧИК: Кручение вокруг оси
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

applyIdBtn.Activated:Connect(function()
    local ok, err = setMusicId(musicInput.Text)
    if ok then
        applyIdBtn.Text = "✅ Применено!"
        task.wait(1.2)
        applyIdBtn.Text = "✅ Применить ID"
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
    if musicInput.Text ~= "" then
        setMusicId(musicInput.Text)
    end
    local ok = saveSettings()
    if ok then
        saveBtn.Text = "✅ Сохранено!"
        task.wait(1.5)
        saveBtn.Text = "💾 Сохранить"
    else
        saveBtn.Text = "❌ Ошибка сохранения"
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
        musicBtn.Text = "🎵 Музыка: " .. (musicEnabled and "ВКЛ" or "ВЫКЛ")
        if savedMusicId ~= "" then musicInput.Text = savedMusicId end

        if spinResetting then
            spinBtn.Text = "↩️ Вращение: ВОЗВРАТ"
            spinBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
            spinBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
        else
            spinBtn.Text = "↩️ Вращение в 0"
            spinBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
            spinBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
        end

        if spinAxisEnabled then
            spinAxisBtn.Text = "🔄 Кручение оси: ВКЛ"
            spinAxisBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 55)
            spinAxisBtn.TextColor3 = Color3.fromRGB(140, 255, 220)
        else
            spinAxisBtn.Text = "🔄 Кручение оси: ВЫКЛ"
            spinAxisBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 35)
            spinAxisBtn.TextColor3 = Color3.fromRGB(200, 160, 160)
        end

        for ri = 2, 5 do refreshRingButton(ri) end
        applyDirectionPreset()
        applySpeedModePreset()
        rebuildAllRings()

        loadBtn.Text = "✅ Загружено!"
        task.wait(1.5)
        loadBtn.Text = "📂 Загрузить"
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
    directionIndex, speedModeIndex, heightIndex, formModeIndex = 1, 1, 3, 1
    spinResetting = false
    spinAxisEnabled = true

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
    spinBtn.Text = "↩️ Вращение в 0"
    spinBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
    spinBtn.TextColor3 = Color3.fromRGB(200, 180, 255)
    spinAxisBtn.Text = "🔄 Кручение оси: ВКЛ"
    spinAxisBtn.BackgroundColor3 = Color3.fromRGB(35, 55, 55)
    spinAxisBtn.TextColor3 = Color3.fromRGB(140, 255, 220)
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
end)

-- ==================== ПЕРЕТАСКИВАНИЕ ====================
local dragging, dragStart, startPos = false, nil, nil
mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = mainBtn.Position
    end
end)
mainBtn.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        mainBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
mainBtn.InputEnded:Connect(function() dragging = false end)

-- ==================== СТАРТ ====================
createMusicSound()
applyShapes()
setupRespawnHook()
setEnabled(true)

return {
    Stop = function() setEnabled(false) end,
    Start = function() setEnabled(true) end,
    Rings = rings,
    Settings = SETTINGS,
    Save = saveSettings,
    Load = loadSettings,
    ColorPresets = COLOR_PRESETS,
    HeightPresets = HEIGHT_PRESETS,
}
