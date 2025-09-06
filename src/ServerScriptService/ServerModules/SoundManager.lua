

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

local SoundManager = {}

local function findSoundTemplate(name: string): Sound?
	local folder = ReplicatedStorage:FindFirstChild("Sounds")
	if folder and folder:FindFirstChild(name) then
		return folder[name] :: Sound
	end
	return ReplicatedStorage:FindFirstChild(name) :: Sound?
end

SoundManager.soundTemplates = {
        StoneSound      = findSoundTemplate("StoneSound") or findSoundTemplate("BreakSound"),
        GoldSound       = findSoundTemplate("GoldSound") or findSoundTemplate("StoneSound") or findSoundTemplate("BreakSound"),
        CrystalSound    = findSoundTemplate("CrystalSound"),
        ProgressCrystal = findSoundTemplate("ProgressCrystal"),
        ConversionSound = findSoundTemplate("ConversionSound"),
}

function SoundManager:playSound(soundName: string, position: Vector3, pitch: number?)
	local soundTemplate = self.soundTemplates[soundName]
	if not soundTemplate then
		warn("[SoundManager] Plantilla no encontrada:", soundName)
		return
	end

	local part = Instance.new("Part")
	part.Name = "SoundContainer"
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Position = position
	part.Parent = workspace

	local s = soundTemplate:Clone()
	s.Pitch = pitch or 1
	s.Parent = part
	s:Play()

	DebrisService:AddItem(part, 3)
end

return SoundManager
