-- ORBIT v25.4 | orbit_weapons_menu.lua
-- Меню выбора оружия. Мультивыбор + экипировка на руки.
-- v25.4: самодостаточные билдеры (без SHAPE_PRESETS), двойной обработчик кнопок,
--        ORBIT.weapons.open() как функция, страховки destroy.
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] weapons_menu: нет ORBIT"); return false end
if ORBIT.weapons and ORBIT.weapons.destroy then pcall(ORBIT.weapons.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local PT_BLOCK, PT_BALL = Enum.PartType.Block, Enum.PartType.Ball
local PT_CYL = Enum.PartType.Cylinder
local MAT = Enum.Material

local alive = true
local conns = {}

local function connect(sig, fn)
  local c = sig:Connect(fn); conns[#conns + 1] = c; return c
end
local function ping(n, v, p) if ORBIT.Sfx and ORBIT.Sfx.play then pcall(ORBIT.Sfx.play, n, v or 1, p or 1) end end
local function getChar()
  local c = LP.Character
  if not c then return nil end
  local h = c:FindFirstChildOfClass("Humanoid")
  local r = c:FindFirstChild("HumanoidRootPart")
  if not h or not r or h.Health <= 0 then return nil end
  return c, h, r
end

local W = {
  isOpen = false,
  sg = nil,
  frame = nil,
  folder = nil,
  equipped = {},
  selected = {},
  btnGui = nil,
}

local function fold()
  if W.folder and W.folder.Parent then return W.folder end
  W.folder = Instance.new("Folder")
  W.folder.Name = "OrbitWeapons_" .. LP.UserId
  W.folder.Parent = WS
  return W.folder
end

local function mkp(parent, name, size, cf, col, noRecolor, shape, mat, trans)
  local p
  if ORBIT.newPart then
    p = ORBIT.newPart(parent, name, size, cf, col, noRecolor)
  end
  if not p then
    p = Instance.new("Part")
    p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true
    p.CanCollide = false; p.CastShadow = false; p.Color = col; p.Parent = parent
    if noRecolor then p:SetAttribute("NoRecolor", true) end
  end
  if shape then p.Shape = shape end
  if mat then p.Material = mat end
  if trans then p.Transparency = trans end
  p.Anchored = true
  p.CanCollide = false
  p.CanQuery = false
  p.CanTouch = false
  return p
end

-- ===== Строители оружия =====
local function buildSansKnife()
  local m = Instance.new("Model")
  m.Name = "Wpn_sans_knife"
  local root = mkp(m, "Root", V3(0.1,0.1,0.1), CF(), C3(0,0,0), true, PT_BLOCK, MAT.SmoothPlastic, 1)
  m.PrimaryPart = root
  local blade = mkp(m, "Blade", V3(0.35, 0.35, 3.2), CF(), C3(240,240,225), true, PT_BLOCK, MAT.SmoothPlastic)
  blade.CFrame = root.CFrame * CF(0, 0, -1.6)
  for _, zoff in ipairs({1.5, -1.5}) do
    for _, sx in ipairs({-1, 1}) do
      local lobe = mkp(m, "Lobe", V3(0.38,0.38,0.38), CF(), C3(240,240,225), true, PT_BALL, MAT.SmoothPlastic)
      lobe.CFrame = blade.CFrame * CF(sx * 0.16, 0, zoff)
    end
  end
  local hilt = mkp(m, "Hilt", V3(0.22, 0.22, 0.5), CF(), C3(60,55,70), true, PT_BLOCK, MAT.SmoothPlastic)
  hilt.CFrame = root.CFrame * CF(0, 0, 0.3)
  return m
end

local function buildSword()
  local m = Instance.new("Model")
  m.Name = "Wpn_sword"
  local root = mkp(m, "Root", V3(0.1,0.1,0.1), CF(), C3(0,0,0), true, PT_BLOCK, MAT.SmoothPlastic, 1)
  m.PrimaryPart = root
  local blade = mkp(m, "Blade", V3(0.18, 0.85, 3.4), CF(), C3(220,230,245), true, PT_BLOCK, MAT.Metal)
  blade.CFrame = root.CFrame * CF(0, 0, -1.9)
  local edge = mkp(m, "Edge", V3(0.08, 0.88, 3.4), CF(), C3(255,255,255), true, PT_BLOCK, MAT.Neon, 0.3)
  edge.CFrame = blade.CFrame * CF(0.14, 0, 0)
  local guard = mkp(m, "Guard", V3(1.4, 0.22, 0.22), CF(), C3(180,160,80), true, PT_BLOCK, MAT.Metal)
  guard.CFrame = root.CFrame * CF(0, 0, -0.15)
  local hilt = mkp(m, "Hilt", V3(0.2, 0.2, 0.7), CF(), C3(80,50,30), true, PT_BLOCK, MAT.Wood)
  hilt.CFrame = root.CFrame * CF(0, 0, 0.35)
  local pommel = mkp(m, "Pommel", V3(0.3,0.3,0.3), CF(), C3(200,180,90), true, PT_BALL, MAT.Metal)
  pommel.CFrame = root.CFrame * CF(0, 0, 0.75)
  return m
end

local function buildShield()
  local m = Instance.new("Model")
  m.Name = "Wpn_shield"
  local root = mkp(m, "Root", V3(0.1,0.1,0.1), CF(), C3(0,0,0), true, PT_BLOCK, MAT.SmoothPlastic, 1)
  m.PrimaryPart = root
  local disk = mkp(m, "Disk", V3(0.2, 2.4, 2.4), CF(), C3(150,170,200), true, PT_CYL, MAT.Metal)
  disk.CFrame = root.CFrame * CFrame.Angles(0, math.rad(90), 0)
  local v = mkp(m, "CrossV", V3(0.15, 1.9, 0.25), CF(), C3(220,220,240), true, PT_BLOCK, MAT.Metal)
  v.CFrame = root.CFrame * CF(0, 0, -0.15)
  local h = mkp(m, "CrossH", V3(1.9, 0.25, 0.15), CF(), C3(220,220,240), true, PT_BLOCK, MAT.Metal)
  h.CFrame = root.CFrame * CF(0, 0, -0.15)
  local boss = mkp(m, "Boss", V3(0.5,0.5,0.5), CF(), C3(255,200,100), true, PT_BALL, MAT.Neon)
  boss.CFrame = root.CFrame * CF(0, 0, -0.25)
  return m
end

local function buildGasterBlaster()
  local G = ORBIT.gaster
  if not G or not G.create then return nil end
  local ok, data = pcall(G.create, 0.55, "Wpn_gaster_blaster")
  if not ok or not data or not data.model then return nil end
  for _, d in ipairs(data.model:GetDescendants()) do
    if d:IsA("BasePart") then
      d:SetAttribute("NoRecolor", true)
      d.CanQuery = false
      d.CanTouch = false
    end
  end
  return data.model
end

-- ===== Каталог оружия =====
local WEAPONS = {
  {
    id = "sans_knife",
    name = "🦴 Костяной клинок",
    desc = "Лезвие из кости с наростами",
    source = "Санс",
    check = function()
      return ORBIT.sansKnifeUnlocked == true
          or ORBIT.sansUnlocked == true
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["sans_knife"])
    end,
    build = buildSansKnife,
  },
  {
    id = "gaster_blaster",
    name = "⚔ Гастер-бластер",
    desc = "Череп-бластер в руке",
    source = "Гастер",
    check = function()
      return ORBIT.gasterWeaponUnlocked == true
          or ORBIT.gasterUnlocked == true
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_weapon"])
    end,
    build = buildGasterBlaster,
  },
  {
    id = "sword",
    name = "🗡 Меч",
    desc = "Классический меч со светящимся лезвием",
    source = "Базовое",
    check = function() return true end,
    build = buildSword,
  },
  {
    id = "shield",
    name = "🛡 Щит",
    desc = "Круглый щит с крестом",
    source = "Базовое",
    check = function() return true end,
    build = buildShield,
  },
}

-- ===== Руки =====
local function findHand(char, side)
  local hum = char:FindFirstChildOfClass("Humanoid")
  local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
  if isR15 then
    if side == "L" then return char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm") end
    return char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm")
  end
  if side == "L" then return char:FindFirstChild("Left Arm") end
  return char:FindFirstChild("Right Arm")
end
local function handCF(hand)
  local hum = hand.Parent and hand.Parent:FindFirstChildOfClass("Humanoid")
  local isR15 = hum and hum.RigType == Enum.HumanoidRigType.R15
  if isR15 then
    return hand.CFrame * CF(0, 0, -1.2) * CFrame.Angles(math.rad(-15), 0, 0)
  end
  return hand.CFrame * CF(0, -1, -1.2) * CFrame.Angles(math.rad(-15), 0, 0)
end

local function updatePositions()
  local char = LP.Character
  if not char then return end
  for id, model in pairs(W.equipped) do
    if not model.Parent then
      W.equipped[id] = nil
    else
      local slot = model:GetAttribute("OrbitSlot") or "R"
      local hand = findHand(char, slot)
      if hand then pcall(function() model:PivotTo(handCF(hand)) end) end
    end
  end
end

-- ===== Экипировка =====
local function unequipOne(id)
  local m = W.equipped[id]
  if m then pcall(function() m:Destroy() end); W.equipped[id] = nil end
end

function W.unequipAll()
  for id in pairs(W.equipped) do unequipOne(id) end
  if ORBIT.notify then ORBIT.notify("🗡 Оружие снято", C3(200,200,240), 2) end
end

function W.applySelection()
  if not getChar() then
    if ORBIT.notify then ORBIT.notify("❌ Нужно заспавниться", C3(255,150,150), 2) end
    return false
  end
  for id in pairs(W.equipped) do
    if not W.selected[id] then unequipOne(id) end
  end
  local slots = { "R", "L" }
  local slotIdx = 0
  local count = 0
  for _, w in ipairs(WEAPONS) do
    if W.selected[w.id] then
      count = count + 1
      if not W.equipped[w.id] then
        local ok, model = pcall(w.build)
        if ok and model then
          model.Parent = fold()
          W.equipped[w.id] = model
          slotIdx = slotIdx + 1
          model:SetAttribute("OrbitSlot", slots[((slotIdx - 1) % #slots) + 1])
        else
          warn("[Orbit Weapons] сборка упала: " .. w.id .. " → " .. tostring(model))
        end
      end
    end
  end
  ping("buy", 1, 1.2)
  if ORBIT.notify then ORBIT.notify("✅ Экипировано: " .. count .. " шт.", C3(180,255,180), 3) end
  return true
end

-- ===== UI =====
local function destroyUI()
  if W.sg then pcall(function() W.sg:Destroy() end) end
  W.sg, W.frame = nil, nil
  W.isOpen = false
  pcall(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
      local old = pg:FindFirstChild("_OrbitWeaponsMenu")
      if old then old:Destroy() end
    end
  end)
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

local function refreshUI()
  if not W.frame then return end
  local sc = W.frame:FindFirstChild("Scroll")
  if not sc then return end
  for _, card in ipairs(sc:GetChildren()) do
    if card:IsA("Frame") and card:GetAttribute("WeaponId") then
      local id = card:GetAttribute("WeaponId")
      local unlocked = card:GetAttribute("Unlocked")
      local chk = card:FindFirstChild("Check")
      local btn = card:FindFirstChild("Toggle")
      local selected = W.selected[id] and true or false
      if chk then
        if not unlocked then chk.Text = "🔒"; chk.TextColor3 = C3(120,120,140)
        elseif selected then chk.Text = "✅"; chk.TextColor3 = C3(120,255,160)
        else chk.Text = "▫"; chk.TextColor3 = C3(180,180,200) end
      end
      if btn then
        if not unlocked then
          btn.BackgroundColor3 = C3(50,40,50); btn.TextColor3 = C3(140,140,160); btn.Text = "ЗАКРЫТО"
        elseif selected then
          btn.BackgroundColor3 = C3(50,100,60); btn.TextColor3 = C3(180,255,200); btn.Text = "СНЯТЬ"
        else
          btn.BackgroundColor3 = C3(60,50,90); btn.TextColor3 = C3(220,210,255); btn.Text = "ВЫБРАТЬ"
        end
      end
    end
  end
  local counter = W.frame:FindFirstChild("Counter")
  if counter then
    local n = 0
    for _, v in pairs(W.selected) do if v then n = n + 1 end end
    counter.Text = "Выбрано: " .. n
  end
end

local function buildUI()
  destroyUI()
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end

  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitWeaponsMenu"; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 62; sg.Parent = pg
  W.sg = sg

  local bg = Instance.new("Frame")
  bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C3(0,0,0)
  bg.BackgroundTransparency = 0.55; bg.BorderSizePixel = 0
  bg.ZIndex = 1; bg.Active = false; bg.Parent = sg

  local cm = WS.CurrentCamera
  local vp = cm and cm.ViewportSize or Vector2.new(800, 600)
  local w = math.min(520, vp.X - 24)
  local h = math.min(560, vp.Y - 40)
  local frame = Instance.new("Frame")
  frame.Name = "Root"; frame.Size = UDim2.fromOffset(w, h)
  frame.AnchorPoint = Vector2.new(0.5, 0.5)
  frame.Position = UDim2.fromScale(0.5, 0.5)
  frame.BackgroundColor3 = C3(18,14,30); frame.BorderSizePixel = 0
  frame.ZIndex = 2; frame.Parent = sg
  W.frame = frame
  Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
  local st = Instance.new("UIStroke", frame); st.Color = C3(180,140,255); st.Thickness = 2; st.Transparency = 0.15

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -60, 0, 32); title.Position = UDim2.fromOffset(16, 10)
  title.BackgroundTransparency = 1; title.Text = "🗡 АРСЕНАЛ ОРУЖИЯ"
  title.TextColor3 = C3(240,230,255); title.Font = Enum.Font.GothamBold
  title.TextSize = 20; title.TextXAlignment = Enum.TextXAlignment.Left
  title.ZIndex = 3; title.Parent = frame

  local close = Instance.new("TextButton")
  close.Size = UDim2.fromOffset(32, 32); close.Position = UDim2.new(1, -44, 0, 6)
  close.BackgroundColor3 = C3(80,30,40); close.TextColor3 = C3(255,160,180)
  close.Font = Enum.Font.GothamBold; close.TextSize = 16; close.Text = "✖"
  close.AutoButtonColor = false; close.ZIndex = 3; close.Parent = frame
  Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
  onClick(close, destroyUI)

  local hint = Instance.new("TextLabel")
  hint.Size = UDim2.new(1, -32, 0, 20); hint.Position = UDim2.fromOffset(16, 46)
  hint.BackgroundTransparency = 1
  hint.Text = "Отметь галочками нужные — и нажми ЭКИПИРОВАТЬ"
  hint.TextColor3 = C3(170,170,200); hint.Font = Enum.Font.Gotham
  hint.TextSize = 11; hint.TextXAlignment = Enum.TextXAlignment.Left
  hint.ZIndex = 3; hint.Parent = frame

  local counter = Instance.new("TextLabel")
  counter.Name = "Counter"; counter.Size = UDim2.new(1, -32, 0, 20)
  counter.Position = UDim2.fromOffset(16, 66); counter.BackgroundTransparency = 1
  counter.Text = "Выбрано: 0"; counter.TextColor3 = C3(255,220,140)
  counter.Font = Enum.Font.GothamBold; counter.TextSize = 12
  counter.TextXAlignment = Enum.TextXAlignment.Left
  counter.ZIndex = 3; counter.Parent = frame

  local sc = Instance.new("ScrollingFrame")
  sc.Name = "Scroll"; sc.Position = UDim2.fromOffset(16, 92)
  sc.Size = UDim2.new(1, -32, 1, -170); sc.BackgroundTransparency = 1
  sc.BorderSizePixel = 0; sc.ScrollBarThickness = 4
  sc.ScrollBarImageColor3 = C3(150,120,255)
  sc.CanvasSize = UDim2.new(0,0,0,0); sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
  sc.ZIndex = 3; sc.Parent = frame
  local layout = Instance.new("UIListLayout", sc)
  layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder
  local pad = Instance.new("UIPadding", sc)
  pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 8)
  pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4)

  for i, wdef in ipairs(WEAPONS) do
    local unlocked = false
    pcall(function() unlocked = wdef.check() end)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 70)
    card.BackgroundColor3 = unlocked and C3(32,30,50) or C3(24,22,34)
    card.BorderSizePixel = 0; card.LayoutOrder = i; card.ZIndex = 4; card.Parent = sc
    card:SetAttribute("WeaponId", wdef.id)
    card:SetAttribute("Unlocked", unlocked)
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke", card)
    cs.Color = unlocked and C3(120,180,255) or C3(70,60,90)
    cs.Thickness = 1.5; cs.Transparency = unlocked and 0.3 or 0.5

    local chk = Instance.new("TextButton")
    chk.Name = "Check"; chk.Size = UDim2.fromOffset(36, 36)
    chk.Position = UDim2.fromOffset(10, 17)
    chk.BackgroundColor3 = C3(45,40,65); chk.BorderSizePixel = 0
    chk.Text = unlocked and "▫" or "🔒"
    chk.TextColor3 = unlocked and C3(180,180,200) or C3(120,120,140)
    chk.Font = Enum.Font.GothamBold; chk.TextSize = 18
    chk.AutoButtonColor = false; chk.ZIndex = 5; chk.Parent = card
    Instance.new("UICorner", chk).CornerRadius = UDim.new(0, 8)

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -170, 0, 22); name.Position = UDim2.fromOffset(56, 8)
    name.BackgroundTransparency = 1; name.Text = wdef.name
    name.TextColor3 = unlocked and C3(240,235,255) or C3(150,140,170)
    name.Font = Enum.Font.GothamBold; name.TextSize = 14
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.ZIndex = 5; name.Parent = card

    local src = Instance.new("TextLabel")
    src.Size = UDim2.new(0, 100, 0, 16); src.Position = UDim2.new(1, -110, 0, 10)
    src.BackgroundTransparency = 1; src.Text = "🎖 " .. wdef.source
    src.TextColor3 = unlocked and C3(200,220,255) or C3(120,120,140)
    src.Font = Enum.Font.Gotham; src.TextSize = 10
    src.TextXAlignment = Enum.TextXAlignment.Right
    src.ZIndex = 5; src.Parent = card

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -56, 0, 22); desc.Position = UDim2.fromOffset(56, 32)
    desc.BackgroundTransparency = 1
    desc.Text = unlocked and wdef.desc or ("🔒 Победи " .. wdef.source .. " — откроется")
    desc.TextColor3 = unlocked and C3(180,180,210) or C3(255,200,120)
    desc.Font = Enum.Font.Gotham; desc.TextSize = 11; desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.ZIndex = 5; desc.Parent = card

    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"; toggle.Size = UDim2.fromOffset(90, 30)
    toggle.Position = UDim2.new(1, -100, 1, -38)
    toggle.BackgroundColor3 = unlocked and C3(60,50,90) or C3(50,40,50)
    toggle.TextColor3 = unlocked and C3(220,210,255) or C3(140,140,160)
    toggle.Font = Enum.Font.GothamBold; toggle.TextSize = 11
    toggle.Text = unlocked and "ВЫБРАТЬ" or "ЗАКРЫТО"
    toggle.AutoButtonColor = false; toggle.ZIndex = 5; toggle.Parent = card
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)

    if unlocked then
      local function toggleSel()
        if W.selected[wdef.id] then W.selected[wdef.id] = nil else W.selected[wdef.id] = true end
        refreshUI()
      end
      onClick(toggle, toggleSel)
      onClick(chk, toggleSel)
    else
      onClick(toggle, function()
        if ORBIT.notify then ORBIT.notify("🔒 Победи " .. wdef.source, C3(255,180,120), 3) end
      end)
    end
  end

  local function mkBtn(x, y, w2, text, color, fn)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w2, 38); b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = color; b.TextColor3 = C3(255,255,255)
    b.Font = Enum.Font.GothamBold; b.TextSize = 13; b.Text = text
    b.AutoButtonColor = false; b.ZIndex = 3; b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    onClick(b, fn)
    return b
  end

  local bW = math.floor((w - 44) / 3)
  mkBtn(16, h - 56, bW, "⚔ ЭКИПИРОВАТЬ", C3(60,130,80), function() W.applySelection(); refreshUI() end)
  mkBtn(16 + bW + 8, h - 56, bW, "✖ СНЯТЬ ВСЁ", C3(130,60,60), function() W.unequipAll(); W.selected = {}; refreshUI() end)
  mkBtn(16 + bW*2 + 16, h - 56, bW, "🔒 ЗАКРЫТЬ", C3(70,60,100), destroyUI)

  W.isOpen = true
  refreshUI()
