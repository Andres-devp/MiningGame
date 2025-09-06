local CFG = {
    layers = 5, -- number of vertical layers
    layerStep = -25, -- vertical offset between layers
    radius = 7, -- axial radius of the honeycomb (in tiles)
    topOffsetY = 0, -- offset from arena base to top layer
    tileYaw = 30, -- rotation of each tile in degrees
    spacingXY = 1.0, -- multiplier for horizontal offsets
    gapXY = 0.25, -- extra spacing in studs between tiles
    sameY = false, -- if true, all layers share the same Y

    debug = true,
    baseWeights = {
        Stone = 40,
        Coal = 25,
        Emerald = 15,
        Gold = 8,
        Diamond = 4,
    },
    -- Optional per-layer overrides: [layer] = {OreName = weight, ...}
    layerOverrides = {
        [1] = { Stone = 50, Coal = 30, Emerald = 10, Gold = 6, Diamond = 4 },
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

    local names = { "Stone", "Coal", "Emerald", "Gold", "Diamond" }
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
    w.Emerald = (w.Emerald or 0) * (1 + center * 0.3)
    w.Gold = (w.Gold or 0) * (1 + center * 0.4)
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

-- Anchor parts and remove constraints before parenting
local function prepStatic(inst)
    if inst:IsA("BasePart") then
        inst.Anchored = true
        inst.CanCollide = true
        inst.Massless = false
    end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = true
            d.Massless = false
        elseif d:IsA("Constraint") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
            d:Destroy()
        end
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
local stoneTpl = templates.Stone
local tplSize
if stoneTpl:IsA("Model") then
    tplSize = stoneTpl:GetExtentsSize()
else
    tplSize = stoneTpl.Size
end

local flatW = math.max(tplSize.X, tplSize.Z)
local tileRadius = flatW / 2

local gapXY = CFG.gapXY or 0
local DX = 1.5 * tileRadius * CFG.spacingXY + gapXY
local DZ = math.sqrt(3) * tileRadius * CFG.spacingXY + gapXY


local layerStep = CFG.sameY and 0 or CFG.layerStep

if CFG.debug then
    print(('[HexGen] flatW=%.3f radius=%.3f DX=%.3f DZ=%.3f yaw=%d spacing=%.3f gap=%.3f')
        :format(flatW, tileRadius, DX, DZ, CFG.tileYaw, CFG.spacingXY, gapXY))

end

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


for layer = 1, CFG.layers do
    local layerFolder = Instance.new("Folder")
    layerFolder.Name = string.format("Layer_%d", layer)
    layerFolder.Parent = platforms

    local weights = mergeWeights(CFG.baseWeights, CFG.layerOverrides[layer])
    local y = baseTopY + CFG.topOffsetY + (layer - 1) * layerStep


    for q = -CFG.radius, CFG.radius do
        local r1 = math.max(-CFG.radius, -q - CFG.radius)
        local r2 = math.min(CFG.radius, -q + CFG.radius)
        for r = r1, r2 do
            local relX = q * DX
            local relZ = (r + q / 2) * DZ

            local tileWeights = applyRadialBias(weights, relX, relZ, tileRadius)
            local oreName = weightedPick(tileWeights)
            local template = templates[oreName]
            local clone = template:Clone()
            prepStatic(clone)
            clone.Parent = layerFolder


            local cf = CFrame.new(basePos.X + relX, y, basePos.Z + relZ) * CFrame.Angles(0, math.rad(CFG.tileYaw or 0), 0)

            pivotTo(clone, cf)
            if clone:GetAttribute("NodeType") == nil then
                clone:SetAttribute("NodeType", oreName)
            end
            local maxHealth = clone:GetAttribute("MaxHealth")
            if maxHealth == nil then
                maxHealth = (oreName == "Stone") and 1 or 20
                clone:SetAttribute("MaxHealth", maxHealth)
            end
            if clone:GetAttribute("Health") == nil then
                clone:SetAttribute("Health", maxHealth)
            end
            if clone:GetAttribute("IsMinable") == nil then
                clone:SetAttribute("IsMinable", true)
            end
            if clone:GetAttribute("Reward") == nil then
                clone:SetAttribute("Reward", 0)
            end
            if clone:GetAttribute("RequiresPickaxe") == nil then
                clone:SetAttribute("RequiresPickaxe", true)
            end

            clone.Name = string.format("%s_q%d_r%d", oreName, q, r)

            if clone:IsA("Model") then
                NodeService.register(clone)
            end

        end
    end
end


print("HexGenerator: generation complete")

