-- ORBIT v24.0 | orbit_loader.lua
-- ЕДИНЫЙ файл: ядро + GUI + загрузчик 16 модулей (p2, p3, p4, p4b, shop, tools,
-- extras, abilities, sans, deathfx, gaster, newfigures, animations, editor3d,
-- minigame, anticheat). Счётчик считается от длины QUEUE, поэтому всегда 16.
-- BUILD: v24.0-r3 (защита от повторного запуска + диагностика)

local BUILD = "v24.0-r3"
local GENV = rawget(_G, "getgenv") and getgenv() or _G

-- ============================================================
--        ЗАЩИТА ОТ ПОВТОРНОГО ЗАПУСКА (самозапуск / дубли)
-- ============================================================
do
    local busy = GENV._OrbitLoaderBusy
    if busy and (os.clock() - (GENV._OrbitLoaderBusyStamp or 0)) < 60 then
        warn("[ORBIT LOADER " .. BUILD .. "] повторный вызов во время загрузки — проигнорирован")
        print(debug.traceback("[ORBIT LOADER] кто вызвал повторно:", 2))
        return rawget(shared, "ORBIT") or rawget(_G, "ORBIT")
    end
    GENV._OrbitLoaderBusy = true
    GENV._OrbitLoaderBusyStamp = os.clock()
end

local execName = "?"
pcall(function() if identifyexecutor then execName = tostring((identifyexecutor())) end end)
print(string.format("[ORBIT LOADER] build=%s executor=%s", BUILD, execName))

-- снести прошлый запуск
do
    local oldGui = GENV._OrbitLoaderGui
    if oldGui then pcall(function() oldGui:Destroy() end); GENV._OrbitLoaderGui = nil end
    local oldMain = GENV._OrbitMainGui
    if oldMain then pcall(function() oldMain:Destroy() end); GENV._OrbitMainGui = nil end
    local oldOrbit = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or GENV.ORBIT
    if oldOrbit and oldOrbit.unload then pcall(oldOrbit.unload) end
