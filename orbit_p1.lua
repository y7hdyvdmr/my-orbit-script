--[[
    ╔══════════════════════════════════════════════════════════╗
    ║   ОРБИТА v23.1 — CORE + LOADER                           ║
    ║   Часть 1/4: ЯДРО + НАСТРОЙКИ + ЗАГРУЗЧИК                ║
    ║   🆕 ОБЛОЖКА ЗАГРУЗКИ — большая иконка этапа              ║
    ║   🆕 Карточки частей с иконками и статусами                ║
    ║   🆕 Выбор платформы (Телефон / ПК)                       ║
    ║   🆕 Последовательная загрузка (без гонки)                ║
    ║   🆕 Чистый unload (боты, кольца, ESP, extras)            ║
    ╚══════════════════════════════════════════════════════════╝
--]]

local GENV = rawget(_G, "getgenv") and getgenv() or _G
local OLD = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (GENV and GENV.ORBIT)
if OLD and OLD.unload then pcall(OLD.unload) end

local ORBIT = {}
shared.ORBIT = ORBIT
rawset(_G, "ORBIT", ORBIT)
if GENV then GENV.ORBIT = ORBIT end

ORBIT.version = "v23.1"
ORBIT.loaded = { p1 = true, p2 = false, p3 = false, p4 = false, sfx = false, ac = false, extras = false }
ORBIT.started = false
ORBIT.PLATFORM = nil

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local LogService   = game:GetService("LogService")
local UIS          = game:GetService("UserInputService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

ORBIT.Players = Players
ORBIT.RunService = RunService
ORBIT.Workspace = Workspace
ORBIT.SoundService = SoundService
ORBIT.TweenService = TweenService
ORBIT.HttpService = HttpService
ORBIT.LogService = LogService
ORBIT.UIS = UIS
ORBIT.LocalPlayer = LocalPlayer
ORBIT.PlayerGui = PlayerGui
ORBIT.SAVE_FILE = "orbit_v21_settings.json"
ORBIT.SAVES_FILE = "orbit_v21_saves.json"
ORBIT.HAS_FS = (writefile and readfile and isfile and type(writefile) == "function")

-- ==================== БЕЗОПАСНЫЙ PROTECT GUI ====================
local function getSafeParent()
    local gethuiFn = rawget(GENV, "gethui")
    if type(gethuiFn) == "function" then
        local ok, hui = pcall(gethuiFn)
        if ok and hui then return hui end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return PlayerGui
end

local function protectGui(gui)
    if not gui then return end
    local synTbl = rawget(GENV, "syn")
    if type(synTbl) == "table" and type(synTbl.protect_gui) == "function" then
        pcall(synTbl.protect_gui, gui); return
    end
    local protectFn = rawget(GENV, "protect_gui")
    if type(protectFn) == "function" then
        pcall(protectFn, gui); return
    end
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)
end

ORBIT.getSafeParent = getSafeParent
ORBIT.protectGui = protectGui

-- ==================== АНТИСПАМ АНИМАЦИЙ ====================
local function isAnimError(msg)
    if type(msg) ~= "string" then return false end
    return msg:find("Animation failed to load", 1, true)
        or msg:find("Failed to load animation", 1, true)
        or msg:find("animation with sanitized ID", 1, true)
end
ORBIT.animErrorCount = 0
pcall(function()
    LogService.MessageOut:Connect(function(msg, msgType)
        if msgType == Enum.MessageType.MessageError and isAnimError(msg) then
            ORBIT.animErrorCount = (ORBIT.animErrorCount or 0) + 1
            if ORBIT.animErrorCount % 10 == 0 then
                pcall(function() LogService:ClearOutput() end)
            end
        end
    end)
end)

-- ==================== НАСТРОЙКИ ====================
ORBIT.DEFAULT_SETTINGS = {
    BlockCount = 8, BaseShapeSize = 1.5, OrbitSpeed = 60, SpinSpeed = 120,
    SpeedMultiplier = 1.0, SpinSpeedMultiplier = 1.0, BobAmplitude = 0.8,
    Material = Enum.Material.Neon, Transparency = 0.1,
    LightRange = 6, LightLimit = 20, LightEnabled = true,
    Rainbow = true, FixedColor = Color3.fromRGB(0, 180, 255),
    ShowBlockNames = false, NameColor = Color3.fromRGB(255, 255, 255),
    LerpSpeed = 5.0,
    TrailEnabled = false, TrailLength = 0.5, TrailWidth = 0.8,
    PulseEnabled = false, PulseAmplitude = 0.15, PulseSpeed = 4.0,
    WaveEnabled = false, WaveSpeed = 3.0, WaveLength = 2.0, WaveAmplitude = 2.5,
    ExplosionEnabled = false, ExplosionSpeed = 0.4, ExplosionPower = 0.7,
    HeartScale = 0.65, OrbitPattern = "Круг",

    AuraEnabled = false, AuraSize = 3.5, AuraThickness = 0.15,
    AuraColor = Color3.fromRGB(150, 100, 255),
    AuraRing = true, AuraParticles = true, AuraShapes = true,
    AuraSpeedMult = 1.0, AuraDirection = 1,
    AuraHeight = 0.5, AuraShapeScale = 1.0,
    AuraTrailEnabled = false, AuraTrailLength = 0.5, AuraTrailWidth = 0.8,
    AuraSpinEnabled = true, AuraSpinAxis = "Y", AuraSpinSpeed = 60,
    AuraPulseEnabled = false,
    AuraPattern = "Круг",

    FireEnabled = false, FireColor = Color3.fromRGB(255, 120, 0),
    FireSize = 6, FireHeat = 8,
    AutoSaveEnabled = false,
    ShowNotifications = true, NotificationsDuration = 2,
    RainbowSpeed = 0.15,
    GradientEnabled = false, GradientSpeed = 0.5,
    AutoShapeSwap = false, AutoShapeSwapInterval = 15,

    ProtEnabled = false,
    AntiKnockback = true, AntiTeleport = true, AntiFreeze = true,
    AutoHeal = false, AutoHealValue = 100,
    AntiVoid = true, AntiVoidY = 5, AntiExplosion = true, AntiFling = true,
    SavePosOnEnable = false, LockPosition = false,
    SmartFloor = true, SmartFloorY = 5, DisableFallDamage = true,
    DodgeEnabled = false, ReverseFlingEnabled = false,

    ESPEnabled = false, ESPMaxDistance = 500,

    UseMySkin = false, AutoCollect = true, CollectRadius = 12,

    -- Extras
    AtmoEnabled = false, AtmoType = "Снег", AtmoIntensity = "Средняя", AtmoSize = "Средний",
    TrailStreamEnabled = false, TrailStreamColorMode = "Радуга",
    ReactSparksEnabled = false,
}
ORBIT.SETTINGS = table.clone(ORBIT.DEFAULT_SETTINGS)

-- ==================== ПРЕСЕТЫ ====================
local P = {}

