-- ОРБИТА v1.0 — HELPER (orbit_helper.lua)
-- Rule-based помощник: понимает простые русские фразы и сразу применяет настройки.
-- Не требует интернета, API-ключей, LLM. Работает офлайн за 1 кадр.
--
-- Примеры команд:
--   «красный» / «сделай радугу» / «цвет ледяной»
--   «медленнее» / «быстрее» / «х2 скорость»
--   «выше» / «ниже» / «в небо»
--   «ауру вкл» / «убери ауру» / «аура огонь»
--   «огонь» / «включи трейлы» / «пульсация вкл»
--   «череп» / «звезда» / «меч» / «скала»
--   «стиль огонь» / «стиль призрак» / «случайный стиль»
--   «все кольца» / «5 колец» / «только 1 кольцо»
--   «помощь» — показать список
--
-- Автор: ОРБИТА. Все идентификаторы латиницей.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (type(getgenv) == "function" and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Helper] ORBIT не найден!"); return end

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local rings    = ORBIT.rings
if not P or not SETTINGS or not rings then
    warn("[Orbit Helper] нужны p3 / p4")
    return
end

local H = {}
ORBIT.helper = H
ORBIT.helperOpen = function()
    if H.open then H.open() end
end

-- ============================================================
--       СЛОВАРИ КЛЮЧЕВЫХ СЛОВ
-- ============================================================
-- Цвета: список корней → точное имя в P.COLORS
local COLOR_KEYWORDS = {
    ["красн"]     = "КРАСНЫЙ",
    ["алый"]      = "АЛЫЙ",
    ["оранж"]     = "ОРАНЖЕВЫЙ",
    ["жёлт"]      = "ЖЁЛТЫЙ",
    ["желт"]      = "ЖЁЛТЫЙ",
    ["золот"]     = "ЗОЛОТОЙ",
    ["зелён"]     = "ЗЕЛЁНЫЙ",
    ["зелен"]     = "ЗЕЛЁНЫЙ",
    ["лайм"]      = "ЛАЙМ",
    ["мят"]       = "МЯТА",
    ["изумруд"]   = "ИЗУМРУД",
    ["голуб"]     = "ГОЛУБОЙ",
    ["лазур"]     = "ЛАЗУРЬ",
    ["бирюз"]     = "БИРЮЗОВЫЙ",
    ["син"]       = "СИНИЙ",
    ["сапфир"]    = "САПФИР",
    ["фиолет"]    = "ФИОЛЕТОВЫЙ",
    ["сирен"]     = "СИРЕНЕВЫЙ",
    ["пурпур"]    = "ПУРПУРНЫЙ",
    ["розов"]     = "РОЗОВЫЙ",
    ["малинов"]   = "МАЛИНОВЫЙ",
    ["бордо"]     = "БОРДО",
    ["коралл"]    = "КОРАЛЛ",
    ["огн"]       = "ОГОНЬ",
    ["лав"]       = "ЛАВА",
    ["бел"]       = "БЕЛЫЙ",
    ["серебр"]    = "СЕРЕБРЯНЫЙ",
    ["сер"]       = "СЕРЫЙ",
    ["чёрн"]      = "ЧЁРНЫЙ",
    ["черн"]      = "ЧЁРНЫЙ",
    ["лёд"]       = "ЛЁД",
    ["лед"]       = "ЛЁД",
    ["радуг"]     = "РАДУГА",
}

-- Стили
local STYLE_KEYWORDS = {
    ["огн"]      = "🔥 Огненный",
    ["лед"]      = "❄️ Ледяной",
    ["лёд"]      = "❄️ Ледяной",
    ["королев"]  = "👑 Королевский",
    ["золот"]    = "👑 Королевский",
    ["радуг"]    = "🌈 Радуга-вихрь",
    ["призрак"]  = "👻 Призрак",
    ["скал"]     = "🪨 Скала-шоу",
    ["случайн"]  = "🎲 Случайный стиль",
    ["рандом"]   = "🎲 Случайный стиль",
}

