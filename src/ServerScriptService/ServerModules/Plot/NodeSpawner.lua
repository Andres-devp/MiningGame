local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local NodeSpawner = {}

local nodeTemplates = ServerStorage:WaitForChild("NodeTemplates")

-- weighted list of ore types ordered from lowest to highest value
local ORE_WEIGHTS = {
    Stone   = 50,
    Coal    = 30,
    Bronze  = 20,
    Emerald = 10,
    Gold    = 6,
    Diamond = 4,
}

-- load reward/max-health info from available ore templates so node stats
-- match the ones defined in the main ore models
local function loadOreStats()
    local stats = {}

    local function pull(folder)
        if not folder then
            return
        end
        for _, inst in ipairs(folder:GetChildren()) do
            local name = inst.Name
            stats[name] = stats[name] or {}
            local h = inst:GetAttribute("MaxHealth")
            local r = inst:GetAttribute("Reward")
            if h ~= nil then
                stats[name].MaxHealth = h
            end
            if r ~= nil then
                stats[name].Reward = r
            end
        end
    end

    -- prefer dedicated ore folders if present
    local ss = ServerStorage:FindFirstChild("PickFall")
    pull(ss and ss:FindFirstChild("Ores"))

    local rs = game:GetService("ReplicatedStorage")
    local pf = rs:FindFirstChild("PickFall")
    pull(pf and pf:FindFirstChild("OreTemplates"))

    -- finally, fall back to nodeTemplates themselves
    pull(nodeTemplates)

    return stats
end

local ORE_STATS = loadOreStats()
local DEFAULT_REWARDS = {
    Stone = 1,
    Coal = 2,
    Bronze = 3,
    Emerald = 4,
    Gold = 5,
    Diamond = 6,
}


local function pickOreType()
    local total = 0
    for _, w in pairs(ORE_WEIGHTS) do
        total += w
    end
    local r = math.random() * total
    for ore, w in pairs(ORE_WEIGHTS) do
        r -= w
        if r <= 0 then
            return ore
        end
    end
    return "Stone"
end

function NodeSpawner:init()
        local plotManager = require(script.Parent:WaitForChild("PlotManager"))
        self:start(plotManager)
end

local DEBUG = true
local function dprint(...) if DEBUG then print("[NodeSpawner]", ...) end end
local function dwarn(...) warn("[NodeSpawner]", ...) end

local TEMPLATE_NAMES = {
	CommonStone = { "CommonStone", "Stone", "Rock", "StoneNode", "StoneModel", "RockNode" },
	Crystal     = { "Crystal", "Cristal", "CrystalNode", "CrystalOre", "CrystalModel" },
}
local ZONE_NAMES = {
	CommonStone = { "RockZone", "StoneZone", "Zone" },
	Crystal     = { "CrystalZone", "CristalZone", "Zone" },
}

local function getUpgrade(player, name, defaultValue)
	local ups = player:FindFirstChild("Upgrades")
	local v = ups and ups:FindFirstChild(name)
	return (v and v.Value) or defaultValue
end

local function ensureNodesContainer(plotModel)
	local container = plotModel:FindFirstChild("Nodes")
	if not container then
		container = Instance.new("Folder")
		container.Name = "Nodes"
		container.Parent = plotModel
	end
	return container
end

local function anyBasePart(obj)
	if not obj then return nil end
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") then return obj:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function caseInsensitiveFind(folder, needle)
	local lo = string.lower
	needle = lo(needle)
	for _, ch in ipairs(folder:GetChildren()) do
		local nm = lo(ch.Name)
		if nm == needle or string.find(nm, needle, 1, true) then
			return ch
		end
	end
	return nil
end

local function findTemplate(nodeType)
	for _, name in ipairs(TEMPLATE_NAMES[nodeType] or {}) do
		local obj = nodeTemplates:FindFirstChild(name)
		if obj then return obj end
	end
	local kw = nodeType == "CommonStone" and "stone" or "crystal"
	local obj = caseInsensitiveFind(nodeTemplates, kw)
	if obj then return obj end
	dwarn(("No encontré plantilla para '%s'. Esperaba algo como: %s")
		:format(nodeType, table.concat(TEMPLATE_NAMES[nodeType] or {}, ", ")))
	return nil
