---@alias GuarWhisperer.Emotion
---| '"happy"'
---| '"sad"'
---| '"pet"'
---| '"eat"'
---| '"fetch"'
---| '"idle"'

---@alias GuarWhisperer.Animal.AIState
---| '"waiting"' #Not moving, doing nothing
---| '"following"' #Following the player
---| '"wandering"' #Wandering around
---| '"moving"' #Moving to a specific location
---| '"attacking"' #Attacking a target

---@alias GuarWhisperer.Animal.AttackPolicy
---| '"passive"'
---| '"defend"'

---@alias GuarWhisperer.Animal.PotionPolicy
---| '"none"'
---| '"all"'
---| '"healthOnly"'

---@class GuarWhisperer.Animal.Home
---@field position { [0]:number, [1]:number, [2]:number}
---@field cell string

---@class GuarWhisperer.Animal.RefData
---@field name string
---@field attackPolicy GuarWhisperer.Animal.AttackPolicy
---@field followingRef tes3reference|"player"
---@field aiState GuarWhisperer.Animal.AIState
---@field previousAiState GuarWhisperer.Animal.AIState
---@field home GuarWhisperer.Animal.Home
---@field dead boolean is dead
---@field carriedItems table<string, {name:string, id:string, count:number, itemData:tes3itemData}>
---@field stuckStrikes number
---@field lastStuckPosition {x:number, y:number, z:number}
---@field aiBroken number
---@field commandActive boolean is currently doing a command
---@field triggerDialog boolean trigger dialog on next activate

---@class GuarWhisperer.Animal
---@field reference tes3reference
---@field safeRef mwseSafeObjectHandle
---@field refData GuarWhisperer.Animal.RefData
---@field mobile tes3mobileCreature
---@field object tes3creature
---@field animalType GuarWhisperer.AnimalType
---@field attributes table<string, number>
---@field stats GuarWhisperer.Stats
---@field aiFixer GuarWhisperer.AIFixer
---@field pack GuarWhisperer.Pack
---@field syntax GuarWhisperer.Syntax
---@field genetics GuarWhisperer.Genetics
---@field lantern GuarWhisperer.Lantern
---@field needs GuarWhisperer.Needs
---@field hunger GuarWhisperer.Hunger
local Animal = {}


local animalConfig = require("mer.theGuarWhisperer.animalConfig")
local harvest = require("mer.theGuarWhisperer.harvest")
local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("Animal")
local ui = require("mer.theGuarWhisperer.ui")
local ashfallInterop = include("mer.ashfall.interop")
local CraftingFramework = require("CraftingFramework")
local Controls = require("mer.theGuarWhisperer.services.Controls")
local AIFixer = require("mer.theGuarWhisperer.components.AIFixer")
local Syntax = require("mer.theGuarWhisperer.components.Syntax")
local Pack = require("mer.theGuarWhisperer.components.Pack")
local Stats = require("mer.theGuarWhisperer.components.Stats")
local Genetics = require("mer.theGuarWhisperer.components.Genetics")
local Lantern = require("mer.theGuarWhisperer.components.Lantern")
local Needs = require("mer.theGuarWhisperer.components.Needs")
local Hunger = require("mer.theGuarWhisperer.components.Hunger")

