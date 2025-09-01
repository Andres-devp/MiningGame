-- Controllers/SaleDialogController.lua
-- Maneja el diálogo con el vendedor para realizar conversiones de objetos

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dialog = require(ReplicatedStorage:WaitForChild("Dialog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local sellRequest = Remotes:WaitForChild("SellRequest")

local M = {}

function M.init()

    local shops = workspace:WaitForChild("Shops")
    local npcContainer = shops:WaitForChild("SaleShop")
    local npc = npcContainer:WaitForChild("SaleShop")

    local prompt = npc:WaitForChild("ProximityPrompt")

    local dialogObject = Dialog.new("Shop", npc, prompt)
    dialogObject:addDialog(
        "¿Tienes algo para vender?",
        {
            "1) Vender todo: rocas y minerales",
            "2) Vender rocas",
            "3) Vender solo lo que tengo seleccionado",
            "4) Cuanto me dan por lo que tengo en rocas",
            "5) Nada",
        }
    )

    prompt.Triggered:Connect(function(player)
        dialogObject:triggerDialog(player, 1)
    end)

    dialogObject.responded:Connect(function(responseNum, dialogNum)
        if dialogNum ~= 1 then return end
        if responseNum == 1 then
            sellRequest:FireServer("All")
            dialogObject:hideGui("¡Todo vendido!")
        elseif responseNum == 2 then
            sellRequest:FireServer("Rocks")
            dialogObject:hideGui("Vendiste tus rocas")
        elseif responseNum == 3 then
            sellRequest:FireServer("Selected")
            dialogObject:hideGui("Revisa tu inventario")
        elseif responseNum == 4 then
            local player = Players.LocalPlayer
            local stones = player:FindFirstChild("Stones")
            local amount = stones and stones.Value or 0
            dialogObject:hideGui("Te darían " .. amount .. " gemas")
        else
            dialogObject:hideGui()
        end
    end)

    print("[SaleDialogController] listo")
end

return M

