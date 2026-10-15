-- ORBIT v1.0 | orbit_admin.lua
-- Требует админ-код. Правильный → всё разблокировано. Неправильный → оба босса.
-- Отдельный скрипт. Запускается поверх уже работающей ОРБИТЫ (ORBIT должен существовать).
--
-- Как использовать:
--   1. Запусти основной загрузчик ОРБИТЫ (loadstring от orbit_loader).
--   2. Дождись полной загрузки и запуска (меню ОРБИТА появилось).
--   3. Запусти этот скрипт.
--   4. Введи код в поле:
--      - верный код  = всё разблокировано (награды, оружие, скины, титулы, монеты);
--      - неверный код = одновременно спавнятся Санс и Гастер, «пробуй сам».
--
-- ВАЖНО: прежде чем раздавать файл — смени ADMIN_CODE ниже на свой.

local ADMIN_CODE = BAPCUk

local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then
  warn("[ORBIT admin] ОРБИТА не запущена — сначала загрузи основной скрипт")
  return
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer
local C3 = Color3.fromRGB

local function uiParent()
  if type(ORBIT.getSafeParent) == "function" then
    local ok, p = pcall(ORBIT.getSafeParent)
    if ok and typeof(p) == "Instance" then return p end
  end
  return LP:FindFirstChildOfClass("PlayerGui")
end

local function killOld()
  local name = "_OrbitAdminPanel"
  local a = uiParent()
  if a then local g = a:FindFirstChild(name); if g then g:Destroy() end end
  local b = LP:FindFirstChildOfClass("PlayerGui")
  if b then local g = b:FindFirstChild(name); if g then g:Destroy() end end
end

-- === Выдача всего ===
local function grantAll()
  ORBIT.sansUnlocked = true
  ORBIT.gasterUnlocked = true
  ORBIT.gasterWeaponUnlocked = true
  ORBIT.sansKnifeUnlocked = true
  ORBIT.sansBlueEyeUnlocked = true

  ORBIT.saveData = ORBIT.saveData or {}
  ORBIT.saveData.sansUnlocked = true
  ORBIT.saveData.gasterUnlocked = true
  ORBIT.saveData.gasterWeaponUnlocked = true
  ORBIT.saveData.sansKnifeUnlocked = true
  ORBIT.saveData.sansBlueEyeUnlocked = true

  ORBIT.saveData.rewards = ORBIT.saveData.rewards or {}
  local ids = {
    "sans_knife","blue_eye","coins_sans","sans_chat","sans_boss_skin","sans_ghost",
    "gaster_weapon","gaster_boss_skin","blue_eye_tick","gaster_skull_helmet",
    "gaster_double_blaster","gaster_portal_fx","gaster_blue_particles","coins_gaster",
    "gaster_dark_cloak","blade_master","orbit_legend","coins",
  }
  for _, id in ipairs(ids) do ORBIT.saveData.rewards[id] = true end

  ORBIT.COINS = (ORBIT.COINS or 0) + 1000000

  if ORBIT.saveSettings then pcall(ORBIT.saveSettings) end
  if ORBIT.saveStorage  then pcall(ORBIT.saveStorage)  end
end

-- === Спавн двух боссов ===
local function spawnBothBosses()
  task.spawn(function()
    if ORBIT.sans_boss and type(ORBIT.sans_boss.startBoss) == "function" then
      pcall(ORBIT.sans_boss.startBoss)
    end
    task.wait(0.6)
    if ORBIT.gaster and type(ORBIT.gaster.startBoss) == "function" then
      pcall(ORBIT.gaster.startBoss)
    end
  end)
end

