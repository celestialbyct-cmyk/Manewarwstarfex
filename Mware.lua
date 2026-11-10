--// Maneware Hub v3 | RightShift - открыть/закрыть меню
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
local function bind(signal, fn)
    local c = signal:Connect(fn)
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
}
local ui = {}

local HITSOUND_ID = "rbxassetid://5633695679" -- skeet (ID из комьюнити-скрипта, можно заменить)
local lastAttack = 0
local IS_TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled
local pins = {}
local notify = function() end

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
RunService:BindToRenderStep("ManewarePin", Enum.RenderPriority.Last.Value, pin)

----------------------------------------------------------------
-- Переключение
----------------------------------------------------------------
local hooks = {}
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
label(side, "private hub", 11, Enum.Font.Gotham, C.dim, 18, 40, 120, 14)
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
        notify("Кнопка убрана: " .. key)
        return
    end
    local n = 0
    for _ in pairs(pins) do n = n + 1 end
    local btn = makeDragButton(PIN_NAMES[key] or key, function() setFeature(key) end)
    btn.Position = UDim2.new(1, -62, 0, 70 + n * 54)
    local function refresh()
        local on = state[key].on
        btn.BackgroundColor3 = on and ACCENT or C.card
        btn.TextColor3 = on and Color3.new(1, 1, 1) or C.text
    end
    refresh()
    pins[key] = { btn = btn, refresh = refresh }
    ui[key].bindLabel.Text = "[BTN]"
    notify("Кнопка добавлена: " .. key .. " (долгое нажатие на функцию - убрать)")
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
    bindLabel.Position = UDim2.new(1, build and -108 or -62, 0.5, 0)

    local sw, setVisual = makeSwitch(header)
    sw.Position = UDim2.new(1, -14, 0.5, 0)

    ui[key] = { set = setVisual, bindLabel = bindLabel }

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
    makeToggle(s, "Target (бежать к цели, кружить)", false, function(v) cfg.auraTarget = v end)
    makeToggle(s, "Crits (только в прыжке)", false, function(v) cfg.auraCrits = v end)
end)
makeFeature(pageCombat, "targetstrafe", "TargetStrafe", "Кружит возле цели (только с AttackAura)", function(s)
    makeSlider(s, "Speed", 1, 40, 0, 10, function(v) cfg.strafeSpeed = v end)
    makeSlider(s, "Range (стады)", 1, 10, 1, 4, function(v) cfg.strafeRange = v end)
end)
makeFeature(pageCombat, "hitsound", "HitSound", "Звук skeet при ударе по игроку", function(s)
    makeSlider(s, "Громкость", 0.5, 10, 1, 3, function(v) cfg.hitVolume = v end)
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

makeFeature(pageMove, "airstuck", "Airstuck", "Заморозка в воздухе или на земле")
makeFeature(pageMove, "speed", "Speed", "Ускорение движения", function(s)
    makeCycle(s, "Режим", { "CFrame", "Velocity", "WalkSpeed" }, "CFrame", function(v) cfg.speedMode = v end)
    makeSlider(s, "Скорость", 16, 50, 0, 16, function(v) cfg.speed = v end, true)
end)

makeFeature(pageMisc, "surround", "Surround", "Запирает тебя в блоках (1 блок внутри)")

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
if IS_TOUCH then
    local menuBtn = makeDragButton("MENU", function()
        menuOpen = not menuOpen
        setOpen(menuOpen)
    end)
    menuBtn.TextSize = 11
    menuBtn.Position = UDim2.new(0, 14, 0, 70)
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
        elseif input.KeyCode ~= Enum.KeyCode.RightShift then
            state[k].bind = input.KeyCode
        end
        ui[k].bindLabel.Text = bindText(k)
        ui[k].bindLabel.TextColor3 = C.dim
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
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
            local cf, size = char:GetBoundingBox()
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
                    hitSound.Volume = cfg.hitVolume
                    hitSound.TimePosition = 0
                    hitSound:Play()
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- Criticals / AttackAura / Surround
----------------------------------------------------------------
local GuiService = game:GetService("GuiService")

local function isAir(hum)
    local st = hum:GetState()
    return hum.FloorMaterial == Enum.Material.Air
        or st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
end

-- Criticals: множитель прыжка + мини-прыжок перед ударом (крит с земли)
local jumpBase = nil
local function restoreJump()
    local hum = getHum()
    if jumpBase and hum then
        pcall(function() hum.JumpPower = jumpBase.jp end)
        pcall(function() hum.JumpHeight = jumpBase.jh end)
    end
    jumpBase = nil
end
hooks.criticals = function(on)
    if on then jumpBase = nil else restoreJump() end
end
bind(RunService.Heartbeat, function()
    if not state.criticals.on or state.airstuck.on then return end
    local hum = getHum()
    if not hum then return end
    if not jumpBase then jumpBase = { jp = hum.JumpPower, jh = hum.JumpHeight } end
    hum.JumpPower = jumpBase.jp * cfg.critJump
    hum.JumpHeight = jumpBase.jh * cfg.critJump ^ 2 -- высота растёт от квадрата силы
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
        local tr = th and th.Health > 0 and (th.RootPart or ch:FindFirstChild("HumanoidRootPart"))
        if tr then
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
        if not hum then return end
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
    if not (hum and root and hum.Health > 0) then return end
    if os.clock() - lastAura < 1 / cfg.auraCooldown then return end
    local ch, tr = findTarget(cfg.auraRange * BLOCK)
    if not ch then return end
    -- Crits: только в воздухе (или с Criticals - тогда сам подпрыгнет)
    if cfg.auraCrits and not isAir(hum) and not state.criticals.on then return end
    lastAura = os.clock()
    task.spawn(doAttack, ch, tr)
end)

-- наведение камеры + Target (бег к цели и кружение)
RunService:BindToRenderStep("ManewareAura", Enum.RenderPriority.Last.Value, function()
    auraCurrent = nil
    if not state.aura.on or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not (hum and root and hum.Health > 0) then return end
    local cam = getCam()
    local reach = cfg.auraRange * BLOCK
    local pursue = cfg.auraTarget and not cfg.auraFree and not state.targetstrafe.on
    local ch, tr, dist = findTarget(pursue and 120 or reach)
    auraCurrent = ch

    local look
    if aimOverride and os.clock() < aimUntil then
        look = aimOverride            -- момент удара (работает и в Free)
    elseif ch and not cfg.auraFree then
        look = tr.Position            -- не Free: камера держит цель
    end
    if look then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, look) end

    if pursue and ch then
        local tp = tr.Position
        local rel = Vector3.new(root.Position.X - tp.X, 0, root.Position.Z - tp.Z)
        local radius = math.clamp(reach * 0.3, 2.5, 5) -- прижимаемся вплотную
        local mv
        if rel.Magnitude > radius + 3 then
            mv = -rel                                   -- далеко: бежим прямо
        else
            local ang = math.atan2(rel.Z, rel.X) + 0.6  -- кружим вокруг цели
            local goal = Vector3.new(tp.X + math.cos(ang) * radius, 0, tp.Z + math.sin(ang) * radius)
            mv = goal - Vector3.new(root.Position.X, 0, root.Position.Z)
        end
        if mv.Magnitude > 0.3 then hum:Move(mv.Unit, false) end
        -- Crits без Criticals: сами прыгаем, чтобы бить в воздухе
        if cfg.auraCrits and not state.criticals.on and dist <= reach + 2 and not isAir(hum) then
            hum.Jump = true
        end
    end
end)

