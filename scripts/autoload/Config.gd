# res://scripts/autoload/Config.gd
extends Node

## Centralized Game Configuration & Constants for Defend Dinosaur v0.0
## All numerical tunings, costs, combat stats, and wave rules are defined here.
## Business logic scripts must reference Config constants and never hardcode values.

# ==============================================================================
# 1. Economy & Action Points
# ==============================================================================
const BASE_AP: int = 3
const RESOURCES: Array[String] = ["wood", "stone", "water", "food"]
const INITIAL_RESOURCES: Dictionary = {
	"wood": 20,
	"stone": 0,
	"water": 0,
	"food": 0
}
const TILE_SIZE: float = 2.0

# ==============================================================================
# 2. Building Definitions (BUILDINGS)
# ==============================================================================
## Economy shape (v0.2 balance pass). One tend = tend_duration seconds of autonomous
## running, so a machine's yield per tend is produces_per_sec * tend_duration:
##   lumber_hut  cost 12  ->  0.25/s * 40s = 10 wood   (pays back in ~1.2 tends)
##   quarry      cost 22  ->  0.15/s * 40s =  6 stone
##   hunting_hut cost 18  ->  0.20/s * 40s =  8 water
## A tower costs 20 wood, i.e. two tends of a single lumber hut -- roughly one raid
## cycle (RAIDS.interval_min/max is 45-90s) of a modest economy.
##
## Opening wallet is 20 wood, which deliberately affords a real first decision
## rather than a forced one: a lumber hut (12) plus a wall (5), or a single tower
## (20) and no economy at all. It must stay at or above the cheapest producer, or
## the player starts unable to build anything and has to hand-harvest first while
## staring at a disabled build menu. Hand-harvesting a node yields RESOURCE_NODES.harvest_rate per
## second but occupies the Hero completely, so machines win on hero-time even
## though they cost wood up front.
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
		"hp": 20.0,
		"cost": {"wood": 20},
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
		"footprint": 1.9,
		"cost": {"wood": 1},
		"ap_cost": 1,
		"upgrades_to": "",
	},
	"lumber_hut": {
		"name": "BUILDING_LUMBER_HUT_NAME",
		"kind": "producer",
		"hp": 10.0,
		"cost": {"wood": 12},
		"ap_cost": 1,
		"tend_duration": 40.0,
		"tend_time": 2.0,
		"harvest_range": 12.0,
		"interacts_with_resources": ["wood"],
		"produces_per_sec": {"wood": 0.25},
		"produces": {"wood": 2},
		"upgrades_to": "",
	},
	"hut": {
		"name": "BUILDING_HUT_NAME",
		"kind": "ap",
		"hp": 10.0,
		"cost": {"wood": 3},
		"ap_cost": 1,
		"ap_bonus": 0,
		"upgrades_to": "wood_house",
	},
	"wood_house": {
		"name": "BUILDING_WOOD_HOUSE_NAME",
		"kind": "ap",
		"hp": 20.0,
		"cost": {"wood": 6},
		"ap_cost": 1,
		"ap_bonus": 1,
		"upgrades_to": "barracks",
	},
	"barracks": {
		"name": "BUILDING_BARRACKS_NAME",
		"kind": "ap",
		"hp": 30.0,
		"cost": {"wood": 10, "stone": 5},
		"ap_cost": 1,
		"ap_bonus": 2,
		"upgrades_to": "",
	},
	"quarry": {
		"name": "BUILDING_QUARRY_NAME",
		"kind": "producer",
		"hp": 15.0,
		"cost": {"wood": 22},
		"ap_cost": 1,
		"tend_duration": 40.0,
		"tend_time": 2.5,
		"harvest_range": 12.0,
		"interacts_with_resources": ["stone"],
		"produces_per_sec": {"stone": 0.15},
		"produces": {"stone": 1},
		"upgrades_to": "",
	},
	"hunting_hut": {
		"name": "BUILDING_HUNTING_HUT_NAME",
		"kind": "producer",
		"hp": 10.0,
		"cost": {"wood": 18},
		"ap_cost": 1,
		"tend_duration": 40.0,
		"tend_time": 2.0,
		"harvest_range": 12.0,
		"interacts_with_resources": ["water"],
		"produces_per_sec": {"water": 0.2},
		"produces": {"water": 1},
		"upgrades_to": "",
	}
}

## Types offered in the Hero's build menu, in display order.
## Buildings absent here exist in BUILDINGS but cannot be placed by the player
## (e.g. "core" is spawned by the level; the "ap" kind is dormant since AP was removed).
## How much of its tile a building's box takes up, in metres.
##
## Most buildings leave a strip free, so two neighbours always have a lane between
## them the Hero fits through and a ring of workshops can never seal him in. A
## barrier -- stakes, and later any wall -- declares a `footprint` of its own that
## fills the tile instead, so a row of them reads as a continuous fence and really
## does shut a gap. Getting boxed in on purpose is recoverable: select any adjacent
## building and demolish it.
const BUILDING_CLEARANCE: float = 0.2   # slack beyond the Hero's width, in metres

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

const BUILDABLE_TYPES: Array[String] = ["wall", "tower", "lumber_hut", "quarry", "hunting_hut"]

