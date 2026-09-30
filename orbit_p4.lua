--[[ ОРБИТА v21.2 — P4 часть 1/2: ПОНЯТНАЯ ГЛАВНАЯ ПАНЕЛЬ ]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P4] Часть 1 не загружена!"); return end

local Players      = ORBIT.Players
local LocalPlayer  = ORBIT.LocalPlayer
local PlayerGui    = ORBIT.PlayerGui
local TweenService = ORBIT.TweenService

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local rings    = ORBIT.rings
local statsData = ORBIT.statsData
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS
if not P then warn("[Orbit P4] P не передан"); return end
if not SHAPE_PRESETS then warn("[Orbit P4] Часть 2 не загружена"); return end
if not ORBIT.startUpdateLoop then warn("[Orbit P4] Часть 3 не загружена"); return end
if not ORBIT.createBot then warn("[Orbit P4] Боты не найдены в p3!"); return end

-- ==================== ОКНО ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "_OrbitMain_" .. tostring(math.random(100000, 999999))
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ORBIT.protectGui(screenGui)
local okp = pcall(function() screenGui.Parent = ORBIT.getSafeParent() end)
if not okp or not screenGui.Parent then screenGui.Parent = PlayerGui end
getgenv()._OrbitMainGui = screenGui

-- Кнопка-открывашка
local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, 56, 0, 56)
mainBtn.Position = UDim2.new(0, 20, 0, 100)
mainBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
mainBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 24
mainBtn.Text = "✨"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke", mainBtn)
mainStroke.Color = Color3.fromRGB(140, 120, 255)
mainStroke.Thickness = 2

-- Панель
local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 320, 0, 720)
panel.Position = UDim2.new(0, 90, 0, 5)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 0)
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.ScrollBarThickness = 4
panel.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(120, 120, 255)
panelStroke.Thickness = 1.5

-- Фон-матрица
local bgLayer = Instance.new("Frame")
bgLayer.Size = UDim2.new(1, 0, 1, 0)
bgLayer.BackgroundColor3 = Color3.fromRGB(0, 5, 2)
bgLayer.BackgroundTransparency = 0.7
bgLayer.BorderSizePixel = 0
bgLayer.ClipsDescendants = true
bgLayer.ZIndex = 0
bgLayer.Parent = panel
Instance.new("UICorner", bgLayer).CornerRadius = UDim.new(0, 14)

local MATRIX_CHARS = {"0","1","<",">","{","}","[","]","/","\\","|","+","-","*","=","#","%","&","$","@","A","E","F","Z","X","7","9","?"}
task.spawn(function()
    local columns = {}
    local NUM_COLS = 12
    for i = 1, NUM_COLS do
        local col = Instance.new("TextLabel")
        col.Size = UDim2.new(0, 14, 0, 300)
        col.Position = UDim2.new((i - 0.5) / NUM_COLS, 0, -1, 0)
        col.BackgroundTransparency = 1
        col.TextColor3 = Color3.fromRGB(80, 255, 140)
        col.TextTransparency = 0.8
        col.Font = Enum.Font.Code
        col.TextSize = 11
        col.TextYAlignment = Enum.TextYAlignment.Top
        col.ZIndex = 0
        col.Parent = bgLayer
        local str = ""
        for j = 1, 25 do
            str = str .. MATRIX_CHARS[math.random(1, #MATRIX_CHARS)]
            if j < 25 then str = str .. "\n" end
        end
        col.Text = str
        table.insert(columns, { label = col, speed = math.random(40, 110) / 100 })
    end
    while bgLayer and bgLayer.Parent do
        for _, c in ipairs(columns) do
            local pos = c.label.Position
            local newY = pos.Y.Scale + 0.001 * c.speed * 55
            if newY > 1.1 then
                newY = -1.1 - math.random(0, 20) / 100
                local str = ""
                for j = 1, 25 do
                    str = str .. MATRIX_CHARS[math.random(1, #MATRIX_CHARS)]
                    if j < 25 then str = str .. "\n" end
                end
                c.label.Text = str
                c.speed = math.random(40, 110) / 100
            end
            c.label.Position = UDim2.new(pos.X.Scale, pos.X.Offset, newY, pos.Y.Offset)
        end
        task.wait(0.06)
    end
end)

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 8)
title.BackgroundTransparency = 1
title.Text = "✨  ОРБИТА v21.2"
title.TextColor3 = Color3.fromRGB(230, 220, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.ZIndex = 2
title.Parent = panel

-- ============ ХЕЛПЕРЫ ============
-- Большая секция с иконкой, названием и подсказкой
local function makeSection(icon, text, hint, color)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -16, 0, hint and 44 or 32)
    holder.BackgroundColor3 = color or Color3.fromRGB(55, 55, 90)
    holder.BackgroundTransparency = 0.35
    holder.BorderSizePixel = 0
    holder.ZIndex = 2
    holder.Parent = panel
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 10)

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -8)
    stripe.Position = UDim2.new(0, 4, 0, 4)
    stripe.BackgroundColor3 = color or Color3.fromRGB(140, 140, 220)
    stripe.BorderSizePixel = 0
    stripe.ZIndex = 3
    stripe.Parent = holder
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 2)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 26, 1, 0)
    iconLbl.Position = UDim2.new(0, 10, 0, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 18
    iconLbl.ZIndex = 3
    iconLbl.Parent = holder

    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -40, 0, hint and 20 or 32)
    s.Position = UDim2.new(0, 38, 0, hint and 2 or 0)
    s.BackgroundTransparency = 1
    s.Text = text
    s.TextColor3 = Color3.fromRGB(240, 240, 255)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 13
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.ZIndex = 3
    s.Parent = holder

    if hint then
        local h = Instance.new("TextLabel")
        h.Size = UDim2.new(1, -40, 0, 18)
        h.Position = UDim2.new(0, 38, 0, 22)
        h.BackgroundTransparency = 1
        h.Text = hint
        h.TextColor3 = Color3.fromRGB(180, 180, 210)
        h.Font = Enum.Font.Gotham
        h.TextSize = 10
        h.TextXAlignment = Enum.TextXAlignment.Left
        h.ZIndex = 3
        h.Parent = holder
    end
    return holder
end

