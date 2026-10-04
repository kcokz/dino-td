# res://tests/test_v07_the_crash.gd
# The player, 2026-10-04: "可以在v0.7做一个开场动画，船舱坠落，山谷受到震动，恐龙进攻船舱是出于对不明物体的恐惧" (GAME-DESIGN 3.0).
#
# THE OPENING: a game chosen on the start screen opens on how it began (StationJump.crash) -- the view low over the
# valley finds the capsule high over its spot, burning, and follows it down; the blow, the view shaken, dust, a ring of
# it along the ground; the valley answering out of the mist; the view back to the run's and him climbing out. Once, a
# game chosen: not a restart, not a jump's landing (its own), not a level a script built. A click or a key ends it.
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
	if tree != null and tree.current_scene != null and _cleanup_nodes.has(tree.current_scene):
		tree.current_scene = null
	if game_state_node != null:
		if "is_paused" in game_state_node:
			game_state_node.is_paused = false
		game_state_node.game = {}
		game_state_node.station = 0
		game_state_node.arrived_by_jump = false
		game_state_node.launch_straight_in = false
		game_state_node.crash_landing = false
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

func _jump(key: String) -> Variant:
	return config_node.STATION_JUMP[key]

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func test_01_a_game_chosen_opens_on_it_and_a_jump_does_not() -> void:
	game_state_node.crash_landing = false
	game_state_node.play("campaign")
	assert_true(game_state_node.crash_landing, "our game chosen opens on the crash")
	game_state_node.crash_landing = false
	game_state_node.play("custom", {}, 7)
	assert_true(game_state_node.crash_landing, "a custom game too")
	game_state_node.play("campaign")
	assert_true(game_state_node.jump_to_next_station(), "on to the second station")
	assert_false(game_state_node.crash_landing, "whose level opens on the jump's own landing, not the crash")

func test_02_a_level_a_script_built_does_not_open_on_it() -> void:
	game_state_node.play("campaign")
	var main = await _level()
	main.open_on_the_crash()
	await wait_frames(2)
	assert_false(main.station_jump.is_running(), "a level a script built is not the game the player chose")
	assert_true(game_state_node.crash_landing, "and it is still to be shown")

func test_03_the_game_the_player_chose_opens_on_it_once() -> void:
	game_state_node.play("campaign")
	var main = await _level()
	tree.current_scene = main
	main.open_on_the_crash()
	await wait_frames(2)
	assert_true(main.station_jump.is_crashing(), "the game the player chose opens on it")
	assert_false(game_state_node.crash_landing, "shown once")
	main.station_jump.finish_now()
	await wait_frames(2)
	main.restart_game()
	main.open_on_the_crash()
	await wait_frames(2)
	assert_false(main.station_jump.is_running(), "a restart is the same run again, at once")
	tree.current_scene = null

func test_04_it_falls_burning_onto_its_spot_and_he_climbs_out() -> void:
	var main = await _level()
	var core: Node3D = main.current_core
	var rest: Transform3D = core.global_transform
	main.station_jump.crash(main)
	assert_true(main.station_jump.is_crashing(), "under way")
	assert_true(game_state_node.is_paused, "the game held still meanwhile")
	assert_false(main.hud.visible, "the HUD out of the way")
	assert_false(main.hero.visible, "he is in it")
	assert_gt(core.global_position.y, rest.origin.y + float(_jump("crash_height")) * 0.9, "the capsule high over its spot")
	assert_not_null(core.find_child("CrashFlame", true, false), "burning")
	assert_not_null(core.find_child("CrashSmoke", true, false), "trailing smoke")
	assert_lt(float(main.camera_rig.tilt), 0.0, "the view looks up at it")
	main.station_jump.finish_now()
	await wait_frames(2)
	assert_false(main.station_jump.is_running(), "over")
	assert_true(core.global_transform.origin.is_equal_approx(rest.origin), "down on its spot")
	assert_true(core.global_transform.basis.is_equal_approx(rest.basis), "and level")
	assert_false(game_state_node.is_paused, "the run begun")
	assert_true(main.hud.visible, "the HUD back")
	assert_true(main.hero.visible, "he has climbed out")
	var flame = core.find_child("CrashFlame", true, false)
	assert_true(flame == null or not flame.emitting, "its flames out")
	assert_not_null(core.find_child("CrashSmoulder", true, false), "the hull smoking a while where it lies")
	var home: Dictionary = main.camera_rig.home()
	assert_almost_eq(float(main.camera_rig.distance), float(home["distance"]), 0.01, "the view the run's own: as far")
	assert_almost_eq(float(main.camera_rig.tilt), float(home["tilt"]), 0.01, "as steep")
	assert_true((main.camera_rig.focus as Vector3).is_equal_approx(home["focus"]), "on what it was on")

