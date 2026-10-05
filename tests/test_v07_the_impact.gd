# res://tests/test_v07_the_impact.gd
# The player, 2026-10-05: "把后面几关都先做起来".
#
# STATION 4'S CLIMAX (GAME-DESIGN 7.2: "高潮：小行星。最后一天，撞击溅出的玻璃小球像雨一样落下……信标充能和撞击倒计时同时在
# 走"; ImpactRain): at Hell Creek the beacon's launch is answered by the impact far off, and the glass it threw up rains
# on the valley till the jump -- scalding a dinosaur, the man out in the open (not in the cabin), a building a little.
# No other station has it, and it goes with the run.
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
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	if game_state_node != null:
		game_state_node.game = {}
		game_state_node.station = 0
		game_state_node.chosen_map_id = ""
		game_state_node.reset_game()
	super.after_each()

func _climax() -> Dictionary:
	return config_node.map_data("hell_creek").get("climax", {})

## A level on the Hell Creek map, the raids held, the beacon mended and launched.
func _launched_at_hell_creek() -> Node:
	game_state_node.chosen_map_id = "hell_creek"
	game_state_node.reset_game()
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	assert_eq(String(game_state_node.map_id), "hell_creek", "(on the Hell Creek map)")
	var spent: int = 0
	while not game_state_node.is_beacon_launched() and spent < 10:
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
		spent += 1
	await wait_frames(2)
	return main

func _animal(main: Node, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path("acheroraptor"))).new()
	main.dinos_container.add_child(d)
	d.setup("acheroraptor")
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = Vector3(at.x, 0.0, at.z)
	d.set_physics_process(false)
	return d

func test_01_only_the_last_station_ends_in_an_impact() -> void:
	assert_eq(String(_climax().get("kind", "")), "impact", "Hell Creek's climax is the impact")
	for id in ["valley", "valley_large", "morrison", "jehol"]:
		assert_true(config_node.map_data(id).get("climax", {}).is_empty(), "%s has none" % id)
	for key in ["delay", "rate_from", "rate_to", "radius", "damage", "fall_seconds"]:
		assert_gt(float(_climax().get(key, 0.0)), 0.0, "it says its %s" % key)
	assert_gt(float(_climax()["rate_to"]), float(_climax()["rate_from"]), "thicker as the charge goes on")
	for id in ["impact_boom", "impact_bead"]:
		assert_true(config_node.SOUNDS["sounds"].has(id), "%s is heard" % id)
		for f in config_node.SOUNDS["sounds"][id]["files"]:
			assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % String(f)), "%s.wav is made" % f)
	for locale in ["en", "zh_CN"]:
		var t: Translation = TranslationServer.get_translation_object(locale)
		assert_true(t != null and String(t.get_message("HINT_IMPACT")) != "", "he is told in %s" % locale)

func test_02_launched_at_hell_creek_the_glass_comes_down() -> void:
	var main = await _launched_at_hell_creek()
	var rain = main.find_child("ImpactRain", false, false)
	assert_not_null(rain, "The launch at Hell Creek brings the impact")
	if rain == null:
		return
	var d = _animal(main, main.current_core.global_position + Vector3(8.0, 0.0, 6.0))
	rain.drop_at(d.global_position)
	# By the clock: a headless run's frames are uncapped, so a count of them is no measure of the bead's fall.
	var start: int = Time.get_ticks_msec()
	var limit_ms: int = int((float(_climax()["fall_seconds"]) + 1.0) * 1000.0)
	while float(d.current_hp) >= 999.0 and Time.get_ticks_msec() - start < limit_ms:
		await tree.process_frame
	assert_almost_eq(999.0 - float(d.current_hp), float(_climax()["damage"]), 0.01, "A bead let go over it comes down and scalds it")

func test_03_the_man_is_scalded_in_the_open_and_not_in_the_cabin() -> void:
	var main = await _launched_at_hell_creek()
	var rain = main.find_child("ImpactRain", false, false)
	if rain == null:
		assert_not_null(rain, "(the rain)")
		return
	var hero = main.hero
	hero.global_position = main.current_core.global_position + Vector3(9.0, 0.0, 9.0)
	main.current_core.hero_inside = false
	var hp: float = float(hero.current_hp)
	rain.land(hero.global_position)
	assert_almost_eq(hp - float(hero.current_hp), float(_climax()["damage"]), 0.01, "Out in the open, a bead scalds him")
	main.current_core.hero_inside = true
	hp = float(hero.current_hp)
	rain.land(hero.global_position)
	assert_almost_eq(float(hero.current_hp), hp, 0.001, "In the cabin he is out of it")
	main.current_core.hero_inside = false
	var far = main.current_core.global_position + Vector3(-9.0, 0.0, -9.0)
	hp = float(hero.current_hp)
	rain.land(far)
	assert_almost_eq(float(hero.current_hp), hp, 0.001, "A bead far off is nothing to him")

func test_04_it_goes_with_the_run() -> void:
	var main = await _launched_at_hell_creek()
	assert_not_null(main.find_child("ImpactRain", false, false), "(raining)")
	game_state_node.reset_game()
	await wait_frames(3)
	assert_null(main.find_child("ImpactRain", false, false), "A new run, no rain")
	game_state_node.chosen_map_id = "valley_large"
	game_state_node.reset_game()
	var spent: int = 0
	while not game_state_node.is_beacon_launched() and spent < 10:
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
		spent += 1
	await wait_frames(2)
	assert_null(main.find_child("ImpactRain", false, false), "And the launch on another map brings none")
