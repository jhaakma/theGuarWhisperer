--[[
    Handles events and player input for command menu
]]

local common = require("mer.theGuarWhisperer.common")
local commandMenu = require("mer.theGuarWhisperer.CommandMenu.CommandMenuModel")


--check if activate key is down
local function didPressActivate()
    local inputController = tes3.worldController.inputController
    return inputController:keybindTest(tes3.keybind.activate)
end

--Check if toggle key is down
local function didPressToggleKey(e)
    local config = common.getConfig()
    return (
        config.commandToggleKey and
        e.keyCode == config.commandToggleKey.keyCode and
        not not e.isShiftDown == not not config.commandToggleKey.isShiftDown and
        not not e.isControlDown == not not config.commandToggleKey.isControlDown and
        not not e.isAltDown == not not config.commandToggleKey.isAltDown
    )
end

local function hasModifierPressed()
    local inputController = tes3.worldController.inputController
    local pressedModifier = inputController:isKeyDown(tes3.scanCode.lShift)
    common.log:debug("Pressed modifier? %s", pressedModifier)
    return pressedModifier
end


local function onKeyPress(e)
    if tes3.menuMode() then
        return
    end
    --Pressed Activate
    if didPressActivate() then

        if commandMenu.activeCompanion then
            --can activate as long as we aren't looking at another reference
            local target = tes3.getPlayerTarget()
            if target == nil or target == commandMenu.activeCompanion.reference then
                commandMenu:performAction()
            end
        end
    else
        --Check if Command button was pressed
       if didPressToggleKey(e) then
            return commandMenu:toggleCommandMenu()
        end
    end
end
event.register("keyDown", onKeyPress)



local function onMouseWheelChanged(e)
    if not common.data then return end
    if tes3ui.menuMode() then return end
    if commandMenu.activeCompanion then
        if e.delta < 0 then
            commandMenu:scrollUp()
        else
            commandMenu:scrollDown()
        end
    end
end
event.register("mouseWheel", onMouseWheelChanged)

local function activateMenu(e)
    common.log:debug("activating menu")
    if hasModifierPressed() then
        e.animal.pack:takeItemLookingAt()
    else
        commandMenu:showCommandMenu(e.animal)
    end
end
event.register("TheGuarWhisperer:showCommandMenu", activateMenu)

--Allow exiting of command menu
local function onMouseButtonDown(e)
    if e.button == tes3.worldController.inputController.inputMaps[19].code then
        commandMenu:destroy()
    end
end
event.register("mouseButtonDown", onMouseButtonDown)