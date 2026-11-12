--// Maneware Hub v3 | RightShift или Insert - открыть/закрыть меню
--// ЛКМ по функции - вкл/выкл | ПКМ - настройки | СКМ (колёсико) - назначить бинд

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- выгрузка предыдущей версии (чтобы старые циклы не мешали)
if env.ManewareUnload then pcall(env.ManewareUnload) end
if env.StarfexUnload then pcall(env.StarfexUnload) end -- старое название клиента

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("ManewareHub") then parentGui.ManewareHub:Destroy() end
if parentGui:FindFirstChild("StarfexHub") then parentGui.StarfexHub:Destroy() end

local conns = {}
local errSeen = {}
local reportErr = function() end
-- обёртка: ошибка в одной функции не ломает остальные и показывается в статусе/консоли
local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            local id = tostring(fn)
            if not errSeen[id] then
                errSeen[id] = true
                warn("[Maneware] ошибка: " .. tostring(err))
                reportErr(tostring(err))
            end
        end
    end
end
local function bind(signal, fn)
    local c = signal:Connect(safe(fn))
    conns[#conns + 1] = c
    return c
end
local function getCam() return workspace.CurrentCamera end

----------------------------------------------------------------
-- Тема (в стиле Neverlose)
----------------------------------------------------------------
local ACCENT = Color3.fromRGB(0, 170, 255)
local C = {
    bg = Color3.fromRGB(11, 15, 26),
    side = Color3.fromRGB(8, 11, 20),
    card = Color3.fromRGB(17, 23, 38),
    off = Color3.fromRGB(44, 54, 78),
    text = Color3.fromRGB(232, 238, 250),
    dim = Color3.fromRGB(117, 131, 163),
    line = Color3.fromRGB(30, 40, 62),
}

local BLOCK = 4          -- 1 "блок" = 4 стада
local TRIG_RANGE = 20    -- дистанция triggerbot (стады)

----------------------------------------------------------------
-- Состояние
----------------------------------------------------------------
local state = {
    airstuck = { on = false, bind = nil },
    esp3d    = { on = false, bind = nil },
    esphp    = { on = false, bind = nil },
    espname  = { on = false, bind = nil },
    speed    = { on = false, bind = nil },
    trigger  = { on = false, bind = nil },
    aim      = { on = false, bind = nil },
    hitsound = { on = false, bind = nil },
    criticals = { on = false, bind = nil },
    aura     = { on = false, bind = nil },
    surround = { on = false, bind = nil },
    keybind  = { on = false, bind = nil },
    targetesp = { on = false, bind = nil },
    targetstrafe = { on = false, bind = nil },
    bunnyhop = { on = false, bind = nil },
    strafe   = { on = false, bind = nil },
    spider   = { on = false, bind = nil },
    targethud = { on = false, bind = nil },
    watermark = { on = false, bind = nil },
    notify   = { on = false, bind = nil },
    notifysound = { on = false, bind = nil },
    device   = { on = false, bind = nil },
}
local cfg = {
    speed = 16,
    speedMode = "CFrame",
    crits = false,
    useCooldown = true,
    cooldown = 1,
    smooth = 1,
    range = 3,
    focus = false,
    hitVolume = 3,
    critJump = 1,        -- Criticals: множитель силы прыжка
    auraCooldown = 1.6,  -- AttackAura: скорость атаки (как в Minecraft, ударов/сек)
    auraBlock = false,   -- бить через блоки
    auraRange = 3,       -- дальность в блоках
    auraFree = false,    -- свободное движение/камера
    auraTarget = false,  -- бежать к цели и кружить
    auraCrits = false,   -- бить только в прыжке
    kbOnlyOn = false,    -- Keybinds: только включённые
    tgMarker = true,     -- TargetESP: куб с острыми углами
    tgMarker2 = false,   -- TargetESP: куб со скруглёнными углами
    tgOnlyAura = false,  -- TargetESP: только при включённой AttackAura
    strafeSpeed = 10,    -- TargetStrafe: скорость
    strafeRange = 4,     -- TargetStrafe: радиус (стады)
    bhBoost = 1,         -- Bunnyhop: прибавка скорости за прыжок
    airStrength = 4,     -- Strafe: сила воздушного разгона
    spiderSpeed = 16,    -- Spider: скорость подъёма (стады/сек)
    hitSoundName = "skeet", -- HitSound: skeet / uwu
    notifySound = "uwu",    -- NotifySound: uwu / celestial
    surroundRange = 6,   -- Surround: дальность поиска цели (блоки)
    surroundDelay = 0.12, -- Surround: пауза между блоками (сек)
}
local ui = {}

local HITSOUND_ID = "rbxassetid://5633695679" -- skeet (ID из комьюнити-скрипта, можно заменить)
local lastAttack = 0
local IS_TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled
local pins = {}
local notify = function() end

----------------------------------------------------------------
-- Звуки: skeet (rbxassetid), uwu (mp3 с GitHub), celestial (свой URL)
----------------------------------------------------------------
local SoundService = game:GetService("SoundService")
-- celestial / celestial_off: звуки включения и выключения из твоего видео (mp3 внутри скрипта, base64)
local CEL_ON = "SUQzBAAAAAABClRYWFgAAAASAAADbWFqb3JfYnJhbmQAaXNvbQBUWFhYAAAAEwAAA21pbm9yX3ZlcnNpb24ANTEyAFRYWFgAAAAkAAADY29tcGF0aWJsZV9icmFuZHMAaXNvbWlzbzJhdmMxbXA0MQBUU1NFAAAADwAAA0xhdmY2MC4xNi4xMDAAAAAAAAAAAAAAAP/7cMAAAAAAAAAAAAAAAAAAAAAAAEluZm8AAAAPAAAAHAAAI4IAERERGhoaGiMjIywsLCw0NDQ9PT09RkZGT09PT1hYWFhhYWFpaWlpcnJye3t7e4SEhI2NjY2WlpaWnp6ep6enp7CwsLm5ubnCwsLLy8vL09PT09zc3OXl5eXu7u739/f3////AAAAAExhdmM2MC4zMQAAAAAAAAAAAAAAACQDKgAAAAAAACOCKu0HmgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/+3DEAAPAAAGkAAAAIAAANIAAAARMQU1FMy4xMDBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVUxBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV//tyxG0DwAABpAAAACAAADSAAAAEVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVUAAL/gtKQylUK2NAEWhv8HABgQAimpeFIh2CRan/mA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qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//twxG2DwAABpAAAACAAADSAAAAEqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpMQU1FMy4xMDCqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqv/7csRtA8AAAaQAAAAgAAA0gAAABKqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqTEFNRTMuMTAwqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//twxG2DwAABpAAAACAAADSAAAAEqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqg=="
local CEL_OFF = "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qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq//twxG2DwAABpAAAACAAADSAAAAEqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqg=="
local SOUND_SRC = {
    skeet = { id = "rbxassetid://5633695679" },
    uwu = { url = "https://github.com/CongoOhioDog/SoundS/blob/main/Uwu.mp3?raw=true", ext = "mp3" },
    celestial = { b64 = CEL_ON, ext = "mp3", id = "rbxasset://sounds/electronicpingshort.wav" },
    celestial_off = { b64 = CEL_OFF, ext = "mp3", id = "rbxasset://sounds/electronicpingshort.wav" },
}

local B64CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64MAP = {}
for i = 1, #B64CHARS do B64MAP[B64CHARS:byte(i)] = i - 1 end
local function b64decode(str)
    local out, buf, bits = {}, 0, 0
    for i = 1, #str do
        local v = B64MAP[str:byte(i)]
        if v then
            buf = buf * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(buf / 2 ^ bits)
                buf = buf - byte * 2 ^ bits
                out[#out + 1] = string.char(byte)
            end
        end
    end
    return table.concat(out)
end
local resolvedSounds = {}
local function resolveSound(name)
    if resolvedSounds[name] then return resolvedSounds[name] end
    local src = SOUND_SRC[name]
    if not src then return nil end
    local id = src.id
    if src.b64 and writefile and getcustomasset then
        local file = "maneware_" .. name .. "." .. (src.ext or "mp3")
        pcall(function()
            if not (isfile and isfile(file)) then writefile(file, b64decode(src.b64)) end
            id = getcustomasset(file)
        end)
    elseif src.url and src.url ~= "" and writefile and getcustomasset then
        local file = "maneware_" .. name .. "." .. (src.ext or "mp3")
        pcall(function()
            if not (isfile and isfile(file)) then writefile(file, game:HttpGet(src.url)) end
            id = getcustomasset(file)
        end)
    end
    resolvedSounds[name] = id
    return id
end
local function playNamed(name, vol)
    local id = resolveSound(name) or SOUND_SRC.skeet.id
    local snd = Instance.new("Sound")
    snd.SoundId = id
    snd.Volume = vol or 1
    snd.Parent = SoundService
    snd:Play()
    task.delay(6, function() pcall(function() snd:Destroy() end) end)
end
task.spawn(function()
    for name in pairs(SOUND_SRC) do pcall(resolveSound, name) end -- предзагрузка
end)

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = lp.Character
    if not c then return nil end
    local h = getHum()
    return (h and h.RootPart) or c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
end

----------------------------------------------------------------
-- Airstuck: якорим корень + закрепляем позицию + блокируем ходьбу/прыжок
----------------------------------------------------------------
local stuck = nil

local function applyAirstuck(on)
    if on then
        local root, hum = getRoot(), getHum()
        if not root then
            notify("Airstuck: корневая часть не найдена")
            return false
        end
        stuck = {
            root = root, cf = root.CFrame,
            vel = root.AssemblyLinearVelocity, ang = root.AssemblyAngularVelocity,
            ws = hum and hum.WalkSpeed, jp = hum and hum.JumpPower, jh = hum and hum.JumpHeight,
        }
        pcall(function() root.Anchored = true end)
        if hum then
            pcall(function() hum.WalkSpeed = 0 end)
            pcall(function() hum.JumpPower = 0 end)
            pcall(function() hum.JumpHeight = 0 end)
        end
        notify("Airstuck ON  [" .. root.Name .. "]")
        return true
    else
        if stuck then
            local root, hum = stuck.root, getHum()
            if root and root.Parent then
                pcall(function() root.Anchored = false end)
                root.AssemblyLinearVelocity = stuck.vel or Vector3.zero
                root.AssemblyAngularVelocity = stuck.ang or Vector3.zero
            end
            if hum then
                pcall(function() if stuck.ws then hum.WalkSpeed = stuck.ws end end)
                pcall(function() if stuck.jp then hum.JumpPower = stuck.jp end end)
                pcall(function() if stuck.jh then hum.JumpHeight = stuck.jh end end)
            end
        end
        stuck = nil
        notify("Airstuck OFF")
        return true
    end
end

local function pin()
    if state.airstuck.on and stuck and stuck.root and stuck.root.Parent then
        local r = stuck.root
        r.CFrame = stuck.cf
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end
end
bind(RunService.Stepped, pin)
bind(RunService.Heartbeat, pin)
if RunService.PreSimulation then bind(RunService.PreSimulation, pin) end
if RunService.PostSimulation then bind(RunService.PostSimulation, pin) end
RunService:BindToRenderStep("ManewarePin", Enum.RenderPriority.Last.Value, safe(pin))

----------------------------------------------------------------
-- Переключение
----------------------------------------------------------------
local hooks = {}
local onToggle = nil
local function setFeature(key, value)
    local s = state[key]
    if value == nil then value = not s.on end
    if key == "airstuck" then
        if not applyAirstuck(value) then value = false end
    end
    s.on = value
    if ui[key] then ui[key].set(value) end
    if pins[key] then pins[key].refresh() end
    if hooks[key] then hooks[key](value) end
    if onToggle then onToggle(key, value) end
end

bind(lp.CharacterAdded, function()
    stuck = nil
    if state.airstuck.on then setFeature("airstuck", false) end
end)

----------------------------------------------------------------
-- Speed: режимы CFrame / Velocity / WalkSpeed
----------------------------------------------------------------
local function moveDir()
    local cf = getCam().CFrame
    local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
    local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
    if look.Magnitude < 1e-3 or right.Magnitude < 1e-3 then return Vector3.zero end
    look, right = look.Unit, right.Unit
    local d = Vector3.zero
    if not UIS:GetFocusedTextBox() then
        if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + look end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - look end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + right end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - right end
    end
    if d.Magnitude == 0 then
        local h = getHum()
        if h then d = Vector3.new(h.MoveDirection.X, 0, h.MoveDirection.Z) end
    end
    return d.Magnitude > 0 and d.Unit or Vector3.zero
end

local speedWasOn = false
bind(RunService.Heartbeat, function(dt)
    local hum, root = getHum(), getRoot()
    if not (hum and root) then return end
    if state.speed.on and not state.airstuck.on then
        speedWasOn = true
        local d = moveDir()
        if cfg.speedMode == "WalkSpeed" then
            hum.WalkSpeed = cfg.speed
        elseif cfg.speedMode == "Velocity" then
            hum.WalkSpeed = cfg.speed
            if d.Magnitude > 0 then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(d.X * cfg.speed, v.Y, d.Z * cfg.speed)
            end
        else -- CFrame
            local extra = cfg.speed - 16
            if d.Magnitude > 0 and extra > 0 then
                root.CFrame = root.CFrame + d * extra * dt
            end
        end
    elseif speedWasOn and not state.speed.on then
        speedWasOn = false
        if cfg.speedMode ~= "CFrame" then hum.WalkSpeed = 16 end
    end
end)

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = o
    return c
end
local function tw(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function label(parent, text, size, font, color, x, y, w, h, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size
    l.Font = font
    l.TextColor3 = color
    l.Position = UDim2.fromOffset(x, y)
    l.Size = UDim2.fromOffset(w, h)
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "ManewareHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
gui.Parent = parentGui

local main = Instance.new("Frame")
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.Size = UDim2.fromOffset(620, 410)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 10)
local mstroke = Instance.new("UIStroke", main)
mstroke.Color = C.line
mstroke.Thickness = 1
local scale = Instance.new("UIScale", main)
local _vp = getCam().ViewportSize
local baseScale = math.clamp(math.min(_vp.X / 660, _vp.Y / 440), 0.5, 1)
scale.Scale = baseScale

-- Sidebar
local side = Instance.new("Frame")
side.Size = UDim2.new(0, 150, 1, 0)
side.BackgroundColor3 = C.side
side.BorderSizePixel = 0
side.Parent = main
corner(side, 10)
local sideFill = Instance.new("Frame")
sideFill.AnchorPoint = Vector2.new(1, 0)
sideFill.Position = UDim2.new(1, 0, 0, 0)
sideFill.Size = UDim2.new(0, 12, 1, 0)
sideFill.BackgroundColor3 = C.side
sideFill.BorderSizePixel = 0
sideFill.Parent = side

label(side, "MANEWARE", 20, Enum.Font.GothamBlack, ACCENT, 18, 16, 120, 24)
local sline = Instance.new("Frame")
sline.Position = UDim2.fromOffset(14, 64)
sline.Size = UDim2.new(1, -28, 0, 1)
sline.BackgroundColor3 = C.line
sline.BorderSizePixel = 0
sline.Parent = side

local tabHolder = Instance.new("Frame")
tabHolder.BackgroundTransparency = 1
tabHolder.Position = UDim2.fromOffset(10, 76)
tabHolder.Size = UDim2.new(1, -20, 1, -90)
tabHolder.Parent = side
local tabLayout = Instance.new("UIListLayout", tabHolder)
tabLayout.Padding = UDim.new(0, 4)

-- Контент
local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(150, 0)
content.Size = UDim2.new(1, -150, 1, 0)
content.Parent = main

local tabTitle = label(content, "", 17, Enum.Font.GothamBold, C.text, 20, 12, 300, 24)
label(content, "RightShift - скрыть", 11, Enum.Font.Gotham, C.dim, 0, 16, 150, 14, Enum.TextXAlignment.Right).Position = UDim2.new(1, -164, 0, 16)

local statusLabel = label(content, "Готово", 12, Enum.Font.Gotham, C.dim, 20, 0, 400, 20)
statusLabel.Position = UDim2.new(0, 20, 1, -26)
notify = function(t) statusLabel.Text = t end
reportErr = function(m) notify("Ошибка: " .. string.sub(m, 1, 90)) end

-- Перетаскивание
do
    local dragging, dragStart, startPos
    local function handle(h)
        h.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, i.Position, main.Position
            end
        end)
    end
    local dragBar = Instance.new("Frame")
    dragBar.BackgroundTransparency = 1
    dragBar.Size = UDim2.new(1, 0, 0, 44)
    dragBar.Parent = content
    handle(dragBar)
    local dragSide = Instance.new("Frame")
    dragSide.BackgroundTransparency = 1
    dragSide.Size = UDim2.new(1, 0, 0, 64)
    dragSide.Parent = side
    handle(dragSide)
    bind(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Вкладки
local pages, tabButtons = {}, {}
local function showTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabButtons) do
        local act = (n == name)
        tw(b.btn, 0.15, { BackgroundTransparency = act and 0 or 1 })
        b.txt.TextColor3 = act and C.text or C.dim
        b.bar.Visible = act
    end
    tabTitle.Text = name
end

local function makeTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = C.card
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.Parent = tabHolder
    corner(btn, 7)
    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(0, 8)
    bar.Size = UDim2.fromOffset(3, 18)
    bar.BackgroundColor3 = ACCENT
    bar.BorderSizePixel = 0
    bar.Visible = false
    bar.Parent = btn
    corner(bar, 2)
    local txt = label(btn, name, 14, Enum.Font.GothamMedium, C.dim, 16, 0, 110, 34)
    tabButtons[name] = { btn = btn, txt = txt, bar = bar }

    local page = Instance.new("ScrollingFrame")
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Position = UDim2.fromOffset(16, 50)
    page.Size = UDim2.new(1, -32, 1, -84)
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = ACCENT
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = content
    local l = Instance.new("UIListLayout", page)
    l.Padding = UDim.new(0, 8)
    pages[name] = page

    btn.MouseButton1Click:Connect(function() showTab(name) end)
    return page
end

-- Элементы
local listeningKey
local function bindText(k)
    return state[k].bind and ("[" .. state[k].bind.Name .. "]") or "[—]"
end

-- Экранные кнопки для телефона (перетаскиваются, тап = вкл/выкл)
local PIN_NAMES = {
    airstuck = "AS", esp3d = "3D", esphp = "HP", espname = "NM",
    speed = "SPD", trigger = "TRG", aim = "AIM", hitsound = "HIT",
    criticals = "CRT", aura = "AUR", surround = "SUR",
    keybind = "KEY", targetesp = "TES", targetstrafe = "STR",
    bunnyhop = "BHP", strafe = "AST", spider = "SPI",
    targethud = "THD", watermark = "WM", notify = "NTF", notifysound = "NSD", device = "DEV",
}

local function makeDragButton(text, onTap)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(46, 46)
    b.BackgroundColor3 = C.card
    b.AutoButtonColor = false
    b.Text = text
    b.TextColor3 = C.text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.ZIndex = 5
    b.Parent = gui
    corner(b, 23)
    local st = Instance.new("UIStroke", b)
    st.Color = ACCENT
    st.Thickness = 1.5

    local active, moved, startPos, startIn
    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            active, moved, startIn, startPos = i, false, i.Position, b.Position
        end
    end)
    bind(UIS.InputChanged, function(i)
        if not active then return end
        local okTouch = active.UserInputType == Enum.UserInputType.Touch and i == active
        local okMouse = active.UserInputType == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseMovement
        if okTouch or okMouse then
            local d = i.Position - startIn
            if d.Magnitude > 8 then moved = true end
            if moved then
                b.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
    bind(UIS.InputEnded, function(i)
        if not active then return end
        local okTouch = active.UserInputType == Enum.UserInputType.Touch and i == active
        local okMouse = active.UserInputType == Enum.UserInputType.MouseButton1 and i.UserInputType == Enum.UserInputType.MouseButton1
        if okTouch or okMouse then
            active = nil
            if not moved then onTap() end
        end
    end)
    return b
end

local function togglePin(key)
    if pins[key] then
        pins[key].btn:Destroy()
        pins[key] = nil
        ui[key].bindLabel.Text = bindText(key)
        if ui[key].pinBtn then ui[key].pinBtn.BackgroundColor3 = C.off end
        notify("Кнопка убрана: " .. key)
        return
    end
    local n = 0
    for _ in pairs(pins) do n = n + 1 end
    local btn = makeDragButton(PIN_NAMES[key] or key, function() setFeature(key) end)
    -- колонки по 6 кнопок, чтобы не уезжали за экран
    btn.Position = UDim2.new(1, -62 - math.floor(n / 6) * 54, 0, 70 + (n % 6) * 54)
    local function refresh()
        local on = state[key].on
        btn.BackgroundColor3 = on and ACCENT or C.card
        btn.TextColor3 = on and Color3.new(1, 1, 1) or C.text
    end
    refresh()
    pins[key] = { btn = btn, refresh = refresh }
    ui[key].bindLabel.Text = "[BTN]"
    if ui[key].pinBtn then ui[key].pinBtn.BackgroundColor3 = ACCENT end
    notify("Кнопка добавлена: " .. key .. " (кнопка BTN или долгое нажатие - убрать)")
end

local function makeSwitch(parent)
    local sw = Instance.new("Frame")
    sw.AnchorPoint = Vector2.new(1, 0.5)
    sw.Size = UDim2.fromOffset(38, 20)
    sw.BackgroundColor3 = C.off
    sw.Parent = parent
    corner(sw, 10)
    local k = Instance.new("Frame")
    k.AnchorPoint = Vector2.new(0, 0.5)
    k.Position = UDim2.new(0, 3, 0.5, 0)
    k.Size = UDim2.fromOffset(14, 14)
    k.BackgroundColor3 = Color3.new(1, 1, 1)
    k.Parent = sw
    corner(k, 7)
    local function set(on)
        tw(sw, 0.15, { BackgroundColor3 = on and ACCENT or C.off })
        tw(k, 0.15, { Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
    end
    return sw, set
end

local function makeFeature(page, key, title, desc, build)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = C.card
    card.BorderSizePixel = 0
    card.Parent = page
    corner(card, 8)
    local st = Instance.new("UIStroke", card)
    st.Color = C.line
    st.Thickness = 1
    local cl = Instance.new("UIListLayout", card)
    cl.SortOrder = Enum.SortOrder.LayoutOrder

    local header = Instance.new("TextButton")
    header.LayoutOrder = 0
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundTransparency = 1
    header.AutoButtonColor = false
    header.Text = ""
    header.Parent = card

    label(header, title, 14, Enum.Font.GothamMedium, C.text, 14, 8, 220, 18)
    label(header, desc .. (build and "  •  SET - настройки" or ""), 11, Enum.Font.Gotham, C.dim, 14, 27, 300, 14)

    local bindLabel = label(header, "[—]", 12, Enum.Font.Gotham, C.dim, 0, 0, 80, 16, Enum.TextXAlignment.Right)
    bindLabel.AnchorPoint = Vector2.new(1, 0.5)
    bindLabel.Position = UDim2.new(1, (build and -108 or -62) - (IS_TOUCH and 46 or 0), 0.5, 0)

    local sw, setVisual = makeSwitch(header)
    sw.Position = UDim2.new(1, -14, 0.5, 0)

    local pinBtn
    do
        pinBtn = Instance.new("TextButton")
        pinBtn.AnchorPoint = Vector2.new(1, 0.5)
        pinBtn.Position = UDim2.new(1, build and -108 or -62, 0.5, 0)
        pinBtn.Size = UDim2.fromOffset(40, 24)
        pinBtn.BackgroundColor3 = C.off
        pinBtn.Text = "BTN"
        pinBtn.TextColor3 = C.text
        pinBtn.Font = Enum.Font.GothamBold
        pinBtn.TextSize = 11
        pinBtn.Visible = IS_TOUCH
        pinBtn.AutoButtonColor = true
        pinBtn.Parent = header
        corner(pinBtn, 6)
        pinBtn.MouseButton1Click:Connect(function() togglePin(key) end)
    end
    ui[key] = { set = setVisual, bindLabel = bindLabel, pinBtn = pinBtn, baseOff = build and -108 or -62 }

    local settings
    if build then
        settings = Instance.new("Frame")
        settings.LayoutOrder = 1
        settings.Size = UDim2.new(1, 0, 0, 0)
        settings.AutomaticSize = Enum.AutomaticSize.Y
        settings.BackgroundTransparency = 1
        settings.Visible = false
        settings.Parent = card
        local p = Instance.new("UIPadding", settings)
        p.PaddingLeft, p.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
        p.PaddingBottom, p.PaddingTop = UDim.new(0, 10), UDim.new(0, 2)
        local sl = Instance.new("UIListLayout", settings)
        sl.Padding = UDim.new(0, 8)
        build(settings)
    end

    if settings then
        local gear = Instance.new("TextButton")
        gear.AnchorPoint = Vector2.new(1, 0.5)
        gear.Position = UDim2.new(1, -62, 0.5, 0)
        gear.Size = UDim2.fromOffset(40, 24)
        gear.BackgroundColor3 = C.off
        gear.Text = "SET"
        gear.TextColor3 = C.text
        gear.Font = Enum.Font.GothamBold
        gear.TextSize = 11
        gear.AutoButtonColor = true
        gear.Parent = header
        corner(gear, 6)
        gear.MouseButton1Click:Connect(function() settings.Visible = not settings.Visible end)
    end

    -- долгое нажатие (телефон) = экранная кнопка-бинд
    local longFlag, holdToken = false, 0
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            longFlag = false
            holdToken = holdToken + 1
            local my = holdToken
            task.delay(0.5, function()
                if holdToken == my then
                    longFlag = true
                    togglePin(key)
                end
            end)
        end
    end)
    header.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then holdToken = holdToken + 1 end
    end)

    header.MouseButton1Click:Connect(function()
        if longFlag then
            longFlag = false
            return
        end
        setFeature(key)
    end)
    header.MouseButton2Click:Connect(function()
        if settings then settings.Visible = not settings.Visible end
    end)
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton3 then
            listeningKey = key
            bindLabel.Text = "[...]"
            bindLabel.TextColor3 = ACCENT
        end
    end)
end

local function makeSlider(parent, text, minV, maxV, decimals, default, onChange, withDefault)
    local fmt = "%." .. decimals .. "f"
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lab = label(f, "", 13, Enum.Font.Gotham, C.text, 0, 0, 220, 18)
    local track = Instance.new("Frame")
    track.Position = UDim2.fromOffset(0, 26)
    track.Size = UDim2.new(1, 0, 0, 6)
    track.BackgroundColor3 = C.off
    track.Parent = f
    corner(track, 3)
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = ACCENT
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, 3)
    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Parent = track
    corner(knob, 7)

    local function set(v)
        local m = 10 ^ decimals
        v = math.clamp(math.floor(v * m + 0.5) / m, minV, maxV)
        local a = (v - minV) / (maxV - minV)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        lab.Text = text .. ": " .. string.format(fmt, v)
        onChange(v)
    end
    set(default)

    if withDefault then
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(1, 0)
        b.Position = UDim2.new(1, 0, 0, 0)
        b.Size = UDim2.fromOffset(64, 20)
        b.BackgroundColor3 = ACCENT
        b.Text = "Default"
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.AutoButtonColor = true
        b.Parent = f
        corner(b, 5)
        b.MouseButton1Click:Connect(function() set(default) end)
    end

    local sliding = false
    local function update(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        set(minV + a * (maxV - minV))
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            update(i.Position.X)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
end

local function makeToggle(parent, text, default, onChange)
    local f = Instance.new("TextButton")
    f.Size = UDim2.new(1, 0, 0, 24)
    f.BackgroundTransparency = 1
    f.AutoButtonColor = false
    f.Text = ""
    f.Parent = parent
    label(f, text, 13, Enum.Font.Gotham, C.text, 0, 0, 260, 24)
    local sw, setV = makeSwitch(f)
    sw.Position = UDim2.new(1, 0, 0.5, 0)
    local v = default
    setV(v)
    onChange(v)
    f.MouseButton1Click:Connect(function()
        v = not v
        setV(v)
        onChange(v)
    end)
end

local function makeCycle(parent, text, options, default, onChange)
    local f = Instance.new("TextButton")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundColor3 = C.off
    f.AutoButtonColor = true
    f.TextColor3 = C.text
    f.Font = Enum.Font.GothamMedium
    f.TextSize = 13
    f.Parent = parent
    corner(f, 6)
    local idx = table.find(options, default) or 1
    local function refresh() f.Text = text .. ": " .. options[idx] end
    refresh()
    onChange(options[idx])
    f.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        refresh()
        onChange(options[idx])
    end)
