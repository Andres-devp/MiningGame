-- ReplicatedStorage/Shared/events/EventBus.lua
-- Seguro para cliente y servidor. REQUIERE: ReplicatedStorage/Remotes/Net (RemoteEvent)

local RS         = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = RS:WaitForChild("Remotes")
local Net     = Remotes:WaitForChild("Net") -- RemoteEvent

local EventBus = {}
local serverHandlers = {}
local clientHandlers = {}

-- ===== CLIENTE → SERVIDOR =====
function EventBus.sendToServer(topic: string, payload: any)
	if RunService:IsClient() then
		Net:FireServer(topic, payload)
	end
end

-- ===== SERVIDOR =====
function EventBus.registerServer(topic: string, fn)
	serverHandlers[topic] = fn
end

if RunService:IsServer() then
	Net.OnServerEvent:Connect(function(player, topic, payload)
		local h = serverHandlers[topic]
		if h then h(player, payload) end
	end)
end

function EventBus.sendToClient(player, topic: string, payload: any)
	if RunService:IsServer() then
		Net:FireClient(player, topic, payload)
	end
end

-- ===== CLIENTE =====
function EventBus.registerClient(topic: string, fn)
	clientHandlers[topic] = fn
end

if RunService:IsClient() then
	Net.OnClientEvent:Connect(function(topic, payload)
		local h = clientHandlers[topic]
		if h then h(payload) end
	end)
end

return EventBus
