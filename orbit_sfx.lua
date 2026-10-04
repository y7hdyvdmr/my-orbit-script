--[[ ОРБИТА v22.7 — SFX (ФИНАЛЬНЫЙ с Сансом и смехом)
     Загружается из orbit_p1.lua
     Подменяет ORBIT.playClick / playDodge / playBotCollect / playWin / playBuy

     Звуки:
     - 135692693675195 — 🎤 голос Санса
     - 113650760423588 — 😂 смех
     - 140721035016341 — 💨 звук уворота
     - 6325779988      — 💨 после уворота
     - 12221967        — 🎁 сбор бота

     + Эмоция Laugh при увороте
]]
--[[ ИЗМЕНЕНИЯ (общий релиз v23.5):
  🐛 при повторном запуске скрипта старая папка со звуками оставалась в SoundService — теперь удаляется;
  🐛 ORBIT.unload не убирал папку и не возвращал оригинальные функции звуков — добавлено;
  🐛 _origPlayClick/_origPlayDodge/... перезаписывались уже подменёнными функциями при повторной
     загрузке — оригиналы запоминаются только один раз.
]]
--[[ ПРОВЕРКА v23.6: багов не найдено. Логика / коннекты / unload — корректны.
     Файл возвращён без изменений.
]]

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

        -- 🆕 Через 2 секунды сбрасываем застрявшую анимацию
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

-- 💨 Уворот от античита — полная последовательность
ORBIT.playDodge = function()
    -- 1. Звук уворота (сразу)
    Sfx.play("dodge", 1, 1)

    -- 2. После уворота (через 0.3 сек)
    task.delay(0.3, function()
        Sfx.play("afterDodge", 1, 1)
    end)

    -- 3. Санс + смех + эмоция (через 0.6 сек)
    task.delay(0.6, function()
        -- Эмоция Laugh (с авто-сбросом)
        playLaughEmote()

        -- 🎤 Голос Санса
        Sfx.play("sans", 1, 1)

        -- 😂 Смех (накладывается чуть позже)
        task.delay(0.15, function()
            Sfx.play("laugh", 0.8, 1)
        end)
    end)
end

-- 🏆 Победа в мини-игре
ORBIT.playWin = function()
    Sfx.play("ping", 1, 1.6)
    task.delay(0.2, function()
        Sfx.play("laugh", 0.6, 1.1)
    end)
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

print("[Orbit SFX] ═══════════════════════════════════")
print("[Orbit SFX] Загружен ✅")
print("[Orbit SFX] Звуки:")
print("[Orbit SFX]   💨 Уворот: 140721035016341")
print("[Orbit SFX]   💨 После:  6325779988")
print("[Orbit SFX]   🎤 Санс:   135692693675195")
print("[Orbit SFX]   😂 Смех:   113650760423588")
print("[Orbit SFX]   🎁 Бот:    12221967")
print("[Orbit SFX] ═══════════════════════════════════")

return true
