--[[ ОРБИТА v21.1 — ЧАСТЬ 3/4: ЛОГИКА + МАКС. ЗАЩИТА v5 + AUTO-DODGE + БОТЫ ]]

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
if not P then warn("[Orbit P3] P не передан"); return end
if not SHAPE_PRESETS then warn("[Orbit P3] Часть 2 не загружена"); return end

-- ==================== КАТЕГОРИИ ФИГУР ====================
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
                    cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0) * CFrame.Angles(0, math.rad(ORBIT.auraSpinAngle), 0)
                else
                    cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0) * CFrame.Angles(math.rad(ORBIT.auraSpinAngle), 0, 0)
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
    part.Name = "FirePart"; part.Size = Vector3.new(1, 1, 1); part.Transparency = 1
    part.Anchored = true; part.CanCollide = false; part.CastShadow = false
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

-- ==================== МАКСИМАЛЬНАЯ ЗАЩИТА v5 ====================
local PROT_STATE = {
    lastSafePos = nil, lastSafeCFrame = nil, lastCheckTime = 0, lastHealTime = 0,
    lastHealth = 100, lastKnockTime = 0, lastFreezeTime = 0, spawnGrace = 0,
    watchConn = nil, logEnabled = true, lastHealthCheck = 0, lastScan = 0,
    lastPositions = {}, godmodeWarned = {},
}
ORBIT.PROT_STATE = PROT_STATE

local ORIG_WS, ORIG_JP = 16, 50
LocalPlayer.CharacterAdded:Connect(function(c)
    local h = c:WaitForChild("Humanoid", 5)
    if h then ORIG_WS, ORIG_JP = h.WalkSpeed, h.JumpPower end
end)

local BAD_CLASSES = {
    BodyVelocity = true, BodyForce = true, BodyAngularVelocity = true,
    BodyGyro = true, BodyPosition = true, BodyThrust = true,
    LinearVelocity = true, AngularVelocity = true, VectorForce = true,
    Torque = true, AlignPosition = true, AlignOrientation = true,
}

local function protLog(text, color)
    if not PROT_STATE.logEnabled then return end
    print("[OrbitProt] " .. text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text = "[🛡] " .. text,
            Color = color or Color3.fromRGB(255, 200, 100),
        })
    end)
end

local function killObject(obj)
    if not obj or not obj.Parent then return end
    pcall(function() obj:Destroy() end)
end

