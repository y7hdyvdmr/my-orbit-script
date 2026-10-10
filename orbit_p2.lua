-- ORBIT v24.3-ai-fix2 | orbit_p2.lua
-- ОРБИТА v24.3-ai-fix2 — ЧАСТЬ 2/4: ФИГУРЫ (30 шт.)
-- v24.0: сердце 7×6, HEART_COLORS {name, c}.
-- v24.2-fix1: финальный блок не подменяет ORBIT.SHAPE_PRESETS целиком.
-- v24.3-ai: + САНС (№29), + ГАСТЕР (№30), перерисованы ФЛАУИ и ОМЕГА ФЛАУИ.
-- v24.3-ai-fix1:
--   * САНС: голубой глаз сдвинут вперёд на 0.10.
--   * ГАСТЕР: EyeGlow сдвинут вперёд на 0.12.
--   * ФЛАУИ: hexagon() пересчитан правильно (SQ3*L вместо 2*SQ3*L).
-- v24.3-ai-fix2:
--   * create3DBlasterPlaceholder перерисован под STRONG-форму (силуэт из Blender).
--   * В mkw (локальная обёртка WedgePart) добавлен NoRecolor и CanQuery/CanTouch=false
--     — иначе зубы/крылья перекрашивались бы в цвет игрока.
--   * В add добавлены CanQuery/CanTouch=false — чтобы превью в магазине
--     не мешало рейкастам.
--   * Убрана пустая заглушка bar(..., 0, 0), торчавшая из-под купола.

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P2] Часть 1 не загружена!"); return end

local newPart       = ORBIT.newPart
local newModelShell = ORBIT.newModelShell
local makeRod       = ORBIT.makeRod
local SETTINGS      = ORBIT.SETTINGS

if SETTINGS.HeartScale == nil then SETTINGS.HeartScale = 1 end

-- ============================================================
--                  ХЕЛПЕРЫ ФИГУР
-- ============================================================
local function isDetailed()
    return (SETTINGS.BlockCount or 8) <= 8
end
local function addBall(model, bodies, diameter, pos, color, noRecolor)
    local p = newPart(model, "Ball", Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color, noRecolor)
    p.Material = Enum.Material.SmoothPlastic
    local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
    table.insert(bodies, p)
    return p
end

