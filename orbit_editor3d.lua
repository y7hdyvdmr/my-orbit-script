--[[ ОРБИТА v23.0 — 3D-РЕДАКТОР ФИГУР
     🧊 Настоящий 3D: вращение камеры, слои, симметрия
     🎨 Палитра 24 цвета
     🖌 Режимы: поставить / удалить / красить
     ↩️ Undo/Redo, шаблоны (куб/шар/крест)
     📥 Экспорт/импорт JSON
     💾 Сохранение прямо в SHAPE_PRESETS
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit 3D Editor] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit 3D Editor] UI не готов!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local HttpService  = ORBIT.HttpService
local LocalPlayer  = ORBIT.LocalPlayer
local screenGui    = ORBIT.ui.screenGui
local IS_MOBILE    = (ORBIT.PLATFORM == "mobile")

-- ============================================================
--       ПАЛИТРА
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
local selectedColorIndex = 1

-- ============================================================
--       СОСТОЯНИЕ РЕДАКТОРА
-- ============================================================
local Ed = {
    Open = false,
    Gui = nil,
    Vp = nil,
    World = nil,
    Cam = nil,
    Folder = nil,         -- папка с занятыми клетками
    GridFolder = nil,     -- папка с сеткой
    N = 6,                -- размер сетки (N×N×N)
    ActiveZ = 1,          -- активный слой
    Mode = "place",       -- place / remove / paint
    SymX = false,
    SymY = false,
    SymZ = false,
    Cells = {},           -- [key] = {x, y, z, color}
    History = {},         -- undo stack
    HistoryIdx = 0,
    MaxHistory = 20,
    CamAzimuth = -45,
    CamElevation = 30,
    CamDistance = 14,
    Dragging = false,
    DragStart = nil,
    DragMoved = false,
    DragBegan = nil,
    Name = "",
}
local function cellKey(x, y, z) return x .. "|" .. y .. "|" .. z end

-- ============================================================
--       УТИЛИТЫ 3D
-- ============================================================
local function cellToWorld(x, y, z)
    -- Центр сетки в (0,0,0), клетки размером 1
    local off = (Ed.N - 1) / 2
    return Vector3.new(x - off - 1, y - off - 1, z - off - 1)
end

local function worldToCell(pos)
    local off = (Ed.N - 1) / 2
    local x = math.floor(pos.X + off + 1.5)
    local y = math.floor(pos.Y + off + 1.5)
    local z = math.floor(pos.Z + off + 1.5)
    if x < 1 or x > Ed.N then return nil end
    if y < 1 or y > Ed.N then return nil end
    if z < 1 or z > Ed.N then return nil end
    return x, y, z
end

-- Пересечение луча с AABB (box min/max)
local function rayAABB(ro, rd, mn, mx)
    local tmin, tmax = -math.huge, math.huge
    local function axis(o, d, lo, hi)
        if math.abs(d) < 1e-8 then
            if o < lo or o > hi then return false end
        else
            local t1 = (lo - o) / d
            local t2 = (hi - o) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            if t1 > tmin then tmin = t1 end
            if t2 < tmax then tmax = t2 end
            if tmin > tmax then return false end
        end
        return true
    end
    if not axis(ro.X, rd.X, mn.X, mx.X) then return nil end
    if not axis(ro.Y, rd.Y, mn.Y, mx.Y) then return nil end
    if not axis(ro.Z, rd.Z, mn.Z, mx.Z) then return nil end
    if tmax < 0 then return nil end
    return tmin >= 0 and tmin or tmax
end

-- ============================================================
--       ПОСТРОЕНИЕ СЕТКИ
-- ============================================================
local function clearGridVisual()
    if Ed.GridFolder then Ed.GridFolder:Destroy(); Ed.GridFolder = nil end
    Ed.GridFolder = Instance.new("Folder")
    Ed.GridFolder.Name = "Grid"
    Ed.GridFolder.Parent = Ed.World
end

