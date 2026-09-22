# res://tests/test_v05_a_fence_is_dragged_out.gd
# A fence is laid by dragging, the way every building game lays one.
#
# Asked for as "墙都是点击一次可以拉出来造，这样不用一个个点". Clicking a hundred stakes one
# at a time is not a decision a hundred times over; it is the SAME decision a hundred
# times, and the click is only in the way of it.
#
# There is no engine feature for this -- Godot has input and it has nodes, and what sits
# between them for a building game is the game's own. So the test of "use what is already
# there" is not whether something was imported, it is how little is new underneath:
#
#   * the run is GridManager's OWN line traversal, asked at the fine grid's scale
#     instead of the tile's (one traversal, two scales, nothing to keep in step);
#   * every stake goes down through the same BuildSystem.place_building a single click
#     uses, so paying, registering, telling the Hero and rebaking the navigation mesh all
#     happen exactly as they always did;
#   * the ghosts are the same Building.make_body the single ghost already used.
#
# What is genuinely new is three pieces of state and the rule about when a press becomes
# a drag.
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

func _level(wood: int = 4000) -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(6)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = wood
		game_state_node.resources["stone"] = wood
	# Where the Hero happens to be standing is not what this suite is about.
	if main.hero:
		main.hero.global_position = main.grid_manager.cell_to_world(
			config_node.MAP["default_core_cell"]) + Vector3(0.0, 0.0, 20.0)
	await wait_frames(2)
	return main

func _divisions() -> int:
	return int(config_node.get_cell_divisions("wall"))

func _stakes_standing(main: Node) -> int:
	var n: int = 0
	for b in main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and ("building_type" in b) and String(b.building_type) == "wall":
			n += 1
	return n

## The whole gesture: press at `from_world`, drag to `to_world`, let go.
func _drag(main: Node, from_world: Vector3, to_world: Vector3) -> int:
	var gm = main.grid_manager
	main.current_build_type = "wall"
	main._drag_from = gm.world_to_fine_cell(from_world, _divisions())
	main._dragging = true
	var cells: Array[Vector2i] = []
	for fine in gm.fine_cells_on_line(from_world, to_world, _divisions()):
		var at: Vector3 = gm.fine_cell_to_world(fine, _divisions())
		if main.build_system.can_place_building("wall", gm.world_to_cell(at), false, at):
			cells.append(fine)
	main._end_drag()
	return main._commit_run(cells)

# ==============================================================================
# 1. One gesture, a whole fence
# ==============================================================================

func test_01_one_drag_lays_a_whole_run() -> void:
	var main = await _level()
	var core: Vector3 = main.grid_manager.cell_to_world(config_node.MAP["default_core_cell"])
	var before: int = _stakes_standing(main)

	var laid: int = _drag(main, core + Vector3(-5.0, 0.0, -8.0), core + Vector3(5.0, 0.0, -8.0))
	await wait_frames(4)

	assert_gt(laid, 5, "One gesture laid a run rather than a stake")
	assert_eq(_stakes_standing(main) - before, laid, "And every one of them is standing there")

func test_02_the_run_has_no_gaps_in_it_even_drawn_diagonally() -> void:
	# A fence with diagonal gaps does not seal, and "I dragged a fence across and things
	# still walked through" is a bug the player cannot see the cause of. The traversal
	# steps one cell at a time and never cuts a corner.
	var main = await _level()
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	var line: Array[Vector2i] = gm.fine_cells_on_line(
		core + Vector3(-5.0, 0.0, -6.0), core + Vector3(5.0, 0.0, -10.0), _divisions())

	assert_gt(line.size(), 10, "The diagonal crosses plenty of cells")
	for i in range(1, line.size()):
		var step: Vector2i = line[i] - line[i - 1]
		assert_eq(absi(step.x) + absi(step.y), 1,
			"Every step is one cell -- no corner is cut at %s" % str(line[i]))

func test_03_a_dragged_fence_actually_seals() -> void:
	# What the run is FOR. The proof is not that the stakes exist, it is that nothing
	# gets through them.
	var main = await _level()
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	# Four drags, corner to corner, round the cabin.
	var half: float = 5.0
	var corners: Array[Vector3] = [
		core + Vector3(-half, 0.0, -half), core + Vector3(half, 0.0, -half),
		core + Vector3(half, 0.0, half), core + Vector3(-half, 0.0, half)]
	var laid: int = 0
	for i in range(4):
		laid += _drag(main, corners[i], corners[(i + 1) % 4])
	assert_gt(laid, 40, "A box of fence was ORDERED in four gestures")
	await wait_frames(8)

	# A drag orders work; it does not do it. Until the Hero has been round them the
	# stakes are blueprints, and a blueprint is in neither navigation bake -- ordering a
	# fence is not having one. So the raid still walks straight through at this point,
	# and that is the rule working rather than the fence failing.
	var outside: Vector3 = core + Vector3(0.0, 0.0, -11.0)
	assert_true(main.nav_maps.is_reachable(outside, core),
		"Ordered and not built, it stops nobody")

	for b in main.grid_manager.get_all_buildings():
		if is_instance_valid(b) and ("building_type" in b) and String(b.building_type) == "wall":
			b.complete_construction()
	await wait_frames(8)

	assert_false(main.nav_maps.is_reachable(outside, core), "Built, a raid has no way in")
	assert_true(main.nav_maps.is_reachable(outside, core, true), "While the man who drew it does")

