local common = require("mer.theGuarWhisperer.common")
local logger = common.createLogger("Lantern")


---@class GuarWhisperer.Lantern.GuarCompanion.refData
---@field lanternOn boolean Lantern is turned on

---@class GuarWhisperer.Lantern.GuarCompanion : GuarWhisperer.Companion.Guar
---@field refData GuarWhisperer.Lantern.GuarCompanion.refData

--- This component is responsible for attaching
--- lanterns to guar's and toggling them on and off.
---@class GuarWhisperer.Lantern
---@field animal GuarWhisperer.Lantern.GuarCompanion
local Lantern = {
    lanternIds = {
        ["light_com_lantern_02_Off"] = true,
        ["light_com_lantern_02"] = true,
        ["light_com_lantern_02_128"] = true,
        ["light_com_lantern_02_128_Off"] = true,
        ["light_com_lantern_02_177"] = true,
        ["light_com_lantern_02_256"] = true,
        ["light_com_lantern_02_64"] = true,
        ["light_com_lantern_02_INF"] = true,
        ["light_com_lantern_01"] = true,
        ["light_com_lantern_01_128"] = true,
        ["light_com_lantern_01_256"] = true,
        ["light_com_lantern_01_77"] = true,
        ["light_com_lantern_01_Off"] = true,
        ["light_de_lantern_14"] = true,
        ["light_de_lantern_11"] = true,
        ["light_de_lantern_10"] = true,
        ["light_de_lantern_10_128"] = true,
        ["light_de_lantern_07"] = true,
        ["light_de_lantern_07_128"] = true,
        ["light_de_lantern_07_warm"] = true,
        ["light_de_lantern_06"] = true,
        ["light_de_lantern_06_128"] = true,
        ["light_de_lantern_06_177"] = true,
        ["light_de_lantern_06_256"] = true,
        ["light_de_lantern_06_64"] = true,
        ["Light_De_Lantern_06A"] = true,
        ["light_de_lantern_05"] = true,
        ["light_de_lantern_05_128_Carry"] = true,
        ["light_de_lantern_05_200"] = true,
        ["light_de_lantern_05_Carry"] = true,
        ["light_de_lantern_02"] = true,
        ["light_de_lantern_02-128"] = true,
        ["light_de_lantern_02-177"] = true,
        ["light_de_lantern_02_128"] = true,
        ["light_de_lantern_02_256_blue"] = true,
        ["light_de_lantern_02_256_Off"] = true,
        ["light_de_lantern_02_blue"] = true,
        ["Light_De_Lantern_01"] = true,
        ["Light_De_Lantern_01_128"] = true,
        ["Light_De_Lantern_01_177"] = true,
        ["Light_De_Lantern_01_77"] = true,
        ["light_de_lantern_01_off"] = true,
        ["Light_De_Lantern_01white"] = true,
        ["dx_l_ashl_lantern_01"] = true,
        ["dx_l_lant_crystal_01"] = true,
        ["dx_l_lant_crystal_02"] = true,
        ["dx_l_lant_paper_01"] = true,
    }
}

---@param animal GuarWhisperer.Lantern.GuarCompanion
---@return GuarWhisperer.Lantern
function Lantern.new(animal)
    local self = setmetatable({}, { __index = Lantern })
    self.animal = animal
    return self
end

function Lantern.getLanternIds()
    return Lantern.lanternIds
end

function Lantern.removeLight(lightNode)
    logger:debug("Removing light from %s", lightNode.name)
    for node in table.traverse{lightNode} do
        local nodesToDetach = {
            ["nibsparticlenode"] = true,
            ["lighteffectswitch"] = true,
            ["glow"] = true,
            ["attachlight"] = true,
            ["candleflameanimnode"] = true
        }
        local nodeName = node.name and node.name:lower() or ""
        if nodesToDetach[nodeName] then
            logger:debug("Detaching %s from %s", node.name, lightNode.name)
            node.parent:detachChild(node)
        end

        -- Kill materialProperty
        local materialProperty = node:getProperty(0x2)
        if materialProperty then
            if (materialProperty.emissive.r > 1e-5 or materialProperty.emissive.g > 1e-5 or materialProperty.emissive.b > 1e-5 or materialProperty.controller) then
                logger:debug("Killing emissive on %s", node.name)
                materialProperty = node:detachProperty(0x2):clone()
                node:attachProperty(materialProperty)
                -- Kill controllers
                materialProperty:removeAllControllers()
                -- Kill emissives
                local emissive = materialProperty.emissive
                emissive.r, emissive.g, emissive.b = 0,0,0
                materialProperty.emissive = emissive
                node:updateProperties()
            end
        end
     -- Kill glowmaps
        local texturingProperty = node:getProperty(0x4)
        local newTextureFilepath = "Textures\\tx_black_01.dds"
        if (texturingProperty and texturingProperty.maps[4]) then
            logger:debug("Killing glowmap on %s", node.name)
            texturingProperty.maps[4].texture = niSourceTexture.createFromPath(newTextureFilepath)
        end
        if (texturingProperty and texturingProperty.maps[5]) then
            logger:debug("Killing glowmap on %s", node.name)
            texturingProperty.maps[5].texture = niSourceTexture.createFromPath(newTextureFilepath)
        end
    end
    lightNode:update()
    lightNode:updateEffects()
