local guarConfig = require("mer.theGuarWhisperer.guarConfig")

local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("GuarCompanion")
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
local Mouth = require("mer.theGuarWhisperer.components.Mouth")
local AI = require("mer.theGuarWhisperer.components.AI")
local Ability = require("mer.theGuarWhisperer.abilities.Ability")

---@alias GuarWhisperer.Emotion
---| '"happy"'
---| '"sad"'
---| '"pet"'
---| '"eat"'
---| '"fetch"'
---| '"idle"'

---@alias GuarWhisperer.GuarCompanion.AIState
---| '"waiting"' #Not moving, doing nothing
---| '"following"' #Following the player
---| '"wandering"' #Wandering around
---| '"moving"' #Moving to a specific location
---| '"attacking"' #Attacking a target

---@alias GuarWhisperer.GuarCompanion.AttackPolicy
---| '"passive"'
---| '"defend"'

---@alias GuarWhisperer.GuarCompanion.PotionPolicy
---| '"none"'
---| '"all"'
---| '"healthOnly"'

---@class GuarWhisperer.GuarCompanion.Home
---@field position { [0]:number, [1]:number, [2]:number}
---@field cell string

---@class GuarWhisperer.GuarCompanion.RefData
---@field name string
---@field attackPolicy GuarWhisperer.GuarCompanion.AttackPolicy
---@field followingRef tes3reference|"player"
---@field home GuarWhisperer.GuarCompanion.Home
---@field dead boolean is dead
---@field commandActive boolean is currently doing a command
---@field triggerDialog boolean trigger dialog on next activate

---@class GuarWhisperer.GuarCompanion
---@field reference tes3reference
---@field safeRef mwseSafeObjectHandle
---@field refData GuarWhisperer.GuarCompanion.RefData
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
---@field mouth GuarWhisperer.Mouth
---@field ai GuarWhisperer.AI
---@field abilities table<GuarWhisperer.GuarCompanion.Abilities, GuarWhisperer.Ability> #Ability id -> Ability
---@field abilityList GuarWhisperer.Ability[] #List of abilities in order they appear in the command menu
local GuarCompanion = {}

---@alias GuarWhisperer.GuarCompanion.Abilities
---| '"charm"'
---| '"attack"'
---| '"eat"'
---| '"harvest"'
---| '"fetch"'
---| '"steal"'
---| '"pet"'
---| '"feed"'
---| '"follow"'
---| '"move"'
---| '"wait"'
---| '"wander"'
---| '"letMePass"'
---| '"equipPack"'
---| '"unequipPack"'
---| '"pacify"'
---| '"defend"'
---| '"breed"'
---| '"rename"'
---| '"getStatus"'
---| '"goHome"'
---| '"takeMeHome"'
---| '"setHome"'


