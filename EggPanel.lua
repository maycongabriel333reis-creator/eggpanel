-- blessedstx | tecla padrão: RightShift
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("blessedstx") then parentGui.blessedstx:Destroy() end

-- ===== TEMA =====
local C = {
    bg = Color3.fromRGB(16, 16, 22),
    panel = Color3.fromRGB(24, 24, 34),
    item = Color3.fromRGB(34, 34, 48),
    accent = Color3.fromRGB(124, 92, 255),
    on = Color3.fromRGB(70, 200, 120),
    text = Color3.fromRGB(235, 235, 245),
    sub = Color3.fromRGB(150, 150, 170),
}

local cfg = {
    antiAfk = true,
    autoCollect = false,
    autoFarm = false,
    interval = 0.5,
    toggleKey = Enum.KeyCode.RightShift,
}

-- ===== HELPERS =====
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
local function tween(o, t, props)
    TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad), props):Play()
end

-- ===== GUI BASE =====
local gui = new("ScreenGui", { Name = "blessedstx", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, parentGui)

local main = new("Frame", {
    Size = UDim2.fromOffset(420, 300),
    Position = UDim2.new(0.5, -210, 0.5, -150),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(main, 10)
new("UIStroke", { Color = C.accent, Thickness = 1, Transparency = 0.5 }, main)

local top = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, main)
new("TextLabel", {
    Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1, Text = "blessedstx", Font = Enum.Font.GothamBold,
    TextSize = 17, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
}, top)

local minBtn = new("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -66, 0, 6),
    BackgroundColor3 = C.item, Text = "–", Font = Enum.Font.GothamBold,
    TextSize = 16, TextColor3 = C.text, BorderSizePixel = 0,
}, top)
corner(minBtn, 6)
local closeBtn = new("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0, 6),
    BackgroundColor3 = Color3.fromRGB(200, 60, 70), Text = "×", Font = Enum.Font.GothamBold,
    TextSize = 16, TextColor3 = C.text, BorderSizePixel = 0,
}, top)
corner(closeBtn, 6)

-- abas
local tabBar = new("Frame", { Size = UDim2.new(0, 110, 1, -40), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, main)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, tabBar)

local content = new("Frame", { Size = UDim2.new(1, -110, 1, -40), Position = UDim2.fromOffset(110, 40), BackgroundTransparency = 1 }, main)

local pages, tabButtons = {}, {}
local function createTab(name, order)
    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
    }, content)
    new("UIListLayout", { Padding = UDim.new(0, 8) }, page)

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = C.item, Text = name,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = C.sub,
        BorderSizePixel = 0, LayoutOrder = order,
    }, tabBar)
    corner(btn, 6)
    btn.MouseButton1Click:Connect(function()
        for n, p in pairs(pages) do
            p.Visible = (n == name)
            tabButtons[n].TextColor3 = (n == name) and C.text or C.sub
            tween(tabButtons[n], 0.15, { BackgroundColor3 = (n == name) and C.accent or C.item })
        end
    end)
    pages[name], tabButtons[name] = page, btn
    return page
end

-- ===== COMPONENTES =====
local function addToggle(page, label, key, onChange)
    local row = new("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.panel, Text = "", BorderSizePixel = 0, AutoButtonColor = false }, page)
    corner(row, 8)
    new("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
        Text = label, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local track = new("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -52, 0.5, -10), BorderSizePixel = 0 }, row)
    corner(track, 10)
    local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.text, BorderSizePixel = 0 }, track)
    corner(knob, 8)
    local function refresh(animate)
        local on = cfg[key]
        local t = animate and 0.15 or 0
        tween(track, t, { BackgroundColor3 = on and C.on or C.item })
        tween(knob, t, { Position = on and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) })
    end
    row.MouseButton1Click:Connect(function()
        cfg[key] = not cfg[key]
        refresh(true)
        if onChange then onChange(cfg[key]) end
    end)
    refresh(false)
end