end

local function findZonePart(plotModel, nodeType)
	for _, z in ipairs(ZONE_NAMES[nodeType] or {}) do
		local cand = plotModel:FindFirstChild(z, true)
		local part = anyBasePart(cand)
		if part then return part, z end
	end
	local keys = nodeType == "CommonStone" and { "rockzone","stonezone","zone" } or { "crystalzone","cristalzone","zone" }
	for _, k in ipairs(keys) do
		local found = caseInsensitiveFind(plotModel, k)
		local part = anyBasePart(found)
		if part then return part, found and found.Name or k end
	end
	dwarn(("No encontré zona para '%s' en %s (crea 'CrystalZone' o 'Zone')."):format(nodeType, plotModel.Name))
	return nil, nil
end

local function placeOnTop(model, zonePart, offsetXZ)
	local primary = model.PrimaryPart or anyBasePart(model)
	if not primary then return end
	local zoneCF, zoneSize = zonePart.CFrame, zonePart.Size
	local ox = (offsetXZ and offsetXZ.X) or (math.random() - 0.5) * (zoneSize.X - 1)
	local oz = (offsetXZ and offsetXZ.Z) or (math.random() - 0.5) * (zoneSize.Z - 1)

	
	local basePos = (zoneCF * CFrame.new(ox, 0, oz)).Position

	
	local modelHalfY = primary.Size.Y * 0.5
	local topY = zoneCF.Position.Y + (zoneSize.Y * 0.5)
	local y = topY + modelHalfY + 0.05

	model:PivotTo(CFrame.new(basePos.X, y, basePos.Z))
end

local function ensureCrystalGui(node)
	local pp = node.PrimaryPart or anyBasePart(node)
	if not pp then return end

	local gui = node:FindFirstChild("ProgresoGui", true)
	if gui and gui:IsA("BillboardGui") then
		if not gui.Adornee then gui.Adornee = pp end
		return
	end

	gui = Instance.new("BillboardGui")
	gui.Name = "ProgresoGui"
	gui.Size = UDim2.new(0, 80, 0, 10)
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.Adornee = pp
	gui.Parent = pp

	local fondo = Instance.new("Frame")
	fondo.Name = "BarraFondo"
	fondo.Size = UDim2.new(1, 0, 1, 0)
	fondo.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	fondo.BorderSizePixel = 0
	fondo.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Barra"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	bar.BorderSizePixel = 0
	bar.Parent = fondo
end

local function spawnNode(plotData, nodeType)
        if not (plotData and plotData.model) then return false end

        local zonePart = findZonePart(plotData.model, nodeType)
        if not zonePart then return false end

        local finalType = nodeType
        local tpl
        if nodeType == "CommonStone" then
                finalType = pickOreType()
                tpl = nodeTemplates:FindFirstChild(finalType)
                if not tpl then
                        dwarn(("No template for ore '%s'"):format(finalType))
                        return false
                end
        else
                tpl = findTemplate(nodeType)
                if not tpl then return false end
        end

        local node = tpl:Clone()

        local stats = ORE_STATS[finalType] or {}

        if node:GetAttribute("MaxHealth") == nil then
                node:SetAttribute("MaxHealth", stats.MaxHealth or (finalType == "Stone" and 1 or 20))
        end

        if node:GetAttribute("Reward") == nil then
                node:SetAttribute("Reward", stats.Reward or DEFAULT_REWARDS[finalType] or 0)

        end

        if node:GetAttribute("Health") == nil then
                node:SetAttribute("Health", node:GetAttribute("MaxHealth"))
        end

        if node:GetAttribute("IsMinable") == nil then
                node:SetAttribute("IsMinable", true)
        end

        if node:GetAttribute("NodeType") == nil then
                node:SetAttribute("NodeType", finalType)
        end

        if not node.PrimaryPart then
                local any = anyBasePart(node)
                if any then node.PrimaryPart = any end
        end

        placeOnTop(node, zonePart)

        if finalType == "Crystal" or nodeType == "Crystal" then
                ensureCrystalGui(node)
        end

        node.Parent = ensureNodesContainer(plotData.model)

        if nodeType == "CommonStone" then
                plotData.rocks[node] = true
        else
                plotData.crystals[node] = true
        end

        return true
