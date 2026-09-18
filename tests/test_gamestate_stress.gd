# res://tests/test_gamestate_stress.gd
# Empirical Challenger 2nd-Order Adversarial Stress Test Suite for GameState
# Validates extreme edge cases: freed node pruning, negative bonuses, type corruption,
# compounding multipliers up to wave 30, phase state locking, and boundary enforcement.
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
# Stress 1: Building Batch Registration & Freed Node Garbage Pruning
# ==============================================================================
func test_stress_building_batch_lifecycle_and_freed_node_pruning() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()

	var buildings: Array[Node] = []
	for i in range(30):
		var b = Node.new()
		var scr = GDScript.new()
		scr.reload()
		b.set_script(scr)
		buildings.append(b)
		game_state.register_building(b)

	assert_eq(game_state.active_buildings.size(), 30, "active_buildings size must be 30")

	# Destroy / free 15 buildings directly without notifying GameState
	for i in range(15):
		var b = buildings[i]
		b.free()

	var new_b = Node.new()
	var new_scr = GDScript.new()
	new_scr.reload()
	new_b.set_script(new_scr)
	buildings.append(new_b)

	game_state.register_building(new_b)

	assert_eq(game_state.active_buildings.size(), 16, "Freed buildings must be pruned from active_buildings")

	# Clean up remaining living buildings
	for b in buildings:
		if is_instance_valid(b):
			b.free()
	game_state._prune_buildings()
	assert_eq(game_state.active_buildings.size(), 0, "active_buildings must be empty")

# ==============================================================================
# ==============================================================================

func test_stress_resource_non_numeric_and_complex_types() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()
	var initial_wood = game_state.resources.get("wood", 0)

	# Non-numeric cost values must be rejected by can_afford and spend_resources
	assert_false(game_state.can_afford({"wood": "10"}), "String cost must be rejected")
	assert_false(game_state.spend_resources({"wood": "10"}), "String cost spend must fail")

	assert_false(game_state.can_afford({"wood": null}), "Null cost must be rejected")
	assert_false(game_state.spend_resources({"wood": null}), "Null cost spend must fail")

	assert_false(game_state.can_afford({"wood": [1, 2]}), "Array cost must be rejected")
	assert_false(game_state.spend_resources({"wood": [1, 2]}), "Array cost spend must fail")

	assert_false(game_state.can_afford({"wood": {}}), "Dictionary cost must be rejected")
	assert_false(game_state.spend_resources({"wood": {}}), "Dictionary cost spend must fail")

	assert_false(game_state.can_afford({"wood": true}), "Boolean cost must be rejected")
	assert_false(game_state.spend_resources({"wood": true}), "Boolean cost spend must fail")

	assert_eq(game_state.resources.get("wood", 0), initial_wood, "Wood must remain unmodified")

	# Empty cost dictionary is valid (cost nothing)
	assert_true(game_state.can_afford({}), "Empty cost dictionary can_afford must return true")
	assert_true(game_state.spend_resources({}), "Empty cost dictionary spend_resources must return true")
	assert_eq(game_state.resources.get("wood", 0), initial_wood, "Wood remains unchanged after empty spend")

# ==============================================================================
# Stress 5: Resource Float Conversion and Exact Boundary Deduction
# ==============================================================================
func test_stress_resource_float_conversion_and_exact_deduction() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()
	# This test is about float-to-int truncation in the transaction, so pin the
	# wallet rather than inheriting whatever Config's opening balance is.
	game_state.resources = {"wood": 10, "stone": 0, "water": 0, "food": 0}

	assert_true(game_state.can_afford({"wood": 3.9}), "Float cost 3.9 can_afford should evaluate int(3.9)=3 <= 10")
	assert_true(game_state.spend_resources({"wood": 3.9}), "spend_resources with 3.9 should deduct 3")
	assert_eq(game_state.resources.get("wood", 0), 7, "Wood should be 10 - 3 = 7")

	# Spend remaining 7.0001
	assert_true(game_state.can_afford({"wood": 7.0001}), "Float cost 7.0001 can_afford should evaluate int(7.0001)=7 <= 7")
	assert_true(game_state.spend_resources({"wood": 7.0001}), "spend_resources with 7.0001 should deduct 7")
	assert_eq(game_state.resources.get("wood", 0), 0, "Wood should now be 0")

	# Deposit float resources
	game_state.add_resources({"wood": 6.8, "stone": 4.1})
	assert_eq(game_state.resources.get("wood", 0), 6, "Wood should increase by int(6.8)=6")
	assert_eq(game_state.resources.get("stone", 0), 4, "Stone should increase by int(4.1)=4")

