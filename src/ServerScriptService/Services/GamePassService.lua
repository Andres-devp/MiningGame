

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Shared   = ReplicatedStorage:WaitForChild("Shared")
local EventBus = require(Shared:WaitForChild("events"):WaitForChild("EventBus"))
local Topics   = require(Shared:WaitForChild("events"):WaitForChild("EventTopics"))

local AUTOMINE_PASS_ID = 1406821381

local GamePassService = {}

local function ensureValues(player: Player)
	
	local owns = player:FindFirstChild("OwnsAutoMinePass")
	if not owns then
		owns = Instance.new("BoolValue")
		owns.Name = "OwnsAutoMinePass"
		owns.Value = false
		owns.Parent = player
	end

	local enabled = player:FindFirstChild("AutoMineEnabled")
	if not enabled then
		enabled = Instance.new("BoolValue")
		enabled.Name = "AutoMineEnabled"
		enabled.Value = false
		enabled.Parent = player
	end

	return owns, enabled
end

local function refreshOwnership(player: Player)
	local owns, _ = ensureValues(player)
	local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, AUTOMINE_PASS_ID)
	if not ok then
		warn(("[GamePass] Falló UserOwnsGamePassAsync para %s"):format(player.Name))
		return false
	end

	local before = owns.Value
	owns.Value = has and true or false

	
	if (not before) and owns.Value then
		local _, enabled = ensureValues(player)
		enabled.Value = true
	end

	return owns.Value
end

local function toggleAutoMine(player: Player)
	local owns, enabled = ensureValues(player)
	if not owns.Value then
		
		return
	end
	enabled.Value = not enabled.Value
end

local function onPlayerAdded(player: Player)
	ensureValues(player)
	refreshOwnership(player)
end

local function onPlayerRemoving(player: Player)
	
end

function GamePassService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	
	for _, p in ipairs(Players:GetPlayers()) do
		task.defer(onPlayerAdded, p)
	end

	
	EventBus.registerServer(Topics.AutoMineSyncRequest, function(player, _payload)
		refreshOwnership(player)
	end)

	EventBus.registerServer(Topics.AutoMineToggleRequest, function(player, _payload)
		toggleAutoMine(player)
	end)

	print("[GamePassService] Inicializado (server-driven AutoMine).")
end

return GamePassService
