
---@alias GuiEventName "gui-opened"|"gui-closed"|"gui-confirmed"|"gui-clicked"|"gui-switch-changed"|"gui-selection-changed"|"gui-elem-changed"|"gui-slider-changed"

---@alias HexPosMap {[int]: {[int]: any}}
---@alias AxialDirection 1|2|3|4|5|6
---@alias AxialDirectionSet {[AxialDirection]: boolean}

---@alias IndexMap {[int]: {[int]: int}}
---@alias EntityRadii {[string]: number[]}
---@alias AmmoReloadParameters {bullet_type: string|nil, flamethrower_type: string|nil, rocket_type: string|nil, railgun_type: string|nil, bullet_count: int|nil, flamethrower_count: int|nil, rocket_count: int|nil, railgun_count: int|nil}
---@alias MapPositionAndDirection {position: MapPosition, direction: defines.direction}
---@alias MapPositionSet {[int]: {[int]: true}}
---@alias DungeonPrototype {wall_entities: EntityRadii, loot_value: number, rolls: int, qualities: string[], tile_type: string, ammo: AmmoReloadParameters, chests_per_hex: int, amount_scaling: number}
---@alias Dungeon {surface: LuaSurface, prototype_idx: int, id: int, maze: HexMaze|nil, turrets: LuaEntity[], walls: LuaEntity[], loot_chests: LuaEntity[], last_turret_reload: int, internal_hexes: HexSet, is_looted: boolean|nil}

---@alias PlayerCatalogSelection {surface_name: string, item_name: string, bazaar_quality: string, last_item_selected: string|nil, last_qb_item_selected: string|nil, bazaar_buy_amount: int|nil}

---@alias IslandConfig {radius: int, fill_ratio: number, algorithm: string, seed: int?, start_pos: HexPos?}

---@alias HexMazeTile {pos: HexPos, open: boolean[]}
---@alias HexMaze {tiles: HexMazeTile[], tiles_by_position: IndexMap, generated: boolean}

---@alias HexSet {[int]: {[int]: true}}
---@alias IntSet {[int]: true}

---@alias ItemRank {item_name: string, rank: int, progress: int[]}
---@alias ItemBuff {type: ItemBuffType, value: float|nil, values: float[]|nil, level_scaling: float|nil, level_scalings: float[]|nil}
---@alias ItemBuffType "moving-speed"|"mining-speed"|"reach-distance"|"build-distance"|"crafting-speed"|"inventory-size"|"trade-productivity"|"all-buffs-level"|"all-buffs-cost-reduced"|"robot-battery"|"robot-speed"|"recipe-productivity"|"beacon-efficiency"|"belt-stack-size"|"passive-coins"|"train-trading-capacity"

---@alias LootItem {item_name: string, quality_tier: int}
---@alias LootItemWithCount {loot_item: LootItem, count: int}
---@alias LootTable {wc: WeightedChoice, loot: LootItem[]}

---@alias SpiderClientAIMode "build"|"hunt"|"claim"|"trade"
---@alias SpiderClientAI {current_mode: SpiderClientAIMode}
---@alias SpiderServerAI {force: LuaForce, enabled_modes: {[SpiderClientAIMode]: boolean}}
---@alias Spider {entity: LuaEntity, client_ai: SpiderClientAI}

---@alias StringAmounts {[string]: number}
---@alias QualityItemCounts {[string]: StringAmounts}
---@alias StringSet {[string]: boolean}
---@alias StringFilters {whitelist: StringSet|nil, blacklist: StringSet|nil}

---@alias WeightedChoice {[any]: number, __total_weight: number}



---@alias NotificationID
---| "quest-completed"
---| "new-catalog-entry"
---| "item-ranked-up"
---| "extra-trade"
---| "interplanetary-trade"
---| "trade-recovered"
---| "strongbox-located"
