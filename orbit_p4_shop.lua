-- ORBIT v24.3 | orbit_p4_shop.lua
-- Магазин + 2D-редактор + 3D-кнопка.
-- v24.3: кнопки «Скопировать фигуру» и «Вставить из буфера» (share-обмен).
local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (type(getgenv) == "function" and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Shop] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit Shop] UI не готов!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local TweenService = ORBIT.TweenService
local HttpService  = ORBIT.HttpService
local LocalPlayer  = ORBIT.LocalPlayer
local UIS          = game:GetService("UserInputService")

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
ORBIT.OWNED_FILE = "orbit_v21_owned.json"
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
    ["ДРАКОН"] = 500, ["ЦВЕТОК ФЛАУИ"] = 550, ["ОМЕГА ФЛАУИ"] = 700,
    ["КОРОНА"] = 600, ["ФЕНИКС"] = 800, ["ПОРТАЛ"] = 650, ["СКАЛА"] = 400,
}

local function saveStorage()
    if not ORBIT.HAS_FS then return end
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(ORBIT.CUSTOM_FILE, HttpService:JSONEncode(ORBIT.CUSTOM_SHAPES))
        writefile(ORBIT.COINS_FILE, tostring(ORBIT.COINS or 0))
        local owned = {}
        for k, v in pairs(ORBIT.OWNED_SHAPES) do if v then table.insert(owned, k) end end
        writefile(ORBIT.OWNED_FILE, HttpService:JSONEncode(owned))
    end)
end

local function loadStorage()
    if not ORBIT.HAS_FS then return end
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
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
        if isfile(ORBIT.OWNED_FILE) then
            local txt = readfile(ORBIT.OWNED_FILE)
            if txt and #txt > 0 then
                local data = HttpService:JSONDecode(txt)
                for _, name in ipairs(data or {}) do ORBIT.OWNED_SHAPES[name] = true end
            end
        end
    end)
end

-- ============================================================
--       ПАЛИТРА
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
local COLOR_NAMES = {
    "Красный", "Оранжевый", "Жёлтый", "Зелёный", "Изумруд", "Голубой",
    "Синий", "Фиолетовый", "Маджента", "Розовый",
    "Пастель-розовый", "Пастель-крем", "Пастель-голубой", "Пастель-мята",
    "Пастель-сиреневый", "Пастель-лаванда",
    "Белый", "Серый", "Тёмно-серый", "Тёмный", "Почти-чёрный",
    "Золотой", "Свето-золотой", "Бронзовый",
}

-- ============================================================
--       onClick
-- ============================================================
local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    -- флаг «нажатие уже обработано» (защита от двойного срабатывания Down + Activated)
    local down, downT, lastRelT = false, 0, 0
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        if ORBIT.playClick then pcall(ORBIT.playClick) end
        local ok, err = pcall(fn)
        if not ok then warn("[Orbit] " .. tostring(err)) end
    end
    local function inScroll()
        return releaseOnly or btn:GetAttribute("ReleaseOnly")
            or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil
    end
    -- нажатие: вне скролла срабатываем сразу, в скролле ждём отпускания
    local function press()
        if down and tick() - downT < 1 then return end
        down, downT = true, tick()
        if not inScroll() then call() end
    end
    -- отпускание: если нажатие было — завершаем его, иначе (клавиатура/геймпад) вызываем с защитой 0.2 с
    local function release()
        local now = tick()
        if down then
            down = false; lastRelT = now
            if inScroll() then call() end
        elseif now - lastRelT > 0.2 then
            lastRelT = now; call()
        end
    end
    btn.MouseButton1Down:Connect(press)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchStart = input.Position
            press()
        end
    end)
    btn.MouseButton1Click:Connect(release)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and touchStart then
            local moved = (input.Position - touchStart).Magnitude
            touchStart = nil
            if moved < 12 then release() else down = false; lastRelT = tick() end
        end
    end)
    btn.Activated:Connect(release)
end

