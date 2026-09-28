--[[ ОРБИТА v20.0 — ЧАСТЬ 3/4: ЛОГИКА (fire edition) ]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P3] Часть 1 не загружена!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local Workspace    = ORBIT.Workspace
local LocalPlayer  = ORBIT.LocalPlayer
local HttpService  = ORBIT.HttpService

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local rings    = ORBIT.rings
local statsData = ORBIT.statsData
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS
if not P then warn("[Orbit P3] P не передан (p1 старая)"); return end
if not SHAPE_PRESETS then warn("[Orbit P3] Часть 2 не загружена"); return end

-- ==================== АУРА ====================
local function getAuraColor(i, total)
    local p = P.COLORS[P.auraColorIndex]
    if p.rainbow then
        local t = tick() - ORBIT.startTime
        return Color3.fromHSV((t*0.2 + i/math.max(total,1)) % 1, 0.9, 1)
    end
    return p.c or SETTINGS.AuraColor
end

local function getAuraShapeSize()
    return ORBIT.getCurrentShapeSize() * SETTINGS.AuraShapeScale
end

function ORBIT.setupAura()
    if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
    ORBIT.auraParts = {}; ORBIT.auraBlocks = {}
    if not SETTINGS.AuraEnabled then return end

    ORBIT.auraFolder = Instance.new("Folder")
    ORBIT.auraFolder.Name = "OrbitAura_" .. tostring(math.random(1, 999999))
    ORBIT.auraFolder.Parent = Workspace

    if SETTINGS.AuraRing then
        local ring = Instance.new("Part")
        ring.Name = "AuraRing"; ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(SETTINGS.AuraThickness, SETTINGS.AuraSize*2, SETTINGS.AuraSize*2)
        ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
        ring.Material = Enum.Material.Neon; ring.Color = getAuraColor(1, 1); ring.Transparency = 0.3
        ring.Parent = ORBIT.auraFolder
        table.insert(ORBIT.auraParts, ring)
    end

    if SETTINGS.AuraParticles then
        local emitter = Instance.new("Part")
        emitter.Name = "AuraEmitter"; emitter.Size = Vector3.new(0.1,0.1,0.1); emitter.Transparency = 1
        emitter.Anchored = true; emitter.CanCollide = false; emitter.CastShadow = false
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
                bodyParts = data.bodyParts, index = i, total = count,
                trail = trail,
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
        for _, data in ipairs(ORBIT.auraBlocks) do
            if not data.part.Parent then continue end
            local angle = math.rad(ORBIT.auraAngle + (data.index-1)*(360/data.total))
            local pos = hrp.Position + Vector3.new(math.cos(angle)*radius, height, math.sin(angle)*radius)
            local cf
            if SETTINGS.AuraSpinEnabled then
                if SETTINGS.AuraSpinAxis == "Y" then
                    cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
                        * CFrame.Angles(0, math.rad(ORBIT.auraSpinAngle), 0)
                else
                    cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
                        * CFrame.Angles(math.rad(ORBIT.auraSpinAngle), 0, 0)
                end
            else
                cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
            end
            if data.isModel and data.model then data.model:PivotTo(cf) else data.part.CFrame = cf end
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
    part.Name = "FirePart"
    part.Size = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.CFrame = hrp.CFrame
    part.Parent = ORBIT.fireFolder

    local fire = Instance.new("Fire")
    fire.Heat = SETTINGS.FireHeat
    fire.Size = SETTINGS.FireSize
    fire.Color = SETTINGS.FireColor
    fire.SecondaryColor = Color3.fromRGB(255, 220, 100)
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

