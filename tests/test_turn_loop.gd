# res://tests/test_turn_loop.gd
# Requirement R3 Acceptance Test Suite:
# Verifies Turn Phase State Machine Loop (PLAN -> ATTACK -> PRODUCE -> PLAN),
# End Action Triggering, Wave Completion Transitions,
# Action Point (AP) Consumption and Restoration, and Multi-Turn Simulation.
extends "res://tests/test_base.gd"

## Wood every test in this suite starts with (see before_each).
const SEED_WOOD: int = 100

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
	# 1. Resolve Autoload Singletons from /root or script fallback
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

	# 2. Load Entity and Core Scripts
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
	# Ensure pristine game state before every test
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		if "current_phase" in game_state_node: game_state_node.current_phase = 0
		if "current_ap" in game_state_node: game_state_node.current_ap = 3
		if "max_ap" in game_state_node: game_state_node.max_ap = 3
		# Top up past Config's lean opening balance so these tests exercise the turn
		# loop rather than affordability.
		if "resources" in game_state_node: game_state_node.resources = {"wood": SEED_WOOD, "stone": SEED_WOOD, "water": SEED_WOOD, "food": 0}
		if "is_game_over" in game_state_node: game_state_node.is_game_over = false

func after_each() -> void:
	# Clean up any instantiated nodes from the test to prevent ObjectDB leaks
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			n.free()
	_cleanup_nodes.clear()

	# Disconnect all active signal watchers
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
# 2. Helpers & Factory Utilities
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

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

# ==============================================================================
# 3. Category 1: Turn Phase State Machine Loop Tests (R3.1)
# ==============================================================================

func test_initial_phase_is_plan() -> void:
	assert_not_null(game_state_node, "GameState autoload must exist")
	if game_state_node == null: return

	assert_eq(int(game_state_node.current_phase), 0, "Game must start in PLAN phase (0)")
	assert_eq(_get_ap(), 3, "Initial AP must equal Config.BASE_AP (3)")
	assert_eq(int(game_state_node.max_ap), 3, "Initial max_ap must be 3")
	assert_eq(_get_wood(), SEED_WOOD, "Wood starts at the seeded balance")
	assert_false(game_state_node.is_game_over, "is_game_over must initially be false")

func test_trigger_end_action_transitions_plan_to_attack() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")
	assert_eq(int(game_state_node.current_phase), 0, "Pre-condition: must be in PLAN phase")

	game_state_node.trigger_end_action()

	assert_eq(int(game_state_node.current_phase), 1, "trigger_end_action() must transition PLAN (0) -> ATTACK (1)")
	assert_true(phase_watcher.emitted, "phase_changed signal must be emitted")
	if not phase_watcher.last_args.is_empty():
		assert_eq(int(phase_watcher.last_args[0]), 1, "phase_changed signal argument must be 1 (ATTACK)")

func test_trigger_end_action_ignored_when_not_in_plan() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# 1. Transition into ATTACK
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "Now in ATTACK phase")

	# 2. Call trigger_end_action while in ATTACK
	var phase_watcher = watch_signal(event_bus_node, "phase_changed")
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "Phase must remain ATTACK (trigger_end_action ignored outside PLAN)")
	assert_false(phase_watcher.emitted, "phase_changed signal must NOT be emitted when action is ignored")

	# 3. Transition into PRODUCE and test rejection again
	event_bus_node.wave_ended.emit(1)
	assert_eq(int(game_state_node.current_phase), 2, "Now in PRODUCE phase")
	phase_watcher.emitted = false

	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 2, "Phase must remain PRODUCE (trigger_end_action ignored in PRODUCE)")
	assert_false(phase_watcher.emitted, "phase_changed signal must NOT be emitted in PRODUCE")

func test_wave_ended_transitions_attack_to_produce() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# Transition PLAN -> ATTACK
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "In ATTACK phase")

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Emit wave_ended signal
	event_bus_node.wave_ended.emit(1)

	assert_eq(int(game_state_node.current_phase), 2, "wave_ended must transition ATTACK (1) -> PRODUCE (2)")
	assert_true(phase_watcher.emitted, "phase_changed signal must be emitted upon wave_ended")
	if not phase_watcher.last_args.is_empty():
		assert_eq(int(phase_watcher.last_args[0]), 2, "phase_changed argument must be 2 (PRODUCE)")

