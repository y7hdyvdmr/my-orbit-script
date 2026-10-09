-- ORBIT v24.2 | orbit_anticheat.lua
-- Античит v14.0: 18 защит, анимации защиты, фразы Санса, крестик панели
-- v24.2: добавлен крестик закрытия панели в правом верхнем углу.
-- Автономный: ORBIT может отсутствовать, тогда всё работает без фраз и общих звуков.

local GENV = rawget(_G, "getgenv") and getgenv() or _G

-- ==================== onClick (Android / Delta) ====================
local function getOrbit()
    local ok, o = pcall(function()
        return rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or GENV.ORBIT
    end)
    if ok and type(o) == "table" then return o end
    return nil
end

local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        local O = getOrbit()
        if O and O.playClick then pcall(O.playClick) end
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

-- ==================== защита от повторного запуска ====================
if GENV._ORBIT_AC_LOADED then
    warn("[Orbit AC] Уже запущен! Выгружаю старый...")
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end
GENV._ORBIT_AC_LOADED = true

-- ==================== сервисы ====================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local SoundService     = game:GetService("SoundService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local ContentProvider  = game:GetService("ContentProvider")
local Debris           = game:GetService("Debris")
local UIS              = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

local function getSafeParent()
    local gethuiFn = rawget(GENV, "gethui")
    if type(gethuiFn) == "function" then
        local ok, hui = pcall(gethuiFn)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return PlayerGui
end

local function protectGui(gui)
    if not gui then return end
    local synTbl = rawget(GENV, "syn")
    if type(synTbl) == "table" and type(synTbl.protect_gui) == "function" then
        pcall(synTbl.protect_gui, gui); return
    end
    local protectFn = rawget(GENV, "protect_gui")
    if type(protectFn) == "function" then pcall(protectFn, gui) end
end

-- ==================== трекер подключений ====================
local AC_CONNS = {}
local function track(conn)
    if conn then AC_CONNS[#AC_CONNS + 1] = conn end
    return conn
end

-- ==================== состояние ====================
local AC = {
    lastAttackTime = tick(),
    lastSay        = 0,
    alive          = true,
    lastFx         = 0,
}

-- ==================== настройки ====================
local SETTINGS = {
    Enabled = false, Sounds = true,
    AntiFling = true, AntiVoid = true, AntiTeleport = true, AntiKnockback = true,
    AntiFreeze = true, AntiAnchor = true, AntiInstantKill = true, AntiDropKick = true,
    AntiExplosion = true, AntiSuperRing = true, AntiHomelander = true, AntiGrab = true,
    AntiRagdoll = true, AntiKillaura = true, NoFallDamage = true,
    AutoHeal = false, HealPower = 100, LockPosition = false,
    VisualSphere = false, SphereSize = 8, IntrusionDetect = true,
    Dodge = false, TrollDetect = true, ReverseFling = false,
    DetectSpeed = true, DetectGodMode = true,
    SmartFloorDelay = 5,
    ButtonPosition = UDim2.new(0, 20, 0, 200),
}

local SESSION = { defenses = 0, dodges = 0, cheatersMarked = 0, intrusions = 0, startTime = tick() }
local MARKED = {}
local CHEATER_LOG = {}

-- ==================== звуки ====================
local soundFolder = Instance.new("Folder")
soundFolder.Name = "OrbitAC_Sfx_" .. tostring(math.random(100000, 999999))
soundFolder.Parent = SoundService

local SOUND_IDS = {
    click      = "rbxasset://sounds/button.wav",
    switch     = "rbxasset://sounds/switch.wav",
    signal     = "rbxasset://sounds/electronicpingshort.wav",
    snap       = "rbxasset://sounds/snap.mp3",
    dodge      = "rbxassetid://140721035016341",
    afterDodge = "rbxassetid://6325779988",
    sans       = "rbxassetid://135692693675195",
    laugh      = "rbxassetid://113650760423588",
    bot        = "rbxassetid://12221967",
    intrusion  = "rbxassetid://12221967",
}

local soundTemplates = {}
for name, id in pairs(SOUND_IDS) do
    local s = Instance.new("Sound")
    s.Name = name; s.SoundId = id; s.Volume = 0.5; s.Parent = soundFolder
    soundTemplates[name] = s
end
task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync(soundFolder:GetChildren()) end)
end)

local SOUND_QUEUE = { Playing = false, List = {} }

local function playSound(name, volume, pitch)
    if not SETTINGS.Sounds then return end
    local O = getOrbit()
    if O and O.Sfx and O.Sfx.play then
        local ok = pcall(O.Sfx.play, name, volume or 1, pitch or 1)
        if ok then return end
    end
    local template = soundTemplates[name]
    if not template then return end
    table.insert(SOUND_QUEUE.List, { name = name, volume = volume or 1, pitch = pitch or 1 })
    if not SOUND_QUEUE.Playing then
        task.spawn(function()
            SOUND_QUEUE.Playing = true
            while AC.alive and #SOUND_QUEUE.List > 0 do
                local item = table.remove(SOUND_QUEUE.List, 1)
                local t = soundTemplates[item.name]
                if t then
                    pcall(function()
                        local s = t:Clone()
                        s.Volume = (item.volume or 1) * t.Volume
                        s.PlaybackSpeed = item.pitch or 1
                        s.Parent = soundFolder
                        s:Play()
                        Debris:AddItem(s, 8)
                        task.wait(math.min(s.TimeLength > 0 and s.TimeLength or 0.5, 3))
                    end)
                end
            end
            SOUND_QUEUE.Playing = false
        end)
    end
end

local function sfxClick()  playSound("click", 0.5) end
local function sfxSwitch() playSound("switch", 0.5) end

local lastDodgeSfx = 0
local function sfxDodgeSans()
    if not SETTINGS.Sounds then return end
    local now = tick()
    if now - lastDodgeSfx < 1.5 then return end
    lastDodgeSfx = now
    local O = getOrbit()
    if O and type(O.playDodge) == "function" then
        pcall(O.playDodge)
        return
    end
    playSound("dodge", 1, 1)
    playSound(math.random() < 0.5 and "sans" or "laugh", 0.8, 1)
end

local function sfxSmartFloor() sfxDodgeSans() end
local function sfxIntrusion() playSound("intrusion", 0.7, 1.5) end
local function sfxMarkCheater() playSound("signal", 0.4, 0.8) end

-- ==================== фразы Санса ====================
local function onAttack()
    AC.lastAttackTime = tick()
    local O = getOrbit()
    if O and O.sans and O.sans.noteAttack and O.mode ~= "normal" then
        pcall(O.sans.noteAttack)
    end
end

local function sayVictory()
    local O = getOrbit()
    if O and O.sans and O.sans.say and O.mode ~= "normal" then
        local now = tick()
        if now - AC.lastSay >= 10 then
            AC.lastSay = now
            pcall(O.sans.say, "victory")
        end
    end
end

local function abilityMoving()
    local O = getOrbit()
    return O and O.abilityMoveUntil and tick() < O.abilityMoveUntil or false
end

-- ==================== анимация защиты ====================
local fxFolder = nil
local function getFxFolder()
    if fxFolder and fxFolder.Parent then return fxFolder end
    fxFolder = Instance.new("Folder")
    fxFolder.Name = "OrbitAC_Fx_" .. tostring(math.random(100000, 999999))
    fxFolder.Parent = Workspace
    return fxFolder
end

