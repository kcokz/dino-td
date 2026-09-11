# res://tests/test_economy_ap_challenge.gd
# Empirical Challenger 2 Test Suite for Milestone 3:
# Stress tests economy production and AP recovery:
# 1. 10+ concurrent LumberHuts producing wood over multiple turns.
# 2. Destroying LumberHuts during ATTACK phase and verifying 0 wood payout in PRODUCE phase.
# 3. Dynamic AP recovery, capacity adjustments with building bonuses, and state boundary resilience.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var lumber_hut_script: GDScript = null
var building_script: GDScript = null
var grid_manager_script: GDScript = null
var build_system_script: GDScript = null

var _cleanup_nodes: Array[Node] = []
var _cleanup_objects: Array[Object] = []

# ==============================================================================
# Lifecycle Hooks
# ==============================================================================

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if config_node == null and ResourceLoader.exists("res://scripts/autoload/Config.gd"):
		config_node = load("res://scripts/autoload/Config.gd").new()
		_cleanup_objects.append(config_node)

	if event_bus_node == null and ResourceLoader.exists("res://scripts/autoload/EventBus.gd"):
		event_bus_node = load("res://scripts/autoload/EventBus.gd").new()
		_cleanup_objects.append(event_bus_node)

	if game_state_node == null and ResourceLoader.exists("res://scripts/autoload/GameState.gd"):
		game_state_node = load("res://scripts/autoload/GameState.gd").new()
		_cleanup_objects.append(game_state_node)

	lumber_hut_script = _load_script([
		"res://scripts/entities/LumberHut.gd",
		"res://scripts/entities/lumber_hut.gd"
	])
	building_script = _load_script([
		"res://scripts/entities/Building.gd",
		"res://scripts/entities/building.gd"
	])
	grid_manager_script = _load_script([
		"res://scripts/core/GridManager.gd",
		"res://scripts/core/grid_manager.gd"
	])
	build_system_script = _load_script([
		"res://scripts/core/BuildSystem.gd",
		"res://scripts/core/build_system.gd"
	])

func before_each() -> void:
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		else:
			if "current_phase" in game_state_node: game_state_node.current_phase = 0
			if "current_ap" in game_state_node: game_state_node.current_ap = 3
			if "max_ap" in game_state_node: game_state_node.max_ap = 3
			if "resources" in game_state_node: game_state_node.resources = {"wood": 10, "stone": 0, "food": 0}
			if "is_game_over" in game_state_node: game_state_node.is_game_over = false
			if "active_buildings" in game_state_node: game_state_node.active_buildings.clear()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if not n.is_queued_for_deletion():
				if n.is_inside_tree():
					n.get_parent().remove_child(n)
				n.free()
	_cleanup_nodes.clear()

	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	for obj in _cleanup_objects:
		if is_instance_valid(obj):
			if obj is Node:
				if not obj.is_queued_for_deletion():
					if obj.is_inside_tree():
						obj.get_parent().remove_child(obj)
					obj.free()
	_cleanup_objects.clear()

# ==============================================================================
# Helper Utilities
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_lumber_hut() -> Object:
	assert_not_null(lumber_hut_script, "LumberHut script must exist")
	if lumber_hut_script == null:
		return null
	var hut = lumber_hut_script.new()
	if hut is Node:
		_cleanup_nodes.append(hut)
	else:
		_cleanup_objects.append(hut)
	return hut

func _create_grid_manager() -> Object:
	if grid_manager_script == null:
		return null
	var instance = grid_manager_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)
	return instance

func _create_build_system(grid_mgr: Object) -> Object:
	if build_system_script == null:
		return null
	var instance = build_system_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)
	if "grid_manager" in instance:
		instance.grid_manager = grid_mgr
	elif instance.has_method("setup"):
		instance.call("setup", grid_mgr)
	return instance

func _get_wood() -> int:
	if game_state_node != null and "resources" in game_state_node:
		return game_state_node.resources.get("wood", 0)
	return -1

func _get_ap() -> int:
	if game_state_node != null and "current_ap" in game_state_node:
		return game_state_node.current_ap
	return -1

