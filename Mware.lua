--// Maneware Hub v5 | INSERT - меню
--// ЛКМ - вкл/выкл | ПКМ - настройки | СКМ - бинд
--// Долгое нажатие (моб.) - экранная кнопка

local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RunService= game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM       = game:GetService("VirtualInputManager")
local SoundService = game:GetService("SoundService")
local GuiService= game:GetService("GuiService")

local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G
if env.ManewareUnload then pcall(env.ManewareUnload) end
if env.StarfexUnload  then pcall(env.StarfexUnload)  end

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("ManewareHub") then parentGui.ManewareHub:Destroy() end
if parentGui:FindFirstChild("StarfexHub")  then parentGui.StarfexHub:Destroy()  end

local conns = {}
local function bind(sig, fn) local c = sig:Connect(fn); conns[#conns+1]=c; return c end
local function getCam() return workspace.CurrentCamera end

----------------------------------------------------------------
-- Тема
----------------------------------------------------------------
local ACCENT = Color3.fromRGB(0, 170, 255)
local C = {
    bg   = Color3.fromRGB(11, 15, 26),  side = Color3.fromRGB(8, 11, 20),
    card = Color3.fromRGB(17, 23, 38),  off  = Color3.fromRGB(44, 54, 78),
    text = Color3.fromRGB(232,238,250), dim  = Color3.fromRGB(117,131,163),
    line = Color3.fromRGB(30, 40, 62),
}
local BLOCK = 4
local TRIG_RANGE = 20

----------------------------------------------------------------
-- Состояние
----------------------------------------------------------------
local state = {}
for _, k in ipairs({ "airstuck","esp3d","esphp","espname","speed","trigger","aim",
    "hitsound","criticals","aura","surround","keybind","targetesp","targetstrafe","bunnyhop" }) do
    state[k] = { on = false, bind = nil }
end

local cfg = {
    speed = 40, speedMode = "WalkSpeed",
    crits = false, useCooldown = true, cooldown = 1,
    smooth = 1, range = 3, focus = false,
    hitVolume = 3, critJump = 1,
    auraCooldown = 1.6, auraBlock = false, auraRange = 3,
    auraFree = false, auraTarget = false, auraCrits = false,
    auraRespectInput = false,  -- если true - WASD перекрывает кружение
    kbOnlyOn = false,
    tgMarker = true, tgMarker2 = false, tgOnlyAura = false,
    strafeSpeed = 12, strafeRange = 4, bhopPower = 1,
}
local ui = {}
local HITSOUND_ID = "rbxassetid://5633695679"
local NOTIFY_ID   = "rbxassetid://4590662766"
local IS_TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled
local pins = {}
local lastAttack = 0

local notifySound = Instance.new("Sound")
notifySound.SoundId = NOTIFY_ID; notifySound.Volume = 0.4
notifySound.Parent = SoundService

local notify = function() end

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = lp.Character
    if not c then return nil end
    local h = getHum()
    return (h and h.RootPart) or c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
        or c:FindFirstChildWhichIsA("BasePart")
end
local function isAir(hum)
    local st = hum:GetState()
    return hum.FloorMaterial == Enum.Material.Air
        or st == Enum.HumanoidStateType.Freefall
        or st == Enum.HumanoidStateType.Jumping
end

----------------------------------------------------------------
-- АНТИЧИТ BYPASS: хук WalkSpeed
----------------------------------------------------------------
-- Блокируем попытки игры сбросить WalkSpeed в 16, пока включён Speed (WalkSpeed mode)
if hookmetamethod and typeof and newcclosure then
    local oldNewIndex
    oldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
        if key == "WalkSpeed"
           and state.speed.on and cfg.speedMode == "WalkSpeed"
           and value == 16
           and typeof(self) == "Instance"
           and self:IsA("Humanoid") then
            return -- отбрасываем сброс
        end
        return oldNewIndex(self, key, value)
    end))
end

----------------------------------------------------------------
-- AIRSTUCK: CFrame-пин без анкора
----------------------------------------------------------------
local stuck = nil

local function applyAirstuck(on)
    if on then
        local root, hum = getRoot(), getHum()
        if not root then notify("Airstuck: нет корня"); return false end
        stuck = { root = root, cf = root.CFrame }
        if hum then
            pcall(function() hum.WalkSpeed = 0 end)
            pcall(function() hum.JumpPower = 0 end)
        end
        notify("Airstuck ON")
        return true
    else
        stuck = nil
        local hum = getHum()
        if hum then
            pcall(function() hum.WalkSpeed = 16 end)
            pcall(function() hum.JumpPower = 50 end)
        end
        notify("Airstuck OFF")
        return true
    end
end

local function pin()
    if not (state.airstuck.on and stuck and stuck.root and stuck.root.Parent) then return end
    local r = stuck.root
    pcall(function() r.CFrame = stuck.cf end)
    pcall(function() r.AssemblyLinearVelocity  = Vector3.zero end)
    pcall(function() r.AssemblyAngularVelocity = Vector3.zero end)
end
bind(RunService.Stepped, pin)
bind(RunService.Heartbeat, pin)
if RunService.PreSimulation  then bind(RunService.PreSimulation,  pin) end
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
-- Speed (multi-layer bypass)
----------------------------------------------------------------
local function moveDir()
    local cf = getCam().CFrame
    local look  = Vector3.new(cf.LookVector.X,  0, cf.LookVector.Z)
    local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
    if look.Magnitude < 1e-3 or right.Magnitude < 1e-3 then return Vector3.zero end
    look, right = look.Unit, right.Unit
    local d = Vector3.zero
    if not UIS:GetFocusedTextBox() then
        if UIS:IsKeyDown(Enum.KeyCode.W) then d += look  end
        if UIS:IsKeyDown(Enum.KeyCode.S) then d -= look  end
        if UIS:IsKeyDown(Enum.KeyCode.D) then d += right end
        if UIS:IsKeyDown(Enum.KeyCode.A) then d -= right end
    end
    if d.Magnitude == 0 then
        local h = getHum()
        if h then d = Vector3.new(h.MoveDirection.X, 0, h.MoveDirection.Z) end
    end
    return d.Magnitude > 0 and d.Unit or Vector3.zero
end

local speedWasOn = false
local function speedStep(dt)
    local hum, root = getHum(), getRoot()
    if not (hum and root) then return end
    if state.speed.on and not state.airstuck.on then
        speedWasOn = true
        local d = moveDir()
        if cfg.speedMode == "WalkSpeed" then
            pcall(function() hum.WalkSpeed = cfg.speed end)
        elseif cfg.speedMode == "Velocity" then
            if d.Magnitude > 0 then
                local v = root.AssemblyLinearVelocity
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.new(d.X * cfg.speed, v.Y, d.Z * cfg.speed)
                end)
            end
        else -- CFrame + velocity
            pcall(function() hum.WalkSpeed = cfg.speed end)
            if d.Magnitude > 0 then
                local v = root.AssemblyLinearVelocity
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.new(d.X * cfg.speed, v.Y, d.Z * cfg.speed)
                end)
            end
        end
    elseif speedWasOn and not state.speed.on then
        speedWasOn = false
        pcall(function() hum.WalkSpeed = 16 end)
    end
