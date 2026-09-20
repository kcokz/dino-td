# res://tests/test_v04_raid_crowd.gd
# A raid is a crowd, and every raid dinosaur is a PackDino.
#
# Reported a fourth time: "恐龙站在木尖刺前（有一段距离）就不进攻了，然后就卡着不动". The
# previous three fixes were real, were measured, and applied to code no raid has ever run.
#
#   1. THE RULE WAS IN A METHOD THE SUBCLASSES REPLACED. PackDino and SiegeDino both
#      overrode _find_threat_priority_target outright, so the "only bite a wall that is
#      actually in the way" check applied to the base class and nothing else. raptor's
#      behaviour is "pack", so EVERY raptor in EVERY wave skipped it. Measured with the
#      script the game really spawns: 2 of 20 got past a fence with both ends open. The
#      ones that did not sat 2.7m off the stakes -- DINO_ATTACK_SLOT_RADIUS_OUTER, which
#      is exactly the "some distance" in the report.
#
#   2. YIELDING TO THE DINOSAUR IN FRONT COULD REACH ZERO SPEED. In a pack that is a
#      deadlock, because nobody has any speed left to get out of anyone's way. Nine of
#      twenty standing still, the worst for ten unbroken seconds. At five dinosaurs it
#      hardly showed -- which is why every earlier probe, all of which used five, missed
#      it. A CROWD IS A DIFFERENT PROBLEM FROM A QUEUE.
#
#   3. "STEP ASIDE" WAS HARD-CODED TO WORLD X. Right for a raid travelling along Z, and
#      for one travelling along X it means stepping into the dinosaur being avoided.
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

func _grid(blocked: Array = []) -> Node:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	return gm

func _wall_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

## A dinosaur of the kind the game really spawns for `type_id`, not the base class.
func _real_dino(type_id: String, at: Vector3, goal: Vector3) -> Node:
	var path: String = String(config_node.get_dino_script_path(type_id))
	var d = load(path).new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup(type_id)
	d.global_position = at
	d.set_waypoints([goal])
	return d

# ==============================================================================
# 1. No species can step past the rule
# ==============================================================================

func test_01_only_the_base_class_decides_what_is_worth_stopping_for() -> void:
	# The check that would have caught this at the time. The rule lives in
	# Dino._find_threat_priority_target; a subclass that replaces THAT method replaces the
	# rule with nothing. Species say what they WANT by overriding _preferred_target.
	var offenders: Array[String] = []
	var dir := DirAccess.open("res://scripts/entities")
	assert_not_null(dir, "The entities folder is readable")
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".gd") and name != "Dino.gd":
			var f := FileAccess.open("res://scripts/entities/".path_join(name), FileAccess.READ)
			if f != null and f.get_as_text().contains("func _find_threat_priority_target"):
				offenders.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	assert_eq(offenders.size(), 0,
		"Only Dino.gd may define _find_threat_priority_target; override _preferred_target instead. Offenders: %s"
			% ", ".join(offenders))

func test_02_every_declared_behaviour_routes_through_the_rule() -> void:
	# Against the real scripts rather than against a filename convention: whatever
	# Config maps a behaviour to has to still answer the rule.
	assert_gt(config_node.DINO_BEHAVIOURS.size(), 0, "There are behaviours declared")
	for habit in config_node.DINO_BEHAVIOURS:
		var path: String = String(config_node.DINO_BEHAVIOURS[habit])
		var script: GDScript = load(path)
		assert_not_null(script, "%s loads" % habit)
		var d = script.new()
		_cleanup_nodes.append(d)
		tree.root.add_child(d)
		assert_true(d.has_method("_preferred_target"),
			"%s says what it wants through _preferred_target" % habit)

