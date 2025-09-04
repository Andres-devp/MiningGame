-- Ubicación: StarterPlayerScripts > ClientModules > ToolManager

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local ToolManager = {}

ToolManager.isEquipped = false
ToolManager.equippedPickaxe = nil
ToolManager.pickaxeTemplate = ReplicatedStorage:WaitForChild("PickaxeModel")

function ToolManager:toggle(character)
	self.isEquipped = not self.isEquipped

	if self.isEquipped then
		local pickaxe = player.Backpack:WaitForChild("PickaxeModel", 2)
		if pickaxe then
			self.equippedPickaxe = pickaxe
			local handle = self.equippedPickaxe:FindFirstChild("Handle")
			local rightHand = character:WaitForChild("RightHand", 2)

			if handle and rightHand then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle; weld.Part1 = rightHand
				weld.Parent = handle
				self.equippedPickaxe.Parent = character
				mouse.TargetFilter = character
			else
				self.isEquipped = false
			end
		else
			self.isEquipped = false
		end
	else
		if self.equippedPickaxe then
			self.equippedPickaxe.Parent = player.Backpack
			self.equippedPickaxe = nil
			mouse.TargetFilter = nil
		end
	end
end

return ToolManager
