# res://tests/test_v04_build_queue.gd
# v0.4 follow-up: laying several rows of stakes at once has to be safe.
#
# The player's worry, in their words: "一口气造好几排，如果被前面造的卡住会怎么处理".
# Two things have to hold for that to be true.
#
#   1. Blueprints never block anybody. The Hero walks through pending work, so a
#      row he has just ordered can never be the thing standing between him and the
#      rest of the row.
#   2. Finished work sometimes does block him, and when it does he must skip the
#      blueprint he cannot reach and get on with the ones he can. Without that he
#      takes the oldest blueprint, fails to reach it, replans, and repeats forever
#      -- one unreachable stake would freeze the entire queue.
#
# The mechanism under both is GridManager.is_reachable, which floods out from the
# BLUEPRINT rather than from the Hero. A sealed pocket is small and finite, so the
# flood closes and the answer is definite; flooding from the Hero would spread over
# open ground until it gave up and could never prove anything.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var grid_script: GDScript = null
var hero_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
	grid_script = load("res://scripts/core/GridManager.gd")
	hero_script = load("res://scripts/entities/Hero.gd")

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

func _grid(blocked: Array = []) -> Node:
	var gm = grid_script.new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	return gm

## A finished stake, registered on the grid, which therefore blocks pathing.
func _stake_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

## An unfinished stake: work on the list, and walkable while it waits.
func _blueprint_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.start_construction()
	gm.occupy_cell(cell, w)
	return w

func _hero_at(gm: Node, cell: Vector2i) -> Node:
	var h = hero_script.new()
	_cleanup_nodes.append(h)
	tree.root.add_child(h)
	h.global_position = gm.cell_to_world(cell)
	return h

## Walls all the way round `cell`, so whatever is in it is sealed in.
func _fence_around(gm: Node, cell: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			_stake_at(gm, Vector2i(cell.x + dx, cell.y + dz))

## Hillside all the way round `cell`, which is what can actually shut the Hero out now.
##
## These tests used to seal him in with STAKES. He walks through his own fence since
## v0.5 -- being locked out of his own camp by it, with no gate in the game, was worse
## than the problem a fence solves -- so a fence seals nothing as far as he is concerned
## and there would be no unreachable work left to test with. The landscape still does.
func _hills_around(gm: Node, cell: Vector2i) -> void:
	var hills: Array = []
	for c in gm.blocked_cells.keys():
		hills.append(c)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			hills.append(Vector2i(cell.x + dx, cell.y + dz))
	gm.set_blocked_cells(hills)

# ==============================================================================
# 1. The flood
# ==============================================================================

func test_01_open_ground_is_reachable_and_a_sealed_pocket_is_not() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var here: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	_fence_around(gm, Vector2i(6, 0))

	assert_true(gm.is_reachable(here, gm.cell_to_world(Vector2i(3, 0))),
		"Across open ground he can get there")
	assert_false(gm.is_reachable(here, gm.cell_to_world(Vector2i(6, 0))),
		"But not into a cell walled off all the way round")
	assert_true(gm.is_reachable(here, gm.cell_to_world(Vector2i(6, 2))),
		"While the ground just outside that ring is still open")
	assert_true(gm.is_reachable(here, here), "And where he stands is trivially where he stands")

func test_02_neither_end_has_to_be_walkable_ground() -> void:
	# A finished building's own cell is not walkable, and a repair order sends him to
	# exactly that cell. Starting the flood there anyway is what makes the answer
	# about the route rather than about the endpoints.
	var gm = _grid([])
	await wait_frames(1)
	var mend_me = _stake_at(gm, Vector2i(3, 0))
	assert_false(gm.is_cell_walkable(Vector2i(3, 0)), "Finished work blocks its own cell")
	assert_true(gm.is_reachable(gm.cell_to_world(Vector2i(0, 0)), mend_me.global_position),
		"Yet he can still be sent to it")

func test_03_a_hill_seals_a_pocket_the_same_way_a_fence_does() -> void:
	# Reachability has to agree with pathing about what the ground is, or the Hero
	# would be sent to work he cannot get to, or kept from work he can.
	var ring: Array = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx != 0 or dz != 0:
				ring.append(Vector2i(5 + dx, dz))
	var gm = _grid(ring)
	await wait_frames(1)

	assert_false(gm.is_reachable(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(5, 0))),
		"Hillside closes a pocket as firmly as stakes do")
	assert_true(gm.is_reachable(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(5, 3))),
		"Round the outside of the ridge is still open")

