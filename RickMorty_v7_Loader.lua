-- ============================================================
-- Rick & Morty Toolkit v7.0 — ЗАГРУЗЧИК (запускай только его)
-- Части должны лежать рядом в GitHub-репозитории с точными именами ниже.
-- При необходимости список FILES можно расширить: порядок загрузки важен.
-- ============================================================
local BASE = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local FILES = {
  "RickMorty_v7_Part1.lua",
  "RickMorty_v7_Part2.lua",
  "RickMorty_v7_Part3.lua",
  "RickMorty_v7_Part4.lua",
  "RickMorty_v7_Part5.lua",
}
local OVERRIDE = {}
local G = (type(getgenv) == "function" and getgenv()) or _G
local MAX_PART_BYTES = 180000 -- запас до возможного лимита около 200 КБ
local function say(msg) print("[RickMorty loader] " .. msg) end
local function bad(msg) warn("[RickMorty loader] " .. msg) end
if type(loadstring) ~= "function" then bad("в этой среде нет loadstring") return end

local FUNCS = {}
local function fetch(i)
  local url = OVERRIDE[i] or (BASE .. FILES[i] .. "?t=" .. tostring(os.time()))
  local ok, src = pcall(function() return game:HttpGet(url) end)
  if not ok or type(src) ~= "string" then return nil, "не удалось скачать: " .. tostring(src) end
  if src:sub(1, 1) == "<" or (src:find("404", 1, true) and #src < 500) then
    return nil, "вместо Lua получена страница ошибки: " .. url
  end
  if #src < 200 then return nil, "ответ слишком короткий: " .. #src .. " байт" end
  if #src > MAX_PART_BYTES then return nil, "часть слишком большая: " .. #src .. " байт; раздели её на дополнительные части" end
  return src
end

-- Сначала скачиваем и компилируем ВСЕ части. Текущая версия остаётся нетронутой,
-- если сеть, имена файлов или синтаксис новой версии окажутся неправильными.
for i = 1, #FILES do
  say("проверка файла " .. i .. "/" .. #FILES .. ": " .. FILES[i])
  local src, why = fetch(i)
  if not src then bad("ЧАСТЬ " .. i .. ": " .. why) return end
  local fn, err = loadstring(src, "=" .. FILES[i])
  if not fn then bad("ЧАСТЬ " .. i .. ": ошибка компиляции: " .. tostring(err)) return end
  FUNCS[i] = fn
end

-- Новая версия прошла предварительную проверку: теперь можно выгрузить старую.
for _, k in ipairs({ "RickMortyV6", "RickMorty" }) do
  local old = G[k]
  if type(old) == "table" and type(old.unload) == "function" then
    pcall(old.unload)
    say("предыдущая версия выгружена: " .. k)
  end
end

local function abort(i, why)
  bad("ЧАСТЬ " .. i .. " (" .. tostring(FILES[i]) .. "): " .. why)
  for _, k in ipairs({ "RickMorty", "RickMortyV6" }) do
    local rm = G[k]
    if type(rm) == "table" and type(rm.unload) == "function" then pcall(rm.unload) end
  end
  bad("загрузка остановлена; доступная очистка выполнена")
end

for i = 1, #FUNCS do
  say("запуск части " .. i .. "/" .. #FUNCS .. ": " .. FILES[i])
  local ok, runErr = pcall(FUNCS[i])
  if not ok then abort(i, "ошибка выполнения: " .. tostring(runErr)) return end
  local rm = G.RickMorty
  if type(rm) ~= "table" or not rm["_part" .. i] then
    abort(i, "часть не зарегистрировалась; проверь порядок и список FILES")
    return
  end
  say("часть " .. i .. " загружена")
end
local rm = G.RickMorty
if rm and rm._ready then
  say("все " .. #FUNCS .. " частей загружены. Версия " .. tostring(rm._version))
else
  bad("части выполнены, но Toolkit не сообщил о полной готовности")
end
