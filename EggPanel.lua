-- EggPanel | Roube um Ovo | client-side (executor com fireproximityprompt)
-- INSERT mostra/esconde | config salva em EggPanel.json (pasta workspace do executor)
-- didn't check no jogo: nomes de ovo/prompt sao keywords ajustaveis

if getgenv and getgenv().EggPanelLoaded then return end
if getgenv then getgenv().EggPanelLoaded = true end

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local VU          = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local Lighting    = game:GetService("Lighting")
local TeleportSvc = game:GetService("TeleportService")
local lp          = Players.LocalPlayer

-- ===== CONFIG =====
local CFG = {
    WalkSpeed = 40, JumpPower = 75, FlySpeed = 60,
    PromptRange = 25, TickS = 0.2,
    EggKeywords    = { "egg", "ovo" },
    PromptKeywords = { "steal", "roub", "collect", "colet", "pegar", "grab", "claim" },
    MenuKey = Enum.KeyCode.Insert,
    File = "EggPanel.json",
}
local State = {
    Speed=false, InfJump=false, Noclip=false, Fly=false, ESP=false,
    AutoPrompt=false, AntiAFK=true, AntiKick=true, Fullbright=false,
}

-- ===== SAVE / LOAD =====
local function save()
    if not writefile then return end
    pcall(function()
        writefile(CFG.File, HttpService:JSONEncode({
            State = State,
            Nums = { WalkSpeed=CFG.WalkSpeed, JumpPower=CFG.JumpPower, FlySpeed=CFG.FlySpeed, PromptRange=CFG.PromptRange },
        }))
    end)
end
local function load()
    if not (readfile and isfile and isfile(CFG.File)) then return end
    pcall(function()
        local d = HttpService:JSONDecode(readfile(CFG.File))
        for k, v in pairs(d.State or {}) do if State[k] ~= nil then State[k] = v end end
        for k, v in pairs(d.Nums or {}) do if CFG[k] ~= nil then CFG[k] = v end end
    end)
end
load()

-- ===== HELPERS =====
local function matches(str, list)
    str = string.lower(tostring(str))
    for _, k in ipairs(list) do if string.find(str, k, 1, true) then return true end end
    return false
end
local function char() return lp.Character end
local function hrp() local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ===== ANTI-AFK =====
lp.Idled:Connect(function()
    if State.AntiAFK then
        VU:CaptureController()
        VU:ClickButton2(Vector2.new())
    end
end)

-- ===== ANTI-KICK (client-side) =====
-- bloqueia LocalPlayer:Kick() chamado por scripts locais do jogo.
-- NAO impede kick/ban vindo do servidor: isso nao existe do lado do cliente.
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            if State.AntiKick and self == lp and string.lower(getnamecallmethod()) == "kick" then
                return
            end
            return old(self, ...)
        end)
    end)
end

-- ===== SPEED / JUMP / FULLBRIGHT =====
RunService.Heartbeat:Connect(function()
    local h = hum()
    if h and State.Speed then
        h.WalkSpeed = CFG.WalkSpeed
        h.UseJumpPower = true
        h.JumpPower = CFG.JumpPower
    end
    if State.Fullbright then
        Lighting.Brightness = 2; Lighting.ClockTime = 14
        Lighting.GlobalShadows = false; Lighting.FogEnd = 1e6
    end
end)

