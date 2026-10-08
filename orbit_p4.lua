-- ORBIT v24.0 | orbit_p4.lua
-- v24.0: вкладка «ЕЩЁ» — кнопки «Собери Гастера», «Гастер-оружие», «Режим: Санс/Обычный»;
--        подгрузка shop/minigame пропускается, если запущено через v24-загрузчик.
--        (новые кнопки лежат в таблице UIK, а не в local — у файла почти исчерпан лимит 200 локальных)
-- ОРБИТА v23.9 — P4: UI
-- v23.5: переделан UI — шапка, поиск, 9 вкладок, сворачиваемые секции, 2 столбца.
-- v23.6: секция SHARE + кнопки 📤 у сохранений + 📥 импорт.
-- v23.7: добавлена кнопка «🤖 Помощник».
-- v23.8: ФИКС — applyStyleByName был объявлен до создания ORBIT.ui. Перенесён вниз.
-- v23.9: SHARE упрощён — одно большое поле + кнопка ЗАГРУЗИТЬ. Одна кнопка
--        разбирается сама: фигура / сохранение / настройки / ссылка.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P4] Часть 1 не загружена!"); return end

local Players      = ORBIT.Players
local LocalPlayer  = ORBIT.LocalPlayer
local PlayerGui    = ORBIT.PlayerGui
local TweenService = ORBIT.TweenService
local UIS          = ORBIT.UIS or game:GetService("UserInputService")
local RunService   = ORBIT.RunService

local SETTINGS = ORBIT.SETTINGS
local P        = ORBIT.P
local rings    = ORBIT.rings
local statsData = ORBIT.statsData
local SHAPE_PRESETS = ORBIT.SHAPE_PRESETS
if not P then warn("[Orbit P4] P не передан"); return end
if not SHAPE_PRESETS then warn("[Orbit P4] Часть 2 не загружена"); return end
if not ORBIT.startUpdateLoop then warn("[Orbit P4] Часть 3 не загружена"); return end
if not ORBIT.createBot then warn("[Orbit P4] Боты не найдены в p3!"); return end

local PLATFORM = ORBIT.PLATFORM or "pc"
local IS_MOBILE = (PLATFORM == "mobile")

-- ==================== ОКНО ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "_OrbitMain_" .. tostring(math.random(100000, 999999))
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ORBIT.protectGui(screenGui)
do
    local okp = pcall(function() screenGui.Parent = ORBIT.getSafeParent() end)
    if not okp or not screenGui.Parent then screenGui.Parent = PlayerGui end
end
(rawget(_G, "getgenv") and getgenv() or _G)._OrbitMainGui = screenGui

-- ============================================================
--       ОБРАБОТЧИК КЛИКОВ (Android / Delta)
-- ============================================================
local function onClick(btn, fn, releaseOnly)
    local deb = false
    local touchStart = nil
    local function call()
        if deb then return end
        deb = true
        task.delay(0.12, function() deb = false end)
        if ORBIT.playClick then ORBIT.playClick() end
        local ok, err = pcall(fn)
        if not ok then warn("[Orbit] " .. tostring(err)) end
    end
    local function inScroll()
        return releaseOnly or btn:GetAttribute("ReleaseOnly")
            or btn:FindFirstAncestorOfClass("ScrollingFrame") ~= nil
    end
    btn.MouseButton1Down:Connect(function() if not inScroll() then call() end end)
    btn.MouseButton1Click:Connect(function() if inScroll() then call() end end)
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchStart = input.Position
            if not inScroll() then call() end
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and touchStart then
            local moved = (input.Position - touchStart).Magnitude
            touchStart = nil
            if inScroll() and moved < 12 then call() end
        end
    end)
    btn.Activated:Connect(call)
end

local NB = {}

-- ============================================================
--       FPS-СЧЁТЧИК
-- ============================================================
local myFps = 60
local myFpsFrames = 0
local myFpsLastCheck = tick()

task.spawn(function()
    while screenGui and screenGui.Parent do
        myFpsFrames = myFpsFrames + 1
        local now = tick()
        if now - myFpsLastCheck >= 1 then
            myFps = math.floor(myFpsFrames / (now - myFpsLastCheck))
            myFpsFrames = 0
            myFpsLastCheck = now
        end
        RunService.RenderStepped:Wait()
    end
end)

-- ==================== FPS ПАНЕЛЬ ====================
local topBar = Instance.new("Frame")
topBar.Name = "_OrbitTopBar"
topBar.Size = UDim2.new(0, 380, 0, 26)
topBar.Position = UDim2.new(0.5, -190, 0, 4)
topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.ZIndex = 5
topBar.Parent = screenGui
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
do
    local topBarStroke = Instance.new("UIStroke", topBar)
    topBarStroke.Color = Color3.fromRGB(120, 120, 255)
    topBarStroke.Thickness = 1
    topBarStroke.Transparency = 0.4
end

local topBarLabel = Instance.new("TextLabel")
topBarLabel.Size = UDim2.new(1, -34, 1, 0)
topBarLabel.Position = UDim2.new(0, 6, 0, 0)
topBarLabel.BackgroundTransparency = 1
topBarLabel.Text = "✨ ОРБИТА " .. tostring(ORBIT.version) .. "  |  FPS: --  |  🤖 0  |  ⭕ 0"
topBarLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
topBarLabel.Font = Enum.Font.GothamBold
topBarLabel.TextSize = 12
topBarLabel.TextXAlignment = Enum.TextXAlignment.Center
topBarLabel.ZIndex = 6
topBarLabel.Parent = topBar

local topBarCloseBtn = Instance.new("TextButton")
topBarCloseBtn.Size = UDim2.new(0, 22, 0, 22)
topBarCloseBtn.Position = UDim2.new(1, -26, 0, 2)
topBarCloseBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 40)
topBarCloseBtn.BackgroundTransparency = 0.3
topBarCloseBtn.TextColor3 = Color3.fromRGB(255, 140, 150)
topBarCloseBtn.Font = Enum.Font.GothamBold
topBarCloseBtn.TextSize = 13
topBarCloseBtn.Text = "✖"
topBarCloseBtn.AutoButtonColor = false
topBarCloseBtn.ZIndex = 7
topBarCloseBtn.Parent = topBar
Instance.new("UICorner", topBarCloseBtn).CornerRadius = UDim.new(0, 6)

onClick(topBarCloseBtn, function()
    topBar.Visible = false
    if NB.fpsToggle then NB.fpsToggle.Text = "📊 FPS-панель: ВЫКЛ" end
    if ORBIT.notify then ORBIT.notify("📊 FPS-панель скрыта (включить: вкладка СИСТЕМА)", Color3.fromRGB(200, 200, 255), 2) end
end)

-- ==================== КНОПКА ====================
local mainBtn = Instance.new("TextButton")
mainBtn.Size = UDim2.new(0, IS_MOBILE and 60 or 56, 0, IS_MOBILE and 60 or 56)
mainBtn.Position = UDim2.new(0, 20, 0, 100)
mainBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainBtn.BackgroundTransparency = 0.1
mainBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
mainBtn.Font = Enum.Font.GothamBold
mainBtn.TextSize = IS_MOBILE and 26 or 24
mainBtn.Text = "✨"
mainBtn.AutoButtonColor = false
mainBtn.Parent = screenGui
Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 14)
do
    local mainStroke = Instance.new("UIStroke", mainBtn)
    mainStroke.Color = Color3.fromRGB(120, 120, 255)
    mainStroke.Thickness = 1.5
end
mainBtn:SetAttribute("ReleaseOnly", true)

-- ==================== ПАНЕЛЬ ====================
local PANEL_W = IS_MOBILE and 340 or 368
local BTN_H = IS_MOBILE and 40 or 32
local BTN_H_BIG = IS_MOBILE and 46 or 38
local S_STEP = 4

local shadow = Instance.new("Frame")
shadow.Name = "_OrbitShadow"
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.62
shadow.BorderSizePixel = 0
shadow.Visible = false
shadow.ZIndex = 0
shadow.Parent = screenGui
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 18)

local window = Instance.new("Frame")
window.Name = "_OrbitWindow"
window.Size = UDim2.new(0, PANEL_W, 0, 520)
window.Position = UDim2.new(0, 90, 0, 5)
window.BackgroundColor3 = Color3.fromRGB(20, 17, 34)
window.BackgroundTransparency = 0.03
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Visible = false
window.Parent = screenGui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 14)
do
    local g = Instance.new("UIGradient", window)
    g.Color = ColorSequence.new(Color3.fromRGB(34, 26, 58), Color3.fromRGB(14, 12, 24))
    g.Rotation = 90
    local st = Instance.new("UIStroke", window)
    st.Thickness = 1.5; st.Transparency = 0.25; st.Color = Color3.fromRGB(255, 255, 255)
    local sg = Instance.new("UIGradient", st)
    sg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 110, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 200)),
    })
    sg.Rotation = 45
end
local function syncShadow()
    shadow.Position = UDim2.new(window.Position.X.Scale, window.Position.X.Offset - 5, window.Position.Y.Scale, window.Position.Y.Offset - 2)
    shadow.Size = UDim2.new(0, window.Size.X.Offset + 10, 0, window.Size.Y.Offset + 10)
end
window:GetPropertyChangedSignal("Position"):Connect(syncShadow)
window:GetPropertyChangedSignal("Size"):Connect(syncShadow)
window:GetPropertyChangedSignal("Visible"):Connect(function() shadow.Visible = window.Visible end)

local searchBox, panelCloseBtn
do
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 46); header.BackgroundTransparency = 1; header.ZIndex = 3
    header.Parent = window
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 88, 1, 0); title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "✨ ОРБИТА" .. (IS_MOBILE and " 📱" or " 💻")
    title.TextColor3 = Color3.fromRGB(225, 215, 255)
    title.Font = Enum.Font.GothamBold; title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 3
    title.Parent = header

    searchBox = Instance.new("TextBox")
    searchBox.Name = "Search"
    searchBox.Size = UDim2.new(1, -150, 0, 34); searchBox.Position = UDim2.new(0, 100, 0, 6)
    searchBox.BackgroundColor3 = Color3.fromRGB(38, 32, 62)
    searchBox.TextColor3 = Color3.fromRGB(240, 235, 255)
    searchBox.PlaceholderText = "🔍 Поиск функции..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(140, 130, 175)
    searchBox.Font = Enum.Font.GothamBold; searchBox.TextSize = 12
    searchBox.Text = ""; searchBox.ClearTextOnFocus = false
    searchBox.TextXAlignment = Enum.TextXAlignment.Left; searchBox.ZIndex = 3
    searchBox.Parent = header
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 10)
    local pad = Instance.new("UIPadding", searchBox); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 30)
    local ss = Instance.new("UIStroke", searchBox); ss.Color = Color3.fromRGB(120, 100, 200); ss.Transparency = 0.5

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 28, 0, 28); clearBtn.Position = UDim2.new(1, -30, 0.5, -14)
    clearBtn.BackgroundTransparency = 1; clearBtn.Text = "✕"; clearBtn.Visible = false
    clearBtn.TextColor3 = Color3.fromRGB(200, 190, 240); clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 14; clearBtn.ZIndex = 4
    clearBtn.Parent = searchBox
    onClick(clearBtn, function() searchBox.Text = "" end, true)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() clearBtn.Visible = searchBox.Text ~= "" end)

    panelCloseBtn = Instance.new("TextButton")
    panelCloseBtn.Size = UDim2.new(0, 36, 0, 34); panelCloseBtn.Position = UDim2.new(1, -44, 0, 6)
    panelCloseBtn.BackgroundColor3 = Color3.fromRGB(80, 36, 52)
    panelCloseBtn.TextColor3 = Color3.fromRGB(255, 150, 165)
    panelCloseBtn.Font = Enum.Font.GothamBold; panelCloseBtn.TextSize = 15
    panelCloseBtn.Text = "✖"; panelCloseBtn.AutoButtonColor = true; panelCloseBtn.ZIndex = 3
    panelCloseBtn.Parent = header
    Instance.new("UICorner", panelCloseBtn).CornerRadius = UDim.new(0, 10)
end

local TABS = {
    { id = "main",    name = "⚡ ГЛАВНАЯ" },
    { id = "look",    name = "🎨 ВИД" },
    { id = "motion",  name = "🛰️ ДВИЖЕНИЕ" },
    { id = "aura",    name = "🌀 АУРА" },
    { id = "fx",      name = "✨ ЭФФЕКТЫ" },
    { id = "bots",    name = "🤖 БОТЫ" },
    { id = "players", name = "👥 ИГРОКИ" },
    { id = "more",    name = "🛒 ЕЩЁ" },
    { id = "sys",     name = "💾 СИСТЕМА" },
}
local SECTION_TAB = {
    { "ОСНОВНОЕ", "main" }, { "СТИЛИ", "main" }, { "СТИХИИ", "main" }, { "ПРОИЗВОДИТЕЛЬНОСТЬ", "main" },
    { "ВНЕШНИЙ ВИД", "look" }, { "ГРАФИКА", "look" }, { "ДОПОЛНИТЕЛЬНО", "look" },
    { "ДВИЖЕНИЕ", "motion" }, { "КРУЧЕНИЕ", "motion" },
    { "СВЕТ АУРЫ", "aura" }, { "АУРА", "aura" },
    { "ЭФФЕКТЫ", "fx" }, { "ЭМОЦИИ", "fx" }, { "ОГОНЬ", "fx" },
    { "БОТЫ", "bots" },
    { "ESP", "players" }, { "ЛЮДИ", "players" }, { "ЗАЩИТА", "players" },
    { "ЗВУКИ", "more" }, { "МУЗЫКА", "more" }, { "МАГАЗИН", "more" },
    { "SHARE", "sys" }, { "СОХРАНЕНИЯ", "sys" }, { "СИСТЕМА", "sys" }, { "СТАТИСТИКА", "sys" },
}

local panel
local relayout
local setTab
local makeBigSection, makeButton
local UIK = { TABS = TABS, _conns = {} }
UIK.connect = function(sig, fn)
    local c = sig:Connect(fn); UIK._conns[#UIK._conns + 1] = c; return c
end

do
    local tabBar = Instance.new("ScrollingFrame")
    tabBar.Name = "Tabs"
    tabBar.Position = UDim2.new(0, 0, 0, 46); tabBar.Size = UDim2.new(1, 0, 0, 38)
    tabBar.BackgroundTransparency = 1; tabBar.BorderSizePixel = 0
    tabBar.ScrollBarThickness = 0; tabBar.ScrollingDirection = Enum.ScrollingDirection.X
    tabBar.CanvasSize = UDim2.new(0, 0, 0, 0); tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabBar.ZIndex = 3; tabBar.Parent = window
    local tl = Instance.new("UIListLayout", tabBar)
    tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 5)
    tl.SortOrder = Enum.SortOrder.LayoutOrder; tl.VerticalAlignment = Enum.VerticalAlignment.Center
    local tp = Instance.new("UIPadding", tabBar); tp.PaddingLeft = UDim.new(0, 8); tp.PaddingRight = UDim.new(0, 8)

    panel = Instance.new("ScrollingFrame")
    panel.Name = "Content"
    panel.Position = UDim2.new(0, 0, 0, 86); panel.Size = UDim2.new(1, 0, 1, -86)
    panel.BackgroundTransparency = 1; panel.BorderSizePixel = 0
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.ScrollBarThickness = IS_MOBILE and 5 or 4
    panel.ScrollBarImageColor3 = Color3.fromRGB(140, 120, 255)
    panel.ScrollingDirection = Enum.ScrollingDirection.Y
    panel.ZIndex = 2; panel.Parent = window

    local sections, activeTab, built = {}, "main", false
    local currentSection = nil
    local chips = {}
    local emptyLbl = Instance.new("TextLabel")
    emptyLbl.Size = UDim2.new(1, -24, 0, 50); emptyLbl.BackgroundTransparency = 1
    emptyLbl.TextColor3 = Color3.fromRGB(150, 140, 185); emptyLbl.Font = Enum.Font.Gotham
    emptyLbl.TextSize = 12; emptyLbl.TextWrapped = true; emptyLbl.Visible = false
    emptyLbl:SetAttribute("_reg", true); emptyLbl.Parent = panel

    local function lowerRu(s)
        local out = {}
        for _, c in utf8.codes(s) do
            if c >= 0x410 and c <= 0x42F then c = c + 32
            elseif c == 0x401 or c == 0x451 then c = 0x435
            elseif c >= 65 and c <= 90 then c = c + 32 end
            out[#out + 1] = utf8.char(c)
        end
        return table.concat(out)
    end
    local function normText(s)
        s = tostring(s or "")
        local ok, r = pcall(lowerRu, s)
        return ok and r or s:lower()
    end
    local function stem(w)
        local ok, n = pcall(utf8.len, w)
        if ok and n and n >= 4 then
            local cut = utf8.offset(w, -1)
            if cut then return w:sub(1, cut - 1) end
        end
        return w
    end

    local function tabFor(title)
        for _, pair in ipairs(SECTION_TAB) do
            if string.find(title, pair[1], 1, true) then return pair[2] end
        end
        return "more"
    end

    local function itemText(it)
        local inst = it.inst
        local t = ""
        if inst:IsA("TextBox") then t = inst.PlaceholderText
        elseif inst:IsA("TextButton") or inst:IsA("TextLabel") then t = inst.Text end
        return normText(t .. " " .. tostring(inst:GetAttribute("Search") or ""))
    end

    local function styleHeader(sec)
        sec.arrow.Text = sec.collapsed and "▸" or "▾"
    end

    local function registerControl(inst, h, half)
        local sec = currentSection
        if not sec then return end
        local ctl = { inst = inst, h = h, half = half and true or false, sec = sec }
        sec.items[#sec.items + 1] = ctl
        return ctl
    end

    local function newSection(text, color, tabId)
        local sec = { title = text, color = color or Color3.fromRGB(60, 60, 100), tab = tabId or tabFor(text),
            collapsed = false, items = {} }
        local holder = Instance.new("TextButton")
        holder.Size = UDim2.new(1, -16, 0, 30)
        holder.BackgroundColor3 = sec.color; holder.BackgroundTransparency = 0.15
        holder.AutoButtonColor = false; holder.Text = ""; holder.BorderSizePixel = 0; holder.ZIndex = 2
        holder:SetAttribute("_reg", true)
        holder.Parent = panel
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)
        local gr = Instance.new("UIGradient", holder)
        gr.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170)); gr.Rotation = 0
        local stripe = Instance.new("Frame")
        stripe.Size = UDim2.new(0, 4, 1, -8); stripe.Position = UDim2.new(0, 5, 0, 4)
        stripe.BackgroundColor3 = Color3.fromRGB(255, 255, 255); stripe.BackgroundTransparency = 0.3
        stripe.BorderSizePixel = 0; stripe.ZIndex = 3; stripe.Parent = holder
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 2)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -44, 1, 0); lbl.Position = UDim2.new(0, 16, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(245, 242, 255); lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 3
        lbl.Parent = holder
        local arrow = Instance.new("TextLabel")
        arrow.Size = UDim2.new(0, 26, 1, 0); arrow.Position = UDim2.new(1, -30, 0, 0)
        arrow.BackgroundTransparency = 1; arrow.Text = "▾"
        arrow.TextColor3 = Color3.fromRGB(235, 230, 255); arrow.Font = Enum.Font.GothamBold
        arrow.TextSize = 14; arrow.ZIndex = 3; arrow.Parent = holder
        sec.header, sec.arrow = holder, arrow
        sections[#sections + 1] = sec
        currentSection = sec
        onClick(holder, function() sec.collapsed = not sec.collapsed; styleHeader(sec); relayout() end, true)
        return sec
    end

    makeBigSection = function(text, _, color)
        return newSection(text, color).header
    end

    makeButton = function(text, _, h, bgColor, textColor)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -16, 0, h or BTN_H)
        b.BackgroundColor3 = bgColor or Color3.fromRGB(45, 45, 66)
        b.TextColor3 = textColor or Color3.fromRGB(235, 235, 255)
        b.Font = Enum.Font.GothamBold
        b.TextScaled = true
        b.Text = text
        b.AutoButtonColor = true
        b.ZIndex = 2
        b:SetAttribute("_reg", true)
        b.Parent = panel
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
        local tc = Instance.new("UITextSizeConstraint", b)
        tc.MaxTextSize = IS_MOBILE and 14 or 12; tc.MinTextSize = 8
        local pad = Instance.new("UIPadding", b)
        pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
        local gr = Instance.new("UIGradient", b)
        gr.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 205)); gr.Rotation = 90
        local stroke = Instance.new("UIStroke", b)
        stroke.Color = Color3.fromRGB(255, 255, 255); stroke.Thickness = 1; stroke.Transparency = 0.86
        registerControl(b, h or BTN_H, h == nil or h == BTN_H)
        return b
    end

    relayout = function()
        local q = normText(searchBox.Text)
        local words = {}
        for w in q:gmatch("%S+") do words[#words + 1] = stem(w) end
        local searching = #words > 0
        local function matches(txt)
            for _, w in ipairs(words) do
                if not string.find(txt, w, 1, true) then return false end
            end
            return true
        end

        for _, sec in ipairs(sections) do
            sec.header.Visible = false
            for _, it in ipairs(sec.items) do it.inst.Visible = false end
        end

        local y, anyShown = 8, false
        for _, sec in ipairs(sections) do
            local list = {}
            if searching then
                local titleHit = matches(normText(sec.title))
                for _, it in ipairs(sec.items) do
                    if titleHit or matches(itemText(it)) then list[#list + 1] = it end
                end
            elseif sec.tab == activeTab then
                if not sec.collapsed then list = sec.items end
            end
            local show = (searching and #list > 0) or (not searching and sec.tab == activeTab)
            if show then
                anyShown = true
                sec.header.Position = UDim2.new(0, 8, 0, y); sec.header.Visible = true
                styleHeader(sec)
                y = y + 34
                local i = 1
                while i <= #list do
                    local a, b = list[i], list[i + 1]
                    local pair = false
                    if a.half and b and b.half then
                        local la = utf8.len(a.inst.Text) or 99
                        local lb = utf8.len(b.inst.Text) or 99
                        -- v23.6 (I2): на узких экранах (≈320 px) половинки уже — порог короче
                        local maxLen = (window.AbsoluteSize.X < 340) and 20 or 30
                        pair = la <= maxLen and lb <= maxLen
                    end
                    if pair then
                        local h = math.max(a.h, b.h)
                        a.inst.Size = UDim2.new(0.5, -11, 0, h); a.inst.Position = UDim2.new(0, 8, 0, y)
                        b.inst.Size = UDim2.new(0.5, -11, 0, h); b.inst.Position = UDim2.new(0.5, 3, 0, y)
                        a.inst.Visible = true; b.inst.Visible = true
                        y = y + h + S_STEP; i = i + 2
                    else
                        local h = a.h
                        if a.inst:IsA("TextBox") then h = math.max(h, BTN_H) end
                        a.inst.Size = UDim2.new(1, -16, 0, h); a.inst.Position = UDim2.new(0, 8, 0, y)
                        a.inst.Visible = true
                        y = y + h + S_STEP; i = i + 1
                    end
                end
                y = y + 8
            end
        end
        if not anyShown then
            emptyLbl.Text = searching and ("Ничего не найдено по запросу «" .. searchBox.Text .. "»")
                or "— в этой вкладке пока пусто —"
            emptyLbl.Position = UDim2.new(0, 12, 0, 20); emptyLbl.Visible = true
            y = 80
        else
            emptyLbl.Visible = false
        end
        panel.CanvasSize = UDim2.new(0, 0, 0, y + 10)
    end

    local function styleChips()
        local searching = searchBox.Text ~= ""
        for id, chip in pairs(chips) do
            local on = (id == activeTab) and not searching
            chip.BackgroundColor3 = on and Color3.fromRGB(120, 90, 235) or Color3.fromRGB(44, 38, 70)
            chip.TextColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 180, 225)
        end
    end

    setTab = function(id)
        activeTab = id
        local had = searchBox.Text ~= ""
        searchBox.Text = ""
        if not had then relayout() end
        styleChips()
        panel.CanvasPosition = Vector2.new(0, 0)
        panel.Position = UDim2.new(0, 14, 0, 86)
        TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Position = UDim2.new(0, 0, 0, 86) }):Play()
    end

    for i, t in ipairs(TABS) do
        local chip = Instance.new("TextButton")
        chip.Name = "Tab_" .. t.id; chip.LayoutOrder = i
        chip.Size = UDim2.new(0, 0, 0, IS_MOBILE and 32 or 28); chip.AutomaticSize = Enum.AutomaticSize.X
        chip.BackgroundColor3 = Color3.fromRGB(44, 38, 70)
        chip.TextColor3 = Color3.fromRGB(190, 180, 225)
        chip.Font = Enum.Font.GothamBold; chip.TextSize = 12; chip.Text = t.name
        chip.AutoButtonColor = true; chip.ZIndex = 3; chip.Parent = tabBar
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 10)
        local cp = Instance.new("UIPadding", chip); cp.PaddingLeft = UDim.new(0, 12); cp.PaddingRight = UDim.new(0, 12)
        chips[t.id] = chip
        onClick(chip, function() setTab(t.id) end)
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        relayout(); styleChips(); panel.CanvasPosition = Vector2.new(0, 0)
    end)

    panel.ChildAdded:Connect(function(ch)
        if not ch:IsA("GuiObject") or ch:GetAttribute("_reg") then return end
        ch:SetAttribute("_reg", true)
        if not built then
            registerControl(ch, ch.Size.Y.Offset, false)
        else
            task.defer(function()
                if not ch.Parent then return end
                local h = ch.Size.Y.Offset
                if h <= 0 then h = ch.AbsoluteSize.Y end
                if h <= 0 then h = 30 end
                if not UIK._legacySec then
                    UIK._legacySec = newSection("✨  ДОПОЛНИТЕЛЬНО (МОДУЛИ)", Color3.fromRGB(90, 70, 130), "more")
                end
                currentSection = UIK._legacySec
                registerControl(ch, h, false)
                relayout()
            end)
        end
    end)

    UIK.finishBuild = function() built = true; styleChips(); relayout() end
    UIK.addSection = function(title, color, tabId) return newSection(title, color, tabId).header end
    UIK.addControl = function(inst, h, half)
        inst:SetAttribute("_reg", true); inst.Parent = panel
        registerControl(inst, h or inst.Size.Y.Offset, half); relayout()
    end
    UIK.makeButton = function(text, h, bg, fg) local b = makeButton(text, 0, h, bg, fg); relayout(); return b end
    UIK.setTab = function(id) setTab(id) end
    UIK.relayout = function() relayout() end