P.SPIN_SPEED = {
    {name="0.5x",value=0.5},{name="1x",value=1.0},{name="2x",value=2.0},
    {name="3x",value=3.0},{name="5x",value=5.0},{name="10x",value=10.0},
}
P.spinSpeedIndex = 2
P.SPREAD = {
    {name="1x плотно",mult=1.0},{name="1.5x",mult=1.5},{name="2x средне",mult=2.0},
    {name="3x широко",mult=3.0},{name="5x максимально",mult=5.0},
}
P.spreadIndex = 2
P.HEIGHT = {
    {name="Возле (у ног)",offset=-3.0},{name="Ноги",offset=-1.0},{name="Низко",offset=0.5},
    {name="Середина",offset=2.0},{name="Туловище",offset=3.0},{name="Голова",offset=4.5},
    {name="Высоко",offset=6.5},{name="Небо",offset=35.0},{name="Космос",offset=60.0},
}
P.heightIndex = 4
P.SPEED = {
    {name="0.5x",value=0.5},{name="1x",value=1.0},{name="1.5x",value=1.5},
    {name="2x",value=2.0},{name="3x",value=3.0},{name="5x",value=5.0},{name="10x",value=10.0},
}
P.speedIndex = 2
P.SPEED_MODE = {
    {name="Разная",mults={1.0,1.3,0.7,1.6,0.5}},
    {name="Одинаковая",mults={1.0,1.0,1.0,1.0,1.0}},
}
P.speedModeIndex = 1
P.DIRECTION = {
    {name="Чередование",dirs={1,-1,1,-1,1}},
    {name="Все ↻",dirs={1,1,1,1,1}},
    {name="Все ↺",dirs={-1,-1,-1,-1,-1}},
    {name="Попарно",dirs={1,1,-1,-1,1}},
}
P.directionIndex = 1
P.FORM_MODES = { {name="Одинаковая"},{name="Разные"} }
P.formModeIndex = 1
P.ORBIT = {
    {name="S",radius=5,height=2},{name="M",radius=8,height=3},
    {name="L",radius=12,height=4},{name="XL",radius=18,height=6},{name="XXL",radius=25,height=8},
}
P.orbitIndex = 2
P.SHAPE_SIZE = {
    {name="XS",factor=0.5},{name="S",factor=0.75},{name="M",factor=1.0},
    {name="L",factor=1.5},{name="XL",factor=2.2},{name="XXL",factor=3.0},
}
P.shapeSizeIndex = 3
P.ORBIT_PATTERNS = {
    {name="Круг"},{name="Спираль"},{name="Волна"},{name="Восьмёрка"},
    {name="Зигзаг"},{name="Лиссажу"},{name="Хаос"},
}
P.orbitPatternIndex = 1

P.SHAPE_CATEGORIES = {
    {name="ВСЕ"},
    {name="ОСНОВНЫЕ",  shapes={"БЛОК","ШАР","ЦИЛИНДР","КЛИН","ТРЕУГОЛЬНИК","ЗВЕЗДА","КРЕСТ","РОМБ","КОСТЬ","ПИРАМИДА","СПИРАЛЬ"}},
    {name="ОРУЖИЕ",    shapes={"МЕЧ","ЩИТ"}},
    {name="МАГИЯ",     shapes={"ГЛАЗ","ИНЬ-ЯН","МОЛНИЯ","ГАСТЕР БЛАСТЕР"}},
    {name="СУЩЕСТВА",  shapes={"ЧЕРЕП","РУКА","РУКА-СЕРДЦЕ","ГОЛОВА","СЕРДЦЕ","КРЫЛЬЯ","ЩУПАЛЬЦЕ"}},
}
P.shapeCategoryIndex = 1

P.COLORS = {
    {name="РАДУГА",rainbow=true},
    {name="КРАСНЫЙ",c=Color3.fromRGB(255,50,50)},
    {name="ОРАНЖЕВЫЙ",c=Color3.fromRGB(255,140,40)},
    {name="ЖЁЛТЫЙ",c=Color3.fromRGB(255,230,60)},
    {name="ЗЕЛЁНЫЙ",c=Color3.fromRGB(0,255,120)},
    {name="ГОЛУБОЙ",c=Color3.fromRGB(0,180,255)},
    {name="СИНИЙ",c=Color3.fromRGB(40,80,255)},
    {name="ФИОЛЕТОВЫЙ",c=Color3.fromRGB(160,80,255)},
    {name="РОЗОВЫЙ",c=Color3.fromRGB(255,90,180)},
    {name="НЕОН-РОЗОВЫЙ",c=Color3.fromRGB(255,0,200)},
    {name="НЕОН-ЗЕЛЁНЫЙ",c=Color3.fromRGB(80,255,80)},
    {name="НЕОН-ГОЛУБОЙ",c=Color3.fromRGB(0,255,255)},
    {name="НЕОН-ЖЁЛТЫЙ",c=Color3.fromRGB(255,255,0)},
    {name="НЕОН-ОРАНЖ",c=Color3.fromRGB(255,120,0)},
    {name="НЕОН-ФИОЛЕТ",c=Color3.fromRGB(200,0,255)},
    {name="ЗОЛОТОЙ",c=Color3.fromRGB(255,200,40)},
    {name="СЕРЕБРЯНЫЙ",c=Color3.fromRGB(220,220,230)},
    {name="БРОНЗОВЫЙ",c=Color3.fromRGB(205,127,50)},
    {name="МЕДНЫЙ",c=Color3.fromRGB(184,115,51)},
    {name="ОГОНЬ",c=Color3.fromRGB(255,90,0)},
    {name="ЛАВА",c=Color3.fromRGB(200,40,0)},
    {name="ЛЁД",c=Color3.fromRGB(180,230,255)},
    {name="ТРАВА",c=Color3.fromRGB(90,200,80)},
    {name="НЕБО",c=Color3.fromRGB(120,190,255)},
    {name="БИРЮЗОВЫЙ",c=Color3.fromRGB(64,224,208)},
    {name="ИЗУМРУД",c=Color3.fromRGB(80,200,120)},
    {name="РУБИН",c=Color3.fromRGB(220,20,90)},
    {name="САПФИР",c=Color3.fromRGB(15,82,186)},
    {name="КОРАЛЛ",c=Color3.fromRGB(255,127,80)},
    {name="ЛАВАНДА",c=Color3.fromRGB(180,130,255)},
    {name="БЕЛЫЙ",c=Color3.fromRGB(245,245,255)},
    {name="СЕРЫЙ",c=Color3.fromRGB(150,150,160)},
    {name="ЧЁРНЫЙ",c=Color3.fromRGB(25,25,30)},
    {name="МАЛИНОВЫЙ",c=Color3.fromRGB(200,0,80)},
    {name="ИНДИГО",c=Color3.fromRGB(75,0,130)},
    {name="ХАКИ",c=Color3.fromRGB(189,183,107)},
}
P.colorIndex = 1
P.auraColorIndex = 1

P.HEART_STEPS = {0.2, 0.35, 0.5, 0.65, 0.9, 1.2, 1.6, 2.2}

P.TRAIL_LEN = {
    {name="Короткий",value=0.25},{name="Средний",value=0.5},
    {name="Длинный",value=0.9},{name="Очень длинный",value=1.6},{name="Гигантский",value=2.5},
}
P.trailLengthIndex = 2
P.TRAIL_WID = {
    {name="Тонкий",value=0.3},{name="Средний",value=0.8},
    {name="Толстый",value=1.5},{name="Широкий",value=2.5},{name="Огромный",value=4.0},
}
P.trailWidthIndex = 2

P.AURA_TRAIL_LEN = {
    {name="Микро",value=0.1},{name="Очень короткий",value=0.2},{name="Короткий",value=0.35},
    {name="Средний",value=0.6},{name="Длинный",value=1.0},{name="Очень длинный",value=1.8},
    {name="Гигантский",value=3.0},{name="Огромный",value=5.0},{name="Бесконечный",value=10.0},
    {name="Абсолютный",value=20.0},
}
P.auraTrailLengthIndex = 4
P.AURA_TRAIL_WID = {
    {name="Тонкий",value=0.3},{name="Средний",value=0.8},{name="Толстый",value=1.5},
    {name="Широкий",value=2.5},{name="Огромный",value=4.0},{name="Гигантский",value=6.5},
    {name="Колоссальный",value=10.0},{name="Мега",value=15.0},{name="Абсолютный",value=25.0},
}
P.auraTrailWidthIndex = 2

