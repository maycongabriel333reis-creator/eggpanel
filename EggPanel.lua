--[[
    Chilli Hub Pro - Steal a Brainrot
    Versão limpa e open-source reescrita a partir de análise de script ofuscado.
    Uso: loadstring(game:HttpGet("https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/brainrot_hub.lua"))()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- CONFIG GLOBAL
-- ==========================================
local Config = {
    AutoSteal = false,
    AutoBuy = false,
    AutoClaim = false,
    Treadmill = false,
    Halloween = false,
    Noclip = false,
    Speed = 50,
    Jump = 100,
    StealPriority = "Highest Value", -- "Highest Value", "Nearest", "Rarity"
    MinValue = 0,
    TickRate = 0.1,
    
    -- Valores base extraídos do script original (ajuste conforme o jogo atualiza)
    EggValues = {
        Common = 1500, Uncommon = 15000, Rare = 100000, Epic = 1000000, 
        Legendary = 10000000, Mythic = 100000000, Divine = 1000000000, 
        Eternal = 15000000000, Secret = 50000000000
    },
    
    RarityOrder = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6, Divine=7, Eternal=8, Secret=9}
}

-- ==========================================
-- UTILS
-- ==========================================
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

function Utils.walkTo(pos, speed)
    local hrp, hum = Utils.getHRP(), Utils.getHum()
    if not hrp or not hum then return false end
    local dist = Utils.dist(hrp.Position, pos)
    hum.WalkSpeed = speed or Config.Speed
    
    -- Tween simples para movimento suave
    local tween = TweenService:Create(hrp, TweenInfo.new(dist / (speed or Config.Speed), Enum.EasingStyle.Linear), {CFrame = CFrame.new(pos)})
    tween:Play()
    tween.Completed:Wait()
    return true
end

function Utils.notify(title, text, dur)
    if Rayfield and Rayfield.Notify then
        Rayfield:Notify({Title = title, Content = text, Duration = dur or 4})
    end
end

-- ==========================================
-- LÓGICA DO JOGO (Remotes e Objetos)
-- ==========================================
local GameLogic = {}

-- No script original, ele usava InvokeServer em Remotes específicos.
-- Como não temos o dump exato, usamos a lógica padrão do jogo:
function GameLogic.getPlots()
    local plots = {}
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("Plot") and v.Plot:FindFirstChild("Eggs") then
            table.insert(plots, v)
        end
    end
    return plots
end

function GameLogic.getEggs()
    local eggs = {}
    local plots = GameLogic.getPlots()
    for _, plot in ipairs(plots) do
        for _, egg in ipairs(plot.Plot.Eggs:GetChildren()) do
            local clickDetector = egg:FindFirstChildWhichIsA("ClickDetector", true)
            local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
            local rarity = egg:GetAttribute("Rarity") or "Common"
            local value = Config.EggValues[rarity] or 0
            
            table.insert(eggs, {
                model = egg,
                pos = egg:GetPivot().Position,
                rarity = rarity,
                value = value,
                prompt = prompt,
                detector = clickDetector
            })
        end
    end
    return eggs
end

function GameLogic.pickBest(eggs)
    if #eggs == 0 then return nil end
    local hrp = Utils.getHRP()
    
    if Config.StealPriority == "Nearest" and hrp then
        table.sort(eggs, function(a, b) return Utils.dist(hrp.Position, a.pos) < Utils.dist(hrp.Position, b.pos) end)
    elseif Config.StealPriority == "Highest Value" then
        table.sort(eggs, function(a, b) return a.value > b.value end)
    elseif Config.StealPriority == "Rarity" then
        table.sort(eggs, function(a, b) return (Config.RarityOrder[a.rarity] or 0) > (Config.RarityOrder[b.rarity] or 0) end)
    end
    
    local best = eggs[1]
    if best.value < Config.MinValue then return nil end
    return best
end

-- ==========================================
-- FEATURES
-- ==========================================
local Features = {}

function Features.steal()
    if not Config.AutoSteal then return end
    local eggs = GameLogic.getEggs()
    local target = GameLogic.pickBest(eggs)
    if not target then return end

    Utils.walkTo(target.pos, Config.Speed)
    
    if target.prompt then
        pcall(fireproximityprompt, target.prompt)
    elseif target.detector then
        pcall(fireclickdetector, target.detector)
    end
end

function Features.treadmill()
    if not Config.Treadmill then return end
    -- Busca a esteira na base do jogador
    local myPlot = GameLogic.getPlots()[1]
    if myPlot then
        local treadmill = myPlot:FindFirstChild("Treadmill", true)
        if treadmill then
            local hrp = Utils.getHRP()
            if hrp and Utils.dist(hrp.Position, treadmill.Position) > 5 then
                Utils.walkTo(treadmill.Position, Config.Speed)
            end
        end
    end
end

function Features.halloween()
    if not Config.Halloween then return end
    -- Lógica adaptada do script original para o evento
    local hrp = Utils.getHRP()
    if not hrp then return end
    
    -- Exemplo: buscar doces no workspace e entregar
    local candyFolder = Workspace:FindFirstChild("Candies")
    if candyFolder then
        for _, candy in ipairs(candyFolder:GetChildren()) do
            if candy:IsA("BasePart") then
                Utils.walkTo(candy.Position, Config.Speed)
                local prompt = candy:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then pcall(fireproximityprompt, prompt) end
            end
        end
    end
end

function Features.applyPhysics()
    local char = Utils.getChar()
    local hum = Utils.getHum()
    if not hum or not char then return end
    
    hum.WalkSpeed = Config.Speed
    hum.JumpPower = Config.Jump
    
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not Config.Noclip
        end
    end
end

-- Loop Principal
RunService.Heartbeat:Connect(function()
    Features.applyPhysics()
    Features.steal()
    Features.treadmill()
    Features.halloween()
end)

-- ==========================================
-- UI (Rayfield)
-- ==========================================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Chilli Hub Pro",
    LoadingTitle = "Chilli Hub Pro",
    LoadingSubtitle = "Steal a Brainrot | Open Source",
    Theme = "Amethyst",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "ChilliHub",
        FileName = "Config"
    },
    KeySystem = false
})

