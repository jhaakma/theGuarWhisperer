--- A collection of utility functions
---@class GuarWhisperer.common.Util
local Util = {}

function Util.getHoursPassed()
    return ( tes3.worldController.daysPassed.value * 24 ) + tes3.worldController.hour.value
end

---Gets an accurate bounding box by cloning and removing lights
--- and collision before calling :createBoundingBox()
---@param node niNode
function Util.generateBoundingBox(node)
    -- prepare bounding box
   --Light particles mess with bounding box calculation
   local cloneForBB = node:clone()
   Util.removeLight(cloneForBB)
   --remove collision
   for node in table.traverse{cloneForBB} do
       if node:isInstanceOfType(tes3.niType.RootCollisionNode) then
           node.appCulled = true
       end
   end
   cloneForBB:update()
   return cloneForBB:createBoundingBox()
end


function Util.removeLight(lightNode)
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

return Util