local function protectFx(char)
    if not AC.alive or not char then return end
    local now = tick()
    if now - AC.lastFx < 0.8 then return end
    AC.lastFx = now
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    task.spawn(function()
        local saved = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then
                saved[p] = p.Transparency
            end
        end
        for i = 1, 3 do
            if not AC.alive then break end
            for p in pairs(saved) do if p.Parent then p.Transparency = 0.2 end end
            task.wait(0.085)
            for p in pairs(saved) do if p.Parent then p.Transparency = 0 end end
            task.wait(0.04)
            for p in pairs(saved) do if p.Parent then p.Transparency = 0.2 end end
            task.wait(0.04)
        end
        for p, orig in pairs(saved) do if p.Parent then p.Transparency = orig end end
    end)

    pcall(function()
        local dome = Instance.new("Part")
        dome.Name = "AcDome"
        dome.Shape = Enum.PartType.Ball
        dome.Size = Vector3.new(12, 12, 12)
        dome.Material = Enum.Material.ForceField
        dome.Color = Color3.fromRGB(0, 170, 255)
        dome.Transparency = 0.7
        dome.Anchored = true
        dome.CanCollide = false
        dome.CanQuery = false
        dome.CanTouch = false
        dome.CastShadow = false
        dome.CFrame = hrp.CFrame
        dome.Parent = getFxFolder()
        Debris:AddItem(dome, 1)
    end)

    pcall(function()
        local sp = Instance.new("Part")
        sp.Name = "AcSparks"
        sp.Shape = Enum.PartType.Ball
        sp.Size = Vector3.new(0.2, 0.2, 0.2)
        sp.Material = Enum.Material.Neon
        sp.Color = Color3.fromRGB(255, 240, 150)
        sp.Anchored = true
        sp.CanCollide = false
        sp.CanQuery = false
        sp.CanTouch = false
        sp.Transparency = 1
        sp.CFrame = hrp.CFrame
        sp.Parent = getFxFolder()
        local em = Instance.new("ParticleEmitter")
        em.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
        em.LightEmission = 1
        em.Size = NumberSequence.new(0.5, 0)
        em.Lifetime = NumberRange.new(0.4, 0.9)
        em.Speed = NumberRange.new(8, 18)
        em.SpreadAngle = Vector2.new(180, 180)
        em.Rate = 0
        em.Parent = sp
        em:Emit(20)
        Debris:AddItem(sp, 1.5)
    end)
end

-- ==================== визуальная сфера ====================
local sphereModel, spherePart = nil, nil

local function createSphere()
    if sphereModel then sphereModel:Destroy() end
    sphereModel = Instance.new("Model")
    sphereModel.Name = "OrbitAC_Sphere"
    sphereModel.Parent = Workspace
    spherePart = Instance.new("Part")
    spherePart.Name = "Sphere"
    spherePart.Shape = Enum.PartType.Ball
    spherePart.Size = Vector3.new(SETTINGS.SphereSize, SETTINGS.SphereSize, SETTINGS.SphereSize)
    spherePart.Material = Enum.Material.ForceField
    spherePart.Color = Color3.fromRGB(0, 150, 255)
    spherePart.Transparency = 0.5
    spherePart.Anchored = true
    spherePart.CanCollide = false
    spherePart.CastShadow = false
    spherePart.CanQuery = false
    spherePart.CanTouch = false
    spherePart.Parent = sphereModel
end

local function killSphere()
    if sphereModel then pcall(function() sphereModel:Destroy() end) end
    sphereModel, spherePart = nil, nil
end

local function updateSphere()
    if not SETTINGS.VisualSphere then killSphere(); return end
    if not spherePart or not spherePart.Parent then createSphere() end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and spherePart then spherePart.CFrame = hrp.CFrame end
end

-- ==================== forward-декларация notify ====================
local notify

-- ==================== детект вторжения ====================
local INTRUSION_TRACK = { LastCheck = 0, Cooldown = {}, WasInside = {} }
local friendCache = {}
local function isFriendOf(plr)
    local c = friendCache[plr]
    if c ~= nil then return c end
    local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end)
    friendCache[plr] = (ok and res) == true
    return friendCache[plr]
end
local trollStrikes = {}

