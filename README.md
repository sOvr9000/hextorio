A Factorio mod for building in hexagons instead of a huge open world.

# Core Features Summary
### World Generation
Each planet in Space Age is composed of thousands of hexagons ("**hexes**"), each initially separated by the planet's main fluid tile.

### Hex Cores
Each hex contains one entity at its center called the "Hex Core", which the player can open to see a custom GUI to the right of its inventory.\
The custom hex core GUI contains information about resources in the tile, who claimed it, and numerous control buttons for managing the hex core.\
Hex cores have eight loaders -- two per side -- built into them for rapid item loading/unloading.

### Hex Claiming
All hexes start as unclaimed. The player spends **coins** to claim hexes.\
Once a hex is claimed, its trades become available to use.\
The player starts with enough coins to immediately claim two hexes on game start.

### Trades
Each hex core contains multiple "trades" -- randomly generated but constant exchange rates of items to other items.\
For example, a trade can be `1x coal -> 2x iron-plate`, where coal is exchanged for iron plates.\
Each hex core processes all trades as quickly as possible by consuming items in its inventory and dropping off items in the same inventory.
Some limits exist based on available inventory space and other more obscure state data.

Quality of items is preserved in trading, but all items in a trade must be the same quality for it to commence.\
Coin amounts in a trade are scaled appropriately to compensate for them being fixed at normal quality.

### Trade Productivity
This is a percentage that affects trades in the exact same way as recipe productivity in machines:
- A purple bar fills up over time.
- The trade behaves normally while the bar is filling up.
- When full, an extra batch of the trade's outputs is given for free.

For example, when trade productivity is `+50%`, the trade consuming two output batches will result in it returning three output batches.\
Since trades are processed in entire batches at a time, the bar does not fill up continuously/smoothly; it instead jumps forward by large steps at a time depending on how much productivity the trade has.

Trade productivity is able to become negative under some circumstances. When this happens:
- A red bar fills up over time.
- The trade *does not output any items* while the bar is filling up.
- When full, only then a batch of the trade's outputs is given.

Where a positive productivity of `pos_prod` causes the purple bar to jump forward by `pos_prod` of the complete bar at a time,\
a negative productivity `neg_prod` causes the red bar to jump forward by `1 / (1 - neg_prod)`.

This is a mathematically and logically consistent negation of the "recipe productivity" concept in the base game.\
The numbers work out nicely when negative productivity is handled like this. For example:
- Suppose a trade of `iron-ore -> copper-ore` has +100% prod, meaning the copper ore output is perfectly doubled.
- Then suppose a different trade of `copper-ore -> iron-ore` has -100% prod, meaning its iron ore output is perfectly halved (use the formula).
- Feeding the inputs and outputs of these trades into each other (iron ore -> copper ore -> iron ore -> ...) creates an equillibrium of no item growth or decay, and non-coincidentally, +100% and -100% are additive inverses. They cancel each other out.

This gives the players a quick way to tell whether combining a positive trade productivity with a negative one nets growth or decay.

### Base Trade Efficiency
The most important setting in this mod, **Base Trade Efficiency** (BTE) controls how much of the input value that a randomly generated trade "tries" to preserve in output value.\
For example, a BTE of 1.0 makes the randomly generated trades generally preserve the value of items from input to output, assuming no productivity.\
And a BTE of 0.1 means that randomly generated trades tend to return only 10% of the input value when producing its outputs.\
Why this setting is important:
- Setting BTE too close to or above 1.0 will result in making the game *very easy*, achieving victory almost effortlessly, because infinite item loops are possible early on.
- Keeping BTE low enough (at or below 0.4) generally keeps productivity from introducing the potential for infinite item loops, forcing the player to build infrastructure to maintain a net positive coin income.

Your preference as a player of this mod tells you which type you are: Do you prefer the trading game, or do you prefer the trade-assisted factory game?

### Coins
There are multiple tiers of coins, each one holding the same value as 100,000x the previous tier.\
Internally handled as normal items in Factorio, they have extended functionality: When taken from or added to in a compatible inventory, tiers automatically normalize.\
For example, a stack of 105,000 coins immediately turns into 5000 of the same-tiered coin plus one of the next tier.

