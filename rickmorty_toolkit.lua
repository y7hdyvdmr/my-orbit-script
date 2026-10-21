-- Rick & Morty Toolkit v3.0 (standalone): Motor6D-скелеты, аниматор, новая пушка и порталы
local G=rawget(_G,"getgenv") and getgenv() or _G
if G.RickMorty and G.RickMorty.unload then pcall(G.RickMorty.unload) end
local RM={_version="3.0"} G.RickMorty=RM
local Pl,RS,TS,UIS,HS,WS,SS=game:GetService("Players"),game:GetService("RunService"),game:GetService("TweenService"),game:GetService("UserInputService"),game:GetService("HttpService"),game:GetService("Workspace"),game:GetService("SoundService")
local LP=Pl.LocalPlayer local PG=LP:WaitForChild("PlayerGui") local W=Color3.fromRGB
local conns={} local function track(c) conns[#conns+1]=c return c end
-- настройки (ActiveSkin="" = без скина)
local FS=type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function"
local FILE="rickmorty_v30.json"
local ST={SoundEnabled=true,NotificationsEnabled=true,NotifDuration=2,MenuKey="RightShift",PortalColor={R=50,G=255,B=50},ActiveSkin="",AimSize=64}
RM.SETTINGS=ST
local function save() if FS then pcall(writefile,FILE,HS:JSONEncode(ST)) end end
if FS then pcall(function() if isfile(FILE) then local d=HS:JSONDecode(readfile(FILE)) if type(d)=="table" then for k,v in pairs(d) do if ST[k]~=nil then ST[k]=v end end end end end) end
-- звуки
local sf=Instance.new("Folder") sf.Name="RM_Sfx" sf.Parent=SS
local SFX={portal="rbxassetid://3314038600",shoot="rbxassetid://12221967",click="rbxasset://sounds/button.wav",notify="rbxasset://sounds/electronicpingshort.wav",teleport="rbxassetid://3314038600"}
local function snd(n,v,p) if not ST.SoundEnabled or not SFX[n] then return end pcall(function() local s=Instance.new("Sound") s.SoundId=SFX[n] s.Volume=v or .5 s.PlaybackSpeed=p or 1 s.Parent=sf s:Play() task.delay(4,function() s:Destroy() end) end) end
-- UI-хелперы
local C={bg=W(18,14,28),bg2=W(28,22,42),ac=W(100,255,140),ac2=W(150,90,255),ac3=W(120,220,255),tx=W(240,235,255),dim=W(150,140,180),dg=W(255,100,120),ok=W(120,255,160),st=W(120,90,220)}
local function I(c,p,par) local o=Instance.new(c) for k,v in pairs(p) do o[k]=v end o.Parent=par return o end
local function cr(o,r) return I("UICorner",{CornerRadius=UDim.new(0,r)},o) end
local function sk(o,c,t,tr) return I("UIStroke",{Color=c,Thickness=t,Transparency=tr},o) end
local function sp0() local f=rawget(G,"gethui") if type(f)=="function" then local ok,h=pcall(f) if ok and h then return h end end local ok,cg=pcall(function() return game:GetService("CoreGui") end) if ok and cg then return cg end return PG end
local gui=I("ScreenGui",{Name="_RM_"..math.random(100000,999999),ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=65,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
do local sy=rawget(G,"syn") if type(sy)=="table" and type(sy.protect_gui)=="function" then pcall(sy.protect_gui,gui) elseif type(rawget(G,"protect_gui"))=="function" then pcall(G.protect_gui,gui) end end
if not pcall(function() gui.Parent=sp0() end) or not gui.Parent then gui.Parent=PG end
local function drag(f,a)
  a=a or f local d,ds,sp,di=false
  a.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then d=true ds=i.Position sp=f.Position i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then d=false end end) end end)
  a.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then di=i end end)
  track(UIS.InputChanged:Connect(function(i) if i==di and d then local dl=i.Position-ds f.Position=UDim2.new(sp.X.Scale,sp.X.Offset+dl.X,sp.Y.Scale,sp.Y.Offset+dl.Y) end end))
end
-- уведомления
local nh=I("Frame",{Size=UDim2.fromOffset(260,300),Position=UDim2.new(1,-280,1,-320),BackgroundTransparency=1,ZIndex=60},gui)
I("UIListLayout",{VerticalAlignment=Enum.VerticalAlignment.Bottom,HorizontalAlignment=Enum.HorizontalAlignment.Right,Padding=UDim.new(0,4)},nh)
local function notify(tx,col,du)
  if not ST.NotificationsEnabled then return end
  col=col or C.ok du=du or ST.NotifDuration
  local ch=nh:GetChildren() if #ch>9 then ch[2]:Destroy() end
  local f=I("Frame",{Size=UDim2.fromOffset(250,32),BackgroundColor3=C.bg,BackgroundTransparency=.1,ZIndex=61},nh) cr(f,8) sk(f,col,1.5,.2)
  I("TextLabel",{Size=UDim2.new(1,-16,1,0),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,Text=tostring(tx),TextColor3=C.tx,Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=62},f)
  snd("notify",.4) task.delay(du,function() if f.Parent then f:Destroy() end end)
