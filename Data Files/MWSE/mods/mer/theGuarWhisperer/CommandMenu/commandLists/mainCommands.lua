local Animal = require("mer.theGuarWhisperer.Animal")
local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("mainCommands")
local this = {}
this.getTitle = function(e)
    ---@type GuarWhisperer.Animal
    local animal = e.activeCompanion
    return string.format("Command %s", animal:getName())
end
this.commands = {

  --Priority 1: specific ref commands
  {
    --CHARM
    label = function(e)
        return string.format("Charm %s", e.targetData.reference.object.name)
    end,
    description = "Attempt to charm the target, increasing their disposition.",
    command = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        if animal:attemptCommand(80, 90) then
            animal:moveToAction(e.targetData.reference, "charm")
        end
    end,
    requirements = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        if not ( e.targetData and e.targetData.reference ) then return false end
        local targetObj = e.targetData.reference.baseObject or
            e.targetData.reference.object

        return targetObj and
            targetObj.objectType == tes3.objectType.npc
            and animal.needs:hasSkillReqs("charm")
    end
},
{
    --ATTACK
    label = function(e)
        return string.format("Attack %s", e.targetData.reference.object.name)
    end,
    description = "Attacks the selected target.",
    command = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        if animal:attemptCommand(50, 80) then
            animal:setAttackPolicy("defend")
            animal:attack(e.targetData.reference)
        end
    end,
    requirements = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        local targetMobile = e.targetData.reference
            and e.targetData.reference.mobile
        --Has target
        if not targetMobile then
            return false
        end
        --Target is alive
        if targetMobile.health.current < 1 then
            return false
        end
        --Target isn't friendly
        ---@param actor tes3mobileActor
        for actor in tes3.iterate(tes3.mobilePlayer.friendlyActors) do
            if actor.reference == e.targetData.reference then
                return false
            end
        end
        --Target isn't another companion
        if Animal.get(e.targetData.reference) then
            return false
        end
        --Has prerequisites for attack command
        if not animal.needs:hasSkillReqs("attack") then
            return false
        end
        --Not passive
        if animal.refData.attackPolicy == "passive" and not tes3.mobilePlayer.inCombat then
             return false
        end
        return true
    end
},

{
    --EAT
    label = function(e)
        return string.format("Eat %s", e.targetData.reference.object.name)
    end,
    description = "Eat the selected item or plant.",
    command = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        if animal:attemptCommand(40, 80) then
            animal:moveToAction(e.targetData.reference, "eat")
        end
    end,
    requirements = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        return animal
            and (not animal:hasCarriedItems())
            and e.targetData.reference ~= nil
            and animal:canEat(e.targetData.reference)
            and animal.needs:hasSkillReqs("eat")
    end
},
{
    --HARVEST
    label = function(e)
        return string.format("Harvest %s", e.targetData.reference.object.name)
    end,
    description = "Harvest the selected plant.",
    command = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        if animal:attemptCommand(50, 80) then
            animal:moveToAction(e.targetData.reference, "harvest")
        end
    end,
    requirements = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        return animal:canHarvest(e.targetData.reference)
            and tes3.hasOwnershipAccess{ target = e.targetData.reference }
            and animal.needs:hasSkillReqs("fetch")
    end
},
{
    --FETCH
    label = function(e)
        return string.format("Fetch %s", e.targetData.reference.object.name)
    end,
    description = "Bring the selected item back to the player.",
    command = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        if animal:attemptCommand(50, 80) then
            animal:moveToAction(e.targetData.reference, "fetch")
        end
    end,
    requirements = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        return animal:canFetch(e.targetData.reference)
            and tes3.hasOwnershipAccess{ target = e.targetData.reference }
            and animal.needs:hasSkillReqs("fetch")
    end
},
{
    --STEAL
    label = function(e)
        return string.format("Steal %s", e.targetData.reference.object.name)
    end,
    description = "Steal the selected item and bring it back to the player. Dont get caught!",
    command = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        if animal:attemptCommand(60, 90) then
            animal:moveToAction(e.targetData.reference, "fetch")
        end
    end,
    requirements = function(e)
        ---@type GuarWhisperer.Animal
        local animal = e.activeCompanion
        return (not animal:hasCarriedItems())
            and animal:canFetch(e.targetData.reference)
            and (not tes3.hasOwnershipAccess{ target = e.targetData.reference })
    end,
    doSteal = true
},

    --priority 4: close-up commands
    {
        --PET
        label = function()
            return "Pet"
        end,
        description = "Pet your guar to increase its happiness.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal:pet()
        end,
        requirements = function(e)
            return e.inMenu
        end,
        delay = 1.5
    },
    {
        --FEED
        label = function()
            return "Feed"
        end,
        description = "Feed your guar something from your inventory.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal.hunger:feed()
        end,
        requirements = function(e)
            return e.inMenu
        end,
        delay = 1.5
    },
    {
        --FOLLOW PLAYER
        label = function()
            return "Follow me"
        end,
        description = "Start following the player.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            if animal:attemptCommand(50, 70) then
                tes3.messageBox("Following")
                animal:returnTo()
            end
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            logger:debug("Ai state: %s", animal:getAI() )
            return (e.targetData.intersection == nil or e.targetData.reference )
                and animal:getAI() ~= "following"
                and animal.needs:hasSkillReqs("follow")
        end
    },

    {
        --MOVE
        label = function()
            return "Move"
        end,
        description = "Move to the selected location.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            if animal:attemptCommand(50, 70) then
                tes3.messageBox("%s moving to location", animal:getName())
                animal:moveTo(e.targetData.intersection)
            end
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return e.targetData.intersection ~= nil
                and (not e.targetData.reference)
                and animal.needs:hasSkillReqs("follow")
        end
    },

    {
        --WAIT
        label = function()
            return "Wait"
        end,
        description = "Wait here.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            if animal:attemptCommand(30, 60) then
                tes3.messageBox("Waiting")
                animal:wait()
            end
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return  (e.targetData.intersection == nil or e.targetData.reference)
                and animal:getAI() ~= "waiting"
        end
    },

    {
        --WANDER
        label = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return "Wander"
        end,
        description = "Wander around the area.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            tes3.messageBox("Wandering")
            animal:wander()
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return (e.targetData.intersection == nil or e.targetData.reference)
                and animal:getAI() ~= "wandering"
        end
    },
    {
        --Position on top of player to break collision
        label = function()
            return "Let me pass"
        end,
        description = "Positions the guar on top of the player, breaking collision and allowing you to move past it.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            timer.delayOneFrame(function()
                tes3.positionCell{
                    reference = animal.reference,
                    position = tes3.player.position,
                    cell = tes3.player.cell
                }
            end)
        end,
        requirements = function(e)
            return e.inMenu
        end,
        delay = 0.1,
    },

    --priority 5: uncommon movement commands

    {
        --EQUIP PACK
        label = function()
            return "Equip pack"
        end,
        description = "Equip a backpack to enable companion share.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal.pack:equipPack()
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return e.inMenu and animal.pack:canEquipPack()
        end,
        delay = 0.1,
    },
    {
        --UNEQUIP PACK
        label = function()
            return "Unequip pack"
        end,
        description = "Unequip the guar's backpack.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal.pack:unequipPack()
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return ( e.inMenu and animal.pack:hasPack() )
        end,
        delay = 0.1,
    },

    {
        --Pacify
        label = function()
            return "Pacify"
        end,
        description = "Stop your guar from engaging in combat.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal:setAttackPolicy("passive")
            tes3.messageBox("%s will no longer engage in combat.", animal:getName())
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return ( e.inMenu and animal:getAttackPolicy() ~= "passive" )
        end
    },
    {
        --Defend
        label = function()
            return "Defend"
        end,
        description = "Your guar will defend you in combat.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            if animal:attemptCommand(40, 60) then
                animal:setAttackPolicy("defend")
                tes3.messageBox("%s will now defend you in battle.", animal:getName())
            end
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return ( e.inMenu and animal:getAttackPolicy() ~= "defend" )
        end
    },

    --priority 6: uncommon up-close commands
    {
        --BREED
        label = function(e)
            return "Breed"
        end,
        description = "Breed with another guar to make a baby guar.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            if animal:attemptCommand(80, 90) then
                local animal = e.activeCompanion
                animal.genetics:breed()
            end
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return e.inMenu
                and animal.genetics:getCanConceive()
        end,
        delay = 1.0,
    },
    {
        --RENAME
        label = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return "Rename"
        end,
        description = "Rename your guar",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal:rename()
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return e.inMenu
        end,
        delay = 0.1,
    },
    {
        --GET STATUS
        label = function(e)
            return "Get status"
        end,
        description = "Check the health, happiness, trust and hunger of your guar.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal:getStatusMenu()
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return e.inMenu
        end,
        delay = 0.1,
    },

    {
        --GO HOME
        label = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return string.format("Go home (%s)",
                tes3.getCell{ id = animal.refData.home.cell} )
        end,
        description = "Send your guar back to their home location.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            if animal:attemptCommand(50, 70) then
                animal:goHome()
            end
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return (
                e.inMenu and
                animal:getHome() and
                animal.needs:hasSkillReqs("follow")
            )
        end,
        delay = 0.1,
    },

    {
        --TAKE ME HOME
        label = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return string.format("Take me home (%s: %s)",
                tes3.getCell{ id = animal.refData.home.cell},
                animal:getTravelTimeText()
            )
        end,
        description = "Ride your guar back to its home location.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            if animal:attemptCommand(50, 80) then
                animal:goHome{ takeMe = true }
            end
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return e.inMenu
                and animal:getHome()
                and animal.needs:hasSkillReqs("follow")
                and not animal.genetics:isBaby()
        end,
        delay = 0.1,
    },

    {
        --SET HOME
        label = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return string.format("Set home (%s)", animal.reference.cell )
        end,
        description = "Set the guar's current location as their home point.",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            animal:setHome(
                animal.reference.position,
                animal.reference.cell
            )
        end,
        requirements = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return ( e.inMenu and animal.needs:hasSkillReqs("follow") )
        end,
        delay = 0.1,
    },
    {
        --CANCEL
        label = function(e)
            return "Cancel"
        end,
        description = "Exit menu",
        command = function(e)
            ---@type GuarWhisperer.Animal
            local animal = e.activeCompanion
            return true
        end,
        requirements = function(e) return true end
    },
}
return this