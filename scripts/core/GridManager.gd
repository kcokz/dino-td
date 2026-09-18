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

## Buildings placed on a finer grid than the tile, keyed by fine coordinate.
##
## Only stakes use this today. A stake is small and a tile is two metres, so one stake
## per tile left a fence looking like a row of lonely spikes with holes between them --
## the cone was never the problem, the GRID was.
##
## Deliberately a SECOND register rather than a replacement for occupied_cells. Every
## tile-level question in the game -- can something walk here, what did I click, is this
## a barrier -- still goes through occupied_cells and gets the same answer it always
## did. This only decides where a stake may be PUT.
var fine_cells: Dictionary = {}

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

# ==============================================================================
# 2a. The finer grid, for things smaller than a tile
# ==============================================================================

## The fine coordinate a world point falls in, at `divisions` positions per tile edge.
func world_to_fine_cell(pos: Vector3, divisions: int) -> Vector2i:
	var step: float = _fine_step(divisions)
	return Vector2i(int(floor(pos.x / step)), int(floor(pos.z / step)))

## The centre of a fine cell, in world space.
func fine_cell_to_world(cell: Vector2i, divisions: int, y: float = 0.0) -> Vector3:
	var step: float = _fine_step(divisions)
	return Vector3((float(cell.x) + 0.5) * step, y, (float(cell.y) + 0.5) * step)

## Which tile a fine cell belongs to. Integer floor division, so it is correct on the
## negative side of the origin too -- Godot's `/` truncates towards zero, which would
## put fine cell -1 in tile 0.
func fine_cell_to_cell(cell: Vector2i, divisions: int) -> Vector2i:
	var d: int = maxi(1, divisions)
	return Vector2i(int(floor(float(cell.x) / float(d))), int(floor(float(cell.y) / float(d))))

## Whether something in this fine cell actually stands in the way.
##
## Not the same question as is_fine_cell_occupied, which is about whether the SPOT is
## taken. A blueprint takes the spot -- you cannot put a second stake on it -- and
## obstructs nobody, which is the same distinction the tile level has always made. Not
## making it here meant a fence you had only ORDERED stopped a raid dead.
func is_fine_cell_solid(cell: Vector2i) -> bool:
	if not is_fine_cell_occupied(cell):
		return false
	var b = fine_cells[cell]
	return not ("is_constructed" in b and not b.is_constructed)

func is_fine_cell_occupied(cell: Vector2i) -> bool:
	if not fine_cells.has(cell):
		return false
	var b = fine_cells[cell]
	if not is_instance_valid(b) or b.is_queued_for_deletion():
		fine_cells.erase(cell)
		return false
	if "is_destroyed" in b and b.is_destroyed:
		fine_cells.erase(cell)
		return false
	return true

## Puts `building` in a fine cell, and makes it the tile's occupant if the tile has
## none yet.
##
## Registering in BOTH is what lets tile-level questions -- what did I click, what is
## standing here -- keep working. What it does NOT decide any more is whether the tile
## can be walked through: for that see `fine_occupants_seal_cell`, because one 0.62m
## stake in a 2m tile is something to walk round rather than a wall.
func occupy_fine_cell(cell: Vector2i, building: Node, divisions: int) -> bool:
	if building == null or is_fine_cell_occupied(cell):
		return false
	fine_cells[cell] = building
	if "fine_pos" in building:
		building.fine_pos = cell
	var tile: Vector2i = fine_cell_to_cell(cell, divisions)
	if "cell_pos" in building:
		building.cell_pos = tile
	if not is_cell_occupied(tile):
		occupied_cells[tile] = building
	return true

func vacate_fine_cell(cell: Vector2i) -> void:
	if fine_cells.has(cell):
		fine_cells.erase(cell)

## Every fine building still standing inside `tile`.
func fine_buildings_in_cell(tile: Vector2i, divisions: int) -> Array[Node]:
	var out: Array[Node] = []
	for fine in fine_cells.keys():
		if fine_cell_to_cell(fine, divisions) != tile:
			continue
		if is_fine_cell_occupied(fine):
			out.append(fine_cells[fine])
	return out

## How finely the building standing in `tile` is placed, or 1 when nothing there is
## placed finely at all.
func _fine_divisions_in(tile: Vector2i) -> int:
	if not occupied_cells.has(tile):
		return 1
	var b = occupied_cells[tile]
	if not is_instance_valid(b):
		return 1
	return _divisions_of(b)

