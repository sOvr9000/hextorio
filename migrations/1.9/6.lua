
return function()
    -- Saves that were created before the hex grid was aligned to the tile grid (hextorio < 1.9.6) keep the geometry that their terrain was built with.
    storage.hex_grid.continuous_geometry = true
end
