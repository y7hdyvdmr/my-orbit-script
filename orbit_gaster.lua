-- ORBIT v24.2-fix2 | orbit_gaster.lua
-- 16 осколков + ловушки + босс-файт + белое оружие.
-- v24.2: "ЗАКРЫТЬ" прячет UI, но НЕ сбрасывает игру.
-- v24.2-fix1: G.destroy восстанавливает ab.fireId (сохраняем в G._origFireId).
-- v24.2-fix2: createGaster перерисован (STRONG) по силуэту из Blender-файла.
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

local G = {
  active = false,
  state = "idle",
  parts = {},
  traps = {},
  figure = nil,
  boss = nil,
  bossUI = nil,
  timer = 120,
  shapeRegistered = false,
  uiHidden = false,
  _origFireId = nil,
}
local alive, folder, token = true, nil, 0

local PARTS = {
  { id = "head",   nm = "Голова",       col = C3(250, 245, 235), shape = PT_BLOCK, sz = 2.4, px = 0.5,  py = 0.14, sw = 46, sh = 34, z = 1 },
  { id = "eyeL",   nm = "Левый глаз",   col = C3(120, 230, 255), shape = PT_BALL,  sz = 1.4, px = 0.4,  py = 0.13, sw = 10, sh = 10, z = 3, round = true },
  { id = "eyeR",   nm = "Правый глаз",  col = C3(120, 230, 255), shape = PT_BALL,  sz = 1.4, px = 0.6,  py = 0.13, sw = 10, sh = 10, z = 3, round = true },
  { id = "brow",   nm = "Бровь",        col = C3(240, 240, 250), shape = PT_BLOCK, sz = 1.6, px = 0.5,  py = 0.05, sw = 40, sh = 8,  z = 2 },
  { id = "cheekL", nm = "Левая щека",   col = C3(230, 220, 240), shape = PT_BLOCK, sz = 1.4, px = 0.32, py = 0.22, sw = 12, sh = 18, z = 2 },
  { id = "cheekR", nm = "Правая щека",  col = C3(230, 220, 240), shape = PT_BLOCK, sz = 1.4, px = 0.68, py = 0.22, sw = 12, sh = 18, z = 2 },
  { id = "hornL",  nm = "Левый рог",    col = C3(210, 210, 230), shape = PT_BLOCK, sz = 1.6, px = 0.30, py = 0.02, sw = 12, sh = 18, z = 2 },
  { id = "hornR",  nm = "Правый рог",   col = C3(210, 210, 230), shape = PT_BLOCK, sz = 1.6, px = 0.70, py = 0.02, sw = 12, sh = 18, z = 2 },
  { id = "snout",  nm = "Нос",          col = C3(240, 235, 220), shape = PT_BLOCK, sz = 2.0, px = 0.5,  py = 0.30, sw = 26, sh = 20, z = 2 },
  { id = "jaw",    nm = "Челюсть",      col = C3(240, 235, 220), shape = PT_BLOCK, sz = 1.8, px = 0.5,  py = 0.38, sw = 30, sh = 14, z = 2 },
  { id = "toothU", nm = "Верхний клык", col = C3(255, 255, 255), shape = PT_BLOCK, sz = 1.2, px = 0.42, py = 0.32, sw = 8,  sh = 12, z = 3 },
  { id = "toothL", nm = "Нижний клык",  col = C3(255, 255, 255), shape = PT_BLOCK, sz = 1.2, px = 0.58, py = 0.32, sw = 8,  sh = 12, z = 3 },
  { id = "armL",   nm = "Левая рука",   col = C3(220, 220, 235), shape = PT_BLOCK, sz = 2,   px = 0.16, py = 0.5,  sw = 18, sh = 52, z = 1 },
  { id = "armR",   nm = "Правая рука",  col = C3(220, 220, 235), shape = PT_BLOCK, sz = 2,   px = 0.84, py = 0.5,  sw = 18, sh = 52, z = 1 },
  { id = "torso",  nm = "Туловище",     col = C3(200, 200, 220), shape = PT_BLOCK, sz = 2.6, px = 0.5,  py = 0.5,  sw = 42, sh = 56, z = 1 },
  { id = "boots",  nm = "Ботинки",      col = C3(170, 170, 200), shape = PT_BLOCK, sz = 2.2, px = 0.5,  py = 0.87, sw = 58, sh = 20, z = 1 },
}

