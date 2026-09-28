--[[ ОРБИТА v20.1 — ЧАСТЬ 4/4: ИНТЕРФЕЙС (clean build) ]]

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
if not SHAPE_PRESETS then warn("[Orbit P4] Часть 2 не загружена"); return end
if not ORBIT.startUpdateLoop then warn("[Orbit P4] Часть 3 не загружена"); return end

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

local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, 56, 0, 56)
mainBtn.Position = UDim2.new(0, 20, 0, 100)
mainBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainBtn.BackgroundTransparency = 0.1
mainBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = 24
mainBtn.Text = "✨"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 14)
local ms = Instance.new("UIStroke", mainBtn)
ms.Color = Color3.fromRGB(120, 120, 255); ms.Thickness = 1.5

local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 280, 0, 720)
panel.Position = UDim2.new(0, 90, 0, 5)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 0)
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.ScrollBarThickness = 4
panel.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local ps = Instance.new("UIStroke", panel)
ps.Color = Color3.fromRGB(120, 120, 255); ps.Thickness = 1

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.Parent = panel

local order = 0
local function nextOrder() order = order + 1; return order end

local function makeSection(text, color)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -8, 0, 20)
    s.BackgroundTransparency = 0.6
    s.BackgroundColor3 = color or Color3.fromRGB(50, 50, 80)
    s.BorderSizePixel = 0; s.Text = "▸ " .. text
    s.TextColor3 = Color3.fromRGB(220, 220, 255)
    s.Font = Enum.Font.GothamBold; s.TextSize = 11
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.LayoutOrder = nextOrder()
    s.Parent = panel
    Instance.new("UICorner", s).CornerRadius = UDim.new(0, 6)
    return s
end

local function makeButton(text, h, bg, tc)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -8, 0, h or 28)
    b.BackgroundColor3 = bg or Color3.fromRGB(40, 40, 55)
    b.TextColor3 = tc or Color3.fromRGB(230, 230, 255)
    b.Font = Enum.Font.GothamBold; b.TextSize = 11; b.Text = text
    b.AutoButtonColor = true; b.LayoutOrder = nextOrder()
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

-- ==================== ШАПКА ====================
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -8, 0, 24)
title.BackgroundTransparency = 1
title.Text = "✨ ОРБИТА v20.1 — ULTIMATE"
title.TextColor3 = Color3.fromRGB(200, 200, 255)
title.Font = Enum.Font.GothamBold; title.TextSize = 12
title.LayoutOrder = nextOrder()
title.Parent = panel

-- ==================== ОСНОВНОЕ ====================
makeSection("⚡ ОСНОВНОЕ", Color3.fromRGB(60, 60, 100))
local toggleBtn     = makeButton("🟢 ВКЛЮЧЕНО", 28, Color3.fromRGB(40,40,55), Color3.fromRGB(0,255,120))
local allRingsBtn   = makeButton("⭕ Все кольца: ВКЛ", 28, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring2Btn      = makeButton("➕ Кольцо 2", 28, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring3Btn      = makeButton("➕ Кольцо 3", 28, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring4Btn      = makeButton("➕ Кольцо 4", 28, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring5Btn      = makeButton("➕ Кольцо 5", 28, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))

-- ==================== ФОРМА ====================
makeSection("🔷 ФОРМА И ФИГУРЫ", Color3.fromRGB(60, 80, 100))
local shapeBtn      = makeButton("🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, 28)
local shapeModeBtn  = makeButton("🎭 Формы: " .. P.FORM_MODES[P.formModeIndex].name, 28, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255))
local shapeSizeBtn  = makeButton("🔍 Фигура: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, 28)
local autoSwapBtn   = makeButton("🎭 Автосмена: ВЫКЛ", 28, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255))

-- ==================== ОРБИТА ====================
makeSection("🛰️ ОРБИТА И ДВИЖЕНИЕ", Color3.fromRGB(60, 100, 80))
local orbitBtn      = makeButton("📏 Орбита: " .. P.ORBIT[P.orbitIndex].name, 28)
local spreadBtn     = makeButton("📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name, 28, Color3.fromRGB(55,30,55), Color3.fromRGB(255,180,255))
local heightBtn     = makeButton("⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name, 28, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local speedBtn      = makeButton("⚡ Множитель: " .. P.SPEED[P.speedIndex].name, 28, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100))
local speedModeBtn  = makeButton("⚙️ Скорость: " .. P.SPEED_MODE[P.speedModeIndex].name, 28, Color3.fromRGB(45,50,65), Color3.fromRGB(180,220,255))
local directionBtn  = makeButton("🔃 Направление: " .. P.DIRECTION[P.directionIndex].name, 28, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255))
local orbitPatternBtn = makeButton("🌀 Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, 28, Color3.fromRGB(60,40,90), Color3.fromRGB(220,180,255))

-- ==================== КРУЧЕНИЕ ====================
makeSection("🔄 КРУЧЕНИЕ", Color3.fromRGB(100, 60, 80))
local spinBtn       = makeButton("↩️ Вращение в 0", 28, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255))
local spinAxisBtn   = makeButton("🔄 Кручение оси: ВКЛ", 28, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220))
local spinDirBtn    = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 28, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255))
local spinSpeedBtn  = makeButton("🌀 Скорость кручения: 1x", 28, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255))