end

function W.openMenu()
  if W.sg and W.sg.Parent then destroyUI(); return false end
  buildUI()
  return true
end

-- v25.4: единая функция open (раньше был boolean → ломало ORBIT.weapons.open())
function W.open()
  return W.openMenu()
end

function W.close()
  destroyUI()
  return true
end

function W.toggle()
  if W.isOpen then return W.close() end
  return W.openMenu()
end

-- ===== Мобильная кнопка =====
local function buildMobileBtn()
  if not UIS.TouchEnabled then return end
  local pg = LP:FindFirstChildOfClass("PlayerGui")
  if not pg then return end
  local old = pg:FindFirstChild("_OrbitWeaponsBtn")
  if old then old:Destroy() end
  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitWeaponsBtn"; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 44; sg.Parent = pg
  W.btnGui = sg
  local b = Instance.new("TextButton")
  b.Name = "WeaponsBtn"; b.AnchorPoint = Vector2.new(1, 1)
  b.Position = UDim2.new(1, -16, 1, -440)
  b.Size = UDim2.fromOffset(56, 56); b.Text = "🗡"; b.TextSize = 28
  b.Font = Enum.Font.GothamBold; b.TextColor3 = C3(255,255,255)
  b.BackgroundColor3 = C3(80,60,130); b.BackgroundTransparency = 0.1
  b.AutoButtonColor = false; b.ZIndex = 44; b.Parent = sg
  Instance.new("UICorner", b).CornerRadius = UDim.new(0, 28)
  local st = Instance.new("UIStroke", b); st.Color = C3(180,140,255); st.Thickness = 2
  local last = 0
  local function fire()
    local t = tick()
    if t - last < 0.25 then return end
    last = t
    pcall(W.toggle)
  end
  b.MouseButton1Down:Connect(fire)
  b.Activated:Connect(fire)
