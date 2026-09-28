--[[ ОРБИТА v20.0 — ЧАСТЬ 4/4: УЛУЧШЕННЫЙ ИНТЕРФЕЙС ]]

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
if not ORBIT.getShapeIndicesInCategory then warn("[Orbit P4] Функции категорий не найдены — обнови p3!"); return end

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

-- Кнопка открытия
local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, 60, 0, 60)
mainBtn.Position = UDim2.new(0, 20, 0, 100)
mainBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainBtn.TextColor3 = Color3.fromRGB(210, 200, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 26
mainBtn.Text = "✨"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", mainBtn)
mainStroke.Color = Color3.fromRGB(140, 100, 255); mainStroke.Thickness = 2
local mainGrad = Instance.new("UIGradient", mainBtn)
mainGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 45)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 35, 70)),
})

-- Панель
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 300, 0, 720)
panel.Position = UDim2.new(0, 90, 0, 5)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(120, 80, 220); panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.3

-- Верхняя цветная полоска панели
local topStripe = Instance.new("Frame")
topStripe.Size = UDim2.new(1, 0, 0, 5)
topStripe.BackgroundColor3 = Color3.fromRGB(140, 100, 255)
topStripe.BorderSizePixel = 0
topStripe.Parent = panel
Instance.new("UICorner", topStripe).CornerRadius = UDim.new(0, 14)

-- Заголовок
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.Position = UDim2.new(0, 0, 0, 5)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
local titleGrad = Instance.new("UIGradient", titleBar)
titleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 25, 45)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30)),
})

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -50, 0, 22)
titleText.Position = UDim2.new(0, 14, 0, 6)
titleText.BackgroundTransparency = 1
titleText.Text = "✨ ОРБИТА v20.0"
titleText.TextColor3 = Color3.fromRGB(230, 220, 255)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

local subtitleText = Instance.new("TextLabel")
subtitleText.Size = UDim2.new(1, -50, 0, 16)
subtitleText.Position = UDim2.new(0, 14, 0, 26)
subtitleText.BackgroundTransparency = 1
subtitleText.Text = "FIRE EDITION • категории фигур"
subtitleText.TextColor3 = Color3.fromRGB(255, 140, 60)
subtitleText.Font = Enum.Font.Gotham
subtitleText.TextSize = 9
subtitleText.TextXAlignment = Enum.TextXAlignment.Left
subtitleText.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.BackgroundTransparency = 0.3
closeBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Text = "✖"
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.Activated:Connect(function() panel.Visible = false end)

-- Скроллируемый список
local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, 0, 1, -55)
list.Position = UDim2.new(0, 0, 0, 55)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = Color3.fromRGB(140, 100, 255)
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)
layout.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 10)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = list

local order = 0
local function nextOrder() order = order + 1; return order end

-- Красивая секция-заголовок
local function makeSection(text, color)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 22)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = nextOrder()
    holder.Parent = list

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -4)
    bar.Position = UDim2.new(0, 0, 0, 2)
    bar.BackgroundColor3 = color or Color3.fromRGB(140, 100, 255)
    bar.BorderSizePixel = 0
    bar.Parent = holder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -12, 1, 0)
    s.Position = UDim2.new(0, 10, 0, 0)
    s.BackgroundTransparency = 1
    s.Text = text
    s.TextColor3 = Color3.fromRGB(220, 210, 255)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 11
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.Parent = holder
    return s
end

-- Красивая кнопка
local function makeButton(text, h, accentColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, h or 30)
    b.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
    b.TextColor3 = Color3.fromRGB(220, 215, 240)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Text = text
    b.AutoButtonColor = false
    b.LayoutOrder = nextOrder()
    b.Parent = list
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", b)
    stroke.Color = accentColor or Color3.fromRGB(70, 70, 100)
    stroke.Thickness = 1
    stroke.Transparency = 0.4

    -- Hover/press эффект через InputBegan/Ended
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(42, 42, 55)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(32, 32, 42)}):Play()
    end)
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(55, 50, 75)}):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(32, 32, 42)}):Play()
    end)
    return b
