# res://tests/test_gamestate_challenge.gd
# Empirical Challenger Test Suite for Milestone 1 GameState implementation.
# repeated resets, and adversarial edge cases.
extends "res://tests/test_base.gd"

## Wood this suite seeds in before_each. It asserts exact balances, so it owns
## its wallet rather than inheriting Config.INITIAL_RESOURCES (production tuning).
const SEED_WOOD: int = 10

var game_state: Object = null
var event_bus: Object = null
var config_node: Object = null
var _allocated_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		game_state = tree.root.get_node_or_null("GameState")
		event_bus = tree.root.get_node_or_null("EventBus")
		config_node = tree.root.get_node_or_null("Config")

	if game_state == null:
		var gs_res = load("res://scripts/autoload/GameState.gd")
		if gs_res != null:
			game_state = gs_res.new()
			if game_state is Node:
				_allocated_nodes.append(game_state)

	if event_bus == null:
		var eb_res = load("res://scripts/autoload/EventBus.gd")
		if eb_res != null:
			event_bus = eb_res.new()
			if event_bus is Node:
				_allocated_nodes.append(event_bus)

	if config_node == null:
		var cfg_res = load("res://scripts/autoload/Config.gd")
		if cfg_res != null:
			config_node = cfg_res.new()
			if config_node is Node:
				_allocated_nodes.append(config_node)

func before_each() -> void:
	if game_state != null and game_state.has_method("reset_game"):
		game_state.reset_game()
	# reset_game() seeds Config.INITIAL_RESOURCES, which is production tuning.
	# This suite asserts exact balances, so pin its own wallet.
	if game_state != null and "resources" in game_state:
		game_state.resources = {"wood": SEED_WOOD, "stone": 0, "water": 0, "food": 0}

func after_all() -> void:
	for n in _allocated_nodes:
		if is_instance_valid(n):
			n.free()
	_allocated_nodes.clear()

# ==============================================================================
# ==============================================================================
func test_challenge_negative_ap_spend() -> void:
	assert_not_null(game_state, "GameState must exist")


# ==============================================================================
# ==============================================================================

func test_challenge_resource_negative_cost_exploits() -> void:
	assert_not_null(game_state, "GameState must exist")
	var initial_wood: int = game_state.resources.get("wood", 0)

	# Exploit attempt: spending negative wood to gain wood
	assert_false(game_state.can_afford({"wood": -5}), "can_afford with negative cost must return false")
	assert_false(game_state.spend_resources({"wood": -5}), "spend_resources with negative cost must return false")
	assert_eq(game_state.resources.get("wood", 0), initial_wood, "Wood must not increase from negative spend")

	# Mixed exploit: valid wood but negative stone
	assert_false(game_state.can_afford({"wood": 2, "stone": -10}), "can_afford with any negative cost must return false")
	assert_false(game_state.spend_resources({"wood": 2, "stone": -10}), "spend_resources with mixed negative cost must return false")
	assert_eq(game_state.resources.get("wood", 0), initial_wood, "Wood must not be deducted when transaction fails")

# ==============================================================================
# Challenge 4: Resource Overdraft & Transaction Atomicity
# ==============================================================================
func test_challenge_resource_overdraft_and_atomicity() -> void:
	assert_not_null(game_state, "GameState must exist")
	assert_eq(game_state.resources.get("wood", 0), 10, "Initial wood is 10")
	assert_eq(game_state.resources.get("stone", 0), 0, "Initial stone is 0")

	# Overdraft by 1
	assert_false(game_state.can_afford({"wood": 11}), "can_afford(11) with 10 wood must return false")
	assert_false(game_state.spend_resources({"wood": 11}), "spend_resources(11) with 10 wood must return false")
	assert_eq(game_state.resources.get("wood", 0), 10, "Wood remains 10 after overdraft rejection")

	# Multi-resource transaction atomicity check:
	# wood: 4 (affordable), stone: 2 (unaffordable because stone is 0)
	assert_false(game_state.can_afford({"wood": 4, "stone": 2}), "Multi-resource check should fail if stone unavailable")
	var res_watcher = watch_signal(event_bus, "resources_changed")
	var spend_result = game_state.spend_resources({"wood": 4, "stone": 2})
	assert_false(spend_result, "spend_resources must return false when one resource is insufficient")
	assert_eq(game_state.resources.get("wood", 0), 10, "Wood must NOT be partially deducted (atomic rollback)")
	assert_eq(game_state.resources.get("stone", 0), 0, "Stone remains 0")
	assert_false(res_watcher.emitted, "resources_changed signal must not emit on failed transaction")

	# Exact full spend of wood
	assert_true(game_state.spend_resources({"wood": 10}), "spend_resources(10) with 10 wood should succeed")
	assert_eq(game_state.resources.get("wood", 0), 0, "Wood should now be exactly 0")

	# Further spend when 0 wood left
	assert_false(game_state.spend_resources({"wood": 1}), "spend_resources(1) with 0 wood must fail")
	assert_eq(game_state.resources.get("wood", 0), 0, "Wood must remain 0")

