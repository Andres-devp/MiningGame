-- MainController.client — robusto y sin sorpresas
local root        = script.Parent
local modulesPath = root:WaitForChild("Modules")
local controllers = root:WaitForChild("Controllers")

local function loadModule(container, name)
	local inst = container:WaitForChild(name)
	if not inst:IsA("ModuleScript") then
		warn(("[MainController] %s no es ModuleScript (es %s)"):format(name, inst.ClassName))
		return nil
	end
	local ok, res = pcall(require, inst)
	if not ok then
		warn(("[MainController] require %s ERROR: %s"):format(name, res))
		return nil
	end
	if type(res) ~= "table" then
		warn(("[MainController] %s no devolvió una tabla"):format(name))
		return nil
	end
	return res
end

local function call(mod, method, ...)
	if type(mod) ~= "table" or type(mod[method]) ~= "function" then return end
	-- Captura varargs antes de entrar al closure
	local args = table.pack(...)
	local ok, err = pcall(function()
		-- estilo ':' -> pasamos self (mod) como primer arg
		return mod[method](mod, table.unpack(args, 1, args.n))
	end)
	if ok then
		print(("[MainController] %s.%s OK"):format(tostring(mod), method))
	else
		warn(("[MainController] %s.%s ERROR: %s"):format(tostring(mod), method, tostring(err)))
	end
end

-- Controladores (todos como ModuleScript .lua)
local UIController         = loadModule(controllers, "UIController")         or {}
local MiningController     = loadModule(controllers, "MiningController")     or {}
local InputController      = loadModule(controllers, "InputController")      or {} -- side-effect
local ShopController       = loadModule(controllers, "ShopController")       or {}
local TPButtons            = loadModule(controllers, "TPButtons")            or {}
local ShopPromptController = loadModule(controllers, "ShopPromptController") or {}
local CloseButtonController= loadModule(controllers, "CloseButtonController") or {}

-- Módulos
local SoundManager         = loadModule(modulesPath, "SoundManager")         or {}

-- Orden: UI -> Mining -> (Input side-effect) -> ShopUI -> TP -> ShopPrompt
call(UIController,     "init")
call(MiningController, "start", nil, SoundManager)

if type(InputController.init) == "function" then
	local ok, err = pcall(function() InputController.init() end)
	print(ok and "[MainController] InputController.init OK"
	      or   ("[MainController] InputController.init ERROR: "..tostring(err)))
else
	print("[MainController] InputController loaded (side-effect).")
end

call(ShopController,       "init")
call(TPButtons,            "init")
call(ShopPromptController, "init")
call(CloseButtonController,"init")

print("--- MainController: controllers initialized (UI, Mining, Input, ShopUI, TP, ShopPrompt, CloseButtons). ---")
