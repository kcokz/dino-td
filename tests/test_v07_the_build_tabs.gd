# res://tests/test_v07_the_build_tabs.gd
# The player, 2026-10-05: "看看因为科技多了，界面是不是要改的更简洁，比如建造栏可以造的如果太多就会很confusing".
#
# HIS BUILD MENU IN TABS (OptionPanel; Config.BUILD_TABS, BUILDINGS.<id>.tab): what he can build sorted by what it is for
# -- the towers; the walls and what is laid in the way; the camp -- one tab shown at a time, a tab only while something in
# it can be built. The tab is kept for the run, the number keys pick the open tab's cards, and the tab key goes round.
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

## A key pressed and let go, through the engine's own input.
func _press(keycode: int, shift: bool = false) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode as Key
		ev.physical_keycode = keycode as Key
		ev.shift_pressed = shift
		ev.pressed = down
		Input.parse_input_event(ev)
		await wait_frames(2)

func _cards(panel: Node) -> Array:
	var out: Array = []
	for child in panel.button_container.get_children():
		if child is Button and not child.is_queued_for_deletion() and String(child.theme_type_variation) == "CardButton":
			out.append(child)
	return out

func _tab_buttons(panel: Node) -> Array:
	var out: Array = []
	for child in panel.build_tabs_row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			out.append(child)
	return out

## The key on the tabs' row, or null.
func _tab_keycap(panel: Node) -> Label:
	for child in panel.build_tabs_row.get_children():
		if child is Label and String(child.name) == "Keycap" and not child.is_queued_for_deletion():
			return child
	return null

func test_01_every_buildable_stands_in_one_named_tab() -> void:
	var ids: Array = []
	for tab in config_node.BUILD_TABS:
		ids.append(String(tab["id"]))
		for locale in ["en", "zh_CN"]:
			var t: Translation = TranslationServer.get_translation_object(locale)
			assert_true(t != null and String(t.get_message(String(tab["name"]))) != "", "The %s tab is named in %s" % [tab["id"], locale])
		assert_true(ResourceLoader.exists(String(config_node.ICON_DIR) + String(tab["icon"]) + ".svg"), "and drawn (%s)" % tab["icon"])
	var used: Dictionary = {}
	for b_type in config_node.BUILDABLE_TYPES:
		var tab: String = String(config_node.BUILDINGS[b_type].get("tab", ""))
		assert_has(ids, tab, "%s says its tab, one of BUILD_TABS" % b_type)
		used[tab] = true
	for id in ids:
		assert_true(used.has(id), "The %s tab has something in it" % id)

func test_02_the_menu_shows_one_tab_at_a_time_and_its_cards_are_that_tabs() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(1)
	var tabs: Array = panel._shown_tabs()
	assert_gt(tabs.size(), 1, "More than one tab with something in it")
	assert_true(panel.build_tabs_row.visible, "The tabs show over the cards")
	assert_eq(_tab_buttons(panel).size(), tabs.size(), "a button a tab")
	assert_eq(String(panel.build_tab), String(config_node.BUILD_TABS[0]["id"]), "Opened the first time, on the first tab")
	var seen: Dictionary = {}
	for tab in tabs:
		panel.show_build_tab(String(tab))
		await wait_frames(1)
		var cards: Array = _cards(panel)
		assert_eq(cards.size(), panel._tab_buildables(String(tab)).size(), "The %s tab: a card for each of its own" % tab)
		for b_type in panel._menu_types:
			assert_eq(String(config_node.build_tab_of(String(b_type))), String(tab), "%s is the %s tab's" % [b_type, tab])
			seen[b_type] = true
		var lit: int = 0
		for btn in _tab_buttons(panel):
			if btn.button_pressed:
				lit += 1
				assert_eq(String(btn.name), "Tab_" + String(tab), "the tab open is the one sunk and lit")
		assert_eq(lit, 1, "one tab lit at a time")
	assert_eq(seen.size(), panel._shown_buildables().size(), "Between them, everything he can build")
	# Not his build menu: no tabs.
	panel._on_back_pressed()
	await wait_frames(1)
	assert_false(panel.build_tabs_row.visible, "Out of the menu, no tabs")

func test_03_a_tab_only_while_something_in_it_can_be_built() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(1)
	var want: Dictionary = {}
	for b_type in panel._shown_buildables():
		want[String(config_node.build_tab_of(String(b_type)))] = true
	assert_eq(panel._shown_tabs().size(), want.size(), "A tab for each kind he can build now, and no other")
	for tab in panel._shown_tabs():
		assert_true(want.has(String(tab)), "%s has something in it" % tab)

func test_04_the_tab_is_kept_and_the_keys_pick_its_cards() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(1)
	var tabs: Array = panel._shown_tabs()
	var last: String = String(tabs[tabs.size() - 1])
	panel.show_build_tab(last)
	await wait_frames(1)
	panel._on_back_pressed()
	panel._on_build_pressed()
	await wait_frames(1)
	assert_eq(String(panel.build_tab), last, "Shut and opened again, it opens on the tab he left it at")
	var first: String = String(panel._menu_types[0])
	await _press(int(config_node.CONTROLS["command_keys"][0]))
	assert_eq(String(main.current_build_type), first, "The first key takes the open tab's first card in hand")

func test_05_the_tab_key_goes_round_and_with_shift_back() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(1)
	var tabs: Array = panel._shown_tabs()
	var key: int = int(config_node.CONTROLS["build_tab_key"])
	assert_eq(String(panel.build_tab), String(tabs[0]), "(on the first)")
	await _press(key)
	assert_eq(String(panel.build_tab), String(tabs[1]), "The tab key opens the next tab")
	await _press(key, true)
	assert_eq(String(panel.build_tab), String(tabs[0]), "with Shift, the one before")
	await _press(key, true)
	assert_eq(String(panel.build_tab), String(tabs[tabs.size() - 1]), "and round from the first to the last")
	var cap: Label = _tab_keycap(panel)
	assert_not_null(cap, "The tabs' row wears the key")
	assert_eq(cap.text if cap else "", Keys.text("build_tab_key"), "as the keyboard writes it")
	# Shut, the key is not the menu's.
	panel._on_back_pressed()
	await wait_frames(1)
	var was: String = String(panel.build_tab)
	await _press(key)
	assert_eq(String(panel.build_tab), was, "With the menu shut the tab key does nothing to it")
	assert_has(Keys.names(), "build_tab_key", "and it is one of the keys the settings page sets")