-- Tab: Farm
local FarmTab = Window:CreateTab("Farm", 4483362458)
FarmTab:CreateToggle({Name = "Auto Steal", CurrentValue = false, Flag = "AutoSteal", Callback = function(v) Config.AutoSteal = v end})
FarmTab:CreateDropdown({
    Name = "Steal Priority",
    Options = {"Highest Value", "Nearest", "Rarity"},
    CurrentOption = "Highest Value",
    Flag = "StealPriority",
    Callback = function(opt) Config.StealPriority = opt end
})
FarmTab:CreateSlider({
    Name = "Min Value to Steal",
    Range = {0, 10000000000},
    Increment = 1000000,
    Suffix = " coins",
    CurrentValue = 0,
    Flag = "MinValue",
    Callback = function(v) Config.MinValue = v end
})
FarmTab:CreateToggle({Name = "Auto Buy", CurrentValue = false, Flag = "AutoBuy", Callback = function(v) Config.AutoBuy = v end})
FarmTab:CreateToggle({Name = "Auto Claim", CurrentValue = false, Flag = "AutoClaim", Callback = function(v) Config.AutoClaim = v end})

-- Tab: Base
local BaseTab = Window:CreateTab("Base", 4483362458)
BaseTab:CreateToggle({Name = "Treadmill Farm", CurrentValue = false, Flag = "Treadmill", Callback = function(v) Config.Treadmill = v end})
BaseTab:CreateParagraph({Title = "Eventos", Content = "Funcionalidades do evento de Halloween e especiais."})
BaseTab:CreateToggle({Name = "Halloween Auto", CurrentValue = false, Flag = "Halloween", Callback = function(v) Config.Halloween = v end})

-- Tab: Player
local PlayerTab = Window:CreateTab("Player", 4483362458)
PlayerTab:CreateSlider({Name = "Speed", Range = {16, 300}, Increment = 1, Suffix = " studs", CurrentValue = 50, Flag = "Speed", Callback = function(v) Config.Speed = v end})
PlayerTab:CreateSlider({Name = "Jump Power", Range = {50, 300}, Increment = 1, Suffix = " studs", CurrentValue = 100, Flag = "Jump", Callback = function(v) Config.Jump = v end})
PlayerTab:CreateToggle({Name = "Noclip", CurrentValue = false, Flag = "Noclip", Callback = function(v) Config.Noclip = v end})

-- Tab: Settings
local SettingsTab = Window:CreateTab("Settings", 4483362458)
SettingsTab:CreateButton({Name = "Save Config", Callback = function() Rayfield:SaveConfiguration() end})
SettingsTab:CreateButton({Name = "Load Config", Callback = function() Rayfield:LoadConfiguration() end})

Utils.notify("Chilli Hub Pro", "Carregado com sucesso.", 5)
