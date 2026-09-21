
-- Factorio 2.1 introduced some kind of nerf to the recycler where all recycling recipes start as disabled until enabled by the recycling technology.
-- This script restores the original expected behavior where all recycling recipes start as enabled so that the quest that rewards a recycler is usable pre-Fulgora again.

local lib = require "api.lib"

for _, prot in pairs(data.raw["recipe"]) do
    if prot.categories and lib.table_index(prot.categories, "recycling") then
        prot.enabled = true
    end
end
