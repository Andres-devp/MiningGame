local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")

local M = {}

local function findDesc(parent, name, timeout)
	timeout = timeout or 5
	local t0 = os.clock()
	repeat
		local inst = parent:FindFirstChild(name, true)
		if inst then return inst end
		task.wait(0.1)
	until (os.clock() - t0) >= timeout
	return nil
end

local function connectAny(btn, cb)
	if not btn then return false end
	if btn.Activated then btn.Activated:Connect(cb); return true end
	if btn.MouseButton1Click then btn.MouseButton1Click:Connect(cb); return true end
	return false
end

function M.init()
	local toPlot  = Remotes:WaitForChild("TeleportToPlot")
	local toPOI   = Remotes:WaitForChild("TeleportToPOI")

	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainGui")
	local btnPlot  = gui:FindFirstChild("TPPlotButton")  or findDesc(gui, "TPPlotButton", 5)
	local btnShops = gui:FindFirstChild("TPShopsButton") or findDesc(gui, "TPShopsButton", 5)

	if not btnPlot or not btnShops then
		warn("[TPButtons] No encontré TPPlotButton o TPShopsButton en MainGui")
		return
	end

        local ok1 = connectAny(btnPlot,  function() toPlot:FireServer() end)
        local ok2 = connectAny(btnShops, function() toPOI:FireServer("Shops") end)
        print(("[TPButtons] Hooks listos  plot=%s  shops=%s"):format(tostring(ok1), tostring(ok2)))
end

return M
