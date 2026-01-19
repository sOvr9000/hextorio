
local lib = require "api.lib"
local event_system = require "api.event_system"
local coin_tiers   = require "api.coin_tiers"
local inventories  = require "api.inventories"

local strongboxes = {}



function strongboxes.register_events()
    event_system.register("runtime-setting-changed-strongbox-spawn-chance", function()
        strongboxes.fetch_strongbox_settings()
    end)

    event_system.register("runtime-setting-changed-strongbox-loot-scale", function()
        strongboxes.fetch_strongbox_settings()
    end)
end

function strongboxes.init()
    strongboxes.fetch_strongbox_settings()

    if not storage.strongboxes.total_coins_earned then
        storage.strongboxes.total_coins_earned = coin_tiers.new()
    end
end

function strongboxes.fetch_strongbox_settings()
    storage.strongboxes.spawn_chance = lib.runtime_setting_value_as_number "strongbox-spawn-chance"
    storage.strongboxes.loot_scale = lib.runtime_setting_value_as_number "strongbox-loot-scale"
end

---Attempt to spawn a strongbox at a given pos.
---@param surface LuaSurface
---@param pos MapPosition
---@param loot_scale number|nil
---@return LuaEntity|nil
function strongboxes.try_spawn(surface, pos, loot_scale)
    if math.random() > storage.strongboxes.spawn_chance then return end
    if not loot_scale then loot_scale = 1 end
    return strongboxes.spawn(surface, pos, 1, loot_scale)
end

---Forcibly spawn a strongbox at a given pos.
---@param surface LuaSurface
---@param pos MapPosition
---@param tier int
---@param loot_scale number|nil
---@return LuaEntity|nil
function strongboxes.spawn(surface, pos, tier, loot_scale)
    if not loot_scale then loot_scale = 1 end

    local sb_entity = surface.create_entity {
        name = "strongbox-tier-" .. tier,
        position = pos,
        force = "enemy",
    }

    if not sb_entity then
        lib.log_error("strongboxes.spawn: Failed to spawn strongbox")
        return
    end

    strongboxes.insert_loot(sb_entity, loot_scale)

    return sb_entity
end

---Get the Coin object to be placed in a strongbox.
---@param sb_entity LuaEntity
---@param loot_scale number
---@return Coin
function strongboxes.get_loot(sb_entity, loot_scale)
    local coin_value = loot_scale * 0.001 * sb_entity.max_health ^ 1.2
    coin_value = math.ceil(0.5 + coin_value * storage.strongboxes.loot_scale * storage.item_buffs.strongbox_loot)

    return coin_tiers.from_base_value(coin_value)
end

---Insert loot into a strongbox, clearing whatever it had before.
---@param sb_entity LuaEntity
---@param loot_scale number
function strongboxes.insert_loot(sb_entity, loot_scale)
    local inv = sb_entity.get_inventory(defines.inventory.chest)
    if not inv then return end
    inv.clear()

    local coin_loot = strongboxes.get_loot(sb_entity, loot_scale)
    inventories.add_coin_to_inventory(inv, coin_loot)
end



return strongboxes
