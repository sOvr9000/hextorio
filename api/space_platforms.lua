
local blueprints = require "api.blueprints"
local event_system = require "api.event_system"

local space_platforms = {}



function space_platforms.register_events()
    event_system.register("quest-reward-received", function(reward_type, reward_value)
        if reward_type == "receive-spaceship" then
            local ship_name = space_platforms.get_platform_name(reward_value)
            local sp = space_platforms.new("nauvis", ship_name)
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

---Get a space platform's name from a blueprint's indexed name in storage.
---@param string_name string
---@return string|nil
function space_platforms.get_platform_name(string_name)
    local bp_storage = storage.blueprints
    local string_def = bp_storage.strings[string_name]
    if not string_def then return end
    return string_def.space_platform_name
end

---@param sp LuaSpacePlatform
---@param platform_name string
function space_platforms.generate(sp, platform_name)
    local stack = blueprints.get_item_stack(platform_name)
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
