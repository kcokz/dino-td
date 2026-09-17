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
# 3. A fence is a row of small cones: thin across the run, gapless along it
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

func _collision_sizes(b: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for child in b.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			out.append(child.shape.size)
	return out

func _collision_size(b: Node) -> Vector3:
	var all_sizes := _collision_sizes(b)
	return all_sizes[0] if not all_sizes.is_empty() else Vector3.ZERO

## Where the cones stand in the stake's own space, along one arm of the shape.
func _cone_positions(b: Node, axis: String) -> Array[float]:
	var out: Array[float] = []
	var body := b.find_child("Body", false, false)
	if body == null:
		return out
	for child in body.get_children():
		if child is MeshInstance3D:
			var at: Vector3 = child.position
			# A cross has an arm on each axis; keep only the arm being measured.
			if axis == "x" and absf(at.z) > 0.001:
				continue
			if axis == "z" and absf(at.x) > 0.001:
				continue
			out.append(at.x if axis == "x" else at.z)
	out.sort()
	return out

func _thin() -> float:
	return float(config_node.get_building_thickness("wall"))

func _longest(sizes: Array[Vector3], axis: String) -> float:
	var best: float = 0.0
	for size in sizes:
		best = maxf(best, size.x if axis == "x" else size.z)
	return best

func test_11_a_stake_on_its_own_closes_its_tile_without_becoming_a_block() -> void:
	# Plant one in a doorway and it has to shut the doorway, so a lone stake still
	# reaches across its tile both ways. What it must NOT be is a filled tile: a
	# block of stakes is nothing but corners, and while a corner meant "full tile"
	# every stake in a block turned back into the big square the player kept seeing.
	var gm = _grid([])
	await wait_frames(1)
	var lone = _wall_at(gm, Vector2i(0, 0))
	lone.fit_to_fence()

	assert_eq(lone.fence_axis(), "both", "Standing alone, it faces both ways")
	var sizes := _collision_sizes(lone)
	var tile: float = float(config_node.TILE_SIZE)
	var thin: float = _thin()
	assert_eq(sizes.size(), 2, "A cross: one arm each way, not one filled tile")
	for size in sizes:
		assert_almost_eq(maxf(size.x, size.z), tile, 0.01, "Each arm reaches across its tile")
		assert_almost_eq(minf(size.x, size.z), thin, 0.01, "And each arm is only as deep as a spike")
	assert_almost_eq(_longest(sizes, "x"), tile, 0.01, "So nothing crosses east-west")
	assert_almost_eq(_longest(sizes, "z"), tile, 0.01, "And nothing crosses north-south")

func test_12_a_run_of_stakes_turns_into_one_thin_line() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var a = _wall_at(gm, Vector2i(0, 0))
	var b = _wall_at(gm, Vector2i(1, 0))
	var c = _wall_at(gm, Vector2i(2, 0))
	for w in [a, b, c]:
		w.fit_to_fence()

	assert_eq(b.fence_axis(), "x", "The middle of an east-west run knows which way it runs")
	var sizes := _collision_sizes(b)
	assert_eq(sizes.size(), 1, "One line, not a cross: it only runs one way")
	var tile: float = float(config_node.TILE_SIZE)
	var thin: float = _thin()
	assert_almost_eq(sizes[0].x, tile, 0.01, "It spans its tile along the fence, so the line has no holes")
	assert_almost_eq(sizes[0].z, thin, 0.01, "And is only as deep as a spike across the fence")
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
	assert_almost_eq(size.x, _thin(), 0.01, "Thin east-west")

func test_14_the_cones_and_the_collision_are_the_same_shape() -> void:
	# The two ways a fence can lie: a gap you cannot walk through, and an edge that
	# stops you without being visible. Both come from the art and the box
	# disagreeing, so they are cut from the same numbers.
	var gm = _grid([])
	await wait_frames(1)
	var a = _wall_at(gm, Vector2i(0, 0))
	var b = _wall_at(gm, Vector2i(1, 0))
	for w in [a, b]:
		w.fit_to_fence()

	var box: Vector3 = _collision_size(b)
	var diameter: float = float(config_node.get_spike_diameter("wall"))
	assert_almost_eq(box.z, diameter, 0.01,
		"Across the run the box is exactly one cone deep, so nothing is held off at a distance")
	assert_almost_eq(box.y, float(config_node.get_building_height("wall")), 0.01, "And as tall as a cone")

	# Along the run the box closes the daylight between cones. That is the one place
	# box and art differ, and it is by one crack that nothing can fit through.
	var cones := _cone_positions(b, "x")
	var drawn: float = (cones[cones.size() - 1] - cones[0]) + diameter
	var slack: float = box.x - drawn
	assert_almost_eq(slack, float(config_node.get_spike_pitch("wall")) - diameter, 0.01,
		"The box is longer than the cones by exactly the daylight between two of them")
	assert_lt(slack, float(config_node.HERO.get("width", 0.8)),
		"Which is far too narrow for anything to use")

func test_15_extending_a_fence_reshapes_the_stake_already_there() -> void:
	# A neighbour going up changes which way the run goes, so the old stake has to
	# hear about it -- otherwise the first stake of every fence keeps its cross.
	var gm = _grid([])
	await wait_frames(1)
	var first = _wall_at(gm, Vector2i(0, 0))
	first.fit_to_fence()
	assert_eq(first.fence_axis(), "both", "Alone to begin with")

	var second = _wall_at(gm, Vector2i(1, 0))
	second.fit_to_fence()
	first.fit_to_fence()
	assert_eq(first.fence_axis(), "x", "Once it has a neighbour it is part of a run")
	assert_eq(_collision_sizes(first).size(), 1, "The cross collapses into a line")
	assert_almost_eq(_collision_size(first).z, _thin(), 0.01, "And slims down to match")

func test_16_the_spikes_are_small_and_evenly_spaced_across_a_tile_boundary() -> void:
	# What the fence is for the player: small cones with no gap worth seeing between
	# them, so a row reads as one picket line. The spacing has to come out identical
	# inside a tile and across a tile boundary, or a long fence shows a visible clump
	# at every tile edge.
	var gm = _grid([])
	await wait_frames(1)
	var a = _wall_at(gm, Vector2i(0, 0))
	var b = _wall_at(gm, Vector2i(1, 0))
	var c = _wall_at(gm, Vector2i(2, 0))
	for w in [a, b, c]:
		w.fit_to_fence()

	var pitch: float = float(config_node.get_spike_pitch("wall"))
	var diameter: float = float(config_node.get_spike_diameter("wall"))
	var tile: float = float(config_node.TILE_SIZE)
	var per_tile: int = int(config_node.get_spikes_per_tile("wall"))

	assert_eq(_cone_positions(b, "x").size(), per_tile,
		"A tile of fence is drawn as the declared number of cones")
	assert_lt(diameter, pitch, "Each cone is narrower than the space it stands in")
	assert_lt(diameter, tile * 0.5, "And small, nothing like the tile-wide slab it used to be")

	# Every cone along three tiles of fence, measured in world space.
	var centres: Array[float] = []
	for w in [a, b, c]:
		for local_x in _cone_positions(w, "x"):
			centres.append(w.global_position.x + local_x)
	centres.sort()
	assert_eq(centres.size(), 3 * per_tile, "Three tiles of cones")
	for i in range(1, centres.size()):
		assert_almost_eq(centres[i] - centres[i - 1], pitch, 0.01,
			"Cone %d stands one pitch from the last, tile boundary or not" % i)
		assert_lt(centres[i] - centres[i - 1] - diameter, 0.2,
			"So the daylight between any two cones is a crack, not a gap")

func test_17_the_ghost_shows_the_shape_the_cell_would_actually_get() -> void:
	# The reported bug: hover showed one shape and placing produced another. Both now
	# come out of Wall.axis_at, so the question is only asked in one place.
	var gm = _grid([])
	await wait_frames(1)
	var a = _wall_at(gm, Vector2i(0, 0))
	a.fit_to_fence()

	var wall_cls: GDScript = load("res://scripts/entities/Wall.gd")
	assert_eq(wall_cls.axis_at(gm, Vector2i(5, 5)), "both",
		"Out on its own, the ghost promises a cross")
	var promised: String = wall_cls.axis_at(gm, Vector2i(1, 0))
	assert_eq(promised, "x", "Beside an existing stake, the ghost promises a line")

	var placed = _wall_at(gm, Vector2i(1, 0))
	placed.fit_to_fence()
	assert_eq(placed.fence_axis(), promised, "And that is the shape the placed stake has")
	assert_eq(_collision_sizes(placed).size(), 1, "A line, exactly as promised")

func test_18_the_ghost_in_the_real_level_is_redrawn_when_the_shape_changes() -> void:
	# Closing the loop through Main, because the reported bug was in the ghost and not
	# in the stake: hovering always drew the lone-stake shape, so the stake that
	# appeared was a different shape from the one promised. The ghost now asks the
	# grid the same question the stake will.
	var main = _level()
	await wait_frames(2)
	var gm = main.grid_manager
	var here := Vector2i(6, 6)
	var beside := Vector2i(7, 6)

	main._rebuild_build_preview("wall", main._preview_axis_for("wall", beside))
	assert_eq(main._preview_axis, "both", "Nothing nearby, so the ghost is a cross")
	var lone_cones: int = _preview_cone_count(main)

	var neighbour = _wall_at(gm, here)
	neighbour.fit_to_fence()

	var axis: String = main._preview_axis_for("wall", beside)
	assert_eq(axis, "x", "Next to that stake the ghost has to promise a line")
	main._rebuild_build_preview("wall", axis)
	assert_eq(main._preview_axis, "x", "And the ghost is rebuilt as one")

	var line_cones: int = _preview_cone_count(main)
	assert_eq(line_cones, int(config_node.get_spikes_per_tile("wall")), "A line of cones")
	assert_lt(line_cones, lone_cones, "Fewer than the cross it would have been on its own")

	main._clear_build_preview()
	assert_eq(main._preview_axis, "", "Putting the ghost away forgets the shape with it")

func _preview_cone_count(main: Node) -> int:
	var count: int = 0
	var ghost = main.build_preview
	if ghost == null:
		return 0
	for node in ghost.find_children("*", "MeshInstance3D", true, false):
		if node != main.build_preview_ring:
			count += 1
	return count
