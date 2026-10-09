-- ORBIT v24.0 | orbit_tools.lua
-- Объединяет: helper + share + editor3d + shop (+2D-редактор) и две новые фичи:
-- 4 темы UI (ORBIT.THEMES / applyTheme) и 52 достижения (ORBIT.achievements).
-- Модули shop/editor3d пропускаются, если уже загружены отдельными шагами загрузчика.
-- v24.0-fix: 3 бага в достижениях (c_charged, fireId double-shot, h_g3 через UI-кнопку).
-- Идентификаторы — латиница, комментарии — русский.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Tools] ORBIT не найден!"); return end
ORBIT.loaded = ORBIT.loaded or {}

local Tools = {}

-- ═════════ МОДУЛЬ: share (из orbit_share.lua) ═════════
local function module_share()
if ORBIT.share then return end
-- ОРБИТА v23.11 — SHARE MODULE (orbit_share.lua)
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
local MAX_LEN   = 200000
local MAX_PIX   = 24
local MIN_PIX   = 8
local MAX_GRID3 = 64
local MIN_GRID3 = 2
local MAX_BLOCKS3 = 5000
local MAX_NAME_LEN = 32

-- ============================================================
--       БАЗА64 (встроенная в HttpService)
-- ============================================================
-- v23.11: HttpService:Base64Encode в обычном Roblox НЕ СУЩЕСТВУЕТ — pcall молча
-- возвращал nil, и поле «ВЫДАТЬ МОИ НАСТРОЙКИ» оставалось пустым (баг B2).
-- Поэтому кодируем сами: чистый Lua, без зависимостей от executor.
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_ENC, B64_DEC = {}, {}
for i = 1, 64 do
    local ch = B64_CHARS:sub(i, i)
    B64_ENC[i - 1] = ch
    B64_DEC[ch:byte()] = i - 1
end

local function b64Encode(str)
    if type(str) ~= "string" then return nil end
    local out, n = {}, 0
    local len = #str
    for i = 1, len, 3 do
        local a, b, c = str:byte(i, i + 2)
        local v = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(v / 262144) % 64
        local c2 = math.floor(v / 4096) % 64
        local c3 = math.floor(v / 64) % 64
        local c4 = v % 64
        n = n + 1
        if b == nil then
            out[n] = B64_ENC[c1] .. B64_ENC[c2] .. "=="
        elseif c == nil then
            out[n] = B64_ENC[c1] .. B64_ENC[c2] .. B64_ENC[c3] .. "="
        else
            out[n] = B64_ENC[c1] .. B64_ENC[c2] .. B64_ENC[c3] .. B64_ENC[c4]
        end
    end
    return table.concat(out)
end

local function b64Decode(str)
    if type(str) ~= "string" then return nil end
    str = str:gsub("[^%w%+/]", "")
    local out, n = {}, 0
    local len = #str
    if len == 0 or len % 4 == 1 then return nil end
    for i = 1, len, 4 do
        local c1 = B64_DEC[str:byte(i)]
        local c2 = B64_DEC[str:byte(i + 1)]
        local b3, b4 = str:byte(i + 2), str:byte(i + 3)
        local c3 = b3 and B64_DEC[b3]
        local c4 = b4 and B64_DEC[b4]
        if not c1 or not c2 then return nil end
        local v = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
        local x1 = math.floor(v / 65536) % 256
        local x2 = math.floor(v / 256) % 256
        local x3 = v % 256
        n = n + 1
        if c3 == nil then
            out[n] = string.char(x1)
        elseif c4 == nil then
            out[n] = string.char(x1, x2)
        else
            out[n] = string.char(x1, x2, x3)
        end
    end
    return table.concat(out)
end

-- ============================================================
--       УПАКОВКА
-- ============================================================
local function pack(kind, payload, extraName)
    local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok or not json then return nil, "Ошибка упаковки" end
    local b64 = b64Encode(json)
    if not b64 then return nil, "Ошибка base64" end
    if kind == "SV" and extraName then
        local safe = tostring(extraName):gsub("[|%c]", "_"):sub(1, MAX_NAME_LEN)
        return PREFIX .. "SV|" .. safe .. "|" .. b64
    end
    return PREFIX .. kind .. "|" .. b64
end

-- ============================================================
--       ВАЛИДАЦИЯ
-- ============================================================
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
        data     = entry.data,
    }
    return pack("SV", payload, name)
end

