--[[ ОРБИТА v23.2 — 3D-РЕДАКТОР ФИГУР v2.0
     🐛 Фикс: цвет не менялся (Activated → InputBegan с Touch)
     🐛 Фикс: не работал на телефоне (вертикальный лэйаут)
     🎨 Улучшено: индикатор текущего цвета + большая палитра
     🔄 Кнопка поворота фигуры
     📱 Полная поддержка мобилки
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit 3D Editor] ORBIT не найден!"); return end
if not ORBIT.ui or not ORBIT.ui.screenGui then warn("[Orbit 3D Editor] UI не готов!"); return end

local Players      = ORBIT.Players
local RunService   = ORBIT.RunService
local HttpService  = ORBIT.HttpService
local UIS          = game:GetService("UserInputService")
local LocalPlayer  = ORBIT.LocalPlayer
local screenGui    = ORBIT.ui.screenGui
local IS_MOBILE    = (ORBIT.PLATFORM == "mobile")

-- ============================================================
--       ПАЛИТРА 24 ЦВЕТА
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
--       СОСТОЯНИЕ
-- ============================================================
local Ed = {
    Open = false, Gui = nil, Vp = nil, World = nil, Cam = nil,
    Folder = nil, GridFolder = nil,
    N = 6, ActiveZ = 1,
    Mode = "place",
    SymX = false, SymY = false, SymZ = false,
    Cells = {},             -- [key] = {x,y,z,color}
    History = {}, HistoryIdx = 0, MaxHistory = 20,
    CamAzimuth = -45, CamElevation = 30, CamDistance = 14,
    Name = "",
}
local function cellKey(x, y, z) return x .. "|" .. y .. "|" .. z end

-- ============================================================
--       УТИЛИТЫ
-- ============================================================
local function cellToWorld(x, y, z)
    local off = (Ed.N - 1) / 2
    return Vector3.new(x - off - 1, y - off - 1, z - off - 1)
end

local function worldToCell(pos)
    local off = (Ed.N - 1) / 2
    local x = math.floor(pos.X + off + 1.5)
    local y = math.floor(pos.Y + off + 1.5)
    local z = math.floor(pos.Z + off + 1.5)
    if x < 1 or x > Ed.N or y < 1 or y > Ed.N or z < 1 or z > Ed.N then return nil end
    return x, y, z
end

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
--       УНИВЕРСАЛЬНЫЙ ТАП
-- ============================================================
local function onClick(btn, fn)
    local debounce = false
    local function call()
        if debounce then return end
        debounce = true
        task.delay(0.05, function() debounce = false end)
        fn()
    end
    btn.MouseButton1Down:Connect(call)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then call() end
    end)
    btn.Activated:Connect(call)
end

-- ============================================================
--       ПОСТРОЕНИЕ СЕТКИ
-- ============================================================
local function clearGridVisual()
    if Ed.GridFolder then Ed.GridFolder:Destroy() end
    Ed.GridFolder = Instance.new("Folder")
    Ed.GridFolder.Name = "Grid"
    Ed.GridFolder.Parent = Ed.World
end

