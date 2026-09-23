# res://tests/test_v05_every_button_the_player_can_press.gd
# Every button a player can reach, pressed, in every place it can be reached from.
#
# The single-stake crash lived on the road from the player's hand to the game, and that
# road has more than one lane: besides the clicks and keys Main._unhandled_input reads
# (test_v05_the_players_hand_never_crashes_the_game.gd), everything else the player does
# goes through a button -- the Hero's build menu, a building's repair and demolish, the
# recipes at a bench in the cabin, the top bar, the pause menu and its pickers. A crash in
# any of those callbacks is the same crash.
#
# So this presses them: every visible, enabled button, following whatever each press
# brings up, the way a player clicks through a panel. Nothing here asserts much beyond
# "the game is still there" -- the teeth are in the runner, which fails a test during
# which any SCRIPT ERROR is logged (tests/script_error_watch.gd).
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var event_bus: Object = null
var _cleanup_nodes: Array[Node] = []

# The pause menu's pickers SAVE the player's own preferences. Whatever the file held
# before this suite ran goes back exactly, byte for byte.
const SETTINGS_PATH := "user://settings.cfg"
var _had_settings: bool = false
var _settings_backup: PackedByteArray = PackedByteArray()
var _locale_before: String = ""

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
		event_bus = tree.root.get_node_or_null("EventBus")
	_had_settings = FileAccess.file_exists(SETTINGS_PATH)
	if _had_settings:
		_settings_backup = FileAccess.get_file_as_bytes(SETTINGS_PATH)
	_locale_before = TranslationServer.get_locale()

func after_all() -> void:
	if _had_settings:
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_settings_backup)
			f.close()
	elif FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	TranslationServer.set_locale(_locale_before)

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null and "is_paused" in game_state_node:
		game_state_node.is_paused = false
	tree.paused = false
	Engine.time_scale = 1.0
	super.after_each()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(8)
	_fill_the_warehouse()
	return main

func _fill_the_warehouse() -> void:
	if game_state_node and "resources" in game_state_node:
		for res in config_node.RESOURCES:
			game_state_node.resources[res] = 4000

## Every button a player could press under `root` right now: shown, and not greyed out.
func _pressable(root: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	if root == null or not is_instance_valid(root):
		return out
	for n in root.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.is_visible_in_tree() and not b.disabled:
			out.append(b)
	return out

## Presses every button under `root`, then every button THAT brought up, and so on --
## one press at a time, rescanning after each, because a press may rebuild the panel.
## `skip` names buttons a test must never press (Quit ends the run). Returns how many
## were pressed.
func _press_everything(root: Node, context: String, skip: Array = []) -> int:
	var done: Dictionary = {}
	var count: int = 0
	for _i in range(60):
		var next: BaseButton = null
		for b in _pressable(root):
			var key: String = "%s|%s|%s" % [context, b.name, (b as Button).text if b is Button else ""]
			var skipped: bool = false
			for s in skip:
				if String(s) in key:
					skipped = true
			if skipped or done.has(key):
				continue
			done[key] = true
			next = b
			break
		if next == null:
			break
		next.pressed.emit()
		count += 1
		await wait_frames(1)
	return count

func _select(unit: Node) -> void:
	if event_bus and event_bus.has_signal("unit_selected"):
		event_bus.unit_selected.emit(unit)

func _place_finished(main: Node, type_id: String, at: Vector3) -> Node:
	var gm = main.grid_manager
	var b = main.build_system.place_building(type_id, gm.world_to_cell(at), main.buildings_container, true, at)
	if b != null and b.has_method("complete_construction"):
		b.complete_construction()
	return b

func _open_ground(main: Node, type_id: String, offset: Vector3) -> Vector3:
	var gm = main.grid_manager
	var core: Vector3 = gm.cell_to_world(config_node.MAP["default_core_cell"])
	for extra in [Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 2.0), Vector3(-2.0, 0.0, 2.0)]:
		var at: Vector3 = core + offset + extra
		if main.build_system.can_place_building(type_id, gm.world_to_cell(at), false, at):
			return at
	return Vector3.INF

# ==============================================================================
# The option panel, in each thing it can show
# ==============================================================================

func test_01_the_heros_panel() -> void:
	# His build menu: Build, every kind of building in it, Back.
	var main = await _level()
	_select(main.hero)
	await wait_frames(1)
	var pressed: int = await _press_everything(main.hud, "hero")
	assert_gt(pressed, 1, "The Hero's panel had buttons to press (%d)" % pressed)
	assert_true(is_instance_valid(main.hero), "And the game is still there")

