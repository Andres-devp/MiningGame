-- StarterPlayerScripts/Controllers/MiningController.lua
-- v9.1: EventBus + barra cristal + SFX + VisualFX (sin RemoteEvents)

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

-- EventBus / Topics
local EventBus  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EventBus"))
local Topics    = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EventTopics"))

-- Visual FX + SFX
local VisualFX  = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("VisualFX"))
local M = {}
local ClientSoundManager

local MAX_DISTANCE   = 18
local CRYSTAL_TIME   = 1.4
local STONE_COOLDOWN = 0.45

local COLOR_CAN  = Color3.fromRGB( 86, 220, 130)
local COLOR_CANT = Color3.fromRGB(240, 120, 120)

-- helpers
local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function distOK(part)
	local root = hrp()
	return (root and part) and ((root.Position - part.Position).Magnitude <= MAX_DISTANCE) or false
end

local function focusPart(model)
        if not model then return nil end
        local hit = model:FindFirstChild("Hitbox")
        if hit and hit:IsA("BasePart") then return hit end
        return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function nodeInfoFrom(inst)
        local obj = inst
        while obj and obj ~= Workspace do
                if CollectionService:HasTag(obj, "Stone") then
                        local m = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model")
                        return "Stone", focusPart(m or obj), m or obj
                elseif CollectionService:HasTag(obj, "Crystal") then
                        local m = obj:IsA("Model") and obj or obj:FindFirstAncestorOfClass("Model")
                        return "Crystal", focusPart(m or obj), m or obj
                end
                obj = obj.Parent
        end
        return nil
end

local function ownsAutoMinePass()
	local v = player:FindFirstChild("OwnsAutoMinePass")
	return v and v.Value or false
end

local function autoMineEnabled()
	local v = player:FindFirstChild("AutoMineEnabled") or player:FindFirstChild("IsAutoMineActive")
	return v and v.Value or false
end

local function hasEquippedPickaxeClient()
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

local function nodeIdOf(model)
	return (model and model:GetAttribute("NodeId")) or (model and model.Name) or nil
end

-- highlight
local hl = Instance.new("Highlight")
hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hl.FillTransparency = 0.6
hl.Enabled = true
hl.Parent = player:WaitForChild("PlayerGui")

local function setHighlight(adorn, canMine)
	if adorn then
		hl.Adornee = adorn
		hl.FillColor = canMine and COLOR_CAN or COLOR_CANT
		hl.OutlineColor = canMine and COLOR_CAN or COLOR_CANT
	else
		hl.Adornee = nil
	end
end

-- Progreso cristal
local function setCrystalProgress(model, ratio)
	local gui = model and model:FindFirstChild("ProgresoGui", true)
	if not (gui and gui:IsA("BillboardGui")) then return end
	if not gui.Adornee then gui.Adornee = model end
	gui.Enabled = true

	local fondo = gui:FindFirstChild("BarraFondo")
	if not (fondo and fondo:IsA("Frame")) then return end
	fondo.ClipsDescendants = true

	local barra = fondo:FindFirstChild("Barra") or fondo:FindFirstChildWhichIsA("Frame")
	if not barra or barra == fondo then
		barra = Instance.new("Frame")
		barra.Name = "Barra"
		barra.BorderSizePixel = 0
		barra.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
		barra.AnchorPoint = Vector2.new(0, 0.5)
		barra.Position = UDim2.fromScale(0, 0.5)
		barra.Size = UDim2.fromScale(0, 1)
		barra.Parent = fondo
	end
	barra.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

local function clearCrystalProgress(model)
	local gui = model and model:FindFirstChild("ProgresoGui", true)
	if not (gui and gui:IsA("BillboardGui")) then return end
	local fondo = gui:FindFirstChild("BarraFondo")
	if not (fondo and fondo:IsA("Frame")) then return end
	local barra = fondo:FindFirstChild("Barra")
	if barra then barra.Size = UDim2.fromScale(0, 1) end
	gui.Enabled = false
end

-- input sostenido para cristal
local isMouseDown = false
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isMouseDown = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isMouseDown = false
	end
end)

-- estado
local pendingModel   = nil
local currentCrystal = nil
local miningActive   = false
local crystalStart   = 0
local lastStoneAuto  = 0

-- === EventBus: feedback server → cliente ===
EventBus.registerClient(Topics.MiningFeedback, function(payload)
	if not payload then return end
	local kind = payload.kind
	local pos  = payload.position

	if kind == "crystal" then
		if currentCrystal then clearCrystalProgress(currentCrystal) end
		currentCrystal, miningActive, pendingModel = nil, false, nil

		-- FX + SFX
		if ClientSoundManager and pos then
			ClientSoundManager:playSound("CrystalSound", pos, 1)
		end
		if pos then
			VisualFX.crystalBurst(pos)
		end
	else
		-- roca
		if ClientSoundManager and pos then
			ClientSoundManager:playComboSound("BreakSound", pos)
		end
		if pos then
			VisualFX.impactDust(pos)
		end
	end
end)

EventBus.registerClient(Topics.MiningCrystalAck, function(payload)
        local ok = payload and payload.ok
        if not pendingModel then return end
        if not ok then
                if currentCrystal then clearCrystalProgress(currentCrystal) end
                currentCrystal, miningActive = nil, false
        end
        pendingModel = nil
end)

function M:start(_, SoundManager)
	ClientSoundManager = SoundManager

        RunService.RenderStepped:Connect(function()
                local target = mouse.Target
                local nodeType, focus, model = nodeInfoFrom(target)

		if nodeType == "Stone" then
			local canMine = focus and distOK(focus)
			setHighlight(model, canMine)

			-- Hover auto-minado si AutoMine ON
			if canMine and autoMineEnabled() and (time() - lastStoneAuto) > STONE_COOLDOWN then
				lastStoneAuto = time()
				local id = nodeIdOf(model)
				if id then
					EventBus.sendToServer(Topics.MiningRequest, { node = model, nodeId = id, toolTier = 1 })
				end
			end

		elseif nodeType == "Crystal" then
			local hasPick = hasEquippedPickaxeClient()
			local inDist  = focus and distOK(focus)
			local canMine = hasPick and inDist
			setHighlight(model, canMine)

			-- Hover solo si pase + AutoMine ON; si no, click/tap sostenido
			local hoverAllowed  = ownsAutoMinePass() and autoMineEnabled()
			local shouldContinue = canMine and (hoverAllowed or isMouseDown)

                        if shouldContinue and not pendingModel and not miningActive then
                                pendingModel = model
                                local id = nodeIdOf(model)
                                if id then
                                        EventBus.sendToServer(Topics.MiningCrystalStart, { node = model, nodeId = id })
                                end
                                currentCrystal = model
                                crystalStart   = time()
                                miningActive   = true
                                setCrystalProgress(model, 0)
                        end

                        if miningActive and currentCrystal == model then
                                local ratio = (time() - crystalStart) / CRYSTAL_TIME
                                setCrystalProgress(model, ratio)
                        end

			if (not shouldContinue) and (pendingModel or miningActive) then
				EventBus.sendToServer(Topics.MiningCrystalStop, {})
				if currentCrystal then clearCrystalProgress(currentCrystal) end
				currentCrystal, miningActive, pendingModel = nil, false, nil
			end

		else
			setHighlight(nil, false)
			if pendingModel or miningActive then
				EventBus.sendToServer(Topics.MiningCrystalStop, {})
				if currentCrystal then clearCrystalProgress(currentCrystal) end
				currentCrystal, miningActive, pendingModel = nil, false, nil
			end
		end
	end)
end

return M
