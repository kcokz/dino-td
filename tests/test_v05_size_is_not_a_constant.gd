# res://tests/test_v05_size_is_not_a_constant.gd
# Where a dinosaur stands, and how far the spikes reach, come from the building.
#
# Reported as "恐龙会在圈出来的地方来回穿梭，进攻不了还掉血" -- shuttling back and forth
# beside a fence, unable to attack, losing health the whole time. Measured at
# FORTY-SEVEN DIRECTION REVERSALS in twenty-five seconds and 18.7 health gone, on an
# animal with three.
#
# Two causes, and both are the same mistake: NUMBERS TUNED WHEN EVERY BUILDING FILLED A
# 2m TILE, left behind when a stake became 0.62m wide.
#
#   * the attack slots were fixed radii from a building's CENTRE, 1.6m and 2.6m. Against
#     a 0.62m cone that is standing 1.3 to 2.3 metres clear of it -- which is exactly the
#     "站在木尖刺前（有一段距离）" that was reported over and over, and which no amount of
#     work on the targeting rules could ever have fixed;
#   * contact_range was a flat 2.0m, so each cone damaged everything within two metres:
#     a four-metre-wide field around a stake you could step over, which bled raids that
#     were only walking PAST it through a gap.
#
# And the shuttle itself was a third thing: steering was recomputed from nothing every
# frame and applied whole, so any term that changed sign reversed the animal instantly.
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

func _spawn(script_path: String, at: Vector3 = Vector3.ZERO) -> Node:
	var n = load(script_path).new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	if n is Node3D:
		(n as Node3D).global_position = at
	return n

func _stake(at: Vector3 = Vector3.ZERO) -> Node:
	var w = _spawn("res://scripts/entities/Wall.gd", at)
	w.setup("wall", Vector2i.ZERO)
	w.global_position = at
	w.complete_construction()
	return w

# ==============================================================================
# 1. A small building is approached closely
# ==============================================================================

func test_01_where_a_dinosaur_stands_comes_from_the_buildings_own_size() -> void:
	var stake_ring: float = float(config_node.get_attack_slot_radius("wall", false))
	var tower_ring: float = float(config_node.get_attack_slot_radius("tower", false))
	assert_lt(stake_ring, tower_ring, "A stake is approached more closely than a turret")

	# Measured from the FACE, so the standoff is the same for both.
	var stake_gap: float = stake_ring - float(config_node.get_building_footprint("wall")) * 0.5
	var tower_gap: float = tower_ring - float(config_node.get_building_footprint("tower")) * 0.5
	assert_almost_eq(stake_gap, tower_gap, 0.001,
		"Because it is the same standoff from the face in both cases")
	assert_almost_eq(stake_gap, float(config_node.DINO_STANDOFF_INNER), 0.001,
		"Which is what Config declares it to be")

func test_02_the_old_fixed_ring_was_far_too_far_for_a_stake() -> void:
	# The number this replaces, and the size of the mistake. Keeping it as an assertion
	# because "it looked like it stopped short" was reported four times before anyone
	# thought to measure where a stake's attackers were actually being sent.
	var ring: float = float(config_node.get_attack_slot_radius("wall", false))
	var old_fixed: float = float(config_node.DINO_ATTACK_SLOT_RADIUS_INNER)
	assert_lt(ring, old_fixed, "A stake's attackers stand closer than the old fixed ring")
	assert_gt(old_fixed - ring, 0.5, "By over half a metre, which is plainly visible from above")

func test_03_a_two_metre_building_keeps_the_numbers_it_always_had() -> void:
	# The derivation has to reproduce the old constants for the case they were chosen
	# for, or this is a rebalance wearing a bug fix's clothes.
	var two_metre: float = float(config_node.TILE_SIZE)
	var inner: float = two_metre * 0.5 + float(config_node.DINO_STANDOFF_INNER)
	var outer: float = two_metre * 0.5 + float(config_node.DINO_STANDOFF_OUTER)
	assert_almost_eq(inner, float(config_node.DINO_ATTACK_SLOT_RADIUS_INNER), 0.001,
		"1.0 + 0.6 is the 1.6 that was there before")
	assert_almost_eq(outer, float(config_node.DINO_ATTACK_SLOT_RADIUS_OUTER), 0.001,
		"And 1.0 + 1.6 is the 2.6")