-- ============================================================
--       РЕГИСТРАЦИЯ КАСТОМНЫХ ФИГУР
-- ============================================================
local function registerCustomShape(shape)
    local name = shape.name or ("СВОЯ_" .. (#ORBIT.CUSTOM_SHAPES))
    for _, sp in ipairs(SHAPE_PRESETS) do
        if sp.name == name then return end
    end

    -- 3D
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

    -- 2D
    if not shape.pixels then return end
    local rows = #shape.pixels
    local cols = #shape.pixels[1]
    local pixelData = {}
    for r = 1, rows do
        pixelData[r] = {}
        local row = shape.pixels[r]
        if type(row) == "string" then
            for c = 1, #row do
                if row:sub(c, c) == "1" then
                    pixelData[r][c] = Color3.fromRGB(255, 255, 255)
                end
            end
        elseif type(row) == "table" then
            for c = 1, #row do
                local v = row[c]
                if v and v > 0 then
                    pixelData[r][c] = PALETTE[v] or Color3.fromRGB(255, 255, 255)
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

-- ✨ v24.3: удаление кастомной фигуры
function ORBIT.deleteCustomShape(shapeName)
    if not shapeName then return false end
    local found = false
    for i = #SHAPE_PRESETS, 1, -1 do
        local sp = SHAPE_PRESETS[i]
        if sp.name == shapeName and sp.isCustom then
            table.remove(SHAPE_PRESETS, i)
            found = true
        end
    end
    for i = #ORBIT.CUSTOM_SHAPES, 1, -1 do
        if ORBIT.CUSTOM_SHAPES[i].name == shapeName then
            table.remove(ORBIT.CUSTOM_SHAPES, i)
        end
    end
    ORBIT.OWNED_SHAPES[shapeName] = nil
    if found then saveStorage() end
    return found
end

-- ✨ v24.3: экспорт кастомной фигуры в строку ОРБИТЫ (для кнопки «Скопировать»)
function ORBIT.encodeCustomShapeByName(shapeName)
    if not shapeName then return nil, "Нет имени" end
    if not ORBIT.share or not ORBIT.share.encodeShape then
        return nil, "Модуль SHARE не загружен"
    end
    -- ищем фигуру в SHAPE_PRESETS
    for _, sp in ipairs(SHAPE_PRESETS) do
        if sp.name == shapeName and sp.isCustom then
            -- ищем исходные данные в CUSTOM_SHAPES
            for _, raw in ipairs(ORBIT.CUSTOM_SHAPES) do
                if raw.name == shapeName then
                    return ORBIT.share.encodeShape(raw)
                end
            end
            return nil, "Нет данных фигуры"
        end
    end
    return nil, "Не кастомная фигура"
end

-- ============================================================
--       ПРЕВЬЮ АВАТАРА
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
            p.Anchored = true; p.CanCollide = false
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
    if not shape then return folder, {} end
    local size = 1.2 * (sizeMult or 1.0)
    local count = blockCount or 8
    local blocks = {}
    for i = 1, count do
        local ok, data = pcall(shape.create, size, "D_" .. i)
        if ok and data then
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
    { name = "СУЩЕСТВА", shapes = {"ЧЕРЕП","РУКА","РУКА-СЕРДЦЕ","ГОЛОВА","СЕРДЦЕ","КРЫЛЬЯ","ЩУПАЛЬЦЕ","СКАЛА","ДРАКОН","ЦВЕТОК ФЛАУИ","ОМЕГА ФЛАУИ"} },
    { name = "НОВЫЕ",    shapes = {"КОРОНА","ФЕНИКС","ПОРТАЛ"} },
    { name = "МОИ ФИГУРЫ", custom = true },
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

    local shopW = IS_MOBILE and 340 or 620
    local shopH = IS_MOBILE and 560 or 520

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

    if ORBIT.ui.fitToScreen then ORBIT.ui.fitToScreen(shopGui, shopW, shopH) end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -240, 0, 28)
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
    coinsLbl.Size = UDim2.new(0, 100, 0, 26)
    coinsLbl.Position = UDim2.new(1, -140, 0, 10)
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

    -- ✨ v24.3: кнопка «Вставить фигуру из буфера»
    local pasteShapeBtn = Instance.new("TextButton")
    pasteShapeBtn.Size = UDim2.new(0, 150, 0, 24)
    pasteShapeBtn.Position = UDim2.new(1, -330, 0, 10)
    pasteShapeBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 110)
    pasteShapeBtn.TextColor3 = Color3.fromRGB(200, 230, 255)
    pasteShapeBtn.Font = Enum.Font.GothamBold
    pasteShapeBtn.TextSize = 10
    pasteShapeBtn.Text = "📥 Вставить из буфера"
    pasteShapeBtn.ZIndex = 11
    pasteShapeBtn.Parent = shopGui
    Instance.new("UICorner", pasteShapeBtn).CornerRadius = UDim.new(0, 8)
    onClick(pasteShapeBtn, function()
        if not ORBIT.share or not ORBIT.share.paste then
            ORBIT.notify("❌ Модуль SHARE не загружен", Color3.fromRGB(255,150,150), 3)
            return
        end
        local txt, err = ORBIT.share.paste()
        if not txt or #txt < 10 then
            ORBIT.notify("📋 Буфер пустой или " .. tostring(err), Color3.fromRGB(255,200,120), 3)
            return
        end
        local decoded, derr = ORBIT.share.decode(txt)
        if not decoded then
            ORBIT.notify("❌ " .. tostring(derr), Color3.fromRGB(255,150,150), 3)
            return
        end
        if decoded.kind ~= "SH" then
            ORBIT.notify("❌ В буфере не фигура (это " .. tostring(decoded.kind) .. ")", Color3.fromRGB(255,150,150), 3)
            return
        end
        if ORBIT.share.applyDecoded then
            local ok = ORBIT.share.applyDecoded(decoded)
            if ok then
                ORBIT.notify("✅ Фигура добавлена в «МОИ ФИГУРЫ»", Color3.fromRGB(180,255,180), 3)
                shopState.categoryIndex = #SHOP_CATEGORIES
                updateCat(); refreshShopShapeList(); refreshShapeLbl(); refreshDemo()
            end
        end
    end)

    local open3DBtn = Instance.new("TextButton")
    open3DBtn.Size = UDim2.new(0, 120, 0, 24)
    open3DBtn.Position = UDim2.new(1, -180, 0, 10)
    open3DBtn.BackgroundColor3 = Color3.fromRGB(80, 45, 130)
    open3DBtn.TextColor3 = Color3.fromRGB(230, 200, 255)
    open3DBtn.Font = Enum.Font.GothamBold
    open3DBtn.TextSize = 10
    open3DBtn.Text = "🔮 3D-РЕДАКТОР"
    open3DBtn.ZIndex = 11
    open3DBtn.Parent = shopGui
    Instance.new("UICorner", open3DBtn).CornerRadius = UDim.new(0, 8)
    local headerExtraY = 0
    if IS_MOBILE then
        open3DBtn.Position = UDim2.new(0, 16, 0, 40)
        pasteShapeBtn.Position = UDim2.new(0, 16, 0, 68)
        headerExtraY = 60
    end
    onClick(open3DBtn, function()
        if ORBIT.openEditor3D then
            ORBIT.openEditor3D()
        else
            ORBIT.notify("❌ 3D-Редактор не загружен", Color3.fromRGB(255,120,120), 2)
        end
    end)

    local previewW = IS_MOBILE and (shopW - 32) or 240
    local previewH = IS_MOBILE and 220 or 300
    local previewFrame = Instance.new("Frame")
    previewFrame.Size = UDim2.new(0, previewW, 0, previewH)
    previewFrame.Position = UDim2.new(0, 16, 0, 44 + headerExtraY)
    previewFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    previewFrame.BorderSizePixel = 0
    previewFrame.ZIndex = 11
    previewFrame.Parent = shopGui
    Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 10)

    local vp, world, cam, avatar = createAvatarPreview(previewFrame, UDim2.new(1, 0, 1, 0))
    vp.ZIndex = 12

    local rightX = IS_MOBILE and 16 or 272
    local rightY = IS_MOBILE and (44 + headerExtraY + previewH + 8) or 44
    local rightW = IS_MOBILE and (shopW - 32) or 332
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

    local refreshShapeLbl

    local catL, catV, catR = shopRow("📁 КАТЕГОРИЯ")
    local shopShapeIdx = 1
    local function refreshShopShapeList()
        local list = getShopShapes()
        if #list == 0 then shopShapeIdx = 1; return end
        shopShapeIdx = math.clamp(shopShapeIdx, 1, #list)
        shopState.shapeIndex = list[shopShapeIdx]
    end
    local function updateCat() catV.Text = SHOP_CATEGORIES[shopState.categoryIndex].name end
    onClick(catL, function()
        shopState.categoryIndex = shopState.categoryIndex - 1
        if shopState.categoryIndex < 1 then shopState.categoryIndex = #SHOP_CATEGORIES end
        shopShapeIdx = 1
        updateCat(); refreshShopShapeList(); refreshShapeLbl(); refreshDemo()
    end)
    onClick(catR, function()
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

    -- ✨ Кнопка «Скопировать» (только для кастомных)
    local copyShapeBtn = Instance.new("TextButton")
    copyShapeBtn.Size = UDim2.new(1, -12, 0, 28)
    copyShapeBtn.Position = UDim2.new(0, 6, 0, ry)
    copyShapeBtn.BackgroundColor3 = Color3.fromRGB(70, 60, 130)
    copyShapeBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
    copyShapeBtn.Font = Enum.Font.GothamBold
    copyShapeBtn.TextSize = 11
    copyShapeBtn.Text = "📋 СКОПИРОВАТЬ (строка другу)"
    copyShapeBtn.Visible = false
    copyShapeBtn.ZIndex = 12
    copyShapeBtn.Parent = rightPanel
    Instance.new("UICorner", copyShapeBtn).CornerRadius = UDim.new(0, 6)
    ry = ry + 32

    -- ✨ Кнопка «Удалить» (только для кастомных)
    local delShapeBtn = Instance.new("TextButton")
    delShapeBtn.Size = UDim2.new(1, -12, 0, 28)
    delShapeBtn.Position = UDim2.new(0, 6, 0, ry)
    delShapeBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 45)
    delShapeBtn.TextColor3 = Color3.fromRGB(255, 170, 170)
    delShapeBtn.Font = Enum.Font.GothamBold
    delShapeBtn.TextSize = 11
    delShapeBtn.Text = "🗑 УДАЛИТЬ СВОЮ ФИГУРУ"
    delShapeBtn.Visible = false
    delShapeBtn.ZIndex = 12
    delShapeBtn.Parent = rightPanel
    Instance.new("UICorner", delShapeBtn).CornerRadius = UDim.new(0, 6)
    ry = ry + 32

    refreshShapeLbl = function()
        refreshShopShapeList()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp then
            sV.Text = "—"
            buyShapeBtn.Visible = false
            copyShapeBtn.Visible = false
            delShapeBtn.Visible = false
            return
        end
        sV.Text = sp.name
        buyShapeBtn.Visible = true
        local owned = ORBIT.OWNED_SHAPES[sp.name]
        local price = SHAPE_PRICES[sp.name] or 0
        if sp.isCustom then
            buyShapeBtn.Text = "✨ ВАША ФИГУРА"
            buyShapeBtn.BackgroundColor3 = Color3.fromRGB(50,60,80)
            buyShapeBtn.TextColor3 = Color3.fromRGB(180,220,255)
            copyShapeBtn.Visible = true
            delShapeBtn.Visible = true
        else
            copyShapeBtn.Visible = false
            delShapeBtn.Visible = false
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
    end

    onClick(sL, function()
        local list = getShopShapes()
        if #list == 0 then return end
        shopShapeIdx = shopShapeIdx - 1
        if shopShapeIdx < 1 then shopShapeIdx = #list end
        shopState.shapeIndex = list[shopShapeIdx]
        refreshShapeLbl(); refreshDemo()
    end)
    onClick(sR, function()
        local list = getShopShapes()
        if #list == 0 then return end
        shopShapeIdx = shopShapeIdx + 1
        if shopShapeIdx > #list then shopShapeIdx = 1 end
        shopState.shapeIndex = list[shopShapeIdx]
        refreshShapeLbl(); refreshDemo()
    end)

    onClick(buyShapeBtn, function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp or sp.isCustom then return end
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

    -- ✨ v24.3: СКОПИРОВАТЬ фигуру
    onClick(copyShapeBtn, function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp or not sp.isCustom then return end
        if not ORBIT.share then
            ORBIT.notify("❌ Модуль SHARE не загружен", Color3.fromRGB(255,150,150), 3)
            return
        end
        local str, err = ORBIT.encodeCustomShapeByName(sp.name)
        if not str then
            ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255,150,150), 3)
            return
        end
        local copied = ORBIT.share.copy(str)
        if copied then
            ORBIT.notify("📋 Скопировано в буфер (" .. #str .. " символов)", Color3.fromRGB(180,255,180), 3)
        else
            ORBIT.notify("📤 Строка готова — выдели и скопируй вручную", Color3.fromRGB(255,220,140), 4)
        end
    end)

    -- ✨ Удаление своей фигуры
    onClick(delShapeBtn, function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp or not sp.isCustom then return end
        local ok = ORBIT.deleteCustomShape(sp.name)
        if ok then
            ORBIT.notify("🗑 Удалена: " .. sp.name, Color3.fromRGB(255,150,150), 3)
            shopShapeIdx = 1
            refreshShapeLbl()
            refreshDemo()
        else
            ORBIT.notify("❌ Не удалось удалить", Color3.fromRGB(255,100,100), 2)
        end
    end)

    local cL, cV, cR = shopRow("🎨 ЦВЕТ КОЛЬЦА")
    local function updateColor() cV.Text = P.COLORS[shopState.colorIndex].name end
    onClick(cL, function()
        shopState.colorIndex = shopState.colorIndex - 1
        if shopState.colorIndex < 1 then shopState.colorIndex = #P.COLORS end
        updateColor(); refreshDemo()
    end)
    onClick(cR, function()
        shopState.colorIndex = shopState.colorIndex + 1
        if shopState.colorIndex > #P.COLORS then shopState.colorIndex = 1 end
        updateColor(); refreshDemo()
    end)

    local zL, zV, zR = shopRow("🔍 РАЗМЕР ФИГУРЫ")
    local function updateSize() zV.Text = P.SHAPE_SIZE[shopState.sizeIndex].name end
    onClick(zL, function()
        shopState.sizeIndex = shopState.sizeIndex - 1
        if shopState.sizeIndex < 1 then shopState.sizeIndex = #P.SHAPE_SIZE end
        updateSize(); refreshDemo()
    end)
    onClick(zR, function()
        shopState.sizeIndex = shopState.sizeIndex + 1
        if shopState.sizeIndex > #P.SHAPE_SIZE then shopState.sizeIndex = 1 end
        updateSize(); refreshDemo()
    end)

    local spL, spV, spR = shopRow("⚡ СКОРОСТЬ")
    local function updateSpeed() spV.Text = P.SPEED[shopState.speedIndex].name end
    onClick(spL, function()
        shopState.speedIndex = shopState.speedIndex - 1
        if shopState.speedIndex < 1 then shopState.speedIndex = #P.SPEED end
        updateSpeed()
    end)
    onClick(spR, function()
        shopState.speedIndex = shopState.speedIndex + 1
        if shopState.speedIndex > #P.SPEED then shopState.speedIndex = 1 end
        updateSpeed()
    end)

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
        onClick(b, function()
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

    local animConn
    animConn = RunService.Heartbeat:Connect(function(dt)
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

    onClick(closeBtn, closeShop)
    onClick(cancelBtn, closeShop)

    onClick(applyBtn, function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if sp and not sp.isCustom and not ORBIT.OWNED_SHAPES[sp.name] then
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
--       2D-РЕДАКТОР
-- ============================================================
local editorOpen = false
local editorGui
local editorConns = {}
local P2 = "Orbit2D_"

local GRID_OPTIONS = {16, 20, 24}
local GRID = 16

local Ed2D = {
    Cells = {}, Tool = "paint", Brush = 1, Color = 1,
    States = {}, StateIdx = 0, MaxHistory = 20,
}

local function resizeGrid(newN)
    local oldCells = Ed2D.Cells
    local oldN = #oldCells
    Ed2D.Cells = {}
    for r = 1, newN do
        Ed2D.Cells[r] = {}
        for c = 1, newN do Ed2D.Cells[r][c] = 0 end
    end
    for r = 1, math.min(oldN, newN) do
        for c = 1, math.min(oldN, newN) do
            if oldCells[r] and oldCells[r][c] then
                Ed2D.Cells[r][c] = oldCells[r][c]
            end
        end
    end
    GRID = newN
end

local function snapshot2D()
    local s = {}
    for r = 1, GRID do s[r] = {}; for c = 1, GRID do s[r][c] = Ed2D.Cells[r][c] end end
    return s
end
local function restore2D(s)
    for r = 1, GRID do
        for c = 1, GRID do Ed2D.Cells[r][c] = (s[r] and s[r][c]) or 0 end
    end
end
local function resetHistory2D()
    Ed2D.States = {snapshot2D()}
    Ed2D.StateIdx = 1
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
end
local function commit2D()
    while #Ed2D.States > Ed2D.StateIdx do table.remove(Ed2D.States) end
    table.insert(Ed2D.States, snapshot2D())
    Ed2D.StateIdx = #Ed2D.States
    while #Ed2D.States > Ed2D.MaxHistory + 1 do
        table.remove(Ed2D.States, 1); Ed2D.StateIdx = Ed2D.StateIdx - 1
    end
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
end
local function do2DUndo()
    if Ed2D.StateIdx <= 1 then return false end
    Ed2D.StateIdx = Ed2D.StateIdx - 1
    restore2D(Ed2D.States[Ed2D.StateIdx])
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
    return true
end
local function do2DRedo()
    if Ed2D.StateIdx >= #Ed2D.States then return false end
    Ed2D.StateIdx = Ed2D.StateIdx + 1
    restore2D(Ed2D.States[Ed2D.StateIdx])
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
    return true
end

resizeGrid(GRID)
resetHistory2D()

local function floodFill2D(r0, c0, newColor)
    local old = Ed2D.Cells[r0][c0]
    if old == newColor then return false end
    local stack = {{r0, c0}}
    local seen = {}
    while #stack > 0 do
        local p = table.remove(stack)
        local r, c = p[1], p[2]
        if r >= 1 and r <= GRID and c >= 1 and c <= GRID then
            local k = r * 100 + c
            if not seen[k] and Ed2D.Cells[r][c] == old then
                seen[k] = true
                Ed2D.Cells[r][c] = newColor
                table.insert(stack, {r + 1, c}); table.insert(stack, {r - 1, c})
                table.insert(stack, {r, c + 1}); table.insert(stack, {r, c - 1})
            end
        end
    end
    return true
end

local HEART_PATTERN = {
    "01100110", "11111111", "11111111", "11111111",
    "01111110", "00111100", "00011000",
}
local SMILE_PATTERN = {
    "00111100", "01111110", "11211211", "11111111",
    "12111121", "11222211", "01111110", "00111100",
}

local function openEditor()
    if editorOpen and editorGui and editorGui.Parent then return end
    editorOpen = true
    Ed2D.Open = true
    editorConns = {}

    local editorW = IS_MOBILE and 360 or 700
    local editorH = IS_MOBILE and 620 or 470

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do
            if k ~= "Name" then o[k] = v end
        end
        o.Name = P2 .. ((props and props.Name) or class)
        if parent then
            if o:IsA("GuiObject") and not (props and props.ZIndex) and parent:IsA("GuiObject") then
                o.ZIndex = parent.ZIndex + 1
            end
            o.Parent = parent
        end
        return o
    end
    local function corner(o, r) return mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end

    editorGui = mk("Frame", {
        Name = "Window", Size = UDim2.new(0, editorW, 0, editorH),
        Position = UDim2.new(0.5, -editorW / 2, 0.5, -editorH / 2),
        BackgroundColor3 = Color3.fromRGB(22, 16, 35), BackgroundTransparency = 0.05,
        BorderSizePixel = 0, ZIndex = 20, Active = true,
    }, nil)
    editorGui.Name = "_OrbitEditor2D"
    editorGui.Parent = screenGui
    corner(editorGui, 16)
    mk("UIStroke", {Color = Color3.fromRGB(180, 130, 255), Thickness = 2}, editorGui)
    if ORBIT.ui.fitToScreen then pcall(ORBIT.ui.fitToScreen, editorGui, editorW, editorH) end

    local function closeEditor()
        editorOpen = false
        Ed2D.Open = false
        Ed2D.SetGridSize = nil
        for _, cn in ipairs(editorConns) do pcall(function() cn:Disconnect() end) end
        editorConns = {}
        Ed2D.OnHistory = nil
        if editorGui then pcall(function() editorGui:Destroy() end) end
        editorGui = nil
    end

    mk("TextLabel", {
        Name = "Title", Size = UDim2.new(1, -200, 0, 26), Position = UDim2.new(0, 16, 0, 8),
        BackgroundTransparency = 1, Text = "🎨 2D-РЕДАКТОР", TextColor3 = Color3.fromRGB(230, 200, 255),
        Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
    }, editorGui)

    local to3DBtn = mk("TextButton", {
        Name = "To3D", Size = UDim2.new(0, 130, 0, 30), Position = UDim2.new(1, -180, 0, 6),
        BackgroundColor3 = Color3.fromRGB(80, 45, 130), TextColor3 = Color3.fromRGB(230, 200, 255),
        Font = Enum.Font.GothamBold, TextSize = 11, Text = "🔮 3D-РЕДАКТОР",
        AutoButtonColor = false, BorderSizePixel = 0,
    }, editorGui)
    corner(to3DBtn, 8)
    onClick(to3DBtn, function()
        if ORBIT.openEditor3D then ORBIT.openEditor3D()
        else ORBIT.notify("❌ 3D-Редактор не загружен", Color3.fromRGB(255,120,120), 2) end
    end)

    local closeBtn = mk("TextButton", {
        Name = "Close", Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -40, 0, 6),
        BackgroundColor3 = Color3.fromRGB(80, 30, 30), TextColor3 = Color3.fromRGB(255, 160, 160),
        Font = Enum.Font.GothamBold, TextSize = 16, Text = "✖", AutoButtonColor = false,
        BorderSizePixel = 0,
    }, editorGui)
    corner(closeBtn, 8)
    onClick(closeBtn, closeEditor)

    local leftX, topY = 16, 42
    local gridPx = IS_MOBILE and 328 or 400
    local pitch = 1

    local gridHolder = mk("Frame", {
        Name = "GridHolder", Size = UDim2.new(0, gridPx, 0, gridPx), Position = UDim2.new(0, leftX, 0, topY),
        BackgroundColor3 = Color3.fromRGB(14, 10, 24), BorderSizePixel = 0,
    }, editorGui)
    corner(gridHolder, 6)
    mk("UIStroke", {Color = Color3.fromRGB(120, 90, 180), Thickness = 2, Transparency = 0.3}, gridHolder)

    local cellLayer = mk("Frame", {
        Name = "CellLayer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    }, gridHolder)

    local cellFrames = {}
    local EMPTY_COLOR = Color3.fromRGB(30, 24, 46)

    local function refreshCell(r, c)
        local f = cellFrames[r] and cellFrames[r][c]
        if not f then return end
        local v = Ed2D.Cells[r][c]
        f.BackgroundColor3 = (v == 0) and EMPTY_COLOR or (PALETTE[v] or Color3.fromRGB(255, 255, 255))
    end
    local function refreshAllCells()
        for r = 1, GRID do for c = 1, GRID do refreshCell(r, c) end end
    end

    local function rebuildGridUI()
        cellLayer:ClearAllChildren()
        cellFrames = {}
        pitch = math.floor((gridPx - 2) / GRID)
        local used = pitch * GRID + 2
        gridHolder.Size = UDim2.new(0, used, 0, used)

        for r = 1, GRID do
            cellFrames[r] = {}
            for c = 1, GRID do
                local f = mk("Frame", {
                    Name = "Cell", BackgroundColor3 = EMPTY_COLOR, BorderSizePixel = 0,
                    Size = UDim2.new(0, pitch - 2, 0, pitch - 2),
                    Position = UDim2.new(0, (c - 1) * pitch + 2, 0, (r - 1) * pitch + 2),
                }, cellLayer)
                local st = mk("UIStroke", {
                    Color = Color3.fromRGB(60, 50, 85), Thickness = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }, f)
                if c % 4 == 1 or r % 4 == 1 then
                    st.Color = Color3.fromRGB(90, 70, 140); st.Thickness = 1.5
                end
                cellFrames[r][c] = f
            end
        end
        refreshAllCells()
    end

    local countLbl
    local function countFilled()
        local n = 0
        for r = 1, GRID do for c = 1, GRID do if Ed2D.Cells[r][c] > 0 then n = n + 1 end end end
        return n
    end
    local function refreshCount()
        if countLbl then countLbl.Text = "🧱 клеток: " .. countFilled() end
    end

    local function paintCell(r, c, val)
        if r < 1 or r > GRID or c < 1 or c > GRID then return false end
        if Ed2D.Cells[r][c] == val then return false end
        Ed2D.Cells[r][c] = val
        refreshCell(r, c)
        return true
    end

    local function stampBrush(r, c, color)
        local n = Ed2D.Brush or 1
        local lo = -math.floor((n - 1) / 2)
        local hi = lo + n - 1
        local changed = false
        for dr = lo, hi do
            for dc = lo, hi do
                if paintCell(r + dr, c + dc, color) then changed = true end
            end
        end
        return changed
    end

    local function applyTool(r, c, isStart)
        local tool = Ed2D.Tool
        local changed = false
        if tool == "fill" then
            if isStart and floodFill2D(r, c, Ed2D.Color) then
                changed = true; refreshAllCells()
            end
        elseif tool == "pick" then
            if isStart then
                local row = Ed2D.Cells[r]
                local idx = row and row[c] or 0
                if idx > 0 then
                    Ed2D.Color = idx
                    if Ed2D.refreshPal then Ed2D.refreshPal() end
                    Ed2D.Tool = "paint"
                    if Ed2D.paintTools then Ed2D.paintTools() end
                end
            end
        elseif tool == "eraser" then
            changed = stampBrush(r, c, 0)
        else
            changed = stampBrush(r, c, Ed2D.Color)
        end
        return changed
    end

    local overlay = mk("TextButton", {
        Name = "Overlay", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = gridHolder.ZIndex + 5,
    }, gridHolder)

    local painting, activeInput, lastR, lastC, strokeChanged = false, nil, 0, 0, false

    local function cellFromPos(pos)
        local ab = gridHolder.AbsolutePosition
        local lx, ly = pos.X - ab.X - 2, pos.Y - ab.Y - 2
        if lx < 0 or ly < 0 then return nil end
        local c = math.floor(lx / pitch) + 1
        local r = math.floor(ly / pitch) + 1
        if r < 1 or r > GRID or c < 1 or c > GRID then return nil end
        return r, c
    end

    local function endStroke()
        if not painting then return end
        painting, activeInput = false, nil
        if strokeChanged then commit2D(); refreshCount() end
        strokeChanged = false
    end

    overlay.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        if painting then return end
        local r, c = cellFromPos(input.Position)
        if not r then return end
        painting, activeInput = true, input
        strokeChanged = false
        lastR, lastC = r, c
        if applyTool(r, c, true) then strokeChanged = true end
    end)
    overlay.InputChanged:Connect(function(input)
        if not painting then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == activeInput) then
            local r, c = cellFromPos(input.Position)
            if r and (r ~= lastR or c ~= lastC) then
                lastR, lastC = r, c
                if applyTool(r, c, false) then strokeChanged = true end
            end
        end
    end)
    overlay.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == activeInput) then
            endStroke()
        end
    end)
    table.insert(editorConns, UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == activeInput) then
            endStroke()
        end
    end))

    local ctrlX = IS_MOBILE and 16 or (leftX + gridPx + 12)
    local ctrlY = IS_MOBILE and (topY + gridPx + 8) or topY
    local ctrlW = IS_MOBILE and (editorW - 32) or (editorW - ctrlX - 16)
    local ctrlH = IS_MOBILE and (editorH - ctrlY - 8) or (editorH - topY - 10)

    local ctrl = mk("ScrollingFrame", {
        Name = "Ctrl", Size = UDim2.new(0, ctrlW, 0, ctrlH), Position = UDim2.new(0, ctrlX, 0, ctrlY),
        BackgroundColor3 = Color3.fromRGB(18, 14, 30), BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255),
    }, editorGui)
    corner(ctrl, 10)
    local list = mk("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, ctrl)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10),
    }, ctrl)
    local function fitCanvas()
        ctrl.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 18)
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)

    local secOrder = 0
    local BTN_SCALE = 1.12
    local function sc(v) return math.floor(v * BTN_SCALE + 0.5) end

    local function section(txt, color, bodyH)
        secOrder = secOrder + 1
        bodyH = sc(bodyH)
        local f = mk("Frame", {
            Name = "Sec", Size = UDim2.new(1, 0, 0, 28 + bodyH), BackgroundTransparency = 1,
            LayoutOrder = secOrder,
        }, ctrl)
        local l = mk("TextLabel", {
            Name = "SecTitle", Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.25),
            BackgroundTransparency = 0.05, BorderSizePixel = 0, Text = "  " .. txt,
            TextColor3 = Color3.fromRGB(255, 250, 255), Font = Enum.Font.GothamBold, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        corner(l, 5)
        return mk("Frame", {
            Name = "Body", Size = UDim2.new(1, 0, 0, bodyH), Position = UDim2.new(0, 0, 0, 28),
            BackgroundTransparency = 1,
        }, f), l
    end

    local BTN = Color3.fromRGB(45, 38, 65)
    local BTN_OFF = Color3.fromRGB(34, 30, 46)

    local function markActive(b, on)
        if not b then return end
        local base = b:GetAttribute("BaseText")
        if not base then base = b.Text; b:SetAttribute("BaseText", base) end
        local st = b:FindFirstChild("ActiveStroke")
        if not st then
            st = Instance.new("UIStroke"); st.Name = "ActiveStroke"; st.Thickness = 2.5
            st.Color = Color3.fromRGB(255, 255, 255); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.Parent = b
        end
        st.Enabled = on and true or false
        b.Text = on and ("✓ " .. base) or base
    end

    local function buttonRow(body, items, y, h, textSize)
        local btns = {}
        local n = #items
        for i, it in ipairs(items) do
            local b = mk("TextButton", {
                Name = "Btn", Size = UDim2.new(1 / n, -4, 0, sc(h or 32)),
                Position = UDim2.new((i - 1) / n, 2, 0, sc(y or 0)),
                BackgroundColor3 = it.color or BTN, TextColor3 = Color3.fromRGB(225, 215, 255),
                Font = Enum.Font.GothamBold, TextSize = textSize or 11, Text = it.text,
                TextWrapped = true, AutoButtonColor = false, BorderSizePixel = 0,
            }, body)
            corner(b, 6)
            onClick(b, it.fn)
            btns[i] = b
        end
        return btns
    end

    -- 📐 РАЗМЕР СЕТКИ
    do
        local body = section("📐 РАЗМЕР СЕТКИ", Color3.fromRGB(60, 80, 120), 32)
        local btns = {}
        local function paintSizes()
            for i, n in ipairs(GRID_OPTIONS) do
                btns[i].BackgroundColor3 = (n == GRID) and Color3.fromRGB(80, 120, 180) or BTN
                markActive(btns[i], n == GRID)
            end
        end
        local function setSize(n)
            if n == GRID then return end
            resizeGrid(n); resetHistory2D(); rebuildGridUI(); paintSizes(); refreshCount()
            ORBIT.notify("📐 Сетка: " .. n .. "×" .. n, Color3.fromRGB(180, 220, 255), 1.5)
        end
        local items = {}
        for i, n in ipairs(GRID_OPTIONS) do
            items[i] = {text = n .. "×" .. n, fn = function() setSize(n) end}
        end
        btns = buttonRow(body, items, 0, 32, 12)
        paintSizes()
        Ed2D.SetGridSize = function(n)
            for _, g in ipairs(GRID_OPTIONS) do
                if g == n then setSize(n); return true end
            end
            return false
        end
    end

    -- 🎨 ПАЛИТРА
    local swatch
    do
        local body, titleLbl = section("🎨 ПАЛИТРА", Color3.fromRGB(100, 60, 140), 54)
        body.Parent.LayoutOrder = 0
        swatch = mk("Frame", {
            Name = "Swatch", Size = UDim2.new(0, 26, 0, 12), Position = UDim2.new(1, -30, 0, 3),
            BackgroundColor3 = PALETTE[Ed2D.Color], BorderSizePixel = 0,
        }, titleLbl)
        corner(swatch, 3)
        mk("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1}, swatch)

        local palScroll = mk("ScrollingFrame", {
            Name = "Pal", Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Color3.fromRGB(15, 12, 24),
            BorderSizePixel = 0, CanvasSize = UDim2.new(0, #PALETTE * 42 + 12, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4,
            ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255),
        }, body)
        corner(palScroll, 8)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, palScroll)
        mk("UIPadding", {
            PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
        }, palScroll)

        local strokes = {}
        local function refreshPal()
            for i, st in ipairs(strokes) do
                local on = (i == Ed2D.Color)
                st.Thickness = on and 3 or 1
                st.Transparency = on and 0 or 0.8
            end
            swatch.BackgroundColor3 = PALETTE[Ed2D.Color]
            titleLbl.Text = " 🎨 " .. COLOR_NAMES[Ed2D.Color]
        end
        for i, col in ipairs(PALETTE) do
            local b = mk("TextButton", {
                Name = "Col", Size = UDim2.new(0, 38, 0, 38), BackgroundColor3 = col,
                Text = "", BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i,
            }, palScroll)
            corner(b, 6)
            strokes[i] = mk("UIStroke", {
                Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.8,
            }, b)
            onClick(b, function()
                Ed2D.Color = i
                if Ed2D.Tool == "eraser" or Ed2D.Tool == "pick" then Ed2D.Tool = "paint"; if Ed2D.paintTools then Ed2D.paintTools() end end
                refreshPal()
            end)
        end
        refreshPal()
        Ed2D.refreshPal = refreshPal
    end

    -- 🔲 РАЗМЕР КИСТИ
    do
        local body = section("🔲 РАЗМЕР КИСТИ", Color3.fromRGB(100, 80, 40), 38)
        local btns = {}
        Ed2D.paintBrush = function()
            for i = 1, 5 do
                btns[i].BackgroundColor3 = (Ed2D.Brush == i) and Color3.fromRGB(100, 80, 160) or BTN
                markActive(btns[i], Ed2D.Brush == i)
            end
        end
        local items = {}
        for i = 1, 5 do
            items[i] = {text = i .. "×" .. i, fn = function() Ed2D.Brush = i; Ed2D.paintBrush() end}
        end
        btns = buttonRow(body, items, 0, 38, 13)
        Ed2D.paintBrush()
    end

    -- 🛠 ИНСТРУМЕНТ
    do
        local body = section("🛠 ИНСТРУМЕНТ", Color3.fromRGB(120, 90, 50), 38)
        local tools = {
            {key = "paint",  text = "🖌 Кисть"},
            {key = "eraser", text = "🧽 Ластик"},
            {key = "fill",   text = "🪣 Заливка"},
            {key = "pick",   text = "💧 Пипетка"},
        }
        local onColor = {
            paint = Color3.fromRGB(100, 80, 160), eraser = Color3.fromRGB(150, 60, 60),
            fill = Color3.fromRGB(80, 130, 80), pick = Color3.fromRGB(70, 120, 150),
        }
        local btns = {}
        Ed2D.paintTools = function()
            for i, t in ipairs(tools) do
                btns[i].BackgroundColor3 = (Ed2D.Tool == t.key) and onColor[t.key] or BTN
                markActive(btns[i], Ed2D.Tool == t.key)
            end
        end
        local items = {}
        for i, t in ipairs(tools) do
            items[i] = {text = t.text, fn = function() Ed2D.Tool = t.key; Ed2D.paintTools() end}
        end
        btns = buttonRow(body, items, 0, 38, 11)
        Ed2D.paintTools()
    end

    -- ↩️ ИСТОРИЯ
    do
        local body = section("↩️ ИСТОРИЯ", Color3.fromRGB(60, 90, 60), 32)
        local hb = buttonRow(body, {
            {text = "↶ Отмена", color = BTN_OFF, fn = function()
                if do2DUndo() then refreshAllCells(); refreshCount() end
            end},
            {text = "↷ Вернуть", color = BTN_OFF, fn = function()
                if do2DRedo() then refreshAllCells(); refreshCount() end
            end},
            {text = "🗑 Очистить", color = Color3.fromRGB(120, 45, 45), fn = function()
                for r = 1, GRID do for c = 1, GRID do Ed2D.Cells[r][c] = 0 end end
                commit2D(); refreshAllCells(); refreshCount()
            end},
        }, 0, 32, 11)
        Ed2D.OnHistory = function()
            local canUndo = Ed2D.StateIdx > 1
            local canRedo = Ed2D.StateIdx < #Ed2D.States
            hb[1].BackgroundColor3 = canUndo and Color3.fromRGB(70, 150, 220) or BTN_OFF
            hb[1].TextTransparency = canUndo and 0 or 0.55
            hb[2].BackgroundColor3 = canRedo and Color3.fromRGB(70, 190, 130) or BTN_OFF
            hb[2].TextTransparency = canRedo and 0 or 0.55
        end
        Ed2D.OnHistory()
    end

    -- ⚡ БЫСТРЫЕ ФОРМЫ
    do
        local body = section("⚡ БЫСТРЫЕ ФОРМЫ", Color3.fromRGB(140, 80, 40), 32)
        local function placeTemplate(pattern, colorMap)
            local offsetR = math.floor((GRID - #pattern) / 2)
            local offsetC = math.floor((GRID - #pattern[1]) / 2)
            for rr = 1, #pattern do
                for cc = 1, #pattern[rr] do
                    local ch = pattern[rr]:sub(cc, cc)
                    local idx = colorMap[ch]
                    if idx then
                        local r, c = offsetR + rr, offsetC + cc
                        if r >= 1 and r <= GRID and c >= 1 and c <= GRID then
                            Ed2D.Cells[r][c] = idx
                        end
                    end
                end
            end
            commit2D(); refreshAllCells(); refreshCount()
        end
        local purple = Color3.fromRGB(80, 60, 100)
        buttonRow(body, {
            {text = "↔ Симметрия", color = purple, fn = function()
                for r = 1, GRID do
                    for c = 1, math.floor(GRID / 2) do
                        Ed2D.Cells[r][GRID - c + 1] = Ed2D.Cells[r][c]
                    end
                end
                commit2D(); refreshAllCells(); refreshCount()
            end},
            {text = "❤ Сердце", color = purple, fn = function() placeTemplate(HEART_PATTERN, {["1"] = 1}) end},
            {text = "☺ Смайл", color = purple, fn = function() placeTemplate(SMILE_PATTERN, {["1"] = 3, ["2"] = 21}) end},
        }, 0, 32, 10)
    end

    -- 💾 СОХРАНЕНИЕ
    do
        local body = section("💾 СОХРАНЕНИЕ", Color3.fromRGB(100, 60, 140), 300)

        countLbl = mk("TextLabel", {
            Name = "Count", Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0, 2, 0, 0),
            BackgroundTransparency = 1, Text = "🧱 клеток: 0", TextColor3 = Color3.fromRGB(180, 220, 255),
            Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        }, body)

        local nameInput = mk("TextBox", {
            Name = "NameInput", Size = UDim2.new(1, -4, 0, 32), Position = UDim2.new(0, 2, 0, 20),
            BackgroundColor3 = Color3.fromRGB(35, 30, 50), TextColor3 = Color3.fromRGB(230, 220, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, PlaceholderText = "✏️ Имя фигуры...",
            PlaceholderColor3 = Color3.fromRGB(150, 140, 180), Text = "", ClearTextOnFocus = false,
            BorderSizePixel = 0,
        }, body)
        corner(nameInput, 6)

        local saveBtn = mk("TextButton", {
            Name = "Save", Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, 58),
            BackgroundColor3 = Color3.fromRGB(60, 120, 80), TextColor3 = Color3.fromRGB(200, 255, 210),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "💾 СОХРАНИТЬ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(saveBtn, 8)

        local sellBtn = mk("TextButton", {
            Name = "Sell", Size = UDim2.new(1, -4, 0, 32), Position = UDim2.new(0, 2, 0, 100),
            BackgroundColor3 = Color3.fromRGB(90, 70, 30), TextColor3 = Color3.fromRGB(255, 220, 120),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "💰 ПРОДАТЬ +50",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(sellBtn, 8)

        local shareBtn = mk("TextButton", {
            Name = "Share", Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, 138),
            BackgroundColor3 = Color3.fromRGB(70, 60, 130), TextColor3 = Color3.fromRGB(220, 210, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "📤 ПОДЕЛИТЬСЯ ФИГУРОЙ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(shareBtn, 8)

        local importBtn = mk("TextButton", {
            Name = "Import", Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, 178),
            BackgroundColor3 = Color3.fromRGB(50, 80, 110), TextColor3 = Color3.fromRGB(200, 230, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "📥 ИМПОРТ ЧУЖОЙ ФИГУРЫ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(importBtn, 8)

        local clearAllBtn = mk("TextButton", {
            Name = "ClearAll", Size = UDim2.new(1, -4, 0, 32), Position = UDim2.new(0, 2, 0, 218),
            BackgroundColor3 = Color3.fromRGB(90, 40, 45), TextColor3 = Color3.fromRGB(255, 180, 180),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "🧹 ОЧИСТИТЬ ВСЁ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(clearAllBtn, 8)

        local pasteBtn = mk("TextButton", {
            Name = "PasteFromClipboard", Size = UDim2.new(1, -4, 0, 32), Position = UDim2.new(0, 2, 0, 256),
            BackgroundColor3 = Color3.fromRGB(60, 90, 130), TextColor3 = Color3.fromRGB(200, 230, 255),
            Font = Enum.Font.GothamBold, TextSize = 11, Text = "📋 ВСТАВИТЬ ИЗ БУФЕРА",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(pasteBtn, 8)

        onClick(saveBtn, function()
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
            local len = utf8.len(nm)
            if nm == "" or not len or len > 20 then
                nm = "СВОЯ_" .. (#SHAPE_PRESETS + 1)
            end
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

            for i, sp in ipairs(SHAPE_PRESETS) do
                if sp.name == nm then
                    ORBIT.shapeIndex = i
                    pcall(function()
                        rings[1].shapeIndex = i
                        ORBIT.destroyRing(1); ORBIT.buildRing(1); ORBIT.applyColor()
                    end)
                    break
                end
            end
        end)

        onClick(sellBtn, function()
            if countFilled() < 8 then
                ORBIT.notify("🎨 Минимум 8 клеток", Color3.fromRGB(255,200,120), 2)
                return
            end
            ORBIT.COINS = (ORBIT.COINS or 0) + 50
            ORBIT.SESSION = ORBIT.SESSION or {}
            ORBIT.SESSION.coinsEarned = (ORBIT.SESSION.coinsEarned or 0) + 50
            saveStorage()
            ORBIT.notify("💰 +50 монет (всего: " .. ORBIT.COINS .. ")", Color3.fromRGB(255,220,120), 3)
            if ORBIT.playBuy then pcall(ORBIT.playBuy) end
        end)

        onClick(shareBtn, function()
            if not ORBIT.share or not ORBIT.share.encodeShape then
                ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255,150,150), 3)
                return
            end
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
                ORBIT.notify("🎨 Сначала нарисуй фигуру", Color3.fromRGB(255,200,120), 2)
                return
            end
            local nm = nameInput.Text
            local len = utf8.len(nm)
            if nm == "" or not len or len > 20 then
                nm = "СВОЯ_" .. (#SHAPE_PRESETS + 1)
            end
            local str, err = ORBIT.share.encodeShape({ name = nm, grid = GRID, pixels = data })
            if not str then
                ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255,150,150), 3)
                return
            end
            ORBIT.share.open(str)
        end)

        onClick(importBtn, function()
            if not ORBIT.share or not ORBIT.share.open then
                ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255,150,150), 3)
                return
            end
            ORBIT.share.open()
        end)

        onClick(clearAllBtn, function()
            for r = 1, GRID do for c = 1, GRID do Ed2D.Cells[r][c] = 0 end end
            commit2D(); refreshAllCells(); refreshCount()
            ORBIT.notify("🧹 Очищено", Color3.fromRGB(255, 200, 200), 2)
        end)

        -- ✨ v24.3: вставить фигуру из буфера прямо в редактор
        onClick(pasteBtn, function()
            if not ORBIT.share or not ORBIT.share.paste then
                ORBIT.notify("❌ Модуль SHARE не загружен", Color3.fromRGB(255,150,150), 3)
                return
            end
            local txt, err = ORBIT.share.paste()
            if not txt or #txt < 10 then
                ORBIT.notify("📋 Буфер пустой", Color3.fromRGB(255,200,120), 3)
                return
            end
            local decoded, derr = ORBIT.share.decode(txt)
            if not decoded or decoded.kind ~= "SH" then
                ORBIT.notify("❌ " .. tostring(derr or "не фигура"), Color3.fromRGB(255,150,150), 3)
                return
            end
            local shape = decoded.data
            if shape.type == "3D" then
                ORBIT.notify("📥 Это 3D-фигура — добавлена в «МОИ ФИГУРЫ»", Color3.fromRGB(180,220,255), 3)
                if ORBIT.share.applyDecoded then
                    ORBIT.share.applyDecoded(decoded)
                end
                return
            end
            -- 2D: загружаем пиксели в сетку
            if shape.grid and shape.pixels then
                if shape.grid ~= GRID then resizeGrid(shape.grid) end
                for r = 1, shape.grid do
                    for c = 1, shape.grid do
                        Ed2D.Cells[r][c] = (shape.pixels[r] and shape.pixels[r][c]) or 0
                    end
                end
                commit2D(); rebuildGridUI(); refreshCount()
                ORBIT.notify("📥 Фигура загружена в редактор: " .. (shape.name or ""), Color3.fromRGB(180,255,180), 3)
            end
        end)
    end

    rebuildGridUI()
    refreshCount()
    fitCanvas()
end

-- Кнопки «Магазин»/«Редактор» привязаны в orbit_p4b.lua (один источник правды).
ORBIT.openShop = openShop
ORBIT.openEditor = openEditor
Ed2D.GridOptions = GRID_OPTIONS
Ed2D.SetBrush = function(n)
    n = math.clamp(math.floor(tonumber(n) or 1), 1, 5)
    Ed2D.Brush = n
    if Ed2D.paintBrush then pcall(Ed2D.paintBrush) end
    return n
end
ORBIT.Editor2D = Ed2D
ORBIT.SHAPE_PRICES = SHAPE_PRICES
ORBIT.PALETTE = PALETTE
ORBIT.saveStorage = saveStorage

if ORBIT.notify then
    ORBIT.notify("🎨 Магазин v24.3 (+ копирование/вставка фигур)", Color3.fromRGB(220,200,255), 3)
end

return true
