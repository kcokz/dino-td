# res://scripts/core/BuildSystem.gd
class_name BuildSystem
extends Node

## Handles building placement validation, cost transactions, and entity instancing.
## Driven by Config.BUILDINGS and coordinated with GridManager, GameState, and EventBus.

const SCRIPT_PATHS: Dictionary = {
	"core": "res://scripts/entities/CoreCampfire.gd",
	"wall": "res://scripts/entities/Wall.gd",
	"gate": "res://scripts/entities/Gate.gd",
	"trap": "res://scripts/entities/Trap.gd",
	"fire": "res://scripts/entities/Fire.gd",
	# The traps laid in the way (GAME-DESIGN 6.0: 刺、砸、困).
	"spikes": "res://scripts/entities/CellTrap.gd",
	"deadfall": "res://scripts/entities/CellTrap.gd",
	"snare": "res://scripts/entities/CellTrap.gd",
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
## Everything is placed on the building grid (GridManager, Config.BUILD_CELL): a building
## fills a square of cells round the one it is put in, and may go wherever every one of them
## is free ground. The *_at calls take that cell; the older ones take a map tile and an
## optional exact point, and find the cell from them.

## The build cell a placement given as a map tile -- and, where the player clicked, the exact
## point -- lands in: the cell under the point, or the one in the middle of the tile.
func build_cell_for(cell: Vector2i, at_world: Variant = null) -> Vector2i:
	if grid_manager == null:
		_auto_resolve_dependencies()
	if grid_manager == null:
		return cell
	if at_world is Vector3:
		return grid_manager.world_to_build_cell(at_world)
	return grid_manager.tile_centre_build_cell(cell)

## Whether a `type_id` can go with its middle in build cell `build_cell`: every cell of it free
## ground, the game on, and the price in hand.
##
## NOT whether somebody is standing there (v0.6 round three: "人在pending建筑的地方pending建筑就不能放了，
## 比如我要造一排栅栏，人在中间就那人在的那一格就没法造了"). An order is not solid; what must not happen
## is a building going solid round a body, and that is held back where it happens -- at the last
## moment of its building (Building.add_build_progress) -- with the Hero stepping out of what he is
## raising before he raises it (Hero._process_building).
func can_place_at(type_id: String, build_cell: Vector2i) -> bool:
	if type_id.is_empty():
		return false
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(type_id):
		return false
	if grid_manager == null:
		_auto_resolve_dependencies()
	if grid_manager == null or not grid_manager.has_method("can_build_on"):
		return false
	var cells: Array[Vector2i] = grid_manager.footprint_cells(type_id, build_cell)
	if not grid_manager.can_build_on(cells):
		return false

	var gs = _get_game_state()
	if gs == null:
		return false
	if "is_game_over" in gs and gs.is_game_over:
		return false
	if "current_phase" in gs and int(gs.current_phase) != 0:
		return false
	var cost: Dictionary = cfg.BUILDINGS[type_id].get("cost", {})
	if gs.has_method("can_afford"):
		return gs.can_afford(cost)
	for r in cost:
		if gs.resources.get(r, 0) < int(cost[r]):
			return false
	return true

## Validates whether a building of type_id can be placed at a map tile -- at the build cell
## under `at_world` when it is given, or in the middle of the tile.
func can_place_building(type_id: String, cell: Vector2i, _is_blueprint: bool = false, at_world: Variant = null) -> bool:
	return can_place_at(type_id, build_cell_for(cell, at_world))

# ==============================================================================
# 2. Execution API
# ==============================================================================

## Pays for a `type_id`, makes it, stands it with its middle in `build_cell` and registers its
## cells. Returns the building, or null -- having spent nothing -- if it cannot go there.
## `facing` is the way a trap faces (Trap.FACINGS), given before it enters the tree so it lays its
## wire the right way from the first; anything that does not face ignores it.
func place_at(type_id: String, build_cell: Vector2i, parent_node: Node = null, start_as_blueprint: bool = false, facing: int = 0) -> Node:
	if not can_place_at(type_id, build_cell):
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
		var eb0 = _get_event_bus()
		if eb0 and eb0.has_signal("resources_changed"):
			eb0.resources_changed.emit(gs.resources)
	if not res_spent:
		return null

	# 2. Create Building Instance
	var building: Node = _instantiate_building(type_id)
	if building == null:
		if gs.has_method("add_resources"):
			gs.add_resources(cost)
		return null

	# 3. Setup entity data & position: the middle of its cells.
	var tile: Vector2i = grid_manager.world_to_cell(grid_manager.build_cell_to_world(build_cell))
	if building.has_method("setup"):
		building.setup(type_id, tile)
	else:
		if "building_type" in building:
			building.building_type = type_id
		if "cell_pos" in building:
			building.cell_pos = tile
		if "max_hp" in building:
			building.max_hp = float(b_data.get("hp", 10.0))
			building.current_hp = building.max_hp
	if "position" in building:
		building.position = grid_manager.build_cell_to_world(build_cell, 0.0)
	if "facing" in building:
		building.facing = facing

	# 4. Attach to scene tree if container available
	var target_parent = parent_node
	if target_parent == null:
		target_parent = buildings_container
	if target_parent == null and grid_manager and grid_manager.is_inside_tree():
		target_parent = grid_manager
	if target_parent and is_instance_valid(target_parent):
		target_parent.add_child(building)

	# 5. Its cells
	if not grid_manager.occupy_building(building, grid_manager.footprint_cells(type_id, build_cell)):
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

## Atomically deducts costs, instances the building entity, and registers occupancy, at a map
## tile -- at the build cell under `at_world` when it is given, or in the middle of the tile.
func place_building(type_id: String, cell: Vector2i, parent_node: Node = null, start_as_blueprint: bool = false, at_world: Variant = null) -> Node:
	return place_at(type_id, build_cell_for(cell, at_world), parent_node, start_as_blueprint)

# ==============================================================================
# 3. Entity Factory
# ==============================================================================

## The script a `type_id` is made of: by KIND, not by name -- a bone stake is a stake and a set
## crossbow is a trap, and each new building of a kind needs a Config row and nothing here -- unless
## the type has a script of its own (a gate is a wall that opens).
static func script_for(type_id: String) -> String:
	var kind: String = ""
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root:
		var cfg = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Config")
		if cfg and cfg.has_method("get_building_kind"):
			kind = String(cfg.get_building_kind(type_id))
	return String(SCRIPT_PATHS.get(type_id, SCRIPT_PATHS.get(kind, SCRIPT_PATHS["base"])))

func _instantiate_building(type_id: String) -> Node:
	var path: String = script_for(type_id)
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
