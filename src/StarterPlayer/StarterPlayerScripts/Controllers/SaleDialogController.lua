-- Controllers/SaleDialogController.lua
-- Maneja el diálogo con el vendedor para realizar conversiones de objetos

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dialog = require(ReplicatedStorage:WaitForChild("Dialog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local sellRequest = Remotes:WaitForChild("SellRequest")

local M = {}

function M.init()
    local npc = workspace:WaitForChild("SaleShop")
    local prompt = npc:WaitForChild("ProximityPrompt")

    local dialogObject = Dialog.new("Shop", npc, prompt)
    dialogObject:addDialog(
        "Got anything to sell?",
        {
            "I want to sell my inventory",
            "I want to sell this",
            "How much is this worth?",
            "Nevermind",
        }
    )

    prompt.Triggered:Connect(function(player)
        dialogObject:triggerDialog(player, 1)
    end)

    dialogObject.responded:Connect(function(responseNum, dialogNum)
        if dialogNum ~= 1 then return end
        if responseNum == 1 then
            sellRequest:FireServer("All")
            dialogObject:hideGui("All sold!")
        elseif responseNum == 2 then
            sellRequest:FireServer("Rocks")
            dialogObject:hideGui("Sold your rocks")
        elseif responseNum == 3 then
            sellRequest:FireServer("Selected")
            dialogObject:hideGui("Check your inventory")
        else
            dialogObject:hideGui()
        end
    end)

    print("[SaleDialogController] listo")
end

return M

