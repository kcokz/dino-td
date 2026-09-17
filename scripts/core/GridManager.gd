# res://scripts/core/GridManager.gd
class_name GridManager
extends Node3D

## Manages 3D world-to-grid coordinate conversion and tracks building occupancy.
## Ground plane is XZ (X=horizontal, Z=depth, Y=elevation).
## Driven by Config.TILE_SIZE (default 2.0).

@export var tile_size: float = 2.0

## Sparse lookup map: Vector2i -> Node (occupying building instance)
var occupied_cells: Dictionary = {}

## Sparse lookup map: Vector2i -> Node (occupying natural resource node)
var resource_cells: Dictionary = {}

## Terrain nobody crosses: hills. A set of cells rather than a map of nodes,
## because unlike a building this never comes and goes -- it is what the ground is.
## Kept apart from occupied_cells for exactly that reason: clearing the grid for a
## new game wipes the buildings and leaves the landscape where it was.
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

## Whether this cell is hillside. Static: it does not change for the whole game.
func is_cell_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell)

## Declares the map's terrain. Replaces whatever was there, so a level can be set
## up twice without the hills doubling.
func set_blocked_cells(cells: Array) -> void:
	blocked_cells.clear()
	for c in cells:
		if c is Vector2i:
			blocked_cells[c] = true

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
## Clears what a game put on the map. The terrain is not one of those things --
## hills survive a restart, because they are the map rather than anything the
## player did to it.
func clear_grid() -> void:
	occupied_cells.clear()
	resource_cells.clear()

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

# ==============================================================================
# 4. Grid Pathfinding & Navigation API (v0.1)
# ==============================================================================

## Checks whether a cell can be traversed by units (Hero / Dinos).
## Resource nodes block navigation (unless ignored).
## Unfinished blueprints (is_constructed == false) are walkable.
## If ignore_building is specified, its cell is treated as walkable.
func is_cell_walkable(cell: Vector2i, ignore_building: Node = null, terrain_only: bool = false) -> bool:
	if is_cell_blocked(cell):
		return false
	# Dinosaurs route around hills but not around buildings: a building in the way
	# is something they attack, and pathing politely around the fence the player
	# just built would make the fence pointless.
	if terrain_only:
		return true
	if is_resource_at_cell(cell):
		if ignore_building != null and resource_cells.get(cell) == ignore_building:
			pass
		else:
			return false
	if not occupied_cells.has(cell):
		return true
	var b = occupied_cells[cell]
	if not is_instance_valid(b) or b.is_queued_for_deletion():
		occupied_cells.erase(cell)
		return true
	if "is_destroyed" in b and b.is_destroyed:
		occupied_cells.erase(cell)
		return true
	# Unfinished blueprints do NOT physically block navigation
	if "is_constructed" in b and not b.is_constructed:
		return true
	# Caller-specified ignored building
	if ignore_building != null and b == ignore_building:
		return true
	return false

## Whether a walker standing at `from_pos` can get to `to_pos` over walkable ground.
##
## Flooded from the TARGET end, which is the whole trick. The case worth detecting is
## a blueprint sealed in by finished stakes, and a sealed pocket is small and finite:
## the flood closes and the answer is definite. Flooding from the walker instead
## would spread across open ground until it gave up -- the grid is unbounded -- and
## so could never prove anything, which is exactly how the first version of this
## failed.
##
## Neither end has to be walkable. The walker's own cell counts because he is plainly
## standing in it, and a blueprint's cell counts because unfinished work blocks
## nobody.
##
## `budget` caps the sweep. Running out means the target is in a region far too big
## to be a pocket, and the answer is then "assume he can get there": guessing "no"
## would stop the Hero working on an open map, while guessing "yes" costs a walk.
func is_reachable(from_pos: Vector3, to_pos: Vector3, budget: int = 400) -> bool:
	var goal: Vector2i = world_to_cell(from_pos)
	var start: Vector2i = world_to_cell(to_pos)
	if start == goal:
		return true
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	var offsets: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		if seen.size() >= budget:
			return true
		var current: Vector2i = queue[head]
		head += 1
		for off in offsets:
			var neighbor: Vector2i = current + off
			if neighbor == goal:
				return true
			if seen.has(neighbor) or not is_cell_walkable(neighbor):
				continue
			seen[neighbor] = true
			queue.append(neighbor)
	return false

