-- ORBIT v25.5 | orbit_sans_boss.lua
-- Мини-игра «Собери Санса» (16 осколков + ловушки) + босс-файт.
-- v25.4:
--   * Бластеры парят рядом с головой, смотрят на игрока.
--   * Кости-снаряды увеличены.
--   * 2-я фраза Санса при победе.
-- v25.5:
--   * Ходьба через ORBIT.figureRig (колени, махи рук, наклон, голова, дыхание).
--     Старые collectLegs/playWalkAnim удалены: они ставили ноги в мировые
--     координаты момента сборки, поэтому ноги «отставали» от модели.
--   * 7 атак вместо 4: + Костяная стена, Синий шторм, Двойной прыжок.
--     Таблица ATTACKS с минимальной фазой вместо attackIndex % 4.
--   * A.battle (orbit_abilities v25.1): ярость (множители урона/интервала),
--     аура при HP < 30%, статистика и награды, slow-mo победы.
--     recordDamage вызываем ТОЛЬКО с "boss"; урон игроку A.battle ловит сам.
--   * Кости-снаряды: «бугры» теперь следуют за костью (раньше оставались на месте).
-- v25.5-fix1: uiParent() с fallback на PlayerGui; S.destroy чистит GUI в обоих
--   родителях; guard через B.isActive()/B.bossId() вместо несуществующих полей
--   B.active/B.boss; хук fireId защищён _wrapper (не затирает хуки других боссов);
--   таймеры сброса состояния в winBoss/failBoss проверяют S.state.
-- v25.5-fix2: переход на A.battle от Клода — guard по полям B.active/B.boss
--   вместо методов isActive()/bossId().
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
  state = "idle",
  hp = 400, maxHp = 400, phase = 1,
  bossBlasters = {},
  timer = 120, collected = 0,
  parts = {}, traps = {},
  boss = nil, bossUI = nil, collectUI = nil,
  folder = nil, shots = {},
  walls = {}, storm = nil, jump = nil,
  bossVel = Vector3.new(0, 0, 0),
  lastAttackId = nil,
  walkTarget = nil, nextRetarget = 0, nextDodge = 0,
  nextAttack = 0, attackIndex = 0, walkPhase = 0,
  hitTimes = {}, _origFireId = nil, _wrapper = nil, hooked = false,
  _shapeRegistered = false,
}
local alive, token = true, 0
local conns = {}

