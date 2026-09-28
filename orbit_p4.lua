--[[ ОРБИТА v20.0 — ЧАСТЬ 4/4: MATRIX RAIN UI ]]

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
if not ORBIT.getShapeIndicesInCategory then warn("[Orbit P4] Обнови p3!"); return end

-- ==================== ЦВЕТА ====================
local ACCENT      = Color3.fromRGB(80, 255, 140)
local ACCENT_DIM  = Color3.fromRGB(40, 140, 80)
local BG_DARK     = Color3.fromRGB(8, 12, 10)
local BG_MED      = Color3.fromRGB(15, 22, 18)
local TEXT_MAIN   = Color3.fromRGB(180, 255, 200)
local TEXT_DIM    = Color3.fromRGB(90, 140, 100)

-- ==================== КОРНЕВОЙ GUI ====================
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

-- ==================== КНОПКА ОТКРЫТИЯ ====================
local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, 64, 0, 64)
mainBtn.Position = UDim2.new(0, 20, 0, 100)
mainBtn.BackgroundColor3 = BG_DARK
mainBtn.TextColor3 = ACCENT
mainBtn.Font = Enum.Font.Code
mainBtn.TextSize = 26
mainBtn.Text = ">_"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", mainBtn)
mainStroke.Color = ACCENT
mainStroke.Thickness = 2
mainStroke.Transparency = 0.2

task.spawn(function()
    while mainBtn and mainBtn.Parent do
        TweenService:Create(mainStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency = 0.7}):Play()
        task.wait(1.2)
        TweenService:Create(mainStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency = 0.2}):Play()
        task.wait(1.2)
    end
end)

-- ==================== ПАНЕЛЬ ====================
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 340, 0, 740)
panel.Position = UDim2.new(0, 95, 0, 5)
panel.BackgroundColor3 = BG_DARK
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = ACCENT
panelStroke.Thickness = 2
panelStroke.Transparency = 0.3

-- ==================== МАТРИЧНЫЙ ДОЖДЬ (фон) ====================
local bgLayer = Instance.new("Frame")
bgLayer.Size = UDim2.new(1, 0, 1, 0)
bgLayer.BackgroundColor3 = Color3.fromRGB(0, 5, 2)
bgLayer.BackgroundTransparency = 0.3
bgLayer.BorderSizePixel = 0
bgLayer.ClipsDescendants = true
bgLayer.ZIndex = 0
bgLayer.Parent = panel
Instance.new("UICorner", bgLayer).CornerRadius = UDim.new(0, 12)

-- Сетка линий
for i = 1, 15 do
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, i / 15, 0)
    line.BackgroundColor3 = ACCENT
    line.BackgroundTransparency = 0.93
    line.BorderSizePixel = 0
    line.ZIndex = 0
    line.Parent = bgLayer
end

-- Падающие символы
local MATRIX_CHARS = {"0","1","<",">","{","}","[","]","/","\\","|","+","-","*","=","#","%","&","$","@","A","E","F","Z","X","7","9","?"}

