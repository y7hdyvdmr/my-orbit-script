-- ОРБИТА v23.7 — CORE + LOADER
-- Часть 1/4: ЯДРО + НАСТРОЙКИ + ЗАГРУЗЧИК
--
-- ИЗМЕНЕНИЯ v23.5:
--   fix: кнопка «ЗАПУСТИТЬ ОРБИТУ» — now через onTap (Down + Touch + Activated).
--   fix: UIScale + центрирование окон загрузчика под мобильный экран.
--   fix: защита от двойного тапа по выбору платформы.
--   fix: addLog без task.wait() на каждую строку.
--   fix: LogService-подключение отключается при перезапуске.
--   fix: очередь уведомлений — лимит 30.
--   fix: ORBIT.HAS_FS — строгий boolean.
--   fix: в P.SHAPE_CATEGORIES добавлена «СКАЛА».
--   new: helper fetchAndRun с повторами (3 для частей, 2 для модулей).
--   new: playBuy / playWin звучат по-разному.
--   new: плавное появление окон загрузчика.
--
-- ИЗМЕНЕНИЯ v23.6:
--   new: перед античитом грузится orbit_share.lua — модуль обмена фигурами и сохранениями.
--   new: индикатор SHARE в полосе прогресса (9 этапов вместо 8).
--   new: в конце грузится orbit_helper.lua (rule-based помощник).
--
-- ИЗМЕНЕНИЯ v23.7:
--   fix: в лог ошибок добавлено больше текста — sub(1, 60) → sub(1, 300).
--        Раньше сообщение вида «attempt to index nil with 'm'» было обрезано и не
--        показывало имя свойства. Теперь видно полностью.

local GENV = rawget(_G, "getgenv") and getgenv() or _G
local OLD = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (GENV and GENV.ORBIT)
if OLD and OLD.unload then pcall(OLD.unload) end

local ORBIT = {}
shared.ORBIT = ORBIT
rawset(_G, "ORBIT", ORBIT)
if GENV then GENV.ORBIT = ORBIT end

ORBIT.version = "v23.7"
ORBIT.loaded = { p1 = true, p2 = false, p3 = false, p4 = false, share = false, sfx = false, ac = false, extras = false, editor3d = false, helper = false }
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
    {name="СУЩЕСТВА",  shapes={"ЧЕРЕП","РУКА","РУКА-СЕРДЦЕ","ГОЛОВА","СЕРДЦЕ","КРЫЛЬЯ","ЩУПАЛЬЦЕ","СКАЛА"}},
}
P.shapeCategoryIndex = 1

-- 50 ЦВЕТОВ
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

local C_BG      = Color3.fromRGB(12, 8, 20)
local C_PANEL   = Color3.fromRGB(22, 16, 35)
local C_GREEN   = Color3.fromRGB(100, 255, 180)
local C_ORANGE  = Color3.fromRGB(255, 168, 79)
local C_DIM     = Color3.fromRGB(120, 100, 160)
local C_BORDER  = Color3.fromRGB(140, 100, 220)
local C_RED     = Color3.fromRGB(255, 100, 120)
local C_CYAN    = Color3.fromRGB(120, 220, 255)

local function computeLoaderScale(w, h)
    local cam = Workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    return math.clamp(math.min((vp.X - 16) / w, (vp.Y - 16) / h), 0.4, 1)
end

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.35
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 1
backdrop.Parent = loaderGui

local bgGlow = Instance.new("Frame")
bgGlow.Size = UDim2.new(1, 0, 0, 200)
bgGlow.Position = UDim2.new(0, 0, 0, 0)
bgGlow.BackgroundColor3 = C_BORDER
bgGlow.BackgroundTransparency = 0.9
bgGlow.BorderSizePixel = 0
bgGlow.ZIndex = 1
bgGlow.Parent = loaderGui
local bgGlowGradient = Instance.new("UIGradient", bgGlow)
bgGlowGradient.Rotation = 90
bgGlowGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 1),
})

-- ============================================================
--       ЭКРАН ВЫБОРА ПЛАТФОРМЫ
-- ============================================================
local platformScreen = Instance.new("Frame")
platformScreen.Size = UDim2.new(0, 460, 0, 560)
platformScreen.AnchorPoint = Vector2.new(0.5, 0.5)
platformScreen.Position = UDim2.new(0.5, 0, 0.5, 0)
platformScreen.BackgroundColor3 = C_PANEL
platformScreen.BorderSizePixel = 0
platformScreen.ZIndex = 10
platformScreen.Parent = loaderGui
Instance.new("UICorner", platformScreen).CornerRadius = UDim.new(0, 16)
local pScale = Instance.new("UIScale", platformScreen)
local pScaleTarget = computeLoaderScale(460, 560)
pScale.Scale = pScaleTarget * 0.9
TweenService:Create(pScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    { Scale = pScaleTarget }):Play()
local pStroke = Instance.new("UIStroke", platformScreen)
pStroke.Color = C_BORDER; pStroke.Thickness = 2; pStroke.Transparency = 0.2