# ==============================================================================
# Stress 6: Resource Addition Boundary Rejection (Negative, Unknown, Bad Types)
# ==============================================================================
func test_stress_resource_addition_boundary_rejection() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()

	var initial_wood = game_state.resources.get("wood", 0)

	# Adding negative amounts must be ignored
	game_state.add_resources({"wood": -5, "stone": -10})
	assert_eq(game_state.resources.get("wood", 0), initial_wood, "Wood must not change after negative addition")
	assert_eq(game_state.resources.get("stone", 0), 0, "Stone must remain 0")

	# Adding unregistered keys must be ignored
	game_state.add_resources({"mithril": 100, "diamonds": 50})
	assert_false(game_state.resources.has("mithril"), "Unregistered key 'mithril' must not be added to inventory")
	assert_false(game_state.resources.has("diamonds"), "Unregistered key 'diamonds' must not be added to inventory")

	# Adding invalid data types
	game_state.add_resources({"wood": "string_gain", "food": null})
	assert_eq(game_state.resources.get("wood", 0), initial_wood, "Wood must not change from string gain")
	assert_eq(game_state.resources.get("food", 0), 0, "Food must remain 0")

# ==============================================================================
# Stress 7: 30-Wave Compounding Multiplier Simulation & Numeric Stability
# ==============================================================================
func test_stress_multi_wave_compounding_to_wave_30() -> void:
	assert_not_null(game_state, "GameState must exist")
	assert_not_null(event_bus, "EventBus must exist")
	game_state.reset_game()

	var expected_hp: float = 1.0
	var expected_dmg: float = 1.0

	for wave in range(1, 31):
		# Start wave
		event_bus.emit_signal("wave_started", wave, (wave % 3 == 0))
		assert_eq(game_state.wave_number, wave, "wave_number must be %d" % wave)

		# End wave
		event_bus.emit_signal("wave_ended", wave)

		# After wave ends, phase must be PRODUCE (2)
		assert_eq(game_state.current_phase, 2, "Phase must advance to PRODUCE (2) after wave %d" % wave)

		if wave % 3 == 0:
			expected_hp *= 1.3
			expected_dmg *= 1.2

		var mults = game_state.dino_stat_multipliers
		assert_almost_eq(float(mults.get("hp", 0.0)), expected_hp, 0.005, "HP multiplier at wave %d must be ~%f" % [wave, expected_hp])
		assert_almost_eq(float(mults.get("damage", 0.0)), expected_dmg, 0.005, "Damage multiplier at wave %d must be ~%f" % [wave, expected_dmg])
		assert_almost_eq(float(mults.get("speed", 0.0)), 1.0, 0.001, "Speed multiplier at wave %d must remain 1.0" % wave)

		# Advance through PRODUCE -> PLAN
		game_state.end_produce_phase()
		assert_eq(game_state.current_phase, 0, "Phase should return to PLAN (0)")

# ==============================================================================
# Stress 8: Phase Out-of-Turn Action Blocking & Reentrancy Guards
# ==============================================================================
func test_stress_phase_out_of_turn_action_blocking() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()
	assert_eq(game_state.current_phase, 0, "Starts in PLAN (0)")

	# Calling end_produce_phase in PLAN should be blocked
	game_state.end_produce_phase()
	assert_eq(game_state.current_phase, 0, "end_produce_phase must do nothing in PLAN phase")

	# Advance to ATTACK
	game_state.trigger_end_action()
	assert_eq(game_state.current_phase, 1, "trigger_end_action transitions to ATTACK (1)")

	# In ATTACK phase:
	game_state.trigger_end_action()
	assert_eq(game_state.current_phase, 1, "trigger_end_action must do nothing in ATTACK phase")
	game_state.end_produce_phase()
	assert_eq(game_state.current_phase, 1, "end_produce_phase must do nothing in ATTACK phase")

	# Advance to PRODUCE
	game_state.advance_phase()
	assert_eq(game_state.current_phase, 2, "advance_phase transitions to PRODUCE (2)")

	# In PRODUCE phase:
	game_state.trigger_end_action()
	assert_eq(game_state.current_phase, 2, "trigger_end_action must do nothing in PRODUCE phase")

	# Conclude produce phase
	game_state.end_produce_phase()
	assert_eq(game_state.current_phase, 0, "end_produce_phase transitions to PLAN (0)")

