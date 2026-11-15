-- ============================================================
--  Rick & Morty Toolkit v6.0 — ЧАСТЬ 4/5: навигация, данные, роботы
--  Системы: 1 координаты, 11 радар, 8 сканер, 18 анализатор NPC, 2 эхо-клон, 4 машина времени,
--  12 роботы, 19 дрон, 7 автопилот корабля, 21 запись маршрутов, 24 клон-машина, 13 сохранение
--  + список измерений. Игроков НЕ сканируем, не отслеживаем и не выбираем целью.
-- ============================================================
local G = (type(getgenv) == "function" and getgenv()) or _G
local RM = G.RickMorty
local TK = RM and RM._TK
if not TK or not RM._part3 then error("[RickMorty] часть 4 запущена без частей 1–3") end

local SF = TK.sysFolder
local function folder(name)
  local f = Instance.new("Folder")
  f.Name = "RM_" .. name
  f.Parent = SF
  return f
end
local function myRoot()
  local _, _, hr = TK.getChar()
  return hr
end

-- ---------- поиск локальных объектов (игроков исключаем целиком) ----------
local function topModel(inst)
  local m = inst:FindFirstAncestorOfClass("Model")
  while m and m.Parent and m.Parent:IsA("Model") do m = m.Parent end
  return m
end
local function isPlayerThing(inst)
  local m = topModel(inst)
  if inst:IsA("Model") then m = inst end
  return m ~= nil and TK.Players:GetPlayerFromCharacter(m) ~= nil
end
local function isToolkit(inst)
  local p = inst
  while p and p ~= TK.Workspace do
    if type(p.Name) == "string" and p.Name:sub(1, 3) == "RM_" then return true end
    p = p.Parent
  end
  return false
