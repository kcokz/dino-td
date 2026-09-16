# res://scripts/core/BuildSystem.gd
class_name BuildSystem
extends Node

## Handles building placement validation, cost transactions, and entity instancing.
## Driven by Config.BUILDINGS and coordinated with GridManager, GameState, and EventBus.

const SCRIPT_PATHS: Dictionary = {
	"core": "res://scripts/entities/CoreCampfire.gd",
	"wall": "res://scripts/entities/Wall.gd",
	"tower": "res://scripts/entities/Tower.gd",
	"base": "res://scripts/entities/Building.gd"
}

@export var grid_manager: Node = null
@export var buildings_container: Node = null

func _ready() -> void:
	_auto_resolve_dependencies()

## Configures dependencies explicitly (dependency injection for tests).
func setup(p_grid_manager: Node, p_container: Node = null) -> void:
	grid_manager = p_grid_manager
	buildings_container = p_container

func set_grid_manager(p_grid_manager: Node) -> void:
	grid_manager = p_grid_manager

func _auto_resolve_dependencies() -> void:
	if grid_manager == null:
		if get_parent() and get_parent().has_node("GridManager"):
			grid_manager = get_parent().get_node("GridManager")
		elif is_inside_tree():
			grid_manager = get_tree().root.find_child("GridManager", true, false)

# ==============================================================================
# 1. Verification API
# ==============================================================================

## Validates whether a building of type_id can be placed at cell.
## Checks config validity, occupancy, game-over state, AP, and resource affordability.
func can_place_building(type_id: String, cell: Vector2i, is_blueprint: bool = false) -> bool:
	if type_id.is_empty():
		return false
	
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(type_id):
		return false
	
	var b_data: Dictionary = cfg.BUILDINGS[type_id]

	# Some buildings have to be worked out before they can be put up. The flag is
	# made at the cabin, so a turret cannot be reached on materials alone.
	if cfg.has_method("building_requires_unlock"):
		var needed: String = String(cfg.building_requires_unlock(type_id))
		if needed != "":
			var gs_unlock = _get_game_state()
			if gs_unlock == null or not gs_unlock.has_method("has_unlock") or not gs_unlock.has_unlock(needed):
				return false

	# Verify GridManager occupancy & Resource Node overlap
	if grid_manager == null:
		_auto_resolve_dependencies()
	if grid_manager == null or not grid_manager.has_method("is_cell_occupied"):
		return false
	if grid_manager.is_cell_occupied(cell):
		return false
	if grid_manager.has_method("is_resource_at_cell") and grid_manager.is_resource_at_cell(cell):
		return false
	
	# Verify Natural Resource Node overlap via Main fallback (v0.2)
	if is_inside_tree():
		var main_node = get_tree().root.find_child("Main", true, false)
		if main_node and main_node.has_method("is_resource_at_cell") and main_node.is_resource_at_cell(cell):
			return false
	
	# Verify GameState transactions
	var gs = _get_game_state()
	if gs == null:
		return false
	if "is_game_over" in gs and gs.is_game_over:
		return false
	if "current_phase" in gs and int(gs.current_phase) != 0:
		return false
	
	# Check AP
	var ap_cost: int = int(b_data.get("ap_cost", 1))
	if is_blueprint or (gs and "infinite_ap" in gs and gs.infinite_ap):
		ap_cost = 0
	if ap_cost > 0:
		if gs.has_method("can_spend_ap"):
			if not gs.can_spend_ap(ap_cost):
				return false
		elif "current_ap" in gs:
			if gs.current_ap < ap_cost:
				return false
	
	# Check Resources
	var cost: Dictionary = b_data.get("cost", {})
	if gs.has_method("can_afford"):
		if not gs.can_afford(cost):
			return false
	elif "resources" in gs:
		for r in cost:
			if gs.resources.get(r, 0) < int(cost[r]):
				return false
	
	return true

# ==============================================================================
# 2. Execution API
# ==============================================================================

