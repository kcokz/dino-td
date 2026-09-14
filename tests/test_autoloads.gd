# res://tests/test_autoloads.gd
# Requirement R1 Acceptance Test Suite:
# Verifies initialization and contracts for Config, EventBus, and GameState Autoloads.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	# Try resolving autoload singletons from /root first
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	# Fallback: load directly from script paths if not registered in project.godot yet
	if config_node == null:
		var config_paths = ["res://scripts/autoload/Config.gd", "res://scripts/autoload/config.gd"]
		for p in config_paths:
			if ResourceLoader.exists(p):
				var res = load(p)
				if res != null:
					config_node = res.new()
					if config_node is Node:
						_cleanup_nodes.append(config_node)
					break

	if event_bus_node == null:
		var eb_paths = ["res://scripts/autoload/EventBus.gd", "res://scripts/autoload/event_bus.gd"]
		for p in eb_paths:
			if ResourceLoader.exists(p):
				var res = load(p)
				if res != null:
					event_bus_node = res.new()
					if event_bus_node is Node:
						_cleanup_nodes.append(event_bus_node)
					break

	if game_state_node == null:
		var gs_paths = ["res://scripts/autoload/GameState.gd", "res://scripts/autoload/game_state.gd"]
		for p in gs_paths:
			if ResourceLoader.exists(p):
				var res = load(p)
				if res != null:
					game_state_node = res.new()
					if game_state_node is Node:
						_cleanup_nodes.append(game_state_node)
					break

func after_all() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			n.free()
	_cleanup_nodes.clear()

# --- Helper Accessors ---

func _get_ap(state: Object) -> int:
	if "current_ap" in state:
		return state.current_ap
	if "ap" in state:
		return state.ap
	return -1

func _get_max_ap(state: Object) -> int:
	if "max_ap" in state:
		return state.max_ap
	if "ap_max" in state:
		return state.ap_max
	return -1

func _get_resources(state: Object) -> Dictionary:
	if "resources" in state and state.resources is Dictionary:
		return state.resources
	return {}

func _get_wave(state: Object) -> int:
	if "wave_number" in state:
		return state.wave_number
	if "wave_n" in state:
		return state.wave_n
	return -1

func _get_phase(state: Object) -> int:
	if "current_phase" in state:
		return state.current_phase
	return -1

# --- Test Cases ---

func test_autoload_config_exists() -> void:
	assert_not_null(config_node, "Autoload Config should be registered in /root/Config or exist in res://scripts/autoload/Config.gd")

func test_config_numerical_constants() -> void:
	if config_node == null:
		assert_true(false, "Config node missing; cannot verify constants")
		return

	assert_has(config_node, "BASE_AP", "Config must define BASE_AP")
	if "BASE_AP" in config_node:
		assert_eq(config_node.BASE_AP, 3, "Config.BASE_AP should equal 3")

	assert_has(config_node, "TILE_SIZE", "Config must define TILE_SIZE")
	if "TILE_SIZE" in config_node:
		assert_almost_eq(float(config_node.TILE_SIZE), 2.0, 0.001, "Config.TILE_SIZE should equal 2.0")

	assert_has(config_node, "RESOURCES", "Config must define RESOURCES")
	if "RESOURCES" in config_node:
		assert_has(config_node.RESOURCES, "wood", "RESOURCES should contain wood")
		assert_has(config_node.RESOURCES, "stone", "RESOURCES should contain stone")
		assert_has(config_node.RESOURCES, "food", "RESOURCES should contain food")

	assert_has(config_node, "INITIAL_RESOURCES", "Config must define INITIAL_RESOURCES")
	if "INITIAL_RESOURCES" in config_node:
		var init_res: Dictionary = config_node.INITIAL_RESOURCES
		assert_has(init_res, "wood", "INITIAL_RESOURCES should specify wood")
		assert_has(init_res, "stone", "INITIAL_RESOURCES should specify stone")
		assert_has(init_res, "food", "INITIAL_RESOURCES should specify food")