local logoFrame = Instance.new("Frame")
logoFrame.Size = UDim2.new(0, 80, 0, 80)
logoFrame.Position = UDim2.new(0.5, -40, 0, 30)
logoFrame.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
logoFrame.BorderSizePixel = 0
logoFrame.ZIndex = 11
logoFrame.Parent = platformScreen
Instance.new("UICorner", logoFrame).CornerRadius = UDim.new(1, 0)
local logoStroke = Instance.new("UIStroke", logoFrame)
logoStroke.Color = C_BORDER; logoStroke.Thickness = 2; logoStroke.Transparency = 0.2

local logoIcon = Instance.new("TextLabel")
logoIcon.Size = UDim2.new(1, 0, 1, 0)
logoIcon.BackgroundTransparency = 1
logoIcon.Text = "✨"
logoIcon.TextColor3 = C_GREEN
logoIcon.Font = Enum.Font.GothamBold
logoIcon.TextSize = 44
logoIcon.ZIndex = 12
logoIcon.Parent = logoFrame

TweenService:Create(logoIcon,
    TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { TextSize = 54 }):Play()

local pTitle = Instance.new("TextLabel")
pTitle.Size = UDim2.new(1, 0, 0, 40)
pTitle.Position = UDim2.new(0, 0, 0, 124)
pTitle.BackgroundTransparency = 1
pTitle.Text = "ОРБИТА " .. ORBIT.version
pTitle.TextColor3 = C_GREEN
pTitle.Font = Enum.Font.GothamBold
pTitle.TextSize = 28
pTitle.ZIndex = 11
pTitle.Parent = platformScreen

local pSub = Instance.new("TextLabel")
pSub.Size = UDim2.new(1, 0, 0, 20)
pSub.Position = UDim2.new(0, 0, 0, 164)
pSub.BackgroundTransparency = 1
pSub.Text = "ВЫБЕРИ СВОЮ ПЛАТФОРМУ"
pSub.TextColor3 = C_ORANGE
pSub.Font = Enum.Font.GothamBold
pSub.TextSize = 13
pSub.ZIndex = 11
pSub.Parent = platformScreen

local pHint = Instance.new("TextLabel")
pHint.Size = UDim2.new(1, 0, 0, 18)
pHint.Position = UDim2.new(0, 0, 0, 186)
pHint.BackgroundTransparency = 1
pHint.Text = "интерфейс и настройки подстроятся автоматически"
pHint.TextColor3 = C_DIM
pHint.Font = Enum.Font.Gotham
pHint.TextSize = 10
pHint.ZIndex = 11
pHint.Parent = platformScreen

local function buildPlatformButton(text, icon, x, y, w, h, accent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, w, 0, h)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(28, 22, 45)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 11
    btn.Parent = platformScreen
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = accent
    stroke.Thickness = 2
    stroke.Transparency = 0.4

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(1, 0, 0, 48)
    iconLbl.Position = UDim2.new(0, 0, 0, 12)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextColor3 = accent
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 42
    iconLbl.ZIndex = 12
    iconLbl.Parent = btn

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 22)
    nameLbl.Position = UDim2.new(0, 0, 0, 62)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = text
    nameLbl.TextColor3 = C_GREEN
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 16
    nameLbl.ZIndex = 12
    nameLbl.Parent = btn

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -12, 1, -90)
    descLbl.Position = UDim2.new(0, 6, 0, 90)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = ""
    descLbl.TextColor3 = C_DIM
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 10
    descLbl.ZIndex = 12
    descLbl.Parent = btn

    return btn, stroke, descLbl
end

local mobileBtn, mobileStroke, mobileDesc = buildPlatformButton(
    "ТЕЛЕФОН", "📱", 24, 222, 200, 220, C_CYAN)
mobileDesc.Text = "• Меньше фигур\n• Лёгкие эффекты\n• Крупные кнопки\n• Вертикальный UI"

local pcBtn, pcStroke, pcDesc = buildPlatformButton(
    "КОМПЬЮТЕР", "💻", 236, 222, 200, 220, C_ORANGE)
pcDesc.Text = "• Больше фигур\n• Все эффекты\n• Полный UI\n• Широкие панели"

local autoDetectLbl = Instance.new("TextLabel")
autoDetectLbl.Size = UDim2.new(1, 0, 0, 20)
autoDetectLbl.Position = UDim2.new(0, 0, 0, 456)
autoDetectLbl.BackgroundTransparency = 1
autoDetectLbl.Text = UIS.TouchEnabled and "Похоже, ты на телефоне" or "Похоже, ты на ПК"
autoDetectLbl.TextColor3 = C_DIM
autoDetectLbl.Font = Enum.Font.Gotham
autoDetectLbl.TextSize = 11
autoDetectLbl.ZIndex = 11
autoDetectLbl.Parent = platformScreen

if UIS.TouchEnabled then
    mobileStroke.Color = C_GREEN
    mobileStroke.Transparency = 0.1
    TweenService:Create(mobileStroke,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.6 }):Play()
else
    pcStroke.Color = C_GREEN
    pcStroke.Transparency = 0.1
    TweenService:Create(pcStroke,
        TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.6 }):Play()