local function checkIntrusion()
    if not SETTINGS.Enabled or not SETTINGS.IntrusionDetect then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local now = tick()
    local radius = SETTINGS.SphereSize / 2
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local other = plr.Character
        local otherHrp = other and other:FindFirstChild("HumanoidRootPart")
        if not otherHrp then continue end
        local dist = (otherHrp.Position - hrp.Position).Magnitude
        local inside = dist <= radius and not isFriendOf(plr)
        if inside and not INTRUSION_TRACK.WasInside[plr] then
            INTRUSION_TRACK.WasInside[plr] = true
            SESSION.intrusions = SESSION.intrusions + 1
            if not INTRUSION_TRACK.Cooldown[plr] or now - INTRUSION_TRACK.Cooldown[plr] > 5 then
                INTRUSION_TRACK.Cooldown[plr] = now
                sfxIntrusion()
                notify("⚠️ Вторжение: " .. plr.Name, Color3.fromRGB(255, 150, 150), 2)
                print("[OrbitAC] 🚨 Вторжение: " .. plr.Name .. " (дист: " .. math.floor(dist) .. ")")
                if SETTINGS.Dodge then
                    local away = (hrp.Position - otherHrp.Position).Unit
                    local target = hrp.Position + away * 12
                    pcall(function()
                        char:PivotTo(CFrame.new(target))
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
        elseif not inside and INTRUSION_TRACK.WasInside[plr] then
            INTRUSION_TRACK.WasInside[plr] = nil
        end
    end
end

-- ==================== состояние / конфиг ====================
local STATE = {
    lastSafePosition = nil, lastSafeCFrame = nil, lastCheckTime = 0, lastHealTime = 0,
    lastHealth = 100, lastKnockbackTime = 0, lastFreezeTime = 0, spawnGrace = 0,
    lastHealthCheck = 0, lastScan = 0, lastPositions = {}, godModeWarning = {},
    voidTimer = 0, lastFloorCheck = 0, lastHrp = nil, dropKickWarning = {},
    jumpCounter = 0, blockedFlings = 0, groundTime = 0, charConnection = nil,
    lastSmartFloor = 0, healthConn = nil, lastHumHealth = nil,
}

local CONFIG = {
    MAX_SPEED = 60, MAX_JUMP = 100, FLING_SPEED_THRESHOLD = 200, FLING_ROT_THRESHOLD = 100,
    INSTANT_FLING = 100000, TELEPORT_DISTANCE = 30, VOID_TIMER = 0.5, FAST_FALL_VY = -50,
    FLOOR_RAY_LENGTH = 500, FLOOR_RAY_SIDE = 100, MIN_GROUND_TIME = 1.0, SMART_FLOOR_COOLDOWN = 3,
}

local BAD_CLASSES = {
    BodyVelocity = true, BodyForce = true, BodyAngularVelocity = true, BodyGyro = true,
    BodyPosition = true, BodyThrust = true, LinearVelocity = true, AngularVelocity = true,
    VectorForce = true, Torque = true, AlignPosition = true, AlignOrientation = true,
}

-- ==================== утилиты ====================
local function log(text) print("[OrbitAC] " .. text) end

local function destroyObj(obj)
    if not obj or not obj.Parent then return end
    pcall(function() obj:Destroy() end)
end

local function zeroVelocity(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end

local function isOnGround(hrp)
    if not hrp then return false end
    local char = hrp.Parent
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if math.abs(hrp.AssemblyLinearVelocity.Y) > 0.5 then return false end
    local state = hum:GetState()
    if state ~= Enum.HumanoidStateType.Running
       and state ~= Enum.HumanoidStateType.RunningNoPhysics
       and state ~= Enum.HumanoidStateType.Seated
       and state ~= Enum.HumanoidStateType.PlatformStanding
       and state ~= Enum.HumanoidStateType.Climbing then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    return Workspace:Raycast(hrp.Position, Vector3.new(0, -4, 0), params) ~= nil
end

local function isInAir(hrp)
    if not hrp then return false end
    local char = hrp.Parent
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local state = hum:GetState()
    return state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Freefall
        or state == Enum.HumanoidStateType.Flying
end

local function getSafeFloor()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
    local origin = hrp.Position + Vector3.new(0, 20, 0)
    local ray = Workspace:Raycast(origin, Vector3.new(0, -CONFIG.FLOOR_RAY_LENGTH, 0), params)
    if ray then return ray.Position + Vector3.new(0, 4, 0) end
    local directions = {
        Vector3.new(0, -CONFIG.FLOOR_RAY_SIDE, 30), Vector3.new(0, -CONFIG.FLOOR_RAY_SIDE, -30),
        Vector3.new(30, -CONFIG.FLOOR_RAY_SIDE, 0), Vector3.new(-30, -CONFIG.FLOOR_RAY_SIDE, 0),
    }
    for _, dir in ipairs(directions) do
        local r = Workspace:Raycast(origin, dir, params)
        if r then return r.Position + Vector3.new(0, 4, 0) end
    end
    if STATE.lastSafeCFrame then
        local p = STATE.lastSafeCFrame.Position
        return Vector3.new(p.X, math.max(p.Y, 10), p.Z)
    end
    return Vector3.new(0, 50, 0)
end

local function disableFallDamage(char)
    if not SETTINGS.NoFallDamage then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
end

local function hookHealth(char)
    if STATE.healthConn then pcall(function() STATE.healthConn:Disconnect() end); STATE.healthConn = nil end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    STATE.lastHumHealth = hum.Health
    STATE.healthConn = hum.HealthChanged:Connect(function(h)
        if not SETTINGS.Enabled then STATE.lastHumHealth = h; return end
        if STATE.lastHumHealth and h < STATE.lastHumHealth then onAttack() end
        STATE.lastHumHealth = h
    end)
end

-- ==================== пометка читера ====================
local function markCheater(plr, enable)
    if not plr or plr == LocalPlayer then return false end
    if enable then
        MARKED[plr] = true
        CHEATER_LOG[plr.UserId] = { name = plr.Name, time = os.time() }
        SESSION.cheatersMarked = SESSION.cheatersMarked + 1
        warn("[OrbitAC] Помечен: " .. plr.Name)
        sfxMarkCheater()
        if notify then notify("🚩 Помечен: " .. plr.Name, Color3.fromRGB(255, 120, 120)) end
    else
        MARKED[plr] = nil
        CHEATER_LOG[plr.UserId] = nil
    end
    return true
end

-- ==================== функции защиты ====================
local function antiDropKick(char, hrp, now)
    if not SETTINGS.AntiDropKick then return end
    if abilityMoving() then STATE.lastHrp = hrp.CFrame; STATE.jumpCounter = 0; return end
    local current = hrp.CFrame
    if STATE.lastHrp then
        local dist = (current.Position - STATE.lastHrp.Position).Magnitude
        if dist > CONFIG.TELEPORT_DISTANCE and not isInAir(hrp) then
            STATE.jumpCounter = STATE.jumpCounter + 1
            if STATE.jumpCounter >= 2 then
                if STATE.lastSafeCFrame then
                    pcall(function() char:PivotTo(STATE.lastSafeCFrame); zeroVelocity(char) end)
                    SESSION.defenses = SESSION.defenses + 1
                    STATE.blockedFlings = STATE.blockedFlings + 1
                    sfxDodgeSans()
                end
                STATE.jumpCounter = 0
            end
        else
            STATE.jumpCounter = 0
        end
    end
    STATE.lastHrp = current
    if hrp.Anchored and not isInAir(hrp) then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.MoveDirection.Magnitude > 0.05 then
            pcall(function() hrp.Anchored = false end)
            SESSION.defenses = SESSION.defenses + 1
        end
    end
end

local function antiFling(char, hrp)
    if not SETTINGS.AntiFling then return end
    if abilityMoving() then return end
    if isInAir(hrp) then return end
    pcall(function()
        local spd = hrp.AssemblyLinearVelocity.Magnitude
        local rot = hrp.AssemblyAngularVelocity.Magnitude
        if spd > CONFIG.INSTANT_FLING or rot > CONFIG.INSTANT_FLING then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if STATE.lastSafeCFrame then pcall(function() char:PivotTo(STATE.lastSafeCFrame) end) end
            SESSION.defenses = SESSION.defenses + 1
            protectFx(char)
            onAttack()
            sfxDodgeSans()
            return
        end
        if spd > CONFIG.FLING_SPEED_THRESHOLD and rot > CONFIG.FLING_ROT_THRESHOLD then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            SESSION.defenses = SESSION.defenses + 1
            protectFx(char)
            onAttack()
            sfxDodgeSans()
        end
    end)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local other = plr.Character
        local otherHrp = other and other:FindFirstChild("HumanoidRootPart")
        if not otherHrp then continue end
        local otherRot = otherHrp.AssemblyAngularVelocity.Magnitude
        local otherSpd = otherHrp.AssemblyLinearVelocity.Magnitude
        if otherRot > CONFIG.FLING_ROT_THRESHOLD * 2 or otherSpd > CONFIG.FLING_SPEED_THRESHOLD * 2 then
            if not STATE.dropKickWarning[plr] then
                STATE.dropKickWarning[plr] = tick()
                markCheater(plr, true)
            end
        end
    end
end

local function antiFreeze(char)
    if not SETTINGS.AntiFreeze then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.WalkSpeed < 1 then hum.WalkSpeed = 16 end
            if hum.JumpPower < 1 then hum.JumpPower = 50 end
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                    local nm = tr.Animation and tr.Animation.Name or ""
                    if nm:lower():find("laugh") then tr:Stop(0) end
                end
            end
        end)
    end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored and p.Name ~= "HumanoidRootPart" then
            pcall(function() p.Anchored = false end)
        end
    end
end

local function antiKnockback(char)
    if not SETTINGS.AntiKnockback then return end
    local found = false
    for _, child in ipairs(char:GetDescendants()) do
        if BAD_CLASSES[child.ClassName] then destroyObj(child); found = true end
    end
    if found then
        protectFx(char)
        onAttack()
    end
end

local function antiAnchor(char)
    if not SETTINGS.AntiAnchor then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Anchored then
        pcall(function() hrp.Anchored = false end)
        SESSION.defenses = SESSION.defenses + 1
    end
end

local function antiInstantKill(char)
    if not SETTINGS.AntiInstantKill then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    local now = tick()
    if isOnGround(hrp) and STATE.lastHealth > 50 and hum.Health < 10
       and (now - (STATE.lastHealthCheck or 0)) < 0.15 then
        if STATE.lastSafeCFrame then
            pcall(function() char:PivotTo(STATE.lastSafeCFrame) end)
            zeroVelocity(char)
            SESSION.defenses = SESSION.defenses + 1
        end
    end
    STATE.lastHealth = hum.Health
    STATE.lastHealthCheck = now
end

local function antiVoid(char, hrp, dt)
    if not SETTINGS.AntiVoid then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if isOnGround(hrp) then STATE.voidTimer = 0; return end
    local vy = hrp.AssemblyLinearVelocity.Y
    local y = hrp.Position.Y
    local falling = false
    if y < -100 then
        falling = true
    elseif vy < CONFIG.FAST_FALL_VY then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}
        local ray = Workspace:Raycast(hrp.Position, Vector3.new(0, -CONFIG.FLOOR_RAY_LENGTH, 0), params)
        if not ray then falling = true end
    end
    if not falling then STATE.voidTimer = 0; return end
    local now = tick()
    if now - (STATE.lastSmartFloor or 0) < CONFIG.SMART_FLOOR_COOLDOWN then STATE.voidTimer = 0; return end
    STATE.voidTimer = STATE.voidTimer + (dt or 0.1)
    if STATE.voidTimer > CONFIG.VOID_TIMER then
        local safe = getSafeFloor()
        if safe and safe.Y > y + 3 then
            STATE.lastSmartFloor = now
            pcall(function() char:PivotTo(CFrame.new(safe)); zeroVelocity(char) end)
            warn("[OrbitAC] Умный Пол спас с Y=" .. math.floor(y))
            protectFx(char)
            sfxSmartFloor()
            notify("🛡 Умный Пол спас!", Color3.fromRGB(120, 255, 180), 2)
            SESSION.defenses = SESSION.defenses + 1
        end
        STATE.voidTimer = 0
    end
end

local function antiTeleport(char, hrp)
    if not SETTINGS.AntiTeleport then return end
    if abilityMoving() then return end
    if not STATE.lastSafePosition then return end
    if not isOnGround(hrp) then return end
    if STATE.groundTime < CONFIG.MIN_GROUND_TIME then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    local dx = hrp.Position.X - STATE.lastSafePosition.X
    local dz = hrp.Position.Z - STATE.lastSafePosition.Z
    if math.sqrt(dx * dx + dz * dz) > 250 then
        pcall(function() char:PivotTo(STATE.lastSafeCFrame + Vector3.new(0, 2, 0)) end)
        zeroVelocity(char)
        SESSION.defenses = SESSION.defenses + 1
        protectFx(char)
        onAttack()
    end
end

