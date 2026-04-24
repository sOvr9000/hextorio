
local lib          = require "api.lib"
local event_system = require "api.event_system"

local translations = {}



---@param loc_string LocalisedString
---@return string|nil
local function get_string_from_localized_string(loc_string)
    if not loc_string then return end

    if type(loc_string) == "string" then
        return loc_string
    end

    local str = loc_string[1]
    if str and type(str) == "string" then
        return str
    end
end



function translations.register_events()
    event_system.register("string-translated", function(event)
        ---@cast event EventData.on_string_translated

        local from_string = get_string_from_localized_string(event.localised_string)
        if not from_string then
            lib.log_error("Failed to index string: " .. serpent.line(event.localised_string))
            return
        end

        local to_string = event.result
        local player_index = event.player_index

        local player_translations = translations.get_player_translations_table(player_index)
        player_translations[from_string] = to_string
    end)
end

function translations.init()
    lib.log("Clearing translation cache for all players.")

    local translations_storage = storage.translations
    if not translations_storage then
        translations_storage = {}
        storage.translations = translations_storage
    end

    translations_storage.player_translations = {} -- Wipe all previous translation data and regenerate as needed.
    translations.populate_to_translate()
end

---Get an item's display name.
---@param translations_table {[string]: string}
---@param item_name string
---@return string|nil
function translations.get_item_name_translation(translations_table, item_name)
    local prot = prototypes.item[item_name]
    if not prot then return end

    local str = get_string_from_localized_string(prot.localised_name)
    if not str then return end

    return translations_table[str]
end

function translations.populate_to_translate()
    local translations_storage = storage.translations
    if not translations_storage then
        translations_storage = {}
        storage.translations = translations_storage
    end

    local to_translate = {}
    for _, prot in pairs(prototypes.item) do
        to_translate[#to_translate+1] = prot.localised_name
    end

    translations_storage.to_translate = to_translate
end

---Request translations for a player.
---@param player LuaPlayer
function translations.request_translations(player)
    local translations_storage = storage.translations
    if not translations_storage then
        translations_storage = {}
        storage.translations = translations_storage
    end

    local to_translate = translations_storage.to_translate
    if not to_translate then
        translations.populate_to_translate()
        to_translate = translations_storage.to_translate
    end

    player.request_translations(to_translate)
end

---Get the table of all cached translations for a player.
---@param player_index int
---@return {[string]: string}
function translations.get_player_translations_table(player_index)
    local translations_storage = storage.translations
    if not translations_storage then
        translations_storage = {}
        storage.translations = translations_storage
    end

    local player_translations_storage = translations_storage.player_translations
    if not player_translations_storage then
        player_translations_storage = {}
        translations_storage.player_translations = player_translations_storage
    end

    local player_translations = player_translations_storage[player_index]
    if not player_translations then
        player_translations = {}
        player_translations_storage[player_index] = player_translations
    end

    return player_translations
end



return translations
