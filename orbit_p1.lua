--[[ ОРБИТА v15.3 — ЧАСТЬ 1/4: ЯДРО + ЗАГРУЗЧИК ]]

local GENV = rawget(_G, "getgenv") and getgenv() or _G
local OLD = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (GENV and GENV.ORBIT)
if OLD and OLD.unload then pcall(OLD.unload) end

local ORBIT = {}
shared.ORBIT = ORBIT
rawset(_G, "ORBIT", ORBIT)
if GENV then GENV.ORBIT = ORBIT end

ORBIT.version = "v15.3-parts"
ORBIT.loaded = { p1 = true, p2 = false, p3 = false, p4 = false }
ORBIT.started = false

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

ORBIT.Players = Players
ORBIT.RunService = RunService
ORBIT.Workspace = Workspace
ORBIT.SoundService = SoundService
ORBIT.TweenService = TweenService
ORBIT.HttpService = HttpService
ORBIT.LocalPlayer = LocalPlayer
ORBIT.PlayerGui = PlayerGui
ORBIT.SAVE_FILE = "orbit_v15_settings.json"
ORBIT.HAS_FS = (writefile and readfile and isfile and type(writefile) == "function")

local function getSafeParent()
    if rawget(GENV, "gethui") then
        local ok, hui = pcall(GENV.gethui)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return PlayerGui
end
local function protectGui(gui)
    if syn and syn.protect_gui then pcall(syn.protect_gui, gui)
    elseif rawget(GENV, "protect_gui") then pcall(GENV.protect_gui, gui) end
end
ORBIT.getSafeParent = getSafeParent
ORBIT.protectGui = protectGui

ORBIT.DEFAULT_SETTINGS = {
    BlockCount = 8, BaseShapeSize = 1.5, OrbitSpeed = 60, SpinSpeed = 120,
    SpeedMultiplier = 1.0, SpinSpeedMultiplier = 1.0, BobAmplitude = 0.8,
    Material = Enum.Material.Neon, Transparency = 0.1, LightRange = 6, LightLimit = 20,
    LightEnabled = true, Rainbow = true, FixedColor = Color3.fromRGB(0, 180, 255),
    ShowBlockNames = false, NameColor = Color3.fromRGB(255, 255, 255), LerpSpeed = 5.0,
    TrailEnabled = false, TrailLength = 0.5, TrailWidth = 0.8,
    PulseEnabled = false, PulseAmplitude = 0.15, PulseSpeed = 4.0,
    WaveEnabled = false, WaveSpeed = 3.0, WaveLength = 2.0, WaveAmplitude = 2.5,
    ExplosionEnabled = false, ExplosionSpeed = 0.4, ExplosionPower = 0.7,
    HeartScale = 0.65, OrbitPattern = "Круг",
    AuraEnabled = false, AuraType = "Кольцо", AuraSize = 3.5, AuraThickness = 0.15,
    AuraColor = Color3.fromRGB(150, 100, 255),
    AuraRing = true, AuraParticles = false, AuraShapes = false,
    AuraSpeedMult = 1.0, AuraDirection = 1,
    AuraHeight = 0.5, AuraShapeScale = 1.0,
    AuraTrailEnabled = false, AuraTrailLength = 0.5, AuraTrailWidth = 0.8,
    AuraSpinEnabled = true, AuraSpinAxis = "Y", AuraSpinSpeed = 60,
    AuraPulseEnabled = false,
    AutoShapeSwap = false, AutoShapeSwapInterval = 15,
    GradientEnabled = false, GradientSpeed = 0.5, GlowEnabled = true, GlowIntensity = 2,
}
ORBIT.SETTINGS = table.clone(ORBIT.DEFAULT_SETTINGS)