local function ping(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end
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

-- ============================================================
--       Белый Гастер (STRONG-версия по силуэту из Blender)
-- ============================================================
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

  -- ===== череп =====
  bar("Skull", V3(0, 0.1, 0.8), V3(0, 1.3, 2.0), 1.25, 1.0)
  bar("SkullBack", V3(0, 1.2, 1.9), V3(0, 2.7, 3.2), 2.0, 1.0)
  bar("Dome", V3(0, 2.0, 2.6), V3(0, 3.0, 3.4), 1.7, 0.7)
  bar("Brow", V3(-0.75, 0.9, 2.0), V3(0.75, 0.9, 2.0), 0.35, 0.28)
  for _, sd in ipairs({ -1, 1 }) do
    bar("Cheek", V3(sd * 0.55, 0.3, 0.7), V3(sd * 0.95, 1.6, 1.4), 0.3, 0.35)
  end
  -- морда, нос
  bar("Snout", V3(0, -0.2, 1.2), V3(0, 1.0, 1.6), 0.65, 0.5)
  bar("NosePlate", V3(0, -0.22, 1.55), V3(0, 0.6, 1.85), 0.3, 0.12, RIB, MAT.Metal)
  -- челюсть, боковые отростки
  bar("Jaw", V3(0, -0.2, 0.35), V3(0, 1.3, 0.75), 0.6, 0.28)
  bar("Chin", V3(0, -0.28, 0.2), V3(0, 0.1, 0.45), 0.4, 0.3)
  for _, sd in ipairs({ -1, 1 }) do
    bar("JawSide", V3(sd * 0.4, 0.4, 0.55), V3(sd * 1.2, 2.4, 1.25), 0.2, 0.16)
    wedge("JawSpike", V3(sd * 1.2, 2.4, 1.25), V3(sd * 1.55, 3.0, 1.3), 0.14, 0.3)
    wedge("JawSpike", V3(sd * 0.9, 1.5, 0.95), V3(sd * 1.4, 1.9, 1.05), 0.12, 0.24)
  end
  -- зубы
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
  -- пасть
  bar("MouthDark", V3(0, 0.15, 0.75), V3(0, 1.5, 0.9), 0.5, 0.4, DARK, MAT.SmoothPlastic)
  local mg = add("MouthGlow", V3(0.4 * u, 0.4 * u, 0.4 * u), CF(U(V3(0, 0.5, 0.75))), GLOW, MAT.Neon, true, 0.35)
  mg.Shape = PT_BALL
  local ml = Instance.new("PointLight"); ml.Name = "MouthLight"; ml.Color = GLOW; ml.Range = 8; ml.Brightness = 1.2; ml.Parent = mg
  -- глазницы
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
  -- крылья
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
    -- гравировка
    bar("Engrave", top(0.15, 0, 0.01), top(0.85, 0, 0.01), 0.06, 0.02, ENG, MAT.SmoothPlastic)
    for _, sd in ipairs({ -1, 1 }) do
      bar("Engrave", top(0.25, sd * 0.5, 0.01), top(0.8, sd * 0.5, 0.01), 0.05, 0.02, ENG, MAT.SmoothPlastic)
    end
    for _, t in ipairs({ 0.4, 0.6, 0.8 }) do
      bar("Engrave", top(t, -0.45, 0.01), top(t, 0.45, 0.01), 0.05, 0.02, ENG, MAT.SmoothPlastic)
    end
    -- рёбра жёсткости
    for _, t in ipairs({ 0.3, 0.5, 0.7 }) do
      bar("Rib", top(t, -0.8, 0.04), top(t, 0.8, 0.04), 0.09, 0.08, RIB, MAT.Metal)
    end
    for _, sd in ipairs({ -1, 1 }) do
      bar("Rib", top(0.15, sd * 0.8, 0.04), top(0.9, sd * 0.8, 0.04), 0.1, 0.08, RIB, MAT.Metal)
    end
    -- аура
    local aura = add("Aura", V3(2.6 * u, 2.6 * u, 2.6 * u), CF(U(V3(0, 2.4, 2.9))), GLOW, MAT.Neon, true, 0.92)
    aura.Shape = PT_BALL
    local ad = V3(0, 0.6549, 0.7556)
    for _, r in ipairs({ { V3(0, 2.2, 2.7), 2.5, 0.8 }, { V3(0, 2.7, 3.2), 1.9, 0.75 } }) do
      local pos = U(r[1])
      local ar = add("AuraRing", V3(0.05 * u, r[2] * u, r[2] * u), CFrame.lookAt(pos, pos + ad) * CFrame.Angles(0, math.rad(90), 0), GLOW, MAT.Neon, true, r[3])
      ar.Shape = PT_CYL
    end
  end

  -- Charge / Beam
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
  local pr = ORBIT.SHAPE_PRESETS
  if type(pr) ~= "table" then return false end
  local nm = "ГАСТЕР БЛАСТЕР"
  local create = function(size, name) return createGaster(size, name) end
  for _, p in ipairs(pr) do
    if p.name == nm then p.create = create; p.isModel = true; G.shapeRegistered = true; return true end
  end
  pr[#pr + 1] = { name = nm, isModel = true, create = create, visualSize = 3.4 }
  G.shapeRegistered = true
  return true
end
G.create = createGaster
-- ============================================================
--       Мир: осколки + ловушки
-- ============================================================
local function rayParams()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  local ex = { fold() }
  if LP.Character then ex[#ex + 1] = LP.Character end
  rp.FilterDescendantsInstances = ex
  return rp
end

local function clearShards()
  for _, s in pairs(G.parts) do if s.part then pcall(function() s.part:Destroy() end) end end
  G.parts = {}
  for _, t in pairs(G.traps) do if t.part then pcall(function() t.part:Destroy() end) end end
  G.traps = {}
end

local function makeShard(def, pos)
  local p = Instance.new("Part")
  p.Name = "GasterShard_" .. def.id; p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CastShadow = false
  p.Shape = def.shape; p.Size = V3(def.sz, def.sz, def.sz); p.Material = MAT.Neon; p.Color = def.col
  p.CFrame = CF(pos); p:SetAttribute("NoRecolor", true); p.Parent = fold()
  local l = Instance.new("PointLight"); l.Color = def.col; l.Range = 14; l.Brightness = 2; l.Parent = p
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(def.col); e.LightEmission = 1; e.Size = NumberSequence.new(0.5, 0)
  e.Lifetime = NumberRange.new(0.6, 1.2); e.Speed = NumberRange.new(2, 5); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 30; e.Parent = p
  local b = Instance.new("BillboardGui")
  b.Size = UDim2.new(0, 120, 0, 20); b.StudsOffset = V3(0, def.sz + 1, 0); b.AlwaysOnTop = true; b.Parent = p
  local t = Instance.new("TextLabel")
  t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = def.nm; t.TextColor3 = C3(255, 255, 255)
  t.TextStrokeTransparency = 0; t.Font = Enum.Font.Code; t.TextScaled = true; t.Parent = b
  local cd = Instance.new("ClickDetector"); cd.MaxActivationDistance = 300; cd.Parent = p
  cd.MouseClick:Connect(function() G.collectPart(def.id) end)
  return p
end

local function makeTrap(pos, r)
  local p = Instance.new("Part")
  p.Name = "GasterTrap"; p.Anchored = true; p.CanCollide = false; p.CanTouch = true; p.CastShadow = false
  p.Shape = PT_BALL; p.Size = V3(r, r, r); p.Material = MAT.Neon; p.Color = COL_TRAP
  p.Transparency = 0.35; p.CFrame = CF(pos); p:SetAttribute("NoRecolor", true); p.Parent = fold()
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
      for _, q in ipairs(placed) do if (q - pos).Magnitude < 7 then ok = false; break end end
      if ok then break end
    end
    placed[#placed + 1] = pos
    G.parts[def.id] = {
      def = def, part = makeShard(def, pos), base = pos,
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
      baseY = pos.y or pos.Y, bobPhase = math.random() * 6,
      hitCooldown = 0,
    }
  end
  return true
end

-- ============================================================
--       UI
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
end

local function buildUI()
  closeUI()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
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
  local title = lbl(10, 6, w - 20, 24, "👁 СОБЕРИ ГАСТЕРА (16 осколков)", 15, C3(220, 220, 255))
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
  u.hint = lbl(x0, 82, cw, 44, "Осколки плавают. Ловушки (фиолетовые) — минус осколок! Собирай ВСЕ 16 — потом босс.", 10, C3(170, 160, 200))
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
    if ORBIT.notify then
      ORBIT.notify("👁 UI скрыт, но игра идёт. Вернуть: кнопка «Собери Гастера» в меню", C3(200, 220, 255), 3)
    end
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

function G.close()
  G.hideUI()
end

-- ============================================================
--       БОСС-UI
-- ============================================================
local function showBossUI()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old = pg:FindFirstChild("_OrbitGasterBoss")
  if old then old:Destroy() end
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
  hpTxt.Text = "500 / 500"; hpTxt.TextColor3 = C3(255, 255, 255)
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
  end
end

local function hideBossUI()
  if G.bossUI and G.bossUI.sg then pcall(function() G.bossUI.sg:Destroy() end) end
  G.bossUI = nil
end

-- ============================================================
--       Игра
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
  if G.ui then toast("Собери все 16 осколков! Осторожно — ловушки!") end
  uiRefresh()
  if ORBIT.notify then ORBIT.notify("👁 Игра началась! 16 осколков + ловушки", C3(200, 220, 255), 3) end
  return true
end

function G.reset()
  clearShards()
  G.state = "idle"; G.timer = 120; G.collected = 0
  hideBossUI()
  G.boss = nil
  if G.ui then toast("Сброшено. Нажми СТАРТ.") end
  uiRefresh()
  if ORBIT.notify then ORBIT.notify("↺ Игра сброшена", C3(255, 200, 120), 2) end
end

local function fail(reason)
  clearShards()
  G.state = "idle"
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
  if s.part then pcall(function() s.part:Destroy() end); s.part = nil end
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
  if not alive or G.state ~= "collecting" or not s or s.got or s.flying or not s.part then return false end
  local c, h, root = getChar()
  if not root then return false end
  local d = (root.Position - s.part.Position).Magnitude
  if d > 12 then
    s.flying = true
    local tt = math.clamp(d / 70, 0.2, 1.2)
    local tw = TS:Create(s.part, TweenInfo.new(tt, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CF(root.Position) })
    tw.Completed:Connect(function() if alive and G.parts[id] == s then finalize(id) end end)
    tw:Play()
    return true
  end
  finalize(id)
  return true
end

local function trapHit(trap)
  if not trap or trap.hitCooldown > tick() then return end
  trap.hitCooldown = tick() + 2
  local lost = nil
  for id, s in pairs(G.parts) do
    if s.got then s.got = false; lost = id; break end
  end
  ping("click", 1, 0.5)
  if G.ui then toast("⚠️ ЛОВУШКА! −1 осколок") end
  if ORBIT.notify then ORBIT.notify("⚠️ Ловушка! Осколок потерян", C3(255, 100, 100), 2) end
  uiRefresh()
  local bp = Instance.new("Part")
  bp.Anchored = true; bp.CanCollide = false; bp.Transparency = 1; bp.Size = V3(0.2, 0.2, 0.2)
  bp.Position = trap.part.Position; bp.Parent = fold()
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
function G.startBoss()
  if not alive then return end
  G.state = "boss"
  local c, h, root = getChar()
  if root then
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "OrbitGasterBossCC"; cc.Parent = Lighting
    G.cc = cc
    TS:Create(cc, TweenInfo.new(1.5), { Brightness = -0.15, Saturation = -0.3, TintColor = C3(230, 230, 255) }):Play()
    ping("laugh", 1, 0.8)
  end
  local data = createGaster(4.5, "GasterBoss")
  data.model.Parent = fold()
  local center = root and root.Position or V3(0, 10, 0)
  local bp = center + V3(0, 6, -20)
  pcall(function() data.model:PivotTo(CFrame.lookAt(bp, center)) end)
  G.boss = {
    data = data,
    hp = 500, maxHp = 500,
    phase = 1,
    angle = 0,
    riseT = 0,
    nextShot = tick() + 3,
    shotCharging = false,
    chargeStart = 0,
    chargeTarget = nil,
    fire = nil,
    basePos = bp,
    timeStart = tick(),
  }
  showBossUI()
  updateBossUI()
  if G.ui then toast("ГАСТЕР ПРОБУДИЛСЯ! Бей своими стихиями!") end
  if ORBIT.notify then
    ORBIT.notify("👁 ГАСТЕР ПРОБУДИЛСЯ!", C3(255, 100, 200), 4)
    ORBIT.notify("⚔️ Применяй свои способности — наноси урон!", C3(255, 200, 120), 5)
  end
  task.spawn(function()
    local ab = ORBIT.abilities
    if not ab then return end
    if ab._gasterHook then return end
    ab._gasterHook = true
    G._origFireId = ab.fireId
    local origFire = ab.fireId
    ab.fireId = function(id, ch)
      local r = origFire(id, ch)
      if r and G.boss and G.state == "boss" then
        G.damageBoss(25)
      end
      return r
    end
  end)
end

function G.damageBoss(n)
  if not G.boss then return end
  G.boss.hp = math.max(0, G.boss.hp - (n or 25))
  updateBossUI()
  if G.boss.data and G.boss.data.model then
    local m = G.boss.data.model
    local pos = m:GetPivot().Position
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.Shape = PT_BALL
    p.Size = V3(1.5, 1.5, 1.5); p.Material = MAT.Neon; p.Color = C3(255, 100, 200)
    p.Transparency = 0.3; p.CFrame = CF(pos); p.Parent = fold()
    TS:Create(p, TweenInfo.new(0.3), { Size = V3(6, 6, 6), Transparency = 1 }):Play()
    Debris:AddItem(p, 0.4)
  end
  if G.boss.hp <= 0 then
    G.winBoss()
  end
end

function G.winBoss()
  if not G.boss then return end
  local b = G.boss
  G.boss = nil
  G.state = "won"
  hideBossUI()
  if b.data and b.data.model then
    local pos = b.data.model:GetPivot().Position
    for i = 1, 8 do
      task.delay(i * 0.1, function()
        if not alive then return end
        local p = Instance.new("Part")
        p.Anchored = true; p.CanCollide = false; p.Shape = PT_BALL
        p.Size = V3(2, 2, 2); p.Material = MAT.Neon; p.Color = COL_BEAM
        p.Transparency = 0.2
        p.CFrame = CF(pos + V3(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8)))
        p.Parent = fold()
        TS:Create(p, TweenInfo.new(0.6), { Size = V3(15, 15, 15), Transparency = 1 }):Play()
        Debris:AddItem(p, 0.7)
        ping("ping", 1, 0.6 + i * 0.1)
      end)
    end
    task.delay(1, function()
      if b.data and b.data.model then pcall(function() b.data.model:Destroy() end) end
    end)
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
  if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
  if ORBIT.COINS then
    ORBIT.COINS = (ORBIT.COINS or 0) + 500
    if ORBIT.saveStorage then pcall(ORBIT.saveStorage) end
    if ORBIT.notify then ORBIT.notify("💰 +500 монет за победу!", C3(255, 220, 100), 4) end
  end
  if G.ui then toast("✅ ГАСТЕР ПОВЕРЖЕН! Оружие доступно.") end
  if ORBIT.notify then
    ORBIT.notify("🏆 ГАСТЕР ПОВЕРЖЕН!", C3(180, 255, 180), 5)
    ORBIT.notify("⚔️ Гастер-оружие открыто (кнопка в меню)", C3(200, 220, 255), 5)
  end
  if not G.figure then task.delay(2, function() if alive then G.assemble(true) end end) end
  uiRefresh()
end

-- ============================================================
--       Фигура после победы
-- ============================================================
function G.removeFigure()
  token = token + 1
  if G.figure then
    pcall(function() G.figure.data.model:Destroy() end)
    G.figure = nil
  end
end

local function buildFigure()
  local data = createGaster(3, "GasterOrbit")
  data.model.Parent = fold()
  local f = { data = data, angle = 0, riseT = 0, nextShot = tick() + 5, fire = nil }
  f.charge = data.model:FindFirstChild("Charge")
  f.light = f.charge and f.charge:FindFirstChild("GLight")
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
          local p = Instance.new("Part")
          p.Anchored = true; p.CanCollide = false; p.Transparency = 1; p.Size = V3(0.2, 0.2, 0.2)
          p.Position = o + V3(0, 40, 0); p.Parent = fold()
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
    if root and not quick then
      local c3, h3, r3 = getChar()
      local text = "Теперь ты знаешь, что такое настоящая сила."
      if r3 and ORBIT.sans and ORBIT.sans.showAt then
        pcall(ORBIT.sans.showAt, r3.Position + V3(0, 6, 0), text, 5)
      end
      ping("sans", 1, 1)
    end
    uiRefresh()
  end)
  return true
end

-- ============================================================
--       Главный цикл
-- ============================================================
local function shootBeam(f, fr)
  local from = f.charge and f.charge.Position or f.data.model:GetPivot().Position
  local to = fr.tpos
  local diff = to - from
  if diff.Magnitude > 0.5 then
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Material = MAT.Neon
    p.Color = COL_BEAM; p.Transparency = 0.1; p.Size = V3(2.2, 2.2, diff.Magnitude)
    p.CFrame = CFrame.lookAt((from + to) / 2, to); p.Parent = fold()
    TS:Create(p, TweenInfo.new(0.35), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.5)
  end
  local bp = Instance.new("Part")
  bp.Anchored = true; bp.CanCollide = false; bp.Transparency = 1; bp.Size = V3(0.2, 0.2, 0.2)
  bp.Position = to; bp.Parent = fold()
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(COL_GLOW); e.LightEmission = 1
  e.Size = NumberSequence.new(1.5, 0); e.Lifetime = NumberRange.new(0.5, 1)
  e.Speed = NumberRange.new(15, 25); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0
  e.Parent = bp
  e:Emit(30)
  Debris:AddItem(bp, 1.5)
  local c, h = getChar()
  if c and h and h.Health > 0 then
    local r = c:FindFirstChild("HumanoidRootPart")
    if r and (r.Position - to).Magnitude < 6 then
      pcall(function() h:TakeDamage(15) end)
    end
  end
  ping("snap", 1, 0.5)
end

local function showWarningLine(from, to)
  local diff = to - from
  if diff.Magnitude < 0.5 then return end
  local p = Instance.new("Part")
  p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Material = MAT.Neon
  p.Color = C3(255, 60, 60); p.Transparency = 0.5
  p.Size = V3(0.4, 0.4, diff.Magnitude)
  p.CFrame = CFrame.lookAt((from + to) / 2, to); p.Parent = fold()
  TS:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Linear), { Transparency = 0.1 }):Play()
  Debris:AddItem(p, 0.5)