func test_04_an_unfinished_blueprint_does_not_block_the_route() -> void:
	# The rule the whole queue rests on. If pending work blocked movement, ordering a
	# row would wall the Hero out of his own row -- which is the bug the player was
	# worried about when they asked what happens if you lay several rows at once.
	var gm = _grid([])
	await wait_frames(1)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx != 0 or dz != 0:
				_blueprint_at(gm, Vector2i(3 + dx, dz))

	assert_true(gm.is_cell_walkable(Vector2i(3, 1)), "Pending work is walkable")
	assert_true(gm.is_reachable(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(3, 0))),
		"So a ring of blueprints is not a wall")

func test_05_running_out_of_budget_assumes_he_can_get_there() -> void:
	# The flood only ever proves a pocket. Anything too big to sweep is not a pocket,
	# and guessing "unreachable" there would quietly stop the Hero working on an open
	# map -- far worse than sending him on a walk that turns out to be blocked.
	var gm = _grid([])
	await wait_frames(1)
	assert_true(gm.is_reachable(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(40, 40)), 8),
		"Out of budget means no answer, and no answer must not become a refusal")

	_fence_around(gm, Vector2i(6, 0))
	assert_false(gm.is_reachable(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(6, 0)), 8),
		"A real pocket is small enough to prove even on a tiny budget")

# ==============================================================================
# 2. What the Hero does with the answer
# ==============================================================================

func test_06_he_skips_the_blueprint_he_cannot_reach_and_builds_the_rest() -> void:
	# The reported worry, made concrete: an older blueprint he cannot get to must not
	# hold up the newer ones out in the open. Walled in by HILLSIDE, because his own
	# fence no longer stops him -- see _hills_around.
	var gm = _grid([])
	await wait_frames(1)
	var sealed_in = _blueprint_at(gm, Vector2i(8, 0))
	_hills_around(gm, Vector2i(8, 0))
	var out_in_the_open = _blueprint_at(gm, Vector2i(2, 0))

	assert_lt(int(sealed_in.build_order), int(out_in_the_open.build_order),
		"The unreachable one was ordered first, so oldest-first would pick it")

	var hero = _hero_at(gm, Vector2i(0, 0))
	await wait_frames(1)
	var chosen = hero._find_nearest_unfinished_building()
	assert_eq(chosen, out_in_the_open, "He takes the work he can actually get to")

func test_07_with_nothing_reachable_he_still_takes_the_oldest() -> void:
	# Fenced in with work outside, walking into the fence is the honest behaviour:
	# the player can see it and take a stake down. Going idle would hide the problem
	# and leave him asleep after the fence was opened again.
	var gm = _grid([])
	await wait_frames(1)
	var outside = _blueprint_at(gm, Vector2i(8, 0))
	var hero = _hero_at(gm, Vector2i(0, 0))
	_hills_around(gm, Vector2i(0, 0))
	await wait_frames(1)

	assert_eq(hero._find_nearest_unfinished_building(), outside,
		"He keeps the only job there is rather than forgetting it")

