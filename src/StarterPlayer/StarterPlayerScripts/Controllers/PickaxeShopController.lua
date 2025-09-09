local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickaxeShopController = {}

function PickaxeShopController.init()
    local player = Players.LocalPlayer
    local PickaxeDefs = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PickaxeDefs"))
    local shopsFolder = workspace:WaitForChild("PickaxeShops")

    local leaderstats = player:WaitForChild("leaderstats")
    local gems = leaderstats:WaitForChild("Gems")
    local owned = player:WaitForChild("OwnedPickaxes")

    local currentPrompt

    local function findFirstAncestorWithAttribute(instance, attribute)
        local parent = instance.Parent
        while parent do
            if parent:GetAttribute(attribute) ~= nil then
                return parent
            end
            parent = parent.Parent
        end
        return nil
    end

    local function getPrice(stand, id)
        local price = stand:GetAttribute("Price")
        local def = PickaxeDefs[id]
        if (price == nil or price == 0) and def then
            price = def.price
        end
        return price
    end

    local function refresh(prompt)
        local stand = findFirstAncestorWithAttribute(prompt, "PickaxeId") or prompt.Parent
        if not stand then return end

        local id = stand:GetAttribute("PickaxeId")
        if not id or id == "" then
            local fromName = stand.Name:match("^Stand(.+)$")
            if fromName then
                id = fromName:lower()
            end
        end
        if not id then return end

        local def = PickaxeDefs[id]

        if not def then return end

        prompt.ObjectText = def.name

        local price = getPrice(stand, id)
        if not price then return end
        local ownedFlag = owned:FindFirstChild(id)
        if ownedFlag and ownedFlag.Value then
            prompt.ActionText = "Equipar"
        else
            local gemValue = gems.Value
            if gemValue >= price then
                prompt.ActionText = ("Comprar (%d Gemas)"):format(price)
            else
                prompt.ActionText = ("Faltan %d Gemas"):format(price - gemValue)
            end
        end
    end

    ProximityPromptService.PromptShown:Connect(function(prompt)
        if prompt:IsDescendantOf(shopsFolder) then
            currentPrompt = prompt
            refresh(prompt)
        end
    end)

    ProximityPromptService.PromptHidden:Connect(function(prompt)
        if prompt == currentPrompt then
            currentPrompt = nil
        end
    end)

    gems.Changed:Connect(function()
        if currentPrompt then
            refresh(currentPrompt)
        end
    end)

    local function onOwnedChanged()
        if currentPrompt then
            refresh(currentPrompt)
        end
    end
    owned.ChildAdded:Connect(onOwnedChanged)
    owned.ChildRemoved:Connect(onOwnedChanged)

    print("[PickaxeShopController] listo")
end

return PickaxeShopController

