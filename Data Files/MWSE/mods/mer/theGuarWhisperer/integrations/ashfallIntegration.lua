-- Define the recipe for the leather ball
---@type CraftingFramework.Recipe.data[]
local bushcraftingRecipes = {
    {
        id = "TGW_LeatherBall",
        craftableId = "mer_tgw_ball_02",
        description = "A ball made of fabric and stuffed with straw. Perfect for playing fetch.",
        materials = {
            { material = "fabric", count = 1 },
            { material = "straw", count = 2 },
        },
        skillRequirements = {
            {
                skill = "Bushcrafting",
                requirement = 15,
            }
        },
        category = "Toys",
        rotationAxis = "z",
        previewScale = 0.8,
    },
}

local carvingRecipes = {
    {
        id = "TGW_Flute",
        craftableId = "mer_tgw_flute",
        description = "A simple wooden flute that can be used to summon guar companions.",
        materials = {
            { material = "wood", count = 1 },
        },
        toolRequirements = {
            {
                tool = "chisel",
                conditionPerUse = 5
            }
        },
        skillRequirements = {
            {
                skill = "Bushcrafting",
                requirement = 15,
            }
        },
        category = "Guar Equipment",
    }
}

event.register("Ashfall:EquipChisel:Registered", function(e)
    ---@type CraftingFramework.MenuActivator
    local menuActivator = e.menuActivator
    menuActivator:registerRecipes(carvingRecipes)
end)

event.register("Ashfall:ActivateBushcrafting:Registered", function(e)
    ---@type CraftingFramework.MenuActivator
    local menuActivator = e.menuActivator
    menuActivator:registerRecipes(bushcraftingRecipes)
end)