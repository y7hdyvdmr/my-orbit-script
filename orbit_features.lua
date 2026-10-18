-- ORBIT v25.0 | orbit_features.lua
-- Дополнительные фишки: Dash, Boss Bar, Радар, Кастомный курсор,
-- Режим "Змейка", Черная дыра, Орбитальное оружие, Матрица,
-- Фазы боя и Комбо-урон.
local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Features] ORBIT не найден!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local Workspace    = ORBIT.Workspace
local LocalPlayer  = ORBIT.LocalPlayer
local TweenService = ORBIT.TweenService
local UIS          = ORBIT.UIS
local Camera       = Workspace.CurrentCamera

local SETTINGS = ORBIT.SETTINGS
local C3 = Color3.fromRGB

local conns = {}
local function track(c) table.insert(conns, c); return c end
local alive = true

-- ============================================================
-- 1. КАСТОМНЫЙ КУРСОР (Заменяет стандартную стрелку)
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
        img.Name = "CursorImg"
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
-- 3. ПОЛОСА ЗДОРОВЬЯ БОССА (Boss Bar)
-- ============================================================
local bossGui, bossFill, bossLabel
local currentBoss = nil

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
        local foundBoss = nil
        local bossHp, bossMaxHp = 0, 1
        local bossName = "БОСС"
        
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name:find("Sans") or obj.Name:find("Gaster")) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    foundBoss = obj
                    bossHp = hum.Health
                    bossMaxHp = hum.MaxHealth
                    bossName = (obj.Name:find("Sans") and "💀 САНС" or "👁 ГАСТЕР")
                    break
                end
            end
        end
        
        if foundBoss then
            currentBoss = foundBoss
            if bossGui and bossGui:FindFirstChild("BossBar") then 
                bossGui.BossBar.Visible = true 
                bossLabel.Text = bossName .. " [" .. math.floor(bossHp) .. "/" .. math.floor(bossMaxHp) .. "]"
                bossFill.Size = UDim2.new(math.clamp(bossHp / bossMaxHp, 0, 1), 0, 1, 0)
            end
        else
            currentBoss = nil
            if bossGui and bossGui:FindFirstChild("BossBar") then bossGui.BossBar.Visible = false end
        end
    end
end)

-- ============================================================
-- 4. РАДАР ИГРОКОВ
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
        local radarRadius = 300
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if oHrp then
                    local dist = (oHrp.Position - myPos).Magnitude
                    if dist <= radarRadius then
                        local relPos = oHrp.Position - myPos
                        local x = (relPos.X / radarRadius) * 70 + 70
                        local y = (relPos.Z / radarRadius) * 70 + 70
                        
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
-- 5. МЕНЮ ФИШЕК (Отдельное окно с кнопкой 🎮)
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
toggleBtn.Position = UDim2.fromOffset(20, 170)
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
featureLabel.Position = UDim2.fromOffset(20, 232)
featureLabel.BackgroundTransparency = 1
featureLabel.Text = "ФИШКИ"
featureLabel.TextColor3 = C3(200, 150, 255)
featureLabel.Font = Enum.Font.GothamBold
featureLabel.TextSize = 10
featureLabel.ZIndex = 60
featureLabel.Parent = featureGui

local fWindow = Instance.new("Frame")
fWindow.Size = UDim2.fromOffset(280, 360)
fWindow.Position = UDim2.fromOffset(90, 170)
fWindow.BackgroundColor3 = C3(18, 14, 28)
fWindow.Visible = false
fWindow.ZIndex = 60
fWindow.Parent = featureGui
Instance.new("UICorner", fWindow).CornerRadius = UDim.new(0, 14)
local wStroke = Instance.new("UIStroke", fWindow); wStroke.Color = C3(150, 120, 255)

local fTitle = Instance.new("TextLabel")
fTitle.Size = UDim2.new(1, 0, 0, 40)
fTitle.BackgroundTransparency = 1
fTitle.Text = "✨ ДОПОЛНИТЕЛЬНЫЕ ФИШКИ"
fTitle.TextColor3 = C3(200, 220, 255)
fTitle.Font = Enum.Font.GothamBold
fTitle.TextSize = 14
fTitle.Parent = fWindow

