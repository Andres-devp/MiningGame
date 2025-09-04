-- StarterPlayerScripts/Controllers/MiningController.lua
-- Highlight-based mining controller with crystal hold mechanic

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local REACH_STUDS = 13
local LOCAL_COOLDOWN = 0.12
local CRYSTAL_TIME = 1.4

local COLOR_CAN = Color3.fromRGB(86, 220, 130)
local COLOR_CANT = Color3.fromRGB(240, 120, 120)

local M = {}

function M.start()
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    local playerGui = player:WaitForChild("PlayerGui")
    local GUIFolder = playerGui:WaitForChild("PickFall")
    local GUI = GUIFolder:WaitForChild("MiningGUI")
    local holderFrame = GUI:WaitForChild("HolderFrame")
    GUI.Enabled = false

    local hl = Instance.new("Highlight")
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = 0.6
    hl.Parent = playerGui

    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local RF_Debounce = Remotes:WaitForChild("Debounce")
    local RE_Subtract = Remotes:WaitForChild("SubtractHealth")
    local RE_Update = Remotes:WaitForChild("UpdateGui")

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { character }

    local function getPickaxe()
        return character:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
    end

    local tool = getPickaxe()

    local function getAdornee(obj)
        if not obj then return nil end
        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        elseif obj:IsA("BasePart") then
            return obj
        else
            return obj:FindFirstChildWhichIsA("BasePart", true)
        end
    end

    local function setHighlight(target, canMine)
        if target then
            hl.Adornee = target
            local c = canMine and COLOR_CAN or COLOR_CANT
            hl.FillColor = c
            hl.OutlineColor = c
        else
            hl.Adornee = nil
        end
    end

    local currentObject
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

    local function isNode(obj)
        return obj and obj:GetAttribute("NodeType") ~= nil
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

    local function setCrystalProgress(model, ratio)
        local gui = model and model:FindFirstChild("ProgresoGui", true)
        if not (gui and gui:IsA("BillboardGui")) then return end
        gui.Enabled = true
        local fondo = gui:FindFirstChild("BarraFondo")
        local barra = fondo and fondo:FindFirstChild("Barra")
        if barra then
            barra.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
        end
    end

    local function clearCrystalProgress(model)
        local gui = model and model:FindFirstChild("ProgresoGui", true)
        if not (gui and gui:IsA("BillboardGui")) then return end
        local fondo = gui:FindFirstChild("BarraFondo")
        local barra = fondo and fondo:FindFirstChild("Barra")
        if barra then barra.Size = UDim2.fromScale(0, 1) end
        gui.Enabled = false
    end

    local miningCrystal = false
    local crystalConn
    local function stopCrystal()
        if crystalConn then
            crystalConn:Disconnect()
            crystalConn = nil
        end
        if currentObject then
            clearCrystalProgress(currentObject)
        end
        miningCrystal = false
    end

    local function startCrystal()
        if miningCrystal or not currentObject then return end
        local ok = RF_Debounce:InvokeServer(currentObject)
        if not ok then return end
        miningCrystal = true
        local startTime = time()
        setCrystalProgress(currentObject, 0)
        crystalConn = RunService.Heartbeat:Connect(function()
            if not miningCrystal or not currentObject then return end
            if not canMineLocal(currentObject) then
                stopCrystal()
                return
            end
            local ratio = (time() - startTime) / CRYSTAL_TIME
            setCrystalProgress(currentObject, ratio)
            if ratio >= 1 then
                local maxH = tonumber(currentObject:GetAttribute("MaxHealth")) or 0
                RE_Subtract:FireServer(currentObject, maxH)
                stopCrystal()
            end
        end)
    end

    local function doRaycast()
        local mp = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mp.X, mp.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 60, rayParams)
        if not result or not result.Instance then
            currentObject = nil
            setHighlight(nil, false)
            GUI.Enabled = false
            return
        end
        local modelAncestor = result.Instance:FindFirstAncestorOfClass("Model")
        local target = modelAncestor or result.Instance
        if isNode(target) then
            currentObject = target
            local adorn = getAdornee(target)
            local canMine = canMineLocal(target)
            setHighlight(adorn, canMine)
            if canMine then
                updateGUI()
            else
                GUI.Enabled = false
            end
        else
            currentObject = nil
            setHighlight(nil, false)
            GUI.Enabled = false
        end
    end

    RE_Update.OnClientEvent:Connect(function()
        if currentObject and canMineLocal(currentObject) then
            updateGUI()
        else
            GUI.Enabled = false
            setHighlight(getAdornee(currentObject), false)
        end
    end)

    UserInputService.InputChanged:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            doRaycast()
        end
    end)

    local function onActivated()
        if not currentObject or not canMineLocal(currentObject) then return end
        local nodeType = currentObject:GetAttribute("NodeType")
        if nodeType == "Crystal" then
            startCrystal()
            return
        end
        local ok = RF_Debounce:InvokeServer(currentObject)
        if not ok then return end
        local t = tick()
        if t - lastSwing < LOCAL_COOLDOWN then return end
        lastSwing = t
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
            t.Deactivated:Connect(function()
                stopCrystal()
            end)
            t.Unequipped:Connect(function()
                GUI.Enabled = false
                setHighlight(nil, false)
                stopCrystal()
            end)
        end
    end

    hookToolEvents(tool)

    player.CharacterAdded:Connect(function(newChar)
        character = newChar
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        rayParams.FilterDescendantsInstances = { character }
        tool = getPickaxe()
        hookToolEvents(tool)
    end)

    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            tool = child
            hookToolEvents(tool)
        end
    end)
end

return M

