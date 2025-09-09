local mod = require(script.Parent:WaitForChild("PlayerDataLegacy"))

return setmetatable({}, { __index = mod })

