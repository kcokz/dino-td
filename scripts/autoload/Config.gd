# res://scripts/autoload/Config.gd
extends Node

## Centralized Game Configuration & Constants for Defend Dinosaur v0.0
## All numerical tunings, costs, combat stats, and wave rules are defined here.
## Business logic scripts must reference Config constants and never hardcode values.

# ==============================================================================
# 1. Economy & Action Points
# ==============================================================================
const BASE_AP: int = 3
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
		"hp": 10.0,
		"cost": {},
		"ap_cost": 0,
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
		"ap_cost": 1,
		"range": 5.0,
		"damage": 1.0,
		"fire_rate": 1.0,
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
		# `footprint` is how much fence ONE stake lays down -- a whole tile, so two
		# stakes side by side join into a line with no hole in it. What the player
		# sees in that length is `spikes_per_tile` cones, each one small: the pitch
		# between cones is footprint / spikes_per_tile, which comes out identical
		# inside a tile and across a tile boundary, so a long fence is an evenly
		# spaced picket line rather than visible clumps.
		#
		# Wall.gd asks its neighbours which way the run goes: cones in a line along
		# it, an L at a corner, a small cross for a stake standing on its own. The
		# collision boxes are cut from the same numbers as the cones, so anything
		# pressing on the fence is touching spikes rather than being held off at a
		# distance by a box nobody can see. There is no `thickness` here on purpose:
		# how deep the line is IS the cone's diameter (get_building_thickness), and
		# a second number for it would be a number that can disagree with the art.
		"footprint": 2.0,
		"height": 0.95,        # taller than a cone is wide, so it reads as a stake
		"spikes_per_tile": 3,  # cones per tile of fence; pitch = footprint / this
		"spike_fill": 0.85,    # cone diameter as a fraction of the pitch (<1 leaves a hair of daylight)
		# Sharpened stakes: anything forcing its way past takes damage per tick, so a
		# fence line wears a raid down instead of only delaying it. Deliberately a
		# chip rather than a kill -- a raptor (DINOS.raptor.hp) chewing through these
		# 8 HP comes out alive but nearly dead, leaving the finishing to a tower or
		# the Hero. contact_range must reach DINO_ATTACK_SLOT_RADIUS_INNER, which is
		# where a dino stands while attacking; a range tied to the footprint alone
		# would leave the attacker just out of reach and the stakes harmless.
		"contact_damage": 0.15,
		"contact_tick": 0.5,
		"contact_range": 2.0,
		# Two wood, not one. At one, mending a stake cost the same as replacing it
		# (repair is the price scaled by the damage, rounded up, so the floor is one
		# unit) -- which made repair meaningless on the cheapest thing in the game.
		# At two, a stake worth saving can be saved.
		"cost": {"wood": 2},
		"ap_cost": 1,
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

## How many cones one tile of fence is drawn as.
static func get_spikes_per_tile(type_id: String) -> int:
	if BUILDINGS.has(type_id):
		return maxi(1, int(BUILDINGS[type_id].get("spikes_per_tile", 1)))
	return 1

## Distance between neighbouring cones. Derived from the footprint rather than
## declared, which is what makes the spacing identical across a tile boundary: a
## stake's cones sit at (i + 0.5) * pitch, so the last cone of one tile and the
## first of the next are exactly one pitch apart, like every other pair.
static func get_spike_pitch(type_id: String) -> float:
	return get_building_footprint(type_id) / float(get_spikes_per_tile(type_id))

## Base diameter of one cone. Just under the pitch, so neighbours stand shoulder to
## shoulder with a hair of daylight between them instead of fusing into a ridge.
static func get_spike_diameter(type_id: String) -> float:
	var fill: float = 0.85
	if BUILDINGS.has(type_id):
		fill = float(BUILDINGS[type_id].get("spike_fill", fill))
	return maxf(0.05, get_spike_pitch(type_id) * clampf(fill, 0.1, 1.0))

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

## Side length of `type_id`'s box, in metres. Declared per building, else derived.
static func get_building_footprint(type_id: String = "") -> float:
	if type_id != "" and BUILDINGS.has(type_id) and BUILDINGS[type_id].has("footprint"):
		return maxf(0.1, float(BUILDINGS[type_id]["footprint"]))
	return get_default_building_footprint()

## True when neighbouring copies of `type_id` close the gap between them rather
## than leaving the Hero a lane.
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
## (e.g. "core" is spawned by the level; the "ap" kind is dormant since AP was removed).
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
	"ground": Color(0.28, 0.32, 0.24),
	"hill": Color(0.36, 0.33, 0.28),
	"grid_hover": Color(1.0, 1.0, 0.2, 0.4),
	"core": Color(0.9, 0.3, 0.1),
	"tower": Color(0.2, 0.5, 0.9),
	"wall": Color(0.5, 0.35, 0.2),
	"raptor": Color(0.9, 0.15, 0.15),
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
const CONTROLS: Dictionary = {
	"hero_move_button": MOUSE_BUTTON_RIGHT,       # Default: Right-click moves Hero
	"build_place_button": MOUSE_BUTTON_LEFT,      # Default: Left-click places building / selects
	"build_cancel_button": MOUSE_BUTTON_RIGHT,    # Right-click cancels build preview
	"cancel_key": KEY_ESCAPE,                     # ESC cancels build preview
	"pause_key": KEY_SPACE                        # Space toggles pause
}

