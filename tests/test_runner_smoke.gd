# res://tests/test_runner_smoke.gd
# Self-test smoke suite verifying the test runner harness, assertions, and lifecycle.
extends "res://tests/test_base.gd"

signal custom_signal(val: int, text: String)

var lifecycle_state: Array[String] = []

func before_all() -> void:
	lifecycle_state.append("before_all")

func before_each() -> void:
	lifecycle_state.append("before_each")

func after_each() -> void:
	lifecycle_state.append("after_each")

func after_all() -> void:
	lifecycle_state.append("after_all")

func test_boolean_assertions() -> void:
	assert_true(true, "true should be true")
	assert_false(false, "false should be false")
	assert_true(1 + 1 == 2, "math equation should hold")

func test_equality_assertions() -> void:
	assert_eq(42, 42, "integers should match")
	assert_eq("dino", "dino", "strings should match")
	assert_ne(1, 2, "distinct integers should not match")
	assert_almost_eq(1.00005, 1.00008, 0.001, "almost equal floats should match")

func test_comparison_assertions() -> void:
	assert_gt(10, 5, "10 > 5")
	assert_gte(10, 10, "10 >= 10")
	assert_lt(3, 8, "3 < 8")
	assert_lte(8, 8, "8 <= 8")

func test_null_assertions() -> void:
	var empty_val = null
	var populated_val = "hello"
	assert_null(empty_val, "empty_val should be null")
	assert_not_null(populated_val, "populated_val should not be null")

func test_collection_assertions() -> void:
	var dict_data = {"wood": 10, "stone": 5}
	var arr_data = ["alpha", "beta", "gamma"]
	assert_has(dict_data, "wood", "dict should contain wood")
	assert_not_has(dict_data, "gold", "dict should not contain gold")
	assert_has(arr_data, "beta", "arr should contain beta")
	assert_not_has(arr_data, "delta", "arr should not contain delta")

func test_signal_watcher() -> void:
	var watcher = watch_signal(self, "custom_signal")
	assert_false(watcher.emitted, "signal should not be emitted yet")
	
	custom_signal.emit(100, "fire")
	
	assert_true(watcher.emitted, "signal should be marked emitted")
	assert_eq(watcher.emit_count, 1, "emit count should be 1")
	assert_eq(watcher.last_args.size(), 2, "should have 2 args")
	assert_eq(watcher.last_args[0], 100, "arg 0 should be 100")
	assert_eq(watcher.last_args[1], "fire", "arg 1 should be 'fire'")

func test_async_wait_frames() -> void:
	var start_frame = Engine.get_process_frames()
	await wait_frames(3)
	var end_frame = Engine.get_process_frames()
	assert_gte(end_frame - start_frame, 3, "should advance at least 3 process frames")
