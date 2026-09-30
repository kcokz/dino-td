# res://scripts/autoload/Config.gd
extends Node

## Centralized Game Configuration & Constants for Defend Dinosaur v0.0
## All numerical tunings, costs, combat stats, and wave rules are defined here.
## Business logic scripts must reference Config constants and never hardcode values.

# ==============================================================================
# 1. Economy & Action Points
# ==============================================================================
## Every resource in the game, and where each one comes from:
##   wood  -- cut by hand from trees
##   stone -- cut by hand from outcrops, but only once the Hero has a pick
##   bone  -- off a dead dinosaur; the workbench turns it into tools, and it tips the bolts
##   food  -- meat, off a dead dinosaur; cooked and eaten at the kitchen
##   prime_meat -- off a boss, and nowhere else; cooked like meat, and far better eating
##   water -- no use yet (GAME-DESIGN 4.4), so the game does not offer it
## Raw materials first, then what the raids leave (GAME-DESIGN 4.2): the order the top
## bar shows them in.
const RESOURCES: Array[String] = ["wood", "stone", "water", "bone", "food", "prime_meat", "hide",
	# The beacon's parts, one out of each of the ship's wrecks (WRECKS): the stock holds them as it
	# holds wood, so a stage's price, what is missing from it and where to get that are said the way
	# every price is.
	"antenna", "battery", "board"]
## The player starts with nothing banked. The opening stock is real wood lying by
## the cabin (the map's opening_stock, Config.MAPS) and has to be walked over like anything
## else -- the first thing the game teaches is that resources are carried, not
## granted. Keep these at zero: a number here is a second, silent way to get rich.
const INITIAL_RESOURCES: Dictionary = {
	"wood": 0,
	"stone": 0,
	"bone": 0,
	"water": 0,
	"food": 0,
	"prime_meat": 0,
	"hide": 0,
	"antenna": 0,
	"battery": 0,
	"board": 0,
}
const TILE_SIZE: float = 2.0

# ==============================================================================
# 2. Building Definitions (BUILDINGS)
# ==============================================================================
## Economy shape (v0.4). There are no production buildings any more: the Hero's own
## hands are the only source of resources, and buildings are only defence. Tending
## made the building the worker and the Hero a maintenance man, which is backwards
## for a game whose premise is that one body holds up a whole base -- and it was a
## machine for buying time with wood, which is exactly the tension worth keeping.
##
## Hand-harvesting yields RESOURCE_NODES.harvest_rate per second and occupies the
## Hero completely, so every second of gathering is a second not spent building.
## That trade is now the whole economy.
const BUILDINGS: Dictionary = {
	"core": {
		"name": "BUILDING_CORE_NAME",
		"kind": "core",
		# The crew module of the ship that brought the Hero here, and his home: a room he
		# walks into (v0.6 round three: "船舱应该外形和内置一致……可进入，镂空，有透明部分（窗）
		# 里面的设施也在"). Seven cells of the building grid long and three deep -- the room
		# inside it, 5.6 m by 2.6, with his benches along the back wall -- and a little over
		# twice his height. It was a 3 m box with the room parked under the map.
		#
		# HOLLOW: its walls are solid and its inside is not; the door is the way in, for him
		# alone (CABIN.module, CoreCampfire.gd). Its north wall stands where the old cabin's
		# did (Main._cabin_centre): a raid coming down from the nest meets the line it met.
		"size": Vector2i(7, 3),
		"hollow": true,
		"height": 2.6,
		# v0.6 feedback: "船舱血量提升到100，这样船舱的攻击能打败初始迅猛龙". A hundred: the
		# opening's stakes are thin, and the cabin has to be able to take the first raid's
		# bites while its gun and the Hero deal with them -- and still be worth defending
		# when a raid of thirty reaches it.
		"hp": 100.0,
		# Its own gun: the wreck's second turret head, on the roof (tools/generate_props.py
		# cabin). It covers the ground round the cabin and no further -- the first raptors
		# die at the walls, a raid does not. The one thing in the valley that picks its own
		# targets, because it is the ship's machinery; what the player builds are traps.
		"range": 4.5,
		"damage": 1.0,
		"fire_rate": 0.8,
		"turn_speed": 240.0,
		# Each shot, seen (Tower._spawn_visual_bullet_effect): a streak `width` metres thick from the
		# muzzle to what it hit, `energy` times its colour (over one: it glows), for `seconds`; and a
		# flash at the muzzle lighting `flash_range` metres round it. A line a pixel wide went unseen at
		# night, and a phytosaur at the fence flashed white under fire from nowhere (the player's report,
		# 2026-09-29: "晚上这种情况下看不出来夜行恐龙受到了什么攻击"). A tenth of a second was a frame or two,
		# caught only by looking at the right moment (the debug-agent's TASK-027: "很短，要正好看着"): a quarter
		# of a second, and still gone long before the next shot.
		"shot": {"width": 0.06, "colour": Color(1.0, 0.82, 0.32), "energy": 3.5, "seconds": 0.25,
			"flash_energy": 3.0, "flash_range": 4.5},
		"cost": {},
		"upgrades_to": "",
	},
	# THE TRAPS, v0.6 round two: "Bow tower作为初始防御太过于强大，一开始就能造塔有点不合理……想一个能
	# 攻击但不是tower的防御……防御装置自动可以攻击需要合理解释". Nothing the player builds aims -- a
	# turret that picks its own targets is the ship's machinery, and only the cabin has one.
	#
	# A trap is set along a LANE: the cells in front of it, as far as `lane` (the wire stops at
	# anything built or standing in the way), in the direction it faces -- R turns it while it
	# is being placed. An animal walking into the tripwire looses it, the way hunters set these
	# on game trails; then it has to be re-armed, `rearm_seconds` of the string being drawn
	# back, which is watched happen (Trap.gd). A trap is a building like any other: it fills its
	# cell, is solid, and a raid bites the ones that shoot it (DINO_AI.shooter_kinds).
	#
	# The opening's trap, wood and vine (tools/generate_props.py trip_bow): a sapling bow on a
	# stock in two forked stakes. One arrow at the first animal on the wire, half a raptor
	# (DINOS.raptor.hp) -- it does not stop a pack, it takes the fight out of the front of one,
	# and a wall or the Hero finishes it -- and a slow re-arm. Four wood: a line of palisade is
	# still where the opening's wood goes.
	"trip_bow": {
		"name": "BUILDING_TRIP_BOW_NAME",
		"kind": "trap",
		"cells": 1,
		"height": 0.5,
		"hp": 8.0,
		"cost": {"wood": 4},
		"lane": 4,
		"damage": 1.4,
		"pierce": false,
		"rearm_seconds": 3.0,
		# The shooting slot of the build menu (GAME-DESIGN 6.0 rule 2, v0.6 round six): bone makes it the
		# set crossbow where it stands.
		"upgrades_to": ["set_crossbow"],
	},
	# The set crossbow, the trip bow with bone (tools/generate_props.py set_crossbow): a heavy stock
	# on a crib of logs, a seasoned stave, a bone-headed bolt -- two bolts a raptor,
	# heavier than the trip bow's arrow even to one animal. It stands like the stone it is set
	# on: a pack goes for what shoots it (DINO_AI.shooter_kinds), and set into a ring facing out
	# -- where it does most -- a trap that fell like a palisade section was the hole the raid
	# came in by (measured: tools/playtest.gd siege, at 16 hit points six of them were gone and
	# the cabin with them; at 40 they hold -- see WAVES). Its bolt flies the whole lane and
	# goes through everything on it -- a raid walks a lane in file, so set down
	# the line of a funnel it answers the column, not the one at the front. Wood for its body and
	# bone for what cuts, and nothing else (GAME-DESIGN 6.0: one word a material -- it was stone
	# and bone until v0.6 round six, a plinth under it): the trip bow's four wood and one bone
	# more, so the first raid's bone still pays for the pick and the first crossbow (9.2). Its
	# hit points stay what held a ring: heavy timber on a crib, not a sapling on two sticks.
	"set_crossbow": {
		"name": "BUILDING_SET_CROSSBOW_NAME",
		"kind": "trap",
		"cells": 1,
		"height": 0.55,
		"hp": 40.0,
		"cost": {"wood": 4, "bone": 1},
		"lane": 6,
		"damage": 2.0,
		"pierce": true,
		"rearm_seconds": 4.0,
		# Improved where it stands (GAME-DESIGN 6.1: a line of buildings upgrades in place).
		"upgrades_to": "set_crossbow_2",
	},
	# The set crossbow improved where it stands: a second stave lashed over the first and a rack
	# of spare bolts, so one is spanned while the other looses -- it re-arms in little more than
	# half the time -- on a plinth built up to carry them: what a late base is held by, the
	# beacon's final wave above all (MAPS.beacon.final_raids). Never placed from the menu; what the upgrade costs is the difference between
	# the two prices (Config.upgrade_cost), so its price is still what it is made of.
	"set_crossbow_2": {
		"name": "BUILDING_SET_CROSSBOW_2_NAME",
		"kind": "trap",
		"cells": 1,
		"height": 0.6,
		"hp": 70.0,
		"cost": {"wood": 4, "bone": 3},
		"lane": 6,
		"damage": 2.0,
		"pierce": true,
		"rearm_seconds": 2.5,
		"upgrades_to": "",
	},
	# THE TRAPS LAID IN THE WAY (GAME-DESIGN 6.0 rule 3: 刺、砸、困; v0.6 round six, the player: "防御太单调，木头石头
	# 都是bow（而且bow不是很flexible，如果前方被墙挡住了就不能进攻）"): three more jobs on the menu, each its own answer,
	# each on the ground of one cell and in nobody's way (walk_over) -- what walks onto it is what it takes, and no
	# wall in front of it stops it (CellTrap.gd). Their first forms are wood alone; one material takes each up.
	#
	# 刺 SPIKES: a patch of fire-hardened stakes, points up among the litter (tools/generate_props.py
	# ground_spikes). Whatever steps on it is stabbed as it steps on (`damage`) and goes at `slow` of its pace
	# while on it; every stab blunts it (`wear` of its hit points), mended at its price. Always set: the answer to
	# what is too quick for a bow's re-arming.
	"ground_spikes": {
		"name": "BUILDING_GROUND_SPIKES_NAME",
		"kind": "spikes",
		"cells": 1,
		"walk_over": true,
		"height": 0.35,
		"hp": 6.0,
		"cost": {"wood": 2},
		"damage": 0.6,
		"slow": 0.5,
		"wear": 1.0,
		"upgrades_to": ["bone_spikes"],
	},
	# With bone points lashed on (6.0: bone is what cuts): deeper, slower to cross, longer to blunt.
	"bone_spikes": {
		"name": "BUILDING_BONE_SPIKES_NAME",
		"kind": "spikes",
		"cells": 1,
		"walk_over": true,
		"height": 0.4,
		"hp": 10.0,
		"cost": {"wood": 2, "bone": 2},
		"damage": 1.2,
		"slow": 0.4,
		"wear": 1.0,
		"upgrades_to": "",
	},
	# 砸 THE DEADFALL: a weight propped over the way on a figure-four of sticks (tools/generate_props.py
	# deadfall) -- a heavy log first. The first thing to walk under it brings it down on everything on its cell
	# (`damage`): the answer to the big and the armoured. Propped again over `rearm_seconds`, the weight seen
	# rising: it turns `swing_degrees` about `swing_axis` from propped to down (CellTrap._show_set; the model's
	# DEADFALL_RISE_DEGREES).
	"log_deadfall": {
		"name": "BUILDING_LOG_DEADFALL_NAME",
		"kind": "deadfall",
		"cells": 1,
		"walk_over": true,
		"height": 0.5,
		"hp": 10.0,
		"cost": {"wood": 3},
		"damage": 2.5,
		"rearm_seconds": 8.0,
		"swing_axis": Vector3(0.0, 0.0, 1.0),
		"swing_degrees": -26.0,
		"upgrades_to": ["stone_deadfall"],
	},
	# A slab of stone in the log's place (6.0: stone is what weighs): what it comes down on does not walk away
	# from it -- a Coelophysis never, a Postosuchus a ninth of it gone.
	"stone_deadfall": {
		"name": "BUILDING_STONE_DEADFALL_NAME",
		"kind": "deadfall",
		"cells": 1,
		"walk_over": true,
		"height": 0.5,
		"hp": 20.0,
		"cost": {"wood": 3, "stone": 3},
		"damage": 5.0,
		"rearm_seconds": 10.0,
		"swing_axis": Vector3(0.0, 0.0, 1.0),
		"swing_degrees": -26.0,
		"upgrades_to": "",
	},
	# 困 THE SNARE: a running noose on a sapling bent down to a trigger peg (tools/generate_props.py snare) --
	# twisted grass first, plant fibre, which is the wood's. The first thing to step in is caught and held where
	# it stands (`hold_seconds`; a boss `boss_hold_seconds` -- grass does not hold one), the sapling seen
	# springing up (`swing_degrees` about `swing_axis`, the model's SNARE_BEND_DEGREES); set again over
	# `rearm_seconds` once it lets go. The answer to what has to be made to stand still: on a bow's lane.
	"grass_snare": {
		"name": "BUILDING_GRASS_SNARE_NAME",
		"kind": "snare",
		"cells": 1,
		"walk_over": true,
		"height": 1.0,
		"hp": 6.0,
		"cost": {"wood": 2},
		"hold_seconds": 2.5,
		"boss_hold_seconds": 0.0,
		"rearm_seconds": 6.0,
		"swing_axis": Vector3(-0.434, 0.0, 0.901),
		"swing_degrees": 58.0,
		"upgrades_to": ["hide_snare"],
	},
	# A thong of hide for the noose (6.0: hide is what binds): it holds longer, and holds a boss a while.
	"hide_snare": {
		"name": "BUILDING_HIDE_SNARE_NAME",
		"kind": "snare",
		"cells": 1,
		"walk_over": true,
		"height": 1.0,
		"hp": 8.0,
		"cost": {"wood": 2, "hide": 1},
		"hold_seconds": 4.0,
		"boss_hold_seconds": 1.5,
		"rearm_seconds": 5.0,
		"swing_axis": Vector3(-0.434, 0.0, 0.901),
		"swing_degrees": 58.0,
		"upgrades_to": "",
	},
	# THE WALLS, v0.6 round two: "重新设计墙，让墙体逻辑简单清晰，墙必须让它们和别的建筑能更贴合……木栅栏成本
	# 太高，用处太小……石墙恐龙能穿过，不合理，木栅栏可以稍微大一点，而且人不能再穿过墙了".
	#
	# One cell of the building grid each (BUILD_CELL, a metre), filled: a run of them is a wall
	# with nothing to slip between, it stands flush against whatever is in the next cell, and
	# whether a way is shut is only whether the cells across it are taken. Nothing gets through
	# a wall -- not a raid, not the Hero; his way through his own wall is a gate.
	#
	# A palisade: sharpened logs a little taller than the Hero, lashed to a rail, that join the
	# next section of wall beside them (Wall.gd; tools/generate_props.py palisade). A metre of it
	# is one wood -- a ring round the cabin was forty wood of stakes, and is a dozen now.
	"wall": {
		"name": "BUILDING_WALL_NAME",
		"kind": "wall",
		"cells": 1,
		"hp": 8.0,
		"height": 1.25,
		# Sharpened: whatever presses against it is hurt, per tick, so a line wears a raid
		# down instead of only holding it -- a chip, not a kill: a raptor (DINOS.raptor.hp)
		# chewing through the 8 hit points comes out alive but nearly dead, leaving the
		# finishing to a trap, the cabin or the Hero. It reaches whoever is against it, body
		# to body (CONTACT_REACH), and nobody walking past.
		"contact_damage": 0.15,
		"contact_tick": 0.5,
		"cost": {"wood": 1},
		# The fence slot of the build menu (GAME-DESIGN 6.0 rule 2, v0.6 round six: "墙上挂机关类似升级
		# 方向，可以做成升级"): most of a wall stays wood, a funnel; where it is bitten, it becomes what
		# the place needs -- bone points on it (sharp), or stone in its place (heavy).
		"upgrades_to": ["bone_stake", "rock_fence", "stone_wall"],
	},
	# The fence with bone (GAME-DESIGN 6.0: bone is what cuts): the same section with bone points
	# lashed to its logs, biting more than twice as hard and lasting a little longer. One bone a
	# metre, as an upgrade where it stands: the raids' bone spent where it does the most harm -- the
	# mouth of a funnel, not a whole ring.
	"bone_stake": {
		"name": "BUILDING_BONE_STAKE_NAME",
		"kind": "wall",
		"cells": 1,
		"hp": 10.0,
		"height": 1.25,
		"contact_damage": 0.35,
		"contact_tick": 0.5,
		"cost": {"wood": 1, "bone": 1},
		"upgrades_to": "",
	},
	# The fence with a rock set on it (GAME-DESIGN 6.0: 砸 as a wall's upgrade -- stone is what weighs; the
	# player: "墙上挂机关类似升级方向，可以做成升级"): a block of sandstone balanced on the post's points, held
	# by a thong (tools/generate_props.py rock_palisade). Bitten, the section shakes it off onto what is
	# biting it -- everything against it takes `drop_damage` -- and it is set back on over
	# `drop_rearm_seconds`, seen rising (Wall). Where a fence is chewed, the chewing costs.
	"rock_fence": {
		"name": "BUILDING_ROCK_FENCE_NAME",
		"kind": "wall",
		"cells": 1,
		"hp": 8.0,
		"height": 1.25,
		"contact_damage": 0.15,
		"contact_tick": 0.5,
		"cost": {"wood": 1, "stone": 2},
		"drop_damage": 4.0,
		"drop_rearm_seconds": 12.0,
		"upgrades_to": "",
	},
	# Courses of unmortared stone, capstones on top (GAME-DESIGN 6.2: only blocks, many hit
	# points): it bites nothing, but a big predator that would eat through a palisade is held
	# here a long time (6.3). The fence with stone in its place (6.0: stone is what weighs): a
	# metre of it is a stone.
	"stone_wall": {
		"name": "BUILDING_STONE_WALL_NAME",
		"kind": "wall",
		"cells": 1,
		"hp": 20.0,
		"height": 1.2,
		"cost": {"stone": 1},
		# With bone, a crossbow set into it (6.0): the wall crossbow.
		"upgrades_to": ["wall_crossbow"],
	},
	# A set crossbow built into a stone wall (GAME-DESIGN 6.0; the player: "bow不是很flexible，如果前方被墙挡住了
	# 就不能进攻"): the wall is its body and the bolt what cuts -- stone and bone. It shoots out along a lane
	# from the wall's face, so the wall is no longer what blinds the bow, and it stands a raid's bites as
	# the stone it is set in (tools/generate_props.py wall_crossbow). It is a trap (Trap.gd): a stone wall
	# becomes one by a new building going up in its cells (Building._become), facing out from the cabin;
	# it is joined by the fences beside it as a wall is (`joins_walls`).
	"wall_crossbow": {
		"name": "BUILDING_WALL_CROSSBOW_NAME",
		"kind": "trap",
		"cells": 1,
		"height": 1.2,
		"hp": 60.0,
		"cost": {"stone": 1, "bone": 2},
		"lane": 6,
		"damage": 2.0,
		"pierce": true,
		"rearm_seconds": 4.0,
		"joins_walls": true,
		"upgrades_to": "",
	},
	# A gate: a section of wall the Hero walks through and nothing else does. Now that a wall
	# stops him, it is how he gets in and out of his own camp; a raid treats it as the wall it
	# is. It stands on its own layer (LAYER_GATE), which his body and his mesh leave out, and
	# swings open as he comes up to it (Gate.gd; tools/generate_props.py gate).
	"gate": {
		"name": "BUILDING_GATE_NAME",
		"kind": "wall",
		"cells": 1,
		"hp": 12.0,
		"height": 1.45,
		"hero_passes": true,
		"cost": {"wood": 2},
		"upgrades_to": "",
	},
	# THE FIRES (GAME-DESIGN 9.3, "火与夜"; v0.6 round four, the player: "火把我觉得在夜里是很有用，但需要不只
	# 是照明的作用，比如不用火把，晚上更多的夜行动物袭击（怕火把但是不怕暗淡灯光的船舱）"). A fire burns from dusk
	# to first light, and what it burns is wood from the stock, a night's worth (`fuel`) taken as it
	# lights (5.4 rule 4: "燃料和弹药直接从仓库扣……添柴就是照料"): no wood, no fire. Lit, it lights the
	# ground `light` metres round it -- seen at night that far, where without a light he sees little
	# (FOG.night) -- and what hunts by night will not come into its light (Fire.gd, FIRE). Its flame
	# burns `flame_height` metres up, `flame_size` times a campfire's.
	#
	# The campfire: a ring of stones, a bed of ash, logs leaned together -- what he can make with his
	# hands and wood by the first dusk (GAME-DESIGN 9.2's timeline: "约 6:00 第一个黄昏：生火").
	"campfire": {
		"name": "BUILDING_CAMPFIRE_NAME",
		"kind": "fire",
		"cells": 1,
		# In nobody's way (Building: walk_over): a ring of stones and ash a hand high, stepped over --
		# built by the cabin it shut the way between the cabin and the fence, and he ran on the spot
		# at it (the player's report, 2026-09-29: "camp fire造着会挡住人的路，让campfire不block比较make
		# sense"). The brazier, a chest-high stone plinth, stands in the way as stone does.
		"walk_over": true,
		"height": 0.4,
		"hp": 6.0,
		"cost": {"wood": 3},
		"light": 7.0,
		"fuel": 2,
		"flame_height": 0.22,
		"flame_size": 1.0,
		# The fire slot of the build menu (GAME-DESIGN 6.0): stone raises it into a brazier.
		"upgrades_to": ["brazier"],
	},
	# The brazier: a stone bowl on a drystone plinth -- the fire raised to his chest, which lights
	# further, and burns more (GAME-DESIGN 6: "火盆（石，1：夜里照得更远，每晚从仓库扣木头）"). The campfire
	# with stone (6.0), so it comes once there is a pick; and it stands a raid's bites like the stone
	# it is, and stands in the way as the campfire does not.
	"brazier": {
		"name": "BUILDING_BRAZIER_NAME",
		"kind": "fire",
		"cells": 1,
		"height": 0.7,
		"hp": 20.0,
		"cost": {"wood": 3, "stone": 4},
		"light": 10.0,
		"fuel": 3,
		"flame_height": 0.66,
		"flame_size": 1.2,
		"upgrades_to": "",
	},
}

## THE BUILDING GRID (v0.6 round two). Every building stands on whole cells of this size and
## fills them: its collider is its cells, and its art is fitted to them. A cell is taken or it
## is free, and that is the whole of what decides where anything can go and where anybody can
## walk -- the tile a tower needed and the finer grid stakes were laid on are gone, and with
## them the tower that could only go up a tile away from a fence, and the gap between them a
## raptor fitted through.
##
## A metre: the Hero is 0.8 m across and a raptor as wide, so one free cell is a way through
## and one taken cell is a wall -- and a fence section is "a little bigger" than the 0.62 m
## stake it replaces. The cells are CENTRED on whole metres, so the middle of every tile
## (TILE_SIZE, the map's grid: hills, trees, rocks) is the middle of a cell.
const BUILD_CELL: float = 1.0

## How far past its own body something pressed against a sharpened wall is still hurt by it, in
## metres: body to body, so it reaches whoever is against it and nobody walking past.
const CONTACT_REACH: float = 0.15

## A gate's door (Gate.gd): it swings open when the Hero comes within `open_radius` metres of the
## gate's middle -- a stride before he reaches it, so he never walks into a shut door -- by
## `open_degrees`, over `swing_seconds`, and shut behind him. Only art: the gate lets him through
## whatever the door is doing.
const GATE: Dictionary = {
	"open_radius": 1.4,
	"open_degrees": 100.0,
	"swing_seconds": 0.35,
}

## Physics layers, as bit masks. 1 ground, 2 buildings, 4 hero, 8 nest (dinos carry
## 4|8), and this one.
##
## A BLUEPRINT IS CLICKABLE BUT SOLID TO NOBODY. It used to be given layer 0 with its
## collision shape disabled, which does stop it blocking anyone -- and also makes it
## invisible to the click raycast, so unfinished work could not be clicked to carry on
## with. Its own layer keeps both halves: the picking ray looks here, and nothing else
## does.
const LAYER_BLUEPRINT: int = 16

## Walls. They stood apart from other buildings so the Hero could walk through his own fence;
## since v0.6 round two ("人不能再穿过墙了") a wall stops him like anything else, and his way
## through is a gate (LAYER_GATE). The layer stays its own because what a wall is -- something a
## raid only bites when it shuts the way -- is worth being able to ask of a collider.
const LAYER_WALL: int = 32

## WHAT IS CLICKED BY MORE THAN WHAT BLOCKS. A tree is clicked anywhere on its crown, seen
## from above, but only its trunk is in anybody's way: its crown-sized shape is on this
## layer, which the picking ray looks at and nothing else does (not the walking mesh, not
## anyone's movement), and a trunk-sized one blocks (RESOURCE_NODES.trunk_radius). With the
## crown blocking, the walking mesh was carved 1.6 m round every trunk and the Hero chopped
## from two metres off, swinging at the air.
const LAYER_PICK: int = 64

## The rest of the layers, named (v0.6 round two). The ground and what stands on it -- hills,
## tree trunks -- is 1; finished buildings 2; the Hero 4; the dinosaurs 8. Every walker has a
## body now that collides (Dino, Hero): nothing overlaps anything, and nothing walks through a
## wall. The nest is on a layer of its own, which nobody walks into -- the raid pours out of it.
const LAYER_GROUND: int = 1
const LAYER_BUILDING: int = 2
const LAYER_HERO: int = 4
const LAYER_DINO: int = 8
## A gate: a wall the Hero passes and nothing else does. His body and his mesh leave this layer
## out; a raid's do not.
const LAYER_GATE: int = 128
const LAYER_NEST: int = 256

## How the navigation meshes are baked. See scripts/core/NavMaps.gd.
const NAV: Dictionary = {
	# Fine enough to see the gap between two stakes. A stake is 0.62m and they snap 0.67m
	# apart, so a coarse bake would smear a fence into a solid line and the gaps the
	# player deliberately left would stop existing.
	# 0.1, so that agent_radius is a WHOLE number of voxels (0.4 = 4 of them). The bake
	# quantises the radius to voxels and warns when it has to round, and a radius that is
	# silently bigger than declared is a fence that seals gaps the player left open.
	"cell_size": 0.1,
	# The same for height, and it has to be set on the MAP as well as on the mesh. Only
	# the size used to be, so every bake landed on a map still at the engine's default
	# 0.25 and warned that the two disagreed -- twelve hundred times over one test run.
	"cell_height": 0.1,
	# What the mesh is carved for. One radius for everything that walks: a theropod is
	# wider and can be routed through a gap it does not fit -- its body stops it there, and
	# being stopped by a wall is a wall to bite (Dino._unstick). A cell of the building grid
	# left open in a wall keeps a strip of mesh at this radius, so a raptor is routed through
	# the funnel the player left (test_v06_one_grid).
	"agent_radius": 0.4,
	# The smallest island of walkable ground the bake keeps, in voxels a side (squared, so 8 is
	# 0.64 m square at cell_size 0.1). The roof of every building is floor to the bake; on a metre
	# of wall that is a sliver cut off from everything, and "the nearest walkable point to that
	# wall" landed on it -- up on the wall, where no route goes.
	"region_min_size": 8.0,
	# The furthest a walker may be MOVED by being put back on the mesh, in metres.
	#
	# A correction is a correction, not a teleport. Measured without this: a raptor
	# standing at (1, -8.5) was moved to (-0.11, 0.45) -- eight and a half metres, on top
	# of the cabin -- because the navigation map had not finished its first sync and
	# map_get_closest_point answers (0, 0, 0) until it has. Nothing about the answer says
	# it is not ready; it is simply wrong for two or three frames, which is exactly the
	# window a wave spawns in.
	#
	# 1.0 is above every honest correction and far below an accident. The largest real one
	# is a fence going up around someone already standing there, which is the agent radius
	# plus half a stake, 0.71m. Anything bigger means either the mesh is not ready or the
	# animal is somewhere the mesh does not reach at all -- sealed inside a ring it should
	# be chewing its way out of, not flung out of.
	"max_correction": 1.0,
}

## How tall a building stands when it does not say otherwise. Height is the honest
## lever for "this thing is imposing": widening a building eats into the lane the
## Hero needs, while making it taller costs nothing.
const BUILDING_HEIGHT_DEFAULT: float = 1.0

static func get_building_height(type_id: String) -> float:
	if BUILDINGS.has(type_id) and BUILDINGS[type_id].has("height"):
		return maxf(0.2, float(BUILDINGS[type_id]["height"]))
	return BUILDING_HEIGHT_DEFAULT

## The colour a building is drawn in while the art is still placeholder boxes.
## Asked by the building itself and by the build preview, so the ghost is always
## the colour of the thing it is promising.
static func get_building_color(type_id: String) -> Color:
	if COLORS.has(type_id):
		return COLORS[type_id]
	return Color(0.6, 0.6, 0.6)

## "box" (one solid block) or "spikes" (a row of small sharpened cones).
##
## Reads VISUALS rather than BUILDINGS: what a thing is drawn as is a fact about its
## art, and since v0.5 all of those live in one table. The accessor stays because the
## build menu and the preview ask the question about a building type, not about a
## visual key.
static func get_building_mesh_style(type_id: String) -> String:
	return get_placeholder_style("building/" + type_id)

static func get_placeholder_style(key: String) -> String:
	if VISUALS.has(key):
		return String(VISUALS[key].get("placeholder", "box"))
	return "box"

## Damage per second a building deals to whatever is pressed against it. Zero for
## everything that is not sharpened. The one place damage-per-tick is turned into
## damage-per-second, so the build menu and Wall itself cannot disagree.
static func get_contact_dps(type_id: String) -> float:
	if not BUILDINGS.has(type_id):
		return 0.0
	var data: Dictionary = BUILDINGS[type_id]
	var dmg: float = float(data.get("contact_damage", 0.0))
	var tick: float = float(data.get("contact_tick", 0.0))
	if dmg <= 0.0 or tick <= 0.0:
		return 0.0
	return dmg / tick

## How many cells of the building grid `type_id` takes (BUILD_CELL), east-west and north-south:
## its "size" where it is not square -- the cabin, a module seven cells long -- else "cells" a
## side; 1 for everything the player builds. Odd both ways, so a building has a middle cell to
## stand on.
static func get_building_size(type_id: String = "") -> Vector2i:
	if type_id != "" and BUILDINGS.has(type_id):
		var row: Dictionary = BUILDINGS[type_id]
		if row.has("size"):
			var v: Vector2i = row["size"]
			return Vector2i(maxi(1, v.x), maxi(1, v.y))
		var n: int = maxi(1, int(row.get("cells", 1)))
		return Vector2i(n, n)
	return Vector2i.ONE

## The longer side of `type_id`, in cells.
static func get_building_cells(type_id: String = "") -> int:
	var size: Vector2i = get_building_size(type_id)
	return maxi(size.x, size.y)

## Half of `type_id`'s box on the ground, in metres: x east-west, y north-south.
static func get_building_half(type_id: String = "") -> Vector2:
	return Vector2(get_building_size(type_id)) * BUILD_CELL * 0.5

## Whether `type_id` has an inside to walk about in -- its walls solid, the rest of its box not
## (the cabin): what stands in its cells is not therefore inside a wall.
static func is_hollow(type_id: String) -> bool:
	return BUILDINGS.has(type_id) and bool(BUILDINGS[type_id].get("hollow", false))

## How far `point` is from the outside of a `type_id` standing at `centre`, in metres, on the
## ground: 0 when touching or inside. To its box -- buildings fill their cells and are never
## turned.
##
## Reach, where a dinosaur stands to bite, and how close the Hero has to be are all measured to
## the box: a circle of half the footprint sits inside a square's corners, and a raptor at the
## cabin's corner could not bite what it stood against.
static func gap_to_building(point: Vector3, type_id: String, centre: Vector3) -> float:
	var half: Vector2 = get_building_half(type_id)
	var dx: float = absf(point.x - centre.x)
	var dz: float = absf(point.z - centre.z)
	return Vector2(maxf(dx - half.x, 0.0), maxf(dz - half.y, 0.0)).length()

## How far from `type_id`'s centre its outside is, heading along `dir` (flat, unit): where the
## ray leaves its box.
static func building_extent_along(type_id: String, dir: Vector3) -> float:
	var half: Vector2 = get_building_half(type_id)
	return minf(half.x / maxf(0.0001, absf(dir.x)), half.y / maxf(0.0001, absf(dir.z)))

## What sort of thing this is: "wall" for anything a wall is made of, whatever else a building
## declares, or "" for a type that says nothing.
static func get_building_kind(type_id: String) -> String:
	if not BUILDINGS.has(type_id):
		return ""
	return String(BUILDINGS[type_id].get("kind", ""))

## The longer side of `type_id`'s box, in metres: its cells. Everything fills its cells; where
## the two sides differ (get_building_size), what asks for a single figure gets the longer.
static func get_building_footprint(type_id: String = "") -> float:
	return float(get_building_cells(type_id)) * BUILD_CELL

## Whether the Hero walks through `type_id` -- a gate -- where everything else stops him.
## Whether `type_id` is in nobody's way once built: walked over, by him and the animals alike, and
## not carved out of anybody's mesh (the campfire).
static func walk_over(type_id: String) -> bool:
	return BUILDINGS.has(type_id) and bool(BUILDINGS[type_id].get("walk_over", false))

