local common = require("mer.theGuarWhisperer.common")
local logger = common.log

local PATH = "Data Files/MWSE/mods/mer/theGuarWhisperer/integrations/"

local function isLuaFile(file) return file:sub(-4, -1) == ".lua" end
local function isInitFile(file) return file == "init.lua" end
local function initAll()
    for file in lfs.dir(PATH) do
        if isLuaFile(file) and not isInitFile(file) then
            logger:debug("Executing file: %s", file)
            dofile(PATH .. file)
        end
    end
end
initAll()