end

-- Вкладки и функции
-- Режим устройства: компьютер / телефон (влияет на клики, прицел, кнопки BTN и MENU)
local AUTO_TOUCH = IS_TOUCH
local menuBtn
local function applyDevice(phone)
    IS_TOUCH = phone
    for _, u in pairs(ui) do
        if u.pinBtn then u.pinBtn.Visible = phone end
        if u.bindLabel and u.baseOff then
            u.bindLabel.Position = UDim2.new(1, u.baseOff - (phone and 46 or 0), 0.5, 0)
        end
    end
    if menuBtn then menuBtn.Visible = phone end
    notify("Режим: " .. (phone and "телефон" or "компьютер"))
end

local pageCombat = makeTab("Combat")
local pageVisuals = makeTab("Visuals")
local pageMove = makeTab("Movement")
local pageMisc = makeTab("Misc")

makeFeature(pageCombat, "trigger", "TriggerBot", "Бьёт, когда игрок под прицелом", function(s)
    makeToggle(s, "Crits (только в прыжке)", false, function(v) cfg.crits = v end)
    makeToggle(s, "Cooldown", true, function(v) cfg.useCooldown = v end)
    makeSlider(s, "Cooldown (сек)", 0.5, 3, 1, 1, function(v) cfg.cooldown = v end)
end)
makeFeature(pageCombat, "aim", "AimAssist", "Наведение на ближайшего игрока", function(s)
    makeToggle(s, "Focus (держать одну цель)", false, function(v) cfg.focus = v end)
    makeSlider(s, "Smooth", 0.1, 5, 1, 1, function(v) cfg.smooth = v end)
    makeSlider(s, "Range (блоки)", 1, 6, 1, 3, function(v) cfg.range = v end)
end)
makeFeature(pageCombat, "criticals", "Criticals", "Криты и сила прыжка", function(s)
    makeSlider(s, "Jump", 0.1, 2, 1, 1, function(v) cfg.critJump = v end, true)
end)
makeFeature(pageCombat, "aura", "AttackAura", "Авто-атака ближайшего игрока", function(s)
    makeSlider(s, "Cooldown (MC)", 0.1, 5, 1, 1.6, function(v) cfg.auraCooldown = v end)
    makeToggle(s, "Attack Block (бить через блоки)", false, function(v) cfg.auraBlock = v end)
    makeSlider(s, "Range (блоки)", 1, 6, 1, 3, function(v) cfg.auraRange = v end)
    makeToggle(s, "Free (двигаться свободно)", false, function(v) cfg.auraFree = v end)
    makeToggle(s, "Target (бежать к цели, кружить)", true, function(v) cfg.auraTarget = v end)
    makeToggle(s, "Crits (только в прыжке)", false, function(v) cfg.auraCrits = v end)
end)
makeFeature(pageCombat, "targetstrafe", "TargetStrafe", "Кружит возле цели (только с AttackAura)", function(s)
    makeSlider(s, "Speed", 1, 40, 0, 10, function(v) cfg.strafeSpeed = v end)
    makeSlider(s, "Range (стады)", 1, 10, 1, 4, function(v) cfg.strafeRange = v end)
end)