end

local function highlightPlatform(btn, stroke, on, accent)
    TweenService:Create(btn, TweenInfo.new(0.1), {
        BackgroundColor3 = on and accent or Color3.fromRGB(28, 22, 45),
    }):Play()
    stroke.Transparency = on and 0.05 or 0.4
end

local function onTap(btn, fn)
    local deb = false
    local function call()
        if deb then return end
        deb = true
        task.delay(0.1, function() deb = false end)
        fn()
    end
    btn.MouseButton1Down:Connect(call)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then call() end
    end)
    btn.Activated:Connect(call)
end

mobileBtn.MouseButton1Down:Connect(function() highlightPlatform(mobileBtn, mobileStroke, true, C_CYAN) end)
mobileBtn.MouseButton1Up:Connect(function() highlightPlatform(mobileBtn, mobileStroke, false, C_CYAN) end)
pcBtn.MouseButton1Down:Connect(function() highlightPlatform(pcBtn, pcStroke, true, C_ORANGE) end)
pcBtn.MouseButton1Up:Connect(function() highlightPlatform(pcBtn, pcStroke, false, C_ORANGE) end)

-- ============================================================
--       ОСНОВНОЙ ЭКРАН ЗАГРУЗЧИКА
-- ============================================================
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 500, 0, 620)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.new(0.5, 0, 0.5, 0)
frame.BackgroundColor3 = C_PANEL
frame.BorderSizePixel = 0
frame.ZIndex = 2
frame.Visible = false
frame.Parent = loaderGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
local frameScale = Instance.new("UIScale", frame)
local frameScaleTarget = computeLoaderScale(500, 620)
frameScale.Scale = frameScaleTarget

local frameStroke = Instance.new("UIStroke", frame)
frameStroke.Color = C_BORDER
frameStroke.Thickness = 2
frameStroke.Transparency = 0.15

local topStrip = Instance.new("Frame")
topStrip.Size = UDim2.new(1, 0, 0, 3)
topStrip.Position = UDim2.new(0, 0, 0, 0)
topStrip.BackgroundColor3 = C_BORDER
topStrip.BorderSizePixel = 0
topStrip.ZIndex = 3
topStrip.Parent = frame
Instance.new("UICorner", topStrip).CornerRadius = UDim.new(0, 16)

local stripGradient = Instance.new("UIGradient", topStrip)
stripGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 255, 180)),
})

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -180, 0, 26)
title.Position = UDim2.new(0, 16, 0, 10)
title.BackgroundTransparency = 1
title.Text = "ОРБИТА " .. ORBIT.version
title.TextColor3 = C_GREEN
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 3
title.Parent = frame

local platformBadge = Instance.new("TextLabel")
platformBadge.Size = UDim2.new(0, 150, 0, 22)
platformBadge.Position = UDim2.new(1, -166, 0, 12)
platformBadge.BackgroundColor3 = Color3.fromRGB(30, 22, 48)
platformBadge.BorderSizePixel = 0
platformBadge.Text = "PLATFORM: —"
platformBadge.TextColor3 = C_ORANGE
platformBadge.Font = Enum.Font.GothamBold
platformBadge.TextSize = 11
platformBadge.ZIndex = 4
platformBadge.Parent = frame
Instance.new("UICorner", platformBadge).CornerRadius = UDim.new(0, 6)

local coverHolder = Instance.new("Frame")
coverHolder.Size = UDim2.new(1, -32, 0, 130)
coverHolder.Position = UDim2.new(0, 16, 0, 44)
coverHolder.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
coverHolder.BorderSizePixel = 0
coverHolder.ZIndex = 3
coverHolder.Parent = frame
Instance.new("UICorner", coverHolder).CornerRadius = UDim.new(0, 12)

local coverStroke = Instance.new("UIStroke", coverHolder)
coverStroke.Color = C_BORDER
coverStroke.Thickness = 1.5
coverStroke.Transparency = 0.4

local ringSize = 96
local ringHolder = Instance.new("Frame")
ringHolder.Size = UDim2.new(0, ringSize, 0, ringSize)
ringHolder.Position = UDim2.new(0, 16, 0.5, -ringSize/2)
ringHolder.BackgroundTransparency = 1
ringHolder.ZIndex = 4
ringHolder.Parent = coverHolder

local ringSegments = {}
local SEGMENTS = 32
for i = 1, SEGMENTS do
    local angle = (i - 1) / SEGMENTS * math.pi * 2 - math.pi / 2
    local r = (ringSize - 8) / 2
    local sx = ringSize / 2 + math.cos(angle) * r - 3
    local sy = ringSize / 2 + math.sin(angle) * r - 3
    local seg = Instance.new("Frame")
    seg.Size = UDim2.new(0, 6, 0, 6)
    seg.Position = UDim2.new(0, sx, 0, sy)
    seg.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
    seg.BorderSizePixel = 0
    seg.ZIndex = 4
    seg.Parent = ringHolder
    Instance.new("UICorner", seg).CornerRadius = UDim.new(1, 0)
    table.insert(ringSegments, seg)
