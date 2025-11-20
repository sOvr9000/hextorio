
require "buff_discharge"
require "buff_destroyer"
require "buff_teslagun"
require "buff_defender"
require "buff_distractor"
require "prototypes.init"

-- Override title screen music.
local title_screen_music = require("api.lib").startup_setting_value "title-screen-music"
if title_screen_music ~= "vanilla" then
    data.raw["ambient-sound"]["main-menu"].sound = "__hextorio__/sound/" .. title_screen_music .. ".ogg"
end
