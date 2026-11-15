-- ============================================================
--  Rick & Morty Toolkit v6.0 — ЧАСТЬ 3/5: энергия и устройства
--  Системы: 10 энергосистема, 20 генератор, 6 щит, 22 купол, 9 ранец, 5 гравиманипулятор,
--  14 уменьшитель, 23 механическая рука, 17 гравизоны, 16 конструктор, 15 голопроектор
--  Всё локально и визуально: сервер этого не видит, чужих игроков и объекты игры не трогаем.
-- ============================================================
local G = rawget(_G, "getgenv") and getgenv() or _G
local RM = G.RickMorty
local TK = RM and RM._TK
if not TK or not RM._part2 then error("[RickMorty] часть 3 запущена без частей 1–2") end

local SF = TK.sysFolder
local function folder(name)
  local f = Instance.new("Folder")
  f.Name = "RM_" .. name
  f.Parent = SF
  return f
end
function TK.apart(parent, name, size, color, cf, mat, shape, tr)
  local p = TK.mkp(name, size, color, mat, shape)
  p.Anchored = true
  p.CFrame = cf
  p.Transparency = tr or 0
  p.Parent = parent
  return p
end
function TK.aimRay(maxd)
  local d, o = RM.getAimDirection()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { TK.LP.Character, TK.ship and TK.ship.model }
  return TK.Workspace:Raycast(o, d * maxd, rp), d, o
end
function TK.billboard(adornee, text, col, w, h)
  local bb = TK.I("BillboardGui", {
    Size = UDim2.fromOffset(w or 110, h or 22), StudsOffset = TK.V3(0, 3, 0), AlwaysOnTop = true, LightInfluence = 0,
    MaxDistance = 120,
  }, adornee)
  local l = TK.I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = TK.C.bg, BackgroundTransparency = .35, Text = text,
    TextColor3 = col or TK.C.ac, Font = Enum.Font.GothamBold, TextSize = 12,
  }, bb)
  TK.cr(l, 6)
  return l
end