# ==============================================================================
# Stress 9: Exhaustive Out-of-Range Phase Assignment Rejection
# ==============================================================================
func test_stress_invalid_phase_boundary_rejection_exhaustive() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()
	assert_eq(game_state.current_phase, 0, "Starts in PLAN (0)")

	var invalid_phases = [-999, -1, 3, 4, 10, 99, 2147483647]
	for bad_p in invalid_phases:
		game_state.set_phase(bad_p)
		assert_eq(game_state.current_phase, 0, "set_phase(%d) must be rejected" % bad_p)

		game_state.change_phase(bad_p)
		assert_eq(game_state.current_phase, 0, "change_phase(%d) must be rejected" % bad_p)

	# State machine remains healthy and can advance normally
	game_state.advance_phase()
	assert_eq(game_state.current_phase, 1, "advance_phase should advance to ATTACK (1) normally")

# ==============================================================================
# Stress 10: Exhaustive Game-Over Terminal Lockout
# ==============================================================================
func test_stress_game_over_terminal_lockout_exhaustive() -> void:
	assert_not_null(game_state, "GameState must exist")
	assert_not_null(event_bus, "EventBus must exist")
	game_state.reset_game()

	# Emit game_won
	event_bus.emit_signal("game_won")
	assert_true(game_state.is_game_over, "is_game_over is true")

	# Verify full mutation lockout

	game_state.set_phase(1)
	assert_eq(game_state.current_phase, 0, "set_phase must be blocked when game_over")

	game_state.advance_phase()
	assert_eq(game_state.current_phase, 0, "advance_phase must be blocked when game_over")

	game_state.trigger_end_action()
	assert_eq(game_state.current_phase, 0, "trigger_end_action must be blocked when game_over")

	game_state.end_produce_phase()
	assert_eq(game_state.current_phase, 0, "end_produce_phase must be blocked when game_over")

	var mult_before = game_state.dino_stat_multipliers.duplicate()
	event_bus.emit_signal("wave_ended", 3)
	assert_eq(game_state.current_phase, 0, "wave_ended must not advance phase when game_over")
	assert_eq(game_state.dino_stat_multipliers, mult_before, "wave_ended must not amplify multipliers when game_over")

	# Reset restores normal functionality
	game_state.reset_game()
	assert_false(game_state.is_game_over, "is_game_over reset to false")

	# Test same lockout under game_lost
	event_bus.emit_signal("game_lost")
	assert_true(game_state.is_game_over, "is_game_over is true under game_lost")
	game_state.advance_phase()
	assert_eq(game_state.current_phase, 0, "advance_phase blocked under game_lost")

# ==============================================================================
# Stress 11: Nest Destruction Counter and Clamping
# ==============================================================================
func test_stress_nest_destruction_edge_cases() -> void:
	assert_not_null(game_state, "GameState must exist")
	assert_not_null(event_bus, "EventBus must exist")
	game_state.reset_game()
	assert_eq(game_state.nests_alive, 1, "Initial nests_alive is 1")

	var won_watcher = watch_signal(event_bus, "game_won")

	# Destroy nest
	var dummy_nest = Node.new()
	event_bus.emit_signal("nest_destroyed", dummy_nest)
	dummy_nest.free()

	assert_eq(game_state.nests_alive, 0, "nests_alive should be 0")
	assert_true(game_state.is_game_over, "is_game_over must be true")
	assert_eq(won_watcher.emit_count, 1, "game_won signal emitted once")

	# Spurious second nest destruction
	event_bus.emit_signal("nest_destroyed", null)
	assert_eq(game_state.nests_alive, 0, "nests_alive clamped to 0, not negative")
	assert_eq(won_watcher.emit_count, 1, "game_won must NOT emit again")

# ==============================================================================
# Stress 12: Compatibility Property Aliases Bidirectional Consistency
# ==============================================================================
func test_stress_compatibility_property_aliases() -> void:
	assert_not_null(game_state, "GameState must exist")
	game_state.reset_game()

	# wave_n <-> wave_number
	game_state.wave_n = 15
	assert_eq(game_state.wave_number, 15, "setting wave_n must update wave_number")
	assert_eq(game_state.wave_n, 15, "getting wave_n must reflect wave_number")

	# dino_multipliers <-> dino_stat_multipliers
	var custom_mults = {"hp": 3.5, "damage": 2.5, "speed": 1.5}
	game_state.dino_multipliers = custom_mults
	assert_eq(game_state.dino_stat_multipliers, custom_mults, "setting dino_multipliers must update dino_stat_multipliers")
	assert_eq(game_state.dino_multipliers, custom_mults, "getting dino_multipliers must reflect dino_stat_multipliers")

	# has_resources alias
	assert_eq(game_state.has_resources({"wood": 5}), game_state.can_afford({"wood": 5}), "has_resources must match can_afford")