## Whether what stands in `tile` still leaves room to walk through it.
##
## THE POINT: a stake is 0.62m of a 2m tile. One of them leaves most of the tile open,
## and a gap the player can plainly see beside it has to be a gap he can use. Before
## this, the first stake in a tile claimed the whole tile, so a cone standing next to a
## hillside sealed a lane that was visibly two-thirds empty.
##
## What closes a tile is a RUN of them: cones side by side with nothing you could get
## between. So the question asked here is the honest one -- CAN YOU STILL CROSS THIS TILE
## -- answered by walking the free fine cells rather than by counting anything.
##
## A tile is open only if you could cross it both ways: north to south AND west to east.
## Failing either means a fence runs through it, and a walker goes round the tile.
##
## The first version of this looked for a complete row or column, which only ever
## recognised fences drawn along the axes. A CURVE -- which is what people actually draw
## -- put two or three cones diagonally across a tile, filled no row and no column, and
## sealed nothing, however solid it looked.
##
## Anything not placed finely fills its tile, as it always has. So does a tile whose
## occupant was registered at tile level only: with nothing finer on record there is
## nothing to say a way exists, and inventing one would open holes in the map.
func occupant_leaves_a_way_through(tile: Vector2i) -> bool:
	var divisions: int = _fine_divisions_in(tile)
	if divisions <= 1:
		return false
	var base := Vector2i(tile.x * divisions, tile.y * divisions)
	var free: Array[bool] = []
	free.resize(divisions * divisions)
	# Two different questions, and conflating them was a bug in its own right.
	#
	# ON RECORD: is anything registered in this tile's fine cells at all? If not, nothing
	# finer is known about it and it fills its tile, as everything did before fine
	# placement existed. Inventing a way through would open holes in the map.
	#
	# SOLID: is something actually standing there? A blueprint takes its spot -- nothing
	# else can go on it -- and obstructs nobody, so it is on record without being solid.
	# A fence you have only ORDERED used to stop a raid dead.
	var on_record: bool = false
	for dz in range(divisions):
		for dx in range(divisions):
			var at := base + Vector2i(dx, dz)
			on_record = on_record or is_fine_cell_occupied(at)
			free[dz * divisions + dx] = not is_fine_cell_solid(at)
	if not on_record:
		return false
	return _crosses(free, divisions, true) and _crosses(free, divisions, false)

## Whether free cells connect one side of the sub-grid to the other: top to bottom when
## `vertical`, left to right otherwise.
##
## Four-connected on purpose. A stake very nearly fills its fine cell, so two of them
## touching at the corners leave a slit a few centimetres wide -- which is a wall, not a
## doorway, and letting anything squeeze through it diagonally would make every fence
## drawn on a curve leak.
func _crosses(free: Array[bool], divisions: int, vertical: bool) -> bool:
	var queue: Array[Vector2i] = []
	var seen: Dictionary = {}
	for i in range(divisions):
		var start := Vector2i(i, 0) if vertical else Vector2i(0, i)
		if free[start.y * divisions + start.x]:
			queue.append(start)
			seen[start] = true
	var far: int = divisions - 1
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		if (vertical and at.y == far) or (not vertical and at.x == far):
			return true
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = at + off
			if next.x < 0 or next.y < 0 or next.x >= divisions or next.y >= divisions:
				continue
			if seen.has(next) or not free[next.y * divisions + next.x]:
				continue
			seen[next] = true
			queue.append(next)
	return false

## The point inside `tile` a walker should actually aim at: its centre, unless something
## small is standing there, in which case the nearest fine cell that is free.
##
## Without this, a path through a tile that holds a stake aims straight at the stake,
## and the walker grinds against a cone he had every room to step around.
func walkable_point_in_cell(tile: Vector2i, y: float = 0.0) -> Vector3:
	var centre: Vector3 = cell_to_world(tile, y)
	var divisions: int = _fine_divisions_in(tile)
	if divisions <= 1:
		return centre
	var base := Vector2i(tile.x * divisions, tile.y * divisions)
	var half: int = divisions / 2
	if not is_fine_cell_solid(base + Vector2i(half, half)):
		return centre
	var best: Vector3 = centre
	var best_d: float = -1.0
	for dz in range(divisions):
		for dx in range(divisions):
			var fine := base + Vector2i(dx, dz)
			if is_fine_cell_solid(fine):
				continue
			var p: Vector3 = fine_cell_to_world(fine, divisions, y)
			var d: float = p.distance_squared_to(centre)
			if best_d < 0.0 or d < best_d:
				best_d = d
				best = p
	return best

