local common = require("mer.theGuarWhisperer.common")
local logger = common.log
local NodeManager = require("mer.theGuarWhisperer.services.SceneNode.NodeManager")

---@class GuarWhisperer.Pack.Animal.refData
---@field hasPack boolean has a backpack equipped
---@field triggerDialog boolean

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
    --No items associated, base off pack
    if not packItem.items or #packItem.items == 0 then
        return true
    end
    for _, item in ipairs(packItem.items) do
        if self.animal.reference.object.inventory:contains(item) then
            return true
        end
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
    self:setSwitch()
    NodeManager.registeredNodeManagers["GuarWhisperer_PackNodes"]:processReference(self.animal.reference)
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
    self:setSwitch()
    NodeManager.registeredNodeManagers["GuarWhisperer_PackNodes"]:processReference(self.animal.reference)
end

function Pack:canEquipPack()
    return self.animal.refData.hasPack ~= true
        and tes3.player.object.inventory:contains(common.packId)
        and self.animal.needs:hasSkillReqs("pack")
end

function Pack:hasPack()
    return self.animal.refData.hasPack == true
end

function Pack:setSwitch()

    if not self.animal.reference.sceneNode then return end
    if not self.animal.reference.mobile then return end

    NodeManager.registeredNodeManagers["GuarWhisperer_PackNodes"]:processReference(self.animal.reference)


    local animState = self.animal.reference.mobile.actionData.animationAttackState

    --don't update nodes during dying animation
    --if health <= 0 and animState ~= tes3.animationState.dead then return end
    if animState == tes3.animationState.dying then return end

    -- for _, packItem in pairs(common.packItems) do
    --     local node = self.animal.reference.sceneNode:getObjectByName(packItem.id)

    --     if node then
    --         node.switchIndex = self:hasPackItem(packItem) and 1 or 0
    --         if self:hasPack() and common.getConfig().displayAllGear and packItem.dispAll then
    --             node.switchIndex =  1
    --         end

    --         --switch has changed, add or remove item meshes
    --         if packItem.attach then
    --             if packItem.light then
    --                 --attach item
    --                 local onNode = node.children[2]
    --                 local lightParent = onNode:getObjectByName("ATTACH_LIGHT")
    --                 local lanternParent = self.animal.reference.sceneNode:getObjectByName("LANTERN")

    --                 if node.switchIndex == 1 then
    --                     local itemHeld = self.animal:getItemFromInventory(packItem)

    --                      --Add actual light

    --                     --Check if its a different light, remove old one
    --                     local sameLantern
    --                     if lanternParent.children and lanternParent.children[1] ~= nil then
    --                         local currentLanternId = lanternParent.children[1].name
    --                         if itemHeld.id == currentLanternId then
    --                             sameLantern = true
    --                         end
    --                     end

    --                     if sameLantern ~= true then
    --                         logger:debug("Changing lantern")
    --                         self.animal.lantern:detachLantern()
    --                         self.animal.lantern:attachLantern(itemHeld)

    --                         self.animal.lantern.addLight(lightParent, itemHeld)
    --                         --Attach the light
    --                         if self.animal.lantern:isOn() then
    --                             self.animal.lantern:turnLanternOn()
    --                         else
    --                             self.animal.lantern:turnLanternOff()
    --                         end
    --                     end
    --                 else
    --                     --detach item and light
    --                     if onNode:getObjectByName("LanternLight") then
    --                         self.animal.lantern:detachLantern()
    --                         self.animal.lantern:turnLanternOff()
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
end

local function findNamedParentNode(node, name)
    logger:debug("Searching for %s parent of node %s", name, node.name)
    local parent = node
    while parent do
        if parent.name == name then
            logger:info("Found parent %s", name)
            return parent
        end
        parent = parent.parent
    end
    return parent
end


function Pack:grabItem(nodeConfig)
    for itemId in pairs(nodeConfig:getItems(self.animal.reference)) do
        local inventory = self.animal.reference.object.inventory
        if inventory:contains(itemId) then
            logger:debug("Found %s in inventory", itemId)
            for _, stack in pairs(inventory) do
                if stack.object.id:lower() == itemId:lower() then
                    local count = stack.count
                    local itemData
                    if stack.variables and #stack.variables > 0 then
                        count = 1
                        itemData = stack.variables[1]
                    end
                    logger:debug("Item transferred successfully")
                    tes3.messageBox("Retrieved %s from pack.", stack.object.name)
                    tes3.transferItem{
                        from = self.animal.reference,
                        to = tes3.player,
                        item = stack.object.id,
                        itemData = itemData,
                        count = count
                    }
                    event.trigger("Ashfall:triggerPackUpdate")
                    return true
                end
            end
        end
    end
    return false
end


function Pack:takeItemLookingAt()
    logger:debug("takeItemLookingAt")
    local eyePos =  tes3.getPlayerEyePosition()
    local results = tes3.rayTest{
        position = eyePos,
        direction = tes3.getPlayerEyeVector(),
        ignore = { tes3.player },
        findAll = true,
        maxDistance = tes3.getPlayerActivationDistance()
    }
    if results then
        local nodeManager = NodeManager.registeredNodeManagers["GuarWhisperer_PackNodes"]
        ---@param nodeConfig GuarWhisperer.NodeManager.InventoryAttachNode
        for _, nodeConfig in ipairs(nodeManager.nodes) do
            for _, result in ipairs(results) do
                if result and result.object then
                    logger:debug("Ray hit %s", result.object.name)
                    if nodeConfig.getItems then
                        logger:info("Checking %s, has items", nodeConfig.id)
                        local node = result.object
                        local hitNode = findNamedParentNode(node, nodeConfig.id)

                        --Block if node is on the other side of the animal
                        if hitNode then
                            local distanceToIntersection = result.intersection:distance(eyePos)
                            local distanceToGuar = self.animal.reference.position:distance(eyePos)
                            if distanceToIntersection > distanceToGuar then
                                hitNode = false
                            end
                        end

                        if not hitNode then
                            logger:debug("Didn't find parent node %s", nodeConfig.id)
                        else
                            --if its a lantern, toggle instead of taking
                            if nodeConfig.id == "ATTACH_LANTERN" then
                                if self.animal.lantern:isOn() then
                                    self.animal.lantern:turnLanternOff{ playSound = true }
                                else
                                    self.animal.lantern:turnLanternOn{ playSound = true }
                                end
                                return
                            else
                                logger:debug("Grabbing %s from pack", nodeConfig.id)
                                if self:grabItem(nodeConfig) then
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
        self:setSwitch()
    end
    logger:debug("Entering pack")
    self.animal.refData.triggerDialog = true
    tes3.player:activate(self.animal.reference)
end

return Pack