# ==============================================================================
# 3. Dinosaur Definitions (DINOS)
# ==============================================================================
const DINOS: Dictionary = {
	"raptor": {
		"name": "DINO_RAPTOR_NAME",
		"hp": 3.0,
		"speed": 4.0,
		"damage": 1.0,
		"attack_rate": 1.0,
		"targeting": "blocker_then_core",
		"size": Vector3(0.8, 0.8, 0.8),
	},
	"big_theropod": {
		"name": "DINO_BIG_THEROPOD_NAME",
		"hp": 15.0,
		"speed": 2.0,
		"damage": 3.0,
		"attack_rate": 0.8,
		"targeting": "prefer_buildings",
		"size": Vector3(1.6, 1.6, 1.6),
	},
	"pterosaur": {
		"name": "DINO_PTEROSAUR_NAME",
		"hp": 2.0,
		"speed": 6.0,
		"damage": 1.0,
		"attack_rate": 1.2,
		"targeting": "ignore_walls",
		"size": Vector3(0.8, 0.5, 0.8),
	}
}
const DINO_LANE_OFFSETS: Array[float] = [-0.35, 0.35, 0.0]
const DINO_SEPARATION_MIN_DIST: float = 1.15
const DINO_MAX_LATERAL_OFFSET: float = 0.6

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
	"hp": 30.0
}

# ==============================================================================
# 6. Placeholder Visual Colors (COLORS)
# ==============================================================================
const COLORS: Dictionary = {
	"ground": Color(0.28, 0.32, 0.24),
	"grid_hover": Color(1.0, 1.0, 0.2, 0.4),
	"core": Color(0.9, 0.3, 0.1),
	"tower": Color(0.2, 0.5, 0.9),
	"wall": Color(0.5, 0.35, 0.2),
	"lumber_hut": Color(0.15, 0.7, 0.3),
	"hut": Color(0.7, 0.6, 0.3),
	"wood_house": Color(0.65, 0.55, 0.25),
	"barracks": Color(0.6, 0.45, 0.2),
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
}

## Presentation sizing. The project renders at a 1280x720 design viewport with
## `canvas_items` stretch, so every value here is in design pixels and the engine
## scales the whole UI up on larger displays (1.5x at 1080p, 3x at 4K).
const UI: Dictionary = {
	"hud_font_size": 20,               # 顶栏资源/状态文字
	"hud_button_font_size": 18,        # 顶栏按钮
	"panel_title_font_size": 24,       # 右下角 Option 栏标题
	"panel_status_font_size": 18,      # Option 栏状态文字
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
const DINO_ATTACK_SLOT_RADIUS_INNER: float = 1.6
const DINO_ATTACK_SLOT_RADIUS_OUTER: float = 2.6

# ==============================================================================
# 12. Continuous Real-Time Raids & Resource Nodes (v0.2)
# ==============================================================================
const RAIDS: Dictionary = {
	"interval_min": 45.0,         # Minimum raid interval (seconds)
	"interval_max": 90.0,         # Maximum raid interval (seconds)
	"first_raid_delay": 60.0,     # Grace period before 1st raid (seconds)
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
	},
	"stone": {
		"name": "RESOURCE_STONE",
		"capacity": 100,
		"harvest_rate": 0.35,     # 0.35 stone/s by hand
		"color": Color(0.6, 0.6, 0.65),
		"depleted_color": Color(0.3, 0.3, 0.3),
	},
	"water": {
		"name": "RESOURCE_WATER",
		"capacity": 120,
		"harvest_rate": 0.5,      # 0.5 water/s by hand
		"color": Color(0.2, 0.5, 0.8),
		"depleted_color": Color(0.25, 0.3, 0.35),
	}
}

## Construction time is a function of price: the more a building costs, the longer
## the Hero stands there making it. Keeping it derived means a designer tunes one
## number (cost) instead of two that can drift apart.
##   wooden stakes (1 wood)  -> 0.5s (the floor)
##   lumber hut   (12 wood)  -> 4.8s
##   auto turret  (20 wood)  -> 8.0s
const BUILD_SECONDS_PER_RESOURCE: float = 0.4
const BUILD_TIME_MIN: float = 0.5

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
	return maxf(BUILD_TIME_MIN, total * BUILD_SECONDS_PER_RESOURCE)

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

## Returns the resource types that this building type interacts with (e.g. lumber_hut -> ["wood"]).
## Buildings without resource interaction (towers, walls, etc.) return an empty array.
static func get_interactable_resource_types(b_type: String) -> Array[String]:
	if not BUILDINGS.has(b_type):
		return []
	var b_cfg: Dictionary = BUILDINGS[b_type]
	if b_cfg.has("interacts_with_resources"):
		var raw: Array = b_cfg["interacts_with_resources"]
		var res: Array[String] = []
		for item in raw:
			res.append(str(item))
		return res
	# Automatic fallback derivation for producer buildings
	if b_cfg.get("kind", "") != "producer":
		return []
	var res: Array[String] = []
	var pps: Dictionary = b_cfg.get("produces_per_sec", {})
	for res_id in pps:
		if RESOURCE_NODES.has(res_id) and not res.has(res_id):
			res.append(res_id)
	var prod: Dictionary = b_cfg.get("produces", {})
	for res_id in prod:
		if RESOURCE_NODES.has(res_id) and not res.has(res_id):
			res.append(res_id)
	return res