-- ==================== ЭФФЕКТЫ КОЛЕЦ ====================
makeSection("✨ ЭФФЕКТЫ КОЛЕЦ", Color3.fromRGB(100, 80, 60))
local trailBtn      = makeButton("🌠 Трейлы: ВЫКЛ", 28, Color3.fromRGB(35,35,50))
local trailLenBtn   = makeButton("📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local trailWidBtn   = makeButton("🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local waveBtn       = makeButton("🌊 Волна: ВЫКЛ", 28, Color3.fromRGB(30,55,75), Color3.fromRGB(140,220,255))
local explosionBtn  = makeButton("💥 Взрыв: ВЫКЛ", 28, Color3.fromRGB(70,40,30), Color3.fromRGB(255,180,120))
local pulseBtn      = makeButton("💓 Пульсация: ВЫКЛ", 28, Color3.fromRGB(35,35,50))
local gradientBtn   = makeButton("🌈 Градиент: ВЫКЛ", 28, Color3.fromRGB(55,35,75), Color3.fromRGB(255,180,255))

-- ==================== АУРА - ЭЛЕМЕНТЫ ====================
makeSection("🌀 АУРА — ЭЛЕМЕНТЫ", Color3.fromRGB(80, 60, 120))
local auraBtn       = makeButton("🌀 Аура: ВЫКЛ", 28, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255))
local auraRingBtn   = makeButton("⭕ Кольцо: ВКЛ", 28, Color3.fromRGB(35,55,35), Color3.fromRGB(160,255,160))
local auraPartBtn   = makeButton("✨ Частицы: ВЫКЛ", 28, Color3.fromRGB(35,50,55), Color3.fromRGB(180,220,255))
local auraFigBtn    = makeButton("🔷 Фигуры: ВЫКЛ", 28, Color3.fromRGB(45,35,65), Color3.fromRGB(220,180,255))
local auraShapeBtn  = makeButton("🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, 28, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255))
local auraColorBtn  = makeButton("🎨 Цвет ауры: " .. P.COLORS[P.auraColorIndex].name, 28, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255))
local auraPulseBtn  = makeButton("💓 Пульсация ауры: ВЫКЛ", 28, Color3.fromRGB(35,35,50), Color3.fromRGB(220,180,255))

-- ==================== АУРА - РАЗМЕР ====================
makeSection("🌀 АУРА — РАЗМЕР", Color3.fromRGB(80, 60, 120))
local auraSizeBtn   = makeButton("📏 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name, 28, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local auraThickBtn  = makeButton("🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local auraHeightBtn = makeButton("⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, 28, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local auraScaleBtn  = makeButton("🔍 Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, 28, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255))

-- ==================== АУРА - СКОРОСТЬ ====================
makeSection("🌀 АУРА — СКОРОСТЬ", Color3.fromRGB(80, 60, 120))
local auraSpeedBtn  = makeButton("⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, 28, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100))
local auraDirBtn    = makeButton("🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name, 28, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255))
local auraSpinBtn   = makeButton("🔄 Кручение: ВКЛ", 28, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220))
local auraSpinAxisBtn = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 28, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255))
local auraSpinSpeedBtn = makeButton("🌀 Скорость кручения: 0.5x", 28, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255))
local auraSpinResetBtn = makeButton("↩️ Сброс вращения", 28, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255))