# ==============================================================================
# 11. Dinosaur Flocking & Attack Slots (v0.1)
# ==============================================================================
## How far a dinosaur can reach whatever it is biting. Without this an attack had
## no notion of distance at all: once one latched onto the Hero it went on hurting
## him from across the map until he died, and stood frozen in front of a target it
## could not touch. Comfortably past the inner attack ring, so a dinosaur standing
## in its slot can always reach the thing it is standing at.
const DINO_ATTACK_REACH: float = 2.2

const DINO_ATTACK_SLOT_RADIUS_INNER: float = 1.6
const DINO_ATTACK_SLOT_RADIUS_OUTER: float = 2.6

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
		"size": Vector3(1.6, 3.0, 1.6),
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
	"hero":                 {"scene": "", "placeholder": "box",      "anchor": "feet",   "color": "caveman"},
	# Every dinosaur gets its own row even while they share a placeholder: the row is
	# where its model will go, and they will not share that.
	"dino/raptor":          {"scene": "", "placeholder": "box",      "anchor": "feet",   "color": "raptor"},
	"dino/big_theropod":    {"scene": "", "placeholder": "box",      "anchor": "feet",   "color": "raptor"},
	"dino/pterosaur":       {"scene": "", "placeholder": "box",      "anchor": "feet",   "color": "raptor"},
	"nest":                 {"scene": "", "placeholder": "box",      "anchor": "feet",   "color": "nest"},
	"building/core":        {"scene": "", "placeholder": "box",      "anchor": "feet",   "color": "core"},
	"building/tower":       {"scene": "", "placeholder": "box",      "anchor": "feet",   "color": "tower"},
	"building/wall":        {"scene": "", "placeholder": "spikes",   "anchor": "feet",   "color": "wall"},
	# A tree is a trunk, a rock is a lump: the cylinder is a stand-in for both until the
	# models land, and "center" is wrong for both of them, so both anchor at the feet.
	"node/wood":            {"scene": "", "placeholder": "cylinder", "anchor": "feet",   "color": ""},
	"node/stone":           {"scene": "", "placeholder": "cylinder", "anchor": "feet",   "color": ""},
	"node/water":           {"scene": "", "placeholder": "cylinder", "anchor": "feet",   "color": ""},
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
	return Vector3.ONE

## Where the cones of a fence stand, in the building's own space, for a run along
## `axis` ("x", "z", or "both" for a corner, a cluster, or a stake on its own).
##
## The single source of that arrangement: the body is drawn from this and Wall.gd's
## collision boxes are cut along the same lines, so the shape you see and the shape that
## stops a raptor are the same shape by construction rather than by agreement.
static func spike_offsets(type_id: String, axis: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var count: int = get_spikes_per_tile(type_id)
	var pitch: float = get_spike_pitch(type_id)
	var span: float = get_building_footprint(type_id)
	var along_x: bool = (axis != "z")
	var along_z: bool = (axis != "x")
	for i in count:
		var t: float = (float(i) + 0.5) * pitch - span * 0.5
		if along_x:
			out.append(Vector3(t, 0.0, 0.0))
		# The two arms of a cross share their middle cone rather than stacking two in
		# the same hole.
		if along_z and not (along_x and is_zero_approx(t)):
			out.append(Vector3(0.0, 0.0, t))
	return out

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
	"size": 0.3,              # 方块边长（米）
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

	# Procedural Sky: Prehistoric atmosphere with clear upper troposphere and dust-laden horizon.
	"background_mode": Environment.BG_SKY,
	"sky_top_color": Color(0.35, 0.45, 0.58),       # Subdued cool zenith
	"sky_horizon_color": Color(0.72, 0.75, 0.77),   # Hazy horizon scattering
	"ground_bottom_color": Color(0.18, 0.20, 0.16), # Dark terrain bounce
	"ground_horizon_color": Color(0.55, 0.58, 0.54),
	"sun_angle_max": 30.0,
	"sun_curve": 0.15,

	# Ambient Lighting: Uses the procedural sky as the source so shadow sides receive
	# soft natural fill tinted by the sky, avoiding pitch-black cavities under trees and rocks.
	"ambient_source": Environment.AMBIENT_SOURCE_SKY,
	"ambient_color": Color(0.85, 0.90, 0.95),
	"ambient_energy": 0.35,
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
	"fog_light_color": Color(0.68, 0.73, 0.78),
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
	"sun_light_color": Color(1.0, 0.96, 0.90),
	"sun_light_energy": 1.15,
	"sun_shadow_enabled": true,
	"sun_shadow_bias": 0.03,
	"sun_shadow_normal_bias": 1.2,
	"sun_shadow_blur": 1.2,
	"sun_shadow_max_distance": 48.0,
}




