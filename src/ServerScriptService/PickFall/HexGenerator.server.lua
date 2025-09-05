local CFG = {
    layers = 5, -- number of vertical layers
    layerStep = -6, -- vertical offset between layers (studs)
    radius = 5, -- axial radius of the honeycomb
    tileWidth = 6, -- width flat-to-flat of a tile
    topOffsetY = 0, -- offset from arena base to top layer
    tileYaw = 0, -- rotation of each tile in degrees
    baseWeights = {
        Stone = 40,
        Coal = 25,
        Bronze = 15,
        Gold = 10,
        Emerald = 6,
        Diamond = 4,
    },
    -- Optional per-layer overrides: [layer] = {OreName = weight, ...}
    layerOverrides = {
        [1] = { Stone = 50, Coal = 30, Bronze = 10, Gold = 5, Emerald = 3, Diamond = 2 },
        -- Add more overrides as needed
    },
}

math.randomseed(tick())

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("NodeService"))


-- Fetch templates from the defined locations
local function getTemplates()
    local paths = {
        ServerStorage:FindFirstChild("PickFall") and ServerStorage.PickFall:FindFirstChild("Ores"),
        ReplicatedStorage:FindFirstChild("PickFall") and ReplicatedStorage.PickFall:FindFirstChild("OreTemplates"),
        Workspace:FindFirstChild("PickFallArena") and Workspace.PickFallArena:FindFirstChild("Ores"),
    }

    local folder
    for _, p in ipairs(paths) do
        if p then
            folder = p
            break
        end
    end
    assert(folder, "Ore templates not found in expected locations")

    local names = { "Stone", "Coal", "Bronze", "Gold", "Emerald", "Diamond" }
    local templates = {}
    for _, name in ipairs(names) do
        local inst = folder:FindFirstChild(name)
        assert(inst, "Missing template: " .. name)
        templates[name] = inst
    end
    return templates
end

-- Merge base and override weight tables
local function mergeWeights(a, b)
    local t = {}
    for k, v in pairs(a) do
        t[k] = v
    end
    if b then
        for k, v in pairs(b) do
            t[k] = (t[k] or 0) + v
        end
    end
    return t
end

-- Weighted random pick from a weight table
local function weightedPick(weights)
    local total = 0
    for _, w in pairs(weights) do
        total += w
    end
    local r = math.random() * total
    for ore, w in pairs(weights) do
        r -= w
        if r <= 0 then
            return ore
        end
    end
    return "Stone"
end

-- Apply a gentle radial bias to weights
local function applyRadialBias(weights, dx, dz, size)
    local w = {}
    for k, v in pairs(weights) do
        w[k] = v
    end
    local dist = math.sqrt(dx * dx + dz * dz)
    local maxDist = CFG.radius * size * 1.5
    local t = math.clamp(dist / maxDist, 0, 1)
    w.Stone = (w.Stone or 0) * (1 + t * 0.5)
    w.Coal = (w.Coal or 0) * (1 + t * 0.3)
    local center = 1 - t
    w.Gold = (w.Gold or 0) * (1 + center * 0.4)
    w.Emerald = (w.Emerald or 0) * (1 + center * 0.4)
    w.Diamond = (w.Diamond or 0) * (1 + center * 0.6)
    return w
end

-- Ensure object pivots to CFrame
local function pivotTo(obj, cf)
    if obj:IsA("Model") then
        if not obj.PrimaryPart then
            local pp = obj:FindFirstChildWhichIsA("BasePart")
            if pp then
                obj.PrimaryPart = pp
            end
        end
        obj:PivotTo(cf)
    elseif obj:IsA("BasePart") then
        obj.CFrame = cf
    end
end

local templates = getTemplates()

local arena = Workspace:FindFirstChild("PickFallArena")
assert(arena and arena:FindFirstChild("Base"), "Workspace/PickFallArena with Base not found")

local platforms = arena:FindFirstChild("OrePlatforms")
if platforms then
    platforms:ClearAllChildren()
else
    platforms = Instance.new("Folder")
    platforms.Name = "OrePlatforms"
    platforms.Parent = arena
end

local basePos = arena.Base.Position
local size = CFG.tileWidth / 2

for layer = 1, CFG.layers do
    local layerFolder = Instance.new("Folder")
    layerFolder.Name = string.format("Layer_%d", layer)
    layerFolder.Parent = platforms

    local weights = mergeWeights(CFG.baseWeights, CFG.layerOverrides[layer])
    local y = CFG.topOffsetY + (layer - 1) * CFG.layerStep

    for q = -CFG.radius, CFG.radius do
        local r1 = math.max(-CFG.radius, -q - CFG.radius)
        local r2 = math.min(CFG.radius, -q + CFG.radius)
        for r = r1, r2 do
            local x = size * 1.5 * q
            local z = size * math.sqrt(3) * (r + q / 2)

            local tileWeights = applyRadialBias(weights, x, z, size)
            local oreName = weightedPick(tileWeights)
            local template = templates[oreName]
            local clone = template:Clone()

            for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = true
                end
            end

            local cf = CFrame.new(basePos.X + x, basePos.Y + y, basePos.Z + z)
                * CFrame.Angles(0, math.rad(CFG.tileYaw), 0)
            pivotTo(clone, cf)
            clone:SetAttribute("NodeType", oreName)
            local maxHealth = (oreName == "Stone") and 1 or 20
            clone:SetAttribute("MaxHealth", maxHealth)
            clone:SetAttribute("Health", maxHealth)
            clone:SetAttribute("IsMinable", true)
            clone:SetAttribute("Reward", 0)
            clone:SetAttribute("RequiresPickaxe", true)

            clone.Name = string.format("%s_q%d_r%d", oreName, q, r)
            clone.Parent = layerFolder

            if clone:IsA("Model") then
                NodeService.register(clone)
            end

        end
    end
end

print(string.format("HexGenerator: layers=%d radius=%d tileWidth=%.2f", CFG.layers, CFG.radius, CFG.tileWidth))