# ==============================================================================
# 2. Without taking the old way away
# ==============================================================================

func test_04_a_press_that_never_moves_still_lays_exactly_one() -> void:
	# The regression that would matter most: somebody who clicks stakes one at a time,
	# as they have until now, must get one stake per click and not two and not none.
	var main = await _level()
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	main.current_build_type = "wall"
	var spot: Vector3 = core + Vector3(0.0, 0.0, -9.0)
	var before: int = _stakes_standing(main)

	# Pressed and released in the same place: no drag ever started.
	main._drag_from = gm.world_to_fine_cell(spot, _divisions())
	main._dragging = false
	var cells: Array[Vector2i] = [main._drag_from]
	main._end_drag()
	main._commit_run(cells)
	await wait_frames(4)

	assert_eq(_stakes_standing(main) - before, 1, "One click, one stake")

func test_05_only_walls_are_dragged_out() -> void:
	# A turret is a decision about ONE spot, and dragging a row of them out is not
	# something anybody means to do. Derived from the kind rather than declared, so a new
	# sort of barrier gets the drag for free and nothing has to be kept in step.
	var main = await _level()
	assert_true(main._is_dragged_out("wall"), "A fence is dragged")
	assert_false(main._is_dragged_out("tower"), "A turret is placed")
	assert_false(main._is_dragged_out("core"), "And so is the cabin")
	assert_eq(String(config_node.get_building_kind("wall")), "wall",
		"Which is the same category the raid's rules are written against")

# ==============================================================================
# 3. What it does when it cannot
# ==============================================================================

func test_06_the_run_steps_over_what_it_cannot_build_on() -> void:
	# Dragging a fence past a rock should give a fence either side of the rock, which is
	# what the player meant. It also means the ghosts are exactly what gets built.
	var main = await _level()
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	# Straight through the cabin, which nothing can be built on.
	var laid: int = _drag(main, core + Vector3(-6.0, 0.0, 0.0), core + Vector3(6.0, 0.0, 0.0))
	await wait_frames(4)

	assert_gt(laid, 8, "It laid what it could")
	var left: int = 0
	var right: int = 0
	for b in gm.get_all_buildings():
		if is_instance_valid(b) and ("building_type" in b) and String(b.building_type) == "wall":
			if (b as Node3D).global_position.x < core.x:
				left += 1
			else:
				right += 1
	assert_gt(left, 0, "Stakes on one side of the cabin")
	assert_gt(right, 0, "And on the other -- the run stepped over it rather than stopping")

func test_07_the_run_stops_when_the_wood_does() -> void:
	# It is not a way to build for free, and it must not half-charge either.
	var main = await _level(0)
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	var each: int = cost_of("wall")
	game_state_node.resources["wood"] = each * 3

	var laid: int = _drag(main, core + Vector3(-6.0, 0.0, -8.0), core + Vector3(6.0, 0.0, -8.0))
	await wait_frames(4)

	assert_eq(laid, 3, "Three stakes' worth of wood laid three stakes")
	assert_lt(int(game_state_node.resources.get("wood", 0)), each, "And paid for all three")

func test_08_the_numbers_are_in_config() -> void:
	assert_true(config_node.BUILD_DRAG.has("max_run"), "How long a run may be")
	assert_true(config_node.BUILD_DRAG.has("drag_threshold_px"),
		"And how far the cursor must move before a click becomes a drag")
	assert_gt(float(config_node.BUILD_DRAG["drag_threshold_px"]), 0.0,
		"Zero would make the shake in an ordinary click lay two stakes")

func test_09_cancelling_mid_drag_lays_nothing() -> void:
	# Escape during a drag has to leave the map as it was, not half a fence.
	var main = await _level()
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	main.current_build_type = "wall"
	main._drag_from = gm.world_to_fine_cell(core + Vector3(-5.0, 0.0, -8.0), _divisions())
	main._dragging = true
	var before: int = _stakes_standing(main)

	main.cancel_building_selection()
	await wait_frames(2)

	assert_eq(main._drag_from, main.NOT_DRAGGING, "The drag is forgotten")
	assert_false(main._dragging, "And not still running")
	assert_eq(_stakes_standing(main), before, "Nothing was laid")
