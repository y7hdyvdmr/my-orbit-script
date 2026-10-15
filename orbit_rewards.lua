-- ORBIT v25.2 | orbit_rewards.lua
-- Экран наград: все награды за Санса и Гастера, общие награды, монеты, статистика, прогресс.
-- v25.1: базовый модуль.
-- v25.1-fix1: фон-оверлей больше не блокирует кнопки прицела/стрельбы,
--             destroyUI с принудительной очисткой по имени.
-- v25.2: + 4 награды: sans_ghost, gaster_dark_cloak, blade_master, orbit_legend.
--        + раздел «ОБЩЕЕ» (награды, не привязанные к одному боссу).
--        + блок «СТАТИСТИКА» (ORBIT.saveData.stats через A.battle.getStats).
--        + UI создаётся через ORBIT.getSafeParent() (запасной вариант PlayerGui),
--          страховка по имени в destroy — в обоих родителях.
--        + фикс: destroyUI делал D.open = false и затирал функцию D.open();
--          флаг переименован в D.isOpen.
--        + hasReward всегда возвращает булево значение для флагов в rewards.
local GENV = (type(getgenv) == "function" and getgenv()) or _G
local ORBIT = GENV.ORBIT or shared.ORBIT
if not ORBIT then warn("[ORBIT] rewards: нет ORBIT"); return false end
if ORBIT.rewards and ORBIT.rewards.destroy then pcall(ORBIT.rewards.destroy) end
ORBIT.loaded = ORBIT.loaded or {}

local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
local LP = Players.LocalPlayer
local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB

-- boss: "Санс" | "Гастер" | "Общее" (определяет раздел). hint — подсказка для закрытой награды.
local REWARDS = {
  -- Санс
  { id = "sans_knife",            boss = "Санс",    icon = "🦴", name = "Костяной клинок",    desc = "Оружие: веер из 3 костей" },
  { id = "blue_eye",              boss = "Санс",    icon = "💧", name = "Синий глаз",         desc = "Возрождение 1 раз в 30 сек" },
  { id = "coins_sans",            boss = "Санс",    icon = "💰", name = "+500 монет",         desc = "Награда за победу над Сансом" },
  { id = "sans_chat",             boss = "Санс",    icon = "💬", name = "Санс в чате",        desc = "Пишет фразы при победах" },
  { id = "sans_boss_skin",        boss = "Санс",    icon = "🎨", name = "Скин «Санс-босс»",   desc = "Открыт в магазине" },
  { id = "sans_ghost",            boss = "Санс",    icon = "👻", name = "Санс-призрак",       desc = "Победа над Сансом без потери HP",
    hint = "Победи Санса, не получив урона" },
  -- Гастер
  { id = "gaster_weapon",         boss = "Гастер",  icon = "⚔", name = "Гастер-оружие",      desc = "G — выстрел, H — снять" },
  { id = "gaster_boss_skin",      boss = "Гастер",  icon = "🎨", name = "Скин «Гастер-босс»", desc = "Косметика в магазине" },
  { id = "blue_eye_tick",         boss = "Гастер",  icon = "💧", name = "Синий глаз-тик",     desc = "Предупреждение раз в 45 сек" },
  { id = "gaster_skull_helmet",   boss = "Гастер",  icon = "💀", name = "Костяной шлем",      desc = "Косметика в магазине" },
  { id = "gaster_double_blaster", boss = "Гастер",  icon = "⚡", name = "Двойной бластер",    desc = "Скорость стрельбы ×2" },
  { id = "gaster_portal_fx",      boss = "Гастер",  icon = "🌀", name = "Тёмный портал",      desc = "Пассивный эффект за спиной" },
  { id = "gaster_blue_particles", boss = "Гастер",  icon = "💠", name = "Синие частицы",      desc = "Шлейф при движении" },
  { id = "coins_gaster",          boss = "Гастер",  icon = "💰", name = "+800 монет",         desc = "Награда за победу над Гастером" },
  { id = "gaster_dark_cloak",     boss = "Гастер",  icon = "🧥", name = "Тёмный плащ",        desc = "Победа над Гастером быстрее 90 сек",
    hint = "Победи Гастера быстрее 90 сек (от начала боя)" },
  -- Общее
  { id = "blade_master",          boss = "Общее",   icon = "⚔", name = "Мастер клинков",     desc = "10 побед над боссами",
    hint = "Одержи 10 побед над боссами" },
  { id = "orbit_legend",          boss = "Общее",   icon = "🏆", name = "Легенда ОРБИТЫ",     desc = "Санс и Гастер подряд без смертей",
    hint = "Победи Санса и Гастера подряд, ни разу не умерев" },
}

