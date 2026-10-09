-- ORBIT v24.0 | orbit_new_figures.lua
-- Новые фигуры: КОРОНА, ФЕНИКС, ПОРТАЛ (регистрация в ORBIT.SHAPE_PRESETS через #+1)
-- Имена деталей совпадают с контрактом orbit_animations.lua (Feather<слой>_*, Flame<слой>, Disk*, Rim*)
local G = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = G.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] newfigures: нет ORBIT"); return false end
ORBIT.loaded = ORBIT.loaded or {}
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local MAT = Enum.Material
local function shell(name)
  if ORBIT.newModelShell then return ORBIT.newModelShell(name) end
  local m = Instance.new("Model"); m.Name = name
  local r = Instance.new("Part")
  r.Name = "Root"; r.Size = V3(0.1, 0.1, 0.1); r.Transparency = 1; r.Anchored = true; r.CanCollide = false; r.Parent = m
  m.PrimaryPart = r
  return m, r
end
local function mk(model, bodies, name, size, cf, col, mat, nr, tr)
  local p
  if ORBIT.newPart then p = ORBIT.newPart(model, name, size, cf, col, nr) end
  if not p then
    p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true
    p.CanCollide = false; p.CastShadow = false; p.Color = col; p.Parent = model
    if nr then p:SetAttribute("NoRecolor", true) end
  end
  p.Material = mat or MAT.Metal; p.Transparency = tr or 0; p.CanQuery = false; p.CanTouch = false
  table.insert(bodies, p)
  return p
end
local function emitter(parent, col, rate, size, speed)
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(col); e.LightEmission = 1; e.Size = NumberSequence.new(size, 0)
  e.Lifetime = NumberRange.new(0.5, 1); e.Speed = NumberRange.new(speed * 0.5, speed)
  e.SpreadAngle = Vector2.new(180, 180); e.Rate = rate; e.Parent = parent
  return e
end
-- ===== КОРОНА: золото (Metal), 5 зубцов, рубины NoRecolor =====
local function createCrown(s, color, name)
  local model, root = shell(name)
  local bodies = {}
  local R, ruby = 0.6 * s, C3(220, 30, 60)
  for i = 1, 8 do -- обод: 8 сегментов
    local a = (i - 1) / 8 * math.pi * 2
    local pos = V3(math.cos(a) * R, 0, math.sin(a) * R)
    local face = CFrame.lookAt(pos, pos + V3(math.cos(a), 0, math.sin(a)))
    mk(model, bodies, "Band", V3(0.5 * s, 0.28 * s, 0.1 * s), face, color, MAT.Metal)
    mk(model, bodies, "Rim", V3(0.5 * s, 0.05 * s, 0.14 * s), face * CF(0, 0.16 * s, 0), color, MAT.Metal)
  end
  for i = 1, 5 do -- 5 зубцов
    local a = (i - 1) / 5 * math.pi * 2
    local c, sn = math.cos(a), math.sin(a)
    local base = V3(c * R, 0.3 * s, sn * R)
    local face = CFrame.lookAt(base, base + V3(c, 0, sn))
    mk(model, bodies, "Spike", V3(0.2 * s, 0.4 * s, 0.1 * s), face, color, MAT.Metal)
    mk(model, bodies, "SpikeTip", V3(0.12 * s, 0.22 * s, 0.08 * s), face * CF(0, 0.3 * s, 0), color, MAT.Metal)
    local ball = mk(model, bodies, "Pearl", V3(0.12 * s, 0.12 * s, 0.12 * s), CF(c * R, 0.62 * s, sn * R), color, MAT.Metal)
    ball.Shape = Enum.PartType.Ball
    local gp = V3(c * (R + 0.07 * s), -0.02 * s, sn * (R + 0.07 * s))
    mk(model, bodies, "Ruby", V3(0.14 * s, 0.14 * s, 0.07 * s), CFrame.lookAt(gp, gp + V3(c, 0, sn)), ruby, MAT.Neon, true)
  end
  local gp = V3(0, -0.02 * s, -(R + 0.09 * s)) -- главный рубин спереди
  mk(model, bodies, "Ruby", V3(0.2 * s, 0.2 * s, 0.09 * s), CF(gp), ruby, MAT.Neon, true)
  return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = s * 1.8 }
