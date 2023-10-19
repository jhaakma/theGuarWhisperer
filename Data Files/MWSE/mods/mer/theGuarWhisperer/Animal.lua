---@alias GuarWhisperer.Emotion
---| '"happy"'
---| '"sad"'
---| '"pet"'
---| '"eat"'

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

---@alias GuarWhisperer.Gender
---|'"male"' Male
---|'"female"' Female
---|'"none"' No gender

---@class GuarWhisperer.Animal.Home
---@field position number[]
---@field cell string

---@class GuarWhisperer.Animal.RefData
---@field name string
---@field gender GuarWhisperer.Gender
---@field trust number
---@field affection number
---@field play number
---@field happiness number
---@field hunger number
---@field level number
---@field attackPolicy GuarWhisperer.Animal.AttackPolicy
---@field potionPolicy GuarWhisperer.Animal.PotionPolicy
---@field followingRef tes3reference|"player"
---@field aiState GuarWhisperer.Animal.AIState
---@field previousAiState GuarWhisperer.Animal.AIState
---@field home GuarWhisperer.Animal.Home
---@field hasPack boolean has a backpack equipped
---@field isBaby boolean is a baby
---@field birthTime number
---@field lanternOn boolean Lantern is turned on
---@field dead boolean is dead
---@field carriedItems table<string, {name:string, id:string, count:number, itemData:tes3itemData}>
---@field lastUpdated number
---@field stuckStrikes number
---@field lastStuckPosition {x:number, y:number, z:number}
---@field aiBroken number
---@field attributes table<string, number>
---@field lastBirthed number last time it gave birth
---@field commandActive boolean is currently doing a command
---@field triggerDialog boolean trigger dialog on next activate
---@field ignoreLantern boolean

---@class GuarWhisperer.Animal
---@field refData GuarWhisperer.Animal.RefData
---@field reference tes3reference
---@field mobile tes3mobileCreature
---@field object tes3object
---@field animalType GuarWhisperer.AnimalType
---@field attributes table<string, number>
---@field stats GuarWhisperer.Stats
---@field aiFixer GuarWhisperer.AIFixer
---@field pack GuarWhisperer.Pack
---@field syntax GuarWhisperer.Syntax
local Animal = {}

local animalConfig = require("mer.theGuarWhisperer.animalConfig")
local harvest = require("mer.theGuarWhisperer.harvest")
local moodConfig = require("mer.theGuarWhisperer.moodConfig")
local common = require("mer.theGuarWhisperer.common")
local logger = common.log
local ui = require("mer.theGuarWhisperer.ui")
local ashfallInterop = include("mer.ashfall.interop")
local AIFixer = require("mer.theGuarWhisperer.services.AIFixer")
local Syntax = require("mer.theGuarWhisperer.services.Syntax")
local Pack = require("mer.theGuarWhisperer.services.Pack")
local Stats = require("mer.theGuarWhisperer.services.Stats")

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
---@param reference tes3reference
---@return GuarWhisperer.Animal.RefData
local function initialiseRefData(reference)
    if reference.data.tgw then return reference.data.tgw end
    math.randomseed(os.time())
    reference.data.tgw = {
        name = "Tamed Guar",
        gender = math.random() < 0.55 and "male" or "female",
        birthTime = common.getHoursPassed(),
        trust = moodConfig.defaultTrust,
        affection = moodConfig.defaultAffection,
        play = moodConfig.defaultPlay,
        happiness = 0,
        hunger = 50,
        level = 1.0,
        attackPolicy = "defend",
    }
    return reference.data.tgw
end

local function isValidRef(reference)
    if not reference then
        logger:debug("No reference")
        return false
    end
    local refObj = reference.baseObject or reference.object
    if not refObj then
        logger:debug("ref doesn't have an object")
        return false
    end
    local isAGuar = (
        (refObj.id == animalConfig.guarMapper.standard) or
        (refObj.id == animalConfig.guarMapper.white)
    )
    if not isAGuar then
        logger:trace("Not a guar")
        return false
    end
    return true
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
    return Animal:new(reference)
end

---Get the animal type and extra data for a given vanilla
--- guar reference.
---@return GuarWhisperer.ConvertData?
function Animal.getConvertData(reference)
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

--- Get the animal type for a converter guar
---@param reference tes3reference
---@return GuarWhisperer.AnimalType?
function Animal.getAnimalType(reference)
    return animalConfig.animals.guar
end


--- Construct a new Animal
---@param reference tes3reference
---@return GuarWhisperer.Animal|nil
function Animal:new(reference)
    logger:trace("Animal:new")
    if not isValidRef(reference) then
        logger:trace("Not valid")
        return
    end
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
        refData = initialiseRefData(reference),
    }
    newAnimal.stats = Stats.new(newAnimal)
    newAnimal.aiFixer = AIFixer.new(newAnimal)
    newAnimal.pack = Pack.new(newAnimal)
    newAnimal.syntax = Syntax.new(newAnimal.refData.gender)

    setmetatable(newAnimal, self)
    self.__index = self
    event.trigger("GuarWhisperer:registerReference", { reference = reference })
    return newAnimal
