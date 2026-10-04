--[[ ОРБИТА v23.3 — P3: ЛОГИКА
     🆕 Свет ауры (PointLight)
     🆕 Синхронизация цвета
     🐛 Фикс SESSION
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P3] Часть 1 не загружена!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local Workspace    = ORBIT.Workspace
local LocalPlayer  = ORBIT.LocalPlayer
local HttpService  = ORBIT.HttpService

local SETTINGS      = ORBIT.SETTINGS
local P             = ORBIT.P
local rings         = ORBIT.rings
local statsData     = ORBIT.statsData
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS
if not P then warn("[Orbit P3] P не передан"); return end
if not SHAPE_PRESETS then warn("[Orbit P3] Часть 2 не загружена"); return end

-- ==================== СЕССИЯ ====================
ORBIT.SESSION = ORBIT.SESSION or {
    botsCollected = 0, cheatersTagged = 0, dodgesMade = 0,
    protectionsTriggered = 0, startTime = tick(), coinsSpent = 0, coinsEarned = 0,
}
function ORBIT.addSession(field, amount)
    ORBIT.SESSION[field] = (ORBIT.SESSION[field] or 0) + (amount or 1)
end

-- ==================== КАТЕГОРИИ ====================
function ORBIT.getShapeIndicesInCategory()
    local cat = P.SHAPE_CATEGORIES[P.shapeCategoryIndex]
    if not cat or not cat.shapes then
        local list = {}
        for i = 1, #SHAPE_PRESETS do list[i] = i end
        return list
    end
    local list = {}
    for _, name in ipairs(cat.shapes) do
        for i, sp in ipairs(SHAPE_PRESETS) do
            if sp.name == name then table.insert(list, i); break end
        end
    end
    return list
end

-- ==================== ПАТТЕРНЫ ====================
local function applyPattern(pattern, angle, radius, height, seed)
    seed = seed or 0
    if pattern == "Круг" then
        return math.cos(angle)*radius, height, math.sin(angle)*radius
    elseif pattern == "Спираль" then
        local sf = (math.sin(angle*0.3)+1)*0.5
        local r = radius*(0.4+0.6*sf)
        return math.cos(angle)*r, height + math.sin(angle*0.5)*3, math.sin(angle)*r
    elseif pattern == "Волна" then
        return math.cos(angle)*radius, height + math.sin(angle*2)*4, math.sin(angle)*radius
    elseif pattern == "Восьмерка" or pattern == "Восьмёрка" then
        return math.sin(angle)*radius, height, math.sin(angle*2)*radius*0.5
    elseif pattern == "Зигзаг" then
        local seg = math.floor(angle/(math.pi/3))
        local dir = (seg%2==0) and 1 or -1
        return math.cos(angle)*radius, height + dir*2, math.sin(angle)*radius
    elseif pattern == "Лиссажу" then
        return math.sin(3*angle)*radius, height, math.sin(2*angle + math.pi/2)*radius
    elseif pattern == "Хаос" then
        local r = radius*(0.7 + math.sin(angle*7.3+seed)*0.3)
        return math.cos(angle)*r, height + math.sin(angle*5.1+seed*2)*3, math.sin(angle)*r
    end
    return math.cos(angle)*radius, height, math.sin(angle)*radius
end
ORBIT.applyPattern = applyPattern

-- ==================== АУРА ====================
local function getAuraColor(i, total)
    local p = P.COLORS[P.auraColorIndex]
    if p.rainbow then
        local t = tick() - ORBIT.startTime
        return Color3.fromHSV((t*0.2 + i/math.max(total,1)) % 1, 0.9, 1)
    end
    return p.c or SETTINGS.AuraColor
end
local function getAuraShapeSize() return ORBIT.getCurrentShapeSize() * SETTINGS.AuraShapeScale end

function ORBIT.setupAura()
    if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
    ORBIT.auraParts = {}; ORBIT.auraBlocks = {}
    if not SETTINGS.AuraEnabled then return end
    ORBIT.auraFolder = Instance.new("Folder")
    ORBIT.auraFolder.Name = "OrbitAura_" .. tostring(math.random(1, 999999))
    ORBIT.auraFolder.Parent = Workspace

    -- Кольцо
    if SETTINGS.AuraRing then
        local ring = Instance.new("Part")
        ring.Name = "AuraRing"; ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(SETTINGS.AuraThickness, SETTINGS.AuraSize*2, SETTINGS.AuraSize*2)
        ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
        ring.CanQuery = false; ring.CanTouch = false
        ring.Material = Enum.Material.Neon; ring.Color = getAuraColor(1, 1); ring.Transparency = 0.3
        ring.Parent = ORBIT.auraFolder
        table.insert(ORBIT.auraParts, ring)
    end

    -- Частицы
    if SETTINGS.AuraParticles then
        local emitter = Instance.new("Part")
        emitter.Name = "AuraEmitter"; emitter.Size = Vector3.new(0.1,0.1,0.1); emitter.Transparency = 1
        emitter.Anchored = true; emitter.CanCollide = false; emitter.CastShadow = false
        emitter.CanQuery = false; emitter.CanTouch = false
        emitter.Parent = ORBIT.auraFolder
        local col = getAuraColor(1, 1)
        for _, cfg in ipairs({
            { rate=150, life={1.0,2.0}, spd={3,6}, spread=Vector2.new(180,180), size={0.4,0.7,0.2}, tr=0.1 },
            { rate=100, life={0.6,1.2}, spd={5,9}, spread=Vector2.new(20,20),   size={0.5,0.5,0.5}, tr=0.3 },
            { rate=80,  life={1.2,2.5}, spd={1,3}, spread=Vector2.new(180,180), size={0.8,0.8,0.3}, tr=0.4 },
        }) do
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            pe.Rate = cfg.rate
            pe.Lifetime = NumberRange.new(cfg.life[1], cfg.life[2])
            pe.Speed = NumberRange.new(cfg.spd[1], cfg.spd[2])
            pe.SpreadAngle = cfg.spread
            pe.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, cfg.size[1]),
                NumberSequenceKeypoint.new(0.5, cfg.size[2]),
                NumberSequenceKeypoint.new(1, cfg.size[3]),
            })
            pe.Color = ColorSequence.new(col)
            pe.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, cfg.tr),
                NumberSequenceKeypoint.new(1, 1),
            })
            pe.Parent = emitter
        end
        table.insert(ORBIT.auraParts, emitter)
    end

    -- 🆕 Свет ауры
    if SETTINGS.AuraLightEnabled then
        local lightPart = Instance.new("Part")
        lightPart.Name = "AuraLightHolder"
        lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
        lightPart.Transparency = 1
        lightPart.Anchored = true
        lightPart.CanCollide = false
        lightPart.CastShadow = false
        lightPart.CanQuery = false
        lightPart.CanTouch = false
        lightPart.Parent = ORBIT.auraFolder
        local pl = Instance.new("PointLight")
        pl.Name = "AuraLight"
        pl.Color = SETTINGS.AuraColor
        pl.Range = SETTINGS.AuraLightRange or 8
        pl.Brightness = SETTINGS.AuraLightBrightness or 2
        pl.Shadows = false
        pl.Parent = lightPart
        table.insert(ORBIT.auraParts, lightPart)
    end

    -- Фигуры
    if SETTINGS.AuraShapes then
        local folder = Instance.new("Folder"); folder.Name = "AuraShapes"; folder.Parent = ORBIT.auraFolder
        local shape = SHAPE_PRESETS[ORBIT.auraShapeIndex] or SHAPE_PRESETS[1]
        local size = getAuraShapeSize()
        local count = math.max(4, math.floor(SETTINGS.BlockCount * 0.75))
        for i = 1, count do
            local data = shape.create(size, "Aura_" .. i)
            local refPart = data.part
            if not data.isModel then
                refPart.Material = SETTINGS.Material
                refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
                refPart.CanQuery = false; refPart.CanTouch = false
                refPart.Transparency = SETTINGS.Transparency
                refPart.Color = getAuraColor(i, count)
            end
            if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
            local trail = nil
            if SETTINGS.AuraTrailEnabled then
                local span = (data.visualSize or size) * 0.35
                local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(-span,0,0); a0.Parent = refPart
                local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(span,0,0); a1.Parent = refPart
                trail = Instance.new("Trail")
                trail.Attachment0 = a0; trail.Attachment1 = a1
                trail.Color = ColorSequence.new(getAuraColor(i, count))
                trail.Lifetime = SETTINGS.AuraTrailLength
                trail.WidthScale = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, SETTINGS.AuraTrailWidth),
                    NumberSequenceKeypoint.new(1, 0),
                })
                trail.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1),
                })
                trail.Parent = refPart
            end
            table.insert(ORBIT.auraBlocks, {
                part = refPart, model = data.model, isModel = data.isModel or false,
                bodyParts = data.bodyParts, index = i, total = count, trail = trail,
            })
        end
    end
end

