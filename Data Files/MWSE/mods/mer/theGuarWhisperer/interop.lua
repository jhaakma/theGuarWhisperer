local Animal = require("mer.theGuarWhisperer.Animal")
local function eat(e)
    local animal = Animal.get(e.reference)
    if animal then
        animal:modHunger(e.amount)
    end
end

event.register("Ashfall:Eat", eat)