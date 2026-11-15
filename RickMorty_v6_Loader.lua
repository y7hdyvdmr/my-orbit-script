-- ============================================================
--  Rick & Morty Toolkit v6.0 — ЗАГРУЗЧИК (запускай только его)
--  По очереди скачивает RickMorty_v6_Part1..Part5.lua, компилирует, запускает и проверяет.
--
--  ВАЖНО: ссылки ниже — ТВОЯ папка на GitHub. Все 5 частей должны лежать в ней
--  с ТОЧНЫМИ именами файлов. Если папка/репозиторий другие — поменяй BASE.
--  (Это тот же репозиторий, что был у V5: файлы V6 в нём появятся, только когда ты их загрузишь.)
-- ============================================================
local BASE = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/" -- ← МЕНЯЙ ЗДЕСЬ, если файлы лежат в другом месте
local FILES = {
  "RickMorty_v6_Part1.lua",
  "RickMorty_v6_Part2.lua",
  "RickMorty_v6_Part3.lua",
  "RickMorty_v6_Part4.lua",
  "RickMorty_v6_Part5.lua",
}
-- Если хочешь, укажи полную ссылку для отдельной части (иначе берётся BASE + имя файла):
local OVERRIDE = { -- [1] = "https://raw.githubusercontent.com/.../RickMorty_v6_Part1.lua",
}

local G = (type(getgenv) == "function" and getgenv()) or _G
local function say(msg) print("[RickMorty loader] " .. msg) end
local function bad(msg) warn("[RickMorty loader] " .. msg) end

-- 1. проверка среды
if type(loadstring) ~= "function" then bad("в этом исполнителе нет loadstring — загрузка невозможна") return end

-- 2. выгрузить предыдущую версию
for _, k in ipairs({ "RickMortyV6", "RickMorty" }) do
  local old = G[k]
  if type(old) == "table" and type(old.unload) == "function" then
    pcall(old.unload)
    say("предыдущая версия (" .. k .. ") выгружена")
  end
end

local function fetch(i)
  local url = OVERRIDE[i] or (BASE .. FILES[i] .. "?t=" .. tostring(os.time()))
  local ok, src = pcall(function() return game:HttpGet(url) end)
  if not ok or type(src) ~= "string" then
    return nil, "не скачался (сеть/HttpGet): " .. tostring(src)
  end
  if src:sub(1, 1) == "<" or (src:find("404", 1, true) and #src < 500) then
    return nil, "вместо Lua пришла страница ошибки — проверь, что файл есть по ссылке:\n" .. url
  end
  if #src < 200 then return nil, "слишком короткий ответ (" .. #src .. " байт)" end
  return src
end

local function abort(i, why)
  bad("ЧАСТЬ " .. i .. " (" .. FILES[i] .. "): " .. why)
  -- безопасная очистка того, что успело создаться
  for _, k in ipairs({ "RickMorty", "RickMortyV6" }) do
    local rm = G[k]
    if type(rm) == "table" and type(rm.unload) == "function" then pcall(rm.unload) end
  end
  bad("загрузка остановлена, частично созданное удалено")
end

-- 3. загрузка частей строго по порядку
for i = 1, #FILES do
  say("часть " .. i .. "/" .. #FILES .. ": " .. FILES[i])
  local src, why = fetch(i)
  if not src then abort(i, why) return end
  local fn, err = loadstring(src, "=" .. FILES[i])
  if not fn then abort(i, "ошибка компиляции: " .. tostring(err)) return end
  local ok, runErr = pcall(fn)
  if not ok then abort(i, "ошибка запуска: " .. tostring(runErr)) return end
  -- 4. проверка, что часть зарегистрировалась
  local rm = G.RickMorty
  if type(rm) ~= "table" or not rm["_part" .. i] then
    abort(i, "часть выполнилась, но не отметила себя загруженной")
    return
  end
  say("часть " .. i .. " — готово")
end

local rm = G.RickMorty
if rm and rm._ready then
  say("все 5 частей загружены. Версия " .. tostring(rm._version) .. ", систем: " .. tostring(rm.systems and #rm.systems or "?"))
else
  bad("части загружены, но Toolkit не сообщил о готовности — смотри предупреждения выше")
end