end
TK.KINDCOL = {
  toolkit = TK.RGB(80, 255, 140), npc = TK.RGB(255, 170, 60), model = TK.RGB(110, 190, 255), part = TK.RGB(190, 190, 200),
}
TK.KINDNAME = { toolkit = "объект Toolkit", npc = "NPC", model = "модель", part = "деталь" }
function TK.scanWorld(radius, maxN, onlyNpc)
  local hr = myRoot()
  if not hr then return {} end
  local op = OverlapParams.new()
  op.FilterType = Enum.RaycastFilterType.Exclude
  op.FilterDescendantsInstances = { TK.LP.Character }
  op.MaxParts = 300
  local ok, parts = pcall(function() return TK.Workspace:GetPartBoundsInRadius(hr.Position, radius, op) end)
  if not ok then return {} end
  local seen, out = {}, {}
  for _, p in ipairs(parts) do
    if not isPlayerThing(p) then
      local m = topModel(p)
      local inst = m or p
      if not seen[inst] then
        seen[inst] = true
        local kind = "part"
        local hum = m and m:FindFirstChildOfClass("Humanoid")
        if isToolkit(inst) then kind = "toolkit" elseif hum then kind = "npc" elseif m then kind = "model" end
        if not onlyNpc or kind == "npc" then
          local pos = m and m:GetPivot().Position or p.Position
          out[#out + 1] = { inst = inst, name = inst.Name, kind = kind, dist = (pos - hr.Position).Magnitude, pos = pos, hum = hum }
        end
      end
    end
  end
  table.sort(out, function(a, b) return a.dist < b.dist end)
  while #out > maxN do table.remove(out) end
  return out
end
local function clearBoxes(list)
  for i = #list, 1, -1 do pcall(function() list[i]:Destroy() end) list[i] = nil end
end

-- ============================================================
--  СИСТЕМА 1: МЕЖПРОСТРАНСТВЕННЫЕ КООРДИНАТЫ
-- ============================================================
local markF = folder("Markers")
local CO = { sel = 1, markers = {} }
local function curPos()
  local hr = myRoot()
  return hr and hr.Position or nil
end
local function markerRebuild()
  for _, m in pairs(CO.markers) do pcall(function() m:Destroy() end) end
  CO.markers = {}
  if not CO.show then return end
  for i, p in ipairs(TK.DB.points) do
    local pos = TK.V3(p.x, p.y, p.z)
    local pillar = TK.apart(markF, "Pillar", TK.V3(.4, 30, .4), TK.C.ac3, CFrame.new(pos + TK.V3(0, 15, 0)), Enum.Material.Neon, nil, .4)
    TK.billboard(pillar, "📍 " .. p.name, TK.C.ac3, 120, 22).Parent.StudsOffset = TK.V3(0, 17, 0)
    CO.markers[i] = pillar
  end
end
TK.onUnload(function() for _, m in pairs(CO.markers) do pcall(function() m:Destroy() end) end end)
local nameBox
function TK.pointAdd(name)
  local p = curPos()
  if not p then TK.notify("Нет персонажа", TK.C.dg, 1.5) return end
  if #TK.DB.points >= 20 then TK.notify("Лимит точек: 20", TK.C.dg, 1.5) return end
  name = (name and name:gsub("^%s+", ""):gsub("%s+$", "") or "")
  if name == "" then name = "Точка " .. (#TK.DB.points + 1) end
  name = name:sub(1, 24)
  TK.DB.points[#TK.DB.points + 1] = { name = name, x = p.X, y = p.Y, z = p.Z }
  CO.sel = #TK.DB.points
  TK.dbSave()
  markerRebuild()
  TK.notify("📍 Сохранено: " .. name, TK.C.ac3, 1.5)
end
function TK.pointGo()
  local pt = TK.DB.points[CO.sel]
  local hr = myRoot()
  if not pt or not hr then TK.notify("Нет выбранной точки", TK.C.dg, 1.5) return end
  if TK.RIDING then TK.notify("Сначала слезь с корабля", TK.C.dg, 1.5) return end
  TK.dimFx(nil, .6)
  hr.CFrame = CFrame.new(pt.x, pt.y + 3, pt.z)
  hr.AssemblyLinearVelocity = TK.V3()
  TK.notify("📍 Переход: " .. pt.name .. " (локальный, только твой экран)", TK.C.ac3, 2)
end
function TK.pointCoordsText()
  local p = curPos()
  if not p then return "  нет персонажа" end
  return string.format("  X %.0f   Y %.0f   Z %.0f", p.X, p.Y, p.Z)
end
TK.regSys({
  n = 1, name = "Межпространственные координаты", tab = "dims", mode = "test",
  note = "Переход к точке меняет только положение твоего персонажа у тебя; сервер с античитом может откатить.", keys = "координаты точки карта маркеры",
  get = function() return CO.show == true end, set = function(v) CO.show = v markerRebuild() end,
})
TK.sect("dims", function(f)
  TK.newSec(f, "СИСТЕМА 1 · КООРДИНАТЫ И ГОЛО-КАРТА")
  TK.newStatus(f, function() return TK.pointCoordsText() end, 24)
  -- карта сверху: игрок в центре, точки вокруг
  local map = TK.I("Frame", { Size = UDim2.new(1, -8, 0, 150), BackgroundColor3 = TK.RGB(8, 20, 24), ZIndex = 42 }, f)
  TK.cr(map, 8)
  TK.sk(map, TK.C.ac, 1, .5)
  TK.I("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, .5), BackgroundColor3 = TK.C.ac, BackgroundTransparency = .8, BorderSizePixel = 0, ZIndex = 43 }, map)
  TK.I("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(.5, 0), BackgroundColor3 = TK.C.ac, BackgroundTransparency = .8, BorderSizePixel = 0, ZIndex = 43 }, map)
  local me = TK.I("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = TK.C.ac, ZIndex = 45 }, map)
  TK.cr(me, 5)
  local dots = {}
  TK.addRefresh(function()
    local p = curPos()
    if not p then return end
    local far = 50
    for _, pt in ipairs(TK.DB.points) do far = math.max(far, math.abs(pt.x - p.X), math.abs(pt.z - p.Z)) end
    far = far * 1.15
    for i, pt in ipairs(TK.DB.points) do
      local d = dots[i]
      if not d then
        d = TK.I("TextLabel", {
          Size = UDim2.fromOffset(80, 14), AnchorPoint = Vector2.new(0, .5), BackgroundTransparency = 1, TextColor3 = TK.C.ac3,
          Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 44,
        }, map)
        dots[i] = d
      end
      d.Text = "● " .. pt.name
      d.TextColor3 = (i == CO.sel) and TK.C.ac or TK.C.ac3
      d.Position = UDim2.new(.5 + (pt.x - p.X) / far * .5, 0, .5 + (pt.z - p.Z) / far * .5, 0)
      d.Visible = true
    end
    for i = #TK.DB.points + 1, #dots do dots[i].Visible = false end
  end)
  nameBox = TK.I("TextBox", {
    Size = UDim2.new(1, -8, 0, 32), BackgroundColor3 = TK.C.bg2, TextColor3 = TK.C.tx, PlaceholderText = "имя точки (до 24 символов)",
    PlaceholderColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 12, Text = "", ClearTextOnFocus = false, ZIndex = 42,
  }, f)
  TK.cr(nameBox, 8)
  TK.newBtn(f, "📍 Сохранить здесь", TK.C.ac, function() TK.pointAdd(nameBox.Text) nameBox.Text = "" end, 34)
  TK.newBtn(f, "▶ Выбрать следующую точку", TK.C.bg2, function()
    if #TK.DB.points == 0 then TK.notify("Точек нет", TK.C.dg, 1.2) return end
    CO.sel = CO.sel % #TK.DB.points + 1
  end, 30)
  TK.newStatus(f, function()
    local pt = TK.DB.points[CO.sel]
    local n = #TK.DB.points
    if not pt then return "  Сохранённых точек: 0 / 20" end
    local p = curPos()
    local d = p and (TK.V3(pt.x, pt.y, pt.z) - p).Magnitude or 0
    return string.format("  [%d/%d] %s\n  X %.0f  Y %.0f  Z %.0f · %.0f ст. от тебя", CO.sel, n, pt.name, pt.x, pt.y, pt.z, d)
  end, 44)
  TK.newBtn(f, "🌀 Перейти к выбранной (локально)", TK.C.bg2, TK.pointGo, 32)
  TK.newBtn(f, "✏ Переименовать выбранную (имя из поля)", TK.C.bg2, function()
    local pt = TK.DB.points[CO.sel]
    local nm = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if not pt or nm == "" then TK.notify("Нужна точка и имя в поле", TK.C.dg, 1.5) return end
    pt.name = nm:sub(1, 24)
    nameBox.Text = ""
    TK.dbSave()
    markerRebuild()
  end, 32)
  TK.newBtn(f, "🗑 Удалить выбранную", TK.C.bg2, function()
    if TK.DB.points[CO.sel] then
      table.remove(TK.DB.points, CO.sel)
      CO.sel = math.max(1, math.min(CO.sel, #TK.DB.points))
      TK.dbSave()
      markerRebuild()
    end
  end, 32)
  TK.newToggle(f, "📌 Маркеры-столбы в мире", function() return CO.show == true end, function(v) CO.show = v markerRebuild() end)
  TK.newInfo(f, "\n  Точки сохраняются в файл (если есть writefile).\n  Переход меняет положение ТОЛЬКО твоего персонажа на твоём клиенте.", 56)
end)

-- ============================================================
--  СПИСОК ИЗМЕРЕНИЙ (из скриншота пользователя; описаний нет, если они не подтверждены)
-- ============================================================
TK.DIMS = {
  { "C-137", "Родное измерение Рика и Морти из основного сериала." },
  { "C-131", "Название взято из скриншота пользователя; описание не подтверждено." },
  { "Прайм-измерение", "Измерение Рика Прайма (по теме скинов и пушки)." },
  { "5126", "Из скриншота пользователя; описание не подтверждено." },
  { "35-C", "Из скриншота пользователя; описание не подтверждено." },
  { "304-X", "Из скриншота пользователя; описание не подтверждено." },
  { "437", "Из скриншота пользователя; описание не подтверждено." },
  { "9-2184C", "Из скриншота пользователя; описание не подтверждено." },
  { "C-132", "Из скриншота пользователя; описание не подтверждено." },
  { "C-500A", "Из скриншота пользователя; описание не подтверждено." },
  { "J19ζ7", "Из скриншота пользователя; описание не подтверждено." },
  { "C-1.21", "Из скриншота пользователя; описание не подтверждено." },
  { "C-118", "Из скриншота пользователя; описание не подтверждено." },
  { "C-141", "Из скриншота пользователя; описание не подтверждено." },
  { "C-198", "Из скриншота пользователя; описание не подтверждено." },
  { "C-229", "Из скриншота пользователя; описание не подтверждено." },
  { "C-290", "Из скриншота пользователя; описание не подтверждено." },
  { "D716", "Из скриншота пользователя; описание не подтверждено." },
  { "Мир собак", "Из скриншота пользователя; описание не подтверждено." },
  { "Мир осиных людей", "Из скриншота пользователя; описание не подтверждено." },
}
TK.X.dim = 1
TK.sect("dims", function(f)
  TK.newSec(f, "ИЗМЕРЕНИЯ (виртуальный выбор)")
  TK.newStatus(f, function()
    local d = TK.DIMS[TK.X.dim]
    return "  Текущее: " .. d[1] .. "\n  " .. d[2]
  end, 56)
  local gr = TK.newGrid(f, 2)
  for i, d in ipairs(TK.DIMS) do
    TK.newBtn(gr, "🌌 " .. d[1], TK.C.bg2, function()
      TK.X.dim = i
      TK.dimFx(nil, 1)
      TK.notify("🌌 Измерение: " .. d[1] .. " (эффект, не настоящий переход)", TK.C.ac2, 2)
    end, 32).TextSize = 10
  end
  TK.newInfo(f, "\n  Это визуальный эффект перехода и пометка для тебя.\n  Настоящего переключения между мирами/серверами нет.", 56)
end)

-- ============================================================
--  СИСТЕМА 11: МЕЖПРОСТРАНСТВЕННЫЙ РАДАР (без игроков)
-- ============================================================
local RD = { on = false, items = {}, acc = 0, t = 0, f = { points = true, toolkit = true, npc = true, portal = true } }
RD.frame = TK.I("Frame", {
  Name = "RM_Radar", Size = UDim2.fromOffset(150, 150), Position = UDim2.new(1, -162, 0, 40), BackgroundColor3 = TK.RGB(6, 18, 22),
  BackgroundTransparency = .15, Visible = false, ZIndex = 25,
}, TK.gui)
TK.cr(RD.frame, 75)
TK.sk(RD.frame, TK.C.ac, 2, .3)
TK.drag(RD.frame)
TK.I("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, .5), BackgroundColor3 = TK.C.ac, BackgroundTransparency = .8, BorderSizePixel = 0, ZIndex = 26 }, RD.frame)
TK.I("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(.5, 0), BackgroundColor3 = TK.C.ac, BackgroundTransparency = .8, BorderSizePixel = 0, ZIndex = 26 }, RD.frame)
do
  local mid = TK.I("Frame", { Size = UDim2.fromScale(.5, .5), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1, ZIndex = 26 }, RD.frame)
  TK.sk(mid, TK.C.ac, 1, .7)
  TK.cr(mid, 40)
end
RD.sweep = TK.I("Frame", { Size = UDim2.fromOffset(2, 72), AnchorPoint = Vector2.new(.5, 1), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = TK.C.ac, BackgroundTransparency = .3, BorderSizePixel = 0, ZIndex = 27, Rotation = 0 }, RD.frame)
TK.I("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = TK.WHITE, ZIndex = 29 }, RD.frame)
RD.pool = {}
local function radarDot(i)
  local d = RD.pool[i]
  if not d then
    d = TK.I("Frame", { Size = UDim2.fromOffset(7, 7), AnchorPoint = Vector2.new(.5, .5), ZIndex = 28 }, RD.frame)
    TK.cr(d, 4)
    RD.pool[i] = d
  end
  return d
end
local RD_COL = { points = TK.RGB(90, 220, 255), toolkit = TK.RGB(80, 255, 140), npc = TK.RGB(255, 170, 60), portal = TK.RGB(180, 100, 255) }
local function radarCollect()
  local hr = myRoot()
  RD.items = {}
  if not hr then return end
  if RD.f.points then
    for _, p in ipairs(TK.DB.points) do RD.items[#RD.items + 1] = { pos = TK.V3(p.x, p.y, p.z), k = "points" } end
  end
  if RD.f.portal then
    for _, P in ipairs({ TK.PA, TK.PB }) do
      if P and P.pos then RD.items[#RD.items + 1] = { pos = P.pos, k = "portal" } end
    end
  end
  if RD.f.toolkit then
    for _, p in ipairs(TK.propsLive and TK.propsLive() or {}) do RD.items[#RD.items + 1] = { pos = p.Position, k = "toolkit" } end
    if TK.ship and TK.ship.pos then RD.items[#RD.items + 1] = { pos = TK.ship.pos, k = "toolkit" } end
  end
  if RD.f.npc then
    for _, o in ipairs(TK.scanWorld(TK.ST.RadarRadius, 25, true)) do RD.items[#RD.items + 1] = { pos = o.pos, k = "npc" } end
  end
end
TK.tick("radar", 10, function(dt)
  if not RD.on then return end
  RD.t = RD.t + dt
  RD.acc = RD.acc + dt
  RD.sweep.Rotation = (RD.t * 120) % 360
  local hr = myRoot()
  if not hr then return end
  if RD.acc > 1.2 then RD.acc = 0 radarCollect() end
  local cam = TK.Workspace.CurrentCamera
  local yaw = 0
  if cam then
    local lv = cam.CFrame.LookVector
    yaw = math.atan2(-lv.X, -lv.Z)
  end
  local R = TK.ST.RadarRadius
  local n = 0
  for _, it in ipairs(RD.items) do
    local off = it.pos - hr.Position
    local x, z = off.X, off.Z
    local c, s = math.cos(yaw), math.sin(yaw)
    local rx, rz = x * c - z * s, x * s + z * c -- поворот: верх радара = куда смотрит камера
    local dist = math.sqrt(rx * rx + rz * rz)
    if dist <= R and n < 60 then
      n = n + 1
      local d = radarDot(n)
      d.BackgroundColor3 = RD_COL[it.k]
      d.Position = UDim2.new(.5 + rx / R * .5, 0, .5 + rz / R * .5, 0)
      d.Visible = true
    end
  end
  for i = n + 1, #RD.pool do RD.pool[i].Visible = false end
end)
function TK.radarSet(v)
  RD.on = v
  RD.frame.Visible = v
  if v then radarCollect() end
end
TK.onUnload(function() pcall(function() RD.frame:Destroy() end) end)
TK.onRespawn(function() RD.acc = 9 end)
TK.regSys({
  n = 11, name = "Межпространственный радар", tab = "dims", mode = "visual",
  note = "Показывает точки, объекты Toolkit, порталы и NPC; игроков не показывает.", keys = "радар карта маркеры",
  get = function() return RD.on end, set = function(v) TK.radarSet(v) end,
})
TK.sect("dims", function(f)
  TK.newSec(f, "СИСТЕМА 11 · РАДАР (без игроков)")
  TK.newToggle(f, "📡 Радар", function() return RD.on end, TK.radarSet)
  TK.newNum(f, "↔ Радиус", "RadarRadius", 20, nil, " ст.")
  for _, k in ipairs({ { "points", "📍 Точки" }, { "toolkit", "🧰 Объекты Toolkit" }, { "npc", "🧍 NPC" }, { "portal", "🌀 Порталы" } }) do
    TK.newToggle(f, k[2], function() return RD.f[k[1]] end, function(v) RD.f[k[1]] = v RD.acc = 9 end, 30)
  end
  TK.newInfo(f, "\n  Окошко радара можно двигать. Верх = направление камеры.", 40)
end)

-- ============================================================
--  СИСТЕМА 8: СКАНЕР ОКРУЖЕНИЯ  /  СИСТЕМА 18: АНАЛИЗАТОР NPC
-- ============================================================
local scanF = folder("Scan")
local SC = { boxes = {}, text = "  Нажми «Сканировать».", id = 0 }
local function showBoxes(list, store)
  clearBoxes(store)
  for _, o in ipairs(list) do
    local ok, sb = pcall(function()
      return TK.I("SelectionBox", { Adornee = o.inst, Color3 = TK.KINDCOL[o.kind], LineThickness = .06, SurfaceTransparency = .85, SurfaceColor3 = TK.KINDCOL[o.kind] }, scanF)
    end)
    if ok then store[#store + 1] = sb end
  end
end
local function scanRing(col)
  local hr = myRoot()
  if not hr then return end
  local ring = TK.I("Part", {
    Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
    Material = Enum.Material.Neon, Color = col, Transparency = .3, Size = TK.V3(.2, 2, 2), CFrame = CFrame.new(hr.Position - TK.V3(0, 2.5, 0)) * TK.R90,
  }, scanF)
  TK.TweenService:Create(ring, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = TK.V3(.2, 160, 160), Transparency = 1 }):Play()
  task.delay(1.1, function() pcall(function() ring:Destroy() end) end)
end
function TK.scanDo()
  if not TK.enUse(3, "сканер") then return end
  scanRing(TK.C.ac3)
  SC.id = SC.id + 1
  local id = SC.id
  local list = TK.scanWorld(120, 14, false)
  showBoxes(list, SC.boxes)
  local lines = { "  Найдено: " .. #list .. " (игроки не сканируются)" }
  for i, o in ipairs(list) do
    if i > 8 then break end
    lines[#lines + 1] = string.format("  %s · %s · %.0f ст.", o.name:sub(1, 18), TK.KINDNAME[o.kind], o.dist)
  end
  SC.text = table.concat(lines, "\n")
  task.delay(15, function() if SC.id == id then clearBoxes(SC.boxes) end end)
end
function TK.scanClear() clearBoxes(SC.boxes) SC.id = SC.id + 1 SC.text = "  Очищено." end
TK.onUnload(function() clearBoxes(SC.boxes) end)
TK.regSys({
  n = 8, name = "Сканер окружения", tab = "newsys", mode = "visual",
  note = "Показывает имя, тип и расстояние публичных объектов; игроков не сканирует.", keys = "сканер объекты рамки окружение",
  get = function() return #SC.boxes > 0 end, set = function(v) if v then TK.scanDo() else TK.scanClear() end end,
})
TK.sect("newsys", function(f)
  TK.newSec(f, "СИСТЕМА 8 · СКАНЕР ОКРУЖЕНИЯ")
  TK.newBtn(f, "📡 Сканировать (3 энергии)", TK.C.ac, TK.scanDo, 36)
  TK.newBtn(f, "🧹 Убрать рамки", TK.C.bg2, TK.scanClear, 30)
  TK.newStatus(f, function() return SC.text end, 120)
  TK.newInfo(f, "\n  Цвета: зелёный — Toolkit, оранжевый — NPC, синий — модель, серый — деталь.", 40)
end)

local NA = { boxes = {}, text = "  Нажми «Анализ».", id = 0 }
function TK.npcAnalyze()
  if not TK.enUse(2, "анализатор") then return end
  scanRing(TK.RGB(255, 170, 60))
  NA.id = NA.id + 1
  local id = NA.id
  local list = TK.scanWorld(120, 6, true)
  showBoxes(list, NA.boxes)
  if #list == 0 then NA.text = "  NPC рядом нет (в радиусе 120)." else
    local lines = {}
    for _, o in ipairs(list) do
      local h = o.hum
      lines[#lines + 1] = string.format("  %s · %.0f ст.\n    HP %d/%d · скорость %d · %s", o.name:sub(1, 18), o.dist,
        h and h.Health or 0, h and h.MaxHealth or 0, h and h.WalkSpeed or 0, h and tostring(h.RigType):gsub("Enum.HumanoidRigType.", "") or "?")
    end
    NA.text = table.concat(lines, "\n")
  end
  task.delay(15, function() if NA.id == id then clearBoxes(NA.boxes) end end)
end
function TK.npcClear() clearBoxes(NA.boxes) NA.id = NA.id + 1 NA.text = "  Очищено." end
TK.onUnload(function() clearBoxes(NA.boxes) end)
TK.regSys({
  n = 18, name = "Анализатор NPC", tab = "newsys", mode = "test",
  note = "Читает только публичные свойства NPC и ничего в них не меняет; игроков не затрагивает.", keys = "npc анализатор здоровье скорость",
  get = function() return #NA.boxes > 0 end, set = function(v) if v then TK.npcAnalyze() else TK.npcClear() end end,
})
TK.sect("newsys", function(f)
  TK.newSec(f, "СИСТЕМА 18 · АНАЛИЗАТОР NPC")
  TK.newBtn(f, "🔎 Анализ ближайших NPC (2 энергии)", TK.C.ac, TK.npcAnalyze, 36)
  TK.newBtn(f, "🧹 Убрать рамки", TK.C.bg2, TK.npcClear, 30)
  TK.newStatus(f, function() return NA.text end, 120)
end)

-- ============================================================
--  СИСТЕМА 2: ЭХО-КЛОН (копия твоего пути с задержкой)
-- ============================================================
local echoF = folder("Echo")
local EC = { on = false, buf = {}, m = nil, acc = 0 }
local function echoModel()
  local id = TK.ST.ActiveSkin
  if id ~= "" and TK.SK[id] then
    local ok, m = pcall(TK.skinModel, TK.SK[id])
    if ok and m then return m end
  end
  local ch = TK.LP.Character
  if not ch then return nil end
  local arch = ch.Archivable
  ch.Archivable = true
  local ok, c = pcall(function() return ch:Clone() end)
  ch.Archivable = arch
  if not ok or not c then return nil end
  for _, d in ipairs(c:GetDescendants()) do
    if d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then d:Destroy() end
  end
  for _, d in ipairs(c:GetDescendants()) do
    if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false end
  end
  return c
end
local function echoSetAlpha(m, a)
  for _, d in ipairs(m:GetDescendants()) do
    if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
      local base = d:GetAttribute("EBase")
      if base == nil then base = d.Transparency d:SetAttribute("EBase", base) end
      d.Transparency = math.clamp(base + (1 - base) * a, 0, 1)
      d.Color = d.Color
    end
  end
end
local function echoOff(quiet)
  EC.on, EC.buf = false, {}
  if EC.m then
    local m = EC.m
    EC.m = nil
    local a = 0
    task.spawn(function()
      for i = 1, 8 do
        pcall(function() echoSetAlpha(m, i / 8) end)
        task.wait(.04)
      end
      pcall(function() m:Destroy() end)
    end)
  end
  if not quiet then TK.notify("👥 Эхо-клон выключен", TK.C.tx, 1.2) end
end
local function echoOn()
  if EC.on then return end
  local hr = myRoot()
  if not hr then TK.notify("Нет персонажа", TK.C.dg, 1.5) return end
  local m = echoModel()
  if not m then TK.notify("Не вышло собрать клон", TK.C.dg, 1.5) return end
  m.Name = "RM_Echo"
  m.Parent = echoF
  pcall(function() m:PivotTo(hr.CFrame * CFrame.new(0, 0, 3)) end)
  EC.m, EC.on, EC.buf, EC.acc = m, true, {}, 0
  for i = 1, 6 do
    task.delay(i * .03, function() if EC.m == m then pcall(function() echoSetAlpha(m, math.max(TK.ST.EchoAlpha / 100, 1 - i / 6)) end) end end)
  end
  TK.burst(hr.Position, TK.C.ac3, 12)
  TK.notify("👥 Эхо-клон включён", TK.C.ac3, 1.5)
end
TK.tick("echo", 20, function(dt)
  if not EC.on then return end
  local hr = myRoot()
  if not hr or not EC.m or not EC.m.Parent then echoOff(true) return end
  EC.buf[#EC.buf + 1] = { os.clock(), hr.CFrame }
  local keep = math.max(TK.ST.EchoLen, TK.ST.EchoDelay / 10 + 1)
  while #EC.buf > 2 and EC.buf[1][1] < os.clock() - keep do table.remove(EC.buf, 1) end
  local want = os.clock() - TK.ST.EchoDelay / 10
  local cf = nil
  for i = #EC.buf, 1, -1 do
    if EC.buf[i][1] <= want then
      local a, b = EC.buf[i], EC.buf[i + 1]
      cf = b and a[2]:Lerp(b[2], math.clamp((want - a[1]) / math.max(b[1] - a[1], 1e-3), 0, 1)) or a[2]
      break
    end
  end
  if cf then pcall(function() EC.m:PivotTo(cf) end) end
  EC.acc = EC.acc + dt
  if EC.acc > .5 then EC.acc = 0 pcall(function() echoSetAlpha(EC.m, TK.ST.EchoAlpha / 100) end) end
end)
TK.onRespawn(function() if EC.on then echoOff(true) end end)
TK.onUnload(function() EC.on = false if EC.m then pcall(function() EC.m:Destroy() end) end end)
TK.regSys({
  n = 2, name = "Эхо-клон персонажа", tab = "newsys", mode = "visual",
  note = "Статичная копия, повторяющая твой путь с задержкой; не NPC и не серверный объект.", keys = "эхо клон копия двойник",
  get = function() return EC.on end, set = function(v) if v then echoOn() else echoOff() end end,
})
TK.sect("newsys", function(f)
  TK.newSec(f, "СИСТЕМА 2 · ЭХО-КЛОН")
  TK.newToggle(f, "👥 Эхо-клон", function() return EC.on end, function(v) if v then echoOn() else echoOff() end end)
  TK.newNum(f, "⏱ Задержка (×0.1 с)", "EchoDelay", 5)
  TK.newNum(f, "👁 Прозрачность", "EchoAlpha", 10, nil, "%")
  TK.newNum(f, "🎞 Длина записи", "EchoLen", 2, nil, " с")
  TK.newInfo(f, "\n  Копия твоего скина (или аватара) идёт по твоему следу.\n  Поза статичная: ходьбу клон не анимирует.", 56)
end)

-- ============================================================
--  СИСТЕМА 4: МАШИНА ВРЕМЕНИ (метки состояния Toolkit и возврат на свою позицию)
-- ============================================================
local timeF = folder("Time")
local TM = { marks = {}, cap = nil }
local function capsuleAt(cf)
  if TM.cap then pcall(function() TM.cap:Destroy() end) end
  local m = Instance.new("Model")
  m.Name = "RM_TimeMachine"
  TK.apart(m, "Pod", TK.V3(6, 3.4, 3.4), TK.RGB(70, 80, 100), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder, .15)
  TK.apart(m, "Glass", TK.V3(5.4, 3, 3), TK.RGB(150, 220, 255), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Glass, Enum.PartType.Cylinder, .6)
  for i = 0, 2 do
    TK.apart(m, "Ring" .. i, TK.V3(.25, 4.2, 4.2), TK.C.ac2, cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(-2 + i * 2, 0, 0), Enum.Material.Neon, Enum.PartType.Cylinder, .3)
  end
  local core = TK.apart(m, "Core", TK.V3(1.4, 1.4, 1.4), TK.RGB(200, 160, 255), cf * CFrame.new(0, 3, 0), Enum.Material.Neon, Enum.PartType.Ball, .1)
  TK.I("PointLight", { Color = TK.RGB(200, 160, 255), Range = 18, Brightness = 2, Shadows = false }, core)
  m.Parent = timeF
  TM.cap = m
  task.delay(2.5, function()
    if TM.cap == m then
      for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then pcall(function() TK.TweenService:Create(d, TweenInfo.new(.6), { Transparency = 1 }):Play() end) end
      end
      task.delay(.7, function() pcall(function() m:Destroy() end) end)
    end
  end)
end
function TK.timeMark()
  local hr = myRoot()
  if not hr then return end
  if #TM.marks >= 5 then table.remove(TM.marks, 1) end
  TM.marks[#TM.marks + 1] = {
    cf = hr.CFrame, skin = TK.ST.ActiveSkin, emo = TK.ST.Emotion, en = TK.EN.cur, t = os.date("%H:%M:%S"),
  }
  TK.burst(hr.Position, TK.RGB(200, 160, 255), 14)
  TK.notify("⏳ Метка " .. #TM.marks .. " сохранена · " .. TM.marks[#TM.marks].t, TK.C.ac2, 1.6)
end
function TK.timeReturn()
  local hr = myRoot()
  local mk = TM.marks[#TM.marks]
  if not hr or not mk then TK.notify("Сначала поставь метку", TK.C.dg, 1.5) return end
  if TK.RIDING then TK.notify("Сначала слезь с корабля", TK.C.dg, 1.5) return end
  if not TK.enUse(20, "машина времени") then return end
  capsuleAt(hr.CFrame * CFrame.new(0, -2.8, -4))
  TK.dimFx(TK.RGB(200, 160, 255), .9)
  task.delay(.9, function()
    local h2 = myRoot()
    if not h2 or TK.DEAD then return end
    h2.CFrame = mk.cf
    h2.AssemblyLinearVelocity = TK.V3()
    if mk.skin ~= "" and mk.skin ~= TK.ST.ActiveSkin then TK.safe(TK.applySkin, mk.skin) end
    if mk.skin == "" and TK.ST.ActiveSkin ~= "" then TK.removeSkin() end
    TK.setEmo(mk.emo)
    TK.EN.cur = math.max(TK.EN.cur, math.min(mk.en, TK.ST.EnergyMax))
    table.remove(TM.marks)
    TK.notify("⏳ Возврат к метке (локально)", TK.C.ac2, 2)
  end)
end
TK.onUnload(function() if TM.cap then pcall(function() TM.cap:Destroy() end) end end)
TK.regSys({
  n = 4, name = "Машина времени", tab = "newsys", mode = "test",
  note = "Возвращает твой персонаж и состояние Toolkit; время сервера и чужие объекты не меняет.", keys = "время машина метка возврат",
  get = function() return #TM.marks > 0 end, set = function(v) if v then TK.timeMark() else TM.marks = {} end end,
})
TK.sect("newsys", function(f)
  TK.newSec(f, "СИСТЕМА 4 · МАШИНА ВРЕМЕНИ")
  TK.newBtn(f, "⏳ Поставить временную метку", TK.C.ac, TK.timeMark, 36)
  TK.newBtn(f, "↩ Вернуться к последней метке (20 энергии)", TK.C.bg2, TK.timeReturn, 36)
  TK.newBtn(f, "🗑 Стереть метки", TK.C.bg2, function() TM.marks = {} end, 30)
  TK.newStatus(f, function()
    if #TM.marks == 0 then return "  Меток нет (до 5)." end
    local l = { "  Метки (время создания):" }
    for i, m in ipairs(TM.marks) do l[#l + 1] = "  " .. i .. ". " .. m.t .. (m.skin ~= "" and ("  · " .. m.skin) or "") end
    return table.concat(l, "\n")
  end, 90)
  TK.newInfo(f, "\n  Метка = твоя позиция, скин, лицо и энергия Toolkit.\n  Только твоя тестовая среда: время сервера не меняется.", 56)
end)

-- ============================================================
--  СИСТЕМА 12: НЕСКОЛЬКО РОБОТОВ (визуальные, свой набор команд)
-- ============================================================
local robF = folder("Robots")
local RB = { list = {}, sel = 1 }
local RTYPES = { "Шар", "Шагоход", "Куб-дрон" }
local function robotBuild(kind, colName)
  local m = Instance.new("Model")
  m.Name = "RM_Robot"
  local col = TK.colOf(colName)
  local dark = TK.RGB(45, 50, 62)
  local body
  if kind == 1 then
    body = TK.apart(m, "Body", TK.V3(2.2, 2.2, 2.2), dark, CFrame.new(), Enum.Material.Metal, Enum.PartType.Ball)
    TK.apart(m, "Eye", TK.V3(.8, .8, .3), col, CFrame.new(0, .2, -1), Enum.Material.Neon, Enum.PartType.Ball)
  elseif kind == 2 then
    body = TK.apart(m, "Body", TK.V3(2, 1.4, 2.6), dark, CFrame.new(), Enum.Material.Metal)
    for _, s in ipairs({ -1, 1 }) do
      TK.apart(m, "Leg", TK.V3(.3, 1.6, .3), TK.RGB(150, 160, 175), CFrame.new(s * 1, -1.1, -.7), Enum.Material.Metal)
      TK.apart(m, "Leg", TK.V3(.3, 1.6, .3), TK.RGB(150, 160, 175), CFrame.new(s * 1, -1.1, .7), Enum.Material.Metal)
    end
    TK.apart(m, "Eye", TK.V3(1.2, .35, .2), col, CFrame.new(0, .2, -1.3), Enum.Material.Neon)
  else
    body = TK.apart(m, "Body", TK.V3(1.8, 1.8, 1.8), dark, CFrame.new(), Enum.Material.Metal)
    for _, s in ipairs({ -1, 1 }) do
      TK.apart(m, "Rotor", TK.V3(1.6, .1, .3), col, CFrame.new(s * 1.3, 1, 0), Enum.Material.Neon)
    end
    TK.apart(m, "Eye", TK.V3(.9, .9, .2), col, CFrame.new(0, 0, -.95), Enum.Material.Neon)
  end
  m.PrimaryPart = body
  m.Parent = robF
  return m
end
function TK.robotAdd()
  for i = #RB.list, 1, -1 do if not RB.list[i].m.Parent then table.remove(RB.list, i) end end
  if #RB.list >= TK.ST.RobotLimit then TK.notify("Лимит роботов: " .. TK.ST.RobotLimit, TK.C.dg, 1.5) return end
  local hr = myRoot()
  if not hr then return end
  local n = #RB.list + 1
  local kind = (n - 1) % 3 + 1
  local colName = TK.COLLIST[(n % 5) + 1]
  local pos = hr.Position + hr.CFrame.LookVector * -4
  local m = robotBuild(kind, colName)
  m:PivotTo(CFrame.new(pos))
  RB.list[n] = { m = m, kind = kind, col = colName, mode = "follow", goal = nil, pos = pos, t = math.random() * 6, slot = n }
  RB.sel = n
  TK.burst(pos, TK.colOf(colName), 14)
  TK.notify("🤖 Робот " .. n .. ": " .. RTYPES[kind], TK.colOf(colName), 1.4)
end
function TK.robotClearAll()
  for i = #RB.list, 1, -1 do pcall(function() RB.list[i].m:Destroy() end) RB.list[i] = nil end
  RB.sel = 1
end
local function robotSel() return RB.list[RB.sel] end
TK.tick("robots", 20, function(dt)
  local hr = myRoot()
  if not hr then return end
  for i, r in ipairs(RB.list) do
    r.t = r.t + dt
    local target
    if r.mode == "follow" then
      local a = (i / math.max(#RB.list, 1)) * math.pi + math.pi / 2
      target = hr.Position + hr.CFrame:VectorToWorldSpace(TK.V3(math.cos(a) * 5, 0, math.sin(a) * 5 + 3))
    elseif r.mode == "goto" and r.goal then target = r.goal else target = r.pos end
    local gy = TK.groundAt(target + TK.V3(0, 4, 0)) or target.Y
    local hover = r.kind == 3 and 4 or (r.kind == 1 and 1.4 or 2.2)
    local flat = TK.V3(target.X - r.pos.X, 0, target.Z - r.pos.Z)
    local step = math.min(flat.Magnitude, 18 * dt)
    local np = r.pos + (flat.Magnitude > .05 and flat.Unit * step or TK.V3())
    r.pos = TK.V3(np.X, gy + hover + math.sin(r.t * 3) * .2, np.Z)
    local look = flat.Magnitude > .3 and flat.Unit or nil
    pcall(function()
      local cf = CFrame.new(r.pos)
      if look then cf = CFrame.lookAt(r.pos, r.pos + look) end
      r.m:PivotTo(cf * CFrame.Angles(0, 0, math.sin(r.t * 2) * .05))
    end)
    if r.mode == "goto" and flat.Magnitude < .4 then r.mode = "stand" end
  end
end)
TK.onUnload(TK.robotClearAll)
TK.regSys({
  n = 12, name = "Несколько роботов", tab = "robots", mode = "visual",
  note = "Локальные визуальные роботы; не связаны с Мисиксами и не воздействуют на игроков.", keys = "роботы следовать стоять",
  get = function() return #RB.list > 0 end, set = function(v) if v then TK.robotAdd() else TK.robotClearAll() end end,
})
TK.sect("robots", function(f)
  TK.newSec(f, "СИСТЕМА 12 · РОБОТЫ (3 типа)")
  TK.newBtn(f, "🤖 Создать робота", TK.C.ac, TK.robotAdd, 36)
  TK.newBtn(f, "▶ Выбрать следующего", TK.C.bg2, function() if #RB.list > 0 then RB.sel = RB.sel % #RB.list + 1 end end, 30)
  local og = TK.newGrid(f, 2)
  TK.newBtn(og, "🚶 Следовать", TK.C.bg2, function() local r = robotSel() if r then r.mode = "follow" end end, 32)
  TK.newBtn(og, "🛑 Стоять", TK.C.bg2, function() local r = robotSel() if r then r.mode = "stand" end end, 32)
  TK.newBtn(og, "📍 К точке прицела", TK.C.bg2, function() local r = robotSel() if r then r.mode = "goto" r.goal = TK.aimHit(120) end end, 32)
  TK.newBtn(og, "🎨 Цвет", TK.C.bg2, function()
    local r = robotSel()
    if not r then return end
    for i, v in ipairs(TK.COLLIST) do if v == r.col then r.col = TK.COLLIST[i % 5 + 1] break end end
    local c = TK.colOf(r.col)
    for _, d in ipairs(r.m:GetDescendants()) do
      if d:IsA("BasePart") and d.Material == Enum.Material.Neon then d.Color = c end
    end
  end, 32)
  TK.newBtn(f, "🗑 Удалить выбранного", TK.C.bg2, function()
    local r = robotSel()
    if r then pcall(function() r.m:Destroy() end) table.remove(RB.list, RB.sel) RB.sel = math.max(1, math.min(RB.sel, #RB.list)) end
  end, 30)
  TK.newBtn(f, "🗑 Удалить всех", TK.C.dg, TK.robotClearAll, 30)
  TK.newNum(f, "🔢 Лимит роботов", "RobotLimit", 1)
  TK.newStatus(f, function()
    if #RB.list == 0 then return "  Роботов нет." end
    local l = {}
    local MN = { follow = "следует", stand = "стоит", ["goto"] = "идёт" }
    for i, r in ipairs(RB.list) do l[#l + 1] = (i == RB.sel and "▶ " or "  ") .. i .. ". " .. RTYPES[r.kind] .. " · " .. (TK.COLNAMES[r.col]) .. " · " .. (MN[r.mode] or r.mode) end
    return table.concat(l, "\n")
  end, 100)
end)

-- ============================================================
--  СИСТЕМА 19: РАЗВЕДЫВАТЕЛЬНЫЙ ДРОН (твой собственный, видит только твою сцену)
-- ============================================================
local droneF = folder("Drone")
local DR = { on = false, m = nil, pos = nil, yaw = 0, mode = "follow", view = false, keys = {}, rot = 0 }
local function droneView(v)
  DR.view = v
  local cam = TK.Workspace.CurrentCamera
  if not v and cam then
    cam.CameraType = Enum.CameraType.Custom
    TK.safe(TK.fixCam)
  end
end
local function droneOff(quiet)
  if DR.on then droneView(false) end
  DR.on = false
  TK.padHide("drone")
  if DR.m then pcall(function() DR.m:Destroy() end) DR.m = nil end
  if not quiet then TK.notify("🛸 Дрон выключен", TK.C.tx, 1.2) end
end
local function droneOn()
  if DR.on then return end
  local hr = myRoot()
  if not hr then TK.notify("Нет персонажа", TK.C.dg, 1.5) return end
  local m = Instance.new("Model")
  m.Name = "RM_Drone"
  local pos = hr.Position + TK.V3(0, 5, 0)
  TK.apart(m, "Body", TK.V3(1.6, .5, 1.6), TK.RGB(50, 56, 70), CFrame.new(pos), Enum.Material.Metal)
  local eye = TK.apart(m, "Eye", TK.V3(.5, .5, .5), TK.C.ac3, CFrame.new(pos), Enum.Material.Neon, Enum.PartType.Ball)
  TK.I("PointLight", { Color = TK.C.ac3, Range = 12, Brightness = 1.5, Shadows = false }, eye)
  DR.rotors = {}
  for i = 1, 4 do
    DR.rotors[i] = TK.apart(m, "Rotor", TK.V3(.1, 1.2, 1.2), TK.RGB(190, 200, 215), CFrame.new(pos), Enum.Material.Metal, Enum.PartType.Cylinder, .35)
  end
  m.Parent = droneF
  DR.m, DR.on, DR.pos, DR.yaw, DR.mode, DR.keys, DR.rot = m, true, pos, 0, "follow", {}, 0
  local function key(k) return function() DR.keys[k] = true if k ~= "up" and k ~= "dn" then DR.mode = "free" end end, function() DR.keys[k] = false end end
  local function B(txt, k) local d, u = key(k) return { txt, d, u } end
  TK.padShow("drone", {
    B("↑ вперёд", "fw"), B("↓ назад", "bk"), B("⟲ влево", "tl"), B("⟳ вправо", "tr"), B("▲ выше", "up"), B("▼ ниже", "dn"),
    { "👁 вид дрона", function() droneView(not DR.view) end },
    { "🏠 вернуть", function() DR.mode = "follow" droneView(false) end },
    { "⏹ выкл", function() droneOff() end },
  })
  TK.notify("🛸 Дрон: кнопки слева (двигай за ⠿)", TK.C.ac3, 2)
end
TK.tick("drone", 60, function(dt)
  if not DR.on or not DR.m then return end
  local hr = myRoot()
  if not hr or not TK.enDrain(2, dt) then droneOff() return end
  DR.rot = DR.rot + dt * 40
  local sp, H = TK.ST.DroneSpeed, TK.ST.DroneHeight
  if DR.mode == "follow" then
    local tgt = hr.Position + TK.V3(0, H, 0) + hr.CFrame.LookVector * -6
    DR.pos = DR.pos:Lerp(tgt, math.min(1, dt * 2.5))
    DR.yaw = math.atan2(-hr.CFrame.LookVector.X, -hr.CFrame.LookVector.Z)
  else
    if DR.keys.tl then DR.yaw = DR.yaw + dt * 1.8 end
    if DR.keys.tr then DR.yaw = DR.yaw - dt * 1.8 end
    local fwd = TK.V3(-math.sin(DR.yaw), 0, -math.cos(DR.yaw))
    local mv = TK.V3()
    if DR.keys.fw then mv = mv + fwd end
    if DR.keys.bk then mv = mv - fwd end
    if DR.keys.up then mv = mv + TK.V3(0, .8, 0) end
    if DR.keys.dn then mv = mv - TK.V3(0, .8, 0) end
    local np = DR.pos + mv * sp * dt
    if (np - hr.Position).Magnitude < 400 then DR.pos = np end -- дрон не улетает дальше 400 ст.
    local gy = TK.groundAt(DR.pos)
    if gy and DR.pos.Y < gy + 2 then DR.pos = TK.V3(DR.pos.X, gy + 2, DR.pos.Z) end
  end
  local cf = CFrame.new(DR.pos) * CFrame.Angles(0, DR.yaw, 0)
  pcall(function()
    for _, p in ipairs(DR.m:GetChildren()) do
      if p.Name == "Body" then p.CFrame = cf elseif p.Name == "Eye" then p.CFrame = cf * CFrame.new(0, -.1, -.9) end
    end
    for i, r in ipairs(DR.rotors) do
      local a = math.rad((i - 1) * 90 + 45)
      r.CFrame = cf * CFrame.new(math.cos(a) * 1.1, .35, math.sin(a) * 1.1) * CFrame.Angles(0, math.rad(DR.rot * (i % 2 == 0 and 1 or -1)), math.rad(90))
    end
  end)
  if DR.view then
    local cam = TK.Workspace.CurrentCamera
    if cam then
      cam.CameraType = Enum.CameraType.Scriptable
      cam.CFrame = cf * CFrame.new(0, .5, -1.2)
    end
  end
end)
TK.onRespawn(function() if DR.on then droneOff(true) end end)
TK.onUnload(function() droneOff(true) droneView(false) end)
TK.regSys({
  n = 19, name = "Разведывательный дрон", tab = "robots", mode = "visual",
  note = "Видит только твою сцену с твоего клиента; для наблюдения за игроками не предназначен.", keys = "дрон полёт камера разведка",
  get = function() return DR.on end, set = function(v) if v then droneOn() else droneOff() end end,
})
TK.sect("robots", function(f)
  TK.newSec(f, "СИСТЕМА 19 · РАЗВЕДЫВАТЕЛЬНЫЙ ДРОН")
  TK.newToggle(f, "🛸 Дрон", function() return DR.on end, function(v) if v then droneOn() else droneOff() end end)
  TK.newNum(f, "💨 Скорость", "DroneSpeed", 10)
  TK.newNum(f, "⬆ Высота следования", "DroneHeight", 2, nil, " ст.")
  TK.newInfo(f, "\n  Режимы: следует за тобой / ручной полёт кнопками слева.\n  «👁 вид дрона» — камера из дрона; «🏠» — вернуть и посадить.\n  Расход 2 энергии/с. При смерти выключается.", 76)
end)

-- ============================================================
--  СИСТЕМА 7: АВТОПИЛОТ КОРАБЛЯ  /  СИСТЕМА 21: ЗАПИСЬ МАРШРУТОВ
-- ============================================================
TK.AP = { wp = {}, idx = 1, active = false, paused = false, rec = false, recBuf = {}, recAcc = 0, viewF = nil }
local AP = TK.AP
function TK.apControl(md, vy, dt) -- вызывается из stepShip; ручное управление всегда главнее
  if not AP.active then return md, vy end
  if md.Magnitude > .15 or vy ~= 0 then
    AP.active = false
    TK.notify("🛩 Автопилот отключён: ручное управление", TK.C.ac2, 1.6)
    return md, vy
  end
  if AP.paused or not TK.ship then return TK.V3(), 0 end
  local wp = AP.wp[AP.idx]
  if not wp then
    AP.active = false
    TK.notify("🛩 Маршрут завершён", TK.C.ac, 1.6)
    return TK.V3(), 0
  end
  local p = TK.ship.pos
  local flat = TK.V3(wp.X - p.X, 0, wp.Z - p.Z)
  local dy = wp.Y - p.Y
  if flat.Magnitude < 10 and math.abs(dy) < 8 then
    AP.idx = AP.idx + 1
    return TK.V3(), 0
  end
  local m = flat.Magnitude > 1 and flat.Unit * math.min(1, flat.Magnitude / 40) or TK.V3()
  return m, math.clamp(dy / 12, -1, 1)
end
function TK.apAddWp()
  local pos = TK.aimHit(1000, 300)
  local gy = TK.groundAt(pos) or pos.Y
  AP.wp[#AP.wp + 1] = TK.V3(pos.X, math.max(pos.Y, gy) + 25, pos.Z)
  TK.notify("🛩 Точка маршрута " .. #AP.wp, TK.C.ac3, 1.2)
end
function TK.apAddPoint()
  local pt = TK.DB.points[CO.sel]
  if not pt then TK.notify("Нет выбранной сохранённой точки", TK.C.dg, 1.4) return end
  AP.wp[#AP.wp + 1] = TK.V3(pt.x, pt.y + 25, pt.z)
  TK.notify("🛩 Добавлена точка: " .. pt.name, TK.C.ac3, 1.2)
end
function TK.apStart()
  if not TK.ship or not TK.RIDING then TK.notify("Сядь в крейсер (вкладка «Корабль»)", TK.C.dg, 1.8) return end
  if #AP.wp == 0 then TK.notify("Добавь точки маршрута", TK.C.dg, 1.5) return end
  AP.active, AP.paused, AP.idx = true, false, 1
  TK.notify("🛩 Автопилот: старт", TK.C.ac, 1.5)
end
function TK.apStop() AP.active, AP.paused = false, false TK.notify("🛩 Автопилот остановлен", TK.C.tx, 1.2) end
function TK.apInd()
  local s = TK.ship
  if not s or not s.pos then return "  корабль не вызван" end
  local alt = s.pos.Y - (TK.groundAt(s.pos) or s.pos.Y)
  local deg = (math.deg(s.yaw or 0) % 360)
  local dirs = { "С", "СЗ", "З", "ЮЗ", "Ю", "ЮВ", "В", "СВ" }
  local d = dirs[math.floor(((deg + 22.5) % 360) / 45) + 1]
  return string.format("  скорость %.0f · высота %.0f · курс %s (%.0f°)", s.vel and s.vel.Magnitude or 0, alt, d, deg)
end
-- запись маршрутов (21)
TK.tick("routerec", 4, function(dt)
  if not AP.rec then return end
  if not TK.ship or not TK.RIDING then return end
  if #AP.recBuf >= 300 then AP.rec = false TK.notify("🎥 Запись: лимит 300 точек", TK.C.dg, 2) return end
  local p = TK.ship.pos
  AP.recBuf[#AP.recBuf + 1] = { p.X, p.Y, p.Z, TK.ship.yaw or 0 }
end)
local routeViewF = folder("RoutePreview")
local function routeShow(r)
  for _, c in ipairs(routeViewF:GetChildren()) do c:Destroy() end
  local n = #r.pts
  local step = math.max(1, math.floor(n / 60))
  for i = 1, n, step do
    local q = r.pts[i]
    TK.apart(routeViewF, "Bead", TK.V3(1.2, 1.2, 1.2), TK.C.ac3, CFrame.new(q[1], q[2], q[3]), Enum.Material.Neon, Enum.PartType.Ball, .3)
  end
  task.delay(15, function() for _, c in ipairs(routeViewF:GetChildren()) do pcall(function() c:Destroy() end) end end)
end
AP.rsel = 1
TK.onUnload(function() AP.active, AP.rec = false, false end)
TK.regSys({
  n = 7, name = "Автопилот космического корабля", tab = "ship", mode = "visual",
  note = "Двигает только твой локальный крейсер; любое ручное управление отключает автопилот.", keys = "автопилот маршрут корабль курс",
  get = function() return AP.active end, set = function(v) if v then TK.apStart() else TK.apStop() end end,
})
TK.regSys({
  n = 21, name = "Запись маршрутов корабля", tab = "ship", mode = "visual",
  note = "Пишет только положение твоего крейсера (до 300 точек, 5 маршрутов).", keys = "запись маршрут повтор корабль",
  get = function() return AP.rec end, set = function(v) AP.rec = v if v then AP.recBuf = {} end end,
})
TK.sect("ship", function(f)
  TK.newSec(f, "СИСТЕМА 7 · АВТОПИЛОТ")
  TK.newStatus(f, function()
    return TK.apInd() .. "\n  Маршрут: " .. #AP.wp .. " точек · " .. (AP.active and (AP.paused and "пауза" or ("в пути → " .. AP.idx)) or "стоит")
  end, 44)
  TK.newBtn(f, "➕ Точка маршрута (куда смотришь)", TK.C.bg2, TK.apAddWp, 32)
  TK.newBtn(f, "➕ Точка из сохранённых координат", TK.C.bg2, TK.apAddPoint, 32)
  local og = TK.newGrid(f, 3)
  TK.newBtn(og, "▶ Старт", TK.C.ac, TK.apStart, 32)
  TK.newBtn(og, "⏸ Пауза", TK.C.bg2, function() if AP.active then AP.paused = not AP.paused end end, 32)
  TK.newBtn(og, "⏹ Стоп", TK.C.bg2, TK.apStop, 32)
  TK.newBtn(f, "🗑 Очистить маршрут", TK.C.bg2, function() AP.wp = {} AP.active = false end, 30)
  TK.newSec(f, "СИСТЕМА 21 · ЗАПИСЬ МАРШРУТОВ")
  TK.newToggle(f, "🎥 Запись (пока ты в крейсере)", function() return AP.rec end, function(v)
    if v then AP.recBuf = {} AP.rec = true
    else
      AP.rec = false
      if #AP.recBuf >= 2 then
        if #TK.DB.routes >= 5 then table.remove(TK.DB.routes, 1) end
        TK.DB.routes[#TK.DB.routes + 1] = { name = "Маршрут " .. os.date("%H:%M:%S"), pts = AP.recBuf }
        AP.rsel = #TK.DB.routes
        TK.dbSave()
        TK.notify("🎥 Маршрут сохранён (" .. #AP.recBuf .. " точек)", TK.C.ac, 1.8)
      end
    end
  end, 32)
  TK.newStatus(f, function()
    local r = TK.DB.routes[AP.rsel]
    local base = AP.rec and ("  ● идёт запись: " .. #AP.recBuf .. " / 300\n") or ""
    if not r then return base .. "  Сохранённых маршрутов: 0 / 5" end
    return base .. "  [" .. AP.rsel .. "/" .. #TK.DB.routes .. "] " .. r.name .. " · " .. #r.pts .. " точек"
  end, 44)
  TK.newBtn(f, "▶ Следующий маршрут", TK.C.bg2, function() if #TK.DB.routes > 0 then AP.rsel = AP.rsel % #TK.DB.routes + 1 end end, 30)
  TK.newBtn(f, "👁 Показать трассу (15 с)", TK.C.bg2, function() local r = TK.DB.routes[AP.rsel] if r then routeShow(r) end end, 30)
  TK.newBtn(f, "🔁 Повторить маршрут (автопилот)", TK.C.bg2, function()
    local r = TK.DB.routes[AP.rsel]
    if not r then TK.notify("Нет маршрута", TK.C.dg, 1.2) return end
    AP.wp = {}
    for i, q in ipairs(r.pts) do
      if i % 3 == 1 or i == #r.pts then AP.wp[#AP.wp + 1] = TK.V3(q[1], q[2], q[3]) end
    end
    TK.apStart()
  end, 32)
  TK.newBtn(f, "🗑 Удалить маршрут", TK.C.bg2, function()
    if TK.DB.routes[AP.rsel] then
      table.remove(TK.DB.routes, AP.rsel)
      AP.rsel = math.max(1, math.min(AP.rsel, #TK.DB.routes))
      TK.dbSave()
    end
  end, 30)
end)

-- ============================================================
--  СИСТЕМА 24: МАШИНА КЛОНИРОВАНИЯ (визуальные копии только собственной тестовой модели)
-- ============================================================
local cloneF = folder("Clones")
local CM = { m = nil, pos = nil, clones = {}, busy = false, prog = 0, skin = 1, t = 0 }
local function cmBuild()
  if CM.m then pcall(function() CM.m:Destroy() end) end
  local pos = TK.aimHit(40)
  local gy = TK.groundAt(pos) or pos.Y
  CM.pos = TK.V3(pos.X, gy, pos.Z)
  local m = Instance.new("Model")
  m.Name = "RM_CloneMachine"
  local cf = CFrame.new(CM.pos)
  TK.apart(m, "Base", TK.V3(6, .6, 6), TK.RGB(40, 44, 54), cf * CFrame.new(0, .3, 0), Enum.Material.Metal)
  TK.apart(m, "Cap", TK.V3(6, 4.4, 4.4), TK.RGB(150, 230, 190), cf * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Glass, Enum.PartType.Cylinder, .6)
  TK.apart(m, "Top", TK.V3(.6, 5, 5), TK.RGB(70, 80, 95), cf * CFrame.new(0, 6.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  for _, s in ipairs({ -1, 1 }) do
    TK.apart(m, "Tube", TK.V3(.4, 4, .4), TK.C.ac, cf * CFrame.new(s * 3.2, 3, 0), Enum.Material.Neon, nil, .4)
    TK.apart(m, "Pipe", TK.V3(.5, .5, 3), TK.RGB(100, 110, 125), cf * CFrame.new(s * 3.2, 5.5, 1.2), Enum.Material.Metal)
  end
  CM.glow = TK.apart(m, "Glow", TK.V3(3, 3, 3), TK.C.ac, cf * CFrame.new(0, 3.2, 0), Enum.Material.Neon, Enum.PartType.Ball, 1)
  TK.I("PointLight", { Color = TK.C.ac, Range = 16, Brightness = 1.5, Shadows = false }, CM.glow)
  CM.lbl = TK.billboard(CM.glow, "🧬 ожидание", TK.C.ac)
  CM.lbl.Parent.StudsOffset = TK.V3(0, 5, 0)
  m.Parent = cloneF
  CM.m = m
  TK.burst(CM.pos, TK.C.ac, 18)
end
function TK.cloneStart()
  if not CM.m or not CM.m.Parent then TK.notify("Сначала поставь машину", TK.C.dg, 1.5) return end
  if CM.busy then return end
  for i = #CM.clones, 1, -1 do if not CM.clones[i].Parent then table.remove(CM.clones, i) end end
  if #CM.clones >= TK.ST.CloneLimit then TK.notify("Лимит клонов: " .. TK.ST.CloneLimit, TK.C.dg, 1.5) return end
  if not TK.enUse(12, "клон-машина") then return end
  CM.busy, CM.prog = true, 0
end
function TK.cloneClear()
  for i = #CM.clones, 1, -1 do pcall(function() CM.clones[i]:Destroy() end) CM.clones[i] = nil end
end
TK.tick("clonemachine", 15, function(dt)
  if not CM.m or not CM.m.Parent then return end
  CM.t = CM.t + dt
  pcall(function()
    CM.glow.Transparency = CM.busy and (.3 + .2 * math.sin(CM.t * 10)) or 1
  end)
  if CM.busy then
    CM.prog = CM.prog + dt / 4
    pcall(function() CM.lbl.Text = "🧬 клонирование " .. math.floor(CM.prog * 100) .. "%" end)
    if CM.prog >= 1 then
      CM.busy = false
      pcall(function() CM.lbl.Text = "🧬 готово" end)
      local id = TK.SKIN_ORDER[CM.skin]
      local ok, mdl = pcall(TK.skinModel, TK.SK[id])
      if ok and mdl then
        mdl.Name = "RM_CloneModel"
        local a = #CM.clones * 1.4 + 1
        mdl:PivotTo(CFrame.new(CM.pos + TK.V3(math.cos(a) * 8, 3, math.sin(a) * 8)) * CFrame.Angles(0, -a, 0))
        mdl.Parent = cloneF
        CM.clones[#CM.clones + 1] = mdl
        TK.burst(CM.pos + TK.V3(0, 3, 0), TK.C.ac, 22)
      end
    end
  else
    pcall(function() CM.lbl.Text = "🧬 клонов: " .. #CM.clones .. " / " .. TK.ST.CloneLimit end)
  end
end)
TK.onUnload(function()
  TK.cloneClear()
  if CM.m then pcall(function() CM.m:Destroy() end) end
end)
TK.regSys({
  n = 24, name = "Машина клонирования", tab = "robots", mode = "visual",
  note = "Делает визуальные копии только собственной тестовой модели скина; игроков и NPC игры не клонирует.", keys = "клон машина капсула копия",
  get = function() return CM.m ~= nil and CM.m.Parent ~= nil end, set = function(v) if v then cmBuild() else TK.cloneClear() if CM.m then CM.m:Destroy() CM.m = nil end end end,
})
TK.sect("robots", function(f)
  TK.newSec(f, "СИСТЕМА 24 · МАШИНА КЛОНИРОВАНИЯ")
  TK.newBtn(f, "🧬 Поставить машину (куда смотришь)", TK.C.ac, cmBuild, 34)
  local sb
  sb = TK.newBtn(f, "", TK.C.bg2, function() CM.skin = CM.skin % #TK.SKIN_ORDER + 1 end, 30)
  TK.addRefresh(function() sb.Text = "👤 Копируем модель: " .. TK.SK[TK.SKIN_ORDER[CM.skin]].name end)
  sb.Text = "👤 Копируем модель: " .. TK.SK[TK.SKIN_ORDER[CM.skin]].name
  TK.newBtn(f, "▶ Запустить цикл (12 энергии)", TK.C.bg2, TK.cloneStart, 32)
  TK.newBtn(f, "🗑 Удалить клонов", TK.C.bg2, TK.cloneClear, 30)
  TK.newNum(f, "🔢 Лимит клонов", "CloneLimit", 1)
  TK.newInfo(f, "\n  Копия — статичная тестовая модель. Оригиналов не удаляет.", 40)
end)

-- ============================================================
--  СИСТЕМА 13: ЛОКАЛЬНОЕ СОХРАНЕНИЕ
-- ============================================================
function TK.saveAll()
  TK.save()
  TK.dbSave()
end
function TK.resetData()
  TK.DB = { points = {}, routes = {}, gadgets = {} }
  TK.dbSave()
  markerRebuild()
end
TK.regSys({
  n = 13, name = "Локальное сохранение", tab = "settings", mode = "test",
  note = "Нужны writefile/readfile/isfile; без них настройки живут только до конца сессии.", keys = "сохранение настройки файл json",
  get = function() return TK.HAS_FS end, set = function(v) if v then TK.saveAll() end end,
  avail = function() if TK.HAS_FS then return true end return false, "нет writefile/readfile (настройки только на сессию)" end,
})
TK.sect("settings", function(f)
  TK.newSec(f, "СИСТЕМА 13 · ЛОКАЛЬНОЕ СОХРАНЕНИЕ")
  TK.newStatus(f, function()
    return (TK.HAS_FS and "  💾 Файловые функции есть: настройки в " .. TK.FILE .. ",\n  точки/маршруты/гаджеты в " .. TK.DBFILE
      or "  ⚠ Нет writefile/readfile/isfile: всё хранится ТОЛЬКО до конца сессии.") ..
      (TK.MIGRATED and "\n  ♻ Подхвачены совместимые настройки старого " .. TK.OLD_FILE or "")
  end, 62)
  TK.newBtn(f, "💾 Сохранить всё сейчас", TK.C.ac, function() TK.saveAll() TK.notify(TK.HAS_FS and "💾 Сохранено" or "💾 Только в памяти (нет файловых функций)", TK.C.ac, 1.6) end, 34)
  TK.newBtn(f, "📥 Перечитать файл данных", TK.C.bg2, function() TK.dbLoad() markerRebuild() TK.notify("📥 Данные перечитаны", TK.C.ac3, 1.4) end, 32)
  TK.newBtn(f, "🧹 Стереть точки, маршруты и конфиги", TK.C.dg, function() TK.resetData() TK.notify("🧹 Данные стёрты", TK.C.tx, 1.4) end, 32)
end)

RM._part4 = true