makeFeature(pageVisuals, "esp3d", "ESP 3D", "3D бокс вокруг игроков")
makeFeature(pageVisuals, "esphp", "ESP HP", "Полоска здоровья слева от бокса")
makeFeature(pageVisuals, "espname", "ESP Name", "Имя над боксом")

makeFeature(pageVisuals, "keybind", "Keybinds", "Список биндов на экране", function(s)
    makeToggle(s, "Only enabled (только включённые)", false, function(v) cfg.kbOnlyOn = v end)
end)
makeFeature(pageVisuals, "targetesp", "TargetESP", "Куб над целью", function(s)
    makeToggle(s, "Marker (острые углы)", true, function(v) cfg.tgMarker = v end)
    makeToggle(s, "Marker-2 (скруглённые)", false, function(v) cfg.tgMarker2 = v end)
    makeToggle(s, "Only AttackAura", false, function(v) cfg.tgOnlyAura = v end)
end)

makeFeature(pageVisuals, "targethud", "TargetHUD", "Окно с целью: голова, ник, HP")
makeFeature(pageVisuals, "watermark", "Watermark", "Ватермарк в стиле Neverlose (можно двигать)")
makeFeature(pageVisuals, "notify", "Notify", "Уведомления о вкл/выкл функций")

makeFeature(pageMove, "airstuck", "Airstuck", "Заморозка в воздухе или на земле")
makeFeature(pageMove, "speed", "Speed", "Ускорение движения", function(s)
    makeCycle(s, "Режим", { "CFrame", "Velocity", "WalkSpeed" }, "CFrame", function(v) cfg.speedMode = v end)
    makeSlider(s, "Скорость", 16, 50, 0, 16, function(v) cfg.speed = v end, true)
end)

