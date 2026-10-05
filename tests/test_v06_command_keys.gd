# res://tests/test_v06_command_keys.gd
# v0.6 round three: "界面格局还是不够精致……往精致游戏上靠近，比如学习暗黑破坏神4的那种界面风格，或者艾尔登环，
# 界面质感在于细节" -- of the operating panel above all.
#
# The bars in those games mark every slot with the key that presses it. The commands on a card now
# answer to the number keys, in the order they stand (Config.CONTROLS.command_keys), each with its
# key on a chip in its corner; Back is the cancel key's, which peels a submenu off as it does a
# ghost in hand; what cannot be taken back is on no key; and with the menu open the keys go no
# further than the menu.
#
# Everything expected is read from Config.
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
	unlock_all()

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
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _keys() -> Array:
	return config_node.CONTROLS["command_keys"]

## A key pressed and let go, through the engine's own input.
func _press(keycode: int) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode as Key
		ev.physical_keycode = keycode as Key
		ev.pressed = down
		Input.parse_input_event(ev)
		await wait_frames(2)

func _buttons(panel: Node) -> Array[Button]:
	var out: Array[Button] = []
	for child in panel.button_container.get_children():
		if child is Button and not child.is_queued_for_deletion():
			out.append(child)
	return out

func test_01_the_first_key_opens_the_first_command() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	await wait_frames(1)
	var first: Button = main.hud.hero_commands.build_button
	assert_eq(String(first.name), "BuildCommand", "Build is the first of his commands, on the first key")
	await _press(int(_keys()[0]))
	assert_eq(String(panel.current_menu), "build", "and the first number key opens it")

func test_02_every_command_wears_its_key() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(1)
	var n: int = 0
	for btn in _buttons(panel):
		var cap: Label = btn.get_node_or_null("Keycap") as Label
		assert_not_null(cap, "%s has a key on it" % btn.text)
		if cap == null:
			continue
		if btn.name == panel.BACK_NAME:
			assert_eq(cap.text, tr("KEY_CANCEL"), "Back is the cancel key's")
			continue
		assert_eq(cap.text, OS.get_keycode_string(int(_keys()[n])), "%s is key %d" % [btn.text, n + 1])
		assert_true(btn.shortcut != null and btn.shortcut.matches_event(_event(int(_keys()[n]))),
			"and that key presses it")
		assert_false(btn.shortcut_in_tooltip, "the key is not said a second time in its tooltip")
		n += 1
	assert_gt(n, 1, "the build menu is more than one card")

func _event(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	ev.pressed = true
	return ev

func test_03_a_key_picks_a_card_in_the_build_menu() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(1)
	var second: Button = _buttons(panel)[1]
	var wanted: String = String(panel._shown_buildables()[1])
	assert_false(second.disabled, "Stocked, the second card can be taken")
	await _press(int(_keys()[1]))
	assert_eq(String(main.current_build_type), wanted, "The second key puts the second card's building in hand")

func test_04_the_cancel_key_peels_the_ghost_the_submenu_and_his_card() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	var cancel: int = int(config_node.CONTROLS["cancel_key"])
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(1)
	await _press(cancel)
	assert_eq(String(panel.current_menu), "default", "The cancel key shuts the build menu")
	panel._on_build_pressed()
	await wait_frames(1)
	await _press(int(_keys()[0]))
	assert_ne(String(main.current_build_type), "", "A building in hand")
	assert_eq(String(panel.current_menu), "default", "which puts the menu away (v0.6 round four)")
	await _press(cancel)
	assert_eq(String(main.current_build_type), "", "The cancel key puts it down first")
	assert_false(main.hud.is_pause_menu_open(), "not yet the menu")
	await _press(int(config_node.CONTROLS["details_key"]))
	assert_true(panel.showing_details(), "His card open in full")
	await _press(cancel)
	assert_false(panel.showing_details(), "the cancel key shuts it")
	assert_false(main.hud.is_pause_menu_open(), "and not yet the menu")
	await _press(cancel)
	assert_true(main.hud.is_pause_menu_open(), "Nothing left to peel off, it opens the menu")

func test_05_with_the_menu_open_the_keys_go_no_further() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	await wait_frames(1)
	main.hud.toggle_pause_menu()
	assert_true(main.hud.is_pause_menu_open(), "The menu is open")
	await _press(int(_keys()[0]))
	assert_eq(String(panel.current_menu), "default", "and the card behind it does not hear the key")
	main.hud.toggle_pause_menu()

func test_06_what_cannot_be_taken_back_is_on_no_key() -> void:
	var main = await _level()
	stock_everything()
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.hero.global_position) + Vector2i(4, 4)
	var wall = main.build_system.place_at("wall", cell, main.buildings_container, false)
	if not wall.is_constructed:
		wall.complete_construction()
	tree.root.get_node("EventBus").unit_selected.emit(wall)
	await wait_frames(1)
	var panel = main.hud.option_panel
	var demolish: Button = null
	for btn in _buttons(panel):
		if btn.theme_type_variation == &"DangerButton":
			demolish = btn
	assert_not_null(demolish, "A fence can be pulled down")
	if demolish == null:
		return
	assert_null(demolish.shortcut, "but not with a key")
	assert_null(demolish.get_node_or_null("Keycap"), "and it wears none")

func test_07_the_settings_page_says_so() -> void:
	# A control nobody can find is a control nobody has: the settings page's Keys tab lists the card's keys with the
	# camera's -- each command's, and the one that shows all of him -- and what Esc steps back out of (v0.7: and each
	# is set there, Keys).
	var main = await _level()
	var menu = main.hud.pause_menu
	main.hud.toggle_pause_menu()
	menu.open_settings()
	menu.show_settings_tab("keys")
	await wait_frames(1)
	var keys: Array = config_node.CONTROLS["command_keys"]
	for i in keys.size():
		var row: Node = menu.find_child("KeyRow_command_key_%d" % (i + 1), true, false)
		assert_not_null(row, "A row for command %d" % (i + 1))
		if row:
			assert_eq((row.get_node("Key") as Button).text, OS.get_keycode_string(int(keys[i])), "its key")
	var details: Node = menu.find_child("KeyRow_details_key", true, false)
	assert_not_null(details, "and the key that shows all of him")
	if details:
		assert_eq((details.get_node("Key") as Button).text, OS.get_keycode_string(int(config_node.CONTROLS["details_key"])), "its key")
	var line: Label = menu.find_child("CommandKeysLabel", true, false) as Label
	assert_not_null(line, "And what Esc steps back out of")
	if line:
		assert_ne(tr("MENU_COMMAND_KEYS"), "MENU_COMMAND_KEYS", "written down")
		assert_eq(line.text, tr("MENU_COMMAND_KEYS"), "and shown")
		assert_true(line.is_visible_in_tree(), "on the Keys tab")
	main.hud.toggle_pause_menu()