P.AURA_SPEED = {
    {name="0.25x",value=0.25},{name="0.5x",value=0.5},{name="1x",value=1.0},
    {name="2x",value=2.0},{name="3x",value=3.0},{name="5x",value=5.0},
}
P.auraSpeedIndex = 3
P.AURA_DIR = { {name="→ Право (↻)",value=1},{name="← Лево (↺)",value=-1} }
P.auraDirIndex = 1
P.AURA_SIZE = {
    {name="XS",value=2.0},{name="S",value=3.0},{name="M",value=3.5},
    {name="L",value=5.0},{name="XL",value=7.0},{name="XXL",value=10.0},
}
P.auraSizeIndex = 3
P.AURA_THICK = {
    {name="Тонкая",value=0.08},{name="Обычная",value=0.15},
    {name="Толстая",value=0.3},{name="Очень толстая",value=0.5},
}
P.auraThickIndex = 2
P.AURA_HEIGHT = {
    {name="Низко (ноги)",value=-1.0},{name="Обычно",value=0.5},{name="Середина",value=1.5},
    {name="Туловище",value=2.5},{name="Грудь",value=3.5},{name="Голова",value=4.5},{name="Высоко",value=6.5},
}
P.auraHeightIndex = 2
P.AURA_SHAPE_SCALE = {
    {name="Крошка",factor=0.3},{name="XS",factor=0.45},{name="S",factor=0.6},
    {name="M",factor=0.8},{name="L",factor=1.0},{name="XL",factor=1.3},{name="XXL",factor=1.7},
}
P.auraShapeScaleIndex = 3
P.AURA_SPIN_SPEED = {
    {name="0.5x",value=30},{name="1x",value=60},{name="2x",value=120},
    {name="3x",value=180},{name="5x",value=300},{name="10x",value=600},
}
P.auraSpinSpeedIndex = 2
P.AURA_SPIN_AXIS = {
    {name="↕️ ВЕРХ/ВНИЗ",value="Y"},{name="↔️ ВЛЕВО/ВПРАВО",value="X"},
}
P.auraSpinAxisIndex = 1
P.AURA_PATTERNS = {
    {name="Круг"},{name="Спираль"},{name="Волна"},{name="Восьмёрка"},
    {name="Зигзаг"},{name="Лиссажу"},{name="Хаос"},
}
P.auraPatternIndex = 1

P.FIRE_SIZE = {
    {name="Маленький",value=3},{name="Средний",value=6},{name="Большой",value=10},
    {name="Огромный",value=16},{name="Адский",value=25},
}
P.fireSizeIndex = 2
P.FIRE_HEAT = {
    {name="Холодный",value=3},{name="Тёплый",value=8},{name="Горячий",value=15},
    {name="Пламя",value=22},{name="Инферно",value=30},
}
P.fireHeatIndex = 2

ORBIT.P = P

-- ==================== СОСТОЯНИЕ ====================
ORBIT.enabled = true
ORBIT.spinResetting = false
ORBIT.spinAxisEnabled = true
ORBIT.spinAxisDir = "X"
ORBIT.updateConn = nil
ORBIT.protConn = nil
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
ORBIT.fireFolder = nil
ORBIT.fireParts = {}
ORBIT.shapeIndex = 1
ORBIT.SHAPE_PRESETS = nil
ORBIT.RING_STEP = 5
ORBIT.SAVES = {}
ORBIT.lastSafePos = nil

ORBIT.SESSION = {
    botsCollected = 0, cheatersTagged = 0, dodgesMade = 0,
    protectionsTriggered = 0, startTime = tick(),
    coinsSpent = 0, coinsEarned = 0,
}

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

function ORBIT.applyPlatformDefaults()
    if ORBIT.PLATFORM == "mobile" then
        ORBIT.SETTINGS.BlockCount = 6
        ORBIT.SETTINGS.LightLimit = 12
        ORBIT.SETTINGS.LightEnabled = true
        ORBIT.SETTINGS.TrailEnabled = false
        ORBIT.SETTINGS.AuraParticles = true
        ORBIT.SETTINGS.AuraShapes = true
        ORBIT.SETTINGS.ESPEnabled = false
    else
        ORBIT.SETTINGS.BlockCount = 8
        ORBIT.SETTINGS.LightLimit = 20
        ORBIT.SETTINGS.LightEnabled = true
        ORBIT.SETTINGS.TrailEnabled = false
        ORBIT.SETTINGS.ESPEnabled = false
    end
end

-- ==================== МУЗЫКА ====================
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

-- ==================== ЗВУКИ (заглушки) ====================
ORBIT.SOUNDS = {
    Enabled = true, Volume = 1.0,
    ClickId = "rbxasset://sounds/button.wav",
    DodgeId = "rbxasset://sounds/snap.mp3",
    AfterDodgeId = "rbxasset://sounds/electronicpingshort.wav",
    SansVoiceId = "rbxasset://sounds/electronicpingshort.wav",
    BotId = "rbxasset://sounds/electronicpingshort.wav",
}
function ORBIT.playSound(id, volume, pitch)
    if not ORBIT.SOUNDS.Enabled then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = volume or ORBIT.SOUNDS.Volume
        if pitch then s.PlaybackSpeed = pitch end
        s.Parent = SoundService
        s:Play()
        task.delay(6, function() pcall(function() s:Destroy() end) end)
    end)
end
function ORBIT.playClick() ORBIT.playSound(ORBIT.SOUNDS.ClickId) end
function ORBIT.playBotCollect() ORBIT.playSound(ORBIT.SOUNDS.BotId) end
function ORBIT.playDodge()
    ORBIT.playSound(ORBIT.SOUNDS.DodgeId)
    task.delay(0.3, function() ORBIT.playSound(ORBIT.SOUNDS.AfterDodgeId) end)
end
function ORBIT.playBuy() ORBIT.playSound(ORBIT.SOUNDS.ClickId) end
function ORBIT.playWin() ORBIT.playSound(ORBIT.SOUNDS.ClickId) end

-- ==================== УВЕДОМЛЕНИЯ ====================
ORBIT.NOTIF_QUEUE = {}
function ORBIT.notify(text, color, duration)
    if not ORBIT.SETTINGS.ShowNotifications then return end
    table.insert(ORBIT.NOTIF_QUEUE, {
        text = text,
        color = color or Color3.fromRGB(140, 255, 200),
        duration = duration or ORBIT.SETTINGS.NotificationsDuration,
    })
end

-- ==================== ХЕЛПЕРЫ ====================
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

function ORBIT.getCurrentShapeSize() return ORBIT.SETTINGS.BaseShapeSize * P.SHAPE_SIZE[P.shapeSizeIndex].factor end
function ORBIT.getTargetRadius(ri) return P.ORBIT[P.orbitIndex].radius + ORBIT.rings[ri].radiusOffset * ORBIT.RING_STEP * P.SPREAD[P.spreadIndex].mult end
function ORBIT.getHeightOffset() return P.HEIGHT[P.heightIndex].offset end
function ORBIT.getTargetHeight(ri) return P.ORBIT[P.orbitIndex].height + ORBIT.rings[ri].heightOffset * P.SPREAD[P.spreadIndex].mult + ORBIT.getHeightOffset() end
function ORBIT.getTargetSpeed() return ORBIT.SETTINGS.OrbitSpeed * ORBIT.SETTINGS.SpeedMultiplier end
function ORBIT.getTargetSpin() return ORBIT.SETTINGS.SpinSpeed * ORBIT.SETTINGS.SpeedMultiplier * ORBIT.SETTINGS.SpinSpeedMultiplier end

