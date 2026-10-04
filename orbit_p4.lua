--[[ ОРБИТА v23.3 — P4: UI
     🆕 Кнопка «Свет ауры» в разделе Ауры
     🆕 Раздел «Графика» — материалы и яркость
     🆕 50 цветов
     🆕 FPS-панель сверху
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P4] Часть 1 не загружена!"); return end

local Players      = ORBIT.Players
local LocalPlayer  = ORBIT.LocalPlayer
local PlayerGui    = ORBIT.PlayerGui
local TweenService = ORBIT.TweenService
local UIS          = ORBIT.UIS or game:GetService("UserInputService")

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local rings    = ORBIT.rings
local statsData = ORBIT.statsData
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS
if not P then warn("[Orbit P4] P не передан"); return end
if not SHAPE_PRESETS then warn("[Orbit P4] Часть 2 не загружена"); return end
if not ORBIT.startUpdateLoop then warn("[Orbit P4] Часть 3 не загружена"); return end
if not ORBIT.createBot then warn("[Orbit P4] Боты не найдены в p3!"); return end

local PLATFORM = ORBIT.PLATFORM or "pc"
local IS_MOBILE = (PLATFORM == "mobile")

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

-- ==================== FPS ПАНЕЛЬ ====================
local topBar = Instance.new("Frame")
topBar.Name = "_OrbitTopBar"
topBar.Size = UDim2.new(0, 360, 0, 26)
topBar.Position = UDim2.new(0.5, -180, 0, 4)
topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.ZIndex = 5
topBar.Parent = screenGui
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
local topBarStroke = Instance.new("UIStroke", topBar)
topBarStroke.Color = Color3.fromRGB(120, 120, 255)
topBarStroke.Thickness = 1
topBarStroke.Transparency = 0.4

local topBarLabel = Instance.new("TextLabel")
topBarLabel.Size = UDim2.new(1, -12, 1, 0)
topBarLabel.Position = UDim2.new(0, 6, 0, 0)
topBarLabel.BackgroundTransparency = 1
topBarLabel.Text = "ОРБИТА v23.3  |  FPS: --  |  БОТЫ: 0  |  КОЛЬЦА: 0"
topBarLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
topBarLabel.Font = Enum.Font.GothamBold
topBarLabel.TextSize = 12
topBarLabel.TextXAlignment = Enum.TextXAlignment.Center
topBarLabel.ZIndex = 6
topBarLabel.Parent = topBar

-- ==================== КНОПКА ====================
local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, IS_MOBILE and 60 or 56, 0, IS_MOBILE and 60 or 56)
mainBtn.Position = UDim2.new(0, 20, 0, 100)
mainBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainBtn.BackgroundTransparency = 0.1
mainBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = IS_MOBILE and 26 or 24
mainBtn.Text = "О"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke", mainBtn)
mainStroke.Color = Color3.fromRGB(120, 120, 255)
mainStroke.Thickness = 1.5

-- ==================== ПАНЕЛЬ ====================
local PANEL_W = IS_MOBILE and 300 or 320
local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, PANEL_W, 0, 720)
panel.Position = UDim2.new(0, 90, 0, 5)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 7000)
panel.ScrollBarThickness = 4
panel.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(120, 120, 255)
panelStroke.Thickness = 1

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "ОРБИТА v23.3" .. (IS_MOBILE and " [ТЕЛ]" or " [ПК]")
title.TextColor3 = Color3.fromRGB(220, 210, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.ZIndex = 2
title.Parent = panel

-- ==================== ХЕЛПЕРЫ ====================
local BTN_H = IS_MOBILE and 34 or 30
local BTN_H_BIG = IS_MOBILE and 38 or 34

local function makeBigSection(text, y, color)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -20, 0, 26)
    holder.Position = UDim2.new(0, 10, 0, y)
    holder.BackgroundColor3 = color or Color3.fromRGB(55, 55, 90)
    holder.BackgroundTransparency = 0.35
    holder.BorderSizePixel = 0
    holder.ZIndex = 2
    holder.Parent = panel
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)
    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 4, 1, -6)
    stripe.Position = UDim2.new(0, 3, 0, 3)
    stripe.BackgroundColor3 = color or Color3.fromRGB(140, 140, 220)
    stripe.BorderSizePixel = 0
    stripe.ZIndex = 3
    stripe.Parent = holder
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 2)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -14, 1, 0)
    s.Position = UDim2.new(0, 12, 0, 0)
    s.BackgroundTransparency = 1
    s.Text = text
    s.TextColor3 = Color3.fromRGB(240, 240, 255)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 12
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.ZIndex = 3
    s.Parent = holder
    return holder
end

local function makeButton(text, y, h, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or BTN_H)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(45, 45, 62)
    b.TextColor3 = textColor or Color3.fromRGB(235, 235, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = IS_MOBILE and 12 or 11
    b.Text = text
    b.AutoButtonColor = true
    b.ZIndex = 2
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", b)
    stroke.Color = bgColor or Color3.fromRGB(80, 80, 120)
    stroke.Thickness = 1
    stroke.Transparency = 0.65
    b.MouseButton1Down:Connect(function()
        if ORBIT.playClick then ORBIT.playClick() end
    end)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            if ORBIT.playClick then ORBIT.playClick() end
        end
    end)
    return b
end

-- ============ ОСНОВНОЕ ============
local yCursor = 40
local S_STEP = 4

