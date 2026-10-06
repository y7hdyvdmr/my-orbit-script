-- ОРБИТА v23.6 — SFX (звуки + эмоции)
-- Загружается из orbit_p1.lua (или из orbit_anticheat.lua).
-- Подменяет ORBIT.playClick / playDodge / playBotCollect / playWin / playBuy.
--
-- Звуки:
--   - 135692693675195 — 🎤 голос Санса
--   - 113650760423588 — 😂 смех
--   - 140721035016341 — 💨 звук уворота
--   - 6325779988      — 💨 после уворота
--   - 12221967        — 🎁 сбор бота
--
-- Публичный API:
--   ORBIT.emote("sans" | "laugh" | "dance" | "greet" | "dodge")
--   ORBIT.Sfx.play(name, vol, pitch) — низкоуровневый проигрыватель
--   ORBIT.playDodge() — звук уворота + (Санс ИЛИ смех), максимум 2 звука
--
-- ИСТОРИЯ:
--   v22.7 — финальный SFX с Сансом и смехом, эмоция Laugh при увороте.
--   v23.5 — при повторном запуске старая папка со звуками удаляется;
--           ORBIT.unload убирает папку и возвращает оригинальные функции;
--           _origPlayClick/... запоминаются только один раз.
--   v23.6 — ORBIT.emote("sans"|"laugh"|"dance"|"greet"|"dodge"); один голос за раз;
--           уворот = звук уворота + (Санс ИЛИ смех), максимум 2 звука; победа — 1 звук.
--   v23.6-fix1 — шапка синхронизирована (было v22.7); удалён устаревший комментарий
--                «ПРОВЕРКА v23.6: багов не найдено»; добавлен warn с версией в конце.
--
-- ВАЖНО: все идентификаторы латиницей.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit SFX] ORBIT не найден!"); return end

local SoundService    = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris          = game:GetService("Debris")

local Sfx = {}

-- ============================================================
--              ВСЕ ЗВУКИ
-- ============================================================
local IDS = {
    -- Встроенные клиента (всегда работают)
    click       = "rbxasset://sounds/button.wav",
    switch      = "rbxasset://sounds/switch.wav",
    ping        = "rbxasset://sounds/electronicpingshort.wav",
    snap        = "rbxasset://sounds/snap.mp3",

    -- Твои кастомные
    dodge       = "rbxassetid://140721035016341",  -- 💨 звук уворота
    afterDodge  = "rbxassetid://6325779988",       -- 💨 после уворота
    sans        = "rbxassetid://135692693675195",  -- 🎤 голос Санса
    laugh       = "rbxassetid://113650760423588",  -- 😂 смех
    botCollect  = "rbxassetid://12221967",         -- 🎁 сбор бота
}

-- Контейнер (старую папку от прошлого запуска убираем)
if ORBIT.sfxFolder and ORBIT.sfxFolder.Parent then pcall(function() ORBIT.sfxFolder:Destroy() end) end
local folder = Instance.new("Folder")
folder.Name = "OrbitSfx_" .. tostring(math.random(100000, 999999))
folder.Parent = SoundService
ORBIT.sfxFolder = folder

-- Шаблоны
local templates = {}
for name, id in pairs(IDS) do
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = id
    s.Volume = 0.5
    s.Parent = folder
    templates[name] = s
end

-- Предзагрузка (чтобы не было задержки)
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

function Sfx.play(name, vol, pitch)
    local tpl = templates[name]
    if not tpl then return end

    local enabled, master = settings()
    if not enabled or master <= 0 then return end

    -- Антиспам 40 мс
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

-- ============================================================
--              ЭМОЦИЯ LAUGH (безопасная)
-- ============================================================
-- Проигрывает эмоцию Laugh. Если поза застревает — сбрасываем через 2 сек.
local function playLaughEmote()
    pcall(function()
        local char = ORBIT.LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        -- Пробуем проиграть эмоцию
        local ok = pcall(function() hum:PlayEmote("Laugh") end)
        if not ok then return end

        -- Через 2 секунды сбрасываем застрявшую анимацию
        task.delay(2, function()
            pcall(function()
                local animator = hum:FindFirstChildOfClass("Animator")
                if not animator then return end
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local name = track.Animation and track.Animation.Name or ""
                    -- Останавливаем эмоции (laugh, cheer, wave и т.д.)
                    if name:lower():find("laugh")
                       or name:lower():find("emote") then
                        track:Stop(0)
                    end
                end
            end)
        end)
    end)
end

-- ============================================================
--              ЭМОЦИИ (v23.6, EM1/EM2)
-- ============================================================
-- Единая точка для обычного режима и режима античита.
-- Правила: голос играет ОДИН за раз; на событие — максимум 2 звука; у каждой эмоции свой кулдаун.
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

-- проиграть встроенную эмоцию Roblox и гарантированно остановить её
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

-- облачко с текстом над головой (речь Санса)
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
        sayBubble(SANS_PHRASES[math.random(1, #SANS_PHRASES)], 3)
        return true
    elseif name == "laugh" then
        if not voiceFree() then return false end
        takeVoice(1.8)
        playRobloxEmote("Laugh", 2)
        Sfx.play("laugh", 0.8, 1)
        return true
    elseif name == "dance" then
        local dances = {"dance", "dance2", "dance3"}
        playRobloxEmote(dances[math.random(1, #dances)], 6)
        return true
    elseif name == "greet" then
        playRobloxEmote("wave", 2.5)
        sayBubble("привет!", 2)
        return true
    elseif name == "dodge" then
        Sfx.play("dodge", 1, 1)
        task.delay(0.45, function()
            -- второй звук: ЛИБО Санс, ЛИБО смех (никогда оба сразу)
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

-- 🖱️ Клик по кнопкам
ORBIT.playClick = function()
    Sfx.play("click", 1, 1)
end

-- 🎁 Сбор бота (фейерверк + звук)
ORBIT.playBotCollect = function()
    Sfx.play("botCollect", 1, 1.2)
end

-- 💨 Уворот от античита: звук уворота + (Санс ИЛИ смех). Максимум 2 звука, без наложения (AC1)
ORBIT.playDodge = function()
    Sfx.emote("dodge")
end
ORBIT.emote = function(name) return Sfx.emote(name) end

-- 🏆 Победа в мини-игре
ORBIT.playWin = function()
    Sfx.play("ping", 1, 1.6)
end

-- 💰 Покупка в магазине
ORBIT.playBuy = function()
    Sfx.play("switch", 1, 1.3)
end

-- 🔀 Переключатель
ORBIT.playSwitch = function()
    Sfx.play("switch", 1, 1)
end

-- 🛡️ Защита сработала (Smart Floor и т.д.)
ORBIT.playProtect = function()
    Sfx.play("snap", 1, 0.9)
end

ORBIT.Sfx = Sfx

-- при выгрузке скрипта: убираем папку и возвращаем оригинальные функции
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

print("[Orbit SFX v23.6] ═══════════════════════════════════")
print("[Orbit SFX v23.6] Загружен ✅")
print("[Orbit SFX v23.6] Звуки:")
print("[Orbit SFX v23.6]   💨 Уворот: 140721035016341")
print("[Orbit SFX v23.6]   💨 После:  6325779988")
print("[Orbit SFX v23.6]   🎤 Санс:   135692693675195")
print("[Orbit SFX v23.6]   😂 Смех:   113650760423588")
print("[Orbit SFX v23.6]   🎁 Бот:    12221967")
print("[Orbit SFX v23.6] ═══════════════════════════════════")
warn("[Orbit SFX v23.6] Загружен ✅")

return true
