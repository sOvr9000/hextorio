
local lib = require "api.lib"
local event_system = require "api.event_system"
local sets = require "api.sets"



local public_commands = sets.new {
    -- nothing yet
}

function on_command(player, command, params)
    if not public_commands[command] and not player.admin then
        player.print("You must be an admin to use that command.")
        return
    end

    if command == "debug-mode" then
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

        for _, trade_items in pairs(storage.trades.starting_trades) do
            for _, item_name in pairs(trade_items[1]) do
                if not lib.is_coin(item_name) then
                    player.insert {
                        name = item_name,
                        count = 200,
                    }
                end
            end
        end

        -- Claim hexes
        -- handled by event_system

        -- Research all technologies
        for _, tech in pairs(game.forces.player.technologies) do
            tech.researched = true
        end

        -- Enable cheat mode (spawn in items instead of crafting them)
        player.cheat_mode = true
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


commands.add_command("claim", "Claim a land hex, or all land hexes within a range", parse_command)
commands.add_command("force-claim", "Claim ANY hex, or ALL hexes within a range", parse_command)
commands.add_command("debug-mode", "Set up your character and game for debugging", parse_command)
commands.add_command("rank-up", "Rank up an item, bypassing progress requirements", parse_command)
commands.add_command("rank-up-all", "Rank up all items that are discovered in the catalog, bypassing progress requirements", parse_command)
commands.add_command("discover-all", "Discover all items in the catalog", parse_command)
commands.add_command("add-trade", "Add a trade to the hex core that you're mousing over", parse_command)
commands.add_command("remove-trade", "Remove trade #x from the hex core that you're mousing over (indexing starts at 1)", parse_command)
commands.add_command("complete-quest", "Complete a quest, bypassing progress requirements", parse_command)