end

local coverIcon = Instance.new("TextLabel")
coverIcon.Size = UDim2.new(0, ringSize - 24, 0, ringSize - 24)
coverIcon.Position = UDim2.new(0, 12, 0, 12)
coverIcon.BackgroundTransparency = 1
coverIcon.Text = "✨"
coverIcon.TextColor3 = C_GREEN
coverIcon.Font = Enum.Font.GothamBold
coverIcon.TextSize = 40
coverIcon.ZIndex = 5
coverIcon.Parent = ringHolder

local function updateRingProgress(percent)
    local active = math.floor(percent * SEGMENTS + 0.5)
    for i, seg in ipairs(ringSegments) do
        if i <= active then
            seg.BackgroundColor3 = C_GREEN
        else
            seg.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
        end
    end
end

local coverTitle = Instance.new("TextLabel")
coverTitle.Size = UDim2.new(1, -132, 0, 22)
coverTitle.Position = UDim2.new(0, 124, 0, 30)
coverTitle.BackgroundTransparency = 1
coverTitle.Text = "ГОТОВ К СТАРТУ"
coverTitle.TextColor3 = C_GREEN
coverTitle.Font = Enum.Font.GothamBold
coverTitle.TextSize = 15
coverTitle.TextXAlignment = Enum.TextXAlignment.Left
coverTitle.ZIndex = 5
coverTitle.Parent = coverHolder

local coverSub = Instance.new("TextLabel")
coverSub.Size = UDim2.new(1, -132, 0, 16)
coverSub.Position = UDim2.new(0, 124, 0, 54)
coverSub.BackgroundTransparency = 1
coverSub.Text = "Нажми на выбор платформы"
coverSub.TextColor3 = C_DIM
coverSub.Font = Enum.Font.Gotham
coverSub.TextSize = 10
coverSub.TextXAlignment = Enum.TextXAlignment.Left
coverSub.ZIndex = 5
coverSub.Parent = coverHolder

local coverStatus = Instance.new("Frame")
coverStatus.Size = UDim2.new(1, -132, 0, 24)
coverStatus.Position = UDim2.new(0, 124, 0, 78)
coverStatus.BackgroundColor3 = Color3.fromRGB(28, 20, 42)
coverStatus.BorderSizePixel = 0
coverStatus.ZIndex = 5
coverStatus.Parent = coverHolder
Instance.new("UICorner", coverStatus).CornerRadius = UDim.new(0, 6)

local coverSteps = {}
local stepsConfig = {
    {name = "P2",    key = "p2"},
    {name = "P3",    key = "p3"},
    {name = "P4",    key = "p4"},
    {name = "SHR",   key = "share"},
    {name = "AC",    key = "ac"},
    {name = "SFX",   key = "sfx"},
    {name = "EX",    key = "extras"},
    {name = "3D",    key = "editor3d"},
    {name = "HEL",   key = "helper"},
}
local stepW = 1 / #stepsConfig
for i, cfg in ipairs(stepsConfig) do
    local stepLbl = Instance.new("TextLabel")
    stepLbl.Size = UDim2.new(stepW, -2, 1, 0)
    stepLbl.Position = UDim2.new((i-1) * stepW, 1, 0, 0)
    stepLbl.BackgroundTransparency = 1
    stepLbl.Text = cfg.name
    stepLbl.TextColor3 = Color3.fromRGB(70, 55, 90)
    stepLbl.Font = Enum.Font.GothamBold
    stepLbl.TextSize = 9
    stepLbl.ZIndex = 6
    stepLbl.Parent = coverStatus
    coverSteps[cfg.key] = stepLbl
end

local function refreshSteps()
    for _, cfg in ipairs(stepsConfig) do
        local lbl = coverSteps[cfg.key]
        if ORBIT.loaded[cfg.key] then
            lbl.TextColor3 = C_GREEN
            lbl.Text = "✓ " .. cfg.name
        else
            lbl.TextColor3 = Color3.fromRGB(70, 55, 90)
            lbl.Text = cfg.name
        end
    end
end

local coverPulseTween = nil
local function setCover(icon, ttl, sub, color)
    coverIcon.Text = icon
    coverTitle.Text = ttl
    coverSub.Text = sub or ""
    local c = color or C_GREEN
    coverTitle.TextColor3 = c
    coverIcon.TextColor3 = c
    coverStroke.Color = c
end

local function startPulse()
    if coverPulseTween then coverPulseTween:Cancel(); coverPulseTween = nil end
    coverIcon.TextSize = 40
    coverPulseTween = TweenService:Create(coverIcon,
        TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { TextSize = 50 })
    coverPulseTween:Play()
end
local function stopPulse()
    if coverPulseTween then coverPulseTween:Cancel(); coverPulseTween = nil end
    coverIcon.TextSize = 40
end

setCover("✨", "ГОТОВ К ЗАГРУЗКЕ", "части 2 → 3 → 4 → share → защита → звуки → extras → 3D", C_GREEN)
updateRingProgress(0.111)
refreshSteps()

