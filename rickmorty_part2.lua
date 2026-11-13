local t = {}
for _, p in ipairs(pts) do t[#t + 1] = { x = p.X, y = p.Y, z = p.Z } end
SAVE.routes[#SAVE.routes + 1] = { name = "Маршрут " .. (#SAVE.routes + 1), pts = t }
notify("💾 Маршрут сохранён (" .. #pts .. " точек)", C.ok)
if RM.refreshRoutes then RM.refreshRoutes() end
end
end
function RM.routePts(r)
local o = {}
for _, p in ipairs(r.pts) do o[#o + 1] = V3(p.x, p.y, p.z) end
return o
end
RM.bindKey("H", function() if S.on then RM.shipHyper() end end)
RM.bindKey("L", function() if S.on then RM.exitFns.ship() end end)
RM.bindKey("R", function() if S.on then RM.shipRec() end end)
RM.bindKey("P", function() if S.on then if S.auto then S.auto = false notify("Автопилот выключен", C.dim) elseif S.route then S.auto = true end end end)
RM.mobCreate("sfire", "💥", .86, .62, 74, nil, nil, function() return MODE.cur == "ship" end)
RM.mobCreate("hyper", "🚀", .72, .66, 56, function() RM.shipHyper() end, nil, function() return MODE.cur == "ship" end)
RM.mobCreate("land", "🛬", .72, .5, 52, function() if S.on then RM.exitFns.ship() end end, nil, function() return MODE.cur == "ship" end)
local hud = I("TextLabel", { Size = UDim2.fromOffset(360, 26), AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 14), BackgroundColor3 = C.bg, BackgroundTransparency = .25,
TextColor3 = C.ac, Font = Enum.Font.GothamBold, TextSize = 12, Visible = false, ZIndex = 40, Text = "" }, RM.gui)
U.corner(hud, 8)
RM.ticks.ship = function(dt, now)
if not S.on then return end
local c, h, r = getChar()
if not (r and S.m and S.m.Parent) or (h and h.Health <= 0) then return leave() end
local c0 = cam()
local look = S.cf.LookVector
local want
local fwd, strafe = 0, 0
if S.auto and S.route then
local tp = S.route[S.ri]
local d = tp - S.cf.Position
if d.Magnitude < 20 then
S.ri = S.ri + 1
if S.ri > #S.route then
S.auto = false
notify("🤖 Автопилот: точка достигнута", C.ok)
end
else
want = d.Unit
fwd = 1
end
elseif S.landing then
want = V3(look.X, 0, look.Z).Unit
else
want = c0 and c0.CFrame.LookVector or look
local md = h and h.MoveDirection or V3()
local cl = c0 and V3(c0.CFrame.LookVector.X, 0, c0.CFrame.LookVector.Z) or V3(0, 0, -1)
if cl.Magnitude > .01 then
cl = cl.Unit
fwd = md:Dot(cl)
strafe = md:Dot(V3(-cl.Z, 0, cl.X))
end
end
if want and want.Magnitude > .01 then look = look:Lerp(want.Unit, min(1, dt * 3)).Unit end
local cruise = ST.shipSpeed
if fwd > .25 then S.speed = min(cruise, S.speed + 120 * dt)
elseif fwd < -.25 then S.speed = max(0, S.speed - 160 * dt)
elseif S.landing then S.speed = max(0, S.speed - 90 * dt) end
local up = RM.vertical() * 40
if S.landing then up = -35 end
local right = look:Cross(V3(0, 1, 0))
if right.Magnitude < .01 then right = V3(1, 0, 0) end
right = right.Unit
local vel = look * S.speed + right * strafe * 40 + V3(0, up, 0)
local step = vel * dt
local pos = S.cf.Position
if step.Magnitude > .001 then
local hit = ray(pos, step.Unit * (step.Magnitude + 6), { WORLD, c })
if hit and hit.Distance < step.Magnitude + 5 then
if S.landing and hit.Normal.Y > .6 and S.speed < 25 then
pos = hit.Position + V3(0, 3.6, 0)
S.speed = 0
S.cf = CFrame.lookAt(pos, pos + look)
S.m:PivotTo(S.cf)
r.CFrame = seat()
return leave()
end
if S.speed > 40 then
fx.spark(hit.Position, RGB(255, 180, 60), 12)
snd("exp", .6, 1.2)
end
pos = hit.Position + hit.Normal * 5
S.speed = S.speed * .2
else
pos = pos + step
end
end
if S.landing and S.speed < 2 then
local g = groundAt(pos, 2)
if g and pos.Y - g.Y < 4.5 then
S.cf = CFrame.lookAt(pos, pos + look)
return leave()
end
end
S.cf = CFrame.lookAt(pos, pos + look) * ANG(0, 0, -strafe * .25)
S.m:PivotTo(S.cf)
r.CFrame = seat()
r.AssemblyLinearVelocity = V3()
local rate = clamp(S.speed / 8, 0, 50) * Q().pr
for _, e in ipairs(ENG) do e.Rate = rate end
if S.rec and (pos - S.rec[#S.rec]).Magnitude > 25 and #S.rec < 300 then S.rec[#S.rec + 1] = pos end
if (UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not RM.win.Visible) or RM.mobHeld("sfire") or UIS:IsKeyDown(Enum.KeyCode.F) then RM.shipFire() end
local g = groundAt(pos, 2)
hud.Visible = ST.hudShip
hud.Text = string.format("🚀 %d  ⛰ %d  ⚡ %d  %s%s%s", floor(S.speed), floor(g and pos.Y - g.Y or 0), floor(EN.v), now < S.hyperAt and "гипер: " .. floor(S.hyperAt - now) .. "с " or "гипер ✓ ",
S.auto and ("🤖 " .. (S.rname or "")) or "", S.rec and " ⏺" or "")
end
RM.ticks.shipHud = function()
if not S.on and hud.Visible then hud.Visible = false end
end
end
do
local C, M, fx = RM.C, RM.M, RM.fx
local UN = RM.units
local unitF = folder("Units")
RM.stats = { kills = 0 }
RM.rcmd = "follow"
local goTo
local MATN, MATM = Enum.Material.Neon, Enum.Material.Metal
local rnd = math.random
local function front(d)
local _, _, r = getChar()
if not r then return nil end
local l = r.CFrame.LookVector
local p = r.Position + V3(l.X, 0, l.Z).Unit * (d or 10) + V3(rnd(-3, 3), 0, rnd(-3, 3))
local g = groundAt(p, 30)
return (g or p - V3(0, 3, 0)) + V3(0, 3.3, 0)
end
local function flash(col)
local f = I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BackgroundTransparency = .6, ZIndex = 150, BorderSizePixel = 0 }, RM.gui)
tw(f, .5, { BackgroundTransparency = 1 })
later(.55, function() f:Destroy() end)
end
RM.flash = flash
local DROPS = { "gear", "chip", "battery", "wire" }
local SYNC
local function unit(spec: any): any
local pos = spec.pos or front(10)
if not pos then return nil end
local rig = M.rig(spec.rig)
local m = rig.model
m.Parent = unitF
m:PivotTo(CF(pos))
local hp = spec.hp or 100
local u = { model = m, root = rig.hrp, hum = rig.hum, rig = rig, hp = hp, max = hp, kind = spec.kind, ai = spec.ai, team = spec.team or "friend", name = spec.name or "?",
dmg = spec.dmg or 0, range = spec.range or 0, acd = spec.acd or .9, cd = 0, say = spec.say or {}, spd = spec.speed or 14, t0 = os.clock(), life = spec.life, home = pos, think = 0, next = 0, atk = 0, aggro = spec.aggro or 70, lastDrop = os.clock(), col = spec.col }
rig.hum.WalkSpeed = u.spd
local bb = I("BillboardGui", { Size = UDim2.fromOffset(60, 7), StudsOffset = V3(0, 3 * (spec.rig.scale or 1) + 1, 0), AlwaysOnTop = true, MaxDistance = 90, Adornee = rig.head }, m)
local bg = I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0 }, bb)
u.fill = I("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ok, BorderSizePixel = 0 }, bg)
UN[m] = u
function u.talk(t) fx.bubble(rig.head, t or u.say[rnd(math.max(1, #u.say))] or "...", 3) end
function u.destroy()
UN[m] = nil
EN.bonus[u] = nil
if m.Parent then m:Destroy() end
end
function u.die(quiet)
if not UN[m] then return end
local p = u.root.Position
entDel(u.kind, u)
u.destroy()
SYNC()
if not quiet then
fx.spark(p, u.team == "enemy" and RGB(255, 90, 60) or C.ac, 30)
snd("exp", .7, 1.3)
if u.team == "enemy" then
RM.stats.kills = RM.stats.kills + 1
if rnd() < .5 then RM.addComp(DROPS[rnd(#DROPS)]) notify("🔩 Выпал компонент", C.ok, 1.5) end
end
end
end
function u.hurt(a, p)
if not UN[m] then return end
u.hp = u.hp - max(0, a)
u.fill.Size = UDim2.fromScale(clamp(u.hp / u.max, 0, 1), 1)
u.fill.BackgroundColor3 = u.hp / u.max < .35 and C.dg or C.ok
if p then fx.spark(p, RGB(255, 200, 120), 6) end
fx.pulse(rig.torso, .2, RGB(255, 80, 80))
if u.hp <= 0 then u.die() end
end
entAdd(u.kind, u)
fx.spark(pos, C.ac, 16)
return u
end
RM.unit = unit
local function enemyNear(u, r)
local best, bd = nil, r
for _, o in pairs(UN) do
if o.team == "enemy" and o.root.Parent and o ~= u then
local d = (o.root.Position - u.root.Position).Magnitude
if d < bd then best, bd = o, d end
end
end
return best, bd
end
local function attack(u, e, now)
u.cd, u.atk = now + u.acd, 1
local a, b = u.root.Position + V3(0, 1.5, 0), e.root.Position
if u.range > 10 then
fx.bolt(a, b, u.col or RGB(255, 90, 90), .2, .2)
snd("shoot", .5, 1.3)
else
fx.spark(b, RGB(255, 255, 255), 6)
end
e.hurt(u.dmg * (u.fr and 1 + u.fr or 1), b)
end
local function follow(u, pp)
if RM.rcmd == "stay" then return end
local d = (pp - u.root.Position).Magnitude
u.hum.WalkSpeed = d > 28 and u.spd * 1.7 or u.spd
if d > 12 then u.hum:MoveTo(pp + (u.root.Position - pp).Unit * 7) elseif d < 5 then u.hum:MoveTo(u.root.Position) end
if d > 160 then u.root.CFrame = CF(pp + V3(4, 2, 0)) end
u.emo = d < 14 and rnd() < .15 and "happy" or nil
end
local AI = {}
local function fight(u, pp, now)
if goTo and now < goTo.t then u.hum:MoveTo(goTo.pos) return end
local e, d = enemyNear(u, u.aggro)
if e and RM.rcmd ~= "stay" then
u.emo = "angry"
if d > max(u.range * .7, 4) then u.hum:MoveTo(e.root.Position) else u.hum:MoveTo(u.root.Position) end
if d <= max(u.range, 6) and now >= u.cd then attack(u, e, now) end
return true
end
follow(u, pp)
end
AI.guard = fight
AI.scout = function(u, pp, now)
local e = enemyNear(u, 110)
if e and not e.marked then
e.marked = true
fx.highlight(e.model, RGB(255, 80, 80), 6)
later(6, function() e.marked = nil end)
u.talk("Цель обнаружена!")
end
follow(u, pp)
end
AI.helper = function(u, pp, now)
follow(u, pp)
if now - u.lastDrop > 25 then
u.lastDrop = now
RM.addComp(DROPS[rnd(#DROPS)])
u.talk("Нашёл деталь!")
end
end
AI.battery = function(u, pp) follow(u, pp) end
AI.mee = function(u, pp, now)
u.fr = clamp((now - u.t0) / u.life, 0, 1)
u.emo = u.fr < .4 and "happy" or (u.fr < .75 and "angry" or "crazy")
if u.fr > .5 and not u.said1 then u.said1 = true u.talk("Почему так долго?!") end
if u.fr > .85 and not u.said2 then u.said2 = true u.talk("Я ХОЧУ ИСЧЕЗНУТЬ!!!") end
local e = enemyNear(u, 80)
if e then
u.hum.WalkSpeed = 26
u.hum:MoveTo(e.root.Position)
if (e.root.Position - u.root.Position).Magnitude < 6 and now >= u.cd then attack(u, e, now) end
else follow(u, pp) end
end
AI.npc = function(u, pp, now)
local d = (pp - u.root.Position).Magnitude
if d < 12 then
u.emo = "happy"
u.hum:MoveTo(u.root.Position)
if not u.greeted or now - u.greeted > 14 then u.greeted = now u.talk() end
else
u.emo = nil
if now > u.next then
u.next = now + 3 + rnd() * 4
u.hum:MoveTo(u.home + V3(rnd(-20, 20), 0, rnd(-20, 20)))
end
end
end
AI.monster = function(u, pp, now)
local tgt, td = nil, 90
local _, _, r = getChar()
if ST.hostile and r then tgt, td = r, (r.Position - u.root.Position).Magnitude end
for _, o in pairs(UN) do
if o.team == "friend" and o.root.Parent then
local dd = (o.root.Position - u.root.Position).Magnitude
if dd < td then tgt, td = o, dd end
end
end
if tgt and td < 90 then
u.emo = "angry"
local tp = tgt.Position or tgt.root.Position
u.hum:MoveTo(tp)
if td < 6 and now >= u.cd then
u.cd, u.atk = now + 1.3, 1
if tgt == r then
if RM.shieldAbsorb and RM.shieldAbsorb(u.dmg, u.root.Position) then return end
r.AssemblyLinearVelocity = ((r.Position - u.root.Position) * V3(1, 0, 1)).Unit * 55 + V3(0, 28, 0)
flash(RGB(255, 40, 40))
snd("exp", .7, .7)
else tgt.hurt(u.dmg, tp) end
end
else u.emo = nil AI.npc(u, pp, now) end
end
AI.dummy = function() end
RM.ticks.units = function(dt, now)
if next(UN) == nil then return end
local _, _, pr = getChar()
local pp = pr and pr.Position or V3()
for m, u in pairs(UN) do
if not (m.Parent and u.root.Parent) then
UN[m] = nil
else
if not u.frozen then
u.think = (u.think or 1) - dt
if u.think <= 0 then
u.think = .25 + rnd() * .1
local f = AI[u.ai]
if f then safe("ИИ " .. u.name, f, u, pp, now) end
end
u.atk = max(0, (u.atk or 0) - dt * 3)
local v = u.root.AssemblyLinearVelocity
if u.rig then M.anim(u.rig, dt, V3(v.X, 0, v.Z).Magnitude, { e = u.emo, atk = u.atk }) end
end
if u.life and now - u.t0 > u.life then
if u.ai == "mee" then
fx.spark(u.root.Position, RGB(90, 190, 235), 40)
u.talk("Пуф!")
end
u.die(true)
end
end
end
end
local function eyes(rig: any, col)
for _, s in ipairs({ -1, 1 }) do M.ball(rig.head, "Eye", .35 * rig.s, rig.head.CFrame * CF(s * .3 * rig.s, .1 * rig.s, -.45 * rig.s), col, MATN) end
for _, p in ipairs(rig.head:GetChildren()) do if p:IsA("BasePart") then weld(rig.head, p, p) end end
end
local RT = {
guard = { "Охранный робот", RGB(120, 130, 150), RGB(255, 70, 70), "guard", 120, 14, 22, 45, 16, { "Угроза устранена.", "Охраняю.", "Периметр чист." } },
helper = { "Робот-помощник", RGB(200, 200, 210), RGB(80, 230, 255), "helper", 80, 12, 0, 0, 0, { "Передай мне ключ!", "Чем помочь?", "Ищу детали." } },
scout = { "Разведчик", RGB(70, 80, 100), RGB(255, 220, 60), "scout", 60, 24, 0, 0, 0, { "Вижу цель.", "Разведка!", "Тихо." } },
battery = { "Робот-батарея", RGB(70, 110, 70), RGB(120, 255, 100), "battery", 100, 12, 0, 0, 0, { "Заряжаю.", "Энергия +", "Держись рядом." } },
}
RM.RT = RT
SYNC = function()
local n = entCount("robots")
if n > 0 then EN.drain("robots", n * CFG.drain.robot, function() entClear("robots") notify("🪫 Роботы отключены: нет энергии", C.dg) end) else EN.stop("robots") end
end
function RM.spawnRobot(k)
local d = RT[k]
if not d or not canAdd("robots", CFG.limit.robots) or not EN.use(CFG.cost.robot, "робот") then return end
local u = unit({ kind = "robots", ai = d[4], name = d[1], hp = d[5], speed = d[6], range = d[7], dmg = d[8], say = d[10], aggro = 70,
rig = { name = d[1], skin = d[2], shirt = d[2], sleeve = d[2], pants = d[2]:Lerp(RGB(0, 0, 0), .4), head = "box", extras = function(rig) eyes(rig, d[3])
M.part(rig.torso, "Core", V3(1, 1, .2) * rig.s, rig.torso.CFrame * CF(0, .2, -.55), d[3], MATN) weld(rig.torso, rig.torso:FindFirstChild("Core"), rig.torso)
M.cyl(rig.head, "Ant", .06, 1, rig.head.CFrame * CF(0, 1, 0), d[2], MATM) weld(rig.head, rig.head:FindFirstChild("Ant"), rig.head) end } })
if not u then return end
u.col = d[3]
if k == "battery" then EN.bonus[u] = 1.2 end
SYNC()
u.talk("Активирован.")
snd("robot", 1, 1)
end
function RM.spawnMeeseeks()
if not canAdd("meeseeks", CFG.limit.meeseeks) or not EN.use(CFG.cost.meeseeks, "Мисикс") then return end
local B = RGB(90, 190, 235)
local u = unit({ kind = "meeseeks", ai = "mee", name = "Мистер Мисикс", hp = 60, speed = 18, dmg = 14, acd = .6, life = 45, say = { "Смотрите на меня!", "Я Мистер Мисикс!" },
rig = { name = "Мисикс", skin = B, shirt = B, sleeve = B, pants = B, head = "human", extras = function(rig) eyes(rig, RGB(255, 255, 255)) end } })
if u then u.talk() snd("portal", .8, 1.8) end
end
local NT = {
{ "Учёный", RGB(238, 205, 170), RGB(245, 245, 250), RGB(90, 90, 100), "npc", "friend", 80, { "Эксперимент удался!", "Наука требует жертв." } },
{ "Охранник", RGB(220, 180, 150), RGB(40, 60, 110), RGB(30, 40, 70), "npc", "friend", 120, { "Проходите.", "Всё спокойно." } },
{ "Торговец", RGB(200, 150, 110), RGB(130, 90, 50), RGB(70, 50, 30), "npc", "friend", 80, { "Лучшие цены в мультивселенной!", "Гаджеты не нужны?" } },
{ "Путешественник", RGB(240, 210, 180), RGB(60, 130, 80), RGB(60, 70, 60), "npc", "friend", 80, { "Я из другого измерения.", "Тут красиво." } },
{ "Гость", RGB(230, 190, 160), RGB(200, 90, 150), RGB(70, 70, 130), "npc", "friend", 80, { "Привет!", "Где тут выход?" } },
{ "Монстр", RGB(120, 160, 90), RGB(90, 120, 60), RGB(70, 90, 50), "monster", "enemy", 200, { "Ргааа!", "Грр..." }, 1.4 },
}
RM.NT = NT
function RM.spawnNPC(i)
local t = NT[i]
if not t or not canAdd("npcs", CFG.limit.npcs) or not EN.use(CFG.cost.npc, "NPC") then return end
local u = unit({ kind = "npcs", ai = t[5], team = t[6], name = t[1], hp = t[7], say = t[8], dmg = 15, speed = t[6] == "enemy" and 15 or 10,
rig = { name = t[1], skin = t[2], shirt = t[3], pants = t[4], scale = t[9] or 1, fabric = true, extras = function(rig) eyes(rig, RGB(20, 20, 20)) end } })
if u then u.talk() end
end
function RM.spawnDummy()
if not canAdd("dummies", CFG.limit.dummies) then return end
unit({ kind = "dummies", ai = "dummy", team = "enemy", name = "Мишень", hp = 120, speed = 0,
rig = { name = "Мишень", skin = RGB(230, 230, 230), shirt = RGB(230, 60, 60), pants = RGB(230, 230, 230), head = "ball", extras = function(rig)
local t = M.cyl(rig.torso, "Target", 1, .1, rig.torso.CFrame * CF(0, 0, -.55) * ANG(pi / 2, 0, 0), RGB(255, 255, 255), MATM)
weld(rig.torso, t, t)
end } })
end
function RM.cloneMe()
local c = LP.Character
if not c or not canAdd("npcs", CFG.limit.npcs) or not EN.use(CFG.cost.npc * 3, "клон") then return end
local function col(n, d) local p = c:FindFirstChild(n) return p and p:IsA("BasePart") and p.Color or d end
local u = unit({ kind = "npcs", ai = "guard", name = "Клон " .. LP.DisplayName, hp = 100, range = 20, dmg = 12, say = { "Я — это ты.", "Мы одно целое." }, speed = 16, col = C.ac,
rig = { name = "Клон", skin = col("Head", RGB(238, 205, 170)), shirt = col("UpperTorso", col("Torso", C.dim)), pants = col("LowerTorso", col("Left Leg", C.dim)), extras = function(rig) eyes(rig, RGB(20, 20, 20)) end } })
if u then u.talk() end
end
function RM.clearUnits(k)
entClear(k)
SYNC()
end
function RM.setCmd(c)
RM.rcmd = c
notify("🎮 Команда роботам: " .. c, C.ac, 1.5)
end
RM.regGadget({ id = "remote", name = "Пульт роботов", icon = "🎮", desc = "Послать роботов в точку (8 с)", style = "box", col = RGB(50, 60, 80), acc = RGB(80, 230, 255), cost = 0, cd = .8, use = function(x)
if x.pos then
goTo = { pos = x.pos, t = os.clock() + 8 }
fx.ring(x.pos, RGB(80, 230, 255), 8, x.nrm)
snd("robot", 1, 1.3)
end
end })
RM.regGadget({ id = "meebox", name = "Коробка Мисикс", icon = "📦", desc = "Вызывает Мистера Мисикса на 45 с", style = "box", col = RGB(90, 190, 235), acc = RGB(255, 255, 255), cost = 0, cd = 1.5, use = function() RM.spawnMeeseeks() end })
RM.regGadget({ id = "cloner", name = "Клон-машина", icon = "🧬", desc = "Создаёт твою боевую копию", style = "box", col = RGB(60, 90, 70), acc = RGB(120, 255, 160), cost = 0, cd = 2, use = function() RM.cloneMe() end })
RM.regGadget({ id = "analyzer", name = "Анализатор", icon = "🔬", desc = "Показывает данные цели под прицелом", style = "box", col = RGB(40, 60, 70), acc = RGB(255, 255, 120), cost = 1, cd = .6, use = function(x)
local o = x.inst
while o and o ~= WORLD and o ~= Workspace do
local u = UN[o]
if u then
fx.highlight(o, RGB(255, 255, 120), 2.5)
return notify(string.format("🔬 %s | HP %d/%d | %s | эмоция: %s", u.name, floor(u.hp), floor(u.max), u.team == "enemy" and "враг" or "союзник", u.emo or "спокойно"), C.ac, 4)
end
local pl = o:IsA("Model") and Players:GetPlayerFromCharacter(o)
if pl then return notify("🔬 Игрок: " .. pl.DisplayName, C.ac, 3) end
o = o.Parent
end
notify("🔬 Объект: " .. (x.inst and x.inst.Name or "ничего"), C.dim, 2)
end })
end
do
local C, M, fx = RM.C, RM.M, RM.fx
local UN = RM.units
local cloneF = folder("Clones")
local rec, recT = {}, 0
local function playingIds(ch)
local ids = {}
local h = ch and ch:FindFirstChildOfClass("Humanoid")
local an = h and h:FindFirstChildOfClass("Animator")
if an then
for _, t in ipairs(an:GetPlayingAnimationTracks()) do
local id = t.Animation and t.Animation.AnimationId
if id and id ~= "" then ids[#ids + 1] = id end
end
end
return ids
end
RM.ticks.echoRec = function(dt, now)
if entCount("echo") == 0 then
if #rec > 0 then rec = {} end
return
end
recT = recT + dt
if recT < .1 then return end
recT = 0
local c, _, r = getChar()
if not r then return end
rec[#rec + 1] = { t = now, cf = r.CFrame, ids = playingIds(c) }
if #rec > 130 then table.remove(rec, 1) end
end
local function sampleAt(t)
local best = rec[1]
for i = #rec, 1, -1 do
if rec[i].t <= t then return rec[i] end
end
return best
end
local function stripScripts(m)
for _, d in ipairs(m:GetDescendants()) do
if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("BillboardGui") or d:IsA("ForceField") then d:Destroy() end
end
end
local function ghostClone(color)
local c = LP.Character
if not c then return nil end
local was = c.Archivable
c.Archivable = true
local m = c:Clone()
c.Archivable = was
if not m then return nil end
stripScripts(m)
local h = m:FindFirstChildOfClass("Humanoid")
if not h then m:Destroy() return nil end
h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
for _, p in ipairs(parts(m)) do
p.Anchored = p.Name == "HumanoidRootPart"
p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
end
I("Highlight", { FillColor = color, OutlineColor = color, FillTransparency = .55, DepthMode = Enum.HighlightDepthMode.Occluded }, m)
m.Parent = cloneF
return m, h
end
function RM.spawnEcho()
if not canAdd("echo", CFG.limit.echo) or not EN.use(CFG.cost.echo, "эхо") then return end
local idx = entCount("echo") + 1
local col = PCOL[(idx * 2) % #PCOL + 1][2]
local m, h = ghostClone(col)
if not m then return end
m.Name = "Echo" .. idx
local r = m:FindFirstChild("HumanoidRootPart")
local an = h:FindFirstChildOfClass("Animator") or I("Animator", nil, h)
local e = { m = m, delay = 1.2 * idx, tracks = {}, t0 = os.clock() }
function e.destroy(s) if s.m.Parent then s.m:Destroy() end end
e.step = function(now)
local s = sampleAt(now - e.delay)
if not (s and r and r.Parent) then return end
r.CFrame = s.cf
local want = {}
for _, id in ipairs(s.ids) do want[id] = true end
for id, tr in pairs(e.tracks) do
if not want[id] then
tr:Stop(.1)
e.tracks[id] = nil
end
end
for id in pairs(want) do
if not e.tracks[id] then
local a = I("Animation", { AnimationId = id })
local ok, tr = pcall(function() return an:LoadAnimation(a) end)
if ok and tr then
tr.Looped = true
tr:Play(.1)
e.tracks[id] = tr
end
end
end
end
entAdd("echo", e)
snd("holo", 1, 1.2)
fx.spark(r.Position, col, 20)
later(25, function()
entDel("echo", e)
e:destroy()
end)
end
RM.ticks.echo = function(dt, now)
for _, e in ipairs(RM.ents.echo or {}) do
if e.m.Parent then e.step(now) end
end
end
function RM.spawnHolo()
if not canAdd("holo", CFG.limit.holo) or not EN.use(CFG.cost.holo, "голограмма") then return end
local pos, nrm = RM.aimHit(120)
local c, _, r = getChar()
if not (r and c) then return end
pos = pos and pos + V3(0, 3.2, 0) or r.Position + r.CFrame.LookVector * 10
local col = RGB(80, 200, 255)
local m = ghostClone(col)
if not m then return end
m.Name = "Hologram"
local hr = m:FindFirstChild("HumanoidRootPart")
hr.CFrame = CFrame.lookAt(pos, V3(r.Position.X, pos.Y, r.Position.Z))
for _, p in ipairs(parts(m)) do
if p.Name ~= "HumanoidRootPart" then
p.Material = Enum.Material.Neon
p.Transparency = clamp(p.Transparency, .35, 1)
end
end
local u = { model = m, root = hr, hp = 60, max = 60, team = "friend", name = "Голограмма", kind = "holo", t0 = os.clock() }
function u.hurt(a, p)
u.hp = u.hp - a
fx.spark(hr.Position, col, 8)
if u.hp <= 0 then u.die() end
end
function u.destroy() UN[m] = nil EN.stop("holo" .. tostring(m)) if m.Parent then m:Destroy() end end
function u.die()
entDel("holo", u)
u.destroy()
end
UN[m] = u
entAdd("holo", u)
EN.drain("holo" .. tostring(m), CFG.drain.holo, function() u.die() end)
fx.light(hr, col, 14, 1.5)
fx.ring(pos - V3(0, 3, 0), col, 10, V3(0, 1, 0))
snd("holo", 1, 1)
later(CFG.holo.time, function() if UN[m] then u.die() end end)
end
RM.ticks.holo = function(dt, now)
for _, u in ipairs(RM.ents.holo or {}) do
local flick = .4 + math.random() * .25
for _, p in ipairs(u.model:GetChildren()) do
if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 then p.Transparency = flick end
end
end
end
local frozenUnits, frozenTracks, freezeUntil = {}, {}, 0
local function unfreeze()
for _, u in ipairs(frozenUnits) do
if u.root and u.root.Parent then u.root.Anchored = false end
u.frozen = nil
end
for _, t in ipairs(frozenTracks) do pcall(function() t:AdjustSpeed(1) end) end
frozenUnits, frozenTracks, freezeUntil = {}, {}, 0
fx.tint(false)
RM.timeStopped = false
notify("⏱ Время пошло снова", C.dim, 1.5)
end
function RM.timeStop()
if RM.timeStopped then return end
if not EN.use(CFG.cost.freeze, "остановка времени") then return end
local _, _, r = getChar()
if not r then return end
RM.timeStopped = true
freezeUntil = os.clock() + CFG.freeze.time
fx.tint(true)
fx.ring(r.Position, RGB(180, 200, 255), CFG.freeze.r * 2)
snd("holo", 1, .5)
for m, u in pairs(UN) do
if u.kind ~= "holo" and u.root.Parent and (u.root.Position - r.Position).Magnitude < CFG.freeze.r then
u.root.Anchored, u.frozen = true, true
frozenUnits[#frozenUnits + 1] = u
end
end
for _, pl in ipairs(Players:GetPlayers()) do
local ch = pl.Character
local pr = ch and ch:FindFirstChild("HumanoidRootPart")
if pl ~= LP and pr and (pr.Position - r.Position).Magnitude < CFG.freeze.r then
local h = ch:FindFirstChildOfClass("Humanoid")
local an = h and h:FindFirstChildOfClass("Animator")
if an then
for _, t in ipairs(an:GetPlayingAnimationTracks()) do
t:AdjustSpeed(0)
frozenTracks[#frozenTracks + 1] = t
end
end
end
end
notify("⏱ Время остановлено на " .. CFG.freeze.time .. " с (визуально, на твоём клиенте)", RGB(180, 200, 255), 3)
end
RM.ticks.timeStop = function(dt, now)
if RM.timeStopped and now > freezeUntil then unfreeze() end
end
RM.cleanups[#RM.cleanups + 1] = function() if RM.timeStopped then pcall(unfreeze) end end
RM.regGadget({ id = "echo", name = "Эхо-проектор", icon = "👥", desc = "Эхо-клон повторяет твой путь и анимации с задержкой (25 с)", style = "box", col = RGB(60, 60, 90), acc = RGB(180, 120, 255), cost = 0, cd = 1.5, use = function() RM.spawnEcho() end })
RM.regGadget({ id = "holo", name = "Проектор голограмм", icon = "🪞", desc = "Голограмма-приманка: враги атакуют её", style = "box", col = RGB(40, 70, 90), acc = RGB(80, 200, 255), cost = 0, cd = 1.5, use = function() RM.spawnHolo() end })
RM.regGadget({ id = "chrono", name = "Хроно-жезл", icon = "⏱", desc = "Остановка времени (визуально)", style = "wand", col = RGB(90, 90, 110), acc = RGB(180, 200, 255), cost = 0, cd = 2, use = function() RM.timeStop() end })
end
do
local C, M, fx, U = RM.C, RM.M, RM.fx, RM.U
local MN, MM = Enum.Material.Neon, Enum.Material.Metal
local UN = RM.units
local fxF = folder("Flight")
local function tinyHud(y)
local l = I("TextLabel", { Size = UDim2.fromOffset(240, 22), AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, y), BackgroundColor3 = C.bg, BackgroundTransparency = .25,
TextColor3 = C.warn, Font = Enum.Font.GothamBold, TextSize = 12, Visible = false, ZIndex = 40 }, RM.gui)
U.corner(l, 8)
return l
end
local J = { on = false, fuel = CFG.jet.fuel, pack = nil, ws = 16, fl = {}, hud = tinyHud(46) }
RM.jet = J
function RM.jetToggle(on)
if on == nil then on = not J.on end
if on == J.on then return end
local c, h = getChar()
if not (c and h) then return end
if on then
local ok, why = enterMode("jet", "jet")
if not ok then return notify(why, C.warn) end
local t = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
if not t then return leaveMode("jet") end
local pk = I("Model", { Name = "RM_Jet" }, c)
local body = M.part(pk, "Body", V3(1.7, 2, .8), t.CFrame * CF(0, 0, .9), RGB(80, 90, 110), MM)
weld(t, body, body)
for _, s in ipairs({ -1, 1 }) do
local n = M.cyl(pk, "N", .32, .7, t.CFrame * CF(s * .5, -1.3, .9), RGB(200, 200, 210), MM)
weld(t, n, n)
local e = I("ParticleEmitter", { Color = ColorSequence.new(RGB(255, 200, 80), RGB(255, 70, 20)), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, .8), NumberSequenceKeypoint.new(1, 0) }),
Lifetime = NumberRange.new(.25, .5), Speed = NumberRange.new(10, 16), LightEmission = 1, Rate = 0, EmissionDirection = Enum.NormalId.Bottom,
Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, n)
J.fl[#J.fl + 1] = e
end
J.pack, J.ws, J.on = pk, h.WalkSpeed, true
notify("🔥 Ранец включён: Space/E/▲ — тяга, Ctrl/Q/▼ — снижение", C.ac, 4)
else
J.on = false
EN.stop("jet")
if J.pack then J.pack:Destroy() end
J.pack, J.fl = nil, {}
h.WalkSpeed = J.ws
leaveMode("jet")
J.hud.Visible = false
notify("Ранец выключен", C.dim)
end
end
RM.ticks.jet = function(dt)
if not J.on then return end
local _, h, r = getChar()
if not (h and r) or h.Health <= 0 then return RM.jetToggle(false) end
local up = RM.vertical()
local air = h.FloorMaterial == Enum.Material.Air
local thr = up > 0 and J.fuel > 0 and EN.v > 1
local v = r.AssemblyLinearVelocity
if thr then
J.fuel = max(0, J.fuel - CFG.jet.burn * dt)
r.AssemblyLinearVelocity = V3(v.X, lerp(v.Y, CFG.jet.fly, min(1, dt * 5)), v.Z)
if not EN.drains.jet then EN.drain("jet", CFG.drain.jet, function() end) end
else
EN.stop("jet")
if air and J.fuel > 0 and v.Y < -22 then r.AssemblyLinearVelocity = V3(v.X, -22, v.Z) end
if up < 0 and air then r.AssemblyLinearVelocity = V3(v.X, max(v.Y - 60 * dt, -45), v.Z) end
end
if not air then J.fuel = min(CFG.jet.fuel, J.fuel + CFG.jet.regen * dt) end
h.WalkSpeed = air and CFG.jet.speed or J.ws
for _, e in ipairs(J.fl) do e.Rate = thr and 90 * Q().pr or 0 end
J.hud.Visible = true
J.hud.Text = "🔥 Топливо: " .. floor(J.fuel) .. "%"
end
RM.regGadget({ id = "jet", name = "Реактивный ранец", icon = "🔥", desc = "Включить / выключить ранец", style = "pack", col = RGB(80, 90, 110), acc = RGB(255, 150, 50), cost = 0, cd = .5, use = function() RM.jetToggle() end })
local D = { on = false, cf = CF(), m = nil, rot = {}, t0 = 0, ang = 0, hud = tinyHud(72) }
RM.drone = D
function RM.droneStop()
if not D.on then return end
D.on = false
EN.stop("drone")
if D.m then D.m:Destroy() D.m = nil end
local _, h, r = getChar()
local c = cam()
if c and h then c.CameraSubject = h end
RM.setCustomControls(false)
if r then r.Anchored = false end
leaveMode("drone")
D.hud.Visible = false
notify("🚁 Дрон отключён", C.dim)
end
RM.exitFns.drone = RM.droneStop
function RM.droneStart()
if D.on then return end
local _, h, r = getChar()
if not (h and r) then return end
if not EN.use(CFG.cost.drone, "дрон") then return end
local ok, why = enterMode("drone", "drone")
if not ok then EN.add(CFG.cost.drone) return notify(why, C.warn) end
local pos = r.Position + r.CFrame.LookVector * 4 + V3(0, 3, 0)
D.cf = CF(pos)
local m = I("Model", { Name = "Drone" }, fxF)
local b = M.ball(m, "Body", 1.8, D.cf, RGB(60, 65, 80), MM)
M.ball(m, "Eye", .8, D.cf * CF(0, 0, -.8), RGB(255, 70, 70), MN)
D.rot = {}
for i = 1, 4 do
local ox, oz = (i % 2 == 0 and 1 or -1) * 1.5, (i > 2 and 1 or -1) * 1.5
local arm = M.part(m, "Arm", V3(.2, .2, 2.1), D.cf * CF(ox / 2, 0, oz / 2) * ANG(0, math.atan2(ox, oz), 0), RGB(40, 40, 50), MM)
local rt = M.cyl(m, "Rotor", .9, .06, D.cf * CF(ox, .3, oz), RGB(200, 220, 255), Enum.Material.Glass, { Transparency = .5 })
D.rot[#D.rot + 1] = { rt, ox, oz }
end
fx.light(b, RGB(255, 255, 255), 24, 2)
m.PrimaryPart = b
M.weldAll(m, b)
M.anchorAll(m, true)
D.m, D.on, D.t0, D.ang = m, true, os.clock(), 0
r.Anchored = true
RM.setCustomControls(true)
local c = cam()
if c then c.CameraSubject = b end
EN.drain("drone", CFG.drain.drone, RM.droneStop)
notify("🚁 Дрон: WASD/джойстик — полёт, Space/Ctrl — высота, X — вернуться. Радиус " .. CFG.drone.range, C.ac, 5)
end
RM.ticks.drone = function(dt, now)
if not D.on then return end
local c, h, r = getChar()
if not (r and D.m and D.m.Parent) or (h and h.Health <= 0) or now - D.t0 > CFG.drone.time then return RM.droneStop() end
local md = RM.moveDir()
local v = md * CFG.drone.speed + V3(0, RM.vertical() * CFG.drone.speed * .7, 0)
local pos = D.cf.Position
local step = v * dt
if step.Magnitude > .01 then
local hit = ray(pos, step.Unit * (step.Magnitude + 1.5), { WORLD, c })
if not hit then pos = pos + step end
end
local off = pos - r.Position
if off.Magnitude > CFG.drone.range then pos = r.Position + off.Unit * CFG.drone.range end
local face = md.Magnitude > .1 and md or D.cf.LookVector
D.cf = CFrame.lookAt(pos, pos + V3(face.X, 0, face.Z))
D.ang = D.ang + dt * 40
D.m:PivotTo(D.cf)
for _, t in ipairs(D.rot) do t[1].CFrame = D.cf * CF(t[2], .3, t[3]) * ANG(0, D.ang, 0) * ANG(0, 0, pi / 2) end
D.hud.Visible = true
D.hud.Text = string.format("🚁 %dс  дистанция %d/%d", floor(max(0, CFG.drone.time - (now - D.t0))), floor(off.Magnitude), CFG.drone.range)
end
RM.bindKey("X", function() RM.exitMode() end)
RM.regGadget({ id = "drone", name = "Дрон-разведчик", icon = "🚁", desc = "Запуск дрона с видом от первого лица", style = "box", col = RGB(60, 65, 80), acc = RGB(255, 90, 90), cost = 0, cd = 1, use = function() RM.droneStart() end })
local function rescale(u, k)
u.model:ScaleTo(u.model:GetScale() * k)
for n, j in pairs(u.rig.joints) do u.rig.base[n] = j.C0 end
u.rig.s = u.rig.s * k
end
RM.regGadget({ id = "shrink", name = "Уменьшитель", icon = "🔬", desc = "Уменьшает / возвращает размер цели (локальные юниты)", style = "pistol", col = RGB(60, 90, 100), acc = RGB(120, 255, 255), cost = CFG.cost.shrink, cd = .8, use = function(x)
local o = x.inst
while o and o ~= WORLD and not UN[o] do o = o.Parent end
local u = o and UN[o]
fx.bolt(x.root.Position + V3(0, 1, 0), x.pos or (x.o + x.d * 200), RGB(120, 255, 255), .25, .25)
if not (u and u.rig) then return notify("Наведи на робота / NPC / мишень", C.warn, 1.5) end
u.shrunk = not u.shrunk
rescale(u, u.shrunk and .4 or 2.5)
u.hp = u.shrunk and min(u.hp, u.max * .5) or u.hp
fx.spark(u.root.Position, RGB(120, 255, 255), 20)
end })
local me = { on = false }
function RM.shrinkMe(on)
local c = LP.Character
if not c then return end
if on == nil then on = not me.on end
if on == me.on then return end
if on and not EN.use(CFG.cost.shrink, "уменьшение") then return end
me.on = on
pcall(function() c:ScaleTo(on and .35 or 1) end)
if on then EN.drain("shrink", 1, function() RM.shrinkMe(false) end) else EN.stop("shrink") end
fx.dim(RGB(120, 255, 255), .6)
notify(on and "🐜 Ты уменьшился" or "Размер возвращён", C.ac)
end
RM.charHooks[#RM.charHooks + 1] = function() me.on = false EN.stop("shrink") J.on = false J.pack = nil J.fl = {} if MODE.cur == "jet" then leaveMode("jet") end end
RM.cleanups[#RM.cleanups + 1] = function()
if me.on then pcall(function() LP.Character:ScaleTo(1) end) end
pcall(RM.droneStop)
pcall(RM.jetToggle, false)
end
RM.regGadget({ id = "shrinkme", name = "Костюм-уменьшитель", icon = "🐜", desc = "Уменьшает тебя в 3 раза (вкл/выкл)", style = "can", col = RGB(70, 90, 110), acc = RGB(120, 255, 255), cost = 0, cd = 1, use = function() RM.shrinkMe() end })
end
do
local C, M, fx = RM.C, RM.M, RM.fx
local SH = { on = false, hp = 0, part = nil, t0 = 0, cd = 0 }
local DM = { on = false, hp = 0, part = nil, pos = nil, t0 = 0 }
RM.shield, RM.dome = SH, DM
local defF = folder("Defense")
local function bubble(r, col, tr)
return I("Part", { Shape = Enum.PartType.Ball, Size = V3(r * 2, r * 2, r * 2), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
Material = Enum.Material.ForceField, Color = col, Transparency = tr, CastShadow = false }, defF)
end
function RM.shieldToggle(on)
if on == nil then on = not SH.on end
if on == SH.on then return end
if on then
if os.clock() < SH.cd then return notify("🛡 Щит перезаряжается: " .. floor(SH.cd - os.clock()) .. " с", C.warn, 1.5) end
if not EN.use(CFG.cost.shield, "щит") then return end
SH.on, SH.hp, SH.t0 = true, CFG.shield.hp, os.clock()
SH.part = bubble(5.5, RGB(80, 200, 255), .55)
EN.drain("shield", CFG.drain.shield, function() RM.shieldToggle(false) end)
snd("shield", 1, 1)
notify("🛡 Щит активен (" .. CFG.shield.time .. " с) — защищает от локальных угроз", C.ac, 2.5)
else
SH.on, SH.cd = false, os.clock() + CFG.shield.cd
EN.stop("shield")
if SH.part then SH.part:Destroy() SH.part = nil end
snd("shield", .8, .6)
end
end
function RM.domeToggle(on)
if on == nil then on = not DM.on end
if on == DM.on then return end
if on then
local _, _, r = getChar()
if not r or not EN.use(CFG.cost.dome, "купол") then return end
DM.on, DM.hp, DM.t0 = true, CFG.dome.hp, os.clock()
DM.pos = r.Position
DM.part = bubble(CFG.dome.r, RGB(120, 255, 180), .8)
DM.part.CFrame = CF(DM.pos)
EN.drain("dome", CFG.drain.dome, function() RM.domeToggle(false) end)
fx.ring(DM.pos - V3(0, 3, 0), RGB(120, 255, 180), CFG.dome.r * 2, V3(0, 1, 0))
snd("shield", 1, .8)
notify("⛺ Купол развёрнут: внутри +энергия, враги не входят", C.ac, 3)
else
DM.on = false
EN.stop("dome")
if DM.part then DM.part:Destroy() DM.part = nil end
notify("Купол свёрнут", C.dim, 1.5)
end
end
function RM.shieldAbsorb(dmg, from)
local _, _, r = getChar()
if SH.on then
SH.hp = SH.hp - dmg * 2
fx.pulse(SH.part, .15, RGB(255, 255, 255))
snd("shield", .8, 1.5)
if SH.hp <= 0 then RM.shieldToggle(false) notify("🛡 Щит разрушен", C.dg) end
return true
end
if DM.on and r and (r.Position - DM.pos).Magnitude < CFG.dome.r then
DM.hp = DM.hp - dmg
if DM.hp <= 0 then RM.domeToggle(false) notify("⛺ Купол разрушен", C.dg) end
return true
end
return false
end
RM.ticks.defense = function(dt, now)
if SH.on then
local _, _, r = getChar()
if not r or now - SH.t0 > CFG.shield.time then return RM.shieldToggle(false) end
SH.part.CFrame = r.CFrame
end
if DM.on then
local _, _, r = getChar()
if now - DM.t0 > CFG.dome.time then return RM.domeToggle(false) end
if r and (r.Position - DM.pos).Magnitude < CFG.dome.r then EN.add(2.5 * dt) end
for _, u in pairs(RM.units) do
if u.team == "enemy" and u.root.Parent then
local off = u.root.Position - DM.pos
local d = off.Magnitude
if d < CFG.dome.r + 1 and d > .1 then
u.root.AssemblyLinearVelocity = off.Unit * 40 + V3(0, 6, 0)
u.hum:MoveTo(DM.pos + off.Unit * (CFG.dome.r + 12))
end
end
end
end
end
RM.cleanups[#RM.cleanups + 1] = function() SH.on, DM.on = false, false end
RM.regGadget({ id = "shield", name = "Генератор щита", icon = "🛡", desc = "Личный щит на 8 с", style = "box", col = RGB(50, 80, 110), acc = RGB(80, 200, 255), cost = 0, cd = .6, use = function() RM.shieldToggle() end })
RM.regGadget({ id = "dome", name = "Купол-генератор", icon = "⛺", desc = "Защитный купол на 30 с", style = "can", col = RGB(50, 100, 80), acc = RGB(120, 255, 180), cost = 0, cd = 1, use = function() RM.domeToggle() end })
end
do
local C, M, fx, U = RM.C, RM.M, RM.fx, RM.U
local UN, MN = RM.units, Enum.Material.Neon
local propsF = RM.propsF
local rnd = math.random
local pick = {}
local CN = { gear = "⚙ Шестерня", chip = "💾 Чип", battery = "🔋 Батарея", wire = "🧵 Провод" }
RM.CN = CN
local CCOL = { gear = RGB(200, 200, 210), chip = RGB(80, 255, 140), battery = RGB(255, 230, 60), wire = RGB(255, 140, 60) }
function RM.dropPickup(pos, k)
k = k or ({ "gear", "chip", "battery", "wire" })[rnd(4)]
local p = M.ball(propsF, "Pickup", 1.1, CF(pos), CCOL[k], MN, { Anchored = true })
fx.light(p, CCOL[k], 8, 1.5)
pick[#pick + 1] = { p = p, k = k, y = pos.Y, t0 = os.clock() }
end
RM.ticks.pickups = function(dt, now)
if #pick == 0 then return end
local _, _, r = getChar()
for i = #pick, 1, -1 do
local e = pick[i]
if not e.p.Parent or now - e.t0 > 150 then
e.p:Destroy()
table.remove(pick, i)
else
e.p.Position = V3(e.p.Position.X, e.y + sin(now * 2 + i) * .4, e.p.Position.Z)
if r and (r.Position - e.p.Position).Magnitude < 5 then
RM.addComp(e.k)
notify("Получено: " .. CN[e.k], C.ok, 1.5)
snd("comp", 1, 1.2)
fx.spark(e.p.Position, CCOL[e.k], 10)
e.p:Destroy()
table.remove(pick, i)
end
end
end
end
function RM.scan()
local c, _, r = getChar()
if not r then return end
fx.ring(r.Position, C.ac, CFG.scan.r * 2, V3(0, 1, 0))
snd("holo", 1, 1.5)
local found = {}
for m, u in pairs(UN) do
local d = (u.root.Position - r.Position).Magnitude
if d < CFG.scan.r and u.kind ~= "holo" then
found[#found + 1] = { d, u.name .. (u.team == "enemy" and " ⚠" or "") }
fx.highlight(m, u.team == "enemy" and C.dg or C.ac, 4)
end
end
for _, pl in ipairs(Players:GetPlayers()) do
local pr = pl ~= LP and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
if pr and (pr.Position - r.Position).Magnitude < CFG.scan.r then
found[#found + 1] = { (pr.Position - r.Position).Magnitude, "Игрок " .. pl.DisplayName }
fx.highlight(pl.Character, RGB(80, 160, 255), 4)
end
end
table.sort(found, function(a, b) return a[1] < b[1] end)
local t = {}
for i = 1, min(5, #found) do t[i] = floor(found[i][1]) .. "м " .. found[i][2] end
notify("📡 Сканер: " .. (#found == 0 and "ничего живого поблизости" or (#found .. " целей: " .. table.concat(t, ", "))), C.ac, 5)
end
RM.regGadget({ id = "scanner", name = "Сканер", icon = "📡", desc = "Импульс: подсвечивает цели и игроков вокруг", style = "box", col = RGB(40, 70, 60), acc = RGB(80, 255, 160), cost = CFG.cost.scan, cd = CFG.scan.cd, use = function() RM.scan() end })
local rad = I("Frame", { Size = UDim2.fromOffset(130, 130), Position = UDim2.new(0, 14, 1, -150), BackgroundColor3 = C.bg, BackgroundTransparency = .25, Visible = false, ZIndex = 40 }, RM.gui)
U.corner(rad, 65)
U.stroke(rad, C.ac, 2, .3)
I("Frame", { Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = C.tx, ZIndex = 42 }, rad)
local dots = {}
RM.radarOn = false
function RM.radar(on)
if on == nil then on = not RM.radarOn end
RM.radarOn = on
rad.Visible = on
end
RM.ticks.radar = function(dt)
if not RM.radarOn then return end
RM.rdT = (RM.rdT or 0) + dt
if RM.rdT < .1 then return end
RM.rdT = 0
local _, _, r = getChar()
local c = cam()
if not (r and c) then return end
local look = c.CFrame.LookVector
local yaw = math.atan2(look.X, look.Z)
local n = 0
local R = ST.radarR
local function dot(pos, col)
local o = pos - r.Position
local x, z = o.X * cos(yaw) - o.Z * sin(yaw), o.X * sin(yaw) + o.Z * cos(yaw)
local d = sqrt(x * x + z * z)
if d > R then return end
n = n + 1
if n > 50 then return end
local f = dots[n]
if not f then
f = I("Frame", { Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(.5, .5), ZIndex = 41, BorderSizePixel = 0 }, rad)
U.corner(f, 3)
dots[n] = f
end
f.Visible, f.BackgroundColor3 = true, col
f.Position = UDim2.new(.5, -x / R * 58, .5, z / R * 58)
end
for _, u in pairs(UN) do dot(u.root.Position, u.team == "enemy" and C.dg or C.ok) end
for _, pl in ipairs(Players:GetPlayers()) do
local pr = pl ~= LP and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
if pr then dot(pr.Position, RGB(80, 160, 255)) end
end
for _, e in ipairs(pick) do dot(e.p.Position, C.warn) end
for i = n + 1, #dots do dots[i].Visible = false end
end
RM.regGadget({ id = "crate", name = "Ящик-реквизит", icon = "📦", desc = "Создаёт физический ящик (для манипулятора)", style = "box", col = RGB(120, 90, 50), acc = RGB(255, 200, 100), cost = 1, cd = .5, use = function(x)
if not canAdd("props", CFG.limit.props) then return end
local pos = x.pos and x.pos + V3(0, 3, 0) or x.o + x.d * 12
local p = M.part(propsF, "Crate", V3(3, 3, 3), CF(pos), RGB(150, 110, 60), Enum.Material.Wood, { CanCollide = true, CanQuery = true, Massless = false })
p.CustomPhysicalProperties = PhysicalProperties.new(.7, .4, .2)
local e = entAdd("props", { p = p, destroy = function(s) s.p:Destroy() end })
later(120, function() entDel("props", e) if p.Parent then p:Destroy() end end)
end })
local held
local function grabTarget(inst)
local o = inst
while o and o ~= WORLD do
if o:IsA("BasePart") and o.Parent == propsF and not o.Anchored then return o end
if UN[o] then return UN[o].root end
o = o.Parent
end
end
local function release(throw)
if not held then return end
local p = held
held = nil
EN.stop("grav")
if throw and p.Parent then p.AssemblyLinearVelocity = RM.aimRay and select(2, RM.aimRay()) * 90 or V3() end
end
RM.regGadget({ id = "grav", name = "Гравитационный манипулятор", icon = "🧲", desc = "Захват ящиков и юнитов; повторный клик — бросок", style = "pistol", col = RGB(70, 60, 100), acc = RGB(160, 120, 255), cost = 0, cd = .4, range = 60, use = function(x)
if held then return release(true) end
local t = x.inst and grabTarget(x.inst)
if not t then return notify("Манипулятор берёт только свои ящики и юниты", C.warn, 2) end
if t.AssemblyMass > CFG.gravity.maxMass then return notify("Слишком тяжёлый", C.warn) end
if not EN.use(2, "манипулятор") then return end
held = t
EN.drain("grav", CFG.drain.grav, function() release(false) end)
snd("gadget", 1, .7)
end })
RM.ticks.grav = function(dt)
if not held then return end
if not held.Parent then return release(false) end
local o, d = RM.aimRay()
local tp = o + d * ST.gravDist
local dv = (tp - held.Position)
held.AssemblyLinearVelocity = dv * 10 * ST.gravForce
held.AssemblyAngularVelocity = V3()
end
RM.cleanups[#RM.cleanups + 1] = function() held = nil end
RM.regGadget({ id = "arm", name = "Рука-манипулятор", icon = "🦾", desc = "Тянет ящик/юнит к тебе, либо подтягивает тебя к поверхности", style = "wand", col = RGB(130, 130, 150), acc = RGB(255, 150, 80), cost = 5, cd = 1, range = 60, use = function(x)
local tp = x.inst and grabTarget(x.inst)
local from = x.root.Position + V3(0, 1, 0)
if not x.pos or (x.pos - from).Magnitude > ST.armLen * 1.6 then return notify("Рука достаёт на " .. ST.armLen .. " м", C.warn, 1.5) end
fx.bolt(from, x.pos, RGB(255, 150, 80), .4, .5)
snd("gadget", 1, .9)
if tp then
tp.AssemblyLinearVelocity = (from + x.root.CFrame.LookVector * 6 - tp.Position).Unit * 70
else
x.root.AssemblyLinearVelocity = (x.pos - from).Unit * 70 + V3(0, 15, 0)
end
end })
local zones = {}
RM.zoneMode = "low"
local ZF = { low = .3, zero = 0, heavy = 2.5 }
RM.ZF = ZF
RM.regGadget({ id = "zone", name = "Гравизона", icon = "🌐", desc = "Зона с другой гравитацией 30 с (режим: меню «Мир»)", style = "can", col = RGB(60, 60, 110), acc = RGB(120, 140, 255), cost = CFG.cost.zone, cd = 1, range = 120, use = function(x)
if not canAdd("zones", CFG.limit.zones) then return end
local pos = x.pos and x.pos + V3(0, 6, 0) or x.o + x.d * 20
local s = I("Part", { Shape = Enum.PartType.Ball, Size = V3(40, 40, 40), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Material = Enum.Material.ForceField,
Color = RM.zoneMode == "heavy" and RGB(255, 90, 90) or RGB(120, 140, 255), Transparency = .7, CFrame = CF(pos) }, propsF)
local e = entAdd("zones", { p = s, pos = pos, k = ZF[RM.zoneMode], destroy = function(z) z.p:Destroy() EN.stop("zone" .. tostring(z.p)) end })
EN.drain("zone" .. tostring(s), CFG.drain.zone, function() entDel("zones", e) e:destroy() end)
zones[#zones + 1] = e
later(30, function() entDel("zones", e) if s.Parent then e:destroy() end end)
snd("shield", 1, .5)
end })
RM.ticks.zones = function(dt)
local g = 196.2
local _, _, r = getChar()
for _, z in ipairs(RM.ents.zones or {}) do
if z.p.Parent then
if r and (r.Position - z.pos).Magnitude < 20 then g = 196.2 * z.k end
for _, u in pairs(UN) do
if (u.root.Position - z.pos).Magnitude < 20 then u.root.AssemblyLinearVelocity += V3(0, 196.2 * (1 - z.k) * dt, 0) end
end
for _, p in ipairs(propsF:GetChildren()) do
if p:IsA("BasePart") and not p.Anchored and (p.Position - z.pos).Magnitude < 20 then p.AssemblyLinearVelocity += V3(0, 196.2 * (1 - z.k) * dt, 0) end
end
end
end
if Workspace.Gravity ~= g then Workspace.Gravity = g end
end
RM.cleanups[#RM.cleanups + 1] = function() Workspace.Gravity = 196.2 end
local mg = I("Frame", { Size = UDim2.fromOffset(300, 110), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .3), BackgroundColor3 = C.bg, Visible = false, ZIndex = 120 }, RM.gui)
U.corner(mg, 12)
U.stroke(mg, C.warn, 2)
local mgT = U.label(mg, "", { Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(8, 4), Font = Enum.Font.GothamBold, ZIndex = 121, TextWrapped = false })
local mgBar = I("Frame", { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 30), BackgroundColor3 = C.bg3, ZIndex = 121 }, mg)
local mgZone = I("Frame", { Size = UDim2.fromScale(.2, 1), BackgroundColor3 = C.ok, ZIndex = 122, BorderSizePixel = 0 }, mgBar)
local mgMark = I("Frame", { Size = UDim2.new(0, 6, 1, 6), Position = UDim2.fromOffset(0, -3), BackgroundColor3 = RGB(255, 255, 255), ZIndex = 123, BorderSizePixel = 0 }, mgBar)
local mgBtn = I("TextButton", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 60), BackgroundColor3 = RGB(32, 110, 72), Text = "СТАБИЛИЗИРОВАТЬ", TextColor3 = C.tx, Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 122 }, mg)
U.corner(mgBtn, 8)
local G = nil
local mgState = { ok = 0, bad = 0, x = 0, dir = 1, sp = .9 }
local function mgNewZone() mgZone.Position = UDim2.fromScale(rnd() * .8, 0) end
local function mgEnd(win)
mg.Visible = false
local gen = G
G = nil
if not (gen and gen.m.Parent) then return end
if win then
EN.bonus[gen] = 3
RM.dropPickup(gen.pos + V3(3, 2, 0), "battery")
gen.core.Color = C.ok
notify("⚡ Генератор стабилен: +3 энергии/с на 60 с и батарея", C.ok, 4)
later(60, function() EN.bonus[gen] = nil if gen.m.Parent then gen.core.Color = C.dim end end)
else
RM.boom(gen.pos, 14, 40, RGB(255, 120, 40))
gen.destroy(gen)
entDel("gens", gen)
notify("💥 Генератор перегружен и взорвался", C.dg, 3)
end
end
conn(mgBtn.Activated:Connect(function()
if not G then return end
local lo = mgZone.Position.X.Scale
if mgState.x >= lo and mgState.x <= lo + .2 then mgState.ok = mgState.ok + 1 else mgState.bad = mgState.bad + 1 end
mgState.sp = mgState.sp + .25
mgNewZone()
if mgState.ok >= 4 then mgEnd(true) elseif mgState.bad >= 3 then mgEnd(false) end
end))
RM.ticks.mini = function(dt)
if not G then return end
mgState.x = mgState.x + mgState.dir * mgState.sp * dt
if mgState.x > 1 then mgState.x, mgState.dir = 1, -1 elseif mgState.x < 0 then mgState.x, mgState.dir = 0, 1 end
mgMark.Position = UDim2.new(mgState.x, -3, 0, -3)
mgT.Text = "⚡ Генератор: попади в зелёное " .. mgState.ok .. "/4, промахи " .. mgState.bad .. "/3"
local _, _, r = getChar()
if not r or (r.Position - G.pos).Magnitude > 30 then mgEnd(false) end
end
function RM.genStart(gen)
if G then return end
mgState = { ok = 0, bad = 0, x = 0, dir = 1, sp = .9 }
mgNewZone()
G = gen
mg.Visible = true
end
RM.regGadget({ id = "gen", name = "Генератор энергии", icon = "⚡", desc = "Поставить генератор; клик по нему — мини-игра стабилизации", style = "box", col = RGB(90, 80, 40), acc = RGB(255, 230, 60), cost = CFG.cost.gen, cd = .8, range = 80, use = function(x)
local o = x.inst
while o and o ~= WORLD do
if o:GetAttribute("RM_Gen") then
for _, g in ipairs(RM.ents.gens or {}) do if g.m == o then return RM.genStart(g) end end
end
o = o.Parent
end
if not x.pos or not canAdd("gens", CFG.limit.gens) then return end
local m = I("Model", { Name = "Generator" }, propsF)
m:SetAttribute("RM_Gen", true)
local base = CF(x.pos + V3(0, 2, 0))
local b = M.part(m, "Base", V3(4, 4, 4), base, RGB(80, 85, 100), Enum.Material.Metal, { Anchored = true, CanQuery = true })
local core = M.cyl(m, "Core", 1.2, 3, base * CF(0, 3, 0), C.dim, MN, { Anchored = true, CanQuery = true })
M.skin(b, "lab")
fx.light(core, C.warn, 14, 1.5)
local g = { m = m, pos = x.pos, core = core, destroy = function(s) EN.bonus[s] = nil s.m:Destroy() end }
entAdd("gens", g)
snd("gadget", 1, .8)
notify("Генератор поставлен. Нажми по нему этим же устройством", C.ac, 3)
end })
RM.lab = nil
function RM.buildLab()
if RM.lab and RM.lab.Parent then RM.lab:Destroy() RM.lab = nil end
local pos, _, _, o, d = RM.aimHit(80)
pos = pos or (o + d * 25)
local fl = Vector3.new(d.X, 0, d.Z)
local base = CFrame.lookAt(pos + V3(0, .3, 0), pos + V3(0, .3, 0) + (fl.Magnitude > .1 and fl.Unit or V3(0, 0, -1)))
local m = I("Model", { Name = "Lab" }, propsF)
local function P(n, sz, off, col, mat) local p = M.part(m, n, sz, base * off, col, mat, { Anchored = true, CanCollide = true, CanQuery = true }) M.skin(p, "lab") return p end
P("Floor", V3(30, .6, 22), CF(), RGB(70, 75, 90), Enum.Material.Metal)
P("Back", V3(30, 10, .6), CF(0, 5, -11), RGB(190, 200, 215), Enum.Material.Metal)
P("Left", V3(.6, 10, 22), CF(-15, 5, 0), RGB(190, 200, 215), Enum.Material.Metal)
P("Right", V3(.6, 10, 22), CF(15, 5, 0), RGB(190, 200, 215), Enum.Material.Metal)
P("Roof", V3(30, .6, 22), CF(0, 10, 0), RGB(100, 105, 120), Enum.Material.Metal).Transparency = .5
P("Table", V3(10, 1, 3), CF(0, 3, -8), RGB(150, 130, 100), Enum.Material.Wood)
P("Leg1", V3(.8, 2.5, .8), CF(-4.5, 1.6, -8), RGB(90, 90, 100), Enum.Material.Metal)
P("Leg2", V3(.8, 2.5, .8), CF(4.5, 1.6, -8), RGB(90, 90, 100), Enum.Material.Metal)
local scr = P("Screen", V3(6, 3.5, .3), CF(0, 6.5, -10.6), RGB(10, 20, 30), MN)
scr.Color = RGB(30, 90, 70)
for i, col in ipairs({ C.ac, C.ac2, C.warn }) do
local t = M.cyl(m, "Tube", .7, 4, base * CF(-12 + i * 2, 2.6, 8) , col, Enum.Material.Glass, { Anchored = true, Transparency = .35 })
fx.light(t, col, 10, 1)
end
fx.light(scr, RGB(120, 255, 200), 24, 1.5)
m.Parent = propsF
RM.lab = m
RM.labPos = pos
RM.labT = os.clock() + 25
snd("gadget", 1, .6)
notify("🧪 Лаборатория построена: рядом генерирует детали каждые ~40 с", C.ok, 4)
end
RM.ticks.lab = function(dt, now)
if not (RM.lab and RM.lab.Parent) then return end
local _, _, r = getChar()
if r and (r.Position - RM.labPos).Magnitude < 40 and now > (RM.labT or 0) then
RM.labT = now + 40
RM.dropPickup(RM.labPos + V3(rnd(-6, 6), 3, rnd(-3, 3)))
end
end
RM.cleanups[#RM.cleanups + 1] = function() if RM.lab then RM.lab:Destroy() end end
end
do
local C, M, fx = RM.C, RM.M, RM.fx
local rnd = math.random
local function v3(p) return V3(p.x, p.y, p.z) end
function RM.coordSave(name)
local _, _, r = getChar()
if not r then return end
if #SAVE.coords >= CFG.limit.coords then return notify("Лимит координат: " .. CFG.limit.coords, C.warn) end
local p = r.Position
SAVE.coords[#SAVE.coords + 1] = { name = str(name ~= "" and name or ("Точка " .. (#SAVE.coords + 1))), p = { x = p.X, y = p.Y, z = p.Z }, ry = select(2, r.CFrame:ToOrientation()), fav = false }
notify("📍 Сохранено: " .. SAVE.coords[#SAVE.coords].name, C.ok, 1.5)
end
function RM.goPos(e, cost)
local _, _, r = getChar()
if not r then return end
if cost and not EN.use(cost, "телепорт") then return end
local back = r.Position
if RM.teleport(v3(e.p), e.ry) then RM.backPos = back else if cost then EN.add(cost) end end
end
function RM.coordGo(i) if SAVE.coords[i] then RM.goPos(SAVE.coords[i], CFG.cost.coord) end end
function RM.coordFav(i) if SAVE.coords[i] then SAVE.coords[i].fav = not SAVE.coords[i].fav end end
function RM.coordDel(i) table.remove(SAVE.coords, i) end
function RM.coordBack()
if not RM.backPos then return notify("Нет точки возврата", C.warn) end
RM.goPos({ p = { x = RM.backPos.X, y = RM.backPos.Y, z = RM.backPos.Z }, ry = 0 }, CFG.cost.coord)
end
function RM.slotSave(i)
local _, _, r = getChar()
if not r then return end
local p = r.Position
SAVE.slots[i] = { name = "Слот " .. i, p = { x = p.X, y = p.Y, z = p.Z }, ry = select(2, r.CFrame:ToOrientation()), mode = MODE.cur, size = 1 }
notify("💾 Слот " .. i .. " сохранён", C.ok, 1.5)
end
function RM.slotGo(i) if SAVE.slots[i] then RM.goPos(SAVE.slots[i], CFG.cost.coord) else notify("Слот пуст", C.warn) end end
RM.regGadget({ id = "coords", name = "Навигатор координат", icon = "📍", desc = "Клик — вернуться в предыдущую точку", style = "box", col = RGB(50, 60, 90), acc = RGB(120, 200, 255), cost = 0, cd = 1, use = function() RM.coordBack() end })
local hist = {}
RM.ticks.hist = function(dt, now)
RM.hT = (RM.hT or 0) + dt
if RM.hT < 3 then return end
RM.hT = 0
local _, h, r = getChar()
if r and h and h.Health > 0 and MODE.cur == "normal" then
hist[#hist + 1] = { t = now, p = r.Position, ry = select(2, r.CFrame:ToOrientation()), en = EN.v }
if #hist > 22 then table.remove(hist, 1) end
end
end
function RM.rewind(sec)
local now = os.clock()
local best
for i = #hist, 1, -1 do
if now - hist[i].t >= sec then best = hist[i] break end
end
best = best or hist[1]
if not best then return notify("История пока пуста: подожди несколько секунд", C.warn) end
if MODE.cur ~= "normal" then return notify("Откат работает в обычном режиме", C.warn) end
if not EN.use(CFG.cost.time, "откат") then return end
if RM.teleport(best.p, best.ry) then
EN.v = max(EN.v, best.en)
notify("⏪ Откат на " .. floor(now - best.t) .. " с назад", C.ac)
else EN.add(CFG.cost.time) end
end
RM.regGadget({ id = "timemachine", name = "Машина времени", icon = "⏪", desc = "Откат на 30 с назад (позиция и энергия)", style = "wand", col = RGB(100, 80, 50), acc = RGB(255, 200, 80), cost = 0, cd = 2, use = function() RM.rewind(30) end })
RM.RECIPES = {
{ id = "pack", name = "Батарейный блок", desc = "+3 батареи (можно повторять)", cost = { wire = 1, chip = 1 }, rep = true },
{ id = "blaster", name = "Самодельный бластер", desc = "Открывает гаджет «Бластер»", cost = { gear = 2, chip = 1, battery = 1 } },
{ id = "capacity", name = "Расширитель ёмкости", desc = "Максимум энергии +25", cost = { chip = 2, battery = 2 } },
{ id = "recup", name = "Рекуператор", desc = "Регенерация энергии +1/с", cost = { gear = 2, wire = 2 } },
}
function RM.applyUnlocks()
EN.max = CFG.energy.max + (SAVE.unl.capacity and 25 or 0)
EN.bonus.recup = SAVE.unl.recup and 1 or nil
EN.v = min(EN.v, EN.max)
end
function RM.craft(i)
local r = RM.RECIPES[i]
if not r then return end
if not r.rep and SAVE.unl[r.id] then return notify("Уже изготовлено", C.warn) end
for k, n in pairs(r.cost) do
if (SAVE.comps[k] or 0) < n then return notify("Не хватает: " .. RM.CN[k] .. " ×" .. n, C.warn) end
end
if r.id ~= "pack" and #SAVE.builds >= CFG.limit.builds then return notify("Лимит чертежей", C.warn) end
local cl = {}
for k, n in pairs(r.cost) do
SAVE.comps[k] = SAVE.comps[k] - n
for _ = 1, n do cl[#cl + 1] = k end
end
if r.id == "pack" then RM.addComp("battery", 3) else SAVE.unl[r.id] = true end
if #SAVE.builds < CFG.limit.builds then SAVE.builds[#SAVE.builds + 1] = { name = r.name, comps = cl, kind = r.id } end
RM.applyUnlocks()
snd("comp", 1, 1)
notify("🛠 Изготовлено: " .. r.name, C.ok)
RM.expAdd("craft")
end
RM.regGadget({ id = "blaster", name = "Бластер (самодельный)", icon = "🔫", desc = "Мощный выстрел. Нужно изготовить в Конструкторе", style = "pistol", col = RGB(90, 70, 50), acc = RGB(255, 150, 40), cost = 3, cd = .5, use = function(x)
if not SAVE.unl.blaster then return notify("Сначала изготовь бластер в Конструкторе", C.warn) end
local to = x.pos or (x.o + x.d * 300)
fx.bolt(x.root.Position + V3(0, 1, 0), to, RGB(255, 150, 40), .45, .25)
snd("shoot", 1, .7)
if x.pos then
fx.spark(x.pos, RGB(255, 150, 40), 14)
if x.inst then RM.hurt(x.inst, 40, x.pos) end
end
end })
local gGive = RM.giveGadget
function RM.giveGadget(id, ne)
if id == "blaster" and not SAVE.unl.blaster then return notify("Бластер ещё не изготовлен (Конструктор)", C.warn) end
return gGive(id, ne)
end
RM.EXPS = {
{ id = "kills", name = "Охотник за монстрами", goal = 5, reward = "chip", desc = "Уничтожь 5 врагов" },
{ id = "tp", name = "Мастер порталов", goal = 10, reward = "wire", desc = "10 телепортаций" },
{ id = "scan", name = "Исследователь", goal = 5, reward = "chip", desc = "5 сканирований" },
{ id = "hyper", name = "Гиперпрыгун", goal = 3, reward = "battery", desc = "3 гиперпрыжка корабля" },
{ id = "robots", name = "Инженер", goal = 4, reward = "gear", desc = "Создай 4 робота" },
{ id = "echo", name = "Эхо-теоретик", goal = 3, reward = "chip", desc = "3 эхо-клона" },
{ id = "craft", name = "Мастер-сборщик", goal = 2, reward = "battery", desc = "Изготовь 2 предмета" },
{ id = "dims", name = "Странник измерений", goal = 3, reward = "gear", desc = "Посети 3 измерения" },
}
function RM.expAdd(id, n)
for _, e in ipairs(RM.EXPS) do
if e.id == id then
local s = SAVE.exp[id] or { p = 0, done = false }
SAVE.exp[id] = s
if not s.done then
s.p = s.p + (n or 1)
if s.p >= e.goal then
s.done, s.p = true, e.goal
RM.addComp(e.reward, 2)
notify("🏆 Эксперимент «" .. e.name .. "» завершён! Награда: " .. RM.CN[e.reward] .. " ×2", C.ok, 5)
snd("comp", 1, 1.4)
end
end
end
end
end
local function hook(name, key, okfn)
local f = RM[name]
RM[name] = function(...)
local a, b = f(...)
if not okfn or okfn(a, b) then RM.expAdd(key) end
return a, b
end
end
hook("teleport", "tp", function(a) return a == true end)
hook("scan", "scan")
hook("shipHyper", "hyper")
hook("spawnEcho", "echo")
local ek = 0
RM.ticks.exp = function(dt)
RM.exT = (RM.exT or 0) + dt
if RM.exT < 1 then return end
RM.exT = 0
local k = RM.stats.kills
if k > ek then RM.expAdd("kills", k - ek) end
ek = k
end
local rc = 0
for _, f in ipairs({ "spawnRobot" }) do
local o = RM[f]
RM[f] = function(...)
local before = entCount("robots")
o(...)
if entCount("robots") > before then RM.expAdd("robots") end
end
end
local LP_ = { "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "FogColor", "FogEnd", "FogStart", "Brightness", "ClockTime", "ExposureCompensation" }
local orig = {}
for _, k in ipairs(LP_) do orig[k] = Lighting[k] end
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local atmO = atm and { Color = atm.Color, Density = atm.Density, Haze = atm.Haze, Offset = atm.Offset }
RM.DIMS = {
{ "C137", "🌍 C-137 (оригинал)", nil },
{ "toxic", "☣ Токсичный мир", { Ambient = RGB(70, 110, 30), OutdoorAmbient = RGB(90, 140, 40), ColorShift_Top = RGB(150, 255, 60), FogColor = RGB(120, 180, 40), FogEnd = 700, FogStart = 60, ClockTime = 17, Brightness = 2, atm = { Color = RGB(150, 220, 60), Density = .45, Haze = 2 } } },
{ "neon", "🌌 Неоновая ночь", { Ambient = RGB(60, 20, 120), OutdoorAmbient = RGB(80, 30, 150), ColorShift_Top = RGB(255, 60, 220), FogColor = RGB(40, 10, 80), FogEnd = 900, FogStart = 80, ClockTime = 0, Brightness = 3, atm = { Color = RGB(180, 60, 255), Density = .35, Haze = 1.5 } } },
{ "ice", "🧊 Ледяной мир", { Ambient = RGB(130, 170, 220), OutdoorAmbient = RGB(160, 200, 240), ColorShift_Top = RGB(200, 240, 255), FogColor = RGB(210, 230, 250), FogEnd = 500, FogStart = 30, ClockTime = 12, Brightness = 3, atm = { Color = RGB(200, 230, 255), Density = .5, Haze = 3 } } },
{ "sunset", "🌇 Закат мультивселенной", { Ambient = RGB(150, 80, 60), OutdoorAmbient = RGB(200, 100, 60), ColorShift_Top = RGB(255, 140, 60), FogColor = RGB(255, 150, 90), FogEnd = 1200, FogStart = 100, ClockTime = 18.2, Brightness = 2, atm = { Color = RGB(255, 150, 90), Density = .3, Haze = 2 } } },
{ "void", "🕳 Пустота", { Ambient = RGB(10, 10, 20), OutdoorAmbient = RGB(15, 15, 30), ColorShift_Top = RGB(60, 60, 120), FogColor = RGB(0, 0, 0), FogEnd = 400, FogStart = 20, ClockTime = 0, Brightness = 0, atm = { Color = RGB(0, 0, 0), Density = .6, Haze = 4 } } },
{ "red", "🔴 Красный мир", { Ambient = RGB(120, 30, 30), OutdoorAmbient = RGB(160, 40, 40), ColorShift_Top = RGB(255, 60, 40), FogColor = RGB(150, 20, 20), FogEnd = 650, FogStart = 50, ClockTime = 15, Brightness = 2, atm = { Color = RGB(255, 80, 60), Density = .4, Haze = 2.5 } } },
}
local visited = {}
function RM.setDim(key, silent)
local d
for _, x in ipairs(RM.DIMS) do if x[1] == key then d = x end end
if not d then return end
ST.dim = key
if not silent then fx.dim(pcol(), 1) end
local g = d[3]
for _, k in ipairs(LP_) do
local v = g and g[k] or orig[k]
if v ~= nil then pcall(function() tw(Lighting, 1.2, { [k] = v }) end) end
end
if atm then
local a = g and g.atm or atmO
if a then pcall(function() tw(atm, 1.2, a) end) end
end
if not silent and key ~= "C137" and not visited[key] then
visited[key] = true
RM.expAdd("dims")
end
if not silent then notify("🌀 Измерение: " .. d[2], C.ac) end
end
RM.cleanups[#RM.cleanups + 1] = function()
for _, k in ipairs(LP_) do pcall(function() Lighting[k] = orig[k] end) end
if atm and atmO then pcall(function() for k, v in pairs(atmO) do atm[k] = v end end) end
end
RM.onImport = function() RM.applyUnlocks() RM.setDim(ST.dim, true) end
RM.regGadget({ id = "dimgun", name = "Пушка измерений", icon = "🌈", desc = "Следующее измерение (цикл)", style = "pistol", col = RGB(80, 50, 110), acc = RGB(255, 100, 220), cost = CFG.cost.coord, cd = 1.5, use = function()
local idx = 1
for i, x in ipairs(RM.DIMS) do if x[1] == ST.dim then idx = i end end
RM.setDim(RM.DIMS[idx % #RM.DIMS + 1][1])
end })
end
do
local C = RM.C
local T = {}
local function arg(a, i) return a[i] and a[i]:lower() end
local function cap(s)
local b1, b2 = s:byte(1, 2)
if b1 == 0xD0 and b2 and b2 >= 0xB0 and b2 <= 0xBF then return string.char(0xD0, b2 - 0x20) .. s:sub(3) end
if b1 == 0xD1 and b2 and b2 >= 0x80 and b2 <= 0x8F then return string.char(0xD0, b2 + 0x20) .. s:sub(3) end
return s
end
local function has(hay, q) return q ~= "" and (hay:find(q, 1, true) or hay:find(cap(q), 1, true) or hay:lower():find(q:lower(), 1, true)) end
local function gname(s)
for id, d in pairs(RM.G) do if id == s or has(d.name, s) then return id end end
end
local function flag(b) return b and "вкл" or "выкл" end
T.help = { "список команд", function()
local n = {}
for k in pairs(T) do n[#n + 1] = k end
table.sort(n)
return "Команды: " .. table.concat(n, ", ") .. ". Пример: tp 1, robot guard, gadget laser, dim neon" end }
T.tp = { "tp <номер координаты>", function(a)
local i = tonumber(a[2])
if not i or not SAVE.coords[i] then return "нет такой координаты (всего " .. #SAVE.coords .. ")" end
RM.coordGo(i)
return "телепорт: " .. SAVE.coords[i].name end }
T.save = { "save [имя] — сохранить координату", function(a) RM.coordSave(a[2] and table.concat(a, " ", 2) or "") return "готово" end }
T.back = { "вернуться в предыдущую точку", function() RM.coordBack() return "ок" end }
T.rewind = { "rewind <секунды> — откат", function(a) RM.rewind(tonumber(a[2]) or 30) return "ок" end }
T.gadget = { "gadget <id|имя> — выдать гаджет", function(a)
local id = gname(a[2] or "")
if not id then return "не найден гаджет. Список: " .. table.concat(RM.gOrder, ", ") end
RM.giveGadget(id)
return "выдан: " .. RM.G[id].name end }
T.robot = { "robot guard|helper|scout|battery", function(a)
if not RM.RT[arg(a, 2) or ""] then return "типы: guard, helper, scout, battery" end
RM.spawnRobot(a[2]:lower())
return "запрос выполнен" end }
T.mee = { "вызвать Мисикса", function() RM.spawnMeeseeks() return "ок" end }
T.npc = { "npc <1-6>", function(a) RM.spawnNPC(tonumber(a[2]) or 1) return "ок" end }
T.dummy = { "создать мишень", function() RM.spawnDummy() return "ок" end }
T.clear = { "clear — убрать юнитов", function() for _, k in ipairs({ "robots", "meeseeks", "npcs", "dummies", "holo", "echo" }) do RM.clearUnits(k) end return "юниты удалены" end }
T.ship = { "ship — вызвать корабль", function() RM.shipSummon() return "ок" end }
T.board = { "сесть в корабль", function() RM.shipBoard() return "ок" end }
T.scan = { "сканер", function() RM.scan() return "ок" end }
T.shield = { "щит", function() RM.shieldToggle() return "щит: " .. flag(RM.shield.on) end }
T.dome = { "купол", function() RM.domeToggle() return "купол: " .. flag(RM.dome.on) end }
T.jet = { "ранец", function() RM.jetToggle() return "ранец: " .. flag(RM.jet.on) end }
T.drone = { "дрон", function() RM.droneStart() return "ок" end }
T.time = { "остановка времени", function() RM.timeStop() return "ок" end }
T.radar = { "радар", function() RM.radar() return "радар: " .. flag(RM.radarOn) end }
T.energy = { "energy — показать энергию", function() return string.format("энергия %d/%d, расход %.1f/с, регенерация %.1f/с", floor(EN.v), EN.max, EN.total(), EN.regen()) end }
T.quality = { "quality low|medium|high", function(a)
local q = (arg(a, 2) or ""):upper():gsub("^MED$", "MEDIUM")
if q ~= "LOW" and q ~= "MEDIUM" and q ~= "HIGH" then return "low / medium / high" end
RM.setQuality(q)
return "качество: " .. q end }
T.dim = { "dim <ключ>", function(a)
local ks = {}
for _, d in ipairs(RM.DIMS) do ks[#ks + 1] = d[1] if d[1] == arg(a, 2) then RM.setDim(d[1]) return "измерение: " .. d[2] end end
return "ключи: " .. table.concat(ks, ", ") end }
T.skin = { "skin <часть имени> | off", function(a)
if arg(a, 2) == "off" then RM.sk.clear() return "костюм снят" end
for _, d in ipairs(RM.sk.list) do if has(d.n, a[2] or "") then RM.sk.apply(d.n) return "скин: " .. d.n end end
return "не найден" end }
T.emotion = { "emotion <имя>", function(a)
if not RM.sk.emos[arg(a, 2) or ""] then return "эмоции: " .. table.concat(RM.sk.emoOrder, ", ") end
RM.sk.setEmotion(a[2]:lower())
return "ок" end }
T.say = { "say <текст> — фраза над головой", function(a) RM.sk.say(table.concat(a, " ", 2)) return "ок" end }
T.lab = { "построить лабораторию", function() RM.buildLab() return "ок" end }
T.diag = { "диагностика", function() return table.concat(RM.diag(), " | ") end }
local FRASES = { "Это не команда, Морти.", "Я не понимаю — но я и не обязан.", "Попробуй help.", "*рыг* Нет такой команды." }
function RM.exec(line)
line = tostring(line or ""):sub(1, 120)
local a = {}
for w in line:gmatch("%S+") do a[#a + 1] = w end
if #a == 0 then return "" end
local c = T[a[1]:lower()]
if not c then
for k in pairs(T) do if k:sub(1, #a[1]) == a[1]:lower() then return "Может, ты имел в виду «" .. k .. "»?" end end
return FRASES[math.random(#FRASES)]
end
local ok, res = pcall(c[2], a)
if not ok then return "ошибка: " .. str(res, 80) end
return res
end
RM.TCMDS = T
local fps = 60
RM.ticks.diag = function(dt) fps = fps + (1 / max(dt, .001) - fps) * .05 end
function RM.diag()
local l = {}
l[#l + 1] = "версия " .. RM.ver .. ", качество " .. ST.quality .. ", режим " .. MODE.cur
l[#l + 1] = string.format("FPS ~%d", floor(fps))
local ok, ping = pcall(function() return (Stats :: any).Network.ServerStatsItem["Data Ping"]:GetValue() end)
if ok then l[#l + 1] = "пинг " .. floor(ping) .. " мс" end
l[#l + 1] = "локальных объектов: " .. #WORLD:GetDescendants()
local ec = {}
for k, v in pairs(RM.ents) do if #v > 0 then ec[#ec + 1] = k .. "=" .. #v end end
l[#l + 1] = "сущности: " .. (#ec > 0 and table.concat(ec, " ") or "нет")
l[#l + 1] = string.format("энергия %d/%d", floor(EN.v), EN.max)
local bad = {}
for k, v in pairs(RM.health) do if v ~= "ok" then bad[#bad + 1] = k .. ": " .. v end end
l[#l + 1] = "разделы меню: " .. (#bad == 0 and "все собраны" or table.concat(bad, "; "))
l[#l + 1] = "ошибок в журнале: " .. #RM.errors
return l
end
function RM.selfTest()
local r = {}
local function t(n, c) r[#r + 1] = (c and "✔ " or "✘ ") .. n end
local s = RM.sanitize({ set = { master = 9, quality = "ZZZ", bogus = 1 }, coords = { { name = "x", p = { x = 1, y = 2, z = 3 } }, { name = 5 } } })
t("sanitize: диапазон громкости", s and s.set.master == 1)
t("sanitize: неверное качество отброшено", s and s.set.quality == "MEDIUM")
t("sanitize: лишние ключи удалены", s and s.set.bogus == nil)
t("sanitize: плохая координата отброшена", s and #s.coords == 1)
local ok = pcall(function() return HttpService:JSONDecode(RM.export()) end)
t("экспорт — корректный JSON", ok)
local v0 = EN.v
EN.v = 50
t("энергия: списание", EN.use(10) and EN.v == 40)
t("энергия: отказ при нехватке", (function() local a = EN.v EN.v = 1 local x = EN.use(5) EN.v = a return not x end)())
EN.v = v0
t("режимы: нормальный", MODE.cur == "normal" or MODE.cur ~= nil)
t("разборщик команд: help", type(RM.exec("help")) == "string")
t("гаджетов зарегистрировано ≥ 20", #RM.gOrder >= 20)
return r
end
end
do
local C, U, fx = RM.C, RM.U, RM.fx
local A = U.btn
local function G(p, n, h) return U.grid(p, n, h) end
local function L(page, h, fill)
local f, clear = U.list(page, h)
local function rf() clear() fill(f) end
rf()
return rf
end
local function on(key, ...)
local fs = { ... }
RM.onShow[key] = function() for _, f in ipairs(fs) do f() end end
end
local GREEN, RED = RGB(32, 110, 72), RGB(120, 40, 40)
local ANIM = { { "idle", "Покой", "idle", "Animation1" }, { "walk", "Ходьба", "walk", "WalkAnim" }, { "run", "Бег", "run", "RunAnim" }, { "jump", "Прыжок", "jump", "JumpAnim" },
{ "fall", "Падение", "fall", "FallAnim" }, { "climb", "Лазание", "climb", "ClimbAnim" }, { "swim", "Плавание", "swim", "Swim" }, { "e1", "Эмоция 1" }, { "e2", "Эмоция 2" }, { "e3", "Эмоция 3" } }
local function animApply()
local c = LP.Character
local an = c and c:FindFirstChild("Animate")
if not an then return end
for _, a in ipairs(ANIM) do
local id = SAVE.animIds[a[1]]
if a[3] and id then
local f = an:FindFirstChild(a[3])
local v = f and f:FindFirstChild(a[4])
if v and v:IsA("Animation") then v.AnimationId = "rbxassetid://" .. id end
end
end
end
RM.charHooks[#RM.charHooks + 1] = function() task.wait(1) animApply() end
local function playEmote(k)
local id = SAVE.animIds[k]
local _, h = getChar()
local an = h and h:FindFirstChildOfClass("Animator")
if not (id and an) then return notify("Введи числовой Animation ID в поле", C.warn) end
local ok, tr = pcall(function() return an:LoadAnimation(I("Animation", { AnimationId = "rbxassetid://" .. id })) end)
if ok and tr then tr.Looped = false tr:Play() else notify("Анимация не загрузилась (проверь ID)", C.dg) end
end
RM.addSection("home", "🏠 Главная", "энергия статус помощь клавиши", function(p)
U.sec(p, "ЭНЕРГИЯ И СТАТУС")
local eb = U.bar(p, "⚡", C.ac)
RM.ticks.homebar = function()
if RM.curSec == "home" and RM.win.Visible then
eb.set(EN.v / EN.max, string.format("⚡ %d / %d   режим: %s", floor(EN.v), EN.max, MODE.cur), EN.v / EN.max < .25 and C.dg or C.ac)
end
end
U.sec(p, "БЫСТРЫЕ ДЕЙСТВИЯ")
local g = G(p, 2)
A(g, "📡 Сканер", nil, function() RM.giveGadget("scanner") end)
A(g, "🌀 Портал-пушка", nil, function() RM.giveGadget("portal1") end)
A(g, "🚀 Вызвать корабль", nil, function() RM.shipSummon() end)
A(g, "🔫 Лазер", nil, function() RM.giveGadget("laser") end)
A(g, "🛡 Щит", nil, function() RM.shieldToggle() end)
A(g, "🗺 Радар", nil, function() RM.radar() end)
U.sec(p, "КАК ПОЛЬЗОВАТЬСЯ")
U.info(p, "• Гаджеты выдаются в рюкзак (цифры 1–9). Огонь/действие — клик или кнопка 🔥.\n• Корабль: H гипер, L посадка, R запись маршрута, P автопилот, F/ЛКМ огонь.\n• X — выйти из дрона/корабля. Меню — " .. ST.menuKey .. " или кнопка 🌀.\n• Всё создаётся локально: другие игроки этого не видят.")
U.info(p, "Версия " .. RM.ver .. ". Проверялось статически и на моках; в Roblox Studio не запускалось.", C.warn)
end)
RM.addSection("portal", "🌀 Порталы", "портал пушка телепорт цвет", function(p)
U.sec(p, "ПОРТАЛЬНЫЕ ПУШКИ")
for _, id in ipairs({ "portal1", "portal2", "portal3" }) do
local d = RM.G[id]
U.card(p, d.icon .. " " .. d.name, d.desc .. " · " .. d.cost .. "⚡", function() RM.giveGadget(id) end)
end
U.sec(p, "НАСТРОЙКИ")
local pn = {}
for i, c in ipairs(PCOL) do pn[i] = c[1] end
U.cycle(p, "Цвет портала", pn, function() return PCOL[clamp(floor(ST.portalColor), 1, #PCOL)][1] end, function(v) for i, n in ipairs(pn) do if n == v then ST.portalColor = i end end end)
A(p, "Закрыть все порталы", RED, function() RM.portalClose() end)
U.info(p, "Портал живёт " .. CFG.portal.life .. " с. Войди в один портал — выйдешь из другого. Если цели нет, портал открывается в воздухе перед тобой.")
end)
RM.addSection("skins", "🎭 Скины", "скин рик морти лицо эмоция костюм", function(p)
local SK = RM.sk
U.sec(p, "КОСТЮМЫ (видны только тебе)")
local g = G(p, 2)
for _, d in ipairs(SK.list) do A(g, d.n, nil, function() SK.apply(d.n) end) end
A(p, "Снять костюм", RED, function() SK.clear() end)
U.sec(p, "ЛИЦА")
local f = G(p, 3, 30)
for _, x in ipairs(SK.faces) do A(f, x[2], nil, function() SK.setFace(x[1]) end) end
U.sec(p, "ЭМОЦИИ ТЕЛА")
local e = G(p, 2, 30)
for _, k in ipairs(SK.emoOrder) do A(e, SK.emos[k][1], nil, function() SK.setEmotion(k) end) end
A(p, "💬 Сказать фразу", nil, function() local d = SK.byName[SK.cur or ""] SK.say(d and d.say[math.random(#d.say)] or "Ну привет.") end)
end)
RM.addSection("gadgets", "🧰 Гаджеты", "гаджет оружие устройство инструмент", function(p)
U.sec(p, "ВСЕ УСТРОЙСТВА (" .. #RM.gOrder .. ")")
for _, id in ipairs(RM.gOrder) do
local d = RM.G[id]
U.card(p, d.icon .. " " .. d.name, d.desc, function() RM.giveGadget(id) end)
end
A(p, "Убрать все гаджеты из рюкзака", RED, function() for _, id in ipairs(RM.gOrder) do RM.removeGadget(id) end end)
end)
RM.addSection("ship", "🚀 Корабль", "корабль полёт гипер автопилот маршрут посадка", function(p)
local S = RM.ship
U.sec(p, "УПРАВЛЕНИЕ")
local g = G(p, 2)
A(g, "🚀 Вызвать", nil, function() RM.shipSummon() end)
A(g, "🧑‍🚀 Сесть", GREEN, function() RM.shipBoard() end)
A(g, "🛬 Посадка / выход", nil, function() RM.exitMode() end)
A(g, "🗑 Убрать корабль", RED, function() RM.shipDismiss() end)
A(g, "🚀 Гиперпрыжок", nil, function() RM.shipHyper() end)
A(g, "💥 Огонь", nil, function() RM.shipFire() end)
U.slider(p, "Крейсерская скорость", CFG.ship.vmin, CFG.ship.vmax, function() return ST.shipSpeed end, function(v) ST.shipSpeed = v end, "%d", 10)
U.toggle(p, "HUD корабля", function() return ST.hudShip end, function(v) ST.hudShip = v end)
U.sec(p, "МАРШРУТЫ")
local g2 = G(p, 2)
A(g2, "⏺ Запись вкл/выкл", nil, function() RM.shipRec() end)
A(g2, "🤖 Автопилот стоп", nil, function() S.auto = false end)
local rf = L(p, 150, function(f)
for i, r in ipairs(SAVE.routes) do
U.row(f, r.name, #r.pts .. " точек", {
{ "▶", GREEN, function() RM.shipAuto(RM.routePts(r), r.name) end },
{ "✕", RED, function() table.remove(SAVE.routes, i) RM.refreshRoutes() end },
}, i)
end
end)
RM.refreshRoutes = rf
U.sec(p, "ЛЕТЕТЬ К КООРДИНАТЕ")
local rf2 = L(p, 110, function(f)
for i, c in ipairs(SAVE.coords) do
U.row(f, c.name, nil, { { "🤖", GREEN, function() RM.shipAuto({ V3(c.p.x, c.p.y + 15, c.p.z) }, c.name) end } }, i)
end
end)
on("ship", rf, rf2)
U.info(p, "Корабль движется кинематически (PivotTo + raycast). Реальной физики столкновений нет.")
end)
RM.addSection("robots", "🤖 Роботы", "робот мисикс npc враг мишень клон", function(p)
U.sec(p, "РОБОТЫ (до " .. CFG.limit.robots .. ")")
local g = G(p, 2)
for k, d in pairs(RM.RT) do A(g, d[1], nil, function() RM.spawnRobot(k) end) end
A(g, "🟦 Мисикс", nil, function() RM.spawnMeeseeks() end)
A(g, "🧬 Клон меня", nil, function() RM.cloneMe() end)
U.cycle(p, "Команда", { "follow", "stay" }, function() return RM.rcmd end, function(v) RM.setCmd(v) end)
U.sec(p, "NPC И ВРАГИ")
local n = G(p, 2)
for i, t in ipairs(RM.NT) do A(n, t[1], t[6] == "enemy" and RED or nil, function() RM.spawnNPC(i) end) end
A(n, "🎯 Мишень", nil, function() RM.spawnDummy() end)
U.toggle(p, "Враги преследуют меня (толчок)", function() return ST.hostile end, function(v) ST.hostile = v end)
U.sec(p, "УБРАТЬ")
local c = G(p, 2, 30)
for _, k in ipairs({ "robots", "meeseeks", "npcs", "dummies" }) do A(c, "✕ " .. k, RED, function() RM.clearUnits(k) end) end
local st = U.info(p, "")
RM.ticks.robotinfo = function() if RM.curSec == "robots" and RM.win.Visible then st.Text = "Убито врагов: " .. RM.stats.kills .. " · роботов: " .. entCount("robots") end end
U.info(p, "Урон получают только локальные цели. Игроков и их здоровье скрипт не затрагивает.")
end)
RM.addSection("clones", "👥 Клоны", "эхо голограмма время остановка", function(p)
U.sec(p, "ЭХО И ГОЛОГРАММЫ")
local g = G(p, 2)
A(g, "👥 Эхо-клон (25 с)", nil, function() RM.spawnEcho() end)
A(g, "🪞 Голограмма", nil, function() RM.spawnHolo() end)
A(g, "⏱ Остановить время", nil, function() RM.timeStop() end)
A(g, "✕ Убрать всё", RED, function() RM.clearUnits("echo") RM.clearUnits("holo") end)
U.info(p, "Эхо повторяет твой путь и реально проигрываемые анимации с задержкой. Голограмма — приманка для врагов. Остановка времени визуальная и локальная (замирают юниты скрипта и анимации других игроков).")
end)
RM.addSection("flight", "🔥 Полёт", "ранец дрон уменьшитель полёт", function(p)
U.sec(p, "УСТРОЙСТВА")
local g = G(p, 2)
A(g, "🔥 Ранец", nil, function() RM.jetToggle() end)
A(g, "🚁 Дрон", nil, function() RM.droneStart() end)
A(g, "🐜 Я уменьшаюсь", nil, function() RM.shrinkMe() end)
A(g, "🔬 Уменьшитель-пушка", nil, function() RM.giveGadget("shrink") end)
A(g, "🚪 Выйти из режима", RED, function() RM.exitMode() end)
U.info(p, "Ранец: Space/E/▲ — тяга, Ctrl/Q/▼ — снижение. Дрон: WASD/джойстик + Space/Ctrl, X — вернуться. Дрон и ранец — взаимоисключающие режимы.")
end)
RM.addSection("defense", "🛡 Защита", "щит купол защита", function(p)
U.sec(p, "ЩИТ И КУПОЛ")
local g = G(p, 2)
A(g, "🛡 Щит " .. CFG.shield.time .. " с", nil, function() RM.shieldToggle() end)
A(g, "⛺ Купол " .. CFG.dome.time .. " с", nil, function() RM.domeToggle() end)
U.info(p, "Ограничение клиентского скрипта: щит и купол блокируют только локальных врагов этого скрипта. Серверный урон и урон от других игроков они остановить не могут.", C.warn)
end)
RM.addSection("world", "🌍 Мир", "сканер радар генератор манипулятор рука гравизона лаборатория ящик", function(p)
U.sec(p, "ПРИБОРЫ")
local g = G(p, 2)
A(g, "📡 Сканер", nil, function() RM.giveGadget("scanner") end)
A(g, "🗺 Радар вкл/выкл", nil, function() RM.radar() end)
A(g, "⚡ Генератор", nil, function() RM.giveGadget("gen") end)
A(g, "🧲 Манипулятор", nil, function() RM.giveGadget("grav") end)
A(g, "🦾 Рука", nil, function() RM.giveGadget("arm") end)
A(g, "📦 Ящик", nil, function() RM.giveGadget("crate") end)
A(g, "🌐 Гравизона", nil, function() RM.giveGadget("zone") end)
A(g, "🧪 Построить лабораторию", nil, function() RM.buildLab() end)
U.cycle(p, "Гравитация зоны", { "low", "zero", "heavy" }, function() return RM.zoneMode end, function(v) RM.zoneMode = v end)
U.slider(p, "Радиус радара", 40, 300, function() return ST.radarR end, function(v) ST.radarR = v end, "%d", 10)
U.slider(p, "Дистанция манипулятора", 6, 60, function() return ST.gravDist end, function(v) ST.gravDist = v end, "%d", 1)
U.slider(p, "Сила манипулятора", .2, 3, function() return ST.gravForce end, function(v) ST.gravForce = v end, "%.1f", .1)
U.slider(p, "Длина руки", 10, 60, function() return ST.armLen end, function(v) ST.armLen = v end, "%d", 1)
U.info(p, "Манипулятор и рука берут только созданные скриптом ящики и юниты: чужие объекты сервера клиент двигать не может. Генератор: кликни по нему этим же устройством — мини-игра.")
end)
RM.addSection("coords", "📍 Координаты", "координаты точки слоты откат время вернуться", function(p)
U.sec(p, "СОХРАНИТЬ ТЕКУЩУЮ ПОЗИЦИЮ")
local inp = U.input(p, "название точки")
local rfc
A(p, "📍 Сохранить", GREEN, function() RM.coordSave(inp.Text) inp.Text = "" rfc() end)
rfc = L(p, 190, function(f)
local order = {}
for i, c in ipairs(SAVE.coords) do order[#order + 1] = i end
table.sort(order, function(a, b) local x, y = SAVE.coords[a], SAVE.coords[b] if x.fav ~= y.fav then return x.fav end return a < b end)
for k, i in ipairs(order) do
local c = SAVE.coords[i]
U.row(f, (c.fav and "★ " or "") .. c.name, string.format("%d, %d, %d", c.p.x, c.p.y, c.p.z), {
{ "➤", GREEN, function() RM.coordGo(i) end },
{ "★", nil, function() RM.coordFav(i) rfc() end },
{ "✕", RED, function() RM.coordDel(i) rfc() end },
}, k)
end
end)
U.sec(p, "БЫСТРЫЕ СЛОТЫ")
local sg = G(p, 5, 30)
for i = 1, CFG.limit.slots do A(sg, "💾" .. i, nil, function() RM.slotSave(i) end) end
local gg = G(p, 5, 30)
for i = 1, CFG.limit.slots do A(gg, "➤" .. i, GREEN, function() RM.slotGo(i) end) end
U.sec(p, "МАШИНА ВРЕМЕНИ")
local t = G(p, 3, 30)
for _, s in ipairs({ 10, 30, 60 }) do A(t, "⏪ " .. s .. " с", nil, function() RM.rewind(s) end) end
A(p, "↩ Вернуться в прошлую точку", nil, function() RM.coordBack() end)
on("coords", rfc)
end)
RM.addSection("builder", "🛠 Конструктор", "конструктор компоненты рецепт крафт чертежи", function(p)
U.sec(p, "ИНВЕНТАРЬ")
local inv = U.info(p, "")
local function showInv()
local t = {}
for k, n in pairs(RM.CN) do t[#t + 1] = n .. " × " .. (SAVE.comps[k] or 0) end
inv.Text = table.concat(t, "   ")
end
U.sec(p, "РЕЦЕПТЫ")
local rf
local function fill(f) end
for i, r in ipairs(RM.RECIPES) do
local cs = {}
for k, n in pairs(r.cost) do cs[#cs + 1] = RM.CN[k] .. "×" .. n end
U.card(p, "🛠 " .. r.name, r.desc .. " · " .. table.concat(cs, " "), function() RM.craft(i) showInv() end)
end
U.sec(p, "ИЗГОТОВЛЕННОЕ")
local rf2 = L(p, 120, function(f)
for i, b in ipairs(SAVE.builds) do U.row(f, b.name, table.concat(b.comps, "+"), { { "✕", RED, function() table.remove(SAVE.builds, i) end } }, i) end
end)
A(p, "🔫 Выдать самодельный бластер", nil, function() RM.giveGadget("blaster") end)
A(p, "🔋 Выдать батарею", nil, function() RM.giveGadget("battery") end)
U.info(p, "Компоненты падают с врагов, из генератора, лаборатории и робота-помощника.")
on("builder", showInv, rf2)
showInv()
end)
RM.addSection("science", "🔭 Наука", "эксперименты измерения достижения мир", function(p)
U.sec(p, "ЭКСПЕРИМЕНТЫ")
local rf = L(p, 220, function(f)
for i, e in ipairs(RM.EXPS) do
local s = SAVE.exp[e.id] or { p = 0 }
U.row(f, (s.done and "✔ " or "") .. e.name, e.desc .. " · " .. floor(s.p) .. "/" .. e.goal, {}, i)
end
end)
U.sec(p, "ИЗМЕРЕНИЯ (освещение и атмосфера, локально)")
local g = G(p, 2)
for _, d in ipairs(RM.DIMS) do A(g, d[2], nil, function() RM.setDim(d[1]) end) end
A(p, "🌈 Пушка измерений", nil, function() RM.giveGadget("dimgun") end)
on("science", rf)
end)
RM.addSection("terminal", "💻 Терминал", "терминал команды диагностика ошибки журнал", function(p)
U.sec(p, "ИИ-ТЕРМИНАЛ (только белый список команд)")
local out, clear = U.list(p, 170)
local n = 0
local function line(t, col)
n = n + 1
local l = U.label(out, t, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = n, TextColor3 = col or C.tx, TextSize = 11 })
if n > 40 then for _, c in ipairs(out:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() break end end end
out.CanvasPosition = Vector2.new(0, 1e5)
end
line("Терминал Рика. help — список команд.", C.ac)
local inp = U.input(p, "введи команду и нажми Enter")
conn(inp.FocusLost:Connect(function(enter)
if not enter or inp.Text == "" then return end
local t = inp.Text
inp.Text = ""
line("> " .. t, C.dim)
line(tostring(RM.exec(t)))
end))
U.sec(p, "ДИАГНОСТИКА")
local g = G(p, 2)
A(g, "🩺 Диагностика", nil, function() for _, t in ipairs(RM.diag()) do line(t, C.warn) end end)
A(g, "🧪 Самопроверка", nil, function() for _, t in ipairs(RM.selfTest()) do line(t, t:sub(1, 1) == "✔" and C.ok or C.dg) end end)
A(g, "🐞 Журнал ошибок", nil, function() if #RM.errors == 0 then line("Ошибок нет", C.ok) end for _, t in ipairs(RM.errors) do line(t, C.dg) end end)
A(g, "🧹 Очистить", RED, function() clear() end)
end)
RM.addSection("settings", "⚙ Настройки", "настройки звук качество анимации мобильное сохранение экспорт", function(p)
U.sec(p, "КАЧЕСТВО И ИНТЕРФЕЙС")
U.cycle(p, "Качество", { "LOW", "MEDIUM", "HIGH" }, function() return ST.quality end, function(v) RM.setQuality(v) end)
U.slider(p, "Масштаб меню", .6, 1.6, function() return ST.uiScale end, function(v) ST.uiScale = v RM.applySize() end, "%.2f", .05)
U.toggle(p, "Эффекты переходов", function() return ST.dimfx end, function(v) ST.dimfx = v end)
U.toggle(p, "Уведомления", function() return ST.notif end, function(v) ST.notif = v end)
U.slider(p, "Время уведомления", .5, 10, function() return ST.notifTime end, function(v) ST.notifTime = v end, "%.1f с", .5)
U.cycle(p, "Клавиша меню", { "RightShift", "RightControl", "F4", "F6", "Insert", "Backquote" }, function() return ST.menuKey end, function(v) ST.menuKey = v end)
U.sec(p, "ЗВУК")
U.toggle(p, "Звук", function() return ST.sound end, function(v) ST.sound = v RM.applyVolume() end)
U.slider(p, "Общая громкость", 0, 1, function() return ST.master end, function(v) ST.master = v RM.applyVolume() end)
U.slider(p, "Эффекты", 0, 1, function() return ST.sfx end, function(v) ST.sfx = v RM.applyVolume() end)
U.slider(p, "Интерфейс", 0, 1, function() return ST.ui end, function(v) ST.ui = v RM.applyVolume() end)
local sg = G(p, 4, 28)
local cats = {}
for k in pairs(SFXCAT) do cats[#cats + 1] = k end
table.sort(cats)
for _, k in ipairs(cats) do A(sg, k, nil, function() snd(k, 1) end) end
U.sec(p, "МОБИЛЬНОЕ УПРАВЛЕНИЕ")
U.toggle(p, "Показывать кнопки на ПК", function() return RM.forceMob end, function(v) RM.forceMob = v end)
U.toggle(p, "Редактор расположения кнопок", function() return RM.mobEdit end, function(v) RM.mobEdit = v end)
U.slider(p, "Размер кнопок", .7, 1.6, function() return ST.mobScale end, function(v) ST.mobScale = v end, "%.2f", .05)
U.slider(p, "Размер прицела", 24, 200, function() return ST.aim end, function(v) ST.aim = v end, "%d", 2)
A(p, "Сбросить расположение кнопок", nil, function() RM.mobReset() end)
U.sec(p, "ANIMATION ID (числа; пусто = стандарт)")
U.info(p, "Свои ID вставляешь сам: скрипт ничего не подставляет. Покой/ходьба/бег/прыжок/падение/лазание/плавание применяются к Animate локально (можно после респавна). Эмоции проигрываются кнопкой ▶.")
for _, a in ipairs(ANIM) do
local box = U.input(p, a[2] .. " — Animation ID", SAVE.animIds[a[1]] or "")
conn(box.FocusLost:Connect(function()
local t = box.Text:gsub("%D", "")
SAVE.animIds[a[1]] = t ~= "" and t:sub(1, 19) or nil
box.Text = t:sub(1, 19)
animApply()
end))
if not a[3] then A(p, "▶ " .. a[2], nil, function() playEmote(a[1]) end, 28) end
end
U.sec(p, "СОХРАНЕНИЕ (в сессии; перенос кодом)")
local code = U.input(p, "код сохранения (JSON)")
local g = G(p, 2)
A(g, "📤 Экспорт", nil, function() code.Text = RM.export() notify("Скопируй код из поля (Ctrl+A, Ctrl+C)", C.ok) end)
A(g, "📥 Импорт", GREEN, function() local ok, e = RM.import(code.Text) notify(ok and "Импорт выполнен" or ("Ошибка: " .. tostring(e)), ok and C.ok or C.dg) if ok then RM.applySize() animApply() end end)
A(g, "♻ Сброс настроек", RED, function() RM.resetSettings() RM.applySize() notify("Настройки сброшены", C.ok) end)
A(g, "⏏ Выгрузить скрипт", RED, function() RM.unload() end)
U.info(p, "Без DataStore данные не переживают выход из игры: перед выходом нажми «Экспорт» и сохрани код.")
end)
end
do
local C = RM.C
RM.tickBad = {}
local function runTicks(list, dt, now)
for name, f in pairs(list) do
local ok, e = pcall(f, dt, now)
if not ok then
local n = (RM.tickBad[name] or 0) + 1
RM.tickBad[name] = n
RM.errors[#RM.errors + 1] = os.date("%H:%M:%S") .. " цикл " .. tostring(name) .. ": " .. str(e, 140)
if #RM.errors > 40 then table.remove(RM.errors, 1) end
warn("[RM6] цикл " .. tostring(name) .. ": " .. tostring(e))
if n >= 8 then
list[name] = nil
notify("⚠ Подсистема «" .. tostring(name) .. "» отключена после повторных ошибок", RGB(255, 90, 90), 5)
end
end
end
end
RM.ticks.energy = function(dt) EN.tick(dt) end
conn(RunService.Heartbeat:Connect(function(dt)
if RM.dead then return end
runTicks(RM.ticks, min(dt, .1), os.clock())
end))
conn(RunService.RenderStepped:Connect(function(dt)
if RM.dead or next(RM.rticks) == nil then return end
runTicks(RM.rticks, min(dt, .1), os.clock())
end))
local function onChar(ch)
if RM.dead then return end
pcall(RM.shipReset)
pcall(RM.droneStop)
if MODE.cur ~= "normal" and MODE.cur ~= "jet" then MODE.cur, MODE.who = "normal", nil end
RM.setCustomControls(false)
for _, f in ipairs(RM.charHooks) do task.spawn(function() safe("респавн", f, ch) end) end
end
conn(LP.CharacterAdded:Connect(onChar))
function RM.unload()
if RM.dead then return end
RM.dead = true
for _, c in ipairs(RM.conns) do pcall(function() c:Disconnect() end) end
for i = #RM.cleanups, 1, -1 do pcall(RM.cleanups[i]) end
pcall(RM.setCustomControls, false)
_G.RM_V6 = nil
print("[RM6] выгружено")
end
RM.unloadFn = RM.unload
RM.cleanups[#RM.cleanups + 1] = function() MODE.cur, MODE.who = "normal", nil end
RM.applyVolume()
pcall(RM.applyUnlocks)
RM.buildMenu()
RM.applySize()
if ST.dim ~= "C137" then pcall(RM.setDim, ST.dim, true) end
if LP.Character then task.spawn(onChar, LP.Character) end
notify("🌀 Rick & Morty Ultimate v" .. RM.ver .. " готов. Меню: кнопка 🌀 или " .. ST.menuKey, C.ac, 5)
print("[RM6] запущено, гаджетов: " .. #RM.gOrder)
end