Some trades require coins as input or produce coins as output.\
Coins are primarily earned through selling items using trades.

Other than through trading, they are acquired through some other features of the mod, and they are spent in various ways:
- Claiming hexes
- Unlocking or enhancing item buffs
- Activating the effects of some upgrades/features

The mod does not handle coins of a quality higher than normal (although quality coins can be cheated in anyway).\
Each quality tier increases an item's coin value by 9x, where normal quality is 1x value.

### Item Value Solver
All items in the game (including those from other mods) are assigned coin values automatically.\
This is done by propagating values of each planet's raw resources throughout the planet's respective usable, unlockable recipes.\
Several factors are considered:
- stack sizes
- item spoil rates
- recipe crafting time
- number of unique items and fluids in recipes
- food (like bioflux) for captive biter spawners
- rocket part costs (and thus interplanetary import costs)
- distances between planets (when production requires interplanetary imports)
- planet-specific overall multipliers to each stepping from ingredients to products

This results in finished products tending toward larger values than the sums of their ingredients, which is intended to reward setting up automated production as opposed to relying solely on trading to "produce" items.

A full description of how the item value solver works is documented at the top of [its module](api/item_value_solver.lua).

### Item Tradability Solver
To preserve gameplay balance, items that are producible on a planet but are only unlocked from later planets must not be tradable.\
For example, `productivty-module-3` is producible on Nauvis, but it is unlocked on Gleba, so that item should not be tradable on Nauvis.

This is to prevent players from buying such items before they're unlocked through Space Age's intended progression path.\
This is also to prevent players from buying items like `holmium-plate` on Aquilo to skip the otherwise necessary interplanetary logistics.\
The item tradability solver targets that issue.

It primarily relies on the tech tree and detecting where and when recipes get unlocked for each planet.\
It works perfectly well with vanilla Space Age, although as more recipes get added by other mods, gameplay balance becomes less stable even with this solver.

This is handled as a fully separate system from item coin value calculation due to certain edge cases that can emerge.\
An example of one such edge case in vanilla Space Age:
- `biter-egg` is unlocked on Gleba, but is only producible on Nauvis.
- `biter-egg` must not be tradable on Nauvis due to the tech tree's implied progression path.
- `biter-egg` must not be tradable on Gleba due to the restriction that it is only producible on Nauvis.
- `biter-egg` must be given an item value, *while not being flagged as tradable on any planet*, in order to determine a value for `productivity-module-3` so that it can be tradable on Gleba.

Item tradability implies associated coin values, but associated coin values do not imply item tradability.

A full description of how the item tradability solver works is documented at the top of [its module](api/item_tradability_solver.lua).

### Questing System
In the quest book GUI, there are quests which can be completed by performing a diverse set of actions.\
Some serve as guides like a tutorial. Others serve as relatively difficult challenges.

Quests are organized in order of progression. Easy quests are shown to the player first, and they reveal more challenging quests once completed.\
Quests are designed to prioritize uniqueness and distinctiveness over abundance. That is to say, the goals are typically about performing a more difficult action a small number of times rather than an easier action a large number of times, to reduce the "grindiness" and encourage varied gameplay tasks.

Almost all quests give rewards. Some rewards unlock entire features of the mod, others simply give valuable items like coins.