local function makeButton(text, h, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, h or 34)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(45, 45, 62)
    b.TextColor3 = textColor or Color3.fromRGB(235, 235, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.ZIndex = 2
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = bgColor or Color3.fromRGB(80, 80, 120)
    stroke.Thickness = 1
    stroke.Transparency = 0.65
    return b
end

-- ============================================================
--                    ОСНОВНОЕ
-- ============================================================
makeSection("⚡", "ОСНОВНОЕ", "Включение скрипта и кольца", Color3.fromRGB(60, 60, 100))
local toggleBtn   = makeButton("🟢 Скрипт ВКЛЮЧЕН", 36, Color3.fromRGB(40,55,40), Color3.fromRGB(120, 255, 160))
local allRingsBtn = makeButton("⭕ Все кольца (2-5): ВКЛ", 32, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring2Btn    = makeButton("Кольцо 2", 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring3Btn    = makeButton("Кольцо 3", 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring4Btn    = makeButton("Кольцо 4", 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring5Btn    = makeButton("Кольцо 5", 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))

-- ============================================================
--                    БОТЫ
-- ============================================================
makeSection("🤖", "БОТЫ — ФАРМ КОЛЕЦ", "Подходи к боту → его фигура встанет тебе в кольцо", Color3.fromRGB(100, 70, 140))

-- Обычные боты → в кольцо 1
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -16, 0, 20)
lbl.BackgroundTransparency = 1
lbl.Text = "  🎯 ОБЫЧНЫЕ — фигура идёт в КОЛЬЦО 1"
lbl.TextColor3 = Color3.fromRGB(200, 255, 200)
lbl.Font = Enum.Font.GothamBold
lbl.TextSize = 11
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.ZIndex = 3
lbl.Parent = panel

local regNearBtn = makeButton("📍 Бот рядом (перед тобой)", 30, Color3.fromRGB(45,80,55), Color3.fromRGB(170,255,200))
local reg1Btn    = makeButton("➕ 1 бот     🔥 5 ботов     💥 10 ботов", 30, Color3.fromRGB(55,75,45), Color3.fromRGB(200,255,180))

-- Специальные боты → кольца 2-5
local lbl2 = Instance.new("TextLabel")
lbl2.Size = UDim2.new(1, -16, 0, 20)
lbl2.BackgroundTransparency = 1
lbl2.Text = "  🌟 СПЕЦИАЛЬНЫЕ — фигура идёт в КОЛЬЦО 2/3/4/5"
lbl2.TextColor3 = Color3.fromRGB(255, 200, 255)
lbl2.Font = Enum.Font.GothamBold
lbl2.TextSize = 11
lbl2.TextXAlignment = Enum.TextXAlignment.Left
lbl2.ZIndex = 3
lbl2.Parent = panel

local sp2Btn = makeButton("Кольцо 2 ← бот рядом   |   5 ботов", 28, Color3.fromRGB(70,55,110), Color3.fromRGB(220,200,255))
local sp3Btn = makeButton("Кольцо 3 ← бот рядом   |   5 ботов", 28, Color3.fromRGB(85,55,110), Color3.fromRGB(225,200,255))
local sp4Btn = makeButton("Кольцо 4 ← бот рядом   |   5 ботов", 28, Color3.fromRGB(100,55,110), Color3.fromRGB(230,200,255))
local sp5Btn = makeButton("Кольцо 5 ← бот рядом   |   5 ботов", 28, Color3.fromRGB(115,55,110), Color3.fromRGB(235,200,255))

local botRemoveAll  = makeButton("🗑 Удалить всех ботов", 30, Color3.fromRGB(80,30,30), Color3.fromRGB(255,180,180))
local botAutoBtn    = makeButton("🎁 Автосбор: ВКЛ", 28, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180))
local botRadiusBtn  = makeButton("📏 Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st", 28, Color3.fromRGB(35,50,65), Color3.fromRGB(180,220,255))

local botInfoLbl = Instance.new("TextLabel")
botInfoLbl.Size = UDim2.new(1, -16, 0, 22)
botInfoLbl.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
botInfoLbl.BackgroundTransparency = 0.3
botInfoLbl.BorderSizePixel = 0
botInfoLbl.Text = "🤖 Ботов: 0"
botInfoLbl.TextColor3 = Color3.fromRGB(210, 210, 255)
botInfoLbl.Font = Enum.Font.GothamBold
botInfoLbl.TextSize = 11
botInfoLbl.ZIndex = 2
botInfoLbl.Parent = panel
Instance.new("UICorner", botInfoLbl).CornerRadius = UDim.new(0, 6)

-- ============================================================
--                    СКИН БОТА
-- ============================================================
makeSection("👤", "СКИН БОТА", "Боты будут выглядеть как ты", Color3.fromRGB(85, 65, 130))
local botSkinBtn = makeButton("👤 Скин как у меня: ВЫКЛ", 32, Color3.fromRGB(55,45,75), Color3.fromRGB(220,200,255))

-- ============================================================
--                    ЛЮДИ
-- ============================================================
makeSection("👥", "ЛЮДИ И КОЛЬЦА", "Навесь кольца другим игрокам / метку читера", Color3.fromRGB(100, 50, 130))
local addAllRingsBtn = makeButton("➕ Навесить кольца ВСЕМ игрокам", 30, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180))
local remAllRingsBtn = makeButton("➖ Убрать кольца У ВСЕХ", 30, Color3.fromRGB(70,40,40), Color3.fromRGB(255,160,160))

local peopleListLabel = Instance.new("TextLabel")
peopleListLabel.Size = UDim2.new(1, -16, 0, 18)
peopleListLabel.BackgroundTransparency = 1
peopleListLabel.Text = "  👤 Игроки на сервере:"
peopleListLabel.TextColor3 = Color3.fromRGB(190, 190, 230)
peopleListLabel.Font = Enum.Font.GothamBold
peopleListLabel.TextSize = 11
peopleListLabel.TextXAlignment = Enum.TextXAlignment.Left
peopleListLabel.ZIndex = 3
peopleListLabel.Parent = panel

local peopleListScroll = Instance.new("ScrollingFrame")
peopleListScroll.Size = UDim2.new(1, -16, 0, 200)
peopleListScroll.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
peopleListScroll.BackgroundTransparency = 0.2
peopleListScroll.BorderSizePixel = 0
peopleListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
peopleListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
peopleListScroll.ScrollBarThickness = 3
peopleListScroll.ScrollBarImageColor3 = Color3.fromRGB(180, 130, 255)
peopleListScroll.ZIndex = 2
peopleListScroll.Parent = panel
Instance.new("UICorner", peopleListScroll).CornerRadius = UDim.new(0, 8)
local peopleListLayout = Instance.new("UIListLayout")
peopleListLayout.SortOrder = Enum.SortOrder.LayoutOrder
peopleListLayout.Padding = UDim.new(0, 4)
peopleListLayout.Parent = peopleListScroll

local refreshPeopleBtn = makeButton("🔄 Обновить список", 30, Color3.fromRGB(45,55,90), Color3.fromRGB(180,220,255))

-- ============================================================
--                    ВНЕШНИЙ ВИД КОЛЬЦА
-- ============================================================
makeSection("🎨", "ВНЕШНИЙ ВИД КОЛЬЦА", "Форма, цвет, размер, свет", Color3.fromRGB(60, 100, 120))
local shapeCatBtn  = makeButton("📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, 30, Color3.fromRGB(60,50,80), Color3.fromRGB(220,200,255))
local shapeBtn     = makeButton("🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, 30)
local shapeModeBtn = makeButton("🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name, 28, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255))
local shapeSizeBtn = makeButton("🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, 28)
local autoSwapBtn  = makeButton("🎭 Автосмена формы: ВЫКЛ", 28, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255))
local colorBtn     = makeButton("🎨 Цвет: " .. P.COLORS[P.colorIndex].name, 30)
local gradientBtn  = makeButton("🌈 Градиент: ВЫКЛ", 28, Color3.fromRGB(55,35,75), Color3.fromRGB(255,180,255))
local lightBtn     = makeButton("💡 Свет: ВКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local nameBtn      = makeButton("🏷️ Имена блоков: ВЫКЛ", 28)

-- ============================================================
--                    ОРБИТА
-- ============================================================
makeSection("🛰️", "ОРБИТА И ДВИЖЕНИЕ", "Как кольцо вращается вокруг тебя", Color3.fromRGB(60, 100, 80))
local orbitBtn    = makeButton("📏 Размер орбиты: " .. P.ORBIT[P.orbitIndex].name, 30)
local spreadBtn   = makeButton("📐 Разлёт колец: " .. P.SPREAD[P.spreadIndex].name, 28, Color3.fromRGB(55,30,55), Color3.fromRGB(255,180,255))
local heightBtn   = makeButton("⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name, 28, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local speedBtn    = makeButton("⚡ Скорость: " .. P.SPEED[P.speedIndex].name, 28, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100))
local speedModeBtn= makeButton("⚙️ Режим скорости: " .. P.SPEED_MODE[P.speedModeIndex].name, 28, Color3.fromRGB(45,50,65), Color3.fromRGB(180,220,255))
local directionBtn= makeButton("🔃 Направление: " .. P.DIRECTION[P.directionIndex].name, 28, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255))
local patternBtn  = makeButton("🌀 Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, 28, Color3.fromRGB(60,40,90), Color3.fromRGB(220,180,255))

-- ============================================================
--                    КРУЧЕНИЕ
-- ============================================================
makeSection("🔄", "КРУЧЕНИЕ ФИГУР", "Вращение самих фигурок", Color3.fromRGB(100, 60, 80))
local spinBtn      = makeButton("↩️ Вернуть вращение в 0", 28, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255))
local spinAxisBtn  = makeButton("🔄 Кручение оси: ВКЛ", 28, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220))
local spinDirBtn   = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 28, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255))
local spinSpeedBtn = makeButton("🌀 Скорость вращения: " .. P.SPIN_SPEED[P.spinSpeedIndex].name, 28, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255))

-- ============================================================
--                    ЭФФЕКТЫ КОЛЕЦ
-- ============================================================
makeSection("✨", "ЭФФЕКТЫ КОЛЕЦ", "Трейлы, волны, пульсация", Color3.fromRGB(100, 80, 60))
local trailBtn    = makeButton("🌠 Трейлы: ВЫКЛ", 28, Color3.fromRGB(35,35,50))
local trailLenBtn = makeButton("📏 Длина трейла: " .. P.TRAIL_LEN[P.trailLengthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local trailWidBtn = makeButton("🎚️ Толщина трейла: " .. P.TRAIL_WID[P.trailWidthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local waveBtn     = makeButton("🌊 Волна: ВЫКЛ", 28, Color3.fromRGB(30,55,75), Color3.fromRGB(140,220,255))
local explosionBtn= makeButton("💥 Пульс размера: ВЫКЛ", 28, Color3.fromRGB(70,40,30), Color3.fromRGB(255,180,120))
local pulseBtn    = makeButton("💓 Пульсация: ВЫКЛ", 28, Color3.fromRGB(35,35,50))

-- ============================================================
--                    ОГОНЬ
-- ============================================================
makeSection("🔥", "ОГОНЬ", "Классический эффект огня", Color3.fromRGB(150, 60, 20))
local fireBtn     = makeButton("🔥 Огонь: ВЫКЛ", 32, Color3.fromRGB(80,30,10), Color3.fromRGB(255,140,60))
local fireSizeBtn = makeButton("📏 Размер огня: " .. P.FIRE_SIZE[P.fireSizeIndex].name, 28, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120))
local fireHeatBtn = makeButton("🌡️ Жар огня: " .. P.FIRE_HEAT[P.fireHeatIndex].name, 28, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120))

-- ============================================================
--                    АУРА — ВКЛ/ЭЛЕМЕНТЫ
-- ============================================================
makeSection("🌀", "АУРА — ВКЛЮЧЕНИЕ", "Дополнительное кольцо-ореол", Color3.fromRGB(80, 60, 130))
local auraBtn     = makeButton("🌀 Аура: ВЫКЛ", 32, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255))
local auraRingBtn = makeButton("⭕ Кольцо ауры: ВКЛ", 28, Color3.fromRGB(35,55,35), Color3.fromRGB(160,255,160))
local auraPartBtn = makeButton("✨ Частицы: ВЫКЛ", 28, Color3.fromRGB(35,50,55), Color3.fromRGB(180,220,255))
local auraFigBtn  = makeButton("🔷 Фигуры ауры: ВЫКЛ", 28, Color3.fromRGB(45,35,65), Color3.fromRGB(220,180,255))
local auraShapeBtn= makeButton("🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, 28, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255))
local auraColorBtn= makeButton("🎨 Цвет ауры: " .. P.COLORS[P.auraColorIndex].name, 28, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255))

-- ============================================================
--                    АУРА — РАЗМЕР
-- ============================================================
makeSection("📏", "АУРА — РАЗМЕР", nil, Color3.fromRGB(80, 60, 130))
local auraSizeBtn  = makeButton("Размер кольца: " .. P.AURA_SIZE[P.auraSizeIndex].name, 28, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local auraThickBtn = makeButton("Толщина кольца: " .. P.AURA_THICK[P.auraThickIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local auraHeightBtn= makeButton("Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, 28, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local auraScaleBtn = makeButton("Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, 28, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255))

-- ============================================================
--                    АУРА — СКОРОСТЬ
-- ============================================================
makeSection("⚡", "АУРА — СКОРОСТЬ И ВРАЩЕНИЕ", nil, Color3.fromRGB(80, 60, 130))
local auraSpeedBtn    = makeButton("Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, 28, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100))
local auraDirBtn      = makeButton("Направление: " .. P.AURA_DIR[P.auraDirIndex].name, 28, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255))
local auraSpinBtn     = makeButton("Кручение: ВКЛ", 28, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220))
local auraSpinAxisBtn = makeButton("Ось: ВЕРХ/ВНИЗ", 28, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255))
local auraSpinSpeedBtn= makeButton("Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name, 28, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255))
local auraSpinResetBtn= makeButton("↩️ Сброс вращения", 28, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255))

-- ============================================================
--                    АУРА — ТРЕЙЛЫ
-- ============================================================
makeSection("🌠", "АУРА — ТРЕЙЛЫ", nil, Color3.fromRGB(80, 60, 130))
local auraTrailBtn   = makeButton("Трейлы ауры: ВЫКЛ", 28, Color3.fromRGB(35,35,50))
local auraTrailLenBtn= makeButton("Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local auraTrailWidBtn= makeButton("Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))

-- ============================================================
--                    ЗАЩИТА
-- ============================================================
makeSection("🛡️", "ЗАЩИТА", "Anti-Fling, Anti-GodMode, Auto-Dodge (Sans)", Color3.fromRGB(60, 100, 60))
local protBtn      = makeButton("🛡️ Защита: ВЫКЛ", 36, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180))
local antiKbBtn    = makeButton("Anti-Knockback: ВКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiTpBtn    = makeButton("Anti-Teleport: ВКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiFrzBtn   = makeButton("Anti-Freeze: ВКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiFlingBtn = makeButton("Anti-Fling/Spin: ВКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local autoHealBtn  = makeButton("Auto-Heal: ВЫКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiVoidBtn  = makeButton("Anti-Void: ВКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local lockPosBtn   = makeButton("Lock Position: ВЫКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

-- Auto-Dodge (Sans)
local dodgeBtn = makeButton("🥷 Auto-Dodge (Sans): ВКЛ", 32, Color3.fromRGB(60,80,50), Color3.fromRGB(200,255,180))
dodgeBtn.Activated:Connect(function()
    if ORBIT.DODGE then
        ORBIT.DODGE.Enabled = not ORBIT.DODGE.Enabled
        dodgeBtn.Text = "🥷 Auto-Dodge (Sans): " .. (ORBIT.DODGE.Enabled and "ВКЛ" or "ВЫКЛ")
        dodgeBtn.BackgroundColor3 = ORBIT.DODGE.Enabled and Color3.fromRGB(60,80,50) or Color3.fromRGB(50,50,50)
    end
end)

-- ============================================================
--                    МЕТКИ
-- ============================================================
makeSection("🚩", "МЕТКИ ЧИТЕРОВ", "Подсветить подозрительных игроков", Color3.fromRGB(120, 50, 80))
local tagNearestBtn = makeButton("🚩 Пометить ближайшего игрока", 30, Color3.fromRGB(80,30,55), Color3.fromRGB(255,150,200))
local clearTagsBtn  = makeButton("🧹 Снять все метки", 28, Color3.fromRGB(50,35,45), Color3.fromRGB(255,180,200))

-- ============================================================
--                    МАГАЗИН / РЕДАКТОР
-- ============================================================
makeSection("🛒", "МАГАЗИН И РЕДАКТОР", "Превью аватара + свои фигуры", Color3.fromRGB(110, 60, 150))
local openShopBtn   = makeButton("🛒 Открыть МАГАЗИН", 36, Color3.fromRGB(90,50,130), Color3.fromRGB(255,210,255))
local openEditorBtn = makeButton("🎨 Редактор своей фигуры", 32, Color3.fromRGB(70,60,110), Color3.fromRGB(220,210,255))

-- ============================================================
--                    ПРОИЗВОДИТЕЛЬНОСТЬ
-- ============================================================
makeSection("⚙️", "ПРОИЗВОДИТЕЛЬНОСТЬ", "Авто-снижение качества на слабых устройствах", Color3.fromRGB(60, 80, 110))
local perfBtn = makeButton("⚡ Качество: АВТО", 30, Color3.fromRGB(35,50,75), Color3.fromRGB(180,220,255))

-- ============================================================
--                    ПРОЧЕЕ
-- ============================================================
makeSection("💗", "ПРОЧЕЕ", nil, Color3.fromRGB(100, 50, 80))
local heartSizeBtn = makeButton("💗 Размер сердца: 100%", 30, Color3.fromRGB(70, 30, 55), Color3.fromRGB(255, 160, 200))

-- ============================================================
--                    СОХРАНЕНИЯ
-- ============================================================
makeSection("💾", "СОХРАНЕНИЯ", "Сохрани/загрузи все настройки", Color3.fromRGB(60, 60, 90))
local saveNameInput = Instance.new("TextBox")
saveNameInput.Size = UDim2.new(1, -16, 0, 32)
saveNameInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
saveNameInput.BackgroundTransparency = 0.1
saveNameInput.TextColor3 = Color3.fromRGB(240, 230, 255)
saveNameInput.Font = Enum.Font.GothamBold
saveNameInput.TextSize = 12
saveNameInput.PlaceholderText = "Напиши имя сохранения..."
saveNameInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
saveNameInput.Text = ""
saveNameInput.ClearTextOnFocus = false
saveNameInput.ZIndex = 2
saveNameInput.Parent = panel
Instance.new("UICorner", saveNameInput).CornerRadius = UDim.new(0, 8)

local createSaveBtn = makeButton("💾 Сохранить под этим именем", 32, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180))

local savesContainer = Instance.new("ScrollingFrame")
savesContainer.Size = UDim2.new(1, -16, 0, 130)
savesContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
savesContainer.BackgroundTransparency = 0.2
savesContainer.BorderSizePixel = 0
savesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
savesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
savesContainer.ScrollBarThickness = 3
savesContainer.ScrollBarImageColor3 = Color3.fromRGB(150,100,200)
savesContainer.ZIndex = 2
savesContainer.Parent = panel
Instance.new("UICorner", savesContainer).CornerRadius = UDim.new(0, 8)
local savesLayout = Instance.new("UIListLayout")
savesLayout.SortOrder = Enum.SortOrder.LayoutOrder
savesLayout.Padding = UDim.new(0, 4)
savesLayout.Parent = savesContainer

-- ============================================================
--                    СИСТЕМА
-- ============================================================
makeSection("🖥️", "СИСТЕМА", nil, Color3.fromRGB(60, 60, 80))
local saveBtn   = makeButton("💾 Сохранить (автослот)", 30, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180))
local loadBtn   = makeButton("📂 Загрузить (автослот)", 30, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255))
local resetBtn  = makeButton("🔄 Сброс настроек", 28, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180))
local unloadBtn = makeButton("❌ ВЫГРУЗИТЬ СКРИПТ", 30, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140))

