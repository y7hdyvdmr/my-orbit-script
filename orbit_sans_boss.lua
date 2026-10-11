-- ORBIT v25.0 | orbit_sans_boss.lua
-- Босс-файт «Санс». Слабее Гастера: HP 400, 4 атаки, додж, телепорт.
-- Награды: костяной клинок + синий глаз + монеты + фразы Санса + скин.
-- Запускается из меню «👹 БОССЫ» (orbit_p4b.lua).
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

-- Палитра Санса
local COL_BONE    = C3(245, 245, 250)
local COL_HOODIE  = C3(55, 115, 225)
local COL_EYE     = C3(0, 205, 255)
local COL_BLASTER = C3(240, 240, 245)
local COL_HP      = C3(255, 100, 100)
local COL_HP_BG   = C3(40, 20, 20)
local COL_UI_BG   = C3(15, 10, 25)

-- Состояние
local S = {
  active = false,
  state = "idle",           -- idle | fighting | won | lost
  hp = 400,
  maxHp = 400,
  phase = 1,
  timer = 90,
  boss = nil,               -- { model, root, charge, lights }
  bossUI = nil,
  folder = nil,
  shots = {},               -- активные атаки (кости, бластеры)
  dodgeUntil = 0,
  nextDodge = 0,
  nextAttack = 0,
  attackIndex = 0,
  teleportFlash = 0,
  hitTimes = {},
  startTick = 0,
  _origFireId = nil,
  hooked = false,
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
local function cam() return WS.CurrentCamera end

-- ============================================================
--       СБОРКА ТЕЛА БОССА (переиспользуем фигуру «САНС» из p2)
-- ============================================================
local function buildSansBoss(size)
  -- Берём существующую фигуру из SHAPE_PRESETS (индекс 29 «САНС»)
  -- Это гарантирует одинаковый внешний вид с обычной фигурой Санса.
  local presets = ORBIT.SHAPE_PRESETS
  local sansPreset = nil
  if type(presets) == "table" then
    for _, p in ipairs(presets) do
      if p.name == "САНС" then sansPreset = p; break end
    end
  end
  if not sansPreset or type(sansPreset.create) ~= "function" then
    warn("[Orbit SansBoss] пресет САНС не найден — использую заглушку")
    local m, r = ORBIT.newModelShell("SansBoss")
    local head = ORBIT.newPart(m, "Head", V3(2,2,2), CF(0,3,0), COL_BONE)
    return { model = m, root = r }
  end
  -- Создаём фигуру через create()
  local ok, data = pcall(sansPreset.create, size, "SansBoss")
  if not ok or not data or not data.model then
    warn("[Orbit SansBoss] create() упал: " .. tostring(data))
    local m, r = ORBIT.newModelShell("SansBoss")
    return { model = m, root = r }
  end
  data.model.Parent = fold()
  -- Ищем корень и светящиеся части (голубой глаз, бластеры)
  local charge = nil
  for _, d in ipairs(data.model:GetDescendants()) do
    if d:IsA("BasePart") then
      if d.Name == "EyeGlow" then charge = d; break end
      if not charge and d.Material == Enum.Material.Neon and d.Color == COL_EYE then charge = d end
    end
  end
  return { model = data.model, root = data.part or data.model.PrimaryPart, charge = charge, bodyParts = data.bodyParts or {} }
end

-- ============================================================
--       СБОРКА БЛАСТЕРА (уменьшенная копия через p2-фигуру)
-- ============================================================
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
--       HP-БАР (синий, как у Гастера но в цветах Санса)
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
    if phase == 2 then
      S.bossUI.hpFill.BackgroundColor3 = C3(255, 130, 60)
    elseif phase == 3 then
      S.bossUI.hpFill.BackgroundColor3 = C3(255, 60, 60)
      -- на финальной фазе Санс говорит агрессивно
      if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack", true) end
    end
  end
end

local function hideBossUI()
  if S.bossUI and S.bossUI.sg then pcall(function() S.bossUI.sg:Destroy() end) end
  S.bossUI = nil
end
-- ============================================================
--       АТАКИ БОССА
-- ============================================================

-- Общая функция: выпустить кость-снаряд
local function spawnBoneShot(origin, dirv, dmg, speed, size)
  size = size or 0.5
  local p = ORBIT.newPart(fold(), "BossBone", V3(size, size, 2.8 * size), CF(origin), COL_BONE)
  p.CFrame = CFrame.lookAt(origin, origin + dirv)
  p:SetAttribute("NoRecolor", true)
  p.Material = MAT.SmoothPlastic
  -- трещины на стержне (визуал STRONG)
  local crack1 = ORBIT.newPart(fold(), "Crack", V3(size * 0.7, size * 0.08, 1.4 * size), CF(), C3(40, 36, 30), true)
  crack1.CFrame = p.CFrame * CF(0, 0, 0.3 * size) * CFrame.Angles(0, 0, math.rad(14))
  crack1.Parent = p
  local crack2 = ORBIT.newPart(fold(), "Crack", V3(size * 0.5, size * 0.07, 0.8 * size), CF(), C3(40, 36, 30), true)
  crack2.CFrame = p.CFrame * CF(0, 0, -0.5 * size) * CFrame.Angles(0, 0, math.rad(-18))
  crack2.Parent = p
  -- наросты по концам
  for _, sz in ipairs({1, -1}) do
    for _, sx in ipairs({-1, 1}) do
      local lobe = ORBIT.newPart(fold(), "Lobe", V3(size * 1.05, size * 1.05, size * 1.05), CF(), COL_BONE, true)
      lobe.Shape = Enum.PartType.Ball
      lobe.Material = MAT.SmoothPlastic
      lobe.CFrame = p.CFrame * CF(sx * size * 0.42, 0, sz * 1.4 * size)
      lobe.Parent = p
    end
  end
  -- блик
  local glint = ORBIT.newPart(fold(), "Glint", V3(size * 0.22, size * 0.22, size * 0.22), CF(), C3(255, 250, 240), true)
  glint.Shape = Enum.PartType.Ball
  glint.Material = MAT.Neon
  glint.Transparency = 0.3
  glint.CFrame = p.CFrame
  glint.Parent = p

  S.shots[#S.shots + 1] = {
    part = p, vel = dirv * speed, life = 3, dmg = dmg, kind = "bone"
  }
end

-- Атака 1: веер костей
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

-- Атака 2: два бластера с боков
local function attackBlasterPair()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local center = r.Position
  local bossPos = S.boss.root.Position
  local sideDir = (center - bossPos)
  sideDir = V3(sideDir.X, 0, sideDir.Z).Unit
  if sideDir.Magnitude < 0.1 then sideDir = V3(1, 0, 0) end
  local right = sideDir:Cross(V3(0, 1, 0)).Unit
  for _, sd in ipairs({-1, 1}) do
    local spos = center + right * (sd * 12) + V3(0, 6, 0) - sideDir * 4
    local m = buildBlaster(0.55)
    if m then
      pcall(function() m:PivotTo(CFrame.lookAt(spos, center)) end)
      local charge = m:FindFirstChild("Charge", true) or m.PrimaryPart
      task.delay(0.4, function()
        if not alive or not S.active then
          pcall(function() m:Destroy() end)
          return
        end
        -- вспышка выстрела
        local beamFrom = charge and charge.Position or spos
        local len = (center - beamFrom).Magnitude
        if len > 1 then
          local core = ORBIT.newPart(fold(), "BossBeam", V3(1.4, 1.4, len), CF(), C3(255, 255, 255))
          core.CFrame = CFrame.lookAt((beamFrom + center) / 2, center)
          local outer = ORBIT.newPart(fold(), "BossBeamOuter", V3(2.5, 2.5, len), CF(), COL_EYE)
          outer.CFrame = core.CFrame
          outer.Transparency = 0.65
          local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 20; l.Brightness = 6; l.Parent = core
          TS:Create(core, TweenInfo.new(0.5), { Size = V3(0.1, 0.1, len), Transparency = 1 }):Play()
          TS:Create(outer, TweenInfo.new(0.55), { Size = V3(0.15, 0.15, len), Transparency = 1 }):Play()
          TS:Create(l, TweenInfo.new(0.6), { Brightness = 0 }):Play()
          Debris:AddItem(core, 0.7); Debris:AddItem(outer, 0.8)
        end
        -- урон по игроку если в зоне
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

-- Атака 3: телепорт-удар (Санс исчезает и появляется за спиной игрока)
local function attackTeleportStrike()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local oldPos = S.boss.root.Position
  -- вспышка на старом месте
  for i = 1, 8 do
    local p = ORBIT.newPart(fold(), "TpSpark", V3(0.5, 0.5, 0.5), CF(), COL_EYE)
    p.Shape = Enum.PartType.Ball
    p.CFrame = CF(oldPos + V3(math.random(-3, 3), math.random(0, 4), math.random(-3, 3)))
    p.Transparency = 0.2
    local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 8; l.Brightness = 4; l.Parent = p
    TS:Create(p, TweenInfo.new(0.4), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.5)
  end
  -- новая позиция за спиной игрока
  local behind = r.CFrame.LookVector * -3 + V3(0, 3, 0)
  local newPos = r.Position + behind
  pcall(function() S.boss.model:PivotTo(CFrame.lookAt(newPos, r.Position)) end)
  -- вспышка на новом месте
  for i = 1, 10 do
    local p = ORBIT.newPart(fold(), "TpSpark", V3(0.6, 0.6, 0.6), CF(), COL_EYE)
    p.Shape = Enum.PartType.Ball
    p.CFrame = CF(newPos + V3(math.random(-2, 2), math.random(0, 4), math.random(-2, 2)))
    p.Transparency = 0.1
    local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 10; l.Brightness = 5; l.Parent = p
    TS:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.6)
  end
  -- через 0.35 сек — удар костью в бок
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
  S.teleportFlash = tick() + 0.5
end

-- Атака 4: синий глаз (замедляет, сбивает прицел)
local function attackBlueEye()
  if not S.boss or not S.active then return end
  local c, h, r = getChar()
  if not r then return end
  local eyePos = S.boss.root.Position + V3(0, 3.5, 0)
  -- расширяющаяся синяя сфера
  local sphere = ORBIT.newPart(fold(), "BlueEye", V3(2, 2, 2), CF(eyePos), COL_EYE)
  sphere.Shape = Enum.PartType.Ball
  sphere.Transparency = 0.3
  local l = Instance.new("PointLight"); l.Color = COL_EYE; l.Range = 30; l.Brightness = 8; l.Parent = sphere
  TS:Create(sphere, TweenInfo.new(0.7), { Size = V3(50, 50, 50), Transparency = 1 }):Play()
  TS:Create(l, TweenInfo.new(0.9), { Brightness = 0 }):Play()
  Debris:AddItem(sphere, 1)
  -- урон тем, кто в радиусе 25
  for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LP and pl.Character then
      local hh = pl.Character:FindFirstChildOfClass("Humanoid")
      local rr = pl.Character:FindFirstChild("HumanoidRootPart")
      if hh and rr and hh.Health > 0 and (rr.Position - eyePos).Magnitude <= 25 then
        pcall(function() hh:TakeDamage(10) end)
        -- замедление
        local orig = hh.WalkSpeed
        pcall(function() hh.WalkSpeed = orig * 0.4 end)
        task.delay(3, function()
          if hh and hh.Parent then pcall(function() hh.WalkSpeed = orig end) end
        end)
      end
    end
  end
  -- самого игрока тоже задеваем если близко
  local _, hh, rr = getChar()
  if hh and rr and (rr.Position - eyePos).Magnitude <= 25 then
    pcall(function() hh:TakeDamage(8) end)
  end
  if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "attack") end