-- Фигуры (корень → имя в SHAPE_PRESETS)
local SHAPE_KEYWORDS = {
    ["блок"]     = "БЛОК",
    ["куб"]      = "БЛОК",
    ["шар"]      = "ШАР",
    ["сфер"]     = "ШАР",
    ["цилиндр"]  = "ЦИЛИНДР",
    ["клин"]     = "КЛИН",
    ["треуголь"] = "ТРЕУГОЛЬНИК",
    ["звезд"]    = "ЗВЕЗДА",
    ["крест"]    = "КРЕСТ",
    ["ромб"]     = "РОМБ",
    ["кост"]     = "КОСТЬ",
    ["пирамид"]  = "ПИРАМИДА",
    ["спирал"]   = "СПИРАЛЬ",
    ["череп"]    = "ЧЕРЕП",
    ["рук"]      = "РУКА",
    ["голов"]    = "ГОЛОВА",
    ["сердц"]    = "СЕРДЦЕ",
    ["крыл"]     = "КРЫЛЬЯ",
    ["щупал"]    = "ЩУПАЛЬЦЕ",
    ["скал"]     = "СКАЛА",
    ["меч"]      = "МЕЧ",
    ["щит"]      = "ЩИТ",
    ["глаз"]     = "ГЛАЗ",
    ["инь"]      = "ИНЬ-ЯН",
    ["молни"]    = "МОЛНИЯ",
    ["гастер"]   = "ГАСТЕР БЛАСТЕР",
}

