local Animal = require("mer.theGuarWhisperer.Animal")

event.register("UIEXP:sandboxConsole", function(e)
    e.sandbox.guarWhisperer = {
        Animal = Animal,
        getCurrent = function()
            return Animal.get(e.sandbox.currentRef)
        end
    }
end)