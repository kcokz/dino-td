# res://tests/test_v07_the_journal.gd
# The player, 2026-10-04: "Beacon右上角的提示应该不要一直显示，用专业游戏的best practice应该有个类似日志或者任务之类的显示方法，
# 而且不要突兀的直接显示，应该有个前因后果的引入（这个是过关游戏特有，自定义没有的）".
#
# In our own game, out of the crashed capsule he says what has happened and what he must do (Config.STORY), and only
# then is the beacon his goal: the journal begun, its card come in. The card is folded to its mark -- what is to be
# done next only with news, under the cursor, or with the journal open. J (or a click on the card) opens the journal:
# the goal now, the cabin's power, the story so far. A custom game has no opening and no journal.
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
		game_state_node.game = {}
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null:
		game_state_node.game = {}
		game_state_node.reset_game()
	super.after_each()

## A level of our own game (Config.GAMES.campaign: its story).
func _ours() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	game_state_node.play("campaign")
	game_state_node.reset_game()
	main.hud.reset_hud(true)
	await wait_frames(1)
	return main

func test_01_out_of_the_capsule_he_says_why_and_then_the_goal_is_his() -> void:
	var main = await _ours()
	var hud = main.hud
	hud.hold_objective()
	assert_false(hud.is_objective_given(), "The goal held back")
	assert_false(hud.objective_panel.visible, "its card not up yet")
	var said: Array = []
	var eb = tree.root.get_node("EventBus")
	var hear := func(key: String, _s: float, _a: Array) -> void: said.append(key)
	eb.hero_spoke.connect(hear)
	await hud.tell_the_story(0.02)
	eb.hero_spoke.disconnect(hear)
	var intro: Array = config_node.STORY["intro"]
	assert_eq(said.slice(0, intro.size()), intro, "He says the story's lines, in their order")
	assert_true(hud.is_objective_given(), "and then the goal is his")
	assert_true(hud.objective_panel.visible, "its card come in")
	assert_true(hud.objective_open(), "open a while with the news")
	var titles: Array = hud.journal_entries().map(func(e): return String(e[0]))
	assert_eq(titles, [tr("JOURNAL_CRASH_TITLE"), tr("JOURNAL_BEACON_TITLE")], "The journal begun: the crash, then the beacon")
	assert_true(hud.hint_label.text.contains(tr("JOURNAL_BEACON_TITLE")), "and it says so: %s" % hud.hint_label.text)

func test_02_the_card_is_folded_to_its_mark_but_with_news_or_under_the_cursor() -> void:
	var main = await _ours()
	var hud = main.hud
	hud.give_objective(false)
	hud._objective_open_ms = 0
	hud._fold_objective()
	assert_true(hud.objective_panel.visible, "The goal's card is up")
	assert_false(hud.objective_detail.visible, "folded: what is to be done next not shown")
	assert_true(hud.find_child("ObjectiveTitle", true, false).is_visible_in_tree(), "its name and mark are")
	hud._objective_hovered = true
	hud._fold_objective()
	assert_true(hud.objective_detail.visible, "Under the cursor it opens")
	hud._objective_hovered = false
	hud._fold_objective()
	assert_false(hud.objective_detail.visible, "and folds again")
	tree.root.get_node("EventBus").beacon_changed.emit(1)
	assert_true(hud.objective_detail.visible, "News -- a stage done -- opens it")
	var titles: Array = hud.journal_entries().map(func(e): return String(e[0]))
	assert_true(titles.has(tr("JOURNAL_STAGE_TITLE") % 1), "and is written in the journal")

func test_03_j_opens_the_journal_and_esc_shuts_it() -> void:
	var main = await _ours()
	var hud = main.hud
	hud.give_objective(false)
	var ev := InputEventKey.new()
	ev.keycode = Keys.key("journal_key")
	ev.pressed = true
	main._unhandled_input(ev)
	await wait_frames(1)
	assert_true(hud.is_journal_open(), "J opens the journal")
	assert_true(hud.objective_detail.visible, "the goal's card open beside it")
	var text: String = ""
	for n in hud.journal_panel.find_children("*", "Label", true, false):
		text += (n as Label).text + "\n"
	assert_true(text.contains(tr("JOURNAL_NOW")) and text.contains(tr("JOURNAL_BEACON_TITLE")), "the goal now, and the story so far")
	assert_true(text.contains(tr("JOURNAL_POWER").get_slice("%", 0)), "and the cabin's power")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	main._unhandled_input(esc)
	await wait_frames(1)
	assert_false(hud.is_journal_open(), "Esc shuts it")
	assert_false(hud.is_pause_menu_open(), "before it would open the menu")

func test_04_a_custom_game_has_no_opening_and_no_journal() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	game_state_node.play("custom", {"map": "small"})
	game_state_node.reset_game()
	main.hud.reset_hud(true)
	var hud = main.hud
	var said: Array = []
	var eb = tree.root.get_node("EventBus")
	var hear := func(key: String, _s: float, _a: Array) -> void: said.append(key)
	eb.hero_spoke.connect(hear)
	hud.hold_objective()
	await hud.tell_the_story(0.02)
	eb.hero_spoke.disconnect(hear)
	assert_false(said.has(String(config_node.STORY["intro"][0])), "No opening")
	assert_true(hud.is_objective_given(), "the goal at once")
	assert_eq(hud.journal_entries().size(), 0, "and no journal")
	hud.toggle_journal()
	assert_false(hud.is_journal_open(), "J opens nothing")
