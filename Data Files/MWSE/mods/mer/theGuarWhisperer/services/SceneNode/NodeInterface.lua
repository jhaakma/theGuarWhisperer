---@meta

---@class GuarWhisperer.NodeManager.RefNodeParams
---@field reference tes3reference
---@field node niNode|niSwitchNode

---A callback which returns true if the node should be displayed. If not provided, will always return true
---@alias GuarWhisperer.NodeManager.setNodeCallback fun(self: GuarWhisperer.NodeManager.Node, e: GuarWhisperer.NodeManager.RefNodeParams)

---@class GuarWhisperer.NodeManager.Node
---@field id string The id (name) of the attach/switch node
---@field setNode GuarWhisperer.NodeManager.setNodeCallback