local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()
local IS_PUBLISHED = (game.PlaceId ~= 0 and game.GameId ~= 0)

local DS_PREFIX = (IS_PUBLISHED and not IS_STUDIO) and "ACM" or "DEV_ACM"

return {
	IS_STUDIO    = IS_STUDIO,
	IS_PUBLISHED = IS_PUBLISHED,
	DS_PREFIX    = DS_PREFIX
}
