-- ОРБИТА v23.8 — SHARE MODULE (orbit_share.lua)
-- Модуль обмена фигурами, сохранениями и настройками между игроками.
--
-- ФОРМАТ строки:
--   ORBIT1|SH|<base64>            фигура из 2D/3D редактора
--   ORBIT1|SV|<имя>|<base64>      именованное сохранение (набор настроек)
--   ORBIT1|PR|<base64>            текущие настройки (пресет без имени)
--
-- API:
--   ORBIT.share.encodeShape(shape)         -> строка
--   ORBIT.share.encodeSave(name)           -> строка
--   ORBIT.share.encodeCurrentSettings()    -> строка
--   ORBIT.share.decode(text)               -> {kind,name,data} | nil,err
--   ORBIT.share.copy(text)                 -> true | false,err
--   ORBIT.share.paste()                    -> text | nil,err
--   ORBIT.share.open()                     -> открыть UI панель
--   ORBIT.share.openImport(text)           -> открыть UI панель сразу с текстом на импорт
--   ORBIT.share.upload(text)               -> url | nil,err  (paste.rs)
--
-- ВАЖНО: все идентификаторы латиницей.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (type(getgenv) == "function" and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Share] ORBIT не найден!"); return end

local HttpService = ORBIT.HttpService
if not HttpService then
    warn("[Orbit Share] Нет HttpService!")
    return
end

local S = {}
ORBIT.share = S

-- ============================================================
--       ВЕРСИЯ / КОНСТАНТЫ
-- ============================================================
local PREFIX    = "ORBIT1|"
local MAX_LEN   = 200000          -- защита от гигантских строк
local MAX_PIX   = 24              -- максимальная сетка 2D
local MIN_PIX   = 8               -- минимальная
local MAX_GRID3 = 64              -- максимальный куб 3D (v23.10: поднято с 8)
local MIN_GRID3 = 2
local MAX_BLOCKS3 = 5000          -- лимит блоков в 3D (v23.10: поднято с 1500)
local MAX_NAME_LEN = 32

-- ============================================================
--       БАЗА64 (встроенная в HttpService)
-- ============================================================
local function b64Encode(str)
    local ok, res = pcall(function() return HttpService:Base64Encode(str) end)
    if ok then return res end
    return nil
end
local function b64Decode(str)
    local ok, res = pcall(function() return HttpService:Base64Decode(str) end)
    if ok then return res end
    return nil
end

-- ============================================================
--       УПАКОВКА
-- ============================================================
-- Общая упаковка: kind + payload (table) + опциональное имя
local function pack(kind, payload, extraName)
    local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok or not json then return nil, "Ошибка упаковки" end
    local b64 = b64Encode(json)
    if not b64 then return nil, "Ошибка base64" end
    if kind == "SV" and extraName then
        -- имя санитайзим: без | и переводов строк
        local safe = tostring(extraName):gsub("[|%c]", "_"):sub(1, MAX_NAME_LEN)
        return PREFIX .. "SV|" .. safe .. "|" .. b64
    end
    return PREFIX .. kind .. "|" .. b64
end

-- ============================================================
--       ВАЛИДАЦИЯ
-- ============================================================
-- Санитайзер 2D-фигуры: { pixels = {{0..24}}, grid = 16 }
local function sanitize2D(data)
    if type(data) ~= "table" then return nil, "Нет данных" end
    local grid = tonumber(data.grid) or #(data.pixels or {})
    if grid < MIN_PIX or grid > MAX_PIX then return nil, "Неверный размер сетки" end
    if type(data.pixels) ~= "table" then return nil, "Нет pixels" end
    local out = {}
    for r = 1, grid do
        local row = data.pixels[r]
        if type(row) ~= "table" then return nil, "Битая строка " .. r end
        out[r] = {}
        for c = 1, grid do
            local v = tonumber(row[c]) or 0
            if v < 0 then v = 0 end
            if v > 24 then v = 24 end
            out[r][c] = math.floor(v)
        end
    end
    local name = tostring(data.name or "ЧУЖАЯ"):gsub("[|%c]", "_"):sub(1, MAX_NAME_LEN)
    return { type = "2D", grid = grid, pixels = out, name = name }
