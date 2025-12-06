
-- Management of the Sentient Spider entity(-ies).
-- Spider magic.



local sets = require "api.sets"
local event_system = require "api.event_system"
local axial        = require "api.axial"
local lib          = require "api.lib"



local spiders = {}



local function collapse_chunk_index(x, y)
    -- No one's building 10k chunks out from spawn, and this allows for a total of ~100M unique chunk indices.
    return (x + 10000) * 20001 + (y + 10000)
end

---Register events for spider management.
function spiders.register_events()
    event_system.register("entity-built", function(entity)
        if entity.name == "entity-ghost" or entity.name == "tile-ghost" then
            spiders.track_ghost(entity)
        elseif storage.spiders.valid_entity_names[entity.name] then
            spiders.index_entity(entity)
        end
    end)
end

---Initialize the API.
function spiders.init()
    storage.spiders.spiders = {} --[[@as {[int]: Spider}]]
    storage.spiders.server_ais = {} --[=[@as SpiderServerAI[]]=]

    -- For now, there's only one server AI. But this can be expanded as forces are added to the game (not the case for Hextorio).
    storage.spiders.server_ais[game.forces.player.index] = {

    }
end

---Redefine the indexing for each spider based on what's currently placed across all surfaces.
function spiders.reindex_spiders()
    local valid_entity_names = sets.to_array(storage.spiders.valid_entity_names)
    for surface_id, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered {
            name = valid_entity_names,
        }
        for _, e in pairs(entities) do
            spiders.index_entity(e)
        end
    end
end

---Create a new Spider object.
---@param entity LuaEntity
---@return Spider
function spiders.new_spider(entity)
    return {
        entity = entity,
        unit_number = entity.unit_number,
        ai = spiders.new_client_ai(),
    }
end

---Create a new AI object.
---@return SpiderClientAI
function spiders.new_client_ai()
    local ai = {
        current_mode = "build",
    }

    return ai
end

function spiders.index_entity(entity)
    storage.spiders.spiders[entity.unit_number] = spiders.new_spider(entity)
end

---Get the SpiderServerAI for a force.
---@param force LuaForce
---@return SpiderServerAI|nil
function spiders.get_server_ai_for_force(force)
    return storage.spiders.server_ais[force.index]
end

---Get the SpiderServerAI for a spider.
---@param spider Spider
---@return SpiderServerAI|nil
function spiders.get_server_ai_for_spider(spider)
    local force = spider.entity.force --[[@as LuaForce]]
    return spiders.get_server_ai_for_force(force)
end

---Return whether the Spider object is still valid.
---@param spider Spider
---@return boolean
function spiders.is_spider_valid(spider)
    return spider.entity and spider.entity.valid
end

---Process all server AIs in the game.
function spiders.process_server_ais()
    for force_index, server_ai in pairs(storage.spiders.server_ais) do
        spiders.process_server_ai(server_ai)
    end
end

---Process a server AI.
---@param server_ai SpiderServerAI
function spiders.process_server_ai(server_ai)
    -- TODO
end

---Process a spider.
---@param spider Spider
function spiders.process_spider(spider)
    local ai = spider.client_ai
    if ai.current_mode == "build" then
        spiders.process_build_mode(spider)
    end
end

---Process the logic for build mode.
---@param spider Spider
function spiders.process_build_mode(spider)

end

---Set the mode for a spider's client AI.
---@param spider Spider
---@param new_mode SpiderClientAIMode
function spiders.set_client_ai_mode(spider, new_mode)
    spider.client_ai.current_mode = new_mode
end

---Take record of a ghost entity or tile.
---@param ghost LuaEntity
function spiders.track_ghost(ghost)
    local surface = ghost.surface
    if lib.is_space_platform(surface.name) then return end

    if not storage.spiders.blueprint_ghosts then
        storage.spiders.blueprint_ghosts = {}
    end

    local surface_id = surface.index
    local surface_ghosts = storage.spiders.blueprint_ghosts[surface_id]
    if not surface_ghosts then
        surface_ghosts = {}
        storage.spiders.blueprint_ghosts[surface_id] = surface_ghosts
    end

    local chunk_pos = lib.get_chunk_pos_from_tile_position(ghost.position)
    local ghosts_X = surface_ghosts[chunk_pos.x]
    if not ghosts_X then
        ghosts_X = {}
        surface_ghosts[chunk_pos.x] = ghosts_X
    end
    local ghosts = ghosts_X[chunk_pos.y]
    if not ghosts then
        ghosts = {}
        ghosts_X[chunk_pos.y] = ghosts
    end

    table.insert(ghosts, ghost)
end

function spiders.process_blueprint_ghosts()
    for surface_id, ghosts_X in pairs(game.surfaces) do
        
    end
end



return spiders


