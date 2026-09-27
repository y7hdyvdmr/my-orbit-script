--[[ ОРБИТА v15.3 — ЧАСТЬ 2/4: ФИГУРЫ (24 шт.) ]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit P2] Часть 1 не загружена!"); return end

local newPart       = ORBIT.newPart
local newModelShell = ORBIT.newModelShell
local makeRod       = ORBIT.makeRod
local SETTINGS      = ORBIT.SETTINGS

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
    return model, root, bodies
end

local function create3DCross(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local bt, bd = size*0.32, size*0.28
    table.insert(bodies, newPart(model, "V", Vector3.new(bt, size*2.0, bd), CFrame.new(), color))
    table.insert(bodies, newPart(model, "H", Vector3.new(size*1.3, bt, bd), CFrame.new(0, size*0.35, 0), color))
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
    return model, root, bodies
end

local HEART_PATTERN = { "11011", "11111", "11111", "01110", "00100" }
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
    return model, root, bodies
end

local HEART_COLORS = {
    Color3.fromRGB(255,140,40), Color3.fromRGB(255,230,60), Color3.fromRGB(255,0,200),
    Color3.fromRGB(220,20,60), Color3.fromRGB(0,255,120), Color3.fromRGB(0,220,220), Color3.fromRGB(40,80,255),
}

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
    return model, root, bodies
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
    end
    return model, root, bodies
end

local function create3DBlasterPlaceholder(size, color, name)
    local model, root = newModelShell(name); local bodies = {}
    local s = size
    local bone = color or Color3.fromRGB(235,230,215)
    local dark = Color3.fromRGB(10,9,9)
    local toothColor = Color3.fromRGB(250,248,240)
    local function block(sz, cf, col, nr)
        local p = newPart(model, "B", sz, cf, col, nr)
        p.Material = Enum.Material.SmoothPlastic
        table.insert(bodies, p); return p
    end
    local function ell(sz, cf, col, nr)
        local p = block(sz, cf, col, nr)
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
        return p
    end
    local function wedge(sz, cf, col, nr)
        local w = Instance.new("WedgePart")
        w.Name = "W"; w.Size = sz; w.CFrame = cf
        w.Anchored = true; w.CanCollide = false; w.CastShadow = false
        w.Material = Enum.Material.SmoothPlastic; w.Color = col
        if nr then w:SetAttribute("NoRecolor", true) end
        w.Parent = model; table.insert(bodies, w); return w
    end
    local function tooth(cf, w, h, col)
        local p = newPart(model, "Tooth", Vector3.new(w, h, w), cf, col, true)
        p.Material = Enum.Material.SmoothPlastic
        local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Pyramid; m.Parent = p
        table.insert(bodies, p); return p
    end
    ell(Vector3.new(1.45*s,1.00*s,1.35*s), CFrame.new(0, 0.28*s, 1.00*s), bone)
    ell(Vector3.new(1.30*s,0.88*s,1.20*s), CFrame.new(0, 0.24*s, 0.15*s), bone)
    ell(Vector3.new(1.00*s,0.68*s,1.10*s), CFrame.new(0, 0.18*s, -0.75*s), bone)
    ell(Vector3.new(0.62*s,0.46*s,0.85*s), CFrame.new(0, 0.12*s, -1.55*s), bone)
    for _, side in ipairs({-1, 1}) do
        ell(Vector3.new(0.10*s,0.10*s,0.14*s), CFrame.new(side*0.18*s, 0.06*s, -1.92*s), dark, true)
        ell(Vector3.new(0.38*s,0.34*s,0.30*s), CFrame.new(side*0.46*s, 0.32*s, -0.42*s), dark, true)
        ell(Vector3.new(0.15*s,0.15*s,0.10*s), CFrame.new(side*0.46*s, 0.32*s, -0.52*s), bone)
    end
    ell(Vector3.new(1.10*s,0.42*s,1.35*s), CFrame.new(0, -0.40*s, 0.55*s), bone)
    ell(Vector3.new(0.72*s,0.30*s,1.00*s), CFrame.new(0, -0.30*s, -0.55*s), bone)
    ell(Vector3.new(0.42*s,0.20*s,0.60*s), CFrame.new(0, -0.24*s, -1.30*s), bone)
    block(Vector3.new(0.68*s,0.34*s,1.55*s), CFrame.new(0, -0.05*s, -0.50*s), dark, true)
    ell(Vector3.new(0.22*s,0.22*s,0.22*s), CFrame.new(0, -0.05*s, -0.85*s), bone)
    for _, side in ipairs({-1, 1}) do
        tooth(CFrame.new(side*0.42*s, -0.02*s, -0.35*s)*CFrame.Angles(math.rad(180), 0, 0), 0.16*s, 0.30*s, toothColor)
        tooth(CFrame.new(side*0.38*s, -0.10*s, -0.30*s), 0.14*s, 0.24*s, toothColor)
    end
    for i = 1, 4 do
        local z = -1.10*s + (i-1)*0.20*s
        tooth(CFrame.new((i%2==0 and 0.24 or -0.24)*s, -0.06*s, z)*CFrame.Angles(math.rad(180), 0, 0), 0.12*s, 0.16*s, toothColor)
    end
    for i = 1, 3 do
        local z = 1.35*s - (i-1)*0.35*s
        local h = 0.70*s - (i-1)*0.16*s
        wedge(Vector3.new(0.18*s, h, 0.30*s),
            CFrame.new(0, 0.55*s+h*0.35, z)*CFrame.Angles(math.rad(-18), math.rad(90), 0), bone)
    end
    return model, root, bodies
end

ORBIT.SHAPE_PRESETS = {
    { name = "БЛОК", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Block; p.Size = Vector3.new(size,size,size)
        return { part = p } end },
    { name = "ШАР", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Ball; p.Size = Vector3.new(size,size,size)
        return { part = p } end },
    { name = "ЦИЛИНДР", create = function(size, name)
        local p = Instance.new("Part"); p.Name = name; p.Shape = Enum.PartType.Cylinder; p.Size = Vector3.new(size,size,size)
        return { part = p } end },
    { name = "КЛИН", create = function(size, name)
        local p = Instance.new("WedgePart"); p.Name = name; p.Size = Vector3.new(size,size,size)
        return { part = p } end },
    { name = "ГОЛОВА", create = function(s, n)
        local m, r, b = createHead(s, Color3.fromRGB(255,220,60), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s } end },
    { name = "СЕРДЦЕ", create = function(s, n)
        local hs = s*1.8
        local m, r, b = createPixelHeart(hs, Color3.fromRGB(255,60,120), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=hs } end },
    { name = "ЗВЕЗДА", create = function(s, n)
        local m, r, b = create3DStar(s, Color3.fromRGB(255,200,40), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s } end },
    { name = "ТРЕУГОЛЬНИК", create = function(s, n)
        local m, r, b = create3DTriangle(s, Color3.fromRGB(0,255,120), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.5 } end },
    { name = "РОМБ", create = function(s, n)
        local m, r, b = create3DDiamond(s, Color3.fromRGB(0,200,255), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.5 } end },
    { name = "КРЕСТ", create = function(s, n)
        local m, r, b = create3DCross(s, Color3.fromRGB(230,220,200), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end },
    { name = "ЧЕРЕП", create = function(s, n)
        local m, r, b = create3DSkull(s, Color3.fromRGB(235,230,215), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.4 } end },
    { name = "МОЛНИЯ", create = function(s, n)
        local m, r, b = create3DLightning(s, Color3.fromRGB(255,230,60), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.5 } end },
    { name = "РУКА", create = function(s, n)
        local m, r, b = create3DHand(s, Color3.fromRGB(235,230,215), n, false)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.2 } end },
    { name = "РУКА-СЕРДЦЕ", create = function(s, n, idx)
        local hc = HEART_COLORS[((idx or 1)-1) % #HEART_COLORS + 1]
        local m, r, b = create3DHand(s, Color3.fromRGB(235,230,215), n, true, hc)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.2 } end },
    { name = "ГАСТЕР БЛАСТЕР", create = function(s, n)
        local m, r, b = create3DBlasterPlaceholder(s, Color3.fromRGB(240,240,245), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.6 } end },
    { name = "МЕЧ", create = function(s, n)
        local m, r, b = createSword(s, Color3.fromRGB(220,230,245), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*3.0 } end },
    { name = "ЩИТ", create = function(s, n)
        local m, r, b = createShield(s, Color3.fromRGB(200,220,240), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.2 } end },
    { name = "КОСТЬ", create = function(s, n)
        local m, r, b = createBone(s, Color3.fromRGB(245,240,220), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end },
    { name = "ПИРАМИДА", create = function(s, n)
        local m, r, b = createPyramid(s, Color3.fromRGB(255,200,100), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.6 } end },
    { name = "ИНЬ-ЯН", create = function(s, n)
        local m, r, b = createYinYang(s, Color3.fromRGB(220,220,240), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end },
    { name = "ГЛАЗ", create = function(s, n)
        local m, r, b = createEye(s, Color3.fromRGB(255,200,200), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.6 } end },
    { name = "СПИРАЛЬ", create = function(s, n)
        local m, r, b = createSpiral(s, Color3.fromRGB(120,200,255), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*1.8 } end },
    { name = "КРЫЛЬЯ", create = function(s, n)
        local m, r, b = createWings(s, Color3.fromRGB(240,240,255), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.2 } end },
    { name = "ЩУПАЛЬЦЕ", create = function(s, n)
        local m, r, b = createTentacle(s, Color3.fromRGB(150,80,180), n)
        return { model=m, part=r, isModel=true, bodyParts=b, visualSize=s*2.0 } end },
}

if ORBIT.refreshLoaderStatus then ORBIT.refreshLoaderStatus() end
if ORBIT.notify then ORBIT.notify("✅ Часть 2: фигуры загружены (24 шт.)", Color3.fromRGB(180,255,180), 3) end

return true
