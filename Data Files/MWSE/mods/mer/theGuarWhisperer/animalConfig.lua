local this = {}

this.idles = {
        idle = "idle",
        happy = "idle5",
        eat = "idle4",
        pet = "idle6",
        fetch = "idle6",
        sad = "idle3"
}

---@class GuarWhisperer.AnimalData.lvl
---@field fetchProgress number
---@field attackProgress number

---@class GuarWhisperer.AnimalData.hunger
---@field changePerHour number

---@class GuarWhisperer.AnimalData.play
---@field changePerHour number
---@field fetchValue number
---@field greetValue number

---@class GuarWhisperer.AnimalData.affection
---@field changePerHour number
---@field petValue number

---@class GuarWhisperer.AnimalData.trust
---@field maxDistance number
---@field changePerHour number
---@field babyLevel number

---@class GuarWhisperer.AnimalData.reqs
---@field pack number
---@field follow number

---@class GuarWhisperer.AnimalData
---@field type string
---@field mutation number
---@field birthIntervalHours number
---@field babyScale number
---@field hoursToMature number
---@field lvl GuarWhisperer.AnimalData.lvl
---@field hunger GuarWhisperer.AnimalData.hunger
---@field play GuarWhisperer.AnimalData.play
---@field affection GuarWhisperer.AnimalData.affection
---@field trust GuarWhisperer.AnimalData.trust
---@field reqs GuarWhisperer.AnimalData.reqs
---@field breedable boolean
---@field tameable boolean
---@field foodList table<string, number>


this.animals = {

    guar = {
        type = "guar",
        mutation = 10,
        birthIntervalHours = 24 * 3,
        babyScale = 0.5,
        hoursToMature = 24 * 4,
        lvl = {
            fetchProgress = 4,
            attackProgress = 2
        },
        hunger = {
            changePerHour = -1.0,
        },
        play = {
            changePerHour = -0.5,
            fetchValue = 60,
            greetValue = 40
        },
        affection = {
            changePerHour = -3.0,
            petValue = 60
        },
        trust = {
            maxDistance = 1500,
            changePerHour = 5,
            babyLevel = 50,
        },
        reqs = {
            pack = 90,
            follow = 40
        },
        breedable = true,
        tameable = true,
        foodList = {

            ["ingred_corkbulb_root_01"] = 50,
            ["ingred_chokeweed_01"] = 40,
            ["ingred_kresh_fiber_01"] = 40,
            ["ingred_marshmerrow_01"] = 35,
            ["ingred_saltrice_01"] = 35,
            ["ingred_wickwheat_01"] = 35,
            ["ingred_comberry_01"] = 25,
            ["ingred_scathecraw_01"] = 40,
            --containers
            ["flora_corkbulb"] = true,
            ["flora_chokeweed_02"] = true,
            ["flora_kreshweed_01"] = true,
            ["flora_kreshweed_02"] = true,
            ["flora_kreshweed_03"] = true,
            ["flora_marshmerrow_01"] = true,
            ["flora_marshmerrow_02"] = true,
            ["flora_marshmerrow_03"] = true,
            ["flora_saltrice_01"] = true,
            ["flora_saltrice_02"] = true,
            ["flora_wickwheat_01"] = true,
            ["flora_wickwheat_02"] = true,
            ["flora_wickwheat_03"] = true,
            ["flora_wickwheat_04"] = true,
            ["flora_comberry_01"] = true,
            ["flora_rm_scathecraw_01"] = true,
            ["flora_rm_scathecraw_02"] = true,
        },
    },

}

this.greetableGuars = {
    ["mdfg\\fabricant_guar.nif"] = true,
    ["r\\guar.nif"] = true,
    ["r\\guar_withpack.nif"] = true,
    ["r\\guar_white.nif"] = true,
    ["mer_tgw\\guar_tame.nif"] = true,
    ["mer_tgw\\guar_tame_w.nif"] = true
}

--Meshes to allow to turn into switch guar
this.meshes = {
    -- ["mdfg\\fabricant_guar.nif"] = {
    --     type  = this.animals.guar,
    --     extra = {
    --         hasPack = false,
    --         canHavePack = false,
    --         color = "fabricant",
    --         foodList = { ["ingred_scrap_metal_01"] = 40}
    --     }
    -- },
    ["r\\guar.nif"] = {
        type  = this.animals.guar,
        extra = {
            hasPack = false,
            canHavePack = true,
            color = "standard"
        },
    },
    ["r\\guar_white.nif"] = {
        type  = this.animals.guar,
        extra = {
            hasPack = false,
            canHavePack = true,
            color = "white"
        }
    },
    -- },
    -- ["r\\guar_withpack.nif"] = {
    --     type  = this.animals.guar,
    --     extra = {
    --         hasPack = true,
    --         canHavePack = true,
    --         color = "standard"
    --     }
    -- },
    -- ["tr\\cr\\guar_withharness.nif"] = {
    --     type  = this.animals.guar,
    --     extra = {
    --         hasPack = true,
    --         canHavePack = true,
    --         color = "standard" A
    --     }
    -- },
}

this.guarMapper = {
    standard = "mer_tgw_guar",
    white = "mer_tgw_guar_w",
}

return this