end
buildMobileBtn()

-- ===== Heartbeat =====
connect(RS.Heartbeat, function()
  if next(W.equipped) ~= nil then pcall(updatePositions) end
end)

-- Возврат оружия после респавна
connect(LP.CharacterAdded, function()
  task.wait(0.6)
  if next(W.selected) ~= nil then pcall(W.applySelection) end
end)

-- ===== API =====
function W.list()
  local out = {}
  for _, w in ipairs(WEAPONS) do
    local unlocked = false
    pcall(function() unlocked = w.check() end)
    out[#out+1] = { id = w.id, name = w.name, desc = w.desc, source = w.source,
      unlocked = unlocked, selected = W.selected[w.id] and true or false }
  end
  return out
end
function W.isUnlocked(id)
  for _, w in ipairs(WEAPONS) do
    if w.id == id then local ok, r = pcall(w.check); return ok and r or false end
  end
  return false
end
function W.isEquipped(id) return W.equipped[id] ~= nil end
function W.equip(id)
  if not W.isUnlocked(id) then return false end
  W.selected[id] = true
  return W.applySelection()
end
function W.unequip(id) W.selected[id] = nil; unequipOne(id); return true end
function W.getEquippedList()
  local out = {}
  for id in pairs(W.equipped) do out[#out+1] = id end
  return out
end

function W.destroy()
  if not alive then return end
  alive = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  conns = {}
  destroyUI()
  W.unequipAll()
  W.selected = {}
  if W.btnGui then pcall(function() W.btnGui:Destroy() end); W.btnGui = nil end
  if W.folder then pcall(function() W.folder:Destroy() end); W.folder = nil end
  pcall(function()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if pg then
      for _, nm in ipairs({"_OrbitWeaponsMenu", "_OrbitWeaponsBtn"}) do
        local g = pg:FindFirstChild(nm)
        if g then g:Destroy() end
      end
    end
  end)
end

ORBIT.weapons = W
ORBIT.loaded.weapons = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(W.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("🗡 Арсенал оружия v25.4 (выбор + мультиэкип)", C3(200, 220, 255), 3)
end

return true
