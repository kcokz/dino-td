# res://tests/test_v05_reach_is_body_to_body.gd
# How close you have to get to bite something depends on both of you.
#
# Reported as "近战小恐龙的攻击范围要小，现在我放一个木栅栏，小恐龙可以隔着这个攻击 cabin".
# Measured before changing anything: a raptor 2.03m from the cabin's centre, with a stake
# standing between them, taking the cabin from ten hit points to nine.
#
# DINO_ATTACK_REACH was 2.2m, centre to centre, for every species against every target. A
# raptor is 0.8m across, so it struck 1.8m clear of its own nose. That is the same mistake
# as the attack slots and the spike range before it -- ONE NUMBER TUNED FOR ONE SIZE,
# applied to all of them -- and the third time it has been found in this system.
#
# Two halves, and the second is what makes it hold however the first is tuned:
#   * reach is the attacker's half-width plus its strike plus the TARGET's half-width;
#   * a bite does not pass through solid matter.
#
# And a third thing fell out of it, which was its own bug: SEEING something, STOPPING for
# it and BEING ABLE TO BITE it were three different distances -- a forward ray that scales
# with speed, a hardcoded 1.8m, and attack_reach. A dinosaur could halt at a distance it
# could not reach from and stand there in ATTACKING state doing no damage, which is
# precisely the symptom reported over and over. They are one question now.
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

func _grid() -> Node:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	return gm

func _spawn(path: String, at: Vector3) -> Node:
	var n = load(path).new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	if n is Node3D:
		(n as Node3D).global_position = at
	return n

func _dino(type_id: String, at: Vector3) -> Node:
	var d = _spawn(String(config_node.get_dino_script_path(type_id)), at)
	d.setup(type_id)
	d.global_position = at
	return d

func _building(type_id: String, gm: Node, cell: Vector2i) -> Node:
	var path := "res://scripts/entities/Wall.gd" if type_id == "wall" else "res://scripts/entities/Tower.gd"
	var b = _spawn(path, gm.cell_to_world(cell))
	b.setup(type_id, cell)
	b.global_position = gm.cell_to_world(cell)
	b.complete_construction()
	gm.occupy_cell(cell, b)
	return b

# ==============================================================================
# 1. Reach is measured between two bodies
# ==============================================================================

func test_01_a_small_dinosaur_strikes_a_short_way_past_itself() -> void:
	var raptor = _dino("raptor", Vector3.ZERO)
	await wait_frames(2)

	var strike: float = float(config_node.DINO_STRIKE)
	assert_almost_eq(raptor.attack_reach() - raptor._avoid_radius, strike, 0.001,
		"What it reaches past its own body is the strike, and nothing else")
	assert_lt(raptor.attack_reach(), float(config_node.DINO_ATTACK_REACH),
		"Which is far less than the flat 2.2m every species used to get")

func test_02_a_bigger_dinosaur_reaches_further_because_it_is_bigger() -> void:
	var raptor = _dino("raptor", Vector3.ZERO)
	var big = _dino("big_theropod", Vector3(20.0, 0.0, 0.0))
	await wait_frames(2)
	assert_gt(big.attack_reach(), raptor.attack_reach(), "Size tells in what it can touch")

func test_03_how_close_it_must_get_depends_on_what_it_is_biting() -> void:
	# The half a flat number cannot express: a stake is 0.62m and the wreck is wider, so
	# reaching the wreck starts further out from its centre than reaching a stake does.
	var gm = _grid()
	await wait_frames(1)
	var raptor = _dino("raptor", Vector3.ZERO)
	var stake = _building("wall", gm, Vector2i(8, 8))
	var tower = _building("tower", gm, Vector2i(12, 12))
	await wait_frames(2)

	assert_lt(raptor._half_width_of(stake), raptor._half_width_of(tower),
		"A stake is the narrower thing")
	var to_stake: float = raptor.attack_reach() + raptor._half_width_of(stake)
	var to_tower: float = raptor.attack_reach() + raptor._half_width_of(tower)
	assert_lt(to_stake, to_tower, "So it has to get closer to a stake than to a turret")

