
local sets = require "api.sets"

return {

    filters = {},
    trades = {},

    allowed_planet_filters = sets.new {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"}, -- needed so that sprite errors don't occur when mods add new planets
}
