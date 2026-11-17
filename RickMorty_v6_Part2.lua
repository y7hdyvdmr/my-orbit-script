-- ============================================================
--  Rick & Morty Toolkit v7.0 — ЧАСТЬ 2/5: порталы, пушки (8 скинов оружия), предметы, Мисиксы, бой с мишенями, крейсер
-- ============================================================
local G = (type(getgenv) == "function" and getgenv()) or _G
local RM = G.RickMorty
local TK = RM and RM._TK
if not TK or not RM._part1 then error("[RickMorty] часть 2 запущена без части 1") end

-- ============================================================
--  МИР: луч прицела, земля
-- ============================================================
function TK.aimHit(maxDist, farDist)
  local d, o = RM.getAimDirection()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { TK.LP.Character, TK.ship and TK.ship.model }
  local r = TK.Workspace:Raycast(o, d * maxDist, rp)
  if r then return r.Position, r.Normal end
  return o + d * math.min(maxDist, farDist or 50), -d
end
function TK.groundAt(pos)
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { TK.LP.Character, TK.ship and TK.ship.model }
  local r = TK.Workspace:Raycast(pos + TK.V3(0, 6, 0), TK.V3(0, -80, 0), rp)
  return r and r.Position.Y or nil
end

-- ============================================================
--  ПОРТАЛЫ: большие, мгновенное касание
-- ============================================================
function TK.pl(par, x, y, w, h, rot, col) -- скруглённая «таблетка» в SurfaceGui
  local f = TK.I("Frame", {
    AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h),
    Rotation = rot or 0, BackgroundColor3 = col, BorderSizePixel = 0,
  }, par)
  TK.I("UICorner", { CornerRadius = UDim.new(.5, 0) }, f)
  return f
end
function TK.killPortal(P, instant) -- закрытие: сжатие + вращение; instant = сразу убрать
  if not P or P.dead then return end
  P.dead = true
  if instant or not (P.d and P.d.Parent) then
    pcall(function() P.mo:Destroy() end)
    return
  end
  P.dying, P.dt0 = true, os.clock()
  P.s0 = P.d.Size.X
  if P.em then pcall(function() P.em.Enabled = false end) end
  TK.DYING[#TK.DYING + 1] = P
  TK.snd("close", .45)
end
function TK.portalRings(at, n, col) -- ударные кольца и вспышка при открытии портала
  local up = math.abs(n.Y) > .9 and Vector3.xAxis or Vector3.yAxis
  for i = 1, 2 do
    task.delay((i - 1) * .18, function()
      if TK.DEAD then return end
      local r = TK.I("Part", {
        Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
        CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = .2,
        Size = TK.V3(.15, TK.PORTAL_R * .6, TK.PORTAL_R * .6),
        CFrame = CFrame.lookAt(at, at + n, up) * CFrame.Angles(0, math.rad(90), 0),
      }, TK.fxFolder)
      TK.TweenService:Create(r, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = TK.V3(.15, TK.PORTAL_R * 2.8, TK.PORTAL_R * 2.8), Transparency = 1,
      }):Play()
      task.delay(.8, function() r:Destroy() end)
    end)
  end
  local fl = TK.I("Part", {
    Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.Neon, Color = col:Lerp(TK.WHITE, .6), Transparency = .3,
    Size = TK.V3(1, 1, 1), Position = at + n * .5,
  }, TK.fxFolder)
  TK.TweenService:Create(fl, TweenInfo.new(.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = TK.V3(TK.PORTAL_R * 1.8, TK.PORTAL_R * 1.8, TK.PORTAL_R * 1.8), Transparency = 1,
  }):Play()
  task.delay(.4, function() fl:Destroy() end)
  TK.burst(at + n, col, 36)
end
function TK.outBack(x) -- «перелёт» при открытии
  x = math.clamp(x, 0, 1)
  return 1 + 2.3 * (x - 1) ^ 3 + 1.3 * (x - 1) ^ 2
end
function TK.newPortal(pos, n, col)
  local up = math.abs(n.Y) > .9 and Vector3.xAxis or Vector3.yAxis
  local at = pos + n * .12
  local P = { pos = at, n = n, R = TK.PORTAL_R, L = {}, t0 = os.clock(), locked = false, mo = TK.I("Model", { Name = "RM_Portal" }, TK.Workspace) }
  local base = CFrame.lookAt(at, at + n, up)
  P.base = base
  local d = TK.mkp("Disc", TK.V3(.1, .1, .2), col)
  d.Anchored = true
  d.Transparency = 1
  d.CFrame = base
  d.Parent = P.mo
  P.d = d
  local dk, md, lt, wh = col:Lerp(TK.BLACK, .7), col:Lerp(TK.BLACK, .35), col:Lerp(TK.WHITE, .45), col:Lerp(TK.WHITE, .88)
  -- светящийся обод и мягкое гало (цилиндры осью вдоль нормали, за плоскостью воронки)
  local function ringPart(name, thick, mult, transp, c)
    local r = TK.I("Part", {
      Name = name, Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false,
      CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = c, Transparency = transp,
      Size = TK.V3(thick, .1, .1),
    }, P.mo)
    r.CFrame = CFrame.lookAt(at + n * .02, at + n * 1.02, up) * CFrame.Angles(0, math.rad(90), 0)
    return r
  end
  P.rim = ringPart("Rim", .22, 1, .05, col:Lerp(TK.WHITE, .25))
  P.halo = ringPart("Halo", .08, 1.3, .82, col)
  local g = TK.I("SurfaceGui", {
    Face = Enum.NormalId.Front, CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Brightness = 1.3,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  }, d)
  local function lay(spd) -- вращающийся слой
    local f = TK.I("Frame", {
      AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1, 1),
      BackgroundTransparency = 1,
    }, g)
    P.L[#P.L + 1] = { f, spd }
    return f
  end
  for i, s in ipairs({ .88, .72, .56, .4, .24 }) do -- градиент от светлого края к тёмному центру (глубина)
    TK.pl(g, .5, .5, s, s, 0, md:Lerp(dk, (i - 1) * .22))
  end
  TK.pl(g, .5, .5, .1, .1, 0, TK.BLACK) -- тёмная «дыра» в центре
  for k, cfg in ipairs({ { 14, -14 }, { 11, 19 } }) do -- два слоя «рваных» кругов по краю
    local f = lay(cfg[2])
    for i = 1, cfg[1] do
      local a = i / cfg[1] * 6.283 + k
      local s = .17 * (.75 + .25 * (i % 3))
      TK.pl(f, .5 + .385 * math.cos(a), .5 + .385 * math.sin(a), s, s, 0, k == 1 and md or md:Lerp(lt, .4))
    end
  end
  local f = lay(38) -- 5 спиральных рукавов
  for arm = 0, 4 do
    for j = 0, 4 do
      local r, an = .41 - j * .07, arm * 1.2566 + j * .6
      TK.pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .2 - j * .025, .045, math.deg(an) + 108, j % 2 == 0 and lt or md:Lerp(lt, .5))
    end
  end
  f = lay(52) -- белые мазки
  for i = 0, 15 do
    local r, an = .26 + .14 * ((i * 3) % 5) / 4, i * 2.4
    TK.pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .12 + .08 * ((i * 5) % 3) / 2, .035, math.deg(an) + 102, wh)
  end
  f = lay(95) -- быстрый внутренний слой
  for i = 0, 5 do
    local r, an = .1 + i * .03, i * 1.1
    TK.pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .13, .04, math.deg(an) + 105, lt)
  end
  f = lay(-24) -- v6: белые искры по воронке (как на фото порталов)
  for i = 0, 21 do
    local r, an = .06 + .38 * ((i * 7) % 10) / 10, i * 2.7
    TK.pl(f, .5 + r * math.cos(an), .5 + r * math.sin(an), .03, .03, 0, wh)
  end
  local g2 = g:Clone() -- обратная сторона (статичная копия)
  g2.Face = Enum.NormalId.Back
  g2.Parent = d
  P.light = TK.I("PointLight", { Color = col, Range = 24, Brightness = 2, Shadows = false }, d)
  local e = TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 16, Lifetime = NumberRange.new(.7, 1),
    Speed = NumberRange.new(4, 5), SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(.6, 0),
    Transparency = NumberSequence.new(.1, 1), LightEmission = 1, Color = ColorSequence.new(lt),
    EmissionDirection = Enum.NormalId.Front,
  }, d)
  pcall(function()
    e.Shape = Enum.ParticleEmitterShape.Disc
    e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
    e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
  end)
  P.em = e
  task.spawn(TK.portalRings, at, n, col)
  TK.snd("open", .5)
  return P
end
function TK.sizeRings(P, s, rimT, haloT) -- размеры обода и гало вслед за порталом
  if P.rim and P.rim.Parent then
    P.rim.Size = TK.V3(.22, s * 1.02, s * 1.02)
    P.rim.Transparency = rimT
  end
  if P.halo and P.halo.Parent then
    P.halo.Size = TK.V3(.08, s * 1.3, s * 1.3)
    P.halo.Transparency = haloT
  end
end
function TK.updPortal(P, t)
  if P.dying then return end
  local s = 2 * P.R
  if not P.done then
    local x = math.min(1, t / .5)
    s = 2 * P.R * math.max(TK.outBack(x), .03)
    P.d.Size = TK.V3(s, s, .2)
    P.done = x >= 1
  end
  local life = TK.PORTAL_LIFE - t
  local pulse = math.sin(t * 5)
  local blink = life < 4 and (math.floor(t * 8) % 2 == 0) -- в последние секунды мигает
  TK.sizeRings(P, s * (1 + pulse * .015), blink and .5 or .05, math.clamp(.82 + pulse * .08, 0, 1))
  for k, l in ipairs(P.L) do -- v6: неровный «дышащий» край, как у портала в мультсериале
    l[1].Rotation = t * l[2]
    local w = 1 + .03 * math.sin(t * 3 + k * 1.7)
    l[1].Size = UDim2.fromScale(w, 2 - w)
  end
  if P.light then P.light.Brightness = (blink and 1 or 2) + pulse * .8 end
end
function TK.stepDying(now) -- анимация закрытия порталов
  for i = #TK.DYING, 1, -1 do
    local P = TK.DYING[i]
    local k = (now - P.dt0) / .5
    if k >= 1 or not (P.d and P.d.Parent) then
      pcall(function() P.mo:Destroy() end)
      table.remove(TK.DYING, i)
    else
      local s = math.max(P.s0 * (1 - k * k), .05)
      P.d.Size = TK.V3(s, s, .2)
      TK.sizeRings(P, s, .05 + k * .9, .82 + k * .18)
      local t = now - P.t0
      for _, l in ipairs(P.L) do l[1].Rotation = t * l[2] * (1 + k * 6) end
      if P.light then P.light.Brightness = 2 * (1 - k) end
    end
  end
end
-- зона касания: почти весь диск портала, глубина ~5 стадов; проверяем корпус и ступни
function TK.inPortal(P, pos)
  local off = pos - P.pos
  local dep = off:Dot(P.n)
  local lat = (off - P.n * dep).Magnitude
  return math.abs(dep) < P.R * .8 and lat < P.R * 1.05
end
function TK.playerInPortal(P, hr)
  return TK.inPortal(P, hr.Position) or TK.inPortal(P, hr.Position - TK.V3(0, 2.6, 0))
end
function TK.teleportTo(hr, from, to)
  TK.tpCd = os.clock() + .3
  to.locked = true -- пока не выйдешь из зоны выходного портала, он не сработает
  local col = TK.pcol()
  TK.burst(hr.Position, col, 30)
  local ex = to.pos + to.n * 4
  local lk = TK.V3(to.n.X, 0, to.n.Z)
  if lk.Magnitude < .1 then lk = hr.CFrame.LookVector else lk = lk.Unit end
  hr.CFrame = CFrame.lookAt(ex, ex + TK.V3(lk.X, 0, lk.Z))
  hr.AssemblyLinearVelocity = to.n * 24
  TK.burst(ex, col, 30)
  TK.snd("teleport", .8, 1.2)
  TK.dimFx(col, .8)
end
-- v7.0: порталы также переносят только тестовые физические объекты Toolkit.
TK.PORTAL_PROP_CD = setmetatable({}, { __mode = "k" })
function TK.teleportPropThroughPortal(part, from, to)
  if not part or not part.Parent or part.Anchored or not from or not to then return false end
  local now = os.clock()
  if (TK.PORTAL_PROP_CD[part] or 0) > now then return false end
  TK.PORTAL_PROP_CD[part] = now + .45
  local rotation = to.base * CFrame.Angles(0, math.pi, 0) * from.base:Inverse()
  local oldPos = part.Position
  local newCF = rotation * part.CFrame
  part.CFrame = newCF + to.n * (to.R * 1.2 + 2)
  part.AssemblyLinearVelocity = rotation:VectorToWorldSpace(part.AssemblyLinearVelocity)
  part.AssemblyAngularVelocity = rotation:VectorToWorldSpace(part.AssemblyAngularVelocity)
  local col = TK.pcol()
  TK.burst(oldPos, col, 10)
  TK.burst(part.Position, col, 10)
  TK.snd("teleport", .35, 1.1)
  return true
end
function TK.setPortalSize(value)
  TK.PORTAL_R = math.clamp(value, 3, 10)
  for _, P in ipairs({ TK.PA, TK.PB }) do
    if P and not P.dead then
      P.R = TK.PORTAL_R
      if P.done and P.d and P.d.Parent then
        P.d.Size = TK.V3(2 * P.R, 2 * P.R, .2)
        TK.sizeRings(P, 2 * P.R, .05, .82)
      end
    end
  end
end
-- ============================================================
--  ВЫСТРЕЛ: у каждой пушки своя анимация
-- ============================================================
TK.FXO = setmetatable({}, { __mode = "k" }) -- исходные цвет/прозрачность деталей пушки
function TK.pulsePart(p, dur, col)
  if not p or not p.Parent then return end
  local o = TK.FXO[p]
  if not o then o = { p.Color, p.Transparency } TK.FXO[p] = o end
  p.Color = col or TK.WHITE
  p.Transparency = 0
  TK.TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = o[1], Transparency = o[2] }):Play()
end
function TK.pulseByName(tool, names, dur, col, step)
  local i = 0
  for _, d in ipairs(tool:GetDescendants()) do
    if names[d.Name] then
      i = i + 1
      local p = d
      if step and step > 0 then
        task.delay((i - 1) * step, function() TK.pulsePart(p, dur, col) end)
      else
        TK.pulsePart(p, dur, col)
      end
    end
  end
end
function TK.lightSpike(tool, peak)
  for _, d in ipairs(tool:GetDescendants()) do
    if d:IsA("PointLight") then
      local o = TK.FXO[d] or d.Brightness
      TK.FXO[d] = o
      d.Brightness = peak
      TK.TweenService:Create(d, TweenInfo.new(.3), { Brightness = o }):Play()
    end
  end
end
function TK.recoil(k, a, dur) -- отдача: сдвигаем предмет в руке и возвращаем
  local w = TK.gripW
  if not w or not w.Parent or not TK.X.gripC1 then return end
  local base = TK.X.gripC1
  TK.X.rec = (TK.X.rec or 0) + 1
  local id = TK.X.rec
  task.spawn(function()
    local t0 = os.clock()
    while id == TK.X.rec and not TK.DEAD and w.Parent do
      local x = (os.clock() - t0) / dur
      if x >= 1 then break end
      local env = (x < .2) and (x / .2) or (1 - (x - .2) / .8) ^ 2
      w.C1 = (CFrame.new(0, 0, k * env) * CFrame.Angles(a * env, 0, 0)):Inverse() * base
      task.wait()
    end
    if id == TK.X.rec and w.Parent then w.C1 = base end
  end)
end
TK.GUNFX = {}
function TK.GUNFX.rick(tool, mz)
  TK.recoil(.35, .12, .22)
  TK.pulseByName(tool, { Core = 1, CoreTop = 1 }, .35, TK.RGB(220, 255, 220))
  TK.pulseByName(tool, { Bubble1 = 1, Bubble2 = 1, Bubble3 = 1 }, .5, TK.WHITE, .05)
  TK.lightSpike(tool, 6)
  if mz then TK.burst(mz.Position, TK.RGB(60, 255, 90), 12) end
end
function TK.GUNFX.rick_prime(tool, mz)
  TK.recoil(.2, .05, .3)
  local dots = {}
  for r = 0, 2 do
    for c = 0, 2 do dots["Dot_" .. r .. "_" .. c] = true end
  end
  TK.pulseByName(tool, dots, .4, TK.WHITE, .035) -- волна по панели точек
  TK.pulseByName(tool, { PinkLine = 1, Corner = 1, FlangeGlow = 1, EmitGlow = 1, RingGlow = 1 }, .45, TK.RGB(255, 120, 180))
  TK.lightSpike(tool, 5)
  if mz then TK.burst(mz.Position, TK.RGB(255, 80, 150), 10) TK.burst(mz.Position, TK.RGB(60, 255, 90), 10) end
