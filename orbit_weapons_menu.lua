-- ORBIT v25.3 | orbit_weapons_menu.lua
-- Экран выбора оружия. Мультивыбор, экипировка на руки.
-- Оружия открываются после побед над боссами.
-- Открывается: ORBIT.weapons.open() или кнопкой из меню.
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] weapons_menu: нет ORBIT"); return false end
if ORBIT.weapons and ORBIT.weapons.destroy then pcall(ORBIT.weapons.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB

-- Каталог оружия
local WEAPONS = {
  {
    id = "sans_knife",
    name = "🦴 Костяной клинок",
    desc = "Веер из 3 костей на ЛКМ",
    source = "Санс",
    unlockedCheck = function()
      return ORBIT.sansKnifeUnlocked == true or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["sans_knife"])
    end,
    buildShape = "КОСТЬ",
    color = C3(240, 240, 225),
    scale = 0.7,
    handOff = CF(0, -1.2, -1.4),
  },
  {
    id = "gaster_blaster",
    name = "⚔ Гастер-бластер",
    desc = "G — выстрел, H — снять (полный комплект)",
    source = "Гастер",
    unlockedCheck = function()
      return ORBIT.gasterWeaponUnlocked == true or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_weapon"])
    end,
    buildShape = "ГАСТЕР БЛАСТЕР",
    color = C3(240, 240, 245),
    scale = 0.55,
    handOff = CF(0, -1, -1.2),
  },
  {
    id = "sword_basic",
    name = "🗡 Меч",
    desc = "Классический меч с рунами",
    source = "Базовое",
    unlockedCheck = function() return true end,
    buildShape = "МЕЧ",
    color = C3(220, 230, 245),
    scale = 0.6,
    handOff = CF(0, -1.2, -1.0),
  },
  {
    id = "shield_basic",
    name = "🛡 Щит",
    desc = "Круглый щит со крестом",
    source = "Базовое",
    unlockedCheck = function() return true end,
    buildShape = "ЩИТ",
    color = C3(200, 220, 240),
    scale = 0.5,
    handOff = CF(0, -1, -1.0),
  },
}

-- Состояние модуля
local W = {
  sg = nil,
  frame = nil,
  folder = nil,
  equipped = {},       -- { weapon_id = model }
  selected = {},       -- { weapon_id = true } — что выбрано галочками
  btn = nil,           -- мобильная кнопка
  open = false,
}

local function ping(n, v, p)
  if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end
end

local function getChar()
  local c = LP.Character
  if not c then return nil end
  local h = c:FindFirstChildOfClass("Humanoid")
  local r = c:FindFirstChild("HumanoidRootPart")
  if not h or not r or h.Health <= 0 then return nil end
  return c, h, r
end

local function fold()
  if W.folder and W.folder.Parent then return W.folder end
  W.folder = Instance.new("Folder")
  W.folder.Name = "OrbitWeapons_" .. LP.UserId
  W.folder.Parent = WS
  return W.folder
end

-- Собрать список доступных оружий
local function getAvailableWeapons()
  local out = {}
  for _, w in ipairs(WEAPONS) do
    local ok, unlocked = pcall(w.unlockedCheck)
    if not ok then unlocked = false end
    out[#out + 1] = {
      id = w.id, name = w.name, desc = w.desc, source = w.source,
      unlocked = unlocked,
    }
  end
  return out
end

-- ============================================================
--       ЭКИПИРОВКА
-- ============================================================
local function findPreset(name)
  local presets = ORBIT.SHAPE_PRESETS
  if type(presets) ~= "table" then return nil end
  for _, p in ipairs(presets) do
    if p.name == name then return p end
  end
  return nil
end

local function findHand(char, side)
  local hum = char:FindFirstChildOfClass("Humanoid")
  local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
  if isR15 then
    if side == "L" then
      return char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm")
    else
      return char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm")
    end
  else
    if side == "L" then return char:FindFirstChild("Left Arm") end
    return char:FindFirstChild("Right Arm")
  end
end

local function handCF(hand, side)
  local hum = hand.Parent and hand.Parent:FindFirstChildOfClass("Humanoid")
  local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
  if isR15 then
    return hand.CFrame * CF(0, 0, -1.2)
  end
  return hand.CFrame * CF(0, -1, -1.2)
end

