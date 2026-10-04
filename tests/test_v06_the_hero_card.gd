# res://tests/test_v06_the_hero_card.gd
# v0.6 round four: "还有一个界面问题，就是surviver面板太大，大部分时间都是要选着这个人到处采到处造，这个面板就
# 一直占着游戏版面，使得游戏游玩时大多数都被这个面板挡着了，有没有方法既方便建造有不要一直显示着这个面板？可以参考
# 一下各个经典游戏怎么处理这个问题的" -- and then: "属性卡按C打开，内容和原来应该稍微有些区别，最好建造和吃的两个
# 图标不要变动位置，就在右下角原处（除了按c打开点击左下头像应该也可以打开）".
#
# His commands are tiles in the bottom right corner, there all the while and never moving: Build from the
# first, at the right end, and each other as it becomes his to the left of those there, on the next
# number key -- Rest the first time he is hurt (v0.7, where Eat came with the first meal), Torch with the
# first dusk ("Build 按钮放最右边，哪个能力先解锁放哪个在靠右，以此类推，吃一开始隐藏因为没有食物，火把也是").
# Chosen, he has no card open. A menu comes up above its tile and goes once a building is in hand (Age of
# Empires IV, StarCraft II); his sheet -- no commands on it -- opens on the details key or his medallion,
# as C opens the character sheet in Diablo IV, and the cancel key shuts it. His health is on his
# medallion all the while. Anything else chosen shows its whole card, above his tiles too; the number
# keys are whichever has commands on them.
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

func test_01_chosen_he_has_his_commands_in_the_corner_and_no_card() -> void:
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
	assert_true(_shown(tiles.build_button), "Build")
	assert_false(tiles.rest_button.visible, "and nothing else yet: Rest comes the first time he is hurt")
	assert_false(tiles.torch_button.visible, "and Torch with the first dusk")
	var corner: Vector2 = tiles.get_parent_area_size() - Vector2.ONE * float(config_node.UI["option_panel_margin"])
	assert_almost_eq(tiles.get_rect().end.x, corner.x, 1.0, "in the bottom right corner")
	assert_almost_eq(tiles.get_rect().end.y, corner.y, 1.0, "at its foot")
	assert_true(tiles.keys_live(), "on the first number keys")
	var cap: Label = tiles.build_button.get_node_or_null("Keycap") as Label
	assert_true(cap != null and cap.visible and cap.text == OS.get_keycode_string(int(_keys()[0])), "Build wears the first")
	assert_true(_shown(main.hud.root_control.find_child("HeroEmblem", true, false) as Control),
		"His health is on his medallion all the while")

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

func test_04_rest_sends_him_home_to_the_pod_and_again_calls_him_off() -> void:
	# v0.7 (GAME-DESIGN 3.0): where Eat was, Rest -- an order, not a menu: home to the healing pod.
	var main = await _level()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	panel.select_target(main.hero)
	main.hero.take_damage(2.0)
	await wait_frames(2)
	assert_true(_shown(tiles.rest_button), "Bitten, Rest has come")
	var pod = HealingPod.of(tree)
	assert_not_null(pod, "The cabin has its pod")
	await _press(int(_keys()[1]))
	assert_eq(main.hero.rest_pod(), pod, "The second key sends him to the pod")
	assert_true(tiles.rest_button.button_pressed, "its tile pressed in while he goes")
	assert_eq(panel.view(), "none", "and no menu comes up: it is an order")
	await _press(int(_keys()[1]))
	assert_null(main.hero.rest_pod(), "Pressed again, he is called off")
	assert_false(tiles.rest_button.button_pressed, "its tile out again")

func test_05_the_details_key_opens_his_sheet_with_no_commands_on_it() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	panel.select_target(main.hero)
	await wait_frames(1)
	await _press(_details_key())
	assert_eq(panel.view(), "full", "The details key opens his sheet")
	assert_true(_shown(panel.header), "his portrait and his name")
	assert_true(_shown(panel.hero_stats), "his health and his tools")
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
	# A whole gate's card has nothing on a key (pulling it down is pressed by hand): the keys stay his
	# commands'. A fence's has its ways up (v0.6 round six: bone stakes, a stone wall), a bitten one's
	# Repair: they are the card's. His tiles answer the mouse either way.
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	var tiles = _tiles(main)
	var eb = tree.root.get_node("EventBus")
	var gm = main.grid_manager
	var gate = main.build_system.place_at("gate", gm.world_to_build_cell(main.hero.global_position) + Vector2i(-4, 4),
		main.buildings_container, false)
	if not gate.is_constructed:
		gate.complete_construction()
	eb.unit_selected.emit(gate)
	await wait_frames(1)
	assert_true(config_node.upgrade_targets("gate").is_empty(), "(a gate has no way up)")
	assert_true(tiles.keys_live(), "A whole gate chosen, the keys are still his commands'")
	var wall = _fence(main)
	eb.unit_selected.emit(wall)
	await wait_frames(1)
	assert_false(tiles.keys_live(), "A fence's ways up are on keys: they are its card's")
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