local P = {}
P.SPIN_SPEED = { {name="0.5x",value=0.5},{name="1x",value=1.0},{name="2x",value=2.0},{name="3x",value=3.0},{name="5x",value=5.0},{name="10x",value=10.0} }
P.spinSpeedIndex = 2
P.SPREAD = { {name="1x плотно",mult=1.0},{name="1.5x",mult=1.5},{name="2x средне",mult=2.0},{name="3x широко",mult=3.0},{name="5x максимально",mult=5.0} }
P.spreadIndex = 2
P.HEIGHT = {
    {name="Возле (у ног)",offset=-3.0},{name="Ноги",offset=-1.0},{name="Низко",offset=0.5},
    {name="Середина",offset=2.0},{name="Туловище",offset=3.0},{name="Голова",offset=4.5},
    {name="Высоко",offset=6.5},{name="Небо",offset=35.0},{name="Космос",offset=60.0},
}
P.heightIndex = 4
P.SPEED = { {name="0.5x",value=0.5},{name="1x",value=1.0},{name="1.5x",value=1.5},{name="2x",value=2.0},{name="3x",value=3.0},{name="5x",value=5.0},{name="10x",value=10.0} }
P.speedIndex = 2
P.SPEED_MODE = { {name="Разная",mults={1.0,1.3,0.7,1.6,0.5}},{name="Одинаковая",mults={1.0,1.0,1.0,1.0,1.0}} }
P.speedModeIndex = 1
P.DIRECTION = { {name="Чередование",dirs={1,-1,1,-1,1}},{name="Все ↻",dirs={1,1,1,1,1}},{name="Все ↺",dirs={-1,-1,-1,-1,-1}},{name="Попарно",dirs={1,1,-1,-1,1}} }
P.directionIndex = 1
P.FORM_MODES = { {name="Одинаковая"},{name="Разные"} }
P.formModeIndex = 1
P.ORBIT = { {name="S",radius=5,height=2},{name="M",radius=8,height=3},{name="L",radius=12,height=4},{name="XL",radius=18,height=6},{name="XXL",radius=25,height=8} }
P.orbitIndex = 2
P.SHAPE_SIZE = { {name="XS",factor=0.5},{name="S",factor=0.75},{name="M",factor=1.0},{name="L",factor=1.5},{name="XL",factor=2.2},{name="XXL",factor=3.0} }
P.shapeSizeIndex = 3
P.ORBIT_PATTERNS = { {name="Круг"},{name="Спираль"},{name="Волна"},{name="Восьмёрка"},{name="Зигзаг"},{name="Лиссажу"},{name="Хаос"} }
P.orbitPatternIndex = 1
P.AURA_TYPES = { {name="Кольцо"},{name="Частицы"},{name="Фигуры"},{name="Оба"},{name="Всё"} }
P.auraTypeIndex = 1
P.COLORS = {
    {name="РАДУГА",rainbow=true},{name="КРАСНЫЙ",c=Color3.fromRGB(255,50,50)},{name="ОРАНЖЕВЫЙ",c=Color3.fromRGB(255,140,40)},
    {name="ЖЁЛТЫЙ",c=Color3.fromRGB(255,230,60)},{name="ЗЕЛЁНЫЙ",c=Color3.fromRGB(0,255,120)},{name="ГОЛУБОЙ",c=Color3.fromRGB(0,180,255)},
    {name="СИНИЙ",c=Color3.fromRGB(40,80,255)},{name="ФИОЛЕТОВЫЙ",c=Color3.fromRGB(160,80,255)},{name="РОЗОВЫЙ",c=Color3.fromRGB(255,90,180)},
    {name="НЕОН-РОЗОВЫЙ",c=Color3.fromRGB(255,0,200)},{name="НЕОН-ЗЕЛЁНЫЙ",c=Color3.fromRGB(80,255,80)},{name="НЕОН-ГОЛУБОЙ",c=Color3.fromRGB(0,255,255)},
    {name="НЕОН-ЖЁЛТЫЙ",c=Color3.fromRGB(255,255,0)},{name="НЕОН-ОРАНЖ",c=Color3.fromRGB(255,120,0)},{name="НЕОН-ФИОЛЕТ",c=Color3.fromRGB(200,0,255)},
    {name="ПАСТЕЛЬ-РОЗА",c=Color3.fromRGB(255,180,200)},{name="ПАСТЕЛЬ-ГОЛУБ",c=Color3.fromRGB(180,220,255)},{name="ПАСТЕЛЬ-ЛИМОН",c=Color3.fromRGB(255,250,180)},
    {name="ПАСТЕЛЬ-МЯТА",c=Color3.fromRGB(180,255,220)},{name="ПАСТЕЛЬ-СИРЕН",c=Color3.fromRGB(210,180,255)},{name="ЗОЛОТОЙ",c=Color3.fromRGB(255,200,40)},
    {name="СЕРЕБРЯНЫЙ",c=Color3.fromRGB(220,220,230)},{name="БРОНЗОВЫЙ",c=Color3.fromRGB(205,127,50)},{name="МЕДНЫЙ",c=Color3.fromRGB(184,115,51)},
    {name="ОГОНЬ",c=Color3.fromRGB(255,90,0)},{name="ЛАВА",c=Color3.fromRGB(200,40,0)},{name="ЛЁД",c=Color3.fromRGB(180,230,255)},
    {name="ТРАВА",c=Color3.fromRGB(90,200,80)},{name="НЕБО",c=Color3.fromRGB(120,190,255)},{name="БИРЮЗОВЫЙ",c=Color3.fromRGB(64,224,208)},
    {name="ИЗУМРУД",c=Color3.fromRGB(80,200,120)},{name="РУБИН",c=Color3.fromRGB(220,20,90)},{name="САПФИР",c=Color3.fromRGB(15,82,186)},
    {name="КОРАЛЛ",c=Color3.fromRGB(255,127,80)},{name="ЛАВАНДА",c=Color3.fromRGB(180,130,255)},{name="БЕЛЫЙ",c=Color3.fromRGB(245,245,255)},
    {name="СЕРЫЙ",c=Color3.fromRGB(150,150,160)},{name="ЧЁРНЫЙ",c=Color3.fromRGB(25,25,30)},{name="МАЛИНОВЫЙ",c=Color3.fromRGB(200,0,80)},
    {name="ИНДИГО",c=Color3.fromRGB(75,0,130)},{name="ХАКИ",c=Color3.fromRGB(189,183,107)},
}
P.colorIndex = 1
P.auraColorIndex = 1
P.TRAIL_LEN = { {name="Короткий",value=0.25},{name="Средний",value=0.5},{name="Длинный",value=0.9},{name="Очень длинный",value=1.6},{name="Гигантский",value=2.5} }
P.trailLengthIndex = 2
P.TRAIL_WID = { {name="Тонкий",value=0.3},{name="Средний",value=0.8},{name="Толстый",value=1.5},{name="Широкий",value=2.5},{name="Огромный",value=4.0} }
P.trailWidthIndex = 2
P.AURA_SPEED = { {name="0.25x",value=0.25},{name="0.5x",value=0.5},{name="1x",value=1.0},{name="2x",value=2.0},{name="3x",value=3.0},{name="5x",value=5.0} }
P.auraSpeedIndex = 3
P.AURA_DIR = { {name="→ Право (↻)",value=1},{name="← Лево (↺)",value=-1} }
P.auraDirIndex = 1
P.AURA_SIZE = { {name="XS",value=2.0},{name="S",value=3.0},{name="M",value=3.5},{name="L",value=5.0},{name="XL",value=7.0},{name="XXL",value=10.0} }
P.auraSizeIndex = 3
P.AURA_THICK = { {name="Тонкая",value=0.08},{name="Обычная",value=0.15},{name="Толстая",value=0.3},{name="Очень толстая",value=0.5} }
P.auraThickIndex = 2
P.AURA_HEIGHT = { {name="Низко (ноги)",value=-1.0},{name="Обычно",value=0.5},{name="Середина",value=1.5},{name="Туловище",value=2.5},{name="Грудь",value=3.5},{name="Голова",value=4.5},{name="Высоко",value=6.5} }
P.auraHeightIndex = 2
P.AURA_SHAPE_SCALE = { {name="Крошка",factor=0.3},{name="XS",factor=0.45},{name="S",factor=0.6},{name="M",factor=0.8},{name="L",factor=1.0},{name="XL",factor=1.3},{name="XXL",factor=1.7} }
P.auraShapeScaleIndex = 3
P.AURA_TRAIL_LEN = { {name="Короткий",value=0.25},{name="Средний",value=0.5},{name="Длинный",value=0.9},{name="Очень длинный",value=1.6},{name="Гигантский",value=2.5} }
P.auraTrailLengthIndex = 2
P.AURA_TRAIL_WID = { {name="Тонкий",value=0.3},{name="Средний",value=0.8},{name="Толстый",value=1.5},{name="Широкий",value=2.5},{name="Огромный",value=4.0} }
P.auraTrailWidthIndex = 2
P.AURA_SPIN_SPEED = { {name="0.5x",value=30},{name="1x",value=60},{name="2x",value=120},{name="3x",value=180},{name="5x",value=300},{name="10x",value=600} }
P.auraSpinSpeedIndex = 2
P.AURA_SPIN_AXIS = { {name="↕️ ВЕРХ/ВНИЗ",value="Y"},{name="↔️ ВЛЕВО/ВПРАВО",value="X"} }
P.auraSpinAxisIndex = 1
P.HEART_STEPS = { 0.1625, 0.325, 0.455, 0.65, 0.975, 1.3, 1.625, 1.95 }
P.heartScaleIndex = 4
ORBIT.P = P