---@type table<tes3.objectType, table>
GuarCompanion.pickableRotations = {
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

-- Reference Manager for GuarCompanion references
---@class GuarWhisperer.GuarCompanion.ReferenceManager : CraftingFramework.ReferenceManager
---@field references table<tes3reference, GuarWhisperer.GuarCompanion>
---@field iterateReferences fun(self: GuarWhisperer.GuarCompanion.ReferenceManager, param: fun(ref:tes3reference, refData:GuarWhisperer.GuarCompanion): boolean|nil )
GuarCompanion.referenceManager = CraftingFramework.ReferenceManager:new{
    id = "GuarWhisperer_Animals",
    requirements = function(_, ref)
        return ref.supportsLuaData and ref.data.tgw ~= nil
    end,
    onActivated = function(refManager, ref)
        local guar = GuarCompanion:new(ref)
        if guar then
            --Cache the guar class
            refManager.references[ref] = guar
            --intiialise
            guar:initialiseOnActivated()
        else
            logger:warn("Ref %s with tgw data was not valid guar", ref)
        end
    end
}

---@param reference tes3reference
---@return GuarWhisperer.GuarCompanion.RefData
function GuarCompanion.initialiseRefData(reference, animalType)
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
    GuarCompanion.referenceManager:addReference(reference)
    GuarCompanion.referenceManager:onActivated(reference)
    return reference.data.tgw
end

---------------------
--Class methods
---------------------

function GuarCompanion:__index(key)
    return self[key]
end

---@param reference tes3reference
---@return GuarWhisperer.GuarCompanion|nil
function GuarCompanion.get(reference)
    local cachedAnimal = GuarCompanion.referenceManager.references[reference]
    return cachedAnimal or GuarCompanion:new(reference)
end


--- Get the guar type for a converter guar
---@param reference tes3reference
---@return GuarWhisperer.AnimalType?
function GuarCompanion.getAnimalType(reference)
    return reference
     and reference.data.tgw
     and guarConfig.animals[reference.data.tgw.type]
     or guarConfig.animals.guar
end

function GuarCompanion.getAnimalObjects()
    return common.config.persistentData.createdGuars
end

---Returns all guar references,
--- even those not in active cells
---@return GuarWhisperer.GuarCompanion[]
function GuarCompanion.getAll()
    local animals = {}
    local objects = GuarCompanion.getAnimalObjects()
    for objId in pairs(objects) do
        local reference = tes3.getReference(objId)
        if reference then
            local guar = GuarCompanion.get(reference)
            if guar then
                table.insert(animals, guar)
            end
        end
    end
    return animals
end

function GuarCompanion.addToCreatedObjects(obj)
    local id = obj.id:lower()
    local createdObjects = GuarCompanion.getAnimalObjects()
    if createdObjects[id] == nil then
        createdObjects[id] = true
        logger:debug("Added %s to created objects", id)
    end
    common.addToEasyEscortBlacklist(obj)
end

--- Construct a new GuarCompanion
---@param reference tes3reference
---@return GuarWhisperer.GuarCompanion|nil
function GuarCompanion:new(reference)
    if not (reference and reference.supportsLuaData and reference.data.tgw) then return end
    local animalType = GuarCompanion.getAnimalType(reference)
    if not animalType then
        logger:trace("No guar type")
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
    newAnimal.mouth = Mouth.new(newAnimal)
    newAnimal.ai = AI.new(newAnimal)
    local abilities = {
        "charm",
        "attack",
        "eat",
        "harvest",
        "fetch",
        "steal",
        "pet",
        "feed",
        "follow",
        "move",
        "wait",
        "wander",
        "letMePass",
        "equipPack",
        "unequipPack",
        "pacify",
        "defend",
        "breed",
        "rename",
        "getStatus",
        "goHome",
        "takeMeHome",
        "setHome",
    }
    newAnimal.abilities = {}
    newAnimal.abilityList = {}
    for _, abilityId in ipairs(abilities) do
        local ability = Ability.get(abilityId)
        if ability then
            table.insert(newAnimal.abilityList, ability)
            newAnimal.abilities[abilityId] = ability
        else
            logger:warn("Ability '%s' not registered", abilityId)
        end
    end

    setmetatable(newAnimal, self)
    self.__index = self
    GuarCompanion.addToCreatedObjects(reference.baseObject)
    event.trigger("GuarWhisperer:registerReference", { reference = reference })
    return newAnimal
end

---Check if the reference associated with this GuarCompanion is still valid
---@return boolean isValid
function GuarCompanion:isValid()
    local valid = self.safeRef:valid()
    if not valid then
        logger:warn("%s's reference is invalid", self:getName())
    end
    return valid
end

--- Get the animals' name
---@return string
function GuarCompanion:getName()
    return self.object.name
end

function GuarCompanion:setName(newName)
    self.object.name = newName
end


--- Set the attack policy
---@param policy GuarWhisperer.GuarCompanion.AttackPolicy
function GuarCompanion:setAttackPolicy(policy)
    self.refData.attackPolicy = policy
end

--- Get the attack policy
---@return GuarWhisperer.GuarCompanion.AttackPolicy
function GuarCompanion:getAttackPolicy()
    return self.refData.attackPolicy
end


function GuarCompanion:initialiseOnActivated()
    if not self:isDead() then
        self.ai:playAnimation("idle")
        if self.mouth:hasCarriedItems() then
            for _, item in pairs(self.mouth:getCarriedItems()) do
                self.mouth:putItemInMouth(tes3.getObject(item.id))
            end
        end
        self.pack:setSwitch()
        self.ai:updateAI()
        logger:info("intialised %s on activated", self:getName())
    end
end

---@param reference tes3reference
function GuarCompanion:distanceFrom(reference)
    return self.reference.position:distance(reference.position)
end

---------------------
--Movement functions
-----------------------

local CELL_WIDTH = 8192
local HOURS_PER_CELL = 0.5
--- Calculate how long it takes to travel home
function GuarCompanion:getTravelTime()
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
function GuarCompanion:getTravelTimeText(hours)
    hours = hours or self:getTravelTime()
    return string.format("%dh%2.0fm", hours, 60*( hours - math.floor(hours)))
end

-- Go back to its home position
---@param e { takeMe: boolean }?
function GuarCompanion:goHome(e)
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
            self.ai:wait()
            timer.delayOneFrame(function()
                if not self:isValid() then return end
                self.ai:wander()
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

---@return GuarWhisperer.GuarCompanion.Home
function GuarCompanion:getHome()
    return self.refData.home
end

--[[
    position must be tes3vector3, cell must be tes3cell
    converts position to table and cell to id for serialisation
]]
function GuarCompanion:setHome(position, cell)
    local newPosition = { position.x, position.y, position.z}
    self.refData.home = { position = newPosition, cell = cell.id }
    tes3.messageBox("Set %s's new home in %s", self:getName(), cell.id)
end

function GuarCompanion:isDead()
    return self.refData.dead or common.getIsDead(self.reference)
end

--------------------------------
-- Fetch Functions
--------------------------------

function GuarCompanion:canBeSummoned()
    return (
        self:isDead() ~= true and
        self.needs:hasSkillReqs("follow")
    )
end

function GuarCompanion:canEat(ref)
    if ref.isEmpty then
        return false
    end
    return self.animalType.foodList[string.lower(ref.object.id)]
end



function GuarCompanion:isActive()
    return (
        self.reference and
        self.reference.mobile and
        table.find(tes3.getActiveCells(), self.reference.cell) and
        not self:isDead() and
        self:distanceFrom(tes3.player) < 5000
    )
end

function GuarCompanion:getMenuTitle()
    local name = self:getName() or "This"
    return string.format(
        "%s is a %s%s %s. %s %s.",
        name, self.genetics:isBaby() and "baby " or "", self.genetics:getGender(), self.animalType.type,
        self.syntax:getHeShe(), self.needs:getHappinessStatus().description
    )
end

function GuarCompanion:getStatusMenu()
    ui.showStatusMenu(self)
end

----------------------------------------
--Commands
----------------------------------------


function GuarCompanion:takeAction(time)
    self.reference.tempData.tgw_takingAction = true
    timer.start{
        duration = time,
        callback = function()
            if not self:isValid() then return end
            self.reference.tempData.tgw_takingAction = false
        end
    }
end

function GuarCompanion:canTakeAction()
    return not self.reference.tempData.tgw_takingAction
end


function GuarCompanion:pet()
    logger:debug("Petting")
    self.needs:modAffection(self.animalType.affection.petValue)
    tes3.messageBox(self.needs:getAffectionStatus().pettingResult(self) )
    self.ai:playAnimation("pet")
    self:takeAction(2)
    if not self.needs:hasSkillReqs("follow") then
        self.needs:modTrust(2)
    end
end

function GuarCompanion:getRefusalMessage()
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


function GuarCompanion:rename()
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
        self.ai:playAnimation("happy")
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



function GuarCompanion:activate()
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
        if self.mouth:hasCarriedItems() then
            self.refData.commandActive = false
            self.mouth:handOverItems()
            self.ai:restorePreviousAI()
        elseif self.refData.commandActive then
            logger:trace("command is active")
            self.refData.commandActive = false
        else
            if self:canTakeAction() then
                logger:trace("showing command menu")
                event.trigger("TheGuarWhisperer:showCommandMenu", { guar = self })
            else
                logger:trace("can't take action")
            end
        end
        return false
    end
end

return GuarCompanion