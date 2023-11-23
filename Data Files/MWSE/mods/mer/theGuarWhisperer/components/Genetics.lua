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

---@class GuarWhisperer.Genetics.GuarCompanion : GuarWhisperer.GuarCompanion
---@field refData GuarWhisperer.Genetics.GuarCompanion.refData

---This component deals with genetics and breeding
---@class GuarWhisperer.Genetics
---@field guar GuarWhisperer.Genetics.GuarCompanion
local Genetics = {}

---@param guar GuarWhisperer.Genetics.GuarCompanion
---@return GuarWhisperer.Genetics
function Genetics.new(guar)
    local self = setmetatable({}, { __index = Genetics })
    self.guar = guar
    return self
end

function Genetics:isBaby()
    return self.guar.refData.isBaby
end

---@param isBaby boolean
function Genetics:setIsBaby(isBaby)
    self.guar.refData.isBaby = isBaby
end

---@return GuarWhisperer.Gender
function Genetics:getGender()
    if not self.guar.refData.gender then
        self.guar.refData.gender = math.random() < 0.55 and "male" or "female"
    end
    return self.guar.refData.gender
end

---Sets birth time to now
function Genetics:setBirthTime()
    self.guar.refData.birthTime = common.util.getHoursPassed()
end

---Gets the time this guar was born
---@return number
function Genetics:getBirthTime()
    return self.guar.refData.birthTime or common.util.getHoursPassed()
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
        self.guar.stats:setBaseAttribute(attributeName, finalValue)
    end
    self.guar.stats:setStats()
end

function Genetics:randomiseGenes()
    logger:debug("Randomising genes")
    --For converting guars, we get its genetics by treating itself as its parents
    --Which randomises its attributes, then updateGrowth should apply to the object
    self:inheritGenes(self.guar, self.guar)
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
    if not self.guar.animalType.breedable then return false end
    if not ( self.guar.refData.gender == "female" ) then return false end
    if self:isBaby() then return false end
    if not self.guar.mobile.hasFreeAction then return false end
    if self.guar.needs:getTrust() < moodConfig.skillRequirements.breed then return false end
    if self.guar.refData.lastBirthed then
        local now = common.util.getHoursPassed()
        local hoursSinceLastBirth = now - self.guar.refData.lastBirthed
        local enoughTimePassed = hoursSinceLastBirth > self.guar.animalType.birthIntervalHours
        if not enoughTimePassed then return false end
    end
    return true
end

---@param guar GuarWhisperer.Genetics.GuarCompanion|GuarWhisperer.GuarCompanion
function Genetics:canBeImpregnatedBy(guar)
    if not guar.animalType.breedable then return false end
    if not (guar.refData.gender == "male" ) then return false end
    if guar.genetics:isBaby() then return false end
    if not guar.mobile.hasFreeAction then return false end
    if self.guar.needs:getTrust() < moodConfig.skillRequirements.breed then return false end
    local distance = guar:distanceFrom(self.guar.reference)
    if distance > 1000 then
        return false
    end
    return true
end

function Genetics:breed()
    --Find nearby guar
    ---@type GuarWhisperer.GuarCompanion[]
    local partnerList = {}

    self.guar.referenceManager:iterateReferences(function(_, guar)
        if self:canBeImpregnatedBy(guar) then
            table.insert(partnerList, guar)
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
                    if not self.guar:isValid() then return end
                    self.guar.refData.lastBirthed  = common.util.getHoursPassed()
                    local babyObject = common.createCreatureCopy(self.guar.reference.baseObject)
                    babyObject.name = string.format("%s Jr", self.guar:getName())
                    local babyRef = tes3.createReference{
                        object = babyObject,
                        position = self.guar.reference.position,
                        orientation =  {
                            self.guar.reference.orientation.x,
                            self.guar.reference.orientation.y,
                            self.guar.reference.orientation.z,
                        },
                        cell = self.guar.reference.cell,
                        scale = self.guar.animalType.babyScale
                    }
                    timer.delayOneFrame(function()
                        if not self.guar:isValid() then return end
                        self.guar.initialiseRefData(babyRef, self.guar.animalType)
                        baby = self.guar:new(babyRef)
                        if baby then
                            baby.genetics:setIsBaby(true)
                            baby.needs:setTrust(self.guar.animalType.trust.babyLevel)
                            baby.genetics:setBirthTime()
                            --baby:inheritGenes(self, partner)
                            baby.genetics:updateGrowth()
                            baby:setAttackPolicy("passive")
                            baby.ai:wander()
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
        ---@param partner GuarWhisperer.GuarCompanion
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
            message = string.format("Which partner would you like to breed %s with?", self.guar:getName() ),
            buttons = buttons
        }
    else
        tes3.messageBox("There are no valid partners nearby.")
    end
end

function Genetics:updateGrowth()
    local age = common.util.getHoursPassed() - self:getBirthTime()
    if self:isBaby() then
        if age > self.guar.animalType.hoursToMature then
            logger:debug("No longer a baby, turn into an adult")
            self:setIsBaby(false)
            -- if not self:getName() then
            --     self:setName(self.reference.object.name)
            -- end
            self.guar.reference.scale = 1
        else
            --map scale to age
            local newScale = math.remap(age, 0,  self.guar.animalType.hoursToMature, self.guar.animalType.babyScale, 1)
            self.guar.reference.scale = newScale
        end
        self.guar.stats:setStats()
    end
end


return Genetics