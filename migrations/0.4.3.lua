
local spiders = require "api.spiders"

local data_spiders = require "data.spiders"

return function()
    storage.spiders = data_spiders
    spiders.register_events()
    spiders.init()
    spiders.reindex_spiders()
end