makeFeature(pageMisc, "surround", "Surround", "Закрывает ближайшего игрока блоками из руки (ПКМ)", function(s)
    makeSlider(s, "Range (блоки)", 1, 8, 1, 6, function(v) cfg.surroundRange = v end)
    makeSlider(s, "Delay (сек)", 0.05, 0.5, 2, 0.12, function(v) cfg.surroundDelay = v end)
end)
makeFeature(pageMisc, "bunnyhop", "Bunnyhop", "Авто-прыжки при зажатом пробеле", function(s)
    makeSlider(s, "Boost", 0, 5, 1, 1, function(v) cfg.bhBoost = v end, true)
end)
makeFeature(pageMisc, "hitsound", "HitSound", "Звук при ударе по игроку", function(s)
    makeCycle(s, "Sound", { "skeet", "uwu" }, "skeet", function(v) cfg.hitSoundName = v end)
    makeSlider(s, "Громкость", 0.5, 10, 1, 3, function(v) cfg.hitVolume = v end)
end)
makeFeature(pageMisc, "notifysound", "NotifySound", "Звук при вкл/выкл функций", function(s)
    makeCycle(s, "Sound", { "uwu", "celestial" }, "uwu", function(v) cfg.notifySound = v end)
end)
makeFeature(pageMisc, "device", "Device", "Режим: компьютер / телефон (вкл - применить)", function(s)
    makeCycle(s, "Устройство", { "Компьютер", "Телефон" }, AUTO_TOUCH and "Телефон" or "Компьютер", function(v)
        cfg.device = v
        if state.device.on then applyDevice(v == "Телефон") end
    end)
end)
hooks.device = function(on)
    if on then applyDevice(cfg.device == "Телефон") else applyDevice(AUTO_TOUCH) end
end
makeFeature(pageMisc, "spider", "Spider", "Лазание по стенам, когда ты рядом с ними", function(s)
    makeSlider(s, "Speed", 4, 40, 0, 16, function(v) cfg.spiderSpeed = v end, true)
end)
makeFeature(pageMisc, "strafe", "Strafe", "Разгон в воздухе (A/D + поворот мыши)", function(s)
    makeSlider(s, "Strength", 1, 10, 1, 4, function(v) cfg.airStrength = v end, true)
end)

showTab("Combat")

-- Открытие/закрытие
local function overMenu()
    if not main.Visible then return false end
    local m = UIS:GetMouseLocation() - Vector2.new(0, 36)
    local p, s = main.AbsolutePosition, main.AbsoluteSize
    local mp = UIS:GetMouseLocation()
    return (mp.X >= p.X and mp.X <= p.X + s.X and mp.Y >= p.Y + 0 and mp.Y <= p.Y + s.Y + 72)
end

local function setOpen(o)
    if o then
        main.Visible = true
        scale.Scale = baseScale * 0.94
        tw(scale, 0.15, { Scale = baseScale })
    else
        tw(scale, 0.12, { Scale = baseScale * 0.94 })
        task.delay(0.12, function()
            if scale.Scale < baseScale * 0.99 then main.Visible = false end
        end)
    end
end
local menuOpen = true

-- Кнопка открытия меню для телефона (перетаскиваемая)
do
    menuBtn = makeDragButton("MENU", function()
        menuOpen = not menuOpen
        setOpen(menuOpen)
    end)
    menuBtn.TextSize = 11
    menuBtn.Position = UDim2.new(0, 14, 0, 70)
    menuBtn.Visible = IS_TOUCH
end

----------------------------------------------------------------
-- Ввод: RightShift + бинды
----------------------------------------------------------------
bind(UIS.InputBegan, function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if listeningKey then
        local k = listeningKey
        listeningKey = nil
        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
            state[k].bind = nil
        elseif input.KeyCode ~= Enum.KeyCode.RightShift and input.KeyCode ~= Enum.KeyCode.Insert then
            state[k].bind = input.KeyCode
        end
        ui[k].bindLabel.Text = bindText(k)
        ui[k].bindLabel.TextColor3 = C.dim
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
        menuOpen = not menuOpen
        setOpen(menuOpen)
        return
    end

    if processed then return end
    for key, s in pairs(state) do
        if s.bind and s.bind == input.KeyCode then setFeature(key) end
    end
end)

----------------------------------------------------------------
-- TriggerBot: луч против габаритного бокса игрока (не зависит от хитбоксов)
----------------------------------------------------------------
local function rayBox(origin, dir, cf, size)
    local o = cf:PointToObjectSpace(origin)
    local d = cf:VectorToObjectSpace(dir)
    local h = size / 2
    local tmin, tmax = -math.huge, math.huge
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local oa, da, ha = o[axis], d[axis], h[axis]
        if math.abs(da) < 1e-6 then
            if math.abs(oa) > ha then return nil end
        else
            local t1, t2 = (-ha - oa) / da, (ha - oa) / da
            if t1 > t2 then t1, t2 = t2, t1 end
            tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
            if tmin > tmax then return nil end
        end
    end
    if tmax < 0 then return nil end
    return math.max(tmin, 0)
end

local function clickMouse()
    lastAttack = os.clock()
    if IS_TOUCH then
        local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function() tool:Activate() end)
            return
        end
        local vp = getCam().ViewportSize
        VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
        VIM:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
        return
    end
    if mouse1click then
        pcall(mouse1click)
    else
        local loc = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
    end
end

local lastHit = 0
bind(RunService.Heartbeat, function()
    if not state.trigger.on then return end
    local hum, root = getHum(), getRoot()
    if not (hum and root and hum.Health > 0) then return end
    if (IS_TOUCH and main.Visible) or overMenu() then return end

    if cfg.crits then
        local st = hum:GetState()
        local air = hum.FloorMaterial == Enum.Material.Air
            or st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
        if not air then return end
    end

    local now = os.clock()
    local interval = cfg.useCooldown and cfg.cooldown or 0.05
    if now - lastHit < interval then return end

    local cam = getCam()
    local loc = IS_TOUCH and (cam.ViewportSize / 2) or UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(loc.X, loc.Y)
    local dir = ray.Direction.Unit

    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        if th and th.Health > 0 then
            local cf, size = ch:GetBoundingBox()
            if (cf.Position - root.Position).Magnitude <= TRIG_RANGE and rayBox(ray.Origin, dir, cf, size) then
                lastHit = now
                clickMouse()
                return
            end
        end
    end
end)

----------------------------------------------------------------
-- AimAssist: 360°, Focus (липкая цель), рендер в самом конце кадра
----------------------------------------------------------------
local focusPlr = nil

local function targetPart(plr)
    local ch = plr.Character
    if not ch then return nil end
    local th = ch:FindFirstChildOfClass("Humanoid")
    if not (th and th.Health > 0) then return nil end
    return ch:FindFirstChild("Head") or th.RootPart or ch:FindFirstChild("HumanoidRootPart")
end