local function buildGridVisual()
    clearGridVisual()
    local N = Ed.N
    local off = (N - 1) / 2

    -- Рёбра куба
    local function line(a, b, color, transp, thickness)
        local diff = b - a
        local len = diff.Magnitude
        local p = Instance.new("Part")
        p.Name = "Line"
        p.Size = Vector3.new(thickness or 0.04, thickness or 0.04, len)
        p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + diff.Unit)
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.CastShadow = false
        p.Material = Enum.Material.Neon
        p.Color = color
        p.Transparency = transp or 0.6
        p.Parent = Ed.GridFolder
    end

    -- Линии сетки текущего слоя (активный Z)
    local zLevel = Ed.ActiveZ - off - 1
    local cActive = PALETTE[selectedColorIndex]
    for i = 0, N do
        local x = i - off - 1
        local y = i - off - 1
        -- По X
        line(Vector3.new(-off - 1, -off - 1, zLevel), Vector3.new(-off - 1 + N, -off - 1, zLevel), cActive, 0.75, 0.03)
        line(Vector3.new(-off - 1, y - 0.0, zLevel), Vector3.new(-off - 1 + N, y, zLevel), cActive, 0.85, 0.02)
        -- По Y
        line(Vector3.new(x, -off - 1, zLevel), Vector3.new(x, -off - 1 + N, zLevel), cActive, 0.85, 0.02)
    end

    -- Полупрозрачная платформа активного слоя
    local plat = Instance.new("Part")
    plat.Name = "Plat"
    plat.Size = Vector3.new(N, 0.02, N)
    plat.CFrame = CFrame.new(0, -off - 1, zLevel)
    plat.Anchored = true
    plat.CanCollide = false
    plat.CanQuery = false
    plat.CanTouch = false
    plat.CastShadow = false
    plat.Material = Enum.Material.Neon
    plat.Color = cActive
    plat.Transparency = 0.92
    plat.Parent = Ed.GridFolder

    -- Каркас куба (внешний)
    local cc = Color3.fromRGB(120, 160, 220)
    local a = -off - 1
    local b = a + N
    for _, pair in ipairs({
        {Vector3.new(a,a,a), Vector3.new(b,a,a)},
        {Vector3.new(b,a,a), Vector3.new(b,a,b)},
        {Vector3.new(b,a,b), Vector3.new(a,a,b)},
        {Vector3.new(a,a,b), Vector3.new(a,a,a)},
        {Vector3.new(a,b,a), Vector3.new(b,b,a)},
        {Vector3.new(b,b,a), Vector3.new(b,b,b)},
        {Vector3.new(b,b,b), Vector3.new(a,b,b)},
        {Vector3.new(a,b,b), Vector3.new(a,b,a)},
        {Vector3.new(a,a,a), Vector3.new(a,b,a)},
        {Vector3.new(b,a,a), Vector3.new(b,b,a)},
        {Vector3.new(b,a,b), Vector3.new(b,b,b)},
        {Vector3.new(a,a,b), Vector3.new(a,b,b)},
    }) do
        line(pair[1], pair[2], cc, 0.8, 0.03)
    end
end

-- ============================================================
--       РЕНДЕР БЛОКОВ
-- ============================================================
local function clearBlocksVisual()
    if Ed.Folder then Ed.Folder:Destroy() end
    Ed.Folder = Instance.new("Folder")
    Ed.Folder.Name = "Blocks"
    Ed.Folder.Parent = Ed.World
end

local function buildBlock(x, y, z, color, isActiveLayer)
    local p = Instance.new("Part")
    p.Name = "Cell_" .. x .. "_" .. y .. "_" .. z
    p.Size = Vector3.new(0.92, 0.92, 0.92)
    p.Position = cellToWorld(x, y, z)
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = color or PALETTE[selectedColorIndex]
    p.Transparency = isActiveLayer and 0.05 or 0.55
    p.Parent = Ed.Folder
    return p
end

local function rebuildAllBlocks()
    clearBlocksVisual()
    for _, cell in pairs(Ed.Cells) do
        buildBlock(cell.x, cell.y, cell.z, cell.color, cell.z == Ed.ActiveZ)
    end
end

local function updateBlocksTransparency()
    for _, p in ipairs(Ed.Folder:GetChildren()) do
        local _, _, z = p.Name:match("Cell_(%d+)_(%d+)_(%d+)")
        if z then
            z = tonumber(z)
            p.Transparency = (z == Ed.ActiveZ) and 0.05 or 0.55
        end
    end
end

-- ============================================================
--       UNDO / REDO
-- ============================================================
local function pushHistory()
    Ed.HistoryIdx = Ed.HistoryIdx + 1
    while #Ed.History > Ed.HistoryIdx - 1 do table.remove(Ed.History) end
    local snapshot = {}
    for k, v in pairs(Ed.Cells) do
        snapshot[k] = {x=v.x, y=v.y, z=v.z, color=v.color}
    end
    table.insert(Ed.History, snapshot)
    if #Ed.History > Ed.MaxHistory then table.remove(Ed.History, 1); Ed.HistoryIdx = Ed.HistoryIdx - 1 end
end

local function doUndo()
    if Ed.HistoryIdx <= 1 then return end
    Ed.HistoryIdx = Ed.HistoryIdx - 1
    local snap = Ed.History[Ed.HistoryIdx]
    Ed.Cells = {}
    for k, v in pairs(snap) do Ed.Cells[k] = {x=v.x, y=v.y, z=v.z, color=v.color} end
    rebuildAllBlocks()
end

local function doRedo()
    if Ed.HistoryIdx >= #Ed.History then return end
    Ed.HistoryIdx = Ed.HistoryIdx + 1
    local snap = Ed.History[Ed.HistoryIdx]
    Ed.Cells = {}
    for k, v in pairs(snap) do Ed.Cells[k] = {x=v.x, y=v.y, z=v.z, color=v.color} end
    rebuildAllBlocks()
end

-- ============================================================
--       ДЕЙСТВИЯ
-- ============================================================
local function setCell(x, y, z, color)
    local k = cellKey(x, y, z)
    Ed.Cells[k] = {x=x, y=y, z=z, color=color}
end
local function delCell(x, y, z)
    Ed.Cells[cellKey(x, y, z)] = nil
end

local function applySymmetry(x, y, z, color, isSet)
    local points = {{x, y, z}}
    local N = Ed.N
    if Ed.SymX then
        local count = #points
        for i = 1, count do
            local p = points[i]
            table.insert(points, {N + 1 - p[1], p[2], p[3]})
        end
    end
    if Ed.SymY then
        local count = #points
        for i = 1, count do
            local p = points[i]
            table.insert(points, {p[1], N + 1 - p[2], p[3]})
        end
    end
    if Ed.SymZ then
        local count = #points
        for i = 1, count do
            local p = points[i]
            table.insert(points, {p[1], p[2], N + 1 - p[3]})
        end
    end
    for _, p in ipairs(points) do
        if isSet then
            setCell(p[1], p[2], p[3], color)
        else
            delCell(p[1], p[2], p[3])
        end
    end