local D = {
  isOpen = false,   -- флаг; поле open занято функцией D.open()
  sg = nil,
  frame = nil,
}

local GUI_NAME = "_OrbitRewardsUI"

local function getSave()
  return ORBIT.saveData or {}
end
local function hasReward(id)
  local d = getSave()
  if id == "coins_sans" then
    return (ORBIT.sansUnlocked == true) or (d.rewards and d.rewards["coins_sans"])
  end
  if id == "coins_gaster" then
    return (ORBIT.gasterUnlocked == true) or (d.rewards and d.rewards["coins_gaster"])
  end
  if id == "gaster_weapon" then
    return (ORBIT.gasterWeaponUnlocked == true) or ((d.rewards and d.rewards["gaster_weapon"]) == true)
  end
  -- v25.2: новые награды (sans_ghost, gaster_dark_cloak, blade_master, orbit_legend) — обычные флаги
  return (d.rewards and d.rewards[id]) == true
end

-- v25.2: статистика боёв. Источник — A.battle.getStats (orbit_abilities v25.1),
-- запасной вариант — ORBIT.saveData.stats напрямую.
local function getBattleStats()
  local ab = ORBIT.abilities
  local B = ab and ab.battle
  if B and B.getStats then
    local ok, st = pcall(B.getStats)
    if ok and type(st) == "table" then return st end
  end
  return getSave().stats or {}
end

local function chainText(ch)
  if type(ch) ~= "string" or ch == "" then return "—" end
  local t = (ch:gsub("sans", "Санс"))
  t = t:gsub("gaster", "Гастер")
  return (t:gsub("%+", " + "))
end

local function getStats()
  local total = #REWARDS
  local got = 0
  local sansGot, sansTotal = 0, 0
  local gasterGot, gasterTotal = 0, 0
  local commonGot, commonTotal = 0, 0
  for _, r in ipairs(REWARDS) do
    local has = hasReward(r.id) and true or false
    if has then got = got + 1 end
    if r.boss == "Санс" then
      sansTotal = sansTotal + 1
      if has then sansGot = sansGot + 1 end
    elseif r.boss == "Гастер" then
      gasterTotal = gasterTotal + 1
      if has then gasterGot = gasterGot + 1 end
    else
      commonTotal = commonTotal + 1
      if has then commonGot = commonGot + 1 end
    end
  end
  return {
    total = total, got = got,
    sans = { got = sansGot, total = sansTotal },
    gaster = { got = gasterGot, total = gasterTotal },
    common = { got = commonGot, total = commonTotal },
    coins = ORBIT.COINS or 0,
  }
end

-- ============================================================
--       UI
-- ============================================================
-- v25.2: родитель для UI — ORBIT.getSafeParent(), запасной вариант PlayerGui
local function uiParent()
  if type(ORBIT.getSafeParent) == "function" then
    local ok, p = pcall(ORBIT.getSafeParent)
    if ok and typeof(p) == "Instance" then return p end
  end
  return LP:FindFirstChildOfClass("PlayerGui")
end

local function destroyUI()
  if D.sg then pcall(function() D.sg:Destroy() end) end
  D.sg, D.frame = nil, nil
  D.isOpen = false
  -- страховка — снести по имени, если ссылка потерялась (в обоих родителях)
  pcall(function()
    local a = uiParent()
    if a then
      local g = a:FindFirstChild(GUI_NAME)
      if g then g:Destroy() end
    end
    local b = LP:FindFirstChildOfClass("PlayerGui")
    if b then
      local g2 = b:FindFirstChild(GUI_NAME)
      if g2 then g2:Destroy() end
    end
  end)
end