end

-- Санитайзер 3D-фигуры: { blocks = {{x,y,z,r,g,b}}, N = 6 }
local function sanitize3D(data)
    if type(data) ~= "table" then return nil, "Нет данных" end
    local N = tonumber(data.N) or 6
    if N < MIN_GRID3 or N > MAX_GRID3 then return nil, "Неверный размер 3D" end
    if type(data.blocks) ~= "table" then return nil, "Нет blocks" end
    if #data.blocks > MAX_BLOCKS3 then return nil, "Слишком много блоков" end
    local out = {}
    for i, b in ipairs(data.blocks) do
        if type(b) ~= "table" then return nil, "Битый блок " .. i end
        local x = math.floor(tonumber(b.x) or 0)
        local y = math.floor(tonumber(b.y) or 0)
        local z = math.floor(tonumber(b.z) or 0)
        if x < 1 or x > N or y < 1 or y > N or z < 1 or z > N then
            return nil, "Блок вне сетки"
        end
        local r = math.clamp(tonumber(b.r) or 1, 0, 1)
        local g = math.clamp(tonumber(b.g) or 1, 0, 1)
        local bcol = math.clamp(tonumber(b.b) or 1, 0, 1)
        out[#out + 1] = { x = x, y = y, z = z, r = r, g = g, b = bcol }
    end
    if #out == 0 then return nil, "Пустая фигура" end
    local name = tostring(data.name or "ЧУЖАЯ_3D"):gsub("[|%c]", "_"):sub(1, MAX_NAME_LEN)
    return { type = "3D", N = N, blocks = out, name = name }
end

-- ============================================================
--       ENCODE
-- ============================================================
function S.encodeShape(shape)
    if type(shape) ~= "table" then return nil, "Нет фигуры" end
    -- Определяем: 2D или 3D
    if shape.is3D or shape.blocks then
        local clean = sanitize3D(shape)
        if not clean then return nil, "Плохие данные 3D" end
        return pack("SH", clean)
    elseif shape.pixels then
        local clean = sanitize2D(shape)
        if not clean then return nil, "Плохие данные 2D" end
        return pack("SH", clean)
    end
    return nil, "Неизвестный формат"
end

function S.encodeSave(name)
    if not name or name == "" then return nil, "Пустое имя" end
    if not ORBIT.SAVES or not ORBIT.SAVES[name] then return nil, "Нет такого сохранения" end
    local entry = ORBIT.SAVES[name]
    local payload = {
        savedAt  = tonumber(entry.time) or os.time(),
        appVer   = ORBIT.version or "?",
        data     = entry.data,   -- уже энцифрованный дамп (см. p3 collectSaveData)
    }
    return pack("SV", payload, name)
end

-- Текущие настройки — «пресет без имени» (те же данные, что и в автослот)
function S.encodeCurrentSettings()
    if not ORBIT.collectSaveData then
        -- p3 не экспортирует collectSaveData наружу — используем приватный путь через saveSettings+readfile
        -- Проще: если есть ORBIT.saveNamed, создаём временное сохранение? Нет.
        -- Фолбэк: пробуем через ORBIT.saveSettings и читаем файл.
    end
    -- Пробуем получить «сырой» дамп через p3 (если экспортирован)
    local collector = ORBIT.collectSaveDataForShare
    if type(collector) ~= "function" then
        return nil, "Обновление p3 не установлено (нет collectSaveDataForShare)"
    end
    local ok, data = pcall(collector)
    if not ok or not data then return nil, "Не удалось собрать настройки" end
    -- кодируем цвета/векторы тем же способом, что p3 (или просто JSON их съест?)
    -- JSONEncode не умеет Color3/Vector3 => нужен энкодер. Он есть в p3, но не экспортирован.
    -- Значит, требуем от p3 экспорт `encodeSettingsForShare`.
    local enc = ORBIT.encodeSettingsForShare
    if type(enc) ~= "function" then
        return nil, "Обновление p3 не установлено (нет encodeSettingsForShare)"
    end
    local ok2, encData = pcall(enc, data)
    if not ok2 or not encData then return nil, "Ошибка сериализации" end
    return pack("PR", { savedAt = os.time(), appVer = ORBIT.version or "?", data = encData })
end

-- ============================================================
--       DECODE
-- ============================================================
function S.decode(text)
    if type(text) ~= "string" then return nil, "Не строка" end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if #text < 12 or #text > MAX_LEN then return nil, "Неверная длина" end
    if text:sub(1, #PREFIX) ~= PREFIX then
        return nil, "Это не строка ОРБИТЫ (нет метки)"
    end
    local body = text:sub(#PREFIX + 1)
    local kind, rest = body:match("^(%a%a)|(.+)$")
    if not kind then return nil, "Повреждённая строка" end

    local name, b64
    if kind == "SV" then
        name, b64 = rest:match("^([^|]+)|(.+)$")
        if not b64 then return nil, "Нет данных" end
    else
        b64 = rest
    end

    local json = b64Decode(b64)
    if not json then return nil, "Ошибка base64" end
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or not data then return nil, "Повреждённые данные (JSON)" end

    if kind == "SH" then
        local clean
        if data.type == "3D" or data.blocks then
            local c, err = sanitize3D(data)
            if not c then return nil, err or "Плохие 3D данные" end
            clean = c
        else
            local c, err = sanitize2D(data)
            if not c then return nil, err or "Плохие 2D данные" end
            clean = c
        end
        return { kind = "SH", data = clean, name = clean.name }
    elseif kind == "SV" or kind == "PR" then
        if type(data) ~= "table" or type(data.data) ~= "table" then
            return nil, "Повреждённые данные сохранения"
        end
        return {
            kind = kind,
            name = name or (kind == "PR" and "Пресет" or "Сохранение"),
            savedAt = tonumber(data.savedAt) or 0,
            appVer  = tostring(data.appVer or "?"),
            data    = data.data,
        }
    end
    return nil, "Неизвестный тип: " .. kind
end

-- ============================================================
--       БУФЕР ОБМЕНА
-- ============================================================
local function hasSetClipboard()  return type(setclipboard) == "function" end
local function hasGetClipboard()  return type(getclipboard) == "function" end

function S.copy(text)
    if not text or #text < 6 then return false, "Пустая строка" end
    if not hasSetClipboard() then return false, "Буфер обмена недоступен" end
    local ok = pcall(setclipboard, text)
    if ok then return true end
    return false, "Ошибка записи в буфер"
end

function S.paste()
    if not hasGetClipboard() then return nil, "Буфер обмена недоступен" end
    local ok, txt = pcall(getclipboard)
    if not ok or type(txt) ~= "string" then return nil, "Ошибка чтения" end
    return txt
end

-- ============================================================
--       ЗАГРУЗКА НА paste.rs (опционально)
-- ============================================================
local function httpPost(url, body)
    -- Пробуем разные API: request (syn/Delta), http_request, HttpService (редко для POST)
    if type(request) == "function" then
        local ok, res = pcall(request, {
            Url = url, Method = "POST", Body = body,
            Headers = { ["Content-Type"] = "text/plain" },
        })
        if ok and type(res) == "table" then
            if res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300 then
                return res.Body or ""
            end
            return nil, "HTTP " .. tostring(res.StatusCode)
        end
    end
    if type(http_request) == "function" then
        local ok, res = pcall(http_request, {
            Url = url, Method = "POST", Body = body,
        })
        if ok and type(res) == "table" then
            return res.Body or ""
        end
    end
    return nil, "Нет HTTP-API (нужен request или http_request)"
end

function S.upload(text)
    if not text or #text < 6 then return nil, "Пустая строка" end
    local body, err = httpPost("https://paste.rs/", text)
    if not body then return nil, err or "Ошибка загрузки" end
    body = body:gsub("%s+", "")
    if body:match("^https?://") then return body end
    return nil, "Плохой ответ сервера"
end

-- ============================================================
--       UI ПАНЕЛЬ
-- ============================================================
local uiPanel = nil

local function ensureUI()
    if not ORBIT.ui or not ORBIT.ui.screenGui then return nil end
    if uiPanel and uiPanel.Parent then return uiPanel end

    local IS_MOBILE = (ORBIT.PLATFORM == "mobile")
    local screenGui = ORBIT.ui.screenGui
    local W = IS_MOBILE and 340 or 520
    local H = IS_MOBILE and 460 or 420

    local win = Instance.new("Frame")
    win.Name = "_OrbitShareWindow"
    win.Size = UDim2.new(0, W, 0, H)
    win.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    win.BackgroundColor3 = Color3.fromRGB(20, 16, 34)
    win.BorderSizePixel = 0
    win.ZIndex = 60
    win.Visible = false
    win.Active = true
    win.Parent = screenGui
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", win)
    stroke.Color = Color3.fromRGB(160, 130, 255)
    stroke.Thickness = 1.5
    if ORBIT.ui.fitToScreen then pcall(ORBIT.ui.fitToScreen, win, W, H) end

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 26)
    title.Position = UDim2.new(0, 14, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "🔗  ПОДЕЛИТЬСЯ / ИМПОРТ"
    title.TextColor3 = Color3.fromRGB(230, 210, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 61
    title.Parent = win

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -38, 0, 4)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 61
    closeBtn.Parent = win
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    local function onClick(btn, fn)
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
    onClick(closeBtn, function() win.Visible = false end)

    -- ──────── Блок "ОТДАТЬ ДРУГУ" ────────
    local sendTitle = Instance.new("TextLabel")
    sendTitle.Size = UDim2.new(1, -20, 0, 18)
    sendTitle.Position = UDim2.new(0, 14, 0, 40)
    sendTitle.BackgroundTransparency = 1
    sendTitle.Text = "📤  ОТДАТЬ ДРУГУ (строка / ссылка)"
    sendTitle.TextColor3 = Color3.fromRGB(180, 255, 200)
    sendTitle.Font = Enum.Font.GothamBold
    sendTitle.TextSize = 12
    sendTitle.TextXAlignment = Enum.TextXAlignment.Left
    sendTitle.ZIndex = 61
    sendTitle.Parent = win

    local sendBox = Instance.new("TextBox")
    sendBox.Size = UDim2.new(1, -28, 0, 90)
    sendBox.Position = UDim2.new(0, 14, 0, 60)
    sendBox.BackgroundColor3 = Color3.fromRGB(15, 12, 24)
    sendBox.TextColor3 = Color3.fromRGB(200, 220, 255)
    sendBox.Font = Enum.Font.Code
    sendBox.TextSize = 11
    sendBox.Text = ""
    sendBox.PlaceholderText = "(тут появится строка для отправки)"
    sendBox.PlaceholderColor3 = Color3.fromRGB(110, 100, 140)
    sendBox.TextWrapped = true
    sendBox.TextXAlignment = Enum.TextXAlignment.Left
    sendBox.TextYAlignment = Enum.TextYAlignment.Top
    sendBox.ClearTextOnFocus = false
    sendBox.MultiLine = true
    sendBox.ZIndex = 61
    sendBox.Parent = win
    Instance.new("UICorner", sendBox).CornerRadius = UDim.new(0, 8)
    local sp = Instance.new("UIPadding", sendBox)
    sp.PaddingLeft = UDim.new(0, 6); sp.PaddingRight = UDim.new(0, 6)
    sp.PaddingTop = UDim.new(0, 4); sp.PaddingBottom = UDim.new(0, 4)

    -- кнопки под "отдать"
    local rowY = 156
    local btnH = 32
    local function mkBtn(text, x, w, color, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, w, 0, btnH)
        b.Position = UDim2.new(0, x, 0, rowY)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(230, 230, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = text
        b.ZIndex = 61
        b.Parent = win
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        onClick(b, cb)
        return b
    end

    local copyBtn = mkBtn("📋 Копировать", 14, 120, Color3.fromRGB(60, 90, 70), function()
        local txt = sendBox.Text
        if txt == "" then
            ORBIT.notify("📤 Сначала сгенерируй строку", Color3.fromRGB(255, 200, 120), 2)
            return
        end
        local ok = S.copy(txt)
        if ok then
            ORBIT.notify("📋 Скопировано в буфер", Color3.fromRGB(180, 255, 180), 2)
        else
            ORBIT.notify("❌ Буфер недоступен — выдели текст вручную", Color3.fromRGB(255, 150, 150), 3)
        end
    end)

    local linkBtn = mkBtn("🌐 Создать ссылку", 140, 150, Color3.fromRGB(60, 70, 110), function()
        local txt = sendBox.Text
        if txt == "" then
            ORBIT.notify("📤 Сначала сгенерируй строку", Color3.fromRGB(255, 200, 120), 2)
            return
        end
        linkBtn.Text = "⏳ Загрузка..."
        task.spawn(function()
            local url, err = S.upload(txt)
            if url then
                sendBox.Text = url
                S.copy(url)
                ORBIT.notify("🌐 Ссылка готова (скопирована): " .. url, Color3.fromRGB(180, 220, 255), 4)
            else
                ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 3)
            end
            linkBtn.Text = "🌐 Создать ссылку"
        end)
    end)

    local clearSendBtn = mkBtn("🗑 Очистить", 296, 90, Color3.fromRGB(80, 50, 60), function()
        sendBox.Text = ""
    end)

    -- ──────── Блок "ПРИНЯТЬ ОТ ДРУГА" ────────
    local recvTitle = Instance.new("TextLabel")
    recvTitle.Size = UDim2.new(1, -20, 0, 18)
    recvTitle.Position = UDim2.new(0, 14, 0, rowY + btnH + 10)
    recvTitle.BackgroundTransparency = 1
    recvTitle.Text = "📥  ВСТАВЬ СТРОКУ ОТ ДРУГА"
    recvTitle.TextColor3 = Color3.fromRGB(255, 210, 180)
    recvTitle.Font = Enum.Font.GothamBold
    recvTitle.TextSize = 12
    recvTitle.TextXAlignment = Enum.TextXAlignment.Left
    recvTitle.ZIndex = 61
    recvTitle.Parent = win

    local recvY = rowY + btnH + 30
    local recvBox = Instance.new("TextBox")
    recvBox.Size = UDim2.new(1, -28, 0, 90)
    recvBox.Position = UDim2.new(0, 14, 0, recvY)
    recvBox.BackgroundColor3 = Color3.fromRGB(15, 12, 24)
    recvBox.TextColor3 = Color3.fromRGB(255, 220, 200)
    recvBox.Font = Enum.Font.Code
    recvBox.TextSize = 11
    recvBox.Text = ""
    recvBox.PlaceholderText = "ORBIT1|SH|... или ссылка https://paste.rs/..."
    recvBox.PlaceholderColor3 = Color3.fromRGB(110, 100, 140)
    recvBox.TextWrapped = true
    recvBox.TextXAlignment = Enum.TextXAlignment.Left
    recvBox.TextYAlignment = Enum.TextYAlignment.Top
    recvBox.ClearTextOnFocus = false
    recvBox.MultiLine = true
    recvBox.ZIndex = 61
    recvBox.Parent = win
    Instance.new("UICorner", recvBox).CornerRadius = UDim.new(0, 8)
    local rp = Instance.new("UIPadding", recvBox)
    rp.PaddingLeft = UDim.new(0, 6); rp.PaddingRight = UDim.new(0, 6)
    rp.PaddingTop = UDim.new(0, 4); rp.PaddingBottom = UDim.new(0, 4)

    -- Кнопки под "принять"
    local recvRowY = recvY + 96
    local function mkRecvBtn(text, x, w, color, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, w, 0, 36)
        b.Position = UDim2.new(0, x, 0, recvRowY)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(230, 230, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.Text = text
        b.ZIndex = 61
        b.Parent = win
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        onClick(b, cb)
        return b
    end

    mkRecvBtn("📋 Из буфера", 14, 130, Color3.fromRGB(50, 80, 100), function()
        local txt, err = S.paste()
        if not txt then
            ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 2)
            return
        end
        recvBox.Text = txt
        ORBIT.notify("📋 Вставлено (" .. #txt .. " симв.)", Color3.fromRGB(180, 220, 255), 2)
    end)

    mkRecvBtn("📥 ИМПОРТ", 152, 160, Color3.fromRGB(60, 120, 80), function()
        local txt = recvBox.Text
        if txt == "" then
            ORBIT.notify("📥 Вставь строку или ссылку", Color3.fromRGB(255, 200, 120), 2)
            return
        end
        -- Если это ссылка — сначала скачаем её содержимое
        if txt:match("^https?://") then
            ORBIT.notify("🌐 Загружаю по ссылке...", Color3.fromRGB(200, 220, 255), 2)
            task.spawn(function()
                local ok, body = pcall(function() return game:HttpGet(txt, true) end)
                if ok and type(body) == "string" and #body > 10 then
                    recvBox.Text = body:gsub("^%s+", ""):gsub("%s+$", "")
                    ORBIT.notify("✅ Ссылка загружена, нажми ИМПОРТ", Color3.fromRGB(180, 255, 180), 2)
                else
                    ORBIT.notify("❌ Не удалось скачать ссылку", Color3.fromRGB(255, 150, 150), 3)
                end
            end)
            return
        end
        -- Обычная строка ORBIT1|...
        local decoded, err = S.decode(txt)
        if not decoded then
            ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 3)
            return
        end
        S.applyDecoded(decoded)
        recvBox.Text = ""
    end)

    mkRecvBtn("🗑 Очистить", 320, 90, Color3.fromRGB(80, 50, 60), function()
        recvBox.Text = ""
    end)

    -- Подсказка
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -28, 0, 40)
    hint.Position = UDim2.new(0, 14, 1, -48)
    hint.BackgroundTransparency = 1
    hint.Text = "💡 Строку можно отправить в Discord/Telegram. Ссылка короче и не режется чатом."
    hint.TextColor3 = Color3.fromRGB(160, 150, 190)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 10
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 61
    hint.Parent = win

    uiPanel = win
    return uiPanel
end

-- ============================================================
--       ПРИМЕНЕНИЕ РАСШИФРОВАННОГО
-- ============================================================
-- Применяет то, что вернул S.decode
function S.applyDecoded(decoded)
    if not decoded then return false end

    if decoded.kind == "SH" then
        local shape = decoded.data
        if shape.type == "3D" then
            -- Регистрируем 3D-фигуру как кастомную через общий механизм p4_shop
            if not ORBIT.registerCustomShape then
                ORBIT.notify("❌ Модуль магазина не готов", Color3.fromRGB(255,150,150), 3)
                return false
            end
            local payload = { name = shape.name, is3D = true, N = shape.N, blocks = shape.blocks }
            ORBIT.registerCustomShape(payload)
            ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
            table.insert(ORBIT.CUSTOM_SHAPES, payload)
            if type(ORBIT.saveStorage) == "function" then pcall(ORBIT.saveStorage) end
            ORBIT.notify("✅ Фигура 3D добавлена: " .. shape.name, Color3.fromRGB(180, 255, 180), 3)
        else
            if not ORBIT.registerCustomShape then
                ORBIT.notify("❌ Модуль магазина не готов", Color3.fromRGB(255,150,150), 3)
                return false
            end
            local payload = { name = shape.name, pixels = shape.pixels }
            ORBIT.registerCustomShape(payload)
            ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
            table.insert(ORBIT.CUSTOM_SHAPES, payload)
            if type(ORBIT.saveStorage) == "function" then pcall(ORBIT.saveStorage) end
            ORBIT.notify("✅ Фигура 2D добавлена: " .. shape.name, Color3.fromRGB(180, 255, 180), 3)
        end
        return true
    end

    if decoded.kind == "SV" then
        -- Именованное сохранение: складываем в ORBIT.SAVES
        ORBIT.SAVES = ORBIT.SAVES or {}
        local name = decoded.name or "ИМПОРТ"
        if ORBIT.SAVES[name] then
            -- уникальное имя
            local base, n = name, 1
            while ORBIT.SAVES[name] do
                n = n + 1
                name = base .. "_" .. n
            end
        end
        ORBIT.SAVES[name] = { data = decoded.data, time = os.time() }
        if type(ORBIT.saveSavesList) == "function" then pcall(ORBIT.saveSavesList) end
        ORBIT.notify("✅ Сохранение добавлено: " .. name, Color3.fromRGB(180, 220, 255), 4)
        return true
    end

    if decoded.kind == "PR" then
        -- Пресет: сразу применяем к настройкам
        local apply = ORBIT.applySaveData
        if type(apply) ~= "function" then
            ORBIT.notify("❌ p3 не экспортирует applySaveData", Color3.fromRGB(255,150,150), 3)
            return false
        end
        local ok, err = pcall(apply, decoded.data)
        if ok then
            ORBIT.notify("✅ Пресет применён", Color3.fromRGB(180, 255, 180), 3)
            if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
            if ORBIT.setupAura then pcall(ORBIT.setupAura) end
            if ORBIT.setupFire then pcall(ORBIT.setupFire) end
            return true
        else
            ORBIT.notify("❌ Ошибка применения: " .. tostring(err):sub(1, 40), Color3.fromRGB(255,150,150), 3)
            return false
        end
    end

    ORBIT.notify("❌ Неизвестный тип строки", Color3.fromRGB(255,150,150), 2)
    return false
end

-- ============================================================
--       ОТКРЫТИЕ ПАНЕЛИ
-- ============================================================
function S.open(initialSendText)
    local win = ensureUI()
    if not win then
        ORBIT.notify("❌ UI не готов", Color3.fromRGB(255,150,150), 2)
        return
    end
    -- Положить в sendBox, если передали
    if initialSendText then
        local sendBox = win:FindFirstChildOfClass("TextBox")
        if sendBox then sendBox.Text = initialSendText end
    end
    win.Visible = true
    if ORBIT.playClick then pcall(ORBIT.playClick) end
end

function S.close()
    if uiPanel then uiPanel.Visible = false end
end

function S.openImport(text)
    S.open()
    local win = ensureUI()
    if win and text then
        local boxes = {}
        for _, ch in ipairs(win:GetChildren()) do
            if ch:IsA("TextBox") then boxes[#boxes + 1] = ch end
        end
        -- второй бокс — «принять»
        if boxes[2] then boxes[2].Text = text end
    end
end

ORBIT.notify = ORBIT.notify or function(msg) print("[ORBIT]", msg) end
if ORBIT.notify then
    ORBIT.notify("🔗 Share-модуль v23.8 загружен", Color3.fromRGB(180, 220, 255), 2)
end
warn("[Orbit Share v23.8] Загружен ✅")
return true
