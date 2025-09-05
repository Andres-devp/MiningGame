

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local sellRequest = Remotes:WaitForChild("SellRequest")

local DataService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("DataService"))

local SellService = {}

local function sellStones(player)
        local stones = player:FindFirstChild("Stones")
        if not stones or stones.Value <= 0 then return end
        local amount = stones.Value
        stones.Value = 0
        
        DataService.addResource(player, "gems", amount * 2)
end

function SellService:init()
        sellRequest.OnServerEvent:Connect(function(player, kind)
                if kind == "All" or kind == "Rocks" or kind == "Selected" then
                        sellStones(player)
                end
        end)
        print("[SellService] Initialized")
end

return SellService