end
bind(RunService.Heartbeat, speedStep)
if RunService.Stepped then bind(RunService.Stepped, function(_, dt) speedStep(dt) end) end

-- доп. цикл на WalkSpeed (перекрывает сброс)
task.spawn(function()
    while true do
        task.wait()
        if state.speed.on and not state.airstuck.on
           and (cfg.speedMode == "WalkSpeed" or cfg.speedMode == "CFrame") then
            local hum = getHum()
            if hum then pcall(function() hum.WalkSpeed = cfg.speed end) end
        end
    end
end)

----------------------------------------------------------------
-- BunnyHop + Criticals auto-bounce
----------------------------------------------------------------
bind(RunService.Heartbeat, function()
    if state.airstuck.on then return end
    local hum = getHum()
    if not hum then return end

    local bouncing = false
    if state.bunnyhop.on and hum.MoveDirection.Magnitude > 0.1 then
        bouncing = true
    end
    if state.criticals.on then
        bouncing = true -- криты = всегда баунсим
    end
    if not bouncing then return end
    if hum.FloorMaterial == Enum.Material.Air then return end

    hum.Jump = true
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
end)

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local function corner(o, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r); c.Parent = o; return c
end
local function tw(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function label(parent, text, size, font, color, x, y, w, h, align)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency=1; l.Text=text; l.TextSize=size; l.Font=font
    l.TextColor3=color; l.Position=UDim2.fromOffset(x,y); l.Size=UDim2.fromOffset(w,h)
    l.TextXAlignment=align or Enum.TextXAlignment.Left; l.Parent=parent; return l
end

local gui = Instance.new("ScreenGui")
gui.Name="ManewareHub"; gui.ResetOnSpawn=false
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
do local s = Instance.new("UIStroke", main); s.Color = C.line; s.Thickness = 1 end
local scale = Instance.new("UIScale", main)
local _vp = getCam().ViewportSize
local baseScale = math.clamp(math.min(_vp.X/660, _vp.Y/440), 0.5, 1)
scale.Scale = baseScale

-- sidebar
local side = Instance.new("Frame")
side.Size = UDim2.new(0, 150, 1, 0)
side.BackgroundColor3 = C.side; side.BorderSizePixel = 0
side.Parent = main
corner(side, 10)
label(side, "MANEWARE", 20, Enum.Font.GothamBlack, ACCENT, 18, 16, 120, 24)
label(side, "strafex edition", 11, Enum.Font.Gotham, C.dim, 18, 40, 130, 14)
local sline = Instance.new("Frame")
sline.Position = UDim2.fromOffset(14,64); sline.Size = UDim2.new(1,-28,0,1)
sline.BackgroundColor3 = C.line; sline.BorderSizePixel = 0; sline.Parent = side

local tabHolder = Instance.new("Frame")
tabHolder.BackgroundTransparency=1
tabHolder.Position = UDim2.fromOffset(10,76)
tabHolder.Size = UDim2.new(1,-20,1,-90)
tabHolder.Parent = side
local tabLayout = Instance.new("UIListLayout", tabHolder)
tabLayout.Padding = UDim.new(0,4)

local content = Instance.new("Frame")
content.BackgroundTransparency=1
content.Position = UDim2.fromOffset(150,0)
content.Size = UDim2.new(1,-150,1,0)
content.Parent = main

local tabTitle = label(content, "", 17, Enum.Font.GothamBold, C.text, 20, 12, 300, 24)
label(content, "INSERT - скрыть", 11, Enum.Font.Gotham, C.dim, 0, 16, 150, 14,
    Enum.TextXAlignment.Right).Position = UDim2.new(1,-164,0,16)

local statusLabel = label(content, "Готово", 12, Enum.Font.Gotham, C.dim, 20, 0, 400, 20)
statusLabel.Position = UDim2.new(0,20,1,-26)

-- notification popup
local notifFrame = Instance.new("Frame")
notifFrame.AnchorPoint = Vector2.new(1,0)
notifFrame.Position = UDim2.new(1,-14,0,14)
notifFrame.AutomaticSize = Enum.AutomaticSize.X
notifFrame.Size = UDim2.fromOffset(0,32)
notifFrame.BackgroundColor3 = C.bg
notifFrame.BackgroundTransparency = 0.05
notifFrame.BorderSizePixel = 0
notifFrame.Visible = false; notifFrame.ZIndex = 10; notifFrame.Parent = gui
corner(notifFrame, 8)
do
    local s = Instance.new("UIStroke", notifFrame); s.Color = ACCENT; s.Thickness = 1.2
    local p = Instance.new("UIPadding", notifFrame)
    p.PaddingLeft, p.PaddingRight = UDim.new(0,12), UDim.new(0,12)
end
local notifLabel = Instance.new("TextLabel")
notifLabel.BackgroundTransparency=1
notifLabel.AutomaticSize = Enum.AutomaticSize.XY
notifLabel.Size = UDim2.fromOffset(0,0)
notifLabel.Font = Enum.Font.GothamMedium
notifLabel.TextSize = 13; notifLabel.TextColor3 = C.text
notifLabel.Text = ""; notifLabel.Parent = notifFrame

local notifToken = 0
notify = function(t)
    statusLabel.Text = t
    pcall(function() notifySound.TimePosition=0; notifySound:Play() end)
    notifToken += 1
    local my = notifToken
    notifLabel.Text = t; notifFrame.Visible = true
    task.delay(2.2, function() if notifToken == my then notifFrame.Visible = false end end)
end

-- drag menu
do
    local dragging, dragStart, startPos
    local function handle(h)
        h.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, i.Position, main.Position
            end
        end)
    end
    local bar = Instance.new("Frame"); bar.BackgroundTransparency=1
    bar.Size = UDim2.new(1,0,0,44); bar.Parent = content; handle(bar)
    local sb = Instance.new("Frame"); sb.BackgroundTransparency=1
    sb.Size = UDim2.new(1,0,0,64); sb.Parent = side; handle(sb)
    bind(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                      startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
           or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- tabs
local pages, tabButtons = {}, {}
local function showTab(name)
    for n, p in pairs(pages) do p.Visible = (n==name) end
    for n, b in pairs(tabButtons) do
        local act = (n==name)
        tw(b.btn, 0.15, { BackgroundTransparency = act and 0 or 1 })
        b.txt.TextColor3 = act and C.text or C.dim
        b.bar.Visible = act
    end
    tabTitle.Text = name
end
local function makeTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,34)
    btn.BackgroundColor3 = C.card; btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false; btn.Text = ""; btn.Parent = tabHolder
    corner(btn,7)
    local bar = Instance.new("Frame")
    bar.Position = UDim2.fromOffset(0,8); bar.Size = UDim2.fromOffset(3,18)
    bar.BackgroundColor3 = ACCENT; bar.BorderSizePixel = 0; bar.Visible = false
    bar.Parent = btn; corner(bar,2)
    local txt = label(btn, name, 14, Enum.Font.GothamMedium, C.dim, 16, 0, 110, 34)
    tabButtons[name] = { btn=btn, txt=txt, bar=bar }
    local page = Instance.new("ScrollingFrame")
    page.BackgroundTransparency=1; page.BorderSizePixel=0
    page.Position = UDim2.fromOffset(16,50)
    page.Size = UDim2.new(1,-32,1,-84)
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = ACCENT
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(); page.Visible = false
    page.Parent = content
    local l = Instance.new("UIListLayout", page); l.Padding = UDim.new(0,8)
    pages[name] = page
    btn.MouseButton1Click:Connect(function() showTab(name) end)
    return page