UIS.JumpRequest:Connect(function()
    if State.InfJump then
        local h = hum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Stepped:Connect(function()
    if State.Noclip and char() then
        for _, p in ipairs(char():GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

-- ===== FLY =====
local flyBV, flyBG
local function stopFly()
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    local h = hum(); if h then h.PlatformStand = false end
end
RunService.RenderStepped:Connect(function()
    local r, h = hrp(), hum()
    if not (State.Fly and r and h) then
        if flyBV then stopFly() end
        return
    end
    if not flyBV then
        flyBV = Instance.new("BodyVelocity"); flyBV.MaxForce = Vector3.one * 9e9; flyBV.Parent = r
        flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.one * 9e9; flyBG.P = 9e4; flyBG.Parent = r
    end
    h.PlatformStand = true
    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
    flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * CFG.FlySpeed or Vector3.zero
    flyBG.CFrame = cam.CFrame
end)

-- ===== EGG TRACKING + ESP =====
local eggs = {}
local function eggRoot(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true) end
end
local function addEgg(inst)
    if eggs[inst] then return end
    if not ((inst:IsA("Model") or inst:IsA("BasePart")) and matches(inst.Name, CFG.EggKeywords)) then return end
    if Players:GetPlayerFromCharacter(inst) then return end
    local par = inst.Parent
    while par and par ~= workspace do
        if eggs[par] then return end
        par = par.Parent
    end
    eggs[inst] = {}
end
local function removeEgg(inst)
    local e = eggs[inst]
    if e then
        if e.hl then e.hl:Destroy() end
        if e.gui then e.gui:Destroy() end
        eggs[inst] = nil
    end
end
for _, d in ipairs(workspace:GetDescendants()) do addEgg(d) end
workspace.DescendantAdded:Connect(addEgg)
workspace.DescendantRemoving:Connect(removeEgg)

task.spawn(function()
    while true do
        task.wait(0.5)
        for inst, e in pairs(eggs) do
            if not State.ESP then
                if e.hl then e.hl:Destroy(); e.hl = nil end
                if e.gui then e.gui:Destroy(); e.gui = nil end
            else
                local root = eggRoot(inst)
                if root and inst.Parent then
                    if not e.hl then
                        e.hl = Instance.new("Highlight")
                        e.hl.FillColor = Color3.fromRGB(255, 220, 60)
                        e.hl.FillTransparency = 0.6
                        e.hl.Adornee = inst
                        e.hl.Parent = inst
                    end
                    if not e.gui then
                        local g = Instance.new("BillboardGui")
                        g.Size = UDim2.fromOffset(120, 24); g.AlwaysOnTop = true
                        g.StudsOffset = Vector3.new(0, 3, 0); g.Adornee = root
                        local t = Instance.new("TextLabel", g)
                        t.Name = "L"; t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
                        t.TextColor3 = Color3.new(1, 1, 0.4); t.TextStrokeTransparency = 0
                        t.Font = Enum.Font.GothamBold; t.TextSize = 13
                        g.Parent = root
                        e.gui = g
                    end
                    local r = hrp()
                    if r then
                        e.gui.L.Text = ("%s [%dm]"):format(inst.Name, (root.Position - r.Position).Magnitude)
                    end
                end
            end
        end
    end
end)

local function tpNearestEgg()
    local r = hrp(); if not r then return end
    local best, bd
    for inst in pairs(eggs) do
        local root = eggRoot(inst)
        if root and inst.Parent then
            local d = (root.Position - r.Position).Magnitude
            if not bd or d < bd then best, bd = root, d end
        end
    end
    if best then r.CFrame = best.CFrame + Vector3.new(0, 4, 0) end
end

-- ===== AUTO PROMPT =====
local prompts = {}
local function trackPrompt(p) if p:IsA("ProximityPrompt") then prompts[p] = true end end
for _, d in ipairs(workspace:GetDescendants()) do trackPrompt(d) end
workspace.DescendantAdded:Connect(trackPrompt)
workspace.DescendantRemoving:Connect(function(d) prompts[d] = nil end)

local function promptPos(p)
    local par = p.Parent
    if par and par:IsA("BasePart") then return par.Position end
    if par and par:IsA("Attachment") then return par.WorldPosition end
    if par and par:IsA("Model") then return par:GetPivot().Position end
end
task.spawn(function()
    while true do
        task.wait(CFG.TickS)
        local r = hrp()
        if State.AutoPrompt and r and fireproximityprompt then
            for p in pairs(prompts) do
                if p.Enabled and (matches(p.ActionText, CFG.PromptKeywords) or matches(p.ObjectText, CFG.EggKeywords)) then
                    local pos = promptPos(p)
                    if pos and (pos - r.Position).Magnitude <= math.min(CFG.PromptRange, p.MaxActivationDistance + 5) then
                        p.HoldDuration = 0
                        pcall(fireproximityprompt, p)
                    end
                end
            end
        end
    end
end)

-- FILL: auto-steal via RemoteEvent. dump:
--   for _,v in ipairs(game:GetDescendants()) do if v:IsA("RemoteEvent") then print(v:GetFullName()) end end
-- spy o remote (SimpleSpy) enquanto rouba, cola caminho + args aqui.

-- ===== SERVER =====
local function rejoin()
    if #Players:GetPlayers() <= 1 then lp:Kick("rejoin"); task.wait(); TeleportSvc:Teleport(game.PlaceId, lp)
    else TeleportSvc:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp) end
end
local function serverHop()
    pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        local data = HttpService:JSONDecode(game:HttpGet(url))
        for _, s in ipairs(data.data or {}) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                TeleportSvc:TeleportToPlaceInstance(game.PlaceId, s.id, lp)
                return
            end
        end
    end)
end

-- ===== GUI =====
local parent = (gethui and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "EggPanel"; gui.ResetOnSpawn = false; gui.Parent = parent

local C = {
    bg = Color3.fromRGB(22, 22, 27), bar = Color3.fromRGB(34, 34, 42),
    btn = Color3.fromRGB(46, 46, 58), on = Color3.fromRGB(45, 140, 80),
    tab = Color3.fromRGB(60, 90, 200), txt = Color3.new(1, 1, 1),
}
local function round(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 6) end

local win = Instance.new("Frame", gui)
win.Size = UDim2.fromOffset(300, 360); win.Position = UDim2.fromOffset(40, 100)
win.BackgroundColor3 = C.bg; win.BorderSizePixel = 0; round(win, 8)

local title = Instance.new("TextLabel", win)
title.Size = UDim2.new(1, 0, 0, 30); title.BackgroundColor3 = C.bar; title.BorderSizePixel = 0
title.Text = "roube um ovo  |  INSERT"; title.TextColor3 = C.txt
title.Font = Enum.Font.GothamBold; title.TextSize = 14; round(title, 8)

do -- drag
    local dragging, start, origin
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, start, origin = true, i.Position, win.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            win.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local tabBar = Instance.new("Frame", win)
tabBar.Size = UDim2.new(1, -16, 0, 26); tabBar.Position = UDim2.fromOffset(8, 36)
tabBar.BackgroundTransparency = 1
local tl = Instance.new("UIListLayout", tabBar)
tl.FillDirection = Enum.FillDirection.Horizontal; tl.Padding = UDim.new(0, 4)

local pages, tabBtns = {}, {}
local function showTab(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, b in pairs(tabBtns) do b.BackgroundColor3 = (n == name) and C.tab or C.btn end
end
local function newTab(name)
    local b = Instance.new("TextButton", tabBar)
    b.Size = UDim2.new(0.25, -3, 1, 0); b.BackgroundColor3 = C.btn; b.BorderSizePixel = 0
    b.Text = name; b.TextColor3 = C.txt; b.Font = Enum.Font.GothamBold; b.TextSize = 12; round(b)
    b.MouseButton1Click:Connect(function() showTab(name) end)
    tabBtns[name] = b

    local p = Instance.new("ScrollingFrame", win)
    p.Size = UDim2.new(1, -16, 1, -72); p.Position = UDim2.fromOffset(8, 66)
    p.BackgroundTransparency = 1; p.BorderSizePixel = 0; p.ScrollBarThickness = 3
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y; p.CanvasSize = UDim2.new()
    local l = Instance.new("UIListLayout", p); l.Padding = UDim.new(0, 5)
    pages[name] = p
    return p
end

local function button(page, text, cb)
    local b = Instance.new("TextButton", page)
    b.Size = UDim2.new(1, -6, 0, 28); b.BackgroundColor3 = C.btn; b.BorderSizePixel = 0
    b.Text = text; b.TextColor3 = C.txt; b.Font = Enum.Font.Gotham; b.TextSize = 13; round(b)
    b.MouseButton1Click:Connect(function() cb(b) end)
    return b
end
local function toggle(page, label, key, onChange)
    local function paint(b)
        b.Text = label .. ": " .. (State[key] and "ON" or "OFF")
        b.BackgroundColor3 = State[key] and C.on or C.btn
    end
    local b = button(page, "", function(btn)
        State[key] = not State[key]
        paint(btn); save()
        if onChange then onChange(State[key]) end
    end)
    paint(b)
end
local function numInput(page, label, key)
    local row = Instance.new("Frame", page)
    row.Size = UDim2.new(1, -6, 0, 28); row.BackgroundColor3 = C.btn; row.BorderSizePixel = 0; round(row)
    local t = Instance.new("TextLabel", row)
    t.Size = UDim2.new(0.6, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = "  " .. label
    t.TextColor3 = C.txt; t.Font = Enum.Font.Gotham; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left
    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(0.4, -6, 1, -8); box.Position = UDim2.new(0.6, 0, 0, 4)
    box.BackgroundColor3 = C.bar; box.BorderSizePixel = 0; box.TextColor3 = C.txt
    box.Font = Enum.Font.Gotham; box.TextSize = 13; box.Text = tostring(CFG[key]); round(box, 4)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then CFG[key] = n; save() else box.Text = tostring(CFG[key]) end
    end)
end

-- Main
local main = newTab("Main")
toggle(main, "Speed/Jump", "Speed", function(on)
    if not on then local h = hum(); if h then h.WalkSpeed = 16; h.JumpPower = 50 end end
end)
toggle(main, "Infinite Jump", "InfJump")
toggle(main, "Noclip", "Noclip")
toggle(main, "Fly (WASD/Space/Ctrl)", "Fly")
numInput(main, "WalkSpeed", "WalkSpeed")
numInput(main, "JumpPower", "JumpPower")
numInput(main, "FlySpeed", "FlySpeed")

-- Eggs
local eg = newTab("Ovos")
toggle(eg, "ESP Ovos", "ESP")
toggle(eg, "Auto Prompt (roubar/coletar)", "AutoPrompt")
numInput(eg, "Alcance prompt", "PromptRange")
button(eg, "TP ovo mais proximo", function() tpNearestEgg() end)

-- Misc
local misc = newTab("Misc")
toggle(misc, "Anti-AFK", "AntiAFK")
toggle(misc, "Anti-Kick (client)", "AntiKick")
toggle(misc, "Fullbright", "Fullbright")
button(misc, "Rejoin", function() rejoin() end)
button(misc, "Server Hop", function() serverHop() end)

-- Config
local cf = newTab("Config")
button(cf, "Salvar config", function(b) save(); b.Text = "Salvo!"; task.delay(1, function() b.Text = "Salvar config" end) end)
button(cf, "Fechar painel", function() gui:Destroy(); if getgenv then getgenv().EggPanelLoaded = nil end end)

showTab("Main")

UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == CFG.MenuKey then win.Visible = not win.Visible end
end)
