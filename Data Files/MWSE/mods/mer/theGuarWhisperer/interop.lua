local GuarCompanion = require("mer.theGuarWhisperer.GuarCompanion")
local function eat(e)
    local animal = GuarCompanion.get(e.reference)
    if animal then
        animal.needs:modHunger(e.amount)
    end
end

event.register("Ashfall:Eat", eat)