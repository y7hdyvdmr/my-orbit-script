-- ORBIT v25.2 | orbit_sans_boss.lua
-- Мини-игра «Собери Санса» (16 осколков + ловушки) + босс-файт.
-- v25.2: добавлена мини-игра сбора, Санс ходит по земле с анимацией шага.
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] sans_boss: нет ORBIT"); return false end
if ORBIT.sans_boss and ORBIT.sans_boss.destroy then pcall(ORBIT.sans_boss.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local PT_BALL, PT_BLOCK, MAT = Enum.PartType.Ball, Enum.PartType.Block, Enum.Material

local COL_BONE    = C3(245, 245, 250)
local COL_HOODIE  = C3(55, 115, 225)
local COL_EYE     = C3(0, 205, 255)
local COL_TRAP    = C3(255, 80, 120)
local COL_HP      = C3(255, 100, 100)
local COL_HP_BG   = C3(40, 20, 20)
local COL_UI_BG   = C3(15, 10, 25)

local S = {
  active = false,
  state = "idle",           -- idle | collecting | boss | won
  hp = 400, maxHp = 400, phase = 1,
  timer = 120, collected = 0,
  parts = {}, traps = {},
  boss = nil, bossUI = nil, collectUI = nil,
  folder = nil, shots = {},
  walkTarget = nil, nextRetarget = 0, nextDodge = 0,
  nextAttack = 0, attackIndex = 0, walkPhase = 0,
  hitTimes = {}, _origFireId = nil, hooked = false,
  _shapeRegistered = false,
}
local alive, token = true, 0
local conns = {}

local function connect(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local function ping(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end
local function fold()
  if S.folder and S.folder.Parent then return S.folder end
  S.folder = Instance.new("Folder")
  S.folder.Name = "OrbitSansBoss_" .. LP.UserId
  S.folder.Parent = WS
  return S.folder
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

-- ============================================================
--       16 ОСКОЛКОВ САНСА
-- ============================================================
local PARTS = {
  { id = "skull",     nm = "Череп",        col = C3(250, 250, 252), sz = 2.4, px = 0.5,  py = 0.10, sw = 46, sh = 32, z = 1 },
  { id = "eyeL",      nm = "Левый глаз",   col = C3(18, 18, 22),   sz = 1.2, px = 0.40, py = 0.15, sw = 10, sh = 8,  z = 3, round = true },
  { id = "eyeR",      nm = "Правый глаз",  col = C3(18, 18, 22),   sz = 1.2, px = 0.60, py = 0.15, sw = 10, sh = 8,  z = 3, round = true },
  { id = "eyeBlue",   nm = "Синий глаз",   col = COL_EYE,          sz = 1.2, px = 0.60, py = 0.15, sw = 8,  sh = 8,  z = 4, round = true },
  { id = "smile",     nm = "Ухмылка",      col = C3(18, 18, 22),   sz = 1.4, px = 0.5,  py = 0.24, sw = 40, sh = 8,  z = 3 },
  { id = "toothU",    nm = "Верхний зуб",  col = C3(255, 255, 255),sz = 1.0, px = 0.44, py = 0.28, sw = 8,  sh = 8,  z = 3 },
  { id = "toothL",    nm = "Нижний зуб",   col = C3(255, 255, 255),sz = 1.0, px = 0.56, py = 0.28, sw = 8,  sh = 8,  z = 3 },
  { id = "hoodie",    nm = "Толстовка",    col = COL_HOODIE,       sz = 2.4, px = 0.5,  py = 0.44, sw = 46, sh = 26, z = 1 },
  { id = "hoodRoll",  nm = "Капюшон",      col = COL_HOODIE,       sz = 1.6, px = 0.5,  py = 0.36, sw = 34, sh = 10, z = 2 },
  { id = "armL",      nm = "Левая рука",   col = C3(55, 115, 225), sz = 1.6, px = 0.20, py = 0.50, sw = 14, sh = 22, z = 1 },
  { id = "armR",      nm = "Правая рука",  col = C3(55, 115, 225), sz = 1.6, px = 0.80, py = 0.50, sw = 14, sh = 22, z = 1 },
  { id = "handL",     nm = "Левая кисть",  col = C3(250, 250, 252),sz = 1.2, px = 0.20, py = 0.62, sw = 10, sh = 10, z = 3, round = true },
  { id = "handR",     nm = "Правая кисть", col = C3(250, 250, 252),sz = 1.2, px = 0.80, py = 0.62, sw = 10, sh = 10, z = 3, round = true },
  { id = "shorts",    nm = "Шорты",        col = C3(18, 18, 22),   sz = 2.0, px = 0.5,  py = 0.64, sw = 40, sh = 14, z = 1 },
  { id = "slipperL",  nm = "Левый тапок",  col = C3(246, 246, 250),sz = 1.4, px = 0.36, py = 0.86, sw = 14, sh = 8,  z = 2, round = true },
  { id = "slipperR",  nm = "Правый тапок", col = C3(246, 246, 250),sz = 1.4, px = 0.64, py = 0.86, sw = 14, sh = 8,  z = 2, round = true },
}

-- ============================================================
--       СБОРКА ТЕЛА БОССА
-- ============================================================
local function buildSansBoss(size)
  local presets = ORBIT.SHAPE_PRESETS
  local sansPreset = nil
  if type(presets) == "table" then
    for _, p in ipairs(presets) do
      if p.name == "САНС" then sansPreset = p; break end
    end
  end
  if not sansPreset or type(sansPreset.create) ~= "function" then
    warn("[Orbit SansBoss] пресет САНС не найден")
    local m, r = ORBIT.newModelShell("SansBoss")
    return { model = m, root = r }
  end
  local ok, data = pcall(sansPreset.create, size, "SansBoss")
  if not ok or not data or not data.model then
    warn("[Orbit SansBoss] create() упал: " .. tostring(data))
    local m, r = ORBIT.newModelShell("SansBoss")
    return { model = m, root = r }
  end
  data.model.Parent = fold()
  local charge = nil
  for _, d in ipairs(data.model:GetDescendants()) do
    if d:IsA("BasePart") then
      if d.Name == "EyeGlow" then charge = d; break end
      if not charge and d.Material == Enum.Material.Neon and d.Color == COL_EYE then charge = d end
    end
  end
  return { model = data.model, root = data.part or data.model.PrimaryPart, charge = charge, bodyParts = data.bodyParts or {} }
end

local function buildBlaster(scale)
  local presets = ORBIT.SHAPE_PRESETS
  local bp = nil
  if type(presets) == "table" then
    for _, p in ipairs(presets) do
      if p.name == "ГАСТЕР БЛАСТЕР" then bp = p; break end
    end
  end
  if not bp or type(bp.create) ~= "function" then return nil end
  local ok, data = pcall(bp.create, scale or 0.6, "SansBossBlaster")
  if not ok or not data or not data.model then return nil end
  data.model.Parent = fold()
  return data.model
end

-- ============================================================
--       HP-БАР БОССА
-- ============================================================
local function showBossUI()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old = pg:FindFirstChild("_OrbitSansBoss")
  if old then old:Destroy() end
  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitSansBoss"; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 40; sg.Parent = pg

  local frame = Instance.new("Frame")
  frame.AnchorPoint = Vector2.new(0.5, 0); frame.Position = UDim2.new(0.5, 0, 0, 30)
  frame.Size = UDim2.new(0, 500, 0, 60)
  frame.BackgroundColor3 = COL_UI_BG; frame.BackgroundTransparency = 0.15; frame.Parent = sg
  Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
  local st = Instance.new("UIStroke", frame); st.Color = COL_EYE; st.Thickness = 2

  local nameLbl = Instance.new("TextLabel")
  nameLbl.Size = UDim2.new(1, -20, 0, 22); nameLbl.Position = UDim2.new(0, 10, 0, 4)
  nameLbl.BackgroundTransparency = 1; nameLbl.Text = "💀 САНС — ФАЗА 1"
  nameLbl.TextColor3 = C3(200, 230, 255); nameLbl.Font = Enum.Font.GothamBold
  nameLbl.TextSize = 14; nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.Parent = frame

  local hpBg = Instance.new("Frame")
  hpBg.Size = UDim2.new(1, -20, 0, 20); hpBg.Position = UDim2.new(0, 10, 0, 30)
  hpBg.BackgroundColor3 = COL_HP_BG; hpBg.BorderSizePixel = 0; hpBg.Parent = frame
  Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 6)

  local hpFill = Instance.new("Frame")
  hpFill.Size = UDim2.new(1, 0, 1, 0); hpFill.BackgroundColor3 = COL_HP
  hpFill.BorderSizePixel = 0; hpFill.Parent = hpBg
  Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 6)
  local gr = Instance.new("UIGradient", hpFill)
  gr.Color = ColorSequence.new(C3(255, 100, 100), C3(0, 205, 255)); gr.Rotation = 0

  local hpTxt = Instance.new("TextLabel")
  hpTxt.Size = UDim2.new(1, 0, 1, 0); hpTxt.BackgroundTransparency = 1
  hpTxt.Text = "400 / 400"; hpTxt.TextColor3 = C3(255, 255, 255)
  hpTxt.Font = Enum.Font.GothamBold; hpTxt.TextSize = 12; hpTxt.ZIndex = 2; hpTxt.Parent = hpBg

  S.bossUI = { sg = sg, frame = frame, nameLbl = nameLbl, hpFill = hpFill, hpTxt = hpTxt }
end

local function updateBossUI()
  if not S.bossUI or not S.active then return end
  local frac = math.clamp(S.hp / S.maxHp, 0, 1)
  S.bossUI.hpFill.Size = UDim2.new(frac, 0, 1, 0)
  S.bossUI.hpTxt.Text = math.floor(S.hp) .. " / " .. S.maxHp
  local phase = S.hp > S.maxHp * 0.66 and 1 or (S.hp > S.maxHp * 0.33 and 2 or 3)
  if phase ~= S.phase then
    S.phase = phase
    S.bossUI.nameLbl.Text = "💀 САНС — ФАЗА " .. phase
    if phase == 2 then S.bossUI.hpFill.BackgroundColor3 = C3(255, 130, 60)
    elseif phase == 3 then S.bossUI.hpFill.BackgroundColor3 = C3(255, 60, 60)
      if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack", true) end
    end
  end
end

local function hideBossUI()
  if S.bossUI and S.bossUI.sg then pcall(function() S.bossUI.sg:Destroy() end) end
  S.bossUI = nil
end
-- ============================================================
--       UI СБОРА ОСКОЛКОВ
-- ============================================================
local function fmtTime(t) t = math.max(0, math.floor(t)); return string.format("%d:%02d", math.floor(t / 60), t % 60) end

local function collectUIRefresh()
  local u = S.collectUI
  if not u then return end
  local n = 0
  for _, def in ipairs(PARTS) do
    local s = S.parts[def.id]
    local got = s and s.got
    if got then n = n + 1 end
    local sl = u.slots[def.id]
    if sl then
      sl.BackgroundColor3 = got and def.col or C3(60, 60, 80)
      sl.BackgroundTransparency = got and 0 or 0.5
    end
  end
  S.collected = n
  u.prog.Text = string.format("Собрано %d/%d", n, #PARTS)
  u.timer.Text = "⏱ " .. fmtTime(S.timer)
end

local function buildCollectUI()
  if S.collectUI and S.collectUI.sg then pcall(function() S.collectUI.sg:Destroy() end) end
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local sg = Instance.new("ScreenGui")
  sg.Name = "OrbitSansCollectGui"; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 25; sg.Parent = pg
  local cm = WS.CurrentCamera
  local vp = cm and cm.ViewportSize or Vector2.new(800, 400)
  local w = math.min(380, vp.X - 24)
  local win = Instance.new("Frame")
  win.AnchorPoint = Vector2.new(0.5, 0); win.Position = UDim2.new(0.5, 0, 0, 10)
  win.Size = UDim2.fromOffset(w, 210)
  win.BackgroundColor3 = C3(16, 14, 28); win.BackgroundTransparency = 0.1; win.Parent = sg
  Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
  local st = Instance.new("UIStroke"); st.Color = C3(120, 200, 255); st.Thickness = 2; st.Parent = win
  local u = { sg = sg, slots = {} }

  local title = Instance.new("TextLabel")
  title.Size = UDim2.fromOffset(w - 20, 24); title.Position = UDim2.fromOffset(10, 6)
  title.BackgroundTransparency = 1; title.Text = "💀 СОБЕРИ САНСА (16 осколков)"
  title.TextSize = 15; title.TextColor3 = C3(220, 240, 255)
  title.Font = Enum.Font.GothamBold; title.TextXAlignment = Enum.TextXAlignment.Center
  title.Parent = win

  -- сетка 4×4 частей
  local sk = Instance.new("Frame")
  sk.Position = UDim2.fromOffset(8, 34); sk.Size = UDim2.fromOffset(120, 168)
  sk.BackgroundTransparency = 1; sk.Parent = win
  for _, def in ipairs(PARTS) do
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale(def.px, def.py)
    f.Size = UDim2.fromOffset(math.max(def.sw * 0.7, 8), math.max(def.sh * 0.7, 6))
    f.BackgroundColor3 = C3(60, 60, 80); f.BackgroundTransparency = 0.5
    f.BorderSizePixel = 0; f.ZIndex = def.z; f.Parent = sk
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, def.round and 99 or 4)
    u.slots[def.id] = f
  end

  local x0, cw = 136, w - 144
  local function lbl(x, y, ww, hh, txt, size, col)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Position = UDim2.fromOffset(x, y)
    l.Size = UDim2.fromOffset(ww, hh); l.Text = txt; l.TextSize = size
    l.TextColor3 = col or C3(235, 225, 255); l.Font = Enum.Font.GothamBold
    l.TextWrapped = true; l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top; l.Parent = win
    return l
  end
  u.prog = lbl(x0, 34, cw, 22, "Собрано 0/16", 15)
  u.timer = lbl(x0, 58, cw, 22, "⏱ 2:00", 15)
  u.hint = lbl(x0, 82, cw, 44, "Осколки летают. Ловушки розовые — минус осколок! Собирай все 16.", 10, C3(170, 160, 200))

  local function btn(x, y, ww, txt, col)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y); b.Size = UDim2.fromOffset(ww, 32)
    b.Text = txt; b.TextSize = 13; b.Font = Enum.Font.GothamBold
    b.TextColor3 = C3(255, 255, 255); b.BackgroundColor3 = col or C3(70, 40, 130)
    b.AutoButtonColor = false; b.Parent = win
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
  end
  u.btnReset = btn(x0, 168, math.floor(cw / 2) - 2, "↺ СБРОС", C3(130, 50, 50))
  u.btnClose = btn(x0 + math.floor(cw / 2) + 2, 168, math.floor(cw / 2) - 2, "✖ СКРЫТЬ", C3(70, 40, 130))

  local function onClick(btn, fn)
    local deb = false
    local function call()
      if deb then return end
      deb = true
      task.delay(0.15, function() deb = false end)
      pcall(fn)
    end
    btn.MouseButton1Down:Connect(call)
    btn.Activated:Connect(call)
  end
  onClick(u.btnReset, function() S.stopCollect() end)
  onClick(u.btnClose, function()
    if u.sg then u.sg.Enabled = false end
    if ORBIT.notify then ORBIT.notify("UI скрыт. Открыть: кнопка боссов в меню", C3(200, 220, 255), 3) end
  end)

  S.collectUI = u
  collectUIRefresh()
