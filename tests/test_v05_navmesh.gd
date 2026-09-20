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
