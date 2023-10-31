--[[

    The Guar Whisperer
        by Merlord

    This mod allows you to tame and breed guars.

    Author: Merlord (https://www.nexusmods.com/morrowind/users/3040468)
    Original script from Feed the animals mod by OperatorJack and RedFurryDemon
    https://www.nexusmods.com/morrowind/mods/47894

]]
require("mer.theGuarWhisperer.MCM")
require("mer.theGuarWhisperer.quickkeys")
require("mer.theGuarWhisperer.integrations")

local Animal = require("mer.theGuarWhisperer.Animal")
local AnimalConverter = require("mer.theGuarWhisperer.services.AnimalConverter")
local commandMenu = require("mer.theGuarWhisperer.CommandMenu.CommandMenuModel")
local ui = require("mer.theGuarWhisperer.ui")
local animalConfig = require("mer.theGuarWhisperer.animalConfig")
local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("main")
require("mer.theGuarWhisperer.interop")


local function activateAnimal(e)
    logger:trace("activateAnimal(): Activating %s", e.target.object.id)
    if not common.getModEnabled() then
        logger:trace("activateAnimal(): mod is disabled")
        return
    end
    if e.activator ~= tes3.player then
        logger:trace("activateAnimal(): Player is not activating")
        return
    end
    --check if companion
    local animal = Animal.get(e.target)
    if animal then
        logger:trace("activateAnimal(): %s is a guar", e.target.object.id)
        return animal:activate()
    else
        if e.target.object.script then
            local obj = e.target.baseObject or e.target.object
            if common.config.mcm.exclusions[obj.id:lower()] then
                logger:trace("Scripted but whitelisted")
            else
                logger:trace("activateAnimal(): %s is blacklisted", e.target.object.id)
                return
            end
        end
        if not e.target.mobile then
            logger:trace("activateAnimal(): %s does not have an associated mobile", e.target.object.id)
            return
        end
        if common.getIsDead(e.target) then
            logger:trace("activateAnimal(): %s is dead", e.target.object.id)
            return
        end
        local convertConfig = AnimalConverter.getConvertConfig(e.target)
        if not convertConfig then
            logger:trace("activateAnimal(): Failed to get animal data for %s", e.target.object.id)
        else
            local foodId
            local animalType = AnimalConverter.getTypeFromConfig(convertConfig)
            for ingredient, _ in pairs(animalType.foodList) do
                if tes3.player.object.inventory:contains(ingredient) then
                    foodId = ingredient
                    break
                end
            end
            if not foodId then
                logger:trace("activateAnimal(): No valid guar food found on player")
            else
                logger:trace("activateAnimal(): Food (%s) found, triggering messageBox to tame guar", foodId)
                local food = tes3.getObject(foodId)
                tes3ui.showMessageMenu{
                    message = string.format("The %s sniffs around your pack. He seems to be eyeing up your %s.", e.target.object.name, food.name),
                    buttons = {
                        {
                            text = string.format("Give the %s some %s", e.target.object.name, food.name),
                            callback = function()
                                local newAnimal = AnimalConverter.convert(e.target, convertConfig)
                                if not newAnimal then
                                    logger:error("Failed to convert guar")
                                    return
                                end
                                newAnimal.hunger:eatFromInventory(food)
                                timer.start{
                                    duration = 1.5,
                                    callback = function()
                                        if not newAnimal:isValid() then return end
                                        newAnimal:rename()
                                        timer.delayOneFrame(function()
                                            local name = newAnimal:getName()
                                            local heShe = newAnimal.syntax:getHeShe(true)
                                            local himHer = newAnimal.syntax:getHimHer(true)
                                            local hisHer = newAnimal.syntax:getHisHer(true)
                                            tes3.messageBox{
                                                message = string.format(
                                                    "%s doesn't trust you enough to accompany you. Try petting %s and giving %s some treats. As %s trust builds up over time, %s will learn new skills like fetching items and wearing a pack.",
                                                    name, himHer, himHer, hisHer, heShe
                                                ),
                                                buttons = { "Okay" }
                                            }
                                        end)
                                    end
                                }
                            end
                        },
                        {
                            text = "Do nothing",
                            callback = function()
                                local sadAnim = animalConfig.idles.sad
                                tes3.playAnimation{
                                    reference = e.target,
                                    group = tes3.animationGroup[sadAnim],
                                    loopCount = 1,
                                    startFlag = tes3.animationStartFlag.immediate
                                }
                                tes3.messageBox("%s gives out a sad whine.", e.target.object.name)
                            end
                        }
                    }
                }
                return false
            end
        end
    end
end


local function isAffectedBySpellType(mobile, spellType)
    for _, activeEffect in pairs(mobile.activeMagicEffectList) do
        local instance = activeEffect.instance
        if instance then
            if instance.source.castType == spellType then
                logger:trace("Is affected by spell type")
                return true
            end
        end
    end
end

---@param e uiObjectTooltipEventData
local function onTooltip(e)
    if not common.getModEnabled() then return end
    local animal = Animal.get(e.reference)
    if animal then
        --Rename
        local label = e.tooltip:findChild(tes3ui.registerID("HelpMenu_name"))
        if animal:getName() then
            local unNamedBaby = (animal.genetics:isBaby() and not animal:getName())
            local prefix = unNamedBaby and "Baby " or ""
            label.text = prefix .. animal:getName()
        end

        if isAffectedBySpellType(animal.reference.mobile, tes3.spellType.blight) then
            label.text = label.text .. (" (Blighted)")
        elseif isAffectedBySpellType(animal.reference.mobile, tes3.spellType.disease) then
            label.text = label.text .. (" (Diseased)")
        end

        --Add stats
        ui.createStatsBlock(e.tooltip, animal)
    end
end

local function guarTimer()
    if not common.getModEnabled() then return end
    Animal.referenceManager:iterateReferences(function(_, animal)
        if animal:isActive() then
            animal.genetics:updateGrowth()
            animal:updateAI()
            animal:updateTravelSpells()
        end
        animal.needs:updateNeeds()
        animal:updateCloseDistance()
    end)
end

---@param animal GuarWhisperer.Animal
local function findFood(animal)
    for ref in animal.reference.cell:iterateReferences(tes3.objectType.container) do
        if animal:canEat(ref) then
            if animal:distanceFrom(ref) < 1000 then
                return ref
            end
        end
    end
    for ref in animal.reference.cell:iterateReferences(tes3.objectType.ingredient) do
        if animal:canEat(ref) then
            if animal:distanceFrom(ref) < 1000 then
                return ref
            end
        end
    end
end

---@param animal GuarWhisperer.Animal
local function findGreetable(animal)
    for ref in animal.reference.cell:iterateReferences(tes3.objectType.creature) do
        local isHappyGuar = (
            ref ~= animal.reference and
            animalConfig.greetableGuars[ref.object.mesh:lower()] and
            ref.mobile and ref.mobile.health.current > 5 and
            not ref.mobile.inCombat
        )

        if isHappyGuar then
            if animal:distanceFrom(ref) < 1000 then
                logger:debug("Found Guar '%s' to greet", ref.object.name)
                return ref
            end
        end
    end
    for ref in animal.reference.cell:iterateReferences(tes3.objectType.npc) do
        local isHappyNPC = (
            ref.mobile and
            not ref.mobile.isDead and
            not ref.mobile.inCombat and
            ref.mobile.fight < 70
        )
        if isHappyNPC then
            if animal:distanceFrom(ref) < 1000 then
                logger:debug("Found NPC '%s' to greet", ref.object.name)
                return ref
            end
        end
    end
end


local lastRef
local function randomActTimer()
    if not common.getModEnabled() then return end
    logger:debug("Random Act Timer")
    local actingRef
    Animal.referenceManager:iterateReferences(function(_, animal)
        if animal.mobile then
            if animal:isActive() then
                if animal:getAI() == "wandering" then
                    logger:debug("%s is wandering, deciding action", animal:getName())
                    if animal.reference.id ~= lastRef then
                        actingRef = animal.reference.id
                        --check for food to eat
                        if animal.needs:getHunger() > 40 then
                            local food = findFood(animal)
                            if food then
                                logger:debug("randomActTimer: Guar eating")
                                animal:moveToAction(food, "eat", true)
                                return false
                            end
                        end
                        --check for other guar
                        local guar = findGreetable(animal)
                        if guar then
                            logger:debug("randomActTimer: Guar greeting")
                            animal:moveToAction(guar, "greet", true)
                            return false
                        end
                        if math.random(100) < 20 then
                            logger:debug("randomActTimer: Guar running")
                            animal.reference.mobile.isRunning = true
                        end
                    end
                elseif animal:getAI() == "waiting" then
                    local rand = math.random(100)
                    logger:debug("rand: %s", rand)
                    for _, data in ipairs(common.config.properties.WAITING_IDLE_CHANCES) do
                        if rand < data.maxChance then
                            logger:debug("playing random animation %s",data.group)
                            tes3.playAnimation{
                                reference = animal.reference,
                                group = tes3.animationGroup[data.group],
                                loopCount = 1,
                                startFlag = tes3.animationStartFlag.normal
                            }
                            break
                        end
                    end
                end
            end
        end
    end)
    --only one guar, let him act again
    if actingRef == lastRef then
        lastRef = nil
    else
        --otherwise block him so others can go
        lastRef = actingRef
    end
    timer.start{
        type = timer.simulate,
        iterations = 1,
        duration = math.random(20, 40),
        callback = randomActTimer
    }
end

local function startTimers()
    timer.start{
        type = timer.simulate,
        iterations = -1,
        duration = 0.2,
        callback = guarTimer
    }
    timer.start{
        type = timer.simulate,
        iterations = 1,
        duration = math.random(5, 10),
        callback = randomActTimer
    }
end


--Iterate over active animals
local function onDataLoaded()
    commandMenu:destroy()
    --initialiseVisuals()
    startTimers()
    --mwscript.addTopic{ topic = "raising guars" }
end

--Keep track of active references
local function onObjectInvalidated(e)
    local ref = e.object
    if ( not not common.fetchItems[ref] ) then
        common.fetchItems[ref] = nil
    end
end

local function onDeath(e)
    local animal = Animal.get(e.reference)
    if animal then
        animal.refData.dead = true
        animal.refData.aiState = nil
        if animal.pack:hasPack() then
            tes3.addItem{
                reference = animal.reference,
                item = common.packId,
                playSound = false
            }
        end
    end
end

--[[
    For guars from an old update, transfer them to new data table
]]
---@param e { reference: tes3reference}
local function convertOldGuar(e)
    if  tes3.player
        and tes3.player.data
        and tes3.player.data.theGuarWhisperer
        and tes3.player.data.theGuarWhisperer.companions
        and tes3.player.data.theGuarWhisperer.companions[e.reference.id]
    then
        e.reference.data.tgw = tes3.player.data.theGuarWhisperer.companions[e.reference.id]
        tes3.player.data.theGuarWhisperer.companions[e.reference.id] = nil
    end

    local objectId = e.reference.baseObject.id:lower()
    local legacyConvertConfig = animalConfig.legacyGuarToConvertConfig[objectId]
    if legacyConvertConfig then
        logger:info("Converting legacy %s into new guar object", objectId)
        ---@type GuarWhisperer.ConvertConfig
        legacyConvertConfig = table.copy(legacyConvertConfig)
        legacyConvertConfig.transferInventory = true
        AnimalConverter.convert(e.reference, legacyConvertConfig)
    end
end

---@return string
local function getVersion()
    local versionFile = io.open("Data Files/MWSE/mods/mer/theGuarWhisperer/version.txt", "r")
    if not versionFile then return "[VERSION_NOT_FOUND]" end
    local version = ""
    for line in versionFile:lines() do -- Loops over all the lines in an open text file
        version = line
    end
    return version
end

local function initialised()
    if tes3.isModActive("TheGuarWhisperer.ESP") then
        require("mer.theGuarWhisperer.services.AI")
        require("mer.theGuarWhisperer.fetch")
        require("mer.theGuarWhisperer.merchant")
        require("mer.theGuarWhisperer.CommandMenu.commandMenuController")
        require("mer.theGuarWhisperer.services.Flute")
        event.register("activate", activateAnimal)
        event.register("uiObjectTooltip", onTooltip)
        event.register("GuarWhispererDataLoaded", onDataLoaded)
        event.register("objectInvalidated", onObjectInvalidated)
        event.register("death", onDeath)
        --event.register("activate", checkDoorTeleport)
        logger:info("%s Initialised", getVersion())
        event.register("loaded", function()
            local refs = {}
            for _, cell in ipairs(tes3.getActiveCells()) do
                for ref in cell:iterateReferences(tes3.objectType.creature) do
                    table.insert(refs, ref)
                end
            end
            for _, ref in ipairs(refs) do
                convertOldGuar{ reference = ref }
            end
            event.unregister("mobileActivated", convertOldGuar)
            event.register("mobileActivated", convertOldGuar)
        end)
    end
end
event.register("initialized", initialised)
