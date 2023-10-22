
local Animal = require("mer.theGuarWhisperer.Animal")
local common = require("mer.theGuarWhisperer.common")

local function isBall(reference)
    return common.balls[reference.id:lower()]
end

local function guarFollow(ball)
    local validAnimals = {}
    ---@param animal GuarWhisperer.Animal
    Animal.referenceManager:iterateReferences(function(_, animal)
        local moving = animal:getAI() == "moving"
        local mouthEmpty = (not animal:hasItems())
        local closeToBall = animal:distanceFrom(ball) < 1000
        local closeToPlayer = animal:distanceFrom(tes3.player) < 500
        if mouthEmpty and (closeToBall or closeToPlayer) and (not moving) then
            table.insert(validAnimals, animal)
        end
    end)
    if #validAnimals == 0 then return end
    local chosenAnimal = table.choice(validAnimals)
    chosenAnimal:moveToAction(ball, "fetch")
end

local function placeBall(ref, position)
    local ray = tes3.rayTest{
        position = tes3vector3.new(
            position.x,
            position.y,
            position.z + 5
        ),
        direction = tes3vector3.new(0, 0, -1)
    }
    if ray and ray.intersection then
        position = tes3vector3.new(
            ray.intersection.x,
            ray.intersection.y,
            ray.intersection.z + 5)
    end
    local ball = tes3.createReference{
        object = ref.object,
        position = position,
        orientation =  {0,0,0},
        cell = ref.cell or tes3.player.cell,
    }
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
        local position = tes3vector3.new(
            e.mobile.reference.position.x,
            e.mobile.reference.position.y,
            e.mobile.reference.position.z + 15)
        placeBall(e.mobile.reference, position)
    end
end

event.register("projectileHitActor", onHitActor, {priority = 100 })
event.register("projectileHitObject", onHitObject, {priority = 100 })
event.register("projectileHitTerrain", onHitTerrain, {priority = 100 })

event.register("projectileExpire", onProjectileExpire)