local function updateAura(dt)
    if not ORBIT.auraFolder then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local baseCol = getAuraColor(1, 1)

    for _, part in ipairs(ORBIT.auraParts) do
        if part.Name == "AuraRing" then
            part.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
            part.Color = P.COLORS[P.auraColorIndex].rainbow and baseCol or (P.COLORS[P.auraColorIndex].c or SETTINGS.AuraColor)
        elseif part.Name == "AuraEmitter" then
            part.CFrame = hrp.CFrame
            if P.COLORS[P.auraColorIndex].rainbow then
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("ParticleEmitter") then child.Color = ColorSequence.new(baseCol) end
                end
            end
        elseif part.Name == "AuraLightHolder" then
            -- 🆕 Свет ауры следует за игроком
            part.CFrame = hrp.CFrame
            local pl = part:FindFirstChildOfClass("PointLight")
            if pl then
                local col
                local ac = P.COLORS[P.auraColorIndex]
                if ac.rainbow then
                    col = baseCol
                else
                    col = ac.c or SETTINGS.AuraColor
                end
                pl.Color = col
                pl.Range = SETTINGS.AuraLightRange or 8
                pl.Brightness = SETTINGS.AuraLightBrightness or 2
            end
        end
    end

    if SETTINGS.AuraShapes and #ORBIT.auraBlocks > 0 then
        local auraOrbitSpeed = SETTINGS.OrbitSpeed * SETTINGS.SpeedMultiplier * 0.7
            * SETTINGS.AuraSpeedMult * SETTINGS.AuraDirection
        ORBIT.auraAngle = ORBIT.auraAngle + auraOrbitSpeed * dt
        if SETTINGS.AuraSpinEnabled then
            ORBIT.auraSpinAngle = ORBIT.auraSpinAngle + SETTINGS.AuraSpinSpeed * SETTINGS.SpeedMultiplier * dt
        end
        local radius = SETTINGS.AuraSize
        local height = SETTINGS.AuraHeight
        local pattern = SETTINGS.AuraPattern or "Круг"
        local t = tick() - ORBIT.startTime
        for _, data in ipairs(ORBIT.auraBlocks) do
            if not data.part.Parent then continue end
            local angle = math.rad(ORBIT.auraAngle + (data.index-1)*(360/data.total))
            local px, py, pz = applyPattern(pattern, angle, radius, height, data.index)
            local pos = hrp.Position + Vector3.new(px, py, pz)
            local cf
            if SETTINGS.AuraSpinEnabled then
                if SETTINGS.AuraSpinAxis == "Y" then
                    cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0) * CFrame.Angles(0, math.rad(ORBIT.auraSpinAngle), 0)
                else
                    cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0) * CFrame.Angles(math.rad(ORBIT.auraSpinAngle), 0, 0)
                end
            else
                cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
            end
            local pulseScale = 1.0
            if SETTINGS.AuraPulseEnabled then
                pulseScale = 1.0 + math.sin(t * 4 + data.index) * 0.15
            end
            if data.isModel and data.model then
                data.model:PivotTo(cf)
                local tgt = pulseScale
                local cur = data.model:GetAttribute("Scale") or 1
                if math.abs(cur - tgt) > 0.005 then
                    pcall(function() data.model:ScaleTo(tgt) end)
                    data.model:SetAttribute("Scale", tgt)
                end
            else
                data.part.CFrame = cf
                if math.abs(pulseScale - 1.0) > 0.001 then
                    local baseSz = getAuraShapeSize() * pulseScale
                    data.part.Size = Vector3.new(baseSz, baseSz, baseSz)
                end
            end
            local col = getAuraColor(data.index, data.total)
            if data.bodyParts then
                for _, p in ipairs(data.bodyParts) do
                    if not p:GetAttribute("NoRecolor") then p.Color = col end
                end
            elseif data.part then data.part.Color = col end
            if data.trail then data.trail.Color = ColorSequence.new(col) end
        end
    end
end

-- ==================== ОГОНЬ ====================
function ORBIT.setupFire()
    if ORBIT.fireFolder then ORBIT.fireFolder:Destroy(); ORBIT.fireFolder = nil end
    ORBIT.fireParts = {}
    if not SETTINGS.FireEnabled then return end
    ORBIT.fireFolder = Instance.new("Folder")
    ORBIT.fireFolder.Name = "OrbitFire_" .. tostring(math.random(1, 999999))
    ORBIT.fireFolder.Parent = Workspace
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local part = Instance.new("Part")
    part.Name = "FirePart"; part.Size = Vector3.new(1, 1, 1); part.Transparency = 1
    part.Anchored = true; part.CanCollide = false; part.CastShadow = false
    part.CanQuery = false; part.CanTouch = false
    part.CFrame = hrp.CFrame; part.Parent = ORBIT.fireFolder
    local fire = Instance.new("Fire")
    fire.Heat = SETTINGS.FireHeat; fire.Size = SETTINGS.FireSize
    fire.Color = SETTINGS.FireColor; fire.SecondaryColor = Color3.fromRGB(255, 220, 100)
    fire.Parent = part
    table.insert(ORBIT.fireParts, part)
end

local function updateFire()
    if not ORBIT.fireFolder then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, part in ipairs(ORBIT.fireParts) do
        if part.Parent then part.CFrame = hrp.CFrame end
    end
end

-- ============================================================
--       ESP
-- ============================================================
ORBIT.ESP = ORBIT.ESP or {
    Enabled = false, MaxDistance = 500, UpdateInterval = 0.1,
    LastUpdate = 0, Tags = {},
}

local function makeESPTag(player)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local existing = head:FindFirstChild("_OrbitESP")
    if existing then existing:Destroy() end

    local isTagged = ORBIT.taggedPlayers and ORBIT.taggedPlayers[player]
    local color = isTagged and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(80, 255, 120)

    local bb = Instance.new("BillboardGui")
    bb.Name = "_OrbitESP"
    bb.Size = UDim2.new(0, 180, 0, 42)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Adornee = head
    bb.Parent = head

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 20)
    nameLbl.BackgroundTransparency = 0.3
    nameLbl.BackgroundColor3 = isTagged and Color3.fromRGB(80, 20, 20) or Color3.fromRGB(20, 60, 30)
    nameLbl.BorderSizePixel = 0
    nameLbl.Text = player.Name
    nameLbl.TextColor3 = color
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.Parent = bb
    Instance.new("UICorner", nameLbl).CornerRadius = UDim.new(0, 4)

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, 0, 0, 18)
    distLbl.Position = UDim2.new(0, 0, 0, 21)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "0 st"
    distLbl.TextColor3 = Color3.fromRGB(220, 220, 255)
    distLbl.Font = Enum.Font.GothamBold
    distLbl.TextSize = 10
    distLbl.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Name = "_OrbitESPHighlight"
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char

    ORBIT.ESP.Tags[player] = { bb = bb, hl = hl, nameLbl = nameLbl, distLbl = distLbl }
end

local function removeESPTag(player)
    local data = ORBIT.ESP.Tags[player]
    if not data then return end
    pcall(function() if data.bb then data.bb:Destroy() end end)
    pcall(function() if data.hl then data.hl:Destroy() end end)
    ORBIT.ESP.Tags[player] = nil
end
ORBIT.removeESPTag = removeESPTag

local function updateESP()
    if not ORBIT.ESP.Enabled then return end
    local now = tick()
    if now - ORBIT.ESP.LastUpdate < ORBIT.ESP.UpdateInterval then return end
    ORBIT.ESP.LastUpdate = now
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local myPos = myHrp.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if char and hrp then
            if not ORBIT.ESP.Tags[player] then makeESPTag(player) end
            local data = ORBIT.ESP.Tags[player]
            if data then
                local dist = (hrp.Position - myPos).Magnitude
                local visible = dist <= ORBIT.ESP.MaxDistance
                if data.bb then data.bb.Enabled = visible end
                if data.hl then data.hl.Enabled = visible end
                if visible and data.distLbl then data.distLbl.Text = math.floor(dist) .. " st" end
            end
        else
            removeESPTag(player)
        end
    end
    for p in pairs(ORBIT.ESP.Tags) do
        if not p.Parent or not p.Character then removeESPTag(p) end
    end
end
ORBIT.updateESP = updateESP

function ORBIT.setESPEnabled(state)
    ORBIT.ESP.Enabled = state
    if not state then
        for p in pairs(ORBIT.ESP.Tags) do removeESPTag(p) end
    end
    if ORBIT.notify then
        ORBIT.notify("ESP: " .. (state and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(180, 220, 255), 2)
    end
end

-- ==================== ФЕЙЕРВЕРК ====================
local function spawnFireworks(position, color3)
    if not ORBIT.fireworkFolder then
        ORBIT.fireworkFolder = Instance.new("Folder")
        ORBIT.fireworkFolder.Name = "OrbitFireworks"
        ORBIT.fireworkFolder.Parent = Workspace
    end
    local part = Instance.new("Part")
    part.Name = "Firework"; part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Transparency = 1; part.Anchored = true; part.CanCollide = false
    part.CanQuery = false; part.CanTouch = false
    part.CFrame = CFrame.new(position); part.Parent = ORBIT.fireworkFolder
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 0
    pe.Lifetime = NumberRange.new(0.8, 1.5)
    pe.Speed = NumberRange.new(15, 30)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    pe.Color = ColorSequence.new(color3)
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = part
    pe:Emit(40)
    task.delay(2, function() pcall(function() part:Destroy() end) end)
end
ORBIT.spawnFireworks = spawnFireworks

-- ==================== МЕТКА ЧИТЕРА ====================
ORBIT.taggedPlayers = ORBIT.taggedPlayers or {}
if not getgenv().ORBIT_CHEATERS then getgenv().ORBIT_CHEATERS = {} end

function ORBIT.getTaggedPlayers()
    local list = {}
    for p in pairs(ORBIT.taggedPlayers) do
        if p and p.Parent then table.insert(list, p) end
    end
    return list
end

function ORBIT.tagCheater(player, enable)
    if not player or player == LocalPlayer then return false end
    if enable then
        ORBIT.taggedPlayers[player] = true
        getgenv().ORBIT_CHEATERS[player.UserId] = {
            name = player.Name, time = os.time(), reason = "manual",
        }
        ORBIT.addSession("cheatersTagged")
        warn("[Orbit v23.3] Помечен: " .. player.Name)
        if ORBIT.notify then ORBIT.notify("Помечен: " .. player.Name, Color3.fromRGB(255, 120, 120)) end
        if ORBIT.ESP and ORBIT.ESP.Enabled and ORBIT.ESP.Tags[player] then
            removeESPTag(player); task.wait(0.1); makeESPTag(player)
        end
    else
        ORBIT.taggedPlayers[player] = nil
        if getgenv().ORBIT_CHEATERS then getgenv().ORBIT_CHEATERS[player.UserId] = nil end
        if ORBIT.ESP and ORBIT.ESP.Enabled and ORBIT.ESP.Tags[player] then
            removeESPTag(player); task.wait(0.1); makeESPTag(player)
        end
    end
    return true
end
function ORBIT.toggleTagCheater(player)
    return ORBIT.tagCheater(player, not ORBIT.taggedPlayers[player])
end
function ORBIT.isTagged(player) return ORBIT.taggedPlayers[player] == true end
function ORBIT.clearAllTags()
    for p in pairs(ORBIT.taggedPlayers) do ORBIT.tagCheater(p, false) end
end

-- ============================================================
--       ПОЛНОЕ КОПИРОВАНИЕ НА ЧУЖИХ
-- ============================================================
ORBIT.targetRings = ORBIT.targetRings or {}

local function attachTrail(refPart, span, color, length, width)
    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(-span,0,0); a0.Parent = refPart
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(span,0,0); a1.Parent = refPart
    local trail = Instance.new("Trail")
    trail.Attachment0 = a0; trail.Attachment1 = a1
    trail.Color = ColorSequence.new(color)
    trail.Lifetime = length
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, width), NumberSequenceKeypoint.new(1, 0),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1),
    })
    trail.Parent = refPart
    return trail
end