local function autoHeal(char)
    if not SETTINGS.AutoHeal then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < hum.MaxHealth and hum.Health > 0 then
        pcall(function() hum.Health = math.min(hum.MaxHealth, hum.Health + SETTINGS.HealPower) end)
    end
end

local function lockPosition(char, hrp)
    if not SETTINGS.LockPosition then return end
    if not isOnGround(hrp) then return end
    if STATE.groundTime < CONFIG.MIN_GROUND_TIME then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MoveDirection.Magnitude > 0.05 then return end
    if STATE.lastSafeCFrame then pcall(function() char:PivotTo(STATE.lastSafeCFrame) end) end
end

local superRingRunning = false
local function antiSuperRing()
    if superRingRunning then return end
    superRingRunning = true
    task.spawn(function()
        while AC.alive do
            task.wait(0.2)
            if SETTINGS.Enabled and SETTINGS.AntiSuperRing then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored then
                        local parent = obj.Parent
                        local skip = false
                        if parent and parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then skip = true end
                        if not skip then
                            for _, ch in ipairs(obj:GetChildren()) do
                                if ch:IsA("AlignPosition") or ch:IsA("Torque") then
                                    pcall(function() ch:Destroy() end)
                                end
                            end
                        end
                    end
                end
            end
        end
        superRingRunning = false
    end)
end

local function antiHomelander(char, hrp)
    if not SETTINGS.AntiHomelander then return end
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("LinearVelocity") then
            local vel = v.Velocity or v.LineVelocity
            if vel and vel.Magnitude > 200 then
                destroyObj(v)
                SESSION.defenses = SESSION.defenses + 1
            end
        end
    end
    local parts = Workspace:GetPartBoundsInRadius(hrp.Position, 6, OverlapParams.new())
    for _, obj in ipairs(parts) do
        if obj:IsA("BasePart") and obj ~= hrp then
            local owner = Players:GetPlayerFromCharacter(obj.Parent)
            if owner and owner ~= LocalPlayer and obj.AssemblyLinearVelocity.Magnitude > 250 then
                pcall(function()
                    obj.AssemblyLinearVelocity = Vector3.zero
                    obj.AssemblyAngularVelocity = Vector3.zero
                end)
                markCheater(owner, true)
            end
        end
    end
end

local function antiGrab(char, hrp)
    if not SETTINGS.AntiGrab then return end
    for _, v in ipairs(hrp:GetChildren()) do
        if v:IsA("WeldConstraint") or v:IsA("Weld") or v:IsA("ManualWeld") or v:IsA("Motor6D") then
            local p0, p1 = v.Part0, v.Part1
            if p0 and p1 then
                local other = (p0 == hrp) and p1 or p0
                if other and other.Parent then
                    local owner = Players:GetPlayerFromCharacter(other.Parent)
                    if owner and owner ~= LocalPlayer then
                        destroyObj(v)
                        SESSION.defenses = SESSION.defenses + 1
                        markCheater(owner, true)
                        onAttack()
                        sayVictory()
                    end
                end
            end
        end
    end
end

local function antiRagdoll(char)
    if not SETTINGS.AntiRagdoll then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        SESSION.defenses = SESSION.defenses + 1
    end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BallSocketConstraint") or v:IsA("NoCollisionConstraint") then destroyObj(v) end
    end
end

local function antiKillaura(char, hrp)
    if not SETTINGS.AntiKillaura then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local hst = hum:GetState()
    local fallish = (hst == Enum.HumanoidStateType.Freefall or hst == Enum.HumanoidStateType.Landed
        or hst == Enum.HumanoidStateType.FallingDown or hst == Enum.HumanoidStateType.Dead)
    if not fallish and hum.Health < (STATE.lastHealth or 100) - 20 then
        local closest, closestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local oHrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if oHrp and not isFriendOf(plr) then
                    local d = (oHrp.Position - hrp.Position).Magnitude
                    if d < closestDist then closest, closestDist = plr, d end
                end
            end
        end
        if closest and closestDist < 10 then
            markCheater(closest, true)
            local away = (hrp.Position - closest.Character.HumanoidRootPart.Position).Unit
            pcall(function() char:PivotTo(CFrame.new(hrp.Position + away * 5)) end)
            SESSION.defenses = SESSION.defenses + 1
            onAttack()
            sayVictory()
        end
    end
    STATE.lastHealth = hum.Health
end

-- ==================== уклонение ====================
local dodgeConnection = nil
local dodgeParams = OverlapParams.new()
dodgeParams.FilterType = Enum.RaycastFilterType.Exclude
local lastDodgeScan = 0
local DODGE = { Enabled = false, Radius = 25, SpeedThreshold = 25, Distance = 15, Cooldown = 0.35, LastTime = 0 }

local function setupDodge()
    if dodgeConnection then dodgeConnection:Disconnect(); dodgeConnection = nil end
    dodgeConnection = RunService.Heartbeat:Connect(function()
        if not SETTINGS.Enabled or not DODGE.Enabled then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or isInAir(hrp) then return end
        local now = tick()
        if now - DODGE.LastTime < DODGE.Cooldown then return end
        if now - lastDodgeScan < 0.05 then return end
        lastDodgeScan = now
        dodgeParams.FilterDescendantsInstances = {char}
        local threats = {}
        local myPos = hrp.Position
        local parts = Workspace:GetPartBoundsInRadius(myPos, DODGE.Radius, dodgeParams)
        for _, obj in ipairs(parts) do
            if obj:IsA("BasePart") and obj.Parent ~= char then
                if not obj.Anchored then
                    local spd = obj.AssemblyLinearVelocity
                    if spd.Magnitude > DODGE.SpeedThreshold then
                        local toMe = myPos - obj.Position
                        if toMe.Magnitude > 0.1 and spd.Unit:Dot(toMe.Unit) > 0.4 then
                            table.insert(threats, { obj = obj, dist = toMe.Magnitude })
                        end
                    end
                end
                local parent = obj.Parent
                if parent and parent:IsA("Model") and parent ~= char then
                    local otherHum = parent:FindFirstChildOfClass("Humanoid")
                    if otherHum and otherHum.Health > 0 then
                        local otherRoot = parent:FindFirstChild("HumanoidRootPart")
                        if otherRoot then
                            local spd = otherRoot.AssemblyLinearVelocity
                            local rot = otherRoot.AssemblyAngularVelocity
                            if spd.Magnitude > DODGE.SpeedThreshold * 2 or rot.Magnitude > DODGE.SpeedThreshold then
                                table.insert(threats, { obj = otherRoot, dist = (otherRoot.Position - myPos).Magnitude })
                            end
                        end
                    end
                end
            end
        end
        if #threats == 0 then return end
        table.sort(threats, function(a, b) return a.dist < b.dist end)
        local threat = threats[1]
        local dir = (threat.obj.Position - myPos).Unit
        local right = dir:Cross(Vector3.new(0, 1, 0)).Unit
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
        local rayRight = Workspace:Raycast(myPos, right * DODGE.Distance, params)
        local dodgeDir = rayRight and -right or right
        local target = myPos + dodgeDir * DODGE.Distance
        local rayDown = Workspace:Raycast(target + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), params)
        if rayDown then target = rayDown.Position + Vector3.new(0, 3, 0) end
        pcall(function()
            char:PivotTo(CFrame.new(target))
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        DODGE.LastTime = now
        SESSION.dodges = SESSION.dodges + 1
        onAttack()
        sfxDodgeSans()
        notify("🥷 Уклонение!", Color3.fromRGB(150, 220, 255), 1.5)
    end)
end

-- ==================== детект троллинга ====================
local TROLLING = { Enabled = true, LastScan = 0, Cooldown = {} }

