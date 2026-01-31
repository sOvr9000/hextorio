
local lib          = require "api.lib"

local toasts = {}



---@alias ToastInfoType "text"|"image"|"row"

---@class ToastParameters
---@field info ToastInfo[]
---@field lifetime int|nil Number of ticks to display toast. Defaults to 300.

---@class ToastInfo
---@field type ToastInfoType
---@field text LocalisedString|nil Only used when type == "text"
---@field image string|nil Only used when type == "image"
---@field elements ToastInfo[]|nil Only used when type == "row"



---Get the current toast queue.
---@return ToastParameters[]
function toasts.get_current_queue()
    if not storage.toasts then
        storage.toasts = {}
    end

    local queue = storage.toasts.queue
    if not queue then
        queue = {}
        storage.toasts.queue = queue
    end

    return queue
end

---Enqueue a toast (pop-up).
---@param toast_params ToastParameters
function toasts.enqueue_toast(toast_params)
    if not toasts.validate_toast_parameters(toast_params) then return end
    toasts.set_default_toast_parameters(toast_params)

    local queue = toasts.get_current_queue()
    table.insert(queue, toast_params)
end

---Set the optional fields in toast parameters to their default values.
---@param toast_params ToastParameters
function toasts.set_default_toast_parameters(toast_params)
    if not toast_params.lifetime then
        toast_params.lifetime = 300
    end
end

---Return whether the given toast parameters have a valid structure, logging errors where found.
---@param toast_params ToastParameters
---@return boolean
function toasts.validate_toast_parameters(toast_params)
    if not toast_params.info then
        lib.log_error("toasts.validate_toast_parameters: `info` not found in ToastParameters root")
        return false
    end

    if type(toast_params.info) ~= "table" then
        lib.log_error("toasts.validate_toast_parameters: ToastParameters.info is not a table")
        return false
    end

    if toast_params.lifetime and type(toast_params.lifetime) ~= "number" and toast_params.lifetime % 1 ~= 0 then
        lib.log_error("toasts.validate_toast_parameters: ToastParameters.lifetime is not an integer")
        return false
    end

    for _, info in pairs(toast_params) do
        if not toasts.validate_toast_info_object(info) then
            return false
        end
    end

    return true
end

---Return whether the given toast info has a valid structure, logging errors where found.
---@param info ToastInfo
---@return boolean
function toasts.validate_toast_info_object(info)
    if not info.type then
        lib.log_error("toasts.validate_toast_info_object: `type` not found int ToastInfo root")
        return false
    end

    if type(info.type) ~= "string" then
        lib.log_error("toasts.validate_toast_info_object: ToastInfo.type is not a string")
        return false
    end

    if info.type == "text" then
        if not info.text then
            lib.log_error("toasts.validate_toast_info_object: ToastInfo.type == \"text\" but ToastInfo.text is missing")
            return false
        end
        if lib.is_localized_string(info.text) then
            lib.log_error("toasts.validate_toast_info_object: ToastInfo.text is not a LocalisedString")
            return false
        end
    elseif info.type == "image" then
        if not info.image then
            lib.log_error("toasts.validate_toast_info_object: ToastInfo.type == \"image\" but ToastInfo.image is missing")
            return false
        end
        if type(info.image) ~= "string" then
            lib.log_error("toasts.validate_toast_info_object: ToastInfo.text is not a string")
            return false
        end
    elseif info.type == "row" then
        if not info.elements then
            lib.log_error("toasts.validate_toast_info_object: ToastInfo.type == \"row\" but ToastInfo.elements is missing")
            return false
        end
        if type(info.elements) ~= "table" then
            lib.log_error("toasts.validate_toast_info_object: ToastInfo.elements is not a table")
            return false
        end
        if #info.elements == 0 then
            lib.log_error("toasts.validate_toast_info_object: ToastInfo.elements is empty")
            return false
        end
        for _, _info in pairs(info.elements) do
            if not toasts.validate_toast_info_object(_info) then
                return false
            end
        end
    end

    return true
end

---Try to pop the next toast from the queue.  Return whether the current toast has changed (the current has finished or was previously unset).
---@return boolean
function toasts.try_dequeue_toast()
    local queue = toasts.get_current_queue()

    local next_toast = queue[1]
    local current = storage.toasts.current

    if not current then
        storage.toasts.current = next_toast
        table.remove(queue, 1)
        return true
    end

    local last_toast_start = storage.toasts.last_toast_start
    if not last_toast_start then
        storage.toasts.last_toast_start = game.tick
    end

    if game.tick >= last_toast_start + current.lifetime then
        -- TODO: this is not tested
        return toasts.try_dequeue_toast()
    end

    return false
end



return toasts
