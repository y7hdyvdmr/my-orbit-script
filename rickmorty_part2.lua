-- Rick & Morty Toolkit v5.0 — ЧАСТЬ 2 (вкладки, главный цикл, запуск)
local G = rawget(_G, "getgenv") and getgenv() or _G
local RM = G.RickMorty
local TK = RM and RM._TK
if not TK then error("[RickMorty] часть 2 запущена без части 1") end

-- ============================================================
--  ВКЛАДКИ: наполнение
-- ============================================================
do -- 🎭 СКИНЫ
  local f = TK.tabFrames.skins
  TK.newSec(f, "ЗАМЕНА ТЕЛА (Motor6D, 8 скинов)")
  for _, id in ipairs(TK.SKIN_ORDER) do
    local S = TK.SK[id]
    local b = TK.newBtn(f, "", TK.C.bg2, function() TK.applySkin(id) end, 40)
    TK.X.skinBtns = TK.X.skinBtns or {}
    TK.X.skinBtns[id] = b
    TK.I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
      Text = S.ico .. " " .. S.name, TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 11,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
    TK.I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 22), BackgroundTransparency = 1,
      Text = S.desc, TextColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 9,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
  end
  TK.newInfo(f, "  Копирование аватара игроков теперь отдельный скрипт (Avatar Copier).", 30)
  TK.newSec(f, "ВЫРАЖЕНИЕ ЛИЦА")
  local gr = TK.newGrid(f, 3)
  for _, e in ipairs(TK.EM) do
    TK.newBtn(gr, e[2], TK.C.bg2, function() TK.setEmo(e[1]) end, 32).TextSize = 11
  end
  TK.newBtn(f, "↩ Вернуть своё тело", TK.C.bg2, TK.removeSkin, 34).TextColor3 = TK.C.dg
end

do -- 🕺 ДВИЖЕНИЯ
  local f = TK.tabFrames.moves
  TK.newSec(f, "ЭМОЦИИ ТЕЛА (стой на месте)")
  local gr = TK.newGrid(f, 2)
  local EMS = {
    { "wave", "👋 Махать" }, { "dance", "🕺 Танец" }, { "drunk", "🥴 Пьяная походка" },
    { "think", "🤔 Думать" }, { "victory", "🙌 Победа" }, { "facepalm", "🤦 Фейспалм" },
  }
  for _, e in ipairs(EMS) do
    TK.newBtn(gr, e[2], TK.C.bg2, function()
      if not TK.RIG then TK.notify("Сначала надень скин", TK.C.dg, 2) return end
      TK.EMOTE = e[1]
    end, 34)
  end
  TK.newBtn(f, "⏹ Остановить движение", TK.C.bg2, function() TK.EMOTE = nil end, 32)
  TK.newSec(f, "РЕПЛИКИ (пузырь над головой)")
  local pg = TK.newGrid(f, 2)
  local PHR = {
    "Wubba lubba dub dub!", "И вот так, Морти!", "Aw jeez, Рик!", "Я Мистер Мисикс!",
    "Быстрее, в портал!", "Это не сон, это физика.",
  }
  for _, p in ipairs(PHR) do
    TK.newBtn(pg, p, TK.C.bg2, function() TK.say(p) end, 38).TextSize = 10
  end
  TK.newInfo(f, "\n  Ходьба, бег, прыжок, посадка в крейсер,\n  хват предмета и моргание включены всегда.\n  Эмоция тела сбрасывается, когда начинаешь идти.", 70)
end

