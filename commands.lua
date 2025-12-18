local lib = require "api.lib"
local event_system = require "api.event_system"
local space_platforms = require "api.space_platforms"
local sets = require "api.sets"
local coin_tiers = require "api.coin_tiers"



local all_commands = {
    {
        name = "refresh-all-trades",
        usage = "/refresh-all-trades",
    },
    {
        name = "hextorio-commands",
        usage = "/hextorio-commands",
    },
    {
        name = "hextorio-debug",
        usage = "/hextorio-debug",
    },
    {
        name = "claim",
        usage = "/claim [radius]",
        params = {"number?"},
        examples = {"/claim", "/claim 1"},
    },
    {
        name = "force-claim",
        usage = "/force-claim [radius]",
        params = {"number?"},
        examples = {"/force-claim", "/force-claim 1"},
    },
    {
        name = "rank-up",
        usage = "/rank-up <item-name>",
        params = {"string"},
        examples = {"/rank-up iron-ore", "/rank-up [color=yellow]in-hand[.color]"},
    },
    {
        name = "rank-up-all",
        usage = "/rank-up-all",
    },
    {
        name = "discover-all",
        usage = "/discover-all",
    },
    {
        name = "add-trade",
        usage = "/add-trade <inputs> <outputs>",
        params = {"any", "any"},
        examples = {"/add-trade stone coal", "/add-trade [stone iron-plate] uranium-ore", "/add-trade plastic-bar [copper-plate copper-ore]", "/add-trade [color=yellow]in-hand[.color] hex-coin"},
    },
    {
        name = "remove-trade",
        usage = "/remove-trade <index>",
        params = {"number"},
        examples = {"/remove-trade 1"},
    },
    {
        name = "complete-quest",
        usage = "/complete-quest <quest-name>",
        params = {"string"},
        examples = {"/complete-quest ground-zero", "/complete-quest find-some-trades"},
    },
    {
        name = "tp-to-ship",
        usage = "/tp-to-ship",
    },
    {
        name = "chart",
        usage = "/chart <surface> [range]",
        params = {"string", "number?"},
        examples = {"/chart vulcanus", "/chart nauvis 500", "/chart [color=pink]here[.color]"},
    },
    {
        name = "spawn-ship",
        usage = "/spawn-ship",
    },
    {
        name = "skip-flight",
        usage = "/skip-flight",
    },
    {
        name = "hex-pool-size",
        usage = "/hex-pool-size [size]",
        params = {"number?"},
        examples = {"/hex-pool-size", "/hex-pool-size 100"},
    },
    {
        name = "add-coins",
        usage = "/add-coins [amount]",
        params = {"number?"},
        examples = {"/add-coins", "/add-coins 100000"},
    },
    {
        name = "summon",
        usage = "/summon <entity> [amount] [quality]",
        params = {"string", "number?", "string?"},
        examples = {"/summon spitter-spawner", "/summon small-worm-turret 2", "/summon big-stomper-pentapod 5 hextreme"},
    },
    {
        name = "tp-to-edge",
        usage = "/tp-to-edge",
    },
    {
        name = "simple-trade-loops",
        usage = "/simple-trade-loops",
    },
    {
        name = "regenerate-trades",
        usage = "/regenerate-trades",
        requires_confirmation = true,
    },
    {
        name = "export-item-values",
        usage = "/export-item-values",
    },
    {
        name = "import-item-values",
        usage = "/import-item-values <string>",
        params = {"string"},
    },
    {
        name = "get-item-value",
        usage = "/get-item-value <item_name> <planet> [quality]",
        params = {"string", "string", "string?"},
        examples = {"/get-item-value carbon-fiber gleba", "/get-item-value agricultural-science-pack nauvis", "/get-item-value long-handed-inserter aquilo rare", "/get-item-value [color=yellow]in-hand[.color] [color=pink]here[.color]"},
    },
    {
        name = "set-item-value",
        usage = "/set-item-value <item_name> <value> [planet]",
        params = {"string", "number", "string?"},
        examples = {
            "/set-item-value iron-plate 0.01\n    Sets the value of 1x [img=item.iron-plate] to 0.01x [img=item.hex-coin] on [img=space-location.nauvis].",
            "\n/set-item-value holmium-plate 20000000 aquilo\n    Sets the value of 1x [img=item.holmium-plate] to 200x [img=item.gravity-coin] on [img=space-location.aquilo].",
            "\n/set-item-value tin-plate 40\n    Sets the value of one tin-plate, if a mod adds an item by that name, to 40x [img=item.hex-coin] on [img=space-location.nauvis].",
            "\n/set-item-value [color=yellow]in-hand[.color] 1000 [color=pink]here[.color]\n    Sets the value of the item in your hand to 1000x [img=item.hex-coin] on your character's current planet."
        },
    },
    {
        name = "remove-item-value",
        usage = "/remove-item-value <item_name> [planet]",
        params = {"string", "string?"},
        examples = {
            "/remove-item-value iron-plate\n\tRemoves the value of [img=item.iron-plate] from all planets, keeping it from showing up in trades anywhere.",
            "\n/remove-item-value water-barrel nauvis\n\tRemoves the value of [img=item.water-barrel] from [planet=nauvis] only, allowing it to still show up in trades on [img=space-location.vulcanus][img=space-location.fulgora][img=space-location.gleba].",
        },
    },
}

