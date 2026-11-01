-- steal an egg — chilli-style hub (open source, no loader)
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/yourname/yourrepo/main/egg_hub.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- config block
local CONFIG = {
    TickMs = 4,
    AutoFarm = false,
    FarmMode = "Fast Tween",
    TeleportZones = true,
    StealPriority = "Highest Value",
    TargetAreas = true,
    MinRarity = "Eternal",
    MinStealValue = 0,
    MoveToEgg = false,
    Delivery = true,
    AntiGuard = false,
    Speed = 50,
    JumpPower = 100,
    Fly = false,
    Noclip = false,
}

-- helpers
local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local c = getChar()
    return c:FindFirstChild("HumanoidRootPart")
end

local function tweenTo(pos, speed)
    local hrp = getHRP()
    if not hrp then return end
    local dist = (hrp.Position - pos).Magnitude
    local t = TweenService:Create(hrp, TweenInfo.new(dist / speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(pos)})
    t:Play()
end

-- anti guard (basic bypass for common guards)
local function antiGuard()
    if not CONFIG.AntiGuard then return end
    local char = getChar()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = hum.MaxHealth
        hum.WalkSpeed = CONFIG.Speed
        hum.JumpPower = CONFIG.JumpPower
    end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not CONFIG.Noclip
        end
    end
end

-- find eggs
local function getEggs()
    local eggs = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:lower():find("egg") and obj:IsA("BasePart") then
            table.insert(eggs, obj)
        end
    end
    return eggs
end

-- main loop
RunService.Heartbeat:Connect(function()
    antiGuard()

    if CONFIG.MoveToEgg then
        local eggs = getEggs()
        if #eggs > 0 then
            local target = eggs[1]
            tweenTo(target.Position, CONFIG.Speed)
        end
    end

    if CONFIG.AutoFarm then
        local eggs = getEggs()
        for _, egg in ipairs(eggs) do
            if egg:FindFirstChild("ClickDetector") then
                fireclickdetector(egg.ClickDetector)
            end
        end
    end
end)

-- UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Chilli Hub",
    LoadingTitle = "Chilli Hub",
    LoadingSubtitle = "by Gorilla",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChilliHub",
        FileName = "Config"
    },
    KeySystem = false
})

-- Farm tab
local FarmTab = Window:CreateTab("Farm", 4483362458)
FarmTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = false,
    Flag = "AutoFarm",
    Callback = function(v) CONFIG.AutoFarm = v end
})

FarmTab:CreateDropdown({
    Name = "Farm Mode",
    Options = {"Fast Tween", "Teleport", "Walk"},
    CurrentOption = "Fast Tween",
    Flag = "FarmMode",
    Callback = function(opt) CONFIG.FarmMode = opt end
})

FarmTab:CreateToggle({
    Name = "Teleport Zones",
    CurrentValue = true,
    Flag = "TeleportZones",
    Callback = function(v) CONFIG.TeleportZones = v end
})

FarmTab:CreateDropdown({
    Name = "Steal Priority",
    Options = {"Highest Value", "Lowest Value", "Nearest"},
    CurrentOption = "Highest Value",
    Flag = "StealPriority",
    Callback = function(opt) CONFIG.StealPriority = opt end
})

FarmTab:CreateToggle({
    Name = "Target Areas",
    CurrentValue = true,
    Flag = "TargetAreas",
    Callback = function(v) CONFIG.TargetAreas = v end
})

FarmTab:CreateDropdown({
    Name = "Min Rarity",
    Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Eternal"},
    CurrentOption = "Eternal",
    Flag = "MinRarity",
    Callback = function(opt) CONFIG.MinRarity = opt end
})

FarmTab:CreateSlider({
    Name = "Min Steal Value",
    Range = {0, 100000},
    Increment = 100,
    Suffix = " coins",
    CurrentValue = 0,
    Flag = "MinStealValue",
    Callback = function(v) CONFIG.MinStealValue = v end
})

-- Event tab
local EventTab = Window:CreateTab("Event", 4483362458)
EventTab:CreateButton({
    Name = "Move To Egg",
    Callback = function()
        CONFIG.MoveToEgg = not CONFIG.MoveToEgg
    end
})

EventTab:CreateToggle({
    Name = "Delivery",
    CurrentValue = true,
    Flag = "Delivery",
    Callback = function(v) CONFIG.Delivery = v end
})

-- Player tab
local PlayerTab = Window:CreateTab("Player", 4483362458)
PlayerTab:CreateSlider({
    Name = "Speed",
    Range = {16, 200},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 50,
    Flag = "Speed",
    Callback = function(v) CONFIG.Speed = v end
})

PlayerTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 300},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 100,
    Flag = "JumpPower",
    Callback = function(v) CONFIG.JumpPower = v end
})

PlayerTab:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Flag = "Fly",
    Callback = function(v) CONFIG.Fly = v end
})

PlayerTab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "Noclip",
    Callback = function(v) CONFIG.Noclip = v end
})

-- Misc tab
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateToggle({
    Name = "Anti Guard",
    CurrentValue = false,
    Flag = "AntiGuard",
    Callback = function(v) CONFIG.AntiGuard = v end
})

-- Config tab
local ConfigTab = Window:CreateTab("Config", 4483362458)
ConfigTab:CreateButton({
    Name = "Save Config",
    Callback = function() Rayfield:SaveConfiguration() end
})

ConfigTab:CreateButton({
    Name = "Load Config",
    Callback = function() Rayfield:LoadConfiguration() end
})

-- bottom toggle (Anti Guard quick access)
Rayfield:Notify({
    Title = "Chilli Hub",
    Content = "Loaded. Toggle Anti Guard in Misc.",
    Duration = 5
})