function ORBIT.buildTargetRings(player, slot)
    if ORBIT.targetRings[player] then
        pcall(function() ORBIT.targetRings[player].folder:Destroy() end)
        ORBIT.targetRings[player] = nil
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local rootFolder = Instance.new("Folder")
    rootFolder.Name = "TargetFull_" .. tostring(math.random(1, 999999))
    rootFolder.Parent = Workspace

    local ringData = {}
    for ri = 1, 5 do
        if rings[ri].enabled then
            local shape = SHAPE_PRESETS[rings[ri].shapeIndex] or SHAPE_PRESETS[1]
            local size = ORBIT.getCurrentShapeSize()
            local ringFolder = Instance.new("Folder")
            ringFolder.Name = "Ring_" .. ri
            ringFolder.Parent = rootFolder
            local blocks = {}
            for i = 1, SETTINGS.BlockCount do
                local data = shape.create(size, "TR_" .. ri .. "_" .. i, i)
                local refPart = data.part
                local visualSize = data.visualSize or size
                if not data.isModel then
                    refPart.Material = SETTINGS.Material
                    refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
                    refPart.CanQuery = false; refPart.CanTouch = false
                    refPart.Transparency = SETTINGS.Transparency
                    refPart.Color = SETTINGS.FixedColor
                end
                if data.bodyParts then
                    for _, bp in ipairs(data.bodyParts) do
                        pcall(function()
                            bp.Transparency = SETTINGS.Transparency
                            bp.CanQuery = false; bp.CanTouch = false
                        end)
                    end
                end
                if data.isModel then data.model.Parent = ringFolder else refPart.Parent = ringFolder end
                local trail = nil
                if SETTINGS.TrailEnabled then
                    trail = attachTrail(refPart, visualSize*0.35, SETTINGS.FixedColor,
                        SETTINGS.TrailLength, SETTINGS.TrailWidth)
                end
                table.insert(blocks, {
                    part = refPart, model = data.model, isModel = data.isModel or false,
                    bodyParts = data.bodyParts, trail = trail,
                    angleOffset = (i-1)*(360/SETTINGS.BlockCount) + rings[ri].angleShift,
                    index = i,
                })
            end
            table.insert(ringData, { ri = ri, folder = ringFolder, blocks = blocks, angle = 0 })
        end
    end

    local auraData = nil
    if SETTINGS.AuraEnabled then
        local auraFolder = Instance.new("Folder")
        auraFolder.Name = "Aura"
        auraFolder.Parent = rootFolder
        local auraRing = nil
        if SETTINGS.AuraRing then
            auraRing = Instance.new("Part")
            auraRing.Name = "AuraRing"
            auraRing.Shape = Enum.PartType.Cylinder
            auraRing.Size = Vector3.new(SETTINGS.AuraThickness, SETTINGS.AuraSize*2, SETTINGS.AuraSize*2)
            auraRing.Anchored = true; auraRing.CanCollide = false; auraRing.CastShadow = false
            auraRing.CanQuery = false; auraRing.CanTouch = false
            auraRing.Material = Enum.Material.Neon
            auraRing.Color = SETTINGS.AuraColor
            auraRing.Transparency = 0.3
            auraRing.Parent = auraFolder
        end
        local auraEmitter = nil
        if SETTINGS.AuraParticles then
            auraEmitter = Instance.new("Part")
            auraEmitter.Name = "AuraEmitter"
            auraEmitter.Size = Vector3.new(0.1,0.1,0.1); auraEmitter.Transparency = 1
            auraEmitter.Anchored = true; auraEmitter.CanCollide = false; auraEmitter.CastShadow = false
            auraEmitter.CanQuery = false; auraEmitter.CanTouch = false
            auraEmitter.Parent = auraFolder
            for _, cfg in ipairs({
                { rate=100, life={1.0,2.0}, spd={3,6}, spread=Vector2.new(180,180), size={0.4,0.7,0.2} },
                { rate=70,  life={0.6,1.2}, spd={5,9}, spread=Vector2.new(20,20),   size={0.5,0.5,0.5} },
            }) do
                local pe = Instance.new("ParticleEmitter")
                pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                pe.Rate = cfg.rate
                pe.Lifetime = NumberRange.new(cfg.life[1], cfg.life[2])
                pe.Speed = NumberRange.new(cfg.spd[1], cfg.spd[2])
                pe.SpreadAngle = cfg.spread
                pe.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, cfg.size[1]),
                    NumberSequenceKeypoint.new(0.5, cfg.size[2]),
                    NumberSequenceKeypoint.new(1, cfg.size[3]),
                })
                pe.Color = ColorSequence.new(SETTINGS.AuraColor)
                pe.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.1),
                    NumberSequenceKeypoint.new(1, 1),
                })
                pe.Parent = auraEmitter
            end
        end
        local auraBlocks = {}
        if SETTINGS.AuraShapes then
            local shape = SHAPE_PRESETS[ORBIT.auraShapeIndex] or SHAPE_PRESETS[1]
            local size = ORBIT.getCurrentShapeSize() * SETTINGS.AuraShapeScale
            local count = math.max(4, math.floor(SETTINGS.BlockCount * 0.75))
            for i = 1, count do
                local data = shape.create(size, "TA_" .. i)
                local refPart = data.part
                if not data.isModel then
                    refPart.Material = SETTINGS.Material
                    refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
                    refPart.CanQuery = false; refPart.CanTouch = false
                    refPart.Transparency = SETTINGS.Transparency
                    refPart.Color = SETTINGS.AuraColor
                end
                if data.isModel then data.model.Parent = auraFolder else refPart.Parent = auraFolder end
                local trail = nil
                if SETTINGS.AuraTrailEnabled then
                    local span = (data.visualSize or size) * 0.35
                    trail = attachTrail(refPart, span, SETTINGS.AuraColor,
                        SETTINGS.AuraTrailLength, SETTINGS.AuraTrailWidth)
                end
                table.insert(auraBlocks, {
                    part = refPart, model = data.model, isModel = data.isModel or false,
                    bodyParts = data.bodyParts, index = i, total = count, trail = trail,
                })
            end
        end
        auraData = {
            folder = auraFolder, ring = auraRing, emitter = auraEmitter,
            blocks = auraBlocks, angle = 0, spinAngle = 0,
        }
    end

    ORBIT.targetRings[player] = { folder = rootFolder, rings = ringData, aura = auraData }
end

function ORBIT.removeTargetRings(player)
    if ORBIT.targetRings[player] then
        pcall(function() ORBIT.targetRings[player].folder:Destroy() end)
        ORBIT.targetRings[player] = nil
    end
end

function ORBIT.addRingsToAll()
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then ORBIT.buildTargetRings(player); count = count + 1 end
    end
    ORBIT.notify("Кольца навешаны на " .. count .. " игроков", Color3.fromRGB(160, 255, 160), 2)
end
function ORBIT.removeRingsFromAll()
    local count = 0
    for player in pairs(ORBIT.targetRings) do ORBIT.removeTargetRings(player); count = count + 1 end
    ORBIT.notify("Убрано у всех (" .. count .. ")", Color3.fromRGB(255, 160, 160), 2)
end
function ORBIT.toggleAllRings()
    local any = false
    for _ in pairs(ORBIT.targetRings) do any = true; break end
    if any then ORBIT.removeRingsFromAll() else ORBIT.addRingsToAll() end
end
function ORBIT.toggleTargetRings(player)
    if ORBIT.targetRings[player] then
        ORBIT.removeTargetRings(player)
        ORBIT.notify("Убрано у " .. player.Name, Color3.fromRGB(255,150,150))
    else
        ORBIT.buildTargetRings(player)
        ORBIT.notify("Полное кольцо у " .. player.Name, Color3.fromRGB(200,150,255))
    end
end
function ORBIT.cleanupAllTargetRings()
    for p in pairs(ORBIT.targetRings) do ORBIT.removeTargetRings(p) end
end
function ORBIT.getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, {
                player = p, name = p.Name, displayName = p.DisplayName,
                hasRing = ORBIT.targetRings[p] ~= nil,
                isTagged = ORBIT.taggedPlayers[p] == true,
            })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function updateTargetRings(dt)
    local t = tick() - ORBIT.startTime
    local baseCol = SETTINGS.FixedColor
    if P.COLORS[P.colorIndex] and not P.COLORS[P.colorIndex].rainbow then
        baseCol = P.COLORS[P.colorIndex].c or baseCol
    end
    local now = tick()

    for player, data in pairs(ORBIT.targetRings) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        for _, rd in ipairs(data.rings) do
            local ring = rings[rd.ri]
            if not ring then continue end
            rd.angle = rd.angle + ORBIT.getTargetSpeed() * ring.speedMult * ring.direction * dt
            local radius = ORBIT.getTargetRadius(rd.ri)
            local height = ORBIT.getTargetHeight(rd.ri)
            local spinAngle = (ORBIT.spinAxisEnabled and not ORBIT.spinResetting) and (t*3) or 0
            local pattern = SETTINGS.OrbitPattern
            for _, b in ipairs(rd.blocks) do
                local ref = b.isModel and b.model or b.part
                if not ref or not ref.Parent then continue end
                local angle = math.rad(rd.angle + b.angleOffset)
                local px, py, pz = applyPattern(pattern, angle, radius, height, rd.ri)
                local targetCF
                if ORBIT.spinAxisDir == "X" then
                    targetCF = CFrame.new(hrp.Position + Vector3.new(px, py, pz)) * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle)*0.7, 0)
                else
                    targetCF = CFrame.new(hrp.Position + Vector3.new(px, py, pz)) * CFrame.Angles(0, math.rad(spinAngle), 0)
                end
                if b.isModel and b.model then b.model:PivotTo(targetCF) else b.part.CFrame = targetCF end
                local col = baseCol
                if SETTINGS.Rainbow then
                    col = Color3.fromHSV((t*SETTINGS.RainbowSpeed*SETTINGS.SpeedMultiplier + b.index/SETTINGS.BlockCount + ring.colorShift) % 1, 0.9, 1)
                elseif SETTINGS.GradientEnabled then
                    col = Color3.fromHSV((t*SETTINGS.GradientSpeed + b.index/SETTINGS.BlockCount) % 1, 0.85, 1)
                end
                if b.bodyParts then
                    for _, p in ipairs(b.bodyParts) do
                        if not p:GetAttribute("NoRecolor") then p.Color = col end
                    end
                elseif b.part then b.part.Color = col end
                if b.trail and (now - (b.lastTrailUpdate or 0)) > 0.1 then
                    b.trail.Color = ColorSequence.new(col)
                    b.lastTrailUpdate = now
                end
            end
        end

        if data.aura then
            local aura = data.aura
            local auraSpeed = SETTINGS.OrbitSpeed * SETTINGS.SpeedMultiplier * 0.7
                * SETTINGS.AuraSpeedMult * SETTINGS.AuraDirection
            aura.angle = aura.angle + auraSpeed * dt
            if SETTINGS.AuraSpinEnabled then
                aura.spinAngle = aura.spinAngle + SETTINGS.AuraSpinSpeed * SETTINGS.SpeedMultiplier * dt
            end
            if aura.ring then
                aura.ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
                aura.ring.Color = SETTINGS.AuraColor
            end
            if aura.emitter then
                aura.emitter.CFrame = hrp.CFrame
            end
            local radius = SETTINGS.AuraSize
            local height = SETTINGS.AuraHeight
            local pattern = SETTINGS.AuraPattern or "Круг"
            for _, b in ipairs(aura.blocks) do
                if not b.part.Parent then continue end
                local angle = math.rad(aura.angle + (b.index-1)*(360/b.total))
                local px, py, pz = applyPattern(pattern, angle, radius, height, b.index)
                local pos = hrp.Position + Vector3.new(px, py, pz)
                local cf
                if SETTINGS.AuraSpinEnabled then
                    if SETTINGS.AuraSpinAxis == "Y" then
                        cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0) * CFrame.Angles(0, math.rad(aura.spinAngle), 0)
                    else
                        cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0) * CFrame.Angles(math.rad(aura.spinAngle), 0, 0)
                    end
                else
                    cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
                end
                if b.isModel and b.model then b.model:PivotTo(cf) else b.part.CFrame = cf end
                local col = SETTINGS.AuraColor
                if P.COLORS[P.auraColorIndex].rainbow then
                    col = Color3.fromHSV((t*0.2 + b.index/b.total) % 1, 0.9, 1)
                end
                if b.bodyParts then
                    for _, p in ipairs(b.bodyParts) do
                        if not p:GetAttribute("NoRecolor") then p.Color = col end
                    end
                elseif b.part then b.part.Color = col end
            end
        end
    end
