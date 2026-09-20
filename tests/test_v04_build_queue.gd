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
# The mechanism under both is a route from the navigation mesh -- NavMaps, baked from
# the level's own colliders. It was a flood of the grid until v0.5, which had to be
# started at the BLUEPRINT end and given a budget, because the grid is unbounded and a
# flood from the Hero would spread over open ground for ever without proving anything.
# A mesh is finite: the route exists or it does not, and there is nothing to guess.
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

var _world: Node3D = null

## The fixture, which since v0.5 has a NAVIGATION MESH over it.
##
## "Can he get there" is answered by a bake, and a bake is made of colliders, so a grid
## with nothing but cell data in it cannot answer anything -- every question comes back
## "anywhere". The ground plane and the hill boxes are the same shapes the level lays
## down, on the same layer, so what these tests ask is what the game asks.
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

## Whether the Hero could walk from `from_pos` to `to_pos` -- asked of the mesh he
## actually walks on. This was GridManager.is_reachable, a flood of the grid, which was
## deleted in v0.5 for disagreeing with the mesh right where the answer matters.
func _can_get_there(from_pos: Vector3, to_pos: Vector3) -> bool:
	return maps_of().is_reachable(from_pos, to_pos, true)

## A finished stake, registered on the grid, which therefore blocks pathing.
func _stake_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_world.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

## An unfinished stake: work on the list, and walkable while it waits.
func _blueprint_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_world.add_child(w)
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

## A hillside cell laid down AFTER the fixture was built: the box, the grid rule and a
## fresh bake, which is the three things Main.spawn_terrain does together.
func _hill_at(gm: Node, cell: Vector2i) -> void:
	var cells: Array = []
	for c in gm.blocked_cells.keys():
		cells.append(c)
	if not (cell in cells):
		cells.append(cell)
	gm.set_blocked_cells(cells)
	block_out_a_hill(_world, gm, cell)

## Walls all the way round `cell`, so whatever is in it is sealed in.
func _fence_around(gm: Node, cell: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			_stake_at(gm, Vector2i(cell.x + dx, cell.y + dz))
	await rebake_fixture()

## Hillside all the way round `cell`, which is what can actually shut the Hero out now.
##
## These tests used to seal him in with STAKES. He walks through his own fence since
## v0.5 -- being locked out of his own camp by it, with no gate in the game, was worse
## than the problem a fence solves -- so a fence seals nothing as far as he is concerned
## and there would be no unreachable work left to test with. The landscape still does.
func _hills_around(gm: Node, cell: Vector2i) -> void:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			_hill_at(gm, Vector2i(cell.x + dx, cell.y + dz))
	await rebake_fixture()

# ==============================================================================
# 1. The flood
# ==============================================================================

func test_01_open_ground_is_reachable_and_a_sealed_pocket_is_not() -> void:
	# SEALED WITH HILLSIDE, because since v0.5 a fence does not seal HIM -- see
	# Config.LAYER_WALL, and test_01b below, which checks the fence still seals a raid.
	var gm = await _grid([])
	var here: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	await _hills_around(gm, Vector2i(6, 0))

	assert_true(_can_get_there(here, gm.cell_to_world(Vector2i(3, 0))),
		"Across open ground he can get there")
	assert_false(_can_get_there(here, gm.cell_to_world(Vector2i(6, 0))),
		"But not into a cell walled off all the way round")
	assert_true(_can_get_there(here, gm.cell_to_world(Vector2i(6, 3))),
		"While the ground just outside that ring is still open")
	assert_true(_can_get_there(here, here), "And where he stands is trivially where he stands")

func test_01b_a_ring_of_stakes_is_not_what_shuts_him_out() -> void:
	# Why this suite seals its pockets with HILLSIDE. Two reasons, and both are real:
	#
	#   * he walks through his own fence (Config.LAYER_WALL), so a fence could not shut
	#     him out however it was built; and
	#   * one stake per tile is not a fence anyway. A stake is 0.62m and tiles are 2m
	#     apart, so a "ring" laid that way is eight cones with 1.38m of open ground
	#     between them -- which nothing is stopped by, and which is the v0.4 finding
	#     that stakes only seal when they are laid on their own finer grid.
	var gm = await _grid([])
	var here: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	await _fence_around(gm, Vector2i(6, 0))
	var walled: Vector3 = gm.cell_to_world(Vector2i(6, 0))

	assert_true(_can_get_there(here, walled), "He walks straight in")
	assert_true(maps_of().is_reachable(here, walled, false),
		"And so does a raid, through gaps wider than it is")

func test_02_a_finished_building_is_somewhere_he_can_still_be_sent() -> void:
	# A repair order sends him to a building's own cell, which nobody can stand in. The
	# grid flood answered this by starting inside the blueprint anyway; the mesh answers
	# it by stopping him beside it, which is where he does the work from. Either way the
	# question is about the ROUTE and not about the endpoints -- see Hero._can_work_on.
	var gm = await _grid([])
	var mend_me = _stake_at(gm, Vector2i(3, 0))
	await rebake_fixture()
	var hero = _hero_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	assert_false(gm.is_cell_walkable(Vector2i(3, 0)), "Finished work blocks its own cell")
	assert_true(hero._can_work_on(mend_me), "Yet he can still be sent to it")

func test_03_a_hill_seals_a_pocket_the_same_way_a_fence_does() -> void:
	# Hillside and stakes are one question to the mesh: both are colliders in the bake,
	# and neither needs a rule of its own.
	var ring: Array = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx != 0 or dz != 0:
				ring.append(Vector2i(5 + dx, dz))
	var gm = await _grid(ring)

	assert_false(_can_get_there(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(5, 0))),
		"Hillside closes a pocket as firmly as stakes do")
	assert_true(_can_get_there(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(5, 3))),
		"Round the outside of the ridge is still open")

