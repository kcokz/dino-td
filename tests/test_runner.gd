# res://tests/test_runner.gd
# Headless test runner harness for Defend Dinosaur v0.0.
# Extends SceneTree to support full coroutine execution, deterministic frame ticking, and headless exit codes.
extends SceneTree

const TESTS_DIR: String = "res://tests/"

var verbose: bool = false
var target_suite_filter: String = ""
var target_test_filter: String = ""
var list_only: bool = false

var total_suites_run: int = 0
## Files named test_* that turned out to contain no tests. Counted rather than ignored,
## so the "every suite ran" check below can tell a deliberately empty file apart from a
## suite that vanished -- two of these exist today and are not failures.
var total_suites_without_tests: int = 0
var total_tests_run: int = 0
var total_tests_passed: int = 0
var total_tests_failed: int = 0
var total_assertions_passed: int = 0
var total_assertions_failed: int = 0
var all_failure_records: Array[Dictionary] = []
## Every SCRIPT ERROR the engine reports during the run (tests/script_error_watch.gd).
## A script error is a crash in the game, so a test during which one happens fails,
## whatever its assertions said.
var _script_errors = null
var total_script_errors: int = 0

## THE PLAYER'S SETTINGS ARE THEIRS. Suites switch the language and the window mode, and
## the game saves each switch -- so the file is read before the first suite and put back
## byte for byte after the last, whatever was saved in between. And the run is in English,
## whatever language the player plays in: every string a suite expects is the English one.
const SETTINGS_PATH: String = "user://settings.cfg"
var _had_settings: bool = false
var _settings_backup: PackedByteArray = PackedByteArray()

func _init() -> void:
	_parse_arguments()
	# A test's twitches go to its log ([TWITCH]), not into the player's telemetry (TwitchWatch).
	TwitchWatch.to_file = false
	_had_settings = FileAccess.file_exists(SETTINGS_PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)
	_script_errors = load("res://tests/script_error_watch.gd").new()
	OS.add_logger(_script_errors)
	_run_all_tests()

## Quits with `code`, taking the error watch back out of the engine first and the player's
## settings back to what they were -- a moment after the last suite, not the frame it ends: its
## level stopped the valley's sound as it went, and a stop is only asked of the audio thread,
## which lets the sound go on its next mix. Quit before it, and the sound was still held at exit
## (debug-agent BUG-003: "1 resources still in use at exit").
func _finish(code: int) -> void:
	if _script_errors != null:
		OS.remove_logger(_script_errors)
		_script_errors = null
	_restore_settings()
	await create_timer(0.25).timeout
	quit(code)

func _restore_settings() -> void:
	if _had_settings:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_settings_backup)
			f.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))

## The script errors reported since there were `start`, or none when nothing is watching.
func _script_errors_since(start: int) -> PackedStringArray:
	return _script_errors.since(start) if _script_errors != null else PackedStringArray()

func _script_error_count() -> int:
	return _script_errors.count() if _script_errors != null else 0

## Records script errors that happened outside any one test -- in a suite's before_all or
## after_all -- against the suite.
func _fail_on_script_errors(suite_file: String, where: String, errors: PackedStringArray) -> void:
	if errors.is_empty():
		return
	total_script_errors += errors.size()
	total_tests_failed += 1
	printerr("  [FAIL] %s (%d SCRIPT ERROR(S) -- in the game this is a crash)" % [where, errors.size()])
	for e in errors.slice(0, 3):
		printerr("         %s" % e)
	all_failure_records.append({
		"suite": suite_file,
		"test": where,
		"message": "SCRIPT ERROR: %s" % errors[0]
	})

func _parse_arguments() -> void:
	var user_args = OS.get_cmdline_user_args()
	var all_args = OS.get_cmdline_args()
	var combined_args = []
	combined_args.append_array(all_args)
	combined_args.append_array(user_args)

	for arg in combined_args:
		if arg == "--verbose" or arg == "-v":
			verbose = true
		elif arg == "--list" or arg == "-l":
			list_only = true
		elif arg.begins_with("--suite="):
			target_suite_filter = arg.substr(8).strip_edges()
		elif arg.begins_with("-s="):
			target_suite_filter = arg.substr(3).strip_edges()
		elif arg.begins_with("--test="):
			target_test_filter = arg.substr(7).strip_edges()
		elif arg.begins_with("-t="):
			target_test_filter = arg.substr(3).strip_edges()