end

-- ============================================================
--       ШАГ БОССА (движение + уклонение + AI)
-- ============================================================
local function spawnDodgeTrail(from, to)
  local trail = ORBIT.makeRod(fold(), from + V3(0, 2, 0), to + V3(0, 2, 0), 0.5, 0.5, COL_EYE)
  if trail then
    trail.Transparency = 0.4
    trail.Material = MAT.Neon
    TS:Create(trail, TweenInfo.new(0.4), { Transparency = 1 }):Play()
    Debris:AddItem(trail, 0.5)
  end
end

local function stepBossMovement(dt, t)
  if not S.boss or not S.boss.root then return end
  local c, h, r = getChar()
  if not r then return end
  local center = r.Position
  -- Санс летает по кругу радиусом 15
  local flyAngle = t * 0.7
  local flyRadius = 15
  local flyY = 6 + math.sin(t * 1.3) * 1.5
  local targetPos = center + V3(math.cos(flyAngle) * flyRadius, flyY, math.sin(flyAngle) * flyRadius)
  local bossPos = S.boss.root.Position

  -- Уклонение: раз в 2.5-4 сек делаем рывок
  if t >= S.nextDodge then
    S.nextDodge = t + 2.5 + math.random() * 1.5
    local dodgeTo = targetPos + V3(math.random(-6, 6), math.random(0, 2), math.random(-6, 6))
    spawnDodgeTrail(bossPos, dodgeTo)
    bossPos = dodgeTo
    S.dodgeUntil = t + 0.3
    pcall(function() S.boss.model:PivotTo(CFrame.lookAt(bossPos, center)) end)
    ping("dodge", 0.8, 1.4)
    if math.random() < 0.3 and ORBIT.sans and ORBIT.sans.say then
      pcall(ORBIT.sans.say, "dodge")
    end
    return
  end

  -- Обычное перемещение к targetPos (плавно)
  local curPos = bossPos
  local diff = targetPos - curPos
  local speed = 12
  if diff.Magnitude > 0.5 then
    local step = math.min(diff.Magnitude, speed * dt)
    local newPos = curPos + diff.Unit * step
    pcall(function() S.boss.model:PivotTo(CFrame.lookAt(newPos, center)) end)
  end