func test_08_oldest_first_still_holds_among_the_ones_he_can_reach() -> void:
	# Reachability filters the list; it does not reorder it. A row still goes up in
	# the order the player clicked, which is the only order they were thinking in.
	var gm = _grid([])
	await wait_frames(1)
	var first = _blueprint_at(gm, Vector2i(5, 0))
	var second = _blueprint_at(gm, Vector2i(1, 0))
	var hero = _hero_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	assert_lt(int(first.build_order), int(second.build_order), "First click, first order")
	assert_eq(hero._find_nearest_unfinished_building(), first,
		"And first order wins even though the other one is nearer")

func test_09_a_blueprint_walled_off_mid_approach_is_handed_back() -> void:
	# He is already walking to it when the gap closes -- a neighbouring stake
	# finishing is enough. Before this he ground against the new wall forever.
	var gm = _grid([])
	await wait_frames(1)
	var sealed_in = _blueprint_at(gm, Vector2i(8, 0))
	var reachable = _blueprint_at(gm, Vector2i(2, 0))
	var hero = _hero_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	hero.order_build(sealed_in, true)
	assert_eq(hero.target_building, sealed_in, "That is the job he set off for")

	_hills_around(gm, Vector2i(8, 0))
	assert_true(hero._abandon_unreachable_building(), "Being stuck makes him re-ask the question")
	assert_eq(hero.target_building, reachable, "And he moves on to work he can do")

func test_10_he_does_not_abandon_work_he_can_still_reach() -> void:
	# The escape hatch must not fire on an ordinary obstruction. Being briefly wedged
	# on a corner is not the same as being walled out.
	var gm = _grid([])
	await wait_frames(1)
	var reachable = _blueprint_at(gm, Vector2i(4, 0))
	_stake_at(gm, Vector2i(2, 0))
	var hero = _hero_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	hero.order_build(reachable, true)
	assert_false(hero._abandon_unreachable_building(),
		"A stake in the way is something he walks around, not a reason to give up")
	assert_eq(hero.target_building, reachable, "He keeps the job")

func test_11_a_finished_building_is_never_abandoned_as_unreachable() -> void:
	# Repair work goes through the same target. A building he cannot path to is
	# still the thing he was told to mend, and the escape hatch is only about the
	# build queue.
	var gm = _grid([])
	await wait_frames(1)
	var mend_me = _stake_at(gm, Vector2i(8, 0))
	mend_me.take_damage(mend_me.max_hp * 0.5)
	_fence_around(gm, Vector2i(8, 0))
	var hero = _hero_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	hero.order_build(mend_me, true)
	assert_false(hero._abandon_unreachable_building(), "Finished work is not queue work")
	assert_eq(hero.target_building, mend_me, "So the repair order stands")

# ==============================================================================
# 3. A blueprint looks like a blueprint
# ==============================================================================

func test_12_a_pending_stake_is_drawn_translucent() -> void:
	# Every visible mesh lives inside the "Body" holder make_body() returns, and the
	# fade only looked at direct children -- so nothing has actually faded since
	# make_body was introduced, and pending work was indistinguishable from finished
	# work. That matters most for a row: the player needs to see what is still owed.
	var gm = _grid([])
	await wait_frames(1)
	var pending = _blueprint_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	var cones := _body_meshes(pending)
	assert_gt(cones.size(), 0, "It is drawn")
	for cone in cones:
		var mat: StandardMaterial3D = cone.material_override as StandardMaterial3D
		assert_not_null(mat, "Each cone carries its own material")
		assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Drawn see-through while pending")
		assert_lt(mat.albedo_color.a, 1.0, "And not at full opacity")

	pending.complete_construction()
	await wait_frames(1)
	for cone in _body_meshes(pending):
		var mat: StandardMaterial3D = cone.material_override as StandardMaterial3D
		assert_almost_eq(mat.albedo_color.a, 1.0, 0.001, "Solid once it is built")

