local common = require("mer.theGuarWhisperer.common")
local logger = common.log

--- This class manages a companion's stats,
--- progress and leveling up.
---@class GuarWhisperer.Stats
---@field animal GuarWhisperer.Animal
local Stats = {}

---@param animal GuarWhisperer.Animal
---@return GuarWhisperer.Stats
function Stats.new(animal)
    local self = setmetatable({}, { __index = Stats })
    self.animal = animal
    return self
end


---@param progress number
function Stats:progressLevel(progress)
    if self.animal.refData.isBaby then return end
    logger:debug("%s is progressing by %s", self.animal:getName(), progress)
    local level = self:getLevel()
    local progressNeeded = 10 + level
    progress = progress * ( 1 / progressNeeded)
    logger:debug("Level before: %s. Actual progress value: %s", self.animal.refData.level, progress)
    self.animal.refData.level = self.animal.refData.level + progress
    local newLevel = self:getLevel()
    local didLevelUp = newLevel > level
    if didLevelUp then
        self:levelUp()
    end
end


---@return number
function Stats:getLevel()
    return math.floor(self.animal.refData.level)
end


----------------------------------------------------
-- Private Methods
----------------------------------------------------

---@private
function Stats:getBaseStrength()
    ---@type tes3creature
    local baseObj = self.animal.reference.baseObject
    return baseObj.attributes[tes3.attribute.strength + 1]
end

---@private
--- Sets strength to base + (level * 5)
function Stats:setStrengthFromLevel()
    local level = self:getLevel()
    local levelEffect = (level-1) * 5
    local newStrength = self:getBaseStrength() + levelEffect
    --Set strength to base + (level * 5)
    tes3.setStatistic{
        reference = self.animal.reference.mobile,
        name = "strength",
        value = newStrength,
    }
end

---@private
--- Sets health to base + (level * 5)
function Stats:setHealthFromLevel()
    local level = self:getLevel()
    local levelEffect = (level-1) * 5
    local newHealth = self.animal.reference.baseObject.health + levelEffect
    tes3.setStatistic{
        reference = self.animal.reference.mobile,
        name = "health",
        value = newHealth,
    }
end

---@private
--- Increases attack by 1 per level
function Stats:setAttackFromLevel()
    local level = self:getLevel()
    local levelEffect = level - 1
    local spellId = string.format("%s_attk", self.animal.reference.id)
    ---@diagnostic disable-next-line: deprecated
    local spell = tes3.getObject(spellId) or tes3spell.create(spellId, "Attack Bonus")
    spell.castType = tes3.spellType.ability
    local effect = spell.effects[1]
    effect.id = tes3.effect.fortifyAttack
    effect.rangeType = tes3.effectRange.animal
    effect.min = levelEffect
    effect.max = levelEffect
    tes3.removeSpell{ reference = self.animal.reference, spell = spell }
    timer.delayOneFrame(function()
        tes3.addSpell{ reference = self.animal.reference, spell = spell }
    end)
end

---@private
function Stats:levelUp()
    local level = self:getLevel()
    --Floor level to remove excess progress
    self.animal.refData.level = level
    self:setStrengthFromLevel()
    self:setHealthFromLevel()
    self:setAttackFromLevel()
    self.animal:playAnimation("pet")
    tes3.messageBox{
        message = string.format("%s is now Level %s", self.animal:getName(), level),
        buttons = { "Okay" }
    }
end

return Stats