func _fine_step(divisions: int) -> float:
	var s: float = tile_size if tile_size > 0.0 else 2.0
	return s / float(maxi(1, divisions))

## Vacates the specified cell. Safe no-op if cell is already unoccupied.
func vacate_cell(cell: Vector2i) -> void:
	if occupied_cells.has(cell):
		occupied_cells.erase(cell)

## Semantic alias for vacate_cell.
func clear_cell(cell: Vector2i) -> void:
	vacate_cell(cell)

## The building at a world POINT rather than in a tile.
##
## With several stakes sharing a tile, asking the TILE gets you whichever of them
## happens to be registered as its occupant -- not the one under the cursor. So
## right-clicking one stake of a fence acted on a different stake, and when that other
## one was already finished the click did nothing at all.
func building_at_point(pos: Vector3) -> Node:
	var tile: Vector2i = world_to_cell(pos)
	var divisions: int = _fine_divisions_in(tile)
	if divisions > 1:
		var fine: Vector2i = world_to_fine_cell(pos, divisions)
		if is_fine_cell_occupied(fine):
			return fine_cells[fine]
	return get_building_at(tile)

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
	fine_cells.clear()
	resource_cells.clear()

## How finely `building`'s type is placed. Asked of Config rather than stored, so the
## answer cannot go stale when the number is tuned.
func _divisions_of(building: Node) -> int:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_cell_divisions") and "building_type" in building:
		return int(cfg.get_cell_divisions(String(building.building_type)))
	return 1

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

	# Fine buildings first: several of them can share a tile, and only one of them is
	# registered as the tile's occupant. Losing that one must hand the tile to another
	# stake standing in it rather than opening the tile up while a fence is still there.
	if "fine_pos" in building:
		var fine: Vector2i = building.fine_pos
		if fine_cells.get(fine) == building:
			fine_cells.erase(fine)
		var divisions: int = _divisions_of(building)
		var tile_of_fine: Vector2i = fine_cell_to_cell(fine, divisions)
		if occupied_cells.get(tile_of_fine) == building:
			occupied_cells.erase(tile_of_fine)
			var survivors := fine_buildings_in_cell(tile_of_fine, divisions)
			if not survivors.is_empty():
				occupied_cells[tile_of_fine] = survivors[0]
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
	# terrain_only asks the narrower question "is the LANDSCAPE in the way", ignoring
	# anything built. It used to be what dinosaurs pathed with, on the theory that going
	# politely round a fence made the fence pointless -- which had it backwards, and left
	# raids walking into walls. Nothing routes with it now; it survives because "can this
	# ground be stood on at all" is still a separate and useful question from "is it free".
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
	# A building smaller than its tile does not fill its tile. Only a run of them does.
	return occupant_leaves_a_way_through(cell)