-- ============================================================
--       КАРТОЧКИ ЧАСТЕЙ
-- ============================================================
local BASE_URL = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local PARTS = {
    { num = 2, file = "orbit_p2.lua", title = "ЧАСТЬ 2", sub = "ФИГУРЫ",     icon = "🔷", color = Color3.fromRGB(120, 200, 255) },
    { num = 3, file = "orbit_p3.lua", title = "ЧАСТЬ 3", sub = "ЛОГИКА",     icon = "⚙️", color = Color3.fromRGB(200, 220, 120) },
    { num = 4, file = "orbit_p4.lua", title = "ЧАСТЬ 4", sub = "ИНТЕРФЕЙС",  icon = "🎨", color = Color3.fromRGB(220, 160, 255) },
}

local partCards = {}
local cardStartY = 182
for i, part in ipairs(PARTS) do
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -32, 0, 36)
    card.Position = UDim2.new(0, 16, 0, cardStartY + (i - 1) * 40)
    card.BackgroundColor3 = Color3.fromRGB(22, 16, 35)
    card.BorderSizePixel = 0
    card.ZIndex = 3
    card.Parent = frame
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cStroke = Instance.new("UIStroke", card)
    cStroke.Color = part.color
    cStroke.Thickness = 1
    cStroke.Transparency = 0.7

    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, 28, 0, 28)
    iconFrame.Position = UDim2.new(0, 4, 0.5, -14)
    iconFrame.BackgroundColor3 = Color3.fromRGB(30, 22, 45)
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

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -110, 1, 0)
    nameLbl.Position = UDim2.new(0, 40, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = part.title .. "  —  " .. part.sub
    nameLbl.TextColor3 = C_DIM
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 5
    nameLbl.Parent = card

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 40, 1, 0)
    statusLbl.Position = UDim2.new(1, -44, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "⬜"
    statusLbl.TextColor3 = C_DIM
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 14
    statusLbl.ZIndex = 5
    statusLbl.Parent = card

    partCards[part.num] = {
        card = card, iconLbl = iconLbl, nameLbl = nameLbl,
        statusLbl = statusLbl, stroke = cStroke,
    }
end

local function setPartStatus(num, status)
    local card = partCards[num]
    if not card then return end
    if status == "wait" then
        card.statusLbl.Text = "⬜"
        card.statusLbl.TextColor3 = C_DIM
        card.nameLbl.TextColor3 = C_DIM
        card.stroke.Transparency = 0.7
    elseif status == "loading" then
        card.statusLbl.Text = "⏳"
        card.statusLbl.TextColor3 = C_ORANGE
        card.nameLbl.TextColor3 = C_ORANGE
        card.stroke.Transparency = 0.3
    elseif status == "ok" then
        card.statusLbl.Text = "✅"
        card.statusLbl.TextColor3 = C_GREEN
        card.nameLbl.TextColor3 = C_GREEN
        card.stroke.Transparency = 0.2
    elseif status == "error" then
        card.statusLbl.Text = "❌"
        card.statusLbl.TextColor3 = C_RED
        card.nameLbl.TextColor3 = C_RED
        card.stroke.Transparency = 0.1
    end
end

-- ============================================================
--       ЛОГ
-- ============================================================
local term = Instance.new("Frame")
term.Size = UDim2.new(1, -32, 0, 140)
term.Position = UDim2.new(0, 16, 0, 316)
term.BackgroundColor3 = Color3.fromRGB(15, 10, 24)
term.BorderSizePixel = 0
term.ZIndex = 3
term.Parent = frame
Instance.new("UICorner", term).CornerRadius = UDim.new(0, 8)
local termStroke = Instance.new("UIStroke", term)
termStroke.Color = C_BORDER
termStroke.Thickness = 1
termStroke.Transparency = 0.5

local termHeader = Instance.new("Frame")
termHeader.Size = UDim2.new(1, 0, 0, 20)
termHeader.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
termHeader.BorderSizePixel = 0
termHeader.ZIndex = 4
termHeader.Parent = term
Instance.new("UICorner", termHeader).CornerRadius = UDim.new(0, 8)

local function makeDot(x, color)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 7, 0, 7)
    d.Position = UDim2.new(0, x, 0.5, -3.5)
    d.BackgroundColor3 = color
    d.BorderSizePixel = 0
    d.ZIndex = 5
    d.Parent = termHeader
    Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
end
makeDot(10, Color3.fromRGB(255, 95, 86))
makeDot(22, Color3.fromRGB(255, 189, 46))
makeDot(34, Color3.fromRGB(39, 201, 63))

local termScroll = Instance.new("ScrollingFrame")
termScroll.Size = UDim2.new(1, -8, 1, -26)
termScroll.Position = UDim2.new(0, 4, 0, 22)
termScroll.BackgroundTransparency = 1
termScroll.BorderSizePixel = 0
termScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
termScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
termScroll.ScrollBarThickness = 3
termScroll.ScrollBarImageColor3 = C_BORDER
termScroll.ScrollingDirection = Enum.ScrollingDirection.Y
termScroll.ZIndex = 4
termScroll.Parent = term

