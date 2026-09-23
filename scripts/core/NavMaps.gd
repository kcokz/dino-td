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
##   layer 2   the wreck and the turrets          -- solid to everybody
##   layer 16  blueprints                         -- ordered, not built; solid to nobody
##   layer 32  walls                              -- solid to a raid, open to the Hero
##
## So the two maps are one bake each with a different mask, and "the Hero walks through
## his own fence" stops being a special case threaded through the pathfinder and becomes
## a bit that is not set.

## Which walker a map is for. The only difference is whether walls are carved out of it.
enum For { RAID = 0, HERO = 1 }

## The group the level puts its geometry in, so a bake knows where to look.
const SOURCE_GROUP: String = "navmesh_source"

## How anything that walks finds these maps without being handed a reference.
const GROUP: String = "nav_maps"

var _regions: Dictionary = {}     # For -> NavigationRegion3D
var _dirty: bool = true
var _baked_once: bool = false

func _ready() -> void:
	add_to_group(GROUP)
	for which in [For.RAID, For.HERO]:
		var region := NavigationRegion3D.new()
		region.name = "Nav_%s" % ("Raid" if which == For.RAID else "Hero")
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
		region.navigation_mesh = _mesh_for(which)
		region.bake_navigation_mesh(false)
	_baked_once = true

func _mesh_for(which: int) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SOURCE_GROUP
	# Ground and hillside (1) and the solid buildings (2) always. Walls (32) only for the
	# raid -- that one bit is the whole of the Hero's exemption. Blueprints (16) are in
	# neither, because ordering a fence is not having one.
	mesh.geometry_collision_mask = _mask_for(which)
	mesh.cell_size = _cell_size()
	mesh.cell_height = _cell_height()
	mesh.agent_radius = _agent_radius()
	mesh.agent_height = 1.0
	mesh.agent_max_climb = 0.3
	mesh.agent_max_slope = 30.0
	return mesh

func _mask_for(which: int) -> int:
	var cfg = get_node_or_null("/root/Config")
	var wall_layer: int = int(cfg.LAYER_WALL) if (cfg and "LAYER_WALL" in cfg) else 32
	return (1 | 2 | wall_layer) if which == For.RAID else (1 | 2)

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
	var region: NavigationRegion3D = _regions.get(For.HERO if walls_are_open else For.RAID)
	if region == null or not is_instance_valid(region):
		return RID()
	return region.get_navigation_map()

## The route from `from_pos` to `to_pos`, funnelled -- the corners actually needed rather
## than the centre of every tile crossed.
func path(from_pos: Vector3, to_pos: Vector3, walls_are_open: bool = false) -> PackedVector3Array:
	var map: RID = map_for(walls_are_open)
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
## Asking whether the route reaches the nearest standable point to the goal has no such
## number in it: it is true whenever the goal is as close as the ground allows, whatever
## is standing there and however big it is.
func is_reachable(from_pos: Vector3, to_pos: Vector3, walls_are_open: bool = false) -> bool:
	var map: RID = map_for(walls_are_open)
	if not map.is_valid():
		return false
	var pts := path(from_pos, to_pos, walls_are_open)
	if pts.is_empty():
		return false
	var nearest: Vector3 = NavigationServer3D.map_get_closest_point(map, to_pos)
	return pts[pts.size() - 1].distance_to(nearest) <= _same_place()

## How far apart two points may be and still be the same place. About the mesh's own
## resolution and nothing else -- which is the only kind of tolerance this question
## should contain.
func _same_place() -> float:
	return maxf(0.2, _cell_size() * 3.0)

## The nearest point on the mesh to `pos` -- where a walker that tried to go somewhere
## impossible would actually end up.
func closest_point(pos: Vector3, walls_are_open: bool = false) -> Vector3:
	var map: RID = map_for(walls_are_open)
	if not map.is_valid():
		return pos
	return NavigationServer3D.map_get_closest_point(map, pos)

## Whether the meshes have been built at least once -- false in a fixture with no level.
func is_ready() -> bool:
	return _baked_once
