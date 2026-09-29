--[[ ОРБИТА v20.8 — P4 часть 2/2: МАГАЗИН + РЕДАКТОР ФИГУР ]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Shop] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit Shop] UI не готов!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local TweenService = ORBIT.TweenService
local HttpService  = ORBIT.HttpService
local LocalPlayer  = ORBIT.LocalPlayer

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local rings    = ORBIT.rings
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS

local screenGui = ORBIT.ui.screenGui

-- ============================================================
--              ХРАНИЛИЩЕ СВОИХ ФИГУР + МОНЕТЫ
-- ============================================================
ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
ORBIT.CUSTOM_FILE = "orbit_v20_custom_shapes.json"
ORBIT.COINS = ORBIT.COINS or 0
ORBIT.COINS_FILE = "orbit_v20_coins.json"

local function loadCustomShapes()
    if not ORBIT.HAS_FS then return end
    pcall(function()
        if isfile(ORBIT.CUSTOM_FILE) then
            local txt = readfile(ORBIT.CUSTOM_FILE)
            if txt and #txt > 0 then
                local data = HttpService:JSONDecode(txt)
                for _, shape in ipairs(data or {}) do
                    table.insert(ORBIT.CUSTOM_SHAPES, shape)
                end
            end
        end
        if isfile(ORBIT.COINS_FILE) then
            local txt = readfile(ORBIT.COINS_FILE)
            if txt and #txt > 0 then
                ORBIT.COINS = tonumber(txt) or 0
            end
        end
    end)
end

local function saveCustomShapes()
    if not ORBIT.HAS_FS then return end
    pcall(function()
        writefile(ORBIT.CUSTOM_FILE, HttpService:JSONEncode(ORBIT.CUSTOM_SHAPES))
        writefile(ORBIT.COINS_FILE, tostring(ORBIT.COINS or 0))
    end)
end

loadCustomShapes()

