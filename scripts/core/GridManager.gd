# res://scripts/core/GridManager.gd
class_name GridManager
extends Node3D

## Where things stand. Two grids, and each answers only its own questions:
##
##   THE MAP'S TILES (Config.TILE_SIZE, two metres) -- where the map puts things: the hills
##   nobody crosses, the trees and rocks the Hero works, the cabin's and the nest's places.
##
##   THE BUILDING GRID (Config.BUILD_CELL, a metre) -- where anything built stands. Every
##   building fills whole cells of it; a cell is taken or it is free, and that is the whole
##   of the placement rule (v0.6 round two: "墙体逻辑简单清晰，墙必须让它们和别的建筑能更贴合").
##   The finer grid stakes used to be laid on, and the whole-tile claim of everything else,
##   are gone, and with them the tower that could only go up a tile away from a fence.
##
## Where anybody can WALK is neither grid's question: it is the navigation mesh's, baked from
## the colliders the buildings are (NavMaps).

@export var tile_size: float = 2.0

## The building grid: build cell (Vector2i) -> the building standing in it. A building of more
## than one cell (the cabin) is in every one of them.
var building_cells: Dictionary = {}

## Tile (Vector2i) -> the natural resource node standing in it.
var resource_cells: Dictionary = {}

## Terrain nobody crosses: hills. A set of tiles rather than a map of nodes, because unlike a
## building this never comes and goes -- it is what the ground is. Kept apart from the
## buildings for exactly that reason: clearing the grid for a new game wipes the buildings and
## leaves the landscape where it was.
var blocked_cells: Dictionary = {}

func _init() -> void:
	_init_tile_size()
	_connect_event_bus()

func _ready() -> void:
	add_to_group("grid_manager")
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
# 1. The map's tiles
# ==============================================================================

## Converts continuous 3D world position to discrete 2D grid cell coordinate.
## Discards vertical elevation Y. Uses mathematical floor() for all quadrants.
func world_to_cell(pos: Vector3) -> Vector2i:
	var s: float = tile_size if tile_size > 0.0 else 2.0
	return Vector2i(int(floor(pos.x / s)), int(floor(pos.z / s)))

## Converts discrete 2D grid cell coordinate to continuous 3D world center point.
## Default y elevation is 0.0. Center of cell is offset by +0.5 * tile_size.
func cell_to_world(cell: Vector2i, y: float = 0.0) -> Vector3:
	var s: float = tile_size if tile_size > 0.0 else 2.0
	return Vector3((float(cell.x) + 0.5) * s, y, (float(cell.y) + 0.5) * s)

## Returns the world-space minimum corner of a cell (useful for mesh bounding).
func cell_to_world_origin(cell: Vector2i, y: float = 0.0) -> Vector3:
	var s: float = tile_size if tile_size > 0.0 else 2.0
	return Vector3(float(cell.x) * s, y, float(cell.y) * s)

## Whether this tile is hillside. Static: it does not change for the whole game.
func is_cell_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell)

## Declares the map's terrain. Replaces whatever was there, so a level can be set up twice
## without the hills doubling.
func set_blocked_cells(cells: Array) -> void:
	blocked_cells.clear()
	for c in cells:
		if c is Vector2i:
			blocked_cells[c] = true

