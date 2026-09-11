# res://tests/test_eventbus_challenge.gd
# Empirical Stress & Decoupling Challenge Test Suite for EventBus
# Tests multi-listener fanout, typed argument passing, disconnection, reentrancy, rapid stress, and decoupling purity.
extends "res://tests/test_base.gd"

var event_bus: Object = null
var _created_nodes: Array[Node] = []
var _cleanup_after_all: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		event_bus = tree.root.get_node_or_null("EventBus")
	if event_bus == null:
		var eb_path = "res://scripts/autoload/EventBus.gd"
		if ResourceLoader.exists(eb_path):
			var eb_class = load(eb_path)
			event_bus = eb_class.new()
			if event_bus is Node:
				_cleanup_after_all.append(event_bus)

func after_each() -> void:
	for n in _created_nodes:
		if is_instance_valid(n):
			n.free()
	_created_nodes.clear()

func after_all() -> void:
	for n in _cleanup_after_all:
		if is_instance_valid(n):
			n.free()
	_cleanup_after_all.clear()

func _create_temp_node(cls_type = Node) -> Node:
	var n = cls_type.new()
	_created_nodes.append(n)
	return n

# ==============================================================================
# Challenge 1: Verify All 15 Signals Exist with Exact Names and Signatures
# ==============================================================================
func test_challenge_1_all_15_signals_present_and_signatures() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var expected_signals = {
		"phase_changed": 1,
		"produce_phase": 0,
		"game_won": 0,
		"game_lost": 0,
		"ap_changed": 2,
		"resources_changed": 1,
		"building_placed": 1,
		"building_destroyed": 1,
		"core_hp_changed": 2,
		"wave_started": 2,
		"wave_ended": 1,
		"dino_spawned": 1,
		"dino_died": 1,
		"dino_reached_core": 1,
		"nest_destroyed": 1
	}

	var sig_list = event_bus.get_signal_list()
	var declared_signals: Dictionary = {}
	for s in sig_list:
		declared_signals[s["name"]] = s["args"].size()

	for sig_name in expected_signals.keys():
		assert_true(declared_signals.has(sig_name), "EventBus must declare signal '%s'" % sig_name)
		if declared_signals.has(sig_name):
			var expected_arg_count = expected_signals[sig_name]
			var actual_arg_count = declared_signals[sig_name]
			assert_eq(actual_arg_count, expected_arg_count,
				"Signal '%s' argument count mismatch. Expected %d, got %d" % [sig_name, expected_arg_count, actual_arg_count])

# ==============================================================================
# Challenge 2: Multi-Listener Fanout Across All 15 Signals
# ==============================================================================
func test_challenge_2_multi_listener_fanout_all_15_signals() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var dummy_node = _create_temp_node(Node3D)

	# Payload definition for all 15 signals
	var signal_payloads = {
		"phase_changed": [1],
		"produce_phase": [],
		"game_won": [],
		"game_lost": [],
		"ap_changed": [2, 3],
		"resources_changed": [{"wood": 12, "stone": 4}],
		"building_placed": [dummy_node],
		"building_destroyed": [dummy_node],
		"core_hp_changed": [8.5, 10.0],
		"wave_started": [3, true],
		"wave_ended": [3],
		"dino_spawned": [dummy_node],
		"dino_died": [dummy_node],
		"dino_reached_core": [dummy_node],
		"nest_destroyed": [dummy_node]
	}

	for sig_name in signal_payloads.keys():
		var payload = signal_payloads[sig_name]
		var listener_count = 5
		var received_counts: Array[int] = []
		var received_args: Array[Array] = []
		var callables: Array[Callable] = []

		for i in range(listener_count):
			received_counts.append(0)
			received_args.append([])
			var idx = i
			var cb = func(a = null, b = null, c = null):
				received_counts[idx] += 1
				var captured = []
				for val in [a, b, c]:
					if val != null:
						captured.append(val)
				received_args[idx] = captured

			callables.append(cb)
			event_bus.connect(sig_name, cb)

		# Emit signal with payload
		match payload.size():
			0:
				event_bus.emit_signal(sig_name)
			1:
				event_bus.emit_signal(sig_name, payload[0])
			2:
				event_bus.emit_signal(sig_name, payload[0], payload[1])

		# Verify all listeners received the signal exactly once
		for i in range(listener_count):
			assert_eq(received_counts[i], 1,
				"Listener %d for signal '%s' did not receive emission" % [i, sig_name])
			assert_eq(received_args[i].size(), payload.size(),
				"Listener %d for signal '%s' captured wrong argument count" % [i, sig_name])
			if payload.size() == 1:
				assert_eq(received_args[i][0], payload[0],
					"Listener %d for signal '%s' captured mismatched 1st arg" % [i, sig_name])
			elif payload.size() == 2:
				assert_eq(received_args[i][0], payload[0],
					"Listener %d for signal '%s' captured mismatched 1st arg" % [i, sig_name])
				assert_eq(received_args[i][1], payload[1],
					"Listener %d for signal '%s' captured mismatched 2nd arg" % [i, sig_name])

			# Clean up listener connection
			if event_bus.is_connected(sig_name, callables[i]):
				event_bus.disconnect(sig_name, callables[i])

