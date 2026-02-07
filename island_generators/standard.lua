
-- Generates a snowflake-like island.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"



return function(params)
    local radius = params.radius or 30
    local fill_ratio = params.fill_ratio or 0.866

    -- Initialize hex set.
    local set = hex_sets.new()
    local current_size = 0
    local max_size = 3 * radius * (radius + 1) + 1
    local target_size = math.ceil(max_size * fill_ratio)

    -- Initialize the open set.
    local open_list = {}
    local open_set = hex_sets.new()

    -- Guarantee some nonland tiles
    local blacklist = hex_sets.new()

    for i = 1, 5 do
        local ring = axial.ring({q=0, r=0}, i)
        local idx = math.random(1, #ring)
        local pos = ring[idx]
        if i > 1 and (pos.q == -pos.r or pos.q ~= 0 and pos.r == 0 or pos.r ~= 0 and pos.q == 0) then
            -- The randomly selected hex on the ring is on a line going out to a vertex of the giant hex island
            if math.random() < 0.5 then
                idx = idx + 1
            else
                idx = idx - 1
            end
            pos = ring[1 + (idx - 1) % #ring]
        end
        hex_sets.add(blacklist, pos)
    end

    -- Misc parameters
    -- local radius_inv = 1 / radius

    -- Helper function for managing the open set, island construction, and stopping condition.
    local function add_hex(pos)
        if hex_sets.add(set, pos) then
            current_size = current_size + 1

            local adj_list = axial.get_adjacent_hexes(pos)
            for i, adj in ipairs(adj_list) do
                local dist = axial.distance(adj, {q=0, r=0})
                if dist <= radius then
                    if not hex_sets.contains(set, adj) and not hex_sets.contains(open_set, adj) and not hex_sets.contains(blacklist, adj) then
                        hex_sets.add(open_set, adj)
                        table.insert(open_list, adj)
                    end
                end
            end
        end
        return current_size >= target_size
    end

    -- Draw lines along the three diameters.
    for i = -radius, radius do
        for _, pos in pairs {
            {q = i, r = 0},
            {q = i, r = -i},
            {q = 0, r = i},
        } do
            if not hex_sets.contains(blacklist, pos) then
                add_hex(pos)
            end
        end
    end

    -- Randomly sample from the open set.
    for i = 1, target_size do
        if not next(open_list) then break end

        local idx = math.random(1, #open_list)

        -- -- Construct weights for sampling
        -- local weights = {}
        -- local total_weight = 0
        -- for j, pos in ipairs(open_list) do
        --     local weight = 1
        --     for _, adj in pairs(axial.get_adjacent_hexes(pos)) do
        --         if hex_sets.contains(set, adj) then
        --             weight = weight * 0.1
        --         end
        --     end
        --     weights[j] = weight
        --     total_weight = total_weight + weight
        -- end

        -- -- Non-uniform sample such that more distant hexes are more likely to be sampled.
        -- local r = math.random() * total_weight
        -- local cur_w = 0
        -- local idx = 0
        -- for j, w in ipairs(weights) do
        --     cur_w = cur_w + w
        --     if cur_w >= r then
        --         idx = j
        --         break
        --     end
        -- end

        local pos = table.remove(open_list, idx)
        hex_sets.remove(open_set, pos)

        if add_hex(pos) then break end
    end

    return set
end


