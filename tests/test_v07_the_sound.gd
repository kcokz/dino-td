# res://tests/test_v07_the_sound.gd
# The player, 2026-10-03: "设置里加一个audio，可以调整音量".
#
# THE VOLUMES: the settings page has a sound section -- a slider to each of the mix's buses (Config.AUDIO: all of it,
# what happens, what is always there), the engine's own audio buses (AudioServer) set by them, heard as they move,
# off at 0, and remembered with the other settings. Every sound the game plays goes through one of them.
#
# The sliders SAVE the player's own preferences: whatever the settings file held before this suite ran goes back
# exactly, byte for byte, and the buses back to where they were.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

const SETTINGS_PATH := "user://settings.cfg"

var config_node: Object = null
var fx: Node = null
var _cleanup_nodes: Array[Node] = []
var _had_settings: bool = false
var _settings_backup: PackedByteArray = PackedByteArray()
var _levels_before: Dictionary = {}

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		fx = tree.root.get_node_or_null("Fx")
	_had_settings = FileAccess.file_exists(SETTINGS_PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)
	for bus in _buses():
		_levels_before[bus] = fx.volume(bus)

func after_all() -> void:
	if _had_settings:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_settings_backup)
			f.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	for bus in _levels_before:
		fx.set_volume(String(bus), int(_levels_before[bus]), false)

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	for bus in _levels_before:
		fx.set_volume(String(bus), int(_levels_before[bus]), false)

func _buses() -> Array:
	return (config_node.AUDIO["buses"] as Dictionary).keys()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(8)
	return main

# ==============================================================================

func test_01_the_mix_is_the_engines_buses() -> void:
	assert_has(_buses(), "Master", "all of it")
	for bus in _buses():
		var i: int = AudioServer.get_bus_index(StringName(bus))
		assert_ne(i, -1, "%s is a bus of the engine's" % bus)
		if bus != "Master" and i != -1:
			assert_eq(AudioServer.get_bus_send(i), &"Master", "%s goes into Master" % bus)
	assert_eq(fx.buses(), _buses(), "and the settings page shows them in Config's order")

func test_02_every_sound_goes_through_one_of_them() -> void:
	var players: Array = fx.find_children("*", "AudioStreamPlayer", true, false) + \
		fx.find_children("*", "AudioStreamPlayer3D", true, false)
	assert_gt(players.size(), 0, "Fx has its players")
	for p in players:
		var bus: StringName = p.bus
		assert_true(_buses().has(String(bus)) and bus != &"Master", "%s plays through a slider of its own (%s)" % [p.name, bus])
		var ambience: bool = String(p.name).begins_with("Ambience")
		assert_eq(bus, fx.AMBIENCE_BUS if ambience else fx.EFFECTS_BUS, "%s: %s" % [p.name, "what is always there" if ambience else "what happens"])
	var crackle: AudioStreamPlayer3D = fx.make_loop("fire_crackle")
	if crackle != null:
		assert_eq(crackle.bus, fx.AMBIENCE_BUS, "a fire's crackle goes on where it is: the ambience")
		crackle.free()

func test_03_a_level_is_heard_as_it_is_set_and_0_is_off() -> void:
	for bus in _buses():
		var i: int = AudioServer.get_bus_index(StringName(bus))
		fx.set_volume(bus, 50, false)
		assert_eq(fx.volume(bus), 50, "%s at 50" % bus)
		assert_almost_eq(AudioServer.get_bus_volume_db(i), linear_to_db(0.5), 0.01, "half as loud to the ear: linear")
		assert_false(AudioServer.is_bus_mute(i), "and on")
		fx.set_volume(bus, 0, false)
		assert_eq(fx.volume(bus), 0, "%s at 0" % bus)
		assert_true(AudioServer.is_bus_mute(i), "off, not only quiet")
		fx.set_volume(bus, 100, false)
		assert_almost_eq(AudioServer.get_bus_volume_db(i), 0.0, 0.01, "%s all the way up: as the mix was made" % bus)
		assert_false(AudioServer.is_bus_mute(i), "and on again")
		fx.set_volume(bus, 140, false)
		assert_eq(fx.volume(bus), 100, "never past all the way up")

func test_04_the_settings_page_has_a_slider_to_each() -> void:
	var main = await _level()
	var hud = main.hud
	hud.toggle_pause_menu()
	await wait_frames(1)
	var menu = hud.find_child("PauseMenu", true, false)
	assert_not_null(menu, "the menu")
	if menu == null:
		return
	assert_false(menu.sound_row.visible, "not on the menu's first page")
	menu.open_settings()
	await wait_frames(1)
	assert_true(menu.sound_row.visible, "on the settings page")
	var i18n = tree.root.get_node_or_null("I18n")
	for bus in _buses():
		var slider: HSlider = menu.volume_sliders.get(bus, null)
		assert_not_null(slider, "a slider for %s" % bus)
		if slider == null:
			continue
		assert_almost_eq(slider.max_value, 100.0, 0.01, "0 to 100")
		assert_almost_eq(slider.step, float(config_node.AUDIO["step"]), 0.01, "in Config's steps")
		assert_eq(String(menu.volume_names[bus].text), tr("MENU_VOLUME_" + String(bus).to_upper()), "named")
		assert_ne(String(menu.volume_names[bus].text), "MENU_VOLUME_" + String(bus).to_upper(), "from the string table")
		slider.value = 30.0
		await wait_frames(1)
		assert_eq(fx.volume(bus), 30, "moved, the %s bus is set at once" % bus)
		assert_eq(String(menu.volume_figures[bus].text), tr("MENU_VOLUME_PERCENT") % 30, "and its figure says so")
		assert_eq(int(i18n.load_setting("audio", bus, -1)), 30, "and it is remembered")
	menu.close()

func test_05_the_levels_come_back_as_the_game_starts() -> void:
	var i18n = tree.root.get_node_or_null("I18n")
	for bus in _buses():
		i18n.save_setting("audio", bus, 40)
		fx.set_volume(bus, 100, false)
	fx._restore_volumes()
	for bus in _buses():
		assert_eq(fx.volume(bus), 40, "%s as it was left" % bus)