func test_produce_phase_emits_produce_phase_signal() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 1, "In ATTACK phase")

	var produce_watcher = watch_signal(event_bus_node, "produce_phase")

	# Wave ends -> enters PRODUCE
	event_bus_node.wave_ended.emit(1)

	assert_eq(int(game_state_node.current_phase), 2, "In PRODUCE phase")
	assert_true(produce_watcher.emitted, "EventBus.produce_phase must be emitted when entering PRODUCE phase")
	assert_eq(produce_watcher.emit_count, 1, "EventBus.produce_phase must be emitted exactly once")

func test_transition_produce_to_plan_resets_ap() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# 1. Drain AP to 0 during PLAN
	assert_true(game_state_node.spend_ap(3), "spend_ap(3) should drain AP")
	assert_eq(_get_ap(), 0, "AP is now 0 in PLAN")

	# 2. Cycle to ATTACK then PRODUCE
	game_state_node.trigger_end_action()
	assert_eq(_get_ap(), 0, "AP remains 0 during ATTACK")
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_ap(), 0, "AP remains 0 during PRODUCE")

	# 3. Watch signals for PRODUCE -> PLAN transition
	var ap_watcher = watch_signal(event_bus_node, "ap_changed")
	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Advance from PRODUCE -> PLAN
	game_state_node.advance_phase()

	assert_eq(int(game_state_node.current_phase), 0, "advance_phase() must transition PRODUCE (2) -> PLAN (0)")
	assert_eq(_get_ap(), 3, "AP must be fully reset to max_ap (3) upon entering PLAN")
	assert_true(phase_watcher.emitted, "phase_changed emitted on return to PLAN")
	assert_true(ap_watcher.emitted, "ap_changed signal must be emitted on AP reset")
	if not ap_watcher.last_args.is_empty():
		assert_eq(int(ap_watcher.last_args[0]), 3, "ap_changed arg 0 (current_ap) must be 3")
		assert_eq(int(ap_watcher.last_args[1]), 3, "ap_changed arg 1 (max_ap) must be 3")

func test_advance_phase_full_cycle() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	# PLAN -> ATTACK
	assert_eq(int(game_state_node.current_phase), 0, "Starts in PLAN")
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 1, "advance_phase() from PLAN enters ATTACK")

	# ATTACK -> PRODUCE
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 2, "advance_phase() from ATTACK enters PRODUCE")

	# PRODUCE -> PLAN
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 0, "advance_phase() from PRODUCE enters PLAN")

func test_end_produce_phase_alias() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	# Test calling end_produce_phase while in PLAN (safe no-op)
	game_state_node.end_produce_phase()
	assert_eq(int(game_state_node.current_phase), 0, "end_produce_phase() ignored when in PLAN")

	# Navigate to PRODUCE
	game_state_node.set_phase(2)
	assert_eq(int(game_state_node.current_phase), 2, "In PRODUCE")

	# Drain AP to test reset
	game_state_node.current_ap = 0
	game_state_node.end_produce_phase()

	assert_eq(int(game_state_node.current_phase), 0, "end_produce_phase() transitions PRODUCE -> PLAN")
	assert_eq(_get_ap(), 3, "AP reset to max_ap")

func test_game_over_blocks_phase_transitions() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	game_state_node.is_game_over = true

	# Attempt trigger_end_action
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), 0, "trigger_end_action blocked when game_over is true")

	# Attempt advance_phase
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 0, "advance_phase blocked when game_over is true")

	# Attempt set_phase
	game_state_node.set_phase(1)
	assert_eq(int(game_state_node.current_phase), 0, "set_phase blocked when game_over is true")

# ==============================================================================
# 4. Category 2: Economy & Resource Production Tests (R3.2)
# ==============================================================================






func test_ap_spent_during_plan_restored_upon_returning_to_plan() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# Spend 1 AP, then 2 AP (total 3 AP spent, remaining = 0)
	assert_true(game_state_node.spend_ap(1), "Spend 1 AP succeeds")
	assert_eq(_get_ap(), 2, "AP is 2")
	assert_true(game_state_node.spend_ap(2), "Spend 2 AP succeeds")
	assert_eq(_get_ap(), 0, "AP is 0")

	# Enter ATTACK
	game_state_node.trigger_end_action()
	assert_eq(_get_ap(), 0, "AP must remain 0 during ATTACK")

	# Wave ends -> enters PRODUCE
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_ap(), 0, "AP must remain 0 during PRODUCE")

	# End produce -> return to PLAN
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 0, "Returned to PLAN")
	assert_eq(_get_ap(), 3, "AP fully restored to max_ap (3) upon returning to PLAN")