end

local listeningKey
local function bindText(k)
    return state[k].bind and ("["..state[k].bind.Name.."]") or "[—]"
end

local PIN_NAMES = {
    airstuck="AS", esp3d="3D", esphp="HP", espname="NM",
    speed="SPD", trigger="TRG", aim="AIM", hitsound="HIT",
    criticals="CRT", aura="AUR", surround="SUR", keybind="KEY",
    targetesp="TES", targetstrafe="STR", bunnyhop="BH",
}

local function makeDragButton(text, onTap)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(46,46)
    b.BackgroundColor3 = C.card; b.AutoButtonColor = false
    b.Text = text; b.TextColor3 = C.text
    b.Font = Enum.Font.GothamBold; b.TextSize = 13
    b.ZIndex = 5; b.Parent = gui
    corner(b,23)
    do local s = Instance.new("UIStroke", b); s.Color = ACCENT; s.Thickness = 1.5 end
    local active, moved, startPos, startIn
    b.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch
           or i.UserInputType==Enum.UserInputType.MouseButton1 then
            active, moved, startIn, startPos = i, false, i.Position, b.Position
        end
    end)
    bind(UIS.InputChanged, function(i)
        if not active then return end
        local okT = active.UserInputType==Enum.UserInputType.Touch and i==active
        local okM = active.UserInputType==Enum.UserInputType.MouseButton1
                    and i.UserInputType==Enum.UserInputType.MouseMovement
        if okT or okM then
            local d = i.Position - startIn
            if d.Magnitude > 8 then moved = true end
            if moved then
                b.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                       startPos.Y.Scale, startPos.Y.Offset+d.Y)
            end
        end
    end)
    bind(UIS.InputEnded, function(i)
        if not active then return end
        local okT = active.UserInputType==Enum.UserInputType.Touch and i==active
        local okM = active.UserInputType==Enum.UserInputType.MouseButton1
                    and i.UserInputType==Enum.UserInputType.MouseButton1
        if okT or okM then
            active = nil
            if not moved then onTap() end
        end
    end)
    return b
end

local function togglePin(key)
    if pins[key] then
        pins[key].btn:Destroy(); pins[key] = nil
        ui[key].bindLabel.Text = bindText(key)
        notify("Кнопка убрана: "..key); return
    end
    local n = 0; for _ in pairs(pins) do n += 1 end
    local btn = makeDragButton(PIN_NAMES[key] or key, function() setFeature(key) end)
    btn.Position = UDim2.new(1,-62,0,70+n*54)
    local function refresh()
        local on = state[key].on
        btn.BackgroundColor3 = on and ACCENT or C.card
        btn.TextColor3 = on and Color3.new(1,1,1) or C.text
    end
    refresh()
    pins[key] = { btn=btn, refresh=refresh }
    ui[key].bindLabel.Text = "[BTN]"
    notify("Кнопка: "..key)
end

local function makeSwitch(parent)
    local sw = Instance.new("Frame")
    sw.AnchorPoint = Vector2.new(1,0.5)
    sw.Size = UDim2.fromOffset(38,20)
    sw.BackgroundColor3 = C.off; sw.Parent = parent
    corner(sw,10)
    local k = Instance.new("Frame")
    k.AnchorPoint = Vector2.new(0,0.5)
    k.Position = UDim2.new(0,3,0.5,0)
    k.Size = UDim2.fromOffset(14,14)
    k.BackgroundColor3 = Color3.new(1,1,1)
    k.Parent = sw; corner(k,7)
    local function set(on)
        tw(sw, 0.15, { BackgroundColor3 = on and ACCENT or C.off })
        tw(k, 0.15, { Position = on and UDim2.new(1,-17,0.5,0) or UDim2.new(0,3,0.5,0) })
    end
    return sw, set
end

local function makeFeature(page, key, title, desc, build)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,-8,0,0); card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = C.card; card.BorderSizePixel = 0
    card.Parent = page; corner(card,8)
    do local s = Instance.new("UIStroke", card); s.Color = C.line; s.Thickness = 1 end
    local cl = Instance.new("UIListLayout", card); cl.SortOrder = Enum.SortOrder.LayoutOrder

    local header = Instance.new("TextButton")
    header.LayoutOrder=0; header.Size=UDim2.new(1,0,0,48)
    header.BackgroundTransparency=1; header.AutoButtonColor=false
    header.Text=""; header.Parent=card

    label(header, title, 14, Enum.Font.GothamMedium, C.text, 14, 8, 220, 18)
    label(header, desc..(build and "  •  SET - настройки" or ""), 11, Enum.Font.Gotham, C.dim, 14, 27, 300, 14)

    local bindLabel = label(header, "[—]", 12, Enum.Font.Gotham, C.dim, 0, 0, 80, 16, Enum.TextXAlignment.Right)
    bindLabel.AnchorPoint = Vector2.new(1,0.5)
    bindLabel.Position = UDim2.new(1, build and -108 or -62, 0.5, 0)

    local sw, setVisual = makeSwitch(header)
    sw.Position = UDim2.new(1,-14,0.5,0)

    ui[key] = { set=setVisual, bindLabel=bindLabel }

    local settings
    if build then
        settings = Instance.new("Frame")
        settings.LayoutOrder=1; settings.Size=UDim2.new(1,0,0,0)
        settings.AutomaticSize = Enum.AutomaticSize.Y
        settings.BackgroundTransparency=1; settings.Visible=false
        settings.Parent = card
        local p = Instance.new("UIPadding", settings)
        p.PaddingLeft, p.PaddingRight = UDim.new(0,14), UDim.new(0,14)
        p.PaddingBottom, p.PaddingTop = UDim.new(0,10), UDim.new(0,2)
        local sl = Instance.new("UIListLayout", settings); sl.Padding = UDim.new(0,8)
        build(settings)
    end
    if settings then
        local gear = Instance.new("TextButton")
        gear.AnchorPoint = Vector2.new(1,0.5)
        gear.Position = UDim2.new(1,-62,0.5,0)
        gear.Size = UDim2.fromOffset(40,24)
        gear.BackgroundColor3 = C.off
        gear.Text = "SET"; gear.TextColor3 = C.text
        gear.Font = Enum.Font.GothamBold; gear.TextSize = 11
        gear.Parent = header; corner(gear,6)
        gear.MouseButton1Click:Connect(function() settings.Visible = not settings.Visible end)
    end

    local longFlag, holdToken = false, 0
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            longFlag = false; holdToken += 1
            local my = holdToken
            task.delay(0.5, function()
                if holdToken == my then longFlag = true; togglePin(key) end
            end)
        end
    end)
    header.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then holdToken += 1 end
    end)

    header.MouseButton1Click:Connect(function()
        if longFlag then longFlag = false; return end
        setFeature(key)
    end)
    header.MouseButton2Click:Connect(function()
        if settings then settings.Visible = not settings.Visible end
    end)
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton3 then
            listeningKey = key
            bindLabel.Text = "[...]"; bindLabel.TextColor3 = ACCENT
        end
    end)