func test_03_a_raptor_does_not_stop_for_a_fence_it_can_walk_round() -> void:
	# The report itself, using the script a wave really spawns. A raptor is a PackDino,
	# and a PackDino used to target the nearest stake within two metres regardless.
	var gm = _grid([])
	await wait_frames(1)
	for x in range(-3, 4):
		_wall_at(gm, Vector2i(x, 0))
	var d = _real_dino("raptor", gm.cell_to_world(Vector2i(0, 0)) + Vector3(0.0, 0.0, 1.6),
		gm.cell_to_world(Vector2i(0, -5)))
	await wait_frames(1)

	assert_true(d.get_script().resource_path.ends_with("PackDino.gd"),
		"A raptor really is a PackDino -- the thing every earlier probe was not testing")
	assert_lt(d.global_position.distance_to(gm.cell_to_world(Vector2i(0, 0))),
		float(d.building_interest_range()), "And the fence is well inside its interest range")
	assert_false(d._way_is_sealed(), "But the ground past the end of the fence is open")
	assert_null(d._find_threat_priority_target(), "So the fence is not worth stopping for")

func test_04_and_still_bites_one_that_seals_the_way() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var goal := Vector2i(0, -4)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				_wall_at(gm, goal + Vector2i(dx, dz))
	var d = _real_dino("raptor", gm.cell_to_world(Vector2i(0, -6)), gm.cell_to_world(goal))
	await wait_frames(1)

	assert_true(d._way_is_sealed(), "Walled in")
	assert_not_null(d._find_threat_priority_target(), "So the ring is worth stopping for")

func test_04b_a_siege_dinosaur_eats_the_fence_instead_of_going_round() -> void:
	# The rule belongs to the species, not to all dinosaurs. SiegeDino.gd says it "walks
	# through the defence rather than fighting the defenders" and bites "whatever is
	# standing in front of it" -- making the rule universal would have left that a
	# sentence in a comment. A pack funnels through the gap; a theropod eats the fence.
	var gm = _grid([])
	await wait_frames(1)
	for x in range(-3, 4):
		_wall_at(gm, Vector2i(x, 0))

	var raptor = _real_dino("raptor", gm.cell_to_world(Vector2i(0, 0)) + Vector3(0.0, 0.0, 1.6),
		gm.cell_to_world(Vector2i(0, -5)))
	var theropod = _real_dino("big_theropod", gm.cell_to_world(Vector2i(2, 0)) + Vector3(0.0, 0.0, 1.6),
		gm.cell_to_world(Vector2i(2, -5)))
	await wait_frames(1)

	assert_true(raptor.walks_round_walls(), "A pack goes round what it can go round")
	assert_false(theropod.walks_round_walls(), "A theropod does not")
	assert_false(raptor._way_is_sealed(), "The fence has open ends, for both of them")
	assert_null(raptor._find_threat_priority_target(), "So the raptor walks round it")
	assert_not_null(theropod._find_threat_priority_target(), "And the theropod eats it")

# ==============================================================================
# 2. A crowd never talks itself to a standstill
# ==============================================================================

func test_06_a_packed_raid_gets_past_a_fence_with_open_ends() -> void:
	# The measurement that matters, at the size the report was made at. Twenty of them,
	# shoulder to shoulder, and a fence they can walk round.
	var gm = _grid([])
	await wait_frames(1)
	for x in range(-2, 3):
		_wall_at(gm, Vector2i(x, 0))

	var goal: Vector3 = gm.cell_to_world(Vector2i(0, -6))
	var raid: Array[Node] = []
	var started: Array[float] = []
	for i in range(20):
		var at: Vector3 = gm.cell_to_world(Vector2i(-2 + (i % 5), 5 + (i / 5)))
		var d = _real_dino("raptor", at, goal)
		d.max_hp = 9999.0
		d.current_hp = 9999.0
		raid.append(d)
		started.append(at.distance_to(goal))
	await wait_frames(1)

	for step in range(900):
		for d in raid:
			if is_instance_valid(d):
				d.advance_towards_waypoint(1.0 / 60.0)

	var got_through: int = 0
	for i in range(raid.size()):
		if is_instance_valid(raid[i]) and raid[i].global_position.z < gm.cell_to_world(Vector2i(0, 0)).z:
			got_through += 1
	assert_gt(got_through, raid.size() / 2,
		"Most of a packed raid gets past a fence it can walk round (%d of %d)" % [got_through, raid.size()])

# ==============================================================================
# 3. Aside means aside
# ==============================================================================
