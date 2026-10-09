-- ORBIT v24.0 | orbit_gaster.lua
-- Мини-игра «Собери Гастера»: 8 осколков, финальная сцена, вечный орбитальный Гастер.
-- + Гастер-оружие (G.weapon) с правками v24.0: сохранение флага + очистка при unload.

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
  { id = "armL", nm = "Левая рука",  col = C3(190, 200, 235), shape = PT_BLOCK, sz = 2,   px = 0.16, py = 0.5,  sw = 18, sh = 52, z = 1 },
  { id = "armR", nm = "Правая рука", col = C3(190, 200, 235), shape = PT_BLOCK, sz = 2,   px = 0.84, py = 0.5,  sw = 18, sh = 52, z = 1 },
  { id = "torso",nm = "Туловище",    col = C3(150, 90, 230),  shape = PT_BLOCK, sz = 2.6, px = 0.5,  py = 0.5,  sw = 42, sh = 56, z = 1 },
  { id = "boots",nm = "Ботинки",     col = C3(110, 60, 200),  shape = PT_BLOCK, sz = 2.2, px = 0.5,  py = 0.87, sw = 58, sh = 20, z = 1 },
  { id = "core", nm = "Ядро",        col = C3(255, 90, 255),  shape = PT_BALL,  sz = 1.8, px = 0.5,  py = 0.5,  sw = 18, sh = 18, z = 4, round = true },
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

-- ===== Фигура ГАСТЕР БЛАСТЕР (кость, Metal) =====
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
  local charge = add("Charge", V3(0.3 * s, 0.3 * s, 0.3 * s), CF(0, -0.22 * s, -1.35 * s), C3(190, 90, 255), MAT.Neon, true, 0.2)
  charge.Shape = PT_BALL
  add("Beam", V3(0.28 * s, 0.22 * s, 1.4 * s), CF(0, -0.22 * s, -2.1 * s), C3(150, 70, 255), MAT.Neon, true, 0.35)
  local l = Instance.new("PointLight")
  l.Name = "GLight"; l.Color = C3(170, 90, 255); l.Range = 12; l.Brightness = 1.5; l.Parent = charge
  local e = Instance.new("ParticleEmitter")
  e.Name = "GSparks"; e.Color = ColorSequence.new(C3(190, 120, 255)); e.LightEmission = 1
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

-- ===== Мир: осколки =====
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
  local st = Instance.new("UIStroke"); st.Color = C3(160, 90, 255); st.Thickness = 2; st.Parent = win
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
  local title = lbl(10, 6, w - 20, 24, "👁 СОБЕРИ ГАСТЕРА", 16, C3(220, 190, 255))
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

-- ===== Игра =====
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

-- ===== Финальная сцена и фигура =====
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
  G.active = false
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
      TS:Create(cc, TweenInfo.new(1.5), { Brightness = -0.1, Saturation = -0.2, TintColor = C3(215, 195, 255) }):Play()
      ping("laugh", 1, 0.8)
      local sp = Instance.new("Part")
      sp.Anchored = true; sp.CanCollide = false; sp.CanQuery = false; sp.Transparency = 1; sp.Size = V3(8, 1, 8)
      sp.Position = root.Position - V3(0, 2.5, 0); sp.Parent = fold()
      local e = Instance.new("ParticleEmitter")
      e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.Color = ColorSequence.new(C3(25, 10, 45))
      e.Rate = 60; e.Lifetime = NumberRange.new(1, 2); e.Speed = NumberRange.new(3, 8); e.Size = NumberSequence.new(3, 5)
      e.Transparency = NumberSequence.new(0.3, 1); e.EmissionDirection = Enum.NormalId.Top; e.Parent = sp
      Debris:AddItem(sp, 6)
      for _ = 1, 6 do
        if not ok() then return end
        local c2, h2, r2 = getChar()
        if r2 then
          local o = r2.Position + V3(math.random(-12, 12), 0, math.random(-12, 12))
          zigzag(o + V3(0, 45, 0), o, C3(200, 150, 255), 0.5)
          burstAt(o, C3(200, 150, 255), 16)
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
        pcall(function() ORBIT.sans.voiceUntil = tick() + 5 end)
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
    p.Color = C3(170, 90, 255); p.Transparency = 0.3; p.Size = V3(1.6, 1.6, diff.Magnitude)
    p.CFrame = CFrame.lookAt((from + to) / 2, to); p.Parent = fold()
    TS:Create(p, TweenInfo.new(0.35), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.45)
  end
  burstAt(to, C3(190, 120, 255), 24)
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
      f.nextShot = t + math.random(4, 7)
      local tg = pickEnemy(center, 80)
      if tg then f.fire = { t0 = t, hum = tg.hum, root = tg.root, tpos = tg.root.Position } end
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
  if G.active then
    G.timer = G.timer - dt
    local _, _, root = getChar()
    for id, s in pairs(G.parts) do
      if not s.got and s.part and s.part.Parent and not s.flying then
        s.part.CFrame = CF(s.base + V3(0, math.sin(t * 2 + s.phase) * 0.6, 0)) * CFrame.Angles(0, t * 1.5 + s.phase, 0)
        if root and (root.Position - s.part.Position).Magnitude < 5 then G.collectPart(id) end
      end
    end
    local shown = math.floor(G.timer)
    if shown ~= lastShown and G.ui then lastShown = shown; G.ui.timer.Text = "⏱ " .. fmtTime(G.timer) end
    if G.active and G.timer <= 0 then fail() end
  end
  if G.figure then stepFigure(dt, t) end
