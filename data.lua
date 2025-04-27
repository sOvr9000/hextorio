
local lib = require "api.lib"
local sets = require "api.sets"
require "prototypes.init"

-- Override title screen music.
-- data.raw["ambient-sound"]["main-menu"].sound = "__hextorio__/sound/somethingwhatever.ogg"
-- (maybe later)

-- Disable planet discovery technologies until their hex tiles are implemented
data.raw["technology"]["planet-discovery-fulgora"].enabled = false
data.raw["technology"]["planet-discovery-gleba"].enabled = false
data.raw["technology"]["planet-discovery-vulcanus"].enabled = false