func test_04_an_unfinished_blueprint_does_not_block_the_route() -> void:
	# The rule the whole queue rests on. If pending work blocked movement, ordering a
	# row would wall the Hero out of his own row -- which is the bug the player was
	# worried about when they asked what happens if you lay several rows at once.
	#
	# It is one bit of a collision mask now: Config.LAYER_BLUEPRINT is in neither bake.
	var gm = await _grid([])
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx != 0 or dz != 0:
				_blueprint_at(gm, Vector2i(3 + dx, dz))
	await rebake_fixture()

	assert_true(gm.is_cell_walkable(Vector2i(3, 1)), "Pending work is walkable")
	assert_true(_can_get_there(gm.cell_to_world(Vector2i(0, 0)), gm.cell_to_world(Vector2i(3, 0))),
		"So a ring of blueprints is not a wall")

# test_05 is gone with its subject. It covered the flood's BUDGET -- "anything too big
# to sweep is not a pocket, so assume he can get there" -- which existed because a flood
# of an unbounded grid has to guess when it runs out. A bake has no budget to run out
# of: the mesh is finite, the route either exists or it does not, and there is nothing
# left to guess. That guess was also the bug in the end, in its other half: the flood
# claimed a way in from close to a fence, where there was none.

# ==============================================================================
# 2. What the Hero does with the answer
# ==============================================================================

func test_06_he_skips_the_blueprint_he_cannot_reach_and_builds_the_rest() -> void:
	# The reported worry, made concrete: an older blueprint he cannot get to must not
	# hold up the newer ones out in the open. Walled in by HILLSIDE, because his own
	# fence no longer stops him -- see _hills_around.
	var gm = await _grid([])
	await wait_frames(1)
	var sealed_in = _blueprint_at(gm, Vector2i(8, 0))
	await _hills_around(gm, Vector2i(8, 0))
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
	var gm = await _grid([])
	await wait_frames(1)
	var outside = _blueprint_at(gm, Vector2i(8, 0))
	var hero = _hero_at(gm, Vector2i(0, 0))
	await _hills_around(gm, Vector2i(0, 0))
	await wait_frames(1)

	assert_eq(hero._find_nearest_unfinished_building(), outside,
		"He keeps the only job there is rather than forgetting it")