local consoleLabel = Instance.new("TextLabel")
consoleLabel.Size = UDim2.new(1, -10, 0, 0)
consoleLabel.Position = UDim2.new(0, 6, 0, 2)
consoleLabel.BackgroundTransparency = 1
consoleLabel.Text = ""
consoleLabel.TextColor3 = C_GREEN
consoleLabel.Font = Enum.Font.Gotham
consoleLabel.TextSize = 10
consoleLabel.TextXAlignment = Enum.TextXAlignment.Left
consoleLabel.TextYAlignment = Enum.TextYAlignment.Top
consoleLabel.RichText = true
consoleLabel.TextWrapped = true
consoleLabel.AutomaticSize = Enum.AutomaticSize.Y
consoleLabel.ZIndex = 4
consoleLabel.Parent = termScroll

local LOG_ENTRIES = {}
local LOG_COLORS = { INFO="88CCFF", WAIT="FFD966", WARN="FFA84F", OK="80FF80", ERR="FF6B6B", SYS="A8C8FF" }
local function addLog(kind, text)
    local c = LOG_COLORS[kind] or "80FF80"
    table.insert(LOG_ENTRIES, string.format('<font color="#%s">[%s]</font> %s', c, kind, text))
    if #LOG_ENTRIES > 40 then table.remove(LOG_ENTRIES, 1) end
    consoleLabel.Text = table.concat(LOG_ENTRIES, "\n")
    task.delay(0.03, function()
        pcall(function()
            termScroll.CanvasPosition = Vector2.new(0, math.max(0, termScroll.AbsoluteCanvasSize.Y - termScroll.AbsoluteWindowSize.Y))
        end)
    end)
end
ORBIT.addLog = addLog

-- ============================================================
--       ПРОГРЕСС + КНОПКА
-- ============================================================
local progHolder = Instance.new("Frame")
progHolder.Size = UDim2.new(1, -32, 0, 28)
progHolder.Position = UDim2.new(0, 16, 0, 464)
progHolder.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
progHolder.BorderSizePixel = 0
progHolder.ZIndex = 3
progHolder.Parent = frame
Instance.new("UICorner", progHolder).CornerRadius = UDim.new(0, 8)
local progStroke = Instance.new("UIStroke", progHolder)
progStroke.Color = C_BORDER; progStroke.Thickness = 1; progStroke.Transparency = 0.4

local progFill = Instance.new("Frame")
progFill.Size = UDim2.new(0.111, 0, 1, 0)
progFill.BackgroundColor3 = C_GREEN
progFill.BorderSizePixel = 0
progFill.ZIndex = 4
progFill.Parent = progHolder
Instance.new("UICorner", progFill).CornerRadius = UDim.new(0, 8)

local fillGradient = Instance.new("UIGradient", progFill)
fillGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 180)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 255)),
})

local progText = Instance.new("TextLabel")
progText.Size = UDim2.new(1, 0, 1, 0)
progText.BackgroundTransparency = 1
progText.Text = "LOADING 11%  •  1/9 ЭТАПОВ"
progText.TextColor3 = Color3.fromRGB(20, 40, 28)
progText.Font = Enum.Font.GothamBold
progText.TextSize = 11
progText.ZIndex = 5
progText.Parent = progHolder

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -32, 0, 46)
startBtn.Position = UDim2.new(0, 16, 1, -76)
startBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 48)
startBtn.BackgroundTransparency = 0.1
startBtn.TextColor3 = C_DIM
startBtn.Font = Enum.Font.GothamBold
startBtn.TextSize = 14
startBtn.Text = "ЖДЁМ ЗАГРУЗКИ..."
startBtn.AutoButtonColor = false
startBtn.ZIndex = 3
startBtn.Parent = frame
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 12)
local stStroke = Instance.new("UIStroke", startBtn)
stStroke.Color = C_BORDER; stStroke.Thickness = 1.5; stStroke.Transparency = 0.4

local statusBar = Instance.new("TextLabel")
statusBar.Size = UDim2.new(1, -32, 0, 18)
statusBar.Position = UDim2.new(0, 16, 1, -26)
statusBar.BackgroundTransparency = 1
statusBar.Text = "> ORBITA INITIALIZED  |  READY"
statusBar.TextColor3 = C_GREEN
statusBar.Font = Enum.Font.Gotham
statusBar.TextSize = 10
statusBar.TextXAlignment = Enum.TextXAlignment.Left
statusBar.ZIndex = 3
statusBar.Parent = frame

-- ============================================================
--       ПОДСЧЁТ ПРОГРЕССА
-- ============================================================
local function countLoaded()
    local n = 1
    if ORBIT.loaded.p2 then n = n + 1 end
    if ORBIT.loaded.p3 then n = n + 1 end
    if ORBIT.loaded.p4 then n = n + 1 end
    if ORBIT.loaded.share then n = n + 1 end
    if ORBIT.loaded.ac then n = n + 1 end
    if ORBIT.loaded.sfx then n = n + 1 end
    if ORBIT.loaded.extras then n = n + 1 end
    if ORBIT.loaded.editor3d then n = n + 1 end
    if ORBIT.loaded.helper then n = n + 1 end
    return n