-- Создать одно оружие (модель)
local function buildWeaponModel(weaponDef)
  local preset = findPreset(weaponDef.buildShape)
  if not preset or type(preset.create) ~= "function" then
    warn("[Orbit Weapons] пресет не найден: " .. weaponDef.buildShape)
    return nil
  end
  local ok, data = pcall(preset.create, weaponDef.scale or 1, "OrbitWeapon_" .. weaponDef.id)
  if not ok or not data or not data.model then
    warn("[Orbit Weapons] create упал: " .. tostring(data))
    return nil
  end
  data.model.Parent = fold()
  -- пометить как NoRecolor
  for _, d in ipairs(data.model:GetDescendants()) do
    if d:IsA("BasePart") then
      d:SetAttribute("NoRecolor", true)
      d.CanQuery = false
      d.CanTouch = false
    end
  end
  return data.model
end

-- Снять одно оружие
local function unequipOne(id)
  local m = W.equipped[id]
  if m then
    pcall(function() m:Destroy() end)
    W.equipped[id] = nil
  end
end

-- Снять всё
function W.unequipAll()
  for id, _ in pairs(W.equipped) do
    unequipOne(id)
  end
  if ORBIT.notify then ORBIT.notify("🗡 Оружие снято", C3(200, 200, 240), 2) end
end