end

local function makeSlider(parent, text, minV, maxV, decimals, default, onChange, withDefault)
    local fmt = "%."..decimals.."f"
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,38); f.BackgroundTransparency=1; f.Parent = parent
    local lab = label(f, "", 13, Enum.Font.Gotham, C.text, 0, 0, 220, 18)
    local track = Instance.new("Frame")
    track.Position = UDim2.fromOffset(0,26); track.Size = UDim2.new(1,0,0,6)
    track.BackgroundColor3 = C.off; track.Parent = f; corner(track,3)
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = ACCENT; fill.Size = UDim2.new(0,0,1,0)
    fill.BorderSizePixel = 0; fill.Parent = track; corner(fill,3)
    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5,0.5); knob.Size = UDim2.fromOffset(14,14)
    knob.BackgroundColor3 = Color3.new(1,1,1); knob.Parent = track; corner(knob,7)
    local function set(v)
        local m = 10^decimals
        v = math.clamp(math.floor(v*m+0.5)/m, minV, maxV)
        local a = (v-minV)/(maxV-minV)
        fill.Size = UDim2.new(a,0,1,0)
        knob.Position = UDim2.new(a,0,0.5,0)
        lab.Text = text..": "..string.format(fmt, v)
        onChange(v)
    end
    set(default)
    if withDefault then
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(1,0); b.Position = UDim2.new(1,0,0,0)
        b.Size = UDim2.fromOffset(64,20); b.BackgroundColor3 = ACCENT
        b.Text = "Default"; b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.Parent = f
        corner(b,5)
        b.MouseButton1Click:Connect(function() set(default) end)
    end
    local sliding = false
    local function update(x)
        local a = math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X, 0, 1)
        set(minV + a*(maxV-minV))
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
           or i.UserInputType==Enum.UserInputType.Touch then
            sliding = true; update(i.Position.X)
        end
    end)
    bind(UIS.InputChanged, function(i)
        if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement
            or i.UserInputType==Enum.UserInputType.Touch) then update(i.Position.X) end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
           or i.UserInputType==Enum.UserInputType.Touch then sliding = false end
    end)
end

local function makeToggle(parent, text, default, onChange)
    local f = Instance.new("TextButton")
    f.Size = UDim2.new(1,0,0,24); f.BackgroundTransparency=1
    f.AutoButtonColor=false; f.Text=""; f.Parent = parent
    label(f, text, 13, Enum.Font.Gotham, C.text, 0, 0, 260, 24)
    local sw, setV = makeSwitch(f)
    sw.Position = UDim2.new(1,0,0.5,0)
    local v = default; setV(v); onChange(v)
    f.MouseButton1Click:Connect(function() v = not v; setV(v); onChange(v) end)
end

local function makeCycle(parent, text, options, default, onChange)
    local f = Instance.new("TextButton")
    f.Size = UDim2.new(1,0,0,26); f.BackgroundColor3 = C.off
    f.AutoButtonColor = true; f.TextColor3 = C.text
    f.Font = Enum.Font.GothamMedium; f.TextSize = 13
    f.Parent = parent; corner(f,6)
    local idx = table.find(options, default) or 1
    local function refresh() f.Text = text..": "..options[idx] end
    refresh(); onChange(options[idx])
    f.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        refresh(); onChange(options[idx])
    end)
end

local pageCombat  = makeTab("Combat")
local pageVisuals = makeTab("Visuals")
local pageMove    = makeTab("Movement")
local pageMisc    = makeTab("Misc")

makeFeature(pageCombat, "trigger", "TriggerBot", "Бьёт под прицелом", function(s)
    makeToggle(s, "Crits (только в прыжке)", false, function(v) cfg.crits = v end)
    makeToggle(s, "Cooldown", true, function(v) cfg.useCooldown = v end)
    makeSlider(s, "Cooldown (сек)", 0.5, 3, 1, 1, function(v) cfg.cooldown = v end)
end)
makeFeature(pageCombat, "aim", "AimAssist", "Наведение", function(s)
    makeToggle(s, "Focus (держать цель)", false, function(v) cfg.focus = v end)
    makeSlider(s, "Smooth", 0.1, 5, 1, 1, function(v) cfg.smooth = v end)
    makeSlider(s, "Range (блоки)", 1, 6, 1, 3, function(v) cfg.range = v end)
end)
makeFeature(pageCombat, "criticals", "Criticals", "Авто-баунс (криты при ударах)", function(s)
    makeSlider(s, "Jump", 0.1, 2, 1, 1, function(v) cfg.critJump = v end, true)
end)
makeFeature(pageCombat, "aura", "AttackAura", "Авто-атака + кружение", function(s)
    makeSlider(s, "Cooldown (MC)", 0.1, 5, 1, 1.6, function(v) cfg.auraCooldown = v end)
    makeToggle(s, "Attack Block", false, function(v) cfg.auraBlock = v end)
    makeSlider(s, "Range (блоки)", 1, 6, 1, 3, function(v) cfg.auraRange = v end)
    makeToggle(s, "Free (двигаться свободно)", false, function(v) cfg.auraFree = v end)
    makeToggle(s, "Respect Input (WASD приоритет)", false, function(v) cfg.auraRespectInput = v end)
    makeToggle(s, "Crits (только в прыжке)", false, function(v) cfg.auraCrits = v end)
end)
makeFeature(pageCombat, "targetstrafe", "TargetStrafe", "Кружит возле цели", function(s)
    makeSlider(s, "Speed", 1, 40, 0, 12, function(v) cfg.strafeSpeed = v end)
    makeSlider(s, "Range (стады)", 1, 10, 1, 4, function(v) cfg.strafeRange = v end)
end)
makeFeature(pageCombat, "hitsound", "HitSound", "Звук при ударе", function(s)
    makeSlider(s, "Громкость", 0.5, 10, 1, 3, function(v) cfg.hitVolume = v end)
end)

makeFeature(pageVisuals, "esp3d",   "ESP 3D",   "3D бокс")
makeFeature(pageVisuals, "esphp",   "ESP HP",   "Полоска здоровья")
makeFeature(pageVisuals, "espname", "ESP Name", "Имя над боксом")
makeFeature(pageVisuals, "keybind", "Keybinds", "Список биндов", function(s)
    makeToggle(s, "Only enabled", false, function(v) cfg.kbOnlyOn = v end)
end)
makeFeature(pageVisuals, "targetesp", "TargetESP", "Куб на теле цели", function(s)
    makeToggle(s, "Marker (острые)", true,  function(v) cfg.tgMarker  = v end)
    makeToggle(s, "Marker-2 (скруглён)",false,function(v) cfg.tgMarker2 = v end)
    makeToggle(s, "Only AttackAura", false, function(v) cfg.tgOnlyAura = v end)
end)

