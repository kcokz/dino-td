class_name NavMaps
extends Node3D

## The navigation meshes, baked from the level's own colliders.
##
## BAKED RATHER THAN COMPUTED, which is rule 8 in AGENT-TASKS.md. A bake works out where
## an agent of a given RADIUS can stand, and that is precisely the question the
## hand-written fence rule was trying to answer -- "do these stakes leave a gap anyone can
## get through". That rule was written twice: the first version only recognised fences
## drawn along the axes and a curve sealed nothing, however solid it looked. The engine
## has never needed telling about diagonals.
##
## EVERY GAME RULE IS ALREADY A COLLISION LAYER, which is what makes this possible at all:
##
##   layer 1   ground, hillside, resource nodes   -- the surface, and what interrupts it
##   layer 2   the cabin and the traps            -- solid to everybody
##   layer 16  blueprints                         -- ordered, not built; solid to nobody
##   layer 32  walls                              -- solid to everybody (since v0.6 round two)
##   layer 128 gates                              -- solid to a raid, open to the Hero
##
## So the maps are one bake each with a different mask, and "the Hero walks through his own
## gate" is not a special case threaded through the pathfinder but a bit that is not set.
##
## A third, SIEGE, leaves walls out too (v0.6 round two): what a siege animal walks, since
## going THROUGH the defence is its design -- and what a raid asks when the way is shut, for
## the first wall the route through them crosses, which is the wall to bite (Dino).

## Which walker a map is for. The only difference is what is carved out of it.
enum For { RAID = 0, HERO = 1, SIEGE = 2 }

## The group the level puts its geometry in, so a bake knows where to look.
const SOURCE_GROUP: String = "navmesh_source"

## How anything that walks finds these maps without being handed a reference.
const GROUP: String = "nav_maps"

## What is open to the Hero and solid to everybody else: the cabin's inside (v0.6 round three),
## whose door is a gate to a raid. Without it a raid's map had a floor in there, cut off, and the
## nearest walkable point to the cabin's middle was on it -- so the cabin always looked shut
## away, and every raid set about the walls. Each member answers hero_only_box():
## [its middle, its half-extents on the ground (x, z), its height].
const HERO_ONLY_GROUP: String = "nav_hero_only"

var _regions: Dictionary = {}     # For -> NavigationRegion3D
var _dirty: bool = true
var _baked_once: bool = false

func _ready() -> void:
	add_to_group(GROUP)
	for which in [For.RAID, For.HERO, For.SIEGE]:
		var region := NavigationRegion3D.new()
		region.name = "Nav_%s" % ["Raid", "Hero", "Siege"][which]
		region.navigation_mesh = _mesh_for(which)
		# Each map is its own world: an agent on one must not path across the other.
		region.set_navigation_map(NavigationServer3D.map_create())
		NavigationServer3D.map_set_up(region.get_navigation_map(), Vector3.UP)
		NavigationServer3D.map_set_cell_size(region.get_navigation_map(), _cell_size())
		NavigationServer3D.map_set_cell_height(region.get_navigation_map(), _cell_height())
		NavigationServer3D.map_set_active(region.get_navigation_map(), true)
		add_child(region)
		_regions[which] = region
	_connect_event_bus()
	rebake()

func _exit_tree() -> void:
	for which in _regions:
		var region: NavigationRegion3D = _regions[which]
		if is_instance_valid(region):
			var map: RID = region.get_navigation_map()
			if map.is_valid():
				NavigationServer3D.free_rid(map)
	_regions.clear()

func _connect_event_bus() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb == null:
		return
	# Anything that changes what is solid makes both meshes stale. Marked rather than
	# rebaked on the spot: laying a row of stakes fires this once per stake, and a row
	# should cost one bake.
	# building_completed as well as building_placed: a blueprint is in neither mesh, so
	# the moment that changes what anyone can walk through is the moment it is FINISHED.
	for sig in ["building_placed", "building_completed", "building_destroyed"]:
		if eb.has_signal(sig) and not eb.is_connected(sig, _on_world_changed):
			eb.connect(sig, _on_world_changed)

func _on_world_changed(_arg: Variant = null) -> void:
	_dirty = true

func _process(_delta: float) -> void:
	if _dirty:
		rebake()

# ==============================================================================
# Baking
# ==============================================================================

## Rebuilds both meshes from the level as it stands.
##
## Synchronous on purpose. The level is a forty-metre field and the bake is milliseconds;
## an async bake would mean a window where a fence has gone up and nothing knows it yet,
## which is a race condition bought for nothing.
func rebake() -> void:
	_dirty = false
	for which in _regions:
		var region: NavigationRegion3D = _regions[which]
		if not is_instance_valid(region):
			continue
		# Parsed and baked in two steps -- what bake_navigation_mesh does in one -- so the
		# hero-only spaces can go into every map but his, between them.
		var mesh: NavigationMesh = _mesh_for(which)
		var source := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh, source, region)
		if which != For.HERO:
			_add_hero_only_spaces(source)
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)
		region.navigation_mesh = mesh
	_baked_once = true

