local Animal = require("mer.theGuarWhisperer.Animal")
local common = require("mer.theGuarWhisperer.common")

local function onEquipWhistle(e)
    if not common.getModEnabled() then
        common.log:trace("activateWhistle(): Mod disabled")
        return
    end
    if not ( e.item.id == common.fluteId ) then
        common.log:trace("activateWhistle(): Activated item not a whistle: %s", e.item.id)
    else
        common.log:trace("activateWhistle(): Found a whistle. Leaving menu mode: %s", e.item.id)
        tes3ui.leaveMenuMode()
        timer.delayOneFrame(function()
            local buttons = {}
            if tes3.player.cell.isInterior ~= true then
                common.iterateRefType("companion", function(ref)
                    local animal = Animal.get(ref)
                    if animal and animal:canBeSummoned() then
                        common.log:trace("activateWhistle(): %s can be summoned, adding to list", animal:getName())
                        table.insert(buttons, {
                            text = animal:getName(),
                            callback = function()
                                timer.delayOneFrame(function()
                                    tes3.playSound{ reference = tes3.player, sound = common.fluteSound, }
                                    animal:wait()
                                    timer.start{
                                        duration = 1,
                                        callback = function() animal:teleportToPlayer(400) end
                                    }
                                    common.fadeTimeOut( 0, 2, function()
                                        animal:playAnimation("pet")
                                        animal:follow()
                                    end)
                                end)
                            end
                        })
                    end
                end)
            else
                common.log:trace("In interior, whistle won't work")
            end

            if #buttons > 0 then
                common.log:trace("activateWhistle(): Found at least one companion, calling messageBox")
                table.insert(buttons, { text = "Cancel"})
                common.messageBox{
                    message = "Which guar do you want to call?",
                    buttons = buttons
                }
            else
                common.log:trace("activateWhistle(): No companions found, playing whistle sound")
                tes3.playSound{ reference = tes3.player, sound = common.fluteSound, }
            end
        end)
    end
end


event.register("equip", onEquipWhistle)