## Atomically deducts costs, instances the building entity, and registers occupancy.
## Returns the instantiated building Node, or null if validation fails.
func place_building(type_id: String, cell: Vector2i, parent_node: Node = null, start_as_blueprint: bool = false) -> Node:
	if not can_place_building(type_id, cell, start_as_blueprint):
		return null
	
	var cfg = _get_config()
	var gs = _get_game_state()
	var b_data: Dictionary = cfg.BUILDINGS[type_id]
	var ap_cost: int = 0 if (start_as_blueprint or (gs and "infinite_ap" in gs and gs.infinite_ap)) else int(b_data.get("ap_cost", 1))
	var cost: Dictionary = b_data.get("cost", {})
	
	# 1. Deduct AP
	var ap_spent: bool = false
	if ap_cost <= 0:
		ap_spent = true
	elif gs.has_method("spend_ap"):
		ap_spent = gs.spend_ap(ap_cost)
	elif "current_ap" in gs and gs.current_ap >= ap_cost:
		gs.current_ap -= ap_cost
		ap_spent = true
		var eb = _get_event_bus()
		if eb and eb.has_signal("ap_changed"):
			eb.ap_changed.emit(gs.current_ap, gs.max_ap)
	
	if not ap_spent:
		return null
	
	# 2. Deduct Resources
	var res_spent: bool = false
	if gs.has_method("spend_resources"):
		res_spent = gs.spend_resources(cost)
	elif "resources" in gs:
		res_spent = true
		for r in cost:
			gs.resources[r] -= int(cost[r])
		var eb = _get_event_bus()
		if eb and eb.has_signal("resources_changed"):
			eb.resources_changed.emit(gs.resources)
	
	if not res_spent:
		# Rollback AP
		if ap_cost > 0 and "current_ap" in gs:
			gs.current_ap += ap_cost
		return null
	
	# 3. Create Building Instance
	var building: Node = _instantiate_building(type_id)
	if building == null:
		# Rollback costs
		if gs.has_method("add_resources"):
			gs.add_resources(cost)
		if "current_ap" in gs:
			gs.current_ap += ap_cost
		return null
	
	# 4. Setup entity data & position
	if building.has_method("setup"):
		building.setup(type_id, cell)
	else:
		if "building_type" in building:
			building.building_type = type_id
		if "cell_pos" in building:
			building.cell_pos = cell
		if "max_hp" in building:
			building.max_hp = float(b_data.get("hp", 10.0))
			building.current_hp = building.max_hp
	
	if grid_manager and grid_manager.has_method("cell_to_world"):
		var world_pos: Vector3 = grid_manager.cell_to_world(cell, 0.0)
		if "position" in building:
			building.position = world_pos
	
	# 5. Attach to scene tree if container available
	var target_parent = parent_node
	if target_parent == null:
		target_parent = buildings_container
	if target_parent == null and grid_manager and grid_manager.is_inside_tree():
		target_parent = grid_manager
	
	if target_parent and is_instance_valid(target_parent):
		target_parent.add_child(building)
	
	# 6. Occupy grid cell
	if grid_manager and grid_manager.has_method("occupy_cell"):
		var occupied = grid_manager.occupy_cell(cell, building)
		if not occupied:
			# Rollback if cell registration failed unexpectedly
			if gs.has_method("add_resources"):
				gs.add_resources(cost)
			if "current_ap" in gs:
				gs.current_ap += ap_cost
			building.free()
			return null
	
	# 7. Start construction if designated as blueprint
	if start_as_blueprint and building.has_method("start_construction"):
		building.start_construction()

	# 8. Broadcast placement event
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_placed"):
		eb.building_placed.emit(building)
	
	return building

# ==============================================================================
# 3. Entity Factory
# ==============================================================================

func _instantiate_building(type_id: String) -> Node:
	var path: String = SCRIPT_PATHS.get(type_id, SCRIPT_PATHS["base"])
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is GDScript:
			return res.new()
	return Node3D.new()

# ==============================================================================
# Resolvers
# ==============================================================================

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("EventBus")
	return null

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
