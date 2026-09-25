# res://tests/test_v05_navmesh.gd
# The navigation meshes, and that they say what the grid says.
#
# Rule 8 in AGENT-TASKS.md, applied to the last big piece of hand-written navigation. A
# bake works out where an agent of a given RADIUS can stand, which is exactly the question
# the hand-written fence rule was trying to answer -- "do these stakes leave a gap anyone
# can get through". That rule had to be written twice: the first version only recognised
# fences drawn along the axes, so a CURVE, which is what people actually draw, sealed
# nothing however solid it looked. The engine has never needed telling about diagonals.
#
# The two maps differ by ONE BIT of a collision mask. "The Hero walks through his own
# fence" stops being a flag threaded through the pathfinder, the line checks and the
# reachability flood, and becomes layer 32 being absent from one bake.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

## A real level, because a bake needs real colliders -- which is the point of baking.
func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

func _core_of(main: Node) -> Vector3:
	return cabin_at(main)

## How far from the cabin's middle a route to it can end: its walls, the walker's width,
## and a little. The old 1.0 and 1.5 were this for a 1 m pod.
func _at_the_cabin(slack: float) -> float:
	return float(config_node.get_building_footprint("core")) * 0.5 + slack

## Stakes all the way round `centre`, placed the way a click places them.
func _ring_around(main: Node, centre: Vector3, radius: float) -> int:
	var gm = main.grid_manager
	var d: int = int(config_node.get_cell_divisions("wall"))
	var step: float = float(config_node.TILE_SIZE) / float(d)
	var seen: Dictionary = {}
	var placed: int = 0
	var around: int = int(ceil(TAU * radius / step)) * 4
	for i in range(around):
		var a: float = TAU * float(i) / float(around)
		var at: Vector3 = centre + Vector3(sin(a) * radius, 0.0, cos(a) * radius)
		var fine: Vector2i = gm.world_to_fine_cell(at, d)
		if seen.has(fine):
			continue
		seen[fine] = true
		var snap: Vector3 = gm.fine_cell_to_world(fine, d)
		var b = main.build_system.place_building("wall", gm.world_to_cell(snap), main.buildings_container, true, snap)
		if b != null:
			b.complete_construction()
			placed += 1
	return placed

# ==============================================================================
# 1. There is a mesh, and it is carved for a real walker
# ==============================================================================

func test_01_the_level_bakes_two_maps() -> void:
	var main = _level()
	await wait_frames(6)

	assert_not_null(main.nav_maps, "The level has its navigation maps")
	assert_true(main.nav_maps.is_ready(), "And has baked them")
	assert_true(main.nav_maps.map_for(false).is_valid(), "One for a raid")
	assert_true(main.nav_maps.map_for(true).is_valid(), "One for the Hero")
	assert_ne(main.nav_maps.map_for(false), main.nav_maps.map_for(true),
		"Which are different maps, or the exemption would leak both ways")

func test_02_the_two_maps_differ_by_exactly_the_wall_layer() -> void:
	# The whole of "the Hero walks through his own fence", as a bit rather than a flag
	# threaded through the pathfinder.
	var main = _level()
	await wait_frames(6)
	var raid_mask: int = main.nav_maps._mask_for(NavMaps.For.RAID)
	var hero_mask: int = main.nav_maps._mask_for(NavMaps.For.HERO)

	assert_eq(raid_mask ^ hero_mask, int(config_node.LAYER_WALL),
		"The only difference between them is the wall layer")
	assert_ne(raid_mask & 2, 0, "Both still see the wreck and the turrets")
	assert_ne(hero_mask & 2, 0, "Both still see the wreck and the turrets")
	assert_eq(raid_mask & int(config_node.LAYER_BLUEPRINT), 0,
		"Neither sees blueprints: ordering a fence is not having one")
	assert_eq(hero_mask & int(config_node.LAYER_BLUEPRINT), 0, "Neither sees blueprints")

func test_03_the_agent_radius_is_a_whole_number_of_voxels() -> void:
	# The bake quantises the radius to its own voxel grid and rounds UP when it does not
	# divide. A radius silently larger than declared is a fence that seals gaps the player
	# deliberately left open, and it warns about it rather than failing.
	var cell: float = float(config_node.NAV["cell_size"])
	var radius: float = float(config_node.NAV["agent_radius"])
	assert_gt(cell, 0.0, "There is a voxel size")
	var voxels: float = radius / cell
	assert_almost_eq(voxels, round(voxels), 0.0001,
		"The radius is %d voxels exactly, so the bake never rounds it up" % int(round(voxels)))

