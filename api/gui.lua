
local gui = {
    core_gui = require "api.gui.core_gui",
    questbook = require "api.gui.questbook_gui",
    trade_overview = require "api.gui.trade_overview_gui",
    catalog = require "api.gui.catalog_gui",
    hex_core = require "api.gui.hex_core_gui",

    trades = require "api.gui.trades_gui",
}



function gui.register_events()
    -- These are events from Hextorio gameplay, not those triggered by the player interacting with GUI elements.
    for _, v in pairs(gui) do
        if type(v) == "table" and v.register_events then
            v.register_events()
        end
    end
end

function gui.reinitialize_everything(player)
    for _, v in pairs(gui) do
        if type(v) == "table" and v.reinitialize then
            v.reinitialize(player)
        end
    end
end



return gui