local function resetVelocity(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                p.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
        end
    end
end

-- ==== ANTI-FLING + ANTI-SPIN (УСИЛЕННЫЙ) ====
local function antiFling(char, hrp)
    if not SETTINGS.AntiFling then return end
    pcall(function()
        -- Сброс линейной скорости (Knockback)
        if hrp.AssemblyLinearVelocity.Magnitude > 150 then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        -- Сброс угловой скорости (Spin) — ловит даже слабое вращение
        if hrp.AssemblyAngularVelocity.Magnitude > 20 then
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

-- ==== AUTO-DODGE (уклонение в стиле Санса) ====
local DODGE = {
    Enabled = true,
    ScanRadius = 18,
    SpeedThreshold = 40,
    DodgeDist = 14,
    Cooldown = 0.4,
    LastDodge = 0,
}
ORBIT.DODGE = DODGE

local dodgeConn = nil

local function setupAutoDodge()
    if dodgeConn then dodgeConn:Disconnect(); dodgeConn = nil end
    dodgeConn = RunService.Heartbeat:Connect(function(dt)
        if not SETTINGS.ProtEnabled or not DODGE.Enabled then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local now = tick()
        if now - DODGE.LastDodge < DODGE.Cooldown then return end

        -- Сканируем угрозы
        local threats = {}
        local myPos = hrp.Position
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj ~= hrp and obj.Parent ~= char then
                local dist = (obj.Position - myPos).Magnitude
                if dist < DODGE.ScanRadius then
                    local vel = obj.AssemblyLinearVelocity
                    if vel.Magnitude > DODGE.SpeedThreshold then
                        local toMe = (myPos - obj.Position)
                        if toMe.Magnitude > 0.1 then
                            local dot = vel.Unit:Dot(toMe.Unit)
                            if dot > 0.5 then
                                table.insert(threats, { obj = obj, dist = dist, vel = vel })
                            end
                        end
                    end
                end
            end
        end

        if #threats > 0 then
            table.sort(threats, function(a, b) return a.dist < b.dist end)
            local threat = threats[1]
            local threatDir = (threat.obj.Position - myPos).Unit
            local rightDir = threatDir:Cross(Vector3.new(0, 1, 0)).Unit

            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
            local rayRight = Workspace:Raycast(myPos, rightDir * DODGE.DodgeDist, rayParams)
            local dodgeDir = rayRight and -rightDir or rightDir

            local targetPos = myPos + dodgeDir * DODGE.DodgeDist
            local rayDown = Workspace:Raycast(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), rayParams)
            if rayDown then
                targetPos = rayDown.Position + Vector3.new(0, 3, 0)
            end

            pcall(function()
                char:PivotTo(CFrame.new(targetPos))
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
            DODGE.LastDodge = now
            protLog("Auto-Dodge: уклонение от " .. threat.obj.Name, Color3.fromRGB(100, 255, 200))
        end
    end)
end
ORBIT.setupAutoDodge = setupAutoDodge

-- ==== ANTI-FREEZE ====
local function antiFreeze(char)
    if not SETTINGS.AntiFreeze then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.WalkSpeed < 1 then hum.WalkSpeed = ORIG_WS end
            if hum.JumpPower < 1 then hum.JumpPower = ORIG_JP end
        end)
    end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored then
            pcall(function() p.Anchored = false end)
        end
    end
end

-- ==== ANTI-KNOCKBACK ====
local function antiKnockback(char)
    if not SETTINGS.AntiKnockback then return end
    for _, child in ipairs(char:GetDescendants()) do
        if BAD_CLASSES[child.ClassName] then killObject(child) end
    end
end

-- ==== ANTI-ANCHOR ====
local function antiAnchor(char)
    if not SETTINGS.ProtEnabled then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then
        pcall(function() hrp.Anchored = false end)
        protLog("Anti-Anchor", Color3.fromRGB(120, 220, 255))
    end
end

-- ==== ANTI-KILL ====
local function antiInstantKill(char)
    if not SETTINGS.ProtEnabled then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local now = tick()
    if PROT_STATE.lastHealth > 50 and hum.Health < 10 and (now - (PROT_STATE.lastHealthCheck or 0)) < 0.15 then
        if PROT_STATE.lastSafeCFrame then
            pcall(function() char:PivotTo(PROT_STATE.lastSafeCFrame) end)
            resetVelocity(char)
            protLog("Anti-Kill (мгновенный урон)", Color3.fromRGB(255, 80, 80))
        end
    end
    PROT_STATE.lastHealth = hum.Health
    PROT_STATE.lastHealthCheck = now
end

-- ==== ANTI-VOID ====
local function antiVoid(char, hrp)
    if not SETTINGS.AntiVoid then return end
    if hrp.Position.Y < SETTINGS.AntiVoidY and PROT_STATE.lastSafeCFrame then
        pcall(function() char:PivotTo(PROT_STATE.lastSafeCFrame + Vector3.new(0, 5, 0)) end)
        protLog("Anti-Void", Color3.fromRGB(120, 220, 255))
    end
end

-- ==== ANTI-TELEPORT ====
local function antiTeleport(char, hrp)
    if not SETTINGS.AntiTeleport then return end
    if not PROT_STATE.lastSafePos then return end
    if (hrp.Position - PROT_STATE.lastSafePos).Magnitude > 100 then
        pcall(function() char:PivotTo(PROT_STATE.lastSafeCFrame + Vector3.new(0, 2, 0)) end)
        resetVelocity(char)
        protLog("Anti-Teleport", Color3.fromRGB(255, 180, 100))
    end
end

-- ==== AUTO-HEAL ====
local function autoHeal(char)
    if not SETTINGS.AutoHeal then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < hum.MaxHealth and hum.Health > 0 then
        pcall(function() hum.Health = math.min(hum.MaxHealth, hum.Health + SETTINGS.AutoHealValue) end)
    end
end

-- ==== LOCK POSITION ====
local function lockPosition(char, hrp)
    if not SETTINGS.LockPosition then return end
    if PROT_STATE.lastSafeCFrame then
        pcall(function() char:PivotTo(PROT_STATE.lastSafeCFrame) end)
    end
end

-- ==== ANTI-RING PARTS ====
local function setupAntiRingParts()
    Workspace.DescendantAdded:Connect(function(obj)
        if not SETTINGS.ProtEnabled then return end
        if obj:IsA("BasePart") then
            local parent = obj.Parent
            if parent and (parent.Name:lower():find("ring") or parent.Name:lower():find("fling")) then
                task.defer(function()
                    if obj.Parent then
                        local vel = obj.AssemblyAngularVelocity
                        if vel.Magnitude > 5 then
                            protLog("Anti-RingParts: удалён " .. obj.Name, Color3.fromRGB(255, 80, 80))
                            obj:Destroy()
                        end
                    end
                end)
            end
        end
    end)
end
setupAntiRingParts()

-- ==== ANTI-GODMODE ====
local function scanForGodMode()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then continue end
        local mh = hum.MaxHealth
        local h = hum.Health
        if mh > 10000 or h > 10000 then
            if not PROT_STATE.godmodeWarned[player] then
                PROT_STATE.godmodeWarned[player] = true
                ORBIT.notify("⚠️ GodMode: " .. player.Name, Color3.fromRGB(255, 80, 80), 3)
                protLog("GodMode: " .. player.Name .. " (MaxHP: " .. math.floor(mh) .. ")", Color3.fromRGB(255, 60, 60))
                if ORBIT.tagCheater then ORBIT.tagCheater(player, true) end
            end
        else
            if PROT_STATE.godmodeWarned[player] then
                PROT_STATE.godmodeWarned[player] = nil
                protLog("GodMode отключён: " .. player.Name, Color3.fromRGB(100, 255, 100))
            end
        end
    end
end

-- ==== ANTI-SPEEDHACK ====
local function detectSpeedHack(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local now = tick()
    local last = PROT_STATE.lastPositions[player]
    if last then
        local dt = now - last.time
        if dt > 0.1 and dt < 1 then
            local dist = (hrp.Position - last.pos).Magnitude
            local speed = dist / dt
            if speed > 150 then
                protLog("SpeedHack/AutoFarm: " .. player.Name .. " (" .. math.floor(speed) .. " st/s)", Color3.fromRGB(255, 100, 100))
                if ORBIT.tagCheater then ORBIT.tagCheater(player, true) end
            end
        end
    end
    PROT_STATE.lastPositions[player] = { pos = hrp.Position, time = now }
end

-- ==== ЗАЩИТА СВОЕГО ПЕРСОНАЖА ====
local function setupCharacterProtection()
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local origMax = hum.MaxHealth
        hum.Changed:Connect(function(prop)
            if prop == "MaxHealth" and hum.MaxHealth > 10000 then
                hum.MaxHealth = origMax
                protLog("Возврат MaxHealth", Color3.fromRGB(255, 80, 80))
            end
        end)
        char.ChildAdded:Connect(function(child)
            if child:IsA("ForceField") then
                task.defer(function() pcall(function() child:Destroy() end) end)
                protLog("Удалён ForceField", Color3.fromRGB(255, 150, 100))
            end
        end)
    end)
end

-- ==== REMOTE-СПАМ БЛОКЕР ====
local remoteCallCounts = {}
local REMOTE_LIMIT = 30
local REMOTE_WINDOW = 1.0

local function setupRemoteMonitor()
    local function hook(remote)
        if not remote:IsA("RemoteEvent") then return end
        local oldFire = remote.FireServer
        if not oldFire then return end
        remote.FireServer = function(self, ...)
            if not SETTINGS.ProtEnabled then return oldFire(self, ...) end
            local now = tick()
            local key = tostring(self)
            remoteCallCounts[key] = remoteCallCounts[key] or {count = 0, time = now}
            local d = remoteCallCounts[key]
            if now - d.time > REMOTE_WINDOW then d.count = 0; d.time = now end
            d.count = d.count + 1
            if d.count > REMOTE_LIMIT then
                protLog("Remote-спам блокирован: " .. self.Name, Color3.fromRGB(255, 60, 60))
                return
            end
            return oldFire(self, ...)
        end
    end
    for _, obj in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if obj:IsA("RemoteEvent") then pcall(hook, obj) end
    end
end
setupRemoteMonitor()

-- ==== ГЛАВНЫЙ ЦИКЛ ====
local function processProtection(dt, char, hrp)
    local now = tick()
    antiFling(char, hrp)
    antiAnchor(char)
    if now - PROT_STATE.lastKnockTime >= 0.1 then
        PROT_STATE.lastKnockTime = now
        antiKnockback(char)
    end
    if now - PROT_STATE.lastFreezeTime >= 0.25 then
        PROT_STATE.lastFreezeTime = now
        antiFreeze(char)
    end
    if SETTINGS.AutoHeal and now - PROT_STATE.lastHealTime >= 0.3 then
        PROT_STATE.lastHealTime = now
        autoHeal(char)
    end
    local inGrace = (now - PROT_STATE.spawnGrace) < 2.0
    antiVoid(char, hrp)
    if not inGrace then
        antiTeleport(char, hrp)
        lockPosition(char, hrp)
    end
    antiInstantKill(char)

    if now - PROT_STATE.lastScan > 0.5 then
        PROT_STATE.lastScan = now
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                pcall(detectSpeedHack, player)
            end
        end
        pcall(scanForGodMode)
    end

    if now - PROT_STATE.lastCheckTime > 0.5 then
        PROT_STATE.lastCheckTime = now
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and hrp.Position.Y > (SETTINGS.AntiVoidY + 10) then
            PROT_STATE.lastSafePos = hrp.Position
            PROT_STATE.lastSafeCFrame = hrp.CFrame
        end
    end
end

local function watchCharacter(char)
    if not char then return end
    antiKnockback(char)
    if PROT_STATE.watchConn then pcall(function() PROT_STATE.watchConn:Disconnect() end) end
    PROT_STATE.watchConn = char.DescendantAdded:Connect(function(obj)
        if not SETTINGS.ProtEnabled then return end
        if BAD_CLASSES[obj.ClassName] then
            task.defer(function() killObject(obj) end)
        end
    end)
end

function ORBIT.enableProtection()
    if ORBIT.protConn then ORBIT.protConn:Disconnect(); ORBIT.protConn = nil end
    if not SETTINGS.ProtEnabled then return end
    PROT_STATE.lastSafePos = nil; PROT_STATE.lastSafeCFrame = nil
    PROT_STATE.lastCheckTime = 0; PROT_STATE.lastHealTime = 0
    PROT_STATE.lastHealth = 100; PROT_STATE.lastKnockTime = 0
    PROT_STATE.lastFreezeTime = 0; PROT_STATE.spawnGrace = tick()
    PROT_STATE.lastPositions = {}; PROT_STATE.godmodeWarned = {}

    if LocalPlayer.Character then watchCharacter(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        PROT_STATE.spawnGrace = tick()
        PROT_STATE.lastSafePos = nil; PROT_STATE.lastSafeCFrame = nil
        task.wait(0.3)
        watchCharacter(newChar)
    end)
    setupCharacterProtection()
    setupAutoDodge()
    ORBIT.protConn = RunService.Heartbeat:Connect(function(dt)
        if not SETTINGS.ProtEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(processProtection, dt, char, hrp)
    end)
    ORBIT.notify("🛡 Защита v5 ВКЛ (Anti-Spin + Dodge)", Color3.fromRGB(120, 255, 180), 3)
    protLog("Защита v5 активна. Auto-Dodge: " .. (DODGE.Enabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(100, 255, 100))
end

function ORBIT.disableProtection()
    if ORBIT.protConn then ORBIT.protConn:Disconnect(); ORBIT.protConn = nil end
    if dodgeConn then dodgeConn:Disconnect(); dodgeConn = nil end
    if PROT_STATE.watchConn then pcall(function() PROT_STATE.watchConn:Disconnect() end); PROT_STATE.watchConn = nil end
    PROT_STATE.lastSafePos = nil; PROT_STATE.lastSafeCFrame = nil
end

Workspace.DescendantAdded:Connect(function(inst)
    if not SETTINGS.ProtEnabled or not SETTINGS.AntiExplosion then return end
    if inst:IsA("Explosion") then
        task.defer(function() pcall(function() inst:Destroy() end) end)
    end
end)

-- ==================== ПРОИЗВОДИТЕЛЬНОСТЬ ====================
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
    if ORBIT.notify then ORBIT.notify("⚡ Качество: " .. level:upper(), Color3.fromRGB(180, 220, 255), 1.5) end
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
    local UIS = game:GetService("UserInputService")
    if PERFORMANCE.MobileAuto and UIS.TouchEnabled and PERFORMANCE.Enabled and PERFORMANCE.Level == "auto" then
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

-- ==================== МЕТКА ЧИТЕРА ====================
ORBIT.taggedPlayers = ORBIT.taggedPlayers or {}
local function makeTagGui(character, color)
    local head = character:FindFirstChild("Head")
    if not head then return nil end
    local existing = head:FindFirstChild("_OrbitCheaterTag")
    if existing then existing:Destroy() end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "_OrbitCheaterTag"
    billboard.Size = UDim2.new(0, 180, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.AlwaysOnTop = true; billboard.LightInfluence = 0
    billboard.Adornee = head; billboard.Parent = head
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 0.2
    label.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
    label.BorderSizePixel = 0
    label.Text = "⚠️ SUSPECTED CHEATER"
    label.TextColor3 = Color3.fromRGB(255, 100, 100)
    label.Font = Enum.Font.GothamBold; label.TextSize = 12
    label.Parent = billboard
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 4)
    local hl = Instance.new("Highlight")
    hl.Name = "_OrbitCheaterHighlight"
    hl.FillColor = color or Color3.fromRGB(255, 40, 40)
    hl.OutlineColor = Color3.fromRGB(255, 200, 200)
    hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = character
    return billboard, hl
end
function ORBIT.tagCheater(player, enable)
    if not player or player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    if enable then
        ORBIT.taggedPlayers[player] = true
        makeTagGui(char, Color3.fromRGB(255, 40, 40))
        if ORBIT.notify then ORBIT.notify("🚩 Помечен: " .. player.Name, Color3.fromRGB(255, 120, 120)) end
    else
        ORBIT.taggedPlayers[player] = nil
        local head = char:FindFirstChild("Head")
        if head then
            local tag = head:FindFirstChild("_OrbitCheaterTag")
            if tag then tag:Destroy() end
        end
        local hl = char:FindFirstChild("_OrbitCheaterHighlight")
        if hl then hl:Destroy() end
        if ORBIT.notify then ORBIT.notify("✅ Метка снята: " .. player.Name, Color3.fromRGB(160, 255, 160)) end
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

-- ==================== КОЛЬЦА НА ДРУГИХ ИГРОКАХ ====================
ORBIT.targetRings = ORBIT.targetRings or {}

function ORBIT.buildTargetRings(player, slot)
    slot = slot or 1
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
            bodyParts = data.bodyParts, angleOffset = (i-1)*(360/SETTINGS.BlockCount), index = i,
        })
    end
    ORBIT.targetRings[player] = { folder = folder, blocks = blocks, angle = 0, slot = slot }
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

