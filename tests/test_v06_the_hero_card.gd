# res://tests/test_v06_the_hero_card.gd
# v0.6 round four: "还有一个界面问题，就是surviver面板太大，大部分时间都是要选着这个人到处采到处造，这个面板就
# 一直占着游戏版面，使得游戏游玩时大多数都被这个面板挡着了，有没有方法既方便建造有不要一直显示着这个面板？可以参考
# 一下各个经典游戏怎么处理这个问题的" -- and then: "属性卡按C打开，内容和原来应该稍微有些区别，最好建造和吃的两个
# 图标不要变动位置，就在右下角原处（除了按c打开点击左下头像应该也可以打开）".
#
# His two commands, Build and Eat, are tiles in the bottom right corner, there all the while and never
# moving; chosen, he has no card open. A menu comes up above its tile and goes once a building is in
# hand (Age of Empires IV, StarCraft II); his sheet -- no commands on it -- opens on the details key or
# his medallion, as C opens the character sheet in Diablo IV, and the cancel key shuts it. His health
# and his meal are on his medallion all the while. Anything else chosen shows its whole card, above
# his tiles too; the number keys are whichever has commands on them.
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

func _details_key() -> int:
	return int(config_node.CONTROLS["details_key"])

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

func _shown(node: Control) -> bool:
	return node != null and node.is_visible_in_tree()

func _tiles(main: Node) -> Node:
	return main.hud.hero_commands

## His medallion clicked, as the status bar's test clicks it.
func _click_medallion(main: Node) -> void:
	var medallion: Control = main.hud.root_control.find_child("HeroEmblem", true, false) as Control
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	medallion.gui_input.emit(click)
	await wait_frames(2)

func _card_width() -> float:
	return float(config_node.UI["option_panel_size"].x)

## A whole section of fence by him.
func _fence(main: Node) -> Node:
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.hero.global_position) + Vector2i(4, 4)
	var wall = main.build_system.place_at("wall", cell, main.buildings_container, false)
	if not wall.is_constructed:
		wall.complete_construction()
	return wall

func test_01_chosen_he_has_his_two_commands_in_the_corner_and_no_card() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	panel.select_target(main.hero)
	await wait_frames(2)
	assert_not_null(tiles, "His commands stand on their own")
	if tiles == null:
		return
	assert_eq(panel.view(), "none", "Chosen, he has no card open")
	assert_false(panel.visible, "none is shown")
	assert_eq([String(tiles.build_button.name), String(tiles.eat_button.name)], ["BuildCommand", "EatCommand"],
		"Build and Eat")
	var corner: Vector2 = tiles.get_parent_area_size() - Vector2.ONE * float(config_node.UI["option_panel_margin"])
	assert_almost_eq(tiles.get_rect().end.x, corner.x, 1.0, "in the bottom right corner")
	assert_almost_eq(tiles.get_rect().end.y, corner.y, 1.0, "at its foot")
	assert_true(tiles.keys_live(), "on the first number keys")
	var cap: Label = tiles.build_button.get_node_or_null("Keycap") as Label
	assert_true(cap != null and cap.visible and cap.text == OS.get_keycode_string(int(_keys()[0])), "Build wears the first")
	assert_true(_shown(main.hud.root_control.find_child("HeroEmblem", true, false) as Control),
		"His health and his meal are on his medallion all the while")

func test_02_his_commands_never_move_and_every_card_stands_above_them() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	panel.select_target(main.hero)
	await wait_frames(2)
	var home: Rect2 = tiles.get_global_rect()
	var wall = _fence(main)
	var steps: Array = [
		["his build menu", func(): panel.show_menu("build")],
		["his meals", func(): panel.show_menu("eat")],
		["his sheet", func(): panel.show_details(true)],
		["a fence's card", func(): tree.root.get_node("EventBus").unit_selected.emit(wall)],
	]
	for step in steps:
		step[1].call()
		await wait_frames(2)
		assert_true(panel.visible, "%s is shown" % step[0])
		assert_eq(tiles.get_global_rect(), home, "with %s open, his commands have not moved" % step[0])
		assert_true(_shown(tiles), "nor gone")
		assert_lte(panel.get_global_rect().end.y, home.position.y, "%s stands above them" % step[0])
		assert_almost_eq(panel.get_global_rect().end.x, home.end.x, 1.0, "its right edge on theirs")

func test_03_build_comes_up_above_its_tile_and_a_building_in_hand_puts_it_away() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	panel.select_target(main.hero)
	await wait_frames(1)
	await _press(int(_keys()[0]))
	assert_eq(panel.view(), "menu", "The first key brings the build menu")
	assert_true(tiles.build_button.button_pressed, "its tile pressed in while it is open")
	assert_false(_shown(panel.header), "What it offers and nothing of him: not his name")
	assert_false(_shown(panel.hero_stats), "nor his bars")
	assert_eq(panel.status_label.text, tr("BUILD_HINT_PICK"), "The line asks for a pick while none is under the cursor")
	var cards: int = 0
	for btn in _buttons(panel):
		if String(btn.theme_type_variation) == "CardButton":
			cards += 1
	assert_eq(cards, panel._shown_buildables().size(), "A card for each thing he can build")
	assert_false(tiles.keys_live(), "The number keys are the menu's now")
	assert_false((tiles.build_button.get_node("Keycap") as Control).visible, "and no key is shown twice")
	await _press(int(_keys()[0]))
	assert_ne(String(main.current_build_type), "", "The first key takes the first building in hand")
	assert_eq(panel.view(), "none", "and the menu goes: the ground it goes on is what matters now")
	assert_false(tiles.build_button.button_pressed, "its tile out again")
	assert_true(tiles.keys_live(), "the keys his commands' again")
	await _press(int(_keys()[0]))
	assert_eq(panel.view(), "menu", "The menu is a key away for the next")
	tiles.build_button.emit_signal("pressed")
	await wait_frames(1)
	assert_eq(panel.view(), "none", "Its tile pressed again, it goes")
	main.cancel_building_selection()

