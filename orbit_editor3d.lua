--[[ ОРБИТА v23.3 — 3D-РЕДАКТОР ФИГУР v3.0 (orbit_editor3d.lua)
     Открывается через ORBIT.openEditor3D()
     • Сетка N×N×N (4..8), слои Z, симметрия X/Y/Z, история 20 шагов
     • Камера: свайп — вращение, пинч — зум, кнопки сброса/зума
     • Выбор клетки: свой луч + rayAABB (Workspace:Raycast в ViewportFrame не работает)
     • Сохранение в ORBIT.SHAPE_PRESETS / ORBIT.CUSTOM_SHAPES (+ writefile, если есть)
     ВАЖНО: все идентификаторы — латиницей, кириллица только в комментариях и текстах.
]]
--[[ ИЗМЕНЕНИЯ (общий релиз v23.5): onClick срабатывает при отпускании пальца внутри ScrollingFrame
     (прокрутка панелей не нажимает кнопки). Логика редактора не менялась. ]]
--[[ ФИКСЫ v23.6:
  🐛 onClick НЕ играл ORBIT.playClick — кнопки редактора молчали, при этом кнопки палитры
     отдельно вызывали playClick (несогласованность). Теперь клик играется единообразно из onClick.
  ✅ остальной код проверен построчно: Ed.Conns пуст (но не утечка — все коннекты на Ed.Vp/Ed.Gui,
     умирают с Destroy), Workspace не пачкается, undo/redo/setGridSize/pickFromScreen — корректны.
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (type(getgenv) == "function" and getgenv().ORBIT)
if not ORBIT then warn("[Orbit 3D Editor] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit 3D Editor] UI не готов!"); return end

local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local screenGui   = ORBIT.ui.screenGui
local IS_MOBILE   = (ORBIT.PLATFORM == "mobile")
local PREFIX      = "Orbit3D_"

-- Если скрипт запущен повторно — аккуратно закрываем старый экземпляр
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
    "Золотой", "Свето-золотой", "Бронзовый",
}

local C = {
    bg     = Color3.fromRGB(18, 14, 30),
    panel  = Color3.fromRGB(22, 16, 36),
    btn    = Color3.fromRGB(45, 38, 65),
    btnOn  = Color3.fromRGB(80, 140, 200),
    text   = Color3.fromRGB(225, 215, 255),
    title  = Color3.fromRGB(48, 38, 76),
    accent = Color3.fromRGB(180, 130, 255),
}

-- ============================================================
--       СОСТОЯНИЕ
-- ============================================================
local Ed = {
    Open = false, Gui = nil, Vp = nil, World = nil, Cam = nil,
    BlockFolder = nil, GridFolder = nil,
    N = 6, ActiveZ = 1, Mode = "place",
    SymX = false, SymY = false, SymZ = false,
    Color = 1,
    Cells = {},          -- [key] = {x, y, z, color}
    Parts = {},          -- [key] = Part (визуал блока)
    States = {}, StateIdx = 0, MaxHistory = 20,
    Az = -45, El = 30, Dist = 16,
    Conns = {}, UI = {},
}

local HALF = Vector3.new(0.5, 0.5, 0.5)

local function key(x, y, z) return (x * 16 + y) * 16 + z end

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

-- ============================================================
--       УТИЛИТЫ GUI
-- ============================================================
-- Создаёт объект, даёт имя с префиксом и ZIndex = ZIndex родителя + 1
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

-- Универсальный тап (Delta/Android): Down + Touch + Activated
-- + защита от двойного срабатывания (Activated приходит после касания)
-- ============================================================
--  onClick: Down + Touch + Activated (Android / Delta).
--  Внутри ScrollingFrame кнопка срабатывает при ОТПУСКАНИИ пальца (если он почти не двигался),
--  иначе свайп для прокрутки нажимал бы кнопки под пальцем. Атрибут ReleaseOnly = true
--  включает этот режим принудительно (например, для перетаскиваемых кнопок).
-- ============================================================
local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        -- 🐛 ФИКС v23.6: играем клик, чтобы кнопки редактора не были «молчаливыми»
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
--       ЛУЧ: rayAABB (своя функция, без Workspace:Raycast)
-- ============================================================
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

-- Луч из точки внутри ViewportFrame (px, py — относительно его угла)
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

-- Выбор клетки: сначала блоки активного слоя, потом плоскость слоя
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

-- ============================================================
--       ВИЗУАЛ: СЕТКА И БЛОКИ
-- ============================================================
local function setupPart(p, color, transp)
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
    p.CastShadow = false; p.Material = Enum.Material.Neon
    p.Color = color; p.Transparency = transp
end

-- Ось-выровненный отрезок/пластина между двумя точками
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

    -- внешний куб (12 рёбер)
    for _, u in ipairs({-h, h}) do
        for _, v in ipairs({-h, h}) do
            gridSeg(Vector3.new(-h, u, v), Vector3.new(h, u, v), frameCol, 0.7, 0.05)
            gridSeg(Vector3.new(u, -h, v), Vector3.new(u, h, v), frameCol, 0.7, 0.05)
            gridSeg(Vector3.new(u, v, -h), Vector3.new(u, v, h), frameCol, 0.7, 0.05)
        end
    end

    -- остальные слои: только тонкая рамка (полупрозрачно)
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

    -- активный слой: яркая сетка + лёгкая заливка
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

-- ============================================================
--       ИСТОРИЯ (до 20 шагов)
-- ============================================================
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
    Ed.States = {snapshot()}
    Ed.StateIdx = 1
end
-- вызывается ПОСЛЕ изменения: запоминает новое состояние
local function commit()
    while #Ed.States > Ed.StateIdx do table.remove(Ed.States) end
    table.insert(Ed.States, snapshot())
    Ed.StateIdx = #Ed.States
    while #Ed.States > Ed.MaxHistory + 1 do
        table.remove(Ed.States, 1)
        Ed.StateIdx = Ed.StateIdx - 1
    end
end
local function doUndo()
    if Ed.StateIdx <= 1 then return end
    Ed.StateIdx = Ed.StateIdx - 1
    restore(Ed.States[Ed.StateIdx])
    refreshView()
end
local function doRedo()
    if Ed.StateIdx >= #Ed.States then return end
    Ed.StateIdx = Ed.StateIdx + 1
    restore(Ed.States[Ed.StateIdx])
    refreshView()
end
resetHistory()

-- ============================================================
--       ДЕЙСТВИЯ НАД СЕТКОЙ
-- ============================================================
-- Точка + её зеркальные пары по включённым осям симметрии
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
    for _, p in ipairs(mirrored(x, y, z)) do
        local k = key(p[1], p[2], p[3])
        local cur = Ed.Cells[k]
        if Ed.Mode == "place" then
            -- поставить (на занятой клетке — перекрасить)
            if not cur or cur.color ~= col then
                Ed.Cells[k] = {x = p[1], y = p[2], z = p[3], color = col}
                changed = true
            end
        elseif Ed.Mode == "remove" then
            if cur then Ed.Cells[k] = nil; changed = true end
        else -- paint
            if cur and cur.color ~= col then cur.color = col; changed = true end
        end
    end
    if changed then commit(); refreshView() end
end

local function fillWith(testFn)
    local col = PALETTE[Ed.Color]
    for x = 1, Ed.N do for y = 1, Ed.N do for z = 1, Ed.N do
        if testFn(x, y, z) then
            Ed.Cells[key(x, y, z)] = {x = x, y = y, z = z, color = col}
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

-- Поворот всей фигуры на 90° вокруг центра куба
local function rotateAll(axis, dir)
    local N = Ed.N
    local c = (N + 1) / 2
    local out = {}
    for _, cell in pairs(Ed.Cells) do
        local x, y, z = cell.x - c, cell.y - c, cell.z - c
        local nx, ny, nz = x, y, z
        if axis == "X" then
            ny, nz = -z * dir, y * dir
        else -- "Y"
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
end

local function setActiveZ(z)
    Ed.ActiveZ = math.clamp(z, 1, Ed.N)
    buildGrid()
    refreshView()
end

-- ============================================================
--       РЕГИСТРАЦИЯ ФИГУРЫ
-- ============================================================
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

    -- Нормализуем: фигура центрируется в кубе размером size
    local size = math.max(maxX - minX + 1, maxY - minY + 1, maxZ - minZ + 1)
    local cx, cy, cz = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
    local mid = (size + 1) / 2
    local blocksCopy = {}
    for _, c in pairs(Ed.Cells) do
        table.insert(blocksCopy, {
            x = c.x - cx + mid, y = c.y - cy + mid, z = c.z - cz + mid, color = c.color,
        })
    end

    -- Уникальное имя
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

    -- Хранилище (формат совпадает с загрузчиком в orbit_p4_shop.lua)
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

-- ============================================================
--       ЗАКРЫТИЕ
-- ============================================================
local function closeEditor()
    Ed.Open = false
    for _, cn in ipairs(Ed.Conns) do pcall(function() cn:Disconnect() end) end
    Ed.Conns = {}
    if Ed.Gui then pcall(function() Ed.Gui:Destroy() end) end
    Ed.Gui, Ed.Vp, Ed.World, Ed.Cam = nil, nil, nil, nil
    Ed.BlockFolder, Ed.GridFolder = nil, nil
    Ed.Parts = {}
    Ed.UI = {}
end

-- ============================================================
--       ОКНО РЕДАКТОРА
-- ============================================================
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

    -- ---------- ViewportFrame ----------
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

    -- ---------- Жесты: свайп / пинч / тап ----------
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
                g.moved = true; g.last = nil   -- второй палец: это не тап
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
                    Ed.Dist = math.clamp(pinchZoom * pinchStart / d, 5, 40)
                    updateCamera()
                end
                return
            end
            rotateBy(input.Position, 8)
        elseif t == Enum.UserInputType.MouseMovement then
            if g.mouse then rotateBy(input.Position, 6) end
        elseif t == Enum.UserInputType.MouseWheel then
            Ed.Dist = math.clamp(Ed.Dist - input.Position.Z * 1.5, 5, 40)
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

    -- ---------- Палитра (всегда под вьюпортом) ----------
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
            -- playClick теперь играет сам onClick — отдельный вызов не нужен
        end)
    end
    refreshPalette()

    -- ---------- Панель инструментов (вертикальный скролл) ----------
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
    local list = mk("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, ctrl)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10),
    }, ctrl)
    local function fitCanvas()
        ctrl.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 18)
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitCanvas)

    local secOrder = 0
    local function section(title, bodyH)
        secOrder = secOrder + 1
        local f = mk("Frame", {
            Name = "Sec", Size = UDim2.new(1, 0, 0, 22 + bodyH), BackgroundTransparency = 1,
            LayoutOrder = secOrder,
        }, ctrl)
        local t = mk("TextLabel", {
            Name = "SecTitle", Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = C.title,
            BorderSizePixel = 0, Text = "  " .. title, TextColor3 = C.text,
            Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        corner(t, 4)
        return mk("Frame", {
            Name = "Body", Size = UDim2.new(1, 0, 0, bodyH), Position = UDim2.new(0, 0, 0, 22),
            BackgroundTransparency = 1,
        }, f)
    end

    local function buttonRow(body, items, y, h, textSize)
        local btns = {}
        local n = #items
        for i, it in ipairs(items) do
            local b = mk("TextButton", {
                Name = "Btn", Size = UDim2.new(1 / n, -4, 0, h or 32),
                Position = UDim2.new((i - 1) / n, 2, 0, y or 0),
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
            end
        end
        local items = {}
        for i, m in ipairs(modes) do
            items[i] = {text = texts[m.key], fn = function() Ed.Mode = m.key; paintModes() end}
        end
        btns = buttonRow(body, items, 0, 32, 11)
        paintModes()
    end

    -- 📐 РАЗМЕР СЕТКИ
    do
        local body = section("📐 РАЗМЕР СЕТКИ", 32)
        local sizes = {4, 5, 6, 7, 8}
        local btns = {}
        local function paintSizes()
            for i, n in ipairs(sizes) do
                btns[i].BackgroundColor3 = (Ed.N == n) and C.btnOn or C.btn
            end
        end
        local items = {}
        for i, n in ipairs(sizes) do
            items[i] = {text = tostring(n), fn = function()
                if Ed.N ~= n then setGridSize(n) end
                paintSizes()
            end}
        end
        btns = buttonRow(body, items, 0, 32, 13)
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
        -- средняя «кнопка» — просто подпись текущего слоя
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
        local gray = Color3.fromRGB(60, 60, 80)
        buttonRow(body, {
            {text = "↩ Отмена",  fn = doUndo, color = gray},
            {text = "↪ Вернуть", fn = doRedo, color = gray},
        }, 0, 32, 11)
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
            {text = "➖ Зум", color = cam, fn = function() Ed.Dist = math.min(40, Ed.Dist + 1.5); updateCamera() end},
            {text = "🎯 Сброс камеры", color = cam, fn = function()
                Ed.Az, Ed.El, Ed.Dist = -45, 30, defaultDist()
                updateCamera()
            end},
        }, 0, 32, 10)
    end

    -- 💾 СОХРАНЕНИЕ
    do
        local body = section("💾 СОХРАНЕНИЕ", 74)
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
    end

    -- Подсказка
    local hintText = "👆 Свайп по 3D — вращать\n🔍 Пинч двумя пальцами — зум\n👆 Тап по клетке — действие по режиму\n📚 Редактируется активный слой (▲/▼)"
    if IS_MOBILE then
        secOrder = secOrder + 1
        mk("TextLabel", {
            Name = "Hint", Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Color3.fromRGB(30, 40, 60),
            BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = hintText,
            TextColor3 = Color3.fromRGB(200, 220, 255), Font = Enum.Font.Gotham, TextSize = 10,
            TextWrapped = true, LayoutOrder = secOrder,
        }, ctrl)
    else
        local hint = mk("TextLabel", {
            Name = "Hint", Size = UDim2.new(0, palW, 0, 70), Position = UDim2.new(0, 10, 0, palY + 82),
            BackgroundColor3 = Color3.fromRGB(30, 40, 60), BackgroundTransparency = 0.3,
            BorderSizePixel = 0, Text = hintText, TextColor3 = Color3.fromRGB(200, 220, 255),
            Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true,
        }, Ed.Gui)
        corner(hint, 6)
    end

    -- Обновление счётчика и подписи слоя
    Ed.UI.refreshInfo = function()
        countLbl.Text = "🧱 " .. countCells()
        if Ed.UI.refreshLayer then Ed.UI.refreshLayer() end
    end
    Ed.UI.refreshInfo()
    fitCanvas()
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
Ed.Close = closeEditor
ORBIT.openEditor3D = openEditor3D
ORBIT.Editor3D = Ed

if ORBIT.notify then
    ORBIT.notify("🔮 3D-Редактор v3.0 загружен", Color3.fromRGB(200, 180, 255), 3)
end
warn("[Orbit 3D Editor v3.0] Загружен ✅")
return true