end

-- ============================================================
--       БОТЫ
-- ============================================================
ORBIT.bots = {}
ORBIT.botIdCounter = 0
ORBIT.botSettings = ORBIT.botSettings or {
    CollectRadius = 12, AutoCollect = true, BotRingRadius = 4, BotRingHeight = 2,
    BotRingBlockCount = 6, BotSpeed = 60, UseMySkin = false, BotYOffset = 1.5,
    ShowPlayerRing = false,
}
ORBIT.botAvatarTemplate = nil

local MAX_BOTS = 40
local LIGHT_SHAPES = {
    ["БЛОК"]=true, ["ШАР"]=true, ["ЦИЛИНДР"]=true, ["КЛИН"]=true, ["СЕРДЦЕ"]=true,
    ["ЗВЕЗДА"]=true, ["ТРЕУГОЛЬНИК"]=true, ["РОМБ"]=true, ["КРЕСТ"]=true,
    ["КОСТЬ"]=true, ["ПИРАМИДА"]=true,
}
local function pickBotShape()
    local heavyAllowed = ORBIT.getBotCount() < 10
    for _ = 1, 20 do
        local idx = math.random(1, #SHAPE_PRESETS)
        if heavyAllowed or LIGHT_SHAPES[SHAPE_PRESETS[idx].name] then return idx end
    end
    return 1
end

function ORBIT.getBotAvatarTemplate()
    if ORBIT.botAvatarTemplate then return ORBIT.botAvatarTemplate end
    local ok, template = pcall(function()
        local desc = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if ok and template then
        template.Name = "_OrbitBotAvatarTemplate"
        template.Parent = nil
        for _, obj in ipairs(template:GetDescendants()) do
            if obj:IsA("Animator") or obj:IsA("AnimationController") then
                pcall(function() obj:Destroy() end)
            end
        end
        ORBIT.botAvatarTemplate = template
        return template
    end
    return nil
end

local function findGroundY(x, z, fromY)
    local origin = Vector3.new(x, fromY + 10, z)
    local dir = Vector3.new(0, -100, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {LocalPlayer.Character}
    for _, b in pairs(ORBIT.bots) do
        if b.model then table.insert(ignore, b.model) end
    end
    params.FilterDescendantsInstances = ignore
    local result = Workspace:Raycast(origin, dir, params)
    if result then return result.Position.Y end
    return fromY
end

local function createDummyCharacter(position, useSkin)
    local groundY = findGroundY(position.X, position.Z, position.Y)
    local rootY = groundY + 1.5
    if useSkin then
        local template = ORBIT.getBotAvatarTemplate()
        if template then
            local ok, model = pcall(function() return template:Clone() end)
            if ok and model then
                model.Name = "OrbitBot_" .. tostring(math.random(1000, 999999))
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Anchored = true; part.CanCollide = false
                        part.CanQuery = false; part.CanTouch = false
                    end
                end
                local h0 = model:FindFirstChildOfClass("Humanoid")
                local r0 = model:FindFirstChild("HumanoidRootPart")
                local lift = (h0 and r0) and (h0.HipHeight + r0.Size.Y / 2) or 3
                pcall(function() model:PivotTo(CFrame.new(position.X, groundY + lift, position.Z)) end)
                local hum = model:FindFirstChildOfClass("Humanoid")
                if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
                model.Parent = Workspace
                return model
            end
        end
    end
    local model = Instance.new("Model")
    model.Name = "OrbitBot_" .. tostring(math.random(1000, 999999))
    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1); root.Transparency = 1
    root.Anchored = true; root.CanCollide = false
    root.CanQuery = false; root.CanTouch = false
    root.CFrame = CFrame.new(Vector3.new(position.X, rootY, position.Z))
    root.Parent = model; model.PrimaryPart = root
    local torso = Instance.new("Part")
    torso.Name = "Torso"; torso.Size = Vector3.new(2, 2, 1)
    torso.Anchored = true; torso.CanCollide = false
    torso.CanQuery = false; torso.CanTouch = false
    torso.Color = Color3.fromRGB(100, 150, 255); torso.Material = Enum.Material.Neon
    torso.CFrame = root.CFrame; torso.Parent = model
    local head = Instance.new("Part")
    head.Name = "Head"; head.Size = Vector3.new(1.5, 1.5, 1.5); head.Shape = Enum.PartType.Ball
    head.Anchored = true; head.CanCollide = false
    head.CanQuery = false; head.CanTouch = false
    head.Color = Color3.fromRGB(255, 200, 100); head.Material = Enum.Material.Neon
    head.CFrame = root.CFrame * CFrame.new(0, 2, 0)
    head.Parent = model
    local hum = Instance.new("Humanoid")
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    hum.Parent = model
    model.Parent = Workspace
    return model
end

local function buildBotPlayerRings(botRoot, botId)
    if not ORBIT.botSettings.ShowPlayerRing then return nil end
    local folder = Instance.new("Folder")
    folder.Name = "BotPlayerRing_" .. botId
    folder.Parent = Workspace
    local ringData = {}
    for ri = 1, 5 do
        if rings[ri].enabled then
            local shape = SHAPE_PRESETS[rings[ri].shapeIndex] or SHAPE_PRESETS[1]
            local size = ORBIT.getCurrentShapeSize()
            local ringFolder = Instance.new("Folder")
            ringFolder.Name = "Ring_" .. ri
            ringFolder.Parent = folder
            local blocks = {}
            for i = 1, SETTINGS.BlockCount do
                local data = shape.create(size, "BR_" .. ri .. "_" .. i, i)
                local refPart = data.part
                local visualSize = data.visualSize or size
                if not data.isModel then
                    refPart.Material = SETTINGS.Material
                    refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
                    refPart.CanQuery = false; refPart.CanTouch = false
                    refPart.Transparency = SETTINGS.Transparency
                    refPart.Color = SETTINGS.FixedColor
                end
                if data.isModel then data.model.Parent = ringFolder else refPart.Parent = ringFolder end
                local trail = nil
                if SETTINGS.TrailEnabled then
                    trail = attachTrail(refPart, visualSize*0.35, SETTINGS.FixedColor,
                        SETTINGS.TrailLength, SETTINGS.TrailWidth)
                end
                table.insert(blocks, {
                    part = refPart, model = data.model, isModel = data.isModel or false,
                    bodyParts = data.bodyParts, trail = trail,
                    angleOffset = (i-1)*(360/SETTINGS.BlockCount) + rings[ri].angleShift,
                    index = i,
                })
            end
            table.insert(ringData, { ri = ri, folder = ringFolder, blocks = blocks, angle = 0 })
        end
    end
    return { folder = folder, rings = ringData }
end

function ORBIT.createBot(shapeIndex, position, targetSlot)
    if ORBIT.getBotCount() >= MAX_BOTS then return nil end
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local basePos = position
    if not basePos then
        if myHrp then
            local angle = math.random() * math.pi * 2
            local dist = 8 + math.random() * 25
            basePos = myHrp.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
        else basePos = Vector3.new(0, 5, 0) end
    end
    shapeIndex = shapeIndex or pickBotShape()
    local model = createDummyCharacter(basePos, ORBIT.botSettings.UseMySkin)
    local folder = Instance.new("Folder")
    folder.Name = "BotRing_" .. tostring(math.random(1, 999999))
    folder.Parent = Workspace
    local shape = SHAPE_PRESETS[shapeIndex]
    local ringSize = ORBIT.getCurrentShapeSize() * (0.5 + math.random() * 0.8)
    local ringRadius = 3 + math.random() * 3
    local ringHeight = 1.5 + math.random() * 2
    local ringSpeed = 30 + math.random() * 120
    local hueBase = math.random()
    local blockCount = 4 + math.random(0, 4)
    local blocks = {}
    for i = 1, blockCount do
        local data = shape.create(ringSize, "Bot_R" .. i, i)
        local refPart = data.part
        if not data.isModel then
            refPart.Material = Enum.Material.Neon
            refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
            refPart.CanQuery = false; refPart.CanTouch = false
            refPart.Transparency = 0.1
            refPart.Color = Color3.fromHSV(hueBase, 0.85, 1)
        end
        if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
        table.insert(blocks, {
            part = refPart, model = data.model, isModel = data.isModel or false,
            bodyParts = data.bodyParts, index = i,
            angleOffset = (i - 1) * (360 / blockCount),
        })
    end
    local botId = ORBIT.botIdCounter + 1
    ORBIT.botIdCounter = botId

    local playerRingsData = nil
    local botRoot = model:FindFirstChild("HumanoidRootPart")
    if botRoot and ORBIT.botSettings.ShowPlayerRing then
        playerRingsData = buildBotPlayerRings(botRoot, botId)
    end

    ORBIT.bots[model] = {
        id = botId, model = model, shapeIndex = shapeIndex,
        folder = folder, blocks = blocks, angle = 0, collected = false,
        ringRadius = ringRadius, ringHeight = ringHeight, ringSpeed = ringSpeed,
        hueBase = hueBase, blockCount = blockCount, targetSlot = targetSlot or 2,
        playerRings = playerRingsData,
    }
    return model
end

function ORBIT.createBotNear(shapeIndex, offsetStuds, targetSlot)
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    offsetStuds = offsetStuds or 3
    local fwd = myHrp.CFrame.LookVector
    local pos = myHrp.Position + Vector3.new(fwd.X, 0, fwd.Z).Unit * offsetStuds
    return ORBIT.createBot(shapeIndex, pos, targetSlot)
end

function ORBIT.createMultipleBots(count, targetSlot)
    count = count or 5
    local indices = {}
    for i = 1, #SHAPE_PRESETS do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = math.random(1, i); indices[i], indices[j] = indices[j], indices[i]
    end
    for i = 1, math.min(count, #SHAPE_PRESETS) do
        ORBIT.createBot(indices[i], nil, targetSlot)
        task.wait(0.08)
    end
end

function ORBIT.createManyBots(count, targetSlot)
    count = math.clamp(tonumber(count) or 10, 1, MAX_BOTS)
    for i = 1, count do
        if not ORBIT.createBot(nil, nil, targetSlot) then
            if ORBIT.notify then
                ORBIT.notify("Лимит ботов: " .. MAX_BOTS, Color3.fromRGB(255, 200, 120), 2)
            end
            break
        end
        if i % 5 == 0 then task.wait(0.08) end
    end
end

function ORBIT.removeBot(botModel)
    local data = ORBIT.bots[botModel]
    if not data then return end
    pcall(function()
        if data.folder then data.folder:Destroy() end
        if data.playerRings and data.playerRings.folder then data.playerRings.folder:Destroy() end
        if data.model then data.model:Destroy() end
    end)
    ORBIT.bots[botModel] = nil
end

function ORBIT.removeAllBots()
    for m in pairs(ORBIT.bots) do ORBIT.removeBot(m) end
end

local function collectBotRing(botModel, data)
    if data.collected then return end
    data.collected = true
    local shapeName = SHAPE_PRESETS[data.shapeIndex] and SHAPE_PRESETS[data.shapeIndex].name or "?"
    local SLOT = math.clamp(data.targetSlot or 2, 1, 5)
    rings[SLOT].shapeIndex = data.shapeIndex
    if not rings[SLOT].enabled then
        ORBIT.setRingEnabled(SLOT, true)
    else
        ORBIT.destroyRing(SLOT); ORBIT.buildRing(SLOT); ORBIT.applyColor(); ORBIT.applyNameVisibility()
    end
    ORBIT.notify(shapeName .. " - кольцо " .. SLOT, Color3.fromRGB(255, 220, 100), 3)
    ORBIT.addSession("botsCollected")
    if ORBIT.playBotCollect then ORBIT.playBotCollect() end
    task.spawn(function()
        local botRoot = data.model and data.model:FindFirstChild("HumanoidRootPart")
        if botRoot and ORBIT.spawnFireworks then
            local c = Color3.fromHSV(data.hueBase or 0, 0.9, 1)
            ORBIT.spawnFireworks(botRoot.Position + Vector3.new(0, 3, 0), c)
        end
    end)
    task.spawn(function()
        for i = 1, 10 do
            for _, b in ipairs(data.blocks) do
                if b.isModel and b.model then pcall(function() b.model:ScaleTo(1 - i*0.09) end)
                elseif b.part then b.part.Transparency = b.part.Transparency + 0.09 end
            end
            task.wait(0.03)
        end
        ORBIT.removeBot(botModel)
    end)
end

local function updateBots(dt)
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local now = tick()
    local t = now - ORBIT.startTime

    for botModel, data in pairs(ORBIT.bots) do
        if data.collected then continue end
        if not data.model or not data.model.Parent then ORBIT.bots[botModel] = nil; continue end
        local botRoot = data.model:FindFirstChild("HumanoidRootPart")
        if not botRoot then continue end

        data.baseCF = data.baseCF or data.model:GetPivot()
        local dist = (botRoot.Position - myHrp.Position).Magnitude

        if dist < 250 then
            data.model:PivotTo(
                data.baseCF
                * CFrame.new(0, 0.4 + math.sin(t * 2 + data.id) * 0.3, 0)
                * CFrame.Angles(0, t * 1.2 + data.id, 0)
            )

            data.angle = data.angle + (data.ringSpeed or 60) * dt
            local radius = data.ringRadius or 4
            local height = data.ringHeight or 2
            local count = #data.blocks
            local doColor = (now - (data.lastColor or 0)) > 0.1
            if doColor then data.lastColor = now end

            for _, b in ipairs(data.blocks) do
                if not b.part or not b.part.Parent then continue end
                local angle = math.rad(data.angle + b.angleOffset)
                local pos = botRoot.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
                local cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
                if b.isModel and b.model then b.model:PivotTo(cf) else b.part.CFrame = cf end

                if doColor then
                    local c = Color3.fromHSV((data.hueBase + t * 0.15 + b.index / count) % 1, 0.85, 1)
                    if b.bodyParts then
                        for _, p in ipairs(b.bodyParts) do
                            if not p:GetAttribute("NoRecolor") then p.Color = c end
                        end
                    elseif b.part then
                        b.part.Color = c
                    end
                end
            end

            if data.playerRings then
                for _, rd in ipairs(data.playerRings.rings) do
                    local ring = rings[rd.ri]
                    if not ring then continue end
                    rd.angle = rd.angle + ORBIT.getTargetSpeed() * ring.speedMult * ring.direction * dt
                    local rRadius = ORBIT.getTargetRadius(rd.ri)
                    local rHeight = ORBIT.getTargetHeight(rd.ri)
                    local spinAngle = (ORBIT.spinAxisEnabled and not ORBIT.spinResetting) and (t*3) or 0
                    local pattern = SETTINGS.OrbitPattern
                    for _, b in ipairs(rd.blocks) do
                        local ref = b.isModel and b.model or b.part
                        if not ref or not ref.Parent then continue end
                        local angle = math.rad(rd.angle + b.angleOffset)
                        local px, py, pz = applyPattern(pattern, angle, rRadius, rHeight, rd.ri)
                        local targetCF
                        if ORBIT.spinAxisDir == "X" then
                            targetCF = CFrame.new(botRoot.Position + Vector3.new(px, py, pz)) * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle)*0.7, 0)
                        else
                            targetCF = CFrame.new(botRoot.Position + Vector3.new(px, py, pz)) * CFrame.Angles(0, math.rad(spinAngle), 0)
                        end
                        if b.isModel and b.model then b.model:PivotTo(targetCF) else b.part.CFrame = targetCF end
                        local col = SETTINGS.FixedColor
                        if SETTINGS.Rainbow then
                            col = Color3.fromHSV((t*SETTINGS.RainbowSpeed*SETTINGS.SpeedMultiplier + b.index/SETTINGS.BlockCount + ring.colorShift) % 1, 0.9, 1)
                        end
                        if b.bodyParts then
                            for _, p in ipairs(b.bodyParts) do
                                if not p:GetAttribute("NoRecolor") then p.Color = col end
                            end
                        elseif b.part then b.part.Color = col end
                        if b.trail and (now - (b.lastTrailUpdate or 0)) > 0.1 then
                            b.trail.Color = ColorSequence.new(col)
                            b.lastTrailUpdate = now
                        end
                    end
                end
            end
        end

        if ORBIT.botSettings.AutoCollect then
            local dx = myHrp.Position.X - botRoot.Position.X
            local dz = myHrp.Position.Z - botRoot.Position.Z
            local dist2 = math.sqrt(dx*dx + dz*dz)
            if dist2 < ORBIT.botSettings.CollectRadius then collectBotRing(botModel, data) end
        end
    end
end

function ORBIT.getBotCount()
    local n = 0
    for _ in pairs(ORBIT.bots) do n = n + 1 end
    return n
end

-- ============================================================
--       КОЛЬЦА (главные)
-- ============================================================
function ORBIT.applyTrailSettings(trail)
    if not trail then return end
    trail.Lifetime = SETTINGS.TrailLength
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, SETTINGS.TrailWidth), NumberSequenceKeypoint.new(1, 0),
    })
