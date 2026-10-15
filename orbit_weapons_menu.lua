=== orbit_weapons_menu.lua v25.9 ===
-- ORBIT v25.9 | orbit_weapons_menu.lua
-- Арсенал: оружие + все награды + атака + фигурные скины (Санс/Гастер).
-- v25.7: sans_boss_skin и gaster_boss_skin -> полная замена персонажа
--        на фигуру из orbit_p2.lua.
-- v25.7-fix1: фиксы разворота фигуры. Фигуры САНС/ГАСТЕР построены лицом к +Z,
--             HRP смотрит к -Z → разворот на 180°.
-- v25.8: + 4 оружия (коса, молот, топор, посох).
--        + система взмаха W.swings: раньше swingFx твинил PrimaryPart, а
--          updatePositions каждый кадр перезаписывал pivot — взмаха не было видно.
--        + скины-фигуры оживают через ORBIT.figureRig (Rig.update каждый кадр,
--          Rig.detach при снятии скина / респавне / destroy).
--        + UI создаётся через ORBIT.getSafeParent() (запасной вариант — PlayerGui).
-- v25.9: + косметика за награды боссов: «Санс-призрак», «Тёмный плащ»,
--          титулы «Мастер клинков» и «Легенда ОРБИТЫ» (с аурой).
--        + таблица EXCLUSIVE (что нельзя носить вместе), откат при неудачном надевании.
--        + у закрытых карточек текст условия берётся из поля hint.
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] weapons_menu: нет ORBIT"); return false end
if ORBIT.weapons and ORBIT.weapons.destroy then pcall(ORBIT.weapons.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local TS = game:GetService("TweenService")
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
-- v25.8: звук — ORBIT.Sfx.play (как везде в проекте), запасной вариант ORBIT.playSound
local function ping(n, v, p)
  if ORBIT.Sfx and ORBIT.Sfx.play then
    pcall(ORBIT.Sfx.play, n, v or 1, p or 1)
  elseif type(ORBIT.playSound) == "function" then
    pcall(ORBIT.playSound, n, v or 1, p or 1)
  end
end
-- v25.8: родитель для UI — ORBIT.getSafeParent(), запасной вариант PlayerGui
local function uiParent()
  if type(ORBIT.getSafeParent) == "function" then
    local ok, p = pcall(ORBIT.getSafeParent)
    if ok and typeof(p) == "Instance" then return p end
  end
  return LP:FindFirstChildOfClass("PlayerGui")
end
local function getChar()
  local c = LP.Character
  if not c then return nil end
  local h = c:FindFirstChildOfClass("Humanoid")
  local r = c:FindFirstChild("HumanoidRootPart")
  if not h or not r or h.Health <= 0 then return nil end
  return c, h, r
end

local W = {
  isOpen = false, sg = nil, frame = nil, folder = nil,
  equipped = {}, selected = {}, btnGui = nil, attackGui = nil,
  lastAttack = 0, attackCD = 0.6,
  activeFx = {},
  savedColors = {},
  skinModel = nil,
  skinOffset = nil,
  savedCharState = nil,
  savedFaceT = nil,
  swings = {},         -- v25.8: активные взмахи { [id] = { kind, t0, dur } }
  equippedMeta = {},   -- v25.8: { [id] = { bodies, visualSize } }
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
  if ORBIT.newPart then p = ORBIT.newPart(parent, name, size, cf, col, noRecolor) end
  if not p then
    p = Instance.new("Part")
    p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true
    p.CanCollide = false; p.CastShadow = false; p.Color = col; p.Parent = parent
    if noRecolor then p:SetAttribute("NoRecolor", true) end
  end
  if shape then p.Shape = shape end
  if mat then p.Material = mat end
  if trans then p.Transparency = trans end
  p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
  return p
end

-- ===== Билдеры оружия =====
local function buildSansKnife()
  local m = Instance.new("Model"); m.Name = "Wpn_sans_knife"
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
  local m = Instance.new("Model"); m.Name = "Wpn_sword"
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
  local m = Instance.new("Model"); m.Name = "Wpn_shield"
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
      d.CanQuery = false; d.CanTouch = false
    end
  end
  return data.model
end

-- ===== v25.8: НОВЫЕ ОРУЖИЯ =====
-- Модели строятся вокруг начала координат; «вперёд» = -Z (как у меча),
-- Root — невидимый корень в точке хвата. Билдер возвращает: model, bodies, visualSize.
local function newWeaponModel(name)
  local m = Instance.new("Model"); m.Name = name
  local root = mkp(m, "Root", V3(0.1,0.1,0.1), CF(), C3(0,0,0), true, PT_BLOCK, MAT.SmoothPlastic, 1)
  m.PrimaryPart = root
  return m, root
end

-- Сегмент между двумя точками (Z вдоль направления, тонкий по Y) — для изогнутых лезвий
local function seg(m, name, a, b, w, h, col, mat, trans)
  local len = (b - a).Magnitude
  if len < 0.02 then return nil end
  return mkp(m, name, V3(w, h, len * 1.04), CFrame.lookAt((a + b) / 2, b), col, true, PT_BLOCK, mat or MAT.Metal, trans)
end

local function buildScythe()
  local m = newWeaponModel("Wpn_scythe")
  local bodies = {}
  local function P(nm, sz, cf, col, shape, mat, tr)
    local p = mkp(m, nm, sz, cf, col, true, shape, mat, tr)
    bodies[#bodies + 1] = p; return p
  end
  local wood, steel, glow = C3(70, 48, 80), C3(210, 220, 235), C3(190, 120, 255)
  P("Shaft", V3(0.18, 0.18, 4.6), CF(0, 0, -1.0), wood, PT_BLOCK, MAT.Wood)
  for i = 0, 3 do
    P("Wrap", V3(0.23, 0.23, 0.12), CF(0, 0, 0.6 - i * 0.28), C3(35, 25, 45), PT_BLOCK, MAT.Fabric)
  end
  P("Pommel", V3(0.3, 0.3, 0.3), CF(0, 0, 1.35), steel, PT_BALL, MAT.Metal)
  P("Collar", V3(0.32, 0.32, 0.32), CF(0, 0, -3.3), steel, PT_BALL, MAT.Metal)
  P("Rune", V3(0.2, 0.2, 0.2), CF(0, 0.2, -3.3), glow, PT_BALL, MAT.Neon)
  -- изогнутое лезвие: дуга в плоскости XZ, уходит в -X и загибается назад к +Z
  local R, prev = 1.7, V3(0, 0, -3.3)
  for i = 1, 7 do
    local th = math.rad(i * 15)
    local cur = V3(-R * math.sin(th), 0, -3.3 + R * (1 - math.cos(th)))
    local w = 0.5 * (1 - (i - 1) / 8)   -- сужение к острию
    local s = seg(m, "Blade", prev, cur, w, 0.08, steel, MAT.Metal)
    if s then bodies[#bodies + 1] = s end
    prev = cur
  end
  P("Tip", V3(0.12, 0.1, 0.12), CF(prev), glow, PT_BALL, MAT.Neon)
  return m, bodies, 5.2
end

local function buildHammer()
  local m = newWeaponModel("Wpn_hammer")
  local bodies = {}
  local function P(nm, sz, cf, col, shape, mat, tr)
    local p = mkp(m, nm, sz, cf, col, true, shape, mat, tr)
    bodies[#bodies + 1] = p; return p
  end
  local wood, steel, dark = C3(95, 65, 40), C3(150, 155, 170), C3(110, 115, 130)
  P("Shaft", V3(0.2, 0.2, 3.2), CF(0, 0, -0.5), wood, PT_BLOCK, MAT.Wood)
  for i = 0, 2 do
    P("Wrap", V3(0.25, 0.25, 0.14), CF(0, 0, 0.8 - i * 0.3), C3(50, 35, 25), PT_BLOCK, MAT.Fabric)
  end
  P("Pommel", V3(0.34, 0.34, 0.34), CF(0, 0, 1.2), dark, PT_BALL, MAT.Metal)
  -- массивная голова: длинная ось по Y (в плоскости взмаха)
  P("Head", V3(1.0, 1.8, 1.0), CF(0, 0, -2.3), steel, PT_BLOCK, MAT.Metal)
  for _, sy in ipairs({-1, 1}) do
    P("Cap", V3(1.18, 0.28, 1.18), CF(0, sy * 0.9, -2.3), dark, PT_BLOCK, MAT.Metal)
    P("Band", V3(1.1, 0.18, 1.1), CF(0, sy * 0.35, -2.3), dark, PT_BLOCK, MAT.Metal)
  end
  P("Rune", V3(0.34, 0.34, 0.06), CF(0, 0, -2.82) * CFrame.Angles(0, 0, math.rad(45)),
    C3(255, 170, 60), PT_BLOCK, MAT.Neon)
  return m, bodies, 3.6
end

local function buildAxe()
  local m = newWeaponModel("Wpn_axe")
  local bodies = {}
  local function P(nm, sz, cf, col, shape, mat, tr)
    local p = mkp(m, nm, sz, cf, col, true, shape, mat, tr)
    bodies[#bodies + 1] = p; return p
  end
  local wood, steel, dark, red = C3(85, 58, 38), C3(205, 212, 225), C3(90, 90, 100), C3(255, 90, 90)
  P("Shaft", V3(0.18, 0.18, 3.0), CF(0, 0, -0.5), wood, PT_BLOCK, MAT.Wood)
  for i = 0, 2 do
    P("Wrap", V3(0.23, 0.23, 0.12), CF(0, 0, 0.8 - i * 0.28), C3(45, 30, 20), PT_BLOCK, MAT.Fabric)
  end
  P("Pommel", V3(0.3, 0.3, 0.3), CF(0, 0, 1.1), dark, PT_BALL, MAT.Metal)
  -- двулезвийный топор: лезвия вверх и вниз от втулки (двойной удар)
  P("HeadBody", V3(0.3, 0.6, 0.55), CF(0, 0, -1.9), dark, PT_BLOCK, MAT.Metal)
  for _, sy in ipairs({-1, 1}) do
    P("Blade", V3(0.12, 0.9, 0.75), CF(0, sy * 0.65, -1.9), steel, PT_BLOCK, MAT.Metal)
    P("Edge", V3(0.15, 0.06, 0.8), CF(0, sy * 1.12, -1.9), red, PT_BLOCK, MAT.Neon, 0.15)
  end
  return m, bodies, 3.4
end

local function buildStaff()
  local m = newWeaponModel("Wpn_staff")
  local bodies = {}
  local function P(nm, sz, cf, col, shape, mat, tr)
    local p = mkp(m, nm, sz, cf, col, true, shape, mat, tr)
    bodies[#bodies + 1] = p; return p
  end
  local wood, gold, gemCol = C3(75, 55, 40), C3(220, 185, 80), C3(90, 220, 255)
  P("Shaft", V3(0.16, 0.16, 4.4), CF(0, 0, -1.0), wood, PT_BLOCK, MAT.Wood)
  for i = 0, 3 do
    P("Wrap", V3(0.21, 0.21, 0.12), CF(0, 0, 0.7 - i * 0.26), C3(40, 28, 20), PT_BLOCK, MAT.Fabric)
  end
  P("Ring", V3(0.28, 0.28, 0.12), CF(0, 0, -2.7), gold, PT_BLOCK, MAT.Metal)
  P("Ring", V3(0.28, 0.28, 0.12), CF(0, 0, -3.0), gold, PT_BLOCK, MAT.Metal)
  -- «когти», держащие кристалл
  for _, sd in ipairs({-1, 1}) do
    P("Prong", V3(0.1, 0.1, 1.0), CFrame.lookAt(V3(sd * 0.32, 0, -3.1), V3(sd * 0.16, 0, -3.95)), gold, PT_BLOCK, MAT.Metal)
  end
  -- кристалл: именно его позицию берёт атака как точку выстрела
  local gem = P("Gem", V3(0.62, 0.62, 0.62), CF(0, 0, -3.5), gemCol, PT_BALL, MAT.Neon, 0.1)
  local l = Instance.new("PointLight"); l.Color = gemCol; l.Range = 10; l.Brightness = 1.6; l.Parent = gem
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(gemCol); e.LightEmission = 1
  e.Size = NumberSequence.new(0.18, 0); e.Lifetime = NumberRange.new(0.4, 0.8)
  e.Speed = NumberRange.new(0.5, 2); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 10; e.Parent = gem
  return m, bodies, 4.8
end

-- ===== Каталог наград =====
local WEAPONS = {
  { id = "sans_knife", kind = "weapon",
    name = "🦴 Костяной клинок", desc = "Лезвие из кости. Атака: веер из 3 костей",
    source = "Санс",
    check = function() return ORBIT.sansKnifeUnlocked == true or ORBIT.sansUnlocked == true
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["sans_knife"]) end,
    build = buildSansKnife },
  { id = "gaster_blaster", kind = "weapon",
    name = "⚔ Гастер-бластер", desc = "Череп в руке. Атака: мощный луч",
    source = "Гастер",
    check = function() return ORBIT.gasterWeaponUnlocked == true or ORBIT.gasterUnlocked == true
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_weapon"]) end,
    build = buildGasterBlaster },
  { id = "sword", kind = "weapon",
    name = "🗡 Меч", desc = "Атака: удар вперёд на 8 studs (35 урона)",
    source = "Базовое",
    check = function() return true end,
    build = buildSword },
  { id = "shield", kind = "weapon",
    name = "🛡 Щит", desc = "Атака: толчок вперёд + небольшой урон",
    source = "Базовое",
    check = function() return true end,
    build = buildShield },
  -- v25.8: новые оружия (пока доступны сразу; условие открытия можно поменять в check)
  { id = "scythe", kind = "weapon", visualSize = 5.2,
    name = "🗡 Коса", desc = "Атака: широкий взмах по дуге, AoE 10 studs (28 урона)",
    source = "Арсенал",
    check = function() return true end,
    build = buildScythe },
  { id = "hammer", kind = "weapon", visualSize = 3.6,
    name = "🔨 Молот", desc = "Медленный: 70 урона + сильный толчок и ударная волна",
    source = "Арсенал",
    check = function() return true end,
    build = buildHammer },
  { id = "axe", kind = "weapon", visualSize = 3.4,
    name = "🪓 Топор", desc = "Двойной удар: 2 × 22 урона подряд",
    source = "Арсенал",
    check = function() return true end,
    build = buildAxe },
  { id = "staff", kind = "weapon", visualSize = 4.8,
    name = "⚡ Посох", desc = "Стреляет разрядом до 70 studs (30 урона + цепь 15)",
    source = "Арсенал",
    check = function() return true end,
    build = buildStaff },

  { id = "sans_boss_skin", kind = "cosmetic",
    name = "🎨 Скин «Санс-босс»",
    desc = "Персонаж исчезает, вместо него — фигура САНС. Тап — надеть/снять",
    source = "Санс",
    check = function() return (ORBIT.sansUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["sans_boss_skin"]) end },
  { id = "gaster_boss_skin", kind = "cosmetic",
    name = "🎨 Скин «Гастер-босс»",
    desc = "Персонаж исчезает, вместо него — фигура ГАСТЕР. Тап — надеть/снять",
    source = "Гастер",
    check = function() return (ORBIT.gasterUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_boss_skin"]) end },
  { id = "gaster_skull_helmet", kind = "cosmetic",
    name = "💀 Костяной шлем",
    desc = "Надевает череп-шлем на голову. Тап — надеть/снять",
    source = "Гастер",
    check = function() return (ORBIT.gasterUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_skull_helmet"]) end },

  -- v25.9: косметика за награды боссов (флаги ставит A.battle.win)
  { id = "sans_ghost", kind = "cosmetic",
    name = "👻 Санс-призрак", desc = "Персонаж полупрозрачный, голубой ореол. Тап — надеть/снять",
    source = "Санс", hint = "Победи Санса, не получив урона",
    check = function() local d = ORBIT.saveData; return ((d and d.rewards) and d.rewards["sans_ghost"]) == true end },
  { id = "gaster_dark_cloak", kind = "cosmetic",
    name = "🧥 Тёмный плащ", desc = "Плащ за спиной, развевается при беге. Тап — надеть/снять",
    source = "Гастер", hint = "Победи Гастера быстрее 90 сек",
    check = function() local d = ORBIT.saveData; return ((d and d.rewards) and d.rewards["gaster_dark_cloak"]) == true end },
  { id = "blade_master", kind = "cosmetic",
    name = "⚔ Титул «Мастер клинков»", desc = "Титул над головой. Тап — надеть/снять",
    source = "Общее", hint = "Одержи 10 побед над боссами",
    check = function() local d = ORBIT.saveData; return ((d and d.rewards) and d.rewards["blade_master"]) == true end },
  { id = "orbit_legend", kind = "cosmetic",
    name = "🏆 Титул «Легенда ОРБИТЫ»", desc = "Золотой титул и аура. Тап — надеть/снять",
    source = "Общее", hint = "Победи Санса и Гастера подряд, ни разу не умерев",
    check = function() local d = ORBIT.saveData; return ((d and d.rewards) and d.rewards["orbit_legend"]) == true end },

  { id = "gaster_portal_fx", kind = "effect",
    name = "🌀 Тёмный портал", desc = "Пассивно: вращающиеся кольца за спиной",
    source = "Гастер",
    check = function() return (ORBIT.gasterUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_portal_fx"]) end },
  { id = "gaster_blue_particles", kind = "effect",
    name = "💠 Синие частицы", desc = "Шлейф из синих искр при движении",
    source = "Гастер",
    check = function() return (ORBIT.gasterUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["gaster_blue_particles"]) end },
  { id = "blue_eye", kind = "effect",
    name = "💧 Синий глаз", desc = "Пассивно: возрождение 1 раз в 30 сек",
    source = "Санс",
    check = function() return (ORBIT.sansUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["blue_eye"]) end },
  { id = "blue_eye_tick", kind = "effect",
    name = "💧 Синий глаз-тик", desc = "Пассивно: предупреждение раз в 45 сек",
    source = "Гастер",
    check = function() return (ORBIT.gasterUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["blue_eye_tick"]) end },

  { id = "sans_chat", kind = "info",
    name = "💬 Санс в чате", desc = "Пишет фразы при победах",
    source = "Санс",
    check = function() return (ORBIT.sansUnlocked == true)
          or (ORBIT.saveData and ORBIT.saveData.rewards and ORBIT.saveData.rewards["sans_chat"]) end },
  { id = "coins_sans", kind = "info",
    name = "💰 +500 монет", desc = "Награда за победу над Сансом",
    source = "Санс",
    check = function() local d = ORBIT.saveData or {}; local rw = d.rewards or {}
      return (ORBIT.sansUnlocked == true) or rw["coins_sans"] == true or rw["coins"] == true end },
  { id = "coins_gaster", kind = "info",
    name = "💰 +800 монет", desc = "Награда за победу над Гастером",
    source = "Гастер",
    check = function() local d = ORBIT.saveData or {}; local rw = d.rewards or {}
      return (ORBIT.gasterUnlocked == true) or rw["coins_gaster"] == true end },
}

-- ===== Части тела (R6 + R15) =====
local BODY_NAMES = {
  "Head","UpperTorso","LowerTorso",
  "LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm",
  "LeftUpperLeg","LeftLowerLeg","RightUpperLeg","RightLowerLeg",
  "Torso","Left Arm","Right Arm","Left Leg","Right Leg",
}

local function getBodyParts(char)
  local out = {}
  for _, n in ipairs(BODY_NAMES) do
    local p = char:FindFirstChild(n)
    if p and p:IsA("BasePart") then out[#out + 1] = { name = n, part = p } end
  end
  return out
end

-- ═══════════════════════════════════════════════════════════
-- ОБРЕЗАНО НА orbit_weapons_menu.lua, строка ~475.
-- Часть 2/5 начинается с: -- ===== Фигурные скины =====
-- ═══════════════════════════════════════════════════════════
-- ===== Фигурные скины =====
local FIGURE_DEFS = {
  sans_boss_skin   = { preset = "САНС",   scale = 1.5, offsetY = -2.6 },
  gaster_boss_skin = { preset = "ГАСТЕР", scale = 1.3, offsetY = -2.8 },
}

function W.applyFigureSkin(skinId)
  W.removeFigureSkin()
  local def = FIGURE_DEFS[skinId]
  if not def then return false end
  local char = LP.Character
  if not char then return false end
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if not hrp then return false end

  W.savedCharState = {}
  for _, item in ipairs(getBodyParts(char)) do
    W.savedCharState[item.name] = item.part.Transparency
    item.part.Transparency = 1
  end
  for _, ch in ipairs(char:GetChildren()) do
    if ch:IsA("Accessory") or ch:IsA("Accoutrement") then
      for _, d in ipairs(ch:GetDescendants()) do
        if d:IsA("BasePart") then d.Transparency = 1 end
      end
    end
  end
  local head = char:FindFirstChild("Head")
  if head then
    local face = head:FindFirstChildOfClass("Decal")
    if face then W.savedFaceT = face.Transparency; face.Transparency = 1 end
  end

  local presets = ORBIT.SHAPE_PRESETS
  if type(presets) ~= "table" then
    warn("[Orbit Weapons] SHAPE_PRESETS пуст — фигура недоступна")
    return false
  end
  local preset = nil
  for _, p in ipairs(presets) do if p.name == def.preset then preset = p; break end end
  if not preset or type(preset.create) ~= "function" then
    warn("[Orbit Weapons] пресет «" .. def.preset .. "» не найден")
    return false
  end

  local ok, data = pcall(preset.create, def.scale, "OrbitSkin_" .. skinId)
  if not ok or not data or not data.model then
    warn("[Orbit Weapons] фигура «" .. def.preset .. "» не создалась")
    return false
  end

  data.model.Parent = fold()
  W.skinModel = data.model
  -- Фигуры САНС/ГАСТЕР построены лицом к +Z, HRP смотрит к -Z → разворот на 180°.
  W.skinOffset = CFrame.new(0, def.offsetY, 0) * CFrame.Angles(0, math.pi, 0)

  if data.model.PrimaryPart then
    pcall(function() data.model:PivotTo(hrp.CFrame * W.skinOffset) end)
  end
  -- v25.8: Rig.attach уже вызвал сам createSans/createGasterBody (orbit_p2 v24.5),
  -- здесь ничего подключать не нужно — просто каждый кадр зовём W.updateSkinRig.
  return true
end

function W.removeFigureSkin()
  if W.skinModel then
    -- v25.8: сначала отцепляем риг (модель уничтожается — rebind не нужен)
    local Rig = ORBIT.figureRig
    if Rig and Rig.detach then pcall(Rig.detach, W.skinModel) end
    pcall(function() W.skinModel:Destroy() end)
    W.skinModel = nil
  end
  W.skinOffset = nil
  local char = LP.Character
  if char and W.savedCharState then
    for _, item in ipairs(getBodyParts(char)) do
      local t = W.savedCharState[item.name]
      if t ~= nil then item.part.Transparency = t end
    end
    for _, ch in ipairs(char:GetChildren()) do
      if ch:IsA("Accessory") or ch:IsA("Accoutrement") then
        for _, d in ipairs(ch:GetDescendants()) do
          if d:IsA("BasePart") then d.Transparency = 0 end
        end
      end
    end
    local head = char:FindFirstChild("Head")
    if head and W.savedFaceT ~= nil then
      local face = head:FindFirstChildOfClass("Decal")
      if face then face.Transparency = W.savedFaceT end
    end
  end
  W.savedCharState = nil
  W.savedFaceT = nil
end

-- v25.8: оживляем фигуру-скин. Вызывается из Heartbeat ПОСЛЕ PivotTo(hrp * offset).
-- velWorld — скорость HRP; риг сам переводит её в оси фигуры (учитывает разворот на 180°).
function W.updateSkinRig(dt)
  local m = W.skinModel
  if not m or not m.Parent then return end
  local Rig = ORBIT.figureRig
  if not Rig or type(Rig.update) ~= "function" then return end
  local char = LP.Character
  local hrp = char and char:FindFirstChild("HumanoidRootPart")
  local vel = hrp and hrp.AssemblyLinearVelocity or nil
  pcall(Rig.update, m, dt, vel)
end

-- ===== Костяной шлем =====
local function buildSkullHelmet()
  local m = Instance.new("Model")
  local root = mkp(m, "Root", V3(1.6, 1.6, 1.6), CF(), C3(245, 245, 250), true, PT_BALL, MAT.SmoothPlastic)
  m.PrimaryPart = root
  local jaw = mkp(m, "Jaw", V3(1.2, 0.5, 1.2), CF(), C3(235, 235, 240), true, PT_BLOCK, MAT.SmoothPlastic)
  jaw.CFrame = root.CFrame * CF(0, -0.7, -0.1)
  local eyeL = mkp(m, "EyeL", V3(0.4, 0.4, 0.4), CF(), C3(15, 15, 20), true, PT_BALL, MAT.SmoothPlastic)
  eyeL.CFrame = root.CFrame * CF(-0.35, 0.15, -0.65)
  local eyeR = mkp(m, "EyeR", V3(0.4, 0.4, 0.4), CF(), C3(15, 15, 20), true, PT_BALL, MAT.SmoothPlastic)
  eyeR.CFrame = root.CFrame * CF(0.35, 0.15, -0.65)
  local glowL = mkp(m, "GlowL", V3(0.2, 0.2, 0.2), CF(), C3(120, 220, 255), true, PT_BALL, MAT.Neon)
  glowL.CFrame = eyeL.CFrame * CF(0, 0, -0.1)
  local glowR = mkp(m, "GlowR", V3(0.2, 0.2, 0.2), CF(), C3(120, 220, 255), true, PT_BALL, MAT.Neon)
  glowR.CFrame = eyeR.CFrame * CF(0, 0, -0.1)
  for _, p in ipairs({jaw, eyeL, eyeR, glowL, glowR}) do
    local w = Instance.new("WeldConstraint"); w.Part0 = root; w.Part1 = p; w.Parent = p
  end
  return m
end

local function attachHelmet(char)
  local head = char:FindFirstChild("Head")
  if not head then return end
  local old = char:FindFirstChild("OrbitSkullHelmet")
  if old then old:Destroy() end
  local m = buildSkullHelmet()
  m.Name = "OrbitSkullHelmet"
  m.Parent = char
  local parts = {}
  for _, d in ipairs(m:GetDescendants()) do
    if d:IsA("BasePart") then
      d.Anchored = false; d.Massless = true
      d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
      parts[#parts + 1] = d
    end
  end
  if #parts == 0 then return end
  local root = parts[1]; m.PrimaryPart = root
  root.CFrame = head.CFrame
  local wc = Instance.new("WeldConstraint")
  wc.Part0 = head; wc.Part1 = root; wc.Parent = root
  for i = 2, #parts do
    local w2 = Instance.new("WeldConstraint")
    w2.Part0 = root; w2.Part1 = parts[i]; w2.Parent = parts[i]
  end
end

-- ===== Регистрация скинов =====
local SKINS = {}

SKINS.sans_boss_skin = {
  apply = function() return W.applyFigureSkin("sans_boss_skin") end,
  remove = function() W.removeFigureSkin() end,
}
SKINS.gaster_boss_skin = {
  apply = function() return W.applyFigureSkin("gaster_boss_skin") end,
  remove = function() W.removeFigureSkin() end,
}
SKINS.gaster_skull_helmet = {
  apply = function()
    local c = LP.Character
    if not c then return false end
    attachHelmet(c)
    return true
  end,
  remove = function()
    local c = LP.Character
    if c then
      local m = c:FindFirstChild("OrbitSkullHelmet")
      if m then m:Destroy() end
    end
  end,
}

-- ===== v25.9: КОСМЕТИКА ЗА НАГРАДЫ (призрак, плащ, два титула) =====
-- Всё клиентское: видит только владелец. Между сессиями не сохраняется (как остальные скины).
-- Что нельзя носить одновременно (скин-фигура скрывает тело, плащ/призрак на нём бессмысленны):
local EXCLUSIVE = {
  sans_boss_skin    = { "gaster_boss_skin", "sans_ghost", "gaster_dark_cloak" },
  gaster_boss_skin  = { "sans_boss_skin", "sans_ghost", "gaster_dark_cloak" },
  sans_ghost        = { "sans_boss_skin", "gaster_boss_skin" },
  gaster_dark_cloak = { "sans_boss_skin", "gaster_boss_skin" },
  blade_master      = { "orbit_legend" },
  orbit_legend      = { "blade_master" },
}

-- 👻 Санс-призрак: части тела и аксессуары на 55% прозрачности + голубой Highlight.
-- Исходная прозрачность хранится в W.ghostSaved и возвращается при снятии.
local function ghostRemove()
  for d, t in pairs(W.ghostSaved or {}) do
    if d.Parent then pcall(function() d.Transparency = t end) end
  end
  W.ghostSaved = nil
  local char = LP.Character
  if char then
    local fx = char:FindFirstChild("OrbitGhostFx")
    if fx then fx:Destroy() end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local l = hrp and hrp:FindFirstChild("OrbitGhostLight")
    if l then l:Destroy() end
  end
end

local function ghostApply()
  local char = LP.Character
  if not char then return false end
  ghostRemove()
  W.ghostSaved = {}
  for _, d in ipairs(char:GetDescendants()) do
    local isPart = d:IsA("BasePart") and d.Name ~= "HumanoidRootPart"
    if (isPart or d:IsA("Decal"))
       and not d:FindFirstAncestor("OrbitDarkCloak") and not d:FindFirstAncestor("OrbitSkullHelmet") then
      W.ghostSaved[d] = d.Transparency
      d.Transparency = math.max(d.Transparency, 0.55)
    end
  end
  local hl = Instance.new("Highlight")
  hl.Name = "OrbitGhostFx"
  hl.FillColor = C3(120, 200, 255); hl.FillTransparency = 0.88
  hl.OutlineColor = C3(160, 230, 255); hl.OutlineTransparency = 0.25
  hl.DepthMode = Enum.HighlightDepthMode.Occluded
  hl.Adornee = char; hl.Parent = char
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if hrp then
    local l = Instance.new("PointLight")
    l.Name = "OrbitGhostLight"; l.Color = C3(130, 210, 255); l.Range = 12; l.Brightness = 1.1; l.Parent = hrp
  end
  return true
end

-- 🧥 Тёмный плащ: 3 звена цепочкой от плеч (каждое поворачивается относительно предыдущего)
-- + воротник и неоновая кайма. Крепится Weld к торсу; покачивание — W.updateCloak каждый кадр.
-- Спина персонажа = +Z торса (лицо смотрит в -Z).
local function cloakRemove()
  local c = W.cloak
  W.cloak = nil
  if c and c.model then pcall(function() c.model:Destroy() end) end
  local char = LP.Character
  local m = char and char:FindFirstChild("OrbitDarkCloak")
  if m then m:Destroy() end
end

function W.updateCloak(dt)
  local c = W.cloak
  if not c then return end
  if not (c.torso.Parent and c.hrp.Parent and c.model.Parent) then return end
  local t = tick()
  -- «шлейф»: чем быстрее бег вперёд, тем сильнее плащ отстаёт (с плавным затуханием)
  local vf = c.hrp.AssemblyLinearVelocity:Dot(c.hrp.CFrame.LookVector)
  c.trail = c.trail + (math.clamp(vf / 16, -1, 1) - c.trail) * math.min(1, dt * 6)
  local base = CFrame.new(c.top)
  local segBase = {}
  for i = 1, 3 do
    local step = -0.06 - c.trail * 0.28 + math.sin(t * 3 + i * 0.9) * 0.03 * (1 + math.abs(c.trail))
    base = base * CFrame.Angles(step, 0, 0)
    segBase[i] = base
    base = base * CFrame.new(0, -0.9, 0)
  end
  for _, it in ipairs(c.items) do
    if it.weld.Parent then it.weld.C0 = segBase[it.seg] * it.off end
  end
end

local function cloakApply()
  local char = LP.Character
  if not char then return false end
  local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")   -- R15 / R6
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if not (torso and hrp) then return false end
  cloakRemove()
  local m = Instance.new("Model"); m.Name = "OrbitDarkCloak"
  local width = torso.Size.X + 0.6
  local items = {}
  local function add(name, size, col, mat, seg, off)
    local p = mkp(m, name, size, CF(), col, true, PT_BLOCK, mat)
    p.Anchored = false; p.Massless = true
    p:SetAttribute("OrbitCosmetic", true)
    local w = Instance.new("Weld"); w.Part0 = torso; w.Part1 = p; w.Parent = p
    items[#items + 1] = { weld = w, seg = seg, off = off }
  end
  for i = 1, 3 do
    add("CloakSeg" .. i, V3(width + (i - 1) * 0.25, 0.95, 0.12), C3(24, 18, 38), MAT.Fabric, i, CF(0, -0.45, 0))
  end
  add("CloakCollar", V3(torso.Size.X + 0.3, 0.2, 0.22), C3(40, 30, 62), MAT.Fabric, 1, CF(0, -0.03, 0))
  add("CloakTrim", V3(width + 0.5, 0.08, 0.14), C3(170, 70, 255), MAT.Neon, 3, CF(0, -0.93, 0))
  m.Parent = char
  W.cloak = {
    model = m, torso = torso, hrp = hrp, items = items, trail = 0,
    top = V3(0, torso.Size.Y * 0.5 - 0.05, torso.Size.Z * 0.5 + 0.12),
  }
  W.updateCloak(0)   -- сразу расставить звенья
  return true
end

-- ⚔ / 🏆 Титулы: BillboardGui над головой. У «Легенды» ещё золотая аура (частицы + свет на HRP).
local function titleRemove()
  local char = LP.Character
  if not char then return end
  local head = char:FindFirstChild("Head")
  local t = head and head:FindFirstChild("OrbitTitle")
  if t then t:Destroy() end
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if hrp then
    local e = hrp:FindFirstChild("OrbitLegendAura")
    if e then e:Destroy() end
    local l = hrp:FindFirstChild("OrbitLegendLight")
    if l then l:Destroy() end
  end
end

local function titleApply(text, col, aura)
  local char = LP.Character
  local head = char and char:FindFirstChild("Head")
  if not head then return false end
  titleRemove()
  local bb = Instance.new("BillboardGui")
  bb.Name = "OrbitTitle"; bb.Adornee = head
  bb.Size = UDim2.fromOffset(240, 34); bb.StudsOffset = V3(0, 2.7, 0)
  bb.AlwaysOnTop = false; bb.MaxDistance = 140; bb.Parent = head
  local l = Instance.new("TextLabel")
  l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1
  l.Text = text; l.TextColor3 = col; l.Font = Enum.Font.GothamBold; l.TextSize = 18
  l.TextStrokeTransparency = 0.3; l.TextStrokeColor3 = C3(10, 8, 20)
  l.Parent = bb
  local hrp = char:FindFirstChild("HumanoidRootPart")
  if aura and hrp then
    local e = Instance.new("ParticleEmitter")
    e.Name = "OrbitLegendAura"
    e.Color = ColorSequence.new(C3(255, 230, 120), C3(255, 170, 40)); e.LightEmission = 1
    e.Size = NumberSequence.new(0.45, 0); e.Lifetime = NumberRange.new(0.9, 1.5)
    e.Speed = NumberRange.new(1, 3); e.EmissionDirection = Enum.NormalId.Top
    e.SpreadAngle = Vector2.new(35, 35); e.Acceleration = V3(0, 1.5, 0)
    e.Rate = UIS.TouchEnabled and 10 or 18     -- на телефоне меньше частиц
    e.Parent = hrp
    local pl = Instance.new("PointLight")
    pl.Name = "OrbitLegendLight"; pl.Color = C3(255, 210, 100); pl.Range = 12; pl.Brightness = 1.2; pl.Parent = hrp
  end
  return true
end

SKINS.sans_ghost = { apply = ghostApply, remove = ghostRemove }
SKINS.gaster_dark_cloak = { apply = cloakApply, remove = cloakRemove }
SKINS.blade_master = {
  apply = function() return titleApply("⚔ Мастер клинков", C3(200, 215, 235), false) end,
  remove = titleRemove,
}
SKINS.orbit_legend = {
  apply = function() return titleApply("🏆 Легенда ОРБИТЫ", C3(255, 215, 90), true) end,
  remove = titleRemove,
}

function W.toggleSkin(id)
  local skin = SKINS[id]
  if not skin then return false end
  if W.activeFx[id] then
    pcall(skin.remove)
    W.activeFx[id] = nil
    return true
  end
  -- снять несовместимое
  local dropped = 0
  for _, other in ipairs(EXCLUSIVE[id] or {}) do
    if W.activeFx[other] then
      local os = SKINS[other]
      if os then pcall(os.remove) end
      W.activeFx[other] = nil
      dropped = dropped + 1
    end
  end
  local ok, res = pcall(skin.apply)
  if not ok or res == false then
    -- не получилось надеть (нет персонажа / фигуры): откат, чтобы не остаться невидимым
    pcall(skin.remove)
    if ORBIT.notify then ORBIT.notify("❌ Не удалось надеть — нужен персонаж", C3(255, 150, 150), 2) end
    return true
  end
  W.activeFx[id] = true
  if dropped > 0 and ORBIT.notify then
    ORBIT.notify("↺ Несовместимое снято: " .. dropped .. " шт.", C3(255, 220, 160), 2)
  end
  return true
end

function W.reapplyActiveSkins()
  for id, _ in pairs(W.activeFx) do
    local skin = SKINS[id]
    if skin then pcall(skin.apply) end
  end
end

-- ═══════════════════════════════════════════════════════════
-- ОБРЕЗАНО НА orbit_weapons_menu.lua, строка ~890.
-- Часть 3/5 начинается с: -- ===== Атака оружием: общие хелперы =====
-- ═══════════════════════════════════════════════════════════
-- ===== Атака оружием: общие хелперы =====
local function rayParams()
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  local ex = { fold() }
  if LP.Character then ex[#ex + 1] = LP.Character end
  rp.FilterDescendantsInstances = ex
  return rp
end

local function damageTarget(inst, dmg, knockDir, knockPow)
  local m = inst:FindFirstAncestorOfClass("Model")
  if not m then return false end
  local hum = m:FindFirstChildOfClass("Humanoid")
  if not hum or hum.Health <= 0 then return false end
  if LP.Character and hum:IsDescendantOf(LP.Character) then return false end
  pcall(function() hum:TakeDamage(dmg) end)
  if knockDir and knockPow then
    local r = m:FindFirstChild("HumanoidRootPart")
    if r then
      pcall(function() r.AssemblyLinearVelocity = knockDir.Unit * knockPow * 3 + V3(0, knockPow * 0.6, 0) end)
    end
  end
  return true
end

-- v25.8: все живые Humanoid в сфере (игроки и NPC), кроме своего персонажа
local function aoeHits(pos, radius)
  local op = OverlapParams.new()
  op.FilterType = Enum.RaycastFilterType.Exclude
  local ex = { fold() }
  if LP.Character then ex[#ex + 1] = LP.Character end
  op.FilterDescendantsInstances = ex
  local seen, out = {}, {}
  for _, p in ipairs(WS:GetPartBoundsInRadius(pos, radius, op)) do
    local m = p:FindFirstAncestorOfClass("Model")
    if m and not seen[m] then
      seen[m] = true
      local hum = m:FindFirstChildOfClass("Humanoid")
      local root = m:FindFirstChild("HumanoidRootPart")
      if hum and root and hum.Health > 0 then out[#out + 1] = { hum = hum, root = root } end
    end
  end
  return out
end

local function knockRoot(root, dir, pow)
  if dir.Magnitude < 0.01 then dir = V3(0, 0, 1) end
  pcall(function() root.AssemblyLinearVelocity = dir.Unit * pow * 3 + V3(0, pow * 0.6, 0) end)
end

local function groundAt(pos)
  local res = WS:Raycast(pos + V3(0, 20, 0), V3(0, -60, 0), rayParams())
  return res and res.Position or pos
end

-- тряска камеры через abilities (если A.shake уже экспортирован)
local function shakeCam(mag, dur)
  local A = ORBIT.abilities
  if A and type(A.shake) == "function" then pcall(A.shake, mag, dur) end
end

-- ===== Эффекты попадания =====
local function hitFx(pos, col, size)
  size = size or 3
  local b = mkp(fold(), "Hit", V3(1, 1, 1), CF(pos), col, true, PT_BALL, MAT.Neon, 0.25)
  TS:Create(b, TweenInfo.new(0.3), { Size = V3(size, size, size), Transparency = 1 }):Play()
  Debris:AddItem(b, 0.4)
  local sp = mkp(fold(), "HitSp", V3(0.2, 0.2, 0.2), CF(pos), col, true, PT_BALL, MAT.Neon, 1)
  local e = Instance.new("ParticleEmitter")
  e.Color = ColorSequence.new(col); e.LightEmission = 1
  e.Size = NumberSequence.new(0.5, 0); e.Lifetime = NumberRange.new(0.3, 0.7)
  e.Speed = NumberRange.new(8, 16); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 0
  e.Parent = sp
  e:Emit(12)
  Debris:AddItem(sp, 1)
end

local function shockRing(pos, radius, col)
  local ring = mkp(fold(), "Shock", V3(0.3, 2, 2), CF(pos + V3(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
    col, true, PT_CYL, MAT.Neon, 0.3)
  TS:Create(ring, TweenInfo.new(0.4), { Size = V3(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
  Debris:AddItem(ring, 0.5)
end

-- дуга косы: 9 неоновых сегментов по полукругу перед игроком
local function arcFx(r, radius, col)
  local look = r.CFrame.LookVector
  local right = look:Cross(V3(0, 1, 0))
  local origin = r.Position + V3(0, 1.5, 0)
  for i = 0, 8 do
    local rot = CFrame.Angles(0, math.rad(-80 + i * 20), 0)
    local pos = origin + rot:VectorToWorldSpace(look) * radius * 0.85
    local tan = rot:VectorToWorldSpace(right)
    local p = mkp(fold(), "Arc", V3(0.3, 0.12, 2.4), CFrame.lookAt(pos, pos + tan), col, true, PT_BLOCK, MAT.Neon, 0.15)
    TS:Create(p, TweenInfo.new(0.3), { Transparency = 1 }):Play()
    Debris:AddItem(p, 0.4)
  end
end

-- рваная молния посоха
local function jaggedBolt(a, b, col, th)
  local d, n, prev = b - a, 8, a
  for i = 1, n do
    local p = (i == n) and b or (a + d * (i / n) + V3(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6)
    local s = seg(fold(), "Bolt", prev, p, th, th, col, MAT.Neon, 0.05)
    if s then TS:Create(s, TweenInfo.new(0.25), { Transparency = 1 }):Play(); Debris:AddItem(s, 0.3) end
    prev = p
  end
end

-- ===== v25.8: система взмаха =====
-- Раньше swingFx твинил PrimaryPart, а updatePositions каждый кадр делал PivotTo —
-- взмах затирался. Теперь смещение хранится в W.swings и ПРИБАВЛЯЕТСЯ к позиции в руке.
local function ease(k) return math.sin(k * math.pi * 0.5) end
local SWING = {}
SWING.thrust = function(k) return CF(0, 0, -1.2 * math.sin(math.pi * k)) end
SWING.slash = function(k)   -- замах → широкий размах справа налево → возврат
  local a
  if k < 0.25 then a = 85 * ease(k / 0.25)
  elseif k < 0.65 then a = 85 - 170 * ease((k - 0.25) / 0.4)
  else a = -85 * (1 - ease((k - 0.65) / 0.35)) end
  return CFrame.Angles(0, math.rad(a), math.rad(-20 * math.sin(math.pi * k)))
end
SWING.overhead = function(k)   -- замах вверх → быстрый удар вниз → возврат
  local a
  if k < 0.45 then a = 75 * ease(k / 0.45)
  elseif k < 0.65 then a = 75 - 115 * ease((k - 0.45) / 0.2)
  else a = -40 * (1 - ease((k - 0.65) / 0.35)) end
  return CFrame.Angles(math.rad(a), 0, 0)
end
SWING.chop = function(k)   -- два рубящих удара вниз (пики на k=0.25 и 0.75)
  return CFrame.Angles(math.rad(-55 * math.abs(math.sin(2 * math.pi * k))), 0, 0)
end
SWING.cast = function(k)   -- отдача посоха
  local s = math.sin(math.pi * k)
  return CF(0, 0, 0.7 * s) * CFrame.Angles(math.rad(-18 * s), 0, 0)
end

function W.swingOffset(id)
  local s = W.swings[id]
  if not s then return CFrame.new() end
  local k = (tick() - s.t0) / s.dur
  if k >= 1 then W.swings[id] = nil; return CFrame.new() end
  return (SWING[s.kind] or SWING.thrust)(k)
end

-- старая сигнатура swingFx(model) сохранена: без kind = короткий выпад вперёд
local function swingFx(model, kind, dur)
  if not model then return end
  local id = model:GetAttribute("OrbitId")
  if not id then return end
  W.swings[id] = { kind = kind or "thrust", t0 = tick(), dur = dur or 0.2 }
end

-- ===== Атаки =====
local ATTACKS = {}
ATTACKS.sword = function(c, h, r, model)
  swingFx(model); ping("snap", 1, 1.3)
  local origin = r.Position + V3(0, 1, 0); local dir = r.CFrame.LookVector
  local res = WS:Raycast(origin, dir * 8, rayParams())
  local hitInst = res and res.Instance
  local hitPos = res and res.Position or (origin + dir * 8)
  local fx = mkp(fold(), "Slash", V3(0.15, 3, 0.15), CF(), C3(255,255,255), true, PT_BLOCK, MAT.Neon, 0.5)
  fx.CFrame = CFrame.lookAt((origin + hitPos) / 2, hitPos) * CFrame.Angles(0, 0, math.rad(45))
  TS:Create(fx, TweenInfo.new(0.15), { Transparency = 1 }):Play(); Debris:AddItem(fx, 0.2)
  if hitInst then damageTarget(hitInst, 35, dir, 12) end
end
ATTACKS.shield = function(c, h, r, model)
  swingFx(model); ping("snap", 0.9, 0.8)
  local origin = r.Position + V3(0, 1, 0); local dir = r.CFrame.LookVector
  local res = WS:Raycast(origin, dir * 5, rayParams())
  local hitInst = res and res.Instance
  local hitPos = res and res.Position or (origin + dir * 5)
  local ring = mkp(fold(), "Push", V3(0.3, 2, 2), CF(), C3(180, 200, 255), true, PT_CYL, MAT.Neon, 0.4)
  ring.CFrame = CFrame.lookAt(hitPos, hitPos + dir) * CFrame.Angles(0, 0, math.rad(90))
  TS:Create(ring, TweenInfo.new(0.3), { Size = V3(0.3, 8, 8), Transparency = 1 }):Play(); Debris:AddItem(ring, 0.35)
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP and p.Character then
      local hrp = p.Character:FindFirstChild("HumanoidRootPart")
      local ph = p.Character:FindFirstChildOfClass("Humanoid")
      if hrp and ph and ph.Health > 0 and (hrp.Position - hitPos).Magnitude <= 5 then
        pcall(function() ph:TakeDamage(18) end)
        pcall(function() hrp.AssemblyLinearVelocity = dir.Unit * 40 + V3(0, 15, 0) end)
      end
    end
  end
  if hitInst then damageTarget(hitInst, 18, dir, 25) end
end
ATTACKS.sans_knife = function(c, h, r, model)
  swingFx(model); ping("snap", 1, 1.6)
  local ab = ORBIT.abilities
  local origin = r.Position + V3(0, 1.5, 0); local dir = r.CFrame.LookVector
  if ab and ab.spawnBones then pcall(ab.spawnBones, origin, dir, 3, 14, 1, false)
  else local res = WS:Raycast(origin, dir * 25, rayParams())
    if res then damageTarget(res.Instance, 25, dir, 10) end end
end
ATTACKS.gaster_blaster = function(c, h, r, model)
  ping("snap", 1, 1.2)
  local ab = ORBIT.abilities
  local origin = r.Position + V3(0, 2.5, 0) + r.CFrame.LookVector * 1
  local dir = r.CFrame.LookVector
  if ab and ab.fireBlaster then pcall(ab.fireBlaster, origin, dir, 1, 1)
  else
    local beam = mkp(fold(), "Beam", V3(1.5, 1.5, 40), CF(), C3(200, 220, 255), true, PT_BLOCK, MAT.Neon, 0.2)
    beam.CFrame = CFrame.lookAt(origin + dir * 20, origin + dir * 40)
    TS:Create(beam, TweenInfo.new(0.4), { Size = V3(0.1, 0.1, 40), Transparency = 1 }):Play(); Debris:AddItem(beam, 0.5)
    local res = WS:Raycast(origin, dir * 60, rayParams())
    if res then damageTarget(res.Instance, 50, dir, 15) end end
end

-- 🗡 Коса: широкий взмах, AoE 11 studs по передней полусфере, 28 урона
ATTACKS.scythe = function(c, h, r, model)
  swingFx(model, "slash", 0.55); ping("snap", 1, 0.8)
  task.delay(0.25, function()
    if not alive then return end
    local _, _, r2 = getChar(); if not r2 then return end
    local look = r2.CFrame.LookVector
    arcFx(r2, 11, C3(190, 120, 255)); ping("snap", 1, 0.6)
    local n = 0
    for _, e in ipairs(aoeHits(r2.Position, 11)) do
      local to = V3(e.root.Position.X - r2.Position.X, 0, e.root.Position.Z - r2.Position.Z)
      if to.Magnitude < 0.1 or to.Unit:Dot(look) > 0 then
        pcall(function() e.hum:TakeDamage(28) end)
        knockRoot(e.root, to, 10)
        hitFx(e.root.Position, C3(190, 120, 255), 4); n = n + 1
      end
    end
    if n > 0 then ping("ping", 1, 1.1); shakeCam(0.4, 0.2) end
  end)
end

-- 🔨 Молот: медленный удар, 70 урона вблизи удара (35 по краю), толчок, ударная волна
ATTACKS.hammer = function(c, h, r, model)
  swingFx(model, "overhead", 0.8); ping("snap", 0.8, 0.5)
  task.delay(0.44, function()
    if not alive then return end
    local _, _, r2 = getChar(); if not r2 then return end
    local impact = groundAt(r2.Position + r2.CFrame.LookVector * 6)
    shockRing(impact, 9, C3(255, 170, 60))
    hitFx(impact + V3(0, 1, 0), C3(255, 200, 100), 7)
    shakeCam(0.9, 0.4)
    ping("snap", 1, 0.4); ping("ping", 1, 0.6)
    for _, e in ipairs(aoeHits(impact, 8)) do
      local flat = V3(e.root.Position.X - impact.X, 0, e.root.Position.Z - impact.Z)
      pcall(function() e.hum:TakeDamage(flat.Magnitude <= 5 and 70 or 35) end)
      knockRoot(e.root, e.root.Position - impact, 30)
      hitFx(e.root.Position, C3(255, 200, 100), 4)
    end
  end)
end

-- 🪓 Топор: двойной удар, 2 × 22 урона по передней дуге 5 studs
ATTACKS.axe = function(c, h, r, model)
  swingFx(model, "chop", 0.6)
  for i, tm in ipairs({0.15, 0.45}) do
    task.delay(tm, function()
      if not alive then return end
      local _, _, r2 = getChar(); if not r2 then return end
      local look = r2.CFrame.LookVector
      local center = r2.Position + look * 3.5
      ping("snap", 1, 1.0 + i * 0.25)
      local fx = mkp(fold(), "Chop", V3(0.15, 3, 0.15), CF(), C3(255, 120, 120), true, PT_BLOCK, MAT.Neon, 0.3)
      fx.CFrame = CFrame.lookAt(center + V3(0, 1.2, 0), center + V3(0, 1.2, 0) + look) * CFrame.Angles(0, 0, math.rad(i == 1 and 30 or -30))
      TS:Create(fx, TweenInfo.new(0.2), { Transparency = 1 }):Play(); Debris:AddItem(fx, 0.25)
      local n = 0
      for _, e in ipairs(aoeHits(center, 5)) do
        local to = V3(e.root.Position.X - r2.Position.X, 0, e.root.Position.Z - r2.Position.Z)
        if to.Magnitude < 0.1 or to.Unit:Dot(look) > 0.2 then
          pcall(function() e.hum:TakeDamage(22) end)
          knockRoot(e.root, to, 6)
          hitFx(e.root.Position, C3(255, 120, 120), 3); n = n + 1
        end
      end
      if n > 0 then ping("ping", 1, 0.9 + i * 0.2); shakeCam(0.3, 0.15) end
    end)
  end
end

-- ⚡ Посох: разряд до 70 studs (автонаводка в конусе ~25°), 30 урона + цепь 15 на 2 цели
ATTACKS.staff = function(c, h, r, model)
  swingFx(model, "cast", 0.35); ping("snap", 1, 1.5)
  local gem = model and model:FindFirstChild("Gem", true)
  local look = r.CFrame.LookVector
  local origin = gem and gem.Position or (r.Position + V3(0, 2, 0) + look * 2)
  local best, bd = nil, 1e9
  for _, e in ipairs(aoeHits(r.Position, 70)) do
    local to = e.root.Position - origin
    local dist = to.Magnitude
    if dist > 1 and to.Unit:Dot(look) > 0.9 and dist < bd then best, bd = e, dist end
  end
  local dir = best and (best.root.Position - origin).Unit or look
  local res = WS:Raycast(origin, dir * 70, rayParams())
  local endPos = best and best.root.Position or (res and res.Position or (origin + dir * 70))
  jaggedBolt(origin, endPos, C3(120, 230, 255), 0.35)
  jaggedBolt(origin, endPos, C3(255, 255, 255), 0.12)
  hitFx(origin, C3(120, 230, 255), 2.5)
  hitFx(endPos, C3(120, 230, 255), 5)
  local primary
  if best then
    primary = best.hum
    pcall(function() best.hum:TakeDamage(30) end)
    knockRoot(best.root, dir, 8)
  elseif res then
    local m = res.Instance:FindFirstAncestorOfClass("Model")
    primary = m and m:FindFirstChildOfClass("Humanoid")
    damageTarget(res.Instance, 30, dir, 8)
  end
  local chained = 0
  for _, e in ipairs(aoeHits(endPos, 15)) do
    if e.hum ~= primary and chained < 2 then
      chained = chained + 1
      jaggedBolt(endPos, e.root.Position, C3(160, 240, 255), 0.25)
      pcall(function() e.hum:TakeDamage(15) end)
      hitFx(e.root.Position, C3(160, 240, 255), 3)
    end
  end
  ping("ping", 1, 1.4)
end

-- перезарядки (сек). Считаются по ТЕКУЩЕМУ оружию (раньше брался КД прошлого)
local WEAPON_CD = { gaster_blaster = 1.4, hammer = 1.6, scythe = 0.8, axe = 0.9, staff = 0.7 }

function W.attack()
  if not alive then return false end
  local activeId = nil
  for id, m in pairs(W.equipped) do
    if m and m.Parent and m:GetAttribute("OrbitSlot") == "R" then activeId = id; break end
  end
  if not activeId then
    for id, m in pairs(W.equipped) do if m and m.Parent then activeId = id; break end end
  end
  if not activeId then return false end
  local t = tick()
  W.attackCD = WEAPON_CD[activeId] or 0.6
  if t - W.lastAttack < W.attackCD then return false end
  W.lastAttack = t
  local c, h, r = getChar()
  if not c then return false end
  local fn = ATTACKS[activeId]
  if fn then
    local model = W.equipped[activeId]
    local ok, err = pcall(fn, c, h, r, model)
    if not ok then warn("[Orbit Weapons] attack " .. activeId .. ": " .. tostring(err)) end
    return true
  end
  return false
end

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
  if isR15 then return hand.CFrame * CF(0, 0, -1.2) * CFrame.Angles(math.rad(-15), 0, 0) end
  return hand.CFrame * CF(0, -1, -1.2) * CFrame.Angles(math.rad(-15), 0, 0)
end

-- v25.8: позиция оружия = рука * смещение взмаха (см. W.swingOffset)
local function updatePositions()
  local char = LP.Character
  if not char then return end
  for id, model in pairs(W.equipped) do
    if not model or not model.Parent then
      W.equipped[id] = nil; W.equippedMeta[id] = nil; W.swings[id] = nil
    else
      local slot = model:GetAttribute("OrbitSlot") or "R"
      local hand = findHand(char, slot)
      if hand then pcall(function() model:PivotTo(handCF(hand) * W.swingOffset(id)) end) end
    end
  end
end

local function unequipOne(id)
  local m = W.equipped[id]
  if m then pcall(function() m:Destroy() end) end
  W.equipped[id] = nil
  W.equippedMeta[id] = nil
  W.swings[id] = nil
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
    if w.kind == "weapon" and W.selected[w.id] then
      count = count + 1
      if not W.equipped[w.id] then
        -- v25.8: новые билдеры возвращают model, bodies, visualSize; старые — только model
        local ok, model, bodies, vs = pcall(w.build)
        if ok and model then
          model.Parent = fold()
          W.equipped[w.id] = model
          W.equippedMeta[w.id] = { bodies = bodies or {}, visualSize = vs or w.visualSize or 3 }
          slotIdx = slotIdx + 1
          model:SetAttribute("OrbitSlot", slots[((slotIdx - 1) % #slots) + 1])
          model:SetAttribute("OrbitId", w.id)   -- v25.8: нужен для взмаха (swingFx)
        else warn("[Orbit Weapons] сборка упала: " .. w.id) end
      end
    end
  end
  ping("buy", 1, 1.2)
  if ORBIT.notify then ORBIT.notify("✅ Экипировано: " .. count .. " шт.", C3(180,255,180), 3) end
  if W.updateAttackBtn then W.updateAttackBtn() end
  return true
end

-- ═══════════════════════════════════════════════════════════
-- ОБРЕЗАНО НА orbit_weapons_menu.lua, строка ~1290.
-- Часть 4/5 начинается с: -- ===== UI =====
-- ═══════════════════════════════════════════════════════════
-- ===== UI =====
-- v25.8: страховка — снести GUI по имени и в ORBIT.getSafeParent(), и в PlayerGui
local function killGui(name)
  local list = {}
  local a = uiParent(); if a then list[#list + 1] = a end
  local b = LP:FindFirstChildOfClass("PlayerGui"); if b and b ~= a then list[#list + 1] = b end
  for _, par in ipairs(list) do
    local g = par:FindFirstChild(name)
    if g then pcall(function() g:Destroy() end) end
  end
end

local function destroyUI()
  if W.sg then pcall(function() W.sg:Destroy() end) end
  W.sg, W.frame = nil, nil
  W.isOpen = false
  killGui("_OrbitWeaponsMenu")
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

local function makeDraggable(btn, defaultPos, saveKey, onTap)
  local dragging = false
  local moved = false
  local dragStart, startPos
  local downT = 0

  local sd = ORBIT.saveData
  local saved = sd and sd.buttonPos and sd.buttonPos[saveKey]
  if saved and type(saved) == "table" and saved.x and saved.y then
    btn.Position = UDim2.new(1, saved.x, 1, saved.y)
  elseif defaultPos then
    btn.Position = defaultPos
  end

  btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = true
      moved = false
      downT = tick()
      dragStart = input.Position
      startPos = btn.Position
    end
  end)
  -- v25.8: глобальные сигналы теперь через connect(), чтобы отключались в destroy()
  connect(UIS.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseMovement then
      local d = input.Position - dragStart
      if d.Magnitude > 8 then moved = true end
      if moved then
        local vp = WS.CurrentCamera.ViewportSize
        local nx = math.clamp(startPos.X.Offset + d.X, -vp.X + 60, -8)
        local ny = math.clamp(startPos.Y.Offset + d.Y, -vp.Y + 60, -8)
        btn.Position = UDim2.new(1, nx, 1, ny)
      end
    end
  end)
  connect(UIS.InputEnded, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = false
      local held = tick() - downT
      if not moved then
        if held < 0.5 and onTap then pcall(onTap) end
      else
        ORBIT.saveData = ORBIT.saveData or {}
        ORBIT.saveData.buttonPos = ORBIT.saveData.buttonPos or {}
        ORBIT.saveData.buttonPos[saveKey] = { x = btn.Position.X.Offset, y = btn.Position.Y.Offset }
      end
    end
  end)
end

local function refreshUI()
  if not W.frame then return end
  local sc = W.frame:FindFirstChild("Scroll")
  if not sc then return end
  for _, card in ipairs(sc:GetChildren()) do
    if card:IsA("Frame") and card:GetAttribute("RewardId") then
      local id = card:GetAttribute("RewardId")
      local unlocked = card:GetAttribute("Unlocked")
      local kind = card:GetAttribute("Kind")
      local chk = card:FindFirstChild("Check")
      local btn = card:FindFirstChild("Toggle")
      local selected = W.selected[id] and true or false
      local isActive = (kind == "cosmetic") and W.activeFx[id] or selected
      if chk then
        if not unlocked then chk.Text = "🔒"; chk.TextColor3 = C3(120,120,140)
        elseif kind == "info" then chk.Text = "ℹ"; chk.TextColor3 = C3(160,200,255)
        elseif isActive then chk.Text = "✅"; chk.TextColor3 = C3(120,255,160)
        else chk.Text = "▫"; chk.TextColor3 = C3(180,180,200) end
      end
      if btn then
        if not unlocked then
          btn.BackgroundColor3 = C3(50,40,50); btn.TextColor3 = C3(140,140,160); btn.Text = "ЗАКРЫТО"
        elseif kind == "info" then
          btn.BackgroundColor3 = C3(40,50,70); btn.TextColor3 = C3(180,210,255); btn.Text = "ИНФО"
        elseif isActive then
          btn.BackgroundColor3 = C3(50,100,60); btn.TextColor3 = C3(180,255,200); btn.Text = "СНЯТЬ"
        elseif kind == "cosmetic" then
          btn.BackgroundColor3 = C3(60,50,90); btn.TextColor3 = C3(220,210,255); btn.Text = "НАДЕТЬ"
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
    counter.Text = "Выбрано оружий: " .. n
  end
end

local function buildUI()
  destroyUI()
  local pg = uiParent()
  if not pg then return end

  local sg = Instance.new("ScreenGui")
  sg.Name = "_OrbitWeaponsMenu"; sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true; sg.DisplayOrder = 62; sg.Parent = pg
  W.sg = sg

  -- фон — обычный Frame (НЕ кнопка), Active=false: тач под ним не блокируется
  local bg = Instance.new("Frame")
  bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C3(0,0,0)
  bg.BackgroundTransparency = 0.55; bg.BorderSizePixel = 0
  bg.ZIndex = 1; bg.Active = false; bg.Parent = sg

  local cm = WS.CurrentCamera
  local vp = cm and cm.ViewportSize or Vector2.new(800, 600)
  local w = math.min(520, vp.X - 24)
  local h = math.min(620, vp.Y - 40)
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
  title.BackgroundTransparency = 1; title.Text = "🎁 АРСЕНАЛ И НАГРАДЫ"
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
  hint.Text = "Скин-фигура заменяет персонажа. Атака ⚔ или клавиша V."
  hint.TextColor3 = C3(170,170,200); hint.Font = Enum.Font.Gotham
  hint.TextSize = 11; hint.TextXAlignment = Enum.TextXAlignment.Left
  hint.ZIndex = 3; hint.Parent = frame

  local counter = Instance.new("TextLabel")
  counter.Name = "Counter"; counter.Size = UDim2.new(1, -32, 0, 20)
  counter.Position = UDim2.fromOffset(16, 66); counter.BackgroundTransparency = 1
  counter.Text = "Выбрано оружий: 0"; counter.TextColor3 = C3(255,220,140)
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

  local order = 0
  local function addHeader(text, color)
    order = order + 1
    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, -8, 0, 28); hdr.BackgroundTransparency = 1
    hdr.LayoutOrder = order; hdr.ZIndex = 4; hdr.Parent = sc
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 14
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 5; lbl.Parent = hdr
  end

  local function addCard(wdef)
    order = order + 1
    local unlocked = false
    pcall(function() unlocked = wdef.check() end)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 70)
    card.BackgroundColor3 = unlocked and C3(32,30,50) or C3(24,22,34)
    card.BorderSizePixel = 0; card.LayoutOrder = order; card.ZIndex = 4; card.Parent = sc
    card:SetAttribute("RewardId", wdef.id)
    card:SetAttribute("Unlocked", unlocked)
    card:SetAttribute("Kind", wdef.kind)
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

    local nm = Instance.new("TextLabel")
    nm.Size = UDim2.new(1, -170, 0, 22); nm.Position = UDim2.fromOffset(56, 8)
    nm.BackgroundTransparency = 1; nm.Text = wdef.name
    nm.TextColor3 = unlocked and C3(240,235,255) or C3(150,140,170)
    nm.Font = Enum.Font.GothamBold; nm.TextSize = 14
    nm.TextXAlignment = Enum.TextXAlignment.Left
    nm.ZIndex = 5; nm.Parent = card

    local src = Instance.new("TextLabel")
    src.Size = UDim2.new(0, 100, 0, 16); src.Position = UDim2.new(1, -110, 0, 10)
    src.BackgroundTransparency = 1; src.Text = "🎖 " .. wdef.source
    src.TextColor3 = unlocked and C3(200,220,255) or C3(120,120,140)
    src.Font = Enum.Font.Gotham; src.TextSize = 10
    src.TextXAlignment = Enum.TextXAlignment.Right
    src.ZIndex = 5; src.Parent = card

    -- v25.8: описание не заезжает под кнопку справа (ширина −166, высота 34)
    -- v25.9: у закрытой карточки — текст условия из wdef.hint
    local ds = Instance.new("TextLabel")
    ds.Size = UDim2.new(1, -166, 0, 34); ds.Position = UDim2.fromOffset(56, 30)
    ds.BackgroundTransparency = 1
    ds.Text = unlocked and wdef.desc or ("🔒 " .. (wdef.hint or ("Победи " .. wdef.source .. " — откроется")))
    ds.TextColor3 = unlocked and C3(180,180,210) or C3(255,200,120)
    ds.Font = Enum.Font.Gotham; ds.TextSize = 11; ds.TextWrapped = true
    ds.TextXAlignment = Enum.TextXAlignment.Left
    ds.TextYAlignment = Enum.TextYAlignment.Top
    ds.ZIndex = 5; ds.Parent = card

    local btn = Instance.new("TextButton")
    btn.Name = "Toggle"; btn.Size = UDim2.fromOffset(90, 30)
    btn.Position = UDim2.new(1, -100, 1, -38)
    btn.BackgroundColor3 = unlocked and C3(60,50,90) or C3(50,40,50)
    btn.TextColor3 = unlocked and C3(220,210,255) or C3(140,140,160)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 11
    btn.Text = unlocked and "ВЫБРАТЬ" or "ЗАКРЫТО"
    btn.AutoButtonColor = false; btn.ZIndex = 5; btn.Parent = card
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    if unlocked then
      if wdef.kind == "info" then
        onClick(btn, function()
          if ORBIT.notify then ORBIT.notify("ℹ " .. wdef.name .. ": " .. wdef.desc, C3(200,220,255), 3) end
        end)
        onClick(chk, function()
          if ORBIT.notify then ORBIT.notify("ℹ " .. wdef.name .. ": " .. wdef.desc, C3(200,220,255), 3) end
        end)
      elseif wdef.kind == "cosmetic" then
        local function toggleCos()
          if W.toggleSkin(wdef.id) then
            if W.activeFx[wdef.id] then
              if ORBIT.notify then ORBIT.notify("✅ " .. wdef.name .. " надет", C3(180,255,180), 2) end
            else
              if ORBIT.notify then ORBIT.notify("⏏ " .. wdef.name .. " снят", C3(255,200,140), 2) end
            end
            refreshUI()
          end
        end
        onClick(btn, toggleCos)
        onClick(chk, toggleCos)
      else
        local function toggleSel()
          if W.selected[wdef.id] then W.selected[wdef.id] = nil else W.selected[wdef.id] = true end
          refreshUI()
        end
        onClick(btn, toggleSel)
        onClick(chk, toggleSel)
      end
    else
      onClick(btn, function()
        if ORBIT.notify then ORBIT.notify("🔒 " .. (wdef.hint or ("Победи " .. wdef.source)), C3(255,180,120), 3) end
      end)
    end
  end

  addHeader("⚔ ОРУЖИЕ", C3(255,220,140))
  for _, w2 in ipairs(WEAPONS) do if w2.kind == "weapon" then addCard(w2) end end
  addHeader("🎨 КОСМЕТИКА", C3(255,180,255))
  for _, w2 in ipairs(WEAPONS) do if w2.kind == "cosmetic" then addCard(w2) end end
  addHeader("💠 ЭФФЕКТЫ", C3(180,220,255))
  for _, w2 in ipairs(WEAPONS) do if w2.kind == "effect" then addCard(w2) end end
  addHeader("💬 ПРОЧЕЕ", C3(200,200,220))
  for _, w2 in ipairs(WEAPONS) do if w2.kind == "info" then addCard(w2) end end

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
function W.open() return W.openMenu() end
function W.close() destroyUI(); return true end
function W.toggle()
  if W.isOpen then return W.close() end
  return W.openMenu()
end

-- ═══════════════════════════════════════════════════════════
-- ОБРЕЗАНО НА orbit_weapons_menu.lua, строка ~1640.
-- Часть 5/5 начинается с: -- ===== Мобильные кнопки с drag =====
-- ═══════════════════════════════════════════════════════════
-- ===== Мобильные кнопки с drag =====
local function buildMobileBtns()
  if not UIS.TouchEnabled then return end
  local pg = uiParent()
  if not pg then return end
  killGui("_OrbitWeaponsBtn"); killGui("_OrbitAttackBtn")

  local sg1 = Instance.new("ScreenGui")
  sg1.Name = "_OrbitWeaponsBtn"; sg1.ResetOnSpawn = false
  sg1.IgnoreGuiInset = true; sg1.DisplayOrder = 44; sg1.Parent = pg
  W.btnGui = sg1
  local b1 = Instance.new("TextButton")
  b1.Name = "WeaponsBtn"; b1.AnchorPoint = Vector2.new(1, 1)
  b1.Size = UDim2.fromOffset(56, 56); b1.Text = "🗡"; b1.TextSize = 28
  b1.Font = Enum.Font.GothamBold; b1.TextColor3 = C3(255,255,255)
  b1.BackgroundColor3 = C3(80,60,130); b1.BackgroundTransparency = 0.1
  b1.AutoButtonColor = false; b1.ZIndex = 44; b1.Parent = sg1
  Instance.new("UICorner", b1).CornerRadius = UDim.new(0, 28)
  local st1 = Instance.new("UIStroke", b1); st1.Color = C3(180,140,255); st1.Thickness = 2

  makeDraggable(b1, UDim2.new(1, -16, 1, -440), "weaponsBtn", function() W.toggle() end)

  local sg2 = Instance.new("ScreenGui")
  sg2.Name = "_OrbitAttackBtn"; sg2.ResetOnSpawn = false
  sg2.IgnoreGuiInset = true; sg2.DisplayOrder = 44; sg2.Parent = pg
  W.attackGui = sg2
  local b2 = Instance.new("TextButton")
  b2.Name = "AttackBtn"; b2.AnchorPoint = Vector2.new(1, 1)
  b2.Size = UDim2.fromOffset(56, 56); b2.Text = "⚔"; b2.TextSize = 28
  b2.Font = Enum.Font.GothamBold; b2.TextColor3 = C3(255,255,255)
  b2.BackgroundColor3 = C3(130,60,60); b2.BackgroundTransparency = 0.1
  b2.AutoButtonColor = false; b2.ZIndex = 44; b2.Parent = sg2
  Instance.new("UICorner", b2).CornerRadius = UDim.new(0, 28)
  local st2 = Instance.new("UIStroke", b2); st2.Color = C3(255,140,140); st2.Thickness = 2
  W.attackBtn = b2

  makeDraggable(b2, UDim2.new(1, -80, 1, -440), "attackBtn", function() W.attack() end)

  W.updateAttackBtn = function()
    local has = next(W.equipped) ~= nil
    if b2 then
      b2.BackgroundTransparency = has and 0.1 or 0.6
      b2.TextColor3 = has and C3(255,255,255) or C3(150,150,150)
    end
  end
  W.updateAttackBtn()
end
buildMobileBtns()

-- ===== Heartbeat: оружие в руках + фигура скина + её риг =====
connect(RS.Heartbeat, function(dt)
  -- оружие в руках (с учётом взмаха)
  if next(W.equipped) ~= nil then pcall(updatePositions) end
  pcall(W.updateCloak, dt)   -- v25.9: покачивание плаща (если надет)
  -- фигура-скин следует за персонажем
  if W.skinModel and W.skinModel.Parent then
    local char = LP.Character
    if char then
      local hrp = char:FindFirstChild("HumanoidRootPart")
      if hrp then
        pcall(function()
          W.skinModel:PivotTo(hrp.CFrame * (W.skinOffset or CFrame.new()))
        end)
        -- v25.8: риг СТРОГО после PivotTo — иначе PivotTo сотрёт позу ног/рук
        W.updateSkinRig(dt)
      end
    end
  end
end)

-- клавиша V — атака (ПК)
connect(UIS.InputBegan, function(input, gp)
  if gp then return end
  if not alive then return end
  if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.V then
    W.attack()
  end
end)

-- возврат оружия + скинов после респавна
connect(LP.CharacterAdded, function()
  task.wait(0.6)
  if next(W.selected) ~= nil then pcall(W.applySelection) end
  -- если активен фигурный скин — переприменить на новом персонаже
  local hasFigure = W.activeFx.sans_boss_skin or W.activeFx.gaster_boss_skin
  if hasFigure then
    for id, _ in pairs(W.activeFx) do
      local skin = SKINS[id]
      if skin and not FIGURE_DEFS[id] then pcall(skin.apply) end
    end
    for id in pairs(FIGURE_DEFS) do
      if W.activeFx[id] then
        local skin = SKINS[id]
        if skin then pcall(skin.apply) end
      end
    end
  else
    pcall(W.reapplyActiveSkins)
  end
end)

-- на случай удаления персонажа
connect(LP.CharacterRemoving, function()
  if W.skinModel then
    local Rig = ORBIT.figureRig
    if Rig and Rig.detach then pcall(Rig.detach, W.skinModel) end   -- v25.8
    pcall(function() W.skinModel:Destroy() end)
    W.skinModel = nil
  end
  W.swings = {}
  W.savedCharState = nil
  W.savedFaceT = nil
end)

-- ===== API =====
function W.list()
  local out = {}
  for _, w in ipairs(WEAPONS) do
    local unlocked = false
    pcall(function() unlocked = w.check() end)
    out[#out+1] = { id = w.id, name = w.name, desc = w.desc, source = w.source,
      kind = w.kind, unlocked = unlocked, selected = W.selected[w.id] and true or false,
      active = W.activeFx[w.id] and true or false, visualSize = w.visualSize }
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
  W.swings, W.equippedMeta = {}, {}
  -- снять все активные скины и косметику (включая фигурные; removeFigureSkin делает Rig.detach)
  for id in pairs(W.activeFx) do
    local skin = SKINS[id]
    if skin then pcall(skin.remove) end
  end
  W.activeFx = {}
  if W.skinModel then
    local Rig = ORBIT.figureRig
    if Rig and Rig.detach then pcall(Rig.detach, W.skinModel) end   -- v25.8 страховка
    pcall(function() W.skinModel:Destroy() end); W.skinModel = nil
  end
  if W.btnGui then pcall(function() W.btnGui:Destroy() end); W.btnGui = nil end
  if W.attackGui then pcall(function() W.attackGui:Destroy() end); W.attackGui = nil end
  if W.folder then pcall(function() W.folder:Destroy() end); W.folder = nil end
  -- страховка по имени (в getSafeParent и в PlayerGui)
  for _, nm in ipairs({"_OrbitWeaponsMenu", "_OrbitWeaponsBtn", "_OrbitAttackBtn"}) do
    killGui(nm)
  end
  pcall(function()
    local c = LP.Character
    local hm = c and c:FindFirstChild("OrbitSkullHelmet")
    if hm then hm:Destroy() end
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
  ORBIT.notify("🗡 Арсенал v25.9 (+косметика за награды, титулы, плащ)", C3(200, 220, 255), 3)
end

return true
Файл 2/3 выдан. Напиши "дальше" — выдам следующий.