end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local LogService   = game:GetService("LogService")
local Stats        = game:GetService("Stats")
local Lighting     = game:GetService("Lighting")
local UIS          = game:GetService("UserInputService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
--              ПОИСК И УДАЛЕНИЕ СТАРЫХ GUI ОРБИТЫ
-- ============================================================
local function sweepOldGuis()
    local roots = {}
    local g = rawget(GENV, "gethui")
    if type(g) == "function" then
        local ok, h = pcall(g)
        if ok and h then roots[#roots + 1] = h end
    end
    pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
    roots[#roots + 1] = PlayerGui
    local killed = 0
    for _, root in ipairs(roots) do
        local okc, kids = pcall(function() return root:GetChildren() end)
        if okc then
            for _, gui in ipairs(kids) do
                if gui:IsA("ScreenGui") then
                    local nm = gui.Name
                    local kill = nm:find("^_OrbitLoader_") or nm:find("^_OrbitMain") or nm:find("^Orbit")
                    if not kill then
                        pcall(function()
                            for _, d in ipairs(gui:GetDescendants()) do
                                if d:IsA("TextLabel") and d.Text:find("/17", 1, true)
                                    and (d.Text:find("LOADING", 1, true) or d.Text:find("Загрузка", 1, true)) then
                                    kill = true; break
                                end
                            end
                        end)
                    end
                    if kill then
                        pcall(function() gui:Destroy() end)
                        killed = killed + 1
                    end
                end
            end
        end
    end
    return killed
end
local swept = sweepOldGuis()
if swept > 0 then warn("[ORBIT LOADER] удалено старых GUI: " .. swept) end

-- ============================================================
--                    ЯДРО
-- ============================================================
local ORBIT = {}
shared.ORBIT = ORBIT
rawset(_G, "ORBIT", ORBIT)
if GENV then GENV.ORBIT = ORBIT end

ORBIT.stub = true
ORBIT.version = "v24.0"
ORBIT.build = BUILD
ORBIT.started = false
ORBIT.PLATFORM = nil
ORBIT.enabled = true
ORBIT.mode = "sans"
ORBIT.RigType = "R15"
ORBIT.abilityMoveUntil = 0

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

ORBIT.loaded = {
    p2 = false, p3 = false, p4 = false, p4b = false,
    extras = false, tools = false, abilities = false, sans = false,
    deathfx = false, gaster = false, newfigures = false, animations = false,
    shop = false, editor3d = false, minigame = false, anticheat = false,
}

ORBIT.saveData = {
    gasterUnlocked = false, gasterWeaponUnlocked = false,
    playerMode = "sans", theme = "dark", achievements = {}, rigType = "R15",
}

do
    local okR, raw = pcall(function()
        if ORBIT.HAS_FS and isfile(ORBIT.SAVE_FILE) then return readfile(ORBIT.SAVE_FILE) end
    end)
    if okR and type(raw) == "string" and #raw > 2 then
        local okJ, d = pcall(function() return HttpService:JSONDecode(raw) end)
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

-- ============================================================
--              SAFE PARENT / PROTECT GUI
-- ============================================================
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
    if type(protectFn) == "function" then pcall(protectFn, gui); return end
end
ORBIT.getSafeParent = getSafeParent
ORBIT.protectGui = protectGui

-- ============================================================
--       АНТИСПАМ АНИМАЦИЙ
-- ============================================================
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
            if ORBIT.animErrorCount % 10 == 0 then pcall(function() LogService:ClearOutput() end) end
        end
    end)
end)

-- ============================================================
--                    НАСТРОЙКИ
-- ============================================================
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

-- ============================================================
--                    ПРЕСЕТЫ
-- ============================================================
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
-- ============================================================
--                    СОСТОЯНИЕ
-- ============================================================
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

-- ============================================================
--                    МУЗЫКА
-- ============================================================
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

-- ============================================================
--                    ЗВУКИ
-- ============================================================
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

-- ============================================================
--                    УВЕДОМЛЕНИЯ
-- ============================================================
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

-- ============================================================
--                    ХЕЛПЕРЫ
-- ============================================================
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
function ORBIT.getHeightOffset()
    return P.HEIGHT[P.heightIndex].offset
end
function ORBIT.getTargetHeight(ri)
    return P.ORBIT[P.orbitIndex].height + ORBIT.rings[ri].heightOffset * P.SPREAD[P.spreadIndex].mult + ORBIT.getHeightOffset()
end
function ORBIT.getTargetSpeed()
    return ORBIT.SETTINGS.OrbitSpeed * ORBIT.SETTINGS.SpeedMultiplier
end
function ORBIT.getTargetSpin()
    return ORBIT.SETTINGS.SpinSpeed * ORBIT.SETTINGS.SpeedMultiplier * ORBIT.SETTINGS.SpinSpeedMultiplier
end

-- ============================================================
--                    СОХРАНЕНИЯ
-- ============================================================
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

-- ============================================================
--                    UNLOAD
-- ============================================================
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
    if GENV._OrbitLoaderGui then pcall(function() GENV._OrbitLoaderGui:Destroy() end); GENV._OrbitLoaderGui = nil end
    if GENV._OrbitMainGui then pcall(function() GENV._OrbitMainGui:Destroy() end); GENV._OrbitMainGui = nil end
    GENV._OrbitLoaderBusy = nil
    shared.ORBIT = nil
    rawset(_G, "ORBIT", nil)
    if GENV then GENV.ORBIT = nil end
end

ORBIT.start = function()
    ORBIT.notify("Не все части загружены", Color3.fromRGB(255,200,100), 3)
end
ORBIT.addLog = function() end
ORBIT.refreshLoaderStatus = function() end
ORBIT.currentFile = nil

-- ============================================================
--                    ОЧЕРЕДЬ МОДУЛЕЙ (единый источник правды)
-- ============================================================
local QUEUE = {
    { file = "orbit_p2.lua",          key = "p2",         short = "P2",   tag = "🔷 Фигуры",       cover = "ФИГУРЫ",       icon = "🔷", color = Color3.fromRGB(120, 200, 255), critical = true },
    { file = "orbit_p3.lua",          key = "p3",         short = "P3",   tag = "⚙️ Логика",       cover = "ЛОГИКА",       icon = "⚙️", color = Color3.fromRGB(200, 220, 120), critical = true },
    { file = "orbit_p4.lua",          key = "p4",         short = "P4",   tag = "🎨 UI (каркас)", cover = "ИНТЕРФЕЙС",    icon = "🎨", color = Color3.fromRGB(220, 160, 255), critical = true },
    { file = "orbit_p4b.lua",         key = "p4b",        short = "P4b",  tag = "🎨 UI (логика)", cover = "UI-ЛОГИКА",    icon = "🎨", color = Color3.fromRGB(220, 160, 255), critical = true },
    { file = "orbit_p4_shop.lua",     key = "shop",       short = "SHOP", tag = "🛒 Магазин",     cover = "МАГАЗИН",      icon = "🛒", color = Color3.fromRGB(180, 130, 255) },
    { file = "orbit_tools.lua",       key = "tools",      short = "TOOLS",tag = "🧰 Tools",       cover = "TOOLS",        icon = "🧰", color = Color3.fromRGB(180, 255, 200) },
    { file = "orbit_extras.lua",      key = "extras",     short = "EXT",  tag = "🎵 Extras",      cover = "EXTRAS",       icon = "🎵", color = Color3.fromRGB(180, 220, 255) },
    { file = "orbit_abilities.lua",   key = "abilities",  short = "ABL",  tag = "✨ Способности", cover = "СПОСОБНОСТИ",  icon = "✨", color = Color3.fromRGB(255, 220, 140) },
    { file = "orbit_sans.lua",        key = "sans",       short = "SNS",  tag = "🎭 Санс",        cover = "САНС",         icon = "🎭", color = Color3.fromRGB(200, 220, 255) },
    { file = "orbit_death_fx.lua",    key = "deathfx",    short = "DFX",  tag = "💀 Смерть FX",   cover = "DEATH FX",     icon = "💀", color = Color3.fromRGB(255, 180, 180) },
    { file = "orbit_gaster.lua",      key = "gaster",     short = "GST",  tag = "👁 Гастер",      cover = "ГАСТЕР",       icon = "👁", color = Color3.fromRGB(200, 140, 255) },
    { file = "orbit_new_figures.lua", key = "newfigures", short = "NF",   tag = "🔷 Новые фигуры",cover = "НОВЫЕ ФИГУРЫ", icon = "🔷", color = Color3.fromRGB(150, 220, 255) },
    { file = "orbit_animations.lua",  key = "animations", short = "ANM",  tag = "🎬 Анимации",    cover = "АНИМАЦИИ",     icon = "🎬", color = Color3.fromRGB(255, 180, 220) },
    { file = "orbit_editor3d.lua",    key = "editor3d",   short = "3D",   tag = "🔮 Редактор 3D", cover = "РЕДАКТОР 3D",  icon = "🔮", color = Color3.fromRGB(200, 160, 255) },
    { file = "orbit_minigame.lua",    key = "minigame",   short = "MG",   tag = "🎮 Мини-игра",   cover = "МИНИ-ИГРА",    icon = "🎮", color = Color3.fromRGB(255, 200, 100) },
    { file = "orbit_anticheat.lua",   key = "anticheat",  short = "AC",   tag = "🛡 Античит",     cover = "АНТИЧИТ",      icon = "🛡", color = Color3.fromRGB(200, 255, 180) },
}
local TOTAL_LOADED = #QUEUE
for _, it in ipairs(QUEUE) do
    if ORBIT.loaded[it.key] == nil then ORBIT.loaded[it.key] = false end
end

-- ============================================================
--                    GUI ЗАГРУЗЧИКА
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
bgGlow.BackgroundColor3 = C_BORDER
bgGlow.BackgroundTransparency = 0.9
bgGlow.BorderSizePixel = 0
bgGlow.ZIndex = 1
bgGlow.Parent = loaderGui
local bgGlowGradient = Instance.new("UIGradient", bgGlow)
bgGlowGradient.Rotation = 90
bgGlowGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
})