function S.encodeCurrentSettings()
    local collector = ORBIT.collectSaveDataForShare
    if type(collector) ~= "function" then
        return nil, "Обновление p3 не установлено (нет collectSaveDataForShare)"
    end
    local ok, data = pcall(collector)
    if not ok or not data then return nil, "Не удалось собрать настройки" end
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
    if text:match("^https?://") then
        local body, derr = S.download(text)
        if not body then return nil, "Ссылка: " .. tostring(derr) end
        text = body
    end
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
--       ЗАГРУЗКА НА paste.rs
-- ============================================================
local function httpRequest(opts)
    local fns = {}
    if type(request) == "function" then fns[#fns + 1] = request end
    if type(http_request) == "function" then fns[#fns + 1] = http_request end
    if type(syn) == "table" and type(syn.request) == "function" then fns[#fns + 1] = syn.request end
    if type(http) == "table" and type(http.request) == "function" then fns[#fns + 1] = http.request end
    if type(fluxus) == "table" and type(fluxus.request) == "function" then fns[#fns + 1] = fluxus.request end
    if #fns == 0 then return nil, "Нет HTTP-API (нужен request или http_request)" end
    local lastErr = "Нет ответа"
    for _, fn in ipairs(fns) do
        local ok, res = pcall(fn, opts)
        if ok and type(res) == "table" then
            local code = res.StatusCode or res.Status
            if code == nil or (code >= 200 and code < 300) then
                return res.Body or ""
            end
            lastErr = "HTTP " .. tostring(code)
        elseif not ok then
            lastErr = tostring(res):sub(1, 40)
        end
    end
    return nil, lastErr
end

local function httpPost(url, body)
    return httpRequest({
        Url = url, Method = "POST", Body = body,
        Headers = { ["Content-Type"] = "text/plain" },
    })
end

function S.download(url)
    if type(url) ~= "string" or not url:match("^https?://") then return nil, "Не ссылка" end
    local body, err = httpRequest({ Url = url, Method = "GET" })
    if not body and type(game) == "userdata" then
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" then body, err = res, nil end
    end
    if not body then return nil, err or "Не удалось скачать" end
    body = body:gsub("^%s+", ""):gsub("%s+$", "")
    if #body < 12 then return nil, "Пустой ответ" end
    return body
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
function S.applyDecoded(decoded)
    if not decoded then return false end

    if decoded.kind == "SH" then
        local shape = decoded.data
        if shape.type == "3D" then
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
        ORBIT.SAVES = ORBIT.SAVES or {}
        local name = decoded.name or "ИМПОРТ"
        if ORBIT.SAVES[name] then
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
        local apply = ORBIT.applySaveData
        if type(apply) ~= "function" then
            ORBIT.notify("❌ p3 не экспортирует applySaveData", Color3.fromRGB(255,150,150), 3)
            return false
        end
        local data = decoded.data
        if type(ORBIT.decodeSettingsForShare) == "function" then
            local okD, res = pcall(ORBIT.decodeSettingsForShare, data)
            if okD and type(res) == "table" then data = res end
        end
        local ok, err = pcall(apply, data)
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
        if boxes[2] then boxes[2].Text = text end
    end
end

ORBIT.notify = ORBIT.notify or function(msg) print("[ORBIT]", msg) end
if ORBIT.notify then
    ORBIT.notify("🔗 Share-модуль v23.11 загружен", Color3.fromRGB(180, 220, 255), 2)
end
warn("[Orbit Share v23.11] Загружен ✅")
return true

end
do local ok, err = pcall(module_share); Tools.share = ok; if not ok then warn("[Orbit Tools] share: " .. tostring(err)) end end

-- ═════════ МОДУЛЬ: helper (из orbit_helper.lua) ═════════
local function module_helper()
if ORBIT.helper then return end
-- ОРБИТА v1.2 — HELPER (orbit_helper.lua)
-- Rule-based помощник: понимает простые русские фразы и сразу применяет настройки.
-- Не требует интернета, API-ключей, LLM. Работает офлайн за 1 кадр.

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
ORBIT.helperClose = function()
    if H.close then pcall(H.close) end
end

-- ============================================================
--       СЛОВАРИ КЛЮЧЕВЫХ СЛОВ
-- ============================================================
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

local STYLE_KEYWORDS = {
    { "огненн",   "🔥 Огненный" },
    { "ледян",    "❄️ Ледяной" },
    { "королев",  "👑 Королевский" },
    { "золот",    "👑 Королевский" },
    { "радуг",    "🌈 Радуга-вихрь" },
    { "призрак",  "👻 Призрак" },
    { "скал",     "🪨 Скала-шоу" },
    { "случайн",  "🎲 Случайный стиль" },
    { "рандом",   "🎲 Случайный стиль" },
    { "огн",      "🔥 Огонь" },
    { "пламя",    "🔥 Огонь" },
    { "земл",     "🌍 Земля" },
    { "камен",    "🌍 Земля" },
    { "вод",      "💧 Вода" },
    { "лёд",      "❄️ Лёд" },
    { "лед",      "❄️ Лёд" },
    { "молни",    "⚡ Молния" },
    { "гроз",     "⚡ Молния" },
    { "телепорт", "✨ Телепорт" },
    { "скорост",  "💨 Скорость" },
    { "ветер",    "🌪️ Ветер" },
    { "ветр",     "🌪️ Ветер" },
    { "вихр",     "🌪️ Ветер" },
    { "яд",       "☠️ Яд" },
}

local ATMO_KEYWORDS = {
    { "снег", "Снег" }, { "дожд", "Дождь" }, { "лепест", "Лепестки" }, { "искр", "Искры" },
    { "звёзд", "Звёзды" }, { "звезд", "Звёзды" }, { "пузыр", "Пузыри" }, { "пепел", "Пепел" },
}

local MATERIAL_KEYWORDS = {
    { "стекл", "Glass" }, { "метал", "Metal" }, { "неон", "Neon" }, { "пластик", "SmoothPlastic" },
    { "лёд", "Ice" }, { "лед", "Ice" }, { "силов", "ForceField" }, { "мрамор", "Marble" },
    { "фольг", "Foil" }, { "камен", "Slate" },
}

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
    ["дракон"]   = "ДРАКОН",
    ["драк"]     = "ДРАКОН",
    ["омега"]    = "ОМЕГА ФЛАУИ",
    ["омега флауи"] = "ОМЕГА ФЛАУИ",
    ["флауи"]    = "ЦВЕТОК ФЛАУИ",
    ["цветок"]   = "ЦВЕТОК ФЛАУИ",
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
    local out = {}
    for _, code in utf8.codes(s or "") do
        if code >= 0x410 and code <= 0x42F then code = code + 32
        elseif code == 0x401 or code == 0x451 then code = 0x435
        elseif code >= 65 and code <= 90 then code = code + 32 end
        out[#out + 1] = utf8.char(code)
    end
    return table.concat(out)
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
    for _, pair in ipairs(STYLE_KEYWORDS) do
        if containsWord(text, pair[1]) then
            if not (pair[1] == "скорост" and (text:match("[хx]%s*%d") or containsWord(text, "быстр") or containsWord(text, "медлен"))) then
                return pair[2]
            end
        end
    end
    return nil
end

local function findFromList(text, list)
    for _, pair in ipairs(list) do
        if containsWord(text, pair[1]) then return pair[2] end
    end
    return nil
end

local function findShape(text)
    local bestIdx, bestName, bestLen = nil, nil, 0
    for root, name in pairs(SHAPE_KEYWORDS) do
        if #root > bestLen and containsWord(text, root) then
            local idx = idxByShapeName(name)
            if idx then bestIdx, bestName, bestLen = idx, name, #root end
        end
    end
    return bestIdx, bestName
end

-- ============================================================
--       ОСНОВНОЙ ПАРСЕР
-- ============================================================
function H.interpret(rawText)
    if type(rawText) ~= "string" then return false, "Пустой запрос" end
    local t = lower(rawText)
    if #t < 2 then return false, "Слишком коротко" end

    if containsWord(t, "помощь") or containsWord(t, "команд") or t == "help" or t == "?" then
        if H.showHelp then pcall(H.showHelp) end
        return true, "📖 Открыл окно помощника"
    end

    do
        local emo
        if containsWord(t, "танц") or containsWord(t, "станцуй") then emo = "dance"
        elseif containsWord(t, "привет") or containsWord(t, "поздоров") or containsWord(t, "помаш") then emo = "greet"
        elseif containsWord(t, "смей") or containsWord(t, "смех") or containsWord(t, "хаха") then emo = "laugh"
        elseif containsWord(t, "санс") or containsWord(t, "скажи что") then emo = "sans"
        elseif containsWord(t, "уворот") then emo = "dodge" end
        if emo then
            if ORBIT.emote and ORBIT.emote(emo) then return true, "🎭 Эмоция: " .. emo end
            return false, "🎭 Эмоции недоступны (нет orbit_sfx) или кулдаун"
        end
    end

    if containsWord(t, "бот") then
        if containsWord(t, "покажи") or containsWord(t, "открой") or containsWord(t, "где") then
            if ORBIT.ui and ORBIT.ui.setTab then ORBIT.ui.setTab("bots"); if ORBIT.ui.open then ORBIT.ui.open() end end
            return true, "🤖 Открыта вкладка БОТЫ"
        elseif containsWord(t, "удал") or containsWord(t, "убери") then
            if ORBIT.removeAllBots then ORBIT.removeAllBots() end
            return true, "🗑 Боты удалены"
        else
            local n = tonumber(t:match("(%d+)")) or 1
            if n <= 1 and ORBIT.createBotNear then ORBIT.createBotNear()
            elseif n <= 10 and ORBIT.createMultipleBots then ORBIT.createMultipleBots(n)
            elseif ORBIT.createManyBots then ORBIT.createManyBots(math.min(n, 100)) end
            return true, "🤖 Ботов создано: " .. n
        end
    end
    if containsWord(t, "вкладк") or containsWord(t, "покажи") or containsWord(t, "открой") then
        local tabs = { {"глав","main"}, {"вид","look"}, {"движен","motion"}, {"аур","aura"}, {"эффект","fx"},
            {"игрок","players"}, {"ещё","more"}, {"еще","more"}, {"систем","sys"} }
        for _, pr in ipairs(tabs) do
            if containsWord(t, pr[1]) and ORBIT.ui and ORBIT.ui.setTab then
                ORBIT.ui.setTab(pr[2]); if ORBIT.ui.open then ORBIT.ui.open() end
                return true, "📂 Вкладка: " .. pr[2]
            end
        end
    end
    if containsWord(t, "сохрани") then
        local ok = ORBIT.saveSettings and ORBIT.saveSettings()
        return true, ok and "💾 Сохранено" or "💾 Сохранено в памяти"
    end
    if containsWord(t, "загруз") and not containsWord(t, "строк") then
        if ORBIT.loadSettings then ORBIT.loadSettings() end
        return true, "📂 Настройки загружены"
    end
    if containsWord(t, "поделись") or containsWord(t, "выдай настройки") or containsWord(t, "обмен") then
        if ORBIT.share and ORBIT.share.open then ORBIT.share.open(); return true, "🔗 Окно SHARE открыто" end
        return false, "🔗 orbit_share.lua не загружен"
    end

    if containsWord(t, "редактор") then
        local is3d = containsWord(t, "3d") or containsWord(t, "3д") or containsWord(t, "объём") or containsWord(t, "объем")
            or containsWord(t, "трёхмер") or containsWord(t, "трехмер")
        if is3d then
            if ORBIT.openEditor3D then pcall(ORBIT.openEditor3D); return true, "🔮 3D-редактор открыт" end
            return false, "🔮 orbit_editor3d.lua не загружен"
        end
        if ORBIT.openEditor then pcall(ORBIT.openEditor); return true, "🎨 2D-редактор открыт" end
        return false, "🎨 orbit_p4_shop.lua не загружен"
    end
    do
        local sizeNum = t:match("сетк%S*%s*[^%d]-(%d+)") or t:match("(%d+)%s*[хx×]%s*%d+%s*сетк")
        local brushNum = t:match("кист%S*%s*[^%d]-(%d+)")
        local ed3 = ORBIT.Editor3D
        local ed2 = ORBIT.Editor2D
        local open3 = ed3 and ed3.Open
        local open2 = ed2 and ed2.Open
        if sizeNum or brushNum then
            if not (open3 or open2) then
                return false, "📐 Сначала открой редактор: «открой редактор» или «3d редактор»"
            end
        end
        if sizeNum then
            local n = tonumber(sizeNum)
            if open3 and ed3.SetGridSize then
                if ed3.SetGridSize(n) then
                    return true, "📐 3D-сетка: " .. n .. (n >= 64 and " ⚠ огромная, может тормозить" or "")
                end
                return false, "📐 В 3D доступны размеры: 4, 5, 6, 7, 8, 16, 32, 64"
            elseif open2 and ed2.SetGridSize then
                if ed2.SetGridSize(n) then return true, "📐 2D-сетка: " .. n .. "×" .. n end
                return false, "📐 В 2D доступны размеры: 16, 20, 24"
            end
        end
        if brushNum then
            local n = tonumber(brushNum)
            if open3 and ed3.SetBrush then
                if ed3.SetBrush(n) then return true, "🔲 3D-кисть: " .. n .. "×" .. n .. "×" .. n end
                return false, "🔲 В 3D доступны кисти: 1–5"
            elseif open2 and ed2.SetBrush then
                if n >= 1 and n <= 5 then
                    ed2.SetBrush(n)
                    return true, "🔲 2D-кисть: " .. n .. "×" .. n
                end
                return false, "🔲 В 2D доступны кисти: 1–5"
            end
        end
    end

    if containsWord(t, "частиц") or (containsWord(t, "аур") and (containsWord(t, "дым") or containsWord(t, "звёзд") or containsWord(t, "звезд") or containsWord(t, "искр"))) then
        local offWords = containsWord(t, "выкл") or containsWord(t, "убери") or containsWord(t, "отключ") or containsWord(t, "без ")
        if offWords then
            SETTINGS.AuraParticles = false
            if ORBIT.setupAura then pcall(ORBIT.setupAura) end
            return true, "✨ Частицы ауры: ВЫКЛ"
        end
        local style
        if containsWord(t, "дым") then style = 2
        elseif containsWord(t, "звёзд") or containsWord(t, "звезд") then style = 3
        elseif containsWord(t, "искр") then style = 1 end
        if style then
            SETTINGS.AuraParticleStyle = style
            SETTINGS.AuraParticles = true
            SETTINGS.AuraEnabled = true
            if ORBIT.setupAura then pcall(ORBIT.setupAura) end
            if ORBIT.ui and ORBIT.ui.refreshAuraFx then pcall(ORBIT.ui.refreshAuraFx) end
            local names = ORBIT.AURA_PARTICLE_STYLES and ORBIT.AURA_PARTICLE_STYLES[style]
            return true, "✨ Частицы ауры: " .. (names and names.name or tostring(style))
        end
        if containsWord(t, "вкл") or containsWord(t, "включ") then
            SETTINGS.AuraParticles = true
            SETTINGS.AuraEnabled = true
            if ORBIT.setupAura then pcall(ORBIT.setupAura) end
            return true, "✨ Частицы ауры: ВКЛ"
        end
        return false, "✨ Частицы ауры: скажи «частицы дым», «частицы звёзды» или «частицы искры»"
    end

    if containsWord(t, "свеч") then
        local off = containsWord(t, "выкл") or containsWord(t, "убери") or containsWord(t, "отключ") or containsWord(t, "без ")
        if containsWord(t, "аур") then
            local level = 1
            if off then level = 0
            elseif containsWord(t, "мало") or containsWord(t, "слаб") or containsWord(t, "чуть") or containsWord(t, "тих") then level = 0.5
            elseif containsWord(t, "сильн") or containsWord(t, "макс") or containsWord(t, "ярк") or containsWord(t, "много") or containsWord(t, "больш") then level = 2 end
            SETTINGS.AuraGlow = level
            if ORBIT.setupAura then pcall(ORBIT.setupAura) end
            if ORBIT.ui and ORBIT.ui.refreshAuraFx then pcall(ORBIT.ui.refreshAuraFx) end
            return true, "💡 Свечение ауры: " .. (level <= 0 and "ВЫКЛ" or ("×" .. tostring(level)))
        end
        local on = not off
        if ORBIT.ui and ORBIT.ui.setGlow then
            pcall(ORBIT.ui.setGlow, on)
        else
            SETTINGS.GlowEnabled = on
            for _, ring in pairs(rings) do
                for _, d in ipairs(ring.blocks) do
                    if d.light then d.light.Enabled = on end
                end
            end
        end
        return true, "✨ Свечение колец: " .. (on and "ВКЛ" or "ВЫКЛ")
    end

    do
        local atmoOff = containsWord(t, "без атмосфер") or containsWord(t, "убери атмосфер")
            or (containsWord(t, "убери") and findFromList(t, ATMO_KEYWORDS) ~= nil)
        if atmoOff and ORBIT.extras and ORBIT.extras.setAtmo then
            ORBIT.extras.setAtmo(false); return true, "❄️ Атмосфера: ВЫКЛ"
        end
        local atmo = findFromList(t, ATMO_KEYWORDS)
        if atmo and not containsWord(t, "стиль") and ORBIT.extras and ORBIT.extras.setAtmo then
            ORBIT.extras.setAtmo(true, atmo); return true, "❄️ Атмосфера: " .. atmo
        end
    end

    if containsWord(t, "материал") then
        local mname = findFromList(t, MATERIAL_KEYWORDS)
        if mname then
            local okM, mat = pcall(function() return Enum.Material[mname] end)
            if okM and mat then
                if containsWord(t, "аур") then
                    SETTINGS.AuraMaterial = mat
                    if ORBIT.setupAura then pcall(ORBIT.setupAura) end
                    return true, "🧱 Материал ауры: " .. mname
                end
                SETTINGS.Material = mat
                if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
                return true, "🧱 Материал: " .. mname
            end
        end
    end
    do
        local n = t:match("(%d+)%s*фигур") or t:match("(%d+)%s*блок")
        if n then
            SETTINGS.BlockCount = math.clamp(tonumber(n) or 8, 1, 40)
            if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
            return true, "🔷 Фигур в кольце: " .. SETTINGS.BlockCount
        end
    end

    if containsWord(t, "стиль") or containsWord(t, "образ") then
        local styleName = findStyle(t)
        if styleName and ORBIT.ui and ORBIT.ui.applyStyleByName then
            ORBIT.ui.applyStyleByName(styleName)
            return true, "🎭 Стиль: " .. styleName
        end
    end
    if containsWord(t, "хочу") or containsWord(t, "поставь") or containsWord(t, "вруб") or containsWord(t, "сделай") then
        local styleName = findStyle(t)
        if styleName and ORBIT.ui and ORBIT.ui.applyStyleByName then
            ORBIT.ui.applyStyleByName(styleName)
            return true, "🎭 Стиль: " .. styleName
        end
    end

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

    if containsWord(t, "все кольц") or containsWord(t, "все кольца") or containsWord(t, "5 коль") or containsWord(t, "пять коль") then
        for ri = 2, 5 do ORBIT.setRingEnabled(ri, true) end
        return true, "⭕ Включены все 5 колец"
    end
    if containsWord(t, "1 кольц") or containsWord(t, "одно кольц") or containsWord(t, "одно кольцо") then
        for ri = 2, 5 do ORBIT.setRingEnabled(ri, false) end
        return true, "⭕ Оставлено только 1 кольцо"
    end
    do
        local m = t:match("(%d+)%s*кольц")
        if m then
            local n = math.clamp(tonumber(m) or 1, 1, 5)
            for ri = 2, 5 do ORBIT.setRingEnabled(ri, ri <= n) end
            return true, "⭕ Колец включено: " .. n
        end
    end

    local shapeIdx, shapeName = findShape(t)
    if shapeIdx and shapeName then
        ORBIT.shapeIndex = shapeIdx
        if ORBIT.applyShapes then pcall(ORBIT.applyShapes) end
        if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
        return true, "🔷 Фигура: " .. shapeName
    end

    local colIdx, colName = findColor(t)
    if colIdx and colName then
        P.colorIndex = colIdx
        if ORBIT.applyColor then pcall(ORBIT.applyColor) end
        if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
        return true, "🎨 Цвет: " .. colName
    end

    return false, "🤔 Не понял. Скажи «помощь» для списка команд."
end

-- ============================================================
--       ПОКАЗ КОМАНД
-- ============================================================
function H.helpText()
    return table.concat({
        "🤖  КОМАНДЫ ПОМОЩНИКА", "",
        "🎨 Цвет: красный, синий, радуга, огонь, лёд, золотой...",
        "🔷 Фигура: шар, звезда, меч, череп, скала, сердце...",
        "🎭 Стиль: стиль огонь, стиль призрак, случайный стиль",
        "⚡ Скорость: быстрее / медленнее / х2 / в 3 раза",
        "⬆️ Высота: выше / ниже / в небо / в ноги",
        "🌀 Аура: ауру вкл / убери ауру",
        "🔥 Эффекты: огонь / трейлы вкл / пульсация / волна / взрыв",
        "⭕ Кольца: все кольца / 3 кольца / только 1 кольцо",
        "💡 Свет / тени / имена — прямо так",
        "🌋 Стихии: сделай огонь / земля / вода / лёд / молния / телепорт / ветер / яд",
        "🐉 Фигуры: включи дракона / череп / крылья / флауи",
        "❄️ Атмосфера: снег / дождь / лепестки / убери атмосферу",
        "🧱 Материал: материал стекло / материал ауры металл",
        "✨ Частицы ауры: частицы дым / частицы звёзды / частицы искры / частицы выкл",
        "💡 Свечение: свечение ауры сильно / мало / выкл; свечение выкл (кольца)",
        "🌼 Флауи: включи флауи / омега флауи",
        "🎨 Редакторы: открой редактор / 3d редактор / размер сетки 16 / кисть 3",
        "🔷 Количество: 12 фигур",
        "🎭 Эмоции: танцуй / привет / смейся / санс / уворот",
        "🤖 Боты: покажи ботов / создай 5 ботов / удали ботов",
        "📂 Прочее: открой ауру / сохрани / загрузи / поделись", "",
        "Просто напиши фразу целиком:",
        "«хочу огненный стиль»  «сделай радугу»  «поставь череп»",
    }, "\n")
end

-- ============================================================
--       UI ПАНЕЛЬ ПОМОЩНИКА
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

    local y0 = 186
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
    grid.CellSize = UDim2.new(0, cw, 0, 30)
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
    end-- ═════════ МОДУЛЬ: shop (из orbit_p4_shop.lua) ═════════
local function module_shop()
if ORBIT.openShop then return end
-- ОРБИТА v23.12 — P4_SHOP (Магазин + 2D-Редактор + кнопка 3D)
-- v23.12 (Y5): экспорт ORBIT.Editor2D (Open, SetBrush, SetGridSize) для команд помощника.
-- v23.11 (L3): кнопки +12%, яркие заголовки, активный инструмент с обводкой и «✓».
-- v23.10 (I3): 2D-редактор — кисти 1×1…5×5, пипетка, кнопки 38 px.
-- Магазин + 2D-редактор v3: сетка 16/20/24, кисти 1x1/2x2/3x3, ластик, заливка,
-- история 20 шагов, симметрия, шаблоны, сохранение кастомных фигур.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (type(getgenv) == "function" and getgenv().ORBIT)
if not ORBIT then warn("[Orbit Shop] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit Shop] UI не готов!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local TweenService = ORBIT.TweenService
local HttpService  = ORBIT.HttpService
local LocalPlayer  = ORBIT.LocalPlayer
local UIS          = game:GetService("UserInputService")

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local rings    = ORBIT.rings
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS

local screenGui = ORBIT.ui.screenGui
local IS_MOBILE = (ORBIT.PLATFORM == "mobile")

-- ============================================================
--              ХРАНИЛИЩЕ
-- ============================================================
ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
ORBIT.CUSTOM_FILE = "orbit_v21_custom_shapes.json"
ORBIT.COINS = ORBIT.COINS or 0
ORBIT.COINS_FILE = "orbit_v21_coins.json"
ORBIT.OWNED_SHAPES = ORBIT.OWNED_SHAPES or {
    ["БЛОК"] = true, ["ШАР"] = true, ["ЦИЛИНДР"] = true,
}

local SHAPE_PRICES = {
    ["БЛОК"] = 0, ["ШАР"] = 0, ["ЦИЛИНДР"] = 0, ["КЛИН"] = 50,
    ["ГОЛОВА"] = 80, ["СЕРДЦЕ"] = 100, ["ЗВЕЗДА"] = 100, ["ТРЕУГОЛЬНИК"] = 100,
    ["РОМБ"] = 120, ["КРЕСТ"] = 150, ["ЧЕРЕП"] = 200, ["МОЛНИЯ"] = 200,
    ["РУКА"] = 250, ["РУКА-СЕРДЦЕ"] = 300, ["МЕЧ"] = 400, ["ЩИТ"] = 400,
    ["КОСТЬ"] = 100, ["ПИРАМИДА"] = 150, ["ИНЬ-ЯН"] = 250, ["ГЛАЗ"] = 200,
    ["СПИРАЛЬ"] = 200, ["КРЫЛЬЯ"] = 300, ["ЩУПАЛЬЦЕ"] = 350, ["ГАСТЕР БЛАСТЕР"] = 450,
}

local function saveStorage()
    if not ORBIT.HAS_FS then return end
    if type(writefile) ~= "function" then return end
    pcall(function()
        writefile(ORBIT.CUSTOM_FILE, HttpService:JSONEncode(ORBIT.CUSTOM_SHAPES))
        writefile(ORBIT.COINS_FILE, tostring(ORBIT.COINS or 0))
        local owned = {}
        for k, v in pairs(ORBIT.OWNED_SHAPES) do if v then table.insert(owned, k) end end
        writefile("orbit_v21_owned.json", HttpService:JSONEncode(owned))
    end)
end

local function loadStorage()
    if not ORBIT.HAS_FS then return end
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    pcall(function()
        if isfile(ORBIT.CUSTOM_FILE) then
            local txt = readfile(ORBIT.CUSTOM_FILE)
            if txt and #txt > 0 then
                local data = HttpService:JSONDecode(txt)
                for _, shape in ipairs(data or {}) do
                    table.insert(ORBIT.CUSTOM_SHAPES, shape)
                end
            end
        end
        if isfile(ORBIT.COINS_FILE) then
            local txt = readfile(ORBIT.COINS_FILE)
            if txt and #txt > 0 then ORBIT.COINS = tonumber(txt) or 0 end
        end
        if isfile("orbit_v21_owned.json") then
            local txt = readfile("orbit_v21_owned.json")
            if txt and #txt > 0 then
                local data = HttpService:JSONDecode(txt)
                for _, name in ipairs(data or {}) do ORBIT.OWNED_SHAPES[name] = true end
            end
        end
    end)
end

-- ============================================================
--       ПАЛИТРА (24 цвета)
-- ============================================================
local PALETTE = {
    Color3.fromRGB(255, 60, 60),   Color3.fromRGB(255, 140, 40),
    Color3.fromRGB(255, 230, 60),  Color3.fromRGB(120, 255, 100),
    Color3.fromRGB(80, 255, 180),  Color3.fromRGB(80, 220, 255),
    Color3.fromRGB(60, 120, 255),  Color3.fromRGB(140, 80, 255),
    Color3.fromRGB(220, 80, 255),  Color3.fromRGB(255, 80, 180),
    Color3.fromRGB(255, 200, 200), Color3.fromRGB(255, 240, 200),
    Color3.fromRGB(200, 240, 255), Color3.fromRGB(200, 255, 220),
    Color3.fromRGB(200, 200, 255), Color3.fromRGB(240, 200, 255),
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200),
    Color3.fromRGB(120, 120, 130), Color3.fromRGB(60, 60, 70),
    Color3.fromRGB(30, 30, 40),    Color3.fromRGB(255, 200, 100),
    Color3.fromRGB(255, 240, 120), Color3.fromRGB(180, 130, 60),
}
local COLOR_NAMES = {
    "Красный", "Оранжевый", "Жёлтый", "Зелёный", "Изумруд", "Голубой",
    "Синий", "Фиолетовый", "Маджента", "Розовый",
    "Пастель-розовый", "Пастель-крем", "Пастель-голубой", "Пастель-мята",
    "Пастель-сиреневый", "Пастель-лаванда",
    "Белый", "Серый", "Тёмно-серый", "Тёмный", "Почти-чёрный",
    "Золотой", "Свето-золотой", "Бронзовый",
}

-- ============================================================
--       УНИВЕРСАЛЬНЫЙ ТАП (Delta/Android)
-- ============================================================
local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        if ORBIT.playClick then pcall(ORBIT.playClick) end
        local ok, err = pcall(fn)
        if not ok then warn("[Orbit] " .. tostring(err)) end
    end
    local function inScroll()
        return releaseOnly or btn:GetAttribute("ReleaseOnly")
            or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil
    end
    btn.MouseButton1Down:Connect(function() if not inScroll() then call() end end)
    btn.MouseButton1Click:Connect(function() if inScroll() then call() end end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchStart = input.Position
            if not inScroll() then call() end
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and touchStart then
            local moved = (input.Position - touchStart).Magnitude
            touchStart = nil
            if inScroll() and moved < 12 then call() end
        end
    end)
    btn.Activated:Connect(call)
end

-- ============================================================
--       РЕГИСТРАЦИЯ 2D И 3D ФИГУР
-- ============================================================
local function registerCustomShape(shape)
    local name = shape.name or ("СВОЯ_" .. (#ORBIT.CUSTOM_SHAPES))
    for _, sp in ipairs(SHAPE_PRESETS) do
        if sp.name == name then return end
    end

    -- 3D
    if shape.is3D and shape.blocks then
        local size = shape.N or 6
        local blocksCopy = {}
        for _, b in ipairs(shape.blocks) do
            table.insert(blocksCopy, {x=b.x, y=b.y, z=b.z,
                color = Color3.new(b.r or 1, b.g or 1, b.b or 1)})
        end
        table.insert(SHAPE_PRESETS, {
            name = name, isCustom = true, is3D = true,
            create = function(shapeSize, partName)
                local model, root = ORBIT.newModelShell(partName)
                local bodies = {}
                local unit = shapeSize / size
                local cx, cy, cz = (size + 1) / 2, (size + 1) / 2, (size + 1) / 2
                for _, c in ipairs(blocksCopy) do
                    local p = ORBIT.newPart(model, "V",
                        Vector3.new(unit * 0.95, unit * 0.95, unit * 0.95),
                        CFrame.new((c.x - cx) * unit, (c.y - cy) * unit, (c.z - cz) * unit),
                        c.color, true)
                    table.insert(bodies, p)
                end
                return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = shapeSize * 1.4 }
            end,
        })
        ORBIT.OWNED_SHAPES[name] = true
        return
    end

    -- 2D
    local rows = #shape.pixels
    local cols = #shape.pixels[1]
    local pixelData = {}
    for r = 1, rows do
        pixelData[r] = {}
        local row = shape.pixels[r]
        if type(row) == "string" then
            for c = 1, #row do
                if row:sub(c, c) == "1" then
                    pixelData[r][c] = Color3.fromRGB(255, 255, 255)
                end
            end
        elseif type(row) == "table" then
            for c = 1, #row do
                local v = row[c]
                if v and v > 0 then
                    pixelData[r][c] = PALETTE[v] or Color3.fromRGB(255, 255, 255)
                end
            end
        end
    end
    table.insert(SHAPE_PRESETS, {
        name = name, isCustom = true,
        create = function(shapeSize, partName)
            local pixel = shapeSize * 1.8 / math.max(rows, cols)
            local model, root = ORBIT.newModelShell(partName)
            local bodies = {}
            for r = 1, rows do
                for c = 1, cols do
                    local col = pixelData[r][c]
                    if col then
                        local px = (c - (cols + 1) / 2) * pixel
                        local py = ((rows + 1) / 2 - r) * pixel
                        local p = ORBIT.newPart(model, "P",
                            Vector3.new(pixel, pixel, pixel),
                            CFrame.new(px, py, 0), col, true)
                        table.insert(bodies, p)
                    end
                end
            end
            return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = shapeSize }
        end,
    })
    ORBIT.OWNED_SHAPES[name] = true
end

loadStorage()
for _, shape in ipairs(ORBIT.CUSTOM_SHAPES) do
    registerCustomShape(shape)
end
ORBIT.registerCustomShape = registerCustomShape

-- ============================================================
--       ПРЕВЬЮ АВАТАРА
-- ============================================================
local function createAvatarPreview(parent, size)
    local vp = Instance.new("ViewportFrame")
    vp.Size = size
    vp.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    vp.BorderSizePixel = 0
    vp.Ambient = Color3.fromRGB(180, 180, 220)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.LightDirection = Vector3.new(-1, -1, -1)
    vp.Parent = parent
    Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 10)

    local world = Instance.new("WorldModel")
    world.Parent = vp

    local cam = Instance.new("Camera")
    cam.FieldOfView = 40
    cam.Parent = vp
    vp.CurrentCamera = cam

    local avatar
    local ok = pcall(function()
        local desc = Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
        avatar = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if not ok or not avatar then
        avatar = Instance.new("Model")
        local torso = Instance.new("Part")
        torso.Name = "Torso"; torso.Size = Vector3.new(2, 2, 1)
        torso.Anchored = true; torso.CanCollide = false
        torso.Color = Color3.fromRGB(100, 150, 255)
        torso.Parent = avatar
        avatar.PrimaryPart = torso
        local head = Instance.new("Part")
        head.Name = "Head"; head.Shape = Enum.PartType.Ball
        head.Size = Vector3.new(1.4, 1.4, 1.4)
        head.Anchored = true; head.CanCollide = false
        head.Color = Color3.fromRGB(255, 220, 180)
        head.CFrame = torso.CFrame * CFrame.new(0, 1.8, 0)
        head.Parent = avatar
    end

    for _, p in ipairs(avatar:GetDescendants()) do
        if p:IsA("BasePart") then
            p.Anchored = true
            p.CanCollide = false
        end
    end
    pcall(function() avatar:PivotTo(CFrame.new(0, 0, 0)) end)
    avatar.Parent = world

    cam.CFrame = CFrame.new(Vector3.new(0, 1.5, -8), Vector3.new(0, 1.5, 0))
    return vp, world, cam, avatar
end

local function buildDemoRing(world, shapeIndex, color3, sizeMult, blockCount)
    local old = world:FindFirstChild("_DemoRing")
    if old then old:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "_DemoRing"
    folder.Parent = world
    local shape = SHAPE_PRESETS[shapeIndex] or SHAPE_PRESETS[1]
    local size = 1.2 * (sizeMult or 1.0)
    local count = blockCount or 8
    local blocks = {}
    for i = 1, count do
        local data = shape.create(size, "D_" .. i)
        local refPart = data.part
        if not data.isModel then
            refPart.Material = Enum.Material.Neon
            refPart.Anchored = true
            refPart.CanCollide = false
            refPart.Color = color3
        end
        if data.isModel then data.model.Parent = folder else refPart.Parent = folder end
        table.insert(blocks, {
            part = refPart, model = data.model, isModel = data.isModel or false,
            bodyParts = data.bodyParts, index = i,
            angleOffset = (i-1) * (360/count),
        })
    end
    return folder, blocks
end

-- ============================================================
--              МАГАЗИН
-- ============================================================
local shopOpen = false
local shopGui

local shopState = {
    shapeIndex = ORBIT.shapeIndex,
    colorIndex = P.colorIndex,
    sizeIndex = P.shapeSizeIndex,
    speedIndex = P.speedIndex,
    trail = SETTINGS.TrailEnabled,
    light = SETTINGS.LightEnabled,
    pulse = SETTINGS.PulseEnabled,
    categoryIndex = 1,
}

local SHOP_CATEGORIES = {
    { name = "ВСЕ" },
    { name = "ОСНОВНЫЕ", shapes = {"БЛОК","ШАР","ЦИЛИНДР","КЛИН","ТРЕУГОЛЬНИК","ЗВЕЗДА","КРЕСТ","РОМБ","КОСТЬ","ПИРАМИДА","СПИРАЛЬ"} },
    { name = "ОРУЖИЕ",   shapes = {"МЕЧ","ЩИТ"} },
    { name = "МАГИЯ",    shapes = {"ГЛАЗ","ИНЬ-ЯН","МОЛНИЯ","ГАСТЕР БЛАСТЕР"} },
    { name = "СУЩЕСТВА", shapes = {"ЧЕРЕП","РУКА","РУКА-СЕРДЦЕ","ГОЛОВА","СЕРДЦЕ","КРЫЛЬЯ","ЩУПАЛЬЦЕ","СКАЛА"} },
    { name = "СВОИ",     custom = true },
}

local function getShopShapes()
    local cat = SHOP_CATEGORIES[shopState.categoryIndex]
    local list = {}
    if cat.custom then
        for i, sp in ipairs(SHAPE_PRESETS) do
            if sp.isCustom then table.insert(list, i) end
        end
    elseif not cat.shapes then
        for i = 1, #SHAPE_PRESETS do list[i] = i end
    else
        for _, name in ipairs(cat.shapes) do
            for i, sp in ipairs(SHAPE_PRESETS) do
                if sp.name == name then table.insert(list, i); break end
            end
        end
    end
    return list
end

local function openShop()
    if shopOpen and shopGui then return end
    shopOpen = true

    local shopW = IS_MOBILE and 320 or 560
    local shopH = IS_MOBILE and 540 or 500

    shopGui = Instance.new("Frame")
    shopGui.Name = "_OrbitShop"
    shopGui.Size = UDim2.new(0, shopW, 0, shopH)
    shopGui.Position = UDim2.new(0.5, -shopW/2, 0.5, -shopH/2)
    shopGui.BackgroundColor3 = Color3.fromRGB(22, 16, 35)
    shopGui.BackgroundTransparency = 0.05
    shopGui.BorderSizePixel = 0
    shopGui.ZIndex = 10
    shopGui.Parent = screenGui
    Instance.new("UICorner", shopGui).CornerRadius = UDim.new(0, 16)
    local str = Instance.new("UIStroke", shopGui)
    str.Color = Color3.fromRGB(180, 140, 255)
    str.Thickness = 2
    if ORBIT.ui.fitToScreen then ORBIT.ui.fitToScreen(shopGui, shopW, shopH) end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 0, 28)
    title.Position = UDim2.new(0, 16, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🛒  МАГАЗИН"
    title.TextColor3 = Color3.fromRGB(240, 220, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 11
    title.Parent = shopGui

    local coinsLbl = Instance.new("TextLabel")
    coinsLbl.Size = UDim2.new(0, 130, 0, 26)
    coinsLbl.Position = UDim2.new(1, -170, 0, 10)
    coinsLbl.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
    coinsLbl.BorderSizePixel = 0
    coinsLbl.Text = "💰 " .. (ORBIT.COINS or 0)
    coinsLbl.TextColor3 = Color3.fromRGB(255, 220, 120)
    coinsLbl.Font = Enum.Font.GothamBold
    coinsLbl.TextSize = 12
    coinsLbl.ZIndex = 11
    coinsLbl.Parent = shopGui
    Instance.new("UICorner", coinsLbl).CornerRadius = UDim.new(0, 8)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 11
    closeBtn.Parent = shopGui
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    local open3DBtn = Instance.new("TextButton")
    open3DBtn.Size = UDim2.new(0, 130, 0, 26)
    open3DBtn.BackgroundColor3 = Color3.fromRGB(80, 45, 130)
    open3DBtn.TextColor3 = Color3.fromRGB(230, 200, 255)
    open3DBtn.Font = Enum.Font.GothamBold
    open3DBtn.TextSize = 11
    open3DBtn.Text = "🔮 3D-РЕДАКТОР"
    open3DBtn.ZIndex = 11
    open3DBtn.Parent = shopGui
    Instance.new("UICorner", open3DBtn).CornerRadius = UDim.new(0, 8)
    local headerExtraY = 0
    if IS_MOBILE then
        open3DBtn.Position = UDim2.new(0, 16, 0, 40)
        headerExtraY = 32
    else
        open3DBtn.Position = UDim2.new(1, -310, 0, 10)
    end
    onClick(open3DBtn, function()
        if ORBIT.openEditor3D then
            ORBIT.openEditor3D()
        else
            ORBIT.notify("❌ 3D-Редактор не загружен", Color3.fromRGB(255,120,120), 2)
        end
    end)

    local previewW = IS_MOBILE and (shopW - 32) or 240
    local previewH = IS_MOBILE and 200 or 300
    local previewFrame = Instance.new("Frame")
    previewFrame.Size = UDim2.new(0, previewW, 0, previewH)
    previewFrame.Position = UDim2.new(0, 16, 0, 44 + headerExtraY)
    previewFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
    previewFrame.BorderSizePixel = 0
    previewFrame.ZIndex = 11
    previewFrame.Parent = shopGui
    Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(0, 10)

    local vp, world, cam, avatar = createAvatarPreview(previewFrame, UDim2.new(1, 0, 1, 0))
    vp.ZIndex = 12

    local rightX = IS_MOBILE and 16 or 272
    local rightY = IS_MOBILE and (44 + headerExtraY + previewH + 8) or 44
    local rightW = IS_MOBILE and (shopW - 32) or 272
    local rightH = IS_MOBILE and (shopH - rightY - 60) or (shopH - 100)

    local rightPanel = Instance.new("ScrollingFrame")
    rightPanel.Size = UDim2.new(0, rightW, 0, rightH)
    rightPanel.Position = UDim2.new(0, rightX, 0, rightY)
    rightPanel.BackgroundColor3 = Color3.fromRGB(18, 14, 30)
    rightPanel.BorderSizePixel = 0
    rightPanel.CanvasSize = UDim2.new(0, 0, 0, 900)
    rightPanel.ScrollBarThickness = 4
    rightPanel.ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255)
    rightPanel.ZIndex = 11
    rightPanel.Parent = shopGui
    Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 10)

    local ry = 8
    local function shopRow(label, hintText)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -12, 0, 16)
        lbl.Position = UDim2.new(0, 6, 0, ry)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = Color3.fromRGB(220, 220, 250)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 12
        lbl.Parent = rightPanel
        ry = ry + 16
        if hintText then
            local hint = Instance.new("TextLabel")
            hint.Size = UDim2.new(1, -12, 0, 12)
            hint.Position = UDim2.new(0, 6, 0, ry)
            hint.BackgroundTransparency = 1
            hint.Text = hintText
            hint.TextColor3 = Color3.fromRGB(150, 145, 180)
            hint.Font = Enum.Font.Gotham
            hint.TextSize = 9
            hint.TextXAlignment = Enum.TextXAlignment.Left
            hint.ZIndex = 12
            hint.Parent = rightPanel
            ry = ry + 12
        end

        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1, -12, 0, 30)
        holder.Position = UDim2.new(0, 6, 0, ry)
        holder.BackgroundTransparency = 1
        holder.ZIndex = 12
        holder.Parent = rightPanel

        local leftBtn = Instance.new("TextButton")
        leftBtn.Size = UDim2.new(0, 30, 1, 0)
        leftBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
        leftBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
        leftBtn.Font = Enum.Font.GothamBold
        leftBtn.TextSize = 14
        leftBtn.Text = "◀"
        leftBtn.ZIndex = 13
        leftBtn.Parent = holder
        Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(1, -72, 1, 0)
        valLbl.Position = UDim2.new(0, 34, 0, 0)
        valLbl.BackgroundColor3 = Color3.fromRGB(35, 28, 50)
        valLbl.BorderSizePixel = 0
        valLbl.Text = "—"
        valLbl.TextColor3 = Color3.fromRGB(240, 230, 255)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 11
        valLbl.TextTruncate = Enum.TextTruncate.AtEnd
        valLbl.ZIndex = 13
        valLbl.Parent = holder
        Instance.new("UICorner", valLbl).CornerRadius = UDim.new(0, 6)

        local rightBtn = Instance.new("TextButton")
        rightBtn.Size = UDim2.new(0, 30, 1, 0)
        rightBtn.Position = UDim2.new(1, -30, 0, 0)
        rightBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
        rightBtn.TextColor3 = Color3.fromRGB(220, 210, 255)
        rightBtn.Font = Enum.Font.GothamBold
        rightBtn.TextSize = 14
        rightBtn.Text = "▶"
        rightBtn.ZIndex = 13
        rightBtn.Parent = holder
        Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 6)

        ry = ry + 34
        return leftBtn, valLbl, rightBtn
    end

    local demoFolder, demoBlocks = nil, {}

    local function refreshDemo()
        if demoFolder then demoFolder:Destroy() end
        local col = P.COLORS[shopState.colorIndex]
        local c3 = col.c or Color3.fromRGB(0, 180, 255)
        if col.rainbow then c3 = Color3.fromHSV((tick()*0.2) % 1, 0.9, 1) end
        local sizeMult = P.SHAPE_SIZE[shopState.sizeIndex].factor
        demoFolder, demoBlocks = buildDemoRing(world, shopState.shapeIndex, c3, sizeMult, 8)
    end

    local refreshShapeLbl

    local catL, catV, catR = shopRow("📁 КАТЕГОРИЯ")
    local shopShapeIdx = 1
    local function refreshShopShapeList()
        local list = getShopShapes()
        if #list == 0 then shopShapeIdx = 1; return end
        shopShapeIdx = math.clamp(shopShapeIdx, 1, #list)
        shopState.shapeIndex = list[shopShapeIdx]
    end
    local function updateCat() catV.Text = SHOP_CATEGORIES[shopState.categoryIndex].name end
    onClick(catL, function()
        shopState.categoryIndex = shopState.categoryIndex - 1
        if shopState.categoryIndex < 1 then shopState.categoryIndex = #SHOP_CATEGORIES end
        shopShapeIdx = 1
        updateCat(); refreshShopShapeList(); refreshShapeLbl(); refreshDemo()
    end)
    onClick(catR, function()
        shopState.categoryIndex = shopState.categoryIndex + 1
        if shopState.categoryIndex > #SHOP_CATEGORIES then shopState.categoryIndex = 1 end
        shopShapeIdx = 1
        updateCat(); refreshShopShapeList(); refreshShapeLbl(); refreshDemo()
    end)

    local sL, sV, sR = shopRow("🔷 ФИГУРА")
    local buyShapeBtn = Instance.new("TextButton")
    buyShapeBtn.Size = UDim2.new(1, -12, 0, 28)
    buyShapeBtn.Position = UDim2.new(0, 6, 0, ry)
    buyShapeBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 90)
    buyShapeBtn.TextColor3 = Color3.fromRGB(255, 220, 150)
    buyShapeBtn.Font = Enum.Font.GothamBold
    buyShapeBtn.TextSize = 11
    buyShapeBtn.Text = "🔓 КУПИТЬ: ---"
    buyShapeBtn.ZIndex = 12
    buyShapeBtn.Parent = rightPanel
    Instance.new("UICorner", buyShapeBtn).CornerRadius = UDim.new(0, 6)
    ry = ry + 32

    refreshShapeLbl = function()
        refreshShopShapeList()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp then return end
        sV.Text = sp.name
        local owned = ORBIT.OWNED_SHAPES[sp.name]
        local price = SHAPE_PRICES[sp.name] or 0
        if owned then
            buyShapeBtn.Text = "✅ УЖЕ КУПЛЕНО"
            buyShapeBtn.BackgroundColor3 = Color3.fromRGB(40,70,50)
            buyShapeBtn.TextColor3 = Color3.fromRGB(160,255,180)
        elseif price == 0 then
            buyShapeBtn.Text = "🆓 БЕСПЛАТНО (нажми)"
            buyShapeBtn.BackgroundColor3 = Color3.fromRGB(40,60,60)
            buyShapeBtn.TextColor3 = Color3.fromRGB(180,230,255)
        else
            buyShapeBtn.Text = "💰 КУПИТЬ за " .. price
            buyShapeBtn.BackgroundColor3 = Color3.fromRGB(60,45,90)
            buyShapeBtn.TextColor3 = Color3.fromRGB(255,220,150)
        end
    end

    onClick(sL, function()
        local list = getShopShapes()
        if #list == 0 then return end
        shopShapeIdx = shopShapeIdx - 1
        if shopShapeIdx < 1 then shopShapeIdx = #list end
        shopState.shapeIndex = list[shopShapeIdx]
        refreshShapeLbl(); refreshDemo()
    end)
    onClick(sR, function()
        local list = getShopShapes()
        if #list == 0 then return end
        shopShapeIdx = shopShapeIdx + 1
        if shopShapeIdx > #list then shopShapeIdx = 1 end
        shopState.shapeIndex = list[shopShapeIdx]
        refreshShapeLbl(); refreshDemo()
    end)

    onClick(buyShapeBtn, function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if not sp then return end
        if ORBIT.OWNED_SHAPES[sp.name] then
            ORBIT.notify("✅ Уже куплено", Color3.fromRGB(160,255,180), 2)
            return
        end
        local price = SHAPE_PRICES[sp.name] or 0
        if price > 0 and (ORBIT.COINS or 0) < price then
            ORBIT.notify("❌ Нужно " .. price .. " монет", Color3.fromRGB(255,100,100), 3)
            return
        end
        if price > 0 then ORBIT.COINS = ORBIT.COINS - price end
        ORBIT.OWNED_SHAPES[sp.name] = true
        saveStorage()
        if ORBIT.playBuy then pcall(ORBIT.playBuy) end
        ORBIT.notify("✅ Куплено: " .. sp.name, Color3.fromRGB(160,255,180), 3)
        coinsLbl.Text = "💰 " .. (ORBIT.COINS or 0)
        refreshShapeLbl()
    end)

    local cL, cV, cR = shopRow("🎨 ЦВЕТ КОЛЬЦА")
    local function updateColor() cV.Text = P.COLORS[shopState.colorIndex].name end
    onClick(cL, function()
        shopState.colorIndex = shopState.colorIndex - 1
        if shopState.colorIndex < 1 then shopState.colorIndex = #P.COLORS end
        updateColor(); refreshDemo()
    end)
    onClick(cR, function()
        shopState.colorIndex = shopState.colorIndex + 1
        if shopState.colorIndex > #P.COLORS then shopState.colorIndex = 1 end
        updateColor(); refreshDemo()
    end)

    local zL, zV, zR = shopRow("🔍 РАЗМЕР ФИГУРЫ")
    local function updateSize() zV.Text = P.SHAPE_SIZE[shopState.sizeIndex].name end
    onClick(zL, function()
        shopState.sizeIndex = shopState.sizeIndex - 1
        if shopState.sizeIndex < 1 then shopState.sizeIndex = #P.SHAPE_SIZE end
        updateSize(); refreshDemo()
    end)
    onClick(zR, function()
        shopState.sizeIndex = shopState.sizeIndex + 1
        if shopState.sizeIndex > #P.SHAPE_SIZE then shopState.sizeIndex = 1 end
        updateSize(); refreshDemo()
    end)

    local spL, spV, spR = shopRow("⚡ СКОРОСТЬ")
    local function updateSpeed() spV.Text = P.SPEED[shopState.speedIndex].name end
    onClick(spL, function()
        shopState.speedIndex = shopState.speedIndex - 1
        if shopState.speedIndex < 1 then shopState.speedIndex = #P.SPEED end
        updateSpeed()
    end)
    onClick(spR, function()
        shopState.speedIndex = shopState.speedIndex + 1
        if shopState.speedIndex > #P.SPEED then shopState.speedIndex = 1 end
        updateSpeed()
    end)

    local effectsLbl = Instance.new("TextLabel")
    effectsLbl.Size = UDim2.new(1, -12, 0, 18)
    effectsLbl.Position = UDim2.new(0, 6, 0, ry)
    effectsLbl.BackgroundTransparency = 1
    effectsLbl.Text = "✨ ЭФФЕКТЫ"
    effectsLbl.TextColor3 = Color3.fromRGB(220, 220, 250)
    effectsLbl.Font = Enum.Font.GothamBold
    effectsLbl.TextSize = 11
    effectsLbl.TextXAlignment = Enum.TextXAlignment.Left
    effectsLbl.ZIndex = 12
    effectsLbl.Parent = rightPanel
    ry = ry + 20

    local function shopToggle(text, getter, setter)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 28)
        b.Position = UDim2.new(0, 6, 0, ry)
        b.BackgroundColor3 = getter() and Color3.fromRGB(40,70,50) or Color3.fromRGB(45,38,55)
        b.TextColor3 = getter() and Color3.fromRGB(160,255,180) or Color3.fromRGB(220,200,220)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = text .. ": " .. (getter() and "ВКЛ" or "ВЫКЛ")
        b.ZIndex = 12
        b.Parent = rightPanel
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        onClick(b, function()
            setter(not getter())
            b.BackgroundColor3 = getter() and Color3.fromRGB(40,70,50) or Color3.fromRGB(45,38,55)
            b.TextColor3 = getter() and Color3.fromRGB(160,255,180) or Color3.fromRGB(220,200,220)
            b.Text = text .. ": " .. (getter() and "ВКЛ" or "ВЫКЛ")
        end)
        ry = ry + 32
    end

    shopToggle("🌠 Трейлы", function() return shopState.trail end, function(v) shopState.trail = v end)
    shopToggle("💡 Свет", function() return shopState.light end, function(v) shopState.light = v end)
    shopToggle("💓 Пульсация", function() return shopState.pulse end, function(v) shopState.pulse = v end)

    rightPanel.CanvasSize = UDim2.new(0, 0, 0, ry + 20)

    local animConn
    animConn = RunService.Heartbeat:Connect(function(dt)
        if not shopOpen or not shopGui or not shopGui.Parent then
            if animConn then animConn:Disconnect() end
            return
        end
        local t = tick()
        if avatar then
            pcall(function()
                local rootPart = avatar.PrimaryPart or avatar:FindFirstChild("HumanoidRootPart") or avatar:FindFirstChild("Torso")
                if rootPart then
                    avatar:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(t * 20) % (math.pi*2), 0))
                end
            end)
        end
        local col = P.COLORS[shopState.colorIndex]
        local c3 = col.c or Color3.fromRGB(0, 180, 255)
        if col.rainbow then c3 = Color3.fromHSV((t*0.2) % 1, 0.9, 1) end
        for _, b in ipairs(demoBlocks) do
            local angle = math.rad(t * 90 + b.angleOffset)
            local pos = Vector3.new(math.cos(angle)*2.2, 1.5, math.sin(angle)*2.2)
            local cf = CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi/2, 0)
            if b.isModel and b.model then
                pcall(function() b.model:PivotTo(cf) end)
                if b.bodyParts then
                    for _, p in ipairs(b.bodyParts) do
                        if not p:GetAttribute("NoRecolor") then p.Color = c3 end
                    end
                end
            elseif b.part then
                b.part.CFrame = cf
                b.part.Color = c3
            end
        end
    end)

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, rightW, 0, 36)
    cancelBtn.Position = UDim2.new(0, rightX, 1, -46)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 35, 45)
    cancelBtn.TextColor3 = Color3.fromRGB(255, 180, 190)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 12
    cancelBtn.Text = "❌ ОТМЕНА"
    cancelBtn.ZIndex = 11
    cancelBtn.Parent = shopGui
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)

    local applyBtn = Instance.new("TextButton")
    applyBtn.Size = UDim2.new(0, rightW, 0, 36)
    applyBtn.Position = UDim2.new(0, rightX, 1, -46)
    applyBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 55)
    applyBtn.TextColor3 = Color3.fromRGB(180, 255, 200)
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.TextSize = 12
    applyBtn.Text = "✅ ПРИМЕНИТЬ (кольцо 1)"
    applyBtn.ZIndex = 11
    applyBtn.Parent = shopGui
    Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 10)

    if IS_MOBILE then
        cancelBtn.Size = UDim2.new(0.5, -20, 0, 36)
        cancelBtn.Position = UDim2.new(0, 16, 1, -46)
        applyBtn.Size = UDim2.new(0.5, -20, 0, 36)
        applyBtn.Position = UDim2.new(0.5, 4, 1, -46)
    end

    local function closeShop()
        shopOpen = false
        if animConn then animConn:Disconnect() end
        if shopGui then shopGui:Destroy(); shopGui = nil end
    end

    onClick(closeBtn, closeShop)
    onClick(cancelBtn, closeShop)

    onClick(applyBtn, function()
        local sp = SHAPE_PRESETS[shopState.shapeIndex]
        if sp and not ORBIT.OWNED_SHAPES[sp.name] then
            local price = SHAPE_PRICES[sp.name] or 0
            if price > 0 then
                ORBIT.notify("🔒 Сначала купи «" .. sp.name .. "»", Color3.fromRGB(255,180,120), 3)
                return
            end
        end
        ORBIT.shapeIndex = shopState.shapeIndex
        P.colorIndex = shopState.colorIndex
        P.shapeSizeIndex = shopState.sizeIndex
        SETTINGS.SpeedMultiplier = P.SPEED[shopState.speedIndex].value
        SETTINGS.TrailEnabled = shopState.trail
        SETTINGS.LightEnabled = shopState.light
        SETTINGS.PulseEnabled = shopState.pulse

        rings[1].shapeIndex = shopState.shapeIndex
        ORBIT.destroyRing(1); ORBIT.buildRing(1)
        ORBIT.applyColor(); ORBIT.applyNameVisibility()

        ORBIT.notify("✅ Применено к кольцу 1!", Color3.fromRGB(180,255,180), 3)
        closeShop()
    end)

    updateCat(); refreshShapeLbl(); updateColor(); updateSize(); updateSpeed(); refreshDemo()