## Every tile the segment from `from_pos` to `to_pos` passes through, in order -- or, with
## `size`, every cell of a grid that size.
##
## A grid TRAVERSAL, not a set of point samples: a segment can clip the corner of a cell over a
## shorter distance than any sample spacing, and a missed cell is an answer that is nearly right.
## The run is CONNECTED -- it steps one cell at a time and never cuts a corner -- so a wall
## dragged diagonally has no diagonal gaps in it.
func cells_on_line(from_pos: Vector3, to_pos: Vector3, size: float = 0.0) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if size <= 0.0:
		size = tile_size if tile_size > 0.0 else 2.0
	var x0: float = from_pos.x / size
	var z0: float = from_pos.z / size
	var x1: float = to_pos.x / size
	var z1: float = to_pos.z / size
	var cx: int = int(floor(x0))
	var cz: int = int(floor(z0))
	out.append(Vector2i(cx, cz))
	var end_x: int = int(floor(x1))
	var end_z: int = int(floor(z1))
	if cx == end_x and cz == end_z:
		return out

	var dx: float = x1 - x0
	var dz: float = z1 - z0
	var step_x: int = 0 if is_zero_approx(dx) else (1 if dx > 0.0 else -1)
	var step_z: int = 0 if is_zero_approx(dz) else (1 if dz > 0.0 else -1)
	# How much of the segment it takes to cross one whole cell on each axis...
	var t_delta_x: float = INF if step_x == 0 else absf(1.0 / dx)
	var t_delta_z: float = INF if step_z == 0 else absf(1.0 / dz)
	# ...and how much to reach the first boundary, which is the part that gets a corner right:
	# whichever boundary is nearer is the one crossed next.
	var t_max_x: float = INF
	if step_x > 0:
		t_max_x = (float(cx + 1) - x0) / dx
	elif step_x < 0:
		t_max_x = (float(cx) - x0) / dx
	var t_max_z: float = INF
	if step_z > 0:
		t_max_z = (float(cz + 1) - z0) / dz
	elif step_z < 0:
		t_max_z = (float(cz) - z0) / dz

	var guard: int = 0
	while (cx != end_x or cz != end_z) and guard < 4096:
		guard += 1
		if minf(t_max_x, t_max_z) > 1.0:
			break
		if t_max_x < t_max_z:
			cx += step_x
			t_max_x += t_delta_x
		else:
			cz += step_z
			t_max_z += t_delta_z
		out.append(Vector2i(cx, cz))
	return out

# ==============================================================================
# 2. The building grid
# ==============================================================================

## The side of one cell of the building grid, in metres (Config.BUILD_CELL).
func build_cell_size() -> float:
	var cfg = _get_config()
	return float(cfg.BUILD_CELL) if (cfg and "BUILD_CELL" in cfg) else 1.0

## The build cell a world point falls in. Cells are centred on whole multiples of their size,
## so the middle of every tile is the middle of a cell.
func world_to_build_cell(pos: Vector3) -> Vector2i:
	var s: float = build_cell_size()
	return Vector2i(int(floor(pos.x / s + 0.5)), int(floor(pos.z / s + 0.5)))

## The middle of a build cell, in the world.
func build_cell_to_world(cell: Vector2i, y: float = 0.0) -> Vector3:
	var s: float = build_cell_size()
	return Vector3(float(cell.x) * s, y, float(cell.y) * s)

## The build cell in the middle of `tile`.
func tile_centre_build_cell(tile: Vector2i) -> Vector2i:
	return world_to_build_cell(cell_to_world(tile))

## The cells a `type_id` standing with its middle in `centre` takes: a block of
## Config.get_building_size round it.
func footprint_cells(type_id: String, centre: Vector2i) -> Array[Vector2i]:
	var cfg = _get_config()
	var size: Vector2i = cfg.get_building_size(type_id) if (cfg and cfg.has_method("get_building_size")) else Vector2i.ONE
	var half := Vector2i((size.x - 1) / 2, (size.y - 1) / 2)
	var out: Array[Vector2i] = []
	for dz in range(-half.y, size.y - half.y):
		for dx in range(-half.x, size.x - half.x):
			out.append(centre + Vector2i(dx, dz))
	return out

## The building standing in build cell `cell`, or null. Forgets one that has gone -- freed, or
## destroyed without anybody saying so.
func building_in_build_cell(cell: Vector2i) -> Node:
	if not building_cells.has(cell):
		return null
	var b = building_cells[cell]
	if not is_instance_valid(b) or b.is_queued_for_deletion() or ("is_destroyed" in b and b.is_destroyed):
		building_cells.erase(cell)
		return null
	return b