end

local function stepBoss(dt, t)
  local b = G.boss
  if not b then return end
  local m = b.data.model
  if not m.Parent then G.boss = nil; return end
  local c, h, root = getChar()
  b.angle = b.angle + dt * 0.8
  b.riseT = math.min(1.5, b.riseT + dt)
  local k = b.riseT / 1.5
  k = 1 - (1 - k) * (1 - k)
  local center = root and root.Position or b.lastCenter or V3()
  b.lastCenter = center
  local ca, sa = math.cos(b.angle), math.sin(b.angle)
  local radius = 18
  local pos = center + V3(ca * radius, 8 + math.sin(t * 1.5) * 1 - 12 * (1 - k), sa * radius)
  local look = center
  if b.fire then look = b.fire.tpos end
  pcall(function() m:PivotTo(CFrame.lookAt(pos, look)) end)

  if k < 1 then return end

  local phase = b.hp > b.maxHp * 0.66 and 1 or (b.hp > b.maxHp * 0.33 and 2 or 3)
  local shotCooldown = phase == 1 and 3 or (phase == 2 and 2.2 or 1.6)
  local beamsPerShot = phase == 1 and 1 or (phase == 2 and 2 or 3)

  if not b.shotCharging and t >= b.nextShot then
    b.shotCharging = true
    b.chargeStart = t
    b.chargeTarget = center
    b.beamsPerShot = beamsPerShot
    if root then
      for i = 1, beamsPerShot do
        task.delay((i - 1) * 0.12, function()
          if not alive or not G.boss then return end
          local spread = (i - (beamsPerShot + 1) / 2) * 3
          local predictedPos = root.Position + V3(spread, 2, 0)
          showWarningLine(b.charge and b.charge.Position or m:GetPivot().Position, predictedPos)
        end)
      end
    end
  end

  if b.shotCharging then
    local el = t - b.chargeStart
    if b.light then b.light.Brightness = 1.5 + 6 * math.min(1, el / 0.5) end
    if el >= 0.5 and not b.shotFired then
      b.shotFired = true
      local c2, h2, r2 = getChar()
      for i = 1, b.beamsPerShot do
        local spread = (i - (b.beamsPerShot + 1) / 2) * 3
        local from = b.charge and b.charge.Position or m:GetPivot().Position
        local target = r2 and (r2.Position + V3(spread, 2, 0)) or (from + V3(0, 0, -50))
        shootBeam(b, { tpos = target })
      end
    end
    if el >= 0.8 then
      b.shotCharging = false
      b.shotFired = false
      b.nextShot = t + shotCooldown
    end
  else
    if b.light then b.light.Brightness = 1.5 + 0.5 * math.sin(t * 3) end
  end
