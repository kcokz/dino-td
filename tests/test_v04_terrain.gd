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

var _world: Node3D = null

## The fixture, which since v0.5 has a NAVIGATION MESH over it -- with the hillside as
## real boxes, the same shape and layer Main.spawn_terrain lays down. The grid rule and
## the collider go down together there, and they go down together here.
func _grid(blocked: Array = []) -> Node:
	var gm = grid_script.new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	for c in blocked:
		if c is Vector2i:
			block_out_a_hill(_world, gm, c)
	await rebake_fixture()
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
	var gm = await _grid([Vector2i(2, 2)])
	var builder = build_system_script.new()
	_cleanup_nodes.append(builder)
	tree.root.add_child(builder)
	builder.setup(gm, null)
	await wait_frames(1)
	pay_for(["wall"], 99)

	assert_true(gm.is_cell_blocked(Vector2i(2, 2)), "The cell is hillside")
	var hill: Vector3 = gm.cell_to_world(Vector2i(2, 2))
	var nearest: Vector3 = maps_of().closest_point(hill, true)
	assert_gt(Vector2(nearest.x - hill.x, nearest.z - hill.z).length(), float(gm.tile_size) * 0.5,
		"Nobody stands in it: the nearest ground is outside it")
	assert_false(builder.can_place_building("wall", Vector2i(2, 2)), "And nothing is built on it")

	assert_false(gm.is_cell_blocked(Vector2i(2, 3)), "Its neighbour is ordinary ground")
	assert_true(builder.can_place_building("wall", Vector2i(2, 3)), "Which can still be built on")

func test_02_terrain_is_not_something_a_restart_clears() -> void:
	# Hills are the map, not anything the player did to it.
	var gm = await _grid([Vector2i(1, 1)])
	await wait_frames(1)
	gm.occupy_cell(Vector2i(3, 3), Node3D.new())

	gm.clear_grid()
	assert_false(gm.is_cell_occupied(Vector2i(3, 3)), "A new game takes the buildings")
	assert_true(gm.is_cell_blocked(Vector2i(1, 1)), "And leaves the landscape where it was")

func test_03_the_hero_walks_around_a_hill_rather_than_through_it() -> void:
	var gm = await _grid([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)])
	await wait_frames(1)

	var path: PackedVector3Array = maps_of().path(
		gm.cell_to_world(Vector2i(1, 0)), gm.cell_to_world(Vector2i(1, 2)), true)
	assert_gt(path.size(), 0, "There is a way round")
	for pt in path:
		assert_false(gm.is_cell_blocked(gm.world_to_cell(pt)), "And no step of it is hillside")

func test_04_the_level_lays_its_hills_before_anything_else() -> void:
	var main = _level()
	await wait_frames(2)

	var declared: Array = config_node.map_data().get("default_blocked_cells", [])
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
	var blocked: Array = config_node.map_data().get("default_blocked_cells", [])

	for item in config_node.map_data().get("default_resource_nodes", []):
		assert_false(blocked.has(item["cell"]), "No hill is sitting on the %s at %s" % [item["type"], str(item["cell"])])

	# The nest has to be able to reach the cabin.
	var from_pos: Vector3 = main.grid_manager.cell_to_world(config_node.map_data()["default_nest_cell"])
	var to_pos: Vector3 = cabin_at(main)
	assert_true(main.nav_maps.is_reachable(from_pos, to_pos),
		"A raid can still get from the nest to the cabin")

# ==============================================================================
# 2. Dinosaurs respect it, which is the whole point
# ==============================================================================

func test_06_a_dinosaur_routes_around_a_hill_in_its_way() -> void:
	var gm = await _grid([Vector2i(0, -1), Vector2i(0, -2)])
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

	# Straight ahead is hillside, so the route it is given bends round it (NavMaps.path, on the
	# mesh the hill is carved out of) and the corner it heads for first is not the goal.
	var steer: Vector3 = dino._next_step_towards(dino.waypoints[0])
	assert_gt(dino._route.size(), 2, "The route has a corner in it: the way round")
	assert_gt(Vector2(steer.x, steer.z).distance_to(Vector2(dino.waypoints[0].x, dino.waypoints[0].z)), 0.5,
		"So it heads for a way round instead")
	assert_false(gm.is_cell_blocked(gm.world_to_cell(steer)), "And that way round is walkable")

