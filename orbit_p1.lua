-- ORBIT v24.0 | orbit_p1.lua
-- ЯДРО + НАСТРОЙКИ (без загрузчика — загрузкой занимается orbit_loader.lua)
-- v24.0: ORBIT.saveData (+ rigType), ORBIT.mode, ORBIT.RigType; ORBIT.loaded + флаги;
--        ORBIT.unload чистит новые модули через pcall.
-- v24.0-fix3: УБРАН встроенный загрузчик (loader GUI + autoLoadAll).
--             Теперь p1 = чистое ядро. Запуск только через orbit_loader.lua.

local GENV = rawget(_G, "getgenv") and getgenv() or _G
local OLD = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (GENV and GENV.ORBIT)
if OLD and OLD.unload then pcall(OLD.unload) end

local ORBIT = {}
shared.ORBIT = ORBIT
rawset(_G, "ORBIT", ORBIT)
if GENV then GENV.ORBIT = ORBIT end

ORBIT.version = "v24.0"
ORBIT.loaded = { p1 = true, p2 = false, p3 = false, p4 = false, share = false, sfx = false, ac = false, extras = false, editor3d = false, helper = false,
    sans = false, abilities = false, animations = false, deathfx = false, gaster = false, newfigures = false, tools = false, anticheat = false, shop = false, minigame = false }
ORBIT.started = false
ORBIT.PLATFORM = nil
ORBIT.saveData = { gasterUnlocked = false, gasterWeaponUnlocked = false, playerMode = "sans", theme = "dark", achievements = {}, rigType = "R15" }
do
    local okR, raw = pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" and isfile("orbit_v21_settings.json") then
            return readfile("orbit_v21_settings.json")
        end
    end)
    if okR and type(raw) == "string" and #raw > 2 then
        local okJ, d = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
        if okJ and type(d) == "table" then
            if d.playerMode == "normal" or d.playerMode == "sans" then ORBIT.saveData.playerMode = d.playerMode end
            if d.gasterUnlocked == true then ORBIT.saveData.gasterUnlocked = true end
            if d.gasterWeaponUnlocked == true then ORBIT.saveData.gasterWeaponUnlocked = true end
            if type(d.theme) == "string" then ORBIT.saveData.theme = d.theme end
            if type(d.achievements) == "table" then ORBIT.saveData.achievements = d.achievements end
            if d.rigType == "R6" or d.rigType == "R15" then ORBIT.saveData.rigType = d.rigType end
        end
    end