# ==============================================================================
# 2. And it agrees with the grid about what is walkable
# ==============================================================================

func test_04_open_ground_is_a_route() -> void:
	var main = _level()
	await wait_frames(6)
	var core: Vector3 = _core_of(main)
	var far: Vector3 = core + Vector3(0.0, 0.0, -16.0)

	var route: PackedVector3Array = main.nav_maps.path(far, core)
	assert_gt(route.size(), 1, "There is a way across open ground")
	assert_true(main.nav_maps.is_reachable(far, core), "And it counts as reaching")

func test_05_a_sealed_ring_stops_a_raid_and_not_the_hero() -> void:
	# The case the hand-written rule was written for, twice, asked of the engine instead.
	var main = _level()
	await wait_frames(6)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	var far: Vector3 = core + Vector3(0.0, 0.0, -16.0)

	var placed: int = _ring_around(main, core, 4.0)
	assert_gt(placed, 12, "A ring of stakes went up round the cabin")
	await wait_frames(6)

	assert_false(main.nav_maps.is_reachable(far, core),
		"A raid has no way in -- and it is a CURVE, which the first hand-written rule missed")
	assert_true(main.nav_maps.is_reachable(far, core, true),
		"The man who built it does")

# test_06 is gone with its subject. It held the navmesh and the grid flood side by side
# and required them to agree, on the grounds that while both existed whichever one a
# given line of code happened to ask would decide the behaviour. They did not agree, the
# test did not catch it -- it compared them out in the open, and they only parted company
# within about a metre of a fence -- and the grid flood has since been deleted. There is
# one answer now, which is what this test was asking for.

func test_07_a_blueprint_ring_seals_nothing() -> void:
	# Blueprints are in neither mask. Ordering a fence is not having one, and a raid that
	# stopped for stakes nobody had built yet was one of this version's reported bugs.
	var main = _level()
	await wait_frames(6)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	var far: Vector3 = core + Vector3(0.0, 0.0, -16.0)
	var gm = main.grid_manager
	var d: int = int(config_node.get_cell_divisions("wall"))
	var step: float = float(config_node.TILE_SIZE) / float(d)

	var seen: Dictionary = {}
	var ordered: int = 0
	var around: int = int(ceil(TAU * 4.0 / step)) * 4
	for i in range(around):
		var a: float = TAU * float(i) / float(around)
		var at: Vector3 = core + Vector3(sin(a) * 4.0, 0.0, cos(a) * 4.0)
		var fine: Vector2i = gm.world_to_fine_cell(at, d)
		if seen.has(fine):
			continue
		seen[fine] = true
		var snap: Vector3 = gm.fine_cell_to_world(fine, d)
		# start_as_blueprint, and never completed.
		if main.build_system.place_building("wall", gm.world_to_cell(snap), main.buildings_container, true, snap) != null:
			ordered += 1
	assert_gt(ordered, 12, "A whole ring was ORDERED")
	await wait_frames(6)

	assert_true(main.nav_maps.is_reachable(far, core),
		"And a raid walks straight through it, because none of it is built")

# ==============================================================================
# 3. Being put back on the mesh is a correction, not a teleport
# ==============================================================================

func test_08_a_walker_is_not_flung_across_the_map_while_the_map_warms_up() -> void:
	# NavigationServer3D answers map_get_closest_point with (0, 0, 0) for the first two
	# or three syncs after a level loads, and NOTHING IN THE ANSWER SAYS IT IS NOT READY
	# -- not is_ready, not the region's polygon count (188 vertices, all correct), not
	# map_get_iteration_id, which reaches 1 while the answer is still the origin.
	#
	# A wave spawns inside exactly that window. Measured without the cap: a raptor put
	# down at the nest end of the path, (1, -8.5), was standing on the cabin at
	# (-0.11, 0.45) two frames later, had picked the cabin as its target, and could no
	# longer reach the stake it had been walking at.
	var main = _level()
	var dino = load("res://scripts/entities/Dino.gd").new("raptor")
	_cleanup_nodes.append(dino)
	main.dinos_container.add_child(dino)
	var spawned_at := Vector3(1.0, 0.0, -8.5)
	dino.global_position = spawned_at
	dino.set_waypoints([Vector3(1.0, 0.0, -7.0), Vector3(1.0, 0.0, 1.0)])
	await wait_frames(2)               # the window, exactly

	var cap: float = float(config_node.NAV["max_correction"])
	var thrown: float = absf(dino.global_position.z - spawned_at.z) - float(dino.speed) * 0.1
	assert_lt(thrown, cap,
		"It is where it was put, give or take a step -- not wherever an unready map said")
	assert_lt(absf(dino.global_position.x - spawned_at.x), cap, "And has not been moved sideways")