end

function ORBIT.refreshAllTrails()
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.trail then ORBIT.applyTrailSettings(data.trail) end
        end
    end
    for _, data in ipairs(ORBIT.auraBlocks or {}) do
        if data.trail then
            data.trail.Lifetime = SETTINGS.AuraTrailLength
            data.trail.WidthScale = NumberSequence.new({
                NumberSequenceKeypoint.new(0, SETTINGS.AuraTrailWidth),
                NumberSequenceKeypoint.new(1, 0),
            })
        end
    end
end

function ORBIT.countActiveLights()
    local count = 0
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.light and data.light.Parent then count = count + 1 end
        end
    end
    ORBIT.activeLightCount = count
end

function ORBIT.buildRing(ri)
    local ring = rings[ri]
    if not ring then return end
    if ring.folder then ring.folder:Destroy(); ring.folder = nil end
    ring.blocks = {}
    local folder = Instance.new("Folder")
    folder.Name = "OrbitRing_" .. ri .. "_" .. tostring(math.random(1, 999999))
    folder.Parent = Workspace
    ring.folder = folder
    local shape = SHAPE_PRESETS[ring.shapeIndex] or SHAPE_PRESETS[1]
    local size = ORBIT.getCurrentShapeSize()
    for i = 1, SETTINGS.BlockCount do
        local blockName = "R" .. ri .. "_S" .. i
        local data = shape.create(size, blockName, i)
        local refPart = data.part
        local visualSize = data.visualSize or size
        if not data.isModel then
            refPart.Material = SETTINGS.Material
            refPart.CanCollide = false; refPart.Anchored = true
            refPart.CastShadow = SETTINGS.CastShadow or false
            refPart.CanQuery = false; refPart.CanTouch = false
            refPart.Transparency = SETTINGS.Transparency
            refPart.Color = SETTINGS.FixedColor
        end
        if data.bodyParts then
            for _, bp in ipairs(data.bodyParts) do
                pcall(function()
                    bp.Transparency = SETTINGS.Transparency
                    bp.CanQuery = false; bp.CanTouch = false
                end)
            end
        end
        if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
        local light = nil
        if SETTINGS.LightEnabled and ORBIT.activeLightCount < SETTINGS.LightLimit then
            light = Instance.new("PointLight")
            light.Name = blockName .. "_Light"
            light.Color = SETTINGS.FixedColor
            light.Range = SETTINGS.LightRange
            light.Brightness = SETTINGS.GlowIntensity or 1
            light.Parent = refPart
            ORBIT.activeLightCount = ORBIT.activeLightCount + 1
        end
        local trail = nil
        if SETTINGS.TrailEnabled then
            trail = attachTrail(refPart, visualSize*0.35, SETTINGS.FixedColor,
                SETTINGS.TrailLength, SETTINGS.TrailWidth)
        end
        local nameGui = Instance.new("BillboardGui")
        nameGui.Size = UDim2.new(0, 140, 0, 30)
        nameGui.StudsOffset = Vector3.new(0, visualSize*0.9 + 1, 0)
        nameGui.AlwaysOnTop = true; nameGui.LightInfluence = 0
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
            angleOffset = (i-1)*(360/SETTINGS.BlockCount) + ring.angleShift,
        })
    end
    statsData.totalShapes = statsData.totalShapes + #ring.blocks
