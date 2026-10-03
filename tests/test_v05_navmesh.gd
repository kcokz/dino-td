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
# The Hero's map and a raid's differ by ONE BIT of a collision mask. "The Hero walks through
# his gate" is not a flag threaded through the pathfinder, the line checks and the
# reachability flood: it is the gate layer being absent from one bake. (Until v0.6 round two
# he walked through every fence of his own; now a wall stops everybody, and a gate is his way
# through -- "而且人不能再穿过墙了".)
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

## A built ring of wall all the way round `centre` (test_base.ring_in_level); how many sections.
func _ring_around(main: Node, centre: Vector3, radius: float) -> int:
	return ring_in_level(main, centre, radius).size()

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

func test_02_the_maps_differ_by_exactly_what_keeps_a_raid_out() -> void:
	# The whole of "the Hero walks through his gate", as a bit rather than a flag threaded
	# through the pathfinder -- a wall is in both, since v0.6 round two -- and the siege map,
	# which a siege animal walks and a raid asks for the wall in its way, sees no walls at all.
	var main = _level()
	await wait_frames(6)
	var raid_mask: int = main.nav_maps._mask_for(NavMaps.For.RAID)
	var hero_mask: int = main.nav_maps._mask_for(NavMaps.For.HERO)
	var siege_mask: int = main.nav_maps._mask_for(NavMaps.For.SIEGE)

	assert_eq(raid_mask ^ hero_mask, int(config_node.LAYER_GATE),
		"The only difference between them is the gates")
	assert_ne(hero_mask & int(config_node.LAYER_WALL), 0, "A wall is in the way of the Hero too")
	assert_eq(siege_mask & (int(config_node.LAYER_WALL) | int(config_node.LAYER_GATE)), 0,
		"The siege map sees no walls")
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

func test_05_a_sealed_ring_stops_everybody_and_a_gate_lets_him_in() -> void:
	# The case the hand-written rule was written for, twice, asked of the engine instead. A ring
	# of wall shuts out a raid and the Hero alike (v0.6 round two: "人不能再穿过墙了"); a gate in
	# it is his way in, and still none for a raid.
	var main = _level()
	await wait_frames(6)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	var far: Vector3 = core + Vector3(0.0, 0.0, -16.0)

	var ring: Array[Node] = ring_in_level(main, core, 4.0)
	assert_gt(ring.size(), 12, "A ring of wall went up round the cabin")
	await nav_settled(main)
	assert_false(main.nav_maps.is_reachable(far, core),
		"A raid has no way in -- and it is a CURVE, which the first hand-written rule missed")
	assert_false(main.nav_maps.is_reachable(far, core, true),
		"Nor has the man who built it: a wall stops him too")

	# One section to the south taken down, a gate hung in its place.
	var south: Vector2i = main.grid_manager.world_to_build_cell(core + Vector3(0.0, 0.0, 4.0))
	var section = main.grid_manager.building_in_build_cell(south)
	assert_not_null(section, "There is a section due south")
	section.destroy()
	await nav_settled(main)
	var gate = main.build_system.place_at("gate", south, main.buildings_container, true)
	assert_not_null(gate, "A gate goes in where it stood")
	gate.complete_construction()
	await nav_settled(main)
	assert_true(main.nav_maps.is_reachable(far, core, true), "Now he has a way in: the gate")
	assert_false(main.nav_maps.is_reachable(far, core), "And a raid still has none")

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

	# Ordered, and never built.
	var ordered: Array[Node] = ring_in_level(main, core, 4.0, false)
	assert_gt(ordered.size(), 12, "A whole ring was ORDERED")
	await nav_settled(main)

	assert_true(main.nav_maps.is_reachable(far, core),
		"And a raid walks straight through it, because none of it is built")
	assert_true(main.nav_maps.is_reachable(far, core, true), "And so does the Hero")

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

func test_09_and_one_put_down_in_a_fence_is_put_out_of_it() -> void:
	# A dinosaur has a body since v0.6 round two, and that body is what keeps it out of a
	# walled camp -- not a clamp onto the mesh.
	var main = _level()
	await wait_frames(8)               # long enough for the map to be warm
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	assert_gt(_ring_around(main, core, 4.0), 12, "A ring of stakes went up round the cabin")
	await nav_settled(main)

	var dino = load("res://scripts/entities/Dino.gd").new("raptor")
	_cleanup_nodes.append(dino)
	main.dinos_container.add_child(dino)
	# Half a step inside the fence line, which is as far in as one can ever get. Its own body
	# puts it out of the stakes (v0.6 round two): the engine recovers a collider from inside
	# another when it moves, and the clamp onto the mesh that did this is gone.
	var into_the_stakes: Vector3 = core + Vector3(0.0, 0.0, -4.0 + 0.3)
	dino.global_position = into_the_stakes
	for i in range(10):
		dino._move_body(Vector3.ZERO)

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
	await nav_settled(main)

	var dino = _raptor_outside(main, core)
	await wait_frames(2)
	assert_true(dino._way_is_sealed(), "It knows there is no way in from out in the open")

	# Where one ends up when it gets there: pressed against the stakes, which stand at 4m.
	# Past the recheck throttle, or the cached answer from out in the open is what comes
	# back and the question is not being asked at all.
	dino.global_position = core + Vector3(0.0, 0.0, -4.4)
	await wait_seconds(float(config_node.DINO_AI["route_check_seconds"]) + 0.1)
	assert_true(dino._way_is_sealed(), "And still knows it with its nose against them")

