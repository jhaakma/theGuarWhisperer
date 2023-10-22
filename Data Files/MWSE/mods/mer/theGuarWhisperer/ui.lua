local Syntax = require("mer.theGuarWhisperer.components.Syntax")
local common = require("mer.theGuarWhisperer.common")

local UI = {}

UI.ids = {
    menu = "TheGuarWhisperer_menu",
    outerBlock = "TheGuarWhisperer_outerBlock",
    titleBlock = "TheGuarWhisperer_titleBlock",
    title = "TheGuarWhisperer_title",
    subtitle = "TheGuarWhisperer_subtitle",
    mainBlock = "TheGuarWhisperer_mainBlock",
    buttonsBlock = "TheGuarWhisperer_buttonsBlock",
    infoBlock = "TheGuarWhisperer_infoBlock",
    bottomBlock = "TheGuarWhisperer_bottomBlock",
    closeButton = "TheGuarWhisperer_closeButton",
}
UI.menuWidth = 200
UI.menuHeight = 200
UI.padding = 8

-- Register with Right Click Menu Exit
local RCME = include("mer.RightClickMenuExit")
if RCME then
    RCME.registerMenu{
        menuId = UI.ids.menu,
        buttonId = UI.ids.closeButton
    }
end

local function closeMenu()
    tes3ui.findMenu(UI.ids.menu):destroy()
    tes3ui.leaveMenuMode()
end

---@param animal GuarWhisperer.Animal
local function getSubtitleText(animal)
    return string.format("Level %d %s %s",
        animal.stats:getLevel(),
        animal.genetics:getGender(),
        animal.genetics:isBaby() and "(baby)" or ""
    )
end

---@param animal GuarWhisperer.Animal
local function getDescriptionText(animal)
    return string.format("%s %s. %s %s.",
        animal:getName(),
        animal.needs:getHappinessStatus().description,
        animal.syntax:getHeShe(),
        animal.needs:getTrustStatus().description
    )
end

---@param animal GuarWhisperer.Animal
function UI.showStatusMenu(animal)
    local menu = tes3ui.createMenu{ id = UI.ids.menu, fixedFrame = true }
    menu.visible = false
    menu.autoWidth = true
    menu.autoHeight = true
    tes3ui.enterMenuMode(UI.ids.menu)

    --Outer block
    local outerBlock = menu:createBlock{ id = UI.ids.outerBlock}
    do
        outerBlock.autoHeight = true
        outerBlock.autoWidth = true
        outerBlock.flowDirection = "top_to_bottom"

         --title block
        local titleBlock = outerBlock:createBlock{ id = UI.ids.titleBlock}
        do
            titleBlock.widthProportional = 1.0
            titleBlock.autoHeight = true
            titleBlock.paddingBottom = UI.padding
            titleBlock.flowDirection = "top_to_bottom"

            local titleText = animal:getName()
            local title = titleBlock:createLabel{ id = UI.ids.title, text = titleText }
            do
                title.absolutePosAlignX = 0.5
                title.color = tes3ui.getPalette("header_color")
            end

            local subtitleText = getSubtitleText(animal)
            do
                local subtitle = titleBlock:createLabel{ id = UI.ids.subtitle, text = subtitleText}
                subtitle.absolutePosAlignX = 0.5
            end

            local descriptionText = getDescriptionText(animal)
            local description = outerBlock:createLabel{text = descriptionText}
            description.wrapText = true
            description.justifyText = "center"
            description.widthProportional = 1.0
            description.maxWidth = 200
        end

        UI.createStatsBlock(outerBlock, animal, true)


    --Bottom Block close button
        local bottomBlock = outerBlock:createBlock{ id = UI.ids.bottomBlock }
        do
            bottomBlock.flowDirection = "left_to_right"
            bottomBlock.autoHeight = true
            bottomBlock.widthProportional = 1.0
            bottomBlock.childAlignX = 1.0

            local closeButton = bottomBlock:createButton{ id = UI.ids.closeButton, text = "Close"}
            closeButton.absolutePosAlignX = 1.0
            closeButton.borderAllSides = 2
            closeButton.borderTop = 7
            closeButton:register("mouseClick", closeMenu )
        end
    end



    --update and display after a frame so everything is where its fucking supposed to be
    timer.frame.delayOneFrame(function()
        menu.visible = true
        menu:updateLayout()
    end)