func test_config_buildings_catalog() -> void:
	if config_node == null:
		assert_true(false, "Config node missing; cannot verify BUILDINGS")
		return

	assert_has(config_node, "BUILDINGS", "Config must define BUILDINGS dictionary")
	if not ("BUILDINGS" in config_node):
		return

	var b: Dictionary = config_node.BUILDINGS
	assert_has(b, "core", "BUILDINGS must define 'core'")
	assert_has(b, "tower", "BUILDINGS must define 'tower'")
	assert_has(b, "wall", "BUILDINGS must define 'wall'")
	assert_has(b, "lumber_hut", "BUILDINGS must define 'lumber_hut'")

	if "core" in b:
		assert_eq(b["core"].get("kind", ""), "core", "core kind should be 'core'")
		assert_almost_eq(float(b["core"].get("hp", 0.0)), 10.0, 0.01, "core base hp should be 10.0")

	if "tower" in b:
		assert_eq(b["tower"].get("kind", ""), "tower", "tower kind should be 'tower'")
		assert_almost_eq(float(b["tower"].get("hp", 0.0)), 20.0, 0.01, "tower hp should be 20.0")
		assert_almost_eq(float(b["tower"].get("range", 0.0)), 5.0, 0.01, "tower range should be 5.0")
		assert_almost_eq(float(b["tower"].get("damage", 0.0)), 1.0, 0.01, "tower damage should be 1.0")
		assert_gt(b["tower"].get("cost", {}).get("wood", 0), 0, "tower must cost wood")

	if "wall" in b:
		assert_eq(b["wall"].get("kind", ""), "wall", "wall kind should be 'wall'")
		assert_almost_eq(float(b["wall"].get("hp", 0.0)), 30.0, 0.01, "wall hp should be 30.0")
		assert_gt(b["wall"].get("cost", {}).get("wood", 0), 0, "wall must cost wood")

	if "lumber_hut" in b:
		assert_eq(b["lumber_hut"].get("kind", ""), "producer", "lumber_hut kind should be 'producer'")
		assert_gt(b["lumber_hut"].get("cost", {}).get("wood", 0), 0, "lumber_hut must cost wood")
		assert_eq(b["lumber_hut"].get("produces", {}).get("wood", 0), 2, "lumber_hut produces 2 wood")

func test_config_dinos_and_waves() -> void:
	if config_node == null:
		assert_true(false, "Config node missing; cannot verify DINOS and WAVES")
		return

	assert_has(config_node, "DINOS", "Config must define DINOS")
	if "DINOS" in config_node:
		var d: Dictionary = config_node.DINOS
		assert_has(d, "raptor", "DINOS must define 'raptor'")
		if "raptor" in d:
			assert_almost_eq(float(d["raptor"].get("hp", 0.0)), 3.0, 0.01, "raptor hp should be 3.0")
			assert_almost_eq(float(d["raptor"].get("speed", 0.0)), 4.0, 0.01, "raptor speed should be 4.0")
			assert_almost_eq(float(d["raptor"].get("damage", 0.0)), 1.0, 0.01, "raptor damage should be 1.0")
			assert_eq(d["raptor"].get("targeting", ""), "blocker_then_core", "raptor targeting should be blocker_then_core")

	assert_has(config_node, "WAVES", "Config must define WAVES")
	if "WAVES" in config_node:
		var w: Dictionary = config_node.WAVES
		assert_eq(w.get("base_count", 0), 2, "wave base_count should be 2")
		assert_eq(w.get("count_per_wave", 0), 1, "wave count_per_wave should be 1")
		assert_eq(w.get("big_every", 0), 3, "wave big_every should be 3")
		assert_almost_eq(float(w.get("big_multiplier", 0.0)), 2.0, 0.01, "big_multiplier should be 2.0")
		assert_has(w, "enhance_after_big", "WAVES must define enhance_after_big")
		assert_almost_eq(float(w.get("spawn_interval", 0.0)), 0.8, 0.01, "spawn_interval should be 0.8")

	assert_has(config_node, "NEST", "Config must define NEST")
	if "NEST" in config_node:
		assert_almost_eq(float(config_node.NEST.get("hp", 0.0)), 30.0, 0.01, "NEST hp should be 30.0")

func test_autoload_eventbus_exists() -> void:
	assert_not_null(event_bus_node, "Autoload EventBus should be registered in /root/EventBus or exist in res://scripts/autoload/EventBus.gd")

