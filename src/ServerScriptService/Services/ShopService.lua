-- ServerScriptService/Services/ShopService.lua
-- v1.4 - Compra de pico por Gemas o DevProduct + persistencia (OwnedTools.HasPickaxe)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ManejadorTienda = {}

function ManejadorTienda:init()
	-- Config
	local PRECIO_GEMAS = 10
	local ID_PRODUCTO_PICO = 3374702806 -- tu DevProduct

	local picoTemplate = ReplicatedStorage:WaitForChild("PickaxeModel")
	local tienda = workspace:WaitForChild("TiendaPico")
	local prompt = tienda:WaitForChild("ProximityPrompt")

	local function givePickaxe(player)
		local bp = player:FindFirstChild("Backpack")
		if not bp then return end
		if not bp:FindFirstChild("PickaxeModel") then
			local nuevo = picoTemplate:Clone()
			nuevo.Name = "PickaxeModel"
			nuevo.Parent = bp
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
		flag.Value = true -- Persistirá vía LeaderstatsScript
	end

	-- Compra con Gemas
	prompt.Triggered:Connect(function(player)
		local ls = player:FindFirstChild("leaderstats")
		local gems = ls and ls:FindFirstChild("Gems")
		if not gems then return end

		-- Si ya lo posee, solo entregamos por si no está en Backpack
		local owned = player:FindFirstChild("OwnedTools")
		local has = owned and owned:FindFirstChild("HasPickaxe")
		if has and has.Value then
			givePickaxe(player)
			return
		end

		if gems.Value >= PRECIO_GEMAS then
			gems.Value -= PRECIO_GEMAS
			markOwned(player)
			givePickaxe(player)
		else
			MarketplaceService:PromptProductPurchase(player, ID_PRODUCTO_PICO)
		end
	end)

	-- Compra con Robux
	-- ⚠️ Asegúrate de que SOLO este script asigne ProcessReceipt en todo el juego.
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local userId = receiptInfo.PlayerId
		local productId = receiptInfo.ProductId
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if productId == ID_PRODUCTO_PICO then
			markOwned(player)
			givePickaxe(player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Si el jugador ya lo posee, entrégalo al aparecer
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local owned = player:FindFirstChild("OwnedTools")
			local has = owned and owned:FindFirstChild("HasPickaxe")
			if has and has.Value then
				givePickaxe(player)
			end
		end)
	end)

	print("[ManejadorTienda] Inicializado (pico persistente).")
end

return ManejadorTienda