local public_commands = sets.new {
    "hextorio-commands",
    "get-item-value",
    "simple-trade-loops",
}



-- Type checking functions
local function get_type(value)
    if type(value) == "table" then
        return "array"
    elseif type(value) == "number" then
        return "number"
    else
        return "string"
    end
end

local function validate_type(value, expected_type)
    local actual_type = get_type(value)

    -- Handle optional parameters (marked with ?)
    local is_optional = expected_type:sub(-1) == "?"
    if is_optional then
        expected_type = expected_type:sub(1, -2)
    end

    -- "any" accepts any type
    if expected_type == "any" then
        return true
    end

    return actual_type == expected_type
end

function convert_params(player, params)
    for i = 1, #params do
        local param = params[i]
        local param_type = type(param)
        if param_type == "table" then
            if not convert_params(player, param) then
                return false
            end
        elseif param_type == "string" then
            if param == "in-hand" then
                if not player.cursor_stack or not player.cursor_stack.valid_for_read then
                    player.print {"hextorio.command-no-item-in-hand"}
                    return false
                end
                params[i] = player.cursor_stack.prototype.name
            elseif param == "here" then
                if not player.character then
                    player.print {"hextorio.command-no-character-found"}
                    return false
                end
                params[i] = player.character.surface.name
            end
        end
    end
    return true
end

