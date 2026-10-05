# res://tests/test_v07_the_opening.gd
# The player, 2026-10-04 ("改进2"): "开场动画还要精致化一点，甚至你可以做一个完整飞船穿越，出现故障，人在船舱中睡眠，然后船舱解
# 体，掉落，震动山谷，把各个被惊吓得恐龙刻画出来，它们躁动不安，追寻着烟去了，人惊醒，打开舱门，从船舱爬出来（人脸可以有特写），然后
# 开始……配音你可以想办法".
#
# THE OPENING FILM (Opening): our own game's first station opens on it -- the jump, the failure, him asleep, the
# break-up, the fall (StationJump.crash, a shot of it), the valley's animals startled, him awake and out -- the ship's
# voice under its words. Everything it moves it puts back, everything it brings it takes away, and the run begins as
# the crash alone would leave it; watched through, he says what has happened; ended at once, the briefing does. A
# custom game opens on the crash alone.
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
	if game_state_node != null:
		game_state_node.game = {}
		game_state_node.reset_game()

func after_each() -> void:
	if tree != null and tree.current_scene != null and _cleanup_nodes.has(tree.current_scene):
		tree.current_scene = null
	if game_state_node != null:
		if "is_paused" in game_state_node:
			game_state_node.is_paused = false
		game_state_node.game = {}
		game_state_node.crash_landing = false
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	Dino.clear_all_attack_slots()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

## Our own game's level, chosen as the player chooses it (the current scene), opening on its film.
func _opening_level() -> Node:
	game_state_node.play("campaign")
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	tree.current_scene = main
	return main

## What the run is left at, to be found again after the film: where the cabin stands, the guards and the grazers, the
## sky's light, the dinosaurs out. Taken with the game held, as the film holds it: nothing wanders off meanwhile.
func _snapshot(main: Node) -> Dictionary:
	game_state_node.set_paused(true)
	var guards: Dictionary = {}
	for g in tree.get_nodes_in_group("guard_dinos"):
		guards[g.get_instance_id()] = (g as Node3D).global_position
	var herds: Dictionary = {}
	var h: Node = main.get_node_or_null("Herds")
	if h != null:
		for a in h.get_children():
			if a is Node3D:
				herds[a.get_instance_id()] = (a as Node3D).global_position
	var we: WorldEnvironment = main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = main.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	return {"cabin": main.current_core.global_transform, "guards": guards, "herds": herds,
		"env": we.environment if we != null else null, "sun": sun.light_energy if sun != null else 0.0,
		"dinos": tree.get_nodes_in_group("dinos").size()}

## The run as the film leaves it: as it found it, the module down on its spot, him out at its door, the game going.
func _as_it_was(main: Node, before: Dictionary) -> void:
	assert_false(main.opening.is_playing(), "The film over")
	assert_true(main.current_core.global_transform.is_equal_approx(before["cabin"]), "the module down on its spot, level")
	assert_null(main.find_child("OpeningSet", true, false), "the set above the world struck")
	var we: WorldEnvironment = main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null:
		assert_eq(we.environment, before["env"], "the valley's own sky back")
	var sun: DirectionalLight3D = main.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		assert_almost_eq(sun.light_energy, float(before["sun"]), 0.001, "and its own sun")
	# Within a stride: the game going again, they go about their business (a guard's roaming, a grazer's amble) from the
	# frame the film ends -- wherever they were run off to in it, they were put back.
	var stride: float = 0.3
	for g in tree.get_nodes_in_group("guard_dinos"):
		if before["guards"].has(g.get_instance_id()):
			assert_lt((g as Node3D).global_position.distance_to(before["guards"][g.get_instance_id()]), stride, "the nest's guards back at their posts")
	var h: Node = main.get_node_or_null("Herds")
	if h != null:
		for a in h.get_children():
			if before["herds"].has(a.get_instance_id()):
				assert_lt((a as Node3D).global_position.distance_to(before["herds"][a.get_instance_id()]), stride, "the grazers back where they grazed")
	await wait_frames(2)
	assert_eq(tree.get_nodes_in_group("dinos").size(), int(before["dinos"]), "nothing the film put down left in the valley")
	assert_false(bool(game_state_node.is_paused), "the game going")
	assert_true(main.hud.visible, "the HUD back")
	assert_true(main.hero.visible, "he is out")
	assert_lt(Vector2(main.hero.global_position.x - main.current_core.door_outside().x,
		main.hero.global_position.z - main.current_core.door_outside().z).length(), 0.05, "at its door")
	assert_true(main.camera.current, "the run's own view")