# ==============================================================================
# 2. And a bite does not pass through things
# ==============================================================================

func test_04_it_cannot_bite_the_cabin_through_a_stake() -> void:
	# The report itself.
	var gm = _grid()
	await wait_frames(1)
	var core = _spawn("res://scripts/entities/CoreCampfire.gd", gm.cell_to_world(Vector2i(0, 0)))
	if core.has_method("setup"):
		core.setup("core", Vector2i(0, 0))
	core.global_position = gm.cell_to_world(Vector2i(0, 0))
	gm.occupy_cell(Vector2i(0, 0), core)
	var stake = _building("wall", gm, Vector2i(1, 0))
	var raptor = _dino("raptor", gm.cell_to_world(Vector2i(2, 0)))
	await wait_frames(2)

	assert_true(raptor._solid_between(core), "The stake stands between them")
	assert_false(raptor._target_in_reach(core), "So the cabin is not something it can bite")

func test_05_and_still_bites_the_stake_that_is_in_the_way() -> void:
	var gm = _grid()
	await wait_frames(1)
	var stake = _building("wall", gm, Vector2i(1, 0))
	var bite: float = 0.0
	var raptor = _dino("raptor", Vector3.ZERO)
	await wait_frames(2)
	bite = raptor.attack_reach() + raptor._half_width_of(stake)
	raptor.global_position = stake.global_position + Vector3(0.0, 0.0, -bite * 0.9)
	await wait_frames(1)

	assert_false(raptor._solid_between(stake), "Nothing stands between it and the stake")
	assert_true(raptor._target_in_reach(stake), "Which it can reach")

func test_06_a_clear_line_at_the_right_distance_still_works() -> void:
	var gm = _grid()
	await wait_frames(1)
	var tower = _building("tower", gm, Vector2i(0, 0))
	var raptor = _dino("raptor", Vector3.ZERO)
	await wait_frames(2)
	var bite: float = raptor.attack_reach() + raptor._half_width_of(tower)
	raptor.global_position = tower.global_position + Vector3(0.0, 0.0, -bite * 0.9)
	await wait_frames(1)

	assert_true(raptor._target_in_reach(tower), "In reach with a clear line")
	var before: float = tower.current_hp
	raptor.current_target = tower
	raptor.perform_attack()
	assert_lt(tower.current_hp, before, "And the bite lands")

# ==============================================================================
# 3. Seeing, stopping and biting are one distance
# ==============================================================================

func test_07_it_does_not_stop_at_a_distance_it_cannot_bite_from() -> void:
	# The third bug, which was hiding behind the first two: the stop was a hardcoded 1.8m
	# while the bite was attack_reach, so a dinosaur halted short and stood in ATTACKING
	# state doing nothing. It now walks until it can actually reach.
	var gm = _grid()
	await wait_frames(1)
	var tower = _building("tower", gm, Vector2i(0, -2))
	var raptor = _dino("raptor", Vector3(1.0, 0.0, -8.0))
	raptor.set_waypoints([Vector3(1.0, 0.0, -8.0), Vector3(1.0, 0.0, 0.0)])
	await wait_frames(2)

	for step in range(120):
		if int(raptor.current_state) == int(raptor.State.ATTACKING):
			break
		raptor.advance_towards_waypoint(0.05)
		await wait_frames(1)

	assert_eq(int(raptor.current_state), int(raptor.State.ATTACKING), "It commits to the turret")
	assert_true(raptor._target_in_reach(tower),
		"From somewhere it can actually bite it, not from wherever it first saw it")
	var before: float = tower.current_hp
	raptor.perform_attack()
	assert_lt(tower.current_hp, before, "So the attack it committed to does something")
