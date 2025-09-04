-- ServerScriptService/Services/MiningService.lua
-- v4.1 clean: EventBus + NodeService + RateLimiter (sin RemoteEvents legacy)

local Players            = game:GetService("Players")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local Workspace          = game:GetService("Workspace")
local Debris             = game:GetService("Debris")

-- Services
local NodeService  = require(script.Parent:WaitForChild("NodeService"))
local DataService  = require(script.Parent:WaitForChild("DataService"))
local RateLimiter  = require(script.Parent:WaitForChild("RateLimiter"))

-- EventBus / Topics
local Shared     = ReplicatedStorage:WaitForChild("Shared")
local EventBus   = require(Shared:WaitForChild("events"):WaitForChild("EventBus"))
local Topics     = require(Shared:WaitForChild("events"):WaitForChild("EventTopics"))

-- Parámetros gameplay
local MAX_DISTANCE   = 18
local CRYSTAL_TIME   = 1.4
local CRYSTAL_REWARD = 5
local FAIL_GRACE     = 0.20

-- Anti-spam
local STONE_BURST      = 6
local STONE_REFILL     = 6
local STONE_MIN_GAP    = 0.20

local CRYSTAL_BURST    = 2
local CRYSTAL_REFILL   = 1.5
local CRYSTAL_MIN_GAP  = 0.50

local MiningService = {}

-- Estado por jugador
local activeCrystal: {[Player]: {model: Model, t0: number, lastValid: number, focus: BasePart?}} = {}
local limits: {[Player]: {stone: any, crystal: any}} = {}

