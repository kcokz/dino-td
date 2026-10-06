# res://tests/test_v06_the_din.gd
# The player, v0.6 round five: "信标残骸里捡东西虽然花时间但是没有危险，感觉时间花的很无聊，周围的守卫恐龙并不会进攻"
# -- chosen: "翻找的响声引来附近的恐龙" (GAME-DESIGN 9.3). Metal knocked about carries: at some strokes of a search
# something comes, the longer the more -- phytosaurs out of the river by the antenna's wreck, at night (by day
# they lie in the river: v0.6 round six, "如果植龙是夜行动物，那么白天翻天线不该出来吧"); the
# guards at the nest woken one by one by the battery's; a few raiders in from the edge by the board's, in their
# hours only. None of it is a raid's.
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
		game_state_node.reset_game(5)

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	main.night_prowl.enabled = false
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	return main

func _wreck(part: String) -> Node:
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == part:
			return n
	return null

func _din(part: String) -> Dictionary:
	return config_node.RESOURCE_NODES[part]["din"]

## Strikes the wreck as a search does, `strokes` times.
func _search(wreck: Node, strokes: int) -> void:
	for i in strokes:
		wreck.harvest(1)

func _drawn() -> Array:
	var out: Array = []
	for d in tree.get_nodes_in_group("drawn"):
		if is_instance_valid(d) and not d.is_queued_for_deletion():
			out.append(d)
	return out

func test_01_the_rivers_wreck_brings_phytosaurs_up_at_night_the_longer_the_more() -> void:
	var main = await _level()
	var wreck = _wreck("antenna")
	assert_not_null(wreck, "(the antenna's wreck is on the map)")
	if wreck == null:
		return
	game_state_node.day_clock = float(config_node.DAY["parts"]["night"]) + 10.0
	game_state_node._run_the_day(0.0)
	assert_eq(String(game_state_node.day_part()), "night", "(at night)")
	var din: Dictionary = _din("antenna")
	var said = watch_signal(tree.root.get_node("EventBus"), "din_carried")
	_search(wreck, int(din["at"][0]) - 1)
	assert_eq(_drawn().size(), 0, "Nothing yet")
	_search(wreck, 1)
	assert_eq(_drawn().size(), int(din["count"][0]), "At its stroke, one comes up out of the river")
	for d in _drawn():
		assert_true(d.is_in_group("prowlers"), "a phytosaur")
		assert_true(bool(d.drawn), "(brought by the din)")
	_search(wreck, int(din["at"][1]) - int(din["at"][0]))
	assert_eq(_drawn().size(), int(din["count"][0]) + int(din["count"][1]), "Kept at, more come")
	assert_eq(said.emit_count, 1, "What the noise did is said once")

func test_01b_by_day_they_lie_in_the_river_and_he_gets_the_antenna() -> void:
	# The player, v0.6 round six: "如果植龙是夜行动物，那么白天翻天线不该出来吧？植龙真实情况下跑的比人快吗，如果慢的话人可以跑，
	# 但是最终，人应该能去拿天线".
	var main = await _level()
	var wreck = _wreck("antenna")
	if wreck == null:
		return
	assert_eq(String(game_state_node.day_part()), "day", "(by day)")
	var said = watch_signal(tree.root.get_node("EventBus"), "din_carried")
	_search(wreck, int(config_node.RESOURCE_NODES["antenna"]["strokes"]))
	assert_eq(_drawn().size(), 0, "By day nothing comes up out of the river, however long he is at it")
	assert_false(said.emitted, "and nothing is said of it")
	assert_true(bool(wreck.is_depleted), "He has the antenna")
	# And at night, what comes is slower than he is on land: he can run for it -- from further off than its
	# lunge (Config.DINO_AI.bursts, 2026-10-02).
	assert_lt(float(config_node.DINOS["phytosaur"]["speed"]), float(config_node.HERO["move_speed"]),
		"On land a phytosaur is slower than he is")
	var lunge: Dictionary = config_node.DINO_AI["bursts"][String(config_node.DINOS["phytosaur"]["burst"])]
	assert_lt(float(lunge["within"]), float(config_node.HERO["move_speed"]),
		"and its lunge reaches less than a second's walk of his")

func test_02_the_nests_wreck_wakes_the_guards_one_by_one() -> void:
	var main = await _level()
	var wreck = _wreck("battery")
	if wreck == null:
		return
	game_state_node.day_clock = float(config_node.DAY["parts"]["night"]) + 10.0
	game_state_node._run_the_day(0.0)
	var guards: Array = main.current_nest.guard_dinos
	for g in guards:
		g.global_position = g.post_position
	await wait_seconds(0.5)
	var asleep := func() -> int:
		var n: int = 0
		for g in guards:
			if is_instance_valid(g) and g.is_asleep():
				n += 1
		return n
	var all: int = asleep.call()
	assert_eq(all, guards.size(), "(asleep at night)")
	var din: Dictionary = _din("battery")
	_search(wreck, int(din["at"][0]))
	assert_eq(asleep.call(), all - int(din["count"][0]), "At its stroke, one is woken")
	_search(wreck, int(din["at"][1]) - int(din["at"][0]))
	assert_eq(asleep.call(), all - int(din["count"][0]) - int(din["count"][1]), "Kept at, another")

func test_03_the_edges_wreck_brings_a_few_in_by_day_and_none_at_night() -> void:
	var main = await _level()
	var wreck = _wreck("board")
	if wreck == null:
		return
	var din: Dictionary = _din("board")
	_search(wreck, int(din["at"][0]))
	var came: Array = _drawn()
	assert_eq(came.size(), int(din["count"][0]), "By day, a few come in from the edge")
	for d in came:
		assert_false(d.is_in_group("prowlers"), "the valley's raiders")
		assert_eq((d.waypoints[1] as Vector3).distance_to(wreck.global_position), 0.0, "by way of the wreck")
	assert_false(main.wave_manager.is_wave_active, "and it is no raid")
	for d in came:
		d.queue_free()
	await wait_frames(1)
	game_state_node.day_clock = float(config_node.DAY["parts"]["night"]) + 10.0
	game_state_node._run_the_day(0.0)
	_search(wreck, int(din["at"][1]) - int(din["at"][0]))
	assert_eq(_drawn().size(), 0, "At night the pack sleeps: nothing comes")
