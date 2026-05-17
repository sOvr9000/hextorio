
-- Simple API for unlocking features throughout the game.
-- Events are listened to by other modules to handle the effects of unlocking features.

local lib = require "api.lib"
local sets = require "api.sets"
local event_system = require "api.event_system"

local features = {}



---@alias FeatureName
---| "catalog"
---| "enhance-all"
---| "generator-mode"
---| "hex-core-deletion"
---| "hex-rank"
---| "hexports"
---| "item-buff-enhancement"
---| "item-buffs"
---| "locomotive-trading"
---| "piggy-bank"
---| "quantum-bazaar"
---| "quick-trading"
---| "resource-conversion"
---| "sink-mode"
---| "spider-network"
---| "supercharging"
---| "teleportation-cross-planet"
---| "teleportation"
---| "trade-configuration"
---| "trade-overview"



---@class FeaturesStorage
---@field unlocked_features {[FeatureName]: boolean} Mapping of FeatureName to whether that feature has been unlocked.
---@field feature_name_lookup {[FeatureName]: boolean} Mapping of FeatureName to whether that feature exists as an available feature in the game.



function features.register_events()
    event_system.register("command-unlock-feature", function(player, params)
        local feature_name = params[1]
        if not feature_name then return end

        if not features.is_valid_feature_name(feature_name) then
            player.print {"hextorio.command-invalid-feature", feature_name}
            return
        end

        features.unlock_feature(feature_name)
        player.print {"hextorio.command-feature-unlocked", lib.color_localized_string(features.get_feature_localized_name(feature_name), "orange", "heading-1")}
    end)
end

---@return FeaturesStorage
function features._get_features_storage()
    local f_storage = storage.features
    if not f_storage then
        f_storage = {}
        storage.features = f_storage
    end

    if not f_storage.unlocked_features then
        f_storage.unlocked_features = {}
    end

    if not f_storage.feature_name_lookup then
        -- is there some way to not have to duplicate the entire list from the alias?
        f_storage.feature_name_lookup = sets.new {
            "catalog",
            "enhance-all",
            "generator-mode",
            "hex-core-deletion",
            "hex-rank",
            "hexports",
            "item-buff-enhancement",
            "item-buffs",
            "locomotive-trading",
            "piggy-bank",
            "quantum-bazaar",
            "quick-trading",
            "resource-conversion",
            "sink-mode",
            "spider-network",
            "supercharging",
            "teleportation-cross-planet",
            "teleportation",
            "trade-configuration",
            "trade-overview",
        }
    end

    return f_storage
end

---Return a lookup table of valid features in the game.
---@return {[FeatureName]: boolean}
function features.get_valid_features()
    local f_storage = features._get_features_storage()
    return f_storage.feature_name_lookup
end

---Unlock a feature.
---@param feature_name FeatureName
function features.unlock_feature(feature_name)
    if not features.is_valid_feature_name(feature_name) then
        lib.log_error("features.unlock_feature: Tried to unlock a feature that doesn't exist: " .. tostring(feature_name))
        return
    end

    local f_storage = features._get_features_storage()
    sets.add(f_storage.unlocked_features, feature_name)

    event_system.trigger("feature-unlocked", feature_name)
end

---Return whether a given feature has been unlocked by any quest.
---@param feature_name FeatureName
---@return boolean
function features.is_feature_unlocked(feature_name)
    local f_storage = features._get_features_storage()
    return sets.contains(f_storage.unlocked_features, feature_name)
end

---Return whether the given string is the name of an existing FeatureName.
---@param feature_name string
---@return boolean
function features.is_valid_feature_name(feature_name)
    local f_storage = features._get_features_storage()
    return sets.contains(f_storage.feature_name_lookup, feature_name)
end

---Get the localized string for the name of a feature.
---@param feature_name FeatureName
---@return {[1]: string}
function features.get_feature_localized_name(feature_name)
    return {"feature-name." .. feature_name}
end

---Get the localized string for the description of a feature.
---@param feature_name FeatureName
---@return {[1]: string}
function features.get_feature_localized_description(feature_name)
    return {"feature-description." .. feature_name}
end

---Add a new feature to the game.
---@param feature_name string
function features.register_feature_name(feature_name)
    if type(feature_name) ~= "string" then
        lib.log_error("features.register_feature_name: feature_name must be a string")
        return
    end

    local f_storage = features._get_features_storage()
    sets.add(f_storage.feature_name_lookup, feature_name)
end



return features
