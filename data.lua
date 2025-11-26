
require "buff_discharge"
require "buff_destroyer"
require "buff_teslagun"
require "buff_defender"
require "buff_distractor"
require "prototypes.init"

local lib = require "api.lib"

-- Override title screen music.
if data.raw["ambient-sound"]["main-menu"] == nil then
    lib.log_error("data.lua: Could not find main menu ambient sound data. Another mod has removed it.")
else
    local title_screen_music = lib.startup_setting_value "title-screen-music"
    if title_screen_music ~= "vanilla" then
        data.raw["ambient-sound"]["main-menu"].sound = "__hextorio__/sound/" .. title_screen_music .. ".ogg"
    end
end