local function create3DStar(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local R, r = size*0.85, size*0.85*0.382
    local t, d = size*0.14, size*0.24
    local verts = {}
    for k = 0, 9 do
        local angle = math.rad(90+k*36)
        local radius = (k%2==0) and R or r
        table.insert(verts, Vector3.new(math.cos(angle)*radius, math.sin(angle)*radius, 0))
    end
    for k = 1, 10 do table.insert(bodies, makeRod(model, verts[k], verts[(k%10)+1], t, d, color)) end
    table.insert(bodies, newPart(model, "C", Vector3.new(size*0.15, size*0.15, d*0.6), CFrame.new(), color))
    for k = 0, 4 do
        table.insert(bodies, makeRod(model, Vector3.new(0, 0, 0), verts[k*2 + 1] * 0.92, t*0.8, d*1.5, color))
    end
    for _, zs in ipairs({-1, 1}) do
        local bump = newPart(model, "Bump", Vector3.new(size*0.34, size*0.34, d*0.5), CFrame.new(0, 0, zs*d*0.55), color)
        local bm = Instance.new("SpecialMesh"); bm.MeshType = Enum.MeshType.Sphere; bm.Parent = bump
        table.insert(bodies, bump)
    end
    for k = 0, 4 do
        local ball = newPart(model, "Tip", Vector3.new(t*1.5, t*1.5, t*1.5), CFrame.new(verts[k*2 + 1]), color)
        local bm = Instance.new("SpecialMesh"); bm.MeshType = Enum.MeshType.Sphere; bm.Parent = ball
        table.insert(bodies, ball)
    end
    return model, root, bodies
end

local function create3DCross(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local bt, bd = size*0.32, size*0.28
    table.insert(bodies, newPart(model, "V", Vector3.new(bt, size*2.0, bd), CFrame.new(), color))
    table.insert(bodies, newPart(model, "H", Vector3.new(size*1.3, bt, bd), CFrame.new(0, size*0.35, 0), color))
    local capW, capD = bt*1.35, bd*1.25
    local capH = bt*0.35
    table.insert(bodies, newPart(model, "CapT", Vector3.new(capW, capH, capD), CFrame.new(0,  size*1.0 - capH*0.5, 0), color))
    table.insert(bodies, newPart(model, "CapB", Vector3.new(capW, capH, capD), CFrame.new(0, -size*1.0 + capH*0.5, 0), color))
    table.insert(bodies, newPart(model, "CapL", Vector3.new(capH, capW, capD), CFrame.new(-size*0.65 + capH*0.5, size*0.35, 0), color))
    table.insert(bodies, newPart(model, "CapR", Vector3.new(capH, capW, capD), CFrame.new( size*0.65 - capH*0.5, size*0.35, 0), color))
    addBall(model, bodies, bt*0.9, Vector3.new(0, size*0.35, bd*0.45), Color3.fromRGB(255, 235, 150), true)
    if isDetailed() then
        local gl = newPart(model, "Shine", Vector3.new(bt*0.18, size*1.5, bd*1.05), CFrame.new(-bt*0.25, -size*0.15, 0), Color3.fromRGB(255,255,255), true)
        gl.Transparency = 0.55; table.insert(bodies, gl)
    end
    return model, root, bodies
end

local function create3DSkull(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local bone = color or Color3.fromRGB(235,230,215)
    local socketShade = Color3.fromRGB(205,197,182)
    local dark = Color3.fromRGB(18,14,12)
    local toothColor = Color3.fromRGB(250,248,240)
    local function ell(sz, cf, col, nr)
        local p = newPart(model, "E", sz, cf, col, nr)
        p.Material = Enum.Material.SmoothPlastic
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
        table.insert(bodies, p); return p
    end
    local function blk(sz, cf, col, nr)
        local p = newPart(model, "B", sz, cf, col, nr)
        p.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, p); return p
    end
    ell(Vector3.new(1.15*s,1.10*s,1.10*s), CFrame.new(0,0.30*s,0.08*s), bone)
    ell(Vector3.new(0.85*s,0.70*s,0.75*s), CFrame.new(0,-0.16*s,-0.08*s), bone)
    ell(Vector3.new(0.90*s,0.16*s,0.30*s), CFrame.new(0,0.16*s,-0.36*s), bone)
    for _, side in ipairs({-1, 1}) do
        ell(Vector3.new(0.34*s,0.30*s,0.20*s), CFrame.new(side*0.30*s,0.26*s,-0.34*s), socketShade, true)
        ell(Vector3.new(0.30*s,0.26*s,0.30*s), CFrame.new(side*0.43*s,-0.02*s,-0.18*s), bone)
        ell(Vector3.new(0.42*s,0.40*s,0.14*s), CFrame.new(side*0.25*s,0.03*s,-0.41*s), bone)
        ell(Vector3.new(0.32*s,0.30*s,0.14*s), CFrame.new(side*0.25*s,0.03*s,-0.44*s), dark, true)
        blk(Vector3.new(0.09*s,0.62*s,0.30*s), CFrame.new(side*0.42*s,-0.35*s,0.02*s), bone)
    end
    local nose = newPart(model, "N", Vector3.new(0.20*s,0.26*s,0.14*s),
        CFrame.new(0,-0.22*s,-0.42*s)*CFrame.Angles(math.rad(180),0,0), dark, true)
    local nm = Instance.new("SpecialMesh"); nm.MeshType = Enum.MeshType.Pyramid; nm.Parent = nose
    table.insert(bodies, nose)
    ell(Vector3.new(0.80*s,0.46*s,0.62*s), CFrame.new(0,-0.62*s,-0.10*s), bone)
    blk(Vector3.new(0.62*s,0.05*s,0.20*s), CFrame.new(0,-0.47*s,-0.30*s), dark, true)
    for i = 1, 8 do
        local x = (i-4.5)*0.085*s
        local k = x/(0.3*s)
        blk(Vector3.new(0.08*s,0.13*s,0.09*s), CFrame.new(x,-0.40*s,(-0.37+k*k*0.08)*s), toothColor, true)
        blk(Vector3.new(0.075*s,0.12*s,0.09*s), CFrame.new(x,-0.53*s,(-0.35+k*k*0.08)*s), toothColor, true)
    end
    for _, side in ipairs({-1, 1}) do
        ell(Vector3.new(0.26*s,0.14*s,0.22*s), CFrame.new(side*0.47*s,-0.10*s,-0.22*s), bone)
        ell(Vector3.new(0.14*s,0.20*s,0.10*s), CFrame.new(side*0.50*s, 0.18*s,-0.12*s), socketShade, true)
        blk(Vector3.new(0.065*s,0.17*s,0.10*s), CFrame.new(side*0.20*s,-0.38*s,-0.38*s), toothColor, true)
        blk(Vector3.new(0.06*s,0.15*s,0.10*s),  CFrame.new(side*0.20*s,-0.56*s,-0.36*s), toothColor, true)
    end
    local crackCol = Color3.fromRGB(60, 52, 44)
    local function crack(pos, w, h, rotDeg)
        local c = newPart(model, "Crack", Vector3.new(w, h, 0.03*s), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(rotDeg)), crackCol, true)
        c.Material = Enum.Material.SmoothPlastic; table.insert(bodies, c)
    end
    crack(Vector3.new(0.10*s, 0.72*s, -0.466*s), 0.025*s, 0.18*s, 20)
    crack(Vector3.new(0.17*s, 0.62*s, -0.466*s), 0.025*s, 0.14*s, -25)
    crack(Vector3.new(0.13*s, 0.52*s, -0.466*s), 0.025*s, 0.10*s, 35)
    crack(Vector3.new(0.42*s, 0.16*s, -0.45*s), 0.02*s, 0.12*s, -30)
    for i = 1, 7 do
        local x = (i-4)*0.085*s
        blk(Vector3.new(0.01*s,0.24*s,0.06*s), CFrame.new(x,-0.46*s,-0.36*s), dark, true)
    end
    return model, root, bodies
end

local function addTriangle(parent, a, b, c, thickness, color, bodies)
    local ab, ac, bc = b-a, c-a, c-b
    local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
    if abd > acd and abd > bcd then c, a = a, c
    elseif acd > bcd and acd > abd then a, b = b, a end
    ab, ac, bc = b-a, c-a, c-b
    local right = ac:Cross(ab).Unit
    local up = bc:Cross(right).Unit
    local back = bc.Unit
    local height = math.abs(ab:Dot(up))
    local function wedge(lenZ, cf)
        local w = Instance.new("WedgePart")
        w.Name = "W"; w.Size = Vector3.new(thickness, height, lenZ); w.CFrame = cf
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
        w.Material = Enum.Material.SmoothPlastic; w.Color = color; w.Parent = parent
        table.insert(bodies, w)
    end
    wedge(math.abs(ab:Dot(back)), CFrame.fromMatrix((a+b)/2, right, up, back))
    wedge(math.abs(ac:Dot(back)), CFrame.fromMatrix((a+c)/2, -right, up, -back))
end

local function create3DLightning(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local u = size*2.0/227; local depth = size*0.28
    local function Pt(x, y) return Vector3.new(x*u, y*u, 0) end
    local p1, p2, p3 = Pt(-15,115), Pt(68,115), Pt(28,20)
    local p4, p5, p6, p7 = Pt(55,20), Pt(-42,-112), Pt(2,20), Pt(-55,20)
    addTriangle(model, p7, p3, p1, depth, color, bodies)
    addTriangle(model, p1, p3, p2, depth, color, bodies)
    addTriangle(model, p6, p4, p5, depth, color, bodies)
    local c = (Pt(0, 115) + Pt(0, -112)) * 0.5
    local function shrink(v) return c + (v - c) * 0.55 end
    local before = #bodies
    local core = depth * 1.25
    addTriangle(model, shrink(p7), shrink(p3), shrink(p1), core, Color3.fromRGB(255,255,255), bodies)
    addTriangle(model, shrink(p1), shrink(p3), shrink(p2), core, Color3.fromRGB(255,255,255), bodies)
    addTriangle(model, shrink(p6), shrink(p4), shrink(p5), core, Color3.fromRGB(255,255,255), bodies)
    for i = before + 1, #bodies do
        pcall(function() bodies[i]:SetAttribute("NoRecolor", true); bodies[i].Transparency = 0.2 end)
    end
    addBall(model, bodies, size*0.16, p5, Color3.fromRGB(255,255,200), true)
    addBall(model, bodies, size*0.16, p2, Color3.fromRGB(255,255,200), true)
    return model, root, bodies
end

local function createHead(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local head = newPart(model, "H", Vector3.new(size,size,size), CFrame.new(), color)
    head.Material = Enum.Material.SmoothPlastic
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Head; mesh.Scale = Vector3.new(size,size,size); mesh.Parent = head
    local face = Instance.new("Decal"); face.Face = Enum.NormalId.Front
    face.Texture = "rbxasset://textures/face.png"; face.Parent = head
    table.insert(bodies, head)
    local halo = newPart(model, "Halo", Vector3.new(size*0.06, size*0.85, size*0.85), CFrame.new(0, size*0.78, 0) * CFrame.Angles(0, 0, math.rad(90)),
        Color3.fromRGB(255, 235, 140), true)
    halo.Shape = Enum.PartType.Cylinder; halo.Transparency = 0.25; table.insert(bodies, halo)
    return model, root, bodies
end

local function create3DTriangle(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local R = size*0.75; local t, d = size*0.13, size*0.28
    local v1 = Vector3.new(0, R, 0)
    local v2 = Vector3.new(math.cos(math.rad(210))*R, math.sin(math.rad(210))*R, 0)
    local v3 = Vector3.new(math.cos(math.rad(330))*R, math.sin(math.rad(330))*R, 0)
    table.insert(bodies, makeRod(model, v1, v2, t, d, color))
    table.insert(bodies, makeRod(model, v2, v3, t, d, color))
    table.insert(bodies, makeRod(model, v3, v1, t, d, color))
    for _, v in ipairs({v1, v2, v3}) do addBall(model, bodies, t*1.6, v, color) end
    addBall(model, bodies, size*0.22, Vector3.new(0, 0, 0), Color3.fromRGB(255, 255, 255), true)
    if isDetailed() then
        local k = 0.5
        local w1, w2, w3 = v1*k, v2*k, v3*k
        table.insert(bodies, makeRod(model, w1, w2, t*0.5, d*0.7, color))
        table.insert(bodies, makeRod(model, w2, w3, t*0.5, d*0.7, color))
        table.insert(bodies, makeRod(model, w3, w1, t*0.5, d*0.7, color))
    end
    return model, root, bodies
end

local HEART_PATTERN = { "0110110", "1111111", "1111111", "0111110", "0011100", "0001000" }
local function createPixelHeart(sizeStuds, color, name)
    local rows, cols = #HEART_PATTERN, #HEART_PATTERN[1]
    local pixel = sizeStuds/cols
    local model, root = newModelShell(name); local bodies = {}
    for r = 1, rows do
        local row = HEART_PATTERN[r]
        local c = 1
        while c <= cols do
            if row:sub(c,c) == "1" then
                local sc = c
                while c <= cols and row:sub(c,c) == "1" do c = c + 1 end
                local ec = c - 1
                local width = (ec-sc+1)*pixel
                local cc = (sc+ec)/2
                local x = (cc-(cols+1)/2)*pixel
                local y = ((rows+1)/2 - r)*pixel
                table.insert(bodies, newPart(model, "P", Vector3.new(width, pixel, pixel), CFrame.new(x, y, 0), color))
            else c = c + 1 end
        end
    end
    for r = 1, rows do
        local row = HEART_PATTERN[r]
        local c = 1
        while c <= cols do
            if row:sub(c,c) == "1" then
                local sc = c
                while c <= cols and row:sub(c,c) == "1" do c = c + 1 end
                local ec = c - 1
                local width = (ec-sc+1)*pixel - pixel*0.35
                local cc = (sc+ec)/2
                local x = (cc-(cols+1)/2)*pixel
                local y = ((rows+1)/2 - r)*pixel
                local pad = newPart(model, "Bevel", Vector3.new(width, pixel*0.7, pixel*1.35), CFrame.new(x, y, 0), color)
                table.insert(bodies, pad)
            else c = c + 1 end
        end
    end
    local hx = (2.5 - (cols+1)/2)*pixel
    local hy = ((rows+1)/2 - 1)*pixel
    local shine = newPart(model, "Shine", Vector3.new(pixel*0.55, pixel*0.25, pixel*0.12), CFrame.new(hx, hy + pixel*0.12, -pixel*0.72), Color3.fromRGB(255,255,255), true)
    shine.Transparency = 0.15; table.insert(bodies, shine)
    local shine2 = newPart(model, "Shine", Vector3.new(pixel*0.2, pixel*0.2, pixel*0.12), CFrame.new(hx + pixel*0.45, hy - pixel*0.15, -pixel*0.72), Color3.fromRGB(255,255,255), true)
    shine2.Transparency = 0.3; table.insert(bodies, shine2)
    return model, root, bodies
end

local HEART_COLORS = {
    { name = "ОРАНЖЕВЫЙ", c = Color3.fromRGB(245, 145, 40) },
    { name = "ЖЁЛТЫЙ",    c = Color3.fromRGB(240, 230, 40) },
    { name = "МАДЖЕНТА",  c = Color3.fromRGB(230, 30, 200) },
    { name = "КРАСНЫЙ",   c = Color3.fromRGB(200, 25, 30) },
    { name = "ЛАЙМ",      c = Color3.fromRGB(120, 240, 60) },
    { name = "СИНИЙ",     c = Color3.fromRGB(30, 60, 230) },
    { name = "БИРЮЗОВЫЙ", c = Color3.fromRGB(60, 230, 200) },
}
ORBIT.createPixelHeart = createPixelHeart
ORBIT.HEART_COLORS = HEART_COLORS
ORBIT.PIX_HEART = HEART_PATTERN

local function heartColorByIdx(idx)
    if type(idx) == "number" then
        return HEART_COLORS[((math.floor(idx) - 1) % #HEART_COLORS) + 1].c
    end
    local P = ORBIT.P
    local pc = P and P.COLORS and P.COLORS[P.colorIndex or 1]
    if pc and pc.c then return pc.c end
    return HEART_COLORS[1].c
end
local function createPalmPlate(model, bodies, cf, size, color)
    local half = size*0.5; local cornerR = size*0.22
    local holeR = size*0.26; local depth = size*0.22
    local segments = 44
    for i = 1, segments do
        local a0 = (i-1)/segments*math.pi*2; local a1 = i/segments*math.pi*2
        local mid = (a0+a1)/2
        local cosA, sinA = math.cos(mid), math.sin(mid)
        local maxCoord = math.max(math.abs(cosA), math.abs(sinA))
        local outerR = (maxCoord > 0) and (half/maxCoord) or half
        local cx = math.clamp(cosA*outerR, -(half-cornerR), half-cornerR)
        local cy = math.clamp(sinA*outerR, -(half-cornerR), half-cornerR)
        local dx, dy = cosA*outerR - cx, sinA*outerR - cy
        local dlen = math.sqrt(dx*dx+dy*dy)
        if dlen > 0.001 then cx = cx + dx/dlen*cornerR; cy = cy + dy/dlen*cornerR end
        local outerPt = Vector3.new(cx, cy, 0)
        local innerPt = Vector3.new(math.cos(mid)*holeR, math.sin(mid)*holeR, 0)
        local midPt = (outerPt+innerPt)*0.5
        local segLen = (outerPt-innerPt).Magnitude
        local angle = math.atan2(outerPt.Y-innerPt.Y, outerPt.X-innerPt.X)
        local tangentLen = 2*math.pi*(half*0.7)/segments*1.4
        local partCF = cf * CFrame.new(midPt.X, midPt.Y, 0) * CFrame.Angles(0, 0, angle)
        table.insert(bodies, newPart(model, "Palm", Vector3.new(segLen, tangentLen, depth), partCF, color))
    end
    local spikeLen = holeR*0.65; local spikeW = holeR*0.38
    for k = 0, 3 do
        local ang = math.rad(k*90+45)
        local spikeCF = cf * CFrame.new(math.cos(ang)*(holeR-spikeLen*0.3), math.sin(ang)*(holeR-spikeLen*0.3), 0)
            * CFrame.Angles(0, 0, ang - math.pi/2)
        local w = Instance.new("WedgePart")
        w.Name = "Spike"; w.Size = Vector3.new(spikeW, spikeLen, depth*0.75); w.CFrame = spikeCF
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
        w.Material = Enum.Material.Neon; w.Color = color; w.Parent = model
        table.insert(bodies, w)
    end
end

local function createFinger(model, bodies, baseCF, length, width, color)
    local seg1, seg2, seg3 = length*0.30, length*0.38, length*0.32
    local w1, w2, w3, w4 = width, width*0.75, width*0.35, width*0.05
    table.insert(bodies, newPart(model, "F1", Vector3.new(w1, seg1, w1*0.5), baseCF*CFrame.new(0, seg1/2, 0), color))
    table.insert(bodies, newPart(model, "F2", Vector3.new(w2, seg2, w2*0.5), baseCF*CFrame.new(0, seg1+seg2/2, 0), color))
    table.insert(bodies, newPart(model, "F3", Vector3.new(w3, seg3*0.55, w3*0.45), baseCF*CFrame.new(0, seg1+seg2+seg3*0.275, 0), color))
    table.insert(bodies, newPart(model, "F4", Vector3.new(w4, seg3*0.45, w4*0.45), baseCF*CFrame.new(0, seg1+seg2+seg3*0.55+seg3*0.225, 0), color))
end

local function create3DHand(size, color, name, withHeart, heartColor)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local palmCF = CFrame.new(0, -s*0.10, 0)
    createPalmPlate(model, bodies, palmCF, s*2.2, color)
    if withHeart then
        local hc = heartColor or Color3.fromRGB(255,40,95)
        local heartSize = s*1.8*SETTINGS.HeartScale
        local hModel = select(1, createPixelHeart(heartSize, hc, "Heart"))
        hModel.Parent = model
        hModel:PivotTo(palmCF * CFrame.new(0, 0, s*0.02))
    end
    local wrapY = -s*1.20
    table.insert(bodies, newPart(model, "Wrap1", Vector3.new(s*2.4, s*0.26, s*0.40),
        palmCF * CFrame.new(0, wrapY, 0) * CFrame.Angles(0, 0, math.rad(14)), color))
    table.insert(bodies, newPart(model, "Wrap2", Vector3.new(s*2.4, s*0.26, s*0.40),
        palmCF * CFrame.new(0, wrapY, 0) * CFrame.Angles(0, 0, math.rad(-14)), color))
    local fingerBaseY = s*0.88
    local fingers = {
        {len=2.20,w=0.36,offsetX=-0.78}, {len=2.75,w=0.42,offsetX=-0.26},
        {len=2.75,w=0.42,offsetX= 0.26}, {len=2.20,w=0.36,offsetX= 0.78},
    }
    for _, f in ipairs(fingers) do
        createFinger(model, bodies, CFrame.new(f.offsetX*s, fingerBaseY, 0), s*f.len, s*f.w, color)
    end
    createFinger(model, bodies, CFrame.new(s*1.15, -s*0.10, 0)*CFrame.Angles(0, 0, math.rad(-42)), s*1.70, s*0.46, color)
    return model, root, bodies
end

local function create3DDiamond(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local R = size*0.75; local t, d = size*0.13, size*0.28
    local vT, vR = Vector3.new(0,R,0), Vector3.new(R*0.75,0,0)
    local vB, vL = Vector3.new(0,-R,0), Vector3.new(-R*0.75,0,0)
    table.insert(bodies, makeRod(model, vT, vR, t, d, color))
    table.insert(bodies, makeRod(model, vR, vB, t, d, color))
    table.insert(bodies, makeRod(model, vB, vL, t, d, color))
    table.insert(bodies, makeRod(model, vL, vT, t, d, color))
    table.insert(bodies, makeRod(model, vL, vR, t*0.55, d*0.8, color))
    for _, v in ipairs({vT, vR, vB, vL}) do addBall(model, bodies, t*1.5, v, color) end
    addBall(model, bodies, size*0.2, Vector3.new(0, 0, 0), Color3.fromRGB(255, 255, 255), true)
    if isDetailed() then
        table.insert(bodies, makeRod(model, vT, vB, t*0.55, d*0.8, color))
        local mT, mB = Vector3.new(0, R*0.5, 0), Vector3.new(0, -R*0.5, 0)
        table.insert(bodies, makeRod(model, mT + Vector3.new(-R*0.37, 0, 0), mT + Vector3.new(R*0.37, 0, 0), t*0.4, d*0.7, color))
        table.insert(bodies, makeRod(model, mB + Vector3.new(-R*0.37, 0, 0), mB + Vector3.new(R*0.37, 0, 0), t*0.4, d*0.7, color))
    end
    return model, root, bodies
end
local function createSword(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size; local gripColor = Color3.fromRGB(90,60,40)
    local function mp(nm, sz, cf, col, nr)
        local p = newPart(model, nm, sz, cf, col, nr); p.Material = Enum.Material.Metal
        table.insert(bodies, p); return p
    end
    mp("Blade", Vector3.new(s*0.16, s*2.9, s*0.09), CFrame.new(0, s*0.75, 0), color)
    mp("Fuller", Vector3.new(s*0.04, s*2.55, s*0.02), CFrame.new(0, s*0.75, s*0.045), Color3.fromRGB(150,160,175), true)
    local tip = Instance.new("WedgePart")
    tip.Name = "Tip"; tip.Size = Vector3.new(s*0.16, s*0.55, s*0.09)
    tip.CFrame = CFrame.new(0, s*2.475, 0)*CFrame.Angles(0, 0, math.rad(180))
    tip.Anchored = true; tip.CanCollide = false; tip.CastShadow = false
    tip.Material = Enum.Material.Metal; tip.Color = color; tip.Parent = model
    table.insert(bodies, tip)
    mp("Guard", Vector3.new(s*1.3, s*0.14, s*0.22), CFrame.new(0, -s*0.75, 0), color)
    local gL = mp("GuardKnobL", Vector3.new(s*0.17, s*0.17, s*0.17), CFrame.new(-s*0.65, -s*0.75, 0), color)
    local gLm = Instance.new("SpecialMesh"); gLm.MeshType = Enum.MeshType.Sphere; gLm.Parent = gL
    local gR = mp("GuardKnobR", Vector3.new(s*0.17, s*0.17, s*0.17), CFrame.new(s*0.65, -s*0.75, 0), color)
    local gRm = Instance.new("SpecialMesh"); gRm.MeshType = Enum.MeshType.Sphere; gRm.Parent = gR
    local grip = newPart(model, "Handle", Vector3.new(s*0.18, s*0.85, s*0.18), CFrame.new(0, -s*1.2, 0), gripColor, true)
    grip.Material = Enum.Material.Fabric; table.insert(bodies, grip)
    for i = 1, 4 do
        local wrap = newPart(model, "Wrap", Vector3.new(s*0.20, s*0.03, s*0.20),
            CFrame.new(0, -s*(0.85+i*0.16), 0), Color3.fromRGB(60,40,25), true)
        wrap.Material = Enum.Material.Fabric; table.insert(bodies, wrap)
    end
    local pommel = mp("Pommel", Vector3.new(s*0.30, s*0.30, s*0.30), CFrame.new(0, -s*1.72, 0), color)
    local pm = Instance.new("SpecialMesh"); pm.MeshType = Enum.MeshType.Sphere; pm.Parent = pommel
    local runeCol = Color3.fromRGB(55, 62, 78)
    for i = 1, 6 do
        local y = s*(0.05 + i*0.38)
        local w = s*(0.05 + (i % 2) * 0.03)
        local rune = mp("Rune", Vector3.new(w, s*0.025, s*0.02), CFrame.new(0, y, s*0.048), runeCol, true)
        rune.Material = Enum.Material.SmoothPlastic
        if i % 2 == 0 then
            local r2 = mp("RuneV", Vector3.new(s*0.025, s*0.09, s*0.02), CFrame.new(0, y + s*0.06, s*0.048), runeCol, true)
            r2.Material = Enum.Material.SmoothPlastic
        end
    end
    for _, sd in ipairs({-1, 1}) do
        local edge = mp("Edge", Vector3.new(s*0.025, s*2.9, s*0.095), CFrame.new(sd*s*0.07, s*0.75, 0), Color3.fromRGB(215, 222, 235), true)
        edge.Material = Enum.Material.Metal
    end
    for i = 0, 3 do
        local seg = newPart(model, "GripSeg", Vector3.new(s*0.21, s*0.1, s*0.21), CFrame.new(0, -s*(0.88 + i*0.2), 0),
            (i % 2 == 0) and Color3.fromRGB(110, 78, 52) or Color3.fromRGB(70, 46, 30), true)
        seg.Material = Enum.Material.Fabric; table.insert(bodies, seg)
    end
    for _, y in ipairs({-0.83, -1.6}) do
        mp("GripRing", Vector3.new(s*0.25, s*0.05, s*0.25), CFrame.new(0, s*y, 0), color)
    end
    local gem = newPart(model, "Gem", Vector3.new(s*0.2, s*0.2, s*0.14), CFrame.new(0, -s*0.75, -s*0.1), Color3.fromRGB(255, 60, 80), true)
    local gm = Instance.new("SpecialMesh"); gm.MeshType = Enum.MeshType.Sphere; gm.Parent = gem
    table.insert(bodies, gem)
    return model, root, bodies
end

local function createShield(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local rows, H, maxW, depth, roundFrac = 22, s*2.2, s*1.5, s*0.16, 0.24
    for r = 1, rows do
        local t = (r-0.5)/rows; local y = H*0.5 - t*H
        local width
        if t < roundFrac then
            local k = 1 - (t/roundFrac)
            width = maxW*math.sqrt(math.max(0, 1-k*k))
        else
            local k = (t-roundFrac)/(1-roundFrac)
            width = maxW*(1-k)
        end
        if width > s*0.03 then
            local p = newPart(model, "Row", Vector3.new(width, (H/rows)*1.08, depth), CFrame.new(0, y, 0), color)
            p.Material = Enum.Material.Metal; table.insert(bodies, p)
        end
    end
    local goldAccent = Color3.fromRGB(230,190,70)
    local crossV = newPart(model, "CrossV", Vector3.new(s*0.14, H*0.72, depth*1.7), CFrame.new(0, s*0.05, -depth*0.45), goldAccent, true)
    crossV.Material = Enum.Material.Metal; table.insert(bodies, crossV)
    local crossH = newPart(model, "CrossH", Vector3.new(maxW*0.6, s*0.14, depth*1.7), CFrame.new(0, s*0.35, -depth*0.45), goldAccent, true)
    crossH.Material = Enum.Material.Metal; table.insert(bodies, crossH)
    local boss = newPart(model, "Boss", Vector3.new(s*0.36, s*0.36, s*0.28), CFrame.new(0, s*0.35, -depth*0.55), goldAccent, true)
    boss.Material = Enum.Material.Metal
    local bm = Instance.new("SpecialMesh"); bm.MeshType = Enum.MeshType.Sphere; bm.Parent = boss
    table.insert(bodies, boss)
    local function rivet(x, y)
        local rv = newPart(model, "Rivet", Vector3.new(s*0.09, s*0.09, s*0.09), CFrame.new(x, y, -depth*0.55), goldAccent, true)
        rv.Material = Enum.Material.Metal
        local rm = Instance.new("SpecialMesh"); rm.MeshType = Enum.MeshType.Sphere; rm.Parent = rv
        table.insert(bodies, rv)
    end
    for r = 2, rows - 3, 3 do
        local t = (r-0.5)/rows; local y = H*0.5 - t*H
        local width
        if t < roundFrac then
            local k = 1 - (t/roundFrac); width = maxW*math.sqrt(math.max(0, 1-k*k))
        else
            local k = (t-roundFrac)/(1-roundFrac); width = maxW*(1-k)
        end
        if width > s*0.3 then
            rivet(-width*0.5 + s*0.08, y); rivet(width*0.5 - s*0.08, y)
        end
    end
    rivet(0, H*0.5 - s*0.1)
    local dia = newPart(model, "Diamond", Vector3.new(s*0.34, s*0.34, depth*1.5), CFrame.new(0, -s*0.4, -depth*0.45) * CFrame.Angles(0, 0, math.rad(45)), goldAccent, true)
    dia.Material = Enum.Material.Metal; table.insert(bodies, dia)
    local dia2 = newPart(model, "DiamondIn", Vector3.new(s*0.18, s*0.18, depth*1.7), CFrame.new(0, -s*0.4, -depth*0.5) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(150, 30, 40), true)
    dia2.Material = Enum.Material.SmoothPlastic; table.insert(bodies, dia2)
    for _, sd in ipairs({-1, 1}) do
        local st = newPart(model, "Stripe", Vector3.new(s*0.06, s*0.45, depth*1.5), CFrame.new(sd*s*0.38, s*0.0, -depth*0.42), goldAccent, true)
        st.Material = Enum.Material.Metal; table.insert(bodies, st)
    end
    return model, root, bodies
end

local function createBone(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    table.insert(bodies, newPart(model, "Shaft", Vector3.new(s*0.3, s*1.8, s*0.3), CFrame.new(0, 0, 0), color))
    for _, side in ipairs({-1, 1}) do
        local top = newPart(model, "Top", Vector3.new(s*0.5, s*0.4, s*0.5), CFrame.new(side*s*0.25, s*1.0, 0), color)
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = top
        table.insert(bodies, top)
        local bot = newPart(model, "Bot", Vector3.new(s*0.5, s*0.4, s*0.5), CFrame.new(side*s*0.25, -s*1.0, 0), color)
        local m2 = Instance.new("SpecialMesh"); m2.MeshType = Enum.MeshType.Sphere; m2.Parent = bot
        table.insert(bodies, bot)
    end
    for _, y in ipairs({s*0.78, -s*0.78}) do
        table.insert(bodies, newPart(model, "Joint", Vector3.new(s*0.42, s*0.14, s*0.42), CFrame.new(0, y, 0), color))
    end
    local crack = newPart(model, "Crack", Vector3.new(s*0.08, s*0.5, s*0.32), CFrame.new(s*0.1, s*0.12, 0) * CFrame.Angles(0, 0, math.rad(12)),
        Color3.fromRGB(40, 36, 30), true)
    crack.Material = Enum.Material.SmoothPlastic; table.insert(bodies, crack)
    if isDetailed() then
        local w = newPart(model, "Wear", Vector3.new(s*0.22, s*0.1, s*0.34), CFrame.new(-s*0.02, -s*0.4, 0), Color3.fromRGB(40, 36, 30), true)
        w.Material = Enum.Material.SmoothPlastic; table.insert(bodies, w)
    end
    return model, root, bodies
end

local function createPyramid(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local tiers, totalH, baseW = 5, s*1.8, s*1.7
    local tierH = totalH/tiers
    for i = 1, tiers do
        local t = (i-1)/tiers
        local w = baseW*(1-t)
        local y = -totalH*0.5 + (i-0.5)*tierH
        local block = newPart(model, "Tier", Vector3.new(w, tierH*0.96, w), CFrame.new(0, y, 0), color)
        block.Material = Enum.Material.Sand; table.insert(bodies, block)
    end
    local capH = tierH*0.9
    local cap = newPart(model, "Capstone", Vector3.new(s*0.22, capH, s*0.22),
        CFrame.new(0, totalH*0.5+capH*0.5, 0), Color3.fromRGB(255,220,120), true)
    cap.Material = Enum.Material.Metal
    local cm = Instance.new("SpecialMesh"); cm.MeshType = Enum.MeshType.Pyramid; cm.Parent = cap
    table.insert(bodies, cap)
    local plinth = newPart(model, "Plinth", Vector3.new(baseW*1.12, tierH*0.3, baseW*1.12), CFrame.new(0, -totalH*0.5 - tierH*0.12, 0), color)
    plinth.Material = Enum.Material.Sand; table.insert(bodies, plinth)
    local door = newPart(model, "Door", Vector3.new(s*0.28, tierH*0.8, s*0.12), CFrame.new(0, -totalH*0.5 + tierH*0.4, -baseW*0.5 - s*0.02),
        Color3.fromRGB(30, 22, 15), true)
    door.Material = Enum.Material.SmoothPlastic; table.insert(bodies, door)
    addBall(model, bodies, s*0.2, Vector3.new(0, totalH*0.1, -baseW*0.3), Color3.fromRGB(120, 255, 255), true)
    return model, root, bodies
end
local function createYinYang(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size; local R = s*0.95; local depth = s*0.22
    local whiteColor = Color3.fromRGB(245,245,250)
    local blackColor = Color3.fromRGB(20,20,25)
    local rows = 34; local pixel = (R*2)/rows
    local function classify(x, y)
        local dist = math.sqrt(x*x+y*y)
        if dist > R then return nil end
        local halfR = R*0.5
        if y >= 0 then
            return (math.sqrt(x*x+(y-halfR)^2) <= halfR) and "black" or "white"
        else
            return (math.sqrt(x*x+(y+halfR)^2) <= halfR) and "white" or "black"
        end
    end
    for r = 1, rows do
        local y = ((rows+1)/2 - r)*pixel
        local c = 1
        while c <= rows do
            local x = (c-(rows+1)/2)*pixel
            local col = classify(x, y)
            if col then
                local sc = c
                while c <= rows do
                    local x2 = (c-(rows+1)/2)*pixel
                    if classify(x2, y) ~= col then break end
                    c = c + 1
                end
                local ec = c - 1
                local width = (ec-sc+1)*pixel
                local cc = (sc+ec)/2
                local px = (cc-(rows+1)/2)*pixel
                local pc = (col == "white") and whiteColor or blackColor
                local p = newPart(model, col, Vector3.new(width, pixel, depth), CFrame.new(px, y, 0), pc, true)
                p.Material = Enum.Material.SmoothPlastic; table.insert(bodies, p)
            else c = c + 1 end
        end
    end
    local function dot(y, col)
        local d = newPart(model, "Dot", Vector3.new(R*0.26, R*0.26, depth*1.25), CFrame.new(0, y, 0), col, true)
        d.Material = Enum.Material.SmoothPlastic
        local dm = Instance.new("SpecialMesh"); dm.MeshType = Enum.MeshType.Sphere; dm.Parent = d
        table.insert(bodies, d)
    end
    dot( R*0.5, whiteColor)
    dot(-R*0.5, blackColor)
    local rimN = 36
    local prevRim = Vector3.new(R*1.03, 0, 0)
    for k = 1, rimN do
        local a = k/rimN*math.pi*2
        local cur = Vector3.new(math.cos(a)*R*1.03, math.sin(a)*R*1.03, 0)
        local rim = makeRod(model, prevRim, cur, pixel*0.7, depth*1.2, Color3.fromRGB(215, 185, 90))
        rim.Material = Enum.Material.Metal; rim:SetAttribute("NoRecolor", true)
        table.insert(bodies, rim); prevRim = cur
    end
    return model, root, bodies
end

local function createEye(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local sclera = newPart(model, "Sclera", Vector3.new(s*1.5, s*1.0, s*0.7), CFrame.new(), Color3.fromRGB(250,248,245), true)
    sclera.Material = Enum.Material.SmoothPlastic
    local scMesh = Instance.new("SpecialMesh"); scMesh.MeshType = Enum.MeshType.Sphere; scMesh.Parent = sclera
    table.insert(bodies, sclera)
    local iris = newPart(model, "Iris", Vector3.new(s*0.62, s*0.62, s*0.18),
        CFrame.new(0, 0, s*0.32)*CFrame.Angles(math.rad(90), 0, 0), color)
    iris.Material = Enum.Material.SmoothPlastic
    local irMesh = Instance.new("SpecialMesh"); irMesh.MeshType = Enum.MeshType.Cylinder; irMesh.Parent = iris
    table.insert(bodies, iris)
    local pupil = newPart(model, "Pupil", Vector3.new(s*0.28, s*0.28, s*0.11),
        CFrame.new(0, 0, s*0.40)*CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(10,10,12), true)
    pupil.Material = Enum.Material.SmoothPlastic
    local puMesh = Instance.new("SpecialMesh"); puMesh.MeshType = Enum.MeshType.Cylinder; puMesh.Parent = pupil
    table.insert(bodies, pupil)
    local glint = newPart(model, "Glint", Vector3.new(s*0.10, s*0.10, s*0.06),
        CFrame.new(s*0.14, s*0.14, s*0.46), Color3.fromRGB(255,255,255), true)
    glint.Material = Enum.Material.Neon
    local glMesh = Instance.new("SpecialMesh"); glMesh.MeshType = Enum.MeshType.Sphere; glMesh.Parent = glint
    table.insert(bodies, glint)
    for _, sign in ipairs({1, -1}) do
        local lid = newPart(model, "Lid", Vector3.new(s*1.65, s*0.18, s*0.55),
            CFrame.new(0, sign*s*0.5, s*0.05), Color3.fromRGB(225,205,185), true)
        lid.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, lid)
    end
    local limbus = newPart(model, "Limbus", Vector3.new(s*0.72, s*0.72, s*0.12),
        CFrame.new(0, 0, s*0.30)*CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(25, 30, 45), true)
    limbus.Material = Enum.Material.SmoothPlastic
    local lm = Instance.new("SpecialMesh"); lm.MeshType = Enum.MeshType.Cylinder; lm.Parent = limbus
    table.insert(bodies, limbus)
    local glint2 = newPart(model, "Glint", Vector3.new(s*0.05, s*0.05, s*0.04), CFrame.new(-s*0.1, -s*0.1, s*0.45), Color3.fromRGB(255,255,255), true)
    glint2.Material = Enum.Material.Neon
    local g2m = Instance.new("SpecialMesh"); g2m.MeshType = Enum.MeshType.Sphere; g2m.Parent = glint2
    table.insert(bodies, glint2)
    if (SETTINGS.BlockCount or 8) <= 8 then
        local veinCol = Color3.fromRGB(215, 90, 90)
        for i, v in ipairs({{-0.55, 0.12, 20}, {-0.5, -0.15, -25}, {0.55, 0.1, -20}, {0.5, -0.18, 28}}) do
            local vein = newPart(model, "Vein", Vector3.new(s*0.28, s*0.015, s*0.015),
                CFrame.new(v[1]*s, v[2]*s, s*0.30) * CFrame.Angles(0, 0, math.rad(v[3])), veinCol, true)
            vein.Material = Enum.Material.SmoothPlastic; table.insert(bodies, vein)
        end
        for k = -2, 2 do
            local lash = newPart(model, "Lash", Vector3.new(s*0.03, s*0.16, s*0.03),
                CFrame.new(k*s*0.28, s*0.62, s*0.2) * CFrame.Angles(0, 0, math.rad(-k*10)), Color3.fromRGB(35, 28, 28), true)
            lash.Material = Enum.Material.SmoothPlastic; table.insert(bodies, lash)
        end
    end
    return model, root, bodies
end

local function createSpiral(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local turns, segments = 3, 48
    local radius, height, thickness = s*0.55, s*2.0, s*0.10
    local prev = Vector3.new(radius, -height*0.5, 0)
    for i = 1, segments do
        local t = i/segments
        local angle = t*math.pi*2*turns
        local cur = Vector3.new(math.cos(angle)*radius, -height*0.5+t*height, math.sin(angle)*radius)
        table.insert(bodies, makeRod(model, prev, cur, thickness, thickness, color))
        prev = cur
    end
    addBall(model, bodies, thickness*2.2, Vector3.new(radius, -height*0.5, 0), color)
    addBall(model, bodies, thickness*2.2, prev, color)
    local axis = newPart(model, "Axis", Vector3.new(thickness*0.5, height*0.98, thickness*0.5), CFrame.new(), Color3.fromRGB(255,255,255), true)
    axis.Transparency = 0.5; table.insert(bodies, axis)
    if (SETTINGS.BlockCount or 8) <= 6 then
        local seg2 = 24
        local prev2 = Vector3.new(-radius, -height*0.5, 0)
        for i = 1, seg2 do
            local t = i/seg2
            local angle = t*math.pi*2*turns + math.pi
            local cur = Vector3.new(math.cos(angle)*radius, -height*0.5+t*height, math.sin(angle)*radius)
            table.insert(bodies, makeRod(model, prev2, cur, thickness*0.8, thickness*0.8, color))
            prev2 = cur
        end
    end
    return model, root, bodies
end

-- ============================================================
--  v24.3-ai-fix2: create3DBlasterPlaceholder (STRONG) — форма из orbit_gaster.lua
-- ============================================================
local function create3DBlasterPlaceholder(size, color, name)
    local V3, C3, CF = Vector3.new, Color3.fromRGB, CFrame.new
    local MAT = {
        Marble = Enum.Material.Marble,
        Metal = Enum.Material.Metal,
        SmoothPlastic = Enum.Material.SmoothPlastic,
        Neon = Enum.Material.Neon,
    }
    local model, root = newModelShell(name or "Gaster")
    local bodies = {}
    local s = size
    local u = s * 0.75
    local tiny = s < 1
    local BONE, DARK, ENG = C3(245, 245, 250), C3(15, 15, 20), C3(60, 55, 50)
    local RIB, GLOW = C3(215, 220, 230), C3(210, 235, 255)

    -- локальная обёртка для WedgePart
    -- v24.3-ai-fix2: добавлен NoRecolor + CanQuery/CanTouch = false
    local function mkw(m, n, sz, cf, col, mat)
        local w = Instance.new("WedgePart")
        w.Name = n; w.Size = sz; w.CFrame = cf
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
        w.CanQuery = false; w.CanTouch = false
        w.Material = mat or MAT.SmoothPlastic; w.Color = col
        w:SetAttribute("NoRecolor", true)
        w.Parent = m
        return w
    end

    -- v24.3-ai-fix2: добавлены CanQuery/CanTouch = false
    local function add(n, sz, cf, col, mat, nr, tr)
        local p = newPart(model, n, sz, cf, col, nr)
        if mat then p.Material = mat end
        if tr then p.Transparency = tr end
        p.CanQuery = false; p.CanTouch = false
        table.insert(bodies, p)
        return p
    end
    local function U(p) return V3(p.X * u, (p.Z - 1.7) * u, (p.Y - 1.6) * u) end
    local function bar(n, a, b, w, h, col, mat, tr)
        local pa, pb = U(a), U(b)
        local len = (pb - pa).Magnitude
        if len < 0.01 then return nil end
        return add(n, V3(w * u, h * u, len), CFrame.lookAt((pa + pb) / 2, pb), col or BONE, mat or MAT.Marble, true, tr)
    end
    local function wedge(n, a, b, th, wd, col, mat)
        local pa, pb = U(a), U(b)
        local len = (pb - pa).Magnitude
        if len < 0.01 then return nil end
        local p = mkw(model, n, V3(th * u, wd * u, len), CFrame.lookAt((pa + pb) / 2, pb), col or BONE, mat)
        table.insert(bodies, p)
        return p
    end

    -- череп
    bar("Skull", V3(0, 0.1, 0.8), V3(0, 1.3, 2.0), 1.25, 1.0)
    bar("SkullBack", V3(0, 1.2, 1.9), V3(0, 2.7, 3.2), 2.0, 1.0)
    bar("Dome", V3(0, 2.0, 2.6), V3(0, 3.0, 3.4), 1.7, 0.7)
    bar("Brow", V3(-0.75, 0.9, 2.0), V3(0.75, 0.9, 2.0), 0.35, 0.28)
    for _, sd in ipairs({ -1, 1 }) do
        bar("Cheek", V3(sd * 0.55, 0.3, 0.7), V3(sd * 0.95, 1.6, 1.4), 0.3, 0.35)
    end
    -- морда, нос
    bar("Snout", V3(0, -0.2, 1.2), V3(0, 1.0, 1.6), 0.65, 0.5)
    bar("NosePlate", V3(0, -0.22, 1.55), V3(0, 0.6, 1.85), 0.3, 0.12, RIB, MAT.Metal)
    -- челюсть, боковые отростки
    bar("Jaw", V3(0, -0.2, 0.35), V3(0, 1.3, 0.75), 0.6, 0.28)
    bar("Chin", V3(0, -0.28, 0.2), V3(0, 0.1, 0.45), 0.4, 0.3)
    for _, sd in ipairs({ -1, 1 }) do
        bar("JawSide", V3(sd * 0.4, 0.4, 0.55), V3(sd * 1.2, 2.4, 1.25), 0.2, 0.16)
        wedge("JawSpike", V3(sd * 1.2, 2.4, 1.25), V3(sd * 1.55, 3.0, 1.3), 0.14, 0.3)
        wedge("JawSpike", V3(sd * 0.9, 1.5, 0.95), V3(sd * 1.4, 1.9, 1.05), 0.12, 0.24)
    end
    -- зубы
    for _, sd in ipairs({ -1, 1 }) do
        for i = 0, 3 do
            local c = U(V3(sd * (0.2 + 0.07 * i), 0.0 + 0.3 * i, 0.83))
            local t = mkw(model, "ToothU", V3(0.1 * u, 0.3 * u, 0.12 * u), CF(c) * CFrame.Angles(math.pi, 0, 0), BONE, MAT.Marble)
            table.insert(bodies, t)
        end
        for i = 0, 2 do
            local c = U(V3(sd * (0.17 + 0.06 * i), 0.1 + 0.3 * i, 0.63))
            local t = mkw(model, "ToothL", V3(0.09 * u, 0.26 * u, 0.12 * u), CF(c), BONE, MAT.Marble)
            table.insert(bodies, t)
        end
    end
    -- пасть
    bar("MouthDark", V3(0, 0.15, 0.75), V3(0, 1.5, 0.9), 0.5, 0.4, DARK, MAT.SmoothPlastic)
    local mg = add("MouthGlow", V3(0.4 * u, 0.4 * u, 0.4 * u), CF(U(V3(0, 0.5, 0.75))), GLOW, MAT.Neon, true, 0.35)
    mg.Shape = Enum.PartType.Ball
    local ml = Instance.new("PointLight"); ml.Name = "MouthLight"; ml.Color = GLOW; ml.Range = 8; ml.Brightness = 1.2; ml.Parent = mg
    -- глазницы
    for _, sd in ipairs({ -1, 1 }) do
        local pos = U(V3(sd * 0.64, 0.85, 1.7))
        local dir = V3(sd * 0.85, 0.2, -0.5).Unit
        local base = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
        local sock = add("EyeSocket", V3(0.12 * u, 0.72 * u, 0.72 * u), base, DARK, MAT.SmoothPlastic, true)
        sock.Shape = Enum.PartType.Cylinder
        local ring = add("EyeRing", V3(0.05 * u, 0.5 * u, 0.5 * u), base + dir * (0.07 * u), GLOW, MAT.Neon, true)
        ring.Shape = Enum.PartType.Cylinder
        local inner = add("EyeInner", V3(0.05 * u, 0.34 * u, 0.34 * u), base + dir * (0.095 * u), DARK, MAT.SmoothPlastic, true)
        inner.Shape = Enum.PartType.Cylinder
        local pupil = add("EyeGlint", V3(0.2 * u, 0.2 * u, 0.2 * u), base + dir * (0.13 * u), GLOW, MAT.Neon, true)
        pupil.Shape = Enum.PartType.Ball
        local pl = Instance.new("PointLight"); pl.Name = "EyeLight"; pl.Color = GLOW; pl.Range = 7; pl.Brightness = 1.4; pl.Parent = pupil
    end
    -- крылья
    local wings = {
        { V3(0.45, 2.3, 2.9), V3(1.0, 3.5, 3.8), 0.8 },
        { V3(0.8, 2.3, 2.4), V3(1.35, 3.45, 3.15), 0.7 },
        { V3(1.05, 2.2, 1.8), V3(1.6, 3.25, 2.3), 0.6 },
    }
    for _, sd in ipairs({ -1, 1 }) do
        for _, w in ipairs(wings) do
            local a = V3(sd * w[1].X, w[1].Y, w[1].Z)
            local b = V3(sd * w[2].X, w[2].Y, w[2].Z)
            wedge("Wing", a, b, 0.14, w[3], BONE, MAT.Marble)
            local inA = V3(a.X - sd * 0.09, a.Y, a.Z)
            local inB = V3(a.X - sd * 0.09, a.Y, a.Z) + (b - a) * 0.86
            wedge("WingInner", inA, inB, 0.1, w[3] * 0.7, DARK, MAT.SmoothPlastic)
            if not tiny then
                bar("WingRib", V3(a.X + sd * 0.08, a.Y, a.Z), V3(b.X + sd * 0.08, b.Y, b.Z), 0.06, 0.06, RIB, MAT.Metal)
            end
        end
    end
    wedge("Crest", V3(0, 2.6, 3.2), V3(0, 3.5, 3.8), 0.22, 0.6, BONE, MAT.Marble)
    wedge("CrestInner", V3(0, 2.6, 3.2), V3(0, 3.3, 3.65), 0.1, 0.4, DARK, MAT.SmoothPlastic)

    if not tiny then
        local A2, B2, NUP = V3(0, 1.2, 1.9), V3(0, 2.7, 3.2), V3(0, -0.6549, 0.7556)
        local function top(t, x, off) return A2 + (B2 - A2) * t + NUP * (0.5 + off) + V3(x, 0, 0) end
        bar("Engrave", top(0.15, 0, 0.01), top(0.85, 0, 0.01), 0.06, 0.02, ENG, MAT.SmoothPlastic)
        for _, sd in ipairs({ -1, 1 }) do
            bar("Engrave", top(0.25, sd * 0.5, 0.01), top(0.8, sd * 0.5, 0.01), 0.05, 0.02, ENG, MAT.SmoothPlastic)
        end
        for _, t in ipairs({ 0.4, 0.6, 0.8 }) do
            bar("Engrave", top(t, -0.45, 0.01), top(t, 0.45, 0.01), 0.05, 0.02, ENG, MAT.SmoothPlastic)
        end
        for _, t in ipairs({ 0.3, 0.5, 0.7 }) do
            bar("Rib", top(t, -0.8, 0.04), top(t, 0.8, 0.04), 0.09, 0.08, RIB, MAT.Metal)
        end
        for _, sd in ipairs({ -1, 1 }) do
            bar("Rib", top(0.15, sd * 0.8, 0.04), top(0.9, sd * 0.8, 0.04), 0.1, 0.08, RIB, MAT.Metal)
        end
        local aura = add("Aura", V3(2.6 * u, 2.6 * u, 2.6 * u), CF(U(V3(0, 2.4, 2.9))), GLOW, MAT.Neon, true, 0.92)
        aura.Shape = Enum.PartType.Ball
        local ad = V3(0, 0.6549, 0.7556)
        for _, r in ipairs({ { V3(0, 2.2, 2.7), 2.5, 0.8 }, { V3(0, 2.7, 3.2), 1.9, 0.75 } }) do
            local pos = U(r[1])
            local ar = add("AuraRing", V3(0.05 * u, r[2] * u, r[2] * u), CFrame.lookAt(pos, pos + ad) * CFrame.Angles(0, math.rad(90), 0), GLOW, MAT.Neon, true, r[3])
            ar.Shape = Enum.PartType.Cylinder
        end
    end

    local cz = U(V3(0, -0.38, 0.72))
    local charge = add("Charge", V3(0.3 * s, 0.3 * s, 0.3 * s), CF(cz), C3(240, 250, 255), MAT.Neon, true, 0.2)
    charge.Shape = Enum.PartType.Ball
    add("Beam", V3(0.28 * s, 0.22 * s, 1.4 * s), CF(cz.X, cz.Y, cz.Z - 0.75 * s), C3(255, 255, 255), MAT.Neon, true, 0.3)
    local l = Instance.new("PointLight")
    l.Name = "GLight"; l.Color = C3(230, 240, 255); l.Range = 12; l.Brightness = 1.5; l.Parent = charge
    local e = Instance.new("ParticleEmitter")
    e.Name = "GSparks"; e.Color = ColorSequence.new(C3(230, 240, 255)); e.LightEmission = 1
    e.Size = NumberSequence.new(0.25 * s * 0.3, 0); e.Lifetime = NumberRange.new(0.5, 1)
    e.Speed = NumberRange.new(1, 3); e.SpreadAngle = Vector2.new(180, 180); e.Rate = 15; e.Parent = charge

    return { model = model, part = root, isModel = true, bodyParts = bodies, visualSize = s * 3.4 }
end
local function createWings(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local function feather(cx, cy, side, len, w, spreadDeg, droopDeg)
        local cf = CFrame.new(cx, cy, 0)
            *CFrame.Angles(0, math.rad(side*spreadDeg), 0)
            *CFrame.Angles(math.rad(-droopDeg), 0, 0)
            *CFrame.new(0, 0, -len*0.5)
        local f = Instance.new("WedgePart")
        f.Name = "Feather"; f.Size = Vector3.new(w, s*0.06, len); f.CFrame = cf
        f.Anchored = true; f.CanCollide = false; f.CastShadow = false
        f.Material = Enum.Material.SmoothPlastic; f.Color = color; f.Parent = model
        table.insert(bodies, f)
    end
    for _, side in ipairs({-1, 1}) do
        local prevPos = Vector3.new(side*s*0.15, 0, 0)
        for seg = 1, 5 do
            local t = seg/5
            local arcAngle = t*math.rad(75)
            local bx = side*(s*0.15 + math.sin(arcAngle)*s*1.5)
            local by = math.cos(arcAngle)*s*0.4 + t*s*0.3
            local pos = Vector3.new(bx, by, 0)
            local rod = makeRod(model, prevPos, pos, s*0.16, s*0.12, color)
            rod.Material = Enum.Material.SmoothPlastic
            table.insert(bodies, rod); prevPos = pos
        end
        for i = 1, 8 do
            local t = (i-1)/7
            local arcAngle = t*math.rad(75)
            local bx = side*(s*0.15 + math.sin(arcAngle)*s*1.5)
            local by = math.cos(arcAngle)*s*0.4 + t*s*0.3
            feather(bx, by, side, s*(2.0-t*1.2), s*(0.30-t*0.13), 22+t*48, t*22)
        end
        for i = 1, 6 do
            local t = (i-1)/5
            local arcAngle = 0.15 + t*math.rad(45)
            local bx = side*(s*0.15 + math.sin(arcAngle)*s*0.9)
            local by = (math.cos(arcAngle)*s*0.25 + t*s*0.15)*0.4 + s*0.15
            feather(bx, by, side, s*0.75, s*0.22, 10+t*20, t*10)
        end
        for i = 1, 9 do
            local t = (i-1)/8
            local arcAngle = t*math.rad(62)
            local bx = side*(s*0.15 + math.sin(arcAngle)*s*1.15)
            local by = math.cos(arcAngle)*s*0.33 + t*s*0.24 + s*0.07
            feather(bx, by, side, s*(0.55 - t*0.18), s*(0.18 - t*0.05), 14 + t*34, 4 + t*14)
        end
        for i = 1, 4 do
            local t = (i-1)/3
            feather(side*(s*0.18 + t*s*0.25), s*(0.18 + t*0.02), side, s*0.32, s*0.12, 4 + t*10, 2)
        end
    end
    return model, root, bodies
end

local function createTentacle(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local segments = 10
    local prevPos = Vector3.new(0, -s*0.9, 0)
    for i = 1, segments do
        local t = i/segments
        local curl = t*t*math.rad(200)
        local pos = Vector3.new(math.sin(curl)*s*0.9*t, -s*0.9+t*s*1.8, (1-math.cos(curl))*s*0.5*t)
        local thickness = s*0.42*(1-t*0.75) + s*0.05
        local seg = newPart(model, "Seg", Vector3.new(thickness, thickness, thickness), CFrame.new(pos), color)
        seg.Material = Enum.Material.SmoothPlastic
        local sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere; sm.Parent = seg
        table.insert(bodies, seg)
        if i % 2 == 0 and t < 0.85 then
            local sucker = newPart(model, "Sucker", Vector3.new(thickness*0.55, thickness*0.55, thickness*0.2),
                CFrame.new(pos)*CFrame.new(0, 0, thickness*0.4), Color3.fromRGB(255,200,210), true)
            sucker.Material = Enum.Material.SmoothPlastic
            local suM = Instance.new("SpecialMesh"); suM.MeshType = Enum.MeshType.Cylinder; suM.Parent = sucker
            table.insert(bodies, sucker)
        end
        if i > 1 then
            local rod = makeRod(model, prevPos, pos, thickness*0.85, thickness*0.85, color)
            rod.Material = Enum.Material.SmoothPlastic
            table.insert(bodies, rod)
        end
        prevPos = pos
        if i == segments then
            local tipBall = newPart(model, "TipBulb", Vector3.new(thickness*1.5, thickness*1.5, thickness*1.5), CFrame.new(pos), Color3.fromRGB(255, 215, 225), true)
            tipBall.Material = Enum.Material.SmoothPlastic
            local tm = Instance.new("SpecialMesh"); tm.MeshType = Enum.MeshType.Sphere; tm.Parent = tipBall
            table.insert(bodies, tipBall)
        end
    end
    local baseRing = newPart(model, "BaseRing", Vector3.new(s*0.62, s*0.14, s*0.62), CFrame.new(0, -s*0.95, 0), Color3.fromRGB(80, 40, 60), true)
    baseRing.Material = Enum.Material.SmoothPlastic; table.insert(bodies, baseRing)
    return model, root, bodies
end

local function createRock(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local fine = isDetailed()

    local suit     = color or Color3.fromRGB(70, 22, 92)
    local skin     = Color3.fromRGB(190, 140, 106)
    local shirtCol = Color3.fromRGB(246, 246, 250)
    local shoeCol  = Color3.fromRGB(168, 170, 180)
    local darkCol  = Color3.fromRGB(28, 22, 30)
    local goldCol  = Color3.fromRGB(232, 192, 92)
    local watchCol = Color3.fromRGB(30, 48, 90)
    local plastic, fabric, metal = Enum.Material.SmoothPlastic, Enum.Material.Fabric, Enum.Material.Metal

    local function V(x, y, z) return Vector3.new(x*s, y*s, z*s) end
    local function P(x, y, z) return CFrame.new(x*s, y*s, z*s) end
    local function blk(sz, cf, col, nr, mat)
        local p = newPart(model, "B", sz, cf, col, nr)
        p.Material = mat or fabric
        table.insert(bodies, p); return p
    end
    local function ell(sz, cf, col, nr, mat)
        local p = blk(sz, cf, col, nr, mat or plastic)
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
        return p
    end
    local function limb(a, b, thick, col, nr, mat)
        local r = makeRod(model, a, b, thick, thick, col or suit)
        if mat then r.Material = mat end
        if nr then r:SetAttribute("NoRecolor", true) end
        table.insert(bodies, r); return r
    end

    for _, sd in ipairs({-1, 1}) do
        limb(V(sd*0.14, -0.02, 0), V(sd*0.165, -0.86, 0), 0.25*s)
        blk(V(0.25, 0.10, 0.44), P(sd*0.165, -0.91, -0.08), shoeCol, true, fabric)
    end
    blk(V(0.60, 0.46, 0.30), P(0, 0.17, 0), suit)
    blk(V(0.82, 0.34, 0.34), P(0, 0.52, 0), suit)
    for _, sd in ipairs({-1, 1}) do
        ell(V(0.31, 0.31, 0.31), P(sd*0.44, 0.60, 0), suit, false, fabric)
    end
    blk(V(0.21, 0.14, 0.18), P(0, 0.75, 0), skin, true, plastic)
    ell(V(0.37, 0.45, 0.39), P(0, 0.97, 0), skin, true)
    blk(V(0.21, 0.44, 0.03), P(0, 0.49, -0.175), shirtCol, true, plastic)
    for _, sd in ipairs({-1, 1}) do
        local ang = math.rad(-20 * sd)
        blk(V(0.085, 0.47, 0.05), P(sd*0.145, 0.50, -0.19) * CFrame.Angles(0, 0, ang), suit, false, plastic)
    end
    local hand = V(0, 0.07, -0.34)
    for _, sd in ipairs({-1, 1}) do
        local shoulder = V(sd*0.43, 0.56, 0)
        local elbow    = V(sd*0.54, 0.17, -0.10)
        limb(shoulder, elbow, 0.25*s)
        limb(elbow, hand, 0.20*s)
    end
    ell(V(0.21, 0.15, 0.17), CFrame.new(hand), skin, true)
    if fine then
        for _, sd in ipairs({-1, 1}) do
            ell(V(0.05, 0.05, 0.03), P(sd*0.085, 1.00, -0.166), darkCol, true)
        end
        blk(V(0.25, 0.025, 0.03), P(0, 1.05, -0.172), darkCol, true, plastic)
        blk(V(0.17, 0.035, 0.02), P(0, 0.885, -0.178), shirtCol, true, plastic)
        ell(V(0.045, 0.06, 0.03), P(0, 0.53, -0.198), goldCol, true, metal)
        local elbowL = V(-0.54, 0.17, -0.10)
        local wrist  = elbowL:Lerp(hand, 0.80)
        blk(V(0.19, 0.19, 0.07), CFrame.lookAt(wrist, hand), watchCol, true, metal)
    end
    return model, root, bodies
end

local function createDragon(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local detailed = (SETTINGS.BlockCount or 8) <= 8
    local eyeColor = Color3.fromRGB(235, 70, 255)
    local function blk(sz, pos, col, nr)
        local p = newPart(model, "D", sz, CFrame.new(pos), col or color, nr)
        p.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, p); return p
    end
    local function rod(a, b, th, dp, col)
        local r = makeRod(model, a, b, th, dp, col or color)
        r.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, r); return r
    end
    blk(Vector3.new(s*0.70, s*0.60, s*1.40), Vector3.new(0, 0, 0))
    blk(Vector3.new(s*0.42, s*0.42, s*0.55), Vector3.new(0, s*0.28, -s*0.90))
    blk(Vector3.new(s*0.34, s*0.34, s*0.50), Vector3.new(0, s*0.52, -s*1.25))
    blk(Vector3.new(s*0.50, s*0.40, s*0.52), Vector3.new(0, s*0.70, -s*1.62))
    blk(Vector3.new(s*0.30, s*0.20, s*0.50), Vector3.new(0, s*0.62, -s*2.02))
    blk(Vector3.new(s*0.08, s*0.08, s*0.04), Vector3.new(-s*0.24, s*0.80, -s*1.89), eyeColor, true)
    blk(Vector3.new(s*0.08, s*0.08, s*0.04), Vector3.new( s*0.24, s*0.80, -s*1.89), eyeColor, true)
    for i = 1, 4 do
        local k = 1 - (i-1)*0.2
        blk(Vector3.new(s*0.46*k, s*0.40*k, s*0.55), Vector3.new(0, -s*0.04*i, s*(0.85 + 0.5*i)))
    end
    for _, side in ipairs({-1, 1}) do
        local sh = Vector3.new(side*s*0.30, s*0.26, -s*0.20)
        local el = Vector3.new(side*s*1.10, s*0.78, -s*0.05)
        local wr = Vector3.new(side*s*1.90, s*0.50,  s*0.30)
        rod(sh, el, s*0.13, s*0.13)
        rod(el, wr, s*0.11, s*0.11)
        local t1 = Vector3.new(side*s*2.60, s*0.18, s*1.00)
        local t2 = Vector3.new(side*s*1.90, s*0.05, s*1.60)
        rod(wr, t1, s*0.07, s*0.07)
        rod(wr, t2, s*0.07, s*0.07)
        rod(Vector3.new(side*s*1.1, s*0.45, s*0.25), Vector3.new(side*s*2.0, s*0.28, s*0.85), s*0.035, s*0.75)
        rod(Vector3.new(side*s*0.5, s*0.30, s*0.45), Vector3.new(side*s*1.3, s*0.12, s*1.35), s*0.035, s*0.7)
        blk(Vector3.new(s*0.20, s*0.42, s*0.20), Vector3.new(side*s*0.24, -s*0.46, -s*0.42))
    end
    if detailed then
        blk(Vector3.new(s*0.26, s*0.07, s*0.44), Vector3.new(0, s*0.48, -s*1.96))
        blk(Vector3.new(s*0.07, s*0.20, s*0.07), Vector3.new(-s*0.18, s*1.00, -s*1.50))
        blk(Vector3.new(s*0.07, s*0.20, s*0.07), Vector3.new( s*0.18, s*1.00, -s*1.50))
        for i = 1, 3 do
            blk(Vector3.new(s*0.10, s*0.22, s*0.14), Vector3.new(0, s*0.40, -s*0.35 + (i-1)*s*0.45))
        end
        blk(Vector3.new(s*0.20, s*0.42, s*0.20), Vector3.new(-s*0.24, -s*0.46, s*0.48))
        blk(Vector3.new(s*0.20, s*0.42, s*0.20), Vector3.new( s*0.24, -s*0.46, s*0.48))
    end
    return model, root, bodies
end

-- ============================================================
--  v24.3-ai: НОВЫЕ И ПЕРЕРИСОВАННЫЕ ФИГУРЫ UNDERTALE
-- ============================================================
local function makeFigureKit(model, bodies)
    local kit = {}
    function kit.blk(nm, sz, cf, col, nr, mat, mesh)
        local p = newPart(model, nm, sz, cf, col, nr)
        p.Material = mat or Enum.Material.SmoothPlastic
        if mesh then
            local m = Instance.new("SpecialMesh"); m.MeshType = mesh; m.Parent = p
        end
        table.insert(bodies, p)
        return p
    end
    function kit.cylY(nm, d, h, pos, col, nr, mat)
        local p = newPart(model, nm, Vector3.new(h, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), col, nr)
        p.Shape = Enum.PartType.Cylinder
        p.Material = mat or Enum.Material.SmoothPlastic
        table.insert(bodies, p)
        return p
    end
    function kit.spike(nm, pos, dir, len, w, col, nr, mat)
        local d = dir.Unit
        local center = pos + d * (len * 0.5)
        local cf = CFrame.lookAt(center, center + d) * CFrame.Angles(math.rad(-90), 0, 0)
        local p = newPart(model, nm, Vector3.new(w, len, w), cf, col, nr)
        p.Material = mat or Enum.Material.SmoothPlastic
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Pyramid; m.Parent = p
        table.insert(bodies, p)
        return p
    end
    function kit.rod(a, b, th, dp, col, nr, mat)
        local r = makeRod(model, a, b, th, dp, col)
        r.Material = mat or Enum.Material.SmoothPlastic
        if nr then r:SetAttribute("NoRecolor", true) end
        table.insert(bodies, r)
        return r
    end
    return kit
end

-- №29 САНС (SANS) — полное тело
local function createSans(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local detailed = isDetailed()
    local kit = makeFigureKit(model, bodies)
    local blk, rod = kit.blk, kit.rod

    local blue     = color or Color3.fromRGB(55, 115, 225)
    local blueDark = Color3.fromRGB(38, 85, 175)
    local white    = Color3.fromRGB(246, 246, 250)
    local bone     = Color3.fromRGB(250, 250, 252)
    local black    = Color3.fromRGB(18, 18, 22)
    local pink     = Color3.fromRGB(255, 165, 190)
    local cyan     = Color3.fromRGB(0, 205, 255)
    local fabric, plastic = Enum.Material.Fabric, Enum.Material.SmoothPlastic
    local SPH = Enum.MeshType.Sphere

    local function V(x, y, z) return Vector3.new(x*s, y*s, z*s) end
    local function P(x, y, z) return CFrame.new(x*s, y*s, z*s) end

    -- ГОЛОВА
    local HX, HY, HZ, HC = 0.65, 0.50, 0.525, 1.0
    local function surfZ(x, y)
        local k = 1 - (x/HX)^2 - ((y-HC)/HY)^2
        return -HZ * math.sqrt(math.max(0, k))
    end
    blk("Skull", V(HX*2, HY*2, HZ*2), P(0, HC, 0), bone, true, plastic, SPH)
    blk("Cheeks", V(1.05, 0.46, 0.62), P(0, 0.72, -0.06), bone, true, plastic, SPH)

    for _, sd in ipairs({-1, 1}) do
        local ex, ey = sd*0.27, 1.04
        local sock = blk("Socket", V(0.31, 0.35, 0.12), CFrame.new(ex*s, ey*s, (surfZ(ex, ey) + 0.01)*s) * CFrame.Angles(0, 0, math.rad(-sd*10)),
            black, true, plastic, SPH)
    end
    do
        local ex, ey = -0.27, 1.02
        local z = surfZ(ex, ey)
        local pupil = blk("EyeGlow", V(0.11, 0.11, 0.06), P(ex, ey, z - 0.10), cyan, true, Enum.Material.Neon, SPH)
        local aura = blk("EyeAura", V(0.20, 0.20, 0.07), P(ex, ey, z - 0.105), cyan, true, Enum.Material.Neon, SPH)
        aura.Transparency = 0.65
    end
    do
        local nz = surfZ(0, 0.86)
        blk("Nose", V(0.10, 0.14, 0.05), CFrame.new(0, 0.86*s, (nz - 0.005)*s) * CFrame.Angles(math.rad(180), 0, 0),
            black, true, plastic, Enum.MeshType.Pyramid)
    end
    do
        local pts = {}
        local N = 8
        for i = 0, N do
            local x = -0.50 + i*(1.0/N)
            local y = 0.62 + 0.15*(x/0.5)^2
            pts[#pts+1] = Vector3.new(x*s, y*s, (surfZ(x, y) - 0.008)*s)
        end
        for i = 1, N do rod(pts[i], pts[i+1], 0.04*s, 0.03*s, black, true, plastic) end
        for i = 1, 7 do
            local x = -0.42 + (i-1)*(0.84/6)
            local y = 0.62 + 0.15*(x/0.5)^2
            blk("Tooth", V(0.022, 0.15, 0.03), P(x, y + 0.01, surfZ(x, y) - 0.008), black, true, plastic)
        end
    end

    -- ТЕЛО
    local TY = -0.05
    blk("Hoodie", V(1.00, 0.85, 0.62), P(0, TY, 0), blue, false, fabric)
    blk("Hem", V(1.06, 0.12, 0.66), P(0, -0.47, 0), blueDark, false, fabric)
    for _, sd in ipairs({-1, 1}) do
        blk("Shoulder", V(0.42, 0.42, 0.42), P(sd*0.52, 0.24, 0), blue, false, fabric, SPH)
    end
    blk("Hood", V(0.80, 0.55, 0.40), P(0, 0.32, 0.36), blue, false, fabric, SPH)
    blk("Shirt", V(0.20, 0.72, 0.04), P(0, TY, -0.325), white, true, fabric)
    for _, sd in ipairs({-1, 1}) do
        blk("Flap", V(0.10, 0.72, 0.05), P(sd*0.15, TY, -0.335) * CFrame.Angles(0, 0, math.rad(-sd*8)), blue, false, fabric)
    end
    blk("Neck", V(0.22, 0.16, 0.22), P(0, 0.50, 0), bone, true, plastic)
    for k = 0, 9 do
        local a = k/10*math.pi*2
        blk("Fur", V(0.27, 0.25, 0.27), P(math.cos(a)*0.50, 0.44, math.sin(a)*0.36), white, true, fabric, SPH)
    end

    -- РУКИ
    do
        local shoulder = V(-0.55, 0.22, 0)
        local pocket   = V(-0.33, -0.30, -0.30)
        rod(shoulder, pocket, 0.27*s, 0.27*s, blue, false, fabric)
        blk("Pocket", V(0.36, 0.24, 0.14), P(-0.31, -0.30, -0.335), blueDark, false, fabric, SPH)
    end
    do
        local shoulder = V(0.55, 0.22, 0)
        local wrist    = V(0.66, -0.40, -0.06)
        rod(shoulder, wrist, 0.27*s, 0.27*s, blue, false, fabric)
        blk("Cuff", V(0.30, 0.10, 0.30), P(0.66, -0.43, -0.06), white, true, fabric)
        blk("Hand", V(0.20, 0.20, 0.20), P(0.67, -0.56, -0.06), bone, true, plastic, SPH)
        if detailed then
            for i = -1, 1 do
                blk("Finger", V(0.05, 0.13, 0.05), P(0.67 + i*0.065, -0.68, -0.06), bone, true, plastic)
            end
        end
    end

    -- ШОРТЫ
    blk("Shorts", V(1.00, 0.42, 0.62), P(0, -0.68, 0), black, true, fabric)
    for _, sd in ipairs({-1, 1}) do
        blk("Stripe", V(0.035, 0.42, 0.64), P(sd*0.50, -0.68, 0), white, true, fabric)
    end

    -- НОГИ и ТАПОЧКИ
    for _, sd in ipairs({-1, 1}) do
        rod(V(sd*0.21, -0.86, 0), V(sd*0.21, -1.36, 0), 0.20*s, 0.20*s, bone, true, plastic)
        blk("Slipper", V(0.42, 0.20, 0.64), P(sd*0.21, -1.45, -0.10), white, true, fabric)
        blk("SlipperSole", V(0.44, 0.06, 0.66), P(sd*0.21, -1.545, -0.10), pink, true, fabric)
        blk("SlipperToe", V(0.38, 0.20, 0.30), P(sd*0.21, -1.44, -0.34), pink, true, fabric, SPH)
    end

    return model, root, bodies
end

-- №30 ГАСТЕР (GASTER) — полное тело, призрачный облик
local function createGasterBody(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local kit = makeFigureKit(model, bodies)
    local blk, rod = kit.blk, kit.rod

    local robeCol  = color or Color3.fromRGB(14, 14, 18)
    local boneCol  = Color3.fromRGB(240, 240, 235)
    local dark     = Color3.fromRGB(14, 12, 12)
    local crackCol = Color3.fromRGB(35, 32, 30)
    local glow     = Color3.fromRGB(205, 255, 60)
    local white    = Color3.fromRGB(250, 250, 250)
    local fabric   = Enum.Material.Fabric
    local plastic  = Enum.Material.SmoothPlastic
    local SPH      = Enum.MeshType.Sphere

    local function V(x, y, z) return Vector3.new(x*s, y*s, z*s) end
    local function P(x, y, z) return CFrame.new(x*s, y*s, z*s) end

    -- ЧЕРЕП
    local HX, HY, HZ, HC = 0.65, 0.625, 0.575, 1.0
    local function surfZ(x, y)
        local k = 1 - (x/HX)^2 - ((y-HC)/HY)^2
        return -HZ * math.sqrt(math.max(0, k))
    end
    blk("Skull", V(HX*2, HY*2, HZ*2), P(0, HC, 0), boneCol, true, plastic, SPH)
    blk("Cheeks", V(0.95, 0.55, 0.80), P(0, 0.58, -0.08), boneCol, true, plastic, SPH)

    for _, sd in ipairs({-1, 1}) do
        local ex, ey = sd*0.30, 1.00
        local z = surfZ(ex, ey)
        blk("Socket", V(0.36, 0.40, 0.14), CFrame.new(ex*s, ey*s, (z + 0.01)*s) * CFrame.Angles(0, 0, math.rad(-sd*9)), dark, true, plastic, SPH)
        blk("EyeGlow", V(0.20, 0.24, 0.07), CFrame.new(ex*s, (ey - 0.02)*s, (z - 0.12)*s) * CFrame.Angles(0, 0, math.rad(-sd*9)),
            glow, true, Enum.Material.Neon, SPH)
    end
    do
        local nz = surfZ(0, 0.78)
        blk("Nose", V(0.12, 0.16, 0.06), CFrame.new(0, 0.78*s, (nz - 0.005)*s) * CFrame.Angles(math.rad(180), 0, 0),
            dark, true, plastic, Enum.MeshType.Pyramid)
    end
    do
        local mz = surfZ(0, 0.50)
        blk("Mouth", V(0.62, 0.045, 0.05), P(0, 0.50, mz - 0.005), dark, true, plastic)
        for i = 1, 5 do
            local x = -0.24 + (i-1)*0.12
            blk("Tooth", V(0.02, 0.14, 0.04), P(x, 0.50, mz - 0.005), dark, true, plastic)
        end
    end
    local function surfPt(x, y, off)
        return Vector3.new(x*s, y*s, (surfZ(x, y) - (off or 0.008))*s)
    end
    do
        local zig = { {0.04, 1.58}, {-0.04, 1.36}, {0.05, 1.16}, {-0.02, 0.98}, {0.02, 0.80} }
        for i = 1, #zig - 1 do
            rod(surfPt(zig[i][1], zig[i][2]), surfPt(zig[i+1][1], zig[i+1][2]), 0.035*s, 0.03*s, crackCol, true, plastic)
        end
        rod(surfPt(-0.42, 1.12), surfPt(-0.52, 1.30), 0.03*s, 0.03*s, crackCol, true, plastic)
        rod(surfPt(-0.52, 1.30), surfPt(-0.50, 1.46), 0.03*s, 0.03*s, crackCol, true, plastic)
        rod(surfPt(0.36, 0.84), surfPt(0.46, 0.66), 0.03*s, 0.03*s, crackCol, true, plastic)
        rod(surfPt(0.30, 1.52), surfPt(0.18, 1.40), 0.03*s, 0.03*s, crackCol, true, plastic)
        rod(surfPt(-0.28, 1.50), surfPt(-0.20, 1.42), 0.03*s, 0.03*s, crackCol, true, plastic)
    end

    -- БАЛАХОН
    local ROBE_T = 0.15
    local function robe(p) p.Transparency = ROBE_T; return p end
    robe(blk("Shoulders", V(1.50, 0.70, 0.90), P(0, 0.12, 0.05), robeCol, false, fabric, SPH))
    for i = 1, 6 do
        local r = 0.55 + 0.17*(i-1)
        local y = -0.05 - (i-1)*0.40
        robe(kit.cylY("Robe", r*2*s, 0.50*s, V(0, y, 0.0), robeCol, false, fabric))
    end
    for k = 0, 6 do
        local a = k/7*math.pi*2
        local p = kit.spike("Hem", V(math.cos(a)*1.20, -2.28, math.sin(a)*1.20), Vector3.new(0, -1, 0), 0.60*s, 0.36*s, robeCol, false, fabric)
        p.Transparency = 0.2
    end
    do
        local function robeFront(r, x, y) return Vector3.new(x*s, y*s, -math.sqrt(r*r - x*x)*s - 0.02*s) end
        local top = 0.2
        local vTip = Vector3.new(0, -0.55*s, -0.74*s)
        rod(robeFront(0.55, -0.38, top), vTip, 0.09*s, 0.05*s, white, true, plastic)
        rod(robeFront(0.55,  0.38, top), vTip, 0.09*s, 0.05*s, white, true, plastic)
    end

    -- РУКИ (через create3DHand)
    local function attachHand(side)
        local hs = s*0.30
        local hm, hr, hb = create3DHand(hs, Color3.fromRGB(240, 238, 230), "GasterHand", false)
        hm.Parent = model
        local pos = Vector3.new(side*2.00*s, 0.15*s, -0.30*s)
        local tilt = CFrame.Angles(0, 0, math.rad(-side*18))
        local mirror = (side < 0) and CFrame.Angles(0, math.pi, 0) or CFrame.new()
        hm:PivotTo(CFrame.new(pos) * tilt * mirror)
        for _, p in ipairs(hb) do
            p:SetAttribute("NoRecolor", true)
            table.insert(bodies, p)
        end
    end
    attachHand(-1)
    attachHand(1)

    return model, root, bodies
end

-- №27 ЦВЕТОК ФЛАУИ v2
local function createFlowey_V2(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local u = size * 0.42
    local petalCol = color or Color3.fromRGB(255, 225, 20)
    local black = Color3.fromRGB(12, 12, 14)
    local white = Color3.fromRGB(255, 255, 240)
    local green = Color3.fromRGB(75, 190, 60)
    local SQ3 = math.sqrt(3) / 2
    local plastic = Enum.Material.SmoothPlastic

    local function hexagon(cx, cy, cz, L, thick, col, nr, rot)
        local before = #bodies
        local c, sn = math.cos(rot), math.sin(rot)
        local function pt(x, y) return Vector3.new(cx + x*c - y*sn, cy + x*sn + y*c, cz) end
        local core = newPart(model, "Hex", Vector3.new(L, SQ3*L, thick), CFrame.new(cx, cy, cz) * CFrame.Angles(0, 0, rot), col, nr)
        core.Material = plastic; table.insert(bodies, core)
        addTriangle(model, pt( L/2,  SQ3*L/2), pt( L, 0), pt( L/2, -SQ3*L/2), thick, col, bodies)
        addTriangle(model, pt(-L/2,  SQ3*L/2), pt(-L, 0), pt(-L/2, -SQ3*L/2), thick, col, bodies)
        if nr then
            for i = before + 1, #bodies do bodies[i]:SetAttribute("NoRecolor", true) end
        end
    end

    local y0 = 1.1*u
    local Lp, Rp = 0.74*u, 1.55*u
    for k = 0, 5 do
        local a = math.rad(k*60)
        local cx, cy = math.cos(a)*Rp, y0 + math.sin(a)*Rp
        hexagon(cx, cy, 0.06*u, Lp*1.18, 0.20*u, black, true, a)
        hexagon(cx, cy, 0.00,   Lp,      0.20*u, petalCol, false, a)
    end
    local Lf = 0.80*u
    hexagon(0, y0, -0.12*u, Lf*1.15, 0.24*u, black, true, 0)
    hexagon(0, y0, -0.16*u, Lf,      0.24*u, white, true, 0)

    local ez = -0.30*u
    for _, sx in ipairs({-1, 1}) do
        local cx, cy = sx*0.30*u, y0 + 0.16*u
        local top   = Vector3.new(cx,          cy + 0.27*u, ez)
        local right = Vector3.new(cx + 0.14*u, cy,          ez)
        local bot   = Vector3.new(cx,          cy - 0.27*u, ez)
        local left  = Vector3.new(cx - 0.14*u, cy,          ez)
        local before = #bodies
        addTriangle(model, top, right, left, 0.08*u, black, bodies)
        addTriangle(model, bot, right, left, 0.08*u, black, bodies)
        for i = before + 1, #bodies do bodies[i]:SetAttribute("NoRecolor", true) end
    end

    do
        local pts = {}
        local N = 8
        for i = 0, N do
            local x = -0.60 + i*(1.2/N)
            local y = y0 - 0.14*u - 0.20*u * (1 - (x/0.60)^2)
            pts[#pts+1] = Vector3.new(x*u, y, ez)
        end
        for i = 1, N do
            local r = makeRod(model, pts[i], pts[i+1], 0.10*u, 0.08*u, black)
            r.Material = plastic; r:SetAttribute("NoRecolor", true); table.insert(bodies, r)
        end
        for _, sx in ipairs({-1, 1}) do
            local p = newPart(model, "Corner", Vector3.new(0.12*u, 0.16*u, 0.08*u),
                CFrame.new(sx*0.62*u, y0 - 0.12*u, ez), black, true)
            p.Material = plastic; table.insert(bodies, p)
        end
    end

    do
        local p0 = Vector3.new(0,        y0 - 0.90*u, 0.05*u)
        local p1 = Vector3.new(-0.70*u,  y0 - 2.30*u, 0.05*u)
        local p2 = Vector3.new( 0.35*u,  y0 - 4.10*u, 0.05*u)
        local back = Vector3.new(0, 0, 0.05*u)
        local function seg(a, b)
            local o = makeRod(model, a + back, b + back, 0.60*u, 0.24*u, black)
            o.Material = plastic; o:SetAttribute("NoRecolor", true); table.insert(bodies, o)
            local g = makeRod(model, a, b, 0.38*u, 0.24*u, green)
            g.Material = plastic; g:SetAttribute("NoRecolor", true); table.insert(bodies, g)
        end
        seg(p0, p1)
        seg(p1, p2)
        local jb = newPart(model, "JointB", Vector3.new(0.62*u, 0.62*u, 0.24*u), CFrame.new(p1 + back), black, true)
        jb.Material = plastic
        local m1 = Instance.new("SpecialMesh"); m1.MeshType = Enum.MeshType.Sphere; m1.Parent = jb
        table.insert(bodies, jb)
        local jg = newPart(model, "JointG", Vector3.new(0.40*u, 0.40*u, 0.26*u), CFrame.new(p1), green, true)
        jg.Material = plastic
        local m2 = Instance.new("SpecialMesh"); m2.MeshType = Enum.MeshType.Sphere; m2.Parent = jg
        table.insert(bodies, jg)
    end
    -- №28 ОМЕГА ФЛАУИ v2
local function createOmegaFlowey_V2(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local u = size * 0.34
    local detailed = isDetailed()
    local kit = makeFigureKit(model, bodies)

    local flesh     = color or Color3.fromRGB(140, 35, 48)
    local fleshDark = Color3.fromRGB(95, 20, 32)
    local lipRed    = Color3.fromRGB(205, 30, 45)
    local mouthIn   = Color3.fromRGB(50, 6, 14)
    local black     = Color3.fromRGB(10, 10, 14)
    local vineCol   = Color3.fromRGB(70, 150, 45)
    local spikeCol  = Color3.fromRGB(45, 110, 35)
    local diaCol    = Color3.fromRGB(150, 230, 70)
    local hornCol   = Color3.fromRGB(125, 55, 175)
    local toothCol  = Color3.fromRGB(250, 245, 230)
    local plastic, metal, neon, fabric = Enum.Material.SmoothPlastic, Enum.Material.Metal, Enum.Material.Neon, Enum.Material.Fabric
    local SPH = Enum.MeshType.Sphere

    local function Vu(x, y, z) return Vector3.new(x*u, y*u, z*u) end
    local function sph(nm, sx, sy, sz, x, y, z, col, nr, mat)
        return kit.blk(nm, Vu(sx, sy, sz), CFrame.new(x*u, y*u, z*u), col, nr, mat or plastic, SPH)
    end

    -- ПЛОТЬ
    sph("Flesh", 3.0, 2.6, 1.7,   0,    0,    0.25, flesh, false)
    sph("Flesh", 2.0, 1.7, 1.2,  -1.7, -0.3,  0.35, flesh, false)
    sph("Flesh", 2.0, 1.7, 1.2,   1.7, -0.3,  0.35, flesh, false)
    sph("Flesh", 1.8, 1.3, 1.1,   0,   -1.05, 0.10, fleshDark, false)
    sph("Flesh", 1.0, 0.9, 0.8,  -0.9,  0.95, 0.20, flesh, false)
    sph("Flesh", 1.0, 0.9, 0.8,   0.9,  0.95, 0.20, flesh, false)
    sph("Flesh", 0.7, 0.6, 0.6,   0,    1.2,  0.25, fleshDark, false)

    -- TV
    kit.blk("TvFrame", Vu(1.35, 1.10, 0.45), CFrame.new(0, 0.15*u, -0.62*u), black, true, plastic)
    kit.blk("TvScreen", Vu(1.10, 0.85, 0.06), CFrame.new(0, 0.15*u, -0.87*u), Color3.fromRGB(30, 150, 140), true, neon)
    for _, sx in ipairs({-1, 1}) do
        kit.blk("TvEye", Vu(0.14, 0.20, 0.05), CFrame.new(sx*0.24*u, 0.30*u, -0.91*u), Color3.fromRGB(255, 40, 40), true, neon)
    end
    for _, x in ipairs({-0.36, -0.18, 0, 0.18, 0.36}) do
        local y = -0.14 + 0.10*(x/0.36)^2
        kit.blk("TvSmile", Vu(0.15, 0.06, 0.05), CFrame.new(x*u, (0.15 + y)*u, -0.91*u), black, true, plastic)
    end

    -- ДЕМОНИЧЕСКИЕ ГЛАЗА
    local function giantEye(side, irisCol)
        local ex, ey = side*1.75, 0.45
        sph("EyeSocket", 1.50, 1.40, 0.80, ex, ey, -0.25, lipRed, false)
        sph("EyeWhite",  1.15, 1.10, 0.60, ex, ey, -0.52, Color3.fromRGB(250, 232, 225), true)
        sph("EyeIris",   0.72, 0.72, 0.30, ex, ey, -0.76, irisCol, true)
        sph("EyePupil",  0.30, 0.30, 0.14, ex, ey, -0.88, Color3.fromRGB(110, 12, 25), true)
        sph("EyeGlint",  0.10, 0.10, 0.06, ex + side*0.12, ey + 0.13, -0.93, Color3.fromRGB(255, 255, 255), true, neon)
        sph("LidTop",    1.45, 0.55, 0.80, ex, ey + 0.50, -0.50, lipRed, false)
        sph("LidBot",    1.30, 0.40, 0.70, ex, ey - 0.55, -0.45, lipRed, false)
    end
    giantEye(-1, Color3.fromRGB(110, 150, 40))
    giantEye( 1, Color3.fromRGB(35, 150, 175))

    -- ПАСТИ
    local function mouth(cx, cy, cz, w)
        sph("MouthLip",   w, w*0.52, 0.50, cx, cy, cz, lipRed, false)
        sph("MouthInner", w*0.84, w*0.34, 0.30, cx, cy, cz - 0.20, mouthIn, true)
        for _, k in ipairs({-0.28, 0, 0.28}) do
            kit.spike("Tooth", Vu(cx + k*w, cy + w*0.12, cz - 0.36), Vector3.new(0, -1, 0), w*0.26*u, w*0.16*u, toothCol, true)
            kit.spike("Tooth", Vu(cx + k*w, cy - w*0.12, cz - 0.36), Vector3.new(0,  1, 0), w*0.26*u, w*0.16*u, toothCol, true)
        end
    end
    mouth( 0,    -1.15, -0.35, 1.30)
    mouth(-1.75, -1.20, -0.15, 1.00)
    mouth( 1.75, -1.20, -0.15, 1.00)
    mouth( 0,     1.40, -0.10, 0.90)

    -- ЛИАНЫ
    local function vine(side, pts, th0, withDiamonds)
        for i = 1, #pts - 1 do
            local a = Vector3.new(side*pts[i][1], pts[i][2], pts[i][3]) * u
            local b = Vector3.new(side*pts[i+1][1], pts[i+1][2], pts[i+1][3]) * u
            local th = math.max(0.12, th0 - 0.04*(i-1))
            kit.rod(a, b, th*u, th*u, vineCol, true, plastic)
            local dirY = (i % 2 == 0) and -1 or 1
            kit.spike("VineSpike", b, Vector3.new(side*0.3, dirY, 0), 0.55*u, 0.22*u, spikeCol, true, plastic)
            if withDiamonds and i % 2 == 0 then
                local mid = (a + b) * 0.5
                kit.blk("VineDiamond", Vector3.new(0.20*u, 0.20*u, 0.12*u),
                    CFrame.new(mid + Vector3.new(0, 0, -0.10*u)) * CFrame.Angles(0, 0, math.rad(45)), diaCol, true, plastic)
            end
        end
    end
    local vineA = { {1.3,-0.10, 0.00}, {2.1,-0.90,-0.10}, {2.9,-0.40,-0.10}, {3.6,-1.10,-0.10}, {4.3,-0.60,-0.10}, {4.9,-1.20,-0.10}, {5.4,-0.90,-0.10} }
    local vineB = { {0.9,-1.60, 0.05}, {1.9,-2.00, 0.05}, {2.8,-1.70, 0.05}, {3.5,-2.10, 0.05}, {4.2,-1.85, 0.05} }
    for _, side in ipairs({-1, 1}) do
        vine(side, vineA, 0.34, true)
        vine(side, vineB, 0.26, false)
    end

    -- ТРУБЫ
    local pipeCols = {
        Color3.fromRGB(40, 85, 205),
        Color3.fromRGB(190, 35, 35),
        Color3.fromRGB(50, 55, 65),
    }
    local pipeH   = { 2.8, 2.4, 2.0 }
    local pipeY   = { -0.4, -0.6, -0.8 }
    local flangeC = Color3.fromRGB(130, 140, 155)
    for _, side in ipairs({-1, 1}) do
        for k = 1, 3 do
            local x = side*(2.75 + (k-1)*0.38)
            local y, h = pipeY[k], pipeH[k]
            kit.cylY("Pipe", 0.30*u, h*u, Vu(x, y, 0.5), pipeCols[k], true, metal)
            kit.cylY("Flange", 0.56*u, 0.12*u, Vu(x, y + h*0.5, 0.5), flangeC, true, metal)
            if detailed then
                kit.cylY("Flange", 0.56*u, 0.12*u, Vu(x, y - h*0.5, 0.5), flangeC, true, metal)
            end
        end
    end

    -- РОГА
    for _, side in ipairs({-1, 1}) do
        local horns = {
            { {0.5, 1.2, 0.2}, {0.95, 2.0, 0.1}, {0.70, 2.8, 0.0} },
            { {1.3, 1.0, 0.2}, {2.00, 1.7, 0.1}, {2.30, 2.5, 0.0} },
        }
        for _, h in ipairs(horns) do
            local a = Vector3.new(side*h[1][1], h[1][2], h[1][3]) * u
            local b = Vector3.new(side*h[2][1], h[2][2], h[2][3]) * u
            local c = Vector3.new(side*h[3][1], h[3][2], h[3][3]) * u
            kit.rod(a, b, 0.42*u, 0.42*u, hornCol, true, plastic)
            kit.rod(b, c, 0.28*u, 0.28*u, hornCol, true, plastic)
            kit.spike("HornTip", c, c - b, 0.55*u, 0.26*u, hornCol, true, plastic)
        end
    end

    -- ИСКРА
    sph("Spark", 0.55, 0.55, 0.55, 0, -1.70, -0.45, Color3.fromRGB(90, 255, 130), true, neon)
    local halo = sph("SparkHalo", 1.0, 1.0, 1.0, 0, -1.70, -0.45, Color3.fromRGB(90, 255, 130), true, neon)
    halo.Transparency = 0.6
    if detailed then
        sph("SparkDot", 0.14, 0.14, 0.14, -0.55, -1.45, -0.45, Color3.fromRGB(160, 255, 190), true, neon)
        sph("SparkDot", 0.14, 0.14, 0.14,  0.55, -1.95, -0.45, Color3.fromRGB(160, 255, 190), true, neon)
    end

    return model, root, bodies
end

-- ============================================================
--  РЕГИСТРАЦИЯ 30 ФИГУР (v24.3-ai-fix2)
--  По правилам проекта НЕ подменяем ORBIT.SHAPE_PRESETS целиком —
--  используем table.insert, ссылка на таблицу сохраняется.
-- ============================================================
if type(ORBIT.SHAPE_PRESETS) ~= "table" then
    ORBIT.SHAPE_PRESETS = {}
end
do
    local PR = ORBIT.SHAPE_PRESETS
    for i = #PR, 1, -1 do PR[i] = nil end

    local function reg(shape) table.insert(PR, shape) end

    reg({ name = "БЛОК", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Block; p.Size = Vector3.new(size,size,size)
        return { part = p } end })
    reg({ name = "ШАР", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(size,size,size)
        return { part = p } end })
    reg({ name = "ЦИЛИНДР", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Cylinder; p.Size = Vector3.new(size,size,size)
        return { part = p } end })
    reg({ name = "КЛИН", create = function(size, name)
        local p = Instance.new("WedgePart"); p.Name = name; p.Size = Vector3.new(size,size,size)
        return { part = p } end })
    reg({ name = "ГОЛОВА", create = function(s, n)
        local m, r, b = createHead(s, Color3.fromRGB(255,220,60), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s } end })
    reg({ name = "СЕРДЦЕ", create = function(s, n, idx)
        local hs = s*1.8
        local hc = heartColorByIdx(idx)
        local m, r, b = createPixelHeart(hs, hc, n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=hs } end })
    reg({ name = "ЗВЕЗДА", create = function(s, n)
        local m, r, b = create3DStar(s, Color3.fromRGB(255,200,40), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s } end })
    reg({ name = "ТРЕУГОЛЬНИК", create = function(s, n)
        local m, r, b = create3DTriangle(s, Color3.fromRGB(0,255,120), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.5 } end })
    reg({ name = "РОМБ", create = function(s, n)
        local m, r, b = create3DDiamond(s, Color3.fromRGB(0,200,255), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.5 } end })
    reg({ name = "КРЕСТ", create = function(s, n)
        local m, r, b = create3DCross(s, Color3.fromRGB(230,220,200), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end })
    reg({ name = "ЧЕРЕП", create = function(s, n)
        local m, r, b = create3DSkull(s, Color3.fromRGB(235,230,215), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.4 } end })
    reg({ name = "МОЛНИЯ", create = function(s, n)
        local m, r, b = create3DLightning(s, Color3.fromRGB(255,230,60), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.5 } end })
    reg({ name = "РУКА", create = function(s, n)
        local m, r, b = create3DHand(s, Color3.fromRGB(235,230,215), n, false)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.2 } end })
    reg({ name = "РУКА-СЕРДЦЕ", create = function(s, n, idx)
        local hc = heartColorByIdx(idx)
        local m, r, b = create3DHand(s, Color3.fromRGB(235,230,215), n, true, hc)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.2 } end })
    reg({ name = "ГАСТЕР БЛАСТЕР", create = function(s, n)
        return create3DBlasterPlaceholder(s, Color3.fromRGB(240,240,245), n)
    end })
    reg({ name = "МЕЧ", create = function(s, n)
        local m, r, b = createSword(s, Color3.fromRGB(220,230,245), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.0 } end })
    reg({ name = "ЩИТ", create = function(s, n)
        local m, r, b = createShield(s, Color3.fromRGB(200,220,240), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.2 } end })
    reg({ name = "КОСТЬ", create = function(s, n)
        local m, r, b = createBone(s, Color3.fromRGB(245,240,220), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end })
    reg({ name = "ПИРАМИДА", create = function(s, n)
        local m, r, b = createPyramid(s, Color3.fromRGB(255,200,100), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.6 } end })
    reg({ name = "ИНЬ-ЯН", create = function(s, n)
        local m, r, b = createYinYang(s, Color3.fromRGB(220,220,240), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end })
    reg({ name = "ГЛАЗ", create = function(s, n)
        local m, r, b = createEye(s, Color3.fromRGB(255,200,200), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.6 } end })
    reg({ name = "СПИРАЛЬ", create = function(s, n)
        local m, r, b = createSpiral(s, Color3.fromRGB(120,200,255), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end })
    reg({ name = "КРЫЛЬЯ", create = function(s, n)
        local m, r, b = createWings(s, Color3.fromRGB(240,240,255), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.2 } end })
    reg({ name = "ЩУПАЛЬЦЕ", create = function(s, n)
        local m, r, b = createTentacle(s, Color3.fromRGB(150,80,180), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.0 } end })
    reg({ name = "СКАЛА", create = function(s, n)
        local m, r, b = createRock(s, Color3.fromRGB(70,22,92), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.2 } end })
    reg({ name = "ДРАКОН", create = function(s, n)
        local m, r, b = createDragon(s, Color3.fromRGB(45,35,60), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.4 } end })
    reg({ name = "ЦВЕТОК ФЛАУИ", create = function(s, n)
        local m, r, b = createFlowey_V2(s, Color3.fromRGB(255, 225, 20), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.6 } end })
    reg({ name = "ОМЕГА ФЛАУИ", create = function(s, n)
        local m, r, b = createOmegaFlowey_V2(s, Color3.fromRGB(140, 35, 48), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.7 } end })
    reg({ name = "САНС", create = function(s, n)
        local m, r, b = createSans(s, Color3.fromRGB(55, 115, 225), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.1 } end })
    reg({ name = "ГАСТЕР", create = function(s, n)
        local m, r, b = createGasterBody(s, Color3.fromRGB(14, 14, 18), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*4.0 } end })
end

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ Часть 2: фигуры загружены (30 шт., ai-fix2)", Color3.fromRGB(180,255,180), 3) end

return true
    return model, root, bodies
end