toggleBtn.MouseButton1Click:Connect(function()
    fWindow.Visible = not fWindow.Visible
    if ORBIT.playClick then ORBIT.playClick() end
end)

local function makeFButton(text, y, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 36)
    b.Position = UDim2.fromOffset(10, y)
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
-- 6. РЕЖИМ «ЗМЕЙКА»
-- ============================================================
local snakeEnabled = false
local snakeFolder = Instance.new("Folder")
snakeFolder.Name = "Orbit_Snake"
snakeFolder.Parent = Workspace
local snakeParts = {}
local snakeHistory = {}

local snakeBtn = makeFButton("🐍 Режим Змейка: ВЫКЛ", 50, C3(50, 70, 50), function(b)
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
                table.insert(snakeHistory, 1, {cf = hrp.CFrame, t = tick()})
                if #snakeHistory > 20 then table.remove(snakeHistory) end
                
                for i, p in ipairs(snakeParts) do
                    if snakeHistory[i] then
                        p.CFrame = snakeHistory[i].cf
                        local scale = 1 + math.sin(tick() * 5 - i * 0.3) * 0.2
                        p.Size = Vector3.new(1.2, 1.2, 1.2) * scale
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- 7. ЧЕРНАЯ ДЫРА
-- ============================================================
local blackHoleCooldown = 0
makeFButton("🕳 Черная дыра (Притяжение)", 92, C3(60, 30, 80), function()
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
    hole.Material = Enum.Material.SmoothPlastic
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
    glow.Lifetime = NumberRange.new(0.5, 1)
    glow.LightEmission = 1
    
    local pullConn
    pullConn = RunService.Heartbeat:Connect(function()
        if not hole.Parent then pullConn:Disconnect() return end
        for _, m in ipairs(Workspace:GetChildren()) do
            if m:IsA("Model") and m ~= char then
                local root = m:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - targetPos).Magnitude
                    if dist < 50 then
                        local dir = (targetPos - root.Position).Unit
                        root.AssemblyLinearVelocity = dir * 60
                    end
                end
            end
        end
    end)
    
    task.delay(3, function()
        if pullConn then pullConn:Disconnect() end
        hole:Destroy()
    end)
end)

-- ============================================================
-- 8. ОРБИТАЛЬНОЕ ОРУЖИЕ
-- ============================================================
local orbWeaponEnabled = false
local orbFolder = Instance.new("Folder")
orbFolder.Name = "Orbit_Weapons"
orbFolder.Parent = Workspace
local orbParts = {}
local orbAngle = 0

local orbBtn = makeFButton("⚔ Орбитальное оружие: ВЫКЛ", 134, C3(70, 50, 30), function(b)
    orbWeaponEnabled = not orbWeaponEnabled
    b.Text = "⚔ Орбитальное оружие: " .. (orbWeaponEnabled and "ВКЛ" or "ВЫКЛ")
    if orbWeaponEnabled then
        for i = 1, 6 do
            local p = Instance.new("Part")
            p.Size = Vector3.new(0.3, 4, 0.8)
            p.Material = Enum.Material.Neon
            p.Color = C3(255, 200, 50)
            p.Anchored = true
            p.CanCollide = false
            p.Parent = orbFolder
            table.insert(orbParts, p)
        end
    else
        for _, p in ipairs(orbParts) do p:Destroy() end
        orbParts = {}
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
                    local offset = Vector3.new(math.cos(a) * 6, math.sin(tick() * 2 + i) * 0.5, math.sin(a) * 6)
                    p.CFrame = CFrame.new(hrp.Position + offset, hrp.Position + offset + Vector3.new(-math.sin(a), 0, math.cos(a)))
                end
            end
        end
    end
end)

-- ============================================================
-- 9. ЭФФЕКТ «МАТРИЦА»
-- ============================================================
local matrixEnabled = false
local matrixFolder = Instance.new("Folder")
matrixFolder.Name = "Orbit_Matrix"
matrixFolder.Parent = Workspace
local matrixEmitter