ORBIT.enabled = true
ORBIT.spinResetting = false
ORBIT.spinAxisEnabled = true
ORBIT.spinAxisDir = "X"
ORBIT.updateConn = nil
ORBIT.startTime = tick()
ORBIT.activeLightCount = 0
ORBIT.currentRadius, ORBIT.currentHeight = {}, {}
ORBIT.currentSpeed, ORBIT.currentSpin = {}, {}
ORBIT.currentOrbitAngle, ORBIT.currentSpinAngle, ORBIT.currentBobPhase = {}, {}, {}
ORBIT.lastAutoSwap = tick()
ORBIT.currentAutoShapeIndex = 1
ORBIT.statsData = { totalShapes=0, sessionTime=0, lastFPS=60, fpsFrames=0, fpsLastCheck=tick() }
ORBIT.auraFolder = nil
ORBIT.auraParts = {}
ORBIT.auraBlocks = {}
ORBIT.auraAngle = 0
ORBIT.auraSpinAngle = 0
ORBIT.auraShapeIndex = 1
ORBIT.targetRings = {}
ORBIT.peopleButtons = {}
ORBIT.shapeIndex = 1
ORBIT.SHAPE_PRESETS = nil
ORBIT.RING_STEP = 5
ORBIT.rings = {
    [1] = {enabled=true,  shapeIndex=1, folder=nil, blocks={}, radiusOffset=0, heightOffset=0,   direction=1,  speedMult=1.0, angleShift=0,   colorShift=0   },
    [2] = {enabled=false, shapeIndex=2, folder=nil, blocks={}, radiusOffset=1, heightOffset=-0.5, direction=-1, speedMult=1.3, angleShift=22.5, colorShift=0.2 },
    [3] = {enabled=false, shapeIndex=3, folder=nil, blocks={}, radiusOffset=2, heightOffset=0.5,  direction=1,  speedMult=0.7, angleShift=45,  colorShift=0.4 },
    [4] = {enabled=false, shapeIndex=4, folder=nil, blocks={}, radiusOffset=3, heightOffset=-1,   direction=-1, speedMult=1.6, angleShift=67.5, colorShift=0.6 },
    [5] = {enabled=false, shapeIndex=5, folder=nil, blocks={}, radiusOffset=4, heightOffset=1,    direction=1,  speedMult=0.5, angleShift=90,  colorShift=0.8 },
}
for ri in pairs(ORBIT.rings) do
    ORBIT.currentRadius[ri], ORBIT.currentHeight[ri] = 8, 3
    ORBIT.currentSpeed[ri], ORBIT.currentSpin[ri] = 60, 120
    ORBIT.currentOrbitAngle[ri], ORBIT.currentSpinAngle[ri], ORBIT.currentBobPhase[ri] = 0, 0, 0