end)

function G.open()
  if not alive then return false end
  if G.active then clearShards(); G.active = false end
  buildUI()
  return true
end

function G.destroy()
  if not alive then return end
  alive = false
  if G.heartbeat then pcall(function() G.heartbeat:Disconnect() end); G.heartbeat = nil end
  clearShards()
  closeUI()
  G.removeFigure()
  G.active = false
  -- v24.0: чистим и оружие, если оно было в руках
  if G.weapon and G.weapon.destroy then pcall(G.weapon.destroy) end
  if helperWrapped and ORBIT.helper and origInterp then pcall(function() ORBIT.helper.interpret = origInterp end) end
  if folder then pcall(function() folder:Destroy() end); folder = nil end
end

-- ===== ГАСТЕР В РУКАХ (G.weapon = W) =====
local W = { equipped = false, models = {}, proj = {}, cdUntil = 0, conns = {}, side = 1 }
local wFolder, wGui, wBtn = nil, nil, nil
local function wFold()
  if wFolder and wFolder.Parent then return wFolder end
  wFolder = Instance.new("Folder"); wFolder.Name = "OrbitAtmo_GasterWeapon_" .. LP.UserId; wFolder.Parent = WS
  return wFolder
end
local function wNotify(text) if ORBIT.notify then pcall(ORBIT.notify, text, C3(220, 200, 255), 3) end end
-- R15: LeftHand/RightHand (запас — LowerArm); R6: Left Arm/Right Arm
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
  return hand.CFrame * CF(0, -1, -1.2) -- у R6 рука — длинный блок, смещаем к кисти
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
  b.Material = MAT.Neon; b.Color = C3(190, 120, 255); b.Transparency = 0.3; b.Size = V3(1, 1, 1)
  b.CFrame = CF(pos); b.Parent = wFold()
  TS:Create(b, TweenInfo.new(0.35), { Size = V3(12, 12, 12), Transparency = 1 }):Play()
  Debris:AddItem(b, 0.5)
  burstAt(pos, C3(190, 120, 255), 24)
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
  p.Shape = PT_BALL; p.Size = V3(1.4, 1.4, 1.4); p.Material = MAT.Neon; p.Color = C3(190, 120, 255)
  p.CFrame = CF(origin); p:SetAttribute("NoRecolor", true); p.Parent = wFold()
  local l = Instance.new("PointLight"); l.Color = C3(190, 120, 255); l.Range = 12; l.Brightness = 3; l.Parent = p
  W.proj[#W.proj + 1] = { part = p, vel = dir * 140, born = t }
  burstAt(origin, C3(190, 120, 255), 10)
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
    wBtn.BackgroundColor3 = C3(70, 40, 130); wBtn.BackgroundTransparency = 0.1; wBtn.AutoButtonColor = false; wBtn.Parent = wGui
    Instance.new("UICorner", wBtn).CornerRadius = UDim.new(0, 28)
    local t0 = 0
    wBtn.InputBegan:Connect(function(i)
      if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then t0 = tick() end
    end)
    wBtn.InputEnded:Connect(function(i)
      if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        if tick() - t0 > 0.6 then W.unequip() else W.shoot() end -- удержание = снять, тап = выстрел
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
  -- v24.0: сохраняем флаг, чтобы после перезахода не требовать игру заново
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
