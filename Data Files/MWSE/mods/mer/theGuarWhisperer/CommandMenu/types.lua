---@meta

---@class GuarWhisperer.CommandEvent
---@field activeCompanion GuarWhisperer.Companion.Guar
---@field inMenu boolean
---@field changePage function

---@alias GuarWhisperer.Command.Labelcallback fun(e:GuarWhisperer.CommandEvent):string

---@class GuarWhisperer.CommandConfig
---@field label GuarWhisperer.Command.Labelcallback
---@field description string
---@field command fun(e:GuarWhisperer.CommandEvent)
---@field requirements fun(e:GuarWhisperer.CommandEvent):boolean