func test_07_open_ground_is_unchanged() -> void:
	# The route only comes out when the landscape is in the way; a straight run
	# still steers straight at the waypoint, so flocking and flanking are untouched.
	var gm = await _grid([])
	await wait_frames(1)
	var dino = dino_script.new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	dino.global_position = gm.cell_to_world(Vector2i(0, -4))
	var goal: Vector3 = gm.cell_to_world(Vector2i(0, 1))
	await wait_frames(1)

	var steer: Vector3 = dino._next_step_towards(goal)
	# Nothing is in the way: every corner of the route is on the straight line (the mesh may
	# keep a point where the line crosses one of its own edges -- a corner that turns nothing).
	var a := Vector2(dino.global_position.x, dino.global_position.z)
	var line := (Vector2(goal.x, goal.z) - a).normalized()
	for pt in dino._route:
		var off: Vector2 = Vector2(pt.x, pt.z) - a
		assert_almost_eq(off.x * line.y - off.y * line.x, 0.0, 0.05, "The route runs straight (%s)" % str(pt))
	var heading := (Vector2(steer.x, steer.z) - a).normalized()
	assert_gt(heading.dot(line), 0.999, "So it heads straight for it")

func test_08_nothing_ends_up_standing_in_a_hill() -> void:
	# Whatever steers it, the last word belongs to the terrain: its body stops at a hillside
	# like at anything else (v0.6 round two -- the hand-written "put it back" is gone).
	var gm = await _grid([Vector2i(0, 0)])
	await wait_frames(1)
	var dino = dino_script.new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	var safe: Vector3 = gm.cell_to_world(Vector2i(0, 1))
	dino.global_position = safe
	await wait_frames(1)

	# Driven straight at the hill for a second, the way a bad steer would.
	var into: Vector3 = (gm.cell_to_world(Vector2i(0, 0)) - safe).normalized()
	for i in range(60):
		dino._move_body(into * (float(dino.speed) / 60.0))
	assert_false(gm.is_cell_blocked(gm.world_to_cell(dino.global_position)), "Out of the scenery")

func test_09_a_building_against_a_hill_loses_the_slots_behind_it() -> void:
	# Sixteen places to stand and chew, minus the ones inside the hillside -- a slot
	# nothing can reach would park a dinosaur in the scenery.
	var gm = await _grid([])
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
	var gm = await _grid([Vector2i(0, -1)])
	await wait_frames(1)

	assert_true(maps_of().is_reachable(
		gm.cell_to_world(Vector2i(2, -1)), gm.cell_to_world(Vector2i(2, 1))), "A route exists")

	# A line of wall right across the fixture. The raid's map has no way through it; the siege map, which is what a raid asks for the wall
	# in its way, walks straight at it -- and a hill is in that one too.
	var z: float = gm.cell_to_world(Vector2i(0, 0)).z
	run_of_stakes(_world, gm, Vector3(-31.0, 0.0, z), Vector3(31.0, 0.0, z))
	await rebake_fixture()
	var a: Vector3 = gm.cell_to_world(Vector2i(2, -1))
	var b: Vector3 = gm.cell_to_world(Vector2i(2, 1))
	assert_false(maps_of().is_reachable(a, b, NavMaps.For.RAID), "A wall blocks ordinary pathing")
	assert_true(maps_of().is_reachable(a, b, NavMaps.For.SIEGE),
		"But a dinosaur walks at it rather than around it")
	var hill: Vector3 = gm.cell_to_world(Vector2i(0, -1))
	var nearest: Vector3 = maps_of().closest_point(hill, NavMaps.For.SIEGE)
	assert_gt(Vector2(nearest.x - hill.x, nearest.z - hill.z).length(), float(gm.tile_size) * 0.5,
		"While a hill stops it either way: there is no ground inside it on that map either")

# ==============================================================================
# 3. A section of wall is its cell
# ==============================================================================
#
# This was "a stake is one stake": eight tests about a fence working out its SHAPE from its
# neighbours were deleted after it was rebuilt four times, and what replaced them held a stake
# to one small cone with a collider its own size, whatever stood beside it.
#
# v0.6 round two asked for the opposite of the cone -- "墙体逻辑简单清晰……木栅栏可以稍微大一点"
# -- and a section of wall is a whole cell of the building grid now. Its art DOES reach towards
# its neighbours (Wall.dress, in test_v06_one_grid), but only the art: what stops you is the
# cell, the same whatever is beside it, and the body is never torn down to show it. Tests 11 to
# 14 were about the cone and went with it; what is left is the lesson that outlived it.

func _wall_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

## The pieces a section is drawn with, at any depth inside its Body -- a model's meshes sit
## inside the imported scene's own nodes, where a one-level search finds nothing.
func _cones(b: Node) -> Array:
	var out: Array = []
	for m in body_meshes(b):
		out.append(m)
	return out

func test_15_nothing_reshapes_a_stake_after_it_is_built() -> void:
	# There is no longer any code path that redraws a standing stake, which is what the
	# player was seeing when a blueprint of five cones became three. Putting a stake up
	# next door must leave its neighbour's body untouched.
	var gm = await _grid([])
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
