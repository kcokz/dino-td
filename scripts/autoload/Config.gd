# res://scripts/autoload/Config.gd
extends Node

## Centralized Game Configuration & Constants for Defend Dinosaur v0.0
## All numerical tunings, costs, combat stats, and wave rules are defined here.
## Business logic scripts must reference Config constants and never hardcode values.

# ==============================================================================
# 1. Economy & Action Points
# ==============================================================================
const BASE_AP: int = 3
const RESOURCES: Array[String] = ["wood", "stone", "food"]
const INITIAL_RESOURCES: Dictionary = {
	"wood": 10,
	"stone": 0,
	"food": 0
}
const TILE_SIZE: float = 2.0

# ==============================================================================
# 2. Building Definitions (BUILDINGS)
# ==============================================================================
const BUILDINGS: Dictionary = {
	"core": {
		"name": "营火",
		"kind": "core",
		"hp": 10.0,
		"cost": {},
		"ap_cost": 0,
		"upgrades_to": "",
	},
	"tower": {
		"name": "自动哨位",
		"kind": "tower",
		"hp": 20.0,
		"cost": {"wood": 4},
		"ap_cost": 1,
		"range": 5.0,
		"damage": 1.0,
		"fire_rate": 1.0,
		"upgrades_to": "",
	},
	"wall": {
		"name": "木墙",
		"kind": "wall",
		"hp": 30.0,
		"cost": {"wood": 2},
		"ap_cost": 1,
		"upgrades_to": "",
	},
	"lumber_hut": {
		"name": "伐木屋",
		"kind": "producer",
		"hp": 10.0,
		"cost": {"wood": 3},
		"ap_cost": 1,
		"produces": {"wood": 2},
		"upgrades_to": "",
	},
	"hut": {
		"name": "茅屋",
		"kind": "ap",
		"hp": 10.0,
		"cost": {"wood": 3},
		"ap_cost": 1,
		"ap_bonus": 0,
		"upgrades_to": "wood_house",
	},
	"wood_house": {
		"name": "木屋",
		"kind": "ap",
		"hp": 20.0,
		"cost": {"wood": 6},
		"ap_cost": 1,
		"ap_bonus": 1,
		"upgrades_to": "barracks",
	},
	"barracks": {
		"name": "营房",
		"kind": "ap",
		"hp": 30.0,
		"cost": {"wood": 10, "stone": 5},
		"ap_cost": 1,
		"ap_bonus": 2,
		"upgrades_to": "",
	},
	"quarry": {
		"name": "采石场",
		"kind": "producer",
		"hp": 15.0,
		"cost": {"wood": 5},
		"ap_cost": 1,
		"produces": {"stone": 1},
		"upgrades_to": "",
	},
	"hunting_hut": {
		"name": "猎屋",
		"kind": "producer",
		"hp": 10.0,
		"cost": {"wood": 4},
		"ap_cost": 1,
		"produces": {"food": 1},
		"upgrades_to": "",
	}
}

# ==============================================================================
# 3. Dinosaur Definitions (DINOS)
# ==============================================================================
const DINOS: Dictionary = {
	"raptor": {
		"name": "迅猛龙",
		"hp": 3.0,
		"speed": 4.0,
		"damage": 1.0,
		"attack_rate": 1.0,
		"targeting": "blocker_then_core",
		"size": Vector3(0.8, 0.8, 0.8),
	},
	"big_theropod": {
		"name": "大型兽脚类",
		"hp": 15.0,
		"speed": 2.0,
		"damage": 3.0,
		"attack_rate": 0.8,
		"targeting": "prefer_buildings",
		"size": Vector3(1.6, 1.6, 1.6),
	},
	"pterosaur": {
		"name": "翼龙",
		"hp": 2.0,
		"speed": 6.0,
		"damage": 1.0,
		"attack_rate": 1.2,
		"targeting": "ignore_walls",
		"size": Vector3(0.8, 0.5, 0.8),
	}
}

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
}
const PRODUCE_DELAY: float = 1.0