# ==============================================================================
# Challenge 3: Diverse Typed Arguments and Value Extremes
# ==============================================================================
func test_challenge_3_diverse_typed_arguments() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	# Test 3.1: phase_changed integer boundary values
	var received_phases: Array[int] = []
	var phase_cb = func(p: int): received_phases.append(p)
	event_bus.connect("phase_changed", phase_cb)

	event_bus.emit_signal("phase_changed", 0)
	event_bus.emit_signal("phase_changed", 1)
	event_bus.emit_signal("phase_changed", 2)
	event_bus.emit_signal("phase_changed", -1)
	event_bus.emit_signal("phase_changed", 999999)

	assert_eq(received_phases.size(), 5, "All 5 phase values should be captured")
	assert_eq(received_phases[0], 0, "Phase 0 (PLAN)")
	assert_eq(received_phases[1], 1, "Phase 1 (ATTACK)")
	assert_eq(received_phases[2], 2, "Phase 2 (PRODUCE)")
	assert_eq(received_phases[3], -1, "Phase -1 (Boundary)")
	assert_eq(received_phases[4], 999999, "Phase 999999 (Extreme)")
	event_bus.disconnect("phase_changed", phase_cb)

	# Test 3.2: ap_changed integers
	var captured_ap: Array[Array] = []
	var ap_cb = func(cur: int, max_val: int): captured_ap.append([cur, max_val])
	event_bus.connect("ap_changed", ap_cb)
	event_bus.emit_signal("ap_changed", 0, 3)
	event_bus.emit_signal("ap_changed", 100, 100)
	event_bus.emit_signal("ap_changed", -5, 10)
	assert_eq(captured_ap.size(), 3, "3 ap_changed emissions expected")
	assert_eq(captured_ap[0], [0, 3], "AP (0, 3) captured")
	assert_eq(captured_ap[1], [100, 100], "AP (100, 100) captured")
	assert_eq(captured_ap[2], [-5, 10], "AP (-5, 10) captured")
	event_bus.disconnect("ap_changed", ap_cb)

	# Test 3.3: resources_changed dictionary types and structures
	var captured_res: Array[Dictionary] = []
	var res_cb = func(res: Dictionary): captured_res.append(res)
	event_bus.connect("resources_changed", res_cb)
	event_bus.emit_signal("resources_changed", {})
	event_bus.emit_signal("resources_changed", {"wood": 10, "stone": 0, "food": 0})
	event_bus.emit_signal("resources_changed", {"wood": -99, "metadata": {"level": 1, "rates": [1.0, 2.5]}})
	assert_eq(captured_res.size(), 3, "3 resources_changed emissions expected")
	assert_eq(captured_res[0], {}, "Empty dict handled cleanly")
	assert_eq(captured_res[1]["wood"], 10, "Wood value captured")
	assert_eq(captured_res[2]["metadata"]["rates"][1], 2.5, "Nested dictionary/array handled cleanly")
	event_bus.disconnect("resources_changed", res_cb)

	# Test 3.4: core_hp_changed floats
	var captured_hp: Array[Array] = []
	var hp_cb = func(cur: float, max_val: float): captured_hp.append([cur, max_val])
	event_bus.connect("core_hp_changed", hp_cb)
	event_bus.emit_signal("core_hp_changed", 10.0, 10.0)
	event_bus.emit_signal("core_hp_changed", 0.0, 10.0)
	event_bus.emit_signal("core_hp_changed", -1.5, 10.0)
	event_bus.emit_signal("core_hp_changed", 9999.75, 10000.0)
	assert_eq(captured_hp.size(), 4, "4 core_hp_changed emissions expected")
	assert_almost_eq(captured_hp[0][0], 10.0, 0.001, "Full HP 10.0")
	assert_almost_eq(captured_hp[1][0], 0.0, 0.001, "Zero HP 0.0")
	assert_almost_eq(captured_hp[2][0], -1.5, 0.001, "Negative HP -1.5")
	assert_almost_eq(captured_hp[3][0], 9999.75, 0.001, "High HP float")
	event_bus.disconnect("core_hp_changed", hp_cb)

	# Test 3.5: wave_started (int, bool)
	var captured_wave: Array[Array] = []
	var wave_cb = func(n: int, big: bool): captured_wave.append([n, big])
	event_bus.connect("wave_started", wave_cb)
	event_bus.emit_signal("wave_started", 1, false)
	event_bus.emit_signal("wave_started", 3, true)
	event_bus.emit_signal("wave_started", 6, true)
	event_bus.emit_signal("wave_started", 7, false)
	assert_eq(captured_wave.size(), 4, "4 wave_started emissions expected")
	assert_eq(captured_wave[0], [1, false], "Wave 1 not big")
	assert_eq(captured_wave[1], [3, true], "Wave 3 is big")
	assert_eq(captured_wave[2], [6, true], "Wave 6 is big")
	assert_eq(captured_wave[3], [7, false], "Wave 7 not big")
	event_bus.disconnect("wave_started", wave_cb)

	# Test 3.6: Node-derived instances passed to entity signals
	var base_node = _create_temp_node(Node)
	var node3d = _create_temp_node(Node3D)
	var captured_nodes: Array[Node] = []
	var node_cb = func(nd: Node): captured_nodes.append(nd)
	event_bus.connect("building_placed", node_cb)
	event_bus.emit_signal("building_placed", base_node)
	event_bus.emit_signal("building_placed", node3d)
	assert_eq(captured_nodes.size(), 2, "2 nodes captured")
	assert_eq(captured_nodes[0], base_node, "Base node captured")
	assert_eq(captured_nodes[1], node3d, "Node3D captured")
	event_bus.disconnect("building_placed", node_cb)

