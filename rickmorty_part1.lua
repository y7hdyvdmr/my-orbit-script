-- Rick & Morty Ultimate Multiverse v6.0 — один LocalScript.
-- Положи в StarterPlayer > StarterPlayerScripts как LocalScript. Всё работает локально (видишь только ты).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local CAS = game:GetService("ContextActionService")
local Stats = game:GetService("Stats")
local ScriptContext = game:GetService("ScriptContext")
local GuiService = game:GetService("GuiService")
local LP = Players.LocalPlayer
local V3, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local ANG = CFrame.Angles
local pi, rad, sin, cos, abs, floor, max, min, sqrt = math.pi, math.rad, math.sin, math.cos, math.abs, math.floor, math.max, math.min, math.sqrt
if _G.RM_V6 and _G.RM_V6.unload then pcall(_G.RM_V6.unload) end
local RM = { ver = "6.0.0", ticks = {}, rticks = {}, cleanups = {}, conns = {}, ents = {}, health = {}, errors = {}, dead = false }
_G.RM_V6 = RM
local CFG = {
energy = { max = 100, regen = 3, low = 25, crit = 10 },
cost = { portal = 8, coord = 12, time = 10, shield = 6, hyper = 25, scan = 3, echo = 10, holo = 6, npc = 4,
robot = 6, meeseeks = 8, drone = 5, zone = 10, dome = 18, shrink = 4, fire = 1.5, freeze = 12, gen = 0 },
drain = { jet = 7, ship = 3, drone = 3, shield = 2.2, dome = 2, robot = .25, holo = .6, zone = .8, grav = 1.5, arm = 1.5, helmet = .4 },
limit = { robots = 6, meeseeks = 4, drones = 1, echo = 4, holo = 4, npcs = 10, dummies = 6, zones = 3, domes = 1,
gens = 2, slots = 5, coords = 30, routes = 10, builds = 10, props = 18, log = 100 },
portal = { r = 6, life = 60, range = 400, cd = .8 },
ship = { vmin = 50, vmax = 1000, hyper = 300, hyperCd = 8, fireCd = .22 },
jet = { fuel = 100, burn = 28, regen = 18, speed = 70, fly = 55 },
drone = { range = 160, time = 90, speed = 60 },
shield = { time = 8, cd = 12, hp = 120 },
dome = { time = 30, hp = 300, r = 24 },
holo = { time = 120 },
scan = { r = 90, cd = 1.5 },
gravity = { maxMass = 400, hold = 2 },
freeze = { time = 4, r = 70 },
battery = { zone = 15, cost = 25 },
}
local DEF = {
sound = true, master = .8, sfx = .8, ui = .6, notif = true, notifTime = 2.5, menuKey = "RightShift",
portalColor = 1, aim = 64, dimfx = true, shipSpeed = 150, quality = "MEDIUM", uiScale = 1, mobScale = 1,
sens = 1, skin = "", emotion = "normal", dim = "C137", gravDist = 18, gravForce = 1, armLen = 26, radarR = 120,
hudShip = true, hostile = true,
}
local RANGE = {
master = { 0, 1 }, sfx = { 0, 1 }, ui = { 0, 1 }, notifTime = { .5, 10 }, aim = { 24, 200 }, shipSpeed = { 50, 1000 },
uiScale = { .6, 1.6 }, mobScale = { .7, 1.6 }, sens = { .3, 2.5 }, gravDist = { 6, 60 }, gravForce = { .2, 3 },
armLen = { 10, 60 }, radarR = { 40, 300 }, portalColor = { 1, 8 },
}
local function copy(t)
if type(t) ~= "table" then return t end
local o = {}
for k, v in pairs(t) do o[k] = copy(v) end
return o
end
local SAVE = {
v = 1, set = copy(DEF), animIds = {}, mobPos = {}, coords = {}, slots = {}, routes = {}, builds = {},
comps = {}, exp = {}, log = {}, unl = {},
}
local ST = SAVE.set
local function isnum(x) return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge end
local function clamp(x, a, b) return max(a, min(b, x)) end
local function lerp(a, b, t) return a + (b - a) * t end
local function cleanSetting(k, v)
local d = DEF[k]
if d == nil or type(v) ~= type(d) then return nil end
if type(v) == "number" then
if not isnum(v) then return nil end
local r = RANGE[k]
if r then v = clamp(v, r[1], r[2]) end
if k == "portalColor" then v = floor(v) end
elseif type(v) == "string" then
if #v > 40 then return nil end
if k == "quality" and v ~= "LOW" and v ~= "MEDIUM" and v ~= "HIGH" then return nil end
end
return v
end
local function str(s, n) return (tostring(s or ""):gsub("[%c]", " "):sub(1, n or 40)) end
local function cleanList(src, maxN, fn)
local out = {}
if type(src) ~= "table" then return out end
for _, e in ipairs(src) do
if #out >= maxN then break end
local c = type(e) == "table" and fn(e) or nil
if c then out[#out + 1] = c end
end
return out
end
local function v3t(t) -- {x,y,z}
if type(t) ~= "table" or not (isnum(t.x) and isnum(t.y) and isnum(t.z)) then return nil end
return { x = clamp(t.x, -1e5, 1e5), y = clamp(t.y, -1e5, 1e5), z = clamp(t.z, -1e5, 1e5) }
end
function RM.sanitize(d)
if type(d) ~= "table" then return nil end
local n = { v = 1, set = copy(DEF), animIds = {}, mobPos = {}, comps = {}, exp = {}, unl = {} }
if type(d.set) == "table" then
for k, v in pairs(d.set) do
local c = cleanSetting(k, v)
if c ~= nil then n.set[k] = c end
end
end
if type(d.animIds) == "table" then
for k, v in pairs(d.animIds) do
if type(k) == "string" and #k < 30 and type(v) == "string" and v:match("^%d+$") and #v < 20 then n.animIds[k] = v end
end
end
if type(d.mobPos) == "table" then
for k, v in pairs(d.mobPos) do
if type(k) == "string" and #k < 30 and type(v) == "table" and isnum(v[1]) and isnum(v[2]) then
n.mobPos[k] = { clamp(v[1], 0, 1), clamp(v[2], 0, 1) }
end
end
end
n.coords = cleanList(d.coords, CFG.limit.coords, function(e)
local p = v3t(e.p)
if not (p and type(e.name) == "string") then return nil end
return { name = str(e.name), p = p, ry = isnum(e.ry) and e.ry or 0, fav = e.fav == true }
end)
n.slots = cleanList(d.slots, CFG.limit.slots, function(e)
local p = v3t(e.p)
if not (p and type(e.name) == "string") then return nil end
return { name = str(e.name), p = p, ry = isnum(e.ry) and e.ry or 0, mode = str(e.mode, 12), size = isnum(e.size) and clamp(e.size, .1, 1) or 1 }
end)
n.routes = cleanList(d.routes, CFG.limit.routes, function(e)
if type(e.name) ~= "string" or type(e.pts) ~= "table" then return nil end
local pts = {}
for _, p in ipairs(e.pts) do
local c = v3t(p)
if c and #pts < 300 then pts[#pts + 1] = c end
end
if #pts < 2 then return nil end
return { name = str(e.name), pts = pts }
end)
n.builds = cleanList(d.builds, CFG.limit.builds, function(e)
if type(e.name) ~= "string" or type(e.comps) ~= "table" then return nil end
local cs = {}
for _, c in ipairs(e.comps) do
if type(c) == "string" and #c < 20 and #cs < 8 then cs[#cs + 1] = c end
end
return { name = str(e.name), comps = cs, kind = str(e.kind, 12) }
end)
if type(d.comps) == "table" then
for k, v in pairs(d.comps) do
if type(k) == "string" and #k < 20 and isnum(v) then n.comps[k] = clamp(floor(v), 0, 99) end
end
end
if type(d.exp) == "table" then
for k, v in pairs(d.exp) do
if type(k) == "string" and #k < 30 and type(v) == "table" then
n.exp[k] = { p = isnum(v.p) and clamp(v.p, 0, 1e7) or 0, done = v.done == true }
end
end
end
if type(d.unl) == "table" then
for k, v in pairs(d.unl) do
if type(k) == "string" and #k < 30 and v == true then n.unl[k] = true end
end
end
n.log = cleanList(d.log, CFG.limit.log, function(e)
if type(e.id) ~= "string" or #e.id > 30 then return nil end
return { id = e.id, name = str(e.name), t = isnum(e.t) and e.t or 0 }
end)
return n
end
function RM.export()
return HttpService:JSONEncode(SAVE)
end
function RM.import(text)
if type(text) ~= "string" or #text < 2 or #text > 200000 then return false, "пустой или слишком длинный код" end
local ok, d = pcall(function() return HttpService:JSONDecode(text) end)
if not ok then return false, "это не код сохранения" end
local n = RM.sanitize(d)
if not n then return false, "неверный формат" end
for k in pairs(SAVE) do SAVE[k] = nil end
for k, v in pairs(n) do SAVE[k] = v end
ST = SAVE.set
if RM.onImport then pcall(RM.onImport) end
return true
end
function RM.resetSettings()
for k in pairs(ST) do ST[k] = nil end
for k, v in pairs(DEF) do ST[k] = v end
SAVE.animIds, SAVE.mobPos = {}, {}
end
local function I(class: string, props: { [string]: any }?, parent: Instance?): any
local o: any = Instance.new(class :: any)
if props then
for k, v in pairs(props) do o[k] = v end
end
if parent then o.Parent = parent end
return o
end
local function tw(o, t, goal, style, dir)
local tween = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
tween:Play()
return tween
end
local function conn(c)
RM.conns[#RM.conns + 1] = c
return c
end
local function later(t, f)
task.delay(t, function()
if not RM.dead then f() end
end)
end
local function safe(name, f, ...)
local ok, e = pcall(f, ...)
if not ok then
RM.errors[#RM.errors + 1] = os.date("%H:%M:%S") .. " " .. tostring(name) .. ": " .. str(e, 160)
if #RM.errors > 40 then table.remove(RM.errors, 1) end
warn("[RM6] " .. tostring(name) .. ": " .. tostring(e))
end
return ok
end
local function getChar(): (any, any, any)
local c = LP.Character
local h = c and c:FindFirstChildOfClass("Humanoid")
local r = c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
return c, h, r
end
local function cam(): any return Workspace.CurrentCamera end
local function notify(text, color, dur)
if RM.toast then RM.toast(text, color, dur) else print("[RM6] " .. tostring(text)) end
end
local WORLD = I("Folder", { Name = "RM_Local" }, Workspace)
local function folder(name) return I("Folder", { Name = name }, WORLD) end
local FX = folder("Fx")
RM.cleanups[#RM.cleanups + 1] = function() WORLD:Destroy() end
local SFX = {
shoot = "rbxassetid://12221967", click = "rbxasset://sounds/button.wav",
notify = "rbxasset://sounds/electronicpingshort.wav", teleport = "rbxassetid://3314038600",
}
local SFXCAT = {
portal = { "teleport", 1.3, .5 }, tp = { "teleport", 1, .6 }, ship = { "shoot", .6, .5 }, engine = { "shoot", .4, .3 },
robot = { "click", .7, .6 }, gadget = { "click", .9, .6 }, energy = { "notify", .7, .5 }, shield = { "teleport", 1.7, .4 },
holo = { "notify", 1.4, .5 }, comp = { "notify", 1.1, .5 }, ui = { "click", 1.2, .4 }, notif = { "notify", 1, .5 },
exp = { "teleport", .8, .5 }, shoot = { "shoot", 1, .6 },
}
local GRP = I("SoundGroup", { Name = "RM_Master" }, SoundService)
local GSFX = I("SoundGroup", { Name = "RM_Sfx" }, GRP)
local GUI_ = I("SoundGroup", { Name = "RM_Ui" }, GRP)
RM.cleanups[#RM.cleanups + 1] = function() GRP:Destroy() end
function RM.applyVolume()
GRP.Volume = ST.sound and ST.master or 0
GSFX.Volume = ST.sfx
GUI_.Volume = ST.ui
end
RM.applyVolume()
local function snd(cat, vol, pitch)
if RM.dead or not ST.sound then return end
local c = SFXCAT[cat] or SFXCAT.ui
local id = SFX[c[1]]
if not id then return end
pcall(function()
local s = I("Sound", { SoundId = id, Volume = (vol or 1) * c[3], PlaybackSpeed = (pitch or 1) * c[2] })
s.SoundGroup = (cat == "ui" or cat == "notif") and GUI_ or GSFX
s.Parent = FX
s:Play()
task.delay(4, function() s:Destroy() end)
end)
end
local QP = {
LOW = { pr = .25, lights = false, rings = 8, fxdur = .5, hl = 6, hz = .2, trail = false, fx = false },
MEDIUM = { pr = .6, lights = true, rings = 14, fxdur = 1, hl = 14, hz = .1, trail = true, fx = true },
HIGH = { pr = 1, lights = true, rings = 20, fxdur = 1.4, hl = 30, hz = .05, trail = true, fx = true },
}
local function Q() return QP[ST.quality] or QP.MEDIUM end
RM.onQuality = {}
function RM.setQuality(name)
if not QP[name] then return end
ST.quality = name
for _, f in ipairs(RM.onQuality) do pcall(f, QP[name]) end
end
local MODE = { cur = "normal", who = nil }
local function enterMode(mode, who)
if MODE.cur ~= "normal" then return false, "сначала выйди из режима: " .. MODE.cur end
MODE.cur, MODE.who = mode, who
return true
end
local function leaveMode(who)
if MODE.who == who then MODE.cur, MODE.who = "normal", nil end
end
local EN = { v = CFG.energy.max, max = CFG.energy.max, drains = {}, bonus = {}, lowAt = 0, critAt = 0, shown = 0 }
function EN.use(cost, why)
cost = cost or 0
if EN.v >= cost then
EN.v = EN.v - cost
return true
end
notify("⚡ Не хватает энергии" .. (why and (": " .. why) or "") .. " (" .. floor(EN.v) .. "/" .. floor(cost) .. ")", RGB(255, 190, 70), 2)
return false
end
function EN.add(a) EN.v = clamp(EN.v + a, 0, EN.max) end
function EN.drain(key, rate, onEmpty) EN.drains[key] = { rate = rate, fn = onEmpty } end
function EN.stop(key) EN.drains[key] = nil end
function EN.total()
local d = 0
for _, e in pairs(EN.drains) do d = d + e.rate end
return d
end
function EN.regen()
local r = CFG.energy.regen
for _, b in pairs(EN.bonus) do r = r + b end
return r
end
function EN.tick(dt)
local net = EN.regen() - EN.total()
EN.v = clamp(EN.v + net * dt, 0, EN.max)
if EN.v <= 0 then
for k, e in pairs(EN.drains) do
EN.drains[k] = nil
if e.fn then safe("энергия:" .. k, e.fn) end
end
if os.clock() - EN.critAt > 12 then
EN.critAt = os.clock()
notify("🪫 Энергия закончилась: устройства отключены", RGB(255, 90, 90), 3)
snd("energy", 1, .6)
end
elseif EN.v < CFG.energy.crit and os.clock() - EN.critAt > 15 then
EN.critAt = os.clock()
notify("🔴 Критически низкий заряд", RGB(255, 90, 90), 2.5)
elseif EN.v < CFG.energy.low and os.clock() - EN.lowAt > 20 then
EN.lowAt = os.clock()
notify("🟡 Низкий заряд энергии", RGB(255, 210, 80), 2.5)
end
end
local function entList(kind)
local l = RM.ents[kind]
if not l then
l = {}
RM.ents[kind] = l
end
return l
end
local function entCount(kind) return #entList(kind) end
local function entAdd(kind, e)
local l = entList(kind)
l[#l + 1] = e
return e
end
local function entDel(kind, e)
local l = entList(kind)
for i = #l, 1, -1 do
if l[i] == e then table.remove(l, i) end
end
end
local function entClear(kind)
local l = entList(kind)
for i = #l, 1, -1 do
local e = l[i]
table.remove(l, i)
if e.destroy then safe("clear:" .. kind, e.destroy, e) end
end
end
local function canAdd(kind, limit)
if entCount(kind) >= limit then
notify("Лимит: не больше " .. limit .. " (" .. kind .. ")", RGB(255, 190, 70), 2)
return false
end
return true
end
local function dismiss(o: any) if o and o.Parent then o:Destroy() end end
local function ignoreList()
local l = { WORLD }
if LP.Character then l[#l + 1] = LP.Character end
return l
end
local function ray(origin, dir, ign, water)
local p = RaycastParams.new()
p.FilterType = Enum.RaycastFilterType.Exclude
p.FilterDescendantsInstances = ign or ignoreList()
p.IgnoreWater = not water
return Workspace:Raycast(origin, dir, p)
end
local function groundAt(pos, up)
local r = ray(pos + V3(0, up or 6, 0), V3(0, -(up or 6) - 400, 0))
return r and r.Position or nil
end
local function spaceFree(cf, size)
local p = OverlapParams.new()
p.FilterType = Enum.RaycastFilterType.Exclude
p.FilterDescendantsInstances = ignoreList()
for _, part in ipairs(Workspace:GetPartBoundsInBox(cf, size or V3(3, 5, 3), p)) do
if part.CanCollide and part.Transparency < 1 then return false end
end
return true
end
local function safeSpot(pos)
local floorHit = groundAt(pos, 8)
if not floorHit then return nil, "под точкой нет земли (пустота)" end
for _, off in ipairs({ V3(0, 3.5, 0), V3(0, 6, 0), V3(3, 3.5, 0), V3(-3, 3.5, 0), V3(0, 3.5, 3), V3(0, 3.5, -3), V3(0, 10, 0) }) do
local p = pos + off
if spaceFree(CF(p), V3(3, 5, 3)) then return p end
end
return nil, "точка внутри объекта или стены"
end
local function setPivot(cf)
local c, _, r = getChar()
if not (c and r) then return false end
pcall(function() c:PivotTo(cf) end)
if r then
r.AssemblyLinearVelocity = V3()
r.AssemblyAngularVelocity = V3()
end
return true
end
local function parts(model: any): any
local out = {}
for _, d in ipairs(model:GetDescendants()) do
if d:IsA("BasePart") then out[#out + 1] = d end
end
return out
end
local function weld(a, b, parent)
return I("WeldConstraint", { Part0 = a, Part1 = b }, parent or a)
end
local function formatTime(s)
s = floor(s)
return string.format("%d:%02d", floor(s / 60), s % 60)
end
local CC = I("ColorCorrectionEffect", { Name = "RM_CC", Enabled = false }, Lighting)
local BLOOM = I("BloomEffect", { Name = "RM_Bloom", Enabled = false, Intensity = 0, Size = 24, Threshold = 1 }, Lighting)
RM.cleanups[#RM.cleanups + 1] = function()
CC:Destroy()
BLOOM:Destroy()
end
local PCOL = {
{ "🟢 Зелёный", RGB(50, 255, 50) }, { "🔵 Синий", RGB(50, 150, 255) }, { "🟣 Фиолет", RGB(180, 50, 255) },
{ "🟡 Жёлтый", RGB(255, 220, 50) }, { "🔴 Красный", RGB(255, 60, 60) }, { "🟠 Оранж", RGB(255, 140, 40) },
{ "🩵 Бирюза", RGB(40, 240, 220) }, { "🩷 Розовый", RGB(255, 100, 200) },
}
local function pcol() return PCOL[clamp(floor(ST.portalColor), 1, #PCOL)][2] end
do
local C = {
bg = RGB(16, 18, 27), bg2 = RGB(32, 35, 50), bg3 = RGB(44, 48, 68), st = RGB(70, 78, 112), tx = RGB(235, 238, 246),
dim = RGB(150, 158, 180), ac = RGB(80, 230, 140), ac2 = RGB(150, 90, 255), dg = RGB(255, 90, 90),
warn = RGB(255, 200, 80), ok = RGB(90, 225, 140),
}
RM.C = C
local PG = LP:WaitForChild("PlayerGui")
local GUI = I("ScreenGui", { Name = "RM_Gui", ResetOnSpawn = false, DisplayOrder = 500, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, PG)
RM.cleanups[#RM.cleanups + 1] = function() GUI:Destroy() end
RM.gui = GUI
local U = { index = {}, cur = nil }
RM.U = U
local TOUCH = UIS.TouchEnabled
RM.touch = TOUCH
local function corner(o, r) return I("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function stroke(o, col, th, tr) return I("UIStroke", { Color = col or C.st, Thickness = th or 1, Transparency = tr or 0 }, o) end
local function label(parent, text, props: { [string]: any }?): any
local p: { [string]: any } = { BackgroundTransparency = 1, Text = text, TextColor3 = C.tx, Font = Enum.Font.Gotham, TextSize = 12,
TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }
if props then for k, v in pairs(props) do p[k] = v end end
return I("TextLabel", p, parent)
end
U.corner, U.stroke, U.label = corner, stroke, label
local function scrollOf(o: any): any
while o do
if o:IsA("ScrollingFrame") then return o end
o = o.Parent
end
return nil
end
local function reg(label_, btn)
if U.cur then U.index[#U.index + 1] = { sec = U.cur, label = label_, btn = btn } end
end
function U.sec(parent, text)
local l = label(parent, text, { Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.ac, TextWrapped = false })
I("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 2) }, l)
return l
end
function U.info(parent, text, col)
local l = label(parent, text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextColor3 = col or C.dim, TextSize = 11 })
I("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 2) }, l)
return l
end
function U.btn(parent, text, color, cb, h)
local b = I("TextButton", {
Size = UDim2.new(1, 0, 0, h or (TOUCH and 40 or 34)), BackgroundColor3 = color or C.bg2, Text = text, TextColor3 = C.tx,
Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true, AutoButtonColor = true,
}, parent)
corner(b, 8)
if cb then
conn(b.Activated:Connect(function()
snd("ui", 1)
safe("кнопка " .. tostring(text), cb, b)
end))
end
reg(text, b)
return b
end
function U.grid(parent, cols, h)
local g = I("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, parent)
I("UIGridLayout", {
CellSize = UDim2.new(1 / cols, -4, 0, h or (TOUCH and 40 or 34)), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder,
}, g)
return g
end
function U.card(parent, title, desc, cb, color)
local b = I("TextButton", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = color or C.bg2, Text = "", AutoButtonColor = true }, parent)
corner(b, 8)
label(b, title, { Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(10, 5), Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = false })
label(b, desc or "", { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(10, 24), TextColor3 = C.dim, TextSize = 10, TextWrapped = false })
if cb then
conn(b.Activated:Connect(function()
snd("ui", 1)
safe("карточка " .. title, cb, b)
end))
end
reg(title .. " " .. (desc or ""), b)
return b
end
function U.toggle(parent, text, get, set)
local b
local function upd()
local on = get()
b.Text = text .. ": " .. (on and "ВКЛ" or "ВЫКЛ")
b.BackgroundColor3 = on and RGB(32, 110, 72) or C.bg2
end
b = U.btn(parent, text, C.bg2, function()
set(not get())
upd()
end)
upd()
return b, upd
end
function U.cycle(parent, text, opts, get, set)
local b
local function upd() b.Text = text .. ": " .. tostring(get()) end
b = U.btn(parent, text, C.bg2, function()
local cur, idx = get(), 1
for i, o in ipairs(opts) do if o == cur then idx = i end end
set(opts[idx % #opts + 1])
upd()
end)
upd()
return b, upd
end
function U.input(parent, placeholder, default, h)
local t = I("TextBox", {
Size = UDim2.new(1, 0, 0, h or 34), BackgroundColor3 = C.bg2, TextColor3 = C.tx, PlaceholderColor3 = C.dim, PlaceholderText = placeholder,
Text = default or "", Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
TextWrapped = false, ClipsDescendants = true,
}, parent)
corner(t, 8)
I("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, t)
return t
end
function U.bar(parent, text, color)
local f = I("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.bg2 }, parent)
corner(f, 8)
local fill = I("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = color or C.ac, BorderSizePixel = 0 }, f)
corner(fill, 8)
local l = label(f, text, { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), Font = Enum.Font.GothamBold, TextWrapped = false })
return {
frame = f,
set = function(frac, t, col)
fill.Size = UDim2.new(clamp(frac, 0, 1), 0, 1, 0)
if t then l.Text = t end
if col then fill.BackgroundColor3 = col end
end,
}
end
function U.slider(parent, text, lo, hi, get, set, fmt, step)
fmt = fmt or "%.2f"
local f = I("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.bg2 }, parent)
corner(f, 8)
local l = label(f, "", { Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(10, 4), Font = Enum.Font.GothamBold, TextWrapped = false })
local bar = I("Frame", { Size = UDim2.new(1, -24, 0, 8), Position = UDim2.fromOffset(12, 30), BackgroundColor3 = C.bg }, f)
corner(bar, 4)
local fill = I("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.ac, BorderSizePixel = 0 }, bar)
corner(fill, 4)
local knob = I("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(0, 0, .5, 0), BackgroundColor3 = C.tx }, bar)
corner(knob, 9)
local function show()
local v = get()
local a = clamp((v - lo) / (hi - lo), 0, 1)
fill.Size = UDim2.new(a, 0, 1, 0)
knob.Position = UDim2.new(a, 0, .5, 0)
l.Text = text .. ": " .. string.format(fmt, v)
end
local dragging = false
local sf = scrollOf(parent)
local function setFrom(x)
local a = clamp((x - bar.AbsolutePosition.X) / max(bar.AbsoluteSize.X, 1), 0, 1)
local v = lo + (hi - lo) * a
if step then v = floor(v / step + .5) * step end
set(clamp(v, lo, hi))
show()
end
local hit = I("TextButton", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 16), BackgroundTransparency = 1, Text = "" }, f)
conn(hit.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
dragging = true
if sf then sf.ScrollingEnabled = false end
setFrom(i.Position.X)
end
end))
conn(UIS.InputChanged:Connect(function(i)
if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then setFrom(i.Position.X) end
end))
conn(UIS.InputEnded:Connect(function(i)
if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
dragging = false
if sf then sf.ScrollingEnabled = true end
end
end))
show()
reg(text, f)
return f, show
end
function U.list(parent, h)
local f = I("ScrollingFrame", {
Size = UDim2.new(1, 0, 0, h or 160), BackgroundColor3 = C.bg, BorderSizePixel = 0, ScrollBarThickness = 3,
CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, parent)
corner(f, 8)
I("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, f)
I("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, f)
local function clear()
for _, c in ipairs(f:GetChildren()) do
if c:IsA("GuiObject") then c:Destroy() end
end
end
return f, clear
end
function U.row(list, title, sub, buttons, order)
local row = I("Frame", { Size = UDim2.new(1, 0, 0, sub and 42 or 34), BackgroundColor3 = C.bg2, LayoutOrder = order or 0 }, list)
corner(row, 6)
local bw = (#buttons) * 38 + 4
label(row, title, { Size = UDim2.new(1, -bw - 10, 0, 18), Position = UDim2.fromOffset(8, sub and 4 or 8), Font = Enum.Font.GothamBold, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
if sub then label(row, sub, { Size = UDim2.new(1, -bw - 10, 0, 14), Position = UDim2.fromOffset(8, 23), TextColor3 = C.dim, TextSize = 10, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd }) end
for i, bdef in ipairs(buttons) do
local b = I("TextButton", {
Size = UDim2.fromOffset(34, 28), Position = UDim2.new(1, -(#buttons - i + 1) * 38 + 2, .5, -14), BackgroundColor3 = bdef[2] or C.st,
Text = bdef[1], TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = true,
}, row)
corner(b, 6)
conn(b.Activated:Connect(function()
snd("ui", 1)
safe("строка " .. title, bdef[3], b)
end))
end
return row
end
local toastBox = I("Frame", { Size = UDim2.new(0, 280, 1, -80), Position = UDim2.new(1, -290, 0, 50), BackgroundTransparency = 1, ZIndex = 100 }, GUI)
I("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, toastBox)
local toastN = 0
function RM.toast(text, color, dur)
if RM.dead or not ST.notif then return end
toastN = toastN + 1
local f = I("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.bg, BackgroundTransparency = .1, LayoutOrder = toastN, ZIndex = 100 }, toastBox)
corner(f, 8)
stroke(f, color or C.ac, 1.5, .2)
local l = label(f, tostring(text), { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextColor3 = color or C.tx, ZIndex = 101, TextSize = 12 })
I("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, l)
snd("notif", .7)
later(dur or ST.notifTime, function()
tw(f, .25, { BackgroundTransparency = 1 })
tw(l, .25, { TextTransparency = 1 })
later(.3, function() f:Destroy() end)
end)
local kids = {}
for _, c in ipairs(toastBox:GetChildren()) do if c:IsA("Frame") then kids[#kids + 1] = c end end
if #kids > 5 then kids[1]:Destroy() end
end
local vp = cam() and cam().ViewportSize or Vector2.new(800, 600)
local WW, WH = min(400, vp.X - 12), min(560, vp.Y - 24)
local mainBtn = I("TextButton", {
Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(14, 110), BackgroundColor3 = C.bg, Text = "🌀", TextSize = 30,
TextColor3 = C.ac, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 60,
}, GUI)
corner(mainBtn, 16)
stroke(mainBtn, C.ac, 2, .1)
I("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.bg), ColorSequenceKeypoint.new(1, C.bg3) }), Rotation = 45 }, mainBtn)
local win = I("CanvasGroup", { Size = UDim2.fromOffset(WW, WH), Position = UDim2.new(.5, -WW / 2, 0, 12), BackgroundColor3 = C.bg, Visible = false, ZIndex = 50, GroupTransparency = 1 }, GUI)
corner(win, 14)
stroke(win, C.st, 1.5, .1)
local winScale = I("UIScale", { Scale = 1 }, win)
RM.win, RM.mainBtn = win, mainBtn
local function drag(target: any, handle: any, tapCb: any)
local dragging, start, startPos, moved = false, nil, nil, 0
conn(handle.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
dragging, start, startPos, moved = true, i.Position, target.Position, 0
conn(i.Changed:Connect(function()
if i.UserInputState == Enum.UserInputState.End then
dragging = false
if tapCb and moved < 8 then tapCb() end
end
end))
end
end))
conn(UIS.InputChanged:Connect(function(i)
if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
local d = i.Position - start
moved = max(moved, d.Magnitude)
if moved >= 8 or not tapCb then
target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end
end
end))
end
U.drag = drag
local header = I("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.bg2, BorderSizePixel = 0, ZIndex = 51 }, win)
I("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.bg3), ColorSequenceKeypoint.new(1, C.bg2) }) }, header)
label(header, "🌀 RICK & MORTY ULTIMATE MULTIVERSE", { Size = UDim2.new(1, -90, 0, 20), Position = UDim2.fromOffset(12, 3), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.ac, TextWrapped = false, ZIndex = 52 })
local search = I("TextBox", {
Size = UDim2.new(1, -96, 0, 18), Position = UDim2.fromOffset(12, 23), BackgroundColor3 = C.bg, TextColor3 = C.tx, PlaceholderColor3 = C.dim,
PlaceholderText = "🔍 поиск функций...", Text = "", Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 52,
}, header)
corner(search, 6)
I("UIPadding", { PaddingLeft = UDim.new(0, 6) }, search)
local function hbtn(txt, x, col)
local b = I("TextButton", { Size = UDim2.fromOffset(32, 30), Position = UDim2.new(1, x, 0, 7), BackgroundColor3 = col, Text = txt, TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 52 }, header)
corner(b, 8)
return b
end
local bMin, bClose = hbtn("—", -72, C.st), hbtn("✕", -38, C.dg)
local eBar = I("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 0, 44), BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 51 }, win)
local eFill = I("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.ac, BorderSizePixel = 0, ZIndex = 52 }, eBar)
local tabs = I("ScrollingFrame", {
Size = UDim2.new(1, -8, 0, 34), Position = UDim2.fromOffset(4, 50), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = 51,
}, win)
I("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
local bodyF = I("Frame", { Size = UDim2.new(1, -8, 1, -108), Position = UDim2.fromOffset(4, 88), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 51 }, win)
local footer = label(win, "", { Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 1, -18), TextColor3 = C.dim, TextSize = 10, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 52 })
RM.setFooter = function(t) footer.Text = tostring(t) end
drag(win, header)
drag(mainBtn, mainBtn, function() RM.setWin(not win.Visible or win.GroupTransparency > .5) end)
RM.secList, RM.secPage, RM.secTab = {}, {}, {}
RM.curSec = nil
local resultsPage
local function newPage(): any
local p = I("ScrollingFrame", {
Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, Visible = false,
CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 51,
}, bodyF)
I("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, p)
I("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, p)
return p
end
function RM.showSection(key, instant)
for k, p in pairs(RM.secPage) do
local on = k == key
if on and not p.Visible then
p.Visible = true
if not instant then
p.Position = UDim2.fromOffset(14, 0)
tw(p, .22, { Position = UDim2.fromOffset(0, 0) })
end
elseif not on then
p.Visible = false
end
end
if resultsPage then resultsPage.Visible = false end
for k, t in pairs(RM.secTab) do
t.BackgroundColor3 = (k == key) and RGB(32, 110, 72) or C.bg2
end
RM.curSec = key
local pg = RM.secPage[key]
if pg and RM.onShow and RM.onShow[key] then safe("onShow " .. key, RM.onShow[key]) end
end
RM.onShow = {}
function RM.addSection(key, title, kw, build)
RM.secList[#RM.secList + 1] = { key = key, title = title, kw = kw or "", build = build }
end
function RM.buildMenu()
for i, s in ipairs(RM.secList) do
local page = newPage()
RM.secPage[s.key] = page
U.cur = s.key
U.index[#U.index + 1] = { sec = s.key, label = s.title .. " " .. s.kw, btn = nil }
local ok, e = pcall(s.build, page)
if not ok then
RM.errors[#RM.errors + 1] = "UI " .. s.key .. ": " .. str(e, 160)
RM.health[s.key] = "ошибка: " .. str(e, 80)
U.info(page, "⚠ Раздел не собрался: " .. str(e, 120), C.dg)
warn("[RM6] раздел " .. s.key .. ": " .. tostring(e))
else
RM.health[s.key] = "ok"
end
local tb = I("TextButton", {
Size = UDim2.fromOffset(max(60, utf8.len(s.title) * 7 + 12), 30), BackgroundColor3 = C.bg2, Text = s.title, TextColor3 = C.tx,
Font = Enum.Font.GothamBold, TextSize = 11, LayoutOrder = i, ZIndex = 52, AutoButtonColor = true,
}, tabs)
corner(tb, 8)
RM.secTab[s.key] = tb
conn(tb.Activated:Connect(function()
snd("ui", 1)
RM.showSection(s.key)
end))
end
U.cur = nil
resultsPage = newPage()
local function runSearch()
local q = search.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
if q == "" then
RM.showSection(RM.curSec or "home", true)
return
end
for _, c in ipairs(resultsPage:GetChildren()) do
if c:IsA("GuiObject") then c:Destroy() end
end
for _, p in pairs(RM.secPage) do p.Visible = false end
resultsPage.Visible = true
local n = 0
for _, e in ipairs(U.index) do
if e.label:lower():find(q, 1, true) and n < 40 then
n = n + 1
local sec = RM.secTab[e.sec] and RM.secTab[e.sec].Text or e.sec
local b = U.btn(resultsPage, sec .. " › " .. e.label:gsub("\n", " "):sub(1, 60), C.bg2, function()
search.Text = ""
RM.showSection(e.sec)
if e.btn and e.btn.Parent then
local old = e.btn.BackgroundColor3
for _ = 1, 3 do
e.btn.BackgroundColor3 = C.warn
task.wait(.18)
e.btn.BackgroundColor3 = old
task.wait(.14)
end
end
end)
b.LayoutOrder = n
end
end
if n == 0 then U.info(resultsPage, "Ничего не найдено по запросу «" .. q .. "»") end
end
U.cur = "_search"
conn(search:GetPropertyChangedSignal("Text"):Connect(runSearch))
U.cur = nil
RM.showSection("home", true)
end
local minimized = false
local function applySize()
local vv = cam() and cam().ViewportSize or vp
winScale.Scale = ST.uiScale
local w, h = min(400, vv.X - 12), min(560, vv.Y - 24)
win.Size = minimized and UDim2.fromOffset(w, 46) or UDim2.fromOffset(w, h)
tabs.Visible, bodyF.Visible, footer.Visible, eBar.Visible = not minimized, not minimized, not minimized, true
end
RM.applySize = applySize
function RM.setWin(v)
if v then
win.Visible = true
applySize()
winScale.Scale = ST.uiScale * .92
tw(win, .22, { GroupTransparency = 0 })
tw(winScale, .22, { Scale = ST.uiScale }, Enum.EasingStyle.Back)
snd("ui", 1, 1.1)
else
tw(win, .18, { GroupTransparency = 1 })
tw(winScale, .18, { Scale = ST.uiScale * .94 })
later(.2, function()
if win.GroupTransparency >= .9 then win.Visible = false end
end)
end
end
conn(bMin.Activated:Connect(function()
minimized = not minimized
applySize()
end))
conn(bClose.Activated:Connect(function() RM.setWin(false) end))
conn(UIS.InputBegan:Connect(function(i, gp)
if gp or UIS:GetFocusedTextBox() then return end
if i.KeyCode.Name == ST.menuKey then RM.setWin(not win.Visible or win.GroupTransparency > .5) end
end))
function RM.openSection(key)
RM.setWin(true)
RM.showSection(key)
end
local hud = I("Frame", { Size = UDim2.fromOffset(120, 36), Position = UDim2.fromOffset(14, 172), BackgroundColor3 = C.bg, BackgroundTransparency = .15, ZIndex = 60 }, GUI)
corner(hud, 8)
stroke(hud, C.st, 1, .3)
local hudE = label(hud, "⚡ 100%", { Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(6, 2), Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 61, TextWrapped = false })
local hudM = label(hud, "режим: обычный", { Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(6, 19), TextColor3 = C.dim, TextSize = 10, ZIndex = 61, TextWrapped = false })
RM.hud = hud
local MODENAME = { normal = "обычный", ship = "корабль", jet = "ранец", drone = "дрон", tp = "переход" }
RM.ticks.ui = function(dt, now)
RM.uiT = (RM.uiT or 0) + dt
if RM.uiT < .2 then return end
RM.uiT = 0
local f = EN.v / EN.max
eFill.Size = UDim2.new(clamp(f, 0, 1), 0, 1, 0)
eFill.BackgroundColor3 = f < .15 and C.dg or (f < .4 and C.warn or C.ac)
hudE.Text = "⚡ " .. floor(EN.v) .. "%  " .. (EN.total() > 0 and ("−" .. string.format("%.1f", EN.total() - EN.regen()) .. "/с") or "")
hudE.TextColor3 = f < .15 and C.dg or (f < .4 and C.warn or C.tx)
hudM.Text = "режим: " .. (MODENAME[MODE.cur] or MODE.cur)
end
end
do
local C, U = RM.C, RM.U
local corner, stroke, label = U.corner, U.stroke, U.label
local GUI = RM.gui
local TOUCH = RM.touch
local aimF = I("Frame", {
Size = UDim2.fromOffset(ST.aim, ST.aim), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, 0, .5, 0),
BackgroundTransparency = 1, Visible = false, ZIndex = 20,
}, GUI)
I("UICorner", { CornerRadius = UDim.new(1, 0) }, aimF)
stroke(aimF, C.ac, 2, .25)
I("Frame", { Size = UDim2.fromOffset(4, 4), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, 0, .5, 0), BackgroundColor3 = C.ac, ZIndex = 21 }, aimF)
RM.aimF = aimF
function RM.aimRay()
local c = cam()
if not c then return V3(), V3(0, 0, -1) end
local x, y
if TOUCH or UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
local s = c.ViewportSize
x, y = s.X / 2, s.Y / 2
else
local m = UIS:GetMouseLocation()
x, y = m.X, m.Y
end
local r = c:ViewportPointToRay(x, y)
return r.Origin, r.Direction.Unit
end
function RM.aimHit(dist)
local o, d = RM.aimRay()
local r = ray(o, d * (dist or 500))
if r then return r.Position, r.Normal, r.Instance, o, d end
return nil, nil, nil, o, d
end
RM.keybinds = {}
function RM.bindKey(name, fn) RM.keybinds[name] = fn end
conn(UIS.InputBegan:Connect(function(i, gp)
if gp or UIS:GetFocusedTextBox() then return end
local f = RM.keybinds[i.KeyCode.Name]
if f then safe("клавиша " .. i.KeyCode.Name, f) end
end))
local function down(k) return UIS:IsKeyDown(k) end
RM.mb = {}           -- name -> { btn, vis = function, held = bool }
RM.mobEdit = false
RM.forceMob = false
local mobF = I("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 30 }, GUI)
local MS = I("UIScale", { Scale = ST.mobScale }, mobF)
function RM.mobCreate(name, text, fx, fy, size, onDown, onUp, vis)
local b = I("TextButton", {
Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = C.bg, BackgroundTransparency = .25,
Text = text, TextSize = size > 60 and 26 or 20, TextColor3 = C.tx, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 31, Visible = false,
}, mobF)
corner(b, size / 2)
stroke(b, C.ac, 2, .2)
local def = { fx, fy }
local function place()
local p = SAVE.mobPos[name] or def
b.Position = UDim2.fromScale(p[1], p[2])
end
place()
local m = { btn = b, vis = vis, held = false, place = place, def = def, onDown = onDown, onUp = onUp }
RM.mb[name] = m
local dragging = false
conn(b.InputBegan:Connect(function(i)
if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
if RM.mobEdit then
dragging = true
return
end
m.held = true
b.BackgroundColor3 = C.ac2
if onDown then safe("кнопка " .. name, onDown) end
end))
conn(UIS.InputChanged:Connect(function(i)
if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
local s = GUI.AbsoluteSize
local fxp, fyp = clamp(i.Position.X / s.X, .04, .96), clamp(i.Position.Y / s.Y, .06, .94)
b.Position = UDim2.fromScale(fxp, fyp)
SAVE.mobPos[name] = { fxp, fyp }
end
end))
conn(UIS.InputEnded:Connect(function(i)
if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
dragging = false
if m.held then
m.held = false
b.BackgroundColor3 = C.bg
if onUp then safe("кнопка " .. name, onUp) end
end
end))
return m
end
function RM.mobReset()
SAVE.mobPos = {}
for _, m in pairs(RM.mb) do m.place() end
end
function RM.mobHeld(name) return RM.mb[name] and RM.mb[name].held or false end
local joyBase = I("Frame", { Size = UDim2.fromOffset(120, 120), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.14, .72), BackgroundColor3 = C.bg, BackgroundTransparency = .45, Visible = false, ZIndex = 31 }, mobF)
corner(joyBase, 60)
stroke(joyBase, C.st, 2, .2)
local joyKnob = I("Frame", { Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = C.ac, BackgroundTransparency = .2, ZIndex = 32 }, joyBase)
corner(joyKnob, 24)
RM.joy = Vector2.new()
local joyActive, joyInput = false, nil
conn(joyBase.InputBegan:Connect(function(i)
if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
joyActive, joyInput = true, i
end
end))
conn(UIS.InputChanged:Connect(function(i)
if joyActive and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
local c = joyBase.AbsolutePosition + joyBase.AbsoluteSize / 2
local d = (Vector2.new(i.Position.X, i.Position.Y) - c) / (joyBase.AbsoluteSize.X / 2)
if d.Magnitude > 1 then d = d.Unit end
RM.joy = Vector2.new(d.X, -d.Y)
joyKnob.Position = UDim2.new(.5 + d.X * .35, 0, .5 + d.Y * .35, 0)
end
end))
conn(UIS.InputEnded:Connect(function(i)
if joyActive and (i == joyInput or i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1) then
joyActive, RM.joy = false, Vector2.new()
joyKnob.Position = UDim2.fromScale(.5, .5)
end
end))
RM.customCtl = false
local savedWalk
local function controlsObj()
local ok, m = pcall(function()
local ps = LP:FindFirstChild("PlayerScripts")
local pm = ps and ps:FindFirstChild("PlayerModule")
return pm and (require :: any)(pm):GetControls() or nil
end)
return ok and m or nil
end
function RM.setCustomControls(on)
if on == RM.customCtl then return end
RM.customCtl = on
local _, h = getChar()
local cobj = controlsObj()
if on then
if cobj then pcall(function() cobj:Disable() end) end
if h then
savedWalk = { h.WalkSpeed, h.JumpPower, h.UseJumpPower }
h.WalkSpeed = 0
h.JumpPower = 0
h.UseJumpPower = true
end
else
if cobj then pcall(function() cobj:Enable() end) end
if h and savedWalk then
h.WalkSpeed, h.JumpPower, h.UseJumpPower = savedWalk[1], savedWalk[2], savedWalk[3]
savedWalk = nil
end
end
joyBase.Visible = on and (TOUCH or RM.forceMob)
end
function RM.moveDir()
local _, h = getChar()
if not RM.customCtl then return h and h.MoveDirection or V3() end
local x, z = 0, 0
if down(Enum.KeyCode.W) or down(Enum.KeyCode.Up) then z = z + 1 end
if down(Enum.KeyCode.S) or down(Enum.KeyCode.Down) then z = z - 1 end
if down(Enum.KeyCode.D) then x = x + 1 end
if down(Enum.KeyCode.A) then x = x - 1 end
x, z = x + RM.joy.X, z + RM.joy.Y
local c = cam()
if not c then return V3() end
local lv = V3(c.CFrame.LookVector.X, 0, c.CFrame.LookVector.Z)
if lv.Magnitude < .01 then return V3() end
lv = lv.Unit
local rv = V3(-lv.Z, 0, lv.X)
local v = lv * z + rv * x
if v.Magnitude > 1 then v = v.Unit end
return v
end
function RM.vertical()
local v = 0
if down(Enum.KeyCode.Space) or down(Enum.KeyCode.E) or RM.mobHeld("up") then v = v + 1 end
if down(Enum.KeyCode.LeftControl) or down(Enum.KeyCode.Q) or RM.mobHeld("down") then v = v - 1 end
return v
end
function RM.turn()
local t = 0
if down(Enum.KeyCode.Left) or down(Enum.KeyCode.Z) then t = t + 1 end
if down(Enum.KeyCode.Right) or down(Enum.KeyCode.C) then t = t - 1 end
return t
end
RM.ticks.mob = function(dt, now)
RM.mobT = (RM.mobT or 0) + dt
if RM.mobT < .15 then return end
RM.mobT = 0
MS.Scale = ST.mobScale
aimF.Size = UDim2.fromOffset(ST.aim, ST.aim)
local show = TOUCH or RM.forceMob
aimF.Visible = show and RM.heldTool() ~= nil
for _, m in pairs(RM.mb) do
local v = RM.mobEdit or (show and (not m.vis or m.vis()))
m.btn.Visible = v and true or false
end
end
function RM.heldTool()
local c = LP.Character
if not c then return nil end
for _, t in ipairs(c:GetChildren()) do
if t:IsA("Tool") and t:GetAttribute("RM_G") then return t end
end
return nil
end
RM.mobCreate("fire", "🔥", .86, .62, 74, function()
local t = RM.heldTool()
if t then t:Activate() end
end, nil, function() return RM.heldTool() ~= nil and MODE.cur ~= "ship" end)
RM.mobCreate("up", "▲", .86, .40, 60, nil, nil, function() return MODE.cur == "ship" or MODE.cur == "drone" or MODE.cur == "jet" end)
RM.mobCreate("down", "▼", .86, .52, 60, nil, nil, function() return MODE.cur == "ship" or MODE.cur == "drone" or MODE.cur == "jet" end)
RM.mobCreate("exit", "🚪", .93, .30, 54, function()
if RM.exitMode then RM.exitMode() end
end, nil, function() return MODE.cur == "ship" or MODE.cur == "drone" end)
end
do
local C, U = RM.C, RM.U
local GUI = RM.gui
local FXS = {}
RM.fx = FXS
local emitters = setmetatable({}, { __mode = "k" })
local hlCount = 0
function FXS.emitter(parent, props, rate)
local e = I("ParticleEmitter", props or {}, parent)
e:SetAttribute("RM_Rate", rate or 0)
e.Rate = (rate or 0) * Q().pr
emitters[e] = true
return e
end
RM.onQuality[#RM.onQuality + 1] = function(q)
for e in pairs(emitters) do
if e.Parent then e.Rate = (e:GetAttribute("RM_Rate") or 0) * q.pr end
end
for _, d in ipairs(WORLD:GetDescendants()) do
if d:IsA("PointLight") or d:IsA("SpotLight") then d.Enabled = q.lights end
end
end
function FXS.light(parent, color, range, bright)
local l = I("PointLight", { Color = color, Range = range or 12, Brightness = bright or 2, Enabled = Q().lights, Shadows = false }, parent)
return l
end
function FXS.anchor(pos, life)
local p = I("Part", { Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 1, Size = V3(.2, .2, .2), CFrame = CF(pos) }, FX)
task.delay(life or 3, function() p:Destroy() end)
return p
end
function FXS.spark(pos, color, n)
local a = FXS.anchor(pos, 2)
local e = I("ParticleEmitter", {
Color = ColorSequence.new(color or C.ac), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, .5), NumberSequenceKeypoint.new(1, 0) }),
Lifetime = NumberRange.new(.4, .9), Speed = NumberRange.new(8, 22), SpreadAngle = Vector2.new(180, 180), Rate = 0,
LightEmission = 1, Drag = 3, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
}, a)
e:Emit(max(2, floor((n or 24) * Q().pr)))
end
function FXS.ring(pos, color, size, normal)
local cf = normal and CFrame.lookAt(pos, pos + normal) * ANG(0, pi / 2, 0) or CF(pos) * ANG(0, 0, pi / 2)
local p = I("Part", {
Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon,
Color = color or C.ac, Transparency = .2, Size = V3(.2, 1, 1), CFrame = cf,
}, FX)
local d = (size or 14)
tw(p, .5 * Q().fxdur, { Size = V3(.2, d, d), Transparency = 1 })
task.delay(.7, function() p:Destroy() end)
end
function FXS.bolt(a, b, color, th, life)
local len = (b - a).Magnitude
if len < .1 then return end
local p = I("Part", {
Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.Neon, Color = color or C.ac,
Size = V3(th or .25, th or .25, len), CFrame = CFrame.lookAt(a, b) * CF(0, 0, -len / 2),
}, FX)
tw(p, life or .25, { Transparency = 1, Size = V3(.02, .02, len) })
task.delay((life or .25) + .05, function() p:Destroy() end)
end
function FXS.highlight(model, color, dur)
if hlCount >= Q().hl then return nil end
hlCount = hlCount + 1
local h = I("Highlight", { FillColor = color or C.ac, OutlineColor = color or C.ac, FillTransparency = .6, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, model)
local function kill()
if h.Parent then
h:Destroy()
hlCount = max(0, hlCount - 1)
end
end
if dur then later(dur, kill) end
return h, kill
end
function FXS.pulse(part: any, secs, color)
if not (part and part.Parent) then return end
local oc = part.Color
part.Color = color or RGB(255, 255, 255)
tw(part, secs or .4, { Color = oc })
end
function FXS.bubble(adornee, text, dur)
if not (adornee and adornee.Parent) then return end
for _, c in ipairs(adornee:GetChildren()) do
if c.Name == "RM_Bubble" then c:Destroy() end
end
text = tostring(text):sub(1, 80)
local w = clamp(#text * 8 + 24, 80, 260)
local g = I("BillboardGui", { Name = "RM_Bubble", Size = UDim2.fromOffset(w, 36), StudsOffset = V3(0, 3.2, 0), AlwaysOnTop = true, Adornee = adornee, MaxDistance = 120 }, adornee)
local f = I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RGB(255, 255, 255), BackgroundTransparency = .05 }, g)
I("UICorner", { CornerRadius = UDim.new(0, 12) }, f)
I("TextLabel", {
Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), BackgroundTransparency = 1, Text = text, TextColor3 = RGB(20, 20, 30),
Font = Enum.Font.GothamBold, TextSize = 13, TextWrapped = true,
}, f)
task.delay(dur or 3, function() if g.Parent then g:Destroy() end end)
end
local dimBusy = 0
function FXS.dim(color, strength)
if not ST.dimfx or RM.dead then return end
color = color or pcol()
strength = strength or 1
dimBusy = dimBusy + 1
local my = dimBusy
local q = Q()
local ov = I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = .35, ZIndex = 200, BorderSizePixel = 0 }, GUI)
I("UIGradient", {
Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .85), NumberSequenceKeypoint.new(.5, 0), NumberSequenceKeypoint.new(1, .85) }), Rotation = 90,
}, ov)
tw(ov, .7 * q.fxdur, { BackgroundTransparency = 1 })
task.delay(.8 * q.fxdur, function() ov:Destroy() end)
if q.fx then
CC.Enabled, BLOOM.Enabled = true, true
CC.TintColor = color:Lerp(RGB(255, 255, 255), .55)
CC.Saturation, CC.Contrast, CC.Brightness = 0, 0, 0
tw(CC, .18, { Saturation = 1.2 * strength, Contrast = .3 * strength, Brightness = .15 * strength })
tw(BLOOM, .18, { Intensity = 1.6 * strength })
local c = cam()
local base = c and c.FieldOfView or 70
if c then tw(c, .15, { FieldOfView = base + 22 * strength }) end
later(.2, function()
tw(CC, .8 * q.fxdur, { Saturation = 0, Contrast = 0, Brightness = 0 })
tw(BLOOM, .8 * q.fxdur, { Intensity = 0 })
if c then tw(c, .6, { FieldOfView = base }) end
end)
later(1.2 * q.fxdur, function()
if my == dimBusy then
CC.Enabled, BLOOM.Enabled = false, false
CC.TintColor = RGB(255, 255, 255)
end
end)
end
snd("tp", .8, 1)
end
function FXS.tint(on, color)
if on then
CC.Enabled = true
CC.TintColor = color or RGB(180, 200, 255)
tw(CC, .3, { Saturation = -.7, Contrast = .15 })
else
tw(CC, .4, { Saturation = 0, Contrast = 0 })
later(.45, function()
if CC.Saturation > -.05 then
CC.Enabled = false
CC.TintColor = RGB(255, 255, 255)
end
end)
end
end
end
do
local C = RM.C
local M = {}
RM.M = M
local MAT = Enum.Material
local WHITE = RGB(255, 255, 255)
local TEX = { lab = "", ship = "", fabric = "", portal = "" }
RM.TEX = TEX
local VARIANT = { lab = "RM_LabMetal", ship = "RM_ShipPanel", fabric = "RM_ScientistFabric" }
function M.part(parent, name, size, cf, color, mat, o)
local p = I("Part", {
Name = name, Size = size, CFrame = cf, Color = color or C.dim, Material = mat or MAT.SmoothPlastic, Anchored = false, CanCollide = false,
CanTouch = false, CanQuery = false, Massless = true, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
}, parent)
if o then for k, v in pairs(o) do p[k] = v end end
return p
end
function M.cyl(parent, name, r, h, cf, color, mat, o)
local p = M.part(parent, name, V3(h, r * 2, r * 2), cf * ANG(0, 0, pi / 2), color, mat, o)
p.Shape = Enum.PartType.Cylinder
return p
end
function M.ball(parent, name, d, cf, color, mat, o)
local p = M.part(parent, name, V3(d, d, d), cf, color, mat, o)
p.Shape = Enum.PartType.Ball
return p
end
function M.skin(p: any, kind)
local v = VARIANT[kind]
local ok, mv = pcall(function() return game:GetService("MaterialService"):FindFirstChild(v) end)
if ok and mv then pcall(function() p.MaterialVariant = v end) end
if TEX[kind] ~= "" then
for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Top }) do
I("Texture", { Texture = TEX[kind], Face = f, StudsPerTileU = 4, StudsPerTileV = 4, Transparency = .1 }, p)
end
end
end
function M.weldAll(model, root)
for _, d in ipairs(model:GetDescendants()) do
if d:IsA("BasePart") and d ~= root then weld(root, d, d) end
end
end
function M.anchorAll(model, v)
for _, d in ipairs(model:GetDescendants()) do
if d:IsA("BasePart") then d.Anchored = v end
end
end
function M.gadget(style, c, a, tool)
local h
if style == "pistol" then
h = M.part(tool, "Handle", V3(.5, 1.1, .7), CF(), RGB(40, 42, 50))
h.CanCollide = false
M.part(tool, "Body", V3(.6, .7, 2.2), CF(0, .8, -.8), c, MAT.Metal)
M.cyl(tool, "Nozzle", .38, .9, CF(0, .8, -2.1) * ANG(pi / 2, 0, 0), a, MAT.Neon)
M.part(tool, "Tube", V3(.18, .18, 1.6), CF(0, 1.25, -.8), a, MAT.Neon)
M.part(tool, "Cell", V3(.4, .5, .5), CF(0, 1, .55), a, MAT.Neon, { Transparency = .2 })
M.ball(tool, "Orb", .5, CF(0, 1.35, .1), a, MAT.Neon)
elseif style == "box" then
h = M.part(tool, "Handle", V3(1.3, 1.7, .5), CF(), c, MAT.Metal)
M.part(tool, "Screen", V3(1, .9, .06), CF(0, .3, -.28), a, MAT.Neon)
M.part(tool, "Bar", V3(1, .15, .08), CF(0, -.55, -.28), a, MAT.Neon, { Transparency = .3 })
M.cyl(tool, "Ant", .06, .9, CF(.45, 1.2, 0), RGB(200, 200, 210), MAT.Metal)
M.ball(tool, "Tip", .2, CF(.45, 1.7, 0), a, MAT.Neon)
elseif style == "wand" then
h = M.cyl(tool, "Handle", .16, 2.4, CF() * ANG(pi / 2, 0, 0), c, MAT.Metal)
M.ball(tool, "Tip", .8, CF(0, 0, -1.4), a, MAT.Neon, { Transparency = .15 })
M.cyl(tool, "Ring", .45, .12, CF(0, 0, -1.1) * ANG(pi / 2, 0, 0), a, MAT.Neon)
M.cyl(tool, "Pommel", .22, .3, CF(0, 0, 1.2) * ANG(pi / 2, 0, 0), a, MAT.Neon)
elseif style == "can" then
h = M.cyl(tool, "Handle", .5, 1.4, CF(), c, MAT.Metal)
M.cyl(tool, "Band", .52, .3, CF(0, .1, 0), a, MAT.Neon)
M.cyl(tool, "Cap", .3, .25, CF(0, .8, 0), RGB(210, 210, 220), MAT.Metal)
M.cyl(tool, "Glass", .42, .5, CF(0, -.4, 0), a, MAT.Glass, { Transparency = .45 })
else -- pack
h = M.part(tool, "Handle", V3(1.5, 1.9, .8), CF(), c, MAT.Metal)
M.cyl(tool, "T1", .32, 1.2, CF(-.45, -1.2, 0), RGB(200, 200, 210), MAT.Metal)
M.cyl(tool, "T2", .32, 1.2, CF(.45, -1.2, 0), RGB(200, 200, 210), MAT.Metal)
M.cyl(tool, "F1", .26, .2, CF(-.45, -1.85, 0), a, MAT.Neon)
M.cyl(tool, "F2", .26, .2, CF(.45, -1.85, 0), a, MAT.Neon)
M.part(tool, "Gauge", V3(.9, .2, .06), CF(0, .5, -.42), a, MAT.Neon)
end
for _, d in ipairs(tool:GetChildren()) do
if d:IsA("BasePart") and d ~= h then weld(h, d, d) end
end
M.skin(h, "lab")
return h
end
function M.rig(spec)
local s = spec.scale or 1
local m = I("Model", { Name = spec.name or "RMRig" })
local function bp(name, size, col, mat)
return I("Part", { Name = name, Size = size * s, Color = col, Material = mat or MAT.SmoothPlastic, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, CanCollide = false }, m)
end
local hrp = bp("HumanoidRootPart", V3(2, 2, 1), RGB(255, 255, 255))
hrp.Transparency = 1
hrp.CanCollide = true
local torso = bp("Torso", V3(2, 2, 1), spec.shirt or C.dim, spec.fabric and MAT.Fabric or MAT.SmoothPlastic)
local head = bp("Head", V3(2, 1, 1), spec.skin or RGB(240, 200, 160))
if spec.head == "ball" then
head.Shape = Enum.PartType.Ball
head.Size = V3(1.6, 1.6, 1.6) * s
elseif spec.head == "human" or spec.head == nil then
I("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = V3(1.25, 1.25, 1.25) }, head)
end
local la = bp("Left Arm", V3(1, 2, 1), spec.sleeve or spec.skin or RGB(240, 200, 160))
local ra = bp("Right Arm", V3(1, 2, 1), spec.sleeve or spec.skin or RGB(240, 200, 160))
local ll = bp("Left Leg", V3(1, 2, 1), spec.pants or RGB(60, 70, 110))
local rl = bp("Right Leg", V3(1, 2, 1), spec.pants or RGB(60, 70, 110))
hrp.CFrame = CF(0, 0, 0)
local rig = { model = m, hrp = hrp, torso = torso, head = head, joints = {}, base = {}, s = s, ph = math.random() * 6 }
local function joint(name, p0, p1, c0, c1)
local j = I("Motor6D", { Name = name, Part0 = p0, Part1 = p1, C0 = c0, C1 = c1 }, p0)
rig.joints[name] = j
rig.base[name] = c0
return j
end
local function o(x, y, z) return CF(x * s, y * s, z * s) end
joint("RootJoint", hrp, torso, CF(), CF())
joint("Neck", torso, head, o(0, 1, 0), o(0, -.5, 0))
joint("RS", torso, ra, o(1.5, .5, 0), o(0, .5, 0))
joint("LS", torso, la, o(-1.5, .5, 0), o(0, .5, 0))
joint("RH", torso, rl, o(.5, -1, 0), o(0, 1, 0))
joint("LH", torso, ll, o(-.5, -1, 0), o(0, 1, 0))
local hum = I("Humanoid", { RigType = Enum.HumanoidRigType.R6, MaxHealth = spec.hp or 100, Health = spec.hp or 100, WalkSpeed = spec.speed or 14, DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None, HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff }, m)
hum.AutomaticScalingEnabled = false
rig.hum = hum
m.PrimaryPart = hrp
rig.parts = { torso = torso, head = head, la = la, ra = ra, ll = ll, rl = rl }
if spec.extras then spec.extras(rig, rig.parts) end
return rig
end
local POSE = {
happy = { ra = -2.6, la = -2.6 }, angry = { ra = -1.3, la = -1.3 }, sad = { head = .4 }, scared = { ra = -2.2, la = -2.2, head = -.2 },
crazy = { ra = -2.8, la = 2.8 }, thinking = { ra = -1.7, head = .15 }, surprised = { ra = -2.0, la = -2.0 },
}
function M.anim(rig, dt, speed, pose)
if not (rig.model and rig.model.Parent) then return end
rig.ph = rig.ph + dt * (3 + speed * .5)
local j, b = rig.joints, rig.base
local sw = min(speed / 14, 1.4)
local a = sin(rig.ph * 2.2) * sw
local P = pose and POSE[pose.e] or nil
local atk = pose and pose.atk or 0
local ras = P and P.ra or 0
local las = P and P.la or 0
local function set(name, rx, rz)
local jj = j[name]
if jj then jj.C0 = b[name] * ANG(rx, 0, rz or 0) end
end
set("RS", (P and P.ra) and ras or (-a * 1.1 - atk * 1.8), 0)
set("LS", (P and P.la) and las or (a * 1.1), 0)
set("RH", a * 1.0, 0)
set("LH", -a * 1.0, 0)
set("Neck", P and P.head or 0, sin(rig.ph * .8) * .05)
local jr = j.RootJoint
if jr then jr.C0 = CF(0, abs(a) * .15 * rig.s, 0) * ANG(speed > 2 and -.08 or 0, 0, 0) end
end
function M.walkTo(rig, pos)
if rig.hum and rig.hum.Parent then rig.hum:MoveTo(pos) end
end
end
do
local C, M, fx = RM.C, RM.M, RM.fx
local SK = { list = {}, cur = nil, store = {}, costume = nil, face = "normal" }
RM.sk = SK
RM.charHooks = RM.charHooks or {}
local MAT = Enum.Material
local R15 = { head = "Head", torso = "UpperTorso", la = "LeftUpperArm", ra = "RightUpperArm", ll = "LeftUpperLeg", rl = "RightUpperLeg" }
local R6 = { head = "Head", torso = "Torso", la = "Left Arm", ra = "Right Arm", ll = "Left Leg", rl = "Right Leg" }
local COLG = {
R15 = { skin = { "Head", "LeftHand", "RightHand", "LeftLowerArm", "RightLowerArm" }, shirt = { "UpperTorso", "LeftUpperArm", "RightUpperArm" },
pants = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" } },
R6 = { skin = { "Head" }, shirt = { "Torso", "Left Arm", "Right Arm" }, pants = { "Left Leg", "Right Leg" } },
}
local function rigOf(ch: any): (any, any)
local h = ch and ch:FindFirstChildOfClass("Humanoid")
if not h then return nil end
return h.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6", h
end
local function bodyPart(ch: any, key: string): any
local t = rigOf(ch) == "R15" and R15 or R6
return ch:FindFirstChild(t[key])
end
local W, K = RGB(245, 245, 250), RGB(25, 25, 30)
local function skinDef(n, sk, sh, pa, items, say)
local d = { n = n, skin = sk, shirt = sh, pants = pa, items = items, say = say }
SK.list[#SK.list + 1] = d
return d
end
local function it(g, sx, sy, sz, x, y, z, col, mat, shape, rx, ry, rz) return { g, V3(sx, sy, sz), CF(x, y, z) * ANG(rx or 0, ry or 0, rz or 0), col, mat or MAT.SmoothPlastic, shape } end
local function spikes(col, n)
local t = {}
for i = 1, n do
local a = (i / n) * pi * 2
t[#t + 1] = it("head", .35, 1.1, .35, cos(a) * .45, .75, sin(a) * .45, col, nil, nil, sin(a) * .5, 0, -cos(a) * .5)
end
t[#t + 1] = it("head", .4, 1.3, .4, 0, .85, 0, col)
return t
end
local function join(...)
local o = {}
for _, t in ipairs({ ... }) do for _, v in ipairs(t) do o[#o + 1] = v end end
return o
end
local BLUEH, SKIN = RGB(150, 215, 235), RGB(238, 205, 170)
local coat = { it("torso", 2.25, 2.1, 1.25, 0, -.1, 0, W, MAT.Fabric), it("torso", 2.25, 1.4, 1.25, 0, -1.6, 0, W, MAT.Fabric),
it("la", 1.25, 1.5, 1.25, 0, -.2, 0, W, MAT.Fabric), it("ra", 1.25, 1.5, 1.25, 0, -.2, 0, W, MAT.Fabric) }
local brow = { it("head", .8, .12, .1, 0, .22, -.52, RGB(70, 70, 70)) }
local eyepatch = { it("head", .5, .4, .1, .28, .1, -.52, K) }
skinDef("🧪 Рик", SKIN, RGB(90, 160, 200), RGB(110, 110, 120), join(spikes(BLUEH, 7), coat, brow), { "*рыг* Наука, Морти!", "Не ной, Морти.", "Дело в мультивселенной." })
skinDef("😰 Морти", SKIN, RGB(255, 220, 40), RGB(70, 100, 200), { it("head", 1.3, .6, 1.3, 0, .55, 0, RGB(110, 70, 40)), it("head", 1.1, .3, 1.1, 0, .75, .1, RGB(110, 70, 40)) },
{ "О-ой, Рик!", "Мне это не нравится...", "Д-да, конечно." })
skinDef("🕶 Злой Морти", SKIN, RGB(255, 220, 40), RGB(40, 40, 60), join({ it("head", 1.3, .6, 1.3, 0, .55, 0, K), it("torso", 2.2, 1.9, 1.2, 0, -.05, 0, K, MAT.Fabric),
it("la", 1.2, 1.4, 1.2, 0, -.2, 0, K, MAT.Fabric), it("ra", 1.2, 1.4, 1.2, 0, -.2, 0, K, MAT.Fabric) }, eyepatch), { "У меня есть план.", "Всё идёт по плану." })
skinDef("🏴 Рик Прайм", SKIN, RGB(60, 70, 80), RGB(50, 50, 55), join(spikes(RGB(120, 150, 170), 6), { it("torso", 2.25, 2.1, 1.25, 0, -.1, 0, RGB(80, 85, 95), MAT.Fabric),
it("torso", 2.25, 1.4, 1.25, 0, -1.6, 0, RGB(80, 85, 95), MAT.Fabric) }, eyepatch), { "Я — самый умный.", "Вы все — мои копии." })
skinDef("👨 Джерри", SKIN, RGB(140, 190, 215), RGB(110, 100, 90), { it("head", 1.5, .3, 1.5, 0, .5, 0, RGB(130, 125, 120)), it("head", .4, .4, .4, .6, .1, 0, RGB(130, 125, 120)) },
{ "Я тоже умный!", "Ну и ладно.", "Хей, ребята!" })
skinDef("🎀 Саммер", RGB(250, 220, 190), RGB(255, 140, 60), RGB(90, 120, 190), { it("head", 1.4, .6, 1.4, 0, .5, 0, RGB(235, 160, 60)), it("head", .5, 1.8, .5, 0, -.2, .6, RGB(235, 160, 60)),
it("head", .5, .5, .3, .5, .5, .35, RGB(230, 70, 130)) }, { "Серьёзно?!", "Дедушка, ну пожалуйста.", "Да ладно!" })
skinDef("🟦 Мисикс", RGB(90, 190, 235), RGB(90, 190, 235), RGB(90, 190, 235), { it("head", .8, .1, .1, .0, .3, -.52, K), it("head", .5, .5, .1, -.3, .1, -.52, W, nil, "Ball"), it("head", .5, .5, .1, .3, .1, -.52, W, nil, "Ball"),
it("head", .9, .15, .1, 0, -.25, -.52, K) }, { "Смотрите на меня!", "Я Мистер Мисикс!", "Выполню — и исчезну!" })
skinDef("🥒 Огурец Рик", RGB(95, 150, 60), RGB(95, 150, 60), RGB(80, 130, 50), { it("torso", .5, .5, .5, .5, .3, -.5, RGB(60, 105, 40), nil, "Ball"), it("torso", .6, .6, .6, -.5, -.4, -.5, RGB(60, 105, 40), nil, "Ball"),
it("head", .5, .5, .5, -.4, .3, -.5, RGB(60, 105, 40), nil, "Ball"), it("la", .5, .5, .5, 0, -.3, -.5, RGB(60, 105, 40), nil, "Ball") }, { "Я — огурец!", "Это даже круче." })
SK.byName = {}
for _, d in ipairs(SK.list) do SK.byName[d.n] = d end
SK.faces = {
{ "normal", "Обычное", "●  ●", "‿" }, { "happy", "Радость", "^  ^", "◡" }, { "angry", "Злость", "▼  ▼", "︵" }, { "sad", "Грусть", "•  •", "︵" },
{ "surprised", "Удивление", "◎  ◎", "o" }, { "scared", "Страх", "◉  ◉", "﹏" }, { "crazy", "Безумие", "@  @", "ᗜ" }, { "wink", "Подмигивание", "●  ‿", "◡" },
{ "think", "Мысль", "●  ◔", "~" }, { "sleep", "Сон", "-  -", "z" }, { "smirk", "Ухмылка", "●  ●", "ᴗ" }, { "burp", "Рыг", "x  x", "~" },
}
SK.faceBy = {}
for _, f in ipairs(SK.faces) do SK.faceBy[f[1]] = f end
local function faceGui(ch)
local h = bodyPart(ch, "head")
return h and h:FindFirstChild("RM_Face")
end
function SK.setFace(name)
local f = SK.faceBy[name] or SK.faceBy.normal
SK.face = f[1]
local ch = LP.Character
local g = ch and faceGui(ch)
if g then
g.SurfaceGui.Eyes.Text = f[3]
g.SurfaceGui.Mouth.Text = f[4]
end
end
local function ensureFace(ch)
local h = bodyPart(ch, "head")
if not h or h:FindFirstChild("RM_Face") then return end
local old = h:FindFirstChild("face")
if old and old:IsA("Decal") then
SK.store.faceT = { old, old.Transparency }
old.Transparency = 1
end
local p = M.part(h, "RM_Face", V3(1.5, .9, .05), h.CFrame * CF(0, 0, -(h.Size.Z / 2 + .03)), K, nil, { Transparency = 1 })
p.Name = "RM_Face"
weld(h, p, p)
local sg = I("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, AlwaysOnTop = false, LightInfluence = 0 }, p)
I("TextLabel", { Name = "Eyes", Size = UDim2.fromScale(1, .55), BackgroundTransparency = 1, Text = "●  ●", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = K }, sg)
I("TextLabel", { Name = "Mouth", Position = UDim2.fromScale(0, .5), Size = UDim2.fromScale(1, .45), BackgroundTransparency = 1, Text = "‿", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = K }, sg)
SK.setFace(SK.face)
end
SK.emos = {
normal = { "Обычное", "normal", 0, 0 }, happy = { "Радость", "happy", 2.4, 2.4 }, angry = { "Злость", "angry", .9, .9 }, sad = { "Грусть", "sad", 0, 0 },
scared = { "Страх", "scared", 2.1, 2.1 }, crazy = { "Безумие", "crazy", 2.8, .5 }, thinking = { "Размышление", "think", 1.3, 0 }, surprised = { "Удивление", "surprised", 1.6, 1.6 },
}
SK.emoOrder = { "normal", "happy", "angry", "sad", "scared", "crazy", "thinking", "surprised" }
local function shoulders(ch)
local r, l
if rigOf(ch) == "R15" then
local ra, la = ch:FindFirstChild("RightUpperArm"), ch:FindFirstChild("LeftUpperArm")
r, l = ra and ra:FindFirstChild("RightShoulder"), la and la:FindFirstChild("LeftShoulder")
else
local t = ch:FindFirstChild("Torso")
r, l = t and t:FindFirstChild("Right Shoulder"), t and t:FindFirstChild("Left Shoulder")
end
return r, l
end
function SK.setEmotion(name)
local e = SK.emos[name] or SK.emos.normal
ST.emotion = SK.emos[name] and name or "normal"
SK.setFace(e[2])
local ch = LP.Character
if not ch then return end
local r, l = shoulders(ch)
SK.store.sh = SK.store.sh or { r = r and r.C0, l = l and l.C0 }
if r and SK.store.sh.r then r.C0 = SK.store.sh.r * ANG(0, 0, e[3]) end
if l and SK.store.sh.l then l.C0 = SK.store.sh.l * ANG(0, 0, -e[4]) end
end
function SK.say(text)
local ch = LP.Character
local h = ch and bodyPart(ch, "head")
if h then fx.bubble(h, text or "...", 3.5) end
end
function SK.clear()
if SK.costume then SK.costume:Destroy() end
SK.costume = nil
local ch = LP.Character
local st = SK.store
if st.colors then
for p, c in pairs(st.colors) do
if p.Parent then p.Color = c end
end
end
if st.acc then
for p, t in pairs(st.acc) do
if p.Parent then p.Transparency = t end
end
end
if st.cloth then
for o, v in pairs(st.cloth) do
if o.Parent then
if o:IsA("Shirt") then o.ShirtTemplate = v elseif o:IsA("Pants") then o.PantsTemplate = v end
end
end
end
SK.store = { sh = SK.store.sh }
SK.cur, ST.skin = nil, ""
if ch then SK.setEmotion(ST.emotion) end
end
function SK.apply(name, silent)
local d = SK.byName[name]
local ch = LP.Character
if not (d and ch and rigOf(ch)) then return false end
SK.clear()
local rt = rigOf(ch)
local st = { colors = {}, acc = {}, cloth = {}, sh = SK.store.sh }
SK.store = st
for kind, names in pairs(COLG[rt]) do
local col = d[kind]
for _, n in ipairs(names) do
local p = ch:FindFirstChild(n)
if p and p:IsA("BasePart") then
st.colors[p] = p.Color
p.Color = col
end
end
end
for _, o in ipairs(ch:GetChildren()) do
if o:IsA("Accessory") then
local hd = o:FindFirstChild("Handle")
if hd and hd:IsA("BasePart") then
st.acc[hd] = hd.Transparency
hd.Transparency = 1
end
elseif o:IsA("Shirt") then
st.cloth[o] = o.ShirtTemplate
o.ShirtTemplate = ""
elseif o:IsA("Pants") then
st.cloth[o] = o.PantsTemplate
o.PantsTemplate = ""
end
end
local fol = I("Folder", { Name = "RM_Costume" }, ch)
SK.costume = fol
for _, i in ipairs(d.items) do
local bp = bodyPart(ch, i[1])
if bp then
local sz = i[2]
if i[1] == "torso" and rt == "R6" then sz = V3(sz.X, sz.Y * 1.05, sz.Z) end
local p = M.part(fol, "Item", sz, bp.CFrame * i[3], i[4], i[5])
if i[6] == "Ball" then p.Shape = Enum.PartType.Ball end
weld(bp, p, p)
end
end
ensureFace(ch)
SK.cur, ST.skin = name, name
SK.setEmotion(ST.emotion)
if not silent then
snd("gadget", 1, 1.2)
SK.say(d.say[math.random(#d.say)])
notify("Скин: " .. name, C.ac)
end
return true
end
RM.charHooks[#RM.charHooks + 1] = function(ch)
SK.store, SK.costume = {}, nil
task.wait(.6)
if RM.dead or LP.Character ~= ch then return end
if ST.skin ~= "" and SK.byName[ST.skin] then SK.apply(ST.skin, true) else ensureFace(ch) SK.setEmotion(ST.emotion) end
end
RM.cleanups[#RM.cleanups + 1] = function() pcall(SK.clear) end
end
do
local C, M, fx = RM.C, RM.M, RM.fx
local G, UN = {}, {}
RM.G, RM.gOrder, RM.units = G, {}, UN
local cds = {}
local propsF = folder("Props")
RM.propsF = propsF
function RM.hurt(inst, amt, pos)
local o = inst
while o and o ~= WORLD do
local u = UN[o]
if u then
u.hurt(amt, pos)
return true
end
o = o.Parent
end
return false
end
function RM.unitsNear(pos, r, pred)
local out = {}
for m, u in pairs(UN) do
local p = u.root and u.root.Parent and u.root.Position
if p and (p - pos).Magnitude <= r and (not pred or pred(u)) then out[#out + 1] = u end
end
return out
end
function RM.boom(pos, r, dmg, color)
color = color or RGB(255, 150, 60)
fx.spark(pos, color, 40)
fx.ring(pos, color, r * 2)
snd("exp", 1, 1)
for _, u in ipairs(RM.unitsNear(pos, r)) do u.hurt(dmg * (1 - (u.root.Position - pos).Magnitude / (r * 1.4)), pos) end
end
function RM.regGadget(d)
if not G[d.id] then RM.gOrder[#RM.gOrder + 1] = d.id end
G[d.id] = d
end
local function findTool(id)
for _, c in ipairs({ LP.Character, LP:FindFirstChildOfClass("Backpack") }) do
if c then
for _, t in ipairs(c:GetChildren()) do
if t:IsA("Tool") and t:GetAttribute("RM_G") == id then return t end
end
end
end
end
RM.findTool = findTool
function RM.fireGadget(id)
local d = G[id]
if not d or RM.dead then return end
local now = os.clock()
if cds[id] and now < cds[id] then return end
if d.cost and d.cost > 0 and not EN.use(d.cost, d.name) then return end
cds[id] = now + (d.cd or .3)
local c, h, r = getChar()
if not (c and r) then return end
local pos, nrm, inst, o, dir = RM.aimHit(d.range or 300)
local ok = safe("гаджет " .. id, d.use, { pos = pos, nrm = nrm, inst = inst, o = o, d = dir, root = r, hum = h, char = c })
if not ok then EN.add(d.cost or 0) end
end
function RM.giveGadget(id, noEquip)
local d = G[id]
local _, h = getChar()
local bp = LP:FindFirstChildOfClass("Backpack")
if not (d and h and bp) then return end
local t = findTool(id)
if not t then
t = I("Tool", { Name = d.name, RequiresHandle = true, CanBeDropped = false, ToolTip = d.desc or "" })
t:SetAttribute("RM_G", id)
M.gadget(d.style or "pistol", d.col or RGB(70, 80, 100), d.acc or C.ac, t)
conn(t.Activated:Connect(function() RM.fireGadget(id) end))
if d.onUnequip then conn(t.Unequipped:Connect(function() safe("снят " .. id, d.onUnequip) end)) end
t.Parent = bp
RM.gToast = true
end
if not noEquip then h:EquipTool(t) end
return t
end
function RM.removeGadget(id)
local t = findTool(id)
if t then t:Destroy() end
end
RM.cleanups[#RM.cleanups + 1] = function()
for _, c in ipairs({ LP.Character, LP:FindFirstChildOfClass("Backpack") }) do
if c then
for _, t in ipairs(c:GetChildren()) do
if t:IsA("Tool") and t:GetAttribute("RM_G") then t:Destroy() end
end
end
end
end
local function shot(x, color, dmg, th)
local from = x.root.Position + V3(0, 1, 0)
local c = RM.heldTool()
local hd = c and c:FindFirstChild("Handle")
if hd then from = hd.Position + hd.CFrame.LookVector * 1.5 end
local to = x.pos or (x.o + x.d * 300)
fx.bolt(from, to, color, th or .25, .22)
snd("shoot", 1, 1 + math.random() * .2)
if x.pos then
fx.spark(to, color, 10)
if x.inst then RM.hurt(x.inst, dmg, x.pos) end
end
end
RM.regGadget({ id = "laser", name = "Лазерный пистолет", icon = "🔫", desc = "Луч по цели, урон локальным целям", style = "pistol", col = RGB(60, 70, 90), acc = RGB(255, 70, 70),
cost = CFG.cost.fire, cd = .18, use = function(x) shot(x, RGB(255, 70, 70), 22) end })
RM.regGadget({ id = "plasma", name = "Плазмомёт", icon = "💥", desc = "Взрыв по площади", style = "pistol", col = RGB(80, 60, 100), acc = RGB(190, 90, 255),
cost = 6, cd = .9, use = function(x)
shot(x, RGB(190, 90, 255), 0, .6)
if x.pos then RM.boom(x.pos, 12, 60, RGB(190, 90, 255)) end
end })
RM.regGadget({ id = "grapple", name = "Крюк-кошка", icon = "🪝", desc = "Подтягивает к точке прицела", style = "pistol", col = RGB(90, 90, 100), acc = RGB(255, 220, 80),
cost = 5, cd = 1.2, range = 220, use = function(x)
if not x.pos then return notify("Крюку не за что зацепиться", C.warn) end
fx.bolt(x.root.Position, x.pos, RGB(255, 220, 80), .15, .7)
snd("gadget", 1, 1.4)
local t0 = os.clock()
task.spawn(function()
while not RM.dead and os.clock() - t0 < 1.1 and x.root.Parent do
local d = x.pos - x.root.Position
if d.Magnitude < 7 then break end
x.root.AssemblyLinearVelocity = d.Unit * 80
task.wait()
end
end)
end })
RM.regGadget({ id = "dash", name = "Рывок-ботинки", icon = "👟", desc = "Быстрый рывок вперёд", style = "can", col = RGB(60, 60, 80), acc = RGB(80, 230, 255),
cost = 6, cd = 1.4, use = function(x)
local l = x.root.CFrame.LookVector
x.root.AssemblyLinearVelocity = V3(l.X, .15, l.Z).Unit * 95
fx.ring(x.root.Position, RGB(80, 230, 255), 10)
snd("gadget", 1, 1.6)
end })
local buffs = {}
local function buff(key, dur, apply, undo)
if buffs[key] then
apply()
buffs[key] = os.clock() + dur
return
end
buffs[key] = os.clock() + dur
apply()
task.spawn(function()
while not RM.dead and buffs[key] and os.clock() < buffs[key] do task.wait(.25) end
buffs[key] = nil
pcall(undo)
end)
end
RM.regGadget({ id = "speed", name = "Сыворотка скорости", icon = "💉", desc = "Скорость ×1.8, 20 с (только на твоём клиенте)", style = "can", col = RGB(50, 90, 60), acc = RGB(80, 255, 120),
cost = 10, cd = 2, use = function(x)
local h = x.hum
local base = h.WalkSpeed
buff("speed", 20, function() h.WalkSpeed = max(base, 16) * 1.8 end, function() if h.Parent then h.WalkSpeed = 16 end end)
notify("💉 Скорость повышена на 20 с", C.ok)
end })
RM.regGadget({ id = "boots", name = "Прыжковые ботинки", icon = "🥾", desc = "Высокий прыжок, 25 с", style = "can", col = RGB(80, 60, 40), acc = RGB(255, 200, 60),
cost = 8, cd = 2, use = function(x)
local h = x.hum
local use = h.UseJumpPower
buff("boots", 25, function()
h.UseJumpPower = true
h.JumpPower = 120
end, function() if h.Parent then h.JumpPower = 50 h.UseJumpPower = use end end)
notify("🥾 Прыжок усилен на 25 с", C.ok)
end })
local toggles = {}
local function toggler(id, name, icon, desc, style, col, acc, drainRate, on, off, cost)
RM.regGadget({ id = id, name = name, icon = icon, desc = desc, style = style, col = col, acc = acc, cost = 0, cd = .4, use = function(x)
if toggles[id] then
toggles[id] = nil
EN.stop(id)
off()
notify(icon .. " " .. name .. ": выкл", C.dim)
else
if cost and not EN.use(cost, name) then return end
toggles[id] = true
if drainRate then EN.drain(id, drainRate, function() toggles[id] = nil off() end) end
on(x)
notify(icon .. " " .. name .. ": вкл", C.ok)
end
end, onUnequip = nil })
RM.cleanups[#RM.cleanups + 1] = function() if toggles[id] then pcall(off) end end
end
local lamp
toggler("lamp", "Фонарь Рика", "🔦", "Мощный луч света", "can", RGB(80, 80, 90), RGB(255, 245, 200), nil, function(x)
local hd = x.root
lamp = I("SpotLight", { Range = 70, Angle = 60, Brightness = 5, Color = RGB(255, 245, 210), Face = Enum.NormalId.Front, Shadows = false }, hd)
end, function() if lamp then lamp:Destroy() lamp = nil end end)
local thermalOn = false
toggler("thermal", "Тепловизор", "🌡", "Подсвечивает живых и роботов в радиусе", "box", RGB(70, 50, 40), RGB(255, 120, 40), CFG.drain.helmet, function() thermalOn = true end, function() thermalOn = false end)
local thHl = {}
RM.ticks.thermal = function(dt, now)
if not thermalOn and not next(thHl) then return end
RM.thT = (RM.thT or 0) + dt
if RM.thT < .7 then return end
RM.thT = 0
for m, k in pairs(thHl) do
if not thermalOn or not m.Parent then
k()
thHl[m] = nil
end
end
if not thermalOn then return end
local _, _, r = getChar()
if not r then return end
local function add(m)
if m and m ~= LP.Character and not thHl[m] then
local pr = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
if pr and (pr.Position - r.Position).Magnitude < 140 then
local h, k = fx.highlight(m, RGB(255, 110, 40))
if h then thHl[m] = k end
end
end
end
for _, p in ipairs(Players:GetPlayers()) do add(p.Character) end
for m in pairs(UN) do add(m) end
end
local cloakOrig
toggler("cloak", "Невидимка", "🫥", "Ты становишься полупрозрачным (видно только на твоём клиенте)", "box", RGB(40, 40, 60), RGB(150, 120, 255), 1.4, function(x)
cloakOrig = {}
for _, p in ipairs(parts(x.char)) do
if p.Name ~= "HumanoidRootPart" and p.Transparency < .9 then
cloakOrig[p] = p.Transparency
p.Transparency = .85
end
end
end, function()
for p, t in pairs(cloakOrig or {}) do if p.Parent then p.Transparency = t end end
cloakOrig = nil
end, 5)
local trees = {}
RM.regGadget({ id = "seed", name = "Мегасемя", icon = "🌳", desc = "Растит энергодерево: рядом +энергия", style = "can", col = RGB(60, 90, 50), acc = RGB(120, 255, 140),
cost = 8, cd = 1, range = 120, use = function(x)
if not x.pos or not canAdd("props", CFG.limit.props) then return end
local m = I("Model", { Name = "EnergyTree" }, propsF)
local up = x.nrm or V3(0, 1, 0)
local base = CFrame.lookAt(x.pos, x.pos + up) * ANG(-pi / 2, 0, 0)
local trunk = M.cyl(m, "T", .8, 1, base * CF(0, .5, 0), RGB(110, 80, 50), Enum.Material.Wood, { Anchored = true })
local crown = M.ball(m, "Crown", .5, base * CF(0, 1.5, 0), RGB(60, 255, 140), Enum.Material.Neon, { Anchored = true, Transparency = .2 })
fx.light(crown, RGB(60, 255, 140), 18, 2)
tw(trunk, 1.2, { Size = V3(9, 1.6, 1.6), CFrame = base * CF(0, 4.5, 0) * ANG(0, 0, pi / 2) })
tw(crown, 1.2, { Size = V3(8, 8, 8), CFrame = base * CF(0, 10, 0) })
local e = entAdd("props", { m = m, pos = x.pos, destroy = function(s) s.m:Destroy() end })
trees[#trees + 1] = e
snd("gadget", 1, .8)
later(90, function()
entDel("props", e)
for i = #trees, 1, -1 do if trees[i] == e then table.remove(trees, i) end end
if m.Parent then m:Destroy() end
end)
end })
RM.ticks.trees = function(dt)
if #trees == 0 then return end
local _, _, r = getChar()
if not r then return end
for _, t in ipairs(trees) do
if (t.pos - r.Position).Magnitude < 22 then EN.add(3 * dt) end
end
end
SAVE.comps = SAVE.comps or {}
RM.regGadget({ id = "battery", name = "Батарея-заряд", icon = "🔋", desc = "Тратит 1 батарею из инвентаря: +40 энергии", style = "box", col = RGB(60, 60, 70), acc = RGB(255, 230, 60),
cost = 0, cd = 1, use = function()
if (SAVE.comps.battery or 0) < 1 then return notify("Нет батарей. Их даёт генератор и сканер", C.warn) end
SAVE.comps.battery = SAVE.comps.battery - 1
EN.add(40)
snd("energy", 1, 1.2)
notify("🔋 +40 энергии", C.ok)
end })
function RM.addComp(k, n)
SAVE.comps = SAVE.comps or {}
SAVE.comps[k] = clamp((SAVE.comps[k] or 0) + (n or 1), 0, 99)
end
end
do
local C, M, fx = RM.C, RM.M, RM.fx
local PO = { A = nil, B = nil, cd = 0, nextSlot = "A" }
RM.portals = PO
local portF = folder("Portals")
local function colB() return PCOL[(clamp(floor(ST.portalColor), 1, #PCOL)) % #PCOL + 1][2] end
function RM.teleport(pos, ry, exact, vel)
if RM.dead then return false end
local sp, why = pos, nil
if not exact then sp, why = safeSpot(pos) end
if not sp then
notify("⚠ Телепорт отменён: " .. why, C.warn)
return false, why
end
fx.dim(pcol(), 1)
local _, _, r = getChar()
if r then fx.spark(r.Position, pcol(), 24) end
setPivot(CF(sp) * ANG(0, ry or 0, 0))
if vel and r then r.AssemblyLinearVelocity = vel end
fx.spark(sp, pcol(), 24)
PO.cd = os.clock() + CFG.portal.cd
return true
end
local function closeOne(k)
local p = PO[k]
if p then
p.m:Destroy()
entDel("portals", p)
PO[k] = nil
end
end
function RM.portalClose()
closeOne("A")
closeOne("B")
end
function RM.portalOpen(k, pos, n, col)
closeOne(k)
n = n.Magnitude > .1 and n.Unit or V3(0, 1, 0)
local r = CFG.portal.r
local m = I("Model", { Name = "Portal" .. k }, portF)
local base = CFrame.lookAt(pos + n * .15, pos + n) * ANG(-pi / 2, 0, 0)
local ring = M.cyl(m, "Ring", r, .5, base, col, Enum.Material.Neon, { Anchored = true })
local disc = M.cyl(m, "Disc", r - .7, .3, base * CF(0, .1, 0), col:Lerp(RGB(255, 255, 255), .4), Enum.Material.Neon, { Anchored = true, Transparency = .45 })
fx.light(ring, col, 26, 3)
fx.emitter(disc, {
Color = ColorSequence.new(col), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, .6), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(.6, 1.2),
Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(60, 60), LightEmission = 1, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .1), NumberSequenceKeypoint.new(1, 1) }),
EmissionDirection = Enum.NormalId.Right,
}, 40)
ring.Size = V3(.01, .01, .01)
tw(ring, .35, { Size = V3(.5, r * 2, r * 2) }, Enum.EasingStyle.Back)
local e = entAdd("portals", { m = m, ring = ring, disc = disc, pos = pos + n * .15, n = n, t0 = os.clock(), base = base, ang = 0, destroy = function(s) s.m:Destroy() end })
PO[k] = e
snd("portal", 1, k == "A" and 1 or 1.15)
fx.ring(pos, col, 14, n)
return e
end
local function placeAt(x, slot)
local pos, n = x.pos, x.nrm
if not pos then
pos = x.o + x.d * 40
n = -x.d
end
RM.portalOpen(slot, pos, n, slot == "A" and pcol() or colB())
end
RM.ticks.portals = function(dt, now)
for _, k in ipairs({ "A", "B" }) do
local p = PO[k]
if p and p.m.Parent then
p.ang = p.ang + dt * 2.5
p.disc.CFrame = p.base * CF(0, .1, 0) * ANG(0, p.ang, 0)
local left = CFG.portal.life - (now - p.t0)
if left < 4 then
local a = clamp(1 - left / 4, 0, 1)
p.ring.Transparency = a
p.disc.Transparency = .45 + a * .55
end
if left <= 0 then
closeOne(k)
notify("Портал " .. k .. " закрылся", C.dim)
end
end
end
local A, B = PO.A, PO.B
if not (A and B) or now < PO.cd or MODE.cur == "ship" or MODE.cur == "drone" then return end
local _, _, r = getChar()
if not r then return end
for _, pair in ipairs({ { A, B }, { B, A } }) do
local s, d = pair[1], pair[2]
local off = r.Position - s.pos
local along = off:Dot(s.n)
if abs(along) < 2.8 and (off - s.n * along).Magnitude < CFG.portal.r - .6 then
local speed = max(24, r.AssemblyLinearVelocity.Magnitude)
local dest = d.pos + d.n * 4.2
RM.teleport(dest, 0, true, d.n * speed)
setPivot(CFrame.lookAt(dest, dest + V3(d.n.X, 0, d.n.Z)))
r.AssemblyLinearVelocity = d.n * speed
return
end
end
end
RM.regGadget({ id = "portal1", name = "Портальная пушка", icon = "🌀", desc = "Выстрелы по очереди создают портал A и B", style = "pistol", col = RGB(210, 215, 225), acc = RGB(80, 255, 120),
cost = CFG.cost.portal, cd = CFG.portal.cd, range = CFG.portal.range, use = function(x)
local s = PO.nextSlot
placeAt(x, s)
PO.nextSlot = s == "A" and "B" or "A"
notify("Портал " .. s .. (PO.A and PO.B and " — пара готова" or ""), s == "A" and pcol() or colB(), 1.5)
end })
RM.regGadget({ id = "portal2", name = "Квантовый прыгун", icon = "⚡", desc = "Прыжок в точку прицела", style = "pistol", col = RGB(60, 50, 90), acc = RGB(180, 90, 255),
cost = CFG.cost.portal * 1.5, cd = 1, range = CFG.portal.range, use = function(x)
if not x.pos then return notify("Нет точки для прыжка", C.warn) end
fx.bolt(x.root.Position, x.pos, RGB(180, 90, 255), .3, .3)
RM.teleport(x.pos + (x.nrm or V3(0, 1, 0)) * 3, math.atan2(-x.d.X, -x.d.Z))
end })
RM.regGadget({ id = "portal3", name = "Пустотный раскрыватель", icon = "🕳", desc = "Открывает пару: портал рядом с тобой и портал в цель", style = "pistol", col = RGB(30, 30, 40), acc = RGB(255, 60, 200),
cost = CFG.cost.portal * 2, cd = 1.5, range = CFG.portal.range, use = function(x)
local fwd = x.root.CFrame.LookVector
local near = x.root.Position + V3(fwd.X, 0, fwd.Z).Unit * 7
RM.portalOpen("A", near, -V3(fwd.X, 0, fwd.Z).Unit, pcol())
placeAt(x, "B")
notify("Пара порталов открыта", pcol(), 1.5)
end })
end
do
local C, M, fx, U = RM.C, RM.M, RM.fx, RM.U
local S = { m = nil, cf = nil, speed = 0, auto = false, route = nil, ri = 1, rec = nil, landing = false, hyperAt = 0, fireAt = 0, on = false, vel = V3() }
RM.ship = S
RM.exitFns = {}
local shipF = folder("Ship")
local ENG = {}
local function build(cf)
local m = I("Model", { Name = "Cruiser" }, shipF)
local hull = M.cyl(m, "Hull", 2.3, 13, CF() * ANG(pi / 2, 0, 0), RGB(190, 200, 215), Enum.Material.Metal)
m.PrimaryPart = hull
M.skin(hull, "ship")
M.ball(m, "Nose", 4.6, CF(0, 0, -6.5), RGB(190, 200, 215), Enum.Material.Metal)
M.ball(m, "Cockpit", 3.6, CF(0, 1.5, -2.8), RGB(120, 230, 255), Enum.Material.Glass, { Transparency = .45 })
M.part(m, "Stripe", V3(.3, .1, 12), CF(0, 2.28, 0), RGB(80, 255, 140), Enum.Material.Neon)
for _, s in ipairs({ -1, 1 }) do
M.part(m, "Wing", V3(7, .35, 4.5), CF(s * 4.6, -.4, 2) * ANG(0, -s * .3, s * .08), RGB(150, 160, 180), Enum.Material.Metal)
M.part(m, "Tip", V3(.4, .5, 4), CF(s * 8, -.4, 2.4), RGB(80, 255, 140), Enum.Material.Neon)
local e = M.cyl(m, "Engine", .9, 3, CF(s * 2.7, -.3, 5.8) * ANG(pi / 2, 0, 0), RGB(90, 95, 110), Enum.Material.Metal)
local g = M.cyl(m, "Glow", .75, .3, CF(s * 2.7, -.3, 7.4) * ANG(pi / 2, 0, 0), RGB(255, 140, 50), Enum.Material.Neon)
local em = I("ParticleEmitter", { Color = ColorSequence.new(RGB(255, 170, 60), RGB(255, 60, 20)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
Lifetime = NumberRange.new(.3, .6), Speed = NumberRange.new(14, 22), LightEmission = 1, Rate = 0, EmissionDirection = Enum.NormalId.Back,
Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, g)
ENG[#ENG + 1] = em
M.cyl(m, "Cannon", .22, 3, CF(s * 1.9, -1.4, -4.2) * ANG(pi / 2, 0, 0), RGB(60, 65, 80), Enum.Material.Metal)
end
fx.light(hull, RGB(120, 230, 255), 24, 1.5)
M.weldAll(m, hull)
M.anchorAll(m, true)
m:PivotTo(cf)
return m
end
function RM.shipSummon()
if S.on then return notify("Ты уже в корабле", C.warn) end
local _, _, r = getChar()
if not r then return end
local f = r.CFrame.LookVector
local fl = V3(f.X, 0, f.Z).Unit
local p = r.Position + fl * 22
local g = groundAt(p, 30)
p = (g or p - V3(0, 3, 0)) + V3(0, 4.5, 0)
S.cf = CFrame.lookAt(p, p - fl)
if S.m then S.m:Destroy() end
S.m = build(S.cf)
S.speed = 0
snd("ship", 1, 1.2)
fx.ring(p - V3(0, 4, 0), C.ac, 22)
notify("🚀 Корабль вызван. Сесть: кнопка «Сесть» в разделе «Корабль»", C.ac)
end
function RM.shipDismiss()
if S.on then return notify("Сначала выйди из корабля", C.warn) end
if S.m then S.m:Destroy() S.m = nil end
end
RM.cleanups[#RM.cleanups + 1] = function() S.on = false end
local savedZoom
local function seat() return S.cf * CF(0, .3, -2.8) end
function RM.shipBoard()
if not S.m then return notify("Сначала вызови корабль", C.warn) end
local _, _, r = getChar()
if not r or (r.Position - S.cf.Position).Magnitude > 60 then return notify("Подойди ближе к кораблю (до 60)", C.warn) end
local ok, why = enterMode("ship", "ship")
if not ok then return notify(why, C.warn) end
S.on, S.landing, S.speed = true, false, 0
r.Anchored = true
savedZoom = { LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance }
LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance = 24, 80
EN.drain("ship", CFG.drain.ship, function() S.landing = true notify("🪫 Нет энергии — аварийная посадка", C.dg) end)
setPivot(seat())
r.Anchored = true
snd("engine", 1, 1)
notify("🚀 В кабине. W/S — тяга, A/D — боком, Space/Ctrl — вверх/вниз, мышь/камера — курс, ЛКМ — огонь, H гипер, L посадка, R запись, P автопилот", C.ac, 7)
end
local function leave()
local _, _, r = getChar()
S.on, S.auto, S.landing = false, false, false
EN.stop("ship")
leaveMode("ship")
if savedZoom then LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance = savedZoom[1], savedZoom[2] end
for _, e in ipairs(ENG) do e.Rate = 0 end
if r then
r.Anchored = false
local side = S.cf * CF(6, -1, -2)
local g = groundAt(side.Position + V3(0, 5, 0), 20)
local dest = g and g + V3(0, 3.5, 0) or side.Position + V3(0, 6, 0)
setPivot(CF(dest))
end
notify("Ты вышел из корабля", C.dim)
end
function RM.shipReset()
if not S.on then return end
S.on, S.auto, S.landing = false, false, false
EN.stop("ship")
leaveMode("ship")
if savedZoom then LP.CameraMinZoomDistance, LP.CameraMaxZoomDistance = savedZoom[1], savedZoom[2] end
for _, e in ipairs(ENG) do e.Rate = 0 end
end
RM.exitFns.ship = function()
local g = groundAt(S.cf.Position, 4)
local alt = g and (S.cf.Position.Y - g.Y) or 99
if alt > 9 then
S.landing, S.auto = true, false
notify("🛬 Идёт посадка...", C.warn, 2)
else
leave()
end
end
function RM.exitMode()
local f = RM.exitFns[MODE.cur]
if f then f() end
end
function RM.shipHyper()
local now = os.clock()
if not S.on or now < S.hyperAt then return notify("Гипердвигатель перезаряжается", C.warn, 1.5) end
if not EN.use(CFG.cost.hyper, "гиперпрыжок") then return end
local look = S.cf.LookVector
local d = CFG.ship.hyper
local h = ray(S.cf.Position, look * (d + 12), { WORLD, LP.Character })
if h then d = max(0, h.Distance - 14) end
S.hyperAt = now + CFG.ship.hyperCd
fx.dim(RGB(120, 200, 255), 1.2)
S.cf = S.cf + look * d
S.speed = max(S.speed, 160)
snd("ship", 1, 2)
end
function RM.shipFire()
local now = os.clock()
if now < S.fireAt or not EN.use(CFG.cost.fire, "пушки") then return end
S.fireAt = now + CFG.ship.fireCd
local pos, _, inst, o, d = RM.aimHit(600)
local tgt = pos or (S.cf.Position + S.cf.LookVector * 400)
for _, s in ipairs({ -1, 1 }) do
local from = (S.cf * CF(s * 1.9, -1.4, -6)).Position
fx.bolt(from, tgt, RGB(255, 230, 80), .4, .25)
end
snd("shoot", 1, .8)
if pos then
fx.spark(pos, RGB(255, 200, 60), 14)
if inst then RM.hurt(inst, 35, pos) end
end
end
function RM.shipAuto(pts, name)
if not S.on then return notify("Автопилот работает только в корабле", C.warn) end
if not pts or #pts < 1 then return end
S.route, S.ri, S.auto, S.rname, S.landing = pts, 1, true, name or "точка", false
notify("🤖 Автопилот: " .. (name or "точка"), C.ac)
end
function RM.shipRec(on)
if not S.on then return notify("Запись только в корабле", C.warn) end
if on == nil then on = not S.rec end
if on then
S.rec = { S.cf.Position }
notify("⏺ Запись маршрута", C.dg)
elseif S.rec then
local pts = S.rec
S.rec = nil
if #pts < 2 then return notify("Маршрут слишком короткий", C.warn) end
if #SAVE.routes >= CFG.limit.routes then return notify("Лимит маршрутов: " .. CFG.limit.routes, C.warn) end
