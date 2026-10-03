--[[ ОРБИТА v23.0 — P4_SHOP (Магазин + Редактор)
     🐛 Фикс: проверка OWNED_SHAPES при выборе фигуры
     🐛 Фикс: SESSION теперь защищён от nil
     🐛 Убрано слово «ОПРЕДЕЛИТЬ» из кнопки
     🆕 Категории фигур + кнопка покупки с ценой
     🆕 Адаптив под мобилку/ПК
]]

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
local IS_MOBILE = (ORBIT.PLATFORM == "mobile")

-- ============================================================
--              ХРАНИЛИЩЕ
-- ============================================================
ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
ORBIT.CUSTOM_FILE = "orbit_v21_custom_shapes.json"
ORBIT.COINS = ORBIT.COINS or 0
ORBIT.COINS_FILE = "orbit_v21_coins.json"
ORBIT.OWNED_SHAPES = ORBIT.OWNED_SHAPES or {
    ["БЛОК"] = true, ["ШАР"] = true, ["ЦИЛИНДР"] = true,
}

local SHAPE_PRICES = {
    ["БЛОК"] = 0, ["ШАР"] = 0, ["ЦИЛИНДР"] = 0, ["КЛИН"] = 50,
    ["ГОЛОВА"] = 80, ["СЕРДЦЕ"] = 100, ["ЗВЕЗДА"] = 100, ["ТРЕУГОЛЬНИК"] = 100,
    ["РОМБ"] = 120, ["КРЕСТ"] = 150, ["ЧЕРЕП"] = 200, ["МОЛНИЯ"] = 200,
    ["РУКА"] = 250, ["РУКА-СЕРДЦЕ"] = 300, ["МЕЧ"] = 400, ["ЩИТ"] = 400,
    ["КОСТЬ"] = 100, ["ПИРАМИДА"] = 150, ["ИНЬ-ЯН"] = 250, ["ГЛАЗ"] = 200,
    ["СПИРАЛЬ"] = 200, ["КРЫЛЬЯ"] = 300, ["ЩУПАЛЬЦЕ"] = 350, ["ГАСТЕР БЛАСТЕР"] = 450,
}

local function saveStorage()
    if not ORBIT.HAS_FS then return end
    pcall(function()
        writefile(ORBIT.CUSTOM_FILE, HttpService:JSONEncode(ORBIT.CUSTOM_SHAPES))
        writefile(ORBIT.COINS_FILE, tostring(ORBIT.COINS or 0))
        local owned = {}
        for k, v in pairs(ORBIT.OWNED_SHAPES) do if v then table.insert(owned, k) end end
        writefile("orbit_v21_owned.json", HttpService:JSONEncode(owned))
    end)
end

local function loadStorage()
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
            if txt and #txt > 0 then ORBIT.COINS = tonumber(txt) or 0 end
        end
        if isfile("orbit_v21_owned.json") then
            local txt = readfile("orbit_v21_owned.json")
            if txt and #txt > 0 then
                local data = HttpService:JSONDecode(txt)
                for _, name in ipairs(data or {}) do ORBIT.OWNED_SHAPES[name] = true end
            end
        end
    end)
end

local function registerCustomShape(shape)
    local name = shape.name or ("СВОЯ_" .. (#ORBIT.CUSTOM_SHAPES))
    for _, sp in ipairs(SHAPE_PRESETS) do
        if sp.name == name then return end
    end
    table.insert(SHAPE_PRESETS, {
        name = name,
        isCustom = true,
        create = function(size, partName)
            local rows = #shape.pixels
            local cols = #shape.pixels[1]
            local pixel = size * 1.8 / math.max(rows, cols)
            local model, root = ORBIT.newModelShell(partName)
            local bodies = {}
            for r = 1, rows do
                local row = shape.pixels[r]
                for c = 1, cols do
                    if row:sub(c, c) == "1" then
                        local px = (c - (cols + 1) / 2) * pixel
                        local py = ((rows + 1) / 2 - r) * pixel
                        local p = ORBIT.newPart(model, "P", Vector3.new(pixel, pixel, pixel),
                            CFrame.new(px, py, 0), Color3.fromRGB(255, 255, 255))
                        table.insert(bodies, p)
                    end
                end
            end
            return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = size }
        end,
    })
    ORBIT.OWNED_SHAPES[name] = true
end

loadStorage()
for _, shape in ipairs(ORBIT.CUSTOM_SHAPES) do
    registerCustomShape(shape)
end

-- ============================================================
--              ПРЕВЬЮ АВАТАРА
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

    cam.CFrame = CFrame.new(Vector3.new(0, 1.5, -8), Vector3.new(0, 1.5, 0))

    return vp, world, cam, avatar
end

local function buildDemoRing(world, shapeIndex, color3, sizeMult, blockCount)
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
--              МАГАЗИН
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
    categoryIndex = 1,
}

