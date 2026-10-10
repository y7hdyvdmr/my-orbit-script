1-- ORBIT v24.9 | orbit_gaster.lua
-- Мини-игра «Собери Гастера»: 16 осколков + 5 ловушек + босс-файт (3 фазы, 4 атаки).
-- v24.9: возвращены 16 осколков и ловушки, белая палитра, «✖ СКРЫТЬ» прячет UI
--        без сброса, W.update(dt) вызывается из Heartbeat (иначе оружие не работало),
--        орбитальный Гастер стреляет в босса. Совмещено с новой системой босса.

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

-- Белая палитра
local COL_BEAM   = C3(255, 255, 255)
local COL_CHARGE = C3(240, 250, 255)
local COL_GLOW   = C3(230, 240, 255)
local COL_TRAP   = C3(220, 80, 255)

local G = {
  active = false,
  state = "idle",       -- idle / collecting / boss / won
  parts = {},
  traps = {},
  figure = nil,
  collector = { collected = 0, total = 16 },
  heartbeat = nil,
  ui = nil,
  uiHidden = false,
  timer = 120,
  shapeRegistered = false,
}
local alive, folder, token = true, nil, 0
local helperWrapped, origInterp = false, nil
local W, bossStep = nil, nil

local B = {
  active = false, run = 0, phase = 1, hp = 1000, maxHp = 1000, wins = 0,
  busy = false, hold = false, scale = 9, hitR = 8, safe = false, dmgScale = 1,
  hurtUntil = 0, lastFlash = 0, invUntil = 0, riseUntil = 0, nextAttack = 0,
  angle = 0, lastAtk = nil,
  dmg = { blaster = 24, lightning = 16, hand = 28, nova = 38 },
}
G.boss = B

-- ===== 16 ОСКОЛКОВ =====
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

-- ===== БЕЛЫЙ ГАСТЕР =====
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
  local model, root = shell(name or "Gaster")
  local bodies = {}
  local bone, black, white = C3(250, 245, 235), C3(10, 10, 14), C3(255, 255, 255)
  local function add(n, sz, cf, col, mat, nr, tr)
    local p = mkp(model, n, sz, cf, col, mat, nr, tr)
    table.insert(bodies, p)
    return p
  end
  add("Skull", V3(0.9 * s, 0.8 * s, 1.0 * s), CF(0, 0.15 * s, 0.25 * s), bone)
  add("Brow", V3(0.95 * s, 0.18 * s, 0.5 * s), CF(0, 0.55 * s, -0.15 * s), bone)
  for _, sd in ipairs({ -1, 1 }) do
    add("Cheek", V3(0.12 * s, 0.5 * s, 0.8 * s), CF(sd * 0.5 * s, 0.05 * s, 0.05 * s) * CFrame.Angles(0, 0, math.rad(8) * sd), bone)
    add("Horn", V3(0.14 * s, 0.9 * s, 0.18 * s), CF(sd * 0.55 * s, 0.6 * s, 0.55 * s) * CFrame.Angles(math.rad(-25), 0, math.rad(15) * sd), bone)
    add("EyeSocket", V3(0.26 * s, 0.3 * s, 0.12 * s), CF(sd * 0.27 * s, 0.2 * s, -0.28 * s), black, MAT.SmoothPlastic, true)
    add("EyeGlint", V3(0.08 * s, 0.1 * s, 0.05 * s), CF(sd * 0.27 * s, 0.2 * s, -0.35 * s), C3(120, 230, 255), MAT.Neon, true)
  end
  add("Snout", V3(0.55 * s, 0.32 * s, 1.1 * s), CF(0, -0.02 * s, -0.85 * s), bone)
  add("Jaw", V3(0.5 * s, 0.2 * s, 1.0 * s), CF(0, -0.42 * s, -0.65 * s) * CFrame.Angles(math.rad(6), 0, 0), bone)
  add("Nose", V3(0.1 * s, 0.08 * s, 0.05 * s), CF(0, 0.1 * s, -1.41 * s), black, MAT.SmoothPlastic, true)
  for i = 0, 2 do
    local z = -0.5 * s - i * 0.28 * s
    for _, sd in ipairs({ -1, 1 }) do
      add("ToothU", V3(0.06 * s, 0.14 * s, 0.08 * s), CF(sd * 0.2 * s, -0.24 * s, z), white, MAT.Marble, true)
      add("ToothL", V3(0.06 * s, 0.12 * s, 0.08 * s), CF(sd * 0.18 * s, -0.3 * s, z - 0.1 * s), white, MAT.Marble, true)
    end
  end
  -- Белый заряд и луч
  local charge = add("Charge", V3(0.3 * s, 0.3 * s, 0.3 * s), CF(0, -0.22 * s, -1.35 * s), COL_CHARGE, MAT.Neon, true, 0.2)
  charge.Shape = PT_BALL
  add("Beam", V3(0.28 * s, 0.22 * s, 1.4 * s), CF(0, -0.22 * s, -2.1 * s), COL_BEAM, MAT.Neon, true, 0.3)
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

-- ===== МИР: осколки + ловушки =====
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
  -- 16 осколков
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
  -- 5 ловушек
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

