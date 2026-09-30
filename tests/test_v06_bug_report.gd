# res://tests/test_v06_bug_report.gd
# The player, 2026-09-29: "你弄一个bug report功能（加到dev版，release版本没有这个功能），因为有时候截图你看不清也不知道
# 哪里出问题，bug report功能snap所有你想要知道的当前参数并dump出来，我在dev版测试的时候可以直接导出bugreport（给个快捷键）".
#
# In a development build the level has a BugReport, and its key writes everything the game was doing to
# a file: the run, the view, what was picked, the Hero, every animal's mind, the buildings, the raids,
# the corner, and the last things that happened.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func test_01_a_development_build_has_one_and_it_writes_everything() -> void:
	var main = await _level()
	var report: BugReport = main.get_node_or_null("BugReport") as BugReport
	if not OS.is_debug_build():
		assert_null(report, "A release has no bug report")
		return
	assert_not_null(report, "A development build has a bug report")
	if report == null:
		return
	tree.root.get_node("EventBus").wave_started.emit(4, true)
	var path: String = report.save()
	assert_ne(path, "", "Its key writes a report")
	var got = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(got is Dictionary, "(as JSON)")
	if got is Dictionary:
		for key in ["report", "run", "view", "picked", "hero", "dinos", "buildings", "nodes", "raids", "corner", "events"]:
			assert_true(got.has(key), "with %s" % key)
		assert_true(String(got["hero"].get("state", "")) != "", "the Hero's state")
		var said: bool = false
		for e in got["events"]:
			if String(e[1]) == "wave_started":
				said = true
		assert_true(said, "and the last things that happened, as they were said")
	for f in [path, path.replace(".json", ".png")]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

func test_02_its_key_is_in_the_controls() -> void:
	assert_eq(int(config_node.CONTROLS["bug_report_key"]), KEY_F9, "F9 writes a bug report")
