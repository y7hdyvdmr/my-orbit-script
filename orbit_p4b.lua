-- ORBIT v24.2 | orbit_p4b.lua
-- Вторая половина UI: обработчики кнопок, крестики стихий, меню фраз Санса,
-- «Мои фигуры», «Импорт фигуры», палитра, FPS-цикл, API.
-- v24.2-fix1: убран дублирующий fetchRun (shop/minigame грузит только loader);
--             ORBIT.start оборачивает предыдущий обработчик через prevStart;
--             NB.applyStyle включает кольца через ORBIT.setRingEnabled.
local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P4b] P1 не загружен"); return end
if ORBIT.P4b and ORBIT.P4b.ready then warn("[Orbit P4b] уже загружен"); return end
local P4 = ORBIT.P4
if not P4 then warn("[Orbit P4b] orbit_p4.lua не загружен"); return end

local NB            = P4.NB
local onClick       = P4.onClick
local screenGui     = P4.screenGui
local window        = P4.window
local panel         = P4.panel
local searchBox     = P4.searchBox
local panelCloseBtn = P4.panelCloseBtn
local mainBtn       = P4.mainBtn
local topBar        = P4.topBar
local UIK           = P4.UIK
local setTab        = P4.setTab
local relayout      = P4.relayout
local IS_MOBILE     = P4.IS_MOBILE
local BTN_H         = P4.BTN_H
local BTN_H_BIG     = P4.BTN_H_BIG
local S_STEP        = P4.S_STEP
local TweenService  = P4.TweenService
local UIS           = P4.UIS
local Players       = P4.Players
local LocalPlayer   = P4.LocalPlayer
local P             = P4.P
local rings         = P4.rings
local SETTINGS      = P4.SETTINGS
local SHAPE_PRESETS = P4.SHAPE_PRESETS

-- ============================================================
--       ОТКРЫТИЕ / ЗАКРЫТИЕ ПАНЕЛИ
-- ============================================================
NB.panelOpen = false
NB.dragMoved = false
NB.panelScale = Instance.new("UIScale")
NB.panelScale.Parent = window

