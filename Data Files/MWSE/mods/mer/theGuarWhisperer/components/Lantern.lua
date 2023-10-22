local common = require("mer.theGuarWhisperer.common")
local logger = common.log


---@class GuarWhisperer.Lantern.Animal.refData
---@field lanternOn boolean Lantern is turned on

---@class GuarWhisperer.Lantern.Animal : GuarWhisperer.Animal
---@field refData GuarWhisperer.Lantern.Animal.refData

--- This component is responsible for attaching
--- lanterns to guar's and toggling them on and off.
---@class GuarWhisperer.Lantern
---@field animal GuarWhisperer.Lantern.Animal
local Lantern = {}

---@param animal GuarWhisperer.Lantern.Animal
---@return GuarWhisperer.Lantern
function Lantern.new(animal)
    local self = setmetatable({}, { __index = Lantern })
    self.animal = animal
    return self
end

function Lantern.removeLight(lightNode)
    for node in table.traverse{lightNode} do
        --Kill particles
        if node.RTTI.name == "NiBSParticleNode" then
            --node.appCulled = true
            node.parent:detachChild(node)
        end
        --Kill Melchior's Lantern glow effect
        if node.name == "LightEffectSwitch" or node.name == "Glow" then
            --node.appCulled = true
            node.parent:detachChild(node)
        end
        if node.name == "AttachLight" then
            --node.appCulled = true
            node.parent:detachChild(node)
        end

        -- Kill materialProperty
        local materialProperty = node:getProperty(0x2)
        if materialProperty then
            if (materialProperty.emissive.r > 1e-5 or materialProperty.emissive.g > 1e-5 or materialProperty.emissive.b > 1e-5 or materialProperty.controller) then
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
        texturingProperty.maps[4].texture = niSourceTexture.createFromPath(newTextureFilepath)
        end
        if (texturingProperty and texturingProperty.maps[5]) then
            texturingProperty.maps[5].texture = niSourceTexture.createFromPath(newTextureFilepath)
        end
    end
    lightNode:update()
    lightNode:updateEffects()
end

---@param lanternObj tes3light
function Lantern:attachLantern(lanternObj)
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("LANTERN")
    --get lantern mesh and attach
    local itemNode = tes3.loadMesh(lanternObj.mesh):clone()
    --local attachLight = itemNode:getObjectByName("AttachLight")
    --attachLight.parent:detachChild(attachLight)
    itemNode:clearTransforms()
    itemNode.name = lanternObj.id
    lanternParent:attachChild(itemNode, true)
end

function Lantern:detachLantern()
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("LANTERN")
    lanternParent:detachChildAt(1)
end

---@param e? { playSound: boolean }
function Lantern:turnLanternOn(e)
    e = e or {}
    if not self.animal.reference.sceneNode then return end
    --First we gotta delete the old one and clone again, to get our material properties back
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("LANTERN")
    if lanternParent and lanternParent.children and #lanternParent.children > 0 then
        local lanternId = lanternParent.children[1].name
        self:detachLantern()
        self:attachLantern(tes3.getObject(lanternId))

        local lightParent = self.animal.reference.sceneNode:getObjectByName("LIGHT")
        lightParent.translation.z = 0

        local lightNode = self.animal.reference.sceneNode:getObjectByName("LanternLight")
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
    e = e or {}
    if not self.animal.reference.sceneNode then return end
    local lanternParent = self.animal.reference.sceneNode:getObjectByName("LANTERN")
    self.removeLight(lanternParent)
    local lightParent = self.animal.reference.sceneNode:getObjectByName("LIGHT")
    lightParent.translation.z = 1000
    local lightNode = self.animal.reference.sceneNode:getObjectByName("LanternLight")
    if lightNode then
        lightNode:setAttenuationForRadius(0)
        self.animal.reference.sceneNode:update()
        self.animal.reference.sceneNode:updateEffects()
        self.animal.refData.lanternOn = false
        if e.playSound == true then
            tes3.playSound{ reference = tes3.player, sound = "mer_tgw_alight", pitch = 1.0}
        end
    end
end

function Lantern:isOn()
    return self.animal.refData.lanternOn == true
end

return Lantern