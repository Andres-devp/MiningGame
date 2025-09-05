

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
        local UPDATE_COOLDOWN = 30
        local lastUpdate = {}

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

        local function updatePlayerScore(player, force)
                if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Gems") then
                        local userId = player.UserId
                        if not force then
                                local now = os.clock()
                                if lastUpdate[userId] and (now - lastUpdate[userId]) < UPDATE_COOLDOWN then
                                        return
                                end
                                lastUpdate[userId] = now
                        end
                        local gemsValue = player.leaderstats.Gems.Value
                        pcall(function()
                                gemsLeaderboardStore:SetAsync(userId, gemsValue)
                        end)
                end
        end

	Players.PlayerAdded:Connect(function(player)
		local leaderstats = player:WaitForChild("leaderstats")
		local gems = leaderstats:WaitForChild("Gems")
                gems.Changed:Connect(function()
                        updatePlayerScore(player, false)
                end)
	end)

	Players.PlayerRemoving:Connect(function(player)
                updatePlayerScore(player, true)
	end)

	
	local leaderboardLoop = coroutine.wrap(function()
		while true do
			pcall(updateLeaderboard)
			wait(UPDATE_INTERVAL)
		end
	end)

	leaderboardLoop() 
	print("[LeaderboardHandler] Inicializado.")
end

return LeaderboardHandler