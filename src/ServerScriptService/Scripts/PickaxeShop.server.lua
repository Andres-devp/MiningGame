local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickaxeDefs = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PickaxeDefs"))

local TOOLS_PATH = ServerStorage:WaitForChild("Tools"):WaitForChild("Pickaxes")
local SHOPS_FOLDER = workspace:WaitForChild("PickaxeShops")

local ID_TO_TOOL = {
    basic = "PickaxeBasic",
    copper = "PickaxeCopper",
    iron = "PickaxeIron",
    gold = "PickaxeGold",
    crystal = "PickaxeCrystal",
}

local function equipPickaxe(player, id)
    local toolName = ID_TO_TOOL[id]
    if not toolName then return end

    for _, container in ipairs({player.Backpack, player.Character}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool.Name:match("^Pickaxe") then
                    tool:Destroy()
                end
            end
        end
    end

    local template = TOOLS_PATH:FindFirstChild(toolName)
    if not template then return end

    local newTool = template:Clone()
    local def = PickaxeDefs[id]
    if def then
        newTool:SetAttribute("Power", def.power)
        newTool:SetAttribute("Cooldown", def.cooldown)
        newTool:SetAttribute("AOE", def.aoe)
        newTool:SetAttribute("Id", id)
    end

    newTool.Parent = player.Backpack

    local sg = player:FindFirstChild("StarterGear")
    if sg then
        local clone2 = newTool:Clone()
        clone2.Parent = sg
    end
end

local function handlePurchase(prompt, player)
    local stand = prompt:FindFirstAncestorWithAttribute("PickaxeId")
    if not stand then return end
    local id = stand:GetAttribute("PickaxeId")
    if not id then return end
    local price = stand:GetAttribute("Price")
    local def = PickaxeDefs[id]
    if price == nil and def then
        price = def.price
    end
    if price == nil then return end

    local ownedFolder = player:FindFirstChild("OwnedPickaxes")
    if not ownedFolder then return end
    local owned = ownedFolder:FindFirstChild(id)

    local leaderstats = player:FindFirstChild("leaderstats")
    local gems = leaderstats and leaderstats:FindFirstChild("Gems")
    if not gems then return end

    if owned and owned.Value then
        equipPickaxe(player, id)
        return
    end

    if gems.Value >= price then
        gems.Value -= price
        if not owned then
            owned = Instance.new("BoolValue")
            owned.Name = id
            owned.Value = true
            owned.Parent = ownedFolder
        else
            owned.Value = true
        end
        equipPickaxe(player, id)
    else
        local original = prompt.ActionText
        prompt.ActionText = "Faltan gemas"
        task.delay(1.2, function()
            if prompt then
                prompt.ActionText = original
            end
        end)
    end
end

local function connectStand(stand)
    local prompt = stand:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then return end
    prompt.Triggered:Connect(function(player)
        handlePurchase(prompt, player)
    end)
end

for _, stand in ipairs(SHOPS_FOLDER:GetChildren()) do
    connectStand(stand)
end

SHOPS_FOLDER.ChildAdded:Connect(connectStand)

Players.PlayerAdded:Connect(function(player)
    local owned = Instance.new("Folder")
    owned.Name = "OwnedPickaxes"
    owned.Parent = player

    local basic = Instance.new("BoolValue")
    basic.Name = "basic"
    basic.Value = true
    basic.Parent = owned
end)