end

-- ============================================================
--       ОСКОЛКИ И ЛОВУШКИ
-- ============================================================
local function clearShards()
  for _, s in pairs(S.parts) do if s.part then pcall(function() s.part:Destroy() end) end end
  S.parts = {}
  for _, t in pairs(S.traps) do if t.part then pcall(function() t.part:Destroy() end) end end
  S.traps = {}
end

local function makeShard(def, pos)
  local p = ORBIT.newPart(fold(), "SansShard_" .. def.id, V3(def.sz, def.sz, def.sz), CF(pos), def.col)
  p.Shape = PT_BALL
  p.Material = MAT.Neon
  p:SetAttribute("NoRecolor", true)
  local l = Instance.new("PointLight"); l.Color = def.col; l.Range = 14; l.Brightness = 2.5; l.Parent = p
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(def.col); e.LightEmission = 1
  e.Size = NumberSequence.new(0.5, 0); e.Lifetime = NumberRange.new(0.6, 1.2)
  e.Speed = NumberRange.new(2, 5); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 25; e.Parent = p
  local bb = Instance.new("BillboardGui")
  bb.Size = UDim2.new(0, 120, 0, 20); bb.StudsOffset = V3(0, def.sz + 1, 0); bb.AlwaysOnTop = true; bb.Parent = p
  local lbl = Instance.new("TextLabel")
  lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
  lbl.Text = def.nm; lbl.TextColor3 = C3(255, 255, 255)
  lbl.TextStrokeTransparency = 0; lbl.Font = Enum.Font.Code; lbl.TextScaled = true
  lbl.Parent = bb
  return p
