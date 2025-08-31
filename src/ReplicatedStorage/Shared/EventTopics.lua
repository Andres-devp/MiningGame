-- ReplicatedStorage/Shared/EventTopics.lua
-- Enum de tópicos para EventBus (cliente/servidor)

return {
	-- Minería
	MiningRequest       = "mining/request",
	MiningCrystalStart  = "mining/crystal/start",
	MiningCrystalStop   = "mining/crystal/stop",
	MiningFeedback      = "mining/feedback",      -- server -> client: { kind, position }
	MiningCrystalAck    = "mining/crystal/ack",   -- server -> client: { ok }

	-- AutoMine/GamePass
	AutoMineSyncRequest   = "automine/sync-request",   -- client -> server (reverifica ownership)
	AutoMineToggleRequest = "automine/toggle-request", -- client -> server (togglear si posee)
}