-- Регистрируем свои фигуры в SHAPE_PRESETS как отдельные пресеты
local function registerCustomShape(shape)
    -- shape = { name = "...", pixels = { "1111", "1001", ... } }  -- 16x16 сетка строк "0"/"1"
    local name = shape.name or ("СВОЯ_" .. (#ORBIT.CUSTOM_SHAPES))
    -- проверяем что уже нет
    for _, sp in ipairs(SHAPE_PRESETS) do
        if sp.name == name then return end
    end
    table.insert(SHAPE_PRESETS, {
        name = name,
        isCustom = true,
        create = function(size, partName)
            local rows = #shape.pixels
            local cols = #shape.pixels[1]
            local pixel = size / math.max(rows, cols)
            local model, root = ORBIT.newModelShell(partName)
            local bodies = {}
            for r = 1, rows do
                local row = shape.pixels[r]
                for c = 1, cols do
                    if row:sub(c,c) == "1" then
                        local px = (c - (cols+1)/2) * pixel
                        local py = ((rows+1)/2 - r) * pixel
                        local p = ORBIT.newPart(model, "P", Vector3.new(pixel, pixel, pixel),
                            CFrame.new(px, py, 0), Color3.fromRGB(255,255,255))
                        table.insert(bodies, p)
                    end
                end
            end
            return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = size }
        end,
    })
end

for _, shape in ipairs(ORBIT.CUSTOM_SHAPES) do
    registerCustomShape(shape)
end

-- ============================================================
--              ПРЕВЬЮ АВАТАРА В VIEWPORTFRAME
-- ============================================================
local function createAvatarPreview(parent, size)
    local vp = Instance.new("ViewportFrame")
    vp.Size = size
    vp.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    vp.BorderSizePixel = 0
    vp.Ambient = Color3.fromRGB(180, 180, 220)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.LightDirection = Vector3.new(-1, -1, -1)
    vp.Parent = parent
    Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 10)

    local world = Instance.new("WorldModel")
    world.Parent = vp

    local cam = Instance.new("Camera")
    cam.FieldOfView = 40
    cam.Parent = vp
    vp.CurrentCamera = cam

    -- Модель — либо аватар игрока, либо dummy
    local avatar
    local ok = pcall(function()
        local desc = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
        avatar = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if not ok or not avatar then
        avatar = Instance.new("Model")
        local torso = Instance.new("Part")
        torso.Name = "Torso"; torso.Size = Vector3.new(2, 2, 1)
        torso.Anchored = true; torso.CanCollide = false
        torso.Color = Color3.fromRGB(100, 150, 255)
        torso.Parent = avatar
        avatar.PrimaryPart = torso
        local head = Instance.new("Part")
        head.Name = "Head"; head.Shape = Enum.PartType.Ball
        head.Size = Vector3.new(1.4, 1.4, 1.4)
        head.Anchored = true; head.CanCollide = false
        head.Color = Color3.fromRGB(255, 220, 180)
        head.CFrame = torso.CFrame * CFrame.new(0, 1.8, 0)
        head.Parent = avatar
    end

    for _, p in ipairs(avatar:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = false
        end
    end
    pcall(function() avatar:PivotTo(CFrame.new(0, 0, 0)) end)
    avatar.Parent = world

    -- Камера смотрит на аватара спереди
    cam.CFrame = CFrame.new(Vector3.new(0, 1.5, -8), Vector3.new(0, 1.5, 0))

    return vp, world, cam, avatar
end

-- ============================================================
--              ДЕМО-КОЛЬЦО В VIEWPORT
-- ============================================================
local function buildDemoRing(world, shapeIndex, color3, sizeMult, blockCount)
    -- Удаляем старое
    local old = world:FindFirstChild("_DemoRing")
    if old then old:Destroy() end

    local folder = Instance.new("Folder")
    folder.Name = "_DemoRing"
    folder.Parent = world

    local shape = SHAPE_PRESETS[shapeIndex] or SHAPE_PRESETS[1]
    local size = 1.2 * (sizeMult or 1.0)
    local count = blockCount or 8
    local blocks = {}

    for i = 1, count do
        local data = shape.create(size, "D_" .. i)
        local refPart = data.part
        if not data.isModel then
            refPart.Material = Enum.Material.Neon
            refPart.Anchored = true
            refPart.CanCollide = false
            refPart.Color = color3
        end
        if data.isModel then
            data.model.Parent = folder
        else
            refPart.Parent = folder
        end
        table.insert(blocks, {
            part = refPart, model = data.model, isModel = data.isModel or false,
            bodyParts = data.bodyParts, index = i,
            angleOffset = (i-1) * (360/count),
        })
    end

    return folder, blocks
end

-- ============================================================
--              МАГАЗИН / КАСТОМАЙЗЕР (ОКНО)
-- ============================================================
local shopOpen = false
local shopGui

local shopState = {
    shapeIndex = ORBIT.shapeIndex,
    colorIndex = P.colorIndex,
    sizeIndex = P.shapeSizeIndex,
    speedIndex = P.speedIndex,
    trail = SETTINGS.TrailEnabled,
    light = SETTINGS.LightEnabled,
    pulse = SETTINGS.PulseEnabled,
    patternIndex = P.orbitPatternIndex,
}

local function openShop()
    if shopOpen and shopGui then return end
    shopOpen = true

    shopGui = Instance.new("Frame")
    shopGui.Name = "_OrbitShop"
    shopGui.Size = UDim2.new(0, 520, 0, 440)
    shopGui.Position = UDim2.new(0.5, -260, 0.5, -220)
    shopGui.BackgroundColor3 = Color3.fromRGB(22, 16, 35)
    shopGui.BackgroundTransparency = 0.05
    shopGui.BorderSizePixel = 0
    shopGui.ZIndex = 10
    shopGui.Parent = screenGui
    Instance.new("UICorner", shopGui).CornerRadius = UDim.new(0, 14)
    local str = Instance.new("UIStroke", shopGui)
    str.Color = Color3.fromRGB(160, 130, 255)
    str.Thickness = 2

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 0, 34)
    title.Position = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "🛒  МАГАЗИН ОРБИТЫ"
    title.TextColor3 = Color3.fromRGB(240, 220, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 11
    title.Parent = shopGui

    local coinsLbl = Instance.new("TextLabel")
    coinsLbl.Size = UDim2.new(0, 120, 0, 24)
    coinsLbl.Position = UDim2.new(1, -190, 0, 10)
    coinsLbl.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
    coinsLbl.BorderSizePixel = 0
    coinsLbl.Text = "💰 " .. (ORBIT.COINS or 0)
    coinsLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
    coinsLbl.Font = Enum.Font.GothamBold
    coinsLbl.TextSize = 12
    coinsLbl.ZIndex = 11
    coinsLbl.Parent = shopGui
    Instance.new("UICorner", coinsLbl).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 11
    closeBtn.Parent = shopGui
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    -- Превью аватара
    local previewBg = Instance.new("Frame")
    previewBg.Size = UDim2.new(0, 230, 0, 300)
    previewBg.Position = UDim2.new(0, 15, 0, 50)
    previewBg.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    previewBg.BorderSizePixel = 0
    previewBg.ZIndex = 11
    previewBg.Parent = shopGui
    Instance.new("UICorner", previewBg).CornerRadius = UDim.new(0, 10)

    local vp, world, cam, avatar = createAvatarPreview(previewBg, UDim2.new(1, 0, 1, 0))
    vp.ZIndex = 12

    -- Правая панель
    local rightPanel = Instance.new("ScrollingFrame")
    rightPanel.Size = UDim2.new(0, 255, 0, 300)
    rightPanel.Position = UDim2.new(0, 252, 0, 50)
    rightPanel.BackgroundColor3 = Color3.fromRGB(18, 14, 30)
    rightPanel.BorderSizePixel = 0
    rightPanel.CanvasSize = UDim2.new(0, 0, 0, 600)
    rightPanel.ScrollBarThickness = 3
    rightPanel.ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255)
    rightPanel.ZIndex = 11
    rightPanel.Parent = shopGui
    Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 10)

    local ry = 6
    local function shopRow(label)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 18)
        lbl.Position = UDim2.new(0, 5, 0, ry)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(200, 200, 230)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 12
        lbl.Parent = rightPanel
        ry = ry + 20

        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, -10, 0, 30)
        holder.Position = UDim2.new(0, 5, 0, ry)
        holder.BackgroundTransparency = 1
        holder.ZIndex = 12
        holder.Parent = rightPanel

        local leftBtn = Instance.new("TextButton")
        leftBtn.Size = UDim2.new(0, 30, 1, 0)
        leftBtn.Position = UDim2.new(0, 0, 0, 0)
        leftBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
        leftBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
        leftBtn.Font = Enum.Font.GothamBold
        leftBtn.TextSize = 14
        leftBtn.Text = "◀"
        leftBtn.ZIndex = 13
        leftBtn.Parent = holder
        Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(1, -70, 1, 0)
        valLbl.Position = UDim2.new(0, 33, 0, 0)
        valLbl.BackgroundColor3 = Color3.fromRGB(35, 28, 50)
        valLbl.BorderSizePixel = 0
        valLbl.Text = "—"
        valLbl.TextColor3 = Color3.fromRGB(240, 230, 255)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 11
        valLbl.ZIndex = 13
        valLbl.Parent = holder
        Instance.new("UICorner", valLbl).CornerRadius = UDim.new(0, 6)

        local rightBtn = Instance.new("TextButton")
        rightBtn.Size = UDim2.new(0, 30, 1, 0)
        rightBtn.Position = UDim2.new(1, -30, 0, 0)
        rightBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
        rightBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
        rightBtn.Font = Enum.Font.GothamBold
        rightBtn.TextSize = 14
        rightBtn.Text = "▶"
        rightBtn.ZIndex = 13
        rightBtn.Parent = holder
        Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 6)

        ry = ry + 34

        return leftBtn, valLbl, rightBtn
    end

    -- ===== ФИГУРА =====
    local shapeL, shapeV, shapeR = shopRow("🔷 ФИГУРА")
    local function updateShape()
        shapeV.Text = SHAPE_PRESETS[shopState.shapeIndex].name
    end
    shapeL.Activated:Connect(function()
        shopState.shapeIndex = shopState.shapeIndex - 1
        if shopState.shapeIndex < 1 then shopState.shapeIndex = #SHAPE_PRESETS end
        updateShape(); rebuildDemo()
    end)
    shapeR.Activated:Connect(function()
        shopState.shapeIndex = shopState.shapeIndex + 1
        if shopState.shapeIndex > #SHAPE_PRESETS then shopState.shapeIndex = 1 end
        updateShape(); rebuildDemo()
    end)

    -- ===== ЦВЕТ =====
    local colL, colV, colR = shopRow("🎨 ЦВЕТ")
    local function updateColor()
        colV.Text = P.COLORS[shopState.colorIndex].name
    end
    colL.Activated:Connect(function()
        shopState.colorIndex = shopState.colorIndex - 1
        if shopState.colorIndex < 1 then shopState.colorIndex = #P.COLORS end
        updateColor(); rebuildDemo()
    end)
    colR.Activated:Connect(function()
        shopState.colorIndex = shopState.colorIndex + 1
        if shopState.colorIndex > #P.COLORS then shopState.colorIndex = 1 end
        updateColor(); rebuildDemo()
    end)

    -- ===== РАЗМЕР =====
    local szL, szV, szR = shopRow("🔍 РАЗМЕР")
    local function updateSize()
        szV.Text = P.SHAPE_SIZE[shopState.sizeIndex].name
    end
    szL.Activated:Connect(function()
        shopState.sizeIndex = shopState.sizeIndex - 1
        if shopState.sizeIndex < 1 then shopState.sizeIndex = #P.SHAPE_SIZE end
        updateSize(); rebuildDemo()
    end)
    szR.Activated:Connect(function()
        shopState.sizeIndex = shopState.sizeIndex + 1
        if shopState.sizeIndex > #P.SHAPE_SIZE then shopState.sizeIndex = 1 end
        updateSize(); rebuildDemo()
    end)

    -- ===== СКОРОСТЬ =====
    local spL, spV, spR = shopRow("⚡ СКОРОСТЬ")
    local function updateSpeed()
        spV.Text = P.SPEED[shopState.speedIndex].name
    end
    spL.Activated:Connect(function()
        shopState.speedIndex = shopState.speedIndex - 1
        if shopState.speedIndex < 1 then shopState.speedIndex = #P.SPEED end
        updateSpeed()
    end)
    spR.Activated:Connect(function()
        shopState.speedIndex = shopState.speedIndex + 1
        if shopState.speedIndex > #P.SPEED then shopState.speedIndex = 1 end
        updateSpeed()
    end)

    -- ===== ЭФФЕКТЫ (кнопки-тумблеры) =====
    local function shopToggle(text, getter, setter)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 28)
        b.Position = UDim2.new(0, 5, 0, ry)
        b.BackgroundColor3 = getter() and Color3.fromRGB(40,70,50) or Color3.fromRGB(45,38,55)
        b.TextColor3 = getter() and Color3.fromRGB(160,255,180) or Color3.fromRGB(220,200,220)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = text .. ": " .. (getter() and "ВКЛ" or "ВЫКЛ")
        b.ZIndex = 12
        b.Parent = rightPanel
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.Activated:Connect(function()
            setter(not getter())
            b.BackgroundColor3 = getter() and Color3.fromRGB(40,70,50) or Color3.fromRGB(45,38,55)
            b.TextColor3 = getter() and Color3.fromRGB(160,255,180) or Color3.fromRGB(220,200,220)
            b.Text = text .. ": " .. (getter() and "ВКЛ" or "ВЫКЛ")
        end)
        ry = ry + 32
    end

    shopToggle("🌠 Трейлы", function() return shopState.trail end, function(v) shopState.trail = v end)
    shopToggle("💡 Свет", function() return shopState.light end, function(v) shopState.light = v end)
    shopToggle("💓 Пульсация", function() shopState.pulse = not shopState.pulse end, function(v) shopState.pulse = v end)

    rightPanel.CanvasSize = UDim2.new(0, 0, 0, ry + 20)

    -- ===== ДЕМО-КОЛЬЦО (крутится) =====
    local demoFolder, demoBlocks = nil, {}

    function rebuildDemo()
        -- пересоздаём
        if demoFolder then demoFolder:Destroy() end
        local col = P.COLORS[shopState.colorIndex]
        local c3 = col.c or Color3.fromRGB(0, 180, 255)
        if col.rainbow then c3 = Color3.fromHSV((tick()*0.2) % 1, 0.9, 1) end
        local sizeMult = P.SHAPE_SIZE[shopState.sizeIndex].factor
        demoFolder, demoBlocks = buildDemoRing(world, shopState.shapeIndex, c3, sizeMult, 8)
    end

    rebuildDemo()

    -- Анимация вращения
    local animConn = RunService.Heartbeat:Connect(function(dt)
        if not shopOpen or not shopGui or not shopGui.Parent then
            if animConn then animConn:Disconnect() end
            return
        end
        local t = tick()
        -- Автовращение аватара
        if avatar then
            pcall(function()
                local rootPart = avatar.PrimaryPart or avatar:FindFirstChild("HumanoidRootPart") or avatar:FindFirstChild("Torso")
                if rootPart then
                    local pivot = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(t * 20) % (math.pi*2), 0)
                    avatar:PivotTo(pivot)
                end
            end)
        end
        -- Крутим демо-кольцо
        local col = P.COLORS[shopState.colorIndex]
        local c3 = col.c or Color3.fromRGB(0, 180, 255)
        if col.rainbow then c3 = Color3.fromHSV((t*0.2) % 1, 0.9, 1) end
        for _, b in ipairs(demoBlocks) do
            local angle = math.rad(t * 90 + b.angleOffset)
            local pos = Vector3.new(math.cos(angle)*2.2, 1.5, math.sin(angle)*2.2)
            local cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
            if b.isModel and b.model then
                pcall(function() b.model:PivotTo(cf) end)
                if b.bodyParts then
                    for _, p in ipairs(b.bodyParts) do
                        if not p:GetAttribute("NoRecolor") then p.Color = c3 end
                    end
                end
            elseif b.part then
                b.part.CFrame = cf
                b.part.Color = c3
            end
        end
    end)

    -- ===== КНОПКИ ВНИЗУ =====
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 220, 0, 40)
    cancelBtn.Position = UDim2.new(0, 15, 1, -52)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 35, 45)
    cancelBtn.TextColor3 = Color3.fromRGB(255, 180, 190)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 13
    cancelBtn.Text = "❌ ОТМЕНА"
    cancelBtn.ZIndex = 11
    cancelBtn.Parent = shopGui
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)

    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(0, 260, 0, 40)
    applyBtn.Position = UDim2.new(0, 245, 1, -52)
    applyBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 55)
    applyBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 13
    applyBtn.Text = "✅ ОПРЕДЕЛИТЬ (применить)"
    applyBtn.ZIndex = 11
    applyBtn.Parent = shopGui
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 10)

    local function closeShop()
        shopOpen = false
        if animConn then animConn:Disconnect() end
        if shopGui then shopGui:Destroy(); shopGui = nil end
    end

    closeBtn.Activated:Connect(closeShop)
    cancelBtn.Activated:Connect(closeShop)

    applyBtn.Activated:Connect(function()
        -- Применяем к кольцу 1
        ORBIT.shapeIndex = shopState.shapeIndex
        P.colorIndex = shopState.colorIndex
        P.shapeSizeIndex = shopState.sizeIndex
        SETTINGS.SpeedMultiplier = P.SPEED[shopState.speedIndex].value
        SETTINGS.TrailEnabled = shopState.trail
        SETTINGS.LightEnabled = shopState.light
        SETTINGS.PulseEnabled = shopState.pulse

        -- Обновляем фигуру кольца 1
        rings[1].shapeIndex = shopState.shapeIndex
        ORBIT.destroyRing(1)
        ORBIT.buildRing(1)
        ORBIT.applyColor()
        ORBIT.applyNameVisibility()

        ORBIT.notify("✅ Магазин применён → кольцо 1", Color3.fromRGB(180,255,180), 3)
        closeShop()
    end)

    updateShape(); updateColor(); updateSize(); updateSpeed()