end

ORBIT.musicEnabled = false
ORBIT.musicSound = nil
ORBIT.savedMusicId = ""
ORBIT.musicVolume = 0.5
function ORBIT.createMusicSound()
    if ORBIT.musicSound and ORBIT.musicSound.Parent then return end
    ORBIT.musicSound = Instance.new("Sound")
    ORBIT.musicSound.Name = "OrbitMusic_" .. tostring(math.random(1, 999999))
    ORBIT.musicSound.Volume = ORBIT.musicVolume
    ORBIT.musicSound.Looped = true
    ORBIT.musicSound.Parent = SoundService
end
function ORBIT.setMusicId(idText)
    ORBIT.createMusicSound()
    local clean = tostring(idText or ""):gsub("%s", "")
    if clean == "" then return false, "Пустое поле" end
    local num = clean:match("(%d+)")
    if not num then return false, "Не найден ID" end
    ORBIT.musicSound.SoundId = "rbxassetid://" .. num
    ORBIT.savedMusicId = num
    if ORBIT.musicEnabled then ORBIT.musicSound:Play() end
    return true
end

ORBIT.NOTIF_QUEUE = {}
function ORBIT.notify(text, color, duration)
    table.insert(ORBIT.NOTIF_QUEUE, {
        text = text,
        color = color or Color3.fromRGB(140, 255, 200),
        duration = duration or 2,
    })