-- ============================================================
--                    МУЗЫКА
-- ============================================================
makeSection("🎵", "МУЗЫКА", "Свой Sound ID (только у тебя)", Color3.fromRGB(80, 60, 110))
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -16, 0, 32)
musicInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
musicInput.BackgroundTransparency = 0.1
musicInput.TextColor3 = Color3.fromRGB(240, 230, 255)
musicInput.Font = Enum.Font.GothamBold
musicInput.TextSize = 12
musicInput.PlaceholderText = "Sound ID (например 1839246711)"
musicInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
musicInput.Text = ""
musicInput.ClearTextOnFocus = false
musicInput.ZIndex = 2
musicInput.Parent = panel
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 8)

local applyIdBtn = makeButton("✅ Применить ID", 28, Color3.fromRGB(55,80,55), Color3.fromRGB(180,255,180))
local musicBtn   = makeButton("🎵 Музыка: ВЫКЛ", 28, Color3.fromRGB(50,35,60), Color3.fromRGB(220,180,255))

-- ============================================================
--                    СТАТИСТИКА
-- ============================================================
makeSection("📊", "СТАТИСТИКА", nil, Color3.fromRGB(60, 60, 90))
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -16, 0, 90)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsLabel.BackgroundTransparency = 0.2
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "FPS: --"
statsLabel.ZIndex = 2
statsLabel.Parent = panel
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)

