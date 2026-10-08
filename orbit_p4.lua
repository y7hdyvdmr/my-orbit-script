-- ORBIT v24.0 | orbit_p4.lua  (ЧАСТЬ 1/2 — UI + все кнопки; вторая половина в orbit_p4b.lua)
-- v24.0: разбит на два файла, чтобы не превышать лимит 200 locals.
--        Все GUI-элементы лежат в NB.btn.* / NB.lbl.* / NB.input.* / NB.scroll.*
--        В конце экспортируем ORBIT.P4 = {...} для orbit_p4b.lua.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P4] Часть 1 не загружена!"); return end
if ORBIT.P4 and ORBIT.P4.ready then warn("[Orbit P4] уже загружен"); return end

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

local NB = {}          -- общее хранилище (не тратит locals)
NB.btn = {}            -- все кнопки
NB.lbl = {}            -- все лейблы
NB.input = {}          -- все TextBox
NB.scroll = {}         -- все ScrollingFrame

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

-- ============================================================
--       FPS-СЧЁТЧИК
-- ============================================================
NB.myFps = 60
NB.myFpsFrames = 0
NB.myFpsLastCheck = tick()

task.spawn(function()
    while screenGui and screenGui.Parent do
        NB.myFpsFrames = NB.myFpsFrames + 1
        local now = tick()
        if now - NB.myFpsLastCheck >= 1 then
            NB.myFps = math.floor(NB.myFpsFrames / (now - NB.myFpsLastCheck))
            NB.myFpsFrames = 0
            NB.myFpsLastCheck = now
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
    local s = Instance.new("UIStroke", topBar)
    s.Color = Color3.fromRGB(120, 120, 255); s.Thickness = 1; s.Transparency = 0.4
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

NB.btn.topBarClose = Instance.new("TextButton")
NB.btn.topBarClose.Size = UDim2.new(0, 22, 0, 22)
NB.btn.topBarClose.Position = UDim2.new(1, -26, 0, 2)
NB.btn.topBarClose.BackgroundColor3 = Color3.fromRGB(60, 30, 40)
NB.btn.topBarClose.BackgroundTransparency = 0.3
NB.btn.topBarClose.TextColor3 = Color3.fromRGB(255, 140, 150)
NB.btn.topBarClose.Font = Enum.Font.GothamBold
NB.btn.topBarClose.TextSize = 13
NB.btn.topBarClose.Text = "✖"
NB.btn.topBarClose.AutoButtonColor = false
NB.btn.topBarClose.ZIndex = 7
NB.btn.topBarClose.Parent = topBar
Instance.new("UICorner", NB.btn.topBarClose).CornerRadius = UDim.new(0, 6)

onClick(NB.btn.topBarClose, function()
    topBar.Visible = false
    if NB.btn.fpsToggle then NB.btn.fpsToggle.Text = "📊 FPS-панель: ВЫКЛ" end
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
    local s = Instance.new("UIStroke", mainBtn)
    s.Color = Color3.fromRGB(120, 120, 255); s.Thickness = 1.5
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

makeBigSection("⚡  ОСНОВНОЕ", yCursor, Color3.fromRGB(60, 60, 100)); yCursor = yCursor + 30
NB.btn.toggle     = makeButton("🟢 ВКЛЮЧЕНО", yCursor, BTN_H_BIG, Color3.fromRGB(40,50,40), Color3.fromRGB(0,255,120)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.allRings   = makeButton("⭕ Все кольца: ВКЛ", yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.ring2      = makeButton("➕ Кольцо 2", yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.ring3      = makeButton("➕ Кольцо 3", yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.ring4      = makeButton("➕ Кольцо 4", yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.ring5      = makeButton("➕ Кольцо 5", yCursor); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ СТИЛИ ============
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

-- ============ СТИХИИ ============
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

-- ============ ЭМОЦИИ ============
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

-- ============ БОТЫ ============
makeBigSection("🤖  БОТЫ — ФАРМ КОЛЕЦ", yCursor, Color3.fromRGB(110, 70, 150)); yCursor = yCursor + 30
NB.btn.botNear      = makeButton("📍 Создать бота РЯДОМ", yCursor, BTN_H_BIG, Color3.fromRGB(45,80,65), Color3.fromRGB(170,255,200)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.botCreate5   = makeButton("🔥 Создать 5 ботов", yCursor, BTN_H, Color3.fromRGB(65,40,90), Color3.fromRGB(225,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.botCreate25  = makeButton("🌟 Создать 25 ботов", yCursor, BTN_H, Color3.fromRGB(85,45,110), Color3.fromRGB(235,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.botCreate100 = makeButton("👑 Создать 100 ботов", yCursor, BTN_H, Color3.fromRGB(105,55,130), Color3.fromRGB(245,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.botRemoveAll = makeButton("🗑 Удалить всех ботов", yCursor, BTN_H, Color3.fromRGB(80,30,30), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.botAutoCollect  = makeButton("🎁 Автосбор: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.botRadius       = makeButton("📏 Радиус сбора: 12 st", yCursor, BTN_H, Color3.fromRGB(35,50,65), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.botShowRing     = makeButton("👤 Кольцо как у игрока: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,45,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.botSkin         = makeButton("🎭 Скин как у меня: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,45,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP

NB.lbl.botInfo = Instance.new("TextLabel")
NB.lbl.botInfo.Size = UDim2.new(1, -20, 0, 22)
NB.lbl.botInfo.Position = UDim2.new(0, 10, 0, yCursor)
NB.lbl.botInfo.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
NB.lbl.botInfo.BackgroundTransparency = 0.3
NB.lbl.botInfo.BorderSizePixel = 0
NB.lbl.botInfo.Text = "🤖 Ботов: 0"
NB.lbl.botInfo.TextColor3 = Color3.fromRGB(210, 210, 255)
NB.lbl.botInfo.Font = Enum.Font.GothamBold
NB.lbl.botInfo.TextSize = 11
NB.lbl.botInfo.ZIndex = 2
NB.lbl.botInfo.Parent = panel
Instance.new("UICorner", NB.lbl.botInfo).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 26 + 6

-- ============ ESP ============
makeBigSection("👁️  ESP И МЕТКИ", yCursor, Color3.fromRGB(80, 60, 130)); yCursor = yCursor + 30
NB.btn.esp         = makeButton("👁️ ESP игроков: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.taggedCount = makeButton("⭐ Список читеров: 0", yCursor, BTN_H, Color3.fromRGB(70,40,60), Color3.fromRGB(255,180,220)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.tagNearest  = makeButton("🚩 Пометить ближайшего", yCursor, BTN_H, Color3.fromRGB(80,30,55), Color3.fromRGB(255,150,200)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.clearTags   = makeButton("🧹 Снять все метки", yCursor, BTN_H, Color3.fromRGB(50,35,45), Color3.fromRGB(255,180,200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ВНЕШНИЙ ВИД ============
makeBigSection("🎨  ВНЕШНИЙ ВИД КОЛЕЦ", yCursor, Color3.fromRGB(60, 100, 120)); yCursor = yCursor + 30
NB.btn.shapeCat    = makeButton("📁 Категория: " .. P.SHAPE_CATEGORIES[P.shapeCategoryIndex].name, yCursor, BTN_H, Color3.fromRGB(60,50,80), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.shape       = makeButton("🔷 Форма: " .. SHAPE_PRESETS[ORBIT.shapeIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.shapeMode   = makeButton("🎭 Режим: " .. P.FORM_MODES[P.formModeIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,65), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.shapeSize   = makeButton("🔍 Размер: " .. P.SHAPE_SIZE[P.shapeSizeIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.color       = makeButton("🎨 Цвет: " .. P.COLORS[P.colorIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.gradient    = makeButton("🌈 Градиент: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(255,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.light       = makeButton("💡 Свет: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,35), Color3.fromRGB(160,255,160)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.nameBtn     = makeButton("🏷️ Имена блоков: ВЫКЛ", yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.autoSwap    = makeButton("🎭 Автосмена: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ДВИЖЕНИЕ ============
makeBigSection("🛰️  ДВИЖЕНИЕ И ОРБИТА", yCursor, Color3.fromRGB(60, 100, 80)); yCursor = yCursor + 30
NB.btn.orbit        = makeButton("📏 Орбита: " .. P.ORBIT[P.orbitIndex].name, yCursor); yCursor = yCursor + BTN_H + S_STEP
NB.btn.spread       = makeButton("📐 Разлёт: " .. P.SPREAD[P.spreadIndex].name, yCursor, BTN_H, Color3.fromRGB(55,30,55), Color3.fromRGB(255,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.height       = makeButton("⬆️ Высота: " .. P.HEIGHT[P.heightIndex].name, yCursor, BTN_H, Color3.fromRGB(35,55,65), Color3.fromRGB(140,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.speed        = makeButton("⚡ Множитель: " .. P.SPEED[P.speedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.speedMode    = makeButton("⚙️ Режим: " .. P.SPEED_MODE[P.speedModeIndex].name, yCursor, BTN_H, Color3.fromRGB(45,50,65), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.direction    = makeButton("🔃 Направление: " .. P.DIRECTION[P.directionIndex].name, yCursor, BTN_H, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.orbitPattern = makeButton("🌀 Узор: " .. P.ORBIT_PATTERNS[P.orbitPatternIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,90), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ КРУЧЕНИЕ ============
makeBigSection("🔄  КРУЧЕНИЕ", yCursor, Color3.fromRGB(100, 60, 80)); yCursor = yCursor + 30
NB.btn.spin         = makeButton("↩️ Вращение в 0", yCursor, BTN_H, Color3.fromRGB(50,40,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.spinAxis     = makeButton("🔄 Кручение оси: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.spinDir      = makeButton("↕️ Ось: ВЕРХ/ВНИЗ", yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.spinSpeed    = makeButton("🌀 Скорость: " .. P.SPIN_SPEED[P.spinSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ ЭФФЕКТЫ ============
makeBigSection("✨  ЭФФЕКТЫ КОЛЕЦ", yCursor, Color3.fromRGB(100, 80, 60)); yCursor = yCursor + 30
NB.btn.trail        = makeButton("🌠 Трейлы: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.trailLen     = makeButton("📏 Длина: " .. P.TRAIL_LEN[P.trailLengthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.trailWid     = makeButton("🎚️ Толщина: " .. P.TRAIL_WID[P.trailWidthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.wave         = makeButton("🌊 Волна: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(30,55,75), Color3.fromRGB(140,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.explosion    = makeButton("💥 Взрыв: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(70,40,30), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.pulse        = makeButton("💓 Пульсация: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.spawnAnim    = makeButton("🎆 Появление колец: ВКЛ", yCursor, BTN_H, Color3.fromRGB(45,40,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.spawnFlash   = makeButton("💫 Вспышка при вкл: ВКЛ", yCursor, BTN_H, Color3.fromRGB(45,40,75), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ============ АУРА ============
makeBigSection("🌀  АУРА", yCursor, Color3.fromRGB(80, 60, 130)); yCursor = yCursor + 30
NB.btn.aura         = makeButton("🌀 Аура: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.auraRing     = makeButton("⭕ Кольцо: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,35), Color3.fromRGB(160,255,160)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraPart     = makeButton("✨ Частицы: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,55), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraFig      = makeButton("🔷 Фигуры: ВКЛ", yCursor, BTN_H, Color3.fromRGB(45,35,65), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP

NB.btn.auraShape    = makeButton("🔷 Форма ауры: " .. SHAPE_PRESETS[ORBIT.auraShapeIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraColor    = makeButton("🎨 Цвет ауры: " .. P.COLORS[P.auraColorIndex].name, yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.AURA_MATERIALS = {"Neon", "Glass", "ForceField", "Metal", "SmoothPlastic", "Ice", "Foil", "Marble"}
NB.btn.auraMat = makeButton("🧱 Материал ауры: NEON", yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraMat:SetAttribute("Search", "материал ауры стекло металл неон лёд")
NB.btn.auraPartStyle = makeButton("✨ Частицы ауры: ИСКРЫ", yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraPartStyle:SetAttribute("Search", "частицы ауры искры дым звезды стиль")
NB.btn.auraGlow = makeButton("💡 Свечение ауры: ×1", yCursor, BTN_H, Color3.fromRGB(60,40,80), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraGlow:SetAttribute("Search", "свечение ауры glow блеск")

NB.btn.auraSize     = makeButton("📐 Размер: " .. P.AURA_SIZE[P.auraSizeIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraThick    = makeButton("🎚️ Толщина: " .. P.AURA_THICK[P.auraThickIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraHeight   = makeButton("⬆️ Высота: " .. P.AURA_HEIGHT[P.auraHeightIndex].name, yCursor, BTN_H, Color3.fromRGB(50,40,70), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraShapeScale = makeButton("🔍 Масштаб фигур: " .. P.AURA_SHAPE_SCALE[P.auraShapeScaleIndex].name, yCursor, BTN_H, Color3.fromRGB(60,45,85), Color3.fromRGB(220,190,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraPattern  = makeButton("🌀 Узор ауры: " .. P.AURA_PATTERNS[P.auraPatternIndex].name, yCursor, BTN_H, Color3.fromRGB(65,45,95), Color3.fromRGB(230,190,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraSpeed    = makeButton("⚡ Скорость: " .. P.AURA_SPEED[P.auraSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,45,20), Color3.fromRGB(255,220,100)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraDir      = makeButton("🔃 Направление: " .. P.AURA_DIR[P.auraDirIndex].name, yCursor, BTN_H, Color3.fromRGB(45,35,60), Color3.fromRGB(200,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraTrail    = makeButton("🌠 Трейлы ауры: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraTrailLen = makeButton("📏 Длина трейла: " .. P.AURA_TRAIL_LEN[P.auraTrailLengthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraTrailWid = makeButton("🎚️ Толщина трейла: " .. P.AURA_TRAIL_WID[P.auraTrailWidthIndex].name, yCursor, BTN_H, Color3.fromRGB(35,45,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraSpin     = makeButton("🔄 Кручение: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,55,55), Color3.fromRGB(140,255,220)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraSpinAxis = makeButton("↕️ Ось: " .. P.AURA_SPIN_AXIS[P.auraSpinAxisIndex].name, yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraSpinSpeed= makeButton("🌀 Скорость кручения: " .. P.AURA_SPIN_SPEED[P.auraSpinSpeedIndex].name, yCursor, BTN_H, Color3.fromRGB(55,35,75), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraPulse    = makeButton("💓 Пульсация ауры: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(35,35,50)); yCursor = yCursor + BTN_H + S_STEP + 6

-- СВЕТ АУРЫ
makeBigSection("💡  СВЕТ АУРЫ", yCursor, Color3.fromRGB(140, 120, 60)); yCursor = yCursor + 30
NB.btn.auraLight        = makeButton("💡 Свет ауры: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(70,60,30), Color3.fromRGB(255,230,140)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.auraLightRange   = makeButton("📏 Дальность: 8", yCursor, BTN_H, Color3.fromRGB(60,50,25), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.auraLightBright  = makeButton("✨ Яркость: 2", yCursor, BTN_H, Color3.fromRGB(60,50,25), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ГРАФИКА
makeBigSection("🎨  ГРАФИКА И МАТЕРИАЛЫ", yCursor, Color3.fromRGB(60, 100, 130)); yCursor = yCursor + 30
NB.btn.material      = makeButton("🎨 Материал: NEON", yCursor, BTN_H_BIG, Color3.fromRGB(50,80,110), Color3.fromRGB(180,230,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.transparency  = makeButton("👁️ Прозрачность: 10%", yCursor, BTN_H, Color3.fromRGB(60,70,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.brightness    = makeButton("☀️ Яркость: 1", yCursor, BTN_H, Color3.fromRGB(70,60,30), Color3.fromRGB(255,220,140)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.glow          = makeButton("✨ Свечение: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,50), Color3.fromRGB(180,255,220)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.castShadow    = makeButton("🌑 Тени: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(45,45,65), Color3.fromRGB(200,200,220)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.quality       = makeButton("⚡ Качество графики: СРЕДНЕЕ", yCursor, BTN_H, Color3.fromRGB(60,45,90), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ОГОНЬ
makeBigSection("🔥  ОГОНЬ", yCursor, Color3.fromRGB(150, 60, 20)); yCursor = yCursor + 30
NB.btn.fire      = makeButton("🔥 Огонь: ВЫКЛ", yCursor, BTN_H_BIG, Color3.fromRGB(80,30,10), Color3.fromRGB(255,140,60)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.fireSize  = makeButton("📏 Размер: " .. P.FIRE_SIZE[P.fireSizeIndex].name, yCursor, BTN_H, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.fireHeat  = makeButton("🌡️ Жар: " .. P.FIRE_HEAT[P.fireHeatIndex].name, yCursor, BTN_H, Color3.fromRGB(60,30,15), Color3.fromRGB(255,180,120)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ЗАЩИТА
makeBigSection("🛡️  ЗАЩИТА", yCursor, Color3.fromRGB(60, 100, 60)); yCursor = yCursor + 30
NB.btn.antichitLaunch = makeButton("🛡️ Запустить АНТИ-ЧИТ", yCursor, BTN_H_BIG, Color3.fromRGB(45,80,50), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H_BIG + S_STEP

NB.lbl.antichitStatus = Instance.new("TextLabel")
NB.lbl.antichitStatus.Size = UDim2.new(1, -20, 0, 22)
NB.lbl.antichitStatus.Position = UDim2.new(0, 10, 0, yCursor)
NB.lbl.antichitStatus.BackgroundColor3 = Color3.fromRGB(25, 35, 25)
NB.lbl.antichitStatus.BackgroundTransparency = 0.3
NB.lbl.antichitStatus.BorderSizePixel = 0
NB.lbl.antichitStatus.Text = "🛡 Защита: не запущена"
NB.lbl.antichitStatus.TextColor3 = Color3.fromRGB(180, 220, 180)
NB.lbl.antichitStatus.Font = Enum.Font.GothamBold
NB.lbl.antichitStatus.TextSize = 11
NB.lbl.antichitStatus.ZIndex = 2
NB.lbl.antichitStatus.Parent = panel
Instance.new("UICorner", NB.lbl.antichitStatus).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 26 + 6

-- ЛЮДИ
makeBigSection("👥  ЛЮДИ И КОЛЬЦА (полное копирование)", yCursor, Color3.fromRGB(100, 50, 130)); yCursor = yCursor + 30
NB.btn.addAllRings    = makeButton("➕ Навесить ВСЁ всем игрокам", yCursor, BTN_H, Color3.fromRGB(40,70,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.remAllRings    = makeButton("➖ Убрать у всех", yCursor, BTN_H, Color3.fromRGB(70,40,40), Color3.fromRGB(255,160,160)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.toggleAllRings = makeButton("🔄 Переключить всем", yCursor, BTN_H, Color3.fromRGB(50,50,70), Color3.fromRGB(200,200,255)); yCursor = yCursor + BTN_H + S_STEP

NB.scroll.people = Instance.new("ScrollingFrame")
NB.scroll.people.Size = UDim2.new(1, -20, 0, 200)
NB.scroll.people.Position = UDim2.new(0, 10, 0, yCursor)
NB.scroll.people.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
NB.scroll.people.BackgroundTransparency = 0.2
NB.scroll.people.BorderSizePixel = 0
NB.scroll.people.CanvasSize = UDim2.new(0, 0, 0, 0)
NB.scroll.people.AutomaticCanvasSize = Enum.AutomaticSize.Y
NB.scroll.people.ScrollBarThickness = 3
NB.scroll.people.ScrollBarImageColor3 = Color3.fromRGB(180, 130, 255)
NB.scroll.people.ZIndex = 2
NB.scroll.people.Parent = panel
Instance.new("UICorner", NB.scroll.people).CornerRadius = UDim.new(0, 8)
do
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, 4)
    l.Parent = NB.scroll.people
end
yCursor = yCursor + 206

NB.btn.refreshPeople = makeButton("🔄 Обновить список игроков", yCursor, BTN_H, Color3.fromRGB(45,55,90), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ЗВУКИ
makeBigSection("🔊  ЗВУКИ", yCursor, Color3.fromRGB(70, 80, 110)); yCursor = yCursor + 30
NB.btn.soundToggle = makeButton("🔊 Звуки: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.soundVolume = makeButton("🎵 Громкость: 100%", yCursor, BTN_H, Color3.fromRGB(45,55,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.soundTest   = makeButton("🔍 Проверка звуков", yCursor, BTN_H_BIG, Color3.fromRGB(50,60,90), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H_BIG + S_STEP + 6

-- МАГАЗИН
makeBigSection("🛒  МАГАЗИН / РЕДАКТОР / ИГРА", yCursor, Color3.fromRGB(110, 60, 150)); yCursor = yCursor + 30
NB.btn.openShop    = makeButton("🛒 Открыть МАГАЗИН", yCursor, BTN_H_BIG, Color3.fromRGB(90,50,130), Color3.fromRGB(255,210,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.openEditor  = makeButton("🎨 Редактор 2D фигуры", yCursor, BTN_H, Color3.fromRGB(70,60,110), Color3.fromRGB(220,210,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.openGame    = makeButton("🎮 МИНИ-ИГРА «Ловля звёзд»", yCursor, BTN_H_BIG, Color3.fromRGB(130,80,180), Color3.fromRGB(255,230,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.openGaster   = makeButton("🎮 Собери Гастера", yCursor, BTN_H_BIG, Color3.fromRGB(70,40,120), Color3.fromRGB(230,210,255)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.gasterWeapon = makeButton("👁 Гастер-оружие", yCursor, BTN_H, Color3.fromRGB(60,35,100), Color3.fromRGB(220,200,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.mode         = makeButton("🎭 Режим: Санс", yCursor, BTN_H, Color3.fromRGB(50,50,80), Color3.fromRGB(200,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- ПРОИЗВОДИТЕЛЬНОСТЬ
makeBigSection("⚡  ПРОИЗВОДИТЕЛЬНОСТЬ", yCursor, Color3.fromRGB(60, 80, 110)); yCursor = yCursor + 30
NB.btn.perf = makeButton("⚡ Качество: АВТО", yCursor, BTN_H, Color3.fromRGB(35,50,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- СЕРДЦЕ
makeBigSection("💗  ДОПОЛНИТЕЛЬНО", yCursor, Color3.fromRGB(100, 50, 80)); yCursor = yCursor + 30
NB.btn.heartSize = makeButton("💗 Размер сердца: 100%", yCursor, BTN_H, Color3.fromRGB(70, 30, 55), Color3.fromRGB(255, 160, 200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- SHARE
makeBigSection("🔗  SHARE — ВСТАВЬ СТРОКУ И ЗАГРУЗИ", yCursor, Color3.fromRGB(90, 100, 160)); yCursor = yCursor + 30

NB.input.share = Instance.new("TextBox")
NB.input.share.Name = "ShareInput"
NB.input.share.Size = UDim2.new(1, -20, 0, 80)
NB.input.share.Position = UDim2.new(0, 10, 0, yCursor)
NB.input.share.BackgroundColor3 = Color3.fromRGB(15, 12, 24)
NB.input.share.TextColor3 = Color3.fromRGB(200, 220, 255)
NB.input.share.Font = Enum.Font.Code
NB.input.share.TextSize = 10
NB.input.share.Text = ""
NB.input.share.PlaceholderText = "Тут твоя строка для друга. Или вставь чужую и нажми ЗАГРУЗИТЬ"
NB.input.share.PlaceholderColor3 = Color3.fromRGB(120, 110, 160)
NB.input.share.TextWrapped = true
NB.input.share.TextXAlignment = Enum.TextXAlignment.Left
NB.input.share.TextYAlignment = Enum.TextYAlignment.Top
NB.input.share.ClearTextOnFocus = false
NB.input.share.MultiLine = true
NB.input.share.ZIndex = 2
NB.input.share.Parent = panel
Instance.new("UICorner", NB.input.share).CornerRadius = UDim.new(0, 8)
do
    local p = Instance.new("UIPadding", NB.input.share)
    p.PaddingLeft = UDim.new(0, 6); p.PaddingRight = UDim.new(0, 6)
    p.PaddingTop = UDim.new(0, 4); p.PaddingBottom = UDim.new(0, 4)
end
yCursor = yCursor + 86

NB.btn.shareLoad  = makeButton("📥 ЗАГРУЗИТЬ (вставил от друга)", yCursor, BTN_H_BIG, Color3.fromRGB(60, 120, 80), Color3.fromRGB(200, 255, 220)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.shareCopy  = makeButton("📋 ВЫДАТЬ МОИ НАСТРОЙКИ", yCursor, BTN_H, Color3.fromRGB(70, 90, 150), Color3.fromRGB(220, 235, 255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.sharePaste = makeButton("📋 Вставить из буфера в поле", yCursor, BTN_H, Color3.fromRGB(70, 90, 130), Color3.fromRGB(220, 235, 255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.shareClear = makeButton("🗑 Очистить поле", yCursor, BTN_H, Color3.fromRGB(80, 50, 60), Color3.fromRGB(255, 180, 200)); yCursor = yCursor + BTN_H + S_STEP + 6

-- СОХРАНЕНИЯ
makeBigSection("💾  СОХРАНЕНИЯ", yCursor, Color3.fromRGB(60, 60, 90)); yCursor = yCursor + 30
NB.input.saveName = Instance.new("TextBox")
NB.input.saveName.Size = UDim2.new(1, -20, 0, 32)
NB.input.saveName.Position = UDim2.new(0, 10, 0, yCursor)
NB.input.saveName.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
NB.input.saveName.BackgroundTransparency = 0.1
NB.input.saveName.TextColor3 = Color3.fromRGB(240, 230, 255)
NB.input.saveName.Font = Enum.Font.GothamBold
NB.input.saveName.TextSize = 12
NB.input.saveName.PlaceholderText = "Имя сохранения..."
NB.input.saveName.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
NB.input.saveName.Text = ""
NB.input.saveName.ClearTextOnFocus = false
NB.input.saveName.ZIndex = 2
NB.input.saveName.Parent = panel
Instance.new("UICorner", NB.input.saveName).CornerRadius = UDim.new(0, 8)
yCursor = yCursor + 36

NB.btn.createSave = makeButton("💾 СОЗДАТЬ СОХРАНЕНИЕ", yCursor, BTN_H_BIG, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H_BIG + S_STEP
NB.btn.importSave = makeButton("📥 ИМПОРТ СОХРАНЕНИЯ ИЗ БУФЕРА", yCursor, BTN_H, Color3.fromRGB(55, 75, 105), Color3.fromRGB(190, 220, 255)); yCursor = yCursor + BTN_H + S_STEP + 4

NB.scroll.saves = Instance.new("ScrollingFrame")
NB.scroll.saves.Size = UDim2.new(1, -20, 0, 130)
NB.scroll.saves.Position = UDim2.new(0, 10, 0, yCursor)
NB.scroll.saves.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
NB.scroll.saves.BackgroundTransparency = 0.2
NB.scroll.saves.BorderSizePixel = 0
NB.scroll.saves.CanvasSize = UDim2.new(0, 0, 0, 0)
NB.scroll.saves.AutomaticCanvasSize = Enum.AutomaticSize.Y
NB.scroll.saves.ScrollBarThickness = 3
NB.scroll.saves.ScrollBarImageColor3 = Color3.fromRGB(150,100,200)
NB.scroll.saves.ZIndex = 2
NB.scroll.saves.Parent = panel
Instance.new("UICorner", NB.scroll.saves).CornerRadius = UDim.new(0, 8)
do
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, 4)
    l.Parent = NB.scroll.saves
end
yCursor = yCursor + 136

-- СИСТЕМА
makeBigSection("💾  СИСТЕМА", yCursor, Color3.fromRGB(60, 60, 80)); yCursor = yCursor + 30
NB.btn.save    = makeButton("💾 Сохранить в автослот", yCursor, BTN_H, Color3.fromRGB(35,60,45), Color3.fromRGB(160,255,180)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.load    = makeButton("📂 Загрузить из автослота", yCursor, BTN_H, Color3.fromRGB(35,50,60), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.reset   = makeButton("🔄 Сбросить всё", yCursor, BTN_H, Color3.fromRGB(50,30,30), Color3.fromRGB(255,180,180)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.fpsToggle = makeButton("📊 FPS-панель: ВКЛ", yCursor, BTN_H, Color3.fromRGB(35,50,75), Color3.fromRGB(180,220,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.helper  = makeButton("🤖 Помощник (понимает фразы)", yCursor, BTN_H, Color3.fromRGB(70,60,130), Color3.fromRGB(220,210,255)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.unload  = makeButton("❌ ВЫГРУЗИТЬ СКРИПТ", yCursor, BTN_H_BIG, Color3.fromRGB(80,30,30), Color3.fromRGB(255,140,140)); yCursor = yCursor + BTN_H_BIG + S_STEP + 6

-- МУЗЫКА
makeBigSection("🎵  МУЗЫКА", yCursor, Color3.fromRGB(80, 60, 110)); yCursor = yCursor + 30
NB.input.music = Instance.new("TextBox")
NB.input.music.Size = UDim2.new(1, -20, 0, 32)
NB.input.music.Position = UDim2.new(0, 10, 0, yCursor)
NB.input.music.BackgroundColor3 = Color3.fromRGB(35, 30, 45)
NB.input.music.BackgroundTransparency = 0.1
NB.input.music.TextColor3 = Color3.fromRGB(240, 230, 255)
NB.input.music.Font = Enum.Font.GothamBold
NB.input.music.TextSize = 12
NB.input.music.PlaceholderText = "Sound ID"
NB.input.music.PlaceholderColor3 = Color3.fromRGB(140, 130, 170)
NB.input.music.Text = ""
NB.input.music.ClearTextOnFocus = false
NB.input.music.ZIndex = 2
NB.input.music.Parent = panel
Instance.new("UICorner", NB.input.music).CornerRadius = UDim.new(0, 8)
yCursor = yCursor + 36

NB.btn.applyId = makeButton("✅ Применить ID", yCursor, BTN_H, Color3.fromRGB(55,80,55), Color3.fromRGB(180,255,180)); yCursor = yCursor + BTN_H + S_STEP
NB.btn.music   = makeButton("🎵 Музыка: ВЫКЛ", yCursor, BTN_H, Color3.fromRGB(50,35,60), Color3.fromRGB(220,180,255)); yCursor = yCursor + BTN_H + S_STEP + 6

-- СТАТИСТИКА
makeBigSection("📈  СТАТИСТИКА СЕССИИ", yCursor, Color3.fromRGB(60, 60, 90)); yCursor = yCursor + 30
NB.lbl.stats = Instance.new("TextLabel")
NB.lbl.stats.Size = UDim2.new(1, -20, 0, 100)
NB.lbl.stats.Position = UDim2.new(0, 10, 0, yCursor)
NB.lbl.stats.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
NB.lbl.stats.BackgroundTransparency = 0.2
NB.lbl.stats.BorderSizePixel = 0
NB.lbl.stats.TextColor3 = Color3.fromRGB(180, 220, 180)
NB.lbl.stats.Font = Enum.Font.Gotham
NB.lbl.stats.TextSize = 11
NB.lbl.stats.TextXAlignment = Enum.TextXAlignment.Left
NB.lbl.stats.TextYAlignment = Enum.TextYAlignment.Top
NB.lbl.stats.Text = "FPS: --"
NB.lbl.stats.ZIndex = 2
NB.lbl.stats.Parent = panel
Instance.new("UICorner", NB.lbl.stats).CornerRadius = UDim.new(0, 6)
yCursor = yCursor + 106

NB.btn.resetSession = makeButton("🔄 Сбросить статистику", yCursor, BTN_H, Color3.fromRGB(50,40,40), Color3.fromRGB(255,180,180))
yCursor = yCursor + BTN_H + S_STEP + 6

UIK.finishBuild()
-- ============================================================
--       ЭКСПОРТ ДЛЯ orbit_p4b.lua
-- ============================================================
ORBIT.P4 = {
    ready = true,
    NB            = NB,
    onClick       = onClick,
    screenGui     = screenGui,
    window        = window,
    panel         = panel,
    shadow        = shadow,
    searchBox     = searchBox,
    panelCloseBtn = panelCloseBtn,
    mainBtn       = mainBtn,
    topBar        = topBar,
    topBarLabel   = topBarLabel,
    UIK           = UIK,
    TABS          = TABS,
    SECTION_TAB   = SECTION_TAB,
    relayout      = relayout,
    setTab        = setTab,
    makeButton    = makeButton,
    makeBigSection= makeBigSection,
    IS_MOBILE     = IS_MOBILE,
    PLATFORM      = PLATFORM,
    BTN_H         = BTN_H,
    BTN_H_BIG     = BTN_H_BIG,
    S_STEP        = S_STEP,
    PANEL_W       = PANEL_W,
    TweenService  = TweenService,
    UIS           = UIS,
    RunService    = RunService,
    Players       = Players,
    LocalPlayer   = LocalPlayer,
    P             = P,
    rings         = rings,
    SETTINGS      = SETTINGS,
    SHAPE_PRESETS = SHAPE_PRESETS,
    statsData     = statsData,
}

warn("[Orbit P4a] Часть 1 (UI + каркас) загружена. Ждём orbit_p4b.lua...")
return true
