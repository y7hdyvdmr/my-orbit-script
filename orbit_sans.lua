-- ORBIT v24.2 | orbit_sans.lua
-- Расширенный набор фраз + showAt + реакция на события игрока
local G = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = G.ORBIT or shared.ORBIT
if not ORBIT then warn("[Orbit Sans] ORBIT не загружен"); return false end
if ORBIT.sans and ORBIT.sans.ready then warn("[Orbit Sans] уже загружен"); return false end
ORBIT.loaded = ORBIT.loaded or {}

local Players      = ORBIT.Players or game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService   = ORBIT.RunService or game:GetService("RunService")
local Debris       = game:GetService("Debris")
local TS           = game:GetService("TweenService")
local WS           = ORBIT.Workspace or game:GetService("Workspace")
local LP           = ORBIT.LocalPlayer or Players.LocalPlayer

local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB

ORBIT.sans = ORBIT.sans or {}
local S = ORBIT.sans

-- ============================================================
--       ФРАЗЫ (v24.2: расширенный набор)
-- ============================================================
S.phrases = {
    death = {
        "heh. так и знал.",
        "ну вот. опять умер.",
        "да ладно, я же шутил...",
        "не сдавайся. попробуй снова.",
        "ты держался достойно.",
        "опять? ну хоть не в первый раз.",
        "это... было больно.",
        "ладно, признаю — ты меня достал.",
        "хорошая попытка. правда.",
        "знаешь, в следующий раз — увернись.",
        "тц. надо было взять хилку.",
        "ну и ладно. я всё равно вернусь.",
    },
    spawn = {
        "с возвращением.",
        "погнали по-новой.",
        "второй шанс, да?",
        "надеюсь, в этот раз получится.",
        "ну что, ещё разок?",
        "вставай. у нас дела.",
        "похоже, ты снова в деле.",
        "ну вот, я тут.",
        "не отставай.",
    },
    greet = {
        "йоу.",
        "привет, дружище.",
        "давно не виделись.",
        "о, а ты ещё тут?",
        "здарова.",
        "ты как? я в порядке.",
        "о, привет. ну что, пошалим?",
        "приветик.",
        "здорово, братишка.",
        "а я думал, ты ушёл.",
        "ну наконец-то.",
        "ку-ку.",
    },
    hurt = {
        "ой!",
        "это было грубо.",
        "ладно, я почувствовал.",
        "больно, вообще-то.",
        "хороший удар.",
        "ай! за что?",
        "ты чего дерёшься?",
        "это было невежливо.",
        "ладно, я это запомню.",
        "ну и хам.",
        "фу таким быть.",
    },
    kill = {
        "и всё?",
        "слишком просто.",
        "научись играть.",
        "неплохо, но мало.",
        "следующий.",
        "ты видел, как я это сделал?",
        "и даже не вспотел.",
        "неплохо для новичка.",
        "хм. неплохо.",
        "слабовато, честно.",
        "тренируйся ещё.",
    },
    dodge = {
        "увернулся.",
        "мимо!",
        "не сегодня.",
        "слишком медленно.",
        "промазал.",
        "и это всё?",
        "мимо-мимо.",
        "я даже не заметил.",
        "быстрее надо.",
        "неплохо, но нет.",
        "уворачиваюсь, как бог.",
    },
    taunt = {
        "у тебя всё получится.",
        "верю в тебя.",
        "не сдавайся, ладно?",
        "всё будет хорошо.",
        "сделай глубокий вдох.",
        "ты справишься.",
        "расслабься. это просто игра.",
        "я в тебя верю, честно.",
        "давай, покажи класс.",
        "ты можешь больше.",
    },
    combo = {
        "двойной удар!",
        "а это тебе!",
        "вот так, да!",
        "неплохая комбинация.",
        "и всё-таки я лучше.",
        "хрясь!",
        "бах-бах!",
        "и это ещё не всё.",
        "держи-держи!",
        "двойная порция!",
    },
    victory = {
        "и это всё?",
        "я даже не устал.",
        "слабовато.",
        "попробуй ещё разок.",
        "ну... ожидал большего.",
        "тренируйся, малыш.",
    },
    idle = {
        "ты тут?",
        "скучно...",
        "может, что-нибудь сделаем?",
        "я тут просто стою.",
        "не храпи, я слышу.",
        "ну ты где?",
        "я начинаю засыпать.",
        "может, пошалим?",
    },
    lowhp = {
        "ты в порядке?",
        "не умирай сейчас!",
        "подлечись, а?",
        "осторожнее.",
        "кажется, тебе нужна помощь.",
        "ты выглядишь бледно.",
        "давай, соберись!",
    },
    spawnkill = {
        "ну и манеры.",
        "ты чего творишь?",
        "спавн-килл? серьёзно?",
        "это уже наглость.",
        "ты что, вообще без совести?",
    },
    combo_missing = {
        "нужна пара стихий, приятель.",
        "попробуй две разные стихии подряд.",
        "комбо не готово.",
        "две разные — и погнали.",
    },
}

