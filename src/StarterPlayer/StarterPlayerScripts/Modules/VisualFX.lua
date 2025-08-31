-- StarterPlayerScripts/Modules/VisualFX.lua
-- v1.0 - Efectos ligeros: polvo (roca) y burst (cristal) + mini camera shake

local Debris    = game:GetService("Debris")
local RunService= game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local M = {}

local function mkAnchorPart(pos: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2,0.2,0.2)
	p.CFrame = CFrame.new(pos)
	p.Name = "FXAnchor"
	p.Parent = Workspace
	return p
end

local function shakeCamera(duration, magnitude)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local t0 = time()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = time() - t0
		if t >= duration then
			conn:Disconnect()
			return
		end
		local decay = 1 - (t / duration)
		local dx = (math.random()-0.5) * 2 * magnitude * decay
		local dy = (math.random()-0.5) * 2 * magnitude * decay
		cam.CFrame = cam.CFrame * CFrame.new(dx*0.03, dy*0.03, 0)
	end)
end

function M.impactDust(pos: Vector3)
	local part = mkAnchorPart(pos)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://243660364" -- chispas genéricas
	pe.Speed = NumberRange.new(6,10)
	pe.Lifetime = NumberRange.new(0.25,0.45)
	pe.Rate = 0
	pe.Rotation = NumberRange.new(-180,180)
	pe.RotSpeed = NumberRange.new(-90,90)
	pe.SpreadAngle = Vector2.new(45,45)
	pe.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0.0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1.0, 0.0)
	}
	pe.Color = ColorSequence.new(Color3.fromRGB(200,200,200))
	pe.Parent = part
	pe:Emit(18)

	shakeCamera(0.08, 1.0)
	Debris:AddItem(part, 1.0)
end

function M.crystalBurst(pos: Vector3)
	local part = mkAnchorPart(pos)
	local ring = Instance.new("ParticleEmitter")
	ring.Texture = "rbxassetid://3018581294" -- ring
	ring.Rate = 0
	ring.Speed = NumberRange.new(2,4)
	ring.Lifetime = NumberRange.new(0.35,0.55)
	ring.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0.0, 0.3),
		NumberSequenceKeypoint.new(1.0, 1.2)
	}
	ring.Color = ColorSequence.new(Color3.fromRGB(120,200,255))
	ring.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0.0, 0.2),
		NumberSequenceKeypoint.new(1.0, 1.0)
	}
	ring.Parent = part
	ring:Emit(10)

	local spark = Instance.new("ParticleEmitter")
	spark.Texture = "rbxassetid://243660364"
	spark.Rate = 0
	spark.Speed = NumberRange.new(10,14)
	spark.Lifetime = NumberRange.new(0.25,0.35)
	spark.Size = NumberSequence.new(0.25, 0)
	spark.Color = ColorSequence.new(Color3.fromRGB(160,230,255))
	spark.Parent = part
	spark:Emit(12)

	shakeCamera(0.10, 1.2)
	Debris:AddItem(part, 1.0)
end

return M
