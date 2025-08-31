-- ServerModules/ConversionHandler.lua
-- Compatible con ReplicatedStorage/Sounds/ConversionSound o con la raíz

local DebrisService = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ConversionHandler = {}

local function findSound(name: string): Sound?
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	if soundsFolder and soundsFolder:FindFirstChild(name) then
		return soundsFolder[name] :: Sound
	end
	return ReplicatedStorage:FindFirstChild(name) :: Sound?
end

function ConversionHandler:init()
	local basePart = workspace:WaitForChild("ConversionBase")
	local conversionSoundTemplate = findSound("ConversionSound")
	local debounce = {}

	if not conversionSoundTemplate then
		warn("[ConversionHandler] No se encontró 'ConversionSound' ni en ReplicatedStorage/Sounds ni en la raíz.")
	end

	basePart.Touched:Connect(function(otherPart)
		local character = otherPart.Parent
		local humanoid = character and character:FindFirstChild("Humanoid")
		if not humanoid then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player or debounce[player] then return end
		debounce[player] = true

		local stones = player:FindFirstChild("Stones")
		local gemsFolder = player:FindFirstChild("leaderstats")
		local gems = gemsFolder and gemsFolder:FindFirstChild("Gems")

		if stones and gems and stones.Value > 0 then
			local stonesToConvert = stones.Value
			stones.Value = 0
			gems.Value += stonesToConvert

			if conversionSoundTemplate then
				local soundContainer = Instance.new("Part")
				soundContainer.Name = "SoundContainer"
				soundContainer.Anchored = true
				soundContainer.CanCollide = false
				soundContainer.Transparency = 1
				soundContainer.Position = character:FindFirstChild("HumanoidRootPart").Position
				soundContainer.Parent = workspace

				local newSound = conversionSoundTemplate:Clone()
				newSound.Parent = soundContainer
				newSound:Play()

				DebrisService:AddItem(soundContainer, 3)
			end
		end

		task.wait(1)
		debounce[player] = nil
	end)

	print("[ConversionHandler] Inicializado.")
end

return ConversionHandler