end
RM.notify=notify
-- главная кнопка и окно
local mb=I("TextButton",{Size=UDim2.fromOffset(60,60),Position=UDim2.fromOffset(20,120),BackgroundColor3=C.bg,BackgroundTransparency=.05,TextColor3=C.ac,Font=Enum.Font.GothamBold,TextSize=30,Text="🌀",AutoButtonColor=false,ZIndex=50},gui) cr(mb,16) drag(mb)
do local s=sk(mb,C.ac,2,.2) I("UIGradient",{Color=ColorSequence.new{ColorSequenceKeypoint.new(0,C.ac),ColorSequenceKeypoint.new(.5,C.ac3),ColorSequenceKeypoint.new(1,C.ac2)},Rotation=45},s) end
local vp=WS.CurrentCamera.ViewportSize
local WW,WH=math.min(380,vp.X-20),math.min(520,vp.Y-30)
local win=I("Frame",{Size=UDim2.fromOffset(WW,WH),Position=UDim2.fromOffset((vp.X-WW)/2,15),BackgroundColor3=C.bg,BackgroundTransparency=.02,Visible=false,ZIndex=40},gui) cr(win,16) sk(win,C.st,1.5,.25)
I("UIGradient",{Color=ColorSequence.new(C.bg2,C.bg),Rotation=90},win)
local hd=I("Frame",{Size=UDim2.new(1,0,0,44),BackgroundTransparency=1,ZIndex=41},win) drag(win,hd)
I("TextLabel",{Size=UDim2.new(1,-80,1,0),Position=UDim2.fromOffset(14,0),BackgroundTransparency=1,Text="🌀 RICK & MORTY v"..RM._version,TextColor3=C.ac,Font=Enum.Font.GothamBold,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=42},hd)
local cb=I("TextButton",{Size=UDim2.fromOffset(30,30),Position=UDim2.new(1,-38,0,7),BackgroundColor3=C.dg,BackgroundTransparency=.5,TextColor3=C.tx,Font=Enum.Font.GothamBold,TextSize=14,Text="✕",ZIndex=42},hd) cr(cb,8)
cb.MouseButton1Click:Connect(function() win.Visible=false end)
mb.MouseButton1Click:Connect(function() win.Visible=not win.Visible end)
local tabs=I("Frame",{Size=UDim2.new(1,-16,0,38),Position=UDim2.fromOffset(8,48),BackgroundTransparency=1,ZIndex=41},win)
I("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4)},tabs)
local content=I("ScrollingFrame",{Size=UDim2.new(1,-16,1,-120),Position=UDim2.fromOffset(8,90),BackgroundTransparency=1,ScrollBarThickness=3,ScrollBarImageColor3=C.ac,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=41},win)
I("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},content)
I("TextLabel",{Size=UDim2.new(1,-20,0,16),Position=UDim2.new(0,10,1,-22),BackgroundTransparency=1,Text="v"..RM._version.." | Motor6D | аниматор | 2 портала",TextColor3=C.dim,Font=Enum.Font.Code,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left},win)
local function newBtn(par,tx,col,fn,h)
  local b=I("TextButton",{Size=UDim2.new(1,-8,0,h or 36),BackgroundColor3=col or C.bg2,BackgroundTransparency=.1,TextColor3=C.tx,Font=Enum.Font.GothamBold,TextSize=12,Text=tx,ZIndex=42},par) cr(b,8) sk(b,C.st,1,.7)
  b.MouseButton1Click:Connect(function() snd("click",.3) if fn then pcall(fn) end end) return b
end
local function newSec(par,tx) return I("TextLabel",{Size=UDim2.new(1,-8,0,22),BackgroundTransparency=1,Text="▸ "..tx,TextColor3=C.ac3,Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=42},par) end
local function newInfo(par,tx,h) local l=I("TextLabel",{Size=UDim2.new(1,-8,0,h),BackgroundColor3=C.bg2,BackgroundTransparency=.2,Text=tx,TextColor3=C.dim,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=42},par) cr(l,8) return l end
local TABS={{"skins","🎭 СКИНЫ",90},{"portal","🌀 ПОРТАЛ",90},{"settings","⚙️",40}}
local tb,tf={},{}
local function sw(id)
  for k,f in pairs(tf) do f.Visible=k==id end
  for k,b in pairs(tb) do local on=k==id b.BackgroundColor3=on and C.ac or C.bg2 b.TextColor3=on and C.bg or C.tx b.BackgroundTransparency=on and 0 or .2 end
  content.CanvasPosition=Vector2.zero
end
for _,t in ipairs(TABS) do
  local b=I("TextButton",{Size=UDim2.fromOffset(t[3],32),BackgroundColor3=C.bg2,BackgroundTransparency=.2,TextColor3=C.tx,Font=Enum.Font.GothamBold,TextSize=10,Text=t[2],ZIndex=42},tabs) cr(b,8) tb[t[1]]=b
  b.MouseButton1Click:Connect(function() snd("click",.3) sw(t[1]) end)
  local f=I("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false,ZIndex=41},content)
  I("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},f) tf[t[1]]=f
end
track(UIS.InputBegan:Connect(function(i,g) if not g and i.KeyCode.Name==ST.MenuKey then win.Visible=not win.Visible end end))
-- ===== ПРИЦЕЛ =====
local mob=UIS.TouchEnabled and not UIS.MouseEnabled
local aimF,aimL,aimE,cross
local function spt() if mob then return cross or WS.CurrentCamera.ViewportSize/2 end return UIS:GetMouseLocation() end
function RM.getAimDirection() local p=spt() local r=WS.CurrentCamera:ViewportPointToRay(p.X,p.Y) return r.Direction,r.Origin end
local function mkAim()
  local z=ST.AimSize local c=C.ac
  aimF=I("Frame",{Name="RM_Aim",Size=UDim2.fromOffset(z,z),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundTransparency=1,Active=mob,ZIndex=55},gui)
  local rg=I("Frame",{Size=UDim2.fromScale(.8,.8),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,ZIndex=55},aimF) cr(rg,999)
  aimE={sk(rg,c,1.5,.5)}
  local function bx(sz,ps) aimE[#aimE+1]=I("Frame",{Size=sz,Position=ps,AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=c,BorderSizePixel=0,ZIndex=56},aimF) end
  bx(UDim2.fromOffset(4,4),UDim2.fromScale(.5,.5)) cr(aimE[#aimE],99)
  bx(UDim2.new(0,2,.19,0),UDim2.fromScale(.5,.28)) bx(UDim2.new(0,2,.19,0),UDim2.fromScale(.5,.72))
  bx(UDim2.new(.19,0,0,2),UDim2.fromScale(.28,.5)) bx(UDim2.new(.19,0,0,2),UDim2.fromScale(.72,.5))
  aimL=I("TextLabel",{Size=UDim2.fromOffset(150,20),Position=UDim2.fromScale(.5,1.25),AnchorPoint=Vector2.new(.5,0),BackgroundTransparency=1,TextColor3=c,Font=Enum.Font.Code,TextSize=12,Text="0 st",ZIndex=57},aimF)
  local dg=false
  aimF.InputBegan:Connect(function(i) if mob and i.UserInputType==Enum.UserInputType.Touch then dg=true end end)
  track(UIS.InputChanged:Connect(function(i) if dg and i.UserInputType==Enum.UserInputType.Touch then cross=i.Position end end))
  track(UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then dg=false end end))
  if mob then
    local fb=I("TextButton",{Name="RM_Fire",Size=UDim2.fromOffset(70,70),Position=UDim2.new(1,-90,1,-130),BackgroundColor3=W(255,60,80),BackgroundTransparency=.2,Text="🔥",TextColor3=W(255,255,255),Font=Enum.Font.GothamBold,TextSize=35,ZIndex=55},gui) cr(fb,99) sk(fb,c,2,.3) drag(fb)
    fb.MouseButton1Click:Connect(function() if RM.fireFromAim then pcall(RM.fireFromAim) end fb.Size=UDim2.fromOffset(60,60) task.delay(.1,function() fb.Size=UDim2.fromOffset(70,70) end) end)
  end
end
mkAim()
do local acc=0
  track(RS.RenderStepped:Connect(function(dt)
    if not aimF then return end
    local p=spt() aimF.Position=UDim2.fromOffset(p.X,p.Y)
    acc+=dt if acc<.1 then return end acc=0
    local ch=LP.Character local hr=ch and ch:FindFirstChild("HumanoidRootPart") if not hr then return end
    local r=WS.CurrentCamera:ViewportPointToRay(p.X,p.Y)
    local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances={ch}
    local res=WS:Raycast(r.Origin,r.Direction*1000,rp)
    local tp=res and res.Position or r.Origin+r.Direction*1000
    aimL.Text=math.floor((tp-hr.Position).Magnitude).." st"
    local m=res and res.Instance:FindFirstAncestorOfClass("Model") local hit=m and Pl:GetPlayerFromCharacter(m)
    local col=hit and W(255,80,80) or C.ac aimL.TextColor3=col
    for _,e in ipairs(aimE) do if e:IsA("UIStroke") then e.Color=col else e.BackgroundColor3=col end end
  end))
end
-- ===== СКИНЫ: Motor6D-скелет =====
local K,M,mot,base=1,nil,{},{}
local function mkp(n,sz,col,mat,sh,k)
  local p=Instance.new("Part") if sh then p.Shape=sh end
  p.Name=n p.Size=sz*(k or K) p.Color=col p.Material=mat or Enum.Material.SmoothPlastic
  p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false p.Massless=true
  p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth return p
end
local function kc(o) if typeof(o)=="Vector3" then return CFrame.new(o*K) end return CFrame.new(o.Position*K)*o.Rotation end
local function jn(a,b,c0,c1) c1=c1 or CFrame.identity local m=Instance.new("Motor6D") m.Part0=a m.Part1=b m.C0=c0 m.C1=c1 b.CFrame=a.CFrame*c0*c1:Inverse() m.Parent=b return m end
local function att(par,n,sz,col,o,mat,sh) local p=mkp(n,sz,col,mat,sh) p.Parent=M jn(par,p,kc(o)) return p end -- статичная деталь
local function limb(par,n,sz,col,o,mat,zo) -- подвижная часть: висит вниз от сустава
  local p=mkp(n,sz,col,mat) p.Parent=M local m=jn(par,p,kc(o),CFrame.new(0,sz.Y/2*K,(zo or 0)*K)) mot[n]=m base[n]=m.C0 return p
end
local V=Vector3.new
local SK={
  rick={name="Рик Санчес",ico="🧪",desc="Халат со складками, шипы, зубы, пальцы",skin=W(190,180,180),hair=W(165,205,240),shirt=W(150,215,205),coat=W(245,245,248),fold=W(208,210,222),up=W(245,245,248),fo=W(245,245,248),cuff=W(150,215,205),pants=W(108,96,50),shoe=W(78,83,92),sock=W(245,245,245),belt=W(60,45,30),buckle=W(235,190,40),hs=V(1.4,1.5,1.25),ey=.15,ex=.3,er=.52,pr=.1,nl=.4,ny=-.05,open=true,brow=.3,spk=true},
  morty={name="Морти Смит",ico="😰",desc="Жёлтая футболка, большие глаза",skin=W(238,196,156),hair=W(125,85,52),shirt=W(236,226,98),up=W(236,226,98),fo=W(238,196,156),pants=W(48,66,112),shoe=W(240,240,240),hs=V(1.6,1.65,1.4),ey=.05,ex=.33,er=.64,pr=.13,nl=.18,ny=-.2},
  rick_prime={name="Рик Прайм",ico="💀",desc="Куртка, полоски, ботинки, кобура",skin=W(205,195,200),hair=W(165,205,240),shirt=W(112,102,148),jacket=true,pad=W(160,170,200),stripe=W(225,50,95),up=W(48,48,78),fo=W(48,48,78),cuff=W(112,102,148),pants=W(34,34,56),shoe=W(82,88,118),belt=W(70,72,100),holster=true,boot=true,hs=V(1.4,1.5,1.25),ey=.15,ex=.3,er=.55,pr=.11,nl=.35,ny=-.05,open=true,brow=.1,spk=true},
}
SK.evil_morty={} for k,v in pairs(SK.morty) do SK.evil_morty[k]=v end
SK.evil_morty.name="Злой Морти" SK.evil_morty.ico="🖤" SK.evil_morty.desc="Повязка, руки в боки" SK.evil_morty.patch=true SK.evil_morty.hips=true SK.evil_morty.brow=.2
local function build(root,S)
  local sc,hs=S.skin,S.hs
  local T=mkp("Torso",V(1.8,2,.9),S.shirt) T.Parent=M
  mot.Torso=jn(root,T,kc(V(0,-.6,0)),CFrame.new(0,-K,0)) base.Torso=mot.Torso.C0
  if S.belt then att(T,"Belt",V(1.86,.22,.96),S.belt,V(0,-.88,0)) att(T,"Buckle",V(.3,.2,.05),S.buckle or S.belt,V(0,-.88,-.5)) end
  att(T,"Neck",V(.5,.3,.5),sc,V(0,1.05,0))
  local H=mkp("Head",hs,sc) H.Parent=M mot.Head=jn(T,H,kc(V(0,1,0)),CFrame.new(0,-hs.Y/2*K,0)) base.Head=mot.Head.C0
  local fz=-hs.Z/2
  for _,s in ipairs{-1,1} do
    att(H,"Eye",V(.08,S.er,S.er),W(255,255,255),CFrame.new(s*S.ex,S.ey,fz-.02)*CFrame.Angles(0,math.rad(90),0),nil,Enum.PartType.Cylinder)
    att(H,"Pupil",Vector3.one*S.pr,W(0,0,0),V(s*S.ex-s*.05,S.ey,fz-.08),nil,Enum.PartType.Ball)
    att(H,"Ear",V(.14,.42,.28),sc,V(s*(hs.X/2+.04),-.05,.05))
    if S.brow then att(H,"Brow",V(.45,.1,.1),S.hair,CFrame.new(s*.3,S.ey+.38,fz-.03)*CFrame.Angles(0,0,s*S.brow)) end
  end
  att(H,"Nose",V(.16,S.nl,.2),sc,V(0,S.ny,fz-.08))
  if S.open then
    att(H,"Mouth",V(.62,.36,.05),W(90,20,25),V(0,-.42,fz-.02)) att(H,"Teeth",V(.5,.08,.05),W(215,200,120),V(0,-.28,fz-.05)) att(H,"Tongue",V(.22,.12,.05),W(220,70,90),V(.08,-.52,fz-.05))
  else att(H,"Mouth",V(.2,.14,.05),W(110,50,50),V(0,-.45,fz-.02)) end
  if S.spk then -- шипы волос Рика
    for i=0,12 do
      local a=math.rad(-120+i*20) local rg=i%2==0 local d=V(math.sin(a),0,math.cos(a))
      local p=d*V(hs.X*.42,0,hs.Z*.42)+V(0,hs.Y*(rg and .36 or .1),0)
      local u=(d*(rg and .5 or 1.1)+V(0,rg and 1 or .45,0)).Unit local L=(rg and 1 or .8)+.2*math.sin(i*2.3)
      att(H,"Hair",V(.3,.3,L),S.hair,CFrame.lookAt(p,p+u)*CFrame.new(0,0,-L/2))
    end
    for _,x in ipairs{-.35,0,.35} do local p=V(x,hs.Y*.45,.15) local u=V(x*1.4,1,.1).Unit att(H,"Hair",V(.3,.3,.8),S.hair,CFrame.lookAt(p,p+u)*CFrame.new(0,0,-.4)) end
  else -- причёска Морти
    att(H,"Hair",V(hs.X+.1,.42,hs.Z+.1),S.hair,V(0,hs.Y/2-.12,.04)) att(H,"Fringe",V(hs.X+.1,.24,.3),S.hair,V(0,hs.Y/2-.3,fz+.1)) att(H,"HairB",V(hs.X+.1,.9,.25),S.hair,V(0,hs.Y/2-.55,hs.Z/2))
    for _,s in ipairs{-1,1} do att(H,"Sideburn",V(.12,.5,.45),S.hair,V(s*(hs.X/2+.03),hs.Y/2-.35,.15)) end
  end
  if S.patch then -- повязка Злого Морти
    local dk=W(12,12,12)
    att(H,"Patch",V(.1,.7,.7),dk,CFrame.new(S.ex,S.ey,fz-.07)*CFrame.Angles(0,math.rad(90),0),nil,Enum.PartType.Cylinder)
    att(H,"StrapF",V(hs.X+.08,.09,.07),dk,CFrame.new(0,S.ey+.1,fz-.03)*CFrame.Angles(0,0,-.3)) att(H,"StrapB",V(hs.X+.08,.09,.07),dk,V(0,S.ey+.1,hs.Z/2+.03))
    for _,s in ipairs{-1,1} do att(H,"StrapS",V(.07,.09,hs.Z+.06),dk,V(s*(hs.X/2+.04),S.ey+.1,0)) end
  end
  if S.coat then -- халат: полы, лацканы, воротник, складки
    local c=S.coat
    for _,s in ipairs{-1,1} do
      att(T,"CoatS",V(.14,2,1.05),c,V(s*.95,0,.02)) att(T,"Lapel",V(.38,1.5,.08),c,CFrame.new(s*.5,.2,-.5)*CFrame.Angles(0,0,s*.1))
      limb(T,s<0 and "TL" or "TR",V(.14,1.35,1),c,V(s*.95,-.95,.02))
    end
    att(T,"CoatB",V(1.95,2,.14),c,V(0,0,.5)) att(T,"Collar",V(1.9,.26,.3),c,V(0,.95,.35)) limb(T,"TB",V(1.95,1.35,.14),c,V(0,-.95,.5))
    for _,x in ipairs{-.45,.1,.55} do att(T,"Fold",V(.05,1.7,.04),S.fold,V(x,0,.58)) end
  end
  if S.jacket then
    att(T,"Hood",V(1.5,.4,.55),S.pad,V(0,.98,.2)) att(T,"Zip",V(.06,1.8,.04),W(200,195,225),V(0,0,-.46))
    for _,s in ipairs{-1,1} do att(T,"Stripe",V(.5,.14,.05),S.stripe,CFrame.new(s*.5,.55,-.46)*CFrame.Angles(0,0,s*.25)) att(T,"Pocket",V(.5,.7,.05),S.pad,V(s*.55,-.45,-.46)) end
  end
  for _,s in ipairs{-1,1} do
    local n=s<0 and "L" or "R"
    local au=limb(T,"A"..n,V(.5,1,.5),S.up,V(s*1.15,.82,0))
    local fa=limb(au,"E"..n,V(.45,.95,.45),S.fo,V(0,-.5,0))
    if S.cuff then att(fa,"Cuff",V(.5,.16,.5),S.cuff,V(0,-.4,0)) end
    if S.fold then att(au,"Fold",V(.52,.05,.52),S.fold,V(0,-.15,0)) att(fa,"Fold",V(.47,.05,.47),S.fold,V(0,.2,0)) end
    if S.pad then att(au,"Pad",V(.66,.2,.66),S.pad,V(0,.5,0)) end
    local pm=limb(fa,"W"..n,V(.5,.34,.32),sc,V(0,-.475,0))
    for i=0,3 do att(pm,"Finger",V(.1,.3,.12),sc,CFrame.new(-.18+i*.12,-.3,-.03)*CFrame.Angles(.4,0,0)) end
    att(pm,"Thumb",V(.12,.26,.12),sc,CFrame.new(-s*.29,-.05,-.1)*CFrame.Angles(.5,0,-s*.3))
    local th=limb(root,"H"..n,V(.62,1.25,.62),S.pants,V(s*.45,-.6,0))
    if S.holster and s>0 then att(th,"Holster",V(.2,.6,.42),W(70,75,95),V(.38,-.1,0)) end
    local sh=limb(th,"K"..n,V(.56,.85,.56),S.pants,V(0,-.625,0))
    if S.sock then att(sh,"Sock",V(.5,.22,.5),S.sock,V(0,-.3,0)) end
    if S.boot then att(sh,"Boot",V(.64,.6,.64),S.shoe,V(0,-.12,0)) att(sh,"BStripe",V(.66,.09,.66),S.stripe,V(0,.05,0)) end
    local ft=limb(sh,"F"..n,V(.7,.3,1.15),S.shoe,V(0,-.425,0),nil,.25)
    att(ft,"Toe",V(.7,.22,.45),S.shoe,V(0,.04,-.45))
  end
end
-- процедурный аниматор: idle (дыхание) + walk (по скорости) + прыжок
local animC
local function startAnim(root,hum,S)
  local t,ph,st,k,mt,bs=0,0,{},K,mot,base
  local function sm(n,v,a) local c=st[n] or v c=c+(v-c)*a st[n]=c return c end
  local function ap(n,x,y,z) local m=mt[n] if m then m.C0=bs[n]*CFrame.Angles(x,y or 0,z or 0) end end
  animC=RS.RenderStepped:Connect(function(dt)
    local tm=mt.Torso if not tm.Parent or not root.Parent then return end
    t+=dt local vl=root.AssemblyLinearVelocity local v=Vector3.new(vl.X,0,vl.Z).Magnitude
    local air=hum.FloorMaterial==Enum.Material.Air local a=math.min(1,dt*12)
    local w=(air or v<.4) and 0 or math.clamp(v/math.max(hum.WalkSpeed,1),0,1.4)
    w=sm("w",w,a) local ag=sm("a",air and 1 or 0,a)
    ph+=dt*math.min(v,40)*.55 local s,c=math.sin(ph),math.cos(ph)
    local id=1-math.min(1,w*3) local br=math.sin(t*1.9) local ih=(S.hips and 1 or 0)*id*(1-ag)
    tm.C0=CFrame.new(0,(br*.03*id+math.abs(c)*.07*w)*k,0)*bs.Torso*CFrame.Angles(-.1*w+br*.02*id,-s*.12*w,0)
    ap("Head",.08*w-br*.02*id+ag*.15,math.sin(t*.7)*.1*id,math.sin(t*.5)*.03*id)
    local sw=.75*w local lh,rh=s*sw*(1-ag)+.45*ag,-s*sw*(1-ag)-.15*ag
    local lk,rk=-math.max(0,c)*.9*w*(1-ag)-.7*ag,-math.max(0,-c)*.9*w*(1-ag)-.3*ag
    ap("HL",lh,0,-.03) ap("HR",rh,0,.03) ap("KL",lk) ap("KR",rk) ap("FL",-(lh+lk)*.6) ap("FR",-(rh+rk)*.6)
    local sa=.7*w*(1-ag) local ar,al=s*sa,-s*sa local z=.07+br*.03*id+.9*ag+.5*ih local eb=.15+br*.03*id
    ap("AR",ar,0,z) ap("AL",al,0,-z) ap("ER",eb+math.max(0,ar)*.6,0,-1.3*ih) ap("EL",eb+math.max(0,al)*.6,0,1.3*ih)
    local tl=-(.06+.3*w*(.5+.5*math.sin(ph*2)))+ag*.1
    ap("TB",tl) ap("TL",tl,0,-.04-.1*w) ap("TR",tl,0,.04+.1*w)
  end)
end
local curM,hidden=nil,{}
local function clearSkin()
  if animC then animC:Disconnect() animC=nil end
  if curM then pcall(function() curM:Destroy() end) curM=nil end
  for p,t in pairs(hidden) do if p.Parent then p.Transparency=t end end hidden={}
end
local function applySkin(id)
  local S=SK[id] if not S then return end
  local ch=LP.Character local hum=ch and ch:FindFirstChildOfClass("Humanoid") local root=ch and ch:FindFirstChild("HumanoidRootPart")
  if not root or not hum then return notify("Нет персонажа",C.dg) end
  clearSkin()
  for _,d in ipairs(ch:GetDescendants()) do if d:IsA("BasePart") and d~=root and not d:FindFirstAncestorOfClass("Tool") then hidden[d]=d.Transparency d.Transparency=1 end end
  local gy=hum.RigType==Enum.HumanoidRigType.R15 and hum.HipHeight+root.Size.Y/2 or 3
  K=math.clamp(gy/3,.5,3) -- масштаб под рост аватара
  M=Instance.new("Model") M.Name="RM_Skin_"..id M.Parent=ch curM=M mot,base={},{}
  build(root,S) startAnim(root,hum,S)
  ST.ActiveSkin=id save() notify("🎭 Скин: "..S.name,C.ac)
end
local function removeSkin() clearSkin() ST.ActiveSkin="" save() notify("🎭 Скин снят",C.tx) end
track(LP.CharacterAdded:Connect(function() task.wait(1) if ST.ActiveSkin~="" then applySkin(ST.ActiveSkin) end end))
-- ===== ПОРТАЛЫ =====
local PA,PB,tpCd,acc2,gun=nil,nil,0,0,nil
local LIFE=60
local function pcol() local c=ST.PortalColor return W(c.R,c.G,c.B) end
local function burst(pos,col)
  local p=I("Part",{Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,Transparency=1,Size=Vector3.one*.2,Position=pos},WS)
  local e=I("ParticleEmitter",{Texture="rbxasset://textures/particles/sparkles_main.dds",Rate=0,Lifetime=NumberRange.new(.3,.7),Speed=NumberRange.new(8,20),SpreadAngle=Vector2.new(180,180),Size=NumberSequence.new(1.2,0),LightEmission=1,Color=ColorSequence.new(col)},p)
  e:Emit(24) task.delay(1.2,function() p:Destroy() end)
end
local function killP(P) if P and P.mo then pcall(function() P.mo:Destroy() end) end end
local function newPortal(pos,n,col)
  local up=math.abs(n.Y)>.9 and Vector3.xAxis or Vector3.yAxis
  local at=pos+n*.15
  local P={cf=CFrame.lookAt(at,at+n,up),pos=at,n=n,A=2.6,B=4,els={},t0=os.clock(),mo=I("Model",{Name="RM_Portal"},WS)}
  local lt,dk=col:Lerp(W(255,255,255),.5),col:Lerp(W(0,0,0),.4)
  local function el(k,c,sz,rs,th,sp,sh,tr)
    local p=mkp("PL",sz,c,Enum.Material.Neon,sh,1) p.Anchored=true p.Transparency=tr or 0 p.Parent=P.mo
    local e={p=p,k=k,s=sz,rs=rs,th=th,sp=sp} P.els[#P.els+1]=e return e
  end
  for i,d in ipairs{{.8,dk,.15,0},{.55,col,.25,-.04}} do -- диски-ядро
    local e=el("d",d[2],V(.12,2*P.B*d[1],2*P.A*d[1]),0,0,0,Enum.PartType.Cylinder,d[3])
    e.p.CFrame=P.cf*CFrame.new(0,0,d[4])*CFrame.Angles(0,math.rad(90),0)
    if i==1 then I("PointLight",{Color=col,Range=14,Brightness=2,Shadows=false},e.p) end
  end
  for i=1,12 do el("b",i%2==0 and lt or col,Vector3.one*(1+((i*7)%5)*.09),1,i/12*6.283,.5,Enum.PartType.Ball) end -- рваный внешний край
  for i=1,8 do el("b",col,Vector3.one*.9,.76,i/8*6.283,-1.1,Enum.PartType.Ball,.1) end -- средний слой (против часовой)
  for i=1,5 do el("b",dk,Vector3.one*.7,.5,i/5*6.283,2.2,Enum.PartType.Ball,.1) end -- внутренний слой (быстрый)
  for i=0,7 do el("a",lt,V(.7,.14,.14),.12+i*.095,i*.85,2.6,nil,.1) end -- спираль
  for i=0,2 do -- 3 излучателя летят по краю и сыплют частицы к центру
    local e=el("e",lt,Vector3.one*.2,1.02,i*2.094,-1.6,nil,1)
    I("ParticleEmitter",{Texture="rbxasset://textures/particles/sparkles_main.dds",EmissionDirection=Enum.NormalId.Front,Rate=10,Lifetime=NumberRange.new(.8,1.1),Speed=NumberRange.new(3.2,4),SpreadAngle=Vector2.new(8,8),Size=NumberSequence.new(.5,0),Transparency=NumberSequence.new(.1,1),LightEmission=1,Color=ColorSequence.new(lt),RotSpeed=NumberRange.new(-120,120)},e.p)
  end
  return P
end
local function upd(P,t)
  local o=math.min(1,t/.4) o=1-(1-o)^3
  local list,cfs={},{}
  for _,e in ipairs(P.els) do
    if o<1 or not P.done then e.p.Size=e.s*math.max(o,.02) end
    if e.k~="d" then
      local th=e.th+t*e.sp local rs=e.rs*(1+.05*math.sin(t*2.3+e.th*3))*o
      local x,y=math.cos(th)*P.A*rs,math.sin(th)*P.B*rs local cf
      if e.k=="a" then cf=P.cf*CFrame.new(x,y,0)*CFrame.Angles(0,0,th+1.9)
      elseif e.k=="e" then cf=CFrame.lookAt(P.cf*V(x,y,0),P.pos)
      else cf=P.cf*CFrame.new(x,y,0) end
      list[#list+1]=e.p cfs[#cfs+1]=cf
    end
  end
  if o>=1 then P.done=true end
  WS:BulkMoveTo(list,cfs,Enum.BulkMoveMode.FireCFrameChanged)
end
local function tp(hr,to)
  tpCd=os.clock()+1.3 local col=pcol() burst(hr.Position,col)
  local ex=to.pos+to.n*4.5 local lk=V(to.n.X,0,to.n.Z) if lk.Magnitude<.1 then lk=hr.CFrame.LookVector end
  hr.CFrame=CFrame.lookAt(ex,ex+lk) hr.AssemblyLinearVelocity=to.n*18 burst(ex,col) snd("teleport",.8,1.2)
end
track(RS.Heartbeat:Connect(function(dt)
  local now=os.clock()
  if PA and PB and now>=tpCd and now-PA.t0>.5 and now-PB.t0>.5 then
    local ch=LP.Character local hr=ch and ch:FindFirstChild("HumanoidRootPart")
    if hr then local to=(hr.Position-PA.pos).Magnitude<3 and PB or (hr.Position-PB.pos).Magnitude<3 and PA if to then tp(hr,to) end end
  end
  acc2+=dt if acc2<.033 then return end acc2=0 -- визуал порталов ~30 Гц
  if PA then upd(PA,now-PA.t0) end if PB then upd(PB,now-PB.t0) end
  if PA and now-PA.t0>LIFE then killP(PA) PA=nil end if PB and now-PB.t0>LIFE then killP(PB) PB=nil end
end))
local function shoot()
  local d,o=RM.getAimDirection() if not d then return end
  local ig={LP.Character} if PA then ig[#ig+1]=PA.mo end if PB then ig[#ig+1]=PB.mo end
  local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances=ig
  local r=WS:Raycast(o,d*500,rp) local pos,n if r then pos,n=r.Position,r.Normal else pos,n=o+d*50,-d end
  local col=pcol()
  if not PA then PA=newPortal(pos,n,col) notify("🌀 Портал A",col)
  elseif not PB then PB=newPortal(pos,n,col) notify("🌀 Портал B",col)
  elseif PA.t0<=PB.t0 then killP(PA) PA=newPortal(pos,n,col) notify("🌀 Портал A пересоздан",col)
  else killP(PB) PB=newPortal(pos,n,col) notify("🌀 Портал B пересоздан",col) end
  local dm=gun and gun:FindFirstChild("DomeTop")
  if dm then
    local a=dm.Position local dist=(pos-a).Magnitude
    local b=mkp("Beam",V(.25,.25,dist),col,Enum.Material.Neon,nil,1) b.Anchored=true b.CFrame=CFrame.lookAt(a,pos)*CFrame.new(0,0,-dist/2) b.Parent=WS
    TS:Create(b,TweenInfo.new(.25),{Transparency=1}):Play() task.delay(.3,function() b:Destroy() end)
  end
  snd("shoot",.6)
end
RM.shootPortal=shoot RM.fireFromAim=shoot
-- ===== ПОРТАЛЬНАЯ ПУШКА (по фото: белый корпус, колба, LED C-137, провода) =====
local function buildGun()
  local tl=I("Tool",{Name="Portal Gun",RequiresHandle=true,CanBeDropped=false,ToolTip="ЛКМ / 🔥 — портал"})
  local h=mkp("Handle",V(.45,1.3,.6),W(214,217,222),nil,nil,1) h.Parent=tl
  local function gp(n,sz,c,o,m,sh) local p=mkp(n,sz,c,m,sh,1) p.Parent=tl local w=Instance.new("Weld") w.Part0=h w.Part1=p w.C0=o p.CFrame=h.CFrame*o w.Parent=p return p end
  local R90=CFrame.Angles(0,0,math.rad(90)) local GR=W(60,255,90)
  gp("Body",V(1.15,.3,2.2),W(228,230,233),CFrame.new(0,.8,-.75)) gp("Under",V(.95,.14,1.7),W(140,145,152),CFrame.new(0,.63,-.9))
  gp("Nozzle",V(.5,.2,.35),W(95,100,108),CFrame.new(0,.82,-1.95)) gp("GripEnd",V(.5,.32,.66),W(150,155,160),CFrame.new(0,-.62,.03))
  gp("Ring",V(.12,.95,.95),W(140,215,175),CFrame.new(0,.99,-1.2)*R90,Enum.Material.Fabric,Enum.PartType.Cylinder)
  gp("Dome",V(.9,.6,.6),GR,CFrame.new(0,1.5,-1.2)*R90,Enum.Material.Glass,Enum.PartType.Cylinder).Transparency=.35
  gp("DomeTop",Vector3.one*.6,GR,CFrame.new(0,1.95,-1.2),Enum.Material.Glass,Enum.PartType.Ball).Transparency=.35
  local c1=gp("Core",V(.9,.38,.38),W(110,255,110),CFrame.new(0,1.5,-1.2)*R90,Enum.Material.Neon,Enum.PartType.Cylinder) c1.Transparency=.25
  gp("CoreTop",Vector3.one*.38,W(110,255,110),CFrame.new(0,1.95,-1.2),Enum.Material.Neon,Enum.PartType.Ball).Transparency=.25
  I("PointLight",{Color=GR,Range=9,Brightness=2,Shadows=false},c1)
  local led=gp("Led",V(.8,.05,.34),W(14,14,16),CFrame.new(0,.97,-.25))
  local sg=I("SurfaceGui",{Face=Enum.NormalId.Top,CanvasSize=Vector2.new(160,68),LightInfluence=0,Brightness=2},led)
  I("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="C-137",TextColor3=W(255,40,40),Font=Enum.Font.Code,TextScaled=true},sg)
  gp("Btn",V(.1,.4,.4),W(28,28,30),CFrame.new(0,.99,.12)*R90,nil,Enum.PartType.Cylinder)
  local function cab(pts,c) for i=1,#pts-1 do local a,b=pts[i],pts[i+1] gp("Wire",V((b-a).Magnitude,.07,.07),c,CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.rad(90),0),nil,Enum.PartType.Cylinder) end end
  cab({V(.32,1.02,-1.4),V(.52,1.08,-1),V(.55,1,-.5),V(.42,.9,.05)},W(30,30,34))
  cab({V(-.32,1.02,-1.4),V(-.52,1.08,-1),V(-.55,1,-.5),V(-.42,.9,.05)},W(60,62,70))
  tl.Parent=LP.Backpack return tl
end
local function equipGun()
  if gun then pcall(function() gun:Destroy() end) end
  local ch=LP.Character local hum=ch and ch:FindFirstChildOfClass("Humanoid") if not hum then return notify("Нет персонажа",C.dg) end
  gun=buildGun() gun.Activated:Connect(shoot) hum:EquipTool(gun) notify("🌀 Пушка в руках",C.ac)
end
-- ===== ВКЛАДКИ =====
do local f=tf.skins newSec(f,"ЗАМЕНА ТЕЛА (Motor6D + анимации)")
  for _,id in ipairs{"rick","morty","evil_morty","rick_prime"} do
    local S=SK[id] local b=newBtn(f,"",C.bg2,nil,40)
    I("TextLabel",{Size=UDim2.new(1,-20,0,14),Position=UDim2.fromOffset(10,4),BackgroundTransparency=1,Text=S.ico.." "..S.name,TextColor3=C.tx,Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=43},b)
    I("TextLabel",{Size=UDim2.new(1,-20,0,12),Position=UDim2.fromOffset(10,22),BackgroundTransparency=1,Text=S.desc,TextColor3=C.dim,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=43},b)
    b.MouseButton1Click:Connect(function() applySkin(id) end)
  end
  newBtn(f,"↩ Вернуть своё тело",C.bg2,removeSkin,34).TextColor3=C.dg
end
do local f=tf.portal newSec(f,"ПОРТАЛЬНАЯ ПУШКА")
  newBtn(f,"🌀 Экипировать пушку",C.ac,equipGun,40)
  newBtn(f,"🔥 Создать портал",C.bg2,shoot,40)
  newBtn(f,"🗑 Удалить оба портала",C.dg,function() killP(PA) PA=nil killP(PB) PB=nil notify("🗑 Порталы удалены",C.tx) end,34)
  newSec(f,"КАК РАБОТАЕТ")
  newInfo(f,"\n  1-й выстрел — портал A, 2-й — портал B\n  Дальше заменяется более старый портал.\n  Зайди в один — вылетишь из другого.\n  Порталы исчезают через 60 сек.",90)
end
do local f=tf.settings
  newSec(f,"ЗВУК")
  local sb sb=newBtn(f,"🔊 Звуки: "..(ST.SoundEnabled and "ВКЛ" or "ВЫКЛ"),C.bg2,function() ST.SoundEnabled=not ST.SoundEnabled sb.Text="🔊 Звуки: "..(ST.SoundEnabled and "ВКЛ" or "ВЫКЛ") save() end,32)
  newSec(f,"ЦВЕТ ПОРТАЛОВ")
  local PC={{"🟢 Зелёный",{R=50,G=255,B=50}},{"🔵 Синий",{R=50,G=150,B=255}},{"🟣 Фиолет",{R=180,G=50,B=255}},{"🟡 Жёлтый",{R=255,G=220,B=50}},{"🔴 Красный",{R=255,G=60,B=60}}}
  local pi=1 for i,p in ipairs(PC) do if p[2].R==ST.PortalColor.R and p[2].G==ST.PortalColor.G then pi=i break end end
  local pb pb=newBtn(f,"🎨 "..PC[pi][1],C.bg2,function() pi=pi%#PC+1 ST.PortalColor=PC[pi][2] pb.Text="🎨 "..PC[pi][1] save() notify("🎨 Цвет изменён",C.ac) end,32)
  newSec(f,"ПРИЦЕЛ")
  local AS={50,64,80,100} local ai=1 for i,v in ipairs(AS) do if v==ST.AimSize then ai=i break end end
  local ab ab=newBtn(f,"🎯 Размер прицела: "..ST.AimSize,C.bg2,function() ai=ai%#AS+1 ST.AimSize=AS[ai] ab.Text="🎯 Размер прицела: "..ST.AimSize aimF.Size=UDim2.fromOffset(ST.AimSize,ST.AimSize) save() end,32)
  newSec(f,"СБРОС")
  newBtn(f,"🔄 Сбросить всё",C.dg,function()
    ST.SoundEnabled=true ST.NotificationsEnabled=true ST.PortalColor={R=50,G=255,B=50} ST.AimSize=64 removeSkin()
    sb.Text="🔊 Звуки: ВКЛ" pi=1 pb.Text="🎨 "..PC[1][1] ai=2 ab.Text="🎯 Размер прицела: 64" aimF.Size=UDim2.fromOffset(64,64) save() notify("🔄 Сброшено",C.ok)
  end,34)
  newSec(f,"ВЫХОД") newBtn(f,"❌ ВЫГРУЗИТЬ СКРИПТ",C.dg,function() RM.unload() end,36)
  newSec(f,"О СКРИПТЕ") newInfo(f,"\n  Rick & Morty Toolkit v"..RM._version.."\n  4 скина на Motor6D, процедурные idle/walk\n  Пушка по фото, порталы со слоями и спиралью.",80)
end
sw("skins")
function RM.unload()
  for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end conns={}
  clearSkin() killP(PA) killP(PB) PA,PB=nil,nil
  if gun then pcall(function() gun:Destroy() end) end
  pcall(function() sf:Destroy() end) pcall(function() gui:Destroy() end)
  if G.RickMorty==RM then G.RickMorty=nil end
  warn("[RickMorty] выгружен")
end
if ST.ActiveSkin~="" then task.delay(2,function() applySkin(ST.ActiveSkin) end) end
notify("🌀 Rick & Morty v"..RM._version.." загружен",C.ac,4)
warn("[RickMorty v"..RM._version.."] загружен. Прицел: "..(mob and "мобильный" or "ПК"))
return RM
