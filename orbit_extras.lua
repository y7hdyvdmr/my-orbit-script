-- ORBIT v24.0 | orbit_extras.lua
-- Атмосфера (7 типов) + шлейф + реактивные искры + SFX (звуки/эмоции).
-- v24: SFX встроен сюда; новые звуки fire/hit/combo/cd/empty/slowmo;
--      R6/R15 проверка рига в Sfx.emote для dance/laugh/greet;
--      ORBIT.extras.getColorByName; ORBIT.loaded.extras.
-- Мини-игра «Ловля звёзд» живёт в orbit_minigame.lua (шаг 13 загрузчика).
-- Идентификаторы — латиница, комментарии — русский.
local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Extras] ORBIT не найден!"); return end

-- ============================================================
--       SFX (v24: встроен в extras; ранее orbit_sfx.lua)
-- ============================================================
do
local SoundService    = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris          = game:GetService("Debris")
if type(ORBIT.SOUNDS) ~= "table" then ORBIT.SOUNDS = { Enabled = true, Volume = 1 } end
if ORBIT.SOUNDS.Enabled == nil then ORBIT.SOUNDS.Enabled = true end
if ORBIT.SOUNDS.Volume == nil then ORBIT.SOUNDS.Volume = 1 end
local Sfx = {}

-- ============================================================
--              ВСЕ ЗВУКИ
-- ============================================================
local IDS = {
    click       = "rbxasset://sounds/button.wav",
    switch      = "rbxasset://sounds/switch.wav",
    ping        = "rbxasset://sounds/electronicpingshort.wav",
    snap        = "rbxasset://sounds/snap.mp3",
    dodge       = "rbxassetid://140721035016341",
    afterDodge  = "rbxassetid://6325779988",
    sans        = "rbxassetid://135692693675195",
    laugh       = "rbxassetid://113650760423588",
    botCollect  = "rbxassetid://12221967",
    fire        = "rbxasset://sounds/snap.mp3",
    hit         = "rbxasset://sounds/electronicpingshort.wav",
    combo       = "rbxasset://sounds/switch.wav",
    cd          = "rbxasset://sounds/electronicpingshort.wav",
    empty       = "rbxasset://sounds/button.wav",
    slowmo      = "rbxasset://sounds/snap.mp3",
}

if ORBIT.sfxFolder and ORBIT.sfxFolder.Parent then pcall(function() ORBIT.sfxFolder:Destroy() end) end
local folder = Instance.new("Folder")
folder.Name = "OrbitSfx_" .. tostring(math.random(100000, 999999))
folder.Parent = SoundService
ORBIT.sfxFolder = folder

local templates = {}
for name, id in pairs(IDS) do
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = id
    s.Volume = 0.5
    s.Parent = folder
    templates[name] = s
end

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync(folder:GetChildren()) end)
end)

-- ============================================================
--              АНТИСПАМ И ВОСПРОИЗВЕДЕНИЕ
-- ============================================================
local lastPlay = {}

local function settings()
    local s = ORBIT.SOUNDS
    local enabled = true
    local volume = 1
    if type(s) == "table" then
        if s.Enabled == false then enabled = false end
        volume = tonumber(s.Volume) or 1
    end
    return enabled, volume
end

local function sfxPlayRaw(name, vol, pitch)
    local tpl = templates[name]
    if not tpl then return end
    local enabled, master = settings()
    if not enabled or master <= 0 then return end
    local now = os.clock()
    if lastPlay[name] and now - lastPlay[name] < 0.04 then return end
    lastPlay[name] = now
    local s = tpl:Clone()
    s.Volume = tpl.Volume * (vol or 1) * master
    s.PlaybackSpeed = pitch or 1
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 6)
end
function Sfx.play(name, vol, pitch)
    pcall(sfxPlayRaw, name, vol, pitch)
end

-- ============================================================
--              R6/R15 — вспомогательные
-- ============================================================
local function rigOfLocal()
    if ORBIT.RigType == "R6" or ORBIT.RigType == "R15" then return ORBIT.RigType end
    local c = ORBIT.LocalPlayer and ORBIT.LocalPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if h then
        local rig = (h.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
        ORBIT.RigType = rig
        return rig
    end
    return "R15"
end
local function isR15Local() return rigOfLocal() == "R15" end
task.spawn(function()
    local LP = ORBIT.LocalPlayer
    if not LP then return end
    if LP.Character then rigOfLocal() end
    LP.CharacterAdded:Connect(function()
        task.wait(0.5)
        rigOfLocal()
    end)
end)

-- ============================================================
--              ЭМОЦИЯ LAUGH (безопасная)
-- ============================================================
local function playLaughEmote()
    pcall(function()
        local char = ORBIT.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local ok = pcall(function() hum:PlayEmote("Laugh") end)
        if not ok then return end
        task.delay(2, function()
            pcall(function()
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then return end
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local name = track.Animation and track.Animation.Name or ""
                    if name:lower():find("laugh") or name:lower():find("emote") then
                        track:Stop(0)
                    end
                end
            end)
        end)
    end)
end

-- ============================================================
--              ЭМОЦИИ
-- ============================================================
local voiceUntil = 0
local emoteCooldown = {}

local SANS_PHRASES = {
    "ну и денёк...", "птички поют, цветочки цветут...", "ты выбрал не тот день.",
    "у тебя плохое предчувствие?", "а я тут просто стою.",
}

local function voiceFree()
    return os.clock() >= voiceUntil
end
local function takeVoice(sec)
    voiceUntil = os.clock() + (sec or 1.5)
end

local function playRobloxEmote(emoteName, stopAfter)
    local okAll = false
    pcall(function()
        local char = ORBIT.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        okAll = pcall(function() hum:PlayEmote(emoteName) end)
        task.delay(stopAfter or 2.5, function()
            pcall(function()
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then return end
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local nm = (track.Animation and track.Animation.Name or ""):lower()
                    if nm:find("laugh") or nm:find("emote") or nm:find("dance") or nm:find("wave")
                       or nm:find("cheer") or nm:find("point") then
                        track:Stop(0.2)
                    end
                end
            end)
        end)
    end)
    return okAll
end

local function sayBubble(text, sec)
    pcall(function()
        local char = ORBIT.LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head then return end
        local old = head:FindFirstChild("_OrbitSay")
        if old then old:Destroy() end
        local g = Instance.new("BillboardGui")
        g.Name = "_OrbitSay"; g.Size = UDim2.new(0, 220, 0, 40); g.StudsOffset = Vector3.new(0, 3, 0)
        g.AlwaysOnTop = true; g.Adornee = head; g.Parent = head
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 1, 0); l.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        l.BackgroundTransparency = 0.2; l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.Font = Enum.Font.Code; l.TextScaled = true; l.Text = text; l.Parent = g
        Instance.new("UICorner", l).CornerRadius = UDim.new(0, 8)
        Debris:AddItem(g, sec or 2.5)
    end)