task.spawn(function()
    local columns = {}
    local NUM_COLS = 14

    for i = 1, NUM_COLS do
        local col = Instance.new("TextLabel")
        col.Size = UDim2.new(0, 16, 0, 300)
        col.Position = UDim2.new((i - 0.5) / NUM_COLS, 0, -1, 0)
        col.BackgroundTransparency = 1
        col.TextColor3 = ACCENT
        col.TextTransparency = 0.4
        col.Font = Enum.Font.Code
        col.TextSize = 12
        col.TextYAlignment = Enum.TextYAlignment.Top
        col.TextXAlignment = Enum.TextXAlignment.Center
        col.ZIndex = 0
        col.Parent = bgLayer

        local str = ""
        for j = 1, 25 do
            str = str .. MATRIX_CHARS[math.random(1, #MATRIX_CHARS)]
            if j < 25 then str = str .. "\n" end
        end
        col.Text = str

        table.insert(columns, {
            label = col,
            speed = math.random(50, 130) / 100,
        })
    end

    while bgLayer and bgLayer.Parent do
        for _, c in ipairs(columns) do
            local pos = c.label.Position
            local newY = pos.Y.Scale + 0.001 * c.speed * 60
            if newY > 1.1 then
                newY = -1.1 - math.random(0, 20) / 100
                local str = ""
                for j = 1, 25 do
                    str = str .. MATRIX_CHARS[math.random(1, #MATRIX_CHARS)]
                    if j < 25 then str = str .. "\n" end
                end
                c.label.Text = str
                c.speed = math.random(50, 130) / 100
            end
            c.label.Position = UDim2.new(pos.X.Scale, pos.X.Offset, newY, pos.Y.Offset)
        end
        task.wait(0.05)
    end
end)

-- Верхняя декоративная полоска
local topDecor = Instance.new("Frame")
topDecor.Size = UDim2.new(1, 0, 0, 3)
topDecor.BackgroundColor3 = ACCENT
topDecor.BorderSizePixel = 0
topDecor.ZIndex = 2
topDecor.Parent = panel
Instance.new("UICorner", topDecor).CornerRadius = UDim.new(0, 12)

-- ==================== ЗАГОЛОВОК ====================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 56)
header.Position = UDim2.new(0, 0, 0, 3)
header.BackgroundColor3 = BG_MED
header.BackgroundTransparency = 0.15
header.BorderSizePixel = 0
header.ZIndex = 2
header.Parent = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local titleIcon = Instance.new("TextLabel")
titleIcon.Size = UDim2.new(0, 40, 1, 0)
titleIcon.Position = UDim2.new(0, 8, 0, 0)
titleIcon.BackgroundTransparency = 1
titleIcon.Text = "▶"
titleIcon.TextColor3 = ACCENT
titleIcon.Font = Enum.Font.Code
titleIcon.TextSize = 22
titleIcon.ZIndex = 3
titleIcon.Parent = header

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -90, 0, 24)
titleText.Position = UDim2.new(0, 48, 0, 6)
titleText.BackgroundTransparency = 1
titleText.Text = "ОРБИТА v20.0"
titleText.TextColor3 = ACCENT
titleText.Font = Enum.Font.Code
titleText.TextSize = 16
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.ZIndex = 3
titleText.Parent = header

local subtitleText = Instance.new("TextLabel")
subtitleText.Size = UDim2.new(1, -90, 0, 18)
subtitleText.Position = UDim2.new(0, 48, 0, 30)
subtitleText.BackgroundTransparency = 1
subtitleText.Text = "FIRE EDITION • TERMINAL"
subtitleText.TextColor3 = TEXT_DIM
subtitleText.Font = Enum.Font.Code
subtitleText.TextSize = 10
subtitleText.TextXAlignment = Enum.TextXAlignment.Left
subtitleText.ZIndex = 3
subtitleText.Parent = header

local liveDot = Instance.new("Frame")
liveDot.Size = UDim2.new(0, 8, 0, 8)
liveDot.Position = UDim2.new(1, -60, 0, 12)
liveDot.BackgroundColor3 = ACCENT
liveDot.BorderSizePixel = 0
liveDot.ZIndex = 3
liveDot.Parent = header
Instance.new("UICorner", liveDot).CornerRadius = UDim.new(1, 0)
task.spawn(function()
    while liveDot and liveDot.Parent do
        liveDot.BackgroundTransparency = 0
        task.wait(0.5)
        liveDot.BackgroundTransparency = 0.7
        task.wait(0.5)
    end
end)

local liveText = Instance.new("TextLabel")
liveText.Size = UDim2.new(0, 40, 0, 14)
liveText.Position = UDim2.new(1, -50, 0, 9)
liveText.BackgroundTransparency = 1
liveText.Text = "LIVE"
liveText.TextColor3 = ACCENT
liveText.Font = Enum.Font.Code
liveText.TextSize = 10
liveText.TextXAlignment = Enum.TextXAlignment.Left
liveText.ZIndex = 3
liveText.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 28)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
closeBtn.BackgroundTransparency = 0.4
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 14
closeBtn.Text = "×"
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 3
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseEnter:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
end)
closeBtn.MouseLeave:Connect(function()
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
end)
closeBtn.Activated:Connect(function() panel.Visible = false end)

-- ==================== СПИСОК КНОПОК ====================
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, 0, 1, -60)
list.Position = UDim2.new(0, 0, 0, 60)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = ACCENT
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ZIndex = 2
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)
layout.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 12)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = list

local order = 0
local function nextOrder() order = order + 1; return order end

-- ==================== КОМПОНЕНТЫ ====================
local function makeSection(text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 22)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = nextOrder()
    holder.Parent = list

    local prefix = Instance.new("TextLabel")
    prefix.Size = UDim2.new(0, 20, 1, 0)
    prefix.BackgroundTransparency = 1
    prefix.Text = "▸"
    prefix.TextColor3 = ACCENT
    prefix.Font = Enum.Font.Code
    prefix.TextSize = 12
    prefix.Parent = holder

    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -30, 1, 0)
    s.Position = UDim2.new(0, 18, 0, 0)
    s.BackgroundTransparency = 1
    s.Text = text
    s.TextColor3 = ACCENT
    s.Font = Enum.Font.Code
    s.TextSize = 12
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = holder

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -30, 0, 1)
    line.Position = UDim2.new(0, 18, 1, -2)
    line.BackgroundColor3 = ACCENT_DIM
    line.BackgroundTransparency = 0.6
    line.BorderSizePixel = 0
    line.Parent = holder

    return s
end

local function makeButton(text, h, customColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, h or 30)
    b.BackgroundColor3 = BG_MED
    b.BackgroundTransparency = 0.25
    b.TextColor3 = customColor or TEXT_MAIN
    b.Font = Enum.Font.Code
    b.TextSize = 11
    b.Text = "  " .. text
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.LayoutOrder = nextOrder()
    b.Parent = list
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", b)
    stroke.Color = customColor or ACCENT_DIM
    stroke.Thickness = 1
    stroke.Transparency = 0.6

    local leftBar = Instance.new("Frame")
    leftBar.Size = UDim2.new(0, 3, 1, -8)
    leftBar.Position = UDim2.new(0, 4, 0, 4)
    leftBar.BackgroundColor3 = customColor or ACCENT
    leftBar.BorderSizePixel = 0
    leftBar.Parent = b
    Instance.new("UICorner", leftBar).CornerRadius = UDim.new(0, 2)

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(25, 45, 30),
            BackgroundTransparency = 0.1,
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), {Transparency = 0.2}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = BG_MED,
            BackgroundTransparency = 0.25,
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Transparency = 0.6}):Play()
    end)
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.05), {
            BackgroundColor3 = Color3.fromRGB(35, 65, 45),
        }):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundColor3 = BG_MED,
        }):Play()
    end)

    return b