func _get_phase() -> int:
	if game_state_node != null and "current_phase" in game_state_node:
		return int(game_state_node.current_phase)
	return -1

# ==============================================================================
# Section 1: 10+ Concurrent LumberHuts Producing Wood Over Multiple Turns
# ==============================================================================

func test_challenge_10_concurrent_lumber_huts_single_turn_wood_payout() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var huts: Array[Object] = []
	for i in range(10):
		var hut = _create_lumber_hut()
		assert_not_null(hut, "LumberHut %d must be created" % i)
		huts.append(hut)

	assert_eq(huts.size(), 10, "10 LumberHuts must be present")
	assert_eq(_get_wood(), 10, "Initial wood is 10")

	var res_watcher = watch_signal(event_bus_node, "resources_changed")

	# Transition PLAN (0) -> ATTACK (1) -> PRODUCE (2)
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "Phase is ATTACK (1)")

	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "Phase is PRODUCE (2)")

	# 10 LumberHuts each produce 2 wood -> 10 * 2 = 20 wood added. Total = 30 wood.
	assert_eq(_get_wood(), 30, "10 LumberHuts must produce 20 wood (10 + 20 = 30)")
	assert_true(res_watcher.emitted, "resources_changed signal emitted")
	assert_eq(res_watcher.emit_count, 10, "resources_changed emitted 10 times (once per hut)")

func test_challenge_15_concurrent_lumber_huts_across_10_turns_compounding() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var huts: Array[Object] = []
	for i in range(15):
		var hut = _create_lumber_hut()
		assert_not_null(hut, "LumberHut %d must be created" % i)
		huts.append(hut)

	assert_eq(_get_wood(), 10, "Initial wood is 10")

	# Run 10 consecutive full turn cycles: PLAN -> ATTACK -> PRODUCE -> PLAN
	var expected_wood = 10
	for turn in range(1, 11):
		assert_eq(_get_phase(), 0, "Turn %d starts in PLAN (0)" % turn)
		assert_eq(_get_ap(), 3, "Turn %d AP reset to 3 in PLAN" % turn)

		# Spend 2 AP during PLAN
		assert_true(game_state_node.spend_ap(2), "Turn %d spend 2 AP" % turn)
		assert_eq(_get_ap(), 1, "Turn %d AP is 1 after spending" % turn)

		# Advance to ATTACK
		game_state_node.trigger_end_action()
		assert_eq(_get_phase(), 1, "Turn %d phase is ATTACK" % turn)
		assert_eq(_get_ap(), 1, "Turn %d AP remains 1 during ATTACK" % turn)

		# Advance to PRODUCE via wave_ended
		event_bus_node.wave_ended.emit(turn)
		assert_eq(_get_phase(), 2, "Turn %d phase is PRODUCE" % turn)
		assert_eq(_get_ap(), 1, "Turn %d AP remains 1 during PRODUCE" % turn)

		# 15 LumberHuts * 2 wood = +30 wood
		expected_wood += 30
		assert_eq(_get_wood(), expected_wood, "Turn %d wood compounded to %d" % [turn, expected_wood])

		# Transition back to PLAN -> AP must be restored to 3
		game_state_node.advance_phase()
		assert_eq(_get_phase(), 0, "Turn %d transitioned back to PLAN" % turn)
		assert_eq(_get_ap(), 3, "Turn %d AP restored to max_ap (3)" % turn)

	assert_eq(_get_wood(), 310, "After 10 turns with 15 huts, total wood must be 10 + 10*30 = 310")

func test_challenge_30_concurrent_lumber_huts_high_load_stress() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var huts: Array[Object] = []
	for i in range(30):
		var hut = _create_lumber_hut()
		assert_not_null(hut, "LumberHut %d must be created" % i)
		huts.append(hut)

	assert_eq(huts.size(), 30, "30 LumberHuts created")
	assert_eq(_get_wood(), 10, "Initial wood is 10")

	# 3 turns high-load simulation (30 * 2 = 60 wood per turn)
	for turn in range(1, 4):
		game_state_node.trigger_end_action()
		event_bus_node.wave_ended.emit(turn)
		assert_eq(_get_phase(), 2, "Turn %d in PRODUCE" % turn)
		var expected = 10 + turn * 60
		assert_eq(_get_wood(), expected, "Turn %d wood must be %d" % [turn, expected])
		game_state_node.advance_phase()
		assert_eq(_get_ap(), 3, "AP reset to 3 in PLAN")

