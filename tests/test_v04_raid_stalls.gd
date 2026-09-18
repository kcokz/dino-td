# res://tests/test_v04_raid_stalls.gd
# A raid is always doing one of two things: going somewhere, or eating something.
#
# Reported against a curved fence with both ends open: "恐龙来进攻的时候并不会绕过栅栏去
# 进攻 cabin，并且会停在离栅栏比较远的地方，就不进攻了". Three separate causes, none of
# them the rule itself, which is why the rule alone did not fix it:
#
#   1. THE RULE GATED THE BITE AND NOT THE TARGET. A dinosaur would claim an attack slot
#      on a fence it had no intention of biting, walk to the slot, be released for having
#      a way round, and claim it again -- hovering a slot-radius short of the stakes for
#      as long as anyone watched. That is the "stops some way off and does nothing".
#
#   2. "IS THE WAY SEALED" WAS ASKED ABOUT THE TARGET. A target is always reachable --
#      you are standing on it by the time you bite it -- so a wall judged that way is
#      never in the way. The question has to be about where the raid is GOING.
#
#   3. THE STRAIGHT-LINE CHECK SAMPLED, AND MISSED CELLS. It walked the line every metre
#      and could step clean over the corner of a hill, so a dinosaur was told the way was
#      clear, walked into the hillside, was pushed back out, and did it again -- for ever.
#
# The last of those had nothing to do with fences at all: it froze raids on open ground,
# at the two hills either side of the approach, and had been doing so all along.
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
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 500

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
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	return gm

func _build_system(gm: Node) -> Node:
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, gm)
	return bs

func _wall_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

func _dino_at(gm: Node, at: Vector3, goal: Vector3) -> Node:
	var d = load("res://scripts/entities/Dino.gd").new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup("raptor")
	d.global_position = at
	d.set_waypoints([goal])
	return d

func _divisions() -> int:
	return int(config_node.get_cell_divisions("wall"))

func _fine_step() -> float:
	return float(config_node.TILE_SIZE) / float(_divisions())

## A stake at a fine cell, placed the way a click places one.
func _stake(gm: Node, bs: Node, fine: Vector2i) -> Node:
	var at: Vector3 = gm.fine_cell_to_world(fine, _divisions())
	var s = bs.place_building("wall", gm.world_to_cell(at), gm, false, at)
	if s != null:
		_cleanup_nodes.append(s)
	return s

# ==============================================================================
# 1. It never commits to something it will not bite
# ==============================================================================

func test_01_no_slot_is_claimed_on_a_fence_with_a_way_round() -> void:
	# The reported stall, as a rule. Claiming a slot means walking to it, and walking to
	# a fence you are then released from is how a raid spends its afternoon going nowhere.
	var gm = _grid([])
	await wait_frames(1)
	for x in range(-3, 4):
		_wall_at(gm, Vector2i(x, 0))
	# Started right up against the fence, where a stake is well inside
	# building_interest_range -- otherwise this proves nothing, because nothing is ever
	# close enough to be considered.
	var d = _dino_at(gm, gm.cell_to_world(Vector2i(0, 1)), gm.cell_to_world(Vector2i(0, -4)))
	d.global_position = gm.cell_to_world(Vector2i(0, 0)) + Vector3(0.0, 0.0, 1.5)
	await wait_frames(1)

	assert_lt(d.global_position.distance_to(gm.cell_to_world(Vector2i(0, 0))),
		float(d.building_interest_range()), "Close enough for the fence to be considered")
	assert_false(d._way_is_sealed(), "The ground past the end of the fence is open")
	assert_null(d._find_threat_priority_target(),
		"So nothing in the fence is worth stopping for")

	for step in range(20):
		d.advance_towards_waypoint(0.05)
		assert_eq(d.assigned_slot, Vector3.ZERO, "No slot is claimed on it, at any point")
		assert_false(d._is_wall(d.current_target), "And the fence never becomes its target")

func test_02_it_keeps_closing_on_the_core_instead() -> void:
	# The other half of the same report: it was supposed to go round and attack the
	# cabin. Measured as ground covered, because "it moved" is not the same as "it got on
	# with it".
	var gm = _grid([])
	await wait_frames(1)
	for x in range(-3, 4):
		_wall_at(gm, Vector2i(x, 0))
	var goal: Vector3 = gm.cell_to_world(Vector2i(0, -6))
	# Two metres off the fence: the distance at which it used to stop and mill about.
	var d = _dino_at(gm, gm.cell_to_world(Vector2i(0, 1)), goal)
	await wait_frames(1)

	var was: float = d.global_position.distance_to(goal)
	for step in range(360):
		d.advance_towards_waypoint(1.0 / 60.0)
	var now: float = d.global_position.distance_to(goal)
	assert_lt(now, was - 4.0, "Six seconds of walking gets it well round the fence")

func test_03_a_sealed_way_is_still_worth_biting() -> void:
	# And the rule has not been bought by making fences pointless.
	var gm = _grid([])
	await wait_frames(1)
	var goal := Vector2i(0, -4)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				_wall_at(gm, goal + Vector2i(dx, dz))
	var d = _dino_at(gm, gm.cell_to_world(Vector2i(0, 4)), gm.cell_to_world(goal))
	await wait_frames(1)

	assert_true(d._way_is_sealed(), "There is no way in")
	for step in range(400):
		d.advance_towards_waypoint(0.05)
		if int(d.current_state) == int(d.State.ATTACKING):
			break
	assert_eq(int(d.current_state), int(d.State.ATTACKING), "It walks up to the ring and bites it")
	assert_true(d._is_wall(d.current_target), "The stake in its way")

