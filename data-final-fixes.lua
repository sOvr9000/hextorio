
local lib = require "api.lib"

if lib.startup_setting_value_as_boolean "title-screen-background" then
    data.raw["utility-constants"]["default"].main_menu_simulations = nil
    data.raw["utility-constants"]["default"].main_menu_background_image_location = "__hextorio__/graphics/title-screen.png"
end