# ==============================================================================
# Section 2: Destroying LumberHuts During ATTACK Phase & Verifying 0 Wood Payout
# ==============================================================================

func test_challenge_destroy_single_lumber_hut_during_attack_zero_payout() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var hut = _create_lumber_hut()
	assert_not_null(hut, "LumberHut created")
	assert_eq(_get_wood(), 10, "Initial wood is 10")

	# 1. PLAN -> ATTACK
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "Now in ATTACK phase")

	# 2. In ATTACK phase: LumberHut takes lethal damage (10.0 HP)
	var destroyed_watcher = watch_signal(event_bus_node, "building_destroyed")
	hut.take_damage(10.0)
	assert_true(hut.is_destroyed, "LumberHut must be marked is_destroyed")
	assert_lte(float(hut.current_hp), 0.0, "LumberHut HP <= 0.0")
	assert_true(destroyed_watcher.emitted, "building_destroyed signal emitted")

	# 3. Wave ends -> transitions to PRODUCE phase
	var res_watcher = watch_signal(event_bus_node, "resources_changed")
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "Now in PRODUCE phase")

	# 4. Verifying 0 wood payout
	assert_eq(_get_wood(), 10, "Destroyed LumberHut must produce exactly 0 wood (wood remains 10)")
	assert_false(res_watcher.emitted, "resources_changed must NOT be emitted for destroyed hut")

func test_challenge_destroy_all_10_lumber_huts_during_attack_zero_payout() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var huts: Array[Object] = []
	for i in range(10):
		var hut = _create_lumber_hut()
		huts.append(hut)

	assert_eq(_get_wood(), 10, "Initial wood is 10")

	# Enter ATTACK phase
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "In ATTACK phase")

	# Destroy ALL 10 LumberHuts during ATTACK phase
	for i in range(10):
		huts[i].take_damage(10.0)
		assert_true(huts[i].is_destroyed, "Hut %d must be destroyed" % i)

	# Transition to PRODUCE phase
	var res_watcher = watch_signal(event_bus_node, "resources_changed")
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# Zero wood payout: wood remains strictly 10
	assert_eq(_get_wood(), 10, "All 10 huts destroyed in ATTACK must yield 0 wood payout (wood remains 10)")
	assert_false(res_watcher.emitted, "resources_changed must NOT be emitted when 0 resources produced")

func test_challenge_selective_destruction_during_attack_phase() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var huts: Array[Object] = []
	for i in range(12):
		huts.append(_create_lumber_hut())

	assert_eq(_get_wood(), 10, "Initial wood is 10")

	# Enter ATTACK phase
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "In ATTACK phase")

	# Destroy 5 huts (indices 0, 2, 4, 6, 8) during ATTACK phase
	var destroyed_indices = [0, 2, 4, 6, 8]
	for idx in destroyed_indices:
		huts[idx].take_damage(10.0)
		assert_true(huts[idx].is_destroyed, "Hut %d destroyed" % idx)

	# Remaining 7 huts (indices 1, 3, 5, 7, 9, 10, 11) are alive
	for idx in range(12):
		if not destroyed_indices.has(idx):
			assert_false(huts[idx].is_destroyed, "Hut %d must remain alive" % idx)

	# Transition to PRODUCE phase
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# Exactly 7 surviving huts produce 7 * 2 = 14 wood (10 -> 24)
	assert_eq(_get_wood(), 24, "7 living huts produce +14 wood, 5 destroyed produce 0 (10 + 14 = 24)")

