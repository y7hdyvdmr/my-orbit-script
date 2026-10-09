-- ORBIT v24.6 | orbit_sans.lua
-- Фразы Санса во всём проекте. Лучшие фразы + дерзкие.
local G = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = G.ORBIT or shared.ORBIT
if not ORBIT then warn("[Orbit Sans] ORBIT не загружен"); return false end
if ORBIT.sans and ORBIT.sans.ready and ORBIT.sans.version == "v24.6" then
    warn("[Orbit Sans] v24.6 уже загружен"); return false
end
if ORBIT.sans and ORBIT.sans.destroy then pcall(ORBIT.sans.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players      = ORBIT.Players or game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RunService   = ORBIT.RunService or game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local WS           = ORBIT.Workspace or game:GetService("Workspace")
local LP           = ORBIT.LocalPlayer or Players.LocalPlayer

local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB

ORBIT.sans = ORBIT.sans or {}
local S = ORBIT.sans
S.version = "v24.6"
S.ready = true

-- ============================================================
--       ФРАЗЫ (только лучшие + дерзкие)
-- ============================================================
S.phrases = {
    death = {
        "heh. так и знал.",
        "ну вот. опять умер.",
        "не сдавайся. попробуй снова.",
        "ты держался достойно.",
        "ладно, признаю — ты меня достал.",
        "тц. надо было взять хилку.",
        "ну и ладно. я всё равно вернусь.",
        "это... было больно.",
    },
    spawn = {
        "с возвращением.",
        "погнали по-новой.",
        "второй шанс, да?",
        "вставай. у нас дела.",
        "похоже, ты снова в деле.",
        "не отставай.",
    },
    greet = {
        "йоу.",
        "привет, дружище.",
        "давно не виделись.",
        "здарова.",
        "ты как? я в порядке.",
        "о, привет. ну что, пошалим?",
        "здорово, братишка.",
        "ну наконец-то.",
    },
    hurt = {
        "ой!",
        "это было грубо.",
        "больно, вообще-то.",
        "хороший удар.",
        "ай! за что?",
        "ты чего дерёшься?",
        "это было невежливо.",
        "ну и хам.",
    },
    -- 🗡 KILL — теперь дерзкий
    kill = {
        "и всё?",
        "слишком просто.",
        "научись играть.",
        "следующий.",
        "и даже не вспотел.",
        "слабовато, честно.",
        "тренируйся ещё.",
        -- ✨ новые дерзкие
        "вы все здесь доходяги.",
        "и это ваш лучший боец?",
        "да я даже не старался.",
    },
    dodge = {
        "увернулся.",
        "мимо!",
        "не сегодня.",
        "слишком медленно.",
        "промазал.",
        "я даже не заметил.",
        "быстрее надо.",
        "неплохо, но нет.",
    },
    -- 😏 TAUNT — дерзкие насмешки
    taunt = {
        "у тебя всё получится.",
        "верю в тебя.",
        "не сдавайся, ладно?",
        "расслабься. это просто игра.",
        "давай, покажи класс.",
        "ты можешь больше.",
        -- ✨ новые дерзкие
        "вы все здесь доходяги.",
        "ну кто там следующий?",
        "я тут постою, вы пока разомнитесь.",
    },
    combo = {
        "двойной удар!",
        "а это тебе!",
        "вот так, да!",
        "неплохая комбинация.",
        "и всё-таки я лучше.",
        "бах-бах!",
        "держи-держи!",
        "двойная порция!",
    },
    -- 🏆 VICTORY — дерзкие
    victory = {
        "и это всё?",
        "я даже не устал.",
        "слабовато.",
        "попробуй ещё разок.",
        "ну... ожидал большего.",
        "тренируйся, малыш.",
        -- ✨ новые дерзкие
        "вы все здесь доходяги.",
        "даже не начал стараться.",
    },
    idle = {
        "ты тут?",
        "скучно...",
        "может, что-нибудь сделаем?",
        "не храпи, я слышу.",
        "я начинаю засыпать.",
        "может, пошалим?",
    },
    lowhp = {
        "ты в порядке?",
        "не умирай сейчас!",
        "подлечись, а?",
        "осторожнее.",
        "кажется, тебе нужна помощь.",
        "давай, соберись!",
    },
    spawnkill = {
        "ну и манеры.",
        "ты чего творишь?",
        "спавн-килл? серьёзно?",
        "это уже наглость.",
        "ты что, вообще без совести?",
    },
    attack = {
        "получай!",
        "вот тебе!",
        "и ещё разок.",
        "а я быстрее.",
        "ты промазал.",
        "и это всё, что ты можешь?",
        "слабенько.",
    },
}

-- ============================================================
--       ЗВУКИ
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
S.cooldowns.hurt = 3.0
S.cooldowns.lowhp = 8.0
S.cooldowns.idle = 30.0
S.cooldowns.greet = 5.0
S.ENABLED = true
S.lastCat = nil
S.lastCatTime = 0
S.lastSaid = nil
S.lastActivity = tick()

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
--       ПАНЕЛЬ ФРАЗ (своя)
-- ============================================================
local toastGui, toastContainer = nil, nil
local toastCount = 0

local CAT_STYLE = {
    death     = { icon = "💀", color = C3(255, 180, 180) },
    spawn     = { icon = "✨", color = C3(200, 220, 255) },
    greet     = { icon = "👋", color = C3(200, 255, 220) },
    hurt      = { icon = "💔", color = C3(255, 200, 140) },
    kill      = { icon = "🗡", color = C3(255, 140, 140) },
    dodge     = { icon = "🥷", color = C3(150, 220, 255) },
    taunt     = { icon = "😏", color = C3(180, 255, 200) },
    combo     = { icon = "🔥", color = C3(255, 240, 120) },
    victory   = { icon = "🏆", color = C3(200, 255, 200) },
    idle      = { icon = "💤", color = C3(200, 200, 240) },
    lowhp     = { icon = "❤️", color = C3(255, 150, 150) },
    spawnkill = { icon = "⚠️", color = C3(255, 120, 120) },
    attack    = { icon = "⚡", color = C3(255, 220, 140) },
    say       = { icon = "💬", color = C3(220, 220, 255) },
}

local function buildToastGui()
    if toastGui and toastGui.Parent then return end
    local parent = LP:FindFirstChildOfClass("PlayerGui")
    if not parent then return end
    toastGui = Instance.new("ScreenGui")
    toastGui.Name = "_OrbitSansToasts_" .. tostring(math.random(100000, 999999))
    toastGui.ResetOnSpawn = false
    toastGui.IgnoreGuiInset = true
    toastGui.DisplayOrder = 50
    toastGui.Parent = parent

    toastContainer = Instance.new("Frame")
    toastContainer.Name = "Container"
    toastContainer.AnchorPoint = Vector2.new(0.5, 1)
    toastContainer.Position = UDim2.new(0.5, 0, 1, -80)
    toastContainer.Size = UDim2.new(0, 400, 0, 200)
    toastContainer.BackgroundTransparency = 1
    toastContainer.Parent = toastGui

    local layout = Instance.new("UIListLayout", toastContainer)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
end

local function showToast(category, text)
    if not toastGui or not toastGui.Parent then buildToastGui() end
    if not toastContainer then return end

    local style = CAT_STYLE[category] or CAT_STYLE.say
    toastCount = toastCount + 1

    local slot = Instance.new("Frame")
    slot.Size = UDim2.new(1, -20, 0, 40)
    slot.BackgroundTransparency = 1
    slot.LayoutOrder = toastCount
    slot.Parent = toastContainer

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Position = UDim2.new(0, 0, 0, 12)
    frame.BackgroundColor3 = C3(20, 18, 32)
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Parent = slot

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = style.color
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 4, 1, -8)
    bar.Position = UDim2.new(0, 4, 0, 4)
    bar.BackgroundColor3 = style.color
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 2)

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 28, 1, 0)
    icon.Position = UDim2.new(0, 12, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = style.icon
    icon.TextColor3 = style.color
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 18
    icon.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -52, 1, 0)
    lbl.Position = UDim2.new(0, 44, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C3(235, 230, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()

    task.delay(2.8, function()
        if not slot.Parent then return end
        local out = TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0, 0, 0, -12), BackgroundTransparency = 1 })
        out:Play()
        out.Completed:Connect(function() pcall(function() slot:Destroy() end) end)
    end)

    local items = {}
    for _, ch in ipairs(toastContainer:GetChildren()) do
        if ch:IsA("Frame") then table.insert(items, ch) end
    end
    table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #items > 5 do
        local old = table.remove(items, 1)
        pcall(function() old:Destroy() end)
    end