end

local timers = setmetatable({}, { __mode = "k" })
local function getTimers(p) timers[p] = timers[p] or { rock = 0, crystal = 0 } ; return timers[p] end

local function countAndClean(map)
	local n = 0
	for inst in pairs(map) do
		if not (inst and inst.Parent) then map[inst] = nil else n += 1 end
	end
	return n
end

local function topUp(plotData, nodeType, currentCount, maxCount)
	local need = math.max(0, maxCount - currentCount)
	for _ = 1, need do spawnNode(plotData, nodeType) end
	return need
end

function NodeSpawner:start(PlotManager)
	local plotsData = PlotManager.plotsData
	dprint("NodeSpawner iniciado.")

	RunService.Heartbeat:Connect(function(dt)
		for _, plotData in pairs(plotsData) do
			if not plotData.owner then
				plotData._lastMaxRocks = nil
				plotData._lastMaxCrystals = nil
				plotData._seeded = false
			else
				local player = Players:GetPlayerByUserId(plotData.owner)
				if player then
					local rockCount    = countAndClean(plotData.rocks)
					local crystalCount = countAndClean(plotData.crystals)

					local maxRocks    = getUpgrade(player, "RockAmount", 5)
					local maxCrystals = getUpgrade(player, "CrystalAmount", 0)
					local rockSec     = math.max(0.5, getUpgrade(player, "SpawnRate", 4.0))
					local crystalSec  = math.max(0.5, getUpgrade(player, "CrystalSpawnRate", 8.0))

					
					if not plotData._seeded then
						local addR = topUp(plotData, "CommonStone", rockCount, maxRocks)
						local addC = topUp(plotData, "Crystal",     crystalCount, maxCrystals)
						if addR > 0 or addC > 0 then
							dprint(("Seed %s: +%d stones, +%d crystals"):format(plotData.model.Name, addR, addC))
						end
						plotData._seeded = true
						plotData._lastMaxRocks = maxRocks
						plotData._lastMaxCrystals = maxCrystals
					else
						
						if not plotData._lastMaxRocks or maxRocks > plotData._lastMaxRocks then
							local add = topUp(plotData, "CommonStone", rockCount, maxRocks)
							if add > 0 then dprint(("TopUp stones %s: +%d (cap=%d)"):format(plotData.model.Name, add, maxRocks)) end
							plotData._lastMaxRocks = maxRocks
						end
						if not plotData._lastMaxCrystals or maxCrystals > plotData._lastMaxCrystals then
							local add = topUp(plotData, "Crystal", crystalCount, maxCrystals)
							if add > 0 then dprint(("TopUp crystals %s: +%d (cap=%d)"):format(plotData.model.Name, add, maxCrystals)) end
							plotData._lastMaxCrystals = maxCrystals
						end
					end

					
					local t = getTimers(plotData)

					t.rock += dt
					while t.rock >= rockSec do
						if countAndClean(plotData.rocks) < maxRocks then
							spawnNode(plotData, "CommonStone")
						end
						t.rock -= rockSec
						if rockSec <= 0 then break end
					end

					t.crystal += dt
					while t.crystal >= crystalSec do
						if countAndClean(plotData.crystals) < maxCrystals then
							spawnNode(plotData, "Crystal")
						end
						t.crystal -= crystalSec
						if crystalSec <= 0 then break end
					end
				end
			end
		end
	end)
end

return NodeSpawner