func test_challenge_various_attack_destruction_modes() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var h0 = _create_lumber_hut() # exact lethal
	var h1 = _create_lumber_hut() # overkill
	var h2 = _create_lumber_hut() # multi-hit
	var h3 = _create_lumber_hut() # direct destroy()

	assert_eq(_get_wood(), 10, "Initial wood is 10")

	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "In ATTACK phase")

	# Destruction modes applied during ATTACK phase:
	h0.take_damage(10.0)
	assert_true(h0.is_destroyed, "h0 exact lethal destroyed")

	h1.take_damage(9999.0)
	assert_true(h1.is_destroyed, "h1 overkill destroyed")
	assert_lte(float(h1.current_hp), 0.0, "h1 hp <= 0")

	h2.take_damage(4.0)
	assert_false(h2.is_destroyed, "h2 alive after 1st hit (6.0 HP left)")
	h2.take_damage(4.0)
	assert_false(h2.is_destroyed, "h2 alive after 2nd hit (2.0 HP left)")
	h2.take_damage(4.0)
	assert_true(h2.is_destroyed, "h2 destroyed after 3rd hit")

	h3.destroy()
	assert_true(h3.is_destroyed, "h3 direct destroy() succeeded")

	# Enter PRODUCE phase
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# Zero payout from all 4 destroyed huts
	assert_eq(_get_wood(), 10, "All 4 varied-destruction huts must deposit 0 wood (wood remains 10)")

func test_challenge_damaged_but_alive_lumber_huts_still_produce() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var h0 = _create_lumber_hut() # pristine (10 HP)
	var h1 = _create_lumber_hut() # moderate damage (5 HP left)
	var h2 = _create_lumber_hut() # near death (0.5 HP left)
	var h3 = _create_lumber_hut() # dead (0 HP)

	assert_eq(_get_wood(), 10, "Initial wood is 10")

	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "In ATTACK phase")

	h1.take_damage(5.0)
	assert_false(h1.is_destroyed, "h1 is alive")
	assert_eq(float(h1.current_hp), 5.0, "h1 current_hp is 5.0")

	h2.take_damage(9.5)
	assert_false(h2.is_destroyed, "h2 is alive")
	assert_eq(float(h2.current_hp), 0.5, "h2 current_hp is 0.5")

	h3.take_damage(10.0)
	assert_true(h3.is_destroyed, "h3 is destroyed")

	# Enter PRODUCE phase
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# 3 living huts produce 3 * 2 = 6 wood. Dead hut produces 0.
	assert_eq(_get_wood(), 16, "3 living huts (including damaged) produce +6 wood, dead hut produces 0 (10 + 6 = 16)")

func test_challenge_deferred_deletion_frame_safety_in_attack_phase() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var h_dead = _create_lumber_hut()
	var h_alive = _create_lumber_hut()

	assert_eq(_get_wood(), 10, "Initial wood is 10")

	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "In ATTACK phase")

	# Destroy h_dead
	h_dead.take_damage(10.0)
	assert_true(h_dead.is_destroyed, "h_dead marked destroyed")

	# Transition immediately before frame processing flushes queue_free
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# h_alive produces 2 wood; h_dead produces 0
	assert_eq(_get_wood(), 12, "Immediate post-destruction produce yields only living hut wood (10 + 2 = 12)")

	# Wait for frame processing to ensure clean deletion flush
	await wait_frames(2)

	# Transition into Turn 2
	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Turn 2 PLAN")
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "Turn 2 ATTACK")
	event_bus_node.wave_ended.emit(2)
	assert_eq(_get_phase(), 2, "Turn 2 PRODUCE")

	# h_alive produces again (+2 wood = 14)
	assert_eq(_get_wood(), 14, "Turn 2 living hut produces wood after deletion flush (12 + 2 = 14)")

# ==============================================================================
# Section 3: Full Simulation & Rebuilding
# ==============================================================================