end

function ORBIT.newPart(parent, name, size, cf, color, noRecolor)
    local p = Instance.new("Part")
    p.Name = name; p.Size = size; p.CFrame = cf
    p.Anchored = true; p.CanCollide = false; p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = color or Color3.fromRGB(255, 255, 255)
    if noRecolor then p:SetAttribute("NoRecolor", true) end
    p.Parent = parent
    return p
end
function ORBIT.newModelShell(name)
    local model = Instance.new("Model"); model.Name = name
    local root = Instance.new("Part")
    root.Name = "Root"; root.Size = Vector3.new(0.1, 0.1, 0.1); root.Transparency = 1
    root.Anchored = true; root.CanCollide = false; root.CastShadow = false
    root.Parent = model; model.PrimaryPart = root
    return model, root
end
function ORBIT.makeRod(parent, a, b, thickness, depth, color)
    local mid = (a + b) * 0.5; local diff = b - a
    local part = Instance.new("Part")
    part.Name = "Rod"; part.Size = Vector3.new(depth, thickness, diff.Magnitude)
    part.CFrame = CFrame.lookAt(mid, mid + diff.Unit)
    part.Anchored = true; part.CanCollide = false; part.CastShadow = false
    part.Material = Enum.Material.Neon; part.Color = color; part.Parent = parent
    return part
end

function ORBIT.getCurrentShapeSize()
    return ORBIT.SETTINGS.BaseShapeSize * P.SHAPE_SIZE[P.shapeSizeIndex].factor
end
function ORBIT.getTargetRadius(ri)
    return P.ORBIT[P.orbitIndex].radius + ORBIT.rings[ri].radiusOffset * ORBIT.RING_STEP * P.SPREAD[P.spreadIndex].mult
end
function ORBIT.getHeightOffset() return P.HEIGHT[P.heightIndex].offset end
function ORBIT.getTargetHeight(ri)
    return P.ORBIT[P.orbitIndex].height + ORBIT.rings[ri].heightOffset * P.SPREAD[P.spreadIndex].mult + ORBIT.getHeightOffset()
end
function ORBIT.getTargetSpeed() return ORBIT.SETTINGS.OrbitSpeed * ORBIT.SETTINGS.SpeedMultiplier end
function ORBIT.getTargetSpin() return ORBIT.SETTINGS.SpinSpeed * ORBIT.SETTINGS.SpeedMultiplier * ORBIT.SETTINGS.SpinSpeedMultiplier end

ORBIT.start = function()
    ORBIT.notify("⏳ Не все части загружены", Color3.fromRGB(255,200,100), 3)
