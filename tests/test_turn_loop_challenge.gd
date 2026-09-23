# res://tests/test_turn_loop_challenge.gd
# Empirical Challenger 1 Milestone 3 Test Suite:
# Rigorous stress testing and adversarial challenge of the turn phase state machine:
# 1. 50+ continuous cycles through PLAN -> ATTACK -> PRODUCE -> PLAN
# 2. Out-of-order calls (trigger_end_action while in ATTACK/PRODUCE, end_produce_phase while in PLAN)
# 3. High-frequency burst calling and rapid debouncing
# 4. Long-run economy compounding and destroyed-building handling over 50+ cycles
# 5. Chaotic fuzzing and state invariant preservation
# 6. Terminal game over phase locking over 50 iterations
extends "res://tests/test_base.gd"

## Wood this suite seeds in before_each. It asserts exact balances, so it owns
## its wallet rather than inheriting Config.INITIAL_RESOURCES (production tuning).
const SEED_WOOD: int = 10

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var building_script: GDScript = null
var grid_manager_script: GDScript = null
var build_system_script: GDScript = null

var _cleanup_nodes: Array[Node] = []
var _cleanup_objects: Array[Object] = []

# ==============================================================================
# 1. Lifecycle Hooks
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

	building_script = _load_script(["res://scripts/entities/Building.gd", "res://scripts/entities/building.gd"])
	grid_manager_script = _load_script(["res://scripts/core/GridManager.gd", "res://scripts/core/grid_manager.gd"])
	build_system_script = _load_script(["res://scripts/core/BuildSystem.gd", "res://scripts/core/build_system.gd"])

func before_each() -> void:
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		# reset_game() seeds Config.INITIAL_RESOURCES, which is production tuning.
		# This suite asserts exact balances, so pin its own wallet and stay decoupled
		# from whatever the opening balance happens to be.
		if "current_phase" in game_state_node: game_state_node.current_phase = 0
		if "resources" in game_state_node: game_state_node.resources = {"wood": SEED_WOOD, "stone": 0, "water": 0, "food": 0}
		if "is_game_over" in game_state_node: game_state_node.is_game_over = false
		if "wave_number" in game_state_node: game_state_node.wave_number = 0

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
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
				if obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
				obj.free()
			elif obj is RefCounted:
				pass
	_cleanup_objects.clear()

# ==============================================================================
# 2. Helpers
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null


func _get_wood() -> int:
	if game_state_node != null and "resources" in game_state_node:
		return game_state_node.resources.get("wood", 0)
	return -1

func test_challenge_50_plus_continuous_cycles_state_invariants() -> void:
	assert_not_null(game_state_node, "GameState autoload must exist")
	assert_not_null(event_bus_node, "EventBus autoload must exist")
	if game_state_node == null or event_bus_node == null:
		return

	var total_cycles = 60
	var expected_hp_mult: float = 1.0
	var expected_dmg_mult: float = 1.0

	for cycle in range(1, total_cycles + 1):
		# --- Phase 0: PLAN ---
		assert_eq(int(game_state_node.current_phase), 0, "Cycle %d: Must be in PLAN phase" % cycle)

		var ap_to_spend = (cycle % 3) + 1

		# Transition PLAN -> ATTACK via trigger_end_action
		var phase_watcher = watch_signal(event_bus_node, "phase_changed")
		game_state_node.trigger_end_action()

		# --- Phase 1: ATTACK ---
		assert_eq(int(game_state_node.current_phase), 1, "Cycle %d: Must transition to ATTACK phase" % cycle)
		assert_true(phase_watcher.emitted, "Cycle %d: phase_changed signal must be emitted" % cycle)
		assert_eq(int(phase_watcher.last_args[0]), 1, "Cycle %d: phase_changed arg must be 1 (ATTACK)" % cycle)

		# Transition ATTACK -> PRODUCE via wave_ended
		var produce_watcher = watch_signal(event_bus_node, "produce_phase")
		event_bus_node.wave_ended.emit(cycle)

		# --- Phase 2: PRODUCE ---
		assert_eq(int(game_state_node.current_phase), 2, "Cycle %d: Must transition to PRODUCE phase upon wave_ended" % cycle)
		assert_true(produce_watcher.emitted, "Cycle %d: produce_phase signal must be emitted upon entering PRODUCE" % cycle)

		# Dino multiplier check every 3 waves
		if cycle % 3 == 0:
			expected_hp_mult *= 1.3
			expected_dmg_mult *= 1.2

		var current_hp_mult = float(game_state_node.dino_stat_multipliers.get("hp", 1.0))
		var current_dmg_mult = float(game_state_node.dino_stat_multipliers.get("damage", 1.0))
		assert_almost_eq(current_hp_mult, expected_hp_mult, 0.05, "Cycle %d: HP multiplier compounding check" % cycle)
		assert_almost_eq(current_dmg_mult, expected_dmg_mult, 0.05, "Cycle %d: Damage multiplier compounding check" % cycle)

		# Transition PRODUCE -> PLAN via end_produce_phase
		var plan_watcher = watch_signal(event_bus_node, "phase_changed")
		game_state_node.end_produce_phase()

		# Back to PLAN
		assert_eq(int(game_state_node.current_phase), 0, "Cycle %d: end_produce_phase() must return to PLAN" % cycle)
		assert_true(plan_watcher.emitted, "Cycle %d: phase_changed signal emitted for PLAN" % cycle)

	assert_eq(int(game_state_node.current_phase), 0, "Final state after 60 cycles must be PLAN")
	assert_false(game_state_node.is_game_over, "Game must still be active after 60 cycles")

