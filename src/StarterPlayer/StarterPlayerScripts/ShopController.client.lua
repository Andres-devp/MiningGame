

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local gems = leaderstats:WaitForChild("Gems")

local TIENDA = workspace:WaitForChild("TiendaPico")
local PROMPT = TIENDA:WaitForChild("ProximityPrompt")

local PRECIO_GEMAS = 10 
local PRECIO_ROBUX = 10

local isNearShop = false
local lastGemsValue = -1 

local function updatePromptText()
	local currentGems = gems.Value
	if currentGems == lastGemsValue then return end 

	if currentGems >= PRECIO_GEMAS then
		
		PROMPT.ObjectText = "Pico Mejorado"
		PROMPT.ActionText = "Comprar (" .. PRECIO_GEMAS .. " Gemas)"
	else
		
		PROMPT.ObjectText = "Pico Mejorado"
		PROMPT.ActionText = "Comprar (" .. PRECIO_ROBUX .. " Robux)"
	end

	lastGemsValue = currentGems
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local distancia = (character.HumanoidRootPart.Position - TIENDA.Position).Magnitude

	
	if distancia <= PROMPT.MaxActivationDistance then
		if not isNearShop then
			
			updatePromptText()
			isNearShop = true
		end
	else
		if isNearShop then
			
			isNearShop = false
		end
	end
end)

gems.Changed:Connect(function()
	if isNearShop then
		updatePromptText()
	end
end)