end

local function refreshStatus()
    local n = countLoaded()
    local total = 10
    local percent = n / total

    TweenService:Create(progFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.new(percent, 0, 1, 0) }):Play()
    progText.Text = string.format("LOADING %d%%  •  %d/%d ЭТАПОВ", math.floor(percent * 100 + 0.5), n, total)
    updateRingProgress(percent)
    refreshSteps()

    if n >= 4 then
        progText.TextColor3 = Color3.fromRGB(20, 40, 28)
        startBtn.Text = "ЗАПУСТИТЬ ОРБИТУ"
        startBtn.TextColor3 = C_GREEN
        stStroke.Color = C_GREEN
        stStroke.Transparency = 0.1
        statusBar.Text = "> ORBITA INITIALIZED  |  ALL MAIN PARTS LOADED  |  READY"
    end
end
ORBIT.refreshLoaderStatus = refreshStatus

-- ============================================================
--       ЗАГРУЗКА ЧАСТИ
-- ============================================================
-- v23.7: sub(1, 60) → sub(1, 300), чтобы видеть полный текст ошибки
local function fetchAndRun(file, attempts, tag)
    for attempt = 1, attempts do
        local url = BASE_URL .. file .. "?t=" .. os.time() .. "&a=" .. attempt
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src < 100 then
            addLog("WARN", tag .. ": попытка " .. attempt .. " (сеть)")
        elseif type(loadstring) ~= "function" then
            addLog("ERR", "loadstring недоступен в этом executor")
            return false
        else
            local fn, err = loadstring(src)
            if not fn then
                -- v23.7: показываем больше символов из сообщения компилятора
                addLog("ERR", tag .. " compile: " .. tostring(err):sub(1, 300))
            else
                local runOk, runErr = pcall(fn)
                if runOk then return true end
                -- v23.7: показываем больше символов из сообщения рантайма
                addLog("ERR", tag .. " runtime: " .. tostring(runErr):sub(1, 300))
            end
        end
        task.wait(0.4)
    end
    return false
