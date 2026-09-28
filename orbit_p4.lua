--[[ ОРБИТА v20.1 — ЧАСТЬ 4/4: v15.3 CLASSIC UI + MATRIX BG ]]

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

-- Кнопка открытия (как в 15.3)
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
local mainStroke = Instance.new("UIStroke", mainBtn)
mainStroke.Color = Color3.fromRGB(120, 120, 255)
mainStroke.Thickness = 1.5

-- Панель (как в 15.3)
local panel = Instance.new("ScrollingFrame")
panel.Size = UDim2.new(0, 270, 0, 700)
panel.Position = UDim2.new(0, 90, 0, 5)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Visible = false
panel.CanvasSize = UDim2.new(0, 0, 0, 2700)
panel.ScrollBarThickness = 3
panel.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 255)
panel.ScrollingDirection = Enum.ScrollingDirection.Y
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(120, 120, 255)
panelStroke.Thickness = 1

-- ==================== МАТРИЧНЫЙ ДОЖДЬ (ФОН) ====================
local bgLayer = Instance.new("Frame")
bgLayer.Size = UDim2.new(1, 0, 1, 0)
bgLayer.BackgroundColor3 = Color3.fromRGB(0, 5, 2)
bgLayer.BackgroundTransparency = 0.55
bgLayer.BorderSizePixel = 0
bgLayer.ClipsDescendants = true
bgLayer.ZIndex = 0
bgLayer.Parent = panel
Instance.new("UICorner", bgLayer).CornerRadius = UDim.new(0, 12)

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
        col.TextTransparency = 0.65
        col.Font = Enum.Font.Code
        col.TextSize = 11
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

