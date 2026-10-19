-- ORBIT v25.3 | orbit_features.lua (SAFE EDITION)
-- Фишки: Dash, Boss Bar, Радар, Курсор, Змейка, Черная дыра, 
-- Оружие, Матрица, Комбо и Фазы боя.
local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Features] ORBIT не найден!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local Workspace    = ORBIT.Workspace
local LocalPlayer  = ORBIT.LocalPlayer
local TweenService = ORBIT.TweenService
local UIS          = ORBIT.UIS
local C3           = Color3.fromRGB

local conns = {}
local function track(c) table.insert(conns, c); return c end
local alive = true

-- ============================================================
-- 1. КАСТОМНЫЙ КУРСОР
-- ============================================================
local function setupCursor()
    pcall(function()
        local cursorGui = Instance.new("ScreenGui")
        cursorGui.Name = "Orbit_Cursor"
        cursorGui.IgnoreGuiInset = true
        cursorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        cursorGui.DisplayOrder = 64
        cursorGui.Parent = ORBIT.getSafeParent and ORBIT.getSafeParent() or LocalPlayer:WaitForChild("PlayerGui")
        
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromOffset(32, 32)
        img.BackgroundTransparency = 1
        img.Image = "rbxassetid://3570695787"
        img.ImageColor3 = C3(100, 255, 140)
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Parent = cursorGui
        
        track(UIS.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                img.Position = UDim2.fromOffset(input.Position.X, input.Position.Y)
            end
        end))
        track(UIS.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(img, TweenInfo.new(0.1), { Size = UDim2.fromOffset(24, 24), ImageColor3 = C3(255, 100, 120) }):Play()
            end
        end))
        track(UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(img, TweenInfo.new(0.1), { Size = UDim2.fromOffset(32, 32), ImageColor3 = C3(100, 255, 140) }):Play()
            end
        end))
        ORBIT._cleanup = ORBIT._cleanup or {}
        table.insert(ORBIT._cleanup, function() cursorGui:Destroy() end)
    end)
end
setupCursor()

-- ============================================================
-- 2. РЫВОК (DASH)
-- ============================================================
local dashCooldown = 0
local function setupDash()
    track(UIS.InputBegan:Connect(function(input, gpe)
        if gpe or not alive then return end
        if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            if tick() < dashCooldown then return end
            
            dashCooldown = tick() + 2
            local dir = hrp.CFrame.LookVector
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = dir * 120 + Vector3.new(0, 20, 0)
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Parent = hrp
            
            local trailPart = Instance.new("Part")
            trailPart.Anchored = true; trailPart.CanCollide = false
            trailPart.Transparency = 0.5; trailPart.Color = C3(100, 255, 140)
            trailPart.Size = Vector3.new(2, 2, 2); trailPart.CFrame = hrp.CFrame
            trailPart.Parent = Workspace
            TweenService:Create(trailPart, TweenInfo.new(0.4), { Size = Vector3.new(8, 8, 8), Transparency = 1 }):Play()
            task.delay(0.5, function() trailPart:Destroy() end)
            
            if ORBIT.playSound then ORBIT.playSound("rbxasset://sounds/snap.mp3", 0.5, 1.5) end
            task.delay(0.2, function() bv:Destroy() end)
        end
    end))
end
setupDash()

-- ============================================================
-- 3. ПОЛОСА ЗДОРОВЬЯ БОССА
-- ============================================================
local bossGui, bossFill, bossLabel
local function createBossBar()
    local sg = Instance.new("ScreenGui")
    sg.Name = "Orbit_BossBar"
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 60
    sg.Parent = ORBIT.getSafeParent and ORBIT.getSafeParent() or LocalPlayer:WaitForChild("PlayerGui")
    
    local f = Instance.new("Frame")
    f.Name = "BossBar"
    f.Size = UDim2.new(0, 400, 0, 24)
    f.Position = UDim2.new(0.5, -200, 0, 20)
    f.BackgroundColor3 = C3(20, 20, 30)
    f.BackgroundTransparency = 0.2
    f.Visible = false
    f.Parent = sg
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    
    bossFill = Instance.new("Frame")
    bossFill.Size = UDim2.new(1, 0, 1, 0)
    bossFill.BackgroundColor3 = C3(255, 50, 80)
    bossFill.Parent = f
    Instance.new("UICorner", bossFill).CornerRadius = UDim.new(0, 6)
    
    bossLabel = Instance.new("TextLabel")
    bossLabel.Size = UDim2.new(1, 0, 1, 0)
    bossLabel.BackgroundTransparency = 1
    bossLabel.Text = "BOSS"
    bossLabel.TextColor3 = C3(255, 255, 255)
    bossLabel.Font = Enum.Font.GothamBold
    bossLabel.TextSize = 14
    bossLabel.ZIndex = 2
    bossLabel.Parent = f
    
    bossGui = sg
    ORBIT._cleanup = ORBIT._cleanup or {}
    table.insert(ORBIT._cleanup, function() sg:Destroy() end)
