-- ORBIT v24.9 | orbit_focus.lua
-- Режим игры: прячет все UI «ОРБИТЫ», логика/хоткеи остаются работать.

local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] focus: нет ORBIT"); return false end
if ORBIT.focus and ORBIT.focus.destroy then pcall(ORBIT.focus.destroy) end

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local SELF_NAME = "OrbitFocusGui"
local F = {
  enabled = false,
  saved = {},          -- [ScreenGui] = Enabled (bool)
  conns = {},
  gui = nil, btn = nil,
}

-- Ловим все GUI «ОРБИТЫ» по имени (кроме нашей кнопки)
local function isOrbitGui(obj)
  if not obj or not obj:IsA("ScreenGui") then return false end
  local n = obj.Name
  if n == SELF_NAME then return false end
  if n:sub(1, 5) == "Orbit" then return true end
  if n:sub(1, 6) == "_Orbit" then return true end   -- служебные (босс-бар и т.п.)
  return false
end

local function hideOne(sg)
  if F.saved[sg] ~= nil then return end
  F.saved[sg] = sg.Enabled
  pcall(function() sg.Enabled = false end)
end

local function hideAll()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  for _, c in ipairs(pg:GetChildren()) do
    if isOrbitGui(c) then hideOne(c) end
  end
end

local function showAll()
  for sg, state in pairs(F.saved) do
    if sg and sg.Parent then
      pcall(function() sg.Enabled = state end)
    end
  end
  F.saved = {}
end

-- ===== Кнопка =====
local function buildBtn()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local sg = Instance.new("ScreenGui")
  sg.Name = SELF_NAME; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 70; sg.Parent = pg

  local b = Instance.new("TextButton")
  b.AnchorPoint = Vector2.new(1, 0)
  b.Position = UDim2.new(1, -8, 0, 58)      -- под кнопкой 💡 (orbit_nolight)
  b.Size = UDim2.fromOffset(52, 44)
  b.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
  b.BackgroundTransparency = 0.1
  b.TextColor3 = Color3.fromRGB(230, 230, 240)
  b.Font = Enum.Font.GothamBold
  b.TextSize = 20
  b.Text = "🎮"
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
    pcall(F.toggle)
  end
  b.MouseButton1Down:Connect(tap)
  b.Activated:Connect(tap)

  F.gui, F.btn = sg, b
end

local function refreshBtn()
  if not F.btn or not F.btn.Parent then return end
  if F.enabled then
    F.btn.BackgroundColor3 = Color3.fromRGB(20, 55, 32)
    F.btn.TextColor3 = Color3.fromRGB(180, 255, 200)
  else
    F.btn.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    F.btn.TextColor3 = Color3.fromRGB(230, 230, 240)
  end
end

-- ===== API =====
function F.set(on)
  on = on and true or false
  if on == F.enabled then refreshBtn(); return end
  F.enabled = on
  if on then hideAll() else showAll() end
  refreshBtn()
  if ORBIT.notify then
    pcall(ORBIT.notify,
      on and "🎮 Режим игры: интерфейс скрыт" or "🖥 Интерфейс восстановлен",
      on and Color3.fromRGB(180, 255, 200) or Color3.fromRGB(200, 220, 255), 2)
  end
end

function F.toggle() F.set(not F.enabled) end

function F.destroy()
  pcall(showAll)
  for _, c in ipairs(F.conns) do pcall(function() c:Disconnect() end) end
  F.conns = {}
  if F.gui then pcall(function() F.gui:Destroy() end) end
  F.gui, F.btn = nil, nil
end

-- ===== Новые окна в фокус-режиме прячем сразу =====
task.defer(function()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local c = pg.DescendantAdded:Connect(function(d)
    if F.enabled and isOrbitGui(d) then hideOne(d) end
  end)
  F.conns[#F.conns + 1] = c
end)

-- ===== Старт =====
task.defer(function()
  buildBtn()
  refreshBtn()
end)

ORBIT.focus = F
ORBIT.loaded = ORBIT.loaded or {}
ORBIT.loaded.focus = true

local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(F.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("🎮 Кнопка режима игры добавлена", Color3.fromRGB(200, 255, 210), 3)
end

return true