end

function ORBIT.destroyRing(ri)
    local ring = rings[ri]
    if not ring then return end
    if ring.folder then ring.folder:Destroy(); ring.folder = nil end
    ring.blocks = {}
end
function ORBIT.applyColorToBlock(data, c)
    if data.light then data.light.Color = c end
    if data.bodyParts then
        for _, p in ipairs(data.bodyParts) do
            if not p:GetAttribute("NoRecolor") then p.Color = c end
        end
    elseif data.part then data.part.Color = c end
    if data.trail then data.trail.Color = ColorSequence.new(c) end
end
function ORBIT.applyColor()
    local p = P.COLORS[P.colorIndex]
    if p.rainbow then SETTINGS.Rainbow = true
    else
        SETTINGS.Rainbow = false
        SETTINGS.FixedColor = p.c
        for _, ring in pairs(rings) do
            for _, data in ipairs(ring.blocks) do
                ORBIT.applyColorToBlock(data, SETTINGS.FixedColor)
            end
        end
    end
end
function ORBIT.applyNameVisibility()
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.nameGui then data.nameGui.Enabled = SETTINGS.ShowBlockNames end
        end
    end
end
function ORBIT.rebuildAllRings()
    if not ORBIT.enabled then return end
    statsData.totalShapes = 0
    for ri, ring in pairs(rings) do
        if ring.enabled then ORBIT.destroyRing(ri) end
    end
    ORBIT.countActiveLights()
    for ri, ring in pairs(rings) do
        if ring.enabled then ORBIT.buildRing(ri) end
    end
    ORBIT.applyColor()
    ORBIT.applyNameVisibility()
end

function ORBIT.setEnabled(state)
    ORBIT.enabled = state
    if state then
        ORBIT.countActiveLights()
        for ri, ring in pairs(rings) do
            if ring.enabled then ORBIT.buildRing(ri) end
        end
        ORBIT.applyColor(); ORBIT.applyNameVisibility()
        ORBIT.startUpdateLoop()
        ORBIT.notify("Скрипт включён", Color3.fromRGB(100,255,150))
    else
        ORBIT.stopUpdateLoop()
        for ri in pairs(rings) do ORBIT.destroyRing(ri) end
        ORBIT.activeLightCount = 0
        if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
        if ORBIT.fireFolder then ORBIT.fireFolder:Destroy(); ORBIT.fireFolder = nil end
        ORBIT.cleanupAllTargetRings()
        ORBIT.removeAllBots()
        if ORBIT.ESP and ORBIT.ESP.Enabled then ORBIT.setESPEnabled(false) end
        ORBIT.notify("Скрипт выключен", Color3.fromRGB(255,100,100))
    end
end

function ORBIT.setRingEnabled(ri, state)
    local ring = rings[ri]
    if not ring then return end
    ring.enabled = state
    if not ORBIT.enabled then return end
    if state then ORBIT.countActiveLights(); ORBIT.buildRing(ri); ORBIT.applyColor(); ORBIT.applyNameVisibility()
    else ORBIT.destroyRing(ri); ORBIT.countActiveLights() end
end

function ORBIT.applyDirectionPreset()
    local preset = P.DIRECTION[P.directionIndex]
    for ri = 1, 5 do rings[ri].direction = preset.dirs[ri] end
end
function ORBIT.applySpeedModePreset()
    local preset = P.SPEED_MODE[P.speedModeIndex]
    for ri = 1, 5 do rings[ri].speedMult = preset.mults[ri] end
