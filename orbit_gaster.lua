-- ORBIT v24.2 | orbit_gaster.lua
-- Мини-игра «Собери Гастера» + белое оружие (луч и заряд — БЕЛЫЕ, не фиолетовые)
-- v24.2: белая палитра, магнит осколков, улучшенная сцена, белый выстрел.

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

-- ✨ БЕЛАЯ палитра
local COL_BEAM   = C3(255, 255, 255)
local COL_CHARGE = C3(240, 250, 255)
local COL_GLOW   = C3(230, 240, 255)

local G = {
  active = false,
  parts = {},
  figure = nil,
  collector = { collected = 0, total = 8 },
  heartbeat = nil,
  ui = nil,
  timer = 120,
  shapeRegistered = false,
}
local alive, folder, token = true, nil, 0
local helperWrapped, origInterp = false, nil

local PARTS = {
  { id = "head", nm = "Голова",      col = C3(250, 245, 235), shape = PT_BLOCK, sz = 2.4, px = 0.5,  py = 0.14, sw = 46, sh = 34, z = 1 },
  { id = "eyeL", nm = "Левый глаз",  col = C3(120, 230, 255), shape = PT_BALL,  sz = 1.4, px = 0.4,  py = 0.13, sw = 10, sh = 10, z = 3, round = true },
  { id = "eyeR", nm = "Правый глаз", col = C3(120, 230, 255), shape = PT_BALL,  sz = 1.4, px = 0.6,  py = 0.13, sw = 10, sh = 10, z = 3, round = true },
  { id = "armL", nm = "Левая рука",  col = C3(220, 220, 235), shape = PT_BLOCK, sz = 2,   px = 0.16, py = 0.5,  sw = 18, sh = 52, z = 1 },
  { id = "armR", nm = "Правая рука", col = C3(220, 220, 235), shape = PT_BLOCK, sz = 2,   px = 0.84, py = 0.5,  sw = 18, sh = 52, z = 1 },
  { id = "torso",nm = "Туловище",    col = C3(200, 200, 220), shape = PT_BLOCK, sz = 2.6, px = 0.5,  py = 0.5,  sw = 42, sh = 56, z = 1 },
  { id = "boots",nm = "Ботинки",     col = C3(170, 170, 200), shape = PT_BLOCK, sz = 2.2, px = 0.5,  py = 0.87, sw = 58, sh = 20, z = 1 },
  { id = "core", nm = "Ядро",        col = C3(255, 255, 255), shape = PT_BALL,  sz = 1.8, px = 0.5,  py = 0.5,  sw = 18, sh = 18, z = 4, round = true },
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
  if not h or not r then return nil end
  return c, h, r
end

-- ===== Белый Гастер =====
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
  -- ✨ ЗАРЯД — БЕЛЫЙ
  local charge = add("Charge", V3(0.3 * s, 0.3 * s, 0.3 * s), CF(0, -0.22 * s, -1.35 * s), COL_CHARGE, MAT.Neon, true, 0.2)
  charge.Shape = PT_BALL
  -- ✨ ЛУЧ — БЕЛЫЙ
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

-- ===== Осколки =====
local function rayParams()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  local ex = { fold() }
  if LP.Character then ex[#ex + 1] = LP.Character end
  rp.FilterDescendantsInstances = ex
  return rp
end
local function clearShards()
  for _, s in pairs(G.parts) do
    if s.part then pcall(function() s.part:Destroy() end) end
  end
  G.parts = {}
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
function G.spawnParts()
  clearShards()
  local c, h, root = getChar()
  if not root then return false end
  local placed = {}
  local rp = rayParams()
  for _, def in ipairs(PARTS) do
    local pos
    for _ = 1, 10 do
      local a, d = math.random() * math.pi * 2, 15 + math.random() * 35
      local x, z = root.Position.X + math.cos(a) * d, root.Position.Z + math.sin(a) * d
      local res = WS:Raycast(V3(x, root.Position.Y + 60, z), V3(0, -200, 0), rp)
      pos = V3(x, (res and res.Position.Y or root.Position.Y) + 3, z)
      local ok = true
      for _, q in ipairs(placed) do if (q - pos).Magnitude < 8 then ok = false; break end end
      if ok then break end
    end
    placed[#placed + 1] = pos
    G.parts[def.id] = { def = def, part = makeShard(def, pos), base = pos, phase = math.random() * 6, got = false, flying = false }
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
local function fmtTime(t)
  t = math.max(0, math.floor(t))
  return string.format("%d:%02d", math.floor(t / 60), t % 60)
end
local function uiRefresh()
  local u = G.ui
  if not u then return end
  local n = 0
  for _, def in ipairs(PARTS) do
    local s = G.parts[def.id]
    local got = s and s.got
    if got then n = n + 1 end
    local sl = u.slots[def.id]
    sl.BackgroundColor3 = got and def.col or C3(70, 70, 85)
    sl.BackgroundTransparency = got and 0 or 0.45
  end
  G.collector.collected = n
  u.prog.Text = string.format("Собрано %d/%d", n, #PARTS)
  u.timer.Text = G.active and ("⏱ " .. fmtTime(G.timer)) or "⏱ 2:00"
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
  local w = math.min(360, vp.X - 24)
  local win = Instance.new("Frame")
  win.AnchorPoint = Vector2.new(0.5, 0); win.Position = UDim2.new(0.5, 0, 0, 10); win.Size = UDim2.fromOffset(w, 200)
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
  local title = lbl(10, 6, w - 20, 24, "👁 СОБЕРИ ГАСТЕРА", 16, C3(220, 220, 255))
  title.TextXAlignment = Enum.TextXAlignment.Center
  local sk = Instance.new("Frame")
  sk.Position = UDim2.fromOffset(8, 34); sk.Size = UDim2.fromOffset(120, 156); sk.BackgroundTransparency = 1; sk.Parent = win
  for _, def in ipairs(PARTS) do
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.fromScale(def.px, def.py); f.Size = UDim2.fromOffset(def.sw, def.sh)
    f.BackgroundColor3 = C3(70, 70, 85); f.BackgroundTransparency = 0.45; f.BorderSizePixel = 0; f.ZIndex = def.z; f.Parent = sk
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, def.round and 99 or 5)
    u.slots[def.id] = f
  end
  local x0, cw = 136, w - 144
  u.prog = lbl(x0, 34, cw, 22, "Собрано 0/8", 15)
  u.timer = lbl(x0, 58, cw, 22, "⏱ 2:00", 15)
  u.hint = lbl(x0, 82, cw, 40, "Подойди к осколку или нажми на него. Далёкие прилетят сами.", 11, C3(170, 160, 200))
  u.btnStart = btn(x0, 126, cw, "▶ СТАРТ")
  u.btnReset = btn(x0, 162, math.floor(cw / 2) - 2, "↺ СБРОС")
  u.btnClose = btn(x0 + math.floor(cw / 2) + 2, 162, math.floor(cw / 2) - 2, "✖ ЗАКРЫТЬ")
  u.btnReset.TextSize = 11; u.btnClose.TextSize = 11
  if ORBIT.gasterUnlocked then
    u.btnOn = btn(x0, 86, cw, "👁 ВКЛЮЧИТЬ ГАСТЕРА")
    u.btnOn.TextSize = 11; u.hint.Visible = false
    onClick(u.btnOn, function()
      if G.figure then G.removeFigure() else G.assemble(true) end
      uiRefresh()
    end, true)
  end
  onClick(u.btnStart, function() G.start() end, true)
  onClick(u.btnReset, function() G.reset() end, true)
  onClick(u.btnClose, function() G.close() end, true)
  G.ui = u
  uiRefresh()
end

function G.start()
  if not alive then return false end
  if G.active then toast("Игра уже идёт!"); return false end
  if not getChar() then return false end
  if not G.spawnParts() then return false end
  G.timer = 120; G.active = true
  ping("ping", 1, 1.2)
  toast("Собери все 8 осколков за 2 минуты!")
  uiRefresh()
  return true
end
function G.reset()
  clearShards()
  G.active = false; G.timer = 120
  toast("Сброшено. Нажми СТАРТ.")
  uiRefresh()
end
function G.close()
  if G.active then clearShards(); G.active = false end
  closeUI()
end
local function fail()
  clearShards()
  G.active = false
  ping("click", 1, 0.7)
  toast("Время вышло! Нажми СТАРТ.")
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
  if not alive or not G.active or not s or s.got or s.flying or not s.part then return false end
  local c, h, root = getChar()
  if not root then return false end
  local d = (root.Position - s.part.Position).Magnitude
  if d > 10 then
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

-- ===== Финал =====
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
  local f = { data = data, angle = 0, riseT = 0, next
