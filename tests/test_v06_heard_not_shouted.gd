# res://tests/test_v06_heard_not_shouted.gd
# The player, v0.6 round six: "来袭击不要直接红字提醒，要用声音加上别的一些提醒就够了，比如人说话之类的，红字提醒
# 太突兀了". A raid on its way is heard -- the pack's call from the nest's side -- and told: he says where they come
# from, then the other ways in, then who comes with them, a line after another (HeroVoice). How long is left is a
# quiet line in the goal's card, counted down on the raid's own clock (HUD.raid_line). Nothing red across the top.
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

## The clock's next raid warned of, as the WaveManager warns of it.
func _warn(main: Node) -> void:
	var wm = main.wave_manager
	wm.auto_raid_enabled = true
	wm.raid_timer = wm._warning_lead() - 0.01
	wm.warning_emitted = false
	await wait_frames(2)

## The day's clock a moment into `part`, on the first day.
func _to_part(part: String) -> void:
	game_state_node.day_clock = float(config_node.DAY["parts"][part]) + 1.0
	game_state_node._run_the_day(0.0)

## What he says from now on: [key, seconds, args] a line. `stop_hearing` with what this gave back.
func _hear() -> Array:
	var said: Array = []
	var ear := func(key: String, seconds: float, args: Array = []) -> void: said.append([key, seconds, args])
	tree.root.get_node("EventBus").hero_spoke.connect(ear)
	return [said, ear]

func _stop_hearing(heard: Array) -> void:
	tree.root.get_node("EventBus").hero_spoke.disconnect(heard[1])

func test_01_a_raid_on_its_way_is_no_banner() -> void:
	var main = await _level()
	await _warn(main)
	var hud = main.hud
	assert_true(main.wave_manager.warning_emitted, "(warned of)")
	assert_true(hud.raid_line.visible, "How long is left is up")
	assert_true(hud.objective_panel.is_ancestor_of(hud.raid_line), "in the goal's card, at the side")
	assert_true(hud.objective_panel.visible, "(the card up with it)")
	assert_eq(hud.raid_line.theme_type_variation, &"MutedLabel", "in its quiet letters")
	assert_eq(String(hud.raid_line.text), tr("HUD_RAID_WARNING") % int(ceil(main.wave_manager.warned_raid_in())),
		"-- how long (%s)" % hud.raid_line.text)
	assert_null(hud.find_child("RaidWarning", true, false), "No banner across the top")
	assert_false(UiTheme.get_theme().has_stylebox("panel", "BannerPanel"), "and none to be had")

func test_02_it_counts_down_on_the_raids_own_clock() -> void:
	var main = await _level()
	await _warn(main)
	var wm = main.wave_manager
	var hud = main.hud
	# Held where it is, and three seconds taken off by hand.
	wm.auto_raid_enabled = false
	var before: String = String(hud.raid_line.text)
	wm.raid_timer -= 3.0
	await wait_frames(1)
	assert_eq(String(hud.raid_line.text), tr("HUD_RAID_WARNING") % int(ceil(wm.warned_raid_in())),
		"Counted down with the raid's clock (%s)" % hud.raid_line.text)
	assert_ne(String(hud.raid_line.text), before, "(it moved: %s, then %s)" % [before, hud.raid_line.text])
	wm.start_next_raid()
	await wait_frames(1)
	assert_false(hud.raid_line.visible, "The raid out, the count is gone")

func test_03_out_of_the_raiders_hours_it_is_called_off_and_warned_of_again() -> void:
	var main = await _level()
	await _warn(main)
	var wm = main.wave_manager
	var hud = main.hud
	var off: String = ""
	for part in config_node.DAY["parts"]:
		_to_part(String(part))
		if not wm.raiders_out():
			off = String(part)
			break
	assert_ne(off, "", "(the first map's raiders keep hours of their own)")
	wm._process(0.1)
	await wait_frames(1)
	assert_false(hud.raid_line.visible, "Their hours over, the raid is called off: no count standing still all %s" % off)
	for part in config_node.DAY["parts"]:
		_to_part(String(part))
		if wm.raiders_out():
			break
	wm._process(0.1)
	await wait_frames(1)
	assert_true(hud.raid_line.visible, "Out again, it is warned of again")

func test_04_he_tells_it_a_line_after_another() -> void:
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var eb = tree.root.get_node("EventBus")
	var heard: Array = _hear()
	var said: Array = heard[0]
	eb.raid_warning.emit(15.0)
	eb.boss_warning.emit(String(config_node.map_data()["minor_boss"]))
	assert_eq(said.size(), 1, "One line at once: where they come from (%s)" % [said])
	var side: String = tr("DIR_" + voice.nest_side())
	assert_true(String(main.hud.speech_label.text).contains(side), "said in words, the side filled in (%s)" % main.hud.speech_label.text)
	if said.size() == 1:
		var first: float = float(said[0][1])
		voice._process(first * 0.5)
		assert_eq(said.size(), 1, "Nothing over it while it is said")
		voice._process(first * 0.5 + 0.05)
		assert_eq(said.size(), 2, "then the next")
	if said.size() == 2:
		assert_true(String(said[1][0]).begins_with("BARK_RAID_BOSS_"), "-- who comes with them (%s)" % [said])
	_stop_hearing(heard)

func test_05_what_he_had_still_to_say_is_dropped_if_he_goes_down() -> void:
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var eb = tree.root.get_node("EventBus")
	var heard: Array = _hear()
	eb.raid_warning.emit(15.0)
	eb.boss_warning.emit(String(config_node.map_data()["minor_boss"]))
	main.hero.current_state = main.hero.State.DEAD
	voice._process(0.1)
	main.hero.current_state = main.hero.State.IDLE
	for i in 40:
		voice._process(0.25)
	_stop_hearing(heard)
	for line in heard[0]:
		assert_false(String(line[0]).begins_with("BARK_RAID_BOSS_"),
			"Down, what he had still to say of that raid is not said once he is up again (%s)" % [heard[0]])
