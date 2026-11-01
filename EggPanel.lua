--[[
    file: src/init.lua
    desc: núcleo do Chilli Pro Hub
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ==============================
-- CONFIG GLOBAL
-- ==============================
local Config = {
    -- farm
    AutoFarm = false,
    FarmMode = "Smart Tween",      -- Smart Tween | Teleport | Walk
    TeleportZones = true,
    StealPriority = "Highest Value", -- Highest Value | Nearest | Rarity
    MinRarity = "Eternal",
    MinStealValue = 0,
    Delivery = true,
    -- player
    Speed = 50,
    JumpPower = 100,
    Fly = false,
    Noclip = false,
    -- misc
    AntiGuard = false,
    AutoRejoin = false,
    -- internal
    TickMs = 0.01,
    RarityOrder = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Eternal=6},
}

-- ==============================
-- UTILS
-- ==============================
local Utils = {}

function Utils.getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Utils.getHRP()
    local c = Utils.getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Utils.getHum()
    local c = Utils.getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Utils.dist(a, b)
    return (a - b).Magnitude
end

function Utils.tweenTo(pos, speed, cb)
    local hrp = Utils.getHRP()
    if not hrp then return end
    local d = Utils.dist(hrp.Position, pos)
    local t = TweenService:Create(hrp,
        TweenInfo.new(d / math.max(speed, 1), Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(pos)}
    )
    if cb then t.Completed:Connect(cb) end
    t:Play()
    return t
end

function Utils.notify(title, text, dur)
    if Rayfield and Rayfield.Notify then
        Rayfield:Notify({Title = title, Content = text, Duration = dur or 4})
    end
end

-- ==============================
-- EGG MANAGER
-- ==============================
local EggManager = {}

function EggManager.getAll()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name:lower():find("egg") or v:FindFirstChild("ClickDetector")) then
            local meta = {
                part = v,
                pos = v.Position,
                name = v.Name,
                rarity = "Common",
                value = 0,
            }
            -- tentativa de ler atributos comuns
            local ok, r = pcall(function() return v:GetAttribute("Rarity") end)
            if ok and r then meta.rarity = r end
            local ok2, val = pcall(function() return v:GetAttribute("Value") end)
            if ok2 and val then meta.value = val end
            table.insert(list, meta)
        end
    end
    return list
end

function EggManager.pick(eggs)
    if #eggs == 0 then return nil end
    local hrp = Utils.getHRP()
    if not hrp then return nil end

    if Config.StealPriority == "Nearest" then
        table.sort(eggs, function(a, b)
            return Utils.dist(hrp.Position, a.pos) < Utils.dist(hrp.Position, b.pos)
        end)
    elseif Config.StealPriority == "Highest Value" then
        table.sort(eggs, function(a, b) return a.value > b.value end)
    elseif Config.StealPriority == "Rarity" then
        table.sort(eggs, function(a, b)
            return (Config.RarityOrder[a.rarity] or 0) > (Config.RarityOrder[b.rarity] or 0)
        end)
    end

    local best = eggs[1]
    if best and best.value < Config.MinStealValue then
        return nil
    end
    if best and (Config.RarityOrder[best.rarity] or 0) < (Config.RarityOrder[Config.MinRarity] or 0) then
        return nil
    end
    return best
end

-- ==============================
-- FEATURES
-- ==============================
local Features = {}

function Features.antiGuard()
    if not Config.AntiGuard then return end
    local char = Utils.getChar()
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = hum.MaxHealth
        hum.WalkSpeed = Config.Speed
        hum.JumpPower = Config.JumpPower
    end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not Config.Noclip
        end
    end
end

function Features.fly()
    if not Config.Fly then return end
    local hrp = Utils.getHRP()
    local hum = Utils.getHum()
    if not hrp or not hum then return end
    local cam = Workspace.CurrentCamera
    local dir = Vector3.zero
    if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
    if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
    if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
    if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
    hrp.CFrame = hrp.CFrame + dir * (Config.Speed / 60)
    hrp.Velocity = Vector3.zero
end

