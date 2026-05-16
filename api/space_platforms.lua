
local blueprints = require "api.blueprints"
local event_system = require "api.event_system"

local space_platforms = {}



local STARTER_PACK_SHIPS = {
    ["hexaclysm"] = {
        given_foundations = 1336,
    },
}



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

    event_system.register("trigger-created-entity", function(entity)
        if entity.name ~= "space-platform-hub" then return end

        local platform = entity.surface.platform
        if not platform then return end

        local starter_pack_name = space_platforms.get_starter_pack_name(platform)
        if not starter_pack_name or starter_pack_name:sub(1, 13) ~= "starter-pack-" then return end

        local ship_name = starter_pack_name:sub(14)
        local ship_def = STARTER_PACK_SHIPS[ship_name]
        if not ship_def then return end

        space_platforms.generate(platform, "hexaclysm", ship_def.given_foundations, true)
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

---@param platform LuaSpacePlatform
---@return string|nil
function space_platforms.get_starter_pack_name(platform)
    local starter_pack = platform.starter_pack
    if not starter_pack then return end

    local start_pack_name = starter_pack.name
    if type(start_pack_name) == "string" then
        return start_pack_name
    end
    return start_pack_name.name
end

---@param sp LuaSpacePlatform
---@param platform_name string
---@param given_platforms int|nil
---@param insert_cost_to_build boolean|nil
function space_platforms.generate(sp, platform_name, given_platforms, insert_cost_to_build)
    if insert_cost_to_build == nil then insert_cost_to_build = true end

    local stack = blueprints.get_item_stack(platform_name)
    if not stack then return end
    if not sp.hub then return end

    blueprints.build(stack, sp.surface, {0, 0})

    local label = space_platforms.get_platform_name(platform_name)
    if label then
        sp.name = label
    end

    if not insert_cost_to_build then return end

    for _, items in pairs(stack.cost_to_build) do
        local count = items.count
        if items.name == "space-platform-foundation" then
            count = count - (given_platforms or 110)
        end
        if items.name ~= "space-platform-hub" and count > 0 then
            local to_insert = table.deepcopy(items)
            to_insert.count = count
            sp.hub.insert(to_insert) ---@diagnostic disable-line
        end
    end
end



return space_platforms
