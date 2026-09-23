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
##   bone  -- off a dead dinosaur; the workbench turns it into tools
##   food  -- off a dead dinosaur; the kitchen turns it into blueprints
##   water -- no sink yet (see the open question in VERSION.md's v0.4 section)
const RESOURCES: Array[String] = ["wood", "stone", "bone", "water", "food"]
## The player starts with nothing banked. The opening stock is real wood lying by
## the cabin (Config.DROPS.opening_stock) and has to be walked over like anything
## else -- the first thing the game teaches is that resources are carried, not
## granted. Keep these at zero: a number here is a second, silent way to get rich.
const INITIAL_RESOURCES: Dictionary = {
	"wood": 0,
	"stone": 0,
	"bone": 0,
	"water": 0,
	"food": 0
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
		# Taller than the Hero, because it is the landmark the whole map is arranged
		# around and the thing that ends the game if it falls. Width deliberately left at
		# the default: past about 1.2 the gap beside it drops under the Hero's width and
		# is_barrier_building would quietly reclassify the base as a wall.
		"height": 1.9,
		"hp": 10.0,
		"cost": {},
		"upgrades_to": "",
	},
	"tower": {
		"name": "BUILDING_TOWER_NAME",
		"kind": "tower",
		"footprint": 1.1,
		"height": 2.4,
		"hp": 20.0,
		# Stone, so a turret cannot be reached on wood alone -- and a blueprint, so
		# it cannot be reached on materials alone either. Both come out of the
		# cabin, which is the point: the thing you defend is the thing you need.
		"cost": {"wood": 8, "stone": 4},
		"requires_unlock": "blueprint_tower",
		"range": 5.0,
		"damage": 1.0,
		"fire_rate": 1.0,
		# How fast the head swings round to follow its target, in degrees a second. Fast
		# enough to be on target by the next shot from anywhere; slow enough to be seen
		# turning, which is how the player can tell which dinosaur it has picked.
		"turn_speed": 300.0,
		"upgrades_to": "",
	},
	"wall": {
		"name": "BUILDING_WALL_NAME",
		"kind": "wall",
		"hp": 8.0,
		# A barrier: neighbouring stakes close up into a fence the Hero cannot slip
		# through. Being fenced in is undone by demolishing one of them.
		#
		# A row of small sharpened cones. Never a block, in any arrangement.
		#
		# Low and made of small pieces is the whole silhouette: staying below
		# BUILDING_HEIGHT_DEFAULT keeps a fence something you see over rather than a
		# wall of buildings. A turret is the opposite -- narrow enough to walk past,
		# tall enough to spot across the map.
		#
		# A STAKE IS AS BIG AS THE STAKE. `spike_diameter` is the whole of its size:
		# the cone you see, the box that stops you, and the ground it claims are one
		# number, so they cannot disagree.
		#
		# It used to declare a footprint of a whole tile -- 2m of claim for 0.62m of
		# cone. The tile was blocked whether or not anything was standing in the part
		# you were walking through, which is why a plain gap between a stake and a
		# hillside was solid. What closes a way now is a RUN of stakes wide enough to
		# cross a tile, which is the thing the player can actually see is a fence.
		"height": 0.95,          # taller than it is wide, so it reads as a stake
		"spike_diameter": 0.62,  # ONE cone, this wide. Not derived from anything.
		# Stakes are placed on a FINER grid than everything else: three positions per
		# tile edge, so 0.67m apart instead of 2m. That is the whole answer to "one
		# stake, but they sit miles apart" -- the cone was already small, the GRID was
		# what was coarse. A row of them now closes up into a fence you can see is a
		# fence, and how dense it is is the player's decision rather than a constant.
		#
		# Three per tile edge is also what decides when a fence SEALS: a full row or
		# column of fine cells is a run of cones crossing the tile with nothing between
		# them, and that is what nobody walks through. Fewer than that is a gap, and a
		# gap you can see is a gap you can use.
		"cell_divisions": 3,
		# Sharpened stakes: anything forcing its way past takes damage per tick, so a
		# fence line wears a raid down instead of only delaying it. Deliberately a
		# chip rather than a kill -- a raptor (DINOS.raptor.hp) chewing through these
		# 8 HP comes out alive but nearly dead, leaving the finishing to a tower or
		# the Hero.
		#
		# NO `contact_range` HERE ANY MORE. It was a flat 2.0, chosen when a stake
		# filled its 2m tile, and left behind when the stake shrank to 0.62m -- a
		# four-metre-wide damage field around each cone. A raid walking PAST a fence
		# through a perfectly good gap was bled out by stakes it never touched. It is
		# derived from the stake's own size now (Config.get_contact_range), so it
		# reaches whoever is standing against the spikes and nobody else.
		"contact_damage": 0.15,
		"contact_tick": 0.5,
		# Two wood, not one. At one, mending a stake cost the same as replacing it
		# (repair is the price scaled by the damage, rounded up, so the floor is one
		# unit) -- which made repair meaningless on the cheapest thing in the game.
		# At two, a stake worth saving can be saved.
		"cost": {"wood": 2},
		"upgrades_to": "",
	},
}

