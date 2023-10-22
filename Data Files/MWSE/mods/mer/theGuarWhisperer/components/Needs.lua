local moodConfig = require("mer.theGuarWhisperer.moodConfig")
local common = require("mer.theGuarWhisperer.common")
local logger = common.log

---@class GuarWhisperer.Needs.Animal.refData
---@field hunger number
---@field trust number
---@field affection number
---@field play number
---@field happiness number
---@field lastUpdated number

---@class GuarWhisperer.Needs.Animal : GuarWhisperer.Animal
---@field refData GuarWhisperer.Needs.Animal.refData

--- This class manages a companion's needs.
---@class GuarWhisperer.Needs
---@field animal GuarWhisperer.Needs.Animal
local Needs = {
    default = {
        trust = moodConfig.defaultTrust,
        affection = moodConfig.defaultAffection,
        play = moodConfig.defaultPlay,
        hunger = 50,
        happiness = 0,
    }
}

---@param animal GuarWhisperer.Needs.Animal
---@return GuarWhisperer.Needs
function Needs.new(animal)
    local self = setmetatable({}, { __index = Needs })
    self.animal = animal
    return self
end

---------------------------------------------------------
--- Hunger
---------------------------------------------------------

---@return number
function Needs:getHunger()
    return self.animal.refData.hunger or Needs.default.hunger
end

---@param hunger number
function Needs:setHunger(hunger)
    self.animal.refData.hunger = hunger
end

---@return GuarWhisperer.Hunger.Status
function Needs:getHungerStatus()
    return self:getMood("hunger")
end

function Needs:modHunger(amount)
    local previousMood = self:getHungerStatus()
    self:setHunger(math.clamp(self:getHunger() + amount, 0, 100))
    local newMood = self:getMood("hunger")
    if newMood ~= previousMood then
        tes3.messageBox("%s is %s.", self.animal:getName(), newMood.description)
    end
    tes3ui.refreshTooltip()
end

function Needs:updateHunger(timeSinceUpdate)
    local changeAmount = self.animal.animalType.hunger.changePerHour * timeSinceUpdate
    self:modHunger(changeAmount)
end

---------------------------------------------------------
--- Trust
---------------------------------------------------------

---@return number
function Needs:getTrust()
    return self.animal.refData.trust or Needs.default.trust
end

---@param trust number
function Needs:setTrust(trust)
    self.animal.refData.trust = trust
end

---@return GuarWhisperer.Trust.Status
function Needs:getTrustStatus()
    return self:getMood("trust")
end

function Needs:modTrust(amount)
    local previousTrust = self:getTrust()
    self:setTrust(math.clamp(previousTrust+ amount, 0, 100))
    local afterTrust = self:getTrust()
    self.animal.reference.mobile.fight = 50 - (self:getTrust() / 2 )

    for _, trustData in ipairs(moodConfig.trust) do
        if previousTrust < trustData.minValue and afterTrust > trustData.minValue then
            local message = string.format("%s %s. ",
                self.animal:getName(), trustData.description)
            if trustData.skillDescription then
                message = message .. string.format("%s %s",
                    self.animal.syntax:getHeShe(), trustData.skillDescription)
            end
            timer.delayOneFrame(function()
                tes3.messageBox{ message = message, buttons = {"Okay"} }
            end)
        end
    end
    tes3ui.refreshTooltip()
    return afterTrust
end

function Needs:updateTrust(timeSinceUpdate)
    --Limit trust update while time skipping
    if timeSinceUpdate > 0.5 then
        logger:debug("Resting/Waiting, trust update limited to %s", moodConfig.trustWaitMultiplier)
        timeSinceUpdate = timeSinceUpdate * moodConfig.trustWaitMultiplier
    end
    --Trust changes if nearby
    local happinessMulti = math.remap(self:getHappiness(), 0, 100, -1.0, 1.0)
    local trustChangeAmount = (
        self.animal.animalType.trust.changePerHour *
        happinessMulti *
        timeSinceUpdate
    )
    self:modTrust(trustChangeAmount)
    logger:trace("Trust change amount: %s. New Trust: %s", trustChangeAmount, self:getTrust())
