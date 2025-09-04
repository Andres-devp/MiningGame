-- ServerModules/ShopService.lua
-- v1.4 - Buy pickaxe with Gems or DevProduct + persistence (OwnedTools.HasPickaxe)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopService = {}

function ShopService:init()
        -- Config
        local GEM_PRICE = 10
        local PICKAXE_PRODUCT_ID = 3374702806 -- your DevProduct

        local pickaxeTemplate = ReplicatedStorage:WaitForChild("PickaxeModel")
        local pickaxeShop = workspace:WaitForChild("TiendaPico")
        local prompt = pickaxeShop:WaitForChild("ProximityPrompt")

	local function givePickaxe(player)
		local bp = player:FindFirstChild("Backpack")
		if not bp then return end
                if not bp:FindFirstChild("PickaxeModel") then
                        local newPickaxe = pickaxeTemplate:Clone()
                        newPickaxe.Name = "PickaxeModel"
                        newPickaxe.Parent = bp
                end
        end

	local function markOwned(player)
		local owned = player:FindFirstChild("OwnedTools")
		if not owned then
			owned = Instance.new("Folder")
			owned.Name = "OwnedTools"
			owned.Parent = player
		end
		local flag = owned:FindFirstChild("HasPickaxe") or Instance.new("BoolValue")
		flag.Name = "HasPickaxe"
		flag.Parent = owned
                flag.Value = true -- Will persist via LeaderstatsScript
        end

        -- Purchase with Gems
        prompt.Triggered:Connect(function(player)
                local leaderstats = player:FindFirstChild("leaderstats")
                local gems = leaderstats and leaderstats:FindFirstChild("Gems")
                if not gems then return end

                -- If already owned, ensure it's in the Backpack
                local owned = player:FindFirstChild("OwnedTools")
                local has = owned and owned:FindFirstChild("HasPickaxe")
                if has and has.Value then
                        givePickaxe(player)
                        return
                end

                if gems.Value >= GEM_PRICE then
                        gems.Value -= GEM_PRICE
                        markOwned(player)
                        givePickaxe(player)
                else
                        MarketplaceService:PromptProductPurchase(player, PICKAXE_PRODUCT_ID)
                end
        end)

        -- Purchase with Robux
        -- ⚠️ Ensure ONLY this script assigns ProcessReceipt across the game.
        MarketplaceService.ProcessReceipt = function(receiptInfo)
                local userId = receiptInfo.PlayerId
                local productId = receiptInfo.ProductId
                local player = Players:GetPlayerByUserId(userId)
                if not player then
                        return Enum.ProductPurchaseDecision.NotProcessedYet
                end
                if productId == PICKAXE_PRODUCT_ID then
                        markOwned(player)
                        givePickaxe(player)
                        return Enum.ProductPurchaseDecision.PurchaseGranted
                end
                return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        -- If the player already owns it, give it on spawn
        Players.PlayerAdded:Connect(function(player)
                player.CharacterAdded:Connect(function()
                        local owned = player:FindFirstChild("OwnedTools")
                        local has = owned and owned:FindFirstChild("HasPickaxe")
                        if has and has.Value then
                                givePickaxe(player)
                        end
                end)
        end)

        print("[ShopService] Initialized (persistent pickaxe).")
end

return ShopService