## How much of its tile a building's box takes up, in metres.
##
## Most buildings leave a strip free, so two neighbours always have a lane between
## them the Hero fits through and a ring of workshops can never seal him in. A
## barrier -- stakes, and later any wall -- declares a `footprint` of its own that
## fills the tile instead, so a row of them reads as a continuous fence and really
## does shut a gap. Getting boxed in on purpose is recoverable: select any adjacent
## building and demolish it.
const BUILDING_CLEARANCE: float = 0.2   # slack beyond the Hero's width, in metres

## Physics layers, as bit masks. 1 ground, 2 buildings, 4 hero, 8 nest (dinos carry
## 4|8), and this one.
##
## A BLUEPRINT IS CLICKABLE BUT SOLID TO NOBODY. It used to be given layer 0 with its
## collision shape disabled, which does stop it blocking anyone -- and also makes it
## invisible to the click raycast, so unfinished work could not be clicked to carry on
## with. Its own layer keeps both halves: the picking ray looks here, and nothing else
## does.
const LAYER_BLUEPRINT: int = 16

## Walls sit apart from other buildings so that THE MAN WHO BUILT THEM CAN GET PAST.
##
## A fence is his, and being shut out of his own camp by it -- with no gate in the game
## -- is a worse problem than the one a fence solves. Dinosaurs ray against this layer as
## well as the buildings layer; the Hero's collision mask leaves it out, and only it, so
## the wreck and the turrets still stop him exactly as they did.
const LAYER_WALL: int = 32

