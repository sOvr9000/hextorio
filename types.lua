
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
---| "gui-search-button-clicked"
---| "gui-text-changed"
---| "gui-text-confirmed"
---| "gui-search-text-changed"
---| "gui-search-text-confirmed"

-- Note that gui-text-changed is for any text field changing.  gui-search-text-changed is the specific event for a text field that is designated as a search field in a frame title bar.
-- The delegation is done by mapping a gui-text-field tag to a gui-search-text-changed linked handler in the tags of the search button and search field when they're created in core_gui.add_titlebar().

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