local function buildGridVisual()
    clearGridVisual()
    local N = Ed.N
    local off = (N - 1) / 2

    local function line(a, b, color, transp, thickness)
        local diff = b - a
        local len = diff.Magnitude
        if len < 0.01 then return end
        local p = Instance.new("Part")
        p.Name = "Line"
        p.Size = Vector3.new(thickness or 0.03, thickness or 0.03, len)
        p.CFrame = CFrame.lookAt((a + b) / 2, (a + b) / 2 + diff.Unit)
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
        p.CastShadow = false; p.Material = Enum.Material.Neon
        p.Color = color; p.Transparency = transp or 0.6
        p.Parent = Ed.GridFolder
    end

    local zLevel = Ed.ActiveZ - off - 1
    local cActive = PALETTE[selectedColorIndex]
    for i = 0, N do
        local x = i - off - 1
        local y = i - off - 1
        line(Vector3.new(-off - 1, -off - 1, zLevel), Vector3.new(-off - 1 + N, -off - 1, zLevel), cActive, 0.75, 0.03)
        line(Vector3.new(-off - 1, y, zLevel), Vector3.new(-off - 1 + N, y, zLevel), cActive, 0.85, 0.02)
        line(Vector3.new(x, -off - 1, zLevel), Vector3.new(x, -off - 1 + N, zLevel), cActive, 0.85, 0.02)
    end

    local plat = Instance.new("Part")
    plat.Name = "Plat"
    plat.Size = Vector3.new(N, 0.02, N)
    plat.CFrame = CFrame.new(0, -off - 1, zLevel)
    plat.Anchored = true; plat.CanCollide = false; plat.CanQuery = false; plat.CanTouch = false
    plat.CastShadow = false; plat.Material = Enum.Material.Neon
    plat.Color = cActive; plat.Transparency = 0.92
    plat.Parent = Ed.GridFolder

    local cc = Color3.fromRGB(120, 160, 220)
    local a, b = -off - 1, -off - 1 + N
    for _, pair in ipairs({
        {Vector3.new(a,a,a), Vector3.new(b,a,a)}, {Vector3.new(b,a,a), Vector3.new(b,a,b)},
        {Vector3.new(b,a,b), Vector3.new(a,a,b)}, {Vector3.new(a,a,b), Vector3.new(a,a,a)},
        {Vector3.new(a,b,a), Vector3.new(b,b,a)}, {Vector3.new(b,b,a), Vector3.new(b,b,b)},
        {Vector3.new(b,b,b), Vector3.new(a,b,b)}, {Vector3.new(a,b,b), Vector3.new(a,b,a)},
        {Vector3.new(a,a,a), Vector3.new(a,b,a)}, {Vector3.new(b,a,a), Vector3.new(b,b,a)},
        {Vector3.new(b,a,b), Vector3.new(b,b,b)}, {Vector3.new(a,a,b), Vector3.new(a,b,b)},
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
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
    p.CastShadow = false; p.Material = Enum.Material.Neon
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
        local _, _, zs = p.Name:match("Cell_(%d+)_(%d+)_(%d+)")
        if zs then
            p.Transparency = (tonumber(zs) == Ed.ActiveZ) and 0.05 or 0.55
        end
    end
end

-- ============================================================
--       ИСТОРИЯ
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
local function setCell(x, y, z, color) Ed.Cells[cellKey(x, y, z)] = {x=x, y=y, z=z, color=color} end
local function delCell(x, y, z) Ed.Cells[cellKey(x, y, z)] = nil end

local function applySymmetry(x, y, z, color, isSet)
    local points = {{x, y, z}}
    local N = Ed.N
    if Ed.SymX then
        local c = #points
        for i = 1, c do local p = points[i]; table.insert(points, {N + 1 - p[1], p[2], p[3]}) end
    end
    if Ed.SymY then
        local c = #points
        for i = 1, c do local p = points[i]; table.insert(points, {p[1], N + 1 - p[2], p[3]}) end
    end
    if Ed.SymZ then
        local c = #points
        for i = 1, c do local p = points[i]; table.insert(points, {p[1], p[2], N + 1 - p[3]}) end
    end
    for _, p in ipairs(points) do
        if isSet then setCell(p[1], p[2], p[3], color) else delCell(p[1], p[2], p[3]) end
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
    else
        applySymmetry(x, y, z, PALETTE[selectedColorIndex], true)
        rebuildAllBlocks()
    end
end

local function clearAll()
    pushHistory()
    Ed.Cells = {}
    rebuildAllBlocks()
end
local function clearLayer()
    pushHistory()
    for k, cell in pairs(Ed.Cells) do
        if cell.z == Ed.ActiveZ then Ed.Cells[k] = nil end
    end
    rebuildAllBlocks()
end
local function fillCube()
    pushHistory()
    for x = 1, Ed.N do for y = 1, Ed.N do for z = 1, Ed.N do
        setCell(x, y, z, PALETTE[selectedColorIndex])
    end end end
    rebuildAllBlocks()
end
local function fillSphere()
    pushHistory()
    local c = (Ed.N + 1) / 2
    local r = (Ed.N - 0.5) / 2
    for x = 1, Ed.N do for y = 1, Ed.N do for z = 1, Ed.N do
        local dx, dy, dz = x - c, y - c, z - c
        if dx*dx + dy*dy + dz*dz <= r*r then setCell(x, y, z, PALETTE[selectedColorIndex]) end
    end end end
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

-- Поворот всей фигуры вокруг центра
local function rotateAll(axis, dir)
    pushHistory()
    local N = Ed.N
    local c = (N + 1) / 2
    local newCells = {}
    for k, cell in pairs(Ed.Cells) do
        local x, y, z = cell.x - c, cell.y - c, cell.z - c
        local nx, ny, nz = x, y, z
        if axis == "X" then
            nx, ny, nz = x, -z * dir, y * dir
        elseif axis == "Y" then
            nx, ny, nz = -z * dir, y, x * dir
        elseif axis == "Z" then
            nx, ny, nz = -y * dir, x * dir, z
        end
        -- Если вращаем — но это может выйти за границы, обрезаем
        local fx = math.floor(nx + c + 0.5)
        local fy = math.floor(ny + c + 0.5)
        local fz = math.floor(nz + c + 0.5)
        if fx >= 1 and fx <= N and fy >= 1 and fy <= N and fz >= 1 and fz <= N then
            newCells[cellKey(fx, fy, fz)] = {x=fx, y=fy, z=fz, color=cell.color}
        end
    end
    Ed.Cells = newCells
    rebuildAllBlocks()
end

-- ============================================================
--       RAY PICK
-- ============================================================
local function pickCellFromScreen(sx, sy)
    if not Ed.Cam or not Ed.Vp then return nil end
    local ray = Ed.Cam:ScreenPointToRay(sx, sy)
    if not ray then return nil end

    local best, bestT = nil, math.huge

    for _, cell in pairs(Ed.Cells) do
        local center = cellToWorld(cell.x, cell.y, cell.z)
        local mn = center - Vector3.new(0.46, 0.46, 0.46)
        local mx = center + Vector3.new(0.46, 0.46, 0.46)
        local t = rayAABB(ray.Origin, ray.Direction, mn, mx)
        if t and t > 0 and t < bestT then
            bestT = t
            best = {kind = "hit", cell = cell}
        end
    end

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
--       РЕГИСТРАЦИЯ ФИГУРЫ
-- ============================================================
local function registerShapeAsShapePreset(name, cellsData, N)
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

    local finalName = name
    local base, n = finalName, 1
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
                local p = ORBIT.newPart(model, "V",
                    Vector3.new(unit * 0.95, unit * 0.95, unit * 0.95),
                    CFrame.new(px, py, pz), cell.color, true)
                table.insert(bodies, p)
            end
            return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = shapeSize * 1.4 }
        end,
    })

    -- Сохранение
    if ORBIT.HAS_FS then
        ORBIT.CUSTOM_SHAPES = ORBIT.CUSTOM_SHAPES or {}
        local blocks = {}
        for _, cell in pairs(cellsData) do
            table.insert(blocks, {x=cell.x, y=cell.y, z=cell.z,
                r=cell.color.R, g=cell.color.G, b=cell.color.B})
        end
        table.insert(ORBIT.CUSTOM_SHAPES, {name = finalName, is3D = true, N = size, blocks = blocks})
        if ORBIT.saveCustomShapes then pcall(ORBIT.saveCustomShapes) end
        pcall(function()
            writefile(ORBIT.CUSTOM_FILE or "orbit_v21_custom_shapes.json",
                HttpService:JSONEncode(ORBIT.CUSTOM_SHAPES))
        end)
    end
    return true, finalName
