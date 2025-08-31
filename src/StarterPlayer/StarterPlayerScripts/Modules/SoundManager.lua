-- SoundManager (Cliente) v2.1 - Lógica de combo con time(), búsqueda flexible de plantillas

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DebrisService = game:GetService("Debris")

local SoundManager = {}

-- Helper: busca sonidos en ReplicatedStorage/Sounds o en la raíz
local function findSoundTemplate(name)
	local soundsFolder = ReplicatedStorage:FindFirstChild("Sounds")
	if soundsFolder and soundsFolder:FindFirstChild(name) then
		return soundsFolder[name]
	end
	return ReplicatedStorage:WaitForChild(name) -- fallback a raíz
end

-- Plantillas de sonido (soporta ambas jerarquías)
SoundManager.soundTemplates = {
	BreakSound      = findSoundTemplate("BreakSound"),
	CrystalSound    = findSoundTemplate("CrystalSound"),
	ConversionSound = findSoundTemplate("ConversionSound"),
}

-- === LÓGICA DE COMBO CENTRALIZADA ===
local COMBO_WINDOW = 0.5
local PITCH_INCREASE = 0.08
local MAX_PITCH = 2.5
local lastStoneMineTime = 0
local comboCount = 1

-- Función genérica para reproducir un sonido
function SoundManager:playSound(soundName, position, pitch)
	local soundTemplate = self.soundTemplates[soundName]
	if not soundTemplate then
		warn("Intento de reproducir un sonido local que no existe:", soundName)
		return
	end

	local soundContainer = Instance.new("Part")
	soundContainer.Name = "SoundContainer"
	soundContainer.Anchored = true
	soundContainer.CanCollide = false
	soundContainer.Transparency = 1
	soundContainer.Position = position
	soundContainer.Parent = workspace

	local newSound = soundTemplate:Clone()
	newSound.Pitch = pitch or 1
	newSound.Parent = soundContainer
	newSound:Play()

	DebrisService:AddItem(soundContainer, 3)
end

-- === NUEVA FUNCIÓN PARA EL SONIDO DE COMBO ===
function SoundManager:playComboSound(soundName, position)
	local now = time()
	if (now - lastStoneMineTime) <= COMBO_WINDOW then
		comboCount += 1
	else
		comboCount = 1
	end
	lastStoneMineTime = now

	local pitch = math.min(1 + (comboCount - 1) * PITCH_INCREASE, MAX_PITCH)
	self:playSound(soundName, position, pitch)
end

return SoundManager