end
createBossBar()

task.spawn(function()
    while alive do
        task.wait(0.5)
        local found = false
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name:find("Sans") or obj.Name:find("Gaster")) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    bossGui.BossBar.Visible = true
                    local name = obj.Name:find("Sans") and "💀 САНС" or "👁 ГАСТЕР"
                    bossLabel.Text = name .. " [" .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. "]"
                    bossFill.Size = UDim2.new(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 0, 1, 0)
                    found = true
                    break
                end
            end
        end
        if not found and bossGui then bossGui.BossBar.Visible = false end
    end
end)

-- ============================================================
-- 4. РАДАР
-- ============================================================
local radarGui, radarFrame
local dots = {}
local function createRadar()
    local sg = Instance.new("ScreenGui")
    sg.Name = "Orbit_Radar"
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 60
    sg.Parent = ORBIT.getSafeParent and ORBIT.getSafeParent() or LocalPlayer:WaitForChild("PlayerGui")
    
    radarFrame = Instance.new("Frame")
    radarFrame.Size = UDim2.fromOffset(140, 140)
    radarFrame.Position = UDim2.new(1, -160, 1, -160)
    radarFrame.BackgroundColor3 = C3(15, 15, 25)
    radarFrame.BackgroundTransparency = 0.5
    radarFrame.Parent = sg
    Instance.new("UICorner", radarFrame).CornerRadius = UDim.new(1, 0)
    
    local stroke = Instance.new("UIStroke", radarFrame)
    stroke.Color = C3(100, 255, 140)
    stroke.Thickness = 2
    
    radarGui = sg
    ORBIT._cleanup = ORBIT._cleanup or {}
    table.insert(ORBIT._cleanup, function() sg:Destroy() end)
end
createRadar()