func test_eventbus_signals_catalog() -> void:
	if event_bus_node == null:
		assert_true(false, "EventBus node missing; cannot verify signals")
		return

	var required_signals = [
		"phase_changed",
		"ap_changed",
		"resources_changed",
		"building_placed",
		"building_destroyed",
		"wave_started",
		"wave_ended",
		"produce_phase",
		"dino_spawned",
		"dino_died",
		"dino_reached_core",
		"nest_destroyed",
		"game_won",
		"game_lost",
		"core_hp_changed"
	]

	for sig in required_signals:
		assert_has_signal(event_bus_node, sig, "EventBus must declare signal '%s'" % sig)

func test_eventbus_signal_emission_and_reception() -> void:
	if event_bus_node == null:
		assert_true(false, "EventBus node missing; cannot test signal propagation")
		return

	if not event_bus_node.has_signal("phase_changed"):
		assert_true(false, "EventBus lacks phase_changed signal")
		return

	var watcher = watch_signal(event_bus_node, "phase_changed")
	event_bus_node.emit_signal("phase_changed", 1)

	assert_true(watcher.emitted, "phase_changed signal should be captured by watcher")
	assert_eq(watcher.last_args.size(), 1, "phase_changed should pass 1 argument")
	if not watcher.last_args.is_empty():
		assert_eq(watcher.last_args[0], 1, "phase argument should be 1")

func test_autoload_gamestate_exists() -> void:
	assert_not_null(game_state_node, "Autoload GameState should be registered in /root/GameState or exist in res://scripts/autoload/GameState.gd")

func test_gamestate_initial_values() -> void:
	if game_state_node == null:
		assert_true(false, "GameState node missing; cannot verify initial state")
		return

	var current_ap = _get_ap(game_state_node)
	var max_ap = _get_max_ap(game_state_node)
	var res = _get_resources(game_state_node)
	var phase = _get_phase(game_state_node)

	assert_eq(current_ap, 3, "Initial AP should equal 3 (Config.BASE_AP)")
	assert_eq(max_ap, 3, "Initial Max AP should equal 3 (Config.BASE_AP)")
	assert_eq(phase, 0, "Initial Phase should be PLAN (0)")
	assert_has(res, "wood", "GameState resources should have wood")

func test_gamestate_ap_spend_and_reset() -> void:
	if game_state_node == null:
		assert_true(false, "GameState node missing; cannot test AP mechanics")
		return

	if not game_state_node.has_method("spend_ap") or not game_state_node.has_method("reset_ap"):
		assert_true(false, "GameState missing spend_ap or reset_ap method")
		return

	# Reset state first
	if game_state_node.has_method("reset_game"):
		game_state_node.call("reset_game")
	else:
		game_state_node.call("reset_ap")

	var initial_ap = _get_ap(game_state_node)
	assert_eq(initial_ap, 3, "AP should be 3 before spend")

	# Spend 1 AP
	var spend_success = game_state_node.call("spend_ap", 1)
	assert_true(spend_success, "spend_ap(1) should succeed")
	assert_eq(_get_ap(game_state_node), 2, "AP should be 2 after spending 1")

	# Attempt spending more AP than available
	var overspend_success = game_state_node.call("spend_ap", 999)
	assert_false(overspend_success, "spend_ap(999) should return false")
	assert_eq(_get_ap(game_state_node), 2, "AP should remain 2 after failed overspend")

	# Reset AP
	game_state_node.call("reset_ap")
	assert_eq(_get_ap(game_state_node), 3, "reset_ap() should restore AP to max")

func test_gamestate_resources_spend_and_add() -> void:
	if game_state_node == null:
		assert_true(false, "GameState node missing; cannot test resource mechanics")
		return

	# Test resource check/spend
	var has_res_method = "can_afford" if game_state_node.has_method("can_afford") else "has_resources"
	if game_state_node.has_method(has_res_method):
		var can_afford_excess = game_state_node.call(has_res_method, {"wood": 999999})
		assert_false(can_afford_excess, "can_afford should return false for unaffordable cost")

	if game_state_node.has_method("spend_resources"):
		var spend_excess = game_state_node.call("spend_resources", {"wood": 999999})
		assert_false(spend_excess, "spend_resources should fail for unaffordable cost")

	if game_state_node.has_method("add_resources"):
		var pre_wood = _get_resources(game_state_node).get("wood", 0)
		game_state_node.call("add_resources", {"wood": 5})
		var post_wood = _get_resources(game_state_node).get("wood", 0)
		assert_eq(post_wood, pre_wood + 5, "add_resources should increase wood by 5")