-- ============================================================
--              ЭКРАН 1: ВЫБОР ПЛАТФОРМЫ
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

local function mkLabel(parent, text, size, pos, color, font, ts, z)
    local l = Instance.new("TextLabel")
    l.Size = size; l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = color
    l.Font = font; l.TextSize = ts; l.ZIndex = z
    l.Parent = parent
    return l
end

mkLabel(platformScreen, "ОРБИТА " .. ORBIT.version, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 124), C_GREEN, Enum.Font.GothamBold, 28, 11)
mkLabel(platformScreen, "ВЫБЕРИ СВОЮ ПЛАТФОРМУ", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 164), C_ORANGE, Enum.Font.GothamBold, 13, 11)
mkLabel(platformScreen, "интерфейс и настройки подстроятся автоматически", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 186), C_DIM, Enum.Font.Gotham, 10, 11)

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
    stroke.Color = accent; stroke.Thickness = 2; stroke.Transparency = 0.4
    mkLabel(btn, icon, UDim2.new(1, 0, 0, 48), UDim2.new(0, 0, 0, 12), accent, Enum.Font.GothamBold, 42, 12)
    mkLabel(btn, text, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 62), C_GREEN, Enum.Font.GothamBold, 16, 12)
    local descLbl = mkLabel(btn, "", UDim2.new(1, -12, 1, -90), UDim2.new(0, 6, 0, 90), C_DIM, Enum.Font.Gotham, 10, 12)
    return btn, stroke, descLbl