end


--- Get the animals' name
---@return string
function Animal:getName()
    return self.refData.name
end

function Animal:setName(newName)
    self.refData.name = newName
end

---@return "male"|"female"
function Animal:getGender()
    return self.refData.gender
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

--- Set the potion policy
---@param policy GuarWhisperer.Animal.PotionPolicy
function Animal:setPotionPolicy(policy)
    self.refData.potionPolicy = policy
end

--- Get the potion policy
---@return GuarWhisperer.Animal.PotionPolicy
function Animal:getPotionPolicy()
    return self.refData.potionPolicy
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
    if self.reference.mobile.inCombat then
        return
    elseif tes3.player.cell.isInterior then
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
    local target = tes3.player
    --do a raytest to avoid teleporting into stuff
    local oldCulledValue = target.sceneNode.appCulled
    target.sceneNode.appCulled = true
    ---@type niPickRecord
    local rayResult = tes3.rayTest{
        position = target.position,
        direction = target.orientation * (isForward and -1 or 1),
        maxDistance = math.abs(distance),
        ignore = {target, self.reference}
    }
    target.sceneNode.appCulled = oldCulledValue

    if rayResult and rayResult.distance then
        distance = math.min(distance, rayResult.distance)
    end

    local newPosition = tes3vector3.new(
        target.position.x + ( distance * math.sin(target.orientation.z)),
        target.position.y + ( distance * math.cos(target.orientation.z)),
        target.position.z
    )

    --Drop to ground
    if not tes3.isAffectedBy{ reference = self.reference, effect = tes3.effect.levitate } then
        local upDownResult = tes3.rayTest{
            position = newPosition,
            direction = tes3vector3.new(0, 0, -1),
            maxDistance = 5000,
            ignore = {target, self.reference}
        }
        --no down result, try up result
        if not (upDownResult and upDownResult.intersection) then
            upDownResult = tes3.rayTest{
                position = newPosition,
                direction = tes3vector3.new(0, 0, 1),
                maxDistance = 5000,
                ignore = {target, self.reference},
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
        cell = target.cell
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
function Animal:follow()
    --timer.delayOneFrame(function()
        logger:debug("Setting AI Follow")
        self.refData.aiState = "following"
        tes3.setAIFollow{ reference = self.reference, target = tes3.player }
    --end)
end

--- Attack the target
function Animal:attack(target, blockMessage)
    logger:debug("Attacking %s", target.object.name)

    if blockMessage ~= true then
        tes3.messageBox("%s attacking %s", self:getName(), target.object.name)
    end
    self.refData.previousAiState = self:getAI()
    self:follow()
    local ref = self.reference
    local safeTargetRef = tes3.makeSafeObjectHandle(target)
    local safeRef = tes3.makeSafeObjectHandle(ref)
    timer.start{
        duration = 0.5,
        callback = function()
            if not (safeTargetRef and safeTargetRef:valid()) then return end
            if not (safeRef and safeRef:valid()) then return end
            if not target.mobile then return end
            ref.mobile:startCombat(target.mobile)
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
                    self.reference.mobile.isRunning = false
                    if command == "eat" then
                        self:playAnimation("eat")
                    elseif command == "greet" then
                        self:modPlay(self.animalType.play.greetValue)
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
    self.reference.mobile.isRunning = true
    timer.delayOneFrame(function()timer.delayOneFrame(function()
        tes3.setAITravel{ reference = self.reference, destination = position }
        self.refData.aiState = "moving"
    end)end)
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
                self:wander()
            end)
        end
        common.fadeTimeOut(hoursPassed, secondsTaken, function()
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
        self:hasSkillReqs("follow")
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

function Animal:hasSkillReqs(skill)
    return self.refData.trust > moodConfig.skillRequirements[skill]
end

function Animal:addToCarriedItems(name, id, count)
    self.refData.carriedItems = self.refData.carriedItems or {}
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

    for _, item in pairs(self.refData.carriedItems) do
        --detach once per item held
        node:detachChild(node:getObjectByName("Picked_Up_Item"))
        --For ball, equip if unarmed
        if item.name == common.ballId then
            if tes3.player.mobile.readiedWeapon == nil then
                timer.delayOneFrame(function()
                    logger:debug("Re-equipping ball")
                    tes3.player.mobile:equip{ item = item }
                    tes3.player.mobile.weaponReady = true
                end)
            end
        end
    end
end


function Animal:putItemInMouth(object)
    --attach nif
    -- local objNode = tes3.loadMesh(object.mesh):clone()
    -- local itemNode = niNode.new()
    -- itemNode:attachChild(objNode)
    local itemNode = tes3.loadMesh(object.mesh):clone()


    itemNode:clearTransforms()
    itemNode.name = "Picked_Up_Item"
    local node = self.reference.sceneNode:getObjectByName("ATTACH_MOUTH")


    --determine rotation
    --Due to orientation of ponytail bone, item is already rotated 90 degrees
    Animal.removeLight(itemNode)
    --remove collision
    for node in table.traverse{itemNode} do
        if node:isInstanceOfType(tes3.niType.RootCollisionNode) then
            node.appCulled = true
        end
    end
    itemNode:update()
    node:attachChild(itemNode, true)

    local bb = itemNode:createBoundingBox()

    -- --Center position to middle of bounding box
    -- do
    --     local offsetX = (bb.max.x + bb.min.x) / 2
    --     local offsetY = (bb.max.y + bb.min.y) / 2
    --     local offsetZ = (bb.max.z + bb.min.z) / 2
    --    -- itemNode.translation.x = itemNode.translation.x - offsetX
    --    -- itemNode.translation.y = itemNode.translation.y - offsetY
    --     itemNode.translation.z = itemNode.translation.z + offsetZ


    -- end

    do
        --rotation
        local x = bb.max.x - bb.min.x
        local y = bb.max.y - bb.min.y
        local z = bb.max.z - bb.min.z
        local rotation
        if x > y and x > z then --x is longest
            logger:debug("X is longest, rotate z = 90")
            rotation = { z = math.rad(90) }
        elseif y > x and y > z then --y is longest
            logger:debug("Y is longest, no rotation")
            --no rotation
        elseif z > x and z > y then --z is longest
            logger:debug("Z is longest, rotate x = 90")
            rotation = { x = math.rad(90) }
        end
        --local rotation = Animal.pickableRotations[object.objectType]
        if rotation then
            logger:debug("Rotating mouth item")
            local zRot90 = tes3matrix33.new()
            zRot90:fromEulerXYZ(rotation.x or 0, rotation.y or 0, rotation.z or 0)
            itemNode.rotation = itemNode.rotation * zRot90
        end
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
            logger:debug("Ruining boots")
            if not itemData then
                itemData = tes3.addItemData{
                    to = self.reference,
                    item = reference.object,
                    updateGUI = false
                }
                itemData.condition = 0
            end
        end
    end
    reference.itemData = nil
    reference:delete()
    tes3.playSound({reference=self.reference , sound="Item Misc Up"})
    self:addToCarriedItems(reference.object.name, reference.object.id, itemCount)
    self:putItemInMouth(reference.object)

    if not tes3.hasOwnershipAccess{target=reference} then
        tes3.triggerCrime{type=tes3.crimeType.theft, victim=tes3.getOwner(reference), value=reference.object.value * itemCount}
    end

end


function Animal:processFood(amount)
    self:modHunger(amount)

    --Eating restores health as a % of base health
    local healthCurrent = self.mobile.health.current
    local healthMax = self.mobile.health.base
    local difference = healthMax - healthCurrent
    local healthFromFood = math.remap(
        amount,
        0, 100,
        0, healthMax
    )
    healthFromFood = math.min(difference, healthFromFood)
    tes3.modStatistic{
        reference = self.reference,
        name = "health",
        current = healthFromFood
    }

    if self.refData.trust < moodConfig.skillRequirements.follow then
        self:modTrust(3)
    end
end

function Animal:eatFromWorld(target)
    if target.object.objectType == tes3.objectType.container then

        self:harvestItem(target)
        if not self.refData.carriedItems then
            tes3.messageBox("%s wasn't unable to get any nutrition from the %s", self:getName(), target.object.name)
            return
        end
        for _, item in pairs(self.refData.carriedItems) do
            tes3.removeItem{
                reference = self.reference,
                item = item.id,
                count = item.count,
                playSound = false
            }
            local foodAmount = self.animalType.foodList[string.lower(item.id)]
            self:processFood(foodAmount)
        end


        tes3.playSound{ reference = self.reference, sound = "Item Ingredient Up" }
        tes3.messageBox("%s eats the %s", self:getName(), target.object.name)
    elseif target.object.objectType == tes3.objectType.ingredient then

        self:pickUpItem(target)
        local foodAmount = self.animalType.foodList[string.lower(target.object.id)]
        self:processFood(foodAmount)
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
            event.trigger("GuarWhisperer:AteFood", { reference = self.reference, itemId = itemId } )
            self:removeItemsFromMouth()
            self.refData.carriedItems = nil
        end
    }
end


function Animal:eatFromInventory(item, itemData)
    event.trigger("GuarWhisperer:EatFromInventory", { item = item, itemData = itemData })
    --remove food from player
    tes3.player.object.inventory:removeItem{
        mobile = tes3.mobilePlayer,
        item = item,
        itemData = itemData or nil
    }
    tes3ui.forcePlayerInventoryUpdate()

    self:processFood(self.animalType.foodList[string.lower(item.id)])

    --visuals/sound
    self:playAnimation("eat")
    self:takeAction(2)
    local itemId = item.id
    timer.start{
        duration = 1,
        callback = function()
            event.trigger("GuarWhisperer:AteFood", { reference = self.reference, itemId = itemId }  )
            tes3.playSound{ reference = self.reference, sound = "Swallow" }
            tes3.messageBox(
                "%s gobbles up the %s.",
                self:getName(), string.lower(item.name)
            )
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
    local carriedItems = self.refData.carriedItems
    if not carriedItems then return end


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
        if string.lower(item.id) == common.ballId then
            if tes3.player.mobile.readiedWeapon == nil then
                timer.delayOneFrame(function()
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
    self:modPlay(self.animalType.play.fetchValue)
    timer.delayOneFrame(function()
        self:playAnimation("happy")
    end)
end

function Animal:getCharmModifier()
    local personality = self.reference.mobile.attributes[tes3.attribute.personality + 1].current
    return math.log10(personality) * 20
end

function Animal:charm(ref)
    if tes3.persuade{ actor = ref, self:getCharmModifier() } then
        tes3.messageBox("%s successfully charmed %s.", self:getName(), ref.object.name)
    else
        tes3.messageBox("%s failed to charm %s.", self:getName(), ref.object.name)
    end
end





-----------------------------------------
--Mood mechanics
-----------------------------------------


function Animal:modTrust(amount)
    local previousTrust = self.refData.trust
    self.refData.trust = math.clamp(self.refData.trust + amount, 0, 100)
    self.reference.mobile.fight = 50 - (self.refData.trust / 2 )


    local afterTrust = self.refData.trust
    for _, trustData in ipairs(moodConfig.trust) do
        if previousTrust < trustData.minValue and afterTrust > trustData.minValue then
            local message = string.format("%s %s. ",
                self:getName(), trustData.description)
            if trustData.skillDescription then
                message = message .. string.format("%s %s",
                    self.syntax:getHeShe(), trustData.skillDescription)
            end
            timer.delayOneFrame(function()
                tes3.messageBox{ message = message, buttons = {"Okay"} }
            end)
        end
    end
    tes3ui.refreshTooltip()
    return self.refData.trust
end

function Animal:modPlay(amount)
    self.refData.play = math.clamp(self.refData.play + amount, 0, 100)
    tes3ui.refreshTooltip()
    return self.refData.play
end

function Animal:modAffection(amount)
    --As he gains affection, his fight level decreases
    if amount > 0 then
        self.mobile.fight = self.mobile.fight - math.min(amount, 100 - self.refData.affection)
    end
    self.refData.affection = math.clamp(self.refData.affection + amount, 0, 100)
    return self.refData.affection
end

function Animal:modHunger(amount)
    local previousMood = self:getMood("hunger")
    self.refData.hunger = math.clamp(self.refData.hunger + amount, 0, 100)
    local newMood = self:getMood("hunger")
    if newMood ~= previousMood then
        tes3.messageBox("%s is %s.", self:getName(), newMood.description)
    end

    tes3ui.refreshTooltip()
end

function Animal:getMood(moodType)
    for _, mood in ipairs(moodConfig[moodType]) do
        if self.refData[moodType] <= mood.maxValue then
            return mood
        end
    end
end

function Animal:updatePlay(timeSinceUpdate)
    local changeAmount = self.animalType.play.changePerHour * timeSinceUpdate
    self:modPlay(changeAmount)
end

function Animal:updateAffection(timeSinceUpdate)
    local changeAmount = self.animalType.affection.changePerHour * timeSinceUpdate
    self:modAffection(changeAmount)
end

function Animal:updateHunger(timeSinceUpdate)
    local changeAmount = self.animalType.hunger.changePerHour * timeSinceUpdate
    self:modHunger(changeAmount)
end

function Animal:updateTrust(timeSinceUpdate)
    --No trust from sleeping/waiting because that's lame
    if tes3ui.menuMode() or tes3.player.mobile.restHoursRemaining > 0 then return end
    --Trust changes if nearby
    local happinessMulti = math.remap(self.refData.happiness, 0, 100, -1.0, 1.0)
    local trustChangeAmount = (
        self.animalType.trust.changePerHour *
        happinessMulti *
        timeSinceUpdate
    )
    self:modTrust(trustChangeAmount)
end


function Animal:updateHappiness()
    local healthRatio = self.reference.mobile.health.current / self.reference.mobile.health.base
    local hunger = math.remap(self.refData.hunger, 0, 100, 0, 15)
    local comfort = math.remap(healthRatio, 0, 1.0, 0, 25 )
    local affection = math.remap(self.refData.affection, 0, 100, 0, 25)
    local play = math.remap(self.refData.play, 0, 100, 0, 15)
    local trust = math.remap(self.refData.trust, 0, 100, 0, 15)
    self.reference.mobile.flee = 50 - (self.refData.happiness / 2)

    local newHappiness = hunger + comfort + affection + play + trust
    self.refData.happiness = newHappiness
    tes3ui.refreshTooltip()
end


function Animal:updateMood()

    --get the time since last updated
    local now = common.getHoursPassed()
    if not self:isActive() then
        --not active, reset time

        self.refData.lastUpdated = now
        return
    end
    local lastUpdated = self.refData.lastUpdated or now
    local timeSinceUpdate = now - lastUpdated

    self:updatePlay(timeSinceUpdate)
    self:updateAffection(timeSinceUpdate)
    self:updateHappiness()
    self:updateHunger(timeSinceUpdate)
    self:updateTrust(timeSinceUpdate)
    self.refData.lastUpdated = now
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
        return true
    else
        return false
    end
end

---@return boolean
function Animal:hasItems()
    return self.refData.carriedItems ~= nil
        and table.size(self.refData.carriedItems) > 0
end

function Animal:updateCloseDistance()
    if self:getAI() == "following" and tes3.player.cell.isInterior ~= true then
        local distance = self:distanceFrom(tes3.player)
        local teleportDist = common.getConfig().teleportDistance
        --teleport if too far away
        if distance > teleportDist then
            --dont' teleport if fetching (unless stuck)
            if not self:hasItems() then
                self:closeTheDistanceTeleport()
            end
        end
        --teleport if stuck and kinda far away
        local isStuck = self:getIsStuck()
        if isStuck then
            if distance > teleportDist / 2 then
                logger:debug("%s Stuck while following: teleport", self:getName())
                self:closeTheDistanceTeleport()
            end
        end
    end
end

--keep ai in sync
function Animal:updateAI()
    local aiState = self:getAI()
    local packageId = tes3.getCurrentAIPackageId{ reference = self.reference }

    local brokenLimit = 2
    self.refData.aiBroken = self.refData.aiBroken or 0

    if  self.refData.aiBroken <= brokenLimit and self.reference.sceneNode and packageId == "-1" then
        logger:debug("AI Fix: Detected broken AI package")
        self.refData.aiBroken = self.refData.aiBroken + 1
    end

    if self.refData.aiBroken and self.refData.aiBroken > brokenLimit then
        if packageId == tes3.aiPackage.follow then
            logger:debug("AI Fix: AI has been fixed")
            self:moveToAction(tes3.player, "greet", true)
            tes3.messageBox("%s looks like %s really missed you.", self:getName(), self.syntax:getHeShe(true))
            self.refData.aiBroken = nil
        else
            logger:debug("AI Fix: still broken, attempting to fix by starting combat")
            local mobile = self.reference.mobile

            --Magic mwse.memory call to fix guars wandering off
            ---@diagnostic disable: undefined-field
            mwse.memory.writeByte({

                address = mwse.memory.convertFrom.tes3mobileObject(mobile) + 0xC0,
                byte = 0x00,
            })
            timer.delayOneFrame(function()
                ---@diagnostic enable: undefined-field
                self:follow()
            end)
        end
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
    end
    --Check if stuck on something while wandering
    if aiState == "wandering" then
        local isStuck = self:getIsStuck()
        if isStuck then
            logger:debug("Stuck, resetting wander")
            self:wait()
            --set back to wandering in case of save/load
            self.refData.aiState = "wandering"
            timer.start{
                duration = 0.5,
                callback = function()
                    if self.refData.aiState == "wandering" then
                        logger:debug("Still need to wander, setting now")
                        self:wander()
                    end
                end
            }
        end
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
                    self.reference.object.spells:remove(spell)
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
        name, self.refData.isBaby and "baby " or "", self.refData.gender, self.animalType.type,
        self.syntax:getHeShe(), self:getMood("happiness").description
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
            self.reference.tempData.tgw_takingAction = false
        end
    }
end

function Animal:canTakeAction()
    return not self.reference.tempData.tgw_takingAction
end



function Animal:pet()
    logger:debug("Petting")
    self:modAffection(30)
    tes3.messageBox(self:getMood("affection").pettingResult(self) )
    self:playAnimation("pet")
    self:takeAction(2)
    if self.refData.trust < moodConfig.skillRequirements.follow then
        self:modTrust(2)
    end
end


function Animal:feed()
    timer.delayOneFrame(function()
        tes3ui.showInventorySelectMenu{
            reference = tes3.player,
            title = string.format("Feed %s", self:getName()),
            noResultsText = string.format("You do not have any appropriate food."),
            filter = function(e)
                logger:trace("Filter: checking: %s", e.item.id)

                for id, value in pairs(self.animalType.foodList) do
                    logger:trace("%s: %s", id, value)
                end
                return (
                    e.item.objectType == tes3.objectType.ingredient and
                    self.animalType.foodList[string.lower(e.item.id)] ~= nil
                )
            end,
            callback = function(e)
                if e.item then
                    self:eatFromInventory(e.item, e.itemData)
                end
            end
        }
    end)
end

function Animal:rename(isBaby)
    local label = isBaby and string.format("Name your new baby %s %s", self.refData.gender, self.animalType.type) or
        string.format("Enter the new name of your %s %s:",self.refData.gender, self.animalType.type)
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


-------------------------------------
-- Genetics Funcitons
--------------------------------------

function Animal:updateGrowth()
    local age = common.getHoursPassed() - self.refData.birthTime
    if self.refData.isBaby then
        if age > self.animalType.hoursToMature then
            --No longer a baby, turn into an adult
            self.refData.isBaby = false
            if not self:getName() then
                self:setName(self.reference.object.name)
            end
            self.reference.scale = 1
        else
            --map scale to age
            local newScale = math.remap(age, 0,  self.animalType.hoursToMature, self.animalType.babyScale, 1)
            self.reference.scale = newScale
        end
        self:scaleAttributes()
    end
end


--Scales attributes based on physical scale
--at 0.5 scale, attributes are half of adult ones etc
function Animal:scaleAttributes()
    if not self.refData.attributes then self:randomiseGenes() end
    local scale = self.reference.scale
    for attrName, attribute in pairs(tes3.attribute) do
        local newValue = self.refData.attributes[attribute + 1]
        --Speed is actually faster for babies
        if attrName ~= "speed" then
            newValue = newValue * scale
        else
            newValue = newValue * ( 1 / scale )
        end
        newValue = math.floor(newValue)
        tes3.setStatistic{
            reference = self.reference,
            name = attrName,
            value = newValue
        }
    end
    tes3.setStatistic{
        reference = self.reference,
        name = "health",
        base = 100 * scale
    }
    if self.reference.mobile.health.current > self.reference.mobile.health.base then
        tes3.setStatistic{
            reference = self.reference,
            name = "health",
            current = 100 * scale
        }
    end
end

--Averages the attributes of mom and dad and adds some random mutation
--Stores them on refData so they can be scaled down during adolescence
function Animal:inheritGenes(mom, dad)
    self.refData.attributes = {}
    for _, attribute in pairs(tes3.attribute) do
        --get base values of parents
        local momVal = mom.mobile.attributes[attribute + 1].base
        local dadVal = dad.mobile.attributes[attribute + 1].base
        --find the average between them
        local average = (momVal + dadVal) / 2
        --mutation range is 1/10th of average, so higher values = more mutation
        local mutationRange = math.clamp(average * 0.1, 5, 50)
        local mutation = math.random(-mutationRange, mutationRange)
        local finalValue = math.floor(average + mutation)
        finalValue = math.max(finalValue, 0)

        self.refData.attributes[attribute + 1] = finalValue
    end
end

function Animal:randomiseGenes()
    --For converting guars, we get its genetics by treating itself as its parents
    --Which randomises its attributes, then updateGrowth should apply to the object
    self:inheritGenes(self.reference, self.reference)
end

function Animal.getWhiteBabyChance()
    local chanceOutOf = 50
    local merlordESPs = {
        "Ashfall.esp",
        "BardicInspiration.esp",
        "Character Backgrounds.esp",
        "DemonOfKnowledge.esp",
        "Go Fletch.esp",
        "Love_Pillow_Hunt.esp",
        "theMidnightOil.ESP"
    }
    local merlordMWSEs = {
        "backstab",
        "BedBuddies",
        "BookWorm",
        "class-description",
        "KillCommand",
        "MarksmanRebalanced",
        "Mining",
        "MiscMates",
        "NoCombatMenu",
        "QuickLoadouts",
        "RealisticRepair",
        "StartingEquipment",
        "lessAggressiveCreatures",
        "accidentalTheftProtection"
    }
    for _, esp in ipairs(merlordESPs) do
        if tes3.isModActive(esp) then
            chanceOutOf = chanceOutOf - 1
        end
    end
    for _, mod in ipairs(merlordMWSEs) do
        if tes3.getFileExists(string.format("MWSE\\mods\\mer\\%s\\main.lua", mod)) then
            chanceOutOf = chanceOutOf - 1
        end
    end
    local roll = math.random(chanceOutOf)
    return roll == 1
end

function Animal:getCanConceive()
    if not self.animalType.breedable then return false end
    if not ( self.refData.gender == "female" ) then return false end
    if self.refData.isBaby then return false end
    if not self.mobile.hasFreeAction then return false end
    if self.refData.trust < moodConfig.skillRequirements.breed then return false end
    if self.refData.lastBirthed then
        local now = common.getHoursPassed()
        local hoursSinceLastBirth = now - self.refData.lastBirthed
        local enoughTimePassed = hoursSinceLastBirth > self.animalType.birthIntervalHours
        if not enoughTimePassed then return false end
    end
    return true
end

function Animal:canBeImpregnatedBy(animal)
    if not animal.animalType.breedable then return false end
    if not (animal.refData.gender == "male" ) then return false end
    if animal.refData.isBaby then return false end
    if not animal.mobile.hasFreeAction then return false end
    if self.refData.trust < moodConfig.skillRequirements.breed then return false end
    local distance = animal:distanceFrom(self.reference)
    if distance > 1000 then
        return false
    end
    return true
end



function Animal:breed()
    --Find nearby animal
    ---@type GuarWhisperer.Animal[]
    local partnerList = {}

    common.iterateRefType("companion", function(ref)
        local animal = Animal:new(ref)
        if self:canBeImpregnatedBy(animal) then
            table.insert(partnerList, animal)
        end
    end)

    if #partnerList > 0 then
        local function doBreed(partner)
            partner:playAnimation("pet")
            local baby
            timer.start{ type = timer.real, duration = 1, callback = function()
                local color = self:getWhiteBabyChance() and "white" or "standard"
                self.refData.lastBirthed  = common.getHoursPassed()
                local babyRef = tes3.createReference{
                    object = animalConfig.guarMapper[color],
                    position = self.reference.position,
                    orientation =  {
                        self.reference.orientation.x,
                        self.reference.orientation.y,
                        self.reference.orientation.z,
                    },
                    cell = self.reference.cell,
                    scale = self.animalType.babyScale
                }
                babyRef.mobile.fight = 0
                babyRef.mobile.flee = 0

                baby = Animal:new(babyRef)
                if baby then
                    baby.refData.isBaby = true
                    baby.refData.trust = self.animalType.trust.babyLevel
                    --baby:inheritGenes(self, partner)
                    baby:updateGrowth()
                    baby:setHome(baby.reference.position, baby.reference.cell)
                    baby:setAttackPolicy("defend")
                    baby:wander()
                else
                    --Failed to make baby
                end
            end}

            common.fadeTimeOut(0.5, 2, function()
                timer.delayOneFrame(function()
                    if baby then
                        baby:rename(true)
                    end
                end)
            end)
        end
        local buttons = {}
        local i = 1
        ---@param partner GuarWhisperer.Animal
        for _, partner in ipairs(partnerList) do
            table.insert(buttons,
                {
                    text = string.format("%d. %s", i, partner:getName() ),
                    callback = function()
                        doBreed(partner)
                    end
                }
            )
        end
        table.insert( buttons, { text = "Cancel"})

        common.messageBox{
            message = string.format("Which partner would you like to breed %s with?", self:getName() ),
            buttons = buttons
        }
    else
        tes3.messageBox("There are no valid partners nearby.")
    end
end



------------------------------------------
-- Switch node pack functions
--------------------------------------------

function Animal.removeLight(lightNode)
    for node in table.traverse{lightNode} do
        --Kill particles
        if node.RTTI.name == "NiBSParticleNode" then
            --node.appCulled = true
            node.parent:detachChild(node)
        end
        --Kill Melchior's Lantern glow effect
        if node.name == "LightEffectSwitch" or node.name == "Glow" then
            --node.appCulled = true
            node.parent:detachChild(node)
        end
        if node.name == "AttachLight" then
            --node.appCulled = true
            node.parent:detachChild(node)
        end

        -- Kill materialProperty
        local materialProperty = node:getProperty(0x2)
        if materialProperty then
            if (materialProperty.emissive.r > 1e-5 or materialProperty.emissive.g > 1e-5 or materialProperty.emissive.b > 1e-5 or materialProperty.controller) then
                materialProperty = node:detachProperty(0x2):clone()
                node:attachProperty(materialProperty)

                -- Kill controllers
                materialProperty:removeAllControllers()

                -- Kill emissives
                local emissive = materialProperty.emissive
                emissive.r, emissive.g, emissive.b = 0,0,0
                materialProperty.emissive = emissive

                node:updateProperties()
            end
        end
     -- Kill glowmaps
        local texturingProperty = node:getProperty(0x4)
        local newTextureFilepath = "Textures\\tx_black_01.dds"
        if (texturingProperty and texturingProperty.maps[4]) then
        texturingProperty.maps[4].texture = niSourceTexture.createFromPath(newTextureFilepath)
        end
        if (texturingProperty and texturingProperty.maps[5]) then
            texturingProperty.maps[5].texture = niSourceTexture.createFromPath(newTextureFilepath)
        end
    end
    lightNode:update()
    lightNode:updateEffects()

end

function Animal:getHeldItem(packItem)
    for _, item in ipairs(packItem.items) do
        if self.reference.object.inventory:contains(item) then
            return tes3.getObject(item)
        end
    end
end


function Animal:attachLantern(lanternObj)
    local lanternParent = self.reference.sceneNode:getObjectByName("LANTERN")
    --get lantern mesh and attach
    local itemNode = tes3.loadMesh(lanternObj.mesh):clone()
    --local attachLight = itemNode:getObjectByName("AttachLight")
    --attachLight.parent:detachChild(attachLight)
    itemNode:clearTransforms()
    itemNode.name = lanternObj.id
    lanternParent:attachChild(itemNode, true)
end

function Animal:detachLantern()
    local lanternParent = self.reference.sceneNode:getObjectByName("LANTERN")
    lanternParent:detachChildAt(1)
end


function Animal:turnLanternOn(e)
    e = e or {}
    if not self.reference.sceneNode then return end
    --First we gotta delete the old one and clone again, to get our material properties back
    local lanternParent = self.reference.sceneNode:getObjectByName("LANTERN")
    if lanternParent and lanternParent.children and #lanternParent.children > 0 then
        local lanternId = lanternParent.children[1].name
        self:detachLantern()
        self:attachLantern(tes3.getObject(lanternId))

        local lightParent = self.reference.sceneNode:getObjectByName("LIGHT")
        lightParent.translation.z = 0

        local lightNode = self.reference.sceneNode:getObjectByName("LanternLight")
        lightNode:setAttenuationForRadius(256)

        self.reference.sceneNode:update()
        self.reference.sceneNode:updateEffects()

        self.reference:getOrCreateAttachedDynamicLight(lightNode, 1.0)

        self.refData.lanternOn = true

        if e.playSound == true then
            tes3.playSound{ reference = tes3.player, sound = "mer_tgw_alight", pitch = 1.0}
        end
    end
end


function Animal:turnLanternOff(e)
    e = e or {}
    if not self.reference.sceneNode then return end
    local lanternParent = self.reference.sceneNode:getObjectByName("LANTERN")
    self.removeLight(lanternParent)
    local lightParent = self.reference.sceneNode:getObjectByName("LIGHT")
    lightParent.translation.z = 1000
    local lightNode = self.reference.sceneNode:getObjectByName("LanternLight")
    if lightNode then
        lightNode:setAttenuationForRadius(0)
        self.reference.sceneNode:update()
        self.reference.sceneNode:updateEffects()
        self.refData.lanternOn = false
        if e.playSound == true then
            tes3.playSound{ reference = tes3.player, sound = "mer_tgw_alight", pitch = 1.0}
        end
    end
end

function Animal:setSwitch()
    if not self.reference.sceneNode then return end
    if not self.reference.mobile then return end
    local animState = self.reference.mobile.actionData.animationAttackState

    --don't update nodes during dying animation
    --if health <= 0 and animState ~= tes3.animationState.dead then return end
    if animState == tes3.animationState.dying then return end

    for _, packItem in pairs(common.packItems) do
        local node = self.reference.sceneNode:getObjectByName(packItem.id)

        if node then
            node.switchIndex = self.pack:hasPackItem(packItem) and 1 or 0
            if self.refData.hasPack and common.getConfig().displayAllGear and packItem.dispAll then
                node.switchIndex =  1
            end

            --switch has changed, add or remove item meshes
            if packItem.attach then
                if packItem.light then
                    if self.refData.ignoreLantern then
                        node.switchIndex = 0
                        break
                    end
                    --attach item
                    local onNode = node.children[2]
                    local lightParent = onNode:getObjectByName("LIGHT")
                    local lanternParent = self.reference.sceneNode:getObjectByName("LANTERN")

                    if node.switchIndex == 1 then
                        local itemHeld = self:getHeldItem(packItem)

                         --Add actual light

                        --Check if its a different light, remove old one
                        local sameLantern
                        if lanternParent.children and lanternParent.children[1] ~= nil then
                            local currentLanternId = lanternParent.children[1].name
                            if itemHeld.id == currentLanternId then
                                sameLantern = true
                            end
                        end

                        if sameLantern ~= true then
                            common.log:debug("Changing lantern")
                            self:detachLantern()
                            self:attachLantern(itemHeld)

                            --set up light properties
                            local lightNode = onNode:getObjectByName("LanternLight") or niPointLight.new()
                            lightNode.name = "LanternLight"
                            lightNode.ambient = tes3vector3.new(0,0,0) --[[@as niColor]]
                            lightNode.diffuse = tes3vector3.new(
                                itemHeld.color[1] / 255,
                                itemHeld.color[2] / 255,
                                itemHeld.color[3] / 255
                            )--[[@as niColor]]
                            lightParent:attachChild(lightNode, true)
                            --Attach the light
                            if self.refData.lanternOn then
                                self:turnLanternOn()
                            else
                                self:turnLanternOff()
                            end
                        end
                    else
                        --detach item and light
                        if onNode:getObjectByName("LanternLight") then
                            self:detachLantern()
                            self:turnLanternOff()
                        end
                    end
                end
            end
        end
    end
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
        if self.refData.carriedItems ~= nil then
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