function ORBIT.toggleTargetRings(player)
    if ORBIT.targetRings[player] then
        ORBIT.removeTargetRings(player)
        ORBIT.notify("➖ Убрано у " .. player.Name, Color3.fromRGB(255,150,150))
    else
        ORBIT.buildTargetRings(player)
        ORBIT.notify("➕ Кольцо у " .. player.Name, Color3.fromRGB(200,150,255))
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
    for player, data in pairs(ORBIT.targetRings) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        data.angle = data.angle + ORBIT.getTargetSpeed() * dt
        local radius = ORBIT.getTargetRadius(data.slot or 1)
        local height = ORBIT.getTargetHeight(data.slot or 1)
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
                for _, p in ipairs(b.bodyParts) do
                    if not p:GetAttribute("NoRecolor") then p.Color = col end
                end
            elseif b.part then b.part.Color = col end
        end
    end
end

-- ==================== 🤖 БОТЫ ====================
ORBIT.bots = {}
ORBIT.botIdCounter = 0
ORBIT.botSettings = {
    CollectRadius    = 12,
    AutoCollect      = true,
    BotRingRadius    = 4,
    BotRingHeight    = 2,
    BotRingBlockCount = 6,
    BotSpeed         = 60,
    UseMySkin        = false,
    BotYOffset       = 1.5,
}
ORBIT.botAvatarTemplate = nil