end

-- ============ ОСНОВНОЕ ============
local yCursor = 40
local S_STEP = 4

makeBigSection("⚡  ОСНОВНОЕ", yCursor, Color3.fromRGB(60, 60, 100)); yCursor = yCursor + 30
local toggleBtn     = makeButton("🟢 ВКЛЮЧЕНО", yCursor, BTN_H_BIG, Color3.fromRGB(40,50,40), Color3.fromRGB(0,255,120)); yCursor = yCursor + BTN_H_BIG + S_STEP
local allRingsBtn   = makeButton("⭕ Все кольца: ВКЛ", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring2Btn      = makeButton("➕ Кольцо 2", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring3Btn      = makeButton("➕ Кольцо 3", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring4Btn      = makeButton("➕ Кольцо 4", yCursor); yCursor = yCursor + BTN_H + S_STEP
local ring5Btn      = makeButton("➕ Кольцо 5", yCursor); yCursor = yCursor + BTN_H + S_STEP + 6

NB.styleDefs = {
    { name = "🌈 Радуга-вихрь", bg = Color3.fromRGB(70,40,95), fg = Color3.fromRGB(255,200,255),
      color = "РАДУГА", pattern = "Спираль", speed = 2.0, orbit = "L", size = "M", shape = "ЗВЕЗДА",
      rings = {true,true,true,false,false}, material = "Neon", trail = true },
    { name = "❄️ Ледяной", bg = Color3.fromRGB(35,60,90), fg = Color3.fromRGB(190,235,255),
      color = "ЛЁД", pattern = "Круг", speed = 1.0, orbit = "M", size = "M", shape = "РОМБ",
      rings = {true,true,false,false,false}, material = "Glass", transparency = 0.15, aura = true, auraColor = "ЛЁД" },
    { name = "🔥 Огненный", bg = Color3.fromRGB(95,40,15), fg = Color3.fromRGB(255,190,120),
      color = "ОГОНЬ", pattern = "Хаос", speed = 1.5, orbit = "M", size = "M", shape = "МОЛНИЯ",
      rings = {true,true,true,false,false}, material = "Neon", trail = true, fire = true },
    { name = "👑 Королевский", bg = Color3.fromRGB(85,70,20), fg = Color3.fromRGB(255,235,150),
      color = "ЗОЛОТОЙ", pattern = "Волна", speed = 1.0, orbit = "L", size = "M", shape = "ПИРАМИДА",
      rings = {true,true,true,false,false}, material = "Metal", aura = true, auraColor = "ЗОЛОТОЙ" },
    { name = "🪨 Скала-шоу", bg = Color3.fromRGB(60,35,85), fg = Color3.fromRGB(230,200,255),
      color = "ПУРПУРНЫЙ", pattern = "Круг", speed = 1.0, orbit = "L", size = "L", shape = "СКАЛА",
      rings = {true,false,false,false,false}, material = "SmoothPlastic", pulse = true },
    { name = "👻 Призрак", bg = Color3.fromRGB(50,45,80), fg = Color3.fromRGB(220,210,255),
      color = "СИРЕНЕВЫЙ", pattern = "Восьмёрка", speed = 1.0, orbit = "M", size = "M", shape = "ЧЕРЕП",
      rings = {true,true,false,false,false}, material = "ForceField", trail = true, aura = true, auraColor = "СИРЕНЕВЫЙ" },
    { name = "🎲 Случайный стиль", bg = Color3.fromRGB(45,70,60), fg = Color3.fromRGB(190,255,220), random = true },
}
makeBigSection("🎭  СТИЛИ — ОДНО НАЖАТИЕ", yCursor, Color3.fromRGB(130, 70, 150)); yCursor = yCursor + 30
NB.styleBtns = {}
for i, st in ipairs(NB.styleDefs) do
    local isLast = (i == #NB.styleDefs)
    NB.styleBtns[i] = makeButton(st.name, yCursor, isLast and BTN_H_BIG or BTN_H, st.bg, st.fg)
    yCursor = yCursor + (isLast and BTN_H_BIG or BTN_H) + S_STEP
end
yCursor = yCursor + 6

-- ============ СТИХИИ (v23.6, ST1) ============
-- Каждая стихия за одно нажатие меняет: цвет + материал + атмосферу + ауру + огонь.
NB.elementDefs = {
    { name = "🔥 Огонь", bg = Color3.fromRGB(105,40,10), fg = Color3.fromRGB(255,200,130), search = "огонь пламя жар fire",
      color = "ОГОНЬ", pattern = "Хаос", speed = 1.5, orbit = "M", size = "M", shape = "МОЛНИЯ",
      rings = {true,true,true,false,false}, material = "Neon", trail = true, pulse = true,
      aura = true, auraColor = "ЛАВА", auraMaterial = "Neon", fire = true,
      atmo = {type = "Пепел", intensity = "Средняя", size = "Мелкий"} },
    { name = "🌍 Земля", bg = Color3.fromRGB(70,50,30), fg = Color3.fromRGB(220,200,150), search = "земля камень скала earth",
      color = "ТЕРРАКОТА", pattern = "Круг", speed = 0.5, orbit = "M", size = "L", shape = "СКАЛА",
      rings = {true,true,false,false,false}, material = "Slate", transparency = 0,
      aura = true, auraColor = "ХАКИ", auraMaterial = "Slate", fire = false,
      atmo = {type = "Лепестки", intensity = "Слабая", size = "Средний"} },
    { name = "💧 Вода", bg = Color3.fromRGB(25,60,100), fg = Color3.fromRGB(170,225,255), search = "вода море капля water",
      color = "ЛАЗУРЬ", pattern = "Волна", speed = 1.0, orbit = "L", size = "M", shape = "СЕРДЦЕ",
      rings = {true,true,true,false,false}, material = "Glass", transparency = 0.2, trail = true,
      aura = true, auraColor = "БИРЮЗОВЫЙ", auraMaterial = "Glass", fire = false,
      atmo = {type = "Пузыри", intensity = "Средняя", size = "Средний"} },
    { name = "❄️ Лёд", bg = Color3.fromRGB(35,65,95), fg = Color3.fromRGB(200,240,255), search = "лёд лед снег холод ice",
      color = "ЛЁД", pattern = "Круг", speed = 1.0, orbit = "M", size = "M", shape = "РОМБ",
      rings = {true,true,false,false,false}, material = "Ice", transparency = 0.1,
      aura = true, auraColor = "ЛЁД", auraMaterial = "Ice", fire = false,
      atmo = {type = "Снег", intensity = "Сильная", size = "Мелкий"} },
    { name = "⚡ Молния", bg = Color3.fromRGB(70,65,20), fg = Color3.fromRGB(255,250,150), search = "молния гроза электро lightning",
      color = "ЖЁЛТЫЙ", pattern = "Зигзаг", speed = 3.0, orbit = "M", size = "M", shape = "МОЛНИЯ",
      rings = {true,true,true,false,false}, material = "Neon", trail = true, pulse = true,
      aura = true, auraColor = "ЖЁЛТЫЙ", auraMaterial = "Neon", fire = false,
      atmo = {type = "Искры", intensity = "Сильная", size = "Мелкий"} },
    { name = "✨ Телепорт", bg = Color3.fromRGB(65,35,100), fg = Color3.fromRGB(235,200,255), search = "телепорт портал магия teleport",
      color = "ФИОЛЕТОВЫЙ", pattern = "Лиссажу", speed = 2.0, orbit = "L", size = "M", shape = "ИНЬ-ЯН",
      rings = {true,true,false,false,false}, material = "ForceField", trail = true,
      aura = true, auraColor = "АМЕТИСТ", auraMaterial = "ForceField", fire = false,
      atmo = {type = "Звёзды", intensity = "Средняя", size = "Мелкий"} },
    { name = "💨 Скорость", bg = Color3.fromRGB(35,70,70), fg = Color3.fromRGB(190,255,245), search = "скорость быстро ускорение speed",
      color = "БИРЮЗОВЫЙ", pattern = "Спираль", speed = 5.0, orbit = "L", size = "S", shape = "КЛИН",
      rings = {true,true,true,true,false}, material = "Neon", trail = true,
      aura = true, auraColor = "МЯТА", auraMaterial = "Neon", fire = false,
      atmo = {type = "Дождь", intensity = "Слабая", size = "Крошка"} },
    { name = "🌪️ Ветер", bg = Color3.fromRGB(55,65,75), fg = Color3.fromRGB(215,230,245), search = "ветер вихрь торнадо wind",
      color = "СЕРЕБРЯНЫЙ", pattern = "Спираль", speed = 3.0, orbit = "XL", size = "M", shape = "СПИРАЛЬ",
      rings = {true,true,true,false,false}, material = "SmoothPlastic", transparency = 0.3, trail = true,
      aura = true, auraColor = "БЕЛЫЙ", auraMaterial = "SmoothPlastic", fire = false,
      atmo = {type = "Лепестки", intensity = "Сильная", size = "Средний"} },
    { name = "☠️ Яд", bg = Color3.fromRGB(40,70,25), fg = Color3.fromRGB(200,255,130), search = "яд токсин отрава ядовитый poison",
      color = "ЛАЙМ", pattern = "Хаос", speed = 1.0, orbit = "M", size = "M", shape = "ЧЕРЕП",
      rings = {true,true,true,false,false}, material = "Neon", trail = true, pulse = true,
      aura = true, auraColor = "ЗЕЛЁНЫЙ", auraMaterial = "Neon", fire = false,
      atmo = {type = "Пузыри", intensity = "Слабая", size = "Средний"} },
}
makeBigSection("🌋  СТИХИИ — ОДНО НАЖАТИЕ", yCursor, Color3.fromRGB(150, 80, 60)); yCursor = yCursor + 30
NB.elementBtns = {}
for i, st in ipairs(NB.elementDefs) do
    NB.elementBtns[i] = makeButton(st.name, yCursor, BTN_H, st.bg, st.fg)
    NB.elementBtns[i]:SetAttribute("Search", "стихия стихии " .. (st.search or ""))
    yCursor = yCursor + BTN_H + S_STEP
end
yCursor = yCursor + 6

-- ============ ЭМОЦИИ (v23.6, EM1) ============
-- Работают и в обычном режиме, и в режиме античита (общий модуль orbit_sfx.lua).
makeBigSection("🎭  ЭМОЦИИ", yCursor, Color3.fromRGB(140, 90, 160)); yCursor = yCursor + 30
NB.emoteDefs = {
    { "🎤 Санс говорит", "sans",  Color3.fromRGB(35,45,70),  Color3.fromRGB(190,220,255), "санс говорит голос" },
    { "😂 Смех",         "laugh", Color3.fromRGB(60,50,30),  Color3.fromRGB(255,230,150), "смех смеяться хаха" },
    { "💃 Танец",        "dance", Color3.fromRGB(70,35,70),  Color3.fromRGB(255,190,255), "танец танцевать" },
    { "👋 Приветствие",  "greet", Color3.fromRGB(35,70,55),  Color3.fromRGB(180,255,210), "привет помахать" },
    { "💨 Уворот",       "dodge", Color3.fromRGB(45,45,75),  Color3.fromRGB(200,200,255), "уворот звук" },
}
NB.emoteBtns = {}
for i, e in ipairs(NB.emoteDefs) do
    NB.emoteBtns[i] = makeButton(e[1], yCursor, BTN_H, e[3], e[4])
    NB.emoteBtns[i]:SetAttribute("Search", "эмоция эмоции " .. e[5])
    yCursor = yCursor + BTN_H + S_STEP
end
yCursor = yCursor + 6
for i, b in ipairs(NB.emoteBtns) do
    onClick(b, function()
        if ORBIT.emote then
            if not ORBIT.emote(NB.emoteDefs[i][2]) then
                ORBIT.notify("🎭 Подожди секунду...", Color3.fromRGB(255, 220, 140), 1.5)
            end
        else
            ORBIT.notify("❌ orbit_sfx.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        end
    end)
end

-- ============ БОТЫ ============
makeBigSection("🤖  БОТЫ — ФАРМ КОЛЕЦ", yCursor, Color3.fromRGB(110, 70, 150)); yCursor = yCursor + 30
local botCreateNearBtn = makeButton("📍 Создать бота РЯДОМ", yCursor, BTN_H_BIG, Color3.fromRGB(45,80,65), Color3.fromRGB(170,255,200)); yCursor = yCursor + BTN_H_BIG + S_STEP
local botCreate5Btn    = makeButton("🔥 Создать 5 ботов", yCursor, BTN_H, Color3.fromRGB(65,40,90), Color3.fromRGB(225,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botCreate25Btn   = makeButton("🌟 Создать 25 ботов", yCursor, BTN_H, Color3.fromRGB(85,45,110), Color3.fromRGB(235,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botCreate100Btn  = makeButton("👑 Создать 100 ботов", yCursor, BTN_H, Color3.fromRGB(105,55,130), Color3.fromRGB(245,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botRemoveAll     = makeButton("🗑 Удалить всех ботов", yCursor, BTN_H, Color3.fromRGB(80,30,30), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP
local botAutoCollectBtn = makeButton("🎁 Автосбор: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
local botRadiusBtn      = makeButton("📏 Радиус сбора: 12 st", yCursor, BTN_H, Color3.fromRGB(35,50,65), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local botShowPlayerRing = makeButton("👤 Кольцо как у игрока: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,45,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
local botSkinBtnEnd     = makeButton("🎭 Скин как у меня: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,45,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP

local botInfoLbl = Instance.new("TextLabel")
botInfoLbl.Size = UDim2.new(1, -20, 0, 22)
botInfoLbl.Position = UDim2.new(0, 10, 0, yCursor)
botInfoLbl.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
botInfoLbl.BackgroundTransparency = 0.3
botInfoLbl.BorderSizePixel = 0
botInfoLbl.Text = "🤖 Ботов: 0"
botInfoLbl.TextColor3 = Color3.fromRGB(210, 210, 255)
botInfoLbl.Font = Enum.Font.GothamBold
botInfoLbl.TextSize = 11
botInfoLbl.ZIndex = 2
botInfoLbl.Parent = panel
Instance.new("UICorner", botInfoLbl).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 26 + 6

-- ============ ESP ============
makeBigSection("👁️  ESP И МЕТКИ", yCursor, Color3.fromRGB(80, 60, 130)); yCursor = yCursor + 30
local espBtn        = makeButton("👁️ ESP игроков: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local taggedCount   = makeButton("⭐ Список читеров: 0", yCursor, BTN_H, Color3.fromRGB(70,40,60), Color3.fromRGB(255,180,220)); yCursor = yCursor + BTN_H + S_STEP
local tagNearestBtn = makeButton("🚩 Пометить ближайшего", yCursor, BTN_H, Color3.fromRGB(80,30,55), Color3.fromRGB(255,150,200)); yCursor = yCursor + BTN_H + S_STEP
local clearTagsBtn  = makeButton("🧹 Снять все метки", yCursor, BTN_H, Color3.fromRGB(50,35,45), Color3.fromRGB(255,180,200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ВНЕШНИЙ ВИД ============
makeBigSection("🎨  ВНЕШНИЙ ВИД КОЛЕЦ", yCursor, Color3.fromRGB(60, 100, 120)); yCursor = yCursor + 30
local shapeCatBtn   = makeButton("📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, yCursor, BTN_H, Color3.fromRGB(60,50,80), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
local shapeBtn      = makeButton("🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local shapeModeBtn  = makeButton("🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
local shapeSizeBtn  = makeButton("🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local colorBtn      = makeButton("🎨 Цвет: " .. P.COLORS[P.colorIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local gradientBtn   = makeButton("🌈 Градиент: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(255,180,255)); yCursor = yCursor + BTN_H + S_STEP
local lightBtn      = makeButton("💡 Свет: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160)); yCursor = yCursor + BTN_H + S_STEP
local nameBtn       = makeButton("🏷️ Имена блоков: ВЫКЛ", yCursor); yCursor = yCursor + BTN_H + S_STEP
local autoSwapBtn   = makeButton("🎭 Автосмена: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ДВИЖЕНИЕ ============
makeBigSection("🛰️  ДВИЖЕНИЕ И ОРБИТА", yCursor, Color3.fromRGB(60, 100, 80)); yCursor = yCursor + 30
local orbitBtn        = makeButton("📏 Орбита: " .. P.ORBIT[P.orbitIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
local spreadBtn       = makeButton("📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name, yCursor, BTN_H, Color3.fromRGB(55,30,55), Color3.fromRGB(255,180,255)); yCursor = yCursor + BTN_H + S_STEP
local heightBtn       = makeButton("⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name, yCursor, BTN_H, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255)); yCursor = yCursor + BTN_H + S_STEP
local speedBtn        = makeButton("⚡ Множитель: " .. P.SPEED[P.speedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100)); yCursor = yCursor + BTN_H + S_STEP
local speedModeBtn    = makeButton("⚙️ Режим: " .. P.SPEED_MODE[P.speedModeIndex].name, yCursor, BTN_H, Color3.fromRGB(45,50,65), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local directionBtn    = makeButton("🔃 Направление: " .. P.DIRECTION[P.directionIndex].name, yCursor, BTN_H, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local orbitPatternBtn = makeButton("🌀 Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,90), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ КРУЧЕНИЕ ============
makeBigSection("🔄  КРУЧЕНИЕ", yCursor, Color3.fromRGB(100, 60, 80)); yCursor = yCursor + 30
local spinBtn       = makeButton("↩️ Вращение в 0", yCursor, BTN_H, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local spinAxisBtn   = makeButton("🔄 Кручение оси: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220)); yCursor = yCursor + BTN_H + S_STEP
local spinDirBtn    = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local spinSpeedBtn  = makeButton("🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ЭФФЕКТЫ ============
makeBigSection("✨  ЭФФЕКТЫ КОЛЕЦ", yCursor, Color3.fromRGB(100, 80, 60)); yCursor = yCursor + 30
local trailBtn      = makeButton("🌠 Трейлы: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
local trailLenBtn   = makeButton("📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local trailWidBtn   = makeButton("🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local waveBtn       = makeButton("🌊 Волна: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(30,55,75), Color3.fromRGB(140,220,255)); yCursor = yCursor + BTN_H + S_STEP
local explosionBtn  = makeButton("💥 Взрыв: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(70,40,30), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP
local pulseBtn      = makeButton("💓 Пульсация: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
NB.spawnAnim  = makeButton("🎆 Появление колец: ВКЛ", yCursor, BTN_H, Color3.fromRGB(45,40,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.spawnFlash = makeButton("💫 Вспышка при вкл: ВКЛ", yCursor, BTN_H, Color3.fromRGB(45,40,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ АУРА ============
makeBigSection("🌀  АУРА", yCursor, Color3.fromRGB(80, 60, 130)); yCursor = yCursor + 30
local auraBtn       = makeButton("🌀 Аура: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local auraRingBtn   = makeButton("⭕ Кольцо: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,35), Color3.fromRGB(160,255,160)); yCursor = yCursor + BTN_H + S_STEP
local auraPartBtn   = makeButton("✨ Частицы: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,55), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local auraFigBtn    = makeButton("🔷 Фигуры: ВКЛ", yCursor, BTN_H, Color3.fromRGB(45,35,65), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP

local auraShapeBtn  = makeButton("🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraColorBtn  = makeButton("🎨 Цвет ауры: " .. P.COLORS[P.auraColorIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.AURA_MATERIALS = {"Neon", "Glass", "ForceField", "Metal", "SmoothPlastic", "Ice", "Foil", "Marble"}
NB.auraMatBtn = makeButton("🧱 Материал ауры: NEON", yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.auraMatBtn:SetAttribute("Search", "материал ауры стекло металл неон лёд")
-- v23.7 (A2): стиль частиц ауры (искры / дым / звёзды) и сила свечения
NB.auraPartStyleBtn = makeButton("✨ Частицы ауры: ИСКРЫ", yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.auraPartStyleBtn:SetAttribute("Search", "частицы ауры искры дым звезды стиль")
NB.auraGlowBtn = makeButton("💡 Свечение ауры: ×1", yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.auraGlowBtn:SetAttribute("Search", "свечение ауры glow блеск")

local auraSizeBtn   = makeButton("📐 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraThickBtn  = makeButton("🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraHeightBtn = makeButton("⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
local auraShapeScaleBtn = makeButton("🔍 Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, yCursor, BTN_H, Color3.fromRGB(60,45,85), Color3.fromRGB(220,190,255)); yCursor = yCursor + BTN_H + S_STEP

local auraPatternBtn = makeButton("🌀 Узор ауры: " .. P.AURA_PATTERNS[P.auraPatternIndex].name, yCursor, BTN_H, Color3.fromRGB(65,45,95), Color3.fromRGB(230,190,255)); yCursor = yCursor + BTN_H + S_STEP

local auraSpeedBtn  = makeButton("⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100)); yCursor = yCursor + BTN_H + S_STEP
local auraDirBtn    = makeButton("🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name, yCursor, BTN_H, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP

local auraTrailBtn      = makeButton("🌠 Трейлы ауры: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
local auraTrailLenBtn   = makeButton("📏 Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local auraTrailWidBtn   = makeButton("🎚️ Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP

local auraSpinBtn       = makeButton("🔄 Кручение: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220)); yCursor = yCursor + BTN_H + S_STEP
local auraSpinAxisBtn   = makeButton("↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name, yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local auraSpinSpeedBtn  = makeButton("🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP

local auraPulseBtn      = makeButton("💓 Пульсация ауры: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP + 6

-- СВЕТ АУРЫ
makeBigSection("💡  СВЕТ АУРЫ", yCursor, Color3.fromRGB(140, 120, 60)); yCursor = yCursor + 30
local auraLightBtn      = makeButton("💡 Свет ауры: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(70,60,30), Color3.fromRGB(255,230,140)); yCursor = yCursor + BTN_H_BIG + S_STEP
local auraLightRangeBtn = makeButton("📏 Дальность: 8", yCursor, BTN_H, Color3.fromRGB(60,50,25), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP
local auraLightBrightBtn= makeButton("✨ Яркость: 2", yCursor, BTN_H, Color3.fromRGB(60,50,25), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ГРАФИКА
makeBigSection("🎨  ГРАФИКА И МАТЕРИАЛЫ", yCursor, Color3.fromRGB(60, 100, 130)); yCursor = yCursor + 30
local materialBtn   = makeButton("🎨 Материал: NEON", yCursor, BTN_H_BIG, Color3.fromRGB(50,80,110), Color3.fromRGB(180,230,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local transparencyBtn = makeButton("👁️ Прозрачность: 10%", yCursor, BTN_H, Color3.fromRGB(60,70,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H + S_STEP
local brightnessBtn = makeButton("☀️ Яркость: 1", yCursor, BTN_H, Color3.fromRGB(70,60,30), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP
local glowBtn       = makeButton("✨ Свечение: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,50), Color3.fromRGB(180,255,220)); yCursor = yCursor + BTN_H + S_STEP
local castShadowBtn = makeButton("🌑 Тени: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(45,45,65), Color3.fromRGB(200,200,220)); yCursor = yCursor + BTN_H + S_STEP
local qualityBtn    = makeButton("⚡ Качество графики: СРЕДНЕЕ", yCursor, BTN_H, Color3.fromRGB(60,45,90), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ОГОНЬ ============
makeBigSection("🔥  ОГОНЬ", yCursor, Color3.fromRGB(150, 60, 20)); yCursor = yCursor + 30
local fireBtn       = makeButton("🔥 Огонь: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(80,30,10), Color3.fromRGB(255,140,60)); yCursor = yCursor + BTN_H_BIG + S_STEP
local fireSizeBtn   = makeButton("📏 Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name, yCursor, BTN_H, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP
local fireHeatBtn   = makeButton("🌡️ Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name, yCursor, BTN_H, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ЗАЩИТА ============
makeBigSection("🛡️  ЗАЩИТА", yCursor, Color3.fromRGB(60, 100, 60)); yCursor = yCursor + 30
local antichitLaunchBtn = makeButton("🛡️ Запустить АНТИ-ЧИТ", yCursor, BTN_H_BIG, Color3.fromRGB(45,80,50), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H_BIG + S_STEP
local antichitStatusLbl = Instance.new("TextLabel")
antichitStatusLbl.Size = UDim2.new(1, -20, 0, 22)
antichitStatusLbl.Position = UDim2.new(0, 10, 0, yCursor)
antichitStatusLbl.BackgroundColor3 = Color3.fromRGB(25, 35, 25)
antichitStatusLbl.BackgroundTransparency = 0.3
antichitStatusLbl.BorderSizePixel = 0
antichitStatusLbl.Text = "🛡 Защита: не запущена"
antichitStatusLbl.TextColor3 = Color3.fromRGB(180, 220, 180)
antichitStatusLbl.Font = Enum.Font.GothamBold
antichitStatusLbl.TextSize = 11
antichitStatusLbl.ZIndex = 2
antichitStatusLbl.Parent = panel
Instance.new("UICorner", antichitStatusLbl).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 26 + 6

-- ============ ЛЮДИ ============
makeBigSection("👥  ЛЮДИ И КОЛЬЦА (полное копирование)", yCursor, Color3.fromRGB(100, 50, 130)); yCursor = yCursor + 30
local addAllRingsBtn    = makeButton("➕ Навесить ВСЁ всем игрокам", yCursor, BTN_H, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H + S_STEP
local remAllRingsBtn    = makeButton("➖ Убрать у всех", yCursor, BTN_H, Color3.fromRGB(70,40,40), Color3.fromRGB(255,160,160)); yCursor = yCursor + BTN_H + S_STEP
local toggleAllRingsBtn = makeButton("🔄 Переключить всем", yCursor, BTN_H, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255)); yCursor = yCursor + BTN_H + S_STEP

local peopleListScroll = Instance.new("ScrollingFrame")
peopleListScroll.Size = UDim2.new(1, -20, 0, 200)
peopleListScroll.Position = UDim2.new(0, 10, 0, yCursor)
peopleListScroll.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
peopleListScroll.BackgroundTransparency = 0.2
peopleListScroll.BorderSizePixel = 0
peopleListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
peopleListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
peopleListScroll.ScrollBarThickness = 3
peopleListScroll.ScrollBarImageColor3 = Color3.fromRGB(180, 130, 255)
peopleListScroll.ZIndex = 2
peopleListScroll.Parent = panel
Instance.new("UICorner", peopleListScroll).CornerRadius = UDim.new(0, 8)
do
    local peopleListLayout = Instance.new("UIListLayout")
    peopleListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    peopleListLayout.Padding = UDim.new(0, 4)
    peopleListLayout.Parent = peopleListScroll
end
yCursor = yCursor + 206

local refreshPeopleBtn = makeButton("🔄 Обновить список игроков", yCursor, BTN_H, Color3.fromRGB(45,55,90), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ЗВУКИ ============
makeBigSection("🔊  ЗВУКИ", yCursor, Color3.fromRGB(70, 80, 110)); yCursor = yCursor + 30
local soundToggleBtn = makeButton("🔊 Звуки: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
local soundVolumeBtn = makeButton("🎵 Громкость: 100%", yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local soundTestBtn   = makeButton("🔍 Проверка звуков", yCursor, BTN_H_BIG, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H_BIG + S_STEP + 6

-- ============ МАГАЗИН ============
makeBigSection("🛒  МАГАЗИН / РЕДАКТОР / ИГРА", yCursor, Color3.fromRGB(110, 60, 150)); yCursor = yCursor + 30
local openShopBtn    = makeButton("🛒 Открыть МАГАЗИН", yCursor, BTN_H_BIG, Color3.fromRGB(90,50,130), Color3.fromRGB(255,210,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
local openEditorBtn  = makeButton("🎨 Редактор 2D фигуры", yCursor, BTN_H, Color3.fromRGB(70,60,110), Color3.fromRGB(220,210,255)); yCursor = yCursor + BTN_H + S_STEP
local openGameBtn    = makeButton("🎮 МИНИ-ИГРА «Ловля звёзд»", yCursor, BTN_H_BIG, Color3.fromRGB(130,80,180), Color3.fromRGB(255,230,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
do -- v24.0
    UIK.openGasterBtn   = makeButton("🎮 Собери Гастера", yCursor, BTN_H_BIG, Color3.fromRGB(70,40,120), Color3.fromRGB(230,210,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
    UIK.gasterWeaponBtn = makeButton("👁 Гастер-оружие", yCursor, BTN_H, Color3.fromRGB(60,35,100), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
    UIK.modeBtn         = makeButton("🎭 Режим: Санс", yCursor, BTN_H, Color3.fromRGB(50,50,80), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6
end

-- ============ ПРОИЗВОДИТЕЛЬНОСТЬ ============
makeBigSection("⚡  ПРОИЗВОДИТЕЛЬНОСТЬ", yCursor, Color3.fromRGB(60, 80, 110)); yCursor = yCursor + 30
local perfBtn = makeButton("⚡ Качество: АВТО", yCursor, BTN_H, Color3.fromRGB(35,50,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ СЕРДЦЕ ============
makeBigSection("💗  ДОПОЛНИТЕЛЬНО", yCursor, Color3.fromRGB(100, 50, 80)); yCursor = yCursor + 30
local heartSizeBtn = makeButton("💗 Размер сердца: 100%", yCursor, BTN_H, Color3.fromRGB(70, 30, 55), Color3.fromRGB(255, 160, 200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ SHARE (упрощённый) ============
makeBigSection("🔗  SHARE — ВСТАВЬ СТРОКУ И ЗАГРУЗИ", yCursor, Color3.fromRGB(90, 100, 160)); yCursor = yCursor + 30

local shareInputBox = Instance.new("TextBox")
shareInputBox.Name = "ShareInput"
shareInputBox.Size = UDim2.new(1, -20, 0, 80)
shareInputBox.Position = UDim2.new(0, 10, 0, yCursor)
shareInputBox.BackgroundColor3 = Color3.fromRGB(15, 12, 24)
shareInputBox.TextColor3 = Color3.fromRGB(200, 220, 255)
shareInputBox.Font = Enum.Font.Code
shareInputBox.TextSize = 10
shareInputBox.Text = ""
shareInputBox.PlaceholderText = "Тут твоя строка для друга. Или вставь чужую и нажми ЗАГРУЗИТЬ"
shareInputBox.PlaceholderColor3 = Color3.fromRGB(120, 110, 160)
shareInputBox.TextWrapped = true
shareInputBox.TextXAlignment = Enum.TextXAlignment.Left
shareInputBox.TextYAlignment = Enum.TextYAlignment.Top
shareInputBox.ClearTextOnFocus = false
shareInputBox.MultiLine = true
shareInputBox.ZIndex = 2
shareInputBox.Parent = panel
Instance.new("UICorner", shareInputBox).CornerRadius = UDim.new(0, 8)
local sbPad = Instance.new("UIPadding", shareInputBox)
sbPad.PaddingLeft = UDim.new(0, 6); sbPad.PaddingRight = UDim.new(0, 6)
sbPad.PaddingTop = UDim.new(0, 4); sbPad.PaddingBottom = UDim.new(0, 4)
yCursor = yCursor + 86

local shareLoadBtn  = makeButton("📥 ЗАГРУЗИТЬ (вставил от друга)", yCursor, BTN_H_BIG, Color3.fromRGB(60, 120, 80), Color3.fromRGB(200, 255, 220)); yCursor = yCursor + BTN_H_BIG + S_STEP
local shareCopyBtn  = makeButton("📋 ВЫДАТЬ МОИ НАСТРОЙКИ", yCursor, BTN_H, Color3.fromRGB(70, 90, 150), Color3.fromRGB(220, 235, 255)); yCursor = yCursor + BTN_H + S_STEP
local sharePasteBtn = makeButton("📋 Вставить из буфера в поле", yCursor, BTN_H, Color3.fromRGB(70, 90, 130), Color3.fromRGB(220, 235, 255)); yCursor = yCursor + BTN_H + S_STEP
local shareClearBtn = makeButton("🗑 Очистить поле", yCursor, BTN_H, Color3.fromRGB(80, 50, 60), Color3.fromRGB(255, 180, 200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ СОХРАНЕНИЯ ============
makeBigSection("💾  СОХРАНЕНИЯ", yCursor, Color3.fromRGB(60, 60, 90)); yCursor = yCursor + 30
local saveNameInput = Instance.new("TextBox")
saveNameInput.Size = UDim2.new(1, -20, 0, 32)
saveNameInput.Position = UDim2.new(0, 10, 0, yCursor)
saveNameInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
saveNameInput.BackgroundTransparency = 0.1
saveNameInput.TextColor3 = Color3.fromRGB(240, 230, 255)
saveNameInput.Font = Enum.Font.GothamBold
saveNameInput.TextSize = 12
saveNameInput.PlaceholderText = "Имя сохранения..."
saveNameInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
saveNameInput.Text = ""
saveNameInput.ClearTextOnFocus = false
saveNameInput.ZIndex = 2
saveNameInput.Parent = panel
Instance.new("UICorner", saveNameInput).CornerRadius = UDim.new(0, 8)
yCursor = yCursor + 36

local createSaveBtn = makeButton("💾 СОЗДАТЬ СОХРАНЕНИЕ", yCursor, BTN_H_BIG, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H_BIG + S_STEP
local importSaveBtn = makeButton("📥 ИМПОРТ СОХРАНЕНИЯ ИЗ БУФЕРА", yCursor, BTN_H, Color3.fromRGB(55, 75, 105), Color3.fromRGB(190, 220, 255)); yCursor = yCursor + BTN_H + S_STEP + 4

local savesContainer = Instance.new("ScrollingFrame")
savesContainer.Size = UDim2.new(1, -20, 0, 130)
savesContainer.Position = UDim2.new(0, 10, 0, yCursor)
savesContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
savesContainer.BackgroundTransparency = 0.2
savesContainer.BorderSizePixel = 0
savesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
savesContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
savesContainer.ScrollBarThickness = 3
savesContainer.ScrollBarImageColor3 = Color3.fromRGB(150,100,200)
savesContainer.ZIndex = 2
savesContainer.Parent = panel
Instance.new("UICorner", savesContainer).CornerRadius = UDim.new(0, 8)
do
    local savesLayout = Instance.new("UIListLayout")
    savesLayout.SortOrder = Enum.SortOrder.LayoutOrder
    savesLayout.Padding = UDim.new(0, 4)
    savesLayout.Parent = savesContainer
end
yCursor = yCursor + 136

-- ============ СИСТЕМА ============
makeBigSection("💾  СИСТЕМА", yCursor, Color3.fromRGB(60, 60, 80)); yCursor = yCursor + 30
local saveBtn   = makeButton("💾 Сохранить в автослот", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H + S_STEP
local loadBtn   = makeButton("📂 Загрузить из автослота", yCursor, BTN_H, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local resetBtn  = makeButton("🔄 Сбросить всё", yCursor, BTN_H, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP
NB.fpsToggle = makeButton("📊 FPS-панель: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
local helperBtn = makeButton("🤖 Помощник (понимает фразы)", yCursor, BTN_H, Color3.fromRGB(70,60,130), Color3.fromRGB(220,210,255)); yCursor = yCursor + BTN_H + S_STEP
local unloadBtn = makeButton("❌ ВЫГРУЗИТЬ СКРИПТ", yCursor, BTN_H_BIG, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140)); yCursor = yCursor + BTN_H_BIG + S_STEP + 6

-- ============ МУЗЫКА ============
makeBigSection("🎵  МУЗЫКА", yCursor, Color3.fromRGB(80, 60, 110)); yCursor = yCursor + 30
local musicInput = Instance.new("TextBox")
musicInput.Size = UDim2.new(1, -20, 0, 32)
musicInput.Position = UDim2.new(0, 10, 0, yCursor)
musicInput.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
musicInput.BackgroundTransparency = 0.1
musicInput.TextColor3 = Color3.fromRGB(240, 230, 255)
musicInput.Font = Enum.Font.GothamBold
musicInput.TextSize = 12
musicInput.PlaceholderText = "Sound ID"
musicInput.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
musicInput.Text = ""
musicInput.ClearTextOnFocus = false
musicInput.ZIndex = 2
musicInput.Parent = panel
Instance.new("UICorner", musicInput).CornerRadius = UDim.new(0, 8)
yCursor = yCursor + 36

local applyIdBtn = makeButton("✅ Применить ID", yCursor, BTN_H, Color3.fromRGB(55,80,55), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
local musicBtn   = makeButton("🎵 Музыка: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(50,35,60), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ СТАТИСТИКА ============
makeBigSection("📈  СТАТИСТИКА СЕССИИ", yCursor, Color3.fromRGB(60, 60, 90)); yCursor = yCursor + 30
local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -20, 0, 100)
statsLabel.Position = UDim2.new(0, 10, 0, yCursor)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
statsLabel.BackgroundTransparency = 0.2
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 11
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "FPS: --"
statsLabel.ZIndex = 2
statsLabel.Parent = panel
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 106

local resetSessionBtn = makeButton("🔄 Сбросить статистику", yCursor, BTN_H, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP + 6
UIK.finishBuild()

-- ============================================================
--       ОТКРЫТИЕ/ЗАКРЫТИЕ
-- ============================================================
local panelOpen = false
local dragMoved = false
local panelScale = Instance.new("UIScale")
panelScale.Parent = window

local function setPanel(open)
    panelOpen = open
    if open then
        local abs = screenGui.AbsoluteSize
        local w = math.min(PANEL_W, abs.X - 16)
        local h = math.clamp(abs.Y - 40, 220, IS_MOBILE and 560 or 780)
        window.Size = UDim2.fromOffset(w, h)
        window.Position = UDim2.fromOffset(
            math.clamp(mainBtn.Position.X.Offset + (IS_MOBILE and 72 or 70), 4, math.max(4, abs.X - w - 8)),
            math.clamp(math.floor((abs.Y - h) / 2), 4, math.max(4, abs.Y - h - 4)))
        panelScale.Scale = 0.88
        window.Visible = true
        TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
        relayout()
    else
        TweenService:Create(panelScale, TweenInfo.new(0.12), { Scale = 0.88 }):Play()
        task.delay(0.13, function()
            if not panelOpen then window.Visible = false end
        end)
    end
end

onClick(mainBtn, function()
    if dragMoved then dragMoved = false; return end
    setPanel(not panelOpen)
end)
onClick(panelCloseBtn, function() setPanel(false) end)

-- ============================================================
--       ОБРАБОТЧИКИ
-- ============================================================
local ringButtons = { [2]=ring2Btn, [3]=ring3Btn, [4]=ring4Btn, [5]=ring5Btn }
local function refreshRingButton(ri)
    local btn = ringButtons[ri]; if not btn then return end
    if rings[ri].enabled then
        btn.Text = "➖ Кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(55,40,40); btn.TextColor3 = Color3.fromRGB(255,160,160)
    else
        btn.Text = "➕ Кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(40,55,40); btn.TextColor3 = Color3.fromRGB(160,255,160)
    end
end

onClick(toggleBtn, function()
    ORBIT.setEnabled(not ORBIT.enabled)
    if ORBIT.enabled then
        toggleBtn.Text = "🟢 ВКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(0,255,120); toggleBtn.BackgroundColor3 = Color3.fromRGB(40,50,40)
    else
        toggleBtn.Text = "🔴 ВЫКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(255,80,80); toggleBtn.BackgroundColor3 = Color3.fromRGB(50,35,40)
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if statsLabel and statsLabel.Parent and ORBIT.SESSION then
            local s = ORBIT.SESSION
            local elapsed = tick() - (s.startTime or tick())
            local mins = math.floor(elapsed / 60)
            local secs = math.floor(elapsed % 60)
            local bots = 0; for _ in pairs(ORBIT.bots or {}) do bots = bots + 1 end
            local ringTargets = 0; for _ in pairs(ORBIT.targetRings or {}) do ringTargets = ringTargets + 1 end
            local tagged = 0; for _ in pairs(ORBIT.taggedPlayers or {}) do tagged = tagged + 1 end
            local savesCount = 0; for _ in pairs(ORBIT.SAVES or {}) do savesCount = savesCount + 1 end
            statsLabel.Text = string.format(
                "🎁 Ботов: %d  |  🚩 Читеров: %d\n🥷 Уворотов: %d\n🛡️ Защит: %d\n🎯 Колец на людях: %d  |  💾 Сохр: %d\n⏱️ %d:%02d",
                s.botsCollected or 0, s.cheatersTagged or 0,
                s.dodgesMade or 0, s.protectionsTriggered or 0,
                ringTargets, savesCount, mins, secs)
        end
    end
end)

onClick(resetSessionBtn, function()
    if ORBIT.SESSION then
        ORBIT.SESSION.botsCollected = 0
        ORBIT.SESSION.cheatersTagged = 0
        ORBIT.SESSION.dodgesMade = 0
        ORBIT.SESSION.protectionsTriggered = 0
        ORBIT.SESSION.startTime = tick()
        ORBIT.notify("📊 Статистика сброшена", Color3.fromRGB(180,220,255), 2)
    end
end)

onClick(espBtn, function()
    if ORBIT.setESPEnabled then
        ORBIT.setESPEnabled(not ORBIT.ESP.Enabled)
        espBtn.Text = "👁️ ESP игроков: " .. (ORBIT.ESP.Enabled and "ВКЛ" or "ВЫКЛ")
        if ORBIT.ESP.Enabled then
            espBtn.BackgroundColor3 = Color3.fromRGB(40,80,60)
            espBtn.TextColor3 = Color3.fromRGB(180,255,200)
        else
            espBtn.BackgroundColor3 = Color3.fromRGB(50,60,90)
            espBtn.TextColor3 = Color3.fromRGB(200,220,255)
        end
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if taggedCount and ORBIT.getTaggedPlayers then
            taggedCount.Text = "⭐ Список читеров: " .. #ORBIT.getTaggedPlayers()
        end
    end
end)

local function rebuildPeopleList()
    local list = ORBIT.getPlayerList and ORBIT.getPlayerList() or {}
    local sigParts = {}
    for _, info in ipairs(list) do
        sigParts[#sigParts + 1] = info.name .. (info.hasRing and "1" or "0") .. (info.isTagged and "1" or "0")
    end
    local sig = table.concat(sigParts, "|")
    if sig == NB.peopleSig then return end
    NB.peopleSig = sig
    for _, ch in ipairs(peopleListScroll:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    if #list == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -6, 0, 24)
        empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140, 130, 170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 11
        empty.LayoutOrder = 1
        empty.Parent = peopleListScroll
        return
    end
    for i, info in ipairs(list) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 52)
        row.BackgroundColor3 = Color3.fromRGB(28, 22, 45)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = peopleListScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -8, 0, 18)
        nameLbl.Position = UDim2.new(0, 6, 0, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = "👤 " .. info.name
        nameLbl.TextColor3 = Color3.fromRGB(230, 220, 255)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local btnRow = Instance.new("Frame")
        btnRow.Size = UDim2.new(1, -8, 0, 24)
        btnRow.Position = UDim2.new(0, 4, 0, 22)
        btnRow.BackgroundTransparency = 1
        btnRow.Parent = row

        local ringBtn = Instance.new("TextButton")
        ringBtn.Size = UDim2.new(0.5, -2, 1, 0)
        if info.hasRing then
            ringBtn.Text = "➖ Убрать"
            ringBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            ringBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
        else
            ringBtn.Text = "➕ Полное кольцо"
            ringBtn.BackgroundColor3 = Color3.fromRGB(40, 70, 45)
            ringBtn.TextColor3 = Color3.fromRGB(160, 255, 180)
        end
        ringBtn.Font = Enum.Font.GothamBold
        ringBtn.TextSize = 10
        ringBtn.Parent = btnRow
        Instance.new("UICorner", ringBtn).CornerRadius = UDim.new(0, 5)

        local tagBtn = Instance.new("TextButton")
        tagBtn.Size = UDim2.new(0.5, -2, 1, 0)
        tagBtn.Position = UDim2.new(0.5, 2, 0, 0)
        if info.isTagged then
            tagBtn.Text = "✅ Снять метку"
            tagBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 50)
            tagBtn.TextColor3 = Color3.fromRGB(220, 200, 220)
        else
            tagBtn.Text = "🚩 Читер"
            tagBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 55)
            tagBtn.TextColor3 = Color3.fromRGB(255, 150, 200)
        end
        tagBtn.Font = Enum.Font.GothamBold
        tagBtn.TextSize = 10
        tagBtn.Parent = btnRow
        Instance.new("UICorner", tagBtn).CornerRadius = UDim.new(0, 5)

        onClick(ringBtn, function()
            if ORBIT.toggleTargetRings then ORBIT.toggleTargetRings(info.player) end
            task.wait(0.1); rebuildPeopleList()
        end)
        onClick(tagBtn, function()
            if ORBIT.toggleTagCheater then ORBIT.toggleTagCheater(info.player) end
            task.wait(0.1); rebuildPeopleList()
        end)
    end
end
rebuildPeopleList()

onClick(refreshPeopleBtn, function()
    NB.peopleSig = nil
    rebuildPeopleList()
    refreshPeopleBtn.Text = "✅ Обновлено"
    task.wait(0.8)
    refreshPeopleBtn.Text = "🔄 Обновить список игроков"
end)

onClick(addAllRingsBtn, function() if ORBIT.addRingsToAll then ORBIT.addRingsToAll() end; task.wait(0.2); rebuildPeopleList() end)
onClick(remAllRingsBtn, function() if ORBIT.removeRingsFromAll then ORBIT.removeRingsFromAll() end; task.wait(0.2); rebuildPeopleList() end)
onClick(toggleAllRingsBtn, function() if ORBIT.toggleAllRings then ORBIT.toggleAllRings() end; task.wait(0.2); rebuildPeopleList() end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(4)
        if window.Visible then pcall(rebuildPeopleList) end
    end
end)
UIK.connect(Players.PlayerAdded, function(p) if p ~= LocalPlayer then task.wait(0.5); pcall(rebuildPeopleList) end end)
UIK.connect(Players.PlayerRemoving, function(p) if p ~= LocalPlayer then task.wait(0.3); pcall(rebuildPeopleList) end end)

-- БОТЫ
onClick(botCreateNearBtn, function() if ORBIT.createBotNear then ORBIT.createBotNear() end end)
onClick(botCreate5Btn, function() ORBIT.createMultipleBots(5) end)
onClick(botCreate25Btn, function() ORBIT.createManyBots(25) end)
onClick(botCreate100Btn, function() ORBIT.createManyBots(100) end)
onClick(botRemoveAll, function() ORBIT.removeAllBots() end)
onClick(botAutoCollectBtn, function()
    ORBIT.botSettings.AutoCollect = not ORBIT.botSettings.AutoCollect
    botAutoCollectBtn.Text = "🎁 Автосбор: " .. (ORBIT.botSettings.AutoCollect and "ВКЛ" or "ВЫКЛ")
end)
onClick(botRadiusBtn, function()
    local steps = {6, 8, 10, 12, 15, 20, 25}
    local idx = 1
    for i, v in ipairs(steps) do if v == ORBIT.botSettings.CollectRadius then idx = i; break end end
    ORBIT.botSettings.CollectRadius = steps[(idx % #steps) + 1]
    botRadiusBtn.Text = "📏 Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st"
end)
onClick(botShowPlayerRing, function()
    ORBIT.botSettings.ShowPlayerRing = not ORBIT.botSettings.ShowPlayerRing
    botShowPlayerRing.Text = "👤 Кольцо как у игрока: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ")
    ORBIT.notify("👤 Кольцо ботов: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200,180,255), 2)
end)
onClick(botSkinBtnEnd, function()
    ORBIT.botSettings.UseMySkin = not ORBIT.botSettings.UseMySkin
    botSkinBtnEnd.Text = "🎭 Скин как у меня: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ")
    ORBIT.botAvatarTemplate = nil
    ORBIT.notify("🎭 Скин бота: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200, 180, 255), 2)
end)
if ORBIT.botSettings.UseMySkin then botSkinBtnEnd.Text = "🎭 Скин как у меня: ВКЛ" end
if ORBIT.botSettings.ShowPlayerRing then botShowPlayerRing.Text = "👤 Кольцо как у игрока: ВКЛ" end

-- КОЛЬЦА
onClick(allRingsBtn, function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local ns = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= ns then ORBIT.setRingEnabled(ri, ns) end end
    for ri = 2, 5 do refreshRingButton(ri) end
    allRingsBtn.Text = ns and "⭕ Все кольца: ВЫКЛ" or "⭕ Все кольца: ВКЛ"
end)
for ri, btn in pairs(ringButtons) do
    onClick(btn, function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

-- ВНЕШНИЙ ВИД
onClick(shapeCatBtn, function()
    P.shapeCategoryIndex = P.shapeCategoryIndex + 1
    if P.shapeCategoryIndex > #P.SHAPE_CATEGORIES then P.shapeCategoryIndex = 1 end
    shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs > 0 then
        ORBIT.shapeIndex = idxs[1]
        shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.applyShapes(); ORBIT.rebuildAllRings()
    end
end)
onClick(shapeBtn, function()
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs == 0 then return end
    local pos = nil
    for i, v in ipairs(idxs) do if v == ORBIT.shapeIndex then pos = i; break end end
    local newPos = pos and (pos % #idxs) + 1 or 1
    ORBIT.shapeIndex = idxs[newPos]
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
onClick(shapeModeBtn, function()
    P.formModeIndex = P.formModeIndex + 1; if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
onClick(shapeSizeBtn, function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1; if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    ORBIT.rebuildAllRings()
end)
onClick(gradientBtn, function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    gradientBtn.Text = "🌈 Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then SETTINGS.Rainbow = false end
    ORBIT.rebuildAllRings()
end)
onClick(lightBtn, function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
onClick(nameBtn, function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "🏷️ Имена блоков: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    ORBIT.applyNameVisibility()
end)
onClick(autoSwapBtn, function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "🎭 Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then ORBIT.lastAutoSwap = tick() end
end)

-- ДВИЖЕНИЕ
onClick(orbitBtn, function()
    P.orbitIndex = P.orbitIndex + 1; if P.orbitIndex > #P.ORBIT then P.orbitIndex = 1 end
    orbitBtn.Text = "📏 Орбита: " .. P.ORBIT[P.orbitIndex].name
end)
onClick(spreadBtn, function()
    P.spreadIndex = P.spreadIndex + 1; if P.spreadIndex > #P.SPREAD then P.spreadIndex = 1 end
    spreadBtn.Text = "📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name
end)
onClick(heightBtn, function()
    P.heightIndex = P.heightIndex + 1; if P.heightIndex > #P.HEIGHT then P.heightIndex = 1 end
    heightBtn.Text = "⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name
end)
onClick(speedBtn, function()
    P.speedIndex = P.speedIndex + 1; if P.speedIndex > #P.SPEED then P.speedIndex = 1 end
    SETTINGS.SpeedMultiplier = P.SPEED[P.speedIndex].value
    speedBtn.Text = "⚡ Множитель: " .. P.SPEED[P.speedIndex].name
end)
onClick(speedModeBtn, function()
    P.speedModeIndex = P.speedModeIndex + 1; if P.speedModeIndex > #P.SPEED_MODE then P.speedModeIndex = 1 end
    speedModeBtn.Text = "⚙️ Режим: " .. P.SPEED_MODE[P.speedModeIndex].name
    ORBIT.applySpeedModePreset()
end)
onClick(directionBtn, function()
    P.directionIndex = P.directionIndex + 1; if P.directionIndex > #P.DIRECTION then P.directionIndex = 1 end
    directionBtn.Text = "🔃 Направление: " .. P.DIRECTION[P.directionIndex].name
    ORBIT.applyDirectionPreset()
end)
onClick(orbitPatternBtn, function()
    P.orbitPatternIndex = P.orbitPatternIndex + 1; if P.orbitPatternIndex > #P.ORBIT_PATTERNS then P.orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name
    orbitPatternBtn.Text = "🌀 Узор: " .. SETTINGS.OrbitPattern
end)

-- КРУЧЕНИЕ
onClick(spinBtn, function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    spinBtn.Text = ORBIT.spinResetting and "↩️ Вращение: ВОЗВРАТ" or "↩️ Вращение в 0"
end)
onClick(spinAxisBtn, function()
    ORBIT.spinAxisEnabled = not ORBIT.spinAxisEnabled
    spinAxisBtn.Text = "🔄 Кручение оси: " .. (ORBIT.spinAxisEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(spinDirBtn, function()
    if ORBIT.spinAxisDir == "X" then ORBIT.spinAxisDir = "Y"; spinDirBtn.Text = "↔️ Ось: ВЛЕВО/ВПРАВО"
    else ORBIT.spinAxisDir = "X"; spinDirBtn.Text = "↕️ Ось: ВЕРХ/ВНИЗ" end
end)
onClick(spinSpeedBtn, function()
    P.spinSpeedIndex = P.spinSpeedIndex + 1; if P.spinSpeedIndex > #P.SPIN_SPEED then P.spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value
    spinSpeedBtn.Text = "🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

-- ЭФФЕКТЫ
onClick(trailBtn, function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
onClick(trailLenBtn, function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    trailLenBtn.Text = "📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(trailWidBtn, function()
    P.trailWidthIndex = P.trailWidthIndex + 1; if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    trailWidBtn.Text = "🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(waveBtn, function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    waveBtn.Text = "🌊 Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(explosionBtn, function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    explosionBtn.Text = "💥 Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(pulseBtn, function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    pulseBtn.Text = "💓 Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- АУРА
local function refreshAura()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
onClick(auraBtn, function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    auraBtn.Text = "🌀 Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then
        if not SETTINGS.AuraRing and not SETTINGS.AuraParticles and not SETTINGS.AuraShapes then
            SETTINGS.AuraRing = true; SETTINGS.AuraParticles = true; SETTINGS.AuraShapes = true
            auraRingBtn.Text = "⭕ Кольцо: ВКЛ"; auraPartBtn.Text = "✨ Частицы: ВКЛ"; auraFigBtn.Text = "🔷 Фигуры: ВКЛ"
        end
        ORBIT.setupAura()
    else
        if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
    end
end)
onClick(auraRingBtn, function()
    SETTINGS.AuraRing = not SETTINGS.AuraRing
    auraRingBtn.Text = "⭕ Кольцо: " .. (SETTINGS.AuraRing and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraPartBtn, function()
    SETTINGS.AuraParticles = not SETTINGS.AuraParticles
    auraPartBtn.Text = "✨ Частицы: " .. (SETTINGS.AuraParticles and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraFigBtn, function()
    SETTINGS.AuraShapes = not SETTINGS.AuraShapes
    auraFigBtn.Text = "🔷 Фигуры: " .. (SETTINGS.AuraShapes and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraShapeBtn, function()
    ORBIT.auraShapeIndex = ORBIT.auraShapeIndex + 1
    if ORBIT.auraShapeIndex > #SHAPE_PRESETS then ORBIT.auraShapeIndex = 1 end
    auraShapeBtn.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    refreshAura()
end)
onClick(auraSizeBtn, function()
    P.auraSizeIndex = P.auraSizeIndex + 1; if P.auraSizeIndex > #P.AURA_SIZE then P.auraSizeIndex = 1 end
    SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value
    auraSizeBtn.Text = "📐 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    refreshAura()
end)
onClick(auraThickBtn, function()
    P.auraThickIndex = P.auraThickIndex + 1; if P.auraThickIndex > #P.AURA_THICK then P.auraThickIndex = 1 end
    SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value
    auraThickBtn.Text = "🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    refreshAura()
end)
onClick(auraHeightBtn, function()
    P.auraHeightIndex = P.auraHeightIndex + 1; if P.auraHeightIndex > #P.AURA_HEIGHT then P.auraHeightIndex = 1 end
    SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value
    auraHeightBtn.Text = "⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
    refreshAura()
end)
onClick(auraShapeScaleBtn, function()
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1; if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
    SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor
    auraShapeScaleBtn.Text = "🔍 Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    refreshAura()
end)
onClick(auraPatternBtn, function()
    P.auraPatternIndex = P.auraPatternIndex + 1
    if P.auraPatternIndex > #P.AURA_PATTERNS then P.auraPatternIndex = 1 end
    SETTINGS.AuraPattern = P.AURA_PATTERNS[P.auraPatternIndex].name
    auraPatternBtn.Text = "🌀 Узор ауры: " .. SETTINGS.AuraPattern
end)
onClick(auraSpeedBtn, function()
    P.auraSpeedIndex = P.auraSpeedIndex + 1; if P.auraSpeedIndex > #P.AURA_SPEED then P.auraSpeedIndex = 1 end
    SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value
    auraSpeedBtn.Text = "⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
end)
onClick(auraDirBtn, function()
    P.auraDirIndex = P.auraDirIndex + 1; if P.auraDirIndex > #P.AURA_DIR then P.auraDirIndex = 1 end
    SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value
    auraDirBtn.Text = "🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name
end)
onClick(auraTrailBtn, function()
    SETTINGS.AuraTrailEnabled = not SETTINGS.AuraTrailEnabled
    auraTrailBtn.Text = "🌠 Трейлы ауры: " .. (SETTINGS.AuraTrailEnabled and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraTrailLenBtn, function()
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1; if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    auraTrailLenBtn.Text = "📏 Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(auraTrailWidBtn, function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1; if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    auraTrailWidBtn.Text = "🎚️ Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(auraSpinBtn, function()
    SETTINGS.AuraSpinEnabled = not SETTINGS.AuraSpinEnabled
    auraSpinBtn.Text = "🔄 Кручение: " .. (SETTINGS.AuraSpinEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(auraSpinAxisBtn, function()
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1; if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    auraSpinAxisBtn.Text = "↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
onClick(auraSpinSpeedBtn, function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1; if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    auraSpinSpeedBtn.Text = "🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
end)
onClick(auraPulseBtn, function()
    SETTINGS.AuraPulseEnabled = not SETTINGS.AuraPulseEnabled
    auraPulseBtn.Text = "💓 Пульсация ауры: " .. (SETTINGS.AuraPulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- СВЕТ АУРЫ
onClick(auraLightBtn, function()
    SETTINGS.AuraLightEnabled = not SETTINGS.AuraLightEnabled
    auraLightBtn.Text = "💡 Свет ауры: " .. (SETTINGS.AuraLightEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraLightEnabled then
        auraLightBtn.BackgroundColor3 = Color3.fromRGB(120,100,40)
        auraLightBtn.TextColor3 = Color3.fromRGB(255,240,160)
    else
        auraLightBtn.BackgroundColor3 = Color3.fromRGB(70,60,30)
        auraLightBtn.TextColor3 = Color3.fromRGB(255,230,140)
    end
    refreshAura()
end)
onClick(auraLightRangeBtn, function()
    local steps = {4, 6, 8, 12, 16, 24, 32}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightRange then idx = i; break end end
    SETTINGS.AuraLightRange = steps[(idx % #steps) + 1]
    auraLightRangeBtn.Text = "📏 Дальность: " .. SETTINGS.AuraLightRange
    refreshAura()
end)
onClick(auraLightBrightBtn, function()
    local steps = {1, 2, 3, 5, 8, 12}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightBrightness then idx = i; break end end
    SETTINGS.AuraLightBrightness = steps[(idx % #steps) + 1]
    auraLightBrightBtn.Text = "✨ Яркость: " .. SETTINGS.AuraLightBrightness
    refreshAura()
end)

-- ГРАФИКА
local MATERIALS = {"Neon", "Glass", "ForceField", "Plastic", "SmoothPlastic", "Metal", "Ice", "Marble", "Slate", "Granite"}
local materialIndex = 1
for i, m in ipairs(MATERIALS) do
    if m == tostring(SETTINGS.Material):gsub("Enum.Material.", "") then materialIndex = i; break end
end
onClick(materialBtn, function()
    materialIndex = materialIndex + 1
    if materialIndex > #MATERIALS then materialIndex = 1 end
    local mName = MATERIALS[materialIndex]
    SETTINGS.Material = Enum.Material[mName]
    materialBtn.Text = "🎨 Материал: " .. mName:upper()
    ORBIT.rebuildAllRings()
end)
if SETTINGS.Material then
    materialBtn.Text = "🎨 Материал: " .. tostring(SETTINGS.Material):gsub("Enum.Material.", ""):upper()
end

onClick(transparencyBtn, function()
    local steps = {0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9}
    local idx = 1
    for i, v in ipairs(steps) do if math.abs(v - SETTINGS.Transparency) < 0.01 then idx = i; break end end
    SETTINGS.Transparency = steps[(idx % #steps) + 1]
    transparencyBtn.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"
    ORBIT.rebuildAllRings()
end)
transparencyBtn.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"

onClick(brightnessBtn, function()
    local steps = {0.5, 1, 1.5, 2, 3, 5, 8}
    local idx = 1
    for i, v in ipairs(steps) do if v == (SETTINGS.GlowIntensity or 1) then idx = i; break end end
    SETTINGS.GlowIntensity = steps[(idx % #steps) + 1]
    brightnessBtn.Text = "☀️ Яркость: " .. SETTINGS.GlowIntensity
    ORBIT.rebuildAllRings()
end)
brightnessBtn.Text = "☀️ Яркость: " .. (SETTINGS.GlowIntensity or 1)

onClick(glowBtn, function()
    SETTINGS.GlowEnabled = not (SETTINGS.GlowEnabled ~= false)
    local on = SETTINGS.GlowEnabled
    glowBtn.Text = "✨ Свечение: " .. (on and "ВКЛ" or "ВЫКЛ")
    if on then
        glowBtn.BackgroundColor3 = Color3.fromRGB(35,60,50); glowBtn.TextColor3 = Color3.fromRGB(180,255,220)
    else
        glowBtn.BackgroundColor3 = Color3.fromRGB(45,45,65); glowBtn.TextColor3 = Color3.fromRGB(200,200,220)
    end
    for _, ring in pairs(rings) do
        for _, d in ipairs(ring.blocks) do
            if d.light then d.light.Enabled = on end
        end
    end
end)

onClick(castShadowBtn, function()
    SETTINGS.CastShadow = not SETTINGS.CastShadow
    castShadowBtn.Text = "🌑 Тени: " .. (SETTINGS.CastShadow and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)

local GRAPHIC_MODES = {"LOW", "MEDIUM", "HIGH", "ULTRA"}
local graphicModeIndex = 2
local function applyGraphicMode(mode)
    if mode == "LOW" then
        SETTINGS.LightEnabled = false
        SETTINGS.TrailEnabled = false
        SETTINGS.AuraParticles = false
        SETTINGS.BlockCount = 4
    elseif mode == "MEDIUM" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 10
        SETTINGS.TrailEnabled = false
        SETTINGS.AuraParticles = true
        SETTINGS.BlockCount = 6
    elseif mode == "HIGH" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 20
        SETTINGS.TrailEnabled = true
        SETTINGS.AuraParticles = true
        SETTINGS.BlockCount = 8
    elseif mode == "ULTRA" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 40
        SETTINGS.TrailEnabled = true
        SETTINGS.AuraParticles = true
        SETTINGS.AuraShapes = true
        SETTINGS.BlockCount = 12
    end
    ORBIT.rebuildAllRings()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
onClick(qualityBtn, function()
    graphicModeIndex = graphicModeIndex + 1
    if graphicModeIndex > #GRAPHIC_MODES then graphicModeIndex = 1 end
    local mode = GRAPHIC_MODES[graphicModeIndex]
    qualityBtn.Text = "⚡ Качество графики: " .. mode
    applyGraphicMode(mode)
    ORBIT.notify("🎨 Графика: " .. mode, Color3.fromRGB(200,220,255), 2)
end)

-- ОГОНЬ
onClick(fireBtn, function()
    SETTINGS.FireEnabled = not SETTINGS.FireEnabled
    fireBtn.Text = "🔥 Огонь: " .. (SETTINGS.FireEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupFire()
end)
onClick(fireSizeBtn, function()
    P.fireSizeIndex = P.fireSizeIndex + 1; if P.fireSizeIndex > #P.FIRE_SIZE then P.fireSizeIndex = 1 end
    SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value
    fireSizeBtn.Text = "📏 Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)
onClick(fireHeatBtn, function()
    P.fireHeatIndex = P.fireHeatIndex + 1; if P.fireHeatIndex > #P.FIRE_HEAT then P.fireHeatIndex = 1 end
    SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value
    fireHeatBtn.Text = "🌡️ Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)

-- ЗАЩИТА
local antichitLoaded = false
onClick(antichitLaunchBtn, function()
    if antichitLoaded or (ORBIT.loaded and ORBIT.loaded.ac) then
        antichitLoaded = true
        antichitLaunchBtn.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
        antichitStatusLbl.Text = "🛡 Защита: активна (18 функций)"
        antichitStatusLbl.TextColor3 = Color3.fromRGB(160,255,180)
        ORBIT.notify("🛡 Античит уже запущен", Color3.fromRGB(180,255,180), 2)
        return
    end
    antichitLaunchBtn.Text = "⏳ Загружаю..."
    task.spawn(function()
        local url = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_anticheat.lua?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src < 100 then
            antichitLaunchBtn.Text = "❌ Ошибка загрузки"
            antichitStatusLbl.Text = "🛡 Защита: ошибка сети"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            antichitLaunchBtn.Text = "❌ Ошибка кода"
            antichitStatusLbl.Text = "🛡 Защита: ошибка компиляции"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        local runOk, runErr = pcall(fn)
        if not runOk then
            antichitLaunchBtn.Text = "❌ Ошибка запуска"
            antichitStatusLbl.Text = "🛡 Защита: " .. tostring(runErr):sub(1, 30)
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        antichitLoaded = true
        ORBIT.loaded.ac = true
        antichitLaunchBtn.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
        antichitLaunchBtn.BackgroundColor3 = Color3.fromRGB(60,100,60)
        antichitLaunchBtn.TextColor3 = Color3.fromRGB(200,255,200)
        antichitStatusLbl.Text = "🛡 Защита: активна (18 функций)"
        antichitStatusLbl.TextColor3 = Color3.fromRGB(160,255,180)
        ORBIT.notify("🛡 Античит запущен!", Color3.fromRGB(160,255,180), 3)
    end)
end)

task.spawn(function()
    while screenGui and screenGui.Parent and not antichitLoaded do
        task.wait(1)
        if ORBIT.loaded and ORBIT.loaded.ac then
            antichitLoaded = true
            antichitLaunchBtn.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
            antichitLaunchBtn.BackgroundColor3 = Color3.fromRGB(60,100,60)
            antichitStatusLbl.Text = "🛡 Защита: активна (18 функций)"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(160,255,180)
        end
    end
end)

-- ЗВУКИ
onClick(soundToggleBtn, function()
    if ORBIT.SOUNDS then
        ORBIT.SOUNDS.Enabled = not ORBIT.SOUNDS.Enabled
        soundToggleBtn.Text = "🔊 Звуки: " .. (ORBIT.SOUNDS.Enabled and "ВКЛ" or "ВЫКЛ")
    end
end)
local VOLUME_STEPS = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0}
local soundVolumeIndex = 11
onClick(soundVolumeBtn, function()
    if not ORBIT.SOUNDS then return end
    soundVolumeIndex = soundVolumeIndex + 1
    if soundVolumeIndex > #VOLUME_STEPS then soundVolumeIndex = 1 end
    local v = VOLUME_STEPS[soundVolumeIndex]
    ORBIT.SOUNDS.Volume = v
    soundVolumeBtn.Text = "🎵 Громкость: " .. math.floor(v * 100) .. "%"
end)
onClick(soundTestBtn, function()
    soundTestBtn.Text = "⏳ Проверяю..."
    task.wait(0.1)
    if ORBIT.playClick then ORBIT.playClick() end
    task.wait(0.4)
    if ORBIT.playDodge then ORBIT.playDodge() end
    task.wait(1.2)
    soundTestBtn.Text = "✅ Готово"
    task.wait(2)
    soundTestBtn.Text = "🔍 Проверка звуков"
end)

-- МЕТКИ
onClick(tagNearestBtn, function()
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
        ORBIT.toggleTagCheater(closest); task.wait(0.1); pcall(rebuildPeopleList)
    end
end)
onClick(clearTagsBtn, function()
    if ORBIT.clearAllTags then ORBIT.clearAllTags() end
    task.wait(0.1); pcall(rebuildPeopleList)
end)

-- МАГАЗИН
onClick(openShopBtn, function() if ORBIT.openShop then ORBIT.openShop() end end)
onClick(openEditorBtn, function() if ORBIT.openEditor then ORBIT.openEditor() end end)
onClick(openGameBtn, function() if ORBIT.openMiniGame then ORBIT.openMiniGame() end end)
do -- v24.0: Гастер и режим игрока
    local function modeBtnLabel() return (ORBIT.mode == "normal") and "🎭 Режим: Обычный" or "🎭 Режим: Санс" end
    UIK.modeLabel = modeBtnLabel
    onClick(UIK.openGasterBtn, function()
        if ORBIT.gaster and ORBIT.gaster.open then ORBIT.gaster.open()
        else ORBIT.notify("⚠️ Модуль Гастера не загружен", Color3.fromRGB(255,200,120), 3) end
    end)
    onClick(UIK.gasterWeaponBtn, function()
        local W = ORBIT.gaster and ORBIT.gaster.weapon
        if W and W.equip then W.equip()
        else ORBIT.notify("⚠️ Гастер-оружие не загружено", Color3.fromRGB(255,200,120), 3) end
    end)
    onClick(UIK.modeBtn, function()
        if ORBIT.setMode then ORBIT.setMode((ORBIT.mode == "normal") and "sans" or "normal") end
        UIK.modeBtn.Text = modeBtnLabel()
    end)
end

-- ============================================================
--       SHARE (упрощённый, v23.9) — обработчики
-- ============================================================
onClick(shareLoadBtn, function()
    local txt = shareInputBox.Text or ""
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
                shareInputBox.Text = body:gsub("^%s+", ""):gsub("%s+$", "")
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
    if ok then shareInputBox.Text = "" end
end)

onClick(shareCopyBtn, function()
    if not ORBIT.share or not ORBIT.share.encodeCurrentSettings then
        ORBIT.notify("❌ orbit_share.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        return
    end
    local str, err = ORBIT.share.encodeCurrentSettings()
    if not str then
        ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 3)
        return
    end
    shareInputBox.Text = str
    local ok = ORBIT.share.copy(str)
    if ok then
        ORBIT.notify("📤 Готово и скопировано — отправь другу", Color3.fromRGB(180, 255, 180), 3)
    else
        ORBIT.notify("📤 Готово — выдели строку и скопируй вручную", Color3.fromRGB(255, 220, 140), 4)
    end
end)

onClick(sharePasteBtn, function()
    if not ORBIT.share or not ORBIT.share.paste then
        ORBIT.notify("❌ orbit_share.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        return
    end
    local txt, err = ORBIT.share.paste()
    if not txt then
        ORBIT.notify("📋 " .. tostring(err) .. " — вставь вручную", Color3.fromRGB(255, 200, 120), 3)
        return
    end
    shareInputBox.Text = txt
    ORBIT.notify("📋 Вставлено (" .. #txt .. " симв.)", Color3.fromRGB(180, 220, 255), 2)
end)

onClick(shareClearBtn, function()
    shareInputBox.Text = ""
end)

-- ПОМОЩНИК
onClick(helperBtn, function()
    if ORBIT.helperOpen then
        ORBIT.helperOpen()
    else
        ORBIT.notify("❌ orbit_helper.lua не загружен", Color3.fromRGB(255,150,150), 3)
    end
end)

-- ПРОИЗВОДИТЕЛЬНОСТЬ
local PERF_MODES = {"auto", "high", "medium", "low", "minimal", "off"}
local PERF_LABELS = {auto="АВТО", high="ВЫСОКОЕ", medium="СРЕДНЕЕ", low="НИЗКОЕ", minimal="МИНИМУМ", off="ВЫКЛ"}
local perfIndex = 1
local function refreshPerfBtn()
    local info = ORBIT.getPerformanceInfo and ORBIT.getPerformanceInfo() or {Mode="auto", Current="high", FPS=60}
    perfBtn.Text = string.format("⚡ Качество: %s", PERF_LABELS[info.Mode] or info.Mode)
end
refreshPerfBtn()
onClick(perfBtn, function()
    perfIndex = perfIndex + 1; if perfIndex > #PERF_MODES then perfIndex = 1 end
    if ORBIT.setPerformanceMode then ORBIT.setPerformanceMode(PERF_MODES[perfIndex]) end
    refreshPerfBtn()
end)

-- СЕРДЦЕ
local heartScaleIndex = 4
local HEART_STEPS = P.HEART_STEPS or {0.2, 0.35, 0.5, 0.65, 0.9, 1.2, 1.6, 2.2}
for i, v in ipairs(HEART_STEPS) do if math.abs(v - SETTINGS.HeartScale) < 0.01 then heartScaleIndex = i; break end end
local function refreshHeartSizeBtn()
    local pct = math.floor(SETTINGS.HeartScale / 0.65 * 100 + 0.5)
    heartSizeBtn.Text = "💗 Размер сердца: " .. pct .. "%"
end
refreshHeartSizeBtn()
onClick(heartSizeBtn, function()
    heartScaleIndex = heartScaleIndex + 1
    if heartScaleIndex > #HEART_STEPS then heartScaleIndex = 1 end
    SETTINGS.HeartScale = HEART_STEPS[heartScaleIndex]
    refreshHeartSizeBtn(); ORBIT.rebuildAllRings()
end)
UIK.finishBuild()

-- ============================================================
--       ОТКРЫТИЕ/ЗАКРЫТИЕ
-- ============================================================
local panelOpen = false
local dragMoved = false
local panelScale = Instance.new("UIScale")
panelScale.Parent = window

local function setPanel(open)
    panelOpen = open
    if open then
        local abs = screenGui.AbsoluteSize
        local w = math.min(PANEL_W, abs.X - 16)
        local h = math.clamp(abs.Y - 40, 220, IS_MOBILE and 560 or 780)
        window.Size = UDim2.fromOffset(w, h)
        window.Position = UDim2.fromOffset(
            math.clamp(mainBtn.Position.X.Offset + (IS_MOBILE and 72 or 70), 4, math.max(4, abs.X - w - 8)),
            math.clamp(math.floor((abs.Y - h) / 2), 4, math.max(4, abs.Y - h - 4)))
        panelScale.Scale = 0.88
        window.Visible = true
        TweenService:Create(panelScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
        relayout()
    else
        TweenService:Create(panelScale, TweenInfo.new(0.12), { Scale = 0.88 }):Play()
        task.delay(0.13, function()
            if not panelOpen then window.Visible = false end
        end)
    end
end

onClick(mainBtn, function()
    if dragMoved then dragMoved = false; return end
    setPanel(not panelOpen)
end)
onClick(panelCloseBtn, function() setPanel(false) end)

-- ============================================================
--       ОБРАБОТЧИКИ
-- ============================================================
local ringButtons = { [2]=ring2Btn, [3]=ring3Btn, [4]=ring4Btn, [5]=ring5Btn }
local function refreshRingButton(ri)
    local btn = ringButtons[ri]; if not btn then return end
    if rings[ri].enabled then
        btn.Text = "➖ Кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(55,40,40); btn.TextColor3 = Color3.fromRGB(255,160,160)
    else
        btn.Text = "➕ Кольцо " .. ri
        btn.BackgroundColor3 = Color3.fromRGB(40,55,40); btn.TextColor3 = Color3.fromRGB(160,255,160)
    end
end

onClick(toggleBtn, function()
    ORBIT.setEnabled(not ORBIT.enabled)
    if ORBIT.enabled then
        toggleBtn.Text = "🟢 ВКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(0,255,120); toggleBtn.BackgroundColor3 = Color3.fromRGB(40,50,40)
    else
        toggleBtn.Text = "🔴 ВЫКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(255,80,80); toggleBtn.BackgroundColor3 = Color3.fromRGB(50,35,40)
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if statsLabel and statsLabel.Parent and ORBIT.SESSION then
            local s = ORBIT.SESSION
            local elapsed = tick() - (s.startTime or tick())
            local mins = math.floor(elapsed / 60)
            local secs = math.floor(elapsed % 60)
            local ringTargets = 0; for _ in pairs(ORBIT.targetRings or {}) do ringTargets = ringTargets + 1 end
            local savesCount = 0; for _ in pairs(ORBIT.SAVES or {}) do savesCount = savesCount + 1 end
            statsLabel.Text = string.format(
                "🎁 Ботов: %d  |  🚩 Читеров: %d\n🥷 Уворотов: %d\n🛡️ Защит: %d\n🎯 Колец на людях: %d  |  💾 Сохр: %d\n⏱️ %d:%02d",
                s.botsCollected or 0, s.cheatersTagged or 0,
                s.dodgesMade or 0, s.protectionsTriggered or 0,
                ringTargets, savesCount, mins, secs)
        end
    end
end)

onClick(resetSessionBtn, function()
    if ORBIT.SESSION then
        ORBIT.SESSION.botsCollected = 0
        ORBIT.SESSION.cheatersTagged = 0
        ORBIT.SESSION.dodgesMade = 0
        ORBIT.SESSION.protectionsTriggered = 0
        ORBIT.SESSION.startTime = tick()
        ORBIT.notify("📊 Статистика сброшена", Color3.fromRGB(180,220,255), 2)
    end
end)

onClick(espBtn, function()
    if ORBIT.setESPEnabled then
        ORBIT.setESPEnabled(not ORBIT.ESP.Enabled)
        espBtn.Text = "👁️ ESP игроков: " .. (ORBIT.ESP.Enabled and "ВКЛ" or "ВЫКЛ")
        if ORBIT.ESP.Enabled then
            espBtn.BackgroundColor3 = Color3.fromRGB(40,80,60)
            espBtn.TextColor3 = Color3.fromRGB(180,255,200)
        else
            espBtn.BackgroundColor3 = Color3.fromRGB(50,60,90)
            espBtn.TextColor3 = Color3.fromRGB(200,220,255)
        end
    end
end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        if taggedCount and ORBIT.getTaggedPlayers then
            taggedCount.Text = "⭐ Список читеров: " .. #ORBIT.getTaggedPlayers()
        end
    end
end)

local function rebuildPeopleList()
    local list = ORBIT.getPlayerList and ORBIT.getPlayerList() or {}
    local sigParts = {}
    for _, info in ipairs(list) do
        sigParts[#sigParts + 1] = info.name .. (info.hasRing and "1" or "0") .. (info.isTagged and "1" or "0")
    end
    local sig = table.concat(sigParts, "|")
    if sig == NB.peopleSig then return end
    NB.peopleSig = sig
    for _, ch in ipairs(peopleListScroll:GetChildren()) do
        if ch:IsA("Frame") or ch:IsA("TextLabel") then ch:Destroy() end
    end
    if #list == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -6, 0, 24)
        empty.BackgroundTransparency = 1
        empty.Text = "— на сервере только ты —"
        empty.TextColor3 = Color3.fromRGB(140, 130, 170)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 11
        empty.LayoutOrder = 1
        empty.Parent = peopleListScroll
        return
    end
    for i, info in ipairs(list) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 52)
        row.BackgroundColor3 = Color3.fromRGB(28, 22, 45)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = peopleListScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -8, 0, 18)
        nameLbl.Position = UDim2.new(0, 6, 0, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = "👤 " .. info.name
        nameLbl.TextColor3 = Color3.fromRGB(230, 220, 255)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local btnRow = Instance.new("Frame")
        btnRow.Size = UDim2.new(1, -8, 0, 24)
        btnRow.Position = UDim2.new(0, 4, 0, 22)
        btnRow.BackgroundTransparency = 1
        btnRow.Parent = row

        local ringBtn = Instance.new("TextButton")
        ringBtn.Size = UDim2.new(0.5, -2, 1, 0)
        if info.hasRing then
            ringBtn.Text = "➖ Убрать"
            ringBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            ringBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
        else
            ringBtn.Text = "➕ Полное кольцо"
            ringBtn.BackgroundColor3 = Color3.fromRGB(40, 70, 45)
            ringBtn.TextColor3 = Color3.fromRGB(160, 255, 180)
        end
        ringBtn.Font = Enum.Font.GothamBold
        ringBtn.TextSize = 10
        ringBtn.Parent = btnRow
        Instance.new("UICorner", ringBtn).CornerRadius = UDim.new(0, 5)

        local tagBtn = Instance.new("TextButton")
        tagBtn.Size = UDim2.new(0.5, -2, 1, 0)
        tagBtn.Position = UDim2.new(0.5, 2, 0, 0)
        if info.isTagged then
            tagBtn.Text = "✅ Снять метку"
            tagBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 50)
            tagBtn.TextColor3 = Color3.fromRGB(220, 200, 220)
        else
            tagBtn.Text = "🚩 Читер"
            tagBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 55)
            tagBtn.TextColor3 = Color3.fromRGB(255, 150, 200)
        end
        tagBtn.Font = Enum.Font.GothamBold
        tagBtn.TextSize = 10
        tagBtn.Parent = btnRow
        Instance.new("UICorner", tagBtn).CornerRadius = UDim.new(0, 5)

        onClick(ringBtn, function()
            if ORBIT.toggleTargetRings then ORBIT.toggleTargetRings(info.player) end
            task.wait(0.1); rebuildPeopleList()
        end)
        onClick(tagBtn, function()
            if ORBIT.toggleTagCheater then ORBIT.toggleTagCheater(info.player) end
            task.wait(0.1); rebuildPeopleList()
        end)
    end
end
rebuildPeopleList()

onClick(refreshPeopleBtn, function()
    NB.peopleSig = nil
    rebuildPeopleList()
    refreshPeopleBtn.Text = "✅ Обновлено"
    task.wait(0.8)
    refreshPeopleBtn.Text = "🔄 Обновить список игроков"
end)

onClick(addAllRingsBtn, function() if ORBIT.addRingsToAll then ORBIT.addRingsToAll() end; task.wait(0.2); rebuildPeopleList() end)
onClick(remAllRingsBtn, function() if ORBIT.removeRingsFromAll then ORBIT.removeRingsFromAll() end; task.wait(0.2); rebuildPeopleList() end)
onClick(toggleAllRingsBtn, function() if ORBIT.toggleAllRings then ORBIT.toggleAllRings() end; task.wait(0.2); rebuildPeopleList() end)

task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(4)
        if window.Visible then pcall(rebuildPeopleList) end
    end
end)
UIK.connect(Players.PlayerAdded, function(p) if p ~= LocalPlayer then task.wait(0.5); pcall(rebuildPeopleList) end end)
UIK.connect(Players.PlayerRemoving, function(p) if p ~= LocalPlayer then task.wait(0.3); pcall(rebuildPeopleList) end end)

-- БОТЫ
onClick(botCreateNearBtn, function() if ORBIT.createBotNear then ORBIT.createBotNear() end end)
onClick(botCreate5Btn, function() ORBIT.createMultipleBots(5) end)
onClick(botCreate25Btn, function() ORBIT.createManyBots(25) end)
onClick(botCreate100Btn, function() ORBIT.createManyBots(100) end)
onClick(botRemoveAll, function() ORBIT.removeAllBots() end)
onClick(botAutoCollectBtn, function()
    ORBIT.botSettings.AutoCollect = not ORBIT.botSettings.AutoCollect
    botAutoCollectBtn.Text = "🎁 Автосбор: " .. (ORBIT.botSettings.AutoCollect and "ВКЛ" or "ВЫКЛ")
end)
onClick(botRadiusBtn, function()
    local steps = {6, 8, 10, 12, 15, 20, 25}
    local idx = 1
    for i, v in ipairs(steps) do if v == ORBIT.botSettings.CollectRadius then idx = i; break end end
    ORBIT.botSettings.CollectRadius = steps[(idx % #steps) + 1]
    botRadiusBtn.Text = "📏 Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st"
end)
onClick(botShowPlayerRing, function()
    ORBIT.botSettings.ShowPlayerRing = not ORBIT.botSettings.ShowPlayerRing
    botShowPlayerRing.Text = "👤 Кольцо как у игрока: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ")
    ORBIT.notify("👤 Кольцо ботов: " .. (ORBIT.botSettings.ShowPlayerRing and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200,180,255), 2)
end)
onClick(botSkinBtnEnd, function()
    ORBIT.botSettings.UseMySkin = not ORBIT.botSettings.UseMySkin
    botSkinBtnEnd.Text = "🎭 Скин как у меня: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ")
    ORBIT.botAvatarTemplate = nil
    ORBIT.notify("🎭 Скин бота: " .. (ORBIT.botSettings.UseMySkin and "ВКЛ" or "ВЫКЛ"), Color3.fromRGB(200, 180, 255), 2)
end)
if ORBIT.botSettings.UseMySkin then botSkinBtnEnd.Text = "🎭 Скин как у меня: ВКЛ" end
if ORBIT.botSettings.ShowPlayerRing then botShowPlayerRing.Text = "👤 Кольцо как у игрока: ВКЛ" end

-- КОЛЬЦА
onClick(allRingsBtn, function()
    local anyOff = false
    for ri = 2, 5 do if not rings[ri].enabled then anyOff = true; break end end
    local ns = anyOff
    for ri = 2, 5 do if rings[ri].enabled ~= ns then ORBIT.setRingEnabled(ri, ns) end end
    for ri = 2, 5 do refreshRingButton(ri) end
    allRingsBtn.Text = ns and "⭕ Все кольца: ВЫКЛ" or "⭕ Все кольца: ВКЛ"
end)
for ri, btn in pairs(ringButtons) do
    onClick(btn, function() ORBIT.setRingEnabled(ri, not rings[ri].enabled); refreshRingButton(ri) end)
end

-- ВНЕШНИЙ ВИД
onClick(shapeCatBtn, function()
    P.shapeCategoryIndex = P.shapeCategoryIndex + 1
    if P.shapeCategoryIndex > #P.SHAPE_CATEGORIES then P.shapeCategoryIndex = 1 end
    shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs > 0 then
        ORBIT.shapeIndex = idxs[1]
        shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
        ORBIT.applyShapes(); ORBIT.rebuildAllRings()
    end
end)
onClick(shapeBtn, function()
    local idxs = ORBIT.getShapeIndicesInCategory()
    if #idxs == 0 then return end
    local pos = nil
    for i, v in ipairs(idxs) do if v == ORBIT.shapeIndex then pos = i; break end end
    local newPos = pos and (pos % #idxs) + 1 or 1
    ORBIT.shapeIndex = idxs[newPos]
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
onClick(shapeModeBtn, function()
    P.formModeIndex = P.formModeIndex + 1; if P.formModeIndex > #P.FORM_MODES then P.formModeIndex = 1 end
    shapeModeBtn.Text = "🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name
    ORBIT.applyShapes(); ORBIT.rebuildAllRings()
end)
onClick(shapeSizeBtn, function()
    P.shapeSizeIndex = P.shapeSizeIndex + 1; if P.shapeSizeIndex > #P.SHAPE_SIZE then P.shapeSizeIndex = 1 end
    shapeSizeBtn.Text = "🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    ORBIT.rebuildAllRings()
end)
onClick(gradientBtn, function()
    SETTINGS.GradientEnabled = not SETTINGS.GradientEnabled
    gradientBtn.Text = "🌈 Градиент: " .. (SETTINGS.GradientEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.GradientEnabled then SETTINGS.Rainbow = false end
    ORBIT.rebuildAllRings()
end)
onClick(lightBtn, function()
    SETTINGS.LightEnabled = not SETTINGS.LightEnabled
    lightBtn.Text = "💡 Свет: " .. (SETTINGS.LightEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
onClick(nameBtn, function()
    SETTINGS.ShowBlockNames = not SETTINGS.ShowBlockNames
    nameBtn.Text = "🏷️ Имена блоков: " .. (SETTINGS.ShowBlockNames and "ВКЛ" or "ВЫКЛ")
    ORBIT.applyNameVisibility()
end)
onClick(autoSwapBtn, function()
    SETTINGS.AutoShapeSwap = not SETTINGS.AutoShapeSwap
    autoSwapBtn.Text = "🎭 Автосмена: " .. (SETTINGS.AutoShapeSwap and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AutoShapeSwap then ORBIT.lastAutoSwap = tick() end
end)

-- ДВИЖЕНИЕ
onClick(orbitBtn, function()
    P.orbitIndex = P.orbitIndex + 1; if P.orbitIndex > #P.ORBIT then P.orbitIndex = 1 end
    orbitBtn.Text = "📏 Орбита: " .. P.ORBIT[P.orbitIndex].name
end)
onClick(spreadBtn, function()
    P.spreadIndex = P.spreadIndex + 1; if P.spreadIndex > #P.SPREAD then P.spreadIndex = 1 end
    spreadBtn.Text = "📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name
end)
onClick(heightBtn, function()
    P.heightIndex = P.heightIndex + 1; if P.heightIndex > #P.HEIGHT then P.heightIndex = 1 end
    heightBtn.Text = "⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name
end)
onClick(speedBtn, function()
    P.speedIndex = P.speedIndex + 1; if P.speedIndex > #P.SPEED then P.speedIndex = 1 end
    SETTINGS.SpeedMultiplier = P.SPEED[P.speedIndex].value
    speedBtn.Text = "⚡ Множитель: " .. P.SPEED[P.speedIndex].name
end)
onClick(speedModeBtn, function()
    P.speedModeIndex = P.speedModeIndex + 1; if P.speedModeIndex > #P.SPEED_MODE then P.speedModeIndex = 1 end
    speedModeBtn.Text = "⚙️ Режим: " .. P.SPEED_MODE[P.speedModeIndex].name
    ORBIT.applySpeedModePreset()
end)
onClick(directionBtn, function()
    P.directionIndex = P.directionIndex + 1; if P.directionIndex > #P.DIRECTION then P.directionIndex = 1 end
    directionBtn.Text = "🔃 Направление: " .. P.DIRECTION[P.directionIndex].name
    ORBIT.applyDirectionPreset()
end)
onClick(orbitPatternBtn, function()
    P.orbitPatternIndex = P.orbitPatternIndex + 1; if P.orbitPatternIndex > #P.ORBIT_PATTERNS then P.orbitPatternIndex = 1 end
    SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[P.orbitPatternIndex].name
    orbitPatternBtn.Text = "🌀 Узор: " .. SETTINGS.OrbitPattern
end)

-- КРУЧЕНИЕ
onClick(spinBtn, function()
    ORBIT.spinResetting = not ORBIT.spinResetting
    spinBtn.Text = ORBIT.spinResetting and "↩️ Вращение: ВОЗВРАТ" or "↩️ Вращение в 0"
end)
onClick(spinAxisBtn, function()
    ORBIT.spinAxisEnabled = not ORBIT.spinAxisEnabled
    spinAxisBtn.Text = "🔄 Кручение оси: " .. (ORBIT.spinAxisEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(spinDirBtn, function()
    if ORBIT.spinAxisDir == "X" then ORBIT.spinAxisDir = "Y"; spinDirBtn.Text = "↔️ Ось: ВЛЕВО/ВПРАВО"
    else ORBIT.spinAxisDir = "X"; spinDirBtn.Text = "↕️ Ось: ВЕРХ/ВНИЗ" end
end)
onClick(spinSpeedBtn, function()
    P.spinSpeedIndex = P.spinSpeedIndex + 1; if P.spinSpeedIndex > #P.SPIN_SPEED then P.spinSpeedIndex = 1 end
    SETTINGS.SpinSpeedMultiplier = P.SPIN_SPEED[P.spinSpeedIndex].value
    spinSpeedBtn.Text = "🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
end)

-- ЭФФЕКТЫ
onClick(trailBtn, function()
    SETTINGS.TrailEnabled = not SETTINGS.TrailEnabled
    trailBtn.Text = "🌠 Трейлы: " .. (SETTINGS.TrailEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)
onClick(trailLenBtn, function()
    P.trailLengthIndex = P.trailLengthIndex + 1; if P.trailLengthIndex > #P.TRAIL_LEN then P.trailLengthIndex = 1 end
    SETTINGS.TrailLength = P.TRAIL_LEN[P.trailLengthIndex].value
    trailLenBtn.Text = "📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(trailWidBtn, function()
    P.trailWidthIndex = P.trailWidthIndex + 1; if P.trailWidthIndex > #P.TRAIL_WID then P.trailWidthIndex = 1 end
    SETTINGS.TrailWidth = P.TRAIL_WID[P.trailWidthIndex].value
    trailWidBtn.Text = "🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(waveBtn, function()
    SETTINGS.WaveEnabled = not SETTINGS.WaveEnabled
    waveBtn.Text = "🌊 Волна: " .. (SETTINGS.WaveEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(explosionBtn, function()
    SETTINGS.ExplosionEnabled = not SETTINGS.ExplosionEnabled
    explosionBtn.Text = "💥 Взрыв: " .. (SETTINGS.ExplosionEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(pulseBtn, function()
    SETTINGS.PulseEnabled = not SETTINGS.PulseEnabled
    pulseBtn.Text = "💓 Пульсация: " .. (SETTINGS.PulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- АУРА
local function refreshAura()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
onClick(auraBtn, function()
    SETTINGS.AuraEnabled = not SETTINGS.AuraEnabled
    auraBtn.Text = "🌀 Аура: " .. (SETTINGS.AuraEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraEnabled then
        if not SETTINGS.AuraRing and not SETTINGS.AuraParticles and not SETTINGS.AuraShapes then
            SETTINGS.AuraRing = true; SETTINGS.AuraParticles = true; SETTINGS.AuraShapes = true
            auraRingBtn.Text = "⭕ Кольцо: ВКЛ"; auraPartBtn.Text = "✨ Частицы: ВКЛ"; auraFigBtn.Text = "🔷 Фигуры: ВКЛ"
        end
        ORBIT.setupAura()
    else
        if ORBIT.auraFolder then ORBIT.auraFolder:Destroy(); ORBIT.auraFolder = nil end
    end
end)
onClick(auraRingBtn, function()
    SETTINGS.AuraRing = not SETTINGS.AuraRing
    auraRingBtn.Text = "⭕ Кольцо: " .. (SETTINGS.AuraRing and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraPartBtn, function()
    SETTINGS.AuraParticles = not SETTINGS.AuraParticles
    auraPartBtn.Text = "✨ Частицы: " .. (SETTINGS.AuraParticles and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraFigBtn, function()
    SETTINGS.AuraShapes = not SETTINGS.AuraShapes
    auraFigBtn.Text = "🔷 Фигуры: " .. (SETTINGS.AuraShapes and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraShapeBtn, function()
    ORBIT.auraShapeIndex = ORBIT.auraShapeIndex + 1
    if ORBIT.auraShapeIndex > #SHAPE_PRESETS then ORBIT.auraShapeIndex = 1 end
    auraShapeBtn.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    refreshAura()
end)
onClick(auraSizeBtn, function()
    P.auraSizeIndex = P.auraSizeIndex + 1; if P.auraSizeIndex > #P.AURA_SIZE then P.auraSizeIndex = 1 end
    SETTINGS.AuraSize = P.AURA_SIZE[P.auraSizeIndex].value
    auraSizeBtn.Text = "📐 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    refreshAura()
end)
onClick(auraThickBtn, function()
    P.auraThickIndex = P.auraThickIndex + 1; if P.auraThickIndex > #P.AURA_THICK then P.auraThickIndex = 1 end
    SETTINGS.AuraThickness = P.AURA_THICK[P.auraThickIndex].value
    auraThickBtn.Text = "🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    refreshAura()
end)
onClick(auraHeightBtn, function()
    P.auraHeightIndex = P.auraHeightIndex + 1; if P.auraHeightIndex > #P.AURA_HEIGHT then P.auraHeightIndex = 1 end
    SETTINGS.AuraHeight = P.AURA_HEIGHT[P.auraHeightIndex].value
    auraHeightBtn.Text = "⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
    refreshAura()
end)
onClick(auraShapeScaleBtn, function()
    P.auraShapeScaleIndex = P.auraShapeScaleIndex + 1; if P.auraShapeScaleIndex > #P.AURA_SHAPE_SCALE then P.auraShapeScaleIndex = 1 end
    SETTINGS.AuraShapeScale = P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].factor
    auraShapeScaleBtn.Text = "🔍 Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    refreshAura()
end)
onClick(auraPatternBtn, function()
    P.auraPatternIndex = P.auraPatternIndex + 1
    if P.auraPatternIndex > #P.AURA_PATTERNS then P.auraPatternIndex = 1 end
    SETTINGS.AuraPattern = P.AURA_PATTERNS[P.auraPatternIndex].name
    auraPatternBtn.Text = "🌀 Узор ауры: " .. SETTINGS.AuraPattern
end)
onClick(auraSpeedBtn, function()
    P.auraSpeedIndex = P.auraSpeedIndex + 1; if P.auraSpeedIndex > #P.AURA_SPEED then P.auraSpeedIndex = 1 end
    SETTINGS.AuraSpeedMult = P.AURA_SPEED[P.auraSpeedIndex].value
    auraSpeedBtn.Text = "⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
end)
onClick(auraDirBtn, function()
    P.auraDirIndex = P.auraDirIndex + 1; if P.auraDirIndex > #P.AURA_DIR then P.auraDirIndex = 1 end
    SETTINGS.AuraDirection = P.AURA_DIR[P.auraDirIndex].value
    auraDirBtn.Text = "🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name
end)
onClick(auraTrailBtn, function()
    SETTINGS.AuraTrailEnabled = not SETTINGS.AuraTrailEnabled
    auraTrailBtn.Text = "🌠 Трейлы ауры: " .. (SETTINGS.AuraTrailEnabled and "ВКЛ" or "ВЫКЛ")
    refreshAura()
end)
onClick(auraTrailLenBtn, function()
    P.auraTrailLengthIndex = P.auraTrailLengthIndex + 1; if P.auraTrailLengthIndex > #P.AURA_TRAIL_LEN then P.auraTrailLengthIndex = 1 end
    SETTINGS.AuraTrailLength = P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].value
    auraTrailLenBtn.Text = "📏 Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(auraTrailWidBtn, function()
    P.auraTrailWidthIndex = P.auraTrailWidthIndex + 1; if P.auraTrailWidthIndex > #P.AURA_TRAIL_WID then P.auraTrailWidthIndex = 1 end
    SETTINGS.AuraTrailWidth = P.AURA_TRAIL_WID[P.auraTrailWidthIndex].value
    auraTrailWidBtn.Text = "🎚️ Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
    ORBIT.refreshAllTrails()
end)
onClick(auraSpinBtn, function()
    SETTINGS.AuraSpinEnabled = not SETTINGS.AuraSpinEnabled
    auraSpinBtn.Text = "🔄 Кручение: " .. (SETTINGS.AuraSpinEnabled and "ВКЛ" or "ВЫКЛ")
end)
onClick(auraSpinAxisBtn, function()
    P.auraSpinAxisIndex = P.auraSpinAxisIndex + 1; if P.auraSpinAxisIndex > #P.AURA_SPIN_AXIS then P.auraSpinAxisIndex = 1 end
    SETTINGS.AuraSpinAxis = P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].value
    auraSpinAxisBtn.Text = "↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
end)
onClick(auraSpinSpeedBtn, function()
    P.auraSpinSpeedIndex = P.auraSpinSpeedIndex + 1; if P.auraSpinSpeedIndex > #P.AURA_SPIN_SPEED then P.auraSpinSpeedIndex = 1 end
    SETTINGS.AuraSpinSpeed = P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].value
    auraSpinSpeedBtn.Text = "🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
end)
onClick(auraPulseBtn, function()
    SETTINGS.AuraPulseEnabled = not SETTINGS.AuraPulseEnabled
    auraPulseBtn.Text = "💓 Пульсация ауры: " .. (SETTINGS.AuraPulseEnabled and "ВКЛ" or "ВЫКЛ")
end)

-- СВЕТ АУРЫ
onClick(auraLightBtn, function()
    SETTINGS.AuraLightEnabled = not SETTINGS.AuraLightEnabled
    auraLightBtn.Text = "💡 Свет ауры: " .. (SETTINGS.AuraLightEnabled and "ВКЛ" or "ВЫКЛ")
    if SETTINGS.AuraLightEnabled then
        auraLightBtn.BackgroundColor3 = Color3.fromRGB(120,100,40)
        auraLightBtn.TextColor3 = Color3.fromRGB(255,240,160)
    else
        auraLightBtn.BackgroundColor3 = Color3.fromRGB(70,60,30)
        auraLightBtn.TextColor3 = Color3.fromRGB(255,230,140)
    end
    refreshAura()
end)
onClick(auraLightRangeBtn, function()
    local steps = {4, 6, 8, 12, 16, 24, 32}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightRange then idx = i; break end end
    SETTINGS.AuraLightRange = steps[(idx % #steps) + 1]
    auraLightRangeBtn.Text = "📏 Дальность: " .. SETTINGS.AuraLightRange
    refreshAura()
end)
onClick(auraLightBrightBtn, function()
    local steps = {1, 2, 3, 5, 8, 12}
    local idx = 1
    for i, v in ipairs(steps) do if v == SETTINGS.AuraLightBrightness then idx = i; break end end
    SETTINGS.AuraLightBrightness = steps[(idx % #steps) + 1]
    auraLightBrightBtn.Text = "✨ Яркость: " .. SETTINGS.AuraLightBrightness
    refreshAura()
end)

-- ГРАФИКА
local MATERIALS = {"Neon", "Glass", "ForceField", "Plastic", "SmoothPlastic", "Metal", "Ice", "Marble", "Slate", "Granite"}
local materialIndex = 1
for i, m in ipairs(MATERIALS) do
    if m == tostring(SETTINGS.Material):gsub("Enum.Material.", "") then materialIndex = i; break end
end
onClick(materialBtn, function()
    materialIndex = materialIndex + 1
    if materialIndex > #MATERIALS then materialIndex = 1 end
    local mName = MATERIALS[materialIndex]
    SETTINGS.Material = Enum.Material[mName]
    materialBtn.Text = "🎨 Материал: " .. mName:upper()
    ORBIT.rebuildAllRings()
end)
if SETTINGS.Material then
    materialBtn.Text = "🎨 Материал: " .. tostring(SETTINGS.Material):gsub("Enum.Material.", ""):upper()
end

onClick(transparencyBtn, function()
    local steps = {0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9}
    local idx = 1
    for i, v in ipairs(steps) do if math.abs(v - SETTINGS.Transparency) < 0.01 then idx = i; break end end
    SETTINGS.Transparency = steps[(idx % #steps) + 1]
    transparencyBtn.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"
    ORBIT.rebuildAllRings()
end)
transparencyBtn.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100) .. "%"

onClick(brightnessBtn, function()
    local steps = {0.5, 1, 1.5, 2, 3, 5, 8}
    local idx = 1
    for i, v in ipairs(steps) do if v == (SETTINGS.GlowIntensity or 1) then idx = i; break end end
    SETTINGS.GlowIntensity = steps[(idx % #steps) + 1]
    brightnessBtn.Text = "☀️ Яркость: " .. SETTINGS.GlowIntensity
    ORBIT.rebuildAllRings()
end)
brightnessBtn.Text = "☀️ Яркость: " .. (SETTINGS.GlowIntensity or 1)

onClick(glowBtn, function()
    SETTINGS.GlowEnabled = not (SETTINGS.GlowEnabled ~= false)
    local on = SETTINGS.GlowEnabled
    glowBtn.Text = "✨ Свечение: " .. (on and "ВКЛ" or "ВЫКЛ")
    if on then
        glowBtn.BackgroundColor3 = Color3.fromRGB(35,60,50); glowBtn.TextColor3 = Color3.fromRGB(180,255,220)
    else
        glowBtn.BackgroundColor3 = Color3.fromRGB(45,45,65); glowBtn.TextColor3 = Color3.fromRGB(200,200,220)
    end
    for _, ring in pairs(rings) do
        for _, d in ipairs(ring.blocks) do
            if d.light then d.light.Enabled = on end
        end
    end
end)

onClick(castShadowBtn, function()
    SETTINGS.CastShadow = not SETTINGS.CastShadow
    castShadowBtn.Text = "🌑 Тени: " .. (SETTINGS.CastShadow and "ВКЛ" or "ВЫКЛ")
    ORBIT.rebuildAllRings()
end)

local GRAPHIC_MODES = {"LOW", "MEDIUM", "HIGH", "ULTRA"}
local graphicModeIndex = 2
local function applyGraphicMode(mode)
    if mode == "LOW" then
        SETTINGS.LightEnabled = false
        SETTINGS.TrailEnabled = false
        SETTINGS.AuraParticles = false
        SETTINGS.BlockCount = 4
    elseif mode == "MEDIUM" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 10
        SETTINGS.TrailEnabled = false
        SETTINGS.AuraParticles = true
        SETTINGS.BlockCount = 6
    elseif mode == "HIGH" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 20
        SETTINGS.TrailEnabled = true
        SETTINGS.AuraParticles = true
        SETTINGS.BlockCount = 8
    elseif mode == "ULTRA" then
        SETTINGS.LightEnabled = true
        SETTINGS.LightLimit = 40
        SETTINGS.TrailEnabled = true
        SETTINGS.AuraParticles = true
        SETTINGS.AuraShapes = true
        SETTINGS.BlockCount = 12
    end
    ORBIT.rebuildAllRings()
    if SETTINGS.AuraEnabled then ORBIT.setupAura() end
end
onClick(qualityBtn, function()
    graphicModeIndex = graphicModeIndex + 1
    if graphicModeIndex > #GRAPHIC_MODES then graphicModeIndex = 1 end
    local mode = GRAPHIC_MODES[graphicModeIndex]
    qualityBtn.Text = "⚡ Качество графики: " .. mode
    applyGraphicMode(mode)
    ORBIT.notify("🎨 Графика: " .. mode, Color3.fromRGB(200,220,255), 2)
end)

-- ОГОНЬ
onClick(fireBtn, function()
    SETTINGS.FireEnabled = not SETTINGS.FireEnabled
    fireBtn.Text = "🔥 Огонь: " .. (SETTINGS.FireEnabled and "ВКЛ" or "ВЫКЛ")
    ORBIT.setupFire()
end)
onClick(fireSizeBtn, function()
    P.fireSizeIndex = P.fireSizeIndex + 1; if P.fireSizeIndex > #P.FIRE_SIZE then P.fireSizeIndex = 1 end
    SETTINGS.FireSize = P.FIRE_SIZE[P.fireSizeIndex].value
    fireSizeBtn.Text = "📏 Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)
onClick(fireHeatBtn, function()
    P.fireHeatIndex = P.fireHeatIndex + 1; if P.fireHeatIndex > #P.FIRE_HEAT then P.fireHeatIndex = 1 end
    SETTINGS.FireHeat = P.FIRE_HEAT[P.fireHeatIndex].value
    fireHeatBtn.Text = "🌡️ Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if SETTINGS.FireEnabled then ORBIT.setupFire() end
end)

-- ЗАЩИТА
local antichitLoaded = false
onClick(antichitLaunchBtn, function()
    if antichitLoaded or (ORBIT.loaded and ORBIT.loaded.ac) then
        antichitLoaded = true
        antichitLaunchBtn.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
        antichitStatusLbl.Text = "🛡 Защита: активна (18 функций)"
        antichitStatusLbl.TextColor3 = Color3.fromRGB(160,255,180)
        ORBIT.notify("🛡 Античит уже запущен", Color3.fromRGB(180,255,180), 2)
        return
    end
    antichitLaunchBtn.Text = "⏳ Загружаю..."
    task.spawn(function()
        local url = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/orbit_anticheat.lua?t=" .. os.time()
        local ok, src = pcall(function() return game:HttpGet(url) end)
        if not ok or type(src) ~= "string" or #src < 100 then
            antichitLaunchBtn.Text = "❌ Ошибка загрузки"
            antichitStatusLbl.Text = "🛡 Защита: ошибка сети"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            antichitLaunchBtn.Text = "❌ Ошибка кода"
            antichitStatusLbl.Text = "🛡 Защита: ошибка компиляции"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        local runOk, runErr = pcall(fn)
        if not runOk then
            antichitLaunchBtn.Text = "❌ Ошибка запуска"
            antichitStatusLbl.Text = "🛡 Защита: " .. tostring(runErr):sub(1, 30)
            antichitStatusLbl.TextColor3 = Color3.fromRGB(255,150,150)
            task.wait(2)
            antichitLaunchBtn.Text = "🛡️ Запустить АНТИ-ЧИТ"
            return
        end
        antichitLoaded = true
        ORBIT.loaded.ac = true
        antichitLaunchBtn.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
        antichitLaunchBtn.BackgroundColor3 = Color3.fromRGB(60,100,60)
        antichitLaunchBtn.TextColor3 = Color3.fromRGB(200,255,200)
        antichitStatusLbl.Text = "🛡 Защита: активна (18 функций)"
        antichitStatusLbl.TextColor3 = Color3.fromRGB(160,255,180)
        ORBIT.notify("🛡 Античит запущен!", Color3.fromRGB(160,255,180), 3)
    end)
end)

task.spawn(function()
    while screenGui and screenGui.Parent and not antichitLoaded do
        task.wait(1)
        if ORBIT.loaded and ORBIT.loaded.ac then
            antichitLoaded = true
            antichitLaunchBtn.Text = "✅ АНТИ-ЧИТ АКТИВЕН"
            antichitLaunchBtn.BackgroundColor3 = Color3.fromRGB(60,100,60)
            antichitStatusLbl.Text = "🛡 Защита: активна (18 функций)"
            antichitStatusLbl.TextColor3 = Color3.fromRGB(160,255,180)
        end
    end
end)

-- ЗВУКИ
onClick(soundToggleBtn, function()
    if ORBIT.SOUNDS then
        ORBIT.SOUNDS.Enabled = not ORBIT.SOUNDS.Enabled
        soundToggleBtn.Text = "🔊 Звуки: " .. (ORBIT.SOUNDS.Enabled and "ВКЛ" or "ВЫКЛ")
    end
end)
local VOLUME_STEPS = {0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0}
local soundVolumeIndex = 11
onClick(soundVolumeBtn, function()
    if not ORBIT.SOUNDS then return end
    soundVolumeIndex = soundVolumeIndex + 1
    if soundVolumeIndex > #VOLUME_STEPS then soundVolumeIndex = 1 end
    local v = VOLUME_STEPS[soundVolumeIndex]
    ORBIT.SOUNDS.Volume = v
    soundVolumeBtn.Text = "🎵 Громкость: " .. math.floor(v * 100) .. "%"
end)
onClick(soundTestBtn, function()
    soundTestBtn.Text = "⏳ Проверяю..."
    task.wait(0.1)
    if ORBIT.playClick then ORBIT.playClick() end
    task.wait(0.4)
    if ORBIT.playDodge then ORBIT.playDodge() end
    task.wait(1.2)
    soundTestBtn.Text = "✅ Готово"
    task.wait(2)
    soundTestBtn.Text = "🔍 Проверка звуков"
end)

-- МЕТКИ
onClick(tagNearestBtn, function()
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
        ORBIT.toggleTagCheater(closest); task.wait(0.1); pcall(rebuildPeopleList)
    end
end)
onClick(clearTagsBtn, function()
    if ORBIT.clearAllTags then ORBIT.clearAllTags() end
    task.wait(0.1); pcall(rebuildPeopleList)
end)

-- МАГАЗИН
onClick(openShopBtn, function() if ORBIT.openShop then ORBIT.openShop() end end)
onClick(openEditorBtn, function() if ORBIT.openEditor then ORBIT.openEditor() end end)
onClick(openGameBtn, function() if ORBIT.openMiniGame then ORBIT.openMiniGame() end end)
do -- v24.0: Гастер и режим игрока
    local function modeBtnLabel() return (ORBIT.mode == "normal") and "🎭 Режим: Обычный" or "🎭 Режим: Санс" end
    UIK.modeLabel = modeBtnLabel
    onClick(UIK.openGasterBtn, function()
        if ORBIT.gaster and ORBIT.gaster.open then ORBIT.gaster.open()
        else ORBIT.notify("⚠️ Модуль Гастера не загружен", Color3.fromRGB(255,200,120), 3) end
    end)
    onClick(UIK.gasterWeaponBtn, function()
        local W = ORBIT.gaster and ORBIT.gaster.weapon
        if W and W.equip then W.equip()
        else ORBIT.notify("⚠️ Гастер-оружие не загружено", Color3.fromRGB(255,200,120), 3) end
    end)
    onClick(UIK.modeBtn, function()
        if ORBIT.setMode then ORBIT.setMode((ORBIT.mode == "normal") and "sans" or "normal") end
        UIK.modeBtn.Text = modeBtnLabel()
    end)
end

-- ============================================================
--       SHARE (упрощённый, v23.9) — обработчики
-- ============================================================
onClick(shareLoadBtn, function()
    local txt = shareInputBox.Text or ""
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
                shareInputBox.Text = body:gsub("^%s+", ""):gsub("%s+$", "")
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
    if ok then shareInputBox.Text = "" end
end)

onClick(shareCopyBtn, function()
    if not ORBIT.share or not ORBIT.share.encodeCurrentSettings then
        ORBIT.notify("❌ orbit_share.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        return
    end
    local str, err = ORBIT.share.encodeCurrentSettings()
    if not str then
        ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255, 150, 150), 3)
        return
    end
    shareInputBox.Text = str
    local ok = ORBIT.share.copy(str)
    if ok then
        ORBIT.notify("📤 Готово и скопировано — отправь другу", Color3.fromRGB(180, 255, 180), 3)
    else
        ORBIT.notify("📤 Готово — выдели строку и скопируй вручную", Color3.fromRGB(255, 220, 140), 4)
    end
end)

onClick(sharePasteBtn, function()
    if not ORBIT.share or not ORBIT.share.paste then
        ORBIT.notify("❌ orbit_share.lua не загружен", Color3.fromRGB(255, 150, 150), 3)
        return
    end
    local txt, err = ORBIT.share.paste()
    if not txt then
        ORBIT.notify("📋 " .. tostring(err) .. " — вставь вручную", Color3.fromRGB(255, 200, 120), 3)
        return
    end
    shareInputBox.Text = txt
    ORBIT.notify("📋 Вставлено (" .. #txt .. " симв.)", Color3.fromRGB(180, 220, 255), 2)
end)

onClick(shareClearBtn, function()
    shareInputBox.Text = ""
end)

-- ПОМОЩНИК
onClick(helperBtn, function()
    if ORBIT.helperOpen then
        ORBIT.helperOpen()
    else
        ORBIT.notify("❌ orbit_helper.lua не загружен", Color3.fromRGB(255,150,150), 3)
    end
end)

-- ПРОИЗВОДИТЕЛЬНОСТЬ
local PERF_MODES = {"auto", "high", "medium", "low", "minimal", "off"}
local PERF_LABELS = {auto="АВТО", high="ВЫСОКОЕ", medium="СРЕДНЕЕ", low="НИЗКОЕ", minimal="МИНИМУМ", off="ВЫКЛ"}
local perfIndex = 1
local function refreshPerfBtn()
    local info = ORBIT.getPerformanceInfo and ORBIT.getPerformanceInfo() or {Mode="auto", Current="high", FPS=60}
    perfBtn.Text = string.format("⚡ Качество: %s", PERF_LABELS[info.Mode] or info.Mode)
end
refreshPerfBtn()
onClick(perfBtn, function()
    perfIndex = perfIndex + 1; if perfIndex > #PERF_MODES then perfIndex = 1 end
    if ORBIT.setPerformanceMode then ORBIT.setPerformanceMode(PERF_MODES[perfIndex]) end
    refreshPerfBtn()
end)

-- СЕРДЦЕ
local heartScaleIndex = 4
local HEART_STEPS = P.HEART_STEPS or {0.2, 0.35, 0.5, 0.65, 0.9, 1.2, 1.6, 2.2}
for i, v in ipairs(HEART_STEPS) do if math.abs(v - SETTINGS.HeartScale) < 0.01 then heartScaleIndex = i; break end end
local function refreshHeartSizeBtn()
    local pct = math.floor(SETTINGS.HeartScale / 0.65 * 100 + 0.5)
    heartSizeBtn.Text = "💗 Размер сердца: " .. pct .. "%"
end
refreshHeartSizeBtn()
onClick(heartSizeBtn, function()
    heartScaleIndex = heartScaleIndex + 1
    if heartScaleIndex > #HEART_STEPS then heartScaleIndex = 1 end
    SETTINGS.HeartScale = HEART_STEPS[heartScaleIndex]
    refreshHeartSizeBtn(); ORBIT.rebuildAllRings()
end)

-- ============================================================
--       ОБЩЕЕ ОБНОВЛЕНИЕ ПОДПИСЕЙ
-- ============================================================
local function onOff(v) return v and "ВКЛ" or "ВЫКЛ" end

local function refreshAllLabels()
    pcall(function() if UIK.modeBtn and UIK.modeLabel then UIK.modeBtn.Text = UIK.modeLabel() end end)
    if ORBIT.enabled then
        toggleBtn.Text = "🟢 ВКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(0,255,120); toggleBtn.BackgroundColor3 = Color3.fromRGB(40,50,40)
    else
        toggleBtn.Text = "🔴 ВЫКЛЮЧЕНО"; toggleBtn.TextColor3 = Color3.fromRGB(255,80,80); toggleBtn.BackgroundColor3 = Color3.fromRGB(50,35,40)
    end
    local allOn = true
    for ri = 2, 5 do refreshRingButton(ri); if not rings[ri].enabled then allOn = false end end
    allRingsBtn.Text = allOn and "⭕ Все кольца: ВЫКЛ" or "⭕ Все кольца: ВКЛ"
    botAutoCollectBtn.Text = "🎁 Автосбор: " .. onOff(ORBIT.botSettings.AutoCollect)
    botRadiusBtn.Text = "📏 Радиус сбора: " .. ORBIT.botSettings.CollectRadius .. " st"
    botShowPlayerRing.Text = "👤 Кольцо как у игрока: " .. onOff(ORBIT.botSettings.ShowPlayerRing)
    botSkinBtnEnd.Text = "🎭 Скин как у меня: " .. onOff(ORBIT.botSettings.UseMySkin)
    espBtn.Text = "👁️ ESP игроков: " .. onOff(ORBIT.ESP and ORBIT.ESP.Enabled)
    shapeCatBtn.Text = "📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name
    shapeBtn.Text = "🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name
    shapeModeBtn.Text = "🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name
    shapeSizeBtn.Text = "🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name
    colorBtn.Text = "🎨 Цвет: " .. P.COLORS[P.colorIndex].name
    gradientBtn.Text = "🌈 Градиент: " .. onOff(SETTINGS.GradientEnabled)
    lightBtn.Text = "💡 Свет: " .. onOff(SETTINGS.LightEnabled)
    nameBtn.Text = "🏷️ Имена блоков: " .. onOff(SETTINGS.ShowBlockNames)
    autoSwapBtn.Text = "🎭 Автосмена: " .. onOff(SETTINGS.AutoShapeSwap)
    orbitBtn.Text = "📏 Орбита: " .. P.ORBIT[P.orbitIndex].name
    spreadBtn.Text = "📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name
    heightBtn.Text = "⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name
    speedBtn.Text = "⚡ Множитель: " .. P.SPEED[P.speedIndex].name
    speedModeBtn.Text = "⚙️ Режим: " .. P.SPEED_MODE[P.speedModeIndex].name
    directionBtn.Text = "🔃 Направление: " .. P.DIRECTION[P.directionIndex].name
    orbitPatternBtn.Text = "🌀 Узор: " .. tostring(SETTINGS.OrbitPattern)
    spinBtn.Text = ORBIT.spinResetting and "↩️ Вращение: ВОЗВРАТ" or "↩️ Вращение в 0"
    spinAxisBtn.Text = "🔄 Кручение оси: " .. onOff(ORBIT.spinAxisEnabled)
    spinDirBtn.Text = (ORBIT.spinAxisDir == "X") and "↕️ Ось: ВЕРХ/ВНИЗ" or "↔️ Ось: ВЛЕВО/ВПРАВО"
    spinSpeedBtn.Text = "🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name
    trailBtn.Text = "🌠 Трейлы: " .. onOff(SETTINGS.TrailEnabled)
    trailLenBtn.Text = "📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name
    trailWidBtn.Text = "🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name
    waveBtn.Text = "🌊 Волна: " .. onOff(SETTINGS.WaveEnabled)
    explosionBtn.Text = "💥 Взрыв: " .. onOff(SETTINGS.ExplosionEnabled)
    pulseBtn.Text = "💓 Пульсация: " .. onOff(SETTINGS.PulseEnabled)
    NB.spawnAnim.Text = "🎆 Появление колец: " .. onOff(SETTINGS.SpawnAnim ~= false)
    NB.spawnFlash.Text = "💫 Вспышка при вкл: " .. onOff(SETTINGS.SpawnFlash ~= false)
    auraBtn.Text = "🌀 Аура: " .. onOff(SETTINGS.AuraEnabled)
    auraRingBtn.Text = "⭕ Кольцо: " .. onOff(SETTINGS.AuraRing)
    auraPartBtn.Text = "✨ Частицы: " .. onOff(SETTINGS.AuraParticles)
    auraFigBtn.Text = "🔷 Фигуры: " .. onOff(SETTINGS.AuraShapes)
    auraShapeBtn.Text = "🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name
    auraColorBtn.Text = "🎨 Цвет ауры: " .. P.COLORS[P.auraColorIndex].name
    NB.auraMatBtn.Text = "🧱 Материал ауры: " .. string.upper((tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "")))
    if NB.refreshAuraFx then NB.refreshAuraFx() end
    auraSizeBtn.Text = "📐 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name
    auraThickBtn.Text = "🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name
    auraHeightBtn.Text = "⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name
    auraShapeScaleBtn.Text = "🔍 Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name
    auraPatternBtn.Text = "🌀 Узор ауры: " .. tostring(SETTINGS.AuraPattern)
    auraSpeedBtn.Text = "⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name
    auraDirBtn.Text = "🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name
    auraTrailBtn.Text = "🌠 Трейлы ауры: " .. onOff(SETTINGS.AuraTrailEnabled)
    auraTrailLenBtn.Text = "📏 Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name
    auraTrailWidBtn.Text = "🎚️ Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name
    auraSpinBtn.Text = "🔄 Кручение: " .. onOff(SETTINGS.AuraSpinEnabled)
    auraSpinAxisBtn.Text = "↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name
    auraSpinSpeedBtn.Text = "🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name
    auraPulseBtn.Text = "💓 Пульсация ауры: " .. onOff(SETTINGS.AuraPulseEnabled)
    auraLightBtn.Text = "💡 Свет ауры: " .. onOff(SETTINGS.AuraLightEnabled)
    auraLightRangeBtn.Text = "📏 Дальность: " .. tostring(SETTINGS.AuraLightRange)
    auraLightBrightBtn.Text = "✨ Яркость: " .. tostring(SETTINGS.AuraLightBrightness)
    local mname = (tostring(SETTINGS.Material):gsub("Enum%.Material%.", ""))
    for i, m in ipairs(MATERIALS) do if m == mname then materialIndex = i; break end end
    materialBtn.Text = "🎨 Материал: " .. mname:upper()
    transparencyBtn.Text = "👁️ Прозрачность: " .. math.floor(SETTINGS.Transparency * 100 + 0.5) .. "%"
    brightnessBtn.Text = "☀️ Яркость: " .. tostring(SETTINGS.GlowIntensity or 1)
    glowBtn.Text = "✨ Свечение: " .. onOff(SETTINGS.GlowEnabled ~= false)
    castShadowBtn.Text = "🌑 Тени: " .. onOff(SETTINGS.CastShadow)
    fireBtn.Text = "🔥 Огонь: " .. onOff(SETTINGS.FireEnabled)
    fireSizeBtn.Text = "📏 Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name
    fireHeatBtn.Text = "🌡️ Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name
    if ORBIT.SOUNDS then
        soundToggleBtn.Text = "🔊 Звуки: " .. onOff(ORBIT.SOUNDS.Enabled)
        soundVolumeBtn.Text = "🎵 Громкость: " .. math.floor((ORBIT.SOUNDS.Volume or 1) * 100 + 0.5) .. "%"
        soundVolumeIndex = math.clamp(math.floor((ORBIT.SOUNDS.Volume or 1) * 10 + 0.5) + 1, 1, #VOLUME_STEPS)
    end
    musicBtn.Text = "🎵 Музыка: " .. onOff(ORBIT.musicEnabled)
    for i, v in ipairs(HEART_STEPS) do if math.abs(v - SETTINGS.HeartScale) < 0.01 then heartScaleIndex = i; break end end
    refreshHeartSizeBtn()
    NB.fpsToggle.Text = "📊 FPS-панель: " .. onOff(topBar.Visible)
    pcall(refreshPerfBtn)
end

-- ============================================================
--       ПАЛИТРА (50 цветов)
-- ============================================================
local paletteGui = nil
local function closePalette()
    if paletteGui then paletteGui:Destroy(); paletteGui = nil end
end
local function openPalette(titleText, getIdx, onPick)
    closePalette()
    local abs = screenGui.AbsoluteSize
    local w = math.min(340, abs.X - 16)
    local h = math.min(380, abs.Y - 16)
    local f = Instance.new("Frame")
    f.Name = "_OrbitPalette"
    f.AnchorPoint = Vector2.new(0.5, 0.5); f.Position = UDim2.new(0.5, 0, 0.5, 0)
    f.Size = UDim2.new(0, w, 0, h)
    f.BackgroundColor3 = Color3.fromRGB(22, 18, 38); f.BorderSizePixel = 0; f.ZIndex = 60
    f.Parent = screenGui
    paletteGui = f
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
    onClick(cl, closePalette)
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
            task.delay(0.25, closePalette)
        end)
    end
end

onClick(colorBtn, function()
    openPalette("🎨 Цвет колец", function() return P.colorIndex end, function(i)
        P.colorIndex = i
        ORBIT.applyColor()
        colorBtn.Text = "🎨 Цвет: " .. P.COLORS[i].name
    end)
end)
onClick(auraColorBtn, function()
    openPalette("🎨 Цвет ауры", function() return P.auraColorIndex end, function(i)
        P.auraColorIndex = i
        local ac = P.COLORS[i]
        if ac.c then SETTINGS.AuraColor = ac.c end
        auraColorBtn.Text = "🎨 Цвет ауры: " .. ac.name
        refreshAura()
    end)
end)

-- ============================================================
--       СТИЛИ
-- ============================================================
local function idxByName(list, name)
    for i, v in ipairs(list) do if v.name == name then return i end end
    return nil
end
local function idxByValue(list, key, val)
    local best, bd = nil, math.huge
    for i, v in ipairs(list) do
        local d = math.abs((v[key] or 0) - val)
        if d < bd then best, bd = i, d end
    end
    return best
end
local function pickRandom(t) return t[math.random(1, #t)] end

local function makeRandomStyle()
    local pats, shapeNames = {}, {}
    for _, p in ipairs(P.ORBIT_PATTERNS) do pats[#pats + 1] = p.name end
    for _, s in ipairs(SHAPE_PRESETS) do shapeNames[#shapeNames + 1] = s.name end
    local colorName = (math.random() < 0.4) and "РАДУГА" or P.COLORS[math.random(2, #P.COLORS)].name
    local ringsOn = {true, false, false, false, false}
    for ri = 2, math.random(1, 3) do ringsOn[ri] = true end
    local mats = {"Neon", "Neon", "Glass", "Metal", "SmoothPlastic", "ForceField"}
    local st = {
        name = "случайный", color = colorName, pattern = pickRandom(pats), speed = pickRandom({1.0, 1.5, 2.0}),
        orbit = pickRandom({"M", "L"}), size = "M", shape = pickRandom(shapeNames), rings = ringsOn,
        material = pickRandom(mats), trail = math.random() < 0.5, pulse = math.random() < 0.3,
        aura = math.random() < 0.4, fire = math.random() < 0.2,
    }
    st.auraColor = colorName
    return st
end

local function applyStyle(st)
    if st.random then st = makeRandomStyle() end
    local ci = idxByName(P.COLORS, st.color); if ci then P.colorIndex = ci end
    local pi = idxByName(P.ORBIT_PATTERNS, st.pattern)
    if pi then P.orbitPatternIndex = pi; SETTINGS.OrbitPattern = P.ORBIT_PATTERNS[pi].name end
    local sp = idxByValue(P.SPEED, "value", st.speed or 1.0)
    if sp then P.speedIndex = sp; SETTINGS.SpeedMultiplier = P.SPEED[sp].value end
    local oi = idxByName(P.ORBIT, st.orbit or "M"); if oi then P.orbitIndex = oi end
    local zi = idxByName(P.SHAPE_SIZE, st.size or "M"); if zi then P.shapeSizeIndex = zi end
    P.shapeCategoryIndex = 1; P.formModeIndex = 1
    for i, s in ipairs(SHAPE_PRESETS) do if s.name == st.shape then ORBIT.shapeIndex = i; break end end
    ORBIT.applyShapes()
    SETTINGS.Material = Enum.Material[st.material or "Neon"] or Enum.Material.Neon
    SETTINGS.Transparency = st.transparency or 0.1
    SETTINGS.TrailEnabled = st.trail == true
    SETTINGS.PulseEnabled = st.pulse == true
    SETTINGS.LightEnabled = true
    SETTINGS.GradientEnabled = false
    for ri = 1, 5 do
        local want = (ri == 1) or (st.rings and st.rings[ri] == true)
        if want and not rings[ri].enabled then rings[ri].enabled = true
        elseif not want and rings[ri].enabled then ORBIT.setRingEnabled(ri, false) end
    end
    SETTINGS.AuraEnabled = st.aura == true
    if st.aura then
        local ai = idxByName(P.COLORS, st.auraColor or st.color)
        if ai then
            P.auraColorIndex = ai
            if P.COLORS[ai].c then SETTINGS.AuraColor = P.COLORS[ai].c end
        end
        if not (SETTINGS.AuraRing or SETTINGS.AuraParticles or SETTINGS.AuraShapes) then
            SETTINGS.AuraRing = true; SETTINGS.AuraParticles = true; SETTINGS.AuraShapes = true
        end
    end
    SETTINGS.FireEnabled = st.fire == true
    -- v23.6: материал ауры и атмосфера (для стихий)
    SETTINGS.AuraMaterial = Enum.Material[st.auraMaterial or "Neon"] or Enum.Material.Neon
    pcall(function() NB.auraMatBtn.Text = "🧱 Материал ауры: " .. string.upper(tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "")) end)
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
    refreshAllLabels()
    ORBIT.notify("🎭 Стиль: " .. tostring(st.name), Color3.fromRGB(220, 200, 255), 2)
end
for i, b in ipairs(NB.styleBtns) do
    onClick(b, function() applyStyle(NB.styleDefs[i]) end)
end
for i, b in ipairs(NB.elementBtns) do
    onClick(b, function() applyStyle(NB.elementDefs[i]) end)
end
do
    local amIdx = 1
    for i, m in ipairs(NB.AURA_MATERIALS) do
        if m == tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "") then amIdx = i; break end
    end
    onClick(NB.auraMatBtn, function()
        amIdx = amIdx % #NB.AURA_MATERIALS + 1
        local mName = NB.AURA_MATERIALS[amIdx]
        SETTINGS.AuraMaterial = Enum.Material[mName] or Enum.Material.Neon
        NB.auraMatBtn.Text = "🧱 Материал ауры: " .. string.upper(mName)
        ORBIT.setupAura()
    end)
    NB.auraMatBtn.Text = "🧱 Материал ауры: " .. string.upper((tostring(SETTINGS.AuraMaterial):gsub("Enum%.Material%.", "")))
end

-- v23.7 (A2): стиль частиц и свечение ауры
NB.AURA_GLOW_STEPS = {0, 0.5, 1, 2}
NB.refreshAuraFx = function()
    local st = ORBIT.AURA_PARTICLE_STYLES and ORBIT.AURA_PARTICLE_STYLES[SETTINGS.AuraParticleStyle or 1]
    NB.auraPartStyleBtn.Text = "✨ Частицы ауры: " .. (st and st.name or "ИСКРЫ")
    local g = SETTINGS.AuraGlow
    if g == nil then g = 1 end
    NB.auraGlowBtn.Text = "💡 Свечение ауры: " .. (g <= 0 and "ВЫКЛ" or ("×" .. tostring(g)))
end
onClick(NB.auraPartStyleBtn, function()
    local n = ORBIT.AURA_PARTICLE_STYLES and #ORBIT.AURA_PARTICLE_STYLES or 3
    SETTINGS.AuraParticleStyle = ((SETTINGS.AuraParticleStyle or 1) % n) + 1
    NB.refreshAuraFx()
    ORBIT.setupAura()
end)
onClick(NB.auraGlowBtn, function()
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

onClick(NB.spawnAnim, function()
    SETTINGS.SpawnAnim = not (SETTINGS.SpawnAnim ~= false)
    NB.spawnAnim.Text = "🎆 Появление колец: " .. onOff(SETTINGS.SpawnAnim)
end)
onClick(NB.spawnFlash, function()
    SETTINGS.SpawnFlash = not (SETTINGS.SpawnFlash ~= false)
    NB.spawnFlash.Text = "💫 Вспышка при вкл: " .. onOff(SETTINGS.SpawnFlash)
end)
onClick(NB.fpsToggle, function()
    topBar.Visible = not topBar.Visible
    NB.fpsToggle.Text = "📊 FPS-панель: " .. onOff(topBar.Visible)
end)

-- СОХРАНЕНИЯ
local function rebuildSavesList()
    for _, child in ipairs(savesContainer:GetChildren()) do
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
        empty.Parent = savesContainer
        return
    end
    for i, name in ipairs(names) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = savesContainer
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
                refreshAllLabels()
            end
        end)
        onClick(delB, function()
            if ORBIT.deleteNamed(name) then
                ORBIT.notify("🗑 Удалено: " .. name, Color3.fromRGB(255,150,150))
                rebuildSavesList()
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
            shareInputBox.Text = str
            ORBIT.share.copy(str)
            ORBIT.notify("📤 Строка «" .. name .. "» готова", Color3.fromRGB(180,220,255), 3)
            setTab("sys")
        end)
    end
end

onClick(createSaveBtn, function()
    local name = saveNameInput.Text
    if not name or name == "" then name = "Авто-" .. tostring(#ORBIT.getSaveNames() + 1) end
    local ok, err = pcall(function() return ORBIT.saveNamed(name) end)
    if ok and err ~= false then
        ORBIT.notify("💾 Сохранено: " .. name, Color3.fromRGB(160,255,180))
        saveNameInput.Text = ""; rebuildSavesList()
    else
        ORBIT.notify("❌ " .. tostring(err), Color3.fromRGB(255,100,100))
    end
end)

onClick(importSaveBtn, function()
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
    shareInputBox.Text = txt
    ORBIT.notify("📋 Вставлено в поле SHARE — нажми ЗАГРУЗИТЬ", Color3.fromRGB(180,220,255), 3)
    setTab("sys")
end)

onClick(saveBtn, function()
    if musicInput.Text ~= "" then ORBIT.setMusicId(musicInput.Text) end
    if ORBIT.saveSettings() then
        saveBtn.Text = "✅ Сохранено!"; task.wait(1.5); saveBtn.Text = "💾 Сохранить в автослот"
    end
end)
onClick(loadBtn, function()
    if ORBIT.loadSettings() then
        ORBIT.notify("📂 Загружено", Color3.fromRGB(180,220,255))
        ORBIT.rebuildAllRings()
        if ORBIT.setupAura then ORBIT.setupAura() end
        if ORBIT.setupFire then ORBIT.setupFire() end
        refreshAllLabels()
    end
end)
onClick(resetBtn, function()
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
    ORBIT.applyColor()
    ORBIT.rebuildAllRings()
    if ORBIT.setupAura then ORBIT.setupAura() end
    if ORBIT.setupFire then ORBIT.setupFire() end
    refreshAllLabels()
    ORBIT.notify("🔄 Сброс выполнен", Color3.fromRGB(255,180,180))
end)
onClick(unloadBtn, function() pcall(function() ORBIT.unload() end) end)

onClick(applyIdBtn, function()
    local ok = ORBIT.setMusicId(musicInput.Text)
    if ok then
        applyIdBtn.Text = "✅ Готово!"; task.wait(1.2); applyIdBtn.Text = "✅ Применить ID"
    else
        applyIdBtn.Text = "❌ Ошибка"; task.wait(1.5); applyIdBtn.Text = "✅ Применить ID"
    end
end)
onClick(musicBtn, function()
    local s = ORBIT.musicSound and tostring(ORBIT.musicSound.SoundId or "") or ""
    if not ORBIT.musicSound or s == "" or s == "rbxassetid://" then
        musicBtn.Text = "❌ Вставь ID!"; task.wait(1.2)
        musicBtn.Text = "🎵 Музыка: " .. (ORBIT.musicEnabled and "ВКЛ" or "ВЫКЛ")
        return
    end
    ORBIT.musicEnabled = not ORBIT.musicEnabled
    if ORBIT.musicEnabled then ORBIT.musicSound:Play(); musicBtn.Text = "🎵 Музыка: ВКЛ"
    else ORBIT.musicSound:Stop(); musicBtn.Text = "🎵 Музыка: ВЫКЛ" end
end)

rebuildSavesList()

-- ============================================================
--       FPS СЧЁТЧИК
-- ============================================================
task.spawn(function()
    while screenGui and screenGui.Parent do
        task.wait(0.5)
        local fps = myFps or 0
        local bots = 0; for _ in pairs(ORBIT.bots or {}) do bots = bots + 1 end
        local ringsOn = 0; for ri = 1, 5 do if rings[ri].enabled then ringsOn = ringsOn + 1 end end
        local icon = "💻"
        if ORBIT.PLATFORM == "mobile" then icon = "📱" end
        topBarLabel.Text = string.format("%s ОРБИТА %s  |  FPS: %d  |  🤖 %d  |  ⭕ %d/5",
            icon, tostring(ORBIT.version), fps, bots, ringsOn)
        if fps >= 50 then topBarLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
        elseif fps >= 30 then topBarLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
        else topBarLabel.TextColor3 = Color3.fromRGB(255, 140, 140) end
    end
end)

task.spawn(function() while screenGui and screenGui.Parent do task.wait(1); pcall(refreshPerfBtn) end end)

-- ============================================================
--       ПЕРЕТАСКИВАНИЕ
-- ============================================================
local dragging, dragStart, startPos = false, nil, nil

mainBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        startPos = mainBtn.Position
    end
end)

UIK.connect(UIS.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        if d.Magnitude > 6 then dragMoved = true end
        if dragMoved then
            local abs = screenGui.AbsoluteSize
            mainBtn.Position = UDim2.fromOffset(
                math.clamp(startPos.X.Offset + d.X, 0, math.max(0, abs.X - 56)),
                math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, abs.Y - 56))
            )
        end
    end
end)

UIK.connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.Touch
       or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
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
ORBIT.ui.openShopBtn = openShopBtn
ORBIT.ui.openEditorBtn = openEditorBtn

ORBIT.ui.applyStyleByName = function(name)
    if not name then return false end
    for _, st in ipairs(NB.styleDefs) do
        if st.name == name then
            applyStyle(st)
            return true
        end
    end
    for _, st in ipairs(NB.elementDefs or {}) do
        if st.name == name then
            applyStyle(st)
            return true
        end
    end
    return false
end

-- v23.8 (Y5): экспорты для помощника — подписи стиля частиц / свечения и свечение колец
ORBIT.ui.refreshAuraFx = function()
    if NB.refreshAuraFx then NB.refreshAuraFx() end
end
ORBIT.ui.setGlow = function(on)
    on = on and true or false
    SETTINGS.GlowEnabled = on
    glowBtn.Text = "✨ Свечение: " .. (on and "ВКЛ" or "ВЫКЛ")
    if on then
        glowBtn.BackgroundColor3 = Color3.fromRGB(35,60,50); glowBtn.TextColor3 = Color3.fromRGB(180,255,220)
    else
        glowBtn.BackgroundColor3 = Color3.fromRGB(45,45,65); glowBtn.TextColor3 = Color3.fromRGB(200,200,220)
    end
    for _, ring in pairs(rings) do
        for _, d in ipairs(ring.blocks) do
            if d.light then d.light.Enabled = on end
        end
    end
end

ORBIT.ui.open = function() setPanel(true) end
ORBIT.ui.close = function() setPanel(false) end
ORBIT.ui.toggle = function() setPanel(not panelOpen) end

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

ORBIT.start = function()
    local genv = rawget(_G, "getgenv") and getgenv() or _G
    if genv._OrbitLoaderGui then pcall(function() genv._OrbitLoaderGui:Destroy() end) end
    ORBIT.startLogic()
    pcall(refreshAllLabels)
    ORBIT.notify("✨ ОРБИТА " .. tostring(ORBIT.version) .. " запущена!", Color3.fromRGB(200,200,255), 3)
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ P4 v24.0 (+ Гастер, режимы)", Color3.fromRGB(180,255,180), 3) end

-- ПОДГРУЗКА МАГАЗИНА И МИНИ-ИГРЫ
do
    local BASE = "https://raw.githubusercontent.com/y7hdyvdmr/my-orbit-script/refs/heads/main/"
    local function fetchRun(file, key, tries)
        for attempt = 1, tries do
            local ok, body = pcall(function() return game:HttpGet(BASE .. file .. "?t=" .. os.time() .. "&a=" .. attempt) end)
            if ok and type(body) == "string" and #body > 100 then
                local fn, err = loadstring(body)
                if fn then
                    local rok, rerr = pcall(fn)
                    if rok then ORBIT.loaded[key] = true; return true end
                    warn("[Orbit] " .. file .. " runtime: " .. tostring(rerr))
                else
                    warn("[Orbit] " .. file .. " compile: " .. tostring(err))
                end
            end
            task.wait(0.6)
        end
        if ORBIT.notify then ORBIT.notify("⚠️ Не загрузился " .. file, Color3.fromRGB(255,200,120), 3) end
        return false
    end
    local ext = (rawget(_G, "getgenv") and getgenv() or _G)._OrbitV24Loader
    if not ext then -- v24-загрузчик грузит shop/minigame сам (шаги 11 и 13)
        task.spawn(function() fetchRun("orbit_p4_shop.lua", "shop", 3) end)
        task.spawn(function() task.wait(0.5); fetchRun("orbit_minigame.lua", "minigame", 3) end)
    end
end

return true