-- ==================== СОХРАНЕНИЯ ====================
function ORBIT.loadSavesList()
    if not ORBIT.HAS_FS then return end
    pcall(function()
        if isfile(ORBIT.SAVES_FILE) then
            local txt = readfile(ORBIT.SAVES_FILE)
            if txt and #txt > 0 then ORBIT.SAVES = HttpService:JSONDecode(txt) or {} end
        end
    end)
end
function ORBIT.saveSavesList()
    if not ORBIT.HAS_FS then return false end
    return pcall(function()
        writefile(ORBIT.SAVES_FILE, HttpService:JSONEncode(ORBIT.SAVES))
    end)
end

-- ==================== ЧИСТЫЙ UNLOAD ====================
ORBIT.unload = function()
    if ORBIT.updateConn then pcall(function() ORBIT.updateConn:Disconnect() end); ORBIT.updateConn = nil end
    if ORBIT.protConn then pcall(function() ORBIT.protConn:Disconnect() end); ORBIT.protConn = nil end
    for ri in pairs(ORBIT.rings) do
        local r = ORBIT.rings[ri]
        if r.folder then pcall(function() r.folder:Destroy() end); r.folder = nil end
    end
    if ORBIT.auraFolder then pcall(function() ORBIT.auraFolder:Destroy() end); ORBIT.auraFolder = nil end
    if ORBIT.fireFolder then pcall(function() ORBIT.fireFolder:Destroy() end); ORBIT.fireFolder = nil end
    if ORBIT.cleanupAllTargetRings then pcall(ORBIT.cleanupAllTargetRings) end
    if ORBIT.removeAllBots then pcall(ORBIT.removeAllBots) end
    if ORBIT.ESP and ORBIT.removeESPTag then
        for p in pairs(ORBIT.ESP.Tags or {}) do pcall(ORBIT.removeESPTag, p) end
    end
    if ORBIT.fireworkFolder then pcall(function() ORBIT.fireworkFolder:Destroy() end); ORBIT.fireworkFolder = nil end
    if ORBIT.sfxFolder then pcall(function() ORBIT.sfxFolder:Destroy() end); ORBIT.sfxFolder = nil end
    if ORBIT.musicSound then pcall(function() ORBIT.musicSound:Destroy() end); ORBIT.musicSound = nil end
    if ORBIT.stopUltra then pcall(ORBIT.stopUltra) end
    if GENV._OrbitLoaderGui then pcall(function() GENV._OrbitLoaderGui:Destroy() end) end
    if GENV._OrbitMainGui then pcall(function() GENV._OrbitMainGui:Destroy() end) end
    shared.ORBIT = nil
    rawset(_G, "ORBIT", nil)
    if GENV then GENV.ORBIT = nil end
end
ORBIT.start = function()
    ORBIT.notify("⏳ Не все части загружены", Color3.fromRGB(255,200,100), 3)
end

-- ============================================================
--              ЗАГРУЗЧИК
-- ============================================================
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

local LC_BG     = Color3.fromRGB(10, 18, 14)
local LC_GREEN  = Color3.fromRGB(92, 255, 180)
local LC_ORANGE = Color3.fromRGB(255, 168, 79)
local LC_DIM    = Color3.fromRGB(80, 120, 95)
local LC_BORDER = Color3.fromRGB(60, 140, 90)
local LC_RED    = Color3.fromRGB(255, 100, 100)

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.4
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Parent = loaderGui

-- ============================================================
--       ЭКРАН ВЫБОРА ПЛАТФОРМЫ
-- ============================================================
local platformScreen = Instance.new("Frame")
platformScreen.Size = UDim2.new(0, 500, 0, 620)
platformScreen.Position = UDim2.new(0.5, -250, 0.5, -310)
platformScreen.BackgroundColor3 = LC_BG
platformScreen.BorderSizePixel = 0
platformScreen.ZIndex = 10
platformScreen.Parent = loaderGui
Instance.new("UICorner", platformScreen).CornerRadius = UDim.new(0, 6)

local pStroke = Instance.new("UIStroke", platformScreen)
pStroke.Color = LC_BORDER; pStroke.Thickness = 1.5; pStroke.Transparency = 0.2

local pTitle = Instance.new("TextLabel")
pTitle.Size = UDim2.new(1, 0, 0, 60)
pTitle.Position = UDim2.new(0, 0, 0, 60)
pTitle.BackgroundTransparency = 1
pTitle.Text = "ОРБИТА " .. ORBIT.version
pTitle.TextColor3 = LC_GREEN
pTitle.Font = Enum.Font.Code
pTitle.TextSize = 36
pTitle.ZIndex = 11
pTitle.Parent = platformScreen

local pSub = Instance.new("TextLabel")
pSub.Size = UDim2.new(1, 0, 0, 24)
pSub.Position = UDim2.new(0, 0, 0, 122)
pSub.BackgroundTransparency = 1
pSub.Text = "ВЫБЕРИ СВОЮ ПЛАТФОРМУ"
pSub.TextColor3 = LC_ORANGE
pSub.Font = Enum.Font.Code
pSub.TextSize = 15
pSub.ZIndex = 11
pSub.Parent = platformScreen

local pHint = Instance.new("TextLabel")
pHint.Size = UDim2.new(1, 0, 0, 20)
pHint.Position = UDim2.new(0, 0, 0, 152)
pHint.BackgroundTransparency = 1
pHint.Text = "от этого зависят настройки и размер интерфейса"
pHint.TextColor3 = LC_DIM
pHint.Font = Enum.Font.Code
pHint.TextSize = 11
pHint.ZIndex = 11
pHint.Parent = platformScreen

local mobileBtn = Instance.new("TextButton")
mobileBtn.Size = UDim2.new(0, 220, 0, 200)
mobileBtn.Position = UDim2.new(0, 30, 0, 200)
mobileBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 32)
mobileBtn.BackgroundTransparency = 0.15
mobileBtn.TextColor3 = LC_GREEN
mobileBtn.Font = Enum.Font.Code
mobileBtn.TextSize = 18
mobileBtn.Text = "📱\nТЕЛЕФОН\n\n• Меньше фигур\n• Легче эффекты\n• Большие кнопки"
mobileBtn.AutoButtonColor = false
mobileBtn.ZIndex = 11
mobileBtn.Parent = platformScreen
Instance.new("UICorner", mobileBtn).CornerRadius = UDim.new(0, 12)
local mbStroke = Instance.new("UIStroke", mobileBtn)
mbStroke.Color = LC_BORDER; mbStroke.Thickness = 2; mbStroke.Transparency = 0.3

local pcBtn = Instance.new("TextButton")
pcBtn.Size = UDim2.new(0, 220, 0, 200)
pcBtn.Position = UDim2.new(0, 250, 0, 200)
pcBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 32)
pcBtn.BackgroundTransparency = 0.15
pcBtn.TextColor3 = LC_GREEN
pcBtn.Font = Enum.Font.Code
pcBtn.TextSize = 18
pcBtn.Text = "💻\nКОМПЬЮТЕР\n\n• Больше фигур\n• Все эффекты\n• Полный UI"
pcBtn.AutoButtonColor = false
pcBtn.ZIndex = 11
pcBtn.Parent = platformScreen
Instance.new("UICorner", pcBtn).CornerRadius = UDim.new(0, 12)
local pcStroke = Instance.new("UIStroke", pcBtn)
pcStroke.Color = LC_BORDER; pcStroke.Thickness = 2; pcStroke.Transparency = 0.3