### Unlockable Features
Features unlocked from quests are the following exhaustive list:
- *Trade Configuration* - modify how trades are processed, unlocked at the very start to reduce information overload for new players
- *Trade Overview* - easily view and search for specific trades based on items, distance, etc.
- *Catalog* - for each planet, see all items discovered in trades, their coin values, their ranks, and more
- *Hex Rank* - a scoring system for how much has been accomplished in the playthrough (currently purely aesthetic), providing end goals for each measured statistic
- *Resource Conversion* - turn all ore entities into the most abundant one
- *Resource Supercharging* - turn ores or wells infinite
- *Hex Core Deletion* - permanently remove hex core entities
- *Locomotive Trading* - toggleable ability to allow trains to make trades using their cargo wagons as working inventories
- *Piggy Bank* - separate inventory that dynamically resizes to hold all of the player's coins in a safe and easily portable, accessible place
- *Teleportation* - allows teleporting to same-surface hex cores
- *Cross-Surface Teleportation* - upgraded form of *Teleportation* which allows teleporting to other planets if all teleporting inventories are empty
- *Hexports* - freely powered roboports built into hex core entities extending remote visibility and logistic network coverage
- *Quantum Bazaar* - buy and sell maximally ranked items at a one-to-one value exchange rate
- *Sink/Generator Mode* - two separate unlocks for converting all trades in a hex to use coins as the medium of exchange but at a poor exchange rate in either direction
- *Item Buffs* - allows spending coins to unlock new item-specific bonuses
- *Item Buff Enhancement* - allows spending coins to upgrade any unlocked item-specific bonuses
- *Enhance All Item Buffs* - click a single button to spend as many coins as possible to enhance or unlock all affordable item buffs
- *Quick Trading* - click one button to process one (minimal) batch of each trade in a hex core in order to trigger item rank-ups

### The Catalog
This is a GUI which shows all items ever found in trades.\
Each item that is findable in trades has an associated "rank". Items are ranked up through making trades or doing other trade-related tasks.\
The rank is displayed in the catalog as three stars of a certain color, going from **gray** to **bronze** to **silver** to **gold** to **red**.\
Each item rank provides certain bonuses based on the rank itself (not the item).\
The bronze rank unlocks **item buffs**, which are the item-specific bonuses.

### Item Buffs
Item buffs can first be unlocked using coins, providing a base value of the item's special bonus.\
Once unlocked, they can then be enhanced using more coins, increasing the effect of the item's bonus.\
Costs to enhance increase exponentially, and an item buff may either increase linearly or also exponentially but less quickly.

### Dungeons
Hexes have a chance to be generated with a dungeon covering them, spanning multiple contiguous hexes at once.\
Each dungeon hex contains one or more loot chests, where the number of chests and the value of the loot depends on the difficulty of the prototype that was used to generate it.\
Each dungeon hex is also mostly surrounded by hostile turrets with moderate HP regeneration and custom resistances to damage types.\
They serve to fill in some of the missing combat potential where Space Age left to be desired by many players.\
All planets have themed dungeons, e.g. tesla turrets in Fulgoran dungeons both as hostile turrets and as potential loot in chests.

### Items and Recipes
This mod adds a handful of items and recipes to the game, not intended as the primary content of the mod.

Most items are new ammo types like magmatic rounds magazines or plague rockets.\
One unique item called the "Hexadic Resonator" is found exclusively in dungeon loot chests, and it is used to freely enhance item buffs.\
Some interesting items are the demolisher combat robot and Sentient Spider:
- The demolisher robot is like a destroyer which shoots railgun projectiles instead of electricity.
- The Sentient Spider is an enhanced spidertron that shoots a specialized railgun weapon based on electromagnetics, dealing very high tesla-like arcing damage to all entities hit along the railgun/EMP projectile's path.

An item called the "Hexaprism" is also added as an endgame Nauvis resource.\
Hexaprisms are used in crafting the intentionally overpowered things like the Sentient Spider.\
They are also used in making spaceships and vehicles reach *very* fast top speeds, as well as in making tier 4 modules.

Some recipes are added which some may consider to be missing in Space Age like bullet casting recipes.\
A very unique series of recipes from this mod is the "**SOVR Enrichment Process**", which closely parallels the kovarex enrichment process: combine an expensive resource with a cheaper resource to produce more of the expensive resource. This series of recipes is intended to resemble the spreading of "crystal energy" from one to another, functionally equivalent to the enrichment of U-238 into U-235.

This mod also makes some balancing changes some vanilla/Space Age weapons, particularly the teslagun, discharge defense equipment, and destroyers (renamed to tesla destroyers). This was done to make those weapons more interesting and effective as well as to compensate for the increased difficulty due to quality biters in world generation.

### Other Features
The main features are above, but there are other obscure features scattered throughout the mod such as the **Fulgoran Electrocution** animation, which puts on a light show for the player to complete the "Electrocution" quest that would otherwise be too time-consuming on its own.\
There's also an extra quality tier called "Hextreme", following legendary.

