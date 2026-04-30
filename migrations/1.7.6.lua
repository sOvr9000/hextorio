
local lib = require "api.lib"
local strongboxes = require "api.strongboxes"

return function()
    local sb_entity_names = {}
    for _, prot in pairs(prototypes.entity) do
        log(prot.name)
        if prot.name:sub(1, 15) == "strongbox-tier-" then
            sb_entity_names[#sb_entity_names+1] = prot.name
        end
    end

    log(serpent.block(sb_entity_names))

    for _, surface in pairs(game.surfaces) do
        if lib.is_vanilla_planet_name(surface.name) then
            local sb_entities = surface.find_entities_filtered {
                name = sb_entity_names,
            }
            log(surface.name)
            log(#sb_entities)
            for _, sb_entity in pairs(sb_entities) do
                strongboxes.update_chart_tag(sb_entity)
            end
        end
    end

    for _, player in pairs(game.players) do
        for _, elem_name in pairs {"questbook-button", "catalog-button", "trade-overview-button", "hex-rank-button"} do
            local elem = player.gui.top[elem_name]
            if elem and elem.valid then
                elem.destroy()
            end
        end
    end
end