end

local function applyMode(x, y, z)
    pushHistory()
    if Ed.Mode == "remove" then
        applySymmetry(x, y, z, nil, false)
        rebuildAllBlocks()
    elseif Ed.Mode == "paint" then
        local k = cellKey(x, y, z)
        if Ed.Cells[k] then
            Ed.Cells[k].color = PALETTE[selectedColorIndex]
            rebuildAllBlocks()
        end
    else -- place
        applySymmetry(x, y, z, PALETTE[selectedColorIndex], true)
        rebuildAllBlocks()
    end
end

local function clearAll()
    pushHistory()
    Ed.Cells = {}
    rebuildAllBlocks()
end

local function fillCube()
    pushHistory()
    for x = 1, Ed.N do
        for y = 1, Ed.N do
            for z = 1, Ed.N do
                setCell(x, y, z, PALETTE[selectedColorIndex])
            end
        end
    end
    rebuildAllBlocks()
end

local function fillSphere()
    pushHistory()
    local c = (Ed.N + 1) / 2
    local r = (Ed.N - 0.5) / 2
    for x = 1, Ed.N do
        for y = 1, Ed.N do
            for z = 1, Ed.N do
                local dx, dy, dz = x - c, y - c, z - c
                if dx*dx + dy*dy + dz*dz <= r*r then
                    setCell(x, y, z, PALETTE[selectedColorIndex])
                end
            end
        end
    end
    rebuildAllBlocks()
end

local function fillCross()
    pushHistory()
    local c = math.ceil(Ed.N / 2)
    for i = 1, Ed.N do
        setCell(i, c, c, PALETTE[selectedColorIndex])
        setCell(c, i, c, PALETTE[selectedColorIndex])
        setCell(c, c, i, PALETTE[selectedColorIndex])
    end
    rebuildAllBlocks()
end

local function clearLayer()
    pushHistory()
    for k, cell in pairs(Ed.Cells) do
        if cell.z == Ed.ActiveZ then Ed.Cells[k] = nil end
    end
    rebuildAllBlocks()
end

-- ============================================================
--       РЕГИСТРАЦИЯ ФИГУРЫ
-- ============================================================
local function registerShapeAsShapePreset(name, cellsData, N)
    -- Подсчитываем bounds и нормализуем
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    for _, cell in pairs(cellsData) do
        minX = math.min(minX, cell.x); maxX = math.max(maxX, cell.x)
        minY = math.min(minY, cell.y); maxY = math.max(maxY, cell.y)
        minZ = math.min(minZ, cell.z); maxZ = math.max(maxZ, cell.z)
    end
    if minX == math.huge then return false, "Пустая фигура" end

    local cx = (minX + maxX) / 2
    local cy = (minY + maxY) / 2
    local cz = (minZ + maxZ) / 2

    local size = math.max(maxX - minX + 1, maxY - minY + 1, maxZ - minZ + 1)

    -- Проверка уникальности имени
    local finalName = name
    local base = finalName; local n = 1
    local function exists(nm)
        for _, sp in ipairs(ORBIT.SHAPE_PRESETS) do if sp.name == nm then return true end end
        return false
    end
    while exists(finalName) do n = n + 1; finalName = base .. "_" .. n end

    local blocksCopy = {}
    for _, cell in pairs(cellsData) do
        table.insert(blocksCopy, {x=cell.x, y=cell.y, z=cell.z, color=cell.color})
    end

    table.insert(ORBIT.SHAPE_PRESETS, {
        name = finalName,
        isCustom = true,
        is3D = true,
        create = function(shapeSize, partName)
            local model, root = ORBIT.newModelShell(partName)
            local bodies = {}
            local unit = shapeSize / size
            for _, cell in ipairs(blocksCopy) do
                local px = (cell.x - cx) * unit
                local py = (cell.y - cy) * unit
                local pz = (cell.z - cz) * unit
                local p = ORBIT.newPart(model, "V", Vector3.new(unit * 0.95, unit * 0.95, unit * 0.95),
                    CFrame.new(px, py, pz), cell.color, true)
                table.insert(bodies, p)
            end
            return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = shapeSize * 1.4 }
        end,
    })

    -- Сохранение в файл
    if ORBIT.HAS_FS then
        ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
        local blocks = {}
        for _, cell in pairs(cellsData) do
            table.insert(blocks, {x=cell.x, y=cell.y, z=cell.z,
                r=cell.color.R, g=cell.color.G, b=cell.color.B})
        end
        table.insert(ORBIT.CUSTOM_SHAPES, {name = finalName, is3D = true, N = size, blocks = blocks})
        if ORBIT.saveCustomShapes then ORBIT.saveCustomShapes() end
        pcall(function()
            writefile(ORBIT.CUSTOM_FILE or "orbit_v21_custom_shapes.json",
                HttpService:JSONEncode(ORBIT.CUSTOM_SHAPES))
        end)
    end

    return true, finalName
end

