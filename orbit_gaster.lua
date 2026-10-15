-- ORBIT v25.3 | orbit_gaster.lua
-- 16 частей тела + ловушки + босс-файт + белое оружие.
-- v25.2-fix10: бластер босса парит рядом с головой (сбоку + спереди),
--              смотрит на игрока, высота 8.
-- v25.3:
--   * Ходьба через ORBIT.figureRig (колени, махи рук, наклон, голова, дыхание,
--     плащ отстаёт при беге). Старые collectLegs/playWalkAnim удалены.
--   * 7 атак вместо 4: + Молния (AoE сверху), Тёмный взрыв (AoE вокруг босса;
--     один раз при 50% HP, затем в ротации фазы 3), Костяной дождь (8 костей).
--   * A.battle (orbit_abilities v25.1): ярость, аура, статистика, slow-mo, награды.
--     recordDamage — ТОЛЬКО с "boss"; урон игроку A.battle ловит сам (HealthChanged).
--   * Хук fireId с защитами G.hooked / G._wrapper (стек с хуком Санса не ломается);
--     unhookDamage вызывается ПЕРВЫМ в destroy.
--   * Фикс: награда gaster_weapon никогда не показывалась в уведомлениях
--     (флаг ставился до проверки). Теперь список given, как у Санса.
--   * Фикс: Heartbeat оружия/эффектов отключается в destroy.
--   * Фикс: фраза attackWords никогда не показывалась (голова искалась у HRP).
--   * Вспышка attackWords — один переиспользуемый ScreenGui (G.flashFrame).
--   * Подсказка управления оружием делится по UIS.TouchEnabled.
--   * UI через uiParent() (ORBIT.getSafeParent), страховка по имени в destroy.
-- v25.3-fix1: guard A.battle в G.destroy и G.reset — через isActive()/bossId()
--   вместо несуществующих полей B.active/B.boss.
-- v25.3-fix2: переход на A.battle от Клода — guard по полям B.active/B.boss
--   вместо методов isActive()/bossId().
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] gaster: нет ORBIT"); return false end
if ORBIT.gaster and ORBIT.gaster.destroy then pcall(ORBIT.gaster.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local WS = game:GetService("Workspace")
local UIS_W = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local PT_BLOCK, PT_BALL, MAT = Enum.PartType.Block, Enum.PartType.Ball, Enum.Material
local PT_CYL = Enum.PartType.Cylinder

local COL_BEAM   = C3(255, 255, 255)
local COL_CHARGE = C3(240, 250, 255)
local COL_GLOW   = C3(230, 240, 255)
local COL_TRAP   = C3(220, 80, 255)
local COL_BONE   = C3(245, 245, 250)

local G = {
  active = false,
  state = "idle",
  parts = {},
  traps = {},
  figure = nil,
  boss = nil,
  bossUI = nil,
  timer = 120,
  collected = 0,
  shapeRegistered = false,
  uiHidden = false,
  hooked = false, _origFireId = nil, _wrapper = nil,
  walkTarget = nil, nextRetarget = 0, nextDodge = 0,
  nextAttack = 0, attackIndex = 0, walkPhase = 0,
  hitTimes = {},
  bossVel = Vector3.new(0, 0, 0),
  lastAttackId = nil, darkBlastDone = false,
  rain = {}, darkBlast = nil, cc = nil, flashFrame = nil,
  deadSince = nil, fxHb = nil,
}
local alive, folder, token = true, nil, 0

local PARTS = {
  { id = "head",   nm = "Голова",       col = C3(250, 245, 235), sz = 2.4, px = 0.5,  py = 0.14, sw = 46, sh = 34, z = 1, partType = "gaster_skull" },
  { id = "eyeL",   nm = "Левый глаз",   col = C3(120, 230, 255), sz = 1.4, px = 0.4,  py = 0.13, sw = 10, sh = 10, z = 3, partType = "eye_glow" },
  { id = "eyeR",   nm = "Правый глаз",  col = C3(120, 230, 255), sz = 1.4, px = 0.6,  py = 0.13, sw = 10, sh = 10, z = 3, partType = "eye_glow" },
  { id = "brow",   nm = "Бровь",        col = C3(240, 240, 250), sz = 1.6, px = 0.5,  py = 0.05, sw = 40, sh = 8,  z = 2, partType = "brow" },
  { id = "cheekL", nm = "Левая щека",   col = C3(230, 220, 240), sz = 1.4, px = 0.32, py = 0.22, sw = 12, sh = 18, z = 2, partType = "cheek" },
  { id = "cheekR", nm = "Правая щека",  col = C3(230, 220, 240), sz = 1.4, px = 0.68, py = 0.22, sw = 12, sh = 18, z = 2, partType = "cheek" },
  { id = "hornL",  nm = "Левый рог",    col = C3(210, 210, 230), sz = 1.6, px = 0.30, py = 0.02, sw = 12, sh = 18, z = 2, partType = "horn" },
  { id = "hornR",  nm = "Правый рог",   col = C3(210, 210, 230), sz = 1.6, px = 0.70, py = 0.02, sw = 12, sh = 18, z = 2, partType = "horn" },
  { id = "snout",  nm = "Нос",          col = C3(240, 235, 220), sz = 2.0, px = 0.5,  py = 0.30, sw = 26, sh = 20, z = 2, partType = "snout" },
  { id = "jaw",    nm = "Челюсть",      col = C3(240, 235, 220), sz = 1.8, px = 0.5,  py = 0.38, sw = 30, sh = 14, z = 2, partType = "jaw" },
  { id = "toothU", nm = "Верхний клык", col = C3(255, 255, 255), sz = 1.2, px = 0.42, py = 0.32, sw = 8,  sh = 12, z = 3, partType = "tooth" },
  { id = "toothL", nm = "Нижний клык",  col = C3(255, 255, 255), sz = 1.2, px = 0.58, py = 0.32, sw = 8,  sh = 12, z = 3, partType = "tooth" },
  { id = "armL",   nm = "Левая рука",   col = C3(220, 220, 235), sz = 2,   px = 0.16, py = 0.5,  sw = 18, sh = 52, z = 1, partType = "gaster_arm" },
  { id = "armR",   nm = "Правая рука",  col = C3(220, 220, 235), sz = 2,   px = 0.84, py = 0.5,  sw = 18, sh = 52, z = 1, partType = "gaster_arm" },
  { id = "torso",  nm = "Туловище",     col = C3(200, 200, 220), sz = 2.6, px = 0.5,  py = 0.5,  sw = 42, sh = 56, z = 1, partType = "torso" },
  { id = "boots",  nm = "Ботинки",      col = C3(170, 170, 200), sz = 2.2, px = 0.5,  py = 0.87, sw = 58, sh = 20, z = 1, partType = "boots" },
}

local function ping(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end
local function say(cat, force)
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, cat, force) end
end

local function battle()
  local ab = ORBIT.abilities
  return ab and ab.battle or nil
end
local function dmgMul()
  local B = battle()
  if B and B.dmgMul then return B.dmgMul() end
  return 1
end
local function intervalMul()
  local B = battle()
  if B and B.intervalMul then return B.intervalMul() end
  return 1
end
local function shakeNear(pos, mag, dur)
  local B = battle()
  if B and B.shakeNear then pcall(B.shakeNear, pos, mag, dur) end
end

local function uiParent()
  if type(ORBIT.getSafeParent) == "function" then
    local ok, p = pcall(ORBIT.getSafeParent)
    if ok and typeof(p) == "Instance" then return p end
  end
  return LP:FindFirstChildOfClass("PlayerGui")
end
local function killGui(name)
  local a = uiParent()
  if a then
    local g = a:FindFirstChild(name)
    if g then pcall(function() g:Destroy() end) end
  end
  local b = LP:FindFirstChildOfClass("PlayerGui")
  if b then
    local g2 = b:FindFirstChild(name)
    if g2 then pcall(function() g2:Destroy() end) end
  end
end

local function fold()
  if folder and folder.Parent then return folder end
  folder = Instance.new("Folder"); folder.Name = "OrbitAtmo_Gaster_" .. LP.UserId; folder.Parent = WS
  return folder
end
local function getChar()
  local c = LP.Character
  if not c then return nil end
  local h = c:FindFirstChildOfClass("Humanoid")
  local r = c:FindFirstChild("HumanoidRootPart")
  if not h or not r or h.Health <= 0 then return nil end
  return c, h, r
end
local function rayParams()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  local ex = { fold() }
  if LP.Character then ex[#ex + 1] = LP.Character end
  rp.FilterDescendantsInstances = ex
  return rp
end
local function groundAt(pos)
  local rp = rayParams()
  local res = WS:Raycast(pos + V3(0, 40, 0), V3(0, -120, 0), rp)
  return res and res.Position or pos
end

local function buildShardModel(def, pos)
  local m = Instance.new("Model")
  m.Name = "GasterShard_" .. def.id
  local first
  local function add(size, off, col, shape, mat)
    local p = Instance.new("Part")
    p.Name = "P"
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false
    p.CanTouch = false; p.CastShadow = false
    p.Size = size
    p.CFrame = CFrame.new(pos) * off
    p.Color = col
    p.Material = mat or MAT.SmoothPlastic
    p.Shape = shape or PT_BLOCK
    p:SetAttribute("NoRecolor", true)
    p.Parent = m
    if not first then first = p end
    return p
  end
  local t = def.partType or "ball"
  if t == "gaster_skull" then
    add(V3(1.8, 1.8, 1.6), CF(), C3(250, 245, 235), PT_BALL)
    add(V3(0.9, 0.35, 0.9), CF(0, -0.85, 0.1), C3(240, 235, 220))
    add(V3(0.4, 0.4, 0.4), CF(-0.4, 0.1, -0.65), C3(15, 15, 20), PT_BALL)
    add(V3(0.4, 0.4, 0.4), CF(0.4, 0.1, -0.65), C3(15, 15, 20), PT_BALL)
    add(V3(0.15, 0.15, 0.15), CF(-0.4, 0.15, -0.78), C3(120, 230, 255), PT_BALL, MAT.Neon)
    add(V3(0.15, 0.15, 0.15), CF(0.4, 0.15, -0.78), C3(120, 230, 255), PT_BALL, MAT.Neon)
    add(V3(0.15, 0.5, 0.15), CF(-0.6, 1.0, 0), C3(210, 210, 230))
    add(V3(0.15, 0.5, 0.15), CF(0.6, 1.0, 0), C3(210, 210, 230))
  elseif t == "eye_glow" then
    add(V3(0.6, 0.6, 0.6), CF(), def.col, PT_BALL, MAT.Neon)
  elseif t == "brow" then
    add(V3(1.4, 0.25, 0.5), CF(), def.col)
  elseif t == "cheek" then
    add(V3(0.7, 0.9, 0.7), CF(), def.col)
  elseif t == "horn" then
    add(V3(0.35, 1.2, 0.35), CF(), def.col)
    add(V3(0.2, 0.4, 0.2), CF(0, 0.75, 0), def.col)
  elseif t == "snout" then
    add(V3(1.4, 1.0, 1.4), CF(), def.col)
  elseif t == "jaw" then
    add(V3(1.5, 0.7, 0.9), CF(), def.col)
  elseif t == "tooth" then
    add(V3(0.3, 0.7, 0.3), CF(), C3(255, 255, 255))
  elseif t == "gaster_arm" then
    add(V3(0.9, 2.2, 0.9), CF(0, 0.3, 0), C3(220, 220, 235))
    add(V3(0.7, 0.7, 0.7), CF(0, -0.9, 0), C3(240, 240, 250), PT_BALL)
  elseif t == "torso" then
    add(V3(1.8, 2.2, 1.2), CF(), C3(200, 200, 220))
    add(V3(1.4, 0.5, 0.9), CF(0, 1.2, 0), C3(180, 180, 200))
  elseif t == "boots" then
    add(V3(1.8, 0.7, 2.2), CF(), C3(170, 170, 200))
  else
    add(V3(def.sz, def.sz, def.sz), CF(), def.col, PT_BALL)
  end
  m.PrimaryPart = first
  local l = Instance.new("PointLight")
  l.Color = def.col; l.Range = 14; l.Brightness = 2.5; l.Parent = first
  local pe = Instance.new("ParticleEmitter")
  pe.Color = ColorSequence.new(def.col); pe.LightEmission = 1
  pe.Size = NumberSequence.new(0.5, 0); pe.Lifetime = NumberRange.new(0.6, 1.2)
  pe.Speed = NumberRange.new(2, 5); pe.SpreadAngle = Vector2.new(180, 180); pe.Rate = 25
  pe.Parent = first
  local bb = Instance.new("BillboardGui")
  bb.Size = UDim2.new(0, 120, 0, 20); bb.StudsOffset = V3(0, 2.5, 0)
  bb.AlwaysOnTop = true; bb.Parent = first
  local lbl = Instance.new("TextLabel")
  lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
  lbl.Text = def.nm; lbl.TextColor3 = C3(255, 255, 255)
  lbl.TextStrokeTransparency = 0; lbl.Font = Enum.Font.Code; lbl.TextScaled = true
  lbl.Parent = bb
  m.Parent = fold()
  return m
end

local function mkp(model, name, size, cf, col, mat, nr, tr)
  local p
  if ORBIT.newPart then p = ORBIT.newPart(model, name, size, cf, col, nr) end
  if not p then
    p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true
    p.CanCollide = false; p.CastShadow = false; p.Color = col; p.Parent = model
    if nr then p:SetAttribute("NoRecolor", true) end
  end
  p.Material = mat or MAT.Metal; p.Transparency = tr or 0; p.CanQuery = false; p.CanTouch = false
  return p
end
local function mkw(model, name, size, cf, col, mat, tr)
  local p = Instance.new("WedgePart")
  p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true
  p.CanCollide = false; p.CastShadow = false; p.Color = col
  p.Material = mat or MAT.Marble; p.Transparency = tr or 0
  p.CanQuery = false; p.CanTouch = false
  p:SetAttribute("NoRecolor", true)
  p.Parent = model
  return p
end
local function shell(name)
  if ORBIT.newModelShell then return ORBIT.newModelShell(name) end
  local m = Instance.new("Model"); m.Name = name
  local r = Instance.new("Part")
  r.Name = "Root"; r.Size = V3(0.1, 0.1, 0.1); r.Transparency = 1; r.Anchored = true; r.CanCollide = false; r.Parent = m
  m.PrimaryPart = r
  return m, r
end

local function createGaster(size, name)
  local s = size
  local u = s * 0.75
  local tiny = s < 1
  local model, root = shell(name or "Gaster")
  local bodies = {}
  local BONE, DARK, ENG = C3(245, 245, 250), C3(15, 15, 20), C3(60, 55, 50)
  local RIB, GLOW = C3(215, 220, 230), C3(210, 235, 255)
  local function add(n, sz, cf, col, mat, nr, tr)
    local p = mkp(model, n, sz, cf, col, mat, nr, tr)
    table.insert(bodies, p)
    return p
  end
  local function U(p) return V3(p.X * u, (p.Z - 1.7) * u, (p.Y - 1.6) * u) end
  local function bar(n, a, b, w, h, col, mat, tr)
    local pa, pb = U(a), U(b)
    local len = (pb - pa).Magnitude
    if len < 0.01 then return nil end
    return add(n, V3(w * u, h * u, len), CFrame.lookAt((pa + pb) / 2, pb), col or BONE, mat or MAT.Marble, true, tr)
  end
  local function wedge(n, a, b, th, wd, col, mat)
    local pa, pb = U(a), U(b)
    local len = (pb - pa).Magnitude
    if len < 0.01 then return nil end
    local p = mkw(model, n, V3(th * u, wd * u, len), CFrame.lookAt((pa + pb) / 2, pb), col or BONE, mat)
    table.insert(bodies, p)
    return p
  end

  bar("Skull", V3(0, 0.1, 0.8), V3(0, 1.3, 2.0), 1.25, 1.0)
  bar("SkullBack", V3(0, 1.2, 1.9), V3(0, 2.7, 3.2), 2.0, 1.0)
  bar("Dome", V3(0, 2.0, 2.6), V3(0, 3.0, 3.4), 1.7, 0.7)
  bar("Brow", V3(-0.75, 0.9, 2.0), V3(0.75, 0.9, 2.0), 0.35, 0.28)
  for _, sd in ipairs({ -1, 1 }) do
    bar("Cheek", V3(sd * 0.55, 0.3, 0.7), V3(sd * 0.95, 1.6, 1.4), 0.3, 0.35)
  end
  bar("Snout", V3(0, -0.2, 1.2), V3(0, 1.0, 1.6), 0.65, 0.5)
  bar("NosePlate", V3(0, -0.22, 1.55), V3(0, 0.6, 1.85), 0.3, 0.12, RIB, MAT.Metal)
  bar("Jaw", V3(0, -0.2, 0.35), V3(0, 1.3, 0.75), 0.6, 0.28)
  bar("Chin", V3(0, -0.28, 0.2), V3(0, 0.1, 0.45), 0.4, 0.3)
  for _, sd in ipairs({ -1, 1 }) do
    bar("JawSide", V3(sd * 0.4, 0.4, 0.55), V3(sd * 1.2, 2.4, 1.25), 0.2, 0.16)
    wedge("JawSpike", V3(sd * 1.2, 2.4, 1.25), V3(sd * 1.55, 3.0, 1.3), 0.14, 0.3)
    wedge("JawSpike", V3(sd * 0.9, 1.5, 0.95), V3(sd * 1.4, 1.9, 1.05), 0.12, 0.24)
  end
  for _, sd in ipairs({ -1, 1 }) do
    for i = 0, 3 do
      local c = U(V3(sd * (0.2 + 0.07 * i), 0.0 + 0.3 * i, 0.83))
      local t = mkw(model, "ToothU", V3(0.1 * u, 0.3 * u, 0.12 * u), CF(c) * CFrame.Angles(math.pi, 0, 0), BONE, MAT.Marble)
      table.insert(bodies, t)
    end
    for i = 0, 2 do
      local c = U(V3(sd * (0.17 + 0.06 * i), 0.1 + 0.3 * i, 0.63))
      local t = mkw(model, "ToothL", V3(0.09 * u, 0.26 * u, 0.12 * u), CF(c), BONE, MAT.Marble)
      table.insert(bodies, t)
    end
  end
  bar("MouthDark", V3(0, 0.15, 0.75), V3(0, 1.5, 0.9), 0.5, 0.4, DARK, MAT.SmoothPlastic)
  local mg = add("MouthGlow", V3(0.4 * u, 0.4 * u, 0.4 * u), CF(U(V3(0, 0.5, 0.75))), GLOW, MAT.Neon, true, 0.35)
  mg.Shape = PT_BALL
  local ml = Instance.new("PointLight"); ml.Name = "MouthLight"; ml.Color = GLOW; ml.Range = 8; ml.Brightness = 1.2; ml.Parent = mg
  for _, sd in ipairs({ -1, 1 }) do
    local pos = U(V3(sd * 0.64, 0.85, 1.7))
    local dir = V3(sd * 0.85, 0.2, -0.5).Unit
    local base = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
    local sock = add("EyeSocket", V3(0.12 * u, 0.72 * u, 0.72 * u), base, DARK, MAT.SmoothPlastic, true)
    sock.Shape = PT_CYL
    local ring = add("EyeRing", V3(0.05 * u, 0.5 * u, 0.5 * u), base + dir * (0.07 * u), GLOW, MAT.Neon, true)
    ring.Shape = PT_CYL
    local inner = add("EyeInner", V3(0.05 * u, 0.34 * u, 0.34 * u), base + dir * (0.095 * u), DARK, MAT.SmoothPlastic, true)
    inner.Shape = PT_CYL
    local pupil = add("EyeGlint", V3(0.2 * u, 0.2 * u, 0.2 * u), base + dir * (0.13 * u), GLOW, MAT.Neon, true)
    pupil.Shape = PT_BALL
    local pl = Instance.new("PointLight"); pl.Name = "EyeLight"; pl.Color = GLOW; pl.Range = 7; pl.Brightness = 1.4; pl.Parent = pupil
  end
  local wings = {
    { V3(0.45, 2.3, 2.9), V3(1.0, 3.5, 3.8), 0.8 },
    { V3(0.8, 2.3, 2.4), V3(1.35, 3.45, 3.15), 0.7 },
    { V3(1.05, 2.2, 1.8), V3(1.6, 3.25, 2.3), 0.6 },
  }
  for _, sd in ipairs({ -1, 1 }) do
    for _, w in ipairs(wings) do
      local a = V3(sd * w[1].X, w[1].Y, w[1].Z)
      local b = V3(sd * w[2].X, w[2].Y, w[2].Z)
      wedge("Wing", a, b, 0.14, w[3], BONE, MAT.Marble)
      local inA = V3(a.X - sd * 0.09, a.Y, a.Z)
      local inB = V3(a.X - sd * 0.09, a.Y, a.Z) + (b - a) * 0.86
      wedge("WingInner", inA, inB, 0.1, w[3] * 0.7, DARK, MAT.SmoothPlastic)
      if not tiny then
        bar("WingRib", V3(a.X + sd * 0.08, a.Y, a.Z), V3(b.X + sd * 0.08, b.Y, b.Z), 0.06, 0.06, RIB, MAT.Metal)
      end
    end
  end
  wedge("Crest", V3(0, 2.6, 3.2), V3(0, 3.5, 3.8), 0.22, 0.6, BONE, MAT.Marble)
  wedge("CrestInner", V3(0, 2.6, 3.2), V3(0, 3.3, 3.65), 0.1, 0.4, DARK, MAT.SmoothPlastic)

  if not tiny then
    local A2, B2, NUP = V3(0, 1.2, 1.9), V3(0, 2.7, 3.2), V3(0, -0.6549, 0.7556)
    local function top(t, x, off) return A2 + (B2 - A2) * t + NUP * (0.5 + off) + V3(x, 0, 0) end
    bar("Engrave", top(0.15, 0, 0.01), top(0.85, 0, 0.01), 0.06, 0.02, ENG, MAT.SmoothPlastic)
    for _, sd in ipairs({ -1, 1 }) do
      bar("Engrave", top(0.25, sd * 0.5, 0.01), top(0.8, sd * 0.5, 0.01), 0.05, 0.02, ENG, MAT.SmoothPlastic)
    end
    for _, t in ipairs({ 0.4, 0.6, 0.8 }) do
      bar("Engrave", top(t, -0.45, 0.01), top(t, 0.45, 0.01), 0.05, 0.02, ENG, MAT.SmoothPlastic)
    end
    for _, t in ipairs({ 0.3, 0.5, 0.7 }) do
      bar("Rib", top(t, -0.8, 0.04), top(t, 0.8, 0.04), 0.09, 0.08, RIB, MAT.Metal)
    end
    for _, sd in ipairs({ -1, 1 }) do
      bar("Rib", top(0.15, sd * 0.8, 0.04), top(0.9, sd * 0.8, 0.04), 0.1, 0.08, RIB, MAT.Metal)
    end
    local aura = add("Aura", V3(2.6 * u, 2.6 * u, 2.6 * u), CF(U(V3(0, 2.4, 2.9))), GLOW, MAT.Neon, true, 0.92)
    aura.Shape = PT_BALL
    local ad = V3(0, 0.6549, 0.7556)
    for _, r in ipairs({ { V3(0, 2.2, 2.7), 2.5, 0.8 }, { V3(0, 2.7, 3.2), 1.9, 0.75 } }) do
      local pos = U(r[1])
      local ar = add("AuraRing", V3(0.05 * u, r[2] * u, r[2] * u), CFrame.lookAt(pos, pos + ad) * CFrame.Angles(0, math.rad(90), 0), GLOW, MAT.Neon, true, r[3])
      ar.Shape = PT_CYL
    end
  end

  local cz = U(V3(0, -0.38, 0.72))
  local charge = add("Charge", V3(0.3 * s, 0.3 * s, 0.3 * s), CF(cz), COL_CHARGE, MAT.Neon, true, 0.2)
  charge.Shape = PT_BALL
  add("Beam", V3(0.28 * s, 0.22 * s, 1.4 * s), CF(cz.X, cz.Y, cz.Z - 0.75 * s), COL_BEAM, MAT.Neon, true, 0.3)
  local l = Instance.new("PointLight")
  l.Name = "GLight"; l.Color = COL_GLOW; l.Range = 12; l.Brightness = 1.5; l.Parent = charge
  local e = Instance.new("ParticleEmitter")
  e.Name = "GSparks"; e.Color = ColorSequence.new(COL_GLOW); e.LightEmission = 1
  e.Size = NumberSequence.new(0.25 * s * 0.3, 0); e.Lifetime = NumberRange.new(0.5, 1)
  e.Speed = NumberRange.new(1, 3); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 15; e.Parent = charge
  return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = s * 3.4 }
end

function G.registerShape()
  G.shapeRegistered = true
  return true
end
G.create = createGaster

local function clearShards()
  for _, s in pairs(G.parts) do if s.model then pcall(function() s.model:Destroy() end) end end
  G.parts = {}
  for _, t in pairs(G.traps) do if t.part then pcall(function() t.part:Destroy() end) end end
  G.traps = {}
end

local function makeShard(def, pos) return buildShardModel(def, pos) end

local function makeTrap(pos, r)
  local p = ORBIT.newPart(fold(), "GasterTrap", V3(r, r, r), CF(pos), COL_TRAP)
  p.Shape = PT_BALL
  p.Material = MAT.Neon
  p.Transparency = 0.35
  p.CanTouch = true
  p:SetAttribute("NoRecolor", true)
  local l = Instance.new("PointLight"); l.Color = COL_TRAP; l.Range = 12; l.Brightness = 2; l.Parent = p
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(COL_TRAP); e.LightEmission = 1; e.Size = NumberSequence.new(0.6, 0)
  e.Lifetime = NumberRange.new(0.4, 0.8); e.Speed = NumberRange.new(3, 8); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 60; e.Parent = p
  return p
end

function G.spawnParts()
  clearShards()
  local c, h, root = getChar()
  if not root then return false end
  local placed = {}
  local rp = rayParams()
  for _, def in ipairs(PARTS) do
    local pos
    for _ = 1, 12 do
      local a, d = math.random() * math.pi * 2, 20 + math.random() * 45
      local x, z = root.Position.X + math.cos(a) * d, root.Position.Z + math.sin(a) * d
      local res = WS:Raycast(V3(x, root.Position.Y + 70, z), V3(0, -220, 0), rp)
      pos = V3(x, (res and res.Position.Y or root.Position.Y) + 3, z)
      local ok = true
      for _, q in ipairs(placed) do if (q - pos).Magnitude < 8 then ok = false; break end end
      if ok then break end
    end
    placed[#placed + 1] = pos
    G.parts[def.id] = {
      def = def, model = makeShard(def, pos), base = pos,
      phase = math.random() * math.pi * 2,
      radius = 1.5 + math.random() * 2,
      speed = 0.6 + math.random() * 0.8,
      got = false, flying = false,
    }
  end
  for i = 1, 5 do
    local a = (i - 1) / 5 * math.pi * 2
    local d = 25 + math.random() * 15
    local x, z = root.Position.X + math.cos(a) * d, root.Position.Z + math.sin(a) * d
    local res = WS:Raycast(V3(x, root.Position.Y + 70, z), V3(0, -220, 0), rp)
    local pos = V3(x, (res and res.Position.Y or root.Position.Y) + 4, z)
    local r = 3.5 + math.random() * 1.5
    local p = makeTrap(pos, r)
    G.traps[#G.traps + 1] = {
      part = p, r = r, baseAngle = a, baseRadius = d, angle = a,
      angleSpeed = 0.4 + math.random() * 0.4,
      baseY = pos.Y, bobPhase = math.random() * 6,
      hitCooldown = 0,
    }
  end
  return true
end

-- ============================================================
--       UI СБОРА ОСКОЛКОВ
-- ============================================================
local function onClick(btn, fn, releaseOnly)
  local deb = false
  local down, downT, lastRelT = false, 0, 0
  local function call()
    if deb then return end
    deb = true
    task.delay(0.12, function() deb = false end)
    pcall(fn)
  end
  local function inScroll() return releaseOnly or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil end
  local function press()
    if down and tick() - downT < 1 then return end
    down, downT = true, tick()
    if not inScroll() then call() end
  end
  local function release()
    local now = tick()
    if down then
      down = false; lastRelT = now
      if inScroll() then call() end
    elseif now - lastRelT > 0.2 then
      lastRelT = now; call()
    end
  end
  btn.MouseButton1Down:Connect(press)
  btn.Activated:Connect(release)
end
local function fmtTime(t) t = math.max(0, math.floor(t)); return string.format("%d:%02d", math.floor(t / 60), t % 60) end

local function uiRefresh()
  local u = G.ui
  if not u then return end
  local n = 0
  for _, def in ipairs(PARTS) do
    local s = G.parts[def.id]
    local got = s and s.got
    if got then n = n + 1 end
    local sl = u.slots[def.id]
    if sl then
      sl.BackgroundColor3 = got and def.col or C3(70, 70, 85)
      sl.BackgroundTransparency = got and 0 or 0.45
    end
  end
  G.collected = n
  u.prog.Text = string.format("Собрано %d/%d", n, #PARTS)
  if G.state == "collecting" then
    u.timer.Text = "⏱ " .. fmtTime(G.timer)
  elseif G.state == "boss" and G.boss then
    u.timer.Text = "⚔ БОСС"
  elseif G.state == "won" then
    u.timer.Text = "✅ ПОБЕДА"
  else
    u.timer.Text = "⏱ " .. fmtTime(G.timer)
  end
  if u.btnOn then u.btnOn.Text = G.figure and "👁 ВЫКЛЮЧИТЬ ГАСТЕРА" or "👁 ВКЛЮЧИТЬ ГАСТЕРА" end
end

local function toast(text) if G.ui then G.ui.hint.Text = text end end

local function closeUI()
  if G.ui and G.ui.sg then pcall(function() G.ui.sg:Destroy() end) end
  G.ui = nil
  killGui("OrbitGasterGui")
end

local function buildUI()
  closeUI()
  local pg = uiParent()
  if not pg then return end
  local sg = Instance.new("ScreenGui")
  sg.Name = "OrbitGasterGui"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 25; sg.Parent = pg
  local cm = WS.CurrentCamera
  local vp = cm and cm.ViewportSize or Vector2.new(800, 400)
  local w = math.min(380, vp.X - 24)
  local win = Instance.new("Frame")
  win.AnchorPoint = Vector2.new(0.5, 0); win.Position = UDim2.new(0.5, 0, 0, 10); win.Size = UDim2.fromOffset(w, 210)
  win.BackgroundColor3 = C3(16, 12, 26); win.BackgroundTransparency = 0.1; win.Parent = sg
  Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
  local st = Instance.new("UIStroke"); st.Color = C3(200, 200, 255); st.Thickness = 2; st.Parent = win
  local function lbl(x, y, ww, hh, text, size, col)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Position = UDim2.fromOffset(x, y); l.Size = UDim2.fromOffset(ww, hh)
    l.Text = text; l.TextSize = size; l.TextColor3 = col or C3(235, 225, 255); l.Font = Enum.Font.GothamBold
    l.TextWrapped = true; l.TextXAlignment = Enum.TextXAlignment.Left; l.TextYAlignment = Enum.TextYAlignment.Top; l.Parent = win
    return l
  end
  local function btn(x, y, ww, text)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y); b.Size = UDim2.fromOffset(ww, 32); b.Text = text; b.TextSize = 13
    b.Font = Enum.Font.GothamBold; b.TextColor3 = C3(255, 255, 255); b.BackgroundColor3 = C3(70, 40, 130)
    b.AutoButtonColor = false; b.Parent = win
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
  end
  local u = { sg = sg, slots = {} }
  local title = lbl(10, 6, w - 20, 24, "👁 СОБЕРИ ГАСТЕРА (16 частей тела)", 15, C3(220, 220, 255))
  title.TextXAlignment = Enum.TextXAlignment.Center

  local sk = Instance.new("Frame")
  sk.Position = UDim2.fromOffset(8, 34); sk.Size = UDim2.fromOffset(120, 168); sk.BackgroundTransparency = 1; sk.Parent = win
  for _, def in ipairs(PARTS) do
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(def.px, def.py)
    f.Size = UDim2.fromOffset(math.max(def.sw * 0.7, 8), math.max(def.sh * 0.7, 6))
    f.BackgroundColor3 = C3(70, 70, 85); f.BackgroundTransparency = 0.45; f.BorderSizePixel = 0; f.ZIndex = def.z; f.Parent = sk
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, def.round and 99 or 4)
    u.slots[def.id] = f
  end

  local x0, cw = 136, w - 144
  u.prog = lbl(x0, 34, cw, 22, "Собрано 0/16", 15)
  u.timer = lbl(x0, 58, cw, 22, "⏱ 2:00", 15)
  u.hint = lbl(x0, 82, cw, 44, "Части тела плавают. Ловушки фиолетовые — минус 1. Собирай все 16.", 10, C3(170, 160, 200))
  u.btnStart = btn(x0, 132, cw, "▶ СТАРТ")
  u.btnReset = btn(x0, 168, math.floor(cw / 2) - 2, "↺ СБРОС")
  u.btnClose = btn(x0 + math.floor(cw / 2) + 2, 168, math.floor(cw / 2) - 2, "✖ СКРЫТЬ")
  u.btnReset.TextSize = 11; u.btnClose.TextSize = 11
  if ORBIT.gasterUnlocked then
    u.btnOn = btn(x0, 100, cw, "👁 ВКЛЮЧИТЬ ГАСТЕРА")
    u.btnOn.TextSize = 11; u.hint.Visible = false
    onClick(u.btnOn, function()
      if G.figure then G.removeFigure() else G.assemble(true) end
      uiRefresh()
    end, true)
  end
  onClick(u.btnStart, function() G.start() end, true)
  onClick(u.btnReset, function() G.reset() end, true)
  onClick(u.btnClose, function() G.hideUI() end, true)
  G.ui = u
  uiRefresh()
end

function G.hideUI()
  if G.ui and G.ui.sg then
    G.ui.sg.Enabled = false
    G.uiHidden = true
    if ORBIT.notify then ORBIT.notify("👁 UI скрыт. Вернуть: кнопка «Собери Гастера» в меню", C3(200, 220, 255), 3) end
  end
end

function G.showUI()
  if G.ui and G.ui.sg then
    G.ui.sg.Enabled = true
    G.uiHidden = false
  else
    buildUI()
    G.uiHidden = false
  end
end

function G.close() G.hideUI() end

-- ============================================================
--       БОСС-UI
-- ============================================================
local function showBossUI()
  local pg = uiParent()
  if not pg then return end
  killGui("_OrbitGasterBoss")
  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitGasterBoss"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 40; sg.Parent = pg
  local frame = Instance.new("Frame")
  frame.AnchorPoint = Vector2.new(0.5, 0); frame.Position = UDim2.new(0.5, 0, 0, 30)
  frame.Size = UDim2.new(0, 500, 0, 60)
  frame.BackgroundColor3 = C3(15, 10, 25); frame.BackgroundTransparency = 0.15; frame.Parent = sg
  Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
  local st = Instance.new("UIStroke", frame); st.Color = C3(255, 100, 200); st.Thickness = 2

  local nameLbl = Instance.new("TextLabel")
  nameLbl.Size = UDim2.new(1, -20, 0, 22); nameLbl.Position = UDim2.new(0, 10, 0, 4)
  nameLbl.BackgroundTransparency = 1; nameLbl.Text = "👁 ГАСТЕР — ФАЗА 1"
  nameLbl.TextColor3 = C3(255, 200, 240); nameLbl.Font = Enum.Font.GothamBold
  nameLbl.TextSize = 14; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = frame

  local hpBg = Instance.new("Frame")
  hpBg.Size = UDim2.new(1, -20, 0, 20); hpBg.Position = UDim2.new(0, 10, 0, 30)
  hpBg.BackgroundColor3 = C3(40, 20, 40); hpBg.BorderSizePixel = 0; hpBg.Parent = frame
  Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 6)

  local hpFill = Instance.new("Frame")
  hpFill.Size = UDim2.new(1, 0, 1, 0); hpFill.BackgroundColor3 = C3(255, 80, 180)
  hpFill.BorderSizePixel = 0; hpFill.Parent = hpBg
  Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 6)
  local gr = Instance.new("UIGradient", hpFill)
  gr.Color = ColorSequence.new(C3(255, 80, 180), C3(180, 60, 255)); gr.Rotation = 0

  local hpTxt = Instance.new("TextLabel")
  hpTxt.Size = UDim2.new(1, 0, 1, 0); hpTxt.BackgroundTransparency = 1
  hpTxt.Text = "650 / 650"; hpTxt.TextColor3 = C3(255, 255, 255)
  hpTxt.Font = Enum.Font.GothamBold; hpTxt.TextSize = 12; hpTxt.ZIndex = 2; hpTxt.Parent = hpBg

  G.bossUI = { sg = sg, frame = frame, nameLbl = nameLbl, hpFill = hpFill, hpTxt = hpTxt }
