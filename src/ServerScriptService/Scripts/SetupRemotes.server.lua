-- ServerScriptService/Scripts/SetupRemotes.server.lua
-- Crea RemoteEvents necesarios para Pickfall si no existen

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name)
    if remotesFolder:FindFirstChild(name) then return end
    local ev = Instance.new("RemoteEvent")
    ev.Name = name
    ev.Parent = remotesFolder
end

ensureRemote("PickfallJoin")
ensureRemote("PickfallState")
ensureRemote("PickfallWinner")
