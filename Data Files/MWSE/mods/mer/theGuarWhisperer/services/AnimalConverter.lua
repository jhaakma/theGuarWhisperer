local Animal = require("mer.theGuarWhisperer.Animal")
local animalConfig = require("mer.theGuarWhisperer.animalConfig")
local common = require("mer.theGuarWhisperer.common")
logger = common.log

---@class GuarWhisperer.AnimalConverter.convert.params
---@field reference tes3reference

---@class GuarWhisperer.AnimalConverter
local AnimalConverter = {}

---@param reference tes3reference
---@param data GuarWhisperer.ConvertData
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
    reference:delete()

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

---Get the animal type and extra data for a given vanilla
--- guar reference.
---@return GuarWhisperer.ConvertData?
function AnimalConverter.getConvertData(reference)
    logger:trace("Get convert data")
    if not reference then
        logger:trace("No reference")
        return nil
    end
    if not reference.mobile then
        logger:trace("No mobile")
        return nil
    end
    if not (reference.object.objectType == tes3.objectType.creature) then
        logger:trace("Not a creature")
        return nil
    end
    local crMesh = reference.object.mesh:lower()
    logger:trace("Finding type for mesh %s", crMesh)
    local typeData = animalConfig.meshes[crMesh]
    if typeData then
        return typeData
    else
        logger:trace("No type data")
        return nil
    end
end


return AnimalConverter