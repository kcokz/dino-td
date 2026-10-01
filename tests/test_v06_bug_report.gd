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

func test_04_its_button_wears_its_key_and_is_faint_till_the_cursor_is_on_it() -> void:
	# v0.6 round seven, the player: "Debug版本给我一个按钮可以按（上面显示快捷键），可以用比较透明的方法显示（release版本
	# 没有这个功能和按钮）".
	var main = await _level()
	var report: BugReport = main.get_node_or_null("BugReport") as BugReport
	if not OS.is_debug_build():
		assert_null(report, "A release has no bug report, and no button for it")
		return
	await wait_frames(2)
	assert_not_null(report, "(a development build has the bug report)")
	if report == null:
		return
	var btn: Button = report.button
	assert_not_null(btn, "It has a button")
	if btn == null:
		return
	assert_true(btn.is_visible_in_tree(), "on the screen")
	var key: int = int(config_node.CONTROLS["bug_report_key"])
	var cap: Label = btn.get_node_or_null("Keycap") as Label
	assert_not_null(cap, "wearing its key")
	if cap != null:
		assert_eq(cap.text, BugReport.key_text(key), "(the key under Esc, as the board writes it: %s)" % cap.text)
		assert_lte(cap.get_global_rect().end.x, btn.get_global_rect().end.x + 0.5, "inside the button")
	var faint: float = float(config_node.BUG_REPORT["button_alpha"])
	assert_lt(faint, 1.0, "(faint is see-through)")
	assert_almost_eq(btn.modulate.a, faint, 0.001, "Faint while the cursor is elsewhere")
	btn.mouse_entered.emit()
	assert_almost_eq(btn.modulate.a, float(config_node.BUG_REPORT["button_alpha_hover"]), 0.001, "whole under it")
	btn.mouse_exited.emit()
	assert_almost_eq(btn.modulate.a, faint, 0.001, "and faint again after")
	assert_gt(int(report.get("_layer").layer), int(main.hud.layer), "Over the HUD and its menus")
	var version: Rect2 = main.hud.version_label.get_global_rect()
	var at: Rect2 = btn.get_global_rect()
	var seen: Rect2 = main.get_viewport().get_visible_rect()
	assert_gte(at.position.x, version.end.x, "Beside the version at the bottom left")
	assert_true(at.position.y <= version.get_center().y and at.end.y >= version.get_center().y, "on its line")
	assert_true(seen.encloses(at), "and all of it on the screen (%s in %s)" % [at, seen])
	var dir: String = "user://bugreports"
	var before: int = DirAccess.get_files_at(dir).size() if DirAccess.dir_exists_absolute(dir) else 0
	btn.pressed.emit()
	var files: PackedStringArray = DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
	assert_gt(files.size(), before, "Pressed, it writes a report, as the key does")
	for f in files:
		if f.begins_with("bug-") and FileAccess.get_modified_time(dir.path_join(f)) >= int(Time.get_unix_time_from_system()) - 5:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))

func test_05_the_release_build_leaves_it_out() -> void:
	# "release版本没有这个功能和按钮，这在你的build file或者build script得区分": the build decides it. The release preset
	# leaves scripts/dev/ out, the development one keeps it, the build script exports those two and checks the
	# release's pack, and nothing the release ships names what is only in the development build.
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK, "The builds are written down (export_presets.cfg)")
	var by_name: Dictionary = {}
	for section in presets.get_sections():
		if presets.has_section_key(section, "name"):
			by_name[String(presets.get_value(section, "name"))] = section
	var dev_only: String = "scripts/dev/*"
	for preset in ["Windows Dev", "Windows Release"]:
		assert_true(by_name.has(preset), "A preset %s" % preset)
	if by_name.has("Windows Release"):
		var left_out: String = String(presets.get_value(by_name["Windows Release"], "exclude_filter", ""))
		assert_true(left_out.contains(dev_only), "The release leaves the development code out (%s)" % left_out)
	if by_name.has("Windows Dev"):
		var dev_left_out: String = String(presets.get_value(by_name["Windows Dev"], "exclude_filter", ""))
		assert_false(dev_left_out.contains(dev_only), "the development build keeps it")
	var script: String = String(load("res://scripts/core/Main.gd").get_script_constant_map().get("BUG_REPORT_SCRIPT", ""))
	assert_true(script.begins_with("res://scripts/dev/"), "The bug report is development code (%s)" % script)
	assert_true(ResourceLoader.exists(script), "(and there)")
	var build: String = FileAccess.get_file_as_string("res://tools/build.py")
	for preset in ["Windows Dev", "Windows Release"]:
		assert_true(build.contains('"%s"' % preset), "The build script exports %s" % preset)
	assert_true(build.contains('"scripts/dev/"'), "and checks the release's pack for development code")
	# Nothing the release ships names a development class: it would not load without it.
	var dev_classes: Array[String] = []
	for entry in ProjectSettings.get_global_class_list():
		if String(entry["path"]).begins_with("res://scripts/dev/"):
			dev_classes.append(String(entry["class"]))
	assert_true(dev_classes.has("BugReport"), "(the bug report is one: %s)" % ", ".join(dev_classes))
	var named: Array[String] = []
	# Its code only: what is in quotes -- a path, a word -- is not a name, nor is a comment.
	var quoted := RegEx.create_from_string("\"[^\"]*\"")
	for path in _scripts_under("res://scripts"):
		if path.begins_with("res://scripts/dev/"):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = quoted.sub(line, "", true).split("#")[0]
			for cls in dev_classes:
				var at: int = code.find(cls)
				if at >= 0 and not (at > 0 and (code[at - 1] == "_" or code[at - 1].is_valid_identifier())):
					named.append("%s: %s" % [path, line.strip_edges()])
	assert_eq(named.size(), 0, "No shipped script names one in its code: %s" % "; ".join(named))

func _scripts_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(d)))
	return out
