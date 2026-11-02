-- Urban Reload — aimbot + esp + fov + no recoil + no spread + extras
-- executor: Xeno / Delta / Solara / similares (Lua)
-- teclas: RightShift = painel | RightCtrl = aimbot hold | Insert = fechar

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ========== CONFIG ==========
local CONFIG = {
    Aimbot = {
        Enabled = true,
        Key = Enum.KeyCode.RightControl,
        FOV = 120,
        Smooth = 0.25,
        Part = "Head",
        TeamCheck = true,
        VisibleOnly = false,
        MaxDist = 500,
    },
    ESP = {
        Enabled = true,
        Box = true,
        Tracer = true,
        Name = true,
        Distance = true,
        Health = true,
        TeamCheck = true,
        MaxDist = 800,
        Color = Color3.fromRGB(255, 60, 60),
        TracerOrigin = "Bottom",
    },
    NoRecoil = {
        Enabled = true,
        Strength = 0.0, -- 0 = sem recoil total
    },
    NoSpread = {
        Enabled = true,
    },
    Extras = {
        Fullbright = true,
        NoFog = true,
        FOVOverride = 90,
        HitboxExtend = true,
        HitboxSize = 6,
        SpeedBoost = false, -- opcional, risco maior
        SpeedValue = 32,
    },
}

-- ========== ESTADO ==========
local aimbotHeld = false
local espCache = {}
local fovCircle = Drawing.new("Circle")
local gui = nil
local connections = {}

-- ========== FOV CIRCLE ==========
fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
fovCircle.Radius = CONFIG.Aimbot.FOV
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Transparency = 0.8
fovCircle.Visible = CONFIG.Aimbot.Enabled

RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Radius = CONFIG.Aimbot.FOV
    fovCircle.Visible = CONFIG.Aimbot.Enabled
end)

-- ========== HELPERS ==========
local function isAlive(plr)
    local char = plr and plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function getRoot(plr)
    local char = plr and plr.Character
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function isSameTeam(plr)
    if not CONFIG.Aimbot.TeamCheck and not CONFIG.ESP.TeamCheck then return false end
    return plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
end

local function worldToScreen(pos)
    local sp, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), onScreen and sp.Z > 0
end

local function getAimPart(plr)
    local char = plr and plr.Character
    if not char then return nil end
    return char:FindFirstChild(CONFIG.Aimbot.Part) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

-- ========== AIMBOT ==========
local function getClosestTarget()
    local best, bestDist = nil, CONFIG.Aimbot.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local myRoot = getRoot(LocalPlayer)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) and not (CONFIG.Aimbot.TeamCheck and isSameTeam(plr)) then
            local part = getAimPart(plr)
            local root = getRoot(plr)
            if part and root and myRoot then
                local dist3d = (root.Position - myRoot.Position).Magnitude
                if dist3d <= CONFIG.Aimbot.MaxDist then
                    local sp, onScreen = worldToScreen(part.Position)
                    if onScreen then
                        local d = (sp - center).Magnitude
                        if d < bestDist then
                            if CONFIG.Aimbot.VisibleOnly then
                                local ray = Ray.new(Camera.CFrame.Position, part.Position - Camera.CFrame.Position)
                                local hit = workspace:FindPartOnRay(ray, LocalPlayer.Character)
                                if hit and hit:IsDescendantOf(plr.Character) then
                                    best, bestDist = part, d
                                end
                            else
                                best, bestDist = part, d
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if not CONFIG.Aimbot.Enabled or not aimbotHeld then return end
    local target = getClosestTarget()
    if target then
        local targetPos = target.Position
        local currentCF = Camera.CFrame
        local direction = (targetPos - currentCF.Position).Unit
        local targetCF = CFrame.new(currentCF.Position, currentCF.Position + direction)
        Camera.CFrame = currentCF:Lerp(targetCF, CONFIG.Aimbot.Smooth)
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CONFIG.Aimbot.Key then aimbotHeld = true end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if gui then gui.Enabled = not gui.Enabled end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == CONFIG.Aimbot.Key then aimbotHeld = false end
end)