end

-- ============================================================
--       UI 3D-РЕДАКТОРА
-- ============================================================
local function openEditor3D()
    if Ed.Open then return end
    Ed.Open = true

    -- 🆕 Адаптивные размеры
    local W, H
    if IS_MOBILE then
        W = 340
        H = 600
    else
        W = 680
        H = 560
    end

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
    title.Text = "🔮 3D-РЕДАКТОР"
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
    onClick(closeBtn, function()
        Ed.Open = false
        if Ed.Gui then Ed.Gui:Destroy(); Ed.Gui = nil end
        Ed.Vp = nil; Ed.World = nil; Ed.Cam = nil
        Ed.Folder = nil; Ed.GridFolder = nil
    end)

    -- ============================================================
    --       ВЁРСТКА (вертикальная)
    -- ============================================================
    local vpW, vpH
    local ctrlY
    if IS_MOBILE then
        vpW = W - 20          -- 320
        vpH = 240
        ctrlY = 36 + vpH + 8  -- начинается под вьюпортом
    else
        vpW = W - 20
        vpH = 260
        ctrlY = 36 + vpH + 8
    end

    -- Viewport
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
    --       УПРАВЛЕНИЕ КАМЕРОЙ
    -- ============================================================
    local dragBegan, dragMoved, prevTouch = nil, false, nil
    local pinchStartDist, pinchStartZoom = nil, nil

    Ed.Vp.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if input.UserInputType == Enum.UserInputType.Touch then prevTouch = input.Position end
            dragBegan = input.Position
            dragMoved = false
        end
    end)

    Ed.Vp.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local touches = UIS:GetTouches()
            if #touches >= 2 then
                local p1 = touches[1].Position
                local p2 = touches[2].Position
                local d = (p1 - p2).Magnitude
                if not pinchStartDist then
                    pinchStartDist = d
                    pinchStartZoom = Ed.CamDistance
                else
                    local ratio = pinchStartDist / math.max(d, 1)
                    Ed.CamDistance = math.clamp(pinchStartZoom * ratio, 5, 30)
                    updateCamera()
                end
                return
            end
            if dragBegan and not dragMoved then
                if (input.Position - dragBegan).Magnitude > 8 then dragMoved = true end
            end
            if dragMoved and prevTouch then
                local delta = input.Position - prevTouch
                Ed.CamAzimuth = Ed.CamAzimuth - delta.X * 0.5
                Ed.CamElevation = math.clamp(Ed.CamElevation + delta.Y * 0.5, -80, 80)
                updateCamera()
            end
            prevTouch = input.Position
        elseif input.UserInputType == Enum.UserInputType.MouseMovement and dragBegan then
            if (input.Position - dragBegan).Magnitude > 6 then
                dragMoved = true
                Ed.CamAzimuth = Ed.CamAzimuth - input.Delta.X * 0.5
                Ed.CamElevation = math.clamp(Ed.CamElevation + input.Delta.Y * 0.5, -80, 80)
                updateCamera()
            end
        end
    end)

    Ed.Vp.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            local touches = UIS:GetTouches()
            if #touches < 2 then pinchStartDist, pinchStartZoom = nil, nil end
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
            dragBegan, prevTouch = nil, nil
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
    --       ПАНЕЛЬ КОНТРОЛОВ (вертикальный скролл)
    -- ============================================================
    local ctrl = Instance.new("ScrollingFrame")
    ctrl.Size = UDim2.new(1, -20, 0, H - ctrlY - 12)
    ctrl.Position = UDim2.new(0, 10, 0, ctrlY)
    ctrl.BackgroundColor3 = Color3.fromRGB(22, 16, 36)
    ctrl.BorderSizePixel = 0
    ctrl.CanvasSize = UDim2.new(0, 0, 0, 700)
    ctrl.ScrollBarThickness = 4
    ctrl.ScrollBarImageColor3 = Color3.fromRGB(180, 130, 255)
    ctrl.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ctrl.ZIndex = 51
    ctrl.Parent = Ed.Gui
    Instance.new("UICorner", ctrl).CornerRadius = UDim.new(0, 10)

    local cy = 8
    local CTRL_W = W - 40  -- эффективная ширина контролов

    -- ============ ТЕКУЩИЙ ЦВЕТ + СЧЁТЧИК ============
    local infoRow = Instance.new("Frame")
    infoRow.Size = UDim2.new(1, -16, 0, 34)
    infoRow.Position = UDim2.new(0, 8, 0, cy)
    infoRow.BackgroundColor3 = Color3.fromRGB(30, 24, 45)
    infoRow.BorderSizePixel = 0
    infoRow.ZIndex = 52
    infoRow.Parent = ctrl
    Instance.new("UICorner", infoRow).CornerRadius = UDim.new(0, 8)
    cy = cy + 38

    local colorSquare = Instance.new("Frame")
    colorSquare.Size = UDim2.new(0, 26, 0, 26)
    colorSquare.Position = UDim2.new(0, 4, 0.5, -13)
    colorSquare.BackgroundColor3 = PALETTE[1]
    colorSquare.BorderSizePixel = 0
    colorSquare.ZIndex = 53
    colorSquare.Parent = infoRow
    Instance.new("UICorner", colorSquare).CornerRadius = UDim.new(0, 6)
    local cs = Instance.new("UIStroke", colorSquare)
    cs.Color = Color3.fromRGB(255, 255, 255); cs.Thickness = 1.5; cs.Transparency = 0.3

    local colorLbl = Instance.new("TextLabel")
    colorLbl.Size = UDim2.new(0.5, -40, 1, 0)
    colorLbl.Position = UDim2.new(0, 36, 0, 0)
    colorLbl.BackgroundTransparency = 1
    colorLbl.Text = "🎨 Цвет #1"
    colorLbl.TextColor3 = Color3.fromRGB(230, 220, 255)
    colorLbl.Font = Enum.Font.GothamBold
    colorLbl.TextSize = 11
    colorLbl.TextXAlignment = Enum.TextXAlignment.Left
    colorLbl.ZIndex = 53
    colorLbl.Parent = infoRow

    local countLbl = Instance.new("TextLabel")
    countLbl.Size = UDim2.new(0.5, -8, 1, 0)
    countLbl.Position = UDim2.new(0.5, 4, 0, 0)
    countLbl.BackgroundTransparency = 1
    countLbl.Text = "🧱 0"
    countLbl.TextColor3 = Color3.fromRGB(180, 220, 255)
    countLbl.Font = Enum.Font.GothamBold
    countLbl.TextSize = 11
    countLbl.TextXAlignment = Enum.TextXAlignment.Right
    countLbl.ZIndex = 53
    countLbl.Parent = infoRow

    local function refreshInfo()
        colorSquare.BackgroundColor3 = PALETTE[selectedColorIndex]
        colorLbl.Text = "🎨 Цвет #" .. selectedColorIndex
        local count = 0
        for _ in pairs(Ed.Cells) do count = count + 1 end
        countLbl.Text = "🧱 " .. count
    end
    refreshInfo()

    -- ============ ПАЛИТРА (горизонтальный скролл, крупные ячейки) ============
    local palLabel = Instance.new("TextLabel")
    palLabel.Size = UDim2.new(1, -16, 0, 16)
    palLabel.Position = UDim2.new(0, 8, 0, cy)
    palLabel.BackgroundTransparency = 1
    palLabel.Text = "🎨 ВЫБЕРИ ЦВЕТ (тапни)"
    palLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    palLabel.Font = Enum.Font.GothamBold
    palLabel.TextSize = 10
    palLabel.TextXAlignment = Enum.TextXAlignment.Left
    palLabel.ZIndex = 52
    palLabel.Parent = ctrl
    cy = cy + 18

    local palScroll = Instance.new("ScrollingFrame")
    palScroll.Size = UDim2.new(1, -16, 0, 82)
    palScroll.Position = UDim2.new(0, 8, 0, cy)
    palScroll.BackgroundColor3 = Color3.fromRGB(15, 12, 24)
    palScroll.BorderSizePixel = 0
    palScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    palScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
    palScroll.ScrollBarThickness = 4
    palScroll.ScrollBarImageColor3 = Color3.fromRGB(180, 130, 255)
    palScroll.ScrollingDirection = Enum.ScrollingDirection.X
    palScroll.ZIndex = 52
    palScroll.Parent = ctrl
    Instance.new("UICorner", palScroll).CornerRadius = UDim.new(0, 8)

    local palLayout = Instance.new("UIGridLayout")
    palLayout.CellSize = UDim2.new(0, 36, 0, 36)
    palLayout.CellPadding = UDim2.new(0, 4, 0, 4)
    palLayout.FillDirection = Enum.FillDirection.Horizontal
    palLayout.SortOrder = Enum.SortOrder.LayoutOrder
    palLayout.Parent = palScroll

    -- Отступы
    local palPad = Instance.new("UIPadding")
    palPad.PaddingTop = UDim.new(0, 4)
    palPad.PaddingBottom = UDim.new(0, 4)
    palPad.PaddingLeft = UDim.new(0, 4)
    palPad.PaddingRight = UDim.new(0, 4)
    palPad.Parent = palScroll

    local palButtons = {}
    local function refreshPalVisual()
        for i, b in ipairs(palButtons) do
            if b then
                b.UIStroke.Transparency = (i == selectedColorIndex) and 0 or 0.8
                b.UIStroke.Thickness = (i == selectedColorIndex) and 3 or 1.5
            end
        end
        if Ed.GridFolder then buildGridVisual() end
        refreshInfo()
    end

    for i, col in ipairs(PALETTE) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 36, 0, 36)
        b.BackgroundColor3 = col
        b.BorderSizePixel = 0
        b.Text = ""
        b.LayoutOrder = i
        b.ZIndex = 53
        b.Parent = palScroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        local s = Instance.new("UIStroke", b)
        s.Color = Color3.fromRGB(255, 255, 255)
        s.Thickness = 1.5
        s.Transparency = 0.8
        b.UIStroke = s
        onClick(b, function()
            selectedColorIndex = i
            refreshPalVisual()
            print("[3D Editor] Цвет #" .. i .. " выбран")
        end)
        table.insert(palButtons, b)
    end
    refreshPalVisual()
    cy = cy + 88

    -- ============ РЕЖИМЫ ============
    local modeLabel = Instance.new("TextLabel")
    modeLabel.Size = UDim2.new(1, -16, 0, 16)
    modeLabel.Position = UDim2.new(0, 8, 0, cy)
    modeLabel.BackgroundTransparency = 1
    modeLabel.Text = "🖌 РЕЖИМ"
    modeLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    modeLabel.Font = Enum.Font.GothamBold
    modeLabel.TextSize = 10
    modeLabel.TextXAlignment = Enum.TextXAlignment.Left
    modeLabel.ZIndex = 52
    modeLabel.Parent = ctrl
    cy = cy + 18

    local modeRow = Instance.new("Frame")
    modeRow.Size = UDim2.new(1, -16, 0, 32)
    modeRow.Position = UDim2.new(0, 8, 0, cy)
    modeRow.BackgroundTransparency = 1
    modeRow.ZIndex = 52
    modeRow.Parent = ctrl

    local modeButtons = {}
    local modeConfig = {
        {key = "place",  label = "🖌 Ставить",  color = Color3.fromRGB(60, 130, 80)},
        {key = "remove", label = "🗑 Удалить",  color = Color3.fromRGB(140, 60, 60)},
        {key = "paint",  label = "🎨 Красить",  color = Color3.fromRGB(140, 90, 40)},
    }
    for i, cfg in ipairs(modeConfig) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.33, -2, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.333, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(220, 210, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = cfg.label
        b.ZIndex = 53
        b.Parent = modeRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        modeButtons[cfg.key] = {btn = b, color = cfg.color}

        onClick(b, function()
            Ed.Mode = cfg.key
            for k, data in pairs(modeButtons) do
                if k == Ed.Mode then
                    data.btn.BackgroundColor3 = data.color
                    data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                else
                    data.btn.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
                    data.btn.TextColor3 = Color3.fromRGB(200, 190, 220)
                end
            end
            print("[3D Editor] Режим: " .. cfg.key)
        end)
    end
    -- Инициализация
    for k, data in pairs(modeButtons) do
        if k == Ed.Mode then
            data.btn.BackgroundColor3 = data.color
            data.btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
    cy = cy + 36

    -- ============ РАЗМЕР СЕТКИ ============
    local sizeLabel = Instance.new("TextLabel")
    sizeLabel.Size = UDim2.new(1, -16, 0, 16)
    sizeLabel.Position = UDim2.new(0, 8, 0, cy)
    sizeLabel.BackgroundTransparency = 1
    sizeLabel.Text = "📐 РАЗМЕР СЕТКИ"
    sizeLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    sizeLabel.Font = Enum.Font.GothamBold
    sizeLabel.TextSize = 10
    sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
    sizeLabel.ZIndex = 52
    sizeLabel.Parent = ctrl
    cy = cy + 18

    local sizeRow = Instance.new("Frame")
    sizeRow.Size = UDim2.new(1, -16, 0, 30)
    sizeRow.Position = UDim2.new(0, 8, 0, cy)
    sizeRow.BackgroundTransparency = 1
    sizeRow.ZIndex = 52
    sizeRow.Parent = ctrl

    local sizeButtons = {}
    for i, n in ipairs({4, 5, 6, 7, 8}) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.2, -2, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.2, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(220, 210, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = tostring(n)
        b.ZIndex = 53
        b.Parent = sizeRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        sizeButtons[n] = b
        onClick(b, function()
            Ed.N = n
            Ed.ActiveZ = 1
            Ed.Cells = {}
            Ed.History = {}
            Ed.HistoryIdx = 0
            for nn, bb in pairs(sizeButtons) do
                bb.BackgroundColor3 = (nn == Ed.N) and Color3.fromRGB(80, 140, 200) or Color3.fromRGB(45, 38, 65)
            end
            buildGridVisual(); rebuildAllBlocks(); refreshInfo()
        end)
    end
    for n, b in pairs(sizeButtons) do
        if n == Ed.N then b.BackgroundColor3 = Color3.fromRGB(80, 140, 200) end
    end
    cy = cy + 34

    -- ============ СЛОЙ Z ============
    local zLabel = Instance.new("TextLabel")
    zLabel.Size = UDim2.new(1, -16, 0, 16)
    zLabel.Position = UDim2.new(0, 8, 0, cy)
    zLabel.BackgroundTransparency = 1
    zLabel.Text = "📚 АКТИВНЫЙ СЛОЙ (Z)"
    zLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    zLabel.Font = Enum.Font.GothamBold
    zLabel.TextSize = 10
    zLabel.TextXAlignment = Enum.TextXAlignment.Left
    zLabel.ZIndex = 52
    zLabel.Parent = ctrl
    cy = cy + 18

    local zRow = Instance.new("Frame")
    zRow.Size = UDim2.new(1, -16, 0, 34)
    zRow.Position = UDim2.new(0, 8, 0, cy)
    zRow.BackgroundTransparency = 1
    zRow.ZIndex = 52
    zRow.Parent = ctrl

    local zDown = Instance.new("TextButton")
    zDown.Size = UDim2.new(0.3, -3, 1, 0)
    zDown.Position = UDim2.new(0, 0, 0, 0)
    zDown.BackgroundColor3 = Color3.fromRGB(60, 50, 85)
    zDown.TextColor3 = Color3.fromRGB(220, 210, 255)
    zDown.Font = Enum.Font.GothamBold
    zDown.TextSize = 16
    zDown.Text = "▼"
    zDown.ZIndex = 53
    zDown.Parent = zRow
    Instance.new("UICorner", zDown).CornerRadius = UDim.new(0, 6)

    local zLbl = Instance.new("TextLabel")
    zLbl.Size = UDim2.new(0.4, -4, 1, 0)
    zLbl.Position = UDim2.new(0.3, 0, 0, 0)
    zLbl.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    zLbl.BorderSizePixel = 0
    zLbl.Text = "Слой 1 / " .. Ed.N
    zLbl.TextColor3 = Color3.fromRGB(255, 220, 150)
    zLbl.Font = Enum.Font.GothamBold
    zLbl.TextSize = 11
    zLbl.ZIndex = 53
    zLbl.Parent = zRow
    Instance.new("UICorner", zLbl).CornerRadius = UDim.new(0, 6)

    local zUp = Instance.new("TextButton")
    zUp.Size = UDim2.new(0.3, -3, 1, 0)
    zUp.Position = UDim2.new(0.7, 0, 0, 0)
    zUp.BackgroundColor3 = Color3.fromRGB(60, 50, 85)
    zUp.TextColor3 = Color3.fromRGB(220, 210, 255)
    zUp.Font = Enum.Font.GothamBold
    zUp.TextSize = 16
    zUp.Text = "▲"
    zUp.ZIndex = 53
    zUp.Parent = zRow
    Instance.new("UICorner", zUp).CornerRadius = UDim.new(0, 6)

    onClick(zDown, function()
        Ed.ActiveZ = math.max(1, Ed.ActiveZ - 1)
        zLbl.Text = "Слой " .. Ed.ActiveZ .. " / " .. Ed.N
        buildGridVisual(); updateBlocksTransparency()
    end)
    onClick(zUp, function()
        Ed.ActiveZ = math.min(Ed.N, Ed.ActiveZ + 1)
        zLbl.Text = "Слой " .. Ed.ActiveZ .. " / " .. Ed.N
        buildGridVisual(); updateBlocksTransparency()
    end)
    cy = cy + 38

    -- ============ СИММЕТРИЯ ============
    local symLabel = Instance.new("TextLabel")
    symLabel.Size = UDim2.new(1, -16, 0, 16)
    symLabel.Position = UDim2.new(0, 8, 0, cy)
    symLabel.BackgroundTransparency = 1
    symLabel.Text = "🔀 СИММЕТРИЯ (зеркалит блоки)"
    symLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    symLabel.Font = Enum.Font.GothamBold
    symLabel.TextSize = 10
    symLabel.TextXAlignment = Enum.TextXAlignment.Left
    symLabel.ZIndex = 52
    symLabel.Parent = ctrl
    cy = cy + 18

    local symRow = Instance.new("Frame")
    symRow.Size = UDim2.new(1, -16, 0, 30)
    symRow.Position = UDim2.new(0, 8, 0, cy)
    symRow.BackgroundTransparency = 1
    symRow.ZIndex = 52
    symRow.Parent = ctrl

    local symConfig = {
        {key = "SymX", label = "X"},
        {key = "SymY", label = "Y"},
        {key = "SymZ", label = "Z"},
    }
    local symButtons = {}
    for i, cfg in ipairs(symConfig) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.33, -2, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.333, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
        b.TextColor3 = Color3.fromRGB(220, 210, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Text = cfg.label .. " ➖"
        b.ZIndex = 53
        b.Parent = symRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        symButtons[cfg.key] = b
        onClick(b, function()
            Ed[cfg.key] = not Ed[cfg.key]
            b.Text = cfg.label .. " " .. (Ed[cfg.key] and "✅" or "➖")
            b.BackgroundColor3 = Ed[cfg.key] and Color3.fromRGB(80, 120, 180) or Color3.fromRGB(45, 38, 65)
        end)
    end
    cy = cy + 34

    -- ============ БЫСТРЫЕ ФОРМЫ ============
    local shapeLabel = Instance.new("TextLabel")
    shapeLabel.Size = UDim2.new(1, -16, 0, 16)
    shapeLabel.Position = UDim2.new(0, 8, 0, cy)
    shapeLabel.BackgroundTransparency = 1
    shapeLabel.Text = "⚡ ЗАПОЛНИТЬ ФОРМОЙ"
    shapeLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    shapeLabel.Font = Enum.Font.GothamBold
    shapeLabel.TextSize = 10
    shapeLabel.TextXAlignment = Enum.TextXAlignment.Left
    shapeLabel.ZIndex = 52
    shapeLabel.Parent = ctrl
    cy = cy + 18

    local shapeRow = Instance.new("Frame")
    shapeRow.Size = UDim2.new(1, -16, 0, 30)
    shapeRow.Position = UDim2.new(0, 8, 0, cy)
    shapeRow.BackgroundTransparency = 1
    shapeRow.ZIndex = 52
    shapeRow.Parent = ctrl

    local shapeConfig = {
        {label = "⬜ Куб",   fn = fillCube},
        {label = "⚪ Шар",    fn = fillSphere},
        {label = "✚ Крест",  fn = fillCross},
    }
    for i, cfg in ipairs(shapeConfig) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.33, -2, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.333, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(80, 60, 100)
        b.TextColor3 = Color3.fromRGB(240, 220, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = cfg.label
        b.ZIndex = 53
        b.Parent = shapeRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        onClick(b, function() cfg.fn(); refreshInfo() end)
    end
    cy = cy + 34

    -- ============ ПОВОРОТ ============
    local rotLabel = Instance.new("TextLabel")
    rotLabel.Size = UDim2.new(1, -16, 0, 16)
    rotLabel.Position = UDim2.new(0, 8, 0, cy)
    rotLabel.BackgroundTransparency = 1
    rotLabel.Text = "🔄 ПОВЕРНУТЬ ФИГУРУ"
    rotLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    rotLabel.Font = Enum.Font.GothamBold
    rotLabel.TextSize = 10
    rotLabel.TextXAlignment = Enum.TextXAlignment.Left
    rotLabel.ZIndex = 52
    rotLabel.Parent = ctrl
    cy = cy + 18

    local rotRow = Instance.new("Frame")
    rotRow.Size = UDim2.new(1, -16, 0, 30)
    rotRow.Position = UDim2.new(0, 8, 0, cy)
    rotRow.BackgroundTransparency = 1
    rotRow.ZIndex = 52
    rotRow.Parent = ctrl

    local rotConfig = {
        {label = "⟲ X", axis = "X", dir = 1},
        {label = "⟳ X", axis = "X", dir = -1},
        {label = "⟲ Y", axis = "Y", dir = 1},
        {label = "⟳ Y", axis = "Y", dir = -1},
    }
    for i, cfg in ipairs(rotConfig) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.25, -2, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(60, 80, 110)
        b.TextColor3 = Color3.fromRGB(220, 230, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = cfg.label
        b.ZIndex = 53
        b.Parent = rotRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        onClick(b, function() rotateAll(cfg.axis, cfg.dir); refreshInfo() end)
    end
    cy = cy + 34

    -- ============ ИСТОРИЯ ============
    local histRow = Instance.new("Frame")
    histRow.Size = UDim2.new(1, -16, 0, 30)
    histRow.Position = UDim2.new(0, 8, 0, cy)
    histRow.BackgroundTransparency = 1
    histRow.ZIndex = 52
    histRow.Parent = ctrl

    local histConfig = {
        {label = "↩ Отмена", fn = function() doUndo(); refreshInfo() end},
        {label = "↪ Вернуть", fn = function() doRedo(); refreshInfo() end},
        {label = "🗑 Слой", fn = function() clearLayer(); refreshInfo() end},
        {label = "🗑 Всё", fn = function() clearAll(); refreshInfo() end},
    }
    for i, cfg in ipairs(histConfig) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.25, -2, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.25, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        b.TextColor3 = Color3.fromRGB(220, 220, 240)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9
        b.Text = cfg.label
        b.ZIndex = 53
        b.Parent = histRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        onClick(b, cfg.fn)
    end
    cy = cy + 34

    -- ============ КАМЕРА ============
    local camRow = Instance.new("Frame")
    camRow.Size = UDim2.new(1, -16, 0, 30)
    camRow.Position = UDim2.new(0, 8, 0, cy)
    camRow.BackgroundTransparency = 1
    camRow.ZIndex = 52
    camRow.Parent = ctrl

    local camConfig = {
        {label = "➕ Зум", fn = function() Ed.CamDistance = math.max(5, Ed.CamDistance - 1.5); updateCamera() end},
        {label = "➖ Зум", fn = function() Ed.CamDistance = math.min(30, Ed.CamDistance + 1.5); updateCamera() end},
        {label = "🎯 Резет", fn = function() Ed.CamAzimuth = -45; Ed.CamElevation = 30; Ed.CamDistance = 14; updateCamera() end},
    }
    for i, cfg in ipairs(camConfig) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.33, -2, 1, 0)
        b.Position = UDim2.new((i - 1) * 0.333, 0, 0, 0)
        b.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
        b.TextColor3 = Color3.fromRGB(220, 230, 255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Text = cfg.label
        b.ZIndex = 53
        b.Parent = camRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        onClick(b, cfg.fn)
    end
    cy = cy + 34

    -- ============ СОХРАНЕНИЕ ============
    local saveLabel = Instance.new("TextLabel")
    saveLabel.Size = UDim2.new(1, -16, 0, 16)
    saveLabel.Position = UDim2.new(0, 8, 0, cy)
    saveLabel.BackgroundTransparency = 1
    saveLabel.Text = "💾 СОХРАНИТЬ КАК ФИГУРУ"
    saveLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
    saveLabel.Font = Enum.Font.GothamBold
    saveLabel.TextSize = 10
    saveLabel.TextXAlignment = Enum.TextXAlignment.Left
    saveLabel.ZIndex = 52
    saveLabel.Parent = ctrl
    cy = cy + 18

    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, -16, 0, 30)
    nameInput.Position = UDim2.new(0, 8, 0, cy)
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
    cy = cy + 36

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(1, -16, 0, 34)
    saveBtn.Position = UDim2.new(0, 8, 0, cy)
    saveBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
    saveBtn.TextColor3 = Color3.fromRGB(200, 255, 210)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 12
    saveBtn.Text = "💾 СОХРАНИТЬ КАК ФИГУРУ"
    saveBtn.ZIndex = 52
    saveBtn.Parent = ctrl
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 8)

    onClick(saveBtn, function()
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
    cy = cy + 40

    -- ============ ПОДСКАЗКА ============
    local hintLbl = Instance.new("TextLabel")
    hintLbl.Size = UDim2.new(1, -16, 0, 40)
    hintLbl.Position = UDim2.new(0, 8, 0, cy)
    hintLbl.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    hintLbl.BackgroundTransparency = 0.3
    hintLbl.BorderSizePixel = 0
    hintLbl.Text = "👆 Свайп по 3D — вращать\n🔍 Пинч 2 пальцами — зум\n👆 Тап по клетке — действие"
    hintLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    hintLbl.Font = Enum.Font.Gotham
    hintLbl.TextSize = 9
    hintLbl.TextWrapped = true
    hintLbl.ZIndex = 52
    hintLbl.Parent = ctrl
    Instance.new("UICorner", hintLbl).CornerRadius = UDim.new(0, 6)
    cy = cy + 46

    ctrl.CanvasSize = UDim2.new(0, 0, 0, cy + 10)

    -- Автообновление счётчика
    task.spawn(function()
        while Ed.Open and Ed.Gui and Ed.Gui.Parent do
            refreshInfo()
            task.wait(0.4)
        end
    end)
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
ORBIT.openEditor3D = openEditor3D
ORBIT.Editor3D = Ed

if ORBIT.notify then
    ORBIT.notify("🔮 3D-Редактор v2.0 загружен", Color3.fromRGB(200, 180, 255), 3)
end

warn("[Orbit 3D Editor v2.0] Загружен ✅")
return true
