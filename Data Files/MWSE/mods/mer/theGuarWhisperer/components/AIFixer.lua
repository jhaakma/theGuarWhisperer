
local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("AIFixer")

---@class GuarWhisperer.AIFixer.Animal.refData

---@class GuarWhisperer.AIFixer.Animal : GuarWhisperer.Animal
---@field refData GuarWhisperer.AIFixer.Animal.refData

---@class GuarWhisperer.AIFixer
---@field animal  GuarWhisperer.AIFixer.Animal
local AIFixer = {}

---@param animal  GuarWhisperer.AIFixer.Animal
---@return GuarWhisperer.AIFixer
function AIFixer.new(animal)
    local self = setmetatable({}, { __index = AIFixer })
    self.animal = animal
    return self
end

--- If too far away, AI FOllow won't work,
--- so make it invisible and teleport it to the player,
--- then teleport it back after a frame and make it visible again...
---
function AIFixer:resetFollow()
    timer.delayOneFrame(function()timer.delayOneFrame(function()
        if self.animal:distanceFrom(tes3.player) > 500 then
            local lastKnownPosition = self.animal.reference.position:copy()
            local lastKnownCell = self.animal.reference.cell
            local lanternOn = self.animal.lantern:isOn()
            if lanternOn then
                -- Disable lantern so the player doesn't notice lighting changes
                self.animal.lantern:turnLanternOff()
            end
            -- Make guar invisble while we sneakily move it to the player
            self.animal.reference.sceneNode.appCulled = true
            -- Teleport to the player to trigger AI Follow
            tes3.positionCell{
                cell = tes3.player.cell,
                orientation = self.animal.reference.orientation,
                position = tes3.player.position,
                reference = self.animal.reference,
            }
            -- Wait a frame
            timer.delayOneFrame(function()
                -- Then return to where it was
                tes3.positionCell{
                    cell = lastKnownCell,
                    orientation = self.animal.reference.orientation,
                    position = lastKnownPosition,
                    reference = self.animal.reference,
                }
                -- make visible and turn lights back on
                self.animal.reference.sceneNode.appCulled = false
                if lanternOn then
                    self.animal.lantern:turnLanternOn()
                end
            end)
        end
    end)end)
end

local function createContainer()
    ---@type tes3container
    local obj = tes3.createObject {
        id = "tgw_cont_lightfix",
        objectType = tes3.objectType.container,
        getIfExists = true,
        name = "Light Fix",
        mesh = [[EditorMarker.nif]],
        capacity = 10000
    }
    local ref = tes3.createReference {
        object = obj,
        position = tes3.player.position,
        orientation = tes3.player.orientation,
        cell = tes3.player.cell
    }
    ref.sceneNode.appCulled = true
    return ref
end

function AIFixer:fixSoundBug()
    if self.animal.reference.mobile.inCombat then return end
    local playingAttackSound =
           tes3.getSoundPlaying{ sound = "SwishL", reference = self.animal.reference }
        or tes3.getSoundPlaying{ sound = "SwishM", reference = self.animal.reference }
        or tes3.getSoundPlaying{ sound = "SwishS", reference = self.animal.reference }
        or tes3.getSoundPlaying{ sound = "guar roar", reference = self.animal.reference }
    if playingAttackSound then
        logger:warn("AI Fix - fixing attack sound")
        tes3.removeSound{ reference = self.animal.reference, "SwishL"}
        tes3.removeSound{ reference = self.animal.reference, "SwishM"}
        tes3.removeSound{ reference = self.animal.reference, "SwishS"}
        tes3.removeSound{ reference = self.animal.reference, "guar roar"}
        local container = createContainer()
        --Transfer all lights, preserving item data, from guar to player
        for _, stack in pairs(self.animal.reference.object.inventory) do
            if stack.object.objectType == tes3.objectType.light then
                tes3.transferItem{
                    from = self.animal.reference,
                    to = container,
                    item = stack.object,
                    count = stack.count,
                    playSound = false,
                }
            end
        end
        --now transfer them all back after a frame
        timer.delayOneFrame(function()
            for _, stack in pairs(container.object.inventory) do
                if stack.object.objectType == tes3.objectType.light then
                    tes3.transferItem{
                        from = container,
                        to = self.animal.reference,
                        item = stack.object,
                        count = stack.count,
                        playSound = false,
                    }
                end
            end
            container:delete()
            --toggle lights to update scene effects etc
            if self.animal.lantern:isOn() then
                logger:debug("AI Fix - Toggling lantern")
                self.animal.lantern:turnLanternOff()
                self.animal.lantern:turnLanternOn()
            end
        end)
    end
end

return AIFixer