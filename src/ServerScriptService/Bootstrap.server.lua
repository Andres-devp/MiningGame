-- Bootstrap.server.lua
-- Carga módulos de ServerModules y ejecuta init si existe, evitando ConversionHandler eliminado

local ServerScriptService = game:GetService("ServerScriptService")
local modulesFolder = ServerScriptService:WaitForChild("ServerModules")

local modules = {
    "PlotManager",
    "SoundManager",
    "NodeSpawner",
    "PlayerDataLegacy",
    "LeaderboardHandler",
    "ShopService",
    "UpgradeHandler",
    "LeaderstatsScript",
    "SpawnPlotAssociation",
}

local function safeRequire(name)
    local inst = modulesFolder:FindFirstChild(name)
    if not inst then
        warn(string.format("[FALLO] require %s (NO encontrado: %s/%s)", name, modulesFolder:GetFullName(), name))
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
    safeRequire(name)
end

print("[Bootstrap] módulos cargados")
