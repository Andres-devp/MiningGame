

local Dialog = {}
Dialog.__index = Dialog

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Sounds = ReplicatedStorage:WaitForChild("Sounds")
local TICK_SOUND = Sounds:WaitForChild("tick")
local END_TICK_SOUND = Sounds:WaitForChild("tick2")

local function getDialogResponsesUI()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local saleDialog = playerGui:WaitForChild("SaleDialog")
    local responses = saleDialog:WaitForChild("dialogResponses")
    if not responses:FindFirstChild("1") then
        local template = responses:FindFirstChild("template")
        if template then
            for i = 1, 9 do
                local newResponseButton = template:Clone()
                newResponseButton.Parent = responses
                newResponseButton.Name = tostring(i)
            end
            template:Destroy()
        end
    end
    return responses
end

function Dialog.new(npcName, npc, prompt, animation)
    local self = setmetatable({}, Dialog)
    self.npcName = npcName
    self.npc = npc
    self.dialogs = {}
    self.responses = {}
    self.dialogOption = 1
    self.npcGui = self.npc:WaitForChild("Head"):WaitForChild("gui")
    self.active = false
    self.talking = false
    self.prompt = prompt
    self.player = nil

    -- ensure the dialog response buttons exist each time a dialog is created
    getDialogResponsesUI()

    local eventSignal = Instance.new("BindableEvent")
    self.responded = eventSignal.Event
    self.fireResponded = eventSignal

    
    self.animNameText = TweenService:Create(self.npcGui.name, TweenInfo.new(.3), {TextTransparency = 1})
    self.animNameStroke = TweenService:Create(self.npcGui.name.UIStroke, TweenInfo.new(.3), {Transparency = 1})
    self.animArrowText = TweenService:Create(self.npcGui.arrow, TweenInfo.new(.3), {TextTransparency = 1})
    self.animArrowStroke = TweenService:Create(self.npcGui.arrow.UIStroke, TweenInfo.new(.3), {Transparency = 1})
    self.animDialogText = TweenService:Create(self.npcGui.dialog, TweenInfo.new(.3), {TextTransparency = 1})
    self.animDialogStroke = TweenService:Create(self.npcGui.dialog.UIStroke, TweenInfo.new(.3), {Transparency = 1})

    
    if animation then
        local newAnimation = Instance.new("Animation")
        newAnimation.AnimationId = animation
        local newAnimLoaded = npc:WaitForChild("Humanoid"):LoadAnimation(newAnimation)
        newAnimLoaded:Play()
    end

    
    local frameCount = 0
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        frameCount += 1
        if self.talking then
            self.npcGui.StudsOffset = Vector3.new(0, 1.6, 0)
        else
            self.npcGui.StudsOffset = Vector3.new(0, math.sin(frameCount / 25) / 6 + 1.55, 0)
        end

        if self.active then
            local player = self.player or Players.LocalPlayer
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local npcRoot = self.npc.PrimaryPart or self.npc:FindFirstChild("HumanoidRootPart")
            if root and npcRoot then
                local maxDistance = (self.prompt.MaxActivationDistance or 12) + 5
                if (root.Position - npcRoot.Position).Magnitude > maxDistance then
                    self:hideGui()
                end
            end
        end
    end)
    self.connections = {heartbeatConnection}

    return self
end

function Dialog:addDialog(dialogText, responseOptions)
    table.insert(self.dialogs, {text = dialogText, responses = responseOptions})
end

function Dialog:sortDialogs(sortFunc)
    table.sort(self.dialogs, sortFunc or function(a, b)
        return a.text < b.text
    end)
end