end

---@param attachNode niNode
---@param item tes3light
function Lantern.addLight(attachNode, item)
    logger:debug("Adding light to %s", attachNode.name)
    --set up light properties
    local lightNode = attachNode.children[1] or niPointLight.new()
    lightNode.name = "LightNode"
    lightNode.ambient = tes3vector3.new(0,0,0) --[[@as niColor]]
    lightNode.diffuse = tes3vector3.new(
        item.color[1] / 255,
        item.color[2] / 255,
        item.color[3] / 255
    )--[[@as niColor]]
    attachNode:attachChild(lightNode, true)
    return lightNode
end

---@param lanternObj tes3light
function Lantern:attachLantern(lanternObj)
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("ATTACH_LANTERN")
    --get lantern mesh and attach
    local itemNode = tes3.loadMesh(lanternObj.mesh):clone()
    --local attachLight = itemNode:getObjectByName("AttachLight")
    --attachLight.parent:detachChild(attachLight)
    itemNode:clearTransforms()
    itemNode.name = lanternObj.id
    lanternParent:attachChild(itemNode, true)
end

function Lantern:detachLantern()
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("ATTACH_LANTERN")
    lanternParent:detachAllChildren()
end

---@param e? { playSound: boolean }
function Lantern:turnLanternOn(e)
    logger:debug("Turning lantern on")
    e = e or {}
    if not self.animal.reference.sceneNode then return end
    --First we gotta delete the old one and clone again, to get our material properties back
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("ATTACH_LANTERN")
    if lanternParent and lanternParent.children and #lanternParent.children > 0 then
        local lanternId = lanternParent.children[1].name
        self:detachLantern()
        self:attachLantern(tes3.getObject(lanternId))

        local lightParent = self.animal.reference.sceneNode:getObjectByName("ATTACH_LIGHT")
        lightParent.translation.z = 0

        local lightNode = lightParent.children[1] or Lantern.addLight(lightParent, tes3.getObject(lanternId))
        logger:debug("Light node: %s", lightNode.name)
        lightNode:setAttenuationForRadius(256)

        self.animal.reference.sceneNode:update()
        self.animal.reference.sceneNode:updateEffects()
        self.animal.reference:getOrCreateAttachedDynamicLight(lightNode, 1.0)
        self.animal.refData.lanternOn = true
        if e.playSound == true then
            tes3.playSound{ reference = tes3.player, sound = "mer_tgw_alight", pitch = 1.0}
        end
    end
end

---@param e? { playSound: boolean }
function Lantern:turnLanternOff(e)
    logger:debug("Turning lantern off")
    e = e or {}
    if not self.animal.reference.sceneNode then return end
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("ATTACH_LANTERN")
    self.removeLight(lanternParent)
    local lightParent = self.animal.reference.sceneNode:getObjectByName("ATTACH_LIGHT")
    --move away to move PPL lighting artifacts
    lightParent.translation.z = -10000
    local lightNode = lightParent.children[1]
    if lightNode then
        logger:debug("Found light node, detaching")
        lightNode:setAttenuationForRadius(0)
        self.animal.reference.sceneNode:update()
        self.animal.reference.sceneNode:updateEffects()
        self.animal.refData.lanternOn = false
        if e.playSound == true then
            tes3.playSound{ reference = tes3.player, sound = "mer_tgw_alight", pitch = 1.0}
        end
    end
end

function Lantern:turnOnOrOff()
    if self:isOn() then
        self:turnLanternOn()
    else
        self:turnLanternOff()
    end
end

function Lantern:isOn()
    return self.animal.refData.lanternOn == true
end

function Lantern:getLanternFromInventory()
    for item in pairs(self:getLanternIds()) do
        if self.animal.object.inventory:contains(item) then
            return tes3.getObject(item)
        end
    end
end


return Lantern