--// Starfex Hub v2 | RightShift - открыть/закрыть меню
--// ЛКМ по функции - вкл/выкл | ПКМ - настройки | СКМ (колёсико) - назначить бинд

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("StarfexHub") then parentGui.StarfexHub:Destroy() end
pcall(function() RunService:UnbindFromRenderStep("StarfexAim") end)

local ACCENT = Color3.fromRGB(130, 90, 255)
local BG = Color3.fromRGB(20, 20, 28)
local ROW = Color3.fromRGB(32, 32, 44)
local PANEL = Color3.fromRGB(26, 26, 36)
local OFF = Color3.fromRGB(70, 70, 88)
local GREY = Color3.fromRGB(150, 150, 170)

local BLOCK = 4          -- 1 "блок" = 4 стада (поменяй если нужно)
local TRIG_RANGE = 20    -- макс. дистанция для triggerbot (в стадах)

----------------------------------------------------------------
-- Состояние и настройки
----------------------------------------------------------------
local state = {
    airstuck = { on = false, bind = nil },
    esp3d    = { on = false, bind = nil },
    esphp    = { on = false, bind = nil },
    espname  = { on = false, bind = nil },
    speed    = { on = false, bind = nil },
    trigger  = { on = false, bind = nil },
    aim      = { on = false, bind = nil },
}
local cfg = {
    speed = 16,
    crits = false,
    useCooldown = true,
    cooldown = 1,
    smooth = 1,
    range = 3,
}
local ui = {}

local function getChar() return lp.Character end
local function getHRP() return lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") end
local function getHum() return lp.Character and lp.Character:FindFirstChildOfClass("Humanoid") end

----------------------------------------------------------------
-- Airstuck (позиция закрепляется каждый физ. шаг, скорость сохраняется)
----------------------------------------------------------------
local pinCF, savedVel, savedAng

local function applyAirstuck(on)
    local hrp = getHRP()
    if on then
        if not hrp then return false end
        pinCF = hrp.CFrame
        savedVel = hrp.AssemblyLinearVelocity
        savedAng = hrp.AssemblyAngularVelocity
        return true
    else
        if hrp then
            hrp.AssemblyLinearVelocity = savedVel or Vector3.zero
            hrp.AssemblyAngularVelocity = savedAng or Vector3.zero
        end
        pinCF, savedVel, savedAng = nil, nil, nil
        return true
    end
end

local function pin()
    if state.airstuck.on and pinCF then
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = pinCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end
RunService.Stepped:Connect(pin)
RunService.Heartbeat:Connect(pin)
RunService.RenderStepped:Connect(pin)

----------------------------------------------------------------
-- Переключение функций
----------------------------------------------------------------
local function setFeature(key, value)
    local s = state[key]
    if value == nil then value = not s.on end
    if key == "airstuck" then
        if not applyAirstuck(value) then value = false end
    end
    s.on = value
    local u = ui[key]
    if u then
        TweenService:Create(u.pill, TweenInfo.new(0.15), { BackgroundColor3 = value and ACCENT or OFF }):Play()
        u.pill.Text = value and "ON" or "OFF"
    end
end

lp.CharacterAdded:Connect(function()
    pinCF, savedVel, savedAng = nil, nil, nil
    if state.airstuck.on then setFeature("airstuck", false) end
end)

----------------------------------------------------------------
-- Speed (WalkSpeed + принудительная скорость, если игра сбрасывает WalkSpeed)
----------------------------------------------------------------
local speedWasOn = false
RunService.Heartbeat:Connect(function()
    local hum, hrp = getHum(), getHRP()
    if not (hum and hrp) then return end
    if state.speed.on then
        speedWasOn = true
        hum.WalkSpeed = cfg.speed
        if not state.airstuck.on then
            local md = hum.MoveDirection
            if md.Magnitude > 0 then
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(md.X * cfg.speed, v.Y, md.Z * cfg.speed)
            end
        end
    elseif speedWasOn then
        hum.WalkSpeed = 16
        speedWasOn = false
    end
end)

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "StarfexHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
gui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(310, 0)
main.AutomaticSize = Enum.AutomaticSize.Y
main.Position = UDim2.new(0.5, -155, 0.5, -200)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", main)
stroke.Color = ACCENT
stroke.Thickness = 1.5
stroke.Transparency = 0.3

local pad = Instance.new("UIPadding", main)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 12)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)

local list = Instance.new("UIListLayout", main)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder

