
local Animal = require("mer.theGuarWhisperer.Animal")
local common = require("mer.theGuarWhisperer.common")

local function isBall(reference)
    return string.lower(reference.object.id) == common.ballId
end

local function guarFollow(ball)
    ---@param actor tes3mobileActor
    for actor in tes3.iterate(tes3.mobilePlayer.friendlyActors) do
        local animal = Animal.get(actor.reference)
        if animal then
            animal:moveToAction(ball, "fetch")
            return
        end
    end
end

local function placeBall(ref, position)
    local ball = tes3.createReference{
        object = ref.object,
        position = position,
        orientation =  {0,0,0},
        cell = ref.cell or tes3.player.cell,
    }

    local ray = tes3.rayTest{
        position = position,
        direction = tes3vector3.new(0, 0, -1)
    }
    if ray and ray.intersection then
        ball.position = tes3vector3.new(
            ray.intersection.x,
            ray.intersection.y,
            ray.intersection.z + 7)
    end
    guarFollow(ball)
end


local function onHitActor(e)
    if isBall(e.mobile.reference) then
        return false
    end
end

local function onHitObject(e)
    if isBall(e.mobile.reference) then
        return false
    end
end

local function onHitTerrain(e)
    if isBall(e.mobile.reference) then
        return false
    end
end


local function onProjectileExpire(e)
    if isBall(e.mobile.reference) then
        local position = {
            e.mobile.reference.position.x,
            e.mobile.reference.position.y,
            e.mobile.reference.position.z + 15
        }
        placeBall(e.mobile.reference, position)
    end
end

event.register("projectileHitActor", onHitActor, {priority = 100 })
event.register("projectileHitObject", onHitObject, {priority = 100 })
event.register("projectileHitTerrain", onHitTerrain, {priority = 100 })

event.register("projectileExpire", onProjectileExpire)