local function detectTrolling()
    if not SETTINGS.Enabled or not TROLLING.Enabled then return end
    local now = tick()
    if now - TROLLING.LastScan < 0.2 then return end
    TROLLING.LastScan = now
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local other = plr.Character
        local otherHrp = other and other:FindFirstChild("HumanoidRootPart")
        if not otherHrp then continue end
        local dist = (otherHrp.Position - hrp.Position).Magnitude
        if dist < 8 and not isFriendOf(plr) then
            local spd = otherHrp.AssemblyLinearVelocity.Magnitude
            local rot = otherHrp.AssemblyAngularVelocity.Magnitude
            local otherHum = other:FindFirstChildOfClass("Humanoid")
            local st = otherHum and otherHum:GetState()
            local innocent = (st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Seated
                or st == Enum.HumanoidStateType.Landed or st == Enum.HumanoidStateType.Dead)
            if (spd > 70 or rot > 35) and not innocent then
                trollStrikes[plr] = (trollStrikes[plr] or 0) + 1
                if trollStrikes[plr] >= 3 and (not TROLLING.Cooldown[plr] or now - TROLLING.Cooldown[plr] > 4) then
                    TROLLING.Cooldown[plr] = now
                    trollStrikes[plr] = 0
                    sfxDodgeSans()
                    notify("⚠️ Троллинг: " .. plr.Name, Color3.fromRGB(255, 150, 150), 2)
                end
            else
                trollStrikes[plr] = 0
            end
        end
    end
end

-- ==================== ответный флинг ====================
local REVERSE = { Enabled = false, RotLimit = 20 * 2 * math.pi, FlingPower = 500, LastCheck = 0, Interval = 0.3, Detected = {} }

local function reverseFling(plr)
    if not plr or plr == LocalPlayer then return end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        hrp.AssemblyAngularVelocity = Vector3.new(math.random(-1, 1) * 1000, math.random(-1, 1) * 1000, math.random(-1, 1) * 1000)
        hrp.AssemblyLinearVelocity = Vector3.new(0, REVERSE.FlingPower, 0)
    end)
    log("🚨 ОТВЕТНЫЙ ФЛИНГ: " .. plr.Name)
end

local function scanFlingers()
    if not REVERSE.Enabled then return end
    local now = tick()
    if now - REVERSE.LastCheck < REVERSE.Interval then return end
    REVERSE.LastCheck = now
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local rot = hrp.AssemblyAngularVelocity
        if math.abs(rot.X) > REVERSE.RotLimit or math.abs(rot.Y) > REVERSE.RotLimit or math.abs(rot.Z) > REVERSE.RotLimit then
            if not REVERSE.Detected[plr] then
                REVERSE.Detected[plr] = now
                reverseFling(plr)
            end
        end
    end
    for p, t in pairs(REVERSE.Detected) do
        if now - t > 5 then REVERSE.Detected[p] = nil end
    end
end

-- ==================== основной цикл защиты ====================
local function handleProtection(dt, char, hrp)
    local now = tick()
    local airFlag = isInAir(hrp)
    if isOnGround(hrp) then STATE.groundTime = STATE.groundTime + dt else STATE.groundTime = 0 end

    antiDropKick(char, hrp, now)
    antiFling(char, hrp)
    antiAnchor(char)
    if now - STATE.lastKnockbackTime >= 0.1 then STATE.lastKnockbackTime = now; antiKnockback(char) end
    if now - STATE.lastFreezeTime >= 0.25 then STATE.lastFreezeTime = now; antiFreeze(char) end
    if SETTINGS.AutoHeal and now - STATE.lastHealTime >= 0.3 then STATE.lastHealTime = now; autoHeal(char) end

    antiVoid(char, hrp, dt)
    antiHomelander(char, hrp)
    antiGrab(char, hrp)
    antiRagdoll(char)
    antiKillaura(char, hrp)

    local inGrace = (now - STATE.spawnGrace) < 5.0
    if not inGrace and not airFlag then
        antiTeleport(char, hrp)
        lockPosition(char, hrp)
    end
    antiInstantKill(char)
    pcall(detectTrolling)
    pcall(checkIntrusion)

    if now - STATE.lastScan > 0.5 then
        STATE.lastScan = now
        if SETTINGS.DetectSpeed then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local other = plr.Character
                    local otherHrp = other and other:FindFirstChild("HumanoidRootPart")
                    if otherHrp then
                        local last = STATE.lastPositions[plr]
                        if last then
                            local dt2 = now - last.time
                            if dt2 > 0.1 and dt2 < 1 then
                                local spd = (otherHrp.Position - last.pos).Magnitude / dt2
                                if spd > 150 then markCheater(plr, true) end
                            end
                        end
                        STATE.lastPositions[plr] = { pos = otherHrp.Position, time = now }
                    end
                end
            end
        end
        pcall(scanFlingers)
    end

    if now - STATE.lastCheckTime > 0.2 then
        STATE.lastCheckTime = now
        local hum = char:FindFirstChildOfClass("Humanoid")
        local vy = math.abs(hrp.AssemblyLinearVelocity.Y)
        if hum and hum.Health > 0 and not airFlag and vy < 1.0 and isOnGround(hrp) then
            STATE.lastSafePosition = hrp.Position
            local lv = hrp.CFrame.LookVector
            local yaw = math.atan2(-lv.X, -lv.Z)
            STATE.lastSafeCFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
        end
    end
end

local protectionConnection = nil

local function enableProtection()
    if protectionConnection then protectionConnection:Disconnect(); protectionConnection = nil end
    if not SETTINGS.Enabled then return end
    STATE.lastSafePosition = nil; STATE.lastSafeCFrame = nil
    STATE.lastCheckTime = 0; STATE.lastHealTime = 0; STATE.lastHealth = 100
    STATE.lastKnockbackTime = 0; STATE.lastFreezeTime = 0; STATE.spawnGrace = tick()
    STATE.lastPositions = {}; STATE.godModeWarning = {}; STATE.voidTimer = 0
    STATE.lastHrp = nil; STATE.jumpCounter = 0; STATE.groundTime = 0; STATE.lastSmartFloor = 0
    AC.lastAttackTime = tick()

    if LocalPlayer.Character then
        antiKnockback(LocalPlayer.Character)
        disableFallDamage(LocalPlayer.Character)
        hookHealth(LocalPlayer.Character)
    end
    if STATE.charConnection then STATE.charConnection:Disconnect() end
    STATE.charConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
        STATE.lastHrp = nil; STATE.spawnGrace = tick()
        STATE.lastSafePosition = nil; STATE.lastSafeCFrame = nil
        STATE.groundTime = 0; STATE.lastSmartFloor = 0
        task.wait(0.5)
        disableFallDamage(newChar)
        hookHealth(newChar)
    end)

    setupDodge()
    antiSuperRing()

    protectionConnection = RunService.Heartbeat:Connect(function(dt)
        if not SETTINGS.Enabled then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(handleProtection, dt, char, hrp)
    end)
    notify("🛡 Анти-Чит v14.0 ВКЛ", Color3.fromRGB(120, 255, 180), 3)
    log("Анти-Чит v14.0 активен.")
end

local function disableProtection()
    if STATE.charConnection then STATE.charConnection:Disconnect(); STATE.charConnection = nil end
    if protectionConnection then protectionConnection:Disconnect(); protectionConnection = nil end
    if dodgeConnection then dodgeConnection:Disconnect(); dodgeConnection = nil end
    if STATE.healthConn then pcall(function() STATE.healthConn:Disconnect() end); STATE.healthConn = nil end
    STATE.lastSafePosition = nil
    STATE.lastSafeCFrame = nil
end

track(Workspace.DescendantAdded:Connect(function(obj)
    if not SETTINGS.Enabled or not SETTINGS.AntiExplosion then return end
    if obj:IsA("Explosion") then
        task.defer(function() pcall(function() obj:Destroy() end) end)
    end
end))

-- ==================== таймер бездействия ====================
task.spawn(function()
    while AC.alive do
        task.wait(2)
        if AC.alive and SETTINGS.Enabled and tick() - AC.lastAttackTime >= 60 then
            local O = getOrbit()
            if O and O.sans and O.sans.say and O.mode ~= "normal" then
                pcall(O.sans.say, "idle")
            end
            AC.lastAttackTime = tick()
        end
    end
end)

-- ==================== UI ====================
local screen = Instance.new("ScreenGui")
screen.Name = "_OrbitAC_" .. tostring(math.random(100000, 999999))
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 9999
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(screen)
local okParent = pcall(function() screen.Parent = getSafeParent() end)
if not okParent or not screen.Parent then screen.Parent = PlayerGui end