local autoDetectLbl = Instance.new("TextLabel")
autoDetectLbl.Size = UDim2.new(1, 0, 0, 20)
autoDetectLbl.Position = UDim2.new(0, 0, 0, 420)
autoDetectLbl.BackgroundTransparency = 1
autoDetectLbl.Text = UIS.TouchEnabled and "👉 Похоже, ты на телефоне" or "👉 Похоже, ты на ПК"
autoDetectLbl.TextColor3 = LC_DIM
autoDetectLbl.Font = Enum.Font.Code
autoDetectLbl.TextSize = 12
autoDetectLbl.ZIndex = 11
autoDetectLbl.Parent = platformScreen

local function highlightBtn(btn, stroke, on)
    TweenService:Create(btn, TweenInfo.new(0.1), {
        BackgroundColor3 = on and LC_GREEN or Color3.fromRGB(25, 45, 32),
        TextColor3 = on and Color3.fromRGB(10, 25, 18) or LC_GREEN,
    }):Play()
    stroke.Color = on and LC_ORANGE or LC_BORDER
end

mobileBtn.MouseButton1Down:Connect(function() highlightBtn(mobileBtn, mbStroke, true) end)
mobileBtn.MouseButton1Up:Connect(function() highlightBtn(mobileBtn, mbStroke, false) end)
mobileBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then highlightBtn(mobileBtn, mbStroke, true) end
end)
mobileBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then highlightBtn(mobileBtn, mbStroke, false) end
end)

pcBtn.MouseButton1Down:Connect(function() highlightBtn(pcBtn, pcStroke, true) end)
pcBtn.MouseButton1Up:Connect(function() highlightBtn(pcBtn, pcStroke, false) end)
pcBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then highlightBtn(pcBtn, pcStroke, true) end
end)
pcBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then highlightBtn(pcBtn, pcStroke, false) end
end)

-- ============================================================
--       ОСНОВНОЙ ЭКРАН ЗАГРУЗЧИКА
-- ============================================================
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 500, 0, 620)
frame.Position = UDim2.new(0.5, -250, 0.5, -310)
frame.BackgroundColor3 = LC_BG
frame.BorderSizePixel = 0
frame.ZIndex = 2
frame.Visible = false
frame.Parent = loaderGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

local frameStroke = Instance.new("UIStroke", frame)
frameStroke.Color = LC_BORDER
frameStroke.Thickness = 1.5
frameStroke.Transparency = 0.2

local function makeCorner(x, y, isRight, isBottom)
    local h = Instance.new("Frame")
    h.Size = UDim2.new(0, 30, 0, 2)
    h.Position = UDim2.new(x, isRight and -30 or 0, y, isBottom and -2 or 0)
    h.BackgroundColor3 = LC_GREEN
    h.BorderSizePixel = 0
    h.ZIndex = 4
    h.Parent = frame
    local v = Instance.new("Frame")
    v.Size = UDim2.new(0, 2, 0, 30)
    v.Position = UDim2.new(x, isRight and -2 or 0, y, isBottom and -30 or 0)
    v.BackgroundColor3 = LC_GREEN
    v.BorderSizePixel = 0
    v.ZIndex = 4
    v.Parent = frame
end
makeCorner(0.02, 0.02, false, false)
makeCorner(0.98, 0.02, true, false)
makeCorner(0.02, 0.98, false, true)
makeCorner(0.98, 0.98, true, true)

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -180, 0, 26)
title.Position = UDim2.new(0, 16, 0, 6)
title.BackgroundTransparency = 1
title.Text = "ОРБИТА " .. ORBIT.version
title.TextColor3 = LC_GREEN
title.Font = Enum.Font.Code
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = frame

local platformBadge = Instance.new("TextLabel")
platformBadge.Size = UDim2.new(0, 150, 0, 22)
platformBadge.Position = UDim2.new(1, -166, 0, 8)
platformBadge.BackgroundColor3 = Color3.fromRGB(25, 45, 32)
platformBadge.BorderSizePixel = 0
platformBadge.Text = "PLATFORM: —"
platformBadge.TextColor3 = LC_ORANGE
platformBadge.Font = Enum.Font.Code
platformBadge.TextSize = 11
platformBadge.ZIndex = 4
platformBadge.Parent = frame
Instance.new("UICorner", platformBadge).CornerRadius = UDim.new(0, 6)

-- ============================================================
--       🆕 ОБЛОЖКА — большая иконка текущего этапа
-- ============================================================
local coverHolder = Instance.new("Frame")
coverHolder.Size = UDim2.new(1, -32, 0, 78)
coverHolder.Position = UDim2.new(0, 16, 0, 38)
coverHolder.BackgroundColor3 = Color3.fromRGB(12, 22, 16)
coverHolder.BorderSizePixel = 0
coverHolder.ZIndex = 3
coverHolder.Parent = frame
Instance.new("UICorner", coverHolder).CornerRadius = UDim.new(0, 10)

local coverStroke = Instance.new("UIStroke", coverHolder)
coverStroke.Color = LC_BORDER
coverStroke.Thickness = 1
coverStroke.Transparency = 0.5

local coverIconFrame = Instance.new("Frame")
coverIconFrame.Size = UDim2.new(0, 60, 0, 60)
coverIconFrame.Position = UDim2.new(0, 9, 0.5, -30)
coverIconFrame.BackgroundColor3 = Color3.fromRGB(20, 40, 28)
coverIconFrame.BorderSizePixel = 0
coverIconFrame.ZIndex = 4
coverIconFrame.Parent = coverHolder
Instance.new("UICorner", coverIconFrame).CornerRadius = UDim.new(1, 0)

local coverIconStroke = Instance.new("UIStroke", coverIconFrame)
coverIconStroke.Color = LC_GREEN
coverIconStroke.Thickness = 2
coverIconStroke.Transparency = 0.3

local coverIcon = Instance.new("TextLabel")
coverIcon.Size = UDim2.new(1, 0, 1, 0)
coverIcon.BackgroundTransparency = 1
coverIcon.Text = "✨"
coverIcon.TextColor3 = LC_GREEN
coverIcon.Font = Enum.Font.GothamBold
coverIcon.TextSize = 34
coverIcon.ZIndex = 5
coverIcon.Parent = coverIconFrame

local coverTitle = Instance.new("TextLabel")
coverTitle.Size = UDim2.new(1, -82, 0, 22)
coverTitle.Position = UDim2.new(0, 78, 0, 14)
coverTitle.BackgroundTransparency = 1
coverTitle.Text = "ГОТОВ К СТАРТУ"
coverTitle.TextColor3 = LC_GREEN
coverTitle.Font = Enum.Font.Code
coverTitle.TextSize = 15
coverTitle.TextXAlignment = Enum.TextXAlignment.Left
coverTitle.ZIndex = 5
coverTitle.Parent = coverHolder