func test_challenge_grid_integrated_placement_attack_destruction_and_rebuilding() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	assert_not_null(grid_mgr, "GridManager must exist")
	assert_not_null(build_sys, "BuildSystem must exist")

	# Standard initial game resources: 3 AP, 10 wood
	assert_eq(_get_ap(), 3, "Initial AP is 3")
	assert_eq(_get_wood(), 10, "Initial wood is 10")

	var cell0 = Vector2i(1, 1)
	var cell1 = Vector2i(1, 2)
	var cell2 = Vector2i(1, 3)

	# Place 2 LumberHuts via BuildSystem (cost: 2 AP, 6 wood)
	var b0 = build_sys.place_building("lumber_hut", cell0)
	var b1 = build_sys.place_building("lumber_hut", cell1)

	assert_not_null(b0, "b0 placed")
	assert_not_null(b1, "b1 placed")

	_cleanup_nodes.append(b0)
	_cleanup_nodes.append(b1)

	# Remaining AP: 3 - 2 = 1. Remaining wood: 10 - 6 = 4.
	assert_eq(_get_ap(), 1, "AP is 1 after placing 2 huts")
	assert_eq(_get_wood(), 4, "Wood is 4 after placing 2 huts")
	assert_true(grid_mgr.is_cell_occupied(cell0), "cell0 occupied")
	assert_true(grid_mgr.is_cell_occupied(cell1), "cell1 occupied")

	# Transition to ATTACK phase
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "Now in ATTACK phase")

	# Destroy b0 in ATTACK phase
	b0.take_damage(10.0)
	assert_true(b0.is_destroyed, "b0 destroyed")

	# Verify GridManager vacated cell0, but cell1 remains occupied
	assert_false(grid_mgr.is_cell_occupied(cell0), "cell0 vacated by GridManager upon destruction")
	assert_true(grid_mgr.is_cell_occupied(cell1), "cell1 remains occupied")

	# Transition to PRODUCE phase
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# 1 surviving hut (b1) produces 2 wood (4 -> 6)
	assert_eq(_get_wood(), 6, "1 surviving hut produces +2 wood, destroyed b0 produces 0 (4 + 2 = 6)")

	# Conclude turn -> return to PLAN phase (Turn 2)
	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Returned to PLAN phase")
	assert_eq(_get_ap(), 3, "AP reset to max_ap (3)")

	# Player rebuilds on vacated cell0
	assert_true(build_sys.can_place_building("lumber_hut", cell0), "Can build on vacated cell0")
	var b_new = build_sys.place_building("lumber_hut", cell0)
	assert_not_null(b_new, "New LumberHut built successfully on vacated cell0")
	_cleanup_nodes.append(b_new)
	assert_true(grid_mgr.is_cell_occupied(cell0), "cell0 occupied once again")
	assert_eq(_get_ap(), 2, "AP deducted for new build (3 -> 2)")
	assert_eq(_get_wood(), 3, "Wood deducted for new build (6 -> 3)")

	# Player places another LumberHut on cell2
	var b2 = build_sys.place_building("lumber_hut", cell2)
	assert_not_null(b2, "b2 placed")
	_cleanup_nodes.append(b2)
	assert_eq(_get_ap(), 1, "AP deducted for 2nd build in Turn 2 (2 -> 1)")
	assert_eq(_get_wood(), 0, "Wood deducted for 2nd build in Turn 2 (3 -> 0)")

	# Complete Turn 2: all 3 huts (b1, b_new, b2) produce 6 wood
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(2)
	assert_eq(_get_phase(), 2, "Turn 2 in PRODUCE phase")
	assert_eq(_get_wood(), 6, "3 surviving huts produce 6 wood (0 + 6 = 6)")

	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Turn 3 back in PLAN")
	assert_eq(_get_ap(), 3, "Turn 3 AP reset to 3")