RunService:BindToRenderStep("ManewareAim", Enum.RenderPriority.Last.Value, function(dt)
    if not state.aim.on then
        focusPlr = nil
        return
    end
    local root = getRoot()
    if not root then return end
    local cam = getCam()
    local maxDist = cfg.range * BLOCK

    local part
    -- удерживаем текущую цель (Focus)
    if cfg.focus and focusPlr then
        local p = targetPart(focusPlr)
        if p and (p.Position - root.Position).Magnitude <= maxDist then
            part = p
        else
            focusPlr = nil
        end
    end
    if not cfg.focus then focusPlr = nil end

    -- ищем новую цель: наименьший угол к направлению камеры, в любую сторону
    if not part then
        local bestAng = math.huge
        local camPos, camLook = cam.CFrame.Position, cam.CFrame.LookVector
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp then
                local p = targetPart(plr)
                if p and (p.Position - root.Position).Magnitude <= maxDist then
                    local dirTo = (p.Position - camPos).Unit
                    local ang = math.acos(math.clamp(camLook:Dot(dirTo), -1, 1))
                    if ang < bestAng then
                        bestAng, part = ang, p
                        if cfg.focus then focusPlr = plr end
                    end
                end
            end
        end
    end

    if part then
        local alpha = math.clamp(dt * 10 / cfg.smooth, 0, 1)
        local camPos = cam.CFrame.Position
        cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(camPos, part.Position), alpha)
    end
end)

----------------------------------------------------------------
-- ESP (Drawing API)
----------------------------------------------------------------
-- Стабильный бокс: не зависит от аксессуаров, инструментов и поз (раньше он "раздувался")
local function espBox(char, hum)
    local root = hum.RootPart or char:FindFirstChild("HumanoidRootPart")
    if not root then return char:GetBoundingBox() end
    local head = char:FindFirstChild("Head")
    local rp = root.Position
    local bottom
    if hum.RigType == Enum.HumanoidRigType.R15 then
        bottom = rp.Y - root.Size.Y / 2 - hum.HipHeight
    else
        bottom = rp.Y - root.Size.Y / 2 - 2
    end
    local top = head and (head.Position.Y + head.Size.Y / 2) or (rp.Y + 2.5)
    if top - bottom < 2 or top - bottom > 12 then top = bottom + 5.5 end
    local look = root.CFrame.LookVector
    local yaw = math.atan2(-look.X, -look.Z)
    local cf = CFrame.new(rp.X, (top + bottom) / 2, rp.Z) * CFrame.Angles(0, yaw, 0)
    return cf, Vector3.new(3.6, top - bottom, 2.2)
end

local esp = {}

local function newLine(thick, color)
    local l = Drawing.new("Line")
    l.Thickness = thick
    l.Color = color
    l.Visible = false
    return l
end

local function createESP(plr)
    local o = { box = {}, hpBg = newLine(4, Color3.new(0, 0, 0)), hp = newLine(2, Color3.new(0, 1, 0)) }
    for i = 1, 12 do o.box[i] = newLine(1.5, ACCENT) end
    o.name = Drawing.new("Text")
    o.name.Size = 14
    o.name.Center = true
    o.name.Outline = true
    o.name.Color = Color3.new(1, 1, 1)
    o.name.Visible = false
    esp[plr] = o
end

local function hideESP(o)
    for _, l in ipairs(o.box) do l.Visible = false end
    o.hpBg.Visible = false
    o.hp.Visible = false
    o.name.Visible = false
end

local function removeESP(plr)
    local o = esp[plr]
    if not o then return end
    for _, l in ipairs(o.box) do l:Remove() end
    o.hpBg:Remove(); o.hp:Remove(); o.name:Remove()
    esp[plr] = nil
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= lp then createESP(p) end end
bind(Players.PlayerAdded, function(p) if p ~= lp then createESP(p) end end)
bind(Players.PlayerRemoving, removeESP)

local edges = {}
for i = 0, 7 do
    for _, b in ipairs({ 1, 2, 4 }) do
        if bit32.band(i, b) == 0 then
            table.insert(edges, { i + 1, i + b + 1 })
        end
    end
end

