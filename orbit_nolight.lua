-- ORBIT v24.9 | orbit_nolight.lua
-- Безопасное отключение света (без патча Instance.new — Delta запрещает).

local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] nolight: нет ORBIT"); return false end
if ORBIT.nolight and ORBIT.nolight.destroy then pcall(ORBIT.nolight.destroy) end

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LP = Players.LocalPlayer

local LIGHT_CLASSES = {
  PointLight = true, SpotLight = true, SurfaceLight = true,
}
local FX_CLASSES = {
  BloomEffect = true, SunRaysEffect = true,
}

local N = {
  enabled = false,
  saved = {},
  conns = {},
  gui = nil, btn = nil,
}

local function isTarget(inst)
  if not inst then return false end
  local ok, cls = pcall(function() return inst.ClassName end)
  if not ok then return false end
  return LIGHT_CLASSES[cls] == true or FX_CLASSES[cls] == true
end

local function applyOff(inst)
  if not inst or N.saved[inst] then return end
  local ok, cls = pcall(function() return inst.ClassName end)
  if not ok then return end
  local snap = {}
  if cls == "PointLight" or cls == "SpotLight" or cls == "SurfaceLight" then
    snap.Brightness = inst.Brightness
    snap.Enabled = inst.Enabled
    snap.Range = inst.Range
    pcall(function()
      inst.Brightness = 0
      inst.Enabled = false
      inst.Range = 0
    end)
  elseif cls == "BloomEffect" or cls == "SunRaysEffect" then
    snap.Enabled = inst.Enabled
    snap.Intensity = inst.Intensity
    snap.Size = inst.Size
    snap.Threshold = inst.Threshold
    pcall(function()
      inst.Enabled = false
      inst.Intensity = 0
      if snap.Size ~= nil then inst.Size = 0 end
      if snap.Threshold ~= nil then inst.Threshold = 100 end
    end)
  else
    return
  end
  N.saved[inst] = snap
end

local function applyOn(inst)
  local s = N.saved[inst]
  if not s then return end
  pcall(function()
    for k, v in pairs(s) do inst[k] = v end
  end)
  N.saved[inst] = nil
end

local function iterRoots()
  return { WS, Lighting, LP:FindFirstChildOfClass("PlayerGui") }
end

local function disableAll()
  for _, root in ipairs(iterRoots()) do
    if root then
      for _, d in ipairs(root:GetDescendants()) do
        if isTarget(d) then applyOff(d) end
      end
      -- собственный свет + эффекты корня
      if isTarget(root) then applyOff(root) end
    end
  end
end

local function enableAll()
  local list = {}
  for inst in pairs(N.saved) do list[#list + 1] = inst end
  for _, inst in ipairs(list) do
    if inst and inst.Parent then applyOn(inst) end
  end
  N.saved = {}
end

-- ===== DescendantAdded: мгновенно ловим новый свет =====
local function watchRoot(root)
  if not root then return end
  local c = root.DescendantAdded:Connect(function(d)
    if N.enabled and isTarget(d) then applyOff(d) end
  end)
  N.conns[#N.conns + 1] = c
end

-- ===== Периодический пылесос =====
local acc = 0
local function onHeartbeat(dt)
  if not N.enabled then return end
  acc = acc + dt
  if acc < 0.8 then return end
  acc = 0
  disableAll()
end

-- ===== UI =====
local function buildBtn()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local sg = Instance.new("ScreenGui")
  sg.Name = "OrbitNoLightGui"; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 60; sg.Parent = pg

  local b = Instance.new("TextButton")
  b.AnchorPoint = Vector2.new(1, 0)
  b.Position = UDim2.new(1, -8, 0, 8)
  b.Size = UDim2.fromOffset(52, 44)
  b.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
  b.BackgroundTransparency = 0.1
  b.TextColor3 = Color3.fromRGB(230, 230, 240)
  b.Font = Enum.Font.GothamBold
  b.TextSize = 20
  b.Text = "💡"
  b.AutoButtonColor = false
  b.Parent = sg
  Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
  local st = Instance.new("UIStroke", b)
  st.Color = Color3.fromRGB(200, 200, 255); st.Thickness = 1.5

  local deb = false
  local function tap()
    if deb then return end
    deb = true
    task.delay(0.18, function() deb = false end)
    pcall(N.toggle)
  end
  b.MouseButton1Down:Connect(function() tap() end)
  b.Activated:Connect(function() tap() end)

  N.gui, N.btn = sg, b
end

local function refreshBtn()
  if not N.btn or not N.btn.Parent then return end
  if N.enabled then
    N.btn.Text = "🌑"
    N.btn.BackgroundColor3 = Color3.fromRGB(60, 20, 30)
    N.btn.TextColor3 = Color3.fromRGB(255, 180, 180)
  else
    N.btn.Text = "💡"
    N.btn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    N.btn.TextColor3 = Color3.fromRGB(230, 230, 240)
  end
end

-- ===== API =====
function N.set(on)
  on = on and true or false
  if on == N.enabled then refreshBtn(); return end
  N.enabled = on
  if on then
    disableAll()
  else
    enableAll()
  end
  refreshBtn()
  if ORBIT.notify then
    pcall(ORBIT.notify,
      on and "🌑 Свет выключен" or "💡 Свет включён",
      on and Color3.fromRGB(180, 180, 255) or Color3.fromRGB(255, 240, 180), 2)
  end
end

function N.toggle() N.set(not N.enabled) end

function N.destroy()
  pcall(enableAll)
  for _, c in ipairs(N.conns) do pcall(function() c:Disconnect() end) end
  N.conns = {}
  if N.gui then pcall(function() N.gui:Destroy() end) end
  N.gui, N.btn = nil, nil
  N.saved = {}
end

-- ===== Start =====
watchRoot(WS)
watchRoot(Lighting)
task.defer(function()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if pg then watchRoot(pg) end
end)

N.conns[#N.conns + 1] = RS.Heartbeat:Connect(onHeartbeat)

task.defer(function()
  buildBtn()
  refreshBtn()
  N.set(true)  -- сразу гасим
end)

ORBIT.nolight = N
ORBIT.loaded = ORBIT.loaded or {}
ORBIT.loaded.nolight = true

local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(N.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("💡 Кнопка света добавлена (правый верхний угол)", Color3.fromRGB(200, 220, 255), 3)
end

return true