end


--Generic Tooltip with header and description
function UI.createTooltip(thisHeader, thisLabel)
    local tooltip = tes3ui.createTooltipMenu()

    local outerBlock = tooltip:createBlock({ id = "GuarWhisperer:outerBlock" })
    outerBlock.flowDirection = "top_to_bottom"
    outerBlock.paddingTop = 6
    outerBlock.paddingBottom = 12
    outerBlock.paddingLeft = 6
    outerBlock.paddingRight = 6
    outerBlock.width = 300
    outerBlock.autoHeight = true

    local headerText = thisHeader
    local headerLabel = outerBlock:createLabel({ id = "GuarWhisperer:header", text = headerText })
    headerLabel.autoHeight = true
    headerLabel.width = 285
    headerLabel.color = tes3ui.getPalette("header_color")
    headerLabel.wrapText = true
    --header.justifyText = "center"

    local descriptionText = thisLabel
    local descriptionLabel = outerBlock:createLabel({ id = "GuarWhisperer:description", text = descriptionText })
    descriptionLabel.autoHeight = true
    descriptionLabel.width = 285
    descriptionLabel.wrapText = true

    tooltip:updateLayout()
end

---@param parentBlock tes3uiElement
---@param animal GuarWhisperer.Animal
---@param inMenu boolean?
function UI.createStatsBlock(parentBlock, animal, inMenu)
       --Right side info
       local infoBlock = parentBlock:createBlock{ id = UI.ids.infoBlock }
       infoBlock.autoHeight = true
       infoBlock.autoWidth = true
       infoBlock.minWidth = 200
       infoBlock.flowDirection = "top_to_bottom"
       infoBlock.paddingAllSides = UI.padding

        local statData = {
            {
                label = "Health",
                description = "Feed your guar to restore its health.",
                current = animal.mobile.health.current,
                max = animal.mobile.health.base,
                color = { 1, 0, 0 }
            },
            {
                label = "Happiness",
                description = "A guar's happiness is determined by all other factors. Keep your guar well fed, pet it and play fetch occasionally. Happiness determines how quickly your guar will trust you.",
                current = animal.needs:getHappiness(),
                max = 100,
                color =  { 0.1, 0.9, 0.1}
            },

            {
                label = "Trust",
                description = "Built trust by spending time with a happy guar. The more your guar trusts you, the more commands you can give it.",
                current = animal.needs:getTrust(),
                max = 100,
                color = { 0.2, 0.1, 0.8 }
            },
            {
                label = "Hunger",
                description = "Guars love leafy greens. Keep your guar well feed to make them happy and healthy. Guars can eat from your hand, or you can command them to eat directly from a plant.",
                current = 100 - animal.needs:getHunger(),
                max = 100,
                color = { 0.1, 0.5, 0.5 }
            }
        }

        for _, stat in ipairs(statData) do
            local fillbar = infoBlock:createFillBar{
                current = stat.current,
                max = stat.max
            }
            fillbar.widthProportional = 1.0
            --fillbar.height = 10
            fillbar.widget.fillColor = stat.color
            if inMenu then
                local label = fillbar:findChild("PartFillbar_text_ptr")
                label.text = string.format("%s: %d/%d", stat.label, stat.current, stat.max)
                --fillbar:updateLayout()
            else
                fillbar.height = 10
                fillbar.widget.showText = false
            end

            fillbar:register("help", function()
                local header = stat.label
                local description = stat.description
                UI.createTooltip(header, description)
            end)
        end


       local doStats = false
       if doStats then
        infoBlock:createDivider()

        for attrName, attribute in pairs(tes3.attribute) do
            local attrBlock = infoBlock:createBlock()
            attrBlock.flowDirection = "left_to_right"
            attrBlock.absolutePosAlignX = 1.0
            attrBlock.autoHeight = true

            attrBlock:createLabel{ text = Syntax.capitaliseFirst(attrName) }
            local value = tostring(animal.mobile.attributes[attribute + 1].current)
            local valueLabel =attrBlock:createLabel{ text = value }
            valueLabel.absolutePosAlignX = 1.0
        end
    end
end


return UI