end

local function makeTrap(pos, r)
  local p = ORBIT.newPart(fold(), "SansTrap", V3(r, r, r), CF(pos), COL_TRAP)
  p.Shape = PT_BALL
  p.Material = MAT.Neon
  p.Transparency = 0.35
  p:SetAttribute("NoRecolor", true)
  local l = Instance.new("PointLight"); l.Color = COL_TRAP; l.Range = 12; l.Brightness = 2; l.Parent = p
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(COL_TRAP); e.LightEmission = 1
  e.Size = NumberSequence.new(0.6, 0); e.Lifetime = NumberRange.new(0.4, 0.8)
  e.Speed = NumberRange.new(3, 8); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 60; e.Parent = p
  return p
end

local function spawnParts()
  clearShards()
  local c, h, root = getChar()
  if not root then return false end
  local rp = rayParams()
  local placed = {}
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
    S.parts[def.id] = {
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
    S.traps[#S.traps + 1] = {
      part = p, r = r, angle = a, baseRadius = d,
      baseY = pos.Y, bobPhase = math.random() * 6,
      angleSpeed = 0.4 + math.random() * 0.4,
      hitCooldown = 0,
    }
  end
  return true
end

local function finalizePart(id)
  local s = S.parts[id]
  if not s or s.got then return end
  s.got = true
  if s.part then pcall(function() s.part:Destroy() end); s.part = nil end
  ping("botCollect", 1, 1)
  collectUIRefresh()
  local n = 0
  for _, q in pairs(S.parts) do if q.got then n = n + 1 end end
  if n >= #PARTS then
    if S.collectUI and S.collectUI.sg then pcall(function() S.collectUI.sg:Destroy() end); S.collectUI = nil end
    task.delay(0.5, function() S.startBoss() end)
  end
end

function S.collectPart(id)
  local s = S.parts[id]
  if not alive or S.state ~= "collecting" or not s or s.got or s.flying or not s.part then return false end
  local c, h, root = getChar()
  if not root then return false end
  local d = (root.Position - s.part.Position).Magnitude
  if d > 12 then
    s.flying = true
    local tt = math.clamp(d / 70, 0.2, 1.2)
    local tw = TS:Create(s.part, TweenInfo.new(tt, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CF(root.Position) })
    tw.Completed:Connect(function() if alive and S.parts[id] == s then finalizePart(id) end end)
    tw:Play()
    return true
  end
  finalizePart(id)
  return true
end

local function trapHit(trap)
  if not trap or trap.hitCooldown > tick() then return end
  trap.hitCooldown = tick() + 2
  for id, s in pairs(S.parts) do
    if s.got then s.got = false; break end
  end
  ping("click", 1, 0.5)
  if ORBIT.notify then ORBIT.notify("⚠️ Ловушка! Осколок потерян", C3(255, 100, 100), 2) end
  collectUIRefresh()
  local bp = ORBIT.newPart(fold(), "Fx", V3(0.2, 0.2, 0.2), CF(trap.part.Position), COL_TRAP, true)
  bp.Transparency = 1
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(COL_TRAP); e.LightEmission = 1
  e.Size = NumberSequence.new(1.5, 0); e.Lifetime = NumberRange.new(0.5, 1)
  e.Speed = NumberRange.new(15, 25); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0
  e.Parent = bp
  e:Emit(50)
  Debris:AddItem(bp, 1.5)
end

local function stepShards(dt, t)
  if S.state ~= "collecting" then return end
  for id, s in pairs(S.parts) do
    if not s.got and s.part and s.part.Parent and not s.flying then
      local ang = t * s.speed + s.phase
      local offset = V3(math.cos(ang) * s.radius, math.sin(t * 2 + s.phase) * 0.8, math.sin(ang) * s.radius)
      s.part.CFrame = CF(s.base + offset) * CFrame.Angles(0, t * 1.5 + s.phase, 0)
    end
  end
end

local function stepTraps(dt, t)
  if S.state ~= "collecting" then return end
  local c, h, root = getChar()
  if not root then return end
  for _, tr in ipairs(S.traps) do
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

-- ============================================================
--       ХОДЬБА ПО ЗЕМЛЕ + АНИМАЦИЯ
-- ============================================================
local function collectLegs(model)
  local legs = {}
  for _, d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") and (d.Name == "Slipper" or d.Name:find("Slipper")) then
      legs[#legs + 1] = { p = d, baseRel = d.CFrame, side = (d.Position.X > model:GetPivot().Position.X) and 1 or -1 }
    end
  end
  return legs
end

local function playWalkAnim(model, phase, dt)
  if not model or not model.PrimaryPart then return end
  local pivot = model:GetPivot()
  local sway = math.sin(phase * 2) * math.rad(3)
  local bob = math.abs(math.sin(phase)) * 0.08
  pcall(function()
    model:PivotTo(pivot * CFrame.Angles(0, 0, sway) + V3(0, bob, 0))
  end)
  -- ноги: поочерёдно вперёд/назад по Z
  local legPhase = math.sin(phase)
  local legs = S._legs
  if not legs then legs = collectLegs(model); S._legs = legs end
  for _, l in ipairs(legs) do
    if l.p.Parent then
      local zShift = (l.side > 0) and legPhase or -legPhase
      local newCF = model.PrimaryPart.CFrame * (l.baseRel - l.baseRel.Position) 
        * CF(0, 0, zShift * 0.35)
      -- сохраняем относительную позицию
      local rel = model.PrimaryPart.CFrame:ToObjectSpace(l.baseRel)
      pcall(function() l.p.CFrame = model.PrimaryPart.CFrame * rel * CF(0, 0, zShift * 0.35) end)
    end
  end
end

local function findWalkTarget(center, bossPos)
  -- цель — точка вокруг игрока, но не вплотную
  local angle = math.random() * math.pi * 2
  local dist = 5 + math.random() * 3
  local target = center + V3(math.cos(angle) * dist, 0, math.sin(angle) * dist)
  local ground = groundAt(target)
  return V3(ground.X, ground.Y + 3, ground.Z)
end

local function stepBossMovement(dt, t)
  if not S.boss or not S.boss.root then return end
  local c, h, r = getChar()
  if not r then return end
  local bossPos = S.boss.root.Position
  local playerPos = r.Position

  -- пересчёт цели раз в 1.5 сек
  if not S.walkTarget or t >= S.nextRetarget or (S.walkTarget - bossPos).Magnitude < 1.5 then
    S.nextRetarget = t + 1.5
    S.walkTarget = findWalkTarget(playerPos, bossPos)
  end

  -- додж — рывок вбок
  if t >= S.nextDodge then
    S.nextDodge = t + 2.5 + math.random() * 2
    local away = bossPos - playerPos
    away = V3(away.X, 0, away.Z)
    if away.Magnitude > 0.1 then
      local side = away.Unit:Cross(V3(0, 1, 0)) * (math.random() < 0.5 and 1 or -1)
      local dodgeTo = groundAt(bossPos + side * 6)
      S.walkTarget = V3(dodgeTo.X, dodgeTo.Y + 3, dodgeTo.Z)
      S.nextRetarget = t + 0.8
      ping("dodge", 0.8, 1.4)
      if math.random() < 0.3 and ORBIT.sans and ORBIT.sans.say then
        pcall(ORBIT.sans.say, "dodge")
      end
    end
  end

  -- движение к цели по земле
  local target = S.walkTarget or bossPos
  local diff = V3(target.X - bossPos.X, 0, target.Z - bossPos.Z)
  local dist = diff.Magnitude
  if dist > 0.8 then
    local speed = 10
    local step = math.min(dist, speed * dt)
    local dir = diff.Unit
    local newPos = bossPos + dir * step
    local groundY = target.Y
    local finalPos = V3(newPos.X, groundY, newPos.Z)
    pcall(function() S.boss.model:PivotTo(CFrame.lookAt(finalPos, finalPos + dir)) end)
    S.walkPhase = S.walkPhase + dt * 10
    playWalkAnim(S.boss.model, S.walkPhase, dt)
  else
    -- стоит: покачивание дыхания
    S.walkPhase = S.walkPhase + dt * 2
    local bob = math.sin(S.walkPhase) * 0.05
    pcall(function()
      local pivot = S.boss.model:GetPivot()
      S.boss.model:PivotTo(pivot + V3(0, bob, 0))
    end)
  end
end

-- ============================================================
--       АТАКИ
-- ============================================================
local function spawnBoneShot(origin, dirv, dmg, speed, size)
  size = size or 0.5
  local p = ORBIT.newPart(fold(), "BossBone", V3(size, size, 2.8 * size), CF(origin), COL_BONE)
  p.CFrame = CFrame.lookAt(origin, origin + dirv)
  p:SetAttribute("NoRecolor", true)
  p.Material = MAT.SmoothPlastic
  for _, sz in ipairs({1, -1}) do
    for _, sx in ipairs({-1, 1}) do
      local lobe = ORBIT.newPart(fold(), "Lobe", V3(size * 1.05, size * 1.05, size * 1.05), CF(), COL_BONE, true)
      lobe.Shape = PT_BALL
      lobe.Material = MAT.SmoothPlastic
      lobe.CFrame = p.CFrame * CF(sx * size * 0.42, 0, sz * 1.4 * size)
      lobe.Parent = p
    end
  end
  S.shots[#S.shots + 1] = { part = p, vel = dirv * speed, life = 3, dmg = dmg }
end

local function attackBoneVolley()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local from = S.boss.root.Position + V3(0, 2, 0)
  local to = r.Position
  local baseDir = (to - from).Unit
  local n = S.phase >= 2 and 5 or 3
  local spreadDeg = S.phase >= 2 and 20 or 14
  for i = 1, n do
    local a = (i - (n + 1) / 2) * spreadDeg
    local d = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(baseDir)
    task.delay((i - 1) * 0.07, function()
      if alive and S.active then spawnBoneShot(from, d, 20, 60, 0.5) end
    end)
  end
  ping("snap", 0.8, 1.4)
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack") end
end

local function attackBlasterPair()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local center = r.Position
  local bossPos = S.boss.root.Position
  local sideDir = V3(center.X - bossPos.X, 0, center.Z - bossPos.Z)
  if sideDir.Magnitude > 0.1 then sideDir = sideDir.Unit else sideDir = V3(1, 0, 0) end
  local right = sideDir:Cross(V3(0, 1, 0)).Unit
  for _, sd in ipairs({-1, 1}) do
    local spos = center + right * (sd * 12) + V3(0, 6, 0) - sideDir * 4
    local m = buildBlaster(0.55)
    if m then
      pcall(function() m:PivotTo(CFrame.lookAt(spos, center)) end)
      local charge = m:FindFirstChild("Charge", true) or m.PrimaryPart
      task.delay(0.4, function()
        if not alive or not S.active then pcall(function() m:Destroy() end); return end
        local beamFrom = charge and charge.Position or spos
        local len = (center - beamFrom).Magnitude
        if len > 1 then
          local core = ORBIT.newPart(fold(), "Beam", V3(1.4, 1.4, len), CF(), C3(255, 255, 255))
          core.CFrame = CFrame.lookAt((beamFrom + center) / 2, center)
          local outer = ORBIT.newPart(fold(), "BeamOut", V3(2.5, 2.5, len), CF(), COL_EYE)
          outer.CFrame = core.CFrame; outer.Transparency = 0.65
          local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 20; l.Brightness = 6; l.Parent = core
          TS:Create(core, TweenInfo.new(0.5), { Size = V3(0.1, 0.1, len), Transparency = 1 }):Play()
          TS:Create(outer, TweenInfo.new(0.55), { Size = V3(0.15, 0.15, len), Transparency = 1 }):Play()
          TS:Create(l, TweenInfo.new(0.6), { Brightness = 0 }):Play()
          Debris:AddItem(core, 0.7); Debris:AddItem(outer, 0.8)
        end
        local cc, hh, rr = getChar()
        if rr then
          local rel = rr.Position - beamFrom
          local dirv = (center - beamFrom).Unit
          local tp = math.clamp(rel:Dot(dirv), 0, len)
          if (rr.Position - (beamFrom + dirv * tp)).Magnitude <= 4 then
            pcall(function() hh:TakeDamage(18) end)
            S.hitTimes[#S.hitTimes + 1] = tick()
          end
        end
        ping("snap", 1, 0.6)
        task.delay(0.3, function() pcall(function() m:Destroy() end) end)
      end)
    end
  end
  ping("snap", 0.9, 0.7)
end

local function attackTeleportStrike()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local oldPos = S.boss.root.Position
  for i = 1, 8 do
    local p = ORBIT.newPart(fold(), "TpSpark", V3(0.5, 0.5, 0.5), CF(), COL_EYE)
    p.Shape = PT_BALL; p.Transparency = 0.2
    p.CFrame = CF(oldPos + V3(math.random(-3, 3), math.random(0, 4), math.random(-3, 3)))
    local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 8; l.Brightness = 4; l.Parent = p
    TS:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.5)
  end
  -- появляется за спиной игрока на земле
  local behind = r.CFrame.LookVector * -3
  local rawPos = r.Position + V3(behind.X, 0, behind.Z)
  local gp = groundAt(rawPos)
  local newPos = V3(gp.X, gp.Y + 3, gp.Z)
  pcall(function() S.boss.model:PivotTo(CFrame.lookAt(newPos, r.Position)) end)
  S.walkTarget = newPos
  S.nextRetarget = tick() + 1.2
  for i = 1, 10 do
    local p = ORBIT.newPart(fold(), "TpSpark", V3(0.6, 0.6, 0.6), CF(), COL_EYE)
    p.Shape = PT_BALL; p.Transparency = 0.1
    p.CFrame = CF(newPos + V3(math.random(-2, 2), math.random(0, 4), math.random(-2, 2)))
    local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 10; l.Brightness = 5; l.Parent = p
    TS:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.6)
  end
  task.delay(0.35, function()
    if not alive or not S.active then return end
    local c2, h2, r2 = getChar()
    if not r2 then return end
    local shotPos = S.boss.root.Position + V3(0, 1.5, 0)
    local d = (r2.Position - shotPos).Unit
    spawnBoneShot(shotPos, d, 35, 100, 0.7)
    ping("snap", 1, 1.2)
    if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack", true) end
  end)
end

local function attackBlueEye()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local eyePos = S.boss.root.Position + V3(0, 3.5, 0)
  local sphere = ORBIT.newPart(fold(), "BlueEye", V3(2, 2, 2), CF(eyePos), COL_EYE)
  sphere.Shape = PT_BALL; sphere.Transparency = 0.3
  local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 30; l.Brightness = 8; l.Parent = sphere
  TS:Create(sphere, TweenInfo.new(0.7), { Size = V3(50, 50, 50), Transparency = 1 }):Play()
  TS:Create(l, TweenInfo.new(0.9), { Brightness = 0 }):Play()
  Debris:AddItem(sphere, 1)
  local _, hh, rr = getChar()
  if hh and rr and (rr.Position - eyePos).Magnitude <= 25 then
    pcall(function() hh:TakeDamage(8) end)
  end
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack") end
end

-- ============================================================
--       ХУК УРОНА
-- ============================================================
local function hookDamage()
  local ab = ORBIT.abilities
  if not ab or type(ab.fireId) ~= "function" then return end
  if S.hooked then return end
  S.hooked = true
  S._origFireId = ab.fireId
  local orig = ab.fireId
  ab.fireId = function(id, ch)
    local r = orig(id, ch)
    if r and S.active and S.boss and S.state == "boss" then
      local c, h, rr = getChar()
      if rr then
        local bd = (S.boss.root.Position - rr.Position).Magnitude
        if bd <= 60 then
          local dmgVal = ch and 45 or 25
          local dodgeChance = S.phase == 1 and 0.25 or (S.phase == 2 and 0.18 or 0.10)
          if math.random() < dodgeChance then
            if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "dodge") end
            ping("dodge", 1, 1.5)
          else
            S.hp = math.max(0, S.hp - dmgVal)
            updateBossUI()
            S.hitTimes[#S.hitTimes + 1] = tick()
            local hit = ORBIT.newPart(fold(), "Hit", V3(1.5, 1.5, 1.5), CF(S.boss.root.Position + V3(0, 2, 0)), C3(255, 200, 100))
            hit.Shape = PT_BALL; hit.Transparency = 0.2
            local l = Instance.new("PointLight"); l.Color = C3(255, 200, 100); l.Range = 12; l.Brightness = 6; l.Parent = hit
            TS:Create(hit, TweenInfo.new(0.35), { Size = V3(6, 6, 6), Transparency = 1 }):Play()
            TS:Create(l, TweenInfo.new(0.5), { Brightness = 0 }):Play()
            Debris:AddItem(hit, 0.5)
            ping("ping", 1, 1.4)
            if S.hp <= 0 then S.winBoss() end
          end
        end
      end
    end
    return r
  end
end

local function unhookDamage()
  local ab = ORBIT.abilities
  if ab and S.hooked and S._origFireId then
    pcall(function() ab.fireId = S._origFireId end)
  end
  S.hooked = false
  S._origFireId = nil
end

-- ============================================================
--       ШАГ СНАРЯДОВ
-- ============================================================
local function stepShots(dt)
  if #S.shots == 0 then return end
  local rp = rayParams()
  for i = #S.shots, 1, -1 do
    local q = S.shots[i]
    if not q.part or not q.part.Parent or tick() > (q.born or 0) + q.life then
      if q.part and q.part.Parent then pcall(function() q.part:Destroy() end) end
      table.remove(S.shots, i)
    else
      local from = q.part.Position
      local to = from + q.vel * dt
      local hitPos
      local res = WS:Raycast(from, to - from, rp)
      if res then hitPos = res.Position end
      local c, h, r = getChar()
      if not hitPos and r and (r.Position - to).Magnitude < 3 then hitPos = to end
      if hitPos then
        table.remove(S.shots, i)
        pcall(function() q.part:Destroy() end)
        local _, hh, rr = getChar()
        if hh and rr and (rr.Position - hitPos).Magnitude <= 6 then
          pcall(function() hh:TakeDamage(q.dmg) end)
          S.hitTimes[#S.hitTimes + 1] = tick()
        end
        local burst = ORBIT.newPart(fold(), "Burst", V3(2, 2, 2), CF(hitPos), COL_BONE)
        burst.Shape = PT_BALL; burst.Transparency = 0.3
        local l = Instance.new("PointLight"); l.Color = COL_BONE; l.Range = 10; l.Brightness = 4; l.Parent = burst
        TS:Create(burst, TweenInfo.new(0.3), { Size = V3(7, 7, 7), Transparency = 1 }):Play()
        Debris:AddItem(burst, 0.4)
      else
        q.part.CFrame = CFrame.lookAt(to, to + q.vel)
      end
    end
  end
end
-- ============================================================
--       ЗАПУСК МИНИ-ИГРЫ СБОРА
-- ============================================================
function S.startCollect()
  if not alive then return false end
  if S.state == "collecting" or S.state == "boss" then
    if ORBIT.notify then ORBIT.notify("Игра уже идёт!", C3(255, 200, 120), 2) end
    return false
  end
  if not getChar() then return false end
  if not spawnParts() then return false end
  S.state = "collecting"
  S.timer = 120
  S.collected = 0
  S._legs = nil
  buildCollectUI()
  ping("ping", 1, 1.2)
  if ORBIT.notify then
    ORBIT.notify("💀 Собери 16 осколков Санса!", C3(200, 230, 255), 3)
    ORBIT.notify("⚠️ Осторожно — розовые ловушки!", C3(255, 150, 180), 3)
  end
  if ORBIT.sans and ORBIT.sans.say then
    task.delay(0.5, function() pcall(ORBIT.sans.say, "greet", true) end)
  end
  return true
end

function S.stopCollect()
  clearShards()
  if S.collectUI and S.collectUI.sg then pcall(function() S.collectUI.sg:Destroy() end) end
  S.collectUI = nil
  S.state = "idle"
  S.timer = 120
  if ORBIT.notify then ORBIT.notify("↺ Сбор отменён", C3(255, 200, 120), 2) end
end

-- ============================================================
--       СТАРТ БОССА
-- ============================================================
function S.startBoss()
  if not alive then return end
  S.state = "boss"
  S.active = true
  S.hp = 400
  S.maxHp = 400
  S.phase = 1
  S.attackIndex = 0
  S.nextAttack = tick() + 2
  S.nextRetarget = 0
  S.nextDodge = tick() + 3
  S.walkPhase = 0
  S._legs = nil
  S.walkTarget = nil
  S.shots = {}
  S.hitTimes = {}
  clearShards()

  local c, h, r = getChar()
  if not r then return end

  -- создаём модель босса на земле перед игроком
  local data = buildSansBoss(3)
  local spawnPos = r.Position + r.CFrame.LookVector * 15
  local gp = groundAt(spawnPos)
  local finalPos = V3(gp.X, gp.Y + 3, gp.Z)
  pcall(function() data.model:PivotTo(CFrame.lookAt(finalPos, r.Position)) end)
  S.boss = {
    data = data,
    root = data.part or data.model.PrimaryPart,
    model = data.model,
  }
  S.walkTarget = finalPos

  -- лёгкая цветокоррекция
  local cc = Instance.new("ColorCorrectionEffect")
  cc.Name = "OrbitSansBossCC"; cc.Parent = Lighting
  S.cc = cc
  TS:Create(cc, TweenInfo.new(1.2), {
    Brightness = -0.12, Saturation = -0.15, TintColor = C3(230, 235, 255)
  }):Play()

  showBossUI()
  updateBossUI()
  hookDamage()
  ping("laugh", 1, 0.9)

  if ORBIT.sans and ORBIT.sans.say then
    task.delay(0.4, function() pcall(ORBIT.sans.say, "greet", true) end)
    task.delay(1.2, function() pcall(ORBIT.sans.say, "taunt", true) end)
  end
  if ORBIT.notify then
    ORBIT.notify("💀 САНС ВЫШЕЛ НА БОЙ!", C3(200, 230, 255), 4)
    ORBIT.notify("⚔ Используй свои стихии — наноси урон!", C3(255, 200, 120), 5)
  end
end

-- ============================================================
--       ПОБЕДА — 5 НАГРАД
-- ============================================================
local REWARDS = {
  { id = "sans_knife",       name = "🦴 Костяной клинок",      desc = "Оружие: веер из 3 костей" },
  { id = "blue_eye",         name = "💧 Синий глаз",           desc = "Возрождение 1 раз в 30 сек" },
  { id = "coins",            name = "💰 +500 монет",           desc = "Валюта в магазине" },
  { id = "sans_chat",        name = "💬 Санс в чате",          desc = "Пишет фразы при победах" },
  { id = "sans_boss_skin",   name = "🎨 Скин «Санс-босс»",     desc = "Открыт в магазине" },
}

function S.winBoss()
  if not S.active then return end
  S.active = false
  S.state = "won"
  hideBossUI()
  unhookDamage()

  local bossPos = S.boss and S.boss.root and S.boss.root.Position or V3(0, 5, 0)
  for i = 1, 8 do
    task.delay(i * 0.1, function()
      if not alive then return end
      local p = ORBIT.newPart(fold(), "Reward", V3(1.5, 1.5, 1.5), CF(), COL_BONE)
      p.Shape = PT_BALL; p.Transparency = 0.2
      p.CFrame = CF(bossPos + V3(math.random(-8, 8), math.random(-4, 8), math.random(-8, 8)))
      local l = Instance.new("PointLight"); l.Color = COL_BONE; l.Range = 12; l.Brightness = 5; l.Parent = p
      TS:Create(p, TweenInfo.new(0.7), { Size = V3(12, 12, 12), Transparency = 1 }):Play()
      TS:Create(l, TweenInfo.new(0.9), { Brightness = 0 }):Play()
      Debris:AddItem(p, 1)
      ping("ping", 1, 0.8 + i * 0.1)
    end)
  end

  if ORBIT.sans and ORBIT.sans.say then
    task.delay(0.6, function() pcall(ORBIT.sans.say, "victory", true) end)
    task.delay(2.0, function()
      if ORBIT.sans.showAt and LP.Character then
        local head = LP.Character:FindFirstChild("Head")
        if head then
          pcall(ORBIT.sans.showAt, head.Position + V3(0, 3, 0), "забирай. заслужил.", 4)
        end
      end
    end)
  end
  ping("sans", 1, 1)

  task.delay(1.2, function()
    if S.boss and S.boss.model then pcall(function() S.boss.model:Destroy() end) end
    S.boss = nil
  end)

  task.delay(1.5, function()
    if S.cc then
      TS:Create(S.cc, TweenInfo.new(1.2), { Brightness = 0, Saturation = 0, TintColor = C3(255, 255, 255) }):Play()
      task.delay(1.5, function()
        if S.cc then pcall(function() S.cc:Destroy() end); S.cc = nil end
      end)
    end
  end)

  ORBIT.saveData = ORBIT.saveData or {}
  ORBIT.saveData.rewards = ORBIT.saveData.rewards or {}
  local given = {}
  for _, rw in ipairs(REWARDS) do
    if not ORBIT.saveData.rewards[rw.id] then
      ORBIT.saveData.rewards[rw.id] = true
      given[#given + 1] = rw
    end
  end
  ORBIT.COINS = (ORBIT.COINS or 0) + 500
  ORBIT.sansUnlocked = true
  ORBIT.sansKnifeUnlocked = true
  ORBIT.sansBlueEyeUnlocked = true
  ORBIT.saveData.sansUnlocked = true
  ORBIT.saveData.sansKnifeUnlocked = true
  ORBIT.saveData.sansBlueEyeUnlocked = true
  if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
  if ORBIT.saveStorage then pcall(ORBIT.saveStorage) end

  if ORBIT.notify then
    ORBIT.notify("🏆 САНС ПОВЕРЖЕН!", C3(180, 255, 200), 5)
    for i, rw in ipairs(given) do
      task.delay(0.5 + i * 0.6, function()
        ORBIT.notify(rw.name .. " — " .. rw.desc, C3(200, 220, 255), 4)
      end)
    end
  end

  task.delay(5, function()
    if alive then
      S.state = "idle"
      S.hp = 400
      S.timer = 120
    end
  end)
end

-- ============================================================
--       ПРОВАЛ
-- ============================================================
function S.failBoss(reason)
  if not S.active then return end
  S.active = false
  S.state = "lost"
  hideBossUI()
  unhookDamage()
  if S.boss and S.boss.model then pcall(function() S.boss.model:Destroy() end) end
  S.boss = nil
  if S.cc then pcall(function() S.cc:Destroy() end); S.cc = nil end

  if ORBIT.sans and ORBIT.sans.say then
    task.delay(0.3, function() pcall(ORBIT.sans.say, "taunt", true) end)
    task.delay(1.2, function()
      if ORBIT.sans.showAt and LP.Character then
        local head = LP.Character:FindFirstChild("Head")
        if head then
          pcall(ORBIT.sans.showAt, head.Position + V3(0, 3, 0), reason or "время вышло. спишемся.", 4)
        end
      end
    end)
  end
  ping("click", 1, 0.5)
  if ORBIT.notify then
    ORBIT.notify("💀 Санс ушёл... " .. (reason or "время вышло"), C3(255, 180, 180), 4)
  end
  task.delay(3, function()
    if alive then
      S.state = "idle"
      S.hp = 400
      S.timer = 120
    end
  end)
end

-- ============================================================
--       ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function stepBoss(dt, t)
  if not S.active or S.state ~= "boss" then return end
  updateBossUI()
  stepBossMovement(dt, t)

  local attackInterval = S.phase == 1 and 3.5 or (S.phase == 2 and 2.5 or 1.8)
  if t >= S.nextAttack then
    S.nextAttack = t + attackInterval
    S.attackIndex = (S.attackIndex + 1) % 4
    local which = S.attackIndex
    if S.phase == 1 then which = (which % 2)
    elseif S.phase == 2 then which = (which % 3) end
    if which == 0 then attackBoneVolley()
    elseif which == 1 then attackBlasterPair()
    elseif which == 2 then attackTeleportStrike()
    else attackBlueEye() end
  end

  if #S.hitTimes > 0 and t - S.hitTimes[#S.hitTimes] > 8 then
    if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "taunt") end
    S.hitTimes[#S.hitTimes] = t
  end
end

local lastPhase = 1
local function checkPhasePhrases()
  if not S.active then lastPhase = 1; return end
  if S.phase ~= lastPhase then
    lastPhase = S.phase
    if ORBIT.sans and ORBIT.sans.say then
      if S.phase == 2 then
        task.delay(0.3, function() pcall(ORBIT.sans.say, "hurt", true) end)
      elseif S.phase == 3 then
        task.delay(0.3, function() pcall(ORBIT.sans.say, "attack", true) end)
      end
    end
  end
end

local lastCollectTick = 0
local function stepCollect(dt, t)
  if S.state ~= "collecting" then return end
  S.timer = S.timer - dt
  stepShards(dt, t)
  stepTraps(dt, t)
  local c, h, root = getChar()
  if root then
    for id, s in pairs(S.parts) do
      if not s.got and s.part and s.part.Parent and not s.flying then
        if (root.Position - s.part.Position).Magnitude < 5 then S.collectPart(id) end
      end
    end
  end
  if t - lastCollectTick > 0.25 then
    lastCollectTick = t
    collectUIRefresh()
  end
  if S.timer <= 0 then
    clearShards()
    if S.collectUI and S.collectUI.sg then pcall(function() S.collectUI.sg:Destroy() end); S.collectUI = nil end
    S.state = "idle"
    if ORBIT.notify then ORBIT.notify("⏱ Время вышло! Попробуй снова", C3(255, 150, 150), 3) end
  end
end

connect(RS.Heartbeat, function(dt)
  if not alive then return end
  local t = tick()
  stepShots(dt)
  if S.state == "collecting" then stepCollect(dt, t)
  elseif S.state == "boss" then
    stepBoss(dt, t)
    checkPhasePhrases()
  end
end)

-- ============================================================
--       МЕНЮ БОССОВ (Санс + Гастер)
-- ============================================================
function S.open()
  if not alive then return false end
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return false end

  -- снести старое, если висит
  local old = pg:FindFirstChild("_OrbitBossMenu")
  if old then old:Destroy() end

  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitBossMenu"
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.DisplayOrder = 60
  sg.Parent = pg
  S.menu = sg

  -- фон НЕ активен — не блокирует кнопки под ним
  local backdrop = Instance.new("Frame")
  backdrop.Size = UDim2.fromScale(1, 1)
  backdrop.BackgroundColor3 = C3(0, 0, 0)
  backdrop.BackgroundTransparency = 0.5
  backdrop.BorderSizePixel = 0
  backdrop.ZIndex = 1
  backdrop.Active = false
  backdrop.Parent = sg

  local win = Instance.new("Frame")
  win.AnchorPoint = Vector2.new(0.5, 0.5)
  win.Position = UDim2.fromScale(0.5, 0.5)
  win.Size = UDim2.fromOffset(440, 500)
  win.BackgroundColor3 = C3(18, 14, 30)
  win.BorderSizePixel = 0
  win.ZIndex = 2
  win.Parent = sg
  Instance.new("UICorner", win).CornerRadius = UDim.new(0, 14)
  local st = Instance.new("UIStroke", win)
  st.Color = C3(160, 130, 255); st.Thickness = 2; st.Transparency = 0.15

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -60, 0, 32); title.Position = UDim2.new(0, 16, 0, 8)
  title.BackgroundTransparency = 1
  title.Text = "👹 МЕНЮ БОССОВ"
  title.TextColor3 = C3(235, 225, 255); title.Font = Enum.Font.GothamBold
  title.TextSize = 18; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 3
  title.Parent = win

  local closeBtn = Instance.new("TextButton")
  closeBtn.Size = UDim2.fromOffset(32, 32); closeBtn.Position = UDim2.new(1, -40, 0, 6)
  closeBtn.BackgroundColor3 = C3(80, 30, 40); closeBtn.TextColor3 = C3(255, 160, 180)
  closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 16; closeBtn.Text = "✖"
  closeBtn.AutoButtonColor = false; closeBtn.ZIndex = 3; closeBtn.Parent = win
  Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
  closeBtn.Activated:Connect(function() sg:Destroy(); S.menu = nil end)

  local function bossCard(y, icon, name, desc, hp, btnText, btnColor, onClick)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -32, 0, 130); card.Position = UDim2.new(0, 16, 0, y)
    card.BackgroundColor3 = C3(28, 22, 45); card.BorderSizePixel = 0; card.ZIndex = 3
    card.Parent = win
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local cs = Instance.new("UIStroke", card)
    cs.Color = btnColor; cs.Thickness = 2; cs.Transparency = 0.3

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.fromOffset(70, 70); iconLbl.Position = UDim2.new(0, 10, 0, 10)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon; iconLbl.TextColor3 = btnColor
    iconLbl.Font = Enum.Font.GothamBold; iconLbl.TextSize = 48; iconLbl.ZIndex = 4
    iconLbl.Parent = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -100, 0, 24); nameLbl.Position = UDim2.new(0, 88, 0, 12)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = name; nameLbl.TextColor3 = C3(240, 235, 255)
    nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 16
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 4
    nameLbl.Parent = card

    local hpLbl = Instance.new("TextLabel")
    hpLbl.Size = UDim2.new(1, -100, 0, 16); hpLbl.Position = UDim2.new(0, 88, 0, 36)
    hpLbl.BackgroundTransparency = 1
    hpLbl.Text = "❤ HP: " .. hp; hpLbl.TextColor3 = C3(255, 180, 180)
    hpLbl.Font = Enum.Font.Gotham; hpLbl.TextSize = 11
    hpLbl.TextXAlignment = Enum.TextXAlignment.Left; hpLbl.ZIndex = 4
    hpLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -100, 0, 30); descLbl.Position = UDim2.new(0, 88, 0, 54)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = desc; descLbl.TextColor3 = C3(180, 180, 210)
    descLbl.Font = Enum.Font.Gotham; descLbl.TextSize = 10; descLbl.TextWrapped = true
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextYAlignment = Enum.TextYAlignment.Top; descLbl.ZIndex = 4
    descLbl.Parent = card

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 32); btn.Position = UDim2.new(0, 10, 1, -42)
    btn.BackgroundColor3 = btnColor
    btn.TextColor3 = C3(20, 20, 30)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
    btn.Text = btnText
    btn.AutoButtonColor = false; btn.ZIndex = 4; btn.Parent = card
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.Activated:Connect(function()
      sg:Destroy()
      S.menu = nil
      task.delay(0.2, onClick)
    end)
  end

  -- Карточка 1: САНС
  bossCard(48, "💀", "САНС",
    "Мини-игра: собери 16 осколков → бой.\nХодит по земле, уклоняется, телепортируется.",
    400, "🎯 СОБРАТЬ 16 ОСКОЛКОВ", C3(100, 200, 255),
    function() S.startCollect() end)

  -- Карточка 2: ГАСТЕР
  bossCard(190, "👁", "ГАСТЕР",
    "Собери 16 осколков Гастера → бой.\nКружит, бьёт бластером, костями и рукой.",
    650, "👁 МИНИ-ИГРА ГАСТЕРА", C3(200, 140, 255),
    function()
      if ORBIT.gaster and ORBIT.gaster.open then ORBIT.gaster.open() end
    end)

  -- Кнопка «Пропустить и сразу в бой» (только если уже unlocked)
  if ORBIT.sansUnlocked then
    local skipBtn = Instance.new("TextButton")
    skipBtn.Size = UDim2.new(1, -32, 0, 30); skipBtn.Position = UDim2.new(0, 16, 0, 336)
    skipBtn.BackgroundColor3 = C3(70, 40, 100)
    skipBtn.TextColor3 = C3(240, 220, 255); skipBtn.Font = Enum.Font.GothamBold
    skipBtn.TextSize = 12; skipBtn.Text = "⚡ Сразу в бой (без сбора)"
    skipBtn.AutoButtonColor = false; skipBtn.ZIndex = 3; skipBtn.Parent = win
    Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)
    skipBtn.Activated:Connect(function()
      sg:Destroy()
      S.menu = nil
      task.delay(0.2, function() S.startBoss() end)
    end)
  end

  -- Подсказка про награды
  local hint = Instance.new("TextLabel")
  hint.Size = UDim2.new(1, -32, 0, 60); hint.Position = UDim2.new(0, 16, 0, 380)
  hint.BackgroundTransparency = 1
  hint.Text = "🎁 Награды за победу над Сансом:\n🦴 Клинок · 💧 Синий глаз · 💰 +500 · 💬 Чат · 🎨 Скин"
  hint.TextColor3 = C3(220, 200, 140); hint.Font = Enum.Font.Gotham
  hint.TextSize = 10; hint.TextWrapped = true; hint.TextXAlignment = Enum.TextXAlignment.Left
  hint.ZIndex = 3; hint.Parent = win

  return true