func test_11_so_it_commits_to_chewing_instead_of_looking_for_a_gap() -> void:
	# What the answer is for. A fence with no way round is the thing the raid has to eat.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	_ring_around(main, core, 4.0)
	await nav_settled(main)

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
	await nav_settled(main)
	assert_eq(dino._there_is_a_way_round(core), main.nav_maps.is_reachable(dino.global_position, core),
		"Standing at the fence: still the mesh, and not the grid that disagreed with it here")
	assert_false(dino._there_is_a_way_round(core), "Which says there is no way in")

# ==============================================================================
# 5. The Hero walks the same mesh, with his gates left out of it
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
	var core_cell: Vector2i = config_node.map_data()["default_core_cell"]
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

func test_14_his_way_through_a_fence_is_its_gate() -> void:
	# His exemption, as the two bakes rather than a flag: a route for him goes THROUGH the gate
	# in a ring, and the same route for a raid does not exist at all. Through the gate, not the
	# wall: the end of his route is at the cabin, and its way in crosses the ring where the gate
	# stands.
	var main = _level()
	await wait_frames(8)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 4000
	var core: Vector3 = _core_of(main)
	var ring: Array[Node] = ring_in_level(main, core, 4.0, true, 0.0)
	var gates: int = 0
	for b in ring:
		if String(b.building_type) == "gate":
			gates += 1
	assert_eq(gates, 1, "The ring has one gate in it, due south")
	await nav_settled(main)
	var outside: Vector3 = core + Vector3(0.0, 0.0, -9.0)

	var his: PackedVector3Array = main.nav_maps.path(outside, core, true)
	assert_gt(his.size(), 1, "He has a way in")
	assert_lt(his[his.size() - 1].distance_to(core), _at_the_cabin(0.5) * 1.42, "That actually gets there")
	var gate_at: Vector3 = main.grid_manager.build_cell_to_world(
		main.grid_manager.world_to_build_cell(core + Vector3(0.0, 0.0, 4.0)))
	var through_the_gate: bool = false
	for i in range(his.size() - 1):
		var mid: Vector3 = Geometry3D.get_closest_point_to_segment(gate_at, his[i], his[i + 1])
		if Vector2(mid.x - gate_at.x, mid.z - gate_at.z).length() < float(config_node.BUILD_CELL) * 0.75:
			through_the_gate = true
	assert_true(through_the_gate, "Through the gate")
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
	stock_everything(4000)
	var gm = main.grid_manager
	var core: Vector3 = _core_of(main)

	# Ordered, never built, standing beside the road the raid walks down.
	var cell: Vector2i = gm.world_to_cell(core + Vector3(0.0, 0.0, -5.0))
	var ordered = main.build_system.place_building("bow_tower", cell, main.buildings_container, true)
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

	# Pressed against the cabin on two sides, and nothing at all on the other two: a line of wall
	# along the cells just outside its block on the west, and along the north.
	var middle: Vector2i = gm.world_to_build_cell(core)
	var half: int = (int(config_node.get_building_cells("core")) - 1) / 2
	var cells: Array[Vector2i] = [middle + Vector2i(-half - 1, -half - 1)]
	for i in range(-half, half + 1):
		cells.append(middle + Vector2i(-half - 1, i))
		cells.append(middle + Vector2i(i, -half - 1))
	var placed: int = 0
	for cell in cells:
		var b = main.build_system.place_at("wall", cell, main.buildings_container, true)
		if b != null:
			b.complete_construction()
			placed += 1
	assert_gt(placed, 2, "Some stakes went up beside the cabin")
	await nav_settled(main)

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
	await nav_settled(main)
	var outside: Vector3 = core + Vector3(0.0, 0.0, -9.0)

	assert_false(main.nav_maps.is_reachable(outside, core), "A raid still has no way in")
	assert_false(main.nav_maps.is_reachable(outside, core, true), "Nor the Hero, with no gate in it")

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

	# Ordered, with a gate in it, and then LEFT for a while, which is the part that matters.
	var ordered: Array[Node] = ring_in_level(main, core, 4.0, false, 0.0)
	assert_gt(ordered.size(), 12, "A ring was ordered")
	await nav_settled(main)
	assert_true(main.nav_maps.is_reachable(outside, core),
		"Ordered and not built, it stops nobody -- which is the blueprint rule")

	# Now the Hero finishes them, and nothing else in the world happens.
	for b in ordered:
		if is_instance_valid(b):
			b.complete_construction()
	await nav_settled(main)

	assert_false(main.nav_maps.is_reachable(outside, core),
		"Finished, it stops a raid -- without anything else being built to jog the meshes")
	assert_true(main.nav_maps.is_reachable(outside, core, true), "And the Hero gets in by its gate")