end

-- ============================================================
--       ВСПЛЫВАЮЩИЙ ТЕКСТ В 3D
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
    pcall(function() TweenService:Create(lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play() end)

    task.delay(seconds, function()
        pcall(function() TweenService:Create(lbl, TweenInfo.new(0.4), { TextTransparency = 1 }):Play() end)
        task.wait(0.45)
        pcall(function() if anchor.Parent then anchor:Destroy() end end)
    end)
    S.liveTags[#S.liveTags + 1] = anchor
    Debris:AddItem(anchor, seconds + 1)
    return true
end

-- ============================================================
--       ГЛАВНАЯ ФУНКЦИЯ SAY
-- ============================================================
function S.say(category, force)
    if not S.ENABLED then return false end
    if ORBIT.mode ~= "sans" and not force then return false end
    category = category or "greet"
    local list = S.phrases[category] or S.phrases.greet
    if not list or #list == 0 then return false end

    local now = tick()
    local cd = S.cooldowns[category] or S.COOLDOWN_DEFAULT
    local last = S.cooldowns["_last_" .. category] or 0
    if not force and (now - last) < cd then return false end
    S.cooldowns["_last_" .. category] = now

    local text = list[math.random(1, #list)]
    S.lastCat = category
    S.lastSaid = text
    S.lastCatTime = now
    S.lastActivity = now

    pcall(S.playSound, category)
    showToast(category, text)

    if ORBIT.notify and ORBIT.mode == "sans" then
        local style = CAT_STYLE[category] or CAT_STYLE.say
        pcall(ORBIT.notify, (style.icon or "💀") .. " " .. text, style.color, 3)
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
    if toastContainer then toastContainer.Visible = S.ENABLED end
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
S.sayAttack  = function() return S.say("attack") end

-- ============================================================
--       ПУБЛИЧНЫЙ API
-- ============================================================
function S.on(eventName, data)
    S.lastActivity = tick()
    if eventName == "victory" or eventName == "protect" then
        return S.say("victory")
    elseif eventName == "attack" then
        return S.say("attack")
    elseif eventName == "dodge" then
        return S.say("dodge")
    elseif eventName == "kill" then
        return S.say("kill")
    elseif eventName == "idle" then
        return S.say("idle")
    elseif eventName == "greet" then
        return S.say("greet")
    elseif eventName == "hurt" then
        return S.say("hurt")
    elseif eventName == "combo" then
        return S.say("combo")
    elseif eventName == "spawnkill" then
        return S.say("spawnkill", true)
    end
    return false
end

function S.noteAttack()
    S.lastActivity = tick()
    return true
end

-- ============================================================
--       АВТОТРИГГЕРЫ
-- ============================================================
local hpConn, dieConn, charConn = nil, nil, nil
local lastHP = nil

local function detectEnemyNear()
    local c = LP.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not r then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local pr = p.Character:FindFirstChild("HumanoidRootPart")
            if pr and (pr.Position - r.Position).Magnitude < 15 then return true end
        end
    end
    return false
end

local function hookChar(char)
    if not char then return end
    if hpConn then pcall(function() hpConn:Disconnect() end); hpConn = nil end
    if dieConn then pcall(function() dieConn:Disconnect() end); dieConn = nil end

    task.wait(0.5)
    if ORBIT.mode == "sans" and S.ENABLED then pcall(S.say, "spawn", true) end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        char.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then hookChar(char) end
        end)
        return
    end

    lastHP = hum.Health

    dieConn = hum.Died:Connect(function()
        if ORBIT.mode == "sans" and S.ENABLED then
            pcall(S.say, "death", true)
        end
    end)

    hpConn = hum.HealthChanged:Connect(function(h)
        if not S.ENABLED or ORBIT.mode ~= "sans" then lastHP = h; return end
        local maxH = hum.MaxHealth > 0 and hum.MaxHealth or 100
        local ratio = h / maxH
        local drop = (lastHP or h) - h

        if h <= 0 then
            -- через Died
        elseif ratio < 0.25 and (tick() - (S.cooldowns["_last_lowhp"] or 0)) > 8 then
            pcall(S.say, "lowhp")
        elseif drop >= 1 then
            if drop >= 10 and detectEnemyNear() then
                pcall(S.say, "hurt")
            elseif drop >= 3 then
                pcall(S.say, "hurt")
            end
        end
        lastHP = h
    end)
end

if LP then
    if LP.Character then task.spawn(hookChar, LP.Character) end
    charConn = LP.CharacterAdded:Connect(function(c) task.spawn(hookChar, c) end)
end

-- таймер бездействия
task.spawn(function()
    while S.ready and ORBIT.sans == S do
        task.wait(5)
        if S.ENABLED and ORBIT.mode == "sans" then
            if tick() - S.lastActivity > 45 then
                pcall(S.say, "idle")
                S.lastActivity = tick()
            end
        end
    end
end)

-- хук на abilities.combo
task.spawn(function()
    while S.ready and ORBIT.sans == S do
        task.wait(0.5)
        if S.ENABLED and ORBIT.mode == "sans" and ORBIT.abilities then
            local ab = ORBIT.abilities
            if ab._sansHooked then break end
            if type(ab.combo) == "function" then
                local origCombo = ab.combo
                ab.combo = function(...)
                    local r = origCombo(...)
                    if r then pcall(S.say, "combo") end
                    return r
                end
                ab._sansHooked = true
            end
        end
    end
end)

-- ============================================================
--       ОЧИСТКА
-- ============================================================
function S.destroy()
    S.ready = false
    if hpConn then pcall(function() hpConn:Disconnect() end); hpConn = nil end
    if dieConn then pcall(function() dieConn:Disconnect() end); dieConn = nil end
    if charConn then pcall(function() charConn:Disconnect() end); charConn = nil end
    for _, anchor in ipairs(S.liveTags) do
        pcall(function() if anchor.Parent then anchor:Destroy() end end)
    end
    S.liveTags = {}
    if toastGui then pcall(function() toastGui:Destroy() end); toastGui = nil end
    toastContainer = nil
    if S.sound then
        pcall(function() S.sound:Stop() end)
        pcall(function() S.sound:Destroy() end)
        S.sound = nil
    end
end

local prevUnload = ORBIT.unload
ORBIT.unload = function()
    pcall(S.destroy)
    if prevUnload then pcall(prevUnload) end
end

-- ============================================================
--       ИНИЦИАЛИЗАЦИЯ
-- ============================================================
task.spawn(function()
    task.wait(1)
    buildToastGui()
    local total = 0
    for _, list in pairs(S.phrases) do total = total + #list end
    if ORBIT.notify then
        ORBIT.notify("💀 Санс v24.6 (" .. tostring(total) .. " фраз, работает везде)",
            C3(200, 220, 255), 3)
    end
end)

S.ready = true
ORBIT.sans = S

return true