end
ORBIT.mode = ORBIT.saveData.playerMode or "sans"
ORBIT.RigType = ORBIT.saveData.rigType or "R15"
ORBIT.gasterUnlocked = ORBIT.saveData.gasterUnlocked
ORBIT.gasterWeaponUnlocked = ORBIT.saveData.gasterWeaponUnlocked
ORBIT.abilityMoveUntil = 0

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
ORBIT.HAS_FS = (type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function")

-- ==================== PROTECT GUI ====================
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
    ORBIT.logConn = LogService.MessageOut:Connect(function(msg, msgType)
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
    TrailEnabled = false, TrailLength = 0.25, TrailWidth = 0.5,
    PulseEnabled = false, PulseAmplitude = 0.15, PulseSpeed = 4.0,
    WaveEnabled = false, WaveSpeed = 3.0, WaveLength = 2.0, WaveAmplitude = 2.5,
    ExplosionEnabled = false, ExplosionSpeed = 0.4, ExplosionPower = 0.7,
    HeartScale = 0.65, OrbitPattern = "Круг",

    AuraEnabled = false, AuraSize = 3.5, AuraThickness = 0.15,
    AuraColor = Color3.fromRGB(150, 100, 255),
    AuraRing = true, AuraParticles = true, AuraShapes = true,
    AuraSpeedMult = 1.0, AuraDirection = 1,
    AuraHeight = 0.5, AuraShapeScale = 1.0,
    AuraTrailEnabled = false, AuraTrailLength = 0.25, AuraTrailWidth = 0.35,
    AuraSpinEnabled = true, AuraSpinAxis = "Y", AuraSpinSpeed = 60,
    AuraPulseEnabled = false,
    AuraPattern = "Круг",
    AuraLightEnabled = false, AuraLightRange = 8, AuraLightBrightness = 2,
    AuraMaterial = Enum.Material.Neon, AuraGlow = 1.0, AuraParticleStyle = 1,

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

    AtmoEnabled = false, AtmoType = "Снег", AtmoIntensity = "Средняя", AtmoSize = "Средний",
    AtmoColorMode = "Авто", AtmoColorIndex = 1,
    TrailStreamEnabled = false, TrailStreamColorMode = "Радуга", TrailStreamColorIndex = 1,
    ReactSparksEnabled = false, ReactSparksColorIndex = 1,
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
    {name="Все по часовой",dirs={1,1,1,1,1}},
    {name="Все против",dirs={-1,-1,-1,-1,-1}},
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
    {name="СУЩЕСТВА",  shapes={"ЧЕРЕП","РУКА","РУКА-СЕРДЦЕ","ГОЛОВА","СЕРДЦЕ","КРЫЛЬЯ","ЩУПАЛЬЦЕ","СКАЛА","ДРАКОН","ЦВЕТОК ФЛАУИ","ОМЕГА ФЛАУИ","КОРОНА","ФЕНИКС","ПОРТАЛ"}},
}
P.shapeCategoryIndex = 1

P.COLORS = {
    {name="РАДУГА",rainbow=true},
    {name="КРАСНЫЙ",c=Color3.fromRGB(255,50,50)},
    {name="АЛЫЙ",c=Color3.fromRGB(220,20,60)},
    {name="ОРАНЖЕВЫЙ",c=Color3.fromRGB(255,140,40)},
    {name="ПЕРСИКОВЫЙ",c=Color3.fromRGB(255,180,120)},
    {name="АБРИКОСОВЫЙ",c=Color3.fromRGB(255,200,150)},
    {name="ЖЁЛТЫЙ",c=Color3.fromRGB(255,230,60)},
    {name="ЗОЛОТОЙ",c=Color3.fromRGB(255,200,40)},
    {name="МЁД",c=Color3.fromRGB(240,190,80)},
    {name="ШАФРАН",c=Color3.fromRGB(255,180,30)},
    {name="ЗЕЛЁНЫЙ",c=Color3.fromRGB(0,255,120)},
    {name="ЛАЙМ",c=Color3.fromRGB(180,255,80)},
    {name="САЛАТОВЫЙ",c=Color3.fromRGB(150,230,100)},
    {name="МЯТА",c=Color3.fromRGB(150,255,200)},
    {name="ИЗУМРУД",c=Color3.fromRGB(80,200,120)},
    {name="ТРАВА",c=Color3.fromRGB(90,200,80)},
    {name="ОЛИВКОВЫЙ",c=Color3.fromRGB(150,170,80)},
    {name="ХАКИ",c=Color3.fromRGB(189,183,107)},
    {name="ГОЛУБОЙ",c=Color3.fromRGB(0,180,255)},
    {name="НЕБО",c=Color3.fromRGB(120,190,255)},
    {name="ЛАЗУРЬ",c=Color3.fromRGB(80,180,255)},
    {name="БИРЮЗОВЫЙ",c=Color3.fromRGB(64,224,208)},
    {name="АКВАМАРИН",c=Color3.fromRGB(120,220,220)},
    {name="МОРСКАЯ ВОЛНА",c=Color3.fromRGB(64,180,180)},
    {name="ЛЁД",c=Color3.fromRGB(180,230,255)},
    {name="СИНИЙ",c=Color3.fromRGB(40,80,255)},
    {name="САПФИР",c=Color3.fromRGB(15,82,186)},
    {name="ИНДИГО",c=Color3.fromRGB(75,0,130)},
    {name="ФИОЛЕТОВЫЙ",c=Color3.fromRGB(160,80,255)},
    {name="АМЕТИСТ",c=Color3.fromRGB(180,100,240)},
    {name="ЛАВАНДА",c=Color3.fromRGB(180,130,255)},
    {name="СИРЕНЕВЫЙ",c=Color3.fromRGB(200,160,255)},
    {name="ОРХИДЕЯ",c=Color3.fromRGB(220,120,230)},
    {name="ПУРПУРНЫЙ",c=Color3.fromRGB(140,30,180)},
    {name="МАДЖЕНТА",c=Color3.fromRGB(255,0,200)},
    {name="РОЗОВЫЙ",c=Color3.fromRGB(255,90,180)},
    {name="КАРМИН",c=Color3.fromRGB(230,30,90)},
    {name="ВИШНЯ",c=Color3.fromRGB(180,30,60)},
    {name="МАЛИНОВЫЙ",c=Color3.fromRGB(200,0,80)},
    {name="БОРДО",c=Color3.fromRGB(120,20,40)},
    {name="РУБИН",c=Color3.fromRGB(220,20,90)},
    {name="КОРАЛЛ",c=Color3.fromRGB(255,127,80)},
    {name="ТЕРРАКОТА",c=Color3.fromRGB(200,110,80)},
    {name="МЕДНЫЙ",c=Color3.fromRGB(184,115,51)},
    {name="БРОНЗОВЫЙ",c=Color3.fromRGB(205,127,50)},
    {name="ОГОНЬ",c=Color3.fromRGB(255,90,0)},
    {name="ЛАВА",c=Color3.fromRGB(200,40,0)},
    {name="БЕЛЫЙ",c=Color3.fromRGB(245,245,255)},
    {name="СЕРЕБРЯНЫЙ",c=Color3.fromRGB(220,220,230)},
    {name="СЕРЫЙ",c=Color3.fromRGB(150,150,160)},
    {name="ЧЁРНЫЙ",c=Color3.fromRGB(25,25,30)},
}
P.colorIndex = 1
P.auraColorIndex = 1

P.HEART_STEPS = {0.2, 0.35, 0.5, 0.65, 0.9, 1.2, 1.6, 2.2}

P.TRAIL_LEN = {
    {name="Крошечный",value=0.05},{name="Микро",value=0.1},
    {name="Очень короткий",value=0.15},{name="Короткий",value=0.25},
    {name="Средний",value=0.5},{name="Длинный",value=0.9},
    {name="Очень длинный",value=1.6},{name="Гигантский",value=2.5},
}
P.trailLengthIndex = 4
P.TRAIL_WID = {
    {name="Ниточка",value=0.05},{name="Очень тонкий",value=0.1},
    {name="Тонкий",value=0.2},{name="Средний",value=0.5},
    {name="Толстый",value=1.0},{name="Широкий",value=1.8},
    {name="Огромный",value=3.0},{name="Гигантский",value=4.5},
}
P.trailWidthIndex = 4

P.AURA_TRAIL_LEN = {
    {name="Исчезающий",value=0.02},{name="Крошечный",value=0.05},
    {name="Микро",value=0.1},{name="Очень короткий",value=0.15},
    {name="Короткий",value=0.25},{name="Средний",value=0.5},
    {name="Длинный",value=1.0},{name="Очень длинный",value=1.8},
    {name="Гигантский",value=3.0},{name="Огромный",value=5.0},
}
P.auraTrailLengthIndex = 5
P.AURA_TRAIL_WID = {
    {name="Ниточка",value=0.05},{name="Микро",value=0.1},
    {name="Очень тонкий",value=0.2},{name="Тонкий",value=0.35},
    {name="Средний",value=0.7},{name="Толстый",value=1.4},
    {name="Широкий",value=2.5},{name="Огромный",value=4.5},
    {name="Гигантский",value=7.0},{name="Колоссальный",value=11.0},
}
P.auraTrailWidthIndex = 4

P.AURA_SPEED = {
    {name="0.25x",value=0.25},{name="0.5x",value=0.5},{name="1x",value=1.0},
    {name="2x",value=2.0},{name="3x",value=3.0},{name="5x",value=5.0},
}
P.auraSpeedIndex = 3
P.AURA_DIR = { {name="Вправо",value=1},{name="Влево",value=-1} }
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
    {name="ВЕРХ/ВНИЗ",value="Y"},{name="ВЛЕВО/ВПРАВО",value="X"},
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

-- ==================== ЗВУКИ ====================
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
function ORBIT.playBuy() ORBIT.playSound(ORBIT.SOUNDS.ClickId, nil, 1.3) end
function ORBIT.playWin()
    ORBIT.playSound(ORBIT.SOUNDS.ClickId, nil, 1.2)
    task.delay(0.12, function() ORBIT.playSound(ORBIT.SOUNDS.ClickId, nil, 1.5) end)
    task.delay(0.24, function() ORBIT.playSound(ORBIT.SOUNDS.ClickId, nil, 1.8) end)
end

-- ==================== УВЕДОМЛЕНИЯ ====================
ORBIT.NOTIF_QUEUE = {}
function ORBIT.notify(text, color, duration)
    if not ORBIT.SETTINGS.ShowNotifications then return end
    table.insert(ORBIT.NOTIF_QUEUE, {
        text = text,
        color = color or Color3.fromRGB(140, 255, 200),
        duration = duration or ORBIT.SETTINGS.NotificationsDuration,
    })
    while #ORBIT.NOTIF_QUEUE > 30 do table.remove(ORBIT.NOTIF_QUEUE, 1) end
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

-- ==================== UNLOAD ====================
ORBIT.unload = function()
    if ORBIT.logConn then pcall(function() ORBIT.logConn:Disconnect() end); ORBIT.logConn = nil end
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
    if ORBIT.helperClose then pcall(ORBIT.helperClose) end
    for _, k in ipairs({ "sans", "abilities", "animations", "deathFx", "gaster", "tools", "anticheat" }) do
        local m = ORBIT[k]
        if type(m) == "table" and type(m.destroy) == "function" then pcall(m.destroy) end
    end
    for _, ch in ipairs(Workspace:GetChildren()) do
        local nm = ch.Name
        if nm:find("^OrbitAbility_") or nm:find("^OrbitDeathFx_") or nm:find("^OrbitAtmo_") or nm:find("^OrbitSfx_") then
            pcall(function() ch:Destroy() end)
        end
    end
    if GENV._OrbitLoaderGui then pcall(function() GENV._OrbitLoaderGui:Destroy() end) end
    if GENV._OrbitMainGui then pcall(function() GENV._OrbitMainGui:Destroy() end) end
    shared.ORBIT = nil
    rawset(_G, "ORBIT", nil)
    if GENV then GENV.ORBIT = nil end
end

ORBIT.start = function()
    ORBIT.notify("Не все части загружены", Color3.fromRGB(255,200,100), 3)
end

-- ============================================================
--       ЗАГРУЗЧИК УДАЛЁН (v24.0-fix3)
-- ============================================================
-- Раньше здесь был встроенный GUI-загрузчик + autoLoadAll.
-- Он конфликтовал с orbit_loader.lua (двойная загрузка).
-- Теперь p1 — чистое ядро, загрузкой занимается только orbit_loader.lua.

-- Заглушки для совместимости с модулями (p2/p3/p4 могут их вызывать)
ORBIT.addLog = function() end
ORBIT.refreshLoaderStatus = function() end
ORBIT.currentFile = nil

return ORBIT