-- Surround: коробка из блоков вокруг игрока (внутри 1 блок), снизу вверх, затем крыша
local surroundParts, surroundToken = {}, 0

-- ЗАМЕНИ эту функцию, если в игре есть свой способ ставить блоки (remote и т.п.).
-- По умолчанию блок создаётся локально (виден и твёрдый только для тебя).
local function placeBlock(cf)
    local b = Instance.new("Part")
    b.Name = "ManewareBlock"
    b.Size = Vector3.new(BLOCK, BLOCK, BLOCK)
    b.CFrame = cf
    b.Anchored = true
    b.CanCollide = true
    b.Material = Enum.Material.SmoothPlastic
    b.Color = ACCENT
    b.Transparency = 0.35
    b.Parent = workspace
    surroundParts[#surroundParts + 1] = b
    return b
end

local function clearSurround()
    surroundToken = surroundToken + 1
    for _, b in ipairs(surroundParts) do pcall(function() b:Destroy() end) end
    table.clear(surroundParts)
end

local function buildSurround()
    local root, hum = getRoot(), getHum()
    if not (root and hum) then
        notify("Surround: персонаж не найден")
        setFeature("surround", false)
        return
    end
    clearSurround()
    local my = surroundToken
    local cx, cz = root.Position.X, root.Position.Z

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { lp.Character }
    local down = workspace:Raycast(root.Position, Vector3.new(0, -30, 0), params)
    local feetY = down and down.Position.Y or (root.Position.Y - hum.HipHeight - root.Size.Y / 2)

    local ring = {}
    for dx = -1, 1 do
        for dz = -1, 1 do
            if not (dx == 0 and dz == 0) then ring[#ring + 1] = { dx, dz } end
        end
    end

    local function put(dx, dz, layer)
        if surroundToken ~= my then return false end
        placeBlock(CFrame.new(cx + dx * BLOCK, feetY + BLOCK * (layer + 0.5), cz + dz * BLOCK))
        task.wait(0.05)
        return true
    end

    for layer = 0, 2 do                         -- низ, середина, верх
        for _, c in ipairs(ring) do
            if not put(c[1], c[2], layer) then return end
        end
    end
    for dx = -1, 1 do                           -- крыша 3x3
        for dz = -1, 1 do
            if not put(dx, dz, 3) then return end
        end
    end
    notify("Surround: готово")
end

hooks.surround = function(on)
    if on then task.spawn(buildSurround) else clearSurround() end
end

bind(lp.CharacterAdded, function()
    jumpBase = nil
    if state.surround.on then setFeature("surround", false) end
end)

----------------------------------------------------------------
-- TargetStrafe: кружение вокруг цели AttackAura
----------------------------------------------------------------
bind(RunService.Heartbeat, function()
    if not (state.targetstrafe.on and state.aura.on) or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not (hum and root and hum.Health > 0) then return end
    local ch, tr = findTarget(60)
    if not ch then return end
    local radius = cfg.strafeRange
    local tp, rp = tr.Position, root.Position
    local rel = Vector3.new(rp.X - tp.X, 0, rp.Z - tp.Z)
    local ang = rel.Magnitude > 0.01 and math.atan2(rel.Z, rel.X) or 0
    local lead = math.clamp(cfg.strafeSpeed * 0.1 / radius, 0.12, 1.2) -- на сколько опережаем по кругу
    local goal = Vector3.new(tp.X + math.cos(ang + lead) * radius, 0, tp.Z + math.sin(ang + lead) * radius)
    local mv = goal - Vector3.new(rp.X, 0, rp.Z)
    if mv.Magnitude > 0.05 then
        local d = mv.Unit
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(d.X * cfg.strafeSpeed, v.Y, d.Z * cfg.strafeSpeed)
    end
end)

----------------------------------------------------------------
-- Keybinds: список биндов на экране
----------------------------------------------------------------
local KB_ORDER = {
    "airstuck", "esp3d", "esphp", "espname", "speed", "trigger", "aim", "hitsound",
    "criticals", "aura", "targetstrafe", "targetesp", "surround",
}
local KB_NAMES = {
    airstuck = "airstuck", esp3d = "esp 3d", esphp = "esp hp", espname = "esp name", speed = "speed",
    trigger = "triggerbot", aim = "aimassist", hitsound = "hitsound", criticals = "criticals",
    aura = "attackaura", targetstrafe = "targetstrafe", targetesp = "targetesp", surround = "surround",
}

local kbFrame = Instance.new("Frame")
kbFrame.Name = "Keybinds"
kbFrame.Position = UDim2.new(0, 14, 0.4, 0)
kbFrame.AutomaticSize = Enum.AutomaticSize.XY
kbFrame.Size = UDim2.fromOffset(0, 0)
kbFrame.BackgroundColor3 = C.bg
kbFrame.BackgroundTransparency = 0.2
kbFrame.BorderSizePixel = 0
kbFrame.Visible = false
kbFrame.Parent = gui
corner(kbFrame, 8)
do
    local st = Instance.new("UIStroke", kbFrame)
    st.Color = C.line
    st.Thickness = 1
    local pad = Instance.new("UIPadding", kbFrame)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
end
local kbLabel = Instance.new("TextLabel")
kbLabel.BackgroundTransparency = 1
kbLabel.AutomaticSize = Enum.AutomaticSize.XY
kbLabel.Size = UDim2.fromOffset(0, 0)
kbLabel.RichText = true
kbLabel.Font = Enum.Font.GothamMedium
kbLabel.TextSize = 13
kbLabel.TextColor3 = C.text
kbLabel.TextXAlignment = Enum.TextXAlignment.Left
kbLabel.TextYAlignment = Enum.TextYAlignment.Top
kbLabel.Text = ""
kbLabel.Parent = kbFrame

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
        if s and s.bind and (s.on or not cfg.kbOnlyOn) then
            local tag = s.on and '<font color="#00d27a">on</font>' or '<font color="#7583a3">off</font>'
            lines[#lines + 1] = string.format("%s [%s] %s", KB_NAMES[k] or k, s.bind.Name:lower(), tag)
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
for i = 1, MARK_LINES do markLines[i] = newLine(1.5, ACCENT) end

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
    local cf, size = ch:GetBoundingBox()
    local center = cf.Position + Vector3.new(0, size.Y / 2 + 1.8, 0) -- выше тела
    local h = 0.9
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
-- Выгрузка (вызывается при повторном запуске скрипта)
----------------------------------------------------------------
env.ManewareUnload = function()
    if state.airstuck.on then pcall(applyAirstuck, false) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() RunService:UnbindFromRenderStep("ManewareAim") end)
    pcall(function() RunService:UnbindFromRenderStep("ManewarePin") end)
    pcall(function() RunService:UnbindFromRenderStep("ManewareAura") end)
    pcall(restoreJump)
    for _, l in ipairs(markLines) do pcall(function() l:Remove() end) end
    pcall(function() kbFrame:Destroy() end)
    pcall(clearSurround)
    for plr in pairs(esp) do pcall(removeESP, plr) end
    pcall(function() gui:Destroy() end)
    pcall(function() hitSound:Destroy() end)
end

notify("Загружено. RightShift - меню")
