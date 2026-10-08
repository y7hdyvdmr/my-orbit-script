-- ORBIT v24.0 | orbit_death_fx.lua
-- Белое сердце при смерти: всплывает, разбивается, остаётся красный шрам
local G = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = G.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] deathFx: нет ORBIT"); return false end
if ORBIT.deathFx and ORBIT.deathFx.destroy then pcall(ORBIT.deathFx.destroy) end
ORBIT.loaded = ORBIT.loaded or {}
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local D = { _lastCall = 0 }
local alive, conn, folder = true, nil, nil
local active = {}
local PIX = { "0110110", "1111111", "1111111", "0111110", "0011100", "0001000" }
local function fold()
  if folder and folder.Parent then return folder end
  folder = Instance.new("Folder"); folder.Name = "OrbitDeathFx_" .. LP.UserId; folder.Parent = WS
  return folder
end
local function sfx(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end
local function mark(inst)
  for _, d in ipairs(inst:GetDescendants()) do
    if d:IsA("BasePart") then d:SetAttribute("NoRecolor", true); d.CanQuery = false; d.CanTouch = false end
  end
end
-- запасное сердце, если ORBIT.createPixelHeart ещё не загружен
local function ownHeart(size, color, name)
  local m = Instance.new("Model"); m.Name = name
  local root = Instance.new("Part")
  root.Name = "Root"; root.Size = V3(0.1, 0.1, 0.1); root.Transparency = 1
  root.Anchored = true; root.CanCollide = false; root.Parent = m; m.PrimaryPart = root
  local s = size / 7
  local bodies = {}
  for r = 1, #PIX do
    for c = 1, 7 do
      if PIX[r]:sub(c, c) == "1" then
        local p = Instance.new("Part")
        p.Name = "P"; p.Size = V3(s, s, s * 0.6); p.CFrame = CF((c - 4) * s, (3.5 - r) * s, 0)
        p.Anchored = true; p.CanCollide = false; p.CastShadow = false
        p.Material = Enum.Material.Neon; p.Color = color; p.Parent = m
        table.insert(bodies, p)
      end
    end
  end
  return m, root, bodies
end
local function makeHeart(size, color, name)
  if ORBIT.createPixelHeart then
    local ok, m, r, b = pcall(ORBIT.createPixelHeart, size, color, name)
    if ok and m then return m, r, b end
  end
  return ownHeart(size, color, name)
end
local function shatter(fx)
  fx.broken = true
  local pos = fx.base
  pcall(function() fx.model:Destroy() end); fx.model = nil
  local f = fold()
  for i = 1, 5 do
    local s = Instance.new("Part")
    s.Name = "Shard"; s.Size = V3(0.9 + math.random() * 0.8, 1.2, 0.4)
    s.Color = C3(255, 255, 255); s.Material = Enum.Material.Neon
    s.Anchored = false; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false; s.CastShadow = false
    s.CFrame = CF(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
    s:SetAttribute("NoRecolor", true); s.Parent = f
    local a = i / 5 * math.pi * 2
    s.AssemblyLinearVelocity = V3(math.cos(a) * 14, 10 + math.random() * 8, math.sin(a) * 14)
    s.AssemblyAngularVelocity = V3(math.random() * 10, math.random() * 10, math.random() * 10)
    Debris:AddItem(s, 2.5)
  end
  local sp = Instance.new("Part")
  sp.Name = "Sparks"; sp.Anchored = true; sp.CanCollide = false; sp.CanQuery = false; sp.Transparency = 1
  sp.Size = V3(0.2, 0.2, 0.2); sp.Position = pos; sp.Parent = f
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(C3(255, 40, 60)); e.LightEmission = 1
  e.Size = NumberSequence.new(0.5, 0); e.Lifetime = NumberRange.new(0.6, 1.2)
  e.Speed = NumberRange.new(10, 22); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0; e.Parent = sp
  e:Emit(40)
  Debris:AddItem(sp, 2)
  local sm = makeHeart(1.1, C3(220, 20, 40), "DeathScar")
  sm.Parent = f; mark(sm)
  pcall(function() sm:PivotTo(CF(pos)) end)
  fx.scar = sm
  fx.scarParts = {}
  for _, d in ipairs(sm:GetDescendants()) do
    if d:IsA("BasePart") and d.Transparency < 1 then table.insert(fx.scarParts, d) end
  end
  sfx("ping", 1, 1.9)
end
local function step(dt)
  local t = tick()
  for i = #active, 1, -1 do
    local fx = active[i]
    local el = t - fx.t0
    if el >= 5 then
      pcall(function() if fx.model then fx.model:Destroy() end end)
      pcall(function() if fx.scar then fx.scar:Destroy() end end)
      table.remove(active, i)
    else
      if not fx.broken then
        if el < 1 then
          pcall(function()
            fx.model:PivotTo(CF(fx.base + V3(0, 0.5 * el, 0)))
            fx.model:ScaleTo(1 + 0.05 * math.sin(el * 12))
          end)
        else
          fx.base = fx.base + V3(0, 0.5, 0)
          shatter(fx)
        end
      elseif fx.scarParts and el > 4 then
        local k = math.clamp(el - 4, 0, 1)
        for _, p in ipairs(fx.scarParts) do pcall(function() p.Transparency = k end) end
      end
      if not fx.laughed and el >= 0.5 then fx.laughed = true; sfx("laugh", 0.5, 0.9) end
    end
  end
  if #active == 0 and conn then conn:Disconnect(); conn = nil end
end
function D.play(pos)
  if not alive then return false end
  local t = tick()
  if t - D._lastCall < 3 then return false end
  D._lastCall = t
  if typeof(pos) == "CFrame" then pos = pos.Position end
  if typeof(pos) ~= "Vector3" then pos = V3(0, 5, 0) end
  local base = pos + V3(0, 4, 0)
  local model = makeHeart(6, C3(255, 255, 255), "DeathHeart")
  model.Parent = fold(); mark(model)
  pcall(function() model:PivotTo(CF(base)) end)
  local text
  local S = ORBIT.sans
  if S then
    if S.lastCat == "death" and t - (S.lastCatTime or 0) < 2 then text = S.lastSaid
    elseif S.say then text = S.say("death", true) end
  end
  text = text or "Хех, Папирус, прости меня..."
  if S and S.showAt then pcall(S.showAt, base + V3(0, 4, 0), text, 4) end
  sfx("ping", 1, 1.4)
  active[#active + 1] = { t0 = t, model = model, base = base, broken = false }
  if not conn then conn = RS.Heartbeat:Connect(step) end
  return true
end
function D.destroy()
  alive = false
  if conn then pcall(function() conn:Disconnect() end); conn = nil end
  active = {}
  if folder then pcall(function() folder:Destroy() end); folder = nil end
  D._lastCall = 0
end
ORBIT.deathFx = D
ORBIT.loaded.deathfx = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(D.destroy)
  if prevUnload then pcall(prevUnload) end
end
return true