end

-- ============================================================
--       ХУК УРОНА (перехват abilities.fireId)
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
    if r and S.active and S.boss then
      -- Проверяем, попал ли игрок по Сансу своей атакой
      -- (упрощённо: любая атака = 25-50 урона боссу)
      local c, h, rr = getChar()
      if rr then
        local bd = (S.boss.root.Position - rr.Position).Magnitude
        if bd <= 60 then
          local dmgVal = ch and 45 or 25
          -- с шансом уклонения 15-25% (зависит от фазы)
          local dodgeChance = S.phase == 1 and 0.25 or (S.phase == 2 and 0.18 or 0.10)
          if math.random() < dodgeChance then
            -- Санс уклонился
            if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "dodge") end
            ping("dodge", 1, 1.5)
          else
            S.hp = math.max(0, S.hp - dmgVal)
            updateBossUI()
            S.hitTimes[#S.hitTimes + 1] = tick()
            -- визуальный удар
            local hit = ORBIT.newPart(fold(), "Hit", V3(1.5, 1.5, 1.5), CF(S.boss.root.Position + V3(0, 2, 0)), C3(255, 200, 100))
            hit.Shape = Enum.PartType.Ball
            hit.Transparency = 0.2
            local l = Instance.new("PointLight"); l.Color = C3(255, 200, 100); l.Range = 12; l.Brightness = 6; l.Parent = hit
            TS:Create(hit, TweenInfo.new(0.35), { Size = V3(6, 6, 6), Transparency = 1 }):Play()
            TS:Create(l, TweenInfo.new(0.5), { Brightness = 0 }):Play()
            Debris:AddItem(hit, 0.5)
            ping("ping", 1, 1.4)
            -- проверка на победу
            if S.hp <= 0 then
              S.winBoss()
            end
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
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  local ex = { fold() }
  if LP.Character then ex[#ex + 1] = LP.Character end
  rp.FilterDescendantsInstances = ex
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
      -- Проверка на попадание в игрока
      local c, h, r = getChar()
      if not hitPos and r and (r.Position - to).Magnitude < 3 then
        hitPos = to
      end
      if hitPos then
        table.remove(S.shots, i)
        pcall(function() q.part:Destroy() end)
        -- урон + визуал
        local _, hh, rr = getChar()
        if hh and rr and (rr.Position - hitPos).Magnitude <= 6 then
          pcall(function() hh:TakeDamage(q.dmg) end)
          S.hitTimes[#S.hitTimes + 1] = tick()
        end
        local burst = ORBIT.newPart(fold(), "Burst", V3(2, 2, 2), CF(hitPos), COL_BONE)
        burst.Shape = Enum.PartType.Ball
        burst.Transparency = 0.3
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
--       СТАРТ БОЯ
-- ============================================================
function S.start()
  if not alive then return false end
  if S.active then return false end
  local c, h, r = getChar()
  if not r then
    if ORBIT.notify then ORBIT.notify("❌ Сначала заспавнись", C3(255, 150, 150), 2) end
    return false
  end
  S.active = true
  S.state = "fighting"
  S.hp = 400
  S.maxHp = 400
  S.phase = 1
  S.timer = 90
  S.startTick = tick()
  S.nextAttack = tick() + 2
  S.attackIndex = 0
  S.shots = {}
  S.hitTimes = {}
  fold()

  -- Сборка тела босса
  S.boss = buildSansBoss(3)
  local bossCenter = r.Position + V3(0, 10, -18)
  pcall(function() S.boss.model:PivotTo(CFrame.lookAt(bossCenter, r.Position)) end)

  -- Оранжевая пульсация заднего фона (cinematic)
  local cc = Instance.new("ColorCorrectionEffect")
  cc.Name = "OrbitSansBossCC"
  cc.Parent = Lighting
  S.cc = cc
  TS:Create(cc, TweenInfo.new(1.2), {
    Brightness = -0.12, Saturation = -0.15, TintColor = C3(230, 235, 255)
  }):Play()

  showBossUI()
  updateBossUI()
  hookDamage()

  -- Фразы при старте
  if ORBIT.sans and ORBIT.sans.say then
    task.delay(0.4, function() pcall(ORBIT.sans.say, "greet", true) end)
    task.delay(1.2, function() pcall(ORBIT.sans.say, "taunt", true) end)
  end

  ping("laugh", 1, 0.9)
  if ORBIT.notify then
    ORBIT.notify("💀 САНС ВЫШЕЛ НА БОЙ!", C3(200, 230, 255), 4)
    ORBIT.notify("⚔ Используй свои стихии — наноси урон!", C3(255, 200, 120), 5)
  end
  return true
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

  -- Салют из костей
  local bossPos = S.boss and S.boss.root and S.boss.root.Position or V3(0, 5, 0)
  for i = 1, 8 do
    task.delay(i * 0.1, function()
      if not alive then return end
      local p = ORBIT.newPart(fold(), "Reward", V3(1.5, 1.5, 1.5), CF(), COL_BONE)
      p.Shape = Enum.PartType.Ball
      p.Transparency = 0.2
      p.CFrame = CF(bossPos + V3(math.random(-8, 8), math.random(-4, 8), math.random(-8, 8)))
      local l = Instance.new("PointLight"); l.Color = COL_BONE; l.Range = 12; l.Brightness = 5; l.Parent = p
      TS:Create(p, TweenInfo.new(0.7), { Size = V3(12, 12, 12), Transparency = 1 }):Play()
      TS:Create(l, TweenInfo.new(0.9), { Brightness = 0 }):Play()
      Debris:AddItem(p, 1)
      ping("ping", 1, 0.8 + i * 0.1)
    end)
  end

  -- Фразы Санса при победе
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

  -- Разрушение модели босса
  task.delay(1.2, function()
    if S.boss and S.boss.model then pcall(function() S.boss.model:Destroy() end) end
    S.boss = nil
  end)

  -- Убираем cinematic
  task.delay(1.5, function()
    if S.cc then
      TS:Create(S.cc, TweenInfo.new(1.2), { Brightness = 0, Saturation = 0, TintColor = C3(255, 255, 255) }):Play()
      task.delay(1.5, function()
        if S.cc then pcall(function() S.cc:Destroy() end); S.cc = nil end
      end)
    end
  end)

  -- ВЫДАЧА НАГРАД
  ORBIT.saveData = ORBIT.saveData or {}
  ORBIT.saveData.rewards = ORBIT.saveData.rewards or {}
  local given = {}
  for _, rw in ipairs(REWARDS) do
    if not ORBIT.saveData.rewards[rw.id] then
      ORBIT.saveData.rewards[rw.id] = true
      given[#given + 1] = rw
    end
  end
  -- Монеты копим всегда
  ORBIT.COINS = (ORBIT.COINS or 0) + 500
  ORBIT.sansUnlocked = true
  ORBIT.sansKnifeUnlocked = true
  ORBIT.sansBlueEyeUnlocked = true
  ORBIT.saveData.sansUnlocked = true
  ORBIT.saveData.sansKnifeUnlocked = true
  ORBIT.saveData.sansBlueEyeUnlocked = true
  if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
  if ORBIT.saveStorage then pcall(ORBIT.saveStorage) end

  -- Показываем что получили
  if ORBIT.notify then
    ORBIT.notify("🏆 САНС ПОВЕРЖЕН!", C3(180, 255, 200), 5)
    for i, rw in ipairs(given) do
      task.delay(0.5 + i * 0.6, function()
        ORBIT.notify(rw.name .. " — " .. rw.desc, C3(200, 220, 255), 4)
      end)
    end
  end

  -- Сброс через 5 секунд
  task.delay(5, function()
    if alive then
      S.state = "idle"
      S.hp = 400
      S.timer = 90
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

  -- Фразы при провале
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
      S.timer = 90
    end
  end)
end

-- ============================================================
--       ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function stepBoss(dt, t)
  if not S.active then return end

  -- Таймер
  S.timer = S.timer - dt
  if S.timer <= 0 then
    S.failBoss("время вышло.")
    return
  end

  -- Обновление HP-UI (на случай если фаза сменилась)
  updateBossUI()

  -- Движение босса
  stepBossMovement(dt, t)

  -- Атаки: интервал зависит от фазы
  local attackInterval = S.phase == 1 and 3.5 or (S.phase == 2 and 2.5 or 1.8)
  if t >= S.nextAttack then
    S.nextAttack = t + attackInterval
    S.attackIndex = (S.attackIndex + 1) % 4
    local which = S.attackIndex
    -- Фаза 1: только кости и бластер
    -- Фаза 2: + телепорт
    -- Фаза 3: все + синий глаз
    if S.phase == 1 then
      which = (which % 2)  -- 0 или 1 → кости или бластер
    elseif S.phase == 2 then
      which = (which % 3)  -- 0, 1, 2 → кости, бластер, телепорт
    end
    if which == 0 then attackBoneVolley()
    elseif which == 1 then attackBlasterPair()
    elseif which == 2 then attackTeleportStrike()
    else attackBlueEye() end
  end

  -- Реакции по фразам: если долго не бьют — taunt
  if #S.hitTimes > 0 and t - S.hitTimes[#S.hitTimes] > 8 then
    if ORBIT.sans and ORBIT.sans.say then pcall(ORBIT.sans.say, "taunt") end
    S.hitTimes[#S.hitTimes] = t
  end
end

-- Следим за состоянием фаз и меняем фразы
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

-- Регистрация на Heartbeat
connect(RS.Heartbeat, function(dt)
  if not alive then return end
  stepShots(dt)
  if S.active then
    local t = tick()
    stepBoss(dt, t)
    checkPhasePhrases()
  end
end)

-- ============================================================
--       ОТКРЫТИЕ МЕНЮ БОССА
-- ============================================================
function S.open()
  if not alive then return false end
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return false end
  local old = pg:FindFirstChild("_OrbitBossMenu")
  if old then old:Destroy() end

  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitBossMenu"
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.DisplayOrder = 60
  sg.Parent = pg

  local backdrop = Instance.new("Frame")
  backdrop.Size = UDim2.fromScale(1, 1)
  backdrop.BackgroundColor3 = C3(0, 0, 0)
  backdrop.BackgroundTransparency = 0.5
  backdrop.BorderSizePixel = 0
  backdrop.ZIndex = 1
  backdrop.Parent = sg

  local win = Instance.new("Frame")
  win.AnchorPoint = Vector2.new(0.5, 0.5)
  win.Position = UDim2.fromScale(0.5, 0.5)
  win.Size = UDim2.fromOffset(440, 480)
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
  closeBtn.Activated:Connect(function() sg:Destroy() end)

  -- Карточка 1: САНС
  local function bossCard(y, icon, name, desc, hp, onClick, accent, isLocked)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -32, 0, 130); card.Position = UDim2.new(0, 16, 0, y)
    card.BackgroundColor3 = C3(28, 22, 45); card.BorderSizePixel = 0; card.ZIndex = 3
    card.Parent = win
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local cs = Instance.new("UIStroke", card)
    cs.Color = accent; cs.Thickness = 2; cs.Transparency = 0.3

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.fromOffset(70, 70); iconLbl.Position = UDim2.new(0, 10, 0, 10)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon; iconLbl.TextColor3 = accent
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
    btn.BackgroundColor3 = isLocked and C3(50, 40, 50) or accent
    btn.TextColor3 = isLocked and C3(160, 160, 180) or C3(20, 20, 30)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
    btn.Text = isLocked and "🔒 НЕДОСТУПНО" or "⚔ НАЧАТЬ БОЙ"
    btn.AutoButtonColor = false; btn.ZIndex = 4; btn.Parent = card
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    if not isLocked and onClick then
      btn.Activated:Connect(function()
        sg:Destroy()
        task.delay(0.3, onClick)
      end)
    end
  end

  bossCard(48, "💀", "САНС", "Летает, уклоняется, телепортируется.\nАтаки: кости, бластеры, синий глаз.",
           400, function() S.start() end, C3(100, 200, 255), false)

  bossCard(190, "👁", "ГАСТЕР", "Кружит вокруг, бьёт бластером и рукой.\nСобирай осколки, потом бой.",
           500, function()
             if ORBIT.gaster and ORBIT.gaster.open then ORBIT.gaster.open() end
           end, C3(200, 140, 255), false)

  -- Нижняя панель с наградами
  local rewardY = 336
  local rewardTitle = Instance.new("TextLabel")
  rewardTitle.Size = UDim2.new(1, -32, 0, 22); rewardTitle.Position = UDim2.new(0, 16, 0, rewardY)
  rewardTitle.BackgroundTransparency = 1
  rewardTitle.Text = "🎁 НАГРАДЫ ЗА ПОБЕДУ НАД САНСОМ:"
  rewardTitle.TextColor3 = C3(255, 240, 180); rewardTitle.Font = Enum.Font.GothamBold
  rewardTitle.TextSize = 12; rewardTitle.TextXAlignment = Enum.TextXAlignment.Left; rewardTitle.ZIndex = 3
  rewardTitle.Parent = win

  for i, rw in ipairs(REWARDS) do
    local rLbl = Instance.new("TextLabel")
    rLbl.Size = UDim2.new(1, -32, 0, 18); rLbl.Position = UDim2.new(0, 20, 0, rewardY + 24 + (i - 1) * 18)
    rLbl.BackgroundTransparency = 1
    local got = ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards[rw.id]
    rLbl.Text = (got and "✅ " or "▫ ") .. rw.name .. " — " .. rw.desc
    rLbl.TextColor3 = got and C3(180, 255, 180) or C3(200, 200, 220)
    rLbl.Font = Enum.Font.Gotham; rLbl.TextSize = 10
    rLbl.TextXAlignment = Enum.TextXAlignment.Left; rLbl.ZIndex = 3
    rLbl.Parent = win
  end

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
  if S.boss and S.boss.model then pcall(function() S.boss.model:Destroy() end) end
  S.boss = nil
  for _, q in ipairs(S.shots) do
    if q.part and q.part.Parent then pcall(function() q.part:Destroy() end) end
  end
  S.shots = {}
  if S.cc then pcall(function() S.cc:Destroy() end); S.cc = nil end
  if S.folder then pcall(function() S.folder:Destroy() end); S.folder = nil end
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
  ORBIT.notify("👹 Босс Санс v25.0 загружен (HP 400 + 5 наград)", C3(200, 230, 255), 3)
end

return true
