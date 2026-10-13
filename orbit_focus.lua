-- ORBIT v24.9 | orbit_focus.lua
-- Режим игры: прячет ТОЛЬКО UI «ОРБИТЫ» (Orbit* / _Orbit*).
-- Чат, бэкпак, Tab-список, топбар Roblox и сторонние скрипты — НЕ трогает.
-- Хоткеи и логика при этом продолжают работать.
-- v25.0: кнопку можно перетаскивать (drag) и сворачивать (long-press 0.75с).
--   Позиция сохраняется в orbit_focus_pos.json (если доступна FS).
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] focus: нет ORBIT"); return false end
if ORBIT.focus and ORBIT.focus.destroy then pcall(ORBIT.focus.destroy) end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer

local SELF_NAME = "OrbitFocusGui"
local POS_FILE = "orbit_focus_pos.json"
local BTN_W, BTN_H = 52, 44     -- обычный размер
local MINI_W, MINI_H = 22, 22   -- свёрнутый размер
local LONG_MS = 750             -- порог долгого нажатия
local DRAG_PX = 6               -- порог "мы двинули, это не тап"

local F = {
  enabled = false,
  collapsed = false,    -- свёрнута ли кнопка в точку
  saved = {},           -- [ScreenGui] = Enabled
  conns = {},
  gui = nil, btn = nil,
  -- drag-состояние
  dragging = false,
  movedFar = false,
  dragStart = nil,
  dragCenter = nil,
  longToken = 0,
}

-- ===== Утилиты =====
local function getRoots()
  local roots = {}
  local g = rawget(GENV, "gethui")
  if type(g) == "function" then
    local ok, h = pcall(g)
    if ok and h then roots[#roots + 1] = h end
  end
  pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if pg then roots[#roots + 1] = pg end
  return roots
end

-- Только UI «ОРБИТЫ» — по имени.
-- Наш собственный GUI (SELF_NAME) не трогаем.
local function isOrbitGui(obj)
  if not obj or not obj:IsA("ScreenGui") then return false end
  local n = obj.Name
  if n == SELF_NAME then return false end
  if n:sub(1, 5) == "Orbit" then return true end     -- OrbitAbilitiesGui, OrbitSansBossGui и т.п.
  if n:sub(1, 6) == "_Orbit" then return true end    -- _OrbitLoader_*, _OrbitMain, _OrbitShop, _OrbitEditor2D и т.п.
  return false
end

local function hideOne(sg)
  if F.saved[sg] ~= nil then return end
  F.saved[sg] = sg.Enabled
  pcall(function() sg.Enabled = false end)
end

local function hideAll()
  for _, root in ipairs(getRoots()) do
    local ok, kids = pcall(function() return root:GetChildren() end)
    if ok then
      for _, c in ipairs(kids) do
        if isOrbitGui(c) then hideOne(c) end
      end
    end
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

-- ===== Позиция: сохранение/загрузка =====
local function viewport()
  local cam = WS.CurrentCamera
  return (cam and cam.ViewportSize) or Vector2.new(1280, 720)
end

local function defaultCenter()
  local vp = viewport()
  return Vector2.new(vp.X - 8 - BTN_W / 2, 58 + BTN_H / 2)
end

local function clampCenter(c, w, h)
  local vp = viewport()
  local hw, hh = w / 2, h / 2
  return Vector2.new(
    math.clamp(c.X, hw, vp.X - hw),
    math.clamp(c.Y, hh, vp.Y - hh)
  )
end

local function loadPos()
  if not ORBIT.HAS_FS then return nil end
  if type(isfile) ~= "function" or not isfile(POS_FILE) then return nil end
  local ok, txt = pcall(readfile, POS_FILE)
  if not ok or type(txt) ~= "string" or #txt < 3 then return nil end
  local ok2, d = pcall(function() return ORBIT.HttpService:JSONDecode(txt) end)
  if ok2 and type(d) == "table" and tonumber(d.X) and tonumber(d.Y) then
    return Vector2.new(d.X, d.Y)
  end
  return nil
end

local savePending = false
local function scheduleSave()
  if savePending then return end
  savePending = true
  task.delay(0.5, function()
    savePending = false
    if not ORBIT.HAS_FS or not F.btn then return end
    local p = F.btn.Position
    pcall(function()
      writefile(POS_FILE, ORBIT.HttpService:JSONEncode({ X = p.X.Offset, Y = p.Y.Offset }))
    end)
  end)
end

-- ===== Кнопка =====
local function applyCollapsed()
  if not F.btn then return end
  local b = F.btn
  if F.collapsed then
    b.Size = UDim2.fromOffset(MINI_W, MINI_H)
    b.BackgroundTransparency = 0.75
    b.TextTransparency = 0.55
    b.Text = "·"
    b.TextSize = 16
    if b:FindFirstChildOfClass("UIStroke") then
      b:FindFirstChildOfClass("UIStroke").Transparency = 0.7
    end
  else
    b.Size = UDim2.fromOffset(BTN_W, BTN_H)
    b.BackgroundTransparency = 0.1
    b.TextTransparency = 0
    b.Text = "🎮"
    b.TextSize = 20
    if b:FindFirstChildOfClass("UIStroke") then
      b:FindFirstChildOfClass("UIStroke").Transparency = 0
    end
  end
end

local function buildBtn()
  local parent
  if ORBIT.getSafeParent then
    local ok, p = pcall(ORBIT.getSafeParent)
    if ok and p then parent = p end
  end
  if not parent then parent = LP:FindFirstChildOfClass("PlayerGui") end
  if not parent then return end

  local sg = Instance.new("ScreenGui")
  sg.Name = SELF_NAME; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 65; sg.Parent = parent
  if ORBIT.protectGui then pcall(ORBIT.protectGui, sg) end

  local b = Instance.new("TextButton")
  b.Name = "ToggleBtn"
  b.AnchorPoint = Vector2.new(0.5, 0.5)
  b.Size = UDim2.fromOffset(BTN_W, BTN_H)
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

  local c = loadPos() or defaultCenter()
  c = clampCenter(c, BTN_W, BTN_H)
  b.Position = UDim2.fromOffset(c.X, c.Y)

  F.gui, F.btn = sg, b
  applyCollapsed()
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

-- ===== Ввод на кнопке: tap / drag / long-press =====
local function wireBtn(b)
  b.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
      and input.UserInputType ~= Enum.UserInputType.Touch then return end
    F.dragging = true
    F.movedFar = false
    F.dragStart = input.Position
    F.dragCenter = Vector2.new(b.Position.X.Offset, b.Position.Y.Offset)
    F.longToken = F.longToken + 1
    local myToken = F.longToken
    task.delay(LONG_MS / 1000, function()
      if F.dragging and F.longToken == myToken and not F.movedFar then
        F.dragging = false
        F.collapsed = not F.collapsed
        applyCollapsed()
        if ORBIT.notify then
          pcall(ORBIT.notify,
            F.collapsed and "🎮 Кнопка свёрнута" or "🎮 Кнопка развёрнута",
            Color3.fromRGB(200, 220, 255), 1.5)
        end
      end
    end)
  end)

  UIS.InputChanged:Connect(function(input)
    if not F.dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
      and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - F.dragStart
    if delta.Magnitude > DRAG_PX then F.movedFar = true end
    local size = F.collapsed and Vector2.new(MINI_W, MINI_H) or Vector2.new(BTN_W, BTN_H)
    local newC = clampCenter(F.dragCenter + Vector2.new(delta.X, delta.Y), size.X, size.Y)
    b.Position = UDim2.fromOffset(newC.X, newC.Y)
  end)

  UIS.InputEnded:Connect(function(input)
    if not F.dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
      and input.UserInputType ~= Enum.UserInputType.Touch then return end
    F.dragging = false
    F.longToken = F.longToken + 1
    if not F.movedFar then
      pcall(F.toggle)
    else
      scheduleSave()
    end
  end)
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
      on and "🎮 Режим игры: UI ОРБИТЫ скрыт" or "🖥 UI ОРБИТЫ восстановлен",
      on and Color3.fromRGB(180, 255, 200) or Color3.fromRGB(200, 220, 255), 2)
  end
