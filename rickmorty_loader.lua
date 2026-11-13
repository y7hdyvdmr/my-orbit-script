-- Rick & Morty Ultimate v6.0 — загрузчик из двух частей
-- Загрузи обе части в корень GitHub-репозитория, затем запусти этот файл.

local BASE = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local PARTS = { "rickmorty_v6_part1.lua", "rickmorty_v6_part2.lua" }

local function fetch(file)
    local ok, src = pcall(function()
        return game:HttpGet(BASE .. file .. "?t=" .. tostring(os.time()))
    end)
    if not ok or type(src) ~= "string" then
        return nil, "не удалось скачать: " .. tostring(src)
    end
    if src:sub(1, 1) == "<" or (#src < 100) then
        return nil, "вместо Lua получен пустой ответ или страница ошибки"
    end
    return src
end

local chunks = {}
for i, file in ipairs(PARTS) do
    print("[RM v6] скачивание " .. i .. "/" .. #PARTS .. ": " .. file)
    local src, err = fetch(file)
    if not src then
        warn("[RM v6] " .. err)
        return
    end
    chunks[i] = src
end

local combined = table.concat(chunks, "")
local compiler = loadstring or load
if type(compiler) ~= "function" then
    warn("[RM v6] В этой среде недоступна компиляция загруженного Lua-кода")
    return
end
local fn, compileErr = compiler(combined, "=RickMorty_Ultimate_v6")
if not fn then
    warn("[RM v6] ошибка компиляции: " .. tostring(compileErr))
    return
end
local ok, runErr = pcall(fn)
if not ok then
    warn("[RM v6] ошибка запуска: " .. tostring(runErr))
    return
end
print("[RM v6] скрипт передан на выполнение")
