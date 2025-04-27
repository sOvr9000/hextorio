
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local item_ranks = require "api.item_ranks"
local gui = require "api.gui"



local admin_only = {
    ["claim"] = true,
    ["debug-items"] = true,
    ["rank-up"] = true,
    ["add-trade"] = true,
    ["remove-trade"] = true,
    ["rank-up-all"] = true,
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
        -- TODO
    elseif command == "remove-trade" then
        -- TODO
    end
end

function parse_command(command)
    -- Split command.parameter by spaces
    local params = {}
    if command.parameter then
        for arg in command.parameter:gmatch("%S+") do
            table.insert(params, arg)
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