func is_build_cell_taken(cell: Vector2i) -> bool:
	return building_in_build_cell(cell) != null

## Whether anything could be built in `cell` as far as the ground goes: no hillside under any
## part of it, and no tree or rock standing in it. Buildings are the other half (taken).
func is_build_cell_ground(cell: Vector2i) -> bool:
	var s: float = build_cell_size()
	var middle: Vector3 = build_cell_to_world(cell)
	var lo := Vector3(middle.x - s * 0.5, 0.0, middle.z - s * 0.5)
	var hi := Vector3(middle.x + s * 0.5, 0.0, middle.z + s * 0.5)
	# Every tile it overlaps: a cell on a tile's edge is half in the next tile.
	var t_lo: Vector2i = world_to_cell(lo + Vector3(0.001, 0.0, 0.001))
	var t_hi: Vector2i = world_to_cell(hi - Vector3(0.001, 0.0, 0.001))
	for tz in range(t_lo.y, t_hi.y + 1):
		for tx in range(t_lo.x, t_hi.x + 1):
			var tile := Vector2i(tx, tz)
			if is_cell_blocked(tile):
				return false
			if is_resource_at_cell(tile) and _resource_reaches(resource_cells[tile], lo, hi):
				return false
	return true

## Whether `node` -- a tree's trunk, a rock -- stands in the box from `lo` to `hi` at all.
func _resource_reaches(node: Node, lo: Vector3, hi: Vector3) -> bool:
	if not (node is Node3D):
		return true
	var r: float = float(node.block_radius()) if node.has_method("block_radius") else tile_size * 0.5
	var p: Vector3 = (node as Node3D).global_position if (node as Node3D).is_inside_tree() else (node as Node3D).position
	var dx: float = maxf(maxf(lo.x - p.x, 0.0), p.x - hi.x)
	var dz: float = maxf(maxf(lo.z - p.z, 0.0), p.z - hi.z)
	return Vector2(dx, dz).length() < r

## Whether every one of `cells` is free and on buildable ground.
func can_build_on(cells: Array) -> bool:
	for c in cells:
		if is_build_cell_taken(c) or not is_build_cell_ground(c):
			return false
	return true

## Puts `building` in `cells`. Fails, changing nothing, when any of them is taken.
func occupy_building(building: Node, cells: Array) -> bool:
	if building == null:
		return false
	for c in cells:
		if is_build_cell_taken(c):
			return false
	for c in cells:
		building_cells[c] = building
	if not cells.is_empty() and "cell_pos" in building:
		building.cell_pos = world_to_cell(build_cell_to_world(cells[cells.size() / 2]))
	return true

## Takes `building` out of every cell it held.
func vacate_building(building: Node) -> void:
	for c in building_cells.keys():
		if building_cells[c] == building:
			building_cells.erase(c)

## The build cells a run from `from_pos` to `to_pos` covers, middle to middle, connected.
func build_cells_on_line(from_pos: Vector3, to_pos: Vector3) -> Array[Vector2i]:
	var s: float = build_cell_size()
	# The traversal works on cells that START at whole multiples; these are centred on them.
	var shift := Vector3(s * 0.5, 0.0, s * 0.5)
	return cells_on_line(from_pos + shift, to_pos + shift, s)

## The building at a world POINT: whatever stands in the build cell under it.
func building_at_point(pos: Vector3) -> Node:
	return building_in_build_cell(world_to_build_cell(pos))

# ==============================================================================
# 2a. Asked by tile, for the callers that think in tiles
# ==============================================================================
## A tile is two metres and holds several cells of the building grid, and one on each of its
## edges it shares with the tile beside it. These answer for all of them.

