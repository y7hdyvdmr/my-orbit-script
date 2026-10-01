--[[ ОРБИТА v22.7 — SFX (автономный)
     Загружается из orbit_p1.lua
     Подменяет ORBIT.playClick / playDodge / playBotCollect / playWin / playBuy
     Использует rbxasset:// звуки — всегда доступны в Roblox
]]

local ORBIT = rawget(shared, "ORBIT") or rawget(_G, "ORBIT") or (rawget(_G, "getgenv") and getgenv().ORBIT)
if not ORBIT then warn("[Orbit SFX] ORBIT не найден!"); return end

local SoundService    = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris          = game:GetService("Debris")

local Sfx = {}

-- Встроенные звуки клиента Roblox (всегда работают)
local IDS = {
    click   = "rbxasset://sounds/button.wav",
    switch  = "rbxasset://sounds/switch.wav",
    ping    = "rbxasset://sounds/electronicpingshort.wav",
    snap    = "rbxasset://sounds/snap.mp3",
}

-- Контейнер
local folder = Instance.new("Folder")
folder.Name = "OrbitSfx_" .. tostring(math.random(100000, 999999))
folder.Parent = SoundService
ORBIT.sfxFolder = folder

-- Шаблоны
local templates = {}
for name, id in pairs(IDS) do
    local s = Instance.new("Sound")
    s.Name = name
    s.SoundId = id
    s.Volume = 0.5
    s.Parent = folder
    templates[name] = s
end

-- Предзагрузка (чтобы не было задержки при первом воспроизведении)
task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync(folder:GetChildren()) end)
end)

-- Антиспам (не чаще 1 раза в 40 мс на звук)
local lastPlay = {}

-- Настройки из ORBIT.SOUNDS
local function settings()
    local s = ORBIT.SOUNDS
    local enabled = true
    local volume = 1
    if type(s) == "table" then
        if s.Enabled == false then enabled = false end
        volume = tonumber(s.Volume) or 1
    end
    return enabled, volume
end

function Sfx.play(name, vol, pitch)
    local tpl = templates[name]
    if not tpl then return end

    local enabled, master = settings()
    if not enabled or master <= 0 then return end

    local now = os.clock()
    if lastPlay[name] and now - lastPlay[name] < 0.04 then return end
    lastPlay[name] = now

    local s = tpl:Clone()
    s.Volume = tpl.Volume * (vol or 1) * master
    s.PlaybackSpeed = pitch or 1
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 3)
end

-- ============================================================
--       ПОДМЕНА ФУНКЦИЙ В ORBIT
-- ============================================================
-- Сохраняем оригиналы (на случай отката)
ORBIT._origPlayClick      = ORBIT.playClick
ORBIT._origPlayDodge      = ORBIT.playDodge
ORBIT._origPlayBotCollect = ORBIT.playBotCollect

-- Новые функции
ORBIT.playClick      = function() Sfx.play("click", 1, 1) end
ORBIT.playDodge      = function() Sfx.play("snap", 1, 1.4) end
ORBIT.playBotCollect = function() Sfx.play("ping", 1, 1.2) end
ORBIT.playWin        = function() Sfx.play("ping", 1, 1.6) end
ORBIT.playBuy        = function() Sfx.play("switch", 1, 1.3) end
ORBIT.playSwitch     = function() Sfx.play("switch", 1, 1) end

ORBIT.Sfx = Sfx

print("[Orbit SFX] Подключен ✅")

return true
