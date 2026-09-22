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

## Every fine cell the straight line from `from_pos` to `to_pos` passes through.
##
## A CONNECTED run: the traversal steps one cell at a time and never cuts a corner, so a
## fence dragged diagonally has no diagonal gaps in it. That matters for more than looks
## -- a run with gaps in it does not seal, and "I dragged a fence across and things still
## walked through" would be a bug the player could not see the cause of.
func fine_cells_on_line(from_pos: Vector3, to_pos: Vector3, divisions: int) -> Array[Vector2i]:
	return cells_on_line(from_pos, to_pos, _fine_step(divisions))

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
## ALL of them, which since fine placement means both registers.
##
## occupied_cells holds ONE building per tile, so a fence of nine stakes standing in
## three tiles reported as three. Anything that asks "what is on the map" got a third of
## the answer: the Hero's build queue could not see the blueprints sharing a tile with
## something already up, and left them at 0% until every tile occupant was finished.
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

	var fine_to_clean: Array[Vector2i] = []
	for fine in fine_cells:
		var b = fine_cells[fine]
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			if not result.has(b):
				result.append(b)
		else:
			fine_to_clean.append(fine)
	for f in fine_to_clean:
		fine_cells.erase(f)
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
## `walls_are_open` is the Hero asking. A fence is HIS, and being shut out of his own
## camp by it -- with no gate anywhere in the game -- is a worse problem than the one a
## fence solves. It opens WALLS and nothing else: the wreck and the turrets still stop
## him, and it changes nothing at all for a dinosaur, which is the whole point of a
## fence.
func is_cell_walkable(cell: Vector2i, ignore_building: Node = null, terrain_only: bool = false,
		walls_are_open: bool = false) -> bool:
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
	if walls_are_open and _only_walls_here(cell):
		return true
	# A building smaller than its tile does not fill its tile. Only a run of them does.
	return occupant_leaves_a_way_through(cell)

## Whether everything standing in `cell` is a wall.
##
## Everything, not just the tile's registered occupant: a stake sharing a tile with the
## wreck must not make the wreck walk-through-able.
func _only_walls_here(cell: Vector2i) -> bool:
	var cfg = _get_config()
	if cfg == null or not cfg.has_method("get_building_kind"):
		return false
	var found: bool = false
	for b in _things_standing_in(cell):
		found = true
		if not ("building_type" in b) or String(cfg.get_building_kind(String(b.building_type))) != "wall":
			return false
	return found

## Every living building registered in `cell`, at either resolution.
func _things_standing_in(cell: Vector2i) -> Array[Node]:
	var out: Array[Node] = []
	var holder = get_building_at(cell)
	if holder != null:
		out.append(holder)
	var divisions: int = _fine_divisions_in(cell)
	if divisions > 1:
		var base := Vector2i(cell.x * divisions, cell.y * divisions)
		for dz in range(divisions):
			for dx in range(divisions):
				var at := base + Vector2i(dx, dz)
				if is_fine_cell_solid(at) and not out.has(fine_cells[at]):
					out.append(fine_cells[at])
	return out

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
## `size` is the width of one cell, and defaults to a whole tile. Passing the fine step
## instead walks the same line over the finer grid, which is what laying a run of stakes
## needs -- see fine_cells_on_line. One traversal, asked at two scales, rather than two
## traversals to keep in step with each other.
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
		ignore_building: Node = null, skip: Vector2i = NO_CELL, walls_are_open: bool = false) -> Vector2i:
	for cell in cells_on_line(from_pos, to_pos):
		if cell == skip:
			continue
		if not is_cell_walkable(cell, ignore_building, terrain_only, walls_are_open):
			return cell
	return NO_CELL
## THE GRID A* AND ITS REACHABILITY FLOOD USED TO LIVE HERE.
##
## Both are gone, and what replaced them is one bake: scripts/core/NavMaps.gd. They were
## a second implementation of a question the engine already answers, and the two
## disagreed -- not everywhere, which is why it took a whole version to see, but in a
## band about a metre wide RIGHT AT A FENCE, which is the only place the answer is ever
## acted on. A raid walked up to a sealed ring knowing it was sealed and forgot at the
## moment it arrived.
##
## The cell queries above are still the grid's own job: what occupies a tile, what a
## click lands on, whether a stake may be placed. Where somebody can WALK is asked of
## the mesh, by everybody, and there is no longer a second answer to pick from.