-- Категории для магазина
local SHOP_CATEGORIES = {
    { name = "ВСЕ" },
    { name = "ОСНОВНЫЕ", shapes = {"БЛОК","ШАР","ЦИЛИНДР","КЛИН","ТРЕУГОЛЬНИК","ЗВЕЗДА","КРЕСТ","РОМБ","КОСТЬ","ПИРАМИДА","СПИРАЛЬ"} },
    { name = "ОРУЖИЕ",   shapes = {"МЕЧ","ЩИТ"} },
    { name = "МАГИЯ",    shapes = {"ГЛАЗ","ИНЬ-ЯН","МОЛНИЯ","ГАСТЕР БЛАСТЕР"} },
    { name = "СУЩЕСТВА", shapes = {"ЧЕРЕП","РУКА","РУКА-СЕРДЦЕ","ГОЛОВА","СЕРДЦЕ","КРЫЛЬЯ","ЩУПАЛЬЦЕ"} },
    { name = "СВОИ",     custom = true },
}

local function getShopShapes()
    local cat = SHOP_CATEGORIES[shopState.categoryIndex]
    local list = {}
    if cat.custom then
        for i, sp in ipairs(SHAPE_PRESETS) do
            if sp.isCustom then table.insert(list, i) end
        end
    elseif not cat.shapes then
        for i = 1, #SHAPE_PRESETS do list[i] = i end
    else
        for _, name in ipairs(cat.shapes) do
            for i, sp in ipairs(SHAPE_PRESETS) do
                if sp.name == name then table.insert(list, i); break end
            end
        end
    end
    return list
end