end

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

    setCover(part.icon, "ЗАГРУЗКА: " .. part.sub, part.file .. " — скачивание...", part.color)
    startPulse()
    addLog("INFO", "Downloading " .. part.file .. "...")

    task.spawn(function()
        local success = fetchAndRun(part.file, 3, part.file)

        if not success then
            setPartStatus(part.num, "error")
            setCover("❌", "ОШИБКА: " .. part.sub, part.file .. " — не загрузился", C_RED)
            stopPulse()
            addLog("ERR", "Failed: " .. part.file)
            loading[part.num] = nil
            if onDone then onDone(false) end
            return
        end

        local verified = true
        if part.num == 2 and (not ORBIT.SHAPE_PRESETS or #ORBIT.SHAPE_PRESETS < 3) then verified = false end
        if part.num == 3 and not ORBIT.startUpdateLoop then verified = false end
        if part.num == 4 and not ORBIT.ui then verified = false end

        if not verified then
            ORBIT.loaded["p" .. part.num] = false
            setPartStatus(part.num, "error")
            addLog("WARN", "Часть загружена но поля пусты!")
            loading[part.num] = nil
            if onDone then onDone(false) end
            return
        end

        ORBIT.loaded["p" .. part.num] = true
        setPartStatus(part.num, "ok")
        stopPulse()
        addLog("OK", part.sub .. " — загружено")
        ORBIT.notify("✅ " .. part.sub .. " загружено", Color3.fromRGB(160, 255, 180), 2)
        refreshStatus()
        if onDone then onDone(true) end
    end)
end

-- ============================================================
--       ДОП. МОДУЛИ
-- ============================================================
local function loadExtra(name, file, key, onDone)
    if ORBIT.loaded[key] then
        if onDone then onDone(true) end
        return
    end
    task.spawn(function()
        addLog("INFO", "Downloading " .. file .. "...")
        if not fetchAndRun(file, 2, name) then
            addLog("WARN", name .. " не загрузился — продолжаю без него")
            if onDone then onDone(false) end
            return
        end
        ORBIT.loaded[key] = true
        addLog("OK", name .. " — загружено")
        refreshStatus()
        if onDone then onDone(true) end
    end)
end

-- ============================================================
--       ГЛАВНАЯ ЦЕПОЧКА ЗАГРУЗКИ
-- ============================================================
local function autoLoadAll()
    task.wait(0.3)

    loadPart(PARTS[1], function(ok1)
        if not ok1 then
            setCover("⚠️", "ЧАСТЬ 2 НЕ ЗАГРУЖЕНА", "проверь интернет", C_ORANGE)
            return
        end
        task.wait(0.3)
        loadPart(PARTS[2], function(ok2)
            if not ok2 then
                setCover("⚠️", "ЧАСТЬ 3 НЕ ЗАГРУЖЕНА", "проверь интернет", C_ORANGE)
                return
            end
            task.wait(0.3)
            loadPart(PARTS[3], function(ok3)
                if not ok3 then
                    setCover("⚠️", "ЧАСТЬ 4 НЕ ЗАГРУЖЕНА", "проверь интернет", C_ORANGE)
                    return
                end

                setCover("✅", "ОСНОВА ГОТОВА", "загружаю share, защиту, звуки, extras, 3D...", C_GREEN)

                setCover("🔗", "ЗАГРУЗКА: SHARE", "orbit_share.lua...", Color3.fromRGB(180, 220, 255))
                startPulse()
                loadExtra("🔗 Share", "orbit_share.lua", "share", function()
                    stopPulse()

                    setCover("🛡️", "ЗАГРУЗКА: ЗАЩИТА", "orbit_anticheat.lua...", Color3.fromRGB(255, 140, 140))
                    startPulse()
                    loadExtra("🛡️ Античит", "orbit_anticheat.lua", "ac", function()
                        stopPulse()

                        setCover("🎵", "ЗАГРУЗКА: ЗВУКИ", "orbit_sfx.lua...", Color3.fromRGB(255, 200, 255))
                        startPulse()
                        loadExtra("🎵 SFX", "orbit_sfx.lua", "sfx", function()
                            stopPulse()

                            setCover("✨", "ЗАГРУЗКА: EXTRAS", "атмосфера, шлейф, искры...", Color3.fromRGB(200, 220, 255))
                            startPulse()
                            loadExtra("✨ Extras", "orbit_extras.lua", "extras", function()
                                stopPulse()

                                setCover("🔮", "ЗАГРУЗКА: 3D-РЕДАКТОР", "orbit_editor3d.lua...", Color3.fromRGB(200, 150, 255))
                                startPulse()
                                loadExtra("🔮 3D-Редактор", "orbit_editor3d.lua", "editor3d", function()
                                    stopPulse()

                                    setCover("🤖", "ЗАГРУЗКА: ПОМОЩНИК", "orbit_helper.lua...", Color3.fromRGB(200, 220, 255))
                                    startPulse()
                                    loadExtra("🤖 Помощник", "orbit_helper.lua", "helper", function()
                                        stopPulse()
                                        task.wait(0.3)
                                        setCover("✅", "ВСЁ ГОТОВО", "нажми ЗАПУСТИТЬ ОРБИТУ", C_GREEN)
                                        updateRingProgress(1)
                                        refreshStatus()
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- ============================================================
--       СТАРТ
-- ============================================================
onTap(startBtn, function()
    if not (ORBIT.loaded.p2 and ORBIT.loaded.p3 and ORBIT.loaded.p4) then
        ORBIT.notify("Сначала загрузи все части", Color3.fromRGB(255, 200, 100), 3)
        return
    end
    if ORBIT.started then return end
    ORBIT.started = true
    startBtn.Text = "РАБОТАЕТ..."
    setCover("🚀", "ЗАПУСК ОРБИТЫ", "включаю все системы...", C_GREEN)
    addLog("OK", "Запуск ОРБИТЫ...")
    task.wait(0.3)
    backdrop.Visible = false
    frame.Visible = false
    pcall(function() ORBIT.start() end)
end)

-- ============================================================
--       ВЫБОР ПЛАТФОРМЫ
-- ============================================================
local platformChosen = false
local function selectPlatform(platform)
    if platformChosen then return end
    platformChosen = true
    ORBIT.PLATFORM = platform
    ORBIT.applyPlatformDefaults()

    TweenService:Create(platformScreen, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
    for _, ch in ipairs(platformScreen:GetChildren()) do
        if ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("Frame") then
            pcall(function()
                TweenService:Create(ch, TweenInfo.new(0.25), {
                    BackgroundTransparency = 1,
                    TextTransparency = ch:IsA("TextLabel") and 1 or nil,
                }):Play()
            end)
        end
    end
    task.wait(0.28)
    platformScreen.Visible = false
    frame.Visible = true
    frameScale.Scale = frameScaleTarget * 0.92
    TweenService:Create(frameScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = frameScaleTarget }):Play()

    platformBadge.Text = platform == "mobile" and "MOBILE" or "PC"

    addLog("SYS", "orbit_loader.lua — старт")
    addLog("INFO", "Платформа: " .. platform:upper())
    addLog("INFO", "Загрузка ОРБИТЫ " .. ORBIT.version)
    ORBIT.loadSavesList()
    local saveCount = 0
    for _ in pairs(ORBIT.SAVES) do saveCount = saveCount + 1 end
    addLog("OK", "Найдено сохранений: " .. saveCount)
    addLog("OK", "BlockCount: " .. ORBIT.SETTINGS.BlockCount)

    setCover("✨", "СТАРТ ЗАГРУЗКИ", "части 2 → 3 → 4 → share → защита → звуки → extras → 3D", C_GREEN)

    task.spawn(autoLoadAll)
end

onTap(mobileBtn, function() selectPlatform("mobile") end)
onTap(pcBtn, function() selectPlatform("pc") end)

ORBIT.notify("✨ ОРБИТА " .. ORBIT.version .. " — выбери платформу", Color3.fromRGB(200, 200, 255), 4)

return ORBIT
