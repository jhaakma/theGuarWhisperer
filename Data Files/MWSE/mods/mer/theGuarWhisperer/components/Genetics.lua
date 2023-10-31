local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("Genetics")
local moodConfig = require("mer.theGuarWhisperer.moodConfig")
local Controls = require("mer.theGuarWhisperer.services.Controls")

---@alias GuarWhisperer.Gender
---|'"male"' Male
---|'"female"' Female
---|'"none"' No gender

---@class GuarWhisperer.Genetics.GuarCompanion.refData
---@field isBaby boolean
---@field lastBirthed number
---@field birthTime number
---@field gender GuarWhisperer.Gender
---@field trust number

---@class GuarWhisperer.Genetics.GuarCompanion : GuarWhisperer.Companion.Guar
---@field refData GuarWhisperer.Genetics.GuarCompanion.refData

---This component deals with genetics and breeding
---@class GuarWhisperer.Genetics
---@field animal GuarWhisperer.Genetics.GuarCompanion
local Genetics = {}

---@param animal GuarWhisperer.Genetics.GuarCompanion
---@return GuarWhisperer.Genetics
function Genetics.new(animal)
    local self = setmetatable({}, { __index = Genetics })
    self.animal = animal
    return self
end

function Genetics:isBaby()
    return self.animal.refData.isBaby
end

---@param isBaby boolean
function Genetics:setIsBaby(isBaby)
    self.animal.refData.isBaby = isBaby
end

---@return GuarWhisperer.Gender
function Genetics:getGender()
    if not self.animal.refData.gender then
        self.animal.refData.gender = math.random() < 0.55 and "male" or "female"
    end
    return self.animal.refData.gender
end

---Sets birth time to now
function Genetics:setBirthTime()
    self.animal.refData.birthTime = common.util.getHoursPassed()
end

---Gets the time this guar was born
---@return number
function Genetics:getBirthTime()
    return self.animal.refData.birthTime or common.util.getHoursPassed()
end

--Averages the attributes of mom and dad and adds some random mutation
--Stores them on refData so they can be scaled down during adolescence
---@param mom GuarWhisperer.Genetics.GuarCompanion
---@param dad GuarWhisperer.Genetics.GuarCompanion
function Genetics:inheritGenes(mom, dad)
    for _, attribute in pairs(tes3.attribute) do
        local attributeName = table.find(tes3.attribute, attribute)
        --get base values of parents
        local momVal = mom.stats:getBaseAttributeValue(attributeName)
        local dadVal = dad.stats:getBaseAttributeValue(attributeName)
        --find the average between them
        local average = (momVal + dadVal) / 2
        --mutation range is 1/10th of average, so higher values = more mutation
        local mutationRange = math.clamp(average * 0.1, 5, 50)
        local mutation = math.lerp(-mutationRange, mutationRange, math.random())
        local finalValue = math.floor(average + mutation)
        finalValue = math.max(finalValue, 0)
        logger:debug(" - Setting %s to %d", attributeName, finalValue)
        self.animal.stats:setBaseAttribute(attributeName, finalValue)
    end
    self.animal.stats:setStats()
end

function Genetics:randomiseGenes()
    logger:debug("Randomising genes")
    --For converting guars, we get its genetics by treating itself as its parents
    --Which randomises its attributes, then updateGrowth should apply to the object
    self:inheritGenes(self.animal, self.animal)
end

function Genetics.getWhiteBabyChance()
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

function Genetics:getCanConceive()
    if not self.animal.animalType.breedable then return false end
    if not ( self.animal.refData.gender == "female" ) then return false end
    if self:isBaby() then return false end
    if not self.animal.mobile.hasFreeAction then return false end
    if self.animal.needs:getTrust() < moodConfig.skillRequirements.breed then return false end
    if self.animal.refData.lastBirthed then
        local now = common.util.getHoursPassed()
        local hoursSinceLastBirth = now - self.animal.refData.lastBirthed
        local enoughTimePassed = hoursSinceLastBirth > self.animal.animalType.birthIntervalHours
        if not enoughTimePassed then return false end
    end
    return true
