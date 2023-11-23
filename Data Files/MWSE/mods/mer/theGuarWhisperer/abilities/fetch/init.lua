require("mer.theGuarWhisperer.abilities.fetch.eventHandler")

---@class GuarWhisperer.Fetch
local Fetch = {}

local pickableObjectTypes = {
    [tes3.objectType.alchemy] = true,
    [tes3.objectType.ammunition] = true,
    [tes3.objectType.apparatus] = true,
    [tes3.objectType.armor] = true,
    [tes3.objectType.book] = true,
    [tes3.objectType.clothing] = true,
    [tes3.objectType.ingredient] = true,
    [tes3.objectType.light] = true,
    [tes3.objectType.lockpick] = true,
    [tes3.objectType.miscItem] = true,
    [tes3.objectType.probe] = true,
    [tes3.objectType.repairItem] = true,
    [tes3.objectType.weapon] = true,
}

---@return boolean canFetch Whether the reference item can be fetched
function Fetch.canFetch(reference)
    return reference
    and reference.object.canCarry ~= false
    and pickableObjectTypes[reference.object.objectType]
end

return Fetch