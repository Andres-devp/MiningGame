-- Ubicación: ServerScriptService > ServerModules > LeaderboardHandler

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardHandler = {}

local gemsLeaderboardStore = DataStoreService:GetOrderedDataStore("GemsLeaderboard_V1")

function LeaderboardHandler:init()
	local leaderboardDisplay = workspace:WaitForChild("LeaderboardDisplay")
	local surfaceGui = leaderboardDisplay:WaitForChild("SurfaceGui")
	local container = surfaceGui:WaitForChild("Container")
	local template = container:WaitForChild("Template")
	local UPDATE_INTERVAL = 60

	local function updateLeaderboard()
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "Template" then
				child:Destroy()
			end
		end

		local pages = gemsLeaderboardStore:GetSortedAsync(false, 10)
		local topTen = pages:GetCurrentPage()

		for rank, data in ipairs(topTen) do
			local userId = tonumber(data.key)
			local gems = data.value
			local playerName = "Cargando..."

			pcall(function()
				playerName = Players:GetNameFromUserIdAsync(userId)
			end)

			local newEntry = template:Clone()
			newEntry.Name = playerName
			newEntry.RankLabel.Text = "#" .. rank
			newEntry.NameLabel.Text = playerName
			newEntry.GemsLabel.Text = gems
			newEntry.Visible = true
			newEntry.Parent = container
		end
	end

	local function updatePlayerScore(player)
		if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Gems") then
			local gemsValue = player.leaderstats.Gems.Value
			pcall(function()
				gemsLeaderboardStore:SetAsync(player.UserId, gemsValue)
			end)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		local leaderstats = player:WaitForChild("leaderstats")
		local gems = leaderstats:WaitForChild("Gems")
		gems.Changed:Connect(function()
			updatePlayerScore(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		updatePlayerScore(player)
	end)

	-- Usamos coroutine.wrap para que el bucle no bloquee el resto del script
	local leaderboardLoop = coroutine.wrap(function()
		while true do
			pcall(updateLeaderboard)
			wait(UPDATE_INTERVAL)
		end
	end)

	leaderboardLoop() -- Iniciamos el bucle
	print("[LeaderboardHandler] Inicializado.")
end

return LeaderboardHandler