local coverSub = Instance.new("TextLabel")
coverSub.Size = UDim2.new(1, -82, 0, 16)
coverSub.Position = UDim2.new(0, 78, 0, 38)
coverSub.BackgroundTransparency = 1
coverSub.Text = "Нажми на выбор платформы"
coverSub.TextColor3 = LC_DIM
coverSub.Font = Enum.Font.Code
coverSub.TextSize = 10
coverSub.TextXAlignment = Enum.TextXAlignment.Left
coverSub.ZIndex = 5
coverSub.Parent = coverHolder

local coverPulseTween = nil
local function setCover(icon, ttl, sub, color)
    coverIcon.Text = icon
    coverTitle.Text = ttl
    coverSub.Text = sub or ""
    local c = color or LC_GREEN
    coverTitle.TextColor3 = c
    coverIcon.TextColor3 = c
    coverIconStroke.Color = c
end

local function startPulse()
    if coverPulseTween then coverPulseTween:Cancel(); coverPulseTween = nil end
    coverIcon.TextSize = 34
    coverPulseTween = TweenService:Create(
        coverIcon,
        TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { TextSize = 42 }
    )
    coverPulseTween:Play()
end

local function stopPulse()
    if coverPulseTween then coverPulseTween:Cancel(); coverPulseTween = nil end
    coverIcon.TextSize = 34
end

setCover("✨", "ГОТОВ К ЗАГРУЗКЕ", "3 части + античит + звуки + extras", LC_GREEN)

-- ============================================================
--       КАРТОЧКИ ЧАСТЕЙ (с иконками фигур)
-- ============================================================
local BASE_URL = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local PARTS = {
    { num = 2, file = "orbit_p2.lua", title = "PART 2", sub = "ФИГУРЫ",   icon = "🔷", color = Color3.fromRGB(120, 200, 255) },
    { num = 3, file = "orbit_p3.lua", title = "PART 3", sub = "ЛОГИКА",   icon = "⚙️", color = Color3.fromRGB(200, 220, 120) },
    { num = 4, file = "orbit_p4.lua", title = "PART 4", sub = "ИНТЕРФЕЙС",icon = "🎨", color = Color3.fromRGB(220, 160, 255) },
}

local partCards = {}
local cardStartY = 124
for i, part in ipairs(PARTS) do
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -32, 0, 32)
    card.Position = UDim2.new(0, 16, 0, cardStartY + (i - 1) * 36)
    card.BackgroundColor3 = Color3.fromRGB(18, 28, 22)
    card.BorderSizePixel = 0
    card.ZIndex = 3
    card.Parent = frame
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cStroke = Instance.new("UIStroke", card)
    cStroke.Color = part.color
    cStroke.Thickness = 1
    cStroke.Transparency = 0.6

    -- Иконка фигуры
    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, 26, 0, 26)
    iconFrame.Position = UDim2.new(0, 3, 0.5, -13)
    iconFrame.BackgroundColor3 = Color3.fromRGB(25, 38, 30)
    iconFrame.BorderSizePixel = 0
    iconFrame.ZIndex = 4
    iconFrame.Parent = card
    Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(1, 0)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(1, 0, 1, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = part.icon
    iconLbl.TextColor3 = part.color
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 16
    iconLbl.ZIndex = 5
    iconLbl.Parent = iconFrame

    -- Название
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -100, 1, 0)
    nameLbl.Position = UDim2.new(0, 36, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = part.title .. " — " .. part.sub
    nameLbl.TextColor3 = LC_DIM
    nameLbl.Font = Enum.Font.Code
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 5
    nameLbl.Parent = card

    -- Статус-иконка
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 32, 1, 0)
    statusLbl.Position = UDim2.new(1, -36, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "⬜"
    statusLbl.TextColor3 = LC_DIM
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 14
    statusLbl.ZIndex = 5
    statusLbl.Parent = card

    -- Кнопка поверх (для ручной загрузки)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 6
    btn.Parent = card
    btn.Activated:Connect(function() loadPart(part) end)

    partCards[part.num] = {
        card = card, iconLbl = iconLbl, nameLbl = nameLbl,
        statusLbl = statusLbl, stroke = cStroke, btn = btn,
    }
end

local function setPartStatus(num, status)
    local card = partCards[num]
    if not card then return end
    if status == "wait" then
        card.statusLbl.Text = "⬜"
        card.statusLbl.TextColor3 = LC_DIM
        card.nameLbl.TextColor3 = LC_DIM
    elseif status == "loading" then
        card.statusLbl.Text = "⏳"
        card.statusLbl.TextColor3 = LC_ORANGE
        card.nameLbl.TextColor3 = LC_ORANGE
    elseif status == "ok" then
        card.statusLbl.Text = "✅"
        card.statusLbl.TextColor3 = LC_GREEN
        card.nameLbl.TextColor3 = LC_GREEN
    elseif status == "error" then
        card.statusLbl.Text = "❌"
        card.statusLbl.TextColor3 = LC_RED
        card.nameLbl.TextColor3 = LC_RED
    end
end

-- ============================================================
--       ПРОГРЕСС-БАР
-- ============================================================
local progHolder = Instance.new("Frame")
progHolder.Size = UDim2.new(1, -32, 0, 30)
progHolder.Position = UDim2.new(0, 16, 0, 235)
progHolder.BackgroundColor3 = Color3.fromRGB(15, 26, 20)
progHolder.BorderSizePixel = 0
progHolder.ZIndex = 3
progHolder.Parent = frame
Instance.new("UICorner", progHolder).CornerRadius = UDim.new(0, 8)
local progStroke = Instance.new("UIStroke", progHolder)
progStroke.Color = LC_BORDER; progStroke.Thickness = 1; progStroke.Transparency = 0.4

local progFill = Instance.new("Frame")
progFill.Size = UDim2.new(0.25, 0, 1, 0)
progFill.BackgroundColor3 = LC_GREEN
progFill.BorderSizePixel = 0
progFill.ZIndex = 4
progFill.Parent = progHolder
Instance.new("UICorner", progFill).CornerRadius = UDim.new(0, 8)

local progText = Instance.new("TextLabel")
progText.Size = UDim2.new(1, 0, 1, 0)
progText.BackgroundTransparency = 1
progText.Text = "LOADING... 25%  [1/4]"
progText.TextColor3 = Color3.fromRGB(20, 40, 28)
progText.Font = Enum.Font.Code
progText.TextSize = 13
progText.ZIndex = 5
progText.Parent = progHolder

-- ============================================================
--       ТЕРМИНАЛ (логи)
-- ============================================================
local term = Instance.new("Frame")
term.Size = UDim2.new(1, -32, 0, 190)
term.Position = UDim2.new(0, 16, 0, 271)
term.BackgroundColor3 = Color3.fromRGB(6, 12, 9)
term.BorderSizePixel = 0
term.ZIndex = 3
term.Parent = frame
Instance.new("UICorner", term).CornerRadius = UDim.new(0, 8)
local termStroke = Instance.new("UIStroke", term)
termStroke.Color = LC_BORDER
termStroke.Thickness = 1
termStroke.Transparency = 0.4

local termHeader = Instance.new("Frame")
termHeader.Size = UDim2.new(1, 0, 0, 22)
termHeader.BackgroundColor3 = Color3.fromRGB(18, 30, 22)
termHeader.BorderSizePixel = 0
termHeader.ZIndex = 4
termHeader.Parent = term
Instance.new("UICorner", termHeader).CornerRadius = UDim.new(0, 8)

local function makeDot(x, color)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 8, 0, 8)
    d.Position = UDim2.new(0, x, 0.5, -4)
    d.BackgroundColor3 = color
    d.BorderSizePixel = 0
    d.ZIndex = 5
    d.Parent = termHeader
    Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
