local common = require("mer.theGuarWhisperer.common")
local logger = common.log

---@alias GuarWhisperer.Stats.AttributeName
---| '"strength"'
---| '"agility"'
---| '"endurance"'
---| '"intelligence"'
---| '"willpower"'
---| '"personality"'
---| '"speed"'
---| '"luck"'

---@type table<GuarWhisperer.Stats.AttributeName, {increasePerLevel: number, inverseScale: boolean}>
local attributeScaling = {
    strength = {
        increasePerLevel = 5,
        inverseScale = false,
    },
    agility = {
        increasePerLevel = 1,
        inverseScale = false,
    },
    endurance = {
        increasePerLevel = 1,
        inverseScale = false,
    },
    intelligence = {
        increasePerLevel = 1,
        inverseScale = false,
    },
    willpower = {
        increasePerLevel = 1,
        inverseScale = false,
    },
    personality = {
        increasePerLevel = 1,
        inverseScale = false,
    },
    speed = {
        increasePerLevel = 0,
        inverseScale = true,
    },
    luck = {
        increasePerLevel = 0,
        inverseScale = false,
    },
}

---@class GuarWhisperer.Stats.Animal.refData
---@field progress number
---@field level number

--- The original attributes of the animal.
---@alias GuarWhisperer.Stats.BaseAttributes table<GuarWhisperer.Stats.AttributeName, number>

---@class GuarWhisperer.Stats.Animal : GuarWhisperer.Animal
---@field refData GuarWhisperer.Stats.Animal.refData

--- This class manages a companion's stats,
--- progress and leveling up.
---@class GuarWhisperer.Stats
---@field animal GuarWhisperer.Stats.Animal
local Stats = {}

---@param animal GuarWhisperer.Stats.Animal
---@return GuarWhisperer.Stats
function Stats.new(animal)
    local self = setmetatable({}, { __index = Stats })
    self.animal = animal
    return self
end

---@param progress number
function Stats:progressLevel(progress)
    if self.animal.genetics:isBaby() then return end
    logger:debug("%s is progressing by %s", self.animal:getName(), progress)
    local progressNeeded = self:getProgressNeeded()
    self:setProgress(self:getProgress() + progress)
    local didLevelUp = self:getProgress() > progressNeeded
    if didLevelUp then
        self:levelUp()
    end
end

---@return number
function Stats:getLevel()
    return math.floor(self.animal.refData.level) or 1
end

---@param level number
function Stats:setLevel(level)
    self.animal.refData.level = level
end

---@return number
function Stats:getProgress()
    return self.animal.refData.progress or 0
end

---@param progress number
function Stats:setProgress(progress)
    self.animal.refData.progress = progress
end


---@return tes3statistic
function Stats:getAttribute(attribute)
    return self.animal.reference.mobile.attributes[tes3.attribute[attribute] + 1]
end

---@param attribute GuarWhisperer.Stats.AttributeName
function Stats:getBaseAttributeValue(attribute)
    return self.animal.reference.baseObject.attributes[tes3.attribute[attribute] + 1]
end


---@param attribute GuarWhisperer.Stats.AttributeName
---@param value number
function Stats:setAttribute(attribute, value)
    tes3.setStatistic{
        reference = self.animal.reference.mobile,
        attribute = tes3.attribute[attribute],
        value = value,
    }
end

---@param attribute GuarWhisperer.Stats.AttributeName
---@param value number
function Stats:setBaseAttribute(attribute, value)
    self.animal.reference.baseObject.attributes[tes3.attribute[attribute] + 1] = value
end

function Stats:setStats()
    self:determineAttributes()
    self:determineHealth()
    self:determineAttack()
end

function Stats:print()
    local message =
    [[Attack:
        Object: %d, Bonus: %d
    Attributes:
        Strength     - Object: %d, Current: %d
        Agility      - Object: %d, Current: %d
        Endurance    - Object: %d, Current: %d
        Intelligence - Object: %d, Current: %d
        Willpower    - Object: %d, Current: %d
        Personality  - Object: %d, Current: %d
        Speed        - Object: %d, Current: %d
        Luck         - Object: %d, Current: %d]]
    mwse.log(message,
        self.animal.reference.baseObject.attacks[1].max, self.animal.reference.mobile.attackBonus,
        self:getBaseAttributeValue("strength"), self:getAttribute("strength").current,
        self:getBaseAttributeValue("agility"), self:getAttribute("agility").current,
        self:getBaseAttributeValue("endurance"), self:getAttribute("endurance").current,
        self:getBaseAttributeValue("intelligence"), self:getAttribute("intelligence").current,
        self:getBaseAttributeValue("willpower"), self:getAttribute("willpower").current,
        self:getBaseAttributeValue("personality"), self:getAttribute("personality").current,
        self:getBaseAttributeValue("speed"), self:getAttribute("speed").current,
        self:getBaseAttributeValue("luck"), self:getAttribute("luck").current
    )
end

----------------------------------------------------
-- Private Methods
----------------------------------------------------

---@private
---@return number the amount of progress required to level up
function Stats:getProgressNeeded()
    return 20 + self:getLevel()
end

---@private
--- Determine the creature's attributes based on its level and scale.
function Stats:determineAttributes()
    logger:debug("Determining atrributes")
    local level = self:getLevel()
    local scale = self.animal.reference.scale
    for attribute, config in pairs(attributeScaling) do
        local levelEffect = (level-1) * config.increasePerLevel
        local scaleEffect = config.inverseScale
            and (1 / scale)
            or scale
        local baseValue = self:getBaseAttributeValue(attribute)
        local newValue = math.floor((baseValue + levelEffect) * scaleEffect)
        self:setAttribute(attribute, newValue)
    end
end

---@private
--- Determine the creature's health based on its level and scale.
function Stats:determineHealth()
    local level = self:getLevel()
    local levelEffect = (level-1) * 5
    local health = self.animal.reference.baseObject.health
    local scaleEffect = self.animal.reference.scale
    local newHealth = math.floor((health + levelEffect) * scaleEffect)
    tes3.setStatistic{
        reference = self.animal.reference.mobile,
        name = "health",
        value = newHealth,
    }
end

---@private
--- Determine the creature's attack based on its level.
function Stats:determineAttack()
    local level = self:getLevel()
    local levelEffect = level - 1
    self.animal.reference.mobile.attackBonus = levelEffect
end

---@private
function Stats:levelUp()
    local newLevel = self:getLevel() + 1
    self:setProgress(0)
    self:setLevel(newLevel)
    self:determineAttributes()
    self:determineHealth()
    self:determineAttack()
    tes3.messageBox{
        message = string.format("%s is now Level %s", self.animal:getName(), newLevel),
        --buttons = { "Okay" }
    }
end

return Stats