local function addSlider(page, label, key, min, max, step)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, page)
    corner(row, 8)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 4), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local bar = new("Frame", { Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 0, 34), BackgroundColor3 = C.item, BorderSizePixel = 0 }, row)
    corner(bar, 3)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, bar)
    corner(fill, 3)

    local function set(v)
        v = math.clamp(math.floor(v / step + 0.5) * step, min, max)
        cfg[key] = v
        lbl.Text = string.format("%s: %.2f", label, v)
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
    end
    set(cfg[key])

    local sliding = false
    local function fromInput(i)
        set(min + (max - min) * math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1))
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            sliding = true; fromInput(i)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end)
end

-- notificações
local notifHolder = new("Frame", { Size = UDim2.fromOffset(260, 300), Position = UDim2.new(1, -276, 1, -316), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6) }, notifHolder)
local function notify(text, dur)
    local n = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.panel, Text = "  " .. text,
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0, BackgroundTransparency = 1, TextTransparency = 1,
    }, notifHolder)
    corner(n, 8)
    tween(n, 0.2, { BackgroundTransparency = 0, TextTransparency = 0 })
    task.delay(dur or 3, function()
        tween(n, 0.25, { BackgroundTransparency = 1, TextTransparency = 1 })
        task.wait(0.3); n:Destroy()
    end)
end

-- ===== ABAS =====
local pMain = createTab("Principal", 1)
local pCfg = createTab("Config", 2)

addToggle(pMain, "Anti-AFK", "antiAfk", function(v) notify("Anti-AFK " .. (v and "ligado" or "desligado")) end)
addToggle(pMain, "Auto coletar ovos", "autoCollect", function(v) notify("Auto coletar " .. (v and "ligado" or "desligado")) end)
addToggle(pMain, "Auto farm", "autoFarm", function(v) notify("Auto farm " .. (v and "ligado" or "desligado")) end)

addSlider(pCfg, "Intervalo do loop (s)", "interval", 0.1, 3, 0.05)

local keyRow = new("TextButton", {
    Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.panel, BorderSizePixel = 0,
    Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, AutoButtonColor = false,
}, pCfg)
corner(keyRow, 8)
local listening = false
local function refreshKey() keyRow.Text = "Tecla do painel: " .. cfg.toggleKey.Name end
refreshKey()
keyRow.MouseButton1Click:Connect(function() listening = true; keyRow.Text = "Pressione uma tecla..." end)

-- ===== LÓGICA =====
player.Idled:Connect(function()
    if cfg.antiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

local function collectEggs()
    -- FILL: ex: game.ReplicatedStorage.Remotes.CollectEgg:FireServer(...)
end
local function farmStep()
    -- FILL: lógica de auto-farm do jogo
end

task.spawn(function()
    while gui.Parent do
        task.wait(cfg.interval)
        if cfg.autoCollect then pcall(collectEggs) end
        if cfg.autoFarm then pcall(farmStep) end
    end
end)

GuiService.ErrorMessageChanged:Connect(function(msg)
    if msg and msg ~= "" then
        warn("[blessedstx] desconectado: " .. msg)
        notify("Desconectado: " .. msg, 8)
    end
end)

-- ===== ARRASTAR / MINIMIZAR / FECHAR / TECLA =====
local dragging, dragStart, startPos
top.InputBegan:Connect(function(i)
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
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    tween(main, 0.2, { Size = minimized and UDim2.fromOffset(420, 40) or UDim2.fromOffset(420, 300) })
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

UIS.InputBegan:Connect(function(i, gp)
    if listening and i.UserInputType == Enum.UserInputType.Keyboard then
        cfg.toggleKey = i.KeyCode; listening = false; refreshKey()
        notify("Tecla alterada para " .. i.KeyCode.Name)
        return
    end
    if not gp and i.KeyCode == cfg.toggleKey then main.Visible = not main.Visible end
end)

-- abre na primeira aba
tabButtons["Principal"]:Activate()
pages["Principal"].Visible = true
tabButtons["Principal"].BackgroundColor3 = C.accent
tabButtons["Principal"].TextColor3 = C.text
notify("blessedstx carregado")