end

-- ============================================================
--              РЕДАКТОР ПИКСЕЛЬНЫХ ФИГУР
-- ============================================================
local editorOpen = false
local editorGui

local GRID = 16
local editorGrid = {}
local brushState = {}

local function resetGrid()
    editorGrid = {}
    for r = 1, GRID do
        editorGrid[r] = {}
        for c = 1, GRID do
            editorGrid[r][c] = false
        end
    end
end
resetGrid()

local function openEditor()
    if editorOpen and editorGui then return end
    editorOpen = true

    editorGui = Instance.new("Frame")
    editorGui.Name = "_OrbitEditor"
    editorGui.Size = UDim2.new(0, 480, 0, 520)
    editorGui.Position = UDim2.new(0.5, -240, 0.5, -260)
    editorGui.BackgroundColor3 = Color3.fromRGB(22, 16, 35)
    editorGui.BackgroundTransparency = 0.05
    editorGui.BorderSizePixel = 0
    editorGui.ZIndex = 20
    editorGui.Parent = screenGui
    Instance.new("UICorner", editorGui).CornerRadius = UDim.new(0, 14)
    local str = Instance.new("UIStroke", editorGui)
    str.Color = Color3.fromRGB(180, 130, 255)
    str.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 30)
    title.Position = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "🎨  РЕДАКТОР СВОЕЙ ФИГУРЫ"
    title.TextColor3 = Color3.fromRGB(230, 200, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 21
    title.Parent = editorGui

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 21
    closeBtn.Parent = editorGui
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    -- Сетка
    local gridHolder = Instance.new("Frame")
    gridHolder.Size = UDim2.new(0, 320, 0, 320)
    gridHolder.Position = UDim2.new(0, 80, 0, 50)
    gridHolder.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
    gridHolder.BorderSizePixel = 0
    gridHolder.ZIndex = 21
    gridHolder.Parent = editorGui
    Instance.new("UICorner", gridHolder).CornerRadius = UDim.new(0, 8)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 20, 0, 20)
    grid.CellPadding = UDim2.new(0, 0, 0, 0)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = gridHolder

    local pixelFrames = {}
    for r = 1, GRID do
        for c = 1, GRID do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 20, 0, 20)
            btn.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
            btn.BorderSizePixel = 1
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.LayoutOrder = (r-1) * GRID + c
            btn.ZIndex = 22
            btn.Parent = gridHolder
            pixelFrames[(r-1) * GRID + c] = { btn = btn, r = r, c = c }

            local function toggle()
                editorGrid[r][c] = not editorGrid[r][c]
                btn.BackgroundColor3 = editorGrid[r][c] and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(30, 25, 45)
            end

            btn.MouseButton1Down:Connect(toggle)
            btn.MouseButton1Up:Connect(function() end)
            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then toggle() end
            end)
        end
    end

    local function refreshGrid()
        for i, p in pairs(pixelFrames) do
            local on = editorGrid[p.r][p.c]
            p.btn.BackgroundColor3 = on and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(30, 25, 45)
        end
    end

    -- Кнопки слева
    local function sideBtn(text, y, bg, fg, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 65, 0, 34)
        b.Position = UDim2.new(0, 8, 0, y)
        b.BackgroundColor3 = bg
        b.TextColor3 = fg
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = text
        b.ZIndex = 21
        b.Parent = editorGui
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.Activated:Connect(onClick)
        return b
    end

    sideBtn("🗑\nОЧИСТ", 60, Color3.fromRGB(70, 35, 40), Color3.fromRGB(255, 180, 180), function()
        for r = 1, GRID do for c = 1, GRID do editorGrid[r][c] = false end end
        refreshGrid()
    end)
    sideBtn("🔄\nИНВЕРТ", 100, Color3.fromRGB(50, 50, 80), Color3.fromRGB(200, 200, 255), function()
        for r = 1, GRID do for c = 1, GRID do editorGrid[r][c] = not editorGrid[r][c] end end
        refreshGrid()
    end)
    sideBtn("↔\nСИММ", 140, Color3.fromRGB(60, 50, 90), Color3.fromRGB(220, 200, 255), function()
        for r = 1, GRID do
            for c = 1, math.floor(GRID/2) do
                editorGrid[r][GRID - c + 1] = editorGrid[r][c]
            end
        end
        refreshGrid()
    end)
    sideBtn("⬆\nСЕРЕД", 180, Color3.fromRGB(50, 60, 80), Color3.fromRGB(180, 220, 255), function()
        -- Залить центральную область
        for r = 4, 12 do
            for c = 4, 12 do
                editorGrid[r][c] = true
            end
        end
        refreshGrid()
    end)

    -- Поле имени
    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(0, 300, 0, 32)
    nameInput.Position = UDim2.new(0, 80, 0, 385)
    nameInput.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    nameInput.TextColor3 = Color3.fromRGB(230, 220, 255)
    nameInput.Font = Enum.Font.GothamBold
    nameInput.TextSize = 12
    nameInput.PlaceholderText = "Имя фигуры..."
    nameInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
    nameInput.Text = ""
    nameInput.ClearTextOnFocus = false
    nameInput.ZIndex = 21
    nameInput.Parent = editorGui
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 8)

    -- Кнопки внизу
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0, 230, 0, 40)
    saveBtn.Position = UDim2.new(0, 8, 1, -52)
    saveBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 55)
    saveBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 12
    saveBtn.Text = "💾 СОХРАНИТЬ + ПРИМЕНИТЬ"
    saveBtn.ZIndex = 21
    saveBtn.Parent = editorGui
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 10)

    local sellBtn = Instance.new("TextButton")
    sellBtn.Size = UDim2.new(0, 230, 0, 40)
    sellBtn.Position = UDim2.new(1, -238, 1, -52)
    sellBtn.BackgroundColor3 = Color3.fromRGB(90, 70, 30)
    sellBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
    sellBtn.Font = Enum.Font.GothamBold
    sellBtn.TextSize = 12
    sellBtn.Text = "💰 ПРОДАТЬ МАГАЗИНУ (+50)"
    sellBtn.ZIndex = 21
    sellBtn.Parent = editorGui
    Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 10)

    local function closeEditor()
        editorOpen = false
        if editorGui then editorGui:Destroy(); editorGui = nil end
    end
    closeBtn.Activated:Connect(closeEditor)

    local function gridToStrings()
        local out = {}
        for r = 1, GRID do
            local row = ""
            for c = 1, GRID do
                row = row .. (editorGrid[r][c] and "1" or "0")
            end
            table.insert(out, row)
        end
        return out
    end

    saveBtn.Activated:Connect(function()
        local name = nameInput.Text
        if not name or name == "" then
            name = "СВОЯ_" .. (#ORBIT.CUSTOM_SHAPES + 1)
        end
        local shape = { name = name, pixels = gridToStrings() }
        table.insert(ORBIT.CUSTOM_SHAPES, shape)
        registerCustomShape(shape)
        saveCustomShapes()

        ORBIT.notify("🎨 Фигура '" .. name .. "' сохранена!", Color3.fromRGB(180,255,220), 3)

        -- Сразу применяем как текущую
        for i, sp in ipairs(SHAPE_PRESETS) do
            if sp.name == name then
                ORBIT.shapeIndex = i
                rings[1].shapeIndex = i
                ORBIT.destroyRing(1)
                ORBIT.buildRing(1)
                ORBIT.applyColor()
                break
            end
        end
        closeEditor()
    end)

    sellBtn.Activated:Connect(function()
        local name = nameInput.Text
        if not name or name == "" then name = "ПРОДАННАЯ" end
        local shape = { name = name .. "_" .. tick() % 1000, pixels = gridToStrings() }
        ORBIT.COINS = (ORBIT.COINS or 0) + 50
        saveCustomShapes()
        ORBIT.notify("💰 Продано! +50 монет (всего " .. ORBIT.COINS .. ")", Color3.fromRGB(255,220,120), 3)
        closeEditor()
    end)
end

-- ============================================================
--              ПРИВЯЗКА КНОПОК
-- ============================================================
if ORBIT.ui.openShopBtn then
    ORBIT.ui.openShopBtn.Activated:Connect(function()
        if ORBIT.uiMode == "shop" or true then
            openShop()
        end
    end)
end

if ORBIT.ui.openEditorBtn then
    ORBIT.ui.openEditorBtn.Activated:Connect(function()
        openEditor()
    end)
end

ORBIT.openShop = openShop
ORBIT.openEditor = openEditor

if ORBIT.notify then
    ORBIT.notify("🛒 Магазин и редактор готовы!", Color3.fromRGB(220,200,255), 3)
end

return true