end
makeDot(10, Color3.fromRGB(255, 95, 86))
makeDot(24, Color3.fromRGB(255, 189, 46))
makeDot(38, Color3.fromRGB(39, 201, 63))

local termTitle = Instance.new("TextLabel")
termTitle.Size = UDim2.new(1, -60, 1, 0)
termTitle.Position = UDim2.new(0, 56, 0, 0)
termTitle.BackgroundTransparency = 1
termTitle.Text = "orbitloader — bash"
termTitle.TextColor3 = LC_DIM
termTitle.Font = Enum.Font.Code
termTitle.TextSize = 11
termTitle.TextXAlignment = Enum.TextXAlignment.Left
termTitle.ZIndex = 5
termTitle.Parent = termHeader

local termScroll = Instance.new("ScrollingFrame")
termScroll.Size = UDim2.new(1, -8, 1, -28)
termScroll.Position = UDim2.new(0, 4, 0, 24)
termScroll.BackgroundTransparency = 1
termScroll.BorderSizePixel = 0
termScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
termScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
termScroll.ScrollBarThickness = 3
termScroll.ScrollBarImageColor3 = LC_GREEN
termScroll.ScrollingDirection = Enum.ScrollingDirection.Y
termScroll.ZIndex = 4
termScroll.Parent = term

local consoleLabel = Instance.new("TextLabel")
consoleLabel.Size = UDim2.new(1, -10, 0, 0)
consoleLabel.Position = UDim2.new(0, 8, 0, 4)
consoleLabel.BackgroundTransparency = 1
consoleLabel.Text = ""
consoleLabel.TextColor3 = LC_GREEN
consoleLabel.Font = Enum.Font.Code
consoleLabel.TextSize = 11
consoleLabel.TextXAlignment = Enum.TextXAlignment.Left
consoleLabel.TextYAlignment = Enum.TextYAlignment.Top
consoleLabel.RichText = true
consoleLabel.TextWrapped = true
consoleLabel.AutomaticSize = Enum.AutomaticSize.Y
consoleLabel.ZIndex = 4
consoleLabel.Parent = termScroll

local LOG_ENTRIES = {}
local LOG_COLORS = { INFO="5CFFB4", WAIT="FFD966", WARN="FFA84F", OK="80FF80", ERR="FF6B6B", SYS="8CD0FF" }
local function addLog(kind, text)
    local c = LOG_COLORS[kind] or "5CFFB4"
    table.insert(LOG_ENTRIES, string.format('<font color="#%s">[%s]</font> %s', c, kind, text))
    if #LOG_ENTRIES > 60 then table.remove(LOG_ENTRIES, 1) end
    consoleLabel.Text = table.concat(LOG_ENTRIES, "\n")
    task.wait()
    termScroll.CanvasPosition = Vector2.new(0, math.max(0, termScroll.AbsoluteCanvasSize.Y - termScroll.AbsoluteWindowSize.Y))
end
ORBIT.addLog = addLog

-- ============================================================
--       КНОПКА СТАРТА
-- ============================================================
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -32, 0, 44)
startBtn.Position = UDim2.new(0, 16, 1, -76)
startBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 32)
startBtn.BackgroundTransparency = 0.15
startBtn.TextColor3 = LC_DIM
startBtn.Font = Enum.Font.Code
startBtn.TextSize = 15
startBtn.Text = "⌛ ЖДЁМ ЧАСТИ..."
startBtn.AutoButtonColor = false
startBtn.ZIndex = 3
startBtn.Parent = frame
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)
local stStroke = Instance.new("UIStroke", startBtn)
stStroke.Color = LC_BORDER; stStroke.Thickness = 1.5; stStroke.Transparency = 0.4

local statusBar = Instance.new("TextLabel")
statusBar.Size = UDim2.new(1, -32, 0, 18)
statusBar.Position = UDim2.new(0, 16, 1, -26)
statusBar.BackgroundTransparency = 1
statusBar.Text = "> ORBITA INITIALIZED  |  READY"
statusBar.TextColor3 = LC_GREEN
statusBar.Font = Enum.Font.Code
statusBar.TextSize = 10
statusBar.TextXAlignment = Enum.TextXAlignment.Left
statusBar.ZIndex = 3
statusBar.Parent = frame

-- ============================================================
--       ОБНОВЛЕНИЕ ПРОГРЕССА
-- ============================================================
local function refreshStatus()
    local n = 1
    if ORBIT.loaded.p2 then n = n + 1 end
    if ORBIT.loaded.p3 then n = n + 1 end
    if ORBIT.loaded.p4 then n = n + 1 end

    TweenService:Create(progFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {Size = UDim2.new(n / 4, 0, 1, 0)}):Play()
    progText.Text = string.format("LOADING... %d%%  [%d/4]", math.floor(n * 25), n)

    if n >= 4 then
        progText.TextColor3 = Color3.fromRGB(10, 30, 20)
        startBtn.Text = "▶  ЗАПУСТИТЬ ОРБИТУ"
        startBtn.TextColor3 = LC_GREEN
        stStroke.Color = LC_GREEN
        stStroke.Transparency = 0.1
        statusBar.Text = "> ORBITA INITIALIZED  |  ALL PARTS LOADED  |  READY"
    end
end
ORBIT.refreshLoaderStatus = refreshStatus

-- ============================================================
--       ЗАГРУЗКА ЧАСТИ
-- ============================================================
local loading = {}