-- ==================== КОЛЬЦА НА ДРУГИХ ====================
function ORBIT.buildTargetRings(player)
    if ORBIT.targetRings[player] then
        pcall(function() ORBIT.targetRings[player].folder:Destroy() end)
        ORBIT.targetRings[player] = nil
    end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local folder = Instance.new("Folder")
    folder.Name = "TargetRing_" .. tostring(math.random(1, 999999))
    folder.Parent = Workspace
    local shape = SHAPE_PRESETS[ORBIT.shapeIndex] or SHAPE_PRESETS[1]
    local size = ORBIT.getCurrentShapeSize()
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
            angleOffset = (i-1)*(360/SETTINGS.BlockCount),
            index = i,
        })
    end
    ORBIT.targetRings[player] = { folder = folder, blocks = blocks, angle = 0 }
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
        if player ~= LocalPlayer then
            ORBIT.buildTargetRings(player)
            count = count + 1
        end
    end
    ORBIT.notify("➕ Кольца навешены " .. count .. " игрокам", Color3.fromRGB(160, 255, 160), 2)
end

function ORBIT.removeRingsFromAll()
    local count = 0
    for player in pairs(ORBIT.targetRings) do
        ORBIT.removeTargetRings(player)
        count = count + 1
    end
    ORBIT.notify("➖ Убрано у всех (" .. count .. ")", Color3.fromRGB(255, 160, 160), 2)
end

function ORBIT.toggleAllRings()
    local any = false
    for _ in pairs(ORBIT.targetRings) do any = true; break end
    if any then ORBIT.removeRingsFromAll() else ORBIT.addRingsToAll() end
end

local function updateTargetRings(dt)
    local t = tick() - ORBIT.startTime
    local baseCol = SETTINGS.FixedColor
    if P.COLORS[P.colorIndex] and not P.COLORS[P.colorIndex].rainbow then
        baseCol = P.COLORS[P.colorIndex].c or baseCol
    end
    for player, data in pairs(ORBIT.targetRings) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        data.angle = data.angle + ORBIT.getTargetSpeed() * dt
        local radius = ORBIT.getTargetRadius(1)
        local height = ORBIT.getTargetHeight(1)
        local spinAngle = (ORBIT.spinAxisEnabled and not ORBIT.spinResetting) and (t*3) or 0
        for _, b in ipairs(data.blocks) do
            local ref = b.isModel and b.model or b.part
            if not ref or not ref.Parent then continue end
            local angle = math.rad(data.angle + b.angleOffset)
            local px, pz = math.cos(angle)*radius, math.sin(angle)*radius
            local targetCF
            if ORBIT.spinAxisDir == "X" then
                targetCF = CFrame.new(hrp.Position + Vector3.new(px, height, pz)) * CFrame.Angles(math.rad(spinAngle), math.rad(spinAngle)*0.7, 0)
            else
                targetCF = CFrame.new(hrp.Position + Vector3.new(px, height, pz)) * CFrame.Angles(0, math.rad(spinAngle), 0)
            end
            if b.isModel and b.model then b.model:PivotTo(targetCF) else b.part.CFrame = targetCF end
            local col = baseCol
            if SETTINGS.Rainbow then
                col = Color3.fromHSV((t*SETTINGS.RainbowSpeed*SETTINGS.SpeedMultiplier + b.index/SETTINGS.BlockCount) % 1, 0.9, 1)
            end
            if b.bodyParts then
                for _, p in ipairs(bodyParts) do
                    if not p:GetAttribute("NoRecolor") then p.Color = col end
                end
            elseif b.part then b.part.Color = col end
        end
    end
end

function ORBIT.cleanupAllTargetRings()
    for p in pairs(ORBIT.targetRings) do ORBIT.removeTargetRings(p) end
    for _, btn in pairs(ORBIT.peopleButtons) do pcall(function() btn:Destroy() end) end
    ORBIT.peopleButtons = {}
end

function ORBIT.toggleTargetRings(player)
    if ORBIT.targetRings[player] then
        ORBIT.removeTargetRings(player)
        ORBIT.notify("➖ Убрано у " .. player.Name, Color3.fromRGB(255,150,150))
    else
        ORBIT.buildTargetRings(player)
        ORBIT.notify("➕ Кольцо у " .. player.Name, Color3.fromRGB(200,150,255))
    end