end

local function updateBossUI()
  if not G.bossUI or not G.boss then return end
  local b = G.boss
  local frac = math.clamp(b.hp / b.maxHp, 0, 1)
  G.bossUI.hpFill.Size = UDim2.new(frac, 0, 1, 0)
  G.bossUI.hpTxt.Text = math.floor(b.hp) .. " / " .. b.maxHp
  local phase = b.hp > b.maxHp * 0.66 and 1 or (b.hp > b.maxHp * 0.33 and 2 or 3)
  if phase ~= b.phase then
    b.phase = phase
    G.bossUI.nameLbl.Text = "👁 ГАСТЕР — ФАЗА " .. phase
    if phase == 2 then
      G.bossUI.hpFill.BackgroundColor3 = C3(255, 130, 60)
    elseif phase == 3 then
      G.bossUI.hpFill.BackgroundColor3 = C3(255, 60, 60)
    end
    local B = battle()
    if B and B.onPhase then pcall(B.onPhase, phase) end
  end
end

local function hideBossUI()
  if G.bossUI and G.bossUI.sg then pcall(function() G.bossUI.sg:Destroy() end) end
  G.bossUI = nil
  killGui("_OrbitGasterBoss")
end

-- ============================================================
--       ХОДЬБА ЧЕРЕЗ ORBIT.figureRig
-- ============================================================
local GROUND_Y = 3