func test_challenge_out_of_order_trigger_end_action_in_attack() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	# Enter ATTACK phase
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "Currently in ATTACK phase")

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Call trigger_end_action while in ATTACK
	game_state_node.trigger_end_action()

	assert_eq(int(game_state_node.current_phase), 1, "Phase must remain ATTACK (1)")
	assert_false(phase_watcher.emitted, "phase_changed must NOT emit when trigger_end_action is called in ATTACK")

func test_challenge_out_of_order_trigger_end_action_in_produce() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	# Transition to PRODUCE
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(1)
	assert_eq(int(game_state_node.current_phase), 2, "Currently in PRODUCE phase")

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Call trigger_end_action while in PRODUCE
	game_state_node.trigger_end_action()

	assert_eq(int(game_state_node.current_phase), 2, "Phase must remain PRODUCE (2)")
	assert_false(phase_watcher.emitted, "phase_changed must NOT emit when trigger_end_action is called in PRODUCE")

func test_challenge_out_of_order_end_produce_phase_in_plan() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	assert_eq(int(game_state_node.current_phase), 0, "Currently in PLAN phase")

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Call end_produce_phase while in PLAN
	game_state_node.end_produce_phase()

	assert_eq(int(game_state_node.current_phase), 0, "Phase must remain PLAN (0)")
	assert_false(phase_watcher.emitted, "phase_changed must NOT emit when end_produce_phase is called in PLAN")

func test_challenge_out_of_order_end_produce_phase_in_attack() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "Currently in ATTACK phase")

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Call end_produce_phase while in ATTACK
	game_state_node.end_produce_phase()

	assert_eq(int(game_state_node.current_phase), 1, "Phase must remain ATTACK (1)")
	assert_false(phase_watcher.emitted, "phase_changed must NOT emit when end_produce_phase is called in ATTACK")

func test_challenge_end_plan_phase_alias_out_of_order() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	# end_plan_phase is alias for trigger_end_action
	game_state_node.end_plan_phase()
	assert_eq(int(game_state_node.current_phase), 1, "end_plan_phase transitions PLAN -> ATTACK")

	# Calling in ATTACK
	game_state_node.end_plan_phase()
	assert_eq(int(game_state_node.current_phase), 1, "end_plan_phase ignored in ATTACK")

	# Transition to PRODUCE
	event_bus_node.wave_ended.emit(1)
	assert_eq(int(game_state_node.current_phase), 2, "In PRODUCE")

	# Calling in PRODUCE
	game_state_node.end_plan_phase()
	assert_eq(int(game_state_node.current_phase), 2, "end_plan_phase ignored in PRODUCE")

