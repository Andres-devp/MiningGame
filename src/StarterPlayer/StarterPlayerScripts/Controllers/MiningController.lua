-- StarterPlayerScripts/Controllers/MiningController.lua
-- Simplified mining controller using remote events and existing pickaxe

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

-- tuning constants
local REACH_STUDS = 13
local LOCAL_COOLDOWN = 0.12

local M = {}

function M.start()
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    -- gui references
    local playerGui = player:WaitForChild("PlayerGui")
    local GUIFolder = playerGui:WaitForChild("PickFall")
    local GUI = GUIFolder:WaitForChild("MiningGUI")
    local holderFrame = GUI:WaitForChild("HolderFrame")
    GUI.Enabled = false

    -- remotes
    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local RF_Debounce = Remotes:WaitForChild("Debounce")
    local RE_Subtract = Remotes:WaitForChild("SubtractHealth")
    local RE_Update = Remotes:WaitForChild("UpdateGui")

    -- raycast params to ignore player
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { character }

    local function getPickaxe()
        return character:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
    end

    local tool = getPickaxe()

    player.CharacterAdded:Connect(function(newChar)
        character = newChar
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        rayParams.FilterDescendantsInstances = { character }
        tool = getPickaxe()
        hookToolEvents(tool)
    end)

    -- mining helpers
    local currentObject = nil
    local lastSwing = 0

    local function safePos(obj)
        if not obj then return nil end
        if obj:IsA("Model") then
            return obj:GetPivot().Position
        elseif obj:IsA("BasePart") then
            return obj.Position
        else
            local part = obj:FindFirstAncestorOfClass("BasePart")
            return part and part.Position or nil
        end
    end

    local function inRange(obj)
        local pos = safePos(obj)
        return pos and (pos - humanoidRootPart.Position).Magnitude <= REACH_STUDS or false
    end

    local function canMineLocal(target)
        if not target then return false end
        if not target:FindFirstAncestor("Nodes") then return false end
        local equipped = character:FindFirstChildOfClass("Tool")
        if not (equipped and equipped:FindFirstChild("HealthSubtraction")) then return false end
        local mh = target:GetAttribute("MaxHealth")
        if mh == nil then return false end
        if target:GetAttribute("IsMinable") == false then return false end
        local h = target:GetAttribute("Health")
        if h ~= nil and tonumber(h) <= 0 then return false end
        if not inRange(target) then return false end
        return true
    end

    local function updateGUI()
        if not currentObject then return end
        GUI.Enabled = true
        holderFrame.NameLabel.Text = currentObject.Name
        local h = tonumber(currentObject:GetAttribute("Health")) or 0
        local mh = tonumber(currentObject:GetAttribute("MaxHealth")) or math.max(1, h)
        if h < 0 then h = 0 end
        holderFrame.HealthLabel.Text = tostring(h) .. " / " .. tostring(mh)
        holderFrame.BarFrame.Size = UDim2.fromScale(h / mh, 1)
    end

    local function removeSelectionBox()
        if currentObject then
            for _, child in ipairs(currentObject:GetChildren()) do
                if child:IsA("SelectionBox") then
                    child:Destroy()
                end
            end
        end

        currentObject = nil
        GUI.Enabled = false
    end

    local function addSelectionBox(target)
        removeSelectionBox()
        currentObject = target
        local sel = Instance.new("SelectionBox")
        sel.Name = "SelectionHighlight"
        sel.LineThickness = 0.03
        local adornee = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
        sel.Adornee = adornee or target
        sel.Color3 = Color3.fromRGB(78, 145, 255)
        sel.Parent = currentObject
        updateGUI()
    end

    local function doRaycast()
        local mp = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mp.X, mp.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 60, rayParams)
        if not result or not result.Instance then
            removeSelectionBox()
            return

        end
        local modelAncestor = result.Instance:FindFirstAncestorOfClass("Model")
        local target = modelAncestor or result.Instance
        if canMineLocal(target) then
            addSelectionBox(target)
        else
            removeSelectionBox()
        end
    end

    RE_Update.OnClientEvent:Connect(function()
        if currentObject and canMineLocal(currentObject) then
            updateGUI()
        else
            removeSelectionBox()
        end
    end)

    UserInputService.InputChanged:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            doRaycast()
        end
    end)

    local function onActivated()
        if not currentObject or not canMineLocal(currentObject) then
            return
        end
        local t = tick()
        if t - lastSwing < LOCAL_COOLDOWN then return end
        lastSwing = t
        local canMineServer = RF_Debounce:InvokeServer(currentObject)
        if not canMineServer then return end

        local hsVal = 0
        local equipped = character:FindFirstChildOfClass("Tool")
        if equipped then
            local hs = equipped:FindFirstChild("HealthSubtraction")
            if hs then hsVal = tonumber(hs.Value) or 0 end
        end

        RE_Subtract:FireServer(currentObject, hsVal)
    end

    local function hookToolEvents(t)
        if t and t:IsA("Tool") then
            t.Activated:Connect(onActivated)
            t.Unequipped:Connect(function()
                GUI.Enabled = false
                removeSelectionBox()
            end)
        end

    end

    hookToolEvents(tool)
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            tool = child
            hookToolEvents(tool)

        end

    end)
end

return M