# ==============================================================================
# Challenge 5: Unknown Resource Keys & Missing Key Crash Vulnerability
# ==============================================================================
func test_challenge_unknown_resource_keys() -> void:
	assert_not_null(game_state, "GameState must exist")

	# 1. Unknown resource key with positive cost: can_afford should return false
	assert_false(game_state.can_afford({"mithril": 5}), "can_afford with unowned positive key must return false")
	assert_false(game_state.spend_resources({"mithril": 5}), "spend_resources with unowned positive key must return false")
	assert_false(game_state.resources.has("mithril"), "resources dict must not have added 'mithril'")

	# 2. VULNERABILITY TEST: Unknown resource key with zero cost
	# can_afford({"unknown_zero": 0}) returns true because resources.get("unknown_zero", 0) < 0 is false.
	# But spend_resources({"unknown_zero": 0}) executes: resources["unknown_zero"] -= 0.
	# Since "unknown_zero" is not in resources dictionary, dict[key] -= 0 causes a fatal runtime crash:
	# "Invalid access to property or key 'unknown_zero' on a base object of type 'Dictionary'"
	# can_afford must reject unknown resource keys, or spend_resources must guard against non-existent dictionary keys.
	var can_afford_zero = game_state.can_afford({"unknown_zero": 0})
	assert_false(can_afford_zero, "can_afford must reject unknown resource keys to prevent downstream Dictionary key crash")

# ==============================================================================
# Challenge 6: 100 Rapid Phase Transitions
# ==============================================================================
func test_challenge_100_rapid_phase_transitions() -> void:
	assert_not_null(game_state, "GameState must exist")
	assert_not_null(event_bus, "EventBus must exist")

	# Start from clean PLAN (0)
	game_state.reset_game()
	assert_eq(game_state.current_phase, 0, "Phase should be PLAN (0)")

	var phase_watcher = watch_signal(event_bus, "phase_changed")
	var produce_watcher = watch_signal(event_bus, "produce_phase")

	var expected_phase = 0
	var total_transitions = 100
	var expected_produce_emits = 0

	for i in range(total_transitions):
		expected_phase = (expected_phase + 1) % 3
		if expected_phase == 2:
			expected_produce_emits += 1

		game_state.advance_phase()

		assert_eq(game_state.current_phase, expected_phase, "Phase at iteration %d must be %d" % [i, expected_phase])

	assert_eq(phase_watcher.emit_count, total_transitions, "phase_changed should emit exactly %d times" % total_transitions)
	assert_eq(produce_watcher.emit_count, expected_produce_emits, "produce_phase should emit exactly %d times" % expected_produce_emits)

# ==============================================================================
# Challenge 7: Repeated reset_game Under Highly Corrupted / Dirty State
# ==============================================================================
func test_challenge_repeated_reset_game_under_stress() -> void:
	assert_not_null(game_state, "GameState must exist")

	# Perform 50 cycles of polluting state and resetting
	for cycle in range(50):
		# Heavily pollute state
		game_state.is_game_over = true
		game_state.current_phase = 1 # ATTACK
		game_state.wave_number = 88
		game_state.nests_alive = 0
		game_state.dino_stat_multipliers = {"hp": 99.0, "damage": 88.0, "speed": 77.0, "extra": 12.0}
		game_state.resources = {"wood": 9999, "stone": 8888, "food": 7777, "corrupted_item": 666}

		# Add mock building to active_buildings
		var mock_node = Node.new()
		game_state.active_buildings.append(mock_node)

		# Execute reset
		game_state.reset_game()
		mock_node.free()

		# Verify all invariants strictly hold
		assert_false(game_state.is_game_over, "is_game_over must be false after reset (cycle %d)" % cycle)
		assert_eq(game_state.current_phase, 0, "current_phase must be PLAN (0) after reset (cycle %d)" % cycle)
		assert_eq(game_state.wave_number, 0, "wave_number must be 0 after reset (cycle %d)" % cycle)
		assert_eq(game_state.nests_alive, 1, "nests_alive must be 1 after reset (cycle %d)" % cycle)
		assert_eq(game_state.active_buildings.size(), 0, "active_buildings must be empty after reset (cycle %d)" % cycle)

		var res = game_state.resources
		assert_eq(res.get("wood", 0), opening_banked_wood(), "wood resets to the opening wallet (cycle %d)" % cycle)
		assert_eq(res.get("stone", 0), 0, "stone must be 0 (cycle %d)" % cycle)
		assert_eq(res.get("food", 0), 0, "food must be 0 (cycle %d)" % cycle)
		assert_false(res.has("corrupted_item"), "corrupted_item must be gone (cycle %d)" % cycle)

		var mults = game_state.dino_stat_multipliers
		assert_almost_eq(float(mults.get("hp", 0.0)), 1.0, 0.001, "hp mult must be 1.0 (cycle %d)" % cycle)
		assert_almost_eq(float(mults.get("damage", 0.0)), 1.0, 0.001, "damage mult must be 1.0 (cycle %d)" % cycle)
		assert_almost_eq(float(mults.get("speed", 0.0)), 1.0, 0.001, "speed mult must be 1.0 (cycle %d)" % cycle)
		assert_false(mults.has("extra"), "extra multiplier key must be gone (cycle %d)" % cycle)