end
function ORBIT.applyShapes()
    if P.formModeIndex == 1 then
        for ri = 1, 5 do rings[ri].shapeIndex = ORBIT.shapeIndex end
    else
        for ri = 1, 5 do rings[ri].shapeIndex = ((ORBIT.shapeIndex+ri-2) % #SHAPE_PRESETS) + 1 end
    end
end

-- ============================================================
--       МГНОВЕННЫЙ CLEANUP ПРИ СМЕРТИ
-- ============================================================
local function cleanupOnDeath()
    for ri in pairs(rings) do
        pcall(ORBIT.destroyRing, ri)
    end
    if ORBIT.auraFolder then pcall(function() ORBIT.auraFolder:Destroy() end); ORBIT.auraFolder = nil end
    if ORBIT.fireFolder then pcall(function() ORBIT.fireFolder:Destroy() end); ORBIT.fireFolder = nil end
    ORBIT.activeLightCount = 0
    warn("[Orbit] Смерть - все элементы убраны мгновенно")
end

function ORBIT.setupRespawnHook()
    local function hookCurrentChar(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Died:Connect(function() cleanupOnDeath() end)
        else
            char.ChildAdded:Connect(function(child)
                if child:IsA("Humanoid") then
                    child.Died:Connect(function() cleanupOnDeath() end)
                end
            end)
        end
    end

    if LocalPlayer.Character then hookCurrentChar(LocalPlayer.Character) end

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        hookCurrentChar(newChar)
        task.wait(0.5)
        if ORBIT.enabled then
            for ri, ring in pairs(rings) do
                if ring.enabled then ORBIT.destroyRing(ri) end
            end
            ORBIT.countActiveLights()
            for ri, ring in pairs(rings) do
                if ring.enabled then ORBIT.buildRing(ri) end
            end
            ORBIT.applyColor(); ORBIT.applyNameVisibility()
            ORBIT.setupAura()
            ORBIT.setupFire()
        end
    end)
end

-- ============================================================
--       ПРОИЗВОДИТЕЛЬНОСТЬ
-- ============================================================
local PERFORMANCE = {
    Enabled = true, Level = "auto", CurrentLevel = "high",
    LastCheck = 0, CheckInterval = 3.0,
    FPS_HIGH = 50, FPS_MEDIUM = 35, FPS_LOW = 22,
    MobileAuto = true, Snapshot = nil,
}
local function perfSnapshot()
    PERFORMANCE.Snapshot = {
        LightEnabled = SETTINGS.LightEnabled, TrailEnabled = SETTINGS.TrailEnabled,
        AuraTrailEnabled = SETTINGS.AuraTrailEnabled, BlockCount = SETTINGS.BlockCount,
    }
end
local function perfRestore()
    if not PERFORMANCE.Snapshot then return end
    for k, v in pairs(PERFORMANCE.Snapshot) do SETTINGS[k] = v end
end
local function setLightsEnabled(on)
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.light then data.light.Enabled = on end
        end
    end
end
local function setTrailsEnabled(on)
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.trail then data.trail.Enabled = on end
        end
    end
end
local function setAuraTrailsEnabled(on)
    for _, data in ipairs(ORBIT.auraBlocks or {}) do
        if data.trail then data.trail.Enabled = on end
    end
end
local function applyPerformanceLevel(level)
    if PERFORMANCE.CurrentLevel == level then return end
    PERFORMANCE.CurrentLevel = level
    if level == "high" then
        perfRestore(); setLightsEnabled(SETTINGS.LightEnabled)
        setTrailsEnabled(SETTINGS.TrailEnabled); setAuraTrailsEnabled(SETTINGS.AuraTrailEnabled)
    elseif level == "medium" then
        setLightsEnabled(false); setTrailsEnabled(true); setAuraTrailsEnabled(SETTINGS.AuraTrailEnabled)
    elseif level == "low" then
        setLightsEnabled(false); setTrailsEnabled(false); setAuraTrailsEnabled(false)
    elseif level == "minimal" then
        setLightsEnabled(false); setTrailsEnabled(false); setAuraTrailsEnabled(false)
    end
    if ORBIT.notify then ORBIT.notify("Качество: " .. level:upper(), Color3.fromRGB(180, 220, 255), 1.5) end
end
function ORBIT.setPerformanceMode(mode)
    if mode == "off" then
        PERFORMANCE.Enabled = false; PERFORMANCE.Level = "high"; applyPerformanceLevel("high")
    else
        PERFORMANCE.Enabled = true; PERFORMANCE.Level = mode
        if mode ~= "auto" then applyPerformanceLevel(mode) end
    end
    return PERFORMANCE.Level
end
function ORBIT.getPerformanceInfo()
    return { Enabled = PERFORMANCE.Enabled, Mode = PERFORMANCE.Level,
        Current = PERFORMANCE.CurrentLevel, FPS = ORBIT.statsData and ORBIT.statsData.lastFPS or 60 }
end
task.spawn(function()
    task.wait(1.5); perfSnapshot()
    if PERFORMANCE.MobileAuto and ORBIT.PLATFORM == "mobile" and PERFORMANCE.Enabled and PERFORMANCE.Level == "auto" then
        applyPerformanceLevel("medium")
    end
end)
task.spawn(function()
    while task.wait(0.5) do
        if not ORBIT.enabled then break end
        if PERFORMANCE.Enabled and PERFORMANCE.Level == "auto" then
            local now = tick()
            if now - PERFORMANCE.LastCheck > PERFORMANCE.CheckInterval then
                PERFORMANCE.LastCheck = now
                local fps = ORBIT.statsData and ORBIT.statsData.lastFPS or 60
                local newLevel = PERFORMANCE.CurrentLevel
                if fps >= PERFORMANCE.FPS_HIGH then newLevel = "high"
                elseif fps >= PERFORMANCE.FPS_MEDIUM then newLevel = "medium"
                elseif fps >= PERFORMANCE.FPS_LOW then newLevel = "low"
                else newLevel = "minimal" end
                if newLevel ~= PERFORMANCE.CurrentLevel then applyPerformanceLevel(newLevel) end
            end
        end
    end
end)

-- ==================== ГЛАВНЫЙ ЦИКЛ ====================
function ORBIT.startUpdateLoop()
    if ORBIT.updateConn then return end
    ORBIT.startTime = tick()
    ORBIT.updateConn = RunService.Heartbeat:Connect(function(dt)
        if not ORBIT.enabled then return end
        local character = LocalPlayer.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local t = tick() - ORBIT.startTime
        local globalMult = SETTINGS.SpeedMultiplier
        local lerpFactor = math.clamp(dt * SETTINGS.LerpSpeed, 0, 1)
        local baseSize = ORBIT.getCurrentShapeSize()

        statsData.fpsFrames = statsData.fpsFrames + 1
        if t - statsData.fpsLastCheck >= 1 then
            statsData.lastFPS = math.floor(statsData.fpsFrames / (t - statsData.fpsLastCheck))
            statsData.fpsFrames = 0; statsData.fpsLastCheck = t
        end
        statsData.sessionTime = t
        ORBIT.SESSION.sessionTime = t

        updateAura(dt); updateFire(); updateBots(dt); updateTargetRings(dt)
        pcall(updateESP)

        if SETTINGS.AutoShapeSwap and (tick() - ORBIT.lastAutoSwap) > SETTINGS.AutoShapeSwapInterval then
            ORBIT.lastAutoSwap = tick()
            ORBIT.currentAutoShapeIndex = ORBIT.currentAutoShapeIndex + 1
            if ORBIT.currentAutoShapeIndex > #SHAPE_PRESETS then ORBIT.currentAutoShapeIndex = 1 end
            ORBIT.shapeIndex = ORBIT.currentAutoShapeIndex
            ORBIT.applyShapes(); ORBIT.rebuildAllRings()
        end

        for ri, ring in pairs(rings) do
            ORBIT.currentRadius[ri] = ORBIT.currentRadius[ri] + (ORBIT.getTargetRadius(ri) - ORBIT.currentRadius[ri]) * lerpFactor
            ORBIT.currentHeight[ri] = ORBIT.currentHeight[ri] + (ORBIT.getTargetHeight(ri) - ORBIT.currentHeight[ri]) * lerpFactor
            ORBIT.currentSpeed[ri] = ORBIT.currentSpeed[ri] + (ORBIT.getTargetSpeed()*ring.speedMult*ring.direction - ORBIT.currentSpeed[ri]) * lerpFactor
            ORBIT.currentSpin[ri] = ORBIT.currentSpin[ri] + (ORBIT.getTargetSpin()*ring.speedMult*ring.direction - ORBIT.currentSpin[ri]) * lerpFactor
            ORBIT.currentOrbitAngle[ri] = ORBIT.currentOrbitAngle[ri] + ORBIT.currentSpeed[ri] * dt
            ORBIT.currentBobPhase[ri] = ORBIT.currentBobPhase[ri] + 2*(globalMult*ring.speedMult)*dt
            if ORBIT.spinResetting then
                local bl = math.clamp(dt*3.0, 0, 1)
                ORBIT.currentSpinAngle[ri] = ORBIT.currentSpinAngle[ri] + (0 - ORBIT.currentSpinAngle[ri]) * bl
                if math.abs(ORBIT.currentSpinAngle[ri]) < 0.01 then ORBIT.currentSpinAngle[ri] = 0 end
            elseif ORBIT.spinAxisEnabled then
                ORBIT.currentSpinAngle[ri] = ORBIT.currentSpinAngle[ri] + ORBIT.currentSpin[ri] * dt
            end
        end

        local explosionMul = 1.0
        if SETTINGS.ExplosionEnabled then
            local phase = (t * SETTINGS.ExplosionSpeed) % 1
            explosionMul = 1 + math.sin(phase*math.pi*2)*SETTINGS.ExplosionPower
        end
        local now = tick()

        for ri, ring in pairs(rings) do
            if not ring.enabled then continue end
            local radius = ORBIT.currentRadius[ri] * explosionMul
            local height = ORBIT.currentHeight[ri]
            local orbitAngle = ORBIT.currentOrbitAngle[ri]
            local spinAngle = ORBIT.currentSpinAngle[ri]
            local bobPhase = ORBIT.currentBobPhase[ri]
            local pattern = SETTINGS.OrbitPattern
            for i, data in ipairs(ring.blocks) do
                if not data.part.Parent then continue end
                local angle = math.rad(orbitAngle + data.angleOffset)
                local yBob
                if SETTINGS.WaveEnabled then
                    yBob = math.sin(t*SETTINGS.WaveSpeed - (angle + orbitAngle*0.002)*SETTINGS.WaveLength) * SETTINGS.WaveAmplitude
                else
                    yBob = math.sin(bobPhase + i + ri*0.5) * SETTINGS.BobAmplitude
                end
                local px, py, pz = applyPattern(pattern, angle, radius, height + yBob, ri)
                local offset = Vector3.new(px, py, pz)
                local targetCF
                if ORBIT.spinAxisDir == "X" then
                    targetCF = CFrame.new(root.Position + offset) * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle)*0.7, 0)
                else
                    targetCF = CFrame.new(root.Position + offset) * CFrame.Angles(0, math.rad(spinAngle), 0)
                end
                if data.isModel and data.model then data.model:PivotTo(targetCF) else data.part.CFrame = targetCF end
                local ps = 1.0
                if SETTINGS.PulseEnabled then
                    ps = 1.0 + math.sin(t*SETTINGS.PulseSpeed + i + ri)*SETTINGS.PulseAmplitude
                end
                if data.isModel and data.model then
                    local tgt = SETTINGS.PulseEnabled and ps or 1
                    local cur = data.model:GetAttribute("Scale") or 1
                    if math.abs(cur - tgt) > 0.005 then data.model:ScaleTo(tgt); data.model:SetAttribute("Scale", tgt) end
                elseif data.part then
                    local sz = baseSize * ps
                    if math.abs(data.part.Size.X - sz) > 0.001 then data.part.Size = Vector3.new(sz, sz, sz) end
                end
                if SETTINGS.Rainbow then
                    local hue = (t*SETTINGS.RainbowSpeed*globalMult*ring.speedMult + i/SETTINGS.BlockCount + ring.colorShift) % 1
                    local c = Color3.fromHSV(hue, 0.9, 1)
                    ORBIT.applyColorToBlock(data, c)
                    if data.trail and (now - data.lastTrailUpdate) > 0.1 then
                        data.trail.Color = ColorSequence.new(c); data.lastTrailUpdate = now
                    end
                elseif SETTINGS.GradientEnabled then
                    local hue = (t*SETTINGS.GradientSpeed + i/SETTINGS.BlockCount) % 1
                    ORBIT.applyColorToBlock(data, Color3.fromHSV(hue, 0.85, 1))
                end
            end
        end
    end)
end

function ORBIT.stopUpdateLoop()
    if ORBIT.updateConn then ORBIT.updateConn:Disconnect(); ORBIT.updateConn = nil end
end

-- ==================== СОХРАНЕНИЯ ====================
local SAVED_DATA = nil
local function enc(v)
    if type(v) == "table" then
        local o = {}; for k, x in pairs(v) do o[k] = enc(x) end; return o
    elseif typeof(v) == "Color3" then return {__t="c3", R=v.R, G=v.G, B=v.B}
    elseif typeof(v) == "Vector3" then return {__t="v3", X=v.X, Y=v.Y, Z=v.Z}
    else return v end
end
local function dec(v)
    if type(v) == "table" then
        if v.__t == "c3" then return Color3.new(v.R, v.G, v.B) end
        if v.__t == "v3" then return Vector3.new(v.X, v.Y, v.Z) end
        local o = {}; for k, x in pairs(v) do o[k] = dec(x) end; return o
    end
    return v
end

local function collectSaveData()
    local rs, re = {}, {}
    for ri = 1, 5 do rs[ri] = rings[ri].shapeIndex; re[ri] = rings[ri].enabled end
    return {
        spreadIndex=P.spreadIndex, speedIndex=P.speedIndex, orbitIndex=P.orbitIndex,
        shapeSizeIndex=P.shapeSizeIndex, colorIndex=P.colorIndex,
        trailLengthIndex=P.trailLengthIndex, trailWidthIndex=P.trailWidthIndex,
        directionIndex=P.directionIndex, speedModeIndex=P.speedModeIndex,
        heightIndex=P.heightIndex, shapeIndex=ORBIT.shapeIndex, formModeIndex=P.formModeIndex,
        orbitPatternIndex=P.orbitPatternIndex, auraColorIndex=P.auraColorIndex,
        auraShapeIndex=ORBIT.auraShapeIndex, shapeCategoryIndex=P.shapeCategoryIndex,
        ringShapes=rs, ringEnabled=re,
        lightEnabled=SETTINGS.LightEnabled, trailEnabled=SETTINGS.TrailEnabled,
        pulseEnabled=SETTINGS.PulseEnabled, showNames=SETTINGS.ShowBlockNames,
        waveEnabled=SETTINGS.WaveEnabled, explosionEnabled=SETTINGS.ExplosionEnabled,
        auraEnabled=SETTINGS.AuraEnabled, auraSizeIndex=P.auraSizeIndex,
        auraThickIndex=P.auraThickIndex, auraHeightIndex=P.auraHeightIndex,
        auraShapeScaleIndex=P.auraShapeScaleIndex,
        auraTrailEnabled=SETTINGS.AuraTrailEnabled,
        auraTrailLengthIndex=P.auraTrailLengthIndex,
        auraTrailWidthIndex=P.auraTrailWidthIndex,
        auraPatternIndex=P.auraPatternIndex,
        auraSpinEnabled=SETTINGS.AuraSpinEnabled, auraSpinAxis=SETTINGS.AuraSpinAxis,
        auraSpinSpeedIndex=P.auraSpinSpeedIndex, auraPulseEnabled=SETTINGS.AuraPulseEnabled,
        auraSpeedIndex=P.auraSpeedIndex, auraDirIndex=P.auraDirIndex,
        auraLightEnabled=SETTINGS.AuraLightEnabled,
        auraLightRange=SETTINGS.AuraLightRange,
        auraLightBrightness=SETTINGS.AuraLightBrightness,
        fireEnabled=SETTINGS.FireEnabled, fireSizeIndex=P.fireSizeIndex, fireHeatIndex=P.fireHeatIndex,
        rainbowSpeed=SETTINGS.RainbowSpeed,
        autoShapeSwap=SETTINGS.AutoShapeSwap, autoShapeSwapInterval=SETTINGS.AutoShapeSwapInterval,
        gradientEnabled=SETTINGS.GradientEnabled,
        spinResetting=ORBIT.spinResetting, spinAxisEnabled=ORBIT.spinAxisEnabled, spinAxisDir=ORBIT.spinAxisDir,
        spinSpeedIndex=P.spinSpeedIndex, heartScale=SETTINGS.HeartScale,
        musicEnabled=ORBIT.musicEnabled, musicId=ORBIT.savedMusicId,
        useMySkin=ORBIT.botSettings.UseMySkin,
        showPlayerRing=ORBIT.botSettings.ShowPlayerRing,
        espEnabled=ORBIT.ESP and ORBIT.ESP.Enabled,
        soundEnabled=ORBIT.SOUNDS and ORBIT.SOUNDS.Enabled,
        soundVolume=ORBIT.SOUNDS and ORBIT.SOUNDS.Volume,
    }