# Planned Features
### Automated spidertron interaction with the mod
- Unlocked as a quest reward.
- When a group of spidertrons (even if only containing one spidertron) is selected, a button shows up in the top left corner of the screen beside the mod's buttons.
- This button opens a GUI for managing allowed behaviors of the selected spidertrons:
  - Add to spidertron manager
  - Remove from spidertron manager
  - *Item Ranking Mode* - Allow requesting items from a suitable logistic network to carry them over to a trade in order to rank up items.
  - *Logistics Mode* - Configure a looping schedule of specific entities to either pick up all contents or dropoff entire inventory to.
    - Not restricted to hex cores.
    - The schedule is a list of entities, marked as either to pick up or to drop off items.
    - Item pickup and dropoff filtering can be loosely achieved with spidertron and hex core inventory slot filters.
- When a spidertron is set to move to an entity, it finds a path through claimed hexes so that it doesn't try to cut corners and run straight into a dungeon.

### Quickly viewable hex claim cost
- Mouse over a hex core to see a GUI element (label with transparent background) appear over it indicating hex claim cost.
- Label uses rich text to display coin amounts beautifully.

### More world generation modes
- *Fractal* - Could either be a Sierpinski triangle or some kind of Koch Snowflake type of thing.
- *Circular* - The hexes visually approximate a circle, like the current *Donut* world generation mode but with the center filled-in.
- *Organic* - Something produced via cellular automaton iteration, or perhaps Perlin noise.
- *Double Spiral* - Same as the current *Spiral* world generation mode, but two spiral arms originating from the spawn hex instead of one.
- *Triple Spiral* - Same as *Double Spiral*, but three arms instead of two.
- *Double-Triple Spiral* - Technically a hexaspiral, but this sounds way cooler.

### Add more item buffs
Many items are missing item buffs, but it is intended for *all* items to give buffs once unlocked.

### Quest completion toasts
A GUI with a transparent background pops up in the center of the screen briefly indicating a quest has been completed, showing the same information as what the console currently shows.

### Add current coin generation rate to HUD
Currently only the current hex rank shows at the top of the screen, but below it could very nicely be just one more rich text label indicating the current net coin production rate (per second, based on hourly statistics, as seen in the hex rank GUI).\
But this would show the *current* rate, not the maximum ever reached like the statistic reads.

### Make the Quick Trading feature work with Piggy Bank
It's just not implemented yet. The intuitive functionality of the Piggy Bank feature is to provide coins to trades that take coins when using the quick-trade button.

### Make hexadic resonators more convenient to use
Make them use use entire stacks at a time. There's enough inventory control in the game to facilitate using partial stacks. Doing this will make it less time-consuming to reap the rewards from the SOVR Enrichment Process recipes.

### Hex claim tool visual effects
When the tool is in use, highlight outlines of visible hexes (and to some distance some uncharted hexes) in remote view.

### Add item rank filtering to trade overview
Discussed here: https://mods.factorio.com/mod/hextorio/discussion/6964605b25f42e07037e4b65

### Add mod setting "Calcite Bias Chance"
This would complement the "Tungsten Bias Chance" setting, allowing players to modify calcite generation in the same way as the other ores.

### Replace mod setting "Min Tungsten Distance" with runtime logic
To accurately replicate Space Age's tungsten ore generation rules, this mod should spawn tungsten ore only if it's inside demolisher territory. Doing this will remove the need to configure this setting when other settings like Vulcanus hex size change.

### A quest which gives an epic-quality space platform (currently WIP)
This is gradually being worked on at the moment. A challenging Gleba quest will, when completed, reward the players with a free ship built with epic quality components and uses all the best tech post-Gleba such as bullet casting recipes and rocket turrets, so it's capable of flying to Aquilo.