func test_09_and_the_mesh_still_moves_one_that_is_off_it() -> void:
	# The cap must not cost the clamp its job, which is that NOTHING PHYSICALLY STOPS A
	# DINOSAUR: movement is a position added to, with no body sweep, so the mesh is the
	# only thing keeping a raid out of a walled camp.
	var main = _level()
	await wait_frames(8)               # long enough for the map to be warm
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	assert_gt(_ring_around(main, core, 4.0), 12, "A ring of stakes went up round the cabin")
	await wait_frames(8)

	var dino = load("res://scripts/entities/Dino.gd").new("raptor")
	_cleanup_nodes.append(dino)
	main.dinos_container.add_child(dino)
	# Half a step inside the fence line, which is as far in as one can ever get.
	var into_the_stakes: Vector3 = core + Vector3(0.0, 0.0, -4.0 + 0.3)
	dino.global_position = into_the_stakes
	dino._stay_on_the_navmesh()

	assert_gt(dino.global_position.distance_to(into_the_stakes), 0.05,
		"Standing in the fence line is not somewhere it may stand, so it is moved")
	assert_lt(dino.global_position.distance_to(into_the_stakes),
		float(config_node.NAV["max_correction"]), "By a correction, and no more")

# ==============================================================================
# 4. And it is the mesh that answers "is there a way round", not the grid
# ==============================================================================

func _raptor_outside(main: Node, core: Vector3) -> Node:
	var dino = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(dino)
	main.dinos_container.add_child(dino)
	dino.setup("raptor")
	dino.global_position = core + Vector3(0.0, 0.0, -9.0)
	dino.set_waypoints([core])
	return dino

func test_10_a_sealed_ring_is_still_sealed_when_you_are_standing_against_it() -> void:
	# THE ANSWER MUST NOT CHANGE AS YOU WALK UP TO IT. The grid and the mesh are two
	# implementations of one question, and they disagreed -- not everywhere, which is why
	# this took so long to see, but in a band about a metre wide RIGHT AT THE FENCE, which
	# is the only place the answer is ever acted on. Mapped at sixteen bearings and nine
	# distances round a ring of forty-eight stakes: identical from 5.6m out, and the grid
	# claiming a way in at every bearing from 4.8m in.
	#
	# So a raid walked up knowing it was sealed, and forgot at the moment it arrived. With
	# twenty raptors: all twenty knew at spawn, seventeen of seventeen survivors were told
	# there was a way round five seconds later, and they spent the rest of the raid pacing
	# the fence looking for it, taking a chip from every stake they brushed, dead in
	# fifteen seconds with the fence down seventeen points of three hundred and sixty-eight.
	# The player reported it as "恐龙会在圈出来的地方来回穿梭，进攻不了还掉血".
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	assert_gt(_ring_around(main, core, 4.0), 12, "A ring of stakes went up round the cabin")
	await wait_frames(8)

	var dino = _raptor_outside(main, core)
	await wait_frames(2)
	assert_true(dino._way_is_sealed(), "It knows there is no way in from out in the open")

	# Where one ends up when it gets there: pressed against the stakes, which stand at 4m.
	# Past the recheck throttle, or the cached answer from out in the open is what comes
	# back and the question is not being asked at all.
	dino.global_position = core + Vector3(0.0, 0.0, -4.4)
	await wait_seconds(dino.ROUTE_RECHECK_SECONDS + 0.1)
	assert_true(dino._way_is_sealed(), "And still knows it with its nose against them")

func test_11_so_it_commits_to_chewing_instead_of_looking_for_a_gap() -> void:
	# What the answer is for. A fence with no way round is the thing the raid has to eat.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	_ring_around(main, core, 4.0)
	await wait_frames(8)

	var dino = _raptor_outside(main, core)
	dino.global_position = core + Vector3(0.0, 0.0, -4.4)
	await wait_frames(2)
	var attacked: bool = false
	for step in range(360):
		dino.advance_towards_waypoint(1.0 / 60.0)
		if int(dino.current_state) == int(dino.State.ATTACKING):
			attacked = true
			break
		await wait_frames(1)
	assert_true(attacked, "It settles on a stake and starts biting rather than pacing")
	assert_true(_is_wall(dino.current_target), "And what it bites is the fence in its way")

