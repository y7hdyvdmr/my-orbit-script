-- Rick & Morty Ultimate v6 — ЗАГРУЗЧИК
-- Сам ничего не умеет: по очереди скачивает части с GitHub, компилирует и запускает.
-- Часть 1 (ядро, интерфейс, порталы, предметы, мир) → потом часть 2 (скины v5, пушки v5, меню v5, запуск).

local BASE = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
local PARTS = { "RickMorty_Part1.min.lua", "RickMorty_Part2.min.lua" }

local function fetch(file)
    local ok, src = pcall(function()
        return game:HttpGet(BASE .. file .. "?t=" .. tostring(os.time()))
    end)
    if not ok or type(src) ~= "string" then
        return nil, "не скачался (сеть или HttpGet)"
    end
    if src:sub(1, 1) == "<" or src:find("404", 1, true) and #src < 500 then
        return nil, "пришла страница ошибки вместо Lua (файла нет на GitHub или ссылка неверная)"
    end
    if #src < 100 then
        return nil, "слишком короткий ответ (" .. #src .. " байт)"
    end
    return src
end

for i, file in ipairs(PARTS) do
    print("[RickMorty loader] часть " .. i .. "/" .. #PARTS .. ": " .. file)
    local src, why = fetch(file)
    if not src then
        warn("[RickMorty loader] " .. file .. ": " .. why)
        return
    end
    local fn, err = loadstring(src, "=" .. file)
    if not fn then
        warn("[RickMorty loader] ошибка компиляции " .. file .. ": " .. tostring(err))
        return
    end
    local runOk, runErr = pcall(fn)
    if not runOk then
        warn("[RickMorty loader] ошибка запуска " .. file .. ": " .. tostring(runErr))
        return
    end
    print("[RickMorty loader] " .. file .. " — готово")
end
print("[RickMorty loader] все части загружены")
