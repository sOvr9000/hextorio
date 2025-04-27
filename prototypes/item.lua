
local hex_coin = table.deepcopy(data.raw["item"]["coin"])
hex_coin.name = "hex-coin"
hex_coin.icon = "__hextorio__/graphics/icons/hex-coin.png"
hex_coin.order = "ya"
hex_coin.stack_size = 99999
hex_coin.auto_recycle = false
hex_coin.subgroup = "other"
hex_coin.hidden = false

local gravity_coin = table.deepcopy(hex_coin)
gravity_coin.name = "gravity-coin"
gravity_coin.icon = "__hextorio__/graphics/icons/gravity-coin.png"
gravity_coin.order = "yb"
gravity_coin.auto_recycle = false
gravity_coin.subgroup = "other"
gravity_coin.hidden = false

local meteor_coin = table.deepcopy(hex_coin)
meteor_coin.name = "meteor-coin"
meteor_coin.icon = "__hextorio__/graphics/icons/meteor-coin.png"
meteor_coin.order = "yc"
meteor_coin.auto_recycle = false
meteor_coin.subgroup = "other"
meteor_coin.hidden = false

local hexaprism_coin = table.deepcopy(hex_coin)
hexaprism_coin.name = "hexaprism-coin"
hexaprism_coin.icon = "__hextorio__/graphics/icons/hexaprism-coin.png"
hexaprism_coin.order = "yd"
hexaprism_coin.stack_size = 100000
hexaprism_coin.auto_recycle = false
hexaprism_coin.subgroup = "other"
hexaprism_coin.hidden = false

data:extend({hex_coin, gravity_coin, meteor_coin, hexaprism_coin})