do -- 🧰 ПРЕДМЕТЫ
  local f = TK.tabFrames.items
  TK.newSec(f, "ПРЕДМЕТЫ (держатся рукой скина)")
  for _, def in ipairs(TK.ITEMS) do
    local b = TK.newBtn(f, "", TK.C.bg2, function() TK.giveItem(def) end, 40)
    TK.I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1,
      Text = def.ico .. " " .. def.name, TextColor3 = TK.C.tx, Font = Enum.Font.GothamBold, TextSize = 11,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
    TK.I("TextLabel", {
      Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 22), BackgroundTransparency = 1,
      Text = def.desc, TextColor3 = TK.C.dim, Font = Enum.Font.Gotham, TextSize = 9,
      TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 43,
    }, b)
  end
  TK.newSec(f, "ПРИКАЗЫ МИСИКСАМ (идут туда, куда смотришь)")
  local og = TK.newGrid(f, 2)
  TK.newBtn(og, "🛡 Защищай меня", TK.C.ac, function() RM.helperOrder("guard") end, 36)
  TK.newBtn(og, "⚔ Атакуй цель", TK.C.bg2, function() RM.helperOrder("attack") end, 36)
  TK.newBtn(og, "📍 Иди туда", TK.C.bg2, function() RM.helperOrder("move") end, 36)
  TK.newBtn(og, "🚶 За мной", TK.C.bg2, function() RM.helperOrder("follow") end, 36)
  TK.newBtn(og, "🛑 Стой", TK.C.bg2, function() RM.helperOrder("stay") end, 36)
  TK.newBtn(og, "💨 Исчезни", TK.C.dg, function() RM.helperOrder("vanish") end, 36)
  local pvp
  pvp = TK.newBtn(f, "👥 Бить игроков (только визуально): " .. (TK.ST.AttackPlayers and "ВКЛ" or "ВЫКЛ"), TK.C.bg2, function()
    TK.ST.AttackPlayers = not TK.ST.AttackPlayers
    pvp.Text = "👥 Бить игроков (только визуально): " .. (TK.ST.AttackPlayers and "ВКЛ" or "ВЫКЛ")
    TK.save()
  end, 36)
  TK.newBtn(f, "🎯 Поставить мишень (куда смотришь)", TK.C.bg2, function() RM.spawnDummy() end, 34)
  TK.newBtn(f, "🗑 Убрать мишени", TK.C.bg2, function() RM.clearDummies() end, 34)
  TK.newSec(f, "КРЕЙСЕР")
  TK.newSlider(f, "🚀 Скорость корабля", 50, 1000, TK.ST.ShipSpeed, function(v) TK.ST.ShipSpeed = v end, TK.save)
  TK.newBtn(f, "🚀 Вызвать крейсер", TK.C.ac, TK.summonShip, 36)
  TK.newBtn(f, "🪑 Сесть", TK.C.bg2, TK.board, 34)
  TK.newBtn(f, "🚪 Слезть", TK.C.bg2, TK.dismount, 34)
  TK.newBtn(f, "🗑 Убрать всё (предметы, помощники, крейсер)", TK.C.dg, function()
    TK.clearAll()
    TK.notify("🗑 Всё убрано", TK.C.tx)
  end, 36)
  TK.newInfo(f, "\n  Предметы сохраняются в рюкзаке; экипируй нужный и нажми ЛКМ или 🔥.\n  Ящик Мисиксов: помощник бежит к точке прицела.\n  Батарея: зона энергии, расход 25% заряда.\n  Крейсер: тап по нему сажает. 🔥 огонь, 🌌 прыжок.\n  Всё видишь только ты.", 100)
end

do -- 🌀 ПОРТАЛ
  local f = TK.tabFrames.portal
  TK.newSec(f, "ПОРТАЛЬНЫЕ ПУШКИ (НЕ ЗАВИСЯТ ОТ СКИНА)")
  TK.newBtn(f, "🔫 Портальная пушка Рика", TK.C.ac, function() TK.giveItem(TK.ITEMS[1]) end, 40)
  TK.newBtn(f, "🔫 Портальная пушка Рика Прайма", TK.C.bg2, function() TK.giveItem(TK.ITEMS[2]) end, 40)
  TK.newBtn(f, "🔫 Портальная пушка Злого Морти", TK.C.bg2, function() TK.giveItem(TK.ITEMS[3]) end, 40)
  TK.newBtn(f, "🔥 Создать портал", TK.C.bg2, TK.shootPortal, 40)
  TK.newBtn(f, "🗑 Удалить оба портала", TK.C.dg, function()
    TK.killPortal(TK.PA)
    TK.killPortal(TK.PB)
    TK.PA, TK.PB = nil, nil
    TK.notify("🗑 Порталы удалены", TK.C.tx)
  end, 34)
  TK.newBtn(f, "🌌 Тест эффекта перехода", TK.C.bg2, function() TK.dimFx(nil, 1) end, 34)
  TK.newSec(f, "КАК РАБОТАЕТ")
  TK.newInfo(f, "\n  Портал большой (диаметр 12 стадов).\n  Коснулся любой части портала — телепорт сразу.\n  1-й выстрел — A, 2-й — B, дальше заменяется старый.\n  Выходной портал не сработает, пока ты из него не выйдешь.\n  Порталы исчезают через 60 с.", 108)
end