func test_13_the_feedback_layer_is_not_part_of_the_building() -> void:
	# The fade and the hit flash both work off Building._body_meshes(). The status
	# bar, the selection ring and the coverage ring are meshes hanging off a building
	# without being part of it -- fading the progress bar along with the blueprint, or
	# flashing the selection ring when the stake is bitten, would put the feedback
	# layer inside the thing it is reporting on.
	var gm = _grid([])
	await wait_frames(1)
	var pending = _blueprint_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	var body: Array = pending._body_meshes()
	assert_gt(body.size(), 0, "The stake has a body")
	for mesh in body:
		assert_eq(mesh.get_parent().name, StringName("Body"),
			"Only the body counts as the building")

	assert_not_null(pending.status_bar, "It has a status bar")
	for node in pending.status_bar.find_children("*", "MeshInstance3D", true, false):
		assert_false(body.has(node), "The status bar is not part of the body")
	assert_not_null(pending.selection_ring, "And a selection ring")
	for node in pending.selection_ring.find_children("*", "MeshInstance3D", true, false):
		assert_false(body.has(node), "Nor is the selection ring")

func _body_meshes(b: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var body := b.find_child("Body", false, false)
	if body == null:
		return out
	for child in body.get_children():
		if child is MeshInstance3D:
			out.append(child)
	return out

# ==============================================================================
# 4. Getting there when the straight line is blocked
# ==============================================================================
#
# "Click somewhere and if he cannot walk straight there, he does not move." Three
# separate things caused that, and none of them was the pathfinder itself.

func test_14_he_walks_round_what_is_in_the_way() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var from: Vector3 = gm.cell_to_world(Vector2i(0, 4))
	var to: Vector3 = gm.cell_to_world(Vector2i(0, -4))
	for x in range(-3, 3):
		_stake_at(gm, Vector2i(x, 0))
	await wait_frames(1)

	var path: Array = gm.find_path(from, to)
	assert_gt(path.size(), 1, "A detour is more than one step")
	# Every step has to be somewhere he can actually stand.
	for point in path:
		assert_true(gm.is_cell_walkable(gm.world_to_cell(point)),
			"Step at %s is on open ground" % str(gm.world_to_cell(point)))

func test_15_a_goal_inside_something_solid_becomes_the_nearest_spot_outside_it() -> void:
	# Clicking a hill, a tree or a building used to search the eight neighbours and give
	# up if all of them were solid too -- which is exactly the case in the middle of a
	# hill -- and hand back a straight line into the rock.
	var ring: Array = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			ring.append(Vector2i(5 + dx, dz))
	var gm = _grid(ring)
	await wait_frames(1)

	var from: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	var into_the_hill: Vector3 = gm.cell_to_world(Vector2i(5, 0))
	var path: Array = gm.find_path(from, into_the_hill)
	var last: Vector2i = gm.world_to_cell(path[path.size() - 1])
	assert_true(gm.is_cell_walkable(last), "He is sent somewhere he can stand")
	assert_lte(absi(last.x - 5) + absi(last.y), 3, "And it is close to where the player clicked")

func test_16_an_unreachable_goal_still_gets_him_as_close_as_possible() -> void:
	# The important half. A* failing used to return a straight line, which walks him
	# into the nearest wall and leaves him grinding -- the stuck timer replans, gets the
	# same straight line, forever. A partial path gets him as close as the map allows
	# and then stops.
	var gm = _grid([])
	await wait_frames(1)
	var goal := Vector2i(8, 0)
	_fence_around(gm, goal)
	await wait_frames(1)

	var from: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	var path: Array = gm.find_path(from, gm.cell_to_world(goal))
	assert_gt(path.size(), 0, "He is given somewhere to go")
	var last: Vector2i = gm.world_to_cell(path[path.size() - 1])
	assert_ne(last, goal, "Not into the sealed pocket, which he cannot enter")
	assert_true(gm.is_cell_walkable(last), "But somewhere he can stand")
	assert_lt(gm.cell_to_world(last).distance_to(gm.cell_to_world(goal)),
		gm.cell_to_world(Vector2i(0, 0)).distance_to(gm.cell_to_world(goal)),
		"And closer to it than he started")