### Improved sink/generator mode button tooltips
The tooltips should show the "signatures" (item types but not item counts) of the trades that would be created as a result of switching to the respective mode.\
For example, if a hex core contains these trades:\
`3x iron-plate -> 2x coal, 1x iron-stick`\
`4x copper-ore, 3x steel-plate -> 6x stone, 7x stone-brick`\
then the tooltip for the sink mode button should show rich text like this:\
`[img=item.iron-plate][img=trade-arrow][img=item.hex-coin]`\
`[img=item.copper-ore][img=trade-arrow][img=item.hex-coin]`\
`[img=item.steel-plate][img=trade-arrow][img=item.hex-coin]`\
This will help to illustrate what these modes are doing before an irreversible change is made.

### Better Quantum Bazaar
- Designated GUI for all features related to the Quantum Bazaar (search, buy/sell, etc), accessible from the catalog or as another button in the top left of the screen.
- Possibly consider using actual inventory UIs to drop items into a "selling bin" and collect items from a "purchased items bin".  Or instead it stays how it is with the button-based and cursor stack-based trading.
- Frees up space in the catalog for those who have squished screens or large display scales.
- Add a button which buys as many of your character's unfulfilled personal logistics requests as possible.
  - This can be a "smart" feature where it first tries to buy as many unique items as possible as opposed to as many of a single item type as possible, helping significantly with e.g. large blueprint builds.

### Redesign GUIs
**Massive** amount of work to be done here. Some common things currently causing confusion:
- Catalog search button. It is commonly requested, and it exists already, but some people don't know it does. Current idea for a simple solution is to switch the sprite to a magnifying glass and still have it make you select an item, but the icon must always remain a magnifying glass for it to make sense.

Another GUI change that would be nice is turning the hex core mode buttons into a single button which gives you the sink and generator mode options. Doing this would allow easy extension of the whole concept of "hex core modes" where only one mode can be chosen permanently, adding a layer of decision-making to the game.

Additionally:
- Add support for the top left buttons being grouped with other mod buttons.

### Ideas on the table
These are tentative ideas, which may or may not be added at some point. They are here for consideration:
- Chaos Mode setting: If enabled, random *temporary* events occur throughout the game, sampling from a list such as the following:
  - All trades gain 25% productivity.
  - Nauvis and Gleba enemy evolution factor is set to 1.000.
  - The hex core at spawn gains 30 random trades (initially disabled to avoid breaking existing logistics).
  - A loaded dungeon turret spawns in each hex that is adjacent to an unclaimed hex.
  - Crafting any item by hand has a chance to spawn a biter or spitter spawner around your character if on Nauvis, or an egg raft if on Gleba.
- Add hidden substation-like entities built into hex cores.
  - Similar to hexports (roboports in hex cores), but provides full area distribution as though the entire area of claimed hexes are a space platform.
  - Potential issue or annoyance if not conveniently toggleable or separable from other power grids.
- Random challenge events:
  - A hex is randomly chosen within which the player may complete a challenge for a small reward.
  - Can be something like building certain types of machines in the hex, or producing a certain item, or executing one of the trades X times, etc.
- A quest or hex rank statistic about net production rates of some items (currently only coins are measured).
- Some quest ideas:
  - Something to reward the player(s) by adding space science packs to the trade item sampling pool.
  - Process three trades in a single tick in one hex core.
    - Probably most easily done by activating belts (going into the loaders) simultaneously to feed the same remaining amount of items needed execute a batch of three separate trades.
    - Requires a little bit more advanced understanding of Factorio's in-game tools and systems given to the player.
  - More tiered quests for item ranking or discovery, perhaps planet-based.
- Some item buff ideas:
  - Extra free hex claims: get `+x%` more free claims from quests
    - Applies retroactively to past earned free hex claims as well as to future rewards
    - Would be handled as summing all past earned free hex claims, then multiplying, then taking the integer difference to determine how many extra free claims are given by this buff.
  - Some kind of productivity bonus given only to trades in hex cores that are in sink or generator mode.
    - Will make these two modes more appealing to some players who think they're completely useless right now.
- Some changes that would be good to do eventually but are relatively unimportant:
  - Define the recycling recipes for the hexic belt types
  - Add the hexic loader (can be a fancy reward from a quest maybe)