-- ===== UI =====
local function onClick(btn, fn, releaseOnly)
  local deb = false
  local function call()
    if deb then return end
    deb = true
    task.delay(0.12, function() deb = false end)
    pcall(fn)
  end
  local function inScroll() return releaseOnly or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil end
  btn.MouseButton1Down:Connect(function() if not inScroll() then call() end end)
  btn.MouseButton1Click:Connect(function() if inScroll() then call() end end)
  btn.Activated:Connect(call)
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
  G.collector.collected = n
  u.prog.Text = string.format("Собрано %d/%d", n, #PARTS)
  if G.state == "collecting" then
    u.timer.Text = "⏱ " .. fmtTime(G.timer)
  elseif G.state == "boss" then
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
  G.uiHidden = false
end
function G.hideUI()
  if G.ui and G.ui.sg then
    G.ui.sg.Enabled = false
    G.uiHidden = true
    if ORBIT.notify then ORBIT.notify("👁 UI скрыт, игра идёт", C3(200, 220, 255), 2) end
  end
end
function G.showUI()
  if G.ui and G.ui.sg then
    G.ui.sg.Enabled = true
    G.uiHidden = false
  else
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then G._rebuild = true end
  end
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
  win.AnchorPoint = Vector2.new(0.5, 0); win.Position = UDim2.new(0.5, 0, 0, 10)
  win.Size = UDim2.fromOffset(w, ORBIT.gasterUnlocked and 240 or 210)
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
  u.hint = lbl(x0, 82, cw, 44, "Осколки плавают. Ловушки (фиолетовые) — минус осколок! Собирай все 16 — потом босс.", 10, C3(170, 160, 200))
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
    u.btnBoss = btn(x0, 200, cw, "⚔ ВЫЗВАТЬ БОССА")
    u.btnBoss.TextSize = 11; u.btnBoss.BackgroundColor3 = C3(130, 40, 90)
    onClick(u.btnBoss, function() B.start() end, true)
  end
  onClick(u.btnStart, function() G.start() end, true)
  onClick(u.btnReset, function() G.reset() end, true)
  onClick(u.btnClose, function() G.hideUI() end, true)
  G.ui = u
  uiRefresh()
end

-- ===== Игра =====
function G.start()
  if not alive then return false end
  if G.state == "collecting" or G.state == "boss" then toast("Игра уже идёт!"); return false end
  if not getChar() then return false end
  if not G.spawnParts() then return false end
  G.timer = 120; G.state = "collecting"; G.collector.collected = 0
  ping("ping", 1, 1.2)
  toast("Собери все 16 осколков! Осторожно — ловушки!")
  uiRefresh()
  return true
end
function G.reset()
  clearShards()
  G.state = "idle"; G.timer = 120; G.collector.collected = 0
  if B.active then B.finish("cancel") end
  toast("Сброшено. Нажми СТАРТ.")
  uiRefresh()
end
function G.close()
  G.hideUI()
end
local function fail(reason)
  clearShards()
  G.state = "idle"
  ping("click", 1, 0.7)
  toast(reason or "Время вышло! Нажми СТАРТ.")
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
  if n >= #PARTS then G.assemble(false) end
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
  for id, s in pairs(G.parts) do
    if s.got then s.got = false; break end
  end
  ping("click", 1, 0.5)
  toast("⚠️ ЛОВУШКА! −1 осколок")
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

-- ===== Финал + орбитальный Гастер =====
local function zigzag(a, b, col, th)
  local pts, d = { a }, b - a
  for i = 1, 5 do pts[#pts + 1] = a + d * (i / 6) + V3(math.random() - 0.5, 0, math.random() - 0.5) * 6 end
  pts[#pts + 1] = b
  for i = 1, #pts - 1 do
    local diff = pts[i + 1] - pts[i]
    if diff.Magnitude > 0.05 then
      local p = Instance.new("Part")
      p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Material = MAT.Neon
      p.Color = col; p.Size = V3(th, th, diff.Magnitude); p.CFrame = CFrame.lookAt((pts[i] + pts[i + 1]) / 2, pts[i + 1])
      p.Parent = fold(); Debris:AddItem(p, 0.18)
    end
  end
end
local function burstAt(pos, col, n)
  local p = Instance.new("Part")
  p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.Transparency = 1; p.Size = V3(0.2, 0.2, 0.2); p.Position = pos; p.Parent = fold()
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(col); e.LightEmission = 1; e.Size = NumberSequence.new(0.7, 0)
  e.Lifetime = NumberRange.new(0.4, 0.9); e.Speed = NumberRange.new(8, 18); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0; e.Parent = p
  e:Emit(n)
  Debris:AddItem(p, 1.5)
end
local function pickEnemy(center, maxd)
  local list = {}
  for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LP and pl.Character then
      local h = pl.Character:FindFirstChildOfClass("Humanoid")
      local r = pl.Character:FindFirstChild("HumanoidRootPart")
      if h and r and h.Health > 0 and (r.Position - center).Magnitude <= maxd then list[#list + 1] = { hum = h, root = r } end
    end
  end
  if #list == 0 then return nil end
  return list[math.random(#list)]
end
function G.removeFigure()
  token = token + 1
  if G.figure then
    pcall(function() G.figure.data.model:Destroy() end)
    G.figure = nil
  end
  if G.cc then pcall(function() G.cc:Destroy() end); G.cc = nil end
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
  token = token + 1
  local my = token
  G.removeFigure()
  token = my
  uiRefresh()
  task.spawn(function()
    local function ok() return alive and token == my end
    local c, h, root = getChar()
    if not quick and root then
      toast("Что-то пробуждается...")
      local cc = Instance.new("ColorCorrectionEffect")
      cc.Name = "OrbitGasterCC"; cc.Parent = Lighting; G.cc = cc
      TS:Create(cc, TweenInfo.new(1.5), { Brightness = -0.05, Saturation = -0.1, TintColor = C3(240, 240, 255) }):Play()
      ping("laugh", 1, 0.8)
      local sp = Instance.new("Part")
      sp.Anchored = true; sp.CanCollide = false; sp.CanQuery = false; sp.Transparency = 1; sp.Size = V3(8, 1, 8)
      sp.Position = root.Position - V3(0, 2.5, 0); sp.Parent = fold()
      local e = Instance.new("ParticleEmitter")
      e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.Color = ColorSequence.new(C3(200, 200, 220))
      e.Rate = 60; e.Lifetime = NumberRange.new(1, 2); e.Speed = NumberRange.new(3, 8); e.Size = NumberSequence.new(3, 5)
      e.Transparency = NumberSequence.new(0.3, 1); e.EmissionDirection = Enum.NormalId.Top; e.Parent = sp
      Debris:AddItem(sp, 6)
      for _ = 1, 6 do
        if not ok() then return end
        local c2, h2, r2 = getChar()
        if r2 then
          local o = r2.Position + V3(math.random(-12, 12), 0, math.random(-12, 12))
          zigzag(o + V3(0, 45, 0), o, COL_GLOW, 0.5)
          burstAt(o, COL_GLOW, 16)
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
    ORBIT.gasterUnlocked = true
    ORBIT.saveData = ORBIT.saveData or {}
    ORBIT.saveData.gasterUnlocked = true
    if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
    toast("Гастер с тобой навсегда.")
    uiRefresh()
  end)
  return true
end
local function shoot(f, fr)
  local from = f.charge and f.charge.Position or f.data.model:GetPivot().Position
  local to = fr.tpos
  local diff = to - from
  if diff.Magnitude > 0.5 then
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Material = MAT.Neon
    p.Color = COL_BEAM; p.Transparency = 0.15; p.Size = V3(1.8, 1.8, diff.Magnitude)
    p.CFrame = CFrame.lookAt((from + to) / 2, to); p.Parent = fold()
    TS:Create(p, TweenInfo.new(0.35), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.45)
  end
  burstAt(to, COL_GLOW, 24)
  if fr.boss then B.damage(20, "figure") end
  if fr.hum and fr.hum.Parent and fr.hum.Health > 0 then pcall(function() fr.hum:TakeDamage(18) end) end
  ping("snap", 1, 0.5)
end
local function stepFigure(dt, t)
  local f = G.figure
  local m = f.data.model
  if not m.Parent then G.figure = nil; return end
  local c, h, root = getChar()
  f.angle = f.angle + dt * 2 * math.pi / 30
  f.riseT = math.min(1.5, f.riseT + dt)
  local k = f.riseT / 1.5
  k = 1 - (1 - k) * (1 - k)
  local center = root and root.Position or f.lastCenter or V3()
  f.lastCenter = center
  local ca, sa = math.cos(f.angle), math.sin(f.angle)
  local pos = center + V3(ca * 8, 4 + math.sin(t * 1.5) * 0.5 - 12 * (1 - k), sa * 8)
  local look = pos + V3(ca, 0, sa)
  local fr = f.fire
  if fr then look = fr.tpos end
  pcall(function() m:PivotTo(CFrame.lookAt(pos, look)) end)
  if k >= 1 then
    if not fr and t >= f.nextShot then
      if B.active and B.pos then
        f.nextShot = t + 3
        f.fire = { t0 = t, tpos = B.pos, boss = true }
      else
        f.nextShot = t + math.random(4, 7)
        local tg = pickEnemy(center, 80)
        if tg then f.fire = { t0 = t, hum = tg.hum, root = tg.root, tpos = tg.root.Position } end
      end
    end
    fr = f.fire
    if fr then
      if fr.root and fr.root.Parent then fr.tpos = fr.root.Position end
      local el = t - fr.t0
      if f.light then f.light.Brightness = 1.5 + 4 * math.min(1, el / 0.5) end
      if el >= 0.5 and not fr.shot then fr.shot = true; shoot(f, fr) end
      if el >= 1.0 then f.fire = nil end
    elseif f.light then
      f.light.Brightness = 1.5 + 0.5 * math.sin(t * 3)
    end
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
local function interpret(raw)
  local t = ruLower(raw)
  if t:find("гастер", 1, true) then
    if t:find("босс", 1, true) then
      if t:find("отбой", 1, true) or t:find("убери", 1, true) or t:find("стоп", 1, true) then
        B.finish("cancel")
        return true, "👁 Босс отозван"
      end
      if B.start() then return true, "⚔ Бой с Гастером!" end
      return true, "🔒 Босс недоступен"
    end
    if t:find("включи", 1, true) and ORBIT.gasterUnlocked then
      if not G.figure then G.assemble(true) end
      return true, "👁 Гастер включён"
    end
    if t:find("собери", 1, true) or t:find("игр", 1, true) then
      G.open()
      return true, "👁 Игра: Собери Гастера"
    end
  end
  return false
end
local function wrapHelper()
  local H = ORBIT.helper
  if helperWrapped or not H or type(H.interpret) ~= "function" then return end
  helperWrapped = true
  origInterp = H.interpret
  H.interpret = function(raw, ...)
    if alive and type(raw) == "string" then
      local ok, handled, msg = pcall(interpret, raw)
      if ok and handled then return true, msg end
    end
    return origInterp(raw, ...)
  end
end

-- ===== Главный цикл =====
local slowAcc, lastShown = 0, -1
G.heartbeat = RS.Heartbeat:Connect(function(dt)
  if not alive then return end
  local t = tick()
  slowAcc = slowAcc + dt
  if slowAcc >= 1 then
    slowAcc = 0
    wrapHelper()
    if not G.shapeRegistered then G.registerShape() end
  end
  if G._rebuild then
    G._rebuild = nil
    buildUI()
  end
  -- Сбор осколков
  if G.state == "collecting" then
    G.timer = G.timer - dt
    local _, _, root = getChar()
    for id, s in pairs(G.parts) do
      if not s.got and s.part and s.part.Parent and not s.flying then
        local ang = t * s.speed + s.phase
        local offset = V3(math.cos(ang) * s.radius, math.sin(t * 2 + s.phase) * 0.8, math.sin(ang) * s.radius)
        s.part.CFrame = CF(s.base + offset) * CFrame.Angles(0, t * 1.5 + s.phase, 0)
        if root and (root.Position - s.part.Position).Magnitude < 5 then G.collectPart(id) end
      end
    end
    -- Ловушки
    if root then
      for _, tr in ipairs(G.traps) do
        if tr.part and tr.part.Parent then
          tr.angle = tr.angle + tr.angleSpeed * dt
          local x = root.Position.X + math.cos(tr.angle) * tr.baseRadius
          local z = root.Position.Z + math.sin(tr.angle) * tr.baseRadius
          local y = tr.baseY + math.sin(t * 1.5 + tr.bobPhase) * 1.5
          tr.part.CFrame = CF(V3(x, y, z))
          if (tr.part.Position - root.Position).Magnitude < tr.r / 2 + 3 then trapHit(tr) end
        end
      end
    end
    local shown = math.floor(G.timer)
    if shown ~= lastShown and G.ui and not G.uiHidden then lastShown = shown; G.ui.timer.Text = "⏱ " .. fmtTime(G.timer) end
    if G.timer <= 0 then fail() end
  end
  if G.figure then stepFigure(dt, t) end
  -- Оружие раньше не получало шаг — фикс Claude
  if W and W.equipped then
    local okW, errW = pcall(W.update, dt)
    if not okW and not G.warnedW then G.warnedW = true; warn("[ORBIT] gaster weapon: " .. tostring(errW)) end
  end
  if bossStep then
    local okB, errB = pcall(bossStep, dt, t)
    if not okB and not G.warnedB then G.warnedB = true; warn("[ORBIT] gaster boss: " .. tostring(errB)) end
  end
end)

function G.open()
  if not alive then return false end
  -- Если игра уже идёт — просто показываем UI
  if G.state == "collecting" or G.state == "boss" then
    if G.ui then G.showUI() else buildUI() end
    return true
  end
  buildUI()
  return true
end
function G.destroy()
  if not alive then return end
  alive = false
  if G.heartbeat then pcall(function() G.heartbeat:Disconnect() end); G.heartbeat = nil end
  if B.active then pcall(B.finish, "cancel") end
  clearShards()
  closeUI()
  G.removeFigure()
  G.state = "idle"
  if G.weapon and G.weapon.destroy then pcall(G.weapon.destroy) end
  if helperWrapped and ORBIT.helper and origInterp then pcall(function() ORBIT.helper.interpret = origInterp end) end
  if folder then pcall(function() folder:Destroy() end); folder = nil end
end

-- ===== ГАСТЕР В РУКАХ (БЕЛЫЙ) =====
W = { equipped = false, models = {}, proj = {}, cdUntil = 0, conns = {}, side = 1 }
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
  burstAt(pos, COL_GLOW, 24)
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
  p.Shape = PT_BALL; p.Size = V3(1.4, 1.4, 1.4); p.Material = MAT.Neon; p.Color = COL_BEAM
  p.CFrame = CF(origin); p:SetAttribute("NoRecolor", true); p.Parent = wFold()
  local l = Instance.new("PointLight"); l.Color = COL_GLOW; l.Range = 12; l.Brightness = 3; l.Parent = p
  W.proj[#W.proj + 1] = { part = p, vel = dir * 140, born = t }
  burstAt(origin, COL_GLOW, 10)
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
      if not hit and B.active and B.pos and (B.pos - to).Magnitude <= B.hitR + 1.5 then hit = to end
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
        if B.active and B.pos and (B.pos - hit).Magnitude <= B.hitR + 6 then B.damage(40, "weapon") end
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

-- ═══════════════════════════════════════════════════════════
-- БОСС (3 фазы, 4 атаки) — белые лучи
-- ═══════════════════════════════════════════════════════════
do
  local PI = math.pi
  local PT_CYL = Enum.PartType.Cylinder
  local PH_NAMES = { "ФАЗА 1/3", "ФАЗА 2/3", "ФАЗА 3/3" }
  local TINT = { C3(240, 240, 255), C3(230, 220, 255), C3(255, 220, 220) }
  local TINT_B = { -0.05, -0.1, -0.16 }
  local CFG = {
    { gap = 2.6, move = 0.25, R = 44, H = 17 },
    { gap = 1.9, move = 0.35, R = 40, H = 16 },
    { gap = 1.3, move = 0.5, R = 34, H = 15 },
  }
  local WEIGHTS = {
    { blaster = 5, lightning = 4 },
    { blaster = 4, lightning = 3, hand = 4 },
    { blaster = 3, lightning = 3, hand = 3, nova = 3 },
  }
  local ATK = {}

  local function okRun(my) return alive and B.active and B.run == my end
  local function flatDist(a, b) return V3(a.X - b.X, 0, a.Z - b.Z).Magnitude end
  local function distToSeg(p, a, b)
    local ab = b - a
    local l2 = ab:Dot(ab)
    if l2 < 1e-6 then return (p - a).Magnitude end
    local k = math.clamp((p - a):Dot(ab) / l2, 0, 1)
    return (p - (a + ab * k)).Magnitude
  end
  local function fx(shape, size, cf, col, mat, tr, life)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
    p.Shape = shape or PT_BLOCK; p.Size = size; p.CFrame = cf; p.Color = col
    p.Material = mat or MAT.Neon; p.Transparency = tr or 0
    p:SetAttribute("NoRecolor", true); p.Parent = fold()
    if life then Debris:AddItem(p, life) end
    return p
  end
  local function groundAt(pos)
    local res = WS:Raycast(V3(pos.X, pos.Y + 40, pos.Z), V3(0, -160, 0), rayParams())
    return V3(pos.X, res and res.Position.Y or (pos.Y - 3), pos.Z)
  end
  local function say(text, dur)
    if ORBIT.sans and ORBIT.sans.showAt and B.pos then
      pcall(ORBIT.sans.showAt, B.pos + V3(0, 10, 0), text, dur or 3.5)
    elseif ORBIT.notify then
      pcall(ORBIT.notify, "👁 " .. text, C3(220, 220, 255), 3)
    end
  end
  local function flash(col, a)
    local u = B.ui
    if not u or not u.flash then return end
    u.flash.BackgroundColor3 = col; u.flash.BackgroundTransparency = a
    TS:Create(u.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
  end
  local function hurt(n)
    local t = tick()
    if t < B.hurtUntil then return false end
    local _, h = getChar()
    if not h or h.Health <= 0 then return false end
    local dmg = n * B.dmgScale
    if B.safe then dmg = math.min(dmg, math.max(0, h.Health - 1)) end
    if dmg <= 0 then return false end
    B.hurtUntil = t + 0.3
    pcall(function() h:TakeDamage(dmg) end)
    ping("click", 1, 0.5)
    flash(C3(255, 60, 90), 0.75)
    return true
  end
  local function knock(root, fromPos, power)
    local d = root.Position - fromPos
    d = V3(d.X, 0, d.Z)
    if d.Magnitude < 0.1 then d = V3(0, 0, 1) end
    pcall(function() root.AssemblyLinearVelocity = d.Unit * power + V3(0, power * 0.7, 0) end)
  end
  local function mouthPos()
    local ch = B.charge
    if ch and ch.Parent then return ch.Position end
    return B.pos or V3()
  end
  local function resetCharge()
    local ch = B.charge
    if ch and ch.Parent then
      TS:Create(ch, TweenInfo.new(0.25), { Size = V3(0.3, 0.3, 0.3) * B.scale }):Play()
    end
  end

  local function closeBossUI()
    if B.ui and B.ui.sg then pcall(function() B.ui.sg:Destroy() end) end
    B.ui = nil
  end
  local function refreshBossUI()
    local u = B.ui
    if not u then return end
    local frac = math.clamp(B.hp / B.maxHp, 0, 1)
    TS:Create(u.fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(frac, 1) }):Play()
    u.name.Text = "👁 ГАСТЕР · " .. PH_NAMES[B.phase]
    u.hp.Text = string.format("%d/%d", math.ceil(B.hp), B.maxHp)
    u.fill.BackgroundColor3 = B.phase == 3 and C3(255, 90, 110) or (B.phase == 2 and C3(230, 100, 230) or C3(210, 210, 255))
  end
  local function buildBossUI()
    closeBossUI()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "OrbitGasterBossGui"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.DisplayOrder = 27; sg.Parent = pg
    local cm = WS.CurrentCamera
    local vp = cm and cm.ViewportSize or Vector2.new(800, 400)
    local w = math.min(380, vp.X - 24)
    local fl = Instance.new("Frame")
    fl.Size = UDim2.fromScale(1, 1); fl.BackgroundColor3 = C3(255, 255, 255); fl.BackgroundTransparency = 1
    fl.BorderSizePixel = 0; fl.Parent = sg
    local win = Instance.new("Frame")
    win.AnchorPoint = Vector2.new(0.5, 0); win.Position = UDim2.new(0.5, 0, 0, 8); win.Size = UDim2.fromOffset(w, 54)
    win.BackgroundColor3 = C3(16, 12, 26); win.BackgroundTransparency = 0.15; win.Parent = sg
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke"); st.Color = C3(200, 200, 255); st.Thickness = 2; st.Parent = win
    local function lbl(x, y, ww, hh, text, size, xa)
      local l = Instance.new("TextLabel")
      l.BackgroundTransparency = 1; l.Position = UDim2.fromOffset(x, y); l.Size = UDim2.fromOffset(ww, hh)
      l.Text = text; l.TextSize = size; l.TextColor3 = C3(235, 235, 255); l.Font = Enum.Font.GothamBold
      l.TextXAlignment = xa or Enum.TextXAlignment.Left; l.Parent = win
      return l
    end
    local u = { sg = sg, flash = fl }
    u.name = lbl(10, 4, w - 90, 20, "👁 ГАСТЕР", 14)
    u.hp = lbl(10, 4, w - 84, 20, "", 12, Enum.TextXAlignment.Right)
    local bg = Instance.new("Frame")
    bg.Position = UDim2.fromOffset(10, 28); bg.Size = UDim2.fromOffset(w - 20, 16)
    bg.BackgroundColor3 = C3(40, 30, 60); bg.BorderSizePixel = 0; bg.Parent = win
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    u.fill = Instance.new("Frame")
    u.fill.Size = UDim2.fromScale(1, 1); u.fill.BackgroundColor3 = C3(210, 210, 255); u.fill.BorderSizePixel = 0; u.fill.Parent = bg
    Instance.new("UICorner", u.fill).CornerRadius = UDim.new(0, 6)
    for _, mark in ipairs({ 0.33, 0.66 }) do
      local tk = Instance.new("Frame")
      tk.Position = UDim2.fromScale(mark, 0); tk.Size = UDim2.new(0, 2, 1, 0); tk.BackgroundColor3 = C3(255, 255, 255)
      tk.BackgroundTransparency = 0.3; tk.BorderSizePixel = 0; tk.ZIndex = 3; tk.Parent = bg
    end
    u.stop = Instance.new("TextButton")
    u.stop.AnchorPoint = Vector2.new(1, 0); u.stop.Position = UDim2.new(1, -6, 0, 3); u.stop.Size = UDim2.fromOffset(64, 22)
    u.stop.Text = "✖ ОТБОЙ"; u.stop.TextSize = 11; u.stop.Font = Enum.Font.GothamBold; u.stop.TextColor3 = C3(255, 255, 255)
    u.stop.BackgroundColor3 = C3(110, 40, 70); u.stop.AutoButtonColor = false; u.stop.ZIndex = 4; u.stop.Parent = win
    Instance.new("UICorner", u.stop).CornerRadius = UDim.new(0, 6)
    onClick(u.stop, function() B.finish("cancel") end, true)
    u.hp.Size = UDim2.fromOffset(w - 84, 20)
    B.ui = u
    refreshBossUI()
  end

  -- Рука
  local function createHand(s)
    local model = shell("GasterBossHand")
    local bone, black = C3(250, 245, 235), C3(10, 10, 14)
    local function P(x, y, z) return CF(x * s, y * s, z * s) end
    local function add(n, sx, sy, sz, cf, col, mat, nr)
      return mkp(model, n, V3(sx * s, sy * s, sz * s), cf, col, mat, nr)
    end
    add("Palm", 7, 1.6, 8, P(0, 0, 0), bone)
    for i = 1, 4 do
      local x = -2.6 + (i - 1) * 1.75
      local len = (i == 2 or i == 3) and 6.5 or 5.5
      add("Finger", 1.3, 1.2, len, P(x, 0, -(4 + len / 2)), bone)
      add("Tip", 1.1, 1.0, 0.9, P(x, 0, -(4 + len + 0.2)), black, MAT.SmoothPlastic, true)
    end
    add("Thumb", 1.5, 1.2, 4.5, P(4.4, 0, -1.2) * CFrame.Angles(0, math.rad(-35), 0), bone)
    local hole = add("Hole", 0.3, 2.8, 2.8, P(0, 0.9, 0.3) * CFrame.Angles(0, 0, math.rad(90)), black, MAT.SmoothPlastic, true)
    hole.Shape = PT_CYL
    local ring = add("HoleRing", 0.22, 3.4, 3.4, P(0, 0.85, 0.3) * CFrame.Angles(0, 0, math.rad(90)), COL_GLOW, MAT.Neon, true)
    ring.Shape = PT_CYL
    return model
  end

  -- Атака: БЛАСТЕР (белый луч)
  local function fireBeam(my, tCharge, fanN, spread)
    if not okRun(my) then return false end
    B.hold = true
    local ch = B.charge
    if ch and ch.Parent then
      TS:Create(ch, TweenInfo.new(tCharge), { Size = V3(0.9, 0.9, 0.9) * B.scale }):Play()
    end
    ping("snap", 0.8, 0.5)
    local line = fx(PT_BLOCK, V3(0.5, 0.5, 1), CF(), COL_GLOW, MAT.Neon, 0.55, tCharge + 1)
    local t0, lockT = tick(), tCharge - 0.35
    local aim = B.pos
    while tick() - t0 < tCharge do
      if not okRun(my) then pcall(function() line:Destroy() end); return false end
      local _, _, root = getChar()
      if not root then break end
      local from = mouthPos()
      if tick() - t0 < lockT then aim = root.Position end
      local d = aim - from
      if d.Magnitude > 0.5 then
        local len = d.Magnitude + 60
        line.Size = V3(0.5, 0.5, len)
        line.CFrame = CFrame.lookAt(from + d.Unit * len / 2, from + d.Unit * len)
      end
      task.wait()
    end
    pcall(function() line:Destroy() end)
    if not okRun(my) then return false end
    local from = mouthPos()
    local dir = aim - from
    if dir.Magnitude < 0.5 then return false end
    dir = dir.Unit
    local L, beams, half = 170, {}, (fanN - 1) / 2
    for k = 0, fanN - 1 do
      local d = CFrame.Angles(0, math.rad(spread * (k - half)), 0):VectorToWorldSpace(dir)
      local cf = CFrame.lookAt(from + d * L / 2, from + d * L)
      local b = fx(PT_BLOCK, V3(5.5, 5.5, L), cf, COL_GLOW, MAT.Neon, 0.15, 1)
      local core = fx(PT_BLOCK, V3(2.2, 2.2, L), cf, COL_BEAM, MAT.Neon, 0, 1)
      TS:Create(b, TweenInfo.new(0.55), { Transparency = 1, Size = V3(0.6, 0.6, L) }):Play()
      TS:Create(core, TweenInfo.new(0.55), { Transparency = 1, Size = V3(0.3, 0.3, L) }):Play()
      beams[#beams + 1] = d
    end
    burstAt(from, COL_GLOW, 30)
    ping("snap", 1, 0.4); ping("ping", 1, 0.5)
    flash(C3(240, 240, 255), 0.85)
    local hit, tt = false, tick()
    while tick() - tt < 0.3 do
      if not okRun(my) then return false end
      local _, _, root = getChar()
      if root and not hit then
        for _, d in ipairs(beams) do
          if distToSeg(root.Position, from, from + d * L) <= 4.5 then hit = hurt(B.dmg.blaster); break end
        end
      end
      task.wait()
    end
    return true
  end
  ATK.blaster = function(my)
    if B.phase == 1 then
      fireBeam(my, 1.5, 1, 0)
    elseif B.phase == 2 then
      fireBeam(my, 1.2, 1, 0); task.wait(0.15); fireBeam(my, 0.8, 1, 0)
    else
      fireBeam(my, 0.9, 1, 0); task.wait(0.15); fireBeam(my, 0.8, 3, 16)
    end
  end

  -- Атака: МОЛНИЯ
  local function strike(my, gp, delay)
    local R = 5.5
    local ring = fx(PT_CYL, V3(0.25, R * 2, R * 2), CF(gp + V3(0, 0.2, 0)) * CFrame.Angles(0, 0, PI / 2), COL_GLOW, MAT.Neon, 0.55, delay + 1)
    local inner = fx(PT_CYL, V3(0.3, 1, 1), ring.CFrame, COL_BEAM, MAT.Neon, 0.3, delay + 1)
    TS:Create(inner, TweenInfo.new(delay, Enum.EasingStyle.Linear), { Size = V3(0.3, R * 2, R * 2) }):Play()
    task.delay(delay, function()
      if not okRun(my) then
        pcall(function() ring:Destroy() end); pcall(function() inner:Destroy() end); return
      end
      pcall(function() ring:Destroy() end); pcall(function() inner:Destroy() end)
      zigzag(gp + V3(0, 70, 0), gp, COL_GLOW, 0.9)
      burstAt(gp + V3(0, 1, 0), COL_GLOW, 22)
      ping("snap", 1, 0.9)
      local _, _, root = getChar()
      if root and flatDist(root.Position, gp) <= R and math.abs(root.Position.Y - gp.Y) < 12 then
        hurt(B.dmg.lightning)
      end
    end)
  end
  ATK.lightning = function(my)
    local n = ({ 3, 4, 6 })[B.phase]
    local delay = ({ 1.0, 0.85, 0.7 })[B.phase]
    for i = 1, n do
      if not okRun(my) then return end
      local _, _, root = getChar()
      if not root then return end
      local off = (i == 1) and V3() or V3(math.random(-14, 14), 0, math.random(-14, 14))
      strike(my, groundAt(root.Position + off), delay)
      task.wait(0.4)
    end
    task.wait(delay)
  end

  -- Атака: РУКА
  local function slam(my, gp, tele, done)
    local R = 10
    local cf0 = CF(gp + V3(0, 0.25, 0)) * CFrame.Angles(0, 0, PI / 2)
    local ring = fx(PT_CYL, V3(0.25, R * 2, R * 2), cf0, C3(200, 180, 240), MAT.Neon, 0.6, tele + 2)
    local inner = fx(PT_CYL, V3(0.3, 1, 1), cf0, COL_BEAM, MAT.Neon, 0.35, tele + 2)
    TS:Create(inner, TweenInfo.new(tele, Enum.EasingStyle.Linear), { Size = V3(0.3, R * 2, R * 2) }):Play()
    local hand = createHand(2.2)
    hand.Parent = fold()
    Debris:AddItem(hand, tele + 3)
    local d = gp - (B.pos or gp)
    local yaw = math.atan2(-d.X, -d.Z)
    local from = CF(gp + V3(0, 55, 0)) * CFrame.Angles(0, yaw, 0)
    local to = CF(gp + V3(0, 3, 0)) * CFrame.Angles(0, yaw, 0)
    pcall(function() hand:PivotTo(from) end)
    local t0 = tick()
    while tick() - t0 < tele do
      if not okRun(my) then done(); return end
      task.wait()
    end
    local f0 = tick()
    while true do
      local a = (tick() - f0) / 0.3
      if a >= 1 then break end
      if not okRun(my) then done(); return end
      pcall(function() hand:PivotTo(from:Lerp(to, a * a)) end)
      task.wait()
    end
    pcall(function() hand:PivotTo(to) end)
    local shock = fx(PT_CYL, V3(0.4, R, R), cf0, COL_GLOW, MAT.Neon, 0.2, 1)
    TS:Create(shock, TweenInfo.new(0.5), { Size = V3(0.4, R * 3.2, R * 3.2), Transparency = 1 }):Play()
    burstAt(gp + V3(0, 2, 0), COL_GLOW, 30)
    ping("snap", 1, 0.3)
    flash(COL_GLOW, 0.88)
    local _, _, root = getChar()
    if root and flatDist(root.Position, gp) <= R and root.Position.Y - gp.Y < 14 then
      if hurt(B.dmg.hand) then knock(root, gp, 45) end
    end
    task.wait(0.5)
    for _, p in ipairs(hand:GetDescendants()) do
      if p:IsA("BasePart") then TS:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play() end
    end
    task.wait(0.5)
    done()
  end
  ATK.hand = function(my)
    local _, _, root = getChar()
    if not root then return end
    local pending = 0
    local function done() pending = pending - 1 end
    local gp1 = groundAt(root.Position)
    pending = pending + 1
    task.spawn(slam, my, gp1, B.phase == 3 and 1.0 or 1.2, done)
    if B.phase == 3 then
      local v = root.AssemblyLinearVelocity
      local gp2 = groundAt(root.Position + V3(v.X, 0, v.Z) * 1.1 + V3(math.random(-4, 4), 0, math.random(-4, 4)))
      pending = pending + 1
      task.spawn(slam, my, gp2, 1.3, done)
    end
    local t0 = tick()
    while pending > 0 and tick() - t0 < 6 do
      if not okRun(my) then return end
      task.wait(0.05)
    end
  end

  -- Атака: ВЗРЫВ
  ATK.nova = function(my)
    local _, _, root = getChar()
    if not root then return end
    local gp = groundAt(root.Position)
    local R, tele = 26, 2.2
    local cf0 = CF(gp + V3(0, 0.3, 0)) * CFrame.Angles(0, 0, PI / 2)
    local ring = fx(PT_CYL, V3(0.3, R * 2, R * 2), cf0, C3(255, 180, 200), MAT.Neon, 0.7, tele + 2)
    local inner = fx(PT_CYL, V3(0.35, 1, 1), cf0, COL_BEAM, MAT.Neon, 0.4, tele + 2)
    TS:Create(inner, TweenInfo.new(tele, Enum.EasingStyle.Linear), { Size = V3(0.35, R * 2, R * 2) }):Play()
    B.hold = true
    local ch = B.charge
    if ch and ch.Parent then TS:Create(ch, TweenInfo.new(tele), { Size = V3(1.1, 1.1, 1.1) * B.scale }):Play() end
    ping("laugh", 1, 0.7)
    local t0 = tick()
    while tick() - t0 < tele do
      if not okRun(my) then pcall(function() ring:Destroy() end); pcall(function() inner:Destroy() end); return end
      task.wait()
    end
    pcall(function() ring:Destroy() end); pcall(function() inner:Destroy() end)
    local ball = fx(PT_BALL, V3(2, 2, 2), CF(gp + V3(0, 2, 0)), COL_GLOW, MAT.Neon, 0.25, 1)
    TS:Create(ball, TweenInfo.new(0.5), { Size = V3(R * 2.2, R * 2.2, R * 2.2), Transparency = 1 }):Play()
    burstAt(gp + V3(0, 3, 0), COL_GLOW, 50)
    ping("snap", 1, 0.3); ping("ping", 1, 0.4)
    flash(COL_GLOW, 0.55)
    local _, _, r2 = getChar()
    if r2 and flatDist(r2.Position, gp) <= R and math.abs(r2.Position.Y - gp.Y) < 28 then
      if hurt(B.dmg.nova) then knock(r2, gp, 60) end
    end
    task.wait(0.6)
  end

  local function enterPhase(p)
    B.phase = p
    B.run = B.run + 1
    B.busy, B.hold = false, false
    B.invUntil = tick() + 2.2
    B.nextAttack = tick() + 3.2
    resetCharge()
    refreshBossUI()
    flash(p == 3 and C3(255, 150, 150) or C3(240, 230, 255), 0.5)
    ping("laugh", 1, p == 3 and 0.6 or 0.8)
    say(p == 2 and "Неплохо. Но это только начало." or "ХВАТИТ ИГР. ПОЧУВСТВУЙ ПУСТОТУ.", 4)
    if B.cc then TS:Create(B.cc, TweenInfo.new(1.5), { TintColor = TINT[p], Brightness = TINT_B[p] }):Play() end
    if B.pos then burstAt(B.pos, C3(255, 255, 255), 40) end
    local ch = B.charge
    if ch and ch.Parent then
      local gl = ch:FindFirstChild("GLight")
      if gl then gl.Color = p == 3 and C3(255, 120, 120) or COL_GLOW end
      if p == 3 then ch.Color = C3(255, 140, 140) end
    end
  end
  function B.damage(n, src)
    if not alive or not B.active then return false end
    local t = tick()
    if t < B.invUntil or t < B.riseUntil then return false end
    B.hp = math.max(0, B.hp - n)
    if B.model and t - B.lastFlash > 0.12 then
      B.lastFlash = t
      local hl = Instance.new("Highlight")
      hl.FillColor = C3(255, 255, 255); hl.FillTransparency = 0.55; hl.OutlineTransparency = 1
      hl.Adornee = B.model; hl.Parent = B.model
      Debris:AddItem(hl, 0.12)
    end
    refreshBossUI()
    if B.hp <= 0 then B.finish("win"); return true end
    local frac = B.hp / B.maxHp
    local np = frac <= 0.33 and 3 or (frac <= 0.66 and 2 or 1)
    if np > B.phase then enterPhase(np) end
    return true
  end
  function B.finish(result)
    if not B.active then return end
    B.active = false
    B.run = B.run + 1
    B.busy, B.hold = false, false
    local model, pos = B.model, B.pos
    B.model, B.charge = nil, nil
    if result == "win" and model then
      B.wins = B.wins + 1
      Debris:AddItem(model, 1.6)
      for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
          local dir = V3(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
          if dir.Magnitude < 0.1 then dir = V3(0, 1, 0) end
          TS:Create(p, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { CFrame = p.CFrame + dir.Unit * math.random(10, 30), Transparency = 1 }):Play()
        end
      end
      if pos then
        burstAt(pos, C3(255, 255, 255), 60)
        burstAt(pos + V3(0, 4, 0), COL_GLOW, 50)
      end
      flash(C3(255, 255, 255), 0.3)
      ping("laugh", 1, 1.4); ping("ping", 1, 0.5)
      if ORBIT.sans and ORBIT.sans.showAt and pos then
        pcall(ORBIT.sans.showAt, pos + V3(0, 10, 0), "Я... вернусь в пустоту...", 4)
      end
      wNotify("🏆 Гастер повержен!")
      G.state = "won"
      -- После победы — орбитальный Гастер
      if not G.figure then task.delay(2, function() if alive then G.assemble(true) end end) end
    else
      if model then pcall(function() model:Destroy() end) end
      if result == "lose" then
        ping("laugh", 1, 0.7)
        wNotify("💀 Гастер победил. Попробуй ещё раз.")
      elseif result == "cancel" then
        wNotify("👁 Бой с Гастером окончен")
      end
      if G.state == "boss" then G.state = "idle" end
    end
    if B.cc then
      local cc = B.cc
      B.cc = nil
      TS:Create(cc, TweenInfo.new(1), { TintColor = C3(255, 255, 255), Brightness = 0 }):Play()
      Debris:AddItem(cc, 1.2)
    end
    closeBossUI()
  end
  B.stop = function() B.finish("cancel") end
  function B.start()
    if not alive then return false end
    if B.active then return false end
    if not ORBIT.gasterUnlocked then wNotify("🔒 Сначала пройди «Собери Гастера»"); return false end
    local c, h, root = getChar()
    if not c or h.Health <= 0 then return false end
    G.close()
    clearShards()
    G.state = "boss"
    B.run = B.run + 1
    B.active = true
    B.phase, B.hp = 1, B.maxHp
    B.busy, B.hold = false, false
    B.hurtUntil, B.lastFlash, B.lastAtk = 0, 0, nil
    B.angle = math.random() * PI * 2
    local data = createGaster(B.scale, "GasterBoss")
    data.model.Parent = fold()
    local bm = data.model:FindFirstChild("Beam")
    if bm then bm:Destroy() end
    B.model = data.model
    B.charge = data.model:FindFirstChild("Charge")
    B.pos = root.Position + V3(math.cos(B.angle) * CFG[1].R, -25, math.sin(B.angle) * CFG[1].R)
    local t = tick()
    B.riseUntil = t + 2.2
    B.invUntil = B.riseUntil
    B.nextAttack = B.riseUntil + 1
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "OrbitGasterBossCC"; cc.Parent = Lighting; B.cc = cc
    TS:Create(cc, TweenInfo.new(1.5), { TintColor = TINT[1], Brightness = TINT_B[1] }):Play()
    buildBossUI()
    if not W.equipped then pcall(W.equip) end
    ping("laugh", 1, 0.6)
    say("Ты зашёл слишком далеко.", 4)
    return true
  end

  local function pickAttack()
    local w, total = WEIGHTS[B.phase], 0
    for k, v in pairs(w) do if k ~= B.lastAtk then total = total + v end end
    local r = math.random() * total
    for k, v in pairs(w) do
      if k ~= B.lastAtk then
        r = r - v
        if r <= 0 then return k end
      end
    end
    return "blaster"
  end
  bossStep = function(dt, t)
    if not B.active then return end
    if dt > 0.2 then dt = 0.2 end
    local _, h, root = getChar()
    if not root or not h or h.Health <= 0 then B.finish("lose"); return end
    local m = B.model
    if not m or not m.Parent then B.finish("cancel"); return end
    local cfg = CFG[B.phase]
    local center = root.Position
    if not B.hold then B.angle = B.angle + dt * cfg.move end
    local rising = t < B.riseUntil
    local k = 1
    if rising then
      k = 1 - (B.riseUntil - t) / 2.2
      k = 1 - (1 - k) * (1 - k)
    end
    local target = center + V3(math.cos(B.angle) * cfg.R, cfg.H + math.sin(t * 1.3) * 1.2 - 30 * (1 - k), math.sin(B.angle) * cfg.R)
    B.pos = B.pos and B.pos:Lerp(target, math.min(1, dt * 2.5)) or target
    pcall(function() m:PivotTo(CFrame.lookAt(B.pos, center)) end)

    -- Снаряды стихий попадают в босса
    local AB = ORBIT.abilities
    if AB and type(AB.projectiles) == "table" then
      for _, q in ipairs(AB.projectiles) do
        local p = q.part
        if p and p.Parent and not q.visual and not q.gbHit then
          if (p.Position - B.pos).Magnitude <= B.hitR + (q.rad or 2) then
            q.gbHit = true
            burstAt(p.Position, C3(255, 255, 255), 14)
            B.damage(14 * (q.mul or 1), "ability")
            q.life = 0
          end
        end
      end
    end

    if not B.busy and t >= B.nextAttack and t >= B.riseUntil and t >= B.invUntil then
      B.busy = true
      local my = B.run
      local name = pickAttack()
      B.lastAtk = name
      task.spawn(function()
        local ok, err = pcall(ATK[name], my)
        if not ok then warn("[ORBIT] gaster boss " .. name .. ": " .. tostring(err)) end
        if B.run == my then
          B.busy, B.hold = false, false
          B.nextAttack = tick() + CFG[B.phase].gap + math.random() * 0.6
          resetCharge()
        end
      end)
    end
  end
end

-- ===== Экспорт =====
ORBIT.gaster = G
if ORBIT.gasterUnlocked == nil then ORBIT.gasterUnlocked = false end
G.registerShape()
ORBIT.loaded.gaster = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(G.destroy)
  if prevUnload then pcall(prevUnload) end
end
return true