## The build cells that overlap `tile`.
func build_cells_in_tile(tile: Vector2i) -> Array[Vector2i]:
	var centre: Vector2i = tile_centre_build_cell(tile)
	var reach: int = int(ceil(tile_size * 0.5 / build_cell_size()))
	var out: Array[Vector2i] = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			out.append(centre + Vector2i(dx, dz))
	return out

## Whether anything built stands in `tile`.
func is_cell_occupied(cell: Vector2i) -> bool:
	return get_building_at(cell) != null

## Something built standing in `tile`: the one in its middle, or any in it.
func get_building_at(cell: Vector2i) -> Node:
	var middle: Node = building_in_build_cell(tile_centre_build_cell(cell))
	if middle != null:
		return middle
	for c in build_cells_in_tile(cell):
		var b: Node = building_in_build_cell(c)
		if b != null:
			return b
	return null

## Stands `building` in `tile`: its cells round the tile's middle -- how a fixture puts something
## up by hand, and how the level places the nest.
func occupy_cell(cell: Vector2i, building: Node) -> bool:
	if building == null:
		return false
	var type_id: String = String(building.building_type) if "building_type" in building else ""
	var ok: bool = occupy_building(building, footprint_cells(type_id, tile_centre_build_cell(cell)))
	if ok and "cell_pos" in building:
		building.cell_pos = cell
	return ok

## Semantic alias for occupy_cell.
func set_cell_occupied(cell: Vector2i, building: Node) -> bool:
	return occupy_cell(cell, building)

## Takes whatever stands in the middle of `tile` out of the grid.
func vacate_cell(cell: Vector2i) -> void:
	var b: Node = building_in_build_cell(tile_centre_build_cell(cell))
	if b != null:
		vacate_building(b)

## Semantic alias for vacate_cell.
func clear_cell(cell: Vector2i) -> void:
	vacate_cell(cell)

## Clears what a game put on the map. The terrain is not one of those things -- hills survive
## a restart, because they are the map rather than anything the player did to it.
func clear_grid() -> void:
	building_cells.clear()
	resource_cells.clear()

## Every living building on the grid, each once however many cells it takes.
func get_all_buildings() -> Array[Node]:
	var result: Array[Node] = []
	var gone: Array[Vector2i] = []
	for cell in building_cells:
		var b = building_cells[cell]
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			gone.append(cell)
		elif not result.has(b):
			result.append(b)
	for c in gone:
		building_cells.erase(c)
	return result

# ==============================================================================
# 2b. Resource Occupancy Tracking API (v0.2)
# ==============================================================================

## Checks whether a cell currently contains an undepleted natural resource node.
func is_resource_at_cell(cell: Vector2i) -> bool:
	if not resource_cells.has(cell):
		return false
	var node = resource_cells[cell]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		resource_cells.erase(cell)
		return false
	if "is_depleted" in node and node.is_depleted:
		resource_cells.erase(cell)
		return false
	return true

## Marks a cell as occupied by a natural resource node.
func occupy_resource_cell(cell: Vector2i, node: Node) -> bool:
	if node == null:
		return false
	if is_resource_at_cell(cell):
		return false
	resource_cells[cell] = node
	if "cell_pos" in node:
		node.cell_pos = cell
	return true

## Vacates the natural resource from the specified cell.
func vacate_resource_cell(cell: Vector2i) -> void:
	if resource_cells.has(cell):
		resource_cells.erase(cell)

## Returns the resource Node at cell, or null if unoccupied or depleted.
func get_resource_at(cell: Vector2i) -> Node:
	if not is_resource_at_cell(cell):
		return null
	return resource_cells.get(cell, null)

## Clears all tracked resource cells.
func clear_resource_cells() -> void:
	resource_cells.clear()

# ==============================================================================
# 3. Reactive Lifecycle Handlers
# ==============================================================================

## A building that comes down gives back every cell it held.
func _on_building_destroyed(building: Node) -> void:
	if building != null:
		vacate_building(building)