-- ============================================================
--       RAY PICK: клик по клетке
-- ============================================================
local function pickCellFromScreen(sx, sy)
    if not Ed.Cam or not Ed.Vp then return nil end
    local ray = Ed.Cam:ScreenPointToRay(sx, sy)
    if not ray then return nil end

    local best, bestT = nil, math.huge
    local hasBlocks = false

    -- 1. Проверяем занятые клетки (прямое попадание = удалить)
    for _, cell in pairs(Ed.Cells) do
        hasBlocks = true
        local center = cellToWorld(cell.x, cell.y, cell.z)
        local mn = center - Vector3.new(0.46, 0.46, 0.46)
        local mx = center + Vector3.new(0.46, 0.46, 0.46)
        local t = rayAABB(ray.Origin, ray.Direction, mn, mx)
        if t and t > 0 and t < bestT then
            bestT = t
            best = {kind = "hit", cell = cell}
        end
    end

    -- 2. Если не попали в блок — проверяем плоскости активного слоя
    if not best then
        local off = (Ed.N - 1) / 2
        local zLevel = Ed.ActiveZ - off - 1
        local mn = Vector3.new(-off - 1, -off - 1, zLevel - 0.46)
        local mx = Vector3.new(-off - 1 + Ed.N, -off - 1 + Ed.N, zLevel + 0.46)
        local t = rayAABB(ray.Origin, ray.Direction, mn, mx)
        if t and t > 0 then
            local hit = ray.Origin + ray.Direction * t
            local x, y, z = worldToCell(hit)
            if x and z == Ed.ActiveZ then
                best = {kind = "floor", x = x, y = y, z = z}
            end
        end
    end

    return best
end