-- ==================== АУРА - ТРЕЙЛЫ ====================
makeSection("🌀 АУРА — ТРЕЙЛЫ", Color3.fromRGB(80, 60, 120))
local auraTrailBtn    = makeButton("🌠 Трейлы ауры: ВЫКЛ", 28, Color3.fromRGB(35,35,50))
local auraTrailLenBtn = makeButton("📏 Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local auraTrailWidBtn = makeButton("🎚️ Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, 28, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))

-- ==================== ЭФФЕКТЫ (ULTIMATE) ====================
makeSection("🔥 ЭФФЕКТЫ ULTIMATE", Color3.fromRGB(150, 80, 40))
local lightningBtn   = makeButton("⚡ Молния: ВЫКЛ", 28, Color3.fromRGB(50,45,20), Color3.fromRGB(255,220,100))
local fireBtn        = makeButton("🔥 Огонь: ВЫКЛ", 28, Color3.fromRGB(80,30,10), Color3.fromRGB(255,140,60))
local smokeBtn       = makeButton("🌫️ Дым: ВЫКЛ", 28, Color3.fromRGB(50,50,55), Color3.fromRGB(200,200,210))
local snowBtn        = makeButton("❄️ Снег: ВЫКЛ", 28, Color3.fromRGB(40,55,80), Color3.fromRGB(220,240,255))
local confettiBtn    = makeButton("🎉 Конфетти: ВЫКЛ", 28, Color3.fromRGB(80,40,80), Color3.fromRGB(255,140,220))
local sparklesBtn    = makeButton("✨ Искры: ВЫКЛ", 28, Color3.fromRGB(60,60,40), Color3.fromRGB(255,255,180))
local groundRippleBtn = makeButton("💫 Риппл: ВЫКЛ", 28, Color3.fromRGB(30,50,60), Color3.fromRGB(120,220,255))
local portalBtn      = makeButton("🌀 Портал: ВЫКЛ", 28, Color3.fromRGB(60,40,90), Color3.fromRGB(200,160,255))
local waveBurstBtn   = makeButton("🌊 Волновой выброс: ВЫКЛ", 28, Color3.fromRGB(30,55,75), Color3.fromRGB(140,220,255))
local ringPulseBtn   = makeButton("💓 Пульс кольца: ВЫКЛ", 28, Color3.fromRGB(35,35,50), Color3.fromRGB(255,200,220))
local beamBtn        = makeButton("🔦 Луч: ВЫКЛ", 28, Color3.fromRGB(40,60,55), Color3.fromRGB(140,255,220))
local starfieldBtn   = makeButton("⭐ Звёзды: ВЫКЛ", 28, Color3.fromRGB(30,30,50), Color3.fromRGB(255,255,200))
local haloBtn        = makeButton("😇 Ореол: ВЫКЛ", 28, Color3.fromRGB(70,60,30), Color3.fromRGB(255,220,120))
local spikesBtn      = makeButton("🗡️ Шипы: ВЫКЛ", 28, Color3.fromRGB(70,30,30), Color3.fromRGB(255,120,120))

-- ==================== ЦВЕТ И СВЕТ ====================
makeSection("🎨 ЦВЕТ И СВЕТ", Color3.fromRGB(100, 100, 50))
local colorBtn      = makeButton("🎨 Цвет: " .. P.COLORS[P.colorIndex].name, 28)
local lightBtn      = makeButton("💡 Свет: ВКЛ", 28, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local nameBtn       = makeButton("🏷️ Имена: ВЫКЛ", 28)

-- ==================== ЛЮДИ ====================
makeSection("👥 ЛЮДИ И КОЛЬЦА", Color3.fromRGB(80, 40, 100))
local addAllRingsBtn  = makeButton("➕ Кольцо У ВСЕХ", 30, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180))
local remAllRingsBtn  = makeButton("➖ УБРАТЬ У ВСЕХ", 30, Color3.fromRGB(70,40,40), Color3.fromRGB(255,160,160))
local toggleAllRingsBtn = makeButton("🔄 Переключить ВСЕМ", 30, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255))

