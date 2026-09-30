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

func test_03_two_at_once_are_two_and_it_says_where_each_came_from() -> void:
	# The debug-agent's TASK-027: "文件名只到秒，一秒里按两次，后一份会盖掉前一份"; and "我想再要的：最近几份抽搐报告
	# （TwitchWatch）；每只恐龙从哪出来的（巢 / 哪个边缘入口）；攻击位置（slot）归谁".
	var main = await _level()
	var report: BugReport = main.get_node_or_null("BugReport") as BugReport
	if not OS.is_debug_build() or report == null:
		return
	var raider = main.wave_manager.spawn_dino()
	assert_not_null(raider, "(a raider out)")
	if raider == null:
		return
	var id: int = raider.get_instance_id()
	tree.root.get_node("EventBus").twitch_detected.emit({"kind": "jitter", "n": 1, "dino": {"id": id}})
	Dino.claim_attack_slot(main.current_core, raider)
	var first: String = report.save()
	var second: String = report.save()
	assert_ne(first, second, "Two reports at once are two files")
	assert_true(FileAccess.file_exists(first) and FileAccess.file_exists(second), "and both are kept")
	var got = JSON.parse_string(FileAccess.get_file_as_string(second))
	assert_true(got is Dictionary, "(as JSON)")
	if got is Dictionary:
		var came: String = ""
		for d in got["dinos"]:
			if int(d["id"]) == id:
				came = String(d.get("came_from", ""))
		assert_true(came == "nest" or came == "behind the nest" or came.begins_with("edge "),
			"Each animal says where it came from (%s)" % came)
		assert_eq(got["twitches"].size(), 1, "The last twitches are in it, whole")
		var held: bool = false
		for b in got["slots"]:
			for p in b["places"]:
				if p["held_by"] != null and int(p["held_by"]) == id:
					held = true
		assert_true(held, "and whose each place round a building is")
	for f in [first, second]:
		for g in [f, f.replace(".json", ".png")]:
			if FileAccess.file_exists(g):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(g))

func test_02_its_key_is_one_the_hand_reaches_and_writes_a_report() -> void:
	# The player, 2026-09-29: "我f按键不方便，有没有别的快捷键可以用给bug report".
	var key: int = int(config_node.CONTROLS["bug_report_key"])
	assert_false(key >= KEY_F1 and key <= KEY_F12, "Not an F key")
	for name in config_node.CONTROLS:
		var bound = config_node.CONTROLS[name]
		if name != "bug_report_key" and (bound is int) and String(name).ends_with("_key"):
			assert_ne(int(bound), key, "and not one the game uses for anything else (%s)" % name)
		if bound is Array:
			assert_false((bound as Array).has(key), "(%s)" % name)
	var main = await _level()
	var report: BugReport = main.get_node_or_null("BugReport") as BugReport
	if not OS.is_debug_build() or report == null:
		return
	var dir: String = "user://bugreports"
	var before: int = DirAccess.get_files_at(dir).size() if DirAccess.dir_exists_absolute(dir) else 0
	var press := InputEventKey.new()
	press.physical_keycode = key as Key
	press.pressed = true
	report._unhandled_input(press)
	var files: PackedStringArray = DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	assert_gt(files.size(), before, "Pressed where it is on the board, it writes a report")
	for f in files:
		if f.begins_with("bug-") and FileAccess.get_modified_time(dir.path_join(f)) >= int(Time.get_unix_time_from_system()) - 5:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
