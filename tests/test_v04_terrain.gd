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
# 3. A stake is one stake
# ==============================================================================
#
# What used to be here was eight tests about a fence working out its shape from its
# neighbours: lines, corners, crosses, seam-to-seam cone spacing, and a ghost that had
# to predict all of it. That system was rebuilt four times, produced a fresh bug every
# time, and was never asked for -- the request, the first time and every time since,
# was one stake.
#
# So it is deleted rather than repaired. These tests hold what replaced it, and the
# point of every one of them is that NOTHING about a stake depends on its neighbours.

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
			return (child.shape as BoxShape3D).size
	return Vector3.ZERO

func _cones(b: Node) -> Array:
	var out: Array = []
	var body := b.find_child("Body", false, false)
	if body == null:
		return out
	for child in body.get_children():
		if child is MeshInstance3D:
			out.append(child)
	return out

func test_11_a_stake_is_one_cone_no_matter_what_is_beside_it() -> void:
	# The whole of the fix, stated once. A stake on its own, a stake in a row, a stake
	# at a corner and a stake in the middle of a block are all the same one cone.
	var gm = _grid([])
	await wait_frames(1)

	var lone = _wall_at(gm, Vector2i(9, 9))
	assert_eq(_cones(lone).size(), 1, "On its own: one cone")

	# A row.
	var row: Array = []
	for x in range(0, 3):
		row.append(_wall_at(gm, Vector2i(x, 0)))
	await wait_frames(1)
	for w in row:
		assert_eq(_cones(w).size(), 1, "In a row: still one cone")

	# A corner, and then a solid block -- the arrangement that used to turn every
	# stake in it back into the big shape.
	_wall_at(gm, Vector2i(2, 1))
	_wall_at(gm, Vector2i(1, 1))
	_wall_at(gm, Vector2i(0, 1))
	await wait_frames(1)
	for w in row:
		assert_eq(_cones(w).size(), 1, "In a block: still one cone")
	assert_eq(_cones(lone).size(), 1, "And the lone one never changed either")

func test_12_a_stake_is_drawn_as_a_cone_of_the_declared_width() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var stake = _wall_at(gm, Vector2i(0, 0))

	var cones := _cones(stake)
	assert_eq(cones.size(), 1, "One cone")
	var mesh: CylinderMesh = cones[0].mesh as CylinderMesh
	assert_not_null(mesh, "Drawn as a cone")
	assert_almost_eq(mesh.top_radius, 0.0, 0.001, "Sharpened to a point")
	assert_almost_eq(mesh.bottom_radius * 2.0, float(config_node.get_spike_diameter("wall")), 0.001,
		"As wide as Config declares -- a plain number now, not derived from a cone count")
	assert_almost_eq(mesh.height, float(config_node.get_building_height("wall")), 0.001,
		"And as tall as Config declares")
	assert_lt(float(config_node.get_spike_diameter("wall")), float(config_node.TILE_SIZE) * 0.5,
		"Small: nowhere near the tile-wide slab it used to be")

func test_13_a_stake_stops_you_where_the_stake_is() -> void:
	# This test used to record the opposite as a deliberate trade: a stake blocked its
	# whole tile while being drawn as one small cone in the middle of it. It said the
	# change would be one number and would announce itself here. It did.
	#
	# The trade was not worth what it cost: a gap the player could plainly see between
	# a stake and a hillside was solid, because the tile was claimed whether or not
	# anything stood in the part he was walking through.
	var gm = _grid([])
	await wait_frames(1)
	var stake = _wall_at(gm, Vector2i(0, 0))

	var tile: float = float(config_node.TILE_SIZE)
	var size: Vector3 = _collision_size(stake)
	assert_almost_eq(size.x, float(config_node.get_spike_diameter("wall")), 0.01,
		"The box that stops you is the cone you can see")
	assert_almost_eq(size.z, float(config_node.get_spike_diameter("wall")), 0.01, "On both axes")
	assert_gt(tile - size.x, float(config_node.HERO.get("width", 0.8)),
		"So there is room beside it, which is what the player was looking at")

func test_14_the_ghost_cannot_disagree_with_the_stake_any_more() -> void:
	# The reported bug, made impossible rather than fixed. The ghost and the stake are
	# the same call with the same arguments: there is no arrangement left to get wrong,
	# and no neighbour for either of them to ask about.
	var gm = _grid([])
	await wait_frames(1)
	var neighbour = _wall_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	var ghost: Node3D = Building.make_body("wall")
	_cleanup_nodes.append(ghost)
	var ghost_cones: int = 0
	for child in ghost.get_children():
		if child is MeshInstance3D:
			ghost_cones += 1
	assert_eq(ghost_cones, 1, "The ghost is one cone")

	# Beside an existing stake -- the case that used to change the answer.
	var placed = _wall_at(gm, Vector2i(1, 0))
	await wait_frames(1)
	assert_eq(_cones(placed).size(), ghost_cones,
		"And the stake that lands beside one is exactly what the ghost promised")

func test_15_nothing_reshapes_a_stake_after_it_is_built() -> void:
	# There is no longer any code path that redraws a standing stake, which is what the
	# player was seeing when a blueprint of five cones became three. Putting a stake up
	# next door must leave its neighbour's body untouched.
	var gm = _grid([])
	await wait_frames(1)
	var first = _wall_at(gm, Vector2i(0, 0))
	await wait_frames(1)
	var before: Node = first.find_child("Body", false, false)
	var before_cones: int = _cones(first).size()

	_wall_at(gm, Vector2i(1, 0))
	_wall_at(gm, Vector2i(0, 1))
	await wait_frames(2)

	assert_eq(_cones(first).size(), before_cones, "Its cone count did not move")
	assert_eq(first.find_child("Body", false, false), before,
		"And its body was never torn down and rebuilt")
