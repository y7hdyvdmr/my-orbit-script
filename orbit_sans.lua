-- ORBIT v24.1 | orbit_sans.lua
-- Фразы Санса и его голос. Используется p3 (onPlayerDied), orbit_death_fx и UI (эмоции).
-- v24.0: say(category, force) с cooldown; поддержка death/spawn/greet/hurt/kill/dodge/taunt.
-- v24.1: добавлены lastCat / lastSaid / lastCatTime / showAt(pos, text, sec) — ждёт orbit_death_fx.

local G = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = G.ORBIT or shared.ORBIT
if not ORBIT then warn("[Orbit Sans] ORBIT не загружен"); return false end
if ORBIT.sans and ORBIT.sans.ready then warn("[Orbit Sans] уже загружен"); return false end
ORBIT.loaded = ORBIT.loaded or {}

local Players    = ORBIT.Players or game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService = ORBIT.RunService or game:GetService("RunService")
local Debris     = game:GetService("Debris")
local WS         = ORBIT.Workspace or game:GetService("Workspace")
local LocalPlayer = ORBIT.LocalPlayer or Players.LocalPlayer

local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB

ORBIT.sans = ORBIT.sans or {}
local S = ORBIT.sans

-- ============================================================
--       ФРАЗЫ ПО КАТЕГОРИЯМ
-- ============================================================
S.phrases = {
    death = {
        "heh. так и знал.",
        "ну вот. опять умер.",
        "да ладно, я же шутил...",
        "не сдавайся. попробуй снова.",
        "ты держался достойно.",
        "опять? ну хоть не в первый раз.",
    },
    spawn = {
        "с возвращением.",
        "погнали по-новой.",
        "второй шанс, да?",
        "надеюсь, в этот раз получится.",
        "ну что, ещё разок?",
    },
    greet = {
        "йоу.",
        "привет, дружище.",
        "давно не виделись.",
        "о, а ты ещё тут?",
        "здарова.",
    },
    hurt = {
        "ой!",
        "это было грубо.",
        "ладно, я почувствовал.",
        "больно, вообще-то.",
        "хороший удар.",
    },
    kill = {
        "и всё?",
        "слишком просто.",
        "научись играть.",
        "неплохо, но мало.",
        "следующий.",
    },
    dodge = {
        "увернулся.",
        "мимо!",
        "не сегодня.",
        "слишком медленно.",
        "промазал.",
    },
    taunt = {
        "у тебя всё получится.",
        "верю в тебя.",
        "не сдавайся, ладно?",
        "всё будет хорошо.",
        "сделай глубокий вдох.",
    },
    combo = {
        "двойной удар!",
        "а это тебе!",
        "вот так, да!",
        "неплохая комбинация.",
        "и всё-таки я лучше.",
    },
}

-- ============================================================
--       ЗВУКИ ГОЛОСА (rbxassetid)
-- ============================================================
S.voiceIds = {
    default = "rbxassetid://6849164472",
    death   = "rbxassetid://6849164472",
    spawn   = "rbxassetid://6849164472",
    hurt    = "rbxassetid://6849164472",
}

S.sound = nil
S.cooldowns = {}
S.COOLDOWN_DEFAULT = 1.2
S.ENABLED = true

-- v24.1: последняя фраза
S.lastCat = nil
S.lastCatTime = 0
S.lastSaid = nil

-- ============================================================
--       ПОИСК / СОЗДАНИЕ SOUND-ОБЪЕКТА
-- ============================================================
local function ensureSound()
    if S.sound and S.sound.Parent then return S.sound end
    local snd = Instance.new("Sound")
    snd.Name = "_OrbitSansVoice"
    snd.Volume = (ORBIT.SOUNDS and ORBIT.SOUNDS.Volume) or 0.7
    snd.SoundId = S.voiceIds.default
    snd.Parent = SoundService
    S.sound = snd
    return snd
end

-- ============================================================
--       ПРОИГРАТЬ ГОЛОС
-- ============================================================
function S.playSound(category)
    if not S.ENABLED then return false end
    local snd = ensureSound()
    if not snd then return false end
    snd.SoundId = S.voiceIds[category] or S.voiceIds.default
    snd.Volume = (ORBIT.SOUNDS and ORBIT.SOUNDS.Enabled ~= false)
        and ((ORBIT.SOUNDS and ORBIT.SOUNDS.Volume) or 0.7) or 0
    pcall(function() snd:Play() end)
    return true
end

-- ============================================================
--       ВСПЛЫВАЮЩИЙ ТЕКСТ В МИРЕ (над сердцем / точкой)
-- ============================================================
S.liveTags = {}   -- активные BillboardGui (для очистки при unload)