end

---@param animal GuarWhisperer.Genetics.GuarCompanion|GuarWhisperer.Companion.Guar
function Genetics:canBeImpregnatedBy(animal)
    if not animal.animalType.breedable then return false end
    if not (animal.refData.gender == "male" ) then return false end
    if animal.genetics:isBaby() then return false end
    if not animal.mobile.hasFreeAction then return false end
    if self.animal.needs:getTrust() < moodConfig.skillRequirements.breed then return false end
    local distance = animal:distanceFrom(self.animal.reference)
    if distance > 1000 then
        return false
    end
    return true
end

function Genetics:breed()
    --Find nearby animal
    ---@type GuarWhisperer.Companion.Guar[]
    local partnerList = {}

    self.animal.referenceManager:iterateReferences(function(_, animal)
        if self:canBeImpregnatedBy(animal) then
            table.insert(partnerList, animal)
        end
    end)

    if #partnerList > 0 then
        local function doBreed(partner)
            partner:playAnimation("pet")
            local baby
            timer.start{
                type = timer.real,
                duration = 1,
                callback = function()
                    if not self.animal:isValid() then return end
                    self.animal.refData.lastBirthed  = common.util.getHoursPassed()
                    local babyObject = common.createCreatureCopy(self.animal.reference.baseObject)
                    babyObject.name = string.format("%s Jr", self.animal:getName())
                    local babyRef = tes3.createReference{
                        object = babyObject,
                        position = self.animal.reference.position,
                        orientation =  {
                            self.animal.reference.orientation.x,
                            self.animal.reference.orientation.y,
                            self.animal.reference.orientation.z,
                        },
                        cell = self.animal.reference.cell,
                        scale = self.animal.animalType.babyScale
                    }
                    timer.delayOneFrame(function()
                        if not self.animal:isValid() then return end
                        self.animal.initialiseRefData(babyRef, self.animal.animalType)
                        baby = self.animal:new(babyRef)
                        if baby then
                            baby.genetics:setIsBaby(true)
                            baby.needs:setTrust(self.animal.animalType.trust.babyLevel)
                            baby.genetics:setBirthTime()
                            --baby:inheritGenes(self, partner)
                            baby.genetics:updateGrowth()
                            baby:setAttackPolicy("passive")
                            baby:wander()
                            babyRef.mobile.fight = 0
                            babyRef.mobile.flee = 0
                        else
                            logger:error("Failed to make baby")
                        end
                    end)
                end
            }
            Controls.fadeTimeOut(0.5, 2, function()
                timer.delayOneFrame(function()
                    if baby and baby:isValid() then
                        baby:rename(true)
                    end
                end)
            end)
        end
        local buttons = {}
        local i = 1
        ---@param partner GuarWhisperer.Companion.Guar
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

        tes3ui.showMessageMenu{
            message = string.format("Which partner would you like to breed %s with?", self.animal:getName() ),
            buttons = buttons
        }
    else
        tes3.messageBox("There are no valid partners nearby.")
    end
end

function Genetics:updateGrowth()
    local age = common.util.getHoursPassed() - self:getBirthTime()
    if self:isBaby() then
        if age > self.animal.animalType.hoursToMature then
            logger:debug("No longer a baby, turn into an adult")
            self:setIsBaby(false)
            -- if not self:getName() then
            --     self:setName(self.reference.object.name)
            -- end
            self.animal.reference.scale = 1
        else
            --map scale to age
            local newScale = math.remap(age, 0,  self.animal.animalType.hoursToMature, self.animal.animalType.babyScale, 1)
            self.animal.reference.scale = newScale
        end
        self.animal.stats:setStats()
    end
end


return Genetics