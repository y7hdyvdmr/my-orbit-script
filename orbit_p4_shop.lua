--[[ ОРБИТА v23.1 — P4_SHOP (Магазин + 2D-Редактор + 3D-Редактор)
     🆕 Улучшенный 2D: сетка 24×24, палитра, кисти, undo, preview
     🆕 Кнопка «Открыть 3D-редактор»
     🐛 Фикс OWNED_SHAPES, SESSION
     🎨 Категории фигур + покупка с ценой
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

-- Универсальный регистратор (поддерживает 2D и 3D)
local function registerCustomShape(shape)
    local name = shape.name or ("СВОЯ_" .. (#ORBIT.CUSTOM_SHAPES))
    for _, sp in ipairs(SHAPE_PRESETS) do
        if sp.name == name then return end
    end

    -- 3D-формат (уже готовый)
    if shape.is3D and shape.blocks then
        local size = shape.N or 6
        local blocksCopy = {}
        for _, b in ipairs(shape.blocks) do
            table.insert(blocksCopy, {x=b.x, y=b.y, z=b.z,
                color = Color3.new(b.r or 1, b.g or 1, b.b or 1)})
        end
        table.insert(SHAPE_PRESETS, {
            name = name, isCustom = true, is3D = true,
            create = function(shapeSize, partName)
                local model, root = ORBIT.newModelShell(partName)
                local bodies = {}
                local unit = shapeSize / size
                local cx, cy, cz = (size + 1) / 2, (size + 1) / 2, (size + 1) / 2
                for _, c in ipairs(blocksCopy) do
                    local p = ORBIT.newPart(model, "V",
                        Vector3.new(unit * 0.95, unit * 0.95, unit * 0.95),
                        CFrame.new((c.x - cx) * unit, (c.y - cy) * unit, (c.z - cz) * unit),
                        c.color, true)
                    table.insert(bodies, p)
                end
                return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = shapeSize * 1.4 }
            end,
        })
        ORBIT.OWNED_SHAPES[name] = true
        return
    end

    -- 2D-формат
    -- Поддерживаем 2 варианта: {pixels = {"1010"...}} и {pixels = {{colorIdx,...}}}
    local rows = #shape.pixels
    local cols = #shape.pixels[1]
    local pixelData = {}  -- [r][c] = Color3 или nil

    local PALETTE_REF = {
        Color3.fromRGB(255, 60, 60),   Color3.fromRGB(255, 140, 40),
        Color3.fromRGB(255, 230, 60),  Color3.fromRGB(120, 255, 100),
        Color3.fromRGB(80, 255, 180),  Color3.fromRGB(80, 220, 255),
        Color3.fromRGB(60, 120, 255),  Color3.fromRGB(140, 80, 255),
        Color3.fromRGB(220, 80, 255),  Color3.fromRGB(255, 80, 180),
        Color3.fromRGB(255, 200, 200), Color3.fromRGB(255, 240, 200),
        Color3.fromRGB(200, 240, 255), Color3.fromRGB(200, 255, 220),
        Color3.fromRGB(200, 200, 255), Color3.fromRGB(240, 200, 255),
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200),
        Color3.fromRGB(120, 120, 130), Color3.fromRGB(60, 60, 70),
        Color3.fromRGB(30, 30, 40),    Color3.fromRGB(255, 200, 100),
        Color3.fromRGB(255, 240, 120), Color3.fromRGB(180, 130, 60),
    }

    for r = 1, rows do
        pixelData[r] = {}
        local row = shape.pixels[r]
        if type(row) == "string" then
            -- Старый формат: "1010"
            for c = 1, #row do
                if row:sub(c, c) == "1" then
                    pixelData[r][c] = Color3.fromRGB(255, 255, 255)
                end
            end
        elseif type(row) == "table" then
            -- Новый формат: {1, 2, 0, 5...} где 0 = пусто, иначе индекс палитры
            for c = 1, #row do
                local v = row[c]
                if v and v > 0 then
                    pixelData[r][c] = PALETTE_REF[v] or Color3.fromRGB(255, 255, 255)
                end
            end
        end
    end

    table.insert(SHAPE_PRESETS, {
        name = name, isCustom = true,
        create = function(shapeSize, partName)
            local pixel = shapeSize * 1.8 / math.max(rows, cols)
            local model, root = ORBIT.newModelShell(partName)
            local bodies = {}
            for r = 1, rows do
                for c = 1, cols do
                    local col = pixelData[r][c]
                    if col then
                        local px = (c - (cols + 1) / 2) * pixel
                        local py = ((rows + 1) / 2 - r) * pixel
                        local p = ORBIT.newPart(model, "P",
                            Vector3.new(pixel, pixel, pixel),
                            CFrame.new(px, py, 0), col, true)
                        table.insert(bodies, p)
                    end
                end
            end
            return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = shapeSize }
        end,
    })
    ORBIT.OWNED_SHAPES[name] = true
end

loadStorage()
for _, shape in ipairs(ORBIT.CUSTOM_SHAPES) do
    registerCustomShape(shape)
end
ORBIT.registerCustomShape = registerCustomShape

-- ============================================================
--       ПАЛИТРА (та же, что в 3D)
-- ============================================================
local PALETTE = {
    Color3.fromRGB(255, 60, 60),   Color3.fromRGB(255, 140, 40),
    Color3.fromRGB(255, 230, 60),  Color3.fromRGB(120, 255, 100),
    Color3.fromRGB(80, 255, 180),  Color3.fromRGB(80, 220, 255),
    Color3.fromRGB(60, 120, 255),  Color3.fromRGB(140, 80, 255),
    Color3.fromRGB(220, 80, 255),  Color3.fromRGB(255, 80, 180),
    Color3.fromRGB(255, 200, 200), Color3.fromRGB(255, 240, 200),
    Color3.fromRGB(200, 240, 255), Color3.fromRGB(200, 255, 220),
    Color3.fromRGB(200, 200, 255), Color3.fromRGB(240, 200, 255),
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200),
    Color3.fromRGB(120, 120, 130), Color3.fromRGB(60, 60, 70),
    Color3.fromRGB(30, 30, 40),    Color3.fromRGB(255, 200, 100),
    Color3.fromRGB(255, 240, 120), Color3.fromRGB(180, 130, 60),
}

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
        if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
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

    -- Кнопка «Открыть 3D-редактор» (вверху, справа от монет)
    local open3DBtn = Instance.new("TextButton")
    open3DBtn.Size = UDim2.new(0, 130, 0, 26)
    open3DBtn.Position = UDim2.new(1, -310, 0, 10)
    open3DBtn.BackgroundColor3 = Color3.fromRGB(80, 45, 130)
    open3DBtn.TextColor3 = Color3.fromRGB(230, 200, 255)
    open3DBtn.Font = Enum.Font.GothamBold
    open3DBtn.TextSize = 11
    open3DBtn.Text = "🔮 3D-РЕДАКТОР"
    open3DBtn.ZIndex = 11
    open3DBtn.Parent = shopGui
    Instance.new("UICorner", open3DBtn).CornerRadius = UDim.new(0, 8)
    open3DBtn.Activated:Connect(function()
        if ORBIT.openEditor3D then
            ORBIT.openEditor3D()
        else
            ORBIT.notify("❌ 3D-Редактор не загружен", Color3.fromRGB(255,120,120), 2)
        end
    end)

    -- Layout
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
    local catL, catV, catR = shopRow("📁 КАТЕГОРИЯ")
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

    local sL, sV, sR = shopRow("🔷 ФИГУРА")
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

    buyShapeBtn.Activated:Connect(function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp then return end
        if ORBIT.OWNED_SHAPES[sp.name] then
            ORBIT.notify("✅ Уже куплено", Color3.fromRGB(160,255,180), 2)
            return
        end
        local price = SHAPE_PRICES[sp.name] or 0
        if price > 0 and (ORBIT.COINS or 0) < price then
            ORBIT.notify("❌ Нужно " .. price .. " монет", Color3.fromRGB(255,100,100), 3)
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
    local cL, cV, cR = shopRow("🎨 ЦВЕТ КОЛЬЦА")
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
    local spL, spV, spR = shopRow("⚡ СКОРОСТЬ")
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
                    avatar:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(t * 20) % (math.pi*2), 0))
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

    applyBtn.Activated:Connect(function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if sp and not ORBIT.OWNED_SHAPES[sp.name] then
            local price = SHAPE_PRICES[sp.name] or 0
            if price > 0 then
                ORBIT.notify("🔒 Сначала купи «" .. sp.name .. "»", Color3.fromRGB(255,180,120), 3)
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
--       УЛУЧШЕННЫЙ 2D-РЕДАКТОР
-- ============================================================
local editorOpen = false
local editorGui

local GRID = 24
local Ed2D = {
    Cells = {},         -- [r][c] = colorIndex (0 = пусто)
    Brush = 1,          -- 1 = кисть 1×1, 2 = 2×2, 3 = 3×3
    EraserMode = false,
    FillMode = false,
    CurrentColor = 1,
    History = {},
    HistoryIdx = 0,
    MaxHistory = 20,
}

local function keyOf(r, c) return r .. "," .. c end

local function reset2DGrid()
    Ed2D.Cells = {}
    for r = 1, GRID do
        Ed2D.Cells[r] = {}
        for c = 1, GRID do Ed2D.Cells[r][c] = 0 end
    end
    Ed2D.History = {}
    Ed2D.HistoryIdx = 0
end
reset2DGrid()

local function snapshot2D()
    local s = {}
    for r = 1, GRID do
        s[r] = {}
        for c = 1, GRID do s[r][c] = Ed2D.Cells[r][c] end
    end
    return s
end

local function push2DHistory()
    Ed2D.HistoryIdx = Ed2D.HistoryIdx + 1
    while #Ed2D.History > Ed2D.HistoryIdx - 1 do table.remove(Ed2D.History) end
    table.insert(Ed2D.History, snapshot2D())
    if #Ed2D.History > Ed2D.MaxHistory then table.remove(Ed2D.History, 1); Ed2D.HistoryIdx = Ed2D.HistoryIdx - 1 end
end

local function apply2DHistory(idx)
    local s = Ed2D.History[idx]
    if not s then return end
    for r = 1, GRID do
        for c = 1, GRID do
            Ed2D.Cells[r][c] = s[r][c] or 0
        end
    end
end

local function do2DUndo()
    if Ed2D.HistoryIdx <= 1 then return end
    Ed2D.HistoryIdx = Ed2D.HistoryIdx - 1
    apply2DHistory(Ed2D.HistoryIdx)
end
local function do2DRedo()
    if Ed2D.HistoryIdx >= #Ed2D.History then return end
    Ed2D.HistoryIdx = Ed2D.HistoryIdx + 1
    apply2DHistory(Ed2D.HistoryIdx)
end

local function floodFill2D(r0, c0, newColor)
    local old = Ed2D.Cells[r0][c0]
    if old == newColor then return end
    local stack = {{r0, c0}}
    local seen = {}
    while #stack > 0 do
        local p = table.remove(stack)
        local r, c = p[1], p[2]
        local k = keyOf(r, c)
        if not seen[k] and r >= 1 and r <= GRID and c >= 1 and c <= GRID and Ed2D.Cells[r][c] == old then
            seen[k] = true
            Ed2D.Cells[r][c] = newColor
            table.insert(stack, {r+1, c})
            table.insert(stack, {r-1, c})
            table.insert(stack, {r, c+1})
            table.insert(stack, {r, c-1})
        end
    end
end

local function openEditor()
    if editorOpen and editorGui then return end
    editorOpen = true

    local editorW = IS_MOBILE and 360 or 640
    local editorH = IS_MOBILE and 620 or 640

    editorGui = Instance.new("Frame")
    editorGui.Name = "_OrbitEditor2D"
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

    if ORBIT.ui.fitToScreen then ORBIT.ui.fitToScreen(editorGui, editorW, editorH) end

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -200, 0, 26)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🎨 2D-РЕДАКТОР"
    title.TextColor3 = Color3.fromRGB(230, 200, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 21
    title.Parent = editorGui

    -- Кнопка «3D-редактор»
    local to3DBtn = Instance.new("TextButton")
    to3DBtn.Size = UDim2.new(0, 130, 0, 26)
    to3DBtn.Position = UDim2.new(1, -180, 0, 8)
    to3DBtn.BackgroundColor3 = Color3.fromRGB(80, 45, 130)
    to3DBtn.TextColor3 = Color3.fromRGB(230, 200, 255)
    to3DBtn.Font = Enum.Font.GothamBold
    to3DBtn.TextSize = 11
    to3DBtn.Text = "🔮 3D-РЕДАКТОР"
    to3DBtn.ZIndex = 21
    to3DBtn.Parent = editorGui
    Instance.new("UICorner", to3DBtn).CornerRadius = UDim.new(0, 8)
    to3DBtn.Activated:Connect(function()
        if ORBIT.openEditor3D then ORBIT.openEditor3D() end
    end)

    -- Кнопка закрытия
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 21
    closeBtn.Parent = editorGui
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    -- Layout
    local leftX = 16
    local topY = 42

    -- Сетка
    local gridPx = IS_MOBILE and 320 or 380
    local cellPx = gridPx / GRID

    local gridHolder = Instance.new("Frame")
    gridHolder.Size = UDim2.new(0, gridPx, 0, gridPx)
    gridHolder.Position = UDim2.new(0, leftX, 0, topY)
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
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.LayoutOrder = (r-1) * GRID + c
            btn.ZIndex = 22
            btn.Parent = gridHolder
            pixelFrames[keyOf(r, c)] = { btn = btn, r = r, c = c, paintedColor = nil }
        end
    end

    local function refresh2DGrid()
        for k, p in pairs(pixelFrames) do
            local v = Ed2D.Cells[p.r][p.c]
            if v == 0 then
                p.btn.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
            else
                p.btn.BackgroundColor3 = PALETTE[v] or Color3.fromRGB(255,255,255)
            end
        end
    end
    refresh2DGrid()

    local function paintCell(r, c)
        if r < 1 or r > GRID or c < 1 or c > GRID then return end
        if Ed2D.EraserMode then
            Ed2D.Cells[r][c] = 0
        elseif Ed2D.FillMode then
            floodFill2D(r, c, Ed2D.CurrentColor)
        else
            Ed2D.Cells[r][c] = Ed2D.CurrentColor
        end
    end

    local function applyBrush(r, c)
        local b = Ed2D.Brush
        if b == 1 then
            paintCell(r, c)
        elseif b == 2 then
            for dr = 0, 1 do for dc = 0, 1 do paintCell(r + dr, c + dc) end end
        elseif b == 3 then
            for dr = -1, 1 do for dc = -1, 1 do paintCell(r + dr, c + dc) end end
        end
    end

    -- Тап по клетке
    local lastPaint = nil
    local function bindCell(btn, r, c)
        local function onPress()
            push2DHistory()
            applyBrush(r, c)
            refresh2DGrid()
            lastPaint = {r = r, c = c}
        end
        btn.MouseButton1Down:Connect(onPress)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then onPress() end
        end)
        btn.MouseEnter:Connect(function()
            if lastPaint then
                -- drag-paint по ПК
                local held = game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                if held then
                    applyBrush(r, c); refresh2DGrid()
                    lastPaint = {r = r, c = c}
                end
            end
        end)
    end

    for k, p in pairs(pixelFrames) do bindCell(p.btn, p.r, p.c) end

    local function stopDragPaint()
        lastPaint = nil
    end
    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            stopDragPaint()
        end
    end)

    -- ============================================================
    --       ПРАВАЯ ПАНЕЛЬ (на мобилке — снизу)
    -- ============================================================
    local ctrlX = IS_MOBILE and 16 or (leftX + gridPx + 12)
    local ctrlY = IS_MOBILE and (topY + gridPx + 8) or topY
    local ctrlW = IS_MOBILE and (editorW - 32) or (editorW - leftX - gridPx - 28)
    local ctrlH = IS_MOBILE and (editorH - ctrlY - 60) or (editorH - topY - 60)

    local ctrl = Instance.new("ScrollingFrame")
    ctrl.Size = UDim2.new(0, ctrlW, 0, ctrlH)
    ctrl.Position = UDim2.new(0, ctrlX, 0, ctrlY)
    ctrl.BackgroundColor3 = Color3.fromRGB(18, 14, 30)
    ctrl.BorderSizePixel = 0
    ctrl.CanvasSize = UDim2.new(0, 0, 0, 800)
    ctrl.ScrollBarThickness = 3
    ctrl.ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255)
    ctrl.ZIndex = 21
    ctrl.Parent = editorGui
    Instance.new("UICorner", ctrl).CornerRadius = UDim.new(0, 10)

    local cy = 6
    local function section(txt, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -12, 0, 16)
        l.Position = UDim2.new(0, 6, 0, cy)
        l.BackgroundColor3 = color
        l.BackgroundTransparency = 0.55
        l.BorderSizePixel = 0
        l.Text = " " .. txt
        l.TextColor3 = Color3.fromRGB(240, 240, 255)
        l.Font = Enum.Font.GothamBold
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 22
        l.Parent = ctrl
        Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
        cy = cy + 20
    end
    local function ctrlBtn(text, color, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 26)
        b.Position = UDim2.new(0, 6, 0, cy)
        b.BackgroundColor3 = color or Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(230, 220, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = text
        b.ZIndex = 22
        b.Parent = ctrl
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.Activated:Connect(function() onClick(b) end)
        cy = cy + 30
        return b
    end

    -- Палитра
    section("🎨 ПАЛИТРА", Color3.fromRGB(100, 60, 140))
    local palGrid = Instance.new("Frame")
    palGrid.Size = UDim2.new(1, -12, 0, 80)
    palGrid.Position = UDim2.new(0, 6, 0, cy)
    palGrid.BackgroundTransparency = 1
    palGrid.ZIndex = 22
    palGrid.Parent = ctrl
    local palLayout = Instance.new("UIGridLayout")
    palLayout.CellSize = UDim2.new(0, 22, 0, 22)
    palLayout.CellPadding = UDim2.new(0, 3, 0, 3)
    palLayout.Parent = palGrid

    local palBtns = {}
    local function refreshPal()
        for i, b in ipairs(palBtns) do
            b.UIStroke.Transparency = (i == Ed2D.CurrentColor) and 0 or 0.85
        end
    end
    for i, col in ipairs(PALETTE) do
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = col
        b.Text = ""
        b.BorderSizePixel = 0
        b.ZIndex = 23
        b.Parent = palGrid
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        local s = Instance.new("UIStroke", b)
        s.Color = Color3.fromRGB(255, 255, 255)
        s.Thickness = 2
        s.Transparency = 0.85
        b.UIStroke = s
        b.Activated:Connect(function()
            Ed2D.CurrentColor = i
            Ed2D.EraserMode = false
            Ed2D.FillMode = false
            refreshPal()
        end)
        table.insert(palBtns, b)
    end
    cy = cy + 86
    refreshPal()

    section("🖌 КИСТЬ / ИНСТРУМЕНТ", Color3.fromRGB(100, 80, 40))
    local brushRow = Instance.new("Frame")
    brushRow.Size = UDim2.new(1, -12, 0, 26)
    brushRow.Position = UDim2.new(0, 6, 0, cy)
    brushRow.BackgroundTransparency = 1
    brushRow.ZIndex = 22
    brushRow.Parent = ctrl
    local brushButtons = {}
    for i, size in ipairs({1, 2, 3}) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.2, -2, 1, 0)
        b.Position = UDim2.new((i-1) * 0.2, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(220, 210, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = size .. "×" .. size
        b.ZIndex = 23
        b.Parent = brushRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        brushButtons[size] = b
    end
    local eraserBtn = Instance.new("TextButton")
    eraserBtn.Size = UDim2.new(0.2, -2, 1, 0)
    eraserBtn.Position = UDim2.new(0.6, 0, 0, 0)
    eraserBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    eraserBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
    eraserBtn.Font = Enum.Font.GothamBold
    eraserBtn.TextSize = 10
    eraserBtn.Text = "🧽"
    eraserBtn.ZIndex = 23
    eraserBtn.Parent = brushRow
    Instance.new("UICorner", eraserBtn).CornerRadius = UDim.new(0, 5)
    local fillBtn = Instance.new("TextButton")
    fillBtn.Size = UDim2.new(0.2, -2, 1, 0)
    fillBtn.Position = UDim2.new(0.8, 0, 0, 0)
    fillBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
    fillBtn.TextColor3 = Color3.fromRGB(200, 255, 200)
    fillBtn.Font = Enum.Font.GothamBold
    fillBtn.TextSize = 10
    fillBtn.Text = "🪣"
    fillBtn.ZIndex = 23
    fillBtn.Parent = brushRow
    Instance.new("UICorner", fillBtn).CornerRadius = UDim.new(0, 5)

    local function refreshBrushUI()
        for size, b in pairs(brushButtons) do
            b.BackgroundColor3 = (Ed2D.Brush == size and not Ed2D.EraserMode and not Ed2D.FillMode)
                and Color3.fromRGB(100, 80, 160) or Color3.fromRGB(45, 38, 65)
        end
        eraserBtn.BackgroundColor3 = Ed2D.EraserMode and Color3.fromRGB(140, 60, 60) or Color3.fromRGB(80, 40, 40)
        fillBtn.BackgroundColor3 = Ed2D.FillMode and Color3.fromRGB(80, 130, 80) or Color3.fromRGB(60, 80, 60)
    end
    for size, b in pairs(brushButtons) do
        b.Activated:Connect(function()
            Ed2D.Brush = size
            Ed2D.EraserMode = false
            Ed2D.FillMode = false
            refreshBrushUI()
        end)
    end
    eraserBtn.Activated:Connect(function()
        Ed2D.EraserMode = not Ed2D.EraserMode
        if Ed2D.EraserMode then Ed2D.FillMode = false end
        refreshBrushUI()
    end)
    fillBtn.Activated:Connect(function()
        Ed2D.FillMode = not Ed2D.FillMode
        if Ed2D.FillMode then Ed2D.EraserMode = false end
        refreshBrushUI()
    end)
    refreshBrushUI()
    cy = cy + 32

    section("↩️ ИСТОРИЯ", Color3.fromRGB(60, 90, 60))
    ctrlBtn("↩ Отменить", Color3.fromRGB(50,70,60), function()
        do2DUndo(); refresh2DGrid()
    end)
    ctrlBtn("↪ Вернуть", Color3.fromRGB(50,70,60), function()
        do2DRedo(); refresh2DGrid()
    end)

    section("⚡ БЫСТРЫЕ ФОРМЫ", Color3.fromRGB(140, 80, 40))
    ctrlBtn("🗑 Очистить всё", Color3.fromRGB(80,40,40), function()
        push2DHistory()
        for r = 1, GRID do for c = 1, GRID do Ed2D.Cells[r][c] = 0 end end
        refresh2DGrid()
    end)
    ctrlBtn("↔ Симметрия левая", Color3.fromRGB(60,50,90), function()
        push2DHistory()
        for r = 1, GRID do
            for c = 1, math.floor(GRID/2) do
                Ed2D.Cells[r][GRID - c + 1] = Ed2D.Cells[r][c]
            end
        end
        refresh2DGrid()
    end)
    ctrlBtn("❤ Заполнить сердце", Color3.fromRGB(80,30,55), function()
        push2DHistory()
        local c = PALETTE[1]
        local heart = {
            "01100110", "11111111", "11111111", "11111111",
            "01111110", "00111100", "00011000",
        }
        local offsetR = math.floor((GRID - #heart) / 2)
        local offsetC = math.floor((GRID - #heart[1]) / 2)
        for rr = 1, #heart do
            for cc = 1, #heart[rr] do
                if heart[rr]:sub(cc, cc) == "1" then
                    Ed2D.Cells[offsetR + rr][offsetC + cc] = 1
                end
            end
        end
        refresh2DGrid()
    end)

    section("💾 СОХРАНЕНИЕ", Color3.fromRGB(100, 60, 140))
    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, -12, 0, 28)
    nameInput.Position = UDim2.new(0, 6, 0, cy)
    nameInput.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    nameInput.TextColor3 = Color3.fromRGB(230, 220, 255)
    nameInput.Font = Enum.Font.GothamBold
    nameInput.TextSize = 11
    nameInput.PlaceholderText = "✏️ Имя фигуры..."
    nameInput.PlaceholderColor3 = Color3.fromRGB(150, 140, 180)
    nameInput.Text = ""
    nameInput.ClearTextOnFocus = false
    nameInput.ZIndex = 22
    nameInput.Parent = ctrl
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 6)
    cy = cy + 34

    ctrlBtn("💾 СОХРАНИТЬ", Color3.fromRGB(60,120,80), function()
        -- Сбор данных: [r][c] = индекс цвета (0 = пусто)
        local data = {}
        local filled = 0
        for r = 1, GRID do
            data[r] = {}
            for c = 1, GRID do
                data[r][c] = Ed2D.Cells[r][c]
                if Ed2D.Cells[r][c] > 0 then filled = filled + 1 end
            end
        end
        if filled < 3 then
            ORBIT.notify("🎨 Закрась хотя бы 3 клетки", Color3.fromRGB(255,200,120), 2)
            return
        end
        local nm = nameInput.Text
        if nm == "" or not utf8.len(nm) or utf8.len(nm) > 20 then
            nm = "СВОЯ_" .. (#SHAPE_PRESETS + 1)
        end
        -- Уникальность
        local base, n = nm, 1
        local function exists(x)
            for _, sp in ipairs(SHAPE_PRESETS) do if sp.name == x then return true end end
            return false
        end
        while exists(nm) do n = n + 1; nm = base .. "_" .. n end

        local shape = { name = nm, pixels = data }
        registerCustomShape(shape)
        ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
        table.insert(ORBIT.CUSTOM_SHAPES, shape)
        saveStorage()
        ORBIT.notify("🎨 Сохранено: " .. nm, Color3.fromRGB(180,255,220), 3)

        -- Применяем к первому кольцу
        for i, sp in ipairs(SHAPE_PRESETS) do
            if sp.name == nm then
                ORBIT.shapeIndex = i
                rings[1].shapeIndex = i
                ORBIT.destroyRing(1); ORBIT.buildRing(1); ORBIT.applyColor()
                break
            end
        end
    end)

    ctrlBtn("💰 ПРОДАТЬ +50", Color3.fromRGB(90,70,30), function()
        local filled = 0
        for r = 1, GRID do
            for c = 1, GRID do
                if Ed2D.Cells[r][c] > 0 then filled = filled + 1 end
            end
        end
        if filled < 8 then
            ORBIT.notify("🎨 Минимум 8 клеток для продажи", Color3.fromRGB(255,200,120), 2)
            return
        end
        ORBIT.COINS = (ORBIT.COINS or 0) + 50
        ORBIT.SESSION = ORBIT.SESSION or {}
        ORBIT.SESSION.coinsEarned = (ORBIT.SESSION.coinsEarned or 0) + 50
        saveStorage()
        ORBIT.notify("💰 +50 монет (всего: " .. ORBIT.COINS .. ")", Color3.fromRGB(255,220,120), 3)
        if ORBIT.playBuy then pcall(ORBIT.playBuy) end
    end)

    ctrl.CanvasSize = UDim2.new(0, 0, 0, cy + 20)

    closeBtn.Activated:Connect(function()
        editorOpen = false
        if editorGui then editorGui:Destroy(); editorGui = nil end
    end)
end

-- ============================================================
--       ПРИВЯЗКА КНОПОК
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
ORBIT.PALETTE = PALETTE
ORBIT.saveStorage = saveStorage

if ORBIT.notify then
    ORBIT.notify("🎨 2D + 🔮 3D редакторы готовы", Color3.fromRGB(220,200,255), 3)
end

return true