-- Заголовок (как в 15.3)
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 24)
title.Position = UDim2.new(0, 0, 0, 8)
title.BackgroundTransparency = 1
title.Text = "✨ ОРБИТА v20.1"
title.TextColor3 = Color3.fromRGB(200, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.ZIndex = 2
title.Parent = panel

-- ==================== ХЕЛПЕРЫ (как в 15.3) ====================
local function makeSection(text, y, color)
    local s = Instance.new("TextLabel")
    s.Size = UDim2.new(1, -20, 0, 20)
    s.Position = UDim2.new(0, 10, 0, y)
    s.BackgroundTransparency = 0.6
    s.BackgroundColor3 = color or Color3.fromRGB(50, 50, 80)
    s.BorderSizePixel = 0
    s.Text = "▸ " .. text
    s.TextColor3 = Color3.fromRGB(220, 220, 255)
    s.Font = Enum.Font.GothamBold
    s.TextSize = 11
    s.TextXAlignment = Enum.TextXAlignment.Left
    s.ZIndex = 2
    s.Parent = panel
    Instance.new("UICorner", s).CornerRadius = UDim.new(0, 6)
    return s
end

local function makeButton(text, y, h, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, h or 30)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(40, 40, 55)
    b.TextColor3 = textColor or Color3.fromRGB(230, 230, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.AutoButtonColor = true
    b.ZIndex = 2
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

-- ==================== СЕКЦИИ UI (всё как в 15.3) ====================
makeSection("⚡ ОСНОВНОЕ", 36, Color3.fromRGB(60, 60, 100))
local toggleBtn     = makeButton("🟢 ВКЛЮЧЕНО", 60, 30, Color3.fromRGB(40,40,55), Color3.fromRGB(0,255,120))
local allRingsBtn   = makeButton("⭕ Все кольца: ВКЛ", 93, 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring2Btn      = makeButton("➕ Кольцо 2", 126, 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring3Btn      = makeButton("➕ Кольцо 3", 159, 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring4Btn      = makeButton("➕ Кольцо 4", 192, 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))
local ring5Btn      = makeButton("➕ Кольцо 5", 225, 30, Color3.fromRGB(40,55,40), Color3.fromRGB(160,255,160))

makeSection("🔷 ФОРМА И ФИГУРЫ", 262, Color3.fromRGB(60, 80, 100))
local shapeCatBtn   = makeButton("📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, 286, 30, Color3.fromRGB(60,50,80), Color3.fromRGB(220,200,255))
local shapeBtn      = makeButton("🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, 319, 30)
local shapeModeBtn  = makeButton("🎭 Формы: " .. P.FORM_MODES[P.formModeIndex].name, 352, 30, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255))
local shapeSizeBtn  = makeButton("🔍 Фигура: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, 385, 30)
local autoSwapBtn   = makeButton("🎭 Автосмена: ВЫКЛ", 418, 30, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255))

makeSection("🛰️ ОРБИТА И ДВИЖЕНИЕ", 455, Color3.fromRGB(60, 100, 80))
local orbitBtn      = makeButton("📏 Орбита: " .. P.ORBIT[P.orbitIndex].name, 479, 30)
local spreadBtn     = makeButton("📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name, 512, 30, Color3.fromRGB(55,30,55), Color3.fromRGB(255,180,255))
local heightBtn     = makeButton("⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name, 545, 30, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local speedBtn      = makeButton("⚡ Множитель: " .. P.SPEED[P.speedIndex].name, 578, 30, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100))
local speedModeBtn  = makeButton("⚙️ Скорость: " .. P.SPEED_MODE[P.speedModeIndex].name, 611, 30, Color3.fromRGB(45,50,65), Color3.fromRGB(180,220,255))
local directionBtn  = makeButton("🔃 Направление: " .. P.DIRECTION[P.directionIndex].name, 644, 30, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255))
local orbitPatternBtn = makeButton("🌀 Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, 677, 30, Color3.fromRGB(60,40,90), Color3.fromRGB(220,180,255))

makeSection("🔄 КРУЧЕНИЕ", 714, Color3.fromRGB(100, 60, 80))
local spinBtn       = makeButton("↩️ Вращение в 0", 738, 30, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255))
local spinAxisBtn   = makeButton("🔄 Кручение оси: ВКЛ", 771, 30, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220))
local spinDirBtn    = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 804, 30, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255))
local spinSpeedBtn  = makeButton("🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name, 837, 30, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255))

makeSection("✨ ЭФФЕКТЫ КОЛЕЦ", 874, Color3.fromRGB(100, 80, 60))
local trailBtn      = makeButton("🌠 Трейлы: ВЫКЛ", 898, 30, Color3.fromRGB(35,35,50))
local trailLenBtn   = makeButton("📏 Трейл: " .. P.TRAIL_LEN[P.trailLengthIndex].name, 931, 30, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local trailWidBtn   = makeButton("🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name, 964, 30, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local waveBtn       = makeButton("🌊 Волна: ВЫКЛ", 997, 30, Color3.fromRGB(30,55,75), Color3.fromRGB(140,220,255))
local explosionBtn  = makeButton("💥 Взрыв: ВЫКЛ", 1030, 30, Color3.fromRGB(70,40,30), Color3.fromRGB(255,180,120))
local pulseBtn      = makeButton("💓 Пульсация: ВЫКЛ", 1063, 30, Color3.fromRGB(35,35,50))
local gradientBtn   = makeButton("🌈 Градиент: ВЫКЛ", 1096, 30, Color3.fromRGB(55,35,75), Color3.fromRGB(255,180,255))

makeSection("🔥 ОГОНЬ", 1133, Color3.fromRGB(150, 60, 20))
local fireBtn       = makeButton("🔥 Огонь: ВЫКЛ", 1157, 34, Color3.fromRGB(80,30,10), Color3.fromRGB(255,140,60))
local fireSizeBtn   = makeButton("📏 Размер огня: " .. P.FIRE_SIZE[P.fireSizeIndex].name, 1194, 30, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120))
local fireHeatBtn   = makeButton("🌡️ Жар огня: " .. P.FIRE_HEAT[P.fireHeatIndex].name, 1227, 30, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120))

makeSection("🌀 АУРА — ЭЛЕМЕНТЫ", 1264, Color3.fromRGB(80, 60, 120))
local auraBtn       = makeButton("🌀 Аура: ВЫКЛ", 1288, 30, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255))
local auraRingBtn   = makeButton("⭕ Кольцо: ВКЛ", 1321, 30, Color3.fromRGB(35,55,35), Color3.fromRGB(160,255,160))
local auraPartBtn   = makeButton("✨ Частицы: ВЫКЛ", 1354, 30, Color3.fromRGB(35,50,55), Color3.fromRGB(180,220,255))
local auraFigBtn    = makeButton("🔷 Фигуры: ВЫКЛ", 1387, 30, Color3.fromRGB(45,35,65), Color3.fromRGB(220,180,255))
local auraShapeBtn  = makeButton("🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, 1420, 30, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255))
local auraColorBtn  = makeButton("🎨 Цвет ауры: " .. P.COLORS[P.auraColorIndex].name, 1453, 30, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255))

makeSection("🌀 АУРА — РАЗМЕР", 1490, Color3.fromRGB(80, 60, 120))
local auraSizeBtn   = makeButton("📏 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name, 1514, 30, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local auraThickBtn  = makeButton("🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name, 1547, 30, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local auraHeightBtn = makeButton("⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, 1580, 30, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255))
local auraScaleBtn  = makeButton("🔍 Размер фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, 1613, 30, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255))

makeSection("🌀 АУРА — СКОРОСТЬ", 1650, Color3.fromRGB(80, 60, 120))
local auraSpeedBtn  = makeButton("⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, 1674, 30, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100))
local auraDirBtn    = makeButton("🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name, 1707, 30, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255))
local auraSpinBtn   = makeButton("🔄 Кручение: ВКЛ", 1740, 30, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220))
local auraSpinAxisBtn = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", 1773, 30, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255))
local auraSpinSpeedBtn = makeButton("🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name, 1806, 30, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255))
local auraSpinResetBtn = makeButton("↩️ Сброс вращения", 1839, 30, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255))

makeSection("🌀 АУРА — ТРЕЙЛЫ", 1876, Color3.fromRGB(80, 60, 120))
local auraTrailBtn    = makeButton("🌠 Трейлы ауры: ВЫКЛ", 1900, 30, Color3.fromRGB(35,35,50))
local auraTrailLenBtn = makeButton("📏 Длина: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, 1933, 30, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))
local auraTrailWidBtn = makeButton("🎚️ Толщина: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, 1966, 30, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255))

makeSection("🎨 ЦВЕТ И СВЕТ", 2003, Color3.fromRGB(100, 100, 50))
local colorBtn      = makeButton("🎨 Цвет: " .. P.COLORS[P.colorIndex].name, 2027, 30)
local lightBtn      = makeButton("💡 Свет: ВКЛ", 2060, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local nameBtn       = makeButton("🏷️ Имена: ВЫКЛ", 2093, 30)

makeSection("👥 ЛЮДИ И КОЛЬЦА", 2130, Color3.fromRGB(80, 40, 100))
local addAllRingsBtn  = makeButton("➕ Кольцо У ВСЕХ", 2154, 30, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180))
local remAllRingsBtn  = makeButton("➖ УБРАТЬ У ВСЕХ", 2187, 30, Color3.fromRGB(70,40,40), Color3.fromRGB(255,160,160))
local toggleAllRingsBtn = makeButton("🔄 Переключить ВСЕМ", 2220, 30, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255))

local peopleContainer = Instance.new("ScrollingFrame")
peopleContainer.Size = UDim2.new(1, -20, 0, 160)
peopleContainer.Position = UDim2.new(0, 10, 0, 2256)
peopleContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
peopleContainer.BackgroundTransparency = 0.2
peopleContainer.BorderSizePixel = 0
peopleContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
peopleContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
peopleContainer.ScrollBarThickness = 3
peopleContainer.ScrollBarImageColor3 = Color3.fromRGB(150,100,200)
peopleContainer.ScrollingDirection = Enum.ScrollingDirection.Y
peopleContainer.ZIndex = 2
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

makeSection("🛡️ ЗАЩИТА", 2430, Color3.fromRGB(60, 100, 60))
local protBtn       = makeButton("🛡️ Защита: ВЫКЛ", 2454, 34, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180))
local antiKbBtn     = makeButton("🛡️ Anti-Knockback: ВКЛ", 2491, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiTpBtn     = makeButton("🛡️ Anti-Teleport: ВКЛ", 2524, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiFrzBtn    = makeButton("🛡️ Anti-Freeze: ВКЛ", 2557, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiFlingBtn  = makeButton("🛡️ Anti-Fling: ВКЛ", 2590, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local autoHealBtn   = makeButton("💚 Auto-Heal: ВЫКЛ", 2623, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local antiVoidBtn   = makeButton("🛡️ Anti-Void: ВКЛ", 2656, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))
local lockPosBtn    = makeButton("📍 Lock Position: ВЫКЛ", 2689, 30, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160))

makeSection("💾 СОХРАНЕНИЯ", 2726, Color3.fromRGB(60, 60, 90))
local saveNameInput = Instance.new("TextBox")
saveNameInput.Size = UDim2.new(1, -20, 0, 32)
saveNameInput.Position = UDim2.new(0, 10, 0, 2750)
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
local sniStroke = Instance.new("UIStroke", saveNameInput)
sniStroke.Color = Color3.fromRGB(180, 140, 255); sniStroke.Thickness = 1

local createSaveBtn = makeButton("💾 СОЗДАТЬ СОХРАНЕНИЕ", 2788, 32, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180))

local savesContainer = Instance.new("ScrollingFrame")
savesContainer.Size = UDim2.new(1, -20, 0, 200)
savesContainer.Position = UDim2.new(0, 10, 0, 2826)
savesContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
savesContainer.BackgroundTransparency = 0.2
savesContainer.BorderSizePixel = 0
savesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
savesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
savesContainer.ScrollBarThickness = 3
savesContainer.ScrollBarImageColor3 = Color3.fromRGB(150,100,200)
savesContainer.ScrollingDirection = Enum.ScrollingDirection.Y
savesContainer.ZIndex = 2
savesContainer.Parent = panel
Instance.new("UICorner", savesContainer).CornerRadius = UDim.new(0, 8)
local savesLayout = Instance.new("UIListLayout")
savesLayout.SortOrder = Enum.SortOrder.LayoutOrder
savesLayout.Padding = UDim.new(0, 4)
savesLayout.Parent = savesContainer

makeSection("🎵 МУЗЫКА", 3040, Color3.fromRGB(80, 60, 100))
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -20, 0, 32)
musicInput.Position = UDim2.new(0, 10, 0, 3064)
musicInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
musicInput.BackgroundTransparency = 0.1
musicInput.TextColor3 = Color3.fromRGB(240, 230, 255)
musicInput.Font = Enum.Font.GothamBold
musicInput.TextSize = 12
musicInput.PlaceholderText = "Пример: 1839246711"
musicInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
musicInput.Text = ""
musicInput.ClearTextOnFocus = false
musicInput.ZIndex = 2
musicInput.Parent = panel
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 8)
local miStroke = Instance.new("UIStroke", musicInput)
miStroke.Color = Color3.fromRGB(180, 140, 255); miStroke.Thickness = 1

local applyIdBtn = makeButton("✅ Применить ID", 3102, 30, Color3.fromRGB(55,80,55), Color3.fromRGB(180,255,180))
local musicBtn   = makeButton("🎵 Музыка: ВЫКЛ", 3135, 30, Color3.fromRGB(50,35,60), Color3.fromRGB(220,180,255))

makeSection("💾 СИСТЕМА", 3172, Color3.fromRGB(60, 60, 80))
local saveBtn   = makeButton("💾 Сохранить (автослот)", 3196, 30, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180))
local loadBtn   = makeButton("📂 Загрузить (автослот)", 3229, 30, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255))
local resetBtn  = makeButton("🔄 Сброс", 3262, 30, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180))
local unloadBtn = makeButton("❌ ВЫГРУЗИТЬ СКРИПТ", 3295, 30, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140))

-- Обновить CanvasSize
panel.CanvasSize = UDim2.new(0, 0, 0, 3340)

-- ==================== СТАТИСТИКА (как в 15.3) ====================
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 50)
statsLabel.Position = UDim2.new(0, 10, 0, 2888)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsLabel.BackgroundTransparency = 0.2
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "FPS: -- | Фигур: 0 | Время: 0 сек"
statsLabel.ZIndex = 2
statsLabel.Parent = panel
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)

-- переносим статистику выше музыки
statsLabel.Position = UDim2.new(0, 10, 0, 2888)

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
    if ns then
        allRingsBtn.Text = "⭕ Все кольца: ВЫКЛ"; allRingsBtn.TextColor3 = Color3.fromRGB(255,160,160); allRingsBtn.BackgroundColor3 = Color3.fromRGB(55,40,40)
    else
        allRingsBtn.Text = "⭕ Все кольца: ВКЛ"; allRingsBtn.TextColor3 = Color3.fromRGB(160,255,160); allRingsBtn.BackgroundColor3 = Color3.fromRGB(40,55,40)
    end
end)
for ri, btn in pairs(ringButtons) do
    btn.Activated:Connect(function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

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
    ORBIT.notify("🔷 " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, Color3.fromRGB(180,220,255))
end)
shapeModeBtn.Activated:Connect(function()
    P.formModeIndex = P.formModeIndex + 1; if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Формы: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
end)
shapeSizeBtn.Activated:Connect(function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1; if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
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
    spinSpeedBtn.Text = "🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

trailBtn.Activated:Connect(function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
trailLenBtn.Activated:Connect(function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    trailLenBtn.Text = "📏 Трейл: " .. P.TRAIL_LEN[P.trailLengthIndex].name
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
            btn.BackgroundColor3 = Color3.fromRGB(80,40,100)
            btn.TextColor3 = Color3.fromRGB(255,200,255)
        end
    end
end)
remAllRingsBtn.Activated:Connect(function()
    ORBIT.removeRingsFromAll()
    for player, btn in pairs(ORBIT.peopleButtons) do
        btn.Text = "🔷 " .. player.Name
        btn.BackgroundColor3 = Color3.fromRGB(40,40,60)
        btn.TextColor3 = Color3.fromRGB(220,220,255)
    end
end)
toggleAllRingsBtn.Activated:Connect(function()
    ORBIT.toggleAllRings()
    task.wait(0.1)
    for player, btn in pairs(ORBIT.peopleButtons) do
        if ORBIT.targetRings[player] then
            btn.Text = "✅ " .. player.Name
            btn.BackgroundColor3 = Color3.fromRGB(80,40,100)
            btn.TextColor3 = Color3.fromRGB(255,200,255)
        else
            btn.Text = "🔷 " .. player.Name
            btn.BackgroundColor3 = Color3.fromRGB(40,40,60)
            btn.TextColor3 = Color3.fromRGB(220,220,255)
        end
    end
end)

protBtn.Activated:Connect(function()
    SETTINGS.ProtEnabled = not SETTINGS.ProtEnabled
    protBtn.Text = "🛡️ Защита: " .. (SETTINGS.ProtEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.ProtEnabled then ORBIT.enableProtection()
    else ORBIT.disableProtection() end
end)
antiKbBtn.Activated:Connect(function()
    SETTINGS.AntiKnockback = not SETTINGS.AntiKnockback
    antiKbBtn.Text = "🛡️ Anti-Knockback: " .. (SETTINGS.AntiKnockback and "ВКЛ" or "ВЫКЛ")
end)
antiTpBtn.Activated:Connect(function()
    SETTINGS.AntiTeleport = not SETTINGS.AntiTeleport
    antiTpBtn.Text = "🛡️ Anti-Teleport: " .. (SETTINGS.AntiTeleport and "ВКЛ" or "ВЫКЛ")
end)
antiFrzBtn.Activated:Connect(function()
    SETTINGS.AntiFreeze = not SETTINGS.AntiFreeze
    antiFrzBtn.Text = "🛡️ Anti-Freeze: " .. (SETTINGS.AntiFreeze and "ВКЛ" or "ВЫКЛ")
end)
antiFlingBtn.Activated:Connect(function()
    SETTINGS.AntiFling = not SETTINGS.AntiFling
    antiFlingBtn.Text = "🛡️ Anti-Fling: " .. (SETTINGS.AntiFling and "ВКЛ" or "ВЫКЛ")
end)
autoHealBtn.Activated:Connect(function()
    SETTINGS.AutoHeal = not SETTINGS.AutoHeal
    autoHealBtn.Text = "💚 Auto-Heal: " .. (SETTINGS.AutoHeal and "ВКЛ" or "ВЫКЛ")
end)
antiVoidBtn.Activated:Connect(function()
    SETTINGS.AntiVoid = not SETTINGS.AntiVoid
    antiVoidBtn.Text = "🛡️ Anti-Void: " .. (SETTINGS.AntiVoid and "ВКЛ" or "ВЫКЛ")
end)
lockPosBtn.Activated:Connect(function()
    SETTINGS.LockPosition = not SETTINGS.LockPosition
    lockPosBtn.Text = "📍 Lock Position: " .. (SETTINGS.LockPosition and "ВКЛ" or "ВЫКЛ")
end)

-- СОХРАНЕНИЯ
local function rebuildSavesList()
    for _, child in ipairs(savesContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
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
        loadB.Text = "✓ ЗАГР"
        loadB.Parent = row
        Instance.new("UICorner", loadB).CornerRadius = UDim.new(0, 5)

        local delB = Instance.new("TextButton")
        delB.Size = UDim2.new(0, 55, 0, 24)
        delB.Position = UDim2.new(1, -60, 0, 4)
        delB.BackgroundColor3 = Color3.fromRGB(80,30,30)
        delB.TextColor3 = Color3.fromRGB(255,150,150)
        delB.Font = Enum.Font.GothamBold
        delB.TextSize = 10
        delB.Text = "✖ УДАЛ"
        delB.Parent = row
        Instance.new("UICorner", delB).CornerRadius = UDim.new(0, 5)

        loadB.Activated:Connect(function()
            local ok = ORBIT.loadNamed(name)
            if ok then
                ORBIT.notify("💾 Загружено: " .. name, Color3.fromRGB(160,255,180))
                ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
                if ORBIT.setupAura then ORBIT.setupAura() end
                if ORBIT.setupFire then ORBIT.setupFire() end
                if SETTINGS.ProtEnabled and ORBIT.enableProtection then ORBIT.enableProtection() end
                shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
                shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
            else
                ORBIT.notify("❌ Ошибка загрузки", Color3.fromRGB(255,100,100))
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

-- МУЗЫКА
applyIdBtn.Activated:Connect(function()
    local ok = ORBIT.setMusicId(musicInput.Text)
    if ok then
        applyIdBtn.Text = "✅ Применено!"
        task.wait(1.2)
        applyIdBtn.Text = "✅ Применить ID"
        ORBIT.notify("🎵 ID применён", Color3.fromRGB(180,255,180))
    else
        applyIdBtn.Text = "❌ Ошибка"
        task.wait(1.5)
        applyIdBtn.Text = "✅ Применить ID"
    end
end)
musicBtn.Activated:Connect(function()
    if not ORBIT.musicSound or ORBIT.musicSound.SoundId == "" then
        musicBtn.Text = "❌ Вставь ID!"
        task.wait(1.2)
        musicBtn.Text = "🎵 Музыка: ВЫКЛ"
        return
    end
    ORBIT.musicEnabled = not ORBIT.musicEnabled
    if ORBIT.musicEnabled then ORBIT.musicSound:Play(); musicBtn.Text = "🎵 Музыка: ВКЛ"
    else ORBIT.musicSound:Stop(); musicBtn.Text = "🎵 Музыка: ВЫКЛ" end
end)

saveBtn.Activated:Connect(function()
    if musicInput.Text ~= "" then ORBIT.setMusicId(musicInput.Text) end
    local ok = ORBIT.saveSettings()
    if ok then
        saveBtn.Text = "✅ Сохранено!"
        task.wait(1.5)
        saveBtn.Text = "💾 Сохранить (автослот)"
        ORBIT.notify("💾 Сохранено в автослот", Color3.fromRGB(160,255,180))
    else
        saveBtn.Text = "❌ Ошибка"
        task.wait(1.5)
        saveBtn.Text = "💾 Сохранить (автослот)"
    end
end)
loadBtn.Activated:Connect(function()
    if ORBIT.loadSettings() then
        ORBIT.notify("📂 Загружено из автослота", Color3.fromRGB(180,220,255))
        shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
        shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.rebuildAllRings(); ORBIT.rebuildAllTargetRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupFire then ORBIT.setupFire() end
        if SETTINGS.ProtEnabled and ORBIT.enableProtection then ORBIT.enableProtection() end
    else
        ORBIT.notify("❌ Нет сохранения", Color3.fromRGB(255,100,100))
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
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            btn.Text = "🔷 " .. player.Name
            btn.LayoutOrder = idx
            btn.Parent = peopleContainer
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
        empty.Size = UDim2.new(1, 0, 0, 28)
        empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140,140,170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.LayoutOrder = 1
        empty.Parent = peopleContainer
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

rebuildSavesList()

-- ==================== УВЕДОМЛЕНИЯ (как в 15.3) ====================
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
            lbl.Position = UDim2.new(0, 0, 0, #active * 38)
            lbl.BackgroundColor3 = Color3.fromRGB(20,20,30)
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
            st.Color = n.color; st.Thickness = 1; st.Transparency = 0.5
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
            local savesCount = 0
            for _ in pairs(ORBIT.SAVES) do savesCount = savesCount + 1 end
            statsLabel.Text = string.format(
                "📊 FPS: %d | 🔷 Фигур: %d\n⏱️ Время: %d:%02d | 🎯 Целей: %d\n💾 Сохранений: %d | 🌀 %s",
                statsData.lastFPS, statsData.totalShapes, m, s, c, savesCount, SETTINGS.OrbitPattern
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
    ORBIT.notify("✨ ОРБИТА v20.1 запущена!", Color3.fromRGB(200,200,255), 3)
    ORBIT.notify("💾 Автосейв ВЫКЛ — сохраняй вручную", Color3.fromRGB(255,220,120), 5)
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ Часть 4: classic UI + matrix загружен", Color3.fromRGB(180,255,180), 3) end

return true