function ORBIT.getBotAvatarTemplate()
    if ORBIT.botAvatarTemplate then return ORBIT.botAvatarTemplate end
    local ok, template = pcall(function()
        local desc = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if ok and template then
        template.Name = "_OrbitBotAvatarTemplate"
        template.Parent = nil
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
    local rootY = groundY + ORBIT.botSettings.BotYOffset

    if useSkin then
        local template = ORBIT.getBotAvatarTemplate()
        if template then
            local ok, model = pcall(function() return template:Clone() end)
            if ok and model then
                model.Name = "OrbitBot_" .. tostring(math.random(1000, 999999))
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Anchored = true
                        part.CanCollide = false
                    end
                end
                pcall(function()
                    model:PivotTo(CFrame.new(Vector3.new(position.X, rootY, position.Z)))
                end)
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
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 2, 1); root.Transparency = 1
    root.Anchored = true; root.CanCollide = false
    root.CFrame = CFrame.new(Vector3.new(position.X, rootY, position.Z))
    root.Parent = model; model.PrimaryPart = root

    local torso = Instance.new("Part")
    torso.Name = "Torso"; torso.Size = Vector3.new(2, 2, 1)
    torso.Anchored = true; torso.CanCollide = false
    torso.Color = Color3.fromRGB(100, 150, 255)
    torso.Material = Enum.Material.Neon
    torso.CFrame = root.CFrame; torso.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"; head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Shape = Enum.PartType.Ball
    head.Anchored = true; head.CanCollide = false
    head.Color = Color3.fromRGB(255, 200, 100)
    head.Material = Enum.Material.Neon
    head.CFrame = root.CFrame * CFrame.new(0, 2, 0)
    head.Parent = model

    local hum = Instance.new("Humanoid"); hum.Parent = model
    model.Parent = Workspace
    return model