## Every hero-only space (HERO_ONLY_GROUP) into `source` as a solid block, exactly its box: the
## walls round it are in the bake already.
func _add_hero_only_spaces(source: NavigationMeshSourceGeometryData3D) -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(HERO_ONLY_GROUP):
		if not is_instance_valid(node) or not node.has_method("hero_only_box"):
			continue
		var box: Array = node.hero_only_box()
		if box.size() < 3:
			continue
		var c: Vector3 = box[0]
		var half: Vector2 = box[1]
		source.add_projected_obstruction(PackedVector3Array([
			Vector3(c.x - half.x, c.y, c.z - half.y), Vector3(c.x + half.x, c.y, c.z - half.y),
			Vector3(c.x + half.x, c.y, c.z + half.y), Vector3(c.x - half.x, c.y, c.z + half.y)]),
			c.y - 1.0, float(box[2]) + 1.0, true)

func _mesh_for(which: int) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SOURCE_GROUP
	# Ground and hillside (1) and the solid buildings (2) always; walls (32) for everybody but a
	# siege; gates (128) only for a raid -- that one bit is the whole of the Hero's way through.
	# Blueprints (16) are in none, because ordering a fence is not having one.
	mesh.geometry_collision_mask = _mask_for(which)
	mesh.cell_size = _cell_size()
	mesh.cell_height = _cell_height()
	mesh.agent_radius = _agent_radius()
	mesh.agent_height = 1.0
	mesh.agent_max_climb = 0.3
	mesh.agent_max_slope = 30.0
	# Islands too small to stand a body on are dropped: the top of a metre of wall is walkable
	# to the bake, cut off from everything, and "the nearest point to that wall" landed on it.
	mesh.region_min_size = _region_min_size()
	return mesh

## The smallest island the bake keeps, in voxels a side (Config.NAV.region_min_size).
func _region_min_size() -> float:
	var cfg = get_node_or_null("/root/Config")
	if cfg and "NAV" in cfg:
		return float(cfg.NAV.get("region_min_size", 8.0))
	return 8.0

## Marks a box `half` metres either side of `owner`'s middle and `height` tall out of every bake,
## as a SOLID. The bake reads a collider as surfaces, not as a solid: under the roof of a box it
## finds a floor with headroom and makes a walkable island of it, walled off from everything --
## under the cabin's roof, and inside every hill -- and "the nearest walkable point" to it is in
## there, where no route goes. The engine's own obstacle does the marking; avoidance is off,
## because steering round it is the baked mesh's job, not the obstacle's. It is carved out of
## EVERY map, so it is only for what stops everybody. Once per owner.
static func mark_solid(owner: Node3D, half: float, height: float) -> void:
	if owner.find_child("BakeObstacle", false, false) != null:
		return
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "BakeObstacle"
	obstacle.avoidance_enabled = false
	obstacle.affect_navigation_mesh = true
	obstacle.height = height + 0.5     # its top as well as the floor under it
	obstacle.vertices = PackedVector3Array([Vector3(-half, 0.0, -half), Vector3(half, 0.0, -half),
		Vector3(half, 0.0, half), Vector3(-half, 0.0, half)])
	owner.add_child(obstacle)

func _mask_for(which: int) -> int:
	var cfg = get_node_or_null("/root/Config")
	var wall_layer: int = int(cfg.LAYER_WALL) if (cfg and "LAYER_WALL" in cfg) else 32
	var gate_layer: int = int(cfg.LAYER_GATE) if (cfg and "LAYER_GATE" in cfg) else 0
	match which:
		For.RAID:
			return 1 | 2 | wall_layer | gate_layer
		For.SIEGE:
			# No walls: a siege animal goes through them, and a raid asks this map for the wall
			# its way in crosses.
			return 1 | 2
	# The Hero's: his walls stop him since v0.6 round two ("人不能再穿过墙了"); his gates do not.
	return 1 | 2 | wall_layer

## How fine the bake is. Small enough to see the gap between two stakes, which is the
## whole reason the mesh exists; a coarse bake would smear a fence into a solid line.
func _cell_size() -> float:
	var cfg = get_node_or_null("/root/Config")
	if cfg and "NAV" in cfg:
		return float(cfg.NAV.get("cell_size", 0.15))
	return 0.15

## The bake's vertical resolution, which the map has to be told as well: a map whose
## cell height differs from its meshes' warns on every bake (Config.NAV.cell_height).
func _cell_height() -> float:
	var cfg = get_node_or_null("/root/Config")
	if cfg and "NAV" in cfg:
		return float(cfg.NAV.get("cell_height", 0.1))
	return 0.1