end

-- ============================================================
--       2D-РЕДАКТОР v3
-- ============================================================
local editorOpen = false
local editorGui
local editorConns = {}
local P2 = "Orbit2D_"

local GRID_OPTIONS = {16, 20, 24}
local GRID = 16

local Ed2D = {
    Cells = {},
    Tool = "paint",
    Brush = 1,
    Color = 1,
    States = {}, StateIdx = 0, MaxHistory = 20,
}

local function resizeGrid(newN)
    local oldCells = Ed2D.Cells
    local oldN = #oldCells
    Ed2D.Cells = {}
    for r = 1, newN do
        Ed2D.Cells[r] = {}
        for c = 1, newN do Ed2D.Cells[r][c] = 0 end
    end
    for r = 1, math.min(oldN, newN) do
        for c = 1, math.min(oldN, newN) do
            if oldCells[r] and oldCells[r][c] then
                Ed2D.Cells[r][c] = oldCells[r][c]
            end
        end
    end
    GRID = newN
end

local function snapshot2D()
    local s = {}
    for r = 1, GRID do
        s[r] = {}
        for c = 1, GRID do s[r][c] = Ed2D.Cells[r][c] end
    end
    return s
end
local function restore2D(s)
    for r = 1, GRID do
        for c = 1, GRID do Ed2D.Cells[r][c] = (s[r] and s[r][c]) or 0 end
    end