local mainButton = Instance.new("TextButton")
mainButton.Size = UDim2.new(0, 56, 0, 56)
mainButton.Position = SETTINGS.ButtonPosition
mainButton.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
mainButton.BackgroundTransparency = 0.1
mainButton.TextColor3 = Color3.fromRGB(255, 180, 180)
mainButton.Font = Enum.Font.GothamBold
mainButton.TextSize = 24
mainButton.Text = "🛡"
mainButton.AutoButtonColor = false
mainButton.Parent = screen
mainButton:SetAttribute("ReleaseOnly", true)
Instance.new("UICorner", mainButton).CornerRadius = UDim.new(0, 14)
local btnStroke = Instance.new("UIStroke", mainButton)
btnStroke.Color = Color3.fromRGB(255, 100, 100)
btnStroke.Thickness = 1.5

local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 300, 0, 600)
panel.Position = UDim2.new(0, 90, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 1700)
panel.ScrollBarThickness = 4
panel.ScrollBarImageColor3 = Color3.fromRGB(255, 100, 100)
panel.Parent = screen
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(255, 100, 100)
panelStroke.Thickness = 1

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 30)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "🛡  ОРБИТА АНТИ-ЧИТ v14.0"
title.TextColor3 = Color3.fromRGB(255, 200, 200)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = panel

-- ✨ КРЕСТИК ЗАКРЫТИЯ ПАНЕЛИ
local panelCloseX = Instance.new("TextButton")
panelCloseX.Name = "PanelCloseX"
panelCloseX.Size = UDim2.new(0, 28, 0, 28)
panelCloseX.Position = UDim2.new(1, -34, 0, 6)
panelCloseX.BackgroundColor3 = Color3.fromRGB(120, 40, 50)
panelCloseX.BackgroundTransparency = 0.1
panelCloseX.TextColor3 = Color3.fromRGB(255, 160, 160)
panelCloseX.Font = Enum.Font.GothamBold
panelCloseX.TextSize = 16
panelCloseX.Text = "✖"
panelCloseX.AutoButtonColor = false
panelCloseX.ZIndex = 5
panelCloseX.Parent = panel
Instance.new("UICorner", panelCloseX).CornerRadius = UDim.new(0, 8)
local pcxStroke = Instance.new("UIStroke", panelCloseX)
pcxStroke.Color = Color3.fromRGB(255, 100, 100)
pcxStroke.Thickness = 1
pcxStroke.Transparency = 0.3

-- раскладка
local curY = 42

local function createSection(text, color)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 28)
    frame.Position = UDim2.new(0, 10, 0, curY)
    frame.BackgroundColor3 = color or Color3.fromRGB(80, 40, 40)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0
    frame.Parent = panel
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, -8)
    bar.Position = UDim2.new(0, 4, 0, 4)
    bar.BackgroundColor3 = color or Color3.fromRGB(255, 100, 100)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -14, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(240, 240, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame
    curY = curY + 32
end

local GREEN_BG, GREEN_TX = Color3.fromRGB(35, 50, 35), Color3.fromRGB(160, 255, 160)

local function createButton(text, h, bg, txtColor)
    h = h or 30
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h)
    b.Position = UDim2.new(0, 10, 0, curY)
    b.BackgroundColor3 = bg or Color3.fromRGB(45, 45, 62)
    b.TextColor3 = txtColor or Color3.fromRGB(235, 235, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = bg or Color3.fromRGB(80, 80, 120)
    stroke.Thickness = 1
    stroke.Transparency = 0.65
    curY = curY + h + 4
    return b
end

createSection("⚡  ОСНОВНОЕ", Color3.fromRGB(80, 40, 40))
local btnToggle = createButton("🔴 ВЫКЛЮЧЕНО", 36, Color3.fromRGB(50, 35, 40), Color3.fromRGB(255, 80, 80))

createSection("📊  СТАТИСТИКА", Color3.fromRGB(60, 60, 90))
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 110)
statsLabel.Position = UDim2.new(0, 10, 0, curY)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsLabel.BackgroundTransparency = 0.2
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
statsLabel.Font = Enum.Font.GothamBold
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "Загрузка..."
statsLabel.Parent = panel
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)
curY = curY + 118

createSection("🛡️  ЗАЩИТА", Color3.fromRGB(60, 100, 60))
local btnFling      = createButton("🛡️ Анти-Флинг: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnVoid       = createButton("🛡️ Анти-Пустота: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnTeleport   = createButton("🛡️ Анти-Телепорт: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnKnockback  = createButton("🛡️ Анти-Отбрасывание: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnFreeze     = createButton("🛡️ Анти-Заморозка: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnDropKick   = createButton("🛡️ Анти-ДропКик: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnInstant    = createButton("🛡️ Анти-МгновСмерть: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnExplosion  = createButton("🛡️ Анти-Взрыв: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnSuperRing  = createButton("🛡️ Анти-СуперКольцо: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnHomelander = createButton("🛡️ Анти-Homelander: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnGrab       = createButton("🛡️ Анти-Grab: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnRagdoll    = createButton("🛡️ Анти-Ragdoll: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnKillaura   = createButton("🛡️ Анти-Killaura: ВКЛ", 30, GREEN_BG, GREEN_TX)
local btnNoFall     = createButton("🛡️ Убрать урон падения: ВКЛ", 30, GREEN_BG, GREEN_TX)

createSection("💚  УТИЛИТЫ", Color3.fromRGB(80, 100, 60))
local btnHeal = createButton("💚 Авто-Лечение: ВЫКЛ", 30, GREEN_BG, GREEN_TX)
local btnLock = createButton("📍 Блокировка позиции: ВЫКЛ", 30, GREEN_BG, GREEN_TX)

createSection("👁️  ВИЗУАЛ", Color3.fromRGB(60, 80, 120))
local btnSphere    = createButton("🔵 Сфера: ВЫКЛ", 32, Color3.fromRGB(40, 50, 70), Color3.fromRGB(180, 220, 255))
local btnSize      = createButton("📏 Размер сферы: 8", 30, Color3.fromRGB(40, 50, 70), Color3.fromRGB(180, 220, 255))
local btnIntrusion = createButton("🚨 Детект вторжения: ВКЛ", 30, Color3.fromRGB(50, 40, 60), Color3.fromRGB(255, 180, 200))

createSection("🥷  ДОП. ЗАЩИТА", Color3.fromRGB(80, 60, 130))
local btnDodge   = createButton("🥷 Уклонение: ВЫКЛ", 32, Color3.fromRGB(50, 50, 50), Color3.fromRGB(200, 200, 200))
local btnTroll   = createButton("👁️ Детект троллинга: ВКЛ", 30, Color3.fromRGB(50, 60, 80), Color3.fromRGB(200, 220, 255))
local btnReverse = createButton("🚨 Ответный флинг: ВЫКЛ", 30, Color3.fromRGB(60, 30, 30), Color3.fromRGB(255, 150, 150))

createSection("👁️  ДЕТЕКТ ЧИТЕРОВ", Color3.fromRGB(100, 60, 60))
local btnSpeed   = createButton("⚡ Детект скорости: ВКЛ", 30, Color3.fromRGB(50, 40, 40), Color3.fromRGB(255, 180, 180))
local btnGodMode = createButton("👁️ Детект GodMode: ВКЛ", 30, Color3.fromRGB(50, 40, 40), Color3.fromRGB(255, 180, 180))
local btnList    = createButton("📋 Список читеров: 0", 28, Color3.fromRGB(60, 35, 45), Color3.fromRGB(255, 180, 220))

createSection("🔊  ЗВУКИ", Color3.fromRGB(70, 80, 110))
local btnSounds  = createButton("🔊 Звуки: ВКЛ", 30, Color3.fromRGB(35, 60, 45), Color3.fromRGB(180, 255, 180))
local btnTestSnd = createButton("🎵 Проверить звуки", 30, Color3.fromRGB(50, 60, 90), Color3.fromRGB(200, 220, 255))

createSection("💾  СИСТЕМА", Color3.fromRGB(60, 60, 80))
local btnSave   = createButton("💾 Сохранить настройки", 30, Color3.fromRGB(35, 60, 45), Color3.fromRGB(160, 255, 180))
local btnLoad   = createButton("📂 Загрузить настройки", 30, Color3.fromRGB(35, 50, 60), Color3.fromRGB(180, 220, 255))
local btnReset  = createButton("🔄 Сбросить всё", 30, Color3.fromRGB(50, 30, 30), Color3.fromRGB(255, 180, 180))
local btnUnload = createButton("❌ ВЫГРУЗИТЬ", 32, Color3.fromRGB(80, 30, 30), Color3.fromRGB(255, 140, 140))

panel.CanvasSize = UDim2.new(0, 0, 0, curY + 10)

-- ==================== уведомления ====================
local notifyContainer = Instance.new("Frame")
notifyContainer.Size = UDim2.new(0, 300, 0.4, 0)
notifyContainer.Position = UDim2.new(1, -320, 0.15, 0)
notifyContainer.BackgroundTransparency = 1
notifyContainer.Parent = screen

local notifyLayout = Instance.new("UIListLayout")
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.Padding = UDim.new(0, 6)
notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notifyLayout.Parent = notifyContainer

local notifyCounter = 0

notify = function(msg, color, duration)
    if not AC.alive then return end
    duration = duration or 2
    color = color or Color3.fromRGB(140, 255, 200)
    notifyCounter = notifyCounter + 1
    local slot = Instance.new("Frame")
    slot.Size = UDim2.new(1, 0, 0, 40)
    slot.BackgroundTransparency = 1
    slot.LayoutOrder = notifyCounter
    slot.Parent = notifyContainer
    local slots = {}
    for _, child in ipairs(notifyContainer:GetChildren()) do
        if child:IsA("Frame") then table.insert(slots, child) end
    end
    table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #slots > 6 do table.remove(slots, 1):Destroy() end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(1.15, 0, 0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = slot
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = color
    stroke.Thickness = 1.5
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -16, 1, 0)
    textLabel.Position = UDim2.new(0, 8, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = msg
    textLabel.TextColor3 = color
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 13
    textLabel.TextWrapped = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = frame
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0, 0, 0, 0) }):Play()
    task.delay(duration, function()
        if not slot or not slot.Parent then return end
        local out = TweenService:Create(frame, TweenInfo.new(0.25), { Position = UDim2.new(1.15, 0, 0, 0) })
        out:Play()
        out.Completed:Connect(function() pcall(function() slot:Destroy() end) end)
    end)
end
GENV._ORBIT_AC_NOTIFY = notify

-- ==================== обработчики UI ====================
local dragging, moved = false, false
local startInputPos, startButtonPos

mainButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        moved = false
        startInputPos = input.Position
        startButtonPos = mainButton.Position
    end
end)

track(UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - startInputPos
        if delta.Magnitude > 6 then moved = true end
        if moved then
            local abs = screen.AbsoluteSize
            mainButton.Position = UDim2.fromOffset(
                math.clamp(startButtonPos.X.Offset + delta.X, 0, math.max(0, abs.X - 56)),
                math.clamp(startButtonPos.Y.Offset + delta.Y, 0, math.max(0, abs.Y - 56)))
        end
    end
end))

track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end))