makeBigSection("ОСНОВНОЕ", yCursor, Color3.fromRGB(60, 60, 100)); yCursor = yCursor + 30
local toggleBtn     = makeButton("ВКЛЮЧЕНО", yCursor, BTN_H_BIG, Color3.fromRGB(40,50,40), Color3.fromRGB(0,255,120)); yCursor = yCursor + BTN_H_BIG + S_STEP
local allRingsBtn   = makeButton("Все кольца: ВКЛ", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring2Btn      = makeButton("Кольцо 2", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring3Btn      = makeButton("Кольцо 3", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring4Btn      = makeButton("Кольцо 4", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring5Btn      = makeButton("Кольцо 5", yCursor); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ БОТЫ ============
makeBigSection("БОТЫ - ФАРМ КОЛЕЦ", yCursor, Color3.fromRGB(110, 70, 150)); yCursor = yCursor + 30
local botCreateNearBtn = makeButton("Создать бота РЯДОМ", yCursor, BTN_H_BIG, Color3.fromRGB(45,80,65), Color3.fromRGB(170,255,200)); yCursor = yCursor + BTN_H_BIG + S_STEP
local botCreate5Btn    = makeButton("Создать 5 ботов", yCursor, BTN_H, Color3.fromRGB(65,40,90), Color3.fromRGB(225,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botCreate25Btn   = makeButton("Создать 25 ботов", yCursor, BTN_H, Color3.fromRGB(85,45,110), Color3.fromRGB(235,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botCreate100Btn  = makeButton("Создать 100 ботов", yCursor, BTN_H, Color3.fromRGB(105,55,130), Color3.fromRGB(245,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botRemoveAll     = makeButton("Удалить всех ботов", yCursor, BTN_H, Color3.fromRGB(80,30,30), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP
local botAutoCollectBtn = makeButton("Автосбор: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
local botRadiusBtn      = makeButton("Радиус сбора: 12 st", yCursor, BTN_H, Color3.fromRGB(35,50,65), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local botShowPlayerRing = makeButton("Кольцо как у игрока: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,45,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botSkinBtnEnd     = makeButton("Скин как у меня: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,45,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP

local botInfoLbl = Instance.new("TextLabel")
botInfoLbl.Size = UDim2.new(1, -20, 0, 22)
botInfoLbl.Position = UDim2.new(0, 10, 0, yCursor)
botInfoLbl.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
botInfoLbl.BackgroundTransparency = 0.3
botInfoLbl.BorderSizePixel = 0
botInfoLbl.Text = "Ботов: 0"
botInfoLbl.TextColor3 = Color3.fromRGB(210, 210, 255)
botInfoLbl.Font = Enum.Font.GothamBold
botInfoLbl.TextSize = 11
botInfoLbl.ZIndex = 2
botInfoLbl.Parent = panel
Instance.new("UICorner", botInfoLbl).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 26 + 6

-- ============ ESP И МЕТКИ ============
makeBigSection("ESP И МЕТКИ", yCursor, Color3.fromRGB(80, 60, 130)); yCursor = yCursor + 30
local espBtn        = makeButton("ESP игроков: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local taggedCount   = makeButton("Список читеров: 0", yCursor, BTN_H, Color3.fromRGB(70,40,60), Color3.fromRGB(255,180,220)); yCursor = yCursor + BTN_H + S_STEP
local tagNearestBtn = makeButton("Пометить ближайшего", yCursor, BTN_H, Color3.fromRGB(80,30,55), Color3.fromRGB(255,150,200)); yCursor = yCursor + BTN_H + S_STEP
local clearTagsBtn  = makeButton("Снять все метки", yCursor, BTN_H, Color3.fromRGB(50,35,45), Color3.fromRGB(255,180,200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ВНЕШНИЙ ВИД ============
makeBigSection("ВНЕШНИЙ ВИД КОЛЕЦ", yCursor, Color3.fromRGB(60, 100, 120)); yCursor = yCursor + 30
local shapeCatBtn   = makeButton("Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, yCursor, BTN_H, Color3.fromRGB(60,50,80), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
local shapeBtn      = makeButton("Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local shapeModeBtn  = makeButton("Режим: " .. P.FORM_MODES[P.formModeIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
local shapeSizeBtn  = makeButton("Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local colorBtn      = makeButton("Цвет: " .. P.COLORS[P.colorIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local gradientBtn   = makeButton("Градиент: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(255,180,255)); yCursor = yCursor + BTN_H + S_STEP
local lightBtn      = makeButton("Свет колец: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160)); yCursor = yCursor + BTN_H + S_STEP
local nameBtn       = makeButton("Имена блоков: ВЫКЛ", yCursor); yCursor = yCursor + BTN_H + S_STEP
local autoSwapBtn   = makeButton("Автосмена: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ДВИЖЕНИЕ ============
makeBigSection("ДВИЖЕНИЕ И ОРБИТА", yCursor, Color3.fromRGB(60, 100, 80)); yCursor = yCursor + 30
local orbitBtn        = makeButton("Орбита: " .. P.ORBIT[P.orbitIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local spreadBtn       = makeButton("Разлёт: " .. P.SPREAD[P.spreadIndex].name, yCursor, BTN_H, Color3.fromRGB(55,30,55), Color3.fromRGB(255,180,255)); yCursor = yCursor + BTN_H + S_STEP
local heightBtn       = makeButton("Высота: " .. P.HEIGHT[P.heightIndex].name, yCursor, BTN_H, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255)); yCursor = yCursor + BTN_H + S_STEP
local speedBtn        = makeButton("Множитель: " .. P.SPEED[P.speedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100)); yCursor = yCursor + BTN_H + S_STEP
local speedModeBtn    = makeButton("Режим: " .. P.SPEED_MODE[P.speedModeIndex].name, yCursor, BTN_H, Color3.fromRGB(45,50,65), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local directionBtn    = makeButton("Направление: " .. P.DIRECTION[P.directionIndex].name, yCursor, BTN_H, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local orbitPatternBtn = makeButton("Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,90), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ КРУЧЕНИЕ ============
makeBigSection("КРУЧЕНИЕ", yCursor, Color3.fromRGB(100, 60, 80)); yCursor = yCursor + 30
local spinBtn       = makeButton("Вращение в 0", yCursor, BTN_H, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local spinAxisBtn   = makeButton("Кручение оси: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220)); yCursor = yCursor + BTN_H + S_STEP
local spinDirBtn    = makeButton("Ось: ВЕРХ/ВНИЗ", yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local spinSpeedBtn  = makeButton("Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ЭФФЕКТЫ ============
makeBigSection("ЭФФЕКТЫ КОЛЕЦ", yCursor, Color3.fromRGB(100, 80, 60)); yCursor = yCursor + 30
local trailBtn      = makeButton("Трейлы: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
local trailLenBtn   = makeButton("Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local trailWidBtn   = makeButton("Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local waveBtn       = makeButton("Волна: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(30,55,75), Color3.fromRGB(140,220,255)); yCursor = yCursor + BTN_H + S_STEP
local explosionBtn  = makeButton("Взрыв: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(70,40,30), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP
local pulseBtn      = makeButton("Пульсация: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ АУРА ============
makeBigSection("АУРА", yCursor, Color3.fromRGB(80, 60, 130)); yCursor = yCursor + 30
local auraBtn       = makeButton("Аура: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local auraRingBtn   = makeButton("Кольцо: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,35), Color3.fromRGB(160,255,160)); yCursor = yCursor + BTN_H + S_STEP
local auraPartBtn   = makeButton("Частицы: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,55), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local auraFigBtn    = makeButton("Фигуры: ВКЛ", yCursor, BTN_H, Color3.fromRGB(45,35,65), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP

local auraShapeBtn  = makeButton("Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraColorBtn  = makeButton("Цвет ауры: " .. P.COLORS[P.auraColorIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP

local auraSizeBtn   = makeButton("Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraThickBtn  = makeButton("Толщина: " .. P.AURA_THICK[P.auraThickIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraHeightBtn = makeButton("Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraShapeScaleBtn = makeButton("Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, yCursor, BTN_H, Color3.fromRGB(60,45,85), Color3.fromRGB(220,190,255)); yCursor = yCursor + BTN_H + S_STEP

local auraPatternBtn = makeButton("Узор ауры: " .. P.AURA_PATTERNS[P.auraPatternIndex].name, yCursor, BTN_H, Color3.fromRGB(65,45,95), Color3.fromRGB(230,190,255)); yCursor = yCursor + BTN_H + S_STEP

local auraSpeedBtn  = makeButton("Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100)); yCursor = yCursor + BTN_H + S_STEP
local auraDirBtn    = makeButton("Направление: " .. P.AURA_DIR[P.auraDirIndex].name, yCursor, BTN_H, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP

local auraTrailBtn      = makeButton("Трейлы ауры: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
local auraTrailLenBtn   = makeButton("Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local auraTrailWidBtn   = makeButton("Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP

local auraSpinBtn       = makeButton("Кручение: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220)); yCursor = yCursor + BTN_H + S_STEP
local auraSpinAxisBtn   = makeButton("Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name, yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local auraSpinSpeedBtn  = makeButton("Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP

local auraPulseBtn      = makeButton("Пульсация ауры: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP

-- 🆕 КНОПКА СВЕТА АУРЫ
makeBigSection("СВЕТ АУРЫ", yCursor, Color3.fromRGB(140, 120, 60)); yCursor = yCursor + 30
local auraLightBtn      = makeButton("Свет ауры: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(70,60,30), Color3.fromRGB(255,230,140)); yCursor = yCursor + BTN_H_BIG + S_STEP
local auraLightRangeBtn = makeButton("Дальность: 8", yCursor, BTN_H, Color3.fromRGB(60,50,25), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP
local auraLightBrightBtn= makeButton("Яркость: 2", yCursor, BTN_H, Color3.fromRGB(60,50,25), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ГРАФИКА ============
makeBigSection("ГРАФИКА И МАТЕРИАЛЫ", yCursor, Color3.fromRGB(60, 100, 130)); yCursor = yCursor + 30
local materialBtn   = makeButton("Материал: NEON", yCursor, BTN_H_BIG, Color3.fromRGB(50,80,110), Color3.fromRGB(180,230,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local transparencyBtn = makeButton("Прозрачность: 10%", yCursor, BTN_H, Color3.fromRGB(60,70,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H + S_STEP
local brightnessBtn = makeButton("Яркость: 1", yCursor, BTN_H, Color3.fromRGB(70,60,30), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP
local glowBtn       = makeButton("Свечение: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,50), Color3.fromRGB(180,255,220)); yCursor = yCursor + BTN_H + S_STEP
local castShadowBtn = makeButton("Тени: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(45,45,65), Color3.fromRGB(200,200,220)); yCursor = yCursor + BTN_H + S_STEP
local qualityBtn    = makeButton("Качество графики: СРЕДНЕЕ", yCursor, BTN_H, Color3.fromRGB(60,45,90), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ОГОНЬ ============
makeBigSection("ОГОНЬ", yCursor, Color3.fromRGB(150, 60, 20)); yCursor = yCursor + 30
local fireBtn       = makeButton("Огонь: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(80,30,10), Color3.fromRGB(255,140,60)); yCursor = yCursor + BTN_H_BIG + S_STEP
local fireSizeBtn   = makeButton("Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name, yCursor, BTN_H, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP
local fireHeatBtn   = makeButton("Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name, yCursor, BTN_H, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ЗАЩИТА ============
makeBigSection("ЗАЩИТА", yCursor, Color3.fromRGB(60, 100, 60)); yCursor = yCursor + 30
local antichitLaunchBtn = makeButton("Запустить АНТИ-ЧИТ", yCursor, BTN_H_BIG, Color3.fromRGB(45,80,50), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H_BIG + S_STEP
local antichitStatusLbl = Instance.new("TextLabel")
antichitStatusLbl.Size = UDim2.new(1, -20, 0, 22)
antichitStatusLbl.Position = UDim2.new(0, 10, 0, yCursor)
antichitStatusLbl.BackgroundColor3 = Color3.fromRGB(25, 35, 25)
antichitStatusLbl.BackgroundTransparency = 0.3
antichitStatusLbl.BorderSizePixel = 0
antichitStatusLbl.Text = "Защита: не запущена"
antichitStatusLbl.TextColor3 = Color3.fromRGB(180, 220, 180)
antichitStatusLbl.Font = Enum.Font.GothamBold
antichitStatusLbl.TextSize = 11
antichitStatusLbl.ZIndex = 2
antichitStatusLbl.Parent = panel
Instance.new("UICorner", antichitStatusLbl).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 26 + 6

-- ============ ЛЮДИ И КОЛЬЦА ============
makeBigSection("ЛЮДИ И КОЛЬЦА (полное копирование)", yCursor, Color3.fromRGB(100, 50, 130)); yCursor = yCursor + 30
local addAllRingsBtn    = makeButton("Навесить ВСЁ всем игрокам", yCursor, BTN_H, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H + S_STEP
local remAllRingsBtn    = makeButton("Убрать у всех", yCursor, BTN_H, Color3.fromRGB(70,40,40), Color3.fromRGB(255,160,160)); yCursor = yCursor + BTN_H + S_STEP
local toggleAllRingsBtn = makeButton("Переключить всем", yCursor, BTN_H, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255)); yCursor = yCursor + BTN_H + S_STEP

local peopleListScroll = Instance.new("ScrollingFrame")
peopleListScroll.Size = UDim2.new(1, -20, 0, 200)
peopleListScroll.Position = UDim2.new(0, 10, 0, yCursor)
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
yCursor = yCursor + 206

local refreshPeopleBtn = makeButton("Обновить список игроков", yCursor, BTN_H, Color3.fromRGB(45,55,90), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ЗВУКИ ============
makeBigSection("ЗВУКИ", yCursor, Color3.fromRGB(70, 80, 110)); yCursor = yCursor + 30
local soundToggleBtn = makeButton("Звуки: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
local soundVolumeBtn = makeButton("Громкость: 100%", yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local soundTestBtn   = makeButton("Проверка звуков", yCursor, BTN_H_BIG, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H_BIG + S_STEP + 6

-- ============ МАГАЗИН ============
makeBigSection("МАГАЗИН / РЕДАКТОР / ИГРА", yCursor, Color3.fromRGB(110, 60, 150)); yCursor = yCursor + 30
local openShopBtn    = makeButton("Открыть МАГАЗИН", yCursor, BTN_H_BIG, Color3.fromRGB(90,50,130), Color3.fromRGB(255,210,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local openEditorBtn  = makeButton("Редактор 2D фигуры", yCursor, BTN_H, Color3.fromRGB(70,60,110), Color3.fromRGB(220,210,255)); yCursor = yCursor + BTN_H + S_STEP
local openGameBtn    = makeButton("МИНИ-ИГРА Ловля звёзд", yCursor, BTN_H_BIG, Color3.fromRGB(130,80,180), Color3.fromRGB(255,230,255)); yCursor = yCursor + BTN_H_BIG + S_STEP + 6

-- ============ ПРОИЗВОДИТЕЛЬНОСТЬ ============
makeBigSection("ПРОИЗВОДИТЕЛЬНОСТЬ", yCursor, Color3.fromRGB(60, 80, 110)); yCursor = yCursor + 30
local perfBtn = makeButton("Качество: АВТО", yCursor, BTN_H, Color3.fromRGB(35,50,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ СЕРДЦЕ ============
makeBigSection("ДОПОЛНИТЕЛЬНО", yCursor, Color3.fromRGB(100, 50, 80)); yCursor = yCursor + 30
local heartSizeBtn = makeButton("Размер сердца: 100%", yCursor, BTN_H, Color3.fromRGB(70, 30, 55), Color3.fromRGB(255, 160, 200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ СОХРАНЕНИЯ ============
makeBigSection("СОХРАНЕНИЯ", yCursor, Color3.fromRGB(60, 60, 90)); yCursor = yCursor + 30
local saveNameInput = Instance.new("TextBox")
saveNameInput.Size = UDim2.new(1, -20, 0, 32)
saveNameInput.Position = UDim2.new(0, 10, 0, yCursor)
saveNameInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
saveNameInput.BackgroundTransparency = 0.1
saveNameInput.TextColor3 = Color3.fromRGB(240, 230, 255)
saveNameInput.Font = Enum.Font.GothamBold
saveNameInput.TextSize = 12
saveNameInput.PlaceholderText = "Имя сохранения..."
saveNameInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
saveNameInput.Text = ""
saveNameInput.ClearTextOnFocus = false
saveNameInput.ZIndex = 2
saveNameInput.Parent = panel
Instance.new("UICorner", saveNameInput).CornerRadius = UDim.new(0, 8)
yCursor = yCursor + 36

local createSaveBtn = makeButton("СОЗДАТЬ СОХРАНЕНИЕ", yCursor, BTN_H_BIG, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H_BIG + S_STEP

local savesContainer = Instance.new("ScrollingFrame")
savesContainer.Size = UDim2.new(1, -20, 0, 130)
savesContainer.Position = UDim2.new(0, 10, 0, yCursor)
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
yCursor = yCursor + 136

-- ============ СИСТЕМА ============
makeBigSection("СИСТЕМА", yCursor, Color3.fromRGB(60, 60, 80)); yCursor = yCursor + 30
local saveBtn   = makeButton("Сохранить в автослот", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H + S_STEP
local loadBtn   = makeButton("Загрузить из автослота", yCursor, BTN_H, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local resetBtn  = makeButton("Сбросить всё", yCursor, BTN_H, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP
local unloadBtn = makeButton("ВЫГРУЗИТЬ СКРИПТ", yCursor, BTN_H_BIG, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140)); yCursor = yCursor + BTN_H_BIG + S_STEP + 6

-- ============ МУЗЫКА ============
makeBigSection("МУЗЫКА", yCursor, Color3.fromRGB(80, 60, 110)); yCursor = yCursor + 30
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -20, 0, 32)
musicInput.Position = UDim2.new(0, 10, 0, yCursor)
musicInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
musicInput.BackgroundTransparency = 0.1
musicInput.TextColor3 = Color3.fromRGB(240, 230, 255)
musicInput.Font = Enum.Font.GothamBold
musicInput.TextSize = 12
musicInput.PlaceholderText = "Sound ID"
musicInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
musicInput.Text = ""
musicInput.ClearTextOnFocus = false
musicInput.ZIndex = 2
musicInput.Parent = panel
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 8)
yCursor = yCursor + 36

local applyIdBtn = makeButton("Применить ID", yCursor, BTN_H, Color3.fromRGB(55,80,55), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
local musicBtn   = makeButton("Музыка: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(50,35,60), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ СТАТИСТИКА ============
makeBigSection("СТАТИСТИКА СЕССИИ", yCursor, Color3.fromRGB(60, 60, 90)); yCursor = yCursor + 30
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 100)
statsLabel.Position = UDim2.new(0, 10, 0, yCursor)
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
yCursor = yCursor + 106

local resetSessionBtn = makeButton("Сбросить статистику", yCursor, BTN_H, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP + 6

panel.CanvasSize = UDim2.new(0, 0, 0, yCursor + 20)

-- ============================================================
--       ОТКРЫТИЕ/ЗАКРЫТИЕ ПАНЕЛИ
-- ============================================================
local panelOpen = false
local dragMoved = false
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local function setPanel(open)
    panelOpen = open
    if open then
        local abs = screenGui.AbsoluteSize
        panel.Size = UDim2.fromOffset(PANEL_W, math.clamp(abs.Y - 60, 200, 800))
        panel.Position = UDim2.fromOffset(
            math.clamp(mainBtn.Position.X.Offset + (IS_MOBILE and 72 or 70), 0, math.max(0, abs.X - PANEL_W - 10)), 30)
        panelScale.Scale = 0.85
        panel.Visible = true
        TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    else
        TweenService:Create(panelScale, TweenInfo.new(0.12), { Scale = 0.85 }):Play()
        task.delay(0.13, function()
            if not panelOpen then panel.Visible = false end
        end)
    end
end

mainBtn.Activated:Connect(function()
    if dragMoved then dragMoved = false; return end
    setPanel(not panelOpen)
    if ORBIT.playClick then ORBIT.playClick() end
end)

-- ============================================================
--       ОБРАБОТЧИКИ
-- ============================================================
local ringButtons = { [2]=ring2Btn, [3]=ring3Btn, [4]=ring4Btn, [5]=ring5Btn }
local function refreshRingButton(ri)
    local btn = ringButtons[ri]; if not btn then return end
    if rings[ri].enabled then
        btn.Text = "Убрать кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(55,40,40); btn.TextColor3 = Color3.fromRGB(255,160,160)
    else
        btn.Text = "Кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(40,55,40); btn.TextColor3 = Color3.fromRGB(160,255,160)
    end
end

toggleBtn.Activated:Connect(function()
    ORBIT.setEnabled(not ORBIT.enabled)
    if ORBIT.enabled then
        toggleBtn.Text = "ВКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(0,255,120); toggleBtn.BackgroundColor3 = Color3.fromRGB(40,50,40)
    else
        toggleBtn.Text = "ВЫКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(255,80,80); toggleBtn.BackgroundColor3 = Color3.fromRGB(50,35,40)
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if statsLabel and statsLabel.Parent and ORBIT.SESSION then
            local s = ORBIT.SESSION
            local elapsed = tick() - (s.startTime or tick())
            local mins = math.floor(elapsed / 60)
            local secs = math.floor(elapsed % 60)
            local bots = 0; for _ in pairs(ORBIT.bots or {}) do bots = bots + 1 end
            local ringTargets = 0; for _ in pairs(ORBIT.targetRings or {}) do ringTargets = ringTargets + 1 end
            local tagged = 0; for _ in pairs(ORBIT.taggedPlayers or {}) do tagged = tagged + 1 end
            local savesCount = 0; for _ in pairs(ORBIT.SAVES or {}) do savesCount = savesCount + 1 end
            statsLabel.Text = string.format(
                "Ботов: %d  |  Читеров: %d\nУворотов: %d\nЗащит: %d\nКолец на людях: %d  |  Сохр: %d\nВремя: %d:%02d",
                s.botsCollected or 0, s.cheatersTagged or 0,
                s.dodgesMade or 0, s.protectionsTriggered or 0,
                ringTargets, savesCount, mins, secs)
        end
    end
end)

resetSessionBtn.Activated:Connect(function()
    if ORBIT.SESSION then
        ORBIT.SESSION.botsCollected = 0
        ORBIT.SESSION.cheatersTagged = 0
        ORBIT.SESSION.dodgesMade = 0
        ORBIT.SESSION.protectionsTriggered = 0
        ORBIT.SESSION.startTime = tick()
        ORBIT.notify("Статистика сброшена", Color3.fromRGB(180,220,255), 2)
    end
end)

espBtn.Activated:Connect(function()
    if ORBIT.setESPEnabled then
        ORBIT.setESPEnabled(not ORBIT.ESP.Enabled)
        espBtn.Text = "ESP игроков: " .. (ORBIT.ESP.Enabled and "ВКЛ" or "ВЫКЛ")
        if ORBIT.ESP.Enabled then
            espBtn.BackgroundColor3 = Color3.fromRGB(40,80,60)
            espBtn.TextColor3 = Color3.fromRGB(180,255,200)
        else
            espBtn.BackgroundColor3 = Color3.fromRGB(50,60,90)
            espBtn.TextColor3 = Color3.fromRGB(200,220,255)
        end
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if taggedCount and ORBIT.getTaggedPlayers then
            taggedCount.Text = "Список читеров: " .. #ORBIT.getTaggedPlayers()
        end
    end
end)

local function rebuildPeopleList()
    for _, ch in ipairs(peopleListScroll:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    local list = ORBIT.getPlayerList and ORBIT.getPlayerList() or {}
    if #list == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -6, 0, 24)
        empty.BackgroundTransparency = 1
        empty.Text = "на сервере только ты"
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
        nameLbl.Text = info.name
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
            ringBtn.Text = "Убрать"
            ringBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            ringBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
        else
            ringBtn.Text = "Полное кольцо"
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
            tagBtn.Text = "Снять метку"
            tagBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 50)
            tagBtn.TextColor3 = Color3.fromRGB(220, 200, 220)
        else
            tagBtn.Text = "Читер"
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
    refreshPeopleBtn.Text = "Обновлено"
    task.wait(0.8)
    refreshPeopleBtn.Text = "Обновить список игроков"
end)

addAllRingsBtn.Activated:Connect(function() if ORBIT.addRingsToAll then ORBIT.addRingsToAll() end; task.wait(0.2); rebuildPeopleList() end)
remAllRingsBtn.Activated:Connect(function() if ORBIT.removeRingsFromAll then ORBIT.removeRingsFromAll() end; task.wait(0.2); rebuildPeopleList() end)
toggleAllRingsBtn.Activated:Connect(function() if ORBIT.toggleAllRings then ORBIT.toggleAllRings() end; task.wait(0.2); rebuildPeopleList() end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(4)
        if panel.Visible then pcall(rebuildPeopleList) end
    end
end)
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then task.wait(0.5); pcall(rebuildPeopleList) end end)
Players.PlayerRemoving:Connect(function(p) if p ~= LocalPlayer then task.wait(0.3); pcall(rebuildPeopleList) end end)

-- БОТЫ
botCreateNearBtn.Activated:Connect(function() if ORBIT.createBotNear then ORBIT.createBotNear() end end)
botCreate5Btn.Activated:Connect(function() ORBIT.createMultipleBots(5) end)
botCreate25Btn.Activated:Connect(function() ORBIT.createManyBots(25) end)
botCreate100Btn.Activated:Connect(function() ORBIT.createManyBots(100) end)
botRemoveAll.Activated:Connect(function() ORBIT.removeAllBots() end)
botAutoCollectBtn.Activated:Connect(function()
    ORBIT.botSettings.AutoCollect = not ORBIT.botSettings.AutoCollect
    botAutoCollectBtn.Text = "Автосбор: " .. (ORBIT.botSettings.AutoCollect and "ВКЛ" or "ВЫКЛ")
end)
botRadiusBtn.Activated:Connect(function()
    local steps = {6, 8, 10, 12, 15, 20, 25}
    local idx = 1
    for i, v in ipairs(steps) do if v == ORBIT.botSettings.CollectRadius then idx = i; break end end
    ORBIT.botSettings.CollectRadius = steps[(idx % #steps) + 1]
    botRadiusBtn.Text = "Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st"
end)
botShowPlayerRing.Activated:Connect(function()
    ORBIT.botSettings.ShowPlayerRing = not ORBIT.botSettings.ShowPlayerRing
    botShowPlayerRing.Text = "Кольцо как у игрока: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ")
    ORBIT.notify("Кольцо ботов: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200,180,255), 2)
end)
botSkinBtnEnd.Activated:Connect(function()
    ORBIT.botSettings.UseMySkin = not ORBIT.botSettings.UseMySkin
    botSkinBtnEnd.Text = "Скин как у меня: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ")
    ORBIT.botAvatarTemplate = nil
    ORBIT.notify("Скин бота: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200, 180, 255), 2)
end)
if ORBIT.botSettings.UseMySkin then botSkinBtnEnd.Text = "Скин как у меня: ВКЛ" end
if ORBIT.botSettings.ShowPlayerRing then botShowPlayerRing.Text = "Кольцо как у игрока: ВКЛ" end

-- КОЛЬЦА
allRingsBtn.Activated:Connect(function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local ns = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= ns then ORBIT.setRingEnabled(ri, ns) end end
    for ri = 2, 5 do refreshRingButton(ri) end
    allRingsBtn.Text = ns and "Все кольца: ВЫКЛ" or "Все кольца: ВКЛ"
end)
for ri, btn in pairs(ringButtons) do
    btn.Activated:Connect(function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

-- ВНЕШНИЙ ВИД
shapeCatBtn.Activated:Connect(function()
    P.shapeCategoryIndex = P.shapeCategoryIndex + 1
    if P.shapeCategoryIndex > #P.SHAPE_CATEGORIES then P.shapeCategoryIndex = 1 end
    shapeCatBtn.Text = "Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs > 0 then
        ORBIT.shapeIndex = idxs[1]
        shapeBtn.Text = "Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
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
    shapeBtn.Text = "Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
shapeModeBtn.Activated:Connect(function()
    P.formModeIndex = P.formModeIndex + 1; if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    shapeModeBtn.Text = "Режим: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
shapeSizeBtn.Activated:Connect(function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1; if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    ORBIT.rebuildAllRings()
end)
colorBtn.Activated:Connect(function()
    P.colorIndex = P.colorIndex + 1; if P.colorIndex > #P.COLORS then P.colorIndex = 1 end
    ORBIT.applyColor()
    colorBtn.Text = "Цвет: " .. P.COLORS[P.colorIndex].name
end)
gradientBtn.Activated:Connect(function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    gradientBtn.Text = "Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then SETTINGS.Rainbow = false end
    ORBIT.rebuildAllRings()
end)
lightBtn.Activated:Connect(function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "Свет колец: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
nameBtn.Activated:Connect(function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "Имена блоков: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    ORBIT.applyNameVisibility()
end)
autoSwapBtn.Activated:Connect(function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then ORBIT.lastAutoSwap = tick() end
end)

-- ДВИЖЕНИЕ
orbitBtn.Activated:Connect(function()
    P.orbitIndex = P.orbitIndex + 1; if P.orbitIndex > #P.ORBIT then P.orbitIndex = 1 end
    orbitBtn.Text = "Орбита: " .. P.ORBIT[P.orbitIndex].name
end)
spreadBtn.Activated:Connect(function()
    P.spreadIndex = P.spreadIndex + 1; if P.spreadIndex > #P.SPREAD then P.spreadIndex = 1 end
    spreadBtn.Text = "Разлёт: " .. P.SPREAD[P.spreadIndex].name
end)
heightBtn.Activated:Connect(function()
    P.heightIndex = P.heightIndex + 1; if P.heightIndex > #P.HEIGHT then P.heightIndex = 1 end
    heightBtn.Text = "Высота: " .. P.HEIGHT[P.heightIndex].name
end)
speedBtn.Activated:Connect(function()
    P.speedIndex = P.speedIndex + 1; if P.speedIndex > #P.SPEED then P.speedIndex = 1 end
    SETTINGS.SpeedMultiplier = P.SPEED[P.speedIndex].value
    speedBtn.Text = "Множитель: " .. P.SPEED[P.speedIndex].name
end)
speedModeBtn.Activated:Connect(function()
    P.speedModeIndex = P.speedModeIndex + 1; if P.speedModeIndex > #P.SPEED_MODE then P.speedModeIndex = 1 end
    speedModeBtn.Text = "Режим: " .. P.SPEED_MODE[P.speedModeIndex].name
    ORBIT.applySpeedModePreset()
end)
directionBtn.Activated:Connect(function()
    P.directionIndex = P.directionIndex + 1; if P.directionIndex > #P.DIRECTION then P.directionIndex = 1 end
    directionBtn.Text = "Направление: " .. P.DIRECTION[P.directionIndex].name
    ORBIT.applyDirectionPreset()
end)
orbitPatternBtn.Activated:Connect(function()
    P.orbitPatternIndex = P.orbitPatternIndex + 1; if P.orbitPatternIndex > #P.ORBIT_PATTERNS then P.orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name
    orbitPatternBtn.Text = "Узор: " .. SETTINGS.OrbitPattern
end)

-- КРУЧЕНИЕ
spinBtn.Activated:Connect(function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    spinBtn.Text = ORBIT.spinResetting and "Вращение: ВОЗВРАТ" or "Вращение в 0"
end)
spinAxisBtn.Activated:Connect(function()
    ORBIT.spinAxisEnabled = not ORBIT.spinAxisEnabled
    spinAxisBtn.Text = "Кручение оси: " .. (ORBIT.spinAxisEnabled and "ВКЛ" or "ВЫКЛ")
end)
spinDirBtn.Activated:Connect(function()
    if ORBIT.spinAxisDir == "X" then ORBIT.spinAxisDir = "Y"; spinDirBtn.Text = "Ось: ВЛЕВО/ВПРАВО"
    else ORBIT.spinAxisDir = "X"; spinDirBtn.Text = "Ось: ВЕРХ/ВНИЗ" end
end)
spinSpeedBtn.Activated:Connect(function()
    P.spinSpeedIndex = P.spinSpeedIndex + 1; if P.spinSpeedIndex > #P.SPIN_SPEED then P.spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value
    spinSpeedBtn.Text = "Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

-- ЭФФЕКТЫ
trailBtn.Activated:Connect(function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
trailLenBtn.Activated:Connect(function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    trailLenBtn.Text = "Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
trailWidBtn.Activated:Connect(function()
    P.trailWidthIndex = P.trailWidthIndex + 1; if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    trailWidBtn.Text = "Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
waveBtn.Activated:Connect(function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    waveBtn.Text = "Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
end)
explosionBtn.Activated:Connect(function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    explosionBtn.Text = "Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
end)
pulseBtn.Activated:Connect(function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    pulseBtn.Text = "Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- АУРА
local function refreshAura()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
auraBtn.Activated:Connect(function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    auraBtn.Text = "Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then
        if not SETTINGS.AuraRing and not SETTINGS.AuraParticles and not SETTINGS.AuraShapes then
            SETTINGS.AuraRing = true; SETTINGS.AuraParticles = true; SETTINGS.AuraShapes = true
            auraRingBtn.Text = "Кольцо: ВКЛ"; auraPartBtn.Text = "Частицы: ВКЛ"; auraFigBtn.Text = "Фигуры: ВКЛ"
        end
        ORBIT.setupAura()
    else
        if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
    end
end)
auraRingBtn.Activated:Connect(function()
    SETTINGS.AuraRing = not SETTINGS.AuraRing
    auraRingBtn.Text = "Кольцо: " .. (SETTINGS.AuraRing and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
auraPartBtn.Activated:Connect(function()
    SETTINGS.AuraParticles = not SETTINGS.AuraParticles
    auraPartBtn.Text = "Частицы: " .. (SETTINGS.AuraParticles and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
auraFigBtn.Activated:Connect(function()
    SETTINGS.AuraShapes = not SETTINGS.AuraShapes
    auraFigBtn.Text = "Фигуры: " .. (SETTINGS.AuraShapes and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
auraShapeBtn.Activated:Connect(function()
    ORBIT.auraShapeIndex = ORBIT.auraShapeIndex + 1
    if ORBIT.auraShapeIndex > #SHAPE_PRESETS then ORBIT.auraShapeIndex = 1 end
    auraShapeBtn.Text = "Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    refreshAura()
end)
auraColorBtn.Activated:Connect(function()
    P.auraColorIndex = P.auraColorIndex + 1
    if P.auraColorIndex > #P.COLORS then P.auraColorIndex = 1 end
    local ac = P.COLORS[P.auraColorIndex]
    if ac.c then SETTINGS.AuraColor = ac.c end
    auraColorBtn.Text = "Цвет ауры: " .. ac.name
    refreshAura()
end)
auraSizeBtn.Activated:Connect(function()
    P.auraSizeIndex = P.auraSizeIndex + 1; if P.auraSizeIndex > #P.AURA_SIZE then P.auraSizeIndex = 1 end
    SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value
    auraSizeBtn.Text = "Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    refreshAura()
end)
auraThickBtn.Activated:Connect(function()
    P.auraThickIndex = P.auraThickIndex + 1; if P.auraThickIndex > #P.AURA_THICK then P.auraThickIndex = 1 end
    SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value
    auraThickBtn.Text = "Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    refreshAura()
end)
auraHeightBtn.Activated:Connect(function()
    P.auraHeightIndex = P.auraHeightIndex + 1; if P.auraHeightIndex > #P.AURA_HEIGHT then P.auraHeightIndex = 1 end
    SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value
    auraHeightBtn.Text = "Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
    refreshAura()
end)
auraShapeScaleBtn.Activated:Connect(function()
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1; if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
    SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor
    auraShapeScaleBtn.Text = "Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    refreshAura()
end)
auraPatternBtn.Activated:Connect(function()
    P.auraPatternIndex = P.auraPatternIndex + 1
    if P.auraPatternIndex > #P.AURA_PATTERNS then P.auraPatternIndex = 1 end
    SETTINGS.AuraPattern = P.AURA_PATTERNS[P.auraPatternIndex].name
    auraPatternBtn.Text = "Узор ауры: " .. SETTINGS.AuraPattern
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
auraTrailBtn.Activated:Connect(function()
    SETTINGS.AuraTrailEnabled = not SETTINGS.AuraTrailEnabled
    auraTrailBtn.Text = "Трейлы ауры: " .. (SETTINGS.AuraTrailEnabled and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
auraTrailLenBtn.Activated:Connect(function()
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1; if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    auraTrailLenBtn.Text = "Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
auraTrailWidBtn.Activated:Connect(function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1; if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    auraTrailWidBtn.Text = "Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
auraSpinBtn.Activated:Connect(function()
    SETTINGS.AuraSpinEnabled = not SETTINGS.AuraSpinEnabled
    auraSpinBtn.Text = "Кручение: " .. (SETTINGS.AuraSpinEnabled and "ВКЛ" or "ВЫКЛ")
end)
auraSpinAxisBtn.Activated:Connect(function()
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1; if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    auraSpinAxisBtn.Text = "Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
auraSpinSpeedBtn.Activated:Connect(function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1; if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    auraSpinSpeedBtn.Text = "Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
end)
auraPulseBtn.Activated:Connect(function()
    SETTINGS.AuraPulseEnabled = not SETTINGS.AuraPulseEnabled
    auraPulseBtn.Text = "Пульсация ауры: " .. (SETTINGS.AuraPulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- 🆕 СВЕТ АУРЫ
auraLightBtn.Activated:Connect(function()
    SETTINGS.AuraLightEnabled = not SETTINGS.AuraLightEnabled
    auraLightBtn.Text = "Свет ауры: " .. (SETTINGS.AuraLightEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraLightEnabled then
        auraLightBtn.BackgroundColor3 = Color3.fromRGB(120,100,40)
        auraLightBtn.TextColor3 = Color3.fromRGB(255,240,160)
    else
        auraLightBtn.BackgroundColor3 = Color3.fromRGB(70,60,30)
        auraLightBtn.TextColor3 = Color3.fromRGB(255,230,140)
    end
    refreshAura()
end)
auraLightRangeBtn.Activated:Connect(function()
    local steps = {4, 6, 8, 12, 16, 24, 32}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightRange then idx = i; break end end
    SETTINGS.AuraLightRange = steps[(idx % #steps) + 1]
    auraLightRangeBtn.Text = "Дальность: " .. SETTINGS.AuraLightRange
    refreshAura()
end)
auraLightBrightBtn.Activated:Connect(function()
    local steps = {1, 2, 3, 5, 8, 12}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightBrightness then idx = i; break end end
    SETTINGS.AuraLightBrightness = steps[(idx % #steps) + 1]
    auraLightBrightBtn.Text = "Яркость: " .. SETTINGS.AuraLightBrightness
    refreshAura()
end)

-- ГРАФИКА
local MATERIALS = {"Neon", "Glass", "ForceField", "Plastic", "SmoothPlastic", "Metal", "Ice", "Marble", "Slate", "Granite"}
local materialIndex = 1
for i, m in ipairs(MATERIALS) do
    if m == tostring(SETTINGS.Material):gsub("Enum.Material.", "") then materialIndex = i; break end
end
materialBtn.Activated:Connect(function()
    materialIndex = materialIndex + 1
    if materialIndex > #MATERIALS then materialIndex = 1 end
    local mName = MATERIALS[materialIndex]
    SETTINGS.Material = Enum.Material[mName]
    materialBtn.Text = "Материал: " .. mName:upper()
    ORBIT.rebuildAllRings()
end)
if SETTINGS.Material then
    materialBtn.Text = "Материал: " .. tostring(SETTINGS.Material):gsub("Enum.Material.", ""):upper()
end

transparencyBtn.Activated:Connect(function()
    local steps = {0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9}
    local idx = 1
    for i, v in ipairs(steps) do if math.abs(v - SETTINGS.Transparency) < 0.01 then idx = i; break end end
    SETTINGS.Transparency = steps[(idx % #steps) + 1]
    transparencyBtn.Text = "Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"
    ORBIT.rebuildAllRings()
end)
transparencyBtn.Text = "Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"

brightnessBtn.Activated:Connect(function()
    local steps = {0.5, 1, 1.5, 2, 3, 5, 8}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.GlowIntensity then idx = i; break end end
    if idx == 1 and SETTINGS.GlowIntensity ~= steps[1] then idx = 2 end
    SETTINGS.GlowIntensity = steps[(idx % #steps) + 1]
    brightnessBtn.Text = "Яркость: " .. SETTINGS.GlowIntensity
    ORBIT.rebuildAllRings()
end)

glowBtn.Activated:Connect(function()
    SETTINGS.GlowEnabled = not SETTINGS.GlowEnabled
    glowBtn.Text = "Свечение: " .. (SETTINGS.GlowEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GlowEnabled then
        glowBtn.BackgroundColor3 = Color3.fromRGB(35,60,50)
        glowBtn.TextColor3 = Color3.fromRGB(180,255,220)
    else
        glowBtn.BackgroundColor3 = Color3.fromRGB(45,45,65)
        glowBtn.TextColor3 = Color3.fromRGB(200,200,220)
    end
end)
glowBtn.Text = "Свечение: " .. (SETTINGS.GlowEnabled and "ВКЛ" or "ВЫКЛ")

castShadowBtn.Activated:Connect(function()
    SETTINGS.CastShadow = not SETTINGS.CastShadow
    castShadowBtn.Text = "Тени: " .. (SETTINGS.CastShadow and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)

local GRAPHIC_MODES = {"LOW", "MEDIUM", "HIGH", "ULTRA"}
local graphicModeIndex = 2
local function applyGraphicMode(mode)
    if mode == "LOW" then
        SETTINGS.LightEnabled = false
        SETTINGS.TrailEnabled = false
        SETTINGS.AuraParticles = false
        SETTINGS.BlockCount = 4
    elseif mode == "MEDIUM" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 10
        SETTINGS.TrailEnabled = false
        SETTINGS.AuraParticles = true
        SETTINGS.BlockCount = 6
    elseif mode == "HIGH" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 20
        SETTINGS.TrailEnabled = true
        SETTINGS.AuraParticles = true
        SETTINGS.BlockCount = 8
    elseif mode == "ULTRA" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 40
        SETTINGS.TrailEnabled = true
        SETTINGS.AuraParticles = true
        SETTINGS.AuraShapes = true
        SETTINGS.BlockCount = 12
    end
    ORBIT.rebuildAllRings()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
qualityBtn.Activated:Connect(function()
    graphicModeIndex = graphicModeIndex + 1
    if graphicModeIndex > #GRAPHIC_MODES then graphicModeIndex = 1 end
    local mode = GRAPHIC_MODES[graphicModeIndex]
    qualityBtn.Text = "Качество графики: " .. mode
    applyGraphicMode(mode)
    ORBIT.notify("Графика: " .. mode, Color3.fromRGB(200,220,255), 2)
end)

-- ОГОНЬ
fireBtn.Activated:Connect(function()
    SETTINGS.FireEnabled = not SETTINGS.FireEnabled
    fireBtn.Text = "Огонь: " .. (SETTINGS.FireEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupFire()
end)
fireSizeBtn.Activated:Connect(function()
    P.fireSizeIndex = P.fireSizeIndex + 1; if P.fireSizeIndex > #P.FIRE_SIZE then P.fireSizeIndex = 1 end
    SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value
    fireSizeBtn.Text = "Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)
fireHeatBtn.Activated:Connect(function()
    P.fireHeatIndex = P.fireHeatIndex + 1; if P.fireHeatIndex > #P.FIRE_HEAT then P.fireHeatIndex = 1 end
    SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value
    fireHeatBtn.Text = "Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)

-- ЗАЩИТА
local antichitLoaded = false
antichitLaunchBtn.Activated:Connect(function()
    if antichitLoaded then
        ORBIT.notify("Античит уже запущен", Color3.fromRGB(180,255,180), 2)
        return
    end
    antichitLaunchBtn.Text = "Загружаю..."
    task.spawn(function()
        local url = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_anticheat.lua?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src < 100 then
            antichitLaunchBtn.Text = "Ошибка загрузки"
            antichitStatusLbl.Text = "Защита: ошибка сети"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "Запустить АНТИ-ЧИТ"
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            antichitLaunchBtn.Text = "Ошибка кода"
            antichitStatusLbl.Text = "Защита: ошибка компиляции"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "Запустить АНТИ-ЧИТ"
            return
        end
        local runOk, runErr = pcall(fn)
        if not runOk then
            antichitLaunchBtn.Text = "Ошибка запуска"
            antichitStatusLbl.Text = "Защита: " .. tostring(runErr):sub(1, 30)
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "Запустить АНТИ-ЧИТ"
            return
        end
        antichitLoaded = true
        antichitLaunchBtn.Text = "АНТИ-ЧИТ АКТИВЕН"
        antichitLaunchBtn.BackgroundColor3 = Color3.fromRGB(60,100,60)
        antichitLaunchBtn.TextColor3 = Color3.fromRGB(200,255,200)
        antichitStatusLbl.Text = "Защита: активна (18 функций)"
        antichitStatusLbl.TextColor3 = Color3.fromRGB(160,255,180)
        ORBIT.notify("Античит запущен!", Color3.fromRGB(160,255,180), 3)
    end)
end)

-- ЗВУКИ
soundToggleBtn.Activated:Connect(function()
    if ORBIT.SOUNDS then
        ORBIT.SOUNDS.Enabled = not ORBIT.SOUNDS.Enabled
        soundToggleBtn.Text = "Звуки: " .. (ORBIT.SOUNDS.Enabled and "ВКЛ" or "ВЫКЛ")
    end
end)
local VOLUME_STEPS = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0}
local soundVolumeIndex = 11
soundVolumeBtn.Activated:Connect(function()
    if not ORBIT.SOUNDS then return end
    soundVolumeIndex = soundVolumeIndex + 1
    if soundVolumeIndex > #VOLUME_STEPS then soundVolumeIndex = 1 end
    local v = VOLUME_STEPS[soundVolumeIndex]
    ORBIT.SOUNDS.Volume = v
    soundVolumeBtn.Text = "Громкость: " .. math.floor(v * 100) .. "%"
end)
soundTestBtn.Activated:Connect(function()
    soundTestBtn.Text = "Проверяю..."
    task.wait(0.1)
    if ORBIT.playClick then ORBIT.playClick() end
    task.wait(0.4)
    if ORBIT.playDodge then ORBIT.playDodge() end
    task.wait(1.2)
    soundTestBtn.Text = "Готово"
    task.wait(2)
    soundTestBtn.Text = "Проверка звуков"
end)

-- МЕТКИ
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
        ORBIT.toggleTagCheater(closest); task.wait(0.1); pcall(rebuildPeopleList)
    end
end)
clearTagsBtn.Activated:Connect(function()
    if ORBIT.clearAllTags then ORBIT.clearAllTags() end
    task.wait(0.1); pcall(rebuildPeopleList)
end)

-- МАГАЗИН
openShopBtn.Activated:Connect(function() if ORBIT.openShop then ORBIT.openShop() end end)
openEditorBtn.Activated:Connect(function() if ORBIT.openEditor then ORBIT.openEditor() end end)
openGameBtn.Activated:Connect(function() if ORBIT.openMiniGame then ORBIT.openMiniGame() end end)

-- ПРОИЗВОДИТЕЛЬНОСТЬ
local PERF_MODES = {"auto", "high", "medium", "low", "minimal", "off"}
local PERF_LABELS = {auto="АВТО", high="ВЫСОКОЕ", medium="СРЕДНЕЕ", low="НИЗКОЕ", minimal="МИНИМУМ", off="ВЫКЛ"}
local perfIndex = 1
local function refreshPerfBtn()
    local info = ORBIT.getPerformanceInfo and ORBIT.getPerformanceInfo() or {Mode="auto", Current="high", FPS=60}
    perfBtn.Text = string.format("Качество: %s (FPS:%d)", PERF_LABELS[info.Mode] or info.Mode, info.FPS)
end
refreshPerfBtn()
perfBtn.Activated:Connect(function()
    perfIndex = perfIndex + 1; if perfIndex > #PERF_MODES then perfIndex = 1 end
    if ORBIT.setPerformanceMode then ORBIT.setPerformanceMode(PERF_MODES[perfIndex]) end
    refreshPerfBtn()
end)

-- СЕРДЦЕ
local heartScaleIndex = 4
local HEART_STEPS = P.HEART_STEPS or {0.2, 0.35, 0.5, 0.65, 0.9, 1.2, 1.6, 2.2}
for i, v in ipairs(HEART_STEPS) do if math.abs(v - SETTINGS.HeartScale) < 0.01 then heartScaleIndex = i; break end end
local function refreshHeartSizeBtn()
    local pct = math.floor(SETTINGS.HeartScale / 0.65 * 100 + 0.5)
    heartSizeBtn.Text = "Размер сердца: " .. pct .. "%"
end
refreshHeartSizeBtn()
heartSizeBtn.Activated:Connect(function()
    heartScaleIndex = heartScaleIndex + 1
    if heartScaleIndex > #HEART_STEPS then heartScaleIndex = 1 end
    SETTINGS.HeartScale = HEART_STEPS[heartScaleIndex]
    refreshHeartSizeBtn(); ORBIT.rebuildAllRings()
end)

-- СОХРАНЕНИЯ
local function rebuildSavesList()
    for _, child in ipairs(savesContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
    end
    local names = ORBIT.getSaveNames()
    if #names == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 28)
        empty.BackgroundTransparency = 1
        empty.Text = "нет сохранений"
        empty.TextColor3 = Color3.fromRGB(140,140,170)
        empty.Font = Enum.Font.Gotham; empty.TextSize = 12; empty.LayoutOrder = 1
        empty.Parent = savesContainer
        return
    end
    for i, name in ipairs(names) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = savesContainer
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -130, 1, 0); nameLbl.Position = UDim2.new(0, 8, 0, 0)
        nameLbl.BackgroundTransparency = 1; nameLbl.Text = name
        nameLbl.TextColor3 = Color3.fromRGB(220,220,255)
        nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local loadB = Instance.new("TextButton")
        loadB.Size = UDim2.new(0, 55, 0, 24); loadB.Position = UDim2.new(1, -120, 0, 4)
        loadB.BackgroundColor3 = Color3.fromRGB(40,80,50); loadB.TextColor3 = Color3.fromRGB(160,255,180)
        loadB.Font = Enum.Font.GothamBold; loadB.TextSize = 10; loadB.Text = "ЗАГР"; loadB.Parent = row
        Instance.new("UICorner", loadB).CornerRadius = UDim.new(0, 5)

        local delB = Instance.new("TextButton")
        delB.Size = UDim2.new(0, 55, 0, 24); delB.Position = UDim2.new(1, -60, 0, 4)
        delB.BackgroundColor3 = Color3.fromRGB(80,30,30); delB.TextColor3 = Color3.fromRGB(255,150,150)
        delB.Font = Enum.Font.GothamBold; delB.TextSize = 10; delB.Text = "УДАЛ"; delB.Parent = row
        Instance.new("UICorner", delB).CornerRadius = UDim.new(0, 5)

        loadB.Activated:Connect(function()
            local ok = ORBIT.loadNamed(name)
            if ok then
                ORBIT.notify("Загружено: " .. name, Color3.fromRGB(160,255,180))
                ORBIT.rebuildAllRings()
                if ORBIT.setupAura then ORBIT.setupAura() end
                if ORBIT.setupFire then ORBIT.setupFire() end
                refreshHeartSizeBtn()
            end
        end)
        delB.Activated:Connect(function()
            if ORBIT.deleteNamed(name) then
                ORBIT.notify("Удалено: " .. name, Color3.fromRGB(255,150,150))
                rebuildSavesList()
            end
        end)
    end
end

createSaveBtn.Activated:Connect(function()
    local name = saveNameInput.Text
    if not name or name == "" then name = "Авто-" .. tostring(#ORBIT.getSaveNames() + 1) end
    local ok, err = pcall(function() return ORBIT.saveNamed(name) end)
    if ok and err ~= false then
        ORBIT.notify("Сохранено: " .. name, Color3.fromRGB(160,255,180))
        saveNameInput.Text = ""; rebuildSavesList()
    else
        ORBIT.notify("Ошибка: " .. tostring(err), Color3.fromRGB(255,100,100))
    end
end)

saveBtn.Activated:Connect(function()
    if musicInput.Text ~= "" then ORBIT.setMusicId(musicInput.Text) end
    if ORBIT.saveSettings() then
        saveBtn.Text = "Сохранено!"; task.wait(1.5); saveBtn.Text = "Сохранить в автослот"
    end
end)
loadBtn.Activated:Connect(function()
    if ORBIT.loadSettings() then
        ORBIT.notify("Загружено", Color3.fromRGB(180,220,255))
        ORBIT.rebuildAllRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupFire then ORBIT.setupFire() end
        refreshHeartSizeBtn()
    end
end)
resetBtn.Activated:Connect(function()
    for k, v in pairs(ORBIT.DEFAULT_SETTINGS) do SETTINGS[k] = v end
    ORBIT.shapeIndex = 1; ORBIT.auraShapeIndex = 1
    P.colorIndex = 1; P.auraColorIndex = 1
    P.shapeCategoryIndex = 1; P.orbitPatternIndex = 1; P.auraPatternIndex = 1
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[1].name
    SETTINGS.AuraPattern = P.AURA_PATTERNS[1].name
    ORBIT.rebuildAllRings()
    if ORBIT.setupAura then ORBIT.setupAura() end
    if ORBIT.setupFire then ORBIT.setupFire() end
    ORBIT.notify("Сброс выполнен", Color3.fromRGB(255,180,180))
end)
unloadBtn.Activated:Connect(function() pcall(function() ORBIT.unload() end) end)

applyIdBtn.Activated:Connect(function()
    local ok = ORBIT.setMusicId(musicInput.Text)
    if ok then
        applyIdBtn.Text = "Готово!"; task.wait(1.2); applyIdBtn.Text = "Применить ID"
    else
        applyIdBtn.Text = "Ошибка"; task.wait(1.5); applyIdBtn.Text = "Применить ID"
    end
end)
musicBtn.Activated:Connect(function()
    local s = ORBIT.musicSound and tostring(ORBIT.musicSound.SoundId or "") or ""
    if not ORBIT.musicSound or s == "" or s == "rbxassetid://" then
        musicBtn.Text = "Вставь ID!"; task.wait(1.2)
        musicBtn.Text = "Музыка: " .. (ORBIT.musicEnabled and "ВКЛ" or "ВЫКЛ")
        return
    end
    ORBIT.musicEnabled = not ORBIT.musicEnabled
    if ORBIT.musicEnabled then ORBIT.musicSound:Play(); musicBtn.Text = "Музыка: ВКЛ"
    else ORBIT.musicSound:Stop(); musicBtn.Text = "Музыка: ВЫКЛ" end
end)

rebuildSavesList()

-- ============================================================
--       FPS СЧЁТЧИК
-- ============================================================
task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        local fps = statsData.lastFPS or 0
        local bots = 0; for _ in pairs(ORBIT.bots or {}) do bots = bots + 1 end
        local ringsOn = 0; for ri = 1, 5 do if rings[ri].enabled then ringsOn = ringsOn + 1 end end
        local icon = "[PC]"
        if ORBIT.PLATFORM == "mobile" then icon = "[TEL]" end
        topBarLabel.Text = string.format("%s ОРБИТА v23.3  |  FPS: %d  |  БОТЫ: %d  |  КОЛЬЦА: %d/5",
            icon, fps, bots, ringsOn)
        if fps >= 50 then topBarLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
        elseif fps >= 30 then topBarLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
        else topBarLabel.TextColor3 = Color3.fromRGB(255, 140, 140) end
    end
end)

task.spawn(function() while screenGui and screenGui.Parent do task.wait(1); pcall(refreshPerfBtn) end end)

-- ============================================================
--       ПЕРЕТАСКИВАНИЕ
-- ============================================================
local dragging, dragStart, startPos = false, nil, nil

mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = mainBtn.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        if d.Magnitude > 6 then dragMoved = true end
        if dragMoved then
            local abs = screenGui.AbsoluteSize
            mainBtn.Position = UDim2.fromOffset(
                math.clamp(startPos.X.Offset + d.X, 0, math.max(0, abs.X - 56)),
                math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, abs.Y - 56))
            )
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ============================================================
--       API + ФИТ
-- ============================================================
ORBIT.ui = ORBIT.ui or {}
ORBIT.ui.screenGui = screenGui
ORBIT.ui.panel = panel
ORBIT.ui.topBar = topBar
ORBIT.ui.openShopBtn = openShopBtn
ORBIT.ui.openEditorBtn = openEditorBtn

ORBIT.ui.open = function() setPanel(true) end
ORBIT.ui.close = function() setPanel(false) end
ORBIT.ui.toggle = function() setPanel(not panelOpen) end

ORBIT.ui.fitToScreen = function(frame, w, h)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    local sc = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", frame)
    local abs = screenGui.AbsoluteSize
    sc.Scale = math.min(1, (abs.X - 20) / w, (abs.Y - 20) / h)
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.L then
        if ORBIT.ui and ORBIT.ui.toggle then ORBIT.ui.toggle() end
    end
end)

-- ============================================================
--       СТАРТ
-- ============================================================
ORBIT.start = function()
    if getgenv()._OrbitLoaderGui then pcall(function() getgenv()._OrbitLoaderGui:Destroy() end) end
    ORBIT.startLogic()
    ORBIT.notify("ОРБИТА v23.3 запущена!", Color3.fromRGB(200,200,255), 3)
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("P4 v23.3 (UI + FPS + аура + графика)", Color3.fromRGB(180,255,180), 3) end

-- ПОДГРУЗКА МАГАЗИНА
task.spawn(function()
    local url = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_p4_shop.lua?t=" .. os.time()
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if ok and type(src) == "string" and #src > 100 then
        local fn = loadstring(src)
        if fn then pcall(fn) end
    end
end)

-- ПОДГРУЗКА МИНИ-ИГРЫ
task.spawn(function()
    task.wait(0.5)
    local url = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_minigame.lua?t=" .. os.time()
    local ok, src = pcall(function() return game:HttpGet(url) end)
    if ok and type(src) == "string" and #src > 100 then
        local fn, err = loadstring(src)
        if fn then
            local runOk, runErr = pcall(fn)
            if not runOk then warn("[Orbit MiniGame] Runtime error: " .. tostring(runErr)) end
        else
            warn("[Orbit MiniGame] Compile error: " .. tostring(err))
        end
    else
        warn("[Orbit MiniGame] Не удалось загрузить файл")
    end
end)

return true