func _is_wall(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and ("building_type" in node) \
		and String(node.building_type) == "wall"

func test_12_the_dinosaur_and_the_mesh_give_the_same_answer() -> void:
	# The fixture trap, named: many suites build a bare GridManager with no geometry in
	# it, so there is no mesh to bake and the grid is all there is. That fallback must
	# stay a fallback -- "the game runs the mesh, the tests run the grid" is how the
	# PackDino override hid for a whole version.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	var dino = _raptor_outside(main, core)
	await wait_frames(2)

	assert_eq(dino._there_is_a_way_round(core), main.nav_maps.is_reachable(dino.global_position, core),
		"Open ground: the dinosaur is asking the mesh")
	_ring_around(main, core, 4.0)
	dino.global_position = core + Vector3(0.0, 0.0, -4.4)
	await wait_frames(8)
	assert_eq(dino._there_is_a_way_round(core), main.nav_maps.is_reachable(dino.global_position, core),
		"Standing at the fence: still the mesh, and not the grid that disagreed with it here")
	assert_false(dino._there_is_a_way_round(core), "Which says there is no way in")

# ==============================================================================
# 5. The Hero walks the same mesh, with his own fence left out of it
# ==============================================================================

func test_13_his_route_to_a_building_ends_where_he_can_work_from() -> void:
	# WHERE THE ROUTE ENDS IS WHERE HE CAN WORK FROM. A building is carved out of the
	# mesh, so a route to its centre stops at the edge of the carve -- a stand-point
	# beside it, from whichever side he is coming.
	#
	# This replaced a scan of four cardinal offsets, each tested for a walkable neighbour,
	# each pathed to, sorted by distance, first success taken: a hand-written answer to
	# "where can somebody of my size stand next to this", which is what a bake answers by
	# construction. Measured: 0.92m from the cabin's centre and 0.20m from a stake's, both
	# inside build range, where the grid handed back a single waypoint at the building's
	# own centre and let him walk into it.
	var main = _level()
	await wait_frames(8)
	var core_cell: Vector2i = config_node.MAP["default_core_cell"]
	var cabin = main.grid_manager.get_building_at(core_cell)
	assert_not_null(cabin, "The cabin is standing")
	var hero = main.hero
	hero.global_position = main.grid_manager.cell_to_world(core_cell) + Vector3(0.0, 0.0, -12.0)
	await wait_frames(2)

	var route: PackedVector3Array = main.nav_maps.path(hero.global_position, cabin.global_position, true)
	assert_gt(route.size(), 1, "There is a way to the cabin")
	var stand: Vector3 = route[route.size() - 1]
	assert_true(hero._is_in_build_range(stand, cabin),
		"And the end of it is somewhere he can build from")
	assert_gt(stand.distance_to(cabin.global_position), 0.0,
		"Beside the cabin rather than inside it")

func test_14_his_own_fence_is_not_something_to_walk_round() -> void:
	# The exemption, as the two bakes rather than a flag: a route for him goes THROUGH a
	# line of his own stakes, and the same route for a raid does not exist at all.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	_ring_around(main, core, 4.0)
	await wait_frames(8)
	var outside: Vector3 = core + Vector3(0.0, 0.0, -9.0)

	var his: PackedVector3Array = main.nav_maps.path(outside, core, true)
	assert_gt(his.size(), 1, "He has a way in")
	assert_lt(his[his.size() - 1].distance_to(core), _at_the_cabin(0.5) * 1.42, "That actually gets there")
	assert_false(main.nav_maps.is_reachable(outside, core), "And a raid has none")

# ==============================================================================
# 6. And nobody stops to eat work that has only been ordered
# ==============================================================================

func test_15_a_raid_walks_past_a_turret_nobody_has_built() -> void:
	# The blueprint rule has two halves and only one of them is a collision layer.
	# Config.LAYER_BLUEPRINT keeps unbuilt work out of both bakes and out of everyone's
	# mask -- but a mask only covers what is found by a RAY, and a dinosaur finds
	# buildings by looking through the "buildings" group for the nearest one. So a turret
	# that had only been ordered was a perfectly good thing to walk at and bite.
	#
	# Measured: a raptor sent at the cabin stopped 5.27m short of it, at a turret nobody
	# had built, and stood there chewing the blueprint from 20 hit points down to 6.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
		game_state_node.resources["stone"] = 4000
	var gm = main.grid_manager
	var core: Vector3 = _core_of(main)

	# Ordered, never built, standing beside the road the raid walks down.
	var cell: Vector2i = gm.world_to_cell(core + Vector3(0.0, 0.0, -5.0))
	var ordered = main.build_system.place_building("tower", cell, main.buildings_container, true)
	assert_not_null(ordered, "A turret was ordered")
	assert_false(ordered.is_constructed, "And never built")
	await wait_frames(4)

	var dino = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(dino)
	main.dinos_container.add_child(dino)
	dino.setup("raptor")
	dino.max_hp = 9999.0
	dino.current_hp = 9999.0
	dino.global_position = core + Vector3(0.0, 0.0, -10.0)
	dino.set_waypoints([core])
	await wait_frames(2)

	assert_false(dino._is_target_valid(ordered), "It is not something to commit to")
	var blueprint_hp: float = ordered.current_hp
	var started: float = dino.global_position.distance_to(core)
	for step in range(600):
		dino.advance_towards_waypoint(1.0 / 60.0)
		if dino.global_position.distance_to(core) < _at_the_cabin(1.5):
			break
		await wait_physics_frames(1)

	assert_lt(dino.global_position.distance_to(core), _at_the_cabin(1.5),
		"It walks past the order and reaches the cabin, %.2fm from where it started" % started)
	assert_eq(ordered.current_hp, blueprint_hp, "Without taking a bite out of a plan")

# ==============================================================================
# 7. "Can I get there" is not a number of metres
# ==============================================================================

func test_16_a_fence_that_does_not_enclose_anything_seals_nothing() -> void:
	# Reported as "恐龙又直接进攻还没围住 cabin 的木栅栏了" -- the raid eating a fence with
	# two sides of the cabin wide open -- and the cause had nothing to do with fences.
	#
	# Almost every goal worth asking about is a BUILDING, and buildings are carved out of
	# the mesh, so a route to one always stops short by roughly the agent's radius plus
	# the building's half width plus whatever else is carved nearby. Reachability used to
	# allow a fixed metre of slack for that. A metre is a guess: the bare cabin left a
	# route ending 0.922m from its centre, which fits with SEVEN CENTIMETRES to spare,
	# and five stakes beside it pushed the end to 1.020m. Every dinosaur in the game was
	# then told the way was sealed.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var gm = main.grid_manager
	var core: Vector3 = _core_of(main)
	if main.hero:
		main.hero.global_position = core + Vector3(0.0, 0.0, 16.0)
	var d: int = int(config_node.get_cell_divisions("wall"))

	# Pressed against the cabin on two sides, and nothing at all on the other two: a row of
	# stakes along the tiles just outside its block on the west, and along the north.
	var fine_step: float = float(config_node.TILE_SIZE) / float(d)
	var lo: Vector2i = gm.world_to_fine_cell(gm.cell_to_world_origin(config_node.MAP["default_core_cell"])
		+ Vector3(fine_step * 0.5, 0.0, fine_step * 0.5), d)
	var along: int = int(round(float(config_node.get_building_span("core")) * float(config_node.TILE_SIZE) / fine_step))
	var fine_cells: Array[Vector2i] = [lo + Vector2i(-1, -1)]
	for i in range(along):
		fine_cells.append(lo + Vector2i(-1, i))
		fine_cells.append(lo + Vector2i(i, -1))
	var placed: int = 0
	for fine in fine_cells:
		var snap: Vector3 = gm.fine_cell_to_world(fine, d)
		var b = main.build_system.place_building("wall", gm.world_to_cell(snap), main.buildings_container, true, snap)
		if b != null:
			b.complete_construction()
			placed += 1
	assert_gt(placed, 2, "Some stakes went up beside the cabin")
	await wait_frames(8)

	var outside: Vector3 = core + Vector3(0.0, 0.0, -12.0)
	assert_true(main.nav_maps.is_reachable(outside, core),
		"Two sides are wide open, so of course the cabin can be reached")

	var dino = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(dino)
	main.dinos_container.add_child(dino)
	dino.setup("raptor")
	dino.max_hp = 9999.0
	dino.current_hp = 9999.0
	dino.global_position = outside
	dino.set_waypoints([core])
	await wait_frames(2)
	assert_false(dino._way_is_sealed(), "And the raid knows it")

	for step in range(600):
		dino.advance_towards_waypoint(1.0 / 60.0)
		if dino.global_position.distance_to(core) < _at_the_cabin(1.0) * 1.42:
			break
		await wait_physics_frames(1)
	assert_lt(dino.global_position.distance_to(core), _at_the_cabin(1.0) * 1.42, "It walks round to the cabin")
	assert_false(_is_wall(dino.current_target), "Rather than stopping to eat the fence")

func test_17_and_a_route_that_stops_somewhere_else_still_means_no() -> void:
	# The half that must not be given away by loosening the first. A sealed ring is not
	# "a route that ends a bit further out" -- it is a route that ends somewhere else
	# entirely, outside the ring, while the nearest standable point to the cabin is
	# inside it.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	assert_gt(_ring_around(main, core, 4.0), 12, "A ring went up")
	await wait_frames(8)
	var outside: Vector3 = core + Vector3(0.0, 0.0, -9.0)

	assert_false(main.nav_maps.is_reachable(outside, core), "A raid still has no way in")
	assert_true(main.nav_maps.is_reachable(outside, core, true), "And the Hero still has one")

func test_18_the_tolerance_is_about_the_mesh_and_not_about_buildings() -> void:
	# What makes the rule hold whatever is standing in the way: the only number left in
	# it is the mesh's own resolution. A tolerance that has to cover "the agent's radius
	# plus the building's half width" is a tolerance that has to be re-guessed for every
	# building ever added.
	var main = _level()
	await wait_frames(8)
	var cell: float = float(config_node.NAV["cell_size"])
	var radius: float = float(config_node.NAV["agent_radius"])

	assert_lt(main.nav_maps._same_place(), radius,
		"It is smaller than an agent, so it cannot be hiding a body's width of slack")
	assert_gte(main.nav_maps._same_place(), cell,
		"And no smaller than the mesh can resolve")

# ==============================================================================
# 8. Finishing a building is when the world changes shape
# ==============================================================================

func test_19_a_fence_the_hero_has_just_finished_actually_blocks() -> void:
	# ORDERING a fence and HAVING one are separate moments, and only the second one
	# changes what anyone can walk through. The meshes were only ever told about the
	# first: EventBus.building_placed fires when a blueprint goes down, and nothing at
	# all fired when it became a wall.
	#
	# It looked like it worked because of how the tests and the level happened to place
	# things -- in a tight loop, where putting the NEXT blueprint down marked the meshes
	# stale before the bake ever ran, so the bake saw the finished ones. Let a moment
	# pass between ordering a fence and finishing it, which is exactly what the Hero
	# walking over to build it does, and the fence stops nobody.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	if main.hero:
		main.hero.global_position = core + Vector3(0.0, 0.0, 20.0)
	var outside: Vector3 = core + Vector3(0.0, 0.0, -9.0)

	# Ordered, and then LEFT for a while, which is the part that matters.
	var ordered: Array[Node] = []
	for b in _ring_around_as_blueprints(main, core, 4.0):
		ordered.append(b)
	assert_gt(ordered.size(), 12, "A ring was ordered")
	await wait_frames(8)
	assert_true(main.nav_maps.is_reachable(outside, core),
		"Ordered and not built, it stops nobody -- which is the blueprint rule")

	# Now the Hero finishes them, and nothing else in the world happens.
	for b in ordered:
		if is_instance_valid(b):
			b.complete_construction()
	await wait_frames(8)

	assert_false(main.nav_maps.is_reachable(outside, core),
		"Finished, it stops a raid -- without anything else being built to jog the meshes")
	assert_true(main.nav_maps.is_reachable(outside, core, true), "And the Hero still gets in")

## A ring ORDERED and left unbuilt, handed back so a test can finish it later.
func _ring_around_as_blueprints(main: Node, centre: Vector3, radius: float) -> Array[Node]:
	var gm = main.grid_manager
	var d: int = int(config_node.get_cell_divisions("wall"))
	var step: float = float(config_node.TILE_SIZE) / float(d)
	var seen: Dictionary = {}
	var out: Array[Node] = []
	var around: int = int(ceil(TAU * radius / step)) * 4
	for i in range(around):
		var a: float = TAU * float(i) / float(around)
		var at: Vector3 = centre + Vector3(sin(a) * radius, 0.0, cos(a) * radius)
		var fine: Vector2i = gm.world_to_fine_cell(at, d)
		if seen.has(fine):
			continue
		seen[fine] = true
		var snap: Vector3 = gm.fine_cell_to_world(fine, d)
		var b = main.build_system.place_building("wall", gm.world_to_cell(snap), main.buildings_container, true, snap)
		if b != null:
			out.append(b)
	return out