local peopleContainer = Instance.new("ScrollingFrame")
peopleContainer.Size = UDim2.new(1, -8, 0, 180)
peopleContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
peopleContainer.BorderSizePixel = 0
peopleContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
peopleContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
peopleContainer.ScrollBarThickness = 3
peopleContainer.ScrollBarImageColor3 = Color3.fromRGB(150,100,200)
peopleContainer.ScrollingDirection = Enum.ScrollingDirection.Y
peopleContainer.LayoutOrder = nextOrder()
peopleContainer.Parent = panel
Instance.new("UICorner", peopleContainer).CornerRadius = UDim.new(0, 8)
local peopleLayout = Instance.new("UIListLayout")
peopleLayout.SortOrder = Enum.SortOrder.LayoutOrder
peopleLayout.Padding = UDim.new(0, 4)
peopleLayout.Parent = peopleContainer
local peoplePadding = Instance.new("UIPadding")
peoplePadding.PaddingTop = UDim.new(0, 4); peoplePadding.PaddingBottom = UDim.new(0, 4)
peoplePadding.PaddingLeft = UDim.new(0, 4); peoplePadding.PaddingRight = UDim.new(0, 4)
peoplePadding.Parent = peopleContainer

-- ==================== СТАТИСТИКА ====================
makeSection("📊 СТАТИСТИКА", Color3.fromRGB(60, 60, 90))
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -8, 0, 56)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
statsLabel.Font = Enum.Font.Gotham; statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "FPS: -- | Фигур: 0 | Время: 0 сек"
statsLabel.LayoutOrder = nextOrder()
statsLabel.Parent = panel
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)

-- ==================== МУЗЫКА ====================
makeSection("🎵 МУЗЫКА", Color3.fromRGB(80, 60, 100))
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -8, 0, 32)
musicInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
musicInput.BackgroundTransparency = 0.1
musicInput.TextColor3 = Color3.fromRGB(240, 230, 255)
musicInput.Font = Enum.Font.GothamBold; musicInput.TextSize = 12
musicInput.PlaceholderText = "Пример: 1839246711"
musicInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
musicInput.Text = ""; musicInput.ClearTextOnFocus = false
musicInput.LayoutOrder = nextOrder()
musicInput.Parent = panel
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 8)
local inputStroke = Instance.new("UIStroke", musicInput)
inputStroke.Color = Color3.fromRGB(180, 140, 255); inputStroke.Thickness = 1

local applyIdBtn = makeButton("✅ Применить ID", 28, Color3.fromRGB(55,80,55), Color3.fromRGB(180,255,180))
local musicBtn      = makeButton("🎵 Музыка: ВЫКЛ", 28, Color3.fromRGB(50,35,60), Color3.fromRGB(220,180,255))

-- ==================== СИСТЕМА ====================
makeSection("💾 СИСТЕМА (только по кнопке)", Color3.fromRGB(60, 60, 80))
local saveBtn       = makeButton("💾 СОХРАНИТЬ", 32, Color3.fromRGB(35,70,50), Color3.fromRGB(160,255,180))
local loadBtn       = makeButton("📂 ЗАГРУЗИТЬ", 32, Color3.fromRGB(35,55,70), Color3.fromRGB(180,220,255))
local resetBtn      = makeButton("🔄 СБРОС", 32, Color3.fromRGB(70,35,35), Color3.fromRGB(255,180,180))
local unloadBtn     = makeButton("❌ ВЫГРУЗИТЬ СКРИПТ", 32, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140))

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -8, 0, 26)
hintLabel.BackgroundTransparency = 0.4
hintLabel.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
hintLabel.BorderSizePixel = 0
hintLabel.Text = "⚠️ Автосейв выключен — жми 💾 вручную"
hintLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 10
hintLabel.LayoutOrder = nextOrder()
hintLabel.Parent = panel
Instance.new("UICorner", hintLabel).CornerRadius = UDim.new(0, 6)

-- ==================== ОБРАБОТЧИКИ ====================
local ringButtons = { [2]=ring2Btn, [3]=ring3Btn, [4]=ring4Btn, [5]=ring5Btn }

local function refreshRingButton(ri)
    local btn = ringButtons[ri]; if not btn then return end
    if rings[ri].enabled then
        btn.Text = "➖ Убрать кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(55,40,40); btn.TextColor3 = Color3.fromRGB(255,160,160)
    else
        btn.Text = "➕ Кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(40,55,40); btn.TextColor3 = Color3.fromRGB(160,255,160)
    end