local function openShop()
    if shopOpen and shopGui then return end
    shopOpen = true

    local shopW = IS_MOBILE and 320 or 560
    local shopH = IS_MOBILE and 540 or 500

    shopGui = Instance.new("Frame")
    shopGui.Name = "_OrbitShop"
    shopGui.Size = UDim2.new(0, shopW, 0, shopH)
    shopGui.Position = UDim2.new(0.5, -shopW/2, 0.5, -shopH/2)
    shopGui.BackgroundColor3 = Color3.fromRGB(22, 16, 35)
    shopGui.BackgroundTransparency = 0.05
    shopGui.BorderSizePixel = 0
    shopGui.ZIndex = 10
    shopGui.Parent = screenGui
    Instance.new("UICorner", shopGui).CornerRadius = UDim.new(0, 16)
    local str = Instance.new("UIStroke", shopGui)
    str.Color = Color3.fromRGB(180, 140, 255)
    str.Thickness = 2

    if ORBIT.ui.fitToScreen then
        ORBIT.ui.fitToScreen(shopGui, shopW, shopH)
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 0, 28)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🛒  МАГАЗИН"
    title.TextColor3 = Color3.fromRGB(240, 220, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 11
    title.Parent = shopGui

    local coinsLbl = Instance.new("TextLabel")
    coinsLbl.Name = "_CoinsLbl"
    coinsLbl.Size = UDim2.new(0, 130, 0, 26)
    coinsLbl.Position = UDim2.new(1, -170, 0, 10)
    coinsLbl.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
    coinsLbl.BorderSizePixel = 0
    coinsLbl.Text = "💰 " .. (ORBIT.COINS or 0)
    coinsLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
    coinsLbl.Font = Enum.Font.GothamBold
    coinsLbl.TextSize = 12
    coinsLbl.ZIndex = 11
    coinsLbl.Parent = shopGui
    Instance.new("UICorner", coinsLbl).CornerRadius = UDim.new(0, 8)

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

    -- Layout: preview слева, настройки справа (на мобилке — preview сверху)
    local previewW = IS_MOBILE and (shopW - 32) or 240
    local previewH = IS_MOBILE and 200 or 300
    local previewFrame = Instance.new("Frame")
    previewFrame.Size = UDim2.new(0, previewW, 0, previewH)
    previewFrame.Position = UDim2.new(0, 16, 0, 44)
    previewFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    previewFrame.BorderSizePixel = 0
    previewFrame.ZIndex = 11
    previewFrame.Parent = shopGui
    Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 10)

    local vp, world, cam, avatar = createAvatarPreview(previewFrame, UDim2.new(1, 0, 1, 0))
    vp.ZIndex = 12

    -- Панель настроек
    local rightX = IS_MOBILE and 16 or 272
    local rightY = IS_MOBILE and (44 + previewH + 8) or 44
    local rightW = IS_MOBILE and (shopW - 32) or 272
    local rightH = IS_MOBILE and (shopH - rightY - 60) or (shopH - 100)

    local rightPanel = Instance.new("ScrollingFrame")
    rightPanel.Size = UDim2.new(0, rightW, 0, rightH)
    rightPanel.Position = UDim2.new(0, rightX, 0, rightY)
    rightPanel.BackgroundColor3 = Color3.fromRGB(18, 14, 30)
    rightPanel.BorderSizePixel = 0
    rightPanel.CanvasSize = UDim2.new(0, 0, 0, 900)
    rightPanel.ScrollBarThickness = 4
    rightPanel.ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255)
    rightPanel.ZIndex = 11
    rightPanel.Parent = shopGui
    Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 10)

    local ry = 8

    -- Заголовок-строка
    local function shopRow(label, hintText)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 16)
        lbl.Position = UDim2.new(0, 6, 0, ry)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(220, 220, 250)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 12
        lbl.Parent = rightPanel
        ry = ry + 16

        if hintText then
            local hint = Instance.new("TextLabel")
            hint.Size = UDim2.new(1, -12, 0, 12)
            hint.Position = UDim2.new(0, 6, 0, ry)
            hint.BackgroundTransparency = 1
            hint.Text = hintText
            hint.TextColor3 = Color3.fromRGB(150, 145, 180)
            hint.Font = Enum.Font.Gotham
            hint.TextSize = 9
            hint.TextXAlignment = Enum.TextXAlignment.Left
            hint.ZIndex = 12
            hint.Parent = rightPanel
            ry = ry + 12
        end

        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, -12, 0, 30)
        holder.Position = UDim2.new(0, 6, 0, ry)
        holder.BackgroundTransparency = 1
        holder.ZIndex = 12
        holder.Parent = rightPanel

        local leftBtn = Instance.new("TextButton")
        leftBtn.Size = UDim2.new(0, 30, 1, 0)
        leftBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
        leftBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
        leftBtn.Font = Enum.Font.GothamBold
        leftBtn.TextSize = 14
        leftBtn.Text = "◀"
        leftBtn.ZIndex = 13
        leftBtn.Parent = holder
        Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(1, -72, 1, 0)
        valLbl.Position = UDim2.new(0, 34, 0, 0)
        valLbl.BackgroundColor3 = Color3.fromRGB(35, 28, 50)
        valLbl.BorderSizePixel = 0
        valLbl.Text = "—"
        valLbl.TextColor3 = Color3.fromRGB(240, 230, 255)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 11
        valLbl.TextTruncate = Enum.TextTruncate.AtEnd
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

    local demoFolder, demoBlocks = nil, {}

    local function refreshDemo()
        if demoFolder then demoFolder:Destroy() end
        local col = P.COLORS[shopState.colorIndex]
        local c3 = col.c or Color3.fromRGB(0, 180, 255)
        if col.rainbow then c3 = Color3.fromHSV((tick()*0.2) % 1, 0.9, 1) end
        local sizeMult = P.SHAPE_SIZE[shopState.sizeIndex].factor
        demoFolder, demoBlocks = buildDemoRing(world, shopState.shapeIndex, c3, sizeMult, 8)
    end

    -- Категория
    local catL, catV, catR = shopRow("📁 КАТЕГОРИЯ", "Фильтр списка фигур")
    local shopShapeIdx = 1
    local function refreshShopShapeList()
        local list = getShopShapes()
        if #list == 0 then shopShapeIdx = 1; return end
        shopShapeIdx = math.clamp(shopShapeIdx, 1, #list)
        shopState.shapeIndex = list[shopShapeIdx]
    end
    local function updateCat() catV.Text = SHOP_CATEGORIES[shopState.categoryIndex].name end
    catL.Activated:Connect(function()
        shopState.categoryIndex = shopState.categoryIndex - 1
        if shopState.categoryIndex < 1 then shopState.categoryIndex = #SHOP_CATEGORIES end
        shopShapeIdx = 1
        updateCat(); refreshShopShapeList(); refreshShapeLbl(); refreshDemo()
    end)
    catR.Activated:Connect(function()
        shopState.categoryIndex = shopState.categoryIndex + 1
        if shopState.categoryIndex > #SHOP_CATEGORIES then shopState.categoryIndex = 1 end
        shopShapeIdx = 1
        updateCat(); refreshShopShapeList(); refreshShapeLbl(); refreshDemo()
    end)

    -- Фигура (с проверкой владения!)
    local sL, sV, sR = shopRow("🔷 ФИГУРА", "Стрелки листают по категории")
    local buyShapeBtn = Instance.new("TextButton")
    buyShapeBtn.Size = UDim2.new(1, -12, 0, 28)
    buyShapeBtn.Position = UDim2.new(0, 6, 0, ry)
    buyShapeBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 90)
    buyShapeBtn.TextColor3 = Color3.fromRGB(255, 220, 150)
    buyShapeBtn.Font = Enum.Font.GothamBold
    buyShapeBtn.TextSize = 11
    buyShapeBtn.Text = "🔓 КУПИТЬ: ---"
    buyShapeBtn.ZIndex = 12
    buyShapeBtn.Parent = rightPanel
    Instance.new("UICorner", buyShapeBtn).CornerRadius = UDim.new(0, 6)
    ry = ry + 32

    local function refreshShapeLbl()
        refreshShopShapeList()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp then return end
        sV.Text = sp.name
        local owned = ORBIT.OWNED_SHAPES[sp.name]
        local price = SHAPE_PRICES[sp.name] or 0
        if owned then
            buyShapeBtn.Text = "✅ УЖЕ КУПЛЕНО"
            buyShapeBtn.BackgroundColor3 = Color3.fromRGB(40,70,50)
            buyShapeBtn.TextColor3 = Color3.fromRGB(160,255,180)
        elseif price == 0 then
            buyShapeBtn.Text = "🆓 БЕСПЛАТНО (нажми)"
            buyShapeBtn.BackgroundColor3 = Color3.fromRGB(40,60,60)
            buyShapeBtn.TextColor3 = Color3.fromRGB(180,230,255)
        else
            buyShapeBtn.Text = "💰 КУПИТЬ за " .. price
            buyShapeBtn.BackgroundColor3 = Color3.fromRGB(60,45,90)
            buyShapeBtn.TextColor3 = Color3.fromRGB(255,220,150)
        end
    end

    sL.Activated:Connect(function()
        local list = getShopShapes()
        if #list == 0 then return end
        shopShapeIdx = shopShapeIdx - 1
        if shopShapeIdx < 1 then shopShapeIdx = #list end
        shopState.shapeIndex = list[shopShapeIdx]
        refreshShapeLbl(); refreshDemo()
    end)
    sR.Activated:Connect(function()
        local list = getShopShapes()
        if #list == 0 then return end
        shopShapeIdx = shopShapeIdx + 1
        if shopShapeIdx > #list then shopShapeIdx = 1 end
        shopState.shapeIndex = list[shopShapeIdx]
        refreshShapeLbl(); refreshDemo()
    end)

    -- 🐛 Кнопка покупки
    buyShapeBtn.Activated:Connect(function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp then return end
        if ORBIT.OWNED_SHAPES[sp.name] then
            ORBIT.notify("✅ Уже куплено", Color3.fromRGB(160,255,180), 2)
            return
        end
        local price = SHAPE_PRICES[sp.name] or 0
        if price > 0 and (ORBIT.COINS or 0) < price then
            ORBIT.notify("❌ Нужно " .. price .. " монет (у тебя " .. ORBIT.COINS .. ")", Color3.fromRGB(255,100,100), 3)
            return
        end
        if price > 0 then ORBIT.COINS = ORBIT.COINS - price end
        ORBIT.OWNED_SHAPES[sp.name] = true
        saveStorage()
        if ORBIT.playBuy then pcall(ORBIT.playBuy) end
        ORBIT.notify("✅ Куплено: " .. sp.name, Color3.fromRGB(160,255,180), 3)
        coinsLbl.Text = "💰 " .. (ORBIT.COINS or 0)
        refreshShapeLbl()
    end)

    -- Цвет
    local cL, cV, cR = shopRow("🎨 ЦВЕТ")
    local function updateColor() cV.Text = P.COLORS[shopState.colorIndex].name end
    cL.Activated:Connect(function()
        shopState.colorIndex = shopState.colorIndex - 1
        if shopState.colorIndex < 1 then shopState.colorIndex = #P.COLORS end
        updateColor(); refreshDemo()
    end)
    cR.Activated:Connect(function()
        shopState.colorIndex = shopState.colorIndex + 1
        if shopState.colorIndex > #P.COLORS then shopState.colorIndex = 1 end
        updateColor(); refreshDemo()
    end)

    -- Размер
    local zL, zV, zR = shopRow("🔍 РАЗМЕР ФИГУРЫ")
    local function updateSize() zV.Text = P.SHAPE_SIZE[shopState.sizeIndex].name end
    zL.Activated:Connect(function()
        shopState.sizeIndex = shopState.sizeIndex - 1
        if shopState.sizeIndex < 1 then shopState.sizeIndex = #P.SHAPE_SIZE end
        updateSize(); refreshDemo()
    end)
    zR.Activated:Connect(function()
        shopState.sizeIndex = shopState.sizeIndex + 1
        if shopState.sizeIndex > #P.SHAPE_SIZE then shopState.sizeIndex = 1 end
        updateSize(); refreshDemo()
    end)

    -- Скорость
    local spL, spV, spR = shopRow("⚡ СКОРОСТЬ ВРАЩЕНИЯ")
    local function updateSpeed() spV.Text = P.SPEED[shopState.speedIndex].name end
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

    -- Эффекты
    local effectsLbl = Instance.new("TextLabel")
    effectsLbl.Size = UDim2.new(1, -12, 0, 18)
    effectsLbl.Position = UDim2.new(0, 6, 0, ry)
    effectsLbl.BackgroundTransparency = 1
    effectsLbl.Text = "✨ ЭФФЕКТЫ"
    effectsLbl.TextColor3 = Color3.fromRGB(220, 220, 250)
    effectsLbl.Font = Enum.Font.GothamBold
    effectsLbl.TextSize = 11
    effectsLbl.TextXAlignment = Enum.TextXAlignment.Left
    effectsLbl.ZIndex = 12
    effectsLbl.Parent = rightPanel
    ry = ry + 20

    local function shopToggle(text, getter, setter)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 28)
        b.Position = UDim2.new(0, 6, 0, ry)
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
    shopToggle("💓 Пульсация", function() return shopState.pulse end, function(v) shopState.pulse = v end)

    rightPanel.CanvasSize = UDim2.new(0, 0, 0, ry + 20)

    -- Анимация
    local animConn = RunService.Heartbeat:Connect(function(dt)
        if not shopOpen or not shopGui or not shopGui.Parent then
            if animConn then animConn:Disconnect() end
            return
        end
        local t = tick()

        if avatar then
            pcall(function()
                local rootPart = avatar.PrimaryPart or avatar:FindFirstChild("HumanoidRootPart") or avatar:FindFirstChild("Torso")
                if rootPart then
                    local pivot = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(t * 20) % (math.pi*2), 0)
                    avatar:PivotTo(pivot)
                end
            end)
        end

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

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, rightW, 0, 36)
    cancelBtn.Position = UDim2.new(0, rightX, 1, -46)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 35, 45)
    cancelBtn.TextColor3 = Color3.fromRGB(255, 180, 190)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 12
    cancelBtn.Text = "❌ ОТМЕНА"
    cancelBtn.ZIndex = 11
    cancelBtn.Parent = shopGui
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)

    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(0, rightW, 0, 36)
    applyBtn.Position = UDim2.new(0, rightX, 1, -46)
    applyBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 55)
    applyBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 12
    applyBtn.Text = "✅ ПРИМЕНИТЬ (кольцо 1)"
    applyBtn.ZIndex = 11
    applyBtn.Parent = shopGui
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 10)

    -- Если мобилка — растянем кнопки на нижнюю полосу
    if IS_MOBILE then
        cancelBtn.Size = UDim2.new(0.5, -20, 0, 36)
        cancelBtn.Position = UDim2.new(0, 16, 1, -46)
        applyBtn.Size = UDim2.new(0.5, -20, 0, 36)
        applyBtn.Position = UDim2.new(0.5, 4, 1, -46)
    end

    local function closeShop()
        shopOpen = false
        if animConn then animConn:Disconnect() end
        if shopGui then shopGui:Destroy(); shopGui = nil end
    end

    closeBtn.Activated:Connect(closeShop)
    cancelBtn.Activated:Connect(closeShop)

    -- 🐛 Проверка владения при применении
    applyBtn.Activated:Connect(function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if sp and not ORBIT.OWNED_SHAPES[sp.name] then
            local price = SHAPE_PRICES[sp.name] or 0
            if price > 0 then
                ORBIT.notify("🔒 Сначала купи «" .. sp.name .. "» за " .. price, Color3.fromRGB(255,180,120), 3)
                return
            end
        end
        ORBIT.shapeIndex = shopState.shapeIndex
        P.colorIndex = shopState.colorIndex
        P.shapeSizeIndex = shopState.sizeIndex
        SETTINGS.SpeedMultiplier = P.SPEED[shopState.speedIndex].value
        SETTINGS.TrailEnabled = shopState.trail
        SETTINGS.LightEnabled = shopState.light
        SETTINGS.PulseEnabled = shopState.pulse

        rings[1].shapeIndex = shopState.shapeIndex
        ORBIT.destroyRing(1); ORBIT.buildRing(1)
        ORBIT.applyColor(); ORBIT.applyNameVisibility()

        ORBIT.notify("✅ Применено к кольцу 1!", Color3.fromRGB(180,255,180), 3)
        closeShop()
    end)

    updateCat(); refreshShapeLbl(); updateColor(); updateSize(); updateSpeed(); refreshDemo()