do -- ⚙️ НАСТРОЙКИ
  local f = TK.tabFrames.settings
  TK.newSec(f, "ЗВУК")
  local sb
  sb = TK.newBtn(f, "🔊 Звуки: " .. (TK.ST.SoundEnabled and "ВКЛ" or "ВЫКЛ"), TK.C.bg2, function()
    TK.ST.SoundEnabled = not TK.ST.SoundEnabled
    sb.Text = "🔊 Звуки: " .. (TK.ST.SoundEnabled and "ВКЛ" or "ВЫКЛ")
    TK.save()
  end, 32)
  TK.newSec(f, "ЭФФЕКТ ПЕРЕХОДА")
  local fb
  fb = TK.newBtn(f, "🌌 Эффект: " .. (TK.ST.DimFx and "ВКЛ" or "ВЫКЛ"), TK.C.bg2, function()
    TK.ST.DimFx = not TK.ST.DimFx
    fb.Text = "🌌 Эффект: " .. (TK.ST.DimFx and "ВКЛ" or "ВЫКЛ")
    TK.save()
  end, 32)
  TK.newSec(f, "ЦВЕТ ПОРТАЛОВ")
  local PC = {
    { "🟢 Зелёный", { R = 50, G = 255, B = 50 } }, { "🔵 Синий", { R = 50, G = 150, B = 255 } },
    { "🟣 Фиолет", { R = 180, G = 50, B = 255 } }, { "🟡 Жёлтый", { R = 255, G = 220, B = 50 } },
    { "🔴 Красный", { R = 255, G = 60, B = 60 } },
  }
  local pi = 1
  for i, p in ipairs(PC) do
    if p[2].R == TK.ST.PortalColor.R and p[2].G == TK.ST.PortalColor.G then pi = i break end
  end
  local pb
  pb = TK.newBtn(f, "🎨 " .. PC[pi][1], TK.C.bg2, function()
    pi = pi % #PC + 1
    TK.ST.PortalColor = PC[pi][2]
    pb.Text = "🎨 " .. PC[pi][1]
    TK.save()
    TK.notify("🎨 Цвет изменён", TK.C.ac)
  end, 32)
  TK.newSec(f, "ПРИЦЕЛ")
  local AS = { 50, 64, 80, 100 }
  local ai = 1
  for i, v in ipairs(AS) do
    if v == TK.ST.AimSize then ai = i break end
  end
  local ab
  ab = TK.newBtn(f, "🎯 Размер прицела: " .. TK.ST.AimSize, TK.C.bg2, function()
    ai = ai % #AS + 1
    TK.ST.AimSize = AS[ai]
    ab.Text = "🎯 Размер прицела: " .. TK.ST.AimSize
    TK.aimF.Size = UDim2.fromOffset(TK.ST.AimSize, TK.ST.AimSize)
    TK.save()
  end, 32)
  TK.newSec(f, "СБРОС")
  TK.newBtn(f, "🔄 Сбросить всё", TK.C.dg, function()
    TK.removeSkin()
    TK.clearAll()
    TK.resetSettings()
    sb.Text = "🔊 Звуки: ВКЛ"
    fb.Text = "🌌 Эффект: ВКЛ"
    pi, ai = 1, 2
    if TK.setWin then TK.ST.MenuKey = TK.DEFAULTS.MenuKey end
    pb.Text = "🎨 " .. PC[1][1]
    ab.Text = "🎯 Размер прицела: 64"
    TK.aimF.Size = UDim2.fromOffset(64, 64)
    TK.save()
    TK.notify("🔄 Сброшено", TK.C.ok)
  end, 34)
  TK.newSec(f, "ВЫХОД")
  TK.newBtn(f, "❌ ВЫГРУЗИТЬ СКРИПТ", TK.C.dg, function() RM.unload() end, 36)
  TK.newSec(f, "О СКРИПТЕ")
  TK.newInfo(f, "\n  Rick & Morty Toolkit v" .. RM._version .. "\n  8 скинов, 12 лиц, 6 эмоций тела, 10 предметов.\n  Всё локально: другие игроки этого не видят.", 80)
end
TK.switchTab("skins")

-- ============================================================
--  ГЛАВНЫЙ ЦИКЛ: телепорт, порталы, помощники, батарея
-- ============================================================
do
  local acc, acc2 = 0, 0
  TK.track(TK.RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    local _, _, hr = TK.getChar()
    -- мгновенный телепорт при касании портала
    if hr and TK.PA and TK.PB and now >= TK.tpCd and not TK.RIDING then
      local inA, inB = TK.playerInPortal(TK.PA, hr), TK.playerInPortal(TK.PB, hr)
      if not inA then TK.PA.locked = false end
      if not inB then TK.PB.locked = false end
      if now - TK.PA.t0 > .25 and now - TK.PB.t0 > .25 then
        if inA and not TK.PA.locked then
          TK.teleportTo(hr, TK.PA, TK.PB)
        elseif inB and not TK.PB.locked then
          TK.teleportTo(hr, TK.PB, TK.PA)
        end
      end
    end
    -- визуал порталов ~30 Гц и срок жизни
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
    -- помощники Мисиксы
    for i = #TK.helpers, 1, -1 do
      local h = TK.helpers[i]
      local ok, alive = pcall(TK.stepHelper, h, dt)
      if not ok or not alive then
        TK.ITM.vanishFx(h)
        pcall(function() h.R.model:Destroy() end)
        table.remove(TK.helpers, i)
      end
    end
    -- батарея: заряд растёт, зоны проверяются 4 раза в секунду
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
      if TK.X.skinBtns then
        for id, b in pairs(TK.X.skinBtns) do
          local on = TK.ST.ActiveSkin == id
          b.BackgroundColor3 = on and TK.C.st or TK.C.bg2
        end
      end
      TK.ridePanel.Visible = TK.RIDING
      TK.dismountBtn.Visible = TK.RIDING
    end
  end))
end

if TK.ST.ActiveSkin ~= "" then
  task.delay(2, function() if not TK.DEAD then TK.safe(TK.applySkin, TK.ST.ActiveSkin) end end)
end
TK.notify("🌀 Rick & Morty v" .. RM._version .. " загружен", TK.C.ac, 4)
warn("[RickMorty v" .. RM._version .. "] загружен. Прицел: " .. (TK.mob and "мобильный" or "ПК"))
return RM