func test_01_our_game_opens_on_its_film() -> void:
	var main = await _opening_level()
	main.open_on_the_crash()
	await wait_frames(2)
	assert_not_null(main.opening, "Our own game opens on its film")
	assert_true(main.opening.is_playing(), "playing")
	assert_true(bool(game_state_node.is_paused), "the game held still through it")
	assert_false(main.hud.visible, "the HUD out of the way")
	assert_not_null(main.find_child("OpeningSet", true, false), "its first shots set above the world")
	var ship: Node = main.find_child("Ship", true, false)
	assert_not_null(ship, "the ship")
	if ship != null:
		for part in ["Ring_glow", "Dish", "Bay", "Board", "Clamps", "Engines"]:
			assert_not_null(ship.find_child(part, true, false), "with its %s" % part)
	assert_gt(main.current_core.global_position.y, 1000.0, "the module docked at its nose, up there")
	main.opening.skip()
	await wait_frames(4)

func test_02_watched_through_it_leaves_the_run_as_it_found_it_and_he_says_why() -> void:
	var main = await _opening_level()
	var before: Dictionary = _snapshot(main)
	var said: Array = []
	var eb = tree.root.get_node("EventBus")
	var hear := func(key: String, _s: float, _a: Array) -> void: said.append(key)
	eb.hero_spoke.connect(hear)
	main.opening = Opening.new()
	main.add_child(main.opening)
	main.opening.pace = 40.0
	main.opening.finished.connect(main._after_the_crash, CONNECT_ONE_SHOT)
	main.hud.hold_objective()
	main.opening.play(main)
	# Its shots above the world, then its fall -- the crash's own, run to its end at once -- then the valley.
	var spent: int = 0
	while not main.opening._fell and spent < 600:
		await tree.process_frame
		spent += 1
	assert_true(main.opening._fell, "the shots above the world over, the module falls")
	assert_true(main.station_jump.is_running(), "the fall is the crash's")
	# Its fall run to its end at once -- its own tween only: StationJump.finish_now steps every tween there is, the
	# grazers' ambling among them.
	main.station_jump._crash_tween.custom_step(1000.0)
	spent = 0
	while main.opening.is_playing() and spent < 900:
		await tree.process_frame
		spent += 1
	assert_false(main.opening.was_skipped, "(watched through)")
	await _as_it_was(main, before)
	await wait_frames(4)
	eb.hero_spoke.disconnect(hear)
	assert_false(main.hud.is_briefing_open(), "Watched through: no briefing")
	assert_true(said.has(String(config_node.STORY["intro"][0])), "he says what has happened")
	main.hud._story_run += 1

func test_03_ended_at_once_it_leaves_the_run_as_it_found_it_and_the_briefing_says_why() -> void:
	var main = await _opening_level()
	var before: Dictionary = _snapshot(main)
	main.open_on_the_crash()
	await wait_frames(2)
	assert_true(main.opening.is_playing(), "(playing)")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	main.opening._unhandled_input(key)
	assert_true(main.opening.is_playing(), "Not the press that chose the game, a moment before")
	main.opening._began_at -= int(float(config_node.OPENING["seconds"]["skip_after"]) * 1000.0) + 100
	main.opening._unhandled_input(key)
	await wait_frames(4)
	assert_true(main.opening.was_skipped, "A press after it has begun ends it")
	assert_true(main.hud.is_briefing_open(), "and the game holds on the briefing")
	main.hud.briefing.close()
	await wait_frames(1)
	await _as_it_was(main, before)

func test_04_a_custom_game_opens_on_the_crash_alone() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	game_state_node.play("custom", {"map": "small"})
	game_state_node.reset_game()
	game_state_node.crash_landing = true
	assert_false(bool(game_state_node.internal("story", false)), "(a custom game tells no story)")
	tree.current_scene = main
	main.open_on_the_crash()
	await wait_frames(2)
	assert_true(main.opening == null or not main.opening.is_playing(), "No film")
	assert_true(main.station_jump.is_crashing(), "the crash alone")
	main.station_jump.finish_now()
	await wait_frames(2)

func test_05_the_ship_speaks_its_lines_in_its_voice_and_its_words_are_said_in_both_languages() -> void:
	var lines: Dictionary = config_node.OPENING["lines"]
	assert_gte(lines.size(), 4, "The ship's voice speaks in the film")
	for shot in lines:
		var line: Dictionary = lines[shot]
		var sound: String = String(line["sound"])
		assert_has(config_node.SOUNDS["sounds"], sound, "%s's voice is a sound" % shot)
		for f in config_node.SOUNDS["sounds"].get(sound, {}).get("files", []):
			assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % String(f)), "its file is there (%s)" % String(f))
		var key: String = String(line["text"])
		for locale in ["en", "zh_CN"]:
			var t: Translation = TranslationServer.get_translation_object(locale)
			assert_true(t != null and String(t.get_message(key)) != "", "its words in %s (%s)" % [locale, key])
	for id in ["film_fault", "film_alarm", "film_separation", "film_breakup", "film_pod_open", "film_door"]:
		assert_has(config_node.SOUNDS["sounds"], id, "%s is a sound" % id)
		assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % id), "%s's file is there" % id)
	assert_true(ResourceLoader.exists(String(config_node.VISUALS["film/ship"]["scene"])), "the ship is drawn")
