-- ServerScriptService/Scripts/MiningServer.server.lua
-- Server-side handling for mining using remote events

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local SWING_COOLDOWN = 0.15
local MAX_RANGE = 16


local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = ReplicatedStorage
end

local SubtractHealthRE = Remotes:FindFirstChild("SubtractHealth")
if not SubtractHealthRE then
    SubtractHealthRE = Instance.new("RemoteEvent")
    SubtractHealthRE.Name = "SubtractHealth"
    SubtractHealthRE.Parent = Remotes
end

local UpdateGuiRE = Remotes:FindFirstChild("UpdateGui")
if not UpdateGuiRE then
    UpdateGuiRE = Instance.new("RemoteEvent")
    UpdateGuiRE.Name = "UpdateGui"
    UpdateGuiRE.Parent = Remotes
end

local DebounceRF = Remotes:FindFirstChild("Debounce")
if not DebounceRF then
    DebounceRF = Instance.new("RemoteFunction")
    DebounceRF.Name = "Debounce"
    DebounceRF.Parent = Remotes
end


local SoundManager = require(script.Parent.Parent.ServerModules.SoundManager)


local Debounce = setmetatable({}, { __mode = "k" })

local function objPos(object)
    if not object then return nil end
    if object:IsA("Model") then
        return object:GetPivot().Position
    elseif object:IsA("BasePart") then
        return object.Position
    else
        local p = object:FindFirstAncestorOfClass("BasePart")
        return p and p.Position or nil
    end
end

local function isMinable(obj)
    if typeof(obj) ~= "Instance" or not obj.Parent then return false end

    local mh = obj:GetAttribute("MaxHealth")
    if mh == nil then return false end
    if obj:GetAttribute("IsMinable") == false then return false end

    local h = obj:GetAttribute("Health")
    if h ~= nil and tonumber(h) <= 0 then return false end
    return true
end

local function inRange(player, obj)
    local char = player.Character
    if not (char and char.PrimaryPart) then return false end
    local p = objPos(obj)
    return p and (p - char.PrimaryPart.Position).Magnitude <= MAX_RANGE or false
end

DebounceRF.OnServerInvoke = function(player, object)

    if not player or not object then return false end
    if Debounce[player] then return false end
    if not isMinable(object) then return false end
    if not inRange(player, object) then return false end

    return true
end

SubtractHealthRE.OnServerEvent:Connect(function(player, object, healthSubtraction)

    if not player or typeof(object) ~= "Instance" or not object.Parent then return end
    if Debounce[player] then return end
    if not isMinable(object) then return end
    if not inRange(player, object) then return end


    Debounce[player] = true

    local current = object:GetAttribute("Health")
    local maxH = object:GetAttribute("MaxHealth")

    if maxH == nil then
        Debounce[player] = false
        return
    end

    if current == nil then
        current = tonumber(maxH) or 100
        object:SetAttribute("Health", current)
    end
    local amount = tonumber(healthSubtraction) or 0
    if amount <= 0 then amount = 1 end

    local newHealth = math.max(0, current - amount)
    object:SetAttribute("Health", newHealth)


    UpdateGuiRE:FireClient(player)


    local pos = objPos(object) or Vector3.new()
    local lowerName = string.lower(object.Name)
    local soundName = lowerName:find("crystal") and "CrystalSound" or "BreakSound"
    SoundManager:playSound(soundName, pos)

    if newHealth <= 0 then
        local reward = tonumber(object:GetAttribute("Reward")) or 0

        if reward > 0 then
            if lowerName:find("crystal") then
                local leaderstats = player:FindFirstChild("leaderstats")
                local gems = leaderstats and leaderstats:FindFirstChild("Gems")
                if gems then gems.Value = gems.Value + reward end
            else
                local stones = player:FindFirstChild("Stones")
                if stones then stones.Value = stones.Value + reward end
            end
        end

        if object and object.Parent then
            object:Destroy()
        end
    end

    task.delay(SWING_COOLDOWN, function()
        Debounce[player] = false

    end)
end)

Players.PlayerAdded:Connect(function(player)

    Debounce[player] = false
end)

Players.PlayerRemoving:Connect(function(player)
    Debounce[player] = nil

end)