---@type table<tes3.objectType, boolean>
Animal.pickableObjects = {
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

---@type table<tes3.objectType, table>
Animal.pickableRotations = {
    [tes3.objectType.ammunition] = {x=math.rad(270) },
    [tes3.objectType.armor] = {x=math.rad(270) },
    [tes3.objectType.book] = {x=math.rad(270) },
    [tes3.objectType.clothing] = {x=math.rad(270) },
    [tes3.objectType.ingredient] = {x=math.rad(270) },
    [tes3.objectType.lockpick] = {x=math.rad(90) },
    [tes3.objectType.miscItem] = {x=math.rad(270) },
    [tes3.objectType.probe] = {x=math.rad(90) },
    [tes3.objectType.repairItem] = {x=math.rad(90) },
    [tes3.objectType.weapon] = {x=math.rad(90) },
}
---------------------
--Internal methods
---------------------

-- Reference Manager for Animal references
---@class GuarWhisperer.Animal.ReferenceManager : CraftingFramework.ReferenceManager
---@field references table<tes3reference, GuarWhisperer.Animal>
Animal.referenceManager = CraftingFramework.ReferenceManager:new{
    id = "GuarWhisperer_Animals",
    requirements = function(_, ref)
        return ref.supportsLuaData and ref.data.tgw ~= nil
    end,
    onActivated = function(refManager, ref)
        local animal = Animal:new(ref)
        if animal then
            --Cache the animal class
            refManager.references[ref] = animal
            --intiialise
            animal:initialiseOnActivated()
        else
            logger:warn("Ref %s with tgw data was not valid animal", ref)
        end
    end
}

---@param reference tes3reference
---@return GuarWhisperer.Animal.RefData
function Animal.initialiseRefData(reference, animalType)
    logger:debug("Initialising Ref data for %s", reference)
    local newData = {
        type = animalType,
        level = 1.0,
        attackPolicy = "defend",
        home = {
            position = {
                reference.position.x,
                reference.position.y,
                reference.position.z
            },
            cell = reference.cell.id
        },
    }

    reference.data.tgw = reference.data.tgw or {}
    table.copymissing(reference.data.tgw, newData)
    Animal.referenceManager:addReference(reference)
    Animal.referenceManager:onActivated(reference)
    return reference.data.tgw
end

---------------------
--Class methods
---------------------

function Animal:__index(key)
    return self[key]
end

---@param reference tes3reference
---@return GuarWhisperer.Animal|nil
function Animal.get(reference)
    local cachedAnimal = Animal.referenceManager.references[reference]
    return cachedAnimal or Animal:new(reference)
end


--- Get the animal type for a converter guar
---@param reference tes3reference
---@return GuarWhisperer.AnimalType?
function Animal.getAnimalType(reference)
    return reference
     and reference.data.tgw
     and animalConfig.animals[reference.data.tgw.type]
     or animalConfig.animals.guar
end

function Animal.getAnimalObjects()
    return common.config.persistentData.createdGuars
end

---Returns all animal references,
--- even those not in active cells
---@return GuarWhisperer.Animal[]
function Animal.getAll()
    local animals = {}
    local objects = Animal.getAnimalObjects()
    for objId in pairs(objects) do
        local reference = tes3.getReference(objId)
        if reference then
            local animal = Animal.get(reference)
            if animal then
                table.insert(animals, animal)
            end
        end
    end
    return animals
end


function Animal.addToCreatedObjects(obj)
    local createdObjects = Animal.getAnimalObjects()
    createdObjects[obj.id:lower()] = true
    logger:debug("Added %s to created objects", obj.id)
end

--- Construct a new Animal
---@param reference tes3reference
---@return GuarWhisperer.Animal|nil
function Animal:new(reference)
    if not (reference and reference.supportsLuaData and reference.data.tgw) then return end
    local animalType = Animal.getAnimalType(reference)
    if not animalType then
        logger:trace("No animal type")
        return
    end
    local newAnimal = {
        reference = reference,
        object = reference.object,
        mobile = reference.mobile,
        animalType = animalType,
        refData = reference.data.tgw,
    }
    newAnimal.safeRef = tes3.makeSafeObjectHandle(reference)
    newAnimal.stats = Stats.new(newAnimal)
    newAnimal.aiFixer = AIFixer.new(newAnimal)
    newAnimal.pack = Pack.new(newAnimal)
    newAnimal.syntax = Syntax.new(newAnimal.refData.gender)
    newAnimal.genetics = Genetics.new(newAnimal)
    newAnimal.lantern = Lantern.new(newAnimal)
    newAnimal.needs = Needs.new(newAnimal)
    newAnimal.hunger = Hunger.new(newAnimal)

    setmetatable(newAnimal, self)
    self.__index = self
    Animal.addToCreatedObjects(reference.baseObject)
    event.trigger("GuarWhisperer:registerReference", { reference = reference })
    return newAnimal
end

---Check if the reference associated with this Animal is still valid
---@return boolean isValid
function Animal:isValid()
    local valid = self.safeRef:valid()
    if not valid then
        logger:warn("%s's reference is invalid", self:getName())
    end
    return valid
end

--- Get the animals' name
---@return string
function Animal:getName()
    return self.object.name
end

function Animal:setName(newName)
    self.object.name = newName
end


--- Set the attack policy
---@param policy GuarWhisperer.Animal.AttackPolicy
function Animal:setAttackPolicy(policy)
    self.refData.attackPolicy = policy
end

--- Get the attack policy
---@return GuarWhisperer.Animal.AttackPolicy
function Animal:getAttackPolicy()
    return self.refData.attackPolicy
end


function Animal:initialiseOnActivated()
    if not self:isDead() then
        self:playAnimation("idle")
        if self:hasCarriedItems() then
            for _, item in pairs(self:getCarriedItems()) do
                self:putItemInMouth(tes3.getObject(item.id))
            end
        end
        self.pack:setSwitch()
        self:updateAI()
        logger:info("intialised %s on activated", self:getName())
    end
end


---------------------
--Movement functions
-----------------------

--- Play an animation
---@param emotionType GuarWhisperer.Emotion
---@param doWait any
function Animal:playAnimation(emotionType, doWait)
    local groupId = animalConfig.idles[emotionType]
    if tes3.animationGroup[groupId] ~= nil then
        logger:debug("playing %s, wait: %s", groupId, doWait)
        tes3.playAnimation{
            reference = self.reference,
            group = tes3.animationGroup[groupId],
            loopCount = 0,
            startFlag = doWait and tes3.animationStartFlag.normal or tes3.animationStartFlag.immediate
        }
    end
end

--- Set the AI State
---@param aiState GuarWhisperer.Animal.AIState
function Animal:setAI(aiState)
    logger:debug("Setting AI to %s", aiState)
    aiState = aiState or "waiting"
    self.refData.aiState = aiState
    local states ={
        following = self.returnTo,
        waiting = self.wait,
        wandering = self.wander,
        moving = self.wait,
    }
    local callback = states[aiState]
    if callback then callback(self) end
end

--- Get the current AI state
---@return GuarWhisperer.Animal.AIState
function Animal:getAI()
    return self.refData.aiState or "waiting"
end

--- Restore the previous AI state
function Animal:restorePreviousAI()
    if self.refData.previousAiState then
        logger:debug("Restoring AI state to %s", self.refData.previousAiState)
        self:setAI(self.refData.previousAiState)
    end
    self.refData.previousAiState = nil
end

--- Teleport if too far away while following
function Animal:closeTheDistanceTeleport()
    if tes3.player.cell.isInterior then
        return
    elseif self:getAI() ~= "following" then
        return
    elseif self:isDead() then
        return
    end
    local doTeleportBehind = (
        tes3.player.mobile.isMovingForward or
        tes3.player.mobile.isMovingLeft or
        tes3.player.mobile.isMovingRight
    )
    local distance = doTeleportBehind and -400 or 400
    logger:debug("Closing the distance teleport")
    self:teleportToPlayer(distance)
end

--- Teleport to the player
---@param distance number? @Distance in front (positive) or behind (negative) the player
function Animal:teleportToPlayer(distance)
    distance = distance or 0
    local isForward = distance >= 0
    logger:debug("teleportToPlayer(): Distance: %s", distance)

    local eyeVec = tes3.getPlayerEyeVector()
    local position = tes3.getPlayerEyePosition()
    local direction = tes3vector3.new(
        eyeVec.x,
        eyeVec.y,
        0) * (isForward and -1 or 1)


    --do a raytest to avoid teleporting into stuff
    ---@type niPickRecord
    local rayResult = tes3.rayTest{
        position = position,
        direction = direction,
        maxDistance = math.abs(distance),
        ignore = {tes3.player, self.reference}
    }
    if rayResult and rayResult.intersection then
        distance = math.min(distance, rayResult.distance)
        logger:debug("Hit %s, new distance: %s", rayResult.object, distance)
    end

    local newPosition = tes3vector3.new(
        tes3.player.position.x + ( distance * math.sin(tes3.player.orientation.z)),
        tes3.player.position.y + ( distance * math.cos(tes3.player.orientation.z)),
        tes3.player.position.z
    )

    --Drop to ground
    if not tes3.isAffectedBy{ reference = self.reference, effect = tes3.effect.levitate } then
        local upDownResult = tes3.rayTest{
            position = newPosition,
            direction = tes3vector3.new(0, 0, -1),
            maxDistance = 5000,
            ignore = {tes3.player, self.reference}
        }
        --no down result, try up result
        if not (upDownResult and upDownResult.intersection) then
            upDownResult = tes3.rayTest{
                position = newPosition,
                direction = tes3vector3.new(0, 0, 1),
                maxDistance = 5000,
                ignore = {tes3.player, self.reference},
                useBackTriangles = true
            }
        end

        if upDownResult and upDownResult.intersection then
            local newZ

            local oldPosition = upDownResult.intersection

            --check we crossed the water level if passed 0 z
            local crossedWaterLevel = oldPosition.z > 0 and newPosition.z < 0
                or oldPosition.z < 0 and newPosition.z > 0
            if crossedWaterLevel then
                newZ = 0
            else
                local vertDist = upDownResult.intersection.z - newPosition.z
                newZ = newPosition.z + vertDist
            end
            logger:debug("Setting Z position from %s to %s", newPosition.z, newZ)
            newPosition = tes3vector3.new(newPosition.x, newPosition.y, newZ)
        else
            logger:debug("No teleport: failed to find ground below player")
            return
        end
    end

    local wasFollowing
    if self:getAI() == "following" then
        wasFollowing = true
        self:wait()
    end
    tes3.positionCell{
        reference = self.reference,
        position = newPosition,
        cell = tes3.player.cell
    }
    self.reference.sceneNode:update()
    self.reference.sceneNode:updateEffects()
    if wasFollowing then
        self:follow()
    end
end

--- Stay still
function Animal:wait(idles)
    if not self.reference.mobile then return end
    self.refData.aiState = "waiting"
    logger:debug("Waiting")
    tes3.setAIWander{
        reference = self.reference,
        range = 0,
        idles = idles or {
            0, --sit
            0, --eat
            0, --look
            0, --wiggle
            0, --n/a
            0, --n/a
            0, --n/a
            0
        },
        duration = 2
    }
end

--- Wander around
---@param range number? Default: 500
function Animal:wander(range)
    if not self.reference.mobile then return end
    logger:debug("Wandering")
    self.refData.aiState = "wandering"
    range = range or 500
    tes3.setAIWander{
        reference = self.reference,
        range = range,
        idles = {
            42, --sit
            05, --eat
            52, --look
            01, --wiggle
            0, --n/a
            0, --n/a
            0, --n/a
            0
        }
    }
end


--- Follow the player
---@param target tes3reference?
function Animal:follow(target)
    target = target or tes3.player
    logger:debug("Setting AI Follow")
    self.refData.aiState = "following"
    tes3.setAIFollow{ reference = self.reference, target = target }
end

--- Attack the target
function Animal:attack(target, blockMessage)
    logger:debug("Attacking %s", target.object.name)

    if blockMessage ~= true then
        tes3.messageBox("%s attacking %s", self:getName(), target.object.name)
    end
    self.refData.previousAiState = self:getAI()
    self:follow()
    local safeTargetRef = tes3.makeSafeObjectHandle(target)
    timer.start{
        duration = 0.5,
        callback = function()
            if not (safeTargetRef and safeTargetRef:valid()) then return end
            if not self:isValid() then return end
            if not target.mobile then return end
            self.reference.mobile:startCombat(target.mobile)
            self.refData.aiState = "attacking"
        end
    }
end


function Animal:moveToAction(reference, command, noMessage)
    self.refData.previousAiState = self:getAI()
    common.fetchItems[reference] = true
    self.reference.mobile.isRunning = true
    self:moveTo(reference.position)
    --Start simulate event to check if close enough to the reference
    local previousPosition
    local distanceTimer
    local function checkRefDistance()
        if not self:isValid() then
            distanceTimer:cancel()
            return
        end
        self.reference.mobile.isRunning = true
        local distances = {
            fetch = 100,
            harvest = 400,
            greet = 500,
            eat = 200
        }
        local distance = distances[command] or 100
        --for first frames during loading
        if not self:isActive() then return end

        local currentPosition = self.reference.position
        local currentDist = self:distanceFrom(reference)
        local stillFetching = currentDist > distance
            and ( previousPosition == nil or
                    currentPosition:distance(previousPosition) > 5 )
        previousPosition = self.reference.position:copy()
        if not stillFetching then
            --check reference hasn't been picked up
            if not common.fetchItems[reference] == true then
                self:returnTo()
            --Check if guar got all the way there
            elseif currentDist > 500 then
                if noMessage ~= true then
                    tes3.messageBox("Couldn't reach.")
                end
                self:restorePreviousAI()
            else
                timer.delayOneFrame(function()
                    if not self:isValid() then return end
                    self.reference.mobile.isRunning = false
                    if command == "eat" then
                        self:playAnimation("eat")
                    elseif command == "greet" then
                        self.needs:modPlay(self.animalType.play.greetValue)
                        self:playAnimation("pet")
                        tes3.playAnimation{
                            reference = reference,
                            group = tes3.animationGroup.idle,
                            loopCount = 1,
                            startFlag = tes3.animationStartFlag.normal
                        }
                    elseif command == "charm" then
                        self:playAnimation("pet")
                    else
                        self:playAnimation("fetch")
                    end
                end)

                --Wait until fetch animation completes, then pick up reference and follow player again
                timer.start{
                    type = timer.simulate,
                    duration = 1,
                    callback = function()
                        if not self:isValid() then return end
                        if common.fetchItems[reference] == true then
                            local duration
                            if command == "harvest" then
                                self:harvestItem(reference)
                                duration = 1
                            elseif command == "eat" then
                                self:eatFromWorld(reference)
                                self:playAnimation("happy", true)
                                timer.start{
                                    type = timer.simulate,
                                    duration = 1,
                                    callback = function()
                                        if not self:isValid() then return end
                                        tes3.playSound{ reference = self.reference, sound = "Swallow" }
                                    end
                                }
                                duration = 2.5
                            elseif command == "greet" then
                                duration = 3
                            elseif command == "charm" then
                                duration = 2
                                self:charm(reference)
                            else
                                self:pickUpItem(reference)
                                duration = 1
                            end
                            timer.start{
                                type = timer.simulate,
                                duration = duration,
                                callback = function()
                                    if not self:isValid() then return end
                                    if command == "fetch" or command == "harvest" then
                                        self.stats:progressLevel(self.animalType.lvl.fetchProgress)
                                        self:returnTo()
                                    else
                                        logger:debug("Previous AI: %s", self.refData.previousAiState)
                                        self:restorePreviousAI()
                                    end
                                end
                            }
                        end
                    end
                }
            end
            distanceTimer:cancel()
        end
    end
    distanceTimer = timer.start{
        type = timer.simulate,
        iterations = -1,
        duration = 0.75,
        callback = checkRefDistance
    }
end

--- Move to the given position
function Animal:moveTo(position)
    tes3.setAITravel{ reference = self.reference, destination = position }
    self.refData.aiState = "moving"
end

--- Return to the player
function Animal:returnTo()
    self:follow()
    self.aiFixer:resetFollow()
end

local CELL_WIDTH = 8192
local HOURS_PER_CELL = 0.5
--- Calculate how long it takes to travel home
function Animal:getTravelTime()
    local homePos = tes3vector3.new(
        self.refData.home.position[1],
        self.refData.home.position[2],
        self.refData.home.position[3]
    )
    local distance = self.reference.position:distance(homePos)
    logger:debug("travel distance: %s", distance)
    local travelTime =  HOURS_PER_CELL * (distance/CELL_WIDTH)
    logger:debug("travel time: %s", travelTime)
    return travelTime
end

--- Get the travel time as a formatted string
function Animal:getTravelTimeText(hours)
    hours = hours or self:getTravelTime()
    return string.format("%dh%2.0fm", hours, 60*( hours - math.floor(hours)))
end

-- Go back to its home position
---@param e { takeMe: boolean }?
function Animal:goHome(e)
    local home = self:getHome()
    e = e or {}
    local hoursPassed = ( e.takeMe and self:getTravelTime() or 0 )
    local secondsTaken = ( e.takeMe and math.min(hoursPassed, 3) or 1)
    if not home then
        tes3.messageBox("No home set")
        return
    else
        if e.takeMe then
            if ashfallInterop then ashfallInterop.blockSleepLoss() end
        else
            self:wait()
            timer.delayOneFrame(function()
                if not self:isValid() then return end
                self:wander()
            end)
        end
        Controls.fadeTimeOut(hoursPassed, secondsTaken, function()
            tes3.positionCell{
                reference = self.reference,
                position = home.position,
                --cell = self.refData.home.cell
            }
            if e.takeMe then
                tes3.positionCell{
                    reference = tes3.player,
                    position = home.position,
                }
                if ashfallInterop then ashfallInterop.unblockSleepLoss() end
            else
                tes3.messageBox("%s has gone home to %s", self:getName(), tes3.getCell{ id = home.cell })
            end
        end)
    end
end

---@return GuarWhisperer.Animal.Home
function Animal:getHome()
    return self.refData.home
end

--[[
    position must be tes3vector3, cell must be tes3cell
    converts position to table and cell to id for serialisation
]]
function Animal:setHome(position, cell)
    local newPosition = { position.x, position.y, position.z}
    self.refData.home = { position = newPosition, cell = cell.id }
    tes3.messageBox("Set %s's new home in %s", self:getName(), cell.id)
end

function Animal:isDead()
    return self.refData.dead or common.getIsDead(self.reference)
end

--------------------------------
-- Fetch Functions
--------------------------------

function Animal:canBeSummoned()
    return (
        self:isDead() ~= true and
        self.needs:hasSkillReqs("follow")
    )
end



function Animal:canEat(ref)
    if ref.isEmpty then
        return false
    end
    return self.animalType.foodList[string.lower(ref.object.id)]
end

function Animal:canHarvest(reference)
    return (
        self:isDead() ~= true and
        reference and
        not reference.isEmpty and
        harvest.isHerb(reference)
    )
end

function Animal:canFetch(reference)
    return (
        reference and
        reference.object.canCarry ~= false and --nil or true is fine
        self.pickableObjects[reference.object.objectType]
    )
end


---@return boolean
function Animal:hasCarriedItems()
    return table.size(self:getCarriedItems()) > 0
end


function Animal:getCarriedItems()
    return self.refData.carriedItems or {}
end

function Animal:addToCarriedItems(name, id, count)
    self.refData.carriedItems = self:getCarriedItems()
    if not self.refData.carriedItems[id] then
        self.refData.carriedItems[id] = {
            name = name,
            id = id,
            count = count,
        }
    else
        self.refData.carriedItems[id].count = self.refData.carriedItems[id].count + count
    end
end

function Animal:removeItemsFromMouth()
    local node = self.reference.sceneNode:getObjectByName("ATTACH_MOUTH")
    for _, item in pairs(self:getCarriedItems()) do
        local pickedItem = node:getObjectByName("Picked_Up_Item")
        while pickedItem do
            node:detachChild(node:getObjectByName("Picked_Up_Item"))
            pickedItem = node:getObjectByName("Picked_Up_Item")
        end
        --For ball, equip if unarmed
        if common.balls[item.id:lower()] then
            if tes3.player.mobile.readiedWeapon == nil then
                timer.delayOneFrame(function()
                    if not self:isValid() then return end
                    logger:debug("Re-equipping ball")
                    tes3.player.mobile:equip{ item = item }
                    tes3.player.mobile.weaponReady = true
                end)
            end
        end
    end
end

---Gets an accurate bounding box by cloning and removing lights
--- and collision before calling :createBoundingBox()
---@param node niNode
local function generateBoundingBox(node)

     -- prepare bounding box
    --Light particles mess with bounding box calculation
    local cloneForBB = node:clone()
    Lantern.removeLight(cloneForBB)
    --remove collision
    for node in table.traverse{cloneForBB} do
        if node:isInstanceOfType(tes3.niType.RootCollisionNode) then
            node.appCulled = true
        end
    end
    cloneForBB:update()
    return cloneForBB:createBoundingBox()
end

---@param object tes3object|tes3misc
---@param node? niNode
function Animal:putItemInMouth(object, node)
    logger:info("Putting %s in %s's hunger", object.name, self:getName())
    --Get item node and clear transforms
    local itemNode = (node or tes3.loadMesh(object.mesh)):clone()
    itemNode:clearTransforms()
    itemNode.scale = itemNode.scale * ( 1 / self.reference.scale)
    itemNode.name = "Picked_Up_Item"
    itemNode:update()

    local bb
    if itemNode:getObjectByName("Bounding Box") then
        bb = object.boundingBox
    else
        bb = generateBoundingBox(itemNode)
    end

    local attachNode = self.reference.sceneNode:getObjectByName("ATTACH_MOUTH")
    attachNode:attachChild(itemNode, true)
    do --determine rotation
        --rotation
        local x = bb.max.x - bb.min.x
        local y = bb.max.y - bb.min.y
        local z = bb.max.z - bb.min.z
        logger:debug("X: %s, Y: %s, Z: %s", x, y, z)
        local rotation
        ---@type string
        local longestAxis = (
            x > y and x > z and "x" or
            y > x and y > z and "y" or
            z > x and z > y and "z"
        )

        --[[
            The Y axis goes from the left side to the right side of the hunger
            The X axis goes from front to the back of the hunger

            We want to rotate the item so that the longest side is along the Y axis
        ]]
        if longestAxis == "x" then
            logger:debug("X is longest, rotate z = 90")
            rotation = { z = math.rad(90) }
        elseif longestAxis == "y" then
            logger:debug("Y is longest, no rotation")
        elseif longestAxis == "z" then
            logger:debug("Z is longest, rotate x = 90")
            rotation = { x = math.rad(90) }
        end
        if rotation then
            logger:debug("Rotating hunger item")
            local zRot90 = tes3matrix33.new()
            zRot90:fromEulerXYZ(rotation.x or 0, rotation.y or 0, rotation.z or 0)
            itemNode.rotation = itemNode.rotation * zRot90
        end

        --Position at center of bounding box along longest axis
        local yCenter = (bb.max[longestAxis] - bb.min[longestAxis]) / 2
        local yOffset = bb.min[longestAxis] + yCenter

        --Raise Z by min bb of new up
        --The original axis that is now pointing UP
        local newUpAxis = (
            longestAxis == "x" and "z" or
            longestAxis == "y" and "z" or
            longestAxis == "z" and "y"
        )
        local zOffset = bb.min[newUpAxis]
        ---For very thin items (paper etc), raise them up a bit
        local zHeight = bb.max[newUpAxis] - bb.min[newUpAxis]
        if zHeight < 1 then
            logger:debug("zHeight < 1, raising zOffset")
            zOffset = zOffset -2
        end

        local offset = tes3vector3.new(
            0,
            yOffset,
            zOffset
        )
        logger:debug("Current Y: %s, yOffset: %s", itemNode.translation.y, yOffset)
        itemNode.translation = itemNode.translation - offset
    end
    itemNode.appCulled = false
end

function Animal:pickUpItem(reference)
    local itemData = reference.itemData
    local itemCount = reference.itemData and reference.itemData.count or 1

    if itemCount > 1 then
        tes3.addItem{
            reference = self.reference,
            item = reference.object,
            updateGUI = true,
            count = itemCount
        }
    else
        local isBoots = (
            reference.object.objectType == tes3.objectType.armor and
            reference.object.slot == tes3.armorSlot.boots
        )
        tes3.addItem{
            reference = self.reference,
            item = reference.object,
            updateGUI = true,
            itemData = itemData,
            count =  1
        }
        if isBoots then
            if not itemData then
                itemData = tes3.addItemData{
                    to = self.reference,
                    item = reference.object,
                    updateGUI = false
                }
            end
            logger:debug("Ruining boots")
            itemData.condition = 0
        end
    end
    reference.itemData = nil
    reference:delete()
    tes3.playSound({reference=self.reference , sound="Item Misc Up"})
    self:addToCarriedItems(reference.object.name, reference.object.id, itemCount)
    self:putItemInMouth(reference.object, reference.sceneNode)

    if not tes3.hasOwnershipAccess{target=reference} then
        tes3.triggerCrime{type=tes3.crimeType.theft, victim=tes3.getOwner(reference), value=reference.object.value * itemCount}
    end
end



function Animal:eatFromWorld(target)
    if target.object.objectType == tes3.objectType.container then

        self:harvestItem(target)
        if not self:hasCarriedItems() then
            tes3.messageBox("%s wasn't unable to get any nutrition from the %s", self:getName(), target.object.name)
            return
        end
        for _, item in pairs(self:getCarriedItems()) do
            tes3.removeItem{
                reference = self.reference,
                item = item.id,
                count = item.count,
                playSound = false
            }
            local foodAmount = self.animalType.foodList[string.lower(item.id)]
            self.hunger:processFood(foodAmount)
        end
        tes3.playSound{ reference = self.reference, sound = "Item Ingredient Up" }
        tes3.messageBox("%s eats the %s", self:getName(), target.object.name)
    elseif target.object.objectType == tes3.objectType.ingredient then

        self:pickUpItem(target)
        local foodAmount = self.animalType.foodList[string.lower(target.object.id)]
        self.hunger:processFood(foodAmount)
        tes3.removeItem{
            reference = self.reference,
            item = target.object,
            playSound = false
        }
        tes3.messageBox("%s eats the %s", self:getName(), target.object.name)
    end

    local itemId = target.baseObject.id
    timer.start{
        type = timer.simulate,
        duration = 1,
        callback = function()
            if not self:isValid() then return end
            event.trigger("GuarWhisperer:AteFood", { reference = self.reference, itemId = itemId } )
            self:removeItemsFromMouth()
            self.refData.carriedItems = nil
        end
    }
end




function Animal:harvestItem(target)
    local items = harvest.harvest(self.reference, target)
    if not items then return end
    for _, item in ipairs(items) do
        local object = tes3.getObject(item.id)
        self:addToCarriedItems(item.name, item.id, item.count)
        self:putItemInMouth(object)

        if not tes3.hasOwnershipAccess{target=target} then
            tes3.triggerCrime{type=tes3.crimeType.theft, victim=tes3.getOwner(item), value = object.value * item.count }
        end
    end
end



function Animal:handOverItems()
    local carriedItems = self:getCarriedItems()
    for _, item in pairs(carriedItems) do
        local count = item.count
        tes3.transferItem{
            from = self.reference,
            to = tes3.player,
            item = item.id,
            itemData = item.itemData,
            count = count,
            playSound=false,
        }
        --For ball, equip if unarmed
        if common.balls[item.id:lower()] then
            if tes3.player.mobile.readiedWeapon == nil then
                timer.delayOneFrame(function()
                    if not self:isValid() then return end
                    logger:debug("Re-equipping ball")
                    tes3.player.mobile:equip{ item = item.id }
                    tes3.player.mobile.weaponReady = true
                end)
            end
        end
    end

    tes3.playSound{reference=self.reference, sound="Item Ingredient Up", pitch=1.0}

    if #carriedItems == 1 then
        tes3.messageBox("%s brings you %s x%d.", self:getName(), carriedItems[1].name, carriedItems[1].count)
    else
        local message = string.format("%s brings you the following:\n", self:getName())
        for _, item in pairs(carriedItems) do
            message = message .. string.format("%s x%d,\n", item.name, item.count)
        end
        message = string.sub(message, 1, -3)
        tes3.messageBox(message)
    end

    self:removeItemsFromMouth()
    self.refData.carriedItems = nil

    --make happier
    self.needs:modPlay(self.animalType.play.fetchValue)
    timer.delayOneFrame(function()
        if not self:isValid() then return end
        self:playAnimation("happy")
    end)
end

function Animal:getCharmModifier()
    local personality = self.stats:getAttribute("personality").current
    return math.log10(personality) * 20
end

function Animal:charm(ref)
    if tes3.persuade{ actor = ref, self:getCharmModifier() } then
        tes3.messageBox("%s successfully charmed %s.", self:getName(), ref.object.name)
    else
        tes3.messageBox("%s failed to charm %s.", self:getName(), ref.object.name)
    end
end



function Animal:isActive()
    return (
        self.reference and
        self.reference.mobile and
        table.find(tes3.getActiveCells(), self.reference.cell) and
        not self:isDead() and
        self:distanceFrom(tes3.player) < 5000
    )
end

---@param reference tes3reference
function Animal:distanceFrom(reference)
    return self.reference.position:distance(reference.position)
end

function Animal:getIsStuck()
    local strikesNeeded = 5

    local maxDistance = 10
    -- if self.reference.mobile.isRunning then
    --     maxDistance = 10
    -- end

    self.refData.stuckStrikes = self.refData.stuckStrikes or 0
    --self.refData.stuckStrikes: we check x times before deciding he's stuck
    if self.refData.stuckStrikes < strikesNeeded then
        --Check if he's trying to move forward
        if self.reference.mobile.isMovingForward then
            --Get the distance from last position and check if it's too small
            if self.refData.lastStuckPosition then
                local lastStuckPosition = tes3vector3.new(
                    self.refData.lastStuckPosition.x,
                    self.refData.lastStuckPosition.y,
                    self.refData.lastStuckPosition.z
                )
                local distance = self.reference.position:distance(lastStuckPosition)
                if distance < maxDistance then
                    self.refData.stuckStrikes = self.refData.stuckStrikes + 1
                else
                    self.refData.stuckStrikes = 0
                end
            end
        end
    end
    local position = self.reference.position
    self.refData.lastStuckPosition = { x = position.x, y = position.y, z = position.z}

    if self.refData.stuckStrikes >= strikesNeeded then
        self.refData.stuckStrikes = 0
        logger:debug("Guar is stuck")
        return true
    else
        return false
    end
end

function Animal:updateCloseDistance()
    if self:getAI() == "following" and tes3.player.cell.isInterior ~= true then
        local distance = self:distanceFrom(tes3.player)
        local teleportDist = common.config.mcm.teleportDistance
        --teleport if too far away

        if distance > teleportDist and not self.reference.mobile.inCombat then
            --dont' teleport if fetching (unless stuck)
            if not self:hasCarriedItems() then
                self:closeTheDistanceTeleport()
            end
        end
        --teleport if stuck and kinda far away
        local isStuck = self:getIsStuck()
        if isStuck and (distance > teleportDist / 2) then
            logger:debug("%s Stuck while following: teleport", self:getName())
            self:closeTheDistanceTeleport()
        end
    end
end

--keep ai in sync
function Animal:updateAI()
    local aiState = self:getAI()
    local packageId = tes3.getCurrentAIPackageId{ reference = self.reference }

    local brokenLimit = 2
    self.refData.aiBroken = self.refData.aiBroken or 0

    local exceededBrokenLimit = self.refData.aiBroken > brokenLimit
    local hasSceneNode = self.reference.sceneNode ~= nil
    local invalidPackageId = packageId == nil or packageId == -1
    if (not exceededBrokenLimit) and hasSceneNode and invalidPackageId then
        logger:debug("AI Fix: Detected broken AI package")
        self.refData.aiBroken = self.refData.aiBroken + 1
    end

    if exceededBrokenLimit then
        logger:warn("AI Fix: still broken, using mwse.memory fix")
        --Magic mwse.memory call to fix guars wandering off
        ---@diagnostic disable: undefined-field
        mwse.memory.writeByte({
            address = mwse.memory.convertFrom.tes3mobileObject(self.reference.mobile) + 0xC0,
            byte = 0x00,
        })
        self.refData.aiBroken = 0
    end

    --set correct ai package
    if aiState == "following" then
        if packageId ~= tes3.aiPackage.follow then
            logger:debug("Current AI package: %s", table.find(tes3.aiPackage, packageId) or packageId)
            logger:debug("%s Restoring following AI", self:getName())
            self:returnTo()
        end
    elseif aiState == "waiting" or aiState == "wandering" then
        if packageId ~= tes3.aiPackage.wander then
            logger:debug("Current AI package: %s", table.find(tes3.aiPackage, packageId) or packageId)
            logger:debug("%s Restoring %s AI", self:getName(), aiState)
            self:setAI(aiState)
        end
    elseif aiState == "attacking" then
        if self.reference.mobile.inCombat ~= true then
            logger:debug("Current AI package: %s", table.find(tes3.aiPackage, packageId) or packageId)
            logger:debug("restoring previous AI after combat")
            self:restorePreviousAI()
        end
    elseif aiState == "moving" then
        if self.reference.mobile.actionData.aiBehaviorState == 255 then
            logger:debug("Current AI package: %s", table.find(tes3.aiPackage, packageId) or packageId)
            logger:debug("Setting to wait after moving")
            self:wait()
        end
    --Check if stuck on something while wandering
    elseif aiState == "wandering" then
        local isStuck = self:getIsStuck()
        if isStuck then
            logger:debug("Stuck, resetting wander")
            self:wait()
            --set back to wandering in case of save/load
            self.refData.aiState = "wandering"
            timer.start{
                duration = 0.5,
                callback = function()
                    if not self:isValid() then return end
                    if self.refData.aiState == "wandering" then
                        logger:debug("Still need to wander, setting now")
                        self:wander()
                    end
                end
            }
        end
    else
        logger:warn("No AI state detected")
        self:wait()
    end

    --[[
        We don't want to edit the hostileActors list while
        we are iterating it, so we store the hotiles in a local
        table then stopCombat afterwards
    ]]
    local hostileStopList = {}
    ---@param hostile tes3mobileActor
    for hostile in tes3.iterate(self.reference.mobile.hostileActors) do
        if hostile.health.current <= 1 then
            logger:debug("%s is dead, stopping combat", hostile.reference.object.name)
            table.insert(hostileStopList, hostile)
        end
    end

    for _, hostile in ipairs(hostileStopList) do
        self.reference.mobile:stopCombat(hostile)
    end

    --Make sure the lanterns are working properly
    self.reference.sceneNode:update()
    self.reference.sceneNode:updateEffects()
end



function Animal:updateTravelSpells()
    local effects = {
        [tes3.effect.levitate] = "mer_tgw_lev",
        [tes3.effect.waterWalking] = "mer_tgw_ww",
        --[tes3.effect.invisibility] = "mer_tgw_invs"
    }

    if not self:isActive() then return end
    for effect, spell in pairs(effects) do
        if tes3.isAffectedBy{ reference = tes3.player, effect = effect } then
            --not affected but player is
            if not tes3.isAffectedBy{ reference = self.reference, effect = effect } then
                if self:getAI() == "following" then
                    logger:debug("Adding spell to %s", self:getName())
                    self.object.spells:remove(spell)
                    tes3.addSpell{reference = self.reference, spell = spell }
                end
            end

        else
            --effected but player isn't
            if tes3.isAffectedBy{ reference = self.reference, effect = effect } then
                logger:debug("Removing spell from %s", self:getName())
                tes3.removeSpell{reference = self.reference, spell = spell }
            end
        end
        --affected no longer following
        if tes3.isAffectedBy{ reference = self.reference, effect = effect } then
            if self:getAI() ~= "following" then
                logger:debug("Removing spell from %s", self:getName())
                tes3.removeSpell{reference = self.reference, spell = spell }
            end
        end
    end
end

-----------------------------------------
-- UI stuff
------------------------------------------

function Animal:getMenuTitle()
    local name = self:getName() or "This"
    return string.format(
        "%s is a %s%s %s. %s %s.",
        name, self.genetics:isBaby() and "baby " or "", self.genetics:getGender(), self.animalType.type,
        self.syntax:getHeShe(), self.needs:getHappinessStatus().description
    )
end

function Animal:getStatusMenu()
    ui.showStatusMenu(self)
end

----------------------------------------
--Commands
----------------------------------------


function Animal:takeAction(time)
    self.reference.tempData.tgw_takingAction = true
    timer.start{
        duration = time,
        callback = function()
            if not self:isValid() then return end
            self.reference.tempData.tgw_takingAction = false
        end
    }
end

function Animal:canTakeAction()
    return not self.reference.tempData.tgw_takingAction
end


function Animal:pet()
    logger:debug("Petting")
    self.needs:modAffection(self.animalType.affection.petValue)
    tes3.messageBox(self.needs:getAffectionStatus().pettingResult(self) )
    self:playAnimation("pet")
    self:takeAction(2)
    if not self.needs:hasSkillReqs("follow") then
        self.needs:modTrust(2)
    end
end

function Animal:getRefusalMessage()
    local messages = {
        "<name> doesn't want to do that.",
        "<name> refuses to listen to you.",
        "Your command falls on deaf ears.",
        "<name> ignores you.",
    }
    local message = table.choice(messages)
    message = string.gsub(message, "<name>", self:getName())
    return message
end

--- Attempt a command. If this fails, a random message
--- will display and the animal will wander instead
---@param min number The minimum value the required happiness will be randomly chosen from
---@param max number the maximum value the required happiness will be randomly chosen from
---@return boolean whether the command was successful. If false, the animal will wander
function Animal:attemptCommand(min, max)
    local happinessRequired = math.random(min, max)
    if self.needs:getHappiness() < happinessRequired then
        tes3.messageBox(self:getRefusalMessage())
        self:wander()
        return false
    end
    return true
end



function Animal:rename()
    local label = self.genetics:isBaby() and string.format("Name your new baby %s %s", self.genetics:getGender(), self.animalType.type) or
        string.format("Enter the new name of your %s %s:",self.genetics:getGender(), self.animalType.type)
    local renameMenuId = tes3ui.registerID("TheGuarWhisperer_Rename")

    local t = {
        name = self:getName()
    }

    local function nameChosen()
        local newName = Syntax.capitaliseFirst(t.name)
        self:setName(newName)
        tes3ui.leaveMenuMode()
        tes3ui.findMenu(renameMenuId):destroy()
        tes3.messageBox("%s has been renamed to %s", Syntax.capitaliseFirst(self.animalType.type), self:getName())
        self:playAnimation("happy")
    end

    local menu = tes3ui.createMenu{ id = renameMenuId, fixedFrame = true }
    menu.minWidth = 400
    menu.absolutePosAlignX = 0.5
    menu.absolutePosAlignY = 0.5
    menu.autoHeight = true
    mwse.mcm.createTextField(
        menu,
        {
            label = label,
            variable = mwse.mcm.createTableVariable{
                id = "name",
                table = t
            },
            callback = nameChosen
        }
    )
    tes3ui.enterMenuMode(renameMenuId)
end



function Animal:activate()
    if not self:isActive() then
        logger:trace("not active")
        return
    end
    if self:isDead() then
        logger:trace("guar is dead")
        return
    end
    if not self.reference.mobile.hasFreeAction then
        logger:trace("no free action")
        return
    end
    --Allow regular activation for dialog/companion share
    if self.refData.triggerDialog == true then
        logger:debug("triggerDialog true, entering companion share")
        self.refData.triggerDialog = nil
        return
    --Block activation if issuing a command
    elseif common.data.skipActivate then
        logger:trace("skipActivate")
        common.data.skipActivate = false
        return false
    --Otherwise trigger custom activation
    else
        if self:hasCarriedItems() then
            self.refData.commandActive = false
            self:handOverItems()
            self:restorePreviousAI()
        elseif self.refData.commandActive then
            logger:trace("command is active")
            self.refData.commandActive = false
        else
            if self:canTakeAction() then
                logger:trace("showing command menu")
                event.trigger("TheGuarWhisperer:showCommandMenu", { animal = self })
            else
                logger:trace("can't take action")
            end
        end
        return false
    end
end

return Animal