end

local mobileBtn, mobileStroke, mobileDesc = buildPlatformButton("ТЕЛЕФОН", "📱", 24, 222, 200, 220, C_CYAN)
mobileDesc.Text = "• Меньше фигур\n• Лёгкие эффекты\n• Крупные кнопки\n• Вертикальный UI"
local pcBtn, pcStroke, pcDesc = buildPlatformButton("КОМПЬЮТЕР", "💻", 236, 222, 200, 220, C_ORANGE)
pcDesc.Text = "• Больше фигур\n• Все эффекты\n• Полный UI\n• Широкие панели"

mkLabel(platformScreen, UIS.TouchEnabled and "Похоже, ты на телефоне" or "Похоже, ты на ПК",
    UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 456), C_DIM, Enum.Font.Gotham, 11, 11)
mkLabel(platformScreen, "build " .. BUILD .. "  |  " .. execName,
    UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 1, -24), C_DIM, Enum.Font.Code, 10, 11)

do
    local s = UIS.TouchEnabled and mobileStroke or pcStroke
    s.Color = C_GREEN; s.Transparency = 0.1
    TweenService:Create(s, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
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
        task.delay(0.3, function() deb = false end)
        fn()
    end
    btn.Activated:Connect(call)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then call() end
    end)
end

mobileBtn.MouseButton1Down:Connect(function() highlightPlatform(mobileBtn, mobileStroke, true, C_CYAN) end)
mobileBtn.MouseButton1Up:Connect(function() highlightPlatform(mobileBtn, mobileStroke, false, C_CYAN) end)
pcBtn.MouseButton1Down:Connect(function() highlightPlatform(pcBtn, pcStroke, true, C_ORANGE) end)
pcBtn.MouseButton1Up:Connect(function() highlightPlatform(pcBtn, pcStroke, false, C_ORANGE) end)

-- ============================================================
--              ЭКРАН 2: ЗАГРУЗКА
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
frameStroke.Color = C_BORDER; frameStroke.Thickness = 2; frameStroke.Transparency = 0.15

local topStrip = Instance.new("Frame")
topStrip.Size = UDim2.new(1, 0, 0, 4)
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

local title = mkLabel(frame, "ОРБИТА " .. ORBIT.version, UDim2.new(1, -180, 0, 26), UDim2.new(0, 16, 0, 12), C_GREEN, Enum.Font.GothamBold, 18, 3)
title.TextXAlignment = Enum.TextXAlignment.Left