local function connect(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local function ping(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end

local function battle()
  local ab = ORBIT.abilities
  return ab and ab.battle or nil
end
local function dmgMul()
  local B = battle()
  if B and B.dmgMul then return B.dmgMul() end
  return 1
end
local function intervalMul()
  local B = battle()
  if B and B.intervalMul then return B.intervalMul() end
  return 1
end
local function shakeNear(pos, mag, dur)
  local B = battle()
  if B and B.shakeNear then pcall(B.shakeNear, pos, mag, dur) end
end

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

-- v25.5: родитель для UI — ORBIT.getSafeParent(), запасной вариант PlayerGui
local function uiParent()
  if type(ORBIT.getSafeParent) == "function" then
    local ok, p = pcall(ORBIT.getSafeParent)
    if ok and typeof(p) == "Instance" then return p end
  end
  return LP:FindFirstChildOfClass("PlayerGui")
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

local PARTS = {
  { id = "skull",     nm = "Череп",        col = C3(250, 250, 252), sz = 2.4, px = 0.5,  py = 0.10, sw = 46, sh = 32, z = 1, partType = "skull" },
  { id = "eyeL",      nm = "Левый глаз",   col = C3(18, 18, 22),   sz = 1.2, px = 0.40, py = 0.15, sw = 10, sh = 8,  z = 3, partType = "ball" },
  { id = "eyeR",      nm = "Правый глаз",  col = C3(18, 18, 22),   sz = 1.2, px = 0.60, py = 0.15, sw = 10, sh = 8,  z = 3, partType = "ball" },
  { id = "eyeBlue",   nm = "Синий глаз",   col = COL_EYE,          sz = 1.2, px = 0.60, py = 0.15, sw = 8,  sh = 8,  z = 4, partType = "eye_glow" },
  { id = "smile",     nm = "Ухмылка",      col = C3(18, 18, 22),   sz = 1.4, px = 0.5,  py = 0.24, sw = 40, sh = 8,  z = 3, partType = "smile" },
  { id = "toothU",    nm = "Верхний зуб",  col = C3(255, 255, 255),sz = 1.0, px = 0.44, py = 0.28, sw = 8,  sh = 8,  z = 3, partType = "tooth" },
  { id = "toothL",    nm = "Нижний зуб",   col = C3(255, 255, 255),sz = 1.0, px = 0.56, py = 0.28, sw = 8,  sh = 8,  z = 3, partType = "tooth" },
  { id = "hoodie",    nm = "Толстовка",    col = COL_HOODIE,       sz = 2.4, px = 0.5,  py = 0.44, sw = 46, sh = 26, z = 1, partType = "hoodie" },
  { id = "hoodRoll",  nm = "Капюшон",      col = COL_HOODIE,       sz = 1.6, px = 0.5,  py = 0.36, sw = 34, sh = 10, z = 2, partType = "hood_roll" },
  { id = "armL",      nm = "Левая рука",   col = COL_HOODIE,       sz = 1.6, px = 0.20, py = 0.50, sw = 14, sh = 22, z = 1, partType = "arm" },
  { id = "armR",      nm = "Правая рука",  col = COL_HOODIE,       sz = 1.6, px = 0.80, py = 0.50, sw = 14, sh = 22, z = 1, partType = "arm" },
  { id = "handL",     nm = "Левая кисть",  col = C3(250, 250, 252),sz = 1.2, px = 0.20, py = 0.62, sw = 10, sh = 10, z = 3, partType = "ball" },
  { id = "handR",     nm = "Правая кисть", col = C3(250, 250, 252),sz = 1.2, px = 0.80, py = 0.62, sw = 10, sh = 10, z = 3, partType = "ball" },
  { id = "shorts",    nm = "Шорты",        col = C3(18, 18, 22),   sz = 2.0, px = 0.5,  py = 0.64, sw = 40, sh = 14, z = 1, partType = "shorts" },
  { id = "slipperL",  nm = "Левый тапок",  col = C3(246, 246, 250),sz = 1.4, px = 0.36, py = 0.86, sw = 14, sh = 8,  z = 2, partType = "slipper" },
  { id = "slipperR",  nm = "Правый тапок", col = C3(246, 246, 250),sz = 1.4, px = 0.64, py = 0.86, sw = 14, sh = 8,  z = 2, partType = "slipper" },
}

local function buildShardModel(def, pos)
  local m = Instance.new("Model")
  m.Name = "SansShard_" .. def.id
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
  if t == "skull" then
    add(V3(1.6, 1.6, 1.6), CF(), C3(250, 250, 252), PT_BALL)
    add(V3(1.2, 0.5, 1.2), CF(0, -0.7, 0), C3(240, 240, 245))
    add(V3(0.35, 0.35, 0.35), CF(-0.35, 0.15, -0.65), C3(15, 15, 20), PT_BALL)
    add(V3(0.35, 0.35, 0.35), CF(0.35, 0.15, -0.65), C3(15, 15, 20), PT_BALL)
  elseif t == "hoodie" then
    add(V3(1.8, 1.3, 1.0), CF(), def.col)
    add(V3(1.4, 0.5, 0.7), CF(0, 0.9, 0), def.col, PT_BALL)
  elseif t == "hood_roll" then
    add(V3(1.6, 0.6, 1.0), CF(), def.col, PT_BALL)
  elseif t == "arm" then
    add(V3(0.7, 1.5, 0.7), CF(0, 0.4, 0), def.col)
    add(V3(0.55, 0.55, 0.55), CF(0, -0.55, 0), C3(250, 250, 252), PT_BALL)
  elseif t == "shorts" then
    add(V3(2.0, 0.9, 1.0), CF(), def.col)
  elseif t == "slipper" then
    add(V3(0.9, 0.5, 1.4), CF(), def.col, PT_BALL)
  elseif t == "smile" then
    add(V3(0.7, 0.4, 0.3), CF(0, 0, 0), C3(18, 18, 22))
    add(V3(0.35, 0.5, 0.3), CF(-0.55, 0.15, 0), C3(255, 255, 255))
    add(V3(0.35, 0.5, 0.3), CF(0.55, 0.15, 0), C3(255, 255, 255))
  elseif t == "tooth" then
    add(V3(0.5, 0.7, 0.4), CF(), C3(255, 255, 255))
  elseif t == "eye_glow" then
    add(V3(def.sz, def.sz, def.sz), CF(), def.col, PT_BALL, MAT.Neon)
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

local function showBossUI()
  local pg = uiParent()
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
    local B = battle()
    if B and B.onPhase then pcall(B.onPhase, phase) end
  end
end

local function hideBossUI()
  if S.bossUI and S.bossUI.sg then pcall(function() S.bossUI.sg:Destroy() end) end
  S.bossUI = nil
end

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
  local pg = uiParent()
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
  title.BackgroundTransparency = 1; title.Text = "💀 СОБЕРИ САНСА (16 частей)"
  title.TextSize = 15; title.TextColor3 = C3(220, 240, 255)
  title.Font = Enum.Font.GothamBold; title.TextXAlignment = Enum.TextXAlignment.Center
  title.Parent = win

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
  u.hint = lbl(x0, 82, cw, 44, "Части тела летают. Ловушки розовые — минус 1 часть! Собирай все 16.", 10, C3(170, 160, 200))

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

local function clearShards()
  for _, s in pairs(S.parts) do if s.model then pcall(function() s.model:Destroy() end) end end
  S.parts = {}
  for _, t in pairs(S.traps) do if t.part then pcall(function() t.part:Destroy() end) end end
  S.traps = {}
end

local function makeShard(def, pos) return buildShardModel(def, pos) end

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
      for _, q in ipairs(placed) do if (q - pos).Magnitude < 8 then ok = false; break end end
      if ok then break end
    end
    placed[#placed + 1] = pos
    S.parts[def.id] = {
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
  if s.model then pcall(function() s.model:Destroy() end); s.model = nil end
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
  if not alive or S.state ~= "collecting" or not s or s.got or s.flying or not s.model then return false end
  local c, h, root = getChar()
  if not root then return false end
  local cur = s.model:GetPivot().Position
  local d = (root.Position - cur).Magnitude
  if d > 12 then
    s.flying = true
    task.spawn(function()
      while alive and S.parts[id] == s and s.flying and s.model and s.model.Parent do
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
      if alive and S.parts[id] == s then finalizePart(id) end
    end)
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
  if ORBIT.notify then ORBIT.notify("⚠️ Ловушка! Часть тела потеряна", C3(255, 100, 100), 2) end
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
    if not s.got and s.model and s.model.Parent and not s.flying then
      local ang = t * s.speed + s.phase
      local offset = V3(math.cos(ang) * s.radius, math.sin(t * 2 + s.phase) * 0.8, math.sin(ang) * s.radius)
      s.model:PivotTo(CFrame.new(s.base + offset) * CFrame.Angles(0, t * 1.5 + s.phase, 0))
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

-- ===== v25.5: ХОДЬБА ЧЕРЕЗ ORBIT.figureRig =====
local function say(cat, force)
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, cat, force) end
end

local function findWalkTarget(center, bossPos)
  local angle = math.random() * math.pi * 2
  local dist = 5 + math.random() * 3
  local target = center + V3(math.cos(angle) * dist, 0, math.sin(angle) * dist)
  local ground = groundAt(target)
  return V3(ground.X, ground.Y + 3, ground.Z)
end

local function faceCF(pos, target)
  local flat = V3(target.X, pos.Y, target.Z)
  if (flat - pos).Magnitude < 0.05 then return CFrame.new(pos) end
  return CFrame.lookAt(pos, flat) * CFrame.Angles(0, math.pi, 0)
end

local function applyRig(dt)
  local Rig = ORBIT.figureRig
  if Rig and Rig.update and S.boss and S.boss.model then
    pcall(Rig.update, S.boss.model, dt, S.bossVel)
  end
end

local function stepBossMovement(dt, t)
  if not S.boss or not S.boss.model then return end
  local c, h, r = getChar()
  if not r then S.bossVel = V3(0, 0, 0); return end
  local bossPos = S.boss.model:GetPivot().Position
  local playerPos = r.Position

  if not S.walkTarget or t >= S.nextRetarget or (S.walkTarget - bossPos).Magnitude < 1.5 then
    S.nextRetarget = t + 1.5
    S.walkTarget = findWalkTarget(playerPos, bossPos)
  end

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
      if math.random() < 0.3 then say("dodge") end
    end
  end

  local target = S.walkTarget or bossPos
  local diff = V3(target.X - bossPos.X, 0, target.Z - bossPos.Z)
  local dist = diff.Magnitude
  local newPos = bossPos
  if dist > 0.8 then
    local step = math.min(dist, 10 * dt)
    local dir = diff.Unit
    newPos = V3(bossPos.X + dir.X * step, target.Y, bossPos.Z + dir.Z * step)
  end
  local vel = V3(newPos.X - bossPos.X, 0, newPos.Z - bossPos.Z) / math.max(dt, 0.001)
  S.bossVel = S.bossVel:Lerp(vel, math.min(1, dt * 10))
  pcall(function() S.boss.model:PivotTo(faceCF(newPos, playerPos)) end)
end

-- ============================================================
--       КОСТИ (v25.5: «бугры» следуют за костью)
-- ============================================================
local function makeBone(origin, size, light)
  size = size or 0.9
  local len = 3.8 * size
  local p = ORBIT.newPart(fold(), "BossBone", V3(size * 1.4, size * 1.4, len), CF(origin), COL_BONE)
  p:SetAttribute("NoRecolor", true)
  p.Material = MAT.SmoothPlastic
  local extra = {}
  for _, sz in ipairs({1, -1}) do
    local xs = light and {0} or {-1, 1}
    for _, sx in ipairs(xs) do
      local lobe = ORBIT.newPart(fold(), "Lobe", V3(size * 1.5, size * 1.5, size * 1.5), CF(), COL_BONE, true)
      lobe.Shape = PT_BALL
      lobe.Material = MAT.SmoothPlastic
      lobe.Parent = p
      extra[#extra + 1] = { p = lobe, off = CF(sx * size * 0.6, 0, sz * (len * 0.5 - size * 0.4)) }
    end
  end
  return p, extra, len
end

local function placeBone(p, extra, cf)
  p.CFrame = cf
  for _, e in ipairs(extra) do e.p.CFrame = cf * e.off end
end

local function spawnBoneShot(origin, dirv, dmg, speed, size)
  local p, extra = makeBone(origin, size or 0.9, false)
  placeBone(p, extra, CFrame.lookAt(origin, origin + dirv))
  S.shots[#S.shots + 1] = { part = p, extra = extra, vel = dirv * speed, life = 3, dmg = dmg * dmgMul(), born = tick() }
end

-- ============================================================
--       АТАКИ: прежние 4
-- ============================================================
local function attackBoneVolley()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local from = S.boss.model:GetPivot().Position + V3(0, 2, 0)
  local to = r.Position
  local baseDir = (to - from).Unit
  local n = S.phase >= 2 and 5 or 3
  local spreadDeg = S.phase >= 2 and 20 or 14
  for i = 1, n do
    local a = (i - (n + 1) / 2) * spreadDeg
    local d = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(baseDir)
    task.delay((i - 1) * 0.07, function()
      if alive and S.active then spawnBoneShot(from, d, 20, 60) end
    end)
  end
  ping("snap", 0.8, 1.4)
  say("attack")
end

local function attackBlasterPair()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local center = r.Position
  local bossPos = S.boss.model:GetPivot().Position
  local sideDir = V3(center.X - bossPos.X, 0, center.Z - bossPos.Z)
  if sideDir.Magnitude > 0.1 then sideDir = sideDir.Unit else sideDir = V3(1, 0, 0) end
  local right = sideDir:Cross(V3(0, 1, 0)).Unit
  for _, sd in ipairs({-1, 1}) do
    local spos = center + right * (sd * 12) + V3(0, 6, 0) - sideDir * 4
    local m = buildBlaster(0.85)
    if m then
      pcall(function() m:PivotTo(CFrame.lookAt(spos, center)) end)
      local charge = m:FindFirstChild("Charge", true) or m.PrimaryPart
      task.delay(0.4, function()
        if not alive or not S.active then pcall(function() m:Destroy() end); return end
        local beamFrom = charge and charge.Position or spos
        local len = (center - beamFrom).Magnitude
        if len > 1 then
          local core = ORBIT.newPart(fold(), "Beam", V3(1.8, 1.8, len), CF(), C3(255, 255, 255))
          core.CFrame = CFrame.lookAt((beamFrom + center) / 2, center)
          local outer = ORBIT.newPart(fold(), "BeamOut", V3(3.0, 3.0, len), CF(), COL_EYE)
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
            pcall(function() hh:TakeDamage(18 * dmgMul()) end)
            S.hitTimes[#S.hitTimes + 1] = tick()
          end
        end
        shakeNear(center, 0.5, 0.25)
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
  local oldPos = S.boss.model:GetPivot().Position
  for i = 1, 8 do
    local p = ORBIT.newPart(fold(), "TpSpark", V3(0.5, 0.5, 0.5), CF(), COL_EYE)
    p.Shape = PT_BALL; p.Transparency = 0.2
    p.CFrame = CF(oldPos + V3(math.random(-3, 3), math.random(0, 4), math.random(-3, 3)))
    local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 8; l.Brightness = 4; l.Parent = p
    TS:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.5)
  end
  local behind = r.CFrame.LookVector * -3
  local rawPos = r.Position + V3(behind.X, 0, behind.Z)
  local gp = groundAt(rawPos)
  local newPos = V3(gp.X, gp.Y + 3, gp.Z)
  S.bossVel = V3(0, 0, 0)
  pcall(function() S.boss.model:PivotTo(faceCF(newPos, r.Position)) end)
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
    if not alive or not S.active or not S.boss then return end
    local c2, h2, r2 = getChar()
    if not r2 then return end
    local shotPos = S.boss.model:GetPivot().Position + V3(0, 1.5, 0)
    local d = (r2.Position - shotPos).Unit
    spawnBoneShot(shotPos, d, 35, 100, 1.2)
    ping("snap", 1, 1.2)
    say("attack", true)
  end)
end

local function attackBlueEye()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local eyePos = S.boss.model:GetPivot().Position + V3(0, 3.5, 0)
  local sphere = ORBIT.newPart(fold(), "BlueEye", V3(2, 2, 2), CF(eyePos), COL_EYE)
  sphere.Shape = PT_BALL; sphere.Transparency = 0.3
  local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 30; l.Brightness = 8; l.Parent = sphere
  TS:Create(sphere, TweenInfo.new(0.7), { Size = V3(50, 50, 50), Transparency = 1 }):Play()
  TS:Create(l, TweenInfo.new(0.9), { Brightness = 0 }):Play()
  Debris:AddItem(sphere, 1)
  local _, hh, rr = getChar()
  if hh and rr and (rr.Position - eyePos).Magnitude <= 25 then
    pcall(function() hh:TakeDamage(8 * dmgMul()) end)
  end
  shakeNear(eyePos, 0.5, 0.3)
  say("attack")
end

-- ============================================================
--       v25.5: НОВАЯ АТАКА 1 — «КОСТЯНАЯ СТЕНА»
-- ============================================================
local WALL_N, WALL_SP, WALL_SPEED = 11, 2.4, 24

local function attackBoneWall()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local bossPos = S.boss.model:GetPivot().Position
  local flat = V3(r.Position.X - bossPos.X, 0, r.Position.Z - bossPos.Z)
  if flat.Magnitude < 1 then flat = V3(0, 0, 1) end
  local dir = flat.Unit
  local right = dir:Cross(V3(0, 1, 0)).Unit
  local dist0 = flat.Magnitude
  local waves = (S.phase >= 3) and 2 or 1
  say("attack"); ping("snap", 0.8, 0.6)

  for w = 1, waves do
    task.delay((w - 1) * 0.9, function()
      if not alive or not S.active then return end
      local start = bossPos + dir * 3
      local g0 = groundAt(start)
      local travel = dist0 + 25
      local warn = ORBIT.newPart(fold(), "WallWarn", V3(WALL_N * WALL_SP, 0.2, travel),
        CFrame.lookAt(g0 + dir * (travel / 2) + V3(0, 0.15, 0), g0 + dir * travel + V3(0, 0.15, 0)), COL_TRAP, true)
      warn.Material = MAT.Neon; warn.Transparency = 0.55
      TS:Create(warn, TweenInfo.new(0.7), { Transparency = 1 }):Play()
      Debris:AddItem(warn, 0.8)

      task.delay(0.7, function()
        if not alive or not S.active then return end
        local gapIdx = math.random(2, WALL_N - 2)
        local exists, bones = {}, {}
        for i = 1, WALL_N do
          exists[i] = not (i == gapIdx or i == gapIdx + 1)
          if exists[i] then
            local lat = (i - (WALL_N + 1) / 2) * WALL_SP
            local p, extra, len = makeBone(g0, 1.5, true)
            bones[#bones + 1] = { p = p, extra = extra, len = len, lat = lat }
          end
        end
        S.walls[#S.walls + 1] = {
          bones = bones, exists = exists, pos = Vector3.new(start.X, g0.Y, start.Z),
          dir = dir, right = right, speed = WALL_SPEED, born = tick(),
          life = travel / WALL_SPEED, hit = false,
        }
        ping("snap", 1, 0.5)
      end)
    end)
  end
end

local function stepWalls(dt)
  if #S.walls == 0 then return end
  local t = tick()
  local _, hum, root = getChar()
  for i = #S.walls, 1, -1 do
    local w = S.walls[i]
    local el = t - w.born
    if el > w.life or not S.active then
      for _, b in ipairs(w.bones) do pcall(function() b.p:Destroy() end) end
      table.remove(S.walls, i)
    else
      w.pos = w.pos + w.dir * w.speed * dt
      local gy = groundAt(w.pos).Y
      local k = math.clamp(el / 0.3, 0, 1)
      for _, b in ipairs(w.bones) do
        local base = w.pos + w.right * b.lat
        local cy = gy + b.len * 0.5 - b.len * (1 - k)
        placeBone(b.p, b.extra, CFrame.new(base.X, cy, base.Z) * CFrame.Angles(math.rad(90), 0, 0))
      end
      if root and hum and not w.hit then
        local rel = root.Position - w.pos
        local along = rel:Dot(w.dir)
        local lat = rel:Dot(w.right)
        if math.abs(along) < 1.8 and root.Position.Y < gy + 6 then
          local idx = math.floor(lat / WALL_SP + (WALL_N + 1) / 2 + 0.5)
          if w.exists[idx] and math.abs(lat - (idx - (WALL_N + 1) / 2) * WALL_SP) < 1.5 then
            w.hit = true
            pcall(function() hum:TakeDamage(22 * dmgMul()) end)
            pcall(function() root.AssemblyLinearVelocity = w.dir * 40 + V3(0, 18, 0) end)
            S.hitTimes[#S.hitTimes + 1] = tick()
            shakeNear(root.Position, 0.5, 0.25)
            ping("ping", 1, 0.7)
          end
        end
      end
    end
  end
end

-- ============================================================
--       v25.5: НОВАЯ АТАКА 2 — «СИНИЙ ШТОРМ»
-- ============================================================
local BLUE_RULE = true
local STORM_ORBIT, STORM_CONV = 1.8, 0.9

local function makeStormSkull()
  local m
  local presets = ORBIT.SHAPE_PRESETS
  if type(presets) == "table" then
    for _, p in ipairs(presets) do
      if p.name == "ЧЕРЕП" and type(p.create) == "function" then
        local ok, data = pcall(p.create, 1.6, "SansStormSkull")
        if ok and data and data.model then m = data.model end
        break
      end
    end
  end
  if not m then
    m = Instance.new("Model"); m.Name = "SansStormSkull"
    local root = ORBIT.newPart(m, "Root", V3(1.6, 1.6, 1.6), CF(), COL_EYE, true)
    root.Shape = PT_BALL; root.Material = MAT.Neon
    m.PrimaryPart = root
  end
  local halo = ORBIT.newPart(m, "Halo", V3(3, 3, 3), CF(), COL_EYE, true)
  halo.Shape = PT_BALL; halo.Material = MAT.Neon; halo.Transparency = 0.7
  local l = Instance.new("PointLight")
  l.Color = COL_EYE; l.Range = 14; l.Brightness = 3; l.Parent = m.PrimaryPart or halo
  for _, d in ipairs(m:GetDescendants()) do
    if d:IsA("BasePart") then
      d:SetAttribute("NoRecolor", true); d.CanQuery = false; d.CanTouch = false
    end
  end
  m.Parent = fold()
  return m
end

local function endStorm(withFx)
  local st = S.storm
  if not st then return end
  S.storm = nil
  for _, m in ipairs(st.skulls) do
    if withFx and m.Parent then
      local pos = m:GetPivot().Position
      local b = ORBIT.newPart(fold(), "StormBurst", V3(1, 1, 1), CF(pos), COL_EYE, true)
      b.Shape = PT_BALL; b.Material = MAT.Neon; b.Transparency = 0.3
      TS:Create(b, TweenInfo.new(0.3), { Size = V3(6, 6, 6), Transparency = 1 }):Play()
      Debris:AddItem(b, 0.4)
    end
    pcall(function() m:Destroy() end)
  end
end

local function attackBlueStorm()
  if not S.boss or not S.active or S.storm then return end
  local c, h, r = getChar()
  if not r then return end
  local skulls = {}
  for i = 1, 3 do skulls[i] = makeStormSkull() end
  S.storm = { skulls = skulls, t0 = tick(), center = r.Position, ang = math.random() * 6.28, hit = {} }
  say("taunt"); ping("snap", 0.8, 1.4)
  if ORBIT.notify then
    ORBIT.notify(BLUE_RULE and "💙 Синий шторм: не двигайся, когда черепа сойдутся!" or "💙 Синий шторм!",
      C3(120, 200, 255), 3)
  end
end

local function stepStorm(dt, t)
  local st = S.storm
  if not st then return end
  if not S.active then endStorm(false); return end
  local _, hum, root = getChar()
  local el = t - st.t0
  if root then st.center = st.center:Lerp(root.Position, math.min(1, dt * 3)) end
  local radius, speed
  if el < STORM_ORBIT then
    radius = 12 - 3 * (el / STORM_ORBIT); speed = 2.4
  else
    local k = math.clamp((el - STORM_ORBIT) / STORM_CONV, 0, 1)
    radius = 9 * (1 - k) + 0.8; speed = 2.4 + 4 * k
  end
  st.ang = st.ang + speed * dt
  for i, m in ipairs(st.skulls) do
    local a = st.ang + (i - 1) * (2 * math.pi / 3)
    local pos = st.center + V3(math.cos(a) * radius, 1.5 + math.sin(el * 3 + i) * 0.5, math.sin(a) * radius)
    pcall(function() m:PivotTo(CFrame.lookAt(pos, st.center + V3(0, 1.5, 0))) end)
    if el >= STORM_ORBIT and root and hum and not st.hit[i] and (root.Position - pos).Magnitude < 3.2 then
      st.hit[i] = true
      local v = root.AssemblyLinearVelocity
      local moving = V3(v.X, 0, v.Z).Magnitude > 3
      if (not BLUE_RULE) or moving then
        pcall(function() hum:TakeDamage(12 * dmgMul()) end)
        S.hitTimes[#S.hitTimes + 1] = tick()
        shakeNear(pos, 0.4, 0.2)
        ping("ping", 1, 1.3)
      end
    end
  end
  if el >= STORM_ORBIT + STORM_CONV + 0.15 then endStorm(true) end
end

-- ============================================================
--       v25.5: НОВАЯ АТАКА 3 — «ДВОЙНОЙ ПРЫЖОК»
-- ============================================================
local JUMP_KEYS = { {0, 0}, {0.3, -0.6}, {0.75, 10}, {1.0, 10}, {1.4, 15}, {1.65, 15}, {2.15, 0} }

local function jumpHeight(t)
  for i = 1, #JUMP_KEYS - 1 do
    local a, b = JUMP_KEYS[i], JUMP_KEYS[i + 1]
    if t <= b[1] then
      local k = (t - a[1]) / (b[1] - a[1])
      k = k * k * (3 - 2 * k)
      return a[2] + (b[2] - a[2]) * k
    end
  end
  return 0
end

local function jumpFan(n, spread)
  if not S.boss or not S.active then return end
  local _, _, r = getChar()
  if not r then return end
  local from = S.boss.model:GetPivot().Position + V3(0, 1, 0)
  local flat = V3(r.Position.X - from.X, 0, r.Position.Z - from.Z)
  if flat.Magnitude < 0.5 then flat = V3(0, 0, 1) end
  local down = (flat.Unit * math.cos(math.rad(42)) + V3(0, -math.sin(math.rad(42)), 0)).Unit
  for i = 1, n do
    local a = (i - (n + 1) / 2) * spread
    local d = CFrame.Angles(0, math.rad(a), 0):VectorToWorldSpace(down)
    spawnBoneShot(from, d, 18, 62, 0.9)
  end
  ping("snap", 0.9, 1.3)
  shakeNear(from, 0.3, 0.15)
end

local function attackDoubleJump()
  if not S.boss or not S.active or S.jump then return end
  local c, h, r = getChar()
  if not r then return end
  local start = S.boss.model:GetPivot().Position
  local flat = V3(r.Position.X - start.X, 0, r.Position.Z - start.Z)
  local mag = flat.Magnitude
  local goal = start + (mag > 0.1 and flat.Unit or V3(0, 0, 1)) * math.min(mag, 7)
  S.jump = { t0 = tick(), start = start, goal = goal, fan1 = false, fan2 = false }
  S.bossVel = V3(0, 0, 0)
  say("combo"); ping("snap", 0.9, 0.7)
end

local function stepJump(dt, t)
  local j = S.jump
  if not j then return end
  if not S.boss or not S.boss.model then S.jump = nil; return end
  local el = t - j.t0
  local _, _, r = getChar()
  local look = r and r.Position or (j.goal + V3(0, 0, 1))
  local k = math.clamp(el / 2.15, 0, 1)
  local x = j.start.X + (j.goal.X - j.start.X) * k
  local z = j.start.Z + (j.goal.Z - j.start.Z) * k
  local y = j.start.Y + jumpHeight(el)
  pcall(function() S.boss.model:PivotTo(faceCF(V3(x, y, z), look)) end)
  if el >= 0.8 and not j.fan1 then j.fan1 = true; jumpFan(S.phase >= 3 and 5 or 3, 16) end
  if el >= 1.45 and not j.fan2 then j.fan2 = true; jumpFan(7, 12) end
  if el >= 2.15 then
    local g = groundAt(V3(x, y, z))
    local land = V3(x, g.Y + 3, z)
    pcall(function() S.boss.model:PivotTo(faceCF(land, look)) end)
    S.walkTarget = land
    S.nextRetarget = t + 1
    S.jump = nil
    local ring = ORBIT.newPart(fold(), "LandRing", V3(0.3, 2, 2),
      CF(g + V3(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), COL_EYE, true)
    ring.Shape = Enum.PartType.Cylinder; ring.Material = MAT.Neon; ring.Transparency = 0.3
    TS:Create(ring, TweenInfo.new(0.4), { Size = V3(0.3, 14, 14), Transparency = 1 }):Play()
    Debris:AddItem(ring, 0.5)
    shakeNear(g, 0.9, 0.4); ping("snap", 1, 0.5)
    local _, hh, rr = getChar()
    if hh and rr and (rr.Position - g).Magnitude <= 7 and rr.Position.Y < g.Y + 5 then
      pcall(function() hh:TakeDamage(16 * dmgMul()) end)
      pcall(function() rr.AssemblyLinearVelocity = (rr.Position - g).Unit * 30 + V3(0, 15, 0) end)
      S.hitTimes[#S.hitTimes + 1] = tick()
    end
  end
end

-- ============================================================
--       ТАБЛИЦА АТАК (7 шт.)
-- ============================================================
local ATTACKS = {
  { id = "bone",  minPhase = 1, fn = attackBoneVolley },
  { id = "blast", minPhase = 1, fn = attackBlasterPair },
  { id = "wall",  minPhase = 1, fn = attackBoneWall },
  { id = "tp",    minPhase = 2, fn = attackTeleportStrike },
  { id = "storm", minPhase = 2, fn = attackBlueStorm },
  { id = "eye",   minPhase = 3, fn = attackBlueEye },
  { id = "jump",  minPhase = 3, fn = attackDoubleJump },
}

local function pickAttack()
  if S.jump then return nil end
  local pool = {}
  for _, a in ipairs(ATTACKS) do
    if S.phase >= a.minPhase and a.id ~= S.lastAttackId
       and not (a.id == "storm" and S.storm) then
      pool[#pool + 1] = a
    end
  end
  if #pool == 0 then return nil end
  local a = pool[math.random(#pool)]
  S.lastAttackId = a.id
  return a
end

local function clearAttackFx()
  for _, w in ipairs(S.walls) do
    for _, b in ipairs(w.bones) do pcall(function() b.p:Destroy() end) end
  end
  S.walls = {}
  endStorm(false)
  S.jump = nil
end

-- ============================================================
--       УРОН ПО БОССУ (хук на ab.fireId)
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
    if r and S.hooked and S.active and S.boss and S.state == "boss" then
      local c, h, rr = getChar()
      if rr then
        local bd = (S.boss.model:GetPivot().Position - rr.Position).Magnitude
        if bd <= 60 then
          local dmgVal = ch and 45 or 25
          local dodgeChance = S.phase == 1 and 0.25 or (S.phase == 2 and 0.18 or 0.10)
          if math.random() < dodgeChance then
            say("dodge")
            ping("dodge", 1, 1.5)
          else
            S.hp = math.max(0, S.hp - dmgVal)
            updateBossUI()
            S.hitTimes[#S.hitTimes + 1] = tick()
            local B = battle()
            if B and B.recordDamage then pcall(B.recordDamage, dmgVal, "boss") end
            local hit = ORBIT.newPart(fold(), "Hit", V3(1.5, 1.5, 1.5), CF(S.boss.model:GetPivot().Position + V3(0, 2, 0)), C3(255, 200, 100))
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
  S._wrapper = ab.fireId
end

local function unhookDamage()
  local ab = ORBIT.abilities
  if ab and S.hooked and S._origFireId and ab.fireId == S._wrapper then
    pcall(function() ab.fireId = S._origFireId end)
  end
  S._wrapper = nil
  S.hooked = false
  S._origFireId = nil
end

-- ============================================================
--       СНАРЯДЫ-КОСТИ
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
        shakeNear(hitPos, 0.35, 0.2)
        local burst = ORBIT.newPart(fold(), "Burst", V3(2.5, 2.5, 2.5), CF(hitPos), COL_BONE)
        burst.Shape = PT_BALL; burst.Transparency = 0.3
        local l = Instance.new("PointLight"); l.Color = COL_BONE; l.Range = 10; l.Brightness = 4; l.Parent = burst
        TS:Create(burst, TweenInfo.new(0.3), { Size = V3(8, 8, 8), Transparency = 1 }):Play()
        Debris:AddItem(burst, 0.4)
      else
        placeBone(q.part, q.extra or {}, CFrame.lookAt(to, to + q.vel))
      end
    end
  end
end

-- ============================================================
--       СТАРТ СБОРА И БОЯ
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
  buildCollectUI()
  ping("ping", 1, 1.2)
  if ORBIT.notify then
    ORBIT.notify("💀 Собери 16 частей тела Санса!", C3(200, 230, 255), 3)
    ORBIT.notify("⚠️ Осторожно — розовые ловушки!", C3(255, 150, 180), 3)
  end
  task.delay(0.5, function() say("greet", true) end)
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

local function destroyBossModel()
  local Rig = ORBIT.figureRig
  if S.boss and S.boss.model then
    if Rig and Rig.detach then pcall(Rig.detach, S.boss.model) end
    pcall(function() S.boss.model:Destroy() end)
  end
  for _, b in ipairs(S.bossBlasters or {}) do
    if b and b.Parent then pcall(function() b:Destroy() end) end
  end
  S.bossBlasters = {}
  S.boss = nil
  S.bossVel = V3(0, 0, 0)
end

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
  S.walkTarget = nil
  S.shots = {}
  S.hitTimes = {}
  S.bossBlasters = {}
  S.bossVel = V3(0, 0, 0)
  S.lastAttackId = nil
  S.deadSince = nil
  clearAttackFx()
  clearShards()

  local c, h, r = getChar()
  if not r then
    S.active = false; S.state = "idle"
    return
  end

  local data = buildSansBoss(3)

  if data and data.model then
    for _, ch in ipairs(data.model:GetChildren()) do
      if ch:IsA("Model") and ch.Name:find("Blaster") then
        table.insert(S.bossBlasters, ch)
      end
    end
    for _, b in ipairs(S.bossBlasters) do
      b.Parent = fold()
    end
  end

  local spawnPos = r.Position + r.CFrame.LookVector * 15
  local gp = groundAt(spawnPos)
  local finalPos = V3(gp.X, gp.Y + 3, gp.Z)
  pcall(function() data.model:PivotTo(faceCF(finalPos, r.Position)) end)
  S.boss = {
    data = data,
    root = data.part or data.model.PrimaryPart,
    model = data.model,
  }
  S.walkTarget = finalPos

  local cc = Instance.new("ColorCorrectionEffect")
  cc.Name = "OrbitSansBossCC"; cc.Parent = Lighting
  S.cc = cc
  TS:Create(cc, TweenInfo.new(1.2), {
    Brightness = -0.12, Saturation = -0.15, TintColor = C3(230, 235, 255)
  }):Play()

  showBossUI()
  updateBossUI()
  hookDamage()
  local B = battle()
  if B and B.start then
    pcall(B.start, "sans", {
      maxHp = S.maxHp,
      getHp = function() return S.hp, S.maxHp end,
      getModel = function() return S.boss and S.boss.model or nil end,
    })
  end
  ping("laugh", 1, 0.9)

  task.delay(0.4, function() say("greet", true) end)
  task.delay(1.2, function() say("taunt", true) end)
  if ORBIT.notify then
    ORBIT.notify("💀 САНС ВЫШЕЛ НА БОЙ!", C3(200, 230, 255), 4)
    ORBIT.notify("⚔ Используй свои стихии — наноси урон!", C3(255, 200, 120), 5)
  end
end

local REWARDS = {
  { id = "sans_knife",       name = "🦴 Костяной клинок",      desc = "Оружие: веер из 3 костей" },
  { id = "blue_eye",         name = "💧 Синий глаз",           desc = "Возрождение 1 раз в 30 сек" },
  { id = "coins_sans",       name = "💰 +500 монет",           desc = "Валюта в магазине" },
  { id = "sans_chat",        name = "💬 Санс в чате",          desc = "Пишет фразы при победах" },
  { id = "sans_boss_skin",   name = "🎨 Скин «Санс-босс»",     desc = "Открыт в арсенале" },
}

function S.winBoss()
  if not S.active then return end
  S.active = false
  S.state = "won"
  hideBossUI()
  unhookDamage()
  clearAttackFx()
  local B = battle()
  if B and B.win then pcall(B.win, { boss = "sans" }) end

  local bossPos = (S.boss and S.boss.model and S.boss.model:GetPivot().Position) or V3(0, 5, 0)
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

  task.delay(0.6, function() say("victory", true) end)
  task.delay(2.0, function()
    if ORBIT.sans and ORBIT.sans.showAt and LP.Character then
      local head = LP.Character:FindFirstChild("Head")
      if head then
        pcall(ORBIT.sans.showAt, head.Position + V3(0, 3, 0), "забирай. заслужил.", 4)
      end
    end
  end)
  task.delay(6.5, function()
    if not alive then return end
    if ORBIT.sans and ORBIT.sans.showAt and LP.Character then
      local head = LP.Character:FindFirstChild("Head")
      if head then
        pcall(ORBIT.sans.showAt, head.Position + V3(0, 3, 0), "не скучай, приятель.", 4)
      end
    end
  end)
  ping("sans", 1, 1)

  task.delay(1.2, function() destroyBossModel() end)

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
  ORBIT.saveData.rewards["coins"] = true
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
    if alive and S.state == "won" then
      S.state = "idle"
      S.hp = 400
      S.timer = 120
    end
  end)
end

function S.failBoss(reason)
  if not S.active then return end
  S.active = false
  S.state = "lost"
  hideBossUI()
  unhookDamage()
  clearAttackFx()
  local B = battle()
  if B and B.lose then pcall(B.lose, reason) end
  destroyBossModel()
  if S.cc then pcall(function() S.cc:Destroy() end); S.cc = nil end

  task.delay(0.3, function() say("taunt", true) end)
  task.delay(1.2, function()
    if ORBIT.sans and ORBIT.sans.showAt and LP.Character then
      local head = LP.Character:FindFirstChild("Head")
      if head then
        pcall(ORBIT.sans.showAt, head.Position + V3(0, 3, 0), reason or "время вышло. спишемся.", 4)
      end
    end
  end)
  ping("click", 1, 0.5)
  if ORBIT.notify then
    ORBIT.notify("💀 Санс ушёл... " .. (reason or "время вышло"), C3(255, 180, 180), 4)
  end
  task.delay(3, function()
    if alive and S.state == "lost" then
      S.state = "idle"
      S.hp = 400
      S.timer = 120
    end
  end)
end
S.loseBoss = S.failBoss

-- ============================================================
--       ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function stepBoss(dt, t)
  if not S.active or S.state ~= "boss" then return end
  updateBossUI()

  if not getChar() then
    S.deadSince = S.deadSince or t
    if t - S.deadSince > 3 then S.failBoss("ты пал. спишемся."); return end
  else
    S.deadSince = nil
  end

  if S.jump then stepJump(dt, t) else stepBossMovement(dt, t) end
  stepStorm(dt, t)

  if S.boss and S.boss.model and #S.bossBlasters > 0 then
    local c2, h2, r2 = getChar()
    local mcf = S.boss.model:GetPivot()
    local bossPos = mcf.Position
    local targetPos = r2 and r2.Position or (bossPos + mcf.LookVector * 20)
    local toTarget = V3(targetPos.X - bossPos.X, 0, targetPos.Z - bossPos.Z)
    if toTarget.Magnitude > 0.1 then
      local dir = toTarget.Unit
      local right = dir:Cross(V3(0, 1, 0)).Unit
      for i, b in ipairs(S.bossBlasters) do
        if b.Parent then
          local sd = (i == 1) and -1 or 1
          local bp = bossPos + dir * 2 + right * (sd * 6) + V3(0, 10, 0)
          pcall(function() b:PivotTo(CFrame.lookAt(bp, targetPos)) end)
        end
      end
    end
  end

  if t >= S.nextAttack then
    local a = pickAttack()
    if a then
      local base = S.phase == 1 and 3.5 or (S.phase == 2 and 2.5 or 1.8)
      S.nextAttack = t + base * intervalMul()
      local ok, err = pcall(a.fn)
      if not ok then warn("[Orbit SansBoss] атака " .. tostring(a.id) .. ": " .. tostring(err)) end
    else
      S.nextAttack = t + 0.4
    end
  end

  if #S.hitTimes > 20 then table.remove(S.hitTimes, 1) end
  if #S.hitTimes > 0 and t - S.hitTimes[#S.hitTimes] > 8 then
    say("taunt")
    S.hitTimes[#S.hitTimes] = t
  end

  applyRig(dt)
end

local lastPhase = 1
local function checkPhasePhrases()
  if not S.active then lastPhase = 1; return end
  if S.phase ~= lastPhase then
    lastPhase = S.phase
    if S.phase == 2 then
      task.delay(0.3, function() say("hurt", true) end)
    elseif S.phase == 3 then
      task.delay(0.3, function() say("attack", true) end)
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
      if not s.got and s.model and s.model.Parent and not s.flying then
        if (root.Position - s.model:GetPivot().Position).Magnitude < 5 then S.collectPart(id) end
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
  stepWalls(dt)
  if S.state == "collecting" then stepCollect(dt, t)
  elseif S.state == "boss" then
    stepBoss(dt, t)
    checkPhasePhrases()
  end
end)

-- ============================================================
--       ОЧИСТКА
-- ============================================================
function S.destroy()
  if not alive then return end
  alive = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  conns = {}
  unhookDamage()
  clearAttackFx()
  hideBossUI()
  clearShards()
  -- v25.5-fix2: A.battle от Клода — поля B.active/B.boss
  local B = battle()
  if B and B.active and B.boss == "sans" and B.cleanup then
    pcall(B.cleanup)
  end
  if S.collectUI and S.collectUI.sg then pcall(function() S.collectUI.sg:Destroy() end); S.collectUI = nil end
  destroyBossModel()
  for _, q in ipairs(S.shots) do
    if q.part and q.part.Parent then pcall(function() q.part:Destroy() end) end
  end
  S.shots = {}
  if S.cc then pcall(function() S.cc:Destroy() end); S.cc = nil end
  if S.menu then pcall(function() S.menu:Destroy() end); S.menu = nil end
  if S.folder then pcall(function() S.folder:Destroy() end); S.folder = nil end
  pcall(function()
    for _, pg in ipairs({ uiParent(), LP:FindFirstChildOfClass("PlayerGui") }) do
      if pg then
        for _, nm in ipairs({ "_OrbitBossMenu", "_OrbitSansBoss", "OrbitSansCollectGui" }) do
          local g = pg:FindFirstChild(nm)
          if g then g:Destroy() end
        end
      end
    end
  end)
  S.active = false
  S.state = "idle"
end

-- ============================================================
--       МЕНЮ БОССОВ (Санс + Гастер)
-- ============================================================
function S.open()
  if not alive then return false end
  local pg = uiParent()
  if not pg then return false end

  local old = pg:FindFirstChild("_OrbitBossMenu")
  if old then old:Destroy() end

  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitBossMenu"
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.DisplayOrder = 60
  sg.Parent = pg
  S.menu = sg

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

  bossCard(48, "💀", "САНС",
    "Мини-игра: собери 16 частей тела → бой.\n7 атак: кости, стена, бластеры, телепорт, синий шторм, двойной прыжок.",
    400, "🎯 СОБРАТЬ 16 ЧАСТЕЙ", C3(100, 200, 255),
    function() S.startCollect() end)

  bossCard(190, "👁", "ГАСТЕР",
    "Собери 16 осколков Гастера → бой.\nХодит по земле, бьёт рукой/бластером/костями.",
    650, "👁 МИНИ-ИГРА ГАСТЕРА", C3(200, 140, 255),
    function()
      if ORBIT.gaster and ORBIT.gaster.open then ORBIT.gaster.open() end
    end)

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

  local hint = Instance.new("TextLabel")
  hint.Size = UDim2.new(1, -32, 0, 60); hint.Position = UDim2.new(0, 16, 0, 380)
  hint.BackgroundTransparency = 1
  hint.Text = "🎁 Награды за победу над Сансом:\n🦴 Клинок · 💧 Синий глаз · 💰 +500 · 💬 Чат · 🎨 Скин\n👻 Призрак (без урона) · ⚔ Мастер клинков (10 побед) · 🏆 Легенда"
  hint.TextColor3 = C3(220, 200, 140); hint.Font = Enum.Font.Gotham
  hint.TextSize = 10; hint.TextWrapped = true; hint.TextXAlignment = Enum.TextXAlignment.Left
  hint.ZIndex = 3; hint.Parent = win

  return true
end

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
S.version = "v25.5-fix2"
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
  ORBIT.notify("💀 Санс v25.5-fix2 (7 атак, риг ходьбы, ярость и награды)", C3(200, 230, 255), 3)
end

return true
