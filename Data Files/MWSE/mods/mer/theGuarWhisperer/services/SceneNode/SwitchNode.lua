local common = require("mer.theGuarWhisperer.common")
local logger = common.log



---Returns the index of the child node to select as Active inside the Switch Node
---@alias GuarWhisperer.NodeManager.SwitchNode.getActiveIndex fun(self: GuarWhisperer.NodeManager.SwitchNode, e: GuarWhisperer.NodeManager.RefNodeParams): number

---@class GuarWhisperer.NodeManager.SwitchNode : GuarWhisperer.NodeManager.Node
---@field getActiveIndex GuarWhisperer.NodeManager.SwitchNode.getActiveIndex
local SwitchNode = {}
SwitchNode.__index = SwitchNode

---@class GuarWhisperer.NodeManager.SwitchNode.config
---@field id string
---@field getActiveIndex GuarWhisperer.NodeManager.SwitchNode.getActiveIndex

---@param e GuarWhisperer.NodeManager.SwitchNode.config
---@return GuarWhisperer.NodeManager.SwitchNode
function SwitchNode.new(e)
    local self = setmetatable({}, { __index = SwitchNode })
    self.id = e.id
    self.getActiveIndex = e.getActiveIndex
    return self
end

---@param e GuarWhisperer.NodeManager.RefNodeParams
function SwitchNode:setNode(e)
    local index = self:getActiveIndex({
        reference = e.reference,
        node = e.node
    })
    logger:trace("Setting switch index of %s to %d", e.node.name, index)
    e.node.switchIndex = index
end

---@param node niNode
---@param name string
---@return number?
function SwitchNode.getIndex(node, name)
    for i, child in ipairs(node.children) do
        local isMatch = name and child and child.name
            and child.name:lower() == name:lower()
        if isMatch then
            return i - 1
        end
    end
    logger:warn("Could not find child node %s in %s", name, node.name)
end

return SwitchNode