-- ============================================================
--       ГОЛОСА
-- ============================================================
S.voiceIds = {
    default = "rbxassetid://6849164472",
    death   = "rbxassetid://6849164472",
    spawn   = "rbxassetid://6849164472",
    hurt    = "rbxassetid://6849164472",
    laugh   = "rbxassetid://113650760423588",
    sans    = "rbxassetid://135692693675195",
}
S.sound = nil
S.cooldowns = {}
S.COOLDOWN_DEFAULT = 1.2
S.ENABLED = true
S.lastCat = nil
S.lastCatTime = 0
S.lastSaid = nil

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

function S.playSound(category)
    if not S.ENABLED then return false end
    local snd = ensureSound()
    if not snd then return false end
    snd.SoundId = S.voiceIds[category] or S.voiceIds.default
    snd.Volume = ((ORBIT.SOUNDS and ORBIT.SOUNDS.Enabled ~= false)
        and ((ORBIT.SOUNDS and ORBIT.SOUNDS.Volume) or 0.7)) or 0
    pcall(function() snd:Play() end)
    return true
end

-- ============================================================
--       ВСПЛЫВАЮЩИЙ ТЕКСТ
-- ============================================================
S.liveTags = {}
function S.showAt(pos, text, seconds)
    if not S.ENABLED or not text or text == "" then return false end
    if typeof(pos) == "CFrame" then pos = pos.Position end
    if typeof(pos) ~= "Vector3" then return false end
    seconds = seconds or 3

    local anchor = Instance.new("Part")
    anchor.Name = "OrbitSansTag"
    anchor.Size = V3(0.1, 0.1, 0.1); anchor.Transparency = 1
    anchor.Anchored = true; anchor.CanCollide = false
    anchor.CanQuery = false; anchor.CanTouch = false; anchor.CastShadow = false
    anchor.CFrame = CF(pos); anchor.Parent = WS

    local bb = Instance.new("BillboardGui")
    bb.Name = "_OrbitSansBillboard"
    bb.Size = UDim2.new(0, 320, 0, 60)
    bb.AlwaysOnTop = true; bb.LightInfluence = 0
    bb.Adornee = anchor; bb.Parent = anchor

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = C3(255, 255, 255)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 20
    lbl.TextWrapped = true; lbl.TextStrokeTransparency = 0.2; lbl.TextStrokeColor3 = C3(0, 0, 0)
    lbl.Parent = bb
    lbl.TextTransparency = 1
    pcall(function() TS:Create(lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play() end)

    task.delay(seconds, function()
        pcall(function() TS:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play() end)
        task.wait(0.45)
        pcall(function() if anchor.Parent then anchor:Destroy() end end)
    end)
    S.liveTags[#S.liveTags + 1] = anchor
    Debris:AddItem(anchor, seconds + 1)
    return true
end

-- ============================================================
--       СКАЗАТЬ
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
        elseif category == "combo" then color = C3(255, 240, 120)
        elseif category == "victory" then color = C3(200, 255, 200)
        elseif category == "lowhp" then color = C3(255, 150, 150)
        elseif category == "spawnkill" then color = C3(255, 120, 120) end
        ORBIT.notify("💀 " .. text, color, 3)
    end
    warn("[Orbit Sans][" .. category .. "] " .. text)
    return text
end

-- ============================================================
--       ВКЛ/ВЫКЛ
-- ============================================================
function S.setEnabled(state)
    S.ENABLED = state and true or false
    if not S.ENABLED and S.sound then pcall(function() S.sound:Stop() end) end
    if ORBIT.notify then
        ORBIT.notify("💀 Санс: " .. (S.ENABLED and "ВКЛ" or "ВЫКЛ"), C3(200, 220, 255), 2)
    end
    return S.ENABLED
end
function S.toggle() return S.setEnabled(not S.ENABLED) end

-- ============================================================
--       АЛИАСЫ
-- ============================================================
S.sayDeath   = function() return S.say("death", true) end
S.saySpawn   = function() return S.say("spawn", true) end
S.sayGreet   = function() return S.say("greet") end
S.sayHurt    = function() return S.say("hurt") end
S.sayKill    = function() return S.say("kill") end
S.sayDodge   = function() return S.say("dodge") end
S.sayTaunt   = function() return S.say("taunt") end
S.sayCombo   = function() return S.say("combo") end
S.sayVictory = function() return S.say("victory") end
S.sayIdle    = function() return S.say("idle") end
S.sayLowHP   = function() return S.say("lowhp") end
S.saySpawnKill = function() return S.say("spawnkill") end

-- ============================================================
--       ХУК НА СПАВН + СЛЕЖЕНИЕ ЗА HP
-- ============================================================
local hpConn, lastHP = nil, nil
local function hookChar(char)
    if not char then return end
    if hpConn then pcall(function() hpConn:Disconnect() end); hpConn = nil end
    task.wait(0.4)
    if ORBIT.mode == "sans" and S.ENABLED then pcall(S.say, "spawn", true) end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    lastHP = hum.Health
    hpConn = hum.HealthChanged:Connect(function(h)
        if not S.ENABLED or ORBIT.mode ~= "sans" then return end
        local maxH = hum.MaxHealth > 0 and hum.MaxHealth or 100
        if h < lastHP - 0.5 then
            -- получил урон
            if h / maxH < 0.25 and (tick() - (S.cooldowns.lowhp or 0)) > 8 then
                pcall(S.say, "lowhp")
            else
                pcall(S.say, "hurt")
            end
        elseif h < lastHP then
            -- лёгкий тик
        end
        lastHP = h
    end)
end

task.spawn(function() task.wait(2) end)
if LP then
    if LP.Character then task.spawn(hookChar, LP.Character) end
    LP.CharacterAdded:Connect(function(c) task.spawn(hookChar, c) end)
end

-- ============================================================
--       ОЧИСТКА
-- ============================================================
local prevUnload = ORBIT.unload
ORBIT.unload = function()
    if hpConn then pcall(function() hpConn:Disconnect() end); hpConn = nil end
    for _, anchor in ipairs(S.liveTags) do
        pcall(function() if anchor.Parent then anchor:Destroy() end end)
    end
    S.liveTags = {}
    if S.sound then
        pcall(function() S.sound:Stop() end)
        pcall(function() S.sound:Destroy() end)
        S.sound = nil
    end
    if prevUnload then pcall(prevUnload) end
end

S.ready = true
ORBIT.sans = S

if ORBIT.notify then
    ORBIT.notify("💀 Санс v24.2 (" .. tostring((function() local n=0 for _ in pairs(S.phrases) do for _ in ipairs(S.phrases[_]) do n=n+1 end end return n end)()) .. " фраз)", C3(200, 220, 255), 2)
end

return true