local function buildUI()
  destroyUI()
  local pg = uiParent()
  if not pg then return end

  local sg = Instance.new("ScreenGui")
  sg.Name = GUI_NAME
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.DisplayOrder = 62
  sg.Parent = pg
  D.sg = sg
  D.isOpen = true

  -- Задний фон — обычный Frame (НЕ кнопка), Active=false: тач под ним не блокируется
  local bg = Instance.new("Frame")
  bg.Size = UDim2.fromScale(1, 1)
  bg.BackgroundColor3 = C3(0, 0, 0)
  bg.BackgroundTransparency = 0.5
  bg.BorderSizePixel = 0
  bg.ZIndex = 1
  bg.Active = false
  bg.Parent = sg

  local cm = game:GetService("Workspace").CurrentCamera
  local vp = cm and cm.ViewportSize or Vector2.new(800, 600)
  local w = math.min(560, vp.X - 24)
  local h = math.min(620, vp.Y - 40)
  local frame = Instance.new("Frame")
  frame.Size = UDim2.fromOffset(w, h)
  frame.AnchorPoint = Vector2.new(0.5, 0.5)
  frame.Position = UDim2.fromScale(0.5, 0.5)
  frame.BackgroundColor3 = C3(18, 14, 30)
  frame.BorderSizePixel = 0
  frame.ZIndex = 2
  frame.Parent = sg
  D.frame = frame
  Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
  local st = Instance.new("UIStroke", frame)
  st.Color = C3(180, 140, 255); st.Thickness = 2; st.Transparency = 0.15

  -- Заголовок
  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1, -60, 0, 32)
  title.Position = UDim2.fromOffset(16, 10)
  title.BackgroundTransparency = 1
  title.Text = "🎁 НАГРАДЫ ОРБИТЫ"
  title.TextColor3 = C3(240, 230, 255)
  title.Font = Enum.Font.GothamBold
  title.TextSize = 20
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.ZIndex = 3
  title.Parent = frame

  -- Кнопка закрытия
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
  close.Activated:Connect(function() destroyUI() end)

  -- Счётчики наград (3 строки × 2 колонки)
  local stats = getStats()
  local bstats = getBattleStats()
  local statsBar = Instance.new("Frame")
  statsBar.Size = UDim2.new(1, -32, 0, 92)
  statsBar.Position = UDim2.fromOffset(16, 50)
  statsBar.BackgroundColor3 = C3(28, 22, 44)
  statsBar.BorderSizePixel = 0
  statsBar.ZIndex = 3
  statsBar.Parent = frame
  Instance.new("UICorner", statsBar).CornerRadius = UDim.new(0, 10)

  local function stat(x, y, w2, icon, text, col)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromOffset(w2, 26)
    l.Position = UDim2.fromOffset(x, y)
    l.BackgroundTransparency = 1
    l.Text = icon .. " " .. text
    l.TextColor3 = col or C3(220, 220, 240)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 4
    l.Parent = statsBar
    return l
  end

  stat(12, 8, 200, "🎁", "Получено: " .. stats.got .. " / " .. stats.total, C3(200, 255, 200))
  stat(12, 36, 200, "💰", "Монеты: " .. stats.coins, C3(255, 220, 120))
  stat(12, 62, 200, "🏅", "Общее: " .. stats.common.got .. " / " .. stats.common.total, C3(255, 230, 150))
  stat(220, 8, 200, "💀", "Санс: " .. stats.sans.got .. " / " .. stats.sans.total, C3(200, 220, 255))
  stat(220, 36, 200, "👁", "Гастер: " .. stats.gaster.got .. " / " .. stats.gaster.total, C3(220, 180, 255))
  stat(220, 62, 200, "📊", "Побед: " .. (bstats.wins_total or 0), C3(180, 240, 220))

  -- Прогресс-бар
  local progBg = Instance.new("Frame")
  progBg.Size = UDim2.new(1, -32, 0, 8)
  progBg.Position = UDim2.fromOffset(16, 150)
  progBg.BackgroundColor3 = C3(45, 35, 60)
  progBg.BorderSizePixel = 0
  progBg.ZIndex = 3
  progBg.Parent = frame
  Instance.new("UICorner", progBg).CornerRadius = UDim.new(0, 4)

  local progFill = Instance.new("Frame")
  progFill.Size = UDim2.new(stats.total > 0 and (stats.got / stats.total) or 0, 0, 1, 0)
  progFill.BackgroundColor3 = C3(160, 220, 255)
  progFill.BorderSizePixel = 0
  progFill.ZIndex = 4
  progFill.Parent = progBg
  Instance.new("UICorner", progFill).CornerRadius = UDim.new(0, 4)
  local gr = Instance.new("UIGradient", progFill)
  gr.Color = ColorSequence.new(C3(120, 200, 255), C3(200, 150, 255))

  -- Скролл со списком
  local sc = Instance.new("ScrollingFrame")
  sc.Position = UDim2.fromOffset(16, 168)
  sc.Size = UDim2.new(1, -32, 1, -184)
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

  local function sectionHeader(text, color, order)
    local hd = Instance.new("Frame")
    hd.Size = UDim2.new(1, -8, 0, 28)
    hd.BackgroundTransparency = 1
    hd.LayoutOrder = order
    hd.ZIndex = 4
    hd.Parent = sc
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color
    l.Font = Enum.Font.GothamBold
    l.TextSize = 15
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 5
    l.Parent = hd
  end

  -- v25.2: карточка статистики боёв
  local function statsCard(order)
    local best = tonumber(bstats.best_gaster_time)
    local lines = {
      "🏆 Побед всего: " .. (bstats.wins_total or 0)
        .. "   💀 Санс: " .. (bstats.wins_sans or 0)
        .. "   👁 Гастер: " .. (bstats.wins_gaster or 0),
      "⏱ Лучшее время Гастера: " .. (best and string.format("%.1f с", best) or "—") .. "  (для плаща < 90 с)",
      "🛡 Серия без смертей: " .. (bstats.no_death_streak or 0) .. "   🔗 Цепочка: " .. chainText(bstats.chain),
      "👻 Побед над Сансом без урона: " .. (bstats.no_damage_sans or 0),
      "⚔ До «Мастера клинков»: " .. math.min(bstats.wins_total or 0, 10) .. " / 10",
    }
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 112)
    card.BackgroundColor3 = C3(26, 30, 44)
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 4
    card.Parent = sc
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke", card)
    cs.Color = C3(100, 170, 200); cs.Thickness = 1.5; cs.Transparency = 0.4
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 1, -12)
    l.Position = UDim2.fromOffset(10, 6)
    l.BackgroundTransparency = 1
    l.Text = table.concat(lines, "\n")
    l.TextColor3 = C3(200, 225, 240)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.ZIndex = 5
    l.Parent = card
  end

  local function rewardCard(r, order)
    local got = hasReward(r.id)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 58)
    card.BackgroundColor3 = got and C3(32, 42, 36) or C3(28, 22, 44)
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ZIndex = 4
    card.Parent = sc
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke", card)
    cs.Color = got and C3(120, 220, 150) or C3(80, 70, 110)
    cs.Thickness = 1.5
    cs.Transparency = got and 0.2 or 0.5

    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.fromOffset(46, 46)
    ic.Position = UDim2.fromOffset(8, 6)
    ic.BackgroundColor3 = got and C3(45, 65, 50) or C3(40, 35, 55)
    ic.BorderSizePixel = 0
    ic.Text = r.icon
    ic.TextSize = 26
    ic.Font = Enum.Font.GothamBold
    ic.TextColor3 = C3(255, 255, 255)
    ic.ZIndex = 5
    ic.Parent = card
    Instance.new("UICorner", ic).CornerRadius = UDim.new(0, 8)

    local nm = Instance.new("TextLabel")
    nm.Size = UDim2.new(1, -110, 0, 20)
    nm.Position = UDim2.fromOffset(62, 8)
    nm.BackgroundTransparency = 1
    nm.Text = r.name
    nm.TextColor3 = got and C3(200, 255, 200) or C3(200, 200, 220)
    nm.Font = Enum.Font.GothamBold
    nm.TextSize = 13
    nm.TextXAlignment = Enum.TextXAlignment.Left
    nm.ZIndex = 5
    nm.Parent = card

    local ds = Instance.new("TextLabel")
    ds.Size = UDim2.new(1, -110, 0, 26)
    ds.Position = UDim2.fromOffset(62, 28)
    ds.BackgroundTransparency = 1
    ds.Text = r.desc
    ds.TextColor3 = got and C3(170, 200, 180) or C3(160, 160, 190)
    ds.Font = Enum.Font.Gotham
    ds.TextSize = 11
    ds.TextWrapped = true
    ds.TextXAlignment = Enum.TextXAlignment.Left
    ds.TextYAlignment = Enum.TextYAlignment.Top
    ds.ZIndex = 5
    ds.Parent = card

    local stt = Instance.new("TextLabel")
    stt.Size = UDim2.fromOffset(40, 20)
    stt.Position = UDim2.new(1, -48, 0, 6)
    stt.BackgroundTransparency = 1
    stt.Text = got and "✅" or "🔒"
    stt.TextSize = 16
    stt.Font = Enum.Font.GothamBold
    stt.TextColor3 = got and C3(120, 255, 160) or C3(150, 150, 170)
    stt.ZIndex = 5
    stt.Parent = card

    if not got then
      -- v25.2: у новых наград свой текст условия (r.hint); у остальных прежнее «Победи <босс>»
      local hint = Instance.new("TextLabel")
      hint.Size = UDim2.new(1, -110, 0, 14)
      hint.Position = UDim2.fromOffset(62, 42)
      hint.BackgroundTransparency = 1
      hint.Text = r.hint or ("Победи " .. r.boss .. " — откроется")
      hint.TextColor3 = C3(255, 200, 120)
      hint.Font = Enum.Font.Gotham
      hint.TextSize = 10
      hint.TextXAlignment = Enum.TextXAlignment.Left
      hint.ZIndex = 5
      hint.Parent = card
    end
  end

  local order = 1
  sectionHeader("📊 СТАТИСТИКА", C3(160, 230, 220), order); order = order + 1
  statsCard(order); order = order + 1

  sectionHeader("💀 САНС", C3(200, 220, 255), order); order = order + 1
  for _, r in ipairs(REWARDS) do
    if r.boss == "Санс" then
      rewardCard(r, order); order = order + 1
    end
  end

  sectionHeader("👁 ГАСТЕР", C3(220, 180, 255), order); order = order + 1
  for _, r in ipairs(REWARDS) do
    if r.boss == "Гастер" then
      rewardCard(r, order); order = order + 1
    end
  end

  sectionHeader("🏅 ОБЩЕЕ", C3(255, 230, 150), order); order = order + 1
  for _, r in ipairs(REWARDS) do
    if r.boss == "Общее" then
      rewardCard(r, order); order = order + 1
    end
  end

  frame.Size = UDim2.fromOffset(w * 0.9, h * 0.9)
  TS:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.fromOffset(w, h)
  }):Play()
