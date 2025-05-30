
local sets = require "api.sets"

local tile_names = {}

tile_names.bad = {
    "out-of-map",
    "tile-unknown",
    "space-platform-foundation",
    "empty-space",
}

-- All vanilla tiles
tile_names.base = {
    "acid-refined-concrete",
    "black-refined-concrete",
    "blue-refined-concrete",
    "brown-refined-concrete",
    "concrete",
    "cyan-refined-concrete",
    "deepwater",
    "deepwater-green",
    "dirt-1",
    "dirt-2",
    "dirt-3",
    "dirt-4",
    "dirt-5",
    "dirt-6",
    "dirt-7",
    "dry-dirt",
    "grass-1",
    "grass-2",
    "grass-3",
    "grass-4",
    "green-refined-concrete",
    "hazard-concrete-left",
    "hazard-concrete-right",
    "lab-dark-1",
    "lab-dark-2",
    "lab-white",
    "landfill",
    "nuclear-ground",
    "orange-refined-concrete",
    "out-of-map",
    "pink-refined-concrete",
    "purple-refined-concrete",
    "red-desert-0",
    "red-desert-1",
    "red-desert-2",
    "red-desert-3",
    "red-refined-concrete",
    "refined-concrete",
    "refined-hazard-concrete-left",
    "refined-hazard-concrete-right",
    "sand-1",
    "sand-2",
    "sand-3",
    "stone-path",
    "tile-unknown",
    "tutorial-grid",
    "water",
    "water-green",
    "water-mud",
    "water-shallow",
    "water-wube",
    "yellow-refined-concrete"
}

-- Take out the bad tiles, you don't want to see these ones anywhere ever.
tile_names.base = sets.difference(sets.new(tile_names.base), sets.new(tile_names.bad))

-- All vanilla tiles (Space Age included)
tile_names.space_age = {
    "tile-unknown",
    "water-wube",
    "out-of-map",
    "deepwater",
    "deepwater-green",
    "water",
    "water-green",
    "water-shallow",
    "water-mud",
    "grass-1",
    "grass-2",
    "grass-3",
    "grass-4",
    "dry-dirt",
    "dirt-1",
    "dirt-2",
    "dirt-3",
    "dirt-4",
    "dirt-5",
    "dirt-6",
    "dirt-7",
    "sand-1",
    "sand-2",
    "sand-3",
    "red-desert-0",
    "red-desert-1",
    "red-desert-2",
    "red-desert-3",
    "nuclear-ground",
    "stone-path",
    "lab-dark-1",
    "lab-dark-2",
    "lab-white",
    "tutorial-grid",
    "concrete",
    "hazard-concrete-left",
    "hazard-concrete-right",
    "refined-concrete",
    "refined-hazard-concrete-left",
    "refined-hazard-concrete-right",
    "landfill",
    "red-refined-concrete",
    "green-refined-concrete",
    "blue-refined-concrete",
    "orange-refined-concrete",
    "yellow-refined-concrete",
    "pink-refined-concrete",
    "purple-refined-concrete",
    "black-refined-concrete",
    "brown-refined-concrete",
    "cyan-refined-concrete",
    "acid-refined-concrete",
    "empty-space",
    "space-platform-foundation",
    "foundation",
    "volcanic-jagged-ground",
    "lava",
    "lava-hot",
    "volcanic-cracks-hot",
    "volcanic-cracks-warm",
    "volcanic-cracks",
    "volcanic-folds-flat",
    "volcanic-ash-light",
    "volcanic-ash-dark",
    "volcanic-ash-flats",
    "volcanic-pumice-stones",
    "volcanic-smooth-stone",
    "volcanic-smooth-stone-warm",
    "volcanic-ash-cracks",
    "volcanic-folds",
    "volcanic-folds-warm",
    "volcanic-soil-dark",
    "volcanic-soil-light",
    "volcanic-ash-soil",
    "artificial-yumako-soil",
    "overgrowth-yumako-soil",
    "artificial-jellynut-soil",
    "overgrowth-jellynut-soil",
    "natural-yumako-soil",
    "natural-jellynut-soil",
    "lowland-olive-blubber",
    "lowland-olive-blubber-2",
    "lowland-olive-blubber-3",
    "lowland-brown-blubber",
    "lowland-pale-green",
    "lowland-cream-cauliflower-2",
    "lowland-cream-cauliflower",
    "lowland-dead-skin",
    "lowland-dead-skin-2",
    "lowland-cream-red",
    "lowland-red-vein-2",
    "lowland-red-vein",
    "lowland-red-vein-3",
    "lowland-red-vein-4",
    "lowland-red-vein-dead",
    "lowland-red-infection",
    "midland-cracked-lichen",
    "midland-cracked-lichen-dull",
    "midland-cracked-lichen-dark",
    "midland-turquoise-bark-2",
    "midland-turquoise-bark",
    "midland-yellow-crust-3",
    "midland-yellow-crust-2",
    "midland-yellow-crust",
    "midland-yellow-crust-4",
    "highland-dark-rock",
    "highland-dark-rock-2",
    "highland-yellow-rock",
    "pit-rock",
    "wetland-yumako",
    "wetland-jellynut",
    "wetland-dead-skin",
    "wetland-light-dead-skin",
    "wetland-green-slime",
    "wetland-light-green-slime",
    "wetland-red-tentacle",
    "wetland-pink-tentacle",
    "wetland-blue-slime",
    "gleba-deep-lake",
    "fulgoran-dust",
    "fulgoran-dunes",
    "fulgoran-sand",
    "fulgoran-rock",
    "fulgoran-paving",
    "fulgoran-walls",
    "fulgoran-conduit",
    "fulgoran-machinery",
    "oil-ocean-shallow",
    "oil-ocean-deep",
    "ammoniacal-ocean",
    "ammoniacal-ocean-2",
    "snow-flat",
    "dust-flat",
    "snow-crests",
    "dust-crests",
    "snow-lumpy",
    "dust-lumpy",
    "snow-patchy",
    "dust-patchy",
    "ice-rough",
    "ice-smooth",
    "ice-platform",
    "brash-ice",
    "frozen-concrete",
    "frozen-hazard-concrete-left",
    "frozen-hazard-concrete-right",
    "frozen-refined-concrete",
    "frozen-refined-hazard-concrete-left",
    "frozen-refined-hazard-concrete-right"
}

