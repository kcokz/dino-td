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