## Every cell the segment from `from_pos` to `to_pos` passes through, in order.
##
## A grid TRAVERSAL, not a set of point samples. The difference is the whole reason this
## exists: sampling the line every half metre looks equivalent and is not, because a
## segment can clip the corner of a cell over a shorter distance than the sample spacing
## and be missed entirely.
##
## One missed cell is a dinosaur told the way ahead is clear, walking into a hillside at
## four metres a second, being pushed back out, and doing it again the next frame for as
## long as anyone cares to watch. That is what this fixes, and it is why the answer has
## to be exact rather than nearly right.
func cells_on_line(from_pos: Vector3, to_pos: Vector3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var size: float = tile_size if tile_size > 0.0 else 2.0
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
	# ...and how much to reach the first boundary, which is the part that gets a corner
	# right: whichever boundary is nearer is the one crossed next.
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

## Nothing, as a cell coordinate. Returned when a line meets nothing solid.
const NO_CELL := Vector2i(2147483647, 2147483647)

## The first cell on the segment that cannot be walked through, or NO_CELL.
##
## Asked with the same question the pathfinder uses, so that "the straight line is clear"
## and "A* will route through here" can never disagree -- they did, and a walker caught
## between them stands still.
##
## `skip` is a cell that never counts, for the one a walker is standing in: it is plainly
## standable, whatever is registered there.
func first_solid_on_line(from_pos: Vector3, to_pos: Vector3, terrain_only: bool = false,
		ignore_building: Node = null, skip: Vector2i = NO_CELL) -> Vector2i:
	for cell in cells_on_line(from_pos, to_pos):
		if cell == skip:
			continue
		if not is_cell_walkable(cell, ignore_building, terrain_only):
			return cell
	return NO_CELL

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

	# A goal standing on something -- a hill, a building, a tree -- is asked to move to
	# the nearest square that is not. Searched in rings rather than over the eight
	# neighbours, because the middle of a two-cell hill has no walkable neighbour at all
	# and the old version gave up there and returned a straight line into the rock.
	if not is_cell_walkable(goal_cell, ignore_building, terrain_only):
		var relocated: Vector2i = _nearest_walkable(goal_cell, from_pos, ignore_building, terrain_only)
		if relocated == goal_cell:
			return [to_pos]
		goal_cell = relocated
		to_pos = cell_to_world(goal_cell, to_pos.y)

	# A* Graph Search
	var open_set: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_cell: 0.0}
	var f_score: Dictionary = {start_cell: float(start_cell.distance_to(goal_cell))}

	var cardinals = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var diagonals = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

	# The closest A* has got to the goal so far. Without this there is nothing to return
	# when the search fails, and the only option is a straight line into whatever is in
	# the way.
	var best_cell: Vector2i = start_cell
	var best_h: float = float(start_cell.distance_to(goal_cell))

	var iterations: int = 0
	# Raised with the map: since v0.5 the ground the player can click runs well past the
	# playfield, and eight hundred nodes gave out on the long diagonal.
	var max_iterations: int = 4000

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
					raw_world_path.append(walkable_point_in_cell(cell_path[i]))

			return _smooth_path(from_pos, raw_world_path, ignore_building, terrain_only)

		open_set.remove_at(lowest_idx)
		var cur_h: float = float(current.distance_to(goal_cell))
		if cur_h < best_h:
			best_h = cur_h
			best_cell = current
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

	# A* ran out of room or the goal cannot be reached at all. Rather than hand back a
	# straight line -- which walks whoever asked into the nearest wall and leaves them
	# grinding against it -- hand back the best path actually found, so they get as close
	# as the map allows and stop somewhere sensible.
	#
	# This is what "it just stands there" usually was: a straight line into an obstacle,
	# a stuck timer, a replan producing the same straight line, forever.
	if came_from.has(best_cell) or best_cell != start_cell:
		var partial: Array[Vector2i] = [best_cell]
		var walk: Vector2i = best_cell
		var guard: int = 0
		while came_from.has(walk) and guard < 4096:
			walk = came_from[walk]
			partial.append(walk)
			guard += 1
		partial.reverse()
		var partial_world: Array[Vector3] = []
		for i in range(1, partial.size()):
			partial_world.append(walkable_point_in_cell(partial[i]))
		if not partial_world.is_empty():
			return _smooth_path(from_pos, partial_world, ignore_building, terrain_only)

	return [to_pos]

## The nearest cell to `centre` that can actually be stood on, searched outward in
## rings. Returns `centre` unchanged when there is nothing walkable within reach.
func _nearest_walkable(centre: Vector2i, toward: Vector3, ignore_building: Node = null, terrain_only: bool = false, max_radius: int = 12) -> Vector2i:
	var best: Vector2i = centre
	var best_dist: float = 999999.0
	for radius in range(1, max_radius + 1):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				# Only the ring itself; the inside was covered by a smaller radius.
				if absi(dx) != radius and absi(dz) != radius:
					continue
				var candidate := centre + Vector2i(dx, dz)
				if not is_cell_walkable(candidate, ignore_building, terrain_only):
					continue
				var d: float = cell_to_world(candidate).distance_to(toward)
				if d < best_dist:
					best_dist = d
					best = candidate
		if best != centre:
			return best      # nothing further out can be nearer than this ring
	return centre

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
## Used to sample every 0.4 of a tile, which could step over the corner of a hill and
## smooth a route straight through the thing A* had just gone around.
func _has_line_of_sight(from_pt: Vector3, to_pt: Vector3, ignore_building: Node = null, terrain_only: bool = false) -> bool:
	if from_pt.distance_to(to_pt) <= 0.1:
		return true
	return first_solid_on_line(from_pt, to_pt, terrain_only, ignore_building,
		world_to_cell(from_pt)) == NO_CELL