end
-- ===== ФЕНИКС: Neon, крылья в 3 слоя, хвост-пламя (всё NoRecolor) =====
local function createPhoenix(s, color, name)
  local model, root = shell(name)
  local bodies = {}
  local body = mk(model, bodies, "Body", V3(0.6 * s, 0.6 * s, 0.6 * s), CF(), C3(255, 140, 30), MAT.Neon, true)
  body.Shape = Enum.PartType.Ball
  local head = mk(model, bodies, "Head", V3(0.35 * s, 0.35 * s, 0.35 * s), CF(0, 0.45 * s, -0.4 * s), C3(255, 170, 40), MAT.Neon, true)
  head.Shape = Enum.PartType.Ball
  mk(model, bodies, "Beak", V3(0.1 * s, 0.1 * s, 0.25 * s), CF(0, 0.42 * s, -0.68 * s), C3(255, 230, 90), MAT.Neon, true)
  for _, sd in ipairs({ -1, 1 }) do
    mk(model, bodies, "Eye", V3(0.06 * s, 0.06 * s, 0.06 * s), CF(sd * 0.13 * s, 0.5 * s, -0.55 * s), C3(20, 10, 10), MAT.SmoothPlastic, true)
  end
  for i = -1, 1 do
    mk(model, bodies, "Crest", V3(0.06 * s, 0.22 * s, 0.06 * s), CF(i * 0.08 * s, 0.7 * s, -0.35 * s) * CFrame.Angles(math.rad(-20), 0, math.rad(-i * 15)), C3(255, 90, 20), MAT.Neon, true)
  end
  local layerCol = { C3(255, 175, 40), C3(255, 115, 20), C3(255, 60, 10) }
  for _, sd in ipairs({ -1, 1 }) do -- крылья: 3 слоя × 3 пера
    for k = 1, 3 do
      for j = 1, 3 do
        local len = (0.95 - (k - 1) * 0.15) * s
        local yaw = (j - 2) * math.rad(18)
        local base = V3(sd * 0.3 * s, 0.15 * s - (k - 1) * 0.1 * s, (j - 2) * 0.12 * s)
        local dir = CFrame.Angles(0, -yaw * sd, 0):VectorToWorldSpace(V3(sd, 0, 0))
        local cf = CFrame.lookAt(base + dir * len / 2, base + dir * len) * CFrame.Angles(0, 0, 0)
        mk(model, bodies, "Feather" .. k .. "_" .. (sd == 1 and "R" or "L") .. j, V3(0.2 * s, 0.06 * s, len), cf, layerCol[k], MAT.Neon, true)
      end
    end
  end
  for k = 1, 3 do -- хвост-пламя: 3 слоя
    local f = mk(model, bodies, "Flame" .. k, V3((0.3 - 0.06 * k) * s, 0.12 * s, 0.7 * s),
      CF(0, -0.1 * s - k * 0.05 * s, (0.5 + (k - 1) * 0.55) * s) * CFrame.Angles(math.rad(8 * k), 0, 0),
      layerCol[k], MAT.Neon, true)
    emitter(f, layerCol[k], 18, 0.4 * s, 3)
  end
  local l = Instance.new("PointLight"); l.Color = C3(255, 140, 40); l.Range = 14; l.Brightness = 2; l.Parent = body
  return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = s * 2.4 }
end
-- ===== ПОРТАЛ: Neon-кольцо (цвет кольца меняется), Glass-диск NoRecolor, искры =====
local function createPortal(s, color, name)
  local model, root = shell(name)
  local bodies = {}
  local R, N = 0.9 * s, 16
  local len = 2 * math.pi * R / N * 1.1
  for i = 1, N do
    local a = (i - 1) / N * math.pi * 2
    local rim = mk(model, bodies, "Rim", V3(len, 0.2 * s, 0.2 * s),
      CF(math.cos(a) * R, math.sin(a) * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2), C3(170, 60, 255), MAT.Neon)
    if i % 4 == 1 then emitter(rim, C3(200, 120, 255), 12, 0.3 * s, 3) end
  end
  local disk = mk(model, bodies, "Disk", V3(0.1 * s, 1.7 * s, 1.7 * s), CFrame.Angles(0, math.pi / 2, 0), C3(120, 40, 200), MAT.Glass, true, 0.35)
  disk.Shape = Enum.PartType.Cylinder
  for i = 1, 4 do -- «спицы» диска: видно вращение
    local a = (i - 1) / 4 * math.pi * 2
    mk(model, bodies, "DiskArm" .. i, V3(0.8 * s, 0.08 * s, 0.04 * s),
      CF(math.cos(a) * 0.4 * s, math.sin(a) * 0.4 * s, 0) * CFrame.Angles(0, 0, a), C3(220, 160, 255), MAT.Neon, true)
  end
  local l = Instance.new("PointLight"); l.Color = C3(170, 90, 255); l.Range = 12; l.Brightness = 1.5; l.Parent = disk
  return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = s * 2.0 }
end
local FIGS = {
  { name = "КОРОНА", create = function(s, n) return createCrown(s, C3(255, 205, 60), n) end },
  { name = "ФЕНИКС", create = function(s, n) return createPhoenix(s, C3(255, 140, 30), n) end },
  { name = "ПОРТАЛ", create = function(s, n) return createPortal(s, C3(170, 60, 255), n) end },
}
local function register()
  local pr = ORBIT.SHAPE_PRESETS
  if type(pr) ~= "table" then return false end
  for _, f in ipairs(FIGS) do
    local exists = false
    for _, p in ipairs(pr) do if p.name == f.name then exists = true; break end end
    if not exists then pr[#pr + 1] = { name = f.name, isModel = true, create = f.create } end
  end
  if ORBIT.animations and ORBIT.animations.register then
    pcall(ORBIT.animations.register, "ФЕНИКС", { "flames", "feathers" })
  end
  ORBIT.loaded.newfigures = true
  return true
end
if not register() then
  task.spawn(function() -- p2 ещё не загрузился: ждём до 15 с
    for _ = 1, 30 do
      task.wait(0.5)
      if register() then return end
    end
    warn("[ORBIT] newfigures: SHAPE_PRESETS не появился")
  end)
end
ORBIT.newFigures = { create = { crown = createCrown, phoenix = createPhoenix, portal = createPortal } }
return true