-- ---------- респавн/смерть: все устройства безопасно отключаются ----------
TK.charHooks = {}
function TK.onRespawn(fn) TK.charHooks[#TK.charHooks + 1] = fn end
local function bindChar(ch)
  local hum = ch:WaitForChild("Humanoid", 5)
  if hum then
    TK.track(hum.Died:Connect(function()
      for _, fn in ipairs(TK.charHooks) do pcall(fn, "died") end
    end))
  end
  for _, fn in ipairs(TK.charHooks) do pcall(fn, "spawn") end
end
TK.track(TK.LP.CharacterAdded:Connect(function(ch) task.spawn(bindChar, ch) end))
if TK.LP.Character then task.spawn(bindChar, TK.LP.Character) end

-- ---------- мобильная панель кнопок (перетаскивается за ⠿) ----------
TK.pad = TK.I("Frame", {
  Name = "RM_Pad", Size = UDim2.fromOffset(66, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 8, .3, 0),
  BackgroundTransparency = 1, ZIndex = 30, Visible = false,
}, TK.gui)
TK.I("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, TK.pad)
do
  local h = TK.I("TextButton", {
    Size = UDim2.fromOffset(66, 18), BackgroundColor3 = TK.C.bg, BackgroundTransparency = .3, Text = "⠿ двигай",
    TextColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 9, ZIndex = 31, LayoutOrder = -1,
  }, TK.pad)
  TK.cr(h, 6)
  TK.drag(TK.pad, h)
end
TK.padGroups = {}
function TK.padHide(id)
  local g = TK.padGroups[id]
  if g then pcall(function() g:Destroy() end) end
  TK.padGroups[id] = nil
  local any = false
  for _ in pairs(TK.padGroups) do any = true end
  TK.pad.Visible = any
end
-- list = { {текст, onDown, onUp}, ... }: кнопки с удержанием
function TK.padShow(id, list)
  TK.padHide(id)
  local g = TK.I("Frame", { Size = UDim2.fromOffset(66, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 30 }, TK.pad)
  TK.I("UIListLayout", { Padding = UDim.new(0, 4) }, g)
  for _, it in ipairs(list) do
    local b = TK.I("TextButton", {
      Size = UDim2.fromOffset(66, 42), BackgroundColor3 = TK.C.st, BackgroundTransparency = .15, Text = it[1],
      TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true, ZIndex = 31,
    }, g)
    TK.cr(b, 10)
    TK.sk(b, TK.C.ac, 1, .4)
    local down = false
    b.InputBegan:Connect(function(i)
      if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        down = true
        if it[2] then TK.safe(it[2]) end
        i.Changed:Connect(function()
          if i.UserInputState == Enum.UserInputState.End and down then
            down = false
            if it[3] then TK.safe(it[3]) end
          end
        end)
      end
    end)
  end
  TK.padGroups[id] = g
  TK.pad.Visible = true
end
TK.onUnload(function() for id in pairs(TK.padGroups) do TK.padHide(id) end pcall(function() TK.pad:Destroy() end) end)

-- ---------- локальная база: точки, маршруты, конфиги гаджетов ----------
TK.DBFILE = "rickmorty_v6_data.json"
TK.DB = { points = {}, routes = {}, gadgets = {} }
local function fin(n) return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge end
function TK.dbSanitize(d)
  local out = { points = {}, routes = {}, gadgets = {} }
  if type(d) ~= "table" then return out end
  if type(d.points) == "table" then
    for _, p in ipairs(d.points) do
      if #out.points >= 20 then break end
      if type(p) == "table" and type(p.name) == "string" and #p.name <= 24 and fin(p.x) and fin(p.y) and fin(p.z) then
        out.points[#out.points + 1] = { name = p.name, x = p.x, y = p.y, z = p.z }
      end
    end
  end
  if type(d.routes) == "table" then
    for _, r in ipairs(d.routes) do
      if #out.routes >= 5 then break end
      if type(r) == "table" and type(r.name) == "string" and #r.name <= 24 and type(r.pts) == "table" then
        local pts = {}
        for _, q in ipairs(r.pts) do
          if #pts >= 300 then break end
          if type(q) == "table" and fin(q[1]) and fin(q[2]) and fin(q[3]) and fin(q[4] or 0) then
            pts[#pts + 1] = { q[1], q[2], q[3], q[4] or 0 }
          end
        end
        if #pts >= 2 then out.routes[#out.routes + 1] = { name = r.name, pts = pts } end
      end
    end
  end
  if type(d.gadgets) == "table" then
    for _, g in ipairs(d.gadgets) do
      if #out.gadgets >= 8 then break end
      if type(g) == "table" and math.floor(tonumber(g.body) or 0) >= 1 and math.floor(tonumber(g.body) or 0) <= 3
        and math.floor(tonumber(g.deco) or 0) >= 1 and math.floor(tonumber(g.deco) or 0) <= 4
        and TK.COL[g.core] and TK.COL[g.color] then
        out.gadgets[#out.gadgets + 1] = { body = math.floor(g.body), deco = math.floor(g.deco), core = g.core, color = g.color }
      end
    end
  end
  return out
end
function TK.dbLoad()
  if not TK.HAS_FS then return end
  pcall(function()
    if isfile(TK.DBFILE) then
      TK.DB = TK.dbSanitize(TK.HttpService:JSONDecode(readfile(TK.DBFILE)))
    end
  end)
end
function TK.dbSave()
  if TK.HAS_FS then pcall(writefile, TK.DBFILE, TK.HttpService:JSONEncode(TK.DB)) end
end
TK.dbLoad()

-- ============================================================
--  СИСТЕМА 10: ОБЩАЯ ЭНЕРГОСИСТЕМА
-- ============================================================
TK.EN.cur = TK.ST.EnergyMax
TK.X.hudOn = true
TK.hud = TK.I("Frame", {
  Name = "RM_Hud", Size = UDim2.fromOffset(150, 20), AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 4),
  BackgroundColor3 = TK.C.bg, BackgroundTransparency = .25, ZIndex = 20,
}, TK.gui)
TK.cr(TK.hud, 8)
TK.sk(TK.hud, TK.C.ac, 1, .5)
TK.hudFill = TK.I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = TK.C.ac, BorderSizePixel = 0, ZIndex = 21 }, TK.hud)
TK.cr(TK.hudFill, 8)
TK.hudTxt = TK.I("TextLabel", {
  Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", TextColor3 = TK.BLACK, Font = Enum.Font.GothamBold,
  TextSize = 11, ZIndex = 22,
}, TK.hud)
function TK.enPaint()
  local f = TK.EN.cur / TK.ST.EnergyMax
  TK.hudFill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
  local over = TK.enOverloaded()
  TK.hudFill.BackgroundColor3 = over and TK.C.dg or (f < .2 and TK.RGB(255, 190, 70) or TK.C.ac)
  TK.hudTxt.Text = (over and "⚡ ПЕРЕГРУЗКА" or ("⚡ " .. math.floor(TK.EN.cur) .. " / " .. TK.ST.EnergyMax))
  TK.hudTxt.TextColor3 = over and TK.WHITE or TK.BLACK
  TK.hud.Visible = TK.X.hudOn
end
TK.tick("energy", 10, function(dt)
  TK.EN.cur = math.min(TK.EN.cur, TK.ST.EnergyMax)
  if not TK.enOverloaded() then TK.enAdd(TK.ST.EnergyRegen * dt * .5) end -- базовое восстановление: половина от настройки/с
  if TK.EN.cur < TK.ST.EnergyMax * .2 and os.clock() - TK.EN.warned > 30 and not TK.enOverloaded() then
    TK.EN.warned = os.clock()
    TK.notify("⚠ Низкий заряд энергии", TK.RGB(255, 190, 70), 2)
  end
  TK.enPaint()
end)
TK.regSys({
  n = 10, name = "Общая энергосистема", tab = "energy", mode = "visual",
  note = "Запас энергии только внутри Toolkit; экономики игры не касается.", keys = "энергия заряд перегрузка ёмкость",
  get = function() return TK.X.hudOn end, set = function(v) TK.X.hudOn = v TK.enPaint() end,
})
TK.sect("energy", function(f)
  TK.newSec(f, "СИСТЕМА 10 · ОБЩАЯ ЭНЕРГИЯ")
  TK.newStatus(f, function()
    return "  ⚡ " .. math.floor(TK.EN.cur) .. " / " .. TK.ST.EnergyMax .. (TK.enOverloaded() and "  — ПЕРЕГРУЗКА, восстановление…" or "") ..
      "\n  Расходуют: щит, купол, ранец, гравиманипулятор, зоны, рука.\n  Пополняют: восстановление и генераторы."
  end, 62)
  TK.newToggle(f, "📊 Полоска энергии на экране", function() return TK.X.hudOn end, function(v) TK.X.hudOn = v TK.enPaint() end)
  TK.newNum(f, "🔋 Макс. ёмкость", "EnergyMax", 25, function() TK.EN.cur = math.min(TK.EN.cur, TK.ST.EnergyMax) end)
  TK.newNum(f, "♻ Скорость восстановления", "EnergyRegen", 1, nil, " /с")
  TK.newBtn(f, "⚡ Заполнить до максимума", TK.C.bg2, function() TK.EN.cur = TK.ST.EnergyMax TK.EN.over = 0 TK.notify("⚡ Энергия полная", TK.C.ac, 1.2) end, 32)
  TK.newInfo(f, "\n  Только внутри Toolkit. Экономику и ресурсы игры не меняет.", 44)
end)

-- ============================================================
--  СИСТЕМА 20: ГЕНЕРАТОР ЭНЕРГИИ
-- ============================================================
local gens, genF = {}, folder("Gens")
local GEN_RATE, GEN_LIM = 3, 2
local function buildGen(pos)
  local m = Instance.new("Model")
  m.Name = "RM_Gen"
  local cf = CFrame.new(pos)
  TK.apart(m, "Base", TK.V3(3.2, .6, 3.2), TK.RGB(45, 50, 58), cf * CFrame.new(0, .3, 0), Enum.Material.Metal)
  TK.apart(m, "Tank", TK.V3(3.4, 2.4, 2.4), TK.RGB(70, 80, 92), cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  local core = TK.apart(m, "Core", TK.V3(1.6, 1.6, 1.6), TK.RGB(80, 255, 140), cf * CFrame.new(0, 1.8, 0), Enum.Material.Neon, Enum.PartType.Ball, .15)
  TK.I("PointLight", { Color = TK.RGB(80, 255, 140), Range = 14, Brightness = 2, Shadows = false }, core)
  TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = TK.fxRate(10), Lifetime = NumberRange.new(.8, 1.4),
    Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new(.5, 0), LightEmission = 1,
    Color = ColorSequence.new(TK.RGB(120, 255, 160)), Acceleration = TK.V3(0, 3, 0),
  }, core)
  local ring = TK.apart(m, "Ring", TK.V3(.3, 2.6, 2.6), TK.RGB(150, 90, 255), cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder, .2)
  local lbl = TK.billboard(core, "⚡ +" .. GEN_RATE .. "/с", TK.C.ac)
  m.Parent = genF
  return { m = m, core = core, ring = ring, lbl = lbl, cf = cf, t = 0 }
end
function TK.genAdd()
  if #gens >= GEN_LIM then TK.notify("Лимит генераторов: " .. GEN_LIM, TK.C.dg, 1.5) return end
  local pos = TK.aimHit(60)
  local gy = TK.groundAt(pos)
  gens[#gens + 1] = buildGen(TK.V3(pos.X, gy or pos.Y, pos.Z))
  TK.burst(pos, TK.RGB(80, 255, 140), 14)
  TK.notify("⚡ Генератор установлен", TK.C.ac, 1.5)
end
function TK.genClear()
  for i = #gens, 1, -1 do pcall(function() gens[i].m:Destroy() end) gens[i] = nil end
end
TK.tick("generators", 15, function(dt)
  for _, g in ipairs(gens) do
    g.t = g.t + dt
    local full = TK.EN.cur >= TK.ST.EnergyMax
    pcall(function()
      g.ring.CFrame = g.cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(g.t * 2, 0, math.rad(90))
      g.core.Size = TK.V3(1.6, 1.6, 1.6) * (1 + .06 * math.sin(g.t * 5))
      g.lbl.Text = full and "⚡ заряд полный" or ("⚡ +" .. GEN_RATE .. "/с")
    end)
    if not full then TK.enAdd(GEN_RATE * dt) end -- ограничено ёмкостью и скоростью
  end
end)
TK.onUnload(TK.genClear)
TK.regSys({
  n = 20, name = "Генератор энергии", tab = "energy", mode = "visual",
  note = "Пополняет только запас Toolkit.", keys = "генератор энергия ядро",
  get = function() return #gens > 0 end, set = function(v) if v then TK.genAdd() else TK.genClear() end end,
})
TK.sect("energy", function(f)
  TK.newSec(f, "СИСТЕМА 20 · ГЕНЕРАТОР ЭНЕРГИИ")
  TK.newBtn(f, "⚡ Поставить генератор (куда смотришь)", TK.C.ac, TK.genAdd, 36)
  TK.newBtn(f, "🗑 Убрать генераторы", TK.C.bg2, TK.genClear, 32)
  TK.newStatus(f, function() return "  Генераторов: " .. #gens .. " / " .. GEN_LIM .. "  (каждый +" .. GEN_RATE .. " энергии в секунду)" end, 28)
end)

-- ============================================================
--  СИСТЕМА 6: ЭНЕРГЕТИЧЕСКИЙ ЩИТ (визуальный, не неуязвимость)
-- ============================================================
local SH = { on = false, part = nil, untilT = 0, cd = 0, dev = nil }
local SH_DUR, SH_CD = 20, 8
local function shieldOff(quiet)
  if SH.part then
    local p = SH.part
    SH.part = nil
    pcall(function()
      TK.TweenService:Create(p, TweenInfo.new(.3), { Size = TK.V3(2, 2, 2), Transparency = 1 }):Play()
    end)
    task.delay(.35, function() pcall(function() p:Destroy() end) end)
  end
  if SH.dev then pcall(function() SH.dev:Destroy() end) SH.dev = nil end
  if SH.on and not quiet then
    SH.cd = os.clock() + SH_CD
    TK.notify("🛡 Щит выключен", TK.C.tx, 1.2)
  end
  SH.on = false
end
local function shieldOn()
  if SH.on then return end
  if os.clock() < SH.cd then TK.notify("🛡 Перезарядка " .. math.ceil(SH.cd - os.clock()) .. " с", TK.C.dg, 1.2) return end
  local _, _, hr = TK.getChar()
  if not hr then TK.notify("Нет персонажа", TK.C.dg, 1.5) return end
  if not TK.enUse(8, "щит") then return end
  local col = TK.colOf(TK.ST.ShieldColor)
  SH.part = TK.I("Part", {
    Name = "RM_ShieldG", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.ForceField, Color = col, Transparency = TK.ST.ShieldAlpha / 100,
    Size = TK.V3(2, 2, 2), CFrame = hr.CFrame,
  }, SF)
  TK.TweenService:Create(SH.part, TweenInfo.new(.35, Enum.EasingStyle.Back), { Size = TK.V3(9, 9, 9) }):Play()
  -- компактный генератор у ног
  local d = Instance.new("Model")
  d.Name = "RM_ShieldDev"
  TK.apart(d, "Pod", TK.V3(.8, .5, .8), TK.RGB(50, 56, 70), hr.CFrame * CFrame.new(1.8, -2.6, 0), Enum.Material.Metal, Enum.PartType.Cylinder)
  TK.apart(d, "Eye", TK.V3(.4, .4, .4), col, hr.CFrame * CFrame.new(1.8, -2.2, 0), Enum.Material.Neon, Enum.PartType.Ball)
  d.Parent = SF
  SH.dev = d
  SH.on, SH.untilT = true, os.clock() + SH_DUR
  TK.burst(hr.Position, col, 14)
  TK.snd("open", .3)
  TK.notify("🛡 Щит включён (визуальный)", col, 1.5)
end
TK.tick("shield", 20, function(dt)
  if not SH.on then return end
  local _, _, hr = TK.getChar()
  if not hr or not SH.part or os.clock() > SH.untilT or not TK.enDrain(3, dt) then shieldOff() return end
  pcall(function()
    SH.part.CFrame = hr.CFrame
    SH.part.Color = TK.colOf(TK.ST.ShieldColor)
    local left = SH.untilT - os.clock()
    SH.part.Transparency = TK.ST.ShieldAlpha / 100 + ((left < 3) and (math.floor(os.clock() * 8) % 2) * .25 or 0)
    SH.dev:PivotTo(hr.CFrame * CFrame.new(1.8, -2.4, 0))
  end)
end)
TK.onRespawn(function() shieldOff(true) end)
TK.onUnload(function() shieldOff(true) end)
TK.regSys({
  n = 6, name = "Энергетический щит", tab = "energy", mode = "visual",
  note = "Только визуальный купол: настоящей неуязвимости нет (нужна поддержка игры).", keys = "щит защита купол персональный",
  get = function() return SH.on end, set = function(v) if v then shieldOn() else shieldOff() end end,
})
TK.sect("energy", function(f)
  TK.newSec(f, "СИСТЕМА 6 · ЭНЕРГОЩИТ (визуальный)")
  TK.newToggle(f, "🛡 Щит", function() return SH.on end, function(v) if v then shieldOn() else shieldOff() end end)
  TK.newCycle(f, "🎨 Цвет", "ShieldColor", TK.COLLIST, TK.COLNAMES)
  TK.newNum(f, "👁 Прозрачность", "ShieldAlpha", 10, nil, "%")
  TK.newStatus(f, function()
    if SH.on then return "  🛡 работает ещё " .. math.max(0, math.ceil(SH.untilT - os.clock())) .. " с (расход 3 энергии/с)" end
    if os.clock() < SH.cd then return "  Перезарядка " .. math.ceil(SH.cd - os.clock()) .. " с" end
    return "  Готов. Включение: 8 энергии, длится до 20 с."
  end, 36)
  TK.newInfo(f, "\n  Только картинка вокруг тебя на твоём экране. Не защищает от урона.", 44)
end)

-- ============================================================
--  СИСТЕМА 22: ЗАЩИТНЫЙ КУПОЛ (большой, отдельный от щита)
-- ============================================================
local DM = { on = false, sphere = nil, gen = nil, pos = nil, t = 0, ring = nil, lbl = nil }
local function domeOff(quiet)
  local s, g = DM.sphere, DM.gen
  DM.sphere, DM.gen, DM.ring, DM.lbl = nil, nil, nil, nil
  if s then
    pcall(function() TK.TweenService:Create(s, TweenInfo.new(.5), { Size = TK.V3(2, 2, 2), Transparency = 1 }):Play() end)
    task.delay(.55, function() pcall(function() s:Destroy() end) end)
  end
  if g then pcall(function() g:Destroy() end) end
  if DM.on and not quiet then TK.notify("🏛 Купол свёрнут", TK.C.tx, 1.2) end
  DM.on = false
end
local function domeOn()
  if DM.on then return end
  if not TK.enUse(15, "купол") then return end
  local pos = TK.aimHit(60)
  local gy = TK.groundAt(pos) or pos.Y
  local base = TK.V3(pos.X, gy, pos.Z)
  local col = TK.colOf(TK.ST.DomeColor)
  local r = TK.ST.DomeRadius
  DM.pos = base
  DM.sphere = TK.I("Part", {
    Name = "RM_DomeG", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.ForceField, Color = col, Transparency = .5, Size = TK.V3(2, 2, 2), CFrame = CFrame.new(base),
  }, SF)
  TK.TweenService:Create(DM.sphere, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = TK.V3(2 * r, 2 * r, 2 * r) }):Play()
  local g = Instance.new("Model")
  g.Name = "RM_DomeGen"
  local cf = CFrame.new(base)
  TK.apart(g, "Base", TK.V3(4, .8, 4), TK.RGB(40, 44, 54), cf * CFrame.new(0, .4, 0), Enum.Material.Metal)
  TK.apart(g, "Pillar", TK.V3(3, 1.4, 1.4), TK.RGB(80, 90, 105), cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  local core = TK.apart(g, "Core", TK.V3(1.4, 1.4, 1.4), col, cf * CFrame.new(0, 3.2, 0), Enum.Material.Neon, Enum.PartType.Ball, .1)
  TK.I("PointLight", { Color = col, Range = 20, Brightness = 2, Shadows = false }, core)
  DM.ring = TK.apart(g, "Ring", TK.V3(.25, 3, 3), col, cf * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder, .3)
  DM.lbl = TK.billboard(core, "🏛 купол", col)
  g.Parent = SF
  DM.gen = g
  DM.core = core
  DM.on = true
  TK.burst(base, col, 24)
  TK.snd("open", .3, 1)
  TK.notify("🏛 Купол развёрнут (визуальный)", col, 1.5)
end
TK.tick("dome", 15, function(dt)
  if not DM.on then return end
  DM.t = DM.t + dt
  if not TK.enDrain(4, dt) then domeOff() return end
  pcall(function()
    DM.ring.CFrame = CFrame.new(DM.pos) * CFrame.new(0, 3.2, 0) * CFrame.Angles(DM.t * 1.6, 0, math.rad(90))
    DM.lbl.Text = "🏛 " .. math.floor(TK.EN.cur) .. "⚡"
    DM.sphere.Transparency = .5 + .08 * math.sin(DM.t * 2)
  end)
end)
TK.onUnload(function() domeOff(true) end)
TK.regSys({
  n = 22, name = "Защитный купол", tab = "energy", mode = "visual",
  note = "Только картинка; не защищает от урона без поддержки игры.", keys = "купол защита барьер",
  get = function() return DM.on end, set = function(v) if v then domeOn() else domeOff() end end,
})
TK.sect("energy", function(f)
  TK.newSec(f, "СИСТЕМА 22 · ЗАЩИТНЫЙ КУПОЛ (визуальный)")
  TK.newToggle(f, "🏛 Купол в точке прицела", function() return DM.on end, function(v) if v then domeOn() else domeOff() end end)
  TK.newNum(f, "↔ Радиус (при развёртывании)", "DomeRadius", 10, nil, " ст.")
  TK.newCycle(f, "🎨 Цвет", "DomeColor", TK.COLLIST, TK.COLNAMES)
  TK.newInfo(f, "\n  Расход 4 энергии/с, развёртывание 15. Радиус и цвет — при включении.", 44)
end)

-- ============================================================
--  СИСТЕМА 9: РЕАКТИВНЫЙ РАНЕЦ (локальный подъём собственного персонажа)
-- ============================================================
local JP = { on = false, up = false, down = false, model = nil, flames = {} }
local function jetOff(quiet)
  JP.up, JP.down = false, false
  if JP.model then pcall(function() JP.model:Destroy() end) JP.model = nil end
  JP.flames = {}
  TK.padHide("jet")
  if JP.on and not quiet then TK.notify("🎒 Ранец выключен", TK.C.tx, 1.2) end
  JP.on = false
end
local function jetOn()
  if JP.on then return end
  local ch, hum, hr = TK.getChar()
  if not hr or not hum or hum.Health <= 0 then TK.notify("Нет персонажа", TK.C.dg, 1.5) return end
  if TK.RIDING then TK.notify("Сначала слезь с корабля", TK.C.dg, 1.5) return end
  local m = Instance.new("Model")
  m.Name = "RM_Jetpack"
  local function weldPart(name, size, col, off, mat, shape)
    local p = TK.mkp(name, size, col, mat, shape)
    p.CFrame = hr.CFrame * off
    local w = Instance.new("Weld")
    w.Part0, w.Part1, w.C0 = hr, p, off
    w.Parent = p
    p.Parent = m
    return p
  end
  weldPart("Plate", TK.V3(1.6, 1.8, .4), TK.RGB(60, 66, 80), CFrame.new(0, .2, .9), Enum.Material.Metal)
  for _, s in ipairs({ -1, 1 }) do
    local t = weldPart("Tank", TK.V3(1.6, .7, .7), TK.RGB(150, 160, 175), CFrame.new(s * .5, .2, 1.35) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
    local n = weldPart("Nozzle", TK.V3(.3, .5, .5), TK.RGB(40, 40, 46), CFrame.new(s * .5, -.8, 1.35) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
    weldPart("Glow", TK.V3(.2, .4, .4), TK.RGB(110, 220, 255), CFrame.new(s * .5, -1.05, 1.35) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    local fl = TK.I("ParticleEmitter", {
      Texture = "rbxasset://textures/particles/fire_main.dds", Rate = TK.fxRate(40), Lifetime = NumberRange.new(.25, .5),
      Speed = NumberRange.new(10, 16), SpreadAngle = Vector2.new(8, 8), Size = NumberSequence.new(.7, 0), LightEmission = 1,
      Color = ColorSequence.new(TK.RGB(120, 220, 255), TK.RGB(255, 140, 50)), EmissionDirection = Enum.NormalId.Bottom, Enabled = false,
    }, n)
    JP.flames[#JP.flames + 1] = fl
  end
  m.Parent = ch
  JP.model, JP.on = m, true
  TK.padShow("jet", {
    { "⬆ вверх", function() JP.up = true end, function() JP.up = false end },
    { "⬇ вниз", function() JP.down = true end, function() JP.down = false end },
    { "⏹ выкл", function() jetOff() end },
  })
  TK.notify("🎒 Ранец включён · удерживай ⬆ (ПК: E / Q)", TK.C.ac, 2)
end
TK.track(TK.UIS.InputBegan:Connect(function(i, gpe)
  if gpe or not JP.on then return end
  if i.KeyCode == Enum.KeyCode.E then JP.up = true elseif i.KeyCode == Enum.KeyCode.Q then JP.down = true end
end))
TK.track(TK.UIS.InputEnded:Connect(function(i)
  if i.KeyCode == Enum.KeyCode.E then JP.up = false elseif i.KeyCode == Enum.KeyCode.Q then JP.down = false end
end))
TK.tick("jetpack", 60, function(dt)
  if not JP.on then return end
  local _, hum, hr = TK.getChar()
  if not hr or not hum or hum.Health <= 0 or TK.RIDING then jetOff() return end
  if not TK.enDrain(JP.up and 7 or 2.5, dt) then jetOff() return end
  local v = hr.AssemblyLinearVelocity
  local P = TK.ST.JetPower
  local target = JP.up and P or (JP.down and -P * .5 or 0) -- без кнопок: зависание
  local ny = v.Y + (target - v.Y) * math.min(1, dt * 5)
  hr.AssemblyLinearVelocity = TK.V3(v.X, ny, v.Z)
  for _, fl in ipairs(JP.flames) do fl.Enabled = JP.up end
end)
TK.onRespawn(function() jetOff(true) end)
TK.onUnload(function() jetOff(true) end)
TK.regSys({
  n = 9, name = "Реактивный ранец", tab = "gadgets", mode = "test",
  note = "Двигает только твоего персонажа на твоём клиенте; в играх с античитом может откатываться.", keys = "ранец полёт jetpack",
  get = function() return JP.on end, set = function(v) if v then jetOn() else jetOff() end end,
})
TK.sect("gadgets", function(f)
  TK.newSec(f, "СИСТЕМА 9 · РЕАКТИВНЫЙ РАНЕЦ")
  TK.newToggle(f, "🎒 Ранец", function() return JP.on end, function(v) if v then jetOn() else jetOff() end end)
  TK.newNum(f, "🚀 Сила тяги", "JetPower", 10)
  TK.newInfo(f, "\n  Кнопки ⬆ ⬇ появляются слева (двигай за ⠿). ПК: E / Q.\n  Расход: 2.5 энергии/с в зависании, 7/с при подъёме.\n  Выключается при смерти, респавне и выгрузке.", 76)
end)

-- ============================================================
--  ТЕСТОВЫЕ ОБЪЕКТЫ (props) — единственное, чем управляют гравитационные системы
-- ============================================================
local propF = folder("Props")
TK.props = {}
local PROP_LIM = 12
function TK.propsSpawn(n)
  local _, _, hr = TK.getChar()
  if not hr then return end
  local base = hr.Position + hr.CFrame.LookVector * 10
  for i = 1, n do
    if #TK.props >= PROP_LIM then TK.notify("Лимит тестовых объектов: " .. PROP_LIM, TK.C.dg, 1.5) break end
    local sph = (i % 2 == 0)
    local sz = 1.5 + (i % 3) * .5
    local p = TK.I("Part", {
      Name = "RM_Prop", Shape = sph and Enum.PartType.Ball or Enum.PartType.Block, Size = TK.V3(sz, sz, sz),
      Color = TK.colOf(TK.COLLIST[(i % 5) + 1]), Material = Enum.Material.SmoothPlastic, Anchored = false, CanCollide = true,
      CFrame = CFrame.new(base + TK.V3((i - 3) * 2.5, 6 + i, math.sin(i) * 3)),
    }, propF)
    p:SetAttribute("BaseSize", p.Size)
    TK.props[#TK.props + 1] = p
  end
end
function TK.propsClear()
  for i = #TK.props, 1, -1 do pcall(function() TK.props[i]:Destroy() end) TK.props[i] = nil end
end
function TK.propsLive()
  for i = #TK.props, 1, -1 do
    if not TK.props[i].Parent then table.remove(TK.props, i) end
  end
  return TK.props
end
TK.onUnload(TK.propsClear)

-- ============================================================
--  СИСТЕМА 5: ГРАВИТАЦИОННЫЙ МАНИПУЛЯТОР (только тестовые объекты Toolkit)
-- ============================================================
local GM = { mode = nil, held = nil }
local function gmStop() GM.mode, GM.held = nil, nil TK.padHide("grav") end
local function gmStart()
  TK.padShow("grav", {
    { "🧲 тянуть", function() GM.mode = "pull" end, function() GM.mode = nil end },
    { "💥 толкать", function() GM.mode = "push" end, function() GM.mode = nil end },
    { "✊ держать", function() GM.mode = "hold" end, function() GM.mode = nil GM.held = nil end },
  })
  GM.active = true
end
TK.tick("gravman", 30, function(dt)
  if not GM.active or not GM.mode then return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  if not TK.enDrain(4, dt) then GM.mode = nil return end
  local R, P = TK.ST.GravRadius, TK.ST.GravPower
  local front = hr.Position + hr.CFrame.LookVector * 7 + TK.V3(0, 1, 0)
  if GM.mode == "hold" then
    if not (GM.held and GM.held.Parent) then
      GM.held = nil
      local best, bd = nil, R
      local aim = TK.aimHit(R + 30)
      for _, p in ipairs(TK.propsLive()) do
        local d = (p.Position - aim).Magnitude
        if d < bd then best, bd = p, d end
      end
      GM.held = best
    end
    if GM.held then
      local cam = TK.Workspace.CurrentCamera
      local tgt = cam and (cam.CFrame.Position + cam.CFrame.LookVector * 9) or front
      local dv = (tgt - GM.held.Position)
      GM.held.AssemblyLinearVelocity = dv * 8
    end
    return
  end
  for _, p in ipairs(TK.propsLive()) do
    local off = p.Position - hr.Position
    if off.Magnitude <= R then
      if GM.mode == "pull" then
        p.AssemblyLinearVelocity = (front - p.Position).Unit * math.min(P, (front - p.Position).Magnitude * 6)
      else
        p.AssemblyLinearVelocity = off.Unit * P + TK.V3(0, P * .3, 0)
      end
    end
  end
end)
TK.onRespawn(function() if GM.active then gmStop() GM.active = false end end)
TK.onUnload(function() gmStop() GM.active = false end)
function TK.buildGravTool()
  local tool, h, P = TK.miniTool("Гравиманипулятор", "Притягивать / отталкивать тестовые объекты", TK.V3(.5, 1.1, .5), TK.RGB(50, 54, 66))
  P("Body", TK.V3(.9, .7, 1.4), TK.RGB(90, 96, 115), CFrame.new(0, .7, -.5), Enum.Material.Metal)
  P("Coil", TK.V3(.2, 1.1, 1.1), TK.RGB(170, 100, 255), CFrame.new(0, .7, -1.25) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  P("Coil2", TK.V3(.2, .8, .8), TK.RGB(110, 220, 255), CFrame.new(0, .7, -1.5) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  local core = P("Core", TK.V3(.4, .4, .4), TK.RGB(255, 255, 255), CFrame.new(0, 1.15, -.2), Enum.Material.Neon, Enum.PartType.Ball)
  TK.I("PointLight", { Color = TK.RGB(170, 100, 255), Range = 8, Brightness = 1.5, Shadows = false }, core)
  return tool
end
TK.GADGETS = {
  grav = { id = "g_grav", ico = "🧲", name = "Гравиманипулятор", desc = "Тянет/толкает тестовые объекты", build = TK.buildGravTool,
    act = function()
      if not GM.active then gmStart() TK.notify("🧲 Кнопки слева: тянуть / толкать / держать", TK.C.ac, 2.5) else gmStop() GM.active = false TK.notify("🧲 Выключен", TK.C.tx, 1) end
    end, grip = TK.V3(0, -.1, 0) },
}
TK.regSys({
  n = 5, name = "Гравитационный манипулятор", tab = "gadgets", mode = "test",
  note = "Двигает только тестовые объекты Toolkit, не игроков и не чужие объекты.", keys = "гравитация притяжение манипулятор",
  get = function() return GM.active end, set = function(v) if v then gmStart() else gmStop() GM.active = false end end,
})
TK.sect("gadgets", function(f)
  TK.newSec(f, "СИСТЕМА 5 · ГРАВИТАЦИОННЫЙ МАНИПУЛЯТОР")
  TK.newBtn(f, "🧲 Взять манипулятор", TK.C.ac, function() TK.giveItem(TK.GADGETS.grav) end, 36)
  TK.newBtn(f, "🧱 Создать тестовые объекты (5)", TK.C.bg2, function() TK.propsSpawn(5) end, 34)
  TK.newBtn(f, "🗑 Убрать тестовые объекты", TK.C.bg2, TK.propsClear, 32)
  TK.newNum(f, "💪 Сила", "GravPower", 10)
  TK.newNum(f, "↔ Радиус", "GravRadius", 10, nil, " ст.")
  TK.newStatus(f, function() return "  Тестовых объектов: " .. #TK.propsLive() .. " / " .. PROP_LIM .. "  · режим: " .. (GM.active and "включён" or "выключен") end, 28)
  TK.newInfo(f, "\n  Тапни по предмету в руке — появятся кнопки слева.\n  Воздействует только на тестовые объекты (только у тебя).", 56)
end)

-- ============================================================
--  СИСТЕМА 14: УМЕНЬШИТЕЛЬ (тестовые объекты и копия собственного скина)
-- ============================================================
local copyF = folder("Copy")
local SHR = { copy = nil, small = false }
local function scaleModel(m, k)
  pcall(function() m:ScaleTo(k) end)
end
local function tweenScale(m, from, to, dur)
  task.spawn(function()
    local t0 = os.clock()
    while m.Parent and not TK.DEAD do
      local a = math.clamp((os.clock() - t0) / dur, 0, 1)
      scaleModel(m, from + (to - from) * a)
      if a >= 1 then break end
      task.wait()
    end
  end)
end
function TK.shrinkCopyMake()
  if SHR.copy and SHR.copy.Parent then SHR.copy:Destroy() end
  local id = TK.ST.ActiveSkin ~= "" and TK.ST.ActiveSkin or "rick"
  local _, _, hr = TK.getChar()
  if not hr then return end
  local ok, m = pcall(TK.skinModel, TK.SK[id])
  if not ok or not m then TK.notify("Не вышло собрать копию", TK.C.dg, 1.5) return end
  local pos = hr.Position + hr.CFrame.LookVector * 6
  m.Name = "RM_ShrinkCopy"
  m:PivotTo(CFrame.new(pos.X, hr.Position.Y, pos.Z) * CFrame.Angles(0, math.rad(180), 0) * (hr.CFrame - hr.Position))
  m.Parent = copyF
  SHR.copy, SHR.small, SHR.k = m, false, 1
  TK.burst(pos, TK.C.ac3, 14)
end
function TK.shrinkToggle(model)
  if model == SHR.copy then
    local to = SHR.small and 1 or (TK.ST.ShrinkScale / 100)
    tweenScale(SHR.copy, SHR.k, to, .6)
    SHR.k, SHR.small = to, not SHR.small
  end
end
function TK.shrinkProp(p)
  local base = p:GetAttribute("BaseSize")
  if typeof(base) ~= "Vector3" then return end
  local small = p:GetAttribute("Small")
  local to = small and base or base * (TK.ST.ShrinkScale / 100)
  p:SetAttribute("Small", not small)
  TK.TweenService:Create(p, TweenInfo.new(.5, Enum.EasingStyle.Back), { Size = to }):Play()
end
function TK.shrinkFire()
  if not TK.enUse(5, "уменьшитель") then return end
  local r = TK.aimRay(200)
  if not r then TK.notify("Некуда стрелять", TK.C.dg, 1) return end
  local hit = r.Instance
  TK.burst(r.Position, TK.RGB(120, 255, 200), 14)
  if hit and hit.Name == "RM_Prop" and hit.Parent == propF then
    TK.shrinkProp(hit)
  elseif hit and SHR.copy and hit:IsDescendantOf(SHR.copy) then
    TK.shrinkToggle(SHR.copy)
  else
    TK.notify("Цель: тестовый объект или копия скина", TK.C.dg, 1.6)
  end
end
function TK.buildShrinkTool()
  local tool, h, P = TK.miniTool("Уменьшитель", "Уменьшить/увеличить тестовый объект", TK.V3(.5, 1.1, .5), TK.RGB(40, 90, 80))
  P("Body", TK.V3(.8, .6, 1.2), TK.RGB(70, 170, 140), CFrame.new(0, .7, -.4), Enum.Material.Metal)
  P("Cone", TK.V3(.9, .5, .5), TK.RGB(200, 255, 235), CFrame.new(0, .7, -1.3) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
  local l = P("Lens", TK.V3(.15, .45, .45), TK.RGB(120, 255, 200), CFrame.new(0, .7, -1.58) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("PointLight", { Color = TK.RGB(120, 255, 200), Range = 8, Brightness = 1.5, Shadows = false }, l)
  P("Dial", TK.V3(.1, .3, .3), TK.RGB(255, 200, 80), CFrame.new(0, 1.05, -.3) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  return tool
end
TK.GADGETS.shrink = { id = "g_shrink", ico = "🔬", name = "Уменьшитель", desc = "Стреляй по тестовому объекту или копии", build = TK.buildShrinkTool,
  act = TK.shrinkFire, grip = TK.V3(0, -.1, 0) }
TK.onUnload(function() if SHR.copy then pcall(function() SHR.copy:Destroy() end) end end)
TK.regSys({
  n = 14, name = "Уменьшитель", tab = "gadgets", mode = "visual",
  note = "Меняет размер только тестовых объектов и копии твоего скина (твой персонаж и чужие — нет).", keys = "уменьшитель размер масштаб",
  get = function() return SHR.copy ~= nil and SHR.copy.Parent ~= nil end,
  set = function(v) if v then TK.shrinkCopyMake() elseif SHR.copy then SHR.copy:Destroy() SHR.copy = nil end end,
})
TK.sect("gadgets", function(f)
  TK.newSec(f, "СИСТЕМА 14 · УМЕНЬШИТЕЛЬ")
  TK.newBtn(f, "🔬 Взять уменьшитель", TK.C.ac, function() TK.giveItem(TK.GADGETS.shrink) end, 36)
  TK.newBtn(f, "👤 Сделать копию своего скина", TK.C.bg2, TK.shrinkCopyMake, 34)
  TK.newBtn(f, "🧱 Создать тестовые объекты (5)", TK.C.bg2, function() TK.propsSpawn(5) end, 34)
  TK.newNum(f, "📏 Коэффициент уменьшения", "ShrinkScale", 5, nil, "%")
  TK.newInfo(f, "\n  Выстрел по объекту/копии: уменьшает, повторный — возвращает.\n  Свой персонаж и чужие размеры не меняются.", 56)
end)

-- ============================================================
--  СИСТЕМА 23: МЕХАНИЧЕСКАЯ РУКА (берёт только тестовые объекты)
-- ============================================================
local ARM = { m = nil, held = nil, pos = nil, t = 0, claw = 1, tgt = nil, yaw = 0 }
local armF = folder("Arm")
local function armClear()
  if ARM.m then pcall(function() ARM.m:Destroy() end) end
  ARM.m, ARM.held, ARM.tgt = nil, nil, nil
end
local function armBuild()
  armClear()
  local pos = TK.aimHit(60)
  local gy = TK.groundAt(pos) or pos.Y
  ARM.pos = TK.V3(pos.X, gy, pos.Z)
  local m = Instance.new("Model")
  m.Name = "RM_Arm"
  local col = TK.RGB(160, 170, 190)
  ARM.base = TK.apart(m, "Base", TK.V3(.8, 3, 3), TK.RGB(50, 54, 64), CFrame.new(ARM.pos) * CFrame.new(0, .4, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  ARM.turn = TK.apart(m, "Turn", TK.V3(1.4, 1.4, 1.4), TK.RGB(90, 100, 120), CFrame.new(ARM.pos + TK.V3(0, 1.6, 0)), Enum.Material.Metal, Enum.PartType.Ball)
  ARM.s1 = TK.apart(m, "Seg1", TK.V3(.8, .8, 1), col, CFrame.new(ARM.pos), Enum.Material.Metal)
  ARM.s2 = TK.apart(m, "Seg2", TK.V3(.6, .6, 1), TK.RGB(190, 200, 215), CFrame.new(ARM.pos), Enum.Material.Metal)
  ARM.elbow = TK.apart(m, "Elbow", TK.V3(1, 1, 1), TK.RGB(255, 190, 70), CFrame.new(ARM.pos), Enum.Material.Neon, Enum.PartType.Ball, .2)
  ARM.cl1 = TK.apart(m, "ClawA", TK.V3(.25, .25, 1.2), TK.RGB(230, 235, 240), CFrame.new(ARM.pos), Enum.Material.Metal)
  ARM.cl2 = TK.apart(m, "ClawB", TK.V3(.25, .25, 1.2), TK.RGB(230, 235, 240), CFrame.new(ARM.pos), Enum.Material.Metal)
  m.Parent = armF
  ARM.m = m
  TK.burst(ARM.pos, TK.RGB(255, 190, 70), 14)
end
local function armPlace(part, a, b, th)
  local d = (b - a)
  local len = d.Magnitude
  part.Size = TK.V3(th, th, math.max(len, .1))
  part.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
end
TK.tick("arm", 30, function(dt)
  if not ARM.m or not ARM.m.Parent then return end
  ARM.t = ARM.t + dt
  local L = TK.ST.ArmLen / 2
  local root = ARM.pos + TK.V3(0, 1.6, 0)
  -- цель: удержанный объект, выбранный объект или точка покоя
  local tgt = ARM.tgt
  local want = nil
  if tgt and tgt.Parent then want = tgt.Position
  else want = root + TK.V3(math.sin(ARM.t * .8) * L * .6, L * .9, math.cos(ARM.t * .8) * L * .6) end
  local flat = TK.V3(want.X - root.X, 0, want.Z - root.Z)
  local dx = math.max(flat.Magnitude, .01)
  local dy = want.Y - root.Y
  local dist = math.clamp(math.sqrt(dx * dx + dy * dy), .5, L * 1.95)
  -- двухзвенный IK в вертикальной плоскости
  local c = math.clamp((dist * dist - 2 * L * L) / (2 * L * L), -1, 1)
  local elb = math.acos(c)
  local base = math.atan2(dy, dx)
  local a1 = base + math.atan2(L * math.sin(elb), L + L * math.cos(elb)) * -1
  local dir = flat.Magnitude > .01 and flat.Unit or TK.V3(0, 0, -1)
  local function pt(ang, len, from) return from + dir * (math.cos(ang) * len) + TK.V3(0, math.sin(ang) * len, 0) end
  local elbowP = pt(base + math.atan2(L * math.sin(elb), L + L * math.cos(elb)), L, root)
  local tip = pt(base + math.atan2(L * math.sin(elb), L + L * math.cos(elb)) - elb, L, elbowP)
  if dist >= L * 1.9 then tip = root + (want - root).Unit * dist elbowP = root + (tip - root) / 2 + TK.V3(0, 1, 0) end
  pcall(function()
    armPlace(ARM.s1, root, elbowP, .8)
    armPlace(ARM.s2, elbowP, tip, .6)
    ARM.elbow.CFrame = CFrame.new(elbowP)
    local fwd = (tip - elbowP).Unit
    local right = fwd:Cross(TK.V3(0, 1, 0))
    if right.Magnitude < .01 then right = TK.V3(1, 0, 0) end
    right = right.Unit
    local open = ARM.held and .3 or (.9 + .3 * math.sin(ARM.t * 3))
    ARM.cl1.CFrame = CFrame.lookAt(tip + right * open * .5, tip + right * open * .5 + fwd) * CFrame.new(0, 0, -.6)
    ARM.cl2.CFrame = CFrame.lookAt(tip - right * open * .5, tip - right * open * .5 + fwd) * CFrame.new(0, 0, -.6)
    ARM.tip = tip + fwd * 1.1
    if ARM.held and ARM.held.Parent then
      ARM.held.AssemblyLinearVelocity = TK.V3()
      ARM.held.CFrame = CFrame.new(ARM.tip)
    end
  end)
end)
function TK.armGrab()
  if not ARM.m then TK.notify("Сначала поставь руку", TK.C.dg, 1.5) return end
  if ARM.held then TK.notify("Уже держу объект", TK.C.dg, 1.2) return end
  local best, bd = nil, TK.ST.ArmLen * 1.9
  for _, p in ipairs(TK.propsLive()) do
    local d = (p.Position - ARM.pos).Magnitude
    if d < bd then best, bd = p, d end
  end
  if not best then TK.notify("Рядом нет тестовых объектов", TK.C.dg, 1.6) return end
  if not TK.enUse(4, "рука") then return end
  ARM.tgt = best
  task.delay(.9, function()
    if ARM.tgt == best and best.Parent then ARM.held = best best.Anchored = true end
  end)
end
function TK.armRelease()
  local h = ARM.held
  ARM.held, ARM.tgt = nil, nil
  if h and h.Parent then
    h.Anchored = false
    h.AssemblyLinearVelocity = TK.V3(0, 5, 0)
  end
end
TK.onUnload(function() ARM.held = nil armClear() end)
TK.regSys({
  n = 23, name = "Механическая рука", tab = "gadgets", mode = "visual",
  note = "Берёт только тестовые объекты Toolkit.", keys = "рука клешня манипулятор механическая",
  get = function() return ARM.m ~= nil end, set = function(v) if v then armBuild() else armClear() end end,
})
TK.sect("gadgets", function(f)
  TK.newSec(f, "СИСТЕМА 23 · МЕХАНИЧЕСКАЯ РУКА")
  TK.newBtn(f, "🦾 Поставить руку (куда смотришь)", TK.C.ac, armBuild, 36)
  TK.newBtn(f, "🧱 Создать тестовые объекты (5)", TK.C.bg2, function() TK.propsSpawn(5) end, 34)
  TK.newBtn(f, "✊ Схватить ближайший объект", TK.C.bg2, TK.armGrab, 34)
  TK.newBtn(f, "🖐 Отпустить", TK.C.bg2, TK.armRelease, 32)
  TK.newBtn(f, "🗑 Убрать руку", TK.C.bg2, armClear, 32)
  TK.newNum(f, "📏 Длина", "ArmLen", 2, nil, " ст.")
  TK.newInfo(f, "\n  Рука тянется к ближайшему тестовому объекту, хватает и держит.\n  Игроков и чужие объекты не трогает.", 56)
end)

-- ============================================================
--  СИСТЕМА 17: ГРАВИТАЦИОННЫЕ ЗОНЫ (влияют только на тестовые объекты)
-- ============================================================
local zoneF = folder("GZones")
local GZ = {}
local GZ_LIM = 4
function TK.gzoneAdd()
  if #GZ >= GZ_LIM then TK.notify("Лимит зон: " .. GZ_LIM, TK.C.dg, 1.5) return end
  local pos = TK.aimHit(80)
  local r = TK.ST.GravRadius
  local col = TK.colOf(TK.COLLIST[(#GZ % 5) + 1])
  local s = TK.I("Part", {
    Name = "RM_GZone", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.ForceField, Color = col, Transparency = .55, Size = TK.V3(2, 2, 2), CFrame = CFrame.new(pos),
  }, zoneF)
  TK.TweenService:Create(s, TweenInfo.new(.8, Enum.EasingStyle.Back), { Size = TK.V3(2 * r, 2 * r, 2 * r) }):Play()
  local ring = TK.I("Part", {
    Name = "RM_GZoneRing", Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = .6, Size = TK.V3(.2, 2, 2),
    CFrame = CFrame.new(pos) * TK.R90,
  }, zoneF)
  GZ[#GZ + 1] = { s = s, ring = ring, pos = pos, r = r, on = true, t = 0, col = col }
  TK.burst(pos, col, 18)
  TK.notify("🌀 Гравизона " .. #GZ, col, 1.2)
end
function TK.gzoneClear()
  for i = #GZ, 1, -1 do
    pcall(function() GZ[i].s:Destroy() GZ[i].ring:Destroy() end)
    GZ[i] = nil
  end
end
TK.tick("gzones", 30, function(dt)
  for _, z in ipairs(GZ) do
    z.t = z.t + dt
    pcall(function()
      z.s.Transparency = z.on and (.55 + .1 * math.sin(z.t * 3)) or .9
      local k = 1 + .15 * math.sin(z.t * 4)
      z.ring.Size = TK.V3(.2, 2 * z.r * k, 2 * z.r * k)
    end)
    if z.on and #TK.props > 0 and TK.enDrain(1.5, dt) then
      for _, p in ipairs(TK.propsLive()) do
        if (p.Position - z.pos).Magnitude <= z.r then -- почти невесомость + лёгкое вращение
          local v = p.AssemblyLinearVelocity
          p.AssemblyLinearVelocity = TK.V3(v.X * .98, v.Y + TK.Workspace.Gravity * dt * .93, v.Z * .98)
          p.AssemblyAngularVelocity = p.AssemblyAngularVelocity + TK.V3(0, dt * 2, 0)
        end
      end
    end
  end
end)
TK.onUnload(TK.gzoneClear)
TK.regSys({
  n = 17, name = "Гравитационные зоны", tab = "gadgets", mode = "visual",
  note = "Влияют только на тестовые объекты Toolkit.", keys = "гравитация зона сфера искажение",
  get = function() return #GZ > 0 end, set = function(v) if v then TK.gzoneAdd() else TK.gzoneClear() end end,
})
TK.sect("gadgets", function(f)
  TK.newSec(f, "СИСТЕМА 17 · ГРАВИТАЦИОННЫЕ ЗОНЫ")
  TK.newBtn(f, "🌀 Создать зону (куда смотришь)", TK.C.ac, TK.gzoneAdd, 36)
  TK.newBtn(f, "⏯ Вкл/выкл все зоны", TK.C.bg2, function()
    for _, z in ipairs(GZ) do z.on = not z.on end
  end, 32)
  TK.newBtn(f, "🗑 Удалить зоны", TK.C.bg2, TK.gzoneClear, 32)
  TK.newStatus(f, function() return "  Зон: " .. #GZ .. " / " .. GZ_LIM .. "  · радиус берётся из «Радиус» манипулятора" end, 28)
end)

-- ============================================================
--  СИСТЕМА 16: КОНСТРУКТОР ГАДЖЕТОВ (локальные модели из Parts)
-- ============================================================
local CT = { body = 1, deco = 1, core = "green", color = "cyan", built = {}, saved = 1 }
local BODYN = { "Капсула", "Куб", "Сфера" }
local DECON = { "Антенна", "Кольцо", "Плавники", "Шипы" }
local buildF = folder("Gadgets")
local function ctorModel(cfg, at, anchored)
  local m = Instance.new("Model")
  m.Name = "RM_Gadget"
  local cf = at or CFrame.new()
  local col, core = TK.colOf(cfg.color), TK.colOf(cfg.core)
  local dark = TK.RGB(40, 44, 56)
  if cfg.body == 1 then
    TK.apart(m, "Body", TK.V3(2.6, 1.4, 1.4), col:Lerp(dark, .5), cf * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  elseif cfg.body == 2 then
    TK.apart(m, "Body", TK.V3(1.8, 1.8, 1.8), col:Lerp(dark, .5), cf, Enum.Material.Metal)
  else
    TK.apart(m, "Body", TK.V3(2, 2, 2), col:Lerp(dark, .5), cf, Enum.Material.Metal, Enum.PartType.Ball)
  end
  local c = TK.apart(m, "Core", TK.V3(.9, .9, .9), core, cf * CFrame.new(0, 0, -.8), Enum.Material.Neon, Enum.PartType.Ball, .1)
  TK.I("PointLight", { Color = core, Range = 10, Brightness = 1.5, Shadows = false }, c)
  if cfg.deco == 1 then
    TK.apart(m, "Antenna", TK.V3(.12, 1.4, .12), TK.RGB(200, 205, 215), cf * CFrame.new(0, 1.5, 0), Enum.Material.Metal)
    TK.apart(m, "Tip", TK.V3(.3, .3, .3), core, cf * CFrame.new(0, 2.3, 0), Enum.Material.Neon, Enum.PartType.Ball)
  elseif cfg.deco == 2 then
    TK.apart(m, "Ring", TK.V3(.2, 2.8, 2.8), col, cf * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder, .3)
  elseif cfg.deco == 3 then
    for _, s in ipairs({ -1, 1 }) do
      TK.apart(m, "Fin", TK.V3(.15, 1.2, 1.2), col, cf * CFrame.new(s * 1.3, 0, .3) * CFrame.Angles(0, 0, s * .4), Enum.Material.Metal)
    end
  else
    for i = 0, 5 do
      local a = math.rad(i * 60)
      TK.apart(m, "Spike", TK.V3(.2, .2, .8), TK.RGB(220, 225, 235), cf * CFrame.new(math.cos(a) * 1.1, math.sin(a) * 1.1, .6) * CFrame.Angles(0, 0, a), Enum.Material.Metal)
    end
  end
  return m
end
function TK.ctorSpawn(cfg)
  for i = #CT.built, 1, -1 do if not CT.built[i].m.Parent then table.remove(CT.built, i) end end
  if #CT.built >= 6 then TK.notify("Лимит гаджетов: 6", TK.C.dg, 1.5) return end
  local pos = TK.aimHit(60)
  local gy = TK.groundAt(pos) or pos.Y
  local base = TK.V3(pos.X, gy + 2.5, pos.Z)
  local m = ctorModel(cfg, CFrame.new(base), true)
  m.Parent = buildF
  CT.built[#CT.built + 1] = { m = m, base = base, t = math.random() * 6 }
  TK.burst(base, TK.colOf(cfg.core), 14)
end
function TK.ctorClear()
  for i = #CT.built, 1, -1 do pcall(function() CT.built[i].m:Destroy() end) CT.built[i] = nil end
end
TK.tick("ctor", 20, function(dt)
  for _, g in ipairs(CT.built) do
    g.t = g.t + dt
    pcall(function() g.m:PivotTo(CFrame.new(g.base + TK.V3(0, math.sin(g.t * 2) * .3, 0)) * CFrame.Angles(0, g.t * .8, 0)) end)
  end
end)
TK.onUnload(TK.ctorClear)
TK.regSys({
  n = 16, name = "Конструктор гаджетов", tab = "gadgets", mode = "visual",
  note = "Строит локальные модели; это не настоящие серверные предметы.", keys = "конструктор гаджет сборка модуль",
  get = function() return #CT.built > 0 end, set = function(v) if v then TK.ctorSpawn(CT) else TK.ctorClear() end end,
})
TK.sect("gadgets", function(f)
  TK.newSec(f, "СИСТЕМА 16 · КОНСТРУКТОР ГАДЖЕТОВ")
  local pv = TK.newPreview(f, 140)
  local function refresh() pv.set(ctorModel(CT, CFrame.new(), true), "Предпросмотр: " .. BODYN[CT.body] .. " + " .. DECON[CT.deco]) end
  local function cyc(label, getter, nextf)
    local b
    b = TK.newBtn(f, "", TK.C.bg2, function() nextf() b.Text = label .. ": " .. getter() refresh() end, 32)
    b.Text = label .. ": " .. getter()
    return b
  end
  cyc("🧱 Корпус", function() return BODYN[CT.body] end, function() CT.body = CT.body % 3 + 1 end)
  cyc("✨ Декор", function() return DECON[CT.deco] end, function() CT.deco = CT.deco % 4 + 1 end)
  cyc("⚡ Энергомодуль", function() return TK.COLNAMES[CT.core] end, function()
    for i, v in ipairs(TK.COLLIST) do if v == CT.core then CT.core = TK.COLLIST[i % 5 + 1] break end end
  end)
  cyc("🎨 Цвет корпуса", function() return TK.COLNAMES[CT.color] end, function()
    for i, v in ipairs(TK.COLLIST) do if v == CT.color then CT.color = TK.COLLIST[i % 5 + 1] break end end
  end)
  TK.newBtn(f, "🛠 Собрать в точке прицела", TK.C.ac, function() TK.ctorSpawn(CT) end, 36)
  TK.newBtn(f, "💾 Сохранить конфигурацию", TK.C.bg2, function()
    if #TK.DB.gadgets >= 8 then table.remove(TK.DB.gadgets, 1) end
    TK.DB.gadgets[#TK.DB.gadgets + 1] = { body = CT.body, deco = CT.deco, core = CT.core, color = CT.color }
    TK.dbSave()
    CT.saved = #TK.DB.gadgets
    TK.notify("💾 Конфиг сохранён (" .. #TK.DB.gadgets .. "/8)" .. (TK.HAS_FS and "" or " · только на сессию"), TK.C.ac, 1.8)
  end, 32)
  TK.newBtn(f, "📂 Загрузить следующую конфигурацию", TK.C.bg2, function()
    local n = #TK.DB.gadgets
    if n == 0 then TK.notify("Сохранённых конфигураций нет", TK.C.dg, 1.5) return end
    CT.saved = CT.saved % n + 1
    local c = TK.DB.gadgets[CT.saved]
    CT.body, CT.deco, CT.core, CT.color = c.body, c.deco, c.core, c.color
    refresh()
    TK.notify("📂 Конфиг " .. CT.saved .. "/" .. n, TK.C.ac3, 1.2)
  end, 32)
  TK.newBtn(f, "🗑 Убрать собранные", TK.C.bg2, TK.ctorClear, 30)
  TK.tabOpen.gadgets = refresh
  refresh()
end)

-- ============================================================
--  СИСТЕМА 15: ГОЛОГРАФИЧЕСКИЙ ПРОЕКТОР (текст и значки, без картинок-ассетов)
-- ============================================================
local HP = { on = false, m = nil, panels = {}, t = 0, pos = nil }
local holoF = folder("Holo")
local function holoLines()
  local pos = (TK.getChar() and select(3, TK.getChar())) and select(3, TK.getChar()).Position or TK.V3()
  local sysOn = 0
  for _, s in ipairs(TK.SYSL) do
    local ok, v = pcall(s.get)
    if ok and v then sysOn = sysOn + 1 end
  end
  return {
    { "СИСТЕМЫ", "🧠 Систем: " .. #TK.SYSL .. "\n✅ Включено: " .. sysOn },
    { "ЭНЕРГИЯ", "⚡ " .. math.floor(TK.EN.cur) .. " / " .. TK.ST.EnergyMax .. "\n" .. (TK.enOverloaded() and "ПЕРЕГРУЗКА" or "норма") },
    { "КООРДИНАТЫ", string.format("X %d\nY %d\nZ %d", pos.X, pos.Y, pos.Z) },
    { "ПОРТАЛЫ", "🌀 A: " .. (TK.PA and "открыт" or "—") .. "\n🌀 B: " .. (TK.PB and "открыт" or "—") },
  }
end
local function holoOff(quiet)
  if HP.m then
    local m = HP.m
    for _, p in ipairs(m:GetDescendants()) do
      pcall(function()
        if p:IsA("BasePart") then TK.TweenService:Create(p, TweenInfo.new(.4), { Transparency = 1 }):Play() end
        if p:IsA("TextLabel") then TK.TweenService:Create(p, TweenInfo.new(.4), { TextTransparency = 1 }):Play() end
      end)
    end
    task.delay(.5, function() pcall(function() m:Destroy() end) end)
  end
  HP.m, HP.panels = nil, {}
  if HP.on and not quiet then TK.notify("📽 Проектор выключен", TK.C.tx, 1.2) end
  HP.on = false
end
local function holoOn()
  if HP.on then return end
  local pos = TK.aimHit(40)
  local gy = TK.groundAt(pos) or pos.Y
  HP.pos = TK.V3(pos.X, gy, pos.Z)
  local m = Instance.new("Model")
  m.Name = "RM_Holo"
  local col = TK.colOf(TK.ST.HoloColor)
  TK.apart(m, "Base", TK.V3(.5, 2, 2), TK.RGB(40, 44, 54), CFrame.new(HP.pos + TK.V3(0, .25, 0)) * TK.R90, Enum.Material.Metal, Enum.PartType.Cylinder)
  local em = TK.apart(m, "Emitter", TK.V3(.3, .8, .8), col, CFrame.new(HP.pos + TK.V3(0, .6, 0)) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("PointLight", { Color = col, Range = 12, Brightness = 1.2, Shadows = false }, em)
  local lines = holoLines()
  for i, ln in ipairs(lines) do
    local p = TK.apart(m, "Panel", TK.V3(4.4, 2.6, .1), col, CFrame.new(HP.pos + TK.V3(0, 4, 0)), Enum.Material.Neon, nil, 1)
    local sg = TK.I("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(220, 130), LightInfluence = 0, Brightness = 1.5 }, p)
    local fr = TK.I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, sg)
    local t1 = TK.I("TextLabel", {
      Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 4), BackgroundTransparency = 1, Text = "◈ " .. ln[1],
      TextColor3 = TK.WHITE, Font = Enum.Font.GothamBold, TextSize = 20, TextTransparency = 1,
    }, fr)
    local t2 = TK.I("TextLabel", {
      Size = UDim2.new(1, -10, 1, -34), Position = UDim2.fromOffset(5, 32), BackgroundTransparency = 1, Text = ln[2],
      TextColor3 = TK.WHITE, Font = Enum.Font.Code, TextSize = 22, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Top,
    }, fr)
    HP.panels[i] = { p = p, t1 = t1, t2 = t2, ang = (i - 1) * (math.pi / 2) }
    TK.TweenService:Create(p, TweenInfo.new(.7), { Transparency = TK.ST.HoloAlpha / 100 + .15 }):Play()
    TK.TweenService:Create(t1, TweenInfo.new(.7), { TextTransparency = 0 }):Play()
    TK.TweenService:Create(t2, TweenInfo.new(.7), { TextTransparency = 0 }):Play()
  end
  m.Parent = holoF
  HP.m, HP.on, HP.t, HP.acc = m, true, 0, 0
  TK.burst(HP.pos + TK.V3(0, 1, 0), col, 14)
  TK.notify("📽 Проектор включён", col, 1.5)
end
TK.tick("holo", 20, function(dt)
  if not HP.on or not HP.m then return end
  HP.t = HP.t + dt
  HP.acc = HP.acc + dt
  local cam = TK.Workspace.CurrentCamera
  local col = TK.colOf(TK.ST.HoloColor)
  local lines
  if HP.acc > .5 then HP.acc = 0 lines = holoLines() end
  for i, pn in ipairs(HP.panels) do
    pcall(function()
      local a = pn.ang + HP.t * .25
      local at = HP.pos + TK.V3(math.cos(a) * 5, 4 + math.sin(HP.t * 1.5 + i) * .25, math.sin(a) * 5)
      pn.p.CFrame = CFrame.lookAt(at, cam and TK.V3(cam.CFrame.Position.X, at.Y, cam.CFrame.Position.Z) or HP.pos) * CFrame.Angles(0, math.pi, 0)
      pn.p.Color = col
      if lines then pn.t2.Text = lines[i][2] end
    end)
  end
end)
TK.onUnload(function() holoOff(true) end)
TK.regSys({
  n = 15, name = "Голографический проектор", tab = "gadgets", mode = "visual",
  note = "Показывает текстовые панели; картинки по ID не используются.", keys = "голограмма проектор панель",
  get = function() return HP.on end, set = function(v) if v then holoOn() else holoOff() end end,
})
TK.sect("gadgets", function(f)
  TK.newSec(f, "СИСТЕМА 15 · ГОЛОПРОЕКТОР")
  TK.newToggle(f, "📽 Проектор (в точке прицела)", function() return HP.on end, function(v) if v then holoOn() else holoOff() end end)
  TK.newCycle(f, "🎨 Цвет", "HoloColor", TK.COLLIST, TK.COLNAMES)
  TK.newNum(f, "👁 Прозрачность панелей", "HoloAlpha", 10, nil, "%")
  TK.newInfo(f, "\n  4 парящих панели: системы, энергия, координаты, порталы.\n  Цвет и прозрачность применяются при включении.", 56)
end)

RM._part3 = true
