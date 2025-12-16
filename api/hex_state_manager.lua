
local lib = require "api.lib"

local hex_state_manager = {}



---@alias HexStateMap {[int]: {[int]: HexState}}
---@alias HexCoreMode "normal"|"sink"|"generator"

---@class HexPos
---@field q int
---@field r int

---@class HexPoolParameters
---@field surface_id int
---@field hex_pos HexPos

---@class HexCoreStats
---@field total_items_produced QualityItemCounts
---@field total_items_consumed QualityItemCounts
---@field total_coins_produced Coin
---@field total_coins_consumed Coin

---@class HexState
---@field position HexPos The position of this hex state.
---@field flat_index int|nil The index of the coordinates pointing to this hex state in its surface's flattened array of existing, generated hex coordinates.
---@field claimed boolean|nil Whether this hex state has been claimed yet.
---@field trades int[]|nil A list of trade IDs that this state contains.
---@field hex_core LuaEntity|nil The associated hex core entity of this hex state.
---@field input_loaders LuaEntity[]|nil The loader entities for loading this state's hex core.
---@field output_loaders LuaEntity[]|nil The loader entities for unloading this state's hex core.
---@field mode HexCoreMode|nil The current mode of this hex state.
---@field generated boolean|nil Whether this hex state has been generated yet with hex_grid.initialize_hex().
---@field is_dungeon boolean|nil Whether this hex state currently belongs to a dungeon.
---@field was_dungeon boolean|nil Whether this hex state previously belonged to a dungeon, which was looted.
---@field is_land boolean|nil Whether this hex is supposed to contain land tiles.
---@field deleted boolean|nil Whether the hex core of this hex state has been deleted after it has spawned.
---@field is_starting_hex boolean|nil Whether this hex state belongs to the starting hex of its planet.
---@field is_biters boolean|nil Whether this hex is supposed to contain biters.
---@field is_pentapods boolean|nil Whether this hex is supposed to contain pentapods.
---@field is_resources boolean|nil Whether this hex is supposed to contain resource entities.
---@field is_well boolean|nil Whether this hex is supposed to contain resource wells like crude oil or fluorine vents.
---@field is_infinite boolean|nil Whether the resource entities or wells in this hex were turned infinite.
---@field output_buffer QualityItemCounts|nil The numbers of items per quality name waiting to unload into the inventory of this hex state's hex core.
---@field total_items_sold QualityItemCounts|nil The total items consumed by the trades in this hex state's hex core.
---@field total_items_bought QualityItemCounts|nil The total items produced by the trades in this hex state's hex core.
---@field total_coins_produced Coin|nil The total coins produced by the trades in this hex state's hex core.
---@field total_coins_consumed Coin|nil The total coins consumed by the trades in this hex state's hex core.
---@field resources {[string]: int}|nil Initial counts of resources in this hex.
---@field ore_entities LuaEntity[]|nil The ore entities in this hex.
---@field claim_price Coin|nil The calculated cost to claim this hex.
---@field claimed_by string|nil The name of the player that claimed this hex. If claimed == true and claimed_by == nil, then this hex was claimed in a different way.
---@field claimed_timestamp int|nil The game tick during which this hex was claimed.
---@field is_in_claim_queue boolean|nil Whether this hex is currently in the queue to be claimed.
---@field is_active boolean|nil Whether this hex state is currently active in trading. Activity in trading means the hex core has at least one item in its input inventory, where frequent, periodic calculations are made to determine whether trades can be made. This field is used in managing the load balancer for distributed hex state processing.
---@field hex_core_input_inventory LuaInventory|nil The inventory used for giving items to trades, typically the hex core's inventory itself.
---@field hex_core_output_inventory LuaInventory|nil The inventory used for receiving items from trades, typically the hex core's inventory itself.
---@field hexport LuaEntity|nil The hexport (custom roboport) built into this hex state's hex core.
---@field hexlight LuaEntity|nil The first of two hexlights (custom lamps) built into this hex state's hex core.
---@field hexlight2 LuaEntity|nil The second of two hexlights (custom lamps) built into this hex state's hex core.
---@field send_outputs_to_cargo_wagons boolean|nil Whether trains keep the results of their trading in their cargo wagons.
---@field allow_locomotive_trading boolean|nil Whether trains are currently allowed to make trades with this hex state's hex core by stopping at train stops in the same hex.
---@field tags_created int|nil The number of tags created on the map for trades at this hex state's hex core. Starts counting at 0, so 0 means 1 tag has been created, etc.