end

local function refreshSpinSpeedBtn()
    spinSpeedBtn.Text = "🌀 Скорость кручения: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end
local function refreshAuraColorBtn()
    local ac = P.COLORS[P.auraColorIndex]
    auraColorBtn.Text = "🎨 Цвет ауры: " .. ac.name
    if ac.rainbow then
        auraColorBtn.TextColor3 = Color3.fromRGB(255,200,255)
        auraColorBtn.BackgroundColor3 = Color3.fromRGB(80,40,90)
    else
        auraColorBtn.TextColor3 = ac.c
        auraColorBtn.BackgroundColor3 = Color3.fromRGB(60,40,80)
    end
end
local function refreshAuraShapeBtn()
    auraShapeBtn.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
end

mainBtn.Activated:Connect(function() panel.Visible = not panel.Visible end)

-- ОСНОВНОЕ
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
    if ns then
        allRingsBtn.Text = "⭕ Все кольца: ВЫКЛ"; allRingsBtn.TextColor3 = Color3.fromRGB(255,160,160); allRingsBtn.BackgroundColor3 = Color3.fromRGB(55,40,40)
    else
        allRingsBtn.Text = "⭕ Все кольца: ВКЛ"; allRingsBtn.TextColor3 = Color3.fromRGB(160,255,160); allRingsBtn.BackgroundColor3 = Color3.fromRGB(40,55,40)
    end