func _run_all_tests() -> void:
	# Defer execution by 1 frame to ensure root nodes and any autoloads are fully ready
	await process_frame
	# In English, without saving it (see SETTINGS_PATH).
	var i18n := root.get_node_or_null("I18n")
	if i18n != null and i18n.has_method("set_locale"):
		i18n.set_locale("en", false)
	else:
		TranslationServer.set_locale("en")

	print("============================================================")
	print("DEFEND DINOSAUR v0.0 — HEADLESS TEST RUNNER")
	print("Godot Version: %s" % Engine.get_version_info()["string"])
	print("============================================================")

	var suite_files = _discover_test_suites()
	if suite_files.is_empty():
		printerr("ERROR: No test suites found in %s" % TESTS_DIR)
		_finish(1)
		return

	if list_only:
		print("Discovered test suites:")
		for path in suite_files:
			print("  - %s" % path)
		_finish(0)
		return

	var start_all_ms = Time.get_ticks_msec()

	for suite_path in suite_files:
		var suite_name = suite_path.get_file()
		if target_suite_filter != "" and not (target_suite_filter in suite_name):
			continue

		await _execute_test_suite(suite_path)

	var elapsed_all_ms = Time.get_ticks_msec() - start_all_ms

	# Every suite that was discovered has to have run. Counting them is the one check
	# that catches a whole file going missing however it happens -- a compile error, an
	# exception during setup, anything. A green run over a shrinking number of suites is
	# the most dangerous result this runner can produce, because nothing looks wrong.
	if target_suite_filter == "":
		var expected: int = suite_files.size()
		var accounted: int = total_suites_run + total_suites_without_tests
		if accounted != expected:
			printerr("ERROR: %d suites were discovered but only %d are accounted for" % [expected, accounted])
			total_tests_failed += 1
			all_failure_records.append({
				"suite": "test_runner",
				"test": "every_suite_ran",
				"message": "%d of %d suites did not run. A suite that vanishes takes its tests with it." % [expected - accounted, expected]
			})

	print("============================================================")
	print("TEST EXECUTION SUMMARY")
	print("Suites Executed:     %d" % total_suites_run)
	print("Total Tests:         %d" % total_tests_run)
	print("Tests Passed:        %d" % total_tests_passed)
	print("Tests Failed:        %d" % total_tests_failed)
	print("Assertions Passed:   %d" % total_assertions_passed)
	print("Assertions Failed:   %d" % total_assertions_failed)
	print("Script Errors:       %d" % total_script_errors)
	print("Twitches Reported:   %d" % TwitchWatch.reports_made)
	print("Total Elapsed Time:  %d ms" % elapsed_all_ms)
	print("============================================================")

	if not all_failure_records.is_empty():
		print("\nFAILURE DETAILS (%d failures):" % all_failure_records.size())
		for idx in range(all_failure_records.size()):
			var record = all_failure_records[idx]
			printerr("  %d) [%s :: %s] %s" % [
				idx + 1,
				record.get("suite", "unknown"),
				record.get("test", "unknown"),
				record.get("message", "")
			])
		print("============================================================\n")

	if total_tests_failed > 0 or total_tests_run == 0:
		print("RESULT: FAILED (exit code 1)")
		_finish(1)
	else:
		print("RESULT: ALL TESTS PASSED (exit code 0)")
		_finish(0)