func test_05_it_comes_down_inside_what_the_cabin_sees() -> void:
	# The mist is not lifted for it: high over its spot it must be over ground the cabin sees, or the mist swallows it.
	var main = await _level()
	var core: Node3D = main.current_core
	var half: Vector2 = config_node.get_building_half(String(core.building_type))
	assert_lte(float(_jump("crash_side")) + maxf(half.x, half.y), float(config_node.FOG["sight"]["core"]),
		"its whole length over what the cabin sees, all the way down")
	main.station_jump.crash(main)
	assert_eq(float(main.fog.shade_at(core.global_position)), 0.0, "and that ground is clear of the mist")
	main.station_jump.finish_now()
	await wait_frames(2)

func test_06_the_blow_is_heard_and_the_valley_answers() -> void:
	var main = await _level()
	var core: Node3D = main.current_core
	var heard: Array = []
	var fx: Node = tree.root.get_node("Fx")
	var hear := func(id: String, _at: Vector3) -> void:
		heard.append(id)
	fx.played.connect(hear)
	main.station_jump.crash(main)
	assert_has(heard, "crash_fall", "it is heard coming")
	# Its fall's clock is the tween's, stepped here at once; the sounds' is the wall's -- an event is not heard again
	# within its class's gap (Config.SOUNDS.classes), which the fall's length keeps in the game.
	await tree.create_timer(float(config_node.SOUNDS["classes"]["event"]["gap"]) + 0.05).timeout
	var tw: Tween = main.station_jump._crash_tween
	tw.custom_step(float(_jump("crash_fall_seconds")) + 0.05)
	assert_has(heard, "crash", "the blow")
	assert_not_null(core.find_child("CrashRing", true, false), "a ring of dust runs out along the ground")
	assert_not_null(core.find_child("CrashDust", true, false), "dust thrown up")
	tw.custom_step(float(_jump("crash_shake_seconds")) + float(_jump("crash_calls_after"))
		+ float(_jump("crash_calls_gap")) * float(_jump("crash_calls")) + 0.1)
	var answers: int = 0
	for id in heard:
		if String(id).ends_with("_alert") or (String(id).ends_with("_call") and not String(id).begins_with("crash")):
			answers += 1
	assert_gt(answers, 0, "the valley answers out of the mist")
	fx.played.disconnect(hear)
	main.station_jump.finish_now()
	await wait_frames(2)

func test_07_a_press_ends_it_at_once() -> void:
	var main = await _level()
	var core: Node3D = main.current_core
	var rest: Vector3 = core.global_position
	main.station_jump.crash(main)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	main.station_jump._unhandled_input(key)
	assert_true(main.station_jump.is_crashing(), "not the press that chose the game, a moment before")
	main.station_jump._crash_began_at -= int(float(_jump("crash_skip_after")) * 1000.0) + 100
	main.station_jump._unhandled_input(key)
	assert_false(main.station_jump.is_running(), "a press after it has begun ends it")
	assert_true(core.global_position.is_equal_approx(rest), "the capsule down")
	assert_false(game_state_node.is_paused, "the run begun")
	assert_true(main.hud.visible, "the HUD back")
	assert_true(main.hero.visible, "he is out")

func test_08_its_sounds_and_words_are_there() -> void:
	for id in ["crash_fall", "crash"]:
		assert_has(config_node.SOUNDS["sounds"], id, "%s is a sound" % id)
		for f in config_node.SOUNDS["sounds"][id]["files"]:
			assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % String(f)), "%s's file is there" % String(f))
	assert_ne(tr("HINT_CRASHED"), "HINT_CRASHED", "what happened is said, once it is over")