---Get a hex state at a flat index on a surface.
---@param surface_id int
---@param flat_index int
---@return HexState|nil
function hex_state_manager.get_hex_from_flat_index(surface_id, flat_index)
    local surface_hexes = storage.hex_grid.flattened_surface_hexes[surface_id]
    if not surface_hexes then return end
    local pos = surface_hexes[flat_index]
    if not pos then return end
    return hex_state_manager.get_hex_state(surface_id, pos)
end

---Get a series of hex states at a flat index on a surface.
---@param surface_id int
---@param from_index int
---@param to_index int
---@return HexState[]
function hex_state_manager.get_hexes_from_flat_indices(surface_id, from_index, to_index)
    local surface_hexes = storage.hex_grid.flattened_surface_hexes[surface_id]
    if not surface_hexes then return {} end

    local len = 0
    local states = {}

    for index = from_index, to_index do
        local pos = surface_hexes[index]
        if pos then
            local state = hex_state_manager.get_hex_state(surface_id, pos)
            if state then
                len = len + 1
                states[len] = state
            end
        end
    end

    return states
end

---Get the state of a hex on a specific surface.  Only returns nil if the surface does not exist or the surface is a space platform.
---@param surface SurfaceIdentification
---@param hex_pos HexPos
---@return HexState|nil
function hex_state_manager.get_hex_state(surface, hex_pos)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then return end

    local surface_obj = game.get_surface(surface_id)
    if not surface_obj or lib.is_space_platform(surface_obj.name) then return end

    local surface_hexes = hex_state_manager.get_surface_hexes(surface_id)
    if not surface_hexes then return end

    local state = hex_state_manager.get_hex_state_from_surface_hexes(surface_hexes, hex_pos)

    if not state.position then
        state.position = {q = hex_pos.q, r = hex_pos.r} -- copy position just in case
    end

    return state
end

---Get or create surface storage, failing if the surface does not exist or is a space platform.
---@param surface SurfaceIdentification
---@return HexStateMap|nil
function hex_state_manager.get_surface_hexes(surface)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.get_surface_hexes: surface not found: " .. tostring(surface))
        return
    end

    local surface_obj = game.get_surface(surface_id)
    if not surface_obj or lib.is_space_platform(surface_obj.name) then
        return
    end

    local surface_hexes = storage.hex_grid.surface_hexes[surface_id]
    if not surface_hexes then
        surface_hexes = {}
        storage.hex_grid.surface_hexes[surface_id] = surface_hexes
    end

    return surface_hexes
end

---Same as hex_state_manager.get_surface_hexes(), but the returned array is one-dimensional.
---@param surface SurfaceIdentification
---@return HexState[]
function hex_state_manager.get_flattened_surface_hexes(surface)
    local surface_hexes = hex_state_manager.get_surface_hexes(surface)
    if not surface_hexes then return {} end

    local flattened_surface_hexes = {}
    for _, Q in pairs(surface_hexes) do
        for _, state in pairs(Q) do
            table.insert(flattened_surface_hexes, state)
        end
    end

    return flattened_surface_hexes
end

---Get a hex by its axial coordinates in a surface's hex state map.  Defaults and sets to an empty hex state if the hex does not exist.
---@param surface_hexes HexStateMap
---@param hex_pos HexPos
---@return HexState
function hex_state_manager.get_hex_state_from_surface_hexes(surface_hexes, hex_pos)
    local Q = surface_hexes[hex_pos.q]
    if not Q then
        Q = {}
        surface_hexes[hex_pos.q] = Q
    end

    local state = Q[hex_pos.r]
    if not state then
        state = {position = hex_pos}
        Q[hex_pos.r] = state
    end

    return state
end



return hex_state_manager