func _discover_test_suites() -> Array[String]:
	var suites: Array[String] = []
	var dir = DirAccess.open(TESTS_DIR)
	if dir == null:
		return suites

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("test_") and file_name.ends_with(".gd"):
			if file_name != "test_runner.gd" and file_name != "test_base.gd":
				suites.append(TESTS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	suites.sort()
	return suites

func _execute_test_suite(suite_path: String) -> void:
	var suite_file = suite_path.get_file()
	print("\n>>> Running Test Suite: %s" % suite_file)
	var orphans_before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	await _run_suite(suite_path, suite_file)
	# Nodes it took out of the tree, or never put in, and never freed: they are left to the end of the run --
	# with their bodies, their scripts and whatever they hold (the debug-agent's BUG-021: "可以在 test_runner 最后
	# 打印 OBJECT_ORPHAN_NODE_COUNT，哪个测试之后涨了就是哪个"). Counted a frame or two on, once what it queued
	# for freeing has gone.
	await process_frame
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans_before
	if orphans > 0:
		print("  [ORPHANS] %d node(s) out of the tree and never freed after %s -- every orphan of the run so far:" % [orphans, suite_file])
		Node.print_orphan_nodes()

func _run_suite(suite_path: String, suite_file: String) -> void:

	var script_res = load(suite_path)
	if script_res == null:
		printerr("ERROR: Could not load script %s" % suite_path)
		total_tests_failed += 1
		all_failure_records.append({
			"suite": suite_file,
			"test": "suite_loader",
			"message": "Failed to load suite script at %s" % suite_path
		})
		return

	# A script with a parse error still load()s to a GDScript object -- it is only
	# calling new() on it that goes wrong, and that aborts this function outright, so
	# the checks below never ran and the suite just vanished from the run. One syntax
	# error used to take thirteen tests with it and still report ALL TESTS PASSED.
	if script_res is GDScript and not (script_res as GDScript).can_instantiate():
		printerr("ERROR: %s failed to compile -- look for a Parse Error above" % suite_file)
		total_tests_failed += 1
		all_failure_records.append({
			"suite": suite_file,
			"test": "suite_compiler",
			"message": "The suite did not compile, so none of its tests ran."
		})
		return

	# A script that is not a suite -- a check of its own that extends SceneTree and runs from its _init when
	# launched with --script (the victory auditors' probes) -- is not made here. Made, it was a whole second
	# SceneTree -- its window, its worlds, its multiplayer -- with its _init waiting for a frame that tree would
	# never have, all of it left at exit every run (the debug-agent's BUG-021: "两个 SceneTree、两个 Window……
	# 还有两个 GDScriptFunctionState"). It has no tests for this runner either way.
	if script_res is GDScript and not ClassDB.is_parent_class(String((script_res as GDScript).get_instance_base_type()), "RefCounted"):
		print("  [SKIP] %s is a script of its own, not a suite -- run it with --script" % suite_file)
		total_suites_without_tests += 1
		return

	var suite_instance = script_res.new()
	if suite_instance == null:
		printerr("ERROR: Could not instantiate script %s" % suite_path)
		total_tests_failed += 1
		all_failure_records.append({
			"suite": suite_file,
			"test": "suite_instantiator",
			"message": "Failed to instantiate suite at %s" % suite_path
		})
		return

	if "tree" in suite_instance:
		suite_instance.tree = self

	# Discover test methods
	var test_methods: Array[String] = []
	var method_list = suite_instance.get_method_list()
	for m in method_list:
		var m_name: String = m["name"]
		if m_name.begins_with("test_"):
			if target_test_filter == "" or (target_test_filter in m_name):
				test_methods.append(m_name)
	test_methods.sort()

	if test_methods.is_empty():
		print("  [WARN] No test methods matching 'test_*' found in %s" % suite_file)
		total_suites_without_tests += 1
		return

	total_suites_run += 1

	# Suite lifecycle: before_all
	var setup_errors_from: int = _script_error_count()
	if suite_instance.has_method("before_all"):
		await suite_instance.call("before_all")
	_fail_on_script_errors(suite_file, "before_all", _script_errors_since(setup_errors_from))

	# Run each test
	for method_name in test_methods:
		total_tests_run += 1
		if "current_test_name" in suite_instance:
			suite_instance.current_test_name = method_name

		var pre_fail_count = 0
		var pre_pass_count = 0
		if "assertions_failed" in suite_instance:
			pre_fail_count = suite_instance.assertions_failed
		if "assertions_passed" in suite_instance:
			pre_pass_count = suite_instance.assertions_passed

		# Everything from here to the end of after_each is this test's: a script error
		# anywhere in it is this test's crash.
		var errors_from: int = _script_error_count()

		# Test lifecycle: before_each
		if suite_instance.has_method("before_each"):
			await suite_instance.call("before_each")

		var start_test_ms = Time.get_ticks_msec()

		# Invoke the test method (supports both sync and async via await)
		await suite_instance.call(method_name)

		var elapsed_test_ms = Time.get_ticks_msec() - start_test_ms

		# Test lifecycle: after_each
		if suite_instance.has_method("after_each"):
			await suite_instance.call("after_each")

		var post_fail_count = pre_fail_count
		var post_pass_count = pre_pass_count
		if "assertions_failed" in suite_instance:
			post_fail_count = suite_instance.assertions_failed
		if "assertions_passed" in suite_instance:
			post_pass_count = suite_instance.assertions_passed

		var delta_fails = post_fail_count - pre_fail_count
		var delta_passes = post_pass_count - pre_pass_count

		total_assertions_passed += delta_passes
		total_assertions_failed += delta_fails

		var script_errors: PackedStringArray = _script_errors_since(errors_from)
		if not script_errors.is_empty():
			# First, and whatever the assertions said: a SCRIPT ERROR is a crash in the
			# game. The one that started this -- placing a single stake -- crashed on
			# every click while every drag test around it stayed green.
			total_script_errors += script_errors.size()
			total_tests_failed += 1
			printerr("  [FAIL] %s (%d SCRIPT ERROR(S) -- in the game this is a crash, %d ms)" % [method_name, script_errors.size(), elapsed_test_ms])
			for e in script_errors.slice(0, 3):
				printerr("         %s" % e)
			all_failure_records.append({
				"suite": suite_file,
				"test": method_name,
				"message": "SCRIPT ERROR: %s" % script_errors[0]
			})
		elif delta_fails == 0 and delta_passes == 0:
			# A test that asserted nothing is not a passing test, it is a test that did
			# not run. The usual cause is an error part-way through -- a script that no
			# longer exists, a null where a node was expected -- which aborts the method
			# silently and leaves a green [PASS] behind it. Eight tests sat like this for
			# a whole version after v0.4 deleted the classes they instantiated.
			total_tests_failed += 1
			printerr("  [FAIL] %s (0 assertions -- the test aborted before asserting anything, %d ms)" % [method_name, elapsed_test_ms])
			all_failure_records.append({
				"suite": suite_file,
				"test": method_name,
				"message": "Reached the end with 0 assertions. Look for a SCRIPT ERROR above: the method died part-way through."
			})
		elif delta_fails == 0:
			total_tests_passed += 1
			print("  [PASS] %s (%d assertions, %d ms)" % [method_name, delta_passes, elapsed_test_ms])
		else:
			total_tests_failed += 1
			printerr("  [FAIL] %s (%d failed assertions, %d ms)" % [method_name, delta_fails, elapsed_test_ms])

	# Suite lifecycle: after_all
	var teardown_errors_from: int = _script_error_count()
	if suite_instance.has_method("after_all"):
		await suite_instance.call("after_all")
	_fail_on_script_errors(suite_file, "after_all", _script_errors_since(teardown_errors_from))

	# Collect failures
	if "failure_records" in suite_instance:
		for rec in suite_instance.failure_records:
			var full_rec = {
				"suite": suite_file,
				"test": rec.get("test", "unknown"),
				"message": rec.get("message", "")
			}
			all_failure_records.append(full_rec)

	# Whatever it would be kept alive by, let go (test_base.release) -- before its tree is taken from it.
	if suite_instance.has_method("release"):
		suite_instance.release()

	if "tree" in suite_instance:
		suite_instance.tree = null

	if suite_instance is Node:
		suite_instance.queue_free()

	suite_instance = null
	script_res = null

# --- Direct Assertion Helpers (callable on test runner) ---

func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		total_assertions_passed += 1
		return true
	total_assertions_failed += 1
	printerr("  [FAIL] assert_true: Expected TRUE, got FALSE. %s" % message)
	return false

func assert_false(condition: bool, message: String = "") -> bool:
	if not condition:
		total_assertions_passed += 1
		return true
	total_assertions_failed += 1
	printerr("  [FAIL] assert_false: Expected FALSE, got TRUE. %s" % message)
	return false

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		total_assertions_passed += 1
		return true
	total_assertions_failed += 1
	printerr("  [FAIL] assert_eq: Expected '%s', got '%s'. %s" % [str(expected), str(actual), message])
	return false

func assert_ne(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual != expected:
		total_assertions_passed += 1
		return true
	total_assertions_failed += 1
	printerr("  [FAIL] assert_ne: Expected NOT equal to '%s'. %s" % [str(expected), message])
	return false

func assert_null(val: Variant, message: String = "") -> bool:
	if val == null:
		total_assertions_passed += 1
		return true
	total_assertions_failed += 1
	printerr("  [FAIL] assert_null: Expected NULL, got '%s'. %s" % [str(val), message])
	return false

func assert_not_null(val: Variant, message: String = "") -> bool:
	if val != null:
		total_assertions_passed += 1
		return true
	total_assertions_failed += 1
	printerr("  [FAIL] assert_not_null: Expected NOT NULL, got NULL. %s" % message)
	return false