end)
for ri, btn in pairs(ringButtons) do
    btn.Activated:Connect(function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

-- ФОРМА
shapeBtn.Activated:Connect(function()
    ORBIT.shapeIndex = ORBIT.shapeIndex + 1
    if ORBIT.shapeIndex > #SHAPE_PRESETS then ORBIT.shapeIndex = 1 end
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

-- ОРБИТА
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

-- КРУЧЕНИЕ
spinBtn.Activated:Connect(function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    if ORBIT.spinResetting then spinBtn.Text = "↩️ Вращение: ВОЗВРАТ"; spinBtn.BackgroundColor3 = Color3.fromRGB(60,40,40); spinBtn.TextColor3 = Color3.fromRGB(255,180,180)
    else spinBtn.Text = "↩️ Вращение в 0"; spinBtn.BackgroundColor3 = Color3.fromRGB(50,40,60); spinBtn.TextColor3 = Color3.fromRGB(200,180,255) end
end)
spinAxisBtn.Activated:Connect(function()
    ORBIT.spinAxisEnabled = not ORBIT.spinAxisEnabled
    if ORBIT.spinAxisEnabled then spinAxisBtn.Text = "🔄 Кручение оси: ВКЛ"
    else spinAxisBtn.Text = "🔄 Кручение оси: ВЫКЛ" end
end)
spinDirBtn.Activated:Connect(function()
    if ORBIT.spinAxisDir == "X" then ORBIT.spinAxisDir = "Y"; spinDirBtn.Text = "↔️ Ось: ВЛЕВО/ВПРАВО"
    else ORBIT.spinAxisDir = "X"; spinDirBtn.Text = "↕️ Ось: ВЕРХ/ВНИЗ" end
end)
spinSpeedBtn.Activated:Connect(function()
    P.spinSpeedIndex = P.spinSpeedIndex + 1; if P.spinSpeedIndex > #P.SPIN_SPEED then P.spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value
    refreshSpinSpeedBtn()
end)

-- ЭФФЕКТЫ КОЛЕЦ
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
    refreshAuraShapeBtn()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraColorBtn.Activated:Connect(function()
    P.auraColorIndex = P.auraColorIndex + 1
    if P.auraColorIndex > #P.COLORS then P.auraColorIndex = 1 end
    local ac = P.COLORS[P.auraColorIndex]
    if ac.c then SETTINGS.AuraColor = ac.c end
    refreshAuraColorBtn()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end)
auraPulseBtn.Activated:Connect(function()
    SETTINGS.AuraPulseEnabled = not SETTINGS.AuraPulseEnabled
    auraPulseBtn.Text = "💓 Пульсация ауры: " .. (SETTINGS.AuraPulseEnabled and "ВКЛ" or "ВЫКЛ")
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
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1; if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
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
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1; if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    auraSpinAxisBtn.Text = "🔃 Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
auraSpinSpeedBtn.Activated:Connect(function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1; if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    auraSpinSpeedBtn.Text = "🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
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
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1; if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    auraTrailLenBtn.Text = "📏 Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
end)
auraTrailWidBtn.Activated:Connect(function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1; if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    auraTrailWidBtn.Text = "🎚️ Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
end)

-- ULTIMATE ЭФФЕКТЫ
lightningBtn.Activated:Connect(function()
    SETTINGS.LightningEnabled = not SETTINGS.LightningEnabled
    lightningBtn.Text = "⚡ Молния: " .. (SETTINGS.LightningEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
fireBtn.Activated:Connect(function()
    SETTINGS.FireEnabled = not SETTINGS.FireEnabled
    fireBtn.Text = "🔥 Огонь: " .. (SETTINGS.FireEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
smokeBtn.Activated:Connect(function()
    SETTINGS.SmokeEnabled = not SETTINGS.SmokeEnabled
    smokeBtn.Text = "🌫️ Дым: " .. (SETTINGS.SmokeEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
snowBtn.Activated:Connect(function()
    SETTINGS.SnowEnabled = not SETTINGS.SnowEnabled
    snowBtn.Text = "❄️ Снег: " .. (SETTINGS.SnowEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
confettiBtn.Activated:Connect(function()
    SETTINGS.ConfettiEnabled = not SETTINGS.ConfettiEnabled
    confettiBtn.Text = "🎉 Конфетти: " .. (SETTINGS.ConfettiEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
sparklesBtn.Activated:Connect(function()
    SETTINGS.SparklesEnabled = not SETTINGS.SparklesEnabled
    sparklesBtn.Text = "✨ Искры: " .. (SETTINGS.SparklesEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
groundRippleBtn.Activated:Connect(function()
    SETTINGS.GroundRippleEnabled = not SETTINGS.GroundRippleEnabled
    groundRippleBtn.Text = "💫 Риппл: " .. (SETTINGS.GroundRippleEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
portalBtn.Activated:Connect(function()
    SETTINGS.PortalEnabled = not SETTINGS.PortalEnabled
    portalBtn.Text = "🌀 Портал: " .. (SETTINGS.PortalEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
waveBurstBtn.Activated:Connect(function()
    SETTINGS.WaveBurstEnabled = not SETTINGS.WaveBurstEnabled
    waveBurstBtn.Text = "🌊 Волновой выброс: " .. (SETTINGS.WaveBurstEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
ringPulseBtn.Activated:Connect(function()
    SETTINGS.RingPulseEnabled = not SETTINGS.RingPulseEnabled
    ringPulseBtn.Text = "💓 Пульс кольца: " .. (SETTINGS.RingPulseEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
beamBtn.Activated:Connect(function()
    SETTINGS.BeamEnabled = not SETTINGS.BeamEnabled
    beamBtn.Text = "🔦 Луч: " .. (SETTINGS.BeamEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
starfieldBtn.Activated:Connect(function()
    SETTINGS.StarfieldEnabled = not SETTINGS.StarfieldEnabled
    starfieldBtn.Text = "⭐ Звёзды: " .. (SETTINGS.StarfieldEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
haloBtn.Activated:Connect(function()
    SETTINGS.HaloEnabled = not SETTINGS.HaloEnabled
    haloBtn.Text = "😇 Ореол: " .. (SETTINGS.HaloEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)
spikesBtn.Activated:Connect(function()
    SETTINGS.SpikesEnabled = not SETTINGS.SpikesEnabled
    spikesBtn.Text = "🗡️ Шипы: " .. (SETTINGS.SpikesEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupEffects()
end)

-- ЦВЕТ И СВЕТ
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

-- ЛЮДИ: кнопки "у всех"
addAllRingsBtn.Activated:Connect(function()
    if ORBIT.addRingsToAll then ORBIT.addRingsToAll() end
end)
remAllRingsBtn.Activated:Connect(function()
    if ORBIT.removeRingsFromAll then ORBIT.removeRingsFromAll() end
end)
toggleAllRingsBtn.Activated:Connect(function()
    if ORBIT.toggleAllRings then ORBIT.toggleAllRings() end
end)

-- МУЗЫКА
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

-- СИСТЕМА
saveBtn.Activated:Connect(function()
    if musicInput.Text ~= "" then ORBIT.setMusicId(musicInput.Text) end
    local ok = ORBIT.saveSettings()
    if ok then
        saveBtn.Text = "✅ СОХРАНЕНО!"
        task.wait(1.5)
        saveBtn.Text = "💾 СОХРАНИТЬ"
        ORBIT.notify("💾 Настройки сохранены", Color3.fromRGB(160,255,180))
    else
        saveBtn.Text = "❌ Ошибка"; task.wait(1.5); saveBtn.Text = "💾 СОХРАНИТЬ"
    end
end)
loadBtn.Activated:Connect(function()
    local ok = ORBIT.loadSettings()
    if ok then
        ORBIT.notify("📂 Настройки загружены", Color3.fromRGB(180,220,255))
        ORBIT.rebuildAllRings()
        ORBIT.rebuildAllTargetRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupEffects then ORBIT.setupEffects() end
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
            btn.Size = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = Color3.fromRGB(40,40,60)
            btn.TextColor3 = Color3.fromRGB(220,220,255)
            btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
            btn.Text = "🔷 " .. player.Name
            btn.LayoutOrder = idx; btn.Parent = peopleContainer
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            ORBIT.peopleButtons[player] = btn
            btn.Activated:Connect(function()
                ORBIT.toggleTargetRings(player)
                if ORBIT.targetRings[player] then
                    btn.Text = "✅ " .. player.Name
                    btn.BackgroundColor3 = Color3.fromRGB(80,40,100)
                    btn.TextColor3 = Color3.fromRGB(255,200,255)
                else
                    btn.Text = "🔷 " .. player.Name
                    btn.BackgroundColor3 = Color3.fromRGB(40,40,60)
                    btn.TextColor3 = Color3.fromRGB(220,220,255)
                end
            end)
        end
    end
    if idx == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 28); empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140,140,170)
        empty.Font = Enum.Font.Gotham; empty.TextSize = 12
        empty.LayoutOrder = 1; empty.Parent = peopleContainer
    end
end
rebuildPeopleList()

Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then task.wait(0.5); rebuildPeopleList() end end)
Players.PlayerRemoving:Connect(function(p)
    if p ~= LocalPlayer then
        ORBIT.removeTargetRings(p)
        task.wait(0.1)
        rebuildPeopleList()
    end
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        p.CharacterAdded:Connect(function()
            if ORBIT.targetRings[p] then
                task.wait(0.3)
                ORBIT.removeTargetRings(p)
                ORBIT.buildTargetRings(p)
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
            lbl.BackgroundColor3 = Color3.fromRGB(20,20,30)
            lbl.BackgroundTransparency = 0.15; lbl.BorderSizePixel = 0
            lbl.TextColor3 = n.color
            lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
            lbl.Text = " " .. n.text; lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = notifContainer
            Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
            local st = Instance.new("UIStroke", lbl); st.Color = n.color; st.Thickness = 1; st.Transparency = 0.5
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
            local m = math.floor(statsData.sessionTime/60)
            local s = math.floor(statsData.sessionTime%60)
            local c = 0
            for _ in pairs(ORBIT.targetRings) do c = c + 1 end
            statsLabel.Text = string.format(
                "📊 FPS: %d | 🔷 Фигур: %d\n⏱️ Время: %d:%02d | 🌀 %s\n🎯 Целей: %d | 📦 Эффектов: %d",
                statsData.lastFPS, statsData.totalShapes, m, s, SETTINGS.OrbitPattern, c,
                ORBIT.effectParts and #ORBIT.effectParts or 0
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
        mainBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)
mainBtn.InputEnded:Connect(function() dragging = false end)

-- ==================== СТАРТ ====================
ORBIT.start = function()
    if getgenv()._OrbitLoaderGui then pcall(function() getgenv()._OrbitLoaderGui:Destroy() end) end
    ORBIT.startLogic()
    ORBIT.notify("✨ ОРБИТА v20.1 запущена!", Color3.fromRGB(200,200,255), 3)
    ORBIT.notify("💾 Автосейв ВЫКЛ — жми 'Сохранить' вручную", Color3.fromRGB(255,220,120), 5)
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ Часть 4: интерфейс загружен", Color3.fromRGB(180,255,180), 3) end

return true
