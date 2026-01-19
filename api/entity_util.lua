
local entity_util = {}



---Get the tier of a strongbox entity from its name. Return nil if the entity is not a strongbox.
---@param sb_entity LuaEntity
---@return int|nil
function entity_util.get_tier_of_strongbox(sb_entity)
    return tonumber(sb_entity.name:sub(16))
end



return entity_util