func test_ap_restoration_with_building_bonus() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	# Create a dummy building node with ap_bonus property
	var ap_building = Node.new()
	var scr = GDScript.new()
	scr.source_code = "extends Node\nvar ap_bonus: int = 1\n"
	scr.reload()
	ap_building.set_script(scr)
	_cleanup_nodes.append(ap_building)

	game_state_node.register_building(ap_building)
	assert_eq(int(game_state_node.max_ap), 4, "max_ap should increase to 4 with +1 AP building bonus")
	game_state_node.reset_ap()
	assert_eq(_get_ap(), 4, "AP refilled to upgraded max_ap (4)")

	# Spend all 4 AP
	assert_true(game_state_node.spend_ap(4), "Spend 4 AP succeeds")
	assert_eq(_get_ap(), 0, "AP is 0")

	# Cycle through ATTACK and PRODUCE to PLAN
	game_state_node.advance_phase() # ATTACK
	game_state_node.advance_phase() # PRODUCE
	game_state_node.advance_phase() # PLAN

	assert_eq(int(game_state_node.current_phase), 0, "Returned to PLAN")
	assert_eq(_get_ap(), 4, "AP restored to upgraded max_ap (4)")

func test_a_produce_phase_with_nothing_to_produce_pays_nothing() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	assert_eq(_get_wood(), SEED_WOOD, "Wood starts at the seeded balance")

	# v0.4: nothing produces resources any more -- the Hero's hands are the whole
	# economy -- so reaching PRODUCE must move no numbers at all.
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(1)

	assert_eq(int(game_state_node.current_phase), 2, "In PRODUCE phase")
	assert_eq(_get_wood(), SEED_WOOD, "Wood is unchanged when no LumberHuts exist")


# ==============================================================================
# 5. Category 3: Multi-Turn Simulation & Progression Tests (R3.3)
# ==============================================================================



func test_wave_3_big_wave_stat_buff_on_wave_ended() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# Initial multipliers
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.0, 0.01, "Initial dino HP mult is 1.0")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.0, 0.01, "Initial dino damage mult is 1.0")

	# Waves 1 and 2
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(1)
	game_state_node.advance_phase()

	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(2)
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.0, 0.01, "Wave 2: HP mult remains 1.0")
	game_state_node.advance_phase()

	# Wave 3 (Big Wave)
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(3)

	# Multipliers should be enhanced by Config.WAVES.enhance_after_big (1.3 HP, 1.2 Damage)
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.3, 0.01, "Wave 3: HP mult scaled to 1.3")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.2, 0.01, "Wave 3: Damage mult scaled to 1.2")
	assert_eq(int(game_state_node.current_phase), 2, "Transitioned to PRODUCE after big wave")


# ==============================================================================
# 6. Category 4: Hardening & Adversarial Edge Cases (R3.4)
# ==============================================================================

func test_rapid_trigger_end_action_debouncing() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")

	# Fire trigger_end_action 10 times consecutively
	for i in range(10):
		game_state_node.trigger_end_action()

	assert_eq(int(game_state_node.current_phase), 1, "Phase must transition to ATTACK (1)")
	assert_eq(phase_watcher.emit_count, 1, "phase_changed must be emitted exactly once despite 10 rapid calls")

func test_ap_reset_does_not_exceed_max_ap() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	# Reset when AP is already full
	game_state_node.reset_ap()
	assert_eq(_get_ap(), 3, "AP remains max_ap (3)")

	# Reset when AP is mutated to negative (invalid state recovery)
	game_state_node.current_ap = -5
	game_state_node.reset_ap()
	assert_eq(_get_ap(), 3, "AP recovers to max_ap (3)")


## Wood a single LumberHut pays out on the legacy produce_phase, from Config.
func _hut_yield() -> int:
	var cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg == null:
		return 0
	return int(cfg.BUILDINGS["lumber_hut"].get("produces", {}).get("wood", 0))