func test_challenge_multi_turn_dynamic_attrition_and_reconstruction() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# Initial 10 LumberHuts
	var huts: Array[Object] = []
	for i in range(10):
		huts.append(_create_lumber_hut())

	assert_eq(_get_wood(), 10, "Initial wood is 10")

	# Turn 1: All 10 survive -> +20 wood (10 -> 30)
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_wood(), 30, "Turn 1: 10 huts yield +20 wood (30 total)")
	game_state_node.advance_phase()
	assert_eq(_get_ap(), 3, "Turn 1 AP restored to 3")

	# Turn 2: In ATTACK, destroy huts 0 and 1 (8 survive) -> +16 wood (30 -> 46)
	game_state_node.trigger_end_action()
	huts[0].take_damage(10.0)
	huts[1].take_damage(10.0)
	event_bus_node.wave_ended.emit(2)
	assert_eq(_get_wood(), 46, "Turn 2: 8 huts yield +16 wood (46 total)")
	game_state_node.advance_phase()
	assert_eq(_get_ap(), 3, "Turn 2 AP restored to 3")

	# Turn 3: In ATTACK, destroy huts 2, 3, 4 (5 survive) -> +10 wood (46 -> 56)
	game_state_node.trigger_end_action()
	huts[2].take_damage(10.0)
	huts[3].take_damage(10.0)
	huts[4].take_damage(10.0)
	event_bus_node.wave_ended.emit(3)
	assert_eq(_get_wood(), 56, "Turn 3: 5 huts yield +10 wood (56 total)")
	game_state_node.advance_phase()
	assert_eq(_get_ap(), 3, "Turn 3 AP restored to 3")

	# Turn 4: In ATTACK, destroy huts 5, 6, 7, 8, 9 (0 survive) -> +0 wood (56 -> 56)
	game_state_node.trigger_end_action()
	for i in range(5, 10):
		huts[i].take_damage(10.0)
	event_bus_node.wave_ended.emit(4)
	assert_eq(_get_wood(), 56, "Turn 4: 0 huts yield +0 wood (wood remains 56)")
	game_state_node.advance_phase()
	assert_eq(_get_ap(), 3, "Turn 4 AP restored to 3")

	# Turn 5: Reconstruct 6 new LumberHuts in PLAN phase -> all 6 survive -> +12 wood (56 -> 68)
	var new_huts: Array[Object] = []
	for i in range(6):
		new_huts.append(_create_lumber_hut())
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(5)
	assert_eq(_get_wood(), 68, "Turn 5: 6 rebuilt huts yield +12 wood (68 total)")
	game_state_node.advance_phase()
	assert_eq(_get_ap(), 3, "Turn 5 AP restored to 3")

# ==============================================================================
# Section 4: Action Point (AP) Recovery & Dynamic Capacity Stress Testing
# ==============================================================================

func test_challenge_ap_recovery_multi_turn_stress() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# 10 turn loop stress-testing AP drain and recovery
	for turn in range(1, 11):
		assert_eq(_get_phase(), 0, "Turn %d in PLAN" % turn)
		assert_eq(_get_ap(), 3, "Turn %d starts with full AP (3)" % turn)

		var spend_amount = (turn % 3) + 1 # cycles 2, 3, 1, 2, 3...
		assert_true(game_state_node.spend_ap(spend_amount), "Turn %d spend %d AP" % [turn, spend_amount])
		assert_eq(_get_ap(), 3 - spend_amount, "Turn %d AP after spend" % turn)

		# ATTACK phase: AP must not change
		game_state_node.trigger_end_action()
		assert_eq(_get_phase(), 1, "Turn %d ATTACK" % turn)
		assert_eq(_get_ap(), 3 - spend_amount, "AP locked in ATTACK")

		# PRODUCE phase: AP must not change
		event_bus_node.wave_ended.emit(turn)
		assert_eq(_get_phase(), 2, "Turn %d PRODUCE" % turn)
		assert_eq(_get_ap(), 3 - spend_amount, "AP locked in PRODUCE")

		# Watch ap_changed signal when transitioning back to PLAN
		var ap_watcher = watch_signal(event_bus_node, "ap_changed")
		game_state_node.advance_phase()
		assert_eq(_get_phase(), 0, "Turn %d back to PLAN" % turn)
		assert_eq(_get_ap(), 3, "Turn %d AP reset to 3 upon entering PLAN" % turn)
		assert_true(ap_watcher.emitted, "ap_changed emitted on return to PLAN")
		if not ap_watcher.last_args.is_empty():
			assert_eq(int(ap_watcher.last_args[0]), 3, "ap_changed current arg is 3")
			assert_eq(int(ap_watcher.last_args[1]), 3, "ap_changed max arg is 3")

