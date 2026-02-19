
---@alias GuiEventName
---| "gui-opened"
---| "gui-closed"
---| "gui-confirmed"
---| "gui-clicked"
---| "gui-switch-changed"
---| "gui-selection-changed"
---| "gui-elem-changed"
---| "gui-slider-changed"
---| "gui-back"
---| "gui-forward"

---@alias HexPosMap {[int]: {[int]: any}}
---@alias IndexMap {[int]: {[int]: int}}

---@alias HexSet {[int]: {[int]: true}}
---@alias IntSet {[int]: true}

---@alias SpiderClientAIMode "build"|"hunt"|"claim"|"trade"
---@alias SpiderClientAI {current_mode: SpiderClientAIMode}
---@alias SpiderServerAI {force: LuaForce, enabled_modes: {[SpiderClientAIMode]: boolean}}
---@alias Spider {entity: LuaEntity, client_ai: SpiderClientAI}

---@alias StringAmounts {[string]: number}
---@alias QualityItemCounts {[string]: StringAmounts}
---@alias StringSet {[string]: boolean}
---@alias StringFilters {whitelist: StringSet|nil, blacklist: StringSet|nil}



---@alias NotificationID
---| "quest-completed"
---| "new-catalog-entry"
---| "item-ranked-up"
---| "extra-trade"
---| "interplanetary-trade"
---| "trade-recovered"
---| "strongbox-located"