local matrixBtn = makeFButton("🟩 Эффект Матрицы: ВЫКЛ", 176, C3(30, 70, 30), function(b)
    matrixEnabled = not matrixEnabled
    b.Text = "🟩 Эффект Матрицы: " .. (matrixEnabled and "ВКЛ" or "ВЫКЛ")
    if matrixEnabled then
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        
        local emitterPart = Instance.new("Part")
        emitterPart.Name = "MatrixEmitter"
        emitterPart.Anchored = true
        emitterPart.CanCollide = false
        emitterPart.Transparency = 1
        emitterPart.Size = Vector3.new(1, 1, 1)
        emitterPart.Parent = matrixFolder
        
        matrixEmitter = Instance.new("ParticleEmitter")
        matrixEmitter.Texture = "rbxassetid://243660364"
        matrixEmitter.Color = ColorSequence.new(C3(0, 255, 0))
        matrixEmitter.Rate = 100
        matrixEmitter.Lifetime = NumberRange.new(1, 2)
        matrixEmitter.Speed = NumberRange.new(30, 40)
        matrixEmitter.SpreadAngle = Vector2.new(10, 10)
        matrixEmitter.Size = NumberSequence.new(1.5)
        matrixEmitter.LightEmission = 1
        matrixEmitter.Acceleration = Vector3.new(0, -50, 0)
        matrixEmitter.Parent = emitterPart
        
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not matrixEnabled or not char.Parent then conn:Disconnect() return end
            local r = char:FindFirstChild("HumanoidRootPart")
            if r then
                emitterPart.CFrame = CFrame.new(r.Position + Vector3.new(0, 40, 0))
                emitterPart.CFrame = CFrame.lookAt(emitterPart.Position, emitterPart.Position + Vector3.new(0, -1, 0))
            end
        end)
        ORBIT._cleanup = ORBIT._cleanup or {}
        table.insert(ORBIT._cleanup, function()
            matrixEnabled = false
            conn:Disconnect()
            emitterPart:Destroy()
        end)
    else
        for _, obj in ipairs(matrixFolder:GetChildren()) do obj:Destroy() end
    end
end)

-- ============================================================
-- 10. КОМБО-УРОН
-- ============================================================
local comboGui = Instance.new("ScreenGui")
comboGui.Name = "Orbit_Combo"
comboGui.ResetOnSpawn = false
comboGui.IgnoreGuiInset = true
comboGui.DisplayOrder = 62
comboGui.Parent = ORBIT.getSafeParent and ORBIT.getSafeParent() or LocalPlayer:WaitForChild("PlayerGui")

local comboLabel = Instance.new("TextLabel")
comboLabel.Size = UDim2.new(0, 300, 0, 80)
comboLabel.Position = UDim2.new(0.5, -150, 0.3, 0)
comboLabel.BackgroundTransparency = 1
comboLabel.Text = ""
comboLabel.TextColor3 = C3(255, 200, 50)
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextSize = 50
comboLabel.TextStrokeTransparency = 0.5
comboLabel.Visible = false
comboLabel.Parent = comboGui

local comboCount = 0
local lastHitTime = 0
local comboTimeout = 1.5
local lastBossHp = 0

ORBIT._cleanup = ORBIT._cleanup or {}
table.insert(ORBIT._cleanup, function() comboGui:Destroy() end)

local function updateCombo()
    if comboCount >= 2 then
        comboLabel.Text = "x" .. comboCount .. " КОМБО!"
        comboLabel.Visible = true
        
        comboLabel.Size = UDim2.new(0, 400, 0, 100)
        comboLabel.Position = UDim2.new(0.5, -200, 0.3, -10)
        TweenService:Create(comboLabel, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 300, 0, 80),
            Position = UDim2.new(0.5, -150, 0.3, 0)
        }):Play()
        
        if comboCount >= 5 then
            comboLabel.TextColor3 = C3(255, 50, 50)
        elseif comboCount >= 3 then
            comboLabel.TextColor3 = C3(255, 150, 50)
        else
            comboLabel.TextColor3 = C3(255, 255, 50)
        end
        
        if ORBIT.playSound then ORBIT.playSound("rbxasset://sounds/electronicpingshort.wav", 0.5, 1 + comboCount * 0.1) end
    else
        comboLabel.Visible = false
    end
