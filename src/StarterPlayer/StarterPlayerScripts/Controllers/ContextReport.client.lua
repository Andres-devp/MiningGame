-- ContextReport.client — diagnóstico seguro (para usar dentro de StarterPlayerScripts/Controllers)
local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local function safeRequire(mod)
	local ok, res = pcall(require, mod)
	if not ok then
		return nil, ("require ERROR: %s"):format(res)
	end
	return res, nil
end

local function listKeys(tbl)
	local keys = {}
	for k,_ in pairs(tbl) do table.insert(keys, tostring(k)) end
	table.sort(keys)
	return table.concat(keys, ", ")
end

print("=== [ContextReport.client] INICIO ===")

-- 1) Ubica PlayerScripts (no uses script.Parent porque aquí estamos dentro de /Controllers)
local ps = script:FindFirstAncestorOfClass("PlayerScripts") or lp:WaitForChild("PlayerScripts")

-- 2) Da tiempo a que se clonen las carpetas hijas
task.wait()

-- 3) Busca las carpetas hermanas correctas bajo PlayerScripts
local controllers = ps:FindFirstChild("Controllers") or ps:WaitForChild("Controllers", 10)
local clientModules = ps:FindFirstChild("ClientModules") or ps:WaitForChild("ClientModules", 10)

if controllers then
	local items = {}
	for _,m in ipairs(controllers:GetChildren()) do
		if m:IsA("ModuleScript") then
			local t, e = safeRequire(m)
			if type(t)=="table" then
				table.insert(items, ("%s: {%s}"):format(m.Name, listKeys(t)))
			else
				table.insert(items, ("%s: (%s)"):format(m.Name, e or "no devuelve tabla"))
			end
		end
	end
	if #items>0 then print("[Controllers] -> "..table.concat(items, " || ")) end
else
	warn("[Controllers] FALTA carpeta Controllers en PlayerScripts")
end

if clientModules then
        local items = {}
        for _,m in ipairs(clientModules:GetChildren()) do
		if m:IsA("ModuleScript") then
			local t, e = safeRequire(m)
			if type(t)=="table" then
				table.insert(items, ("%s: {%s}"):format(m.Name, listKeys(t)))
			else
				table.insert(items, ("%s: (%s)"):format(m.Name, e or "no devuelve tabla"))
			end
		end
	end
        if #items>0 then print("[ClientModules] -> "..table.concat(items, " || ")) end
else
        warn("[ClientModules] FALTA carpeta ClientModules en PlayerScripts")
end

print("=== [ContextReport.client] FIN ===")