end

function ORBIT.rebuildAllTargetRings()
    local t = {}
    for p in pairs(ORBIT.targetRings) do table.insert(t, p) end
    for _, p in ipairs(t) do ORBIT.removeTargetRings(p); ORBIT.buildTargetRings(p) end
end

-- ==================== УЗОРЫ ====================
local function applyOrbitPattern(ri, baseAngle, baseRadius, baseHeight)
    local pattern = SETTINGS.OrbitPattern
    local t = baseAngle
    if pattern == "Круг" then
        return math.cos(t)*baseRadius, baseHeight, math.sin(t)*baseRadius
    elseif pattern == "Спираль" then
        local sf = (math.sin(t*0.3)+1)*0.5
        local r = baseRadius*(0.4+0.6*sf)
        return math.cos(t)*r, baseHeight + math.sin(t*0.5)*3, math.sin(t)*r
    elseif pattern == "Волна" then
        return math.cos(t)*baseRadius, baseHeight + math.sin(t*2)*4, math.sin(t)*baseRadius
    elseif pattern == "Восьмёрка" then
        return math.sin(t)*baseRadius, baseHeight, math.sin(t*2)*baseRadius*0.5
    elseif pattern == "Зигзаг" then
        local seg = math.floor(t/(math.pi/3))
        local dir = (seg%2==0) and 1 or -1
        return math.cos(t)*baseRadius, baseHeight + dir*2, math.sin(t)*baseRadius
    elseif pattern == "Лиссажу" then
        return math.sin(3*t)*baseRadius, baseHeight, math.sin(2*t + math.pi/2)*baseRadius
    elseif pattern == "Хаос" then
        local r = baseRadius*(0.7 + math.sin(t*7.3+ri)*0.3)
        return math.cos(t)*r, baseHeight + math.sin(t*5.1+ri*2)*3, math.sin(t)*r
    end
    return math.cos(t)*baseRadius, baseHeight, math.sin(t)*baseRadius
end

-- ==================== УТИЛИТЫ ====================
function ORBIT.countActiveLights()
    local count = 0
    for _, ring in pairs(rings) do
        for _, data in ipairs(ring.blocks) do
            if data.light and data.light.Parent then count = count + 1 end
        end
    end
    ORBIT.activeLightCount = count