end
local function resetHistory2D()
    Ed2D.States = {snapshot2D()}
    Ed2D.StateIdx = 1
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
end
local function commit2D()
    while #Ed2D.States > Ed2D.StateIdx do table.remove(Ed2D.States) end
    table.insert(Ed2D.States, snapshot2D())
    Ed2D.StateIdx = #Ed2D.States
    while #Ed2D.States > Ed2D.MaxHistory + 1 do
        table.remove(Ed2D.States, 1)
        Ed2D.StateIdx = Ed2D.StateIdx - 1
    end
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
end
local function do2DUndo()
    if Ed2D.StateIdx <= 1 then return false end
    Ed2D.StateIdx = Ed2D.StateIdx - 1
    restore2D(Ed2D.States[Ed2D.StateIdx])
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
    return true
end
local function do2DRedo()
    if Ed2D.StateIdx >= #Ed2D.States then return false end
    Ed2D.StateIdx = Ed2D.StateIdx + 1
    restore2D(Ed2D.States[Ed2D.StateIdx])
    if Ed2D.OnHistory then pcall(Ed2D.OnHistory) end
    return true
end

resizeGrid(GRID)
resetHistory2D()

local function floodFill2D(r0, c0, newColor)
    local old = Ed2D.Cells[r0][c0]
    if old == newColor then return false end
    local stack = {{r0, c0}}
    local seen = {}
    while #stack > 0 do
        local p = table.remove(stack)
        local r, c = p[1], p[2]
        if r >= 1 and r <= GRID and c >= 1 and c <= GRID then
            local k = r * 100 + c
            if not seen[k] and Ed2D.Cells[r][c] == old then
                seen[k] = true
                Ed2D.Cells[r][c] = newColor
                table.insert(stack, {r + 1, c})
                table.insert(stack, {r - 1, c})
                table.insert(stack, {r, c + 1})
                table.insert(stack, {r, c - 1})
            end
        end
    end
    return true
end

local HEART_PATTERN = {
    "01100110", "11111111", "11111111", "11111111",
    "01111110", "00111100", "00011000",
}
local SMILE_PATTERN = {
    "00111100", "01111110", "11211211", "11111111",
    "12111121", "11222211", "01111110", "00111100",
}

