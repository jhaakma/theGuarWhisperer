local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("Hunger")

---@class GuarWhisperer.Hunger.Animal.refData

---@class GuarWhisperer.Hunger.Animal : GuarWhisperer.Animal

---@class GuarWhisperer.Hunger
---@field animal GuarWhisperer.Hunger.Animal
---@field refData GuarWhisperer.Hunger.Animal.refData
local Hunger = {}

function Hunger.new(animal)
    local self = setmetatable({}, { __index = Hunger })
    self.animal = animal
    return self
end

function Hunger:feed()
    timer.delayOneFrame(function()
        if not self.animal:isValid() then return end
        tes3ui.showInventorySelectMenu{
            reference = tes3.player,
            title = string.format("Feed %s", self.animal:getName()),
            noResultsText = string.format("You do not have any appropriate food."),
            filter = function(e)
                logger:trace("Filter: checking: %s", e.item.id)
                for id, value in pairs(self.animal.animalType.foodList) do
                    logger:trace("%s: %s", id, value)
                end
                return (
                    e.item.objectType == tes3.objectType.ingredient and
                    self.animal.animalType.foodList[string.lower(e.item.id)] ~= nil
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

function Hunger:processFood(amount)
    self.animal.needs:modHunger(amount)

    --Eating restores health as a % of base health
    local healthCurrent = self.animal.mobile.health.current
    local healthMax = self.animal.mobile.health.base
    local difference = healthMax - healthCurrent
    local healthFromFood = math.remap(
        amount,
        0, 100,
        0, healthMax
    )
    healthFromFood = math.min(difference, healthFromFood)
    tes3.modStatistic{
        reference = self.animal.reference,
        name = "health",
        current = healthFromFood
    }

    --Before guar is willing to follow, feeding increases trust
    if not self.animal.needs:hasSkillReqs("follow") then
        self.animal.needs:modTrust(3)
    end
end

function Hunger:eatFromInventory(item, itemData)
    event.trigger("GuarWhisperer:EatFromInventory", { item = item, itemData = itemData })
    --remove food from player
    tes3.player.object.inventory:removeItem{
        mobile = tes3.mobilePlayer,
        item = item,
        itemData = itemData or nil
    }
    tes3ui.forcePlayerInventoryUpdate()

    self:processFood(self.animal.animalType.foodList[string.lower(item.id)])

    --visuals/sound
    self.animal:playAnimation("eat")
    self.animal:takeAction(2)
    local itemId = item.id
    timer.start{
        duration = 1,
        callback = function()
            if not self.animal:isValid() then return end
            event.trigger("GuarWhisperer:AteFood", { reference = self.animal.reference, itemId = itemId }  )
            tes3.playSound{ reference = self.animal.reference, sound = "Swallow" }
            tes3.messageBox(
                "%s gobbles up the %s.",
                self.animal:getName(), string.lower(item.name)
            )
        end
    }
end

return Hunger