end

local function stepShards(dt, t)
  if G.state ~= "collecting" then return end
  for id, s in pairs(G.parts) do
    if not s.got and s.part and s.part.Parent and not s.flying then
      local ang = t * s.speed + s.phase
      local offset = V3(math.cos(ang) * s.radius, math.sin(t * 2 + s.phase) * 0.8, math.sin(ang) * s.radius)
      s.part.CFrame = CF(s.base + offset) * CFrame.Angles(0, t * 1.5 + s.phase, 0)
    end
  end
end

local function stepTraps(dt, t)
  if G.state ~= "collecting" then return end
  local c, h, root = getChar()
  if not root then return end
  for i, tr in ipairs(G.traps) do
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
        if not s.got and s.part and s.part.Parent and not s.flying then
          if (root.Position - s.part.Position).Magnitude < 5 then G.collectPart(id) end
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
      local pos = center + V3(ca * 8, 4 + math.sin(t * 1.5) * 0.5 - 12 * (1 - kk), sa * 8)
      local look = pos + V3(ca, 0, sa)
      pcall(function() m:PivotTo(CFrame.lookAt(pos, look)) end)
      if kk >= 1 then
        if t >= f.nextShot then
          f.nextShot = t + math.random(4, 7)
          local enemies = {}
          for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
              local h2 = pl.Character:FindFirstChildOfClass("Humanoid")
              local r2 = pl.Character:FindFirstChild("HumanoidRootPart")
              if h2 and r2 and h2.Health > 0 and (r2.Position - center).Magnitude <= 80 then
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
          if el >= 0.5 and not f.fire.shot then f.fire.shot = true; shootBeam(f, f.fire) end
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
    if G.ui then
      G.showUI()
    else
      buildUI()
    end
    return true
  end
  buildUI()
  return true
