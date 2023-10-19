local Animal = require("mer.theGuarWhisperer.Animal")
local animalConfig = require("mer.theGuarWhisperer.animalConfig")
local common = require("mer.theGuarWhisperer.common")

---@class GuarWhisperer.AnimalConverter
local AnimalConverter = {}

function AnimalConverter.convert(reference, data)
    local newRef = tes3.createReference{
        object = animalConfig.guarMapper[data.extra.color],
        position = reference.position,
        orientation =  {
            reference.orientation.x,
            reference.orientation.y,
            reference.orientation.z,
        },
        cell = reference.cell,
    }
    --Remove old ref
    reference:setDelete()

    local animal = Animal.get(newRef)
    if not animal then
        return
    end
    for key, val in pairs(data.extra) do
        animal.refData[key] = val
    end
    if animal.refData.hasPack then
        animal:setSwitch()
    end
    animal:randomiseGenes()

    animal:setHome(animal.reference.position, animal.reference.cell)

    return animal
end

return AnimalConverter