end

-- name: "sans" | "laugh" | "dance" | "greet" | "dodge"
function Sfx.emote(name)
    local now = os.clock()
    local cd = emoteCooldown[name] or 0
    if now < cd then return false end
    emoteCooldown[name] = now + 1.2

    if name == "sans" then
        if not voiceFree() then return false end
        takeVoice(1.8)
        Sfx.play("sans", 1, 1)
        if ORBIT.mode ~= "normal" then
            sayBubble(SANS_PHRASES[math.random(1, #SANS_PHRASES)], 3)
        end
        return true
    elseif name == "laugh" then
        if not voiceFree() then return false end
        takeVoice(1.8)
        local ok = playRobloxEmote("Laugh", 2)
        if not ok then pcall(function()
            local hum = ORBIT.LocalPlayer.Character and ORBIT.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:PlayEmote("cheer") end
        end) end
        Sfx.play("laugh", 0.8, 1)
        return true
    elseif name == "dance" then
        local dances = isR15Local() and { "dance", "dance2", "dance3" } or { "dance" }
        playRobloxEmote(dances[math.random(1, #dances)], 6)
        return true
    elseif name == "greet" then
        playRobloxEmote("wave", 2.5)
        if ORBIT.mode ~= "normal" then sayBubble("привет!", 2) end
        return true
    elseif name == "dodge" then
        Sfx.play("dodge", 1, 1)
        task.delay(0.45, function()
            if math.random() < 0.5 then Sfx.emote("sans") else Sfx.emote("laugh") end
        end)
        return true
    end
    return false
end

-- ============================================================
--              ПОДМЕНА ФУНКЦИЙ В ORBIT
-- ============================================================
if not ORBIT._sfxPatched then
    ORBIT._origPlayClick      = ORBIT.playClick
    ORBIT._origPlayDodge      = ORBIT.playDodge
    ORBIT._origPlayBotCollect = ORBIT.playBotCollect
    ORBIT._origPlayWin        = ORBIT.playWin
    ORBIT._origPlayBuy        = ORBIT.playBuy
    ORBIT._sfxPatched = true
end

ORBIT.playClick = function()
    Sfx.play("click", 1, 1)
end
ORBIT.playBotCollect = function()
    Sfx.play("botCollect", 1, 1.2)
end
ORBIT.playDodge = function()
    Sfx.emote("dodge")
end
ORBIT.emote = function(name) return Sfx.emote(name) end
ORBIT.playWin = function()
    Sfx.play("ping", 1, 1.6)
end
ORBIT.playBuy = function()
    Sfx.play("switch", 1, 1.3)
end
ORBIT.playSwitch = function()
    Sfx.play("switch", 1, 1)
end
ORBIT.playProtect = function()
    Sfx.play("snap", 1, 0.9)
end

ORBIT.Sfx = Sfx

do
    local prevUnload = ORBIT.unload
    ORBIT.unload = function()
        pcall(function() folder:Destroy() end)
        if ORBIT._sfxPatched then
            ORBIT.playClick = ORBIT._origPlayClick or ORBIT.playClick
            ORBIT.playDodge = ORBIT._origPlayDodge or ORBIT.playDodge
            ORBIT.playBotCollect = ORBIT._origPlayBotCollect or ORBIT.playBotCollect
            ORBIT.playWin = ORBIT._origPlayWin or ORBIT.playWin
            ORBIT.playBuy = ORBIT._origPlayBuy or ORBIT.playBuy
            ORBIT._sfxPatched = nil
        end
        if prevUnload then pcall(prevUnload) end
    end
end
end -- SFX

-- ============================================================
--       ЖДЁМ UI (если p4 ещё не готов)
-- ============================================================
local waitT = 0
while (not ORBIT.ui or not ORBIT.ui.panel) and waitT < 20 do
    task.wait(0.3)
    waitT = waitT + 0.3
end
if not ORBIT.ui or not ORBIT.ui.panel then
    warn("[Orbit Extras] UI не готов после 20 сек!")
    return
end

local Players     = ORBIT.Players
local RunService  = ORBIT.RunService
local Workspace   = ORBIT.Workspace
local TweenService = ORBIT.TweenService
local LocalPlayer = ORBIT.LocalPlayer

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local panel    = ORBIT.ui.panel
local IS_MOBILE = (ORBIT.PLATFORM == "mobile")
local UI = ORBIT.ui
local onClick = UI.onClick or function(btn, fn) btn.Activated:Connect(fn) end

-- ============================================================
--       ДЕФОЛТНЫЕ НАСТРОЙКИ
-- ============================================================
SETTINGS.AtmoEnabled        = SETTINGS.AtmoEnabled or false
SETTINGS.AtmoType           = SETTINGS.AtmoType or "Снег"
SETTINGS.AtmoIntensity      = SETTINGS.AtmoIntensity or "Средняя"
SETTINGS.AtmoSize           = SETTINGS.AtmoSize or "Средний"
SETTINGS.AtmoColorMode      = SETTINGS.AtmoColorMode or "Авто"
SETTINGS.AtmoColorIndex     = SETTINGS.AtmoColorIndex or 1
SETTINGS.TrailStreamEnabled = SETTINGS.TrailStreamEnabled or false
SETTINGS.TrailStreamColorMode = SETTINGS.TrailStreamColorMode or "Радуга"
SETTINGS.TrailStreamColorIndex = SETTINGS.TrailStreamColorIndex or 1
SETTINGS.ReactSparksEnabled = SETTINGS.ReactSparksEnabled or false
SETTINGS.ReactSparksColorIndex = SETTINGS.ReactSparksColorIndex or 1

-- ============================================================
--       СПИСОК ЦВЕТОВ
-- ============================================================
local COLORS_LIST = P and P.COLORS or {
    {name="РАДУГА",rainbow=true},
    {name="КРАСНЫЙ",c=Color3.fromRGB(255,50,50)},
}
local function getColorByIndex(i)
    if not COLORS_LIST or #COLORS_LIST == 0 then return Color3.fromRGB(255,255,255) end
    local c = COLORS_LIST[((i - 1) % #COLORS_LIST) + 1]
    if c.rainbow then return Color3.fromHSV((tick() * 0.2) % 1, 0.9, 1) end
    return c.c or Color3.fromRGB(255,255,255)
end
local function getColorByName(name)
    for i, c in ipairs(COLORS_LIST or {}) do
        if c.name == name then return getColorByIndex(i) end
    end
    return Color3.fromRGB(255,255,255)
end
local function getColorNameByIndex(i)
    if not COLORS_LIST or #COLORS_LIST == 0 then return "?" end
    return COLORS_LIST[((i - 1) % #COLORS_LIST) + 1].name or "?"
end

-- ============================================================
--       ТИПЫ АТМОСФЕРЫ
-- ============================================================
local ATMO_TYPES = {
    { name="Снег", icon="❄️", texture="rbxasset://textures/particles/sparkles_main.dds",
      colors={Color3.fromRGB(230,245,255), Color3.fromRGB(200,230,255)},
      speed={-3,-1}, spread=Vector2.new(30,30), rotSpeed={-20,20}, gravity=0.15 },
    { name="Дождь", icon="🌧️", texture="rbxasset://textures/particles/sparkles_main.dds",
      colors={Color3.fromRGB(140,180,255), Color3.fromRGB(100,150,220)},
      speed={-20,-10}, spread=Vector2.new(8,8), rotSpeed={0,0}, gravity=0.5 },
    { name="Лепестки", icon="🌸", texture="rbxasset://textures/particles/sparkles_main.dds",
      colors={Color3.fromRGB(255,180,220), Color3.fromRGB(255,140,200)},
      speed={-2,-0.5}, spread=Vector2.new(180,180), rotSpeed={-60,60}, gravity=0.1 },
    { name="Искры", icon="✨", texture="rbxasset://textures/particles/sparkles_main.dds",
      colors={Color3.fromRGB(255,220,80), Color3.fromRGB(255,180,40)},
      speed={3,6}, spread=Vector2.new(180,180), rotSpeed={-180,180}, gravity=-0.05 },
    { name="Звёзды", icon="⭐", texture="rbxasset://textures/particles/sparkles_main.dds",
      colors={Color3.fromRGB(255,255,220), Color3.fromRGB(220,230,255)},
      speed={0.5,2}, spread=Vector2.new(180,180), rotSpeed={0,0}, gravity=-0.02 },
    { name="Пузыри", icon="💧", texture="rbxasset://textures/particles/sparkles_main.dds",
      colors={Color3.fromRGB(140,200,255), Color3.fromRGB(80,160,240)},
      speed={2,5}, spread=Vector2.new(30,30), rotSpeed={0,0}, gravity=-0.1 },
    { name="Пепел", icon="🔥", texture="rbxasset://textures/particles/sparkles_main.dds",
      colors={Color3.fromRGB(255,100,40), Color3.fromRGB(200,60,20)},
      speed={-2,-0.5}, spread=Vector2.new(180,180), rotSpeed={-30,30}, gravity=0.1 },
}
local atmoTypeIndex = 1
for i, t in ipairs(ATMO_TYPES) do
    if t.name == SETTINGS.AtmoType then atmoTypeIndex = i; break end
end

local ATMO_INTENSITY = {
    { name="Очень слабая", rate=20 },
    { name="Слабая", rate=50 },
    { name="Средняя", rate=90 },
    { name="Сильная", rate=150 },
    { name="Очень сильная", rate=250 },
}
local atmoIntensityIndex = 3
for i, t in ipairs(ATMO_INTENSITY) do
    if t.name == SETTINGS.AtmoIntensity then atmoIntensityIndex = i; break end
end

local ATMO_SIZE = {
    { name="Крошка", min=0.15, max=0.3 },
    { name="Мелкий", min=0.25, max=0.5 },
    { name="Средний", min=0.4, max=0.8 },
    { name="Крупный", min=0.7, max=1.3 },
    { name="Огромный", min=1.2, max=2.0 },
}
local atmoSizeIndex = 3
for i, t in ipairs(ATMO_SIZE) do
    if t.name == SETTINGS.AtmoSize then atmoSizeIndex = i; break end
end

local TRAIL_STREAM_COLOR_MODES = { "Радуга", "Из списка 50", "Как у колец" }
local trailStreamColorIndex = 1
for i, m in ipairs(TRAIL_STREAM_COLOR_MODES) do
    if m == SETTINGS.TrailStreamColorMode then trailStreamColorIndex = i; break end
end

local ATMO_COLOR_MODES = {"Авто", "Из списка 50"}
local atmoColorModeIndex = 1
for i, m in ipairs(ATMO_COLOR_MODES) do
    if m == SETTINGS.AtmoColorMode then atmoColorModeIndex = i; break end
end

-- ============================================================
--       СОСТОЯНИЕ
-- ============================================================
local atmoFolder = nil
local atmoEmitter = nil
local atmoConn = nil
local atmoSeed = 0

local trailStreamFolder = nil
local trailStreamPart = nil
local trailStreamTrail = nil

local reactSparksFolder = nil
local reactSparksConn = nil
local reactLastJump = 0
local reactLastRun = 0
local reactLastHealth = 100

-- ============================================================
--       АТМОСФЕРА
-- ============================================================
local function buildAtmoEmitter()
    if atmoFolder then atmoFolder:Destroy(); atmoFolder = nil end
    atmoEmitter = nil
    if not SETTINGS.AtmoEnabled then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    atmoFolder = Instance.new("Folder")
    atmoFolder.Name = "OrbitAtmo_" .. tostring(math.random(1, 999999))
    atmoFolder.Parent = Workspace

    local emitterPart = Instance.new("Part")
    emitterPart.Name = "AtmoEmitter"
    emitterPart.Size = Vector3.new(0.1, 0.1, 0.1)
    emitterPart.Transparency = 1
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.CastShadow = false
    emitterPart.CanQuery = false
    emitterPart.CanTouch = false
    emitterPart.CFrame = hrp.CFrame
    emitterPart.Parent = atmoFolder
    atmoEmitter = emitterPart

    local cfg = ATMO_TYPES[atmoTypeIndex]
    local int = ATMO_INTENSITY[atmoIntensityIndex]
    local size = ATMO_SIZE[atmoSizeIndex]

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = cfg.texture
    pe.Rate = int.rate
    pe.Lifetime = NumberRange.new(2.5, 4.5)
    pe.Speed = NumberRange.new(cfg.speed[1], cfg.speed[2])
    pe.SpreadAngle = cfg.spread
    pe.RotSpeed = NumberRange.new(cfg.rotSpeed[1], cfg.rotSpeed[2])
    pe.Rotation = NumberRange.new(0, 360)
    pe.Acceleration = Vector3.new(0, -cfg.gravity * 20, 0)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size.min),
        NumberSequenceKeypoint.new(0.5, (size.min + size.max) / 2),
        NumberSequenceKeypoint.new(1, size.max),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.7, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.LightEmission = 0.5
    pe.LightInfluence = 0

    if SETTINGS.AtmoColorMode == "Авто" then
        local c1 = cfg.colors[1]
        local c2 = cfg.colors[2]
        pe.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c1),
            ColorSequenceKeypoint.new(0.5, c2),
            ColorSequenceKeypoint.new(1, c1),
        })
    else
        pe.Color = ColorSequence.new(getColorByIndex(SETTINGS.AtmoColorIndex))
    end
    pe.Parent = emitterPart
end

local function updateAtmo()
    if not atmoEmitter or not atmoEmitter.Parent then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    atmoSeed = atmoSeed + 1
    local offset = Vector3.new(
        math.sin(atmoSeed * 0.7) * 8,
        12 + math.sin(atmoSeed * 0.3) * 4,
        math.cos(atmoSeed * 0.5) * 8
    )
    atmoEmitter.CFrame = CFrame.new(hrp.Position + offset)

    if SETTINGS.AtmoColorMode ~= "Авто" then
        local pe = atmoEmitter:FindFirstChildOfClass("ParticleEmitter")
        if pe then
            pe.Color = ColorSequence.new(getColorByIndex(SETTINGS.AtmoColorIndex))
        end
    end
end

local function setupAtmo()
    buildAtmoEmitter()
    if atmoConn then atmoConn:Disconnect(); atmoConn = nil end
    if SETTINGS.AtmoEnabled then
        atmoConn = RunService.Heartbeat:Connect(updateAtmo)
    end
end
-- ============================================================
--       ТРЕЙЛ-ШЛЕЙФ
-- ============================================================
local function buildTrailStream()
    if trailStreamFolder then trailStreamFolder:Destroy(); trailStreamFolder = nil end
    trailStreamPart = nil; trailStreamTrail = nil
    if not SETTINGS.TrailStreamEnabled then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    trailStreamFolder = Instance.new("Folder")
    trailStreamFolder.Name = "OrbitTrailStream_" .. tostring(math.random(1, 999999))
    trailStreamFolder.Parent = Workspace

    local p = Instance.new("Part")
    p.Name = "TrailAnchor"
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.CanQuery = false
    p.CanTouch = false
    p.CFrame = hrp.CFrame
    p.Parent = trailStreamFolder
    trailStreamPart = p

    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, -1.2, 0); a0.Parent = p
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 1.2, 0); a1.Parent = p

    trailStreamTrail = Instance.new("Trail")
    trailStreamTrail.Attachment0 = a0
    trailStreamTrail.Attachment1 = a1
    trailStreamTrail.Lifetime = SETTINGS.TrailLength or 0.5
    trailStreamTrail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, SETTINGS.TrailWidth or 0.8),
        NumberSequenceKeypoint.new(0.7, (SETTINGS.TrailWidth or 0.8) * 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    trailStreamTrail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    trailStreamTrail.FaceCamera = true
    trailStreamTrail.LightEmission = 1
    trailStreamTrail.Parent = p

    local mode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
    local col
    if mode == "Радуга" then
        col = Color3.fromHSV((tick() * 0.2) % 1, 0.9, 1)
    elseif mode == "Из списка 50" then
        col = getColorByIndex(SETTINGS.TrailStreamColorIndex)
    else
        col = SETTINGS.FixedColor or Color3.fromRGB(0, 180, 255)
    end
    trailStreamTrail.Color = ColorSequence.new(col)
end

local trailStreamConn = nil
local function setupTrailStream()
    buildTrailStream()
    if trailStreamConn then trailStreamConn:Disconnect(); trailStreamConn = nil end
    if not SETTINGS.TrailStreamEnabled then return end

    trailStreamConn = RunService.Heartbeat:Connect(function(dt)
        if not trailStreamPart or not trailStreamPart.Parent then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        trailStreamPart.CFrame = hrp.CFrame
        local mode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
        if trailStreamTrail then
            if mode == "Радуга" then
                trailStreamTrail.Color = ColorSequence.new(Color3.fromHSV((tick() * 0.2) % 1, 0.9, 1))
            elseif mode == "Из списка 50" then
                trailStreamTrail.Color = ColorSequence.new(getColorByIndex(SETTINGS.TrailStreamColorIndex))
            elseif mode == "Как у колец" then
                local p = P.COLORS[P.colorIndex]
                if p and not p.rainbow then
                    trailStreamTrail.Color = ColorSequence.new(p.c)
                else
                    trailStreamTrail.Color = ColorSequence.new(Color3.fromHSV((tick() * (SETTINGS.RainbowSpeed or 0.15)) % 1, 0.9, 1))
                end
            end
        end
    end)
end

-- ============================================================
--       РЕАКТИВНЫЕ ИСКРЫ
-- ============================================================
local function reactBurst(position, color3, count, spread)
    if not reactSparksFolder then
        reactSparksFolder = Instance.new("Folder")
        reactSparksFolder.Name = "OrbitReactSparks"
        reactSparksFolder.Parent = Workspace
    end
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.1, 0.1, 0.1)
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CFrame = CFrame.new(position)
    p.Parent = reactSparksFolder

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Rate = 0
    pe.Lifetime = NumberRange.new(0.4, 0.9)
    pe.Speed = NumberRange.new(8, 16)
    pe.SpreadAngle = spread or Vector2.new(180, 180)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    pe.Color = ColorSequence.new(color3 or Color3.fromRGB(255, 220, 100))
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    pe.LightEmission = 1
    pe.LightInfluence = 0
    pe.Parent = p
    pe:Emit(count or 20)
    task.delay(1.5, function() pcall(function() p:Destroy() end) end)
end

local function setupReactSparks()
    if reactSparksConn then reactSparksConn:Disconnect(); reactSparksConn = nil end
    if not SETTINGS.ReactSparksEnabled then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    reactLastHealth = hum and hum.Health or 100

    reactSparksConn = RunService.Heartbeat:Connect(function(dt)
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        local now = tick()
        local sparkColor = getColorByIndex(SETTINGS.ReactSparksColorIndex)

        local vy = hrp.AssemblyLinearVelocity.Y
        if vy > 25 and (now - reactLastJump) > 1.2 then
            reactLastJump = now
            reactBurst(hrp.Position - Vector3.new(0, 2.5, 0), sparkColor, 18, Vector2.new(180, 180))
        end

        local speedXZ = math.sqrt(hrp.AssemblyLinearVelocity.X^2 + hrp.AssemblyLinearVelocity.Z^2)
        if speedXZ > 12 and (now - reactLastRun) > 0.35 then
            reactLastRun = now
            reactBurst(hrp.Position - Vector3.new(0, 2.7, 0), sparkColor, 6, Vector2.new(40, 40))
        end

        if hum.Health < reactLastHealth - 5 then
            reactBurst(hrp.Position, Color3.fromRGB(255, 60, 80), 30, Vector2.new(180, 180))
        end
        reactLastHealth = hum.Health
    end)
end

-- ============================================================
--       UI
-- ============================================================
local finalY = panel.CanvasSize.Y.Offset + 12
local BTN_H = IS_MOBILE and 34 or 30

local function oldMakeBigSection(text, y, color)
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

local function oldMakeButton(text, y, h, bgColor, textColor)
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

local function makeBigSection(text, y, color)
    if UI.addSection then return UI.addSection(text, color, "fx") end
    return oldMakeBigSection(text, y, color)
end
local function makeButton(text, y, h, bgColor, textColor)
    if UI.makeButton then
        local hh = h
        if h == BTN_H then hh = nil end
        return UI.makeButton(text, hh, bgColor, textColor)
    end
    return oldMakeButton(text, y, h, bgColor, textColor)
end

-- ====== АТМОСФЕРА ======
makeBigSection("❄️  АТМОСФЕРА (вокруг тебя)", finalY, Color3.fromRGB(70, 100, 140))
finalY = finalY + 30

local atmoToggle = makeButton("", finalY, BTN_H + 4)
finalY = finalY + BTN_H + 8
local atmoTypeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local atmoIntBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local atmoSizeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local atmoColorModeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 4
local atmoColorBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 10

local function refreshAtmoUI()
    local cfg = ATMO_TYPES[atmoTypeIndex]
    local int = ATMO_INTENSITY[atmoIntensityIndex]
    local sz = ATMO_SIZE[atmoSizeIndex]
    atmoToggle.Text = "❄️ Атмосфера: " .. (SETTINGS.AtmoEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AtmoEnabled then
        atmoToggle.BackgroundColor3 = Color3.fromRGB(50,80,110)
        atmoToggle.TextColor3 = Color3.fromRGB(180,220,255)
    else
        atmoToggle.BackgroundColor3 = Color3.fromRGB(45,45,62)
        atmoToggle.TextColor3 = Color3.fromRGB(220,220,255)
    end
    atmoTypeBtn.Text = cfg.icon .. " Тип: " .. cfg.name
    atmoIntBtn.Text = "📊 Интенсивность: " .. int.name
    atmoSizeBtn.Text = "📏 Размер: " .. sz.name
    atmoColorModeBtn.Text = "🎨 Режим: " .. SETTINGS.AtmoColorMode
    local cname = getColorNameByIndex(SETTINGS.AtmoColorIndex)
    local ccol = getColorByIndex(SETTINGS.AtmoColorIndex)
    atmoColorBtn.Text = "🌈 Цвет: " .. cname
    atmoColorBtn.TextColor3 = ccol
    if SETTINGS.AtmoColorMode == "Авто" then
        atmoColorBtn.BackgroundTransparency = 0.7
    else
        atmoColorBtn.BackgroundTransparency = 0
        atmoColorBtn.BackgroundColor3 = Color3.new(ccol.R*0.3, ccol.G*0.3, ccol.B*0.3)
    end
end
refreshAtmoUI()

onClick(atmoToggle, function()
    SETTINGS.AtmoEnabled = not SETTINGS.AtmoEnabled
    SETTINGS.AtmoType = ATMO_TYPES[atmoTypeIndex].name
    SETTINGS.AtmoIntensity = ATMO_INTENSITY[atmoIntensityIndex].name
    SETTINGS.AtmoSize = ATMO_SIZE[atmoSizeIndex].name
    refreshAtmoUI()
    setupAtmo()
    ORBIT.notify("❄️ Атмосфера: " .. (SETTINGS.AtmoEnabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(180,220,255), 2)
end)
onClick(atmoTypeBtn, function()
    atmoTypeIndex = atmoTypeIndex + 1
    if atmoTypeIndex > #ATMO_TYPES then atmoTypeIndex = 1 end
    SETTINGS.AtmoType = ATMO_TYPES[atmoTypeIndex].name
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)
onClick(atmoIntBtn, function()
    atmoIntensityIndex = atmoIntensityIndex + 1
    if atmoIntensityIndex > #ATMO_INTENSITY then atmoIntensityIndex = 1 end
    SETTINGS.AtmoIntensity = ATMO_INTENSITY[atmoIntensityIndex].name
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)
onClick(atmoSizeBtn, function()
    atmoSizeIndex = atmoSizeIndex + 1
    if atmoSizeIndex > #ATMO_SIZE then atmoSizeIndex = 1 end
    SETTINGS.AtmoSize = ATMO_SIZE[atmoSizeIndex].name
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)
onClick(atmoColorModeBtn, function()
    atmoColorModeIndex = atmoColorModeIndex + 1
    if atmoColorModeIndex > #ATMO_COLOR_MODES then atmoColorModeIndex = 1 end
    SETTINGS.AtmoColorMode = ATMO_COLOR_MODES[atmoColorModeIndex]
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
end)
onClick(atmoColorBtn, function()
    if SETTINGS.AtmoColorMode == "Авто" then
        SETTINGS.AtmoColorMode = "Из списка 50"
        atmoColorModeIndex = 2
    end
    SETTINGS.AtmoColorIndex = ((SETTINGS.AtmoColorIndex) % #COLORS_LIST) + 1
    refreshAtmoUI()
    if SETTINGS.AtmoEnabled then setupAtmo() end
    ORBIT.notify("🎨 Цвет атмосферы: " .. getColorNameByIndex(SETTINGS.AtmoColorIndex),
        getColorByIndex(SETTINGS.AtmoColorIndex), 1.5)
end)

-- ====== ТРЕЙЛ-ШЛЕЙФ ======
makeBigSection("🌠  ТРЕЙЛ-ШЛЕЙФ", finalY, Color3.fromRGB(100, 70, 140))
finalY = finalY + 30

local trailStreamToggle = makeButton("", finalY, BTN_H + 4)
finalY = finalY + BTN_H + 8
local trailStreamLenBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local trailStreamWidBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local trailStreamColorModeBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(60,60,90), Color3.fromRGB(200,220,255))
finalY = finalY + BTN_H + 4
local trailStreamColorBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 10

local function refreshTrailStreamUI()
    trailStreamToggle.Text = "🌠 Шлейф: " .. (SETTINGS.TrailStreamEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.TrailStreamEnabled then
        trailStreamToggle.BackgroundColor3 = Color3.fromRGB(75,50,100)
        trailStreamToggle.TextColor3 = Color3.fromRGB(230,200,255)
    else
        trailStreamToggle.BackgroundColor3 = Color3.fromRGB(45,45,62)
        trailStreamToggle.TextColor3 = Color3.fromRGB(220,220,255)
    end
    local len = P.TRAIL_LEN and P.TRAIL_LEN[P.trailLengthIndex]
    local wid = P.TRAIL_WID and P.TRAIL_WID[P.trailWidthIndex]
    trailStreamLenBtn.Text = "📏 Длина: " .. (len and len.name or "Средний")
    trailStreamWidBtn.Text = "🎚️ Толщина: " .. (wid and wid.name or "Средний")
    trailStreamColorModeBtn.Text = "🎨 Режим: " .. SETTINGS.TrailStreamColorMode
    local cname = getColorNameByIndex(SETTINGS.TrailStreamColorIndex)
    local ccol = getColorByIndex(SETTINGS.TrailStreamColorIndex)
    trailStreamColorBtn.Text = "🌈 Цвет: " .. cname
    trailStreamColorBtn.TextColor3 = ccol
    if SETTINGS.TrailStreamColorMode == "Из списка 50" then
        trailStreamColorBtn.BackgroundTransparency = 0
        trailStreamColorBtn.BackgroundColor3 = Color3.new(ccol.R*0.3, ccol.G*0.3, ccol.B*0.3)
    else
        trailStreamColorBtn.BackgroundTransparency = 0.7
    end
end
refreshTrailStreamUI()

onClick(trailStreamToggle, function()
    SETTINGS.TrailStreamEnabled = not SETTINGS.TrailStreamEnabled
    SETTINGS.TrailStreamColorMode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
    refreshTrailStreamUI()
    setupTrailStream()
    ORBIT.notify("🌠 Шлейф: " .. (SETTINGS.TrailStreamEnabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(230,200,255), 2)
end)
onClick(trailStreamLenBtn, function()
    if not P.TRAIL_LEN then return end
    P.trailLengthIndex = P.trailLengthIndex + 1
    if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    refreshTrailStreamUI()
    if trailStreamTrail then trailStreamTrail.Lifetime = SETTINGS.TrailLength end
end)
onClick(trailStreamWidBtn, function()
    if not P.TRAIL_WID then return end
    P.trailWidthIndex = P.trailWidthIndex + 1
    if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    refreshTrailStreamUI()
    if trailStreamTrail then
        trailStreamTrail.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, SETTINGS.TrailWidth),
            NumberSequenceKeypoint.new(0.7, SETTINGS.TrailWidth * 0.5),
            NumberSequenceKeypoint.new(1, 0),
        })
    end
end)
onClick(trailStreamColorModeBtn, function()
    trailStreamColorIndex = trailStreamColorIndex + 1
    if trailStreamColorIndex > #TRAIL_STREAM_COLOR_MODES then trailStreamColorIndex = 1 end
    SETTINGS.TrailStreamColorMode = TRAIL_STREAM_COLOR_MODES[trailStreamColorIndex]
    refreshTrailStreamUI()
end)
onClick(trailStreamColorBtn, function()
    if SETTINGS.TrailStreamColorMode ~= "Из списка 50" then
        SETTINGS.TrailStreamColorMode = "Из списка 50"
        trailStreamColorIndex = 2
    end
    SETTINGS.TrailStreamColorIndex = ((SETTINGS.TrailStreamColorIndex) % #COLORS_LIST) + 1
    refreshTrailStreamUI()
    ORBIT.notify("🌈 Цвет шлейфа: " .. getColorNameByIndex(SETTINGS.TrailStreamColorIndex),
        getColorByIndex(SETTINGS.TrailStreamColorIndex), 1.5)
end)

-- ====== РЕАКТИВНЫЕ ИСКРЫ ======
makeBigSection("💥  РЕАКТИВНЫЕ ИСКРЫ", finalY, Color3.fromRGB(140, 80, 50))
finalY = finalY + 30

local reactToggle = makeButton("", finalY, BTN_H + 4)
finalY = finalY + BTN_H + 8
local reactColorBtn = makeButton("", finalY, BTN_H, Color3.fromRGB(80,60,110), Color3.fromRGB(240,210,255))
finalY = finalY + BTN_H + 8

local reactHint = Instance.new("TextLabel")
reactHint.Size = UDim2.new(1, -20, 0, 40)
reactHint.Position = UDim2.new(0, 10, 0, finalY)
reactHint.BackgroundColor3 = Color3.fromRGB(35, 25, 20)
reactHint.BackgroundTransparency = 0.3
reactHint.BorderSizePixel = 0
reactHint.Text = "Искры при прыжке / беге (в момент урона — красные)"
reactHint.TextColor3 = Color3.fromRGB(220, 200, 180)
reactHint.Font = Enum.Font.Gotham
reactHint.TextSize = 10
reactHint.TextWrapped = true
reactHint.ZIndex = 2
if UI.addControl then UI.addControl(reactHint, 40) else reactHint.Parent = panel end
Instance.new("UICorner", reactHint).CornerRadius = UDim.new(0, 6)
finalY = finalY + 46

local function refreshReactUI()
    reactToggle.Text = "💥 Реактивные искры: " .. (SETTINGS.ReactSparksEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.ReactSparksEnabled then
        reactToggle.BackgroundColor3 = Color3.fromRGB(110,60,40)
        reactToggle.TextColor3 = Color3.fromRGB(255,220,180)
    else
        reactToggle.BackgroundColor3 = Color3.fromRGB(45,45,62)
        reactToggle.TextColor3 = Color3.fromRGB(220,220,255)
    end
    local cname = getColorNameByIndex(SETTINGS.ReactSparksColorIndex)
    local ccol = getColorByIndex(SETTINGS.ReactSparksColorIndex)
    reactColorBtn.Text = "🌈 Цвет искр: " .. cname
    reactColorBtn.TextColor3 = ccol
    reactColorBtn.BackgroundColor3 = Color3.new(ccol.R*0.3, ccol.G*0.3, ccol.B*0.3)
end
refreshReactUI()

onClick(reactToggle, function()
    SETTINGS.ReactSparksEnabled = not SETTINGS.ReactSparksEnabled
    refreshReactUI()
    setupReactSparks()
    ORBIT.notify("💥 Искры: " .. (SETTINGS.ReactSparksEnabled and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(255,200,140), 2)
end)
onClick(reactColorBtn, function()
    SETTINGS.ReactSparksColorIndex = ((SETTINGS.ReactSparksColorIndex) % #COLORS_LIST) + 1
    refreshReactUI()
    ORBIT.notify("💥 Цвет искр: " .. getColorNameByIndex(SETTINGS.ReactSparksColorIndex),
        getColorByIndex(SETTINGS.ReactSparksColorIndex), 1.5)
end)

if not UI.addSection then panel.CanvasSize = UDim2.new(0, 0, 0, finalY + 20) end

-- ============================================================
--       РЕСПАВН
-- ============================================================
local respawnConn = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if SETTINGS.AtmoEnabled then setupAtmo() end
    if SETTINGS.TrailStreamEnabled then setupTrailStream() end
    if SETTINGS.ReactSparksEnabled then setupReactSparks() end
end)

-- ============================================================
--       ИНИЦИАЛИЗАЦИЯ
-- ============================================================
if SETTINGS.AtmoEnabled then setupAtmo() end
if SETTINGS.TrailStreamEnabled then setupTrailStream() end
if SETTINGS.ReactSparksEnabled then setupReactSparks() end

-- ============================================================
--       ВЫГРУЗКА
-- ============================================================
do
    local prevUnload = ORBIT.unload
    ORBIT.unload = function()
        pcall(function() respawnConn:Disconnect() end)
        if atmoConn then pcall(function() atmoConn:Disconnect() end); atmoConn = nil end
        if trailStreamConn then pcall(function() trailStreamConn:Disconnect() end); trailStreamConn = nil end
        if reactSparksConn then pcall(function() reactSparksConn:Disconnect() end); reactSparksConn = nil end
        if atmoFolder then pcall(function() atmoFolder:Destroy() end); atmoFolder = nil; atmoEmitter = nil end
        if trailStreamFolder then
            pcall(function() trailStreamFolder:Destroy() end)
            trailStreamFolder = nil; trailStreamPart = nil; trailStreamTrail = nil
        end
        if reactSparksFolder then pcall(function() reactSparksFolder:Destroy() end); reactSparksFolder = nil end
        if prevUnload then pcall(prevUnload) end
    end
end

-- ============================================================
--       СИНХРОНИЗАЦИЯ ИЗ SETTINGS
-- ============================================================
local function syncFromSettings()
    for i, t in ipairs(ATMO_TYPES) do if t.name == SETTINGS.AtmoType then atmoTypeIndex = i; break end end
    for i, t in ipairs(ATMO_INTENSITY) do if t.name == SETTINGS.AtmoIntensity then atmoIntensityIndex = i; break end end
    for i, t in ipairs(ATMO_SIZE) do if t.name == SETTINGS.AtmoSize then atmoSizeIndex = i; break end end
    for i, m in ipairs(ATMO_COLOR_MODES) do if m == SETTINGS.AtmoColorMode then atmoColorModeIndex = i; break end end
    for i, m in ipairs(TRAIL_STREAM_COLOR_MODES) do if m == SETTINGS.TrailStreamColorMode then trailStreamColorIndex = i; break end end
    pcall(setupAtmo)
    pcall(setupTrailStream)
    pcall(setupReactSparks)
end

local function setAtmo(enabled, typeName, intensityName, sizeName)
    SETTINGS.AtmoEnabled = enabled == true
    if typeName then SETTINGS.AtmoType = typeName end
    if intensityName then SETTINGS.AtmoIntensity = intensityName end
    if sizeName then SETTINGS.AtmoSize = sizeName end
    SETTINGS.AtmoColorMode = "Авто"
    syncFromSettings()
end

ORBIT.extras = {
    syncFromSettings = syncFromSettings,
    setAtmo = setAtmo,
    setupAtmo = setupAtmo,
    setupTrailStream = setupTrailStream,
    setupReactSparks = setupReactSparks,
    reactBurst = reactBurst,
    getColorByIndex = getColorByIndex,
    getColorByName = getColorByName,
    getColorNameByIndex = getColorNameByIndex,
}

ORBIT.loaded = ORBIT.loaded or {}
ORBIT.loaded.extras = true
ORBIT.loaded.sfx = true

if ORBIT.notify then
    ORBIT.notify("❄️ Extras v24.0 загружен", Color3.fromRGB(180,220,255), 3)
end
warn("[Orbit Extras v24.0] Загружен ✅")
return true