local panelOpen = false
local function setPanel(open)
    panelOpen = open
    sfxSwitch()
    if open then
        local abs = screen.AbsoluteSize
        panel.Size = UDim2.fromOffset(300, math.clamp(abs.Y - 40, 200, 700))
        panel.Position = UDim2.fromOffset(math.clamp(mainButton.Position.X.Offset + 70, 0, math.max(0, abs.X - 310)), 20)
        panelScale.Scale = 0.85
        panel.Visible = true
        TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    else
        TweenService:Create(panelScale, TweenInfo.new(0.12), { Scale = 0.85 }):Play()
        task.delay(0.13, function() if not panelOpen then panel.Visible = false end end)
    end
end

-- КРЕСТИК: закрывает панель
onClick(panelCloseX, function()
    setPanel(false)
end, true)

onClick(mainButton, function()
    if moved then moved = false; return end
    setPanel(not panelOpen)
end, true)

local function applyToggleState()
    if SETTINGS.Enabled then
        btnToggle.Text = "🟢 ВКЛЮЧЕНО"
        btnToggle.TextColor3 = Color3.fromRGB(0, 255, 120)
        btnToggle.BackgroundColor3 = Color3.fromRGB(40, 50, 40)
        enableProtection()
    else
        btnToggle.Text = "🔴 ВЫКЛЮЧЕНО"
        btnToggle.TextColor3 = Color3.fromRGB(255, 80, 80)
        btnToggle.BackgroundColor3 = Color3.fromRGB(50, 35, 40)
        disableProtection()
        killSphere()
    end
end

onClick(btnToggle, function()
    SETTINGS.Enabled = not SETTINGS.Enabled
    sfxSwitch()
    applyToggleState()
    if not SETTINGS.Enabled then notify("🔴 Анти-Чит ВЫКЛ", Color3.fromRGB(255, 100, 100), 2) end
end)

local function toggleBtn(button, field, prefix, colorOn, colorOff)
    SETTINGS[field] = not SETTINGS[field]
    button.Text = prefix .. ": " .. (SETTINGS[field] and "ВКЛ" or "ВЫКЛ")
    if SETTINGS[field] then
        button.TextColor3 = colorOn or GREEN_TX
        button.BackgroundColor3 = GREEN_BG
    else
        button.TextColor3 = colorOff or Color3.fromRGB(220, 200, 200)
        button.BackgroundColor3 = Color3.fromRGB(50, 40, 40)
    end
end

onClick(btnFling, function()      toggleBtn(btnFling, "AntiFling", "🛡️ Анти-Флинг") end)
onClick(btnVoid, function()       toggleBtn(btnVoid, "AntiVoid", "🛡️ Анти-Пустота") end)
onClick(btnTeleport, function()   toggleBtn(btnTeleport, "AntiTeleport", "🛡️ Анти-Телепорт") end)
onClick(btnKnockback, function()  toggleBtn(btnKnockback, "AntiKnockback", "🛡️ Анти-Отбрасывание") end)
onClick(btnFreeze, function()     toggleBtn(btnFreeze, "AntiFreeze", "🛡️ Анти-Заморозка") end)
onClick(btnDropKick, function()   toggleBtn(btnDropKick, "AntiDropKick", "🛡️ Анти-ДропКик") end)
onClick(btnInstant, function()    toggleBtn(btnInstant, "AntiInstantKill", "🛡️ Анти-МгновСмерть") end)
onClick(btnExplosion, function()  toggleBtn(btnExplosion, "AntiExplosion", "🛡️ Анти-Взрыв") end)
onClick(btnSuperRing, function()  toggleBtn(btnSuperRing, "AntiSuperRing", "🛡️ Анти-СуперКольцо") end)
onClick(btnHomelander, function() toggleBtn(btnHomelander, "AntiHomelander", "🛡️ Анти-Homelander") end)
onClick(btnGrab, function()       toggleBtn(btnGrab, "AntiGrab", "🛡️ Анти-Grab") end)
onClick(btnRagdoll, function()    toggleBtn(btnRagdoll, "AntiRagdoll", "🛡️ Анти-Ragdoll") end)
onClick(btnKillaura, function()   toggleBtn(btnKillaura, "AntiKillaura", "🛡️ Анти-Killaura") end)
onClick(btnNoFall, function()     toggleBtn(btnNoFall, "NoFallDamage", "🛡️ Убрать урон падения") end)
onClick(btnHeal, function()       toggleBtn(btnHeal, "AutoHeal", "💚 Авто-Лечение") end)
onClick(btnLock, function()       toggleBtn(btnLock, "LockPosition", "📍 Блокировка позиции") end)
onClick(btnIntrusion, function()  toggleBtn(btnIntrusion, "IntrusionDetect", "🚨 Детект вторжения") end)
onClick(btnSpeed, function()      toggleBtn(btnSpeed, "DetectSpeed", "⚡ Детект скорости") end)
onClick(btnGodMode, function()    toggleBtn(btnGodMode, "DetectGodMode", "👁️ Детект GodMode") end)

