

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(capacity: number, refillPerSec: number, minInterval: number)
	local self = setmetatable({}, RateLimiter)
	self.capacity     = math.max(1, capacity or 5)
	self.refillPerSec = math.max(0, refillPerSec or 5)
	self.minInterval  = math.max(0, minInterval or 0)
	self.tokens       = self.capacity
	self.lastRefill   = time()
	self.lastUse      = 0
	return self
end

function RateLimiter:allow(tokensRequired: number?)
	local need = math.max(1, tokensRequired or 1)
	local now  = time()

	
	local elapsed = now - self.lastRefill
	if elapsed > 0 then
		self.tokens = math.min(self.capacity, self.tokens + elapsed * self.refillPerSec)
		self.lastRefill = now
	end

	
	if (now - self.lastUse) < self.minInterval then
		return false
	end

	if self.tokens >= need then
		self.tokens -= need
		self.lastUse = now
		return true
	end

	return false
end

return RateLimiter