end
ORBIT.unload = function()
    if ORBIT.updateConn then pcall(function() ORBIT.updateConn:Disconnect() end); ORBIT.updateConn = nil end
    for ri in pairs(ORBIT.rings) do
        local r = ORBIT.rings[ri]
        if r.folder then pcall(function() r.folder:Destroy() end); r.folder = nil end
    end
    if ORBIT.auraFolder then pcall(function() ORBIT.auraFolder:Destroy() end); ORBIT.auraFolder = nil end
    if ORBIT.musicSound then pcall(function() ORBIT.musicSound:Destroy() end); ORBIT.musicSound = nil end
    if GENV._OrbitLoaderGui then pcall(function() GENV._OrbitLoaderGui:Destroy() end) end
    if GENV._OrbitMainGui then pcall(function() GENV._OrbitMainGui:Destroy() end) end
    if GENV._OrbitNotifGui then pcall(function() GENV._OrbitNotifGui:Destroy() end) end
    shared.ORBIT = nil
    rawset(_G, "ORBIT", nil)
    if GENV then GENV.ORBIT = nil end
end

local loaderGui = Instance.new("ScreenGui")
loaderGui.Name = "_OrbitLoader_" .. tostring(math.random(100000, 999999))
loaderGui.ResetOnSpawn = false
loaderGui.IgnoreGuiInset = true
loaderGui.DisplayOrder = 99999
loaderGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
protectGui(loaderGui)
local okp = pcall(function() loaderGui.Parent = getSafeParent() end)
if not okp or not loaderGui.Parent then loaderGui.Parent = PlayerGui end
GENV._OrbitLoaderGui = loaderGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 300)
frame.Position = UDim2.new(0.5, -160, 0.5, -150)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
frame.BorderSizePixel = 0
frame.Parent = loaderGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
local frStroke = Instance.new("UIStroke", frame)
frStroke.Color = Color3.fromRGB(140, 100, 255)
frStroke.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "✨ ОРБИТА " .. ORBIT.version
title.TextColor3 = Color3.fromRGB(220, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -20, 0, 20)
subtitle.Position = UDim2.new(0, 10, 0, 36)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Загрузите части 2, 3, 4 по очереди"
subtitle.TextColor3 = Color3.fromRGB(160, 150, 200)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 44)
statusLabel.Position = UDim2.new(0, 10, 0, 60)
statusLabel.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
statusLabel.BackgroundTransparency = 0.3
statusLabel.BorderSizePixel = 0
statusLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = "  Статус: 1/4 загружено\n  Часть 1: ✅"
statusLabel.Parent = frame
Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 8)

local BASE_URL = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local PARTS = {
    { num = 2, file = "orbit_p2.lua", desc = "⬇ Часть 2: ФИГУРЫ (24 шт.)" },
    { num = 3, file = "orbit_p3.lua", desc = "⬇ Часть 3: ЛОГИКА / АУРА / ЦИКЛ" },
    { num = 4, file = "orbit_p4.lua", desc = "⬇ Часть 4: ИНТЕРФЕЙС" },
}

local partButtons = {}
local yStart = 112
for i, part in ipairs(PARTS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 32)
    btn.Position = UDim2.new(0, 10, 0, yStart + (i - 1) * 34)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.TextColor3 = Color3.fromRGB(220, 220, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = part.desc
    btn.AutoButtonColor = true
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    partButtons[part.num] = btn
end

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -20, 0, 40)
startBtn.Position = UDim2.new(0, 10, 0, 222)
startBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
startBtn.TextColor3 = Color3.fromRGB(150, 150, 180)
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 14
startBtn.Text = "⏳ Ждём части 2-4..."
startBtn.AutoButtonColor = true
startBtn.Parent = frame
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Text = "✖"
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.Activated:Connect(function() frame.Visible = false end)

