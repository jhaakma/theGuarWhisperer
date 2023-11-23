local Action = require("mer.theGuarWhisperer.abilities.Action")
local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("charm")

local Charm = {}


---@param guar GuarWhisperer.GuarCompanion
function Charm.getCharmModifier(guar)
    local personality = guar.stats:getAttribute("personality").current
    return math.log10(personality) * 20
end

function Charm.charm(guar, ref)
    if not ref.mobile then
        logger:warn("%s does not have a mobile", ref.object.id)
        return
    end
    if tes3.persuade{ actor = ref, Charm.getCharmModifier(guar) } then
        tes3.messageBox("%s successfully charmed %s.", guar:getName(), ref.object.name)
    else
        tes3.messageBox("%s failed to charm %s.", guar:getName(), ref.object.name)
    end
end


return Charm