end

-- v24.2-fix1: восстанавливаем ab.fireId, если он был обёрнут
function G.destroy()
  if not alive then return end
  alive = false
  if G.heartbeat then pcall(function() G.heartbeat:Disconnect() end); G.heartbeat = nil end
  clearShards()
  hideBossUI()
  closeUI()
  G.removeFigure()
  G.state = "idle"
  if G.weapon and G.weapon.destroy then pcall(G.weapon.destroy) end
  if G.cc then pcall(function() G.cc:Destroy() end); G.cc = nil end
  if folder then pcall(function() folder:Destroy() end); folder = nil end
  local ab = ORBIT.abilities
  if ab and ab._gasterHook then
    if G._origFireId and ab.fireId ~= G._origFireId then
      pcall(function() ab.fireId = G._origFireId end)
    end
    ab._gasterHook = nil
    G._origFireId = nil
  end
end

-- ============================================================
--       Оружие (белое)
-- ============================================================
local W = { equipped = false, models = {}, proj = {}, cdUntil = 0, conns = {}, side = 1 }
local wFolder, wGui, wBtn = nil, nil, nil
local function wFold()
  if wFolder and wFolder.Parent then return wFolder end
  wFolder = Instance.new("Folder"); wFolder.Name = "OrbitAtmo_GasterWeapon_" .. LP.UserId; wFolder.Parent = WS
  return wFolder
