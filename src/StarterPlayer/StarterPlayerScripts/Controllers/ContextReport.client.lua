
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

local ps = script:FindFirstAncestorOfClass("PlayerScripts") or lp:WaitForChild("PlayerScripts")

task.wait()

local controllers = ps:FindFirstChild("Controllers") or ps:WaitForChild("Controllers", 10)
local clientModules = ps:FindFirstChild("ClientModules") or ps:WaitForChild("ClientModules", 10)

    local function gather(folder, prefix, items)
            for _,m in ipairs(folder:GetChildren()) do
                    if m:IsA("ModuleScript") then
                            local t, e = safeRequire(m)
                            if type(t)=="table" then
                                    table.insert(items, ("%s%s: {%s}"):format(prefix, m.Name, listKeys(t)))
                            else
                                    table.insert(items, ("%s%s: (%s)"):format(prefix, m.Name, e or "no devuelve tabla"))
                            end
                    elseif m:IsA("Folder") then
                            gather(m, prefix .. m.Name .. "/", items)
                    end
            end
    end

    if controllers then
            local items = {}
            gather(controllers, "", items)
            if #items>0 then print("[Controllers] -> "..table.concat(items, " || ")) end
    else
            warn("[Controllers] FALTA carpeta Controllers en PlayerScripts")
    end

    if clientModules then
            local items = {}
            gather(clientModules, "", items)
            if #items>0 then print("[ClientModules] -> "..table.concat(items, " || ")) end
    else
            warn("[ClientModules] FALTA carpeta ClientModules en PlayerScripts")
    end

print("=== [ContextReport.client] FIN ===")