func test_04_eat_brings_the_meals_and_one_eaten_puts_them_away() -> void:
	var main = await _level()
	game_state_node.stock_meal("meat")
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	panel.select_target(main.hero)
	await wait_frames(1)
	await _press(int(_keys()[1]))
	assert_eq(panel.view(), "menu", "The second key brings the meals")
	assert_true(tiles.eat_button.button_pressed, "its tile pressed in")
	assert_eq(panel.status_label.text, tr("EAT_HINT_PICK"), "asking for one")
	await _press(int(_keys()[0]))
	assert_true(main.hero.is_eating(), "The first key eats the first")
	assert_eq(panel.view(), "none", "and the meals go")

func test_05_the_details_key_opens_his_sheet_with_no_commands_on_it() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	panel.select_target(main.hero)
	await wait_frames(1)
	await _press(_details_key())
	assert_eq(panel.view(), "full", "The details key opens his sheet")
	assert_true(_shown(panel.header), "his portrait and his name")
	assert_true(_shown(panel.hero_stats), "his bars, his meal and his kit")
	assert_eq(_buttons(panel).size(), 0, "and no commands: they stay below, where they always are")
	assert_true(tiles.keys_live(), "on their keys")
	assert_almost_eq(panel.size.x, _card_width(), 1.0, "The card's width")
	await _press(_details_key())
	assert_eq(panel.view(), "none", "Again, and it shuts")
	await _press(_details_key())
	await _press(int(config_node.CONTROLS["cancel_key"]))
	assert_eq(panel.view(), "none", "The cancel key shuts it too")
	assert_false(main.hud.is_pause_menu_open(), "before it opens the menu")

func test_06_from_a_menu_the_details_key_shows_his_sheet() -> void:
	# Not a toggle that shuts what was never shown: from the build menu, it is his sheet.
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel.show_menu("build")
	await wait_frames(1)
	await _press(_details_key())
	assert_eq(panel.view(), "full", "From the build menu, his sheet")

func test_07_his_medallion_picks_him_and_opens_his_sheet() -> void:
	var main = await _level()
	stock_everything()
	var wall = _fence(main)
	tree.root.get_node("EventBus").unit_selected.emit(wall)
	await wait_frames(1)
	var panel = main.hud.option_panel
	assert_eq(panel.view(), "full", "Something else chosen shows its whole card")
	await _click_medallion(main)
	assert_eq(panel.selected_unit, main.hero, "His medallion picks him")
	assert_true(panel.showing_details(), "and opens his sheet")
	await _click_medallion(main)
	assert_eq(panel.selected_unit, main.hero, "Again: still him")
	assert_eq(panel.view(), "none", "and no card")
	var cap: Label = main.hud.root_control.find_child("HeroEmblem", true, false).find_child("Keycap", true, false) as Label
	assert_not_null(cap, "The medallion wears the details key")
	if cap:
		assert_eq(cap.text, OS.get_keycode_string(_details_key()), "on a chip")

func test_08_another_subject_or_a_cleared_one_starts_his_card_shut() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel.show_details(true)
	await wait_frames(1)
	var wall = _fence(main)
	tree.root.get_node("EventBus").unit_selected.emit(wall)
	await wait_frames(1)
	await _press(int(config_node.CONTROLS["cancel_key"]))
	assert_eq(panel.selected_unit, main.hero, "The fence let go, the card is his again")
	assert_eq(panel.view(), "none", "and shut: what was opened for him before is not opened again")
	panel.show_details(true)
	tree.root.get_node("EventBus").unit_deselected.emit()
	await wait_frames(1)
	assert_eq(panel.view(), "none", "A click on the bare ground shuts it as well")

func test_09_the_keys_are_whichever_has_commands_on_them() -> void:
	# A whole fence's card has nothing on a key (pulling it down is pressed by hand): the keys stay his
	# commands'. A bitten one's has Repair: they are the card's. His tiles answer the mouse either way.
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	var eb = tree.root.get_node("EventBus")
	var wall = _fence(main)
	eb.unit_selected.emit(wall)
	await wait_frames(1)
	assert_true(tiles.keys_live(), "A whole fence chosen, the keys are still his commands'")
	wall.take_damage(wall.max_hp * 0.5)
	eb.unit_selected.emit(wall)
	await wait_frames(1)
	assert_false(tiles.keys_live(), "A bitten one's Repair is on a key: they are its card's")
	tiles.build_button.emit_signal("pressed")
	await wait_frames(1)
	assert_eq(panel.selected_unit, main.hero, "Build pressed picks him")
	assert_eq(panel.view(), "menu", "and brings his build menu")

func test_10_at_the_end_of_the_run_they_go_and_at_a_restart_they_are_back() -> void:
	var main = await _level()
	var tiles = _tiles(main)
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel.show_details(true)
	await wait_frames(1)
	tree.root.get_node("EventBus").game_lost.emit()
	await wait_frames(2)
	assert_false(_shown(tiles), "The run over, his commands go")
	assert_false(panel.visible, "and the card")
	main.hud.reset_hud()
	await wait_frames(1)
	assert_true(_shown(tiles), "Back at a restart")
	assert_eq(panel.view(), "none", "with no card open")