- Sufficiently high hex ranks can give bonuses. Some ideas:
  - Proxy trading:
    - Each trade has a very small (maybe upgradeable?) chance of doubling its output based on the total number of actively used trades in adjacent hexes.
- Add more modes for hex cores other than sink or generator:
  - Proxy trading mode? The feature described as a possible hex rank-based upgrade if that system gets extended.
  - The idea of hex core modes is that only one mode can be chosen, and it's a permanent decision so that sacrifice has to be made (adds a layer of decision making).
- Add menu simulations:
  - An enemy demolisher combat robot (flying railgun bot) destroying some of the player's factory.
  - A hex core unloading gravity coins at 60/s on fast transport belts (belt capacity 1) to another hex core.
  - Rogue spidertron accident:
    - Spidertron approaches a player.
    - Spidertron pauses for a few seconds.
    - Spidertron takes a couple steps closer.
    - Spidertron pauses for a second.
    - Spidertron fires a nuke and blows itself up with the player.
  - The Sentient Spider running in to obliterate a dungeon on Vulcanus.
  - 500 construction bots rushing in to place landmines around the turrets of a dungeon on Gleba, maybe succeeding in killing the turrets.
- Add TD wave spawn locations ("**pits**") as void hexes (`out-of-map` tile) which rarely replace a non-land hex
  - Summoning a wave makes them come from a random **pit** hex.
  - The player has a 30 second countdown before the wave spawns.
  - Thematic enemy units spawned per planet:
    - **Nauvis** - Biters
    - **Vulcanus** - Demolishers
    - **Fulgora** - Destroyer combat robots
    - **Gleba** - Pentapods
    - **Aquilo** - The Sentient Spider (or multiple clones of it)
  - What rewards, though?
- Add timed trial runs, where you're temporarily teleported to a clone of your current world.
  - The objective is to destroy as much of it as possible.
  - The more entities destroyed, the higher your score.
    - Maybe the score gives you something, maybe these time trial runs are rate-limited.
  - Cheesing can be mostly prevented by only copying over entities that are "active":
    - finished products > 500
    - has existed for at least 5 hours
    - or other conditions
  - Helps to scratch that itch that some Factorio players encounter at some point where they want to destroy what they've built or fun.
  - Or maybe instead this fake dimension is a supermassive dungeon of the same type as what's seen on the planet the player came from.
    - Would make obtaining the Sentient Spider extremely satisfying.
- Add molten coin recipes:
  - Throw coins into a foundry, receive molten coins
  - Tons of potential for new trading dynamics and strategies
- A much older idea, make hex cores be able to receive unique buffs based on fluid input:
  - water add 5% trade productivity
  - sulfuric acid removes 5% trade productivity
  - molten hex coins convert all trade outputs to coins as if the trades were all originally "sell" trades
    - the trades would appear unchanged in the GUI, but coins of equivalent value would be added to the hex core inventory instead of the items in the trade outputs
  - lubricant gives a chance for items to not be consumed on trade
  - (some kind of masochist mode) steam enables claiming adjacent hexes, which would be unclaimable if steam isn't provided
  - molten gravity coin causes all trade outputs to go directly to player inventories
  - molten meteor coin allows buying items for equivalent value with coins (*this QoL has been implemented as the Quantum Bazaar*)
  - molten hexaprism coin removes all trades from hex core along with their productivity bonuses but makes them accessible - by hand via player inventory (*this QoL has been implemented as the Quantum Bazaar*)
  - electrolyte randomly pulls in items from other claimed hex cores
  - holmium solution causes items in hex core to randomly teleport around to other claimed hex cores
  - fluoroketone (hot or cold) reverses trade direction but negates productivity effect while reversed
    - for example, +50% productivity on a trade becomes -50%, which prevents an exploit of repeatedly trading items back and forth using only one trade (prevents generating infinite items)
  - molten iron removes 15% prod
  - molten copper adds 15% prod
  - liquid hexaprism (the endgame Nauvis ore) adds 50% prod

