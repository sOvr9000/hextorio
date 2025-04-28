
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local item_ranks = require "api.item_ranks"
local gui = require "api.gui"
local event_system = require "api.event_system"
local sets = require "api.sets"



local admin_only = sets.new {
    "claim",
    "debug-items",
    "rank-up",
    "rank-up-all",
    "add-trade",
    "remove-trade",
}

function on_command(player, command, params)
    if admin_only[command] and not player.admin then return end

    if command == "claim" then
        hex_grid.claim_hex(player.surface.name, {q = params[1], r = params[2]})
    elseif command == "debug-items" then
        player.insert{
            name = "hex-coin",
            count = 12345,
        }
        player.insert{
            name = "gravity-coin",
            count = 12345,
        }
        player.insert{
            name = "meteor-coin",
            count = 12345,
        }
        player.insert{
            name = "hexaprism-coin",
            count = 12345,
        }
    elseif command == "rank-up" then
        if item_ranks.rank_up(params[1]) then
            -- player.print("Ranked up [item=" .. params[1] .. "] to rank " .. lib.get_rank_img_str(item_ranks.get_item_rank(params[1])))
            gui.update_catalog(player, "nauvis", params[1])
        else
            player.print("Failed to rank up [item=" .. params[1] .. "]")
        end
    elseif command == "rank-up-all" then
        item_ranks.rank_up_all()
    elseif command == "discover-all" then
        -- item_ranks.rank_up_all()
    elseif command == "add-trade" then
        event_system.trigger("command-add-trade", player, params)
    elseif command == "remove-trade" then
        event_system.trigger("command-remove-trade", player, params)
    end
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


commands.add_command("claim", "Claim a hex", parse_command)
commands.add_command("debug-items", "Add items to your inventory for debugging", parse_command)
commands.add_command("rank-up", "Rank up an item, bypassing progress requirements", parse_command)
commands.add_command("rank-up-all", "Rank up all items that are discovered in the catalog, bypassing progress requirements", parse_command)
commands.add_command("discover-all", "Discover an item in the catalog", parse_command)
commands.add_command("add-trade", "Add a trade to the nearest hex core", parse_command)
commands.add_command("remove-trade", "Remove trade #x from the nearest hex core (indexing starts at 1)", parse_command)

