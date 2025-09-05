

local Workspace = game:GetService("Workspace")

local M = {}
M._plotToSpawn = {}
M._spawnToPlot = {}

local function waitForFolder(parent, name, timeout)
	local f = parent:FindFirstChild(name)
	if f then return f end
	local ok = pcall(function() f = parent:WaitForChild(name, timeout or 10) end)
	return f
end

local function normalize(s)
	return string.lower((s or ""):gsub("%s+", ""):gsub("_", ""))
end

local function namesMatch(plotName, spawnName)
	if not plotName or not spawnName then return false end
	local p = normalize(plotName)
	local s = normalize(spawnName)
	if p == s then return true end
	if s:find(p, 1, true) or p:find(s, 1, true) then return true end
	local tag = p:match("(plot%d+)")
	if tag and s:find(tag, 1, true) then return true end
	return false
end

local function link(plot, spawn)
	if not plot or not spawn then return end
	
	local old = M._plotToSpawn[plot]
	if old and old ~= spawn then M._spawnToPlot[old] = nil end
	M._plotToSpawn[plot] = spawn
	M._spawnToPlot[spawn] = plot
end

local function unlinkPlot(plot)
	local sp = M._plotToSpawn[plot]
	if sp then M._spawnToPlot[sp] = nil end
	M._plotToSpawn[plot] = nil
end

local function unlinkSpawn(spawn)
	local pl = M._spawnToPlot[spawn]
	if pl then M._plotToSpawn[pl] = nil end
	M._spawnToPlot[spawn] = nil
end

function M.refreshForPlot(plot, spawnsFolder)
	if not plot or not plot:IsA("Model") then return end
	spawnsFolder = spawnsFolder or Workspace:FindFirstChild("Spawns")
	
	local tp = plot:FindFirstChild("TeleportPoint") or plot:FindFirstChild("Spawn")
	if tp and tp:IsA("BasePart") then
		link(plot, tp); return
	end
	
	if spawnsFolder then
		for _, sp in ipairs(spawnsFolder:GetChildren()) do
			local target = sp
			if sp:IsA("Model") then
				target = sp.PrimaryPart or sp:FindFirstChildWhichIsA("BasePart")
			end
			if target and namesMatch(plot.Name, sp.Name) then
				link(plot, target)
				return
			end
		end
	end
end

function M:init(opts)
        opts = opts or {}
        local timeout = opts.timeout or 0
        local plotsFolder  = waitForFolder(Workspace, "Plots",  timeout)
        local spawnsFolder = waitForFolder(Workspace, "Spawns", timeout)
	if not plotsFolder then
		warn("[SpawnPlotAssociation] 'Workspace/Plots' no existe (timeout). Abort init.")
		return false
	end

	
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then
			M.refreshForPlot(plot, spawnsFolder)
		end
	end

	
	plotsFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			M.refreshForPlot(child, spawnsFolder)
		end
	end)
	plotsFolder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then unlinkPlot(child) end
	end)

	if spawnsFolder then
		spawnsFolder.ChildAdded:Connect(function(child)
			for _, plot in ipairs(plotsFolder:GetChildren()) do
				if plot:IsA("Model") and namesMatch(plot.Name, child.Name) then
					local target = child
					if child:IsA("Model") then
						target = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
					end
					if target then link(plot, target) end
				end
			end
		end)
		spawnsFolder.ChildRemoved:Connect(function(child)
			unlinkSpawn(child)
		end)
	end

	print("[SpawnPlotAssociation] init OK — asociaciones listas.")
	return true
end

function M.GetSpawnForPlot(plot)  return M._plotToSpawn[plot] end
function M.GetPlotForSpawn(spawn) return M._spawnToPlot[spawn] end

return M