makeFeature(pageMove, "airstuck", "Airstuck", "Заморозка в воздухе/на земле")
makeFeature(pageMove, "speed", "Speed", "Ускорение", function(s)
    makeCycle(s, "Режим", { "WalkSpeed", "Velocity", "CFrame" }, "WalkSpeed",
        function(v) cfg.speedMode = v end)
    makeSlider(s, "Скорость", 8, 100, 0, 40, function(v) cfg.speed = v end, true)
end)
makeFeature(pageMove, "bunnyhop", "BunnyHop", "Авто-прыжок при движении")

makeFeature(pageMisc, "surround", "Surround", "Трапает ближайшего игрока блоками (ПКМ)")

showTab("Combat")

local function overMenu()
    if not main.Visible then return false end
    local p, s = main.AbsolutePosition, main.AbsoluteSize
    local mp = UIS:GetMouseLocation()
    return mp.X >= p.X and mp.X <= p.X+s.X and mp.Y >= p.Y and mp.Y <= p.Y+s.Y
end
local function setOpen(o)
    if o then
        main.Visible = true
        scale.Scale = baseScale*0.94
        tw(scale, 0.15, { Scale = baseScale })
    else
        tw(scale, 0.12, { Scale = baseScale*0.94 })
        task.delay(0.12, function()
            if scale.Scale < baseScale*0.99 then main.Visible = false end
        end)
    end
end
local menuOpen = true

if IS_TOUCH then
    local mb = makeDragButton("MENU", function() menuOpen = not menuOpen; setOpen(menuOpen) end)
    mb.TextSize = 11; mb.Position = UDim2.new(0,14,0,70)
end

----------------------------------------------------------------
-- Input: INSERT + бинды
----------------------------------------------------------------
bind(UIS.InputBegan, function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if listeningKey then
        local k = listeningKey; listeningKey = nil
        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
            state[k].bind = nil
        elseif input.KeyCode ~= Enum.KeyCode.Insert then
            state[k].bind = input.KeyCode
        end
        ui[k].bindLabel.Text = bindText(k)
        ui[k].bindLabel.TextColor3 = C.dim
        return
    end
    if input.KeyCode == Enum.KeyCode.Insert then
        menuOpen = not menuOpen; setOpen(menuOpen); return
    end
    if processed then return end
    for key, s in pairs(state) do
        if s.bind and s.bind == input.KeyCode then setFeature(key) end
    end
end)

----------------------------------------------------------------
-- TriggerBot
----------------------------------------------------------------
local function rayBox(origin, dir, cf, size)
    local o = cf:PointToObjectSpace(origin)
    local d = cf:VectorToObjectSpace(dir)
    local h = size/2
    local tmin, tmax = -math.huge, math.huge
    for _, ax in ipairs({"X","Y","Z"}) do
        local oa, da, ha = o[ax], d[ax], h[ax]
        if math.abs(da) < 1e-6 then
            if math.abs(oa) > ha then return nil end
        else
            local t1, t2 = (-ha-oa)/da, (ha-oa)/da
            if t1 > t2 then t1, t2 = t2, t1 end
            tmin = math.max(tmin, t1); tmax = math.min(tmax, t2)
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
        if tool then pcall(function() tool:Activate() end); return end
        local vp = getCam().ViewportSize
        VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 0)
        VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 0); return
    end
    if mouse1click then pcall(mouse1click)
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
    if cfg.crits and not isAir(hum) then return end
    local now = os.clock()
    local interval = cfg.useCooldown and cfg.cooldown or 0.05
    if now - lastHit < interval then return end
    local cam = getCam()
    local loc = IS_TOUCH and (cam.ViewportSize/2) or UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(loc.X, loc.Y)
    local dir = ray.Direction.Unit
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        if th and th.Health > 0 then
            local cf, sz = ch:GetBoundingBox()
            if (cf.Position - root.Position).Magnitude <= TRIG_RANGE and rayBox(ray.Origin, dir, cf, sz) then
                lastHit = now; clickMouse(); return
            end
        end
    end
end)

----------------------------------------------------------------
-- AimAssist
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
    if not state.aim.on then focusPlr = nil; return end
    local root = getRoot(); if not root then return end
    local cam = getCam()
    local maxDist = cfg.range * BLOCK
    local part
    if cfg.focus and focusPlr then
        local p = targetPart(focusPlr)
        if p and (p.Position-root.Position).Magnitude <= maxDist then part = p
        else focusPlr = nil end
    end
    if not cfg.focus then focusPlr = nil end
    if not part then
        local bestAng = math.huge
        local camPos, camLook = cam.CFrame.Position, cam.CFrame.LookVector
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp then
                local p = targetPart(plr)
                if p and (p.Position-root.Position).Magnitude <= maxDist then
                    local dirTo = (p.Position-camPos).Unit
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
        local targetCF = CFrame.lookAt(cam.CFrame.Position, part.Position, Vector3.new(0,1,0))
        local alpha = math.clamp(dt*10/cfg.smooth, 0, 1)
        cam.CFrame = cam.CFrame:Lerp(targetCF, alpha)
    end
end)

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------
local esp = {}
local function newLine(t,c) local l=Drawing.new("Line"); l.Thickness=t; l.Color=c; l.Visible=false; return l end
local function createESP(plr)
    local o = { box={}, hpBg=newLine(4, Color3.new(0,0,0)), hp=newLine(2, Color3.new(0,1,0)) }
    for i=1,12 do o.box[i] = newLine(1.5, ACCENT) end
    o.name = Drawing.new("Text"); o.name.Size=14; o.name.Center=true; o.name.Outline=true
    o.name.Color = Color3.new(1,1,1); o.name.Visible = false
    esp[plr] = o
end
local function hideESP(o)
    for _, l in ipairs(o.box) do l.Visible=false end
    o.hpBg.Visible=false; o.hp.Visible=false; o.name.Visible=false
end
local function removeESP(plr)
    local o = esp[plr]; if not o then return end
    for _, l in ipairs(o.box) do l:Remove() end
    o.hpBg:Remove(); o.hp:Remove(); o.name:Remove()
    esp[plr] = nil
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= lp then createESP(p) end end
bind(Players.PlayerAdded,    function(p) if p ~= lp then createESP(p) end end)
bind(Players.PlayerRemoving, removeESP)

local edges = {}
for i=0,7 do for _, b in ipairs({1,2,4}) do
    if bit32.band(i,b)==0 then table.insert(edges, {i+1, i+b+1}) end
end end