task.spawn(function()
    while alive do
        task.wait(0.2)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        for _, dot in pairs(dots) do dot:Destroy() end
        dots = {}
        
        local myPos = hrp.Position
        local radius = 300
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if oHrp then
                    local dist = (oHrp.Position - myPos).Magnitude
                    if dist <= radius then
                        local relPos = oHrp.Position - myPos
                        local x = (relPos.X / radius) * 70 + 70
                        local y = (relPos.Z / radius) * 70 + 70
                        
                        local dot = Instance.new("Frame")
                        dot.Size = UDim2.fromOffset(6, 6)
                        dot.Position = UDim2.fromOffset(x - 3, y - 3)
                        dot.BackgroundColor3 = C3(255, 50, 50)
                        dot.Parent = radarFrame
                        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
                        table.insert(dots, dot)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- 5. МЕНЮ ФИШЕК (ФИКСИРОВАННЫЕ ПОЗИЦИИ, БЕЗ СПИСКОВ)
-- ============================================================
local featureGui = Instance.new("ScreenGui")
featureGui.Name = "Orbit_FeaturesMenu"
featureGui.ResetOnSpawn = false
featureGui.IgnoreGuiInset = true
featureGui.DisplayOrder = 65
featureGui.Parent = ORBIT.getSafeParent and ORBIT.getSafeParent() or LocalPlayer:WaitForChild("PlayerGui")
ORBIT._cleanup = ORBIT._cleanup or {}
table.insert(ORBIT._cleanup, function() featureGui:Destroy() end)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(60, 60)
toggleBtn.Position = UDim2.fromOffset(20, 330)
toggleBtn.BackgroundColor3 = C3(70, 40, 110)
toggleBtn.TextColor3 = C3(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 22
toggleBtn.Text = "🎮"
toggleBtn.ZIndex = 60
toggleBtn.Parent = featureGui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 14)
local st = Instance.new("UIStroke", toggleBtn); st.Color = C3(200, 150, 255); st.Thickness = 2

local featureLabel = Instance.new("TextLabel")
featureLabel.Size = UDim2.fromOffset(60, 14)
featureLabel.Position = UDim2.fromOffset(20, 392)
featureLabel.BackgroundTransparency = 1
featureLabel.Text = "ФИШКИ"
featureLabel.TextColor3 = C3(200, 150, 255)
featureLabel.Font = Enum.Font.GothamBold
featureLabel.TextSize = 10
featureLabel.ZIndex = 60
featureLabel.Parent = featureGui

local fWindow = Instance.new("Frame")
fWindow.Size = UDim2.fromOffset(280, 380)
fWindow.Position = UDim2.fromOffset(90, 300)
fWindow.BackgroundColor3 = C3(18, 14, 28)
fWindow.Visible = false
fWindow.ZIndex = 60
fWindow.Parent = featureGui
Instance.new("UICorner", fWindow).CornerRadius = UDim.new(0, 14)
local wStroke = Instance.new("UIStroke", fWindow); wStroke.Color = C3(150, 120, 255)

local fTitle = Instance.new("TextLabel")
fTitle.Size = UDim2.new(1, 0, 0, 40)
fTitle.BackgroundTransparency = 1
fTitle.Text = "✨ ФИШКИ"
fTitle.TextColor3 = C3(200, 220, 255)
fTitle.Font = Enum.Font.GothamBold
fTitle.TextSize = 16
fTitle.Parent = fWindow

toggleBtn.MouseButton1Click:Connect(function()
    fWindow.Visible = not fWindow.Visible
    if ORBIT.playClick then ORBIT.playClick() end
end)

-- Универсальная функция создания кнопки с явным Y
local function addBtn(text, yPos, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 40)
    b.Position = UDim2.fromOffset(10, yPos)
    b.BackgroundColor3 = color or C3(40, 40, 60)
    b.TextColor3 = C3(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.Parent = fWindow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function()
        if ORBIT.playClick then ORBIT.playClick() end
        cb(b)
    end)
    return b
end

-- ============================================================
-- 6. ЗМЕЙКА
-- ============================================================
local snakeEnabled = false
local snakeFolder = Instance.new("Folder", Workspace)
snakeFolder.Name = "Orbit_Snake"
local snakeParts = {}
local snakeHistory = {}

addBtn("🐍 Режим Змейка: ВЫКЛ", 50, C3(50, 70, 50), function(b)
    snakeEnabled = not snakeEnabled
    b.Text = "🐍 Режим Змейка: " .. (snakeEnabled and "ВКЛ" or "ВЫКЛ")
    if snakeEnabled then
        for i = 1, 20 do
            local p = Instance.new("Part")
            p.Size = Vector3.new(1.2, 1.2, 1.2)
            p.Material = Enum.Material.Neon
            p.Color = C3(100, 255, 140)
            p.Anchored = true
            p.CanCollide = false
            p.Parent = snakeFolder
            table.insert(snakeParts, p)
        end
    else
        for _, p in ipairs(snakeParts) do p:Destroy() end
        snakeParts = {}
        snakeHistory = {}
    end
end)

task.spawn(function()
    while alive do
        local dt = RunService.Heartbeat:Wait()
        if snakeEnabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                table.insert(snakeHistory, 1, {cf = hrp.CFrame})
                if #snakeHistory > 20 then table.remove(snakeHistory) end
                for i, p in ipairs(snakeParts) do
                    if snakeHistory[i] then p.CFrame = snakeHistory[i].cf end
                end
            end
        end
    end
end)

-- ============================================================
-- 7. ЧЕРНАЯ ДЫРА
-- ============================================================
local blackHoleCooldown = 0
addBtn("🕳 Черная дыра", 98, C3(60, 30, 80), function()
    if tick() < blackHoleCooldown then return end
    blackHoleCooldown = tick() + 5
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local targetPos = hrp.Position + hrp.CFrame.LookVector * 20
    local hole = Instance.new("Part")
    hole.Shape = Enum.PartType.Ball
    hole.Size = Vector3.new(4, 4, 4)
    hole.Color = C3(0, 0, 0)
    hole.Anchored = true
    hole.CanCollide = false
    hole.Position = targetPos
    hole.Parent = Workspace
    
    local glow = Instance.new("ParticleEmitter", hole)
    glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    glow.Color = ColorSequence.new(C3(150, 50, 255))
    glow.Rate = 100
    glow.Speed = NumberRange.new(-20, -10)
    glow.Size = NumberSequence.new(2, 0)
    glow.LightEmission = 1
    
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not hole.Parent then conn:Disconnect() return end
        for _, m in ipairs(Workspace:GetChildren()) do
            if m:IsA("Model") and m ~= char then
                local root = m:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - targetPos).Magnitude < 50 then
                    root.AssemblyLinearVelocity = (targetPos - root.Position).Unit * 60
                end
            end
        end
    end)
    task.delay(3, function() conn:Disconnect() hole:Destroy() end)