func test_challenge_ap_recovery_with_dynamic_building_bonuses() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	assert_eq(game_state_node.max_ap, 3, "Base max_ap is 3")

	# Create 3 mock building nodes with ap_bonus = 1 extending Building.gd
	var bonus_script = GDScript.new()
	bonus_script.source_code = "extends 'res://scripts/entities/Building.gd'\nvar ap_bonus: int = 1\n"
	bonus_script.reload()

	var b_bonus1 = bonus_script.new()
	var b_bonus2 = bonus_script.new()
	var b_bonus3 = bonus_script.new()
	_cleanup_nodes.append(b_bonus1)
	_cleanup_nodes.append(b_bonus2)
	_cleanup_nodes.append(b_bonus3)

	# Register all 3 bonus buildings
	game_state_node.register_building(b_bonus1)
	game_state_node.register_building(b_bonus2)
	game_state_node.register_building(b_bonus3)

	assert_eq(game_state_node.max_ap, 6, "max_ap raised to 3 + 3 = 6")

	# Enter PLAN phase: AP resets to new max_ap (6)
	game_state_node.reset_ap()
	assert_eq(_get_ap(), 6, "AP resets to 6 with 3 bonus buildings")

	# Spend 6 AP in PLAN
	assert_true(game_state_node.spend_ap(6), "Spend all 6 AP")
	assert_eq(_get_ap(), 0, "AP is 0")

	# Enter ATTACK
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "In ATTACK phase")

	# Destroy 2 of the 3 bonus buildings during ATTACK
	b_bonus1.destroy()
	b_bonus2.destroy()

	# max_ap dynamically updates to 3 + 1 = 4
	assert_eq(game_state_node.max_ap, 4, "max_ap dropped to 4 after destroying 2 bonus buildings")

	# Enter PRODUCE then back to PLAN
	event_bus_node.wave_ended.emit(1)
	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Back in PLAN")
	assert_eq(_get_ap(), 4, "AP resets to new max_ap (4)")

	# Destroy the final bonus building during next ATTACK
	game_state_node.trigger_end_action()
	b_bonus3.destroy()
	assert_eq(game_state_node.max_ap, 3, "max_ap reverted to Config.BASE_AP (3)")

	# Return to PLAN -> AP resets to 3
	event_bus_node.wave_ended.emit(2)
	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Back in PLAN")
	assert_eq(_get_ap(), 3, "AP fully restored to base 3")

func test_challenge_ap_boundary_resilience() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	# Corrupt AP to negative
	game_state_node.current_ap = -50
	assert_false(game_state_node.can_spend_ap(1), "can_spend_ap false when AP negative")
	game_state_node.reset_ap()
	assert_eq(_get_ap(), 3, "reset_ap() restores negative AP to max_ap (3)")

	# Corrupt AP to overflow
	game_state_node.current_ap = 999
	game_state_node.recalculate_max_ap()
	assert_eq(_get_ap(), 3, "recalculate_max_ap clamps overflow AP to max_ap (3)")

	# Spend bounds
	assert_false(game_state_node.spend_ap(4), "Cannot spend 4 AP when current is 3")
	assert_false(game_state_node.spend_ap(-1), "Cannot spend negative AP")
	assert_eq(_get_ap(), 3, "AP unchanged after invalid spend attempts")

func test_challenge_lumber_hut_config_override_multi_resource_payout() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# Create 5 LumberHuts with customized production payload (wood: 5, stone: 1)
	var huts: Array[Object] = []
	for i in range(5):
		var hut = _create_lumber_hut()
		hut.production = {"wood": 5, "stone": 1}
		huts.append(hut)

	assert_eq(game_state_node.resources["wood"], 10, "Initial wood 10")
	assert_eq(game_state_node.resources["stone"], 0, "Initial stone 0")

	# Enter ATTACK then PRODUCE
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# 5 huts * 5 wood = +25 wood (10 -> 35)
	# 5 huts * 1 stone = +5 stone (0 -> 5)
	assert_eq(game_state_node.resources["wood"], 35, "Custom multi-resource: wood is 10 + 25 = 35")
	assert_eq(game_state_node.resources["stone"], 5, "Custom multi-resource: stone is 0 + 5 = 5")