## How the navigation meshes are baked. See scripts/core/NavMaps.gd.
const NAV: Dictionary = {
	# Fine enough to see the gap between two stakes. A stake is 0.62m and they snap 0.67m
	# apart, so a coarse bake would smear a fence into a solid line and the gaps the
	# player deliberately left would stop existing.
	# 0.1, so that agent_radius is a WHOLE number of voxels (0.4 = 4 of them). The bake
	# quantises the radius to voxels and warns when it has to round, and a radius that is
	# silently bigger than declared is a fence that seals gaps the player left open.
	"cell_size": 0.1,
	# What the mesh is carved for. One radius for everything that walks: a theropod is
	# wider and can be routed through a gap it does not fit, which only the avoidance
	# solver notices. A third mesh is the fix if that ever shows on screen.
	"agent_radius": 0.4,
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

## How many places a building of this type may stand along one tile edge.
##
## 1 for almost everything: a turret goes in the middle of its tile and that is that.
## Stakes use a finer grid so a fence can be built dense enough to read as a fence.
static func get_cell_divisions(type_id: String) -> int:
	if BUILDINGS.has(type_id):
		return clampi(int(BUILDINGS[type_id].get("cell_divisions", 1)), 1, 8)
	return 1

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

## How wide one stake is.
##
## DECLARED, not derived. It used to be worked out from a cone count and a tile
## width, which is how a stake ended up being three cones, or five at a corner, and
## why the number changed under the player as neighbours went up. There is one cone
## and this is how wide it is.
static func get_spike_diameter(type_id: String) -> float:
	if BUILDINGS.has(type_id):
		return maxf(0.05, float(BUILDINGS[type_id].get("spike_diameter", 0.6)))
	return 0.6

## How deep a fence line is across the run, in metres.
##
## For spikes this IS the cone -- derived, not declared, so the collision box can
## never be wider or narrower than the spikes the player is looking at. That
## equality is the whole point: a box wider than its art stops things at nothing
## visible, and one narrower lets them through something that looks solid.
static func get_building_thickness(type_id: String) -> float:
	if get_building_mesh_style(type_id) == "spikes":
		return get_spike_diameter(type_id)
	if BUILDINGS.has(type_id) and BUILDINGS[type_id].has("thickness"):
		return maxf(0.05, float(BUILDINGS[type_id]["thickness"]))
	return get_building_footprint(type_id)

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

## Footprint for a building that has not declared one: wide as the tile allows
## while still leaving the Hero a way past.
static func get_default_building_footprint() -> float:
	var hero_w: float = float(HERO.get("width", 0.8))
	return maxf(0.5, TILE_SIZE - hero_w - BUILDING_CLEARANCE)

## What sort of thing this is: "wall" for anything a fence is made of, whatever else a
## building declares, or "" for a type that says nothing.
static func get_building_kind(type_id: String) -> String:
	if not BUILDINGS.has(type_id):
		return ""
	return String(BUILDINGS[type_id].get("kind", ""))

## Side length of `type_id`'s box, in metres. Declared per building, else derived.
##
## A building drawn out of small pieces is as wide as one piece. Anything else is a
## box nobody can see holding the Hero off a stake he is plainly standing beside.
static func get_building_footprint(type_id: String = "") -> float:
	if type_id != "" and get_building_mesh_style(type_id) == "spikes":
		return get_spike_diameter(type_id)
	if type_id != "" and BUILDINGS.has(type_id) and BUILDINGS[type_id].has("footprint"):
		return maxf(0.1, float(BUILDINGS[type_id]["footprint"]))
	return get_default_building_footprint()

## True when ONE of these fills its tile, so that a line of them cannot be slipped
## between.
##
## Nothing is any more. Stakes were the only barrier, and a stake is 0.62m wide: it is
## something to walk round, and a fence is what a RUN of them makes. Which tiles a run
## actually closes is GridManager's `fine_occupants_seal_cell`, because it depends on
## where the player put them rather than on the type.
static func is_barrier_building(type_id: String) -> bool:
	var fp: float = get_building_footprint(type_id)
	return (TILE_SIZE - fp) <= float(HERO.get("width", 0.8))

## The flag a building needs before it can be placed, or "" for anything the Hero
## can put up from the start. Declared as data so a new gate is a Config line
## rather than a branch somewhere in the build path.
static func building_requires_unlock(type_id: String) -> String:
	if BUILDINGS.has(type_id):
		return String(BUILDINGS[type_id].get("requires_unlock", ""))
	return ""

## The flag needed before `res_id` can be cut by hand, or "" for anything bare
## hands can take.
static func harvest_requires_unlock(res_id: String) -> String:
	if RESOURCE_NODES.has(res_id):
		return String(RESOURCE_NODES[res_id].get("requires_unlock", ""))
	return ""

## Types offered in the Hero's build menu, in display order.
## Buildings absent here exist in BUILDINGS but cannot be placed by the player
## (e.g. "core" is spawned by the level rather than bought).
const BUILDABLE_TYPES: Array[String] = ["wall", "tower"]

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
const DINOS: Dictionary = {
	"raptor": {
		"name": "DINO_RAPTOR_NAME",
		"hp": 3.0,
		"speed": 4.0,
		"damage": 1.0,
		"attack_rate": 1.0,
		"behaviour": "pack",
		"drops": {"food": 1, "bone": 1},
		"size": Vector3(0.8, 0.8, 0.8),
	},
	"big_theropod": {
		"name": "DINO_BIG_THEROPOD_NAME",
		"hp": 15.0,
		"speed": 2.0,
		"damage": 3.0,
		"attack_rate": 0.8,
		"behaviour": "siege",
		"drops": {"food": 3, "bone": 3},
		"size": Vector3(1.6, 1.6, 1.6),
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

# ==============================================================================
# 4. Wave Spawning & Scaling Rules (WAVES)
# ==============================================================================
const WAVES: Dictionary = {
	"base_count": 2,
	"count_per_wave": 1,
	"big_every": 3,
	"big_multiplier": 2.0,
	"enhance_after_big": {
		"hp": 1.3,
		"damage": 1.2,
		"speed": 1.0
	},
	"spawn_interval": 0.8,
}

# ==============================================================================
# 5. Nest Configuration (NEST)
# ==============================================================================
const NEST: Dictionary = {
	"hp": 30.0,
	# Bigger than anything the player builds, because it is the thing the whole map is
	# pointed at. Both its collider and its body come from this one figure.
	"size": Vector3(2.0, 1.2, 2.0),
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
	"tower": Color(0.2, 0.5, 0.9),
	"wall": Color(0.5, 0.35, 0.2),
	"raptor": Color(0.47, 0.38, 0.26),          # sand and dust: a predator that hunts here
	"big_theropod": Color(0.35, 0.29, 0.24),    # darker and heavier than the pack
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
const INITIAL_NESTS_ALIVE: int = 1

# ==============================================================================
# 8. Level & Map Layout Configuration
# ==============================================================================
const MAP: Dictionary = {
	"default_core_cell": Vector2i(0, 0),
	"default_nest_cell": Vector2i(0, -9),
	"path_column_x": 0,
	"produce_duration": 1.0, # Duration (seconds) of PRODUCE phase before auto-advancing to PLAN
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
		{"type": "water", "cell": Vector2i(-4, -4)}
	],
}
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
	"hp": 10.0,                   # 生命值（归零直接 Game Over）
	"move_speed": 4.0,            # 移动速度（米/秒）
	"damage": 1.0,                # 攻击力（仅部署阶段生效，前期攻击力较低）
	"attack_rate": 1.0,           # 攻击间隔（秒）
	"attack_range": 2.0,          # 攻击距离（米）
	"provoke_duration": 5.0,      # 挑衅仇恨持续时长（秒）
	"provoke_radius": 4.0,        # 挑衅仇恨生效半径（米）
	"width": 0.8,                 # 碰撞体宽度（米）——建筑占地由它推导
	"height": 1.6,                # 身高（米）——碰撞体与外形都用它，所以模型换上来也是这个高度
}

## Presentation sizing. The project renders at a 1280x720 design viewport with
## `canvas_items` stretch, so every value here is in design pixels and the engine
## scales the whole UI up on larger displays (1.5x at 1080p, 3x at 4K).
const UI: Dictionary = {
	"hud_font_size": 20,               # 顶栏资源/状态文字
	"hud_button_font_size": 18,        # 顶栏按钮
	"panel_title_font_size": 24,       # 右下角 Option 栏标题
	# 状态行要装下全游戏最长的一句话（未解锁的建筑要说明它在等什么），
	# 所以它比按钮字号小一档，并且开了自动换行——放不下的字等于没有字。
	"panel_status_font_size": 15,      # Option 栏状态文字
	"panel_button_font_size": 18,      # Option 栏指令按钮
	"gameover_title_font_size": 40,
	# 世界空间文字的实际高度 = font_size * pixel_size（米）。
	# TILE_SIZE 是 2.0m，所以 48 * 0.005 = 0.24m 约为格子的 1/8，一个建筑名大致一格宽。
	"world_label_font_size": 48,       # 建筑/资源点头顶的 3D 文字
	"world_label_pixel_size": 0.005,   # 3D 文字的世界尺寸（每像素米数）
	"world_label_fixed_size": false,   # true 会让文字屏幕尺寸恒定并无视 pixel_size 缩放，导致巨大
	"option_panel_size": Vector2(430, 300),  # 右下角 Option 栏尺寸（设计像素）
	"option_panel_margin": 16.0,       # Option 栏距屏幕边缘的留白
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
	# A building with nothing to report shows no name. Without this a fence of twenty
	# stakes writes "Wooden Stakes" twenty times across the middle of the screen.
	"name_label_hide_when_idle": true,
	"health_bar_hide_at_full": true,  # 满血时隐藏，避免画面嘈杂
	# 捡起东西时在原地飘一个数字：掉落物消失了，只有 HUD 数字变化，
	# 不给一个就地的反馈的话玩家看不出"进账了"。
	"pickup_text_rise": 1.0,          # 飘起的高度（米）
	"pickup_text_duration": 0.7,      # 飘起并淡出的时长（秒）
	# 选中圈沿单位底座绘制，尺寸由该单位的实际占地推导，不是固定半径——
	# 木栅栏宽 1.9m，固定 0.85m 的圈会整个埋进方块里看不见。
	"selection_ring_margin": 0.18,    # 圈比底座向外扩出多少（米）
	"selection_ring_thickness": 0.09, # 圈线粗细（米）
	"selection_ring_color": Color(0.35, 1.0, 0.5, 0.9),
	# 悬停圈：鼠标下面是什么。和选中圈刻意不同色，否则"我选中的"和"我指着的"分不清。
	# 木尖刺只有 0.62m 宽，一排挨在一起时，没有这个圈根本看不出点的是哪一根。
	"hover_ring_color": Color(1.0, 1.0, 1.0, 0.55),
	"audio_volume_db": -8.0,
	"audio_enabled": true,
}

const NEST_GUARDS: Dictionary = {
	"count": 3,                   # 巢穴外守卫数量
	"post_radius": 3.0,           # 岗位游荡半径（米）
	"aggro_radius": 6.0,          # 警戒半径：目标进入即脱离岗位追击
	"leash_radius": 12.0,         # 追出此距离放弃并返回岗位
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

## Where a dinosaur stands to bite something, as a distance from the building's FACE.
##
## These used to be radii from the building's CENTRE, fixed at 1.6 and 2.6. That was the
## same number for everything because everything filled a 2m tile. A stake is 0.62m wide
## now, and the fixed radius put its attackers 1.3 to 2.3 METRES from a cone you could
## step over -- which is exactly the "恐龙站在木尖刺前（有一段距离）" that kept being
## reported, and which no amount of work on the targeting rules was ever going to fix.
##
## Measured from the face, a species stands the same way against a stake as against the
## wreck. The old numbers fall out unchanged for a 2m building (1.0 + 0.6 = 1.6).
const DINO_STANDOFF_INNER: float = 0.6
const DINO_STANDOFF_OUTER: float = 1.6

## Kept for anything still asking the old question. A 2m building is the case they
## describe, and get_attack_slot_radius is what decides now.
const DINO_ATTACK_SLOT_RADIUS_INNER: float = 1.6
const DINO_ATTACK_SLOT_RADIUS_OUTER: float = 2.6

## How far from `type_id`'s centre a dinosaur stands while biting it.
static func get_attack_slot_radius(type_id: String, outer: bool = false) -> float:
	var half: float = get_building_footprint(type_id) * 0.5
	return half + (DINO_STANDOFF_OUTER if outer else DINO_STANDOFF_INNER)

## How far from a sharpened building's centre its spikes still hurt.
##
## Derived, for the same reason as the standoff: a flat 2.0 was a fence that damaged
## everything within two metres of each cone -- a four-metre-wide field around a 0.62m
## stake, which chewed through raids that were only walking PAST it through a gap. It has
## to reach whatever is standing in the inner slot and stop soon after.
static func get_contact_range(type_id: String) -> float:
	if BUILDINGS.has(type_id) and BUILDINGS[type_id].has("contact_range"):
		return maxf(0.0, float(BUILDINGS[type_id]["contact_range"]))
	return get_attack_slot_radius(type_id, false) + 0.4

# ==============================================================================
# 12. Continuous Real-Time Raids & Resource Nodes (v0.2)
# ==============================================================================
const RAIDS: Dictionary = {
	"interval_min": 80.0,         # 两次来袭的最小间隔（秒）——v0.4 的开局链条多了几趟路
	"interval_max": 120.0,        # 最大间隔——区间内随机，不是固定周期
	"first_raid_delay": 90.0,     # 开局宽限期：够建一座伐木屋、照料一轮、再架一座哨位
	"warning_lead_time": 15.0,    # Pre-raid warning duration (seconds)
	"intensity_per_minute": 0.15, # Raid intensity escalation slope per minute
	"intensity_jitter": 0.3,      # Random intensity fluctuation (+/- 30%)
}

const RESOURCE_NODES: Dictionary = {
	"wood": {
		"name": "RESOURCE_WOOD",
		"capacity": 150,
		"harvest_rate": 0.5,      # 0.5 wood/s by hand
		"color": Color(0.35, 0.55, 0.25),
		"depleted_color": Color(0.3, 0.3, 0.3),
		# A tree stands taller than the Hero, which is how it reads as a tree rather
		# than a bush. Width stays inside the tile so it never overhangs a cell the
		# grid says is free.
		# A tree's CROWN may spread past its cell: it is up in the air, and who can walk
		# where is decided by the cell, never by the art. Fitted into the old 1.6m box the
		# tree fern's four-metre crown shrank the whole tree to a 1.7m shrub.
		"size": Vector3(3.2, 3.6, 3.2),
	},
	"stone": {
		"name": "RESOURCE_STONE",
		"capacity": 100,
		"harvest_rate": 0.35,     # 0.35 stone/s by hand
		# Bare hands do not cut rock. The pick is made at the cabin out of bone, and
		# bone comes off a dinosaur -- which is what turns the first raid from a
		# threat into something the player needs.
		"requires_unlock": "harvest_stone",
		"color": Color(0.6, 0.6, 0.65),
		"depleted_color": Color(0.3, 0.3, 0.3),
		"size": Vector3(1.6, 1.2, 1.6),   # an outcrop: wide and low, unlike a tree
	},
	"water": {
		"name": "RESOURCE_WATER",
		"capacity": 120,
		"harvest_rate": 0.5,      # 0.5 water/s by hand
		"color": Color(0.2, 0.5, 0.8),
		"depleted_color": Color(0.25, 0.3, 0.35),
		"size": Vector3(1.8, 0.3, 1.8),   # a pool, so almost flat
	}
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
	"hero":                 {"scene": "res://assets/models/hero.glb", "placeholder": "hero",     "anchor": "feet",   "color": "caveman"},
	# Every dinosaur gets its own row even while they share a placeholder: the row is
	# where its model will go, and they will not share that.
	"dino/raptor":          {"scene": "res://assets/models/raptor.glb", "placeholder": "raptor",   "anchor": "feet",   "color": "raptor"},
	"dino/big_theropod":    {"scene": "res://assets/models/t_rex.glb", "placeholder": "raptor",   "anchor": "feet",   "color": "big_theropod"},
	"dino/pterosaur":       {"scene": "res://assets/models/pterosaur.glb", "placeholder": "raptor",   "anchor": "feet",   "color": "pterosaur"},
	# A low mound of scraped-up earth with a clutch of eggs in the hollow on top, a rim of
	# broken branches, and a burrow at its foot facing the field: the mouth the raid pours
	# out of, with bones by the door (tools/generate_props.py).
	"nest":                 {"scene": "res://assets/models/props/nest_a.glb",
		"material": "vertex", "placeholder": "nest_mound", "anchor": "feet", "color": "nest"},
	# The wreck: the only evidence the Hero is from anywhere else, and the thing that
	# ends the game if the raid reaches it. It gets the most geometry on the map.
	"building/core":        {"scene": "res://assets/models/wreck.glb", "placeholder": "ship_wreck", "anchor": "feet", "color": "core"},
	# A machine off the wreck -- white plating, the orange band, twin barrels and a red
	# eye -- on a stand the Hero lashed together from timber over a drystone plinth. The
	# head is its own node and turns to face what it shoots (Tower.gd). It was a box.
	"building/tower":       {"scene": "res://assets/models/props/sentry_a.glb",
		"material": "vertex", "placeholder": "box", "anchor": "feet", "color": "tower"},
	# A sharpened log driven into a mound of turned earth: axe-cut facets, a fire-hardened
	# charred tip, a band of vine lashing. It was an orange traffic cone.
	"building/wall":        {"scene": "res://assets/models/props/stake_a.glb",
		"material": "vertex", "placeholder": "spikes", "anchor": "feet", "color": "wall"},
	# A tree is a trunk, a rock is a lump: the cylinder is a stand-in for both until the
	# models land, and "center" is wrong for both of them, so both anchor at the feet.
	# A tree fern, like the forest round it -- the choppable tree was a striped barrel
	# with a tuft on top, standing among the real ones. Cut down, it is a stump with its
	# crown lying beside it (tools/generate_flora.py).
	"node/wood":            {"scene": "res://assets/models/flora/tree_fern_a.glb",
		"scene_depleted": "res://assets/models/flora/tree_fern_stump_a.glb",
		"material": "flora",    # coloured by its vertices, like the forest it stands in
		"placeholder": "cycad", "anchor": "feet", "color": ""},
	# Mossy boulders half sunk in the ground; quarried, a split low stump of rock with
	# pale fresh faces and rubble round it (tools/generate_props.py).
	"node/stone":           {"scene": "res://assets/models/props/outcrop_a.glb",
		"scene_depleted": "res://assets/models/props/outcrop_quarried_a.glb",
		"material": "vertex", "placeholder": "outcrop", "anchor": "feet", "color": ""},
	"node/water":           {"scene": "", "placeholder": "pool",     "anchor": "feet",   "color": ""},
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
	"drop/water":           {"scene": "res://assets/models/props/drop_water_a.glb",
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
			return NEST.get("size", Vector3(2.0, 1.2, 2.0))
		"building":
			var fp: float = get_building_footprint(id)
			return Vector3(fp, get_building_height(id), fp)
		"node":
			if RESOURCE_NODES.has(id) and RESOURCE_NODES[id].has("size"):
				return RESOURCE_NODES[id]["size"]
			return Vector3(1.6, 1.0, 1.6)
		"drop":
			# A pile is wider than it is tall: half as wide again as DROPS.size, which is
			# as tall as one gets.
			var s: float = float(DROPS.get("size", 0.3))
			return Vector3(s * 1.5, s, s * 1.5)
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
	# 开局物资：撒在船舱周围，而不是直接进仓库
	"opening_stock": {"wood": 20},
	"opening_piles": 4,        # 分成几堆
	"opening_ring_radius": 4.5, # 距船舱的距离（米）——必须大于现代人出生点的拾取半径
}

## What the player has to go and fetch before anything can be built, totalled by
## resource. The same figure a wallet used to start with, just on the floor.
static func get_opening_stock(res_id: String) -> int:
	return int(DROPS.get("opening_stock", {}).get(res_id, 0))

## Colour for a resource that has no node on the map: meat only ever comes off a
## dinosaur, so RESOURCE_NODES has nothing to say about it.
const RESOURCE_FALLBACK_COLORS: Dictionary = {
	"food": Color(0.78, 0.32, 0.28),
	"bone": Color(0.88, 0.85, 0.72),
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
## fee, and a turret -- expensive, and worth keeping where it stands -- is the
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
## Hero gains is made in it. Two stations, one rule: **materials make tools, food
## gives ideas.** The workbench turns bone, wood and stone into abilities -- what
## the Hero can *do*; the kitchen turns meat into blueprints -- what he can
## *build*.
##
## Nothing here is an inventory item. A recipe grants a permanent flag and that is
## the whole of it: unlocked means usable, so there is no bag, no slots, and no
## stat sheet to maintain. That is the line that keeps this from becoming an RPG.
##
## The interior is a scene parked off the map rather than a scene swap, so the
## world keeps running while the player is inside -- which is the point: crafting
## costs real seconds, and while he is at the bench nobody is holding the line.
const CABIN: Dictionary = {
	"interior_origin": Vector3(0.0, -200.0, 0.0),  # far below the map; never seen from outside
	"enter_range": 2.5,                            # how close the Hero must be to step inside
	# The interior is the same world 200 metres down, so it inherits the level's sky --
	# and the room has no ceiling, so the camera looked straight over the wall into open
	# daylight. Being "indoors" fell apart the moment you stepped in.
	#
	# Camera3D carries its own Environment, so the fix is per-camera rather than a second
	# WorldEnvironment: entering the cabin swaps to it and leaving swaps back, with no
	# extra machinery to keep in sync. Flat dark colour, no sky and no fog -- what is
	# beyond the walls of a room you cannot see out of is nothing.
	"interior_background": Color(0.05, 0.045, 0.055),
	"interior_ambient": Color(0.30, 0.26, 0.24),   # a little bounce, so shadows are not pitch black
	"interior_ambient_energy": 0.45,
}

## Every recipe, whatever station it belongs to, has the same shape:
##   station  -- which bench it is made at
##   inputs   -- what it costs, spent when work begins
##   time     -- seconds the Hero must stand there (progress is kept if he leaves)
##   unlocks  -- the permanent flag it grants
## Adding a third station later is an entry here plus a node in the scene, not a
## new system.
const RECIPES: Dictionary = {
	"stone_pick": {
		"name": "RECIPE_STONE_PICK_NAME",
		"station": "workbench",
		"inputs": {"bone": 1, "wood": 4},
		"time": 8.0,
		"unlocks": "harvest_stone",
	},
	"roast_meat": {
		"name": "RECIPE_ROAST_MEAT_NAME",
		"station": "kitchen",
		# Two meat, which is what the first raid leaves. The pick and the blueprint
		# both have to be reachable on one raid's drops or the opening stalls: the
		# player would be waiting on a second wave with no turret and no reason to
		# have gone home.
		"inputs": {"food": 2, "wood": 2},
		"time": 6.0,
		"unlocks": "blueprint_tower",
	},
}

## Stations in the order they stand in the cabin.
const STATIONS: Array[String] = ["workbench", "kitchen"]

## Recipes belonging to one station, in declaration order.
static func recipes_at(station_id: String) -> Array[String]:
	var out: Array[String] = []
	for recipe_id in RECIPES:
		if String(RECIPES[recipe_id].get("station", "")) == station_id:
			out.append(String(recipe_id))
	return out

## Construction time is a function of price: the more a building costs, the longer
## the Hero stands there making it. Keeping it derived means a designer tunes one
## number (cost) instead of two that can drift apart.
##   wooden stakes (1 wood)  -> 1.0s (the floor)
##   lumber hut   (12 wood)  -> 12.3s
## Superlinear on purpose: at a flat rate per resource the gap between a cheap and
## an expensive building is barely noticeable, and raising a turret should feel
## like work next to hammering in a stake.
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
## So the level is a valley floor. `field_half` is flat and exactly level, because
## everything in this game lives on a grid at y = 0 and ground that undulated under the
## buildings would stand them in the air or bury them. Past it the land climbs away and
## keeps going well beyond anything the camera can frame, which gives the boundary a
## reason to exist in the world rather than hiding it: you are at the bottom of a
## valley, and the way out is up.
const TERRAIN: Dictionary = {
	# Flat ground reaches this far from the origin. It has to comfortably cover every
	# cell the level uses -- the nest sits at z = -9 cells = -18m, so 22 leaves margin.
	# Shrinking this without checking the map would put a slope under a building.
	"field_half": 22.0,
	# Total ground extent. Far past what the fixed camera can frame, which is the whole
	# point: there is no edge to find.
	"outskirts_half": 110.0,
	# The climb happens over `rim_span` metres past the field, NOT over the whole extent.
	# It has to finish inside what the camera can see or the valley wall never appears:
	# at the first attempt the rise was spread over 88 metres, so by the time it was tall
	# enough to notice it was behind the fog, and the horizon was just grey.
	"rim_span": 38.0,
	"rim_rise": 18.0,          # how high the surrounding land stands by the top of the climb
	"rim_noise": 4.5,          # broken up, so the valley is not a perfect bowl
	"quad_size": 4.0,          # ground mesh resolution in metres
	"noise_seed": 20260917,    # fixed, so the same landscape comes back every launch
	"noise_frequency": 0.018,
	# Hills: how finely each cell is subdivided, and how much rubble is added on top.
	# The rubble is scaled by height so it never lifts a hill off the ground or pokes
	# through the edge it shares with the hill next door.
	"hill_subdivisions": 6,
	"hill_noise": 0.12,
	# Ground colour is blended by slope: flat reads as grass, steep as rock. Without it
	# the rising land is exactly the same green as the field and the whole view reads as
	# an endless lawn instead of a valley. `rock_slope` is the gradient at which the
	# blend reaches full rock.
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
	"flora_edge_count": 26,                    # per variant
	"flora_edge_from": 3.0,
	"flora_edge_to": 22.0,
	"flora_skyline_trees": ["res://assets/models/flora/araucaria_a.glb",
		"res://assets/models/flora/araucaria_b.glb"],
	"flora_skyline_count": 22,                 # per variant
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
	"cliff_count": 8,                          # per variant; each is about 8 m along
	"cliff_from": 14.0,                        # metres past the field's edge
	"cliff_to": 30.0,
	"cliff_scale": Vector2(0.9, 1.4),
	# How deep each is set into the slope, in metres per unit of its scale: its front row
	# stands downhill of its middle, and without this it stood on stilts of daylight.
	"cliff_sink": 0.9,
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

	# Hero states (corresponds to Hero.State enum keys)
	"hero": {
		"IDLE": "idle",
		"MOVING": "walk",
		"BUILDING": "build",
		"ATTACKING": "attack",
		"DEAD": "death",
		"HARVESTING": "harvest",
	},

	# Dinosaur states (corresponds to Dino.State enum keys)
	"dino": {
		"WALKING": "run",     # bipedal locomotion gait
		"ATTACKING": "attack", # bite / swipe
		"DEAD": "death",
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
	},
}
