
---@alias IndexMap {[int]: {[int]: int}}
---@alias StringAmounts {[string]: number}
---@alias QualityItemCounts {[string]: StringAmounts}
---@alias MapPositionAndDirection {position: MapPosition, direction: defines.direction}
---@alias MapPositionSet {[int]: {[int]: true}}
---@alias StringSet {[string]: boolean}
---@alias StringFilters {whitelist: StringSet|nil, blacklist: StringSet|nil}
