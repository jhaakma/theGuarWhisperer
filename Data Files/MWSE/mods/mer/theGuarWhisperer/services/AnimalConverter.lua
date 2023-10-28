local Animal = require("mer.theGuarWhisperer.Animal")
local animalConfig = require("mer.theGuarWhisperer.animalConfig")
local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("AnimalConverter")

---@class GuarWhisperer.AnimalConverter.convert.params
---@field reference tes3reference

---@class GuarWhisperer.AnimalConverter
local AnimalConverter = {}

---Override the base object stats
---@param baseObject tes3creature
---@param convertConfig GuarWhisperer.ConvertConfig
function AnimalConverter.overrideStats(baseObject, convertConfig)
    local statOverrides = convertConfig.statOverrides
    if not statOverrides then return end
    logger:debug("Overriding stats")
    if statOverrides.attributes then
        logger:debug("Overriding attributes")
        for attribute, value in pairs(statOverrides.attributes) do
            logger:debug("Setting %s to %d", attribute, value)
            baseObject.attributes[tes3.attribute[attribute] + 1] = value
        end
    end
    if statOverrides.attackMin or statOverrides.attackMax then
        for _, attack in ipairs(baseObject.attacks) do
            if statOverrides.attackMin then
                logger:debug("Setting attack min to %d", statOverrides.attackMin)
                attack.min = statOverrides.attackMin
            end
            if statOverrides.attackMax then
                logger:debug("Setting attack max to %d", statOverrides.attackMax)
                attack.max = statOverrides.attackMax
            end
        end
    end
end


---@param reference tes3reference
---@param convertConfig GuarWhisperer.ConvertConfig
function AnimalConverter.convert(reference, convertConfig)
    if reference.data.TGW_FLAGGED_FOR_DELETE then return end
    logger:debug("Converting %s into type '%s'", reference.object.id, convertConfig.type)
    local newObj = common.createCreatureCopy(reference.baseObject)
    if convertConfig.mesh then
        logger:debug("Replacing mesh with %s", convertConfig.mesh)
        newObj.mesh = convertConfig.mesh
    end
    AnimalConverter.overrideStats(newObj, convertConfig)

    local name = reference.data.tgw and reference.data.tgw.name
        or convertConfig.name
    if name then
        logger:debug("Replacing name with %s", name)
        newObj.name = name
    end

    reference.hasNoCollision = true
    local newRef = tes3.createReference{
        object = newObj,
        position = reference.position,
        orientation =  {
            reference.orientation.x,
            reference.orientation.y,
            reference.orientation.z,
        },
        cell = reference.cell,
    }
    if reference.data.tgw then
        newRef.data.tgw = table.copy(reference.data.tgw)
    end
    reference.data.TGW_FLAGGED_FOR_DELETE = true
    --Remove old ref
    reference:delete()

    Animal.initialiseRefData(newRef, convertConfig.type)
    table.copymissing(newRef.data.tgw, convertConfig.extra)
    local animal = Animal.get(newRef)
    if not animal then
        logger:error("Failed to create animal from reference %s", newRef)
        return
    end
    if animal.pack:hasPack() then
       animal.pack:setSwitch()
    end
    animal.genetics:randomiseGenes()

    logger:debug("Conversion done")
    return animal
end

---Get the animal type and extra data for a given vanilla
--- guar reference.
---@param reference tes3reference
---@return GuarWhisperer.ConvertConfig?
function AnimalConverter.getConvertConfig(reference)
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
    local typeData = animalConfig.meshToConvertConfig[crMesh]
    if typeData then
        return typeData
    else
        logger:trace("No type data")
        return nil
    end
end

---@param convertConfig GuarWhisperer.ConvertConfig
---@return GuarWhisperer.AnimalType
function AnimalConverter.getTypeFromConfig(convertConfig)
    return animalConfig.animals[convertConfig.type]
end

return AnimalConverter