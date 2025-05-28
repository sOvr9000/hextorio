
local blueprints = require "api.blueprints"

local space_platforms = {}



---@param planet_name string
---@param name string|nil
---@return LuaSpacePlatform|nil
function space_platforms.new(planet_name, name)
    local sp = game.forces.player.create_space_platform {
        planet = planet_name,
        starter_pack = "space-platform-starter-pack",
        name = name,
    }
    if not sp then return end

    sp.apply_starter_pack()
    return sp
end

---@param sp LuaSpacePlatform
---@param blueprint_name string
function space_platforms.generate(sp, blueprint_name)
    
end

---@param sp LuaSpacePlatform
function space_platforms.generate_tier1_ship(sp)
    local stack = blueprints.get_item_stack "starter-ship"
    if not stack then return end
    if not sp.hub then return end

    blueprints.build(stack, sp.surface, {0, 0})
    for _, items in pairs(stack.cost_to_build) do
        if items.name == "space-platform-foundation" then
            items.count = items.count - 110
        end
        if items.name ~= "space-platform-hub" then
            sp.hub.insert(items)
        end
    end
end



return space_platforms
