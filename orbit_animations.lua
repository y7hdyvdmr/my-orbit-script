-- ORBIT v24.0 | orbit_animations.lua
-- Анимации фигур и игрока. Один Heartbeat на всё.
-- v24.0-fix1: R6/R15 проверка рига в P.laugh и P.greet (в P.dance уже была).
-- КОНТРАКТ ИМЁН ЧАСТЕЙ (core называет детали так, фронт фигуры = -Z, верх = +Y):
--   ДРАКОН: WingL*/WingR*, Tail1..N, Head*   ФЛАУИ: Head*, Petal*   ОМЕГА: Screen*, Vine*
--   ГЛАЗ: Lid*, Pupil*   МЕЧ: Blade*   ЩИТ: Crack*   КРЫЛЬЯ: Feather<слой>_*   ЧЕРЕП: EyeL/EyeR
--   ИНЬ-ЯН: Dot*   ФЕНИКС: Flame<слой>   ПОРТАЛ: Disk*, Ring
local G = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = G.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] animations: нет ORBIT"); return false end
if ORBIT.animations and ORBIT.animations.destroy then pcall(ORBIT.animations.destroy) end
ORBIT.loaded = ORBIT.loaded or {}
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local rad, sin, pi = math.rad, math.sin, math.pi
local A = {}
local alive = true
local list, REG, DEFS = {}, {}, {}
local attached = setmetatable({}, { __mode = "k" })
local wrappers = setmetatable({}, { __mode = "k" })
local conn, hpConn, charConn, folder = nil, nil, nil, nil
local dmgT, hpRatio = 0, 1
local lastDodge = 0
local function ping(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end
local function fold()
  if folder and folder.Parent then return folder end
  folder = Instance.new("Folder"); folder.Name = "OrbitSfx_Anim"; folder.Parent = WS
  return folder
end
-- ===== Хелперы частей =====
local function rootOf(fig) return (fig.model and fig.model.PrimaryPart) or fig.part end
local function grab(model, prefix)
  local out, root = {}, model.PrimaryPart
  if not root then return out end
  for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") and d ~= root and d.Name:sub(1, #prefix) == prefix then
      out[#out + 1] = { p = d, rel = root.CFrame:ToObjectSpace(d.CFrame) }
    end
  end
  table.sort(out, function(a, b) return (tonumber(a.p.Name:match("%d+")) or 0) < (tonumber(b.p.Name:match("%d+")) or 0) end)
  return out
end
local function grabAll(model)
  local out, root = {}, model.PrimaryPart
  if not root then return out end
  for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") and d ~= root then out[#out + 1] = { p = d, rel = root.CFrame:ToObjectSpace(d.CFrame) } end
  end
  return out
end
local function scaleF(fig, data)
  local ok, s = pcall(function() return fig.model:GetScale() end)
  if ok and data.s0 and data.s0 > 0 then return s / data.s0 end
  return 1
end
local function put(root, e, pre, post, f)
  local rel = e.rel
  local cf = root.CFrame * pre * CF(rel.Position * f) * rel.Rotation
  e.p.CFrame = post and (cf * post) or cf
end
local function around(pv, R, f) return CF(pv * f) * R * CF(-pv * f) end
local function sgn(x) return x < 0 and -1 or 1 end
local function lpRoot()
  local c = LP.Character
  return c and c:FindFirstChild("HumanoidRootPart")
end
local I = CFrame.new()
-- ===== Определения анимаций =====
DEFS.wings = {
  init = function(fig, d) d.L = grab(fig.model, "WingL"); d.R = grab(fig.model, "WingR") end,
  tick = function(dt, fig, d, t)
    local root, f = d.root, scaleF(fig, d)
    local a = sin(t * 2 * pi / 1.2)
    for _, set in ipairs({ d.L, d.R }) do
      for _, e in ipairs(set) do
        local s = sgn(e.rel.Position.X)
        put(root, e, CFrame.Angles(0, rad(15) * a * s, rad(10) * a * s), nil, f)
      end
    end
  end,
}
DEFS.tail = {
  init = function(fig, d) d.T = grab(fig.model, "Tail") end,
  tick = function(dt, fig, d, t)
    local n = #d.T
    if n == 0 then return end
    local f = scaleF(fig, d)
    local pv = d.T[1].rel.Position
    for i, e in ipairs(d.T) do
      local th = rad(10) * sin(t * 2.2 - i * 0.6) * (i / n)
      put(d.root, e, around(pv, CFrame.Angles(0, th, 0), f), nil, f)
    end
  end,
}
DEFS.headTrack = {
  init = function(fig, d)
    d.H = grab(fig.model, "Head"); d.yaw = 0
    d.pv = d.H[1] and d.H[1].rel.Position or V3()
    for _, e in ipairs(d.H) do if e.p.Name == "Head" then d.pv = e.rel.Position end end
  end,
  tick = function(dt, fig, d, t)
    if #d.H == 0 then return end
    local pr = lpRoot()
    local f = scaleF(fig, d)
    if pr then
      local v = d.root.CFrame:PointToObjectSpace(pr.Position)
      local tg = math.clamp(math.atan2(-v.X, -v.Z), -0.6, 0.6)
      d.yaw = d.yaw + (tg - d.yaw) * math.min(1, dt * 4)
    end
    local pre = around(d.pv, CFrame.Angles(0, d.yaw, 0), f)
    for _, e in ipairs(d.H) do put(d.root, e, pre, nil, f) end
  end,
}
DEFS.nod = {
  init = function(fig, d) d.H = grab(fig.model, "Head") end,
  tick = function(dt, fig, d, t)
    local f = scaleF(fig, d)
    local post = CFrame.Angles(rad(8) * sin(t * 2 * pi / 2.4), 0, 0)
    for _, e in ipairs(d.H) do put(d.root, e, I, post, f) end
  end,
}
DEFS.petals = {
  init = function(fig, d)
    d.P = grab(fig.model, "Petal"); d.hp = V3()
    for _, e in ipairs(grab(fig.model, "Head")) do if e.p.Name == "Head" then d.hp = e.rel.Position end end
  end,
  tick = function(dt, fig, d, t)
    local f = scaleF(fig, d)
    local b = 1 + 0.06 * sin(t * 2.4)
    for _, e in ipairs(d.P) do
      local pos = d.hp + (e.rel.Position - d.hp) * b
      e.p.CFrame = d.root.CFrame * (CF(pos * f) * e.rel.Rotation)
    end
  end,
}
DEFS.tv = {
  init = function(fig, d) d.S = grab(fig.model, "Screen"); d.nextT = 0; d.val = 0.1 end,
  tick = function(dt, fig, d, t)
    if t >= d.nextT then d.val = 0.05 + math.random() * 0.10; d.nextT = t + 0.06 + math.random() * 0.08 end
    for _, e in ipairs(d.S) do e.p.Transparency = d.val end
  end,
}
DEFS.vines = {
  init = function(fig, d) d.V = grab(fig.model, "Vine") end,
  tick = function(dt, fig, d, t)
    local f = scaleF(fig, d)
    for i, e in ipairs(d.V) do
      local th = rad(6) * sin(t * 1.8 + i * 0.9) * sgn(e.rel.Position.X)
      put(d.root, e, CFrame.Angles(0, 0, th), nil, f)
    end
  end,
}
DEFS.heartbeat = {
  init = function(fig, d) d.phase = 0 end,
  tick = function(dt, fig, d, t)
    local per = hpRatio < 0.3 and 0.4 or 0.8
    d.phase = d.phase + dt * 2 * pi / per
    local s = 1 + 0.05 * (0.5 + 0.5 * sin(d.phase))
    pcall(function() fig.model:ScaleTo(d.s0 * s) end)
  end,
}
DEFS.eye = {
  init = function(fig, d)
    d.Lid = grab(fig.model, "Lid"); d.Pu = grab(fig.model, "Pupil")
    d.nextBlink = tick() + 3 + math.random() * 2; d.blinkEnd = 0; d.off = V3()
    d.k = 0.08 * (fig.visualSize or 2)
    for _, e in ipairs(d.Lid) do e.p.Transparency = 1 end
  end,
  tick = function(dt, fig, d, t)
    if t >= d.nextBlink then d.blinkEnd = t + 0.15; d.nextBlink = t + 3 + math.random() * 2 end
    local closed = t < d.blinkEnd
    for _, e in ipairs(d.Lid) do e.p.Transparency = closed and 0 or 1 end
    local cm = WS.CurrentCamera
    if cm and #d.Pu > 0 then
      local v = d.root.CFrame:VectorToObjectSpace(cm.CFrame.Position - d.root.Position)
      if v.Magnitude > 0.01 then v = v.Unit end
      d.off = d.off:Lerp(V3(v.X, v.Y, 0) * d.k, math.min(1, dt * 8))
      local f = scaleF(fig, d)
      for _, e in ipairs(d.Pu) do
        e.p.CFrame = d.root.CFrame * (CF((e.rel.Position + d.off) * f) * e.rel.Rotation)
      end
    end
  end,
}
local function mkSpin(per, axis)
  return {
    init = function(fig, d) d.all = grabAll(fig.model); d.skip = false end,
    tick = function(dt, fig, d, t)
      if #d.all > 120 then d.skip = not d.skip; if d.skip then return end end
      local ang = (t * 2 * pi / per) % (2 * pi)
      local pre = axis == "Z" and CFrame.Angles(0, 0, ang) or CFrame.Angles(0, ang, 0)
      local f = scaleF(fig, d)
      for _, e in ipairs(d.all) do put(d.root, e, pre, nil, f) end
    end,
  }
end
DEFS.spin2 = mkSpin(2, "Y")
DEFS.spinStar = mkSpin(6, "Z")
DEFS.sway = {
  init = function(fig, d) d.all = grabAll(fig.model) end,
  tick = function(dt, fig, d, t)
    local pre = CFrame.Angles(rad(4) * sin(t * 1.5), 0, rad(3) * sin(t * 1.1))
    local f = scaleF(fig, d)
    for _, e in ipairs(d.all) do put(d.root, e, pre, nil, f) end
  end,
}
DEFS.swordGlow = {
  init = function(fig, d) d.B = grab(fig.model, "Blade"); d.orig = {}; d.hot = false end,
  tick = function(dt, fig, d, t)
    local ts = ORBIT.abilityLastTime or 0
    local hot = ORBIT.abilityLast == "fire" and t - ts < 0.6
    if hot then
      if not d.hot then
        d.hot = true
        for _, e in ipairs(d.B) do d.orig[e.p] = e.p.Color end
      end
      local k = 1 - (t - ts) / 0.6
      for _, e in ipairs(d.B) do
        local o = d.orig[e.p]
        if o then e.p.Color = o:Lerp(C3(255, 140, 40), k) end
      end
    elseif d.hot then
      d.hot = false
      for _, e in ipairs(d.B) do
        local o = d.orig[e.p]
        if o then e.p.Color = o end
      end
    end
  end,
  cleanup = function(fig, d)
    if d.hot then for _, e in ipairs(d.B) do local o = d.orig[e.p]; if o then pcall(function() e.p.Color = o end) end end end
  end,
}
DEFS.shieldFlash = {
  init = function(fig, d) d.K = grab(fig.model, "Crack"); for _, e in ipairs(d.K) do e.p.Transparency = 1 end end,
  tick = function(dt, fig, d, t)
    local k = math.clamp(1 - (t - dmgT) / 0.8, 0, 1)
    for _, e in ipairs(d.K) do e.p.Transparency = 1 - 0.9 * k end
  end,
}
DEFS.feathers = {
  init = function(fig, d) d.F = grab(fig.model, "Feather") end,
  tick = function(dt, fig, d, t)
    local f = scaleF(fig, d)
    for _, e in ipairs(d.F) do
      local layer = tonumber(e.p.Name:match("Feather(%d+)")) or 1
      local th = rad(5) * sin(t * 2.2 - layer * 0.8) * sgn(e.rel.Position.X)
      put(d.root, e, CFrame.Angles(0, 0, th), nil, f)
    end
  end,
}
DEFS.skullEyes = {
  init = function(fig, d)
    d.E = grab(fig.model, "Eye"); d.lights = {}
    for _, e in ipairs(d.E) do
      local l = Instance.new("PointLight")
      l.Name = "_AnimLight"; l.Range = 6; l.Brightness = 0.7; l.Color = C3(255, 120, 60); l.Parent = e.p
      d.lights[#d.lights + 1] = l
    end
  end,
  tick = function(dt, fig, d, t)
    local S = ORBIT.sans
    local hot = (t - (ORBIT.abilityLastTime or 0) < 0.5) or (S and S.lastCat == "attack" and t - (S.lastCatTime or 0) < 1)
    local target = hot and 3 or (0.7 + 0.2 * sin(t * 2))
    for _, l in ipairs(d.lights) do l.Brightness = l.Brightness + (target - l.Brightness) * math.min(1, dt * 10) end
  end,
  cleanup = function(fig, d) for _, l in ipairs(d.lights or {}) do pcall(function() l:Destroy() end) end end,
}
DEFS.yin = {
  init = function(fig, d) d.D = grab(fig.model, "Dot") end,
  tick = function(dt, fig, d, t)
    local f = scaleF(fig, d)
    local pre = CFrame.Angles(0, 0, t * pi)
    for _, e in ipairs(d.D) do put(d.root, e, pre, nil, f) end
  end,
}
DEFS.flames = {
  init = function(fig, d) d.F = grab(fig.model, "Flame") end,
  tick = function(dt, fig, d, t)
    local f = scaleF(fig, d)
    for _, e in ipairs(d.F) do
      local layer = tonumber(e.p.Name:match("Flame(%d+)")) or 1
      put(d.root, e, CFrame.Angles(0, rad(10) * sin(t * 3 - layer * 0.9), 0), nil, f)
    end
  end,
}
DEFS.portal = {
  init = function(fig, d)
    d.D = grab(fig.model, "Disk"); d.fx = {}
    for _, e in ipairs(grab(fig.model, "Ring")) do
      local pe = Instance.new("ParticleEmitter")
      pe.Name = "_AnimSparks"; pe.Color = ColorSequence.new(C3(190, 120, 255)); pe.LightEmission = 1
      pe.Size = NumberSequence.new(0.25, 0); pe.Lifetime = NumberRange.new(0.4, 0.8)
      pe.Speed = NumberRange.new(2, 4); pe.SpreadAngle = Vector2.new(180, 180); pe.Rate = 25; pe.Parent = e.p
      d.fx[#d.fx + 1] = pe
    end
  end,
  tick = function(dt, fig, d, t)
    local f = scaleF(fig, d)
    local pre = CFrame.Angles(0, 0, (t * 2 * pi / 1.5) % (2 * pi))
    for _, e in ipairs(d.D) do put(d.root, e, pre, nil, f) end
  end,
  cleanup = function(fig, d) for _, p in ipairs(d.fx or {}) do pcall(function() p:Destroy() end) end end,
}
-- ===== Реестр: имя фигуры (SHAPE_PRESETS) -> список анимаций =====
REG["ДРАКОН"] = { "wings", "tail", "headTrack" }
REG["ЦВЕТОК ФЛАУИ"] = { "nod", "petals" }
REG["ОМЕГА ФЛАУИ"] = { "tv", "vines" }
REG["СЕРДЦЕ"] = { "heartbeat" }
REG["ГЛАЗ"] = { "eye" }
REG["СПИРАЛЬ"] = { "spin2" }
REG["МЕЧ"] = { "swordGlow" }
REG["ЩИТ"] = { "shieldFlash" }
REG["КРЫЛЬЯ"] = { "feathers" }
REG["ЧЕРЕП"] = { "skullEyes" }
REG["ЗВЕЗДА"] = { "spinStar" }
REG["ИНЬ-ЯН"] = { "yin" }
REG["КОРОНА"] = { "sway" }
REG["ФЕНИКС"] = { "flames" }
REG["ПОРТАЛ"] = { "portal" }
-- ===== API =====
local function norm(fig)
  if type(fig) == "table" then return fig.model and fig or nil end
  if typeof(fig) == "Instance" and fig:IsA("Model") then
    local w = wrappers[fig]
    if not w then w = { model = fig, part = fig.PrimaryPart, isModel = true, visualSize = 2 }; wrappers[fig] = w end
    return w
  end
  return nil
end
function A.play(fig, name)
  if not alive then return false end
  fig = norm(fig)
  local def = DEFS[name]
  if not fig or not def then return false end
  for _, e in ipairs(list) do if e.fig == fig and e.name == name then return true end end
  local root = rootOf(fig)
  if not root or not fig.model then return false end
  local data = { s0 = 1, root = root }
  pcall(function() data.s0 = fig.model:GetScale() end)
  local ok, err = pcall(def.init, fig, data)
  if not ok then warn("[ORBIT] anim " .. name .. ": " .. tostring(err)); return false end
  list[#list + 1] = { fig = fig, name = name, def = def, data = data }
  return true
end
function A.stop(fig, name)
  fig = norm(fig)
  if not fig then return false end
  local found = false
  for i = #list, 1, -1 do
    local e = list[i]
    if e.fig == fig and (name == nil or e.name == name) then
      if e.def.cleanup then pcall(e.def.cleanup, fig, e.data) end
      table.remove(list, i); found = true
    end
  end
  return found
end
function A.register(figName, animList) REG[figName] = animList end
function A.attach(block, figName)
  local reg = REG[figName]
  if not reg or attached[block] then return false end
  attached[block] = true
  for _, an in ipairs(reg) do A.play(block, an) end
  return true
end
local function scan()
  local rings = ORBIT.rings
  local presets = ORBIT.SHAPE_PRESETS
  if type(rings) ~= "table" or type(presets) ~= "table" then return end
  for _, r in pairs(rings) do
    if type(r) == "table" and r.blocks and r.enabled ~= false then
      local pr = presets[r.shapeIndex or ORBIT.shapeIndex or 1]
      local reg = pr and REG[pr.name]
      if reg then
        for _, b in ipairs(r.blocks) do
          if type(b) == "table" and b.isModel and b.model and not attached[b] then A.attach(b, pr.name) end
        end
      end
    end
  end
end
-- ===== Проверка рига R6 / R15 =====
local function rigOf(hum)
  if not hum then return "R15" end
  return (hum.RigType == Enum.HumanoidRigType.R15) and "R15" or "R6"
end
local function isR15(hum)
  return rigOf(hum) == "R15"
end
-- ===== Анимации игрока =====
local P = {}
local function hum()
  local c = LP.Character
  if not c then return nil end
  return c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart"), c
end
local function stopEmote(h)
  pcall(function()
    local an = h:FindFirstChildOfClass("Animator")
    if not an then return end
    for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
      if tr.Priority == Enum.AnimationPriority.Action then tr:Stop(0.2) end
    end
  end)
end
local function say(text, sec)
  local h, r = hum()
  local head = LP.Character and LP.Character:FindFirstChild("Head")
  if head and ORBIT.sans and ORBIT.sans.showAt then pcall(ORBIT.sans.showAt, head.Position + V3(0, 2, 0), text, sec or 2.5) end
end
function P.dance()
  local h = hum()
  if not h then return false end
  if ORBIT.emote and ORBIT.emote("dance") then return true end
  local names = isR15(h) and { "dance", "dance2", "dance3" } or { "dance" }
  local ok, res = pcall(function() return h:PlayEmote(names[math.random(#names)]) end)
  return ok and res and true or false
end
function P.laugh()
  local h = hum()
  if not h then return false end
  ping("laugh", 1, 1)
  if ORBIT.emote and ORBIT.emote("laugh") then return true end
  -- R6: laugh есть и на R6, но с другим набором анимаций. Пробуем оба.
  local ok, res = pcall(function() return h:PlayEmote("laugh") end)
  if not ok or not res then
    -- запасной вариант для R6: используем "cheer" (обычно есть)
    pcall(function() h:PlayEmote("cheer") end)
  end
  task.delay(2, function() if alive then stopEmote(h) end end)
  return true
end
function P.greet()
  local h = hum()
  if not h then return false end
  say("привет!", 2.5)
  if ORBIT.emote and ORBIT.emote("greet") then return true end
  -- wave есть и на R6, и на R15
  local ok, res = pcall(function() return h:PlayEmote("wave") end)
  return ok and res and true or false
end
function P.sans()
  if ORBIT.sans and ORBIT.sans.say then return ORBIT.sans.say("random", true) end
  return nil
end
function P.dodge(side)
  local h, r, c = hum()
  if not h or h.Health <= 0 or not r then return false end
  local now = tick()
  if now - lastDodge < 0.8 then return false end
  lastDodge = now
  side = side or (math.random() < 0.5 and 1 or -1)
  local dirv = r.CFrame.RightVector * side
  local from = r.Position
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { c, fold() }
  local res = WS:Raycast(from, dirv * 6, rp)
  local d = (res and res.Instance.CanCollide) and math.max(0, (res.Position - from).Magnitude - 2) or 6
  if d < 0.5 then return false end
  ORBIT.abilityMoveUntil = tick() + 1
  local to = from + dirv * d
  local tr = Instance.new("Part")
  tr.Name = "_DodgeTrail"; tr.Anchored = true; tr.CanCollide = false; tr.CanQuery = false; tr.CanTouch = false
  tr.Material = Enum.Material.Neon; tr.Color = C3(255, 255, 255); tr.Transparency = 0.2
  tr.Size = V3(0.8, 2.5, d); tr.CFrame = CFrame.lookAt((from + to) / 2, to); tr.Parent = fold()
  pcall(function() TS:Create(tr, TweenInfo.new(0.3), { Transparency = 1 }):Play() end)
  game:GetService("Debris"):AddItem(tr, 0.4)
  r.CFrame = CF(to) * (r.CFrame - r.CFrame.Position)
  ping("dodge", 1, 1)
  return true
end
A.player = P
A.rigOf = rigOf
A.isR15 = isR15
-- ===== Слежение за HP (сердце, щит) =====
local function hook(char)
  if hpConn then pcall(function() hpConn:Disconnect() end); hpConn = nil end
  local h = char:WaitForChild("Humanoid", 5)
  if not h or not alive then return end
  -- запоминаем риг
  ORBIT.RigType = rigOf(h)
  local last = h.Health
  hpRatio = h.MaxHealth > 0 and h.Health / h.MaxHealth or 1
  hpConn = h.HealthChanged:Connect(function(hp)
    if hp < last - 0.01 then dmgT = tick(); ORBIT.lastDamageTime = dmgT end
    last = hp
    hpRatio = h.MaxHealth > 0 and hp / h.MaxHealth or 1
  end)
end
if LP.Character then task.spawn(hook, LP.Character) end
charConn = LP.CharacterAdded:Connect(function(ch) task.spawn(hook, ch) end)
-- ===== Главный цикл =====
local scanAcc = 0
conn = RS.Heartbeat:Connect(function(dt)
  if not alive then return end
  local t = tick()
  scanAcc = scanAcc + dt
  if scanAcc >= 0.5 then scanAcc = 0; scan() end
  for i = #list, 1, -1 do
    local e = list[i]
    local fig, root = e.fig, e.data.root
    if not fig.model or not fig.model.Parent or not root or not root.Parent then
      if e.def.cleanup then pcall(e.def.cleanup, fig, e.data) end
      table.remove(list, i)
    else
      local ok, err = pcall(e.def.tick, dt, fig, e.data, t)
      if not ok then
        warn("[ORBIT] anim " .. e.name .. ": " .. tostring(err))
        pcall(function() if e.def.cleanup then e.def.cleanup(fig, e.data) end end)
        table.remove(list, i)
      end
    end
  end
end)
function A.destroy()
  if not alive then return end
  alive = false
  if conn then pcall(function() conn:Disconnect() end); conn = nil end
  if hpConn then pcall(function() hpConn:Disconnect() end); hpConn = nil end
  if charConn then pcall(function() charConn:Disconnect() end); charConn = nil end
  for _, e in ipairs(list) do
    if e.def.cleanup then pcall(e.def.cleanup, e.fig, e.data) end
  end
  list = {}
  if folder then pcall(function() folder:Destroy() end); folder = nil end
end
ORBIT.animations = A
ORBIT.loaded.animations = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(A.destroy)
  if prevUnload then pcall(prevUnload) end
end
return true
