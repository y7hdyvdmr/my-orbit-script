-- Вкусно — и Точка Generator v2 (Полная детализация)
local G = rawget(_G, "getgenv") and getgenv() or _G
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local V3, RGB = Vector3.new, Color3.fromRGB

-- Универсальная функция создания детали
local function mkp(name, size, cf, color, mat, shape, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Color = color or RGB(255,255,255)
    p.Material = mat or Enum.Material.SmoothPlastic
    if shape then p.Shape = shape end
    p.Parent = parent or Workspace
    return p
end

-- Создание одного ресторана
local function buildRestaurant(cf)
    local model = Instance.new("Model")
    model.Name = "Vkusno_i_Tochka"
    model.Parent = Workspace
    
    -- Центр здания
    local center = CFrame.new(cf.Position) * CFrame.Angles(0, cf.LookVector.X, 0) -- Разворот по взгляду
    
    -- ================= ЭКСТЕРЬЕР =================
    -- 1. Основной пол
    mkp("Floor", V3(44, 1, 44), center * CFrame.new(0, -0.5, 0), RGB(60, 60, 60), Enum.Material.Concrete, nil, model)
    
    -- 2. Деревянные стены (задняя и боковые)
    local woodColor = RGB(130, 75, 45)
    local wallMat = Enum.Material.WoodPlanks
    mkp("BackWall", V3(44, 16, 1), center * CFrame.new(0, 8, 22), woodColor, wallMat, nil, model)
    mkp("LeftWall", V3(1, 16, 44), center * CFrame.new(-22, 8, 0), woodColor, wallMat, nil, model)
    mkp("RightWall", V3(1, 16, 44), center * CFrame.new(22, 8, 0), woodColor, wallMat, nil, model)
    
    -- 3. Стеклянный фасад
    local glassColor = RGB(200, 230, 255)
    for i = -1, 1 do
        -- Окна
        mkp("GlassWindow", V3(12, 10, 0.5), center * CFrame.new(i * 14, 6, -22), glassColor, Enum.Material.Glass, nil, model).Transparency = 0.4
    end
    
    -- 4. Наклонная деревянная крыша (Козырек)
    local roofCF = center * CFrame.new(0, 16, -22) * CFrame.Angles(math.rad(-15), 0, 0)
    mkp("WoodRoof", V3(46, 6, 4), roofCF, woodColor, wallMat, nil, model)
    -- Рейки на крыше
    for i = -22, 22, 2 do
        mkp("RoofSlat", V3(0.5, 6.5, 4.2), roofCF * CFrame.new(i, 0, 0), RGB(100, 55, 35), wallMat, nil, model)
    end
    
    -- 5. Вывеска "ВКУСНО — И ТОЧКА"
    local signPart = mkp("Sign", V3(30, 4, 0.5), center * CFrame.new(0, 15, -23.5), RGB(130, 75, 45), Enum.Material.SmoothPlastic, nil, model)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(1000, 150)
    sg.LightInfluence = 0
    sg.Parent = signPart
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1
    txt.Text = "ВКУСНО — И ТОЧКА"
    txt.TextColor3 = RGB(255, 255, 255)
    txt.Font = Enum.Font.GothamBlack
    txt.TextScaled = true
    txt.Parent = sg
    -- Логотип (оранжевые палочки)
    for i = 1, 3 do
        mkp("Logo", V3(1.5, 4, 0.5), center * CFrame.new(-18 + i*2, 15, -23.2), RGB(255, 100, 0), Enum.Material.Neon, nil, model)
    end
    
    -- 6. Уличные зонтики и столики
    for i = -1, 1, 2 do
        local umbPos = center * CFrame.new(i * 16, 0, -30)
        -- Ножка зонтика
        mkp("UmbPole", V3(0.5, 10, 0.5), umbPos * CFrame.new(0, 5, 0), RGB(40, 40, 40), Enum.Material.Metal, nil, model)
        -- Купол зонтика (используем цилиндр)
        mkp("UmbTop", V3(0.5, 12, 12), umbPos * CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.rad(90)), RGB(30, 30, 30), Enum.Material.Fabric, Enum.PartType.Cylinder, model)
        -- Столик
        mkp("Table", V3(4, 0.2, 4), umbPos * CFrame.new(0, 2, 0), RGB(100, 60, 40), Enum.Material.Wood, nil, model)
        -- Скамейки
        mkp("Bench", V3(4, 0.2, 1), umbPos * CFrame.new(0, 1, 3), RGB(100, 60, 40), Enum.Material.Wood, nil, model)
    end

    -- 7. Заборчик и кусты
    for i = -22, 22, 2 do
        mkp("Bush", V3(2, 2, 2), center * CFrame.new(i, 0, -25), RGB(40, 80, 30), Enum.Material.Grass, Enum.PartType.Ball, model)
    end

    -- ================= ИНТЕРЬЕР =================
    -- 1. Черный потолок
    mkp("Ceiling", V3(42, 1, 42), center * CFrame.new(0, 16, 0), RGB(15, 15, 18), Enum.Material.Metal, nil, model)
    
    -- 2. Квадратные светильники на потолке
    for x = -12, 12, 12 do
        for z = -10, 10, 10 do
            local lightPart = mkp("LightPanel", V3(3, 0.2, 3), center * CFrame.new(x, 15.4, z), RGB(255, 255, 255), Enum.Material.Neon, nil, model)
            local pl = Instance.new("PointLight")
            pl.Color = RGB(255, 255, 255)
            pl.Range = 15
            pl.Brightness = 2
            pl.Parent = lightPart
        end
    end

    -- 3. Гирлянды из шаров (Оранжевые, Зеленые, Белые)
    local bColors = {RGB(255, 100, 0), RGB(0, 160, 80), RGB(255, 255, 255)}
    local function makeBalloonCluster(pos, amount)
        for i = 1, amount do
            local c = bColors[math.random(1, 3)]
            local offset = V3(math.random(-2, 2), math.random(-2, 2), math.random(-2, 2))
            mkp("Balloon", V3(1.5, 1.8, 1.5), center * CFrame.new(pos + offset), c, Enum.Material.SmoothPlastic, Enum.PartType.Ball, model)
        end
    end
    -- Шарики вдоль потолка
    for i = -15, 15, 5 do
        makeBalloonCluster(V3(i, 14, -8), 4)
        makeBalloonCluster(V3(i, 14, 8), 4)
    end

    -- 4. Кассовая стойка (Белая с черным)
    mkp("CounterBase", V3(30, 3, 4), center * CFrame.new(0, 1.5, 5), RGB(250, 250, 250), Enum.Material.SmoothPlastic, nil, model)
    mkp("CounterTop", V3(31, 0.4, 5), center * CFrame.new(0, 3.2, 5), RGB(30, 30, 30), Enum.Material.SmoothPlastic, nil, model)
    
    -- Кассы и мониторы
    for i = -1, 1 do
        mkp("Cashier", V3(2.5, 1.5, 1.5), center * CFrame.new(i * 8, 3.8, 5), RGB(20, 20, 20), Enum.Material.Metal, nil, model)
        mkp("Screen", V3(2, 1.2, 0.2), center * CFrame.new(i * 8, 4.5, 4.2), RGB(0, 150, 255), Enum.Material.Neon, nil, model)
        -- Деревянные подносы на стойке
        mkp("Tray", V3(4, 0.5, 2), center * CFrame.new(i * 8, 3.5, 6.5), RGB(180, 130, 90), Enum.Material.Wood, nil, model)
    end

    -- 5. Экраны меню на потолке (черные панели с текстом)
    for i = -1, 1 do
        local menuPos = center * CFrame.new(i * 12, 11, 10)
        local menuPart = mkp("MenuBoard", V3(10, 4, 0.2), menuPos, RGB(10, 10, 15), Enum.Material.SmoothPlastic, nil, model)
        local msg = Instance.new("SurfaceGui")
        msg.Face = Enum.NormalId.Front
        msg.CanvasSize = Vector2.new(500, 200)
        msg.LightInfluence = 0
        msg.Parent = menuPart
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Text = i == -1 and "ТЕ САМЫЕ\nВКУСЫ" or (i == 0 and "БУРГЕРЫ\nИ КАРТОШКА" or "НАПИТКИ\nИ ДЕСЕРТЫ")
        lbl.TextColor3 = RGB(255, 255, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.Parent = msg
    end

    -- 6. Печь на заднем плане (справа)
    local ovenBase = center * CFrame.new(15, 2, 15)
    mkp("OvenBase", V3(8, 4, 6), ovenBase, RGB(120, 120, 120), Enum.Material.Metal, nil, model)
    local fire = mkp("Fire", V3(6, 3, 1), ovenBase * CFrame.new(0, 0, -3.5), RGB(255, 100, 0), Enum.Material.Neon, nil, model)
    local fl = Instance.new("PointLight")
    fl.Color = RGB(255, 150, 50)
    fl.Range = 15
    fl.Brightness = 3
    fl.Parent = fire

    -- Эффект появления
    local burst = mkp("Burst", V3(1,1,1), center.Position, RGB(255,255,255), Enum.Material.Neon, nil, model)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 0
    pe.Speed = NumberRange.new(20, 40)
    pe.Lifetime = NumberRange.new(0.5, 1)
    pe.Color = ColorSequence.new(RGB(255, 200, 100))
    pe.Parent = burst
    pe:Emit(150)
    task.delay(2, function() burst:Destroy() end)
    
    return model
end
-- ============================================================
--  СОЗДАНИЕ ПРЕДМЕТА (ИСПРАВЛЕН БАГ С ЗАСТРЕВАНИЕМ)
-- ============================================================
local tool = Instance.new("Tool")
tool.Name = "Вкусно — и Точка"
tool.RequiresHandle = true
tool.CanBeDropped = false

-- ВАЖНО: Handle НЕ Anchored, иначе игрок застрянет!
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = V3(1.5, 1.5, 1.5)
handle.Anchored = false 
handle.CanCollide = false
handle.Massless = true
handle.Color = RGB(255, 100, 0) -- Оранжевый
handle.Material = Enum.Material.SmoothPlastic
handle.Parent = tool

-- Логотип на коробке
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.CanvasSize = Vector2.new(200, 200)
sg.Parent = handle
local logo = Instance.new("TextLabel")
logo.Size = UDim2.fromScale(1, 1)
logo.BackgroundTransparency = 1
logo.Text = "В&Т\nГЕНЕРАТОР"
logo.TextColor3 = RGB(255, 255, 255)
logo.Font = Enum.Font.GothamBlack
logo.TextScaled = true
logo.Parent = sg

-- Логика клика
tool.Activated:Connect(function()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local mouse = LP:GetMouse()
    local targetPos = mouse.Hit.Position
    
    -- Проверка на дистанцию (не дальше 100 стадов)
    if (targetPos - hrp.Position).Magnitude > 100 then return end
    
    -- Если кликнули по пустоте, ставим под ноги
    if mouse.Target == nil then
        targetPos = hrp.Position - V3(0, 3, 0)
    end
    
    -- Строим ресторан
    buildRestaurant(mouse.Hit)
    
    -- Звук
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://3314038600"
    snd.Volume = 1
    snd.Parent = handle
    snd:Play()
    task.delay(3, function() snd:Destroy() end)
end)

-- Выдаем предмет игроку
tool.Parent = LP:WaitForChild("Backpack")

print("[В&Т] Генератор выдан! Кликай по земле, чтобы построить ресторан.")
