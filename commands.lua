
local lib = require "api.lib"
local event_system = require "api.event_system"
local space_platforms = require "api.space_platforms"
local sets = require "api.sets"



local all_commands = {
    {name = "hextorio-commands", usage = "/hextorio-commands"},
    {name = "hextorio-debug", usage = "/hextorio-debug"},
    {name = "claim", usage = "/claim [radius]", examples = {"/claim", "/claim 1"}},
    {name = "force-claim", usage = "/force-claim [radius]", examples = {"/force-claim", "/force-claim 1"}},
    {name = "rank-up", usage = "/rank-up <item-name>", examples = {"/rank-up iron-ore"}},
    {name = "rank-up-all", usage = "/rank-up-all"},
    {name = "discover-all", usage = "/discover-all"},
    {name = "add-trade", usage = "/add-trade <inputs> <outputs>", examples = {"/add-trade stone coal", "/add-trade [stone iron-plate] uranium-ore", "/add-trade plastic-bar [copper-plate copper-ore]"}},
    {name = "remove-trade", usage = "/remove-trade <index>", examples = {"/remove-trade 1"}},
    {name = "complete-quest", usage = "/complete-quest <quest-name>", examples = {"/complete-quest ground-zero", "/complete-quest find-some-trades"}},
    {name = "tp-to-ship", usage = "/tp-to-ship"},
    {name = "chart", usage = "/chart <surface> [range]", examples = {"/chart vulcanus", "/chart nauvis 500"}},
}

local public_commands = sets.new {
    "hextorio-commands",
}



function on_command(player, command, params)
    if not public_commands[command] and not player.admin then
        player.print {"hextorio.admin-command-only"}
        return
    end

    if command == "hextorio-commands" then
        local cmd_names = {}
        for _, cmd in pairs(all_commands) do
            table.insert(cmd_names, "/" .. cmd.name)
        end
        player.print(table.concat(cmd_names, " "))
    elseif command == "hextorio-debug" then
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

        if player.get_inventory(defines.inventory.character_main) then
            -- Get legendary mech armor
            lib.insert_endgame_armor(player)

            for _, starting_trades in pairs(storage.trades.starting_trades) do
                for _, trade_items in pairs(starting_trades) do
                    for _, item_name in pairs(trade_items[1]) do
                        if not lib.is_coin(item_name) then
                            player.insert {
                                name = item_name,
                                count = 200,
                            }
                        end
                    end
                end
            end
        else
            player.print {"hextorio.no-player-inventory"}
        end

        -- Claim hexes
        -- handled by event_system

        -- Research all technologies
        for _, tech in pairs(game.forces.player.technologies) do
            tech.researched = true
        end

        -- Enable cheat mode (spawn in items instead of crafting them)
        player.cheat_mode = true

        local sp = space_platforms.new("nauvis", "Hexaclysm")
        if sp then
            space_platforms.generate_tier1_ship(sp)
        end
    elseif command == "tp-to-ship" then
        player.teleport({x = 0, y = 0}, "platform-1")
    elseif command == "chart" then
        local range = params[2] or 300
        player.force.chart(params[1], {{-range, -range}, {range, range}})
    end

    event_system.trigger("command-" .. command, player, params)
end

function parse_command(command)
    -- Parse parameters, handling arrays in square brackets
    local params = {}

    -- If there's no parameter, use empty params
    if not command.parameter or command.parameter == "" then
        local player = game.get_player(command.player_index)
        on_command(player, command.name, params)
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

    -- Fetch the player who called the command
    local player = game.get_player(command.player_index)

    -- Invoke the command function with the passed parameters
    on_command(player, command.name, params)
end



for _, cmd in pairs(all_commands) do
    local str = {"", "\n", {"hextorio.command-usage", cmd.usage}, "\n", {"command-help." .. cmd.name}}
    if cmd.examples and next(cmd.examples) then
        table.insert(str, {"", "\n", {"hextorio.command-examples"}})
        table.insert(str, "\n" .. table.concat(cmd.examples, "\n"))
    end
    commands.add_command(cmd.name, str, parse_command)
end