-- showAt(pos, text, seconds) — показать фразу в 3D-мире над pos
function S.showAt(pos, text, seconds)
    if not S.ENABLED or not text or text == "" then return false end
    if typeof(pos) == "CFrame" then pos = pos.Position end
    if typeof(pos) ~= "Vector3" then return false end
    seconds = seconds or 3

    local anchor = Instance.new("Part")
    anchor.Name = "OrbitSansTag"
    anchor.Size = V3(0.1, 0.1, 0.1)
    anchor.Transparency = 1
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.CastShadow = false
    anchor.CFrame = CF(pos)
    anchor.Parent = WS

    local bb = Instance.new("BillboardGui")
    bb.Name = "_OrbitSansBillboard"
    bb.Size = UDim2.new(0, 320, 0, 60)
    bb.StudsOffset = V3(0, 0, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.Adornee = anchor
    bb.Parent = anchor

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C3(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 20
    lbl.TextWrapped = true
    lbl.TextStrokeTransparency = 0.2
    lbl.TextStrokeColor3 = C3(0, 0, 0)
    lbl.Parent = bb

    -- появление
    lbl.TextTransparency = 1
    pcall(function()
        game:GetService("TweenService"):Create(lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
    end)

    -- исчезновение + удаление
    task.delay(seconds, function()
        pcall(function()
            game:GetService("TweenService"):Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        end)
        task.wait(0.45)
        pcall(function() if anchor.Parent then anchor:Destroy() end end)
    end)

    S.liveTags[#S.liveTags + 1] = anchor
    Debris:AddItem(anchor, seconds + 1)
    return true
end

-- ============================================================
--       СКАЗАТЬ ФРАЗУ
-- ============================================================
function S.say(category, force)
    if not S.ENABLED then return false end
    if ORBIT.mode ~= "sans" and not force then return false end
    category = category or "greet"
    local list = S.phrases[category] or S.phrases.greet
    if not list or #list == 0 then return false end

    local now = tick()
    local last = S.cooldowns[category] or 0
    if not force and (now - last) < S.COOLDOWN_DEFAULT then return false end
    S.cooldowns[category] = now

    local text = list[math.random(1, #list)]

    -- v24.1: запоминаем последнюю фразу (нужно death_fx)
    S.lastCat = category
    S.lastSaid = text
    S.lastCatTime = now

    pcall(S.playSound, category)

    if ORBIT.notify then
        local color = C3(200, 220, 255)
        if category == "death" then color = C3(255, 180, 180)
        elseif category == "kill" then color = C3(255, 140, 140)
        elseif category == "hurt" then color = C3(255, 200, 140)
        elseif category == "taunt" then color = C3(180, 255, 200)
        elseif category == "combo" then color = C3(255, 240, 120) end
        ORBIT.notify("💀 " .. text, color, 3)
    end

    warn("[Orbit Sans][" .. category .. "] " .. text)

    -- v24.1: возвращаем текст, не true (death_fx ждёт строку)
    return text
end

-- ============================================================
--       ВКЛ/ВЫКЛ
-- ============================================================
function S.setEnabled(state)
    S.ENABLED = state and true or false
    if not S.ENABLED and S.sound then pcall(function() S.sound:Stop() end) end
    if ORBIT.notify then
        ORBIT.notify("💀 Санс: " .. (S.ENABLED and "ВКЛ" or "ВЫКЛ"),
            C3(200, 220, 255), 2)
    end
    return S.ENABLED
end

function S.toggle() return S.setEnabled(not S.ENABLED) end

-- ============================================================
--       БЫСТРЫЕ АЛИАСЫ
-- ============================================================
S.sayDeath = function() return S.say("death", true) end
S.saySpawn = function() return S.say("spawn", true) end
S.sayGreet = function() return S.say("greet") end
S.sayHurt  = function() return S.say("hurt") end
S.sayKill  = function() return S.say("kill") end
S.sayDodge = function() return S.say("dodge") end
S.sayTaunt = function() return S.say("taunt") end
S.sayCombo = function() return S.say("combo") end

-- ============================================================
--       АВТО-ХУК НА СПАВН
-- ============================================================
task.spawn(function()
    task.wait(2)
    if ORBIT.mode == "sans" then pcall(S.say, "spawn", true) end
end)

if LocalPlayer then
    local function hook(char)
        if not char then return end
        task.wait(0.5)
        if ORBIT.mode == "sans" and S.ENABLED then
            pcall(S.say, "spawn", true)
        end
    end
    LocalPlayer.CharacterAdded:Connect(hook)
end

-- ============================================================
--       ОЧИСТКА
-- ============================================================
local prevUnload = ORBIT.unload
ORBIT.unload = function()
    for _, anchor in ipairs(S.liveTags) do
        pcall(function() if anchor.Parent then anchor:Destroy() end end)
    end
    S.liveTags = {}
    if S.sound then pcall(function() S.sound:Stop() end); pcall(function() S.sound:Destroy() end); S.sound = nil end
    if prevUnload then pcall(prevUnload) end
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
S.ready = true
ORBIT.sans = S

if ORBIT.notify then
    ORBIT.notify("💀 Санс v24.1 (фразы + showAt)", C3(200, 220, 255), 2)
end

return true