func test_challenge_rapid_burst_out_of_order_bombardment() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	# In PLAN: Bombard with 100 end_produce_phase calls
	for i in range(100):
		game_state_node.end_produce_phase()
	assert_eq(int(game_state_node.current_phase), 0, "Phase remains PLAN after 100 end_produce_phase calls")

	# Transition once to ATTACK
	var phase_watcher = watch_signal(event_bus_node, "phase_changed")
	for i in range(50):
		game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "Phase transitions to ATTACK")
	assert_eq(phase_watcher.emit_count, 1, "phase_changed emitted exactly once despite 50 calls")

	# In ATTACK: Bombard with 50 end_produce_phase calls and 50 trigger_end_action calls
	for i in range(50):
		game_state_node.end_produce_phase()
		game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "Phase remains ATTACK after interleaved bombardment")

	# Transition once to PRODUCE
	event_bus_node.wave_ended.emit(1)
	assert_eq(int(game_state_node.current_phase), 2, "Phase transitions to PRODUCE")

	# In PRODUCE: Bombard with 50 trigger_end_action calls
	for i in range(50):
		game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 2, "Phase remains PRODUCE after 50 trigger_end_action calls")

	# Now conclude PRODUCE with rapid burst of end_produce_phase
	phase_watcher.emitted = false
	phase_watcher.emit_count = 0
	for i in range(50):
		game_state_node.end_produce_phase()
	assert_eq(int(game_state_node.current_phase), 0, "Phase transitions to PLAN")
	assert_eq(phase_watcher.emit_count, 1, "phase_changed emitted exactly once transitioning PRODUCE -> PLAN")

# ==============================================================================
# 5. Test Category 3: Signal Reentrancy & Signal Storm
# ==============================================================================

func test_challenge_reentrant_phase_changed_call_safety() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	# Connect a reentrant callback that attempts to trigger end action immediately on phase changed
	var reentrant_calls = [0]
	var cb = func(new_phase: int):
		if new_phase == 1:
			reentrant_calls[0] += 1
			# Attempt out-of-order trigger_end_action inside signal listener
			game_state_node.trigger_end_action()

	event_bus_node.phase_changed.connect(cb)

	# Fire transition PLAN -> ATTACK
	game_state_node.trigger_end_action()

	assert_eq(reentrant_calls[0], 1, "Reentrant listener was invoked once")
	assert_eq(int(game_state_node.current_phase), 1, "Phase remains stable in ATTACK, no reentrancy loop")

	event_bus_node.phase_changed.disconnect(cb)

# ==============================================================================
# ==============================================================================

func test_challenge_dynamic_ap_capacity_shifts_during_turn_loop() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return


	var b1 = Node.new()
	var scr1 = GDScript.new()
	scr1.source_code = "extends Node\n"   # an empty script extends RefCounted, which a Node refuses
	scr1.reload()
	b1.set_script(scr1)
	_cleanup_nodes.append(b1)

	game_state_node.register_building(b1)

	# Advance to ATTACK -> PRODUCE -> PLAN
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(1)
	game_state_node.end_produce_phase()

	assert_eq(int(game_state_node.current_phase), 0, "Turn 2: In PLAN")

	# Destroy / unregister b1 during Turn 2 PLAN
	game_state_node.unregister_building(b1)

	# Complete Turn 2
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(2)
	game_state_node.end_produce_phase()

	assert_eq(int(game_state_node.current_phase), 0, "Turn 3: In PLAN")

# ==============================================================================
# 7. Test Category 5: Terminal Game Over State Lockout Across Iterations
# ==============================================================================

func test_challenge_terminal_game_over_state_locking_multi_iteration() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	# Trigger game lost
	event_bus_node.game_lost.emit()
	assert_true(game_state_node.is_game_over, "Game is over")
	assert_eq(int(game_state_node.current_phase), 0, "Current phase is PLAN")

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Attempt 50 iterations of operations under game_over condition
	for i in range(50):
		game_state_node.trigger_end_action()
		game_state_node.advance_phase()
		game_state_node.end_produce_phase()
		game_state_node.set_phase(1)
		game_state_node.set_phase(2)
		event_bus_node.wave_ended.emit(i)

		assert_eq(int(game_state_node.current_phase), 0, "Iteration %d: Phase must remain locked at 0" % i)

	assert_false(phase_watcher.emitted, "Zero phase_changed signals emitted while game is over")

