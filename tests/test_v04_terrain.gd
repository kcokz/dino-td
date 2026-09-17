# res://tests/test_v04_terrain.gd
# v0.4: hills are a gameplay object, not scenery.
#
# Terrain nobody crosses narrows the approach, and a narrowed approach is what
# finally gives stake and turret placement an answer -- on an open field every
# spot is as good as every other. That only works if the hills stop the raid as
# well as the player, so dinosaurs route around them instead of following a fixed
# corridor.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var grid_script: GDScript = null
var build_system_script: GDScript = null
var hero_script: GDScript = null
var dino_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
	grid_script = load("res://scripts/core/GridManager.gd")
	build_system_script = load("res://scripts/core/BuildSystem.gd")
	hero_script = load("res://scripts/entities/Hero.gd")
	dino_script = load("res://scripts/entities/Dino.gd")

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
	clear_drops()
	super.after_each()

func _grid(blocked: Array = []) -> Node:
	var gm = grid_script.new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	return gm

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

# ==============================================================================
# 1. The rule
# ==============================================================================

func test_01_a_hill_is_neither_walkable_nor_buildable() -> void:
	var gm = _grid([Vector2i(2, 2)])
	var builder = build_system_script.new()
	_cleanup_nodes.append(builder)
	tree.root.add_child(builder)
	builder.setup(gm, null)
	await wait_frames(1)
	pay_for(["wall"], 99)

	assert_true(gm.is_cell_blocked(Vector2i(2, 2)), "The cell is hillside")
	assert_false(gm.is_cell_walkable(Vector2i(2, 2)), "Nobody walks through it")
	assert_false(builder.can_place_building("wall", Vector2i(2, 2)), "And nothing is built on it")

	assert_false(gm.is_cell_blocked(Vector2i(2, 3)), "Its neighbour is ordinary ground")
	assert_true(builder.can_place_building("wall", Vector2i(2, 3)), "Which can still be built on")

func test_02_terrain_is_not_something_a_restart_clears() -> void:
	# Hills are the map, not anything the player did to it.
	var gm = _grid([Vector2i(1, 1)])
	await wait_frames(1)
	gm.occupy_cell(Vector2i(3, 3), Node3D.new())

	gm.clear_grid()
	assert_false(gm.is_cell_occupied(Vector2i(3, 3)), "A new game takes the buildings")
	assert_true(gm.is_cell_blocked(Vector2i(1, 1)), "And leaves the landscape where it was")

func test_03_the_hero_walks_around_a_hill_rather_than_through_it() -> void:
	var gm = _grid([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)])
	await wait_frames(1)

	var path: Array = gm.find_path(gm.cell_to_world(Vector2i(1, 0)), gm.cell_to_world(Vector2i(1, 2)))
	assert_gt(path.size(), 0, "There is a way round")
	for pt in path:
		assert_false(gm.is_cell_blocked(gm.world_to_cell(pt)), "And no step of it is hillside")

func test_04_the_level_lays_its_hills_before_anything_else() -> void:
	var main = _level()
	await wait_frames(2)

	var declared: Array = config_node.MAP.get("default_blocked_cells", [])
	assert_gt(declared.size(), 0, "The map declares terrain")
	for c in declared:
		assert_true(main.grid_manager.is_cell_blocked(c), "%s is hillside in play" % str(c))
	assert_not_null(main.terrain_container, "And there is something standing there to see")
	assert_eq(main.terrain_container.get_child_count(), declared.size(),
		"One hill on the map per cell in Config")

func test_05_no_hill_sits_on_a_resource_node_or_seals_the_path() -> void:
	# Two rules for the layout: the raid has to be able to arrive, and a hill must
	# never bury something the Hero needs to harvest.
	var main = _level()
	await wait_frames(2)
	var blocked: Array = config_node.MAP.get("default_blocked_cells", [])

	for item in config_node.MAP.get("default_resource_nodes", []):
		assert_false(blocked.has(item["cell"]), "No hill is sitting on the %s at %s" % [item["type"], str(item["cell"])])

	# The nest has to be able to reach the cabin.
	var from_pos: Vector3 = main.grid_manager.cell_to_world(config_node.MAP["default_nest_cell"])
	var to_pos: Vector3 = main.grid_manager.cell_to_world(config_node.MAP["default_core_cell"])
	var path: Array = main.grid_manager.find_path(from_pos, to_pos, null, true)
	assert_gt(path.size(), 0, "A raid can still get from the nest to the cabin")

# ==============================================================================
# 2. Dinosaurs respect it, which is the whole point
# ==============================================================================