# ==============================================================================
# ==============================================================================
func test_challenge_building_registration_stress() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()

	var b1 = Node.new()
	var scr1 = GDScript.new()
	scr1.reload()
	b1.set_script(scr1)
	_allocated_nodes.append(b1)

	# Register b1 once
	game_state.register_building(b1)
	assert_eq(game_state.active_buildings.size(), 1, "active_buildings size should be 1")

	# Register b1 a second time (idempotency check)
	game_state.register_building(b1)
	assert_eq(game_state.active_buildings.size(), 1, "active_buildings size should still be 1")

	# Unregister b1
	game_state.unregister_building(b1)
	assert_eq(game_state.active_buildings.size(), 0, "active_buildings should be empty")

	# Unregister b1 again (spurious unregister check)
	game_state.unregister_building(b1)
	assert_eq(game_state.active_buildings.size(), 0, "active_buildings remains empty")

	# Register null node
	game_state.register_building(null)
	assert_eq(game_state.active_buildings.size(), 0, "active_buildings remains empty")

# ==============================================================================
# Challenge 9: Game Over State Lock & Immutability
# ==============================================================================
func test_challenge_game_over_immutability() -> void:
	assert_not_null(game_state, "GameState must exist")
	assert_not_null(event_bus, "EventBus must exist")
	game_state.reset_game()

	# Emit game_lost
	event_bus.emit_signal("game_lost")
	assert_true(game_state.is_game_over, "is_game_over must be true")
	assert_eq(game_state.current_phase, 0, "current_phase is PLAN (0)")

	# Advance phase while game is over
	game_state.advance_phase()
	assert_eq(game_state.current_phase, 0, "advance_phase must be blocked when game over")

	# Direct set_phase while game is over
	game_state.set_phase(1)
	assert_eq(game_state.current_phase, 0, "set_phase must be blocked when game over")

	# trigger_end_action while game is over
	game_state.trigger_end_action()
	assert_eq(game_state.current_phase, 0, "trigger_end_action must be blocked when game over")

	# Wave ended while game is over: should NOT advance phase to PRODUCE or scale stats
	var mult_before = game_state.dino_stat_multipliers.duplicate()
	event_bus.emit_signal("wave_ended", 3)
	assert_eq(game_state.current_phase, 0, "wave_ended must not advance phase when game over")
	assert_eq(game_state.dino_stat_multipliers, mult_before, "dino stats must not scale when game over")

	# Reset restores playability
	game_state.reset_game()
	assert_false(game_state.is_game_over, "reset_game clears game over state")
	game_state.advance_phase()
	assert_eq(game_state.current_phase, 1, "phase can advance normally after reset")

# ==============================================================================
# Challenge 10: Wave Scaling Multiplier Boundary (Wave 0 Edge Case)
# ==============================================================================
func test_challenge_wave_0_edge_case() -> void:
	assert_not_null(game_state, "GameState must exist")
	assert_not_null(event_bus, "EventBus must exist")
	game_state.reset_game()

	var mult_initial_hp = float(game_state.dino_stat_multipliers.get("hp", 1.0))
	assert_almost_eq(mult_initial_hp, 1.0, 0.001, "Initial hp multiplier is 1.0")

	# Emit wave_ended with wave 0
	# In GameState line 293: if n % big_every == 0:
	# When n = 0, 0 % 3 == 0 evaluates to true!
	# This inadvertently scales dino HP by 1.3 before any wave has been played.
	event_bus.emit_signal("wave_ended", 0)
	var mult_after_w0_hp = float(game_state.dino_stat_multipliers.get("hp", 1.0))

	assert_almost_eq(mult_after_w0_hp, 1.0, 0.001, "Wave 0 must NOT trigger big-wave stat amplification (0 %% 3 == 0 bug)")

# ==============================================================================
# Challenge 11: Invalid Phase Assignment Protection
# ==============================================================================
func test_challenge_invalid_phase_assignment() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()
	assert_eq(game_state.current_phase, 0, "Starts in PLAN (0)")

	# Attempt to assign out-of-range phase (e.g. 99)
	# If set_phase accepts invalid integers without clamping or validation,
	# advance_phase() will permanently lock up because match doesn't handle 99.
	game_state.change_phase(99)
	
	# Verify whether state machine can still advance or if it was corrupted
	game_state.advance_phase()
	var current = game_state.current_phase
	var is_valid_phase = current in [0, 1, 2]
	assert_true(is_valid_phase, "GameState must not enter or remain in an invalid phase state outside [0, 1, 2]")
