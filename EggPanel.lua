-- blessedstx panel | RightShift abre/fecha
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- evita duplicar o painel
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("blessedstx") then parentGui.blessedstx:Destroy() end

local state = { antiAfk = true, autoCollect = false, autoFarm = false }

-- ===== ANTI-AFK =====
player.Idled:Connect(function()
    if state.antiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- ===== GANCHOS DO JOGO (preencha com o Remote Spy) =====
local function collectEggs()
    -- FILL: ex: game.ReplicatedStorage.Remotes.CollectEgg:FireServer(...)
end

local function farmStep()
    -- FILL: lógica de auto-farm do jogo
end

task.spawn(function()
    while task.wait(0.5) do
        if state.autoCollect then pcall(collectEggs) end
        if state.autoFarm then pcall(farmStep) end
    end
end)

-- ===== LOG DE KICK (só funciona se o jogo avisar o motivo) =====
game:GetService("GuiService").ErrorMessageChanged:Connect(function(msg)
    if msg and msg ~= "" then warn("[blessedstx] desconectado: " .. msg) end
end)

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "blessedstx"
gui.ResetOnSpawn = false
gui.Parent = parentGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(240, 190)
frame.Position = UDim2.new(0.5, -120, 0.5, -95)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
title.BorderSizePixel = 0
title.Text = "blessedstx"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local function addToggle(label, key, y)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1, -24, 0, 32)
    b.Position = UDim2.new(0, 12, 0, y)
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.TextColor3 = Color3.new(1, 1, 1)
    b.BorderSizePixel = 0
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local function refresh()
        b.Text = label .. ": " .. (state[key] and "ON" or "OFF")
        b.BackgroundColor3 = state[key] and Color3.fromRGB(50, 150, 80) or Color3.fromRGB(50, 50, 65)
    end
    b.MouseButton1Click:Connect(function() state[key] = not state[key]; refresh() end)
    refresh()
end

addToggle("Anti-AFK", "antiAfk", 48)
addToggle("Auto Coletar Ovos", "autoCollect", 88)
addToggle("Auto Farm", "autoFarm", 128)

-- arrastar
local dragging, dragStart, startPos
title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, i.Position, frame.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- abrir/fechar
UIS.InputBegan:Connect(function(i, gp)
    if not gp and i.KeyCode == Enum.KeyCode.RightShift then frame.Visible = not frame.Visible end
end)