-- ==================== ЛОГИКА: КНОПКИ ====================
local ringButtons = { [2]=ring2Btn, [3]=ring3Btn, [4]=ring4Btn, [5]=ring5Btn }
local function refreshRingButton(ri)
    local btn = ringButtons[ri]; if not btn then return end
    if rings[ri].enabled then
        btn.Text = "➖ Кольцо " .. ri .. " (убрать)"
        btn.BackgroundColor3 = Color3.fromRGB(55,40,40); btn.TextColor3 = Color3.fromRGB(255,160,160)
    else
        btn.Text = "➕ Кольцо " .. ri .. " (включить)"
        btn.BackgroundColor3 = Color3.fromRGB(40,55,40); btn.TextColor3 = Color3.fromRGB(160,255,160)
    end
end

mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)

toggleBtn.Activated:Connect(function()
    ORBIT.setEnabled(not ORBIT.enabled)
    if ORBIT.enabled then
        toggleBtn.Text = "🟢 Скрипт ВКЛЮЧЕН"
        toggleBtn.TextColor3 = Color3.fromRGB(120,255,160)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40,55,40)
    else
        toggleBtn.Text = "🔴 Скрипт ВЫКЛЮЧЕН"
        toggleBtn.TextColor3 = Color3.fromRGB(255,80,80)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50,35,40)
    end
end)

-- ===== СПИСОК ИГРОКОВ =====
local function rebuildPeopleList()
    for _, ch in ipairs(peopleListScroll:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    local list = ORBIT.getPlayerList and ORBIT.getPlayerList() or {}
    if #list == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -6, 0, 24)
        empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140, 130, 170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 11
        empty.LayoutOrder = 1
        empty.Parent = peopleListScroll
        return
    end
    for i, info in ipairs(list) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 52)
        row.BackgroundColor3 = Color3.fromRGB(28, 22, 45)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = peopleListScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -8, 0, 18)
        nameLbl.Position = UDim2.new(0, 6, 0, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = "👤 " .. info.name
        nameLbl.TextColor3 = Color3.fromRGB(230, 220, 255)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local btnRow = Instance.new("Frame")
        btnRow.Size = UDim2.new(1, -8, 0, 24)
        btnRow.Position = UDim2.new(0, 4, 0, 22)
        btnRow.BackgroundTransparency = 1
        btnRow.Parent = row

        local ringBtn = Instance.new("TextButton")
        ringBtn.Size = UDim2.new(0.5, -2, 1, 0)
        if info.hasRing then
            ringBtn.Text = "➖ Убрать кольцо"
            ringBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            ringBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
        else
            ringBtn.Text = "➕ Навесить кольцо"
            ringBtn.BackgroundColor3 = Color3.fromRGB(40, 70, 45)
            ringBtn.TextColor3 = Color3.fromRGB(160, 255, 180)
        end
        ringBtn.Font = Enum.Font.GothamBold
        ringBtn.TextSize = 10
        ringBtn.Parent = btnRow
        Instance.new("UICorner", ringBtn).CornerRadius = UDim.new(0, 5)

        local tagBtn = Instance.new("TextButton")
        tagBtn.Size = UDim2.new(0.5, -2, 1, 0)
        tagBtn.Position = UDim2.new(0.5, 2, 0, 0)
        if info.isTagged then
            tagBtn.Text = "✅ Снять метку"
            tagBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 50)
            tagBtn.TextColor3 = Color3.fromRGB(220, 200, 220)
        else
            tagBtn.Text = "🚩 Метка читера"
            tagBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 55)
            tagBtn.TextColor3 = Color3.fromRGB(255, 150, 200)
        end
        tagBtn.Font = Enum.Font.GothamBold
        tagBtn.TextSize = 10
        tagBtn.Parent = btnRow
        Instance.new("UICorner", tagBtn).CornerRadius = UDim.new(0, 5)

        ringBtn.Activated:Connect(function()
            if ORBIT.toggleTargetRings then ORBIT.toggleTargetRings(info.player) end
            task.wait(0.1); rebuildPeopleList()
        end)
        tagBtn.Activated:Connect(function()
            if ORBIT.toggleTagCheater then ORBIT.toggleTagCheater(info.player) end
            task.wait(0.1); rebuildPeopleList()
        end)
    end