-- ========== ESP ==========
local function createESP(plr)
    if plr == LocalPlayer then return end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false

    local outline = Drawing.new("Square")
    outline.Thickness = 3
    outline.Filled = false
    outline.Color = Color3.new(0, 0, 0)
    outline.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Visible = false

    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    name.Visible = false

    local distText = Drawing.new("Text")
    distText.Size = 12
    distText.Center = true
    distText.Outline = true
    distText.Visible = false

    local healthBar = Drawing.new("Square")
    healthBar.Thickness = 1
    healthBar.Filled = true
    healthBar.Visible = false

    espCache[plr] = {box = box, outline = outline, tracer = tracer, name = name, dist = distText, hp = healthBar}
end

local function removeESP(plr)
    local e = espCache[plr]
    if not e then return end
    for _, obj in pairs(e) do
        if obj.Remove then obj:Remove() end
    end
    espCache[plr] = nil
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)
for _, p in ipairs(Players:GetPlayers()) do createESP(p) end

RunService.RenderStepped:Connect(function()
    for plr, e in pairs(espCache) do
        local show = CONFIG.ESP.Enabled and plr ~= LocalPlayer and isAlive(plr)
        if show and CONFIG.ESP.TeamCheck and isSameTeam(plr) then show = false end

        local root = getRoot(plr)
        local head = plr.Character and plr.Character:FindFirstChild("Head")
        if not (show and root and head) then
            for _, obj in pairs(e) do obj.Visible = false end
            continue
        end

        local myRoot = getRoot(LocalPlayer)
        local dist3d = myRoot and (root.Position - myRoot.Position).Magnitude or 0
        if dist3d > CONFIG.ESP.MaxDist then
            for _, obj in pairs(e) do obj.Visible = false end
            continue
        end

        local headSp, headOn = worldToScreen(head.Position + Vector3.new(0, 1, 0))
        local feetSp, feetOn = worldToScreen(root.Position - Vector3.new(0, 3, 0))
        if not (headOn and feetOn) then
            for _, obj in pairs(e) do obj.Visible = false end
            continue
        end

        local h = math.abs(headSp.Y - feetSp.Y)
        local w = h * 0.65
        local x = headSp.X - w / 2
        local y = headSp.Y
        local color = CONFIG.ESP.Color

        if CONFIG.ESP.Box then
            e.box.Visible = true
            e.box.Size = Vector2.new(w, h)
            e.box.Position = Vector2.new(x, y)
            e.box.Color = color
            e.outline.Visible = true
            e.outline.Size = e.box.Size
            e.outline.Position = e.box.Position
        else
            e.box.Visible = false
            e.outline.Visible = false
        end

        if CONFIG.ESP.Tracer then
            e.tracer.Visible = true
            local origin = CONFIG.ESP.TracerOrigin == "Bottom"
                and Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                or Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            e.tracer.From = origin
            e.tracer.To = Vector2.new(x + w / 2, y + h)
            e.tracer.Color = color
        else
            e.tracer.Visible = false
        end

        if CONFIG.ESP.Name then
            e.name.Visible = true
            e.name.Text = plr.Name
            e.name.Position = Vector2.new(x + w / 2, y - 16)
            e.name.Color = color
        else
            e.name.Visible = false
        end

        if CONFIG.ESP.Distance then
            e.dist.Visible = true
            e.dist.Text = math.floor(dist3d) .. "m"
            e.dist.Position = Vector2.new(x + w / 2, y + h + 2)
            e.dist.Color = color
        else
            e.dist.Visible = false
        end

        if CONFIG.ESP.Health then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                e.hp.Visible = true
                e.hp.Size = Vector2.new(3, h * ratio)
                e.hp.Position = Vector2.new(x - 5, y + h - h * ratio)
                e.hp.Color = Color3.fromRGB(255 * (1 - ratio), 255 * ratio, 0)
            else
                e.hp.Visible = false
            end
        else
            e.hp.Visible = false
        end
    end
end)