local function refreshStatus()
    local n = 1
    if ORBIT.loaded.p2 then n = n + 1 end
    if ORBIT.loaded.p3 then n = n + 1 end
    if ORBIT.loaded.p4 then n = n + 1 end
    local lines = {
        "  Статус: " .. n .. "/4 загружено",
        "  Часть 1: ✅" .. (ORBIT.loaded.p2 and "  Часть 2: ✅" or "  Часть 2: ⬜"),
        "  Часть 3: " .. (ORBIT.loaded.p3 and "✅" or "⬜") .. "  Часть 4: " .. (ORBIT.loaded.p4 and "✅" or "⬜"),
    }
    statusLabel.Text = table.concat(lines, "\n")
    if ORBIT.loaded.p2 and ORBIT.loaded.p3 and ORBIT.loaded.p4 then
        startBtn.Text = "▶ ЗАПУСТИТЬ ОРБИТУ"
        startBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 60)
        startBtn.TextColor3 = Color3.fromRGB(180, 255, 180)
    else
        startBtn.Text = "⏳ Ждём части 2-4..."
        startBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        startBtn.TextColor3 = Color3.fromRGB(150, 150, 180)
    end
end
ORBIT.refreshLoaderStatus = refreshStatus
refreshStatus()

local loading = {}
local function loadPart(part)
    if loading[part.num] then return end
    if ORBIT.loaded["p" .. part.num] then
        ORBIT.notify("Часть " .. part.num .. " уже загружена", Color3.fromRGB(255, 200, 100))
        return
    end
    loading[part.num] = true
    local btn = partButtons[part.num]
    btn.Text = "⏳ Загрузка части " .. part.num .. "..."
    btn.BackgroundColor3 = Color3.fromRGB(60, 50, 30)

    task.spawn(function()
        local url = BASE_URL .. part.file .. "?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src < 100 then
            btn.Text = "❌ Ошибка сети: часть " .. part.num
            btn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
            loading[part.num] = nil
            ORBIT.notify("❌ Не удалось скачать часть " .. part.num, Color3.fromRGB(255, 100, 100), 4)
            task.wait(2)
            btn.Text = part.desc
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            return
        end

        local fn, err = loadstring(src)
        if not fn then
            btn.Text = "❌ Ошибка компиляции ч." .. part.num
            btn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
            loading[part.num] = nil
            ORBIT.notify("❌ Compile: " .. tostring(err):sub(1, 90), Color3.fromRGB(255, 100, 100), 6)
            task.wait(3)
            btn.Text = part.desc
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            return
        end

        local runOk, runErr = pcall(fn)
        if not runOk then
            btn.Text = "❌ Ошибка запуска ч." .. part.num
            btn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
            loading[part.num] = nil
            ORBIT.notify("❌ Runtime: " .. tostring(runErr):sub(1, 90), Color3.fromRGB(255, 100, 100), 6)
            task.wait(3)
            btn.Text = part.desc
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            return
        end

        ORBIT.loaded["p" .. part.num] = true
        btn.Text = "✅ Часть " .. part.num .. " загружена"
        btn.BackgroundColor3 = Color3.fromRGB(40, 75, 50)
        btn.TextColor3 = Color3.fromRGB(180, 255, 180)
        loading[part.num] = nil
        ORBIT.notify("✅ Часть " .. part.num .. " загружена", Color3.fromRGB(160, 255, 180), 3)
        refreshStatus()
    end)
end

for _, part in ipairs(PARTS) do
    local btn = partButtons[part.num]
    btn.Activated:Connect(function() loadPart(part) end)
end

startBtn.Activated:Connect(function()
    if not (ORBIT.loaded.p2 and ORBIT.loaded.p3 and ORBIT.loaded.p4) then
        ORBIT.notify("⏳ Сначала загрузи все части", Color3.fromRGB(255, 200, 100), 3)
        return
    end
    if ORBIT.started then
        ORBIT.notify("Скрипт уже запущен", Color3.fromRGB(255, 200, 100), 2)
        return
    end
    ORBIT.started = true
    startBtn.Text = "▶ Работает"
    startBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 50)
    task.wait(0.2)
    frame.Visible = false
    pcall(function() ORBIT.start() end)
end)

task.spawn(function()
    task.wait(0.5)
    for _, part in ipairs(PARTS) do
        if not ORBIT.loaded["p" .. part.num] then
            task.wait(0.3)
            loadPart(part)
        end
    end
end)

ORBIT.notify("✨ Орбита: загружаю части 2-4...", Color3.fromRGB(200, 200, 255), 4)

return ORBIT