# Planned Changes
### Rebalancing
- Strongboxes:
  - Change from constant coin rewards per strongbox level to flat bonuses to passive coin income, up to a maximum level such as 10 (after which the strongbox is destroyed permanently).
  - Rebalance HP to more accurately reflect what's possible throughout the game.
  - This will keep turret spam from having to be operated forever while still getting to have fun coming up with ways to turret spam.
- Hexadic Resonators:
  - Prohibit use if the cheapest item buff is more expensive than 10 hours of your global net coin production (as seen in Hex Rank statistics).
  - This prevents runaway costs reaching ridiculous levels.
  - Problem can be mitigated by defining buffs for more item types.
  - Also, maybe reduce the number of them given by dungeons since it can easily get out of hand (don't want too many to become useless given the balancing change above).
  - Also change stack sizes per hexadic resonator tier so that the SOVR Enrichment Process does not result in tons of chests full of tier 1s.
  - Also reduce the effectiveness of each resonator by a factor of two: tier 1s require two to be used at once (and use two at a time) to upgrade one item buff, tier 2s only need one to be used but still only upgrade one item buff, etc.
- Dungeons:
  - Prevent auto-claim (upon successful looting of the dungeon) from occurring until at least one adjacent hex is claimed.
  - This will prevent players from being able to claim remote hexes, completely disconnected from the spawn hex.
  - Also, make dungeon chests irreplacable with other chest entities, which will patch out the exploit of using build distance buffs to freely loot dungeons while standing outside of them.
- Quests:
  - Make it so that quests cannot be completed until revealed, but their conditions can be completed while hidden and then the quest gets auto-completed immediately upon reveal. So, rewards are properly gated behind ordered quest completion.

### Tweaks
- Dungeon loot chests contain more varied amounts of loot instead of staying mostly constant for each dungeon prototype.
  - Something like a +/- 15% variation of total loot value per chest would be nice to see for a change.

### Optimizations
- Store hex states as their flat indices in trade objects.  Using *indirection* like this will almost certainly improve save times and reduce save file sizes to some degree.
- Distribute hex tile (concrete) placement across more ticks in smaller loads so that instead of stuttering every 20 frames, it's more like negligibly small stutters on every frame.
- Consider the potential of an LRU cache improving trade overview processing times.

### Bugfixes
- Fix that the mod's main buttons in the top left of the screen sometimes don't show up on rejoining a server.
- Verify that when an extra trade is created in a hex core from bonus effect of bronze-ranked items, the respective item in the extra trade is not replaced by coins. This bug has been observed at least once in 1.2.x, but it could potentially have been indirectly fixed with the second or third trade generation overhaul somewhere in 1.4.x or 1.5.x.

### Development Workflow
- Add menu simulations designated for testing common, important, and heavily used features of the mod, only enabled when in development mode (*never* enabled in production).
  - The main menu's built-in simulations will be overridden with custom ones built to rapidly simulate the start of the game with this mod and simulate player interactions in various ways, validating various mechanics to ensure correctness before release.
  - This is the common way to do some form of unit testing for large Factorio mods (overhauls typically).
  - This needs to be done sooner rather than later because random bugs and crashes keep occurring in the most unexpected ways, not being caught before release. The number of bugs since 1.4.x has been unnacceptably high in comparison to 0.0.1 - 1.4.0. The complexity of this project and its many interdependent systems call for at least some form of unit testing.
- Refactoring:
  - Some files consist of thousands of lines of code, which is unnecessary.
  - Some modules can make better use of the event system to split up logic into multiple files or reduce `require` frequency.
  - Some modules contain some (but not a lot of) logic that should more appropriately exist in another module.
  - The event system would be better implemented as executing callbacks on the raw EventData that Factorio provides instead of pre-parsing and passing multiple arguments. Doing this also comes with a small optimization for rapidly triggered events such as `on_entity_damaged` because it will avoid argument unpacking (a slow operation and harsh on Lua's GC).
- Finish adding LuaLS typing
  - to the early functions that were written without it
  - as well as to all objects managed in `storage` to reduce the likelihood of misunderstanding and misuse.
- Use the `no-crop` flag in sprite prototypes for quest images, and verify that all quest images look the same (no awkward stretching).
  - Without this, strange workarounds in the images themselves have to be made to prevent stretching.
