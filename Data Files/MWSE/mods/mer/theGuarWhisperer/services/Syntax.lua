


---@class GuarWhisperer.Syntax
---@field gender GuarWhisperer.Gender
local Syntax = {}

---@param gender GuarWhisperer.Gender
---@return GuarWhisperer.Syntax
function Syntax.new(gender)
    local self = setmetatable({}, { __index = Syntax })
    self.gender = gender or "none"
    return self
end

--- Returns the provided string with the first letter capitalised
function Syntax.capitaliseFirst(str)
    return str:gsub("^%l", string.upper)
end

---Returns the string "He", "She" or "It",
--- depending on the configured gender.
---@param lower boolean? if you want the string to be lowercase, otherwise the first letter will be capitalised
---@return "He"| "She" | "It" | "he" | "she" | "it"
function Syntax:getHeShe(lower)
    local map = {
        male = "He",
        female = "She",
        none = "It"
    }
    local name =  map[self.gender] or map.none
    if lower then name = string.lower(name) end
    return name
end

---Returns the string "Him", "Her" or "It",
--- depending on the configured gender.
---@param lower boolean? if you want the string to be lowercase, otherwise the first letter will be capitalised
---@return "Him"| "Her" | "It" | "him" | "her" | "it"
function Syntax:getHimHer(lower)
    local map = {
        male = "Him",
        female = "Her",
        none = "It"
    }
    local name =  map[self.gender] or map.none
    if lower then name = string.lower(name) end
    return name
end

---Returns the string "His", "Her" or "Its",
--- depending on the configured gender.
---@param lower boolean? if you want the string to be lowercase, otherwise the first letter will be capitalised
---@return "His"| "Her" | "Its" | "his" | "her" | "its"
function Syntax:getHisHer(lower)
    local map = {
        male = "His",
        female = "Her",
        none = "Its"
    }
    local name =  map[self.gender] or map.none
    if lower then name = string.lower(name) end
    return name
end

return Syntax