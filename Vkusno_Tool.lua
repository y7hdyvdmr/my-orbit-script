-- Вкусно — и Точка Generator (standalone)
local G = rawget(_G, "getgenv") and getgenv() or _G
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local V3, RGB = Vector3.new, Color3.fromRGB

local function mkp(name, size, pos, color, mat, shape, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = pos
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
local function buildRestaurant(cf, targetPart)
    if targetPart then
        targetPart.Transparency = 1
        targetPart.CanCollide = false
    end
    
    local model = Instance.new("Model")
    model.Name = "Vkusno_i_Tochka"
    model.Parent = Workspace
    
    -- Масштаб здания (примерно 40x20x40 стадов)
    local base = CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(math.random(-4, 4) * 90), 0)
    
    -- 1. ПОЛ И ПОТОЛОК
    local floor = mkp("Floor", V3(40, 1, 40), base.Position - V3(0, 0.5, 0), RGB(40, 40, 40), Enum.Material.Concrete, nil, model)
    local roof = mkp("Roof", V3(40, 1, 40), base.Position + V3(0, 15, 0), RGB(20, 20, 25), Enum.Material.Metal, nil, model)
    
    -- 2. ВНЕШНИЕ СТЕНЫ (Деревянные рейки снаружи)
    local wallColor = RGB(120, 70, 40)
    local function makeWall(offset, size, isGlass)
        local w = mkp("Wall", size, base.Position + offset, isGlass and RGB(150, 220, 255) or wallColor, isGlass and Enum.Material.Glass or Enum.Material.WoodPlanks, nil, model)
        w.CFrame = base * CFrame.new(offset)
        w.Transparency = isGlass and 0.5 or 0
        return w
    end
    
    -- Задняя и боковые стены (сплошные)
    makeWall(V3(0, 7.5, 20), V3(40, 15, 1))
    makeWall(V3(20, 7.5, 0), V3(1, 15, 40))
    makeWall(V3(-20, 7.5, 0), V3(1, 15, 40))
    
    -- Фасад (передняя часть с окнами)
    makeWall(V3(0, 7.5, -20), V3(40, 3, 1)) -- Верхняя часть
    makeWall(V3(-15, 5, -20), V3(10, 10, 1), true) -- Окно левое
    makeWall(V3(15, 5, -20), V3(10, 10, 1), true) -- Окно правое
    makeWall(V3(0, 5, -20), V3(10, 10, 1)) -- Центральная дверь (стекло)
    
    -- 3. ВЫВЕСКА "ВКУСНО И ТОЧКА"
    local sign = mkp("SignBoard", V3(30, 5, 1), base.Position + V3(0, 12, -20.5), RGB(255, 255, 255), Enum.Material.SmoothPlastic, nil, model)
    sign.CFrame = base * CFrame.new(0, 12, -20.5)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(800, 120)
    sg.Parent = sign
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Text = "ВКУСНО — И ТОЧКА"
    text.TextColor3 = RGB(255, 255, 255)
    text.Font = Enum.Font.GothamBlack
    text.TextScaled = true
    text.Parent = sg
    
    -- Логотип (оранжевые палочки)
    for i=1, 3 do
        mkp("Logo", V3(1.5, 4, 0.5), base.Position + V3(-18 + i*2, 12, -21), RGB(255, 100, 0), Enum.Material.Neon, nil, model)
    end

    -- 4. ИНТЕРЬЕР: Касса и стойка
    local counter = mkp("Counter", V3(25, 3, 4), base.Position + V3(0, 1.5, 5), RGB(240, 240, 240), Enum.Material.SmoothPlastic, nil, model)
    counter.CFrame = base * CFrame.new(0, 1.5, 5)
    
    -- Кассовые аппараты (черные коробочки)
    for i=1, 3 do
        mkp("Cashier", V3(2, 1.5, 1.5), base.Position + V3(-8 + i*8, 3.5, 5), RGB(30, 30, 30), Enum.Material.Metal, nil, model).CFrame = base * CFrame.new(-8 + i*8, 3.5, 5)
        mkp("Screen", V3(1.5, 1, 0.2), base.Position + V3(-8 + i*8, 4, 4.5), RGB(0, 200, 255), Enum.Material.Neon, nil, model).CFrame = base * CFrame.new(-8 + i*8, 4, 4.5)
    end

    -- 5. ПОТОЛОЧНЫЕ ЭКРАНЫ (Меню)
    for i=1, 3 do
        local menu = mkp("MenuScreen", V3(10, 4, 0.5), base.Position + V3(-10 + (i-1)*10, 10, 7), RGB(10, 10, 10), Enum.Material.SmoothPlastic, nil, model)
        menu.CFrame = base * CFrame.new(-10 + (i-1)*10, 10, 7)
        local msg = Instance.new("SurfaceGui")
        msg.Face = Enum.NormalId.Front
        msg.CanvasSize = Vector2.new(400, 160)
        msg.Parent = menu
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Text = i == 1 and "Бургеры\nи Наггетсы" or (i == 2 and "Картофель\nи Соусы" or "Напитки\nи Десерты")
        lbl.TextColor3 = RGB(255, 255, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextScaled = true
        lbl.Parent = msg
    end

    -- 6. ШАРИКИ (Оранжевые, Зелёные, Белые)
    local balloonColors = {RGB(255, 100, 0), RGB(0, 180, 80), RGB(255, 255, 255)}
    for i=1, 15 do
        local c = balloonColors[math.random(1, 3)]
        local b = mkp("Balloon", V3(2, 2, 2), base.Position + V3(math.random(-15, 15), math.random(9, 13), math.random(0, 10)), c, Enum.Material.SmoothPlastic, Enum.PartType.Ball, model)
        b.CFrame = base * CFrame.new(math.random(-15, 15), math.random(9, 13), math.random(0, 10))
    end

    -- 7. ПЕЧЬ (Справа)
    local oven = mkp("Oven", V3(8, 6, 8), base.Position + V3(14, 3, 10), RGB(150, 150, 150), Enum.Material.Metal, nil, model)
    oven.CFrame = base * CFrame.new(14, 3, 10)
    local fire = mkp("Fire", V3(6, 3, 1), base.Position + V3(14, 3, 6), RGB(255, 100, 0), Enum.Material.Neon, nil, model)
    fire.CFrame = base * CFrame.new(14, 3, 6)
    local light = Instance.new("PointLight")
    light.Color = RGB(255, 150, 50)
    light.Range = 12
    light.Brightness = 3
    light.Parent = fire

    -- Эффект появления
    local burst = mkp("Burst", V3(1,1,1), base.Position, RGB(255,255,255), Enum.Material.Neon, nil, model)
    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 0
    pe.Speed = NumberRange.new(20, 40)
    pe.Lifetime = NumberRange.new(0.5, 1)
    pe.Color = ColorSequence.new(RGB(255, 200, 100))
    pe.Parent = burst
    pe:Emit(100)
    task.delay(2, function() burst:Destroy() end)
    
    return model
end
-- ============================================================
--  СОЗДАНИЕ ПРЕДМЕТА
-- ============================================================
local tool = Instance.new("Tool")
tool.Name = "Генератор Вкусно — и Точка"
tool.RequiresHandle = true
tool.CanBeDropped = false

-- Ручка (коробка с логотипом)
local handle = mkp("Handle", V3(1.5, 1.5, 1.5), V3(0,0,0), RGB(255, 100, 0), Enum.Material.SmoothPlastic, nil, tool)
handle.CFrame = CFrame.new(0, 0, 0)

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
    
    -- Луч из камеры в точку клика
    local mouse = LP:GetMouse()
    local targetPos = mouse.Hit.Position
    local targetPart = mouse.Target
    
    -- Проверка на дистанцию (не дальше 100 стадов)
    if (targetPos - hrp.Position).Magnitude > 100 then
        return
    end
    
    -- Строим ресторан на месте блока
    buildRestaurant(mouse.Hit, targetPart)
    
    -- Звук
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://3314038600" -- Portal sound
    snd.Volume = 1
    snd.Parent = handle
    snd:Play()
    task.delay(3, function() snd:Destroy() end)
end)

-- Выдаем предмет игроку
tool.Parent = LP:WaitForChild("Backpack")

-- Оповещение
local function notify(text)
    print("[В&Т] " .. text)
    -- Если хочешь красивое уведомление на экране, можем добавить позже
end
notify("Генератор Вкусно — и Точка выдан! Кликай по блокам.")
