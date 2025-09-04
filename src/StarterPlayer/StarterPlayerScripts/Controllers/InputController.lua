-- StarterPlayerScripts/Controllers/InputController.lua
-- v5.0 (clean) - Click/tap para minar rocas; peticiones por EventBus

local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local CollectionService  = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse  = player:GetMouse()

local EventBus = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("events"):WaitForChild("EventBus"))
local Topics   = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("events"):WaitForChild("EventTopics"))

local MAX_DISTANCE = 18

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function distOK(part)
	local root = hrp()
	return (root and part) and ((root.Position - part.Position).Magnitude <= MAX_DISTANCE) or false
end

local function focusPart(model: Model?)
	if not model then return nil end
	local hit = model:FindFirstChild("Hitbox")
	if hit and hit:IsA("BasePart") then return hit end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function isStoneModel(model: Model?): boolean
	if not (model and model:IsA("Model")) then return false end
	if CollectionService:HasTag(model, "Stone") then return true end
	if model.PrimaryPart and CollectionService:HasTag(model.PrimaryPart, "Stone") then return true end
	local hit = model:FindFirstChild("Hitbox")
	if hit and hit:IsA("BasePart") and CollectionService:HasTag(hit, "Stone") then return true end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "Stone") then
			return true
		end
	end
	return false
end

local function raycastFromScreen(screenPos: Vector2)
	local cam = Workspace.CurrentCamera
	if not cam then return nil end

	local unitRay = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params  = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
	return result and result.Instance or nil
end

local function fireMine(model: Model)
	local id = model:GetAttribute("NodeId") or model.Name
	EventBus.sendToServer(Topics.MiningRequest, {
		node   = model,
		nodeId = id,
		toolTier = 1,
	})
end

local function tryMineFromPart(part: Instance)
	if not part then return end
	local model = part:FindFirstAncestorOfClass("Model")
	if not isStoneModel(model) then return end

	local focus = focusPart(model)
	if not (focus and distOK(focus)) then return end

	fireMine(model)
end

-- PC + móvil
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryMineFromPart(mouse.Target)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		tryMineFromPart(raycastFromScreen(input.Position))
	end
end)

return {}