local title = Instance.new("TextLabel")
title.LayoutOrder = 0
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "STARFEX  •  HUB"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = main

local sub = Instance.new("TextLabel")
sub.LayoutOrder = 1
sub.Size = UDim2.new(1, 0, 0, 14)
sub.BackgroundTransparency = 1
sub.Text = "ЛКМ - вкл/выкл  •  ПКМ - настройки  •  СКМ - бинд"
sub.TextColor3 = GREY
sub.Font = Enum.Font.Gotham
sub.TextSize = 11
sub.Parent = main

do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local listeningKey
local function bindText(k)
    return state[k].bind and ("[" .. state[k].bind.Name .. "]") or "[—]"
end

local function makeRow(order, key, label, onRight)
    local row = Instance.new("TextButton")
    row.LayoutOrder = order
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = ROW
    row.AutoButtonColor = true
    row.Text = ""
    row.Parent = main
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Position = UDim2.fromOffset(12, 0)
    name.Size = UDim2.new(0.5, 0, 1, 0)
    name.Text = label
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.TextColor3 = Color3.new(1, 1, 1)
    name.Font = Enum.Font.GothamMedium
    name.TextSize = 14
    name.Parent = row

    local bindLabel = Instance.new("TextLabel")
    bindLabel.BackgroundTransparency = 1
    bindLabel.Position = UDim2.new(0.5, 0, 0, 0)
    bindLabel.Size = UDim2.new(0.25, 0, 1, 0)
    bindLabel.Text = "[—]"
    bindLabel.TextColor3 = GREY
    bindLabel.Font = Enum.Font.Gotham
    bindLabel.TextSize = 12
    bindLabel.Parent = row

    local pill = Instance.new("TextLabel")
    pill.AnchorPoint = Vector2.new(1, 0.5)
    pill.Position = UDim2.new(1, -10, 0.5, 0)
    pill.Size = UDim2.fromOffset(46, 22)
    pill.BackgroundColor3 = OFF
    pill.Text = "OFF"
    pill.TextColor3 = Color3.new(1, 1, 1)
    pill.Font = Enum.Font.GothamBold
    pill.TextSize = 12
    pill.Parent = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    ui[key] = { pill = pill, bindLabel = bindLabel }

    row.MouseButton1Click:Connect(function() setFeature(key) end)
    row.MouseButton2Click:Connect(function() if onRight then onRight() end end)
    row.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton3 then
            listeningKey = key
            bindLabel.Text = "[...]"
            bindLabel.TextColor3 = ACCENT
        end
    end)
end

local function makePanel(order, height)
    local p = Instance.new("Frame")
    p.LayoutOrder = order
    p.Size = UDim2.new(1, 0, 0, 0)
    p.BackgroundColor3 = PANEL
    p.ClipsDescendants = true
    p.Visible = false
    p.Parent = main
    Instance.new("UICorner", p).CornerRadius = UDim.new(0, 8)
    local function toggle()
        p.Visible = not p.Visible
        p.Size = UDim2.new(1, 0, 0, p.Visible and height or 0)
    end
    return p, toggle
end

