-- TeleportHandler.server — compatible con PlotManager v2.8.1 (usa PlotName y TeleportPoint)
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")
local plotsFolder = workspace:WaitForChild("Plots")

local hub = workspace:WaitForChild("Hub")
local pois = hub:WaitForChild("POIs")

local toPlot = Remotes:WaitForChild("TeleportToPlot")
local toPOI  = Remotes:WaitForChild("TeleportToPOI")

-- intenta leer el Plot del jugador por PlotName (y como fallback, por owner en plotsData)
local function getPlayerPlotModel(plr)
	-- 1) por StringValue PlotName
	local pn = plr:FindFirstChild("PlotName")
	if pn and pn.Value ~= "" then
		local mdl = plotsFolder:FindFirstChild(pn.Value)
		if mdl then return mdl end
	end
	-- 2) fallback por plotsData del módulo (opcional)
	local ok, PM = pcall(function()
		return require(game.ServerScriptService.ServerModules:WaitForChild("PlotManager"))
	end)
	if ok and PM and PM.plotsData then
		for _, data in pairs(PM.plotsData) do
			if data.owner == plr.UserId then
				return data.model
			end
		end
	end
	return nil
end

local function pivotCharacter(char, cf)
	local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 3))
	if hrp and cf then
		hrp.CFrame = cf + Vector3.new(0, 3, 0)
	end
end

toPlot.OnServerEvent:Connect(function(plr)
	local model = getPlayerPlotModel(plr)
	if not model then return end
	-- Tu PlotManager usa 'TeleportPoint'; también acepto 'Spawn' por si lo cambias
	local tp = model:FindFirstChild("TeleportPoint") or model:FindFirstChild("Spawn")
	if not tp then return end
	local char = plr.Character or plr.CharacterAdded:Wait()
	pivotCharacter(char, tp.CFrame)
end)

toPOI.OnServerEvent:Connect(function(plr, poiName)
	poiName = tostring(poiName or "")
	local poi = pois:FindFirstChild(poiName)
	if not poi then return end
	local char = plr.Character or plr.CharacterAdded:Wait()
	pivotCharacter(char, poi.CFrame)
end)