end
rebuildPeopleList()

refreshPeopleBtn.Activated:Connect(function()
    rebuildPeopleList()
    refreshPeopleBtn.Text = "✅ Обновлено"
    task.wait(0.8)
    refreshPeopleBtn.Text = "🔄 Обновить список"
end)

addAllRingsBtn.Activated:Connect(function()
    if ORBIT.addRingsToAll then ORBIT.addRingsToAll() end
    task.wait(0.2); rebuildPeopleList()
end)
remAllRingsBtn.Activated:Connect(function()
    if ORBIT.removeRingsFromAll then ORBIT.removeRingsFromAll() end
    task.wait(0.2); rebuildPeopleList()
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(4)
        if panel.Visible then pcall(rebuildPeopleList) end
    end
end)
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then task.wait(0.5); pcall(rebuildPeopleList) end end)
Players.PlayerRemoving:Connect(function(p) if p ~= LocalPlayer then task.wait(0.3); pcall(rebuildPeopleList) end end)

-- ===== БОТЫ =====
local function refreshBotCount()
    local count = 0
    for _, data in pairs(ORBIT.bots) do
        if not data.collected then count = count + 1 end
    end
    botInfoLbl.Text = "🤖 Ботов: " .. count
end

regNearBtn.Activated:Connect(function()
    ORBIT.createBotNear(nil, 4, 1); task.wait(0.1); refreshBotCount()
end)
reg1Btn.Activated:Connect(function()
    ORBIT.createBot(nil, nil, 1); task.wait(0.1); refreshBotCount()
end)

sp2Btn.Activated:Connect(function()
    ORBIT.createMultipleBots(5, 2); task.wait(0.5); refreshBotCount()
end)
sp3Btn.Activated:Connect(function()
    ORBIT.createMultipleBots(5, 3); task.wait(0.5); refreshBotCount()
end)
sp4Btn.Activated:Connect(function()
    ORBIT.createMultipleBots(5, 4); task.wait(0.5); refreshBotCount()
end)
sp5Btn.Activated:Connect(function()
    ORBIT.createMultipleBots(5, 5); task.wait(0.5); refreshBotCount()
end)

-- Дополнительные кнопки обычных ботов (5/10)
reg1Btn.MouseButton1Down:Connect(function()
    -- правая часть кнопки — 5/10 ботов
end)

-- Отдельные кнопки для 5 и 10 (заменим текст)
local reg5Btn  = makeButton("🔥 5 обычных ботов → кольцо 1", 28, Color3.fromRGB(60,80,50), Color3.fromRGB(205,255,185))
local reg10Btn = makeButton("💥 10 обычных ботов → кольцо 1", 28, Color3.fromRGB(65,85,55), Color3.fromRGB(210,255,190))

reg5Btn.Activated:Connect(function() ORBIT.createMultipleBots(5, 1); task.wait(0.5); refreshBotCount() end)
reg10Btn.Activated:Connect(function() ORBIT.createManyBots(10, 1); task.wait(0.5); refreshBotCount() end)