end

task.spawn(function()
    while alive do
        task.wait(0.1)
        
        local bossModel = nil
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") and (obj.Name:find("Sans") or obj.Name:find("Gaster")) then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    bossModel = obj
                    break
                end
            end
        end
        
        if bossModel then
            local hum = bossModel:FindFirstChildOfClass("Humanoid")
            local currentHp = hum.Health
            
            if lastBossHp > 0 and currentHp < lastBossHp then
                local now = tick()
                if now - lastHitTime <= comboTimeout then
                    comboCount = comboCount + 1
                else
                    comboCount = 1
                end
                lastHitTime = now
                updateCombo()
            end
            lastBossHp = currentHp
        else
            lastBossHp = 0
            comboCount = 0
            comboLabel.Visible = false
        end
        
        if comboCount > 0 and tick() - lastHitTime > comboTimeout then
            comboCount = 0
            comboLabel.Visible = false
        end
    end
end)

-- ============================================================
-- 11. ФАЗЫ БОЯ (Ярость Босса)
-- ============================================================
local enrageOverlay = Instance.new("Frame")
enrageOverlay.Size = UDim2.new(1, 0, 1, 0)
enrageOverlay.BackgroundColor3 = C3(255, 0, 0)
enrageOverlay.BackgroundTransparency = 1
enrageOverlay.BorderSizePixel = 0
enrageOverlay.ZIndex = 10
enrageOverlay.Parent = comboGui

local bossPhase = 1
local enrageActive = false
local enragedBossModel = nil

local function triggerEnrage(bossModel)
    if enrageActive then return end
    enrageActive = true
    enragedBossModel = bossModel
    bossPhase = 2
    
    enrageOverlay.BackgroundTransparency = 0.5
    TweenService:Create(enrageOverlay, TweenInfo.new(1.5), { BackgroundTransparency = 0.9 }):Play()
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        for i = 1, 10 do
            hum.CameraOffset = Vector3.new(math.random(-1, 1), math.random(-1, 1), 0)
            task.wait(0.05)
        end
        hum.CameraOffset = Vector3.zero
    end
    
    local root = bossModel:FindFirstChild("HumanoidRootPart") or bossModel:FindFirstChild("Torso")
    if root then
        local fire = Instance.new("Fire")
        fire.Size = 10
        fire.Heat = 20
        fire.Color = C3(255, 0, 0)
        fire.SecondaryColor = C3(150, 0, 0)
        fire.Parent = root
        
        local light = Instance.new("PointLight")
        light.Color = C3(255, 0, 0)
        light.Range = 15
        light.Brightness = 5
        light.Parent = root
    end
    
    if ORBIT.playSound then ORBIT.playSound("rbxassetid://113650760423588", 1, 0.8) end
    if ORBIT.notify then ORBIT.notify("🔥 БОСС В ЯРОСТИ! Урон увеличен!", C3(255, 50, 50), 4) end
end

task.spawn(function()
    while alive do
        task.wait(0.5)
        if enrageActive then
            if not enragedBossModel or not enragedBossModel.Parent then
                enrageActive = false
                enragedBossModel = nil
                bossPhase = 1
                enrageOverlay.BackgroundTransparency = 1
            end
        else
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and (obj.Name:find("Sans") or obj.Name:find("Gaster")) then
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local hpPercent = hum.Health / hum.MaxHealth
                        if hpPercent <= 0.5 then
                            triggerEnrage(obj)
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- 12. ЗАВЕРШЕНИЕ И ОЧИСТКА
-- ============================================================
local prevUnload = ORBIT.unload
ORBIT.unload = function()
    alive = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, fn in ipairs(ORBIT._cleanup or {}) do pcall(fn) end
    if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then ORBIT.notify("⚔ Features: Комбо и Фазы загружены!", C3(180, 255, 180), 3) end

-- ============================================================
-- 13. ЗАГРУЗКА (Обязательный возврат)
-- ============================================================
ORBIT.loaded = ORBIT.loaded or {}
ORBIT.loaded.features = true
return true