# ==============================================================================
# Challenge 4: Null Argument Safety for Node-Typed Signals
# ==============================================================================
func test_challenge_4_null_node_safety() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var captured_null: Array = []
	var cb = func(entity: Node): captured_null.append(entity)
	event_bus.connect("dino_died", cb)

	# Emitting null for Node parameter must not crash engine
	event_bus.emit_signal("dino_died", null)

	assert_eq(captured_null.size(), 1, "dino_died should receive emission with null")
	assert_null(captured_null[0], "Captured value should be null without runtime crash")
	event_bus.disconnect("dino_died", cb)

# ==============================================================================
# Challenge 5: Disconnection and Listener Isolation
# ==============================================================================
func test_challenge_5_disconnection_and_listener_isolation() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var counts = {"a": 0, "b": 0, "c": 0}

	var cb_a = func(_n: int): counts["a"] += 1
	var cb_b = func(_n: int): counts["b"] += 1
	var cb_c = func(_n: int): counts["c"] += 1

	event_bus.connect("wave_ended", cb_a)
	event_bus.connect("wave_ended", cb_b)
	event_bus.connect("wave_ended", cb_c)

	# Round 1: All 3 connected
	event_bus.emit_signal("wave_ended", 1)
	assert_eq(counts["a"], 1, "Listener A received Round 1")
	assert_eq(counts["b"], 1, "Listener B received Round 1")
	assert_eq(counts["c"], 1, "Listener C received Round 1")

	# Round 2: Disconnect B
	event_bus.disconnect("wave_ended", cb_b)
	assert_true(event_bus.is_connected("wave_ended", cb_a), "Listener A still connected")
	assert_false(event_bus.is_connected("wave_ended", cb_b), "Listener B disconnected")
	assert_true(event_bus.is_connected("wave_ended", cb_c), "Listener C still connected")

	event_bus.emit_signal("wave_ended", 2)
	assert_eq(counts["a"], 2, "Listener A received Round 2")
	assert_eq(counts["b"], 1, "Listener B did NOT receive Round 2")
	assert_eq(counts["c"], 2, "Listener C received Round 2")

	# Round 3: Disconnect remaining A and C
	event_bus.disconnect("wave_ended", cb_a)
	event_bus.disconnect("wave_ended", cb_c)

	event_bus.emit_signal("wave_ended", 3)
	assert_eq(counts["a"], 2, "Listener A did NOT receive Round 3")
	assert_eq(counts["b"], 1, "Listener B did NOT receive Round 3")
	assert_eq(counts["c"], 2, "Listener C did NOT receive Round 3")

