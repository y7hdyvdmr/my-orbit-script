-- ORBIT v24.5 | orbit_abilities.lua
-- v24.5: aim НЕ замедляет, "Скорость" снова ускоряет, телепорт в точку прицела (200 studs).
local G = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = G.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] abilities: нет ORBIT"); return false end
if ORBIT.abilities and ORBIT.abilities.destroy then pcall(ORBIT.abilities.destroy) end
ORBIT.loaded = ORBIT.loaded or {}
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local PT_BALL, PT_BLOCK, MAT = Enum.PartType.Ball, Enum.PartType.Block, Enum.Material
local TOUCH = UIS.TouchEnabled
local MOB = TOUCH and not UIS.MouseEnabled
local EL = {
  { id = "fire", nm = "ОГОНЬ", ic = "🔥", col = C3(255, 110, 30) },
  { id = "earth", nm = "ЗЕМЛЯ", ic = "🌍", col = C3(150, 110, 70) },
  { id = "water", nm = "ВОДА", ic = "💧", col = C3(60, 150, 255) },
  { id = "ice", nm = "ЛЁД", ic = "❄️", col = C3(170, 230, 255) },
  { id = "lightning", nm = "МОЛНИЯ", ic = "⚡", col = C3(255, 240, 90) },
  { id = "teleport", nm = "ТЕЛЕПОРТ", ic = "✨", col = C3(190, 120, 255) },
  { id = "speed", nm = "СКОРОСТЬ", ic = "💨", col = C3(120, 255, 190) },
  { id = "wind", nm = "ВЕТЕР", ic = "🌪️", col = C3(225, 240, 255) },
  { id = "poison", nm = "ЯД", ic = "☠️", col = C3(90, 210, 70) },
}
local IDX = {}
for i, e in ipairs(EL) do IDX[e.id] = i end

local hidden = {}

