-- Este script local controla la apariencia del ProximityPrompt de la tienda.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local gems = leaderstats:WaitForChild("Gems")

local TIENDA = workspace:WaitForChild("TiendaPico")
local PROMPT = TIENDA:WaitForChild("ProximityPrompt")

local PRECIO_GEMAS = 10 -- Asegúrate de que este precio coincida con el del servidor
local PRECIO_ROBUX = 10

local isNearShop = false
local lastGemsValue = -1 -- Para evitar actualizaciones innecesarias

-- Función para actualizar el texto del prompt
local function updatePromptText()
	local currentGems = gems.Value
	if currentGems == lastGemsValue then return end -- No ha cambiado nada, no hacer nada

	if currentGems >= PRECIO_GEMAS then
		-- El jugador puede pagar con Gemas
		PROMPT.ObjectText = "Pico Mejorado"
		PROMPT.ActionText = "Comprar (" .. PRECIO_GEMAS .. " Gemas)"
	else
		-- El jugador no puede pagar con Gemas, mostrar opción de Robux
		PROMPT.ObjectText = "Pico Mejorado"
		PROMPT.ActionText = "Comprar (" .. PRECIO_ROBUX .. " Robux)"
	end

	lastGemsValue = currentGems
end

-- Bucle que se ejecuta en cada frame para verificar la proximidad
RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local distancia = (character.HumanoidRootPart.Position - TIENDA.Position).Magnitude

	-- Si el jugador está cerca, actualizamos el texto
	if distancia <= PROMPT.MaxActivationDistance then
		if not isNearShop then
			-- Acaba de entrar en el rango, actualizamos una vez
			updatePromptText()
			isNearShop = true
		end
	else
		if isNearShop then
			-- Acaba de salir del rango
			isNearShop = false
		end
	end
end)

-- Conectamos el evento para que el texto se actualice si las gemas cambian MIENTRAS está cerca
gems.Changed:Connect(function()
	if isNearShop then
		updatePromptText()
	end
end)