-- ============================================================
--       УТИЛИТЫ
-- ============================================================
local function lower(s)
    -- кириллица + латиница, ASCII-safe в рамках текущего окружения
    local out = {}
    for _, code in utf8.codes(s or "") do
        if code >= 0x410 and code <= 0x42F then code = code + 32
        elseif code == 0x401 or code == 0x451 then code = 0x435
        elseif code >= 65 and code <= 90 then code = code + 32 end
        out[#out + 1] = utf8.char(code)
    end
    return table.concat(out)
end

local function startsWith(s, prefix)
    return s:sub(1, #prefix) == prefix
end

local function containsWord(text, root)
    return string.find(text, root, 1, true) ~= nil
end

local function idxByColorName(name)
    for i, c in ipairs(P.COLORS) do
        if c.name == name then return i end
    end
    return nil
end

local function idxByShapeName(name)
    for i, sp in ipairs(ORBIT.SHAPE_PRESETS) do
        if sp.name == name then return i end
    end
    return nil
end

local function findColor(text)
    for root, name in pairs(COLOR_KEYWORDS) do
        if containsWord(text, root) then
            local idx = idxByColorName(name)
            if idx then return idx, name end
        end
    end
    return nil
end

local function findStyle(text)
    for root, name in pairs(STYLE_KEYWORDS) do
        if containsWord(text, root) then return name end
    end
    return nil
end

local function findShape(text)
    for root, name in pairs(SHAPE_KEYWORDS) do
        if containsWord(text, root) then
            local idx = idxByShapeName(name)
            if idx then return idx, name end
        end
    end
    return nil
end

local function applyColorByName(name)
    local idx = idxByColorName(name)
    if not idx then return false, "Цвет не найден: " .. name end
    P.colorIndex = idx
    if ORBIT.applyColor then pcall(ORBIT.applyColor) end
    if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
    return true, "🎨 Цвет: " .. name
end

local function applyShapeByName(name)
    local idx = idxByShapeName(name)
    if not idx then return false, "Фигура не найдена: " .. name end
    ORBIT.shapeIndex = idx
    P.shapeCategoryIndex = 1
    P.formModeIndex = 1
    if ORBIT.applyShapes then pcall(ORBIT.applyShapes) end
    if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
    return true, "🔷 Фигура: " .. name
end

-- ============================================================
--       ОСНОВНОЙ ПАРСЕР
-- ============================================================
-- Возвращает: true, "что сделали"
-- или false, "не понял"
function H.interpret(rawText)
    if type(rawText) ~= "string" then return false, "Пустой запрос" end
    local t = lower(rawText)
    if #t < 2 then return false, "Слишком коротко" end

    -- ---------- СПРАВКА ----------
    if containsWord(t, "помощь") or containsWord(t, "команд") or t == "help" or t == "?" then
        return true, H.showHelp and "📖 Список команд открыт" or "помощь"
    end

    -- ---------- СТИЛЬ ----------
    if containsWord(t, "стиль") or containsWord(t, "образ") then
        local styleName = findStyle(t)
        if styleName and ORBIT.ui and ORBIT.ui.applyStyleByName then
            ORBIT.ui.applyStyleByName(styleName)
            return true, "🎭 Стиль: " .. styleName
        end
    end
    -- Без слова «стиль», если встретили имя стиля и «хочу/поставь/вруби»
    if containsWord(t, "хочу") or containsWord(t, "поставь") or containsWord(t, "вруб") or containsWord(t, "сделай") then
        local styleName = findStyle(t)
        if styleName and ORBIT.ui and ORBIT.ui.applyStyleByName then
            ORBIT.ui.applyStyleByName(styleName)
            return true, "🎭 Стиль: " .. styleName
        end
    end

    -- ---------- СКОРОСТЬ ----------
    local speedRoots = {
        ["быстрее"] = 1, ["ускорь"] = 1, ["ускор"] = 1,
        ["медленнее"] = -1, ["замедл"] = -1, ["медл"] = -1,
    }
    for root, dir in pairs(speedRoots) do
        if containsWord(t, root) then
            local cur = P.speedIndex or 2
            local newIdx = math.clamp(cur + dir, 1, #P.SPEED)
            P.speedIndex = newIdx
            SETTINGS.SpeedMultiplier = P.SPEED[newIdx].value
            return true, "⚡ Скорость: " .. P.SPEED[newIdx].name
        end
    end
    -- «х2», «х5», «2x», «в 3 раза»
    do
        local m = t:match("[хx]%s*(%d+)") or t:match("в%s*(%d+)%s*раз")
        if m then
            local n = tonumber(m)
            if n then
                local best, bd = 1, math.huge
                for i, s in ipairs(P.SPEED) do
                    local d = math.abs(s.value - n)
                    if d < bd then best, bd = i, d end
                end
                P.speedIndex = best
                SETTINGS.SpeedMultiplier = P.SPEED[best].value
                return true, "⚡ Скорость: " .. P.SPEED[best].name
            end
        end
    end

    -- ---------- ВЫСОТА ----------
    if containsWord(t, "выше") or containsWord(t, "высок") or containsWord(t, "небо") or containsWord(t, "космос") then
        local cur = P.heightIndex or 4
        local newIdx = math.clamp(cur + 1, 1, #P.HEIGHT)
        P.heightIndex = newIdx
        return true, "⬆️ Высота: " .. P.HEIGHT[newIdx].name
    end
    if containsWord(t, "ниже") or containsWord(t, "низ") or containsWord(t, "в ног") or containsWord(t, "приземл") then
        local cur = P.heightIndex or 4
        local newIdx = math.clamp(cur - 1, 1, #P.HEIGHT)
        P.heightIndex = newIdx
        return true, "⬇️ Высота: " .. P.HEIGHT[newIdx].name
    end

    -- ---------- АУРА ----------
    local auraOff = containsWord(t, "убери") or containsWord(t, "выключ") or containsWord(t, "отключ") or containsWord(t, "убрать")
    local auraOn  = containsWord(t, "включ") or containsWord(t, "вруб") or containsWord(t, "поставь") or containsWord(t, "добавь")
    if containsWord(t, "аур") then
        if auraOff then
            SETTINGS.AuraEnabled = false
            if ORBIT.auraFolder then pcall(function() ORBIT.auraFolder:Destroy() end); ORBIT.auraFolder = nil end
            return true, "🌀 Аура: ВЫКЛ"
        elseif auraOn or true then
            SETTINGS.AuraEnabled = true
            if not (SETTINGS.AuraRing or SETTINGS.AuraParticles or SETTINGS.AuraShapes) then
                SETTINGS.AuraRing = true
                SETTINGS.AuraParticles = true
                SETTINGS.AuraShapes = true
            end
            if ORBIT.setupAura then pcall(ORBIT.setupAura) end
            return true, "🌀 Аура: ВКЛ"
        end
    end

    -- ---------- ОГОНЬ ----------
    if containsWord(t, "огон") or containsWord(t, "огня") or containsWord(t, "поджог") then
        if auraOff then
            SETTINGS.FireEnabled = false
            if ORBIT.fireFolder then pcall(function() ORBIT.fireFolder:Destroy() end); ORBIT.fireFolder = nil end
            return true, "🔥 Огонь: ВЫКЛ"
        else
            SETTINGS.FireEnabled = true
            if ORBIT.setupFire then pcall(ORBIT.setupFire) end
            return true, "🔥 Огонь: ВКЛ"
        end
    end

    -- ---------- ТРЕЙЛЫ / ПУЛЬСАЦИЯ / ВОЛНА / ВЗРЫВ ----------
    if containsWord(t, "трейл") then
        local v = not auraOff
        SETTINGS.TrailEnabled = v
        if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
        return true, "🌠 Трейлы: " .. (v and "ВКЛ" or "ВЫКЛ")
    end
    if containsWord(t, "пульс") then
        local v = not auraOff
        SETTINGS.PulseEnabled = v
        return true, "💓 Пульсация: " .. (v and "ВКЛ" or "ВЫКЛ")
    end
    if containsWord(t, "волн") then
        local v = not auraOff
        SETTINGS.WaveEnabled = v
        return true, "🌊 Волна: " .. (v and "ВКЛ" or "ВЫКЛ")
    end
    if containsWord(t, "взрыв") or containsWord(t, "взорви") then
        local v = not auraOff
        SETTINGS.ExplosionEnabled = v
        return true, "💥 Взрыв: " .. (v and "ВКЛ" or "ВЫКЛ")
    end
    if containsWord(t, "свет") and not containsWord(t, "аур") then
        local v = not auraOff
        SETTINGS.LightEnabled = v
        if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
        return true, "💡 Свет: " .. (v and "ВКЛ" or "ВЫКЛ")
    end

    -- ---------- КОЛЬЦА ----------
    if containsWord(t, "все кольц") or containsWord(t, "все кольца") or containsWord(t, "5 коль") or containsWord(t, "пять коль") then
        for ri = 2, 5 do ORBIT.setRingEnabled(ri, true) end
        return true, "⭕ Включены все 5 колец"
    end
    if containsWord(t, "1 кольц") or containsWord(t, "одно кольц") or containsWord(t, "одно кольцо") then
        for ri = 2, 5 do ORBIT.setRingEnabled(ri, false) end
        return true, "⭕ Оставлено только 1 кольцо"
    end
    -- «3 кольца», «4 кольца»
    do
        local m = t:match("(%d+)%s*кольц")
        if m then
            local n = math.clamp(tonumber(m) or 1, 1, 5)
            for ri = 2, 5 do ORBIT.setRingEnabled(ri, ri <= n) end
            return true, "⭕ Колец включено: " .. n
        end
    end

    -- ---------- ФИГУРА ----------
    local shapeIdx, shapeName = findShape(t)
    if shapeIdx and shapeName then
        ORBIT.shapeIndex = shapeIdx
        if ORBIT.applyShapes then pcall(ORBIT.applyShapes) end
        if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
        return true, "🔷 Фигура: " .. shapeName
    end

    -- ---------- ЦВЕТ ----------
    local colIdx, colName = findColor(t)
    if colIdx and colName then
        P.colorIndex = colIdx
        if ORBIT.applyColor then pcall(ORBIT.applyColor) end
        if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
        return true, "🎨 Цвет: " .. colName
    end

    -- ---------- ТЕМП / СЛОЖНОСТЬ / НЕЗНАЮ ----------
    return false, "🤔 Не понял. Скажи «помощь» для списка команд."
end

-- ============================================================
--       ПОКАЗ КОМАНД
-- ============================================================
function H.helpText()
    return table.concat({
        "🤖  КОМАНДЫ ПОМОЩНИКА",
        "",
        "🎨 Цвет: красный, синий, радуга, огонь, лёд, золотой...",
        "🔷 Фигура: шар, звезда, меч, череп, скала, сердце...",
        "🎭 Стиль: стиль огонь, стиль призрак, случайный стиль",
        "⚡ Скорость: быстрее / медленнее / х2 / в 3 раза",
        "⬆️ Высота: выше / ниже / в небо / в ноги",
        "🌀 Аура: ауру вкл / убери ауру",
        "🔥 Эффекты: огонь / трейлы вкл / пульсация / волна / взрыв",
        "⭕ Кольца: все кольца / 3 кольца / только 1 кольцо",
        "💡 Свет / тени / имена — прямо так",
        "",
        "Просто напиши фразу целиком:",
        "«хочу огненный стиль»  «сделай радугу»  «поставь череп»",
    }, "\n")
end

-- ============================================================
--       UI ПАНЕЛЬ
-- ============================================================
local panel = nil

function H.open()
    if not ORBIT.ui or not ORBIT.ui.screenGui then return end
    if panel and panel.Parent then panel.Visible = true; return end

    local screenGui = ORBIT.ui.screenGui
    local IS_MOBILE = (ORBIT.PLATFORM == "mobile")
    local W = IS_MOBILE and 330 or 460
    local Hh = IS_MOBILE and 480 or 420

    local win = Instance.new("Frame")
    win.Name = "_OrbitHelper"
    win.Size = UDim2.new(0, W, 0, Hh)
    win.Position = UDim2.new(0.5, -W/2, 0.5, -Hh/2)
    win.BackgroundColor3 = Color3.fromRGB(22, 18, 38)
    win.BorderSizePixel = 0
    win.ZIndex = 70
    win.Active = true
    win.Parent = screenGui
    panel = win
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", win)
    st.Color = Color3.fromRGB(140, 120, 255); st.Thickness = 1.5
    if ORBIT.ui.fitToScreen then pcall(ORBIT.ui.fitToScreen, win, W, Hh) end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 30)
    title.Position = UDim2.new(0, 14, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "🤖 ПОМОЩНИК"
    title.TextColor3 = Color3.fromRGB(220, 220, 255)
    title.Font = Enum.Font.GothamBold; title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 71; title.Parent = win

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -38, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 16
    closeBtn.Text = "✖"; closeBtn.ZIndex = 71
    closeBtn.Parent = win
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    closeBtn.MouseButton1Down:Connect(function() win.Visible = false end)
    closeBtn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then win.Visible = false end end)
    closeBtn.Activated:Connect(function() win.Visible = false end)

    -- Поле ввода
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -28, 0, 40)
    input.Position = UDim2.new(0, 14, 0, 42)
    input.BackgroundColor3 = Color3.fromRGB(35, 30, 55)
    input.TextColor3 = Color3.fromRGB(240, 235, 255)
    input.Font = Enum.Font.GothamBold; input.TextSize = 13
    input.PlaceholderText = "Напиши: «сделай радугу» или «стиль огонь»..."
    input.PlaceholderColor3 = Color3.fromRGB(140, 130, 180)
    input.Text = ""
    input.ClearTextOnFocus = false
    input.ZIndex = 71
    input.Parent = win
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 10)
    local pad = Instance.new("UIPadding", input)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)

    -- Кнопка «Выполнить»
    local runBtn = Instance.new("TextButton")
    runBtn.Size = UDim2.new(1, -28, 0, 38)
    runBtn.Position = UDim2.new(0, 14, 0, 90)
    runBtn.BackgroundColor3 = Color3.fromRGB(70, 100, 160)
    runBtn.TextColor3 = Color3.fromRGB(230, 240, 255)
    runBtn.Font = Enum.Font.GothamBold; runBtn.TextSize = 13
    runBtn.Text = "▶  ВЫПОЛНИТЬ"
    runBtn.ZIndex = 71
    runBtn.Parent = win
    Instance.new("UICorner", runBtn).CornerRadius = UDim.new(0, 10)

    -- Лог (последний ответ)
    local logLbl = Instance.new("TextLabel")
    logLbl.Size = UDim2.new(1, -28, 0, 44)
    logLbl.Position = UDim2.new(0, 14, 0, 134)
    logLbl.BackgroundColor3 = Color3.fromRGB(15, 12, 26)
    logLbl.BackgroundTransparency = 0.1
    logLbl.BorderSizePixel = 0
    logLbl.Text = "Готов помочь. Напиши команду или выбери пресет ниже."
    logLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    logLbl.Font = Enum.Font.Gotham
    logLbl.TextSize = 11
    logLbl.TextWrapped = true
    logLbl.TextXAlignment = Enum.TextXAlignment.Left
    logLbl.TextYAlignment = Enum.TextYAlignment.Top
    logLbl.ZIndex = 71
    logLbl.Parent = win
    Instance.new("UICorner", logLbl).CornerRadius = UDim.new(0, 8)
    local lp = Instance.new("UIPadding", logLbl)
    lp.PaddingLeft = UDim.new(0, 8); lp.PaddingRight = UDim.new(0, 8)
    lp.PaddingTop = UDim.new(0, 4); lp.PaddingBottom = UDim.new(0, 4)

    local function click(fn)
        return function(btn)
            local deb = false
            local function call()
                if deb then return end
                deb = true
                task.delay(0.12, function() deb = false end)
                if ORBIT.playClick then pcall(ORBIT.playClick) end
                pcall(fn)
            end
            btn.MouseButton1Down:Connect(call)
            btn.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.Touch then call() end
            end)
            btn.Activated:Connect(call)
        end
    end

    local function doRun()
        local txt = input.Text or ""
        if txt == "" then
            logLbl.Text = "🤔 Пустой запрос. Напиши что-нибудь."
            return
        end
        local ok, msg = H.interpret(txt)
        logLbl.Text = (ok and "✅ " or "⚠️ ") .. tostring(msg)
        if ok and ORBIT.notify then
            ORBIT.notify("🤖 " .. tostring(msg), Color3.fromRGB(180, 220, 255), 3)
        end
        if ok then input.Text = "" end
    end

    click(doRun)(runBtn)
    input.FocusLost:Connect(function(enter)
        if enter then doRun() end
    end)

    -- Ряд быстрых кнопок-пресетов
    local y0 = 186
    local BTN_H = 30
    local presetTitle = Instance.new("TextLabel")
    presetTitle.Size = UDim2.new(1, -28, 0, 16)
    presetTitle.Position = UDim2.new(0, 14, 0, y0)
    presetTitle.BackgroundTransparency = 1
    presetTitle.Text = "⚡ БЫСТРЫЕ"
    presetTitle.TextColor3 = Color3.fromRGB(180, 200, 255)
    presetTitle.Font = Enum.Font.GothamBold; presetTitle.TextSize = 11
    presetTitle.TextXAlignment = Enum.TextXAlignment.Left
    presetTitle.ZIndex = 71; presetTitle.Parent = win

    y0 = y0 + 20
    local presets = {
        {"🔥 Огненный",  "хочу огненный стиль"},
        {"👻 Призрак",   "стиль призрак"},
        {"🌈 Радуга",    "сделай радугу"},
        {"❄️ Ледяной",   "стиль лёд"},
        {"👑 Королев.",  "стиль золотой"},
        {"🪨 Скала",     "поставь скала"},
        {"⭐ Звёзды",    "фигура звезда"},
        {"💀 Череп",     "фигура череп"},
        {"⚡ Быстрее",   "быстрее"},
        {"🐢 Медленнее", "медленнее"},
        {"⬆️ Выше",      "выше"},
        {"⬇️ Ниже",      "ниже"},
        {"🌀 Аура ВКЛ",  "ауру вкл"},
        {"🚫 Аура ВЫКЛ", "убери ауру"},
        {"⭕ 5 колец",   "все кольца"},
        {"1️⃣ 1 кольцо", "только 1 кольцо"},
    }

    local cols = 2
    local cw = (W - 28 - (cols - 1) * 6) / cols
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -28, 1, -(y0 + 8))
    scroll.Position = UDim2.new(0, 14, 0, y0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(150, 130, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 70
    scroll.Parent = win

    local grid = Instance.new("UIGridLayout", scroll)
    grid.CellSize = UDim2.new(0, cw, 0, BTN_H)
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.SortOrder = Enum.SortOrder.LayoutOrder

    for i, p in ipairs(presets) do
        local b = Instance.new("TextButton")
        b.LayoutOrder = i
        b.BackgroundColor3 = Color3.fromRGB(50, 45, 80)
        b.TextColor3 = Color3.fromRGB(225, 220, 255)
        b.Font = Enum.Font.GothamBold; b.TextSize = 11
        b.Text = p[1]
        b.ZIndex = 71
        b.Parent = scroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        local phrase = p[2]
        click(function()
            input.Text = phrase
            doRun()
        end)(b)
    end
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
H.showHelp = function()
    H.open()
    if ORBIT.notify then
        ORBIT.notify("📖 Смотри окно помощника", Color3.fromRGB(200, 220, 255), 2)
    end
end

-- Хук для того, чтобы p4 мог вызвать applyStyleByName
if not ORBIT.ui then ORBIT.ui = {} end
if not ORBIT.ui.applyStyleByName then
    -- простая реализация: применяем через интерпретатор
    ORBIT.ui.applyStyleByName = function(name)
        if not name then return false end
        local t = lower(name)
        -- найдём в STYLE_KEYWORDS
        for root, styleName in pairs(STYLE_KEYWORDS) do
            if containsWord(t, root) then
                -- вместо полного applyStyle — эмулируем через стилевые ключи
                -- (в p4 уже есть applyStyle, но он приватен; здесь — общий путь через интерпретатор)
                H.interpret("стиль " .. tostring(styleName))
                return true
            end
        end
        return false
    end
end

if ORBIT.notify then
    ORBIT.notify("🤖 Помощник v1.0 загружен (команда «помощь»)", Color3.fromRGB(200, 220, 255), 3)
end
warn("[Orbit Helper v1.0] Загружен ✅")
return true
