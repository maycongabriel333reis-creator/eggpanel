-- Egg Hub | Roube um Ovo | client-side (executor com fireproximityprompt)
-- INSERT ou botao "E" abre/fecha | config em EggHub.json | didn't run no jogo

local G = (getgenv and getgenv()) or _G
if G.EggHubCleanup then pcall(G.EggHubCleanup) end

local function main()
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
        PromptMode = "Keywords",   -- "Keywords" | "All"
        EggKeywords    = { "egg", "ovo" },
        PromptKeywords = { "steal", "roub", "collect", "colet", "pegar", "grab", "claim" },
        MenuKey = Enum.KeyCode.Insert,
        File = "EggHub.json",
    }
    local State = {
        Speed=false, InfJump=false, Noclip=false, Fly=false,
        EggESP=false, PlayerESP=false, AutoPrompt=false,
        AntiAFK=true, AntiKick=true, Fullbright=false,
    }
    local NUMS = { "WalkSpeed", "JumpPower", "FlySpeed", "PromptRange" }

    local function save()
        if not writefile then return end
        pcall(function()
            local nums = {}
            for _, k in ipairs(NUMS) do nums[k] = CFG[k] end
            writefile(CFG.File, HttpService:JSONEncode({ State = State, Nums = nums, PromptMode = CFG.PromptMode }))
        end)
    end
    local function loadCfg()
        if not (readfile and isfile and isfile(CFG.File)) then return end
        pcall(function()
            local d = HttpService:JSONDecode(readfile(CFG.File))
            for k, v in pairs(d.State or {}) do if State[k] ~= nil then State[k] = v end end
            for k, v in pairs(d.Nums or {}) do if CFG[k] ~= nil then CFG[k] = v end end
            if d.PromptMode then CFG.PromptMode = d.PromptMode end
        end)
    end
    loadCfg()

    -- ===== HELPERS =====
    local alive = true
    local conns = {}
    local function bind(sig, fn) conns[#conns + 1] = sig:Connect(fn) end
    local function matches(str, list)
        str = string.lower(tostring(str))
        for _, k in ipairs(list) do if string.find(str, k, 1, true) then return true end end
        return false
    end
    local function char() return lp.Character end
    local function hrp() local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end
    local function hum() local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end

    -- ===== ANTI-AFK =====
    bind(lp.Idled, function()
        if State.AntiAFK then
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end
    end)

    -- ===== ANTI-KICK (client-side; nao impede kick/ban do servidor) =====
    G.EggHubAntiKick = State.AntiKick
    if hookmetamethod and getnamecallmethod and not G.EggHubHooked then
        local ok = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", function(self, ...)
                if G.EggHubAntiKick and self == lp and string.lower(getnamecallmethod()) == "kick" then
                    return
                end
                return old(self, ...)
            end)
        end)
        if ok then G.EggHubHooked = true end
    end

    -- ===== SPEED / JUMP / FULLBRIGHT =====
    bind(RunService.Heartbeat, function()
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
    bind(UIS.JumpRequest, function()
        if State.InfJump then
            local h = hum()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
    bind(RunService.Stepped, function()
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
    bind(RunService.RenderStepped, function()
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

    -- ===== EGG TRACKING =====
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
    bind(workspace.DescendantAdded, addEgg)
    bind(workspace.DescendantRemoving, removeEgg)

    local pesp = {}   -- [player] = Highlight
    local function clearESP()
        for _, e in pairs(eggs) do
            if e.hl then e.hl:Destroy(); e.hl = nil end
            if e.gui then e.gui:Destroy(); e.gui = nil end
        end
        for p, h in pairs(pesp) do h:Destroy(); pesp[p] = nil end
    end

    task.spawn(function()
        while alive do
            task.wait(0.5)
            local r = hrp()
            for inst, e in pairs(eggs) do
                if not State.EggESP then
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
                        if r then
                            e.gui.L.Text = ("%s [%dm]"):format(inst.Name, (root.Position - r.Position).Magnitude)
                        end
                    end
                end
            end
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= lp then
                    local c = pl.Character
                    if State.PlayerESP and c then
                        if not pesp[pl] or pesp[pl].Adornee ~= c then
                            if pesp[pl] then pesp[pl]:Destroy() end
                            local h = Instance.new("Highlight")
                            h.FillColor = Color3.fromRGB(255, 60, 60); h.FillTransparency = 0.7
                            h.Adornee = c; h.Parent = c
                            pesp[pl] = h
                        end
                    elseif pesp[pl] then
                        pesp[pl]:Destroy(); pesp[pl] = nil
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
    bind(workspace.DescendantAdded, trackPrompt)
    bind(workspace.DescendantRemoving, function(d) prompts[d] = nil end)

    local function promptPos(p)
        local par = p.Parent
        if par and par:IsA("BasePart") then return par.Position end
        if par and par:IsA("Attachment") then return par.WorldPosition end
        if par and par:IsA("Model") then return par:GetPivot().Position end
    end
    task.spawn(function()
        while alive do
            task.wait(CFG.TickS)
            local r = hrp()
            if State.AutoPrompt and r and fireproximityprompt then
                for p in pairs(prompts) do
                    local okMatch = CFG.PromptMode == "All"
                        or matches(p.ActionText, CFG.PromptKeywords)
                        or matches(p.ObjectText, CFG.EggKeywords)
                    if p.Enabled and okMatch then
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
        if #Players:GetPlayers() <= 1 then
            TeleportSvc:Teleport(game.PlaceId, lp)
        else
            TeleportSvc:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
        end
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
    local function getParent()
        if gethui then
            local ok, h = pcall(gethui)
            if ok and h then return h end
        end
        local ok = pcall(function() return game:GetService("CoreGui"):GetChildren() end)
        if ok then return game:GetService("CoreGui") end
        return lp:WaitForChild("PlayerGui")
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "EggHub"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    gui.Parent = getParent()

    local C = {
        red    = Color3.fromRGB(205, 30, 42),
        redHi  = Color3.fromRGB(240, 70, 80),
        redLo  = Color3.fromRGB(150, 15, 25),
        bg     = Color3.fromRGB(18, 18, 22),
        row    = Color3.fromRGB(30, 30, 35),
        off    = Color3.fromRGB(55, 55, 62),
        white  = Color3.new(1, 1, 1),
    }
    local function round(o, r) Instance.new("UICorner", o).CornerRadius = UDim.new(0, r or 6) end
    local function stroke(o, col, th)
        local s = Instance.new("UIStroke", o); s.Color = col; s.Thickness = th or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        return s
    end
    local function label(parent, text, size, font)
        local t = Instance.new("TextLabel", parent)
        t.BackgroundTransparency = 1; t.Text = text; t.TextColor3 = C.white
        t.Font = font or Enum.Font.GothamBold; t.TextSize = size or 16
        t.TextXAlignment = Enum.TextXAlignment.Left
        return t
    end

    local W, H = 580, 400
    local win = Instance.new("Frame", gui)
    win.Size = UDim2.fromOffset(W, H); win.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
    win.BackgroundColor3 = C.bg; win.BorderSizePixel = 0; round(win, 8); stroke(win, C.redLo, 2)

    local bar = Instance.new("Frame", win)
    bar.Size = UDim2.new(1, 0, 0, 40); bar.BackgroundColor3 = C.red; bar.BorderSizePixel = 0
    round(bar, 8); stroke(bar, C.redLo, 2)
    local ttl = label(bar, "Egg Hub", 22, Enum.Font.GothamBlack)
    ttl.Size = UDim2.fromScale(1, 1); ttl.TextXAlignment = Enum.TextXAlignment.Center

    local xb = Instance.new("TextButton", bar)
    xb.Size = UDim2.fromOffset(34, 28); xb.Position = UDim2.new(1, -42, 0.5, -14)
    xb.BackgroundColor3 = C.redLo; xb.BorderSizePixel = 0; xb.Text = "X"
    xb.TextColor3 = C.white; xb.Font = Enum.Font.GothamBlack; xb.TextSize = 18; round(xb, 4)
    xb.MouseButton1Click:Connect(function() win.Visible = false end)

    do -- drag
        local dragging, start, origin
        bar.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, start, origin = true, i.Position, win.Position
            end
        end)
        bind(UIS.InputChanged, function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - start
                win.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
            end
        end)
        bind(UIS.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end

    -- botao flutuante "E"
    local fab = Instance.new("TextButton", gui)
    fab.Size = UDim2.fromOffset(40, 40); fab.Position = UDim2.fromOffset(12, 200)
    fab.BackgroundColor3 = C.red; fab.BorderSizePixel = 0; fab.Text = "E"
    fab.TextColor3 = C.white; fab.Font = Enum.Font.GothamBlack; fab.TextSize = 20
    round(fab, 20); stroke(fab, C.redLo, 2)
    fab.MouseButton1Click:Connect(function() win.Visible = not win.Visible end)

    -- tabs (esquerda)
    local tabCol = Instance.new("Frame", win)
    tabCol.Size = UDim2.fromOffset(120, H - 56); tabCol.Position = UDim2.fromOffset(8, 48)
    tabCol.BackgroundTransparency = 1
    local tcl = Instance.new("UIListLayout", tabCol); tcl.Padding = UDim.new(0, 6)

    -- search (embaixo)
    local sb = Instance.new("Frame", win)
    sb.Size = UDim2.new(1, -144, 0, 34); sb.Position = UDim2.new(0, 136, 1, -42)
    sb.BackgroundColor3 = C.row; sb.BorderSizePixel = 0; round(sb, 6); stroke(sb, C.redLo, 1)
    local sl = label(sb, "Search", 14); sl.Size = UDim2.fromOffset(60, 34); sl.Position = UDim2.fromOffset(10, 0)
    local search = Instance.new("TextBox", sb)
    search.Size = UDim2.new(1, -80, 1, -10); search.Position = UDim2.fromOffset(72, 5)
    search.BackgroundColor3 = C.bg; search.BorderSizePixel = 0; search.ClearTextOnFocus = false
    search.PlaceholderText = "Filter features..."; search.Text = ""
    search.TextColor3 = C.white; search.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
    search.Font = Enum.Font.Gotham; search.TextSize = 13; search.TextXAlignment = Enum.TextXAlignment.Left
    round(search, 4)

    local pages, tabBtns, current = {}, {}, nil
    local function applyFilter()
        local q = string.lower(search.Text)
        local pg = pages[current]; if not pg then return end
        for _, row in ipairs(pg.rows) do
            row.frame.Visible = (q == "") or (string.find(string.lower(row.name), q, 1, true) ~= nil)
        end
    end
    local function showTab(name)
        current = name
        for n, p in pairs(pages) do p.scroll.Visible = (n == name) end
        for n, b in pairs(tabBtns) do b.BackgroundColor3 = (n == name) and C.redHi or C.red end
        applyFilter()
    end
    search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    local function newTab(name)
        local b = Instance.new("TextButton", tabCol)
        b.Size = UDim2.new(1, 0, 0, 38); b.BackgroundColor3 = C.red; b.BorderSizePixel = 0
        b.Text = name; b.TextColor3 = C.white; b.Font = Enum.Font.GothamBlack; b.TextSize = 17
        round(b, 5); stroke(b, C.redLo, 2)
        b.MouseButton1Click:Connect(function() showTab(name) end)
        tabBtns[name] = b

        local s = Instance.new("ScrollingFrame", win)
        s.Size = UDim2.new(1, -144, 1, -100); s.Position = UDim2.fromOffset(136, 48)
        s.BackgroundTransparency = 1; s.BorderSizePixel = 0; s.ScrollBarThickness = 4
        s.ScrollBarImageColor3 = C.red
        s.AutomaticCanvasSize = Enum.AutomaticSize.Y; s.CanvasSize = UDim2.new(); s.Visible = false
        local l = Instance.new("UIListLayout", s); l.Padding = UDim.new(0, 6)
        local pg = { scroll = s, rows = {} }
        pages[name] = pg
        return pg
    end

    local function newRow(pg, name)
        local f = Instance.new("Frame", pg.scroll)
        f.Size = UDim2.new(1, -8, 0, 38); f.BackgroundColor3 = C.row; f.BorderSizePixel = 0
        round(f, 5); stroke(f, C.redLo, 1)
        local t = label(f, name, 16); t.Size = UDim2.new(0.55, 0, 1, 0); t.Position = UDim2.fromOffset(10, 0)
        pg.rows[#pg.rows + 1] = { frame = f, name = name }
        return f
    end

    local function toggle(pg, name, key, onChange)
        local f = newRow(pg, name)
        local track = Instance.new("TextButton", f)
        track.Size = UDim2.fromOffset(52, 24); track.Position = UDim2.new(1, -62, 0.5, -12)
        track.BorderSizePixel = 0; track.Text = ""; round(track, 12)
        local knob = Instance.new("Frame", track)
        knob.Size = UDim2.fromOffset(18, 18); knob.BackgroundColor3 = C.white; knob.BorderSizePixel = 0; round(knob, 9)
        local function paint()
            track.BackgroundColor3 = State[key] and C.red or C.off
            knob.Position = State[key] and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        end
        track.MouseButton1Click:Connect(function()
            State[key] = not State[key]
            paint(); save()
            if onChange then onChange(State[key]) end
        end)
        paint()
    end
    local function numInput(pg, name, key)
        local f = newRow(pg, name)
        local box = Instance.new("TextBox", f)
        box.Size = UDim2.fromOffset(90, 26); box.Position = UDim2.new(1, -100, 0.5, -13)
        box.BackgroundColor3 = C.bg; box.BorderSizePixel = 0; box.TextColor3 = C.white
        box.Font = Enum.Font.GothamBold; box.TextSize = 14; box.Text = tostring(CFG[key]); round(box, 4)
        stroke(box, C.redLo, 1)
        box.FocusLost:Connect(function()
            local n = tonumber(box.Text)
            if n then CFG[key] = n; save() else box.Text = tostring(CFG[key]) end
        end)
    end
    local function dropdown(pg, name, key, options)
        local f = newRow(pg, name)
        local b = Instance.new("TextButton", f)
        b.Size = UDim2.fromOffset(110, 26); b.Position = UDim2.new(1, -120, 0.5, -13)
        b.BackgroundColor3 = C.bg; b.BorderSizePixel = 0; b.TextColor3 = C.white
        b.Font = Enum.Font.GothamBold; b.TextSize = 14; b.Text = tostring(CFG[key]); round(b, 4)
        stroke(b, C.redLo, 1)
        b.MouseButton1Click:Connect(function()
            local idx = 1
            for i, o in ipairs(options) do if o == CFG[key] then idx = i end end
            CFG[key] = options[(idx % #options) + 1]
            b.Text = CFG[key]; save()
        end)
    end
    local function action(pg, name, btnText, cb)
        local f = newRow(pg, name)
        local b = Instance.new("TextButton", f)
        b.Size = UDim2.fromOffset(90, 26); b.Position = UDim2.new(1, -100, 0.5, -13)
        b.BackgroundColor3 = C.red; b.BorderSizePixel = 0; b.TextColor3 = C.white
        b.Font = Enum.Font.GothamBlack; b.TextSize = 14; b.Text = btnText; round(b, 4)
        b.MouseButton1Click:Connect(function() cb(b) end)
    end

    -- Farm
    local farm = newTab("Farm")
    toggle(farm, "Auto Prompt", "AutoPrompt")
    dropdown(farm, "Prompt Mode", "PromptMode", { "Keywords", "All" })
    numInput(farm, "Prompt Range", "PromptRange")
    action(farm, "Move To Egg", "Teleport", function() tpNearestEgg() end)

    -- Player
    local player = newTab("Player")
    toggle(player, "Speed / Jump", "Speed", function(on)
        if not on then local h = hum(); if h then h.WalkSpeed = 16; h.JumpPower = 50 end end
    end)
    numInput(player, "Walk Speed", "WalkSpeed")
    numInput(player, "Jump Power", "JumpPower")
    toggle(player, "Infinite Jump", "InfJump")
    toggle(player, "Noclip", "Noclip")
    toggle(player, "Fly (WASD/Space/Ctrl)", "Fly")
    numInput(player, "Fly Speed", "FlySpeed")

    -- Visual
    local visual = newTab("Visual")
    toggle(visual, "Egg ESP", "EggESP")
    toggle(visual, "Player ESP", "PlayerESP")
    toggle(visual, "Fullbright", "Fullbright")

    -- Server
    local server = newTab("Server")
    action(server, "Rejoin", "Rejoin", function() rejoin() end)
    action(server, "Server Hop", "Hop", function() serverHop() end)
    action(server, "Copy Job ID", "Copy", function(b)
        if setclipboard then setclipboard(game.JobId); b.Text = "Copied" else b.Text = "N/A" end
        task.delay(1, function() b.Text = "Copy" end)
    end)

    -- Misc
    local misc = newTab("Misc")
    toggle(misc, "Anti-AFK", "AntiAFK")
    toggle(misc, "Anti-Kick (client)", "AntiKick", function(on) G.EggHubAntiKick = on end)

    -- Config
    local cf = newTab("Config")
    action(cf, "Save Config", "Save", function(b) save(); b.Text = "Saved"; task.delay(1, function() b.Text = "Save" end) end)
    action(cf, "Destroy Hub", "Destroy", function() if G.EggHubCleanup then G.EggHubCleanup() end end)

    showTab("Farm")

    bind(UIS.InputBegan, function(i, gp)
        if not gp and i.KeyCode == CFG.MenuKey then win.Visible = not win.Visible end
    end)

    G.EggHubCleanup = function()
        alive = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        pcall(stopFly)
        pcall(clearESP)
        pcall(function() gui:Destroy() end)
        G.EggHubCleanup = nil
    end
end

local ok, err = pcall(main)
if not ok then
    warn("[EggHub] erro: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "EggHub erro", Text = tostring(err):sub(1, 200), Duration = 20,
        })
    end)
end