function Dialog:triggerDialog(player, questionNumber)
    self.player = player or Players.LocalPlayer
    self.active = true
    self:showGui()

    if #self.dialogs == 0 then
        warn("No dialogs available for NPC: " .. self.npcName)
        return
    end

    local dialogNum = questionNumber or self.dialogOption
    local dialog = self.dialogs[dialogNum]

    TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 65}):Play()

    task.spawn(function()
        self.talking = true
        local dialogObject = self.npcGui.dialog
        dialogObject.Visible = true
        dialogObject.Text = ""
        local currenttext = ""
        local skip = false
        local arrow = 0
        for _, letter in ipairs(string.split(dialog.text, "")) do
            currenttext = currenttext .. letter
            if letter == "<" then skip = true end
            if letter == ">" then skip = false arrow += 1 continue end
            if arrow == 2 then arrow = 0 end
            if skip then continue end
            dialogObject.Text = currenttext .. (arrow == 1 and "</font>" or "")
            TICK_SOUND:Play()
            task.wait(0.02)
        end
        dialogObject.Text = dialog.text

        local keyboardInputs = {
            Enum.KeyCode.One,
            Enum.KeyCode.Two,
            Enum.KeyCode.Three,
            Enum.KeyCode.Four,
            Enum.KeyCode.Five,
            Enum.KeyCode.Six,
            Enum.KeyCode.Seven,
            Enum.KeyCode.Eight,
            Enum.KeyCode.Nine,
        }

        local uiResponses = getDialogResponsesUI()
        local responseNum
        for i, response in ipairs(dialog.responses) do
            local option = uiResponses:FindFirstChild(tostring(i))
            if not option then
                continue
            end
            option.text.Text = "<font color='rgb(255,220,127)'>" .. i .. ".)</font> [''" .. response .. "'']"

            option.Size = UDim2.fromScale(option.Size.X.Scale, 0.4)
            option.text.Position = UDim2.new(0.02, 0, 0.5, 0)
            option.Visible = true
            TweenService:Create(option, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(option.Size.X.Scale, 0, 0.35, 0) }):Play()

            local enterCon = option.MouseEnter:Connect(function()
                TweenService:Create(option, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Size = UDim2.new(option.Size.X.Scale + (option.Size.X.Scale * .05), 0, 0.4, 0) }):Play()
                TweenService:Create(option.text, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Position = UDim2.new(0.06, 0, 0.5, 0) }):Play()
                END_TICK_SOUND:Play()
            end)

            local leaveCon = option.MouseLeave:Connect(function()
                TweenService:Create(option, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Size = UDim2.new(option.Size.X.Scale, 0, 0.35, 0) }):Play()
                TweenService:Create(option.text, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Position = UDim2.new(0.02, 0, 0.5, 0) }):Play()
            end)

            local chooseCon = option.MouseButton1Down:Connect(function()
                if not self.active then return end
                self.active = false
                responseNum = i
                self.fireResponded:Fire(i, dialogNum)
                TICK_SOUND:Play()
            end)

            local numberpressCon = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    local numIndex = table.find(keyboardInputs, input.KeyCode)
                    if numIndex and numIndex == i then
                        if not self.active then return end
                        self.active = false
                        responseNum = i
                        self.fireResponded:Fire(i, dialogNum)
                        TICK_SOUND:Play()
                    end
                end
            end)

            coroutine.wrap(function()
                repeat task.wait() until responseNum ~= nil
                enterCon:Disconnect()
                leaveCon:Disconnect()
                chooseCon:Disconnect()
                numberpressCon:Disconnect()
                option.Visible = false
            end)()

            END_TICK_SOUND:Play()
            task.wait(0.2)
        end

        self.active = true
        while self.active do
            task.wait()
        end
    end)
end

function Dialog:showGui()
    turnProximityPromptsOn(false)

    self.animNameText:Play()
    self.animNameStroke:Play()
    self.animArrowText:Play()
    self.animArrowStroke:Play()

    self.animDialogText:Cancel()
    self.animDialogStroke:Cancel()

    self.npcGui.dialog.TextTransparency = 0
    self.npcGui.dialog.UIStroke.Transparency = 0

    coroutine.wrap(function()
        task.wait(0.3)
        if self.npcGui.name.TextTransparency ~= 1 then return end
        self.npcGui.name.Visible = false
        self.npcGui.arrow.Visible = false
    end)()
end

function Dialog:hideGui(exitQuip)
    self.active = false
    self.talking = true
    turnProximityPromptsOn(true)
    self.talking = false

    TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()

    local playerReponseOptions = getDialogResponsesUI()
    for _, option in ipairs(playerReponseOptions:GetChildren()) do
        if option:IsA("GuiButton") then
            option.Visible = false
        end
    end

    local dialogObject = self.npcGui.dialog
    if exitQuip then
        dialogObject.TextTransparency = 0
        dialogObject.UIStroke.Transparency = 0
        self.npcGui.name.TextTransparency = 1
        self.npcGui.name.UIStroke.Transparency = 1
        self.npcGui.arrow.TextTransparency = 1
        self.npcGui.arrow.UIStroke.Transparency = 1
        local currenttext = ""
        dialogObject.Text = ""
        dialogObject.Visible = true
        local skip = false
        local arrow = 0
        for _, letter in ipairs(string.split(exitQuip, "")) do
            if dialogObject.Text ~= currenttext and skip == 0 then break end
            currenttext = currenttext .. letter
            if letter == "<" then skip = true end
            if letter == ">" then skip = false arrow += 1 continue end
            if arrow == 2 then arrow = 0 end
            if skip then continue end
            dialogObject.Text = currenttext .. (arrow == 1 and "</font>" or "")
            TICK_SOUND:Play()
            task.wait(0.02)
        end
        dialogObject.Text = exitQuip
    end

    task.spawn(function()
        if exitQuip then
            task.wait(2)
            if dialogObject.Text ~= exitQuip then return end
        end

        if self.npcGui.name.TextTransparency ~= 1 then
            self.animNameText:Cancel()
            self.animNameStroke:Cancel()
            self.animArrowText:Cancel()
            self.animArrowStroke:Cancel()
        end
        self.npcGui.name.TextTransparency = 0
        self.npcGui.name.UIStroke.Transparency = 0
        self.npcGui.arrow.TextTransparency = 0
        self.npcGui.arrow.UIStroke.Transparency = 0
        self.npcGui.name.Visible = true
        self.npcGui.arrow.Visible = true

        self.animDialogText:Play()
        self.animDialogStroke:Play()
        turnProximityPromptsOn(true)
    end)
end

function Dialog:nextOption()
    self.dialogOption += 1
    if #self.dialogs < self.dialogOption then
        warn("No next dialog option for, " .. self.npcName)
        self.dialogOption -= 1
    end
    return self.dialogOption
end

function turnProximityPromptsOn(yes)
    for _, prompt in CollectionService:GetTagged("NPCprompt") do
        if prompt:IsA("ProximityPrompt") then
            prompt.Enabled = yes
        end
    end
end

return Dialog

