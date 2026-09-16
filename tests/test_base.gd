# res://tests/test_base.gd
# Base class for Defend Dinosaur v0.0 test suites.
# Provides structured assertions, signal monitoring, lifecycle hooks, and async utilities.
extends RefCounted

# Inner class for watching signal emissions and capturing arguments.
class SignalWatcher extends RefCounted:
	var target: Object
	var signal_name: String
	var emitted: bool = false
	var emit_count: int = 0
	var emission_args: Array = []
	var last_args: Array = []
	var _callable: Callable

	func _init(p_target: Object, p_signal_name: String) -> void:
		target = p_target
		signal_name = p_signal_name
		_callable = Callable(self, "_on_signal")
		if target != null and target.has_signal(signal_name):
			target.connect(signal_name, _callable)

	func _on_signal(a = null, b = null, c = null, d = null, e = null) -> void:
		emitted = true
		emit_count += 1
		var args: Array = []
		for arg in [a, b, c, d, e]:
			if arg != null:
				args.append(arg)
		last_args = args
		emission_args.append(args)

	func disconnect_watcher() -> void:
		if target != null and is_instance_valid(target) and target.has_signal(signal_name):
			if target.is_connected(signal_name, _callable):
				target.disconnect(signal_name, _callable)
		target = null

var tree: SceneTree = null
var current_test_name: String = ""
var assertions_passed: int = 0
var assertions_failed: int = 0
var failure_records: Array[Dictionary] = []
var _active_watchers: Array[SignalWatcher] = []

# --- Lifecycle Hooks (override in subclass as needed) ---
func before_all() -> void:
	pass

func before_each() -> void:
	pass

func after_each() -> void:
	# Clean up any signal watchers created during the test
	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	pass

# --- Signal Watcher Factory ---
func watch_signal(p_target: Object, p_signal_name: String) -> SignalWatcher:
	var watcher = SignalWatcher.new(p_target, p_signal_name)
	_active_watchers.append(watcher)
	return watcher

# --- Assertion Helpers ---

func _record_pass(_msg: String) -> void:
	assertions_passed += 1

func _record_fail(msg: String) -> void:
	assertions_failed += 1
	var record = {
		"test": current_test_name,
		"message": msg
	}
	failure_records.append(record)
	printerr("  [FAIL] %s: %s" % [current_test_name, msg])

func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		_record_pass(message)
		return true
	_record_fail("Expected TRUE, got FALSE. %s" % message)
	return false

func assert_false(condition: bool, message: String = "") -> bool:
	if not condition:
		_record_pass(message)
		return true
	_record_fail("Expected FALSE, got TRUE. %s" % message)
	return false

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		_record_pass(message)
		return true
	_record_fail("Expected '%s' (type %s), got '%s' (type %s). %s" % [
		str(expected), type_string(typeof(expected)),
		str(actual), type_string(typeof(actual)),
		message
	])
	return false

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual != expected:
		_record_pass(message)
		return true
	_record_fail("Expected value NOT equal to '%s', but values matched. %s" % [str(expected), message])
	return false

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> bool:
	if abs(actual - expected) <= tolerance:
		_record_pass(message)
		return true
	_record_fail("Expected '%s' within tolerance %s, got '%s'. %s" % [
		str(expected), str(tolerance), str(actual), message
	])
	return false

