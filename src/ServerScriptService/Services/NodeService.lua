

local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local ATTR_NODE_ID      = "NodeId"

local NodeService = {}

local idToNode   : {[string]: Model} = {}
local nodeToId   : {[Instance]: string} = {}
local conns      : {[Instance]: RBXScriptConnection} = {}

local KNOWN_ORES = {
        Stone = true,
        Coal = true,
        Bronze = true,
        Gold = true,
        Emerald = true,
        Diamond = true,
}

local function ensureDefaults(model: Model)
        local nodeType = model:GetAttribute("NodeType")
        if not nodeType or nodeType == "" then
                nodeType = model.Name
                model:SetAttribute("NodeType", nodeType)
        end

        local maxH = tonumber(model:GetAttribute("MaxHealth"))
        if not maxH then
                maxH = (nodeType == "Stone") and 1 or 20
                model:SetAttribute("MaxHealth", maxH)
        end

        if tonumber(model:GetAttribute("Health")) == nil then
                model:SetAttribute("Health", maxH)
        end

        if model:GetAttribute("IsMinable") == nil then
                model:SetAttribute("IsMinable", true)
        end

        if model:GetAttribute("Reward") == nil then
                model:SetAttribute("Reward", 0)
        end

        if model:GetAttribute("RequiresPickaxe") == nil then
                model:SetAttribute("RequiresPickaxe", true)
        end
end

local function isNodeModel(model: Model?): boolean
        if not model or not model:IsA("Model") then return false end
        if model:GetAttribute("IsMinable") or model:GetAttribute("NodeType") then
                return true
        end
        return KNOWN_ORES[model.Name] == true
end

local function rootModel(inst: Instance?): Model?
        if not inst then return nil end
        if inst:IsA("Model") then return inst end
        return inst:FindFirstAncestorOfClass("Model")
end

local function makeNodeId(): string
	
	local g = HttpService:GenerateGUID(false) 
	g = g:gsub("%-", "")
	return "N_" .. g
end

function NodeService.assignNodeId(model: Model): string
	local id = model:GetAttribute(ATTR_NODE_ID)
	if type(id) == "string" and #id > 0 then
		return id
	end
	id = makeNodeId()
	model:SetAttribute(ATTR_NODE_ID, id)
	return id
end

function NodeService.register(model: Model)
        if not isNodeModel(model) then
                print("[NodeService] Ignored non-node", model and model:GetFullName())
                return
        end
        if nodeToId[model] then
                print("[NodeService] Already registered", model:GetFullName())
                return
        end
        ensureDefaults(model)

        local id = NodeService.assignNodeId(model)
        print("[NodeService] Registered", model:GetFullName(), "id=", id)

        
        local prev = idToNode[id]
        if prev and prev ~= model then
                
                if conns[prev] then conns[prev]:Disconnect() conns[prev] = nil end
                nodeToId[prev] = nil
        end

        idToNode[id] = model
        nodeToId[model] = id

        
        conns[model] = model.AncestryChanged:Connect(function(_, newParent)
                if newParent == nil then
                        NodeService.unregister(model)
                end
        end)
end

function NodeService.unregister(model: Model)
        local id = nodeToId[model]
        if not id then return end
        print("[NodeService] Unregistered", model:GetFullName(), "id=", id)
        nodeToId[model] = nil
        if idToNode[id] == model then
                idToNode[id] = nil
        end
        if conns[model] then
                conns[model]:Disconnect()
                conns[model] = nil
        end
end

function NodeService.getById(id: string): Model?
	return idToNode[id]
end

function NodeService.getId(model: Model): string?
	return nodeToId[model]
end

function NodeService.count()
	local c = 0
	for _ in pairs(idToNode) do c += 1 end
	return c
end

local function registerIfNode(inst: Instance)
        local mdl = rootModel(inst)
        if mdl and isNodeModel(mdl) and not nodeToId[mdl] then
                NodeService.register(mdl)
        end
end

function NodeService.start()

        local added = 0
        for _, inst in ipairs(Workspace:GetDescendants()) do
                if inst:IsA("Model") and isNodeModel(inst) and not nodeToId[inst] then
                        NodeService.register(inst)
                        added += 1
                end
        end

        Workspace.DescendantAdded:Connect(registerIfNode)

        print(("[NodeService] Índice iniciado: %d nodos registrados."):format(added))
end

function NodeService.isNode(model: Model): boolean
	return isNodeModel(model)
end

return NodeService