local platformBadge = mkLabel(frame, "PLATFORM: —", UDim2.new(0, 150, 0, 22), UDim2.new(1, -166, 0, 14), C_ORANGE, Enum.Font.GothamBold, 11, 4)
platformBadge.BackgroundTransparency = 0
platformBadge.BackgroundColor3 = Color3.fromRGB(30, 22, 48)
Instance.new("UICorner", platformBadge).CornerRadius = UDim.new(0, 6)

local coverHolder = Instance.new("Frame")
coverHolder.Size = UDim2.new(1, -32, 0, 110)
coverHolder.Position = UDim2.new(0, 16, 0, 50)
coverHolder.BackgroundColor3 = Color3.fromRGB(18, 12, 30)
coverHolder.BorderSizePixel = 0
coverHolder.ZIndex = 3
coverHolder.Parent = frame
Instance.new("UICorner", coverHolder).CornerRadius = UDim.new(0, 12)
local coverStroke = Instance.new("UIStroke", coverHolder)
coverStroke.Color = C_BORDER; coverStroke.Thickness = 1.5; coverStroke.Transparency = 0.4

local ringSize = 84
local ringHolder = Instance.new("Frame")
ringHolder.Size = UDim2.new(0, ringSize, 0, ringSize)
ringHolder.Position = UDim2.new(0, 14, 0.5, -ringSize / 2)
ringHolder.BackgroundTransparency = 1
ringHolder.ZIndex = 4
ringHolder.Parent = coverHolder

local ringSegments = {}
local SEGMENTS = 32
for i = 1, SEGMENTS do
    local angle = (i - 1) / SEGMENTS * math.pi * 2 - math.pi / 2
    local r = (ringSize - 8) / 2
    local seg = Instance.new("Frame")
    seg.Size = UDim2.new(0, 6, 0, 6)
    seg.Position = UDim2.new(0, ringSize / 2 + math.cos(angle) * r - 3, 0, ringSize / 2 + math.sin(angle) * r - 3)
    seg.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
    seg.BorderSizePixel = 0
    seg.ZIndex = 4
    seg.Parent = ringHolder
    Instance.new("UICorner", seg).CornerRadius = UDim.new(1, 0)
    ringSegments[#ringSegments + 1] = seg
end

local coverIcon = mkLabel(ringHolder, "✨", UDim2.new(0, ringSize - 20, 0, ringSize - 20), UDim2.new(0, 10, 0, 10), C_GREEN, Enum.Font.GothamBold, 34, 5)

local function updateRingProgress(percent)
    local active = math.floor(percent * SEGMENTS + 0.5)
    for i, seg in ipairs(ringSegments) do
        seg.BackgroundColor3 = (i <= active) and C_GREEN or Color3.fromRGB(40, 30, 60)
    end
end

local coverTitle = mkLabel(coverHolder, "ГОТОВ К СТАРТУ", UDim2.new(1, -112, 0, 22), UDim2.new(0, 110, 0, 22), C_GREEN, Enum.Font.GothamBold, 15, 5)
coverTitle.TextXAlignment = Enum.TextXAlignment.Left
local coverSub = mkLabel(coverHolder, "Нажми на выбор платформы", UDim2.new(1, -112, 0, 16), UDim2.new(0, 110, 0, 46), C_DIM, Enum.Font.Gotham, 10, 5)
coverSub.TextXAlignment = Enum.TextXAlignment.Left

local coverSteps = Instance.new("Frame")
coverSteps.Size = UDim2.new(1, -112, 0, 22)
coverSteps.Position = UDim2.new(0, 110, 0, 70)
coverSteps.BackgroundColor3 = Color3.fromRGB(28, 20, 42)
coverSteps.BorderSizePixel = 0
coverSteps.ZIndex = 5
coverSteps.Parent = coverHolder
Instance.new("UICorner", coverSteps).CornerRadius = UDim.new(0, 6)

local stepLabels = {}
local stepW = 1 / TOTAL_LOADED
for i, it in ipairs(QUEUE) do
    local lbl = mkLabel(coverSteps, it.short, UDim2.new(stepW, -1, 1, 0), UDim2.new((i - 1) * stepW, 0, 0, 0),
        Color3.fromRGB(70, 55, 90), Enum.Font.Code, 8, 6)
    stepLabels[it.key] = lbl
end

local function setCover(icon, ttl, sub, color)
    coverIcon.Text = icon
    coverTitle.Text = ttl
    coverSub.Text = sub or ""
    local c = color or C_GREEN
    coverTitle.TextColor3 = c
    coverIcon.TextColor3 = c
    coverStroke.Color = c
end

local coverPulseTween = nil
local function stopPulse()
    if coverPulseTween then coverPulseTween:Cancel(); coverPulseTween = nil end
    coverIcon.TextSize = 34
end
local function startPulse()
    stopPulse()
    coverPulseTween = TweenService:Create(coverIcon,
        TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { TextSize = 44 })
    coverPulseTween:Play()
end

setCover("✨", "ГОТОВ К ЗАГРУЗКЕ", "p2 → p3 → p4 → p4b → остальные", C_GREEN)
updateRingProgress(0)

-- ============================================================
--                    ЛОГ
-- ============================================================
local term = Instance.new("Frame")
term.Size = UDim2.new(1, -32, 0, 220)
term.Position = UDim2.new(0, 16, 0, 168)
term.BackgroundColor3 = Color3.fromRGB(15, 10, 24)
term.BorderSizePixel = 0
term.ZIndex = 3
term.Parent = frame
Instance.new("UICorner", term).CornerRadius = UDim.new(0, 8)
local termStroke = Instance.new("UIStroke", term)
termStroke.Color = C_BORDER; termStroke.Thickness = 1; termStroke.Transparency = 0.5

local termHeader = Instance.new("Frame")
termHeader.Size = UDim2.new(1, 0, 0, 20)
termHeader.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
termHeader.BorderSizePixel = 0
termHeader.ZIndex = 4
termHeader.Parent = term
Instance.new("UICorner", termHeader).CornerRadius = UDim.new(0, 8)

for i, col in ipairs({ Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) }) do
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 7, 0, 7)
    d.Position = UDim2.new(0, 10 + (i - 1) * 12, 0.5, -3.5)
    d.BackgroundColor3 = col
    d.BorderSizePixel = 0
    d.ZIndex = 5
    d.Parent = termHeader
    Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