func test_gamestate_ap_boundary_conditions() -> void:
	if game_state_node == null:
		assert_true(false, "GameState node missing; cannot test AP boundary conditions")
		return

	if not game_state_node.has_method("spend_ap") or not game_state_node.has_method("reset_ap"):
		assert_true(false, "GameState missing spend_ap or reset_ap method")
		return

	game_state_node.call("reset_ap")
	var initial_ap = _get_ap(game_state_node)

	# Spending 0 AP should succeed and not alter AP balance
	var spend_zero = game_state_node.call("spend_ap", 0)
	assert_true(spend_zero, "spend_ap(0) should return true")
	assert_eq(_get_ap(game_state_node), initial_ap, "spend_ap(0) should not change AP")

	# Spending negative AP should be rejected
	var spend_negative = game_state_node.call("spend_ap", -1)
	assert_false(spend_negative, "spend_ap(-1) should return false")
	assert_eq(_get_ap(game_state_node), initial_ap, "spend_ap(-1) should not change AP")

	# Drain all AP
	var spend_all = game_state_node.call("spend_ap", initial_ap)
	assert_true(spend_all, "spend_ap(initial_ap) should succeed")
	assert_eq(_get_ap(game_state_node), 0, "AP should be exactly 0 after draining")

	# Spending 1 AP when 0 AP left must fail
	var spend_empty = game_state_node.call("spend_ap", 1)
	assert_false(spend_empty, "spend_ap(1) with 0 AP must fail")
	assert_eq(_get_ap(game_state_node), 0, "AP must remain 0")

	# Reset restores full AP
	game_state_node.call("reset_ap")
	assert_eq(_get_ap(game_state_node), initial_ap, "reset_ap should restore to full max AP")

func test_gamestate_resources_boundary_conditions() -> void:
	if game_state_node == null:
		assert_true(false, "GameState node missing; cannot test resource boundaries")
		return

	var has_res_method = "can_afford" if game_state_node.has_method("can_afford") else "has_resources"
	if game_state_node.has_method(has_res_method):
		# Empty cost dictionary is always affordable
		var can_afford_empty = game_state_node.call(has_res_method, {})
		assert_true(can_afford_empty, "can_afford({}) should return true")

	if game_state_node.has_method("spend_resources"):
		# Empty cost deduction succeeds without changing balances
		var res_before = _get_resources(game_state_node).duplicate()
		var spend_empty = game_state_node.call("spend_resources", {})
		assert_true(spend_empty, "spend_resources({}) should return true")
		var res_after = _get_resources(game_state_node)
		for k in res_before.keys():
			assert_eq(res_after.get(k), res_before[k], "Resource %s should be unchanged after spending {}" % k)

func test_gamestate_turn_cycle_and_phase_transitions() -> void:
	if game_state_node == null or event_bus_node == null:
		assert_true(false, "GameState or EventBus missing; cannot test phase transitions")
		return

	if game_state_node.has_method("reset_game"):
		game_state_node.call("reset_game")

	var phase_watcher = watch_signal(event_bus_node, "phase_changed")
	var produce_watcher = watch_signal(event_bus_node, "produce_phase")

	assert_eq(_get_phase(game_state_node), 0, "Initial phase must be PLAN (0)")

	game_state_node.call("advance_phase")
	assert_eq(_get_phase(game_state_node), 1, "Phase should advance to ATTACK (1)")
	assert_true(phase_watcher.emitted, "phase_changed should emit on transition to ATTACK")
	if not phase_watcher.last_args.is_empty():
		assert_eq(phase_watcher.last_args[0], 1, "phase_changed should pass 1 for ATTACK")

	game_state_node.call("spend_ap", 1)
	assert_eq(_get_ap(game_state_node), 2, "AP should be 2 after spending 1 in ATTACK")

	phase_watcher.emitted = false
	game_state_node.call("advance_phase")
	assert_eq(_get_phase(game_state_node), 2, "Phase should advance to PRODUCE (2)")
	assert_true(phase_watcher.emitted, "phase_changed should emit on transition to PRODUCE")
	assert_true(produce_watcher.emitted, "produce_phase should emit on transition to PRODUCE")

	phase_watcher.emitted = false
	game_state_node.call("advance_phase")
	assert_eq(_get_phase(game_state_node), 0, "Phase should advance to PLAN (0)")
	assert_true(phase_watcher.emitted, "phase_changed should emit on transition to PLAN")
	assert_eq(_get_ap(game_state_node), _get_max_ap(game_state_node), "AP should reset to max on entering PLAN")

