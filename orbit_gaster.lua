-- ORBIT v25.2-fix5 | orbit_gaster.lua
-- 16 частей тела + ловушки + босс-файт + белое оружие.
-- v25.2-fix5:
--   * Босс — пресет «ГАСТЕР» из p2 (чёрный), scale 5, лицом к игроку, руки ×2.
--   * Оружие в руке — «ГАСТЕР БЛАСТЕР» scale 3.
--   * Награда после победы — бластер-спутник (череп scale 1.5), крутится и стреляет.
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
  walkTarget = nil, nextRetarget = 0, nextDodge = 0,
  nextAttack = 0, attackIndex = 0, walkPhase = 0,
  hitTimes = {}, _legs = nil,
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
  -- v25.2-fix5: не перезаписываем пресеты p2
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
  end
end

local function hideBossUI()
  if G.bossUI and G.bossUI.sg then pcall(function() G.bossUI.sg:Destroy() end) end
  G.bossUI = nil
end

-- ============================================================
--       ХОДЬБА ПО ЗЕМЛЕ
-- ============================================================
local function collectLegs(model)
  local legs = {}
  for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") and (d.Name == "Shoe" or d.Name == "Leg") then
      legs[#legs + 1] = { p = d, baseRel = d.CFrame, side = (d.Position.X > model:GetPivot().Position.X) and 1 or -1 }
    end
  end
  return legs
end

local function playWalkAnim(model, phase, dt)
  if not model or not model.PrimaryPart then return end
  local pivot = model:GetPivot()
  local sway = math.sin(phase * 2) * math.rad(3)
  local bob = math.abs(math.sin(phase)) * 0.12
  pcall(function()
    model:PivotTo(pivot * CFrame.Angles(0, 0, sway) + V3(0, bob, 0))
  end)
  local legPhase = math.sin(phase)
  local legs = G._legs
  if not legs then legs = collectLegs(model); G._legs = legs end
  for _, l in ipairs(legs) do
    if l.p.Parent then
      local zShift = (l.side > 0) and legPhase or -legPhase
      local rel = model.PrimaryPart.CFrame:ToObjectSpace(l.baseRel)
      pcall(function() l.p.CFrame = model.PrimaryPart.CFrame * rel * CF(0, 0, zShift * 0.35) end)
    end
  end
end

local function findWalkTarget(center, bossPos)
  local angle = math.random() * math.pi * 2
  local dist = 8 + math.random() * 4
  local target = center + V3(math.cos(angle) * dist, 0, math.sin(angle) * dist)
  local ground = groundAt(target)
  return V3(ground.X, ground.Y + 3, ground.Z)
end

local function stepBossMovement(dt, t)
  if not G.boss or not G.boss.model then return end
  local c, h, r = getChar()
  if not r then return end
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
      G.walkTarget = V3(dodgeTo.X, dodgeTo.Y + 3, dodgeTo.Z)
      G.nextRetarget = t + 0.8
      ping("dodge", 0.8, 1.4)
    end
  end
  local target = G.walkTarget or bossPos
  local diff = V3(target.X - bossPos.X, 0, target.Z - bossPos.Z)
  local dist = diff.Magnitude
  if dist > 0.8 then
    local speed = 9
    local step = math.min(dist, speed * dt)
    local dir = diff.Unit
    local newPos = bossPos + dir * step
    local groundY = target.Y
    local finalPos = V3(newPos.X, groundY, newPos.Z)
    -- v25.2-fix5: разворот на 180° — фигуры p2 построены лицом к +Z
    pcall(function() G.boss.model:PivotTo(CFrame.lookAt(finalPos, finalPos + dir) * CFrame.Angles(0, math.pi, 0)) end)
    G.walkPhase = G.walkPhase + dt * 9
    playWalkAnim(G.boss.model, G.walkPhase, dt)
  else
    -- стоит: смотрит на игрока
    pcall(function()
      local cur = G.boss.model:GetPivot().Position
      G.boss.model:PivotTo(CFrame.lookAt(cur, playerPos) * CFrame.Angles(0, math.pi, 0))
    end)
    G.walkPhase = G.walkPhase + dt * 2
    local bob = math.sin(G.walkPhase) * 0.08
    pcall(function()
      local pivot = G.boss.model:GetPivot()
      G.boss.model:PivotTo(pivot + V3(0, bob, 0))
    end)
  end
end

-- ============================================================
--       АТАКИ
-- ============================================================
local function shootBeamSimple(from, to)
  local diff = to - from
  if diff.Magnitude < 0.5 then return end
  local p = Instance.new("Part")
  p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
  p.Material = MAT.Neon; p.Color = COL_BEAM; p.Transparency = 0.1
  p.Size = V3(2.2, 2.2, diff.Magnitude)
  p.CFrame = CFrame.lookAt((from + to) / 2, to); p.Parent = fold()
  local core = Instance.new("PointLight"); core.Color = COL_GLOW; core.Range = 20; core.Brightness = 6; core.Parent = p
  TS:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
  TS:Create(core, TweenInfo.new(0.5), { Brightness = 0 }):Play()
  Debris:AddItem(p, 0.6)
  local c, h, r = getChar()
  if r and h and (r.Position - to).Magnitude < 6 then
    pcall(function() h:TakeDamage(15) end)
    G.hitTimes[#G.hitTimes + 1] = tick()
  end
  ping("snap", 1, 0.5)
end

local function attackBlaster(model)
  local c, h, r = getChar()
  if not r then return end
  local from = model:GetPivot().Position + V3(0, 5, 0)
  local to = r.Position
  shootBeamSimple(from, to)
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack") end
end

local function attackHand(model)
  local c, h, r = getChar()
  if not r then return end
  local ab = ORBIT.abilities
  if ab and ab.spawnHand then
    local pos = r.Position + V3((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 4)
    local ground = groundAt(pos)
    pcall(ab.spawnHand, ground, 1.4, r.Position, 30, 5.5, 0.5)
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
    pcall(ab.spawnBones, from, dir, n, 14, 1.5, false)
  end
  ping("snap", 1, 1.4)
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack") end
end

local function attackWords(model)
  local c, h, r = getChar()
  if not r then return end
  local head = r:FindFirstChild("Head")
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
    pcall(function() h:TakeDamage(5) end)
    G.hitTimes[#G.hitTimes + 1] = tick()
  end
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if pg then
    local sg = Instance.new("ScreenGui"); sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.DisplayOrder = 55; sg.Parent = pg
    local f = Instance.new("Frame")
    f.Size = UDim2.fromScale(1, 1)
    f.BackgroundColor3 = C3(120, 30, 180)
    f.BackgroundTransparency = 0.7; f.BorderSizePixel = 0
    f.ZIndex = 1; f.Active = false; f.Parent = sg
    TS:Create(f, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    task.delay(0.5, function() pcall(function() sg:Destroy() end) end)
  end
  ping("snap", 0.6, 1.6)
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
  clearShards()
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
--       БОСС — v25.2-fix5
-- ============================================================
function G.startBoss()
  if not alive then return end
  G.state = "boss"
  G.active = true
  G.walkPhase = 0
  G._legs = nil
  G.walkTarget = nil
  G.nextRetarget = 0
  G.nextDodge = tick() + 3
  G.nextAttack = tick() + 2.5
  G.attackIndex = 0
  G.hitTimes = {}
  clearShards()

  local c, h, root = getChar()
  if not root then return end

  local cc = Instance.new("ColorCorrectionEffect")
  cc.Name = "OrbitGasterBossCC"; cc.Parent = Lighting
  G.cc = cc
  TS:Create(cc, TweenInfo.new(1.5), { Brightness = -0.15, Saturation = -0.3, TintColor = C3(230, 230, 255) }):Play()
  ping("laugh", 1, 0.8)

  -- Босс = пресет «ГАСТЕР» из p2, scale = 5
  local data = nil
  local presets = ORBIT.SHAPE_PRESETS
  if type(presets) == "table" then
    for _, p in ipairs(presets) do
      if p.name == "ГАСТЕР" and type(p.create) == "function" then
        local ok, d = pcall(p.create, 5, "GasterBoss")
        if ok and d and d.model then data = d end
        break
      end
    end
  end
  if not data then
    warn("[OrbitGaster] пресет «ГАСТЕР» не найден, fallback на createGaster")
    data = createGaster(5, "GasterBoss")
  end
  data.model.Parent = fold()

  -- v25.2-fix5: руки босса ×2
  local HAND_PART_NAMES = {
    F1 = true, F2 = true, F3 = true, F4 = true,
    Palm = true, Wrap1 = true, Wrap2 = true, Spike = true,
    Heart = true, P = true, Bevel = true, Shine = true,
    HandL = true, HandR = true, Finger = true, Thumb = true,
    Arm = true, Wrist = true, Elbow = true,
  }
  for _, d in ipairs(data.model:GetDescendants()) do
    if d:IsA("BasePart") and HAND_PART_NAMES[d.Name] then
      pcall(function() d.Size = d.Size * 2 end)
    end
  end

  local spawnPos = root.Position + root.CFrame.LookVector * 20
  local gp = groundAt(spawnPos)
  local finalPos = V3(gp.X, gp.Y + 3, gp.Z)
  -- v25.2-fix5: разворот на 180° — фигуры p2 построены лицом к +Z
  pcall(function() data.model:PivotTo(CFrame.lookAt(finalPos, root.Position) * CFrame.Angles(0, math.pi, 0)) end)

  G.boss = {
    data = data,
    model = data.model,
    root = data.part or data.model.PrimaryPart,
    hp = 650, maxHp = 650,
    phase = 1,
    charge = nil,
    light = nil,
    shotCharging = false,
    shotFired = false,
    chargeStart = 0,
  }
  for _, d in ipairs(data.model:GetDescendants()) do
    if d.Name == "Charge" then
      G.boss.charge = d
      G.boss.light = d:FindFirstChild("GLight")
    end
  end
  G.walkTarget = finalPos
  G._legs = nil

  showBossUI()
  updateBossUI()

  task.spawn(function()
    local ab = ORBIT.abilities
    if not ab or ab._gasterHook then return end
    ab._gasterHook = true
    G._origFireId = ab.fireId
    local origFire = ab.fireId
    ab.fireId = function(id, ch)
      local r = origFire(id, ch)
      if r and G.boss and G.state == "boss" then
        local dmgVal = ch and 45 or 25
        G.boss.hp = math.max(0, G.boss.hp - dmgVal)
        updateBossUI()
        G.hitTimes[#G.hitTimes + 1] = tick()
        if G.boss.hp <= 0 then G.winBoss() end
      end
      return r
    end
  end)

  if G.ui then toast("ГАСТЕР ПРОБУДИЛСЯ! Бей своими стихиями!") end
  if ORBIT.notify then
    ORBIT.notify("👁 ГАСТЕР ПРОБУДИЛСЯ!", C3(255, 100, 200), 4)
    ORBIT.notify("⚔️ Применяй свои способности — наноси урон!", C3(255, 200, 120), 5)
  end
end

function G.damageBoss(n)
  if not G.boss then return end
  G.boss.hp = math.max(0, G.boss.hp - (n or 25))
  updateBossUI()
  if G.boss.hp <= 0 then G.winBoss() end
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

local function stepBoss(dt, t)
  if not G.boss or not G.active then return end
  if G.state ~= "boss" then return end
  local model = G.boss.model
  if not model or not model.Parent then G.boss = nil; return end
  stepBossMovement(dt, t)
  if G.boss.light then
    G.boss.light.Brightness = 1.5 + 0.6 * math.sin(t * 3)
  end
  if t >= G.nextAttack then
    G.attackIndex = (G.attackIndex % 4) + 1
    local interval = G.boss.phase == 1 and 3.5 or (G.boss.phase == 2 and 2.8 or 2.2)
    G.nextAttack = t + interval
    if G.attackIndex == 1 then attackBlaster(model)
    elseif G.attackIndex == 2 then attackBones(model)
    elseif G.attackIndex == 3 then attackHand(model)
    else attackWords(model) end
  end
end

-- ============================================================
--       ПОБЕДА — v25.2-fix5
-- ============================================================
function G.winBoss()
  if not G.boss then return end
  local b = G.boss
  G.boss = nil
  G.state = "won"
  G.active = false
  hideBossUI()

  if b.model then
    local pos = b.model:GetPivot().Position
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
      if b.model then pcall(function() b.model:Destroy() end) end
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
  ORBIT.saveData.rewards = ORBIT.saveData.rewards or {}
  ORBIT.saveData.rewards["gaster_weapon"] = true
  local newRewards = {}
  if not ORBIT.saveData.rewards["gaster_weapon"] then
    ORBIT.saveData.rewards["gaster_weapon"] = true
    newRewards[#newRewards + 1] = "⚔ Гастер-бластер открыт в арсенале"
  end
  if not ORBIT.saveData.rewards["gaster_boss_skin"] then
    ORBIT.saveData.rewards["gaster_boss_skin"] = true
    newRewards[#newRewards + 1] = "🎨 Скин «Гастер-босс» открыт"
  end
  if not ORBIT.saveData.rewards["blue_eye_tick"] then
    ORBIT.saveData.rewards["blue_eye_tick"] = true
    newRewards[#newRewards + 1] = "💧 Синий глаз-тик"
  end
  if not ORBIT.saveData.rewards["gaster_skull_helmet"] then
    ORBIT.saveData.rewards["gaster_skull_helmet"] = true
    newRewards[#newRewards + 1] = "💀 Костяной шлем"
  end
  if not ORBIT.saveData.rewards["gaster_double_blaster"] then
    ORBIT.saveData.rewards["gaster_double_blaster"] = true
    newRewards[#newRewards + 1] = "⚡ Двойной бластер"
  end
  if not ORBIT.saveData.rewards["gaster_portal_fx"] then
    ORBIT.saveData.rewards["gaster_portal_fx"] = true
    newRewards[#newRewards + 1] = "🌀 Тёмный портал"
  end
  if not ORBIT.saveData.rewards["gaster_blue_particles"] then
    ORBIT.saveData.rewards["gaster_blue_particles"] = true
    newRewards[#newRewards + 1] = "💠 Синие частицы"
  end
  if not ORBIT.saveData.rewards["coins_gaster"] then
    ORBIT.saveData.rewards["coins_gaster"] = true
    newRewards[#newRewards + 1] = "💰 +800 монет"
  end
  if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
  ORBIT.COINS = (ORBIT.COINS or 0) + 800
  if ORBIT.saveStorage then pcall(ORBIT.saveStorage) end
  if ORBIT.notify then ORBIT.notify("💰 +800 монет!", C3(255, 220, 100), 4) end
  for i, msg in ipairs(newRewards) do
    if ORBIT.notify then
      task.delay(0.4 + i * 0.6, function()
        ORBIT.notify(msg, C3(200, 220, 255), 4)
      end)
    end
  end
  if G.ui then toast("✅ ГАСТЕР ПОВЕРЖЕН!") end
  if ORBIT.notify then ORBIT.notify("🏆 ГАСТЕР ПОВЕРЖЕН!", C3(180, 255, 180), 5) end
  uiRefresh()
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

  -- ФИГУРА-СПУТНИК (бластер) после победы
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
      -- смотрит по направлению движения
      local look = pos + V3(-sa, 0, ca)
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
          if el >= 0.5 and not f.fire.shot then f.fire.shot = true; shootBeamSimple(f.charge and f.charge.Position or pos, f.fire.tpos) end
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

function G.removeFigure()
  token = token + 1
  if G.figure then
    pcall(function() G.figure.data.model:Destroy() end)
    G.figure = nil
  end
end

-- v25.2-fix5: спутник = БЛАСТЕР (череп), а НЕ Гастер целиком
local function buildFigure()
  local presets = ORBIT.SHAPE_PRESETS
  local data = nil
  if type(presets) == "table" then
    for _, p in ipairs(presets) do
      if p.name == "ГАСТЕР БЛАСТЕР" and type(p.create) == "function" then
        local ok, d = pcall(p.create, 1.5, "GasterBlasterOrbit")
        if ok and d and d.model then data = d end
        break
      end
    end
  end
  if not data then data = createGaster(1.5, "GasterBlasterOrbit") end
  data.model.Parent = fold()
  local f = { data = data, angle = 0, riseT = 0, nextShot = tick() + 5, fire = nil }
  f.charge = data.model:FindFirstChild("Charge", true)
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
    uiRefresh()
  end)
  return true
end
-- ============================================================
--       ОРУЖИЕ (бластер в руке scale = 3)
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
    wNotify("🔒 Сначала пройди «Собери Гастера»"); return false
  end
  local c, h = getChar()
  if not c or h.Health <= 0 then return false end
  -- бластер-оружие в руке: пресет «ГАСТЕР БЛАСТЕР» из p2, scale = 3
  for _, k in ipairs({ "L", "R" }) do
    local data = nil
    local presets = ORBIT.SHAPE_PRESETS
    if type(presets) == "table" then
      for _, p in ipairs(presets) do
        if p.name == "ГАСТЕР БЛАСТЕР" and type(p.create) == "function" then
          local ok, d = pcall(p.create, 3, "GasterHand" .. k)
          if ok and d and d.model then data = d end
          break
        end
      end
    end
    if not data then data = createGaster(3, "GasterHand" .. k) end
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
  wNotify("👁 Гастер-бластеры в руках: G — выстрел, H — снять")
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
  local root = Instance.new("Part"); root.Name = "Root"; root.Size = V3(0.1,0.1,0.1); root.Transparency = 1
  root.Anchored = true; root.CanCollide = false; root.Parent = m; m.PrimaryPart = root
  for i = 1, 3 do
    local ring = Instance.new("Part")
    ring.Name = "Ring" .. i
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = V3(0.15, 3 - i * 0.5, 3 - i * 0.5)
    ring.Anchored = true; ring.CanCollide = false; ring.CastShadow = false
    ring.CanQuery = false; ring.CanTouch = false
    ring.Material = Enum.Material.Neon
    ring.Color = i == 1 and C3(120, 60, 200) or (i == 2 and C3(80, 40, 160) or C3(40, 20, 100))
    ring.Transparency = 0.3 - i * 0.05
    ring.Parent = m
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
  local p = Instance.new("Part")
  p.Anchored = true; p.CanCollide = false; p.CastShadow = false
  p.CanQuery = false; p.CanTouch = false
  p.Shape = Enum.PartType.Ball
  p.Size = V3(0.35, 0.35, 0.35)
  p.Material = Enum.Material.Neon
  p.Color = C3(120, 180, 255)
  p.Transparency = 0.15
  p.CFrame = CF(r.Position + V3(math.random(-0.5, 0.5), -0.5, math.random(-0.5, 0.5)))
  p.Parent = fxFold()
  local l = Instance.new("PointLight"); l.Color = C3(120, 180, 255); l.Range = 5; l.Brightness = 1.5; l.Parent = p
  TS:Create(p, TweenInfo.new(0.5), { Transparency = 1, Size = V3(0.05, 0.05, 0.05) }):Play()
  TS:Create(l, TweenInfo.new(0.5), { Brightness = 0 }):Play()
  Debris:AddItem(p, 0.6)
end

RS.Heartbeat:Connect(function(dt)
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
  if G.heartbeat then pcall(function() G.heartbeat:Disconnect() end); G.heartbeat = nil end
  clearShards()
  hideBossUI()
  closeUI()
  G.removeFigure()
  G.state = "idle"
  if G.weapon and G.weapon.destroy then pcall(G.weapon.destroy) end
  if G.cc then pcall(function() G.cc:Destroy() end); G.cc = nil end
  if folder then pcall(function() folder:Destroy() end); folder = nil end
  if portalModel then pcall(function() portalModel:Destroy() end); portalModel = nil end
  if fxFolder then pcall(function() fxFolder:Destroy() end); fxFolder = nil end
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
--       ЭКСПОРТ
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

if ORBIT.notify then
  ORBIT.notify("👁 Гастер v25.2-fix5 (чёрный босс ×5, спутник-бластер)", C3(220, 200, 255), 3)
end

return true
