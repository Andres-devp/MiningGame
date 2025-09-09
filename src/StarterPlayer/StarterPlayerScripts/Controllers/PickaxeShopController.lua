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

    local function getPrice(stand, id)
        local price = stand:GetAttribute("Price")
        local def = PickaxeDefs[id]
        if price == nil and def then
            price = def.price
        end
        return price
    end

      local function refresh(prompt)
          local stand = prompt:FindFirstAncestorWithAttribute("PickaxeId")
          if not stand then return end
          local id = stand:GetAttribute("PickaxeId")
          if not id then return end
          local def = PickaxeDefs[id]
        if not def then return end

        prompt.ObjectText = def.name

        local price = getPrice(stand, id)
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

