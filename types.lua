
---@alias IndexMap {[int]: {[int]: int}}
---@alias StringAmounts {[string]: number}
---@alias QualityItemCounts {[string]: StringAmounts}
---@alias MapPositionAndDirection {position: MapPosition, direction: defines.direction}
---@alias MapPositionSet {[int]: {[int]: true}}
---@alias StringSet {[string]: boolean}
---@alias StringFilters {whitelist: StringSet|nil, blacklist: StringSet|nil}

---@alias NotificationID
---| "quest-completed"
---| "new-catalog-entry"
---| "item-ranked-up"
---| "extra-trade"
---| "interplanetary-trade"
---| "trade-recovered"

---@alias AmmoReloadParameters {bullet_type: string|nil, flamethrower_type: string|nil, rocket_type: string|nil, railgun_type: string|nil, bullet_count: int|nil, flamethrower_count: int|nil, rocket_count: int|nil, railgun_count: int|nil}
