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
## Checks config validity, occupancy, game-over state, and resource affordability.
## Which fine cell a placement lands in, for a type that is placed more finely than
## one per tile.
##
## `at_world` is where the player actually clicked. Without it -- a test placing by
## tile, or the Hero's own code -- the middle of the tile is used, so tile-level
## placement keeps working exactly as it did.
func fine_cell_for(type_id: String, cell: Vector2i, at_world: Variant) -> Vector2i:
	var cfg = _get_config()
	var divisions: int = int(cfg.get_cell_divisions(type_id)) if (cfg and cfg.has_method("get_cell_divisions")) else 1
	if divisions <= 1 or grid_manager == null:
		return cell
	if at_world is Vector3 and grid_manager.has_method("world_to_fine_cell"):
		return grid_manager.world_to_fine_cell(at_world, divisions)
	return Vector2i(cell.x * divisions + int(divisions / 2), cell.y * divisions + int(divisions / 2))

## Whether whatever already holds `cell` is itself a finely-placed thing, and so has
## room beside it, rather than a building that owns the whole tile.
func _tile_holder_is_fine(cell: Vector2i) -> bool:
	if grid_manager == null or not grid_manager.has_method("get_building_at"):
		return false
	var holder = grid_manager.get_building_at(cell)
	if holder == null or not is_instance_valid(holder) or not ("building_type" in holder):
		return false
	return _divisions(String(holder.building_type)) > 1

func _divisions(type_id: String) -> int:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_cell_divisions"):
		return int(cfg.get_cell_divisions(type_id))
	return 1

func can_place_building(type_id: String, cell: Vector2i, is_blueprint: bool = false, at_world: Variant = null) -> bool:
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
	# A finely-placed type asks about its own small square rather than the whole tile:
	# several stakes share a tile on purpose, which is the entire point of placing them
	# on a finer grid. Everything else still asks about the tile.
	var divisions: int = _divisions(type_id)
	if divisions > 1:
		if grid_manager.is_fine_cell_occupied(fine_cell_for(type_id, cell, at_world)):
			return false
		# Sharing a tile is only allowed with something else that is ALSO placed finely.
		# The first version of this replaced the tile check instead of adding to it, and
		# a stake could be driven straight through the wreck -- three tests caught it.
		if grid_manager.is_cell_occupied(cell) and not _tile_holder_is_fine(cell):
			return false
	elif grid_manager.is_cell_occupied(cell):
		return false
	# Hillside: not ground anyone builds on.
	if grid_manager.has_method("is_cell_blocked") and grid_manager.is_cell_blocked(cell):
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
func place_building(type_id: String, cell: Vector2i, parent_node: Node = null, start_as_blueprint: bool = false, at_world: Variant = null) -> Node:
	if not can_place_building(type_id, cell, start_as_blueprint, at_world):
		return null
	
	var cfg = _get_config()
	var gs = _get_game_state()
	var b_data: Dictionary = cfg.BUILDINGS[type_id]
	var cost: Dictionary = b_data.get("cost", {})
	
	# 1. Deduct Resources
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
		return null
	
	# 2. Create Building Instance
	var building: Node = _instantiate_building(type_id)
	if building == null:
		# Rollback costs
		if gs.has_method("add_resources"):
			gs.add_resources(cost)
		return null
	
	# 3. Setup entity data & position
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
	
	var divisions_for_place: int = _divisions(type_id)
	var fine: Vector2i = fine_cell_for(type_id, cell, at_world)
	if grid_manager and grid_manager.has_method("cell_to_world"):
		var world_pos: Vector3
		if divisions_for_place > 1:
			world_pos = grid_manager.fine_cell_to_world(fine, divisions_for_place, 0.0)
		else:
			world_pos = grid_manager.cell_to_world(cell, 0.0)
		if "position" in building:
			building.position = world_pos
	
	# 4. Attach to scene tree if container available
	var target_parent = parent_node
	if target_parent == null:
		target_parent = buildings_container
	if target_parent == null and grid_manager and grid_manager.is_inside_tree():
		target_parent = grid_manager
	
	if target_parent and is_instance_valid(target_parent):
		target_parent.add_child(building)
	
	# 5. Occupy grid cell
	if grid_manager and grid_manager.has_method("occupy_cell"):
		var occupied: bool
		if divisions_for_place > 1:
			occupied = grid_manager.occupy_fine_cell(fine, building, divisions_for_place)
		else:
			occupied = grid_manager.occupy_cell(cell, building)
		if not occupied:
			# Rollback if cell registration failed unexpectedly
			if gs.has_method("add_resources"):
				gs.add_resources(cost)
			building.free()
			return null
	
	# 6. Start construction if designated as blueprint
	if start_as_blueprint and building.has_method("start_construction"):
		building.start_construction()

	# 7. Broadcast placement event
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