end
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
            refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
            refPart.Transparency = SETTINGS.Transparency
            refPart.Color = SETTINGS.FixedColor
        end
        if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
        local light = nil
        if SETTINGS.LightEnabled and ORBIT.activeLightCount < SETTINGS.LightLimit then
            light = Instance.new("PointLight")
            light.Name = blockName .. "_Light"
            light.Color = SETTINGS.FixedColor
            light.Range = SETTINGS.LightRange
            light.Brightness = 1
            light.Parent = refPart
            ORBIT.activeLightCount = ORBIT.activeLightCount + 1
        end
        local trail = nil
        if SETTINGS.TrailEnabled then
            local span = visualSize*0.35
            local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(-span,0,0); a0.Parent = refPart
            local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(span,0,0); a1.Parent = refPart
            trail = Instance.new("Trail")
            trail.Attachment0 = a0; trail.Attachment1 = a1
            trail.Color = ColorSequence.new(SETTINGS.FixedColor)
            trail.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1),
            })
            ORBIT.applyTrailSettings(trail)
            trail.Parent = refPart
        end
        local nameGui = Instance.new("BillboardGui")
        nameGui.Size = UDim2.new(0, 140, 0, 30)
        nameGui.StudsOffset = Vector3.new(0, visualSize*0.9 + 1, 0)
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

        updateAura(dt)
        updateTargetRings(dt)
        updateFire()

        if SETTINGS.AutoShapeSwap and (tick() - ORBIT.lastAutoSwap) > SETTINGS.AutoShapeSwapInterval then
            ORBIT.lastAutoSwap = tick()
            ORBIT.currentAutoShapeIndex = ORBIT.currentAutoShapeIndex + 1
            if ORBIT.currentAutoShapeIndex > #SHAPE_PRESETS then ORBIT.currentAutoShapeIndex = 1 end
            ORBIT.shapeIndex = ORBIT.currentAutoShapeIndex
            ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
            ORBIT.notify("🎭 Автосмена: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, Color3.fromRGB(220,200,255))
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
            for i, data in ipairs(ring.blocks) do
                if not data.part.Parent then continue end
                local angle = math.rad(orbitAngle + data.angleOffset)
                local yBob
                if SETTINGS.WaveEnabled then
                    yBob = math.sin(t*SETTINGS.WaveSpeed - (angle + orbitAngle*0.002)*SETTINGS.WaveLength) * SETTINGS.WaveAmplitude
                else
                    yBob = math.sin(bobPhase + i + ri*0.5) * SETTINGS.BobAmplitude
                end
                local px, py, pz = applyOrbitPattern(ri, angle, radius, height + yBob)
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

function ORBIT.setEnabled(state)
    ORBIT.enabled = state
    if state then
        ORBIT.countActiveLights()
        for ri, ring in pairs(rings) do
            if ring.enabled then ORBIT.buildRing(ri) end
        end
        ORBIT.applyColor(); ORBIT.applyNameVisibility()
        ORBIT.startUpdateLoop()
        ORBIT.notify("🟢 Скрипт включён", Color3.fromRGB(100,255,150))
    else
        ORBIT.stopUpdateLoop()
        for ri in pairs(rings) do ORBIT.destroyRing(ri) end
        ORBIT.activeLightCount = 0
        if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
        if ORBIT.fireFolder then ORBIT.fireFolder:Destroy(); ORBIT.fireFolder = nil end
        ORBIT.cleanupAllTargetRings()
        ORBIT.notify("🔴 Скрипт выключен", Color3.fromRGB(255,100,100))
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

function ORBIT.setupRespawnHook()
    LocalPlayer.CharacterAdded:Connect(function()
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

-- ==================== СОХРАНЕНИЕ ====================
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
        orbitPatternIndex=P.orbitPatternIndex, auraTypeIndex=P.auraTypeIndex,
        auraColorIndex=P.auraColorIndex, auraShapeIndex=ORBIT.auraShapeIndex,
        ringShapes=rs, ringEnabled=re,
        lightEnabled=SETTINGS.LightEnabled, trailEnabled=SETTINGS.TrailEnabled,
        pulseEnabled=SETTINGS.PulseEnabled, showNames=SETTINGS.ShowBlockNames,
        waveEnabled=SETTINGS.WaveEnabled, explosionEnabled=SETTINGS.ExplosionEnabled,
        auraEnabled=SETTINGS.AuraEnabled, auraSize=SETTINGS.AuraSize,
        auraRing=SETTINGS.AuraRing, auraParticles=SETTINGS.AuraParticles, auraShapes=SETTINGS.AuraShapes,
        auraSpeedMult=SETTINGS.AuraSpeedMult, auraDirection=SETTINGS.AuraDirection,
        auraSpeedIndex=P.auraSpeedIndex, auraDirIndex=P.auraDirIndex,
        auraSizeIndex=P.auraSizeIndex, auraThickIndex=P.auraThickIndex,
        auraHeight=SETTINGS.AuraHeight, auraHeightIndex=P.auraHeightIndex,
        auraShapeScale=SETTINGS.AuraShapeScale, auraShapeScaleIndex=P.auraShapeScaleIndex,
        auraTrailEnabled=SETTINGS.AuraTrailEnabled,
        auraTrailLength=SETTINGS.AuraTrailLength, auraTrailLengthIndex=P.auraTrailLengthIndex,
        auraTrailWidth=SETTINGS.AuraTrailWidth, auraTrailWidthIndex=P.auraTrailWidthIndex,
        auraSpinEnabled=SETTINGS.AuraSpinEnabled, auraSpinAxis=SETTINGS.AuraSpinAxis,
        auraSpinSpeed=SETTINGS.AuraSpinSpeed, auraSpinSpeedIndex=P.auraSpinSpeedIndex,
        auraSpinAxisIndex=P.auraSpinAxisIndex,
        auraPulseEnabled=SETTINGS.AuraPulseEnabled,
        fireEnabled=SETTINGS.FireEnabled, fireSize=SETTINGS.FireSize, fireHeat=SETTINGS.FireHeat,
        fireSizeIndex=P.fireSizeIndex, fireHeatIndex=P.fireHeatIndex,
        rainbowSpeed=SETTINGS.RainbowSpeed,
        autoShapeSwap=SETTINGS.AutoShapeSwap, autoShapeSwapInterval=SETTINGS.AutoShapeSwapInterval,
        gradientEnabled=SETTINGS.GradientEnabled,
        spinResetting=ORBIT.spinResetting, spinAxisEnabled=ORBIT.spinAxisEnabled, spinAxisDir=ORBIT.spinAxisDir,
        spinSpeedIndex=P.spinSpeedIndex, heartScale=SETTINGS.HeartScale,
        musicEnabled=ORBIT.musicEnabled, musicId=ORBIT.savedMusicId, musicVolume=ORBIT.musicVolume,
    }
end

function ORBIT.saveSettings()
    SAVED_DATA = collectSaveData()
    if ORBIT.HAS_FS then
        return pcall(function() writefile(ORBIT.SAVE_FILE, HttpService:JSONEncode(enc(SAVED_DATA))) end)
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
    local d = SAVED_DATA
    if d.spreadIndex then P.spreadIndex = d.spreadIndex end
    if d.speedIndex then P.speedIndex = d.speedIndex end
    if d.orbitIndex then P.orbitIndex = d.orbitIndex end
    if d.shapeSizeIndex then P.shapeSizeIndex = d.shapeSizeIndex end
    if d.colorIndex then P.colorIndex = d.colorIndex end
    if d.trailLengthIndex then P.trailLengthIndex = d.trailLengthIndex end
    if d.trailWidthIndex then P.trailWidthIndex = d.trailWidthIndex end
    if d.directionIndex then P.directionIndex = d.directionIndex end
    if d.speedModeIndex then P.speedModeIndex = d.speedModeIndex end
    if d.heightIndex then P.heightIndex = d.heightIndex end
    if d.shapeIndex then ORBIT.shapeIndex = d.shapeIndex end
    if d.formModeIndex then P.formModeIndex = d.formModeIndex end
    if d.orbitPatternIndex then P.orbitPatternIndex = d.orbitPatternIndex; SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name end
    if d.auraTypeIndex then P.auraTypeIndex = d.auraTypeIndex end
    if d.auraColorIndex then P.auraColorIndex = d.auraColorIndex end
    if d.auraShapeIndex then ORBIT.auraShapeIndex = d.auraShapeIndex end
    if d.spinResetting ~= nil then ORBIT.spinResetting = d.spinResetting end
    if d.spinAxisEnabled ~= nil then ORBIT.spinAxisEnabled = d.spinAxisEnabled end
    if d.spinAxisDir ~= nil then ORBIT.spinAxisDir = d.spinAxisDir end
    if d.spinSpeedIndex then P.spinSpeedIndex = d.spinSpeedIndex; SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value end
    if d.heartScale then SETTINGS.HeartScale = d.heartScale end
    if d.auraEnabled ~= nil then SETTINGS.AuraEnabled = d.auraEnabled end
    if d.auraSize then SETTINGS.AuraSize = d.auraSize end
    if d.auraRing ~= nil then SETTINGS.AuraRing = d.auraRing end
    if d.auraParticles ~= nil then SETTINGS.AuraParticles = d.auraParticles end
    if d.auraShapes ~= nil then SETTINGS.AuraShapes = d.auraShapes end
    if d.auraSpeedMult then SETTINGS.AuraSpeedMult = d.auraSpeedMult end
    if d.auraDirection then SETTINGS.AuraDirection = d.auraDirection end
    if d.auraSpeedIndex then P.auraSpeedIndex = d.auraSpeedIndex; SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value end
    if d.auraDirIndex then P.auraDirIndex = d.auraDirIndex; SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value end
    if d.auraSizeIndex then P.auraSizeIndex = d.auraSizeIndex; SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value end
    if d.auraThickIndex then P.auraThickIndex = d.auraThickIndex; SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value end
    if d.auraHeight then SETTINGS.AuraHeight = d.auraHeight end
    if d.auraHeightIndex then P.auraHeightIndex = d.auraHeightIndex; SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value end
    if d.auraShapeScale then SETTINGS.AuraShapeScale = d.auraShapeScale end
    if d.auraShapeScaleIndex then P.auraShapeScaleIndex = d.auraShapeScaleIndex; SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor end
    if d.auraTrailEnabled ~= nil then SETTINGS.AuraTrailEnabled = d.auraTrailEnabled end
    if d.auraTrailLength then SETTINGS.AuraTrailLength = d.auraTrailLength end
    if d.auraTrailLengthIndex then P.auraTrailLengthIndex = d.auraTrailLengthIndex; SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value end
    if d.auraTrailWidth then SETTINGS.AuraTrailWidth = d.auraTrailWidth end
    if d.auraTrailWidthIndex then P.auraTrailWidthIndex = d.auraTrailWidthIndex; SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value end
    if d.auraSpinEnabled ~= nil then SETTINGS.AuraSpinEnabled = d.auraSpinEnabled end
    if d.auraSpinAxis then SETTINGS.AuraSpinAxis = d.auraSpinAxis end
    if d.auraSpinSpeed then SETTINGS.AuraSpinSpeed = d.auraSpinSpeed end
    if d.auraSpinSpeedIndex then P.auraSpinSpeedIndex = d.auraSpinSpeedIndex; SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value end
    if d.auraSpinAxisIndex then P.auraSpinAxisIndex = d.auraSpinAxisIndex; SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value end
    if d.auraPulseEnabled ~= nil then SETTINGS.AuraPulseEnabled = d.auraPulseEnabled end
    if d.fireEnabled ~= nil then SETTINGS.FireEnabled = d.fireEnabled end
    if d.fireSize then SETTINGS.FireSize = d.fireSize end
    if d.fireHeat then SETTINGS.FireHeat = d.fireHeat end
    if d.fireSizeIndex then P.fireSizeIndex = d.fireSizeIndex; SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value end
    if d.fireHeatIndex then P.fireHeatIndex = d.fireHeatIndex; SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value end
    if d.rainbowSpeed then SETTINGS.RainbowSpeed = d.rainbowSpeed end
    if d.autoShapeSwap ~= nil then SETTINGS.AutoShapeSwap = d.autoShapeSwap end
    if d.autoShapeSwapInterval then SETTINGS.AutoShapeSwapInterval = d.autoShapeSwapInterval end
    if d.gradientEnabled ~= nil then SETTINGS.GradientEnabled = d.gradientEnabled end
    if d.musicVolume then ORBIT.musicVolume = d.musicVolume end
    if d.ringShapes then
        for ri = 1, 5 do if d.ringShapes[ri] then rings[ri].shapeIndex = d.ringShapes[ri] end end
    end
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
    if P.COLORS[P.auraColorIndex] and P.COLORS[P.auraColorIndex].c then SETTINGS.AuraColor = P.COLORS[P.auraColorIndex].c end
    return true
end

function ORBIT.startLogic()
    ORBIT.createMusicSound()
    ORBIT.applyShapes()
    ORBIT.setupRespawnHook()
    pcall(function() ORBIT.loadSettings() end)
    ORBIT.setEnabled(true)
    ORBIT.setupAura()
    ORBIT.setupFire()
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ Часть 3: логика загружена", Color3.fromRGB(180,255,180), 3) end

return true