func test_gamestate_wave_scaling_after_big_wave() -> void:
	if game_state_node == null or event_bus_node == null:
		assert_true(false, "GameState or EventBus missing; cannot test wave scaling")
		return

	if game_state_node.has_method("reset_game"):
		game_state_node.call("reset_game")

	event_bus_node.emit_signal("wave_ended", 1)
	var mult_w1: Dictionary = game_state_node.get("dino_stat_multipliers")
	assert_almost_eq(float(mult_w1.get("hp", 0.0)), 1.0, 0.01, "Dino HP multiplier unchanged after wave 1")

	event_bus_node.emit_signal("wave_ended", 3)
	var mult_w3: Dictionary = game_state_node.get("dino_stat_multipliers")
	assert_almost_eq(float(mult_w3.get("hp", 0.0)), 1.3, 0.01, "Dino HP multiplier scaled by 1.3 after wave 3")
	assert_almost_eq(float(mult_w3.get("damage", 0.0)), 1.2, 0.01, "Dino damage multiplier scaled by 1.2 after wave 3")
	assert_almost_eq(float(mult_w3.get("speed", 0.0)), 1.0, 0.01, "Dino speed multiplier scaled by 1.0 after wave 3")

func test_gamestate_building_ap_bonus_lifecycle() -> void:
	if game_state_node == null or event_bus_node == null:
		assert_true(false, "GameState or EventBus missing; cannot test building lifecycle")
		return

	if game_state_node.has_method("reset_game"):
		game_state_node.call("reset_game")

	var initial_max_ap = _get_max_ap(game_state_node)
	assert_eq(initial_max_ap, 3, "Initial max AP should be 3")

	var mock_building = Node.new()
	var script = GDScript.new()
	script.source_code = "extends Node\nvar ap_bonus: int = 1\n"
	script.reload()
	mock_building.set_script(script)
	_cleanup_nodes.append(mock_building)

	event_bus_node.emit_signal("building_placed", mock_building)
	assert_eq(_get_max_ap(game_state_node), 4, "Max AP should increase to 4 when AP building is placed")

	event_bus_node.emit_signal("building_destroyed", mock_building)
	assert_eq(_get_max_ap(game_state_node), 3, "Max AP should return to 3 when AP building is destroyed")

func test_gamestate_win_and_loss_terminal_states() -> void:
	if game_state_node == null or event_bus_node == null:
		assert_true(false, "GameState or EventBus missing; cannot test win/loss")
		return

	if game_state_node.has_method("reset_game"):
		game_state_node.call("reset_game")

	assert_eq(game_state_node.get("is_game_over"), false, "is_game_over should initially be false")

	var dummy_nest = Node.new()
	_cleanup_nodes.append(dummy_nest)
	var win_watcher = watch_signal(event_bus_node, "game_won")
	event_bus_node.emit_signal("nest_destroyed", dummy_nest)

	assert_true(win_watcher.emitted, "game_won should be emitted when last nest is destroyed")
	assert_eq(game_state_node.get("is_game_over"), true, "is_game_over should be true after game won")

	game_state_node.call("reset_game")
	assert_eq(game_state_node.get("is_game_over"), false, "is_game_over should reset to false")

	event_bus_node.emit_signal("game_lost")
	assert_eq(game_state_node.get("is_game_over"), true, "is_game_over should be true after game lost")