end

-- ==================== ОСНОВНОЕ ====================
makeSection("⚡ ОСНОВНОЕ", Color3.fromRGB(100, 100, 180))
local toggleBtn     = makeButton("🟢 ВКЛЮЧЕНО", 30, Color3.fromRGB(0, 200, 100))
local allRingsBtn   = makeButton("⭕ Все кольца: ВКЛ", 30, Color3.fromRGB(0, 180, 90))
local ring2Btn      = makeButton("➕ Кольцо 2", 28)
local ring3Btn      = makeButton("➕ Кольцо 3", 28)
local ring4Btn      = makeButton("➕ Кольцо 4", 28)
local ring5Btn      = makeButton("➕ Кольцо 5", 28)

-- ==================== КАТЕГОРИЯ + ФОРМА ====================
makeSection("🔷 ФОРМА И ФИГУРЫ", Color3.fromRGB(100, 150, 255))
local shapeCatBtn   = makeButton("📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, 32, Color3.fromRGB(140, 100, 255))
local shapeBtn      = makeButton("🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, 30, Color3.fromRGB(80, 120, 200))
local shapeModeBtn  = makeButton("🎭 Формы: " .. P.FORM_MODES[P.formModeIndex].name, 28)
local shapeSizeBtn  = makeButton("🔍 Фигура: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, 28)
local autoSwapBtn   = makeButton("🎭 Автосмена: ВЫКЛ", 28)

-- ==================== ОРБИТА ====================
makeSection("🛰️ ОРБИТА И ДВИЖЕНИЕ", Color3.fromRGB(100, 200, 150))
local orbitBtn      = makeButton("📏 Орбита: " .. P.ORBIT[P.orbitIndex].name, 28)
local spreadBtn     = makeButton("📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name, 28)
local heightBtn     = makeButton("⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name, 28)
local speedBtn      = makeButton("⚡ Множитель: " .. P.SPEED[P.speedIndex].name, 28)
local speedModeBtn  = makeButton("⚙️ Скорость: " .. P.SPEED_MODE[P.speedModeIndex].name, 28)
local directionBtn  = makeButton("🔃 Направление: " .. P.DIRECTION[P.directionIndex].name, 28)
local orbitPatternBtn = makeButton("🌀 Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, 28)

-- ==================== КРУЧЕНИЕ ====================
makeSection("🔄 КРУЧЕНИЕ", Color3.fromRGB(200, 120, 180))
local spinBtn       = makeButton("↩️ Вращение в 0", 28)
local spinAxisBtn   = makeButton("🔄 Кручение оси: ВКЛ", 28)
local spinDirBtn    = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 28)
local spinSpeedBtn  = makeButton("🌀 Скорость кручения: 1x", 28)

-- ==================== ЭФФЕКТЫ КОЛЕЦ ====================
makeSection("✨ ЭФФЕКТЫ КОЛЕЦ", Color3.fromRGB(220, 180, 100))
local trailBtn      = makeButton("🌠 Трейлы: ВЫКЛ", 28)
local trailLenBtn   = makeButton("📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name, 28)
local trailWidBtn   = makeButton("🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name, 28)
local waveBtn       = makeButton("🌊 Волна: ВЫКЛ", 28)
local explosionBtn  = makeButton("💥 Взрыв: ВЫКЛ", 28)
local pulseBtn      = makeButton("💓 Пульсация: ВЫКЛ", 28)
local gradientBtn   = makeButton("🌈 Градиент: ВЫКЛ", 28)

-- ==================== 🔥 ОГОНЬ ====================
makeSection("🔥 ОГОНЬ", Color3.fromRGB(255, 120, 40))
local fireBtn       = makeButton("🔥 Огонь: ВЫКЛ", 36, Color3.fromRGB(255, 120, 40))
local fireSizeBtn   = makeButton("📏 Размер огня: " .. P.FIRE_SIZE[P.fireSizeIndex].name, 28, Color3.fromRGB(255, 150, 80))
local fireHeatBtn   = makeButton("🌡️ Жар огня: " .. P.FIRE_HEAT[P.fireHeatIndex].name, 28, Color3.fromRGB(255, 150, 80))

-- ==================== АУРА: ЭЛЕМЕНТЫ ====================
makeSection("🌀 АУРА — ЭЛЕМЕНТЫ", Color3.fromRGB(150, 100, 220))
local auraBtn       = makeButton("🌀 Аура: ВЫКЛ", 30)
local auraRingBtn   = makeButton("⭕ Кольцо: ВКЛ", 28)
local auraPartBtn   = makeButton("✨ Частицы: ВЫКЛ", 28)
local auraFigBtn    = makeButton("🔷 Фигуры: ВЫКЛ", 28)
local auraShapeBtn  = makeButton("🔷 Форма: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, 28)
local auraColorBtn  = makeButton("🎨 Цвет: " .. P.COLORS[P.auraColorIndex].name, 28)

-- ==================== АУРА: РАЗМЕР ====================
makeSection("🌀 АУРА — РАЗМЕР", Color3.fromRGB(150, 100, 220))
local auraSizeBtn   = makeButton("📏 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name, 28)
local auraThickBtn  = makeButton("🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name, 28)
local auraHeightBtn = makeButton("⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, 28)
local auraScaleBtn  = makeButton("🔍 Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, 28)

-- ==================== АУРА: СКОРОСТЬ ====================
makeSection("🌀 АУРА — СКОРОСТЬ", Color3.fromRGB(150, 100, 220))
local auraSpeedBtn  = makeButton("⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, 28)
local auraDirBtn    = makeButton("🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name, 28)
local auraSpinBtn   = makeButton("🔄 Кручение: ВКЛ", 28)
local auraSpinAxisBtn = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 28)
local auraSpinSpeedBtn = makeButton("🌀 Скорость: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name, 28)
local auraSpinResetBtn = makeButton("↩️ Сброс вращения", 28)

-- ==================== АУРА: ТРЕЙЛЫ ====================
makeSection("🌀 АУРА — ТРЕЙЛЫ", Color3.fromRGB(150, 100, 220))
local auraTrailBtn    = makeButton("🌠 Трейлы ауры: ВЫКЛ", 28)
local auraTrailLenBtn = makeButton("📏 Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, 28)
local auraTrailWidBtn = makeButton("🎚️ Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, 28)

-- ==================== ЦВЕТ И СВЕТ ====================
makeSection("🎨 ЦВЕТ И СВЕТ", Color3.fromRGB(200, 180, 100))
local colorBtn      = makeButton("🎨 Цвет: " .. P.COLORS[P.colorIndex].name, 30)
local lightBtn      = makeButton("💡 Свет: ВКЛ", 28)
local nameBtn       = makeButton("🏷️ Имена: ВЫКЛ", 28)

-- ==================== ЛЮДИ ====================
makeSection("👥 ЛЮДИ И КОЛЬЦА", Color3.fromRGB(200, 100, 220))
local addAllRingsBtn  = makeButton("➕ Кольцо У ВСЕХ", 32, Color3.fromRGB(0, 200, 100))
local remAllRingsBtn  = makeButton("➖ УБРАТЬ У ВСЕХ", 32, Color3.fromRGB(220, 60, 60))
local toggleAllRingsBtn = makeButton("🔄 Переключить ВСЕМ", 30)

local peopleContainer = Instance.new("Frame")
peopleContainer.Size = UDim2.new(1, 0, 0, 180)
peopleContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
peopleContainer.BorderSizePixel = 0
peopleContainer.LayoutOrder = nextOrder()
peopleContainer.Parent = list
Instance.new("UICorner", peopleContainer).CornerRadius = UDim.new(0, 8)
local pStroke = Instance.new("UIStroke", peopleContainer)
pStroke.Color = Color3.fromRGB(80, 60, 140); pStroke.Thickness = 1; pStroke.Transparency = 0.5

local peopleList = Instance.new("ScrollingFrame")
peopleList.Size = UDim2.new(1, 0, 1, 0)
peopleList.BackgroundTransparency = 1
peopleList.BorderSizePixel = 0
peopleList.CanvasSize = UDim2.new(0, 0, 0, 0)
peopleList.AutomaticCanvasSize = Enum.AutomaticSize.Y
peopleList.ScrollBarThickness = 3
peopleList.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 220)
peopleList.ScrollingDirection = Enum.ScrollingDirection.Y
peopleList.Parent = peopleContainer
local peopleLayout = Instance.new("UIListLayout")
peopleLayout.SortOrder = Enum.SortOrder.LayoutOrder
peopleLayout.Padding = UDim.new(0, 4)
peopleLayout.Parent = peopleList
local peoplePad = Instance.new("UIPadding")
peoplePad.PaddingTop = UDim.new(0, 4); peoplePad.PaddingBottom = UDim.new(0, 4)
peoplePad.PaddingLeft = UDim.new(0, 4); peoplePad.PaddingRight = UDim.new(0, 4)
peoplePad.Parent = peopleList

-- ==================== СТАТИСТИКА ====================
makeSection("📊 СТАТИСТИКА", Color3.fromRGB(120, 120, 180))
local statsCard = Instance.new("Frame")
statsCard.Size = UDim2.new(1, 0, 0, 60)
statsCard.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsCard.BorderSizePixel = 0
statsCard.LayoutOrder = nextOrder()
statsCard.Parent = list
Instance.new("UICorner", statsCard).CornerRadius = UDim.new(0, 8)
local sStroke = Instance.new("UIStroke", statsCard)
sStroke.Color = Color3.fromRGB(80, 120, 80); sStroke.Thickness = 1; sStroke.Transparency = 0.5

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -16, 1, -8)
statsLabel.Position = UDim2.new(0, 8, 0, 4)
statsLabel.BackgroundTransparency = 1
statsLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "FPS: -- | Фигур: 0 | Время: 0 сек"
statsLabel.Parent = statsCard

-- ==================== МУЗЫКА ====================
makeSection("🎵 МУЗЫКА", Color3.fromRGB(180, 100, 220))
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, 0, 0, 32)
musicInput.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
musicInput.TextColor3 = Color3.fromRGB(240, 230, 255)
musicInput.Font = Enum.Font.GothamBold
musicInput.TextSize = 12
musicInput.PlaceholderText = "Пример: 1839246711"
musicInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
musicInput.Text = ""
musicInput.ClearTextOnFocus = false
musicInput.LayoutOrder = nextOrder()
musicInput.Parent = list
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 8)
local mStroke = Instance.new("UIStroke", musicInput)
mStroke.Color = Color3.fromRGB(180, 140, 255); mStroke.Thickness = 1; mStroke.Transparency = 0.4

local applyIdBtn = makeButton("✅ Применить ID", 28, Color3.fromRGB(60, 180, 100))
local musicBtn   = makeButton("🎵 Музыка: ВЫКЛ", 28, Color3.fromRGB(180, 100, 220))

-- ==================== СИСТЕМА ====================
makeSection("💾 СИСТЕМА", Color3.fromRGB(120, 120, 120))
local saveBtn   = makeButton("💾 СОХРАНИТЬ", 36, Color3.fromRGB(60, 180, 100))
local loadBtn   = makeButton("📂 ЗАГРУЗИТЬ", 34, Color3.fromRGB(80, 140, 220))
local resetBtn  = makeButton("🔄 СБРОС", 32, Color3.fromRGB(220, 60, 60))
local unloadBtn = makeButton("❌ ВЫГРУЗИТЬ СКРИПТ", 32, Color3.fromRGB(200, 40, 40))

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, 0, 0, 26)
hintLabel.BackgroundColor3 = Color3.fromRGB(40, 32, 55)
hintLabel.BackgroundTransparency = 0.4
hintLabel.BorderSizePixel = 0
hintLabel.Text = "⚠️ Автосейв ВЫКЛ — жми 💾 вручную"
hintLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 10
hintLabel.LayoutOrder = nextOrder()
hintLabel.Parent = list
Instance.new("UICorner", hintLabel).CornerRadius = UDim.new(0, 6)

-- ==================== ОБРАБОТЧИКИ ====================
local ringButtons = { [2]=ring2Btn, [3]=ring3Btn, [4]=ring4Btn, [5]=ring5Btn }

local function refreshRingButton(ri)
    local btn = ringButtons[ri]; if not btn then return end
    if rings[ri].enabled then
        btn.Text = "➖ Убрать кольцо " .. ri
        btn.TextColor3 = Color3.fromRGB(255, 160, 160)
    else
        btn.Text = "➕ Кольцо " .. ri
        btn.TextColor3 = Color3.fromRGB(160, 255, 160)
    end
end

mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)

toggleBtn.Activated:Connect(function()
    ORBIT.setEnabled(not ORBIT.enabled)
    if ORBIT.enabled then toggleBtn.Text = "🟢 ВКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(0,255,120)
    else toggleBtn.Text = "🔴 ВЫКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(255,80,80) end
end)

allRingsBtn.Activated:Connect(function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local ns = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= ns then ORBIT.setRingEnabled(ri, ns) end end
    for ri = 2, 5 do refreshRingButton(ri) end
    if ns then allRingsBtn.Text = "⭕ Все кольца: ВЫКЛ"; allRingsBtn.TextColor3 = Color3.fromRGB(255,160,160)
    else allRingsBtn.Text = "⭕ Все кольца: ВКЛ"; allRingsBtn.TextColor3 = Color3.fromRGB(160,255,160) end
end)

for ri, btn in pairs(ringButtons) do
    btn.Activated:Connect(function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

-- Категории
shapeCatBtn.Activated:Connect(function()
    P.shapeCategoryIndex = P.shapeCategoryIndex + 1
    if P.shapeCategoryIndex > #P.SHAPE_CATEGORIES then P.shapeCategoryIndex = 1 end
    shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs > 0 then
        ORBIT.shapeIndex = idxs[1]
        shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
    end
    ORBIT.notify("📁 " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, Color3.fromRGB(200,180,255))
end)

shapeBtn.Activated:Connect(function()
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs == 0 then return end
    local pos = nil
    for i, v in ipairs(idxs) do if v == ORBIT.shapeIndex then pos = i; break end end
    local newPos = pos and (pos % #idxs) + 1 or 1
    ORBIT.shapeIndex = idxs[newPos]
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
end)

shapeModeBtn.Activated:Connect(function()
    P.formModeIndex = P.formModeIndex + 1
    if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Формы: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
end)
shapeSizeBtn.Activated:Connect(function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1
    if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "🔍 Фигура: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
end)
autoSwapBtn.Activated:Connect(function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "🎭 Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then ORBIT.lastAutoSwap = tick() end
end)

orbitBtn.Activated:Connect(function()
    P.orbitIndex = P.orbitIndex + 1; if P.orbitIndex > #P.ORBIT then P.orbitIndex = 1 end
    orbitBtn.Text = "📏 Орбита: " .. P.ORBIT[P.orbitIndex].name
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
    speedBtn.Text = "⚡ Множитель: " .. P.SPEED[P.speedIndex].name
end)
speedModeBtn.Activated:Connect(function()
    P.speedModeIndex = P.speedModeIndex + 1; if P.speedModeIndex > #P.SPEED_MODE then P.speedModeIndex = 1 end
    speedModeBtn.Text = "⚙️ Скорость: " .. P.SPEED_MODE[P.speedModeIndex].name
    ORBIT.applySpeedModePreset()
end)
directionBtn.Activated:Connect(function()
    P.directionIndex = P.directionIndex + 1; if P.directionIndex > #P.DIRECTION then P.directionIndex = 1 end
    directionBtn.Text = "🔃 Направление: " .. P.DIRECTION[P.directionIndex].name
    ORBIT.applyDirectionPreset()
end)
orbitPatternBtn.Activated:Connect(function()
    P.orbitPatternIndex = P.orbitPatternIndex + 1; if P.orbitPatternIndex > #P.ORBIT_PATTERNS then P.orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name
    orbitPatternBtn.Text = "🌀 Узор: " .. SETTINGS.OrbitPattern
end)

spinBtn.Activated:Connect(function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    spinBtn.Text = ORBIT.spinResetting and "↩️ Вращение: ВОЗВРАТ" or "↩️ Вращение в 0"
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
    spinSpeedBtn.Text = "🌀 Скорость кручения: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

trailBtn.Activated:Connect(function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
trailLenBtn.Activated:Connect(function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    trailLenBtn.Text = "📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
trailWidBtn.Activated:Connect(function()
    P.trailWidthIndex = P.trailWidthIndex + 1; if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    trailWidBtn.Text = "🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
waveBtn.Activated:Connect(function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    waveBtn.Text = "🌊 Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
end)
explosionBtn.Activated:Connect(function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    explosionBtn.Text = "💥 Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
end)
pulseBtn.Activated:Connect(function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    pulseBtn.Text = "💓 Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
end)
gradientBtn.Activated:Connect(function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    gradientBtn.Text = "🌈 Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then SETTINGS.Rainbow = false end
    ORBIT.rebuildAllRings()
end)

-- 🔥 ОГОНЬ
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

-- АУРА
auraBtn.Activated:Connect(function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    auraBtn.Text = "🌀 Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura()
    else if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end end
end)
auraRingBtn.Activated:Connect(function()
    SETTINGS.AuraRing = not SETTINGS.AuraRing
    auraRingBtn.Text = "⭕ Кольцо: " .. (SETTINGS.AuraRing and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraPartBtn.Activated:Connect(function()
    SETTINGS.AuraParticles = not SETTINGS.AuraParticles
    auraPartBtn.Text = "✨ Частицы: " .. (SETTINGS.AuraParticles and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraFigBtn.Activated:Connect(function()
    SETTINGS.AuraShapes = not SETTINGS.AuraShapes
    auraFigBtn.Text = "🔷 Фигуры: " .. (SETTINGS.AuraShapes and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraShapeBtn.Activated:Connect(function()
    ORBIT.auraShapeIndex = ORBIT.auraShapeIndex + 1
    if ORBIT.auraShapeIndex > #SHAPE_PRESETS then ORBIT.auraShapeIndex = 1 end
    auraShapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraColorBtn.Activated:Connect(function()
    P.auraColorIndex = P.auraColorIndex + 1
    if P.auraColorIndex > #P.COLORS then P.auraColorIndex = 1 end
    local ac = P.COLORS[P.auraColorIndex]
    if ac.c then SETTINGS.AuraColor = ac.c end
    auraColorBtn.Text = "🎨 Цвет: " .. ac.name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraSizeBtn.Activated:Connect(function()
    P.auraSizeIndex = P.auraSizeIndex + 1; if P.auraSizeIndex > #P.AURA_SIZE then P.auraSizeIndex = 1 end
    SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value
    auraSizeBtn.Text = "📏 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraThickBtn.Activated:Connect(function()
    P.auraThickIndex = P.auraThickIndex + 1; if P.auraThickIndex > #P.AURA_THICK then P.auraThickIndex = 1 end
    SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value
    auraThickBtn.Text = "🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraHeightBtn.Activated:Connect(function()
    P.auraHeightIndex = P.auraHeightIndex + 1; if P.auraHeightIndex > #P.AURA_HEIGHT then P.auraHeightIndex = 1 end
    SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value
    auraHeightBtn.Text = "⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
end)
auraScaleBtn.Activated:Connect(function()
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1
    if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
    SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor
    auraScaleBtn.Text = "🔍 Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraSpeedBtn.Activated:Connect(function()
    P.auraSpeedIndex = P.auraSpeedIndex + 1; if P.auraSpeedIndex > #P.AURA_SPEED then P.auraSpeedIndex = 1 end
    SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value
    auraSpeedBtn.Text = "⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
end)
auraDirBtn.Activated:Connect(function()
    P.auraDirIndex = P.auraDirIndex + 1; if P.auraDirIndex > #P.AURA_DIR then P.auraDirIndex = 1 end
    SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value
    auraDirBtn.Text = "🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name
end)
auraSpinBtn.Activated:Connect(function()
    SETTINGS.AuraSpinEnabled = not SETTINGS.AuraSpinEnabled
    auraSpinBtn.Text = "🔄 Кручение: " .. (SETTINGS.AuraSpinEnabled and "ВКЛ" or "ВЫКЛ")
end)
auraSpinAxisBtn.Activated:Connect(function()
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1
    if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    auraSpinAxisBtn.Text = "↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
auraSpinSpeedBtn.Activated:Connect(function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1
    if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    auraSpinSpeedBtn.Text = "🌀 Скорость: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
end)
auraSpinResetBtn.Activated:Connect(function()
    ORBIT.auraSpinAngle = 0
    ORBIT.notify("↩️ Сброс вращения ауры", Color3.fromRGB(200,180,255))
end)
auraTrailBtn.Activated:Connect(function()
    SETTINGS.AuraTrailEnabled = not SETTINGS.AuraTrailEnabled
    auraTrailBtn.Text = "🌠 Трейлы ауры: " .. (SETTINGS.AuraTrailEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraTrailLenBtn.Activated:Connect(function()
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1
    if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    auraTrailLenBtn.Text = "📏 Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
end)
auraTrailWidBtn.Activated:Connect(function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1
    if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    auraTrailWidBtn.Text = "🎚️ Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
end)

colorBtn.Activated:Connect(function()
    P.colorIndex = P.colorIndex + 1; if P.colorIndex > #P.COLORS then P.colorIndex = 1 end
    ORBIT.applyColor()
    colorBtn.Text = "🎨 Цвет: " .. P.COLORS[P.colorIndex].name
end)
lightBtn.Activated:Connect(function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
nameBtn.Activated:Connect(function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "🏷️ Имена: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    ORBIT.applyNameVisibility()
end)

addAllRingsBtn.Activated:Connect(function()
    ORBIT.addRingsToAll()
    task.wait(0.1)
    for player, btn in pairs(ORBIT.peopleButtons) do
        if ORBIT.targetRings[player] then
            btn.Text = "✅ " .. player.Name
            btn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
            btn.TextColor3 = Color3.fromRGB(255, 200, 255)
        end
    end
end)
remAllRingsBtn.Activated:Connect(function()
    ORBIT.removeRingsFromAll()
    for player, btn in pairs(ORBIT.peopleButtons) do
        btn.Text = "🔷 " .. player.Name
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        btn.TextColor3 = Color3.fromRGB(220, 220, 255)
    end
end)
toggleAllRingsBtn.Activated:Connect(function()
    ORBIT.toggleAllRings()
    task.wait(0.1)
    for player, btn in pairs(ORBIT.peopleButtons) do
        if ORBIT.targetRings[player] then
            btn.Text = "✅ " .. player.Name
            btn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
            btn.TextColor3 = Color3.fromRGB(255, 200, 255)
        else
            btn.Text = "🔷 " .. player.Name
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            btn.TextColor3 = Color3.fromRGB(220, 220, 255)
        end
    end
end)

applyIdBtn.Activated:Connect(function()
    local ok = ORBIT.setMusicId(musicInput.Text)
    if ok then applyIdBtn.Text = "✅!"; task.wait(1.2); applyIdBtn.Text = "✅ Применить ID"
    else applyIdBtn.Text = "❌"; task.wait(1.5); applyIdBtn.Text = "✅ Применить ID" end
end)
musicBtn.Activated:Connect(function()
    if not ORBIT.musicSound or ORBIT.musicSound.SoundId == "" then
        musicBtn.Text = "❌ Вставь ID!"; task.wait(1.2); musicBtn.Text = "🎵 Музыка: ВЫКЛ"; return
    end
    ORBIT.musicEnabled = not ORBIT.musicEnabled
    if ORBIT.musicEnabled then ORBIT.musicSound:Play(); musicBtn.Text = "🎵 Музыка: ВКЛ"
    else ORBIT.musicSound:Stop(); musicBtn.Text = "🎵 Музыка: ВЫКЛ" end
end)

saveBtn.Activated:Connect(function()
    if musicInput.Text ~= "" then ORBIT.setMusicId(musicInput.Text) end
    local ok = ORBIT.saveSettings()
    if ok then
        saveBtn.Text = "✅ СОХРАНЕНО!"; task.wait(1.5); saveBtn.Text = "💾 СОХРАНИТЬ"
        ORBIT.notify("💾 Сохранено", Color3.fromRGB(160,255,180))
    else
        saveBtn.Text = "❌ Ошибка"; task.wait(1.5); saveBtn.Text = "💾 СОХРАНИТЬ"
    end
end)
loadBtn.Activated:Connect(function()
    if ORBIT.loadSettings() then
        ORBIT.notify("📂 Загружено", Color3.fromRGB(180,220,255))
        shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
        shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupFire then ORBIT.setupFire() end
    else
        ORBIT.notify("❌ Нет сохранения", Color3.fromRGB(255,120,120))
    end
end)
resetBtn.Activated:Connect(function()
    SETTINGS = table.clone(ORBIT.DEFAULT_SETTINGS)
    ORBIT.SETTINGS = SETTINGS
    ORBIT.notify("🔄 Сброс выполнен", Color3.fromRGB(255,180,180))
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
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
            btn.TextColor3 = Color3.fromRGB(220, 220, 255)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            btn.Text = "🔷 " .. player.Name
            btn.LayoutOrder = idx
            btn.Parent = peopleList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            local bst = Instance.new("UIStroke", btn)
            bst.Color = Color3.fromRGB(70, 60, 120); bst.Thickness = 1; bst.Transparency = 0.5
            ORBIT.peopleButtons[player] = btn
            btn.Activated:Connect(function()
                ORBIT.toggleTargetRings(player)
                if ORBIT.targetRings[player] then
                    btn.Text = "✅ " .. player.Name
                    btn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
                    btn.TextColor3 = Color3.fromRGB(255, 200, 255)
                else
                    btn.Text = "🔷 " .. player.Name
                    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
                    btn.TextColor3 = Color3.fromRGB(220, 220, 255)
                end
            end)
        end
    end
    if idx == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 28)
        empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140, 140, 170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
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
notifContainer.Size = UDim2.new(0, 260, 0, 300)
notifContainer.Position = UDim2.new(1, -280, 0, 50)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui
getgenv()._OrbitNotifGui = notifContainer

task.spawn(function()
    local active = {}
    while screenGui and screenGui.Parent do
        if #ORBIT.NOTIF_QUEUE > 0 then
            local n = table.remove(ORBIT.NOTIF_QUEUE, 1)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 32)
            lbl.Position = UDim2.new(0, 0, 0, #active*38)
            lbl.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
            lbl.BackgroundTransparency = 0.15
            lbl.BorderSizePixel = 0
            lbl.TextColor3 = n.color
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 12
            lbl.Text = " " .. n.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = notifContainer
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
            local st = Instance.new("UIStroke", lbl)
            st.Color = n.color; st.Thickness = 1; st.Transparency = 0.4
            table.insert(active, lbl)
            task.spawn(function()
                task.wait(n.duration)
                TweenService:Create(lbl, TweenInfo.new(0.5), {BackgroundTransparency=1, TextTransparency=1}):Play()
                task.wait(0.5)
                for i, l in ipairs(active) do if l == lbl then table.remove(active, i); break end end
                lbl:Destroy()
                for i, l in ipairs(active) do l.Position = UDim2.new(0, 0, 0, (i-1)*38) end
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
                "📊 FPS: %d  |  🔷 Фигур: %d\n⏱️ Время: %d:%02d  |  🌀 %s\n🎯 Целей: %d",
                statsData.lastFPS, statsData.totalShapes, m, s, SETTINGS.OrbitPattern, c
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
    ORBIT.notify("✨ ОРБИТА v20.0 запущена!", Color3.fromRGB(200,200,255), 3)
    ORBIT.notify("💾 Автосейв ВЫКЛ — сохраняй вручную", Color3.fromRGB(255,220,120), 5)
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ Часть 4: интерфейс загружен", Color3.fromRGB(180,255,180), 3) end

return true