-- ========= Helpers =========
local function getHRP(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function distOK(player, part)
	local hrp = getHRP(player)
	return (hrp and part) and ((hrp.Position - part.Position).Magnitude <= MAX_DISTANCE) or false
end

local function hasTagDeep(model: Model, tag: string): boolean
	if CollectionService:HasTag(model, tag) then return true end
	if model.PrimaryPart and CollectionService:HasTag(model.PrimaryPart, tag) then return true end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and CollectionService:HasTag(d, tag) then
			return true
		end
	end
	return false
end

local function focusPart(model: Model?): BasePart?
	if not model then return nil end
	local hit = model:FindFirstChild("Hitbox")
	if hit and hit:IsA("BasePart") then return hit end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function ownsPlotForModel(player, model)
	local plotName = player:GetAttribute("PlotName") or (player:FindFirstChild("PlotName") and player.PlotName.Value)
	if not plotName or plotName == "" then return true end
	local plots = Workspace:FindFirstChild("Plots")
	local myPlot = plots and plots:FindFirstChild(plotName)
	return (myPlot and model:IsDescendantOf(myPlot)) or false
end

local function hasPickaxeServer(player)
	local ch = player.Character
	if not ch then return false end
	if ch:FindFirstChild("PickaxeModel") then return true end
	for _, inst in ipairs(ch:GetChildren()) do
		if inst:IsA("Tool") and (inst.Name:lower():find("pick") or CollectionService:HasTag(inst, "Pickaxe")) then
			return true
		end
	end
	local flag = player:FindFirstChild("PickaxeEquipped")
	return (flag and flag.Value) or false
end

local function ensureLimiters(player: Player)
	local l = limits[player]
	if l then return l end
	l = {
		stone   = RateLimiter.new(STONE_BURST,   STONE_REFILL,   STONE_MIN_GAP),
		crystal = RateLimiter.new(CRYSTAL_BURST, CRYSTAL_REFILL, CRYSTAL_MIN_GAP),
	}
	limits[player] = l
	return l
end

-- coerce payload → Model con NodeService
local function coerceNode(payload): Model?
	if typeof(payload) ~= "table" then return nil end

	local inst = payload.node
	local id   = payload.nodeId

	if typeof(inst) == "Instance" and inst:IsA("Model") then
		return inst
	end

	if typeof(id) == "string" and #id > 0 then
		local byIdx = NodeService.getById(id)
		if byIdx then return byIdx end

		local byName = Workspace:FindFirstChild(id, true)
		if byName and byName:IsA("Model") then return byName end
	end

	return nil
end

-- ========= Piedras =========
local function mineStone(player, model: Model)
	local l = ensureLimiters(player)
	if not l.stone:allow(1) then return end

	if typeof(model) ~= "Instance" or not model:IsA("Model") then return end
	if not hasTagDeep(model, "Stone") then return end
	if not ownsPlotForModel(player, model) then return end

	local focus = focusPart(model)
	if not (focus and distOK(player, focus)) then return end

	local add = hasPickaxeServer(player) and 2 or 1
	DataService.addResource(player, "stones", add)

        EventBus.sendToClient(player, Topics.MiningFeedback, {
                kind = "stone",
                position = focus.Position,
        })
        -- efectos de partículas al romper la roca
        local fx = model:FindFirstChild("FxStone", true)
        if fx and fx:IsA("Attachment") then
                local parent = fx.Parent
                if parent and parent:IsA("BasePart") then
                        local anchor = Instance.new("Part")
                        anchor.Name = "FxStoneAnchor"
                        anchor.Anchored = true
                        anchor.CanCollide = false
                        anchor.Transparency = 1
                        anchor.Size = Vector3.new(0.1,0.1,0.1)
                        anchor.CFrame = fx.WorldCFrame

                        local clone = fx:Clone()
                        clone.Parent = anchor
                        anchor.Parent = Workspace

                        for _, emitter in ipairs(clone:GetChildren()) do
                                if emitter:IsA("ParticleEmitter") then

                                        local prevRate = emitter.Rate
                                        emitter.Enabled = true
                                        if emitter.Rate <= 0 then
                                                emitter.Rate = 20
                                        end
                                        emitter:Emit(15)
                                        task.delay(0.5, function()
                                                emitter.Enabled = false
                                                emitter.Rate = prevRate
                                        end)

                                end
                        end

                        Debris:AddItem(anchor, 2)
                end
        end

        if model.Parent then model:Destroy() end
end

-- ========= Cristales =========
local function beginCrystal(player, model: Model)
	local l = ensureLimiters(player)
	if not l.crystal:allow(1) then
		EventBus.sendToClient(player, Topics.MiningCrystalAck, { ok = false })
		return
	end

	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		EventBus.sendToClient(player, Topics.MiningCrystalAck, { ok = false }); return
	end
	if not hasTagDeep(model, "Crystal") then
		EventBus.sendToClient(player, Topics.MiningCrystalAck, { ok = false }); return
	end
	if not hasPickaxeServer(player) then
		EventBus.sendToClient(player, Topics.MiningCrystalAck, { ok = false }); return
	end
	if not ownsPlotForModel(player, model) then
		EventBus.sendToClient(player, Topics.MiningCrystalAck, { ok = false }); return
	end

	local focus = focusPart(model)
	if not (focus and distOK(player, focus)) then
		EventBus.sendToClient(player, Topics.MiningCrystalAck, { ok = false }); return
	end

	activeCrystal[player] = { model = model, t0 = time(), lastValid = time(), focus = focus }
	EventBus.sendToClient(player, Topics.MiningCrystalAck, { ok = true })
end

local function stopCrystal(player)
	activeCrystal[player] = nil
end

RunService.Heartbeat:Connect(function()
	local now = time()
	for plr, state in pairs(activeCrystal) do
		local m = state.model
		if not (plr and m and m.Parent) then
			activeCrystal[plr] = nil
		else
			local focus = state.focus and state.focus.Parent and state.focus or focusPart(m)
			state.focus = focus
			local ok = focus and distOK(plr, focus) and hasPickaxeServer(plr) and ownsPlotForModel(plr, m)

			if ok then
				if (now - state.t0) >= CRYSTAL_TIME then
					DataService.addResource(plr, "gems", CRYSTAL_REWARD)

					EventBus.sendToClient(plr, Topics.MiningFeedback, {
						kind = "crystal",
						position = focus.Position,
					})

					if m.Parent then m:Destroy() end
					activeCrystal[plr] = nil
				else
					state.lastValid = now
				end
			else
				if (now - (state.lastValid or now)) > FAIL_GRACE then
					activeCrystal[plr] = nil
				end
			end
		end
	end
end)

local function onPlayerRemoving(player: Player)
	activeCrystal[player] = nil
	limits[player] = nil
end
Players.PlayerRemoving:Connect(onPlayerRemoving)

function MiningService.init()
	EventBus.registerServer(Topics.MiningRequest, function(player, payload)
		local node = coerceNode(payload)
		if node then mineStone(player, node) end
	end)

	EventBus.registerServer(Topics.MiningCrystalStart, function(player, payload)
		local node = coerceNode(payload)
		if node then beginCrystal(player, node) end
	end)

	EventBus.registerServer(Topics.MiningCrystalStop, function(player, _payload)
		stopCrystal(player)
	end)

	print("[MiningService] Initialized (clean EventBus only).")
end

return MiningService