func test_06_a_dinosaur_routes_around_a_hill_in_its_way() -> void:
	var gm = _grid([Vector2i(0, -1), Vector2i(0, -2)])
	await wait_frames(1)

	var dino = dino_script.new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	dino.global_position = gm.cell_to_world(Vector2i(0, -4))
	var wps: Array[Vector3] = [gm.cell_to_world(Vector2i(0, 1))]
	dino.waypoints = wps
	dino.current_waypoint_index = 0
	await wait_frames(1)

	# Straight ahead is hillside, so it must be steering somewhere else.
	assert_false(dino._line_is_clear(dino.global_position, dino.waypoints[0]),
		"The direct line runs into a hill")
	var steer: Vector3 = dino._steer_target(dino.waypoints[0])
	assert_ne(steer, dino.waypoints[0], "So it heads for a way round instead")
	assert_false(gm.is_cell_blocked(gm.world_to_cell(steer)), "And that way round is walkable")

func test_07_open_ground_is_unchanged() -> void:
	# The route only comes out when the landscape is in the way; a straight run
	# still steers straight at the waypoint, so flocking and flanking are untouched.
	var gm = _grid([])
	await wait_frames(1)
	var dino = dino_script.new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	dino.global_position = gm.cell_to_world(Vector2i(0, -4))
	var goal: Vector3 = gm.cell_to_world(Vector2i(0, 1))
	await wait_frames(1)

	assert_true(dino._line_is_clear(dino.global_position, goal), "Nothing is in the way")
	assert_eq(dino._steer_target(goal), goal, "So it heads straight for it")
	assert_true(dino.nav_path.is_empty(), "And keeps no route it does not need")

func test_08_nothing_ends_up_standing_in_a_hill() -> void:
	# Separation and flanking both shove sideways and neither knows about the
	# landscape, so the last word belongs to the terrain.
	var gm = _grid([Vector2i(0, 0)])
	await wait_frames(1)
	var dino = dino_script.new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	var safe: Vector3 = gm.cell_to_world(Vector2i(0, 1))
	dino.global_position = safe
	await wait_frames(1)

	dino.global_position = gm.cell_to_world(Vector2i(0, 0))   # shoved into the hill
	dino._keep_off_the_hills(safe)
	assert_eq(dino.global_position, safe, "It is put back where it came from")
	assert_false(gm.is_cell_blocked(gm.world_to_cell(dino.global_position)), "Out of the scenery")

func test_09_a_building_against_a_hill_loses_the_slots_behind_it() -> void:
	# Sixteen places to stand and chew, minus the ones inside the hillside -- a slot
	# nothing can reach would park a dinosaur in the scenery.
	var gm = _grid([])
	await wait_frames(1)
	var open_building := StaticBody3D.new()
	_cleanup_nodes.append(open_building)
	tree.root.add_child(open_building)
	open_building.global_position = gm.cell_to_world(Vector2i(0, 0))
	await wait_frames(1)

	Dino.clear_all_attack_slots()
	Dino._init_building_slots(open_building)
	var open_count: int = Dino._building_slots[open_building.get_instance_id()].size()
	assert_gt(open_count, 0, "On open ground there are places to stand")

	gm.set_blocked_cells([Vector2i(1, 0), Vector2i(-1, 0)])
	Dino.clear_all_attack_slots()
	Dino._init_building_slots(open_building)
	var walled_count: int = Dino._building_slots[open_building.get_instance_id()].size()
	assert_lt(walled_count, open_count, "Hemmed in, there are fewer")
	for slot in Dino._building_slots[open_building.get_instance_id()]:
		assert_false(gm.is_cell_blocked(gm.world_to_cell(slot["pos"])),
			"And not one of them is inside a hill")
	Dino.clear_all_attack_slots()

func test_10_a_dinosaur_walks_around_a_hill_but_bites_a_fence() -> void:
	# The distinction that keeps the fence meaningful: terrain is routed around,
	# buildings are not. Pathing politely around the stakes the player just planted
	# would make planting them pointless.
	var gm = _grid([Vector2i(0, -1)])
	await wait_frames(1)

	var through_building: Array = gm.find_path(
		gm.cell_to_world(Vector2i(2, -1)), gm.cell_to_world(Vector2i(2, 1)), null, true)
	assert_gt(through_building.size(), 0, "A route exists")

	# With terrain_only the search ignores buildings entirely...
	var wall := StaticBody3D.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	gm.occupy_cell(Vector2i(2, 0), wall)
	assert_false(gm.is_cell_walkable(Vector2i(2, 0)), "A building blocks ordinary pathing")
	assert_true(gm.is_cell_walkable(Vector2i(2, 0), null, true),
		"But a dinosaur walks at it rather than around it")
	assert_false(gm.is_cell_walkable(Vector2i(0, -1), null, true),
		"While a hill stops it either way")

# ==============================================================================
# 3. A fence is a panel: thin across the run, gapless along it
# ==============================================================================