local function findWalkTarget(center, bossPos)
  local angle = math.random() * math.pi * 2
  local dist = 8 + math.random() * 4
  local target = center + V3(math.cos(angle) * dist, 0, math.sin(angle) * dist)
  local ground = groundAt(target)
  return V3(ground.X, ground.Y + GROUND_Y, ground.Z)
end

local function faceCF(pos, target)
  local flat = V3(target.X, pos.Y, target.Z)
  if (flat - pos).Magnitude < 0.05 then return CFrame.new(pos) end
  return CFrame.lookAt(pos, flat) * CFrame.Angles(0, math.pi, 0)
end

local function applyRig(dt)
  local Rig = ORBIT.figureRig
  if Rig and Rig.update and G.boss and G.boss.model then
    pcall(Rig.update, G.boss.model, dt, G.bossVel)
  end
end

local function stepBossMovement(dt, t)
  if not G.boss or not G.boss.model then return end
  local c, h, r = getChar()
  if not r then G.bossVel = V3(0, 0, 0); return end
  local bossPos = G.boss.model:GetPivot().Position
  local playerPos = r.Position
  if not G.walkTarget or t >= G.nextRetarget or (G.walkTarget - bossPos).Magnitude < 1.5 then
    G.nextRetarget = t + 1.5
    G.walkTarget = findWalkTarget(playerPos, bossPos)
  end
  if t >= G.nextDodge then
    G.nextDodge = t + 2.5 + math.random() * 2
    local away = bossPos - playerPos
    away = V3(away.X, 0, away.Z)
    if away.Magnitude > 0.1 then
      local side = away.Unit:Cross(V3(0, 1, 0)) * (math.random() < 0.5 and 1 or -1)
      local dodgeTo = groundAt(bossPos + side * 7)
      G.walkTarget = V3(dodgeTo.X, dodgeTo.Y + GROUND_Y, dodgeTo.Z)
      G.nextRetarget = t + 0.8
      ping("dodge", 0.8, 1.4)
    end
  end
  local target = G.walkTarget or bossPos
  local diff = V3(target.X - bossPos.X, 0, target.Z - bossPos.Z)
  local dist = diff.Magnitude
  local newPos = bossPos
  if dist > 0.8 then
    local step = math.min(dist, 9 * dt)
    local dir = diff.Unit
    newPos = V3(bossPos.X + dir.X * step, target.Y, bossPos.Z + dir.Z * step)
  end
  local vel = V3(newPos.X - bossPos.X, 0, newPos.Z - bossPos.Z) / math.max(dt, 0.001)
  G.bossVel = G.bossVel:Lerp(vel, math.min(1, dt * 10))
  pcall(function() G.boss.model:PivotTo(faceCF(newPos, playerPos)) end)
