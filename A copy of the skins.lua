--[[
  Avatar Copier v1.8 (отдельный скрипт, standalone)
  Копирует аватар по НИКУ (или ID) на твоего персонажа: лицо, волосы, форма и размер тела,
  цвета, одежда (футболка, штаны, графика) и ВСЕ аксессуары (шапки, крылья, детали).
  Видишь только ты. Только встроенные сервисы Roblox: без loadstring и HttpGet.

  За основу взята v1.1 (она не уносит тебя на Луну: на твоём персонаже нет чужих физических частей).
  v1.8: режим «визуальный R6» (кнопка, по умолчанию выключен): если скин R6, а у тебя R15,
        твои R15-части скрываются, и вместо них показываются R6-части скина, прикреплённые к твоему скелету.
        Хитбокс и анимации остаются R15.
  v1.7: форма тела подгоняется вручную по эталонной модели (если масштаб Humanoid не сработал),
        копируются анимации (походка, бег, прыжок, падение, лазание, плавание, idle).
  Что было в v1.6:
   - ник ищется через Roblox, списка игроков сервера больше нет;
   - по нику собирается полная модель игрока (Players:CreateHumanoidModelFromDescription),
     из неё копируются лицо, форма и размер тела, волосы и все вещи;
   - скин из тулкита Рика и Морти снимается автоматически (нужен тулкит v4.8);
   - после копирования возвращаются твои скорость и прыжок, позиция и камера.
  «Вернуть моё» возвращает твой прежний вид.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer

-- повторный запуск: убрать старое окно
local okEnv, ENV = pcall(function() return getgenv() end)
if not okEnv or type(ENV) ~= "table" then ENV = _G end
if ENV.RM_AvatarCopier and ENV.RM_AvatarCopier.destroy then pcall(ENV.RM_AvatarCopier.destroy) end

-- ============================================================
--  СОСТОЯНИЕ
-- ============================================================
local S = {
  acc = {},      -- всё, что мы добавили на твоего персонажа (клоны, одежда, аксессуары)
  undo = {},     -- функции, которые возвращают изменённое (лицо, голова)
  stash = {},    -- твои вещи, убранные на время копии
  scales = {},   -- твои исходные значения масштаба
  applied = false, myDesc = nil, char = nil, busy = false,
  optScale = true, optAnim = true, visualR6 = false, lastId = nil, snap = nil,
}
local LOOK = { Shirt = true, Pants = true, ShirtGraphic = true, BodyColors = true, CharacterMesh = true }
local SCALE_NAMES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale", "BodyTypeScale", "BodyProportionScale" }
local DESC_SCALE = {
  BodyHeightScale = "HeightScale", BodyWidthScale = "WidthScale", BodyDepthScale = "DepthScale",
  HeadScale = "HeadScale", BodyTypeScale = "BodyTypeScale", BodyProportionScale = "ProportionScale",
}
local R15_TO_R6 = {
  UpperTorso = "Torso", LowerTorso = "Torso", Head = "Head",
  LeftUpperArm = "Left Arm", LeftLowerArm = "Left Arm", LeftHand = "Left Arm",
  RightUpperArm = "Right Arm", RightLowerArm = "Right Arm", RightHand = "Right Arm",
  LeftUpperLeg = "Left Leg", LeftLowerLeg = "Left Leg", LeftFoot = "Left Leg",
  RightUpperLeg = "Right Leg", RightLowerLeg = "Right Leg", RightFoot = "Right Leg",
}
local R6_TO_R15 = {
  Torso = "UpperTorso", Head = "Head", ["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm",
  ["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg",
}

local R15_PARTS = {
  "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
  "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
  "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
-- слот описания -> папка в скрипте Animate -> имена Animation внутри
local ANIM_SLOTS = {
  { "IdleAnimation", "idle", { "Animation1", "Animation2" } },
  { "WalkAnimation", "walk", { "WalkAnim" } },
  { "RunAnimation", "run", { "RunAnim" } },
  { "JumpAnimation", "jump", { "JumpAnim" } },
  { "FallAnimation", "fall", { "FallAnim" } },
  { "ClimbAnimation", "climb", { "ClimbAnim" } },
  { "SwimAnimation", "swim", { "Swim" } },
}

local setStatus -- объявлена заранее (окно ниже)

local function getChar()
  local ch = LP.Character
  local hum = ch and ch:FindFirstChildOfClass("Humanoid")
  local root = ch and ch:FindFirstChild("HumanoidRootPart")
  return ch, hum, root
end

local function fixCamera() -- камера всегда на твоём персонаже
  local cam = Workspace.CurrentCamera
  local _, hum = getChar()
  if cam and hum then
    cam.CameraSubject = hum
    cam.CameraType = Enum.CameraType.Custom
  end
end

local function shortErr(e, n)
  e = tostring(e)
  n = n or 80
  return #e > n and (e:sub(1, n) .. "...") or e
end

local function ourPartFor(ch, name)
  local p = ch:FindFirstChild(name)
  if p and p:IsA("BasePart") then return p, true end
  local alt = R15_TO_R6[name] or R6_TO_R15[name]
  p = alt and ch:FindFirstChild(alt)
  if p and p:IsA("BasePart") then return p, false end
  return nil, false
end

local function scrub(inst) -- убрать из клона скрипты и звуки
  for _, d in ipairs(inst:GetDescendants()) do
    if d:IsA("LuaSourceContainer") or d:IsA("Sound") then d:Destroy() end
  end
end

-- все части клона: без якоря, без массы, без коллизий (физически не влияют на тебя)
local function lightParts(inst)
  local list = inst:IsA("BasePart") and { inst } or {}
  for _, d in ipairs(inst:GetDescendants()) do
    if d:IsA("BasePart") then list[#list + 1] = d end
  end
  for _, p in ipairs(list) do
    p.Anchored = false
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Massless = true
  end
end

-- ============================================================
--  ФОРМА ТЕЛА (R15): снимок своего тела и подгонка под эталонную модель
-- ============================================================
local function isR15(ch)
  return ch ~= nil and ch:FindFirstChild("UpperTorso") ~= nil
end

-- запоминаем своё настоящее тело: размеры частей, точки крепления, суставы, высоту
local function snapshotShape(ch, hum)
  local snap = { parts = {}, hip = hum.HipHeight }
  for _, n in ipairs(R15_PARTS) do
    local p = ch:FindFirstChild(n)
    if p and p:IsA("BasePart") then
      local e = { part = p, size = p.Size, att = {}, mot = {} }
      for _, d in ipairs(p:GetChildren()) do
        if d:IsA("Attachment") then
          e.att[#e.att + 1] = { d, d.Position }
        elseif d:IsA("Motor6D") then
          e.mot[#e.mot + 1] = { d, d.C0, d.C1 }
        end
      end
      snap.parts[#snap.parts + 1] = e
    end
  end
  return snap
end

local function restoreShape(snap)
  local _, hum = getChar()
  for _, e in ipairs(snap.parts) do
    pcall(function()
      if not e.part.Parent then return end
      e.part.Size = e.size
      for _, a in ipairs(e.att) do a[1].Position = a[2] end
      for _, m in ipairs(e.mot) do
        m[1].C0 = m[2]
        m[1].C1 = m[3]
      end
    end)
  end
  if hum and snap.hip then pcall(function() hum.HipHeight = snap.hip end) end
end

-- насколько размеры наших частей отличаются от эталона (0 = совпали, .3 = на 30%)
local function shapeMismatch(ch, ref)
  local worst = 0
  for _, n in ipairs(R15_PARTS) do
    if n ~= "HumanoidRootPart" then
      local a, b = ch:FindFirstChild(n), ref:FindFirstChild(n)
      if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
        local sa, sb = a.Size, b.Size
        for _, d in ipairs({ math.abs(sa.X - sb.X) / math.max(sb.X, .05), math.abs(sa.Y - sb.Y) / math.max(sb.Y, .05),
          math.abs(sa.Z - sb.Z) / math.max(sb.Z, .05) }) do
          if d > worst then worst = d end
        end
      end
    end
  end
  return worst
end

-- переносим размеры частей, точки крепления и суставы из эталонной модели (как это делает Roblox)
local function applyRefShape(ch, hum, ref, refHum)
  local n = 0
  for _, name in ipairs(R15_PARTS) do
    local op, rp = ch:FindFirstChild(name), ref:FindFirstChild(name)
    if op and rp and op:IsA("BasePart") and rp:IsA("BasePart") then
      local ok = pcall(function()
        op.Size = rp.Size
        for _, d in ipairs(rp:GetChildren()) do
          if d:IsA("Attachment") then
            local oa = op:FindFirstChild(d.Name)
            if oa and oa:IsA("Attachment") then oa.Position = d.Position end
          elseif d:IsA("Motor6D") then
            local om = op:FindFirstChild(d.Name)
            if om and om:IsA("Motor6D") then
              om.C0 = d.C0
              om.C1 = d.C1
            end
          end
        end
      end)
      if ok then n = n + 1 end
    end
  end
  if refHum then
    local okH, hh = pcall(function() return refHum.HipHeight end)
    if okH and type(hh) == "number" and hh > 0 then pcall(function() hum.HipHeight = hh end) end
  end
  return n
end

-- ============================================================
--  АНИМАЦИИ: походка, бег, прыжок и т.д. из описания аватара
-- ============================================================
local function restartAnimate(ch, hum)
  local anim = ch:FindFirstChild("Animate")
  if hum then
    pcall(function()
      for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop(0) end
    end)
  end
  if anim and anim:IsA("LocalScript") then
    pcall(function() anim.Disabled = true end)
    task.wait()
    pcall(function() anim.Disabled = false end)
  end
end

-- возвращает, сколько анимаций заменено
local function applyAnimations(ch, hum, desc)
  local anim = ch:FindFirstChild("Animate")
  if not anim then return 0 end
  local olds, n = {}, 0
  for _, slot in ipairs(ANIM_SLOTS) do
    local okV, id = pcall(function() return desc[slot[1]] end)
    if okV and type(id) == "number" and id ~= 0 then
      local folder = anim:FindFirstChild(slot[2])
      if folder then
        local hit = false
        for _, nm in ipairs(slot[3]) do
          local a = folder:FindFirstChild(nm)
          if a and a:IsA("Animation") then
            olds[#olds + 1] = { a, a.AnimationId }
            a.AnimationId = "http://www.roblox.com/asset/?id=" .. id
            hit = true
          end
        end
        if hit then n = n + 1 end
      end
    end
  end
  if n > 0 then
    S.undo[#S.undo + 1] = function()
      for _, o in ipairs(olds) do pcall(function() o[1].AnimationId = o[2] end) end
      local c, h = getChar()
      if c then restartAnimate(c, h) end
    end
    restartAnimate(ch, hum)
  end
  return n
end

-- ============================================================
--  СКИН ИЗ ТУЛКИТА: снять перед копированием
-- ============================================================
-- true: снят; false: тулкит есть, но старый (нет removeSkin); nil: тулкита нет
local function removeToolkitSkin()
  local rm = ENV.RickMorty
  if type(rm) ~= "table" then return nil end
  if type(rm.removeSkin) ~= "function" then return false end
  return (pcall(rm.removeSkin))
end

-- ============================================================
--  ВОЗВРАТ ТВОЕГО ВИДА
-- ============================================================
local function restoreOwn()
  local ch, hum = getChar()
  for _, a in ipairs(S.acc) do pcall(function() a:Destroy() end) end
  for i = #S.undo, 1, -1 do pcall(S.undo[i]) end
  local hadScales = next(S.scales) ~= nil
  if ch and S.char == ch and hum then
    for n, val in pairs(S.scales) do
      local ov = hum:FindFirstChild(n)
      if ov then ov.Value = val end
    end
    for _, d in ipairs(S.stash) do d.Parent = ch end -- сварки у вещей свои, как были
  end
  if S.snap and ch and S.char == ch then
    if hadScales then task.wait(.15) end -- дать движку пересчитать масштаб, потом вернуть свои размеры
    restoreShape(S.snap)
  end
  S.acc, S.undo, S.stash, S.scales, S.char, S.snap = {}, {}, {}, {}, nil, nil
end

local function restoreAll()
  S.lastId = nil
  local wasApplied = S.applied
  restoreOwn()
  if wasApplied then
    local _, hum = getChar()
    S.applied = false
    if hum and S.myDesc then
      local ok, e = pcall(function() hum:ApplyDescription(S.myDesc) end)
      if not ok then return false, "ApplyDescription: " .. shortErr(e) end
    else
      return false, "нет сохранённого описания: умри и возродись, чтобы вернуть вид"
    end
  end
  return true
end

-- убрать твои вещи на время копии (вернутся кнопкой «Вернуть моё»)
local function stashOwn(ch, hum)
  for _, d in ipairs(ch:GetChildren()) do
    if d:IsA("Accessory") or LOOK[d.ClassName] then S.stash[#S.stash + 1] = d end
  end
  for _, d in ipairs(S.stash) do d.Parent = nil end
end

-- ============================================================
--  АКСЕССУАРЫ: ручное крепление по точкам крепления
-- ============================================================
local function findOurAttachment(ch, name)
  for _, p in ipairs(ch:GetChildren()) do
    if p:IsA("BasePart") then
      local a = p:FindFirstChild(name)
      if a and a:IsA("Attachment") then return p, a end
    end
  end
  return nil, nil
end

-- c: клон Accessory. возвращает true, способ
local function attachAccessory(c, ch, root)
  local hd = c:FindFirstChild("Handle")
  if not (hd and hd:IsA("BasePart")) then return false, "нет Handle" end
  -- внешние сварки (на части исходного персонажа): запомнить и убрать
  local ext
  for _, d in ipairs(c:GetDescendants()) do
    if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
      local p0, p1 = d.Part0, d.Part1
      local out0 = p0 and p0 ~= c and not c:IsAncestorOf(p0)
      local out1 = p1 and p1 ~= c and not c:IsAncestorOf(p1)
      if out0 or out1 then
        ext = ext or { w = d, out0 = out0, p0 = p0, p1 = p1 }
        d:Destroy()
      end
    end
  end
  local w = Instance.new("Weld")
  w.Name = "AccessoryWeld"
  -- 1) как делает Roblox: по одинаковым именам точек крепления
  for _, a in ipairs(hd:GetChildren()) do
    if a:IsA("Attachment") then
      local part, oa = findOurAttachment(ch, a.Name)
      if part and oa then
        w.Part0 = part
        w.Part1 = hd
        w.C0 = oa.CFrame
        w.C1 = a.CFrame
        w.Parent = hd
        c.Parent = ch
        return true, "по точке " .. a.Name
      end
    end
  end
  -- 2) по оригинальной сварке с исходным персонажем
  if ext then
    local other = ext.out0 and ext.p0 or ext.p1
    local inner = ext.out0 and ext.p1 or ext.p0
    local our = other and ourPartFor(ch, other.Name) or nil
    local okW, cf0, cf1 = pcall(function() return ext.w.C0, ext.w.C1 end)
    if our and inner and okW then
      if ext.out0 then
        w.Part0, w.Part1, w.C0, w.C1 = our, inner, cf0, cf1
      else
        w.Part0, w.Part1, w.C0, w.C1 = inner, our, cf0, cf1
      end
      w.Parent = hd
      c.Parent = ch
      return true, "по оригинальной сварке"
    end
  end
  -- 3) запасной вариант: к голове
  local head = ch:FindFirstChild("Head")
  w.Part0 = (head and head:IsA("BasePart")) and head or root
  w.Part1 = hd
  w.C0 = CFrame.new(0, .6, 0)
  w.Parent = hd
  c.Parent = ch
  return true, "к голове"
end

-- клонирует и крепит один Accessory (src: оригинал). возвращает ok, способ
local function addAccessoryClone(a, ch, root)
  local c = a:Clone()
  if not c then return false, "не клонируется" end
  scrub(c)
  local ok, how = attachAccessory(c, ch, root)
  if not ok then
    c:Destroy()
    return false, how
  end
  lightParts(c)
  S.acc[#S.acc + 1] = c
  return true, how
end

-- ============================================================
--  КОПИРОВАНИЕ ИЗ МОДЕЛИ ИГРОКА
-- ============================================================
-- src: модель игрока (из описания аватара). desc: HumanoidDescription. full: полная модель (R15 с телом)
local function copyFromModel(src, desc, full)
  local ch, hum, root = getChar()
  if not (ch and hum and root) then return false, "нет твоего персонажа" end
  restoreOwn()
  S.char = ch
  stashOwn(ch, hum)
  local stat = { cloth = 0, acc = 0, accTotal = 0, body = 0, face = false, scale = false, native = false, notes = {},
    shape = 0, anim = 0, r6 = not isR15(ch) }
  local srcHum = src:FindFirstChildOfClass("Humanoid")
  if not stat.r6 then
    local okS, snap = pcall(snapshotShape, ch, hum)
    if okS then S.snap = snap end
  end

  -- форма частей тела (R15: руки, ноги, торс, голова): берём меш у модели игрока
  if full then
    for _, sp in ipairs(src:GetChildren()) do
      if sp:IsA("MeshPart") then
        local our = ch:FindFirstChild(sp.Name)
        if our and our:IsA("MeshPart") then
          local okM = pcall(function() our:ApplyMesh(sp) end)
          if okM then stat.body = stat.body + 1 end
        end
      end
    end
    if stat.body > 0 then
      S.applied = true -- форму вернёт ApplyDescription(твоё описание)
    elseif desc then
      -- меш напрямую не меняется: родной способ Roblox, но без аксессуаров (они ниже)
      local okN = pcall(function()
        local d2 = desc:Clone()
        d2:SetAccessories({}, true)
        hum:ApplyDescription(d2)
      end)
      if okN then
        S.applied = true
        stat.native = true
      end
    end
  end

  -- размер тела
  if S.optScale then
    local changed = false
    for _, n in ipairs(SCALE_NAMES) do
      local ov = hum:FindFirstChild(n)
      local sv = srcHum and srcHum:FindFirstChild(n)
      local val
      if sv and sv:IsA("NumberValue") then
        val = sv.Value
      elseif desc then
        local okV, dv = pcall(function() return desc[DESC_SCALE[n]] end)
        if okV and type(dv) == "number" then val = dv end
      end
      if ov and ov:IsA("NumberValue") and val then
        if S.scales[n] == nil then S.scales[n] = ov.Value end
        ov.Value = val
        changed = true
      end
    end
    if changed then
      stat.scale = true
      task.wait(.3)
    end
    -- проверка: если части тела не стали как у эталона (Humanoid-масштаб не сработал), подгоняем вручную
    if full and S.snap and not stat.r6 then
      local okM, bad = pcall(shapeMismatch, ch, src)
      if okM and bad > .04 then
        stat.shape = applyRefShape(ch, hum, src, srcHum)
        if stat.shape > 0 then
          stat.scale = true
          task.wait(.1)
        end
      end
    end
  end

  -- одежда и цвета тела: футболка, штаны, графика, BodyColors
  for _, d in ipairs(src:GetChildren()) do
    if LOOK[d.ClassName] then
      local c = d:Clone()
      if c then
        c.Parent = ch
        S.acc[#S.acc + 1] = c
        stat.cloth = stat.cloth + 1
      end
    end
  end

  -- лицо и форма головы
  local sh, mh = src:FindFirstChild("Head"), ch:FindFirstChild("Head")
  if sh and mh then
    local sf = sh:FindFirstChildWhichIsA("Decal")
    if sf then
      local mf = mh:FindFirstChildWhichIsA("Decal")
      if mf then
        local old = mf.Texture
        mf.Texture = sf.Texture
        S.undo[#S.undo + 1] = function() mf.Texture = old end
      else
        local nf = sf:Clone()
        nf.Parent = mh
        S.acc[#S.acc + 1] = nf
      end
      stat.face = true
    end
    local sm, mm = sh:FindFirstChildOfClass("SpecialMesh"), mh:FindFirstChildOfClass("SpecialMesh")
    if sm and mm then
      local o1, o2, o3 = mm.Scale, mm.MeshId, mm.TextureId
      pcall(function()
        mm.Scale = sm.Scale
        mm.MeshId = sm.MeshId
        mm.TextureId = sm.TextureId
      end)
      S.undo[#S.undo + 1] = function()
        mm.Scale, mm.MeshId, mm.TextureId = o1, o2, o3
      end
    end
  end

  -- аксессуары: волосы, шапки, крылья и всё остальное
  for _, a in ipairs(src:GetChildren()) do
    if a:IsA("Accessory") then
      stat.accTotal = stat.accTotal + 1
      local ok, how = addAccessoryClone(a, ch, root)
      if ok then
        stat.acc = stat.acc + 1
      else
        stat.notes[#stat.notes + 1] = a.Name .. ": " .. tostring(how)
      end
    end
  end

  if S.optAnim and desc then
    local okAn, nAn = pcall(applyAnimations, ch, hum, desc)
    if okAn then stat.anim = nAn else stat.notes[#stat.notes + 1] = "анимации: " .. shortErr(nAn, 40) end
  end

  if stat.cloth + stat.acc + stat.body == 0 and not stat.face and not stat.native then
    restoreOwn()
    return false, "у источника ничего не нашлось"
  end
  return true, nil, stat
end

local function loadAssetItem(id, className)
  local ok, m = pcall(function() return InsertService:LoadAsset(id) end)
  if not ok or not m then return nil, shortErr(m, 50) end
  local it = m:FindFirstChildWhichIsA(className, true)
  local c = it and it:Clone() or nil
  m:Destroy()
  return c
end

-- собирает вид из описания аватара вручную: цвета, одежда, лицо, аксессуары (по ID через InsertService)
local function manualFromDescription(desc)
  local ch, hum, root = getChar()
  if not (ch and hum and root) then return false, "нет твоего персонажа" end
  restoreOwn()
  S.char = ch
  stashOwn(ch, hum)
  local stat = { cloth = 0, acc = 0, accTotal = 0, body = 0, notes = {} }

  local bc = Instance.new("BodyColors")
  pcall(function()
    bc.HeadColor3 = desc.HeadColor
    bc.TorsoColor3 = desc.TorsoColor
    bc.LeftArmColor3 = desc.LeftArmColor
    bc.RightArmColor3 = desc.RightArmColor
    bc.LeftLegColor3 = desc.LeftLegColor
    bc.RightLegColor3 = desc.RightLegColor
  end)
  bc.Parent = ch
  S.acc[#S.acc + 1] = bc
  stat.cloth = stat.cloth + 1

  for _, pair in ipairs({ { desc.Shirt, "Shirt" }, { desc.Pants, "Pants" }, { desc.GraphicTShirt, "ShirtGraphic" } }) do
    local id = pair[1]
    if id and id ~= 0 then
      local c, err = loadAssetItem(id, pair[2])
      if c then
        c.Parent = ch
        S.acc[#S.acc + 1] = c
        stat.cloth = stat.cloth + 1
      else
        stat.notes[#stat.notes + 1] = pair[2] .. ": " .. tostring(err)
      end
    end
  end

  if desc.Face and desc.Face ~= 0 then
    local head = ch:FindFirstChild("Head")
    local face = loadAssetItem(desc.Face, "Decal")
    if head and face then
      for _, d in ipairs(head:GetChildren()) do
        if d:IsA("Decal") then d.Texture = face.Texture end
      end
    end
  end

  local okA, list = pcall(function() return desc:GetAccessories(true) end)
  if okA and list then
    for _, info in ipairs(list) do
      stat.accTotal = stat.accTotal + 1
      local acc, err = loadAssetItem(info.AssetId, "Accessory")
      if acc then
        scrub(acc)
        local ok, how = attachAccessory(acc, ch, root)
        if ok then
          lightParts(acc)
          S.acc[#S.acc + 1] = acc
          stat.acc = stat.acc + 1
        else
          acc:Destroy()
          stat.notes[#stat.notes + 1] = tostring(info.AssetId) .. ": " .. tostring(how)
        end
      else
        stat.notes[#stat.notes + 1] = tostring(info.AssetId) .. ": " .. tostring(err)
      end
    end
  end

  if S.optScale then
    for n, f in pairs(DESC_SCALE) do
      local ov = hum:FindFirstChild(n)
      local okV, v = pcall(function() return desc[f] end)
      if ov and okV and type(v) == "number" then
        S.scales[n] = ov.Value
        ov.Value = v
      end
    end
  end
  if S.optAnim then
    local okAn, nAn = pcall(applyAnimations, ch, hum, desc)
    if okAn then stat.anim = nAn end
  end
  return true, nil, stat
end

-- ============================================================
--  ВИЗУАЛЬНЫЙ R6: показываем R6-части скина поверх своего R15-скелета
-- ============================================================
local R6_TO_OURS = {
  { "Torso", "UpperTorso" }, { "Head", "Head" },
  { "Left Arm", "LeftUpperArm" }, { "Right Arm", "RightUpperArm" },
  { "Left Leg", "LeftUpperLeg" }, { "Right Leg", "RightUpperLeg" },
}
local BODY_COLOR_OF = {
  Torso = "TorsoColor", Head = "HeadColor", ["Left Arm"] = "LeftArmColor", ["Right Arm"] = "RightArmColor",
  ["Left Leg"] = "LeftLegColor", ["Right Leg"] = "RightLegColor",
}

local function copyVisualR6(src, desc)
  local ch, hum, root = getChar()
  if not (ch and hum and root) then return false, "нет твоего персонажа" end
  local srcRoot = src:FindFirstChild("HumanoidRootPart") or src:FindFirstChild("Torso")
  if not srcRoot then return false, "в модели R6 нет корня" end
  restoreOwn()
  S.char = ch
  stashOwn(ch, hum)
  local stat = { cloth = 0, acc = 0, accTotal = 0, body = 0, face = false, scale = false, native = false,
    notes = {}, shape = 0, anim = 0, r6 = false, visual = true }

  -- 1) прячем свои R15-части (видно только тебе), вернём через undo
  local hidden = {}
  for _, n in ipairs(R15_PARTS) do
    local p = ch:FindFirstChild(n)
    if p and p:IsA("BasePart") and n ~= "HumanoidRootPart" then
      hidden[#hidden + 1] = p
      p.LocalTransparencyModifier = 1
    end
  end
  S.undo[#S.undo + 1] = function()
    for _, p in ipairs(hidden) do
      if p.Parent then p.LocalTransparencyModifier = 0 end
    end
  end

  -- 2) R6-части скина: клоны, прикреплённые к нашим R15-частям, цвета тела из описания
  for _, pair in ipairs(R6_TO_OURS) do
    local sp, op = src:FindFirstChild(pair[1]), ch:FindFirstChild(pair[2])
    if sp and sp:IsA("BasePart") and op and op:IsA("BasePart") then
      local okC, c = pcall(function() return sp:Clone() end)
      if okC and c then
        for _, d in ipairs(c:GetChildren()) do
          if d:IsA("Motor6D") or d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Attachment") then
            d:Destroy()
          end
        end
        local cf = BODY_COLOR_OF[pair[1]]
        if cf and desc then
          pcall(function() c.Color = desc[cf] end)
        end
        local want = root.CFrame * srcRoot.CFrame:ToObjectSpace(sp.CFrame)
        c.Name = "R6_" .. pair[1]
        c.CFrame = want
        local w = Instance.new("Weld")
        w.Part0 = op
        w.Part1 = c
        w.C0 = op.CFrame:ToObjectSpace(want)
        w.C1 = CFrame.new()
        c.Parent = ch
        w.Parent = c
        lightParts(c)
        S.acc[#S.acc + 1] = c
        stat.body = stat.body + 1
        if pair[1] == "Head" then stat.face = true end
      end
    end
  end
  if stat.body == 0 then
    restoreOwn()
    return false, "в модели R6 не нашлось частей"
  end
  -- 3) футболка и штаны: как у всех, но на скрытом R15-теле они не видны (ограничение режима)
  for _, d in ipairs(src:GetChildren()) do
    if LOOK[d.ClassName] and d.ClassName ~= "BodyColors" then
      local c = d:Clone()
      if c then
        c.Parent = ch
        S.acc[#S.acc + 1] = c
        stat.cloth = stat.cloth + 1
      end
    end
  end
  -- 4) аксессуары крепятся как обычно
  for _, a in ipairs(src:GetChildren()) do
    if a:IsA("Accessory") then
      stat.accTotal = stat.accTotal + 1
      local ok, how = addAccessoryClone(a, ch, root)
      if ok then stat.acc = stat.acc + 1
      else stat.notes[#stat.notes + 1] = a.Name .. ": " .. tostring(how) end
    end
  end
  S.applied = true
  return true, nil, stat
end

-- по порядку: полная модель из описания -> модель внешнего вида -> ручная сборка -> ApplyDescription
local function copyByUserId(uid)
  local ch, hum = getChar()
  if not (ch and hum) then return false, "нет твоего персонажа" end
  local errs = {}
  local okD, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(uid) end)
  if not okD or not desc then return false, "описание: " .. shortErr(desc, 60) end
  local okA, list = pcall(function() return desc:GetAccessories(true) end)
  local expected = (okA and list) and #list or 0

  -- 0) визуальный R6: только если режим включён, скин R6, а у тебя R15
  if S.visualR6 and isR15(ch) then
    local okApp, app = pcall(function() return Players:GetCharacterAppearanceAsync(uid) end)
    if okApp and app and app:FindFirstChild("Torso") and not app:FindFirstChild("UpperTorso") then
      local okV, eV, statV = copyVisualR6(app, desc)
      pcall(function() app:Destroy() end)
      if okV then
        return true, nil, statV, "визуальный R6 (скин R6)"
      end
      errs[#errs + 1] = "визуальный R6: " .. shortErr(eV, 60)
    elseif okApp and app then
      pcall(function() app:Destroy() end)
    end
  end

  -- 1) полная модель игрока из описания (лицо, волосы, тело, одежда)
  local ok1, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, hum.RigType) end)
  if ok1 and model then
    local ok2, e2, stat = copyFromModel(model, desc, true)
    pcall(function() model:Destroy() end)
    if ok2 and (stat.acc > 0 or expected == 0) then
      return true, nil, stat, "модель из описания"
    end
    errs[#errs + 1] = "модель: " .. (ok2 and ("аксессуаров " .. stat.acc .. "/" .. expected) or shortErr(e2, 40))
  else
    errs[#errs + 1] = "сборка модели: " .. shortErr(model, 45)
  end

  -- 2) модель внешнего вида
  local ok3, model2 = pcall(function() return Players:GetCharacterAppearanceAsync(uid) end)
  if ok3 and model2 then
    local ok4, e4, stat = copyFromModel(model2, desc, false)
    pcall(function() model2:Destroy() end)
    if ok4 and (stat.acc > 0 or expected == 0) then
      return true, nil, stat, "модель внешнего вида"
    end
    errs[#errs + 1] = "внешний вид: " .. (ok4 and ("аксессуаров " .. stat.acc .. "/" .. expected) or shortErr(e4, 40))
  else
    errs[#errs + 1] = "внешний вид: " .. shortErr(model2, 45)
  end

  -- 3) вручную из описания (аксессуары по ID)
  local ok5, e5, stat5 = manualFromDescription(desc)
  if ok5 and (stat5.acc > 0 or expected == 0) then
    return true, nil, stat5, "сборка по ID"
  end
  errs[#errs + 1] = "по ID: " .. (ok5 and ("аксессуаров " .. stat5.acc .. "/" .. expected) or shortErr(e5, 40))

  -- 4) родной ApplyDescription
  restoreOwn()
  local ok6, e6 = pcall(function() hum:ApplyDescription(desc) end)
  if ok6 then
    S.applied = true
    return true, nil, { cloth = 0, acc = 0, accTotal = expected, body = 0, face = true, scale = true, native = true, notes = {}, shape = 0, anim = 0 }, "ApplyDescription"
  end
  errs[#errs + 1] = "ApplyDescription: " .. shortErr(e6, 45)
  return false, table.concat(errs, " | ")
end

local function statText(stat, how)
  local parts = {}
  if stat then
    parts[#parts + 1] = "аксессуары " .. stat.acc .. (stat.accTotal > 0 and ("/" .. stat.accTotal) or "")
    if stat.cloth > 0 then parts[#parts + 1] = "одежда " .. stat.cloth end
    if stat.face then parts[#parts + 1] = "лицо" end
    if stat.body > 0 then parts[#parts + 1] = "части тела " .. stat.body end
    if stat.native then parts[#parts + 1] = "тело через Roblox" end
    if stat.scale then parts[#parts + 1] = "размер" end
    if stat.shape and stat.shape > 0 then parts[#parts + 1] = "форма тела вручную (" .. stat.shape .. " частей)" end
    if stat.anim and stat.anim > 0 then parts[#parts + 1] = "анимации " .. stat.anim end
    if stat.visual then parts[#parts + 1] = "хитбокс и анимации R15, видно R6" end
    if stat.r6 then parts[#parts + 1] = "R6: форма тела в этой игре не меняется" end
  end
  return (how and (how .. ": ") or "") .. table.concat(parts, ", ")
end

local function doCopy(raw)
  if S.busy then return end
  local text = tostring(raw or ""):match("^%s*(.-)%s*$")
  local id = tonumber(text:match("roblox%.com/users/(%d+)") or text:match("^(%d+)$") or "")
  local nick = (not id) and text:match("^@?([%w_]+)$") or nil
  if not id and not nick then
    setStatus("Введи ник игрока (или ID)", true)
    return
  end
  S.busy = true
  task.spawn(function()
    local _, hum0, root0 = getChar()
    local savedCF = root0 and root0.CFrame
    local ws, jp, jh = hum0 and hum0.WalkSpeed, hum0 and hum0.JumpPower, hum0 and hum0.JumpHeight
    local ok, err = pcall(function()
      local ch, hum = getChar()
      if not (ch and hum) then
        setStatus("Нет твоего персонажа: дождись появления", true)
        return
      end
      if not id then
        setStatus("Ищу ник " .. nick .. "...", false)
        local okN, uid = pcall(function() return Players:GetUserIdFromNameAsync(nick) end)
        if not okN or not uid then
          setStatus("Ник не найден: " .. nick, true)
          return
        end
        id = uid
      end
      setStatus("Копирую аватар " .. id .. "...", false)
      -- вернуть прежнюю копию, запомнить твой настоящий вид, снять скин из тулкита
      restoreAll()
      if not S.myDesc then
        local okM, md = pcall(function() return hum:GetAppliedDescription() end)
        if okM and md then
          S.myDesc = md
        else
          pcall(function() S.myDesc = Players:GetHumanoidDescriptionFromUserId(LP.UserId) end)
        end
      end
      local tk = removeToolkitSkin()
      if tk then task.wait(.15) end
      local okc, e, stat, how = copyByUserId(id)
      if okc then
        S.lastId = id
        local msg = "Готово: " .. statText(stat, how)
        if tk == false then msg = msg .. ". Тулкит старый: обнови до v4.8, чтобы скин Рика/Морти снимался сам" end
        setStatus(msg, false)
        if stat and stat.notes[1] then print("[Copier] не вышло: " .. table.concat(stat.notes, "; ")) end
      else
        warn("[Copier] не удалось: " .. tostring(e))
        setStatus("Не удалось: " .. shortErr(e, 170), true)
      end
    end)
    if not ok then
      warn("[Copier] ошибка: " .. tostring(err))
      setStatus("Ошибка: " .. shortErr(err, 120), true)
    end
    -- защита: вернуть скорость и прыжок, вернуть на место, снять якорь, вернуть камеру
    task.wait(.3)
    local _, hum1, root1 = getChar()
    if hum1 then
      if ws and hum1.WalkSpeed ~= ws then hum1.WalkSpeed = ws end
      if jp and hum1.JumpPower ~= jp then hum1.JumpPower = jp end
      if jh and hum1.JumpHeight ~= jh then hum1.JumpHeight = jh end
    end
    if root1 and savedCF then
      if (root1.Position - savedCF.Position).Magnitude > 25 then root1.CFrame = savedCF end
      if root1.Anchored then root1.Anchored = false end
    end
    fixCamera()
    S.busy = false
  end)
end

local function doRestore()
  if S.busy then return end
  S.busy = true
  task.spawn(function()
    local ok, e = restoreAll()
    if ok then setStatus("Твой вид возвращён", false) else setStatus("Не вышло вернуть: " .. shortErr(e, 120), true) end
    fixCamera()
    S.busy = false
  end)
end

-- ============================================================
--  ОКНО
-- ============================================================
local BG, BG2, ST, TX, DIM, AC, DG = Color3.fromRGB(24, 26, 34), Color3.fromRGB(38, 41, 54), Color3.fromRGB(70, 76, 100),
  Color3.fromRGB(235, 238, 245), Color3.fromRGB(150, 156, 175), Color3.fromRGB(80, 220, 130), Color3.fromRGB(255, 90, 90)

local function mk(class, props, parent)
  local o = Instance.new(class)
  for k, v in pairs(props) do o[k] = v end
  if parent then o.Parent = parent end
  return o
end
local function corner(o, r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }, o) end

local function guiParent()
  local okH, ui = pcall(function() return gethui and gethui() end)
  if okH and ui then return ui end
  local okC, cg = pcall(function() return game:GetService("CoreGui") end)
  if okC and cg then
    local t = Instance.new("Folder")
    local okP = pcall(function() t.Parent = cg end)
    if okP and t.Parent == cg then
      t:Destroy()
      return cg
    end
  end
  return LP:WaitForChild("PlayerGui")
end

local gui = mk("ScreenGui", { Name = "RM_AvatarCopier", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true }, guiParent())
local main = mk("Frame", {
  Size = UDim2.fromOffset(300, 336), Position = UDim2.new(.5, -150, .5, -168), BackgroundColor3 = BG, BorderSizePixel = 0,
}, gui)
corner(main, 12)
mk("UIStroke", { Color = ST, Thickness = 1.5 }, main)

local bar = mk("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = BG2, BorderSizePixel = 0 }, main)
corner(bar, 12)
mk("TextLabel", {
  Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
  Text = "👤 Копиратор аватара v1.8", TextColor3 = TX, Font = Enum.Font.GothamBold, TextSize = 14,
  TextXAlignment = Enum.TextXAlignment.Left,
}, bar)
local btnMin = mk("TextButton", {
  Size = UDim2.fromOffset(32, 28), Position = UDim2.new(1, -72, 0, 4), BackgroundColor3 = ST, Text = "—", TextColor3 = TX,
  Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true,
}, bar)
corner(btnMin, 8)
local btnClose = mk("TextButton", {
  Size = UDim2.fromOffset(32, 28), Position = UDim2.new(1, -36, 0, 4), BackgroundColor3 = DG, Text = "✕", TextColor3 = TX,
  Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true,
}, bar)
corner(btnClose, 8)

local body = mk("Frame", { Size = UDim2.new(1, 0, 1, -36), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1 }, main)
local nick = mk("TextBox", {
  Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = BG2, TextColor3 = TX,
  PlaceholderColor3 = DIM, PlaceholderText = "Ник игрока, например bapcuk", Text = "", Font = Enum.Font.Gotham,
  TextSize = 13, ClearTextOnFocus = false,
}, body)
corner(nick, 8)
local function button(text, col, x, y, w, h)
  local b = mk("TextButton", {
    Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y), BackgroundColor3 = col, Text = text, TextColor3 = TX,
    Font = Enum.Font.GothamBold, TextSize = 12, TextWrapped = true, AutoButtonColor = true,
  }, body)
  corner(b, 8)
  return b
end
local bCopy = button("📋 Скопировать", Color3.fromRGB(40, 150, 90), 10, 58, 135, 38)
local bBack = button("↩ Вернуть моё", ST, 155, 58, 135, 38)
local status = mk("TextLabel", {
  Size = UDim2.new(1, -20, 0, 80), Position = UDim2.fromOffset(10, 106), BackgroundColor3 = BG2, TextColor3 = DIM,
  Text = "Введи ник игрока и нажми «Скопировать». Копируются лицо, волосы, форма тела, одежда, аксессуары и анимации.",
  Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true,
  TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, body)
corner(status, 8)
mk("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingRight = UDim.new(0, 8) }, status)
local bScale = button("Размер тела: вкл", Color3.fromRGB(40, 150, 90), 10, 194, 280, 30)
local bAnim = button("Анимации: вкл", Color3.fromRGB(40, 150, 90), 10, 230, 280, 30)
local bVis = button("Визуальный R6: выкл", BG2, 10, 266, 280, 30)

setStatus = function(text, isErr)
  status.Text = text
  status.TextColor3 = isErr and DG or AC
  print("[Copier] " .. text)
end

local conns = {}
local function track(c) conns[#conns + 1] = c end
track(bCopy.Activated:Connect(function() doCopy(nick.Text) end))
track(bBack.Activated:Connect(doRestore))
track(bVis.Activated:Connect(function()
  S.visualR6 = not S.visualR6
  bVis.Text = "Визуальный R6: " .. (S.visualR6 and "вкл" or "выкл")
  bVis.BackgroundColor3 = S.visualR6 and Color3.fromRGB(40, 150, 90) or BG2
  setStatus(S.visualR6 and "Визуальный R6 включён: применится к следующему копированию R6-скина" or "Визуальный R6 выключен", false)
end))
track(bAnim.Activated:Connect(function()
  S.optAnim = not S.optAnim
  bAnim.Text = "Анимации: " .. (S.optAnim and "вкл" or "выкл")
  bAnim.BackgroundColor3 = S.optAnim and Color3.fromRGB(40, 150, 90) or BG2
end))
track(bScale.Activated:Connect(function()
  S.optScale = not S.optScale
  bScale.Text = "Размер тела: " .. (S.optScale and "вкл" or "выкл")
  bScale.BackgroundColor3 = S.optScale and Color3.fromRGB(40, 150, 90) or BG2
end))
-- после респавна копия пропадает вместе с персонажем: надеваем снова
track(LP.CharacterAdded:Connect(function()
  local id = S.lastId
  S.acc, S.undo, S.stash, S.scales, S.char, S.applied, S.snap = {}, {}, {}, {}, nil, false, nil
  task.delay(.5, fixCamera)
  if id then
    task.delay(1.5, function()
      if S.lastId == id and not S.busy then doCopy(tostring(id)) end
    end)
  end
end))

local minimized = false
track(btnMin.Activated:Connect(function()
  minimized = not minimized
  body.Visible = not minimized
  main.Size = minimized and UDim2.fromOffset(300, 36) or UDim2.fromOffset(300, 336)
end))
local function destroy()
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  pcall(restoreAll)
  pcall(function() gui:Destroy() end)
  ENV.RM_AvatarCopier = nil
end
track(btnClose.Activated:Connect(destroy))
-- restoreSync вызывает тулкит, когда ты выбираешь его скин: копия снимается, чтобы они не наложились
ENV.RM_AvatarCopier = {
  destroy = destroy,
  restore = doRestore,
  restoreSync = function()
    pcall(restoreAll)
    fixCamera()
  end,
}

-- перетаскивание окна за заголовок (мышь и палец)
do
  local dragging, startPos, startInput
  track(bar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
      dragging, startPos, startInput = true, main.Position, i.Position
      i.Changed:Connect(function()
        if i.UserInputState == Enum.UserInputState.End then dragging = false end
      end)
    end
  end))
  track(UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
      local d = i.Position - startInput
      main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
  end))
end

print("[Copier] Avatar Copier v1.6 загружен (по нику или ID)")