end

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
local LOG_COLORS = { INFO="88CCFF", WARN="FFA84F", OK="80FF80", ERR="FF6B6B", SYS="A8C8FF" }
local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
local function addLog(kind, text)
    local c = LOG_COLORS[kind] or "80FF80"
    table.insert(LOG_ENTRIES, string.format('<font color="#%s">[%s]</font> %s', c, kind, esc(text)))
    if #LOG_ENTRIES > 60 then table.remove(LOG_ENTRIES, 1) end
    consoleLabel.Text = table.concat(LOG_ENTRIES, "\n")
    task.delay(0.03, function()
        pcall(function()
            termScroll.CanvasPosition = Vector2.new(0, math.max(0, termScroll.AbsoluteCanvasSize.Y - termScroll.AbsoluteWindowSize.Y))
        end)
    end)
end
ORBIT.addLog = addLog

-- ============================================================
--              ПРОГРЕСС + КНОПКА СТАРТ
-- ============================================================
local progHolder = Instance.new("Frame")
progHolder.Size = UDim2.new(1, -32, 0, 28)
progHolder.Position = UDim2.new(0, 16, 0, 396)
progHolder.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
progHolder.BorderSizePixel = 0
progHolder.ZIndex = 3
progHolder.Parent = frame
Instance.new("UICorner", progHolder).CornerRadius = UDim.new(0, 8)
local progStroke = Instance.new("UIStroke", progHolder)
progStroke.Color = C_BORDER; progStroke.Thickness = 1; progStroke.Transparency = 0.4

local progFill = Instance.new("Frame")
progFill.Size = UDim2.new(0, 0, 1, 0)
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

local progText = mkLabel(progHolder, "ГОТОВ К СТАРТУ", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
    Color3.fromRGB(20, 40, 28), Enum.Font.GothamBold, 11, 5)

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, -32, 0, 46)
startBtn.Position = UDim2.new(0, 16, 1, -86)
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

