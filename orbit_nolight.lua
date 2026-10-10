-- ORBIT v24.9 | orbit_nolight.lua
-- Глобальный переключатель света: PointLight/SpotLight/SurfaceLight.
-- Ставит хук на Instance.new, сразу выключает существующие и периодически подчищает.

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
  PointLight = true,
  SpotLight = true,
  SurfaceLight = true,
}

local N = {
  enabled = false,
  saved = {},          -- part -> { orig = {Brightness=..., Enabled=...} }
  hookInstalled = false,
  origNew = nil,
  conns = {},
  gui = nil,
  btn = nil,
}

-- ===== Хук на Instance.new =====
local function applyOff(inst)
  if not inst or not inst:IsA("Light") then return end
  if N.saved[inst] then return end
  N.saved[inst] = {
    Brightness = inst.Brightness,
    Enabled = inst.Enabled,
    Range = inst.Range,
  }
  pcall(function()
    inst.Brightness = 0
    inst.Enabled = false
    inst.Range = 0
  end)
end

local function applyOn(inst)
  local s = N.saved[inst]
  if not s then return end
  pcall(function()
    inst.Brightness = s.Brightness
    inst.Enabled = s.Enabled
    inst.Range = s.Range
  end)
  N.saved[inst] = nil
end

local function installHook()
  if N.hookInstalled then return end
  N.origNew = Instance.new
  Instance.new = function(cls, parent)
    local inst = N.origNew(cls, parent)
    if N.enabled and LIGHT_CLASSES[cls] then applyOff(inst) end
    return inst
  end
  N.hookInstalled = true
end

local function uninstallHook()
  if not N.hookInstalled then return end
  if N.origNew then Instance.new = N.origNew end
  N.hookInstalled = false
  N.origNew = nil
end

-- ===== Обход всех источников =====
local function eachLight(fn)
  local roots = { WS, Lighting }
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if pg then roots[#roots + 1] = pg end
  for _, root in ipairs(roots) do
    for _, d in ipairs(root:GetDescendants()) do
      if d:IsA("Light") then pcall(fn, d) end
    end
  end
end

local function disableAll()
  eachLight(applyOff)
end

local function enableAll()
  local list = {}
  for inst in pairs(N.saved) do list[#list + 1] = inst end
  for _, inst in ipairs(list) do
    if inst and inst.Parent then applyOn(inst) end
  end
  N.saved = {}
end

-- ===== Периодический "пылесос" (на случай свет из-под других мест) =====
local sweepAcc = 0
local function onHeartbeat(dt)
  if not N.enabled then return end
  sweepAcc = sweepAcc + dt
  if sweepAcc < 1.5 then return end
  sweepAcc = 0
  disableAll()
end

-- ===== UI кнопка =====
local function buildBtn()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local sg = Instance.new("ScreenGui")
  sg.Name = "OrbitNoLightGui"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
  sg.DisplayOrder = 60; sg.Parent = pg
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
  local st = Instance.new("UIStroke", b); st.Color = Color3.fromRGB(200, 200, 255); st.Thickness = 1.5

  local function call(fn)
    local deb = false
    if deb then return end
    deb = true
    task.delay(0.15, function() deb = false end)
    pcall(fn)
  end
  local downT = 0
  b.MouseButton1Down:Connect(function() downT = tick() end)
  b.Activated:Connect(function()
    if tick() - downT < 0.05 then call(N.toggle) end
  end)

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

-- ===== Public API =====
function N.set(on)
  on = on and true or false
  if on == N.enabled then refreshBtn(); return end
  N.enabled = on
  if on then
    disableAll()
    installHook()
  else
    uninstallHook()
    enableAll()
  end
  refreshBtn()
  if ORBIT.notify then
    pcall(ORBIT.notify, on and "🌑 Свет выключен" or "💡 Свет включён",
      on and Color3.fromRGB(180, 180, 255) or Color3.fromRGB(255, 240, 180), 2)
  end
end

function N.toggle() N.set(not N.enabled) end

function N.destroy()
  pcall(uninstallHook)
  pcall(enableAll)
  for _, c in ipairs(N.conns) do pcall(function() c:Disconnect() end) end
  N.conns = {}
  if N.gui then pcall(function() N.gui:Destroy() end) end
  N.gui, N.btn = nil, nil
  N.saved = {}
end

-- ===== Start =====
installHook()
task.defer(function()
  buildBtn()
  refreshBtn()
  -- по умолчанию сразу глушим весь свет
  N.set(true)
end)

N.conns[#N.conns + 1] = RS.Heartbeat:Connect(onHeartbeat)

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