func _wall_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

func _collision_size(b: Node) -> Vector3:
	for child in b.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return child.shape.size
	return Vector3.ZERO

func test_11_a_stake_on_its_own_closes_its_whole_tile() -> void:
	# Plant one in a doorway and it has to shut the doorway. It only slims down
	# once it is part of a run, because only then do its neighbours cover the rest.
	var gm = _grid([])
	await wait_frames(1)
	var lone = _wall_at(gm, Vector2i(0, 0))
	lone.fit_to_fence()

	assert_eq(lone.fence_axis(), "both", "Standing alone, it faces both ways")
	var size: Vector3 = _collision_size(lone)
	var tile: float = float(config_node.TILE_SIZE)
	assert_almost_eq(size.x, tile, 0.01, "Full width east-west")
	assert_almost_eq(size.z, tile, 0.01, "And full width north-south")

func test_12_a_run_of_stakes_turns_into_a_thin_panel() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var a = _wall_at(gm, Vector2i(0, 0))
	var b = _wall_at(gm, Vector2i(1, 0))
	var c = _wall_at(gm, Vector2i(2, 0))
	for w in [a, b, c]:
		w.fit_to_fence()

	assert_eq(b.fence_axis(), "x", "The middle of an east-west run knows which way it runs")
	var size: Vector3 = _collision_size(b)
	var tile: float = float(config_node.TILE_SIZE)
	var thin: float = float(config_node.BUILDINGS["wall"]["thickness"])
	assert_almost_eq(size.x, tile, 0.01, "It spans its tile along the fence, so the line has no holes")
	assert_almost_eq(size.z, thin, 0.01, "And is only as deep as it looks across the fence")
	assert_lt(thin, tile, "Which is what stops a fence looking like a wall")

func test_13_a_north_south_run_turns_the_other_way() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var a = _wall_at(gm, Vector2i(0, 0))
	var b = _wall_at(gm, Vector2i(0, 1))
	var c = _wall_at(gm, Vector2i(0, 2))
	for w in [a, b, c]:
		w.fit_to_fence()

	assert_eq(b.fence_axis(), "z", "A north-south run is recognised too")
	var size: Vector3 = _collision_size(b)
	assert_almost_eq(size.z, float(config_node.TILE_SIZE), 0.01, "Spanning its tile north-south")
	assert_almost_eq(size.x, float(config_node.BUILDINGS["wall"]["thickness"]), 0.01, "Thin east-west")

func test_14_the_panel_and_the_collision_are_the_same_shape() -> void:
	# The two ways a fence can lie: a gap you cannot walk through, and an edge that
	# stops you without being visible. Both come from the mesh and the box
	# disagreeing, so they are cut from the same numbers.
	var gm = _grid([])
	await wait_frames(1)
	var a = _wall_at(gm, Vector2i(0, 0))
	var b = _wall_at(gm, Vector2i(1, 0))
	for w in [a, b]:
		w.fit_to_fence()

	var box: Vector3 = _collision_size(b)
	var body := b.find_child("Body", false, false)
	assert_not_null(body, "It has a body")
	var mesh: MeshInstance3D = null
	for child in body.get_children():
		if child is MeshInstance3D:
			mesh = child
	assert_not_null(mesh, "Drawn from one mesh")

	# The body is turned a quarter for a north-south run, so compare the pair of
	# horizontal extents rather than the axes by name.
	var drawn: Vector3 = mesh.mesh.size
	var drawn_pair := Vector2(minf(drawn.x, drawn.z), maxf(drawn.x, drawn.z))
	var box_pair := Vector2(minf(box.x, box.z), maxf(box.x, box.z))
	assert_almost_eq(drawn_pair.x, box_pair.x, 0.01, "Drawn as thin as it blocks")
	assert_almost_eq(drawn_pair.y, box_pair.y, 0.01, "And as wide as it blocks")
	assert_almost_eq(drawn.y, box.y, 0.01, "And as tall")

func test_15_extending_a_fence_reshapes_the_stake_already_there() -> void:
	# A neighbour going up changes which way the run goes, so the old stake has to
	# hear about it -- otherwise the first stake of every fence stays a block.
	var gm = _grid([])
	await wait_frames(1)
	var first = _wall_at(gm, Vector2i(0, 0))
	first.fit_to_fence()
	assert_eq(first.fence_axis(), "both", "Alone to begin with")

	var second = _wall_at(gm, Vector2i(1, 0))
	second.fit_to_fence()
	first.fit_to_fence()
	assert_eq(first.fence_axis(), "x", "Once it has a neighbour it is part of a run")
	assert_almost_eq(_collision_size(first).z, float(config_node.BUILDINGS["wall"]["thickness"]), 0.01,
		"And slims down to match")
