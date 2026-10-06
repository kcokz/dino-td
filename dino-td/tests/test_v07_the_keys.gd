# res://tests/test_v07_the_keys.gd
# The player, 2026-10-04: "Settings界面还不够专业，camera和command应该有单独的tab？每个tab应该还能调整这些按键吧，按照专业游戏
# 界面制作方式来，General，Key shortcut之类的两个tab".
#
# The settings page in two tabs: General (language, window, sound) and Keys -- every key the player can set
# (Config.KEY_BINDINGS), each set by clicking it and pressing the new one (Esc keeps it), a key taken from another
# giving that one the old key, all of them back to Config's at once, and remembered in the settings file. What wears a
# key -- the card's tiles, the medallions -- says the new one.
#
# The settings file is the player's: the one test that writes it puts back exactly what it held.
extends "res://tests/test_base.gd"

const SETTINGS_PATH := "user://settings.cfg"

var config_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	Keys.saves = false
	Keys.reset(false)
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

## The pause menu open on its settings page's tab `tab`.
func _settings(main: Node, tab: String) -> Node:
	var menu = main.hud.pause_menu
	main.hud.toggle_pause_menu()
	menu.open_settings()
	menu.show_settings_tab(tab)
	await wait_frames(1)
	return menu

func _press(menu: Node, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	menu._input(ev)

func _row_key(menu: Node, key_name: String) -> String:
	var row: Node = menu.find_child("KeyRow_" + key_name, true, false)
	return (row.get_node("Key") as Button).text if row else ""

func test_01_two_tabs_general_and_keys() -> void:
	var main = await _level()
	var menu = await _settings(main, "general")
	assert_not_null(menu.general_tab, "A General tab")
	assert_not_null(menu.keys_tab, "and a Keys tab")
	assert_true(menu.general_tab.button_pressed and not menu.keys_tab.button_pressed, "General chosen")
	assert_true(menu.language_row.is_visible_in_tree() and menu.window_row.is_visible_in_tree() and menu.sound_row.is_visible_in_tree(),
		"on it the language, the window and the sound")
	assert_false(menu.keys_scroll.is_visible_in_tree(), "not the keys")
	menu.show_settings_tab("keys")
	await wait_frames(1)
	assert_true(menu.keys_tab.button_pressed and not menu.general_tab.button_pressed, "Keys chosen")
	assert_true(menu.keys_scroll.is_visible_in_tree(), "the keys shown")
	assert_false(menu.language_row.is_visible_in_tree(), "and General's rows not")
	menu.back_to_root()
	await wait_frames(1)
	assert_false(menu.general_tab.is_visible_in_tree() or menu.keys_scroll.is_visible_in_tree(), "None of it on the main page")
	main.hud.toggle_pause_menu()

func test_02_every_key_the_player_can_set_is_listed_with_its_key() -> void:
	var main = await _level()
	var menu = await _settings(main, "keys")
	for row in config_node.KEY_BINDINGS:
		var key_name: String = String(row["name"])
		assert_eq(_row_key(menu, key_name), OS.get_keycode_string(Keys.default_key(key_name)), "%s: its key" % key_name)
	assert_eq(_row_key(menu, "camera_forward_key"), OS.get_keycode_string(int(config_node.CONTROLS["camera_forward_key"])), "(W, the default)")
	main.hud.toggle_pause_menu()

func test_03_a_key_set_by_a_press_and_the_game_answers_to_it() -> void:
	var main = await _level()
	var menu = await _settings(main, "keys")
	menu._listen("details_key")
	assert_eq(_row_key(menu, "details_key"), tr("MENU_KEY_LISTEN"), "Clicked, it waits for a key")
	_press(menu, KEY_X)
	assert_eq(Keys.key("details_key"), KEY_X, "The press is its key")
	assert_eq(_row_key(menu, "details_key"), OS.get_keycode_string(KEY_X), "and its row says so")
	assert_eq(String(menu.listening), "", "no longer waiting")
	main.hud.toggle_pause_menu()
	await wait_frames(1)
	# The game answers to it: X shows all of him.
	var was: bool = bool(main.hud.option_panel.showing_details())
	var ev := InputEventKey.new()
	ev.keycode = KEY_X
	ev.pressed = true
	main._unhandled_input(ev)
	await wait_frames(1)
	assert_ne(bool(main.hud.option_panel.showing_details()), was, "X opens him in full")

func test_04_taken_from_another_it_gives_that_one_its_old_key() -> void:
	var left: int = Keys.key("camera_rotate_left_key")
	var right: int = Keys.key("camera_rotate_right_key")
	var swapped: String = Keys.bind("camera_rotate_left_key", right, false)
	assert_eq(Keys.key("camera_rotate_left_key"), right, "Turn left takes turn right's key")
	assert_eq(Keys.key("camera_rotate_right_key"), left, "and turn right is given turn left's")
	assert_eq(swapped, "camera_rotate_right_key", "(it says which)")
	for a in Keys.names():
		for b in Keys.names():
			if a < b and Keys.key(a) == Keys.key(b):
				assert_true(Keys._share(a, b), "No key does two things (%s, %s)" % [a, b])

func test_05_the_view_reset_and_the_placements_turn_share_r() -> void:
	assert_eq(Keys.key("camera_reset_key"), Keys.key("trap_turn_key"), "R is both, by design: never both live")
	Keys.bind("camera_reset_key", KEY_T, false)
	assert_eq(Keys.key("camera_reset_key"), KEY_T, "Reset moved to T")
	assert_eq(Keys.key("trap_turn_key"), Keys.default_key("trap_turn_key"), "the turn left on R, not swapped")

func test_06_esc_keeps_the_key_and_the_menu_open() -> void:
	var main = await _level()
	var menu = await _settings(main, "keys")
	menu._listen("pause_key")
	_press(menu, KEY_ESCAPE)
	assert_eq(Keys.key("pause_key"), Keys.default_key("pause_key"), "Esc keeps the key it had")
	assert_eq(String(menu.listening), "", "and stops waiting")
	assert_true(bool(menu.is_open), "the menu still open")
	main.hud.toggle_pause_menu()

func test_07_back_to_defaults_at_once() -> void:
	var main = await _level()
	var menu = await _settings(main, "keys")
	Keys.bind("camera_forward_key", KEY_I, false)
	Keys.bind("command_key_1", KEY_Z, false)
	await wait_frames(1)
	assert_eq(_row_key(menu, "camera_forward_key"), OS.get_keycode_string(KEY_I), "(set)")
	menu._on_keys_reset_pressed()
	for key_name in Keys.names():
		assert_eq(Keys.key(key_name), Keys.default_key(key_name), "%s back to Config's" % key_name)
	assert_eq(_row_key(menu, "camera_forward_key"), OS.get_keycode_string(Keys.default_key("camera_forward_key")), "and the rows say so")
	main.hud.toggle_pause_menu()

func test_08_what_wears_a_key_says_the_new_one() -> void:
	var main = await _level()
	await wait_frames(2)
	Keys.bind("command_key_1", KEY_Z, false)
	Keys.bind("details_key", KEY_X, false)
	Keys.bind("camera_reset_key", KEY_T, false)
	await wait_frames(1)
	var build: Button = main.hud.hero_commands.build_button
	var cap: Label = build.get_node_or_null("Keycap") as Label
	assert_true(cap != null and cap.text == OS.get_keycode_string(KEY_Z), "Build's tile wears Z")
	var hero_cap: Label = main.hud.find_child("HeroEmblem", true, false).get_node_or_null("Disc/Keycap") as Label
	assert_true(hero_cap != null and hero_cap.text == OS.get_keycode_string(KEY_X), "his medallion X")
	var cabin_cap: Label = main.hud.find_child("CabinEmblem", true, false).get_node_or_null("Disc/Keycap") as Label
	assert_true(cabin_cap != null and cabin_cap.text == OS.get_keycode_string(KEY_T), "the cabin's T")

func test_09_remembered_in_the_settings_file_and_read_back() -> void:
	# The player's file, put back exactly as it was.
	var had: bool = FileAccess.file_exists(SETTINGS_PATH)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(SETTINGS_PATH) if had else PackedByteArray()
	Keys.saves = true
	Keys.bind("camera_tilt_up_key", KEY_G)
	var file := ConfigFile.new()
	var loaded: int = file.load(SETTINGS_PATH)
	var kept: int = int(file.get_value(Keys.SECTION, "camera_tilt_up_key", 0)) if loaded == OK else 0
	# Read back as a start reads it.
	Keys._bound.clear()
	Keys._loaded = false
	var read_back: int = Keys.key("camera_tilt_up_key")
	Keys.saves = false
	if had:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	assert_eq(kept, KEY_G, "Set, it is written to the settings file")
	assert_eq(read_back, KEY_G, "and read back at the next start")
	assert_eq(FileAccess.get_file_as_bytes(SETTINGS_PATH) if had else PackedByteArray(), backup, "(the player's file as it was)")
