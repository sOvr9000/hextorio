
local lib = require "api.lib"
local gui = require "api.gui"
local quests = require "api.quests"

local data_quests = require "data.quests"

local migrations = {}



local versions = {
    "0.0.1",
    "0.1.0",
    "0.1.1",
    "0.1.2",
    "0.1.3",
    "0.1.4",
    "0.1.5",
    "0.2.0",
    "0.2.1",
    "0.2.2",
    "0.2.3",
    "0.3.0",
    "0.3.1",
    "0.3.2",
    "0.4.0",
    "0.4.1",
    "0.4.2",
    "0.4.3",
    "1.0.0",
    "1.0.1",
    "1.0.2",
    "1.0.3",
    "1.0.4",
    "1.0.5",
    "1.0.6",
    "1.0.7",
    "1.0.8",
    "1.0.9",
    "1.0.10",
    "1.0.11",
    "1.0.12",
    "1.0.13",
    "1.0.14",
    "1.0.15",
    "1.0.16",
    "1.0.17",
    "1.0.18",
    "1.1.0",
    "1.1.1",
    "1.1.2",
    "1.1.3",
    "1.1.4",
    "1.2.0",
    "1.2.1",
    "1.3.0",
    "1.3.1",
    "1.3.2",
    "1.3.3",
    "1.3.4",
    "1.3.5",
    "1.3.6",
    "1.3.7",
    "1.3.8",
}

local version_stepping = {}
for i = 1, #versions - 1 do
    version_stepping[versions[i]] = versions[i + 1]
end

local handlers = {}

function migrations.load_handlers()
    for i = 1, #versions - 1 do
        handlers[versions[i]] = require("migrations/" .. versions[i] .. ".lua")
    end
end

function migrations.on_mod_updated(old_version, new_version)
    lib.log("Starting version migrations")

    -- Reinitialize quests
    lib.log("Reloading quests")
    storage.quests.quest_defs = data_quests.quest_defs
    quests.reinitialize_everything()

    lib.log("Checking migration for version " .. old_version .. " -> " .. new_version)
    local latest = versions[#versions]
    while true do
        if not old_version or old_version == latest or old_version == new_version then
            lib.log("Migrated to " .. old_version)
            break
        end
        local func = handlers[old_version]
        if not func then
            error("missing migration for " .. old_version .. " -> " .. version_stepping[old_version])
        end
        lib.log("migrating " .. old_version .. " -> " .. version_stepping[old_version])
        func()
        old_version = version_stepping[old_version]
    end

    -- Reinitialize GUIs
    lib.log("Reloading GUIs")
    for _, player in pairs(game.players) do
        gui.reinitialize_everything(player)
    end
end



return migrations


