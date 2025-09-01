-- Controllers/CloseButtonController.lua
-- Conecta botones llamados "CloseButton" para ocultar su Frame padre

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local M = {}

-- Conecta un botón específico
local function hookButton(btn: GuiButton)
    btn.Activated:Connect(function()
        local parent = btn.Parent
        if parent and parent:IsA("GuiObject") then
            parent.Visible = false
        end
    end)
end

function M:init()
    local gui = player:WaitForChild("PlayerGui")

    -- Buscar botones existentes
    for _, inst in ipairs(gui:GetDescendants()) do
        if inst:IsA("GuiButton") and inst.Name == "CloseButton" then
            hookButton(inst)
        end
    end

    -- Escuchar nuevos botones agregados dinámicamente
    gui.DescendantAdded:Connect(function(inst)
        if inst:IsA("GuiButton") and inst.Name == "CloseButton" then
            hookButton(inst)
        end
    end)

    print("[CloseButtonController] listo")
end

return M

