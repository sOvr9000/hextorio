-- Handle all coin splitting when control-right-clicking inventories (without their inventories open).

local coin_tiers = require "api.coin_tiers"
local lib = require "api.lib"



local function verify_data_structure()
    if not storage.inventories then storage.inventories = {} end
    if not storage.inventories.player_inventories then storage.inventories.player_inventories = {} end
    if not storage.inventories.chest_inventories then storage.inventories.chest_inventories = {} end
end

---@param player LuaPlayer
---@return ItemWithQualityCount[]
local function get_player_inv_storage(player)
    verify_data_structure()
    local key = player.index
    if not storage.inventories.player_inventories[key] then storage.inventories.player_inventories[key] = {} end
    return storage.inventories.player_inventories[key]
end

---@param player LuaPlayer
local function set_player_inv_storage(player)
    verify_data_structure()
    local inv = player.get_main_inventory()
    if not inv then return end
    local key = player.index
    storage.inventories.player_inventories[key] = table.deepcopy(inv.get_contents())
end

---@param entity LuaEntity
---@return ItemWithQualityCount[]
local function get_chest_inv_storage(entity)
    verify_data_structure()
    local key = entity.unit_number
    if not key then return {} end
    if not storage.inventories.chest_inventories[key] then storage.inventories.chest_inventories[key] = {} end
    return storage.inventories.chest_inventories[key]
end

---@param entity LuaEntity
local function set_chest_inv_storage(entity)
    verify_data_structure()
    local inv = entity.get_inventory(defines.inventory.chest)
    if not inv then return end
    local key = entity.unit_number
    if not key then return end
    storage.inventories.chest_inventories[key] = table.deepcopy(inv.get_contents())
end



-- This is the driver code for handling proper coin splitting.  Enable when debugged.
--[[
script.on_event("hextorio-fast-entity-split", function(event)
    ---@cast event EventData.CustomInputEvent

    local player = game.get_player(event.player_index)
    if not player then return end

    local entity = player.opened or player.selected
    -- game.print(entity)
    if not entity then return end
    if entity.object_name ~= "LuaEntity" then return end

    set_chest_inv_storage(entity)
    set_player_inv_storage(player)
end)

script.on_event(defines.events.on_player_fast_transferred, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local player_inv = player.get_inventory(defines.inventory.character_main)
    if not player_inv then return end

    local entity = event.entity
    local chest_inv = entity.get_inventory(defines.inventory.chest)
    if not chest_inv then return end

    local player_contents = get_player_inv_storage(player)
    local chest_contents = get_chest_inv_storage(entity)

    if event.from_player then
        -- This was a transfer of items from player to entity.
        -- for _, item_stack in pairs(player_contents) do
        --     local item_name = item_stack.name
        --     if lib.is_coin(item_name) and item_stack.count % 2 == 1 then
        --         local tier = lib.get_tier_of_coin_name(item_name)
        --         if tier >= 2 then
        --             local next_coin_down = lib.get_coin_name_of_tier(tier - 1)
        --         end
        --     end
        -- end

        -- local inv = entity.get_inventory(defines.inventory.chest)
        -- if inv then
        --     coin_tiers.normalize_inventory(inv)
        -- end
    else
        -- This was a transfer of items from entity to player.
        local coin_to_offset = coin_tiers.new()
        for _, item_stack in pairs(chest_contents) do
            local item_name = item_stack.name
            if lib.is_coin(item_name) and item_stack.count % 2 == 1 then
                local tier = lib.get_tier_of_coin_name(item_name)
                if tier >= 2 then
                    local c = coin_tiers.new()
                    local offset = 0.5
                    if item_stack.count == 1 then
                        -- This is needed because the stack-splitting math is different between counts > 1 and counts == 1.
                        offset = -0.5
                    end
                    c.values[tier] = c.values[tier] + offset
                    coin_to_offset = coin_tiers.add(coin_to_offset, c)
                end
            end
        end

        coin_tiers.add_coin_to_inventory(player_inv, coin_to_offset)
        -- coin_tiers.normalize_inventory(player_inv)

        coin_tiers.remove_coin_from_inventory(chest_inv, coin_to_offset)
        -- coin_tiers.normalize_inventory(chest_inv)
    end
end)
]]