end

-- ==================== СЕКЦИИ ====================
makeSection("СИСТЕМА")
local toggleBtn     = makeButton("[●] ВКЛЮЧЕНО", 30, ACCENT)
local allRingsBtn   = makeButton("[○] Все кольца: ВКЛ", 28)
local ring2Btn      = makeButton("[+] Кольцо 2", 26)
local ring3Btn      = makeButton("[+] Кольцо 3", 26)
local ring4Btn      = makeButton("[+] Кольцо 4", 26)
local ring5Btn      = makeButton("[+] Кольцо 5", 26)

makeSection("ФОРМА И ФИГУРЫ")
local shapeCatBtn   = makeButton("[◇] Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, 30, ACCENT)
local shapeBtn      = makeButton("[◆] Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, 28, ACCENT)
local shapeModeBtn  = makeButton("[◇] Формы: " .. P.FORM_MODES[P.formModeIndex].name, 26)
local shapeSizeBtn  = makeButton("[◇] Фигура: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, 26)
local autoSwapBtn   = makeButton("[◇] Автосмена: ВЫКЛ", 26)

makeSection("ОРБИТА И ДВИЖЕНИЕ")
local orbitBtn      = makeButton("[◇] Орбита: " .. P.ORBIT[P.orbitIndex].name, 26)
local spreadBtn     = makeButton("[◇] Разлёт: " .. P.SPREAD[P.spreadIndex].name, 26)
local heightBtn     = makeButton("[◇] Высота: " .. P.HEIGHT[P.heightIndex].name, 26)
local speedBtn      = makeButton("[◇] Множитель: " .. P.SPEED[P.speedIndex].name, 26)
local speedModeBtn  = makeButton("[◇] Скорость: " .. P.SPEED_MODE[P.speedModeIndex].name, 26)
local directionBtn  = makeButton("[◇] Направление: " .. P.DIRECTION[P.directionIndex].name, 26)
local orbitPatternBtn = makeButton("[◇] Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, 26)

makeSection("КРУЧЕНИЕ")
local spinBtn       = makeButton("[↩] Вращение в 0", 26)
local spinAxisBtn   = makeButton("[◇] Кручение оси: ВКЛ", 26)
local spinDirBtn    = makeButton("[◇] Ось: ВЕРХ/ВНИЗ", 26)
local spinSpeedBtn  = makeButton("[◇] Скорость: 1x", 26)

makeSection("ЭФФЕКТЫ КОЛЕЦ")
local trailBtn      = makeButton("[◇] Трейлы: ВЫКЛ", 26)
local trailLenBtn   = makeButton("[◇] Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name, 26)
local trailWidBtn   = makeButton("[◇] Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name, 26)
local waveBtn       = makeButton("[◇] Волна: ВЫКЛ", 26)
local explosionBtn  = makeButton("[◇] Взрыв: ВЫКЛ", 26)
local pulseBtn      = makeButton("[◇] Пульсация: ВЫКЛ", 26)
local gradientBtn   = makeButton("[◇] Градиент: ВЫКЛ", 26)

makeSection("ОГОНЬ")
local fireBtn       = makeButton("[fire] Огонь: ВЫКЛ", 34, Color3.fromRGB(255, 140, 60))
local fireSizeBtn   = makeButton("[◇] Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name, 26, Color3.fromRGB(255, 150, 80))
local fireHeatBtn   = makeButton("[◇] Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name, 26, Color3.fromRGB(255, 150, 80))

makeSection("АУРА — ЭЛЕМЕНТЫ")
local auraBtn       = makeButton("[aura] Аура: ВЫКЛ", 30, Color3.fromRGB(180, 120, 255))
local auraRingBtn   = makeButton("[◇] Кольцо: ВКЛ", 26, Color3.fromRGB(180, 120, 255))
local auraPartBtn   = makeButton("[◇] Частицы: ВЫКЛ", 26, Color3.fromRGB(180, 120, 255))
local auraFigBtn    = makeButton("[◇] Фигуры: ВЫКЛ", 26, Color3.fromRGB(180, 120, 255))
local auraShapeBtn  = makeButton("[◇] Форма: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraColorBtn  = makeButton("[◇] Цвет: " .. P.COLORS[P.auraColorIndex].name, 26, Color3.fromRGB(180, 120, 255))

makeSection("АУРА — РАЗМЕР")
local auraSizeBtn   = makeButton("[◇] Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraThickBtn  = makeButton("[◇] Толщина: " .. P.AURA_THICK[P.auraThickIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraHeightBtn = makeButton("[◇] Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraScaleBtn  = makeButton("[◇] Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, 26, Color3.fromRGB(180, 120, 255))

makeSection("АУРА — СКОРОСТЬ")
local auraSpeedBtn  = makeButton("[◇] Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraDirBtn    = makeButton("[◇] Направление: " .. P.AURA_DIR[P.auraDirIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraSpinBtn   = makeButton("[◇] Кручение: ВКЛ", 26, Color3.fromRGB(180, 120, 255))
local auraSpinAxisBtn = makeButton("[◇] Ось: ВЕРХ/ВНИЗ", 26, Color3.fromRGB(180, 120, 255))
local auraSpinSpeedBtn = makeButton("[◇] Скорость: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraSpinResetBtn = makeButton("[↩] Сброс вращения", 26, Color3.fromRGB(180, 120, 255))

makeSection("АУРА — ТРЕЙЛЫ")
local auraTrailBtn    = makeButton("[◇] Трейлы: ВЫКЛ", 26, Color3.fromRGB(180, 120, 255))
local auraTrailLenBtn = makeButton("[◇] Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, 26, Color3.fromRGB(180, 120, 255))
local auraTrailWidBtn = makeButton("[◇] Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, 26, Color3.fromRGB(180, 120, 255))

makeSection("ЦВЕТ И СВЕТ")
local colorBtn      = makeButton("[◆] Цвет: " .. P.COLORS[P.colorIndex].name, 28, ACCENT)
local lightBtn      = makeButton("[◇] Свет: ВКЛ", 26)
local nameBtn       = makeButton("[◇] Имена: ВЫКЛ", 26)

makeSection("ЛЮДИ И КОЛЬЦА")
local addAllRingsBtn  = makeButton("[+] Кольцо У ВСЕХ", 30, ACCENT)
local remAllRingsBtn  = makeButton("[-] УБРАТЬ У ВСЕХ", 30, Color3.fromRGB(255, 100, 100))
local toggleAllRingsBtn = makeButton("[~] Переключить ВСЕМ", 28)

local peopleContainer = Instance.new("Frame")
peopleContainer.Size = UDim2.new(1, 0, 0, 190)
peopleContainer.BackgroundColor3 = BG_MED
peopleContainer.BackgroundTransparency = 0.3
peopleContainer.BorderSizePixel = 0
peopleContainer.LayoutOrder = nextOrder()
peopleContainer.Parent = list
Instance.new("UICorner", peopleContainer).CornerRadius = UDim.new(0, 6)
local pStroke = Instance.new("UIStroke", peopleContainer)
pStroke.Color = ACCENT_DIM; pStroke.Thickness = 1; pStroke.Transparency = 0.5

local peopleList = Instance.new("ScrollingFrame")
peopleList.Size = UDim2.new(1, -8, 1, -8)
peopleList.Position = UDim2.new(0, 4, 0, 4)
peopleList.BackgroundTransparency = 1
peopleList.BorderSizePixel = 0
peopleList.CanvasSize = UDim2.new(0, 0, 0, 0)
peopleList.AutomaticCanvasSize = Enum.AutomaticSize.Y
peopleList.ScrollBarThickness = 3
peopleList.ScrollBarImageColor3 = ACCENT
peopleList.ScrollingDirection = Enum.ScrollingDirection.Y
peopleList.Parent = peopleContainer
local peopleLayout = Instance.new("UIListLayout")
peopleLayout.SortOrder = Enum.SortOrder.LayoutOrder
peopleLayout.Padding = UDim.new(0, 3)
peopleLayout.Parent = peopleList

makeSection("СТАТИСТИКА")
local statsCard = Instance.new("Frame")
statsCard.Size = UDim2.new(1, 0, 0, 70)
statsCard.BackgroundColor3 = BG_MED
statsCard.BackgroundTransparency = 0.3
statsCard.BorderSizePixel = 0
statsCard.LayoutOrder = nextOrder()
statsCard.Parent = list
Instance.new("UICorner", statsCard).CornerRadius = UDim.new(0, 6)
local sStroke = Instance.new("UIStroke", statsCard)
sStroke.Color = ACCENT_DIM; sStroke.Thickness = 1; sStroke.Transparency = 0.5

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -12, 1, -8)
statsLabel.Position = UDim2.new(0, 8, 0, 4)
statsLabel.BackgroundTransparency = 1
statsLabel.TextColor3 = ACCENT
statsLabel.Font = Enum.Font.Code
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "> FPS: --\n> Фигур: 0\n> Время: 0:00"
statsLabel.Parent = statsCard

makeSection("МУЗЫКА")
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, 0, 0, 30)
musicInput.BackgroundColor3 = BG_MED
musicInput.BackgroundTransparency = 0.2
musicInput.TextColor3 = TEXT_MAIN
musicInput.Font = Enum.Font.Code
musicInput.TextSize = 11
musicInput.PlaceholderText = "> вставь ID сюда..."
musicInput.PlaceholderColor3 = TEXT_DIM
musicInput.Text = ""
musicInput.ClearTextOnFocus = false
musicInput.LayoutOrder = nextOrder()
musicInput.Parent = list
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 6)
local mStroke = Instance.new("UIStroke", musicInput)
mStroke.Color = ACCENT_DIM; mStroke.Thickness = 1; mStroke.Transparency = 0.4

local applyIdBtn = makeButton("[✓] Применить ID", 26, ACCENT)
local musicBtn   = makeButton("[♪] Музыка: ВЫКЛ", 26)

makeSection("СИСТЕМА")
local saveBtn   = makeButton("[save] СОХРАНИТЬ", 34, ACCENT)
local loadBtn   = makeButton("[load] ЗАГРУЗИТЬ", 32)
local resetBtn  = makeButton("[x] СБРОС", 30, Color3.fromRGB(255, 100, 100))
local unloadBtn = makeButton("[x] ВЫГРУЗИТЬ СКРИПТ", 30, Color3.fromRGB(255, 100, 100))

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, 0, 0, 24)
hintLabel.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
hintLabel.BackgroundTransparency = 0.4
hintLabel.BorderSizePixel = 0
hintLabel.Text = "! Автосейв выключен — жми [save]"
hintLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
hintLabel.Font = Enum.Font.Code
hintLabel.TextSize = 10
hintLabel.LayoutOrder = nextOrder()
hintLabel.Parent = list
Instance.new("UICorner", hintLabel).CornerRadius = UDim.new(0, 4)

-- ==================== ОБРАБОТЧИКИ ====================
local ringButtons = { [2]=ring2Btn, [3]=ring3Btn, [4]=ring4Btn, [5]=ring5Btn }

local function refreshRingButton(ri)
    local btn = ringButtons[ri]; if not btn then return end
    if rings[ri].enabled then
        btn.Text = "  [-] Убрать кольцо " .. ri
        btn.TextColor3 = Color3.fromRGB(255, 140, 140)
    else
        btn.Text = "  [+] Кольцо " .. ri
        btn.TextColor3 = TEXT_MAIN
    end
end

mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)

toggleBtn.Activated:Connect(function()
    ORBIT.setEnabled(not ORBIT.enabled)
    if ORBIT.enabled then
        toggleBtn.Text = "  [●] ВКЛЮЧЕНО"; toggleBtn.TextColor3 = ACCENT
    else
        toggleBtn.Text = "  [○] ВЫКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

allRingsBtn.Activated:Connect(function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local ns = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= ns then ORBIT.setRingEnabled(ri, ns) end end
    for ri = 2, 5 do refreshRingButton(ri) end
    allRingsBtn.Text = "  [" .. (ns and "●" or "○") .. "] Все кольца: " .. (ns and "ВКЛ" or "ВЫКЛ")
end)

for ri, btn in pairs(ringButtons) do
    btn.Activated:Connect(function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

shapeCatBtn.Activated:Connect(function()
    P.shapeCategoryIndex = P.shapeCategoryIndex + 1
    if P.shapeCategoryIndex > #P.SHAPE_CATEGORIES then P.shapeCategoryIndex = 1 end
    shapeCatBtn.Text = "  [◇] Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs > 0 then
        ORBIT.shapeIndex = idxs[1]
        shapeBtn.Text = "  [◆] Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
    end
    ORBIT.notify("> " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, ACCENT)
end)

shapeBtn.Activated:Connect(function()
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs == 0 then return end
    local pos = nil
    for i, v in ipairs(idxs) do if v == ORBIT.shapeIndex then pos = i; break end end
    local newPos = pos and (pos % #idxs) + 1 or 1
    ORBIT.shapeIndex = idxs[newPos]
    shapeBtn.Text = "  [◆] Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
end)

shapeModeBtn.Activated:Connect(function()
    P.formModeIndex = P.formModeIndex + 1
    if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    shapeModeBtn.Text = "  [◇] Формы: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
end)
shapeSizeBtn.Activated:Connect(function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1
    if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "  [◇] Фигура: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
end)
autoSwapBtn.Activated:Connect(function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "  [◇] Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then ORBIT.lastAutoSwap = tick() end
end)

orbitBtn.Activated:Connect(function()
    P.orbitIndex = P.orbitIndex + 1; if P.orbitIndex > #P.ORBIT then P.orbitIndex = 1 end
    orbitBtn.Text = "  [◇] Орбита: " .. P.ORBIT[P.orbitIndex].name
end)
spreadBtn.Activated:Connect(function()
    P.spreadIndex = P.spreadIndex + 1; if P.spreadIndex > #P.SPREAD then P.spreadIndex = 1 end
    spreadBtn.Text = "  [◇] Разлёт: " .. P.SPREAD[P.spreadIndex].name
end)
heightBtn.Activated:Connect(function()
    P.heightIndex = P.heightIndex + 1; if P.heightIndex > #P.HEIGHT then P.heightIndex = 1 end
    heightBtn.Text = "  [◇] Высота: " .. P.HEIGHT[P.heightIndex].name
end)
speedBtn.Activated:Connect(function()
    P.speedIndex = P.speedIndex + 1; if P.speedIndex > #P.SPEED then P.speedIndex = 1 end
    SETTINGS.SpeedMultiplier = P.SPEED[P.speedIndex].value
    speedBtn.Text = "  [◇] Множитель: " .. P.SPEED[P.speedIndex].name
end)
speedModeBtn.Activated:Connect(function()
    P.speedModeIndex = P.speedModeIndex + 1; if P.speedModeIndex > #P.SPEED_MODE then P.speedModeIndex = 1 end
    speedModeBtn.Text = "  [◇] Скорость: " .. P.SPEED_MODE[P.speedModeIndex].name
    ORBIT.applySpeedModePreset()
end)
directionBtn.Activated:Connect(function()
    P.directionIndex = P.directionIndex + 1; if P.directionIndex > #P.DIRECTION then P.directionIndex = 1 end
    directionBtn.Text = "  [◇] Направление: " .. P.DIRECTION[P.directionIndex].name
    ORBIT.applyDirectionPreset()
end)
orbitPatternBtn.Activated:Connect(function()
    P.orbitPatternIndex = P.orbitPatternIndex + 1; if P.orbitPatternIndex > #P.ORBIT_PATTERNS then P.orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name
    orbitPatternBtn.Text = "  [◇] Узор: " .. SETTINGS.OrbitPattern
end)

spinBtn.Activated:Connect(function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    spinBtn.Text = "  [↩] " .. (ORBIT.spinResetting and "Вращение: ВОЗВРАТ" or "Вращение в 0")
end)
spinAxisBtn.Activated:Connect(function()
    ORBIT.spinAxisEnabled = not ORBIT.spinAxisEnabled
    spinAxisBtn.Text = "  [◇] Кручение оси: " .. (ORBIT.spinAxisEnabled and "ВКЛ" or "ВЫКЛ")
end)
spinDirBtn.Activated:Connect(function()
    if ORBIT.spinAxisDir == "X" then ORBIT.spinAxisDir = "Y"; spinDirBtn.Text = "  [◇] Ось: ВЛЕВО/ВПРАВО"
    else ORBIT.spinAxisDir = "X"; spinDirBtn.Text = "  [◇] Ось: ВЕРХ/ВНИЗ" end
end)
spinSpeedBtn.Activated:Connect(function()
    P.spinSpeedIndex = P.spinSpeedIndex + 1; if P.spinSpeedIndex > #P.SPIN_SPEED then P.spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value
    spinSpeedBtn.Text = "  [◇] Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

trailBtn.Activated:Connect(function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "  [◇] Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
trailLenBtn.Activated:Connect(function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    trailLenBtn.Text = "  [◇] Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
trailWidBtn.Activated:Connect(function()
    P.trailWidthIndex = P.trailWidthIndex + 1; if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    trailWidBtn.Text = "  [◇] Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
waveBtn.Activated:Connect(function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    waveBtn.Text = "  [◇] Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
end)
explosionBtn.Activated:Connect(function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    explosionBtn.Text = "  [◇] Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
end)
pulseBtn.Activated:Connect(function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    pulseBtn.Text = "  [◇] Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
end)
gradientBtn.Activated:Connect(function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    gradientBtn.Text = "  [◇] Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then SETTINGS.Rainbow = false end
    ORBIT.rebuildAllRings()
end)

fireBtn.Activated:Connect(function()
    SETTINGS.FireEnabled = not SETTINGS.FireEnabled
    fireBtn.Text = "  [fire] Огонь: " .. (SETTINGS.FireEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupFire()
end)
fireSizeBtn.Activated:Connect(function()
    P.fireSizeIndex = P.fireSizeIndex + 1; if P.fireSizeIndex > #P.FIRE_SIZE then P.fireSizeIndex = 1 end
    SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value
    fireSizeBtn.Text = "  [◇] Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)
fireHeatBtn.Activated:Connect(function()
    P.fireHeatIndex = P.fireHeatIndex + 1; if P.fireHeatIndex > #P.FIRE_HEAT then P.fireHeatIndex = 1 end
    SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value
    fireHeatBtn.Text = "  [◇] Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)

auraBtn.Activated:Connect(function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    auraBtn.Text = "  [aura] Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura()
    else if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end end
end)
auraRingBtn.Activated:Connect(function()
    SETTINGS.AuraRing = not SETTINGS.AuraRing
    auraRingBtn.Text = "  [◇] Кольцо: " .. (SETTINGS.AuraRing and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraPartBtn.Activated:Connect(function()
    SETTINGS.AuraParticles = not SETTINGS.AuraParticles
    auraPartBtn.Text = "  [◇] Частицы: " .. (SETTINGS.AuraParticles and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraFigBtn.Activated:Connect(function()
    SETTINGS.AuraShapes = not SETTINGS.AuraShapes
    auraFigBtn.Text = "  [◇] Фигуры: " .. (SETTINGS.AuraShapes and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraShapeBtn.Activated:Connect(function()
    ORBIT.auraShapeIndex = ORBIT.auraShapeIndex + 1
    if ORBIT.auraShapeIndex > #SHAPE_PRESETS then ORBIT.auraShapeIndex = 1 end
    auraShapeBtn.Text = "  [◇] Форма: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraColorBtn.Activated:Connect(function()
    P.auraColorIndex = P.auraColorIndex + 1
    if P.auraColorIndex > #P.COLORS then P.auraColorIndex = 1 end
    local ac = P.COLORS[P.auraColorIndex]
    if ac.c then SETTINGS.AuraColor = ac.c end
    auraColorBtn.Text = "  [◇] Цвет: " .. ac.name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraSizeBtn.Activated:Connect(function()
    P.auraSizeIndex = P.auraSizeIndex + 1; if P.auraSizeIndex > #P.AURA_SIZE then P.auraSizeIndex = 1 end
    SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value
    auraSizeBtn.Text = "  [◇] Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraThickBtn.Activated:Connect(function()
    P.auraThickIndex = P.auraThickIndex + 1; if P.auraThickIndex > #P.AURA_THICK then P.auraThickIndex = 1 end
    SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value
    auraThickBtn.Text = "  [◇] Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraHeightBtn.Activated:Connect(function()
    P.auraHeightIndex = P.auraHeightIndex + 1; if P.auraHeightIndex > #P.AURA_HEIGHT then P.auraHeightIndex = 1 end
    SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value
    auraHeightBtn.Text = "  [◇] Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
end)
auraScaleBtn.Activated:Connect(function()
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1
    if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
    SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor
    auraScaleBtn.Text = "  [◇] Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraSpeedBtn.Activated:Connect(function()
    P.auraSpeedIndex = P.auraSpeedIndex + 1; if P.auraSpeedIndex > #P.AURA_SPEED then P.auraSpeedIndex = 1 end
    SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value
    auraSpeedBtn.Text = "  [◇] Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
end)
auraDirBtn.Activated:Connect(function()
    P.auraDirIndex = P.auraDirIndex + 1; if P.auraDirIndex > #P.AURA_DIR then P.auraDirIndex = 1 end
    SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value
    auraDirBtn.Text = "  [◇] Направление: " .. P.AURA_DIR[P.auraDirIndex].name
end)
auraSpinBtn.Activated:Connect(function()
    SETTINGS.AuraSpinEnabled = not SETTINGS.AuraSpinEnabled
    auraSpinBtn.Text = "  [◇] Кручение: " .. (SETTINGS.AuraSpinEnabled and "ВКЛ" or "ВЫКЛ")
end)
auraSpinAxisBtn.Activated:Connect(function()
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1
    if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    auraSpinAxisBtn.Text = "  [◇] Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
auraSpinSpeedBtn.Activated:Connect(function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1
    if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    auraSpinSpeedBtn.Text = "  [◇] Скорость: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
end)
auraSpinResetBtn.Activated:Connect(function()
    ORBIT.auraSpinAngle = 0
    ORBIT.notify("> Вращение ауры сброшено", ACCENT)
end)
auraTrailBtn.Activated:Connect(function()
    SETTINGS.AuraTrailEnabled = not SETTINGS.AuraTrailEnabled
    auraTrailBtn.Text = "  [◇] Трейлы: " .. (SETTINGS.AuraTrailEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraTrailLenBtn.Activated:Connect(function()
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1
    if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    auraTrailLenBtn.Text = "  [◇] Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
end)
auraTrailWidBtn.Activated:Connect(function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1
    if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    auraTrailWidBtn.Text = "  [◇] Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
end)

colorBtn.Activated:Connect(function()
    P.colorIndex = P.colorIndex + 1; if P.colorIndex > #P.COLORS then P.colorIndex = 1 end
    ORBIT.applyColor()
    colorBtn.Text = "  [◆] Цвет: " .. P.COLORS[P.colorIndex].name
end)
lightBtn.Activated:Connect(function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "  [◇] Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
nameBtn.Activated:Connect(function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "  [◇] Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    ORBIT.applyNameVisibility()
end)

addAllRingsBtn.Activated:Connect(function()
    ORBIT.addRingsToAll()
    task.wait(0.1)
    for player, btn in pairs(ORBIT.peopleButtons) do
        if ORBIT.targetRings[player] then
            btn.Text = "  [●] " .. player.Name
            btn.TextColor3 = ACCENT
        end
    end
end)
remAllRingsBtn.Activated:Connect(function()
    ORBIT.removeRingsFromAll()
    for player, btn in pairs(ORBIT.peopleButtons) do
        btn.Text = "  [ ] " .. player.Name
        btn.TextColor3 = TEXT_DIM
    end
end)
toggleAllRingsBtn.Activated:Connect(function()
    ORBIT.toggleAllRings()
    task.wait(0.1)
    for player, btn in pairs(ORBIT.peopleButtons) do
        if ORBIT.targetRings[player] then
            btn.Text = "  [●] " .. player.Name
            btn.TextColor3 = ACCENT
        else
            btn.Text = "  [ ] " .. player.Name
            btn.TextColor3 = TEXT_DIM
        end
    end
end)

applyIdBtn.Activated:Connect(function()
    local ok = ORBIT.setMusicId(musicInput.Text)
    if ok then applyIdBtn.Text = "  [✓]!"; task.wait(1.2); applyIdBtn.Text = "  [✓] Применить ID"
    else applyIdBtn.Text = "  [×] Ошибка"; task.wait(1.5); applyIdBtn.Text = "  [✓] Применить ID" end
end)
musicBtn.Activated:Connect(function()
    if not ORBIT.musicSound or ORBIT.musicSound.SoundId == "" then
        musicBtn.Text = "  [×] Вставь ID!"; task.wait(1.2); musicBtn.Text = "  [♪] Музыка: ВЫКЛ"; return
    end
    ORBIT.musicEnabled = not ORBIT.musicEnabled
    if ORBIT.musicEnabled then ORBIT.musicSound:Play(); musicBtn.Text = "  [♪] Музыка: ВКЛ"
    else ORBIT.musicSound:Stop(); musicBtn.Text = "  [♪] Музыка: ВЫКЛ" end
end)

saveBtn.Activated:Connect(function()
    if musicInput.Text ~= "" then ORBIT.setMusicId(musicInput.Text) end
    local ok = ORBIT.saveSettings()
    if ok then
        saveBtn.Text = "  [✓] СОХРАНЕНО!"; task.wait(1.5); saveBtn.Text = "  [save] СОХРАНИТЬ"
        ORBIT.notify("> Настройки сохранены", ACCENT)
    else
        saveBtn.Text = "  [×] Ошибка"; task.wait(1.5); saveBtn.Text = "  [save] СОХРАНИТЬ"
    end
end)
loadBtn.Activated:Connect(function()
    if ORBIT.loadSettings() then
        ORBIT.notify("> Загружено", ACCENT)
        shapeCatBtn.Text = "  [◇] Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
        shapeBtn.Text = "  [◆] Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupFire then ORBIT.setupFire() end
    else
        ORBIT.notify("> Нет сохранения", Color3.fromRGB(255,100,100))
    end
end)
resetBtn.Activated:Connect(function()
    SETTINGS = table.clone(ORBIT.DEFAULT_SETTINGS)
    ORBIT.SETTINGS = SETTINGS
    ORBIT.notify("> Сброс выполнен", Color3.fromRGB(255,180,100))
end)
unloadBtn.Activated:Connect(function()
    pcall(function() ORBIT.unload() end)
end)

-- ==================== СПИСОК ЛЮДЕЙ ====================
local function rebuildPeopleList()
    for _, btn in pairs(ORBIT.peopleButtons) do pcall(function() btn:Destroy() end) end
    ORBIT.peopleButtons = {}
    local idx = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            idx = idx + 1
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = BG_DARK
            btn.BackgroundTransparency = 0.3
            btn.TextColor3 = TEXT_DIM
            btn.Font = Enum.Font.Code
            btn.TextSize = 11
            btn.Text = "  [ ] " .. player.Name
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.AutoButtonColor = false
            btn.LayoutOrder = idx
            btn.Parent = peopleList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            local bst = Instance.new("UIStroke", btn)
            bst.Color = ACCENT_DIM; bst.Thickness = 1; bst.Transparency = 0.6
            ORBIT.peopleButtons[player] = btn
            btn.Activated:Connect(function()
                ORBIT.toggleTargetRings(player)
                if ORBIT.targetRings[player] then
                    btn.Text = "  [●] " .. player.Name
                    btn.TextColor3 = ACCENT
                else
                    btn.Text = "  [ ] " .. player.Name
                    btn.TextColor3 = TEXT_DIM
                end
            end)
        end
    end
    if idx == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 26)
        empty.BackgroundTransparency = 1
        empty.Text = "> на сервере только ты"
        empty.TextColor3 = TEXT_DIM
        empty.Font = Enum.Font.Code
        empty.TextSize = 11
        empty.LayoutOrder = 1
        empty.Parent = peopleList
    end
end
rebuildPeopleList()

Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then task.wait(0.5); rebuildPeopleList() end end)
Players.PlayerRemoving:Connect(function(p)
    if p ~= LocalPlayer then
        ORBIT.removeTargetRings(p)
        task.wait(0.1); rebuildPeopleList()
    end
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            if ORBIT.targetRings[p] then
                task.wait(0.3); ORBIT.removeTargetRings(p); ORBIT.buildTargetRings(p)
            end
        end)
    end
end

-- ==================== УВЕДОМЛЕНИЯ ====================
local notifContainer = Instance.new("Frame")
notifContainer.Size = UDim2.new(0, 280, 0, 400)
notifContainer.Position = UDim2.new(1, -300, 0, 50)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui
getgenv()._OrbitNotifGui = notifContainer

task.spawn(function()
    local active = {}
    while screenGui and screenGui.Parent do
        if #ORBIT.NOTIF_QUEUE > 0 then
            local n = table.remove(ORBIT.NOTIF_QUEUE, 1)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 30)
            lbl.Position = UDim2.new(0, 0, 0, #active * 36)
            lbl.BackgroundColor3 = BG_DARK
            lbl.BackgroundTransparency = 0.2
            lbl.BorderSizePixel = 0
            lbl.TextColor3 = n.color or ACCENT
            lbl.Font = Enum.Font.Code
            lbl.TextSize = 11
            lbl.Text = "> " .. n.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = notifContainer
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
            local st = Instance.new("UIStroke", lbl)
            st.Color = ACCENT_DIM; st.Thickness = 1; st.Transparency = 0.4
            local padL = Instance.new("UIPadding", lbl)
            padL.PaddingLeft = UDim.new(0, 8)
            table.insert(active, lbl)
            task.spawn(function()
                task.wait(n.duration)
                TweenService:Create(lbl, TweenInfo.new(0.5), {BackgroundTransparency=1, TextTransparency=1}):Play()
                task.wait(0.5)
                for i, l in ipairs(active) do if l == lbl then table.remove(active, i); break end end
                lbl:Destroy()
                for i, l in ipairs(active) do l.Position = UDim2.new(0, 0, 0, (i-1)*36) end
            end)
        end
        task.wait(0.1)
    end
end)

-- ==================== СТАТИСТИКА ====================
task.spawn(function()
    while task.wait(0.5) do
        if statsLabel and statsLabel.Parent then
            local m = math.floor(statsData.sessionTime / 60)
            local s = math.floor(statsData.sessionTime % 60)
            local c = 0
            for _ in pairs(ORBIT.targetRings) do c = c + 1 end
            statsLabel.Text = string.format(
                "> FPS: %d  |  Фигур: %d\n> Время: %d:%02d\n> Целей: %d  |  Узор: %s",
                statsData.lastFPS, statsData.totalShapes, m, s, c, SETTINGS.OrbitPattern
            )
        end
    end
end)

-- ==================== ПЕРЕТАСКИВАНИЕ ====================
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

-- ==================== СТАРТ ====================
ORBIT.start = function()
    if getgenv()._OrbitLoaderGui then pcall(function() getgenv()._OrbitLoaderGui:Destroy() end) end
    ORBIT.startLogic()
    ORBIT.notify("ОРБИТА v20.0 запущена", ACCENT, 3)
    ORBIT.notify("Автосейв выкл — сохраняй вручную", Color3.fromRGB(255,220,120), 5)
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("Часть 4: матричный UI загружен", ACCENT, 3) end

return true