end

function ORBIT.createBot(shapeIndex, position, targetSlot)
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local basePos = position
    if not basePos then
        if myHrp then
            local angle = math.random() * math.pi * 2
            local dist  = 8 + math.random() * 25
            basePos = myHrp.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
        else
            basePos = Vector3.new(0, 5, 0)
        end
    end
    shapeIndex = shapeIndex or math.random(1, #SHAPE_PRESETS)
    local model = createDummyCharacter(basePos, ORBIT.botSettings.UseMySkin)
    local folder = Instance.new("Folder")
    folder.Name = "BotRing_" .. tostring(math.random(1, 999999))
    folder.Parent = Workspace
    local shape = SHAPE_PRESETS[shapeIndex]
    local ringSize   = ORBIT.getCurrentShapeSize() * (0.5 + math.random() * 0.8)
    local ringRadius = 3 + math.random() * 3
    local ringHeight = 1.5 + math.random() * 2
    local ringSpeed  = 30 + math.random() * 120
    local hueBase    = math.random()
    local blockCount = 4 + math.random(0, 4)
    local blocks = {}
    for i = 1, blockCount do
        local data = shape.create(ringSize, "Bot_R" .. i, i)
        local refPart = data.part
        if not data.isModel then
            refPart.Material = Enum.Material.Neon
            refPart.CanCollide = false; refPart.Anchored = true; refPart.CastShadow = false
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
    ORBIT.bots[model] = {
        id = botId, model = model, shapeIndex = shapeIndex,
        folder = folder, blocks = blocks, angle = 0, collected = false,
        ringRadius = ringRadius, ringHeight = ringHeight, ringSpeed = ringSpeed,
        hueBase = hueBase, blockCount = blockCount,
        targetSlot = targetSlot or 2,
    }
    return model
end

function ORBIT.createBotNear(shapeIndex, offsetStuds, targetSlot)
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then
        ORBIT.notify("❌ Нет персонажа", Color3.fromRGB(255, 120, 120), 2)
        return nil
    end
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
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    for i = 1, math.min(count, #SHAPE_PRESETS) do
        ORBIT.createBot(indices[i], nil, targetSlot)
        task.wait(0.08)
    end
    ORBIT.notify("🤖 Создано ботов: " .. math.min(count, #SHAPE_PRESETS), Color3.fromRGB(150, 200, 255), 2)
end

function ORBIT.createManyBots(count, targetSlot)
    count = math.clamp(tonumber(count) or 10, 1, 200)
    local created = 0
    for i = 1, count do
        local shapeIdx = math.random(1, #SHAPE_PRESETS)
        ORBIT.createBot(shapeIdx, nil, targetSlot)
        created = created + 1
        if i % 5 == 0 then task.wait(0.08) end
    end
    ORBIT.notify("💥 Создано ботов: " .. created, Color3.fromRGB(200, 150, 255), 3)
end

function ORBIT.removeBot(botModel)
    local data = ORBIT.bots[botModel]
    if not data then return end
    pcall(function()
        if data.folder then data.folder:Destroy() end
        if data.model then data.model:Destroy() end
    end)
    ORBIT.bots[botModel] = nil
end

function ORBIT.removeAllBots()
    for m in pairs(ORBIT.bots) do ORBIT.removeBot(m) end
    ORBIT.notify("🗑 Все боты удалены", Color3.fromRGB(255, 180, 180), 2)
end

local function collectBotRing(botModel, data)
    if data.collected then return end
    data.collected = true
    local shapeName = SHAPE_PRESETS[data.shapeIndex] and SHAPE_PRESETS[data.shapeIndex].name or "?"

    local SLOT = data.targetSlot or 2
    SLOT = math.clamp(SLOT, 1, 5)

    rings[SLOT].shapeIndex = data.shapeIndex
    if not rings[SLOT].enabled then
        ORBIT.setRingEnabled(SLOT, true)
    else
        ORBIT.destroyRing(SLOT)
        ORBIT.buildRing(SLOT)
        ORBIT.applyColor()
        ORBIT.applyNameVisibility()
    end

    ORBIT.notify("🎁 " .. shapeName .. " → кольцо " .. SLOT, Color3.fromRGB(255, 220, 100), 3)

    task.spawn(function()
        for i = 1, 10 do
            for _, b in ipairs(data.blocks) do
                if b.isModel and b.model then b.model:ScaleTo(1 - i*0.09)
                elseif b.part then b.part.Transparency = b.part.Transparency + 0.09 end
            end
            task.wait(0.03)
        end
        ORBIT.removeBot(botModel)
    end)
end

local function updateBots(dt)
    if not LocalPlayer.Character then return end
    local myHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    local t = tick() - ORBIT.startTime
    for botModel, data in pairs(ORBIT.bots) do
        if data.collected then continue end
        if not data.model or not data.model.Parent then
            ORBIT.bots[botModel] = nil; continue
        end
        local botRoot = data.model:FindFirstChild("HumanoidRootPart")
        if not botRoot then continue end
        data.angle = data.angle + (data.ringSpeed or ORBIT.botSettings.BotSpeed) * dt
        local radius = data.ringRadius or ORBIT.botSettings.BotRingRadius
        local height = data.ringHeight or ORBIT.botSettings.BotRingHeight
        local count = #data.blocks
        for _, b in ipairs(data.blocks) do
            if not b.part or not b.part.Parent then continue end
            local angle = math.rad(data.angle + b.angleOffset)
            local pos = botRoot.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
            local cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
            if b.isModel and b.model then b.model:PivotTo(cf) else b.part.CFrame = cf end
            local c = Color3.fromHSV((data.hueBase + t * 0.15 + b.index / count) % 1, 0.85, 1)
            if b.bodyParts then
                for _, p in ipairs(b.bodyParts) do
                    if not p:GetAttribute("NoRecolor") then p.Color = c end
                end
            elseif b.part then b.part.Color = c end
        end
        local head = data.model:FindFirstChild("Head")
        if head and not ORBIT.botSettings.UseMySkin then
            head.CFrame = CFrame.new(head.Position) * CFrame.Angles(0, t * 2, 0)
            pcall(function() head.Color = Color3.fromHSV(data.hueBase, 0.75, 1) end)
        end
        local torso = data.model:FindFirstChild("Torso")
        if torso and not ORBIT.botSettings.UseMySkin then
            pcall(function() torso.Color = Color3.fromHSV(data.hueBase, 0.75, 1) end)
        end
        if ORBIT.botSettings.AutoCollect then
            local dx = myHrp.Position.X - botRoot.Position.X
            local dz = myHrp.Position.Z - botRoot.Position.Z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist < ORBIT.botSettings.CollectRadius then
                collectBotRing(botModel, data)
            end
        end
    end
end

function ORBIT.getBotCount()
    local n = 0
    for _ in pairs(ORBIT.bots) do n = n + 1 end
    return n
end

-- ==================== ПАТТЕРНЫ ОРБИТЫ ====================
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
        updateFire()
        updateBots(dt)
        updateTargetRings(dt)

        if SETTINGS.AutoShapeSwap and (tick() - ORBIT.lastAutoSwap) > SETTINGS.AutoShapeSwapInterval then
            ORBIT.lastAutoSwap = tick()
            ORBIT.currentAutoShapeIndex = ORBIT.currentAutoShapeIndex + 1
            if ORBIT.currentAutoShapeIndex > #SHAPE_PRESETS then ORBIT.currentAutoShapeIndex = 1 end
            ORBIT.shapeIndex = ORBIT.currentAutoShapeIndex
            ORBIT.applyShapes(); ORBIT.rebuildAllRings()
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
        ORBIT.notify("🟢 Скрипт включён", Color3.fromRGB(100,255,150))
    else
        ORBIT.stopUpdateLoop()
        if ORBIT.protConn then ORBIT.disableProtection() end
        for ri in pairs(rings) do ORBIT.destroyRing(ri) end
        ORBIT.activeLightCount = 0
        if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
        if ORBIT.fireFolder then ORBIT.fireFolder:Destroy(); ORBIT.fireFolder = nil end
        ORBIT.cleanupAllTargetRings()
        ORBIT.removeAllBots()
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
            if SETTINGS.ProtEnabled then
                PROT_STATE.lastSafePos = nil
                PROT_STATE.lastSafeCFrame = nil
            end
        end
    end)
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
        auraSpinEnabled=SETTINGS.AuraSpinEnabled, auraSpinAxis=SETTINGS.AuraSpinAxis,
        fireEnabled=SETTINGS.FireEnabled, fireSizeIndex=P.fireSizeIndex, fireHeatIndex=P.fireHeatIndex,
        rainbowSpeed=SETTINGS.RainbowSpeed,
        autoShapeSwap=SETTINGS.AutoShapeSwap, autoShapeSwapInterval=SETTINGS.AutoShapeSwapInterval,
        gradientEnabled=SETTINGS.GradientEnabled,
        spinResetting=ORBIT.spinResetting, spinAxisEnabled=ORBIT.spinAxisEnabled, spinAxisDir=ORBIT.spinAxisDir,
        spinSpeedIndex=P.spinSpeedIndex, heartScale=SETTINGS.HeartScale,
        musicEnabled=ORBIT.musicEnabled, musicId=ORBIT.savedMusicId,
        protEnabled=SETTINGS.ProtEnabled, antiKnockback=SETTINGS.AntiKnockback,
        antiTeleport=SETTINGS.AntiTeleport, antiFreeze=SETTINGS.AntiFreeze,
        autoHeal=SETTINGS.AutoHeal, antiVoid=SETTINGS.AntiVoid, antiFling=SETTINGS.AntiFling,
        antiExplosion=SETTINGS.AntiExplosion, lockPosition=SETTINGS.LockPosition,
        useMySkin=ORBIT.botSettings.UseMySkin,
    }
end

local function applySaveData(d)
    if not d then return end
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
    if d.auraSpinEnabled ~= nil then SETTINGS.AuraSpinEnabled = d.auraSpinEnabled end
    if d.auraSpinAxis then SETTINGS.AuraSpinAxis = d.auraSpinAxis end
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
    if d.protEnabled ~= nil then SETTINGS.ProtEnabled = d.protEnabled end
    if d.antiKnockback ~= nil then SETTINGS.AntiKnockback = d.antiKnockback end
    if d.antiTeleport ~= nil then SETTINGS.AntiTeleport = d.antiTeleport end
    if d.antiFreeze ~= nil then SETTINGS.AntiFreeze = d.antiFreeze end
    if d.autoHeal ~= nil then SETTINGS.AutoHeal = d.autoHeal end
    if d.antiVoid ~= nil then SETTINGS.AntiVoid = d.antiVoid end
    if d.antiFling ~= nil then SETTINGS.AntiFling = d.antiFling end
    if d.antiExplosion ~= nil then SETTINGS.AntiExplosion = d.antiExplosion end
    if d.lockPosition ~= nil then SETTINGS.LockPosition = d.lockPosition end
    if d.useMySkin ~= nil then ORBIT.botSettings.UseMySkin = d.useMySkin end
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
    applySaveData(SAVED_DATA)
    return true
end

function ORBIT.saveNamed(name)
    if not name or name == "" then return false, "Пустое имя" end
    ORBIT.SAVES[name] = { data = enc(collectSaveData()), time = os.time() }
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
    if SETTINGS.ProtEnabled then ORBIT.enableProtection() end
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ P3 v21.1 (защита v5 + Auto-Dodge)", Color3.fromRGB(180,255,180), 3) end

return true
