
-- Management of terrain tiles in the game.

local lib = require "api.lib"
local axial = require "api.axial"
local tile_names = require "api.tile_names"

local terrain = {}



-- Set the tile type for a specific position
function terrain.set_tile(surface, position, tile_type)
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]
    if not surface then
        lib.log_error("terrain.set_tile: Invalid surface")
        return
    end

    surface.set_tiles({{name = tile_type, position = position}})
end

---Set the tile type for a list of positions
---@param surface SurfaceIdentification
---@param positions MapPosition[]
---@param tile_type string
---@param ignore_tiles {[string]: boolean} | nil
---@param quality string|nil
function terrain.set_tiles(surface, positions, tile_type, ignore_tiles, quality)
    if not ignore_tiles then ignore_tiles = {} end
    if not quality then quality = "normal" end
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]
    if not surface then
        lib.log_error("terrain.set_tiles: Invalid surface")
        return
    end

    local tiles = {}
    for _, position in pairs(positions) do
        local cur_tile = surface.get_tile(position.x or position[1], position.y or position[2])
        if not cur_tile.valid or not ignore_tiles[cur_tile.name] then
            table.insert(tiles, {name = tile_type, position = position})
        end
    end
    surface.set_tiles(tiles)

    if tile_names.can_spawn_fish(tile_type) then
        local num_fish_tiles = math.floor(#tiles * (0.008 + math.random() * 0.004) + 0.5)
        for i = 1, num_fish_tiles do
            if #tiles == 0 then break end
            local tile = table.remove(tiles, math.random(1, #tiles))
            local fish = surface.create_entity({name = "fish", position = tile.position, quality = quality})
            -- I can try to spawn them with quality, but they won't have quality.  Oops.
        end
    end
end

-- Set all tiles within a hex to tile_type
function terrain.set_hex_tiles(surface, hex_pos, tile_type, overwrite_water)
    if tile_type == "none" then return end

    if overwrite_water == nil then
        overwrite_water = true
    end

    local transformation = terrain.get_surface_transformation(surface)
    if not transformation then
        lib.log_error("No transformation found for surface " .. serpent.line(surface))
        return
    end

    local positions = axial.get_hex_tile_positions(hex_pos, transformation.scale, transformation.rotation, transformation.stroke_width)

    terrain.set_tiles(surface, positions, tile_type, storage.hex_grid.gleba_ignore_tiles)
end

-- Generate tiles along the border of a hex
function terrain.generate_hex_border(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width, ignore_tiles, quality)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0
    stroke_width = stroke_width or 3
    quality = quality or "normal"
    ignore_tiles = ignore_tiles or {}

    local corners = axial.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)
    local border_tiles = axial.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width)

    local surface_id = lib.get_surface_id(surface)
    surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("hex_grid.generate_hex_border: Cannot find surface from " .. serpent.line(surface))
        return
    end

    -- Set all border tiles to the non-land tile for the surface
    local tile_type
    if surface.name == "nauvis" then
        tile_type = "water"
    elseif surface.name == "vulcanus" then
        tile_type = "lava-hot"
    elseif surface.name == "fulgora" then
        tile_type = "oil-ocean-shallow"
    elseif surface.name == "gleba" then
        tile_type = "gleba-deep-lake"
    elseif surface.name == "aquilo" then
        tile_type = "ammoniacal-ocean"
    else
        tile_type = "water"
    end

    terrain.set_tiles(surface, border_tiles, tile_type, ignore_tiles, quality)

    if surface.name == "nauvis" and lib.runtime_setting_value "nauvis-filled-edges" then
        terrain.set_tiles(surface, border_tiles, "hazard-concrete-left", ignore_tiles, quality)
    end
end

---@param surfaceID SurfaceIdentification|LuaSurface|string
---@return {scale:number, rotation:number, stroke_width:number}
function terrain.get_surface_transformation(surfaceID)
    local surface_id = lib.get_surface_id(surfaceID)
    surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("Cannot find surface from " .. serpent.line(surfaceID))
        return {
            scale = 24,
            rotation = 0,
            stroke_width = 5,
        }
    end

    local surface_name = surface.name

    local transformations = storage.hex_grid.surface_transformations
    local transformation = transformations[surface_id]
    if not transformation then
        transformation = {}
        transformations[surface_id] = transformation
    end

    if not transformation.scale then
        transformation.scale = lib.startup_setting_value("hex-size-" .. surface_name)
        if not transformation.scale then
            transformation.scale = 24
        end
    end

    if not transformation.rotation then
        local mode = lib.startup_setting_value("grid-rotation-mode-" .. surface_name)
        if mode == "random" then
            transformation.rotation = math.random() * math.pi
        elseif mode == "flat-top" then
            transformation.rotation = math.pi * 0.5
        elseif mode == "pointed-top" then
            transformation.rotation = 0
        else
            transformation.rotation = 0
        end
    end

    if not transformation.stroke_width then
        transformation.stroke_width = lib.startup_setting_value("hex-stroke-width-" .. surface_name)
        if not transformation.stroke_width then
            transformation.stroke_width = 5
        end
    end

    return transformation
end

function terrain.generate_non_land_tiles(surface, hex_pos)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.generate_non_land_tiles: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    local tile_type
    if surface.name == "nauvis" then
        tile_type = "deepwater"
    elseif surface.name == "vulcanus" then
        tile_type = "lava"
    elseif surface.name == "fulgora" then
        tile_type = "oil-ocean-deep"
    elseif surface.name == "gleba" then
        tile_type = "gleba-deep-lake"
    elseif surface.name == "aquilo" then
        tile_type = "ammoniacal-ocean-2"
    end

    terrain.set_hex_tiles(surface, hex_pos, tile_type, true)
end

---Fill edges between adjacent claimed hexes using sum of squared distances method
---@param surface LuaSurface
---@param hex_pos1 HexPos
---@param hex_pos2 HexPos
---@param tile_type string
function terrain.fill_edges_between_hexes(surface, hex_pos1, hex_pos2, tile_type)
    local transformation = terrain.get_surface_transformation(surface)
    if not transformation then
        lib.log_error("terrain.fill_edges_between_hexes: No transformation found")
        return
    end

    -- centers of both hexes in rectangular coordinates
    local center1 = axial.get_hex_center(hex_pos1, transformation.scale, transformation.rotation)
    local center2 = axial.get_hex_center(hex_pos2, transformation.scale, transformation.rotation)

    -- Calculate squared distance between centers
    local dx = center1.x - center2.x
    local dy = center1.y - center2.y
    local center_dist_squared = dx * dx + dy * dy

    -- Calculate threshold based on center distance and hex radius
    -- Dynamically calculate the threshold multiplier using the formula: 2/(d/r)²
    -- Where d is center_dist and r is hex_radius (transformation.scale)
    local hex_radius = transformation.scale
    local center_dist = math.sqrt(center_dist_squared)
    local threshold_multiplier = 2 / ((center_dist / hex_radius) * (center_dist / hex_radius))

    -- Calculate the threshold
    local threshold = center_dist_squared * threshold_multiplier

    if surface.name == "fulgora" then
        threshold = threshold * 0.78
    end

    -- Get border tiles for both hexes
    local corners1 = axial.get_hex_corners(hex_pos1, transformation.scale, transformation.rotation)
    local corners2 = axial.get_hex_corners(hex_pos2, transformation.scale, transformation.rotation)
    local border_tiles1 = axial.get_hex_border_tiles_from_corners(corners1, transformation.scale, transformation.stroke_width)
    local border_tiles2 = axial.get_hex_border_tiles_from_corners(corners2, transformation.scale, transformation.stroke_width)

    -- Combine border tiles
    local all_border_tiles = {}
    for _, tile in pairs(border_tiles1) do
        table.insert(all_border_tiles, tile)
    end
    for _, tile in pairs(border_tiles2) do
        table.insert(all_border_tiles, tile)
    end

    -- Find water tiles that meet the sum of squared distances criteria
    local edge_tiles = {}
    for _, tile in pairs(all_border_tiles) do
        -- Calculate sum of squared distances to both centers
        local d1_squared = (tile.x - center1.x) * (tile.x - center1.x) + (tile.y - center1.y) * (tile.y - center1.y)
        local d2_squared = (tile.x - center2.x) * (tile.x - center2.x) + (tile.y - center2.y) * (tile.y - center2.y)
        local sum_squared = d1_squared + d2_squared

        -- Check if the tile meets the threshold criteria
        if sum_squared <= threshold then
            -- Check if it's a water tile
            local game_tile = surface.get_tile(tile.x, tile.y)
            if game_tile and game_tile.valid and tile_names.is_nonland_tile(game_tile.name) then
                table.insert(edge_tiles, {x = tile.x, y = tile.y})
            end
        end
    end

    -- Fill the edge tiles
    if #edge_tiles > 0 then
        terrain.set_tiles(surface, edge_tiles, tile_type)
    end
end

-- Finds and fills corners where three claimed hexes meet
function terrain.fill_corners_between_hexes(surface, hex_pos1, hex_pos2, hex_pos3, tile_type)
    local transformation = terrain.get_surface_transformation(surface)
    if not transformation then
        lib.log_error("hex_grid.fill_corners_between_claimed_hexes: No transformation found")
        return
    end

    -- Get centers of all three hexes
    local center0 = axial.get_hex_center(hex_pos1, transformation.scale, transformation.rotation)
    local center1 = axial.get_hex_center(hex_pos2, transformation.scale, transformation.rotation)
    local center2 = axial.get_hex_center(hex_pos3, transformation.scale, transformation.rotation)

    -- Get corners for all three hexes
    local corners0 = axial.get_hex_corners(hex_pos1, transformation.scale, transformation.rotation)
    local corners1 = axial.get_hex_corners(hex_pos2, transformation.scale, transformation.rotation)
    local corners2 = axial.get_hex_corners(hex_pos3, transformation.scale, transformation.rotation)

    -- Find the common corner among all three hexes
    local common_corner = nil
    local tolerance = 0.01

    for _, c0 in pairs(corners0) do
        for _, c1 in pairs(corners1) do
            if math.abs(c0.x - c1.x) < tolerance and math.abs(c0.y - c1.y) < tolerance then
                -- c0 and c1 are the same corner, check if it's also in corners2
                for _, c2 in pairs(corners2) do
                    if math.abs(c0.x - c2.x) < tolerance and math.abs(c0.y - c2.y) < tolerance then
                        -- Found a corner common to all three hexes
                        common_corner = {x = (c0.x + c1.x + c2.x) / 3, y = (c0.y + c1.y + c2.y) / 3}
                        break
                    end
                end

                if common_corner then break end
            end
        end

        if common_corner then break end
    end

    if common_corner then
        -- Get border tiles for all three hexes
        local border_tiles0 = axial.get_hex_border_tiles_from_corners(corners0, transformation.scale, transformation.stroke_width)
        local border_tiles1 = axial.get_hex_border_tiles_from_corners(corners1, transformation.scale, transformation.stroke_width)
        local border_tiles2 = axial.get_hex_border_tiles_from_corners(corners2, transformation.scale, transformation.stroke_width)

        -- Combine all border tiles
        local all_border_tiles = {}
        for _, tile in pairs(border_tiles0) do table.insert(all_border_tiles, tile) end
        for _, tile in pairs(border_tiles1) do table.insert(all_border_tiles, tile) end
        for _, tile in pairs(border_tiles2) do table.insert(all_border_tiles, tile) end

        -- Calculate distance from each center to the common corner
        local dist0 = math.sqrt((common_corner.x - center0.x)^2 + (common_corner.y - center0.y)^2)
        local dist1 = math.sqrt((common_corner.x - center1.x)^2 + (common_corner.y - center1.y)^2)
        local dist2 = math.sqrt((common_corner.x - center2.x)^2 + (common_corner.y - center2.y)^2)

        -- Average distance squared
        local avg_dist_squared = (dist0^2 + dist1^2 + dist2^2) / 3

        -- Radius for corner detection - slightly smaller than average distance
        local corner_radius_squared = avg_dist_squared * 0.85

        -- Find tiles close to the common corner
        local corner_tiles = {}
        for _, tile in pairs(all_border_tiles) do
            -- Distance from tile to corner
            local corner_dist_squared = (tile.x - common_corner.x)^2 + (tile.y - common_corner.y)^2

            -- If tile is close to corner
            if corner_dist_squared < corner_radius_squared * 0.5 then
                -- Check if it's a water tile
                local game_tile = surface.get_tile(tile.x, tile.y)
                if game_tile and game_tile.valid and tile_names.is_nonland_tile(game_tile.name) then
                    table.insert(corner_tiles, {x = tile.x, y = tile.y})
                end
            end
        end

        -- Fill the corner tiles
        if #corner_tiles > 0 then
            terrain.set_tiles(surface, corner_tiles, tile_type)
        end
    end
end




return terrain