local statusBar = mkLabel(frame, "> ORBITA " .. BUILD .. "  |  READY", UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 1, -26), C_GREEN, Enum.Font.Code, 10, 3)
statusBar.TextXAlignment = Enum.TextXAlignment.Left

local function refreshStatus()
    local n = 0
    for _, it in ipairs(QUEUE) do
        if ORBIT.loaded[it.key] then n = n + 1 end
    end
    local percent = n / TOTAL_LOADED
    TweenService:Create(progFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Size = UDim2.new(percent, 0, 1, 0) }):Play()
    local cur = ORBIT.currentFile and ("  •  " .. ORBIT.currentFile) or ""
    progText.Text = string.format("LOADING %d%%  •  %d/%d%s", math.floor(percent * 100 + 0.5), n, TOTAL_LOADED, cur)
    updateRingProgress(percent)
    for _, it in ipairs(QUEUE) do
        stepLabels[it.key].TextColor3 = ORBIT.loaded[it.key] and C_GREEN or Color3.fromRGB(70, 55, 90)
    end
    if ORBIT.loaded.p2 and ORBIT.loaded.p3 and ORBIT.loaded.p4 and ORBIT.loaded.p4b then
        startBtn.Text = "ЗАПУСТИТЬ ОРБИТУ"
        startBtn.TextColor3 = C_GREEN
        stStroke.Color = C_GREEN
        stStroke.Transparency = 0.1
        statusBar.Text = "> ORBITA " .. BUILD .. "  |  ALL MAIN PARTS LOADED  |  READY"
    end
end
ORBIT.refreshLoaderStatus = refreshStatus

-- ============================================================
--              ЗАГРУЗКА ФАЙЛА (с диагностикой)
-- ============================================================
local BASE = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local SUSPECT = { "orbit_p1", "Running UI", "/17" }