bind(RunService.RenderStepped, function()
    local cam = getCam()
    local any = state.esp3d.on or state.esphp.on or state.espname.on
    for plr, o in pairs(esp) do
        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not (any and char and hum and hum.Health > 0) then hideESP(o)
        else
            local cf, sz = char:GetBoundingBox()
            local pts, ok = {}, true
            local minX,minY,maxX,maxY = math.huge,math.huge,-math.huge,-math.huge
            for i=0,7 do
                local x = (bit32.band(i,1)~=0) and 1 or -1
                local y = (bit32.band(i,2)~=0) and 1 or -1
                local z = (bit32.band(i,4)~=0) and 1 or -1
                local world = cf * CFrame.new(x*sz.X/2, y*sz.Y/2, z*sz.Z/2)
                local v = cam:WorldToViewportPoint(world.Position)
                if v.Z <= 0 then ok = false; break end
                pts[i+1] = Vector2.new(v.X, v.Y)
                minX = math.min(minX, v.X); minY = math.min(minY, v.Y)
                maxX = math.max(maxX, v.X); maxY = math.max(maxY, v.Y)
            end
            if not ok then hideESP(o)
            else
                for i, e in ipairs(edges) do
                    local l = o.box[i]
                    if state.esp3d.on then l.From, l.To, l.Visible = pts[e[1]], pts[e[2]], true
                    else l.Visible = false end
                end
                if state.esphp.on then
                    local frac = math.clamp(hum.Health/math.max(hum.MaxHealth,1), 0, 1)
                    local x = minX - 6
                    o.hpBg.From = Vector2.new(x, maxY+1); o.hpBg.To = Vector2.new(x, minY-1)
                    o.hpBg.Visible = true
                    o.hp.From = Vector2.new(x, maxY); o.hp.To = Vector2.new(x, maxY-(maxY-minY)*frac)
                    o.hp.Color = Color3.fromHSV(frac*0.33, 1, 1); o.hp.Visible = true
                else o.hpBg.Visible, o.hp.Visible = false, false end
                if state.espname.on then
                    o.name.Text = plr.Name
                    o.name.Position = Vector2.new((minX+maxX)/2, minY-18)
                    o.name.Visible = true
                else o.name.Visible = false end
            end
        end
    end
end)

----------------------------------------------------------------
-- HitSound
----------------------------------------------------------------
local hitSound = Instance.new("Sound")
hitSound.Name="ManewareHit"; hitSound.SoundId=HITSOUND_ID; hitSound.Parent = SoundService
bind(UIS.InputBegan, function(i, processed)
    if i.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
        lastAttack = os.clock()
    end
end)
local lastHP = setmetatable({}, {__mode="k"})
bind(RunService.Heartbeat, function()
    local root = getRoot()
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        if th then
            local prev = lastHP[th]; lastHP[th] = th.Health
            if state.hitsound.on and prev and th.Health < prev and root then
                local tr = th.RootPart or ch:FindFirstChild("HumanoidRootPart")
                if tr and (IS_TOUCH or os.clock()-lastAttack <= 0.6)
                   and (tr.Position-root.Position).Magnitude <= TRIG_RANGE+5 then
                    hitSound.Volume = cfg.hitVolume
                    hitSound.TimePosition = 0; hitSound:Play()
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- Criticals (множитель прыжка)
----------------------------------------------------------------
local jumpBase = nil
local function restoreJump()
    local hum = getHum()
    if jumpBase and hum then
        if jumpBase.usePower then pcall(function() hum.JumpPower = jumpBase.jp end)
        else pcall(function() hum.JumpHeight = jumpBase.jh end) end
    end
    jumpBase = nil
end
hooks.criticals = function(on) if not on then restoreJump() end end
bind(RunService.Heartbeat, function()
    if not state.criticals.on or state.airstuck.on then return end
    local hum = getHum(); if not hum then return end
    if not jumpBase then
        jumpBase = { jp=hum.JumpPower, jh=hum.JumpHeight, usePower=hum.UseJumpPower }
    end
    if jumpBase.usePower then
        pcall(function() hum.JumpPower = jumpBase.jp * cfg.critJump end)
    else
        pcall(function() hum.JumpHeight = jumpBase.jh * cfg.critJump end)
    end
end)

----------------------------------------------------------------
-- AttackAura + Circle
----------------------------------------------------------------
local auraBusy, lastAura = false, 0
local auraCurrent = nil
local aimOverride, aimUntil = nil, 0

local function findTarget(maxDist)
    local root = getRoot(); if not root then return nil end
    local best, bestRoot, bestD
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        local tr = th and th.Health > 0 and (th.RootPart or ch:FindFirstChild("HumanoidRootPart"))
        if tr then
            local d = (tr.Position-root.Position).Magnitude
            if d <= maxDist and (not bestD or d < bestD) then best, bestRoot, bestD = ch, tr, d end
        end
    end
    return best, bestRoot, bestD
end

local function obstructions(ch, aimPos)
    local origin = getCam().CFrame.Position
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    local filter = { lp.Character }; p.FilterDescendantsInstances = filter
    local list = {}
    for _=1,12 do
        local res = workspace:Raycast(origin, aimPos-origin, p)
        if not res or res.Instance:IsDescendantOf(ch) then break end
        list[#list+1] = res.Instance
        filter[#filter+1] = res.Instance
        p.FilterDescendantsInstances = filter
    end
    return list
end

local function inMenu(loc)
    if not main.Visible then return false end
    local p, s = main.AbsolutePosition, main.AbsoluteSize
    local inset = GuiService:GetGuiInset().Y
    return loc.X>=p.X and loc.X<=p.X+s.X and loc.Y>=p.Y+inset and loc.Y<=p.Y+s.Y+inset
end

local function clickAt(loc)
    if IS_TOUCH then clickMouse(); return end
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
        if not (tr and tr.Parent) then return end
        local aimPos = tr.Position
        local blockers = obstructions(ch, aimPos)
        if #blockers > 0 then
            if not cfg.auraBlock then return end
            for _, part in ipairs(blockers) do
                if part.CanQuery then part.CanQuery = false; restore[#restore+1] = part end
            end
        end
        -- Мгновенный снап камеры в момент удара
        aimOverride, aimUntil = aimPos, os.clock() + 0.25
        local cam = getCam()
        pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPos, Vector3.new(0,1,0)) end)
        RunService.RenderStepped:Wait()
        local v = cam:WorldToViewportPoint(aimPos)
        local loc = Vector2.new(v.X, v.Y)
        if IS_TOUCH then
            if not main.Visible then clickAt(loc) end
        elseif not inMenu(loc) then
            clickAt(loc)
        end
        task.wait(0.04)
    end)
    for _, part in ipairs(restore) do pcall(function() part.CanQuery = true end) end
    auraBusy = false
end

bind(RunService.Heartbeat, function()
    if not state.aura.on or auraBusy or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not (hum and root and hum.Health > 0) then return end
    if os.clock() - lastAura < 1/cfg.auraCooldown then return end
    local ch, tr = findTarget(cfg.auraRange * BLOCK)
    if not ch then return end
    if cfg.auraCrits and not isAir(hum) and not state.criticals.on then return end
    lastAura = os.clock()
    task.spawn(doAttack, ch, tr)
end)

-- Кружение + взгляд на цель (плавно, без инверсии)
RunService:BindToRenderStep("ManewareAura", Enum.RenderPriority.Last.Value, function(dt)
    auraCurrent = nil
    if not state.aura.on or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not (hum and root and hum.Health > 0) then return end
    local cam = getCam()
    local reach = cfg.auraRange * BLOCK
    local ch, tr, dist = findTarget(reach)
    auraCurrent = ch

    -- Камера: если сейчас момент удара - жёсткий снап, иначе плавный lerp
    if aimOverride and os.clock() < aimUntil then
        pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimOverride, Vector3.new(0,1,0)) end)
    elseif ch and not cfg.auraFree then
        local targetCF = CFrame.lookAt(cam.CFrame.Position, tr.Position, Vector3.new(0,1,0))
        cam.CFrame = cam.CFrame:Lerp(targetCF, math.clamp(dt*15, 0, 1))
    end

    -- Кружение вокруг цели (стабильный тангенс = никогда не инвертируется)
    if ch and not cfg.auraFree and not state.targetstrafe.on then
        local toT = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
        local d = toT.Magnitude
        if d < 0.1 then return end
        local dirTo = toT.Unit
        local tangent = Vector3.new(-dirTo.Z, 0, dirTo.X) -- всегда против часовой
        local radius = math.clamp(reach * 0.28, 2.8, 4.5)

        local mv
        if cfg.auraRespectInput then
            -- игрок управляет, кружим только когда стоит
            local input = moveDir()
            if input.Magnitude > 0.1 then mv = input
            else mv = tangent end
        else
            if d > radius + 1.5 then mv = dirTo                       -- подойти
            elseif d < radius - 1.5 then mv = tangent - dirTo * 0.3   -- отойти
            else mv = tangent end                                     -- кружить
        end
        if mv.Magnitude > 0.05 then hum:Move(mv.Unit, false) end

        -- Crits в прыжке, если Criticals выкл
        if cfg.auraCrits and not state.criticals.on and dist <= reach + 2 and not isAir(hum) then
            hum.Jump = true
        end
    end
