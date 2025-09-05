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

math.randomseed(math.floor(os.clock()*1e6))


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
    print("HexGenerator: using template folder", folder:GetFullName())

    local names = { "Stone", "Coal", "Bronze", "Gold", "Emerald", "Diamond" }
    local templates = {}
    for _, name in ipairs(names) do
        local inst = folder:FindFirstChild(name)
        assert(inst, "Missing template: " .. name)
        templates[name] = inst
    end
    print("HexGenerator: loaded templates", table.concat(names, ", "))
    return templates
end

-- Merge base and override weight tables (overrides replace)
local function mergeWeights(a, b)
    local t = {}
    for k, v in pairs(a) do t[k] = v end
    if b then
        for k, v in pairs(b) do t[k] = v end

    end
    return t
end

local function weightedPick(weights)
    local total = 0
    for _, w in pairs(weights) do
        total += math.max(0, w or 0)
    end
    if total <= 0 then
        return "Stone"
    end
    local r = math.random() * total
    for ore, w in pairs(weights) do
        w = math.max(0, w or 0)

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

-- Case-insensitive wait for child
local function waitForChildCI(parent, name, timeout)
    timeout = timeout or 5
    local lower, t0 = name:lower(), os.clock()
    repeat
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name:lower() == lower then return child end
        end
        task.wait(0.1)
    until os.clock() - t0 >= timeout
end

local templates = getTemplates()

local arena = waitForChildCI(Workspace, "PickFallArena", 5)
local base = arena and waitForChildCI(arena, "Base", 5)
assert(arena and base, "Workspace/PickFallArena with Base not found")
print("HexGenerator: arena", arena, "base", base)


local platforms = arena:FindFirstChild("OrePlatforms")
if platforms then
    platforms:ClearAllChildren()
    print("HexGenerator: cleared existing platforms")
else
    platforms = Instance.new("Folder")
    platforms.Name = "OrePlatforms"
    platforms.Parent = arena
    print("HexGenerator: created platforms folder")
end

local basePos = base.Position
local baseTopY = basePos.Y + (base.Size and base.Size.Y / 2 or 0)

local size = CFG.tileWidth / 2

for layer = 1, CFG.layers do
    local layerFolder = Instance.new("Folder")
    layerFolder.Name = string.format("Layer_%d", layer)
    layerFolder.Parent = platforms

    local weights = mergeWeights(CFG.baseWeights, CFG.layerOverrides[layer])
    local y = baseTopY + CFG.topOffsetY + (layer - 1) * CFG.layerStep
    print(string.format("HexGenerator: generating layer %d at y=%.2f", layer, y))
    local tileCount = 0

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

            local cf = CFrame.new(basePos.X + x, y, basePos.Z + z)

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

            tileCount += 1
            if tileCount <= 5 then
                print(string.format("HexGenerator: placed %s at layer %d q=%d r=%d", oreName, layer, q, r))
            end

        end
    end
    print(string.format("HexGenerator: layer %d placed %d tiles", layer, tileCount))
end

print(string.format("HexGenerator: layers=%d radius=%d tileWidth=%.2f", CFG.layers, CFG.radius, CFG.tileWidth))
print("HexGenerator: generation complete")