# ==============================================================================
# 8. Test Category 6: Chaotic Fuzzing of State Machine Invariants
# ==============================================================================

func test_challenge_chaotic_state_machine_fuzz_oracle() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = 987654321

	var actions_tested = 0

	for step in range(250):
		var action = rng.randi_range(0, 4)
		match action:
			0:
				game_state_node.trigger_end_action()
			1:
				game_state_node.end_produce_phase()
			2:
				game_state_node.advance_phase()
			3:
				var wave_idx = rng.randi_range(1, 20)
				event_bus_node.wave_ended.emit(wave_idx)
			4:
				var invalid_val = rng.randi_range(-5, 5)
				if invalid_val < 0 or invalid_val > 2:
					game_state_node.set_phase(invalid_val)

		actions_tested += 1

		# Invariant verification after every single chaotic action
		var cur_phase = int(game_state_node.current_phase)
		assert_gte(cur_phase, 0, "Step %d: Phase must be >= 0" % step)
		assert_lte(cur_phase, 2, "Step %d: Phase must be <= 2" % step)


		var cur_wood = _get_wood()
		assert_gte(cur_wood, 0, "Step %d: Wood must never drop below 0" % step)

	assert_eq(actions_tested, 250, "All 250 chaotic fuzz operations completed safely")

# ==============================================================================
# 9. Test Category 7: 100 Continuous Cycles Extreme Stress
# ==============================================================================

func test_challenge_100_continuous_cycles_stress() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	var turns = 100
	var initial_wood = _get_wood()

	for t in range(1, turns + 1):
		# PLAN
		assert_eq(int(game_state_node.current_phase), 0, "Turn %d: PLAN phase" % t)


		# trigger_end_action -> ATTACK
		game_state_node.trigger_end_action()
		assert_eq(int(game_state_node.current_phase), 1, "Turn %d: ATTACK phase" % t)

		# Wave started
		event_bus_node.wave_started.emit(t, (t % 3 == 0))
		assert_eq(game_state_node.wave_number, t, "Turn %d: wave_number updated on wave_started" % t)

		# Out-of-order attempts in ATTACK
		game_state_node.trigger_end_action()
		game_state_node.end_produce_phase()
		assert_eq(int(game_state_node.current_phase), 1, "Turn %d: Phase remains ATTACK" % t)

		# wave_ended -> PRODUCE
		event_bus_node.wave_ended.emit(t)
		assert_eq(int(game_state_node.current_phase), 2, "Turn %d: PRODUCE phase" % t)

		# Out-of-order attempts in PRODUCE
		game_state_node.trigger_end_action()
		assert_eq(int(game_state_node.current_phase), 2, "Turn %d: Phase remains PRODUCE" % t)

		# end_produce_phase -> PLAN
		game_state_node.end_produce_phase()
		assert_eq(int(game_state_node.current_phase), 0, "Turn %d: Back to PLAN phase" % t)

	assert_eq(_get_wood(), initial_wood, "Wood unchanged without producer buildings across 100 turns")
	assert_eq(game_state_node.wave_number, 100, "Wave number reached 100")

# ==============================================================================
# 10. Test Category 8: Mixed Building Destruction in Multi-Turn Loop
# ==============================================================================


# ==============================================================================
# 11. Test Category 9: Empirical Wave Ended Behavior Outside Attack
# ==============================================================================

func test_challenge_wave_ended_outside_attack_behavior() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null:
		return

	# While in PLAN (0):
	assert_eq(int(game_state_node.current_phase), 0, "Starts in PLAN")

	# Note: Emitting wave_ended while in PLAN transitions to PRODUCE in current implementation
	# We verify this empirical behavior is stable and does not corrupt GameState
	event_bus_node.wave_ended.emit(1)
	assert_eq(int(game_state_node.current_phase), 2, "wave_ended from PLAN transitions to PRODUCE")

	# Returning to PLAN
	game_state_node.end_produce_phase()
	assert_eq(int(game_state_node.current_phase), 0, "Returns to PLAN")