## What the mesh is carved for. ONE radius for everything that walks, which is a
## simplification worth naming: a theropod is wider than a raptor, so it can be routed
## through a gap it does not fit in, and only the avoidance solver will notice. Carving a
## third mesh for it is the fix if that ever shows.
func _agent_radius() -> float:
	var cfg = get_node_or_null("/root/Config")
	if cfg and "NAV" in cfg:
		return float(cfg.NAV.get("agent_radius", 0.4))
	return 0.4

# ==============================================================================
# Asking
# ==============================================================================

func map_for(walls_are_open: bool) -> RID:
	return map_of(For.HERO if walls_are_open else For.RAID)

## The map for `which` walker (For).
func map_of(which: int) -> RID:
	var region: NavigationRegion3D = _regions.get(which)
	if region == null or not is_instance_valid(region):
		return RID()
	return region.get_navigation_map()

## The map a caller means: `which` is a For, or -- as it always was -- a bool, true for the
## Hero's mesh and false for the raid's.
func _map(which: Variant) -> RID:
	if which is bool:
		return map_for(bool(which))
	return map_of(int(which))

## The route from `from_pos` to `to_pos`, funnelled -- the corners actually needed rather
## than the centre of every tile crossed.
func path(from_pos: Vector3, to_pos: Vector3, walls_are_open: Variant = false) -> PackedVector3Array:
	var map: RID = _map(walls_are_open)
	if not map.is_valid():
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(map, from_pos, to_pos, true)

## Whether `to_pos` can be walked to at all.
##
## The path is the answer, which is the point of using the engine's: the server returns
## the best route it has, so one that stops short of where it was asked for means there
## is no way there. The hand-written version flooded the grid from the target end with a
## budget, and had to guess when the budget ran out.
##
## "SHORT OF WHERE IT WAS ASKED FOR" IS MEASURED AGAINST THE NEAREST PLACE THE MESH HAS,
## not against the goal itself, and that difference is a whole bug. Almost every goal
## worth asking about is a BUILDING, and buildings are carved out of the mesh -- so a
## route to one always stops short by roughly the agent's radius plus the building's half
## width, plus whatever else is carved nearby. This used to allow a fixed metre of slack
## for that, and a metre is a guess: the bare cabin left a route ending 0.922m from its
## centre, which fits with 0.078m to spare, and putting FIVE STAKES beside it pushed the
## end to 1.020m. Two sides of the cabin were wide open and every dinosaur in the game
## was told the way was sealed, walked up to the fence and started eating it -- reported
## as "恐龙又直接进攻还没围住 cabin 的木栅栏了". Seven centimetres of an arbitrary
## tolerance, with nothing about the actual question in it.
##
## Asking whether the route gets as close to the goal as the nearest standable point does
## has no such number in it: it is true whenever the goal is as close as the ground allows,
## whatever is standing there and however big it is.
##
## As close AS, not TO the same point. The cabin is square and its middle is equally far
## from all four of its walls, so "the nearest standable point" is a four-way tie, and the
## server can settle it one way for the route and another for the nearest point: a route
## that reached the north wall was judged against the south one and called sealed.
func is_reachable(from_pos: Vector3, to_pos: Vector3, walls_are_open: Variant = false) -> bool:
	var map: RID = _map(walls_are_open)
	if not map.is_valid():
		return false
	var pts := path(from_pos, to_pos, walls_are_open)
	if pts.is_empty():
		return false
	var nearest: Vector3 = NavigationServer3D.map_get_closest_point(map, to_pos)
	return _flat(pts[pts.size() - 1]).distance_to(_flat(to_pos)) <= _flat(nearest).distance_to(_flat(to_pos)) + _same_place()

## On the ground: how high a route runs over the carve is not how far it is from the goal.
static func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

## How far apart two points may be and still be the same place. About the mesh's own
## resolution and nothing else -- which is the only kind of tolerance this question
## should contain.
func _same_place() -> float:
	return maxf(0.2, _cell_size() * 3.0)

## The nearest point on the mesh to `pos` -- where a walker that tried to go somewhere
## impossible would actually end up.
func closest_point(pos: Vector3, walls_are_open: Variant = false) -> Vector3:
	var map: RID = _map(walls_are_open)
	if not map.is_valid():
		return pos
	return NavigationServer3D.map_get_closest_point(map, pos)

## Whether the meshes can be asked yet: built at least once, and taken up by the navigation server.
##
## BUILT IS NOT ENOUGH. A map answers from its last sync, and until its first one every route is
## empty and map_get_closest_point says (0, 0, 0) -- with nothing in either answer to say so. A
## dinosaur asking in those first frames after a level loads was told the way to the cabin was
## shut, and went for the first building on a straight line (v0.6 round two). Not ready is not
## "shut": a caller that gets false here treats the way as open.
func is_ready() -> bool:
	if not _baked_once:
		return false
	for which in _regions:
		var map: RID = map_of(which)
		if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
			return false
	return true