local function makeSlider(parent, y, text, minV, maxV, decimals, default, onChange, withDefault)
    local fmt = "%." .. decimals .. "f"
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.fromOffset(12, y)
    label.Size = UDim2.new(0.6, 0, 0, 18)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.Parent = parent

    local track = Instance.new("Frame")
    track.Position = UDim2.new(0, 12, 0, y + 26)
    track.Size = UDim2.new(1, -24, 0, 8)
    track.BackgroundColor3 = OFF
    track.Parent = parent
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = ACCENT
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.fromOffset(16, 16)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function set(v)
        local m = 10 ^ decimals
        v = math.clamp(math.floor(v * m + 0.5) / m, minV, maxV)
        local a = (v - minV) / (maxV - minV)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        label.Text = text .. ": " .. string.format(fmt, v)
        onChange(v)
    end
    set(default)

    if withDefault then
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(1, 0)
        b.Position = UDim2.new(1, -10, 0, y - 1)
        b.Size = UDim2.fromOffset(70, 20)
        b.BackgroundColor3 = ACCENT
        b.Text = "Default"
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
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
    UIS.InputChanged:Connect(function(i)
        if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
end

local function makeToggle(parent, y, text, default, onChange)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(12, y)
    b.Size = UDim2.new(1, -24, 0, 24)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.AutoButtonColor = false
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local v = default
    local function refresh()
        b.BackgroundColor3 = v and ACCENT or OFF
        b.Text = text .. ": " .. (v and "ON" or "OFF")
    end
    refresh()
    onChange(v)
    b.MouseButton1Click:Connect(function()
        v = not v
        refresh()
        onChange(v)
    end)
end

-- Строки и панели
makeRow(2, "airstuck", "Airstuck")
makeRow(4, "esp3d", "ESP 3D")
makeRow(6, "esphp", "ESP HP")
makeRow(8, "espname", "ESP Name")

local speedPanel, speedToggle = makePanel(11, 50)
makeRow(10, "speed", "Speed", speedToggle)
makeSlider(speedPanel, 6, "Скорость", 16, 50, 0, 16, function(v) cfg.speed = v end, true)

local trigPanel, trigToggle = makePanel(13, 108)
makeRow(12, "trigger", "TriggerBot", trigToggle)
makeToggle(trigPanel, 6, "Crits (только в прыжке)", false, function(v) cfg.crits = v end)
makeToggle(trigPanel, 36, "Cooldown", true, function(v) cfg.useCooldown = v end)
makeSlider(trigPanel, 66, "Cooldown (сек)", 0.5, 3, 1, 1, function(v) cfg.cooldown = v end)

local aimPanel, aimToggle = makePanel(15, 102)
makeRow(14, "aim", "AimAssist", aimToggle)
makeSlider(aimPanel, 6, "Smooth", 0.1, 5, 1, 1, function(v) cfg.smooth = v end)
makeSlider(aimPanel, 54, "Range (блоки)", 1, 6, 1, 3, function(v) cfg.range = v end)

----------------------------------------------------------------
-- Ввод: RightShift + бинды
----------------------------------------------------------------
UIS.InputBegan:Connect(function(input, processed)
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
        ui[k].bindLabel.TextColor3 = GREY
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
        return
    end

    if processed then return end
    for key, s in pairs(state) do
        if s.bind and s.bind == input.KeyCode then setFeature(key) end
    end
end)

----------------------------------------------------------------
-- TriggerBot
----------------------------------------------------------------
local function clickMouse()
    if mouse1click then
        mouse1click()
    else
        local loc = UIS:GetMouseLocation()
        VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
    end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local lastHit = 0

RunService.RenderStepped:Connect(function()
    if not state.trigger.on or main.Visible then return end
    local char, hum = getChar(), getHum()
    if not (char and hum and hum.Health > 0) then return end

    rayParams.FilterDescendantsInstances = { char }
    local loc = UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(loc.X, loc.Y)
    local res = workspace:Raycast(ray.Origin, ray.Direction * TRIG_RANGE, rayParams)
    if not res then return end

    local model = res.Instance:FindFirstAncestorOfClass("Model")
    local plr = model and Players:GetPlayerFromCharacter(model)
    local thum = model and model:FindFirstChildOfClass("Humanoid")
    if not (plr and thum and thum.Health > 0) then return end

    if cfg.crits and hum.FloorMaterial ~= Enum.Material.Air then return end

    local now = os.clock()
    local interval = cfg.useCooldown and cfg.cooldown or 0.05
    if now - lastHit >= interval then
        lastHit = now
        clickMouse()
    end
end)

----------------------------------------------------------------
-- AimAssist
----------------------------------------------------------------
RunService:BindToRenderStep("StarfexAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not state.aim.on then return end
    local hrp = getHRP()
    if not hrp then return end
    cam = workspace.CurrentCamera

    local maxDist = cfg.range * BLOCK
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local bestPos, bestD = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local thum = plr.Character:FindFirstChildOfClass("Humanoid")
            local part = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
            if thum and thum.Health > 0 and part and (part.Position - hrp.Position).Magnitude <= maxDist then
                local v = cam:WorldToViewportPoint(part.Position)
                if v.Z > 0 then
                    local d = (Vector2.new(v.X, v.Y) - center).Magnitude
                    if d < bestD then bestD, bestPos = d, part.Position end
                end
            end
        end
    end

    if bestPos then
        local alpha = math.clamp(dt * 10 / cfg.smooth, 0, 1)
        cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, bestPos), alpha)
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
Players.PlayerAdded:Connect(function(p) if p ~= lp then createESP(p) end end)
Players.PlayerRemoving:Connect(removeESP)

local edges = {}
for i = 0, 7 do
    for _, bit in ipairs({ 1, 2, 4 }) do
        if bit32.band(i, bit) == 0 then
            table.insert(edges, { i + 1, i + bit + 1 })
        end
    end
end

RunService.RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
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
