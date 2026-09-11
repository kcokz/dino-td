# res://scripts/core/GridManager.gd
class_name GridManager
extends Node3D

## Manages 3D world-to-grid coordinate conversion and tracks building occupancy.
## Ground plane is XZ (X=horizontal, Z=depth, Y=elevation).
## Driven by Config.TILE_SIZE (default 2.0).

@export var tile_size: float = 2.0

## Sparse lookup map: Vector2i -> Node (occupying building instance)
var occupied_cells: Dictionary = {}

func _init() -> void:
	_init_tile_size()
	_connect_event_bus()

func _ready() -> void:
	_init_tile_size()
	_connect_event_bus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var eb = _get_event_bus()
		if eb and is_instance_valid(eb) and eb.has_signal("building_destroyed"):
			if eb.building_destroyed.is_connected(_on_building_destroyed):
				eb.building_destroyed.disconnect(_on_building_destroyed)

func _init_tile_size() -> void:
	var cfg = _get_config()
	if cfg and "TILE_SIZE" in cfg:
		tile_size = float(cfg.TILE_SIZE)

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

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_destroyed"):
		if not eb.building_destroyed.is_connected(_on_building_destroyed):
			eb.building_destroyed.connect(_on_building_destroyed)

# ==============================================================================
# 1. Coordinate Mathematics
# ==============================================================================

## Converts continuous 3D world position to discrete 2D grid cell coordinate.
## Discards vertical elevation Y. Uses mathematical floor() for all quadrants.
func world_to_cell(pos: Vector3) -> Vector2i:
	var s: float = tile_size if tile_size > 0.0 else 2.0
	var cx: int = int(floor(pos.x / s))
	var cz: int = int(floor(pos.z / s))
	return Vector2i(cx, cz)

## Converts discrete 2D grid cell coordinate to continuous 3D world center point.
## Default y elevation is 0.0. Center of cell is offset by +0.5 * tile_size.
func cell_to_world(cell: Vector2i, y: float = 0.0) -> Vector3:
	var s: float = tile_size if tile_size > 0.0 else 2.0
	var wx: float = (float(cell.x) + 0.5) * s
	var wz: float = (float(cell.y) + 0.5) * s
	return Vector3(wx, y, wz)

## Returns the world-space minimum corner of a cell (useful for mesh bounding).
func cell_to_world_origin(cell: Vector2i, y: float = 0.0) -> Vector3:
	var s: float = tile_size if tile_size > 0.0 else 2.0
	return Vector3(float(cell.x) * s, y, float(cell.y) * s)

# ==============================================================================
# 2. Occupancy Tracking API
# ==============================================================================

## Checks whether a cell currently contains a living building.
## Self-heals if the occupying node was freed without unregistering.
func is_cell_occupied(cell: Vector2i) -> bool:
	if not occupied_cells.has(cell):
		return false
	var b = occupied_cells[cell]
	if not is_instance_valid(b) or b.is_queued_for_deletion():
		occupied_cells.erase(cell)
		return false
	if "is_destroyed" in b and b.is_destroyed:
		occupied_cells.erase(cell)
		return false
	return true

## Attempts to mark a cell as occupied by a building instance.
## Returns true on success, false if cell is already occupied or building is null.
func occupy_cell(cell: Vector2i, building: Node) -> bool:
	if building == null:
		return false
	if is_cell_occupied(cell):
		return false
	occupied_cells[cell] = building
	if "cell_pos" in building:
		building.cell_pos = cell
	return true

## Semantic alias for occupy_cell.
func set_cell_occupied(cell: Vector2i, building: Node) -> bool:
	return occupy_cell(cell, building)

## Vacates the specified cell. Safe no-op if cell is already unoccupied.
func vacate_cell(cell: Vector2i) -> void:
	if occupied_cells.has(cell):
		occupied_cells.erase(cell)

## Semantic alias for vacate_cell.
func clear_cell(cell: Vector2i) -> void:
	vacate_cell(cell)

## Returns the building Node at cell, or null if unoccupied or invalid.
func get_building_at(cell: Vector2i) -> Node:
	if not is_cell_occupied(cell):
		return null
	return occupied_cells.get(cell, null)

## Clears all occupied cells. Useful for level resets and unit test isolation.
func clear_grid() -> void:
	occupied_cells.clear()

## Returns an array of all living building nodes tracked by the grid.
func get_all_buildings() -> Array[Node]:
	var result: Array[Node] = []
	var cells_to_clean: Array[Vector2i] = []
	for cell in occupied_cells:
		var b = occupied_cells[cell]
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			result.append(b)
		else:
			cells_to_clean.append(cell)
	for c in cells_to_clean:
		occupied_cells.erase(c)
	return result

# ==============================================================================
# 3. Reactive Lifecycle Handlers
# ==============================================================================

## Automatically frees grid cell when building emits building_destroyed.
func _on_building_destroyed(building: Node) -> void:
	if building == null:
		return
	# Fast-path by cell_pos property
	if "cell_pos" in building:
		var c: Vector2i = building.cell_pos
		if occupied_cells.get(c) == building:
			vacate_cell(c)
			return
	# Fallback linear search
	for c in occupied_cells.keys():
		if occupied_cells[c] == building:
			vacate_cell(c)
			break