botRemoveAll.Activated:Connect(function()
    ORBIT.removeAllBots(); task.wait(0.1); refreshBotCount()
end)
botAutoBtn.Activated:Connect(function()
    ORBIT.botSettings.AutoCollect = not ORBIT.botSettings.AutoCollect
    botAutoBtn.Text = "🎁 Автосбор: " .. (ORBIT.botSettings.AutoCollect and "ВКЛ" or "ВЫКЛ")
end)
botRadiusBtn.Activated:Connect(function()
    local steps = {6, 8, 10, 12, 15, 20, 25}
    local idx = 1
    for i, v in ipairs(steps) do if v == ORBIT.botSettings.CollectRadius then idx = i; break end end
    ORBIT.botSettings.CollectRadius = steps[(idx % #steps) + 1]
    botRadiusBtn.Text = "📏 Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st"
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(1)
        if panel.Visible then pcall(refreshBotCount) end
    end
end)
refreshBotCount()

-- ===== СКИН БОТА =====
botSkinBtn.Activated:Connect(function()
    ORBIT.botSettings.UseMySkin = not ORBIT.botSettings.UseMySkin
    botSkinBtn.Text = "👤 Скин как у меня: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ")
    ORBIT.botAvatarTemplate = nil
    ORBIT.notify("👤 Скин бота: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200, 180, 255), 2)
end)
if ORBIT.botSettings.UseMySkin then botSkinBtn.Text = "👤 Скин как у меня: ВКЛ" end

-- ===== КОЛЬЦА =====
allRingsBtn.Activated:Connect(function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local ns = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= ns then ORBIT.setRingEnabled(ri, ns) end end
    for ri = 2, 5 do refreshRingButton(ri) end
    allRingsBtn.Text = ns and "⭕ Все кольца (2-5): ВЫКЛ" or "⭕ Все кольца (2-5): ВКЛ"
end)
for ri, btn in pairs(ringButtons) do
    btn.Activated:Connect(function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

-- ===== ВНЕШНИЙ ВИД =====
shapeCatBtn.Activated:Connect(function()
    P.shapeCategoryIndex = P.shapeCategoryIndex + 1
    if P.shapeCategoryIndex > #P.SHAPE_CATEGORIES then P.shapeCategoryIndex = 1 end
    shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs > 0 then
        ORBIT.shapeIndex = idxs[1]
        shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.applyShapes(); ORBIT.rebuildAllRings()
    end
end)
shapeBtn.Activated:Connect(function()
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs == 0 then return end
    local pos = nil
    for i, v in ipairs(idxs) do if v == ORBIT.shapeIndex then pos = i; break end end
    local newPos = pos and (pos % #idxs) + 1 or 1
    ORBIT.shapeIndex = idxs[newPos]
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
shapeModeBtn.Activated:Connect(function()
    P.formModeIndex = P.formModeIndex + 1; if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
shapeSizeBtn.Activated:Connect(function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1; if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    ORBIT.rebuildAllRings()
end)
autoSwapBtn.Activated:Connect(function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "🎭 Автосмена формы: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then ORBIT.lastAutoSwap = tick() end
end)
colorBtn.Activated:Connect(function()
    P.colorIndex = P.colorIndex + 1; if P.colorIndex > #P.COLORS then P.colorIndex = 1 end
    ORBIT.applyColor()
    colorBtn.Text = "🎨 Цвет: " .. P.COLORS[P.colorIndex].name
end)
gradientBtn.Activated:Connect(function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    gradientBtn.Text = "🌈 Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then SETTINGS.Rainbow = false end
    ORBIT.rebuildAllRings()
end)
lightBtn.Activated:Connect(function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
nameBtn.Activated:Connect(function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "🏷️ Имена блоков: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    ORBIT.applyNameVisibility()
end)

-- ===== ОРБИТА =====
orbitBtn.Activated:Connect(function()
    P.orbitIndex = P.orbitIndex + 1; if P.orbitIndex > #P.ORBIT then P.orbitIndex = 1 end
    orbitBtn.Text = "📏 Размер орбиты: " .. P.ORBIT[P.orbitIndex].name
end)
spreadBtn.Activated:Connect(function()
    P.spreadIndex = P.spreadIndex + 1; if P.spreadIndex > #P.SPREAD then P.spreadIndex = 1 end
    spreadBtn.Text = "📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name
end)
heightBtn.Activated:Connect(function()
    P.heightIndex = P.heightIndex + 1; if P.heightIndex > #P.HEIGHT then P.heightIndex = 1 end
    heightBtn.Text = "⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name
end)
speedBtn.Activated:Connect(function()
    P.speedIndex = P.speedIndex + 1; if P.speedIndex > #P.SPEED then P.speedIndex = 1 end
    SETTINGS.SpeedMultiplier = P.SPEED[P.speedIndex].value
    speedBtn.Text = "⚡ Скорость: " .. P.SPEED[P.speedIndex].name
end)
speedModeBtn.Activated:Connect(function()
    P.speedModeIndex = P.speedModeIndex + 1; if P.speedModeIndex > #P.SPEED_MODE then P.speedModeIndex = 1 end
    speedModeBtn.Text = "⚙️ Режим скорости: " .. P.SPEED_MODE[P.speedModeIndex].name
    ORBIT.applySpeedModePreset()
end)
directionBtn.Activated:Connect(function()
    P.directionIndex = P.directionIndex + 1; if P.directionIndex > #P.DIRECTION then P.directionIndex = 1 end
    directionBtn.Text = "🔃 Направление: " .. P.DIRECTION[P.directionIndex].name
    ORBIT.applyDirectionPreset()
end)
patternBtn.Activated:Connect(function()
    P.orbitPatternIndex = P.orbitPatternIndex + 1; if P.orbitPatternIndex > #P.ORBIT_PATTERNS then P.orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name
    patternBtn.Text = "🌀 Узор: " .. SETTINGS.OrbitPattern
end)

-- ===== КРУЧЕНИЕ =====
spinBtn.Activated:Connect(function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    spinBtn.Text = ORBIT.spinResetting and "↩️ Вращение: ВОЗВРАТ" or "↩️ Вернуть вращение в 0"
end)
spinAxisBtn.Activated:Connect(function()
    ORBIT.spinAxisEnabled = not ORBIT.spinAxisEnabled
    spinAxisBtn.Text = "🔄 Кручение оси: " .. (ORBIT.spinAxisEnabled and "ВКЛ" or "ВЫКЛ")
end)
spinDirBtn.Activated:Connect(function()
    if ORBIT.spinAxisDir == "X" then ORBIT.spinAxisDir = "Y"; spinDirBtn.Text = "↔️ Ось: ВЛЕВО/ВПРАВО"
    else ORBIT.spinAxisDir = "X"; spinDirBtn.Text = "↕️ Ось: ВЕРХ/ВНИЗ" end
end)
spinSpeedBtn.Activated:Connect(function()
    P.spinSpeedIndex = P.spinSpeedIndex + 1; if P.spinSpeedIndex > #P.SPIN_SPEED then P.spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value
    spinSpeedBtn.Text = "🌀 Скорость вращения: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

-- ===== ЭФФЕКТЫ =====
trailBtn.Activated:Connect(function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
trailLenBtn.Activated:Connect(function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    trailLenBtn.Text = "📏 Длина трейла: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
trailWidBtn.Activated:Connect(function()
    P.trailWidthIndex = P.trailWidthIndex + 1; if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    trailWidBtn.Text = "🎚️ Толщина трейла: " .. P.TRAIL_WID[P.trailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
waveBtn.Activated:Connect(function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    waveBtn.Text = "🌊 Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
end)
explosionBtn.Activated:Connect(function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    explosionBtn.Text = "💥 Пульс размера: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
end)
pulseBtn.Activated:Connect(function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    pulseBtn.Text = "💓 Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- ===== ОГОНЬ =====
fireBtn.Activated:Connect(function()
    SETTINGS.FireEnabled = not SETTINGS.FireEnabled
    fireBtn.Text = "🔥 Огонь: " .. (SETTINGS.FireEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupFire()
end)
fireSizeBtn.Activated:Connect(function()
    P.fireSizeIndex = P.fireSizeIndex + 1; if P.fireSizeIndex > #P.FIRE_SIZE then P.fireSizeIndex = 1 end
    SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value
    fireSizeBtn.Text = "📏 Размер огня: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)
fireHeatBtn.Activated:Connect(function()
    P.fireHeatIndex = P.fireHeatIndex + 1; if P.fireHeatIndex > #P.FIRE_HEAT then P.fireHeatIndex = 1 end
    SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value
    fireHeatBtn.Text = "🌡️ Жар огня: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)

-- ===== АУРА =====
auraBtn.Activated:Connect(function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    auraBtn.Text = "🌀 Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura()
    else if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end end
end)
auraRingBtn.Activated:Connect(function()
    SETTINGS.AuraRing = not SETTINGS.AuraRing
    auraRingBtn.Text = "⭕ Кольцо ауры: " .. (SETTINGS.AuraRing and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraPartBtn.Activated:Connect(function()
    SETTINGS.AuraParticles = not SETTINGS.AuraParticles
    auraPartBtn.Text = "✨ Частицы: " .. (SETTINGS.AuraParticles and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraFigBtn.Activated:Connect(function()
    SETTINGS.AuraShapes = not SETTINGS.AuraShapes
    auraFigBtn.Text = "🔷 Фигуры ауры: " .. (SETTINGS.AuraShapes and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraShapeBtn.Activated:Connect(function()
    ORBIT.auraShapeIndex = ORBIT.auraShapeIndex + 1
    if ORBIT.auraShapeIndex > #SHAPE_PRESETS then ORBIT.auraShapeIndex = 1 end
    auraShapeBtn.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraColorBtn.Activated:Connect(function()
    P.auraColorIndex = P.auraColorIndex + 1
    if P.auraColorIndex > #P.COLORS then P.auraColorIndex = 1 end
    local ac = P.COLORS[P.auraColorIndex]
    if ac.c then SETTINGS.AuraColor = ac.c end
    auraColorBtn.Text = "🎨 Цвет ауры: " .. ac.name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)

auraSizeBtn.Activated:Connect(function()
    P.auraSizeIndex = P.auraSizeIndex + 1; if P.auraSizeIndex > #P.AURA_SIZE then P.auraSizeIndex = 1 end
    SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value
    auraSizeBtn.Text = "Размер кольца: " .. P.AURA_SIZE[P.auraSizeIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraThickBtn.Activated:Connect(function()
    P.auraThickIndex = P.auraThickIndex + 1; if P.auraThickIndex > #P.AURA_THICK then P.auraThickIndex = 1 end
    SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value
    auraThickBtn.Text = "Толщина кольца: " .. P.AURA_THICK[P.auraThickIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraHeightBtn.Activated:Connect(function()
    P.auraHeightIndex = P.auraHeightIndex + 1; if P.auraHeightIndex > #P.AURA_HEIGHT then P.auraHeightIndex = 1 end
    SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value
    auraHeightBtn.Text = "Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
end)
auraScaleBtn.Activated:Connect(function()
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1
    if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
    SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor
    auraScaleBtn.Text = "Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraSpeedBtn.Activated:Connect(function()
    P.auraSpeedIndex = P.auraSpeedIndex + 1; if P.auraSpeedIndex > #P.AURA_SPEED then P.auraSpeedIndex = 1 end
    SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value
    auraSpeedBtn.Text = "Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
end)
auraDirBtn.Activated:Connect(function()
    P.auraDirIndex = P.auraDirIndex + 1; if P.auraDirIndex > #P.AURA_DIR then P.auraDirIndex = 1 end
    SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value
    auraDirBtn.Text = "Направление: " .. P.AURA_DIR[P.auraDirIndex].name
end)
auraSpinBtn.Activated:Connect(function()
    SETTINGS.AuraSpinEnabled = not SETTINGS.AuraSpinEnabled
    auraSpinBtn.Text = "Кручение: " .. (SETTINGS.AuraSpinEnabled and "ВКЛ" or "ВЫКЛ")
end)
auraSpinAxisBtn.Activated:Connect(function()
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1
    if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    auraSpinAxisBtn.Text = "Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
auraSpinSpeedBtn.Activated:Connect(function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1
    if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    auraSpinSpeedBtn.Text = "Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
end)
auraSpinResetBtn.Activated:Connect(function()
    ORBIT.auraSpinAngle = 0
    ORBIT.notify("↩️ Сброс вращения ауры", Color3.fromRGB(200,180,255))
end)
auraTrailBtn.Activated:Connect(function()
    SETTINGS.AuraTrailEnabled = not SETTINGS.AuraTrailEnabled
    auraTrailBtn.Text = "Трейлы ауры: " .. (SETTINGS.AuraTrailEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraTrailLenBtn.Activated:Connect(function()
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1
    if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    auraTrailLenBtn.Text = "Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
end)
auraTrailWidBtn.Activated:Connect(function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1
    if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    auraTrailWidBtn.Text = "Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
end)

-- ===== ЗАЩИТА =====
protBtn.Activated:Connect(function()
    SETTINGS.ProtEnabled = not SETTINGS.ProtEnabled
    protBtn.Text = "🛡️ Защита: " .. (SETTINGS.ProtEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.ProtEnabled then ORBIT.enableProtection()
    else ORBIT.disableProtection() end
end)
antiKbBtn.Activated:Connect(function()
    SETTINGS.AntiKnockback = not SETTINGS.AntiKnockback
    antiKbBtn.Text = "Anti-Knockback: " .. (SETTINGS.AntiKnockback and "ВКЛ" or "ВЫКЛ")
end)
antiTpBtn.Activated:Connect(function()
    SETTINGS.AntiTeleport = not SETTINGS.AntiTeleport
    antiTpBtn.Text = "Anti-Teleport: " .. (SETTINGS.AntiTeleport and "ВКЛ" or "ВЫКЛ")
end)
antiFrzBtn.Activated:Connect(function()
    SETTINGS.AntiFreeze = not SETTINGS.AntiFreeze
    antiFrzBtn.Text = "Anti-Freeze: " .. (SETTINGS.AntiFreeze and "ВКЛ" or "ВЫКЛ")
end)
antiFlingBtn.Activated:Connect(function()
    SETTINGS.AntiFling = not SETTINGS.AntiFling
    antiFlingBtn.Text = "Anti-Fling/Spin: " .. (SETTINGS.AntiFling and "ВКЛ" or "ВЫКЛ")
end)
autoHealBtn.Activated:Connect(function()
    SETTINGS.AutoHeal = not SETTINGS.AutoHeal
    autoHealBtn.Text = "Auto-Heal: " .. (SETTINGS.AutoHeal and "ВКЛ" or "ВЫКЛ")
end)
antiVoidBtn.Activated:Connect(function()
    SETTINGS.AntiVoid = not SETTINGS.AntiVoid
    antiVoidBtn.Text = "Anti-Void: " .. (SETTINGS.AntiVoid and "ВКЛ" or "ВЫКЛ")
end)
lockPosBtn.Activated:Connect(function()
    SETTINGS.LockPosition = not SETTINGS.LockPosition
    lockPosBtn.Text = "Lock Position: " .. (SETTINGS.LockPosition and "ВКЛ" or "ВЫКЛ")
end)

-- ===== МЕТКИ =====
tagNearestBtn.Activated:Connect(function()
    local closest, bestDist = nil, math.huge
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - myHrp.Position).Magnitude
                if d < bestDist then closest, bestDist = p, d end
            end
        end
    end
    if closest and ORBIT.toggleTagCheater then
        ORBIT.toggleTagCheater(closest)
        task.wait(0.1); pcall(rebuildPeopleList)
    end
end)
clearTagsBtn.Activated:Connect(function()
    if ORBIT.clearAllTags then ORBIT.clearAllTags() end
    task.wait(0.1); pcall(rebuildPeopleList)
end)

-- ===== МАГАЗИН =====
openShopBtn.Activated:Connect(function()
    if ORBIT.openShop then ORBIT.openShop() end
end)
openEditorBtn.Activated:Connect(function()
    if ORBIT.openEditor then ORBIT.openEditor() end
end)

-- ===== ПРОИЗВОДИТЕЛЬНОСТЬ =====
local PERF_MODES = {"auto", "high", "medium", "low", "minimal", "off"}
local PERF_LABELS = {auto="АВТО", high="ВЫСОКОЕ", medium="СРЕДНЕЕ", low="НИЗКОЕ", minimal="МИНИМУМ", off="ВЫКЛ"}
local perfIndex = 1
local function refreshPerfBtn()
    local info = ORBIT.getPerformanceInfo and ORBIT.getPerformanceInfo() or {Mode="auto", Current="high", FPS=60}
    perfBtn.Text = string.format("⚡ Качество: %s (FPS: %d)", PERF_LABELS[info.Mode] or info.Mode, info.FPS)
end
refreshPerfBtn()
perfBtn.Activated:Connect(function()
    perfIndex = perfIndex + 1
    if perfIndex > #PERF_MODES then perfIndex = 1 end
    local mode = PERF_MODES[perfIndex]
    if ORBIT.setPerformanceMode then ORBIT.setPerformanceMode(mode) end
    refreshPerfBtn()
end)
task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(1)
        pcall(refreshPerfBtn)
    end
end)

-- ===== СЕРДЦЕ =====
local heartScaleIndex = 4
local HEART_STEPS = P.HEART_STEPS or {0.2, 0.35, 0.5, 0.65, 0.9, 1.2, 1.6, 2.2}
for i, v in ipairs(HEART_STEPS) do
    if math.abs(v - SETTINGS.HeartScale) < 0.01 then heartScaleIndex = i; break end
end
local function refreshHeartBtn()
    local pct = math.floor(SETTINGS.HeartScale / 0.65 * 100 + 0.5)
    heartSizeBtn.Text = "💗 Размер сердца: " .. pct .. "%"
end
refreshHeartBtn()
heartSizeBtn.Activated:Connect(function()
    heartScaleIndex = heartScaleIndex + 1
    if heartScaleIndex > #HEART_STEPS then heartScaleIndex = 1 end
    SETTINGS.HeartScale = HEART_STEPS[heartScaleIndex]
    refreshHeartBtn()
    ORBIT.rebuildAllRings()
end)

-- ===== СОХРАНЕНИЯ =====
local function rebuildSavesList()
    for _, child in ipairs(savesContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
    end
    local names = ORBIT.getSaveNames()
    if #names == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 28)
        empty.BackgroundTransparency = 1
        empty.Text = "— нет сохранений —"
        empty.TextColor3 = Color3.fromRGB(140,140,170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.LayoutOrder = 1
        empty.Parent = savesContainer
        return
    end
    for i, name in ipairs(names) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = savesContainer
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -130, 1, 0)
        nameLbl.Position = UDim2.new(0, 8, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = "💾 " .. name
        nameLbl.TextColor3 = Color3.fromRGB(220,220,255)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local loadB = Instance.new("TextButton")
        loadB.Size = UDim2.new(0, 55, 0, 24)
        loadB.Position = UDim2.new(1, -120, 0, 4)
        loadB.BackgroundColor3 = Color3.fromRGB(40,80,50)
        loadB.TextColor3 = Color3.fromRGB(160,255,180)
        loadB.Font = Enum.Font.GothamBold
        loadB.TextSize = 10
        loadB.Text = "ЗАГР"
        loadB.Parent = row
        Instance.new("UICorner", loadB).CornerRadius = UDim.new(0, 5)

        local delB = Instance.new("TextButton")
        delB.Size = UDim2.new(0, 55, 0, 24)
        delB.Position = UDim2.new(1, -60, 0, 4)
        delB.BackgroundColor3 = Color3.fromRGB(80,30,30)
        delB.TextColor3 = Color3.fromRGB(255,150,150)
        delB.Font = Enum.Font.GothamBold
        delB.TextSize = 10
        delB.Text = "УДАЛ"
        delB.Parent = row
        Instance.new("UICorner", delB).CornerRadius = UDim.new(0, 5)

        loadB.Activated:Connect(function()
            local ok = ORBIT.loadNamed(name)
            if ok then
                ORBIT.notify("💾 Загружено: " .. name, Color3.fromRGB(160,255,180))
                ORBIT.rebuildAllRings()
                if ORBIT.setupAura then ORBIT.setupAura() end
                if ORBIT.setupFire then ORBIT.setupFire() end
                if SETTINGS.ProtEnabled and ORBIT.enableProtection then ORBIT.enableProtection() end
                refreshHeartBtn()
                botSkinBtn.Text = "👤 Скин как у меня: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ")
            end
        end)
        delB.Activated:Connect(function()
            local ok = ORBIT.deleteNamed(name)
            if ok then
                ORBIT.notify("🗑 Удалено: " .. name, Color3.fromRGB(255,150,150))
                rebuildSavesList()
            end
        end)
    end
end

createSaveBtn.Activated:Connect(function()
    local name = saveNameInput.Text
    if not name or name == "" then
        ORBIT.notify("✏️ Введи имя сохранения", Color3.fromRGB(255,200,100))
        return
    end
    local ok, err = ORBIT.saveNamed(name)
    if ok then
        ORBIT.notify("💾 Сохранено: " .. name, Color3.fromRGB(160,255,180))
        saveNameInput.Text = ""
        rebuildSavesList()
    else
        ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255,100,100))
    end
end)

saveBtn.Activated:Connect(function()
    if musicInput.Text ~= "" then ORBIT.setMusicId(musicInput.Text) end
    local ok = ORBIT.saveSettings()
    if ok then
        saveBtn.Text = "✅ Сохранено!"
        task.wait(1.5)
        saveBtn.Text = "💾 Сохранить (автослот)"
    end
end)
loadBtn.Activated:Connect(function()
    if ORBIT.loadSettings() then
        ORBIT.notify("📂 Загружено из автослота", Color3.fromRGB(180,220,255))
        ORBIT.rebuildAllRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupFire then ORBIT.setupFire() end
        if SETTINGS.ProtEnabled and ORBIT.enableProtection then ORBIT.enableProtection() end
        refreshHeartBtn()
        botSkinBtn.Text = "👤 Скин как у меня: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ")
    end
end)
resetBtn.Activated:Connect(function()
    for k, v in pairs(ORBIT.DEFAULT_SETTINGS) do SETTINGS[k] = v end
    ORBIT.shapeIndex = 1
    ORBIT.auraShapeIndex = 1
    P.colorIndex = 1
    P.auraColorIndex = 1
    P.shapeCategoryIndex = 1
    P.orbitPatternIndex = 1
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[1].name
    ORBIT.rebuildAllRings()
    if ORBIT.setupAura then ORBIT.setupAura() end
    if ORBIT.setupFire then ORBIT.setupFire() end
    ORBIT.notify("🔄 Сброс выполнен", Color3.fromRGB(255,180,180))
end)
unloadBtn.Activated:Connect(function()
    pcall(function() ORBIT.unload() end)
end)

-- ===== МУЗЫКА =====
applyIdBtn.Activated:Connect(function()
    local ok = ORBIT.setMusicId(musicInput.Text)
    if ok then
        applyIdBtn.Text = "✅ Готово!"
        task.wait(1.2)
        applyIdBtn.Text = "✅ Применить ID"
    else
        applyIdBtn.Text = "❌ Ошибка"
        task.wait(1.5)
        applyIdBtn.Text = "✅ Применить ID"
    end
end)
musicBtn.Activated:Connect(function()
    local s = ORBIT.musicSound and tostring(ORBIT.musicSound.SoundId or "") or ""
    if not ORBIT.musicSound or s == "" or s == "rbxassetid://" then
        musicBtn.Text = "❌ Сначала вставь ID!"
        task.wait(1.2)
        musicBtn.Text = "🎵 Музыка: " .. (ORBIT.musicEnabled and "ВКЛ" or "ВЫКЛ")
        return
    end
    ORBIT.musicEnabled = not ORBIT.musicEnabled
    if ORBIT.musicEnabled then
        ORBIT.musicSound:Play()
        musicBtn.Text = "🎵 Музыка: ВКЛ"
    else
        ORBIT.musicSound:Stop()
        musicBtn.Text = "🎵 Музыка: ВЫКЛ"
    end
end)

rebuildSavesList()

-- ===== СТАТИСТИКА =====
task.spawn(function()
    while task.wait(0.5) do
        if statsLabel and statsLabel.Parent then
            local m = math.floor(statsData.sessionTime / 60)
            local s = math.floor(statsData.sessionTime % 60)
            local bots = 0
            for _ in pairs(ORBIT.bots) do bots = bots + 1 end
            local ringTargets = 0
            for _ in pairs(ORBIT.targetRings) do ringTargets = ringTargets + 1 end
            local players = #Players:GetPlayers()
            statsLabel.Text = string.format(
                "📊 FPS: %d  |  🔷 Фигур: %d\n⏱️ Время: %d:%02d\n🤖 Ботов: %d  |  🎯 Колец у людей: %d\n👥 Всего игроков: %d",
                statsData.lastFPS, statsData.totalShapes, m, s, bots, ringTargets, players
            )
        end
    end
end)

-- ===== ПЕРЕТАСКИВАНИЕ =====
local dragging, dragStart, startPos = false, nil, nil
mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = mainBtn.Position
    end
end)
mainBtn.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        mainBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
mainBtn.InputEnded:Connect(function() dragging = false end)

-- ===== ССЫЛКИ ДЛЯ МАГАЗИНА =====
ORBIT.ui = ORBIT.ui or {}
ORBIT.ui.screenGui = screenGui
ORBIT.ui.panel = panel
ORBIT.ui.openShopBtn = openShopBtn
ORBIT.ui.openEditorBtn = openEditorBtn

-- ===== СТАРТ =====
ORBIT.start = function()
    if getgenv()._OrbitLoaderGui then pcall(function() getgenv()._OrbitLoaderGui:Destroy() end) end
    ORBIT.startLogic()
    ORBIT.notify("✨ ОРБИТА v21.2 запущена!", Color3.fromRGB(200,200,255), 3)
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ P4 v21.2 (часть 1/2) — интерфейс готов", Color3.fromRGB(180,255,180), 3) end

-- ============================================================
-- ПОДГРУЗКА ЧАСТИ 2/2 — МАГАЗИН
-- ============================================================
task.spawn(function()
    local url = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_p4_shop.lua?t=" .. os.time()
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if ok and type(src) == "string" and #src > 100 then
        local fn, err = loadstring(src)
        if fn then
            local runOk, runErr = pcall(fn)
            if not runOk then warn("[Orbit P4 Shop] Runtime error: " .. tostring(runErr)) end
        else
            warn("[Orbit P4 Shop] Compile error: " .. tostring(err))
        end
    end
end)

return true
