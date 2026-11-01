-- blessedstx | Roube um Ovo | client-side
-- INSERT ou botao "B" abre/fecha | config salva em blessedstx.json
-- sintaxe compativel (sem +=, sem Vector3.one/zero), toda API de executor e opcional

print("[blessedstx] iniciando")

local G
do
    local ok, e = pcall(function() return getgenv() end)
    G = (ok and type(e) == "table") and e or _G
end
if G.blessedCleanup then pcall(G.blessedCleanup) end

local wait_  = (task and task.wait) or wait
local spawn_ = (task and task.spawn) or spawn
local delay_ = (task and task.delay) or delay

local function main()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local Players = game:GetService("Players")
    while not Players.LocalPlayer do wait_(0.1) end
    local lp          = Players.LocalPlayer
    local RunService  = game:GetService("RunService")
    local UIS         = game:GetService("UserInputService")
    local VU          = game:GetService("VirtualUser")
    local HttpService = game:GetService("HttpService")
    local Lighting    = game:GetService("Lighting")
    local TeleportSvc = game:GetService("TeleportService")

    -- ===== CONFIG =====
    local CFG = {
        WalkSpeed = 40, JumpPower = 75, FlySpeed = 60,
        PromptRange = 25, TickS = 0.2,
        PromptMode = "Keywords",           -- "Keywords" | "All"
        RemotePath = "", RemoteArgs = "[]", RemoteInterval = 0.5,
        EggKeywords    = { "egg", "ovo" },
        PromptKeywords = { "steal", "roub", "collect", "colet", "pegar", "grab", "claim" },
        MenuKey = Enum.KeyCode.Insert,
        File = "blessedstx.json",
    }
    local State = {
        Speed = false, InfJump = false, Noclip = false, Fly = false,
        EggESP = false, PlayerESP = false, AutoPrompt = false, AutoRemote = false,
        AntiAFK = true, AntiKick = true, Fullbright = false, LogRemotes = false,
    }
    local NUMS = { "WalkSpeed", "JumpPower", "FlySpeed", "PromptRange", "RemoteInterval" }
    local STRS = { "PromptMode", "RemotePath", "RemoteArgs" }

    local function save()
        if not writefile then return end
        pcall(function()
            local d = { State = State, Nums = {}, Strs = {} }
            for _, k in ipairs(NUMS) do d.Nums[k] = CFG[k] end
            for _, k in ipairs(STRS) do d.Strs[k] = CFG[k] end
            writefile(CFG.File, HttpService:JSONEncode(d))
        end)
    end
    local function loadCfg()
        if not (readfile and isfile) then return end
        pcall(function()
            if not isfile(CFG.File) then return end
            local d = HttpService:JSONDecode(readfile(CFG.File))
            for k, v in pairs(d.State or {}) do if State[k] ~= nil then State[k] = v end end
            for k, v in pairs(d.Nums or {}) do if type(v) == "number" then CFG[k] = v end end
            for k, v in pairs(d.Strs or {}) do if type(v) == "string" then CFG[k] = v end end
        end)
    end
    loadCfg()

    -- ===== HELPERS =====
    local alive = true
    local conns = {}
    local function bind(sig, fn) conns[#conns + 1] = sig:Connect(fn) end
    local function matches(str, list)
        str = string.lower(tostring(str))
        for _, k in ipairs(list) do
            if string.find(str, k, 1, true) then return true end
        end
        return false
    end
    local function char() return lp.Character end
    local function hrp() local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end
    local function hum() local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end

    -- ===== ANTI-AFK =====
    bind(lp.Idled, function()
        if State.AntiAFK then
            pcall(function()
                VU:CaptureController()
                VU:ClickButton2(Vector2.new(0, 0))
            end)
        end
    end)

    -- ===== HOOK: anti-kick (client) + remote logger =====
    -- anti-kick so bloqueia LocalPlayer:Kick() de script local; kick/ban do servidor nao tem como bloquear
    G.blessedAntiKick = State.AntiKick
    G.blessedLogOn = State.LogRemotes
    G.blessedLogs = G.blessedLogs or {}

    local function logRemote(self, m, ...)
        if checkcaller and checkcaller() then return end
        local n = select("#", ...)
        local args = { ... }
        local parts = {}
        for i = 1, math.min(n, 6) do
            local v = args[i]
            local t = typeof(v)
            if t == "string" then
                parts[#parts + 1] = '"' .. string.sub(v, 1, 30) .. '"'
            elseif t == "number" or t == "boolean" then
                parts[#parts + 1] = tostring(v)
            elseif t == "Instance" then
                parts[#parts + 1] = "<" .. v.Name .. ">"
            else
                parts[#parts + 1] = "<" .. t .. ">"
            end
        end
        local line = self:GetFullName() .. ":" .. m .. "(" .. table.concat(parts, ", ") .. ")"
        local logs = G.blessedLogs
        if logs[#logs] ~= line then
            logs[#logs + 1] = line
            if #logs > 40 then table.remove(logs, 1) end
        end
    end

    if hookmetamethod and getnamecallmethod and not G.blessedHooked then
        local ok = pcall(function()
            local old
            local fn = function(self, ...)
                local m = getnamecallmethod()
                if m == "Kick" or m == "kick" then
                    if G.blessedAntiKick and self == lp then return end
                elseif (m == "FireServer" or m == "InvokeServer") and G.blessedLogOn then
                    if typeof(self) == "Instance" then
                        pcall(logRemote, self, m, ...)
                        if setnamecallmethod then setnamecallmethod(m) end
                    end
                end
                return old(self, ...)
            end
            if newcclosure then fn = newcclosure(fn) end
            old = hookmetamethod(game, "__namecall", fn)
        end)
        if ok then G.blessedHooked = true end
    end

    -- ===== SPEED / JUMP / FULLBRIGHT =====
    bind(RunService.Heartbeat, function()
        local h = hum()
        if h and State.Speed then
            h.WalkSpeed = CFG.WalkSpeed
            pcall(function() h.UseJumpPower = true end)
            h.JumpPower = CFG.JumpPower
        end
        if State.Fullbright then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1000000
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
        local h = hum()
        if h then h.PlatformStand = false end
    end
    bind(RunService.RenderStepped, function()
        local r, h = hrp(), hum()
        if not (State.Fly and r and h) then
            if flyBV then stopFly() end
            return
        end
        if not flyBV then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBV.Velocity = Vector3.new(0, 0, 0)
            flyBV.Parent = r
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            flyBG.P = 90000
            flyBG.Parent = r
        end
        h.PlatformStand = true
        local cam = workspace.CurrentCamera
        local dir = Vector3.new(0, 0, 0)
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then
            flyBV.Velocity = dir.Unit * CFG.FlySpeed
        else
            flyBV.Velocity = Vector3.new(0, 0, 0)
        end
        flyBG.CFrame = cam.CFrame
    end)

    -- ===== EGG TRACKING + ESP =====
    local eggs = {}
    local function eggRoot(inst)
        if inst:IsA("BasePart") then return inst end
        if inst:IsA("Model") then
            return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
        end
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

    local pesp = {}
    local function clearESP()
        for _, e in pairs(eggs) do
            if e.hl then e.hl:Destroy(); e.hl = nil end
            if e.gui then e.gui:Destroy(); e.gui = nil end
        end
        for p, h in pairs(pesp) do h:Destroy(); pesp[p] = nil end
    end

    spawn_(function()
        while alive do
            wait_(0.5)
            pcall(function()
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
                                g.Size = UDim2.new(0, 120, 0, 24)
                                g.AlwaysOnTop = true
                                g.StudsOffset = Vector3.new(0, 3, 0)
                                g.Adornee = root
                                local t = Instance.new("TextLabel", g)
                                t.Name = "L"
                                t.Size = UDim2.new(1, 0, 1, 0)
                                t.BackgroundTransparency = 1
                                t.TextColor3 = Color3.new(1, 1, 0.4)
                                t.TextStrokeTransparency = 0
                                t.Font = Enum.Font.GothamBold
                                t.TextSize = 13
                                g.Parent = root
                                e.gui = g
                            end
                            if r then
                                local dist = math.floor((root.Position - r.Position).Magnitude)
                                e.gui.L.Text = inst.Name .. " [" .. dist .. "m]"
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
                                h.FillColor = Color3.fromRGB(255, 60, 60)
                                h.FillTransparency = 0.7
                                h.Adornee = c
                                h.Parent = c
                                pesp[pl] = h
                            end
                        elseif pesp[pl] then
                            pesp[pl]:Destroy()
                            pesp[pl] = nil
                        end
                    end
                end
            end)
        end
    end)

    local function tpNearestEgg()
        local r = hrp()
        if not r then return end
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
    local function firePrompt(p)
        if fireproximityprompt then
            pcall(fireproximityprompt, p)
        else
            pcall(function()
                p:InputHoldBegin()
                wait_(0.05)
                p:InputHoldEnd()
            end)
        end
    end
    spawn_(function()
        while alive do
            wait_(CFG.TickS)
            local r = hrp()
            if State.AutoPrompt and r then
                for p in pairs(prompts) do
                    pcall(function()
                        local okMatch = CFG.PromptMode == "All"
                            or matches(p.ActionText, CFG.PromptKeywords)
                            or matches(p.ObjectText, CFG.EggKeywords)
                        if p.Enabled and okMatch then
                            local pos = promptPos(p)
                            if pos and (pos - r.Position).Magnitude <= math.min(CFG.PromptRange, p.MaxActivationDistance + 5) then
                                p.HoldDuration = 0
                                firePrompt(p)
                            end
                        end
                    end)
                end
            end
        end
    end)

    -- ===== AUTO REMOTE (steal/collect) =====
    -- 1) liga "Log Remotes" na aba Log, rouba um ovo na mao
    -- 2) copia o caminho do remote em Farm > Remote Path e os args (JSON, ex: ["abc",1]) em Remote Args
    local function resolvePath(path)
        local cur = game
        for seg in string.gmatch(path, "[^%.]+") do
            if not (seg == "game" and cur == game) then
                local nxt = cur:FindFirstChild(seg)
                if not nxt and cur == game then
                    local ok, svc = pcall(function() return game:GetService(seg) end)
                    if ok then nxt = svc end
                end
                if not nxt then return nil end
                cur = nxt
            end
        end
        return cur
    end
    spawn_(function()
        while alive do
            wait_(math.max(0.05, tonumber(CFG.RemoteInterval) or 0.5))
            if State.AutoRemote and CFG.RemotePath ~= "" then
                pcall(function()
                    local rem = resolvePath(CFG.RemotePath)
                    if not rem then return end
                    local okd, args = pcall(function() return HttpService:JSONDecode(CFG.RemoteArgs) end)
                    if not okd or type(args) ~= "table" then args = {} end
                    if rem:IsA("RemoteEvent") then
                        rem:FireServer(unpack(args))
                    elseif rem:IsA("RemoteFunction") then
                        spawn_(function() pcall(function() rem:InvokeServer(unpack(args)) end) end)
                    end
                end)
            end
        end
    end)

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
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
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
    local gui = Instance.new("ScreenGui")
    gui.Name = "blessedstx"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    pcall(function() gui.IgnoreGuiInset = true end)
    pcall(function() gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    pcall(function() if protect_gui then protect_gui(gui) end end)

    -- tenta gethui -> CoreGui -> PlayerGui e confirma que realmente prendeu
    local function attach()
        local cands = {}
        if gethui then
            local ok, h = pcall(gethui)
            if ok and h then cands[#cands + 1] = h end
        end
        cands[#cands + 1] = game:GetService("CoreGui")
        cands[#cands + 1] = lp:WaitForChild("PlayerGui")
        for _, c in ipairs(cands) do
            local ok = pcall(function() gui.Parent = c end)
            if ok and gui.Parent == c then return c end
        end
        return nil
    end
    local where = attach()
    if not where then error("nao consegui prender a GUI em nenhum parent") end

    local C = {
        red   = Color3.fromRGB(205, 30, 42),
        redHi = Color3.fromRGB(240, 70, 80),
        redLo = Color3.fromRGB(150, 15, 25),
        bg    = Color3.fromRGB(18, 18, 22),
        row   = Color3.fromRGB(30, 30, 35),
        off   = Color3.fromRGB(55, 55, 62),
        white = Color3.new(1, 1, 1),
    }
    local function round(o, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 6)
        c.Parent = o
    end
    local function stroke(o, col, th)
        local s = Instance.new("UIStroke")
        s.Color = col
        s.Thickness = th or 1
        s.Parent = o
    end
    local function label(parent, text, size, font)
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Text = text
        t.TextColor3 = C.white
        t.Font = font or Enum.Font.GothamBold
        t.TextSize = size or 16
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = parent
        return t
    end

    local W, H = 580, 400
    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, W, 0, H)
    win.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
    win.BackgroundColor3 = C.bg
    win.BorderSizePixel = 0
    win.Parent = gui
    round(win, 8)
    stroke(win, C.redLo, 2)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 40)
    bar.BackgroundColor3 = C.red
    bar.BorderSizePixel = 0
    bar.Parent = win
    round(bar, 8)
    stroke(bar, C.redLo, 2)
    local ttl = label(bar, "blessedstx", 22, Enum.Font.GothamBlack)
    ttl.Size = UDim2.new(1, 0, 1, 0)
    ttl.TextXAlignment = Enum.TextXAlignment.Center

    local xb = Instance.new("TextButton")
    xb.Size = UDim2.new(0, 34, 0, 28)
    xb.Position = UDim2.new(1, -42, 0.5, -14)
    xb.BackgroundColor3 = C.redLo
    xb.BorderSizePixel = 0
    xb.Text = "X"
    xb.TextColor3 = C.white
    xb.Font = Enum.Font.GothamBlack
    xb.TextSize = 18
    xb.Parent = bar
    round(xb, 4)
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
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    -- botao flutuante "B"
    local fab = Instance.new("TextButton")
    fab.Size = UDim2.new(0, 40, 0, 40)
    fab.Position = UDim2.new(0, 12, 0, 200)
    fab.BackgroundColor3 = C.red
    fab.BorderSizePixel = 0
    fab.Text = "B"
    fab.TextColor3 = C.white
    fab.Font = Enum.Font.GothamBlack
    fab.TextSize = 20
    fab.Parent = gui
    round(fab, 20)
    stroke(fab, C.redLo, 2)
    fab.MouseButton1Click:Connect(function() win.Visible = not win.Visible end)

    -- coluna de abas
    local tabCol = Instance.new("Frame")
    tabCol.Size = UDim2.new(0, 120, 0, H - 56)
    tabCol.Position = UDim2.new(0, 8, 0, 48)
    tabCol.BackgroundTransparency = 1
    tabCol.Parent = win
    local tcl = Instance.new("UIListLayout")
    tcl.Padding = UDim.new(0, 6)
    tcl.Parent = tabCol

    -- search
    local sb = Instance.new("Frame")
    sb.Size = UDim2.new(1, -144, 0, 34)
    sb.Position = UDim2.new(0, 136, 1, -42)
    sb.BackgroundColor3 = C.row
    sb.BorderSizePixel = 0
    sb.Parent = win
    round(sb, 6)
    stroke(sb, C.redLo, 1)
    local sl = label(sb, "Search", 14)
    sl.Size = UDim2.new(0, 60, 0, 34)
    sl.Position = UDim2.new(0, 10, 0, 0)
    local search = Instance.new("TextBox")
    search.Size = UDim2.new(1, -80, 1, -10)
    search.Position = UDim2.new(0, 72, 0, 5)
    search.BackgroundColor3 = C.bg
    search.BorderSizePixel = 0
    search.ClearTextOnFocus = false
    search.PlaceholderText = "Filter features..."
    search.Text = ""
    search.TextColor3 = C.white
    search.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
    search.Font = Enum.Font.Gotham
    search.TextSize = 13
    search.TextXAlignment = Enum.TextXAlignment.Left
    search.Parent = sb
    round(search, 4)

    local pages, tabBtns, current = {}, {}, nil
    local function applyFilter()
        local q = string.lower(search.Text)
        local pg = pages[current]
        if not pg then return end
        for _, row in ipairs(pg.rows) do
            row.frame.Visible = (q == "") or (string.find(string.lower(row.name), q, 1, true) ~= nil)
        end
    end
    local function showTab(name)
        current = name
        for n, p in pairs(pages) do p.scroll.Visible = (n == name) end
        for n, b in pairs(tabBtns) do
            b.BackgroundColor3 = (n == name) and C.redHi or C.red
        end
        applyFilter()
    end
    search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    local function newTab(name)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 38)
        b.BackgroundColor3 = C.red
        b.BorderSizePixel = 0
        b.Text = name
        b.TextColor3 = C.white
        b.Font = Enum.Font.GothamBlack
        b.TextSize = 17
        b.Parent = tabCol
        round(b, 5)
        stroke(b, C.redLo, 2)
        b.MouseButton1Click:Connect(function() showTab(name) end)
        tabBtns[name] = b

        local s = Instance.new("ScrollingFrame")
        s.Size = UDim2.new(1, -144, 1, -100)
        s.Position = UDim2.new(0, 136, 0, 48)
        s.BackgroundTransparency = 1
        s.BorderSizePixel = 0
        s.ScrollBarThickness = 4
        s.ScrollBarImageColor3 = C.red
        s.CanvasSize = UDim2.new(0, 0, 0, 0)
        pcall(function() s.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
        s.Visible = false
        s.Parent = win
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 6)
        l.Parent = s
        local pg = { scroll = s, rows = {} }
        pages[name] = pg
        return pg
    end

    local function newRow(pg, name, labelFrac)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -8, 0, 38)
        f.BackgroundColor3 = C.row
        f.BorderSizePixel = 0
        f.Parent = pg.scroll
        round(f, 5)
        stroke(f, C.redLo, 1)
        local t = label(f, name, 16)
        t.Size = UDim2.new(labelFrac or 0.55, 0, 1, 0)
        t.Position = UDim2.new(0, 10, 0, 0)
        pg.rows[#pg.rows + 1] = { frame = f, name = name }
        return f
    end

    local function toggle(pg, name, key, onChange)
        local f = newRow(pg, name)
        local track = Instance.new("TextButton")
        track.Size = UDim2.new(0, 52, 0, 24)
        track.Position = UDim2.new(1, -62, 0.5, -12)
        track.BorderSizePixel = 0
        track.Text = ""
        track.Parent = f
        round(track, 12)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.BackgroundColor3 = C.white
        knob.BorderSizePixel = 0
        knob.Parent = track
        round(knob, 9)
        local function paint()
            if State[key] then
                track.BackgroundColor3 = C.red
                knob.Position = UDim2.new(1, -21, 0.5, -9)
            else
                track.BackgroundColor3 = C.off
                knob.Position = UDim2.new(0, 3, 0.5, -9)
            end
        end
        track.MouseButton1Click:Connect(function()
            State[key] = not State[key]
            paint()
            save()
            if onChange then onChange(State[key]) end
        end)
        paint()
    end
    local function box(f, w, text)
        local b = Instance.new("TextBox")
        b.Size = UDim2.new(0, w, 0, 26)
        b.Position = UDim2.new(1, -(w + 10), 0.5, -13)
        b.BackgroundColor3 = C.bg
        b.BorderSizePixel = 0
        b.TextColor3 = C.white
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.ClearTextOnFocus = false
        b.Text = text
        b.Parent = f
        round(b, 4)
        stroke(b, C.redLo, 1)
        return b
    end
    local function numInput(pg, name, key)
        local f = newRow(pg, name)
        local b = box(f, 90, tostring(CFG[key]))
        b.FocusLost:Connect(function()
            local n = tonumber(b.Text)
            if n then CFG[key] = n; save() else b.Text = tostring(CFG[key]) end
        end)
    end
    local function textInput(pg, name, key)
        local f = newRow(pg, name, 0.38)
        local b = box(f, 190, tostring(CFG[key]))
        b.FocusLost:Connect(function()
            CFG[key] = b.Text
            save()
        end)
    end
    local function dropdown(pg, name, key, options)
        local f = newRow(pg, name)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 110, 0, 26)
        b.Position = UDim2.new(1, -120, 0.5, -13)
        b.BackgroundColor3 = C.bg
        b.BorderSizePixel = 0
        b.TextColor3 = C.white
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.Text = tostring(CFG[key])
        b.Parent = f
        round(b, 4)
        stroke(b, C.redLo, 1)
        b.MouseButton1Click:Connect(function()
            local idx = 1
            for i, o in ipairs(options) do
                if o == CFG[key] then idx = i end
            end
            CFG[key] = options[(idx % #options) + 1]
            b.Text = CFG[key]
            save()
        end)
    end
    local function action(pg, name, btnText, cb)
        local f = newRow(pg, name)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 90, 0, 26)
        b.Position = UDim2.new(1, -100, 0.5, -13)
        b.BackgroundColor3 = C.red
        b.BorderSizePixel = 0
        b.TextColor3 = C.white
        b.Font = Enum.Font.GothamBlack
        b.TextSize = 14
        b.Text = btnText
        b.Parent = f
        round(b, 4)
        b.MouseButton1Click:Connect(function() cb(b) end)
    end
    local function flash(b, txt, back)
        b.Text = txt
        delay_(1, function() b.Text = back end)
    end

    -- Farm
    local farm = newTab("Farm")
    toggle(farm, "Auto Prompt", "AutoPrompt")
    dropdown(farm, "Prompt Mode", "PromptMode", { "Keywords", "All" })
    numInput(farm, "Prompt Range", "PromptRange")
    action(farm, "Move To Egg", "Teleport", function() tpNearestEgg() end)
    toggle(farm, "Auto Remote", "AutoRemote")
    textInput(farm, "Remote Path", "RemotePath")
    textInput(farm, "Remote Args", "RemoteArgs")
    numInput(farm, "Remote Delay", "RemoteInterval")

    -- Player
    local player = newTab("Player")
    toggle(player, "Speed / Jump", "Speed", function(on)
        if not on then
            local h = hum()
            if h then h.WalkSpeed = 16; h.JumpPower = 50 end
        end
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
        if setclipboard then
            setclipboard(game.JobId)
            flash(b, "Copied", "Copy")
        else
            flash(b, "N/A", "Copy")
        end
    end)

    -- Misc
    local misc = newTab("Misc")
    toggle(misc, "Anti-AFK", "AntiAFK")
    toggle(misc, "Anti-Kick (client)", "AntiKick", function(on) G.blessedAntiKick = on end)

    -- Log (remote logger)
    local logTab = newTab("Log")
    toggle(logTab, "Log Remotes", "LogRemotes", function(on) G.blessedLogOn = on end)
    action(logTab, "Clear", "Clear", function() G.blessedLogs = {} end)
    action(logTab, "Copy Log", "Copy", function(b)
        if setclipboard then
            setclipboard(table.concat(G.blessedLogs, "\n"))
            flash(b, "Copied", "Copy")
        else
            flash(b, "N/A", "Copy")
        end
    end)
    local logLabel = Instance.new("TextLabel")
    logLabel.Size = UDim2.new(1, -8, 0, 120)
    pcall(function() logLabel.AutomaticSize = Enum.AutomaticSize.Y end)
    logLabel.BackgroundColor3 = C.row
    logLabel.BorderSizePixel = 0
    logLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
    logLabel.Font = Enum.Font.Code
    logLabel.TextSize = 12
    logLabel.TextWrapped = true
    logLabel.TextXAlignment = Enum.TextXAlignment.Left
    logLabel.TextYAlignment = Enum.TextYAlignment.Top
    logLabel.Text = ""
    logLabel.Parent = logTab.scroll
    round(logLabel, 5)

    spawn_(function()
        while alive do
            wait_(0.5)
            if current == "Log" and win.Visible then
                if #G.blessedLogs == 0 then
                    logLabel.Text = hookmetamethod and "ligue Log Remotes e faca a acao no jogo" or "executor sem hookmetamethod: logger indisponivel"
                else
                    logLabel.Text = table.concat(G.blessedLogs, "\n")
                end
            end
        end
    end)

    -- Config
    local cf = newTab("Config")
    action(cf, "Save Config", "Save", function(b) save(); flash(b, "Saved", "Save") end)
    action(cf, "Destroy", "Destroy", function()
        if G.blessedCleanup then G.blessedCleanup() end
    end)

    showTab("Farm")

    bind(UIS.InputBegan, function(i, gp)
        if not gp and i.KeyCode == CFG.MenuKey then win.Visible = not win.Visible end
    end)

    G.blessedCleanup = function()
        alive = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        pcall(stopFly)
        pcall(clearESP)
        pcall(function() gui:Destroy() end)
        G.blessedCleanup = nil
    end

    print("[blessedstx] carregado em " .. tostring(where))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "blessedstx", Text = "carregado | INSERT ou botao B", Duration = 6,
        })
    end)
end

local ok, err = pcall(main)
if not ok then
    warn("[blessedstx] erro: " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "blessedstx erro", Text = string.sub(tostring(err), 1, 200), Duration = 20,
        })
    end)
end
