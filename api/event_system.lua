
local lib = require "api.lib"

local event_system = {}


local funcs = {}

function event_system.register_callback(name, callback)
    -- storage.event_system.callbacks[name] = (storage.event_system.callbacks[name] or {})
    -- table.insert(storage.event_system.callbacks[name], callback)
    funcs[name] = (funcs[name] or {})
    table.insert(funcs[name], callback)
end

function event_system.trigger(name, ...)
    local callbacks = funcs[name]
    if not callbacks then
        lib.log_error("event_system.trigger: No callbacks registered for event: " .. name)
        return
    end
    for _, callback in pairs(callbacks) do
        callback(...)
    end
end



return event_system