end

-- ============================================================
--       АТАКИ: прежние 4
-- ============================================================
local function shootBeamSimple(from, to, dmgTarget, mul)
  mul = mul or 1
  local diff = to - from
  if diff.Magnitude < 0.5 then return end
  local p = ORBIT.newPart(fold(), "Beam", V3(2.2, 2.2, diff.Magnitude),
    CFrame.lookAt((from + to) / 2, to), COL_BEAM, true)
  p.Material = MAT.Neon
  p.Transparency = 0.1
  p.CanQuery = false; p.CanTouch = false
  local core = Instance.new("PointLight"); core.Color = COL_GLOW; core.Range = 20; core.Brightness = 6; core.Parent = p
  TS:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
  TS:Create(core, TweenInfo.new(0.5), { Brightness = 0 }):Play()
  Debris:AddItem(p, 0.6)

  if dmgTarget and dmgTarget.hum and dmgTarget.hum.Parent and dmgTarget.hum.Health > 0 then
    pcall(function() dmgTarget.hum:TakeDamage(15 * mul) end)
    G.hitTimes[#G.hitTimes + 1] = tick()
  else
    local c, h, r = getChar()
    if r and h and (r.Position - to).Magnitude < 6 then
      pcall(function() h:TakeDamage(15 * mul) end)
      G.hitTimes[#G.hitTimes + 1] = tick()
    end
  end
  shakeNear(to, 0.45, 0.2)
  ping("snap", 1, 0.5)
end

local function attackBlaster(model)
  local c, h, r = getChar()
  if not r then return end
  local from = model:GetPivot().Position + V3(0, 5, 0)
  shootBeamSimple(from, r.Position, nil, dmgMul())
  say("attack")
end

local function attackHand(model)
  local c, h, r = getChar()
  if not r then return end
  local ab = ORBIT.abilities
  if ab and ab.spawnHand then
    local pos = r.Position + V3((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 4)
    local ground = groundAt(pos)
    pcall(ab.spawnHand, ground, 1.4, r.Position, 30 * dmgMul(), 5.5, 0.5)
  end
  ping("snap", 0.9, 0.7)
end

local function attackBones(model)
  local c, h, r = getChar()
  if not r then return end
  local ab = ORBIT.abilities
  local from = model:GetPivot().Position + V3(0, 3, 0)
  local d = (r.Position - from)
  if d.Magnitude < 1 then d = V3(0, 0, 1) end
  local dir = d.Unit
  if ab and ab.spawnBones then
    local n = G.boss and (G.boss.hp < G.boss.maxHp * 0.5 and 7 or 5) or 5
    pcall(ab.spawnBones, from, dir, n, 14, 1.5 * dmgMul(), false)
  end
  ping("snap", 1, 1.4)
  say("attack")
end

local function purpleFlash()
  local f = G.flashFrame
  if not (f and f.Parent) then
    local pg = uiParent()
    if not pg then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "_OrbitGasterFlash"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.DisplayOrder = 55; sg.Parent = pg
    f = Instance.new("Frame")
    f.Size = UDim2.fromScale(1, 1); f.BackgroundColor3 = C3(120, 30, 180)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.ZIndex = 1; f.Active = false; f.Parent = sg
    G.flashFrame = f
  end
  f.BackgroundTransparency = 0.7
  TS:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
end

local function attackWords(model)
  local c, h, r = getChar()
  if not r then return end
  local head = c and c:FindFirstChild("Head")
  local phrases = {
    "слабо. очень слабо.",
    "ты не сможешь меня победить.",
    "такая жалкая попытка...",
    "и это всё, на что ты способен?",
    "я даже не устал.",
  }
  local phrase = phrases[math.random(#phrases)]
  if head and ORBIT.sans and ORBIT.sans.showAt then
    pcall(ORBIT.sans.showAt, head.Position + V3(0, 3, 0), phrase, 3.5)
  end
  if h then
    pcall(function() h:TakeDamage(5 * dmgMul()) end)
    G.hitTimes[#G.hitTimes + 1] = tick()
  end
  purpleFlash()
  ping("snap", 0.6, 1.6)
end

-- ============================================================
--       НОВАЯ АТАКА 1 — «МОЛНИЯ» (AoE сверху)
-- ============================================================
local function strikeAt(pos, warnT, radius, dmg)
  local g = groundAt(pos)
  local ring = ORBIT.newPart(fold(), "BoltWarn", V3(0.2, radius * 2, radius * 2),
    CF(g + V3(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(255, 240, 120), true)
  ring.Shape = PT_CYL; ring.Material = MAT.Neon; ring.Transparency = 0.5
  TS:Create(ring, TweenInfo.new(warnT, Enum.EasingStyle.Linear),
    { Transparency = 0.9, Size = V3(0.2, radius * 1.2, radius * 1.2) }):Play()
  Debris:AddItem(ring, warnT + 0.1)
  task.delay(warnT, function()
    if not alive or not G.active then return end
    local col = ORBIT.newPart(fold(), "BoltCol", V3(1.6, 70, 1.6), CF(g + V3(0, 35, 0)), C3(255, 255, 220), true)
    col.Material = MAT.Neon; col.Transparency = 0.1
    TS:Create(col, TweenInfo.new(0.35), { Size = V3(0.2, 70, 0.2), Transparency = 1 }):Play()
    Debris:AddItem(col, 0.45)
    local fl = ORBIT.newPart(fold(), "BoltFlash", V3(2, 2, 2), CF(g + V3(0, 1, 0)), C3(255, 255, 200), true)
    fl.Shape = PT_BALL; fl.Material = MAT.Neon; fl.Transparency = 0.2
    local l = Instance.new("PointLight"); l.Color = C3(255, 255, 200); l.Range = 26; l.Brightness = 8; l.Parent = fl
    TS:Create(fl, TweenInfo.new(0.4), { Size = V3(radius * 2, radius * 2, radius * 2), Transparency = 1 }):Play()
    TS:Create(l, TweenInfo.new(0.45), { Brightness = 0 }):Play()
    Debris:AddItem(fl, 0.5)
    shakeNear(g, 0.7, 0.3); ping("snap", 1, 1.6)
    local _, hum, root = getChar()
    if hum and root and root.Position.Y < g.Y + 12
       and (V3(root.Position.X, g.Y, root.Position.Z) - g).Magnitude <= radius then
      pcall(function() hum:TakeDamage(dmg * dmgMul()) end)
      G.hitTimes[#G.hitTimes + 1] = tick()
    end
  end)
end

local function attackLightning()
  if not G.boss or not G.active then return end
  local c, h, r = getChar()
  if not r then return end
  local ph = G.boss.phase or 1
  local n = (ph >= 3) and 3 or ((ph >= 2) and 2 or 1)
  say("attack"); ping("snap", 0.8, 1.6)
  for i = 1, n do
    task.delay((i - 1) * 0.45, function()
      if not alive or not G.active then return end
      local _, _, r2 = getChar()
      if not r2 then return end
      local v = r2.AssemblyLinearVelocity
      local p = r2.Position + V3(v.X, 0, v.Z) * 0.35
      if i > 1 then p = p + V3(math.random(-6, 6), 0, math.random(-6, 6)) end
      strikeAt(p, 0.8, 7, 20)
    end)
  end
end

-- ============================================================
--       ОБЩИЕ ХЕЛПЕРЫ НОВЫХ АТАК
-- ============================================================
local destroyBossModel

local function quiet(p)
  p.CanQuery = false; p.CanTouch = false
  return p
end

local function makeBone(origin, size)
  local len = 3.8 * size
  local p = ORBIT.newPart(fold(), "GasterBone", V3(size * 1.4, size * 1.4, len), CF(origin), COL_BONE, true)
  p.Material = MAT.SmoothPlastic
  quiet(p)
  local extra = {}
  for _, sz in ipairs({1, -1}) do
    for _, sx in ipairs({-1, 1}) do
      local lobe = ORBIT.newPart(fold(), "Lobe", V3(size * 1.5, size * 1.5, size * 1.5), CF(), COL_BONE, true)
      lobe.Shape = PT_BALL; lobe.Material = MAT.SmoothPlastic
      quiet(lobe)
      lobe.Parent = p
      extra[#extra + 1] = { p = lobe, off = CF(sx * size * 0.6, 0, sz * (len * 0.5 - size * 0.4)) }
    end
  end
  return p, extra, len
end
local function placeBone(p, extra, cf)
  p.CFrame = cf
  for _, e in ipairs(extra) do e.p.CFrame = cf * e.off end
end

local function bossFlash(col, alpha, dur)
  local ab = ORBIT.abilities
  if ab and ab.flash then pcall(ab.flash, col, alpha, dur) end
end

-- ============================================================
--       НОВАЯ АТАКА 2 — «ТЁМНЫЙ ВЗРЫВ» (AoE вокруг босса)
-- ============================================================
local DB_R, DB_CHARGE = 20, 1.8

local function endDarkBlast()
  local d = G.darkBlast
  if not d then return end
  G.darkBlast = nil
  for _, k in ipairs({ "sphere", "ring" }) do
    if d[k] then pcall(function() d[k]:Destroy() end) end
  end
end

local function attackDarkBlast()
  if not G.boss or not G.active or G.darkBlast then return end
  local pos = G.boss.model:GetPivot().Position
  local g = groundAt(pos)
  local sphere = ORBIT.newPart(fold(), "DarkCore", V3(2, 2, 2), CF(pos + V3(0, 4, 0)), C3(40, 10, 70), true)
  sphere.Shape = PT_BALL; sphere.Material = MAT.Neon; sphere.Transparency = 0.15
  quiet(sphere)
  local l = Instance.new("PointLight"); l.Color = C3(150, 60, 255); l.Range = 30; l.Brightness = 3; l.Parent = sphere
  local ring = ORBIT.newPart(fold(), "DarkRing", V3(0.25, DB_R * 2, DB_R * 2),
    CF(g + V3(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(150, 60, 255), true)
  ring.Shape = PT_CYL; ring.Material = MAT.Neon; ring.Transparency = 0.55
  quiet(ring)
  G.darkBlast = { t0 = tick(), pos = pos, g = g, sphere = sphere, light = l, ring = ring, nextShake = 0 }
  G.bossVel = V3(0, 0, 0)
  if ORBIT.sans and ORBIT.sans.showAt then
    pcall(ORBIT.sans.showAt, pos + V3(0, 9, 0), "прочувствуй тьму.", 2.5)
  end
  if ORBIT.notify then ORBIT.notify("🌑 ТЁМНЫЙ ВЗРЫВ! Выйди за фиолетовое кольцо!", C3(190, 120, 255), 3) end
  bossFlash(C3(80, 20, 140), 0.85, 0.4)
  ping("laugh", 1, 0.7)
end

local function stepDarkBlast(dt, t)
  local d = G.darkBlast
  if not d then return end
  if not G.active or not G.boss then endDarkBlast(); return end
  local el = t - d.t0
  if el < DB_CHARGE then
    local k = el / DB_CHARGE
    d.pos = G.boss.model:GetPivot().Position
    d.sphere.Size = V3(1, 1, 1) * (2 + 7 * k)
    d.sphere.CFrame = CF(d.pos + V3(0, 4 + 2 * k, 0))
    d.ring.Transparency = math.clamp(0.55 - 0.25 * k + 0.1 * math.sin(t * 20), 0.2, 0.7)
    if d.light then d.light.Brightness = 3 + 7 * k end
    if t >= d.nextShake then
      d.nextShake = t + 0.25
      shakeNear(d.pos, 0.2 + 0.3 * k, 0.2)
    end
    return
  end

  local pos, g = d.pos, d.g
  local wave = ORBIT.newPart(fold(), "DarkWave", V3(2, 2, 2), CF(pos + V3(0, 3, 0)), C3(90, 30, 160), true)
  wave.Shape = PT_BALL; wave.Material = MAT.Neon; wave.Transparency = 0.2
  quiet(wave)
  TS:Create(wave, TweenInfo.new(0.5), { Size = V3(1, 1, 1) * DB_R * 2, Transparency = 1 }):Play()
  Debris:AddItem(wave, 0.6)
  local shock = ORBIT.newPart(fold(), "DarkShock", V3(0.3, 4, 4),
    CF(g + V3(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(200, 120, 255), true)
  shock.Shape = PT_CYL; shock.Material = MAT.Neon; shock.Transparency = 0.2
  quiet(shock)
  TS:Create(shock, TweenInfo.new(0.5), { Size = V3(0.3, DB_R * 2.4, DB_R * 2.4), Transparency = 1 }):Play()
  Debris:AddItem(shock, 0.6)
  bossFlash(C3(140, 60, 220), 0.6, 0.5)
  shakeNear(pos, 1.0, 0.5)
  ping("snap", 1, 0.4); ping("laugh", 1, 0.6)
  local _, hum, root = getChar()
  if hum and root then
    local flat = V3(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
    if flat.Magnitude <= DB_R and root.Position.Y < g.Y + 14 then
      pcall(function() hum:TakeDamage(35 * dmgMul()) end)
      local dir = flat.Magnitude > 0.1 and flat.Unit or V3(0, 0, 1)
      pcall(function() root.AssemblyLinearVelocity = dir * 45 + V3(0, 20, 0) end)
      G.hitTimes[#G.hitTimes + 1] = tick()
    end
  end
  endDarkBlast()
  G.nextRetarget = t + 0.5
end

-- ============================================================
--       НОВАЯ АТАКА 3 — «КОСТЯНОЙ ДОЖДЬ» (8 костей)
-- ============================================================
local RAIN_N, RAIN_SPEED, RAIN_WARN, RAIN_H = 8, 55, 0.9, 40

local function attackBoneRain()
  if not G.boss or not G.active or #G.rain > 0 then return end
  local _, _, r = getChar()
  if not r then return end
  local base = r.Position
  local v = r.AssemblyLinearVelocity
  local lead = base + V3(v.X, 0, v.Z) * 0.6
  local t0 = tick()
  for i = 1, RAIN_N do
    local tgt
    if i <= 3 then
      tgt = lead + V3(math.random(-3, 3), 0, math.random(-3, 3))
    else
      local a, d = math.random() * math.pi * 2, 4 + math.random() * 10
      tgt = base + V3(math.cos(a) * d, 0, math.sin(a) * d)
    end
    local g = groundAt(tgt)
    local p, extra, len = makeBone(g + V3(0, RAIN_H, 0), 1.3)
    local warn = ORBIT.newPart(fold(), "RainWarn", V3(0.2, 6.4, 6.4),
      CF(g + V3(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), C3(255, 90, 90), true)
    warn.Shape = PT_CYL; warn.Material = MAT.Neon; warn.Transparency = 0.45
    quiet(warn)
    placeBone(p, extra, CFrame.new(g.X, g.Y + RAIN_H, g.Z) * CFrame.Angles(math.rad(90), 0, 0))
    G.rain[#G.rain + 1] = {
      p = p, extra = extra, len = len, warn = warn, g = g,
      fallT = t0 + RAIN_WARN + (i - 1) * 0.12, y = g.Y + RAIN_H,
    }
  end
  say("attack"); ping("snap", 0.8, 1.2)
end

local function killRain(b)
  pcall(function() b.p:Destroy() end)
  pcall(function() b.warn:Destroy() end)
end

local function stepRain(dt, t)
  for i = #G.rain, 1, -1 do
    local b = G.rain[i]
    if not G.active or not b.p.Parent then
      killRain(b); table.remove(G.rain, i)
    elseif t < b.fallT then
      b.warn.Transparency = 0.45 + 0.35 * math.abs(math.sin(t * 14))
    else
      b.y = b.y - RAIN_SPEED * dt
      placeBone(b.p, b.extra, CFrame.new(b.g.X, b.y, b.g.Z) * CFrame.Angles(math.rad(90), 0, 0))
      if b.y <= b.g.Y + b.len * 0.5 then
        local ring = ORBIT.newPart(fold(), "RainHit", V3(0.3, 2, 2),
          CF(b.g + V3(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), COL_BONE, true)
        ring.Shape = PT_CYL; ring.Material = MAT.Neon; ring.Transparency = 0.3
        quiet(ring)
        TS:Create(ring, TweenInfo.new(0.35), { Size = V3(0.3, 8, 8), Transparency = 1 }):Play()
        Debris:AddItem(ring, 0.45)
        shakeNear(b.g, 0.4, 0.2)
        local _, hum, root = getChar()
        if hum and root and root.Position.Y < b.g.Y + 6
           and (V3(root.Position.X, b.g.Y, root.Position.Z) - b.g).Magnitude <= 3.2 then
          pcall(function() hum:TakeDamage(18 * dmgMul()) end)
          G.hitTimes[#G.hitTimes + 1] = tick()
          ping("ping", 1, 0.8)
        end
        killRain(b); table.remove(G.rain, i)
      end
    end
  end
end

-- ============================================================
--       ТАБЛИЦА АТАК (7 шт.)
-- ============================================================
local function withModel(f)
  return function()
    local b = G.boss
    if b and b.model then f(b.model) end
  end
end

local ATTACKS = {
  { id = "blaster", minPhase = 1, fn = withModel(attackBlaster) },
  { id = "bones",   minPhase = 1, fn = withModel(attackBones) },
  { id = "words",   minPhase = 1, fn = withModel(attackWords) },
  { id = "bolt",    minPhase = 1, fn = attackLightning },
  { id = "hand",    minPhase = 2, fn = withModel(attackHand) },
  { id = "rain",    minPhase = 2, fn = attackBoneRain },
  { id = "dark",    minPhase = 3, fn = attackDarkBlast },
}
local DARK_ATTACK
for _, a in ipairs(ATTACKS) do
  if a.id == "dark" then DARK_ATTACK = a; break end
end

local function pickAttack()
  local b = G.boss
  if not b or G.darkBlast then return nil end
  if not G.darkBlastDone and b.hp <= b.maxHp * 0.5 then
    G.darkBlastDone = true
    G.lastAttackId = DARK_ATTACK.id
    return DARK_ATTACK
  end
  local pool = {}
  for _, a in ipairs(ATTACKS) do
    if (b.phase or 1) >= a.minPhase and a.id ~= G.lastAttackId
       and not (a.id == "rain" and #G.rain > 0) then
      pool[#pool + 1] = a
    end
  end
  if #pool == 0 then return nil end
  local a = pool[math.random(#pool)]
  G.lastAttackId = a.id
  return a
end

local function clearAttackFx()
  for _, b in ipairs(G.rain) do killRain(b) end
  G.rain = {}
  endDarkBlast()
end

-- ============================================================
--       УРОН ПО БОССУ (хук на ab.fireId)
-- ============================================================
local function hitBoss(n)
  local b = G.boss
  if not b then return end
  b.hp = math.max(0, b.hp - n)
  updateBossUI()
  G.hitTimes[#G.hitTimes + 1] = tick()
  local B = battle()
  if B and B.recordDamage then pcall(B.recordDamage, n, "boss") end
  if b.hp <= 0 then G.winBoss() end
end

local function hookDamage()
  local ab = ORBIT.abilities
  if not ab or type(ab.fireId) ~= "function" or G.hooked then return end
  G.hooked = true
  G._origFireId = ab.fireId
  local orig = ab.fireId
  ab.fireId = function(id, ch)
    local r = orig(id, ch)
    if r and G.hooked and G.boss and G.state == "boss" then
      hitBoss(ch and 45 or 25)
    end
    return r
  end
  G._wrapper = ab.fireId
end

local function unhookDamage()
  local ab = ORBIT.abilities
  if ab and G.hooked and G._origFireId and ab.fireId == G._wrapper then
    pcall(function() ab.fireId = G._origFireId end)
  end
  G.hooked = false
  G._origFireId = nil
  G._wrapper = nil
end

function G.damageBoss(n)
  hitBoss(n or 25)
end

-- ============================================================
--       Игра: старт/сброс/сбор
-- ============================================================
function G.start()
  if not alive then return false end
  if G.state == "collecting" or G.state == "boss" then
    if G.ui then toast("Игра уже идёт!") end
    return false
  end
  if not getChar() then return false end
  if not G.spawnParts() then return false end
  G.timer = 120; G.state = "collecting"; G.collected = 0
  ping("ping", 1, 1.2)
  if G.ui then toast("Собери все 16 частей! Осторожно — ловушки!") end
  uiRefresh()
  if ORBIT.notify then ORBIT.notify("👁 Игра началась! 16 частей тела + ловушки", C3(200, 220, 255), 3) end
  return true
end

function G.reset()
  local wasBoss = (G.state == "boss")
  clearShards()
  clearAttackFx()
  if wasBoss then
    unhookDamage()
    -- v25.3-fix2: A.battle от Клода — поля B.active/B.boss
    local B = battle()
    if B and B.active and B.boss == "gaster" and B.lose then
      pcall(B.lose, "сброс")
    end
    destroyBossModel()
    if G.cc then pcall(function() G.cc:Destroy() end); G.cc = nil end
  end
  G.state = "idle"; G.timer = 120; G.collected = 0
  G.active = false
  hideBossUI()
  G.boss = nil
  if G.ui then toast("Сброшено. Нажми СТАРТ.") end
  uiRefresh()
  if ORBIT.notify then ORBIT.notify("↺ Игра сброшена", C3(255, 200, 120), 2) end
end

local function fail(reason)
  clearShards()
  G.state = "idle"
  G.active = false
  hideBossUI()
  G.boss = nil
  ping("click", 1, 0.7)
  if G.ui then toast(reason or "Время вышло! Нажми СТАРТ.") end
  uiRefresh()
end

local function finalize(id)
  local s = G.parts[id]
  if not s or s.got then return end
  s.got = true
  if s.model then pcall(function() s.model:Destroy() end); s.model = nil end
  ping("botCollect", 1, 1)
  uiRefresh()
  local n = 0
  for _, q in pairs(G.parts) do if q.got then n = n + 1 end end
  if n >= #PARTS then
    task.delay(0.5, function() G.startBoss() end)
  end
end

function G.collectPart(id)
  local s = G.parts[id]
  if not alive or G.state ~= "collecting" or not s or s.got or s.flying or not s.model then return false end
  local c, h, root = getChar()
  if not root then return false end
  local cur = s.model:GetPivot().Position
  local d = (root.Position - cur).Magnitude
  if d > 12 then
    s.flying = true
    task.spawn(function()
      while alive and G.parts[id] == s and s.flying and s.model and s.model.Parent do
        local _, _, r2 = getChar()
        if not r2 then break end
        local cur2 = s.model:GetPivot().Position
        local target = r2.Position
        local dist = (target - cur2).Magnitude
        if dist < 2 then break end
        local step = math.min(dist, 60 * 0.03)
        s.model:PivotTo(CFrame.new(cur2 + (target - cur2).Unit * step))
        task.wait(0.03)
      end
      if alive and G.parts[id] == s then finalize(id) end
    end)
    return true
  end
  finalize(id)
  return true
end

local function trapHit(trap)
  if not trap or trap.hitCooldown > tick() then return end
  trap.hitCooldown = tick() + 2
  for id, s in pairs(G.parts) do
    if s.got then s.got = false; break end
  end
  ping("click", 1, 0.5)
  if G.ui then toast("⚠️ ЛОВУШКА! −1 часть") end
  if ORBIT.notify then ORBIT.notify("⚠️ Ловушка! Часть потеряна", C3(255, 100, 100), 2) end
  uiRefresh()
  local bp = ORBIT.newPart(fold(), "TrapFx", V3(0.2, 0.2, 0.2), CF(trap.part.Position), COL_TRAP, true)
  bp.Transparency = 1
  quiet(bp)
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(COL_TRAP); e.LightEmission = 1
  e.Size = NumberSequence.new(1.5, 0); e.Lifetime = NumberRange.new(0.5, 1)
  e.Speed = NumberRange.new(15, 25); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0
  e.Parent = bp
  e:Emit(50)
  Debris:AddItem(bp, 1.5)
end

-- ============================================================
--       БОСС
-- ============================================================
destroyBossModel = function(b)
  b = b or G.boss
  if not b then return end
  local Rig = ORBIT.figureRig
  if b.model then
    if Rig and Rig.detach then pcall(Rig.detach, b.model) end
    pcall(function() b.model:Destroy() end)
  end
  if b.blaster then pcall(function() b.blaster:Destroy() end) end
  if b == G.boss then G.boss = nil end
  G.bossVel = V3(0, 0, 0)
end

local function presetCreate(name, size, objName)
  local presets = ORBIT.SHAPE_PRESETS
  if type(presets) ~= "table" then return nil end
  for _, p in ipairs(presets) do
    if p.name == name and type(p.create) == "function" then
      local ok, d = pcall(p.create, size, objName)
      if ok and d and d.model then return d end
      return nil
    end
  end
  return nil
end

function G.startBoss()
  if not alive then return end
  local c, h, root = getChar()
  if not root then
    G.state = "idle"; G.active = false
    return
  end
  G.state = "boss"
  G.active = true
  G.walkPhase = 0
  G.walkTarget = nil
  G.nextRetarget = 0
  G.nextDodge = tick() + 3
  G.nextAttack = tick() + 2.5
  G.attackIndex = 0
  G.hitTimes = {}
  G.bossVel = V3(0, 0, 0)
  G.lastAttackId = nil
  G.darkBlastDone = false
  G.deadSince = nil
  clearAttackFx()
  clearShards()

  local data = presetCreate("ГАСТЕР", 5, "GasterBoss")
  if not data then
    warn("[OrbitGaster] пресет «ГАСТЕР» не найден — бой не запущен (нужен orbit_p2 v24.5)")
    if ORBIT.notify then ORBIT.notify("❌ Гастер: фигура не загружена (orbit_p2)", C3(255, 150, 150), 4) end
    G.state = "idle"; G.active = false
    uiRefresh()
    return
  end
  local Rig = ORBIT.figureRig
  if not (Rig and Rig.byModel and Rig.byModel[data.model]) then
    warn("[OrbitGaster] риг не подключён к фигуре — ходьба останется статичной (нужен orbit_p2 v24.5)")
  end
  data.model.Parent = fold()

  local cc = Instance.new("ColorCorrectionEffect")
  cc.Name = "OrbitGasterBossCC"; cc.Parent = Lighting
  G.cc = cc
  TS:Create(cc, TweenInfo.new(1.5), { Brightness = -0.15, Saturation = -0.3, TintColor = C3(230, 230, 255) }):Play()
  ping("laugh", 1, 0.8)

  local HAND_PART_NAMES = {
    F1 = true, F2 = true, F3 = true, F4 = true,
    Palm = true, Wrap1 = true, Wrap2 = true, Spike = true,
    Heart = true, P = true, Bevel = true, Shine = true,
    HandL = true, HandR = true, Finger = true, Thumb = true,
    Arm = true, Wrist = true, Elbow = true,
  }
  for _, d in ipairs(data.model:GetDescendants()) do
    if d:IsA("BasePart") and HAND_PART_NAMES[d.Name] then
      pcall(function() d.Size = d.Size * 3 end)
    end
  end

  for _, ch in ipairs(data.model:GetChildren()) do
    if ch.Name:find("Blaster") then pcall(function() ch:Destroy() end) end
  end
  local bd = presetCreate("ГАСТЕР БЛАСТЕР", 3.5, "GasterBossBlaster")
  local bossBlaster = bd and bd.model or nil
  local charge, light
  if bossBlaster then
    bossBlaster.Parent = fold()
    for _, d in ipairs(bossBlaster:GetDescendants()) do
      if d:IsA("BasePart") then d:SetAttribute("NoRecolor", true) end
    end
    charge = bossBlaster:FindFirstChild("Charge", true)
    light = charge and charge:FindFirstChild("GLight") or nil
  end

  local gp = groundAt(root.Position + root.CFrame.LookVector * 20)
  local finalPos = V3(gp.X, gp.Y + GROUND_Y, gp.Z)
  pcall(function() data.model:PivotTo(faceCF(finalPos, root.Position)) end)

  G.boss = {
    data = data, model = data.model, root = data.part or data.model.PrimaryPart,
    blaster = bossBlaster, charge = charge, light = light,
    hp = 650, maxHp = 650, phase = 1,
  }
  G.walkTarget = finalPos

  showBossUI()
  updateBossUI()
  hookDamage()
  local B = battle()
  if B and B.start then
    pcall(B.start, "gaster", {
      maxHp = 650,
      getHp = function() return G.boss and G.boss.hp or 0, 650 end,
      getModel = function() return G.boss and G.boss.model or nil end,
    })
  end

  if G.ui then toast("ГАСТЕР ПРОБУДИЛСЯ! Бей своими стихиями!") end
  if ORBIT.notify then
    ORBIT.notify("👁 ГАСТЕР ПРОБУДИЛСЯ!", C3(255, 100, 200), 4)
    ORBIT.notify("⚔️ Применяй свои способности — наноси урон!", C3(255, 200, 120), 5)
  end
end

-- ============================================================
--       ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function stepShards(dt, t)
  if G.state ~= "collecting" then return end
  for id, s in pairs(G.parts) do
    if not s.got and s.model and s.model.Parent and not s.flying then
      local ang = t * s.speed + s.phase
      local offset = V3(math.cos(ang) * s.radius, math.sin(t * 2 + s.phase) * 0.8, math.sin(ang) * s.radius)
      s.model:PivotTo(CFrame.new(s.base + offset) * CFrame.Angles(0, t * 1.5 + s.phase, 0))
    end
  end
end

local function stepTraps(dt, t)
  if G.state ~= "collecting" then return end
  local c, h, root = getChar()
  if not root then return end
  for _, tr in ipairs(G.traps) do
    if tr.part and tr.part.Parent then
      tr.angle = tr.angle + tr.angleSpeed * dt
      local x = root.Position.X + math.cos(tr.angle) * tr.baseRadius
      local z = root.Position.Z + math.sin(tr.angle) * tr.baseRadius
      local y = tr.baseY + math.sin(t * 1.5 + tr.bobPhase) * 1.5
      tr.part.CFrame = CF(V3(x, y, z))
      local d = (tr.part.Position - root.Position).Magnitude
      if d < tr.r / 2 + 3 then trapHit(tr) end
    end
  end
end

local BL_FWD, BL_RIGHT, BL_UP = 2.5, 10, 20

local function stepBoss(dt, t)
  local b = G.boss
  if not b or not G.active or G.state ~= "boss" then return end
  local model = b.model
  if not model or not model.Parent then
    G.failBoss("босс исчез")
    return
  end

  if not getChar() then
    G.deadSince = G.deadSince or t
    if t - G.deadSince > 3 then G.failBoss("ты пал. спишемся."); return end
  else
    G.deadSince = nil
  end

  if G.darkBlast then
    G.bossVel = V3(0, 0, 0)
    local _, _, r = getChar()
    if r then pcall(function() model:PivotTo(faceCF(model:GetPivot().Position, r.Position)) end) end
  else
    stepBossMovement(dt, t)
  end
  stepDarkBlast(dt, t)
  stepRain(dt, t)

  if b.light then b.light.Brightness = 1.5 + 0.6 * math.sin(t * 3) end

  if b.blaster and b.blaster.Parent then
    local _, _, r2 = getChar()
    local mcf = model:GetPivot()
    local bossPos = mcf.Position
    local targetPos = r2 and r2.Position or (bossPos - mcf.LookVector * 20)
    local toTarget = V3(targetPos.X - bossPos.X, 0, targetPos.Z - bossPos.Z)
    if toTarget.Magnitude > 0.1 then
      local dir = toTarget.Unit
      local right = dir:Cross(V3(0, 1, 0)).Unit
      local bp = bossPos + dir * BL_FWD + right * BL_RIGHT + V3(0, BL_UP, 0)
      pcall(function() b.blaster:PivotTo(CFrame.lookAt(bp, targetPos)) end)
    else
      local bp = bossPos + V3(0, 8, 0)
      pcall(function() b.blaster:PivotTo(CFrame.lookAt(bp, bp - mcf.LookVector)) end)
    end
  end

  if t >= G.nextAttack then
    local a = pickAttack()
    if a then
      local base = (b.phase == 1) and 3.5 or ((b.phase == 2) and 2.8 or 2.2)
      G.nextAttack = t + base * intervalMul()
      local ok, err = pcall(a.fn)
      if not ok then warn("[OrbitGaster] атака " .. tostring(a.id) .. ": " .. tostring(err)) end
    else
      G.nextAttack = t + 0.4
    end
  end

  if #G.hitTimes > 20 then table.remove(G.hitTimes, 1) end

  applyRig(dt)
end

-- ============================================================
--       ПОБЕДА / ПОРАЖЕНИЕ
-- ============================================================
local REWARDS = {
  { id = "gaster_weapon",         name = "⚔ Гастер-бластер открыт в арсенале" },
  { id = "gaster_boss_skin",      name = "🎨 Скин «Гастер-босс» открыт" },
  { id = "blue_eye_tick",         name = "💧 Синий глаз-тик" },
  { id = "gaster_skull_helmet",   name = "💀 Костяной шлем" },
  { id = "gaster_double_blaster", name = "⚡ Двойной бластер" },
  { id = "gaster_portal_fx",      name = "🌀 Тёмный портал" },
  { id = "gaster_blue_particles", name = "💠 Синие частицы" },
  { id = "coins_gaster",          name = "💰 +800 монет" },
}

function G.winBoss()
  if not G.boss then return end
  local b = G.boss
  G.boss = nil
  G.state = "won"
  G.active = false
  hideBossUI()
  unhookDamage()
  clearAttackFx()
  local B = battle()
  if B and B.win then pcall(B.win, { boss = "gaster" }) end

  if b.blaster then pcall(function() b.blaster:Destroy() end); b.blaster = nil end

  if b.model then
    local pos = b.model:GetPivot().Position
    for i = 1, 8 do
      task.delay(i * 0.1, function()
        if not alive then return end
        local p = ORBIT.newPart(fold(), "WinFx", V3(2, 2, 2),
          CF(pos + V3(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))), COL_BEAM, true)
        p.Shape = PT_BALL; p.Material = MAT.Neon; p.Transparency = 0.2
        quiet(p)
        TS:Create(p, TweenInfo.new(0.6), { Size = V3(15, 15, 15), Transparency = 1 }):Play()
        Debris:AddItem(p, 0.7)
        ping("ping", 1, 0.6 + i * 0.1)
      end)
    end
    task.delay(1, function() destroyBossModel(b) end)
  end
  task.delay(1.2, function()
    if G.cc then TS:Create(G.cc, TweenInfo.new(1.5), { Brightness = 0, Saturation = 0, TintColor = C3(255, 255, 255) }):Play() end
    task.delay(1.8, function()
      if G.cc then pcall(function() G.cc:Destroy() end); G.cc = nil end
    end)
  end)
  local c, h, root = getChar()
  if root and ORBIT.sans and ORBIT.sans.showAt then
    pcall(ORBIT.sans.showAt, root.Position + V3(0, 6, 0), "Ты... справился. Неплохо.", 5)
  end
  ping("sans", 1, 1)

  ORBIT.gasterUnlocked = true
  ORBIT.gasterWeaponUnlocked = true
  ORBIT.saveData = ORBIT.saveData or {}
  ORBIT.saveData.gasterUnlocked = true
  ORBIT.saveData.gasterWeaponUnlocked = true
  ORBIT.saveData.rewards = ORBIT.saveData.rewards or {}

  local given = {}
  for _, rw in ipairs(REWARDS) do
    if not ORBIT.saveData.rewards[rw.id] then
      ORBIT.saveData.rewards[rw.id] = true
      given[#given + 1] = rw
    end
  end
  ORBIT.COINS = (ORBIT.COINS or 0) + 800
  if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
  if ORBIT.saveStorage then pcall(ORBIT.saveStorage) end

  if ORBIT.notify then
    ORBIT.notify("🏆 ГАСТЕР ПОВЕРЖЕН!", C3(180, 255, 180), 5)
    ORBIT.notify("💰 +800 монет!", C3(255, 220, 100), 4)
    local shown = 0
    for _, rw in ipairs(given) do
      if rw.id ~= "coins_gaster" then
        shown = shown + 1
        task.delay(0.5 + shown * 0.35, function() ORBIT.notify(rw.name, C3(200, 220, 255), 4) end)
      end
    end
  end
  if G.ui then toast("✅ ГАСТЕР ПОВЕРЖЕН!") end
  uiRefresh()
end

function G.failBoss(reason)
  if G.state ~= "boss" then return end
  G.state = "idle"
  G.active = false
  hideBossUI()
  unhookDamage()
  clearAttackFx()
  local B = battle()
  if B and B.lose then pcall(B.lose, reason) end
  destroyBossModel()
  if G.cc then pcall(function() G.cc:Destroy() end); G.cc = nil end
  ping("click", 1, 0.5)
  if ORBIT.notify then ORBIT.notify("👁 Гастер ушёл... " .. (reason or ""), C3(255, 180, 180), 4) end
  if G.ui then toast(reason or "Нажми СТАРТ.") end
  uiRefresh()
end
G.loseBoss = G.failBoss

-- ============================================================
--       ГЛАВНЫЙ HEARTBEAT
-- ============================================================
G.heartbeat = RS.Heartbeat:Connect(function(dt)
  if not alive then return end
  local t = tick()
  if not G.shapeRegistered then
    if not G._shapeAcc then G._shapeAcc = 0 end
    G._shapeAcc = G._shapeAcc + dt
    if G._shapeAcc > 1 then G._shapeAcc = 0; G.registerShape() end
  end

  if G.state == "collecting" then
    G.timer = G.timer - dt
    stepShards(dt, t)
    stepTraps(dt, t)
    local c, h, root = getChar()
    if root then
      for id, s in pairs(G.parts) do
        if not s.got and s.model and s.model.Parent and not s.flying then
          if (root.Position - s.model:GetPivot().Position).Magnitude < 5 then G.collectPart(id) end
        end
      end
    end
    if G.ui and not G.uiHidden then G.ui.timer.Text = "⏱ " .. fmtTime(G.timer) end
    if G.timer <= 0 then fail("Время вышло! Нажми СТАРТ.") end
  elseif G.state == "boss" then
    stepBoss(dt, t)
  end

  if G.figure then
    local f = G.figure
    local m = f.data.model
    if m.Parent then
      local c, h, root = getChar()
      f.angle = f.angle + dt * 2 * math.pi / 30
      f.riseT = math.min(1.5, f.riseT + dt)
      local kk = f.riseT / 1.5
      kk = 1 - (1 - kk) * (1 - kk)
      local center = root and root.Position or V3()
      local ca, sa = math.cos(f.angle), math.sin(f.angle)
      local pos = center + V3(ca * 10, 12 + math.sin(t * 1.5) * 0.5 - 12 * (1 - kk), sa * 10)
      local look = pos + V3(-sa, 0, ca)
      pcall(function() m:PivotTo(CFrame.lookAt(pos, look)) end)
      if kk >= 1 then
        if t >= f.nextShot then
          f.nextShot = t + math.random(3, 5)
          local enemies = {}
          for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
              local h2 = pl.Character:FindFirstChildOfClass("Humanoid")
              local r2 = pl.Character:FindFirstChild("HumanoidRootPart")
              if h2 and r2 and h2.Health > 0 and (r2.Position - center).Magnitude <= 100 then
                enemies[#enemies + 1] = { hum = h2, root = r2 }
              end
            end
          end
          if #enemies > 0 then
            local target = enemies[math.random(#enemies)]
            f.fire = { t0 = t, hum = target.hum, root = target.root, tpos = target.root.Position }
          end
        end
        if f.fire then
          if f.fire.root and f.fire.root.Parent then f.fire.tpos = f.fire.root.Position end
          local el = t - f.fire.t0
          if f.light then f.light.Brightness = 1.5 + 4 * math.min(1, el / 0.5) end
          if el >= 0.5 and not f.fire.shot then
            f.fire.shot = true
            shootBeamSimple(f.charge and f.charge.Position or pos, f.fire.tpos, f.fire)
          end
          if el >= 1.0 then f.fire = nil end
        elseif f.light then
          f.light.Brightness = 1.5 + 0.5 * math.sin(t * 3)
        end
      end
    else
      G.figure = nil
    end
  end
end)

function G.open()
  if not alive then return false end
  if (G.state == "collecting" or G.state == "boss") then
    if G.ui then G.showUI() else buildUI() end
    return true
  end
  buildUI()
  return true
end

-- ============================================================
--       ФИГУРА-СПУТНИК (после победы)
-- ============================================================
function G.removeFigure()
  token = token + 1
  if G.figure then
    pcall(function() G.figure.data.model:Destroy() end)
    G.figure = nil
  end
end

local function buildFigure()
  local data = presetCreate("ГАСТЕР БЛАСТЕР", 3.5, "GasterBlasterOrbit")
  if not data then data = createGaster(3.5, "GasterBlasterOrbit") end
  data.model.Parent = fold()
  local f = { data = data, angle = 0, riseT = 0, nextShot = tick() + 3, fire = nil, charge = nil, light = nil }
  f.charge = data.model:FindFirstChild("Charge", true)
  f.light = f.charge and f.charge:FindFirstChild("GLight") or nil
  G.figure = f
  return f
end

function G.assemble(quick)
  if not alive then return false end
  G.state = "won"
  clearShards()
  hideBossUI()
  G.boss = nil
  token = token + 1
  local my = token
  G.removeFigure()
  token = my
  uiRefresh()
  task.spawn(function()
    local function ok() return alive and token == my end
    local c, h, root = getChar()
    if not quick and root then
      if G.ui then toast("Что-то пробуждается...") end
      ping("laugh", 1, 0.8)
      for _ = 1, 6 do
        if not ok() then return end
        local c2, h2, r2 = getChar()
        if r2 then
          local o = r2.Position + V3(math.random(-12, 12), 0, math.random(-12, 12))
          local p = ORBIT.newPart(fold(), "AsmFx", V3(0.2, 0.2, 0.2), CF(o + V3(0, 40, 0)), COL_GLOW, true)
          p.Transparency = 1
          quiet(p)
          local e = Instance.new("ParticleEmitter")
          e.Color = ColorSequence.new(COL_GLOW); e.LightEmission = 1
          e.Size = NumberSequence.new(0.8, 0); e.Lifetime = NumberRange.new(0.5, 1)
          e.Speed = NumberRange.new(15, 25); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0
          e.Parent = p
          e:Emit(20)
          Debris:AddItem(p, 1.5)
        end
        ping("snap", 0.8, 0.6 + math.random() * 0.4)
        task.wait(0.3)
      end
      task.wait(0.3)
    end
    if not ok() then return end
    buildFigure()
    uiRefresh()
  end)
  return true
end

-- ============================================================
--       ОРУЖИЕ (бластер в руке scale 4.5)
-- ============================================================
local W = { equipped = false, models = {}, proj = {}, cdUntil = 0, conns = {}, side = 1 }
local wFolder, wGui, wBtn = nil, nil, nil
local function wFold()
  if wFolder and wFolder.Parent then return wFolder end
  wFolder = Instance.new("Folder"); wFolder.Name = "OrbitAtmo_GasterWeapon_" .. LP.UserId; wFolder.Parent = WS
  return wFolder
end
local function wNotify(text) if ORBIT.notify then pcall(ORBIT.notify, text, C3(220, 220, 255), 3) end end

local function mkfx(parent, name, size, cf, col, shape, mat, tr)
  local p = ORBIT.newPart(parent, name, size, cf, col, true)
  if shape then p.Shape = shape end
  p.Material = mat or MAT.Neon
  p.Transparency = tr or 0
  p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
  return p
end

local function getHands(char)
  local hum = char:FindFirstChildOfClass("Humanoid")
  local r15 = hum ~= nil and hum.RigType == Enum.HumanoidRigType.R15
  if r15 then
    return char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm"), char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm"), true
  end
  return char:FindFirstChild("Left Arm"), char:FindFirstChild("Right Arm"), false
end
local function handCF(hand, r15)
  if r15 then return hand.CFrame * CF(0, 2, -1.2) end
  return hand.CFrame * CF(0, 1, -1.2)
end
local function wAim(origin)
  local cm = WS.CurrentCamera
  if not cm then return origin + V3(0, 0, -50) end
  local sp = UIS_W.MouseEnabled and UIS_W:GetMouseLocation() or (cm.ViewportSize / 2)
  local ray = cm:ViewportPointToRay(sp.X, sp.Y)
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { LP.Character or wFold(), wFold(), fold() }
  local res = WS:Raycast(ray.Origin, ray.Direction * 400, rp)
  return res and res.Position or (ray.Origin + ray.Direction * 400)
end
local function wExplode(pos)
  local b = mkfx(wFold(), "GBlast", V3(1, 1, 1), CF(pos), COL_BEAM, PT_BALL, MAT.Neon, 0.25)
  TS:Create(b, TweenInfo.new(0.35), { Size = V3(12, 12, 12), Transparency = 1 }):Play()
  Debris:AddItem(b, 0.5)
  local sp = mkfx(wFold(), "GBlastSp", V3(0.2, 0.2, 0.2), CF(pos), COL_BEAM, nil, MAT.Neon, 1)
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(COL_GLOW); e.LightEmission = 1
  e.Size = NumberSequence.new(1.2, 0); e.Lifetime = NumberRange.new(0.5, 1)
  e.Speed = NumberRange.new(10, 20); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0
  e.Parent = sp
  e:Emit(24)
  Debris:AddItem(sp, 1.5)
  for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LP and pl.Character then
      local h = pl.Character:FindFirstChildOfClass("Humanoid")
      local r = pl.Character:FindFirstChild("HumanoidRootPart")
      if h and r and h.Health > 0 and (r.Position - pos).Magnitude <= 6 then pcall(h.TakeDamage, h, 30) end
    end
  end
  ping("ping", 1, 1)
end

function W.shoot()
  if not alive or not W.equipped then return false end
  local t = tick()
  if t < W.cdUntil then return false end
  local c, h = getChar()
  if not c or h.Health <= 0 then return false end
  local cd = 0.8
  if ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_double_blaster"] then
    cd = 0.4
  end
  W.cdUntil = t + cd
  W.side = -W.side
  local m = W.models[W.side == 1 and "R" or "L"] or W.models.R or W.models.L
  local charge = m and m:FindFirstChild("Charge", true)
  local origin = charge and charge.Position or (c.PrimaryPart and c.PrimaryPart.Position) or V3()
  local dir = wAim(origin) - origin
  if dir.Magnitude < 0.5 then dir = (c.PrimaryPart and c.PrimaryPart.CFrame.LookVector) or V3(0, 0, -1) end
  dir = dir.Unit
  local p = mkfx(wFold(), "GasterShot", V3(1.4, 1.4, 1.4), CF(origin), COL_BEAM, PT_BALL, MAT.Neon, 0)
  local l = Instance.new("PointLight"); l.Color = COL_GLOW; l.Range = 12; l.Brightness = 3; l.Parent = p
  W.proj[#W.proj + 1] = { part = p, vel = dir * 140, born = t }
  ping("ping", 1, 0.6)
  return true
end

local function wShowBtn(on)
  if not UIS_W.TouchEnabled then return end
  if on and not wGui then
    local pg = uiParent()
    if not pg then return end
    wGui = Instance.new("ScreenGui")
    wGui.Name = "OrbitGasterWeaponGui"; wGui.ResetOnSpawn = false; wGui.IgnoreGuiInset = true; wGui.DisplayOrder = 22; wGui.Parent = pg
    wBtn = Instance.new("TextButton")
    wBtn.AnchorPoint = Vector2.new(1, 1); wBtn.Position = UDim2.new(1, -110, 1, -125); wBtn.Size = UDim2.fromOffset(56, 56)
    wBtn.Text = "👁"; wBtn.TextSize = 28; wBtn.Font = Enum.Font.GothamBold; wBtn.TextColor3 = C3(255, 255, 255)
    wBtn.BackgroundColor3 = C3(90, 90, 130); wBtn.BackgroundTransparency = 0.1; wBtn.AutoButtonColor = false; wBtn.Parent = wGui
    Instance.new("UICorner", wBtn).CornerRadius = UDim.new(0, 28)
    local t0 = 0
    wBtn.InputBegan:Connect(function(i)
      if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then t0 = tick() end
    end)
    wBtn.InputEnded:Connect(function(i)
      if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - t0 > 0.6 then W.unequip() else W.shoot() end
      end
    end)
  elseif not on and wGui then
    pcall(function() wGui:Destroy() end); wGui, wBtn = nil, nil
    killGui("OrbitGasterWeaponGui")
  end
end

function W.equip()
  if not alive then return false end
  if W.equipped then return true end
  if not (ORBIT.gasterUnlocked or ORBIT.gasterWeaponUnlocked) then
    wNotify("🔒 Сначала пройди «Собери Гастера»"); return false
  end
  local c, h = getChar()
  if not c or h.Health <= 0 then return false end
  for _, k in ipairs({ "L", "R" }) do
    local data = presetCreate("ГАСТЕР БЛАСТЕР", 4.5, "GasterHand" .. k)
    if not data then data = createGaster(4.5, "GasterHand" .. k) end
    data.model.Parent = wFold()
    for _, d in ipairs(data.model:GetDescendants()) do
      if d:IsA("BasePart") then d:SetAttribute("NoRecolor", true) end
    end
    W.models[k] = data.model
  end
  W.equipped = true
  wShowBtn(true)
  ORBIT.gasterWeaponUnlocked = true
  ORBIT.saveData = ORBIT.saveData or {}
  ORBIT.saveData.gasterWeaponUnlocked = true
  if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
  local hint = UIS_W.TouchEnabled and "Тап — выстрел, удержание — снять" or "G — выстрел, H — снять"
  wNotify("👁 Гастер-бластеры в руках: " .. hint)
  return true
end

function W.unequip()
  W.equipped = false
  for k, m in pairs(W.models) do pcall(function() m:Destroy() end); W.models[k] = nil end
  for _, q in ipairs(W.proj) do pcall(function() q.part:Destroy() end) end
  W.proj = {}
  wShowBtn(false)
end

function W.toggle() if W.equipped then W.unequip() else W.equip() end end

function W.update(dt)
  if not W.equipped then return end
  local c, h = getChar()
  if not c or h.Health <= 0 then W.unequip(); return end
  local lh, rh, r15 = getHands(c)
  if lh and W.models.L then pcall(function() W.models.L:PivotTo(handCF(lh, r15)) end) end
  if rh and W.models.R then pcall(function() W.models.R:PivotTo(handCF(rh, r15)) end) end
  if #W.proj == 0 then return end
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { c, wFold(), fold() }
  local t = tick()
  for i = #W.proj, 1, -1 do
    local q = W.proj[i]
    if not q.part.Parent or t - q.born > 2.5 then
      pcall(function() q.part:Destroy() end); table.remove(W.proj, i)
    else
      local from = q.part.Position
      local to = from + q.vel * dt
      local hit
      local res = WS:Raycast(from, to - from, rp)
      if res then
        local m = res.Instance:FindFirstAncestorOfClass("Model")
        if res.Instance.CanCollide or (m and m:FindFirstChildOfClass("Humanoid")) then hit = res.Position end
      end
      if not hit then
        for _, pl in ipairs(Players:GetPlayers()) do
          local r = pl ~= LP and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
          if r and (r.Position - to).Magnitude < 3 then hit = to; break end
        end
      end
      if hit then
        table.remove(W.proj, i)
        pcall(function() q.part:Destroy() end)
        wExplode(hit)
      else
        q.part.CFrame = CF(to)
      end
    end
  end
end

W.conns[#W.conns + 1] = UIS_W.InputBegan:Connect(function(i, gp)
  if gp or not alive or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
  if i.KeyCode == Enum.KeyCode.G then
    if W.equipped then W.shoot() else W.equip() end
  elseif i.KeyCode == Enum.KeyCode.H then
    W.unequip()
  end
end)

function W.destroy()
  W.unequip()
  for _, c in ipairs(W.conns) do pcall(function() c:Disconnect() end) end
  W.conns = {}
  killGui("OrbitGasterWeaponGui")
  if wFolder then pcall(function() wFolder:Destroy() end); wFolder = nil end
end
G.weapon = W

-- ============================================================
--       ПАССИВНЫЕ ЭФФЕКТЫ ОТ НАГРАД
-- ============================================================
local fxFolder, portalModel, trailAcc = nil, nil, 0
local function fxFold()
  if fxFolder and fxFolder.Parent then return fxFolder end
  fxFolder = Instance.new("Folder"); fxFolder.Name = "OrbitGasterFx_" .. LP.UserId; fxFolder.Parent = WS
  return fxFolder
end

local function ensurePortal()
  if not (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_portal_fx"]) then return end
  local c = LP.Character
  if not c or not c:FindFirstChild("HumanoidRootPart") then return end
  if portalModel and portalModel.Parent then
    local r = c.HumanoidRootPart
    local pos = r.Position + r.CFrame.LookVector * -3 + V3(0, 1.5, 0)
    pcall(function() portalModel:PivotTo(CFrame.lookAt(pos, pos + r.CFrame.LookVector)) end)
    return
  end
  local m = Instance.new("Model"); m.Name = "OrbitPortal"
  local root = ORBIT.newPart(m, "Root", V3(0.1, 0.1, 0.1), CF(), C3(0, 0, 0), true)
  root.Transparency = 1; quiet(root)
  m.PrimaryPart = root
  for i = 1, 3 do
    local col = i == 1 and C3(120, 60, 200) or (i == 2 and C3(80, 40, 160) or C3(40, 20, 100))
    local ring = mkfx(m, "Ring" .. i, V3(0.15, 3 - i * 0.5, 3 - i * 0.5), CF(), col, PT_CYL, MAT.Neon, 0.3 - i * 0.05)
    ring.CastShadow = false
  end
  m.Parent = fxFold()
  portalModel = m
end

local function spawnBlueTrail(dt)
  if not (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_blue_particles"]) then return end
  local c = LP.Character
  if not c or not c:FindFirstChild("HumanoidRootPart") then return end
  local h = c:FindFirstChildOfClass("Humanoid")
  if not h or h.MoveDirection.Magnitude < 0.1 then return end
  trailAcc = trailAcc + dt
  if trailAcc < 0.06 then return end
  trailAcc = 0
  local r = c.HumanoidRootPart
  local pos = r.Position + V3(math.random() - 0.5, -0.5, math.random() - 0.5)
  local p = mkfx(fxFold(), "BlueTrail", V3(0.35, 0.35, 0.35), CF(pos), C3(120, 180, 255), PT_BALL, MAT.Neon, 0.15)
  p.CastShadow = false
  local l = Instance.new("PointLight"); l.Color = C3(120, 180, 255); l.Range = 5; l.Brightness = 1.5; l.Parent = p
  TS:Create(p, TweenInfo.new(0.5), { Transparency = 1, Size = V3(0.05, 0.05, 0.05) }):Play()
  TS:Create(l, TweenInfo.new(0.5), { Brightness = 0 }):Play()
  Debris:AddItem(p, 0.6)
end

G.fxHb = RS.Heartbeat:Connect(function(dt)
  if not alive then return end
  if G.weapon then pcall(function() G.weapon.update(dt) end) end
  pcall(ensurePortal)
  pcall(spawnBlueTrail, dt)
end)

-- ============================================================
--       ОЧИСТКА
-- ============================================================
function G.destroy()
  if not alive then return end
  alive = false
  G.active = false
  unhookDamage()
  if G.heartbeat then pcall(function() G.heartbeat:Disconnect() end); G.heartbeat = nil end
  if G.fxHb then pcall(function() G.fxHb:Disconnect() end); G.fxHb = nil end
  -- v25.3-fix2: A.battle от Клода — поля B.active/B.boss
  local B = battle()
  if B and B.active and B.boss == "gaster" and B.cleanup then
    pcall(B.cleanup)
  end
  clearShards()
  clearAttackFx()
  hideBossUI()
  closeUI()
  G.removeFigure()
  destroyBossModel()
  G.state = "idle"
  if G.weapon and G.weapon.destroy then pcall(G.weapon.destroy) end
  if G.cc then pcall(function() G.cc:Destroy() end); G.cc = nil end
  G.flashFrame = nil
  killGui("_OrbitGasterFlash")
  for _, nm in ipairs({ "OrbitGasterGui", "_OrbitGasterBoss", "OrbitGasterWeaponGui" }) do killGui(nm) end
  if folder then pcall(function() folder:Destroy() end); folder = nil end
  if portalModel then pcall(function() portalModel:Destroy() end); portalModel = nil end
  if fxFolder then pcall(function() fxFolder:Destroy() end); fxFolder = nil end
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
G.version = "v25.3-fix2"
ORBIT.gaster = G
if ORBIT.gasterUnlocked == nil then ORBIT.gasterUnlocked = false end
G.registerShape()
ORBIT.loaded.gaster = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(G.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("👁 Гастер v25.3-fix2 (7 атак, риг ходьбы, ярость и награды)", C3(220, 200, 255), 3)
end

return true