end
local function wNotify(text) if ORBIT.notify then pcall(ORBIT.notify, text, C3(220, 220, 255), 3) end end
local function getHands(char)
  local hum = char:FindFirstChildOfClass("Humanoid")
  local r15 = hum ~= nil and hum.RigType == Enum.HumanoidRigType.R15
  if r15 then
    return char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm"), char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm"), true
  end
  return char:FindFirstChild("Left Arm"), char:FindFirstChild("Right Arm"), false
end
local function handCF(hand, r15)
  if r15 then return hand.CFrame * CF(0, 0, -1.2) end
  return hand.CFrame * CF(0, -1, -1.2)
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
  local b = Instance.new("Part")
  b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false; b.Shape = PT_BALL
  b.Material = MAT.Neon; b.Color = COL_BEAM; b.Transparency = 0.25; b.Size = V3(1, 1, 1)
  b.CFrame = CF(pos); b.Parent = wFold()
  TS:Create(b, TweenInfo.new(0.35), { Size = V3(12, 12, 12), Transparency = 1 }):Play()
  Debris:AddItem(b, 0.5)
  local sp = Instance.new("Part")
  sp.Anchored = true; sp.CanCollide = false; sp.Transparency = 1; sp.Size = V3(0.2, 0.2, 0.2)
  sp.Position = pos; sp.Parent = wFold()
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
  W.cdUntil = t + 0.8
  W.side = -W.side
  local m = W.models[W.side == 1 and "R" or "L"] or W.models.R or W.models.L
  local charge = m and m:FindFirstChild("Charge")
  local origin = charge and charge.Position or (c.PrimaryPart and c.PrimaryPart.Position) or V3()
  local dir = wAim(origin) - origin
  if dir.Magnitude < 0.5 then dir = (c.PrimaryPart and c.PrimaryPart.CFrame.LookVector) or V3(0, 0, -1) end
  dir = dir.Unit
  local p = Instance.new("Part")
  p.Name = "GasterShot"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
  p.Shape = PT_BALL; p.Size = V3(1.4, 1.4, 1.4); p.Material = MAT.Neon
  p.Color = COL_BEAM
  p.CFrame = CF(origin); p:SetAttribute("NoRecolor", true); p.Parent = wFold()
  local l = Instance.new("PointLight"); l.Color = COL_GLOW; l.Range = 12; l.Brightness = 3; l.Parent = p
  W.proj[#W.proj + 1] = { part = p, vel = dir * 140, born = t }
  ping("ping", 1, 0.6)
  return true
end
local function wShowBtn(on)
  if not UIS_W.TouchEnabled then return end
  if on and not wGui then
    local pg = LP:FindFirstChildOfClass("PlayerGui")
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
  end
end
function W.equip()
  if not alive then return false end
  if W.equipped then return true end
  if not (ORBIT.gasterUnlocked or ORBIT.gasterWeaponUnlocked) then
    wNotify("🔒 Сначала пройди «Собери Гастера» и победи босса"); return false
  end
  local c, h = getChar()
  if not c or h.Health <= 0 then return false end
  for _, k in ipairs({ "L", "R" }) do
    local data = createGaster(0.55, "GasterHand" .. k)
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
  wNotify("👁 Гастеры в руках: G — выстрел, H — снять")
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
  if wFolder then pcall(function() wFolder:Destroy() end); wFolder = nil end
end
G.weapon = W

-- ============================================================
--       Экспорт
-- ============================================================
ORBIT.gaster = G
if ORBIT.gasterUnlocked == nil then ORBIT.gasterUnlocked = false end
G.registerShape()
ORBIT.loaded.gaster = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(G.destroy)
  if prevUnload then pcall(prevUnload) end
end

RS.Heartbeat:Connect(function(dt) if alive then W.update(dt) end end)

if ORBIT.notify then
  ORBIT.notify("👁 Гастер v24.2-fix2 (16 осколков + босс + новый череп)", C3(220, 200, 255), 3)
end

return true
