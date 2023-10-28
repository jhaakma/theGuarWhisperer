--- A collection of utility functions
---@class GuarWhisperer.common.Util
local Util = {}

function Util.getHoursPassed()
    return ( tes3.worldController.daysPassed.value * 24 ) + tes3.worldController.hour.value
end

return Util