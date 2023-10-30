local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("Integrations - nodes")
local Animal = require("mer.theGuarWhisperer.Animal")
local Lantern = require("mer.theGuarWhisperer.components.Lantern")
local NodeManager = require("CraftingFramework.nodeVisuals.NodeManager")
local SwitchNode = require("CraftingFramework.nodeVisuals.SwitchNode")
local AttachNode = require("CraftingFramework.nodeVisuals.InventoryAttachNode")
local ashfall = include("mer.ashfall.interop")

---@param reference tes3reference
local function isPackAnimal(reference)
    local animal = Animal.get(reference)
    return animal and animal.pack:hasPack()
end

local function getTentIds()
    local tents = {}
    if ashfall then
        if ashfall.getMiscTentIds then
            for _, id in ipairs(ashfall.getMiscTentIds()) do
                tents[id:lower()] = true
            end
        end
        if ashfall.getMiscTentCoverIds() then
            for _, id in ipairs(ashfall.getMiscTentCoverIds()) do
                tents[id:lower()] = true
            end
        end
    end
    return tents
end

---@return table<string, boolean>
local function getAxeIds()
    if ashfall and ashfall.getBackPackWoodAxeIds then
        return ashfall.getBackPackWoodAxeIds()
    end
    return {
        ashfall_woodaxe = true,
        ashfall_woodaxe_steel = true,
        ashfall_woodaxe_flint = true,
        ashfall_woodaxe_glass = true,
    }
end

local function getWoodIds()
    if ashfall and ashfall.getFirewoodIds then
        return ashfall.getFirewoodIds()
    else
        return {
            ashfall_firewood = true
        }
    end
end

local function isActivePackAnimal (_, e)
    return isPackAnimal(e.reference)
end

---@param reference tes3reference
---@param item tes3item
local function isCarryingItem(reference, item)
    local itemId = item.id:lower()
    local animal = Animal.get(reference)
    local carriedItems = animal and animal:getCarriedItems()
    if carriedItems then
        for _, carriedItem in pairs(carriedItems) do
            if carriedItem.id:lower() == itemId then
                return true
            end
        end
    end
    return false
end

local function itemValidNotCarrying(_, e)
    return not isCarryingItem(e.reference, e.item)
end

---@type CraftingFramework.NodeManager.SwitchNode.config[]
local switchConfigs = {
    {
        id = "SWITCH_PACK",
        getActiveIndex = function(self, e)
            local node = isPackAnimal(e.reference) and "ON" or "OFF"
            return self.getIndex(e.node, node)
        end
    },
    {
        id = "SWITCH_ACCESSORIES",
        getActiveIndex = function(self, e)
            local node = isPackAnimal(e.reference) and "ON" or "OFF"
            return self.getIndex(e.node, node)
        end
    },
}

---@type CraftingFramework.NodeManager.InventoryAttachNode.config[]
local attachConfigs = {
    {
        id = "ATTACH_TENT",
        getItems = getTentIds,
        isActive = isActivePackAnimal,
        itemValid = itemValidNotCarrying
    },
    {
        id = "ATTACH_AXE",
        getItems = getAxeIds,
        isActive = isActivePackAnimal,
        itemValid = itemValidNotCarrying,
        switchId = "SWITCH_AXE"
    },
    {
        id = "ATTACH_WOOD",
        getItems = getWoodIds,
        itemValid = itemValidNotCarrying,
        isActive = isActivePackAnimal,
        switchId = "SWITCH_WOOD"
    },
    {
        id = "ATTACH_LANTERN",
        getItems = Lantern.getLanternIds,
        itemValid = itemValidNotCarrying,
        isActive = isActivePackAnimal,
        switchId = "SWITCH_LANTERN",
        afterAttach = function(_, e, item )
            ---@cast item tes3light
            local animal = Animal.get(e.reference)
            if not animal then return end
            if item ~= nil then
                animal.lantern:detachLantern()
                animal.lantern:attachLantern(item)
                local switchNode = e.reference.sceneNode:getObjectByName("SWITCH_LANTERN")
                local attachLightNode = switchNode:getObjectByName("ATTACH_LIGHT")
                animal.lantern.addLight(attachLightNode, item)
                --Attach the light
                animal.lantern:turnOnOrOff()
            else
                animal.lantern:turnLanternOff()
            end
        end
    }
}

local nodes = {}
for _, nodeConfig in ipairs(switchConfigs) do
    local switchNode = SwitchNode.new(nodeConfig)
    table.insert(nodes, switchNode)
    logger:debug("Registered switch node %s", nodeConfig.id)
end
for _, nodeConfig in ipairs(attachConfigs) do
    local attachNode = AttachNode.new(nodeConfig)
    table.insert(nodes, attachNode)

    logger:debug("Registered attach node %s", nodeConfig.id)
end


NodeManager.register{
    id = "GuarWhisperer_PackNodes",
    referenceRequirements = function(reference)
        return Animal.get(reference) ~= nil
    end,
    nodes = nodes
}