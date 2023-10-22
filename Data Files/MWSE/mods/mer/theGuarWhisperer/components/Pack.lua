local common = require("mer.theGuarWhisperer.common")
local logger = common.log

---@class GuarWhisperer.Pack.Animal.refData
---@field hasPack boolean has a backpack equipped

---@class GuarWhisperer.Pack.Animal : GuarWhisperer.Animal
---@field refData GuarWhisperer.Pack.Animal.refData

---@class GuarWhisperer.Pack
---@field animal GuarWhisperer.Pack.Animal
local Pack = {}

---@param animal GuarWhisperer.Pack.Animal
---@return GuarWhisperer.Pack
function Pack.new(animal)
    local self = setmetatable({}, { __index = Pack })
    self.animal = animal
    return self
end

function Pack:hasPackItem(packItem)
    local isDead = self.animal:isDead()
    local itemEquipped
    --No items associated, base off pack
    if not packItem.items or #packItem.items == 0 then
        packItem = common.packItems.pack
    end
    --While alive, no pack in inventory, base off hasPack
    if packItem == common.packItems.pack then
        if not isDead then
            itemEquipped = self.animal.refData.hasPack
        end
    end
    --iterate over items
    for _, item in ipairs(packItem.items) do
        if self.animal.reference.object.inventory:contains(item) then
            itemEquipped = true
        end
    end
    if itemEquipped then
        --If item equipped, we also need to check the pack is equipped
        if packItem == common.packItems.pack then
            return true
        end
        return self:hasPackItem(common.packItems.pack)
    else
        return false
    end
end


function Pack:equipPack()
    if not self.animal.reference.context or not self.animal.reference.context.Companion then
        logger:error("[Guar Whisperer] Attempting to give pack to guar with no Companion var")
    end
    self.animal.reference.context.companion = 1
    tes3.removeItem{
        reference = tes3.player,
        item = common.packId,
        playSound = true
    }
    self.animal.refData.hasPack = true
    self.animal:setSwitch()
end

function Pack:unequipPack()
    if self.animal.reference.context and self.animal.reference.context.Companion then
        self.animal.reference.context.companion = 0
    end
    for _, stack in pairs(self.animal.reference.object.inventory) do
        tes3.transferItem{
            from = self.animal.reference,
            to = tes3.player,
            item = stack.object,
            count = stack.count or 1,
            playSound=false
        }
    end
    tes3.addItem{
        reference = tes3.player,
        item = common.packId,
        playSound = true
    }
    self.animal.refData.hasPack = false
    self.animal:setSwitch()
end

function Pack:canEquipPack()
    return self.animal.refData.hasPack ~= true
        and tes3.player.object.inventory:contains(common.packId)
        and self.animal.needs:hasSkillReqs("pack")
end

function Pack:hasPack()
    return self.animal.refData.hasPack == true
end




return Pack