# ==============================================================================
# Challenge 6: Self-Disconnection During Signal Callback
# ==============================================================================
func test_challenge_6_self_disconnection_during_callback() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var holder: Dictionary = {"call_count": 0, "cb": null}

	holder["cb"] = func(_n: int, _b: bool):
		holder["call_count"] += 1
		if event_bus.is_connected("wave_started", holder["cb"]):
			event_bus.disconnect("wave_started", holder["cb"])

	event_bus.connect("wave_started", holder["cb"])

	# First emission triggers callback and self-disconnects
	event_bus.emit_signal("wave_started", 1, false)
	assert_eq(holder["call_count"], 1, "Callback executed on first emission")
	assert_false(event_bus.is_connected("wave_started", holder["cb"]), "Callback should now be disconnected")

	# Second emission should not trigger callback
	event_bus.emit_signal("wave_started", 2, false)
	assert_eq(holder["call_count"], 1, "Callback should not execute on second emission after self-disconnect")

# ==============================================================================
# Challenge 7: Reentrant Cascading Signals
# ==============================================================================
func test_challenge_7_reentrant_cascading_signals() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var sequence: Array[String] = []

	# Setup a chain: phase_changed(2) -> produce_phase() -> resources_changed()
	var on_phase_changed = func(phase: int):
		sequence.append("phase_%d" % phase)
		if phase == 2:
			event_bus.emit_signal("produce_phase")

	var on_produce = func():
		sequence.append("produce")
		event_bus.emit_signal("resources_changed", {"wood": 5})

	var on_resources = func(res: Dictionary):
		sequence.append("resources_%d" % res.get("wood", 0))

	event_bus.connect("phase_changed", on_phase_changed)
	event_bus.connect("produce_phase", on_produce)
	event_bus.connect("resources_changed", on_resources)

	# Trigger initial signal
	event_bus.emit_signal("phase_changed", 2)

	assert_eq(sequence.size(), 3, "All 3 cascading signals should have executed")
	assert_eq(sequence[0], "phase_2", "First was phase_changed(2)")
	assert_eq(sequence[1], "produce", "Second was produce_phase")
	assert_eq(sequence[2], "resources_5", "Third was resources_changed(5)")

	event_bus.disconnect("phase_changed", on_phase_changed)
	event_bus.disconnect("produce_phase", on_produce)
	event_bus.disconnect("resources_changed", on_resources)