end

function D.open()
  if D.sg and D.sg.Parent then
    destroyUI()
    return true
  end
  buildUI()
  return true
end
function D.close()
  destroyUI()
  return true
end

function D.toggle()
  if D.sg and D.sg.Parent then
    return D.close()
  end
  return D.open()
end

function D.refresh()
  if D.sg and D.sg.Parent then
    buildUI()
  end
end

function D.hasReward(id)
  return hasReward(id)
end

function D.getStats()
  return getStats()
end

-- v25.2: статистика боёв (wins_total, wins_sans, wins_gaster, best_gaster_time,
-- no_death_streak, no_damage_sans, chain)
function D.getBattleStats()
  return getBattleStats()
end

function D.list()
  local out = {}
  for _, r in ipairs(REWARDS) do
    out[#out + 1] = {
      id = r.id, boss = r.boss, name = r.name,
      desc = r.desc, icon = r.icon, hint = r.hint,
      got = hasReward(r.id) and true or false,
    }
  end
  return out
end

function D.destroy()
  destroyUI()
end

ORBIT.rewards = D
ORBIT.loaded.rewards = true
local prevUnload = ORBIT.unload
ORBIT.unload = function()
  pcall(D.destroy)
  if prevUnload then pcall(prevUnload) end
end

if ORBIT.notify then
  ORBIT.notify("🎁 Модуль наград загружен (v25.2: +4 награды, статистика)", C3(220, 200, 255), 3)
end

return true