local function fetchAndRun(file, attempts, tag)
    for attempt = 1, attempts do
        ORBIT.currentFile = file
        pcall(function()
            statusBar.Text = "> ⬇ " .. file .. "  (попытка " .. attempt .. "/" .. attempts .. ")"
            statusBar.TextColor3 = C_GREEN
            refreshStatus()
        end)
        local url = BASE .. file .. "?t=" .. os.time() .. "&a=" .. attempt
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src < 100 then
            addLog("WARN", tag .. ": попытка " .. attempt .. " (сеть)")
        elseif type(loadstring) ~= "function" then
            addLog("ERR", "loadstring недоступен")
            return false
        else
            for _, pat in ipairs(SUSPECT) do
                if src:find(pat, 1, true) then
                    addLog("WARN", file .. " содержит «" .. pat .. "»")
                    warn("[ORBIT LOADER] " .. file .. " содержит подозрительную строку: " .. pat)
                end
            end
            print(string.format("[ORBIT LOADER] %s  %d байт  «%s»", file, #src, (src:match("^[^\r\n]*") or ""):sub(1, 60)))
            local firstLine = src:match("^[^\r\n]*") or ""
            if src:find("Главный загрузчик: стаб ORBIT", 1, true)
                or src:find("_OrbitV24Loader = true", 1, true)
                or firstLine:find("orbit_loader.lua", 1, true) then
                addLog("ERR", file .. " — внутри СТАРЫЙ ЛОАДЕР, пропущен")
                warn("[ORBIT LOADER] " .. url .. " содержит старый лоадер — не запускаю")
                ORBIT.currentFile = nil
                return false
            end
            local fn, err = loadstring(src, "=" .. file)
            if not fn then
                addLog("ERR", tag .. " compile: " .. tostring(err):sub(1, 200))
            else
                local runOk, runErr = pcall(fn)
                if runOk then
                    pcall(function() statusBar.Text = "> ✔ " .. file .. " — готово" end)
                    return true
                end
                addLog("ERR", tag .. " runtime: " .. tostring(runErr):sub(1, 200))
            end
        end
        pcall(function() statusBar.Text = "> ⚠ " .. file .. " — повтор..."; statusBar.TextColor3 = C_ORANGE end)
        task.wait(0.4)
    end
    ORBIT.currentFile = nil
    return false
end

local function loadOne(item)
    if ORBIT.loaded[item.key] then return true end
    setCover(item.icon, "ЗАГРУЗКА: " .. item.cover, item.file .. " — скачивание...", item.color)
    startPulse()
    addLog("INFO", "Downloading " .. item.file .. "...")
    local ok = fetchAndRun(item.file, 3, item.tag)
    if not ok then
        addLog("WARN", item.file .. ": пробую v24/" .. item.file)
        ok = fetchAndRun("v24/" .. item.file, 2, item.tag)
    end
    stopPulse()
    if ok then
        ORBIT.loaded[item.key] = true
        addLog("OK", item.tag .. " — загружено")
        refreshStatus()
        return true
    end
    addLog("ERR", "Failed: " .. item.file)
    if item.critical then
        setCover("❌", "ОШИБКА: " .. item.cover, item.file .. " не загрузился", C_RED)
    end
    return false
end

local function autoLoadAll()
    task.wait(0.3)
    for _, item in ipairs(QUEUE) do
        GENV._OrbitLoaderBusyStamp = os.clock()
        local ok = loadOne(item)
        if not ok and item.critical then
            GENV._OrbitLoaderBusy = nil
            return
        end
        task.wait(0.2)
    end
    task.wait(0.3)
    GENV._OrbitLoaderBusy = nil
    setCover("✅", "ВСЁ ГОТОВО", "нажми ЗАПУСТИТЬ ОРБИТУ", C_GREEN)
    updateRingProgress(1)
    refreshStatus()
end

-- ============================================================
--              КНОПКА СТАРТ
-- ============================================================
onTap(startBtn, function()
    if not (ORBIT.loaded.p2 and ORBIT.loaded.p3 and ORBIT.loaded.p4 and ORBIT.loaded.p4b) then
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
--              ВЫБОР ПЛАТФОРМЫ
-- ============================================================
local platformChosen = false
local function selectPlatform(platform)
    if platformChosen then return end
    platformChosen = true
    ORBIT.PLATFORM = platform
    ORBIT.applyPlatformDefaults()

    TweenService:Create(platformScreen, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
    for _, ch in ipairs(platformScreen:GetChildren()) do
        if ch:IsA("TextLabel") then
            pcall(function() TweenService:Create(ch, TweenInfo.new(0.25), { TextTransparency = 1 }):Play() end)
        elseif ch:IsA("TextButton") or ch:IsA("Frame") then
            pcall(function() TweenService:Create(ch, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play() end)
        end
    end
    task.wait(0.28)
    platformScreen.Visible = false
    frame.Visible = true
    frameScale.Scale = frameScaleTarget * 0.92
    TweenService:Create(frameScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = frameScaleTarget }):Play()

    platformBadge.Text = platform == "mobile" and "MOBILE" or "PC"

    addLog("SYS", "orbit_loader.lua " .. BUILD .. " — старт (" .. execName .. ")")
    addLog("INFO", "Платформа: " .. platform:upper())
    addLog("INFO", "Модулей в очереди: " .. TOTAL_LOADED)
    ORBIT.loadSavesList()
    local saveCount = 0
    for _ in pairs(ORBIT.SAVES) do saveCount = saveCount + 1 end
    addLog("OK", "Найдено сохранений: " .. saveCount)
    addLog("OK", "BlockCount: " .. ORBIT.SETTINGS.BlockCount)

    setCover("✨", "СТАРТ ЗАГРУЗКИ", "p2 → p3 → p4 → p4b → остальные", C_GREEN)
    task.spawn(autoLoadAll)
end

onTap(mobileBtn, function() selectPlatform("mobile") end)
onTap(pcBtn, function() selectPlatform("pc") end)

task.delay(60, function()
    if not platformChosen then GENV._OrbitLoaderBusy = nil end
end)

ORBIT.notify("✨ ОРБИТА " .. ORBIT.version .. " — выбери платформу", Color3.fromRGB(200, 200, 255), 4)

return ORBIT
