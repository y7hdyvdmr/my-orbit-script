-- ORBIT v24.1 | orbit_tools.lua
-- Содержит: share (обмен фигурами/настройками), helper (текстовый помощник),
-- 4 темы UI (ORBIT.THEMES / applyTheme) и 52 достижения (ORBIT.achievements).
-- Магазин + 2D-редактор живут в orbit_p4_shop.lua, 3D-редактор — в orbit_editor3d.lua
-- (их дубли из tools вырезаны; здесь только ссылки на ORBIT.openShop / openEditor / openEditor3D).
-- v24.0-fix: 3 бага в достижениях (c_charged, fireId double-shot, h_g3 через UI-кнопку).
-- v24.1-fix1 (tools): hookAll ставит отложенные хуки для abilities/gaster/emote/openShop/openEditor —
--                     иначе пол-достижений не срабатывали (эти функции появляются ПОСЛЕ tools).
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
        -- флаг «нажатие уже обработано» (защита от двойного срабатывания Down + Activated)
        local down, downT, lastRelT = false, 0, 0
        local function call()
            if deb then return end
            deb = true
            task.delay(0.12, function() deb = false end)
            if ORBIT.playClick then pcall(ORBIT.playClick) end
            pcall(fn)
        end
        -- нажатие: срабатываем сразу (скроллов в этом окне нет)
        local function press()
            if down and tick() - downT < 1 then return end
            down, downT = true, tick()
            call()
        end
        -- отпускание: если нажатие было — только сбрасываем флаг, иначе (клавиатура/геймпад) вызываем с защитой 0.2 с
        local function release()
            local now = tick()
            if down then
                down = false; lastRelT = now
            elseif now - lastRelT > 0.2 then
                lastRelT = now; call()
            end
        end
        btn.MouseButton1Down:Connect(press)
        btn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then press() end
        end)
        btn.Activated:Connect(release)
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
            local touchStart = nil
            local down, downT, lastRelT = false, 0, 0
            local function call()
                if deb then return end
                deb = true
                task.delay(0.12, function() deb = false end)
                if ORBIT.playClick then pcall(ORBIT.playClick) end
                pcall(fn)
            end
            local function inScroll()
                return btn:GetAttribute("ReleaseOnly")
                    or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil
            end
            local function press()
                if down and tick() - downT < 1 then return end
                down, downT = true, tick()
                if not inScroll() then call() end
            end
            local function release()
                local now = tick()
                if down then
                    down = false; lastRelT = now
                    if inScroll() then call() end
                elseif now - lastRelT > 0.2 then
                    lastRelT = now; call()
                end
            end
            btn.MouseButton1Down:Connect(press)
            btn.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.Touch then
                    touchStart = i.Position
                    press()
                end
            end)
            btn.MouseButton1Click:Connect(release)
            btn.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.Touch and touchStart then
                    local moved = (i.Position - touchStart).Magnitude
                    touchStart = nil
                    if moved < 12 then release() else down = false; lastRelT = tick() end
                end
            end)
            btn.Activated:Connect(release)
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
    end
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

-- ----- Оборачивание чужих функций (v24.1-fix1) -----
-- v24.1-fix1: некоторые ORBIT-функции (abilities/gaster/emote/openShop/openEditor) появляются
--             ПОЗЖЕ tools (грузятся в loader-очереди после). Оборачиваем их в фоновом polling'е.
local wrapped = {}
local function wrap(tbl, key, after)
    if type(tbl) ~= "table" or type(tbl[key]) ~= "function" then return false end
    local orig = tbl[key]
    tbl[key] = function(...)
        local r = table.pack(orig(...))
        pcall(after, ...)
        return table.unpack(r, 1, r.n)
    end
    table.insert(wrapped, { tbl, key, orig, tbl[key] })
    return true
end

local hookedOnce = {}   -- [tbl] = { [key] = true } — не вешаем дважды

local function hookOnce(tbl, key, after)
    if type(tbl) ~= "table" then return false end
    hookedOnce[tbl] = hookedOnce[tbl] or {}
    if hookedOnce[tbl][key] then return true end
    if type(tbl[key]) ~= "function" then return false end
    hookedOnce[tbl][key] = true
    return wrap(tbl, key, after)