func assert_gt(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual > expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s > %s. %s" % [str(actual), str(expected), message])
	return false

func assert_gte(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual >= expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s >= %s. %s" % [str(actual), str(expected), message])
	return false

func assert_lt(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual < expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s < %s. %s" % [str(actual), str(expected), message])
	return false

func assert_lte(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual <= expected:
		_record_pass(message)
		return true
	_record_fail("Expected %s <= %s. %s" % [str(actual), str(expected), message])
	return false

func assert_null(value: Variant, message: String = "") -> bool:
	if value == null:
		_record_pass(message)
		return true
	_record_fail("Expected NULL, got '%s'. %s" % [str(value), message])
	return false

func assert_not_null(value: Variant, message: String = "") -> bool:
	if value != null:
		_record_pass(message)
		return true
	_record_fail("Expected NOT NULL, got NULL. %s" % message)
	return false

func assert_has(collection: Variant, element_or_key: Variant, message: String = "") -> bool:
	if collection != null and element_or_key in collection:
		_record_pass(message)
		return true
	_record_fail("Expected collection '%s' to contain '%s'. %s" % [str(collection), str(element_or_key), message])
	return false

func assert_not_has(collection: Variant, element_or_key: Variant, message: String = "") -> bool:
	if collection != null and not (element_or_key in collection):
		_record_pass(message)
		return true
	_record_fail("Expected collection '%s' NOT to contain '%s'. %s" % [str(collection), str(element_or_key), message])
	return false

func assert_has_method(target: Object, method_name: String, message: String = "") -> bool:
	if target != null and target.has_method(method_name):
		_record_pass(message)
		return true
	_record_fail("Object %s does not implement method '%s'. %s" % [str(target), method_name, message])
	return false

func assert_has_signal(target: Object, signal_name: String, message: String = "") -> bool:
	if target != null and target.has_signal(signal_name):
		_record_pass(message)
		return true
	_record_fail("Object %s does not declare signal '%s'. %s" % [str(target), signal_name, message])
	return false

# --- Async Utilities ---

func wait_frames(frame_count: int = 1) -> void:
	if tree != null:
		for i in range(frame_count):
			await tree.process_frame

func wait_seconds(sec: float) -> void:
	if tree != null:
		var start_time: int = Time.get_ticks_msec()
		var target_ms: int = int(sec * 1000.0)
		while (Time.get_ticks_msec() - start_time) < target_ms:
			await tree.process_frame

func wait_for_signal(p_target: Object, p_signal_name: String, timeout_sec: float = 1.0) -> bool:
	if p_target == null or not p_target.has_signal(p_signal_name):
		return false
	var fired: Array[bool] = [false]
	var cb = func(_a = null, _b = null, _c = null, _d = null, _e = null):
		fired[0] = true
	p_target.connect(p_signal_name, cb, Object.CONNECT_ONE_SHOT)
	var start_time: int = Time.get_ticks_msec()
	var timeout_ms: int = int(timeout_sec * 1000.0)
	while not fired[0] and (Time.get_ticks_msec() - start_time) < timeout_ms:
		if tree != null:
			await tree.process_frame
		else:
			break
	if p_target.is_connected(p_signal_name, cb):
		p_target.disconnect(p_signal_name, cb)
	return fired[0]

# ==============================================================================
# Balance helpers
# ==============================================================================

## Cost of a building straight from Config. Tests that only care about "the right
## amount was deducted" should use this instead of restating the tuning values,
## so a balance pass does not break them.
func cost_of(type_id: String, res_id: String = "wood") -> int:
	var cfg = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(type_id):
		return 0
	return int(cfg.BUILDINGS[type_id].get("cost", {}).get(res_id, 0))

## The wood a fresh game starts with, straight from Config. Tests that mean
## "the wallet is untouched" should compare against this rather than a literal.
func opening_wood() -> int:
	var cfg = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		cfg = Engine.get_main_loop().root.get_node_or_null("Config")
	if cfg == null or not ("INITIAL_RESOURCES" in cfg):
		return 10
	return int(cfg.INITIAL_RESOURCES.get("wood", 10))

## How much of `res_id` is lying on the ground as drops (v0.3). Production no
## longer banks anything directly -- a machine leaves a pile beside it and the
## warehouse only grows when the Hero fetches it -- so a test that means
## "production happened" asks this, not the wallet.
func ground_total(res_id: String) -> int:
	var sum: int = 0
	if not (Engine.get_main_loop() is SceneTree):
		return 0
	for d in Engine.get_main_loop().get_nodes_in_group("drops"):
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		if "resource_type" in d and String(d.resource_type) == res_id:
			sum += int(d.amount)
	return sum

## Everything the player has earned of `res_id`, banked or still on the floor.
## The right measure for "did this produce anything", since where it currently
## sits is a matter of whether anyone has walked over it yet.
func earned_total(res_id: String) -> int:
	var gs = null
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		gs = Engine.get_main_loop().root.get_node_or_null("GameState")
	var banked: int = 0
	if gs and "resources" in gs:
		banked = int(gs.resources.get(res_id, 0))
	return banked + ground_total(res_id)

## Clears every drop on the ground. Suites that produce resources should call this
## between tests, or one test's piles turn up in the next one's totals.
func clear_drops() -> void:
	if not (Engine.get_main_loop() is SceneTree):
		return
	for d in Engine.get_main_loop().get_nodes_in_group("drops"):
		if is_instance_valid(d):
			if d.is_inside_tree():
				d.get_parent().remove_child(d)
			if not d.is_queued_for_deletion():
				d.free()

## Total wood needed to place every type in `type_ids` once.
func total_cost_of(type_ids: Array, res_id: String = "wood") -> int:
	var sum: int = 0
	for t in type_ids:
		sum += cost_of(String(t), res_id)
	return sum