-- ========== NO RECOIL / NO SPREAD (hooks genéricos) ==========
-- FILL: Urban Reload não expõe módulos públicos; se o jogo usar CameraController/InventoryController
-- como outros shooters Roblox, esses hooks pegam. Se não, precisa achar o módulo real com
-- getgc(true) e procurar por "Recoil"/"Spread" nas tabelas.
local function applyWeaponHooks()
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            -- no recoil
            if CONFIG.NoRecoil.Enabled then
                if rawget(obj, "Recoil") ~= nil then
                    pcall(function() rawset(obj, "Recoil", CONFIG.NoRecoil.Strength) end)
                end
                if rawget(obj, "CameraRecoilingEnabled") ~= nil then
                    pcall(function() rawset(obj, "CameraRecoilingEnabled", false) end)
                end
                if rawget(obj, "weaponKick") ~= nil and type(obj.weaponKick) == "function" then
                    pcall(function() obj.weaponKick = function() end end)
                end
            end
            -- no spread
            if CONFIG.NoSpread.Enabled then
                if rawget(obj, "spread") ~= nil then
                    pcall(function() rawset(obj, "spread", 0) end)
                end
                if rawget(obj, "Spread") ~= nil then
                    pcall(function() rawset(obj, "Spread", 0) end)
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(1) do
        if CONFIG.NoRecoil.Enabled or CONFIG.NoSpread.Enabled then
            pcall(applyWeaponHooks)
        end
    end
end)

-- ========== EXTRAS ==========
-- 1) fullbright
RunService.RenderStepped:Connect(function()
    if CONFIG.Extras.Fullbright then
        game.Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        game.Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        game.Lighting.Brightness = 2
    end
end)

-- 2) no fog
RunService.RenderStepped:Connect(function()
    if CONFIG.Extras.NoFog then
        game.Lighting.FogEnd = 100000
        game.Lighting.FogStart = 100000
    end
end)

-- 3) fov override
RunService.RenderStepped:Connect(function()
    if CONFIG.Extras.FOVOverride and CONFIG.Extras.FOVOverride > 0 then
        Camera.FieldOfView = CONFIG.Extras.FOVOverride
    end
end)

-- 4) hitbox extend
RunService.RenderStepped:Connect(function()
    if not CONFIG.Extras.HitboxExtend then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local size = Vector3.new(CONFIG.Extras.HitboxSize, CONFIG.Extras.HitboxSize, CONFIG.Extras.HitboxSize)
                if head.Size ~= size then
                    head.Size = size
                end
            end
        end
    end
end)

-- 5) speed boost (opcional, risco alto)
RunService.RenderStepped:Connect(function()
    if not CONFIG.Extras.SpeedBoost then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = CONFIG.Extras.SpeedValue
    end
end)

-- ========== UI SIMPLES ==========
local function buildUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "UrbanReload_UI"
    sg.ResetOnSpawn = false
    sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
    gui = sg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 320)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.Text = "  urban reload"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local y = 36
    local function addToggle(text, get, set)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 24)
        btn.Position = UDim2.new(0, 8, 0, y)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.Code
        btn.TextSize = 12
        btn.Parent = frame
        local function refresh()
            btn.Text = text .. ": " .. (get() and "ON" or "OFF")
            btn.BackgroundColor3 = get() and Color3.fromRGB(0, 120, 60) or Color3.fromRGB(35, 35, 35)
        end
        btn.MouseButton1Click:Connect(function()
            set(not get())
            refresh()
        end)
        refresh()
        y = y + 28
    end

    addToggle("aimbot", function() return CONFIG.Aimbot.Enabled end, function(v) CONFIG.Aimbot.Enabled = v end)
    addToggle("esp", function() return CONFIG.ESP.Enabled end, function(v) CONFIG.ESP.Enabled = v end)
    addToggle("no recoil", function() return CONFIG.NoRecoil.Enabled end, function(v) CONFIG.NoRecoil.Enabled = v end)
    addToggle("no spread", function() return CONFIG.NoSpread.Enabled end, function(v) CONFIG.NoSpread.Enabled = v end)
    addToggle("fullbright", function() return CONFIG.Extras.Fullbright end, function(v) CONFIG.Extras.Fullbright = v end)
    addToggle("no fog", function() return CONFIG.Extras.NoFog end, function(v) CONFIG.Extras.NoFog = v end)
    addToggle("hitbox", function() return CONFIG.Extras.HitboxExtend end, function(v) CONFIG.Extras.HitboxExtend = v end)
    addToggle("fov 90", function() return CONFIG.Extras.FOVOverride > 0 end, function(v) CONFIG.Extras.FOVOverride = v and 90 or 0 end)
end

buildUI()
