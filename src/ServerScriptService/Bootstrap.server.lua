-- Bootstrap.server.lua
-- Carga módulos de Modules y ejecuta init si existe, evitando ConversionHandler eliminado

local ServerScriptService = game:GetService("ServerScriptService")
local modulesFolder = ServerScriptService:WaitForChild("Modules")
local servicesFolder = ServerScriptService:WaitForChild("Services")

local modules = {
    "PlotManager",
    "SoundManager",
    "NodeSpawner",
    "PlayerDataLegacy",
    "LeaderboardHandler",
    "UpgradeHandler",
    "LeaderstatsScript",
    "SpawnPlotAssociation",
}

local function safeRequire(folder, name)
    local inst = folder:FindFirstChild(name)
    if not inst then
        warn(string.format("[FALLO] require %s (NO encontrado: %s/%s)", name, folder:GetFullName(), name))
        return nil
    end
    local ok, mod = pcall(require, inst)
    if not ok then
        warn(string.format("[FALLO] require %s (%s)", name, mod))
        return nil
    end
    print("[OK] require " .. name)
    if type(mod) == "table" and type(mod.init) == "function" then
        local okInit, err = pcall(mod.init, mod)
        if not okInit then
            warn(string.format("[FALLO] init %s (%s)", name, err))
        end
    end
    return mod
end

for _, name in ipairs(modules) do
    safeRequire(modulesFolder, name)
end


-- Servicios que no se cargan automáticamente desde Modules y
-- necesitan cargarse manualmente para que expongan su API/Events.
-- GamePassService maneja el estado del AutoMine (game pass + toggle),
-- por lo que debe inicializarse junto con MiningService.
local services = { "NodeService", "ShopService", "SellService", "MiningService", "GamePassService" }


for _, name in ipairs(services) do
    safeRequire(servicesFolder, name)
end

print("[Bootstrap] módulos cargados")