end

function F.toggle() F.set(not F.enabled) end

function F.setCollapsed(v)
  F.collapsed = v and true or false
  applyCollapsed()
end

function F.resetPosition()
  if not F.btn then return end
  local c = clampCenter(defaultCenter(), BTN_W, BTN_H)
  F.btn.Position = UDim2.fromOffset(c.X, c.Y)
  scheduleSave()
end

function F.destroy()
  pcall(showAll)
  for _, c in ipairs(F.conns) do pcall(function() c:Disconnect() end) end
  F.conns = {}
  local function killRoot(root)
    if not root then return end
    local found = root:FindFirstChild(SELF_NAME)
    if found then pcall(function() found:Destroy() end) end
  end
  killRoot(LP:FindFirstChildOfClass("PlayerGui"))
  pcall(function() killRoot(game:GetService("CoreGui")) end)
  do
    local g = rawget(GENV, "gethui")
    if type(g) == "function" then
      local ok, h = pcall(g)
      if ok then pcall(killRoot, h) end
    end
  end
  if F.gui then pcall(function() F.gui:Destroy() end) end
  F.gui, F.btn = nil, nil
end

-- ===== Новые окна ОРБИТЫ в фокус-режиме прячем сразу =====
task.defer(function()
  for _, root in ipairs(getRoots()) do
    local ok, conn = pcall(function()
      return root.DescendantAdded:Connect(function(d)
        if not F.enabled then return end
        if isOrbitGui(d) then hideOne(d) end
      end)
    end)
    if ok and conn then F.conns[#F.conns + 1] = conn end
  end
end)

-- ===== Старт =====
task.defer(function()
  buildBtn()
  if F.btn then
    refreshBtn()
    wireBtn(F.btn)
  end
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