end


---------------------------------------------------------
--- Affection
---------------------------------------------------------

---@return number
function Needs:getAffection()
    return self.animal.refData.affection or Needs.default.affection
end

---@param affection number
function Needs:setAffection(affection)
    self.animal.refData.affection = affection
end

---@return GuarWhisperer.Affection.Status
function Needs:getAffectionStatus()
    return self:getMood("affection")
end

function Needs:modAffection(amount)
    --As he gains affection, his fight level decreases
    if amount > 0 then
        self.animal.mobile.fight = self.animal.mobile.fight - math.min(amount, 100 - self:getAffection())
    end
    self:setAffection(math.clamp(self:getAffection() + amount, 0, 100))
    return self:getAffection()
end

function Needs:updateAffection(timeSinceUpdate)
    if timeSinceUpdate > 0.5 then
        logger:debug("Resting/Waiting, affection update limited to %s", moodConfig.affectionWaitMultiplier)
        timeSinceUpdate = timeSinceUpdate * moodConfig.affectionWaitMultiplier
    end

    local changeAmount = self.animal.animalType.affection.changePerHour * timeSinceUpdate
    self:modAffection(changeAmount)
end

---------------------------------------------------------
--- Play
---------------------------------------------------------

---@return number
function Needs:getPlay()
    return self.animal.refData.play or Needs.default.play
end

---@param play number
function Needs:setPlay(play)
    self.animal.refData.play = play
end

function Needs:modPlay(amount)
    self:setPlay(math.clamp(self:getPlay() + amount, 0, 100))
    tes3ui.refreshTooltip()
    return self:getPlay()
end

function Needs:updatePlay(timeSinceUpdate)
    local changeAmount = self.animal.animalType.play.changePerHour * timeSinceUpdate
    self:modPlay(changeAmount)
end

---------------------------------------------------------
--- Happiness
---------------------------------------------------------

---@return number
function Needs:getHappiness()
    return self.animal.refData.happiness or Needs.default.happiness
end

---@param happiness number
function Needs:setHappiness(happiness)
    self.animal.refData.happiness = happiness
end

---@return GuarWhisperer.Happiness.Status
function Needs:getHappinessStatus()
    return self:getMood("happiness")
end


function Needs:updateHappiness()
    local healthRatio = self.animal.reference.mobile.health.current / self.animal.reference.mobile.health.base
    local hungerEffect = math.remap(self:getHunger(), 0, 100, -15, 30)
    local comfortEffect = math.remap(healthRatio, 0, 1.0, -100, 0)
    local affectionEffect = math.remap(self:getAffection(), 0, 100, -10, 40)
    local play = math.remap(self:getPlay(), 0, 100, 0, 15)
    local trust = math.remap(self:getTrust(), 0, 100, 0, 20)

    local newHappiness = hungerEffect + comfortEffect + affectionEffect + play + trust
    newHappiness = math.clamp(newHappiness, 0, 100)

    self:setHappiness(newHappiness)

    self.animal.reference.mobile.flee = 75 - (self:getHappiness()/ 2)
    tes3ui.refreshTooltip()
end

---------------------------------------------------------

function Needs:hasSkillReqs(skill)
    return self:getTrust() > moodConfig.skillRequirements[skill]
end

function Needs:updateNeeds()
    --get the time since last updated
    local now = common.getHoursPassed()
    if not self.animal:isActive() then
        --not active, reset time
        self.animal.refData.lastUpdated = now
        return
    end
    local lastUpdated = self.animal.refData.lastUpdated or now
    local timeSinceUpdate = now - lastUpdated
    self:updatePlay(timeSinceUpdate)
    self:updateAffection(timeSinceUpdate)
    self:updateHappiness()
    self:updateHunger(timeSinceUpdate)
    self:updateTrust(timeSinceUpdate)
    self.animal.refData.lastUpdated = now
end

---@private
---Gets the status of a need
function Needs:getMood(moodType)
    for _, mood in ipairs(moodConfig[moodType]) do
        if self.animal.refData[moodType] <= mood.maxValue then
            return mood
        end
    end
end

return Needs