# ==============================================================================
# Challenge 8: High-Frequency Rapid Stress Test
# ==============================================================================
func test_challenge_8_rapid_stress_throughput() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var tracker = {
		"count1": 0,
		"count2": 0,
		"last_val1": -1,
		"last_val2": -1
	}

	var cb1 = func(cur: int, _max_val: int):
		tracker["count1"] += 1
		tracker["last_val1"] = cur

	var cb2 = func(cur: int, _max_val: int):
		tracker["count2"] += 1
		tracker["last_val2"] = cur

	event_bus.connect("ap_changed", cb1)
	event_bus.connect("ap_changed", cb2)

	var iterations = 2000
	var start_ms = Time.get_ticks_msec()

	for i in range(iterations):
		event_bus.emit_signal("ap_changed", i, 3)

	var elapsed_ms = Time.get_ticks_msec() - start_ms

	assert_eq(tracker["count1"], iterations, "Listener 1 received all 2000 emissions")
	assert_eq(tracker["count2"], iterations, "Listener 2 received all 2000 emissions")
	assert_eq(tracker["last_val1"], iterations - 1, "Listener 1 final value is 1999")
	assert_eq(tracker["last_val2"], iterations - 1, "Listener 2 final value is 1999")
	assert_lt(elapsed_ms, 500, "2000 multi-listener emissions completed rapidly (<500ms, actual: %d ms)" % elapsed_ms)

	event_bus.disconnect("ap_changed", cb1)
	event_bus.disconnect("ap_changed", cb2)

# ==============================================================================
# Challenge 9: Freed Node Listener Resilience
# ==============================================================================
func test_challenge_9_freed_node_listener_resilience() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	# Create a dummy Node that has a method
	var victim_node = Node.new()
	var script = GDScript.new()
	script.source_code = "extends Node\nvar received: bool = false\nfunc on_event(p: int) -> void: received = true\n"
	script.reload()
	victim_node.set_script(script)

	var survivor_data = {"count": 0}
	var survivor_cb = func(_p: int): survivor_data["count"] += 1

	event_bus.connect("phase_changed", Callable(victim_node, "on_event"))
	event_bus.connect("phase_changed", survivor_cb)

	# Initial emission: both receive
	event_bus.emit_signal("phase_changed", 1)
	assert_eq(victim_node.get("received"), true, "Victim node received signal before destruction")
	assert_eq(survivor_data["count"], 1, "Survivor listener received first signal")

	# Destroy the victim node immediately
	victim_node.set_script(null)
	victim_node.free()
	script = null

	# Emit signal again: engine must not crash or fail; survivor must still receive
	event_bus.emit_signal("phase_changed", 2)
	assert_eq(survivor_data["count"], 2, "Survivor listener cleanly received signal after peer node was freed")

	event_bus.disconnect("phase_changed", survivor_cb)

# ==============================================================================
# Challenge 10: Decoupling and Architectural Purity
# ==============================================================================
func test_challenge_10_decoupling_purity() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	# EventBus must not declare any state variables
	var prop_list = event_bus.get_property_list()
	var custom_properties: Array[String] = []
	for p in prop_list:
		var usage = p["usage"]
		# PROPERTY_USAGE_SCRIPT_VARIABLE = 8192
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			custom_properties.append(p["name"])

	assert_eq(custom_properties.size(), 0,
		"EventBus must have ZERO state variables (found: %s)" % str(custom_properties))

	# EventBus source code inspection: zero hardcoded singleton references in executable code
	var script = event_bus.get_script()
	assert_not_null(script, "EventBus script should be loaded")
	if script != null:
		var code: String = script.source_code
		var non_comment_lines: Array[String] = []
		for line in code.split("\n"):
			var trimmed = line.strip_edges()
			if not trimmed.begins_with("#"):
				non_comment_lines.append(trimmed)
		var code_only: String = "\n".join(non_comment_lines)

		assert_false(code_only.contains("GameState"), "EventBus must not couple directly to GameState")
		assert_false(code_only.contains("Config."), "EventBus must not couple directly to Config")
		assert_false(code_only.contains("Main."), "EventBus must not couple directly to Main")
		assert_false(code_only.contains("GridManager"), "EventBus must not couple directly to GridManager")
		assert_false(code_only.contains("BuildSystem"), "EventBus must not couple directly to BuildSystem")
		assert_false(code_only.contains("WaveManager"), "EventBus must not couple directly to WaveManager")

