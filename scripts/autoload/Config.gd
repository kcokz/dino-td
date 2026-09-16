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
		# Wide and low is the whole silhouette: the width is what closes the gap, and
		# staying below BUILDING_HEIGHT_DEFAULT keeps a row of stakes reading as a
		# fence you see over rather than as a wall of buildings. A turret is the
		# opposite -- narrow enough to walk past, tall enough to spot across the map.
		# Fills its tile exactly, so neighbouring stakes touch and a fence line has
		# no holes in it -- a visible gap between two stakes reads as a way through
		# even when the collision says otherwise. Stakes stay unimposing by being
		# LOW rather than by being narrow: height is the lever that costs nothing,
		# while width is the thing that decides whether a fence is a fence.
		"footprint": 2.0,
		"height": 0.85,
		"mesh_style": "spikes",
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
		"cost": {"wood": 1},
		"ap_cost": 1,
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

## "box" (one solid block) or "spikes" (a single sharpened stake).
static func get_building_mesh_style(type_id: String) -> String:
	if BUILDINGS.has(type_id) and BUILDINGS[type_id].has("mesh_style"):
		return String(BUILDINGS[type_id]["mesh_style"])
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
		"targeting": "blocker_then_core",
		"drops": {"food": 1, "bone": 1},
		"size": Vector3(0.8, 0.8, 0.8),
	},
	"big_theropod": {
		"name": "DINO_BIG_THEROPOD_NAME",
		"hp": 15.0,
		"speed": 2.0,
		"damage": 3.0,
		"attack_rate": 0.8,
		"targeting": "prefer_buildings",
		"drops": {"food": 3, "bone": 3},
		"size": Vector3(1.6, 1.6, 1.6),
	},
	"pterosaur": {
		"name": "DINO_PTEROSAUR_NAME",
		"hp": 2.0,
		"speed": 6.0,
		"damage": 1.0,
		"attack_rate": 1.2,
		"targeting": "ignore_walls",
		"drops": {"food": 1, "bone": 1},
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
const DINO_ATTACK_SLOT_RADIUS_INNER: float = 1.6
const DINO_ATTACK_SLOT_RADIUS_OUTER: float = 2.6

# ==============================================================================
# 12. Continuous Real-Time Raids & Resource Nodes (v0.2)
# ==============================================================================
const RAIDS: Dictionary = {
	"interval_min": 70.0,         # 两次来袭的最小间隔（秒）
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
	},
	"water": {
		"name": "RESOURCE_WATER",
		"capacity": 120,
		"harvest_rate": 0.5,      # 0.5 water/s by hand
		"color": Color(0.2, 0.5, 0.8),
		"depleted_color": Color(0.25, 0.3, 0.35),
	}
}

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
		"inputs": {"food": 3, "wood": 2},
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