end
function TK.GUNFX.evil_morty(tool, mz)
  TK.recoil(.55, .2, .4)
  TK.pulseByName(tool, { Orb = 1, Core = 1 }, .5, TK.WHITE)
  TK.pulseByName(tool, { LensCore = 1 }, .6, TK.RGB(200, 235, 255))
  TK.lightSpike(tool, 6)
  if mz then TK.burst(mz.Position, TK.RGB(255, 225, 80), 16) end
end
function TK.gunFx(id)
  local tool = TK.heldTool
  if not tool or not tool.Parent then return end
  local f = TK.GUNFX[id]
  if f then pcall(f, tool, tool:FindFirstChild("Muzzle")) end
end
function TK.shootPortal(gunId)
  local now = os.clock()
  if now - (TK.X.lastShot or 0) < .25 then return end -- защита от спама
  TK.X.lastShot = now
  -- Если выстрел сделан конкретной пушкой, её характеристики не зависят от выбранного скина.
  local g = (gunId and TK.GUN_CFG[gunId]) or TK.gunCfg()
  local range = g and g.range or 500
  local pos, n = TK.aimHit(range, g and g.range or 50)
  local col = TK.gunSkinCol(gunId) or (g and g.col) or TK.pcol()
  if not TK.PA then
    TK.PA = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал A", col)
  elseif not TK.PB then
    TK.PB = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал B", col)
  elseif TK.PA.t0 <= TK.PB.t0 then
    TK.killPortal(TK.PA)
    TK.PA = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал A пересоздан", col)
  else
    TK.killPortal(TK.PB)
    TK.PB = TK.newPortal(pos, n, col)
    TK.notify("🌀 Портал B пересоздан", col)
  end
  local mz = TK.heldTool and TK.heldTool:FindFirstChild("Muzzle", true)
  if mz then
    local a = mz.Position
    local dist = (pos - a).Magnitude
    if dist > 1 then
      local b = TK.mkp("Beam", TK.V3(.25, .25, dist), col, Enum.Material.Neon)
      b.Anchored = true
      b.CFrame = CFrame.lookAt(a, pos) * CFrame.new(0, 0, -dist / 2)
      b.Parent = TK.fxFolder
      TK.TweenService:Create(b, TweenInfo.new(.25), { Transparency = 1 }):Play()
      task.delay(.3, function() b:Destroy() end)
    end
  end
  TK.gunFx(gunId)
  TK.snd("shoot", .6)
end
RM.shootPortal = TK.shootPortal

-- ============================================================
--  ПРЕДМЕТЫ: сборка моделей и хват рукой скина
-- ============================================================
function TK.toolPart(tool, handle, name, size, color, offset, material, shape)
  local p = TK.mkp(name, size, color, material, shape)
  p.Parent = tool
  local w = Instance.new("Weld")
  w.Part0 = handle
  w.Part1 = p
  w.C0 = offset
  p.CFrame = handle.CFrame * offset
  w.Parent = p
  return p
end
TK.R90 = CFrame.Angles(0, 0, math.rad(90)) -- ось цилиндра: X -> вертикаль
TK.RZ = CFrame.Angles(0, math.rad(90), 0)  -- ось цилиндра: X -> вдоль Z

-- портальная пушка по фото
-- пушки по фото (v4.6): Рик (мультяшная), Рик Прайм (диск с ручкой, панель точек), Злой Морти (золотая)
function TK.gunBase()
  local tool = TK.I("Tool", { Name = "Портальная пушка", RequiresHandle = true, CanBeDropped = false, ToolTip = "Открыть портал" })
  local h = TK.mkp("Handle", TK.V3(.45, 1.3, .6), TK.RGB(214, 217, 222))
  h.Transparency = 1
  h.Parent = tool
  return tool, function(...) return TK.toolPart(tool, h, ...) end