end

-- ============================================================
--              РЕДАКТОР ПИКСЕЛЬНЫХ ФИГУР
-- ============================================================
local editorOpen = false
local editorGui

local GRID = 16
local editorGrid = {}

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

    local editorW = IS_MOBILE and 340 or 520
    local editorH = IS_MOBILE and 560 or 600

    editorGui = Instance.new("Frame")
    editorGui.Name = "_OrbitEditor"
    editorGui.Size = UDim2.new(0, editorW, 0, editorH)
    editorGui.Position = UDim2.new(0.5, -editorW/2, 0.5, -editorH/2)
    editorGui.BackgroundColor3 = Color3.fromRGB(22, 16, 35)
    editorGui.BackgroundTransparency = 0.05
    editorGui.BorderSizePixel = 0
    editorGui.ZIndex = 20
    editorGui.Parent = screenGui
    Instance.new("UICorner", editorGui).CornerRadius = UDim.new(0, 16)
    local str = Instance.new("UIStroke", editorGui)
    str.Color = Color3.fromRGB(180, 130, 255)
    str.Thickness = 2

    if ORBIT.ui.fitToScreen then
        ORBIT.ui.fitToScreen(editorGui, editorW, editorH)
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 28)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🎨  РЕДАКТОР ФИГУРЫ"
    title.TextColor3 = Color3.fromRGB(230, 200, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 21
    title.Parent = editorGui

    local subTitle = Instance.new("TextLabel")
    subTitle.Size = UDim2.new(1, -60, 0, 16)
    subTitle.Position = UDim2.new(0, 16, 0, 34)
    subTitle.BackgroundTransparency = 1
    subTitle.Text = "Клик по клетке → закрасить"
    subTitle.TextColor3 = Color3.fromRGB(180, 160, 220)
    subTitle.Font = Enum.Font.Gotham
    subTitle.TextSize = 10
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.ZIndex = 21
    subTitle.Parent = editorGui

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

    -- Размер сетки в зависимости от платформы
    local gridPx = IS_MOBILE and 260 or 340
    local cellPx = gridPx / GRID

    local gridHolder = Instance.new("Frame")
    gridHolder.Size = UDim2.new(0, gridPx, 0, gridPx)
    gridHolder.Position = UDim2.new(0.5, -gridPx/2, 0, 60)
    gridHolder.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
    gridHolder.BorderSizePixel = 0
    gridHolder.ZIndex = 21
    gridHolder.Parent = editorGui
    Instance.new("UICorner", gridHolder).CornerRadius = UDim.new(0, 8)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, cellPx, 0, cellPx)
    grid.CellPadding = UDim2.new(0, 0, 0, 0)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = gridHolder

    local pixelFrames = {}
    for r = 1, GRID do
        for c = 1, GRID do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, cellPx, 0, cellPx)
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

            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                   or input.UserInputType == Enum.UserInputType.Touch then
                    toggle()
                end
            end)
        end
    end

    local function refreshGrid()
        for i, p in pairs(pixelFrames) do
            local on = editorGrid[p.r][p.c]
            p.btn.BackgroundColor3 = on and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(30, 25, 45)
        end
    end

    local toolsY = 60 + gridPx + 8
    local toolsRow = Instance.new("Frame")
    toolsRow.Size = UDim2.new(1, -32, 0, 34)
    toolsRow.Position = UDim2.new(0, 16, 0, toolsY)
    toolsRow.BackgroundTransparency = 1
    toolsRow.ZIndex = 21
    toolsRow.Parent = editorGui

    local function toolBtn(text, xPos, bg, fg, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.24, -4, 1, 0)
        b.Position = UDim2.new(xPos, 0, 0, 0)
        b.BackgroundColor3 = bg
        b.TextColor3 = fg
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9
        b.Text = text
        b.ZIndex = 22
        b.Parent = toolsRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.Activated:Connect(onClick)
        return b
    end

    toolBtn("🗑 ОЧИСТ", 0, Color3.fromRGB(70, 35, 40), Color3.fromRGB(255, 180, 180), function()
        for r = 1, GRID do for c = 1, GRID do editorGrid[r][c] = false end end
        refreshGrid()
    end)
    toolBtn("🔄 ИНВЕРТ", 0.25, Color3.fromRGB(50, 50, 80), Color3.fromRGB(200, 200, 255), function()
        for r = 1, GRID do for c = 1, GRID do editorGrid[r][c] = not editorGrid[r][c] end end
        refreshGrid()
    end)
    toolBtn("↔ СИММЕТ", 0.5, Color3.fromRGB(60, 50, 90), Color3.fromRGB(220, 200, 255), function()
        for r = 1, GRID do
            for c = 1, math.floor(GRID/2) do
                editorGrid[r][GRID - c + 1] = editorGrid[r][c]
            end
        end
        refreshGrid()
    end)
    toolBtn("⬆ ЦЕНТР", 0.75, Color3.fromRGB(50, 60, 80), Color3.fromRGB(180, 220, 255), function()
        for r = 4, 12 do
            for c = 4, 12 do
                editorGrid[r][c] = true
            end
        end
        refreshGrid()
    end)

    local nameY = toolsY + 42
    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, -32, 0, 32)
    nameInput.Position = UDim2.new(0, 16, 0, nameY)
    nameInput.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    nameInput.TextColor3 = Color3.fromRGB(230, 220, 255)
    nameInput.Font = Enum.Font.GothamBold
    nameInput.TextSize = 12
    nameInput.PlaceholderText = "✏️ Имя фигуры..."
    nameInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
    nameInput.Text = ""
    nameInput.ClearTextOnFocus = false
    nameInput.ZIndex = 21
    nameInput.Parent = editorGui
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 8)

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0.48, -20, 0, 40)
    saveBtn.Position = UDim2.new(0, 16, 1, -50)
    saveBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 55)
    saveBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 11
    saveBtn.Text = "💾 СОХРАНИТЬ"
    saveBtn.ZIndex = 21
    saveBtn.Parent = editorGui
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 10)

    local sellBtn = Instance.new("TextButton")
    sellBtn.Size = UDim2.new(0.48, -20, 0, 40)
    sellBtn.Position = UDim2.new(0.5, 4, 1, -50)
    sellBtn.BackgroundColor3 = Color3.fromRGB(90, 70, 30)
    sellBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
    sellBtn.Font = Enum.Font.GothamBold
    sellBtn.TextSize = 11
    sellBtn.Text = "💰 ПРОДАТЬ +50"
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
        local strings = gridToStrings()
        local filled = 0
        for _, row in ipairs(strings) do
            for _ in row:gmatch("1") do filled = filled + 1 end
        end
        if filled < 3 then
            ORBIT.notify("🎨 Закрась хотя бы 3 клетки", Color3.fromRGB(255, 200, 120), 2)
            return
        end

        local name = nameInput.Text
        if name == "" or not utf8.len(name) or utf8.len(name) > 20 then
            name = "СВОЯ_" .. (#SHAPE_PRESETS + 1)
        end

        local function exists(nm)
            for _, sp in ipairs(SHAPE_PRESETS) do if sp.name == nm then return true end end
            return false
        end
        local base, n = name, 1
        while exists(name) do
            n = n + 1
            name = base .. "_" .. n
        end

        local shape = { name = name, pixels = strings }
        registerCustomShape(shape)
        table.insert(ORBIT.CUSTOM_SHAPES, shape)
        saveStorage()

        ORBIT.notify("🎨 Фигура '" .. name .. "' сохранена!", Color3.fromRGB(180,255,220), 3)

        for i, sp in ipairs(SHAPE_PRESETS) do
            if sp.name == name then
                ORBIT.shapeIndex = i
                rings[1].shapeIndex = i
                ORBIT.destroyRing(1); ORBIT.buildRing(1); ORBIT.applyColor()
                break
            end
        end
        closeEditor()
    end)

    sellBtn.Activated:Connect(function()
        local strings = gridToStrings()
        local filled = 0
        for _, row in ipairs(strings) do
            for _ in row:gmatch("1") do filled = filled + 1 end
        end
        if filled < 8 then
            ORBIT.notify("🎨 Минимум 8 клеток для продажи", Color3.fromRGB(255, 200, 120), 2)
            return
        end

        ORBIT.COINS = (ORBIT.COINS or 0) + 50
        ORBIT.SESSION = ORBIT.SESSION or {}
        ORBIT.SESSION.coinsEarned = (ORBIT.SESSION.coinsEarned or 0) + 50
        saveStorage()
        ORBIT.notify("💰 +50 монет (всего: " .. ORBIT.COINS .. ")", Color3.fromRGB(255,220,120), 3)
        if ORBIT.playBuy then pcall(ORBIT.playBuy) end
        closeEditor()
    end)
end

-- ============================================================
--              ПРИВЯЗКА КНОПОК
-- ============================================================
if ORBIT.ui.openShopBtn then
    ORBIT.ui.openShopBtn.Activated:Connect(function() openShop() end)
end

if ORBIT.ui.openEditorBtn then
    ORBIT.ui.openEditorBtn.Activated:Connect(function() openEditor() end)
end

ORBIT.openShop = openShop
ORBIT.openEditor = openEditor
ORBIT.SHAPE_PRICES = SHAPE_PRICES

if ORBIT.notify then
    ORBIT.notify("🛒 Магазин + Редактор v23.0 готовы", Color3.fromRGB(220,200,255), 3)
end

return true
