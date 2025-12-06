
local blueprints = require "api.blueprints"
local event_system = require "api.event_system"

local space_platforms = {}



function space_platforms.register_events()
    event_system.register("quest-reward-received", function(reward_type, reward_value)
        if reward_type == "receive-spaceship" then
            local sp = space_platforms.new "nauvis"
            if sp then
                space_platforms.generate(sp, reward_value)
            end
        end
    end)
end

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
---@param ship_name string
function space_platforms.generate(sp, ship_name)
    local stack = blueprints.get_item_stack(ship_name)
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