tile_names.space_age = sets.difference(sets.new(tile_names.space_age), sets.new(tile_names.bad))

-- Tiles that are only in space-age
tile_names.space_age_exclusive = sets.to_array(sets.difference(sets.new(tile_names.space_age), sets.new(tile_names.base)))

-- Tiles that are not land tiles
tile_names.non_land = {
    "deepwater",
    "deepwater-green",
    "water",
    "water-green",
    "water-mud",
    "water-shallow",
    "water-wube",
}

-- Tiles that are not land tiles in Space Age and base
tile_names.space_age_non_land = {
    "deepwater",
    "deepwater-green",
    "water",
    "water-green",
    "water-mud",
    "water-shallow",
    "water-wube",
    "lava",
    "lava-hot",
    "wetland-yumako",
    "wetland-jellynut",
    "wetland-dead-skin",
    "wetland-light-dead-skin",
    "wetland-green-slime",
    "wetland-light-green-slime",
    "wetland-red-tentacle",
    "wetland-pink-tentacle",
    "wetland-blue-slime",
    "gleba-deep-lake",
    "oil-ocean-shallow",
    "oil-ocean-deep",
    "ammoniacal-ocean",
    "ammoniacal-ocean-2",
    "brash-ice",
}

-- Tiles that are not land tiles in Space Age only
tile_names.space_age_exclusive_non_land = sets.to_array(sets.difference(sets.new(tile_names.space_age_non_land), sets.new(tile_names.non_land)))

-- All land tiles in base
tile_names.land = sets.to_array(sets.difference(sets.new(tile_names.base), sets.new(tile_names.non_land)))

-- All land tiles in Space Age and base
tile_names.space_age_land = sets.to_array(sets.difference(sets.new(tile_names.space_age), sets.new(tile_names.space_age_non_land)))

-- All land tiles in Space Age only
tile_names.space_age_exclusive_land = sets.to_array(sets.difference(sets.new(tile_names.space_age_exclusive), sets.new(tile_names.space_age_non_land)))



-- Generate lookup tables
tile_names.lookup = {}
for key, arr in pairs(tile_names) do
    if key ~= "lookup" then
        tile_names.lookup[key] = sets.new(arr)
    end
end



---@param name string
---@return boolean
function tile_names.is_land_tile(name)
    return tile_names.lookup.space_age_land[name] == true
end

---@param name string
---@return boolean
function tile_names.is_nonland_tile(name)
    return tile_names.lookup.space_age_non_land[name] == true
end

---@param name string
---@return boolean
function tile_names.can_spawn_fish(name)
    return name == "water" or name == "deepwater"
end



return tile_names