-- === UI ===
local function buildUI()
  killOld()
  local pg = uiParent()
  if not pg then return end

  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitAdminPanel"
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.DisplayOrder = 66
  sg.Parent = pg

  -- фон — обычный Frame (не кнопка)
  local bg = Instance.new("Frame")
  bg.Size = UDim2.fromScale(1, 1)
  bg.BackgroundColor3 = C3(0, 0, 0)
  bg.BackgroundTransparency = 0.45
  bg.BorderSizePixel = 0
  bg.Active = false
  bg.ZIndex = 1
  bg.Parent = sg

  local card = Instance.new("Frame")
  card.AnchorPoint = Vector2.new(0.5, 0.5)
  card.Position = UDim2.fromScale(0.5, 0.5)
  card.Size = UDim2.fromOffset(340, 220)
  card.BackgroundColor3 = C3(22, 16, 38)
  card.BorderSizePixel = 0
  card.ZIndex = 2
  card.Parent = sg
  Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
  local st = Instance.new("UIStroke", card)
  st.Color = C3(180, 140, 255); st.Thickness = 2; st.Transparency = 0.2

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -60, 0, 32)
  title.Position = UDim2.fromOffset(16, 12)
  title.BackgroundTransparency = 1
  title.Text = "🔐 АДМИН-ПАНЕЛЬ"
  title.TextColor3 = C3(240, 230, 255)
  title.Font = Enum.Font.GothamBold
  title.TextSize = 20
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.ZIndex = 3
  title.Parent = card

  local close = Instance.new("TextButton")
  close.Size = UDim2.fromOffset(32, 32)
  close.Position = UDim2.new(1, -44, 0, 8)
  close.BackgroundColor3 = C3(80, 30, 40)
  close.TextColor3 = C3(255, 160, 180)
  close.Font = Enum.Font.GothamBold
  close.TextSize = 16
  close.Text = "✖"
  close.AutoButtonColor = false
  close.ZIndex = 3
  close.Parent = card
  Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

  local hint = Instance.new("TextLabel")
  hint.Size = UDim2.new(1, -32, 0, 18)
  hint.Position = UDim2.fromOffset(16, 48)
  hint.BackgroundTransparency = 1
  hint.Text = "Введи код. Верный — всё, неверный — пробуй сам."
  hint.TextColor3 = C3(180, 180, 210)
  hint.Font = Enum.Font.Gotham
  hint.TextSize = 11
  hint.TextXAlignment = Enum.TextXAlignment.Left
  hint.ZIndex = 3
  hint.Parent = card

  local box = Instance.new("TextBox")
  box.Size = UDim2.new(1, -32, 0, 44)
  box.Position = UDim2.fromOffset(16, 78)
  box.BackgroundColor3 = C3(15, 12, 24)
  box.TextColor3 = C3(240, 235, 255)
  box.PlaceholderText = "ADMIN CODE"
  box.PlaceholderColor3 = C3(140, 130, 175)
  box.Font = Enum.Font.Code
  box.TextSize = 16
  box.Text = ""
  box.ClearTextOnFocus = false
  box.TextXAlignment = Enum.TextXAlignment.Center
  box.ZIndex = 3
  box.Parent = card
  Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
  local bs = Instance.new("UIStroke", box)
  bs.Color = C3(120, 100, 200); bs.Thickness = 1.5; bs.Transparency = 0.3

  local status = Instance.new("TextLabel")
  status.Size = UDim2.new(1, -32, 0, 16)
  status.Position = UDim2.fromOffset(16, 128)
  status.BackgroundTransparency = 1
  status.Text = ""
  status.TextColor3 = C3(255, 180, 180)
  status.Font = Enum.Font.Gotham
  status.TextSize = 11
  status.TextXAlignment = Enum.TextXAlignment.Left
  status.ZIndex = 3
  status.Parent = card

  local okBtn = Instance.new("TextButton")
  okBtn.Size = UDim2.new(1, -32, 0, 44)
  okBtn.Position = UDim2.fromOffset(16, 156)
  okBtn.BackgroundColor3 = C3(60, 130, 80)
  okBtn.TextColor3 = C3(220, 255, 220)
  okBtn.Font = Enum.Font.GothamBold
  okBtn.TextSize = 15
  okBtn.Text = "ПОДТВЕРДИТЬ"
  okBtn.AutoButtonColor = false
  okBtn.ZIndex = 3
  okBtn.Parent = card
  Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 10)

  local function destroy()
    pcall(function() sg:Destroy() end)
  end

  local busy = false
  local function trySubmit()
    if busy then return end
    busy = true
    local code = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""):upper()
    local expected = ADMIN_CODE:upper()
    if code == expected then
      status.Text = "✅ Код верный — выдаю всё..."
      status.TextColor3 = C3(160, 255, 180)
      okBtn.BackgroundColor3 = C3(60, 150, 80)
      okBtn.Text = "ВЫДАНО"
      task.wait(0.5)
      grantAll()
      if ORBIT.notify then ORBIT.notify("🔓 Админ-режим: всё разблокировано", C3(180, 255, 180), 4) end
      destroy()
    else
      status.Text = "❌ Неверный код. Пробуй сам."
      status.TextColor3 = C3(255, 120, 120)
      box.Text = ""
      okBtn.BackgroundColor3 = C3(130, 40, 40)
      okBtn.Text = "ПРОБУЙ САМ"
      if ORBIT.notify then ORBIT.notify("🔒 Неверный код. Пробуй сам.", C3(255, 150, 150), 4) end
      task.wait(1.2)
      destroy()
      spawnBothBosses()
    end
  end

  okBtn.MouseButton1Down:Connect(trySubmit)
  okBtn.Activated:Connect(trySubmit)
  box.FocusLost:Connect(function(enterPressed)
    if enterPressed then trySubmit() end
  end)
  close.Activated:Connect(destroy)

  local scale = Instance.new("UIScale", card)
  scale.Scale = 0.85
  TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
  task.defer(function() pcall(function() box:CaptureFocus() end) end)
end

buildUI()
return true
