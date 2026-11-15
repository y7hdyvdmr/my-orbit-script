-- ============================================================
--  Rick & Morty Toolkit v6.0 — ЧАСТЬ 5/5: ИИ-компьютер Рика (система 25), главная, настройки,
--  диагностика, единый главный цикл и финальный запуск
-- ============================================================
local G = (type(getgenv) == "function" and getgenv()) or _G
local RM = G.RickMorty
local TK = RM and RM._TK
if not TK or not RM._part4 then error("[RickMorty] часть 5 запущена без частей 1–4") end

-- ---------- журнал уведомлений (для ИИ-компьютера) ----------
TK.LOG = {}
do
  local old = TK.notify
  TK.notify = function(text, col, dur)
    TK.LOG[#TK.LOG + 1] = os.date("%H:%M:%S") .. "  " .. tostring(text)
    if #TK.LOG > 30 then table.remove(TK.LOG, 1) end
    return old(text, col, dur)
  end
  RM.notify = TK.notify
end

-- ---------- система 3: Мисиксы (используем помощников V5) ----------
TK.regSys({
  n = 3, name = "Робот-помощник / Mr. Meeseeks", tab = "robots", mode = "visual",
  note = "Помощники V5 (до 3); бьют только твои мишени, игроков не трогают.", keys = "мисикс помощник ящик генератор",
  get = function() return #TK.helpers > 0 end,
  set = function(v) if v then TK.spawnMeeseeks() else RM.helperOrder("vanish") end end,
})

-- ---------- система 25: ИИ-компьютер (центр управления) ----------
local MODE_TXT = {
  visual = "только визуально", test = "только своя тестовая среда", server = "нужна поддержка игры",
}
function TK.sysState(d) -- "ВКЛ" | "ВЫКЛ" | "НЕДОСТУПНО"
  if d.avail then
    local ok, why = d.avail()
    if not ok then return "НЕДОСТУПНО", why end
  end
  local ok, v = pcall(d.get)
  if not ok then return "НЕДОСТУПНО", tostring(v):sub(1, 40) end
  return v and "ВКЛ" or "ВЫКЛ"
end
function TK.sysToggle(d)
  local st, why = TK.sysState(d)
  if st == "НЕДОСТУПНО" then TK.notify("⛔ " .. d.name .. ": " .. (why or "недоступно"), TK.C.dg, 2.5) return end
  local ok, err = pcall(d.set, st ~= "ВКЛ")
  if not ok then TK.notify("⚠ " .. tostring(err):sub(1, 60), TK.C.dg, 3) end
end
TK.regSys({
  n = 25, name = "ИИ-компьютер Рика", tab = "ai", mode = "visual",
  note = "Центр управления остальными системами; сам ничего не меняет в игре.", keys = "ии компьютер центр панель",
  get = function() return TK.win.Visible end, set = function(v) TK.setWin(v) end,
})
table.sort(TK.SYSL, function(a, b) return a.n < b.n end)

TK.TABTITLE = {}
for _, c in ipairs(TK.CATS) do TK.TABTITLE[c[1]] = c[2] end
TK.sect("ai", function(f)
  TK.newSec(f, "СИСТЕМА 25 · ИИ-КОМПЬЮТЕР РИКА")
  TK.newStatus(f, function()
    local on, off, na = 0, 0, 0
    for _, d in ipairs(TK.SYSL) do
      local st = TK.sysState(d)
      if st == "ВКЛ" then on = on + 1 elseif st == "ВЫКЛ" then off = off + 1 else na = na + 1 end
    end
    return string.format("  🧠 Rick AI · Toolkit v%s · графика %s\n  ⚡ %d / %d%s\n  Системы: ✅ %d вкл · ⚪ %d выкл · ⛔ %d недоступно (всего %d)\n  Персонаж: %s · Лицо: %s",
      RM._version, TK.ST.Gfx, math.floor(TK.EN.cur), TK.ST.EnergyMax, TK.enOverloaded() and " ПЕРЕГРУЗКА" or "", on, off, na, #TK.SYSL,
      TK.ST.ActiveSkin ~= "" and TK.SK[TK.ST.ActiveSkin].name or "свой", TK.ST.Emotion)
  end, 76)
  -- быстрые команды
  TK.newSec(f, "БЫСТРЫЕ КОМАНДЫ")
  local q = TK.newGrid(f, 2)
  TK.newBtn(q, "🔥 Портал", TK.C.bg2, function() TK.shootPortal() end, 32)
  TK.newBtn(q, "🔫 Пушка Рика", TK.C.bg2, function() TK.giveItem(TK.itemById("gun_rick")) end, 32)
  TK.newBtn(q, "🚀 Вызвать корабль", TK.C.bg2, TK.summonShip, 32)
  TK.newBtn(q, "🟦 Мисикс", TK.C.bg2, function() TK.spawnMeeseeks() end, 32)
  TK.newBtn(q, "📡 Сканер", TK.C.bg2, TK.scanDo, 32)
  TK.newBtn(q, "⚡ Полная энергия", TK.C.bg2, function() TK.EN.cur = TK.ST.EnergyMax TK.EN.over = 0 end, 32)
  TK.newBtn(q, "🛑 Всё выключить", TK.C.dg, function()
    for _, d in ipairs(TK.SYSL) do
      if d.n ~= 25 and d.n ~= 13 and d.n ~= 10 then
        local st = TK.sysState(d)
        if st == "ВКЛ" then pcall(d.set, false) end
      end
    end
    TK.notify("🛑 Все системы выключены", TK.C.tx, 1.5)
  end, 32)
  TK.newBtn(q, "🧹 Убрать всё", TK.C.dg, function() TK.clearAll() TK.notify("🗑 Всё убрано", TK.C.tx, 1.2) end, 32)
  -- команда текстом
  local box = TK.I("TextBox", {
    Size = UDim2.new(1, -8, 0, 32), BackgroundColor3 = TK.C.bg2, TextColor3 = TK.C.tx, PlaceholderText = "поиск по функциям или команда…",
    PlaceholderColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 12, Text = "", ClearTextOnFocus = false, ZIndex = 42,
  }, f)
  TK.cr(box, 8)
  TK.newSec(f, "СИСТЕМЫ (тап = вкл/выкл, 🔎 = перейти во вкладку)")
  local rows = {}
  for _, d in ipairs(TK.SYSL) do
    local row = TK.I("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, ZIndex = 41 }, f)
    local main = TK.newBtn(row, "", TK.C.bg2, function() TK.sysToggle(d) end, 40)
    main.Size = UDim2.new(1, -46, 1, 0)
    local lbl = TK.I("TextLabel", {
      Size = UDim2.new(1, -78, 0, 14), Position = UDim2.fromOffset(8, 4), BackgroundTransparency = 1, Text = d.n .. ". " .. d.name,
      TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
      TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 43,
    }, main)
    local sub = TK.I("TextLabel", {
      Size = UDim2.new(1, -16, 0, 12), Position = UDim2.fromOffset(8, 22), BackgroundTransparency = 1, Text = "",
      TextColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
      TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 43,
    }, main)
    local stl = TK.I("TextLabel", {
      Size = UDim2.fromOffset(70, 14), Position = UDim2.new(1, -74, 0, 4), BackgroundTransparency = 1, Text = "",
      TextColor3 = TK.C.ok, Font = Enum.Font.GothamBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 43,
    }, main)
    local go = TK.newBtn(row, "🔎", TK.C.st, function()
      if TK.tabFrames[d.tab] then TK.switchTab(d.tab) else TK.notify("Вкладка недоступна", TK.C.dg, 1.5) end
    end, 40)
    go.Size = UDim2.fromOffset(40, 40)
    go.Position = UDim2.new(1, -40, 0, 0)
    go.TextSize = 16
    rows[#rows + 1] = { d = d, row = row, stl = stl, sub = sub, main = main }
  end
  local function paint()
    local q2 = box.Text:lower()
    for _, r in ipairs(rows) do
      local st, why = TK.sysState(r.d)
      r.stl.Text = st
      r.stl.TextColor3 = st == "ВКЛ" and TK.C.ok or (st == "ВЫКЛ" and TK.C.dim or TK.C.dg)
      r.main.BackgroundColor3 = st == "ВКЛ" and TK.C.st or TK.C.bg2
      r.sub.Text = (st == "НЕДОСТУПНО" and ("⛔ " .. tostring(why)) or ("[" .. (MODE_TXT[r.d.mode] or r.d.mode) .. "] " .. r.d.note))
      local hay = (r.d.name .. " " .. (r.d.keys or "") .. " " .. (TK.TABTITLE[r.d.tab] or "")):lower()
      r.row.Visible = q2 == "" or hay:find(q2, 1, true) ~= nil
    end
  end
  box:GetPropertyChangedSignal("Text"):Connect(paint)
  TK.addRefresh(paint)
  paint()
  TK.newSec(f, "ЖУРНАЛ УВЕДОМЛЕНИЙ")
  TK.newStatus(f, function()
    local n = #TK.LOG
    if n == 0 then return "  пусто" end
    local out = {}
    for i = math.max(1, n - 6), n do out[#out + 1] = "  " .. TK.LOG[i] end
    return table.concat(out, "\n")
  end, 110)
  TK.newInfo(f, "\n  Режимы: «только визуально» — картинка на твоём экране,\n  «только своя тестовая среда» — меняет твоего персонажа локально,\n  «нужна поддержка игры» — без серверной части не работает.", 76)
end)

-- ---------- главная ----------
TK.sect("home", function(f)
  TK.newSec(f, "🌀 RICK & MORTY ULTIMATE TOOLKIT v" .. RM._version)
  TK.newStatus(f, function()
    return string.format("  Персонаж: %s\n  Лицо: %s · Скин пушки: %s\n  Порталы: A %s · B %s\n  ⚡ %d / %d · Мисиксов: %d · Корабль: %s",
      TK.ST.ActiveSkin ~= "" and TK.SK[TK.ST.ActiveSkin].name or "свой",
      TK.ST.Emotion, TK.gunSkin().name, TK.PA and "✓" or "—", TK.PB and "✓" or "—",
      math.floor(TK.EN.cur), TK.ST.EnergyMax, #TK.helpers, TK.ship and "вызван" or "нет")
  end, 78)
  TK.newSec(f, "БЫСТРЫЙ СТАРТ")
  local g = TK.newGrid(f, 2)
  TK.newBtn(g, "🎭 Персонажи", TK.C.bg2, function() TK.switchTab("chars") end, 36)
  TK.newBtn(g, "🔫 Пушки", TK.C.bg2, function() TK.switchTab("guns") end, 36)
  TK.newBtn(g, "🧰 Предметы", TK.C.bg2, function() TK.switchTab("items") end, 36)
  TK.newBtn(g, "📟 Гаджеты", TK.C.bg2, function() TK.switchTab("gadgets") end, 36)
  TK.newBtn(g, "🚀 Корабль", TK.C.bg2, function() TK.switchTab("ship") end, 36)
  TK.newBtn(g, "🧠 ИИ Рика", TK.C.ac, function() TK.switchTab("ai") end, 36)
  TK.newBtn(f, "🔥 Открыть портал (куда смотришь)", TK.C.ac, function() TK.shootPortal() end, 38)
  TK.newInfo(f, "\n  Закрытие окна НЕ выгружает Toolkit (🌀 открывает снова).\n  Полная выгрузка: Настройки → ❌.\n  Всё локально: другие игроки ничего этого не видят.", 66)
  if TK.NO_FS then
    TK.newInfo(f, "\n  ⚠ В этом исполнителе нет writefile/readfile:\n  настройки и точки живут только до конца сессии.", 52).TextColor3 = TK.C.dg
  end
end)

-- ---------- настройки ----------
TK.sect("settings", function(f)
  TK.newSec(f, "ЗВУК (только открытие и закрытие портала)")
  TK.newToggle(f, "🔊 Звуки", function() return TK.ST.SoundEnabled end, function(v) TK.ST.SoundEnabled = v TK.save() end)
  TK.newNum(f, "🔓 Громкость открытия", "OpenVol", 10, function() TK.snd("open") end, "%")
  TK.newNum(f, "🔒 Громкость закрытия", "CloseVol", 10, function() TK.snd("close") end, "%")
  TK.newSec(f, "ИНТЕРФЕЙС И ГРАФИКА")
  TK.newToggle(f, "🔔 Уведомления", function() return TK.ST.NotificationsEnabled end, function(v) TK.ST.NotificationsEnabled = v TK.save() end)
  TK.newToggle(f, "🌌 Эффект перехода", function() return TK.ST.DimFx end, function(v) TK.ST.DimFx = v TK.save() end)
  TK.newCycle(f, "🖥 Графика", "Gfx", { "Low", "Medium", "High" }, { Low = "Low (слабый телефон)", Medium = "Medium", High = "High" })
  TK.newNum(f, "🔍 Масштаб окна", "UiScale", 10, function(v) TK.winScale.Scale = v / 100 end, "%")
  TK.newNum(f, "🎯 Размер прицела", "AimSize", 10, function(v) if TK.aimF then TK.aimF.Size = UDim2.fromOffset(v, v) end end)
  TK.newNum(f, "⏱ Длительность уведомлений", "NotifDuration", 1, nil, " с")
  TK.newSec(f, "СБРОС И ВЫХОД")
  TK.newBtn(f, "💾 Сохранить настройки", TK.C.bg2, function() TK.saveAll() TK.notify(TK.HAS_FS and "💾 Сохранено" or "Только в памяти", TK.C.ac, 1.5) end, 32)
  TK.newBtn(f, "🔄 Сбросить все настройки", TK.C.dg, function()
    TK.removeSkin()
    TK.clearAll()
    TK.resetSettings()
    TK.PORTAL_LIFE, TK.PORTAL_R = TK.ST.PortalLife, TK.ST.PortalSize
    TK.winScale.Scale = TK.ST.UiScale / 100
    if TK.aimF then TK.aimF.Size = UDim2.fromOffset(TK.ST.AimSize, TK.ST.AimSize) end
    TK.save()
    TK.runRefresh()
    TK.notify("🔄 Сброшено", TK.C.ok)
  end, 34)
  TK.newBtn(f, "❌ ВЫГРУЗИТЬ SCRIPT ПОЛНОСТЬЮ", TK.C.dg, function() RM.unload() end, 38)
  TK.newInfo(f, "\n  Rick & Morty Toolkit v" .. RM._version .. "\n  9 скинов · 12 лиц · 6 движений · 10 предметов · 25 систем.\n  Всё локально: другие игроки этого не видят.", 76)
end)

-- ---------- диагностика ----------
local function diagText()
  local l = {}
  l[#l + 1] = "  Версия: v" .. RM._version .. " · графика " .. TK.ST.Gfx
  l[#l + 1] = "  Части: " .. (RM._part1 and "1✓" or "1✗") .. " " .. (RM._part2 and "2✓" or "2✗") .. " " .. (RM._part3 and "3✓" or "3✗") .. " " .. (RM._part4 and "4✓" or "4✗") .. " 5✓"
  l[#l + 1] = "  Файлы: " .. (TK.HAS_FS and "writefile есть" or "НЕТ writefile (настройки на сессию)")
  local tabs = 0
  for _ in pairs(TK.tabFrames) do tabs = tabs + 1 end
  l[#l + 1] = "  Вкладок: " .. tabs .. " / " .. #TK.CATS
  l[#l + 1] = "  Систем зарегистрировано: " .. #TK.SYSL .. " / 25"
  local cnt = 0
  pcall(function() cnt = #TK.sysFolder:GetDescendants() end)
  l[#l + 1] = "  Объектов систем: " .. cnt .. " · соединений: " .. #TK.conns
  local bad = {}
  for _, t in ipairs(TK.ticks) do
    if t.dead then bad[#bad + 1] = t.name end
  end
  l[#l + 1] = "  Задач цикла: " .. #TK.ticks .. (#bad > 0 and ("  ⚠ отключены: " .. table.concat(bad, ", ")) or "  (все работают)")
  l[#l + 1] = "  FPS≈ " .. math.floor(TK.fps or 0) .. " · игроков-целей: 0 (по конструкции)"
  return table.concat(l, "\n")
end
TK.sect("diag", function(f)
  TK.newSec(f, "ДИАГНОСТИКА")
  TK.newStatus(f, diagText, 150)
  local res = TK.newInfo(f, "  Нажми «Проверить системы».", 120)
  TK.newBtn(f, "🩺 Проверить все 25 систем", TK.C.ac, function()
    local missing, na = {}, {}
    local have = {}
    for _, d in ipairs(TK.SYSL) do
      have[d.n] = true
      local st, why = TK.sysState(d)
      if st == "НЕДОСТУПНО" then na[#na + 1] = d.n .. " (" .. tostring(why) .. ")" end
      if type(d.set) ~= "function" or not TK.TABTITLE[d.tab] or not TK.tabFrames[d.tab] then missing[#missing + 1] = d.n .. " (нет вкладки/действия)" end
    end
    for i = 1, 25 do if not have[i] then missing[#missing + 1] = i .. " (не зарегистрирована)" end end
    local out = {}
    out[#out + 1] = (#missing == 0) and "  ✅ Все 25 систем зарегистрированы и имеют действие." or ("  ❌ Проблемы: " .. table.concat(missing, "; "))
    out[#out + 1] = (#na == 0) and "  ✅ Недоступных систем нет." or ("  ⛔ Недоступно: " .. table.concat(na, "; "))
    out[#out + 1] = "  Это проверка структуры, а не игровой тест."
    res.Text = table.concat(out, "\n")
  end, 36)
  TK.newBtn(f, "🧹 Аварийная очистка эффектов и устройств", TK.C.dg, function()
    pcall(TK.clearAll)
    pcall(function() TK.sysFolder:ClearAllChildren() end)
    pcall(function() TK.fxFolder:ClearAllChildren() end)
    for id in pairs(TK.padGroups or {}) do TK.padHide(id) end
    TK.notify("🧹 Очищено (устройства могут потребовать повторного включения)", TK.C.tx, 2.5)
  end, 36)
end)

-- ============================================================
--  ЕДИНЫЙ ГЛАВНЫЙ ЦИКЛ
-- ============================================================
TK.fps = 60
do
  local acc, acc2, accUi = 0, 0, 0
  TK.track(TK.RunService.Heartbeat:Connect(function(dt)
    if TK.DEAD then return end
    TK.fps = TK.fps + (1 / math.max(dt, 1e-3) - TK.fps) * .05
    local now = os.clock()
    local _, _, hr = TK.getChar()
    -- мгновенный телепорт при касании портала (только твой персонаж, локально)
    if hr and TK.PA and TK.PB and now >= TK.tpCd and not TK.RIDING then
      local inA, inB = TK.playerInPortal(TK.PA, hr), TK.playerInPortal(TK.PB, hr)
      if not inA then TK.PA.locked = false end
      if not inB then TK.PB.locked = false end
      if now - TK.PA.t0 > .25 and now - TK.PB.t0 > .25 then
        if inA and not TK.PA.locked then TK.teleportTo(hr, TK.PA, TK.PB)
        elseif inB and not TK.PB.locked then TK.teleportTo(hr, TK.PB, TK.PA) end
      end
    end
    acc = acc + dt
    if acc >= .033 then
      acc = 0
      if TK.PA then TK.updPortal(TK.PA, now - TK.PA.t0) end
      if TK.PB then TK.updPortal(TK.PB, now - TK.PB.t0) end
    end
    if TK.PA and now - TK.PA.t0 > TK.PORTAL_LIFE then TK.killPortal(TK.PA) TK.PA = nil end
    if TK.PB and now - TK.PB.t0 > TK.PORTAL_LIFE then TK.killPortal(TK.PB) TK.PB = nil end
    if #TK.DYING > 0 then TK.stepDying(now) end
    if TK.X.shield then TK.ITM.stepShield(now, hr) end
    for i = #TK.helpers, 1, -1 do
      local h = TK.helpers[i]
      local ok, alive = pcall(TK.stepHelper, h, dt)
      if not ok or not alive then
        TK.ITM.vanishFx(h)
        pcall(function() h.R.model:Destroy() end)
        table.remove(TK.helpers, i)
      end
    end
    TK.BAT = math.min(100, TK.BAT + dt * 4)
    acc2 = acc2 + dt
    if acc2 >= .25 then
      acc2 = 0
      TK.updateZones(hr, now)
      TK.ITM.purge()
      TK.ITM.stepHelmet()
      if TK.batLabel and TK.batLabel.Parent then
        TK.batLabel.Text = math.floor(TK.BAT) .. "%"
        TK.batLabel.TextColor3 = TK.BAT < 20 and TK.RGB(255, 90, 90) or (TK.BAT < 50 and TK.RGB(255, 210, 80) or TK.RGB(120, 255, 140))
      end
      TK.ridePanel.Visible = TK.RIDING
      TK.dismountBtn.Visible = TK.RIDING
    end
    -- обновление подписей меню, пока оно открыто
    accUi = accUi + dt
    if accUi >= .5 then
      accUi = 0
      if TK.win.Visible then TK.runRefresh() end
    end
    -- периодические задачи систем (с защитой: 5 ошибок подряд = задача отключена)
    for _, t in ipairs(TK.ticks) do
      if not t.dead then
        t.acc = t.acc + dt
        if t.acc >= t.step then
          local d = t.acc
          t.acc = 0
          local ok, err = pcall(t.fn, d)
          if ok then t.fails = 0 else
            t.fails = t.fails + 1
            if t.fails >= 5 then
              t.dead = true
              warn("[RickMorty] задача «" .. t.name .. "» отключена: " .. tostring(err))
              TK.notify("⚠ Задача " .. t.name .. " отключена (ошибка)", TK.C.dg, 3)
            end
          end
        end
      end
    end
  end))
end

-- ============================================================
--  ФИНАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ
-- ============================================================
for _, c in ipairs(TK.CATS) do
  if not TK.tabFrames[c[1]] then
    TK.regTab(c[1], function(f) TK.newInfo(f, "  Раздел пуст.", 30) end)
  end
end
TK.switchTab("home")
if TK.ST.ActiveSkin ~= "" then
  task.delay(2, function() if not TK.DEAD then TK.safe(TK.applySkin, TK.ST.ActiveSkin) end end)
end
RM._part5 = true
RM._ready = true
RM.systems = TK.SYSL
TK.notify("🌀 Rick & Morty v" .. RM._version .. " загружен", TK.C.ac, 4)
if TK.NO_FS then TK.notify("⚠ Нет файловых функций: настройки не сохранятся", TK.C.dg, 5) end
if TK.MIGRATED then TK.notify("♻ Подхвачены настройки старой версии", TK.C.ac3, 3) end
warn("[RickMorty v" .. RM._version .. "] загружен. Систем: " .. #TK.SYSL .. ". Прицел: " .. (TK.mob and "мобильный" or "ПК"))
return RM