# ==============================================================================
# Challenge 11: Cross-Listener Disconnection During Emission (Mutation Safety)
# ==============================================================================
func test_challenge_11_cross_listener_disconnection_during_emission() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var exec_order: Array[String] = []
	var holder = {"cb2": null}

	var cb1 = func(_p: int):
		exec_order.append("cb1")
		if holder["cb2"] != null and event_bus.is_connected("phase_changed", holder["cb2"]):
			event_bus.disconnect("phase_changed", holder["cb2"])

	holder["cb2"] = func(_p: int):
		exec_order.append("cb2")

	var cb3 = func(_p: int):
		exec_order.append("cb3")

	event_bus.connect("phase_changed", cb1)
	event_bus.connect("phase_changed", holder["cb2"])
	event_bus.connect("phase_changed", cb3)

	# Emission where cb1 disconnects cb2 mid-flight
	event_bus.emit_signal("phase_changed", 0)

	assert_has(exec_order, "cb1", "cb1 must have executed")
	assert_has(exec_order, "cb3", "cb3 must have executed")
	assert_false(event_bus.is_connected("phase_changed", holder["cb2"]), "cb2 must now be disconnected")

	# Second emission: only cb1 and cb3 run
	exec_order.clear()
	event_bus.emit_signal("phase_changed", 1)
	assert_eq(exec_order.size(), 2, "Exactly 2 listeners executed after mid-flight disconnect")
	assert_eq(exec_order[0], "cb1", "cb1 ran in 2nd emission")
	assert_eq(exec_order[1], "cb3", "cb3 ran in 2nd emission")

	event_bus.disconnect("phase_changed", cb1)
	event_bus.disconnect("phase_changed", cb3)

# ==============================================================================
# Challenge 12: Extreme Stress 10,000 Rapid Emissions Fanout
# ==============================================================================
func test_challenge_12_extreme_stress_10000_emissions() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var counters = [0, 0, 0, 0, 0]
	var callables: Array[Callable] = []

	for i in range(5):
		var idx = i
		var cb = func(_cur: float, _max_v: float):
			counters[idx] += 1
		callables.append(cb)
		event_bus.connect("core_hp_changed", cb)

	var iterations = 10000
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		event_bus.emit_signal("core_hp_changed", float(i), 10000.0)

	var total_time = Time.get_ticks_msec() - start_time

	for i in range(5):
		assert_eq(counters[i], iterations,
			"Listener %d must have received all %d emissions under extreme stress" % [i, iterations])

	assert_lt(total_time, 2000,
		"10,000 emissions across 5 listeners finished in <2000ms (actual: %d ms)" % total_time)

	for cb in callables:
		event_bus.disconnect("core_hp_changed", cb)

# ==============================================================================
# Challenge 13: Duplicate Connection Guard and Signal Reflection
# ==============================================================================
func test_challenge_13_duplicate_connection_guard_and_reflection() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var dummy_cb = func(): pass

	# Signal reflection API verification
	assert_true(event_bus.has_signal("game_won"), "has_signal('game_won') must return true")
	assert_false(event_bus.has_signal("non_existent_signal_xyz"), "has_signal('non_existent_signal_xyz') must return false")

	# Connection state verification
	assert_false(event_bus.is_connected("game_won", dummy_cb), "Initially not connected")
	event_bus.connect("game_won", dummy_cb)
	assert_true(event_bus.is_connected("game_won", dummy_cb), "Confirmed connected")

	# Disconnect and verify
	event_bus.disconnect("game_won", dummy_cb)
	assert_false(event_bus.is_connected("game_won", dummy_cb), "Confirmed disconnected")