onClick(btnSphere, function()
    SETTINGS.VisualSphere = not SETTINGS.VisualSphere
    btnSphere.Text = "🔵 Сфера: " .. (SETTINGS.VisualSphere and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.VisualSphere then createSphere() else killSphere() end
end)

onClick(btnSize, function()
    local sizes = {4, 6, 8, 12, 16, 20, 25, 30}
    local idx = 1
    for i, v in ipairs(sizes) do if v == SETTINGS.SphereSize then idx = i; break end end
    SETTINGS.SphereSize = sizes[(idx % #sizes) + 1]
    btnSize.Text = "📏 Размер сферы: " .. SETTINGS.SphereSize
    if spherePart then
        spherePart.Size = Vector3.new(SETTINGS.SphereSize, SETTINGS.SphereSize, SETTINGS.SphereSize)
    end
end)

onClick(btnDodge, function()
    DODGE.Enabled = not DODGE.Enabled
    btnDodge.Text = "🥷 Уклонение: " .. (DODGE.Enabled and "ВКЛ" or "ВЫКЛ")
    btnDodge.BackgroundColor3 = DODGE.Enabled and Color3.fromRGB(60, 80, 50) or Color3.fromRGB(50, 50, 50)
end)
onClick(btnTroll, function()
    TROLLING.Enabled = not TROLLING.Enabled
    btnTroll.Text = "👁️ Детект троллинга: " .. (TROLLING.Enabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(btnReverse, function()
    REVERSE.Enabled = not REVERSE.Enabled
    btnReverse.Text = "🚨 Ответный флинг: " .. (REVERSE.Enabled and "ВКЛ" or "ВЫКЛ")
    btnReverse.BackgroundColor3 = REVERSE.Enabled and Color3.fromRGB(100, 30, 30) or Color3.fromRGB(60, 30, 30)
end)

onClick(btnList, function()
    local list = {}
    for p in pairs(MARKED) do
        if p and p.Parent then table.insert(list, p.Name) end
    end
    if #list == 0 then
        notify("📋 Читеров не найдено", Color3.fromRGB(200, 200, 255), 3)
    else
        notify("📋 Читеры: " .. table.concat(list, ", "), Color3.fromRGB(255, 180, 220), 5)
    end
end)

onClick(btnSounds, function()
    SETTINGS.Sounds = not SETTINGS.Sounds
    btnSounds.Text = "🔊 Звуки: " .. (SETTINGS.Sounds and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.Sounds then sfxSwitch() end
end)

onClick(btnTestSnd, function()
    btnTestSnd.Text = "⏳ Проигрываю..."
    task.wait(0.1)
    sfxClick()
    task.wait(0.5)
    sfxDodgeSans()
    task.wait(3)
    btnTestSnd.Text = "✅ Готово"
    task.wait(2)
    btnTestSnd.Text = "🎵 Проверить звуки"
end)

-- ==================== сохранение ====================
local SAVE_FILE = "orbit_ac_settings.json"
local HAS_FS = (writefile and readfile and isfile and type(writefile) == "function")

onClick(btnSave, function()
    if not HAS_FS then
        notify("❌ Нет файловой системы", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    local ok = pcall(function()
        local data = {}
        for k, v in pairs(SETTINGS) do
            if type(v) ~= "userdata" and type(v) ~= "function" then data[k] = v end
        end
        writefile(SAVE_FILE, HttpService:JSONEncode(data))
    end)
    if ok then
        btnSave.Text = "✅ Сохранено!"
        task.wait(1.5)
        btnSave.Text = "💾 Сохранить настройки"
        notify("💾 Настройки сохранены", Color3.fromRGB(160, 255, 180), 2)
    else
        notify("❌ Ошибка сохранения", Color3.fromRGB(255, 100, 100), 2)
    end
end)

onClick(btnLoad, function()
    if not HAS_FS or not isfile(SAVE_FILE) then
        notify("❌ Нет сохранения", Color3.fromRGB(255, 100, 100), 2)
        return
    end
    pcall(function()
        local data = HttpService:JSONDecode(readfile(SAVE_FILE))
        for k, v in pairs(data) do
            if SETTINGS[k] ~= nil then SETTINGS[k] = v end
        end
        notify("📂 Настройки загружены", Color3.fromRGB(180, 220, 255), 2)
    end)
end)

onClick(btnReset, function()
    SETTINGS.AntiFling = true; SETTINGS.AntiVoid = true; SETTINGS.AntiTeleport = true
    SETTINGS.AntiKnockback = true; SETTINGS.AntiFreeze = true; SETTINGS.AntiAnchor = true
    SETTINGS.AntiInstantKill = true; SETTINGS.AntiDropKick = true; SETTINGS.AntiExplosion = true
    SETTINGS.AntiSuperRing = true; SETTINGS.AntiHomelander = true; SETTINGS.AntiGrab = true
    SETTINGS.AntiRagdoll = true; SETTINGS.AntiKillaura = true; SETTINGS.NoFallDamage = true
    SETTINGS.AutoHeal = false; SETTINGS.LockPosition = false; SETTINGS.VisualSphere = false
    SETTINGS.IntrusionDetect = true
    DODGE.Enabled = false; TROLLING.Enabled = true; REVERSE.Enabled = false
    killSphere()
    notify("🔄 Сброс выполнен", Color3.fromRGB(255, 180, 180), 2)
end)

onClick(btnUnload, function()
    pcall(function() GENV._ORBIT_AC_UNLOAD() end)
end)

-- ==================== выгрузка ====================
GENV._ORBIT_AC_UNLOAD = function()
    AC.alive = false
    disableProtection()
    for _, c in ipairs(AC_CONNS) do pcall(function() c:Disconnect() end) end
    AC_CONNS = {}
    killSphere()
    if fxFolder then pcall(function() fxFolder:Destroy() end); fxFolder = nil end
    SOUND_QUEUE.List = {}
    if screen then pcall(function() screen:Destroy() end) end
    if soundFolder then pcall(function() soundFolder:Destroy() end) end
    local O = getOrbit()
    if O and O.loaded then O.loaded.anticheat = false end
    GENV._ORBIT_AC_LOADED = nil
    GENV._ORBIT_AC_UNLOAD = nil
    GENV._ORBIT_AC_NOTIFY = nil
    GENV._ORBIT_AC_TOGGLE = nil
    print("[OrbitAC] Выгружен")
end

-- ==================== обновление статистики ====================
task.spawn(function()
    while AC.alive and screen and screen.Parent do
        task.wait(0.5)
        local elapsed = tick() - SESSION.startTime
        statsLabel.Text = string.format(
            "🛡️ Защит: %d\n🥷 Уворотов: %d\n🚨 Вторжений: %d\n🚩 Читеров: %d\n⏱️ Сессия: %d:%02d",
            SESSION.defenses, SESSION.dodges, SESSION.intrusions, SESSION.cheatersMarked,
            math.floor(elapsed / 60), math.floor(elapsed % 60))
        btnList.Text = "📋 Список читеров: " .. SESSION.cheatersMarked
        if SETTINGS.VisualSphere then updateSphere() end
    end
end)

-- ==================== горячая клавиша K ====================
GENV._ORBIT_AC_TOGGLE = function()
    SETTINGS.Enabled = not SETTINGS.Enabled
    applyToggleState()
end

track(UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.K then
        if GENV._ORBIT_AC_TOGGLE then GENV._ORBIT_AC_TOGGLE() end
    end
end))

-- ==================== автозапуск ====================
task.spawn(function()
    task.wait(1)
    notify("🛡 ОРБИТА АНТИ-ЧИТ v14.0", Color3.fromRGB(255, 200, 200), 3)
    task.wait(0.3)
    notify("✨ Анимации защиты + фразы Санса", Color3.fromRGB(255, 220, 180), 3)
    task.wait(0.3)
    notify("🎮 K — вкл/выкл защиту", Color3.fromRGB(200, 220, 255), 3)
    task.wait(0.3)
    notify("✖ Крестик — закрыть панель", Color3.fromRGB(200, 255, 200), 3)
end)

-- ==================== регистрация в ORBIT ====================
do
    local O = getOrbit()
    if O then
        O.loaded = O.loaded or {}
        O.loaded.anticheat = true
        local prevUnload = O.unload
        O.unload = function()
            pcall(function() if GENV._ORBIT_AC_UNLOAD then GENV._ORBIT_AC_UNLOAD() end end)
            if prevUnload then pcall(prevUnload) end
        end
    end
end

print("[Orbit Anti-Cheat v14.0] Запущен ✅")

return true