static func hero_passes(type_id: String) -> bool:
	return BUILDINGS.has(type_id) and bool(BUILDINGS[type_id].get("hero_passes", false))

## The flag needed before `res_id` can be cut by hand, or "" for anything bare
## hands can take.
## Whether `res_id` is one of the beacon's parts, which come out of the ship's wrecks (WRECKS): the
## bar shows one only while it is held, and its first find is said as a part found.
static func is_part(res_id: String) -> bool:
	return RESOURCE_NODES.has(res_id) and bool(RESOURCE_NODES[res_id].get("part", false))

static func harvest_requires_unlock(res_id: String) -> String:
	if RESOURCE_NODES.has(res_id):
		return String(RESOURCE_NODES[res_id].get("requires_unlock", ""))
	return ""

## What he can do for good, in the order it can be made: every recipe whose unlock `owned`
## (GameState.unlocks) holds -- a pick that opens stone, an axe that fells faster, a pot to sear
## on (v0.6 round three: "人获得的物品，目前都是能力……作为一个小正方形图标……能力槽要可扩展"). His
## card shows each as a square with its own icon (the recipe's id, tools/build_icons.py), named and
## explained on hover (recipe_effect_text). Whatever else becomes his for good later is one more
## source here, and gets its square the same way.
static func abilities(owned: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var held: Dictionary = kit(owned)
	for slot in KIT_SLOTS:
		if held.has(slot):
			out.append(String(held[slot]))
	return out

## What making `recipe_id` did, in words, for the moment it is done: the resources it
## brings in faster ("Wood x2"), the one it lets him gather at all, or -- a vessel -- that
## meals cooked on it do more. "" for anything else. From the recipe's own data, so a new
## tool says itself (GAME-DESIGN 14.2, path 4).
static func recipe_effect_text(recipe_id: String) -> String:
	if not RECIPES.has(recipe_id):
		return ""
	var row: Dictionary = RECIPES[recipe_id]
	var flag: String = String(row.get("unlocks", ""))
	var parts: PackedStringArray = []
	var speeds: Dictionary = row.get("harvest_speed", {})
	for res_id in speeds:
		# Its words from the table, with the times sign the rest of them use (the debug-agent's BUG-020:
		# the axe said "Wood x2" with a letter x, the spear "hits ×2").
		parts.append(TranslationServer.translate("EFFECT_HARVEST_SPEED") % [TranslationServer.translate("RESOURCE_%s" % String(res_id).to_upper()),
			factor_text(float(speeds[res_id]))])
	for res_id in RESOURCE_NODES:
		if flag != "" and String(RESOURCE_NODES[res_id].get("requires_unlock", "")) == flag:
			parts.append(TranslationServer.translate("TOOL_OPENS") % TranslationServer.translate(String(RESOURCE_NODES[res_id].get("name", res_id))))
	for method in COOKING_METHODS:
		if flag != "" and String(method.get("vessel", "")) == flag:
			parts.append(TranslationServer.translate("TOOL_VESSEL"))
	# What it does to him, for good (armour, boots, a weapon).
	if float(row.get("max_hp", 0.0)) > 0.0:
		parts.append(TranslationServer.translate("EFFECT_MAX_HP") % int(round(float(row["max_hp"]))))
	if float(row.get("move_speed", 1.0)) != 1.0:
		parts.append(TranslationServer.translate("EFFECT_MOVE_SPEED") % factor_text(float(row["move_speed"])))
	if float(row.get("damage", 1.0)) != 1.0:
		parts.append(TranslationServer.translate("EFFECT_DAMAGE") % factor_text(float(row["damage"])))
	return " · ".join(parts)

## Why `res_id` cannot be cut yet, in words: the tool it takes, where that is made and what
## it costs -- "Stone takes a Bone Pick: make one at the Workbench (1 Bone, 4 Wood)". Said
## where the player meets the wall, right-clicking the rock, so the chain is never a
## riddle (GAME-DESIGN 9.2: the next step is always visible). "" for what bare hands take.
##
## `known` (GameState.knows) keeps the chain to what the run has turned up: until the tool's
## materials have, it only says that bare hands will not do -- the pick is not named before
## the bone it is made of has been seen.
static func missing_tool_hint(res_id: String, known: Callable = Callable()) -> String:
	var flag: String = harvest_requires_unlock(res_id)
	if flag == "":
		return ""
	for recipe_id in RECIPES:
		var row: Dictionary = RECIPES[recipe_id]
		if String(row.get("unlocks", "")) != flag:
			continue
		if not _all_known(row.get("inputs", {}), known):
			return TranslationServer.translate("HINT_NEED_TOOL_VAGUE") % \
				TranslationServer.translate(String(RESOURCE_NODES[res_id].get("name", res_id)))
		var costs: PackedStringArray = []
		for input_id in row.get("inputs", {}):
			costs.append("%d %s" % [int(row["inputs"][input_id]),
				TranslationServer.translate("RESOURCE_%s" % String(input_id).to_upper())])
		return TranslationServer.translate("HINT_NEED_TOOL") % [
			TranslationServer.translate(String(RESOURCE_NODES[res_id].get("name", res_id))),
			TranslationServer.translate(String(row.get("name", recipe_id))),
			TranslationServer.translate("STATION_%s_NAME" % String(row.get("station", "")).to_upper()),
			", ".join(costs)]
	return ""

## What `res_id` is for, worked out from the data rather than written down (GAME-DESIGN
## 4.3 rule 5): every building the player can put up, every recipe and every dish that
## asks for it, and every stage of `map`'s beacon, as {"kind": "building" | "recipe" |
## "dish" | "beacon", "id": ...}. A new building that costs stone makes itself part of what
## stone is for by existing -- nothing to update. Empty means it is for nothing yet, and
## the game does not offer it (4.3 rule 1).
##
## With `known` (GameState.knows), only the uses whose every material has turned up: what
## the bar and the first-pickup line say, so neither gives away what is still to come.
static func uses_of(res_id: String, map: Dictionary = {}, known: Callable = Callable()) -> Array:
	var out: Array = []
	for b_type in player_building_types():
		var cost: Dictionary = BUILDINGS[b_type].get("cost", {}) if BUILDINGS.has(b_type) else {}
		if cost.has(res_id) and _all_known(cost, known):
			out.append({"kind": "building", "id": b_type})
	for recipe_id in RECIPES:
		var inputs: Dictionary = RECIPES[recipe_id].get("inputs", {})
		if inputs.has(res_id) and _all_known(inputs, known):
			out.append({"kind": "recipe", "id": recipe_id})
	for dish_id in DISHES:
		var eats: Dictionary = DISHES[dish_id].get("inputs", {})
		if eats.has(res_id) and _all_known(eats, known):
			out.append({"kind": "dish", "id": dish_id})
	for job_id in beacon_jobs(map):
		var takes: Dictionary = beacon_job(map, job_id).get("inputs", {})
		if takes.has(res_id) and _all_known(takes, known):
			out.append({"kind": "beacon", "id": job_id})
	return out

## Whether `known` (a GameState.knows) holds every material in `cost`; true with no `known`.
static func _all_known(cost: Dictionary, known: Callable) -> bool:
	if not known.is_valid():
		return true
	for res_id in cost:
		if not bool(known.call(String(res_id))):
			return false
	return true

## What `res_id` is for, in words, grouped by what is done with it -- "make Bone Pick ·
## build Crossbow Tower, Bone Stake · repair the beacon" -- worked out from uses_of, so a new
## building or recipe says itself here and nobody writes it down (GAME-DESIGN 4.3 rule 5).
static func uses_text(res_id: String, map: Dictionary = {}, known: Callable = Callable()) -> String:
	var made: PackedStringArray = []
	var built: PackedStringArray = []
	var cooked: bool = false
	var beacon: bool = false
	for use in uses_of(res_id, map, known):
		var id: String = String(use["id"])
		match String(use["kind"]):
			"recipe":
				made.append(TranslationServer.translate(String(RECIPES[id].get("name", id))))
			"building":
				built.append(get_building_name(id))
			"dish":
				cooked = true
			"beacon":
				beacon = true
	var sep: String = TranslationServer.translate("LIST_SEPARATOR")
	var parts: PackedStringArray = []
	if not made.is_empty():
		parts.append(TranslationServer.translate("USE_MAKE") % sep.join(made))
	if not built.is_empty():
		parts.append(TranslationServer.translate("USE_BUILD") % sep.join(built))
	if cooked:
		parts.append(TranslationServer.translate("USE_COOK"))
	if beacon:
		parts.append(TranslationServer.translate("USE_BEACON"))
	return " · ".join(parts)

## Where `res_id` comes from, for someone short of it: the tool it takes when he has not
## made it (missing_tool_hint), or -- for what nothing on the map gives -- that the dead
## leave it, and which of the dead. "" when nothing stands in the way but going to get it.
## Rule 4 of GAME-DESIGN 4.3, said where the price is.
static func source_hint(res_id: String, owned: Dictionary, known: Callable = Callable()) -> String:
	var flag: String = harvest_requires_unlock(res_id)
	if flag != "" and not owned.has(flag):
		return missing_tool_hint(res_id, known)
	if RESOURCE_NODES.has(res_id):
		# A part is in one wreck, and where that is is said: the smoke over it is the one to go to.
		var found: String = String(RESOURCE_NODES[res_id].get("found", ""))
		return (TranslationServer.translate(found) % TranslationServer.translate("RESOURCE_%s" % res_id.to_upper())) \
			if found != "" else ""
	var dropped: bool = false
	var bosses_only: bool = true
	for species in DINOS:
		if int(DINOS[species].get("drops", {}).get(res_id, 0)) > 0:
			dropped = true
			if String(DINOS[species].get("boss", "")) == "":
				bosses_only = false
	if not dropped:
		return ""
	return TranslationServer.translate("SOURCE_BOSSES" if bosses_only else "SOURCE_DINOSAURS") % \
		TranslationServer.translate("RESOURCE_%s" % res_id.to_upper())

## Types offered in the Hero's build menu, in display order: one a job, each its first form, of
## wood alone (GAME-DESIGN 6.0 rule 2; v0.6 round six, the player: "当新的材料出现，老的材料又在，可选的
## 建造物一下子变太多，有点杂乱无章"). Every other material is an upgrade where a building stands
## (BUILDINGS.<id>.upgrades_to): bone stakes and the stone wall off the fence, the set crossbow off
## the trip bow, the brazier off the campfire -- the menu never grows by a material.
## Buildings absent here exist in BUILDINGS but are not placed from the menu ("core" is spawned
## by the level; the rest are what these become).
const BUILDABLE_TYPES: Array[String] = ["wall", "gate", "trip_bow", "ground_spikes", "log_deadfall", "grass_snare", "campfire"]

## Everything the player can have standing: what the menu offers and all it becomes where it stands,
## however many steps up. What a material is for is worked out over these (uses_of).
static func player_building_types() -> Array[String]:
	var out: Array[String] = []
	var todo: Array = BUILDABLE_TYPES.duplicate()
	while not todo.is_empty():
		var t: String = String(todo.pop_front())
		if out.has(t) or not BUILDINGS.has(t):
			continue
		out.append(t)
		todo.append_array(upgrade_targets(t))
	return out

## What every trap shares (BUILDINGS kind "trap", Trap.gd).
const TRAPS: Dictionary = {
	# The tripwire, ankle-high on a raptor across the middle of its lane: a hand narrower than
	# the cell each side, so an animal walking the next lane over does not brush it.
	"wire_width": 0.8,
	"wire_height": 0.18,
	# What trips it: everything a body could be stepping through the wire with, up to this
	# height. A wire is a line; an animal is not, and a raptor's legs are its whole height.
	"trigger_height": 1.0,
	# How far the string moves between drawn and let go, in metres: the nock to the chord of
	# the bow on the model (tools/generate_props.py TRAP_STRING_TRAVEL). Re-arming draws it back
	# along that path -- how the player sees a trap being made ready again.
	"string_travel": 0.26,
	# How fast a loosed arrow or bolt is drawn flying, in metres a second. The hit lands the
	# moment it looses; the flight is only what is seen.
	"shot_speed": 32.0,
	# The lane shown on the ground under a trap being placed, the wire's colour.
	"lane_color": Color(0.95, 0.8, 0.35),
	# The traps laid in the way (CellTrap): an animal is on one when its middle is on the cell or this far
	# past its edge (metres) -- a foot is ahead of a middle -- and a slowing lasts this long after it steps off
	# (seconds), so a stride across the edge does not flicker it.
	"cell_reach": 0.2,
	"slow_linger": 0.25,
}

## The night's hunters (NightProwl, ProwlerDino; GAME-DESIGN 9.3; v0.6 round four, the player: "不用火把，
## 晚上更多的夜行动物袭击（怕火把但是不怕暗淡灯光的船舱）").
const PROWL: Dictionary = {
	# One comes up out of the river this many seconds into the night, and another every `every`
	# after -- while fewer are out than may be: `most_lit` with a fire burning within `lit_within`
	# metres of the cabin, `most_dark` without ("不点火，夜里摸上来的就多"). The night is 90 s (DAY).
	"first_after": 8.0,
	"every": 18.0,
	# They come up in pairs (`pair` at a time; v0.6 round five, the player chose "植龙专找黑里的人": "成对出现"),
	# so as many may be out as two pairs in the dark and one by a fire.
	"most_lit": 2,
	"most_dark": 4,
	"pair": 2,
	"lit_within": 10.0,
	# It goes for the Hero when he is this near and in the dark ("直接冲着人和基地来") -- smelt from this far, the
	# man in the dark is what it is out for (v0.6 round five, the player: "晚上人跑到野外目前也没什么危险，是有恐龙但
	# 没多少会进攻人（没点火把的情况下）" -- chosen "植龙专找黑里的人": "没火的人是植龙的首要目标：闻到就来"). It was
	# 8 m, and a man out in the dark was left be. Lit -- a torch in his hand, a fire's light on him -- it will
	# not come in (lights).
	"hunts_within": 28.0,
	# How it keeps out of a light (FIRE; the torch): it stands `edge_inside` metres inside the light's
	# edge -- dimly lit there, and seen -- and backs out, at `back_out_pace` of its speed, when it finds
	# itself further in than `flee_inside`. Along the edge it paces: `pace_step_degrees` round at a time,
	# every `pace_every` seconds (between the two), at `wary_pace` of its speed, and now and then turns
	# back (`turn_back_chance`).
	"edge_inside": 0.6,
	"flee_inside": 1.6,
	"back_out_pace": 1.3,
	# Backing out, it goes to the nearest part of the edge it can stand on and reach -- tried this many
	# ways round, a place this near the walkable ground counting as on it -- and cornered, getting no
	# further out for `cornered_seconds`, it turns at bay on whoever cornered it for `at_bay_seconds`,
	# the light or no, then tries again (the debug-agent's BUG-018: it stood in the torchlight at his
	# feet in the field's corner). Cornered animals do.
	"way_out_tries": 12.0,
	"way_out_slack": 0.6,
	"cornered_seconds": 1.2,
	"at_bay_seconds": 3.0,
	"pace_step_degrees": 25.0,
	"pace_every": [3.0, 5.0],
	"wary_pace": 0.5,
	"turn_back_chance": 0.3,
	# The eye-shine ("火光照到的黑暗边上能看见眼睛反光"): its eyes glow this colour, this bright at a light's
	# edge or in it, dimming over `eye_reach` metres further out -- a light is what an eye shines back.
	# The eyes on `eye_bone` are a few centimetres, lost from the game's camera: over each a glint
	# `glint_size` metres across, `glint_energy` times its colour at the brightest, so it glows without
	# burning out to white (the debug-agent's TASK-021: "两个白色的小点……默认镜头下看不出来").
	#
	# Smaller and dimmer since the player's report of 2026-09-29: "夜晚的恐龙两个眼睛太亮了，有点像两个灯泡，是需要
	# 炯炯有神，但是不能这么滑稽" -- at 0.3 m and two and a half times its colour, the glint was a lamp
	# on each side of its head. Then half that and half as bright, and two white specks lost twenty metres
	# off (the debug-agent's TASK-027: "20 米就找不到了……建议在这次和上次中间取一个值"). Now halfway
	# between the two: about 0.16 m at the game's distance, bright enough to find at a fire's edge.
	"eye_color": Color(1.0, 0.55, 0.2),
	"eye_energy": 3.2,
	"eye_reach": 3.0,
	"eye_bone": "Head",
	"glint_size": 0.22,
	"glint_energy": 1.9,
	# And sized to the camera: `glint_per_metre` of its distance across, from `glint_least` up to
	# `glint_size` -- two small points up close, one still seen at the game's distance.
	"glint_per_metre": 0.0065,
	"glint_least": 0.035,
	# Brought up out of the river by a wreck's din by day (Din), out of its hours: it goes back to the river
	# once it has not had the man within its reach for this long (seconds).
	"drawn_linger": 20.0,
}

## What every fire shares (BUILDINGS kind "fire", Fire.gd), and the torch in his hand (Hero).
const FIRE: Dictionary = {
	# The parts of the day a fire burns in (DAY.parts): lit as the dusk comes, out at first light.
	"burns": ["dusk", "night"],
	# A fire with no wood for its night tries the stock again this often, in seconds: wood brought in
	# lights it.
	"retry_seconds": 2.0,
	# Its light: warm and wavering, `light_above` metres over the flame. It reaches `light_reach` times
	# as far as the fire keeps the night off (BUILDINGS.<id>.light), so the edge of it is dim -- where
	# eyes are seen shining -- and falls off by the engine's `light_attenuation`. It wavers by `flicker`
	# of its energy, at about `flicker_speed` a second.
	"light_color": Color(1.0, 0.62, 0.32),
	"light_energy": 5.0,
	"light_above": 0.4,
	"light_reach": 1.25,
	"light_attenuation": 0.7,
	"flicker": 0.18,
	"flicker_speed": 7.0,
	# The flame (Fire.make_flame): how many tongues at once and how long each lives (seconds), how far
	# round the middle they start (metres), how fast they rise, how big each is -- a campfire's; a
	# fire's own flame_size scales all of it -- and their colour from white-yellow leaving the wood,
	# through orange, to nothing -- brighter than white where it is hottest, so it glows (the environment's
	# glow).
	"flame": {"amount": 32, "lifetime": 0.8, "spread": 0.1, "spread_degrees": 10.0, "rise": 0.9,
		"speed_min": 0.5, "speed_max": 1.0, "tongue": 0.4,
		"colours": [Color(2.2, 1.8, 0.9, 1.0), Color(1.9, 0.8, 0.2, 0.8), Color(0.7, 0.13, 0.03, 0.0)]},
	# THE TORCH in his hand (Hero.light_torch; GAME-DESIGN 9.3: "火把会烧完"): a wood, and it burns this
	# many seconds -- two of them see a night through (DAY: the dusk is 30 s and the night 90) -- lighting
	# this far round him, as far as a campfire; its flame this big, held in `bone` and kept upright,
	# `tilt_degrees` off it. It dims over its last `fade_seconds`. Only in the dark (burns): by day
	# there is nothing for it to do.
	"torch": {"cost": {"wood": 1}, "seconds": 60.0, "light": 7.0, "flame_size": 0.45, "bone": "hand_l",
		"length": 0.62, "tilt_degrees": 12.0, "fade_seconds": 6.0, "light_energy": 3.5},
}

## Everything `type_id` can be turned into where it stands (BUILDINGS.<id>.upgrades_to: one id, or a
## list -- a fence becomes bone stakes or a stone wall, GAME-DESIGN 6.0), in the order given.
static func upgrade_targets(type_id: String) -> Array[String]:
	var out: Array[String] = []
	if not BUILDINGS.has(type_id):
		return out
	var to: Variant = BUILDINGS[type_id].get("upgrades_to", "")
	for t in (to if to is Array else [to]):
		if BUILDINGS.has(String(t)) and not out.has(String(t)):
			out.append(String(t))
	return out

## The first of them, or "".
static func upgrade_target(type_id: String) -> String:
	var all: Array[String] = upgrade_targets(type_id)
	return all[0] if not all.is_empty() else ""

## What it costs to turn a `type_id` into `target` (the first it can become, if none is named): the
## difference between its price and the price of what it becomes, never less than nothing. A twin
## set crossbow costs a set crossbow and two more bone, so the upgrade is two bone -- and a
## building's price stays exactly what it is made of. {} for what it cannot become.
static func upgrade_cost(type_id: String, target: String = "") -> Dictionary:
	if target == "":
		target = upgrade_target(type_id)
	if target == "" or not upgrade_targets(type_id).has(target):
		return {}
	var have: Dictionary = BUILDINGS[type_id].get("cost", {})
	var out: Dictionary = {}
	var want: Dictionary = BUILDINGS[target].get("cost", {})
	for res_id in want:
		var more: int = int(want[res_id]) - int(have.get(res_id, 0))
		if more > 0:
			out[res_id] = more
	return out

## Seconds the Hero works to turn a `type_id` into `target` (the first, if none is named): the
## build-time curve on the upgrade's own price, so an upgrade takes what building that much would.
static func get_upgrade_time(type_id: String, target: String = "") -> float:
	var total: float = 0.0
	var cost: Dictionary = upgrade_cost(type_id, target)
	for res_id in cost:
		total += float(cost[res_id])
	if total <= 0.0:
		return 0.0
	return maxf(BUILD_TIME_MIN, pow(total, BUILD_TIME_EXPONENT) * BUILD_SECONDS_PER_RESOURCE)

# ==============================================================================
# 3. Dinosaur Definitions (DINOS)
# ==============================================================================
## `behaviour` picks the class that decides what this species *wants* -- see
## DINO_BEHAVIOURS. Everything else about a dinosaur (moving, fighting, dying) is
## shared, so adding a new small pack species is an entry here and nothing more.
##
## `drops` is what is left on the ground when one dies, and it is the only source
## of `food` and `bone` in the game -- a carcass gives meat and bone, or you get
## neither. That is the gate onto stone: the pick needs bone, so the first raid
## stops being purely a threat and becomes something the player needs.
##
## SCALE. Everything in the valley is sized against the Hero, and he is 1.2 m: the size a
## person is next to everything else here -- a stake at his chest, a tree fern three
## times his height, the cabin twice it. Real proportions from there: a raptor is
## Deinonychus-sized, its head at his chest; the big theropod stands two and a half times
## his height. They were drawn the other way up: the Hero as tall as the tyrannosaur and
## twice the height of a raptor.
##
## So the HEIGHT of `size` is how tall the animal stands. Its WIDTH is the body the game
## touches -- the fence gaps it fits through, how far it reaches, how close a pack packs
## -- and that did not move when the stature did. Nothing but the art and the height of
## the collider reads the height; what a dinosaur sees in its way is looked for at
## DINO_PROBE_HEIGHT, whatever its size.
const DINOS: Dictionary = {
	"raptor": {
		"name": "DINO_RAPTOR_NAME",
		# A little softer (v0.6 feedback: "初始木栅栏强度很低，需要把迅猛龙强度稍微调低"): a
		# stake stands nine bites instead of eight, and the raptor that chews through one
		# still comes out alive and nearly dead (BUILDINGS.wall) -- softer than that and a
		# single stake would kill raptors forever without falling.
		"hp": 2.8,
		"speed": 4.0,
		"damage": 0.9,
		"attack_rate": 1.0,
		"behaviour": "pack",
		"drops": {"food": 1, "bone": 1},
		"size": Vector3(0.8, 0.9, 0.8),   # head at the Hero's chest, three times his length
	},
	# The head of the pack (GAME-DESIGN 7.5): a bigger, harder raptor at the front of every
	# big wave -- the same habit and the same body width as the rest (it has to fit the
	# same gaps), a head taller, and three times as hard to kill. What it leaves is the
	# reward for having killed it: a boss's cut of meat.
	"raptor_alpha": {
		"name": "DINO_RAPTOR_ALPHA_NAME",
		"hp": 10.0,
		"speed": 4.4,
		"damage": 1.5,
		"attack_rate": 1.0,
		"behaviour": "pack",
		"boss": "minor",
		"drops": {"prime_meat": 1, "bone": 2},
		"size": Vector3(0.8, 1.15, 0.8),
	},
	# The map's boss (GAME-DESIGN 7.5: comes once in the middle of the game, on the map's
	# beat, and last of all in the beacon's final wave). Hard enough that a trap or two is
	# not an answer on their own -- it is what the stone wall is for (6.3).
	"big_theropod": {
		"name": "DINO_BIG_THEROPOD_NAME",
		"hp": 45.0,
		"speed": 2.0,
		"damage": 3.0,
		"attack_rate": 0.8,
		"behaviour": "siege",
		"boss": "major",
		"drops": {"prime_meat": 3, "bone": 4},
		"size": Vector3(1.6, 3.0, 1.6),   # two and a half times the Hero's height
	},
	# THE FIRST MAP'S CAST (GAME-DESIGN 7.2, station 1: the Late Triassic, the Chinle Formation,
	# v0.6 round three: "第一关还应该是三叠纪"). The raptor, its alpha and the big theropod stay for
	# the maps they belong to; the valley is raided by these (MAPS.valley).
	#
	# Coelophysis: a light theropod three metres long, found by the hundred together at Ghost
	# Ranch -- the pack that raids. The raptor's numbers, which the opening was balanced on: the
	# same body width (the same gaps), the same bite, the same softness against a stake. A long
	# neck carries its head a little higher.
	"coelophysis": {
		# Hunted by day (GAME-DESIGN 9.3): the ring of bone in a young one's eye is a hawk's -- sharp by
		# day, poor in the dark (Rinehart et al., 2004). Its raids come in the day; at dusk it goes home.
		"hours": ["day"],
		"name": "DINO_COELOPHYSIS_NAME",
		"hp": 2.8,
		"speed": 4.0,
		"damage": 0.9,
		"attack_rate": 1.0,
		"behaviour": "pack",
		"drops": {"food": 1, "bone": 1},
		# Not every one leaves both (v0.6 round three: "肉骨太多可以让死了的恐龙随机掉落解决" -- a
		# run left twenty and thirty of each unused): each has this chance, under DROPS.pity_after.
		"drop_chance": {"food": 0.5, "bone": 0.5},
		"size": Vector3(0.8, 0.95, 0.8),
	},
	# The head of the pack (GAME-DESIGN 7.5): a bigger, older Coelophysis at the front of every
	# big wave -- the alpha's numbers, and the middle of the run's high point: it is who comes, not
	# the map's boss (v0.6 round three: "中段的小boss不应该把最后的大boss形象暴露").
	"coelophysis_alpha": {
		# The pack's hours are its leader's.
		"hours": ["day"],
		"name": "DINO_COELOPHYSIS_ALPHA_NAME",
		"hp": 10.0,
		"speed": 4.4,
		"damage": 1.5,
		"attack_rate": 1.0,
		"behaviour": "pack",
		"boss": "minor",
		# Its hide (v0.6 round three: "精英就掉落皮可以做护甲和鞋子就行了"), not a prime cut -- what he
		# makes armour and boots of (RECIPES, the row's armour and boots) -- and its bones.
		"drops": {"hide": 2, "bone": 2},
		"size": Vector3(0.8, 1.25, 0.8),
	},
	# Postosuchus: not a dinosaur -- a rauisuchian, a land-going relative of the crocodiles four
	# or five metres long, and the biggest predator of its world (7.2: "恐龙还不是霸主"). The map's
	# boss, seen once: last of all in the beacon's final wave. Built low and long rather than
	# tall -- twice the Hero's height at the head -- and as hard as the big theropod it stands in
	# for, so the stone wall is still what it is for (6.3).
	"postosuchus": {
		# No fossil tells its hours; an ambusher of the crocodiles' line, it keeps theirs -- out at
		# dusk and in the night (GAME-DESIGN 9.3). It only comes last of all, in the final wave.
		"hours": ["dusk", "night"],
		"name": "DINO_POSTOSUCHUS_NAME",
		"hp": 45.0,
		"speed": 2.0,
		"damage": 3.0,
		"attack_rate": 0.8,
		"behaviour": "siege",
		"boss": "major",
		"drops": {"hide": 2, "bone": 4},
		"size": Vector3(1.5, 2.0, 1.5),
	},
	# The phytosaur: not a crocodile, though it looks like one -- a long-snouted, armoured reptile of
	# the rivers, Machaeroprosopus in the same Chinle rocks as Coelophysis (GAME-DESIGN 7.2), three
	# and a half metres of it, a metre high. The night's hunter (9.3: "夜里：……危险换成了河边：植龙沿岸巡，
	# 基地离河近就会被摸上来"): up out of the river in the dark (NightProwl), for the Hero and the cabin --
	# and afraid of fire (ProwlerDino). Heavier than a Coelophysis, and slower on land; what it leaves is
	# meat and bone -- hide is the elites' (v0.6 round three: "精英就掉落皮可以做护甲和鞋子就行了").
	"phytosaur": {
		# Out at night (9.3: crocodiles "傍晚到入夜后打猎，夜里还会在离水五十米内的岸上埋伏").
		"hours": ["night"],
		"name": "DINO_PHYTOSAUR_NAME",
		# Tougher and harder-biting than it was (v0.6 round five: "咬得更疼、更抗打" -- it was 8 and 1.2, and "人还能
		# 把那个恐龙干掉"): four of a Coelophysis's hit points, twice its bite. A man in the dark is its meat.
		"hp": 12.0,
		"speed": 3.0,
		"damage": 1.8,
		"attack_rate": 0.8,
		"behaviour": "prowl",
		"drops": {"food": 2, "bone": 1},
		"size": Vector3(0.9, 1.0, 0.9),
	},
	# Hesperosuchus agilis: an early crocodylomorph of the same Chinle rocks, the crocodile's line before it
	# went to the water -- a metre and a bit, slender, long-legged, "agile" by name (GAME-DESIGN 7.2; v0.6 round
	# six, the player: "恐龙每次都是从一个地方来进攻，物种到day 4也就一种，太单调" -- chosen "快跑的黄昏鳄").
	# THE RUNNER (RunnerDino): half as fast again as a Coelophysis and brittle -- a trip bow's arrow all but
	# kills it, but at its pace a bow re-arms after it has gone by. It comes for the man, not the cabin, and
	# stops for no trap: spikes and snares, which need no re-arming, and a wall between him and it answer it.
	# In the raids from the third day (MAPS.<id>.raiders_by_day). By day, as its raid is.
	"hesperosuchus": {
		"hours": ["day"],
		"name": "DINO_HESPEROSUCHUS_NAME",
		"hp": 1.6,
		"speed": 6.5,
		"damage": 0.6,
		"attack_rate": 1.4,
		"behaviour": "runner",
		# The crocodile-line's hiss, a small animal's (SOUNDS: Postosuchus's recordings pitched right up).
		"voice": "hesperosuchus",
		"drops": {"food": 1, "bone": 1},
		"drop_chance": {"food": 0.5, "bone": 0.5},
		"size": Vector3(0.6, 0.55, 0.6),
	},
	"pterosaur": {
		"name": "DINO_PTEROSAUR_NAME",
		"hp": 2.0,
		"speed": 6.0,
		"damage": 1.0,
		"attack_rate": 1.2,
		"behaviour": "pack",
		"drops": {"food": 1, "bone": 1},
		"size": Vector3(0.8, 0.5, 0.8),
	}
}
const DINO_LANE_OFFSETS: Array[float] = [-0.35, 0.35, 0.0]
## A habit, and the class that implements it. Species with the same habit share a
## class outright: a second kind of raptor is "pack" and needs no new code.
const DINO_BEHAVIOURS: Dictionary = {
	"pack": "res://scripts/entities/PackDino.gd",
	"siege": "res://scripts/entities/SiegeDino.gd",
	# Hunts by night, and will not come into a fire's light (GAME-DESIGN 9.3).
	"prowl": "res://scripts/entities/ProwlerDino.gd",
	# Quick and brittle, for the man and past the traps (GAME-DESIGN 7.2: Hesperosuchus).
	"runner": "res://scripts/entities/RunnerDino.gd",
}

## The script a species is built from. Anything without a declared habit gets the
## plain base, which walks the path and bites what blocks it.
static func get_dino_script_path(type_id: String) -> String:
	if not DINOS.has(type_id):
		return "res://scripts/entities/Dino.gd"
	var habit: String = String(DINOS[type_id].get("behaviour", ""))
	return String(DINO_BEHAVIOURS.get(habit, "res://scripts/entities/Dino.gd"))

const DINO_SEPARATION_MIN_DIST: float = 1.15

## How quickly a dinosaur's velocity follows the one it wants, per second.
##
## A HEADING IS A PHYSICAL THING THAT TURNS. Steering used to be recomputed from nothing
## every frame and applied whole, so any term that changed sign -- which side to pass
## somebody on, which way a neighbour was pushing -- reversed the animal instantly. In a
## crowd pressed into a corner that is a shuffle: measured at over a hundred direction
## reversals in twenty-five seconds, going nowhere and being bled by the spikes the whole
## time. That is the "来回穿梭" that was reported.
##
## Damping it fixes the whole class rather than whichever term was flipping this week.
##
## TUNED AGAINST BOTH THINGS IT TRADES OFF, because it does trade. At 6.0 the shuffle is
## gone and so is most of the raid: a turn takes a sixth of a second and dinosaurs
## brushing the hills, whose speed is reset as they are pushed clear, never get back up
## to it -- two of twenty reached the cabin instead of thirteen. At 20.0 the reversals
## stay where 6.0 put them and the raid is exactly as quick as with no damping at all.
## How wide a dinosaur is to the avoidance solver, and how far it looks for neighbours.
##
## NavigationAgent3D does the avoiding now. The hand-written version it replaces -- a
## separation force, an anti-tailgating throttle, a side to pass on, and a damping term
## to stop all three flip-flopping -- took four attempts and still deadlocked a crowd at
## zero speed and shuffled a pair seventy times in twenty-five seconds. See rule 8 in
## AGENT-TASKS.md: those were not interesting bugs, they were the price of writing local
## avoidance by hand.
const DINO_AVOID_NEIGHBOURS: float = 4.0     # how far it looks for others, in metres
const DINO_AVOID_TIME_HORIZON: float = 1.2   # how far ahead it plans to miss them, in seconds
const DINO_AVOID_MAX_NEIGHBOURS: int = 10

## How a dinosaur makes up its mind, and how its body moves (Dino.gd; v0.6 round two: "我需要
## 更专业的恐龙进攻逻辑，永远不要抽搐或者傻掉"). Every change of mind has a margin or a minimum
## time here, so none can flip back and forth from one frame to the next -- which from outside
## is a twitch -- and a dinosaur that is getting nowhere always has something to do about it.
const DINO_AI: Dictionary = {
	# It reconsiders what to do this often, in seconds -- not every frame. Each animal starts at
	# its own phase, so a raid does not all think at once.
	"think_seconds": 0.25,
	# And asks whether the way to the cabin is shut this often: the answer costs a route, and a
	# fence coming down half a second late is not something anyone can see.
	"route_check_seconds": 1.0,
	# When something is built or knocked down it asks again this soon, in seconds -- after the
	# meshes are baked again, or it gets the old answer and keeps it for a whole recheck.
	"rebake_grace": 0.1,
	# It takes hold at its reach and lets go only this much PAST it, in metres. One step back from
	# the Hero is not an escape, and one that let go at the reach it took hold at would let go and
	# take hold on alternate frames.
	"reach_release": 0.35,
	# The Hero is chased this much past the range it noticed him at, in metres, and no further.
	"chase_slack": 2.0,
	# HEADWAY: over this many seconds a travelling animal must have got this far, in metres, or it
	# is stuck, and looks at what is holding it (Dino._unstick).
	"stuck_window": 1.2,
	"stuck_distance": 0.25,
	# How far past its own body it feels for what it is pressed against, in metres.
	"press_reach": 0.3,
	# Held up in a crowd, it waits its turn this long, in seconds, rather than shoving -- shoving
	# in a jam is a shuffle.
	"patience": 0.8,
	# It turns at this many degrees a second, never snapping. At 540 a raptor turns about in a
	# third of a second -- quick for an animal, and slow enough that a nudge from the avoidance
	# solver is not a twitch.
	"turn_speed": 540.0,
	# Slower than this, in metres a second, it is not heading anywhere to face, and faces what it
	# is going for instead.
	"turn_min_speed": 0.3,
	# An intermediate waypoint counts as reached this close, in metres: a crowd cannot all stand on
	# one point, and the ones that could not would otherwise mill round it. (The last is stood on:
	# it is the cabin, or the end of the road.)
	"waypoint_reach": 1.0,
	# A bend in the road this close to the cabin's walls, in metres, is not gone to: the cabin is
	# (Dino._on_the_doorstep) -- the first map's last bend is a metre behind its back.
	"cabin_approach": 3.0,
	# A place round a building to stand at while biting it, one every this many metres along each
	# face (Dino.ring_round): a body's width (DINOS.coelophysis.size, 0.8) and a little. The cabin's
	# seven-metre face takes seven.
	"slot_spacing": 1.0,
	# Every place round what it came to bite taken, it waits its turn this far out from its walls,
	# in metres -- beyond the outer ring (DINO_STANDOFF_OUTER), at the crowd's edge (Dino.queue_spot);
	# and, waiting, it looks again for a place to bite from every this many seconds.
	"queue_standoff": 2.8,
	"queue_patience": 1.5,
	# This near its place (metres), it faces what it came for, walking or waiting: facing the place
	# while it tried for it and the target while it waited, by turns, was a head swinging each way
	# every second (the debug-agent's BUG-008).
	"face_target_within": 2.0,
	# Come to rest on its spot, it is not sent back onto it for a nudge shorter than this (metres):
	# in a crowd it stepped back at every one, turning to each step and back.
	"spot_slack": 0.4,
	# A place round a building to bite it from counts as one it can get to when its route there ends
	# this near it, in metres. A place behind a fence from it has a route too -- to the near side of
	# the fence, out of reach of the building -- and a raid stood there, milling, for the whole of
	# it (v0.6 round three: "大多数都在后面转来转去"). About the mesh's own margin round a building.
	"slot_stand_slack": 0.5,
	# Going home at the end of its hours (Dino.go_home), it is home this near the nest, in metres.
	"home_reach": 2.0,
	# Its route (NavMaps.path): how close to a corner counts as there, how close to a spot it is
	# ambling to, how far it may be pushed off the route before it asks again, and how far a goal
	# must move before it asks again -- asking costs a route.
	"path_desired_distance": 0.5,
	"target_desired_distance": 0.3,
	"path_max_distance": 2.0,
	"regoal_distance": 0.3,
	# How many times one step may slide along what it meets (Dino._move_body).
	"slide_steps": 4,
	# Pressed against a wall it could go round, with nobody else in the way, it tries the way round
	# this many headway windows before it bites through instead.
	"wall_patience": 3,
	# JAMMED (Dino._watch_for_a_jam): getting no nearer its goal -- by `jam_progress` metres of the
	# way it has left -- for `jam_seconds`, crowd or no crowd, and up against a wall between it and
	# where it is going, it goes through that wall. The way round was there, but a raid's worth of
	# them in single file up a one-metre corridor to a one-cell gap is not a way round: they milled
	# up and down it, walking a lot and getting nowhere, which the headway window (moved, not got
	# nearer) never counted as stuck -- and a crowd never bites a wall it could go round (the player's
	# report, 2026-09-29: "恐龙大波会在走廊（两行栅栏中间徘徊）"). A few, through a funnel, are through
	# long before.
	# The runner (RunnerDino, Hesperosuchus): how far off it comes for the man from, in metres -- across
	# most of the small valley's field; he is what it is after.
	"runner_hunts_within": 18.0,
	"jam_seconds": 4.0,
	"jam_progress": 0.5,
	# And the wall it goes through need not be one it is up against: this far past its body (metres) --
	# a queue waits a body's length behind the one ahead of it, and in a corridor never touches the fence
	# (the debug-agent's BUG-025: seventy seconds, eleven standing, no wall bitten).
	"jam_reach": 1.0,
	# Two bodies whose middles are this close, in metres, are one on top of the other: the engine
	# has no way out to push either along, so one is nudged (Dino._unstack).
	"stacked_within": 0.05,
	# How much a dinosaur's steering gives way, against the Hero's (HERO.avoidance_priority): an
	# agent ignores those below it, so with his above theirs they steer round him and he walks
	# where he is sent.
	"avoidance_priority": 0.5,
	# How much wider than its body it is to the steering solver, in metres: the room it keeps to
	# pass a neighbour by. At none, steering that aims to pass body-to-body gives out when they
	# meet, and an animal slides to a stop at the Hero's shoulder.
	"avoid_margin": 0.1,
	# Its box is lifted this far off the ground, in metres, so the ground it stands on is never
	# something it is pressed against.
	"ground_clearance": 0.08,
	# What its body bumps into (layer names above): everything but the nest it comes out of.
	"collides_with": ["LAYER_GROUND", "LAYER_BUILDING", "LAYER_WALL", "LAYER_GATE", "LAYER_HERO", "LAYER_DINO"],
	# What counts as shooting at it, by BUILDINGS kind: what a pack leaves its path for.
	"shooter_kinds": ["trap"],
	# A trap that shot at it is the one it goes for for this long (seconds); a building it found
	# every place round taken is left be for this long, and something else chosen -- ten raptors
	# went for the one crossbow nearest the nest, which two could bite (the debug-agent's BUG-009).
	"shot_memory": 4.0,
	"crowded_memory": 3.0,
	# Buildings are in the raiders' steering (Building._update_avoidance): an outline of each finished
	# one on these avoidance layers (a bitmask), which their agents avoid (Dino._refresh_walker) and
	# the Hero's does not -- he goes through his gates. Steering round each other, they knew nothing
	# of walls: a raptor squeezed at a fence corner was steered into the fence, pressed there and
	# swung its head (the debug-agent's BUG-009).
	"building_avoidance_layers": 2,
	# How far ahead (seconds) the steering looks for a building's outline: it turns off before it
	# would reach one this soon -- about a body's length at a run -- rather than being held off only
	# at the touch (the engine's own default is none at all). Not much further: at 0.4 a crowd at the
	# cabin's corner turned off a stride and a half early, each by the others' turning, and swung
	# their heads there.
	"obstacle_horizon": 0.2,
}

# ==============================================================================
# 4. Wave Spawning & Scaling Rules (WAVES)
# ==============================================================================
## A raid grows three ways at once -- one more raider a wave (count_per_wave), a little more
## a minute (RAIDS.intensity_per_minute) and tougher after each big wave (enhance_after_big)
## -- and the three MULTIPLY, so each has to be small. At v0.5's figures (+15% a minute, x1.3
## hit points a big wave) the raid at minute 25 was about a hundred raptors at 2.2 times
## their hit points, and the beacon's final wave three times that: no base holds that.
## Measured with `tools/playtest.gd siege` (v0.6): six crossbow towers facing the nest
## held thirty raptors at x1.3 and fell to fifty at x1.5. Since the towers became traps (v0.6
## round two), six set crossbows set into a ring facing the nest hold thirty at x1.3 with half
## of them standing, and fifty at x1.5 by a hair -- every trap gone, the cabin at 13 of 100;
## ten improved ones round it hold the beacon's final wave (MAPS.beacon.final_raids). These
## figures put the raid at minute 25 near thirty at under x1.5, and a big wave half as
## big again rather than twice as big -- a base that kept building holds it, one that
## stopped at the fourth trap does not.
const WAVES: Dictionary = {
	"base_count": 2,
	"count_per_wave": 1,
	"big_every": 3,
	"big_multiplier": 1.5,
	"enhance_after_big": {
		"hp": 1.1,
		"damage": 1.1,
		"speed": 1.0
	},
	"spawn_interval": 0.8,
}

# ==============================================================================
# 5. Nest Configuration (NEST)
# ==============================================================================
## The nest has no hit points (v0.6, decided): it cannot be destroyed, and a run is won by
## the beacon (MAPS.beacon), not by knocking it down. Walking a turret up to its face was
## how v0.0-v0.5 were won; what the nest might become later -- a mid-game objective that
## quiets the raids from its side -- is GAME-DESIGN 10, open question 6.
const NEST: Dictionary = {
	# Bigger than anything the player builds, because it is the thing the whole map is
	# pointed at. Both its collider and its body come from this one figure.
	"size": Vector3(2.0, 1.2, 2.0),
	# Each species' nest is its own (GAME-DESIGN 9.3; v0.6 round three: "巢穴也不能长一个样，应该不同的
	# 恐龙巢穴也不一样"), and some are not the mound's size: Coelophysis nested in crowds, a field of
	# shallow scrapes across the ground (VISUALS "nest/coelophysis").
	"sizes": {"coelophysis": Vector3(3.6, 0.3, 3.6)},
}

# ==============================================================================
# 6. Placeholder Visual Colors (COLORS)
# ==============================================================================
const COLORS: Dictionary = {
	# A wet, mossy valley floor and dark volcanic rock. The floor was a pale olive, and
	# under a warm sun an olive floor goes BROWN -- the first attempt at a Mesozoic
	# palette turned the whole valley into a dusty savanna at sunset. Lushness has to be
	# in the ground itself; light can only warm what is there.
	"ground": Color(0.15, 0.25, 0.11),
	"hill": Color(0.27, 0.26, 0.22),
	"grid_hover": Color(1.0, 1.0, 0.2, 0.4),
	"core": Color(0.9, 0.3, 0.1),
	"trap": Color(0.62, 0.44, 0.24),
	"wall": Color(0.5, 0.35, 0.2),
	"stone_wall": Color(0.55, 0.53, 0.49),
	"fire": Color(0.45, 0.4, 0.36),
	"raptor": Color(0.47, 0.38, 0.26),          # sand and dust: a predator that hunts here
	"big_theropod": Color(0.35, 0.29, 0.24),    # darker and heavier than the pack
	"raptor_alpha": Color(0.40, 0.30, 0.20),
	"coelophysis": Color(0.55, 0.40, 0.18),     # sand-ochre
	"coelophysis_alpha": Color(0.45, 0.31, 0.14),
	"postosuchus": Color(0.30, 0.23, 0.15),     # umber, armoured
	"phytosaur": Color(0.22, 0.24, 0.15),       # dark olive, a river's colour
	"hesperosuchus": Color(0.36, 0.32, 0.22),   # dun-grey, a dry bank's
	"pterosaur": Color(0.55, 0.50, 0.44),
	"nest": Color(0.4, 0.1, 0.5),
	"caveman": Color(0.1, 0.8, 0.8)
}

# ==============================================================================
# 7. Initial Gameplay State Defaults
# ==============================================================================
const INITIAL_DINO_MULTIPLIERS: Dictionary = {
	"hp": 1.0,
	"damage": 1.0,
	"speed": 1.0
}

# ==============================================================================
# 8. Maps (v0.6) -- a map is data
# ==============================================================================
## Every map, by id. A map is the CONTENT of a run -- where everything stands, what the
## player starts with, who raids and when the big moments come -- and the rules it runs
## under are the rest of this file (GAME-DESIGN 12.1: a rule's numbers live in Config, a
## map's content in its map, and neither in the logic). Nothing reads a map from here
## directly: the run's map is GameState.map_data(), so choosing a different one later is
## a matter of which id a run starts with.
##
## There is one map: the valley v0.1-v0.5 were played on. It was Config.MAP, and its keys
## already said "default_" -- it was always the first map's data. Later maps move to data
## files (res://data/maps/, GAME-DESIGN 12.2) in the same shape, and ids, once used, never
## change (12.6).
const DEFAULT_MAP_ID: String = "valley"

## The map `map_id` names -- or, with no id, the one a run starts on. A map `like` another is that
## one with its own keys over it (the large valley is the valley, bigger). Made once a map.
static func map_data(map_id: String = "") -> Dictionary:
	var id: String = map_id if map_id != "" else DEFAULT_MAP_ID
	if _maps.has(id):
		return _maps[id]
	var own: Dictionary = MAPS.get(id, {})
	var map: Dictionary = own
	if own.has("like"):
		map = map_data(String(own["like"])).duplicate()
		map.merge(own, true)
		map.erase("like")
		map.make_read_only()
	_maps[id] = map
	return map

static var _maps: Dictionary = {}

## The land of map `map_id`: TERRAIN, with the map's own "terrain" laid over it key by key -- a
## bigger valley has a bigger field, and its river further out. Made once a map, and read-only as
## TERRAIN is: the ground and the river are built once for land that cannot change under them
## (TerrainBuilder), and a map with nothing of its own is TERRAIN itself.
static func terrain_of(map_id: String = "") -> Dictionary:
	var id: String = map_id if map_id != "" else DEFAULT_MAP_ID
	if _terrains.has(id):
		return _terrains[id]
	var own: Dictionary = map_data(id).get("terrain", {})
	var land: Dictionary = TERRAIN
	if not own.is_empty():
		land = TERRAIN.duplicate()
		for key in own:
			# A table of its own (the river) says only what differs: its course, and the rest as TERRAIN's.
			if own[key] is Dictionary and TERRAIN.get(key) is Dictionary:
				var part: Dictionary = (TERRAIN[key] as Dictionary).duplicate()
				part.merge(own[key], true)
				part.make_read_only()
				land[key] = part
			else:
				land[key] = own[key]
		land.make_read_only()
	_terrains[id] = land
	return land

## The land of the map being played (GameState.map_id).
static func terrain() -> Dictionary:
	var loop := Engine.get_main_loop()
	var gs: Node = (loop as SceneTree).root.get_node_or_null("GameState") if loop is SceneTree else null
	return terrain_of(String(gs.map_id) if (gs != null and "map_id" in gs) else "")

static var _terrains: Dictionary = {}

const MAPS: Dictionary = {
	"valley": {
	"name": "MAP_VALLEY_NAME",
	"default_core_cell": Vector2i(0, 0),
	"default_nest_cell": Vector2i(0, -9),
	"path_column_x": 0,
	# What the player starts with, lying by the cabin rather than in the warehouse (DROPS
	# says how it is laid out): wood, and nothing else. Stone only ever comes out of the
	# ground, the ground only gives it to the pick, and the pick is bone -- so everything
	# made of stone, the axe included, comes after the first raid: "the first raid is
	# supply" (GAME-DESIGN 5.2). A couple of stones used to lie here too, exactly an axe's
	# price, and a stone the player could hold but not cut was the one thing about the
	# opening nobody could explain. How much: a ring of palisade round the cabin a cell out
	# (24 sections round the seven-by-three module, v0.6 round three; it was 16 round the
	# three-metre cabin) and a trip bow's worth over -- the same margin as before.
	"opening_stock": {"wood": 28},
	# The beat table (GAME-DESIGN 9.2): when this map's big moments come, in seconds from
	# landing.
	"beats": {
		# Time to fetch the stock, put a fence up and make an axe before anything arrives.
		"first_raid": 90.0,
	},
	# Who raids here, and how often each, by weight: the Late Triassic's (GAME-DESIGN 7.2).
	"raiders": {"coelophysis": 1.0},
	# And from a day on (GameState.day_number), who raids instead: the latest begun (WaveManager._raiders_now;
	# v0.6 round six, the player: "物种到day 4也就一种，太单调" -- chosen "快跑的黄昏鳄"). From the third day, a
	# runner for every three of the pack.
	"raiders_by_day": [{"from_day": 3, "raiders": {"coelophysis": 3.0, "hesperosuchus": 1.0}}],
	# The ways a raid comes in by, as the days go (v0.6 round six: "恐龙每次都是从一个地方来进攻" -- chosen "更多来
	# 袭方向"): the nest's, and from `from_day` a party in by each of `ways` as well -- a point of the compass,
	# the way into the valley (`entries`) that lies most that way from the cabin. A raid is shared out among the
	# nest and them, one after another (WaveManager._next_origin); the warning says every side it comes from.
	"ways_by_day": [{"from_day": 3, "ways": ["E"]}, {"from_day": 5, "ways": ["E", "S"]}],
	# Who guards the nest (NEST_GUARDS): the same animal.
	"guards": "coelophysis",
	# At the head of every big wave (WAVES.big_every): the lesser boss (GAME-DESIGN 7.5) -- the
	# middle of the run's high point.
	"minor_boss": "coelophysis_alpha",
	# The map's boss: seen once, last of all in the beacon's final wave (7.5, v0.6 round three:
	# the middle of the run must not give away what comes at the end).
	"boss": "postosuchus",
	# Where else raids come from, besides the nest: cells at the edge of the field, west,
	# east, south and south-east. The beacon's final wave uses them -- "from every direction
	# at once" (GAME-DESIGN 8.3) -- so the base the player built facing the nest has to have
	# a back as well; and what a repaired stage stirs up comes in by them, in turn
	# (WaveManager._next_origin; the player: "信标恐龙就应该来自边界"). The south-east one is the
	# way past the third wreck (WRECKS). Every one is walkable and reaches the cabin
	# (test_v06_beacon).
	"entries": [Vector2i(-10, 0), Vector2i(9, 0), Vector2i(0, 9), Vector2i(9, 9)],
	# The valley's edge behind the nest, where a raid's numbers past its party from the nest come in
	# (RAIDS.nest_most), unseen in the mist. Every one is walkable and reaches the cabin
	# (test_v06_from_the_edge).
	"reinforce_from": [Vector2i(-3, -10), Vector2i(3, -10)],
	# Who comes up out of the river at night (NightProwl, GAME-DESIGN 9.3), by weight, and where: the
	# field's west edge, the river side -- the river runs past it a few metres out (TERRAIN.river).
	# Every one is walkable and reaches the cabin (test_v06_the_night).
	"prowlers": {"phytosaur": 1.0},
	"prowl_from": [Vector2i(-10, -5), Vector2i(-10, 2), Vector2i(-10, 7)],
	# The beacon (GAME-DESIGN 8.3): the run's main line, and its only way to be won.
	"beacon": {
		# Repaired at the cabin a stage at a time, in order, each stage from a higher tier
		# of this map's materials: wood, then stone, then stone and bone (8.3: station 1).
		# Single figures (4.6), each "just within reach" (9.2) of the stretch of the run
		# it belongs to: the first beside the opening's stakes and axe -- 8 of the 28
		# wood leaves room for part of a fence, not a full ring -- the second once the pick
		# has come, the third on the bone that only fighting brings in. `time` is seconds
		# at the bench, which, like every job there, are seconds nobody holds the line.
		"stages": [
			# And each its part, out of one of the ship's wrecks (WRECKS; GAME-DESIGN 9.3, "信标变成
			# 冒险"): the antenna by the river, the battery behind the nest, the control board where
			# the valley's south-east way comes in.
			{"inputs": {"wood": 8, "antenna": 1}, "time": 10.0},
			{"inputs": {"stone": 8, "battery": 1}, "time": 15.0},
			{"inputs": {"stone": 6, "bone": 6, "board": 1}, "time": 20.0},
		],
		# Repaired, it waits until the player launches it -- there is no hurry but the
		# raids, which keep growing (RAIDS.intensity_per_minute) -- and then charges for
		# this long. Full charge is the jump. Three minutes: long enough to be the fight
		# of the run, short enough that the stream below is the whole of it.
		#
		# v0.6 round three: "发送之后应该等等恐龙出现，人可以走出去继续建造，但要有明显的". The valley does not
		# come at once: for `launch_grace` seconds after the launch the signal is out and nothing has
		# answered it yet -- a countdown on the screen, no raids -- and he can go out and build. The
		# charge runs from the launch, so it is the grace longer than the fight it holds.
		"launch_grace": 40.0,
		"charge_seconds": 210.0,
		# The final wave: this many ordinary raids' worth, sized as a raid would be at the
		# moment of launch -- so the longer the launch is put off, the harder the end --
		# streamed out of the nest and every entry in turn with no gaps, over the first
		# `stream_share` of the charge. The map's boss comes last of all, and that share
		# is what leaves it time to reach the cabin before the jump: the finale is a
		# fight, not a boss stepping out as the capsule leaves.
		#
		# Two and a half since the towers became traps (v0.6 round two): ten improved set
		# crossbows set into a ring hold seventy-five raptors at x1.5 streamed from every side,
		# and fall to ninety -- where ten towers held ninety (tools/playtest.gd siege, WAVES).
		#
		# One and a half since v0.6 round three: three full games of this map by the playtest bot
		# (tools/playtest.gd play:) -- a ring of fence and four set crossbows, as a first run builds --
		# lost the final wave at 2.5 both hiding in the cabin and fighting; at 1.25 it jumped home
		# with the cabin at 1 of 100. The first map is the first; the later ones can ask more.
		"final_raids": 1.5,
		"stream_share": 0.7,
		# Each stage repaired is heard (v0.6 round three: "每次信标造成都会有一小波"): its hum carries down
		# the valley, and a small raid comes of it -- this many, the first stage's first -- with its
		# warning, `stage_wave_delay` seconds after the stage stands. On top of the raids the clock
		# sends, not in place of one: standing in for the next it was smaller than the raid it
		# replaced, and repairing the beacon eased the pressure it was meant to add (BUG-001).
		"stage_waves": [2, 3, 4],
		"stage_wave_delay": 22.0,
	},
	## Hills: ground nobody crosses and nothing is built on.
	##
	## They are a gameplay object rather than scenery. A hill narrows the approach,
	## and a narrowed approach is what finally gives stake and turret placement an
	## answer -- without them the map is an open field where every spot is as good
	## as every other. The pair at z = -5 leaves a three-tile gate on the path
	## column, which is the fight the level is built around.
	##
	## Two rules for anything added here: never seal the corridor completely (the
	## raid has to be able to arrive, and the Hero has to be able to walk out), and
	## never sit on a resource node.
	"hill_height": 2.2,      # 丘陵高度（米）——比人高，看得出走不过去
	# 火山岩：每个丘陵格上立一组嶙峋的岩柱（tools/generate_props.py），脚下是一层低矮的
	# 共享土丘，让相邻格连成一片。缺美术时退回原来的满高土丘。
	"hill_rocks": ["res://assets/models/props/rock_formation_a.glb",
		"res://assets/models/props/rock_formation_b.glb",
		"res://assets/models/props/rock_formation_c.glb"],
	# 岩石脚下那层土丘的高度，占丘陵高度的比例。它只是地面在岩石下微微隆起——边缘与
	# 地面齐平、相邻格无缝连成一片（TerrainBuilder.hill_height_at）；"是山"的是岩石本身。
	"hill_base_fraction": 0.12,
	"default_blocked_cells": [
		Vector2i(-3, -5), Vector2i(-2, -5),
		Vector2i(2, -5), Vector2i(3, -5),
		Vector2i(-3, -8), Vector2i(3, -3),
	],
	"default_resource_nodes": [
		{"type": "wood", "cell": Vector2i(-4, -2)},
		{"type": "wood", "cell": Vector2i(4, -2)},
		{"type": "stone", "cell": Vector2i(-4, -6)},
		{"type": "stone", "cell": Vector2i(4, -6)},
		# The cabin's far side, away from the nest (v0.6 round three): stone that does not mean a
		# fight with the guards every time, and a third tree. The two by the nest stay, nearer the
		# stone's other uses and the danger.
		{"type": "stone", "cell": Vector2i(-6, 3)},
		{"type": "wood", "cell": Vector2i(6, 3)},
		# At the field's west edge, where the river runs closest (TERRAIN.river): the
		# spot the Hero draws water from. It was a pool in the middle of the field.
		{"type": "water", "cell": Vector2i(-11, -4)},
		# The ship's wrecks (WRECKS), one part in each: by the river, where the phytosaurs come up at
		# night (MAPS.prowl_from); behind the nest, in its guards' reach while they are awake; and on
		# the way in from the south-east (MAPS.entries).
		{"type": "antenna", "cell": Vector2i(-9, 4)},
		{"type": "battery", "cell": Vector2i(0, -11)},
		{"type": "board", "cell": Vector2i(6, 7)},
	],
	},

	# The same valley, bigger (v0.6 round four, the player: "地图放大做成可自定义……测试的时候可以用小地
	# 图，我玩的时候用大地图"; GAME-DESIGN 9.3: three to five times the ground, and places rather than
	# paths). Four times the ground, the nest twice as far; between them a ridge with ways through it,
	# a stone forest to the north-east, a stand of trees to the south-west, water at the west edge.
	# What it does not say is the valley's: the same raid, beacon, stock and beats. The player's map;
	# the small one is the tests' and the debug-agent's (MAP_SIZES, Main._choose_the_map).
	"valley_large": {
		"like": "valley",
		"terrain": {
			"field_half": 44.0,
			# Its river past the bigger field's west edge, as the valley's runs past its own: off the
			# plateau, down the wall, along the floor two or three metres past the flat, into the canyon.
			"river": {"course": [
				{"at": Vector2(-130.0, -96.0), "half_width": 1.1, "bank": 1.2},
				{"at": Vector2(-108.0, -90.0), "half_width": 1.1, "bank": 1.2},
				{"at": Vector2(-88.0, -82.0), "half_width": 1.1, "bank": 1.2},
				{"at": Vector2(-72.0, -72.0), "half_width": 1.1, "bank": 1.3},
				{"at": Vector2(-63.0, -61.0), "half_width": 1.0, "bank": 1.4},
				{"at": Vector2(-57.0, -50.0), "half_width": 1.1, "bank": 1.3},
				{"at": Vector2(-53.0, -40.0), "half_width": 1.5, "bank": 1.1},
				{"at": Vector2(-50.0, -30.0), "half_width": 2.0, "bank": 0.9},
				{"at": Vector2(-48.5, -18.0), "half_width": 2.1, "bank": 1.0},
				{"at": Vector2(-48.0, -8.0), "half_width": 2.1, "bank": 1.1},
				{"at": Vector2(-48.5, 2.0), "half_width": 2.2, "bank": 0.9},
				{"at": Vector2(-50.0, 12.0), "half_width": 2.3, "bank": 0.8},
				{"at": Vector2(-53.0, 20.0), "half_width": 2.3, "bank": 1.0},
				{"at": Vector2(-58.0, 27.0), "half_width": 2.2, "bank": 1.6},
				{"at": Vector2(-64.0, 34.0), "half_width": 2.1, "bank": 2.4},
				{"at": Vector2(-68.0, 44.0), "half_width": 2.0, "bank": 2.8},
				{"at": Vector2(-71.0, 58.0), "half_width": 2.0, "bank": 2.6},
				{"at": Vector2(-73.0, 76.0), "half_width": 2.0, "bank": 2.2},
				{"at": Vector2(-75.0, 96.0), "half_width": 2.0, "bank": 1.8},
				{"at": Vector2(-76.0, 114.0), "half_width": 2.0, "bank": 1.8},
			]},
		},
		"default_nest_cell": Vector2i(0, -18),
		"entries": [Vector2i(-21, 0), Vector2i(20, 0), Vector2i(0, 20), Vector2i(19, 19)],
		"reinforce_from": [Vector2i(-6, -21), Vector2i(0, -21), Vector2i(6, -21)],
		"prowl_from": [Vector2i(-21, -6), Vector2i(-21, 3), Vector2i(-21, 10)],
		"default_blocked_cells": [
			# The valley's outcrop north of the cabin.
			Vector2i(-3, -5), Vector2i(-2, -5), Vector2i(2, -5), Vector2i(3, -5),
			Vector2i(-3, -8), Vector2i(3, -3),
			# A ridge between the cabin and the nest, with ways through it: a narrow one to the west,
			# a wide one in the middle, the long way round to the east.
			Vector2i(-9, -12), Vector2i(-8, -12), Vector2i(-7, -12),
			Vector2i(-4, -13), Vector2i(-3, -13),
			Vector2i(5, -12), Vector2i(6, -12), Vector2i(7, -12), Vector2i(8, -13),
			# The stone forest: a ring of pillars with the stone in among them.
			Vector2i(12, -10), Vector2i(13, -9), Vector2i(16, -10), Vector2i(17, -12),
			Vector2i(16, -14), Vector2i(13, -15), Vector2i(11, -13),
			# Rocks to the west and south-east.
			Vector2i(-15, -6), Vector2i(-16, -5), Vector2i(10, 12), Vector2i(11, 13),
		],
		"default_resource_nodes": [
			# The opening's, where the valley has them.
			{"type": "wood", "cell": Vector2i(-4, -2)},
			{"type": "wood", "cell": Vector2i(4, -2)},
			{"type": "wood", "cell": Vector2i(6, 3)},
			{"type": "stone", "cell": Vector2i(-6, 3)},
			# By the nest: the danger's stone.
			{"type": "stone", "cell": Vector2i(-4, -16)},
			{"type": "stone", "cell": Vector2i(4, -16)},
			# The stone forest.
			{"type": "stone", "cell": Vector2i(14, -12)},
			{"type": "stone", "cell": Vector2i(14, -11)},
			{"type": "stone", "cell": Vector2i(15, -13)},
			# The stand of trees to the south-west.
			{"type": "wood", "cell": Vector2i(-12, 6)},
			{"type": "wood", "cell": Vector2i(-14, 8)},
			{"type": "wood", "cell": Vector2i(-11, 9)},
			{"type": "wood", "cell": Vector2i(-15, 5)},
			{"type": "wood", "cell": Vector2i(-13, 11)},
			# Trees east and south, and stone to the south.
			{"type": "wood", "cell": Vector2i(16, 3)},
			{"type": "wood", "cell": Vector2i(18, 7)},
			{"type": "wood", "cell": Vector2i(3, 14)},
			{"type": "wood", "cell": Vector2i(-2, 17)},
			{"type": "stone", "cell": Vector2i(-6, 15)},
			# Water at the field's west edge, where the river runs closest.
			{"type": "water", "cell": Vector2i(-22, -4)},
			# The ship's wrecks, as the valley has them, twice as far.
			{"type": "antenna", "cell": Vector2i(-19, 6)},
			{"type": "battery", "cell": Vector2i(3, -20)},
			{"type": "board", "cell": Vector2i(15, 16)},
		],
	},
}

## Which map each map size plays (the settings page, Main._choose_the_map): the small valley is
## the tests' and the debug-agent's; the large one is the player's (v0.6 round four).
const MAP_SIZES: Dictionary = {"small": "valley", "large": "valley_large"}
## The size a player's first run is played at, before they have chosen one.
const DEFAULT_MAP_SIZE: String = "large"
## How long the retired phase machine's produce phase showed before moving on.
const PRODUCE_DELAY: float = 1.0

# ==============================================================================
# 9. Real-Time Deployment & Modern Hero Configuration (v0.1)
# ==============================================================================
const TIME: Dictionary = {
	"deploy_length": 90.0,        # 部署时长（秒）
	"produce_length": 3.0,        # 夜晚产出结算展示时长（秒）
	"build_range": 1.5,           # 就位施工判定半径（米）
	"allow_pause": true,
}

const HERO: Dictionary = {
	# Walking and getting nowhere this many seconds with something biting him, he turns on it whatever
	# he was sent to do (Hero._hit_back; the debug-agent's BUG-022: held at the cabin's end by a
	# phytosaur on his way home, he walked on the spot and was bitten to death). Long enough that a
	# walk the player sent him on past a raid is still walked; a second is his way being shut.
	"fight_when_held": 1.0,
	# Walking and getting nowhere this many seconds on a plain walk -- nothing to build, gather or fight
	# at its end -- he stops, rather than run on the spot for ever at whatever the route did not know
	# was in the way (the player's report, 2026-09-29: "人会一直有跑的动作但会一直卡着进不去").
	"give_up_after": 3.0,
	"hp": 10.0,                   # 生命值（归零直接 Game Over）
	"move_speed": 4.0,            # 移动速度（米/秒）
	"damage": 1.0,                # 攻击力（仅部署阶段生效，前期攻击力较低）
	"attack_rate": 1.0,           # 攻击间隔（秒）
	"attack_range": 2.0,          # 攻击距离（米）
	# What killed him is taken to be the nearest animal this far from him when he falls (metres): a
	# bite is at arm's length, and the defeat screen names it (debug-agent BUG-011).
	"killer_within": 3.0,
	"provoke_duration": 5.0,      # 挑衅仇恨持续时长（秒）
	"provoke_radius": 4.0,        # 挑衅仇恨生效半径（米）
	"width": 0.8,                 # 碰撞体宽度（米）——建筑占地由它推导
	# How far past his own body he works a tree or a rock from (metres, body to body): an
	# arm and a swing. He walks up to it and stops there -- not a couple of metres off.
	"harvest_reach": 0.45,
	# 避让优先级（0–1）：比恐龙的高（DINO_AI.avoidance_priority），恐龙绕着他走，他照着命令走，
	# 不给恐龙让路。他站在恐龙的路上时，恐龙从旁边绕过去，而不是顶在他身上走不动。
	"avoidance_priority": 1.0,
	# 身高（米）——碰撞体与外形都用它。和这个世界相称：木桩到他胸口、树蕨是他三倍高、
	# 船舱是他两倍多高。1.6 米时他和霸王龙一样高、是迅猛龙的两倍。占地和通道只由
	# width 决定，与身高无关，所以改身高不改玩法。
	"height": 1.2,
}

## The interface's design tokens (UI-POLISH T1): every colour, type size, gap, corner and
## timing the HUD, the panels and the menus are drawn with. UiTheme builds the one Theme
## from these; nothing in the interface picks a colour or a size of its own.
##
## The look is the Hero's own kit. The capsule he came down in is white with orange hazard
## striping and its instruments glow cyan, so the interface reads as his gear rather than as
## a web page laid over the Jurassic: dark weathered panels, warm off-white text, hazard
## orange for what to press, cyan for the beacon and the ship's systems.
##
## Sizes are design pixels (the 1280x720 canvas; the engine scales it up on bigger screens).
## Type and spacing each come in a fixed ladder -- one step apart, never a size between --
## which is most of what makes a set of panels look like they belong together.
const THEME: Dictionary = {
	# The interface's faces (v0.6 feedback: "字体也需要改，需要有优秀游戏的质感"; all three SIL OFL,
	# their licences beside them in assets/fonts).
	# Titles, names and every button are cut in Cinzel: Roman inscriptional capitals, the
	# lettering of monuments -- carved, as the rest of this interface is made by hand. Its
	# lowercase is small capitals, so a name reads as an inscription whatever its case. Chinese
	# in the same places is Noto Serif SC (思源宋体), the serif that stands beside it, cut down to
	# the characters the game says (tools/subset_fonts.py; test_v06_the_faces checks every
	# string is covered).
	"display_font": "res://assets/fonts/Cinzel.ttf",
	"display_cjk_font": "res://assets/fonts/NotoSerifSC-Title.ttf",
	# Running text is Alegreya Sans: drawn with a pen's warmth where Inter was a screen's, with
	# lining figures that can all be set one width. It comes a file per weight; the semibold
	# step is its bold.
	"text_fonts": {"regular": "res://assets/fonts/AlegreyaSans-Regular.ttf",
		"medium": "res://assets/fonts/AlegreyaSans-Medium.ttf",
		"semibold": "res://assets/fonts/AlegreyaSans-Bold.ttf",
		"bold": "res://assets/fonts/AlegreyaSans-Bold.ttf",
		"black": "res://assets/fonts/AlegreyaSans-ExtraBold.ttf"},
	# Chinese running text -- and anything no face above has -- falls back to the player's own
	# system UI face, first in this list that is installed.
	"fallback_fonts": ["Noto Sans SC", "Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
		"Hiragino Sans GB", "Source Han Sans SC", "Noto Sans CJK SC", "WenQuanYi Micro Hei"],
	# The weight steps, for the faces that vary along an axis (Cinzel 400-900, the cut Noto
	# Serif SC 600-900) and for the system face.
	"weights": {"regular": 430, "medium": 530, "semibold": 620, "bold": 720, "black": 860},
	# Alegreya's letters are smaller for their size than Inter's were, and Cinzel's capitals
	# larger: running text a step up, titles a step down.
	"font_sizes": {"caption": 14, "small": 16, "body": 18, "label": 19, "heading": 22, "title": 30, "display": 48},
	# "hair" is the gap inside one thing -- between a speed's segments, a stage's pips.
	"spacing": {"hair": 2, "xs": 4, "s": 8, "m": 12, "l": 16, "xl": 24},
	# The corner of what is still a flat box: a focus ring, a box standing in for a material
	# whose image is not imported yet.
	"radius": {"s": 5, "xs": 2},
	"border": 1,
	# The valley's own colours (v0.6: "远古时代质感"): bone for text, umber and ash for what it
	# stands on, fire-ochre for the one thing to press, red ochre for danger, moss for health.
	# The ship's things -- the beacon, what it knows -- keep their cold blue: they are the
	# one thing here from another age.
	"colors": {
		"bg": Color(0.07, 0.058, 0.047),
		# The stone's own colour, where a flat box stands in for it.
		"panel": Color(0.2, 0.185, 0.165, 0.95),
		"panel_border": Color(0.36, 0.32, 0.27),
		"text": Color(0.9, 0.86, 0.78),
		"text_muted": Color(0.66, 0.61, 0.52),
		"text_faint": Color(0.5, 0.46, 0.39),
		# Titles and names stand in pale gilt, over their rule (v0.6 round three: the D4 / Elden Ring
		# way -- the heading is the one warm thing on a quiet panel).
		"title": Color(0.9, 0.78, 0.55),
		"accent": Color(0.86, 0.66, 0.36),
		"accent_text": Color(0.96, 0.89, 0.74),
		"tech": Color(0.42, 0.78, 0.88),
		"danger": Color(0.8, 0.29, 0.21),
		# Danger as text on a dark panel -- a count he is short of, a demolish -- a step
		# lighter than the fill, or the red sinks into the panel.
		"danger_text": Color(0.95, 0.53, 0.42),
		"warning": Color(0.91, 0.7, 0.29),
		"success": Color(0.52, 0.74, 0.35),
		# A meal's boost (v0.6 round two: "boost 要比较清楚地显示在移动速度、血量上面"): gold, on
		# his bars over what he has of his own, at his feet, and in the words that rise off him.
		"boost": Color(0.97, 0.77, 0.3),
		# The day's dial (HUD): its ring by day, at dusk -- the red the sky goes -- and in the night.
		"day_day": Color(0.97, 0.80, 0.36),
		"day_dusk": Color(0.93, 0.38, 0.20),
		"day_night": Color(0.42, 0.55, 0.92),
		# His armour's hit points on his bar (v0.6 round three): tanned leather, told from his own
		# health and a meal's gold by its colour and where it sits between them.
		"armor": Color(0.66, 0.44, 0.24),
		# Ink: text on a card's hide -- a card's name and price, a tooltip. Since v0.6 round three
		# the hide is dark vellum, so the ink is pale; "ink_short" is a count he is short of, as
		# danger_text is on stone.
		"ink": Color(0.9, 0.85, 0.76),
		"ink_muted": Color(0.68, 0.62, 0.52),
		"ink_faint": Color(0.53, 0.48, 0.4),
		"ink_short": Color(0.95, 0.48, 0.38),
		"ink_accent": Color(0.9, 0.7, 0.42),
		"shadow": Color(0.0, 0.0, 0.0, 0.45),
		"scrim": Color(0.035, 0.028, 0.02, 0.62),
	},
	# How a material is tinted for a state (UiTheme.surface). The materials are drawn in their
	# own colours; a tint lights them under the cursor, presses them, dims what cannot be
	# pressed -- a channel above 1 lightens.
	"tints": {
		"plain": Color(1.0, 1.0, 1.0),
		"hover": Color(1.16, 1.12, 1.08),        # under the cursor: the rim and the leather catch more light
		"down": Color(0.84, 0.82, 0.8),          # pressed in
		"off": Color(0.78, 0.76, 0.74, 0.6),     # cannot be pressed: dimmed, the world showing through
		"rust": Color(1.3, 0.78, 0.72),          # a thing that cannot be undone, under the cursor
		"rust_down": Color(1.05, 0.62, 0.58),
		"lost": Color(1.15, 0.72, 0.66),         # the verdict on a fall: the leather gone red
		"hide": Color(1.0, 1.0, 1.0),            # a card, a tooltip: dark vellum, for pale ink
		"hide_hover": Color(1.06, 1.04, 1.0),
		"hide_down": Color(0.9, 0.85, 0.78),
		"hide_off": Color(0.8, 0.76, 0.72),      # one that cannot be taken yet: duller, still read
		# A command in the corner he cannot give now (HeroCommands: no meal, daylight, no wood): plainly
		# dull, its icon greyed down -- at "hide_off" and the card's icon dimming, a greyed Eat was as
		# bright as a Torch to be pressed (the debug-agent's TASK-024).
		"tile_off": Color(0.58, 0.55, 0.52, 0.9),
		"icon_off": Color(0.42, 0.4, 0.38, 0.7),
		# A command just become his, lit up as it comes into the corner, fading over "come_seconds"
		# (UiKit.come_in; TASK-024: "新按钮出现时注意得到吗：不太注意得到").
		"come": Color(1.55, 1.35, 0.9),
		"groove": Color(0.15, 0.13, 0.115),      # bare chrome, pressed
		"groove_faint": Color(0.15, 0.13, 0.115, 0.55),   # and under the cursor
	},
	# Capitals are set wider than running text -- an inscription is spaced -- and titles stand
	# proud of the leather on a shadow. Extra pixels between letters, by kind.
	"letter_spacing": {"button": 1, "heading": 1, "title": 2, "display": 4},
	"title_shadow": Vector2i(0, 2),
	# A health bar says how bad it is by length, colour and -- below the low mark -- by
	# pulsing, so a player who cannot tell amber from green still sees the cabin is dying
	# (UI-POLISH rule 3: never colour alone).
	"hp_warn_ratio": 0.6,
	"hp_low_ratio": 0.3,
	# Panels and toasts come and go this fast: a transition, never a wait (UI-POLISH T10).
	"fade_seconds": 0.12,
	# A count that changes flashes for this long, so income is seen, not searched for.
	"flash_seconds": 0.45,
	# Behind a full-screen menu the world is frosted (assets/shaders/ui_frost.gdshader): how
	# soft (the mip level read), and how dark the edges go. The tint is "scrim".
	"frost_blur": 3.0,
	"frost_vignette": 0.35,

	# The sizes of the interface's pieces, each on a ladder like the type's, so one kind of
	# thing is one size wherever it appears.
	# Icons: in a price chip; beside a count; beside a heading or a toast; on the raid
	# banner; a portrait or a bench; the verdict.
	"icon_sizes": {"xs": 14, "s": 18, "m": 22, "l": 30, "xl": 44, "xxl": 56},
	# Control heights: the top bar's (slim -- it sits over the world); a command, big enough
	# to hit without aiming; a card -- a name line with a price row under it, both inside the
	# hide's stitches; a tile -- a command on a unit's card, its icon over its word (UiKit.command_button).
	"control_heights": {"bar": 30, "command": 44, "card": 68, "tile": 88},
	# Widths: a speed segment; the figure at a bar's end ("10 / 10" at its widest); a
	# stage's pip; the results card's buttons, which sit side by side and match.
	"widths": {"segment": 38, "figure": 64, "pip": 14, "button": 180},
	# How thick a bar is drawn, and a pip -- a short dash, so the stages read as one row. A
	# bar is a groove with pigment in it: "fill_inset" is the groove's wall showing above and
	# below the pigment.
	"thickness": {"bar": 12, "pip": 6},
	"fill_inset": 2,
	# Motion. A card pops in over this long, from this much of its size -- a nudge, not a
	# zoom; the command card fades in from this much when it changes to another unit.
	"pop_seconds": 0.18,
	# A card showing something that changes by itself -- a bar filling, a countdown -- reads
	# it again this often: smooth enough to watch, and not every frame.
	"refresh_seconds": 0.2,
	# A command on a unit's card (UiKit.command_button) is a tile ("control_heights") tall and
	# this many times as wide: room for its icon big over its word, and four to a row.
	"command_aspect": 1.05,
	# An empty one keeps the rules' gilt lozenge at its middle, this faint (over the slot's own
	# dimming): there to be seen, not read as something he has.
	"empty_mark_alpha": 0.6,
	# A bench's jobs stand one to a row up to this many, two to a row past it (OptionPanel): six
	# of them one to a row were most of the screen's height.
	"one_column_most": 3,
	"pop_scale": 0.96,
	# A command come into the corner grows in from this much of its size, and its light fades
	# over this long (UiKit.come_in): an arrival, where a card's pop is a nudge.
	"come_scale": 0.7,
	"come_seconds": 1.4,
	"settle_alpha": 0.35,
	# The cabin's bar, nearly gone, pulses this fast (radians a second), down to this much.
	"pulse_speed": 7.0,
	"pulse_floor": 0.55,
	# The PAUSED word stands a little back from the frame round it.
	"paused_alpha": 0.85,
	# How long a toast stays: a line to glance at; one to read (a tool made, the boss, why a
	# rock will not break); one worth reading twice (what a material is for, a raid's
	# account, the launch).
	"toast_seconds": {"glance": 2.5, "read": 4.0, "long": 6.0},

	# The interface's materials (v0.6 feedback: "远古时代质感的菜单界面，状态栏", then "还是没到优
	# 秀游戏的质感"): framed, as the good ones are -- dark tanned leather in a rim of bone, a
	# knuckle of it pegged at each corner, for every panel; the ship's own things slate in steel
	# with a line of cyan light; a button leather in a thinner rim, the one thing to press
	# painted ochre; a socket sunk in the leather for a portrait and the chosen tab; a stroke of
	# ink for a toast, of red ochre for a raid; a trough capped with bone with pigment in it for
	# a bar; a rule with a tooth of bone under a title; a stitched hide for a card and a tooltip.
	# tools/build_ui_textures.gd draws them to these numbers and UiTheme cuts each into nine and
	# tiles it. Sizes are design pixels: "margin" is where it is cut (the rim, the knuckles, a
	# brush's ragged ends live there and are never stretched), "pad" how far its shadow reaches
	# past what it is drawn behind. Drawn at "surface_scale" times their size: crisp at 1440p,
	# where the stretch is 2x.
	"surface_scale": 2,
	"surfaces": {
		"frame": {"image": "res://assets/ui/frame.png", "size": Vector2i(256, 256), "margin": Vector2i(28, 28), "pad": 8},
		"frame_tech": {"image": "res://assets/ui/frame_tech.png", "size": Vector2i(256, 256), "margin": Vector2i(28, 28), "pad": 8},
		# The top row's slim frames, over the world.
		"plate": {"image": "res://assets/ui/plate.png", "size": Vector2i(96, 48), "margin": Vector2i(16, 16), "pad": 6},
		# A button is stretched top to bottom, not tiled ("tile_v"): the stud at each end stays one.
		"button": {"image": "res://assets/ui/button.png", "size": Vector2i(160, 44), "margin": Vector2i(14, 14), "pad": 4,
			"tile_v": false},
		"button_accent": {"image": "res://assets/ui/button_accent.png", "size": Vector2i(160, 44), "margin": Vector2i(14, 14), "pad": 4,
			"tile_v": false},
		"socket": {"image": "res://assets/ui/socket.png", "size": Vector2i(56, 56), "margin": Vector2i(16, 16), "pad": 2},
		"socket_tech": {"image": "res://assets/ui/socket_tech.png", "size": Vector2i(56, 56), "margin": Vector2i(16, 16), "pad": 2},
		# "stitch": how far in from its edge a hide is sewn -- what it holds sits inside that.
		"hide": {"image": "res://assets/ui/hide.png", "size": Vector2i(192, 192), "margin": Vector2i(24, 24), "pad": 6,
			"stitch": 7},
		# A brush stroke's grain runs its length and is stretched, not repeated, top to bottom
		# ("tile_v"), to the height of the lines on it.
		"brush": {"image": "res://assets/ui/brush.png", "size": Vector2i(256, 40), "margin": Vector2i(40, 0), "pad": 0,
			"tile_v": false},
		"brush_blood": {"image": "res://assets/ui/brush_blood.png", "size": Vector2i(256, 40), "margin": Vector2i(40, 0), "pad": 0,
			"tile_v": false},
		# "cap": how wide each bone cap on a trough's ends is -- the pigment runs between them.
		"trough": {"image": "res://assets/ui/trough.png", "size": Vector2i(48, 12), "margin": Vector2i(6, 0), "pad": 0,
			"tile_v": false, "cap": 4},
		"paint": {"image": "res://assets/ui/paint.png", "size": Vector2i(48, 12), "margin": Vector2i(4, 0), "pad": 0,
			"tile_v": false},
		"hatch": {"image": "res://assets/ui/hatch.png", "size": Vector2i(48, 12), "margin": Vector2i(4, 0), "pad": 0,
			"tile_v": false},
		"groove": {"image": "res://assets/ui/groove.png", "size": Vector2i(48, 48), "margin": Vector2i(10, 10), "pad": 0},
		"rule": {"image": "res://assets/ui/rule.png", "size": Vector2i(160, 6), "margin": Vector2i(56, 0), "pad": 0,
			"tile_v": false},
		# Drawn whole, at a rule's middle -- not cut into nine.
		"ornament": {"image": "res://assets/ui/ornament.png", "size": Vector2i(24, 12), "margin": Vector2i(0, 0), "pad": 0},
		# The status bar (v0.6: "状态栏的那个版面还是显得像网页游戏"): one strip of leather along
		# the top edge of the screen, its rim along its bottom and its shadow on the world
		# ("expand": its shadow reaches out below it only, the rest runs off the screen); round
		# buttons for the speeds, pause and menu, the speed it runs at lit; a round socket for
		# each material's icon.
		"strip": {"image": "res://assets/ui/strip.png", "size": Vector2i(256, 48), "margin": Vector2i(16, 16), "pad": 8,
			"tile_v": false, "expand": Vector4i(0, 0, 0, 8)},
		"round_button": {"image": "res://assets/ui/round_button.png", "size": Vector2i(34, 34), "margin": Vector2i(16, 16), "pad": 2},
		"round_button_lit": {"image": "res://assets/ui/round_button_lit.png", "size": Vector2i(34, 34), "margin": Vector2i(16, 16), "pad": 2},
		"socket_round": {"image": "res://assets/ui/socket_round.png", "size": Vector2i(32, 32), "margin": Vector2i(15, 15), "pad": 1},
		# A medallion -- the cabin's, hung from the strip, and the Hero's -- drawn whole: its rim,
		# the channel its ring of health lies in ("ring": the channel's inner and outer radius),
		# the socket its portrait stands in ("socket": its radius), in design pixels at "size".
		# "ring_fill" is the pigment in the channel, tinted the colour of what is left.
		"medallion": {"image": "res://assets/ui/medallion.png", "size": Vector2i(104, 104), "margin": Vector2i(0, 0), "pad": 6,
			"rim": 4.5, "ring": Vector2(33.0, 40.0), "socket": 31.0},
		"ring_fill": {"image": "res://assets/ui/ring_fill.png", "size": Vector2i(104, 104), "margin": Vector2i(0, 0), "pad": 6,
			"ring": Vector2(33.0, 40.0)},
	},
}

## Portraits (tools/render_portraits.gd): each thing the command card and a bench can show,
## rendered from its own model under a studio light -- what a good RTS puts in its unit panel
## (v0.6: "还是没到优秀游戏的质感"), where a flat icon was. One per Config.VISUALS key of these
## kinds, at <dir><the key, "/" as "_">.png; "size" is how big one is shown (design pixels),
## rendered at "scale" times it, for 1440p. A thing with no portrait shows its icon.
const PORTRAITS: Dictionary = {
	"dir": "res://assets/portraits/",
	"size": 64,
	"scale": 2,
	# The animals too, by their heads (tools/render_portraits.gd): shown where one is named -- a boss on the
	# field, what a wreck's din brought, what killed him.
	"kinds": ["hero", "building", "node", "station", "dino"],
}

## Each material's icon, rendered by tools/render_portraits.gd from the pile the game drops of
## it (Config.VISUALS "drop/<id>"): the thing itself, as the portraits are, where the drawn
## icon was a flat sign. At <dir><id>.png; "size" the size it is drawn for, rendered at
## "scale" times it; "edge" the dark ring round its silhouette (design pixels) that lets it
## read small, on a pale card and a dark strip alike. UiTheme.icon takes it over the drawn one.
const RENDERED_ICONS: Dictionary = {
	"dir": "res://assets/icons/rendered/",
	"size": 32,
	"scale": 2,
	"edge": 1.4,
	"kinds": ["drop"],
}

## Where the interface's icons are (tools/build_icons.py draws them): `<name>.svg`. Resources,
## buildings and benches are named by their own ids; a resource node and a dinosaur say
## which icon is theirs in their own rows ("icon"), because a tree is not called "wood".
const ICON_DIR: String = "res://assets/icons/"

## Presentation sizing. The project renders at a 1280x720 design viewport with
## `canvas_items` stretch, so every value here is in design pixels and the engine
## scales the whole UI up on larger displays (1.5x at 1080p, 3x at 4K).
## Type sizes are not here: they are the theme's ladder (THEME.font_sizes), and a widget
## asks for a kind of text rather than a number of pixels.
const UI: Dictionary = {
	# 世界空间文字的实际高度 = font_size * pixel_size（米）。
	# TILE_SIZE 是 2.0m，所以 48 * 0.005 = 0.24m 约为格子的 1/8，一个建筑名大致一格宽。
	"world_label_font_size": 48,       # 建筑/资源点头顶的 3D 文字
	"world_label_pixel_size": 0.005,   # 3D 文字的世界尺寸（每像素米数）
	"world_label_fixed_size": false,   # true 会让文字屏幕尺寸恒定并无视 pixel_size 缩放，导致巨大
	# 右下角命令卡：宽度固定，高度随内容（UI-POLISH T10：原来固定 300 高，下半截是空的）。
	# 440：两列建造卡片（兽皮，字在针脚里面）要放得下最长的名字 "Crossbow Tower"，410 时会被截断。
	"option_panel_size": Vector2(440, 0),
	"option_panel_margin": 16.0,       # 命令卡距屏幕边缘的留白
	# The speeds the top bar offers, one segment each (UI-POLISH T9).
	"game_speeds": [1.0, 2.0, 3.0],
	"resource_count_width": 30,        # a count's box: four figures without the chip jumping
	"objective_width": 290,            # the beacon card, top right
	# The status bar: the strip along the top edge; the cabin's medallion hung from its middle,
	# its top this far down; the Hero's at the bottom left, drawn this much smaller; a toast
	# starts under the cabin's medallion and the figures under it.
	"strip_height": 48,                # a round button (34) with room above it and above the rim
	"emblem_top": 2,
	# The day's dial (HUD, GAME-DESIGN 9.3): this size of the cabin's medallion, and this far right
	# of its middle, in pixels -- beside the cabin, clear of the controls.
	"day_dial_scale": 0.55,
	"day_dial_offset": 104.0,
	"hero_emblem_scale": 0.8,
	"toast_top": 132,                  # where the centre toasts start, under the cabin's medallion
	"toast_max_width": 560,            # a longer toast wraps inside this
	# What he says (HUD speech bubble): no wider than this before it wraps, and standing this high
	# over his feet (metres) -- clear of his head, he is 1.2 m.
	"speech_max_width": 300,
	"speech_above": 1.8,
	"paused_word_bottom": 150,         # "PAUSED" sits this far above the bottom edge
	"result_card_width": 560,
	"menu_width": 400,
	"menu_picker_width": 190,
}

## Presentation feedback (v0.3). None of this changes what happens in the game;
## it changes whether the player can tell that it happened.
const FEEDBACK: Dictionary = {
	"hit_flash_duration": 0.12,       # 受击闪白持续（秒）
	"hit_flash_strength": 0.85,       # 闪白强度 0~1
	"debris_count": 7,                # 死亡碎块数量
	"debris_size": 0.16,              # 碎块边长（米）
	"debris_speed": 3.4,              # 碎块初速（米/秒）
	"debris_lifetime": 0.7,           # 碎块存在时长（秒）
	"health_bar_width": 1.1,          # 血条宽度（米）
	"health_bar_height": 0.13,        # 血条高度（米）
	# A bar stands this far over the top of what it belongs to (Dino: its declared height), so a
	# big animal's is not buried in its back.
	"health_bar_lift": 0.2,
	# A boss is told apart in the world, not by a bar across the screen (v0.6 round three: "血槽不要
	# 画大……真实感的游戏，你可以把boss恐龙通过一些方法突出出来，比如掉血的时候血量大点"): the bar over it,
	# shown once it is hurt, is this many times as long -- and as thick by the square root, so it is
	# a longer bar and not a slab. By Config.DINOS[..].boss.
	"boss_bar_scale": {"minor": 1.6, "major": 2.4},
	# A building with nothing to report shows no name. Without this a fence of twenty
	# stakes writes "Wooden Stakes" twenty times across the middle of the screen.
	"name_label_hide_when_idle": true,
	"health_bar_hide_at_full": true,  # 满血时隐藏，避免画面嘈杂
	# 树和石头头上的"木材 150/150"：只在选中它、或者刚采过它的这几秒里显示（v0.6 第三轮：满地的字就是网页游戏）。
	"node_label_seconds": 3.0,
	# 人挨咬时顶部提示一次"人在挨打"，之后这么多秒内不再重复（真实时间）。
	"hero_hurt_alert_seconds": 10.0,
	# 捡起东西时在原地飘一个数字：掉落物消失了，只有 HUD 数字变化，
	# 不给一个就地的反馈的话玩家看不出"进账了"。
	"pickup_text_rise": 1.0,          # 飘起的高度（米）
	"pickup_text_duration": 0.7,      # 飘起并淡出的时长（秒）
	# 选中圈沿单位底座绘制，尺寸由该单位的实际占地推导，不是固定半径——
	# 木栅栏宽 1.9m，固定 0.85m 的圈会整个埋进方块里看不见。
	"selection_ring_margin": 0.18,    # 圈比底座向外扩出多少（米）
	"selection_ring_thickness": 0.09, # 圈线粗细（米）
	"selection_ring_color": Color(0.35, 1.0, 0.5, 0.9),
	# 单位（现代人、恐龙）脚下的选中圈：一圈细圆环，贴着脚——细，才不像地上多出了一样东西。
	# 建筑仍然是沿底座的方框。
	"unit_ring_margin": 0.06,
	"unit_ring_thickness": 0.03,
	# 下命令时在目标处画两圈细环，收拢、淡出（即时战略的做法）：点到了，他往这儿去。
	# 颜色按命令：走过去（绿）、去干活——砍树、采石、施工（橙）、去打（红）。
	"order_marker_radius": 0.6,       # 外圈半径（米）
	"order_marker_inner": 0.4,        # 内圈比外圈小多少（比例）
	"order_marker_lift": 0.06,        # 离地高度（米），免得和地面打架
	"order_marker_seconds": 0.45,     # 收拢并淡出的时长（秒）
	"order_marker_end_scale": 0.3,    # 收到多小时消失
	"order_marker_colors": {
		"move": Color(0.35, 1.0, 0.5, 0.95),
		"work": Color(1.0, 0.72, 0.25, 0.95),
		"attack": Color(1.0, 0.32, 0.25, 0.95),
	},
	# 悬停圈：鼠标下面是什么。和选中圈刻意不同色，否则"我选中的"和"我指着的"分不清。
	# 木尖刺只有 0.62m 宽，一排挨在一起时，没有这个圈根本看不出点的是哪一根。
	"hover_ring_color": Color(1.0, 1.0, 1.0, 0.55),
	# 悬停时能采的树和石头微微提亮（UI-POLISH T21："悬停时的一点反应"）：叠一层加亮的暖色，
	# 看得出"这是能动手的"，又不像描边、光圈那样是个游戏标记。
	"hover_lift_color": Color(0.11, 0.09, 0.05),
	"audio_volume_db": -8.0,
	"audio_enabled": true,
}

## What he says, and when (HeroVoice; v0.6 round three: "人自己也需要有些滚动的话在移动的时候idle的时候
## 说，做事情说做的事情等"). The words are strings.csv's BARK_<SITUATION>_<n>, one to "count"; this is
## how often. A line stays over his head a time by its length, between the least and the most.
const BARKS: Dictionary = {
	"seconds_per_char": 0.07,
	"min_seconds": 2.2,
	"max_seconds": 5.0,
	# No sooner than this after his last line, unless the new one is urgent: a man who talks all
	# the time is noise, and the lines that matter would be lost in it.
	"gap": 7.0,
	# Left standing this long, he talks to himself -- and then again every so often.
	"idle_after": 14.0,
	"idle_every": Vector2(28.0, 55.0),
	# At work on a node: which situation it is, by what the node gives.
	"harvest": {"wood": "chop", "stone": "quarry"},
	# A recording of a line, if one is ever made: <key in lower case>.ogg or .wav here.
	"voice_dir": "res://assets/audio/voice/",
	# Each situation: how many lines it has; how likely he says one when it happens; how long
	# before he says one about it again; and whether it cuts in whenever (urgent).
	"lines": {
		"move": {"count": 6, "chance": 0.3, "again": 12.0},
		"idle": {"count": 10, "chance": 1.0, "again": 0.0},
		"chop": {"count": 5, "chance": 0.5, "again": 45.0},
		"quarry": {"count": 4, "chance": 0.5, "again": 45.0},
		"build": {"count": 5, "chance": 0.5, "again": 30.0},
		"repair": {"count": 3, "chance": 0.6, "again": 30.0},
		"eat": {"count": 4, "chance": 0.8, "again": 20.0},
		"fight": {"count": 5, "chance": 0.5, "again": 15.0},
		"hurt": {"count": 4, "chance": 1.0, "again": 12.0, "urgent": true},
		"kill": {"count": 4, "chance": 0.4, "again": 12.0},
		"raid": {"count": 4, "chance": 1.0, "again": 30.0, "urgent": true},
		"raid_over": {"count": 4, "chance": 0.8, "again": 30.0},
		"leader": {"count": 3, "chance": 1.0, "again": 60.0, "urgent": true},
		"boss": {"count": 3, "chance": 1.0, "again": 60.0, "urgent": true},
		"tool": {"count": 3, "chance": 1.0, "again": 5.0},
		"beacon_stage": {"count": 3, "chance": 1.0, "again": 5.0},
		"launched": {"count": 2, "chance": 1.0, "again": 0.0, "urgent": true},
		"enter": {"count": 3, "chance": 0.5, "again": 30.0},
		"leave": {"count": 2, "chance": 0.4, "again": 30.0},
	},
}

# ==============================================================================
# Sound (v0.6 round three: "你就做音效吧，恐龙音效不同恐龙尽量不同，这样有区分度")
# ==============================================================================
## Every sound the game plays, by what it is. The files are made by tools/build_sounds.gd -- how
## each SOUNDS is written there, with the palaeontology it follows -- and this is how they are
## played: which files are one sound (a variant picked at random each time, the engine's
## AudioStreamRandomizer, so a pack is not one animal copied), how loud, how far the pitch wanders
## between plays, and how far it carries.
##
## Almost everything is played IN the world (Fx.play_at): a raptor off the left of the screen is
## heard on the left, and one at the far end of the valley is faint. The listener stands between
## the ground the camera looks at and the camera ("listener_lift"), so zooming out does not turn
## the world down, and turning the view turns the sound with it.
const SOUNDS: Dictionary = {
	"dir": "res://assets/audio/",
	# Players in the world at once. More than the limiter below ever lets through, with room.
	"world_players": 16,
	"listener_lift": 0.3,
	# How near a sound is heard at its own loudness, and how far it is heard at all (metres):
	# Godot's inverse-distance falloff. A sound's own "unit" and "reach" override them.
	"unit": 7.0,
	"reach": 70.0,
	# No more than this many of a class at once, and no sooner than this after the last: a pack
	# of twelve biting a gate is a clatter, not a wall of noise; a herd calls one at a time.
	"classes": {
		"call":   {"max": 2, "gap": 0.45},
		"alert":  {"max": 2, "gap": 0.5},
		"bite":   {"max": 4, "gap": 0.07},
		"hurt":   {"max": 3, "gap": 0.12},
		"death":  {"max": 3, "gap": 0.05},
		"boss":   {"max": 1, "gap": 2.0},
		"work":   {"max": 2, "gap": 0.1},
		"impact": {"max": 4, "gap": 0.08},
		"event":  {"max": 3, "gap": 0.05},
		"ui":     {"max": 3, "gap": 0.03},
	},
	# An animal speaks now and then while it lives -- a raider on the march, a guard at the nest
	# -- at a random moment in this range of seconds after the last; it calls out when it first
	# goes for something (alert), and not again for "alert_every".
	"call_every": Vector2(6.0, 15.0),
	"alert_every": 8.0,
	"hurt_every": 0.7,
	# A herd animal calls when it sets off to amble, this often: now and then, from far off.
	"herd_call_chance": 0.3,
	# His work: a stroke on a node is the sound of what it is; building and mending, a knock
	# this often.
	"harvest": {"wood": "chop", "stone": "quarry", "antenna": "salvage", "battery": "salvage", "board": "salvage"},
	"hammer_every": 0.55,
	# A building bitten sounds of what it is made of; the cabin is plate metal.
	"hit_by_building": {"stone_wall": "stone_hit", "core": "hull_hit"},
	"hit_default": "wood_hit",
	# The valley under everything, not placed: wind, insects, the river.
	"ambience": "ambience_valley",
	"ambience_db": -21.0,
	"sounds": {
		# Coelophysis: a small, quick theropod -- high chitters and trills, hisses.
		"coelophysis_call":  {"files": ["coelophysis_call_1", "coelophysis_call_2", "coelophysis_call_3"], "db": -5.0, "pitch": 1.1, "class": "call"},
		"coelophysis_alert": {"files": ["coelophysis_alert"], "db": -3.0, "pitch": 1.08, "class": "alert"},
		"coelophysis_bite":  {"files": ["coelophysis_bite_1", "coelophysis_bite_2"], "db": -4.0, "pitch": 1.1, "class": "bite"},
		"coelophysis_hurt":  {"files": ["coelophysis_hurt_1", "coelophysis_hurt_2"], "db": -4.0, "pitch": 1.08, "class": "hurt"},
		"coelophysis_death": {"files": ["coelophysis_death"], "db": -2.0, "pitch": 1.06, "class": "death"},
		# Its alpha: the same throat, bigger -- lower, rougher, a honk; heard further.
		"coelophysis_alpha_call":  {"files": ["coelophysis_alpha_call_1", "coelophysis_alpha_call_2"], "db": -3.0, "pitch": 1.05, "class": "call", "unit": 10.0},
		"coelophysis_alpha_alert": {"files": ["coelophysis_alpha_alert"], "db": 0.0, "pitch": 1.03, "class": "boss", "unit": 22.0, "reach": 140.0},
		"coelophysis_alpha_bite":  {"files": ["coelophysis_alpha_bite"], "db": -3.0, "pitch": 1.06, "class": "bite"},
		"coelophysis_alpha_hurt":  {"files": ["coelophysis_alpha_hurt"], "db": -3.0, "pitch": 1.05, "class": "hurt"},
		"coelophysis_alpha_death": {"files": ["coelophysis_alpha_death"], "db": 0.0, "pitch": 1.03, "class": "death", "unit": 12.0},
		# Postosuchus: the crocodiles' side -- a bellow felt more than heard, a hiss, a jaw that claps.
		# Its arrival is heard across the whole valley.
		"postosuchus_call":  {"files": ["postosuchus_call_1", "postosuchus_call_2"], "db": 0.0, "pitch": 1.04, "class": "call", "unit": 16.0, "reach": 120.0},
		"postosuchus_alert": {"files": ["postosuchus_hiss"], "db": -1.0, "pitch": 1.04, "class": "alert", "unit": 12.0},
		"postosuchus_roar":  {"files": ["postosuchus_roar"], "db": 3.0, "pitch": 1.0, "class": "boss", "unit": 45.0, "reach": 220.0},
		"postosuchus_bite":  {"files": ["postosuchus_bite"], "db": 0.0, "pitch": 1.05, "class": "bite", "unit": 10.0},
		"postosuchus_hurt":  {"files": ["postosuchus_hurt"], "db": -1.0, "pitch": 1.05, "class": "hurt", "unit": 10.0},
		"postosuchus_death": {"files": ["postosuchus_death"], "db": 2.0, "pitch": 1.0, "class": "death", "unit": 20.0, "reach": 160.0},
		# The phytosaur: a voice of its own (tools/build_sounds.gd) -- a long snout's low, wet growl, a hiss,
		# a long jaw clapped shut -- heard from nearer than Postosuchus (its "unit"); in the dark, how the
		# night's hunters are known before they are seen. They were Postosuchus's own, pitched up.
		"phytosaur_call":  {"files": ["phytosaur_call_1", "phytosaur_call_2"], "db": -5.0, "pitch": 1.04, "class": "call", "unit": 7.0, "reach": 60.0},
		"phytosaur_alert": {"files": ["phytosaur_hiss"], "db": -4.0, "pitch": 1.04, "class": "alert", "unit": 7.0},
		"phytosaur_bite":  {"files": ["phytosaur_bite"], "db": -3.0, "pitch": 1.05, "class": "bite", "unit": 6.0},
		"phytosaur_hurt":  {"files": ["phytosaur_hurt"], "db": -4.0, "pitch": 1.05, "class": "hurt", "unit": 6.0},
		"phytosaur_death": {"files": ["phytosaur_death"], "db": -2.0, "pitch": 1.0, "class": "death", "unit": 9.0},
		# One coming up out of the river onto the bank (NightProwl): heard from the side it lands on.
		"river_splash":    {"files": ["river_splash"], "db": -3.0, "pitch": 1.06, "class": "call", "unit": 9.0, "reach": 70.0},
		# Hesperosuchus: a voice of its own -- raspy barks, a thin rattling hiss, a light snap -- heard only
		# near: a small, quick hunter's, not a big one's pitched up.
		"hesperosuchus_call":  {"files": ["hesperosuchus_call_1", "hesperosuchus_call_2"], "db": -7.0, "pitch": 1.06, "class": "call", "unit": 5.0, "reach": 40.0},
		"hesperosuchus_alert": {"files": ["hesperosuchus_hiss"], "db": -6.0, "pitch": 1.06, "class": "alert", "unit": 5.0},
		"hesperosuchus_bite":  {"files": ["hesperosuchus_bite"], "db": -6.0, "pitch": 1.08, "class": "bite", "unit": 4.0},
		"hesperosuchus_hurt":  {"files": ["hesperosuchus_hurt"], "db": -7.0, "pitch": 1.08, "class": "hurt", "unit": 4.0},
		"hesperosuchus_death": {"files": ["hesperosuchus_death"], "db": -5.0, "pitch": 1.04, "class": "death", "unit": 6.0},
		# Placerias: a tonne of beaked plant-eater grazing on the valley walls -- nasal grunts, far off.
		"placerias_call": {"files": ["placerias_call_1", "placerias_call_2", "placerias_call_3"], "db": -2.0, "pitch": 1.08, "class": "call", "unit": 12.0, "reach": 110.0},
		# His work.
		"chop":     {"files": ["chop_1", "chop_2", "chop_3"], "db": -7.0, "pitch": 1.06, "class": "work"},
		"quarry":   {"files": ["quarry_1", "quarry_2", "quarry_3"], "db": -9.0, "pitch": 1.06, "class": "work"},
		"hammer":   {"files": ["hammer_1", "hammer_2", "hammer_3"], "db": -9.0, "pitch": 1.06, "class": "work"},
		"strike":   {"files": ["strike"], "db": -5.0, "pitch": 1.1, "class": "work"},
		"swing":    {"files": ["swing"], "db": -12.0, "pitch": 1.12, "class": "work"},
		"hero_hurt": {"files": ["hero_hurt"], "db": -3.0, "pitch": 1.08, "class": "hurt"},
		"eat":      {"files": ["eat"], "db": -8.0, "pitch": 1.05, "class": "work"},
		"pickup":   {"files": ["pickup"], "db": -12.0, "pitch": 1.1, "class": "ui"},
		# Rummaging in a wreck: plate knocked about, lighter than a bite on the cabin's hull.
		"salvage":  {"files": ["hull_hit"], "db": -14.0, "pitch": 1.3, "class": "work"},
		# What is built, and what becomes of it.
		"build_done": {"files": ["build_done"], "db": -5.0, "pitch": 1.04, "class": "event"},
		"wood_hit":   {"files": ["wood_hit_1", "wood_hit_2"], "db": -10.0, "pitch": 1.1, "class": "impact"},
		"stone_hit":  {"files": ["stone_hit"], "db": -10.0, "pitch": 1.1, "class": "impact"},
		"hull_hit":   {"files": ["hull_hit"], "db": -9.0, "pitch": 1.08, "class": "impact"},
		"wood_break": {"files": ["wood_break"], "db": -3.0, "pitch": 1.06, "class": "event"},
		"trap_twang": {"files": ["trap_twang"], "db": -6.0, "pitch": 1.06, "class": "impact"},
		# The traps laid in the way (CellTrap): a deadfall's weight coming down, a snare's sapling springing up.
		"trap_thud": {"files": ["trap_thud"], "db": -4.0, "pitch": 1.06, "class": "impact"},
		"trap_snap": {"files": ["trap_snap"], "db": -6.0, "pitch": 1.08, "class": "impact"},
		"craft_done": {"files": ["craft_done"], "db": -5.0, "pitch": 1.0, "class": "event"},
		"cook_done":  {"files": ["cook_done"], "db": -7.0, "pitch": 1.05, "class": "event"},
		# The raid is heard before it is seen: the pack calling from the nest, far off.
		"raid_warning": {"files": ["raid_warning"], "db": 2.0, "pitch": 1.0, "class": "boss", "unit": 40.0, "reach": 220.0},
		# The ship's own voice.
		"beacon_stage":  {"files": ["beacon_stage"], "db": -4.0, "pitch": 1.0, "class": "event", "unit": 14.0},
		"beacon_launch": {"files": ["beacon_launch"], "db": -1.0, "pitch": 1.0, "class": "event", "unit": 30.0, "reach": 200.0},
		"ui_click": {"files": ["ui_click"], "db": -16.0, "pitch": 1.05, "class": "ui"},
		"ambience_valley": {"files": ["ambience_valley"], "db": 0.0, "pitch": 1.0, "class": "ui"},
	},
}

const NEST_GUARDS: Dictionary = {
	"count": 3,                   # 巢穴外守卫数量
	"post_radius": 3.0,           # 岗位游荡半径（米）
	"aggro_radius": 6.0,          # 警戒半径：目标进入即脱离岗位追击
	"leash_radius": 12.0,         # 追出此距离放弃并返回岗位
	"roam_seconds": Vector2(2.0, 4.0),   # 岗位上多久换一个溜达的点（秒，区间内随机）
	"roam_min_distance": 0.5,            # 溜达点离岗位至少多远（米）
	"roam_pace": 0.4,                    # 溜达时的速度（占全速的比例）
	# 溜达到离那个点这么近就算到了（米）：溜达的点是随便挑的，被路过的同伴挤过头一点，不必掉头回去走最后
	# 半米——抽搐监测抓到过一只守卫这样掉头 167°（v0.6 第四轮）。
	"roam_reach": 0.8,
	# 回到岗位后安静多久才会再去追人（秒）：刚被甩掉就马上又追，就是在警戒圈边上来回拉扯。
	"reaggro_seconds": 1.5,
	# 一只守卫去追人时叫一声，岗位离它的岗位这么近以内的守卫一起来（米）——就是同一个巢的：岗位在巢
	# 周围 post_radius 米，巢两边的岗位相距 2×post_radius。以前每只只在人走进它自己的警戒圈时才追，人
	# 能一只只引出来打，每一架都赢（v0.6 第四轮："初始人就能把守卫恐龙巢穴的小龙一个个杀掉"）。
	"rally_radius": 8.0,
	# 先示威再动手（v0.6 第四轮，玩家定：debug-agent DOC-004——守卫一起上以后，开局去采巢边那块石头的人
	# 还没看见它们就被围住，6 秒倒下）：第一只看见人的站住、面朝他、冲空中咬一下、叫一声，巢里别的守卫
	# 也转过来对着他。给他这么久（秒）退到警戒圈外、再多这么远（米）；这期间靠得比 threat_close 还近、
	# 打了其中一只、或者一直不走，就一起扑上来。冲空中那一口按咬的动作放这么久（秒）。
	"threat_seconds": 2.0,
	"threat_close": 3.0,
	"calm_margin": 1.0,
	"threat_snap": 0.6,
	# 夜里睡（v0.6 第五轮，玩家定："夜里睡，靠太近或火光照到会醒"——"举火把防植龙、却会弄醒守卫，成了取舍"；
	# debug-agent BUG-023：守卫白天夜里一样，夜里的提示却说"腔骨龙睡了"）：过了它这种恐龙的时辰（DINOS.<id>.hours，
	# 腔骨龙是白天）就在岗位上趴下睡。人走到离它这么近（米，中心到中心）、火光照到它（篝火、火盆、他手里的火把，
	# 和植龙怕的是同一些光）、挨了打、或者附近残骸翻找的响声，才醒；醒了只有它自己醒——同伴的叫声叫不醒睡着的，
	# 所以一只一只地来。醒了以后没事这么多秒（秒）才又趴下；追过人、示过威以后也从头算。
	"wake_within": 2.0,
	"stay_up": 20.0,
	# 巢穴附近的建筑多近才会去咬（占警戒半径的比例）
	"building_aggro_share": 0.7,
}

# ==============================================================================
# 10. Control Configuration (v0.1 SSoT, extensible for v0.x player customization)
# ==============================================================================
## Fullscreen or not, and how that choice is remembered.
##
## The game shipped locked to fullscreen (project.godot window/size/mode = 3), which is
## fine for playing and useless for anything else -- you cannot put the window beside
## something, and you cannot take a screenshot of it to point at.
const WINDOW: Dictionary = {
	"default_fullscreen": true,
	"toggle_key": KEY_F11,      # the near-universal binding for this
}

const CONTROLS: Dictionary = {
	"hero_move_button": MOUSE_BUTTON_RIGHT,       # Default: Right-click moves Hero
	"build_place_button": MOUSE_BUTTON_LEFT,      # Default: Left-click places building / selects
	"build_cancel_button": MOUSE_BUTTON_RIGHT,    # Right-click cancels build preview
	"cancel_key": KEY_ESCAPE,                     # ESC cancels build preview
	"pause_key": KEY_SPACE,                       # Space toggles pause
	# The camera. Middle-drag pans, and HOLDING SHIFT while dragging orbits instead --
	# which is the one control the game was missing, and the reason a fence looked
	# lopsided when it was not: from one fixed bearing you see a tall building's near
	# side and the ground behind it is hidden.
	"camera_pan_button": MOUSE_BUTTON_MIDDLE,
	"camera_rotate_left_key": KEY_Q,
	"camera_rotate_right_key": KEY_E,
	"camera_tilt_up_key": KEY_F,                  # towards looking straight down
	"camera_tilt_down_key": KEY_V,                # towards looking along the ground
	"camera_reset_key": KEY_R,                    # back to the opening view
	# A bug report, in a development build (BugReport): everything the game was doing, to a file.
	# The key under Esc, left of 1 -- a dev console's, by where it is on the board whatever the
	# layout: the left hand reaches it without leaving the keys or needing Fn (it was F9; the
	# player: "我f按键不方便"). Nothing else in the game answers to it.
	"bug_report_key": KEY_QUOTELEFT,
	# Turns a trap being placed a quarter, clockwise -- with Shift, back (Trap.FACINGS). The same
	# key as the camera's reset, which it takes over only while a trap is in hand: R is where
	# every building game puts "rotate", and the view is not what the hand is on then.
	"trap_turn_key": KEY_R,
	# The commands on a card answer to the number keys, in the order they stand -- 1 the first,
	# 2 the next -- each marked with its key in a corner (v0.6 round three: the D4 / Elden Ring
	# bars mark every slot so, and a key is quicker than the mouse's trip across the screen).
	# The row above the letters is the one the camera's WASD / QE / FV / R leaves free. What
	# cannot be taken back -- a demolish, the beacon's launch -- is not on a key: it is pressed by
	# hand. Back is the cancel key's, which peels a submenu off as it does a ghost in hand.
	"command_keys": [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9],
	# His card in full -- his portrait, his bars, his kit -- and shut again, as C opens the
	# character sheet in Diablo IV (v0.6 round four: the card stood open all the while he was
	# chosen, which is most of the time). His medallion does the same. A letter the camera's keys
	# leave free.
	"details_key": KEY_C,
	# Pointing at things (Main._raycast_object). How far wide of a unit's body the cursor may
	# be and still take it, in pixels: a raptor is a small thing to hit from eighteen metres
	# up, and a unit is what a click most often means.
	"pick_slop_px": 8.0,
	# How many things one ray may pass through looking for what the click means: a tree's
	# crown, a man under it, a building behind him. Past this many it is the ground.
	"pick_depth": 6,
}

# ==============================================================================
# 10a. Dragging out a wall
# ==============================================================================
## A fence is laid by DRAGGING, the way every building game lays one: press on where it
## starts, drag to where it ends, let go. Clicking a hundred stakes one at a time is not
## a decision a hundred times over, it is the same decision a hundred times.
##
## Only things of kind "wall" do this, and that is derived rather than declared: it is
## already the category the rest of the rules are written against (Dino._is_wall,
## _should_bite), so a new kind of barrier gets the drag for free and nothing has to be
## kept in step.
const BUILD_DRAG: Dictionary = {
	# The longest run one drag may lay, in stakes. A cap rather than a budget: the run
	# already stops when the wood does, and this only stops a wild drag across the whole
	# map from building a preview of four hundred ghosts before it finds that out.
	"max_run": 120,
	# How far the cursor must travel before a press counts as a DRAG rather than a CLICK,
	# in pixels. Without it, the hand-shake in an ordinary click lays two stakes.
	"drag_threshold_px": 6.0,
}

# ==============================================================================
# 10b. The camera
# ==============================================================================
## How the view moves. Every number the camera obeys is here; there were nine of them
## buried in Main as literals before, including two different pan speeds that did not
## match and a zoom clamp written in metres of HEIGHT, which stops meaning anything the
## moment the player can tilt.
##
## The opening framing is NOT here on purpose: the rig reads it off whatever the scene's
## Camera3D is set to (CameraRig.adopt), so scenes/Main.tscn stays the one place that
## decides where the game opens, and "reset the view" means "back to what the scene said".
const CAMERA: Dictionary = {
	# How far the camera sits from the point it is looking at, in metres. Replaces a
	# clamp on the camera's HEIGHT: height is distance times the sine of the tilt, so a
	# height clamp silently becomes a different zoom range at every angle.
	"min_distance": 8.0,
	"max_distance": 45.0,
	# How far it may be tilted, in degrees below the horizon. Not all the way to 90:
	# straight down loses every silhouette, and the ground plane vanishes at 0.
	"min_tilt_degrees": 15.0,
	"max_tilt_degrees": 85.0,
	# Metres per second on a held pan key, and metres per pixel dragged, both at the
	# DEFAULT distance -- they scale with how far out the camera is, or panning while
	# zoomed out crawls and panning while zoomed in flings.
	"pan_speed": 18.0,
	"drag_pan": 0.015,
	# The cursor at the window's edge pans the view that way, at the pan keys' speed (v0.6 round
	# three: "鼠标放到边界应该可以移动视角类似方向arrow"): within this many pixels of an edge. A
	# sliver, so the buttons along the top strip are clicked without the view drifting.
	"edge_pan_margin": 6.0,
	# Degrees per second on a held key, and degrees per pixel dragged.
	"rotate_speed": 110.0,
	"tilt_speed": 55.0,
	"drag_rotate": 0.35,
	"drag_tilt": 0.25,
	# Metres of distance per wheel notch or zoom key press.
	"zoom_step": 2.2,
	# How far past the edge of the playfield the point being looked at may go, in metres.
	# Enough to look at the forest edge and up the valley wall; not enough to leave the
	# valley. There was no limit at all, and holding an arrow key panned the view off the
	# end of the world -- reported as "一直往下没有尽头的而且会出bug，就是直接移出去了".
	"focus_margin": 8.0,
	# How far above the ground the camera itself must stay, in metres. Turning a zoomed-out,
	# low-tilted view towards the valley wall would otherwise put the camera INSIDE it.
	"ground_clearance": 2.5,
}

# ==============================================================================
# 10c. The day
# ==============================================================================
## A day and its night, and who is out when (GAME-DESIGN 9.3; v0.6 round three: "一天六分钟OK";
## "恐龙的正常习性黄昏和夜晚就会进攻吗？白天不进攻吗？这是我们要做到跟恐龙的习性一样"). Seconds of game
## time from the first light. Each species keeps its own hours (DINOS.<id>.hours).
const DAY: Dictionary = {
	# Six minutes, a day and its night: four of daylight, half a minute of dusk, the rest night.
	"length": 360.0,
	# Where each part of it begins, from the first light.
	"parts": {"day": 0.0, "dusk": 240.0, "night": 270.0},
	# The run lands this far into its first morning: the dawn's glow over, the day ahead of it.
	"start": 60.0,
	# The light through the day, blended between these (SceneEnvironment.apply_time_of_day): where
	# the sun stands (at night, the moon) and its colour and strength; how much the sky lights the
	# shadows; the sky's own colours; the haze's light. The middle of the day is Config.ENVIRONMENT's
	# own light, the look the valley was made in; the night is dark enough to be night and light
	# enough to play in -- a fire is what makes it bright (GAME-DESIGN 9.3).
	#
	# "mist": how much brighter than the land under it the fog of war is drawn (FogOfWar; the mist
	# takes its brightness from the land it lies on): a little paler by day, as mist is, and darker
	# than it at dusk and at night -- a mist of one colour whatever the light was white paper at noon
	# and, at dusk and at night, brighter than the ground in sight round the Hero, which drew the eye
	# to the unknown (the debug-agent's TASK-014). The night's is not less than the dusk's: its land is
	# so dark that the screen's tone curve (ENVIRONMENT.tonemap_mode) crushes whatever is darker still
	# -- at 0.5 the never-seen mist came out a twentieth of the land under it, pure black, "像地图没开"
	# (the debug-agent's BUG-016); at 0.7 it is a shade under the mist over ground seen before.
	"light": [
		# Dawn and dusk say themselves by the light -- low, golden and long-shadowed, the sky cooling to
		# blue-violet -- not by red: at the deep red they were, the eyes tired of them (the player's report,
		# 2026-09-29: "Dawn和evening的颜色有点过于红，眼睛会不太舒服").
		{"at": 0.0, "sun_elevation": 10.0, "sun_azimuth": 85.0, "sun_color": Color(1.0, 0.76, 0.58), "sun_energy": 0.75,
			"ambient_energy": 0.34, "sky_top": Color(0.22, 0.28, 0.44), "sky_horizon": Color(0.86, 0.72, 0.62),
			"fog_color": Color(0.72, 0.66, 0.64), "mist": 1.15},
		{"at": 45.0, "sun_elevation": 18.0, "sun_azimuth": 70.0, "sun_color": Color(1.0, 0.84, 0.64), "sun_energy": 1.05,
			"ambient_energy": 0.42, "sky_top": Color(0.26, 0.40, 0.58), "sky_horizon": Color(0.90, 0.78, 0.62),
			"fog_color": Color(0.80, 0.74, 0.66), "mist": 1.3},
		{"at": 110.0, "sun_elevation": 34.0, "sun_azimuth": 40.0, "sun_color": Color(1.0, 0.93, 0.80), "sun_energy": 1.4,
			"ambient_energy": 0.5, "sky_top": Color(0.28, 0.46, 0.62), "sky_horizon": Color(0.84, 0.82, 0.70),
			"fog_color": Color(0.76, 0.80, 0.74), "mist": 1.3},
		{"at": 170.0, "sun_elevation": 34.0, "sun_azimuth": 40.0, "sun_color": Color(1.0, 0.93, 0.80), "sun_energy": 1.4,
			"ambient_energy": 0.5, "sky_top": Color(0.28, 0.46, 0.62), "sky_horizon": Color(0.84, 0.82, 0.70),
			"fog_color": Color(0.76, 0.80, 0.74), "mist": 1.3},
		{"at": 220.0, "sun_elevation": 16.0, "sun_azimuth": 10.0, "sun_color": Color(1.0, 0.78, 0.55), "sun_energy": 1.1,
			"ambient_energy": 0.42, "sky_top": Color(0.28, 0.40, 0.56), "sky_horizon": Color(0.92, 0.74, 0.56),
			"fog_color": Color(0.82, 0.72, 0.60), "mist": 1.0},
		{"at": 245.0, "sun_elevation": 10.0, "sun_azimuth": -5.0, "sun_color": Color(1.0, 0.68, 0.42), "sun_energy": 0.9,
			"ambient_energy": 0.32, "sky_top": Color(0.24, 0.26, 0.44), "sky_horizon": Color(0.88, 0.62, 0.46),
			"fog_color": Color(0.64, 0.56, 0.58), "mist": 0.6},
		{"at": 272.0, "sun_elevation": 40.0, "sun_azimuth": 20.0, "sun_color": Color(0.55, 0.65, 0.95), "sun_energy": 0.34,
			"ambient_energy": 0.2, "sky_top": Color(0.04, 0.06, 0.12), "sky_horizon": Color(0.12, 0.13, 0.22),
			"fog_color": Color(0.12, 0.14, 0.22), "mist": 0.7},
		{"at": 345.0, "sun_elevation": 30.0, "sun_azimuth": 45.0, "sun_color": Color(0.55, 0.62, 0.90), "sun_energy": 0.3,
			"ambient_energy": 0.2, "sky_top": Color(0.06, 0.07, 0.14), "sky_horizon": Color(0.20, 0.16, 0.24),
			"fog_color": Color(0.16, 0.15, 0.22), "mist": 0.7},
	],
	# How often the sky's own colours are set again, in seconds: a change of them redraws the sky,
	# and the day changes it slowly enough not to see a step.
	"sky_every": 0.5,
}

## The fog of war (FogOfWar, GAME-DESIGN 9.3; v0.6 round three: "游戏要加上战争迷雾，人不能一开始就知道
## 恐龙巢穴"; "先在现在这张图上做迷雾和找巢"): never seen is dark, seen but out of sight is the land
## dimmed with no animals on it, in sight is everything.
## THE TWITCH WATCH (TwitchWatch; v0.6 round four: "我觉得你需要做一个恐龙抽搐detector，如果恐龙抽搐，它就
## 立刻report一些debug 信息，这个在release的时候甚至可以作为telemetry"): what counts as a twitch, and
## where a report goes. Every count is over game seconds, so it holds at any of the HUD's speeds.
## THE HAND-DRAWN MAP in the corner (MiniMap; RECIPES.hide_map), and its inks -- the bare hide where he has not
## been, the land where he has, the hills darker, the river, what he has built darkest, the cabin pale, him, a
## smoking wreck, the nest.
const MINIMAP: Dictionary = {
	# Pixels a side: narrower than the goal's panel across from it (UI.objective_width), so the corner is
	# still the world's -- about three pixels to a metre on the small valley's field.
	"size": 176.0,
	# Seconds between looks at what he has seen -- the fog looks ten times a second (FOG.every); a map drawn by
	# hand need not keep up -- and drawn again only if it grew.
	"refresh_seconds": 0.5,
	"hide": Color(0.80, 0.68, 0.50),
	"land": Color(0.60, 0.50, 0.34),
	"hill": Color(0.40, 0.31, 0.20),
	"water": Color(0.42, 0.52, 0.55),
	"built": Color(0.20, 0.14, 0.09),
	"ink": Color(0.16, 0.10, 0.06),
	"cabin": Color(0.92, 0.92, 0.88),
	"hero": Color(0.95, 0.35, 0.18),
	"smoke": Color(0.30, 0.28, 0.26),
	"nest": Color(0.55, 0.12, 0.08),
}

## THE BUG REPORT (BugReport; the player, 2026-09-29: "你弄一个bug report功能（加到dev版，release版本没有这个功能）
## ……snap所有你想要知道的当前参数并dump出来……给个快捷键"): how many of the last things that happened it keeps,
## and which of what the game says are too many to be worth keeping -- said every frame, or at every step.
const BUG_REPORT: Dictionary = {
	"events": 120,
	"quiet": ["build_progress_updated", "deploy_time_changed", "resources_changed", "hero_hp_changed",
		"core_hp_changed", "game_speed_changed", "twitch_detected"],
	# The last twitches the watch wrote up (TwitchWatch), kept whole beside the events -- and so not among
	# them (the debug-agent's TASK-027: "我想再要的：最近几份抽搐报告").
	"twitches": 5,
}

const TWITCH: Dictionary = {
	# An animal's record is kept in buckets this long and judged as each closes: often enough to
	# report a twitch while it is still on the screen, and no oftener than it thinks (DINO_AI).
	"bucket": 0.25,
	# The seconds a twitch is counted over: long enough to see it done again and again.
	"window": 2.0,
	# A leg or a swing is over once it has been still this long (seconds): turning one way,
	# standing, and turning the other way seconds later is not a shake.
	"settle": 0.3,
	# JITTER: stepping back the way it came -- counted only after a leg long enough to see from the
	# game camera, about two pixels -- this many times, and ending up no further than jitter_net
	# from where the window began.
	"leg_min": 0.03,
	"jitter_flips": 4,
	"jitter_net": 0.5,
	# SHAKE: turning back against its own turning -- counted only after a swing of swing_min_deg --
	# this many times, on the spot: walking no more than shake_path and getting no further than
	# shake_net. The debug-agent's BUG-005 was swings of 48° to 135°, a few a second, in half a
	# metre. One walking a route round a rock turns this way and that as well, and is not twitching.
	"swing_min_deg": 15.0,
	"shake_flips": 3,
	"shake_path": 1.5,
	"shake_net": 1.0,
	# FIDGET: standing -- walking no more than fidget_path in fidget_window seconds -- biting nothing,
	# and turning back on its own turning this many times, however long it stood between: a head
	# swinging each way every second or so, for twenty seconds, was counted a swing at a time and never
	# reported (settle; the debug-agent's BUG-008). One turn and back after a long stand is not it.
	"fidget_window": 6.0,
	"fidget_flips": 4,
	"fidget_path": 0.5,
	# FLICKER: drawn walking, standing, walking -- this many changes back, not while it bites.
	"flicker_flips": 4,
	# DITHER: going for a thing, letting it go, going for it -- this many changes of mind back.
	"dither_flips": 3,
	# PUSH: asking to walk at push_speed or more, on average, for push_window seconds, walking no
	# more than push_share of what it asked, and getting no further than push_net -- held, not
	# pacing back and forth. Its own rules give up sooner: at a wall it has bitten it by
	# DINO_AI.stuck_window x wall_patience, 3.6 s.
	"push_window": 4.0,
	"push_speed": 1.0,
	"push_share": 0.25,
	"push_net": 0.3,
	# MILL: a raider walking mill_path metres in mill_window seconds, biting nothing and not after
	# the Hero, and ending no further than mill_net from where it began: "转来转去" -- round and
	# round, or pacing up and down, its legs mill_leg metres or more on average. One that walks as
	# far in steps of a few centimetres back and forth is shaking on the spot, and that is JITTER.
	"mill_window": 6.0,
	"mill_path": 6.0,
	"mill_net": 1.5,
	"mill_leg": 1.0,
	# Once reported, an animal is not reported for the same thing for this long; and a launch makes
	# no more than max_reports, so a bad raid cannot fill a disk.
	"cooldown": 8.0,
	"max_reports": 200,
	# Where reports go: a file of JSON lines for each launch, the newest keep_files kept.
	"dir": "user://telemetry",
	"keep_files": 20,
	# What a report says of what was round it (metres), how many of its last frames, and how many
	# of its last changes of clip and of mind.
	"near": 3.0,
	"frames": 30,
	"changes": 8,
	# A debug build marks the animal for mark_seconds, mark_above metres over its head.
	"mark_seconds": 4.0,
	"mark_above": 0.6,
}

const FOG: Dictionary = {
	# Metres to a cell of it; metres of it round the field, over the foot of the valley's walls --
	# which he sees from the field's edge. Past that, the far walls and all, nothing is ever seen.
	"cell": 1.0,
	"margin": 10.0,
	# It looks and paints again this often, in seconds; a cell's shade eases to what it should be
	# over about this long, so the edge of the fog moves rather than jumps.
	"every": 0.1,
	"ease": 0.4,
	# How unknown each cell is, 0 clear to 1 (the shroud's values; the mist below draws them): never
	# seen; seen, out of sight -- the land, no animals on it. In sight is clear.
	"unseen": 1.0,
	"seen": 0.55,
	# How it is drawn: the valley's own mist, not black (v0.6 round four: "考虑到这是一个追求真实场景的
	# 游戏，全黑是不是有点不真实"). Its colour is the environment's haze at the hour -- pale by day,
	# warm at dusk, dark blue at night -- `saturation` of the haze's own colour kept (the dusk haze as
	# it is, 0.80 0.46 0.34, made a red desert of the valley); its brightness is the land's under it,
	# read `blur` levels down the scene's mipmaps -- its lie, not its grass -- times the hour's lift
	# (DAY.light "mist"). `veil`: how thick over seen ground, the land plain through it; `never`: over
	# never-seen ground, the lie of the land a shade through it and nothing on it drawn
	# (FogOfWar._hide_the_unseen). `wisps`: how much its drifting shapes thicken and thin it;
	# `wisp_scale`, per metre, how big they are; `wisp_drift`, how fast they go.
	"mist": {"saturation": 0.5, "veil": 0.4, "never": 0.9, "wisps": 0.14, "wisp_scale": 0.05,
		"wisp_drift": Vector2(0.010, 0.004), "blur": 5.0, "round_about": 3.0, "brightest": 1.0, "ground": 0.3},
	# Seconds into a run the mist is explained, once: ground not seen yet -- not the weather ("只要
	# 玩家能感觉出来这个雾是迷雾不是天气就行").
	"hint_after": 4.0,
	# How far each sees, in metres: the Hero; the cabin; a finished building by its kind -- a trap
	# sees down its lane, a stake barely past itself.
	"sight": {"hero": 10.0, "core": 9.0, "trap": 7.0, "wall": 2.5, "building": 3.0},
	# However dark it is, the cabin sees this many metres out from its walls (FogOfWar._sources): what
	# bites it is seen biting it.
	"round_the_cabin": 2.0,
	# Of the day's sight: at dusk and in the night (GAME-DESIGN 9.3: "看得见的范围缩小，火把它撑开"). In the
	# night he sees a few metres by the moon -- 4.5, the cabin's dim windows 4 -- and a fire, or the torch
	# in his hand, lights further (FIRE; BUILDINGS.<id>.light): it was six metres, as far as a campfire,
	# and a fire lit nothing he did not see.
	"dusk": 0.8,
	"night": 0.45,
	# Seconds earlier a raid is warned of once the nest is found: its setting out is seen
	# (GAME-DESIGN 9.3: "找到了有用：看得见它们出发（预警更早）").
	"found_nest_warning": 10.0,
}

## Whether `species` is out at `part` of the day (Config.DAY.parts): the hours it keeps
## (DINOS.<id>.hours), or always, for one that keeps none.
static func keeps_hours(species: String, part: String) -> bool:
	var hours: Array = DINOS.get(species, {}).get("hours", [])
	return hours.is_empty() or hours.has(part)

# ==============================================================================
# 11. Dinosaur Flocking & Attack Slots (v0.1)
# ==============================================================================
## How far a dinosaur can reach whatever it is biting. Without this an attack had
## no notion of distance at all: once one latched onto the Hero it went on hurting
## him from across the map until he died, and stood frozen in front of a target it
## could not touch. Comfortably past the inner attack ring, so a dinosaur standing
## in its slot can always reach the thing it is standing at.
## How far past its own body a dinosaur can strike, in metres.
##
## NOT the whole reach. The reach is this plus the attacker's own half-width plus the
## target's, so a small animal biting a small thing has to get close and a big one biting
## the cabin does not -- which is what "reach" means and what a single flat number cannot
## express.
##
## DINO_ATTACK_REACH was that flat number: 2.2m, centre to centre, for every species and
## every target. A raptor is 0.8m across, so it struck 1.8m clear of its own nose, and a
## player who put one stake in front of the cabin watched raptors bite the cabin THROUGH
## it. Measured: 2.03m from the cabin centre, reach 2.20m, ten hit points to nine.
##
## 0.35 keeps every species able to reach from the slot it is sent to (which is
## DINO_STANDOFF_INNER from the target's face) with a little to spare.
const DINO_STRIKE: float = 0.35

## Kept for anything still asking the old question. What decides now is Dino.attack_reach.
const DINO_ATTACK_REACH: float = 2.2

## How high a dinosaur looks for what is in its way, at most: below the top of a stake
## (BUILDINGS.wall.height), the lowest thing that stops one. It looked at half its own
## height, and a tyrannosaur three metres tall looked clean over a stake and walked into it.
const DINO_PROBE_HEIGHT: float = 0.4

## Where a dinosaur stands to bite something, as a distance from the building's FACE.
##
## These used to be radii from the building's CENTRE, fixed at 1.6 and 2.6. That was the
## same number for everything because everything filled a 2m tile. A stake is 0.62m wide
## now, and the fixed radius put its attackers 1.3 to 2.3 METRES from a cone you could
## step over -- which is exactly the "恐龙站在木尖刺前（有一段距离）" that kept being
## reported, and which no amount of work on the targeting rules was ever going to fix.
##
## Measured from the face, a species stands the same way against a stake as against the
## wreck.
##
## Half a metre since v0.6 round two: a raptor's middle half a metre off a wall's face is its body
## a hand's breadth off it -- against it, where the spikes reach it (Config.CONTACT_REACH). At 0.6 a
## raid chewing a palisade stood just out of reach of the points it was chewing.
const DINO_STANDOFF_INNER: float = 0.5
const DINO_STANDOFF_OUTER: float = 1.6

## Kept for anything still asking the old question. A 2m building is the case they
## describe, and get_attack_slot_radius is what decides now.
const DINO_ATTACK_SLOT_RADIUS_INNER: float = 1.6
const DINO_ATTACK_SLOT_RADIUS_OUTER: float = 2.6

## How far from `type_id`'s centre a dinosaur stands while biting it.
static func get_attack_slot_radius(type_id: String, outer: bool = false) -> float:
	var half: float = get_building_footprint(type_id) * 0.5
	return half + (DINO_STANDOFF_OUTER if outer else DINO_STANDOFF_INNER)

# ==============================================================================
# 12. Continuous Real-Time Raids & Resource Nodes (v0.2)
# ==============================================================================
const RAIDS: Dictionary = {
	"interval_min": 80.0,         # 两次来袭的最小间隔（秒）——v0.4 的开局链条多了几趟路
	"interval_max": 120.0,        # 最大间隔——区间内随机，不是固定周期
	"warning_lead_time": 15.0,    # Pre-raid warning duration (seconds)
	"intensity_per_minute": 0.05, # Raid intensity escalation slope per minute (see WAVES: it multiplies)
	"intensity_jitter": 0.3,      # Random intensity fluctuation (+/- 30%)
	# A raid is a hunting party of the nest, not all of it (v0.6 round four, the player: "我认为巢穴不应该
	# 出来太多，如果需要很多恐龙，比如信标恐龙就应该来自边界"): at most this many of one step out of the
	# nest; the rest come in from the valley's edge behind it (MAPS.reinforce_from) -- and in the
	# beacon's final wave from every edge (MAPS.entries too).
	"nest_most": 5,
	# Come in from the edge, one hurries, this many times its own pace, while nobody sees it
	# (FogOfWar.is_in_sight) and it is further than edge_hurry_until metres from the cabin: the walk in
	# is the valley's size, not the raid's ("从边界出来的你可以先加速后正常速度"). Seen, or near, and it goes
	# at its own pace from then on -- nobody watches it run like that.
	"edge_hurry": 2.0,
	"edge_hurry_until": 20.0,
}

## The ship's wrecks (GAME-DESIGN 9.3, "信标变成冒险"; v0.6 round four, the player chose: "翻找几秒，
## 直接入库"; "烟柱，远处看得见"; "河边 / 巢后 / 东南边缘"). The time-travel ship broke up coming down and
## its pieces lie about the valley; three hold what the beacon lacks, one part each -- the antenna,
## the battery, the control board -- and each stage of the beacon takes one (MAPS.<id>.beacon). A
## wreck is a node he works like a tree (RESOURCE_NODES "antenna", "battery", "board"): ten strokes'
## search, and its part falls at his feet. Until it is searched it smoulders, and its smoke rises
## above the mist (WreckSmoke): where the three lie is seen from the cabin from the first, and what is
## on the way to them is not.
const WRECKS: Dictionary = {
	# The column over one: puffs rising off a fire as wide as `spread` metres, at `rise` metres a
	# second, slowing (`damping`), leant on by the wind (`wind`, metres a second each second), for
	# `lifetime` seconds -- some twenty metres of smoke, over
	# the tallest tree and seen over the ridge. A puff starts `puff` metres across and grows to
	# `billow` times it. Thin where it leaves the wreck -- the wreck is seen through it -- and
	# thickest some metres up (`alpha` at each share of its life, from nothing out of the mist to
	# nothing at the top). Dark, as what burns in a wreck is -- a pale grey was the mist's own, and
	# lost in it -- and as bright as the valley is lit at the hour (`light`: of the sun's energy and
	# of the sky's, DAY.light): barely there at night.
	"smoke": {
		"amount": 80,
		"lifetime": 14.0,
		"spread": 0.25,
		"rise": 1.8,
		"damping": 0.02,
		"wind": Vector3(0.04, 0.0, 0.02),
		"puff": 0.8,
		"billow": 3.5,
		"colour": Color(0.24, 0.23, 0.22),
		"alpha": [[0.0, 0.0], [0.1, 0.14], [0.35, 0.45], [0.7, 0.28], [1.0, 0.0]],
		"light": Vector2(0.45, 0.6),
	},
}

const RESOURCE_NODES: Dictionary = {
	"wood": {
		"name": "RESOURCE_WOOD",
		"icon": "tree",           # what the panel shows when one is picked (Config.ICON_DIR)
		"capacity": 150,
		# 0.75 wood/s by hand (v0.6 round three: "木头和石头太紧就影响建造的乐趣" -- it was 0.5, and
		# a run spent its middle short of both, the ring falling for want of a stake).
		"harvest_rate": 0.75,
		"color": Color(0.35, 0.55, 0.25),
		"depleted_color": Color(0.3, 0.3, 0.3),
		# A tree stands taller than the Hero, which is how it reads as a tree rather
		# than a bush. Width stays inside the tile so it never overhangs a cell the
		# grid says is free.
		# A tree's CROWN may spread past its cell: it is up in the air, and who can walk
		# where is decided by the cell, never by the art. Fitted into the old 1.6m box the
		# tree fern's four-metre crown shrank the whole tree to a 1.7m shrub. A young conifer
		# four times his height (VISUALS "node/wood"), over the tree ferns' three.
		"size": Vector3(3.2, 4.8, 3.2),
		# What stands in the way, and what he stands at to chop: the trunk. The crown is
		# only clicked (LAYER_PICK).
		"trunk_radius": 0.3,
	},
	"stone": {
		"name": "RESOURCE_STONE",
		"icon": "stone",
		"capacity": 100,
		"harvest_rate": 0.5,      # 0.5 stone/s by hand (was 0.35; see wood)
		# Bare hands do not cut rock. The pick is made at the cabin out of bone, and
		# bone comes off a dinosaur -- which is what turns the first raid from a
		# threat into something the player needs.
		"requires_unlock": "harvest_stone",
		"color": Color(0.6, 0.6, 0.65),
		"depleted_color": Color(0.3, 0.3, 0.3),
		# An outcrop: wide and low, unlike a tree -- sandstone breaking out of the ground (VISUALS
		# "node/stone"). No wider than it was: at 1.8 m the two by the nest narrowed the raid's way out
		# of it, and a raider stood and walked by turns in the squeeze (the twitch watch, test_07).
		"size": Vector3(1.6, 1.4, 1.6),
	},
	"water": {
		"name": "RESOURCE_WATER",
		"icon": "water",
		"capacity": 120,
		"harvest_rate": 0.5,      # 0.5 water/s by hand
		"color": Color(0.2, 0.5, 0.8),
		"depleted_color": Color(0.25, 0.3, 0.35),
		"size": Vector3(1.8, 0.5, 1.8),   # a patch of bank, as tall as the biggest jar on it
	},
	# The ship's wrecks (WRECKS), each by the part it holds: one to give (`capacity`), after
	# `strokes` of search at one a second -- ten seconds at it, bitten or not. A torn piece of
	# hull half in the ground in a scorched furrow, its plating spilled round it: three metres of
	# it, most of it low; what stands in the way is its middle (`trunk_radius`), what is clicked
	# all of it. `found` says where it is, where the part's price is (Config.source_hint).
	"antenna": {
		"name": "NODE_WRECK_ANTENNA",
		"icon": "wreck",
		"kind": "PANEL_KIND_WRECK",
		"part": true,
		"smoke": true,
		"capacity": 1,
		"harvest_rate": 1.0,
		"strokes": 10,
		"hint": "NODE_HINT_WRECK",
		"depleted_text": "STATUS_SEARCHED",
		"found": "SOURCE_ANTENNA",
		# Its din (Din; v0.6 round five, the player chose "翻找的响声引来附近的恐龙"): at these strokes of the
		# search, phytosaurs up out of the river by it -- by day too -- one at the third, one more at the seventh.
		"din": {"draws": "river", "at": [3, 7], "count": [1, 1]},
		"color": Color(0.75, 0.76, 0.78),
		"depleted_color": Color(0.35, 0.35, 0.36),
		"size": Vector3(3.0, 1.5, 3.0),
		"trunk_radius": 0.8,
	},
	"battery": {
		"name": "NODE_WRECK_BATTERY",
		"icon": "wreck",
		"kind": "PANEL_KIND_WRECK",
		"part": true,
		"smoke": true,
		"capacity": 1,
		"harvest_rate": 1.0,
		"strokes": 10,
		"hint": "NODE_HINT_WRECK",
		"depleted_text": "STATUS_SEARCHED",
		"found": "SOURCE_BATTERY",
		# Its din: the sleeping guards at the nest nearest it woken, one at a time -- asleep at night they
		# come one by one; awake by day they are on him already.
		"din": {"draws": "guards", "at": [3, 6, 9], "count": [1, 1, 1]},
		"color": Color(0.75, 0.76, 0.78),
		"depleted_color": Color(0.35, 0.35, 0.36),
		"size": Vector3(3.0, 1.5, 3.0),
		"trunk_radius": 0.8,
	},
	"board": {
		"name": "NODE_WRECK_BOARD",
		"icon": "wreck",
		"kind": "PANEL_KIND_WRECK",
		"part": true,
		"smoke": true,
		"capacity": 1,
		"harvest_rate": 1.0,
		"strokes": 10,
		"hint": "NODE_HINT_WRECK",
		"depleted_text": "STATUS_SEARCHED",
		"found": "SOURCE_BOARD",
		# Its din: a few of the valley's raiders in from the nearest way in, by day -- one, then two.
		"din": {"draws": "edge", "at": [3, 7], "count": [1, 2]},
		"color": Color(0.75, 0.76, 0.78),
		"depleted_color": Color(0.35, 0.35, 0.36),
		"size": Vector3(3.0, 1.5, 3.0),
		"trunk_radius": 0.8,
	},
}

# ==============================================================================
# 12b. Visuals (v0.5) -- where the art is, and how big the thing really is
# ==============================================================================

## What every visible thing in the game is drawn as.
##
## The whole of the v0.5 art migration goes through this table: a model arrives, its
## `scene` stops being empty, and **no logic anywhere moves**. Before this, each entity
## built its own body out of primitives inside `_ensure_components()`, so every model
## would have meant opening and rewriting a different file -- and those files carried
## naked sizes that silently contradicted what was declared here. The big theropod
## declared 1.6 metres for versions and was drawn at 0.8, because nothing read it.
##
## Fields:
##   scene       -- "" while there is no art. A path once there is.
##   placeholder -- which primitive stands in meanwhile: box / cylinder / cone / spikes.
##   anchor      -- "feet" puts the model's lowest point on the ground (characters,
##                  buildings, trees); "center" puts its middle there (a half-buried
##                  boulder). Getting this wrong is why bought models float or sink.
##   color       -- a key into COLORS, for the placeholder only. Real art brings its own.
##
## SIZE IS NOT HERE, on purpose. It is read from wherever the thing already declares
## its dimensions (see get_visual_size), because a second place to write a size is a
## second place for it to be wrong -- and the size is load-bearing: the collider and
## the art are both built from it, which is what stops art from quietly growing wider
## than the thing that blocks a raptor.
const VISUALS: Dictionary = {
	# A man of ordinary build in a plain shirt, trousers and shoes, bare-headed
	# (tools/build_hero.py, from Quaternius's CC0 character kits). He was the kits' cartoon
	# worker in a yellow hard hat -- a big head on a short body, reported as "太卡通了".
	# Fitted by HEIGHT, because he is rigged in a T-pose -- his rest shape is as wide as he
	# is tall, arms straight out -- and a box fit sized him by that span. In play he is
	# always in a clip, arms down.
	"hero":                 {"scene": "res://assets/models/quaternius/hero.glb", "fit": "height",
		"placeholder": "hero", "anchor": "feet", "color": "caveman"},
	# Every dinosaur gets its own row even while they share a placeholder: the row is
	# where its model will go, and they will not share that.
	# Quaternius' animated dinosaurs (CC0, tools/convert_quaternius.py), one author for the
	# whole cast. The pterosaur has none there and stays the generated one.
	#
	# Fitted by HEIGHT. A dinosaur's collider is a box -- a gameplay shape: reach, blocking
	# and paths are all worked out from it -- and a long-tailed animal fitted INSIDE that
	# box by its length stood a third of its declared height: the raptor came in 33 cm tall
	# and was lost in the ferns. By height it is as tall as Config says, and its tail
	# reaches past the box, as a tail does.
	"dino/raptor":          {"scene": "res://assets/models/quaternius/velociraptor.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "raptor"},
	"dino/big_theropod":    {"scene": "res://assets/models/quaternius/trex.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "big_theropod"},
	# The raptor, grown: fitted by height to its own taller size (GAME-DESIGN v0.6: a scaled
	# raptor until it has a model of its own).
	"dino/raptor_alpha":    {"scene": "res://assets/models/quaternius/velociraptor.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "raptor_alpha"},
	# The first map's cast (tools/generate_triassic.py): the Quaternius rigs reshaped, so they play the same
	# clips, and a body sculpted round them (tools/triassic_bodies.py), coloured at its vertices ("skin").
	# The alpha is the same animal, fitted to its own taller size and painted apart: darker, rust-flanked,
	# its head flushed red -- the pack's leader picked out at a glance.
	"dino/coelophysis":     {"scene": "res://assets/models/triassic/coelophysis.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "coelophysis", "material": "skin"},
	"dino/coelophysis_alpha": {"scene": "res://assets/models/triassic/coelophysis_alpha.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "coelophysis_alpha", "material": "skin"},
	"dino/postosuchus":     {"scene": "res://assets/models/triassic/postosuchus.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "postosuchus", "material": "skin"},
	# Long-snouted and armoured, its own eyes a material the game lights (ProwlerDino, the eye-shine).
	"dino/phytosaur":       {"scene": "res://assets/models/triassic/phytosaur.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "phytosaur", "material": "skin"},
	# Hesperosuchus (tools/generate_triassic.py): the velociraptor's rig with a crocodile's snout, scutes
	# down its back, long forelimbs -- up on its hind legs to run.
	"dino/hesperosuchus":   {"scene": "res://assets/models/triassic/hesperosuchus.glb", "fit": "height",
		"placeholder": "raptor", "anchor": "feet", "color": "hesperosuchus", "material": "skin"},
	"dino/pterosaur":       {"scene": "res://assets/models/pterosaur.glb", "placeholder": "raptor",   "anchor": "feet",   "color": "pterosaur"},
	# A low mound of scraped-up earth with a clutch of eggs in the hollow on top, a rim of
	# broken branches, and a burrow at its foot facing the field: the mouth the raid pours
	# out of, with bones by the door (tools/generate_props.py).
	"nest":                 {"scene": "res://assets/models/props/nest_a.glb",
		"material": "vertex", "placeholder": "nest_mound", "anchor": "feet", "color": "nest"},
	# The Coelophysis nesting ground (tools/generate_props.py nest_colony): the first map's nest.
	"nest/coelophysis":     {"scene": "res://assets/models/props/nest_coelophysis_a.glb",
		"material": "vertex", "placeholder": "nest_mound", "anchor": "feet", "color": "nest"},
	# The cabin: the crew module of the ship that brought the Hero here, where it came down --
	# its heat shield ploughed into the earth at the west end, the engine and the ship's gun at
	# the east, a door and windows in its south side, a torn solar panel on the roof -- and the
	# room inside it, his benches along the back wall (tools/generate_cabin.py module). Built
	# to scale about its own middle, so it is not fitted: the hull is where CABIN.module says.
	# The only evidence he is from anywhere else, and the thing that ends the game if the raid
	# reaches it.
	"building/core":        {"scene": "res://assets/models/cabin/module_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "ship_wreck", "anchor": "feet", "color": "core"},
	# The traps (tools/generate_props.py trip_bow, set_crossbow): kits whose String is drawn
	# back and let go, and whose Arrow or Bolt is gone while it is re-armed (Trap.gd). Built
	# pointing north; the trap turns the whole body to the way it faces.
	"building/trip_bow":       {"scene": "res://assets/models/props/trip_bow_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	"building/set_crossbow":   {"scene": "res://assets/models/props/set_crossbow_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	# Its second stave lashed over the first, and a rack of spare bolts on the plinth.
	"building/set_crossbow_2": {"scene": "res://assets/models/props/set_crossbow_2_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	# The traps laid in the way (tools/generate_props.py ground_spikes, deadfall, snare): built to the cell,
	# not fitted -- a deadfall's Weight and a snare's Sapling turn about their feet (CellTrap).
	"building/ground_spikes":  {"scene": "res://assets/models/props/ground_spikes_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	"building/bone_spikes":    {"scene": "res://assets/models/props/bone_spikes_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	"building/log_deadfall":   {"scene": "res://assets/models/props/log_deadfall_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	"building/stone_deadfall": {"scene": "res://assets/models/props/stone_deadfall_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	"building/grass_snare":    {"scene": "res://assets/models/props/grass_snare_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	"building/hide_snare":     {"scene": "res://assets/models/props/hide_snare_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	# A metre of palisade (tools/generate_props.py palisade): a post of sharpened logs in the
	# middle, and a run of them out to each side of the cell, lashed to a rail -- the runs
	# towards whatever stands in the cells beside it are shown, so a line of them is one
	# palisade (Wall.gd). Axe-cut points, fire-hardened tips, vine lashing, turned earth.
	# The fence with a rock on it: the same kit, and the Rock the Wall drops and lifts back.
	"building/rock_fence":  {"scene": "res://assets/models/props/rock_palisade_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "wall"},
	# A crossbow in a stone wall: Base, Bow, String, Bolt, as the set crossbow's.
	"building/wall_crossbow": {"scene": "res://assets/models/props/wall_crossbow_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "trap"},
	"building/wall":        {"scene": "res://assets/models/props/palisade_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "wall"},
	# The same palisade with bone points lashed to its logs (palisade bone=True): what it is
	# made of, readable from the camera.
	"building/bone_stake":  {"scene": "res://assets/models/props/bone_palisade_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "wall"},
	# Courses of unmortared stone filling the cell, capstones on top (tools/generate_props.py
	# stone_wall).
	"building/stone_wall":  {"scene": "res://assets/models/props/stone_wall_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "stone_wall"},
	# Two gateposts and a door of lashed planks on a vine hinge (tools/generate_props.py gate),
	# the door its own node, which swings open for the Hero (Gate.gd).
	"building/gate":        {"scene": "res://assets/models/props/gate_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "wall"},
	# The fires (tools/generate_props.py campfire, brazier): the stones and the wood; the flame and
	# its light are the game's (Fire.gd), lit at dusk.
	"building/campfire":    {"scene": "res://assets/models/props/campfire_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "fire"},
	"building/brazier":     {"scene": "res://assets/models/props/brazier_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "fire"},
	# A tree is a trunk, a rock is a lump: the cylinder is a stand-in for both until the
	# models land, and "center" is wrong for both of them, so both anchor at the feet.
	#
	# WHAT CAN BE WORKED IS TOLD FROM THE VALLEY BY WHAT IT IS (UI-POLISH T21; v0.6 round four, the
	# player: "比如石头，树木，能点的个背景现在很像"; "要还原真实"): no ring or mark on it. The tree
	# he cuts was a tree fern, like the forest round the field -- it could not be told from it. It
	# is a young conifer now, Araucarioxylon, the timber of the Chinle's own Petrified Forest: a
	# spire of whorled branches in a litter of its own fallen needles, where the forest is tree
	# ferns and cycads -- fibre, not timber. Felled, a stump with the trunk and its crown lying
	# where they fell (tools/generate_flora.py timber_conifer, timber_stump).
	"node/wood":            {"scene": "res://assets/models/flora/timber_conifer_a.glb",
		"scene_depleted": "res://assets/models/flora/timber_stump_a.glb",
		"material": "flora",    # coloured by its vertices, like the forest it stands in
		"placeholder": "cycad", "anchor": "feet", "color": ""},
	# And the stone he quarries was mossy grey boulders, like every rock the valley is strewn
	# with: it is a low ledge of the Chinle's bedded sandstone now, slabs banded red, ochre and
	# mauve, broken pieces at its foot -- the rock that is already breaking. Quarried, cut down
	# to a stub with pale fresh tops, rubble round it (tools/generate_props.py sandstone_outcrop).
	"node/stone":           {"scene": "res://assets/models/props/sandstone_outcrop_a.glb",
		"scene_depleted": "res://assets/models/props/sandstone_quarried_a.glb",
		"material": "vertex", "placeholder": "outcrop", "anchor": "feet", "color": ""},
	# Where the Hero draws water, on the river bank at the field's edge: trodden wet mud, a
	# flat stone at the water's edge, clay jars (tools/generate_props.py water_landing). The
	# level turns it to face the river. It was a blue puddle in the middle of the field.
	"node/water":           {"scene": "res://assets/models/props/water_landing_a.glb",
		"material": "vertex", "placeholder": "pool", "anchor": "feet", "color": ""},
	# The ship's wrecks (WRECKS; tools/generate_props.py wreck): a torn piece of the hull, the white
	# plating and orange markings the cabin wears, scorched, half in a burnt furrow, plates spilled
	# round it -- and what the part was fitted in: a bent mast, a battery bay, a console. Searched,
	# its bay is torn open and the panel that closed it lies by it. Built to size, in metres, and
	# not fitted: searched, it is the same wreck, and fitting each to the box would rescale it.
	"node/antenna":         {"scene": "res://assets/models/props/wreck_antenna_a.glb", "fit": "none",
		"scene_depleted": "res://assets/models/props/wreck_antenna_searched_a.glb",
		"material": "vertex", "placeholder": "outcrop", "anchor": "feet", "color": ""},
	"node/battery":         {"scene": "res://assets/models/props/wreck_battery_a.glb", "fit": "none",
		"scene_depleted": "res://assets/models/props/wreck_battery_searched_a.glb",
		"material": "vertex", "placeholder": "outcrop", "anchor": "feet", "color": ""},
	"node/board":           {"scene": "res://assets/models/props/wreck_board_a.glb", "fit": "none",
		"scene_depleted": "res://assets/models/props/wreck_board_searched_a.glb",
		"material": "vertex", "placeholder": "outcrop", "anchor": "feet", "color": ""},
	# The parts, lying where they fell out of the search (tools/generate_props.py drop_antenna ...):
	# a folded dish on its mast, a battery cell, the control unit.
	"drop/antenna":         {"scene": "res://assets/models/props/drop_antenna_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"drop/battery":         {"scene": "res://assets/models/props/drop_battery_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"drop/board":           {"scene": "res://assets/models/props/drop_board_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	# What a drop of each resource looks like lying on the ground: split logs, a heap of
	# quarried stone, bones, a haunch of meat, a clay pot of water (tools/generate_props.py
	# drop_*). They were cubes in the resource's colour, and a green cube was wood.
	"drop/wood":            {"scene": "res://assets/models/props/drop_wood_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"drop/stone":           {"scene": "res://assets/models/props/drop_stone_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"drop/bone":            {"scene": "res://assets/models/props/drop_bone_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"drop/food":            {"scene": "res://assets/models/props/drop_food_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	# A boss's cut. The haunch for now: what sets it apart on the ground is its colour on
	# the pickup and the top bar, until it has a model of its own.
	"drop/prime_meat":      {"scene": "res://assets/models/props/drop_food_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"drop/water":           {"scene": "res://assets/models/props/drop_water_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	# A hide off an elite, rolled and tied (tools/generate_props.py drop_hide).
	"drop/hide":            {"scene": "res://assets/models/props/drop_hide_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	# The torch in his hand (tools/generate_props.py torch): a stick, its head wrapped in resinous bark.
	# Built with its grip at the origin; held there (Hero.light_torch), its flame the game's.
	"prop/torch":           {"scene": "res://assets/models/props/torch_a.glb", "fit": "none",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "fire"},
	# Inside the cabin (tools/generate_cabin.py): the three benches the Hero fitted the module
	# out with, along its back wall. Each is one file of named parts that show as the run goes
	# on (scripts/fx/CabinArt.gd): the tools hang on the workbench's board once made, the stone
	# pot replaces the spit over the fire, the beacon's broken mast goes back up a stage at a
	# time. They were boxes.
	"station/workbench":    {"scene": "res://assets/models/cabin/workbench_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"station/kitchen":      {"scene": "res://assets/models/cabin/kitchen_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
	"station/beacon":       {"scene": "res://assets/models/cabin/beacon_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": ""},
}

## How many metres `key` occupies, resolved from wherever that thing declares its own
## dimensions. One source per size, and the collider and the art both come from here.
static func get_visual_size(key: String) -> Vector3:
	var kind: String = key.get_slice("/", 0)
	var id: String = key.substr(kind.length() + 1) if key.contains("/") else ""
	match kind:
		"hero":
			var w: float = float(HERO.get("width", 0.8))
			return Vector3(w, float(HERO.get("height", 1.6)), w)
		"dino":
			if DINOS.has(id) and DINOS[id].has("size"):
				return DINOS[id]["size"]
			return Vector3.ONE * 0.8
		"nest":
			return NEST.get("sizes", {}).get(id, NEST.get("size", Vector3(2.0, 1.2, 2.0)))
		"building":
			var half: Vector2 = get_building_half(id)
			return Vector3(half.x * 2.0, get_building_height(id), half.y * 2.0)
		"node":
			if RESOURCE_NODES.has(id) and RESOURCE_NODES[id].has("size"):
				return RESOURCE_NODES[id]["size"]
			return Vector3(1.6, 1.0, 1.6)
		"drop":
			# A pile is wider than it is tall: half as wide again as DROPS.size, which is
			# as tall as one gets.
			var s: float = float(DROPS.get("size", 0.3))
			return Vector3(s * 1.5, s, s * 1.5)
		"station":
			return CABIN.get("station_sizes", {}).get(id, Vector3.ONE)
	return Vector3.ONE

# ==============================================================================
# 13. Drops (v0.3) -- every resource enters the warehouse through the Hero
# ==============================================================================
## Nothing is banked as a number any more: dinosaurs leave meat, machines leave
## what they cut at their feet, hand-harvesting leaves a pile, and the opening
## stock is scattered by the cabin. "One body holds up a whole base" only means
## something if the body has to carry the goods as well as build with them.
##
## Four decisions were open when this was designed; these are the answers, and each
## is one number here rather than a shape in the code:
##   * Do drops rot? No -- `lifetime` 0. A raid fought at the far end of the map
##     would otherwise be work for nothing, and the ground is kept tidy by merging
##     rather than by a timer. Set it above 0 to make collection urgent.
##   * Do piles merge? Yes, within `merge_radius`, and a merged pile shows its
##     count. It keeps a long fight from carpeting the field in single units.
##   * Is there a cap? `max_on_ground` caps the number of *piles*, never the
##     resources: at the cap a new drop merges into the nearest pile of its kind,
##     so nothing the player earned is ever deleted.
##   * Is fetching drops from a battlefield interesting or a chore? With no rot it
##     is a choice rather than a deadline -- the mild answer, deliberately, until
##     it has been played.
const DROPS: Dictionary = {
	"stack_amount": 1,        # 一个掉落物携带的资源量
	"pickup_radius": 1.6,     # 现代人走到这个距离内就自动捡起（不需要点击）
	"merge_radius": 1.1,      # 新掉落物并入附近同类堆的距离
	"max_on_ground": 200,     # 场上"堆"数上限（性能护栏，不会丢资源）
	"lifetime": 0.0,          # 0 = 永不消失
	"scatter_radius": 0.8,    # 一次掉落多个时的散布半径（米）
	"toss_height": 0.75,      # 抛出弧线的高度（米）
	"toss_time": 0.35,        # 抛出到落地的时长（秒）
	"fly_time": 0.18,         # 被捡起时飞向现代人的时长（秒）
	"size": 0.3,              # 一堆的高度（米）；宽是它的 1.5 倍，见 get_visual_size
	"label_min_amount": 2,    # 堆叠数达到这个值才显示数字
	# 开局物资撒在船舱周围，而不是直接进仓库。撒多少是地图的内容（MAPS 里的
	# opening_stock），怎么撒是这里的规则。
	"opening_piles": 4,        # 分成几堆
	# A chance drop (DINOS[..].drop_chance) is never missed more than this many times running, and
	# the first of a run is never missed: chance may leave him more, never stuck (GAME-DESIGN 9.2,
	# "随机只会带来富余，不会卡住人") -- the first raid's bone is the bone pick.
	"pity_after": 1,
	# 离船舱墙壁的距离（米）——从墙壁量，不是从中心量：船舱现在三米宽，从中心量 4.5 米，
	# 南边那一堆离出生点只有一米半，现代人第一帧就捡走了，"开局物资要走过去拿"这一课就白教了。
	# 对原来那个一米的舱体，这正好就是原来的 4.5 米。必须让每一堆都在出生点的拾取半径之外。
	"opening_ring_gap": 4.0,
}

## What the player has to go and fetch before anything can be built, totalled by
## resource. The same figure a wallet used to start with, just on the floor.
static func get_opening_stock(res_id: String, map_id: String = "") -> int:
	return int(map_data(map_id).get("opening_stock", {}).get(res_id, 0))

## Colour for a resource that has no node on the map: meat only ever comes off a
## dinosaur, so RESOURCE_NODES has nothing to say about it.
const RESOURCE_FALLBACK_COLORS: Dictionary = {
	"food": Color(0.78, 0.32, 0.28),
	"prime_meat": Color(0.62, 0.12, 0.16),   # darker and richer than meat: a boss's cut
	"bone": Color(0.88, 0.85, 0.72),
	"hide": Color(0.55, 0.38, 0.22),         # tanned leather: an elite's hide (DINOS drops)
}

## The colour of a resource anywhere it has to be drawn -- a map node, a drop, a
## coverage ring. Map nodes are the primary source; RESOURCE_FALLBACK_COLORS
## answers for the resources that have no node.
static func get_resource_color(res_id: String) -> Color:
	if RESOURCE_NODES.has(res_id) and RESOURCE_NODES[res_id].has("color"):
		return RESOURCE_NODES[res_id]["color"]
	if RESOURCE_FALLBACK_COLORS.has(res_id):
		return RESOURCE_FALLBACK_COLORS[res_id]
	return Color(0.7, 0.7, 0.7)

# ==============================================================================
# 13b. Repair (v0.4)
# ==============================================================================
## Patching a building up rather than letting it fall.
##
## The bill is the building's own price scaled by how much of it is missing,
## rounded up, in every resource it was built from. So mending can never cost more
## than building the thing again, a scratch costs the minimum rather than a flat
## fee, and a set crossbow -- expensive, and worth keeping where it stands -- is the
## thing repair is really for.
##
## It is one transaction, charged when the work finishes: walking away costs the
## time spent and nothing else, and there is no half-paid state to reason about.
const REPAIR: Dictionary = {
	"seconds_per_unit": 1.2,  # 每一点修理费对应的施工秒数
}

# ==============================================================================
# 14. The cabin workshop (v0.4)
# ==============================================================================
## The cabin is the thing you defend and the thing you need, and everything the
## Hero gains is made in it. **Tools decide what he can gather, materials decide what
## he can build** (GAME-DESIGN 4.1 rule 1): the workbench turns wood, stone and bone
## into tools -- what the Hero can *do* -- and the kitchen makes the vessels he cooks
## in. There are no blueprints: the kitchen used to turn meat into one, and a master
## builder was made to work out how to build a crossbow.
##
## Nothing here is an inventory item. A recipe grants a permanent flag and that is
## the whole of it: unlocked means usable, so there is no bag, no slots, and no
## stat sheet to maintain. That is the line that keeps this from becoming an RPG.
##
## The interior is a scene parked off the map rather than a scene swap, so the
## world keeps running while the player is inside -- which is the point: crafting
## costs real seconds, and while he is at the bench nobody is holding the line.
const CABIN: Dictionary = {
	# THE CREW MODULE (v0.6 round three), in metres about its middle, x east and z south -- the
	# model's measures (tools/generate_cabin.py module), so what stops a body is where the hull
	# is drawn. Its box is BUILDINGS.core.size; inside it:
	#   room       the half-extents of the floor he walks on: bulkhead to bulkhead, wall to wall
	#   wall       how thick the long walls are, north and south, out to the box's edge; the
	#              ends past the room, the heat shield's and the engine's, are solid
	#   door       the hatch in the south wall: its middle (x), how wide and high it is -- a hand
	#              wider than him either side, and the navigation mesh's own margin
	#              (NAV.agent_radius) leaves him a way through
	"module": {
		"room": Vector2(2.8, 1.3),
		"wall": 0.2,
		"door": {"x": 0.0, "width": 1.2, "height": 1.8},
	},
	# Where he stands to go in and where he is left when he steps out: this far in front of the
	# door, and this far inside it -- clear of the frame, in the camera's sight.
	"door_standoff": 0.8,
	"inside_step": 0.8,
	# The door slides open as he comes within this many metres of it, over this long, and
	# shuts behind him; a raid it keeps out (CoreCampfire.gd).
	"door_open_radius": 1.6,
	"door_slide_seconds": 0.35,
	# INSIDE ("人进入船舱之后，应该也是同样的人在船舱里面"): the same camera and the same world,
	# the roof and the front wall above the sill faded to this much see-through -- enough left
	# to see where they were -- over this long; and the camera eased in over the room, this far
	# from it, and back out to where it was when he leaves.
	"fade_transparency": 0.88,
	"fade_seconds": 0.4,
	"inside_camera_distance": 11.0,
	"camera_ease_seconds": 0.6,
	# The windows' glass: tinted, mostly clear, so the benches show through from outside and a
	# raid through them from inside.
	"glass_color": Color(0.62, 0.8, 0.9, 0.22),

	# The benches, in metres and true to scale -- the Hero is 1.2 m: the workbench's top at his
	# waist, the hood over the fire at his head, the beacon's dish over it. A bench is clicked
	# by its declared size, like everything else (the art is fitted to it and the collider is
	# built from it), and stands where the module's model marks it ("spot_<id>").
	"station_sizes": {
		"workbench": Vector3(1.24, 1.52, 0.68),
		"kitchen": Vector3(1.29, 2.56, 0.82),
		"beacon": Vector3(1.32, 1.89, 0.76),
	},
	# Parts that glow (tools/generate_cabin.py names them "..._glow") and also light the room
	# round them: colour, energy, range, and how much and how fast they flicker. The ceiling
	# lamp is steady; the fire wavers; a working screen barely does; the fault light while the
	# radio is dead pulses slowly; the lamp in the dish once the beacon is launched throbs.
	"glow_lights": {
		"fade_lamp_glow": {"color": Color(1.0, 0.92, 0.78), "energy": 1.0, "range": 5.0, "flicker": 0.0, "speed": 1.0},
		"fire_glow": {"color": Color(1.0, 0.6, 0.28), "energy": 1.6, "range": 3.0, "flicker": 0.25, "speed": 9.0},
		"beacon_3_glow": {"color": Color(0.4, 0.85, 0.95), "energy": 0.6, "range": 1.8, "flicker": 0.05, "speed": 3.0},
		"before_beacon_3_glow": {"color": Color(1.0, 0.22, 0.12), "energy": 0.35, "range": 1.2, "flicker": 0.6, "speed": 1.5},
		"beacon_launch_glow": {"color": Color(0.5, 0.9, 1.0), "energy": 2.2, "range": 4.0, "flicker": 0.4, "speed": 2.0},
		# The roof mast's lamps (v0.6 round three: "也有小的灯"), one a stage: red, amber, the ship's
		# cyan, blinking like a mast's warning lamps, each on its own beat ("blink" flashes a second,
		# lit for "duty" of each); at the launch the dish's throat, bright and restless.
		"lamp_beacon_1_glow": {"color": Color(1.0, 0.22, 0.12), "energy": 1.6, "range": 3.0, "blink": 0.75, "duty": 0.35},
		"lamp_beacon_2_glow": {"color": Color(1.0, 0.62, 0.15), "energy": 1.4, "range": 3.0, "blink": 0.6, "duty": 0.35},
		"lamp_beacon_3_glow": {"color": Color(0.4, 0.9, 1.0), "energy": 1.6, "range": 3.5, "blink": 0.5, "duty": 0.5},
		"lamp_beacon_launch_glow": {"color": Color(0.6, 0.95, 1.0), "energy": 3.0, "range": 7.0, "flicker": 0.5, "speed": 3.0},
	},
}

## Every recipe, whatever station it belongs to, has the same shape:
##   station  -- which bench it is made at
##   inputs   -- what it costs, spent when work begins: a tool or a piece of gear is made of what it
##               is named for and nothing else (GAME-DESIGN 6.0 rule 1; v0.6 round six, the player:
##               "材料各种各样……总感觉有点confuse哪个材料是用来做什么，也很难做规划") -- the bone pick of
##               bone, the stone axe of stone, the vest of hide; the few pieces of wood for a haft
##               went, and so did the bone plates on the second armour (bone is for what cuts)
##   time     -- seconds the Hero must stand there (progress is kept if he leaves)
##   unlocks  -- the permanent flag it grants
## Adding a third station later is an entry here plus a node in the scene, not a
## new system.
const RECIPES: Dictionary = {
	# Neolithic flint miners dug with antler picks: this one is bone, and bone only comes
	# off a dinosaur -- which is what turns the first raid into something the player needs.
	# Named for what it is made of, like everything else (the bone stake, the stone axe): it
	# was the "stone pick", which read as a pick made of stone that stone was needed for.
	# The id stays -- ids never change (GAME-DESIGN 12.6).
	"stone_pick": {
		"name": "RECIPE_STONE_PICK_NAME",
		"station": "workbench",
		"inputs": {"bone": 1},
		"time": 8.0,
		"unlocks": "harvest_stone",
		"slot": "pick",
		"tier": 1,
	},
	# A ground stone head lashed to a haft: the first thing the quarry gives, after the pick.
	"stone_axe": {
		"name": "RECIPE_STONE_AXE_NAME",
		"station": "workbench",
		"inputs": {"stone": 3},
		"time": 6.0,
		"unlocks": "stone_axe",
		"slot": "axe",
		"tier": 1,
		# What a tool does is part of its recipe, so a new tool is a line here and no code
		# (GAME-DESIGN 14.1): every stroke on a tree brings down twice as much. Only the best
		# of a slot counts (Config.kit): an iron axe later is its own factor, not one on top.
		"harvest_speed": {"wood": 2.0},
	},
	# The pick's second step (v0.6 round three): a ground stone head lashed where the bone was --
	# stone comes out twice as fast, and it takes the bone pick's place in his row.
	"quarry_pick": {
		"name": "RECIPE_QUARRY_PICK_NAME",
		"station": "workbench",
		"inputs": {"stone": 5},
		"time": 8.0,
		"unlocks": "quarry_pick",
		"slot": "pick",
		"tier": 2,
		"harvest_speed": {"stone": 2.0},
	},
	# A weapon (v0.6 round three: "武器和鞋子也可以有一格"): he hits harder -- "damage" multiplies
	# his own (Config.HERO.damage). Always weaker than the traps (GAME-DESIGN 5.5): a man defends
	# himself with it, the line is held by what he builds.
	"stone_spear": {
		"name": "RECIPE_STONE_SPEAR_NAME",
		"station": "workbench",
		"inputs": {"stone": 3},
		"time": 6.0,
		"unlocks": "stone_spear",
		"slot": "weapon",
		"tier": 1,
		"damage": 1.5,
	},
	"bone_spear": {
		"name": "RECIPE_BONE_SPEAR_NAME",
		"station": "workbench",
		"inputs": {"bone": 3},
		"time": 8.0,
		"unlocks": "bone_spear",
		"slot": "weapon",
		"tier": 2,
		"damage": 2.0,
	},
	# Armour (v0.6 round three: "增加皮和护甲的一些制作……护甲可以专门做一个或者做成血量"): hit points
	# over his own for good -- "max_hp" -- drawn on his bar in leather. The better one replaces the
	# lesser, and both are hide: the second is the vest under another layer of it, thick and tanned
	# (v0.6 round six: it was bone lamellar, and bone is for what cuts). The id stays (12.6).
	"hide_vest": {
		"name": "RECIPE_HIDE_VEST_NAME",
		"station": "workbench",
		"inputs": {"hide": 1},
		"time": 8.0,
		"unlocks": "hide_vest",
		"slot": "armor",
		"tier": 1,
		"max_hp": 3.0,
	},
	"bone_armor": {
		"name": "RECIPE_BONE_ARMOR_NAME",
		"station": "workbench",
		"inputs": {"hide": 2},
		"time": 12.0,
		"unlocks": "bone_armor",
		"slot": "armor",
		"tier": 2,
		"max_hp": 5.0,
	},
	# Boots: he walks faster for good -- "move_speed" multiplies his own. What meals did for his
	# stride before (COOKING_METHODS); a meal now makes him work faster instead.
	"hide_boots": {
		"name": "RECIPE_HIDE_BOOTS_NAME",
		"station": "workbench",
		"inputs": {"hide": 1},
		"time": 6.0,
		"unlocks": "hide_boots",
		"slot": "boots",
		"tier": 1,
		"move_speed": 1.2,
	},
	# THE HAND-DRAWN MAP (GAME-DESIGN 9.3; v0.6 round five, the player: "小地图没有还是会有点confusing，我们需要设计怎么
	# 能获得小地图" -- chosen "在工作台做一张地图"): the valley as he has seen it, drawn on a hide (6.0: made of what it
	# is named for). Made, it is in the corner for good (MiniMap), outside his row.
	"hide_map": {
		"name": "RECIPE_HIDE_MAP_NAME",
		"station": "workbench",
		"inputs": {"hide": 1},
		"time": 10.0,
		"unlocks": "hide_map",
	},
	# A flat stone set over the fire, to sear meat on (GAME-DESIGN 4.5). Made in the
	# kitchen, like every vessel, and kept for good like a tool. Quarried stone, so it
	# comes after the pick.
	"stone_pot": {
		"name": "RECIPE_STONE_POT_NAME",
		"station": "kitchen",
		"inputs": {"stone": 3},
		"time": 6.0,
		"unlocks": "stone_pot",
	},
}

## His row (v0.6 round three: "能力栏还是得有吧……能力和装备栏两个都在又有点过于复杂……不能让玩家觉得
## 复杂"): what he has made for good, a slot for each kind, in this order. A recipe in the row
## says its "slot" and its "tier"; the best he holds of a slot is the one in it, and only its
## effects count (kit, counts). Kept once made, one line each; nothing to put on or take off.
## A kitchen's pot is not in it: it stays in the kitchen.
const KIT_SLOTS: Array[String] = ["pick", "axe", "weapon", "armor", "boots"]

## The best of each slot he holds: {slot: recipe id} -- a better one having taken its lesser's
## place.
static func kit(owned: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for recipe_id in RECIPES:
		var row: Dictionary = RECIPES[recipe_id]
		var slot: String = String(row.get("slot", ""))
		if slot == "" or not owned.has(String(row.get("unlocks", ""))):
			continue
		if not out.has(slot) or int(row.get("tier", 1)) > int(RECIPES[out[slot]].get("tier", 1)):
			out[slot] = String(recipe_id)
	return out

## Whether what `recipe_id` does counts for `owned`: one outside the row once it is made, one in
## it while it is the best of its slot.
static func counts(recipe_id: String, owned: Dictionary) -> bool:
	var row: Dictionary = RECIPES.get(recipe_id, {})
	if row.is_empty() or not owned.has(String(row.get("unlocks", ""))):
		return false
	var slot: String = String(row.get("slot", ""))
	return slot == "" or String(kit(owned).get(slot, "")) == recipe_id

## Whether `recipe_id` is the next step up its slot of his row for `owned` -- the lowest tier above the
## one he holds -- or not in the row at all: the bench offers only that (CraftingStation; GAME-DESIGN 6.0
## rule 4, 5.5). The vest and the bone armour were on it together, and the vest was a waste once both
## could be paid for (v0.6 round six, the player: "bone armer，皮革armer直接冲突了，一起出现（而且很容易
## 一起出现），却只能造更好的那个"). Now the armour is the vest's next step, at the difference.
static func next_in_slot(recipe_id: String, owned: Dictionary) -> bool:
	var row: Dictionary = RECIPES.get(recipe_id, {})
	var slot: String = String(row.get("slot", ""))
	if row.is_empty() or slot == "":
		return true
	var held: String = String(kit(owned).get(slot, ""))
	var held_tier: int = int(RECIPES[held].get("tier", 1)) if held != "" else 0
	var next_tier: int = -1
	for other in RECIPES:
		var tier: int = int(RECIPES[other].get("tier", 1))
		if String(RECIPES[other].get("slot", "")) == slot and tier > held_tier and (next_tier < 0 or tier < next_tier):
			next_tier = tier
	return int(row.get("tier", 1)) == next_tier

## What `recipe_id` costs, with `owned` made: in his row, the difference from the one it takes the place
## of -- the bone armour over the vest is the bone sewn onto it, the stone pick over the bone one its
## stone head -- never less than nothing; out of the row, or first in its slot, its whole price. So the
## two steps together cost what the better one always did.
static func recipe_price(recipe_id: String, owned: Dictionary) -> Dictionary:
	var row: Dictionary = RECIPES.get(recipe_id, {})
	var want: Dictionary = row.get("inputs", {})
	var slot: String = String(row.get("slot", ""))
	var held: String = String(kit(owned).get(slot, "")) if slot != "" else ""
	if held == "" or held == recipe_id:
		return want
	var have: Dictionary = RECIPES[held].get("inputs", {})
	var out: Dictionary = {}
	for res_id in want:
		var more: int = int(want[res_id]) - int(have.get(res_id, 0))
		if more > 0:
			out[res_id] = more
	return out

## Whether a better one than `recipe_id` of its slot is held already -- so the bench does not
## offer it (CraftingStation).
static func outclassed(recipe_id: String, owned: Dictionary) -> bool:
	var row: Dictionary = RECIPES.get(recipe_id, {})
	var slot: String = String(row.get("slot", ""))
	if slot == "":
		return false
	var held: String = String(kit(owned).get(slot, ""))
	return held != "" and int(RECIPES[held].get("tier", 1)) >= int(row.get("tier", 1))

## What his row adds to him: armour's hit points over his own ("max_hp", summed) and how much
## faster he walks and harder he hits ("move_speed", "damage", multiplied).
static func kit_bonus(owned: Dictionary, effect: String) -> float:
	var summed: bool = effect == "max_hp"
	var total: float = 0.0 if summed else 1.0
	for recipe_id in kit(owned).values():
		var v: float = float(RECIPES[recipe_id].get(effect, 0.0 if summed else 1.0))
		total = total + v if summed else total * v
	return total

## Stations in the order they stand in the cabin.
const STATIONS: Array[String] = ["workbench", "kitchen", "beacon"]

## The bench the beacon is repaired and launched at. A bench of its own, rather than a few
## more recipes on the workbench, because it is the run's main line (GAME-DESIGN 8.3) and
## not one more tool: its steps come from the run's map, one at a time and in order, and
## what finishing them does is bring the end of the run -- not set a flag.
const BEACON_STATION: String = "beacon"
## The beacon's last step, after every repair stage: switching it on.
const BEACON_LAUNCH: String = "beacon_launch"

## The beacon's steps on `map`, in order: one per repair stage ("beacon_1", "beacon_2",
## ...), then the launch. Empty for a map without a beacon.
static func beacon_jobs(map: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var stages: Array = map.get("beacon", {}).get("stages", [])
	if stages.is_empty():
		return out
	for i in range(stages.size()):
		out.append("beacon_%d" % (i + 1))
	out.append(BEACON_LAUNCH)
	return out

## One of the beacon's steps as a bench job, in a recipe's shape -- station, inputs, time,
## name -- which is what lets the cabin's one kind of bench work it; `name_args` fill the
## name in ("Repair the beacon (2/3)"). Empty for anything that is not a step on `map`.
## The launch costs nothing and takes no time: the price was the stages, and the decision
## is the player's.
static func beacon_job(map: Dictionary, job_id: String) -> Dictionary:
	var jobs: Array[String] = beacon_jobs(map)
	var i: int = jobs.find(job_id)
	if i < 0:
		return {}
	if job_id == BEACON_LAUNCH:
		return {"station": BEACON_STATION, "inputs": {}, "time": 0.0, "name": "BEACON_LAUNCH_NAME", "name_args": []}
	var stage: Dictionary = map["beacon"]["stages"][i]
	return {
		"station": BEACON_STATION,
		"inputs": stage.get("inputs", {}),
		"time": float(stage.get("time", 0.0)),
		"name": "BEACON_STAGE_NAME",
		"name_args": [i + 1, jobs.size() - 1],
	}

## Where the beacon on `map` has got to, in words: how many stages stand repaired and what
## the next one takes, that it is ready to launch, or how far it has charged and how long is
## left. The top of the screen and the beacon's bench both say this, and say it the same
## way -- the run's goal and the next step towards it (GAME-DESIGN 14.2, paths 3 and 6).
## "" for a map without a beacon.
static func beacon_status(map: Dictionary, steps_done: int, charged: float) -> String:
	var jobs: Array[String] = beacon_jobs(map)
	if jobs.is_empty():
		return ""
	var stages: int = jobs.size() - 1
	if steps_done < stages:
		var price: PackedStringArray = []
		var inputs: Dictionary = beacon_job(map, jobs[steps_done]).get("inputs", {})
		for res_id in inputs:
			price.append("%d %s" % [int(inputs[res_id]), TranslationServer.translate("RESOURCE_%s" % String(res_id).to_upper())])
		return TranslationServer.translate("BEACON_STATUS_REPAIRING") % [steps_done, stages, ", ".join(price)]
	if steps_done == stages:
		return TranslationServer.translate("BEACON_STATUS_READY")
	var total: float = float(map["beacon"].get("charge_seconds", 0.0))
	var left: int = int(ceil(maxf(0.0, total - charged)))
	var percent: int = int(floor(clampf(charged / total, 0.0, 1.0) * 100.0)) if total > 0.0 else 100
	return TranslationServer.translate("BEACON_STATUS_CHARGING") % [percent, left / 60, left % 60]

## Recipes belonging to one station, in declaration order.
static func recipes_at(station_id: String) -> Array[String]:
	var out: Array[String] = []
	for recipe_id in RECIPES:
		if String(RECIPES[recipe_id].get("station", "")) == station_id:
			out.append(String(recipe_id))
	return out

## How much faster the tools in `owned` (unlock flags, as GameState.unlocks holds them)
## bring `res_id` in: the product of every held tool's `harvest_speed` for it.
static func harvest_speed(res_id: String, owned: Dictionary) -> float:
	var factor: float = 1.0
	for recipe_id in RECIPES:
		if counts(String(recipe_id), owned):
			factor *= float(RECIPES[recipe_id].get("harvest_speed", {}).get(res_id, 1.0))
	return factor

## The held tools that speed up `res_id`, by recipe: what to name when saying why a
## stroke brought in more than one.
static func harvest_tools(res_id: String, owned: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for recipe_id in RECIPES:
		var data: Dictionary = RECIPES[recipe_id]
		if counts(String(recipe_id), owned) and float(data.get("harvest_speed", {}).get(res_id, 1.0)) != 1.0:
			out.append(String(recipe_id))
	return out

## Why a stroke on `res_id` brings in more than one, in words -- the tools doing it and
## the factor they make together, "Stone Axe x2" -- or "" when it is bare hands.
static func harvest_note(res_id: String, owned: Dictionary) -> String:
	var tools: Array[String] = harvest_tools(res_id, owned)
	if tools.is_empty():
		return ""
	var names: PackedStringArray = []
	for recipe_id in tools:
		names.append(TranslationServer.translate(String(RECIPES[recipe_id].get("name", recipe_id))))
	return TranslationServer.translate("HARVEST_NOTE") % [" + ".join(names), factor_text(harvest_speed(res_id, owned))]

# ==============================================================================
# 14a. Cooking (v0.6) -- the kitchen feeds him, and a fed man works faster
# ==============================================================================
## A meal is a piece of meat, cooked at the kitchen and eaten there and then: no bag, no
## stored food (GAME-DESIGN 4.5). Two tables, one rule -- THE VESSEL DECIDES WHAT A MEAL
## DOES, THE MEAT DECIDES HOW MUCH:
##   DISHES          -- one per kind of meat: its price, its cooking time, and how big each
##                      effect it CAN have is.
##   COOKING_METHODS -- one per vessel, best first: which of those effects a meal HAS.
## So a better pot is a new kind of meal -- roasted, meat only heals; seared on a stone pot,
## he also builds faster for a while -- and a better cut is a bigger one of the same kind.
## The player only chooses which meat; the method is whatever his best pot allows.
##
## Eating heals him at once. A meal with a speed effect also leaves him FED for a while
## (GameState.fed): one meal at a time, the new one replacing the last.
##
## Meat cannot be only healing (GAME-DESIGN 4.5): once every building is up, a raid's meat
## still has somewhere to go -- a fed man builds and mends faster.
const DISHES: Dictionary = {
	# What a raptor leaves. A little of everything.
	"meat": {
		"name": "DISH_MEAT_NAME",
		# Drawn cooked -- browned, barred, steaming -- and never as what goes in: with the raw
		# meat's own icon on the meals, what he carries and what he eats looked the same (v0.6 round
		# four: "掉落的raw meat和roast meat图标要区分开现在有点confusing").
		"icon": "roast",
		"station": "kitchen",
		"inputs": {"food": 1},
		"time": 5.0,
		"heal": 4.0,               # of the Hero's 10
		"max_hp": 2.0,             # hit points over his own while he is fed, full when he eats
		"build_speed": 1.3,
		"fed_seconds": 90.0,       # about a raid's gap: fed on the way out, hungry by the next
	},
	# What a boss leaves (GAME-DESIGN 7.5), and the reward for having killed it: every effect
	# clearly bigger, and for longer. A full heal.
	"prime_meat": {
		"name": "DISH_PRIME_MEAT_NAME",
		"icon": "roast_prime",
		"station": "kitchen",
		"inputs": {"prime_meat": 1},
		"time": 5.0,
		"heal": 10.0,
		"max_hp": 4.0,
		"build_speed": 1.8,
		"fed_seconds": 150.0,
	},
}

## Best first: a meal is cooked by the first method whose vessel he owns, and the last one
## needs none, so there is always a way to eat. Each better vessel ADDS an effect to the
## method below it -- that is the "qualitative" step a pot is (GAME-DESIGN 4.5).
##
## v0.6 round two ("肉的作用非常不明显……吃了饭之后会有一个 boost"): even a roast is a boost, not only a
## heal, so the first meal of a run is felt before there is a pot. v0.6 round three: his stride is
## his boots' now (RECIPES hide_boots) -- a meal heals him, and a fed man works faster; the pot
## heals more (`heal_factor`) and holds him up with hit points over his own for a while. Food is
## the only thing that heals him: the kitchen is his infirmary.
const COOKING_METHODS: Array = [
	# Seared on a flat stone heated in the fire: all a roast does, half as much healing again,
	# and hit points over his own while he is fed.
	{"id": "sear", "name": "COOK_SEAR", "vessel": "stone_pot", "effects": ["heal", "max_hp", "build_speed"], "heal_factor": 1.5},
	# Over the fire on a stick, the way he ate the first night: it heals, and he works the
	# quicker for it.
	{"id": "roast", "name": "COOK_ROAST", "vessel": "", "effects": ["heal", "build_speed"]},
]

## EATING (v0.6 round two: "吃饭的逻辑要彻底改一下……吃饭也是一个图标，点进去呢就有吃的东西"). The kitchen
## cooks a meal into his stock (GameState.meals); he eats it from his panel whenever the player
## says, wherever he is (Hero.order_eat) -- standing, the meat in his hand, for `eat_seconds`.
const EATING: Dictionary = {
	# How long a meal takes, in seconds: long enough to be seen and to cost something with a
	# raid on the way, short enough to fit between two jobs.
	"eat_seconds": 2.5,
	# The meat in his hand while he eats, in metres across: a leg, not a pile.
	"prop_size": 0.24,
	# The bone of his rig the meat is held in (tools/build_hero.py: the right hand goes to his
	# mouth in the "eat" clip).
	"prop_bone": "hand_r",
	# How far out from his middle the ring at his feet is while he is fed, in metres: something
	# to see him by that says "fed" without a word. In the boost's colour (THEME.colors.boost).
	"aura_radius": 0.55,
}

## Dishes cooked at one station, in declaration order.
static func dishes_at(station_id: String) -> Array[String]:
	var out: Array[String] = []
	for dish_id in DISHES:
		if String(DISHES[dish_id].get("station", "")) == station_id:
			out.append(String(dish_id))
	return out

## The method a meal is cooked by: the best one whose vessel is among `owned`.
static func cooking_method(owned: Dictionary) -> Dictionary:
	for method in COOKING_METHODS:
		var vessel: String = String(method.get("vessel", ""))
		if vessel == "" or owned.has(vessel):
			return method
	return {}

## What eating `dish_id` does when cooked the best way `owned` allows:
##   {"dish", "method", "heal", "build_speed", "move_speed", "fed_seconds"}
## An effect the method does not have is left at nothing -- no heal, a speed of 1.0 -- and a
## meal with neither speed leaves nobody fed (fed_seconds 0). Empty for an unknown dish.
static func meal_of(dish_id: String, owned: Dictionary) -> Dictionary:
	if not DISHES.has(dish_id):
		return {}
	var dish: Dictionary = DISHES[dish_id]
	var method: Dictionary = cooking_method(owned)
	var effects: Array = method.get("effects", [])
	return meal_cooked(dish_id, String(method.get("id", "")))

## What eating `dish_id` cooked by `method_id` does (COOKING_METHODS), whatever pots he owns
## now: a meal in his stock was cooked the way it was cooked. The same shape as meal_of.
static func meal_cooked(dish_id: String, method_id: String) -> Dictionary:
	if not DISHES.has(dish_id):
		return {}
	var dish: Dictionary = DISHES[dish_id]
	var method: Dictionary = {}
	for m in COOKING_METHODS:
		if String(m.get("id", "")) == method_id:
			method = m
	var effects: Array = method.get("effects", [])
	var meal: Dictionary = {
		"dish": dish_id,
		"method": method_id,
		"heal": float(dish.get("heal", 0.0)) * float(method.get("heal_factor", 1.0)) if effects.has("heal") else 0.0,
		"max_hp": float(dish.get("max_hp", 0.0)) if effects.has("max_hp") else 0.0,
		"build_speed": float(dish.get("build_speed", 1.0)) if effects.has("build_speed") else 1.0,
		"move_speed": float(dish.get("move_speed", 1.0)) if effects.has("move_speed") else 1.0,
	}
	var lasting: bool = meal["build_speed"] != 1.0 or meal["move_speed"] != 1.0 or meal["max_hp"] > 0.0
	meal["fed_seconds"] = float(dish.get("fed_seconds", 0.0)) if lasting else 0.0
	return meal

## The icon a dish is drawn with, cooked (DISHES.<id>.icon) -- or, for one with none, what it is
## cooked from.
static func dish_icon(dish_id: String) -> String:
	var dish: Dictionary = DISHES.get(dish_id, {})
	if dish.has("icon"):
		return String(dish["icon"])
	var inputs: Dictionary = dish.get("inputs", {})
	return String(inputs.keys()[0]) if not inputs.is_empty() else dish_id

## The most any meal does to `effect` ("build_speed", "move_speed", "max_hp"): where the panel's
## bars end, so the best meal in the game fills one and an ordinary one visibly does not.
static func best_meal(effect: String) -> float:
	var best: float = 1.0 if effect.ends_with("_speed") else 0.0
	for dish_id in DISHES:
		best = maxf(best, float(DISHES[dish_id].get(effect, best)))
	return best

## A meal's effects in words -- "heals 4 · builds x1.3 · for 90s" -- for the kitchen's
## menu, and (with_heal false) for the top bar, which only says what he is still living on:
## the heal was spent when he ate. Takes a meal (meal_of) or GameState.fed.
static func describe_meal(meal: Dictionary, with_heal: bool = true) -> String:
	var parts: PackedStringArray = []
	if with_heal and float(meal.get("heal", 0.0)) > 0.0:
		parts.append(TranslationServer.translate("EFFECT_HEAL") % int(round(float(meal["heal"]))))
	if float(meal.get("max_hp", 0.0)) > 0.0:
		parts.append(TranslationServer.translate("EFFECT_MAX_HP") % int(round(float(meal["max_hp"]))))
	if float(meal.get("build_speed", 1.0)) != 1.0:
		parts.append(TranslationServer.translate("EFFECT_BUILD_SPEED") % factor_text(float(meal["build_speed"])))
	if float(meal.get("move_speed", 1.0)) != 1.0:
		parts.append(TranslationServer.translate("EFFECT_MOVE_SPEED") % factor_text(float(meal["move_speed"])))
	if with_heal and float(meal.get("fed_seconds", 0.0)) > 0.0:
		parts.append(TranslationServer.translate("EFFECT_FED_FOR") % int(round(float(meal["fed_seconds"]))))
	return " · ".join(parts)

## A speed factor as the player reads it: "2" for a whole one, "1.3" otherwise.
static func factor_text(f: float) -> String:
	return ("%d" % int(round(f))) if is_equal_approx(f, round(f)) else ("%.1f" % f)

## Construction time is a function of price: the more a building costs, the longer
## the Hero stands there making it. Keeping it derived means a designer tunes one
## number (cost) instead of two that can drift apart.
##   wooden stakes (1 wood)  -> 1.0s (the floor)
##   lumber hut   (12 wood)  -> 12.3s
## Superlinear on purpose: at a flat rate per resource the gap between a cheap and
## an expensive building is barely noticeable, and setting a crossbow on its plinth should
## feel like work next to hammering in a stake.
##   time = max(BUILD_TIME_MIN, total_cost ^ BUILD_TIME_EXPONENT * BUILD_SECONDS_PER_RESOURCE)
const BUILD_SECONDS_PER_RESOURCE: float = 0.55
const BUILD_TIME_EXPONENT: float = 1.25
const BUILD_TIME_MIN: float = 1.0

## Seconds the Hero must spend to raise `type_id`. Free buildings (the cabin, which
## the level spawns rather than the player) take no time at all.
static func get_build_time(type_id: String) -> float:
	if not BUILDINGS.has(type_id):
		return BUILD_TIME_MIN
	var cost: Dictionary = BUILDINGS[type_id].get("cost", {})
	var total: float = 0.0
	for res_id in cost:
		total += float(cost[res_id])
	if total <= 0.0:
		return 0.0
	return maxf(BUILD_TIME_MIN, pow(total, BUILD_TIME_EXPONENT) * BUILD_SECONDS_PER_RESOURCE)

## Helper returning localized display name for any building type.
static func get_building_name(type_id: String) -> String:
	if BUILDINGS.has(type_id):
		var raw_key = BUILDINGS[type_id].get("name", type_id)
		return TranslationServer.translate(raw_key)
	return TranslationServer.translate(type_id)

## Helper returning localized display name for any dinosaur type.
static func get_dino_name(type_id: String) -> String:
	if DINOS.has(type_id):
		var raw_key = DINOS[type_id].get("name", type_id)
		return TranslationServer.translate(raw_key)
	return TranslationServer.translate(type_id)

# ==============================================================================
# 14b. Terrain shape (v0.5)
# ==============================================================================

## The land the level sits in.
##
## The ground used to be a 40x40 plane, and the camera could see its edge -- past that
## line was nothing at all. That one fact did more damage to "this is a place" than
## every placeholder box put together, and no amount of fog fixes a world that visibly
## stops.
##
## So the level stands in open country. `field_half` is flat and exactly level, because
## everything in this game lives on a grid at y = 0 and ground that undulated under the
## buildings would stand them in the air or bury them. Past it a plain runs on towards the
## horizon, and far out a ring of mountains -- softened by the haze -- stands in front of
## the end of the ground. The edge of what can be played on is marked the way land marks
## it: the river, the forest, the rocks.
##
## It was a bowl, the ground climbing a few metres past the field and curling up all round
## it -- reported as "地图到边界还是卷曲上翘的". Level ground and separate mountains on the
## skyline is what strategy games do.
const TERRAIN: Dictionary = {
	# Half the square the game is played on: the ground collider, and what the camera and
	# the scenery are measured from. The nest sits at z = -9 cells = -18m, so 22 leaves
	# margin. Shrinking this without checking the map would put a slope under a building.
	"field_half": 22.0,
	# The valley floor is flat that much further out all round, with its corners rounded
	# off (TerrainBuilder.past_the_flat). It was a circle as wide as the square, so the
	# wall started climbing inside the square's corners, and the edge of the field curled
	# up under anything built there.
	"flat_apron": 3.0,
	"flat_corner": 5.0,
	# Total ground extent. Far past what the fixed camera can frame, and behind the
	# mountains, which stand in front of it: there is no edge to find.
	"outskirts_half": 110.0,
	# The plain: level, with a slow swell in it (metres either way) so it is land rather
	# than a floor, eased in over `plain_blend` metres past the flat.
	"plain_swell": 0.8,
	"plain_blend": 12.0,
	# The mountains: a ring round the whole valley, from `mountains_from` metres out (a
	# long way past the field; the haze starts at 45) climbing `mountains_rise` metres
	# over `mountains_span`, the crest broken into peaks and saddles (`mountains_ridge`,
	# as a share of the height either way) and the faces roughened (`mountains_rock`).
	# Kept low enough that the volcanoes stand clear above them from the field.
	"mountains_from": 72.0,
	"mountains_span": 26.0,
	"mountains_rise": 18.0,
	"mountains_ridge": 0.35,
	"mountains_rock": 2.0,
	"quad_size": 4.0,          # ground mesh resolution in metres
	"noise_seed": 20260917,    # fixed, so the same landscape comes back every launch
	"noise_frequency": 0.018,
	# Hills: how finely each cell is subdivided, and how much rubble is added on top.
	# The rubble is scaled by height so it never lifts a hill off the ground or pokes
	# through the edge it shares with the hill next door.
	"hill_subdivisions": 6,
	"hill_noise": 0.12,
	# Ground colour is blended by slope: flat reads as grass, steep as rock. Without it
	# the mountains are exactly the same green as the field and the whole view reads as
	# an endless lawn. `rock_slope` is the gradient at which the blend reaches full rock.
	"rock_slope": 0.55,
	"ground_mottle": 0.07,     # slow variation so the floor is not one flat wash
	# Surface detail. The mottle above is a 50-metre wavelength -- it stops the ground
	# being one flat colour from the air, and is far too broad to read as soil from the
	# game's camera. `detail_scale` is the fine grain laid on top with a triplanar noise
	# texture, in metres per repeat: this is what turns "a green surface" into "dirt".
	"detail_scale": 2.4,
	"detail_strength": 0.35,   # how far the grain pushes the colour
	"detail_bumpiness": 0.85,  # normal map depth, so low sun rakes across it
	# How far past the flat field the ground cover keeps going before it thins out. It
	# has to reach well into the valley wall: cover that stopped at the field edge drew a
	# hard green line across the ground, which is the very boundary the valley exists to
	# get rid of.
	"cover_reach": 34.0,
	# The river (scripts/fx/River.gd). It comes over the north-west rim and down the wall as
	# white water, winds along the valley floor just outside the field -- closest at the
	# water spot, where the Hero draws water -- and leaves through a canyon in the
	# south-west wall that bends away behind the rim, so the end of the world is never at
	# the end of it. Both ends run off the ground where nobody can see them.
	#
	# Scenery: the channel is cut into the ground outside the square the game is played on
	# and never reaches it, and nothing of it collides.
	#
	# `course` is (x, z) in metres, upstream first. `half_width` is half the width of the
	# water; `bank` how steeply the banks rise, metres up per metre across -- gentle on the
	# valley floor, steep where it cuts down the wall, near sheer in the canyon. The water
	# level is not given anywhere: it is worked out from the ground (River.gd).
	"river": {
		"course": [
			# On the plateau behind the rim, out of sight.
			{"at": Vector2(-112.0, -78.0), "half_width": 1.1, "bank": 1.2},
			{"at": Vector2(-88.0, -74.0), "half_width": 1.1, "bank": 1.2},
			{"at": Vector2(-66.0, -68.0), "half_width": 1.1, "bank": 1.2},
			{"at": Vector2(-50.0, -60.0), "half_width": 1.1, "bank": 1.3},
			# Over the rim and down the wall: narrower where it falls, as a stream does.
			{"at": Vector2(-40.0, -50.0), "half_width": 1.0, "bank": 1.4},
			{"at": Vector2(-34.0, -40.0), "half_width": 1.1, "bank": 1.3},
			{"at": Vector2(-30.0, -31.0), "half_width": 1.5, "bank": 1.1},
			# Along the valley floor, past the field's west edge.
			{"at": Vector2(-27.5, -22.0), "half_width": 2.0, "bank": 0.9},
			{"at": Vector2(-25.8, -12.0), "half_width": 2.1, "bank": 1.0},
			{"at": Vector2(-25.3, -6.0), "half_width": 2.1, "bank": 1.1},
			{"at": Vector2(-26.0, 1.0), "half_width": 2.2, "bank": 0.9},
			{"at": Vector2(-28.0, 8.0), "half_width": 2.3, "bank": 0.8},
			# Into the canyon, and round behind the rim.
			{"at": Vector2(-31.0, 14.0), "half_width": 2.3, "bank": 1.0},
			{"at": Vector2(-36.0, 19.0), "half_width": 2.2, "bank": 1.6},
			{"at": Vector2(-43.0, 23.0), "half_width": 2.1, "bank": 2.4},
			{"at": Vector2(-52.0, 26.0), "half_width": 2.0, "bank": 2.8},
			{"at": Vector2(-60.0, 30.0), "half_width": 2.0, "bank": 2.8},
			{"at": Vector2(-65.0, 38.0), "half_width": 2.0, "bank": 2.6},
			{"at": Vector2(-67.0, 50.0), "half_width": 2.0, "bank": 2.4},
			{"at": Vector2(-68.0, 70.0), "half_width": 2.0, "bank": 2.0},
			{"at": Vector2(-70.0, 95.0), "half_width": 2.0, "bank": 1.8},
			{"at": Vector2(-71.0, 114.0), "half_width": 2.0, "bank": 1.8},
		],
		"seed": 5,
		"margin": 0.35,          # the surface lies this far below the lower of its two banks
		"fall": 0.002,           # and drops at least this much a metre, so there is a current
		"roughness": 0.3,        # how broken up the banks are: the canyon's buttresses and bays
		"roughness_scale": 0.12,
		"overhang": 0.8,         # how far the water runs in under each bank
		# The ground under the water, and the wet band up the bank (sRGB, like COLORS).
		"silt": Color(0.16, 0.14, 0.10),
		"mud": Color(0.26, 0.22, 0.15),
		"wet_band": 0.6,
		"water": {
			# Jungle river green, not swimming-pool blue: the bed shows through where it is
			# shallow. Alpha is how much of the bed it hides.
			"colour": Color(0.10, 0.20, 0.18, 0.86),
			# Churned water, not snow: pale green-grey, and never all of it -- it comes in
			# streaks down the middle, with dark water showing at the edges and between.
			# Solid white read as a road down the valley wall.
			"foam": Color(0.60, 0.68, 0.64, 0.92),
			"foam_from": 0.05,       # fall (m per m) where white water starts...
			"foam_full": 0.35,       # ...and where it is as white as it gets
			"hurry": 10.0,           # how much faster it runs per unit of fall
			"roughness": 0.07,
			"specular": 0.6,
			"ripple_size": 5.0,      # metres per repeat of the ripple texture
			"ripple_depth": 0.55,
			"ripple_bump": 6.0,
			"speed": 0.6,            # m/s where it is calm
			"shore_fade": 0.5,       # metres over which it fades out against the bank
		},
		# Horsetails along both banks, some standing in the shallows, and boulders in the
		# white water (tools/generate_flora.py, tools/generate_props.py).
		"reeds": ["res://assets/models/flora/horsetail_a.glb", "res://assets/models/flora/horsetail_b.glb"],
		"reed_count": 180,       # per variant
		"reed_from": -0.35,      # metres from the water's edge: a little way into the water...
		"reed_to": 1.8,          # ...to a little way up the bank
		"boulders": "res://assets/models/props/outcrop_a.glb",
		"boulder_count": 40,
		"boulder_scale": Vector2(0.45, 0.95),
		# The stepping stones from the water spot down the bank to the water.
		"landing_stones": 3,
	},
}

## Plant-eaters grazing on the lower valley walls (scripts/fx/Herds.gd).
##
## Scenery: no collider, no group, not on the grid, and out past the field where nobody
## walks, so no raid, turret or order ever sees them. `length` puts every species on one
## scale, with the map's boss as the ruler (Postosuchus, about 4.7 m nose to tail --
## DINOS.postosuchus): a Placerias about three quarters of one, as it was. Every animal keeps
## its whole body off the field and the flat apron round it. `bearing` is on the camera rig's
## compass, like the volcanoes'.
const HERDS: Dictionary = {
	"seed": 4417,
	"herds": [
		# The Late Triassic's grazers (GAME-DESIGN 7.2, station 1; v0.6 round three): Placerias,
		# a tusked, beaked dicynodont about three and a half metres long, in herds
		# (tools/generate_triassic.py). The sauropods, hadrosaurs, ceratopsians and stegosaurs that
		# grazed here belong to later maps. On the far bank of the river, across from the water
		# spot; and up the valley's two sides.
		{"species": "placerias", "scene": "res://assets/models/triassic/placerias.glb",
			"count": 6, "length": 3.5, "bearing": 84.0, "distance": 42.0, "spread": 6.0, "speed": 0.6},
		{"species": "placerias", "scene": "res://assets/models/triassic/placerias.glb",
			"count": 4, "length": 3.5, "bearing": 290.0, "distance": 42.0, "spread": 5.0, "speed": 0.6},
		{"species": "placerias", "scene": "res://assets/models/triassic/placerias.glb",
			"count": 4, "length": 3.5, "bearing": 20.0, "distance": 42.0, "spread": 5.0, "speed": 0.6},
	],
	"wander_radius": 4.0,            # how far an animal ambles from where it grazes (m)
	"graze_time": Vector2(5.0, 12.0),  # seconds between ambles
}

## The volcanoes on the skyline, and their smoke.
##
## The one silhouette that says "the age of dinosaurs" before anything moves, and the
## first thing the brief listed under landform (VERSION.md: 火山、河流、峭壁). Scenery at the
## far end of what the camera can see -- nothing here collides, is on the grid, or is
## anywhere a raid or the Hero could reach (scripts/fx/Volcano.gd).
##
## `bearing` is on the camera rig's own compass: the yaw at which the view looks straight
## at it, so every number here can be checked by turning the camera. 0 looks north (-z);
## the opening camera looks along about 68.
const VOLCANOES: Dictionary = {
	"cones": [
		# The big one, near where the opening camera looks: tilt the view up and it is there.
		{"bearing": 58.0, "distance": 270.0, "height": 92.0, "radius": 185.0, "crater": 15.0, "seed": 11, "breach": 130.0},
		# A smaller, further one to the north, so the skyline has depth rather than one landmark.
		{"bearing": 12.0, "distance": 360.0, "height": 70.0, "radius": 150.0, "crater": 11.0, "seed": 23, "breach": 250.0},
	],
	# Where the foot stands. Below the valley floor, so the foot is always behind the rim
	# and the cone rises out of the land beyond it rather than sitting on a plate.
	"base_y": -14.0,
	"rings": 26,               # from the crater lip to the foot
	"segments": 72,
	# > 1: flanks that steepen towards the top, the way a stratovolcano's do. A straight
	# cone reads as a traffic cone at any distance -- and only the top half ever shows
	# over the valley rim, so at 1.8 what showed was near enough a pyramid.
	"profile_power": 2.4,
	"crater_depth": 0.09,      # as a share of the height
	# Where one side of the crater has fallen away (each cone's `breach` is the direction,
	# in degrees round its own centre). What turns a symmetrical cone into a volcano.
	"breach_depth": 0.07,      # as a share of the height
	"breach_width": 55.0,      # degrees
	"gullies": 13,             # radial gullies down the flanks, where the ash runs off
	"gully_depth": 0.05,       # as a share of the height
	"roughness": 0.05,         # low, broad unevenness, as a share of the height
	# Colours, sRGB, by height: forest on the lower flanks, ash above, dark rock at the top,
	# scorched inside the crater. Darker than they would be close to: at this distance the
	# haze adds more than half its own colour, and at the first try the cone was a pale
	# ghost of the sky behind it.
	"forest": Color(0.09, 0.14, 0.06),
	"ash": Color(0.24, 0.22, 0.20),
	"summit": Color(0.14, 0.13, 0.12),
	"scorched": Color(0.24, 0.12, 0.07),
	"treeline": 0.42,          # share of the flank, from the foot, that is still green
	"smoke": {
		"amount": 90,
		"lifetime": 50.0,
		"speed": 2.6,             # m/s out of the crater
		"slowing": 0.02,          # m/s² -- the plume slows as it rises and spreads
		"spread": 7.0,            # degrees either side of straight up
		# The wind, as a steady push sideways (m/s²): the plume rises straight out of the
		# crater and then bends over as it climbs. A fixed lean drew a straight stick.
		"wind": Vector3(0.055, 0.0, 0.02),
		"size_min": 26.0,         # metres, fully grown
		"size_max": 52.0,
		"start_scale": 0.45,      # how small a puff is when it leaves the crater
		# Dark ash at the vent, paler and thinner as it rises. Darker than the sky by a
		# long way on purpose: the haze lifts it most of the way to the sky's own colour,
		# and a plume the brightness of the sky behind it is not there at all.
		"colour": Color(0.17, 0.16, 0.15, 0.9),
		"colour_high": Color(0.40, 0.39, 0.37, 0.55),
	},
}

## What grows on the flat field.
##
## Fixing the landform -- no visible edge, hills with a shape -- still left the ground
## reading as a painted surface, because it was one. Ground looks like ground when it is
## COVERED IN THINGS. This is that, and it is the difference between a diorama base and
## a place.
##
## None of it collides and none of it is on the grid: it is scenery the Hero walks
## straight through, and no tuft ever decides whether a stake can be planted. Cover that
## blocked something would be the same old lie wearing a new costume.
##
## Densities are counts over the whole flat field, tuned by looking at it. Grass is the
## one that has to be generous -- sparse grass reads as bald ground with weeds on it.
const GROUND_COVER: Dictionary = {
	"seed": 7723,
	# Nothing is scattered within this of a cell the level claimed, so the cabin, the
	# nest and the resource nodes are not standing in a bush.
	"clear_radius": 2.2,
	# Grass is thinned to a low sedge between the ferns rather than removed. Grasses were
	# barely a thing before the very end of the Cretaceous, so a meadow of them is the one
	# unmistakably MODERN element a dinosaur valley can have -- but bare soil between the
	# ferns reads as unfinished, and a short sparse sedge is what fills the gaps.
	"grass_count": 2600,
	"grass_height": 0.22,
	"grass_width": 0.05,
	"grass_blades": 7,
	"grass_base": Color(0.12, 0.22, 0.08),
	"grass_tip": Color(0.36, 0.52, 0.18),
	# Ferns: bigger, sparser, and the thing that makes the meadow read as prehistoric
	# rather than as a lawn. Before flowering plants, this is what ground cover was.
	"fern_count": 230,
	"fern_height": 0.62,
	"fern_fronds": 7,
	"fern_stem": Color(0.18, 0.25, 0.12),
	"fern_leaf": Color(0.33, 0.47, 0.20),
	# Far fewer: 1300 pale pebbles drew the eye everywhere and read as a gravel lot.
	"pebble_count": 260,
	"pebble_radius": 0.16,
	"pebble_color": Color(0.42, 0.40, 0.36),
	# Thinly: one here and there reads as old forest, a field of them as a lumber yard.
	"log_count": 22,
	"log_length": 3.2,
	"log_radius": 0.28,
	"log_bark": Color(0.27, 0.21, 0.15),
	"log_core": Color(0.47, 0.39, 0.28),
	# Real fallen trunks: bark, moss along the top, a fern growing out, one end splintered
	# and the other rotted hollow. The procedural log above is what stands in without them.
	"log_meshes": ["res://assets/models/props/fallen_log_a.glb", "res://assets/models/props/fallen_log_b.glb"],

	# THE JURASSIC FLORA, from tools/generate_flora.py.
	#
	# Inside the field only LOW cover -- ground ferns and horsetails, knee height at most.
	# Anything taller inside it would stand over the fight, would be walked through (none
	# of this collides), and would read as a tree to be chopped when it is not one.
	"flora_ground_ferns": ["res://assets/models/flora/ground_fern_a.glb",
		"res://assets/models/flora/ground_fern_b.glb", "res://assets/models/flora/ground_fern_c.glb"],
	"flora_ground_fern_count": 220,            # per variant
	"flora_horsetails": ["res://assets/models/flora/horsetail_a.glb",
		"res://assets/models/flora/horsetail_b.glb"],
	"flora_horsetail_count": 110,              # per variant

	# BEYOND the field: the forest edge and the valley walls, measured in metres past the
	# square the game is played on. Tree ferns and cycads crowd the edge; monkey-puzzles
	# stand further up the slopes, where their umbrellas make the skyline.
	"flora_edge_trees": ["res://assets/models/flora/tree_fern_a.glb",
		"res://assets/models/flora/tree_fern_b.glb", "res://assets/models/flora/tree_fern_c.glb",
		"res://assets/models/flora/cycad_a.glb", "res://assets/models/flora/cycad_b.glb"],
	"flora_edge_count": 40,                    # per variant
	"flora_edge_from": 3.0,
	"flora_edge_to": 22.0,
	"flora_skyline_trees": ["res://assets/models/flora/araucaria_a.glb",
		"res://assets/models/flora/araucaria_b.glb"],
	"flora_skyline_count": 34,                 # per variant
	"flora_skyline_from": 12.0,
	"flora_skyline_to": 46.0,
	# Tall plants dissolve inside this many metres of the camera, so a turned view is
	# never a screenful of trunk.
	"flora_fade_near": 11.0,
	# Cliffs: stretches of columnar basalt (tools/generate_props.py basalt_cliff) in a
	# broken band up the valley wall, among the trees, each turned to face into the
	# valley. Without them the wall was a smooth green bowl, and the brief asked for cliffs
	# by name (VERSION.md: 火山、河流、峭壁). The first try scaled the hills' crags up
	# instead, and a giant rounded crag reads as a boulder, not a cliff.
	# Scenery like everything here: no collision, not on the grid, nowhere anyone walks.
	"cliff_rocks": ["res://assets/models/props/basalt_cliff_a.glb",
		"res://assets/models/props/basalt_cliff_b.glb",
		"res://assets/models/props/basalt_cliff_c.glb"],
	"cliff_count": 14,                         # per variant; each is about 8 m along
	# Metres UP THE MOUNTAINS from their foot (TERRAIN.mountains_from), round the valley as
	# the mountains are: on the steep middle of the slope, where the mountainside climbs
	# well up each one's back and its face looks into the valley -- a band of rock in the
	# slope, its top always under the crest. Laid out in the field's square
	# band they stood on the level ground short of the slope, a row of columns reading as
	# a wall round the map, and at the square's corners up on the crest, against the sky.
	# On the gentle lower slopes they stood clear of the ground behind them, and through
	# the haze a cluster of flat-topped columns read as buildings.
	"cliff_from": 7.0,
	"cliff_to": 16.0,
	"cliff_scale": Vector2(0.9, 1.4),
	# How deep each is set in at its middle, in metres per unit of its scale -- and deeper
	# wherever the ground anywhere under it is lower (Main passes the mesh's bounds): its
	# front row stands downhill of its middle, and a fixed sink that set it into one slope
	# left it on stilts of daylight on a steeper one.
	"cliff_sink": 0.5,
	# How far a cliff keeps back from the top of the river's bank: a stretch is eight
	# metres long, and one stood on the bank hung its end out over the water.
	"cliff_river_clear": 4.0,
}

# ==============================================================================
# 15. Scene Environment & Lighting (v0.5)
# ==============================================================================

## Realistic PBR presentation environment.
##
## In a game with a fixed high-angle isometric camera, visual coherence is driven by
## light, shadow contact, atmospheric depth, and tonemapping rolloff rather than
## micro-level polygon counts. Models arriving in varied polygon densities still read
## as one cohesive world if the light and ground occlusion are right.
const ENVIRONMENT: Dictionary = {
	# Tonemapping: AgX provides photographic highlight compression, preventing hot
	# specular spots on dinosaur scales or bright stones from blowing out to chalk.
	"tonemap_mode": Environment.TONE_MAPPER_AGX,
	"tonemap_exposure": 1.0,
	"tonemap_white": 1.0,

	# Procedural Sky: a WARM, HUMID Mesozoic sky, not a cool modern noon.
	#
	# It was a subdued grey-blue zenith over a pale grey horizon, which is a perfectly good
	# overcast afternoon anywhere on Earth today -- and that was the problem. Nothing about
	# it said "a hundred million years ago". The Mesozoic was a greenhouse world: warmer,
	# wetter, with more water in the air, and the horizon of a humid valley glows gold
	# rather than going grey. The zenith stays blue so the sky still reads as a sky.
	"background_mode": Environment.BG_SKY,
	"sky_top_color": Color(0.28, 0.46, 0.62),       # deep, slightly teal zenith
	"sky_horizon_color": Color(0.84, 0.82, 0.70),   # humid, warm-white at the horizon
	"ground_bottom_color": Color(0.14, 0.15, 0.10), # dark, wet undergrowth bounce
	"ground_horizon_color": Color(0.52, 0.56, 0.44),
	"sun_angle_max": 30.0,
	"sun_curve": 0.15,

	# Ambient Lighting: Uses the procedural sky as the source so shadow sides receive
	# soft natural fill tinted by the sky, avoiding pitch-black cavities under trees and rocks.
	"ambient_source": Environment.AMBIENT_SOURCE_SKY,
	"ambient_color": Color(0.85, 0.90, 0.95),
	# 0.35 was a clear day's fill. This valley is humid and hazy, and a hazy sky throws a
	# lot of light into shadow: at 0.35 every crag seen against the sun was a black shape.
	"ambient_energy": 0.5,
	"ambient_sky_contribution": 0.55,

	# SSAO: Screen-space ambient occlusion is the single most cost-effective feature for
	# top-down view. It plants trees, walls, and dinosaur feet firmly onto the ground
	# plane without floating. Radius is 1.5m, scaled to the 2.0m tile size.
	"ssao_enabled": true,
	"ssao_radius": 1.5,
	"ssao_intensity": 1.8,
	"ssao_power": 1.5,
	"ssao_detail": 0.5,

	# Glow: Kept restrained (0.3 intensity, low bloom) to avoid the synthetic plastic
	# look of over-bloomed indie titles. Softens hot highlights naturally.
	"glow_enabled": true,
	"glow_intensity": 0.3,
	"glow_bloom": 0.08,
	"glow_blend_mode": Environment.GLOW_BLEND_MODE_SOFTLIGHT,

	# Atmospheric Fog: distance haze gives depth across the 40x40 map -- clear where the
	# fight is, thickening towards the border, so the map reads as an edge of somewhere
	# vast rather than as a 40 metre square.
	#
	# FOG_MODE_DEPTH, not EXPONENTIAL, and that choice is load-bearing. Exponential fog
	# has no start distance at all: it accumulates as 1 - exp(-distance * density) from
	# the camera outward, so it would sit on the units being looked at. The depth_begin /
	# depth_end ramp below only exists in FOG_MODE_DEPTH -- under EXPONENTIAL those three
	# numbers are simply ignored, which is what they were doing when this landed.
	#
	# THE TRAP, if this mode is ever changed again: the two modes read `fog_density`
	# completely differently. Here it is the MAXIMUM opacity the haze ever reaches (0.65
	# = the far corner is roughly two thirds hazed). Under EXPONENTIAL the same field is
	# a per-metre coefficient, where 0.65 would be an opaque white-out within a metre.
	# Changing the mode without re-tuning this number breaks the fog in one direction or
	# the other, silently.
	#
	# Distances are measured from the camera, which sits at (12, 18, 5). Measured rather
	# than guessed: the middle of the field is 22m away, its near corner 27m, and its FAR
	# CORNER 47m. Which is why the first numbers here were wrong -- a ramp starting at 26m
	# put haze across the far half of the playfield itself, and that flat grey wash was
	# most of why the whole scene read as low contrast.
	#
	# 45 -> 95 keeps every metre the game is played on clear, and spends the fog on the
	# valley walls beyond it, which is the only place it was ever meant to be.
	"fog_enabled": true,
	"fog_mode": Environment.FOG_MODE_DEPTH,
	# Humid haze is PALE: water in the air scatters nearly white, with a trace of the
	# green below it. Amber haze is dust, and dust is a desert -- measured, an amber fog
	# over this valley read as a savanna at sunset rather than a Jurassic forest.
	"fog_light_color": Color(0.76, 0.80, 0.74),
	"fog_light_energy": 0.85,
	"fog_density": 0.55,        # in DEPTH mode: the ceiling, not a per-metre rate
	"fog_aerial_perspective": 0.4,
	"fog_sky_affect": 0.35,
	"fog_depth_begin": 45.0,
	"fog_depth_end": 95.0,
	"fog_depth_curve": 1.0,     # linear ramp between begin and end; >1 holds it back longer

	# Directional Sun Light:
	# Matches the ancient daylight angle. Shadow bias and normal bias are tuned to eliminate
	# shadow acne on low-poly bevels while keeping tight shadow contact at feet and bases.
	# Max shadow distance is 48.0m to encompass the entire 40x40 ground plane from Camera3D.
	# Warm and a little low: late morning in a greenhouse world. A lower sun rakes across
	# the ground and throws the long shadows that give a tree fern or a dinosaur its SCALE
	# -- from a steep top-down camera, shadow length is most of how height is read at all.
	"sun_light_color": Color(1.0, 0.93, 0.80),
	"sun_light_energy": 1.4,
	"sun_elevation_degrees": 34.0,   # was 41: lower, longer shadows
	"sun_azimuth_degrees": 40.0,     # the same bearing, so nothing on the map flips sides
	"sun_volumetric_fog_energy": 1.6,
	"sun_shadow_enabled": true,
	"sun_shadow_bias": 0.03,
	"sun_shadow_normal_bias": 1.2,
	"sun_shadow_blur": 1.2,
	"sun_shadow_max_distance": 48.0,

	# Volumetric fog: the humid AIR, which distance fog cannot do. See SceneEnvironment.
	# Low density on purpose -- the playfield has to stay legible, and a little of this
	# goes a long way from a camera 25m off the ground. Forward-scattering (anisotropy) is
	# what makes the sun glow through it and draws shafts past the tree ferns.
	"volumetric_fog_enabled": true,
	# 0.009 washed the far side of the valley to a flat milky white from any low angle --
	# the forest thirty metres away lost its colour entirely. Haze, not a wall.
	"volumetric_fog_density": 0.0055,
	"volumetric_fog_albedo": Color(0.90, 0.94, 0.90),
	"volumetric_fog_anisotropy": 0.6,
	"volumetric_fog_length": 80.0,
	"volumetric_fog_detail_spread": 2.0,
	"volumetric_fog_ambient_inject": 0.25,
	"volumetric_fog_sky_affect": 0.5,

	# Grading: a touch more contrast and noticeably more saturation, so the greens read
	# as LUSH rather than as a lawn. The engine's own adjustment, not a post shader.
	"adjustment_enabled": true,
	"adjustment_brightness": 1.0,
	"adjustment_contrast": 1.07,
	"adjustment_saturation": 1.2,
}

# ==============================================================================
# 16. Animation State Machine Mappings (v0.5 S2)
# ==============================================================================

## Decouples entity logic states from asset clip names.
## Entities report their State enum to ActorAnimator, which reads this table to
## determine which clip to play. Swapping model packs changes clip strings here,
## never entity GDScript code.
const ANIMATIONS: Dictionary = {
	# Crossfade duration when transitioning between animation states.
	# 0.2s prevents jerky mechanical snaps while remaining responsive.
	"blend_time": 0.2,

	# The clips that go round and round for as long as the state lasts: walking, standing,
	# and the work and the fighting, which are done over and over. Everything else --
	# dying, a jump -- plays once and holds its last frame. Decided here, for every model,
	# rather than in each file's import settings: it is the game's rule, not the asset's,
	# and a clip that played once and froze mid-stride was what every model did before.
	"looping": ["idle", "walk", "run", "attack", "build", "harvest", "eat", "sleep"],

	# Hero states (corresponds to Hero.State enum keys)
	"hero": {
		"IDLE": "idle",
		"MOVING": "walk",
		"BUILDING": "build",
		"ATTACKING": "attack",
		"DEAD": "death",
		"HARVESTING": "harvest",
		# His hand to his mouth and down again (tools/build_hero.py author_eat).
		"EATING": "eat",
	},

	# Dinosaur states (corresponds to Dino.State enum keys)
	"dino": {
		"WALKING": "run",     # bipedal locomotion gait
		"ATTACKING": "attack", # bite / swipe
		"DEAD": "death",
		# Lying on its belly, legs folded, head on the ground, breathing (tools/generate_triassic.py
		# add_sleep: the Coelophysis's; a species without it goes on standing).
		"SLEEPING": "sleep",
	},

	# Travelling is drawn from the feet, not from the state (ActorAnimator.update_motion; v0.6
	# feedback: "人站着不动的时候还在走"). In a travelling state a walker whose smoothed pace is
	# under `still_speed` stands; over `moving_speed` it moves again -- apart, so easing to a
	# stop cannot flicker. Moving, it plays the gait drawn nearest its pace, sped up or slowed
	# to it within `pace_scale_range`.
	"travelling_states": ["MOVING", "WALKING"],
	# What each walker plays standing, whatever its state says.
	"standing": {"hero": "idle", "dino": "idle"},
	"still_speed": 0.15,
	"moving_speed": 0.35,
	"pace_smoothing": 10.0,       # how quickly the measured pace follows the feet, per second
	# A new gait only when it fits the pace better than the one it is in by this much (as the log of
	# the speeds' ratio: 0.2 is about a fifth): a pace just where a walk and a run meet, going up and
	# down in a crowd, was drawn walk, run, walk, a few frames each.
	"gait_hysteresis": 0.2,
	# And once taken, a gait is kept at least this long (seconds) -- about what an animal takes to
	# go from a walk to a run: two raiders going round the cabin's corner together, slowed and let
	# go by turns, still went walk, run, walk, run twice a second.
	"gait_hold": 1.0,
	"pace_scale_range": Vector2(0.6, 1.8),
	# Each walker's gaits: the clip, and the speed it is drawn at in metres a second at the
	# size it is shown. The Hero is 1.2 m: his walk covers about a metre a second and his jog
	# about three, so at his four he jogs, a little quick -- faster still when fed. A raptor's
	# run is drawn at its own four; a theropod at two walks, heavily.
	"gaits": {
		"hero": {"walk": 1.1, "run": 3.0},
		"dino": {"walk": 1.6, "run": 4.0},
	},

	# Common clip aliases across diverse CC0 / commercial asset packs:
	# E.g., if a pack names its walk cycle "run", or attack "bite", ActorAnimator
	# resolves against this list before falling back to static pose.
	"aliases": {
		"walk": ["run", "walking", "Walk", "Run", "Armature|Walk", "Armature|Run"],
		"run": ["walk", "Run", "Walk", "Armature|Run", "Armature|Walk"],
		"attack": ["bite", "Attack", "Bite", "Armature|Attack", "Armature|Bite"],
		"idle": ["Idle", "breathing", "Armature|Idle"],
		"death": ["die", "dead", "Death", "Die", "Armature|Death"],
		"build": ["craft", "hammer", "Build", "interact"],
		"harvest": ["chop", "mine", "Harvest", "attack"],
		"eat": ["Eat", "idle"],
	},
}
