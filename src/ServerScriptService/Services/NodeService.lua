-- ServerScriptService/Services/NodeService.lua
-- v1.0 - Índice de nodos para lookup O(1)
-- - Registra automáticamente nodos con tags "Stone" o "Crystal"
-- - Garantiza que cada nodo tiene atributo NodeId (GUID compacto)
-- - Expone getById / getId / register / unregister / start

local CollectionService = game:GetService("CollectionService")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")

local TAG_STONE         = "Stone"
local TAG_CRYSTAL       = "Crystal"
local ATTR_NODE_ID      = "NodeId"

local NodeService = {}

-- Mapas principales
local idToNode   : {[string]: Model} = {}
local nodeToId   : {[Instance]: string} = {}
local conns      : {[Instance]: RBXScriptConnection} = {}

-- ========= Helpers =========
local function hasTagDeep(model: Model, tag: string): boolean
	if CollectionService:HasTag(model, tag) then return true end
	if model.PrimaryPart and CollectionService:HasTag(model.PrimaryPart, tag) then return true end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and CollectionService:HasTag(d, tag) then
			return true
		end
	end
	return false
end

local function isNodeModel(model: Model?): boolean
	if not model or not model:IsA("Model") then return false end
	return hasTagDeep(model, TAG_STONE) or hasTagDeep(model, TAG_CRYSTAL)
end

local function rootModelForTagged(inst: Instance?): Model?
	if not inst then return nil end
	if inst:IsA("Model") then return inst end
	return inst:FindFirstAncestorOfClass("Model")
end

local function makeNodeId(): string
	-- GUID compacto sin guiones, prefijo "N_"
	local g = HttpService:GenerateGUID(false) -- "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
	g = g:gsub("%-", "")
	return "N_" .. g
end

-- ========= Core =========
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
	if not isNodeModel(model) then return end
	if nodeToId[model] then return end

	local id = NodeService.assignNodeId(model)

	-- Si ya existía otro nodo con el mismo id (poco probable), lo reemplazamos
	local prev = idToNode[id]
	if prev and prev ~= model then
		-- Limpieza del anterior
		if conns[prev] then conns[prev]:Disconnect() conns[prev] = nil end
		nodeToId[prev] = nil
	end

	idToNode[id] = model
	nodeToId[model] = id

	-- Auto-unregister si el nodo se destruye/sale del árbol
	conns[model] = model.AncestryChanged:Connect(function(_, newParent)
		if newParent == nil then
			NodeService.unregister(model)
		end
	end)
end

function NodeService.unregister(model: Model)
	local id = nodeToId[model]
	if not id then return end
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

-- ========= Bootstrap =========
local function registerIfNode(inst: Instance)
	local mdl = rootModelForTagged(inst)
	if mdl and isNodeModel(mdl) then
		NodeService.register(mdl)
	end
end

local function unregisterIfNode(inst: Instance)
	local mdl = rootModelForTagged(inst)
	if mdl and nodeToId[mdl] then
		NodeService.unregister(mdl)
	end
end

function NodeService.start()
	-- 1) Indexar existentes por tag
	local added = 0
	for _, tag in ipairs({TAG_STONE, TAG_CRYSTAL}) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do
			local mdl = rootModelForTagged(inst)
			if mdl and isNodeModel(mdl) and not nodeToId[mdl] then
				NodeService.register(mdl); added += 1
			end
		end
	end

	-- 2) Señales de alta/baja por tag
	for _, tag in ipairs({TAG_STONE, TAG_CRYSTAL}) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(registerIfNode)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unregisterIfNode)
	end

	print(("[NodeService] Índice iniciado: %d nodos registrados."):format(added))
end

-- API de utilidad (opcional)
function NodeService.isNode(model: Model): boolean
	return isNodeModel(model)
end

return NodeService