NB.setPanel = function(open)
    NB.panelOpen = open
    if open then
        local abs = screenGui.AbsoluteSize
        local w = math.min(P4.PANEL_W, abs.X - 16)
        local h = math.clamp(abs.Y - 40, 220, IS_MOBILE and 560 or 780)
        window.Size = UDim2.fromOffset(w, h)
        window.Position = UDim2.fromOffset(
            math.clamp(mainBtn.Position.X.Offset + (IS_MOBILE and 72 or 70), 4, math.max(4, abs.X - w - 8)),
            math.clamp(math.floor((abs.Y - h) / 2), 4, math.max(4, abs.Y - h - 4)))
        NB.panelScale.Scale = 0.88
        window.Visible = true
        TweenService:Create(NB.panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
        relayout()
    else
        TweenService:Create(NB.panelScale, TweenInfo.new(0.12), { Scale = 0.88 }):Play()
        task.delay(0.13, function()
            if not NB.panelOpen then window.Visible = false end
        end)
    end
end

onClick(mainBtn, function()
    if NB.dragMoved then NB.dragMoved = false; return end
    NB.setPanel(not NB.panelOpen)
end)
onClick(panelCloseBtn, function() NB.setPanel(false) end)

-- ============================================================
--       ХЕЛПЕР: КНОПКИ КОЛЕЦ
-- ============================================================
NB.ringButtons = { [2]=NB.btn.ring2, [3]=NB.btn.ring3, [4]=NB.btn.ring4, [5]=NB.btn.ring5 }

NB.refreshRingButton = function(ri)
    local b = NB.ringButtons[ri]; if not b then return end
    if rings[ri].enabled then
        b.Text = "➖ Кольцо " .. ri
        b.BackgroundColor3 = Color3.fromRGB(55,40,40); b.TextColor3 = Color3.fromRGB(255,160,160)
    else
        b.Text = "➕ Кольцо " .. ri
        b.BackgroundColor3 = Color3.fromRGB(40,55,40); b.TextColor3 = Color3.fromRGB(160,255,160)
    end
end

-- ============================================================
--       ГЛАВНЫЙ ТУМБЛЕР + СТАТИСТИКА
-- ============================================================
onClick(NB.btn.toggle, function()
    ORBIT.setEnabled(not ORBIT.enabled)
    if ORBIT.enabled then
        NB.btn.toggle.Text = "🟢 ВКЛЮЧЕНО"; NB.btn.toggle.TextColor3 = Color3.fromRGB(0,255,120); NB.btn.toggle.BackgroundColor3 = Color3.fromRGB(40,50,40)
    else
        NB.btn.toggle.Text = "🔴 ВЫКЛЮЧЕНО"; NB.btn.toggle.TextColor3 = Color3.fromRGB(255,80,80); NB.btn.toggle.BackgroundColor3 = Color3.fromRGB(50,35,40)
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if NB.lbl.stats and NB.lbl.stats.Parent and ORBIT.SESSION then
            local s = ORBIT.SESSION
            local elapsed = tick() - (s.startTime or tick())
            local mins = math.floor(elapsed / 60)
            local secs = math.floor(elapsed % 60)
            local ringTargets = 0; for _ in pairs(ORBIT.targetRings or {}) do ringTargets = ringTargets + 1 end
            local savesCount = 0; for _ in pairs(ORBIT.SAVES or {}) do savesCount = savesCount + 1 end
            NB.lbl.stats.Text = string.format(
                "🎁 Ботов: %d  |  🚩 Читеров: %d\n🥷 Уворотов: %d\n🛡️ Защит: %d\n🎯 Колец на людях: %d  |  💾 Сохр: %d\n⏱️ %d:%02d",
                s.botsCollected or 0, s.cheatersTagged or 0,
                s.dodgesMade or 0, s.protectionsTriggered or 0,
                ringTargets, savesCount, mins, secs)
        end
    end
end)

onClick(NB.btn.resetSession, function()
    if ORBIT.SESSION then
        ORBIT.SESSION.botsCollected = 0
        ORBIT.SESSION.cheatersTagged = 0
        ORBIT.SESSION.dodgesMade = 0
        ORBIT.SESSION.protectionsTriggered = 0
        ORBIT.SESSION.startTime = tick()
        ORBIT.notify("📊 Статистика сброшена", Color3.fromRGB(180,220,255), 2)
    end
end)

-- ============================================================
--       ESP
-- ============================================================
onClick(NB.btn.esp, function()
    if ORBIT.setESPEnabled then
        ORBIT.setESPEnabled(not ORBIT.ESP.Enabled)
        NB.btn.esp.Text = "👁️ ESP игроков: " .. (ORBIT.ESP.Enabled and "ВКЛ" or "ВЫКЛ")
        if ORBIT.ESP.Enabled then
            NB.btn.esp.BackgroundColor3 = Color3.fromRGB(40,80,60)
            NB.btn.esp.TextColor3 = Color3.fromRGB(180,255,200)
        else
            NB.btn.esp.BackgroundColor3 = Color3.fromRGB(50,60,90)
            NB.btn.esp.TextColor3 = Color3.fromRGB(200,220,255)
        end
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if NB.btn.taggedCount and ORBIT.getTaggedPlayers then
            NB.btn.taggedCount.Text = "⭐ Список читеров: " .. #ORBIT.getTaggedPlayers()
        end
    end
end)

-- ============================================================
--       СПИСОК ИГРОКОВ
-- ============================================================
NB.rebuildPeopleList = function()
    local list = ORBIT.getPlayerList and ORBIT.getPlayerList() or {}
    local sigParts = {}
    for _, info in ipairs(list) do
        sigParts[#sigParts + 1] = info.name .. (info.hasRing and "1" or "0") .. (info.isTagged and "1" or "0")
    end
    local sig = table.concat(sigParts, "|")
    if sig == NB.peopleSig then return end
    NB.peopleSig = sig
    for _, ch in ipairs(NB.scroll.people:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    if #list == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -6, 0, 24); empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140, 130, 170)
        empty.Font = Enum.Font.Gotham; empty.TextSize = 11; empty.LayoutOrder = 1
        empty.Parent = NB.scroll.people
        return
    end
    for i, info in ipairs(list) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 52)
        row.BackgroundColor3 = Color3.fromRGB(28, 22, 45)
        row.BorderSizePixel = 0; row.LayoutOrder = i
        row.Parent = NB.scroll.people
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -8, 0, 18); nameLbl.Position = UDim2.new(0, 6, 0, 2)
        nameLbl.BackgroundTransparency = 1; nameLbl.Text = "👤 " .. info.name
        nameLbl.TextColor3 = Color3.fromRGB(230, 220, 255)
        nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local btnRow = Instance.new("Frame")
        btnRow.Size = UDim2.new(1, -8, 0, 24); btnRow.Position = UDim2.new(0, 4, 0, 22)
        btnRow.BackgroundTransparency = 1; btnRow.Parent = row

        local ringB = Instance.new("TextButton")
        ringB.Size = UDim2.new(0.5, -2, 1, 0)
        if info.hasRing then
            ringB.Text = "➖ Убрать"
            ringB.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            ringB.TextColor3 = Color3.fromRGB(255, 160, 160)
        else
            ringB.Text = "➕ Полное кольцо"
            ringB.BackgroundColor3 = Color3.fromRGB(40, 70, 45)
            ringB.TextColor3 = Color3.fromRGB(160, 255, 180)
        end
        ringB.Font = Enum.Font.GothamBold; ringB.TextSize = 10; ringB.Parent = btnRow
        Instance.new("UICorner", ringB).CornerRadius = UDim.new(0, 5)

        local tagB = Instance.new("TextButton")
        tagB.Size = UDim2.new(0.5, -2, 1, 0); tagB.Position = UDim2.new(0.5, 2, 0, 0)
        if info.isTagged then
            tagB.Text = "✅ Снять метку"
            tagB.BackgroundColor3 = Color3.fromRGB(60, 40, 50)
            tagB.TextColor3 = Color3.fromRGB(220, 200, 220)
        else
            tagB.Text = "🚩 Читер"
            tagB.BackgroundColor3 = Color3.fromRGB(80, 30, 55)
            tagB.TextColor3 = Color3.fromRGB(255, 150, 200)
        end
        tagB.Font = Enum.Font.GothamBold; tagB.TextSize = 10; tagB.Parent = btnRow
        Instance.new("UICorner", tagB).CornerRadius = UDim.new(0, 5)

        onClick(ringB, function()
            if ORBIT.toggleTargetRings then ORBIT.toggleTargetRings(info.player) end
            task.delay(0.1, NB.rebuildPeopleList)
        end)
        onClick(tagB, function()
            if ORBIT.toggleTagCheater then ORBIT.toggleTagCheater(info.player) end
            task.delay(0.1, NB.rebuildPeopleList)
        end)
    end
end
NB.rebuildPeopleList()

onClick(NB.btn.refreshPeople, function()
    NB.peopleSig = nil
    NB.rebuildPeopleList()
    NB.btn.refreshPeople.Text = "✅ Обновлено"
    task.wait(0.8)
    NB.btn.refreshPeople.Text = "🔄 Обновить список игроков"
end)

onClick(NB.btn.addAllRings, function() if ORBIT.addRingsToAll then ORBIT.addRingsToAll() end; task.wait(0.2); NB.rebuildPeopleList() end)
onClick(NB.btn.remAllRings, function() if ORBIT.removeRingsFromAll then ORBIT.removeRingsFromAll() end; task.wait(0.2); NB.rebuildPeopleList() end)
onClick(NB.btn.toggleAllRings, function() if ORBIT.toggleAllRings then ORBIT.toggleAllRings() end; task.wait(0.2); NB.rebuildPeopleList() end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(4)
        if window.Visible then pcall(NB.rebuildPeopleList) end
    end
end)
UIK.connect(Players.PlayerAdded, function(p) if p ~= LocalPlayer then task.wait(0.5); pcall(NB.rebuildPeopleList) end end)
UIK.connect(Players.PlayerRemoving, function(p) if p ~= LocalPlayer then task.wait(0.3); pcall(NB.rebuildPeopleList) end end)

-- ============================================================
--       БОТЫ
-- ============================================================
onClick(NB.btn.botNear, function() if ORBIT.createBotNear then ORBIT.createBotNear() end end)
onClick(NB.btn.botCreate5, function() ORBIT.createMultipleBots(5) end)
onClick(NB.btn.botCreate25, function() ORBIT.createManyBots(25) end)
onClick(NB.btn.botCreate100, function() ORBIT.createManyBots(100) end)
onClick(NB.btn.botRemoveAll, function() ORBIT.removeAllBots() end)
onClick(NB.btn.botAutoCollect, function()
    ORBIT.botSettings.AutoCollect = not ORBIT.botSettings.AutoCollect
    NB.btn.botAutoCollect.Text = "🎁 Автосбор: " .. (ORBIT.botSettings.AutoCollect and "ВКЛ" or "ВЫКЛ")
end)
onClick(NB.btn.botRadius, function()
    local steps = {6, 8, 10, 12, 15, 20, 25}
    local idx = 1
    for i, v in ipairs(steps) do if v == ORBIT.botSettings.CollectRadius then idx = i; break end end
    ORBIT.botSettings.CollectRadius = steps[(idx % #steps) + 1]
    NB.btn.botRadius.Text = "📏 Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st"
end)
onClick(NB.btn.botShowRing, function()
    ORBIT.botSettings.ShowPlayerRing = not ORBIT.botSettings.ShowPlayerRing
    NB.btn.botShowRing.Text = "👤 Кольцо как у игрока: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ")
    ORBIT.notify("👤 Кольцо ботов: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200,180,255), 2)
end)
onClick(NB.btn.botSkin, function()
    ORBIT.botSettings.UseMySkin = not ORBIT.botSettings.UseMySkin
    NB.btn.botSkin.Text = "🎭 Скин как у меня: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ")
    ORBIT.botAvatarTemplate = nil
    ORBIT.notify("🎭 Скин бота: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200, 180, 255), 2)
end)
if ORBIT.botSettings.UseMySkin then NB.btn.botSkin.Text = "🎭 Скин как у меня: ВКЛ" end
if ORBIT.botSettings.ShowPlayerRing then NB.btn.botShowRing.Text = "👤 Кольцо как у игрока: ВКЛ" end

-- ============================================================
--       КОЛЬЦА
-- ============================================================
onClick(NB.btn.allRings, function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local ns = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= ns then ORBIT.setRingEnabled(ri, ns) end end
    for ri = 2, 5 do NB.refreshRingButton(ri) end
    NB.btn.allRings.Text = ns and "⭕ Все кольца: ВЫКЛ" or "⭕ Все кольца: ВКЛ"
end)
for ri, b in pairs(NB.ringButtons) do
    onClick(b, function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); NB.refreshRingButton(ri) end)
end

-- ============================================================
--       ВНЕШНИЙ ВИД
-- ============================================================
onClick(NB.btn.shapeCat, function()
    P.shapeCategoryIndex = P.shapeCategoryIndex + 1
    if P.shapeCategoryIndex > #P.SHAPE_CATEGORIES then P.shapeCategoryIndex = 1 end
    NB.btn.shapeCat.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs > 0 then
        ORBIT.shapeIndex = idxs[1]
        NB.btn.shape.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.applyShapes(); ORBIT.rebuildAllRings()
    end
end)
onClick(NB.btn.shape, function()
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs == 0 then return end
    local pos = nil
    for i, v in ipairs(idxs) do if v == ORBIT.shapeIndex then pos = i; break end end
    local newPos = pos and (pos % #idxs) + 1 or 1
    ORBIT.shapeIndex = idxs[newPos]
    NB.btn.shape.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)

-- «Мои фигуры» — открывает магазин на категории СВОИ
onClick(NB.btn.myFigs, function()
    if ORBIT.openShop then
        ORBIT.openShop()
        ORBIT.notify("🖼️ Категория «СВОИ» — листай до конца", Color3.fromRGB(220, 200, 255), 3)
    else
        ORBIT.notify("❌ Модуль магазина не загружен", Color3.fromRGB(255,150,150), 3)
    end
end)
-- «Импорт фигуры» — открывает панель SHARE
onClick(NB.btn.importFig, function()
    if ORBIT.share and ORBIT.share.open then
        ORBIT.share.open()
        ORBIT.notify("📥 Вставь строку и нажми ИМПОРТ", Color3.fromRGB(200, 230, 255), 3)
    else
        ORBIT.notify("❌ Модуль SHARE не загружен", Color3.fromRGB(255,150,150), 3)
    end
end)

onClick(NB.btn.shapeMode, function()
    P.formModeIndex = P.formModeIndex + 1; if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    NB.btn.shapeMode.Text = "🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
onClick(NB.btn.shapeSize, function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1; if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
    NB.btn.shapeSize.Text = "🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    ORBIT.rebuildAllRings()
end)
onClick(NB.btn.gradient, function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    NB.btn.gradient.Text = "🌈 Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then SETTINGS.Rainbow = false end
    ORBIT.rebuildAllRings()
end)
onClick(NB.btn.light, function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    NB.btn.light.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
onClick(NB.btn.nameBtn, function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    NB.btn.nameBtn.Text = "🏷️ Имена блоков: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    ORBIT.applyNameVisibility()
end)
onClick(NB.btn.autoSwap, function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    NB.btn.autoSwap.Text = "🎭 Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then ORBIT.lastAutoSwap = tick() end
end)

-- ============================================================
--       ДВИЖЕНИЕ
-- ============================================================
onClick(NB.btn.orbit, function()
    P.orbitIndex = P.orbitIndex + 1; if P.orbitIndex > #P.ORBIT then P.orbitIndex = 1 end
    NB.btn.orbit.Text = "📏 Орбита: " .. P.ORBIT[P.orbitIndex].name
end)
onClick(NB.btn.spread, function()
    P.spreadIndex = P.spreadIndex + 1; if P.spreadIndex > #P.SPREAD then P.spreadIndex = 1 end
    NB.btn.spread.Text = "📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name
end)
onClick(NB.btn.height, function()
    P.heightIndex = P.heightIndex + 1; if P.heightIndex > #P.HEIGHT then P.heightIndex = 1 end
    NB.btn.height.Text = "⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name
end)
onClick(NB.btn.speed, function()
    P.speedIndex = P.speedIndex + 1; if P.speedIndex > #P.SPEED then P.speedIndex = 1 end
    SETTINGS.SpeedMultiplier = P.SPEED[P.speedIndex].value
    NB.btn.speed.Text = "⚡ Множитель: " .. P.SPEED[P.speedIndex].name
end)
onClick(NB.btn.speedMode, function()
    P.speedModeIndex = P.speedModeIndex + 1; if P.speedModeIndex > #P.SPEED_MODE then P.speedModeIndex = 1 end
    NB.btn.speedMode.Text = "⚙️ Режим: " .. P.SPEED_MODE[P.speedModeIndex].name
    ORBIT.applySpeedModePreset()
end)
onClick(NB.btn.direction, function()
    P.directionIndex = P.directionIndex + 1; if P.directionIndex > #P.DIRECTION then P.directionIndex = 1 end
    NB.btn.direction.Text = "🔃 Направление: " .. P.DIRECTION[P.directionIndex].name
    ORBIT.applyDirectionPreset()
end)
onClick(NB.btn.orbitPattern, function()
    P.orbitPatternIndex = P.orbitPatternIndex + 1
    if P.orbitPatternIndex > #P.ORBIT_PATTERNS then P.orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name
    NB.btn.orbitPattern.Text = "🌀 Узор: " .. SETTINGS.OrbitPattern
end)

-- ============================================================
--       КРУЧЕНИЕ
-- ============================================================
onClick(NB.btn.spin, function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    NB.btn.spin.Text = ORBIT.spinResetting and "↩️ Вращение: ВОЗВРАТ" or "↩️ Вращение в 0"
end)
onClick(NB.btn.spinAxis, function()
    ORBIT.spinAxisEnabled = not ORBIT.spinAxisEnabled
    NB.btn.spinAxis.Text = "🔄 Кручение оси: " .. (ORBIT.spinAxisEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(NB.btn.spinDir, function()
    if ORBIT.spinAxisDir == "X" then
        ORBIT.spinAxisDir = "Y"; NB.btn.spinDir.Text = "↔️ Ось: ВЛЕВО/ВПРАВО"
    else
        ORBIT.spinAxisDir = "X"; NB.btn.spinDir.Text = "↕️ Ось: ВЕРХ/ВНИЗ"
    end
end)
onClick(NB.btn.spinSpeed, function()
    P.spinSpeedIndex = P.spinSpeedIndex + 1; if P.spinSpeedIndex > #P.SPIN_SPEED then P.spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value
    NB.btn.spinSpeed.Text = "🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

-- ============================================================
--       ЭФФЕКТЫ
-- ============================================================
onClick(NB.btn.trail, function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    NB.btn.trail.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
onClick(NB.btn.trailLen, function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    NB.btn.trailLen.Text = "📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(NB.btn.trailWid, function()
    P.trailWidthIndex = P.trailWidthIndex + 1; if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    NB.btn.trailWid.Text = "🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(NB.btn.wave, function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    NB.btn.wave.Text = "🌊 Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(NB.btn.explosion, function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    NB.btn.explosion.Text = "💥 Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(NB.btn.pulse, function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    NB.btn.pulse.Text = "💓 Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(NB.btn.spawnAnim, function()
    SETTINGS.SpawnAnim = not (SETTINGS.SpawnAnim ~= false)
    NB.btn.spawnAnim.Text = "🎆 Появление колец: " .. (SETTINGS.SpawnAnim and "ВКЛ" or "ВЫКЛ")
end)
onClick(NB.btn.spawnFlash, function()
    SETTINGS.SpawnFlash = not (SETTINGS.SpawnFlash ~= false)
    NB.btn.spawnFlash.Text = "💫 Вспышка при вкл: " .. (SETTINGS.SpawnFlash and "ВКЛ" or "ВЫКЛ")
end)

-- ============================================================
--       АУРА
-- ============================================================
NB.refreshAura = function()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
onClick(NB.btn.aura, function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    NB.btn.aura.Text = "🌀 Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then
        if not SETTINGS.AuraRing and not SETTINGS.AuraParticles and not SETTINGS.AuraShapes then
            SETTINGS.AuraRing = true; SETTINGS.AuraParticles = true; SETTINGS.AuraShapes = true
            NB.btn.auraRing.Text = "⭕ Кольцо: ВКЛ"; NB.btn.auraPart.Text = "✨ Частицы: ВКЛ"; NB.btn.auraFig.Text = "🔷 Фигуры: ВКЛ"
        end
        ORBIT.setupAura()
    else
        if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
    end
end)
onClick(NB.btn.auraRing, function()
    SETTINGS.AuraRing = not SETTINGS.AuraRing
    NB.btn.auraRing.Text = "⭕ Кольцо: " .. (SETTINGS.AuraRing and "ВКЛ" or "ВЫКЛ")
    NB.refreshAura()
end)
onClick(NB.btn.auraPart, function()
    SETTINGS.AuraParticles = not SETTINGS.AuraParticles
    NB.btn.auraPart.Text = "✨ Частицы: " .. (SETTINGS.AuraParticles and "ВКЛ" or "ВЫКЛ")
    NB.refreshAura()
end)
onClick(NB.btn.auraFig, function()
    SETTINGS.AuraShapes = not SETTINGS.AuraShapes
    NB.btn.auraFig.Text = "🔷 Фигуры: " .. (SETTINGS.AuraShapes and "ВКЛ" or "ВЫКЛ")
    NB.refreshAura()
end)
onClick(NB.btn.auraShape, function()
    ORBIT.auraShapeIndex = ORBIT.auraShapeIndex + 1
    if ORBIT.auraShapeIndex > #SHAPE_PRESETS then ORBIT.auraShapeIndex = 1 end
    NB.btn.auraShape.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    NB.refreshAura()
end)
onClick(NB.btn.auraSize, function()
    P.auraSizeIndex = P.auraSizeIndex + 1; if P.auraSizeIndex > #P.AURA_SIZE then P.auraSizeIndex = 1 end
    SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value
    NB.btn.auraSize.Text = "📐 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    NB.refreshAura()
end)
onClick(NB.btn.auraThick, function()
    P.auraThickIndex = P.auraThickIndex + 1; if P.auraThickIndex > #P.AURA_THICK then P.auraThickIndex = 1 end
    SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value
    NB.btn.auraThick.Text = "🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    NB.refreshAura()
end)
onClick(NB.btn.auraHeight, function()
    P.auraHeightIndex = P.auraHeightIndex + 1; if P.auraHeightIndex > #P.AURA_HEIGHT then P.auraHeightIndex = 1 end
    SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value
    NB.btn.auraHeight.Text = "⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
    NB.refreshAura()
end)
onClick(NB.btn.auraShapeScale, function()
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1
    if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
    SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor
    NB.btn.auraShapeScale.Text = "🔍 Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    NB.refreshAura()
end)
onClick(NB.btn.auraPattern, function()
    P.auraPatternIndex = P.auraPatternIndex + 1
    if P.auraPatternIndex > #P.AURA_PATTERNS then P.auraPatternIndex = 1 end
    SETTINGS.AuraPattern = P.AURA_PATTERNS[P.auraPatternIndex].name
    NB.btn.auraPattern.Text = "🌀 Узор ауры: " .. SETTINGS.AuraPattern
end)
onClick(NB.btn.auraSpeed, function()
    P.auraSpeedIndex = P.auraSpeedIndex + 1; if P.auraSpeedIndex > #P.AURA_SPEED then P.auraSpeedIndex = 1 end
    SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value
    NB.btn.auraSpeed.Text = "⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
end)
onClick(NB.btn.auraDir, function()
    P.auraDirIndex = P.auraDirIndex + 1; if P.auraDirIndex > #P.AURA_DIR then P.auraDirIndex = 1 end
    SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value
    NB.btn.auraDir.Text = "🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name
end)
onClick(NB.btn.auraTrail, function()
    SETTINGS.AuraTrailEnabled = not SETTINGS.AuraTrailEnabled
    NB.btn.auraTrail.Text = "🌠 Трейлы ауры: " .. (SETTINGS.AuraTrailEnabled and "ВКЛ" or "ВЫКЛ")
    NB.refreshAura()
end)
onClick(NB.btn.auraTrailLen, function()
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1
    if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    NB.btn.auraTrailLen.Text = "📏 Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(NB.btn.auraTrailWid, function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1
    if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    NB.btn.auraTrailWid.Text = "🎚️ Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(NB.btn.auraSpin, function()
    SETTINGS.AuraSpinEnabled = not SETTINGS.AuraSpinEnabled
    NB.btn.auraSpin.Text = "🔄 Кручение: " .. (SETTINGS.AuraSpinEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(NB.btn.auraSpinAxis, function()
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1
    if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    NB.btn.auraSpinAxis.Text = "↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
onClick(NB.btn.auraSpinSpeed, function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1
    if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    NB.btn.auraSpinSpeed.Text = "🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
end)
onClick(NB.btn.auraPulse, function()
    SETTINGS.AuraPulseEnabled = not SETTINGS.AuraPulseEnabled
    NB.btn.auraPulse.Text = "💓 Пульсация ауры: " .. (SETTINGS.AuraPulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- ============================================================
--       СВЕТ АУРЫ
-- ============================================================
onClick(NB.btn.auraLight, function()
    SETTINGS.AuraLightEnabled = not SETTINGS.AuraLightEnabled
    NB.btn.auraLight.Text = "💡 Свет ауры: " .. (SETTINGS.AuraLightEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraLightEnabled then
        NB.btn.auraLight.BackgroundColor3 = Color3.fromRGB(120,100,40)
        NB.btn.auraLight.TextColor3 = Color3.fromRGB(255,240,160)
    else
        NB.btn.auraLight.BackgroundColor3 = Color3.fromRGB(70,60,30)
        NB.btn.auraLight.TextColor3 = Color3.fromRGB(255,230,140)
    end
    NB.refreshAura()
end)
onClick(NB.btn.auraLightRange, function()
    local steps = {4, 6, 8, 12, 16, 24, 32}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightRange then idx = i; break end end
    SETTINGS.AuraLightRange = steps[(idx % #steps) + 1]
    NB.btn.auraLightRange.Text = "📏 Дальность: " .. SETTINGS.AuraLightRange
    NB.refreshAura()
end)
onClick(NB.btn.auraLightBright, function()
    local steps = {1, 2, 3, 5, 8, 12}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightBrightness then idx = i; break end end
    SETTINGS.AuraLightBrightness = steps[(idx % #steps) + 1]
    NB.btn.auraLightBright.Text = "✨ Яркость: " .. SETTINGS.AuraLightBrightness
    NB.refreshAura()
end)

-- ============================================================
--       ГРАФИКА
-- ============================================================
NB.MATERIALS = {"Neon", "Glass", "ForceField", "Plastic", "SmoothPlastic", "Metal", "Ice", "Marble", "Slate", "Granite"}
NB.materialIndex = 1
for i, m in ipairs(NB.MATERIALS) do
    if m == tostring(SETTINGS.Material):gsub("Enum.Material.", "") then NB.materialIndex = i; break end
end
onClick(NB.btn.material, function()
    NB.materialIndex = NB.materialIndex + 1
    if NB.materialIndex > #NB.MATERIALS then NB.materialIndex = 1 end
    local mName = NB.MATERIALS[NB.materialIndex]
    SETTINGS.Material = Enum.Material[mName]
    NB.btn.material.Text = "🎨 Материал: " .. mName:upper()
    ORBIT.rebuildAllRings()
end)
if SETTINGS.Material then
    NB.btn.material.Text = "🎨 Материал: " .. tostring(SETTINGS.Material):gsub("Enum.Material.", ""):upper()
end

onClick(NB.btn.transparency, function()
    local steps = {0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9}
    local idx = 1
    for i, v in ipairs(steps) do if math.abs(v - SETTINGS.Transparency) < 0.01 then idx = i; break end end
    SETTINGS.Transparency = steps[(idx % #steps) + 1]
    NB.btn.transparency.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"
    ORBIT.rebuildAllRings()
end)
NB.btn.transparency.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"

onClick(NB.btn.brightness, function()
    local steps = {0.5, 1, 1.5, 2, 3, 5, 8}
    local idx = 1
    for i, v in ipairs(steps) do if v == (SETTINGS.GlowIntensity or 1) then idx = i; break end end
    SETTINGS.GlowIntensity = steps[(idx % #steps) + 1]
    NB.btn.brightness.Text = "☀️ Яркость: " .. SETTINGS.GlowIntensity
    ORBIT.rebuildAllRings()
end)
NB.btn.brightness.Text = "☀️ Яркость: " .. (SETTINGS.GlowIntensity or 1)

onClick(NB.btn.glow, function()
    SETTINGS.GlowEnabled = not (SETTINGS.GlowEnabled ~= false)
    local on = SETTINGS.GlowEnabled
    NB.btn.glow.Text = "✨ Свечение: " .. (on and "ВКЛ" or "ВЫКЛ")
    if on then
        NB.btn.glow.BackgroundColor3 = Color3.fromRGB(35,60,50); NB.btn.glow.TextColor3 = Color3.fromRGB(180,255,220)
    else
        NB.btn.glow.BackgroundColor3 = Color3.fromRGB(45,45,65); NB.btn.glow.TextColor3 = Color3.fromRGB(200,200,220)
    end
    for _, ring in pairs(rings) do
        for _, d in ipairs(ring.blocks) do
            if d.light then d.light.Enabled = on end
        end
    end
end)

onClick(NB.btn.castShadow, function()
    SETTINGS.CastShadow = not SETTINGS.CastShadow
    NB.btn.castShadow.Text = "🌑 Тени: " .. (SETTINGS.CastShadow and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)

NB.GRAPHIC_MODES = {"LOW", "MEDIUM", "HIGH", "ULTRA"}
NB.graphicModeIndex = 2
NB.applyGraphicMode = function(mode)
    if mode == "LOW" then
        SETTINGS.LightEnabled = false; SETTINGS.TrailEnabled = false; SETTINGS.AuraParticles = false; SETTINGS.BlockCount = 4
    elseif mode == "MEDIUM" then
        SETTINGS.LightEnabled = true; SETTINGS.LightLimit = 10; SETTINGS.TrailEnabled = false; SETTINGS.AuraParticles = true; SETTINGS.BlockCount = 6
    elseif mode == "HIGH" then
        SETTINGS.LightEnabled = true; SETTINGS.LightLimit = 20; SETTINGS.TrailEnabled = true; SETTINGS.AuraParticles = true; SETTINGS.BlockCount = 8
    elseif mode == "ULTRA" then
        SETTINGS.LightEnabled = true; SETTINGS.LightLimit = 40; SETTINGS.TrailEnabled = true; SETTINGS.AuraParticles = true; SETTINGS.AuraShapes = true; SETTINGS.BlockCount = 12
    end
    ORBIT.rebuildAllRings()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
onClick(NB.btn.quality, function()
    NB.graphicModeIndex = NB.graphicModeIndex + 1
    if NB.graphicModeIndex > #NB.GRAPHIC_MODES then NB.graphicModeIndex = 1 end
    local mode = NB.GRAPHIC_MODES[NB.graphicModeIndex]
    NB.btn.quality.Text = "⚡ Качество графики: " .. mode
    NB.applyGraphicMode(mode)
    ORBIT.notify("🎨 Графика: " .. mode, Color3.fromRGB(200,220,255), 2)
end)

-- ============================================================
--       ОГОНЬ
-- ============================================================
onClick(NB.btn.fire, function()
    SETTINGS.FireEnabled = not SETTINGS.FireEnabled
    NB.btn.fire.Text = "🔥 Огонь: " .. (SETTINGS.FireEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupFire()
end)
onClick(NB.btn.fireSize, function()
    P.fireSizeIndex = P.fireSizeIndex + 1; if P.fireSizeIndex > #P.FIRE_SIZE then P.fireSizeIndex = 1 end
    SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value
    NB.btn.fireSize.Text = "📏 Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)
onClick(NB.btn.fireHeat, function()
    P.fireHeatIndex = P.fireHeatIndex + 1; if P.fireHeatIndex > #P.FIRE_HEAT then P.fireHeatIndex = 1 end
    SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value
    NB.btn.fireHeat.Text = "🌡️ Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)

-- ============================================================
--       АНТИЧИТ
-- ============================================================
NB.antichitLoaded = false
onClick(NB.btn.antichitLaunch, function()
    if NB.antichitLoaded or (ORBIT.loaded and ORBIT.loaded.anticheat) then
        NB.antichitLoaded = true
        NB.btn.antichitLaunch.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
        NB.lbl.antichitStatus.Text = "🛡 Защита: активна (18 функций)"
        NB.lbl.antichitStatus.TextColor3 = Color3.fromRGB(160,255,180)
        ORBIT.notify("🛡 Античит уже запущен", Color3.fromRGB(180,255,180), 2)
        return
    end
    NB.btn.antichitLaunch.Text = "⏳ Загружаю..."
    task.spawn(function()
        local url = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_anticheat.lua?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src < 100 then
            NB.btn.antichitLaunch.Text = "❌ Ошибка загрузки"
            NB.lbl.antichitStatus.Text = "🛡 Защита: ошибка сети"
            NB.lbl.antichitStatus.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2); NB.btn.antichitLaunch.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            NB.btn.antichitLaunch.Text = "❌ Ошибка кода"
            NB.lbl.antichitStatus.Text = "🛡 Защита: ошибка компиляции"
            NB.lbl.antichitStatus.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2); NB.btn.antichitLaunch.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        local runOk, runErr = pcall(fn)
        if not runOk then
            NB.btn.antichitLaunch.Text = "❌ Ошибка запуска"
            NB.lbl.antichitStatus.Text = "🛡 Защита: " .. tostring(runErr):sub(1, 30)
            NB.lbl.antichitStatus.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2); NB.btn.antichitLaunch.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        NB.antichitLoaded = true
        ORBIT.loaded.anticheat = true
        NB.btn.antichitLaunch.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
        NB.btn.antichitLaunch.BackgroundColor3 = Color3.fromRGB(60,100,60)
        NB.btn.antichitLaunch.TextColor3 = Color3.fromRGB(200,255,200)
        NB.lbl.antichitStatus.Text = "🛡 Защита: активна (18 функций)"
        NB.lbl.antichitStatus.TextColor3 = Color3.fromRGB(160,255,180)
        ORBIT.notify("🛡 Античит запущен!", Color3.fromRGB(160,255,180), 3)
    end)
end)

task.spawn(function()
    while screenGui and screenGui.Parent and not NB.antichitLoaded do
        task.wait(1)
        if ORBIT.loaded and ORBIT.loaded.anticheat then
            NB.antichitLoaded = true
            NB.btn.antichitLaunch.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
            NB.btn.antichitLaunch.BackgroundColor3 = Color3.fromRGB(60,100,60)
            NB.lbl.antichitStatus.Text = "🛡 Защита: активна (18 функций)"
            NB.lbl.antichitStatus.TextColor3 = Color3.fromRGB(160,255,180)
        end
    end
end)

-- ============================================================
--       ЗВУКИ
-- ============================================================
onClick(NB.btn.soundToggle, function()
    if ORBIT.SOUNDS then
        ORBIT.SOUNDS.Enabled = not ORBIT.SOUNDS.Enabled
        NB.btn.soundToggle.Text = "🔊 Звуки: " .. (ORBIT.SOUNDS.Enabled and "ВКЛ" or "ВЫКЛ")
    end
end)
NB.VOLUME_STEPS = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0}
NB.soundVolumeIndex = 11
onClick(NB.btn.soundVolume, function()
    if not ORBIT.SOUNDS then return end
    NB.soundVolumeIndex = NB.soundVolumeIndex + 1
    if NB.soundVolumeIndex > #NB.VOLUME_STEPS then NB.soundVolumeIndex = 1 end
    local v = NB.VOLUME_STEPS[NB.soundVolumeIndex]
    ORBIT.SOUNDS.Volume = v
    NB.btn.soundVolume.Text = "🎵 Громкость: " .. math.floor(v * 100) .. "%"
end)
onClick(NB.btn.soundTest, function()
    NB.btn.soundTest.Text = "⏳ Проверяю..."
    task.wait(0.1)
    if ORBIT.playClick then ORBIT.playClick() end
    task.wait(0.4)
    if ORBIT.playDodge then ORBIT.playDodge() end
    task.wait(1.2)
    NB.btn.soundTest.Text = "✅ Готово"
    task.wait(2)
    NB.btn.soundTest.Text = "🔍 Проверка звуков"
end)

-- ============================================================
--       МЕТКИ
-- ============================================================
onClick(NB.btn.tagNearest, function()
    local closest, bestDist = nil, math.huge
    local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - myHrp.Position).Magnitude
                if d < bestDist then closest, bestDist = p, d end
            end
        end
    end
    if closest and ORBIT.toggleTagCheater then
        ORBIT.toggleTagCheater(closest); task.wait(0.1); pcall(NB.rebuildPeopleList)
    end
end)
onClick(NB.btn.clearTags, function()
    if ORBIT.clearAllTags then ORBIT.clearAllTags() end
    task.wait(0.1); pcall(NB.rebuildPeopleList)
end)

-- ============================================================
--       МАГАЗИН / РЕДАКТОР / ИГРА / ГАСТЕР
-- ============================================================
onClick(NB.btn.openShop, function() if ORBIT.openShop then ORBIT.openShop() end end)
onClick(NB.btn.openEditor, function() if ORBIT.openEditor then ORBIT.openEditor() end end)
onClick(NB.btn.openGame, function() if ORBIT.openMiniGame then ORBIT.openMiniGame() end end)
do
    NB.modeLabel = function() return (ORBIT.mode == "normal") and "🎭 Режим: Обычный" or "🎭 Режим: Санс" end
    onClick(NB.btn.openGaster, function()
        if ORBIT.gaster and ORBIT.gaster.open then ORBIT.gaster.open()
        else ORBIT.notify("⚠️ Модуль Гастера не загружен", Color3.fromRGB(255,200,120), 3) end
    end)
    onClick(NB.btn.gasterWeapon, function()
        local W = ORBIT.gaster and ORBIT.gaster.weapon
        if W and W.equip then W.equip()
        else ORBIT.notify("⚠️ Гастер-оружие не загружено", Color3.fromRGB(255,200,120), 3) end
    end)
    onClick(NB.btn.mode, function()
        if ORBIT.setMode then ORBIT.setMode((ORBIT.mode == "normal") and "sans" or "normal") end
        NB.btn.mode.Text = NB.modeLabel()
    end)
end

-- ============================================================
--       ПОМОЩНИК
-- ============================================================
onClick(NB.btn.helper, function()
    if ORBIT.helperOpen then
        ORBIT.helperOpen()
    else
        ORBIT.notify("❌ orbit_helper.lua не загружен", Color3.fromRGB(255,150,150), 3)
    end
end)

-- ============================================================
--       ПРОИЗВОДИТЕЛЬНОСТЬ
-- ============================================================
NB.PERF_MODES = {"auto", "high", "medium", "low", "minimal", "off"}
NB.PERF_LABELS = {auto="АВТО", high="ВЫСОКОЕ", medium="СРЕДНЕЕ", low="НИЗКОЕ", minimal="МИНИМУМ", off="ВЫКЛ"}
NB.perfIndex = 1
NB.refreshPerfBtn = function()
    local info = ORBIT.getPerformanceInfo and ORBIT.getPerformanceInfo() or {Mode="auto", Current="high", FPS=60}
    NB.btn.perf.Text = string.format("⚡ Качество: %s", NB.PERF_LABELS[info.Mode] or info.Mode)
end
NB.refreshPerfBtn()
onClick(NB.btn.perf, function()
    NB.perfIndex = NB.perfIndex + 1; if NB.perfIndex > #NB.PERF_MODES then NB.perfIndex = 1 end
    if ORBIT.setPerformanceMode then ORBIT.setPerformanceMode(NB.PERF_MODES[NB.perfIndex]) end
    NB.refreshPerfBtn()
end)

-- ============================================================
--       СЕРДЦЕ
-- ============================================================
NB.heartScaleIndex = 4
NB.HEART_STEPS = P.HEART_STEPS or {0.2, 0.35, 0.5, 0.65, 0.9, 1.2, 1.6, 2.2}
for i, v in ipairs(NB.HEART_STEPS) do if math.abs(v - SETTINGS.HeartScale) < 0.01 then NB.heartScaleIndex = i; break end end
NB.refreshHeartSizeBtn = function()
    local pct = math.floor(SETTINGS.HeartScale / 0.65 * 100 + 0.5)
    NB.btn.heartSize.Text = "💗 Размер сердца: " .. pct .. "%"
end
NB.refreshHeartSizeBtn()
onClick(NB.btn.heartSize, function()
    NB.heartScaleIndex = NB.heartScaleIndex + 1
    if NB.heartScaleIndex > #NB.HEART_STEPS then NB.heartScaleIndex = 1 end
    SETTINGS.HeartScale = NB.HEART_STEPS[NB.heartScaleIndex]
    NB.refreshHeartSizeBtn(); ORBIT.rebuildAllRings()
end)

-- ============================================================
--       SHARE
-- ============================================================
onClick(NB.btn.shareLoad, function()
    local txt = NB.input.share.Text or ""
    txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
    if txt == "" then
        ORBIT.notify("📥 Поле пустое — вставь строку от друга", Color3.fromRGB(255, 200, 120), 3)
        return
    end
    if txt:match("^https?://") then
        ORBIT.notify("🌐 Загружаю по ссылке...", Color3.fromRGB(200, 220, 255), 2)
        task.spawn(function()
            local ok, body = pcall(function() return game:HttpGet(txt, true) end)
            if ok and type(body) == "string" and #body > 10 then
                NB.input.share.Text = body:gsub("^%s+", ""):gsub("%s+$", "")
                ORBIT.notify("✅ Скачал — нажми ЗАГРУЗИТЬ ещё раз", Color3.fromRGB(180, 255, 180), 3)
            else
                ORBIT.notify("❌ Не удалось скачать ссылку", Color3.fromRGB(255, 150, 150), 3)
            end
        end)
        return
    end
    if not ORBIT.share or not ORBIT.share.decode then
        ORBIT.notify("❌ orbit_share.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        return
    end
    local dec, err = ORBIT.share.decode(txt)
    if not dec then
        ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 4)
        return
    end
    local ok = ORBIT.share.applyDecoded(dec)
    if ok then NB.input.share.Text = "" end
end)

onClick(NB.btn.shareCopy, function()
    if not ORBIT.share or not ORBIT.share.encodeCurrentSettings then
        ORBIT.notify("❌ orbit_share.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        return
    end
    local str, err = ORBIT.share.encodeCurrentSettings()
    if not str then
        ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 3)
        return
    end
    NB.input.share.Text = str
    local ok = ORBIT.share.copy(str)
    if ok then
        ORBIT.notify("📤 Готово и скопировано — отправь другу", Color3.fromRGB(180, 255, 180), 3)
    else
        ORBIT.notify("📤 Готово — выдели строку и скопируй вручную", Color3.fromRGB(255, 220, 140), 4)
    end
end)

onClick(NB.btn.sharePaste, function()
    if not ORBIT.share or not ORBIT.share.paste then
        ORBIT.notify("❌ orbit_share.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        return
    end
    local txt, err = ORBIT.share.paste()
    if not txt then
        ORBIT.notify("📋 " .. tostring(err) .. " — вставь вручную", Color3.fromRGB(255, 200, 120), 3)
        return
    end
    NB.input.share.Text = txt
    ORBIT.notify("📋 Вставлено (" .. #txt .. " симв.)", Color3.fromRGB(180, 220, 255), 2)
end)

onClick(NB.btn.shareClear, function()
    NB.input.share.Text = ""
end)

-- ============================================================
--       СОХРАНЕНИЯ
-- ============================================================
NB.rebuildSavesList = function()
    for _, child in ipairs(NB.scroll.saves:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then child:Destroy() end
    end
    local names = ORBIT.getSaveNames()
    if #names == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 28)
        empty.BackgroundTransparency = 1
        empty.Text = "— нет сохранений —"
        empty.TextColor3 = Color3.fromRGB(140,140,170)
        empty.Font = Enum.Font.Gotham; empty.TextSize = 12; empty.LayoutOrder = 1
        empty.Parent = NB.scroll.saves
        return
    end
    for i, name in ipairs(names) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = NB.scroll.saves
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -190, 1, 0); nameLbl.Position = UDim2.new(0, 8, 0, 0)
        nameLbl.BackgroundTransparency = 1; nameLbl.Text = "💾 " .. name
        nameLbl.TextColor3 = Color3.fromRGB(220,220,255)
        nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local shareB = Instance.new("TextButton")
        shareB.Size = UDim2.new(0, 55, 0, 24); shareB.Position = UDim2.new(1, -180, 0, 4)
        shareB.BackgroundColor3 = Color3.fromRGB(70, 70, 130); shareB.TextColor3 = Color3.fromRGB(220, 220, 255)
        shareB.Font = Enum.Font.GothamBold; shareB.TextSize = 10; shareB.Text = "📤 SHR"
        shareB.Parent = row
        Instance.new("UICorner", shareB).CornerRadius = UDim.new(0, 5)

        local loadB = Instance.new("TextButton")
        loadB.Size = UDim2.new(0, 55, 0, 24); loadB.Position = UDim2.new(1, -120, 0, 4)
        loadB.BackgroundColor3 = Color3.fromRGB(40,80,50); loadB.TextColor3 = Color3.fromRGB(160,255,180)
        loadB.Font = Enum.Font.GothamBold; loadB.TextSize = 10; loadB.Text = "✓ ЗАГР"; loadB.Parent = row
        Instance.new("UICorner", loadB).CornerRadius = UDim.new(0, 5)

        local delB = Instance.new("TextButton")
        delB.Size = UDim2.new(0, 55, 0, 24); delB.Position = UDim2.new(1, -60, 0, 4)
        delB.BackgroundColor3 = Color3.fromRGB(80,30,30); delB.TextColor3 = Color3.fromRGB(255,150,150)
        delB.Font = Enum.Font.GothamBold; delB.TextSize = 10; delB.Text = "✖ УДАЛ"; delB.Parent = row
        Instance.new("UICorner", delB).CornerRadius = UDim.new(0, 5)

        onClick(loadB, function()
            local ok = ORBIT.loadNamed(name)
            if ok then
                ORBIT.notify("💾 Загружено: " .. name, Color3.fromRGB(160,255,180))
                ORBIT.rebuildAllRings()
                if ORBIT.setupAura then ORBIT.setupAura() end
                if ORBIT.setupFire then ORBIT.setupFire() end
                NB.refreshAllLabels()
            end
        end)
        onClick(delB, function()
            if ORBIT.deleteNamed(name) then
                ORBIT.notify("🗑 Удалено: " .. name, Color3.fromRGB(255,150,150))
                NB.rebuildSavesList()
            end
        end)
        onClick(shareB, function()
            if not ORBIT.share or not ORBIT.share.encodeSave then
                ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255,150,150), 3)
                return
            end
            local str, err = ORBIT.share.encodeSave(name)
            if not str then
                ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255,150,150), 3)
                return
            end
            NB.input.share.Text = str
            ORBIT.share.copy(str)
            ORBIT.notify("📤 Строка «" .. name .. "» готова", Color3.fromRGB(180,220,255), 3)
            setTab("sys")
        end)
    end
end

onClick(NB.btn.createSave, function()
    local name = NB.input.saveName.Text
    if not name or name == "" then name = "Авто-" .. tostring(#ORBIT.getSaveNames() + 1) end
    local ok, err = pcall(function() return ORBIT.saveNamed(name) end)
    if ok and err ~= false then
        ORBIT.notify("💾 Сохранено: " .. name, Color3.fromRGB(160,255,180))
        NB.input.saveName.Text = ""; NB.rebuildSavesList()
    else
        ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255,100,100))
    end
end)

onClick(NB.btn.importSave, function()
    if not ORBIT.share or not ORBIT.share.paste then
        ORBIT.notify("❌ Модуль шаринга не загружен", Color3.fromRGB(255,150,150), 3)
        return
    end
    local txt, err = ORBIT.share.paste()
    if not txt then
        ORBIT.notify("📋 " .. tostring(err) .. " — вставь в поле SHARE", Color3.fromRGB(255,200,120), 3)
        setTab("sys")
        return
    end
    NB.input.share.Text = txt
    ORBIT.notify("📋 Вставлено в поле SHARE — нажми ЗАГРУЗИТЬ", Color3.fromRGB(180,220,255), 3)
    setTab("sys")
end)

onClick(NB.btn.save, function()
    if NB.input.music.Text ~= "" then ORBIT.setMusicId(NB.input.music.Text) end
    if ORBIT.saveSettings() then
        NB.btn.save.Text = "✅ Сохранено!"; task.wait(1.5); NB.btn.save.Text = "💾 Сохранить в автослот"
    end
end)
onClick(NB.btn.load, function()
    if ORBIT.loadSettings() then
        ORBIT.notify("📂 Загружено", Color3.fromRGB(180,220,255))
        ORBIT.rebuildAllRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupFire then ORBIT.setupFire() end
        NB.refreshAllLabels()
    end
end)
onClick(NB.btn.reset, function()
    for k, v in pairs(ORBIT.DEFAULT_SETTINGS) do SETTINGS[k] = v end
    ORBIT.shapeIndex = 1; ORBIT.auraShapeIndex = 1
    P.colorIndex = 1; P.auraColorIndex = 1
    P.shapeCategoryIndex = 1; P.orbitPatternIndex = 1; P.auraPatternIndex = 1
    P.spinSpeedIndex = 2; P.spreadIndex = 2; P.heightIndex = 4; P.speedIndex = 2; P.speedModeIndex = 1
    P.directionIndex = 1; P.formModeIndex = 1; P.orbitIndex = 2; P.shapeSizeIndex = 3
    P.trailLengthIndex = 4; P.trailWidthIndex = 4
    P.auraSizeIndex = 3; P.auraThickIndex = 2; P.auraHeightIndex = 2; P.auraShapeScaleIndex = 3
    P.auraTrailLengthIndex = 5; P.auraTrailWidthIndex = 4; P.auraSpeedIndex = 3; P.auraDirIndex = 1
    P.auraSpinAxisIndex = 1; P.auraSpinSpeedIndex = 2; P.fireSizeIndex = 2; P.fireHeatIndex = 2
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[1].name
    SETTINGS.AuraPattern = P.AURA_PATTERNS[1].name
    SETTINGS.GlowEnabled = true; SETTINGS.GlowIntensity = 1; SETTINGS.CastShadow = false
    ORBIT.spinResetting = false; ORBIT.spinAxisEnabled = true; ORBIT.spinAxisDir = "X"
    ORBIT.applyDirectionPreset(); ORBIT.applySpeedModePreset(); ORBIT.applyShapes()
    ORBIT.applyColor(); ORBIT.rebuildAllRings()
    if ORBIT.setupAura then ORBIT.setupAura() end
    if ORBIT.setupFire then ORBIT.setupFire() end
    NB.refreshAllLabels()
    ORBIT.notify("🔄 Сброс выполнен", Color3.fromRGB(255,180,180))
end)
onClick(NB.btn.unload, function() pcall(function() ORBIT.unload() end) end)

onClick(NB.btn.applyId, function()
    local ok = ORBIT.setMusicId(NB.input.music.Text)
    if ok then
        NB.btn.applyId.Text = "✅ Готово!"; task.wait(1.2); NB.btn.applyId.Text = "✅ Применить ID"
    else
        NB.btn.applyId.Text = "❌ Ошибка"; task.wait(1.5); NB.btn.applyId.Text = "✅ Применить ID"
    end
end)
onClick(NB.btn.music, function()
    local s = ORBIT.musicSound and tostring(ORBIT.musicSound.SoundId or "") or ""
    if not ORBIT.musicSound or s == "" or s == "rbxassetid://" then
        NB.btn.music.Text = "❌ Вставь ID!"; task.wait(1.2)
        NB.btn.music.Text = "🎵 Музыка: " .. (ORBIT.musicEnabled and "ВКЛ" or "ВЫКЛ")
        return
    end
    ORBIT.musicEnabled = not ORBIT.musicEnabled
    if ORBIT.musicEnabled then ORBIT.musicSound:Play(); NB.btn.music.Text = "🎵 Музыка: ВКЛ"
    else ORBIT.musicSound:Stop(); NB.btn.music.Text = "🎵 Музыка: ВЫКЛ" end
end)

NB.rebuildSavesList()

-- ============================================================
--       ✨ СТИХИИ: ОБРАБОТЧИКИ КРЕСТИКОВ И ВОЗВРАТА
-- ============================================================
NB.elementHidden = {}   -- локальный кэш: id -> true

for i, row in ipairs(NB.elementRows) do
    local st = row.def
    local btn = row.btn
    local xBtn = row.xBtn

    onClick(btn, function() NB.applyStyle(st) end)

    onClick(xBtn, function()
        local id = st.id
        if ORBIT.abilities and ORBIT.abilities.hideElement then
            pcall(ORBIT.abilities.hideElement, id)
        end
        NB.elementHidden[id] = true
        row.holder.Visible = false
        relayout()
        ORBIT.notify("❌ Стихия скрыта: " .. st.name, Color3.fromRGB(255, 180, 180), 2)
    end)
end

onClick(NB.btn.restoreElements, function()
    if ORBIT.abilities and ORBIT.abilities.resetHidden then
        pcall(ORBIT.abilities.resetHidden)
    end
    NB.elementHidden = {}
    for _, row in ipairs(NB.elementRows) do
        row.holder.Visible = true
    end
    relayout()
    ORBIT.notify("♻️ Все стихии возвращены", Color3.fromRGB(180, 255, 180), 2)
end)

-- ============================================================
--       ✨ МЕНЮ ФРАЗ САНСА
-- ============================================================
NB.openSansPhraseMenu = function()
    if not ORBIT.sans or not ORBIT.sans.phrases then
        ORBIT.notify("❌ Модуль Санса не загружен", Color3.fromRGB(255,150,150), 2)
        return
    end
    local old = screenGui:FindFirstChild("_OrbitSansMenu")
    if old then old:Destroy() end

    local cats = {}
    for cat, _ in pairs(ORBIT.sans.phrases) do cats[#cats + 1] = cat end
    table.sort(cats)

    local m = Instance.new("Frame")
    m.Name = "_OrbitSansMenu"
    m.AnchorPoint = Vector2.new(0.5, 0.5)
    m.Position = UDim2.new(0.5, 0, 0.5, 0)
    m.Size = UDim2.new(0, math.min(360, screenGui.AbsoluteSize.X - 20), 0, math.min(460, screenGui.AbsoluteSize.Y - 40))
    m.BackgroundColor3 = Color3.fromRGB(22, 18, 38)
    m.BorderSizePixel = 0
    m.ZIndex = 80
    m.Parent = screenGui
    Instance.new("UICorner", m).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", m); st.Color = Color3.fromRGB(150, 120, 255); st.Thickness = 1.5

    local title = Instance.new("TextLabel", m)
    title.Size = UDim2.new(1, -60, 0, 30); title.Position = UDim2.new(0, 14, 0, 6)
    title.BackgroundTransparency = 1; title.Text = "💀 ФРАЗЫ САНСА"
    title.TextColor3 = Color3.fromRGB(235, 225, 255); title.Font = Enum.Font.GothamBold
    title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 81

    local cl = Instance.new("TextButton", m)
    cl.Size = UDim2.new(0, 30, 0, 30); cl.Position = UDim2.new(1, -38, 0, 4)
    cl.BackgroundColor3 = Color3.fromRGB(80, 30, 30); cl.TextColor3 = Color3.fromRGB(255, 160, 160)
    cl.Font = Enum.Font.GothamBold; cl.TextSize = 15; cl.Text = "✖"; cl.ZIndex = 81
    Instance.new("UICorner", cl).CornerRadius = UDim.new(0, 8)
    cl.Activated:Connect(function() m:Destroy() end)

    local sc = Instance.new("ScrollingFrame", m)
    sc.Position = UDim2.new(0, 8, 0, 44); sc.Size = UDim2.new(1, -16, 1, -52)
    sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0; sc.ScrollBarThickness = 4
    sc.CanvasSize = UDim2.new(0, 0, 0, 0); sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.ZIndex = 81
    local layout = Instance.new("UIListLayout", sc)
    layout.Padding = UDim.new(0, 6); layout.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", sc); pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 4); pad.PaddingTop = UDim.new(0, 4)

    local CAT_LABEL = {
        death = "💀 Смерть", spawn = "✨ Спавн", greet = "👋 Приветствие",
        hurt = "💔 Боль", kill = "🗡 Убийство", dodge = "🥷 Уворот",
        taunt = "😏 Насмешка", combo = "🔥 Комбо", victory = "🏆 Победа",
        idle = "💤 Простой", lowhp = "❤️ Мало HP", spawnkill = "⚠️ Спавн-килл",
    }

    for _, cat in ipairs(cats) do
        local hdr = Instance.new("TextLabel", sc)
        hdr.Size = UDim2.new(1, -4, 0, 22); hdr.BackgroundTransparency = 1
        hdr.Text = "▸ " .. (CAT_LABEL[cat] or cat:upper())
        hdr.TextColor3 = Color3.fromRGB(200, 200, 255)
        hdr.Font = Enum.Font.GothamBold; hdr.TextSize = 11
        hdr.TextXAlignment = Enum.TextXAlignment.Left; hdr.ZIndex = 82

        for _, phrase in ipairs(ORBIT.sans.phrases[cat]) do
            local b = Instance.new("TextButton", sc)
            b.Size = UDim2.new(1, -4, 0, 30)
            b.BackgroundColor3 = Color3.fromRGB(45, 38, 65)
            b.TextColor3 = Color3.fromRGB(230, 220, 255)
            b.Font = Enum.Font.GothamBold; b.TextSize = 11
            b.Text = phrase; b.TextWrapped = true; b.TextTruncated = true; b.ZIndex = 82
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            b.Activated:Connect(function()
                local c = LocalPlayer.Character
                local head = c and c:FindFirstChild("Head")
                if head and ORBIT.sans and ORBIT.sans.showAt then
                    pcall(ORBIT.sans.showAt, head.Position + Vector3.new(0, 2, 0), phrase, 4)
                end
                ORBIT.notify("💀 " .. phrase, Color3.fromRGB(200, 220, 255), 3)
                if ORBIT.sans and ORBIT.sans.playSound then pcall(ORBIT.sans.playSound, cat) end
                m:Destroy()
            end)
        end
    end
end

-- Обработчики эмоций
for i, b in ipairs(NB.emoteBtns) do
    local def = NB.emoteDefs[i]
    onClick(b, function()
        local name = def[2]
        if name == "say" then
            NB.openSansPhraseMenu()
        elseif ORBIT.emote then
            if not ORBIT.emote(name) then
                ORBIT.notify("🎭 Подожди секунду...", Color3.fromRGB(255, 220, 140), 1.5)
            end
        else
            ORBIT.notify("❌ Модуль эмоций не загружен", Color3.fromRGB(255, 150, 150), 3)
        end
    end)
end

-- ============================================================
--       ПАЛИТРА (50 цветов)
-- ============================================================
NB.paletteGui = nil
NB.closePalette = function()
    if NB.paletteGui then NB.paletteGui:Destroy(); NB.paletteGui = nil end
end
NB.openPalette = function(titleText, getIdx, onPick)
    NB.closePalette()
    local abs = screenGui.AbsoluteSize
    local w = math.min(340, abs.X - 16)
    local h = math.min(380, abs.Y - 16)
    local f = Instance.new("Frame")
    f.Name = "_OrbitPalette"
    f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Size = UDim2.new(0, w, 0, h)
    f.BackgroundColor3 = Color3.fromRGB(22, 18, 38); f.BorderSizePixel = 0; f.ZIndex = 60
    f.Parent = screenGui
    NB.paletteGui = f
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", f); st.Color = Color3.fromRGB(150, 120, 255); st.Thickness = 1.5
    local ttl = Instance.new("TextLabel")
    ttl.Size = UDim2.new(1, -60, 0, 38); ttl.Position = UDim2.new(0, 12, 0, 4)
    ttl.BackgroundTransparency = 1; ttl.TextColor3 = Color3.fromRGB(235, 225, 255)
    ttl.Font = Enum.Font.GothamBold; ttl.TextSize = 13; ttl.TextXAlignment = Enum.TextXAlignment.Left
    ttl.ZIndex = 61; ttl.Parent = f
    local function setTitle() ttl.Text = titleText .. " — " .. P.COLORS[getIdx()].name end
    setTitle()
    local cl = Instance.new("TextButton")
    cl.Size = UDim2.new(0, 36, 0, 32); cl.Position = UDim2.new(1, -44, 0, 6)
    cl.BackgroundColor3 = Color3.fromRGB(80, 36, 52); cl.TextColor3 = Color3.fromRGB(255, 150, 165)
    cl.Font = Enum.Font.GothamBold; cl.TextSize = 14; cl.Text = "✖"; cl.ZIndex = 61; cl.Parent = f
    Instance.new("UICorner", cl).CornerRadius = UDim.new(0, 9)
    onClick(cl, NB.closePalette)
    local sc = Instance.new("ScrollingFrame")
    sc.Position = UDim2.new(0, 8, 0, 46); sc.Size = UDim2.new(1, -16, 1, -54)
    sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0; sc.ScrollBarThickness = 4
    sc.CanvasSize = UDim2.new(0, 0, 0, 0); sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.ZIndex = 61; sc.Parent = f
    local cell = IS_MOBILE and 46 or 40
    local grid = Instance.new("UIGridLayout", sc)
    grid.CellSize = UDim2.new(0, cell, 0, cell); grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", sc); pad.PaddingLeft = UDim.new(0, 4); pad.PaddingTop = UDim.new(0, 4)
    local strokes = {}
    for i, c in ipairs(P.COLORS) do
        local sw = Instance.new("TextButton")
        sw.LayoutOrder = i; sw.Text = c.rainbow and "🌈" or ""; sw.TextSize = 20
        sw.BackgroundColor3 = c.c or Color3.fromRGB(140, 100, 255); sw.AutoButtonColor = true
        sw.ZIndex = 62; sw.Parent = sc
        Instance.new("UICorner", sw).CornerRadius = UDim.new(0, 10)
        if c.rainbow then
            local g = Instance.new("UIGradient", sw)
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 80)),
                ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
            })
            g.Rotation = 45
        end
        local ss = Instance.new("UIStroke", sw)
        ss.Thickness = (i == getIdx()) and 3 or 1
        ss.Color = (i == getIdx()) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
        ss.Transparency = (i == getIdx()) and 0 or 0.6
        strokes[i] = ss
        onClick(sw, function()
            onPick(i)
            setTitle()
            for j, s in pairs(strokes) do
                s.Thickness = (j == i) and 3 or 1
                s.Color = (j == i) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
                s.Transparency = (j == i) and 0 or 0.6
            end
            task.delay(0.25, NB.closePalette)
        end)
    end
end

onClick(NB.btn.color, function()
    NB.openPalette("🎨 Цвет колец", function() return P.colorIndex end, function(i)
        P.colorIndex = i
        ORBIT.applyColor()
        NB.btn.color.Text = "🎨 Цвет: " .. P.COLORS[i].name
    end)
end)
onClick(NB.btn.auraColor, function()
    NB.openPalette("🎨 Цвет ауры", function() return P.auraColorIndex end, function(i)
        P.auraColorIndex = i
        local ac = P.COLORS[i]
        if ac.c then SETTINGS.AuraColor = ac.c end
        NB.btn.auraColor.Text = "🎨 Цвет ауры: " .. ac.name
        NB.refreshAura()
    end)
end)

-- ============================================================
--       СТИЛИ
-- ============================================================
NB.idxByName = function(list, name)
    for i, v in ipairs(list) do if v.name == name then return i end end
    return nil
end
NB.idxByValue = function(list, key, val)
    local best, bd = nil, math.huge
    for i, v in ipairs(list) do
        local d = math.abs((v[key] or 0) - val)
        if d < bd then best, bd = i, d end
    end
    return best
end
NB.pickRandom = function(t) return t[math.random(1, #t)] end

NB.makeRandomStyle = function()
    local pats, shapeNames = {}, {}
    for _, p in ipairs(P.ORBIT_PATTERNS) do pats[#pats + 1] = p.name end
    for _, s in ipairs(SHAPE_PRESETS) do shapeNames[#shapeNames + 1] = s.name end
    local colorName = (math.random() < 0.4) and "РАДУГА" or P.COLORS[math.random(2, #P.COLORS)].name
    local ringsOn = {true, false, false, false, false}
    for ri = 2, math.random(1, 3) do ringsOn[ri] = true end
    local mats = {"Neon", "Neon", "Glass", "Metal", "SmoothPlastic", "ForceField"}
    local st = {
        name = "случайный", color = colorName, pattern = NB.pickRandom(pats), speed = NB.pickRandom({1.0, 1.5, 2.0}),
        orbit = NB.pickRandom({"M", "L"}), size = "M", shape = NB.pickRandom(shapeNames), rings = ringsOn,
        material = NB.pickRandom(mats), trail = math.random() < 0.5, pulse = math.random() < 0.3,
        aura = math.random() < 0.4, fire = math.random() < 0.2,
    }
    st.auraColor = colorName
    return st
end

-- v24.2-fix1: включение колец через ORBIT.setRingEnabled (единообразие)
NB.applyStyle = function(st)
    if st.random then st = NB.makeRandomStyle() end
    local ci = NB.idxByName(P.COLORS, st.color); if ci then P.colorIndex = ci end
    local pi = NB.idxByName(P.ORBIT_PATTERNS, st.pattern)
    if pi then P.orbitPatternIndex = pi; SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[pi].name end
    local sp = NB.idxByValue(P.SPEED, "value", st.speed or 1.0)
    if sp then P.speedIndex = sp; SETTINGS.SpeedMultiplier = P.SPEED[sp].value end
    local oi = NB.idxByName(P.ORBIT, st.orbit or "M"); if oi then P.orbitIndex = oi end
    local zi = NB.idxByName(P.SHAPE_SIZE, st.size or "M"); if zi then P.shapeSizeIndex = zi end
    P.shapeCategoryIndex = 1; P.formModeIndex = 1
    for i, s in ipairs(SHAPE_PRESETS) do if s.name == st.shape then ORBIT.shapeIndex = i; break end end
    ORBIT.applyShapes()
    SETTINGS.Material = Enum.Material[st.material or "Neon"] or Enum.Material.Neon
    SETTINGS.Transparency = st.transparency or 0.1
    SETTINGS.TrailEnabled = st.trail == true
    SETTINGS.PulseEnabled = st.pulse == true
    SETTINGS.LightEnabled = true
    SETTINGS.GradientEnabled = false
    -- v24.2-fix1: включаем/выключаем кольца через setRingEnabled
    for ri = 1, 5 do
        local want = (ri == 1) or (st.rings and st.rings[ri] == true)
        if want and not rings[ri].enabled then
            ORBIT.setRingEnabled(ri, true)
        elseif not want and rings[ri].enabled then
            ORBIT.setRingEnabled(ri, false)
        end
    end
    SETTINGS.AuraEnabled = st.aura == true
    if st.aura then
        local ai = NB.idxByName(P.COLORS, st.auraColor or st.color)
        if ai then
            P.auraColorIndex = ai
            if P.COLORS[ai].c then SETTINGS.AuraColor = P.COLORS[ai].c end
        end
        if not (SETTINGS.AuraRing or SETTINGS.AuraParticles or SETTINGS.AuraShapes) then
            SETTINGS.AuraRing = true; SETTINGS.AuraParticles = true; SETTINGS.AuraShapes = true
        end
    end
    SETTINGS.FireEnabled = st.fire == true
    SETTINGS.AuraMaterial = Enum.Material[st.auraMaterial or "Neon"] or Enum.Material.Neon
    pcall(function() NB.btn.auraMat.Text = "🧱 Материал ауры: " .. string.upper(tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "")) end)
    if ORBIT.extras and ORBIT.extras.setAtmo then
        if st.atmo then
            pcall(ORBIT.extras.setAtmo, true, st.atmo.type, st.atmo.intensity, st.atmo.size)
        elseif st.fire ~= nil or st.aura ~= nil then
            pcall(ORBIT.extras.setAtmo, false)
        end
    end
    ORBIT.applyColor()
    ORBIT.rebuildAllRings()
    ORBIT.setupAura()
    ORBIT.setupFire()
    NB.refreshAllLabels()
    ORBIT.notify("🎭 Стиль: " .. tostring(st.name), Color3.fromRGB(220, 200, 255), 2)
end
for i, b in ipairs(NB.styleBtns) do
    onClick(b, function() NB.applyStyle(NB.styleDefs[i]) end)
end

do
    NB.amIdx = 1
    for i, m in ipairs(NB.AURA_MATERIALS) do
        if m == tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "") then NB.amIdx = i; break end
    end
    onClick(NB.btn.auraMat, function()
        NB.amIdx = NB.amIdx % #NB.AURA_MATERIALS + 1
        local mName = NB.AURA_MATERIALS[NB.amIdx]
        SETTINGS.AuraMaterial = Enum.Material[mName] or Enum.Material.Neon
        NB.btn.auraMat.Text = "🧱 Материал ауры: " .. string.upper(mName)
        ORBIT.setupAura()
    end)
    NB.btn.auraMat.Text = "🧱 Материал ауры: " .. string.upper((tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "")))
end

NB.AURA_GLOW_STEPS = {0, 0.5, 1, 2}
NB.refreshAuraFx = function()
    local st = ORBIT.AURA_PARTICLE_STYLES and ORBIT.AURA_PARTICLE_STYLES[SETTINGS.AuraParticleStyle or 1]
    NB.btn.auraPartStyle.Text = "✨ Частицы ауры: " .. (st and st.name or "ИСКРЫ")
    local g = SETTINGS.AuraGlow
    if g == nil then g = 1 end
    NB.btn.auraGlow.Text = "💡 Свечение ауры: " .. (g <= 0 and "ВЫКЛ" or ("×" .. tostring(g)))
end
onClick(NB.btn.auraPartStyle, function()
    local n = ORBIT.AURA_PARTICLE_STYLES and #ORBIT.AURA_PARTICLE_STYLES or 3
    SETTINGS.AuraParticleStyle = ((SETTINGS.AuraParticleStyle or 1) % n) + 1
    NB.refreshAuraFx()
    ORBIT.setupAura()
end)
onClick(NB.btn.auraGlow, function()
    local cur = SETTINGS.AuraGlow
    if cur == nil then cur = 1 end
    local nextVal = NB.AURA_GLOW_STEPS[1]
    for i, v in ipairs(NB.AURA_GLOW_STEPS) do
        if math.abs(v - cur) < 0.01 then nextVal = NB.AURA_GLOW_STEPS[i % #NB.AURA_GLOW_STEPS + 1]; break end
    end
    SETTINGS.AuraGlow = nextVal
    NB.refreshAuraFx()
    ORBIT.setupAura()
end)
NB.refreshAuraFx()

onClick(NB.btn.fpsToggle, function()
    topBar.Visible = not topBar.Visible
    NB.btn.fpsToggle.Text = "📊 FPS-панель: " .. NB.onOff(topBar.Visible)
end)

-- ============================================================
--       ОБЩЕЕ ОБНОВЛЕНИЕ ПОДПИСЕЙ
-- ============================================================
NB.onOff = function(v) return v and "ВКЛ" or "ВЫКЛ" end

NB.refreshAllLabels = function()
    pcall(function() if NB.btn.mode and NB.modeLabel then NB.btn.mode.Text = NB.modeLabel() end end)
    if ORBIT.enabled then
        NB.btn.toggle.Text = "🟢 ВКЛЮЧЕНО"; NB.btn.toggle.TextColor3 = Color3.fromRGB(0,255,120); NB.btn.toggle.BackgroundColor3 = Color3.fromRGB(40,50,40)
    else
        NB.btn.toggle.Text = "🔴 ВЫКЛЮЧЕНО"; NB.btn.toggle.TextColor3 = Color3.fromRGB(255,80,80); NB.btn.toggle.BackgroundColor3 = Color3.fromRGB(50,35,40)
    end
    local allOn = true
    for ri = 2, 5 do NB.refreshRingButton(ri); if not rings[ri].enabled then allOn = false end end
    NB.btn.allRings.Text = allOn and "⭕ Все кольца: ВЫКЛ" or "⭕ Все кольца: ВКЛ"
    NB.btn.botAutoCollect.Text = "🎁 Автосбор: " .. NB.onOff(ORBIT.botSettings.AutoCollect)
    NB.btn.botRadius.Text = "📏 Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st"
    NB.btn.botShowRing.Text = "👤 Кольцо как у игрока: " .. NB.onOff(ORBIT.botSettings.ShowPlayerRing)
    NB.btn.botSkin.Text = "🎭 Скин как у меня: " .. NB.onOff(ORBIT.botSettings.UseMySkin)
    NB.btn.esp.Text = "👁️ ESP игроков: " .. NB.onOff(ORBIT.ESP and ORBIT.ESP.Enabled)
    NB.btn.shapeCat.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    NB.btn.shape.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    NB.btn.shapeMode.Text = "🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name
    NB.btn.shapeSize.Text = "🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    NB.btn.color.Text = "🎨 Цвет: " .. P.COLORS[P.colorIndex].name
    NB.btn.gradient.Text = "🌈 Градиент: " .. NB.onOff(SETTINGS.GradientEnabled)
    NB.btn.light.Text = "💡 Свет: " .. NB.onOff(SETTINGS.LightEnabled)
    NB.btn.nameBtn.Text = "🏷️ Имена блоков: " .. NB.onOff(SETTINGS.ShowBlockNames)
    NB.btn.autoSwap.Text = "🎭 Автосмена: " .. NB.onOff(SETTINGS.AutoShapeSwap)
    NB.btn.orbit.Text = "📏 Орбита: " .. P.ORBIT[P.orbitIndex].name
    NB.btn.spread.Text = "📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name
    NB.btn.height.Text = "⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name
    NB.btn.speed.Text = "⚡ Множитель: " .. P.SPEED[P.speedIndex].name
    NB.btn.speedMode.Text = "⚙️ Режим: " .. P.SPEED_MODE[P.speedModeIndex].name
    NB.btn.direction.Text = "🔃 Направление: " .. P.DIRECTION[P.directionIndex].name
    NB.btn.orbitPattern.Text = "🌀 Узор: " .. tostring(SETTINGS.OrbitPattern)
    NB.btn.spin.Text = ORBIT.spinResetting and "↩️ Вращение: ВОЗВРАТ" or "↩️ Вращение в 0"
    NB.btn.spinAxis.Text = "🔄 Кручение оси: " .. NB.onOff(ORBIT.spinAxisEnabled)
    NB.btn.spinDir.Text = (ORBIT.spinAxisDir == "X") and "↕️ Ось: ВЕРХ/ВНИЗ" or "↔️ Ось: ВЛЕВО/ВПРАВО"
    NB.btn.spinSpeed.Text = "🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
    NB.btn.trail.Text = "🌠 Трейлы: " .. NB.onOff(SETTINGS.TrailEnabled)
    NB.btn.trailLen.Text = "📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    NB.btn.trailWid.Text = "🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    NB.btn.wave.Text = "🌊 Волна: " .. NB.onOff(SETTINGS.WaveEnabled)
    NB.btn.explosion.Text = "💥 Взрыв: " .. NB.onOff(SETTINGS.ExplosionEnabled)
    NB.btn.pulse.Text = "💓 Пульсация: " .. NB.onOff(SETTINGS.PulseEnabled)
    NB.btn.spawnAnim.Text = "🎆 Появление колец: " .. NB.onOff(SETTINGS.SpawnAnim ~= false)
    NB.btn.spawnFlash.Text = "💫 Вспышка при вкл: " .. NB.onOff(SETTINGS.SpawnFlash ~= false)
    NB.btn.aura.Text = "🌀 Аура: " .. NB.onOff(SETTINGS.AuraEnabled)
    NB.btn.auraRing.Text = "⭕ Кольцо: " .. NB.onOff(SETTINGS.AuraRing)
    NB.btn.auraPart.Text = "✨ Частицы: " .. NB.onOff(SETTINGS.AuraParticles)
    NB.btn.auraFig.Text = "🔷 Фигуры: " .. NB.onOff(SETTINGS.AuraShapes)
    NB.btn.auraShape.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    NB.btn.auraColor.Text = "🎨 Цвет ауры: " .. P.COLORS[P.auraColorIndex].name
    NB.btn.auraMat.Text = "🧱 Материал ауры: " .. string.upper((tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "")))
    if NB.refreshAuraFx then NB.refreshAuraFx() end
    NB.btn.auraSize.Text = "📐 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    NB.btn.auraThick.Text = "🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    NB.btn.auraHeight.Text = "⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
    NB.btn.auraShapeScale.Text = "🔍 Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    NB.btn.auraPattern.Text = "🌀 Узор ауры: " .. tostring(SETTINGS.AuraPattern)
    NB.btn.auraSpeed.Text = "⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
    NB.btn.auraDir.Text = "🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name
    NB.btn.auraTrail.Text = "🌠 Трейлы ауры: " .. NB.onOff(SETTINGS.AuraTrailEnabled)
    NB.btn.auraTrailLen.Text = "📏 Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
    NB.btn.auraTrailWid.Text = "🎚️ Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
    NB.btn.auraSpin.Text = "🔄 Кручение: " .. NB.onOff(SETTINGS.AuraSpinEnabled)
    NB.btn.auraSpinAxis.Text = "↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
    NB.btn.auraSpinSpeed.Text = "🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
    NB.btn.auraPulse.Text = "💓 Пульсация ауры: " .. NB.onOff(SETTINGS.AuraPulseEnabled)
    NB.btn.auraLight.Text = "💡 Свет ауры: " .. NB.onOff(SETTINGS.AuraLightEnabled)
    NB.btn.auraLightRange.Text = "📏 Дальность: " .. tostring(SETTINGS.AuraLightRange)
    NB.btn.auraLightBright.Text = "✨ Яркость: " .. tostring(SETTINGS.AuraLightBrightness)
    local mname = (tostring(SETTINGS.Material):gsub("Enum%.Material%.", ""))
    for i, m in ipairs(NB.MATERIALS) do if m == mname then NB.materialIndex = i; break end end
    NB.btn.material.Text = "🎨 Материал: " .. mname:upper()
    NB.btn.transparency.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100 + 0.5) .. "%"
    NB.btn.brightness.Text = "☀️ Яркость: " .. tostring(SETTINGS.GlowIntensity or 1)
    NB.btn.glow.Text = "✨ Свечение: " .. NB.onOff(SETTINGS.GlowEnabled ~= false)
    NB.btn.castShadow.Text = "🌑 Тени: " .. NB.onOff(SETTINGS.CastShadow)
    NB.btn.fire.Text = "🔥 Огонь: " .. NB.onOff(SETTINGS.FireEnabled)
    NB.btn.fireSize.Text = "📏 Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    NB.btn.fireHeat.Text = "🌡️ Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if ORBIT.SOUNDS then
        NB.btn.soundToggle.Text = "🔊 Звуки: " .. NB.onOff(ORBIT.SOUNDS.Enabled)
        NB.btn.soundVolume.Text = "🎵 Громкость: " .. math.floor((ORBIT.SOUNDS.Volume or 1) * 100 + 0.5) .. "%"
        NB.soundVolumeIndex = math.clamp(math.floor((ORBIT.SOUNDS.Volume or 1) * 10 + 0.5) + 1, 1, #NB.VOLUME_STEPS)
    end
    NB.btn.music.Text = "🎵 Музыка: " .. NB.onOff(ORBIT.musicEnabled)
    for i, v in ipairs(NB.HEART_STEPS) do if math.abs(v - SETTINGS.HeartScale) < 0.01 then NB.heartScaleIndex = i; break end end
    NB.refreshHeartSizeBtn()
    NB.btn.fpsToggle.Text = "📊 FPS-панель: " .. NB.onOff(topBar.Visible)
    pcall(NB.refreshPerfBtn)
end

-- ============================================================
--       FPS СЧЁТЧИК (верхняя панель)
-- ============================================================
task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        local fps = NB.myFps or 0
        local bots = 0; for _ in pairs(ORBIT.bots or {}) do bots = bots + 1 end
        local ringsOn = 0; for ri = 1, 5 do if rings[ri].enabled then ringsOn = ringsOn + 1 end end
        local icon = (ORBIT.PLATFORM == "mobile") and "📱" or "💻"
        P4.topBarLabel.Text = string.format("%s ОРБИТА %s  |  FPS: %d  |  🤖 %d  |  ⭕ %d/5",
            icon, tostring(ORBIT.version), fps, bots, ringsOn)
        if fps >= 50 then P4.topBarLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
        elseif fps >= 30 then P4.topBarLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
        else P4.topBarLabel.TextColor3 = Color3.fromRGB(255, 140, 140) end
    end
end)

task.spawn(function() while screenGui and screenGui.Parent do task.wait(1); pcall(NB.refreshPerfBtn) end end)

-- ============================================================
--       ПЕРЕТАСКИВАНИЕ ГЛАВНОЙ КНОПКИ
-- ============================================================
NB.dragging = false
NB.dragStart = nil
NB.startPos = nil

mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        NB.dragging = true
        NB.dragMoved = false
        NB.dragStart = input.Position
        NB.startPos = mainBtn.Position
    end
end)

UIK.connect(UIS.InputChanged, function(input)
    if not NB.dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - NB.dragStart
        if d.Magnitude > 6 then NB.dragMoved = true end
        if NB.dragMoved then
            local abs = screenGui.AbsoluteSize
            mainBtn.Position = UDim2.fromOffset(
                math.clamp(NB.startPos.X.Offset + d.X, 0, math.max(0, abs.X - 56)),
                math.clamp(NB.startPos.Y.Offset + d.Y, 0, math.max(0, abs.Y - 56))
            )
        end
    end
end)

UIK.connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        NB.dragging = false
    end
end)

-- ============================================================
--       API + ФИТ
-- ============================================================
ORBIT.ui = ORBIT.ui or {}
ORBIT.ui.screenGui = screenGui
ORBIT.ui.panel = panel
ORBIT.ui.window = window
ORBIT.ui.onClick = onClick
for k, v in pairs(UIK) do if ORBIT.ui[k] == nil then ORBIT.ui[k] = v end end
ORBIT.ui.topBar = topBar
ORBIT.ui.openShopBtn = NB.btn.openShop
ORBIT.ui.openEditorBtn = NB.btn.openEditor

ORBIT.ui.applyStyleByName = function(name)
    if not name then return false end
    for _, st in ipairs(NB.styleDefs) do
        if st.name == name then NB.applyStyle(st); return true end
    end
    for _, st in ipairs(NB.elementDefs or {}) do
        if st.name == name then NB.applyStyle(st); return true end
    end
    return false
end

ORBIT.ui.refreshAuraFx = function()
    if NB.refreshAuraFx then NB.refreshAuraFx() end
end
ORBIT.ui.setGlow = function(on)
    on = on and true or false
    SETTINGS.GlowEnabled = on
    NB.btn.glow.Text = "✨ Свечение: " .. (on and "ВКЛ" or "ВЫКЛ")
    if on then
        NB.btn.glow.BackgroundColor3 = Color3.fromRGB(35,60,50); NB.btn.glow.TextColor3 = Color3.fromRGB(180,255,220)
    else
        NB.btn.glow.BackgroundColor3 = Color3.fromRGB(45,45,65); NB.btn.glow.TextColor3 = Color3.fromRGB(200,200,220)
    end
    for _, ring in pairs(rings) do
        for _, d in ipairs(ring.blocks) do
            if d.light then d.light.Enabled = on end
        end
    end
end

ORBIT.ui.open = function() NB.setPanel(true) end
ORBIT.ui.close = function() NB.setPanel(false) end
ORBIT.ui.toggle = function() NB.setPanel(not NB.panelOpen) end
ORBIT.ui.openSansPhraseMenu = function() NB.openSansPhraseMenu() end

ORBIT.ui.fitToScreen = function(frame, w, h)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    local sc = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", frame)
    local abs = screenGui.AbsoluteSize
    sc.Scale = math.min(1, (abs.X - 20) / w, (abs.Y - 20) / h)
end

UIK.connect(UIS.InputBegan, function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.L then
        if ORBIT.ui and ORBIT.ui.toggle then ORBIT.ui.toggle() end
    end
end)

-- ============================================================
--       СТАРТ
-- ============================================================
local prevUnload = ORBIT.unload
ORBIT.unload = function()
    for _, c in ipairs(UIK._conns) do pcall(function() c:Disconnect() end) end
    UIK._conns = {}
    if prevUnload then pcall(prevUnload) end
end

-- v24.2-fix1: не теряем предыдущий ORBIT.start (если уже был)
local prevStart = ORBIT.start
ORBIT.start = function()
    local genv = rawget(_G, "getgenv") and getgenv() or _G
    if genv._OrbitLoaderGui then pcall(function() genv._OrbitLoaderGui:Destroy() end) end
    if ORBIT.startLogic then pcall(ORBIT.startLogic) end
    pcall(NB.refreshAllLabels)
    ORBIT.notify("✨ ОРБИТА " .. tostring(ORBIT.version) .. " запущена!", Color3.fromRGB(200,200,255), 3)
    -- если кто-то определил start ДО нас и он не равен startLogic — вызываем
    if prevStart and prevStart ~= ORBIT.startLogic and prevStart ~= ORBIT.start then
        pcall(prevStart)
    end
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ P4b v24.2-fix1 (крестики стихий + фразы Санса + фигуры)", Color3.fromRGB(180,255,180), 3) end

-- v24.2-fix1: магазин и мини-игра грузятся ТОЛЬКО загрузчиком (orbit_loader.lua).
-- Здесь больше никакого fetchRun — иначе двойная загрузка и перезапись обработчиков.

-- ============================================================
--       ЭКСПОРТ
-- ============================================================
ORBIT.P4b = { ready = true }

return true