func test_02_a_buildings_panel() -> void:
	# Repair (so each is damaged first) and demolish, on a stake and on a turret.
	var main = await _level()
	for spec in [["wall", Vector3(-5.0, 0.0, 5.0)], ["tower", Vector3(5.0, 0.0, 5.0)]]:
		var at: Vector3 = _open_ground(main, String(spec[0]), spec[1])
		if at == Vector3.INF:
			_record_fail("No open ground for a %s" % spec[0])
			continue
		var b = _place_finished(main, String(spec[0]), at)
		assert_not_null(b, "A %s was built" % spec[0])
		if b == null:
			continue
		b.take_damage(b.max_hp * 0.5)
		_select(b)
		await wait_frames(1)
		var pressed: int = await _press_everything(main.hud, String(spec[0]))
		assert_gt(pressed, 0, "The %s's panel had buttons to press" % spec[0])
	assert_true(is_instance_valid(main.hero), "And the game is still there")

func test_03_a_tree_and_a_rock() -> void:
	var main = await _level()
	var seen: int = 0
	for node in main.resource_nodes_container.get_children():
		_select(node)
		await wait_frames(1)
		await _press_everything(main.hud, "node:%s" % node.name)
		seen += 1
	assert_gt(seen, 0, "There were resource nodes to look at")

func test_04_every_bench_in_the_cabin() -> void:
	# Inside, each bench's recipes -- with everything in the warehouse, so every one of
	# them can actually be made.
	var main = await _level()
	assert_true(main.has_method("enter_cabin"), "The cabin can be entered")
	main.enter_cabin()
	await wait_frames(2)
	var stations: Array = main.cabin_interior.stations if main.cabin_interior != null and "stations" in main.cabin_interior else []
	assert_gt(stations.size(), 0, "There are benches inside")
	var recipes: int = 0
	for station in stations:
		_fill_the_warehouse()
		_select(station)
		await wait_frames(1)
		recipes += await _press_everything(main.hud, "station:%s" % station.name)
	assert_gt(recipes, 0, "Their recipes were there to press (%d)" % recipes)
	main.leave_cabin()
	await wait_frames(2)
	assert_false(main.in_cabin, "And back out again")

# ==============================================================================
# The top bar and the pause menu
# ==============================================================================

func test_05_the_top_bar() -> void:
	# Speed (round the whole cycle), pause (on and off), and end-the-deploy-early --
	# which starts the raid, so the raid then runs for a while with nothing held back.
	var main = await _level()
	var hud = main.hud
	for i in range(4):
		hud.speed_btn.pressed.emit()
		await wait_frames(1)
	hud.pause_btn.pressed.emit()
	await wait_frames(1)
	hud.pause_btn.pressed.emit()
	await wait_frames(1)
	hud.end_action_btn.pressed.emit()
	await wait_physics_frames(60 * 6)
	assert_true(is_instance_valid(main.hero), "Six seconds of raid later, the game is still there")

func test_06_restart() -> void:
	var main = await _level()
	_place_finished(main, "wall", _open_ground(main, "wall", Vector3(-5.0, 0.0, 5.0)))
	main.hud.restart_btn.pressed.emit()
	await wait_frames(4)
	assert_true(is_instance_valid(main.hero), "A restarted level has its Hero")
	assert_eq(main.current_build_type, "", "And nothing in hand")

func test_07_the_pause_menu_and_everything_in_it() -> void:
	# Every button in it but Quit, and every item in both pickers -- the language and the
	# window mode -- in the same order a player would try them.
	var main = await _level()
	var hud = main.hud
	hud.toggle_pause_menu()
	await wait_frames(1)
	assert_true(hud.is_pause_menu_open(), "The menu opened")
	var menu: Node = hud.find_child("PauseMenu", true, false)
	assert_not_null(menu, "It is there to press things in")
	if menu == null:
		return
	await _press_everything(menu, "pause", ["QuitBtn", "ResumeBtn"])
	for picker_name in ["language_picker", "window_picker"]:
		if not (picker_name in menu):
			continue
		var picker: OptionButton = menu.get(picker_name)
		if picker == null:
			continue
		for i in range(picker.item_count):
			picker.item_selected.emit(i)
			await wait_frames(1)
	if "resume_btn" in menu and menu.resume_btn != null:
		menu.resume_btn.pressed.emit()
	await wait_frames(1)
	assert_true(is_instance_valid(main.hero), "And the game is still there")

func test_08_the_fullscreen_key() -> void:
	# F11 is read by an autoload, not by the level, so it has a road of its own.
	var main = await _level()
	var window_mode: Node = tree.root.get_node_or_null("WindowMode")
	assert_not_null(window_mode, "The window-mode autoload is there")
	if window_mode == null:
		return
	for _i in range(2):
		var e := InputEventKey.new()
		e.keycode = KEY_F11
		e.physical_keycode = KEY_F11
		e.pressed = true
		window_mode._shortcut_input(e)
		await wait_frames(1)
	assert_true(is_instance_valid(main.hero), "Twice toggled, and the game is still there")