func test_11_each_command_comes_in_to_the_left_as_it_becomes_his_and_stays() -> void:
	# The player: "Build 按钮放最右边，哪个能力先解锁放哪个在靠右，以此类推，吃一开始隐藏因为没有食物，火把也是".
	var main = await _level()
	var tiles: HeroCommands = _tiles(main)
	var keys: Array = _keys()
	await wait_frames(2)
	assert_true(_shown(tiles.build_button), "Build is there from the first")
	assert_false(tiles.rest_button.visible, "Rest is not: nothing has bitten him")
	assert_false(tiles.torch_button.visible, "nor Torch: it is morning")
	var build_at: Vector2 = _place(tiles.build_button)
	# The first dusk before the first bite: Torch is the first to come.
	_set_clock(_at("dusk") + 1.0)
	await wait_frames(2)
	assert_true(tiles.torch_button.visible, "The first dusk, Torch comes")
	assert_lt(_place(tiles.torch_button).x, build_at.x, "to Build's left")
	assert_eq(_place(tiles.build_button), build_at, "Build where it was")
	assert_eq(_key_on(tiles.torch_button), int(keys[1]), "on the second key, the first to come")
	var torch_at: Vector2 = _place(tiles.torch_button)
	main.hero.take_damage(1.0)
	await wait_frames(2)
	assert_true(tiles.rest_button.visible, "The first bite, Rest comes")
	assert_lt(_place(tiles.rest_button).x, torch_at.x, "to the left of both")
	assert_eq([_place(tiles.build_button), _place(tiles.torch_button)], [build_at, torch_at],
		"and neither moves")
	assert_eq(_key_on(tiles.rest_button), int(keys[2]), "on the third key")
	# Come, they stay: greyed out while they cannot be pressed, so none moves.
	var rest_at: Vector2 = _place(tiles.rest_button)
	main.hero.heal(main.hero.max_hp)
	_set_clock(_at("day") + 100.0, 2)
	await wait_frames(2)
	assert_true(tiles.torch_button.visible and tiles.torch_button.disabled, "By day the torch's is there, greyed out")
	assert_true(tiles.rest_button.visible and tiles.rest_button.disabled, "and with him whole, Rest's")
	assert_eq([_place(tiles.build_button), _place(tiles.torch_button), _place(tiles.rest_button)],
		[build_at, torch_at, rest_at], "none has moved")
	# Its words put into another language, it is the same run (HUD._on_locale_changed).
	tree.root.get_node("EventBus").locale_changed.emit(TranslationServer.get_locale())
	await wait_frames(2)
	assert_true(tiles.torch_button.visible and tiles.rest_button.visible, "In another language they are still there")
	assert_eq([_key_on(tiles.torch_button), _key_on(tiles.rest_button)], [int(keys[1]), int(keys[2])], "on their keys")
	# A new run: Build alone again -- and this time bitten first.
	main.restart_game()
	await wait_frames(2)
	assert_false(tiles.rest_button.visible or tiles.torch_button.visible, "A new run, Build alone again")
	main.hero.take_damage(1.0)
	await wait_frames(2)
	assert_eq(_key_on(tiles.rest_button), int(keys[1]), "Rest the first to come this time: the second key")
	_set_clock(_at("dusk") + 1.0)
	await wait_frames(2)
	assert_eq(_key_on(tiles.torch_button), int(keys[2]), "and Torch the third")
	assert_lt(_place(tiles.torch_button).x, _place(tiles.rest_button).x, "to Rest's left")
	assert_eq(_place(tiles.build_button), build_at, "Build where it always is")

func test_12_a_command_come_is_seen_arriving_and_one_he_cannot_give_is_plainly_dull() -> void:
	# The debug-agent's TASK-024: "新按钮出现时……不太注意得到"; "灰得太淡：没饭的'吃饭'（灰）和能点的'火把'几乎
	# 一样亮".
	var main = await _level()
	var tiles: HeroCommands = _tiles(main)
	await wait_frames(2)
	_set_clock(_at("dusk") + 1.0)
	var torch: Button = tiles.torch_button
	var lit: Color = torch.modulate
	assert_gt(lit.r, 1.0, "Come, it is lit up")
	# Laid out by its row a frame on, and still growing: a row sets its tiles' scale back to one as it
	# lays them out, and it had grown in from its full size (the debug-agent's BUG-024).
	await wait_frames(2)
	assert_lt(torch.scale.x, 0.95, "and grows in, after its row has laid it out")
	await wait_seconds(float(config_node.THEME["come_seconds"]) + 0.2)
	assert_almost_eq(torch.modulate.r, 1.0, 0.02, "the light fades")
	assert_almost_eq(torch.scale.x, 1.0, 0.02, "at its size")
	# One he cannot give is plainly dull: its icon greyed down, its word faint.
	var off: Color = torch.get_theme_color("icon_disabled_color")
	var on: Color = torch.get_theme_color("icon_normal_color")
	assert_lt(off.v * off.a, on.v * on.a * 0.5, "A greyed command's icon is not half as bright as one to press")
	assert_eq(torch.get_theme_color("font_disabled_color"), UiTheme.color("ink_faint"), "and its word faint")
	# Rest can be pressed while he is hurt, and not when he is whole.
	main.hero.take_damage(1.0)
	await wait_frames(1)
	assert_false(tiles.rest_button.disabled, "Hurt, Rest can be pressed")
	main.hero.heal(main.hero.max_hp)
	await wait_frames(1)
	assert_true(tiles.rest_button.disabled, "whole, it cannot")

## Where the corner lays `btn` out, on the screen: not where it is drawn while it grows in (UiKit.come_in),
## which is about its middle.
func _place(btn: Control) -> Vector2:
	return (btn.get_parent() as Control).global_position + btn.position

## The key that presses `btn`, or -1 for none.
func _key_on(btn: Button) -> int:
	return int(btn.shortcut.events[0].keycode) if (btn.shortcut != null and not btn.shortcut.events.is_empty()) else -1

func _at(part: String) -> float:
	return float(config_node.DAY["parts"][part])

## Sets the clock to `t` seconds into day `day`, and says the part of the day that is.
func _set_clock(t: float, day: int = 1) -> void:
	game_state_node.day_clock = float(day - 1) * float(config_node.DAY["length"]) + t
	game_state_node._run_the_day(0.0)