-- Экипировать всё, что отмечено галочками
function W.applySelection()
  if not getChar() then
    if ORBIT.notify then ORBIT.notify("❌ Нужно заспавниться", C3(255, 150, 150), 2) end
    return false
  end

  -- снять то, что больше не выбрано
  for id, _ in pairs(W.equipped) do
    if not W.selected[id] then unequipOne(id) end
  end

  -- экипировать новое
  local slots = { "R", "L", "R", "L", "R", "L" }  -- чередуем руки
  local slotIdx = 0
  local count = 0
  for _, w in ipairs(WEAPONS) do
    if W.selected[w.id] then
      count = count + 1
      if not W.equipped[w.id] then
        local model = buildWeaponModel(w)
        if model then
          W.equipped[w.id] = model
          slotIdx = slotIdx + 1
          local slot = slots[((slotIdx - 1) % #slots) + 1]
          model:SetAttribute("OrbitSlot", slot)
        end
      end
    end
  end

  ping("buy", 1, 1.2)
  if ORBIT.notify then
    ORBIT.notify("✅ Экипировано: " .. count .. " шт.", C3(180, 255, 180), 3)
  end
  return true
end

-- Обновление позиций оружия каждый кадр (привязка к рукам)
local function updateEquippedPositions()
  local char = LP.Character
  if not char then return end
  for id, model in pairs(W.equipped) do
    if not model.Parent then
      W.equipped[id] = nil
    else
      local slot = model:GetAttribute("OrbitSlot") or "R"
      local hand = findHand(char, slot)
      if hand then
        pcall(function()
          model:PivotTo(handCF(hand, slot))
        end)
      end
    end
  end
end

-- ============================================================
--       UI
-- ============================================================
local function destroyUI()
  if W.sg then pcall(function() W.sg:Destroy() end) end
  W.sg, W.frame = nil, nil
  W.open = false
  -- страховка по имени
  pcall(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
      local old = pg:FindFirstChild("_OrbitWeaponsMenu")
      if old then old:Destroy() end
    end
  end)
end

local function refreshUI()
  if not W.frame then return end
  local sc = W.frame:FindFirstChild("Scroll")
  if not sc then return end
  -- перебираем карточки, обновляем галочки и статус
  for _, card in ipairs(sc:GetChildren()) do
    if card:IsA("Frame") and card:GetAttribute("WeaponId") then
      local id = card:GetAttribute("WeaponId")
      local chk = card:FindFirstChild("Check")
      local btn = card:FindFirstChild("Toggle")
      local unlocked = card:GetAttribute("Unlocked")
      if chk then
        if not unlocked then
          chk.Text = "🔒"
          chk.TextColor3 = C3(120, 120, 140)
        elseif W.selected[id] then
          chk.Text = "✅"
          chk.TextColor3 = C3(120, 255, 160)
        else
          chk.Text = "▫"
          chk.TextColor3 = C3(180, 180, 200)
        end
      end
      if btn then
        if not unlocked then
          btn.BackgroundColor3 = C3(50, 40, 50)
          btn.TextColor3 = C3(140, 140, 160)
        elseif W.selected[id] then
          btn.BackgroundColor3 = C3(50, 100, 60)
          btn.TextColor3 = C3(180, 255, 200)
        else
          btn.BackgroundColor3 = C3(60, 50, 90)
          btn.TextColor3 = C3(220, 210, 255)
        end
      end
    end
  end
  -- счётчик
  local counter = W.frame:FindFirstChild("Counter")
  if counter then
    local n = 0
    for _, v in pairs(W.selected) do if v then n = n + 1 end end
    counter.Text = "Выбрано: " .. n
  end
end

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

local function buildUI()
  destroyUI()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end

  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitWeaponsMenu"
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.DisplayOrder = 62
  sg.Parent = pg
  W.sg = sg

  -- фон неактивный, не блокирует тапы
  local bg = Instance.new("Frame")
  bg.Size = UDim2.fromScale(1, 1)
  bg.BackgroundColor3 = C3(0, 0, 0)
  bg.BackgroundTransparency = 0.55
  bg.BorderSizePixel = 0
  bg.ZIndex = 1
  bg.Active = false
  bg.Parent = sg

  local cm = WS.CurrentCamera
  local vp = cm and cm.ViewportSize or Vector2.new(800, 600)
  local w = math.min(520, vp.X - 24)
  local h = math.min(560, vp.Y - 40)
  local frame = Instance.new("Frame")
  frame.Name = "Root"
  frame.Size = UDim2.fromOffset(w, h)
  frame.AnchorPoint = Vector2.new(0.5, 0.5)
  frame.Position = UDim2.fromScale(0.5, 0.5)
  frame.BackgroundColor3 = C3(18, 14, 30)
  frame.BorderSizePixel = 0
  frame.ZIndex = 2
  frame.Parent = sg
  W.frame = frame
  Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
  local st = Instance.new("UIStroke", frame)
  st.Color = C3(180, 140, 255); st.Thickness = 2; st.Transparency = 0.15

  -- заголовок
  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -60, 0, 32)
  title.Position = UDim2.fromOffset(16, 10)
  title.BackgroundTransparency = 1
  title.Text = "🗡 АРСЕНАЛ ОРУЖИЯ"
  title.TextColor3 = C3(240, 230, 255)
  title.Font = Enum.Font.GothamBold
  title.TextSize = 20
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.ZIndex = 3
  title.Parent = frame

  -- закрыть
  local close = Instance.new("TextButton")
  close.Size = UDim2.fromOffset(32, 32)
  close.Position = UDim2.new(1, -44, 0, 6)
  close.BackgroundColor3 = C3(80, 30, 40)
  close.TextColor3 = C3(255, 160, 180)
  close.Font = Enum.Font.GothamBold
  close.TextSize = 16
  close.Text = "✖"
  close.AutoButtonColor = false
  close.ZIndex = 3
  close.Parent = frame
  Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
  onClick(close, destroyUI)

  -- подсказка
  local hint = Instance.new("TextLabel")
  hint.Size = UDim2.new(1, -32, 0, 20)
  hint.Position = UDim2.fromOffset(16, 46)
  hint.BackgroundTransparency = 1
  hint.Text = "Отметь галочками нужные оружия и нажми ЭКИПИРОВАТЬ"
  hint.TextColor3 = C3(170, 170, 200)
  hint.Font = Enum.Font.Gotham
  hint.TextSize = 11
  hint.TextXAlignment = Enum.TextXAlignment.Left
  hint.ZIndex = 3
  hint.Parent = frame

  -- счётчик выбранных
  local counter = Instance.new("TextLabel")
  counter.Name = "Counter"
  counter.Size = UDim2.new(1, -32, 0, 20)
  counter.Position = UDim2.fromOffset(16, 66)
  counter.BackgroundTransparency = 1
  counter.Text = "Выбрано: 0"
  counter.TextColor3 = C3(255, 220, 140)
  counter.Font = Enum.Font.GothamBold
  counter.TextSize = 12
  counter.TextXAlignment = Enum.TextXAlignment.Left
  counter.ZIndex = 3
  counter.Parent = frame

  -- скролл со списком
  local sc = Instance.new("ScrollingFrame")
  sc.Name = "Scroll"
  sc.Position = UDim2.fromOffset(16, 92)
  sc.Size = UDim2.new(1, -32, 1, -170)
  sc.BackgroundTransparency = 1
  sc.BorderSizePixel = 0
  sc.ScrollBarThickness = 4
  sc.ScrollBarImageColor3 = C3(150, 120, 255)
  sc.CanvasSize = UDim2.new(0, 0, 0, 0)
  sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
  sc.ZIndex = 3
  sc.Parent = frame

  local layout = Instance.new("UIListLayout", sc)
  layout.Padding = UDim.new(0, 8)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  local pad = Instance.new("UIPadding", sc)
  pad.PaddingTop = UDim.new(0, 4)
  pad.PaddingBottom = UDim.new(0, 8)
  pad.PaddingLeft = UDim.new(0, 4)
  pad.PaddingRight = UDim.new(0, 4)

  -- карточки оружия
  for i, wdef in ipairs(WEAPONS) do
    local unlocked = false
    pcall(function() unlocked = wdef.unlockedCheck() end)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 70)
    card.BackgroundColor3 = unlocked and C3(32, 30, 50) or C3(24, 22, 34)
    card.BorderSizePixel = 0
    card.LayoutOrder = i
    card.ZIndex = 4
    card.Parent = sc
    card:SetAttribute("WeaponId", wdef.id)
    card:SetAttribute("Unlocked", unlocked)
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local cs = Instance.new("UIStroke", card)
    cs.Color = unlocked and C3(120, 180, 255) or C3(70, 60, 90)
    cs.Thickness = 1.5
    cs.Transparency = unlocked and 0.3 or 0.5

    -- галочка
    local chk = Instance.new("TextLabel")
    chk.Name = "Check"
    chk.Size = UDim2.fromOffset(36, 36)
    chk.Position = UDim2.fromOffset(10, 17)
    chk.BackgroundColor3 = C3(45, 40, 65)
    chk.BorderSizePixel = 0
    chk.Text = unlocked and "▫" or "🔒"
    chk.TextColor3 = unlocked and C3(180, 180, 200) or C3(120, 120, 140)
    chk.Font = Enum.Font.GothamBold
    chk.TextSize = 18
    chk.ZIndex = 5
    chk.Parent = card
    Instance.new("UICorner", chk).CornerRadius = UDim.new(0, 8)

    -- название
    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -170, 0, 22)
    name.Position = UDim2.fromOffset(56, 8)
    name.BackgroundTransparency = 1
    name.Text = wdef.name
    name.TextColor3 = unlocked and C3(240, 235, 255) or C3(150, 140, 170)
    name.Font = Enum.Font.GothamBold
    name.TextSize = 14
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 5
    name.Parent = card

    -- источник
    local src = Instance.new("TextLabel")
    src.Size = UDim2.new(0, 100, 0, 16)
    src.Position = UDim2.new(1, -110, 0, 10)
    src.BackgroundTransparency = 1
    src.Text = "🎖 " .. wdef.source
    src.TextColor3 = unlocked and C3(200, 220, 255) or C3(120, 120, 140)
    src.Font = Enum.Font.Gotham
    src.TextSize = 10
    src.TextXAlignment = Enum.TextXAlignment.Right
    src.ZIndex = 5
    src.Parent = card

    -- описание
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -56, 0, 22)
    desc.Position = UDim2.fromOffset(56, 32)
    desc.BackgroundTransparency = 1
    desc.Text = unlocked and wdef.desc or ("🔒 Победи " .. wdef.source .. " — откроется")
    desc.TextColor3 = unlocked and C3(180, 180, 210) or C3(255, 200, 120)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 11
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.ZIndex = 5
    desc.Parent = card

    -- кнопка «выбрать / снять»
    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"
    toggle.Size = UDim2.fromOffset(90, 30)
    toggle.Position = UDim2.new(1, -100, 1, -38)
    toggle.BackgroundColor3 = unlocked and C3(60, 50, 90) or C3(50, 40, 50)
    toggle.TextColor3 = unlocked and C3(220, 210, 255) or C3(140, 140, 160)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 11
    toggle.Text = unlocked and "ВЫБРАТЬ" or "ЗАКРЫТО"
    toggle.AutoButtonColor = false
    toggle.ZIndex = 5
    toggle.Parent = card
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

    if unlocked then
      onClick(toggle, function()
        if W.selected[wdef.id] then
          W.selected[wdef.id] = nil
        else
          W.selected[wdef.id] = true
        end
        refreshUI()
      end)
      onClick(chk, function()
        if W.selected[wdef.id] then
          W.selected[wdef.id] = nil
        else
          W.selected[wdef.id] = true
        end
        refreshUI()
      end)
    else
      onClick(toggle, function()
        if ORBIT.notify then
          ORBIT.notify("🔒 Награда закрыта. Победи " .. wdef.source, C3(255, 180, 120), 3)
        end
      end)
    end
  end

  -- нижние кнопки: ЭКИПИРОВАТЬ / СНЯТЬ / ЗАКРЫТЬ
  local function mkBtn(x, y, w2, text, color, onClickFn)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w2, 38)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = color
    b.TextColor3 = C3(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = text
    b.AutoButtonColor = false
    b.ZIndex = 3
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    onClick(b, onClickFn)
    return b
  end

  local bW = math.floor((w - 44) / 3)
  mkBtn(16,               h - 56, bW, "⚔ ЭКИПИРОВАТЬ", C3(60, 130, 80), function()
    W.applySelection()
    refreshUI()
  end)
  mkBtn(16 + bW + 8,      h - 56, bW, "✖ СНЯТЬ ВСЁ",   C3(130, 60, 60), function()
    W.unequipAll()
    W.selected = {}
    refreshUI()
  end)
  mkBtn(16 + bW*2 + 16,   h - 56, bW, "🔒 ЗАКРЫТЬ",     C3(70, 60, 100), function()
    destroyUI()
  end)

  W.open = true
  refreshUI()
end

function W.openMenu()
  if W.sg and W.sg.Parent then
    destroyUI()
    return false
  end
  buildUI()
  return true
end

function W.close()
  destroyUI()
  return true
  -- ============================================================
--       HEARTBEAT — обновление позиций оружия
-- ============================================================
local conn = RS.Heartbeat:Connect(function(dt)
  if not W.open and next(W.equipped) == nil then return end
  if next(W.equipped) ~= nil then
    pcall(updateEquippedPositions)
  end
end)

-- ============================================================
--       МОБИЛЬНАЯ КНОПКА (открывает меню)
-- ============================================================
local function buildMobileBtn()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old = pg:FindFirstChild("_OrbitWeaponsBtn")
  if old then old:Destroy() end
  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitWeaponsBtn"
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.DisplayOrder = 44
  sg.Parent = pg
  W.btn = sg

  local b = Instance.new("TextButton")
  b.Name = "WeaponsBtn"
  b.AnchorPoint = Vector2.new(1, 1)
  b.Position = UDim2.new(1, -16, 1, -440)
  b.Size = UDim2.fromOffset(56, 56)
  b.Text = "🗡"
  b.TextSize = 28
  b.Font = Enum.Font.GothamBold
  b.TextColor3 = C3(255, 255, 255)
  b.BackgroundColor3 = C3(80, 60, 130)
  b.BackgroundTransparency = 0.1
  b.AutoButtonColor = false
  b.ZIndex = 44
  b.Parent = sg
  Instance.new("UICorner", b).CornerRadius = UDim.new(0, 28)
  local st = Instance.new("UIStroke", b)
  st.Color = C3(180, 140, 255)
  st.Thickness = 2

  onClick(b, function()
    W.openMenu()
  end)
end

if game:GetService("UserInputService").TouchEnabled then
  buildMobileBtn()
end

-- ============================================================
--       API
-- ============================================================
function W.list()
  return getAvailableWeapons()
end

function W.isUnlocked(id)
  for _, w in ipairs(WEAPONS) do
    if w.id == id then
      local ok, r = pcall(w.unlockedCheck)
      return ok and r or false
    end
  end
  return false
end

function W.equip(id)
  if not W.isUnlocked(id) then return false end
  W.selected[id] = true
  return W.applySelection()
end

function W.unequip(id)
  W.selected[id] = nil
  unequipOne(id)
  return true
end

function W.getEquippedList()
  local out = {}
  for id, _ in pairs(W.equipped) do out[#out + 1] = id end
  return out
end

function W.destroy()
  pcall(function() if conn then conn:Disconnect() end end)
  destroyUI()
  W.unequipAll()
  W.selected = {}
  if W.btn then pcall(function() W.btn:Destroy() end); W.btn = nil end
  if W.folder then pcall(function() W.folder:Destroy() end); W.folder = nil end
  -- страховка
  pcall(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
      for _, nm in ipairs({ "_OrbitWeaponsMenu", "_OrbitWeaponsBtn" }) do
        local g = pg:FindFirstChild(nm)
        if g then g:Destroy() end
      end
    end
  end)
end

-- При смерти персонажа — снять оружие (часть пропадёт с телом)
local charAddedConn
pcall(function()
  charAddedConn = LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    W.unequipAll()
    W.selected = {}
    if W.open then
      pcall(W.applySelection)
    end
  end)
end)

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
ORBIT.weapons = W
ORBIT.loaded.weapons = true

local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(W.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("🗡 Арсенал оружия загружен (v25.3)", C3(200, 220, 255), 3)
end

return true
