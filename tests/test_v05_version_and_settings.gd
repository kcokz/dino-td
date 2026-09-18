# res://tests/test_v05_version_and_settings.gd
# The version is in one place, and the settings appear in one place.
#
# VERSION.md has said since v0.3 that the version lives in exactly one file. It did not.
# project.godot said one thing, HUD.gd carried a "v0.0" literal as its fallback, and two
# labels in HUD.tscn had "v0.2" saved into them -- one of which NOTHING IN THE CODE EVER
# SET, so the game-over screen read "Defend Dinosaur v0.2" for three versions.
#
# A rule nothing enforces is a wish. This is the enforcement.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

# ==============================================================================
# 1. One source
# ==============================================================================

func test_01_the_version_comes_from_project_settings() -> void:
	var declared: String = String(ProjectSettings.get_setting("application/config/version"))
	assert_ne(declared.strip_edges(), "", "project.godot declares a version")
	assert_eq(AppInfo.get_version(), declared.strip_edges(),
		"And that is the version the game reports")

func test_02_the_fallback_is_not_a_version_number() -> void:
	# The trap this whole thing keeps falling into: a plausible-looking literal is
	# indistinguishable from the truth, so a stale one is invisible. "unknown" cannot be
	# mistaken for a real version by anybody.
	assert_eq(AppInfo.VERSION, "unknown", "The last-resort value refuses to guess")
	assert_false(AppInfo.VERSION.begins_with("v"), "It does not look like a version")

func test_03_no_scene_file_has_a_version_baked_into_it() -> void:
	# The check that would have caught the game-over badge. A label saved with a version
	# in it looks right in the editor and goes stale in silence, because nothing ever
	# reads it back.
	var offenders: Array[String] = []
	for path in ["res://scenes/ui/HUD.tscn", "res://scenes/Main.tscn", "res://scenes/CabinInterior.tscn"]:
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var line_no: int = 0
		while not f.eof_reached():
			var line: String = f.get_line()
			line_no += 1
			if not line.begins_with("text = "):
				continue
			# A version looks like "v" followed by a digit.
			for i in range(line.length() - 1):
				if line[i] == "v" and line[i + 1].is_valid_int():
					offenders.append("%s:%d  %s" % [path, line_no, line.strip_edges()])
					break
	assert_eq(offenders.size(), 0,
		"No scene may carry a version string: %s" % ", ".join(offenders))

func test_04_both_places_the_player_reads_a_version_are_filled_from_one() -> void:
	var main = _level()
	await wait_frames(2)
	var hud = main.hud
	assert_not_null(hud, "The level has a HUD")

	assert_not_null(hud.version_label, "There is a version in the top bar")
	assert_eq(hud.version_label.text, AppInfo.get_version(), "And it is the real one")

	assert_not_null(hud.version_badge, "And one on the game-over screen")
	assert_eq(hud.version_badge.text, AppInfo.get_app_title(),
		"Which nothing used to set at all, so it read v0.2 for three versions")
	assert_true(hud.version_badge.text.contains(AppInfo.get_version()),
		"It carries the same version as everything else")

# ==============================================================================
# 2. One place per setting
# ==============================================================================

func test_05_the_window_setting_is_on_the_settings_page_only() -> void:
	# Every row added to the pause menu's box shows on every page unless it is told
	# otherwise. Forgetting that put the window picker on the main menu as well, so the
	# same setting appeared twice.
	var menu = load("res://scripts/ui/PauseMenu.gd").new()
	_cleanup_nodes.append(menu)
	tree.root.add_child(menu)
	await wait_frames(2)

	menu.open()
	await wait_frames(1)
	assert_eq(int(menu.current_page), int(menu.Page.ROOT), "It opens on the main page")
	assert_false(menu.window_row.visible, "Where the window setting does not belong")
	assert_false(menu.language_row.visible, "Nor the language one")

	menu._on_settings_pressed()
	await wait_frames(1)
	assert_eq(int(menu.current_page), int(menu.Page.SETTINGS), "Now on the settings page")
	assert_true(menu.window_row.visible, "Where the window setting does belong")
	assert_true(menu.language_row.visible, "Alongside the language one")

func test_06_the_window_mode_is_one_service_not_a_second_copy() -> void:
	# The picker and the F11 key have to be two ways of asking the same thing, or they
	# will disagree the first time somebody uses the key.
	var wm = tree.root.get_node_or_null("WindowMode")
	assert_not_null(wm, "There is one thing that owns the window mode")
	assert_true(wm.has_method("is_fullscreen"), "It can be asked")
	assert_true(wm.has_method("set_fullscreen"), "And told")
	assert_true(wm.has_signal("changed"), "And it says when it changes")
	assert_gt(int(config_node.WINDOW.get("toggle_key", 0)), 0, "The key is declared in Config")