-- ============================================================
--       UI
-- ============================================================
local function openEditor3D()
    if Ed.Open then return end
    Ed.Open = true

    local W = IS_MOBILE and 360 or 720
    local H = IS_MOBILE and 620 or 520

    Ed.Gui = Instance.new("Frame")
    Ed.Gui.Name = "_Orbit3DEditor"
    Ed.Gui.Size = UDim2.new(0, W, 0, H)
    Ed.Gui.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    Ed.Gui.BackgroundColor3 = Color3.fromRGB(18, 14, 30)
    Ed.Gui.BorderSizePixel = 0
    Ed.Gui.ZIndex = 50
    Ed.Gui.Parent = screenGui
    Instance.new("UICorner", Ed.Gui).CornerRadius = UDim.new(0, 14)
    local gs = Instance.new("UIStroke", Ed.Gui)
    gs.Color = Color3.fromRGB(180, 130, 255); gs.Thickness = 2

    if ORBIT.ui.fitToScreen then ORBIT.ui.fitToScreen(Ed.Gui, W, H) end

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 0, 26)
    title.Position = UDim2.new(0, 14, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "🔮 3D-РЕДАКТОР ФИГУР"
    title.TextColor3 = Color3.fromRGB(230, 210, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 51
    title.Parent = Ed.Gui

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    closeBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "✖"
    closeBtn.ZIndex = 51
    closeBtn.Parent = Ed.Gui
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

    -- Layout: Viewport + панель управления
    local vpW = IS_MOBILE and (W - 20) or 400
    local vpH = IS_MOBILE and 280 or (H - 80)
    local ctrlX = IS_MOBILE and 10 or 420
    local ctrlY = IS_MOBILE and 320 or 40
    local ctrlW = IS_MOBILE and (W - 20) or (W - 430)
    local ctrlH = IS_MOBILE and (H - 380) or (H - 100)

    -- ViewportFrame
    Ed.Vp = Instance.new("ViewportFrame")
    Ed.Vp.Size = UDim2.new(0, vpW, 0, vpH)
    Ed.Vp.Position = UDim2.new(0, 10, 0, 36)
    Ed.Vp.BackgroundColor3 = Color3.fromRGB(8, 6, 16)
    Ed.Vp.BorderSizePixel = 0
    Ed.Vp.ZIndex = 51
    Ed.Vp.Ambient = Color3.fromRGB(200, 200, 220)
    Ed.Vp.LightColor = Color3.fromRGB(255, 255, 255)
    Ed.Vp.LightDirection = Vector3.new(-1, -1, -1)
    Ed.Vp.Parent = Ed.Gui
    Instance.new("UICorner", Ed.Vp).CornerRadius = UDim.new(0, 10)

    Ed.World = Instance.new("WorldModel")
    Ed.World.Parent = Ed.Vp

    Ed.Cam = Instance.new("Camera")
    Ed.Cam.FieldOfView = 50
    Ed.Cam.Parent = Ed.Vp
    Ed.Vp.CurrentCamera = Ed.Cam

    local function updateCamera()
        local az = math.rad(Ed.CamAzimuth)
        local el = math.rad(Ed.CamElevation)
        local dist = Ed.CamDistance
        local pos = Vector3.new(
            dist * math.cos(el) * math.sin(az),
            dist * math.sin(el),
            dist * math.cos(el) * math.cos(az)
        )
        Ed.Cam.CFrame = CFrame.new(pos, Vector3.new(0, 0, 0))
    end
    updateCamera()

    buildGridVisual()
    rebuildAllBlocks()

    -- ============================================================
    --         УПРАВЛЕНИЕ ПАЛЬЦЕМ
    -- ============================================================
    local dragBegan = nil
    local dragMoved = false
    local prevTouch = nil
    local pinchStartDist = nil
    local pinchStartZoom = nil

    Ed.Vp.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
           or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if input.UserInputType == Enum.UserInputType.Touch then
                prevTouch = input.Position
            end
            dragBegan = input.Position
            dragMoved = false
        end
    end)

    Ed.Vp.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local touches = game:GetService("UserInputService"):GetTouches()
            if #touches >= 2 then
                -- Пинч: зум
                local p1 = touches[1].Position
                local p2 = touches[2].Position
                local dist = (p1 - p2).Magnitude
                if not pinchStartDist then
                    pinchStartDist = dist
                    pinchStartZoom = Ed.CamDistance
                else
                    local ratio = pinchStartDist / math.max(dist, 1)
                    Ed.CamDistance = math.clamp(pinchStartZoom * ratio, 5, 30)
                    updateCamera()
                end
                return
            end

            if dragBegan and not dragMoved then
                local d = input.Position - dragBegan
                if d.Magnitude > 8 then dragMoved = true end
            end

            if dragMoved and prevTouch then
                local delta = input.Position - prevTouch
                Ed.CamAzimuth = Ed.CamAzimuth - delta.X * 0.5
                Ed.CamElevation = math.clamp(Ed.CamElevation + delta.Y * 0.5, -80, 80)
                updateCamera()
            end
            prevTouch = input.Position
        elseif input.UserInputType == Enum.UserInputType.MouseMovement and dragBegan then
            local d = input.Position - dragBegan
            if d.Magnitude > 6 then
                dragMoved = true
                Ed.CamAzimuth = Ed.CamAzimuth - input.Delta.X * 0.5
                Ed.CamElevation = math.clamp(Ed.CamElevation + input.Delta.Y * 0.5, -80, 80)
                updateCamera()
            end
        end
    end)

    Ed.Vp.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local touches = game:GetService("UserInputService"):GetTouches()
            if #touches < 2 then
                pinchStartDist = nil
                pinchStartZoom = nil
            end
            if dragBegan and not dragMoved then
                -- Это был тап → действие
                local rel = input.Position - Ed.Vp.AbsolutePosition
                local picked = pickCellFromScreen(rel.X, rel.Y)
                if picked then
                    if picked.kind == "hit" then
                        if Ed.Mode == "place" and picked.cell.z == Ed.ActiveZ then
                            applyMode(picked.cell.x, picked.cell.y, picked.cell.z)
                        else
                            applyMode(picked.cell.x, picked.cell.y, picked.cell.z)
                        end
                    elseif picked.kind == "floor" then
                        if Ed.Mode == "place" then
                            applyMode(picked.x, picked.y, picked.z)
                        end
                    end
                end
            end
            dragBegan = nil
            prevTouch = nil
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragBegan and not dragMoved then
                local rel = input.Position - Ed.Vp.AbsolutePosition
                local picked = pickCellFromScreen(rel.X, rel.Y)
                if picked then
                    if picked.kind == "hit" then
                        applyMode(picked.cell.x, picked.cell.y, picked.cell.z)
                    elseif picked.kind == "floor" and Ed.Mode == "place" then
                        applyMode(picked.x, picked.y, picked.z)
                    end
                end
            end
            dragBegan = nil
        end
    end)

    -- ============================================================
    --         ПАНЕЛЬ УПРАВЛЕНИЯ
    -- ============================================================
    local ctrl = Instance.new("ScrollingFrame")
    ctrl.Size = UDim2.new(0, ctrlW, 0, ctrlH)
    ctrl.Position = UDim2.new(0, ctrlX, 0, ctrlY)
    ctrl.BackgroundColor3 = Color3.fromRGB(22, 16, 36)
    ctrl.BorderSizePixel = 0
    ctrl.CanvasSize = UDim2.new(0, 0, 0, 900)
    ctrl.ScrollBarThickness = 3
    ctrl.ScrollBarImageColor3 = Color3.fromRGB(180, 130, 255)
    ctrl.ZIndex = 51
    ctrl.Parent = Ed.Gui
    Instance.new("UICorner", ctrl).CornerRadius = UDim.new(0, 10)

    local cy = 6
    local function section(txt, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -12, 0, 18)
        l.Position = UDim2.new(0, 6, 0, cy)
        l.BackgroundColor3 = color
        l.BackgroundTransparency = 0.6
        l.BorderSizePixel = 0
        l.Text = " " .. txt
        l.TextColor3 = Color3.fromRGB(240, 240, 255)
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 52
        l.Parent = ctrl
        Instance.new("UICorner", l).CornerRadius = UDim.new(0, 4)
        cy = cy + 22
    end
    local function button(text, color, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 26)
        b.Position = UDim2.new(0, 6, 0, cy)
        b.BackgroundColor3 = color or Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(230, 220, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = text
        b.ZIndex = 52
        b.Parent = ctrl
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.Activated:Connect(function() onClick(b) end)
        cy = cy + 30
        return b
    end
    local function row(txtLeft, txtRight, color)
        local r = Instance.new("TextButton")
        r.Size = UDim2.new(1, -12, 0, 26)
        r.Position = UDim2.new(0, 6, 0, cy)
        r.BackgroundColor3 = color or Color3.fromRGB(35, 30, 50)
        r.TextColor3 = Color3.fromRGB(230, 220, 255)
        r.Font = Enum.Font.GothamBold
        r.TextSize = 10
        r.Text = txtLeft
        r.TextXAlignment = Enum.TextXAlignment.Left
        r.ZIndex = 52
        r.Parent = ctrl
        Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)
        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0, 100, 1, 0)
        valLbl.Position = UDim2.new(1, -104, 0, 0)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = txtRight
        valLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
        valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 10
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.ZIndex = 53
        valLbl.Parent = r
        cy = cy + 30
        return r, valLbl
    end

    section("🎨 ЦВЕТ", Color3.fromRGB(100, 60, 140))
    -- Палитра: 8 × 3
    local palGrid = Instance.new("Frame")
    palGrid.Size = UDim2.new(1, -12, 0, 80)
    palGrid.Position = UDim2.new(0, 6, 0, cy)
    palGrid.BackgroundTransparency = 1
    palGrid.ZIndex = 52
    palGrid.Parent = ctrl
    local palLayout = Instance.new("UIGridLayout")
    palLayout.CellSize = UDim2.new(0, 24, 0, 24)
    palLayout.CellPadding = UDim2.new(0, 3, 0, 3)
    palLayout.Parent = palGrid

    local palButtons = {}
    local function refreshPalButtons()
        for i, b in ipairs(palButtons) do
            b.UIStroke.Transparency = (i == selectedColorIndex) and 0 or 0.85
        end
        if Ed.GridFolder then buildGridVisual() end
    end
    for i, col in ipairs(PALETTE) do
        local b = Instance.new("TextButton")
        b.BackgroundColor3 = col
        b.Text = ""
        b.BorderSizePixel = 0
        b.ZIndex = 53
        b.Parent = palGrid
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        local s = Instance.new("UIStroke", b)
        s.Color = Color3.fromRGB(255, 255, 255)
        s.Thickness = 2
        s.Transparency = 0.85
        b.UIStroke = s
        b.Activated:Connect(function()
            selectedColorIndex = i
            refreshPalButtons()
        end)
        table.insert(palButtons, b)
    end
    cy = cy + 86
    refreshPalButtons()

    section("🖌 РЕЖИМ", Color3.fromRGB(100, 80, 40))
    local modeRow = Instance.new("Frame")
    modeRow.Size = UDim2.new(1, -12, 0, 28)
    modeRow.Position = UDim2.new(0, 6, 0, cy)
    modeRow.BackgroundTransparency = 1
    modeRow.ZIndex = 52
    modeRow.Parent = ctrl
    local modeButtons = {}
    local modeLabels = { place = "➕ Поставить", remove = "➖ Удалить", paint = "🎨 Красить" }
    local modeKeys = { "place", "remove", "paint" }
    for i, key in ipairs(modeKeys) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.33, -2, 1, 0)
        b.Position = UDim2.new((i-1)*0.333, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(220, 210, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9
        b.Text = modeLabels[key]
        b.ZIndex = 53
        b.Parent = modeRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        modeButtons[key] = b
    end
    local function refreshModeButtons()
        for k, b in pairs(modeButtons) do
            if k == Ed.Mode then
                b.BackgroundColor3 = Color3.fromRGB(120, 90, 180)
                b.TextColor3 = Color3.fromRGB(255, 240, 255)
            else
                b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
                b.TextColor3 = Color3.fromRGB(200, 190, 220)
            end
        end
    end
    for k, b in pairs(modeButtons) do
        b.Activated:Connect(function()
            Ed.Mode = k
            refreshModeButtons()
        end)
    end
    refreshModeButtons()
    cy = cy + 34

    section("📐 РАЗМЕР СЕТКИ", Color3.fromRGB(40, 80, 100))
    local sizeRow = Instance.new("Frame")
    sizeRow.Size = UDim2.new(1, -12, 0, 26)
    sizeRow.Position = UDim2.new(0, 6, 0, cy)
    sizeRow.BackgroundTransparency = 1
    sizeRow.ZIndex = 52
    sizeRow.Parent = ctrl
    local sizeButtons = {}
    for i, n in ipairs({4, 5, 6, 7, 8}) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.2, -2, 1, 0)
        b.Position = UDim2.new((i-1) * 0.2, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(220, 210, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = tostring(n)
        b.ZIndex = 53
        b.Parent = sizeRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        sizeButtons[n] = b
    end
    local function refreshSizeButtons()
        for n, b in pairs(sizeButtons) do
            if n == Ed.N then
                b.BackgroundColor3 = Color3.fromRGB(80, 140, 200)
            else
                b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
            end
        end
    end
    for n, b in pairs(sizeButtons) do
        b.Activated:Connect(function()
            Ed.N = n
            Ed.ActiveZ = 1
            Ed.Cells = {}
            Ed.History = {}
            Ed.HistoryIdx = 0
            refreshSizeButtons()
            buildGridVisual(); rebuildAllBlocks()
        end)
    end
    refreshSizeButtons()
    cy = cy + 30

    section("📚 СЛОЙ Z", Color3.fromRGB(60, 60, 100))
    local zRow = Instance.new("Frame")
    zRow.Size = UDim2.new(1, -12, 0, 30)
    zRow.Position = UDim2.new(0, 6, 0, cy)
    zRow.BackgroundTransparency = 1
    zRow.ZIndex = 52
    zRow.Parent = ctrl
    local zDown = Instance.new("TextButton")
    zDown.Size = UDim2.new(0.3, -3, 1, 0); zDown.Position = UDim2.new(0, 0, 0, 0)
    zDown.BackgroundColor3 = Color3.fromRGB(60, 50, 85); zDown.TextColor3 = Color3.fromRGB(220, 210, 255)
    zDown.Font = Enum.Font.GothamBold; zDown.TextSize = 14; zDown.Text = "▼"
    zDown.ZIndex = 53; zDown.Parent = zRow
    Instance.new("UICorner", zDown).CornerRadius = UDim.new(0, 6)
    local zLbl = Instance.new("TextLabel")
    zLbl.Size = UDim2.new(0.4, -4, 1, 0); zLbl.Position = UDim2.new(0.3, 0, 0, 0)
    zLbl.BackgroundColor3 = Color3.fromRGB(35, 30, 50); zLbl.BorderSizePixel = 0
    zLbl.Text = "Слой 1 / " .. Ed.N
    zLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
    zLbl.Font = Enum.Font.GothamBold; zLbl.TextSize = 11
    zLbl.ZIndex = 53; zLbl.Parent = zRow
    Instance.new("UICorner", zLbl).CornerRadius = UDim.new(0, 6)
    local zUp = Instance.new("TextButton")
    zUp.Size = UDim2.new(0.3, -3, 1, 0); zUp.Position = UDim2.new(0.7, 0, 0, 0)
    zUp.BackgroundColor3 = Color3.fromRGB(60, 50, 85); zUp.TextColor3 = Color3.fromRGB(220, 210, 255)
    zUp.Font = Enum.Font.GothamBold; zUp.TextSize = 14; zUp.Text = "▲"
    zUp.ZIndex = 53; zUp.Parent = zRow
    Instance.new("UICorner", zUp).CornerRadius = UDim.new(0, 6)

    local function refreshZLbl()
        zLbl.Text = "Слой " .. Ed.ActiveZ .. " / " .. Ed.N
    end
    zDown.Activated:Connect(function()
        Ed.ActiveZ = math.max(1, Ed.ActiveZ - 1)
        refreshZLbl(); buildGridVisual(); updateBlocksTransparency()
    end)
    zUp.Activated:Connect(function()
        Ed.ActiveZ = math.min(Ed.N, Ed.ActiveZ + 1)
        refreshZLbl(); buildGridVisual(); updateBlocksTransparency()
    end)
    cy = cy + 36

    section("🔀 СИММЕТРИЯ", Color3.fromRGB(90, 60, 130))
    local symXBtn = button("X симметрия: ВЫКЛ", nil, function(b)
        Ed.SymX = not Ed.SymX
        b.Text = "X симметрия: " .. (Ed.SymX and "ВКЛ" or "ВЫКЛ")
        b.BackgroundColor3 = Ed.SymX and Color3.fromRGB(80,120,180) or Color3.fromRGB(45,38,65)
    end)
    local symYBtn = button("Y симметрия: ВЫКЛ", nil, function(b)
        Ed.SymY = not Ed.SymY
        b.Text = "Y симметрия: " .. (Ed.SymY and "ВКЛ" or "ВЫКЛ")
        b.BackgroundColor3 = Ed.SymY and Color3.fromRGB(80,120,180) or Color3.fromRGB(45,38,65)
    end)
    local symZBtn = button("Z симметрия: ВЫКЛ", nil, function(b)
        Ed.SymZ = not Ed.SymZ
        b.Text = "Z симметрия: " .. (Ed.SymZ and "ВКЛ" or "ВЫКЛ")
        b.BackgroundColor3 = Ed.SymZ and Color3.fromRGB(80,120,180) or Color3.fromRGB(45,38,65)
    end)

    section("⚡ БЫСТРЫЕ ФОРМЫ", Color3.fromRGB(140, 80, 40))
    button("⬜ Заполнить КУБ", Color3.fromRGB(80,60,100), function() fillCube() end)
    button("⚪ Заполнить ШАР",  Color3.fromRGB(80,60,100), function() fillSphere() end)
    button("✚ Заполнить КРЕСТ", Color3.fromRGB(80,60,100), function() fillCross() end)

    section("↩️ ИСТОРИЯ", Color3.fromRGB(60, 90, 60))
    local undoBtn = button("↩ Отменить", Color3.fromRGB(50,70,60), function() doUndo() end)
    local redoBtn = button("↪ Вернуть",  Color3.fromRGB(50,70,60), function() doRedo() end)
    button("🗑 Очистить всё",      Color3.fromRGB(80,40,40), function() clearAll() end)
    button("🗑 Очистить только слой", Color3.fromRGB(80,50,40), function() clearLayer() end)

    section("🔍 ЗУМ", Color3.fromRGB(60, 80, 110))
    local zoomInBtn = button("➕ Приблизить", Color3.fromRGB(50,60,80), function()
        Ed.CamDistance = math.max(5, Ed.CamDistance - 1.5); updateCamera()
    end)
    local zoomOutBtn = button("➖ Отдалить", Color3.fromRGB(50,60,80), function()
        Ed.CamDistance = math.min(30, Ed.CamDistance + 1.5); updateCamera()
    end)
    button("🎯 Сбросить камеру", Color3.fromRGB(50,60,80), function()
        Ed.CamAzimuth = -45; Ed.CamElevation = 30; Ed.CamDistance = 14; updateCamera()
    end)

    section("💾 СОХРАНЕНИЕ", Color3.fromRGB(100, 60, 140))
    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, -12, 0, 28)
    nameInput.Position = UDim2.new(0, 6, 0, cy)
    nameInput.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    nameInput.TextColor3 = Color3.fromRGB(230, 220, 255)
    nameInput.Font = Enum.Font.GothamBold
    nameInput.TextSize = 11
    nameInput.PlaceholderText = "✏️ Имя фигуры..."
    nameInput.PlaceholderColor3 = Color3.fromRGB(150, 140, 180)
    nameInput.Text = ""
    nameInput.ClearTextOnFocus = false
    nameInput.ZIndex = 52
    nameInput.Parent = ctrl
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 6)
    cy = cy + 34

    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, -12, 0, 20)
    infoLbl.Position = UDim2.new(0, 6, 0, cy)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = "🧱 Блоков: 0"
    infoLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    infoLbl.Font = Enum.Font.GothamBold
    infoLbl.TextSize = 11
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
    infoLbl.ZIndex = 52
    infoLbl.Parent = ctrl
    cy = cy + 24

    local function refreshInfo()
        local count = 0
        for _ in pairs(Ed.Cells) do count = count + 1 end
        infoLbl.Text = "🧱 Блоков: " .. count
    end

    -- Обновляем info после каждого действия
    local origRebuild = rebuildAllBlocks
    -- Просто добавим цикл обновления
    task.spawn(function()
        while Ed.Open and Ed.Gui and Ed.Gui.Parent do
            refreshInfo()
            task.wait(0.3)
        end
    end)

    button("💾 СОХРАНИТЬ КАК ФИГУРУ", Color3.fromRGB(60,120,80), function()
        local filled = 0
        for _ in pairs(Ed.Cells) do filled = filled + 1 end
        if filled < 2 then
            ORBIT.notify("🧱 Поставь хотя бы 2 блока", Color3.fromRGB(255,200,120), 2)
            return
        end
        local nm = nameInput.Text
        if nm == "" or not utf8.len(nm) or utf8.len(nm) > 20 then
            nm = "3D_СВОЯ_" .. math.random(100,999)
        end
        local ok, result = registerShapeAsShapePreset(nm, Ed.Cells, Ed.N)
        if ok then
            ORBIT.notify("✅ Сохранено: " .. tostring(result), Color3.fromRGB(160,255,180), 3)
            if ORBIT.rebuildAllRings then pcall(ORBIT.rebuildAllRings) end
        else
            ORBIT.notify("❌ " .. tostring(result), Color3.fromRGB(255,120,120), 2)
        end
    end)

    local exportBox = Instance.new("TextBox")
    exportBox.Size = UDim2.new(1, -12, 0, 60)
    exportBox.Position = UDim2.new(0, 6, 0, cy)
    exportBox.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
    exportBox.TextColor3 = Color3.fromRGB(180, 255, 180)
    exportBox.Font = Enum.Font.Code
    exportBox.TextSize = 9
    exportBox.Text = ""
    exportBox.PlaceholderText = "📥 JSON сюда — вставится"
    exportBox.PlaceholderColor3 = Color3.fromRGB(120, 110, 150)
    exportBox.ClearTextOnFocus = false
    exportBox.MultiLine = true
    exportBox.TextWrapped = true
    exportBox.ZIndex = 52
    exportBox.Parent = ctrl
    Instance.new("UICorner", exportBox).CornerRadius = UDim.new(0, 6)
    cy = cy + 66

    button("📤 Экспорт в текст", Color3.fromRGB(60,80,120), function()
        local arr = {}
        for _, cell in pairs(Ed.Cells) do
            table.insert(arr, {x=cell.x, y=cell.y, z=cell.z, r=cell.color.R, g=cell.color.G, b=cell.color.B})
        end
        local ok, json = pcall(function() return HttpService:JSONEncode({n=Ed.N, blocks=arr}) end)
        if ok then exportBox.Text = json end
        pcall(function()
            if setclipboard then setclipboard(json) end
        end)
    end)
    button("📥 Импорт из текста", Color3.fromRGB(60,80,120), function()
        local txt = exportBox.Text
        if not txt or txt == "" then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(txt) end)
        if not ok or not data or not data.blocks then
            ORBIT.notify("❌ Плохой JSON", Color3.fromRGB(255,120,120), 2)
            return
        end
        pushHistory()
        Ed.Cells = {}
        if data.n then Ed.N = math.clamp(data.n, 4, 8) end
        for _, b in ipairs(data.blocks) do
            local col = Color3.new(b.r or 1, b.g or 1, b.b or 1)
            setCell(b.x, b.y, b.z, col)
        end
        rebuildAllBlocks(); buildGridVisual()
        ORBIT.notify("✅ Импорт: " .. #data.blocks .. " блоков", Color3.fromRGB(160,255,180), 2)
    end)

    ctrl.CanvasSize = UDim2.new(0, 0, 0, cy + 20)

    -- Кнопка закрытия
    closeBtn.Activated:Connect(function()
        Ed.Open = false
        if Ed.Gui then Ed.Gui:Destroy(); Ed.Gui = nil end
        Ed.Vp = nil; Ed.World = nil; Ed.Cam = nil; Ed.Folder = nil; Ed.GridFolder = nil
    end)

    -- Автозум начальный
    updateCamera()
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
ORBIT.openEditor3D = openEditor3D
ORBIT.Editor3D = Ed

if ORBIT.notify then
    ORBIT.notify("🔮 3D-Редактор загружен", Color3.fromRGB(200, 180, 255), 3)
end

warn("[Orbit 3D Editor] Загружен ✅")
return true