# ==============================================================================
# Challenge 14: Massive Fanout Scale (100 Concurrent Listeners)
# ==============================================================================
func test_challenge_14_massive_fanout_scale_100_listeners() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var listener_count = 100
	var received_counts: Array[int] = []
	var callables: Array[Callable] = []

	for i in range(listener_count):
		received_counts.append(0)
		var idx = i
		var cb = func(_phase: int):
			received_counts[idx] += 1
		callables.append(cb)
		event_bus.connect("phase_changed", cb)

	var emissions = 10
	for p in range(emissions):
		event_bus.emit_signal("phase_changed", p % 3)

	for i in range(listener_count):
		assert_eq(received_counts[i], emissions, "Listener %d received all %d emissions in massive 100-fanout" % [i, emissions])
		if event_bus.is_connected("phase_changed", callables[i]):
			event_bus.disconnect("phase_changed", callables[i])

# ==============================================================================
# Challenge 15: CONNECT_ONE_SHOT Interleaved with Persistent Listeners
# ==============================================================================
func test_challenge_15_one_shot_and_persistent_interleaving() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var tracker = {
		"persistent_count": 0,
		"one_shot_count": 0
	}

	var persistent_cb = func(_n: int):
		tracker["persistent_count"] += 1

	var one_shot_cb = func(_n: int):
		tracker["one_shot_count"] += 1

	event_bus.connect("wave_ended", persistent_cb)
	event_bus.connect("wave_ended", one_shot_cb, Object.CONNECT_ONE_SHOT)

	# Emission 1: Both must fire
	event_bus.emit_signal("wave_ended", 1)
	assert_eq(tracker["persistent_count"], 1, "Persistent listener fired emission 1")
	assert_eq(tracker["one_shot_count"], 1, "One-shot listener fired emission 1")
	assert_false(event_bus.is_connected("wave_ended", one_shot_cb), "One-shot listener automatically disconnected")
	assert_true(event_bus.is_connected("wave_ended", persistent_cb), "Persistent listener remains connected")

	# Emission 2: Only persistent must fire
	event_bus.emit_signal("wave_ended", 2)
	assert_eq(tracker["persistent_count"], 2, "Persistent listener fired emission 2")
	assert_eq(tracker["one_shot_count"], 1, "One-shot listener did NOT fire emission 2")

	event_bus.disconnect("wave_ended", persistent_cb)

# ==============================================================================
# Challenge 16: Callable Bind Argument Propagation
# ==============================================================================
func test_challenge_16_callable_bind_argument_propagation() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var tracker = {
		"signal_arg": -1,
		"bound_ctx": "",
		"bound_num": -1
	}

	# Signal emits 1 arg (phase: int). We bind 2 extra args ("hud_system", 999)
	# In Godot 4, bound arguments are appended AFTER the signal arguments
	var base_cb = func(phase: int, context_tag: String, ctx_id: int):
		tracker["signal_arg"] = phase
		tracker["bound_ctx"] = context_tag
		tracker["bound_num"] = ctx_id

	var bound_cb = base_cb.bind("hud_system", 999)
	event_bus.connect("phase_changed", bound_cb)

	event_bus.emit_signal("phase_changed", 2)

	assert_eq(tracker["signal_arg"], 2, "Signal argument passed correctly")
	assert_eq(tracker["bound_ctx"], "hud_system", "Bound string context passed correctly")
	assert_eq(tracker["bound_num"], 999, "Bound int context passed correctly")

	event_bus.disconnect("phase_changed", bound_cb)

