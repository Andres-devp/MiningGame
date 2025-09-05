

local Players = game:GetService("Players")
local plotsFolder = workspace:WaitForChild("Plots")

local PlotManager = {}
PlotManager.plotsData = {}

for _, plotModel in ipairs(plotsFolder:GetChildren()) do
	if plotModel:IsA("Model") then
		PlotManager.plotsData[plotModel.Name] = {
			owner = nil,
			model = plotModel,
			rocks = {},
			crystals = {},
			_seeded = false,
			_lastMaxRocks = nil,
			_lastMaxCrystals = nil,
		}
	end
end
print("[PlotManager] Tabla de parcelas inicializada con " .. #plotsFolder:GetChildren() .. " parcelas.")

local function getOrCreatePlotNameValue(player)
	local v = player:FindFirstChild("PlotName")
	if not v then
		v = Instance.new("StringValue")
		v.Name = "PlotName"
		v.Value = ""
		v.Parent = player
	end
	return v
end

local function teleportToPlot(player, plotModel)
	local character = player.Character or player.CharacterAdded:Wait()
	local tp = plotModel:FindFirstChild("TeleportPoint")
	if tp then
		if character and character.PrimaryPart then
			character:PivotTo(tp.CFrame)
		else
			local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 3)
			if hrp then hrp.CFrame = tp.CFrame end
		end
	end
end

local function assignPlot(player)
	local plotNameValue = getOrCreatePlotNameValue(player)

	for plotName, data in pairs(PlotManager.plotsData) do
		if data.owner == nil then
			data.owner = player.UserId
			data._seeded = false
			data._lastMaxRocks = nil
			data._lastMaxCrystals = nil
			plotNameValue.Value = plotName

			teleportToPlot(player, data.model)
			print(player.Name .. " ha reclamado la parcela " .. plotName)
			return
		end
	end

	warn("No hay parcelas libres para asignar a " .. player.Name)
end

local function removePlot(player)
	local plotNameValue = player:FindFirstChild("PlotName")
	local plotName = plotNameValue and plotNameValue.Value or ""
	if plotName ~= "" and PlotManager.plotsData[plotName] then
		
		for node in pairs(PlotManager.plotsData[plotName].rocks) do
			if node and node.Parent then node:Destroy() end
		end
		for node in pairs(PlotManager.plotsData[plotName].crystals) do
			if node and node.Parent then node:Destroy() end
		end
		
		PlotManager.plotsData[plotName].owner = nil
		PlotManager.plotsData[plotName]._seeded = false
		PlotManager.plotsData[plotName]._lastMaxRocks = nil
		PlotManager.plotsData[plotName]._lastMaxCrystals = nil
		print("La parcela " .. plotName .. " ha sido liberada.")
	end
	if plotNameValue then plotNameValue.Value = "" end
end

function PlotManager:init()
	Players.PlayerAdded:Connect(assignPlot)
	Players.PlayerRemoving:Connect(removePlot)

	
	for _, p in ipairs(Players:GetPlayers()) do
		task.defer(assignPlot, p)
	end

	print("[PlotManager] Eventos de jugador conectados.")
end
function PlotManager:getPlotName(player)
	local v = player:FindFirstChild("PlotName")
	return (v and v.Value) or ""
end

function PlotManager:getPlayerPlotModel(player)
	local name = self:getPlotName(player)
	if name ~= "" then
		return workspace.Plots:FindFirstChild(name)
	end
	for _, data in pairs(self.plotsData) do
		if data.owner == player.UserId then
			return data.model
		end
	end
	return nil
end

return PlotManager