local C = {
  fire = { dmg = 25, speed = 120, r = 4, cd = 1.2, burn = 2 },
  earth = { dmg = 35, g = 50, knock = 15, cd = 1.5, speed = 85 },
  water = { dps = 5, range = 35, cd = 0, push = 8 },
  ice = { dmg = 15, spread = 15, slow = 2, cd = 2, speed = 90 },
  lightning = { dmg = 40, range = 40, stun = 0.5, cd = 2.5 },
  teleport = { maxDist = 200, cd = 3 },  -- ← было 30 studs, стало 200
  speed = { dist = 20, mult = 1.8, dur = 3, cd = 5 },
  wind = { r = 15, knock = 25, cd = 4 },
  poison = { dps = 8, r = 8, dur = 5, cd = 6 },
  combo = { cd = 6, window = 6 },
  charge = { time = 1, dmg = 2, speed = 1.5, size = 1.5 },
}
local A = { current = "fire", cooldowns = {}, projectiles = {}, config = C }
local conns, ui = {}, {}
local folder
local alive = true
local aiming, waterHeld, shiftHeld, centerOnce = false, false, false, false
local waterUntil, waterAcc, pressT, crossPos = 0, 0, nil, nil
local prevId = "ice"
local lastFire = {}
local dots, slows, hitWatch, clouds = {}, {}, {}, {}
local enemyCache, enemyT = {}, 0
local speedUntil, toastUntil = 0, 0
local hitMarkerUntil = 0
local sm = nil
local helperWrapped, origInterp = false, nil
local speedRestoreToken = 0
local function connect(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local function ping(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end
local function fold()
  if folder and folder.Parent then return folder end
  folder = Instance.new("Folder"); folder.Name = "OrbitAbility_" .. LP.UserId; folder.Parent = WS
  return folder
end
local function cam() return WS.CurrentCamera end
local function getChar()
  local c = LP.Character
  if not c then return nil end
  local h = c:FindFirstChildOfClass("Humanoid")
  local r = c:FindFirstChild("HumanoidRootPart")
  if not h or not r or h.Health <= 0 then return nil end
  return c, h, r
end
local function T(o, t, props, style)
  pcall(function() TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end)
end
local function toast(text)
  if ui.toast then ui.toast.Text = text; ui.toast.Visible = true; toastUntil = tick() + 1.5 end
end

-- ===== Утилиты мира =====
local function mkpart(shape, size, col, mat, tr)
  local p
  if ORBIT.newPart then p = ORBIT.newPart(fold(), "Ab", size, CF(), col, true) end
  if not p then
    p = Instance.new("Part"); p.Name = "Ab"; p.Size = size; p.Anchored = true
    p.CanCollide = false; p.CastShadow = false; p.Color = col; p.Parent = fold()
  end
  p.Shape = shape or PT_BLOCK
  p.CanQuery = false; p.CanTouch = false; p.Material = mat or MAT.Neon; p.Transparency = tr or 0
  return p
end
local function glow(p, col, rate)
  local l = Instance.new("PointLight"); l.Color = col; l.Range = 10; l.Brightness = 2; l.Parent = p
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(col); e.LightEmission = 1; e.Size = NumberSequence.new(0.7, 0)
  e.Lifetime = NumberRange.new(0.3, 0.6); e.Speed = NumberRange.new(1, 4)
  e.SpreadAngle = Vector2.new(180, 180); e.Rate = rate or 40; e.Parent = p
end
local function rodp(a, b, th, col)
  if (b - a).Magnitude < 0.05 then return nil end
  local p
  if ORBIT.makeRod then
    local ok, r = pcall(ORBIT.makeRod, fold(), a, b, th, th, col)
    if ok then p = r end
  end
  if not p then
    p = Instance.new("Part"); p.Size = V3(th, th, (b - a).Magnitude)
    p.CFrame = CFrame.lookAt((a + b) / 2, b); p.Anchored = true; p.CanCollide = false
    p.Material = MAT.Neon; p.Color = col; p.Parent = fold()
  end
  p.CanQuery = false; p.CanTouch = false; p:SetAttribute("NoRecolor", true)
  return p
end
local function burst(pos, col, n, spd)
  local p = mkpart(PT_BALL, V3(0.2, 0.2, 0.2), col, MAT.Neon, 1)
  p.CFrame = CF(pos)
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(col); e.Size = NumberSequence.new(0.6, 0)
  e.Lifetime = NumberRange.new(0.4, 0.9); e.Speed = NumberRange.new(spd or 12, (spd or 12) * 2)
  e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0; e.LightEmission = 1; e.Parent = p
  e:Emit(n or 20)
  Debris:AddItem(p, 1.5)
end
local function impactRing(pos, col, r, th)
  local p = mkpart(Enum.PartType.Cylinder, V3(0.3, r * 0.5, r * 0.5), col, MAT.Neon, 0.3)
  p.CFrame = CF(pos) * CFrame.Angles(0, 0, math.rad(90))
  T(p, 0.35, { Size = V3(0.3, r * 2, r * 2), Transparency = 1 })
  Debris:AddItem(p, 0.45)
  local p2 = mkpart(Enum.PartType.Cylinder, V3(0.3, r * 0.3, r * 0.3), C3(255, 255, 255), MAT.Neon, 0.2)
  p2.CFrame = p.CFrame
  T(p2, 0.28, { Size = V3(0.3, r * 1.2, r * 1.2), Transparency = 1 })
  Debris:AddItem(p2, 0.4)
end
local function blast(pos, r, col)
  impactRing(pos, col, r, 0.4)
  local p = mkpart(PT_BALL, V3(1, 1, 1), col, MAT.Neon, 0.35)
  p.CFrame = CF(pos)
  T(p, 0.35, { Size = V3(r * 2, r * 2, r * 2), Transparency = 1 })
  Debris:AddItem(p, 0.5)
  burst(pos, col, 25, r * 3)
end
local function bolt(a, b, col, th)
  local segs, d = 8, b - a
  local pts = { a }
  for i = 1, segs - 1 do
    local off = V3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (d.Magnitude / segs) * 1.2
    pts[#pts + 1] = a + d * (i / segs) + off
  end
  pts[#pts + 1] = b
  for i = 1, #pts - 1 do
    local p = rodp(pts[i], pts[i + 1], th or 0.35, col)
    if p then Debris:AddItem(p, 0.18) end
  end
end
local function trailFx(a, b, col)
  local p = rodp(a, b, 0.9, col)
  if p then p.Transparency = 0.2; T(p, 0.45, { Transparency = 1 }); Debris:AddItem(p, 0.6) end
end
local function clampPt(from, to, maxd)
  local d = to - from
  if d.Magnitude > maxd then return from + d.Unit * maxd end
  return to
end
local function rayParams()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  local ex = { fold() }
  if LP.Character then ex[#ex + 1] = LP.Character end
  rp.FilterDescendantsInstances = ex
  return rp
end
local function isSolid(inst)
  if inst.CanCollide then return true end
  local m = inst:FindFirstAncestorOfClass("Model")
  return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
end
local function attachTrail(part, col)
  local a0 = Instance.new("Attachment"); a0.Position = V3(0, 0, 0); a0.Parent = part
  local a1 = Instance.new("Attachment"); a1.Position = V3(0, 0, 0); a1.Parent = part
  local tr = Instance.new("Trail")
  tr.Attachment0 = a0; tr.Attachment1 = a1
  tr.Lifetime = 0.35
  tr.Color = ColorSequence.new(col)
  tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
  tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
  tr.LightEmission = 1; tr.FaceCamera = true
  tr.Parent = part
  return tr
end

-- ===== Враги =====
local function enemies()
  local t = tick()
  if t - enemyT < 0.15 then return enemyCache end
  enemyT = t
  local list = {}
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP and p.Character then
      local h = p.Character:FindFirstChildOfClass("Humanoid")
      local r = p.Character:FindFirstChild("HumanoidRootPart")
      if h and r and h.Health > 0 then list[#list + 1] = { plr = p, hum = h, root = r } end
    end
  end
  enemyCache = list
  return list
end
local function near(pos, r)
  local out = {}
  for _, e in ipairs(enemies()) do
    if e.hum.Health > 0 and (e.root.Position - pos).Magnitude <= r then out[#out + 1] = e end
  end
  return out
end
local function dmg(e, n)
  if not e or not e.hum or e.hum.Health <= 0 then return end
  pcall(function() e.hum:TakeDamage(n) end)
  hitWatch[e.hum] = tick()
  hitMarkerUntil = tick() + 0.18
end
local function knock(root, dir, studs)
  if dir.Magnitude < 0.01 then dir = V3(0, 0, 1) end
  pcall(function() root.AssemblyLinearVelocity = dir.Unit * studs * 3 + V3(0, studs * 0.8, 0) end)
end
local function slowEnemy(hum, f, sec)
  if not hum or not hum.Parent or hum.Health <= 0 then return end
  if hum == LP.Character or (LP.Character and hum:IsDescendantOf(LP.Character)) then return end
  local s = slows[hum]
  if not s then s = { orig = hum.WalkSpeed, endt = 0 }; slows[hum] = s end
  s.endt = math.max(s.endt, tick() + sec)
  pcall(function() hum.WalkSpeed = s.orig * f end)
end
local function burn(e, sec)
  pcall(function()
    local f = Instance.new("Fire"); f.Size = 6; f.Heat = 0; f.Parent = e.root
    Debris:AddItem(f, sec)
  end)
  dots[#dots + 1] = { e = e, dps = 5, endt = tick() + sec }
end
local function mkCloud(pos, r, dur, dps, col, rain)
  local p
  if rain then
    p = mkpart(PT_BLOCK, V3(r * 2, 1, r * 2), col, MAT.Neon, 1); p.CFrame = CF(pos + V3(0, 16, 0))
  else
    p = mkpart(PT_BALL, V3(r * 1.6, r * 1.6, r * 1.6), col, MAT.Neon, 0.9); p.CFrame = CF(pos + V3(0, r * 0.4, 0))
  end
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(col)
  if rain then
    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    e.Rate = 90; e.Lifetime = NumberRange.new(0.8, 1.1); e.Speed = NumberRange.new(26, 32)
    e.EmissionDirection = Enum.NormalId.Bottom; e.Size = NumberSequence.new(0.5); e.LightEmission = 0.6
  else
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.Rate = 35; e.Lifetime = NumberRange.new(1.5, 2.5); e.Speed = NumberRange.new(1, 3)
    e.SpreadAngle = Vector2.new(180, 180); e.Size = NumberSequence.new(r * 0.5, r * 0.7)
    e.Transparency = NumberSequence.new(0.45, 1); e.LightEmission = 0.2
  end
  e.Parent = p
  clouds[#clouds + 1] = { pos = pos, r = r, endt = tick() + dur, dps = dps, part = p }
end

-- ===== Прицел =====
local function screenPoint()
  local c = cam()
  local vp = c and c.ViewportSize or Vector2.new(800, 400)
  if centerOnce then return vp / 2 end
  if MOB then
    if aiming and crossPos then return crossPos end
    return vp / 2
  end
  return UIS:GetMouseLocation()
end
-- Получить точку, куда смотрит прицел. Если прицел выключен — берём центр экрана.
local function aimPoint(origin)
  local c = cam()
  if not c then return origin + V3(0, 0, -50) end
  local sp = screenPoint()
  local ray = c:ViewportPointToRay(sp.X, sp.Y)
  local res = WS:Raycast(ray.Origin, ray.Direction * 1000, rayParams())
  if res then return res.Position end
  return ray.Origin + ray.Direction * 1000
end

-- ===== Снаряды =====
local function addProj(q) q.born = tick(); A.projectiles[#A.projectiles + 1] = q end
local function onFire(q, pos)
  local r = C.fire.r * (q.ch and C.charge.size or 1)
  blast(pos, r, EL[1].col)
  for _, t in ipairs(near(pos, r)) do dmg(t, C.fire.dmg * q.mul); burn(t, C.fire.burn) end
  ping("ping", 1, 1.2)
end
local function onEarth(q, pos)
  burst(pos, C3(140, 105, 70), 25, 14)
  impactRing(pos, C3(180, 140, 90), 5, 0.4)
  for _, t in ipairs(near(pos, 5)) do
    dmg(t, C.earth.dmg * q.mul)
    knock(t.root, t.root.Position - pos, C.earth.knock)
  end
  ping("ping", 1, 0.7)
end
local function onIce(q, pos)
  burst(pos, EL[4].col, 14, 10)
  impactRing(pos, EL[4].col, 3.2, 0.3)
  for _, t in ipairs(near(pos, 3.2)) do dmg(t, C.ice.dmg * q.mul); slowEnemy(t.hum, 0.3, C.ice.slow) end
  ping("ping", 0.8, 1.6)
end
local function stepProj(dt)
  local list = A.projectiles
  if #list == 0 then return end
  local rp = rayParams()
  for i = #list, 1, -1 do
    local q = list[i]
    local part = q.part
    if not part or not part.Parent or tick() - q.born > q.life then
      if part then pcall(function() part:Destroy() end) end
      table.remove(list, i)
    else
      if q.g then q.vel = q.vel + V3(0, -q.g * dt, 0) end
      local from = part.Position
      local to = from + q.vel * dt
      local hitPos
      if not q.visual then
        local res = WS:Raycast(from, to - from, rp)
        if res and isSolid(res.Instance) then hitPos = res.Position end
        if not hitPos then
          for _, e in ipairs(enemies()) do
            if e.hum.Health > 0 and (e.root.Position - to).Magnitude <= q.rad then hitPos = to; break end
          end
        end
      end
      if hitPos then
        table.remove(list, i)
        pcall(q.onHit, q, hitPos)
        pcall(function() part:Destroy() end)
      elseif q.spin then
        q.rot = (q.rot or 0) + dt * 8
        part.CFrame = CF(to) * CFrame.Angles(q.rot, q.rot * 0.7, 0)
      else
        part.CFrame = CFrame.lookAt(to, to + q.vel)
      end
    end
  end
end

-- ===== Способности =====
local FIRE = {}
FIRE.fire = function(ch, origin, dir)
  local sz = 1.6 * (ch and C.charge.size or 1)
  local p = mkpart(PT_BALL, V3(sz, sz, sz), EL[1].col)
  p.CFrame = CF(origin); glow(p, EL[1].col, ch and 90 or 45)
  attachTrail(p, EL[1].col)
  addProj({ part = p, vel = dir * C.fire.speed * (ch and C.charge.speed or 1), life = 3, rad = sz * 0.5 + 3, onHit = onFire, ch = ch, mul = ch and C.charge.dmg or 1 })
end
FIRE.earth = function(ch, origin, dir)
  local sz = 2.2 * (ch and C.charge.size or 1)
  local p = mkpart(PT_BLOCK, V3(sz, sz * 0.8, sz * 1.1), C3(125, 95, 60), MAT.Slate)
  p.CFrame = CF(origin)
  local sp = C.earth.speed * (ch and C.charge.speed or 1)
  addProj({ part = p, vel = dir * sp + V3(0, 22, 0), g = C.earth.g, spin = true, life = 4, rad = sz * 0.5 + 3, onHit = onEarth, ch = ch, mul = ch and C.charge.dmg or 1 })
end
FIRE.ice = function(ch, origin, dir)
  for k = -1, 1 do
    local d = CFrame.Angles(0, math.rad(C.ice.spread * k), 0):VectorToWorldSpace(dir)
    local p = mkpart(PT_BLOCK, V3(0.45, 0.45, 2.4) * (ch and 1.3 or 1), C3(170, 230, 255), MAT.Glass, 0.15)
    p.CFrame = CFrame.lookAt(origin, origin + d)
    attachTrail(p, EL[4].col)
    addProj({ part = p, vel = d * C.ice.speed * (ch and C.charge.speed or 1), life = 2, rad = 3, onHit = onIce, ch = ch, mul = ch and C.charge.dmg or 1 })
  end
end
FIRE.lightning = function(ch, origin, dir)
  local list = near(origin, C.lightning.range)
  table.sort(list, function(a, b) return (a.root.Position - origin).Magnitude < (b.root.Position - origin).Magnitude end)
  local t = list[1]
  local to = t and t.root.Position or (origin + dir * C.lightning.range)
  bolt(origin, to, EL[5].col, ch and 0.6 or 0.35)
  burst(to, EL[5].col, 18, 14)
  impactRing(to, EL[5].col, 4, 0.3)
  local mul = ch and C.charge.dmg or 1
  if t then
    dmg(t, C.lightning.dmg * mul); slowEnemy(t.hum, 0, C.lightning.stun)
    if ch then
      for _, e2 in ipairs(near(t.root.Position, 20)) do
        if e2 ~= t then
          bolt(t.root.Position, e2.root.Position, EL[5].col, 0.5)
          dmg(e2, C.lightning.dmg); slowEnemy(e2.hum, 0, C.lightning.stun)
          break
        end
      end
    end
  end
  ping("snap", 1, 1.5)
end
local function flatDir(dir, r)
  local f = V3(dir.X, 0, dir.Z)
  if f.Magnitude < 0.1 then f = r.CFrame.LookVector * V3(1, 0, 1) end
  return f.Unit
end
local function hop(r, flat, dist, col)
  local from = r.Position
  local d = dist
  local res = WS:Raycast(from, flat * dist, rayParams())
  if res and res.Instance.CanCollide then d = math.max(2, (res.Position - from).Magnitude - 2) end
  ORBIT.abilityMoveUntil = tick() + 1
  local to = from + flat * d
  trailFx(from, to, col)
  r.CFrame = CF(to, to + flat)
  burst(from, col, 16, 10); burst(to, col, 16, 10)
end

-- ✨ ТЕЛЕПОРТ v24.5: летит в точку прицела (до 200 studs), с рейкастом на пути
FIRE.teleport = function(ch, origin, dir, target, c, h, r)
  local from = r.Position
  local want = target or aimPoint(from)  -- куда смотрит прицел

  -- Ограничение дистанции
  local diff = want - from
  local maxDist = C.teleport.maxDist  -- 200 studs
  if ch then maxDist = maxDist * 1.3 end  -- заряженный — 260
  if diff.Magnitude > maxDist then
    want = from + diff.Unit * maxDist
  end

  -- Проверяем, нет ли стены на пути (от груди игрока, а не от ног)
  local head = from + V3(0, 1.5, 0)
  local wantHead = want + V3(0, 1.5, 0)
  local rayDir = (wantHead - head)
  local rp = rayParams()
  local res = WS:Raycast(head, rayDir, rp)
  local finalPos = want
  if res and res.Instance.CanCollide then
    -- останавливаемся перед стеной (немного отступаем)
    local hitDist = (res.Position - head).Magnitude
    local safeDist = math.max(2, hitDist - 3)
    finalPos = head + rayDir.Unit * safeDist
    finalPos = V3(finalPos.X, finalPos.Y - 1.5, finalPos.Z)
  end

  -- Ищем безопасный пол под целевой точкой
  local downRes = WS:Raycast(finalPos + V3(0, 5, 0), V3(0, -15, 0), rp)
  if downRes then
    finalPos = downRes.Position + V3(0, 3, 0)
  end

  -- Ставим на позицию
  ORBIT.abilityMoveUntil = tick() + 1
  local to = finalPos

  -- Визуал: 2 следа + кольцо
  trailFx(from + V3(0, 1, 0), to + V3(0, 1, 0), EL[6].col)
  burst(from, EL[6].col, 24, 15)
  burst(to, EL[6].col, 24, 15)
  impactRing(from, EL[6].col, 4, 0.35)
  impactRing(to, EL[6].col, 5, 0.4)

  -- Телепорт
  local look = r.CFrame.LookVector
  r.CFrame = CF(to, to + look)
  pcall(function()
    r.AssemblyLinearVelocity = V3(0, 0, 0)
    r.AssemblyAngularVelocity = V3(0, 0, 0)
  end)
  local dist = (to - from).Magnitude
  toast(string.format("✨ Телепорт: %.0f st", dist))
  ping("snap", 1, 1.6)
end

-- ✨ СКОРОСТЬ v24.5: ускорение вернули (WalkSpeed 32 на 3 сек)
FIRE.speed = function(ch, origin, dir, target, c, h, r)
  hop(r, flatDir(dir, r), C.speed.dist * (ch and 1.5 or 1), EL[7].col)
  local dur = C.speed.dur * (ch and 1.5 or 1)
  speedUntil = tick() + dur
  ORBIT.abilitySpeedUntil = speedUntil
  -- ✨ УСКОРЕНИЕ
  if h and h.Parent then
    speedRestoreToken = speedRestoreToken + 1
    local myToken = speedRestoreToken
    local prevSpeed = h.WalkSpeed
    local boost = 32 * (ch and 1.3 or 1)
    pcall(function() h.WalkSpeed = boost end)
    task.delay(dur, function()
      if not alive or speedRestoreToken ~= myToken then return end
      if h and h.Parent and h.WalkSpeed == boost then
        pcall(function() h.WalkSpeed = prevSpeed end)
      end
    end)
  end
  ping("snap", 1, 1.3)
end
FIRE.wind = function(ch, origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 40)
  for k = 0, 2 do
    task.delay(k * 0.12, function()
      if not alive then return end
      local ring = mkpart(Enum.PartType.Cylinder, V3(0.5, 2, 2), EL[8].col, MAT.Neon, 0.45)
      ring.CFrame = CF(p + V3(0, k * 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
      T(ring, 0.7, { Size = V3(0.5, C.wind.r * 2, C.wind.r * 2), Transparency = 1, CFrame = ring.CFrame * CFrame.Angles(math.rad(170), 0, 0) })
      Debris:AddItem(ring, 0.9)
    end)
  end
  burst(p, EL[8].col, 30, 18)
  for _, e in ipairs(near(p, C.wind.r)) do knock(e.root, e.root.Position - p, C.wind.knock * (ch and 1.5 or 1)) end
  ping("snap", 0.9, 0.6)
end
FIRE.poison = function(ch, origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 50)
  mkCloud(p, C.poison.r * (ch and 1.5 or 1), C.poison.dur, C.poison.dps * (ch and C.charge.dmg or 1), C3(80, 200, 70), false)
  ping("snap", 0.8, 0.5)
end

-- ===== Комбо =====
local COMBOS = {}
COMBOS["fire+lightning"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 60)
  blast(p, 12, C3(200, 110, 255)); blast(p, 6, C3(255, 210, 90))
  bolt(p + V3(0, 40, 0), p, C3(220, 170, 255), 0.6)
  for _, e in ipairs(near(p, 12)) do dmg(e, 80); burn(e, 2) end
  toast("🔥⚡ ПЛАЗМЕННЫЙ ВЗРЫВ")
end
COMBOS["ice+water"] = function(origin, dir, target, c, h, r)
  local p = r.Position
  local w = mkpart(PT_BALL, V3(2, 2, 2), C3(170, 230, 255), MAT.Neon, 0.3)
  w.CFrame = CF(p)
  T(w, 0.6, { Size = V3(40, 40, 40), Transparency = 0.92 }); Debris:AddItem(w, 0.8)
  burst(p, C3(200, 240, 255), 40, 25)
  for _, e in ipairs(near(p, 20)) do slowEnemy(e.hum, 0, 2.5); dmg(e, 10) end
  toast("💧❄️ ЛЕДЯНАЯ ВОЛНА")
end
COMBOS["earth+wind"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 50)
  blast(p, 15, C3(210, 180, 120))
  mkCloud(p, 15, 3, 0, C3(210, 180, 120), false)
  for _, e in ipairs(near(p, 15)) do dmg(e, 50); slowEnemy(e.hum, 0.4, 3) end
  toast("🌍🌪️ ПЕСЧАНАЯ БУРЯ")
end
COMBOS["poison+water"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 50)
  mkCloud(p, 15, 3, 20, C3(150, 230, 60), true)
  toast("☠️💧 КИСЛОТНЫЙ ДОЖДЬ")
end
COMBOS["fire+ice"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 55)
  blast(p, 10, C3(255, 180, 90)); blast(p, 10, C3(180, 230, 255))
  for _, e in ipairs(near(p, 10)) do dmg(e, 45); slowEnemy(e.hum, 0.4, 2); burn(e, 2) end
  toast("🔥❄️ ТЕРМОШОК")
end
COMBOS["fire+wind"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 60)
  burst(p, C3(255, 130, 40), 60, 30)
  for _, e in ipairs(near(p, 15)) do dmg(e, 35); burn(e, 3) end
  toast("🔥🌪️ ОГНЕННЫЙ СМЕРЧ")
end
COMBOS["ice+lightning"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 55)
  bolt(p + V3(0, 30, 0), p, C3(200, 230, 255), 0.5)
  for _, e in ipairs(near(p, 12)) do dmg(e, 60); slowEnemy(e.hum, 0.2, 3) end
  toast("❄️⚡ ЛЕДЯНАЯ МОЛНИЯ")
end
COMBOS["water+lightning"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 50)
  local w = mkpart(PT_BALL, V3(3, 3, 3), C3(80, 160, 255), MAT.Neon, 0.4)
  w.CFrame = CF(p)
  T(w, 0.4, { Size = V3(20, 20, 20), Transparency = 1 }); Debris:AddItem(w, 0.5)
  for _, e in ipairs(near(p, 12)) do dmg(e, 55); slowEnemy(e.hum, 0.2, 1.5) end
  bolt(p + V3(0, 25, 0), p, C3(140, 200, 255), 0.4)
  toast("💧⚡ ЭЛЕКТРОШОК")
end
COMBOS["teleport+lightning"] = function(origin, dir, target, c, h, r)
  local p = clampPt(r.Position, target, 45)
  for i = 1, 4 do
    task.delay(i * 0.08, function()
      if not alive then return end
      bolt(p + V3(math.random(-6, 6), 30, math.random(-6, 6)), p, EL[5].col, 0.4)
    end)
  end
  for _, e in ipairs(near(p, 10)) do dmg(e, 90); slowEnemy(e.hum, 0, 1) end
  toast("✨⚡ ПРОСТРАНСТВЕННЫЙ РАЗРЯД")
end
-- ✨ speed+wind — теперь с ускорением
COMBOS["speed+wind"] = function(origin, dir, target, c, h, r)
  local dur = 6
  speedUntil = tick() + dur
  ORBIT.abilitySpeedUntil = speedUntil
  if h and h.Parent then
    speedRestoreToken = speedRestoreToken + 1
    local myToken = speedRestoreToken
    local prevSpeed = h.WalkSpeed
    local boost = 40
    pcall(function() h.WalkSpeed = boost end)
    task.delay(dur, function()
      if not alive or speedRestoreToken ~= myToken then return end
      if h and h.Parent and h.WalkSpeed == boost then
        pcall(function() h.WalkSpeed = prevSpeed end)
      end
    end)
  end
  local p = r.Position
  for i = 0, 4 do
    task.delay(i * 0.1, function()
      if not alive then return end
      local ring = mkpart(Enum.PartType.Cylinder, V3(0.4, 3, 3), EL[8].col, MAT.Neon, 0.5)
      ring.CFrame = CF(p) * CFrame.Angles(0, 0, math.rad(90))
      T(ring, 0.5, { Size = V3(0.4, 20, 20), Transparency = 1 })
      Debris:AddItem(ring, 0.6)
    end)
  end
  toast("💨🌪️ УСКОРЕНИЕ ВЕТРА")
end

local function cdLeft(id) return math.max(0, (A.cooldowns[id] or 0) - tick()) end
local function cdFrac(id)
  local left = cdLeft(id)
  local cd = (C[id] and C[id].cd) or 1
  if left <= 0 or cd <= 0 then return 0 end
  return math.min(1, left / cd)
end
local function comboKey()
  local a, b = lastFire[1], lastFire[2]
  local t = tick()
  if a and b and t - a.t <= C.combo.window and t - b.t <= C.combo.window then
    local k = { a.id, b.id }
    table.sort(k)
    local key = k[1] .. "+" .. k[2]
    if COMBOS[key] then return key end
  end
  return nil
end

-- ===== Публичные функции =====
function A.fireId(id, ch)
  if not alive then return false end
  local c, h, r = getChar()
  if not c then return false end
  local el = EL[IDX[id]]
  if not el then return false end
  if id == "water" then waterUntil = tick() + 1.5; return true end
  local left = cdLeft(id)
  if left > 0 then ping("click", 0.6, 0.8); toast(el.nm .. " КД " .. string.format("%.1f", left)); return false end
  local origin = r.Position + V3(0, 1.5, 0) + r.CFrame.LookVector * 1.5
  local target = aimPoint(origin)
  local dir = target - origin
  if dir.Magnitude < 0.5 then dir = r.CFrame.LookVector end
  dir = dir.Unit
  local ok, err = pcall(FIRE[id], ch and true or false, origin, dir, target, c, h, r)
  if not ok then warn("[ORBIT] abilities: " .. tostring(err)); return false end
  A.cooldowns[id] = tick() + C[id].cd * (ch and 1.3 or 1)
  if lastFire[1] and lastFire[1].id == id then lastFire[1].t = tick()
  else
    table.insert(lastFire, 1, { id = id, t = tick() })
    while #lastFire > 4 do table.remove(lastFire) end
  end
  ORBIT.abilityLast = id; ORBIT.abilityLastTime = tick()
  ping("snap", 0.9, id == "ice" and 1.3 or 1)
  return true
end
function A.fire(ch) return A.fireId(A.current, ch) end
function A.alt() return A.fireId(prevId, false) end
function A.combo()
  if not alive then return false end
  local c, h, r = getChar()
  if not c then return false end
  local key = comboKey()
  if not key then ping("click", 0.6, 0.8); toast("КОМБО: нужна пара стихий"); return false end
  local left = cdLeft("combo")
  if left > 0 then ping("click", 0.6, 0.8); toast("КОМБО КД " .. string.format("%.1f", left)); return false end
  local origin = r.Position + V3(0, 1.5, 0)
  local target = aimPoint(origin)
  local dir = target - origin
  if dir.Magnitude < 0.5 then dir = r.CFrame.LookVector end
  local ok, err = pcall(COMBOS[key], origin, dir.Unit, target, c, h, r)
  if not ok then warn("[ORBIT] abilities combo: " .. tostring(err)); return false end
  A.cooldowns.combo = tick() + C.combo.cd
  lastFire = {}
  ORBIT.abilityLast = "combo"; ORBIT.abilityLastTime = tick()
  ping("switch", 1, 0.9)
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "combo") end
  return true
end
function A.setCurrent(id)
  if not IDX[id] then return false end
  if id ~= A.current then
    prevId = A.current; A.current = id; waterHeld = false; pressT = nil
    ping("switch", 0.8, 1.2)
  end
  return true
end
function A.next() local i = IDX[A.current] % #EL + 1; return A.setCurrent(EL[i].id) end
function A.prev() local i = (IDX[A.current] - 2) % #EL + 1; return A.setCurrent(EL[i].id) end
function A.aim(on)
  if on == nil then aiming = not aiming else aiming = on and true or false end
  if aiming and not crossPos then local c = cam(); crossPos = c and c.ViewportSize / 2 or Vector2.new(400, 200) end
  return aiming
end

function A.hideElement(id)
  if not IDX[id] then return false end
  hidden[id] = true
  if A.current == id then
    for _, e in ipairs(EL) do
      if not hidden[e.id] then A.setCurrent(e.id); break end
    end
  end
  return true
end
function A.showElement(id)
  if not IDX[id] then return false end
  hidden[id] = nil
  return true
end
function A.isHidden(id) return hidden[id] == true end
function A.getVisibleElements()
  local out = {}
  for _, e in ipairs(EL) do
    if not hidden[e.id] then out[#out + 1] = e end
  end
  return out
end
function A.getElements() return EL end
function A.resetHidden() hidden = {} end

-- ===== Slow-mo =====
local function smEnd()
  if not sm then return end
  local s = sm
  sm = nil
  pcall(function() WS.Gravity = s.g0 end)
  pcall(function() local c = cam(); if c and s.fov0 then c.FieldOfView = s.fov0 end end)
  if s.cc then pcall(function() s.cc:Destroy() end) end
  if s.gui then pcall(function() s.gui:Destroy() end) end
end
local function smStart()
  if sm or not alive then return end
  local c, h = getChar()
  local cm = cam()
  sm = { t0 = tick(), g0 = WS.Gravity, hum = h, fov0 = cm and cm.FieldOfView }
  local cc = Instance.new("ColorCorrectionEffect")
  cc.Name = "OrbitSlowmoCC"; cc.Parent = Lighting; sm.cc = cc
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if pg then
    local g = Instance.new("ScreenGui")
    g.Name = "OrbitSlowmoVig"; g.IgnoreGuiInset = true; g.ResetOnSpawn = false; g.DisplayOrder = 30; g.Parent = pg
    local cg = Instance.new("CanvasGroup")
    cg.Size = UDim2.fromScale(1, 1); cg.BackgroundTransparency = 1; cg.GroupTransparency = 1; cg.Parent = g
    local function edge(pos, size, rot)
      local f = Instance.new("Frame")
      f.BackgroundColor3 = C3(0, 0, 0); f.BorderSizePixel = 0; f.Position = pos; f.Size = size; f.Parent = cg
      local gr = Instance.new("UIGradient")
      gr.Rotation = rot
      gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
      gr.Parent = f
    end
    edge(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.3, 0), 90)
    edge(UDim2.new(0, 0, 0.7, 0), UDim2.new(1, 0, 0.3, 0), 270)
    edge(UDim2.new(0, 0, 0, 0), UDim2.new(0.25, 0, 1, 0), 0)
    edge(UDim2.new(0.75, 0, 0, 0), UDim2.new(0.25, 0, 1, 0), 180)
    sm.gui = g; sm.cg = cg
  end
  ping("snap", 1, 0.8)
end
local function smStep()
  if not sm then return end
  local el = tick() - sm.t0
  local f
  if el < 0.25 then f = 1 - 0.7 * (el / 0.25)
  elseif el < 1.6 then f = 0.3
  elseif el < 2 then f = 0.3 + 0.7 * ((el - 1.6) / 0.4)
  else smEnd(); return end
  local k = (1 - f) / 0.7
  pcall(function() WS.Gravity = sm.g0 * f * f end)
  pcall(function()
    sm.cc.Saturation = 0.6 * k; sm.cc.Contrast = 0.25 * k
    sm.cc.TintColor = Color3.new(1, 1 - 0.12 * k, 1 - 0.08 * k)
    if sm.cg then sm.cg.GroupTransparency = 1 - k end
    local cm = cam(); if cm and sm.fov0 then cm.FieldOfView = sm.fov0 - 8 * k end
  end)
end
A.slowmo = smStart

-- ===== Вода =====
local function waterTick(dt)
  local c, h, r = getChar()
  if not c then return end
  local origin = r.Position + V3(0, 1.5, 0)
  local dir = aimPoint(origin) - origin
  if dir.Magnitude < 0.1 then dir = r.CFrame.LookVector end
  dir = dir.Unit
  waterAcc = waterAcc + dt
  if waterAcc >= 0.04 then
    waterAcc = 0
    local jit = V3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
    local d = mkpart(PT_BALL, V3(0.9, 0.9, 0.9), EL[3].col, MAT.Glass, 0.25)
    d.CFrame = CF(origin + dir * 2 + jit)
    addProj({ part = d, vel = dir * 70 + jit * 6, g = 12, life = 0.55, visual = true })
  end
  for _, e in ipairs(enemies()) do
    local to = e.root.Position - origin
    local d = to.Magnitude
    if e.hum.Health > 0 and d <= C.water.range and d > 0.1 and to.Unit:Dot(dir) > 0.92 then
      dmg(e, C.water.dps * dt)
      pcall(function()
        local v = e.root.AssemblyLinearVelocity
        e.root.AssemblyLinearVelocity = V3(dir.X * C.water.push, v.Y, dir.Z * C.water.push)
      end)
    end
  end
end

-- ===== Нажатие / отпускание =====
local function pressDown()
  if not getChar() then return end
  if A.current == "water" then waterHeld = true; return end
  pressT = tick()
  if shiftHeld then A.fire(true); pressT = nil end
end
local function pressUp()
  if waterHeld then waterHeld = false; return end
  if pressT then
    local held = tick() - pressT
    pressT = nil
    A.fire(held >= C.charge.time)
  end
end

-- ===== Помощник =====
local function ruLower(s)
  s = s:lower()
  s = s:gsub("\208([\144-\175])", function(ch)
    local b = ch:byte()
    if b <= 159 then return "\208" .. string.char(b + 32) end
    return "\209" .. string.char(b - 32)
  end)
  s = s:gsub("\208\129", "\209\145")
  return s
end
local NAMES = { { "огонь", "fire" }, { "земл", "earth" }, { "вод", "water" }, { "лёд", "ice" }, { "лед", "ice" }, { "молни", "lightning" }, { "телепорт", "teleport" }, { "скорост", "speed" }, { "ветер", "wind" }, { "яд", "poison" } }
function A.interpret(raw)
  local t = ruLower(raw)
  local function has(s) return t:find(s, 1, true) ~= nil end
  if has("стихи") then
    for _, p in ipairs(NAMES) do
      if has(p[1]) then A.setCurrent(p[2]); return true, "✨ Стихия: " .. EL[IDX[p[2]]].nm end
    end
  end
  if has("комбо") then A.combo(); return true, "✨ Комбо" end
  if has("стреляй") or has("выстрел") then A.fire(false); return true, "🔥 Выстрел: " .. EL[IDX[A.current]].nm end
  if has("прицел") then return true, A.aim() and "🎯 Прицел включён" or "🎯 Прицел выключен" end
  return false
end
local function wrapHelper()
  local H = ORBIT.helper
  if helperWrapped or not H or type(H.interpret) ~= "function" then return end
  helperWrapped = true
  origInterp = H.interpret
  H.interpret = function(raw, ...)
    if alive and type(raw) == "string" then
      local ok, handled, msg = pcall(A.interpret, raw)
      if ok and handled then return true, msg end
    end
    return origInterp(raw, ...)
  end
end

-- ===== UI =====
local function onClick(btn, fn)
  local deb = false
  local function call()
    if deb then return end
    deb = true
    task.delay(0.12, function() deb = false end)
    pcall(fn)
  end
  connect(btn.MouseButton1Down, call)
  connect(btn.Activated, call)
end
local function mkBtn(parent, text, w, h, pos, anchor)
  local b = Instance.new("TextButton")
  b.Size = UDim2.fromOffset(math.max(w, 30), math.max(h, 30)); b.Position = pos
  b.AnchorPoint = anchor or Vector2.new(0, 0)
  b.BackgroundColor3 = C3(30, 30, 40); b.BackgroundTransparency = 0.15
  b.TextColor3 = C3(255, 255, 255); b.Font = Enum.Font.GothamBold
  b.TextSize = math.floor(math.min(w, h) * 0.5); b.Text = text; b.AutoButtonColor = false
  b.Parent = parent
  Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
  return b
end
local KEYN = {}
for i, k in ipairs({ "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }) do KEYN[Enum.KeyCode[k]] = i end

local function mkUI()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local sg = Instance.new("ScreenGui")
  sg.Name = "OrbitAbilitiesGui"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 20; sg.Parent = pg
  ui.sg = sg
  local cm = cam()
  local vp = cm and cm.ViewportSize or Vector2.new(800, 400)
  local slot = math.clamp(math.floor((vp.X - 24) / 9) - 3, 30, 46)
  ui.slot = slot
  local pan = Instance.new("Frame")
  pan.Name = "Panel"; pan.AnchorPoint = Vector2.new(0.5, 1); pan.Position = UDim2.new(0.5, 0, 1, -8)
  pan.Size = UDim2.fromOffset(9 * slot + 8 * 3 + 12, slot + 12)
  pan.BackgroundColor3 = C3(18, 18, 24); pan.BackgroundTransparency = 0.25; pan.Parent = sg
  Instance.new("UICorner", pan).CornerRadius = UDim.new(0, 10)
  ui.panel = pan
  ui.slots = {}
  for i, el in ipairs(EL) do
    local b = mkBtn(pan, el.ic, slot, slot, UDim2.fromOffset(6 + (i - 1) * (slot + 3), 6))
    b.BackgroundColor3 = C3(34, 34, 44); b.BackgroundTransparency = 0; b.ClipsDescendants = true
    local st = Instance.new("UIStroke"); st.Color = el.col; st.Thickness = 1; st.Parent = b
    local sh = Instance.new("Frame")
    sh.Size = UDim2.new(1, 0, 0, 0); sh.BackgroundColor3 = C3(0, 0, 0); sh.BackgroundTransparency = 0.35
    sh.BorderSizePixel = 0; sh.ZIndex = 2; sh.Parent = b
    local kl = Instance.new("TextLabel")
    kl.Size = UDim2.fromOffset(12, 12); kl.Position = UDim2.fromOffset(2, 1); kl.BackgroundTransparency = 1
    kl.Text = tostring(i); kl.TextColor3 = C3(190, 190, 200); kl.Font = Enum.Font.Code; kl.TextSize = 10; kl.ZIndex = 3; kl.Parent = b
    onClick(b, function() A.setCurrent(el.id) end)
    ui.slots[el.id] = { btn = b, stroke = st, shade = sh, idxLabel = kl }
  end
  local cb = mkBtn(sg, MOB and "✨ КОМБО" or "✨ КОМБО [F]", 120, 32, UDim2.new(0.5, 0, 1, -(slot + 24)), Vector2.new(0.5, 1))
  cb.TextSize = 14; cb.TextColor3 = C3(150, 150, 160)
  ui.comboStroke = Instance.new("UIStroke"); ui.comboStroke.Color = C3(255, 240, 120); ui.comboStroke.Thickness = 1; ui.comboStroke.Parent = cb
  onClick(cb, function() A.combo() end)
  ui.combo = cb
  local pairLbl = Instance.new("TextLabel")
  pairLbl.AnchorPoint = Vector2.new(0.5, 1); pairLbl.Position = UDim2.new(0.5, 0, 1, -(slot + 60)); pairLbl.Size = UDim2.fromOffset(220, 22)
  pairLbl.BackgroundColor3 = C3(0, 0, 0); pairLbl.BackgroundTransparency = 0.4
  pairLbl.TextColor3 = C3(255, 240, 120); pairLbl.Font = Enum.Font.GothamBold
  pairLbl.TextSize = 13; pairLbl.Visible = false; pairLbl.Parent = sg
  Instance.new("UICorner", pairLbl).CornerRadius = UDim.new(0, 8)
  ui.pairLbl = pairLbl
  local ts = Instance.new("TextLabel")
  ts.AnchorPoint = Vector2.new(0.5, 1); ts.Position = UDim2.new(0.5, 0, 1, -(slot + 86)); ts.Size = UDim2.fromOffset(260, 22)
  ts.BackgroundColor3 = C3(0, 0, 0); ts.BackgroundTransparency = 0.4; ts.TextColor3 = C3(255, 255, 255)
  ts.Font = Enum.Font.GothamBold; ts.TextSize = 14; ts.Visible = false; ts.Parent = sg
  Instance.new("UICorner", ts).CornerRadius = UDim.new(0, 8)
  ui.toast = ts

  local cr = Instance.new("Frame")
  cr.Name = "Cross"; cr.AnchorPoint = Vector2.new(0.5, 0.5); cr.Size = UDim2.fromOffset(64, 64)
  cr.BackgroundTransparency = 1; cr.Visible = false; cr.Active = TOUCH; cr.Parent = sg
  ui.lines = {}
  local function line(x, y, w, h, col)
    local f = Instance.new("Frame")
    f.Position = UDim2.fromOffset(x, y); f.Size = UDim2.fromOffset(w, h); f.BorderSizePixel = 0
    f.BackgroundColor3 = col or C3(255, 255, 255); f.Parent = cr
    ui.lines[#ui.lines + 1] = f
    return f
  end
  local dot = line(30, 30, 4, 4); Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
  line(31, 0, 2, 14); line(31, 50, 2, 14)
  line(0, 31, 14, 2); line(50, 31, 14, 2)
  local ring = Instance.new("Frame")
  ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = UDim2.fromScale(0.5, 0.5)
  ring.Size = UDim2.fromOffset(80, 80); ring.BackgroundTransparency = 1
  ring.Parent = cr
  ui.hitRing = ring
  local ringStroke = Instance.new("UIStroke", ring)
  ringStroke.Color = C3(255, 80, 80); ringStroke.Thickness = 2; ringStroke.Transparency = 1
  ui.hitStroke = ringStroke
  local cl = Instance.new("TextLabel")
  cl.AnchorPoint = Vector2.new(0.5, 0); cl.Position = UDim2.new(0.5, 0, 1, 2); cl.Size = UDim2.fromOffset(180, 16)
  cl.BackgroundTransparency = 1; cl.TextColor3 = C3(255, 255, 255); cl.Font = Enum.Font.Code; cl.TextSize = 12; cl.Parent = cr
  ui.cross, ui.crossLabel = cr, cl

  local dragging = nil
  connect(cr.InputBegan, function(i)
    if TOUCH and i.UserInputType == Enum.UserInputType.Touch then dragging = i end
  end)
  connect(UIS.InputChanged, function(i, gp)
    if dragging and i == dragging then crossPos = Vector2.new(i.Position.X, i.Position.Y) end
    if i.UserInputType == Enum.UserInputType.MouseWheel and not gp and alive then
      if i.Position.Z > 0 then A.prev() else A.next() end
    end
  end)
  connect(UIS.InputEnded, function(i) if dragging and i == dragging then dragging = nil end end)
  if MOB then
    local fb = mkBtn(sg, "🔥", 64, 64, UDim2.new(1, -16, 1, -190), Vector2.new(1, 1))
    fb.TextSize = 30
    connect(fb.InputBegan, function(i)
      if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then pressDown() end
    end)
    connect(fb.InputEnded, function(i)
      if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then pressUp() end
    end)
    ui.fireBtn = fb
    local ab = mkBtn(sg, "🎯", 46, 46, UDim2.new(1, -16, 1, -262), Vector2.new(1, 1))
    onClick(ab, function() A.aim() end)
    local menu = Instance.new("Frame")
    menu.AnchorPoint = Vector2.new(1, 1); menu.Position = UDim2.new(1, -120, 1, -190); menu.Size = UDim2.fromOffset(3 * 48 + 16, 3 * 48 + 16)
    menu.BackgroundColor3 = C3(18, 18, 24); menu.BackgroundTransparency = 0.2; menu.Visible = false; menu.Parent = sg
    Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 10)
    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.fromOffset(44, 44); gl.CellPadding = UDim2.fromOffset(4, 4)
    gl.HorizontalAlignment = Enum.HorizontalAlignment.Center; gl.VerticalAlignment = Enum.VerticalAlignment.Center; gl.Parent = menu
    for _, el in ipairs(EL) do
      local mb = Instance.new("TextButton")
      mb.Text = el.ic; mb.TextSize = 24; mb.Font = Enum.Font.GothamBold; mb.TextColor3 = C3(255, 255, 255)
      mb.BackgroundColor3 = C3(34, 34, 44); mb.AutoButtonColor = false; mb.Parent = menu
      Instance.new("UICorner", mb).CornerRadius = UDim.new(0, 8)
      onClick(mb, function() A.setCurrent(el.id); menu.Visible = false end)
    end
    local sb = mkBtn(sg, "🗡 ВЫБОР", 90, 36, UDim2.new(1, -16, 1, -318), Vector2.new(1, 1))
    sb.TextSize = 14
    onClick(sb, function() menu.Visible = not menu.Visible end)
  end
end

local function refreshUI()
  if not ui.sg then return end
  local t = tick()
  for id, s in pairs(ui.slots) do
    s.shade.Size = UDim2.new(1, 0, cdFrac(id), 0)
    local on = (id == A.current)
    s.stroke.Thickness = on and 3 or 1
    s.btn.BackgroundColor3 = on and C3(52, 52, 70) or C3(34, 34, 44)
  end
  local el = EL[IDX[A.current]]
  ui.cross.Visible = aiming
  if aiming then
    local sp = screenPoint()
    ui.cross.Position = UDim2.fromOffset(sp.X, sp.Y)
    local origin = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character.HumanoidRootPart.Position or V3()
    local dist = 0
    local target = aimPoint(origin)
    if target then dist = (target - origin).Magnitude end
    local txt = el.nm
    if pressT and t - pressT >= C.charge.time then txt = txt .. " ⚡ЗАРЯД" end
    ui.crossLabel.Text = txt .. "  •  " .. math.floor(dist) .. " st"
    for _, l in ipairs(ui.lines) do l.BackgroundColor3 = el.col end
    if t < hitMarkerUntil then
      ui.hitStroke.Transparency = 0
      ui.hitStroke.Color = C3(255, 60, 60)
      local s = (hitMarkerUntil - t) / 0.18
      ui.hitRing.Size = UDim2.fromOffset(80 + (1 - s) * 30, 80 + (1 - s) * 30)
    else
      ui.hitStroke.Transparency = 1
      ui.hitRing.Size = UDim2.fromOffset(80, 80)
    end
  end
  local key = comboKey()
  if key and cdLeft("combo") <= 0 then
    local a, b = key:match("^(%w+)%+(%w+)$")
    local ia, ib = IDX[a], IDX[b]
    if ia and ib then
      ui.pairLbl.Text = "⚡ КОМБО ГОТОВО: " .. EL[ia].ic .. " + " .. EL[ib].ic
      ui.pairLbl.Visible = true
    end
  else
    ui.pairLbl.Visible = false
  end
  local ready = key ~= nil and cdLeft("combo") <= 0
  ui.combo.TextColor3 = ready and C3(255, 240, 120) or C3(150, 150, 160)
  ui.comboStroke.Thickness = ready and (2 + math.abs(math.sin(t * 4)) * 2) or 1
  if ui.fireBtn then ui.fireBtn.Text = el.ic end
  if t > toastUntil then ui.toast.Visible = false end
end

-- ===== Ввод ПК =====
connect(UIS.InputBegan, function(i, gp)
  if not alive then return end
  local ut = i.UserInputType
  if ut == Enum.UserInputType.Keyboard then
    if gp then return end
    local k = i.KeyCode
    local n = KEYN[k]
    if n and not hidden[EL[n].id] then A.setCurrent(EL[n].id)
    elseif k == Enum.KeyCode.Q then A.prev()
    elseif k == Enum.KeyCode.E then A.next()
    elseif k == Enum.KeyCode.R then A.alt()
    elseif k == Enum.KeyCode.F then A.combo()
    elseif k == Enum.KeyCode.LeftShift then shiftHeld = true end
  elseif ut == Enum.UserInputType.MouseButton1 then
    if not gp then pressDown() end
  elseif ut == Enum.UserInputType.MouseButton2 then
    if not gp then A.aim(true) end
  end
end)
connect(UIS.InputEnded, function(i)
  if not alive then return end
  local ut = i.UserInputType
  if ut == Enum.UserInputType.Keyboard then
    if i.KeyCode == Enum.KeyCode.LeftShift then shiftHeld = false end
  elseif ut == Enum.UserInputType.MouseButton1 then pressUp()
  elseif ut == Enum.UserInputType.MouseButton2 then aiming = false end
end)
local lastTap, lastTapPos = 0, nil
connect(UIS.TouchTapInWorld, function(pos, processed)
  if processed or not alive then return end
  local t = tick()
  if lastTapPos and t - lastTap < 0.3 and (pos - lastTapPos).Magnitude < 80 then
    lastTap, lastTapPos = 0, nil
    centerOnce = true
    A.fire(false)
    centerOnce = false
  else
    lastTap, lastTapPos = t, pos
  end
end)

-- ===== Главный цикл =====
local uiAcc, slowAcc = 0, 0
connect(RS.Heartbeat, function(dt)
  if not alive then return end
  local t = tick()
  stepProj(dt)
  if (waterHeld and A.current == "water") or t < waterUntil then waterTick(dt) end
  for i = #dots, 1, -1 do
    local d = dots[i]
    if t >= d.endt or not d.e.hum.Parent or d.e.hum.Health <= 0 then table.remove(dots, i)
    else dmg(d.e, d.dps * dt) end
  end
  for i = #clouds, 1, -1 do
    local cl = clouds[i]
    if t >= cl.endt then
      pcall(function() cl.part:Destroy() end)
      table.remove(clouds, i)
    elseif cl.dps > 0 then
      for _, e in ipairs(near(cl.pos, cl.r)) do dmg(e, cl.dps * dt) end
    end
  end
  -- восстановление врагов (НЕ игрока)
  for hum, s in pairs(slows) do
    if t >= s.endt or not hum.Parent then
      pcall(function() if hum.Parent then hum.WalkSpeed = s.orig end end)
      slows[hum] = nil
    end
  end
  -- aim НЕ замедляет — этой строки больше нет
  for hum, ts in pairs(hitWatch) do
    if hum.Parent and hum.Health <= 0 then
      hitWatch[hum] = nil
      if t - ts < 6 then smStart() end
    elseif not hum.Parent or t - ts > 6 then hitWatch[hum] = nil end
  end
  smStep()
  uiAcc = uiAcc + dt
  if uiAcc >= 0.06 then uiAcc = 0; refreshUI() end
  slowAcc = slowAcc + dt
  if slowAcc >= 1 then
    slowAcc = 0
    wrapHelper()
    if not getChar() then waterHeld = false; pressT = nil end
  end
end)

-- ===== Очистка =====
function A.destroy()
  if not alive then return end
  alive = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  conns = {}
  for hum, s in pairs(slows) do pcall(function() hum.WalkSpeed = s.orig end) end
  slows = {}
  smEnd()
  if helperWrapped and ORBIT.helper and origInterp then pcall(function() ORBIT.helper.interpret = origInterp end) end
  if ui.sg then pcall(function() ui.sg:Destroy() end) end
  ui = {}
  for _, q in ipairs(A.projectiles) do pcall(function() q.part:Destroy() end) end
  A.projectiles = {}
  for _, cl in ipairs(clouds) do pcall(function() cl.part:Destroy() end) end
  clouds, dots, hitWatch, lastFire = {}, {}, {}, {}
  A.cooldowns = {}
  if folder then pcall(function() folder:Destroy() end); folder = nil end
  ORBIT.abilityMoveUntil = 0
end
local okUi, errUi = pcall(mkUI)
if not okUi then warn("[ORBIT] abilities UI: " .. tostring(errUi)) end
ORBIT.abilities = A
ORBIT.abilityMoveUntil = 0
ORBIT.loaded.abilities = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(A.destroy)
  if prevUnload then pcall(prevUnload) end
end
return true
