local SwitchNode = require("mer.theGuarWhisperer.services.SceneNode.SwitchNode")
local common = require("mer.theGuarWhisperer.common")
local logger = common.log

---@class GuarWhisperer.NodeManager.itemValid.params
---@field reference tes3reference The reference being attached to
---@field item tes3item The chosen item to check for validity

---Returns a list of ids of items that are able to be attached to this node
---@alias GuarWhisperer.NodeManager.getItems fun(self: GuarWhisperer.NodeManager.InventoryAttachNode, reference: tes3reference): table<string, boolean>
---Callback for determining whether this node is active at all, before any item is selected
---@alias GuarWhisperer.NodeManager.isActive fun(self: GuarWhisperer.NodeManager.InventoryAttachNode, e: GuarWhisperer.NodeManager.RefNodeParams): boolean
---Callback for determining if the chosen item is valid for attaching to the node
---@alias GuarWhisperer.NodeManager.itemValid fun(self: GuarWhisperer.NodeManager.InventoryAttachNode, e: GuarWhisperer.NodeManager.itemValid.params): boolean
---This callback is to run additional logic after the item has been attached to the node. it will still run if no item was attached
---@alias GuarWhisperer.NodeManager.afterAttach fun(self: GuarWhisperer.NodeManager.InventoryAttachNode, e: GuarWhisperer.NodeManager.RefNodeParams, item: tes3item)
---If provided, a switch node of this name will be set to the "ON" child if the item is attached, or the "OFF" child otherwise
---@alias GuarWhisperer.NodeManager.switchId string

---@class GuarWhisperer.NodeManager.InventoryAttachNode : GuarWhisperer.NodeManager.Node
---@field getItems GuarWhisperer.NodeManager.getItems
---@field isActive GuarWhisperer.NodeManager.isActive
---@field itemValid GuarWhisperer.NodeManager.itemValid
---@field afterAttach? GuarWhisperer.NodeManager.afterAttach
---@field switchId? GuarWhisperer.NodeManager.switchId
local InventoryAttachNode = {}

---@class GuarWhisperer.NodeManager.InventoryAttachNode.config
---@field id string
---@field getItems GuarWhisperer.NodeManager.getItems
---@field isActive? GuarWhisperer.NodeManager.isActive
---@field itemValid? fun(self: GuarWhisperer.NodeManager.InventoryAttachNode, tes3item: tes3item): boolean
---@field afterAttach? GuarWhisperer.NodeManager.afterAttach
---@field switchId? GuarWhisperer.NodeManager.switchId


---@param e GuarWhisperer.NodeManager.InventoryAttachNode.config
---@return GuarWhisperer.NodeManager.InventoryAttachNode
function InventoryAttachNode.new(e)
    ---@type GuarWhisperer.NodeManager.InventoryAttachNode
    local self = setmetatable({}, { __index = InventoryAttachNode })
    self.id = e.id
    self.getItems = e.getItems
    self.isActive = e.isActive or function() return true end
    self.itemValid = e.itemValid or function() return true end
    self.afterAttach = e.afterAttach
    self.switchId = e.switchId
    return self
end

---@param e GuarWhisperer.NodeManager.RefNodeParams
function InventoryAttachNode:getItemToDisplay(e)
    local item = self:getInventoryItem(e.reference)
    if self:isActive(e) and item then
        return item
    end
end

---@param reference tes3reference
---@return tes3item|tes3misc?
function InventoryAttachNode:getInventoryItem(reference)
    for itemId in pairs(self:getItems(reference)) do
        local item = tes3.getObject(itemId)
        if item ~= nil and self:itemValid{ reference = reference, item = item} then
            if reference.object.inventory:contains(itemId) then
                return item
            end
        end
    end
end

---Detach all the children of the node. Still need to call update on the sceneNode
---@param e GuarWhisperer.NodeManager.RefNodeParams
function InventoryAttachNode:clearAttachNode(e)
    --remove children
    for i, childNode in ipairs(e.node.children) do
        if childNode then
            e.node:detachChildAt(i)
        end
    end
end

---@type GuarWhisperer.NodeManager.RefNodeParams
function InventoryAttachNode:doSwitchNode(e, hasItem)
    local switchNode = e.reference.sceneNode:getObjectByName(self.switchId)
    local childName = hasItem and "ON" or "OFF"
    local index = SwitchNode.getIndex(switchNode, childName)
    switchNode.switchIndex = index
end

function InventoryAttachNode:attachItem(e, item)
    logger:trace("Attaching %s to %s:%s", item.id, e.reference, e.node.name)
    local mesh = tes3.loadMesh(item.mesh, true):clone()
    mesh:clearTransforms()
    e.node:attachChild(mesh, true)
    e.reference.sceneNode:update()
    e.reference.sceneNode:updateEffects()
end

---@type GuarWhisperer.NodeManager.setNodeCallback
function InventoryAttachNode:setNode(e)
    self:clearAttachNode(e)
    local item = self:getInventoryItem(e.reference)
    if self.switchId then
        self:doSwitchNode(e, item ~= nil)
    end
    if item then
        self:attachItem(e, item)
    end
    if self.afterAttach then
        self:afterAttach(e, item)
    end
end

return InventoryAttachNode