func test_04_the_slots_a_dinosaur_can_claim_are_close_to_a_stake() -> void:
	var stake = _stake(Vector3.ZERO)
	var dino = _spawn(String(config_node.get_dino_script_path("raptor")), Vector3(4.0, 0.0, 0.0))
	dino.setup("raptor")
	await wait_frames(1)

	Dino.clear_all_attack_slots()
	var slot: Vector3 = Dino.claim_attack_slot(stake, dino)
	assert_ne(slot, Vector3.ZERO, "It gets somewhere to stand")
	var stand_off: float = slot.distance_to(stake.global_position)
	assert_lte(stand_off, float(config_node.get_attack_slot_radius("wall", true)) + 0.01,
		"No further out than the stake's own outer ring")
	assert_lt(stand_off, float(config_node.DINO_ATTACK_SLOT_RADIUS_OUTER),
		"Which is nearer than the old fixed one")

# ==============================================================================
# 2. The spikes reach what is against them and nothing else
# ==============================================================================

func test_05_contact_range_is_derived_not_declared() -> void:
	assert_false(config_node.BUILDINGS["wall"].has("contact_range"),
		"No flat number left to go stale when the stake is resized again")
	var reach: float = float(config_node.get_contact_range("wall"))
	assert_gte(reach, float(config_node.get_attack_slot_radius("wall", false)),
		"It reaches whatever is standing against the spikes")
	assert_lt(reach, float(config_node.DINO_ATTACK_SLOT_RADIUS_INNER) + 0.5,
		"And stops well short of the two metres it used to cover")

func test_06_something_walking_past_through_a_gap_is_not_bled() -> void:
	# The reported half: a raid that had found a way round was being chewed by stakes it
	# never touched, because every cone damaged everything within two metres of it.
	var stake = _stake(Vector3.ZERO)
	await wait_frames(1)
	var reach: float = stake.contact_range
	var passing = _spawn(String(config_node.get_dino_script_path("raptor")),
		Vector3(reach + 0.3, 0.0, 0.0))
	passing.setup("raptor")
	await wait_frames(1)

	var before: float = passing.current_hp
	stake.damage_touching_dinos()
	assert_eq(passing.current_hp, before, "Walking past at arm's length costs nothing")
	assert_lt(reach + 0.3, 2.0, "And arm's length is inside what the old range covered")

func test_07_something_pressed_against_them_still_is() -> void:
	var stake = _stake(Vector3.ZERO)
	await wait_frames(1)
	var ring: float = float(config_node.get_attack_slot_radius("wall", false))
	var biting = _spawn(String(config_node.get_dino_script_path("raptor")), Vector3(ring, 0.0, 0.0))
	biting.setup("raptor")
	await wait_frames(1)

	var before: float = biting.current_hp
	assert_eq(stake.damage_touching_dinos(), 1, "The one standing where it bites is caught")
	assert_lt(biting.current_hp, before, "And pays for it")

# ==============================================================================
# 2b. A fence hurts once, however many stakes are reaching you
# ==============================================================================
#
# The fourth time the same mistake turned up in this system, and the same shape as the
# three above: A NUMBER TUNED FOR ONE LAYOUT APPLIED TO ANOTHER. The layout that changed
# is the stakes' own finer grid -- they stand 0.67m apart now -- while contact_range has
# to be wide enough to cover whatever is standing in the attack slot, 0.91m out. So
# three stakes reach the same animal and each one used to damage it separately.

func _fence_run(from_x: float, to_x: float) -> Array[Node]:
	var out: Array[Node] = []
	var step: float = float(config_node.TILE_SIZE) / float(config_node.get_cell_divisions("wall"))
	var x: float = from_x
	while x <= to_x + 0.001:
		out.append(_stake(Vector3(x, 0.0, 0.0)))
		x += step
	return out

func test_07b_three_stakes_reach_one_animal_standing_where_it_bites() -> void:
	# The measurement the rest of this section rests on, so that it fails loudly if the
	# spacing or the range ever move apart again.
	var run: Array[Node] = _fence_run(-2.0, 2.0)
	await wait_frames(1)
	var ring: float = float(config_node.get_attack_slot_radius("wall", false))
	var biting = _spawn(String(config_node.get_dino_script_path("raptor")), Vector3(0.0, 0.0, ring))
	biting.setup("raptor")
	await wait_frames(1)

	var reaching: int = 0
	for stake in run:
		if (stake as Node3D).global_position.distance_to(biting.global_position) <= stake.contact_range:
			reaching += 1
	assert_gt(reaching, 1, "More than one stake of a fence reaches what is biting it")