# ==============================================================================
# 2. The sealed question is about the journey
# ==============================================================================

func test_04_sealed_is_judged_against_where_it_is_going() -> void:
	# Not against whatever it last targeted. A target is always reachable -- it is where
	# you are standing by the time you bite it -- so judging a wall that way makes every
	# wall walkable-round, for ever, including the one sealing the core.
	var gm = _grid([])
	await wait_frames(1)
	var goal := Vector2i(0, -4)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				_wall_at(gm, goal + Vector2i(dx, dz))
	var d = _dino_at(gm, gm.cell_to_world(Vector2i(0, 4)), gm.cell_to_world(goal))
	await wait_frames(1)

	assert_true(d._way_is_sealed(), "Sealed, judged against the waypoint")
	# Now hand it the wall as a target, which is what happens a moment later anyway.
	d.current_target = gm.get_building_at(Vector2i(0, -3))
	d._route_checked_at = -999.0
	assert_true(d._way_is_sealed(), "And still sealed once it has picked something to bite")

# ==============================================================================
# 3. The straight line has to walk cells, not sample them
# ==============================================================================

func test_05_a_line_never_steps_over_a_cell() -> void:
	# The exact shape of the freeze, in one assertion. A shallow line clips the corner of
	# the next cell over a distance far shorter than any sample spacing.
	var gm = _grid([])
	await wait_frames(1)
	var from_pos := Vector3(-2.13, 0.0, -10.0)
	var to_pos := Vector3(1.0, 0.0, 1.0)
	var cells: Array = gm.cells_on_line(from_pos, to_pos)

	assert_true(cells.has(gm.world_to_cell(from_pos)), "It starts where the walker is")
	assert_true(cells.has(gm.world_to_cell(to_pos)), "And ends where it is going")
	assert_true(cells.has(Vector2i(-2, -5)),
		"And includes the cell the walker's very next step lands in")
	# Every consecutive pair must be side by side: a jump means a skipped cell.
	for i in range(1, cells.size()):
		var step: Vector2i = cells[i] - cells[i - 1]
		assert_eq(absi(step.x) + absi(step.y), 1,
			"Step %d moves one cell, never diagonally and never further" % i)

func test_06_the_line_agrees_with_the_pathfinder() -> void:
	# They disagreed: the line check called a tile solid for being OCCUPIED, while A*
	# routed straight through it. A walker caught between the two does not go round and
	# does not stop -- it walks into the thing, gets pushed out, and repeats.
	var gm = _grid([])
	var bs = _build_system(gm)
	await wait_frames(1)
	_stake(gm, bs, Vector2i(0, 0))
	await wait_frames(1)

	var tile: Vector2i = Vector2i(0, 0)
	assert_true(gm.is_cell_walkable(tile), "One stake leaves the tile crossable")
	var from_pos: Vector3 = gm.cell_to_world(Vector2i(0, -3))
	var to_pos: Vector3 = gm.cell_to_world(Vector2i(0, 3))
	assert_eq(gm.first_solid_on_line(from_pos, to_pos), gm.NO_CELL,
		"So the straight line through it is clear, exactly as A* believes")

func test_07_a_walker_slides_along_a_hill_instead_of_stopping_dead() -> void:
	# The last line of defence. Whatever any check gets wrong in future, pressing into
	# the scenery must not be able to park a dinosaur for the rest of the game.
	var gm = _grid([Vector2i(0, 0)])
	await wait_frames(1)
	var d = _dino_at(gm, gm.cell_to_world(Vector2i(0, -1)), gm.cell_to_world(Vector2i(0, 3)))
	await wait_frames(1)

	# Step straight into the hill, the way a bad steer would.
	var before: Vector3 = d.global_position
	d.global_position = gm.cell_to_world(Vector2i(0, 0)) + Vector3(0.9, 0.0, 0.0)
	d.velocity = Vector3(0.0, 0.0, 4.0)
	d._keep_off_the_hills(before)

	assert_false(gm.is_cell_blocked(gm.world_to_cell(d.global_position)),
		"It does not end up standing in the hill")
	assert_gt(d.velocity.length(), 0.0,
		"And it keeps its speed, because a wall face only blocks one direction")

func test_08_a_raid_on_open_ground_past_two_hills_does_not_freeze() -> void:
	# What the report looked like with no fence at all, which is how the third cause was
	# found: dinosaurs that reached the hills flanking the approach and stayed there.
	# The measured geometry, not an invented one: a dinosaur at this exact spot, with the
	# hills the level actually has, was frozen for thirteen seconds of an eighteen second
	# run. The line from here to the goal clips the corner of the hill it is standing
	# against over a few centimetres -- less than the old sampler's stride.
	var gm = _grid([Vector2i(-3, -5), Vector2i(-2, -5), Vector2i(2, -5), Vector2i(3, -5)])
	await wait_frames(1)
	var goal := Vector3(1.0, 0.0, 1.0)
	var d = _dino_at(gm, Vector3(-2.130616, 0.0, -10.00012), goal)
	await wait_frames(1)
	assert_eq(gm.world_to_cell(d.global_position), Vector2i(-2, -6), "Pressed against the hill")
	assert_true(gm.is_cell_blocked(Vector2i(-2, -5)), "Which is right in front of it")

	var was: float = d.global_position.distance_to(goal)
	for step in range(600):
		d.advance_towards_waypoint(1.0 / 60.0)
	var closed: float = was - d.global_position.distance_to(goal)
	assert_gt(closed, 6.0, "It gets round the hill instead of parking against it")