end

local function hookAllSync()
    -- то, что уже есть на момент загрузки tools: ядро + p3 + сам tools.
    hookOnce(ORBIT, "playDodge",       function() A.event("dodge") end)
    hookOnce(ORBIT, "playBotCollect",  function() A.event("bot") end)
    hookOnce(ORBIT, "helperOpen",      function() A.unlock("s_helper") end)
    hookOnce(ORBIT, "setMode",         function() A.unlock("h_mode") end)
    if ORBIT.share then
        for _, k in ipairs({ "copy", "paste", "upload", "download", "applyDecoded" }) do
            hookOnce(ORBIT.share, k, function() A.unlock("s_share") end)
        end
    end
end

-- Цели, которые могут появиться позже. Лямбды замкнуты на хук-функцию,
-- чтобы не плодить код при каждом тике polling'а.
local pendingHooks = {
    { path = { "abilities" },      key = "fire",        handler = function(ch)
        A.event("shot")
        if ch == true then A.event("charged") end
        local ab = ORBIT.abilities
        if ab and ab.current then A.event("element", ab.current) end
    end },
    { path = { "abilities" },      key = "fireId",      handler = function(id) A.event("element", id) end },
    { path = { "abilities" },      key = "combo",       handler = function() A.event("combo") end },
    { path = { "abilities" },      key = "slowmo",      handler = function() A.event("slowmo") end },
    { path = { "abilities" },      key = "setCurrent",  handler = function(id) A.event("elementButton", id) end },
    { path = { "gaster" },         key = "assemble",    handler = function(quick)
        A.unlock("k_gparts")
        if quick ~= true then A.event("gasterDone") end
    end },
    { path = { "gaster", "weapon" }, key = "equip",     handler = function() A.unlock("k_gweapon") end },
    { path = {},                   key = "playProtect", handler = function() A.event("protect") end },
    { path = {},                   key = "emote",       handler = function(name)
        if name == "greet" then A.event("greet") elseif name == "dance" then A.event("dance") end
    end },
    { path = {},                   key = "openShop",    handler = function() A.unlock("k_shop") end },
    { path = {},                   key = "openEditor",  handler = function() A.unlock("h_ed2d") end },
    { path = {},                   key = "openEditor3D", handler = function() A.unlock("h_ed3d") end },
}

local function tryHookPending()
    for _, h in ipairs(pendingHooks) do
        local tbl = ORBIT
        for _, seg in ipairs(h.path) do
            tbl = tbl and tbl[seg]
        end
        if tbl and not (hookedOnce[tbl] and hookedOnce[tbl][h.key]) then
            hookOnce(tbl, h.key, h.handler)
        end
    end
end

local pollOn = true
local function startHookPoller()
    task.spawn(function()
        for _ = 1, 240 do       -- ~2 минуты (0.5с * 240)
            if not pollOn then return end
            local allDone = true
            for _, h in ipairs(pendingHooks) do
                local tbl = ORBIT
                for _, seg in ipairs(h.path) do
                    tbl = tbl and tbl[seg]
                end
                if tbl and not (hookedOnce[tbl] and hookedOnce[tbl][h.key]) then
                    allDone = false
                end
            end
            tryHookPending()
            if allDone then return end
            task.wait(0.5)
        end
    end)
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
    refresh()
end)

-- v24.1-fix1: сначала синхронные хуки (ядро/p3/tools), потом отложенные (abilities/gaster/emote/...).
hookAllSync()
startHookPoller()
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
    helper = ORBIT.helper, share = ORBIT.share,
    achievements = ORBIT.achievements, applyTheme = ORBIT.applyTheme,
}
ORBIT.loaded.tools = true
if ORBIT.notify then ORBIT.notify("🧰 Tools v24.1-fix1 загружен", Color3.fromRGB(180,255,200), 3) end
warn("[Orbit Tools v24.1-fix1] Загружен ✅")
return true