function validate_params(player, command_name, params, expected_params)
    -- Count required parameters
    local required_count = 0
    local total_count = #expected_params

    for _, param_type in ipairs(expected_params) do
        if not param_type:match("%?$") then
            required_count = required_count + 1
        end
    end

    -- Check minimum parameter count
    if #params < required_count then
        player.print({"hextorio.command-not-enough-params", required_count, #params})
        return false
    end

    -- Check maximum parameter count
    if #params > total_count then
        player.print({"hextorio.command-too-many-params", total_count, #params})
        return false
    end

    -- Validate each parameter type
    for i, expected_type in ipairs(expected_params) do
        if params[i] ~= nil then
            if not validate_type(params[i], expected_type) then
                local clean_type = expected_type:gsub("%?$", "")
                player.print({"hextorio.command-wrong-type", i, clean_type, get_type(params[i])})
                return false
            end
        end
    end

    return true
end

function on_command(player, command, params)
    if command == "hextorio-commands" then
        local cmd_names = {}
        for _, cmd in pairs(all_commands) do
            if player.admin or public_commands[cmd.name] then
                table.insert(cmd_names, "/" .. cmd.name)
            end
        end
        player.print(table.concat(cmd_names, " "))
    elseif command == "hextorio-debug" then
        storage.debug_mode = true

        player.insert {
            name = "hex-coin",
            count = 99999,
        }
        player.insert {
            name = "gravity-coin",
            count = 99999,
        }
        player.insert {
            name = "meteor-coin",
            count = 99999,
        }
        player.insert {
            name = "hexaprism-coin",
            count = 100000,
        }

        -- Get legendary mech armor
        lib.insert_endgame_armor(player)

        -- Give powerful weapons
        player.insert {name = "teslagun", quality = "hextreme", count = 1}
        player.insert {name = "railgun", quality = "hextreme", count = 1}
        player.insert {name = "rocket-launcher", quality = "hextreme", count = 1}
        player.insert {name = "tesla-ammo", quality = "hextreme", count = 200}
        player.insert {name = "railgun-ammo", quality = "hextreme", count = 50}
        player.insert {name = "atomic-bomb", quality = "hextreme", count = 20}
        player.insert {name = "plague-rocket", quality = "hextreme", count = 200}
        player.insert {name = "demolisher-capsule", quality = "hextreme", count = 100} -- railguns robot
        -- player.insert {name = "disintegrator-capsule", quality = "hextreme", count = 100} -- lasers robot
        -- player.insert {name = "decimator-capsule", quality = "hextreme", count = 100} -- bullets robot

        -- Give items for making trades at spawn hexes on all planets
        -- for _, starting_trades in pairs(storage.trades.starting_trades) do
        --     for _, trade_items in pairs(starting_trades) do
        --         if type(trade_items[1]) == "string" then
        --             trade_items[1] = {trade_items[1]}
        --         end
        --         for _, item_name in pairs(trade_items[1]) do
        --             if not lib.is_coin(item_name) then
        --                 player.insert {
        --                     name = item_name,
        --                     count = 200,
        --                 }
        --             end
        --         end
        --     end
        -- end

        -- Research all technologies
        for _, tech in pairs(game.forces.player.technologies) do
            tech.researched = true
        end

        -- Enable cheat mode (spawn in items instead of crafting them)
        player.cheat_mode = true
        player.clear_recipe_notifications()

        -- Spawn Sentient Spider
        local character = player.character
        if character then
            local spider = player.surface.create_entity {
                name = "sentient-spider",
                position = character.position,
                surface = character.surface,
                quality = "hextreme",
                force = "player",
            }
            if spider then
                player.set_driving(true)
                storage.debug_spider = spider
                spider.vehicle_automatic_targeting_parameters = {auto_target_with_gunner = true, auto_target_without_gunner = true}
                local main_inv = spider.get_inventory(defines.inventory.spider_trunk)
                if main_inv then
                    main_inv.insert {name = "construction-robot", quality = "hextreme", count = 680}
                    main_inv.insert {name = "repair-pack", quality = "hextreme", count = 100}
                    main_inv.insert {name = "hex-coin", count = 99999}
                    main_inv.insert {name = "gravity-coin", count = 99999}
                    main_inv.insert {name = "meteor-coin", count = 99999}
                    main_inv.insert {name = "hexaprism-coin", count = 100000}
                end
                local ammo_inv = spider.get_inventory(defines.inventory.spider_ammo)
                if ammo_inv then
                    ammo_inv.insert {name = "electromagnetic-penetrator-cell", quality = "hextreme", count = 6}
                end
                local grid = spider.grid
                if grid then
                    for _ = 1, 4 do
                        grid.put({name = "fusion-reactor-equipment", quality = "hextreme"})
                    end
                    for _ = 1, 8 do
                        grid.put({name = "battery-mk3-equipment", quality = "hextreme"})
                    end
                    for _ = 1, 4 do
                        grid.put({name = "fusion-reactor-equipment", quality = "hextreme"})
                    end
                    for _ = 1, 4 do
                        grid.put({name = "personal-laser-defense-equipment", quality = "hextreme"})
                    end
                    for _ = 1, 6 do
                        grid.put({name = "exoskeleton-equipment", quality = "hextreme"})
                    end
                    for _ = 1, 8 do
                        grid.put({name = "personal-roboport-mk2-equipment", quality = "hextreme"})
                    end
                    for _ = 1, 31 do
                        grid.put({name = "energy-shield-mk2-equipment", quality = "hextreme"})
                    end
                    for _ = 1, 12 do
                        grid.put({name = "toolbelt-equipment", quality = "hextreme"})
                    end
                end
            end
        end

        -- Spawn midgame spaceship
        local sp = space_platforms.new "nauvis"
        if sp then
            space_platforms.generate(sp, "starter-ship")
        end

        -- Claim hexes
        -- handled by event_system
    elseif command == "tp-to-ship" then
        player.teleport({x = 0, y = 0}, "platform-1")
    elseif command == "chart" then
        local surface_name = params[1]
        if not game.get_surface(surface_name) then
            player.print {"hextorio.command-invalid-surface"}
            return
        end

        local range = params[2] or 300
        player.force.chart(surface_name, {{-range, -range}, {range, range}})
    elseif command == "spawn-ship" then
        local sp = space_platforms.new "nauvis"
        if sp then
            space_platforms.generate(sp, "starter-ship")
        end
    elseif command == "skip-flight" then
        local sp = player.surface.platform
        if not sp then
            player.print({"hextorio.not-on-platform"})
            return
        end
        if not sp.space_connection then
            player.print({"hextorio.platform-no-destination"})
            return
        end

        sp.distance = 1
    elseif command == "add-coins" then
        local inv = lib.get_player_inventory(player)
        if inv then
            coin_tiers.add_coin_to_inventory(inv, coin_tiers.from_base_value(params[1] or 100000000000000000000))
        end
    elseif command == "summon" then
        local entity_name = params[1]
        local amount = params[2] or 1
        local quality = params[3] or "normal"
        for i = 1, amount do
            game.surfaces[1].create_entity {
                name = entity_name,
                position = player.position,
                quality = quality,
            }
        end
        lib.unstuck_player(player)
    end

    event_system.trigger("command-" .. command, player, params)
end

function parse_command(command)
    -- Verify storage integrity
    if not storage.commands then
        storage.commands = {}
    end

    -- Fetch the player who called the command
    local player = game.get_player(command.player_index)
    if not player then return end

    if not public_commands[command.name] and not player.admin then
        player.print {"hextorio.admin-command-only"}
        return
    end

    -- Parse parameters, handling arrays in square brackets
    local params = {}

    -- If there's no parameter, use empty params
    if not command.parameter or command.parameter == "" then
        -- Find command definition for validation
        local cmd_def = nil
        for _, cmd in pairs(all_commands) do
            if cmd.name == command.name then
                cmd_def = cmd
                break
            end
        end

        -- Validate parameters
        if not cmd_def then return end
        if cmd_def.params then
            if not validate_params(player, command.name, params, cmd_def.params) then
                return
            end
        end

        local confirmed = true
        if cmd_def.requires_confirmation then
            confirmed = command.name == storage.commands.last_command
        end

        if confirmed then
            if convert_params(player, params) then
                on_command(player, command.name, params)
            end
        else
            player.print(lib.color_localized_string({"hextorio.command-confirmation"}, "pink"))
        end

        storage.commands.last_command = command.name
        return
    end

    local param_str = command.parameter
    local i = 1

    while i <= #param_str do
        local char = param_str:sub(i, i)

        if char == "[" then
            -- Parse array
            local array = {}
            i = i + 1

            -- Look for array elements until closing bracket
            while i <= #param_str and param_str:sub(i, i) ~= "]" do
                -- Skip whitespace
                if param_str:sub(i, i):match("%s") then
                    i = i + 1
                else
                    -- Find end of current token
                    local token_end = param_str:find("[%s%]]", i) or (#param_str + 1)
                    local token = param_str:sub(i, token_end - 1)
                    -- Cast to number if possible
                    local num = tonumber(token)
                    table.insert(array, num or token)
                    i = token_end
                end
            end

            -- Skip closing bracket if found
            if i <= #param_str and param_str:sub(i, i) == "]" then
                i = i + 1
            end

            table.insert(params, array)
        elseif char:match("%s") then
            -- Skip whitespace
            i = i + 1
        else
            -- Parse regular parameter
            local token_end = param_str:find("%s", i) or (#param_str + 1)
            local token = param_str:sub(i, token_end - 1)
            -- Cast to number if possible
            local num = tonumber(token)
            table.insert(params, num or token)
            i = token_end
        end
    end

    -- Find command definition for validation
    local cmd_def = nil
    for _, cmd in pairs(all_commands) do
        if cmd.name == command.name then
            cmd_def = cmd
            break
        end
    end

    -- Validate parameters
    if not cmd_def then return end
    if cmd_def.params then
        if not validate_params(player, command.name, params, cmd_def.params) then
            return
        end
    end

    local confirmed = true
    if cmd_def.requires_confirmation then
        confirmed = command.name == storage.commands.last_command
    end

    if confirmed then
        if convert_params(player, params) then
            on_command(player, command.name, params)
        end
    else
        player.print(lib.color_localized_string({"hextorio.command-confirmation"}, "pink"))
    end

    storage.commands.last_command = command.name
end



for _, cmd in pairs(all_commands) do
    local str = {"", "\n", {"hextorio.command-usage", cmd.usage}, "\n", {"command-help." .. cmd.name}}
    if cmd.examples and next(cmd.examples) then
        table.insert(str, {"", "\n", {"hextorio.command-examples"}})
        table.insert(str, "\n" .. table.concat(cmd.examples, "\n"))
    end
    commands.add_command(cmd.name, str, parse_command)
end