end)

-- ============================================================
-- 8. ОРБИТАЛЬНОЕ ОРУЖИЕ (Награда)
-- ============================================================
local orbWeaponEnabled = false
local orbFolder = Instance.new("Folder", Workspace)
orbFolder.Name = "Orbit_Weapons"
local orbParts = {}
local orbAngle = 0
local orbHitCooldowns = {}

local function isBossDefeated()
    if not ORBIT.saveData or not ORBIT.saveData.stats then return false end
    return (ORBIT.saveData.stats.wins_total or 0) > 0
end

local orbBtn = addBtn("⚔ Орбитальное оружие", 146, C3(70, 50, 30), function(b)
    if not isBossDefeated() then
        if ORBIT.notify then ORBIT.notify("🔒 Убей Санса или Гастера!", C3(255, 100, 100), 3) end
        return
    end
    orbWeaponEnabled = not orbWeaponEnabled
    b.Text = "⚔ Оружие: " .. (orbWeaponEnabled and "ВКЛ" or "ВЫКЛ")
    
    if orbWeaponEnabled then
        for i = 1, 6 do
            local p = Instance.new("WedgePart")
            p.Size = Vector3.new(0.4, 3, 1.2)
            p.Material = Enum.Material.Neon
            p.Color = C3(255, 50, 50)
            p.Anchored = true
            p.CanCollide = false
            p.Parent = orbFolder
            local light = Instance.new("PointLight", p)
            light.Color = C3(255, 50, 50); light.Range = 5
            table.insert(orbParts, p)
        end
    else
        for _, p in ipairs(orbParts) do p:Destroy() end
        orbParts = {}
    end
end)

task.delay(1, function()
    if not isBossDefeated() then
        orbBtn.Text = "🔒 Оружие (Убей босса)"
        orbBtn.TextColor3 = C3(150, 150, 150)
    end
end)