function Features.farm()
    if not Config.AutoFarm then return end
    local eggs = EggManager.getAll()
    local target = EggManager.pick(eggs)
    if not target then return end

    if Config.FarmMode == "Teleport" then
        local hrp = Utils.getHRP()
        if hrp then hrp.CFrame = CFrame.new(target.pos) end
    elseif Config.FarmMode == "Walk" then
        local hum = Utils.getHum()
        if hum and Utils.getHRP() then
            hum:MoveTo(target.pos)
        end
    else -- Smart Tween
        Utils.tweenTo(target.pos, Config.Speed)
    end

    local cd = target.part:FindFirstChild("ClickDetector")
    if cd then
        pcall(fireclickdetector, cd)
    end
end

-- ==============================
-- LOOP
-- ==============================
local acc = 0
RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < Config.TickMs then return end
    acc = 0
    Features.antiGuard()
    Features.fly()
    Features.farm()
end)

-- ==============================
-- UI
-- ==============================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Chilli Pro",
    LoadingTitle = "Chilli Pro",
    LoadingSubtitle = "advanced egg framework",
    Theme = "Amethyst",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChilliPro",
        FileName = "Config",
    },
    KeySystem = false,
})

local FarmTab = Window:CreateTab("Farm", 4483362458)
FarmTab:CreateToggle({ Name = "Auto Farm", CurrentValue = false, Flag = "AutoFarm",
    Callback = function(v) Config.AutoFarm = v end })

FarmTab:CreateDropdown({ Name = "Farm Mode", Options = {"Smart Tween","Teleport","Walk"},
    CurrentOption = "Smart Tween", Flag = "FarmMode",
    Callback = function(o) Config.FarmMode = o end })

FarmTab:CreateDropdown({ Name = "Steal Priority", Options = {"Highest Value","Nearest","Rarity"},
    CurrentOption = "Highest Value", Flag = "StealPriority",
    Callback = function(o) Config.StealPriority = o end })

FarmTab:CreateDropdown({ Name = "Min Rarity",
    Options = {"Common","Uncommon","Rare","Epic","Legendary","Eternal"},
    CurrentOption = "Eternal", Flag = "MinRarity",
    Callback = function(o) Config.MinRarity = o end })

FarmTab:CreateSlider({ Name = "Min Steal Value", Range = {0,100000}, Increment = 100,
    Suffix = " coins", CurrentValue = 0, Flag = "MinStealValue",
    Callback = function(v) Config.MinStealValue = v end })

FarmTab:CreateToggle({ Name = "Teleport Zones", CurrentValue = true, Flag = "TeleportZones",
    Callback = function(v) Config.TeleportZones = v end })

FarmTab:CreateToggle({ Name = "Delivery", CurrentValue = true, Flag = "Delivery",
    Callback = function(v) Config.Delivery = v end })

local PlayerTab = Window:CreateTab("Player", 4483362458)
PlayerTab:CreateSlider({ Name = "Speed", Range = {16,300}, Increment = 1,
    Suffix = " studs", CurrentValue = 50, Flag = "Speed",
    Callback = function(v) Config.Speed = v end })
PlayerTab:CreateSlider({ Name = "Jump Power", Range = {50,400}, Increment = 1,
    Suffix = " studs", CurrentValue = 100, Flag = "JumpPower",
    Callback = function(v) Config.JumpPower = v end })
PlayerTab:CreateToggle({ Name = "Fly", CurrentValue = false, Flag = "Fly",
    Callback = function(v) Config.Fly = v end })
PlayerTab:CreateToggle({ Name = "Noclip", CurrentValue = false, Flag = "Noclip",
    Callback = function(v) Config.Noclip = v end })

local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateToggle({ Name = "Anti Guard", CurrentValue = false, Flag = "AntiGuard",
    Callback = function(v) Config.AntiGuard = v end })
MiscTab:CreateToggle({ Name = "Auto Rejoin", CurrentValue = false, Flag = "AutoRejoin",
    Callback = function(v) Config.AutoRejoin = v end })
MiscTab:CreateButton({ Name = "Move To Egg", Callback = function()
    local eggs = EggManager.getAll()
    local t = EggManager.pick(eggs)
    if t then Utils.tweenTo(t.pos, Config.Speed) end
end })

local SettingsTab = Window:CreateTab("Settings", 4483362458)
SettingsTab:CreateButton({ Name = "Save Config", Callback = function() Rayfield:SaveConfiguration() end })
SettingsTab:CreateButton({ Name = "Load Config", Callback = function() Rayfield:LoadConfiguration() end })

Utils.notify("Chilli Pro", "carregado, boa caçada", 5)