end

local function applySaveData(d)
    if not d then return end
    if d.spreadIndex then P.spreadIndex = d.spreadIndex end
    if d.speedIndex then P.speedIndex = d.speedIndex; SETTINGS.SpeedMultiplier = P.SPEED[P.speedIndex].value end
    if d.orbitIndex then P.orbitIndex = d.orbitIndex end
    if d.shapeSizeIndex then P.shapeSizeIndex = d.shapeSizeIndex end
    if d.colorIndex then P.colorIndex = d.colorIndex end
    if d.trailLengthIndex then P.trailLengthIndex = d.trailLengthIndex; SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value end
    if d.trailWidthIndex then P.trailWidthIndex = d.trailWidthIndex; SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value end
    if d.directionIndex then P.directionIndex = d.directionIndex end
    if d.speedModeIndex then P.speedModeIndex = d.speedModeIndex end
    if d.heightIndex then P.heightIndex = d.heightIndex end
    if d.shapeIndex then ORBIT.shapeIndex = d.shapeIndex end
    if d.formModeIndex then P.formModeIndex = d.formModeIndex end
    if d.orbitPatternIndex then P.orbitPatternIndex = d.orbitPatternIndex; SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name end
    if d.auraColorIndex then P.auraColorIndex = d.auraColorIndex end
    if d.auraShapeIndex then ORBIT.auraShapeIndex = d.auraShapeIndex end
    if d.shapeCategoryIndex then P.shapeCategoryIndex = d.shapeCategoryIndex end
    if d.spinResetting ~= nil then ORBIT.spinResetting = d.spinResetting end
    if d.spinAxisEnabled ~= nil then ORBIT.spinAxisEnabled = d.spinAxisEnabled end
    if d.spinAxisDir ~= nil then ORBIT.spinAxisDir = d.spinAxisDir end
    if d.spinSpeedIndex then P.spinSpeedIndex = d.spinSpeedIndex; SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value end
    if d.heartScale then SETTINGS.HeartScale = d.heartScale end
    if d.auraEnabled ~= nil then SETTINGS.AuraEnabled = d.auraEnabled end
    if d.auraSizeIndex then P.auraSizeIndex = d.auraSizeIndex; SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value end
    if d.auraThickIndex then P.auraThickIndex = d.auraThickIndex; SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value end
    if d.auraHeightIndex then P.auraHeightIndex = d.auraHeightIndex; SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value end
    if d.auraShapeScaleIndex then P.auraShapeScaleIndex = d.auraShapeScaleIndex; SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor end
    if d.auraTrailEnabled ~= nil then SETTINGS.AuraTrailEnabled = d.auraTrailEnabled end
    if d.auraTrailLengthIndex then P.auraTrailLengthIndex = d.auraTrailLengthIndex; SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value end
    if d.auraTrailWidthIndex then P.auraTrailWidthIndex = d.auraTrailWidthIndex; SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value end
    if d.auraPatternIndex then P.auraPatternIndex = d.auraPatternIndex; SETTINGS.AuraPattern = P.AURA_PATTERNS[P.auraPatternIndex].name end
    if d.auraSpinEnabled ~= nil then SETTINGS.AuraSpinEnabled = d.auraSpinEnabled end
    if d.auraSpinAxis then SETTINGS.AuraSpinAxis = d.auraSpinAxis end
    if d.auraSpinSpeedIndex then P.auraSpinSpeedIndex = d.auraSpinSpeedIndex; SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value end
    if d.auraPulseEnabled ~= nil then SETTINGS.AuraPulseEnabled = d.auraPulseEnabled end
    if d.auraSpeedIndex then P.auraSpeedIndex = d.auraSpeedIndex; SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value end
    if d.auraDirIndex then P.auraDirIndex = d.auraDirIndex; SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value end
    if d.auraLightEnabled ~= nil then SETTINGS.AuraLightEnabled = d.auraLightEnabled end
    if d.auraLightRange then SETTINGS.AuraLightRange = d.auraLightRange end
    if d.auraLightBrightness then SETTINGS.AuraLightBrightness = d.auraLightBrightness end
    if d.fireEnabled ~= nil then SETTINGS.FireEnabled = d.fireEnabled end
    if d.fireSizeIndex then P.fireSizeIndex = d.fireSizeIndex; SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value end
    if d.fireHeatIndex then P.fireHeatIndex = d.fireHeatIndex; SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value end
    if d.rainbowSpeed then SETTINGS.RainbowSpeed = d.rainbowSpeed end
    if d.autoShapeSwap ~= nil then SETTINGS.AutoShapeSwap = d.autoShapeSwap end
    if d.gradientEnabled ~= nil then SETTINGS.GradientEnabled = d.gradientEnabled end
    if d.ringShapes then for ri = 1, 5 do if d.ringShapes[ri] then rings[ri].shapeIndex = d.ringShapes[ri] end end end
    if d.ringEnabled then
        for ri = 1, 5 do
            if d.ringEnabled[ri] ~= nil then
                if rings[ri].enabled and not d.ringEnabled[ri] then ORBIT.destroyRing(ri) end
                rings[ri].enabled = d.ringEnabled[ri]
            end
        end
    end
    if d.lightEnabled ~= nil then SETTINGS.LightEnabled = d.lightEnabled end
    if d.trailEnabled ~= nil then SETTINGS.TrailEnabled = d.trailEnabled end
    if d.pulseEnabled ~= nil then SETTINGS.PulseEnabled = d.pulseEnabled end
    if d.showNames ~= nil then SETTINGS.ShowBlockNames = d.showNames end
    if d.waveEnabled ~= nil then SETTINGS.WaveEnabled = d.waveEnabled end
    if d.explosionEnabled ~= nil then SETTINGS.ExplosionEnabled = d.explosionEnabled end
    if d.musicEnabled ~= nil then ORBIT.musicEnabled = d.musicEnabled end
    if d.musicId then ORBIT.savedMusicId = d.musicId; ORBIT.setMusicId(d.musicId) end
    if d.useMySkin ~= nil then ORBIT.botSettings.UseMySkin = d.useMySkin end
    if d.showPlayerRing ~= nil then ORBIT.botSettings.ShowPlayerRing = d.showPlayerRing end
    if d.espEnabled ~= nil and ORBIT.ESP then ORBIT.ESP.Enabled = d.espEnabled end
    if d.soundEnabled ~= nil and ORBIT.SOUNDS then ORBIT.SOUNDS.Enabled = d.soundEnabled end
    if d.soundVolume ~= nil and ORBIT.SOUNDS then ORBIT.SOUNDS.Volume = d.soundVolume end
end

function ORBIT.saveSettings()
    local ok, data = pcall(collectSaveData)
    if not ok then return false, "Сбор данных" end
    local ok2, encData = pcall(enc, data)
    if not ok2 then return false, "Сериализация" end
    SAVED_DATA = data
    if ORBIT.HAS_FS then
        return pcall(function() writefile(ORBIT.SAVE_FILE, HttpService:JSONEncode(encData)) end)
    end
    return true
end

function ORBIT.loadSettings()
    if not SAVED_DATA and ORBIT.HAS_FS then
        pcall(function()
            if isfile(ORBIT.SAVE_FILE) then
                local txt = readfile(ORBIT.SAVE_FILE)
                if txt and #txt > 0 then SAVED_DATA = dec(HttpService:JSONDecode(txt)) end
            end
        end)
    end
    if not SAVED_DATA then return false end
    applySaveData(SAVED_DATA)
    return true
end

function ORBIT.saveNamed(name)
    if not name or name == "" then return false, "Пустое имя" end
    local ok, data = pcall(collectSaveData)
    if not ok then return false, "Ошибка сбора" end
    local ok2, encData = pcall(enc, data)
    if not ok2 then return false, "Ошибка сериализации" end
    ORBIT.SAVES[name] = { data = encData, time = os.time() }
    ORBIT.saveSavesList()
    return true
end

function ORBIT.loadNamed(name)
    if not ORBIT.SAVES[name] then return false, "Нет сохранения" end
    applySaveData(dec(ORBIT.SAVES[name].data))
    return true
end

function ORBIT.deleteNamed(name)
    if not ORBIT.SAVES[name] then return false end
    ORBIT.SAVES[name] = nil
    ORBIT.saveSavesList()
    return true
end

function ORBIT.getSaveNames()
    local names = {}
    for name in pairs(ORBIT.SAVES) do table.insert(names, name) end
    table.sort(names)
    return names
end

-- ==================== СТАРТ ====================
function ORBIT.startLogic()
    ORBIT.createMusicSound()
    ORBIT.applyShapes()
    ORBIT.setupRespawnHook()
    pcall(function() ORBIT.loadSettings() end)
    ORBIT.setEnabled(true)
    ORBIT.setupAura()
    ORBIT.setupFire()
    if ORBIT.enableProtection then
        pcall(ORBIT.enableProtection)
    end
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("P3 v23.3 (логика + свет ауры)", Color3.fromRGB(180,255,180), 3) end

return true