end

-- ============================================================
--       ОЧИСТКА
-- ============================================================
function S.destroy()
  if not alive then return end
  alive = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  conns = {}
  unhookDamage()
  hideBossUI()
  clearShards()
  if S.collectUI and S.collectUI.sg then pcall(function() S.collectUI.sg:Destroy() end); S.collectUI = nil end
  if S.boss and S.boss.model then pcall(function() S.boss.model:Destroy() end) end
  S.boss = nil
  for _, q in ipairs(S.shots) do
    if q.part and q.part.Parent then pcall(function() q.part:Destroy() end) end
  end
  S.shots = {}
  if S.cc then pcall(function() S.cc:Destroy() end); S.cc = nil end
  if S.menu then pcall(function() S.menu:Destroy() end); S.menu = nil end
  if S.folder then pcall(function() S.folder:Destroy() end); S.folder = nil end
  -- страховка по имени
  pcall(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
      for _, nm in ipairs({ "_OrbitBossMenu", "_OrbitSansBoss", "OrbitSansCollectGui" }) do
        local g = pg:FindFirstChild(nm)
        if g then g:Destroy() end
      end
    end
  end)
  S.active = false
  S.state = "idle"
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
ORBIT.sans_boss = S
if ORBIT.sansUnlocked == nil then ORBIT.sansUnlocked = false end
if ORBIT.sansKnifeUnlocked == nil then ORBIT.sansKnifeUnlocked = false end
if ORBIT.sansBlueEyeUnlocked == nil then ORBIT.sansBlueEyeUnlocked = false end
if ORBIT.saveData and ORBIT.saveData.rewards == nil then ORBIT.saveData.rewards = {} end
ORBIT.loaded.sans_boss = true

local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(S.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("💀 Санс v25.2 (сбор 16 осколков + ходьба + 5 наград)", C3(200, 230, 255), 3)
end

return true
