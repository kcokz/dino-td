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
	return main.grid_manager.cell_to_world(config_node.MAP["default_core_cell"])

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

func test_06_the_navmesh_and_the_grid_give_the_same_answer() -> void:
	# They are two independent implementations of one question. While both exist they
	# have to agree, or whichever one a given bit of code happens to ask will decide the
	# behaviour -- and that is how a walker ends up neither going round nor stopping.
	var main = _level()
	await wait_frames(6)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	var far: Vector3 = core + Vector3(0.0, 0.0, -16.0)
	var gm = main.grid_manager

	assert_eq(main.nav_maps.is_reachable(far, core), gm.is_reachable(far, core),
		"Open ground: same answer")

	_ring_around(main, core, 4.0)
	await wait_frames(6)
	assert_eq(main.nav_maps.is_reachable(far, core), gm.is_reachable(far, core),
		"Sealed, for a raid: same answer")
	assert_eq(main.nav_maps.is_reachable(far, core, true), gm.is_reachable(far, core, 400, true),
		"Sealed, for the Hero: same answer")

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