end)

----------------------------------------------------------------
-- Surround: реальные блоки из инструмента (ПКМ)
----------------------------------------------------------------
local surroundToken = 0
local function clearSurround() surroundToken += 1 end

local function aimAt(worldPos)
    local cam = getCam()
    pcall(function() cam.CFrame = CFrame.lookAt(cam.CFrame.Position, worldPos, Vector3.new(0,1,0)) end)
    RunService.RenderStepped:Wait()
    return cam:WorldToViewportPoint(worldPos)
end

local function rightClick(worldPos)
    local vp = aimAt(worldPos)
    if vp.Z <= 0 then return end
    if IS_TOUCH then
        local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    else
        VIM:SendMouseMoveEvent(vp.X, vp.Y, game)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(vp.X, vp.Y, 1, true, game, 0)
        task.wait(0.01)
        VIM:SendMouseButtonEvent(vp.X, vp.Y, 1, false, game, 0)
    end
    task.wait(0.05)
end

local function buildSurroundOthers()
    local myRoot = getRoot()
    if not myRoot then notify("Surround: персонаж не найден"); return end
    local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
    if not tool then notify("Surround: возьми блок в руку!"); return end

    local target, targetRoot, bestD
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp then
            local ch = plr.Character
            local th = ch and ch:FindFirstChildOfClass("Humanoid")
            local tr = th and th.Health > 0 and (th.RootPart or ch:FindFirstChild("HumanoidRootPart"))
            if tr then
                local d = (tr.Position-myRoot.Position).Magnitude
                if not bestD or d < bestD then target, targetRoot, bestD = plr, tr, d end
            end
        end
    end
    if not target then notify("Surround: нет цели"); return end

    local my = surroundToken
    local hum = getHum()

    -- подойти поближе
    local tries = 0
    while tries < 160 and surroundToken == my do
        local rp = getRoot(); if not rp then break end
        local rel = targetRoot.Position - rp.Position
        if rel.Magnitude <= BLOCK * 3.5 then break end
        if hum then hum:Move(rel.Unit, false) end
        task.wait(0.05); tries += 1
    end
    if surroundToken ~= my then return end

    local tp = targetRoot.Position

    -- Найти землю под целью
    local rayP = RaycastParams.new()
    rayP.FilterType = Enum.RaycastFilterType.Exclude
    rayP.FilterDescendantsInstances = { lp.Character, target.Character }
    local down = workspace:Raycast(tp, Vector3.new(0, -60, 0), rayP)
    local groundY = down and down.Position.Y or (tp.Y - 3)

    -- Слои снизу вверх: сначала на землю рядом с целью, потом на тело цели
    for layer = 0, 2 do
        for dx = -1, 1 do
            for dz = -1, 1 do
                if dx ~= 0 or dz ~= 0 then
                    if surroundToken ~= my then return end
                    -- Первый слой - точно на землю. Верхние - в тело.
                    local pos = Vector3.new(
                        tp.X + dx * BLOCK,
                        layer == 0 and (groundY + 0.5) or (tp.Y + layer * BLOCK),
                        tp.Z + dz * BLOCK
                    )
                    rightClick(pos)
                end
            end
        end
    end
    -- Крышка
    for dx = -1, 1 do
        for dz = -1, 1 do
            if surroundToken ~= my then return end
            rightClick(Vector3.new(tp.X + dx * BLOCK, tp.Y + 3 * BLOCK, tp.Z + dz * BLOCK))
        end
    end
    notify("Surround: готово")
end

hooks.surround = function(on)
    if on then task.spawn(buildSurroundOthers) else clearSurround() end
end

bind(lp.CharacterAdded, function()
    jumpBase = nil
    if state.surround.on then setFeature("surround", false) end
end)

----------------------------------------------------------------
-- TargetStrafe
----------------------------------------------------------------
bind(RunService.Heartbeat, function()
    if not state.targetstrafe.on or state.airstuck.on then return end
    local hum, root = getHum(), getRoot()
    if not (hum and root and hum.Health > 0) then return end
    local ch, tr = findTarget(80)
    if not ch then return end
    local radius = cfg.strafeRange
    local tp, rp = tr.Position, root.Position
    local rel = Vector3.new(rp.X - tp.X, 0, rp.Z - tp.Z)
    local ang = rel.Magnitude > 0.01 and math.atan2(rel.Z, rel.X) or 0
    local lead = math.clamp(cfg.strafeSpeed * 0.08 / radius, 0.12, 1.2)
    local goal = Vector3.new(tp.X + math.cos(ang + lead) * radius, 0,
                             tp.Z + math.sin(ang + lead) * radius)
    local mv = goal - Vector3.new(rp.X, 0, rp.Z)
    if mv.Magnitude > 0.05 then
        hum:Move(mv.Unit, false)
        -- Дополнительная скорость
        local v = root.AssemblyLinearVelocity
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(mv.Unit.X * cfg.strafeSpeed, v.Y, mv.Unit.Z * cfg.strafeSpeed)
        end)
    end
end)

----------------------------------------------------------------
-- Keybinds (крупные, перетаскиваемые)
----------------------------------------------------------------
local KB_ORDER = {
    "airstuck","esp3d","esphp","espname","speed","trigger","aim","hitsound",
    "criticals","aura","targetstrafe","targetesp","surround","bunnyhop",
}
local KB_NAMES = {
    airstuck="airstuck", esp3d="esp 3d", esphp="esp hp", espname="esp name",
    speed="speed", trigger="triggerbot", aim="aimassist", hitsound="hitsound",
    criticals="criticals", aura="attackaura", targetstrafe="targetstrafe",
    targetesp="targetesp", surround="surround", bunnyhop="bunnyhop",
}