end
function TK.buildGunRick()
  local tool, P = TK.gunBase()
  local H = math.rad
  P("HandleBar", TK.V3(.55, .42, 1.7), TK.RGB(190, 192, 196), CFrame.new(0, 0, .4))
  P("HandleCap", TK.V3(.55, .42, .55), TK.RGB(190, 192, 196), CFrame.new(0, 0, 1.25), nil, Enum.PartType.Ball)
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, -.05))
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, .3))
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, .65))
  P("GripRidge", TK.V3(.57, .05, .1), TK.RGB(120, 122, 128), CFrame.new(0, .215, 1))
  P("Body", TK.V3(1.35, .5, 2.3), TK.RGB(205, 207, 210), CFrame.new(0, .02, -1.45))
  P("BodyTop", TK.V3(1.2, .05, 2), TK.RGB(222, 224, 227), CFrame.new(0, .285, -1.45))
  P("Under", TK.V3(1.25, .12, 2.1), TK.RGB(150, 152, 158), CFrame.new(0, -.22, -1.45))
  P("SideL", TK.V3(.04, .3, 1.9), TK.RGB(170, 172, 178), CFrame.new(-.69, .02, -1.45))
  P("SideR", TK.V3(.04, .3, 1.9), TK.RGB(170, 172, 178), CFrame.new(.69, .02, -1.45))
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(-.56, .31, -.6), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(-.56, .31, -1.45), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(-.56, .31, -2.3), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(.56, .31, -.6), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(.56, .31, -1.45), nil, Enum.PartType.Ball)
  P("Rivet", TK.V3(.1, .1, .1), TK.RGB(130, 132, 138), CFrame.new(.56, .31, -2.3), nil, Enum.PartType.Ball)
  P("Vent", TK.V3(.55, .03, .06), TK.RGB(45, 46, 52), CFrame.new(0, .3, -.5))
  P("Vent", TK.V3(.55, .03, .06), TK.RGB(45, 46, 52), CFrame.new(0, .3, -.62))
  P("Vent", TK.V3(.55, .03, .06), TK.RGB(45, 46, 52), CFrame.new(0, .3, -.74))
  P("Emitter", TK.V3(.5, .2, .05), TK.RGB(30, 30, 34), CFrame.new(0, .02, -2.62))
  P("EmitRing", TK.V3(.07, .6, .6), TK.RGB(80, 84, 90), CFrame.new(0, .02, -2.63) * CFrame.Angles(H(0), H(90), H(0)), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("EmitGlow", TK.V3(.08, .4, .4), TK.RGB(60, 230, 90), CFrame.new(0, .02, -2.65) * CFrame.Angles(H(0), H(90), H(0)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .35
  end
  P("ButtonFrame", TK.V3(.72, .06, .52), TK.RGB(45, 46, 52), CFrame.new(0, .27, -.95))
  do
    local q = P("Button", TK.V3(.6, .09, .42), TK.RGB(215, 30, 40), CFrame.new(0, .31, -.95), Enum.Material.Neon)
    q.Transparency = .1
  end
  P("Led", TK.V3(.1, .1, .1), TK.RGB(110, 255, 110), CFrame.new(.5, .31, -.4), Enum.Material.Neon, Enum.PartType.Ball)
  P("Knob", TK.V3(.22, .5, .5), TK.RGB(35, 35, 38), CFrame.new(0, .36, -.35) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("KnobCap", TK.V3(.05, .36, .36), TK.RGB(70, 72, 78), CFrame.new(0, .63, -.35) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Ring", TK.V3(.1, .9, .9), TK.RGB(170, 172, 176), CFrame.new(0, .3, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("RingGlow", TK.V3(.04, .96, .96), TK.RGB(60, 255, 90), CFrame.new(0, .33, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .5
  end
  do
    local q = P("Dome", TK.V3(.8, .7, .7), TK.RGB(60, 255, 90), CFrame.new(0, .75, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Glass, Enum.PartType.Cylinder)
    q.Transparency = .25
  end
  do
    local q = P("DomeTop", TK.V3(.7, .7, .7), TK.RGB(60, 255, 90), CFrame.new(0, 1.15, -1.9), Enum.Material.Glass, Enum.PartType.Ball)
    q.Transparency = .25
  end
  do
    local q = P("Core", TK.V3(.75, .44, .44), TK.RGB(110, 255, 110), CFrame.new(0, .75, -1.9) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .2
    TK.I("PointLight", { Color = TK.RGB(60, 255, 90), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  do
    local q = P("CoreTop", TK.V3(.44, .44, .44), TK.RGB(110, 255, 110), CFrame.new(0, 1.13, -1.9), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .2
  end
  do
    local q = P("Bubble1", TK.V3(.17, .17, .17), TK.RGB(190, 255, 190), CFrame.new(.12, .6, -1.82), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
  end
  do
    local q = P("Bubble2", TK.V3(.13, .13, .13), TK.RGB(190, 255, 190), CFrame.new(-.1, .9, -1.95), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
  end
  do
    local q = P("Bubble3", TK.V3(.1, .1, .1), TK.RGB(190, 255, 190), CFrame.new(.05, 1.05, -1.88), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
  end
  do
    local q = P("Muzzle", TK.V3(.1, .1, .1), TK.RGB(255, 255, 255), CFrame.new(0, .02, -2.8), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = 1
  end
  do -- v6: красный дисплей «C-137» и три зелёные лампы на корпусе (по новым фото пушки Рика)
    local dsp = P("Display", TK.V3(.5, .05, .28), TK.RGB(40, 10, 10), CFrame.new(0, .3, .1))
    local sg = TK.I("SurfaceGui", { Face = Enum.NormalId.Top, CanvasSize = Vector2.new(100, 56), LightInfluence = 0, Brightness = 2 }, dsp)
    TK.I("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "C-137", TextColor3 = TK.RGB(255, 60, 60), Font = Enum.Font.Code, TextScaled = true }, sg)
    for i = -1, 1 do
      P("Led3", TK.V3(.14, .1, .14), TK.RGB(110, 255, 110), CFrame.new(i * .3, .31, -1.15), Enum.Material.Neon, Enum.PartType.Ball)
    end
  end
  return tool
end
function TK.buildGunPrime()
  local tool, P = TK.gunBase()
  local H = math.rad
  P("Grip", TK.V3(.62, 1.55, .78), TK.RGB(205, 208, 213), CFrame.new(0, 0, .2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripDark", TK.V3(.5, 1, .2), TK.RGB(82, 85, 92), CFrame.new(0, -.42, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.15, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.37, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.59, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("GripRib", TK.V3(.5, .06, .22), TK.RGB(60, 62, 68), CFrame.new(0, -.81, -.2) * CFrame.Angles(H(-14), H(0), H(0)))
  P("Body", TK.V3(.95, .85, 1.95), TK.RGB(225, 228, 232), CFrame.new(0, 1.05, -.8))
  P("Slope", TK.V3(.66, .5, .95), TK.RGB(225, 228, 232), CFrame.new(0, 1.2, .38) * CFrame.Angles(H(14), H(0), H(0)))
  P("Strut", TK.V3(.55, .2, 1.75), TK.RGB(200, 203, 208), CFrame.new(0, 0, -.3) * CFrame.Angles(H(45), H(0), H(0)))
  P("Trigger", TK.V3(.14, .42, .2), TK.RGB(45, 45, 50), CFrame.new(0, .42, -.3) * CFrame.Angles(H(20), H(0), H(0)))
  do
    local q = P("Switch", TK.V3(.28, .16, .32), TK.RGB(225, 35, 35), CFrame.new(0, 1.45, .65), Enum.Material.Neon)
    q.Transparency = .1
  end
  do
    local q = P("PinkLine", TK.V3(.03, .05, 1.75), TK.RGB(255, 60, 130), CFrame.new(-.49, 1.36, -.8), Enum.Material.Neon)
    q.Transparency = .15
  end
  do
    local q = P("PinkLine", TK.V3(.03, .05, 1.75), TK.RGB(255, 60, 130), CFrame.new(.49, 1.36, -.8), Enum.Material.Neon)
    q.Transparency = .15
  end
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(-.3, 1.49, -1.5), nil, Enum.PartType.Ball)
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(-.3, 1.49, -.2), nil, Enum.PartType.Ball)
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(.3, 1.49, -1.5), nil, Enum.PartType.Ball)
  P("Screw", TK.V3(.09, .09, .09), TK.RGB(150, 154, 160), CFrame.new(.3, 1.49, -.2), nil, Enum.PartType.Ball)
  P("Panel", TK.V3(.86, .8, .03), TK.RGB(28, 28, 30), CFrame.new(0, 1.05, -1.79))
  P("BezelT", TK.V3(1, .07, .06), TK.RGB(95, 98, 105), CFrame.new(0, 1.47, -1.8), Enum.Material.Metal)
  P("BezelB", TK.V3(1, .07, .06), TK.RGB(95, 98, 105), CFrame.new(0, .63, -1.8), Enum.Material.Metal)
  P("BezelL", TK.V3(.07, .9, .06), TK.RGB(95, 98, 105), CFrame.new(-.46, 1.05, -1.8), Enum.Material.Metal)
  P("BezelR", TK.V3(.07, .9, .06), TK.RGB(95, 98, 105), CFrame.new(.46, 1.05, -1.8), Enum.Material.Metal)
  P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(-.5, .61, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
  P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(-.5, 1.49, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
  P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(.5, .61, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
  do
    local q = P("Corner", TK.V3(.1, .1, .1), TK.RGB(255, 60, 130), CFrame.new(.5, 1.49, -1.84), Enum.Material.Neon, Enum.PartType.Ball)
    TK.I("PointLight", { Color = TK.RGB(255, 60, 130), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  P("Dot_0_0", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(-.27, .79, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_0_1", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(0, .79, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_0_2", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(.27, .79, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_1_0", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(-.27, 1.05, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_1_1", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(0, 1.05, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_1_2", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(.27, 1.05, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_2_0", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(-.27, 1.31, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_2_1", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(0, 1.31, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Dot_2_2", TK.V3(.22, .22, .22), TK.RGB(110, 255, 110), CFrame.new(.27, 1.31, -1.83), Enum.Material.Neon, Enum.PartType.Ball)
  P("Flange", TK.V3(.1, .85, .85), TK.RGB(200, 204, 210), CFrame.new(0, 1.52, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("FlangeGlow", TK.V3(.04, .92, .92), TK.RGB(255, 60, 130), CFrame.new(0, 1.57, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .35
  end
  do
    local q = P("Dome", TK.V3(.75, .72, .72), TK.RGB(60, 255, 90), CFrame.new(0, 1.95, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Glass, Enum.PartType.Cylinder)
    q.Transparency = .25
  end
  do
    local q = P("DomeTop", TK.V3(.72, .72, .72), TK.RGB(60, 255, 90), CFrame.new(0, 2.32, -.95), Enum.Material.Glass, Enum.PartType.Ball)
    q.Transparency = .25
  end
  do
    local q = P("Core", TK.V3(.7, .46, .46), TK.RGB(110, 255, 110), CFrame.new(0, 1.95, -.95) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .2
    TK.I("PointLight", { Color = TK.RGB(60, 255, 90), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  do
    local q = P("CoreTop", TK.V3(.46, .46, .46), TK.RGB(110, 255, 110), CFrame.new(0, 2.3, -.95), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .2
  end
  P("DialRing", TK.V3(.07, .62, .62), TK.RGB(210, 213, 218), CFrame.new(.5, 1, -.55), Enum.Material.Metal, Enum.PartType.Cylinder)
  do
    local q = P("DialTick", TK.V3(.09, .66, .66), TK.RGB(120, 124, 130), CFrame.new(.5, 1, -.55), nil, Enum.PartType.Cylinder)
    q.Transparency = 0
  end
  P("Dial", TK.V3(.09, .5, .5), TK.RGB(190, 194, 200), CFrame.new(.53, 1, -.55), nil, Enum.PartType.Cylinder)
  P("DialPtr", TK.V3(.07, .09, .4), TK.RGB(232, 235, 240), CFrame.new(.58, 1, -.55) * CFrame.Angles(H(35), H(0), H(0)))
  P("Hole1", TK.V3(.03, .1, .1), TK.RGB(20, 20, 22), CFrame.new(.49, 1.05, -1.25), nil, Enum.PartType.Cylinder)
  P("Hole2", TK.V3(.03, .1, .1), TK.RGB(20, 20, 22), CFrame.new(.49, .82, -1.25), nil, Enum.PartType.Cylinder)
  P("Toggle", TK.V3(.12, .05, .05), TK.RGB(190, 194, 200), CFrame.new(.52, 1.28, -1.25))
  do
    local q = P("Muzzle", TK.V3(.1, .1, .1), TK.RGB(255, 255, 255), CFrame.new(0, 1.05, -1.95), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = 1
  end
  return tool
end
function TK.buildGunEvil()
  local tool, P = TK.gunBase()
  local H = math.rad
  P("Grip", TK.V3(.5, 1.4, .6), TK.RGB(120, 115, 120), CFrame.new(0, 0, .1) * CFrame.Angles(H(-10), H(0), H(0)))
  P("GripWrap", TK.V3(.52, .16, .62), TK.RGB(80, 60, 40), CFrame.new(0, -.25, .1) * CFrame.Angles(H(-10), H(0), H(0)))
  P("GripWrap", TK.V3(.52, .16, .62), TK.RGB(80, 60, 40), CFrame.new(0, .1, .08) * CFrame.Angles(H(-10), H(0), H(0)))
  P("Trigger", TK.V3(.14, .45, .18), TK.RGB(30, 30, 34), CFrame.new(0, .45, -.3) * CFrame.Angles(H(15), H(0), H(0)))
  P("Slab", TK.V3(.75, .7, 2.6), TK.RGB(175, 150, 45), CFrame.new(0, .95, -.9))
  P("SlabEdge", TK.V3(.77, .06, 2.6), TK.RGB(215, 190, 75), CFrame.new(0, 1.3, -.9))
  P("SlabPlate", TK.V3(.55, .03, 1.9), TK.RGB(140, 118, 38), CFrame.new(0, 1.33, -.9))
  do
    local q = P("SlabLine", TK.V3(.03, .04, 2.4), TK.RGB(255, 225, 110), CFrame.new(-.39, 1.1, -.9), Enum.Material.Neon)
    q.Transparency = .35
  end
  do
    local q = P("SlabLine", TK.V3(.03, .04, 2.4), TK.RGB(255, 225, 110), CFrame.new(.39, 1.1, -.9), Enum.Material.Neon)
    q.Transparency = .35
  end
  P("Block", TK.V3(1.05, 1.1, 1.1), TK.RGB(150, 125, 35), CFrame.new(0, .95, -2.35))
  P("BlockEdge", TK.V3(1.07, .06, 1.1), TK.RGB(215, 190, 75), CFrame.new(0, 1.5, -2.35))
  P("VentSlot", TK.V3(.8, .03, .08), TK.RGB(40, 32, 12), CFrame.new(0, 1.52, -2.1))
  P("VentSlot", TK.V3(.8, .03, .08), TK.RGB(40, 32, 12), CFrame.new(0, 1.52, -2.3))
  P("VentSlot", TK.V3(.8, .03, .08), TK.RGB(40, 32, 12), CFrame.new(0, 1.52, -2.5))
  P("LensRing", TK.V3(.06, .78, .78), TK.RGB(35, 40, 35), CFrame.new(-.55, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, 1.37, -2.35))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, 1.247, -2.053) * CFrame.Angles(H(45), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .95, -1.93) * CFrame.Angles(H(90), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .653, -2.053) * CFrame.Angles(H(135), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .53, -2.35) * CFrame.Angles(H(180), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .653, -2.647) * CFrame.Angles(H(225), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, .95, -2.77) * CFrame.Angles(H(270), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(-.56, 1.247, -2.647) * CFrame.Angles(H(315), H(0), H(0)))
  P("Lens", TK.V3(.08, .62, .62), TK.RGB(85, 100, 85), CFrame.new(-.57, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("LensCore", TK.V3(.1, .28, .28), TK.RGB(60, 170, 255), CFrame.new(-.6, .95, -2.35), Enum.Material.Neon, Enum.PartType.Cylinder)
  P("LensRing", TK.V3(.06, .78, .78), TK.RGB(35, 40, 35), CFrame.new(.55, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, 1.37, -2.35))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, 1.247, -2.053) * CFrame.Angles(H(45), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .95, -1.93) * CFrame.Angles(H(90), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .653, -2.053) * CFrame.Angles(H(135), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .53, -2.35) * CFrame.Angles(H(180), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .653, -2.647) * CFrame.Angles(H(225), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, .95, -2.77) * CFrame.Angles(H(270), H(0), H(0)))
  P("Tooth", TK.V3(.09, .11, .11), TK.RGB(110, 92, 28), CFrame.new(.56, 1.247, -2.647) * CFrame.Angles(H(315), H(0), H(0)))
  P("Lens", TK.V3(.08, .62, .62), TK.RGB(85, 100, 85), CFrame.new(.57, .95, -2.35), nil, Enum.PartType.Cylinder)
  P("LensCore", TK.V3(.1, .28, .28), TK.RGB(60, 170, 255), CFrame.new(.6, .95, -2.35), Enum.Material.Neon, Enum.PartType.Cylinder)
  do
    local q = P("Orb", TK.V3(.55, .55, .55), TK.RGB(255, 240, 140), CFrame.new(0, .95, -3), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = .15
    TK.I("PointLight", { Color = TK.RGB(255, 220, 50), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  P("OrbCup", TK.V3(.12, .62, .62), TK.RGB(120, 100, 30), CFrame.new(0, .95, -2.92) * CFrame.Angles(H(0), H(90), H(0)), nil, Enum.PartType.Cylinder)
  do
    local q = P("Jar", TK.V3(.95, .5, .5), TK.RGB(255, 225, 80), CFrame.new(0, 1.75, -1.55) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Glass, Enum.PartType.Cylinder)
    q.Transparency = .4
  end
  do
    local q = P("DomeTop", TK.V3(.5, .5, .5), TK.RGB(255, 225, 80), CFrame.new(0, 2.25, -1.55), Enum.Material.Glass, Enum.PartType.Ball)
    q.Transparency = .4
  end
  do
    local q = P("Core", TK.V3(.8, .25, .25), TK.RGB(255, 240, 140), CFrame.new(0, 1.75, -1.55) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
    q.Transparency = .3
    TK.I("PointLight", { Color = TK.RGB(255, 220, 50), Range = 9, Brightness = 2, Shadows = false }, q)
  end
  P("JarBase", TK.V3(.1, .56, .56), TK.RGB(120, 100, 30), CFrame.new(0, 1.35, -1.55) * CFrame.Angles(H(0), H(0), H(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
  P("GreyA", TK.V3(.45, .5, .5), TK.RGB(110, 118, 115), CFrame.new(0, 1.5, -.65))
  P("GreyB", TK.V3(.3, .35, .3), TK.RGB(130, 135, 130), CFrame.new(0, 1.45, -.25))
  P("VialTeal", TK.V3(.4, .22, .22), TK.RGB(60, 140, 125), CFrame.new(.2, 1.55, -.95) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("VialRust", TK.V3(.45, .2, .2), TK.RGB(150, 85, 50), CFrame.new(-.2, 1.55, -.3) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Canister", TK.V3(1, .4, .4), TK.RGB(110, 78, 50), CFrame.new(0, 1.75, .25) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Strap", TK.V3(.1, .44, .44), TK.RGB(70, 50, 35), CFrame.new(0, 1.9, .25) * CFrame.Angles(H(0), H(0), H(90)), nil, Enum.PartType.Cylinder)
  P("Cable", TK.V3(.05, .05, .9), TK.RGB(30, 30, 34), CFrame.new(.22, 1.45, -1.3) * CFrame.Angles(H(0), H(20), H(0)))
  do
    local q = P("Muzzle", TK.V3(.1, .1, .1), TK.RGB(255, 255, 255), CFrame.new(0, .95, -3.2), Enum.Material.Neon, Enum.PartType.Ball)
    q.Transparency = 1
  end
  return tool
end

-- замораживатель времени (дизайн мой: картинки не было)
function TK.buildFreezer()
  local tool = TK.I("Tool", { Name = "Замораживатель времени", RequiresHandle = true, CanBeDropped = false, ToolTip = "Остановить время" })
  local h = TK.mkp("Handle", TK.V3(.5, 1.2, .5), TK.RGB(60, 64, 74))
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local BL = TK.RGB(90, 200, 255)
  P("Body", TK.V3(.9, .75, 1.3), TK.RGB(225, 230, 235), CFrame.new(0, .75, -.45))
  P("LensRing", TK.V3(.12, 1.15, 1.15), TK.RGB(50, 54, 62), CFrame.new(0, .75, -1.12) * TK.RZ, nil, Enum.PartType.Cylinder)
  P("Lens", TK.V3(.4, .9, .9), BL, CFrame.new(0, .75, -1.2) * TK.RZ, Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = .3
  local core = P("Core", TK.V3(.5, .5, .5), TK.RGB(200, 245, 255), CFrame.new(0, .75, -1.15) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  core.Transparency = .2
  TK.I("PointLight", { Color = BL, Range = 9, Brightness = 2, Shadows = false }, core)
  local btn = P("Button", TK.V3(.12, .5, .5), TK.RGB(50, 120, 200), CFrame.new(0, 1.18, -.3) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("PointLight", { Color = BL, Range = 5, Brightness = 1, Shadows = false }, btn)
  for _, s in ipairs({ -1, 1 }) do
    P("Fin", TK.V3(.1, .5, .8), TK.RGB(150, 160, 170), CFrame.new(s * .5, .75, -.4))
  end
  return tool
end

-- ящик Мисиксов по фото: тёмно-бирюзовый куб, зелёные окна, синяя кнопка сверху
function TK.buildMeeseeksBox()
  local tool = TK.I("Tool", { Name = "Ящик Мисиксов", RequiresHandle = true, CanBeDropped = false, ToolTip = "Нажми кнопку — помощник" })
  local h = TK.mkp("Handle", TK.V3(1.5, 1.5, 1.5), TK.RGB(30, 66, 64), Enum.Material.Metal)
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local GREEN, DKG = TK.RGB(120, 250, 180), TK.RGB(40, 190, 130)
  P("Top", TK.V3(1.3, .12, 1.3), TK.RGB(84, 130, 130), CFrame.new(0, .78, 0), Enum.Material.Metal)
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("Post", TK.V3(.14, 1.56, .14), TK.RGB(62, 112, 110), CFrame.new(sx * .72, 0, sz * .72), Enum.Material.Metal)
    end
  end
  P("ButtonBase", TK.V3(.1, .66, .66), TK.RGB(8, 24, 24), CFrame.new(0, .86, 0) * TK.R90, nil, Enum.PartType.Cylinder)
  local btn = P("Button", TK.V3(.24, .5, .5), TK.RGB(70, 170, 240), CFrame.new(0, .97, 0) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("PointLight", { Color = TK.RGB(70, 170, 240), Range = 8, Brightness = 1.5, Shadows = false }, btn)
  for i = 0, 3 do -- «восьмиугольные» окна на 4 гранях
    local side = CFrame.Angles(0, math.rad(i * 90), 0) * CFrame.new(0, -.02, -.755)
    P("WinA", TK.V3(.86, .5, .05), GREEN, side, Enum.Material.Neon)
    P("WinB", TK.V3(.5, .86, .05), GREEN, side, Enum.Material.Neon)
    P("WinC", TK.V3(.62, .62, .05), GREEN, side * CFrame.Angles(0, 0, math.rad(45)), Enum.Material.Neon)
    P("Line", TK.V3(.03, .7, .06), DKG, side * CFrame.new(-.12, 0, -.02))
    P("Line", TK.V3(.03, .7, .06), DKG, side * CFrame.new(.12, 0, -.02))
  end
  return tool
end

-- батарея микровселенной по фото: фиолетовое желе в чёрной раме, три глаза, экран заряда
function TK.buildBattery()
  local tool = TK.I("Tool", { Name = "Батарея микровселенной", RequiresHandle = true, CanBeDropped = false, ToolTip = "Зона энергии" })
  local h = TK.mkp("Handle", TK.V3(1.2, .8, .8), TK.RGB(170, 60, 230), Enum.Material.Neon)
  h.Transparency = .15
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local dk = TK.RGB(22, 22, 26)
  P("Glass", TK.V3(1.4, 1, 1), TK.RGB(215, 140, 255), CFrame.new(), Enum.Material.Glass).Transparency = .6
  for _, sy in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("BarX", TK.V3(1.5, .1, .1), dk, CFrame.new(0, sy * .5, sz * .5), Enum.Material.Metal)
    end
  end
  for _, sx in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      P("BarY", TK.V3(.1, 1.1, .1), dk, CFrame.new(sx * .7, 0, sz * .5), Enum.Material.Metal)
    end
    for _, sy in ipairs({ -1, 1 }) do
      P("BarZ", TK.V3(.1, .1, 1.1), dk, CFrame.new(sx * .7, sy * .5, 0), Enum.Material.Metal)
    end
  end
  P("Panel", TK.V3(.6, .7, .06), dk, CFrame.new(-.35, 0, -.53), Enum.Material.Metal)
  for i = 0, 2 do -- три глаза
    local ex = -.5 + i * .15
    local ey = (i == 1) and .22 or .15
    P("Eye", TK.V3(.16, .16, .16), TK.RGB(240, 240, 240), CFrame.new(ex, ey, -.58), nil, Enum.PartType.Ball)
    P("Pupil", TK.V3(.08, .08, .08), TK.RGB(0, 0, 0), CFrame.new(ex, ey, -.63), nil, Enum.PartType.Ball)
  end
  P("Door", TK.V3(.18, .28, .04), TK.RGB(70, 74, 82), CFrame.new(-.35, -.2, -.57))
  P("Blob", TK.V3(.2, .2, .2), TK.RGB(255, 150, 255), CFrame.new(.15, .15, -.1), Enum.Material.Neon, Enum.PartType.Ball).Transparency = .2
  P("Blob", TK.V3(.12, .12, .12), TK.RGB(255, 200, 255), CFrame.new(-.1, .05, .15), Enum.Material.Neon, Enum.PartType.Ball).Transparency = .2
  local scr = P("Screen", TK.V3(.5, .18, .05), TK.RGB(10, 14, 10), CFrame.new(.3, -.2, -.53))
  local sg = TK.I("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(120, 40), LightInfluence = 0, Brightness = 2 }, scr)
  local lbl = TK.I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "100%", TextColor3 = TK.RGB(120, 255, 140),
    Font = Enum.Font.Code, TextScaled = true,
  }, sg)
  TK.I("PointLight", { Color = TK.RGB(190, 80, 255), Range = 9, Brightness = 2, Shadows = false }, h)
  return tool, lbl
end

-- пульт вызова крейсера
function TK.buildRemote()
  local tool = TK.I("Tool", { Name = "Пульт крейсера", RequiresHandle = true, CanBeDropped = false, ToolTip = "Вызвать / сесть / слезть" })
  local h = TK.mkp("Handle", TK.V3(.5, 1, .3), TK.RGB(55, 60, 68), Enum.Material.Metal)
  h.Parent = tool
  local function P(...) return TK.toolPart(tool, h, ...) end
  local scr = P("Screen", TK.V3(.38, .3, .04), TK.RGB(10, 20, 14), CFrame.new(0, .22, -.17), Enum.Material.Neon)
  scr.Color = TK.RGB(60, 255, 120)
  local sg = TK.I("SurfaceGui", { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(120, 90), LightInfluence = 0, Brightness = 2 }, scr)
  TK.I("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "SHIP", TextColor3 = TK.RGB(5, 40, 15),
    Font = Enum.Font.Code, TextScaled = true,
  }, sg)
  P("Button", TK.V3(.14, .22, .22), TK.RGB(255, 140, 40), CFrame.new(0, -.2, -.17) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  P("Antenna", TK.V3(.7, .05, .05), TK.RGB(30, 30, 34), CFrame.new(.15, .85, 0) * TK.R90, nil, Enum.PartType.Cylinder)
  P("Tip", TK.V3(.1, .1, .1), TK.RGB(255, 80, 80), CFrame.new(.15, 1.2, 0), Enum.Material.Neon, Enum.PartType.Ball)
  return tool
end

-- хват: убираем стандартный RightGrip и привариваем предмет к ладони скина
function TK.detachHand()
  TK.HOLDING = false
  TK.X.rec = (TK.X.rec or 0) + 1
  TK.X.gripC1 = nil
  if TK.gripW then pcall(function() TK.gripW:Destroy() end) TK.gripW = nil end
  if TK.gripC then TK.gripC:Disconnect() TK.gripC = nil end
end
function TK.attachHand(tool, off)
  TK.detachHand()
  if not TK.RIG or not TK.RIG.hand then return end -- без скина работает стандартный хват Roblox
  local handle = tool:FindFirstChild("Handle")
  local ch = TK.LP.Character
  if not handle or not ch then return end
  for _, o in ipairs(ch:GetDescendants()) do
    if o.Name == "RightGrip" then o:Destroy() end
  end
  TK.gripC = ch.DescendantAdded:Connect(function(o)
    if o.Name == "RightGrip" then task.defer(function() pcall(function() o:Destroy() end) end) end
  end)
  TK.gripW = Instance.new("Weld")
  TK.gripW.Name = "RM_Grip"
  TK.gripW.Part0 = TK.RIG.hand
  TK.gripW.Part1 = handle
  -- рука вытянута вперёд: «вниз» кисти смотрит вперёд, «вперёд» кисти смотрит вверх
  TK.gripW.C0 = CFrame.new(off or TK.V3()) * CFrame.Angles(-math.pi / 2, 0, 0)
  TK.gripW.Parent = TK.RIG.hand
  TK.X.gripC1 = TK.gripW.C1
  TK.HOLDING = true
end
function TK.refreshGrip() -- вернуть стандартный хват после снятия скина
  TK.detachHand()
  local ch, hum = TK.getChar()
  if hum and TK.heldTool and TK.heldTool.Parent == ch then
    task.defer(function()
      hum:UnequipTools()
      hum:EquipTool(TK.heldTool)
    end)
  end
end

-- ============================================================
--  ПРЕДМЕТЫ: действия
-- ============================================================
-- ❄ замораживатель времени: пузырь, экран в серых тонах, помощники замирают на 4 с
TK.ccStop = nil
function TK.timeStop()
  local now = os.clock()
  if now < TK.TS_CD then TK.notify("❄ Перезарядка " .. math.ceil(TK.TS_CD - now) .. " с", TK.C.dg, 1) return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  TK.TS_CD = now + 10
  TK.TIMESTOP_UNTIL = now + 4
  local bub = TK.I("Part", {
    Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.ForceField, Color = TK.RGB(120, 200, 255), Transparency = .25,
    Size = TK.V3(2, 2, 2), CFrame = hr.CFrame,
  }, TK.fxFolder)
  TK.TweenService:Create(bub, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = TK.V3(44, 44, 44) }):Play()
  task.delay(3.5, function()
    TK.TweenService:Create(bub, TweenInfo.new(.5), { Transparency = 1 }):Play()
    task.delay(.55, function() bub:Destroy() end)
  end)
  if not TK.ccStop or not TK.ccStop.Parent then TK.ccStop = TK.I("ColorCorrectionEffect", { Name = "RM_TimeStop" }, TK.Lighting) end
  TK.TweenService:Create(TK.ccStop, TweenInfo.new(.3), { Saturation = -.85, Contrast = .2, TintColor = TK.RGB(185, 225, 255) }):Play()
  task.delay(4, function()
    if TK.ccStop and TK.ccStop.Parent then
      TK.TweenService:Create(TK.ccStop, TweenInfo.new(.6), { Saturation = 0, Contrast = 0, TintColor = TK.WHITE }):Play()
    end
  end)
  for _, hp in ipairs(TK.helpers) do
    local hl = TK.I("Highlight", {
      FillColor = TK.RGB(150, 220, 255), FillTransparency = .5, OutlineColor = TK.WHITE, Adornee = hp.R.model,
    }, hp.R.model)
    task.delay(4, function() if hl.Parent then hl:Destroy() end end)
  end
  TK.snd("teleport", .7, .6)
  TK.notify("⏱ Время остановлено на 4 с", TK.RGB(150, 230, 255), 2)
end

-- 🟦 ящик Мисиксов: помощник бежит к точке прицела, «выполняет задание» и исчезает
TK.helperFolder = TK.I("Folder", { Name = "RM_Helpers" }, TK.Workspace)
TK.MEE_CATCH = {
  "Я Мистер Мисикс, посмотри на меня!", "Ооо, да, можно!", "Существование — это боль!",
  "Я выполню задание!", "Дай мне исчезнуть!",
}
function TK.spawnMeeseeks()
  if #TK.helpers >= 3 then TK.notify("Максимум 3 Мисикса сразу", TK.C.dg, 1.5) return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  local target = TK.aimHit(120)
  local far = target and (target - hr.Position).Magnitude > 8
  local lv = TK.V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
  lv = lv.Magnitude > .01 and lv.Unit or TK.V3(0, 0, -1)
  local ahead = hr.Position + lv * 5
  local gy = TK.groundAt(ahead) or (hr.Position.Y - 3)
  local pos = TK.V3(ahead.X, gy + 3, ahead.Z)
  local root = TK.mkp("MRoot", TK.V3(2, 2, 1), TK.WHITE)
  root.Transparency = 1
  root.Anchored = true
  root.CFrame = CFrame.lookAt(pos, pos + lv)
  local R = TK.newRig(root, TK.SK.meeseeks, 1)
  R.FT = TK.ftar(TK.SK.meeseeks, "happy")
  R.FC = TK.copy(R.FT)
  root.Parent = R.model
  R.model.Parent = TK.helperFolder
  TK.burst(pos, TK.RGB(90, 170, 255), 30)
  TK.helpers[#TK.helpers + 1] = {
    R = R, root = root, born = os.clock(), face = lv, state = far and "go" or "follow",
    target = target, life = far and 22 or 14,
  }
  TK.bubble(R.parts.Head, TK.MEE_CATCH[math.random(#TK.MEE_CATCH)], 2.8)
  TK.snd("teleport", .5, 1.6)
end
function TK.stepHelper(h, dt) -- false = удалить помощника
  local R, root = h.R, h.root
  if not root.Parent then return false end
  local _, _, hr = TK.getChar()
  if not hr then return true end
  local now = os.clock()
  if now < TK.TIMESTOP_UNTIL then
    h.born = h.born + dt
    return true
  end
  local pos = root.Position
  local goal, stopD, speed = nil, 5, 18
  if h.state == "go" then
    goal, stopD = h.target, 2.5
  elseif h.state == "follow" or h.state == "back" then
    goal = hr.Position
  end
  local moving = false
  if goal then
    local flat = TK.V3(goal.X - pos.X, 0, goal.Z - pos.Z)
    local dist = flat.Magnitude
    if dist > stopD then
      local dirv = flat.Unit
      pos = pos + dirv * math.min(dist - stopD, speed * dt)
      h.face = dirv
      moving = true
    elseif h.state == "go" then
      h.state = "work"
      h.workEnd = now + 2.4
      TK.bubble(R.parts.Head, "Готово! Можно мне исчезнуть?", 2.4)
    end
  end
  if h.state == "work" and now > h.workEnd then h.state = "back" end
  local gy = TK.groundAt(pos)
  local jump = (h.state == "work") and math.abs(math.sin(now * 7)) * 1.4 or 0
  local ty = (gy and gy + 3 or pos.Y) + jump
  pos = TK.V3(pos.X, pos.Y + (ty - pos.Y) * math.min(1, dt * 14), pos.Z)
  root.CFrame = CFrame.lookAt(pos, pos + TK.V3(h.face.X, 0, h.face.Z))
  TK.stepRig(R, dt, {
    speed = moving and speed or 0, walkSpeed = 16, air = false, emote = (h.state == "work") and "dance" or nil,
  })
  if now - h.born > h.life then
    TK.burst(pos, TK.RGB(90, 170, 255), 30)
    return false
  end
  return true
end

-- ============================================================
--  БОЙ: приказы Мисиксам, мишени, урон (всё визуально, ничего настоящего не меняется)
-- ============================================================
do
  local hpOf, deadUntil, dummies = {}, {}, {}
  local FIGHT_CATCH = { "Получай!", "За Рика!", "Ооо, дерёмся!", "Я тебя уничтожу!" }
  local ORDER_TEXT = {
    guard = "Я тебя защищу!", attack = "Я его побью!", move = "Иду туда!",
    follow = "Иду за тобой!", stay = "Стою на месте!", vanish = "Наконец-то!",
  }
  local ORDER_NAMES = {
    guard = "🛡 Мисиксы защищают", attack = "⚔ Мисиксы атакуют", move = "📍 Мисиксы идут на точку",
    follow = "🚶 Мисиксы идут за тобой", stay = "🛑 Мисиксы стоят", vanish = "💨 Мисиксы исчезают",
  }

  -- цель жива? (у NPC и игроков смотрим Health, у мишени свой счётчик)
  local function alive(tg)
    if not tg or not tg.model or not tg.model.Parent or not tg.root or not tg.root.Parent then return false end
    local du = deadUntil[tg.model]
    if du then
      if os.clock() < du then return false end
      deadUntil[tg.model], hpOf[tg.model] = nil, nil
    end
    if tg.kind ~= "dummy" then
      local hum = tg.model:FindFirstChildOfClass("Humanoid")
      if not hum or hum.Health <= 0 then return false end
    end
    return true
  end

  -- поиск целей: мишени, NPC и (если разрешено) игроки; себя не трогаем
  local op = OverlapParams.new()
  op.FilterType = Enum.RaycastFilterType.Exclude
  local function scan(center, radius)
    local list = {}
    for _, d in ipairs(dummies) do
      if alive(d) and (d.root.Position - center).Magnitude <= radius then list[#list + 1] = d end
    end
    op.FilterDescendantsInstances = { TK.LP.Character, TK.helperFolder }
    local ok, parts = pcall(function() return TK.Workspace:GetPartBoundsInRadius(center, radius, op) end)
    if ok then
      local seen = {}
      for _, p in ipairs(parts) do
        local m = p:FindFirstAncestorOfClass("Model")
        if m and not seen[m] and m ~= TK.LP.Character then
          seen[m] = true
          local hum = m:FindFirstChildOfClass("Humanoid")
          local root = m:FindFirstChild("HumanoidRootPart")
          if hum and root then
            local isPlayer = TK.Players:GetPlayerFromCharacter(m) ~= nil
            if not isPlayer then -- v6: настоящие игроки никогда не цели
              local tg = { model = m, root = root, kind = isPlayer and "player" or "npc" }
              if alive(tg) then list[#list + 1] = tg end
            end
          end
        end
      end
    end
    return list
  end
  local function nearest(list, pos)
    local best, bd = nil, 1e9
    for _, tg in ipairs(list) do
      local d = (tg.root.Position - pos).Magnitude
      if d < bd then best, bd = tg, d end
    end
    return best
  end

  -- эффекты удара: цифра урона, красная подсветка, искры (видишь только ты)
  local function dmgText(adornee, amount)
    local bb = TK.I("BillboardGui", {
      Size = UDim2.fromOffset(60, 24), StudsOffset = TK.V3((math.random() - .5) * 1.5, 2.5, 0),
      AlwaysOnTop = true, LightInfluence = 0,
    }, adornee)
    local l = TK.I("TextLabel", {
      Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "-" .. amount,
      TextColor3 = TK.RGB(255, 80, 80), TextStrokeTransparency = 0, Font = Enum.Font.GothamBold, TextSize = 18,
    }, bb)
    TK.TweenService:Create(bb, TweenInfo.new(.6), { StudsOffset = bb.StudsOffset + TK.V3(0, 2.5, 0) }):Play()
    TK.TweenService:Create(l, TweenInfo.new(.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
    task.delay(.65, function() bb:Destroy() end)
  end
  local function koDummy(d) -- мишень падает и через 5 с встаёт
    d.ko = true
    d.model:PivotTo(d.cf * CFrame.new(0, -2.9, 0) * CFrame.Angles(-1.45, 0, 0))
    task.delay(5, function()
      d.ko = false
      if d.model.Parent then d.model:PivotTo(d.cf) end
    end)
  end
  local function hitFx(tg, lo, hi) -- true, если цель добита (на экране)
    local dmg = math.random(lo or 8, hi or 15)
    hpOf[tg.model] = (hpOf[tg.model] or 100) - dmg
    dmgText(tg.root, dmg)
    TK.burst(tg.root.Position, TK.RGB(255, 200, 80), 8)
    local hl = TK.I("Highlight", {
      FillColor = TK.RGB(255, 70, 70), FillTransparency = .4, OutlineTransparency = 1, Adornee = tg.model,
    }, tg.model)
    task.delay(.12, function() if hl.Parent then hl:Destroy() end end)
    if tg.kind == "dummy" and not tg.ko then
      tg.model:PivotTo(tg.cf * CFrame.new((math.random() - .5) * .4, 0, (math.random() - .5) * .4))
      task.delay(.08, function() if tg.model.Parent and not tg.ko then tg.model:PivotTo(tg.cf) end end)
    end
    TK.snd("click", .4, 1.4)
    return hpOf[tg.model] <= 0
  end
  local function damage(tg, lo, hi) -- удар + обработка «победы»
    if not hitFx(tg, lo, hi) then return false end
    deadUntil[tg.model] = os.clock() + (tg.kind == "dummy" and 5 or 12)
    TK.burst(tg.root.Position, TK.RGB(255, 200, 80), 24)
    if tg.kind == "dummy" then koDummy(tg) end
    return true
  end
  TK.CB.scan, TK.CB.nearest, TK.CB.damage = scan, nearest, damage

  -- мишень для тренировки (стоит там, куда смотришь)
  local function spawnDummy()
    if #dummies >= 3 then TK.notify("Максимум 3 мишени", TK.C.dg, 1.5) return end
    local pos = TK.aimHit(60)
    local g = TK.groundAt(pos)
    pos = TK.V3(pos.X, g or pos.Y, pos.Z)
    local mo = TK.I("Model", { Name = "RM_Dummy" }, TK.helperFolder)
    local function add(n, sz, col, rel, mat, shape)
      local p = TK.mkp(n, sz, col, mat, shape)
      p.Anchored = true
      p.CFrame = CFrame.new(pos) * rel
      p.Parent = mo
      return p
    end
    add("Base", TK.V3(.4, 2.4, 2.4), TK.RGB(90, 70, 50), CFrame.new(0, .2, 0) * TK.R90, nil, Enum.PartType.Cylinder)
    add("Post", TK.V3(.5, 3.2, .5), TK.RGB(150, 110, 70), CFrame.new(0, 1.8, 0), Enum.Material.Wood)
    local body = add("Body", TK.V3(1.8, 2, .9), TK.RGB(205, 170, 90), CFrame.new(0, 3.6, 0), Enum.Material.Fabric)
    add("Arms", TK.V3(3.2, .4, .4), TK.RGB(150, 110, 70), CFrame.new(0, 4.1, 0), Enum.Material.Wood)
    add("Head", TK.V3(1.1, 1.1, 1.1), TK.RGB(220, 190, 120), CFrame.new(0, 5.1, 0), Enum.Material.Fabric, Enum.PartType.Ball)
    add("Ring1", TK.V3(.1, 1.2, 1.2), TK.RGB(220, 40, 40), CFrame.new(0, 3.6, -.46) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
    add("Ring2", TK.V3(.1, .8, .8), TK.WHITE, CFrame.new(0, 3.6, -.5) * TK.RZ, nil, Enum.PartType.Cylinder)
    add("Ring3", TK.V3(.1, .35, .35), TK.RGB(220, 40, 40), CFrame.new(0, 3.6, -.53) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
    mo.PrimaryPart = body
    dummies[#dummies + 1] = { model = mo, root = body, kind = "dummy", cf = mo:GetPivot() }
    TK.burst(pos + TK.V3(0, 2, 0), TK.RGB(255, 200, 80), 20)
    TK.notify("🎯 Мишень поставлена", TK.C.ac, 1.5)
  end
  RM.spawnDummy = function() TK.safe(spawnDummy) end
  RM.clearDummies = function()
    for i = #dummies, 1, -1 do
      pcall(function() dummies[i].model:Destroy() end)
      table.remove(dummies, i)
    end
  end

  -- ящик вызывает Мисикса-охранника
  TK.spawnMeeseeks = function()
    if #TK.helpers >= 3 then TK.notify("Максимум 3 Мисикса сразу", TK.C.dg, 1.5) return end
    local _, _, hr = TK.getChar()
    if not hr then return end
    local lv = TK.V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
    lv = lv.Magnitude > .01 and lv.Unit or TK.V3(0, 0, -1)
    local ahead = hr.Position + lv * 5
    local gy = TK.groundAt(ahead) or (hr.Position.Y - 3)
    local pos = TK.V3(ahead.X, gy + 3, ahead.Z)
    local root = TK.mkp("MRoot", TK.V3(2, 2, 1), TK.WHITE)
    root.Transparency = 1
    root.Anchored = true
    root.CFrame = CFrame.lookAt(pos, pos + lv)
    local R = TK.newRig(root, TK.SK.meeseeks, 1)
    R.FT = TK.ftar(TK.SK.meeseeks, "happy")
    R.FC = TK.copy(R.FT)
    root.Parent = R.model
    R.model.Parent = TK.helperFolder
    TK.burst(pos, TK.RGB(90, 170, 255), 30)
    TK.helpers[#TK.helpers + 1] = {
      R = R, root = root, born = os.clock(), face = lv, order = "guard", life = 90,
      slot = #TK.helpers, nextScan = 0, nextHit = 0,
    }
    TK.bubble(R.parts.Head, "Я Мистер Мисикс! Я тебя защищу!", 2.8)
    TK.snd("pop", .6)
    TK.ITM.spawnFx(pos)
  end

  -- поведение помощника: приказы, поиск врагов, бой
  local function step(h, dt)
    local R, root = h.R, h.root
    if not root.Parent then return false end
    local _, _, hr = TK.getChar()
    if not hr then return true end
    local now = os.clock()
    if now < TK.TIMESTOP_UNTIL then
      h.born = h.born + dt
      return true
    end
    local pos, P = root.Position, hr.Position
    local order = h.order
    -- поиск цели (охрана бьёт только NPC и мишени; игроков — только по приказу «Атакуй»)
    if (order == "guard" or order == "attack") and not alive(h.target) then
      h.target = nil
      if now >= h.nextScan then
        h.nextScan = now + .6
        local center, radius = P, 32
        if order == "attack" then center, radius = h.orderPos or P, 26 end
        h.target = nearest(scan(center, radius), pos)
        if h.target then TK.bubble(R.parts.Head, FIGHT_CATCH[math.random(#FIGHT_CATCH)], 1.8) end
      end
    end
    local tg = h.target
    -- слишком далеко от хозяина: возвращаем к нему
    if (order == "guard" or order == "follow") and (pos - P).Magnitude > 80 then
      local a = h.slot * 2.094
      pos = P + TK.V3(math.cos(a), 0, math.sin(a)) * 6
      TK.burst(pos, TK.RGB(90, 170, 255), 20)
      h.target, tg = nil, nil
    end
    -- куда идти
    local goal, stopD, speed = nil, 1.5, 20
    if tg then
      goal, stopD, speed = tg.root.Position, 3.2, 24
    elseif order == "guard" then
      local a = h.slot * 2.094
      goal = P + TK.V3(math.cos(a), 0, math.sin(a)) * 6
    elseif order == "follow" then
      goal, stopD = P, 5
    elseif order == "attack" or order == "move" then
      goal, stopD = h.orderPos or P, 2.5
    end
    local moving, inRange = false, false
    if goal then
      local flat = TK.V3(goal.X - pos.X, 0, goal.Z - pos.Z)
      local dist = flat.Magnitude
      if dist > stopD then
        local dirv = flat.Unit
        pos = pos + dirv * math.min(dist - stopD, speed * dt)
        h.face = dirv
        moving = true
      else
        inRange = true
        if tg and dist > .05 then h.face = flat.Unit end
      end
    end
    -- пришёл на место
    if inRange and not tg then
      if order == "move" then
        h.order = "stay"
        TK.bubble(R.parts.Head, "Я на месте!", 2)
      elseif order == "attack" then
        h.order = "guard"
        TK.bubble(R.parts.Head, h.fought and "Победа! Возвращаюсь!" or "Тут никого нет...", 2.2)
        h.fought = false
      end
    end
    -- удар
    local fighting = tg ~= nil and inRange
    if fighting and now >= h.nextHit then
      h.nextHit = now + .45
      if damage(tg, 8, 15) then
        TK.bubble(R.parts.Head, "Победа!", 1.6)
        h.target = nil
        h.fought = true
      end
    end
    -- земля, поворот, анимация
    local gy = TK.groundAt(pos)
    local ty = gy and gy + 3 or pos.Y
    pos = TK.V3(pos.X, pos.Y + (ty - pos.Y) * math.min(1, dt * 14), pos.Z)
    root.CFrame = CFrame.lookAt(pos, pos + TK.V3(h.face.X, 0, h.face.Z))
    TK.stepRig(R, dt, { speed = moving and speed or 0, walkSpeed = 16, air = false })
    if fighting then -- кулаки: руки бьют по очереди
      local ph = now * 7 + h.slot
      local p1, p2 = math.max(0, math.sin(ph)), math.max(0, math.sin(ph + math.pi))
      local mt, bs = R.mot, R.base
      mt.AR.C0 = bs.AR * CFrame.Angles(.2 + 1.4 * p1, 0, .1)
      mt.ER.C0 = bs.ER * CFrame.Angles(.3 - .3 * p1, 0, 0)
      mt.AL.C0 = bs.AL * CFrame.Angles(.2 + 1.4 * p2, 0, -.1)
      mt.EL.C0 = bs.EL * CFrame.Angles(.3 - .3 * p2, 0, 0)
      mt.Torso.C0 = mt.Torso.C0 * CFrame.Angles(0, (p2 - p1) * .35, 0)
    end
    if now - h.born > h.life then
      TK.burst(pos, TK.RGB(90, 170, 255), 30)
      return false
    end
    return true
  end
  TK.stepHelper = function(h, dt)
    local ok, res = pcall(step, h, dt)
    if not ok then
      warn("[RickMorty] Мисикс: " .. tostring(res))
      return false
    end
    return res
  end

  -- приказ всем Мисиксам (цель = точка прицела)
  RM.helperOrder = function(order)
    if #TK.helpers == 0 then TK.notify("Сначала вызови Мисикса ящиком", TK.C.dg, 2) return end
    local pos = TK.aimHit(120)
    local now = os.clock()
    local target = nil
    if order == "attack" then
      target = nearest(scan(pos, 26), pos)
      if not target then TK.notify("Рядом с точкой прицела целей нет", TK.C.dg, 2) end
    end
    for _, h in ipairs(TK.helpers) do
      h.born, h.life = now, 90
      h.order, h.orderPos, h.target, h.fought, h.nextScan = order, pos, target, false, 0
      if order == "vanish" then
        h.born = now - 1000
      else
        TK.bubble(h.R.parts.Head, ORDER_TEXT[order], 2)
      end
    end
    TK.notify(ORDER_NAMES[order], TK.C.ac, 1.5)
  end
end

-- 🔋 батарея: зона энергии 15 секунд; заряд не расходуется в Toolkit 7.0.
function TK.useBattery()
  local _, _, hr = TK.getChar()
  if not hr then return end
  TK.BAT = 100
  local pos = TK.aimHit(70)
  if (pos - hr.Position).Magnitude > 60 then pos = hr.Position + (pos - hr.Position).Unit * 60 end
  local g = TK.groundAt(pos)
  pos = TK.V3(pos.X, g or pos.Y, pos.Z)
  local col = TK.RGB(190, 80, 255)
  local mo = TK.I("Model", { Name = "RM_Zone" }, TK.Workspace)
  local disc = TK.mkp("Zone", TK.V3(.3, 20, 20), col, Enum.Material.Neon, Enum.PartType.Cylinder)
  disc.Anchored = true
  disc.Transparency = .65
  disc.CFrame = CFrame.new(pos + TK.V3(0, .2, 0)) * TK.R90
  disc.Parent = mo
  local ring = TK.mkp("ZoneRing", TK.V3(.4, 20.6, 20.6), col:Lerp(TK.WHITE, .4), Enum.Material.Neon, Enum.PartType.Cylinder)
  ring.Anchored = true
  ring.Transparency = .4
  ring.CFrame = disc.CFrame
  ring.Parent = mo
  local em = TK.mkp("Emitter", TK.V3(18, .2, 18), col)
  em.Anchored = true
  em.Transparency = 1
  em.CFrame = CFrame.new(pos + TK.V3(0, .4, 0))
  em.Parent = mo
  TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 18, Lifetime = NumberRange.new(1.5, 2),
    Speed = NumberRange.new(4, 6), SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(.5, 0),
    Transparency = NumberSequence.new(.1, 1), LightEmission = 1, Color = ColorSequence.new(col),
    EmissionDirection = Enum.NormalId.Top,
  }, em)
  TK.I("PointLight", { Color = col, Range = 22, Brightness = 2, Shadows = false }, disc)
  TK.TweenService:Create(disc, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = .82 }):Play()
  TK.zones[#TK.zones + 1] = { mo = mo, disc = disc, radius = 10, untilT = os.clock() + 15 }
  TK.burst(pos + TK.V3(0, 1, 0), col, 30)
  TK.snd("teleport", .6, .8)
  TK.notify("🔋 Зона энергии создана на 15 с", col, 2)
end
function TK.updateZones(hr, now)
  local inside = false
  for i = #TK.zones, 1, -1 do
    local zn = TK.zones[i]
    if now > zn.untilT then
      table.remove(TK.zones, i)
      TK.TweenService:Create(zn.disc, TweenInfo.new(.5), { Transparency = 1 }):Play()
      task.delay(.6, function() pcall(function() zn.mo:Destroy() end) end)
    elseif hr then
      local off = hr.Position - zn.disc.Position
      if TK.V3(off.X, 0, off.Z).Magnitude < zn.radius and math.abs(off.Y) < 10 then inside = true end
    end
  end
  if inside ~= TK.inZone then
    TK.inZone = inside
    local aura = hr and hr:FindFirstChild("RM_Aura")
    if inside and hr then
      if not aura then
        TK.I("PointLight", { Name = "RM_Aura", Color = TK.RGB(200, 90, 255), Range = 14, Brightness = 3, Shadows = false }, hr)
      end
      TK.notify("⚡ Ты в зоне энергии", TK.RGB(200, 120, 255), 1.5)
    elseif aura then
      aura:Destroy()
    end
  end
end

-- 🚀 космический крейсер по фото (серая тарелка, купол, жёлтые полосы, двигатель, ножки)
TK.SHIP_H = 3.7 -- высота центра корпуса над землёй (скорость берётся из ST.ShipSpeed)
TK.SEAT = CFrame.new(0, 1.75, .5)
function TK.ell(model, name, size, col, rel, mat) -- эллипсоид через SpecialMesh
  local p = TK.mkp(name, size, col, mat)
  p.Anchored = true
  p.CFrame = rel
  TK.I("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, p)
  p.Parent = model
  return p
end
function TK.buildShip()
  local model = TK.I("Model", { Name = "RM_Cruiser" }, TK.Workspace)
  local function add(name, size, col, rel, mat, shape)
    local p = TK.mkp(name, size, col, mat, shape)
    p.Anchored = true
    p.CFrame = rel
    p.Parent = model
    return p
  end
  local GRAY, LIGHT, DARK, YEL = TK.RGB(88, 96, 104), TK.RGB(185, 192, 200), TK.RGB(40, 44, 50), TK.RGB(235, 190, 40)
  local hull = TK.ell(model, "Hull", TK.V3(11, 3.2, 11), GRAY, CFrame.new(0, -.2, 0), Enum.Material.Metal)
  model.PrimaryPart = hull
  add("Rim", TK.V3(.9, 12, 12), LIGHT, CFrame.new(0, .3, 0) * TK.R90, Enum.Material.Metal, Enum.PartType.Cylinder)
  TK.ell(model, "Deck", TK.V3(9.5, 1.8, 9.5), TK.RGB(170, 176, 184), CFrame.new(0, .9, 0), Enum.Material.Metal)
  for _, s in ipairs({ -1, 1 }) do
    add("Stripe", TK.V3(1.2, .1, 3.6), YEL, CFrame.new(s * 3.2, 1.3, -2.4) * CFrame.Angles(0, math.rad(-30 * s), 0))
    TK.ell(model, "Vent", TK.V3(1.4, .7, 1.1), TK.RGB(200, 185, 140), CFrame.new(s * 2.6, 1.15, -3.6))
    add("Light", TK.V3(.6, .2, .2), TK.RGB(255, 240, 150), CFrame.new(s * 1.2, .5, -5.3), Enum.Material.Neon)
  end
  add("StripeBack", TK.V3(3, .1, .9), YEL, CFrame.new(0, 1.15, 4.4))
  local dome = TK.ell(model, "Dome", TK.V3(5.2, 3.6, 6.4), TK.RGB(190, 230, 255), CFrame.new(0, 2.4, -.6), Enum.Material.Glass)
  dome.Transparency = .5
  add("Seat", TK.V3(1.5, .3, 1.5), TK.RGB(70, 58, 52), CFrame.new(0, 1.15, .5))
  add("SeatBack", TK.V3(1.5, 1.6, .3), TK.RGB(70, 58, 52), CFrame.new(0, 2, 1.3))
  add("Console", TK.V3(2.2, .5, .8), DARK, CFrame.new(0, 1.5, -1.7))
  for _, s in ipairs({ -1, 1 }) do
    add("Screen", TK.V3(.5, .3, .05), TK.RGB(90, 240, 220), CFrame.new(s * .6, 1.85, -2.05), Enum.Material.Neon)
    add("Lever", TK.V3(.08, .7, .08), DARK, CFrame.new(s * .95, 1.9, -1.4))
  end
  add("Engine", TK.V3(2.6, 2.4, 2.4), TK.RGB(120, 126, 132), CFrame.new(0, 1, 5.7) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
  add("EngineIn", TK.V3(.2, 1.8, 1.8), TK.RGB(10, 10, 12), CFrame.new(0, 1, 7) * TK.RZ, nil, Enum.PartType.Cylinder)
  local glow = add("EngineGlow", TK.V3(.1, 1.2, 1.2), TK.RGB(120, 200, 255), CFrame.new(0, 1, 7.05) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  TK.I("ParticleEmitter", {
    Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 15, Lifetime = NumberRange.new(.4, .7),
    Speed = NumberRange.new(6, 9), Size = NumberSequence.new(.9, 0), LightEmission = 1, Color = ColorSequence.new(TK.RGB(120, 200, 255)),
    EmissionDirection = Enum.NormalId.Back,
  }, glow)
  add("Wing", TK.V3(7, .25, 1.8), GRAY, CFrame.new(0, 3, 5.2))
  add("WingPanel", TK.V3(2.2, .06, 1.2), TK.RGB(240, 150, 40), CFrame.new(-2, 3.15, 5.2))
  for _, s in ipairs({ -1, 1 }) do
    add("Support", TK.V3(.3, 1.6, .3), DARK, CFrame.new(s * 2.5, 2.2, 5.2))
  end
  for i = 0, 3 do -- четыре ножки с опорами
    local a = math.rad(45 + i * 90)
    local x, z = math.sin(a) * 3.8, math.cos(a) * 3.8
    add("Leg", TK.V3(.35, 2.6, .35), DARK, CFrame.new(x, -1.9, z) * CFrame.Angles(math.sin(a) * .0, 0, 0))
    add("Foot", TK.V3(.9, .4, 1.1), TK.RGB(30, 32, 38), CFrame.new(x * 1.12, -3.25, z * 1.12) * CFrame.Angles(0, a, 0))
  end
  TK.I("PointLight", { Color = TK.RGB(180, 220, 255), Range = 18, Brightness = 1.5, Shadows = false }, hull)
  -- большие пушки по бокам (дула смотрят вперёд)
  for _, s in ipairs({ -1, 1 }) do
    add("CannonBase", TK.V3(1.8, .9, 1.8), DARK, CFrame.new(s * 3.2, .35, -3.6), Enum.Material.Metal)
    add("Cannon", TK.V3(4.2, 1.3, 1.3), TK.RGB(70, 76, 86), CFrame.new(s * 3.2, .7, -4.8) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
    add("CannonRing", TK.V3(.5, 1.8, 1.8), YEL, CFrame.new(s * 3.2, .7, -6.7) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
    add("CannonGlow", TK.V3(.2, 1, 1), TK.RGB(255, 90, 60), CFrame.new(s * 3.2, .7, -6.95) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  end
  -- твёрдые части (на них можно стоять) и кликабельность всего корабля
  local solids = {}
  for _, p in ipairs(model:GetChildren()) do
    p.CanQuery = true
    local nm = p.Name
    if nm == "Hull" or nm == "Rim" or nm == "Deck" or nm == "Wing" or nm == "Engine" or nm == "Foot" then
      solids[#solids + 1] = p
    end
  end
  return model, dome, solids
end
function TK.summonShip()
  local _, _, hr = TK.getChar()
  if not hr then return end
  if TK.RIDING or (TK.ship and TK.ship.board) then TK.dismount(true) end
  if TK.ship then pcall(function() TK.ship.model:Destroy() end) TK.ship = nil end
  local lv = TK.V3(hr.CFrame.LookVector.X, 0, hr.CFrame.LookVector.Z)
  lv = lv.Magnitude > .01 and lv.Unit or TK.V3(0, 0, -1)
  local ahead = hr.Position + lv * 18
  local gy = TK.groundAt(ahead) or (hr.Position.Y - 3)
  local land = TK.V3(ahead.X, gy + TK.SHIP_H, ahead.Z)
  local model, dome, solids = TK.buildShip()
  TK.ship = {
    model = model, dome = dome, solids = solids, land = land, pos = land + TK.V3(0, 60, 0),
    yaw = math.atan2(-lv.X, -lv.Z), vel = TK.V3(), state = "landing", t = 0, cf = CFrame.new(land),
  }
  model:PivotTo(CFrame.new(TK.ship.pos) * CFrame.Angles(0, TK.ship.yaw, 0))
  TK.dimFx(TK.RGB(255, 170, 70), .6)
  TK.notify("🚀 Крейсер прибывает...", TK.C.ac, 2)
end
-- твёрдость: пока корабль стоит, на него можно залезть и стоять на палубе
function TK.SH.solid(on) end -- физическая твёрдость отключена: корабль не толкает игроков
-- купол открывается на шарнире сзади (open: 0..1)
function TK.SH.dome(open)
  if not TK.ship or not TK.ship.dome or not TK.ship.dome.Parent then return end
  TK.ship.dome.CFrame = TK.ship.cf * CFrame.new(0, 2.4, -.6) * CFrame.new(0, 0, 3.2)
    * CFrame.Angles(open * .9, 0, 0) * CFrame.new(0, 0, -3.2)
end
-- пушки крейсера: красные болты в точку прицела, урон по цели рядом (визуально)
function TK.SH.fireOld()
  if not TK.RIDING or not TK.ship or TK.ship.board then return end
  local now = os.clock()
  if now < TK.SH.fireCd then return end
  TK.SH.fireCd = now + .22
  local pos = TK.aimHit(800)
  TK.SH.side = -TK.SH.side
  local muzzle = (TK.ship.cf * CFrame.new(TK.SH.side * 3.2, .2, -4.4)).Position
  local delta = pos - muzzle
  local dist = delta.Magnitude
  if dist < 2 then return end
  local dir = delta.Unit
  local len = math.min(dist, 7)
  local bolt = TK.mkp("Bolt", TK.V3(.4, .4, len), TK.RGB(255, 70, 70), Enum.Material.Neon)
  bolt.Anchored = true
  bolt.CFrame = CFrame.lookAt(muzzle, muzzle + dir) * CFrame.new(0, 0, -len / 2)
  bolt.Parent = TK.Workspace
  local fly = math.clamp(dist / 500, .05, .5)
  TK.TweenService:Create(bolt, TweenInfo.new(fly, Enum.EasingStyle.Linear), {
    CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, len / 2),
  }):Play()
  TK.snd("shoot", .5, 1.3)
  task.delay(fly, function()
    bolt:Destroy()
    TK.burst(pos, TK.RGB(255, 120, 60), 16)
    local tg = TK.CB.nearest(TK.CB.scan(pos, 7), pos)
    if tg then TK.CB.damage(tg, 20, 35) end
  end)
end
-- виртуальный пол палубы: ставит тебя на крышу корабля, не толкает ни тебя, ни других
TK.SH.onDeck = false
function TK.SH.deck(hr, hum)
  TK.SH.onDeck = false
  if not TK.ship or TK.ship.state ~= "idle" or TK.RIDING or TK.ship.board or not hr or not hum then return end
  local off = hr.Position - TK.ship.pos
  if TK.V3(off.X, 0, off.Z).Magnitude > 4.6 then return end
  local half = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + hr.Size.Y / 2) or 3
  local feet = hr.Position.Y - half
  local top = TK.ship.pos.Y + 1.8
  local vel = hr.AssemblyLinearVelocity
  if vel.Y <= 1 and feet >= top - .7 and feet <= top + .5 then
    hr.CFrame = hr.CFrame + TK.V3(0, top - feet, 0)
    if hum.Jump then
      local jv = hum.UseJumpPower and hum.JumpPower or math.sqrt(2 * TK.Workspace.Gravity * hum.JumpHeight)
      hr.AssemblyLinearVelocity = TK.V3(vel.X, jv, vel.Z)
    else
      hr.AssemblyLinearVelocity = TK.V3(vel.X, 0, vel.Z)
    end
    TK.SH.onDeck = true
  end
end
-- большие пушки: крупные болты, дальность x5, взрыв со сферой
function TK.SH.fire()
  if not TK.RIDING or not TK.ship or TK.ship.board then return end
  local now = os.clock()
  if now < TK.SH.fireCd then return end
  TK.SH.fireCd = now + .28
  local pos = TK.aimHit(4000, 250)
  TK.SH.side = -TK.SH.side
  local muzzle = (TK.ship.cf * CFrame.new(TK.SH.side * 3.2, .7, -7.2)).Position
  local delta = pos - muzzle
  local dist = delta.Magnitude
  if dist < 2 then return end
  local dir = delta.Unit
  local len = math.min(dist, 16)
  local bolt = TK.mkp("Bolt", TK.V3(1.3, 1.3, len), TK.RGB(255, 70, 70), Enum.Material.Neon)
  bolt.Anchored = true
  TK.I("PointLight", { Color = TK.RGB(255, 80, 60), Range = 22, Brightness = 4, Shadows = false }, bolt)
  bolt.CFrame = CFrame.lookAt(muzzle, muzzle + dir) * CFrame.new(0, 0, -len / 2)
  bolt.Parent = TK.Workspace
  local fly = math.clamp(dist / 900, .05, 1.2)
  TK.TweenService:Create(bolt, TweenInfo.new(fly, Enum.EasingStyle.Linear), {
    CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, len / 2),
  }):Play()
  TK.burst(muzzle, TK.RGB(255, 200, 80), 14)
  TK.snd("shoot", .7, .9)
  task.delay(fly, function()
    bolt:Destroy()
    TK.burst(pos, TK.RGB(255, 120, 60), 40)
    local ex = TK.mkp("Blast", TK.V3(2, 2, 2), TK.RGB(255, 140, 60), Enum.Material.Neon, Enum.PartType.Ball)
    ex.Anchored = true
    ex.Transparency = .3
    ex.Position = pos
    ex.Parent = TK.Workspace
    TK.TweenService:Create(ex, TweenInfo.new(.4), { Size = TK.V3(16, 16, 16), Transparency = 1 }):Play()
    task.delay(.45, function() ex:Destroy() end)
    local tg = TK.CB.nearest(TK.CB.scan(pos, 14), pos)
    if tg then TK.CB.damage(tg, 40, 70) end
  end)
end
-- гипер-прыжок: рывок вперёд с эффектом перехода между измерениями
function TK.SH.hyper()
  if not TK.RIDING or not TK.ship or TK.ship.board then return end
  local now = os.clock()
  if now < TK.SH.hyperCd then TK.notify("🌌 Гипер-прыжок через " .. math.ceil(TK.SH.hyperCd - now) .. " с", TK.C.dg, 1) return end
  TK.SH.hyperCd = now + 6
  local fwd = CFrame.Angles(0, TK.ship.yaw, 0).LookVector
  local dist = math.clamp(TK.ST.ShipSpeed * .8, 120, 600)
  local col = TK.RGB(160, 120, 255)
  TK.dimFx(col, 1.2)
  for i = 1, 6 do TK.burst(TK.ship.pos + fwd * (dist * i / 6), col, 10) end
  TK.ship.pos = TK.ship.pos + fwd * dist
  TK.ship.vel = fwd * math.max(TK.ship.vel.Magnitude, TK.ST.ShipSpeed * .5)
  TK.notify("🌌 Гипер-прыжок!", col, 1.5)
end

-- посадка: тап по кораблю или кнопка; персонаж прыгает в кабину, купол открывается
function TK.board()
  local _, hum, hr = TK.getChar()
  if not TK.ship or TK.RIDING or TK.ship.board or not hum or not hr then return end
  if TK.ship.state ~= "idle" then TK.notify("Крейсер ещё садится", TK.C.dg, 1.5) return end
  local dist = (hr.Position - TK.ship.pos).Magnitude
  if dist > 90 then TK.notify("Крейсер далеко: вызови его", TK.C.dg, 2) return end
  TK.EMOTE = nil
  hum.PlatformStand = true
  TK.SH.solid(false)
  TK.ship.vel = TK.V3()
  TK.ship.board = { kind = "in", t = 0, dur = .95, from = hr.CFrame, arc = 3 + dist * .04 }
  TK.snd("teleport", .5, 1.5)
  TK.notify("🚀 Полёт: джойстик/WASD, ▲▼, 🔥 — огонь, 🌌 — прыжок", TK.C.ac, 3)
end
-- высадка с прыжком; instant = мгновенно (смерть, пересоздание корабля)
function TK.dismount(instant)
  local _, hum, hr = TK.getChar()
  if not TK.ship then
    TK.RIDING = false
    if hum then hum.PlatformStand = false end
    return
  end
  if instant then
    TK.RIDING = false
    TK.ship.board = nil
    TK.rideKeys.up, TK.rideKeys.down = false, false
    if hum then hum.PlatformStand = false end
    if hr then
      hr.CFrame = CFrame.new(TK.ship.pos) * CFrame.Angles(0, TK.ship.yaw, 0) * CFrame.new(7, 2.2, 0)
      hr.AssemblyLinearVelocity = TK.V3()
    end
    TK.SH.solid(true)
    return
  end
  if not TK.RIDING or TK.ship.board or not hr then return end
  TK.RIDING = false
  TK.rideKeys.up, TK.rideKeys.down = false, false
  TK.ship.vel = TK.V3()
  TK.ship.board = {
    kind = "out", t = 0, dur = .85, from = hr.CFrame, arc = 3.5,
    to = CFrame.new(TK.ship.pos) * CFrame.Angles(0, TK.ship.yaw, 0) * CFrame.new(7, 2.2, 0),
  }
end
function TK.shipAction()
  local _, _, hr = TK.getChar()
  if not hr then return end
  if TK.RIDING then TK.dismount() return end
  if not TK.ship then TK.summonShip() return end
  if TK.ship.state == "idle" and (hr.Position - TK.ship.pos).Magnitude < 90 then TK.board() else TK.summonShip() end
end
function TK.stepShip(dt)
  if not TK.ship or not TK.ship.model.Parent then TK.SH.onDeck = false return end
  local _, hum, hr = TK.getChar()
  if (TK.RIDING or TK.ship.board) and (not hum or hum.Health <= 0 or not hr) then TK.dismount(true) end
  if TK.SH.held and TK.RIDING and not TK.ship.board then TK.SH.fire() end
  local now = os.clock()
  local pitch, roll = 0, 0
  if TK.ship.state == "landing" then
    TK.ship.t = TK.ship.t + dt
    local a = math.min(1, TK.ship.t / 1.5)
    a = 1 - (1 - a) ^ 3
    TK.ship.pos = TK.V3(TK.ship.land.X, TK.ship.land.Y + (1 - a) * 60, TK.ship.land.Z)
    if TK.ship.t >= 1.5 then
      TK.ship.state = "idle"
      TK.SH.solid(true)
    end
  elseif TK.RIDING and not TK.ship.board and hum then
    local speed = TK.ST.ShipSpeed
    local md = hum.MoveDirection
    local vy = (TK.rideKeys.up and 1 or 0) - (TK.rideKeys.down and 1 or 0)
    if TK.apControl then md, vy = TK.apControl(md, vy, dt) end -- v6: автопилот (ручное управление главнее)
    local want = TK.V3(md.X * speed, vy * math.max(40, speed * .6), md.Z * speed)
    TK.ship.vel = TK.ship.vel:Lerp(want, math.min(1, dt * 2.5))
    TK.ship.pos = TK.ship.pos + TK.ship.vel * dt
    local gy = TK.groundAt(TK.ship.pos)
    if gy and TK.ship.pos.Y < gy + TK.SHIP_H then
      TK.ship.pos = TK.V3(TK.ship.pos.X, gy + TK.SHIP_H, TK.ship.pos.Z)
      if TK.ship.vel.Y < 0 then TK.ship.vel = TK.V3(TK.ship.vel.X, 0, TK.ship.vel.Z) end
    end
    if md.Magnitude > .15 then
      local ty = math.atan2(-md.X, -md.Z)
      local diff = (ty - TK.ship.yaw + math.pi) % (2 * math.pi) - math.pi
      TK.ship.yaw = TK.ship.yaw + diff * math.min(1, dt * 4)
    end
    local lv = CFrame.Angles(0, TK.ship.yaw, 0):VectorToObjectSpace(TK.ship.vel)
    pitch = lv.Z / speed * .25
    roll = -lv.X / speed * .3
  end
  local bobY = TK.RIDING and math.sin(now * 2) * .12 or 0
  TK.ship.cf = CFrame.new(TK.ship.pos + TK.V3(0, bobY, 0)) * CFrame.Angles(0, TK.ship.yaw, 0) * CFrame.Angles(pitch, 0, roll)
  TK.ship.model:PivotTo(TK.ship.cf)
  TK.SH.deck(hr, hum)
  local open = 0
  local b = TK.ship.board
  if b and hr then
    -- анимация посадки/высадки: дуга прыжка, купол открывается и закрывается
    b.t = b.t + dt
    local u = math.min(1, b.t / b.dur)
    local e = u * u * (3 - 2 * u)
    local target = (b.kind == "in") and (TK.ship.cf * TK.SEAT) or b.to
    hr.CFrame = b.from:Lerp(target, e) + TK.V3(0, math.sin(math.pi * e) * b.arc, 0)
    hr.AssemblyLinearVelocity = TK.V3()
    open = (u < .2) and (u / .2) or ((u < .75) and 1 or (1 - u) / .25)
    TK.ship.boardW = math.sin(math.pi * u)
    if u >= 1 then
      TK.ship.board, TK.ship.boardW = nil, nil
      if b.kind == "in" then
        TK.RIDING = true
      else
        if hum then hum.PlatformStand = false end
        TK.SH.solid(true)
      end
    end
  elseif TK.RIDING and hr then
    hr.CFrame = TK.ship.cf * TK.SEAT
    hr.AssemblyLinearVelocity = TK.V3()
    hr.AssemblyAngularVelocity = TK.V3()
  end
  TK.SH.dome(open)
end
TK.track(TK.RunService.RenderStepped:Connect(function(dt)
  local ok, e = pcall(TK.stepShip, dt)
  if not ok then
    TK.SH.errs = (TK.SH.errs or 0) + 1
    if TK.SH.errs <= 3 then warn("[RickMorty] ошибка крейсера: " .. tostring(e)) end
  end
end))

-- панель управления полётом: ▲ ▼ 🌌 и кнопка слезть
TK.ridePanel = TK.I("Frame", {
  Size = UDim2.fromOffset(70, 212), Position = UDim2.new(1, -90, 1, -350), BackgroundTransparency = 1,
  Visible = false, ZIndex = 58,
}, TK.gui)
function TK.rideBtn(txt, y, key, fn)
  local b = TK.I("TextButton", {
    Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(0, y), BackgroundColor3 = TK.C.bg, BackgroundTransparency = .15,
    TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 26, Text = txt, ZIndex = 59,
  }, TK.ridePanel)
  TK.cr(b, 16)
  TK.sk(b, TK.C.ac, 1.5, .3)
  if key then
    b.MouseButton1Down:Connect(function() TK.rideKeys[key] = true end)
    b.MouseButton1Up:Connect(function() TK.rideKeys[key] = false end)
    b.MouseLeave:Connect(function() TK.rideKeys[key] = false end)
  end
  if fn then b.MouseButton1Click:Connect(fn) end
end
TK.rideBtn("▲", 0, "up")
TK.rideBtn("▼", 72, "down")
TK.rideBtn("🌌", 144, nil, function() TK.SH.hyper() end)
TK.dismountBtn = TK.I("TextButton", {
  Size = UDim2.fromOffset(120, 40), Position = UDim2.new(.5, -60, 0, 12), BackgroundColor3 = TK.C.bg, BackgroundTransparency = .15,
  TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 13, Text = "🚪 Слезть", Visible = false, ZIndex = 59,
}, TK.gui)
TK.cr(TK.dismountBtn, 10)
TK.sk(TK.dismountBtn, TK.C.ac, 1.5, .3)
TK.dismountBtn.MouseButton1Click:Connect(function() TK.dismount() end)
-- клавиши: Space/Shift — вверх/вниз, H — гипер-прыжок, зажатая ЛКМ — огонь
TK.track(TK.UIS.InputBegan:Connect(function(i, gpe)
  if gpe then return end
  if i.KeyCode == Enum.KeyCode.Space then TK.rideKeys.up = true end
  if i.KeyCode == Enum.KeyCode.LeftShift then TK.rideKeys.down = true end
  if i.KeyCode == Enum.KeyCode.H then TK.SH.hyper() end
  if i.UserInputType == Enum.UserInputType.MouseButton1 and TK.RIDING then TK.SH.held = true end
end))
TK.track(TK.UIS.InputEnded:Connect(function(i)
  if i.KeyCode == Enum.KeyCode.Space then TK.rideKeys.up = false end
  if i.KeyCode == Enum.KeyCode.LeftShift then TK.rideKeys.down = false end
  if i.UserInputType == Enum.UserInputType.MouseButton1 then TK.SH.held = false end
end))
-- тап/клик по кораблю: сразу садимся
TK.track(TK.UIS.InputBegan:Connect(function(i, gpe)
  if gpe or not TK.ship or TK.RIDING or TK.ship.board or TK.ship.state ~= "idle" then return end
  if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
  local r = TK.Workspace.CurrentCamera:ViewportPointToRay(i.Position.X, i.Position.Y)
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { TK.LP.Character }
  local res = TK.Workspace:Raycast(r.Origin, r.Direction * 300, rp)
  if res and res.Instance:IsDescendantOf(TK.ship.model) then TK.board() end
end))

-- ============================================================
--  ПРЕДМЕТЫ: список и выдача
-- ============================================================
-- ============================================================
--  НОВЫЕ ПРЕДМЕТЫ v5.0: генератор Мисиксов, шлем Рика, энергощит
-- ============================================================
function TK.miniTool(name, tip, hsize, hcol)
  local tool = TK.I("Tool", { Name = name, RequiresHandle = true, CanBeDropped = false, ToolTip = tip })
  local h = TK.mkp("Handle", hsize, hcol, Enum.Material.Metal)
  h.Parent = tool
  return tool, h, function(...) return TK.toolPart(tool, h, ...) end
end

-- 🟦 генератор Мисиксов: ручной излучатель с голубым ядром
function TK.ITM.buildGen()
  local tool, _, P = TK.miniTool("Генератор Мисиксов", "Создать помощника", TK.V3(.5, 1.1, .5), TK.RGB(40, 70, 72))
  local BL = TK.RGB(90, 180, 255)
  P("Body", TK.V3(.9, .8, 1.3), TK.RGB(60, 110, 108), CFrame.new(0, .7, -.45), Enum.Material.Metal)
  P("Ring", TK.V3(.14, 1.1, 1.1), TK.RGB(30, 40, 44), CFrame.new(0, .7, -1.15) * TK.RZ, Enum.Material.Metal, Enum.PartType.Cylinder)
  local core = P("Core", TK.V3(.3, .75, .75), BL, CFrame.new(0, .7, -1.2) * TK.RZ, Enum.Material.Neon, Enum.PartType.Cylinder)
  core.Transparency = .15
  TK.I("PointLight", { Color = BL, Range = 9, Brightness = 2, Shadows = false }, core)
  P("Btn", TK.V3(.12, .4, .4), TK.RGB(120, 250, 180), CFrame.new(0, 1.15, -.3) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  for _, s in ipairs({ -1, 1 }) do
    P("Coil", TK.V3(.1, .6, .1), TK.RGB(150, 220, 255), CFrame.new(s * .5, .75, -.9), Enum.Material.Neon)
  end
  return tool
end
function TK.ITM.genFx(tool)
  if not tool then return end
  local c = tool:FindFirstChild("Core", true)
  if c then TK.pulsePart(c, .6, TK.WHITE) end
  TK.lightSpike(tool, 6)
end

-- 🪖 шлем Рика: надевается на голову скина (или персонажа), снимается второй активацией
function TK.headPart()
  if TK.RIG and TK.RIG.parts and TK.RIG.parts.Head and TK.RIG.parts.Head.Parent then return TK.RIG.parts.Head end
  local ch = TK.LP.Character
  return ch and ch:FindFirstChild("Head")
end
function TK.ITM.buildHelmetTool()
  local tool, h, P = TK.miniTool("Шлем Рика", "Надеть / снять шлем", TK.V3(.8, .8, .8), TK.RGB(170, 175, 185))
  h.Shape = Enum.PartType.Ball
  P("Glass", TK.V3(1.05, 1.05, 1.05), TK.RGB(150, 220, 255), CFrame.new(0, .05, 0), Enum.Material.Glass, Enum.PartType.Ball).Transparency = .6
  P("Collar", TK.V3(.12, 1, 1), TK.RGB(120, 125, 135), CFrame.new(0, -.45, 0) * TK.R90, Enum.Material.Metal, Enum.PartType.Cylinder)
  return tool
end
function TK.helmetModel(head)
  local m = TK.I("Model", { Name = "RM_Helmet" }, TK.Workspace)
  local root = TK.mkp("HRoot", TK.V3(.2, .2, .2), TK.WHITE)
  root.Transparency = 1
  root.Massless = true
  root.Parent = m
  local w = Instance.new("Weld")
  w.Part0, w.Part1, w.C0 = head, root, CFrame.new(0, .1, 0)
  w.Parent = root
  local function add(name, size, col, mat, shape, cf, tr)
    local p = TK.mkp(name, size, col, mat, shape)
    p.Massless = true
    if tr then p.Transparency = tr end
    p.CFrame = root.CFrame * cf
    local ww = Instance.new("Weld")
    ww.Part0, ww.Part1, ww.C0 = root, p, cf
    ww.Parent = p
    p.Parent = m
    return p
  end
  local hs = head.Size
  local r = math.max(hs.X, hs.Y, hs.Z) * 1.25
  add("Dome", TK.V3(r, r, r), TK.RGB(150, 220, 255), Enum.Material.Glass, Enum.PartType.Ball, CFrame.new(), .65)
  add("Collar", TK.V3(.25, r * .82, r * .82), TK.RGB(120, 125, 135), Enum.Material.Metal, Enum.PartType.Cylinder,
    CFrame.new(0, -r * .42, 0) * TK.R90)
  add("Light", TK.V3(.18, .18, .18), TK.RGB(255, 240, 150), Enum.Material.Neon, Enum.PartType.Ball, CFrame.new(r * .46, r * .1, -r * .18))
  add("Light", TK.V3(.18, .18, .18), TK.RGB(255, 240, 150), Enum.Material.Neon, Enum.PartType.Ball, CFrame.new(-r * .46, r * .1, -r * .18))
  TK.I("PointLight", { Color = TK.RGB(180, 230, 255), Range = 8, Brightness = 1, Shadows = false }, root)
  return m, root
end
function TK.ITM.removeHelmet(fast)
  local m = TK.X.helmet
  TK.X.helmet, TK.X.helmetHead = nil, nil
  if m and m.Parent then
    if fast then
      pcall(function() m:Destroy() end)
    else
      for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HRoot" then
          pcall(function() TK.TweenService:Create(d, TweenInfo.new(.25), { Transparency = 1 }):Play() end)
        end
      end
      task.delay(.3, function() pcall(function() m:Destroy() end) end)
    end
  end
end
function TK.ITM.wearHelmet()
  local head = TK.headPart()
  if not head then return false end
  TK.ITM.removeHelmet(true)
  TK.X.helmet = TK.helmetModel(head)
  TK.X.helmetHead = head
  return true
end
function TK.ITM.toggleHelmet()
  if TK.X.helmet and TK.X.helmet.Parent then
    TK.ITM.removeHelmet()
    TK.snd("equip", .4, .8)
    TK.notify("🪖 Шлем снят", TK.C.tx, 1.2)
  else
    if TK.ITM.wearHelmet() then
      local h = TK.headPart()
      if h then TK.burst(h.Position, TK.RGB(150, 220, 255), 14) end
      TK.snd("equip", .5, 1.1)
      TK.notify("🪖 Шлем надет", TK.C.ac, 1.2)
    else
      TK.notify("Нет головы для шлема", TK.C.dg, 1.5)
    end
  end
end
function TK.ITM.stepHelmet()
  if not TK.X.helmet then return end
  local head = TK.headPart()
  if not TK.X.helmet.Parent or not head then TK.ITM.removeHelmet(true) return end
  if head ~= TK.X.helmetHead then -- скин сменился: перевешиваем шлем на новую голову
    TK.ITM.wearHelmet()
  end
  local cam = TK.Workspace.CurrentCamera
  if cam and TK.X.helmet then -- от первого лица стекло не мешает
    local near = (cam.CFrame.Position - head.Position).Magnitude < 1.6
    for _, d in ipairs(TK.X.helmet:GetDescendants()) do
      if d:IsA("BasePart") then d.LocalTransparencyModifier = near and 1 or 0 end
    end
  end
end

-- 🛡 энергощит: прозрачный купол вокруг тебя на 8 с, перезарядка 12 с
function TK.ITM.buildShieldTool()
  local tool, _, P = TK.miniTool("Энергощит", "Включить щит на 8 с", TK.V3(.5, 1, .5), TK.RGB(45, 55, 80))
  local BL = TK.RGB(110, 190, 255)
  P("Body", TK.V3(.8, .7, .8), TK.RGB(80, 95, 130), CFrame.new(0, .6, -.2), Enum.Material.Metal)
  local o = P("Orb", TK.V3(.7, .7, .7), BL, CFrame.new(0, 1.15, -.2), Enum.Material.Neon, Enum.PartType.Ball)
  o.Transparency = .25
  TK.I("PointLight", { Color = BL, Range = 9, Brightness = 2, Shadows = false }, o)
  P("Ring", TK.V3(.1, 1, 1), TK.RGB(150, 220, 255), CFrame.new(0, .95, -.2) * TK.R90, Enum.Material.Neon, Enum.PartType.Cylinder)
  return tool
end
function TK.ITM.dropShield()
  local s = TK.X.shield
  TK.X.shield, TK.X.shieldUntil = nil, 0
  if s and s.Parent then
    TK.TweenService:Create(s, TweenInfo.new(.3), { Size = TK.V3(2, 2, 2), Transparency = 1 }):Play()
    task.delay(.35, function() pcall(function() s:Destroy() end) end)
  end
end
function TK.ITM.toggleShield()
  local now = os.clock()
  if TK.X.shield then TK.ITM.dropShield() TK.snd("close", .4) return end
  if now < (TK.X.shieldCd or 0) then TK.notify("🛡 Перезарядка " .. math.ceil(TK.X.shieldCd - now) .. " с", TK.C.dg, 1) return end
  local _, _, hr = TK.getChar()
  if not hr then return end
  TK.X.shieldCd = now + 12
  TK.X.shieldUntil = now + 8
  local s = TK.I("Part", {
    Name = "RM_Shield", Shape = Enum.PartType.Ball, Anchored = true, CanCollide = false, CanQuery = false,
    CanTouch = false, CastShadow = false, Material = Enum.Material.ForceField, Color = TK.RGB(110, 190, 255),
    Transparency = .45, Size = TK.V3(2, 2, 2), CFrame = hr.CFrame,
  }, TK.Workspace)
  TK.X.shield = s
  TK.TweenService:Create(s, TweenInfo.new(.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = TK.V3(9, 9, 9) }):Play()
  TK.burst(hr.Position, TK.RGB(110, 190, 255), 16)
  TK.snd("open", .5, 1.3)
  TK.notify("🛡 Щит включён (8 с)", TK.RGB(150, 210, 255), 1.5)
end
function TK.ITM.stepShield(now, hr)
  local s = TK.X.shield
  if not s then return end
  if not s.Parent or not hr or now > TK.X.shieldUntil then TK.ITM.dropShield() return end
  s.CFrame = hr.CFrame
  if TK.X.shieldUntil - now < 1.5 then s.Transparency = .45 + (math.floor(now * 10) % 2) * .3 end
end

-- эффекты появления / исчезновения Мисикса
function TK.ITM.spawnFx(pos, col)
  col = col or TK.RGB(90, 170, 255)
  local beam = TK.I("Part", {
    Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = .3, Size = TK.V3(9, 4, 4),
    CFrame = CFrame.new(pos) * TK.R90,
  }, TK.fxFolder)
  TK.TweenService:Create(beam, TweenInfo.new(.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = TK.V3(9, .2, .2), Transparency = 1,
  }):Play()
  task.delay(.7, function() beam:Destroy() end)
  local ring = TK.I("Part", {
    Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
    CastShadow = false, Material = Enum.Material.Neon, Color = col, Transparency = .2, Size = TK.V3(.15, 2, 2),
    CFrame = CFrame.new(pos - TK.V3(0, 2.5, 0)) * TK.R90,
  }, TK.fxFolder)
  TK.TweenService:Create(ring, TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = TK.V3(.15, 12, 12), Transparency = 1,
  }):Play()
  task.delay(.8, function() ring:Destroy() end)
  TK.burst(pos, col, 30)
end
function TK.ITM.vanishFx(h)
  local ok, p = pcall(function() return h.root.Position end)
  if ok and p then
    TK.burst(p, TK.RGB(90, 170, 255), 28)
    TK.ITM.spawnFx(p)
    TK.snd("vanish", .4)
  end
end

TK.ITEMS = {
  { id = "gun_rick", ico = "🔫", name = "Портальная пушка Рика", desc = "Классическая пушка Рика", build = TK.buildGunRick, act = function() TK.shootPortal("rick") end, grip = TK.V3(0, -.05, 0) },
  { id = "gun_prime", ico = "🔫", name = "Портальная пушка Рика Прайма", desc = "Пушка Рика Прайма", build = TK.buildGunPrime, act = function() TK.shootPortal("rick_prime") end, grip = TK.V3(0, -.05, 0) },
  { id = "gun_evil", ico = "🔫", name = "Портальная пушка Злого Морти", desc = "Золотая пушка Злого Морти", build = TK.buildGunEvil, act = function() TK.shootPortal("evil_morty") end, grip = TK.V3(0, -.05, 0) },
  { id = "freeze", ico = "❄", name = "Замораживатель времени", desc = "Пузырь и стоп-кадр на 4 с", build = TK.buildFreezer, act = TK.timeStop, fx = function(t) TK.pulsePart(t:FindFirstChild("Core", true), .6, TK.WHITE) TK.lightSpike(t, 6) end, grip = TK.V3(0, -.1, 0) },
  { id = "meeseeks", ico = "🟦", name = "Ящик Мисиксов", desc = "Вызывает помощника", build = TK.buildMeeseeksBox, act = TK.spawnMeeseeks, grip = TK.V3(0, -.55, -.15) },
  { id = "battery", ico = "🔋", name = "Батарея микровселенной", desc = "Зона энергии 15 с", build = TK.buildBattery, act = TK.useBattery, fx = function(t) TK.lightSpike(t, 7) end, grip = TK.V3(0, -.5, -.1) },
  { id = "ship", ico = "🚀", name = "Пульт крейсера", desc = "Вызвать, сесть, лететь", build = TK.buildRemote, act = TK.shipAction, grip = TK.V3(0, -.05, 0) },
  { id = "mee_gen", ico = "🧪", name = "Генератор Мисиксов", desc = "Помощник с эффектом появления", build = TK.ITM.buildGen, act = TK.spawnMeeseeks, fx = TK.ITM.genFx, grip = TK.V3(0, -.1, 0) },
  { id = "helmet", ico = "🪖", name = "Шлем Рика", desc = "Надеть / снять (активация)", build = TK.ITM.buildHelmetTool, act = TK.ITM.toggleHelmet, grip = TK.V3(0, -.1, 0) },
  { id = "shield", ico = "🛡", name = "Энергощит", desc = "Купол на 8 с, откат 12 с", build = TK.ITM.buildShieldTool, act = TK.ITM.toggleShield, grip = TK.V3(0, -.1, 0) },
}
TK.createdTools, TK.toolByDef = {}, {}
function TK.dropTool(tool)
  local cs = TK.createdTools[tool]
  if cs then
    for _, c in ipairs(cs) do pcall(function() c:Disconnect() end) end
    TK.createdTools[tool] = nil
  end
  for id, t in pairs(TK.toolByDef) do
    if t == tool then TK.toolByDef[id] = nil end
  end
  if TK.heldTool == tool then
    TK.heldTool, TK.heldDef, TK.ITEM_ACT, TK.batLabel = nil, nil, nil, nil
    TK.detachHand()
  end
end
function TK.ITM.purge() -- забыть предметы, которые пропали (смерть, респавн, Destroy)
  for tool in pairs(TK.createdTools) do
    local par = tool.Parent
    if not par or (par ~= TK.LP.Backpack and par ~= TK.LP.Character) then
      TK.dropTool(tool)
    end
  end
  if TK.heldTool and not TK.heldTool.Parent then TK.dropTool(TK.heldTool) end
end
function TK.giveItem(def)
  local _, hum = TK.getChar()
  if not hum or hum.Health <= 0 then TK.notify("Нет персонажа", TK.C.dg) return end
  local old = TK.toolByDef[def.id]
  if old and old.Parent then -- предмет уже есть: просто берём в руку, дубли не создаём
    hum:EquipTool(old)
    TK.notify(def.ico .. " " .. def.name .. " (уже есть)", TK.C.tx, 1.2)
    return
  end
  local ok, tool, extra = pcall(def.build)
  if not ok or not tool then TK.notify("Не удалось создать предмет", TK.C.dg) return end
  tool.Name = def.name
  if def.id:sub(1, 4) == "gun_" then TK.applyGunSkin(tool) end
  local cs = {}
  TK.createdTools[tool] = cs
  TK.toolByDef[def.id] = tool
  tool.Parent = TK.LP.Backpack
  cs[#cs + 1] = tool.Activated:Connect(function()
    if TK.heldTool == tool then
      TK.safe(def.act)
      if def.fx then TK.safe(def.fx, tool) end
    end
  end)
  cs[#cs + 1] = tool.Equipped:Connect(function()
    TK.heldTool, TK.heldDef, TK.ITEM_ACT = tool, def, def.act
    if def.id == "battery" then TK.batLabel = extra else TK.batLabel = nil end
    TK.snd("equip", .25)
    task.defer(function()
      if tool.Parent == TK.LP.Character then TK.attachHand(tool, def.grip) end
    end)
  end)
  cs[#cs + 1] = tool.Unequipped:Connect(function()
    if TK.heldTool == tool then
      TK.heldTool, TK.heldDef, TK.ITEM_ACT, TK.batLabel = nil, nil, nil, nil
      TK.detachHand()
    end
  end)
  hum:EquipTool(tool)
  TK.notify(def.ico .. " " .. def.name, TK.C.ac)
end
-- кнопка 🔥 на телефоне стреляет предметом в руке
RM.fireFromAim = function()
  if TK.RIDING then TK.SH.fire() return end
  if TK.ITEM_ACT then TK.ITEM_ACT() else TK.shootPortal() end
end
function TK.clearAll()
  if RM.clearDummies then pcall(RM.clearDummies) end
  TK.detachHand()
  for tool in pairs(TK.createdTools) do
    pcall(function() tool:Destroy() end)
    TK.dropTool(tool)
  end
  TK.toolByDef = {}
  TK.heldTool, TK.heldDef, TK.ITEM_ACT, TK.batLabel = nil, nil, nil, nil
  TK.ITM.removeHelmet(true)
  TK.ITM.dropShield()
  for i = #TK.helpers, 1, -1 do
    pcall(function() TK.helpers[i].R.model:Destroy() end)
    table.remove(TK.helpers, i)
  end
  for i = #TK.zones, 1, -1 do
    pcall(function() TK.zones[i].mo:Destroy() end)
    table.remove(TK.zones, i)
  end
  if TK.RIDING or (TK.ship and TK.ship.board) then pcall(TK.dismount, true) end
  if TK.ship then pcall(function() TK.ship.model:Destroy() end) TK.ship = nil end
  pcall(function()
    TK.ridePanel.Visible = false
    TK.dismountBtn.Visible = false
  end)
  TK.killPortal(TK.PA, true)
  TK.killPortal(TK.PB, true)
  TK.PA, TK.PB = nil, nil
  for i = #TK.DYING, 1, -1 do
    pcall(function() TK.DYING[i].mo:Destroy() end)
    table.remove(TK.DYING, i)
  end
  pcall(function() TK.fxFolder:ClearAllChildren() end)
end


-- ============================================================
--  СКИНЫ ОРУЖИЯ (8 штук по заданию): перекраска деталей по ролям, форма пушек не меняется
-- ============================================================
TK.GSK = {
  { id = "classic", name = "Classic", ru = "Классика", ico = "⚙️" },
  { id = "neon_green", name = "Neon Green", ru = "Неоновый зелёный", ico = "🟢", glow = TK.RGB(60, 255, 90), acc = TK.RGB(120, 255, 160), body = TK.RGB(205, 225, 205) },
  { id = "purple_energy", name = "Purple Energy", ru = "Фиолетовая энергия", ico = "🟣", glow = TK.RGB(170, 90, 255), acc = TK.RGB(230, 100, 255), body = TK.RGB(205, 195, 225) },
  { id = "golden", name = "Golden", ru = "Золотая", ico = "🟡", glow = TK.RGB(255, 220, 80), acc = TK.RGB(255, 180, 40), body = TK.RGB(225, 195, 110) },
  { id = "cosmic", name = "Cosmic", ru = "Космическая", ico = "🌌", glow = TK.RGB(120, 140, 255), acc = TK.RGB(255, 110, 220), body = TK.RGB(45, 45, 90) },
  { id = "technology", name = "Technology", ru = "Технологичная", ico = "🔧", glow = TK.RGB(0, 230, 255), acc = TK.RGB(255, 140, 0), body = TK.RGB(90, 100, 115) },
  { id = "quantum", name = "Quantum", ru = "Квантовая", ico = "⚛️", glow = TK.RGB(235, 255, 255), acc = TK.RGB(80, 255, 230), body = TK.RGB(160, 170, 190) },
  { id = "dark_matter", name = "Dark Matter", ru = "Тёмная материя", ico = "🕳", glow = TK.RGB(150, 40, 230), acc = TK.RGB(20, 20, 30), body = TK.RGB(35, 30, 45) },
}
TK.GSK_BY = {}
for _, s in ipairs(TK.GSK) do TK.GSK_BY[s.id] = s end
TK.GROLE = {}
for n in ("Core CoreTop Dome DomeTop Bubble1 Bubble2 Bubble3 EmitGlow RingGlow Led Orb Jar LensCore"):gmatch("%S+") do TK.GROLE[n] = "glow" end
for n in ("PinkLine Corner FlangeGlow Switch Button SlabLine"):gmatch("%S+") do TK.GROLE[n] = "acc" end
for n in ("Body BodyTop Slab SlabEdge Block BlockEdge Grip HandleBar HandleCap Strut Slope"):gmatch("%S+") do TK.GROLE[n] = "body" end
function TK.gunSkin() return TK.GSK_BY[TK.ST.GunSkin] or TK.GSK[1] end
function TK.gunSkinCol(gunId)
  local s = TK.gunSkin()
  if s.id == "classic" then return nil end
  return s.glow
end
function TK.applyGunSkin(tool, skin)
  local s = skin or TK.gunSkin()
  if s.id == "classic" then return end
  for _, d in ipairs(tool:GetDescendants()) do
    if d:IsA("BasePart") then
      local role = TK.GROLE[d.Name] or (d.Name:sub(1, 4) == "Dot_" and "glow") or nil
      if role == "glow" then d.Color = s.glow elseif role == "acc" then d.Color = s.acc elseif role == "body" then d.Color = s.body end
      if role then TK.FXO[d] = nil end
    elseif d:IsA("PointLight") then
      d.Color = s.glow
      TK.FXO[d] = nil
    end
  end
end
function TK.setGunSkin(id)
  if not TK.GSK_BY[id] then return end
  TK.ST.GunSkin = id
  TK.save()
  for _, def in ipairs(TK.ITEMS) do -- уже выданные пушки перекрашиваем сразу
    if def.id:sub(1, 4) == "gun_" then
      local t = TK.toolByDef[def.id]
      if t and t.Parent then
        local fresh = def.build()
        for _, d in ipairs(t:GetChildren()) do
          if d.Name ~= "Handle" then d:Destroy() end
        end
        local h = t:FindFirstChild("Handle")
        for _, d in ipairs(fresh:GetChildren()) do
          if d.Name ~= "Handle" then
            d.Parent = t
            local w = d:FindFirstChildOfClass("Weld")
            if w and h then w.Part0 = h end
          end
        end
        fresh:Destroy()
        TK.applyGunSkin(t)
      end
    end
  end
  local s = TK.GSK_BY[id]
  TK.notify("🎨 Скин оружия: " .. s.ru, s.glow or TK.C.ac, 1.5)
end

TK.onUnload(function() pcall(function() TK.helperFolder:Destroy() end) end)

-- ============================================================
--  ВКЛАДКИ ЧАСТИ 2
-- ============================================================
function TK.itemById(id)
  for _, d in ipairs(TK.ITEMS) do if d.id == id then return d end end
end
function TK.itemModel(def, skin)
  local ok, tool = pcall(def.build)
  if not ok or not tool then return nil end
  if def.id:sub(1, 4) == "gun_" then TK.applyGunSkin(tool, skin) end
  return TK.toolToModel(tool)
end
-- выбор из списка + предпросмотр + кнопка действия
function TK.pickPanel(f, h, entries, modelOf, actions)
  local pv = TK.newPreview(f, h)
  local cur = entries[1].id
  local btns = {}
  local function show(id)
    cur = id
    for _, e in ipairs(entries) do
      if e.id == id then
        local ok, m = pcall(modelOf, e)
        if ok and m then pv.set(m, e.name .. (e.sub and (" — " .. e.sub) or "")) else pv.set(nil) end
      end
    end
    for k, b in pairs(btns) do b.BackgroundColor3 = (k == id) and TK.C.ac3 or TK.C.bg2 end
  end
  local gr = TK.newGrid(f, 2)
  for _, e in ipairs(entries) do
    btns[e.id] = TK.newBtn(gr, e.name, TK.C.bg2, function() show(e.id) end, 34)
    btns[e.id].TextSize = 10
  end
  for _, a in ipairs(actions) do
    TK.newBtn(f, a[1], a[3] or TK.C.ac, function() a[2](cur, show) end, 36)
  end
  return { show = show, get = function() return cur end }
end

TK.sect("items", function(f)
  TK.newSec(f, "ПРЕДМЕТЫ TOOLKIT (пушки и гаджеты в этом разделе)")
  local entries = {}
  for _, d in ipairs(TK.ITEMS) do entries[#entries + 1] = { id = d.id, name = d.ico .. " " .. d.name, sub = d.desc, def = d } end
  TK.pickPanel(f, 150, entries, function(e) return TK.itemModel(e.def) end, {
    { "🎒 Взять предмет", function(id) TK.giveItem(TK.itemById(id)) end },
  })
  TK.newBtn(f, "🗑 Убрать всё (предметы, помощники, корабль)", TK.C.dg, function()
    TK.clearAll()
    TK.notify("🗑 Всё убрано", TK.C.tx)
  end, 36)
  TK.newInfo(f, "\n  Экипируй предмет и нажми ЛКМ или 🔥 на телефоне.\n  Зона батареи — 15 с (без расхода заряда), щит — 8 с,\n  замораживатель времени — 4 с. Всё видишь только ты.", 76)
end)
TK.sect("portals", function(f)
  TK.newSec(f, "ПОРТАЛЫ A / B")
  TK.newBtn(f, "🔥 Создать портал (куда смотришь)", TK.C.ac, function() TK.shootPortal() end, 40)
  TK.newBtn(f, "🗑 Закрыть оба портала", TK.C.dg, function()
    TK.killPortal(TK.PA)
    TK.killPortal(TK.PB)
    TK.PA, TK.PB = nil, nil
    TK.notify("🗑 Порталы закрыты", TK.C.tx)
  end, 34)
  TK.newBtn(f, "🌌 Тест эффекта перехода", TK.C.bg2, function() TK.dimFx(nil, 1) end, 34)
  TK.newBtn(f, "📍 Портал в выбранную сохранённую точку", TK.C.bg2, function()
    if TK.portalAtSavedPoint then TK.portalAtSavedPoint() else TK.notify("Система координат ещё не загружена", TK.C.dg, 1.5) end
  end, 36)
  TK.newBtn(f, "🧩 Создать тестовую модель для порталов", TK.C.bg2, function()
    if TK.propsSpawnModel then TK.propsSpawnModel() end
  end, 34)
  TK.newSec(f, "НАСТРОЙКИ ПОРТАЛОВ")
  local PC = {
    { "🟢 Зелёный", { R = 50, G = 255, B = 50 } }, { "🔵 Синий", { R = 50, G = 150, B = 255 } },
    { "🟣 Фиолетовый", { R = 180, G = 50, B = 255 } }, { "🟡 Жёлтый", { R = 255, G = 220, B = 50 } },
    { "🔴 Красный", { R = 255, G = 60, B = 60 } },
  }
  local function pidx()
    local c = TK.ST.PortalColor
    for i, p in ipairs(PC) do
      if p[2].R == c.R and p[2].G == c.G and p[2].B == c.B then return i end
    end
    return 1
  end
  local pb
  pb = TK.newBtn(f, "", TK.C.bg2, function()
    local i = pidx() % #PC + 1
    TK.ST.PortalColor = { R = PC[i][2].R, G = PC[i][2].G, B = PC[i][2].B }
    TK.save()
    pb.Text = "🎨 Цвет порталов: " .. PC[i][1]
  end, 34)
  pb.Text = "🎨 Цвет порталов: " .. PC[pidx()][1]
  TK.addRefresh(function() pb.Text = "🎨 Цвет порталов: " .. PC[pidx()][1] end)
  TK.newSlider(f, "📏 Размер порталов", 3, 10, TK.ST.PortalSize, function(v) TK.ST.PortalSize = v TK.setPortalSize(v) end, TK.save, 1)
  TK.newNum(f, "⏱ Время жизни", "PortalLife", 10, function(v) TK.PORTAL_LIFE = v end, " с")
  TK.newInfo(f, "\n  Через порталы проходят твой персонаж и тестовые физические блоки Toolkit.\n  Перенос блока сохраняет его поворот и скорость. Другие игроки и\n  серверные объекты требуют поддержки самой игры.\n  1-й выстрел — A, 2-й — B, дальше заменяется старейший.", 100)
end)
TK.sect("guns", function(f)
  TK.newSec(f, "ПОРТАЛЬНЫЕ ПУШКИ (не зависят от скина персонажа)")
  local entries = {
    { id = "gun_rick", name = "🔫 Пушка Рика", sub = "дальность 1000", def = TK.itemById("gun_rick") },
    { id = "gun_prime", name = "🔫 Пушка Рика Прайма", sub = "дальность 10000", def = TK.itemById("gun_prime") },
    { id = "gun_evil", name = "🔫 Пушка Злого Морти", sub = "дальность 700", def = TK.itemById("gun_evil") },
  }
  TK.pickPanel(f, 160, entries, function(e) return TK.itemModel(e.def) end, {
    { "🎒 Взять пушку", function(id) TK.giveItem(TK.itemById(id)) end },
    { "🔥 Выстрелить порталом", function() TK.shootPortal() end, TK.C.bg2 },
  })
  TK.newInfo(f, "\n  Это те же предметы, что во вкладке «Предметы» (без дублей).\n  Анимация выстрела у каждой пушки своя.", 56)
end)
TK.sect("wskin", function(f)
  TK.newSec(f, "СКИНЫ ОРУЖИЯ (8) — для всех трёх пушек")
  local gunDefs = { TK.itemById("gun_rick"), TK.itemById("gun_prime"), TK.itemById("gun_evil") }
  local gi = 1
  local entries = {}
  for _, s in ipairs(TK.GSK) do entries[#entries + 1] = { id = s.id, name = s.ico .. " " .. s.name, sub = s.ru, skin = s } end
  local P
  P = TK.pickPanel(f, 160, entries, function(e) return TK.itemModel(gunDefs[gi], e.skin) end, {
    { "✅ Применить скин", function(id) TK.setGunSkin(id) end },
    { "↩ Вернуть Classic", function(_, show) TK.setGunSkin("classic") show("classic") end, TK.C.bg2 },
  })
  TK.newBtn(f, "🔁 Показать на другой пушке", TK.C.bg2, function()
    gi = gi % #gunDefs + 1
    P.show(P.get())
  end, 32)
  TK.newStatus(f, function()
    return "  Сейчас применён: " .. TK.gunSkin().name .. " (" .. TK.gunSkin().ru .. ")"
  end, 28)
end)
TK.sect("robots", function(f)
  TK.newSec(f, "МИСИКСЫ (система 3, помощники V5)")
  TK.newBtn(f, "🟦 Ящик Мисиксов", TK.C.ac, function() TK.giveItem(TK.itemById("meeseeks")) end, 36)
  TK.newBtn(f, "🧪 Генератор Мисиксов", TK.C.bg2, function() TK.giveItem(TK.itemById("mee_gen")) end, 36)
  local og = TK.newGrid(f, 2)
  TK.newBtn(og, "🛡 Защищай меня", TK.C.ac, function() RM.helperOrder("guard") end, 36)
  TK.newBtn(og, "⚔ Бей мишень", TK.C.bg2, function() RM.helperOrder("attack") end, 36)
  TK.newBtn(og, "📍 Иди туда", TK.C.bg2, function() RM.helperOrder("move") end, 36)
  TK.newBtn(og, "🚶 За мной", TK.C.bg2, function() RM.helperOrder("follow") end, 36)
  TK.newBtn(og, "🛑 Стой", TK.C.bg2, function() RM.helperOrder("stay") end, 36)
  TK.newBtn(og, "💨 Исчезни", TK.C.dg, function() RM.helperOrder("vanish") end, 36)
  TK.newBtn(f, "🎯 Поставить мишень (куда смотришь)", TK.C.bg2, function() RM.spawnDummy() end, 34)
  TK.newBtn(f, "🗑 Убрать мишени", TK.C.bg2, function() RM.clearDummies() end, 34)
  TK.newStatus(f, function() return "  Мисиксов сейчас: " .. #TK.helpers .. "  (лимит по производительности)" end, 28)
  TK.newInfo(f, "\n  Мисиксы бьют только твои мишени и NPC-манекены.\n  Настоящих игроков они не трогают и не выбирают целью.", 56)
end)
TK.sect("ship", function(f)
  TK.newSec(f, "КОСМИЧЕСКИЙ КРЕЙСЕР РИКА")
  TK.newNum(f, "🚀 Скорость", "ShipSpeed", 50, nil)
  TK.newBtn(f, "🚀 Вызвать крейсер", TK.C.ac, TK.summonShip, 36)
  TK.newBtn(f, "🪑 Сесть", TK.C.bg2, TK.board, 34)
  TK.newBtn(f, "🚪 Слезть", TK.C.bg2, TK.dismount, 34)
  TK.newBtn(f, "📟 Пульт крейсера (взять)", TK.C.bg2, function() TK.giveItem(TK.itemById("ship")) end, 34)
  TK.newInfo(f, "\n  Тап по кораблю сажает. На телефоне: 🔥 огонь, 🌌 прыжок,\n  ↑ ↓ высота. Полёт локальный — сервер корабль не видит.", 62)
end)
RM._part2 = true