# ==============================================================================
# Challenge 17: Deferred Signal Delivery Across Frames
# ==============================================================================
func test_challenge_17_deferred_signal_delivery() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var tracker = {
		"received_count": 0,
		"received_arg": -1.0
	}

	var cb = func(cur: float, _max_v: float):
		tracker["received_count"] += 1
		tracker["received_arg"] = cur

	event_bus.connect("core_hp_changed", cb, Object.CONNECT_DEFERRED)

	# Emit deferred
	event_bus.emit_signal("core_hp_changed", 7.5, 10.0)

	# Synchronously before frame processing, it should not have fired yet
	assert_eq(tracker["received_count"], 0, "Deferred emission should not fire synchronously")

	# Advance frames to allow deferred dispatch
	await wait_frames(2)

	assert_eq(tracker["received_count"], 1, "Deferred emission fired after frame processing")
	assert_almost_eq(tracker["received_arg"], 7.5, 0.001, "Deferred emission carried accurate float argument")

	if event_bus.is_connected("core_hp_changed", cb):
		event_bus.disconnect("core_hp_changed", cb)

# ==============================================================================
# Challenge 18: Rapid Connect / Disconnect Churn Under Emission
# ==============================================================================
func test_challenge_18_rapid_connect_disconnect_churn() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var cycles = 50
	var dummy_func = func(_res: Dictionary): pass

	for i in range(cycles):
		event_bus.connect("resources_changed", dummy_func)
		assert_true(event_bus.is_connected("resources_changed", dummy_func), "Connected in cycle %d" % i)
		event_bus.emit_signal("resources_changed", {"wood": i})
		event_bus.disconnect("resources_changed", dummy_func)
		assert_false(event_bus.is_connected("resources_changed", dummy_func), "Disconnected in cycle %d" % i)

# ==============================================================================
# Challenge 19: Deep Reentrant Signal Cascade (Recursion Depth Test)
# ==============================================================================
func test_challenge_19_deep_reentrant_recursion_depth() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var max_depth = 50
	var tracker = {"depth_reached": 0}
	var recursive_cb: Callable

	var cb_holder = {"cb": null}
	cb_holder["cb"] = func(depth: int):
		tracker["depth_reached"] = depth
		if depth < max_depth:
			event_bus.emit_signal("phase_changed", depth + 1)

	event_bus.connect("phase_changed", cb_holder["cb"])

	# Trigger initial cascade
	event_bus.emit_signal("phase_changed", 1)

	assert_eq(tracker["depth_reached"], max_depth, "Successfully cascaded through %d reentrant signal emissions" % max_depth)

	event_bus.disconnect("phase_changed", cb_holder["cb"])

# ==============================================================================
# Challenge 20: Dictionary Payload Reference Semantics Verification
# ==============================================================================
func test_challenge_20_dictionary_payload_reference_semantics() -> void:
	assert_not_null(event_bus, "EventBus instance must exist")
	if event_bus == null:
		return

	var original_dict = {"wood": 10, "stone": 5}
	var tracker = {
		"l1_seen": {},
		"l2_seen": {}
	}

	var listener_1 = func(res: Dictionary):
		tracker["l1_seen"] = res.duplicate(true)
		# Mutating the payload received
		res["wood"] = 9999

	var listener_2 = func(res: Dictionary):
		tracker["l2_seen"] = res.duplicate(true)

	event_bus.connect("resources_changed", listener_1)
	event_bus.connect("resources_changed", listener_2)

	event_bus.emit_signal("resources_changed", original_dict)

	# Always disconnect before asserting to prevent lingering connections on failure
	event_bus.disconnect("resources_changed", listener_1)
	event_bus.disconnect("resources_changed", listener_2)

	# Verify: GDScript passes Dictionary by reference, meaning original is modified if not cloned
	assert_has(tracker["l1_seen"], "wood", "Listener 1 captured dictionary with wood key")
	assert_eq(tracker["l1_seen"].get("wood", 0), 10, "Listener 1 saw initial unmutated value (10)")
	assert_has(tracker["l2_seen"], "wood", "Listener 2 captured dictionary with wood key")
	assert_eq(tracker["l2_seen"].get("wood", 0), 9999, "Listener 2 observed the mutated dictionary (9999, by-reference propagation confirmed)")
	assert_eq(original_dict.get("wood", 0), 9999, "Caller dictionary reflects mutation due to GDScript reference semantics")