local kbFrame = Instance.new("Frame")
kbFrame.Name="Keybinds"
kbFrame.Position = UDim2.new(0,14,0.35,0)
kbFrame.AutomaticSize = Enum.AutomaticSize.XY
kbFrame.Size = UDim2.fromOffset(0,0)
kbFrame.BackgroundColor3 = C.bg
kbFrame.BackgroundTransparency = 0.1
kbFrame.BorderSizePixel = 0
kbFrame.Visible = false; kbFrame.Active = true
kbFrame.Parent = gui; corner(kbFrame, 10)
do
    local s = Instance.new("UIStroke", kbFrame); s.Color = ACCENT; s.Thickness = 1.2
    local p = Instance.new("UIPadding", kbFrame)
    p.PaddingLeft, p.PaddingRight = UDim.new(0,14), UDim.new(0,14)
    p.PaddingTop,  p.PaddingBottom= UDim.new(0,10), UDim.new(0,10)
end
local kbLabel = Instance.new("TextLabel")
kbLabel.BackgroundTransparency=1
kbLabel.AutomaticSize = Enum.AutomaticSize.XY
kbLabel.Size = UDim2.fromOffset(0,0)
kbLabel.RichText = true
kbLabel.Font = Enum.Font.GothamBold
kbLabel.TextSize = 16
kbLabel.LineHeight = 1.3
kbLabel.TextColor3 = C.text
kbLabel.TextXAlignment = Enum.TextXAlignment.Left
kbLabel.TextYAlignment = Enum.TextYAlignment.Top
kbLabel.Text = ""; kbLabel.Parent = kbFrame

do -- drag
    local dragging, dragStart, startPos
    kbFrame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
           or i.UserInputType==Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, kbFrame.Position
        end
    end)
    bind(UIS.InputChanged, function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement
            or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            kbFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                         startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    bind(UIS.InputEnded, function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
           or i.UserInputType==Enum.UserInputType.Touch then dragging = false end
    end)
end

local kbLast, kbText = 0, ""
bind(RunService.Heartbeat, function()
    if not state.keybind.on then kbFrame.Visible = false; return end
    if os.clock() - kbLast < 0.1 then return end
    kbLast = os.clock()
    local lines = {}
    for _, k in ipairs(KB_ORDER) do
        local s = state[k]
        if s and s.bind and (s.on or not cfg.kbOnlyOn) then
            local tag = s.on and '<font color="#00d27a">[ON]</font>' or '<font color="#7583a3">[off]</font>'
            lines[#lines+1] = string.format('<b>%s</b> <font color="#5b6b8a">[%s]</font> %s',
                KB_NAMES[k] or k, s.bind.Name:lower(), tag)
        end
    end
    local text = table.concat(lines, "\n")
    if text ~= kbText then kbText = text; kbLabel.Text = text end
    kbFrame.Visible = #lines > 0
end)

----------------------------------------------------------------
-- TargetESP (маленький куб на теле)
----------------------------------------------------------------
local MARK_LINES = 160
local markLines = {}
for i=1,MARK_LINES do markLines[i] = newLine(2, ACCENT) end
local function hideMarker() for i=1,MARK_LINES do markLines[i].Visible=false end end

local function crosshairTarget()
    local cam = getCam()
    local loc = IS_TOUCH and (cam.ViewportSize/2) or UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(loc.X, loc.Y)
    local dir = ray.Direction.Unit
    local best, bestT
    for _, plr in ipairs(Players:GetPlayers()) do
        local ch = plr ~= lp and plr.Character
        local th = ch and ch:FindFirstChildOfClass("Humanoid")
        if th and th.Health > 0 then
            local cf, sz = ch:GetBoundingBox()
            local t = rayBox(ray.Origin, dir, cf, sz)
            if t and (not bestT or t < bestT) then best, bestT = ch, t end
        end
    end
    return best
end

local SIGNS = {}
for i=0,7 do
    SIGNS[i+1] = {
        (bit32.band(i,1)~=0) and 1 or -1,
        (bit32.band(i,2)~=0) and 1 or -1,
        (bit32.band(i,4)~=0) and 1 or -1,
    }
end

bind(RunService.RenderStepped, function()
    if not state.targetesp.on or not (cfg.tgMarker or cfg.tgMarker2) then hideMarker(); return end
    local ch
    if cfg.tgOnlyAura then ch = state.aura.on and auraCurrent or nil
    else ch = (state.aura.on and auraCurrent) or crosshairTarget() end
    local th = ch and ch:FindFirstChildOfClass("Humanoid")
    if not (th and th.Health > 0) then hideMarker(); return end

    local cam = getCam()
    local cf, sz = ch:GetBoundingBox()
    local center = cf.Position
    -- Маленький куб (плотно по телу)
    local h = math.max(1.2, sz.Y * 0.42)  -- меньше прежнего
    local ang = -os.clock() * 0.9
    local c, sn = math.cos(ang), math.sin(ang)

    local function corner3(i)
        local g = SIGNS[i]
        local x, y, z = g[1]*h, g[2]*h, g[3]*h
        return Vector3.new(x*c + z*sn, y, -x*sn + z*c)
    end
    local n = 0
    local function seg(a, b)
        n += 1
        local l = markLines[n]; if not l then return end
        local va, vb = cam:WorldToViewportPoint(center+a), cam:WorldToViewportPoint(center+b)
        if va.Z <= 0 or vb.Z <= 0 then l.Visible = false
        else l.From, l.To, l.Visible = Vector2.new(va.X, va.Y), Vector2.new(vb.X, vb.Y), true end
    end
    local rounded = cfg.tgMarker2
    local LEN, R = 0.4, 0.18
    for i=1,8 do
        local v = corner3(i)
        local es = {}
        for k=1,3 do
            local sg = { SIGNS[i][1], SIGNS[i][2], SIGNS[i][3] }; sg[k] = -sg[k]
            local g = { sg[1]*h, sg[2]*h, sg[3]*h }
            local nv = Vector3.new(g[1]*c + g[3]*sn, g[2], -g[1]*sn + g[3]*c)
            es[k] = nv - v
        end
        for k=1,3 do seg(v + es[k]*(rounded and R or 0), v + es[k]*LEN) end
        if rounded then
            local pairsIdx = {{1,2},{1,3},{2,3}}
            for _, pr in ipairs(pairsIdx) do
                local A, B = v + es[pr[1]]*R, v + es[pr[2]]*R
                local prev = A
                for st=1,4 do
                    local t = st/4
                    local pt = A*(1-t)^2 + v*(2*(1-t)*t) + B*(t*t)
                    seg(prev, pt); prev = pt
                end
            end
        end
    end
    for i=n+1,MARK_LINES do markLines[i].Visible = false end
end)

----------------------------------------------------------------
-- Unload
----------------------------------------------------------------
env.ManewareUnload = function()
    if state.airstuck.on then pcall(applyAirstuck, false) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() RunService:UnbindFromRenderStep("ManewareAim")  end)
    pcall(function() RunService:UnbindFromRenderStep("ManewarePin")  end)
    pcall(function() RunService:UnbindFromRenderStep("ManewareAura") end)
    pcall(restoreJump)
    for _, l in ipairs(markLines) do pcall(function() l:Remove() end) end
    pcall(function() kbFrame:Destroy() end)
    pcall(clearSurround)
    for plr in pairs(esp) do pcall(removeESP, plr) end
    pcall(function() gui:Destroy() end)
    pcall(function() hitSound:Destroy() end)
    pcall(function() notifySound:Destroy() end)
end

notify("Загружено. INSERT - меню")
