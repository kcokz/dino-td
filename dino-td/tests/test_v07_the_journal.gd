# res://tests/test_v07_the_journal.gd
# The player, 2026-10-04: "Beacon右上角的提示应该不要一直显示，用专业游戏的best practice应该有个类似日志或者任务之类的显示方法，
# 而且不要突兀的直接显示，应该有个前因后果的引入（这个是过关游戏特有，自定义没有的）".
#
# In our own game, out of the crashed capsule he says what has happened and what he must do (Config.STORY), and only
# then is the beacon his goal: the journal begun, its dial come in beside the cabin's medallion (v0.7, the player:
# "Beacon还是在右上角，界面像网页游戏" -- no card in the corner). The opening skipped, the game holds on the briefing
# instead ("开场故事如果玩家跳过的话，在第一关我们要有明确的类似tutorial的停止方式"). J (or a click on the dial) opens the
# journal: the goal now, the cabin's power, the story so far. A custom game has no opening and no journal.
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
	assert_false(hud.objective_dial.visible, "its dial not up yet")
	var said: Array = []
	var eb = tree.root.get_node("EventBus")
	var hear := func(key: String, _s: float, _a: Array) -> void: said.append(key)
	eb.hero_spoke.connect(hear)
	await hud.tell_the_story(0.02)
	eb.hero_spoke.disconnect(hear)
	var intro: Array = config_node.STORY["intro"]
	assert_eq(said.slice(0, intro.size()), intro, "He says the story's lines, in their order")
	assert_true(hud.is_objective_given(), "and then the goal is his")
	assert_true(hud.objective_dial.visible, "its dial come in")
	assert_null(main.hud.find_child("ObjectiveHeader", true, false), "no card in the corner")
	var titles: Array = hud.journal_entries().map(func(e): return String(e[0]))
	assert_eq(titles, [tr("JOURNAL_CRASH_TITLE"), tr("JOURNAL_BEACON_TITLE")], "The journal begun: the crash, then the beacon")
	assert_true(hud.hint_label.text.contains(tr("JOURNAL_BEACON_TITLE")), "and it says so: %s" % hud.hint_label.text)

func test_02_the_goal_is_a_dial_beside_the_cabins_medallion() -> void:
	var main = await _ours()
	var hud = main.hud
	hud.give_objective(false)
	var dial: Control = hud.objective_dial
	assert_true(dial.visible, "The goal's dial is up")
	var c: Rect2 = hud.core_vital.get_global_rect()
	var d: Rect2 = dial.get_global_rect()
	var day: Rect2 = hud.day_dial.get_global_rect()
	assert_lt(d.get_center().x, c.get_center().x, "beside the cabin's medallion, at its left")
	assert_almost_eq(c.get_center().x - d.get_center().x, day.get_center().x - c.get_center().x, 2.0, "as the day's is at its right")
	assert_almost_eq(d.position.y, day.position.y, 2.0, "level with it")
	assert_eq((dial.get_node("Disc/Keycap") as Label).text, Keys.text("journal_key"), "the journal's key at its shoulder")
	assert_true(dial.tooltip_text.contains(String(game_state_node.objective_status())), "under the cursor, what is to be done next")
	assert_true(dial.tooltip_text.contains(tr("HUD_OBJECTIVE_TIP") % Keys.text("journal_key")), "and where the journal is")
	tree.root.get_node("EventBus").beacon_changed.emit(1)
	var titles: Array = hud.journal_entries().map(func(e): return String(e[0]))
	assert_true(titles.has(tr("JOURNAL_STAGE_TITLE") % 1), "News -- a stage done -- is written in the journal")

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

func test_03b_the_opening_skipped_the_game_holds_on_the_briefing() -> void:
	var main = await _ours()
	var hud = main.hud
	hud.hold_objective()
	game_state_node.is_paused = false
	main.station_jump.was_skipped = true
	main._after_the_crash()
	await wait_frames(1)
	assert_true(hud.is_briefing_open(), "Skipped, the briefing is up")
	assert_true(bool(game_state_node.is_paused), "the game held while it is read")
	assert_false(hud.is_objective_given(), "(the goal not his yet)")
	var text: String = ""
	for n in hud.briefing.find_children("*", "Label", true, false):
		text += (n as Label).text + "\n"
	var days: int = int(round(float(config_node.POWER["lasts_days"])))
	assert_true(text.contains(tr("BRIEFING_BEACON")), "It says what he must do: the beacon")
	assert_true(text.contains(tr("BRIEFING_POWER") % days), "that the capsule's battery runs out, in %d days" % days)
	assert_true(text.contains(tr("BRIEFING_DINOS")), "and what will come for it")
	assert_true(text.contains(tr("BRIEFING_JOURNAL") % Keys.text("journal_key")), "and where it is written")
	hud.briefing.ok_btn.pressed.emit()
	await wait_frames(1)
	assert_false(hud.is_briefing_open(), "Got it: down")
	assert_false(bool(game_state_node.is_paused), "the game going again")
	assert_true(hud.is_objective_given(), "and the goal is his")
	assert_true(hud.objective_dial.visible, "its dial come in")
	assert_eq(hud.journal_entries().size(), 2, "the journal begun")

func test_03c_watched_through_he_says_it_himself() -> void:
	var main = await _ours()
	var hud = main.hud
	hud.hold_objective()
	main.station_jump.was_skipped = false
	var said: Array = []
	var eb = tree.root.get_node("EventBus")
	var hear := func(key: String, _s: float, _a: Array) -> void: said.append(key)
	eb.hero_spoke.connect(hear)
	main._after_the_crash()
	await wait_frames(2)
	eb.hero_spoke.disconnect(hear)
	assert_false(hud.is_briefing_open(), "No briefing")
	assert_true(said.has(String(config_node.STORY["intro"][0])), "he says what has happened")
	hud._story_run += 1

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
	assert_false((hud.objective_dial.get_node("Disc/Keycap") as Label).visible, "and the goal's dial has no key for it")
	hud.brief()
	assert_false(hud.is_briefing_open(), "No briefing either: the goal at once")