bind(RunService.RenderStepped, function()
    local cam = getCam()
    local anyOn = state.esp3d.on or state.esphp.on or state.espname.on

    for plr, o in pairs(esp) do
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (anyOn and char and hum and hum.Health > 0) then
            hideESP(o)
        else
            local cf, size = espBox(char, hum)
            local pts, ok = {}, true
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge

            for i = 0, 7 do
                local x = (bit32.band(i, 1) ~= 0) and 1 or -1
                local y = (bit32.band(i, 2) ~= 0) and 1 or -1
                local z = (bit32.band(i, 4) ~= 0) and 1 or -1
                local world = cf * CFrame.new(x * size.X / 2, y * size.Y / 2, z * size.Z / 2)
                local v = cam:WorldToViewportPoint(world.Position)
                if v.Z <= 0 then ok = false break end
                pts[i + 1] = Vector2.new(v.X, v.Y)
                minX, minY = math.min(minX, v.X), math.min(minY, v.Y)
                maxX, maxY = math.max(maxX, v.X), math.max(maxY, v.Y)
            end

            if not ok then
                hideESP(o)
            else
                for i, e in ipairs(edges) do
                    local l = o.box[i]
                    if state.esp3d.on then
                        l.From, l.To, l.Visible = pts[e[1]], pts[e[2]], true
                    else
                        l.Visible = false
                    end
                end

                if state.esphp.on then
                    local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local x = minX - 6
                    o.hpBg.From = Vector2.new(x, maxY + 1)
                    o.hpBg.To = Vector2.new(x, minY - 1)
                    o.hpBg.Visible = true
                    o.hp.From = Vector2.new(x, maxY)
                    o.hp.To = Vector2.new(x, maxY - (maxY - minY) * frac)
                    o.hp.Color = Color3.fromHSV(frac * 0.33, 1, 1)
                    o.hp.Visible = true
                else
                    o.hpBg.Visible, o.hp.Visible = false, false
                end

                if state.espname.on then
                    o.name.Text = plr.Name
                    o.name.Position = Vector2.new((minX + maxX) / 2, minY - 18)
                    o.name.Visible = true
                else
                    o.name.Visible = false
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- HitSound: звук, когда у игрока рядом падает HP сразу после твоего клика
----------------------------------------------------------------
local hitSound = Instance.new("Sound")
hitSound.Name = "ManewareHit"
hitSound.SoundId = HITSOUND_ID
hitSound.Parent = game:GetService("SoundService")

bind(UIS.InputBegan, function(i, processed)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
        lastAttack = os.clock()
    end
end)

local lastHP = setmetatable({}, { __mode = "k" })
bind(RunService.Heartbeat, function()
    local root = getRoot()
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        if th then
            local prev = lastHP[th]
            lastHP[th] = th.Health
            if state.hitsound.on and prev and th.Health < prev and root then
                local tr = th.RootPart or ch:FindFirstChild("HumanoidRootPart")
                if tr and (IS_TOUCH or os.clock() - lastAttack <= 0.6) and (tr.Position - root.Position).Magnitude <= TRIG_RANGE + 5 then
                    playNamed(cfg.hitSoundName, cfg.hitVolume)
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- Criticals / AttackAura / TargetStrafe / Surround
----------------------------------------------------------------
local GuiService = game:GetService("GuiService")

local function isAir(hum)
    if hum then
        local st = hum:GetState()
        return hum.FloorMaterial == Enum.Material.Air
            or st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
    end
    local root = getRoot()
    if not root then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { lp.Character }
    return workspace:Raycast(root.Position, Vector3.new(0, -3.8, 0), params) == nil
end

-- Criticals: множитель вертикальной скорости в момент отрыва от земли
-- (работает с любым прыжком, не только с Humanoid.JumpPower) + мини-прыжок перед ударом
local jumpBase = nil -- оставлено для совместимости с выгрузкой
local function restoreJump() jumpBase = nil end
local critWasAir = false
hooks.criticals = function() critWasAir = false end

bind(RunService.Heartbeat, function()
    if not state.criticals.on or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not root then return end
    local air = isAir(hum)
    if air and not critWasAir then
        local v = root.AssemblyLinearVelocity
        if v.Y > 4 then
            root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y * cfg.critJump, v.Z)
        end
    end
    critWasAir = air
end)

local function critHop()
    local root = getRoot()
    if not root then return end
    local v = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(v.X, math.clamp(9 * cfg.critJump, 2, 40), v.Z)
end

-- AttackAura
local auraBusy, lastAura = false, 0
local auraCurrent = nil
local aimOverride, aimUntil = nil, 0

local function findTarget(maxDist)
    local root = getRoot()
    if not root then return nil end
    local best, bestRoot, bestD
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        local tr = ch and ((th and th.RootPart) or ch:FindFirstChild("HumanoidRootPart"))
        if tr and (not th or th.Health > 0) then
            local d = (tr.Position - root.Position).Magnitude
            if d <= maxDist and (not bestD or d < bestD) then
                best, bestRoot, bestD = ch, tr, d
            end
        end
    end
    return best, bestRoot, bestD
end

-- части карты между камерой и целью (то, что "ловит" клик)
local function obstructions(ch, aimPos)
    local origin = getCam().CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter = { lp.Character }
    params.FilterDescendantsInstances = filter
    local list = {}
    for _ = 1, 12 do
        local res = workspace:Raycast(origin, aimPos - origin, params)
        if not res or res.Instance:IsDescendantOf(ch) then break end
        list[#list + 1] = res.Instance
        filter[#filter + 1] = res.Instance
        params.FilterDescendantsInstances = filter
    end
    return list
end

local function inMenu(loc)
    if not main.Visible then return false end
    local p, s = main.AbsolutePosition, main.AbsoluteSize
    local inset = GuiService:GetGuiInset().Y
    return loc.X >= p.X and loc.X <= p.X + s.X and loc.Y >= p.Y + inset and loc.Y <= p.Y + s.Y + inset
end

local function clickAt(loc)
    if IS_TOUCH then
        clickMouse()
        return
    end
    lastAttack = os.clock()
    local old = UIS:GetMouseLocation()
    VIM:SendMouseMoveEvent(loc.X, loc.Y, game)
    VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, true, game, 0)
    task.wait(0.03)
    VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
    if UIS.MouseBehavior == Enum.MouseBehavior.Default then
        VIM:SendMouseMoveEvent(old.X, old.Y, game)
    end
end

local function doAttack(ch, tr)
    auraBusy = true
    local restore = {}
    pcall(function()
        local hum = getHum()
        -- Criticals включён: прыгаем маленько и бьём в воздухе (крит даже с земли)
        if state.criticals.on and not isAir(hum) then
            critHop()
            task.wait(0.06)
        end
        if not (tr and tr.Parent) then return end
        local aimPos = tr.Position
        local blockers = obstructions(ch, aimPos)
        if #blockers > 0 then
            if not cfg.auraBlock then return end -- за блоком и Attack Block выключен
            for _, part in ipairs(blockers) do
                if part.CanQuery then
                    part.CanQuery = false -- клик/луч игры пролетает сквозь блок
                    restore[#restore + 1] = part
                end
            end
        end
        aimOverride, aimUntil = aimPos, os.clock() + 0.2
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
        local cam = getCam()
        local v = cam:WorldToViewportPoint(aimPos)
        local loc = Vector2.new(v.X, v.Y)
        if IS_TOUCH then
            if not main.Visible then clickAt(loc) end
        elseif not inMenu(loc) then
            clickAt(loc)
        end
        task.wait(0.05)
    end)
    for _, part in ipairs(restore) do
        pcall(function() part.CanQuery = true end)
    end
    auraBusy = false
end

bind(RunService.Heartbeat, function()
    if not state.aura.on or auraBusy or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not root or (hum and hum.Health <= 0) then return end
    if os.clock() - lastAura < 1 / cfg.auraCooldown then return end
    local ch, tr = findTarget(cfg.auraRange * BLOCK)
    if not ch then return end
    -- Crits: только в воздухе (или с Criticals - тогда сам подпрыгнет)
    if cfg.auraCrits and not isAir(hum) and not state.criticals.on then return end
    lastAura = os.clock()
    task.spawn(doAttack, ch, tr)
end)

-- наведение камеры (не Free) и момент удара
RunService:BindToRenderStep("ManewareAura", Enum.RenderPriority.Last.Value, safe(function()
    auraCurrent = nil
    if not state.aura.on or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not root or (hum and hum.Health <= 0) then return end
    local cam = getCam()
    local reach = cfg.auraRange * BLOCK
    local chase = state.targetstrafe.on or (cfg.auraTarget and not cfg.auraFree)
    local ch, tr = findTarget(chase and 120 or reach)
    auraCurrent = ch
    local look
    if aimOverride and os.clock() < aimUntil then
        look = aimOverride            -- момент удара (работает и в Free)
    elseif ch and not cfg.auraFree then
        look = tr.Position            -- не Free: камера держит цель
    end
    if look then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, look) end
end))

-- Кружение вокруг цели (общее для AttackAura Target и TargetStrafe).
-- Сначала скорость + Humanoid:Move; если персонаж почти не двигается (игра сбрасывает
-- скорость) - автоматически переключается на сдвиг CFrame.
local moveFallback, slowFrames, lastFlat = false, 0, nil
local function circleMove(dt, hum, root, tp, radius, speed)
    local rp = root.Position
    local flat = Vector3.new(rp.X, 0, rp.Z)
    local rel = Vector3.new(rp.X - tp.X, 0, rp.Z - tp.Z)
    local ang = rel.Magnitude > 0.01 and math.atan2(rel.Z, rel.X) or 0
    local lead = math.clamp(speed * 0.12 / math.max(radius, 1), 0.15, 1.2)
    local goal = Vector3.new(tp.X + math.cos(ang + lead) * radius, 0, tp.Z + math.sin(ang + lead) * radius)
    local mv = goal - flat
    if rel.Magnitude > radius + 4 then mv = Vector3.new(-rel.X, 0, -rel.Z) end -- далеко: бежим прямо
    if mv.Magnitude < 0.05 then return end
    local d = mv.Unit
    if hum then hum:Move(d, false) end
    if moveFallback then
        root.CFrame = root.CFrame + d * speed * dt
        return
    end
    local v = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(d.X * speed, v.Y, d.Z * speed)
    if lastFlat then
        if (flat - lastFlat).Magnitude < speed * dt * 0.25 then slowFrames = slowFrames + 1 else slowFrames = 0 end
        if slowFrames > 20 then
            moveFallback = true
            notify("Круги: режим CFrame")
        end
    end
    lastFlat = flat
end
hooks.aura = function() moveFallback, slowFrames, lastFlat = false, 0, nil end
hooks.targetstrafe = function() moveFallback, slowFrames, lastFlat = false, 0, nil end

bind(RunService.Heartbeat, function(dt)
    if not state.aura.on or state.airstuck.on then
        lastFlat = nil
        return
    end
    local hum, root = getHum(), getRoot()
    if not root or (hum and hum.Health <= 0) then return end
    local strafing = state.targetstrafe.on
    local pursue = cfg.auraTarget and not cfg.auraFree
    if not (strafing or pursue) then
        lastFlat = nil
        return
    end
    local ch, tr, dist = findTarget(120)
    if not ch then
        lastFlat = nil
        return
    end
    local reach = cfg.auraRange * BLOCK
    if strafing then
        circleMove(dt, hum, root, tr.Position, cfg.strafeRange, cfg.strafeSpeed)
    else
        circleMove(dt, hum, root, tr.Position, math.clamp(reach * 0.3, 2.5, 5), math.max(hum and hum.WalkSpeed or 16, 16))
    end
    -- Crits без Criticals: сами прыгаем, чтобы бить в воздухе
    if cfg.auraCrits and not state.criticals.on and hum and dist <= reach + 2 and not isAir(hum) then
        hum.Jump = true
    end
end)

----------------------------------------------------------------
-- Surround: настоящие блоки (то, что в руке) через ПКМ вокруг ближайшего игрока.
-- Снизу вверх: нижний, средний, верхний ряд, затем крыша.
----------------------------------------------------------------
local surroundToken = 0
local placeAim = nil -- { cf = CFrame, untilT = number }

RunService:BindToRenderStep("ManewareSurround", Enum.RenderPriority.Last.Value, safe(function()
    if placeAim and os.clock() < placeAim.untilT then getCam().CFrame = placeAim.cf end
end))

local function rmbClick(loc)
    VIM:SendMouseMoveEvent(loc.X, loc.Y, game)
    VIM:SendMouseButtonEvent(loc.X, loc.Y, 1, true, game, 0)
    task.wait(0.04)
    VIM:SendMouseButtonEvent(loc.X, loc.Y, 1, false, game, 0)
end

local function allChars()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then list[#list + 1] = plr.Character end
    end
    return list
end

-- есть ли в клетке твёрдая деталь (персонажи не считаются)
local function occupied(center, B)
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    op.FilterDescendantsInstances = allChars()
    local parts = workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(B * 0.5, B * 0.5, B * 0.5), op)
    for _, p in ipairs(parts) do
        if p.CanCollide and p.Transparency < 1 then return true end
    end
    return false
end

-- камера ставится перед гранью, на которую кликаем ПКМ; блок появляется рядом с гранью
local function placeAt(center, supportPt, normal, B, delay)
    if occupied(center, B) then return true end
    for _ = 1, 2 do
        local camPos = supportPt + normal * (B * 1.6)
        if normal.Y ~= 0 then camPos = camPos + Vector3.new(0, 0, B * 0.5) end
        placeAim = { cf = CFrame.lookAt(camPos, supportPt), untilT = os.clock() + 0.45 }
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
        local v = getCam():WorldToViewportPoint(supportPt)
        rmbClick(Vector2.new(v.X, v.Y))
        task.wait(delay)
        if occupied(center, B) then return true end
    end
    return false
end

local function buildSurround()
    surroundToken = surroundToken + 1
    local my = surroundToken
    local function fail(msg)
        notify(msg)
        if state.surround.on then setFeature("surround", false) end
    end
    if IS_TOUCH then return fail("Surround: только на ПК (нужен ПКМ)") end
    local myRoot = getRoot()
    if not myRoot then return fail("Surround: персонаж не найден") end
    local ch, tr = findTarget(cfg.surroundRange * BLOCK)
    if not ch then return fail("Surround: рядом нет игроков") end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = allChars()
    local res = workspace:Raycast(tr.Position, Vector3.new(0, -40, 0), params)
    if not res then return fail("Surround: под целью нет земли") end

    -- размер блока и сетка берутся из блока под целью
    local gp = res.Instance
    local B, bx, bz = BLOCK, nil, nil
    if math.abs(gp.Size.X - gp.Size.Y) < 0.05 and math.abs(gp.Size.Y - gp.Size.Z) < 0.05 then
        B, bx, bz = gp.Size.X, gp.Position.X, gp.Position.Z
    else
        bx = math.floor(tr.Position.X / B) * B + B / 2
        bz = math.floor(tr.Position.Z / B) * B + B / 2
    end
    local topY = res.Position.Y
    local function cell(dx, dz, layer)
        return Vector3.new(bx + dx * B, topY + B * (layer + 0.5), bz + dz * B)
    end

    local ring = {}
    for dx = -1, 1 do
        for dz = -1, 1 do
            if not (dx == 0 and dz == 0) then ring[#ring + 1] = { dx, dz } end
        end
    end
    local mp = myRoot.Position
    table.sort(ring, function(a, b)
        return (cell(a[1], a[2], 0) - mp).Magnitude < (cell(b[1], b[2], 0) - mp).Magnitude
    end)

    local list = {}
    local function onTop(dx, dz, layer) -- клик по верхней грани блока под клеткой
        local c = cell(dx, dz, layer)
        list[#list + 1] = { c = c, s = Vector3.new(c.X, c.Y - B / 2, c.Z), n = Vector3.new(0, 1, 0) }
    end
    for layer = 0, 2 do
        for _, r in ipairs(ring) do onTop(r[1], r[2], layer) end
    end
    -- крыша: кольцо (кроме клетки -X), центр - клик по внутренней грани блока +X, потом клетка -X
    for _, r in ipairs(ring) do
        if not (r[1] == -1 and r[2] == 0) then onTop(r[1], r[2], 3) end
    end
    local cc = cell(0, 0, 3)
    list[#list + 1] = { c = cc, s = Vector3.new(bx + B / 2, cc.Y, bz), n = Vector3.new(-1, 0, 0) }
    onTop(-1, 0, 3)

    local okCount = 0
    for _, e in ipairs(list) do
        if surroundToken ~= my or not state.surround.on then
            placeAim = nil
            return
        end
        if (tr.Position - Vector3.new(bx, tr.Position.Y, bz)).Magnitude > B * 1.5 then
            placeAim = nil
            return fail("Surround: цель ушла")
        end
        if placeAt(e.c, e.s, e.n, B, cfg.surroundDelay) then okCount = okCount + 1 end
    end
    placeAim = nil
    notify(string.format("Surround: поставлено %d/%d", okCount, #list))
    if state.surround.on then setFeature("surround", false) end
end

local function clearSurround()
    surroundToken = surroundToken + 1
    placeAim = nil
end

hooks.surround = function(on)
    if on then task.spawn(buildSurround) else clearSurround() end
end

bind(lp.CharacterAdded, function()
    jumpBase = nil
    if state.surround.on then setFeature("surround", false) end
end)

----------------------------------------------------------------
-- Перетаскивание произвольного окна
----------------------------------------------------------------
local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, frame.Position
        end
    end)
    bind(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function styleBox(f)
    f.BackgroundColor3 = C.bg
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    corner(f, 8)
    local st = Instance.new("UIStroke", f)
    st.Color = C.line
    st.Thickness = 1
    return st
end

----------------------------------------------------------------
-- Keybinds: список биндов на экране
----------------------------------------------------------------
local KB_ORDER = {
    "airstuck", "esp3d", "esphp", "espname", "speed", "trigger", "aim", "hitsound",
    "criticals", "aura", "targetstrafe", "targetesp", "surround", "bunnyhop", "strafe", "spider",
    "targethud", "watermark", "notify", "notifysound", "device",
}
local KB_NAMES = {
    airstuck = "airstuck", esp3d = "esp 3d", esphp = "esp hp", espname = "esp name", speed = "speed",
    trigger = "triggerbot", aim = "aimassist", hitsound = "hitsound", criticals = "criticals",
    aura = "attackaura", targetstrafe = "targetstrafe", targetesp = "targetesp", surround = "surround",
    bunnyhop = "bunnyhop", strafe = "strafe", spider = "spider",
    targethud = "targethud", watermark = "watermark", notify = "notify", notifysound = "notifysound", device = "device",
}

local kbFrame = Instance.new("Frame")
kbFrame.Name = "Keybinds"
kbFrame.Position = UDim2.new(0, 14, 0.4, 0)
kbFrame.AutomaticSize = Enum.AutomaticSize.XY
kbFrame.Size = UDim2.fromOffset(0, 0)
kbFrame.BackgroundColor3 = C.bg
kbFrame.Active = true
kbFrame.BackgroundTransparency = 0.15
kbFrame.BorderSizePixel = 0
kbFrame.Visible = false
kbFrame.Parent = gui
corner(kbFrame, 8)
do
    local st = Instance.new("UIStroke", kbFrame)
    st.Color = C.line
    st.Thickness = 1
    local pad = Instance.new("UIPadding", kbFrame)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
end
local kbLabel = Instance.new("TextLabel")
kbLabel.BackgroundTransparency = 1
kbLabel.AutomaticSize = Enum.AutomaticSize.XY
kbLabel.Size = UDim2.fromOffset(0, 0)
kbLabel.RichText = true
kbLabel.Font = Enum.Font.GothamBold
kbLabel.TextSize = 20
kbLabel.TextColor3 = C.text
kbLabel.TextXAlignment = Enum.TextXAlignment.Left
kbLabel.TextYAlignment = Enum.TextYAlignment.Top
kbLabel.Text = ""
kbLabel.Parent = kbFrame
makeDraggable(kbFrame)

local kbLast, kbText = 0, ""
bind(RunService.Heartbeat, function()
    if not state.keybind.on then
        kbFrame.Visible = false
        return
    end
    if os.clock() - kbLast < 0.1 then return end
    kbLast = os.clock()
    local lines = {}
    for _, k in ipairs(KB_ORDER) do
        local s = state[k]
        local keyName = s and ((s.bind and s.bind.Name:lower()) or (pins[k] and "btn"))
        if keyName and (s.on or not cfg.kbOnlyOn) then
            local tag = s.on and '<font color="#00d27a">on</font>' or '<font color="#7583a3">off</font>'
            lines[#lines + 1] = string.format("%s [%s] %s", KB_NAMES[k] or k, keyName, tag)
        end
    end
    local text = table.concat(lines, "\n")
    if text ~= kbText then
        kbText = text
        kbLabel.Text = text
    end
    kbFrame.Visible = #lines > 0
end)

----------------------------------------------------------------
-- TargetESP: вращающийся куб-маркер над целью (Drawing)
----------------------------------------------------------------
local MARK_LINES = 120
local markLines = {}
for i = 1, MARK_LINES do markLines[i] = newLine(2.5, ACCENT) end

local function hideMarker()
    for i = 1, MARK_LINES do markLines[i].Visible = false end
end

local function crosshairTarget()
    local cam = getCam()
    local loc = IS_TOUCH and (cam.ViewportSize / 2) or UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(loc.X, loc.Y)
    local dir = ray.Direction.Unit
    local best, bestT
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        if th and th.Health > 0 then
            local cf, size = ch:GetBoundingBox()
            local t = rayBox(ray.Origin, dir, cf, size)
            if t and (not bestT or t < bestT) then best, bestT = ch, t end
        end
    end
    return best
end

local SIGNS = {}
for i = 0, 7 do
    SIGNS[i + 1] = {
        (bit32.band(i, 1) ~= 0) and 1 or -1,
        (bit32.band(i, 2) ~= 0) and 1 or -1,
        (bit32.band(i, 4) ~= 0) and 1 or -1,
    }
end

bind(RunService.RenderStepped, function()
    if not state.targetesp.on or not (cfg.tgMarker or cfg.tgMarker2) then
        hideMarker()
        return
    end
    local ch
    if cfg.tgOnlyAura then
        ch = state.aura.on and auraCurrent or nil
    else
        ch = (state.aura.on and auraCurrent) or crosshairTarget()
    end
    local th = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (th and th.Health > 0) then
        hideMarker()
        return
    end

    local cam = getCam()
    local cf, size = espBox(ch, th)
    local center = cf.Position -- у самого тела
    local h = 2.4
    local th_ = -os.clock() * 0.9 -- медленно крутится вправо
    local c, sn = math.cos(th_), math.sin(th_)

    local function corner3(i)
        local g = SIGNS[i]
        local x, y, z = g[1] * h, g[2] * h, g[3] * h
        return Vector3.new(x * c + z * sn, y, -x * sn + z * c)
    end

    local n = 0
    local function seg(a, b)
        n = n + 1
        local l = markLines[n]
        if not l then return end
        local va, vb = cam:WorldToViewportPoint(center + a), cam:WorldToViewportPoint(center + b)
        if va.Z <= 0 or vb.Z <= 0 then
            l.Visible = false
        else
            l.From, l.To, l.Visible = Vector2.new(va.X, va.Y), Vector2.new(vb.X, vb.Y), true
        end
    end

    local rounded = cfg.tgMarker2
    local LEN, R = 0.35, 0.18 -- длина уголка и радиус скругления (доли ребра)
    for i = 1, 8 do
        local v = corner3(i)
        local es = {}
        for k = 1, 3 do
            local sg = { SIGNS[i][1], SIGNS[i][2], SIGNS[i][3] }
            sg[k] = -sg[k]
            local g = { sg[1] * h, sg[2] * h, sg[3] * h }
            local nv = Vector3.new(g[1] * c + g[3] * sn, g[2], -g[1] * sn + g[3] * c)
            es[k] = nv - v
        end
        for k = 1, 3 do
            seg(v + es[k] * (rounded and R or 0), v + es[k] * LEN)
        end
        if rounded then
            local pairsIdx = { { 1, 2 }, { 1, 3 }, { 2, 3 } }
            for _, pr in ipairs(pairsIdx) do
                local A, B = v + es[pr[1]] * R, v + es[pr[2]] * R
                local prev = A
                for st = 1, 4 do
                    local t = st / 4
                    local pt = A * (1 - t) ^ 2 + v * (2 * (1 - t) * t) + B * (t * t)
                    seg(prev, pt)
                    prev = pt
                end
            end
        end
    end
    for i = n + 1, MARK_LINES do markLines[i].Visible = false end
end)

----------------------------------------------------------------
-- Bunnyhop: авто-прыжок при зажатом пробеле + прибавка скорости на каждом прыжке
----------------------------------------------------------------
local MAX_AIR_SPEED = 80
local bhWasAir = false
bind(RunService.Heartbeat, function()
    local hum, root = getHum(), getRoot()
    if not (hum and root) or not state.bunnyhop.on or state.airstuck.on then
        bhWasAir = false
        return
    end
    local air = isAir(hum)
    local held = (not UIS:GetFocusedTextBox()) and (UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump)
    if air and not bhWasAir and held then
        -- момент отрыва от земли: добавляем скорость по направлению движения
        local d = moveDir()
        if d.Magnitude > 0 and cfg.bhBoost > 0 then
            local v = root.AssemblyLinearVelocity
            local h = Vector3.new(v.X, 0, v.Z) + d * cfg.bhBoost
            if h.Magnitude > MAX_AIR_SPEED then h = h.Unit * MAX_AIR_SPEED end
            root.AssemblyLinearVelocity = Vector3.new(h.X, v.Y, h.Z)
        end
    end
    bhWasAir = air
    if held and not air and hum.Health > 0 then
        hum.Jump = true
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end)

----------------------------------------------------------------
-- Strafe: воздушный разгон как в Source (A/D + поворот камеры набирают скорость)
----------------------------------------------------------------
bind(RunService.Heartbeat, function(dt)
    if not state.strafe.on or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not (hum and root and hum.Health > 0) or not isAir(hum) then return end
    local d = moveDir()
    if d.Magnitude == 0 then return end
    local v = root.AssemblyLinearVelocity
    local h = Vector3.new(v.X, 0, v.Z)
    local cap = 3 -- "потолок" желаемой скорости, как у воздушного ускорения в Source
    local add = cap - h:Dot(d)
    if add <= 0 then return end
    local a = math.min(add, cfg.airStrength * dt * cap * 3)
    h = h + d * a
    if h.Magnitude > MAX_AIR_SPEED then h = h.Unit * MAX_AIR_SPEED end
    root.AssemblyLinearVelocity = Vector3.new(h.X, v.Y, h.Z)
end)

----------------------------------------------------------------
-- Spider: лазание по стенам
----------------------------------------------------------------
local spiderClimbing = false
local spiderParams = RaycastParams.new()
spiderParams.FilterType = Enum.RaycastFilterType.Exclude

local function findWall(root)
    spiderParams.FilterDescendantsInstances = { lp.Character }
    local best, bestD
    for i = 0, 7 do
        local a = i * math.pi / 4
        local dir = Vector3.new(math.cos(a), 0, math.sin(a))
        local res = workspace:Raycast(root.Position, dir * 2.6, spiderParams)
        if res and res.Instance.CanCollide and math.abs(res.Normal.Y) < 0.3 then
            if not bestD or res.Distance < bestD then best, bestD = res, res.Distance end
        end
    end
    return best
end

bind(RunService.Heartbeat, function()
    local hum, root = getHum(), getRoot()
    if not state.spider.on or state.airstuck.on or not (hum and root) or hum.Health <= 0 then
        spiderClimbing = false
        return
    end
    local wall = findWall(root)
    local d = moveDir()
    local pushing = wall and d.Magnitude > 0 and d:Dot(-wall.Normal) > 0.2
    if pushing then
        spiderClimbing = true
        local v = root.AssemblyLinearVelocity
        local stick = -wall.Normal * 2 -- слегка прижимаемся к стене
        root.AssemblyLinearVelocity = Vector3.new(stick.X, cfg.spiderSpeed, stick.Z)
    elseif spiderClimbing then
        -- дошли до верха стены: перекидываемся через край
        spiderClimbing = false
        if not wall and d.Magnitude > 0 then
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(d.X * 10, math.max(v.Y, 12), d.Z * 10)
        end
    end
end)

----------------------------------------------------------------
-- TargetHUD: голова, ник, hp (в шкале Minecraft, макс. 20) и полоска
----------------------------------------------------------------
local hud = Instance.new("Frame")
hud.Name = "TargetHUD"
hud.Position = UDim2.new(0.5, 60, 0.5, 40)
hud.Size = UDim2.fromOffset(236, 76)
hud.Visible = false
hud.Active = true
hud.Parent = gui
styleBox(hud)

local hudHead = Instance.new("ImageLabel")
hudHead.Position = UDim2.fromOffset(10, 10)
hudHead.Size = UDim2.fromOffset(46, 46)
hudHead.BackgroundColor3 = C.card
hudHead.BorderSizePixel = 0
hudHead.Parent = hud
corner(hudHead, 8)

local hudName = label(hud, "", 14, Enum.Font.GothamBold, C.text, 66, 8, 160, 18)
local hudHp = label(hud, "hp:20", 13, Enum.Font.GothamMedium, C.dim, 66, 28, 160, 16)
local hudBarBg = Instance.new("Frame")
hudBarBg.Position = UDim2.fromOffset(66, 50)
hudBarBg.Size = UDim2.fromOffset(160, 8)
hudBarBg.BackgroundColor3 = C.off
hudBarBg.BorderSizePixel = 0
hudBarBg.Parent = hud
corner(hudBarBg, 4)
local hudBar = Instance.new("Frame")
hudBar.Size = UDim2.fromScale(1, 1)
hudBar.BackgroundColor3 = Color3.fromRGB(0, 210, 122)
hudBar.BorderSizePixel = 0
hudBar.Parent = hudBarBg
corner(hudBar, 4)
makeDraggable(hud)

local thumbCache = {}
local hudTarget, hudFrac = nil, 1
bind(RunService.RenderStepped, function(dt)
    if not state.targethud.on then
        hud.Visible = false
        return
    end
    local ch = (state.aura.on and auraCurrent) or crosshairTarget()
    local th = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (th and th.Health > 0) then
        hud.Visible = false
        hudTarget = nil
        return
    end
    hud.Visible = true
    if ch ~= hudTarget then
        hudTarget = ch
        hudFrac = math.clamp(th.Health / math.max(th.MaxHealth, 1), 0, 1)
        local plr = Players:GetPlayerFromCharacter(ch)
        hudName.Text = plr and plr.Name or ch.Name
        hudHead.Image = ""
        if plr then
            local uid = plr.UserId
            if thumbCache[uid] then
                hudHead.Image = thumbCache[uid]
            else
                task.spawn(function()
                    local ok, img = pcall(function()
                        return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                    end)
                    if ok and img then
                        thumbCache[uid] = img
                        if hudTarget == ch then hudHead.Image = img end
                    end
                end)
            end
        end
    end
    local frac = math.clamp(th.Health / math.max(th.MaxHealth, 1), 0, 1)
    hudFrac = hudFrac + (frac - hudFrac) * math.min(1, dt * 8) -- плавное уменьшение
    local hp = math.floor(frac * 20 * 10 + 0.5) / 10
    hudHp.Text = "hp:" .. string.format("%g", hp)
    hudBar.Size = UDim2.new(hudFrac, 0, 1, 0)
    hudBar.BackgroundColor3 = Color3.fromHSV(hudFrac * 0.33, 0.85, 0.9)
end)

----------------------------------------------------------------
-- Watermark (в стиле Neverlose): имя | fps | ping | время, перетаскивается
----------------------------------------------------------------
local wm = Instance.new("Frame")
wm.Name = "Watermark"
wm.AnchorPoint = Vector2.new(1, 0)
wm.Position = UDim2.new(1, -14, 0, 14)
wm.Size = UDim2.fromOffset(0, 28)
wm.AutomaticSize = Enum.AutomaticSize.X
wm.Visible = false
wm.Active = true
wm.Parent = gui
styleBox(wm)
do
    local pad = Instance.new("UIPadding", wm)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.BorderSizePixel = 0
    line.BackgroundColor3 = Color3.new(1, 1, 1)
    line.Parent = wm
    local g = Instance.new("UIGradient", line)
    g.Color = ColorSequence.new(ACCENT, Color3.fromRGB(120, 90, 255))
    corner(line, 2)
end
local wmLabel = Instance.new("TextLabel")
wmLabel.BackgroundTransparency = 1
wmLabel.Size = UDim2.fromOffset(0, 28)
wmLabel.AutomaticSize = Enum.AutomaticSize.X
wmLabel.RichText = true
wmLabel.Font = Enum.Font.GothamMedium
wmLabel.TextSize = 13
wmLabel.TextColor3 = C.text
wmLabel.Text = ""
wmLabel.Parent = wm
makeDraggable(wm)

local fpsSmooth, wmLast = 60, 0
bind(RunService.RenderStepped, function(dt)
    fpsSmooth = fpsSmooth + (1 / math.max(dt, 1e-3) - fpsSmooth) * 0.1
    if not state.watermark.on then
        wm.Visible = false
        return
    end
    wm.Visible = true
    if os.clock() - wmLast < 0.25 then return end
    wmLast = os.clock()
    local ping = 0
    pcall(function() ping = lp:GetNetworkPing() * 1000 end)
    local sep = '  <font color="#2c364e">|</font>  '
    wmLabel.Text = table.concat({
        'mane<font color="#00aaff">ware</font>',
        lp.Name,
        string.format("%d fps", math.floor(fpsSmooth + 0.5)),
        string.format("%d ms", math.floor(ping + 0.5)),
        os.date("%H:%M"),
    }, sep)
end)

----------------------------------------------------------------
-- Notify: уведомления "on hitsound" / "off hitsound" + NotifySound
----------------------------------------------------------------
local toastHolder = Instance.new("Frame")
toastHolder.BackgroundTransparency = 1
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.Position = UDim2.new(1, -16, 1, -50)
toastHolder.Size = UDim2.fromOffset(260, 320)
toastHolder.Parent = gui
do
    local l = Instance.new("UIListLayout", toastHolder)
    l.Padding = UDim.new(0, 6)
    l.VerticalAlignment = Enum.VerticalAlignment.Bottom
    l.HorizontalAlignment = Enum.HorizontalAlignment.Right
    l.SortOrder = Enum.SortOrder.LayoutOrder
end
local toastN = 0

local function toast(name, isOn)
    toastN = toastN + 1
    local f = Instance.new("Frame")
    f.LayoutOrder = toastN
    f.AutomaticSize = Enum.AutomaticSize.XY
    f.Size = UDim2.fromOffset(0, 0)
    f.Parent = toastHolder
    local st = styleBox(f)
    local pad = Instance.new("UIPadding", f)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 7), UDim.new(0, 7)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.AutomaticSize = Enum.AutomaticSize.XY
    l.Size = UDim2.fromOffset(0, 0)
    l.RichText = true
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 14
    l.TextColor3 = C.text
    local c = isOn and "#00d27a" or "#ff5a6a"
    l.Text = string.format('<font color="%s">%s</font> %s', c, isOn and "on" or "off", name)
    l.Parent = f
    task.delay(2.2, function()
        tw(f, 0.3, { BackgroundTransparency = 1 })
        tw(l, 0.3, { TextTransparency = 1 })
        tw(st, 0.3, { Transparency = 1 })
        task.delay(0.35, function() pcall(function() f:Destroy() end) end)
    end)
end

onToggle = function(key, value)
    if state.notifysound.on then
        local snd = cfg.notifySound
        if snd == "celestial" and not value then snd = "celestial_off" end
        task.spawn(playNamed, snd, 2)
    end
    if state.notify.on then
        toast(KB_NAMES[key] or key, value)
    end
end

setFeature("watermark", true)

----------------------------------------------------------------
-- Выгрузка (вызывается при повторном запуске скрипта)
----------------------------------------------------------------
env.ManewareUnload = function()
    if state.airstuck.on then pcall(applyAirstuck, false) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() RunService:UnbindFromRenderStep("ManewareAim") end)
    pcall(function() RunService:UnbindFromRenderStep("ManewarePin") end)
    pcall(function() RunService:UnbindFromRenderStep("ManewareAura") end)
    pcall(function() RunService:UnbindFromRenderStep("ManewareSurround") end)
    pcall(restoreJump)
    for _, l in ipairs(markLines) do pcall(function() l:Remove() end) end
    pcall(function() kbFrame:Destroy() end)
    pcall(clearSurround)
    for plr in pairs(esp) do pcall(removeESP, plr) end
    pcall(function() gui:Destroy() end)
    pcall(function() hitSound:Destroy() end)
end

notify("Загружено. RightShift / Insert - меню")