## Finds an A* path of 3D world waypoints from from_pos to to_pos.
##
## `terrain_only` routes around the landscape and nothing else -- what a dinosaur
## wants, since a building in its way is a thing to bite rather than walk around.
func find_path(from_pos: Vector3, to_pos: Vector3, ignore_building: Node = null, terrain_only: bool = false) -> Array[Vector3]:
	var start_cell: Vector2i = world_to_cell(from_pos)
	var goal_cell: Vector2i = world_to_cell(to_pos)

	if start_cell == goal_cell:
		return [to_pos]

	# If goal_cell is blocked by an obstacle, locate the closest walkable adjacent cell
	if not is_cell_walkable(goal_cell, ignore_building, terrain_only):
		var best_adj: Vector2i = goal_cell
		var best_dist: float = 999999.0
		var offsets = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
		]
		for off in offsets:
			var adj = goal_cell + off
			if is_cell_walkable(adj, ignore_building, terrain_only):
				var d = cell_to_world(adj).distance_to(from_pos)
				if d < best_dist:
					best_dist = d
					best_adj = adj
		if best_adj != goal_cell:
			goal_cell = best_adj
		else:
			return [to_pos]

	# A* Graph Search
	var open_set: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_cell: 0.0}
	var f_score: Dictionary = {start_cell: float(start_cell.distance_to(goal_cell))}

	var cardinals = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var diagonals = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

	var iterations: int = 0
	var max_iterations: int = 800

	while not open_set.is_empty() and iterations < max_iterations:
		iterations += 1

		# Pop lowest f_score node
		var current: Vector2i = open_set[0]
		var lowest_f: float = f_score.get(current, 999999.0)
		var lowest_idx: int = 0
		for idx in range(1, open_set.size()):
			var node = open_set[idx]
			var f: float = f_score.get(node, 999999.0)
			if f < lowest_f:
				lowest_f = f
				current = node
				lowest_idx = idx

		if current == goal_cell:
			# Reconstruct path
			var cell_path: Array[Vector2i] = [current]
			while came_from.has(current):
				current = came_from[current]
				cell_path.append(current)
			cell_path.reverse()

			var raw_world_path: Array[Vector3] = []
			for i in range(1, cell_path.size()):
				if i == cell_path.size() - 1:
					raw_world_path.append(to_pos)
				else:
					raw_world_path.append(cell_to_world(cell_path[i]))

			return _smooth_path(from_pos, raw_world_path, ignore_building, terrain_only)

		open_set.remove_at(lowest_idx)
		var cur_g: float = g_score.get(current, 999999.0)

		# 1. Cardinal neighbors
		for off in cardinals:
			var neighbor = current + off
			if not is_cell_walkable(neighbor, ignore_building, terrain_only):
				continue
			var tent_g = cur_g + 1.0
			if tent_g < g_score.get(neighbor, 999999.0):
				came_from[neighbor] = current
				g_score[neighbor] = tent_g
				f_score[neighbor] = tent_g + float(neighbor.distance_to(goal_cell))
				if not (neighbor in open_set):
					open_set.append(neighbor)

		# 2. Diagonal neighbors (cutting corner prevention)
		for off in diagonals:
			var neighbor = current + off
			if not is_cell_walkable(neighbor, ignore_building, terrain_only):
				continue
			var side1 = current + Vector2i(off.x, 0)
			var side2 = current + Vector2i(0, off.y)
			if not is_cell_walkable(side1, ignore_building, terrain_only) or not is_cell_walkable(side2, ignore_building, terrain_only):
				continue
			var tent_g = cur_g + 1.414
			if tent_g < g_score.get(neighbor, 999999.0):
				came_from[neighbor] = current
				g_score[neighbor] = tent_g
				f_score[neighbor] = tent_g + float(neighbor.distance_to(goal_cell))
				if not (neighbor in open_set):
					open_set.append(neighbor)

	# Fallback if unreached
	return [to_pos]

## Optimizes waypoint sequence by removing redundant intermediate nodes with unobstructed line-of-sight.
func _smooth_path(start_pos: Vector3, raw_path: Array[Vector3], ignore_building: Node = null, terrain_only: bool = false) -> Array[Vector3]:
	if raw_path.size() <= 1:
		return raw_path

	var smoothed: Array[Vector3] = []
	var curr: Vector3 = start_pos
	var i: int = 0

	while i < raw_path.size():
		var furthest: int = i
		for j in range(raw_path.size() - 1, i, -1):
			if _has_line_of_sight(curr, raw_path[j], ignore_building, terrain_only):
				furthest = j
				break
		smoothed.append(raw_path[furthest])
		curr = raw_path[furthest]
		i = furthest + 1

	return smoothed

## Line-of-sight ray tracing on grid cells. Returns true if straight path is unobstructed.
func _has_line_of_sight(from_pt: Vector3, to_pt: Vector3, ignore_building: Node = null, terrain_only: bool = false) -> bool:
	var dist = from_pt.distance_to(to_pt)
	if dist <= 0.1:
		return true
	var steps: int = int(ceil(dist / (tile_size * 0.4)))
	for s in range(1, steps + 1):
		var t = float(s) / float(steps)
		var sample = from_pt.lerp(to_pt, t)
		var c = world_to_cell(sample)
		if not is_cell_walkable(c, ignore_building, terrain_only):
			return false
	return true