local function loadPart(part, onDone)
    if loading[part.num] then
        if onDone then onDone(false) end
        return
    end
    if ORBIT.loaded["p" .. part.num] then
        if onDone then onDone(true) end
        return
    end
    loading[part.num] = true
    setPartStatus(part.num, "loading")

    -- Обложка
    setCover(part.icon, "ЗАГРУЗКА: " .. part.sub, part.file .. " — скачивание...", part.color)
    startPulse()

    addLog("INFO", "Downloading " .. part.file .. "...")

    task.spawn(function()
        local success = false
        local maxRetries = 3
        for attempt = 1, maxRetries do
            local url = BASE_URL .. part.file .. "?t=" .. os.time() .. "&a=" .. attempt
            local ok, src = pcall(function() return game:HttpGet(url) end)
            if not ok or type(src) ~= "string" or #src < 100 then
                addLog("WARN", "Attempt " .. attempt .. " failed (download)")
                task.wait(0.4)
                continue
            end
            local fn, err = loadstring(src)
            if not fn then
                addLog("ERR", "Compile error: " .. tostring(err):sub(1, 50))
                task.wait(0.4)
                continue
            end
            local runOk, runErr = pcall(fn)
            if not runOk then
                addLog("ERR", "Runtime error: " .. tostring(runErr):sub(1, 50))
                task.wait(0.4)
                continue
            end
            success = true
            break
        end

        if not success then
            setPartStatus(part.num, "error")
            setCover("❌", "ОШИБКА ЗАГРУЗКИ", part.file, LC_RED)
            stopPulse()
            addLog("ERR", "Failed: " .. part.file)
            loading[part.num] = nil
            task.wait(2)
            setCover("⚠️", "ОЖИДАНИЕ", "нажми на карточку ещё раз", LC_ORANGE)
            if onDone then onDone(false) end
            return
        end

        -- Проверка
        local verified = true
        if part.num == 2 and (not ORBIT.SHAPE_PRESETS or #ORBIT.SHAPE_PRESETS < 3) then
            verified = false
            addLog("WARN", "Part 2 loaded but SHAPE_PRESETS empty!")
        end
        if part.num == 3 and not ORBIT.startUpdateLoop then
            verified = false
            addLog("WARN", "Part 3 loaded but startUpdateLoop missing!")
        end
        if part.num == 4 and not ORBIT.ui then
            verified = false
            addLog("WARN", "Part 4 loaded but ORBIT.ui missing!")
        end

        if not verified then
            ORBIT.loaded["p" .. part.num] = false
            setPartStatus(part.num, "error")
            loading[part.num] = nil
            if onDone then onDone(false) end
            return
        end

        ORBIT.loaded["p" .. part.num] = true
        setPartStatus(part.num, "ok")
        stopPulse()
        addLog("OK", part.title .. " — " .. part.sub .. " загружено")
        ORBIT.notify("✅ " .. part.sub .. " загружено", Color3.fromRGB(160, 255, 180), 2)
        refreshStatus()

        -- Обложка кратко "готово", но следующая часть перепишет
        setCover("✅", "ГОТОВО: " .. part.sub, "переход к следующему этапу...", LC_GREEN)

        if onDone then onDone(true) end
    end)
end

-- Автоматическая последовательная загрузка
local function autoLoadAll()
    task.wait(0.3)
    loadPart(PARTS[1], function(ok1)
        if not ok1 then
            setCover("⚠️", "ЧАСТЬ 2 НЕ ЗАГРУЖЕНА", "проверь интернет и нажми ещё раз", LC_ORANGE)
            addLog("WARN", "Пропускаю 3 и 4")
            return
        end
        task.wait(0.3)
        loadPart(PARTS[2], function(ok2)
            if not ok2 then
                setCover("⚠️", "ЧАСТЬ 3 НЕ ЗАГРУЖЕНА", "нажми на карточку ещё раз", LC_ORANGE)
                addLog("WARN", "Пропускаю 4")
                return
            end
            task.wait(0.3)
            loadPart(PARTS[3], function(ok3)
                if not ok3 then
                    setCover("⚠️", "ЧАСТЬ 4 НЕ ЗАГРУЖЕНА", "нажми на карточку ещё раз", LC_ORANGE)
                    return
                end
                addLog("OK", "Все части загружены — можно стартовать")
                setCover("✅", "ВСЁ ГОТОВО", "нажми ЗАПУСТИТЬ ОРБИТУ внизу", LC_GREEN)
            end)
        end)
    end)
end

-- ============================================================
--       ДОП. ЭТАПЫ (античит, sfx, extras) — показываются в обложке
-- ============================================================
task.spawn(function()
    task.wait(3.2)
    -- Anti-Cheat
    if not ORBIT.loaded.ac then
        setCover("🛡️", "ЗАГРУЗКА: ЗАЩИТА", "orbit_anticheat.lua...", Color3.fromRGB(255, 140, 140))
        startPulse()
        local url = BASE_URL .. "orbit_anticheat.lua?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and type(src) == "string" and #src > 100 then
            local fn = loadstring(src)
            if fn then
                local runOk, runErr = pcall(fn)
                if runOk then
                    ORBIT.loaded.ac = true
                    addLog("OK", "🛡️ Античит загружен")
                else
                    addLog("ERR", "AntiCheat error: " .. tostring(runErr):sub(1, 40))
                end
            end
        else
            addLog("WARN", "Античит не скачался — можно запустить вручную")
        end
        stopPulse()
    end

    task.wait(0.5)
    -- SFX
    if not ORBIT.loaded.sfx then
        setCover("🎵", "ЗАГРУЗКА: ЗВУКИ", "orbit_sfx.lua...", Color3.fromRGB(255, 200, 255))
        startPulse()
        local url = BASE_URL .. "orbit_sfx.lua?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and type(src) == "string" and #src > 100 then
            local fn = loadstring(src)
            if fn then
                local runOk = pcall(fn)
                if runOk then ORBIT.loaded.sfx = true; addLog("OK", "🎵 SFX загружены") end
            end
        else
            addLog("WARN", "SFX не скачались")
        end
        stopPulse()
    end

    task.wait(0.5)
    -- Extras
    if not ORBIT.loaded.extras then
        setCover("✨", "ЗАГРУЗКА: ДОПОЛНЕНИЯ", "orbit_extras.lua (атмосфера, шлейф, искры)...", Color3.fromRGB(200, 220, 255))
        startPulse()
        local url = BASE_URL .. "orbit_extras.lua?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if ok and type(src) == "string" and #src > 100 then
            local fn = loadstring(src)
            if fn then
                local runOk, runErr = pcall(fn)
                if runOk then
                    ORBIT.loaded.extras = true
                    addLog("OK", "✨ Extras загружены")
                else
                    addLog("ERR", "Extras error: " .. tostring(runErr):sub(1, 40))
                end
            end
        else
            addLog("WARN", "Extras не скачались")
        end
        stopPulse()
    end

    task.wait(0.4)
    setCover("✅", "ВСЁ ГОТОВО", "нажми ЗАПУСТИТЬ ОРБИТУ", LC_GREEN)
end)

-- ============================================================
--       СТАРТ
-- ============================================================
startBtn.Activated:Connect(function()
    if not (ORBIT.loaded.p2 and ORBIT.loaded.p3 and ORBIT.loaded.p4) then
        ORBIT.notify("⏳ Сначала загрузи все части", Color3.fromRGB(255, 200, 100), 3)
        return
    end
    if ORBIT.started then return end
    ORBIT.started = true
    startBtn.Text = "▶ РАБОТАЕТ..."
    setCover("🚀", "ЗАПУСК ОРБИТЫ", "включаю все системы...", LC_GREEN)
    addLog("OK", "Запуск ОРБИТЫ...")
    task.wait(0.3)
    backdrop.Visible = false
    frame.Visible = false
    pcall(function() ORBIT.start() end)
end)

-- ============================================================
--       ВЫБОР ПЛАТФОРМЫ
-- ============================================================
local function selectPlatform(platform)
    ORBIT.PLATFORM = platform
    ORBIT.applyPlatformDefaults()

    -- Плавно убрать экран выбора
    TweenService:Create(platformScreen, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
    for _, ch in ipairs(platformScreen:GetChildren()) do
        if ch:IsA("TextLabel") or ch:IsA("TextButton") then
            TweenService:Create(ch, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
        end
    end
    task.wait(0.28)
    platformScreen.Visible = false
    frame.Visible = true

    platformBadge.Text = platform == "mobile" and "📱 MOBILE" or "💻 PC"

    addLog("SYS", "$ executing orbit_loader.lua...")
    addLog("INFO", "Platform: " .. platform:upper())
    addLog("INFO", "Loading ORBITA " .. ORBIT.version)
    ORBIT.loadSavesList()
    local saveCount = 0
    for _ in pairs(ORBIT.SAVES) do saveCount = saveCount + 1 end
    addLog("OK", "Found " .. saveCount .. " save(s)")
    addLog("OK", "BlockCount: " .. ORBIT.SETTINGS.BlockCount)
    addLog("OK", "Sounds: ENABLED")

    setCover("✨", "СТАРТ ЗАГРУЗКИ", "части 2 → 3 → 4 → защиты → extras", LC_GREEN)

    task.spawn(autoLoadAll)
end

mobileBtn.Activated:Connect(function() selectPlatform("mobile") end)
pcBtn.Activated:Connect(function() selectPlatform("pc") end)

ORBIT.notify("✨ ОРБИТА " .. ORBIT.version .. " — выбери платформу", Color3.fromRGB(200, 200, 255), 4)

return ORBIT