local function openEditor()
    if editorOpen and editorGui and editorGui.Parent then return end
    editorOpen = true
    Ed2D.Open = true
    editorConns = {}

    local editorW = IS_MOBILE and 360 or 700
    local editorH = IS_MOBILE and 620 or 470

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do
            if k ~= "Name" then o[k] = v end
        end
        o.Name = P2 .. ((props and props.Name) or class)
        if parent then
            if o:IsA("GuiObject") and not (props and props.ZIndex) and parent:IsA("GuiObject") then
                o.ZIndex = parent.ZIndex + 1
            end
            o.Parent = parent
        end
        return o
    end
    local function corner(o, r) return mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end

    editorGui = mk("Frame", {
        Name = "Window", Size = UDim2.new(0, editorW, 0, editorH),
        Position = UDim2.new(0.5, -editorW / 2, 0.5, -editorH / 2),
        BackgroundColor3 = Color3.fromRGB(22, 16, 35), BackgroundTransparency = 0.05,
        BorderSizePixel = 0, ZIndex = 20, Active = true,
    }, nil)
    editorGui.Name = "_OrbitEditor2D"
    editorGui.Parent = screenGui
    corner(editorGui, 16)
    mk("UIStroke", {Color = Color3.fromRGB(180, 130, 255), Thickness = 2}, editorGui)
    if ORBIT.ui.fitToScreen then pcall(ORBIT.ui.fitToScreen, editorGui, editorW, editorH) end

    local function closeEditor()
        editorOpen = false
        Ed2D.Open = false
        Ed2D.SetGridSize = nil
        for _, cn in ipairs(editorConns) do pcall(function() cn:Disconnect() end) end
        editorConns = {}
        Ed2D.OnHistory = nil
        if editorGui then pcall(function() editorGui:Destroy() end) end
        editorGui = nil
    end

    mk("TextLabel", {
        Name = "Title", Size = UDim2.new(1, -200, 0, 26), Position = UDim2.new(0, 16, 0, 8),
        BackgroundTransparency = 1, Text = "🎨 2D-РЕДАКТОР", TextColor3 = Color3.fromRGB(230, 200, 255),
        Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
    }, editorGui)

    local to3DBtn = mk("TextButton", {
        Name = "To3D", Size = UDim2.new(0, 130, 0, 30), Position = UDim2.new(1, -180, 0, 6),
        BackgroundColor3 = Color3.fromRGB(80, 45, 130), TextColor3 = Color3.fromRGB(230, 200, 255),
        Font = Enum.Font.GothamBold, TextSize = 11, Text = "🔮 3D-РЕДАКТОР",
        AutoButtonColor = false, BorderSizePixel = 0,
    }, editorGui)
    corner(to3DBtn, 8)
    onClick(to3DBtn, function()
        if ORBIT.openEditor3D then ORBIT.openEditor3D()
        else ORBIT.notify("❌ 3D-Редактор не загружен", Color3.fromRGB(255,120,120), 2) end
    end)

    local closeBtn = mk("TextButton", {
        Name = "Close", Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -40, 0, 6),
        BackgroundColor3 = Color3.fromRGB(80, 30, 30), TextColor3 = Color3.fromRGB(255, 160, 160),
        Font = Enum.Font.GothamBold, TextSize = 16, Text = "✖", AutoButtonColor = false,
        BorderSizePixel = 0,
    }, editorGui)
    corner(closeBtn, 8)
    onClick(closeBtn, closeEditor)

    local leftX, topY = 16, 42
    local gridPx = IS_MOBILE and 328 or 400
    local pitch = 1

    local gridHolder = mk("Frame", {
        Name = "GridHolder", Size = UDim2.new(0, gridPx, 0, gridPx), Position = UDim2.new(0, leftX, 0, topY),
        BackgroundColor3 = Color3.fromRGB(14, 10, 24), BorderSizePixel = 0,
    }, editorGui)
    corner(gridHolder, 6)
    mk("UIStroke", {Color = Color3.fromRGB(120, 90, 180), Thickness = 2, Transparency = 0.3}, gridHolder)

    local cellLayer = mk("Frame", {
        Name = "CellLayer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    }, gridHolder)

    local cellFrames = {}
    local EMPTY_COLOR = Color3.fromRGB(30, 24, 46)

    local function refreshCell(r, c)
        local f = cellFrames[r] and cellFrames[r][c]
        if not f then return end
        local v = Ed2D.Cells[r][c]
        f.BackgroundColor3 = (v == 0) and EMPTY_COLOR or (PALETTE[v] or Color3.fromRGB(255, 255, 255))
    end
    local function refreshAllCells()
        for r = 1, GRID do for c = 1, GRID do refreshCell(r, c) end end
    end

    local function rebuildGridUI()
        cellLayer:ClearAllChildren()
        cellFrames = {}
        pitch = math.floor((gridPx - 2) / GRID)
        local used = pitch * GRID + 2
        gridHolder.Size = UDim2.new(0, used, 0, used)

        for r = 1, GRID do
            cellFrames[r] = {}
            for c = 1, GRID do
                local f = mk("Frame", {
                    Name = "Cell", BackgroundColor3 = EMPTY_COLOR, BorderSizePixel = 0,
                    Size = UDim2.new(0, pitch - 2, 0, pitch - 2),
                    Position = UDim2.new(0, (c - 1) * pitch + 2, 0, (r - 1) * pitch + 2),
                }, cellLayer)
                local st = mk("UIStroke", {
                    Color = Color3.fromRGB(60, 50, 85), Thickness = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }, f)
                if c % 4 == 1 or r % 4 == 1 then
                    st.Color = Color3.fromRGB(90, 70, 140)
                    st.Thickness = 1.5
                end
                cellFrames[r][c] = f
            end
        end
        refreshAllCells()
    end

    local countLbl
    local function countFilled()
        local n = 0
        for r = 1, GRID do for c = 1, GRID do
            if Ed2D.Cells[r][c] > 0 then n = n + 1 end
        end end
        return n
    end
    local function refreshCount()
        if countLbl then countLbl.Text = "🧱 клеток: " .. countFilled() end
    end

    local function paintCell(r, c, val)
        if r < 1 or r > GRID or c < 1 or c > GRID then return false end
        if Ed2D.Cells[r][c] == val then return false end
        Ed2D.Cells[r][c] = val
        refreshCell(r, c)
        return true
    end

    local function stampBrush(r, c, color)
        local n = Ed2D.Brush or 1
        local lo = -math.floor((n - 1) / 2)
        local hi = lo + n - 1
        local changed = false
        for dr = lo, hi do
            for dc = lo, hi do
                if paintCell(r + dr, c + dc, color) then changed = true end
            end
        end
        return changed
    end

    local function applyTool(r, c, isStart)
        local tool = Ed2D.Tool
        local changed = false
        if tool == "fill" then
            if isStart and floodFill2D(r, c, Ed2D.Color) then
                changed = true
                refreshAllCells()
            end
        elseif tool == "pick" then
            if isStart then
                local row = Ed2D.Cells[r]
                local idx = row and row[c] or 0
                if idx > 0 then
                    Ed2D.Color = idx
                    if Ed2D.refreshPal then Ed2D.refreshPal() end
                    Ed2D.Tool = "paint"
                    if Ed2D.paintTools then Ed2D.paintTools() end
                end
            end
        elseif tool == "eraser" then
            changed = stampBrush(r, c, 0)
        else
            changed = stampBrush(r, c, Ed2D.Color)
        end
        return changed
    end

    local overlay = mk("TextButton", {
        Name = "Overlay", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = gridHolder.ZIndex + 5,
    }, gridHolder)

    local painting, activeInput, lastR, lastC, strokeChanged = false, nil, 0, 0, false

    local function cellFromPos(pos)
        local ab = gridHolder.AbsolutePosition
        local lx, ly = pos.X - ab.X - 2, pos.Y - ab.Y - 2
        if lx < 0 or ly < 0 then return nil end
        local c = math.floor(lx / pitch) + 1
        local r = math.floor(ly / pitch) + 1
        if r < 1 or r > GRID or c < 1 or c > GRID then return nil end
        return r, c
    end

    local function endStroke()
        if not painting then return end
        painting, activeInput = false, nil
        if strokeChanged then
            commit2D()
            refreshCount()
        end
        strokeChanged = false
    end

    overlay.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        if painting then return end
        local r, c = cellFromPos(input.Position)
        if not r then return end
        painting, activeInput = true, input
        strokeChanged = false
        lastR, lastC = r, c
        if applyTool(r, c, true) then strokeChanged = true end
    end)

    overlay.InputChanged:Connect(function(input)
        if not painting then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == activeInput) then
            local r, c = cellFromPos(input.Position)
            if r and (r ~= lastR or c ~= lastC) then
                lastR, lastC = r, c
                if applyTool(r, c, false) then strokeChanged = true end
            end
        end
    end)

    overlay.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == activeInput) then
            endStroke()
        end
    end)
    table.insert(editorConns, UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == activeInput) then
            endStroke()
        end
    end))

    local ctrlX = IS_MOBILE and 16 or (leftX + gridPx + 12)
    local ctrlY = IS_MOBILE and (topY + gridPx + 8) or topY
    local ctrlW = IS_MOBILE and (editorW - 32) or (editorW - ctrlX - 16)
    local ctrlH = IS_MOBILE and (editorH - ctrlY - 8) or (editorH - topY - 10)

    local ctrl = mk("ScrollingFrame", {
        Name = "Ctrl", Size = UDim2.new(0, ctrlW, 0, ctrlH), Position = UDim2.new(0, ctrlX, 0, ctrlY),
        BackgroundColor3 = Color3.fromRGB(18, 14, 30), BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255),
    }, editorGui)
    corner(ctrl, 10)
    local list = mk("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, ctrl)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10),
    }, ctrl)
    local function fitCanvas()
        ctrl.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 18)
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)

    local secOrder = 0
    local BTN_SCALE = 1.12
    local function sc(v) return math.floor(v * BTN_SCALE + 0.5) end

    local function section(txt, color, bodyH)
        secOrder = secOrder + 1
        bodyH = sc(bodyH)
        local f = mk("Frame", {
            Name = "Sec", Size = UDim2.new(1, 0, 0, 28 + bodyH), BackgroundTransparency = 1,
            LayoutOrder = secOrder,
        }, ctrl)
        local l = mk("TextLabel", {
            Name = "SecTitle", Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.25),
            BackgroundTransparency = 0.05, BorderSizePixel = 0, Text = "  " .. txt,
            TextColor3 = Color3.fromRGB(255, 250, 255), Font = Enum.Font.GothamBold, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        corner(l, 5)
        return mk("Frame", {
            Name = "Body", Size = UDim2.new(1, 0, 0, bodyH), Position = UDim2.new(0, 0, 0, 28),
            BackgroundTransparency = 1,
        }, f), l
    end

    local BTN = Color3.fromRGB(45, 38, 65)
    local BTN_OFF = Color3.fromRGB(34, 30, 46)

    local function markActive(b, on)
        if not b then return end
        local base = b:GetAttribute("BaseText")
        if not base then base = b.Text; b:SetAttribute("BaseText", base) end
        local st = b:FindFirstChild("ActiveStroke")
        if not st then
            st = Instance.new("UIStroke"); st.Name = "ActiveStroke"; st.Thickness = 2.5
            st.Color = Color3.fromRGB(255, 255, 255); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.Parent = b
        end
        st.Enabled = on and true or false
        b.Text = on and ("✓ " .. base) or base
    end

    local function buttonRow(body, items, y, h, textSize)
        local btns = {}
        local n = #items
        for i, it in ipairs(items) do
            local b = mk("TextButton", {
                Name = "Btn", Size = UDim2.new(1 / n, -4, 0, sc(h or 32)),
                Position = UDim2.new((i - 1) / n, 2, 0, sc(y or 0)),
                BackgroundColor3 = it.color or BTN, TextColor3 = Color3.fromRGB(225, 215, 255),
                Font = Enum.Font.GothamBold, TextSize = textSize or 11, Text = it.text,
                TextWrapped = true, AutoButtonColor = false, BorderSizePixel = 0,
            }, body)
            corner(b, 6)
            onClick(b, it.fn)
            btns[i] = b
        end
        return btns
    end

    -- 📐 РАЗМЕР СЕТКИ
    do
        local body = section("📐 РАЗМЕР СЕТКИ", Color3.fromRGB(60, 80, 120), 32)
        local btns = {}
        local function paintSizes()
            for i, n in ipairs(GRID_OPTIONS) do
                btns[i].BackgroundColor3 = (n == GRID) and Color3.fromRGB(80, 120, 180) or BTN
                markActive(btns[i], n == GRID)
            end
        end
        local function setSize(n)
            if n == GRID then return end
            resizeGrid(n)
            resetHistory2D()
            rebuildGridUI()
            paintSizes()
            refreshCount()
            ORBIT.notify("📐 Сетка: " .. n .. "×" .. n, Color3.fromRGB(180, 220, 255), 1.5)
        end
        local items = {}
        for i, n in ipairs(GRID_OPTIONS) do
            items[i] = {text = n .. "×" .. n, fn = function() setSize(n) end}
        end
        btns = buttonRow(body, items, 0, 32, 12)
        paintSizes()
        Ed2D.SetGridSize = function(n)
            for _, g in ipairs(GRID_OPTIONS) do
                if g == n then setSize(n); return true end
            end
            return false
        end
    end

    -- 🎨 ПАЛИТРА
    local swatch
    do
        local body, titleLbl = section("🎨 ПАЛИТРА", Color3.fromRGB(100, 60, 140), 54)
        body.Parent.LayoutOrder = 0
        swatch = mk("Frame", {
            Name = "Swatch", Size = UDim2.new(0, 26, 0, 12), Position = UDim2.new(1, -30, 0, 3),
            BackgroundColor3 = PALETTE[Ed2D.Color], BorderSizePixel = 0,
        }, titleLbl)
        corner(swatch, 3)
        mk("UIStroke", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1}, swatch)

        local palScroll = mk("ScrollingFrame", {
            Name = "Pal", Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = Color3.fromRGB(15, 12, 24),
            BorderSizePixel = 0, CanvasSize = UDim2.new(0, #PALETTE * 42 + 12, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4,
            ScrollBarImageColor3 = Color3.fromRGB(160, 130, 255),
        }, body)
        corner(palScroll, 8)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, palScroll)
        mk("UIPadding", {
            PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
        }, palScroll)

        local strokes = {}
        local function refreshPal()
            for i, st in ipairs(strokes) do
                local on = (i == Ed2D.Color)
                st.Thickness = on and 3 or 1
                st.Transparency = on and 0 or 0.8
            end
            swatch.BackgroundColor3 = PALETTE[Ed2D.Color]
            titleLbl.Text = " 🎨 " .. COLOR_NAMES[Ed2D.Color]
        end
        for i, col in ipairs(PALETTE) do
            local b = mk("TextButton", {
                Name = "Col", Size = UDim2.new(0, 38, 0, 38), BackgroundColor3 = col,
                Text = "", BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i,
            }, palScroll)
            corner(b, 6)
            strokes[i] = mk("UIStroke", {
                Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.8,
            }, b)
            onClick(b, function()
                Ed2D.Color = i
                if Ed2D.Tool == "eraser" or Ed2D.Tool == "pick" then Ed2D.Tool = "paint"; if Ed2D.paintTools then Ed2D.paintTools() end end
                refreshPal()
            end)
        end
        refreshPal()
        Ed2D.refreshPal = refreshPal
    end

    -- 🔲 РАЗМЕР КИСТИ
    do
        local body = section("🔲 РАЗМЕР КИСТИ", Color3.fromRGB(100, 80, 40), 38)
        local btns = {}
        Ed2D.paintBrush = function()
            for i = 1, 5 do
                btns[i].BackgroundColor3 = (Ed2D.Brush == i) and Color3.fromRGB(100, 80, 160) or BTN
                markActive(btns[i], Ed2D.Brush == i)
            end
        end
        local items = {}
        for i = 1, 5 do
            items[i] = {text = i .. "×" .. i, fn = function() Ed2D.Brush = i; Ed2D.paintBrush() end}
        end
        btns = buttonRow(body, items, 0, 38, 13)
        Ed2D.paintBrush()
    end

    -- 🛠 ИНСТРУМЕНТ
    do
        local body = section("🛠 ИНСТРУМЕНТ", Color3.fromRGB(120, 90, 50), 38)
        local tools = {
            {key = "paint",  text = "🖌 Кисть"},
            {key = "eraser", text = "🧽 Ластик"},
            {key = "fill",   text = "🪣 Заливка"},
            {key = "pick",   text = "💧 Пипетка"},
        }
        local onColor = {
            paint = Color3.fromRGB(100, 80, 160), eraser = Color3.fromRGB(150, 60, 60),
            fill = Color3.fromRGB(80, 130, 80), pick = Color3.fromRGB(70, 120, 150),
        }
        local btns = {}
        Ed2D.paintTools = function()
            for i, t in ipairs(tools) do
                btns[i].BackgroundColor3 = (Ed2D.Tool == t.key) and onColor[t.key] or BTN
                markActive(btns[i], Ed2D.Tool == t.key)
            end
        end
        local items = {}
        for i, t in ipairs(tools) do
            items[i] = {text = t.text, fn = function() Ed2D.Tool = t.key; Ed2D.paintTools() end}
        end
        btns = buttonRow(body, items, 0, 38, 11)
        Ed2D.paintTools()
    end

    -- ↩️ ИСТОРИЯ
    do
        local body = section("↩️ ИСТОРИЯ", Color3.fromRGB(60, 90, 60), 32)
        local hb = buttonRow(body, {
            {text = "↶ Отмена", color = BTN_OFF, fn = function()
                if do2DUndo() then refreshAllCells(); refreshCount() end
            end},
            {text = "↷ Вернуть", color = BTN_OFF, fn = function()
                if do2DRedo() then refreshAllCells(); refreshCount() end
            end},
            {text = "🗑 Очистить", color = Color3.fromRGB(120, 45, 45), fn = function()
                for r = 1, GRID do for c = 1, GRID do Ed2D.Cells[r][c] = 0 end end
                commit2D(); refreshAllCells(); refreshCount()
            end},
        }, 0, 32, 11)
        Ed2D.OnHistory = function()
            local canUndo = Ed2D.StateIdx > 1
            local canRedo = Ed2D.StateIdx < #Ed2D.States
            hb[1].BackgroundColor3 = canUndo and Color3.fromRGB(70, 150, 220) or BTN_OFF
            hb[1].TextTransparency = canUndo and 0 or 0.55
            hb[2].BackgroundColor3 = canRedo and Color3.fromRGB(70, 190, 130) or BTN_OFF
            hb[2].TextTransparency = canRedo and 0 or 0.55
        end
        Ed2D.OnHistory()
    end

    -- ⚡ БЫСТРЫЕ ФОРМЫ
    do
        local body = section("⚡ БЫСТРЫЕ ФОРМЫ", Color3.fromRGB(140, 80, 40), 32)
        local function placeTemplate(pattern, colorMap)
            local offsetR = math.floor((GRID - #pattern) / 2)
            local offsetC = math.floor((GRID - #pattern[1]) / 2)
            for rr = 1, #pattern do
                for cc = 1, #pattern[rr] do
                    local ch = pattern[rr]:sub(cc, cc)
                    local idx = colorMap[ch]
                    if idx then
                        local r, c = offsetR + rr, offsetC + cc
                        if r >= 1 and r <= GRID and c >= 1 and c <= GRID then
                            Ed2D.Cells[r][c] = idx
                        end
                    end
                end
            end
            commit2D(); refreshAllCells(); refreshCount()
        end
        local purple = Color3.fromRGB(80, 60, 100)
        buttonRow(body, {
            {text = "↔ Симметрия", color = purple, fn = function()
                for r = 1, GRID do
                    for c = 1, math.floor(GRID / 2) do
                        Ed2D.Cells[r][GRID - c + 1] = Ed2D.Cells[r][c]
                    end
                end
                commit2D(); refreshAllCells(); refreshCount()
            end},
            {text = "❤ Сердце", color = purple, fn = function()
                placeTemplate(HEART_PATTERN, {["1"] = 1})
            end},
            {text = "☺ Смайл", color = purple, fn = function()
                placeTemplate(SMILE_PATTERN, {["1"] = 3, ["2"] = 21})
            end},
        }, 0, 32, 10)
    end

    -- 💾 СОХРАНЕНИЕ
    do
        local body = section("💾 СОХРАНЕНИЕ", Color3.fromRGB(100, 60, 140), 220)

        countLbl = mk("TextLabel", {
            Name = "Count", Size = UDim2.new(1, -4, 0, 16), Position = UDim2.new(0, 2, 0, 0),
            BackgroundTransparency = 1, Text = "🧱 клеток: 0", TextColor3 = Color3.fromRGB(180, 220, 255),
            Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        }, body)

        local nameInput = mk("TextBox", {
            Name = "NameInput", Size = UDim2.new(1, -4, 0, 32), Position = UDim2.new(0, 2, 0, 20),
            BackgroundColor3 = Color3.fromRGB(35, 30, 50), TextColor3 = Color3.fromRGB(230, 220, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, PlaceholderText = "✏️ Имя фигуры...",
            PlaceholderColor3 = Color3.fromRGB(150, 140, 180), Text = "", ClearTextOnFocus = false,
            BorderSizePixel = 0,
        }, body)
        corner(nameInput, 6)

        local saveBtn = mk("TextButton", {
            Name = "Save", Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, 58),
            BackgroundColor3 = Color3.fromRGB(60, 120, 80), TextColor3 = Color3.fromRGB(200, 255, 210),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "💾 СОХРАНИТЬ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(saveBtn, 8)

        local sellBtn = mk("TextButton", {
            Name = "Sell", Size = UDim2.new(1, -4, 0, 32), Position = UDim2.new(0, 2, 0, 100),
            BackgroundColor3 = Color3.fromRGB(90, 70, 30), TextColor3 = Color3.fromRGB(255, 220, 120),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "💰 ПРОДАТЬ +50",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(sellBtn, 8)

        local shareBtn = mk("TextButton", {
            Name = "Share", Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, 138),
            BackgroundColor3 = Color3.fromRGB(70, 60, 130), TextColor3 = Color3.fromRGB(220, 210, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "📤 ПОДЕЛИТЬСЯ ФИГУРОЙ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(shareBtn, 8)

        local importBtn = mk("TextButton", {
            Name = "Import", Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, 178),
            BackgroundColor3 = Color3.fromRGB(50, 80, 110), TextColor3 = Color3.fromRGB(200, 230, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "📥 ИМПОРТ ЧУЖОЙ ФИГУРЫ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(importBtn, 8)

        onClick(saveBtn, function()
            local data = {}
            local filled = 0
            for r = 1, GRID do
                data[r] = {}
                for c = 1, GRID do
                    data[r][c] = Ed2D.Cells[r][c]
                    if Ed2D.Cells[r][c] > 0 then filled = filled + 1 end
                end
            end
            if filled < 3 then
                ORBIT.notify("🎨 Закрась хотя бы 3 клетки", Color3.fromRGB(255,200,120), 2)
                return
            end
            local nm = nameInput.Text
            local len = utf8.len(nm)
            if nm == "" or not len or len > 20 then
                nm = "СВОЯ_" .. (#SHAPE_PRESETS + 1)
            end
            local base, n = nm, 1
            local function exists(x)
                for _, sp in ipairs(SHAPE_PRESETS) do if sp.name == x then return true end end
                return false
            end
            while exists(nm) do n = n + 1; nm = base .. "_" .. n end

            local shape = { name = nm, pixels = data }
            registerCustomShape(shape)
            ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
            table.insert(ORBIT.CUSTOM_SHAPES, shape)
            saveStorage()
            ORBIT.notify("🎨 Сохранено: " .. nm, Color3.fromRGB(180,255,220), 3)

            for i, sp in ipairs(SHAPE_PRESETS) do
                if sp.name == nm then
                    ORBIT.shapeIndex = i
                    pcall(function()
                        rings[1].shapeIndex = i
                        ORBIT.destroyRing(1); ORBIT.buildRing(1); ORBIT.applyColor()
                    end)
                    break
                end
            end
        end)

        onClick(sellBtn, function()
            if countFilled() < 8 then
                ORBIT.notify("🎨 Минимум 8 клеток", Color3.fromRGB(255,200,120), 2)
                return
            end
            ORBIT.COINS = (ORBIT.COINS or 0) + 50
            ORBIT.SESSION = ORBIT.SESSION or {}
            ORBIT.SESSION.coinsEarned = (ORBIT.SESSION.coinsEarned or 0) + 50
            saveStorage()
            ORBIT.notify("💰 +50 монет (всего: " .. ORBIT.COINS .. ")", Color3.fromRGB(255,220,120), 3)
            if ORBIT.playBuy then pcall(ORBIT.playBuy) end
        end)

        onClick(shareBtn, function()
            if not ORBIT.share or not ORBIT.share.encodeShape then
                ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255,150,150), 3)
                return
            end
            local data = {}
            local filled = 0
            for r = 1, GRID do
                data[r] = {}
                for c = 1, GRID do
                    data[r][c] = Ed2D.Cells[r][c]
                    if Ed2D.Cells[r][c] > 0 then filled = filled + 1 end
                end
            end
            if filled < 3 then
                ORBIT.notify("🎨 Сначала нарисуй фигуру", Color3.fromRGB(255,200,120), 2)
                return
            end
            local nm = nameInput.Text
            local len = utf8.len(nm)
            if nm == "" or not len or len > 20 then
                nm = "СВОЯ_" .. (#SHAPE_PRESETS + 1)
            end
            local str, err = ORBIT.share.encodeShape({
                name = nm,
                grid = GRID,
                pixels = data,
            })
            if not str then
                ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255,150,150), 3)
                return
            end
            ORBIT.share.open(str)
        end)

        onClick(importBtn, function()
            if not ORBIT.share or not ORBIT.share.open then
                ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255,150,150), 3)
                return
            end
            ORBIT.share.open()
        end)
    end

    rebuildGridUI()
    refreshCount()
    fitCanvas()
end

-- ============================================================
--       ПРИВЯЗКА
-- ============================================================
if ORBIT.ui.openShopBtn then
    onClick(ORBIT.ui.openShopBtn, function() openShop() end)
end
if ORBIT.ui.openEditorBtn then
    onClick(ORBIT.ui.openEditorBtn, function() openEditor() end)
end

ORBIT.openShop = openShop
ORBIT.openEditor = openEditor
Ed2D.GridOptions = GRID_OPTIONS
Ed2D.SetBrush = function(n)
    n = math.clamp(math.floor(tonumber(n) or 1), 1, 5)
    Ed2D.Brush = n
    if Ed2D.paintBrush then pcall(Ed2D.paintBrush) end
    return n
end
ORBIT.Editor2D = Ed2D
ORBIT.SHAPE_PRICES = SHAPE_PRICES
ORBIT.PALETTE = PALETTE
ORBIT.saveStorage = saveStorage

if ORBIT.notify then
    ORBIT.notify("🎨 2D + 🔮 3D редакторы v23.9", Color3.fromRGB(220,200,255), 3)
end

return true

end
do local ok, err = pcall(module_shop); Tools.shop = ok; if not ok then warn("[Orbit Tools] shop: " .. tostring(err)) end end
            
end

function H.close()
    if panel and panel.Parent then panel.Visible = false end
end

H.showHelp = function()
    H.open()
    if ORBIT.notify then
        ORBIT.notify("📖 Смотри окно помощника", Color3.fromRGB(200, 220, 255), 2)
    end
end

if not ORBIT.ui then ORBIT.ui = {} end
if not ORBIT.ui.applyStyleByName then
    local applyingFallback = false
    ORBIT.ui.applyStyleByName = function(name)
        if not name or applyingFallback then return false end
        local t = lower(name)
        for _, pair in ipairs(STYLE_KEYWORDS) do
            if containsWord(t, pair[1]) then
                applyingFallback = true
                pcall(H.interpret, "стиль " .. tostring(pair[2]))
                applyingFallback = false
                return true
            end
        end
        return false
    end
end

if ORBIT.notify then
    ORBIT.notify("🤖 Помощник v1.2 загружен (команда «помощь»)", Color3.fromRGB(200, 220, 255), 3)
end
warn("[Orbit Helper v1.2] Загружен ✅")
return true

end
do local ok, err = pcall(module_helper); Tools.helper = ok; if not ok then warn("[Orbit Tools] helper: " .. tostring(err)) end end
-- ═════════ МОДУЛЬ: editor3d (из orbit_editor3d.lua) ═════════
local function module_editor3d()
if ORBIT.Editor3D then return end
-- ОРБИТА v23.13 — 3D-РЕДАКТОР ФИГУР (orbit_editor3d.lua)
-- Открывается через ORBIT.openEditor3D().
-- Сетка N×N×N: 4..8 (легко), 16 (средне), 32 (тяжело), 64 (крайне тяжело).

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (type(getgenv) == "function" and getgenv().ORBIT)
if not ORBIT then warn("[Orbit 3D Editor] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit 3D Editor] UI не готов!"); return end

local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local screenGui   = ORBIT.ui.screenGui
local IS_MOBILE   = (ORBIT.PLATFORM == "mobile")
local PREFIX      = "Orbit3D_"

if ORBIT.Editor3D and ORBIT.Editor3D.Close then pcall(ORBIT.Editor3D.Close) end

-- ============================================================
--       ПАЛИТРА (24 уникальных цвета)
-- ============================================================
local PALETTE = {
    Color3.fromRGB(255, 60, 60),   Color3.fromRGB(255, 140, 40),
    Color3.fromRGB(255, 230, 60),  Color3.fromRGB(120, 255, 100),
    Color3.fromRGB(80, 255, 180),  Color3.fromRGB(80, 220, 255),
    Color3.fromRGB(60, 120, 255),  Color3.fromRGB(140, 80, 255),
    Color3.fromRGB(220, 80, 255),  Color3.fromRGB(255, 80, 180),
    Color3.fromRGB(255, 200, 200), Color3.fromRGB(255, 240, 200),
    Color3.fromRGB(200, 240, 255), Color3.fromRGB(200, 255, 220),
    Color3.fromRGB(200, 200, 255), Color3.fromRGB(240, 200, 255),
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 200, 200),
    Color3.fromRGB(120, 120, 130), Color3.fromRGB(60, 60, 70),
    Color3.fromRGB(30, 30, 40),    Color3.fromRGB(255, 200, 100),
    Color3.fromRGB(255, 240, 120), Color3.fromRGB(180, 130, 60),
}
local COLOR_NAMES = {
    "Красный", "Оранжевый", "Жёлтый", "Зелёный", "Изумруд", "Голубой",
    "Синий", "Фиолетовый", "Маджента", "Розовый",
    "Пастель-розовый", "Пастель-крем", "Пастель-голубой", "Пастель-мята",
    "Пастель-сиреневый", "Пастель-лаванда",
    "Белый", "Серый", "Тёмно-серый", "Тёмный", "Почти-чёрный",
    "Золотой", "Светло-золотой", "Бронзовый",
}

local C = {
    bg     = Color3.fromRGB(18, 14, 30),
    panel  = Color3.fromRGB(22, 16, 36),
    btn    = Color3.fromRGB(45, 38, 65),
    btnOn  = Color3.fromRGB(80, 140, 200),
    text   = Color3.fromRGB(225, 215, 255),
    title  = Color3.fromRGB(98, 66, 178),
    btnOff = Color3.fromRGB(34, 30, 46),
    accent = Color3.fromRGB(180, 130, 255),
}

local SIZES_ALLOWED   = {4, 5, 6, 7, 8, 16, 32, 64}
local BIG_THRESHOLD   = 16
local HUGE_THRESHOLD  = 32
local MAX_CELLS       = 5000
local MAX_HISTORY_BIG = 10
local MAX_HISTORY_STD = 20

local Ed = {
    Open = false, Gui = nil, Vp = nil, World = nil, Cam = nil,
    BlockFolder = nil, GridFolder = nil,
    N = 6, ActiveZ = 1, Mode = "place", Brush = 1,
    SymX = false, SymY = false, SymZ = false,
    Color = 1,
    Cells = {},
    Parts = {},
    States = {}, StateIdx = 0, MaxHistory = MAX_HISTORY_STD,
    Az = -45, El = 30, Dist = 16,
    Conns = {}, UI = {},
}

local HALF = Vector3.new(0.5, 0.5, 0.5)

local function key(x, y, z) return (x * 128 + y) * 128 + z end
local function cellCenter(x, y, z)
    local o = (Ed.N + 1) / 2
    return Vector3.new(x - o, y - o, z - o)
end
local function countCells()
    local n = 0
    for _ in pairs(Ed.Cells) do n = n + 1 end
    return n
end
local function defaultDist() return 4 + Ed.N * 2 end
local function isBig()  return Ed.N >= BIG_THRESHOLD end
local function isHuge() return Ed.N >= HUGE_THRESHOLD end

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Name" then o[k] = v end
    end
    o.Name = PREFIX .. ((props and props.Name) or class)
    if parent then
        if o:IsA("GuiObject") and not (props and props.ZIndex) and parent:IsA("GuiObject") then
            o.ZIndex = parent.ZIndex + 1
        end
        o.Parent = parent
    end
    return o
end

local function corner(o, r)
    return mk("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o)
end

local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        if ORBIT.playClick then pcall(ORBIT.playClick) end
        local ok, err = pcall(fn)
        if not ok then warn("[Orbit] " .. tostring(err)) end
    end
    local function inScroll()
        return releaseOnly or btn:GetAttribute("ReleaseOnly")
            or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil
    end
    btn.MouseButton1Down:Connect(function() if not inScroll() then call() end end)
    btn.MouseButton1Click:Connect(function() if inScroll() then call() end end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchStart = input.Position
            if not inScroll() then call() end
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and touchStart then
            local moved = (input.Position - touchStart).Magnitude
            touchStart = nil
            if inScroll() and moved < 12 then call() end
        end
    end)
    btn.Activated:Connect(call)
end

local function rayAABB(origin, direction, mn, mx)
    local o  = {origin.X, origin.Y, origin.Z}
    local d  = {direction.X, direction.Y, direction.Z}
    local lo = {mn.X, mn.Y, mn.Z}
    local hi = {mx.X, mx.Y, mx.Z}
    local tmin, tmax = -math.huge, math.huge
    for i = 1, 3 do
        if math.abs(d[i]) < 1e-8 then
            if o[i] < lo[i] or o[i] > hi[i] then return nil end
        else
            local t1 = (lo[i] - o[i]) / d[i]
            local t2 = (hi[i] - o[i]) / d[i]
            if t1 > t2 then t1, t2 = t2, t1 end
            if t1 > tmin then tmin = t1 end
            if t2 < tmax then tmax = t2 end
            if tmin > tmax then return nil end
        end
    end
    if tmax < 0 or tmin < 0 then return nil end
    return tmin
end

local function screenRay(px, py)
    local size = Ed.Vp.AbsoluteSize
    local nx = (px / math.max(size.X, 1)) * 2 - 1
    local ny = 1 - (py / math.max(size.Y, 1)) * 2
    local th = math.tan(math.rad(Ed.Cam.FieldOfView) / 2)
    local cf = Ed.Cam.CFrame
    local dir = (cf.LookVector
        + cf.RightVector * (nx * th * (size.X / math.max(size.Y, 1)))
        + cf.UpVector * (ny * th)).Unit
    return cf.Position, dir
end

local function pickFromScreen(px, py)
    local ro, rd = screenRay(px, py)
    local bestT, bestCell = math.huge, nil
    for _, c in pairs(Ed.Cells) do
        if c.z == Ed.ActiveZ then
            local ctr = cellCenter(c.x, c.y, c.z)
            local t = rayAABB(ro, rd, ctr - HALF, ctr + HALF)
            if t and t < bestT then bestT = t; bestCell = c end
        end
    end
    if bestCell then return bestCell.x, bestCell.y, bestCell.z end

    if math.abs(rd.Z) > 1e-6 then
        local zc = Ed.ActiveZ - (Ed.N + 1) / 2
        local t = (zc - ro.Z) / rd.Z
        if t > 0 then
            local hit = ro + rd * t
            local x = math.floor(hit.X + Ed.N / 2) + 1
            local y = math.floor(hit.Y + Ed.N / 2) + 1
            if x >= 1 and x <= Ed.N and y >= 1 and y <= Ed.N then
                return x, y, Ed.ActiveZ
            end
        end
    end
    return nil
end

local function setupPart(p, color, transp)
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
    p.CastShadow = false; p.Material = Enum.Material.Neon
    p.Color = color; p.Transparency = transp
end

local function gridSeg(a, b, color, transp, th)
    local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
    local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
    local p = Instance.new("Part")
    p.Name = PREFIX .. "G"
    p.Size = Vector3.new(math.max(mx.X - mn.X, th), math.max(mx.Y - mn.Y, th), math.max(mx.Z - mn.Z, th))
    p.Position = (mn + mx) / 2
    setupPart(p, color, transp)
    p.Parent = Ed.GridFolder
    return p
end

local function buildGrid()
    if not Ed.World then return end
    if Ed.GridFolder then Ed.GridFolder:Destroy() end
    Ed.GridFolder = Instance.new("Folder")
    Ed.GridFolder.Name = PREFIX .. "Grid"
    Ed.GridFolder.Parent = Ed.World

    local N = Ed.N
    local h = N / 2
    local o = (N + 1) / 2
    local accent = PALETTE[Ed.Color]
    local frameCol = Color3.fromRGB(120, 160, 220)

    for _, u in ipairs({-h, h}) do
        for _, v in ipairs({-h, h}) do
            gridSeg(Vector3.new(-h, u, v), Vector3.new(h, u, v), frameCol, 0.7, 0.05)
            gridSeg(Vector3.new(u, -h, v), Vector3.new(u, h, v), frameCol, 0.7, 0.05)
            gridSeg(Vector3.new(u, v, -h), Vector3.new(u, v, h), frameCol, 0.7, 0.05)
        end
    end

    if isHuge() then
        local zc = Ed.ActiveZ - o
        gridSeg(Vector3.new(-h, -h, zc), Vector3.new(h, -h, zc), accent, 0.4, 0.02)
        gridSeg(Vector3.new(-h, h, zc),  Vector3.new(h, h, zc),  accent, 0.4, 0.02)
        gridSeg(Vector3.new(-h, -h, zc), Vector3.new(-h, h, zc), accent, 0.4, 0.02)
        gridSeg(Vector3.new(h, -h, zc),  Vector3.new(h, h, zc),  accent, 0.4, 0.02)
        return
    end

    if isBig() then
        local zc = Ed.ActiveZ - o
        for i = 0, N do
            local v = -h + i
            gridSeg(Vector3.new(v, -h, zc), Vector3.new(v, h, zc), accent, 0.5, 0.03)
            gridSeg(Vector3.new(-h, v, zc), Vector3.new(h, v, zc), accent, 0.5, 0.03)
        end
        return
    end

    for zi = 1, N do
        if zi ~= Ed.ActiveZ then
            local zc = zi - o
            local col = Color3.fromRGB(110, 120, 170)
            gridSeg(Vector3.new(-h, -h, zc), Vector3.new(h, -h, zc), col, 0.9, 0.02)
            gridSeg(Vector3.new(-h, h, zc),  Vector3.new(h, h, zc),  col, 0.9, 0.02)
            gridSeg(Vector3.new(-h, -h, zc), Vector3.new(-h, h, zc), col, 0.9, 0.02)
            gridSeg(Vector3.new(h, -h, zc),  Vector3.new(h, h, zc),  col, 0.9, 0.02)
        end
    end

    local zc = Ed.ActiveZ - o
    gridSeg(Vector3.new(-h, -h, zc), Vector3.new(h, h, zc), accent, 0.9, 0.04)
    for i = 0, N do
        local v = -h + i
        gridSeg(Vector3.new(v, -h, zc), Vector3.new(v, h, zc), accent, 0.4, 0.035)
        gridSeg(Vector3.new(-h, v, zc), Vector3.new(h, v, zc), accent, 0.4, 0.035)
    end
end

local function syncBlocks()
    if not Ed.BlockFolder then return end
    for k, p in pairs(Ed.Parts) do
        if not Ed.Cells[k] then p:Destroy(); Ed.Parts[k] = nil end
    end
    for k, c in pairs(Ed.Cells) do
        local p = Ed.Parts[k]
        if not p then
            p = Instance.new("Part")
            p.Name = PREFIX .. "Cell"
            p.Size = Vector3.new(0.92, 0.92, 0.92)
            p.Parent = Ed.BlockFolder
            Ed.Parts[k] = p
        end
        p.Position = cellCenter(c.x, c.y, c.z)
        setupPart(p, c.color, (c.z == Ed.ActiveZ) and 0.05 or 0.55)
    end
end

local function clearBlockParts()
    for _, p in pairs(Ed.Parts) do p:Destroy() end
    Ed.Parts = {}
end

local function refreshView()
    syncBlocks()
    if Ed.UI.refreshInfo then Ed.UI.refreshInfo() end
end

local function updateCamera()
    if not Ed.Cam then return end
    local az, el = math.rad(Ed.Az), math.rad(Ed.El)
    local pos = Vector3.new(
        Ed.Dist * math.cos(el) * math.sin(az),
        Ed.Dist * math.sin(el),
        Ed.Dist * math.cos(el) * math.cos(az)
    )
    Ed.Cam.CFrame = CFrame.new(pos, Vector3.new(0, 0, 0))
end

local function snapshot()
    local s = {}
    for k, c in pairs(Ed.Cells) do s[k] = {x = c.x, y = c.y, z = c.z, color = c.color} end
    return s
end
local function restore(s)
    Ed.Cells = {}
    for k, c in pairs(s) do Ed.Cells[k] = {x = c.x, y = c.y, z = c.z, color = c.color} end
end
local function resetHistory()
    Ed.MaxHistory = isBig() and MAX_HISTORY_BIG or MAX_HISTORY_STD
    Ed.States = {snapshot()}
    Ed.StateIdx = 1
    if Ed.OnHistory then pcall(Ed.OnHistory) end
end
local function commit()
    while #Ed.States > Ed.StateIdx do table.remove(Ed.States) end
    table.insert(Ed.States, snapshot())
    Ed.StateIdx = #Ed.States
    while #Ed.States > Ed.MaxHistory + 1 do
        table.remove(Ed.States, 1)
        Ed.StateIdx = Ed.StateIdx - 1
    end
    if Ed.OnHistory then pcall(Ed.OnHistory) end
end
local function doUndo()
    if Ed.StateIdx <= 1 then return end
    Ed.StateIdx = Ed.StateIdx - 1
    restore(Ed.States[Ed.StateIdx])
    refreshView()
    if Ed.OnHistory then pcall(Ed.OnHistory) end
end
local function doRedo()
    if Ed.StateIdx >= #Ed.States then return end
    Ed.StateIdx = Ed.StateIdx + 1
    restore(Ed.States[Ed.StateIdx])
    refreshView()
    if Ed.OnHistory then pcall(Ed.OnHistory) end
end
resetHistory()

local function mirrored(x, y, z)
    local pts = {{x, y, z}}
    local N = Ed.N
    local function dup(ix)
        local cnt = #pts
        for i = 1, cnt do
            local p = pts[i]
            local q = {p[1], p[2], p[3]}
            q[ix] = N + 1 - q[ix]
            pts[#pts + 1] = q
        end
    end
    if Ed.SymX then dup(1) end
    if Ed.SymY then dup(2) end
    if Ed.SymZ then dup(3) end
    return pts
end

local function applyAt(x, y, z)
    local col = PALETTE[Ed.Color]
    local changed = false
    local warned = false
    local n = Ed.Brush or 1
    local lo = -math.floor((n - 1) / 2)
    local hi = lo + n - 1
    local N = Ed.N
    local total = countCells()
    for dx = lo, hi do
        for dy = lo, hi do
            for dz = lo, hi do
                local cx, cy, cz = x + dx, y + dy, z + dz
                if cx >= 1 and cx <= N and cy >= 1 and cy <= N and cz >= 1 and cz <= N then
                    for _, p in ipairs(mirrored(cx, cy, cz)) do
                        local k = key(p[1], p[2], p[3])
                        local cur = Ed.Cells[k]
                        if Ed.Mode == "place" then
                            if not cur then
                                if total >= MAX_CELLS then
                                    if not warned then
                                        warned = true
                                        ORBIT.notify("⚠️ Лимит блоков: " .. MAX_CELLS, Color3.fromRGB(255,200,120), 3)
                                    end
                                else
                                    Ed.Cells[k] = {x = p[1], y = p[2], z = p[3], color = col}
                                    total = total + 1
                                    changed = true
                                end
                            elseif cur.color ~= col then
                                cur.color = col
                                changed = true
                            end
                        elseif Ed.Mode == "remove" then
                            if cur then Ed.Cells[k] = nil; changed = true end
                        else
                            if cur and cur.color ~= col then cur.color = col; changed = true end
                        end
                    end
                end
            end
        end
    end
    if changed then commit(); refreshView() end
end

local function fillWith(testFn)
    local col = PALETTE[Ed.Color]
    local added = 0
    for x = 1, Ed.N do for y = 1, Ed.N do for z = 1, Ed.N do
        if testFn(x, y, z) then
            local k = key(x, y, z)
            if not Ed.Cells[k] then
                if countCells() + added >= MAX_CELLS then
                    ORBIT.notify("⚠️ Лимит блоков: " .. MAX_CELLS .. " (обрезано)", Color3.fromRGB(255,200,120), 3)
                    commit(); refreshView()
                    return
                end
                added = added + 1
            end
            Ed.Cells[k] = {x = x, y = y, z = z, color = col}
        end
    end end end
    commit(); refreshView()
end

local function fillCube() fillWith(function() return true end) end
local function fillSphere()
    local c = (Ed.N + 1) / 2
    local r = Ed.N / 2 - 0.25
    fillWith(function(x, y, z)
        local dx, dy, dz = x - c, y - c, z - c
        return dx * dx + dy * dy + dz * dz <= r * r
    end)
end
local function fillCross()
    local c = math.ceil(Ed.N / 2)
    fillWith(function(x, y, z)
        local n = 0
        if x == c then n = n + 1 end
        if y == c then n = n + 1 end
        if z == c then n = n + 1 end
        return n >= 2
    end)
end

local function clearAll()
    Ed.Cells = {}
    commit(); refreshView()
end
local function clearLayer()
    for k, c in pairs(Ed.Cells) do
        if c.z == Ed.ActiveZ then Ed.Cells[k] = nil end
    end
    commit(); refreshView()
end

local function rotateAll(axis, dir)
    local N = Ed.N
    local c = (N + 1) / 2
    local out = {}
    for _, cell in pairs(Ed.Cells) do
        local x, y, z = cell.x - c, cell.y - c, cell.z - c
        local nx, ny, nz = x, y, z
        if axis == "X" then
            ny, nz = -z * dir, y * dir
        else
            nx, nz = -z * dir, x * dir
        end
        local fx = math.floor(nx + c + 0.5)
        local fy = math.floor(ny + c + 0.5)
        local fz = math.floor(nz + c + 0.5)
        if fx >= 1 and fx <= N and fy >= 1 and fy <= N and fz >= 1 and fz <= N then
            out[key(fx, fy, fz)] = {x = fx, y = fy, z = fz, color = cell.color}
        end
    end
    Ed.Cells = out
    commit(); refreshView()
end

local function setGridSize(n)
    Ed.N = n
    Ed.ActiveZ = 1
    Ed.Cells = {}
    Ed.Dist = defaultDist()
    resetHistory()
    clearBlockParts()
    buildGrid()
    updateCamera()
    refreshView()
    if n >= 32 then
        ORBIT.notify("🐢 N=" .. n .. ": упрощённая сетка (иначе лаги)", Color3.fromRGB(255,200,120), 3)
    elseif n >= 16 then
        ORBIT.notify("⚠️ N=" .. n .. ": без подсветки остальных слоёв", Color3.fromRGB(255,220,140), 2)
    end
end

local function setActiveZ(z)
    Ed.ActiveZ = math.clamp(z, 1, Ed.N)
    buildGrid()
    refreshView()
end

local function persistShapes()
    if type(ORBIT.saveStorage) == "function" then
        pcall(ORBIT.saveStorage)
    elseif ORBIT.HAS_FS and type(writefile) == "function" then
        pcall(function()
            writefile(ORBIT.CUSTOM_FILE or "orbit_v21_custom_shapes.json",
                HttpService:JSONEncode(ORBIT.CUSTOM_SHAPES))
        end)
    end
end

local function registerShape(name)
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, c in pairs(Ed.Cells) do
        minX = math.min(minX, c.x); maxX = math.max(maxX, c.x)
        minY = math.min(minY, c.y); maxY = math.max(maxY, c.y)
        minZ = math.min(minZ, c.z); maxZ = math.max(maxZ, c.z)
    end
    if minX == math.huge then return false, "Пустая фигура" end

    local size = math.max(maxX - minX + 1, maxY - minY + 1, maxZ - minZ + 1)
    local cx, cy, cz = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
    local mid = (size + 1) / 2
    local blocksCopy = {}
    for _, c in pairs(Ed.Cells) do
        table.insert(blocksCopy, {
            x = c.x - cx + mid, y = c.y - cy + mid, z = c.z - cz + mid, color = c.color,
        })
    end

    local function exists(nm)
        for _, sp in ipairs(ORBIT.SHAPE_PRESETS) do
            if sp.name == nm then return true end
        end
        return false
    end
    local finalName, base, n = name, name, 1
    while exists(finalName) do n = n + 1; finalName = base .. "_" .. n end

    table.insert(ORBIT.SHAPE_PRESETS, {
        name = finalName,
        isCustom = true,
        is3D = true,
        create = function(shapeSize, partName)
            local model, root = ORBIT.newModelShell(partName)
            local bodies = {}
            local unit = shapeSize / size
            for _, cell in ipairs(blocksCopy) do
                local p = ORBIT.newPart(model, "V",
                    Vector3.new(unit * 0.95, unit * 0.95, unit * 0.95),
                    CFrame.new((cell.x - mid) * unit, (cell.y - mid) * unit, (cell.z - mid) * unit),
                    cell.color, true)
                table.insert(bodies, p)
            end
            return { model = model, part = root, isModel = true,
                     bodyParts = bodies, visualSize = shapeSize * 1.4 }
        end,
    })

    ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
    local saved = {}
    for i, b in ipairs(blocksCopy) do
        saved[i] = {x = b.x, y = b.y, z = b.z, r = b.color.R, g = b.color.G, b = b.color.B}
    end
    table.insert(ORBIT.CUSTOM_SHAPES, {name = finalName, is3D = true, N = size, blocks = saved})
    if type(ORBIT.OWNED_SHAPES) == "table" then ORBIT.OWNED_SHAPES[finalName] = true end
    persistShapes()
    return true, finalName
end

local function closeEditor()
    Ed.Open = false
    for _, cn in ipairs(Ed.Conns) do pcall(function() cn:Disconnect() end) end
    Ed.Conns = {}
    if Ed.Gui then pcall(function() Ed.Gui:Destroy() end) end
    Ed.Gui, Ed.Vp, Ed.World, Ed.Cam = nil, nil, nil, nil
    Ed.BlockFolder, Ed.GridFolder = nil, nil
    Ed.Parts = {}
    Ed.UI = {}
    Ed.OnHistory = nil
    Ed.PaintBrush, Ed.PaintSizes = nil, nil
end

local function openEditor3D()
    if Ed.Open and Ed.Gui and Ed.Gui.Parent then return end
    Ed.Open = true
    Ed.Parts = {}
    Ed.UI = {}
    Ed.Conns = {}

    local W = IS_MOBILE and 340 or 680
    local H = IS_MOBILE and 600 or 560
    local vpW = IS_MOBILE and 320 or 260
    local vpH = IS_MOBILE and 240 or 260

    Ed.Gui = mk("Frame", {
        Name = "Window", Size = UDim2.new(0, W, 0, H),
        Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
        BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 50, Active = true,
    }, nil)
    Ed.Gui.Name = "_Orbit3DEditor"
    Ed.Gui.Parent = screenGui
    corner(Ed.Gui, 14)
    mk("UIStroke", {Color = C.accent, Thickness = 2}, Ed.Gui)
    if ORBIT.ui.fitToScreen then pcall(ORBIT.ui.fitToScreen, Ed.Gui, W, H) end

    mk("TextLabel", {
        Name = "Title", Size = UDim2.new(1, -60, 0, 26), Position = UDim2.new(0, 14, 0, 6),
        BackgroundTransparency = 1, Text = "🔮 3D-РЕДАКТОР", TextColor3 = C.text,
        Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left,
    }, Ed.Gui)

    local closeBtn = mk("TextButton", {
        Name = "Close", Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -38, 0, 4),
        BackgroundColor3 = Color3.fromRGB(80, 30, 30), TextColor3 = Color3.fromRGB(255, 160, 160),
        Font = Enum.Font.GothamBold, TextSize = 16, Text = "✖", AutoButtonColor = false,
        BorderSizePixel = 0,
    }, Ed.Gui)
    corner(closeBtn, 8)
    onClick(closeBtn, closeEditor)

    Ed.Vp = mk("ViewportFrame", {
        Name = "Viewport", Size = UDim2.new(0, vpW, 0, vpH), Position = UDim2.new(0, 10, 0, 36),
        BackgroundColor3 = Color3.fromRGB(8, 6, 16), BorderSizePixel = 0, Active = true,
        Ambient = Color3.fromRGB(200, 200, 220), LightColor = Color3.fromRGB(255, 255, 255),
        LightDirection = Vector3.new(-1, -1, -1),
    }, Ed.Gui)
    corner(Ed.Vp, 10)

    Ed.World = Instance.new("WorldModel")
    Ed.World.Name = PREFIX .. "World"
    Ed.World.Parent = Ed.Vp

    Ed.Cam = Instance.new("Camera")
    Ed.Cam.Name = PREFIX .. "Camera"
    Ed.Cam.FieldOfView = 50
    Ed.Cam.Parent = Ed.Vp
    Ed.Vp.CurrentCamera = Ed.Cam

    Ed.BlockFolder = Instance.new("Folder")
    Ed.BlockFolder.Name = PREFIX .. "Blocks"
    Ed.BlockFolder.Parent = Ed.World

    updateCamera()
    buildGrid()
    syncBlocks()

    local touches = {}
    local g = {moved = false, mouse = false, last = nil, start = nil}
    local pinchStart, pinchZoom

    local function liveTouches()
        local list = {}
        for inp in pairs(touches) do
            local st = inp.UserInputState
            if st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
                touches[inp] = nil
            else
                list[#list + 1] = inp
            end
        end
        return list
    end

    local function doTap(pos)
        if not Ed.Vp then return end
        local ab = Ed.Vp.AbsolutePosition
        local x, y, z = pickFromScreen(pos.X - ab.X, pos.Y - ab.Y)
        if x then applyAt(x, y, z) end
    end

    local function rotateBy(pos, threshold)
        if not g.last then g.last = pos; return end
        if not g.moved and (pos - g.start).Magnitude > threshold then g.moved = true end
        if g.moved then
            local delta = pos - g.last
            Ed.Az = Ed.Az - delta.X * 0.5
            Ed.El = math.clamp(Ed.El + delta.Y * 0.5, -80, 80)
            updateCamera()
        end
        g.last = pos
    end

    Ed.Vp.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch then
            touches[input] = true
            local n = #liveTouches()
            pinchStart = nil
            if n == 1 then
                g.start, g.last, g.moved = input.Position, input.Position, false
            else
                g.moved = true; g.last = nil
            end
        elseif t == Enum.UserInputType.MouseButton1 then
            g.mouse = true
            g.start, g.last, g.moved = input.Position, input.Position, false
        end
    end)

    Ed.Vp.InputChanged:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch then
            local list = liveTouches()
            if #list >= 2 then
                g.moved = true; g.last = nil
                local d = math.max((list[1].Position - list[2].Position).Magnitude, 1)
                if not pinchStart then
                    pinchStart, pinchZoom = d, Ed.Dist
                else
                    Ed.Dist = math.clamp(pinchZoom * pinchStart / d, 5, math.max(40, Ed.N * 3))
                    updateCamera()
                end
                return
            end
            rotateBy(input.Position, 8)
        elseif t == Enum.UserInputType.MouseMovement then
            if g.mouse then rotateBy(input.Position, 6) end
        elseif t == Enum.UserInputType.MouseWheel then
            Ed.Dist = math.clamp(Ed.Dist - input.Position.Z * 1.5, 5, math.max(40, Ed.N * 3))
            updateCamera()
        end
    end)

    Ed.Vp.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch then
            touches[input] = nil
            local n = #liveTouches()
            if n == 0 then
                if not g.moved then doTap(input.Position) end
                g.moved, g.last, pinchStart = false, nil, nil
            else
                pinchStart, g.last = nil, nil
            end
        elseif t == Enum.UserInputType.MouseButton1 then
            if g.mouse and not g.moved then doTap(input.Position) end
            g.mouse, g.moved, g.last = false, false, nil
        end
    end)

    local palX, palY, palW = 10, 36 + vpH + 6, vpW
    local palBlock = mk("Frame", {
        Name = "PalBlock", Size = UDim2.new(0, palW, 0, 74), Position = UDim2.new(0, palX, 0, palY),
        BackgroundTransparency = 1,
    }, Ed.Gui)

    local palTitle = mk("TextLabel", {
        Name = "PalTitle", Size = UDim2.new(1, -60, 0, 16), BackgroundTransparency = 1,
        Text = "🎨 ВЫБЕРИ ЦВЕТ", TextColor3 = C.text, Font = Enum.Font.GothamBold,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
    }, palBlock)
    local countLbl = mk("TextLabel", {
        Name = "Count", Size = UDim2.new(0, 60, 0, 16), Position = UDim2.new(1, -60, 0, 0),
        BackgroundTransparency = 1, Text = "🧱 0", TextColor3 = Color3.fromRGB(180, 220, 255),
        Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
    }, palBlock)

    local palScroll = mk("ScrollingFrame", {
        Name = "Pal", Size = UDim2.new(1, 0, 0, 54), Position = UDim2.new(0, 0, 0, 18),
        BackgroundColor3 = Color3.fromRGB(15, 12, 24), BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, #PALETTE * 40 + 12, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollBarThickness = 4, ScrollBarImageColor3 = C.accent,
    }, palBlock)
    corner(palScroll, 8)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, palScroll)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
    }, palScroll)

    local palStrokes = {}
    local function refreshPalette()
        for i, st in ipairs(palStrokes) do
            local on = (i == Ed.Color)
            st.Thickness = on and 3 or 1
            st.Transparency = on and 0 or 0.8
        end
        palTitle.Text = "🎨 " .. COLOR_NAMES[Ed.Color]
    end
    for i, col in ipairs(PALETTE) do
        local b = mk("TextButton", {
            Name = "Col", Size = UDim2.new(0, 36, 0, 36), BackgroundColor3 = col,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = i,
        }, palScroll)
        corner(b, 7)
        palStrokes[i] = mk("UIStroke", {
            Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Transparency = 0.8,
        }, b)
        onClick(b, function()
            Ed.Color = i
            refreshPalette()
            buildGrid()
        end)
    end
    refreshPalette()

    local toolsX, toolsY, toolsW, toolsH
    if IS_MOBILE then
        toolsX, toolsY = 10, palY + 78
        toolsW, toolsH = 320, H - toolsY - 8
    else
        toolsX, toolsY = 280, 36
        toolsW, toolsH = 390, H - 36 - 10
    end

    local ctrl = mk("ScrollingFrame", {
        Name = "Tools", Size = UDim2.new(0, toolsW, 0, toolsH), Position = UDim2.new(0, toolsX, 0, toolsY),
        BackgroundColor3 = C.panel, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.accent,
    }, Ed.Gui)
    corner(ctrl, 10)
    local list = mk("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, ctrl)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10),
    }, ctrl)
    local function fitCanvas()
        ctrl.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 18)
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)

    local secOrder = 0
    local BTN_SCALE = 1.12
    local function sc(v) return math.floor(v * BTN_SCALE + 0.5) end

    local function section(title, bodyH)
        secOrder = secOrder + 1
        bodyH = sc(bodyH)
        local f = mk("Frame", {
            Name = "Sec", Size = UDim2.new(1, 0, 0, 28 + bodyH), BackgroundTransparency = 1,
            LayoutOrder = secOrder,
        }, ctrl)
        local t = mk("TextLabel", {
            Name = "SecTitle", Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = C.title,
            BorderSizePixel = 0, Text = "  " .. title, TextColor3 = Color3.fromRGB(255, 248, 255),
            Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        corner(t, 5)
        return mk("Frame", {
            Name = "Body", Size = UDim2.new(1, 0, 0, bodyH), Position = UDim2.new(0, 0, 0, 28),
            BackgroundTransparency = 1,
        }, f)
    end

    local function markActive(b, on)
        if not b then return end
        local base = b:GetAttribute("BaseText")
        if not base then base = b.Text; b:SetAttribute("BaseText", base) end
        local st = b:FindFirstChild("ActiveStroke")
        if not st then
            st = Instance.new("UIStroke"); st.Name = "ActiveStroke"; st.Thickness = 2.5
            st.Color = Color3.fromRGB(255, 255, 255); st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            st.Parent = b
        end
        st.Enabled = on and true or false
        b.Text = on and ("✓ " .. base) or base
    end

    local function buttonRow(body, items, y, h, textSize)
        local btns = {}
        local n = #items
        for i, it in ipairs(items) do
            local b = mk("TextButton", {
                Name = "Btn", Size = UDim2.new(1 / n, -4, 0, sc(h or 32)),
                Position = UDim2.new((i - 1) / n, 2, 0, sc(y or 0)),
                BackgroundColor3 = it.color or C.btn, TextColor3 = C.text,
                Font = Enum.Font.GothamBold, TextSize = textSize or 11, Text = it.text,
                TextWrapped = true, AutoButtonColor = false, BorderSizePixel = 0,
            }, body)
            corner(b, 6)
            onClick(b, it.fn)
            btns[i] = b
        end
        return btns
    end

    -- 🖌 РЕЖИМ
    do
        local body = section("🖌 РЕЖИМ", 32)
        local modes = {
            {key = "place",  on = Color3.fromRGB(60, 140, 90)},
            {key = "remove", on = Color3.fromRGB(150, 60, 60)},
            {key = "paint",  on = Color3.fromRGB(150, 100, 40)},
        }
        local texts = {place = "🖌 Ставить", remove = "🗑 Удалить", paint = "🎨 Красить"}
        local btns = {}
        local function paintModes()
            for i, m in ipairs(modes) do
                btns[i].BackgroundColor3 = (Ed.Mode == m.key) and m.on or C.btn
                markActive(btns[i], Ed.Mode == m.key)
            end
        end
        local items = {}
        for i, m in ipairs(modes) do
            items[i] = {text = texts[m.key], fn = function() Ed.Mode = m.key; paintModes() end}
        end
        btns = buttonRow(body, items, 0, 32, 11)
        paintModes()
    end

    -- 🔲 РАЗМЕР КИСТИ
    do
        local body = section("🔲 РАЗМЕР КИСТИ (куб)", 36)
        local sizes = {1, 2, 3, 4, 5}
        local btns = {}
        local function paintBrush()
            Ed.PaintBrush = paintBrush
            for i, n in ipairs(sizes) do
                btns[i].BackgroundColor3 = (Ed.Brush == n) and C.btnOn or C.btn
                markActive(btns[i], Ed.Brush == n)
            end
        end
        local items = {}
        for i, n in ipairs(sizes) do
            items[i] = {text = n .. "×" .. n .. "×" .. n, fn = function() Ed.Brush = n; paintBrush() end}
        end
        btns = buttonRow(body, items, 0, 36, 11)
        paintBrush()
    end

    -- 📐 РАЗМЕР СЕТКИ
    do
        local body = section("📐 РАЗМЕР СЕТКИ", 84)
        local GRID_ITEMS1 = {
            {n = 4, label = "▪ Малый\n4"}, {n = 5, label = "▪ Малый\n5"},
            {n = 6, label = "◽ Средний\n6"}, {n = 7, label = "◽ Средний\n7"}, {n = 8, label = "◽ Средний\n8"},
        }
        local GRID_ITEMS2 = {
            {n = 16, label = "◼ Большой\n16"}, {n = 32, label = "◼ Большой\n32"},
            {n = 64, label = "⬛ Огромный\n64 ⚠"},
        }
        local btnsBySize = {}
        local function paintSizes()
            Ed.PaintSizes = paintSizes
            for n, b in pairs(btnsBySize) do
                if n == Ed.N then
                    b.BackgroundColor3 = C.btnOn
                elseif n >= HUGE_THRESHOLD then
                    b.BackgroundColor3 = Color3.fromRGB(110, 45, 45)
                elseif n >= BIG_THRESHOLD then
                    b.BackgroundColor3 = Color3.fromRGB(110, 80, 45)
                else
                    b.BackgroundColor3 = C.btn
                end
                markActive(b, n == Ed.N)
            end
        end

        local function build(list, y)
            local items = {}
            for i, it in ipairs(list) do
                items[i] = {text = it.label, fn = function()
                    if Ed.N ~= it.n then setGridSize(it.n) end
                    paintSizes()
                end}
            end
            local btns = buttonRow(body, items, y, 36, 10)
            for i, it in ipairs(list) do btnsBySize[it.n] = btns[i] end
        end
        build(GRID_ITEMS1, 0)
        build(GRID_ITEMS2, 40)
        paintSizes()
    end

    -- 📚 СЛОЙ Z
    do
        local body = section("📚 СЛОЙ Z", 34)
        local btns = buttonRow(body, {
            {text = "▼", fn = function() setActiveZ(Ed.ActiveZ - 1) end},
            {text = "", fn = function() end},
            {text = "▲", fn = function() setActiveZ(Ed.ActiveZ + 1) end},
        }, 0, 34, 16)
        local zLbl = btns[2]
        zLbl.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
        zLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
        zLbl.TextSize = 12
        Ed.UI.refreshLayer = function()
            zLbl.Text = "Слой " .. Ed.ActiveZ .. " / " .. Ed.N
        end
    end

    -- 🔀 СИММЕТРИЯ
    do
        local body = section("🔀 СИММЕТРИЯ (зеркалит блоки)", 32)
        local axes = {"X", "Y", "Z"}
        local btns = {}
        local items = {}
        for i, ax in ipairs(axes) do
            local field = "Sym" .. ax
            items[i] = {text = ax .. " ➖", fn = function()
                Ed[field] = not Ed[field]
                btns[i].Text = ax .. (Ed[field] and " ✅" or " ➖")
                btns[i].BackgroundColor3 = Ed[field] and Color3.fromRGB(80, 120, 180) or C.btn
            end}
        end
        btns = buttonRow(body, items, 0, 32, 12)
        for i, ax in ipairs(axes) do
            local on = Ed["Sym" .. ax]
            btns[i].Text = ax .. (on and " ✅" or " ➖")
            btns[i].BackgroundColor3 = on and Color3.fromRGB(80, 120, 180) or C.btn
        end
    end

    -- ⚡ ФОРМЫ
    do
        local body = section("⚡ ФОРМЫ (заполнить)", 32)
        local purple = Color3.fromRGB(80, 60, 100)
        buttonRow(body, {
            {text = "⬜ Куб",   fn = fillCube,   color = purple},
            {text = "⚪ Шар",   fn = fillSphere, color = purple},
            {text = "✚ Крест", fn = fillCross,  color = purple},
        }, 0, 32, 11)
    end

    -- 🔄 ПОВОРОТ
    do
        local body = section("🔄 ПОВОРОТ ФИГУРЫ (90°)", 32)
        local blue = Color3.fromRGB(60, 80, 110)
        buttonRow(body, {
            {text = "⟲ X", fn = function() rotateAll("X", 1) end,  color = blue},
            {text = "⟳ X", fn = function() rotateAll("X", -1) end, color = blue},
            {text = "⟲ Y", fn = function() rotateAll("Y", 1) end,  color = blue},
            {text = "⟳ Y", fn = function() rotateAll("Y", -1) end, color = blue},
        }, 0, 32, 11)
    end

    -- ↩️ ИСТОРИЯ
    do
        local body = section("↩️ ИСТОРИЯ", 70)
        local hb = buttonRow(body, {
            {text = "↩ Отмена",  fn = doUndo, color = C.btnOff},
            {text = "↪ Вернуть", fn = doRedo, color = C.btnOff},
        }, 0, 32, 11)
        Ed.OnHistory = function()
            local canUndo = Ed.StateIdx > 1
            local canRedo = Ed.StateIdx < #Ed.States
            hb[1].BackgroundColor3 = canUndo and Color3.fromRGB(70, 150, 220) or C.btnOff
            hb[1].TextTransparency = canUndo and 0 or 0.55
            hb[2].BackgroundColor3 = canRedo and Color3.fromRGB(70, 190, 130) or C.btnOff
            hb[2].TextTransparency = canRedo and 0 or 0.55
        end
        Ed.OnHistory()
        buttonRow(body, {
            {text = "🗑 Очистить слой", fn = clearLayer, color = Color3.fromRGB(100, 55, 55)},
            {text = "🗑 Очистить всё",  fn = clearAll,   color = Color3.fromRGB(120, 45, 45)},
        }, 36, 32, 10)
    end

    -- 🎥 КАМЕРА
    do
        local body = section("🎥 КАМЕРА", 32)
        local cam = Color3.fromRGB(50, 60, 80)
        buttonRow(body, {
            {text = "➕ Зум", color = cam, fn = function() Ed.Dist = math.max(5, Ed.Dist - 1.5); updateCamera() end},
            {text = "➖ Зум", color = cam, fn = function() Ed.Dist = math.min(math.max(40, Ed.N * 3), Ed.Dist + 1.5); updateCamera() end},
            {text = "🎯 Сброс камеры", color = cam, fn = function()
                Ed.Az, Ed.El, Ed.Dist = -45, 30, defaultDist()
                updateCamera()
            end},
        }, 0, 32, 10)
    end

    -- 💾 СОХРАНЕНИЕ
    do
        local body = section("💾 СОХРАНЕНИЕ И ОБМЕН", 160)

        local nameInput = mk("TextBox", {
            Name = "NameInput", Size = UDim2.new(1, -4, 0, 32), Position = UDim2.new(0, 2, 0, 0),
            BackgroundColor3 = Color3.fromRGB(35, 30, 50), TextColor3 = C.text,
            Font = Enum.Font.GothamBold, TextSize = 12, PlaceholderText = "✏️ Имя фигуры...",
            PlaceholderColor3 = Color3.fromRGB(150, 140, 180), Text = "", ClearTextOnFocus = false,
            BorderSizePixel = 0,
        }, body)
        corner(nameInput, 6)

        local saveBtn = mk("TextButton", {
            Name = "Save", Size = UDim2.new(1, -4, 0, 34), Position = UDim2.new(0, 2, 0, 38),
            BackgroundColor3 = Color3.fromRGB(60, 120, 80), TextColor3 = Color3.fromRGB(200, 255, 210),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "💾 СОХРАНИТЬ КАК ФИГУРУ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(saveBtn, 8)
        onClick(saveBtn, function()
            if countCells() < 2 then
                ORBIT.notify("🧱 Поставь хотя бы 2 блока", Color3.fromRGB(255, 200, 120), 2)
                return
            end
            local nm = nameInput.Text
            local len = utf8.len(nm)
            if nm == "" or not len or len > 20 then
                nm = "3D_СВОЯ_" .. math.random(100, 999)
            end
            local ok, result = registerShape(nm)
            if ok then
                ORBIT.notify("✅ Сохранено: " .. tostring(result), Color3.fromRGB(160, 255, 180), 3)
                if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
            else
                ORBIT.notify("❌ " .. tostring(result), Color3.fromRGB(255, 120, 120), 2)
            end
        end)

        local shareBtn = mk("TextButton", {
            Name = "Share", Size = UDim2.new(1, -4, 0, 34), Position = UDim2.new(0, 2, 0, 78),
            BackgroundColor3 = Color3.fromRGB(70, 60, 130), TextColor3 = Color3.fromRGB(220, 210, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "📤 ПОДЕЛИТЬСЯ ФИГУРОЙ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(shareBtn, 8)
        onClick(shareBtn, function()
            if not ORBIT.share or not ORBIT.share.encodeShape then
                ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255, 150, 150), 3)
                return
            end
            if countCells() < 2 then
                ORBIT.notify("🧱 Поставь хотя бы 2 блока", Color3.fromRGB(255, 200, 120), 2)
                return
            end
            local minX, minY, minZ = math.huge, math.huge, math.huge
            local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
            for _, c in pairs(Ed.Cells) do
                minX = math.min(minX, c.x); maxX = math.max(maxX, c.x)
                minY = math.min(minY, c.y); maxY = math.max(maxY, c.y)
                minZ = math.min(minZ, c.z); maxZ = math.max(maxZ, c.z)
            end
            local size = math.max(maxX - minX + 1, maxY - minY + 1, maxZ - minZ + 1)
            local cx, cy, cz = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
            local mid = (size + 1) / 2
            local blocks = {}
            for _, c in pairs(Ed.Cells) do
                blocks[#blocks + 1] = {
                    x = math.floor(c.x - cx + mid + 0.5),
                    y = math.floor(c.y - cy + mid + 0.5),
                    z = math.floor(c.z - cz + mid + 0.5),
                    r = c.color.R, g = c.color.G, b = c.color.B,
                }
            end
            local nm = nameInput.Text
            if nm == "" or (utf8.len(nm) or 0) > 20 then nm = "3D_СВОЯ" end
            local str, err = ORBIT.share.encodeShape({
                name = nm, is3D = true, N = size, blocks = blocks,
            })
            if not str then
                ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 3)
                return
            end
            ORBIT.share.open(str)
        end)

        local importBtn = mk("TextButton", {
            Name = "Import", Size = UDim2.new(1, -4, 0, 34), Position = UDim2.new(0, 2, 0, 118),
            BackgroundColor3 = Color3.fromRGB(50, 80, 110), TextColor3 = Color3.fromRGB(200, 230, 255),
            Font = Enum.Font.GothamBold, TextSize = 12, Text = "📥 ИМПОРТ ЧУЖОЙ ФИГУРЫ",
            AutoButtonColor = false, BorderSizePixel = 0,
        }, body)
        corner(importBtn, 8)
        onClick(importBtn, function()
            if not ORBIT.share or not ORBIT.share.open then
                ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255, 150, 150), 3)
                return
            end
            ORBIT.share.open()
        end)
    end

    local hintText = "👆 Свайп по 3D — вращать\n🔍 Пинч двумя пальцами — зум\n👆 Тап по клетке — действие по режиму\n📚 Редактируется активный слой (▲/▼)\n⚠️ N>=16: упрощённая сетка (иначе лаги)"
    if IS_MOBILE then
        secOrder = secOrder + 1
        mk("TextLabel", {
            Name = "Hint", Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = Color3.fromRGB(30, 40, 60),
            BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = hintText,
            TextColor3 = Color3.fromRGB(200, 220, 255), Font = Enum.Font.Gotham, TextSize = 10,
            TextWrapped = true, LayoutOrder = secOrder,
        }, ctrl)
    else
        local hint = mk("TextLabel", {
            Name = "Hint", Size = UDim2.new(0, palW, 0, 86), Position = UDim2.new(0, 10, 0, palY + 82),
            BackgroundColor3 = Color3.fromRGB(30, 40, 60), BackgroundTransparency = 0.3,
            BorderSizePixel = 0, Text = hintText, TextColor3 = Color3.fromRGB(200, 220, 255),
            Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true,
        }, Ed.Gui)
        corner(hint, 6)
    end

    Ed.UI.refreshInfo = function()
        countLbl.Text = "🧱 " .. countCells() .. (countCells() >= MAX_CELLS and "/" .. MAX_CELLS or "")
        if Ed.UI.refreshLayer then Ed.UI.refreshLayer() end
    end
    Ed.UI.refreshInfo()
    fitCanvas()
end

Ed.Close = closeEditor
Ed.BrushSizes = {1, 2, 3, 4, 5}
Ed.GridSizes = {4, 5, 6, 7, 8, 16, 32, 64}
Ed.SetBrush = function(n)
    for _, b in ipairs(Ed.BrushSizes) do
        if b == n then
            Ed.Brush = n
            if Ed.PaintBrush then pcall(Ed.PaintBrush) end
            return true
        end
    end
    return false
end
Ed.SetGridSize = function(n)
    for _, g in ipairs(Ed.GridSizes) do
        if g == n then
            if Ed.N ~= n then setGridSize(n) end
            if Ed.PaintSizes then pcall(Ed.PaintSizes) end
            return true
        end
    end
    return false
end
ORBIT.openEditor3D = openEditor3D
ORBIT.Editor3D = Ed

if ORBIT.notify then
    ORBIT.notify("🔮 3D-Редактор v23.13 (до 64×64)", Color3.fromRGB(200, 180, 255), 3)
end
warn("[Orbit 3D Editor v23.13] Загружен ✅")
return true

end
do local ok, err = pcall(module_editor3d); Tools.editor3d = ok; if not ok then warn("[Orbit Tools] editor3d: " .. tostring(err)) end end

-- ═════════ НОВОЕ v24: ТЕМЫ + ДОСТИЖЕНИЯ ═════════
do local ok, err = pcall(function()
-- ============================================================
--       4 ТЕМЫ UI (v24)
-- ============================================================
do
local Players = ORBIT.Players or game:GetService("Players")
local Debris = game:GetService("Debris")
local C3 = Color3.fromRGB

ORBIT.THEMES = {
    dark = { bg = C3(22, 22, 30),  accent = C3(150, 120, 255), text = C3(235, 235, 245), button = C3(45, 45, 62),  border = C3(90, 90, 120) },
    blue = { bg = C3(14, 24, 44),  accent = C3(70, 160, 255),  text = C3(225, 238, 255), button = C3(28, 52, 92),  border = C3(60, 110, 190) },
    red  = { bg = C3(34, 14, 16),  accent = C3(255, 80, 80),   text = C3(255, 232, 232), button = C3(78, 28, 32),  border = C3(190, 60, 60) },
    soft = { bg = C3(52, 46, 60),  accent = C3(255, 170, 210), text = C3(250, 244, 250), button = C3(86, 76, 98),  border = C3(190, 160, 200) },
}
local THEME_ORDER = { "dark", "blue", "red", "soft" }
local THEME_LABEL = { dark = "🌑 ТЁМНАЯ", blue = "🌊 СИНЯЯ", red = "🔥 КРАСНАЯ", soft = "🌸 МЯГКАЯ" }

local themeConn = nil
local themeBusy = false
local triedThemes = {}

local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
local function sat(c) local _, s = Color3.toHSV(c); return s end

local function paint(obj, th, isDefault)
    if obj:GetAttribute("_OrbitNoTheme") then return end
    if obj:IsA("GuiObject") then
        if obj:GetAttribute("_tOrigBg") == nil then
            obj:SetAttribute("_tOrigBg", obj.BackgroundColor3)
        end
        local ob = obj:GetAttribute("_tOrigBg")
        if isDefault then
            obj.BackgroundColor3 = ob
        elseif obj.BackgroundTransparency < 0.95 then
            if sat(ob) > 0.35 and lum(ob) > 0.2 then
                obj.BackgroundColor3 = ob:Lerp(th.accent, 0.55)
            elseif obj:IsA("TextButton") or obj:IsA("TextBox") then
                obj.BackgroundColor3 = th.button
            elseif lum(ob) < 0.3 then
                obj.BackgroundColor3 = th.bg
            end
        end
    end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        if obj:GetAttribute("_tOrigTx") == nil then
            obj:SetAttribute("_tOrigTx", obj.TextColor3)
        end
        local ot = obj:GetAttribute("_tOrigTx")
        if isDefault then
            obj.TextColor3 = ot
        elseif lum(ot) > 0.7 and sat(ot) < 0.2 then
            obj.TextColor3 = th.text
        end
    end
    if obj:IsA("UIStroke") then
        if obj:GetAttribute("_tOrigSt") == nil then
            obj:SetAttribute("_tOrigSt", obj.Color)
        end
        obj.Color = isDefault and obj:GetAttribute("_tOrigSt") or th.border
    end
end

function ORBIT.applyTheme(name, silent)
    local th = ORBIT.THEMES[name]
    if not th then return false end
    local sg = ORBIT.ui and ORBIT.ui.screenGui
    if not sg then return false end
    ORBIT.saveData = ORBIT.saveData or {}
    ORBIT.saveData.theme = name
    ORBIT._themeName = name
    local isDefault = (name == "dark")
    task.spawn(function()
        local n = 0
        for _, d in ipairs(sg:GetDescendants()) do
            pcall(paint, d, th, isDefault)
            n = n + 1
            if n % 150 == 0 then task.wait() end
        end
    end)
    if themeConn then pcall(function() themeConn:Disconnect() end); themeConn = nil end
    themeConn = sg.DescendantAdded:Connect(function(d)
        task.defer(function()
            if ORBIT._themeName == name then pcall(paint, d, th, isDefault) end
        end)
    end)
    triedThemes[name] = true
    local cnt = 0
    for _ in pairs(triedThemes) do cnt = cnt + 1 end
    if cnt >= 4 and ORBIT.achievements then pcall(ORBIT.achievements.unlock, "h_themes") end
    if not silent then
        pcall(ORBIT.saveSettings)
        if ORBIT.notify then ORBIT.notify("🎨 Тема: " .. (THEME_LABEL[name] or name), th.accent, 2) end
    end
    return true
end
if ORBIT.ui then ORBIT.ui.applyTheme = ORBIT.applyTheme end

task.spawn(function()
    local UI = ORBIT.ui
    if not (UI and UI.addSection and UI.makeButton and UI.addControl) then return end
    local okS = pcall(function() UI.addSection("🎨  ТЕМЫ UI", C3(90, 70, 130), "more") end)
    if not okS then return end
    for _, id in ipairs(THEME_ORDER) do
        local b = UI.makeButton(THEME_LABEL[id], 34, ORBIT.THEMES[id].button, ORBIT.THEMES[id].text)
        b:SetAttribute("_OrbitNoTheme", true)
        UI.addControl(b, 34, true)
        if UI.onClick then UI.onClick(b, function() ORBIT.applyTheme(id) end, true)
        else b.Activated:Connect(function() ORBIT.applyTheme(id) end) end
    end
end)

task.delay(1.5, function()
    local t = ORBIT.saveData and ORBIT.saveData.theme
    if t and t ~= "dark" and ORBIT.THEMES[t] then pcall(ORBIT.applyTheme, t, true) end
end)

local prevUnloadTheme = ORBIT.unload
ORBIT.unload = function()
    if themeConn then pcall(function() themeConn:Disconnect() end); themeConn = nil end
    if prevUnloadTheme then pcall(prevUnloadTheme) end
end
end -- ТЕМЫ

-- ============================================================
--       ДОСТИЖЕНИЯ 52 (v24) — С 3 ПРАВКАМИ
-- ============================================================
do
local Players = ORBIT.Players or game:GetService("Players")
local RunService = ORBIT.RunService or game:GetService("RunService")
local C3 = Color3.fromRGB

ORBIT.saveData = ORBIT.saveData or {}
if type(ORBIT.saveData.achievements) ~= "table" then ORBIT.saveData.achievements = {} end
local ACH = ORBIT.saveData.achievements
if type(ACH._c) ~= "table" then ACH._c = {} end
local CNT = ACH._c

local A = { list = {}, byId = {} }
local CAT_COLOR = { combat = C3(255, 110, 110), collect = C3(255, 210, 90), social = C3(110, 200, 255), hidden = C3(190, 140, 255) }
local CAT_NAME = { combat = "⚔️ Боевые", collect = "💎 Коллекция", social = "🤝 Социальные", hidden = "🕵️ Скрытые" }

local function def(cat, id, name, desc, reward, goal)
    local a = { id = id, name = name, desc = desc, reward = reward or 0, goal = goal or 1, cat = cat, unlocked = false, progress = 0 }
    table.insert(A.list, a); A.byId[id] = a
end

-- Боевые (10)
def("combat", "c_shot1", "Первый выстрел", "Сделай 1 выстрел способностью", 10)
def("combat", "c_shot10", "10 выстрелов", "Сделай 10 выстрелов", 20, 10)
def("combat", "c_shot100", "100 выстрелов", "Сделай 100 выстрелов", 80, 100)
def("combat", "c_combo1", "Первое комбо", "Выполни комбо", 20)
def("combat", "c_combo5", "5 комбо подряд", "Выполни комбо 5 раз подряд", 60, 5)
def("combat", "c_gkill", "Убийство из Гастера", "Победи оружием Гастера", 50)
def("combat", "c_all9", "Все 9 стихий применены", "Примени каждую из 9 стихий", 100, 9)
def("combat", "c_light", "Убийство молнией", "Победи молнией", 40)
def("combat", "c_slowmo", "Слоу-мо", "Включи замедление времени", 20)
def("combat", "c_charged", "Заряженный выстрел", "Сделай заряженный выстрел", 30)
-- Коллекционные
def("collect", "k_ring1", "Первое кольцо", "Включи кольцо", 10)
def("collect", "k_ring5", "Все 5 колец", "Включи все 5 колец одновременно", 60, 5)
def("collect", "k_fig30", "30 фигур", "Открой 30 фигур в коллекции", 40, 30)
def("collect", "k_fig50", "50 фигур", "Открой 50 фигур в коллекции", 100, 50)
def("collect", "k_c3d", "Кастомная 3D-фигура", "Создай фигуру в 3D-редакторе", 50)
def("collect", "k_c2d", "Кастомная 2D-фигура", "Создай фигуру в 2D-редакторе", 50)
def("collect", "k_coin1k", "1000 монет", "Накопи 1000 монет", 50, 1000)
def("collect", "k_coin5k", "5000 монет", "Накопи 5000 монет", 150, 5000)
def("collect", "k_elem", "Все стихии в кольце", "Собери все стихии в кольцах", 80)
def("collect", "k_gparts", "Собраны все 8 частей Гастера", "Собери 8 частей Гастера", 100)
def("collect", "k_gweapon", "Гастер-оружие надето", "Надень оружие Гастера", 60)
def("collect", "k_allfig", "Все фигуры в коллекции", "Открой все фигуры", 300)
def("collect", "k_shop", "Первый визит в магазин", "Открой магазин", 10)
def("collect", "k_atmo", "Атмосфера", "Включи атмосферу или шлейф", 20)
-- Социальные
def("social", "s_bot1", "Первый бот", "Собери первого бота", 10)
def("social", "s_bot10", "10 ботов", "Собери 10 ботов", 30, 10)
def("social", "s_bot100", "100 ботов", "Собери 100 ботов", 120, 100)
def("social", "s_cheat1", "Помечен 1 читер", "Помечи читера через ESP", 20)
def("social", "s_cheat10", "10 читеров", "Помечи 10 читеров", 80, 10)
def("social", "s_dodge", "Уворот от атаки", "Увернись от атаки", 20)
def("social", "s_floor", "Smart Floor спас", "Smart Floor спасает от падения", 40)
def("social", "s_def100", "100 защит", "Античит сработал 100 раз", 100, 100)
def("social", "s_greet", "Приветствие", "Поприветствуй игроков", 10)
def("social", "s_dance", "Танец", "Станцуй", 10)
def("social", "s_helper", "Помощник", "Открой помощника", 10)
def("social", "s_share", "Обмен", "Экспортируй или импортируй настройки", 30)
-- Скрытые
def("hidden", "h_gdeath", "Смерть с Гастером в руках", "Умри с Гастер-оружием", 50)
def("hidden", "h_die10", "Смерть 10 раз", "Умри 10 раз", 40, 10)
def("hidden", "h_dieaura", "Смерть с аурой", "Умри с включённой аурой", 30)
def("hidden", "h_btn9", "Нажал все 9 кнопок стихий", "Нажми каждую из 9 кнопок стихий", 70, 9)
def("hidden", "h_g3", "Гастер пройден 3 раза", "Пройди игру с Гастером 3 раза", 150, 3)
def("hidden", "h_secdance", "Секретный танец", "Станцуй 5 раз за полминуты", 80, 5)
def("hidden", "h_themes", "Все темы UI опробованы", "Попробуй все 4 темы", 40)
def("hidden", "h_mg500", "Рекорд 500+ в мини-игре", "Набери 500+ очков", 100, 500)
def("hidden", "h_mg1000", "Рекорд 1000+", "Набери 1000+ очков", 200, 1000)
def("hidden", "h_hard", "Хардкор пройден", "Пройди мини-игру на хардкоре", 250)
def("hidden", "h_die1", "Первая смерть", "Умри первый раз", 5)
def("hidden", "h_ed3d", "Скульптор", "Открой 3D-редактор", 15)
def("hidden", "h_ed2d", "Художник", "Открой 2D-редактор", 15)
def("hidden", "h_mode", "Две личности", "Смени режим Санс/Обычный", 20)

local lastSave = 0
local function persist()
    if os.clock() - lastSave < 2 then return end
    lastSave = os.clock()
    pcall(ORBIT.saveSettings)
end

function A.isUnlocked(id) return ACH[id] == true end

function A.progress(id)
    local a = A.byId[id]; if not a then return 0 end
    if ACH[id] == true then return 1 end
    return math.clamp((CNT[id] or 0) / a.goal, 0, 1)
end

function A.addReward(id, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    ORBIT.COINS = (ORBIT.COINS or 0) + amount
    pcall(function()
        if ORBIT.HAS_FS and type(writefile) == "function" then
            writefile(ORBIT.COINS_FILE or "orbit_v21_coins.json", tostring(ORBIT.COINS))
        end
    end)
end

local function flash(a)
    pcall(function()
        local sg = ORBIT.ui and ORBIT.ui.screenGui; if not sg then return end
        local f = Instance.new("Frame")
        f.Name = "_OrbitAchFlash"; f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundColor3 = CAT_COLOR[a.cat] or C3(255, 255, 255)
        f.BackgroundTransparency = 0.75; f.BorderSizePixel = 0; f.ZIndex = 200
        f.Active = false; f:SetAttribute("_OrbitNoTheme", true); f.Parent = sg
        local tw = game:GetService("TweenService"):Create(f, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
        tw:Play(); game:GetService("Debris"):AddItem(f, 0.8)
    end)
end

function A.unlock(id)
    local a = A.byId[id]; if not a or ACH[id] == true then return false end
    ACH[id] = true; a.unlocked = true; a.progress = 1
    A.addReward(id, a.reward)
    if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, "ping", 1, 1.5) end
    flash(a)
    if ORBIT.notify then
        ORBIT.notify("🏆 " .. a.name .. (a.reward > 0 and (" (+" .. a.reward .. " 💰)") or ""), CAT_COLOR[a.cat], 4)
    end
    persist()
    if A.refreshUI then pcall(A.refreshUI) end
    return true
end

function A.check(id, value)
    local a = A.byId[id]; if not a then return false end
    if ACH[id] == true then return true end
    value = tonumber(value) or 0
    if value > (CNT[id] or 0) then CNT[id] = value end
    if (CNT[id] or 0) >= a.goal then return A.unlock(id) end
    return false
end

local function bump(id, n) return A.check(id, (CNT[id] or 0) + (n or 1)) end
A.bump = bump

local setSeen = {}
function A.event(name, v)
    if name == "shot" then
        local n = (CNT._shots or 0) + 1; CNT._shots = n
        A.check("c_shot1", n); A.check("c_shot10", n); A.check("c_shot100", n)
    elseif name == "combo" then
        A.unlock("c_combo1")
        CNT._streak = (CNT._streak or 0) + 1
        A.check("c_combo5", CNT._streak)
    elseif name == "element" then
        local key = tostring(v); CNT._el = CNT._el or {}
        if not CNT._el[key] then CNT._el[key] = true end
        local n = 0; for _ in pairs(CNT._el) do n = n + 1 end
        A.check("c_all9", n)
    elseif name == "elementButton" then
        local key = tostring(v); CNT._elb = CNT._elb or {}
        CNT._elb[key] = true
        local n = 0; for _ in pairs(CNT._elb) do n = n + 1 end
        A.check("h_btn9", n)
    elseif name == "gasterKill" then A.unlock("c_gkill")
    elseif name == "lightningKill" then A.unlock("c_light")
    elseif name == "slowmo" then A.unlock("c_slowmo")
    elseif name == "charged" then A.unlock("c_charged")
    elseif name == "bot" then
        local n = (CNT._bots or 0) + 1; CNT._bots = n
        A.check("s_bot1", n); A.check("s_bot10", n); A.check("s_bot100", n)
    elseif name == "cheater" then
        local n = (CNT._cheat or 0) + 1; CNT._cheat = n
        A.check("s_cheat1", n); A.check("s_cheat10", n)
    elseif name == "dodge" then A.unlock("s_dodge")
    elseif name == "floor" then A.unlock("s_floor")
    elseif name == "protect" then
        local n = (CNT._def or 0) + 1; CNT._def = n
        A.check("s_def100", n)
    elseif name == "greet" then A.unlock("s_greet")
    elseif name == "dance" then
        A.unlock("s_dance")
        local now = os.clock()
        setSeen.dance = setSeen.dance or {}
        table.insert(setSeen.dance, now)
        while #setSeen.dance > 0 and now - setSeen.dance[1] > 30 do table.remove(setSeen.dance, 1) end
        A.check("h_secdance", #setSeen.dance)
    elseif name == "gasterDone" then
        local n = (CNT._g or 0) + 1; CNT._g = n
        A.check("h_g3", n)
    elseif name == "minigameScore" then
        local s = tonumber(v) or 0
        A.check("h_mg500", s); A.check("h_mg1000", s)
    elseif name == "hardcoreDone" then A.unlock("h_hard")
    elseif name == "death" then
        A.unlock("h_die1")
        local n = (CNT._die or 0) + 1; CNT._die = n
        A.check("h_die10", n)
        if ORBIT.gaster and ORBIT.gaster.weapon and ORBIT.gaster.weapon.equipped then A.unlock("h_gdeath") end
        if ORBIT.SETTINGS and ORBIT.SETTINGS.AuraEnabled then A.unlock("h_dieaura") end
        CNT._streak = 0
    end
end

-- ----- Оборачивание чужих функций
local wrapped = {}
local function wrap(tbl, key, after)
    if type(tbl) ~= "table" or type(tbl[key]) ~= "function" then return end
    local orig = tbl[key]
    tbl[key] = function(...)
        local r = table.pack(orig(...))
        pcall(after, ...)
        return table.unpack(r, 1, r.n)
    end
    table.insert(wrapped, { tbl, key, orig, tbl[key] })
end

local function hookAll()
    local ab = ORBIT.abilities
    if ab then
        -- v24.0-fix (правка 1): ch приходит bool (true = заряженный). Было type(ch)=="number" — не срабатывало.
        -- v24.0-fix (правка 2): убрал A.event("shot") из fireId — иначе двойной счёт (fire вызывает fireId).
        wrap(ab, "fire", function(ch)
            A.event("shot")
            if ch == true then A.event("charged") end
            if ab.current then A.event("element", ab.current) end
        end)
        wrap(ab, "fireId", function(id) A.event("element", id) end)
        wrap(ab, "combo", function() A.event("combo") end)
        wrap(ab, "slowmo", function() A.event("slowmo") end)
        wrap(ab, "setCurrent", function(id) A.event("elementButton", id) end)
    end
    local g = ORBIT.gaster
    if g then
        -- v24.0-fix (правка 3): assemble(quick) вызывается и кнопкой UI (quick=true). Достижение — только за реальное прохождение.
        wrap(g, "assemble", function(quick)
            A.unlock("k_gparts")
            if quick ~= true then A.event("gasterDone") end
        end)
        if g.weapon then
            wrap(g.weapon, "equip", function() A.unlock("k_gweapon") end)
        end
    end
    wrap(ORBIT, "playDodge", function() A.event("dodge") end)
    wrap(ORBIT, "playBotCollect", function() A.event("bot") end)
    wrap(ORBIT, "playProtect", function() A.event("protect") end)
    wrap(ORBIT, "emote", function(name)
        if name == "greet" then A.event("greet") elseif name == "dance" then A.event("dance") end
    end)
    wrap(ORBIT, "openShop", function() A.unlock("k_shop") end)
    wrap(ORBIT, "openEditor3D", function() A.unlock("h_ed3d") end)
    wrap(ORBIT, "openEditor", function() A.unlock("h_ed2d") end)
    wrap(ORBIT, "helperOpen", function() A.unlock("s_helper") end)
    wrap(ORBIT, "setMode", function() A.unlock("h_mode") end)
    if ORBIT.share then
        for _, k in ipairs({ "copy", "paste", "upload", "download", "applyDecoded" }) do
            wrap(ORBIT.share, k, function() A.unlock("s_share") end)
        end
    end
end

local deathConn, charConn = nil, nil
local function watchChar(char)
    if deathConn then pcall(function() deathConn:Disconnect() end); deathConn = nil end
    local hum = char and char:WaitForChild("Humanoid", 5)
    if not hum then return end
    deathConn = hum.Died:Connect(function() pcall(A.event, "death") end)
end
local lp = ORBIT.LocalPlayer or Players.LocalPlayer
if lp then
    charConn = lp.CharacterAdded:Connect(function(ch) task.spawn(watchChar, ch) end)
    if lp.Character then task.spawn(watchChar, lp.Character) end
end

local pollOn = true
local function countKeys(t) local n = 0; if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end; return n end
task.spawn(function()
    while pollOn do
        task.wait(2)
        pcall(function()
            local ringsOn = 0
            for _, r in pairs(ORBIT.rings or {}) do if r.enabled then ringsOn = ringsOn + 1 end end
            if ringsOn >= 1 then A.unlock("k_ring1") end
            A.check("k_ring5", ringsOn)
            local nf = #(ORBIT.SHAPE_PRESETS or {})
            A.check("k_fig30", nf); A.check("k_fig50", nf)
            do
                local owned = 0
                for _, v in pairs(ORBIT.OWNED_SHAPES or {}) do if v then owned = owned + 1 end end
                if ORBIT.OWNED_SHAPES and nf > 0 and owned >= nf then A.unlock("k_allfig") end
            end
            local coins = ORBIT.COINS or 0
            A.check("k_coin1k", coins); A.check("k_coin5k", coins)
            for _, p in ipairs(ORBIT.SHAPE_PRESETS or {}) do
                if p.isCustom then
                    if p.is3D then A.unlock("k_c3d") else A.unlock("k_c2d") end
                end
            end
            local S = ORBIT.SETTINGS or {}
            if S.AtmoEnabled or S.TrailStreamEnabled then A.unlock("k_atmo") end
            local ec = 0
            if ORBIT.ESP and ORBIT.ESP.Tags then ec = countKeys(ORBIT.ESP.Tags) end
            if ec > (CNT._cheatSeen or 0) then
                for _ = 1, ec - (CNT._cheatSeen or 0) do A.event("cheater") end
                CNT._cheatSeen = ec
            end
            local rec = ORBIT.minigameRecord
            if type(rec) == "table" then
                for name, r in pairs(rec) do
                    if type(r) == "table" and (r.score or 0) > 0 then
                        A.event("minigameScore", r.score)
                        local nm = tostring(name):lower()
                        if (nm:find("hard") or nm:find("хард")) and r.score >= 100 then A.event("hardcoreDone") end
                    end
                end
            end
            if ORBIT.gaster and ORBIT.gaster.weapon and ORBIT.gaster.weapon.equipped then A.unlock("k_gweapon") end
        end)
    end
end)

function A.sync()
    for _, a in ipairs(A.list) do
        a.unlocked = ACH[a.id] == true
        a.progress = A.progress(a.id)
    end
end

local uiPieces = {}
task.spawn(function()
    local UI = ORBIT.ui
    if not (UI and UI.addSection and UI.makeButton and UI.addControl) then return end
    pcall(function() UI.addSection("🏆  ДОСТИЖЕНИЯ", C3(120, 90, 30), "more") end)

    local bar = UI.makeButton("Открыто: 0/" .. #A.list, 30, C3(60, 50, 20), C3(255, 235, 170))
    bar:SetAttribute("_OrbitNoTheme", true)
    UI.addControl(bar, 30, false)
    local tip = UI.makeButton("Нажми на достижение — подсказка", 34, C3(40, 40, 52), C3(220, 220, 235))
    tip:SetAttribute("_OrbitNoTheme", true)
    tip.TextWrapped = true; tip.TextSize = 11
    UI.addControl(tip, 44, false)

    local btns = {}
    local function refresh()
        A.sync()
        local n = 0
        for _, a in ipairs(A.list) do
            local b = btns[a.id]
            if b then
                b.BackgroundColor3 = a.unlocked and (CAT_COLOR[a.cat] or C3(200, 200, 200)) or C3(55, 55, 65)
                b.TextColor3 = a.unlocked and C3(20, 20, 25) or C3(150, 150, 160)
            end
            if a.unlocked then n = n + 1 end
        end
        bar.Text = "🏆 Открыто: " .. n .. "/" .. #A.list
    end
    A.refreshUI = refresh

    local half = false
    for _, a in ipairs(A.list) do
        local short = a.name
        if #short > 14 then short = string.sub(short, 1, utf8.offset(short, 13) and (utf8.offset(short, 13) - 1) or 13) .. "…" end
        local b = UI.makeButton(short, 32, C3(55, 55, 65), C3(150, 150, 160))
        b:SetAttribute("_OrbitNoTheme", true)
        b.TextSize = 10; b.TextWrapped = true
        UI.addControl(b, 36, true)
        btns[a.id] = b
        local function show()
            local pr = math.floor(A.progress(a.id) * 100)
            tip.Text = (CAT_NAME[a.cat] or "") .. " · " .. a.name .. "\n" .. a.desc
                .. "  [" .. (a.unlocked and "✅ 100%" or (pr .. "%")) .. "]  💰" .. a.reward
        end
        if UI.onClick then UI.onClick(b, show, true) else b.Activated:Connect(show) end
    end
    uiPieces = { bar = bar, tip = tip }
    refresh()
end)

hookAll()
A.sync()

ORBIT.achievements = A
ORBIT.achievements.destroy = function()
    pollOn = false
    if deathConn then pcall(function() deathConn:Disconnect() end); deathConn = nil end
    if charConn then pcall(function() charConn:Disconnect() end); charConn = nil end
    for i = #wrapped, 1, -1 do
        local w = wrapped[i]
        if w[1][w[2]] == w[4] then w[1][w[2]] = w[3] end
    end
    wrapped = {}
    A.refreshUI = nil
end

local prevUnloadAch = ORBIT.unload
ORBIT.unload = function()
    pcall(A.destroy)
    if prevUnloadAch then pcall(prevUnloadAch) end
end
end -- ДОСТИЖЕНИЯ

end); if not ok then warn("[Orbit Tools] themes/achievements: " .. tostring(err)) end end

ORBIT.tools = {
    helper = ORBIT.helper, share = ORBIT.share, editor3d = ORBIT.Editor3D, shop = ORBIT.openShop,
    achievements = ORBIT.achievements, applyTheme = ORBIT.applyTheme,
}
ORBIT.loaded.tools = true
if ORBIT.notify then ORBIT.notify("🧰 Tools v24.0 загружен", Color3.fromRGB(180,255,200), 3) end
warn("[Orbit Tools v24.0] Загружен ✅")
return true