func test_07c_the_fence_does_what_the_build_menu_says_it_does() -> void:
	# Measured before the fix: 0.90 dps against the 0.30 the menu promises -- exactly
	# three times, for the three stakes in reach. The build menu is not wrong; the fence
	# was.
	var run: Array[Node] = _fence_run(-2.0, 2.0)
	await wait_frames(1)
	var ring: float = float(config_node.get_attack_slot_radius("wall", false))
	var biting = _spawn(String(config_node.get_dino_script_path("raptor")), Vector3(0.0, 0.0, ring))
	biting.setup("raptor")
	biting.max_hp = 9999.0
	biting.current_hp = 9999.0
	await wait_frames(1)

	var before: float = biting.current_hp
	var ticks: int = 4
	for i in range(ticks):
		for stake in run:
			stake.damage_touching_dinos()
		await wait_physics_frames(1)
	var declared: float = float(config_node.get_contact_dps("wall"))
	var per_tick: float = declared * float(config_node.BUILDINGS["wall"]["contact_tick"])
	assert_almost_eq(before - biting.current_hp, per_tick * float(ticks), 0.001,
		"Four ticks of a whole fence is four chips, not four times however many stakes")

func test_07d_so_a_raptor_gets_through_one_stake_alive() -> void:
	# The balance Config.BUILDINGS.wall states in so many words: "a raptor chewing through
	# these 8 HP comes out alive but nearly dead, leaving the finishing to a tower or the
	# Hero". It did not. Chewing one stake takes 8 seconds and it was losing 7.2 of its 3
	# health doing it -- dead in three and a half, with the stake three quarters standing.
	var damage: float = float(config_node.DINOS["raptor"]["damage"])
	var rate: float = float(config_node.DINOS["raptor"]["attack_rate"])
	var stake_hp: float = float(config_node.BUILDINGS["wall"]["hp"])
	var tick: float = float(config_node.BUILDINGS["wall"]["contact_tick"])
	var seconds_to_chew: float = stake_hp / (damage * rate)

	var run: Array[Node] = _fence_run(-2.0, 2.0)
	await wait_frames(1)
	var ring: float = float(config_node.get_attack_slot_radius("wall", false))
	var biting = _spawn(String(config_node.get_dino_script_path("raptor")), Vector3(0.0, 0.0, ring))
	biting.setup("raptor")
	await wait_frames(1)
	var hp: float = biting.current_hp

	# Its whole meal, driven a tick at a time rather than waited out. Checked for being
	# alive each time round, because a dead one frees itself and the interesting failure
	# is "it died", not a null dereference three lines later.
	var survived: bool = true
	var left: float = hp
	for i in range(int(ceil(seconds_to_chew / tick))):
		for stake in run:
			stake.damage_touching_dinos()
		await wait_physics_frames(1)
		if not is_instance_valid(biting) or biting.is_dead:
			survived = false
			left = 0.0
			break
		left = biting.current_hp

	assert_true(survived, "It survives the stake it is eating")
	assert_lt(left, hp * 0.5, "But only just -- a fence is still worth building")

# ==============================================================================
# 3. And the avoidance that replaced the hand-written steering
# ==============================================================================

func test_08_a_dinosaur_is_registered_with_the_avoidance_solver() -> void:
	# What the four deleted tests above used to check by hand -- which side to pass on,
	# how fast to turn, how hard to yield -- is the solver's business now. What is left
	# worth asserting is that every dinosaur is actually handed to it, with its own size.
	var dino = _spawn(String(config_node.get_dino_script_path("raptor")), Vector3.ZERO)
	dino.setup("raptor")
	await wait_frames(2)

	assert_true(dino._agent.is_valid(), "It has an avoidance agent on the navigation server")
	assert_true("DINO_AVOID_NEIGHBOURS" in config_node, "Whose settings are declared in Config")
	assert_gt(float(config_node.DINO_AVOID_NEIGHBOURS), 0.0, "And are real numbers")

	var big = _spawn(String(config_node.get_dino_script_path("big_theropod")), Vector3(6.0, 0.0, 0.0))
	big.setup("big_theropod")
	await wait_frames(2)
	assert_true(big._agent.is_valid(), "So does a theropod")
	assert_gt(float(config_node.get_visual_size("dino/big_theropod").x),
		float(config_node.get_visual_size("dino/raptor").x),
		"And it is bigger, so it is given a bigger radius -- it must not fit where a raptor does")