task.spawn(function()
    while alive do
        local dt = RunService.Heartbeat:Wait()
        if orbWeaponEnabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                orbAngle = orbAngle + dt * 5
                for i, p in ipairs(orbParts) do
                    local a = orbAngle + (i - 1) * (math.pi * 2 / #orbParts)
                    local offset = Vector3.new(math.cos(a) * 7, math.sin(tick() * 2 + i) * 0.5, math.sin(a) * 7)
                    p.CFrame = CFrame.new(hrp.Position + offset, hrp.Position + offset + Vector3.new(-math.sin(a), 0, math.cos(a)))
                    
                    for _, model in ipairs(Workspace:GetChildren()) do
                        if model:IsA("Model") and model ~= char then
                            local hum = model:FindFirstChildOfClass("Humanoid")
                            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
                            if hum and root and hum.Health > 0 and (root.Position - p.Position).Magnitude < 3.5 then
                                local lastHit = orbHitCooldowns[model] or 0
                                if tick() - lastHit > 0.6 then
                                    orbHitCooldowns[model] = tick()
                                    hum:TakeDamage(15)
                                    local fx = Instance.new("Part", Workspace)
                                    fx.Anchored = true; fx.CanCollide = false; fx.Size = Vector3.new(1,1,1)
                                    fx.Color = C3(255, 0, 0); fx.Material = Enum.Material.Neon; fx.Position = root.Position
                                    TweenService:Create(fx, TweenInfo.new(0.3), { Size = Vector3.new(3,3,3), Transparency = 1 }):Play()
                                    task.delay(0.3, function() fx:Destroy() end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- 9. МАТРИЦА
-- ============================================================
local matrixEnabled = false
local matrixFolder = Instance.new("Folder", Workspace)
matrixFolder.Name = "Orbit_Matrix"

addBtn("🟩 Матрица: ВЫКЛ", 194, C3(30, 70, 30), function(b)
    matrixEnabled = not matrixEnabled
    b.Text = "🟩 Матрица: " .. (matrixEnabled and "ВКЛ" or "ВЫКЛ")
    if matrixEnabled then
        local char = LocalPlayer.Character
        if not char then return end
        
        local emitterPart = Instance.new("Part")
        emitterPart.Anchored = true; emitterPart.CanCollide = false; emitterPart.Transparency = 1
        emitterPart.Size = Vector3.new(1, 1, 1); emitterPart.Parent = matrixFolder
        
        local pe = Instance.new("ParticleEmitter", emitterPart)
        pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        pe.Color = ColorSequence.new(C3(0, 255, 0))
        pe.Rate = 100
        pe.Lifetime = NumberRange.new(1.5, 2.5)
        pe.Speed = NumberRange.new(10, 15)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.Size = NumberSequence.new(2, 0)
        pe.LightEmission = 1
        pe.Acceleration = Vector3.new(0, -60, 0)
        
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not matrixEnabled or not char.Parent then conn:Disconnect() return end
            local r = char:FindFirstChild("HumanoidRootPart")
            if r then
                emitterPart.CFrame = CFrame.new(r.Position + Vector3.new(0, 20, 0))
            end
        end)
        ORBIT._cleanup = ORBIT._cleanup or {}
        table.insert(ORBIT._cleanup, function() matrixEnabled = false conn:Disconnect() emitterPart:Destroy() end)
    else
        for _, obj in ipairs(matrixFolder:GetChildren()) do obj:Destroy() end
    end
end)

-- ============================================================
-- 10. КОМБО И ФАЗЫ (Без UI, только логика)
-- ============================================================
local comboGui = Instance.new("ScreenGui")
comboGui.Name = "Orbit_Combo"
comboGui.ResetOnSpawn = false
comboGui.DisplayOrder = 62
comboGui.Parent = ORBIT.getSafeParent and ORBIT.getSafeParent() or LocalPlayer:WaitForChild("PlayerGui")

local comboLabel = Instance.new("TextLabel")
comboLabel.Size = UDim2.new(0, 300, 0, 80)
comboLabel.Position = UDim2.new(0.5, -150, 0.3, 0)
comboLabel.BackgroundTransparency = 1
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextSize = 50
comboLabel.Visible = false
comboLabel.Parent = comboGui

local comboCount, lastHitTime, lastBossHp = 0, 0, 0
task.spawn(function()
    while alive do
        task.wait(0.1)
        local bModel = nil
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name:find("Sans") or obj.Name:find("Gaster")) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then bModel = obj break end
            end
        end
        if bModel then
            local hp = bModel:FindFirstChildOfClass("Humanoid").Health
            if lastBossHp > 0 and hp < lastBossHp then
                if tick() - lastHitTime <= 1.5 then comboCount = comboCount + 1 else comboCount = 1 end
                lastHitTime = tick()
                comboLabel.Text = "x" .. comboCount .. " КОМБО!"
                comboLabel.TextColor3 = comboCount >= 5 and C3(255,50,50) or C3(255,255,50)
                comboLabel.Visible = true
            end
            lastBossHp = hp
        else
            lastBossHp = 0
        end
        if tick() - lastHitTime > 1.5 then comboLabel.Visible = false end
    end
end)

local enrageOverlay = Instance.new("Frame", comboGui)
enrageOverlay.Size = UDim2.new(1, 0, 1, 0)
enrageOverlay.BackgroundColor3 = C3(255, 0, 0)
enrageOverlay.BackgroundTransparency = 1
enrageOverlay.ZIndex = 10

task.spawn(function()
    local enraged = false
    local enragedModel = nil
    while alive do
        task.wait(0.5)
        if enraged then
            if not enragedModel or not enragedModel.Parent then
                enraged = false; enrageOverlay.BackgroundTransparency = 1
            end
        else
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and (obj.Name:find("Sans") or obj.Name:find("Gaster")) then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and (hum.Health/hum.MaxHealth) <= 0.5 then
                        enraged = true; enragedModel = obj
                        enrageOverlay.BackgroundTransparency = 0.5
                        TweenService:Create(enrageOverlay, TweenInfo.new(1.5), { BackgroundTransparency = 0.9 }):Play()
                        if ORBIT.notify then ORBIT.notify("🔥 БОСС В ЯРОСТИ!", C3(255,50,50), 4) end
                        local r = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                        if r then Instance.new("Fire", r).Color = C3(255,0,0) end
                        break
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- ОЧИСТКА
-- ============================================================
local prevUnload = ORBIT.unload
ORBIT.unload = function()
    alive = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(ORBIT._cleanup or {}) do pcall(fn) end
    if prevUnload then pcall(prevUnload) end
end

ORBIT.loaded = ORBIT.loaded or {}
ORBIT.loaded.features = true
return true
