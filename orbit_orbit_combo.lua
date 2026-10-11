-- ORBIT v25.0-fix1 | orbit_orbit_combo.lua
-- Орбит-комбо: Санс + Гастер крутятся вокруг игрока, атакуют врагов.
-- Требуется победа над обоими боссами.
-- Санс: раз в 2 сек веер костей в ближайшего врага.
-- Гастер: раз в 3 сек бластер по ближайшему.
-- v25.0-fix1: мобильная кнопка 🌀 — двойной обработчик (MouseButton1Down + Activated)
--             с дебаунсом 250мс. Одиночный Activated на Delta Mobile срабатывает ненадёжно.
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] orbit_combo: нет ORBIT"); return false end
if ORBIT.orbit_combo and ORBIT.orbit_combo.destroy then pcall(ORBIT.orbit_combo.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TS = game:GetService("TweenService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB

local O = {
  active = false,
  folder = nil,
  sansModel = nil,
  gasterModel = nil,
  sansAngle = 0,
  gasterAngle = math.pi,
  sansNext = 0,
  gasterNext = 0,
  duration = 30,
  endTime = 0,
  orbitR = 12,
  orbitY = 4,
  ui = nil,
}
local alive, conns = true, {}

local function connect(sig, fn) local c = sig:Connect(fn); conns[#conns + 1] = c; return c end
local function fold()
  if O.folder and O.folder.Parent then return O.folder end
  O.folder = Instance.new("Folder")
  O.folder.Name = "OrbitCombo_" .. LP.UserId
  O.folder.Parent = WS
  return O.folder
end
local function getChar()
  local c = LP.Character
  if not c then return nil end
  local h = c:FindFirstChildOfClass("Humanoid")
  local r = c:FindFirstChild("HumanoidRootPart")
  if not h or not r or h.Health <= 0 then return nil end
  return c, h, r
end
local function enemies()
  local out = {}
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP and p.Character then
      local h = p.Character:FindFirstChildOfClass("Humanoid")
      local r = p.Character:FindFirstChild("HumanoidRootPart")
      if h and r and h.Health > 0 then out[#out + 1] = { hum = h, root = r } end
    end
  end
  return out
end
local function nearest(center, maxD)
  maxD = maxD or 70
  local best, bd = nil, maxD
  for _, e in ipairs(enemies()) do
    local d = (e.root.Position - center).Magnitude
    if d < bd then best, bd = e, d end
  end
  return best
end

-- ============================================================
--       СБОРКА ФИГУР
-- ============================================================
local function buildFigure(name)
  local presets = ORBIT.SHAPE_PRESETS
  local preset = nil
  if type(presets) == "table" then
    for _, p in ipairs(presets) do
      if p.name == name then preset = p; break end
    end
  end
  if not preset or type(preset.create) ~= "function" then
    warn("[OrbitCombo] пресет «" .. name .. "» не найден")
    return nil
  end
  local ok, data = pcall(preset.create, 2.2, "OrbitCombo_" .. name)
  if not ok or not data or not data.model then
    warn("[OrbitCombo] create «" .. name .. "» упал")
    return nil
  end
  data.model.Parent = fold()
  return data
end

-- ============================================================
--       АТАКИ
-- ============================================================
local function sansAttack(model, target)
  local ab = ORBIT.abilities
  if not ab or not ab.spawnBones then return end
  local from = model:GetPivot().Position + V3(0, 2, 0)
  local to = target.root.Position + V3(0, 1, 0)
  local d = (to - from)
  if d.Magnitude < 0.5 then d = V3(0, 0, 1) end
  local dir = d.Unit
  pcall(ab.spawnBones, from, dir, 3, 14, 1.2, false)
  if ORBIT.sans and ORBIT.sans.say and math.random() < 0.2 then
    pcall(ORBIT.sans.say, "attack")
  end
end

local function gasterAttack(model, target)
  local ab = ORBIT.abilities
  if not ab or not ab.fireBlaster then
    -- fallback: простой луч
    local from = model:GetPivot().Position + V3(0, 2, 0)
    local to = target.root.Position
    local d = (to - from)
    if d.Magnitude < 0.5 then return end
    local beam = ORBIT.newPart(fold(), "ComboBeam", V3(1.2, 1.2, d.Magnitude), CF(), C3(180, 220, 255))
    beam.CFrame = CFrame.lookAt((from + to) / 2, to)
    beam.Transparency = 0.15
    local l = Instance.new("PointLight"); l.Color = C3(180, 220, 255); l.Range = 20; l.Brightness = 5; l.Parent = beam
    TS:Create(beam, TweenInfo.new(0.5), { Size = V3(0.1, 0.1, d.Magnitude), Transparency = 1 }):Play()
    TS:Create(l, TweenInfo.new(0.5), { Brightness = 0 }):Play()
    Debris:AddItem(beam, 0.6)
    pcall(function() target.hum:TakeDamage(35) end)
    return
  end
  local from = model:GetPivot().Position + V3(0, 3, 0)
  local to = target.root.Position
  local d = (to - from)
  if d.Magnitude < 0.5 then return end
  pcall(ab.fireBlaster, from, d.Unit, 1, 1)
end

-- ============================================================
--       ГЛАВНЫЙ ЦИКЛ
-- ============================================================
local function step(dt, t)
  if not O.active then return end
  local c, h, r = getChar()
  if not r then O.stop(); return end
  -- проверка таймера
  if t >= O.endTime then O.stop("⌛ Комбо завершено"); return end

  -- круги
  O.sansAngle = O.sansAngle + dt * 1.0
  O.gasterAngle = O.gasterAngle + dt * 1.0

  local sansPos = r.Position + V3(math.cos(O.sansAngle) * O.orbitR, O.orbitY, math.sin(O.sansAngle) * O.orbitR)
  local gasterPos = r.Position + V3(math.cos(O.gasterAngle) * O.orbitR, O.orbitY, math.sin(O.gasterAngle) * O.orbitR)

  if O.sansModel and O.sansModel.model and O.sansModel.model.Parent then
    pcall(function() O.sansModel.model:PivotTo(CFrame.lookAt(sansPos, r.Position)) end)
  else
    O.sansModel = nil
  end
  if O.gasterModel and O.gasterModel.model and O.gasterModel.model.Parent then
    pcall(function() O.gasterModel.model:PivotTo(CFrame.lookAt(gasterPos, r.Position)) end)
  else
    O.gasterModel = nil
  end

  -- атаки
  if O.sansModel and t >= O.sansNext then
    O.sansNext = t + 2.0
    local target = nearest(O.sansModel.model:GetPivot().Position)
    if target then sansAttack(O.sansModel.model, target) end
  end
  if O.gasterModel and t >= O.gasterNext then
    O.gasterNext = t + 3.0
    local target = nearest(O.gasterModel.model:GetPivot().Position)
    if target then gasterAttack(O.gasterModel.model, target) end
  end

  -- UI таймер
  if O.ui and O.ui.timer then
    local left = math.max(0, math.floor(O.endTime - t))
    O.ui.timer.Text = "🌀 ОРБИТ-КОМБО  •  " .. left .. "с"
  end
end

-- ============================================================
--       UI
-- ============================================================
local function buildUI()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitComboUI"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
  sg.DisplayOrder = 45; sg.Parent = pg

  local frame = Instance.new("Frame")
  frame.AnchorPoint = Vector2.new(0.5, 0); frame.Position = UDim2.new(0.5, 0, 0, 96)
  frame.Size = UDim2.fromOffset(320, 30)
  frame.BackgroundColor3 = C3(15, 10, 25); frame.BackgroundTransparency = 0.15
  frame.Parent = sg
  Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
  local st = Instance.new("UIStroke", frame); st.Color = C3(150, 130, 255); st.Thickness = 1.5

  local timer = Instance.new("TextLabel")
  timer.Size = UDim2.new(1, 0, 1, 0); timer.BackgroundTransparency = 1
  timer.Text = "🌀 ОРБИТ-КОМБО"
  timer.TextColor3 = C3(220, 220, 255); timer.Font = Enum.Font.GothamBold
  timer.TextSize = 14; timer.Parent = frame

  O.ui = { sg = sg, frame = frame, timer = timer }
end

local function destroyUI()
  if O.ui and O.ui.sg then pcall(function() O.ui.sg:Destroy() end) end
  O.ui = nil
end

-- ============================================================
--       API
-- ============================================================
function O.canStart()
  return (ORBIT.sansUnlocked and ORBIT.gasterUnlocked)
end

function O.start()
  if not alive then return false end
  if O.active then return false end
  if not O.canStart() then
    if ORBIT.notify then
      ORBIT.notify("🔒 Нужно победить Санса и Гастера", C3(255, 200, 120), 3)
    end
    return false
  end
  local c, h, r = getChar()
  if not r then
    if ORBIT.notify then ORBIT.notify("❌ Сначала заспавнись", C3(255, 150, 150), 2) end
    return false
  end

  fold()
  -- сборка фигур
  local sansData = buildFigure("САНС")
  local gasterData = buildFigure("ГАСТЕР")
  if not sansData and not gasterData then
    if ORBIT.notify then ORBIT.notify("❌ Фигуры не загружены", C3(255, 150, 150), 3) end
    return false
  end

  O.sansModel = sansData
  O.gasterModel = gasterData
  O.sansAngle = 0
  O.gasterAngle = math.pi
  O.sansNext = tick() + 1
  O.gasterNext = tick() + 1.5
  O.endTime = tick() + O.duration
  O.active = true

  buildUI()
  -- вспышка появления
  for _, sd in ipairs({0, math.pi}) do
    local pos = r.Position + V3(math.cos(sd) * O.orbitR, O.orbitY, math.sin(sd) * O.orbitR)
    local p = ORBIT.newPart(fold(), "SpawnFx", V3(2, 2, 2), CF(pos), C3(200, 220, 255))
    p.Shape = Enum.PartType.Ball; p.Transparency = 0.3
    local l = Instance.new("PointLight"); l.Color = C3(200, 220, 255); l.Range = 15; l.Brightness = 8; l.Parent = p
    TS:Create(p, TweenInfo.new(0.6), { Size = V3(15, 15, 15), Transparency = 1 }):Play()
    TS:Create(l, TweenInfo.new(0.7), { Brightness = 0 }):Play()
    Debris:AddItem(p, 0.8)
  end

  if ORBIT.notify then
    ORBIT.notify("🌀 ОРБИТ-КОМБО активировано на " .. O.duration .. " сек!", C3(200, 220, 255), 4)
  end
  if ORBIT.sans and ORBIT.sans.say then
    task.delay(0.5, function() pcall(ORBIT.sans.say, "combo", true) end)
  end
  return true
end

function O.stop(reason)
  if not O.active then return end
  O.active = false
  destroyUI()
  -- рассеивание фигур
  for _, d in ipairs({O.sansModel, O.gasterModel}) do
    if d and d.model and d.model.Parent then
      local m = d.model
      task.spawn(function()
        for _, p in ipairs(m:GetDescendants()) do
          if p:IsA("BasePart") then
            TS:Create(p, TweenInfo.new(0.7), { Transparency = 1 }):Play()
          end
        end
        task.wait(0.8)
        pcall(function() m:Destroy() end)
      end)
    end
  end
  O.sansModel = nil
  O.gasterModel = nil
  if ORBIT.notify then
    ORBIT.notify(reason or "🌀 Орбит-комбо завершено", C3(200, 220, 255), 3)
  end
end

function O.toggle()
  if O.active then O.stop() else O.start() end
end

-- ============================================================
--       КНОПКА ДЛЯ МОБИЛКИ
-- ============================================================
local function buildMobileBtn()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old = pg:FindFirstChild("_OrbitComboBtn")
  if old then old:Destroy() end
  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitComboBtn"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
  sg.DisplayOrder = 44; sg.Parent = pg
  local b = Instance.new("TextButton")
  b.AnchorPoint = Vector2.new(1, 1); b.Position = UDim2.new(1, -16, 1, -380)
  b.Size = UDim2.fromOffset(56, 56); b.Text = "🌀"; b.TextSize = 28
  b.Font = Enum.Font.GothamBold; b.TextColor3 = C3(255, 255, 255)
  b.BackgroundColor3 = C3(60, 50, 110); b.BackgroundTransparency = 0.1
  b.AutoButtonColor = false; b.Parent = sg
  Instance.new("UICorner", b).CornerRadius = UDim.new(0, 28)
  local st = Instance.new("UIStroke", b); st.Color = C3(150, 130, 255); st.Thickness = 2

  -- v25.0-fix1: двойной обработчик с дебаунсом.
  -- На Delta Mobile одиночный Activated срабатывает через раз —
  -- ловим и MouseButton1Down (мгновенно при касании), и Activated (страховка).
  local lastClick = 0
  local function fire()
    local t = tick()
    if t - lastClick < 0.25 then return end
    lastClick = t
    pcall(O.toggle)
  end
  b.MouseButton1Down:Connect(fire)
  b.Activated:Connect(fire)

  O.mobileBtn = sg
end
buildMobileBtn()

-- ============================================================
--       HEARTBEAT
-- ============================================================
connect(RS.Heartbeat, function(dt)
  if alive then step(dt, tick()) end
end)

-- ============================================================
--       ОЧИСТКА
-- ============================================================
function O.destroy()
  if not alive then return end
  alive = false
  O.active = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  conns = {}
  destroyUI()
  if O.mobileBtn then pcall(function() O.mobileBtn:Destroy() end) end
  for _, d in ipairs({O.sansModel, O.gasterModel}) do
    if d and d.model then pcall(function() d.model:Destroy() end) end
  end
  if O.folder then pcall(function() O.folder:Destroy() end); O.folder = nil end
end

ORBIT.orbit_combo = O
ORBIT.loaded.orbit_combo = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(O.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("🌀 Орбит-комбо v25.0-fix1 загружено (Санс + Гастер вокруг)", C3(200, 220, 255), 3)
end

return true
