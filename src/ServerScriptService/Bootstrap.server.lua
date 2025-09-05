local ServerScriptService = game:GetService("ServerScriptService")
local modulesFolder = ServerScriptService:WaitForChild("ServerModules")
local servicesFolder = ServerScriptService:WaitForChild("Services")

local modules = {
    "Plot/PlotManager",
    "SoundManager",
    "Plot/NodeSpawner",
    "PlayerDataLegacy",
    "LeaderboardHandler",
    "ShopService",
    "SellService",
    "Plot/UpgradeHandler",
    "LeaderstatsScript",
    "Plot/SpawnPlotAssociation",
}

local function load(folder, path)
    local inst = folder
    for name in string.gmatch(path, "[^/]+") do
        inst = inst:WaitForChild(name)
    end
    local mod = require(inst)
    if type(mod) == "table" and mod.init then
        mod.init(mod)
    end
    return mod
end

for _, name in ipairs(modules) do
    load(modulesFolder, name)
end

local services = { "MiningService", "GamePassService", "PickFall/PickfallEventService" }

for _, name in ipairs(services) do
    load(servicesFolder, name)
end