func test_08_oldest_first_still_holds_among_the_ones_he_can_reach() -> void:
	# Reachability filters the list; it does not reorder it. A row still goes up in
	# the order the player clicked, which is the only order they were thinking in.
	var gm = await _grid([])
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
	var gm = await _grid([])
	await wait_frames(1)
	var sealed_in = _blueprint_at(gm, Vector2i(8, 0))
	var reachable = _blueprint_at(gm, Vector2i(2, 0))
	var hero = _hero_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	hero.order_build(sealed_in, true)
	assert_eq(hero.target_building, sealed_in, "That is the job he set off for")

	await _hills_around(gm, Vector2i(8, 0))
	assert_true(hero._abandon_unreachable_building(), "Being stuck makes him re-ask the question")
	assert_eq(hero.target_building, reachable, "And he moves on to work he can do")

func test_10_he_does_not_abandon_work_he_can_still_reach() -> void:
	# The escape hatch must not fire on an ordinary obstruction. Being briefly wedged
	# on a corner is not the same as being walled out.
	var gm = await _grid([])
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
	var gm = await _grid([])
	await wait_frames(1)
	var mend_me = _stake_at(gm, Vector2i(8, 0))
	mend_me.take_damage(mend_me.max_hp * 0.5)
	await _fence_around(gm, Vector2i(8, 0))
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
	var gm = await _grid([])
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
	var gm = await _grid([])
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
	var gm = await _grid([])
	await wait_frames(1)
	var from: Vector3 = gm.cell_to_world(Vector2i(0, 4))
	var to: Vector3 = gm.cell_to_world(Vector2i(0, -4))
	for x in range(-3, 3):
		_stake_at(gm, Vector2i(x, 0))
	await wait_frames(1)

	await rebake_fixture()
	var path: PackedVector3Array = maps_of().path(from, to, true)
	assert_gt(path.size(), 1, "A detour is more than one step")
	# Every step has to be somewhere he can actually stand, which for a mesh route is
	# true by construction -- so what this asserts is that the route is ON the mesh at
	# all, rather than a straight line handed back by a search that gave up.
	for point in path:
		assert_lt(maps_of().closest_point(point, true).distance_to(point), 0.3,
			"Step at %s is on the mesh" % str(point.round()))

func test_15_a_goal_inside_something_solid_becomes_the_nearest_spot_outside_it() -> void:
	# Clicking a hill, a tree or a building used to search the eight neighbours and give
	# up if all of them were solid too -- which is exactly the case in the middle of a
	# hill -- and hand back a straight line into the rock.
	var ring: Array = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			ring.append(Vector2i(5 + dx, dz))
	var gm = await _grid(ring)
	await wait_frames(1)

	var from: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	var into_the_hill: Vector3 = gm.cell_to_world(Vector2i(5, 0))
	var path: PackedVector3Array = maps_of().path(from, into_the_hill, true)
	assert_gt(path.size(), 0, "He is given somewhere to go")
	var last: Vector2i = gm.world_to_cell(path[path.size() - 1])
	assert_true(gm.is_cell_walkable(last), "He is sent somewhere he can stand")
	assert_lte(absi(last.x - 5) + absi(last.y), 3, "And it is close to where the player clicked")

func test_16_an_unreachable_goal_still_gets_him_as_close_as_possible() -> void:
	# The important half. A* failing used to return a straight line, which walks him
	# into the nearest wall and leaves him grinding -- the stuck timer replans, gets the
	# same straight line, forever. A partial path gets him as close as the map allows
	# and then stops.
	var gm = await _grid([])
	await wait_frames(1)
	var goal := Vector2i(8, 0)
	await _hills_around(gm, goal)
	await wait_frames(1)

	var from: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	var path: PackedVector3Array = maps_of().path(from, gm.cell_to_world(goal), true)
	assert_gt(path.size(), 0, "He is given somewhere to go")
	var last: Vector2i = gm.world_to_cell(path[path.size() - 1])
	assert_ne(last, goal, "Not into the sealed pocket, which he cannot enter")
	assert_true(gm.is_cell_walkable(last), "But somewhere he can stand")
	assert_lt(gm.cell_to_world(last).distance_to(gm.cell_to_world(goal)),
		gm.cell_to_world(Vector2i(0, 0)).distance_to(gm.cell_to_world(goal)),
		"And closer to it than he started")
