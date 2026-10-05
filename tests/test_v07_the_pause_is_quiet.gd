# res://tests/test_v07_the_pause_is_quiet.gd
# The player, 2026-10-04: "Paused的时候声音也应该pause".
#
# Paused by the player, the game's sound holds where it is -- the valley's ambience, the world's sounds, what was being
# said -- and the interface's own clicks go on. Under a scene that holds the game for itself -- the start screen, the
# crash -- the sound goes on: the crash is heard as it is seen (Fx.play_through_pause).
extends "res://tests/test_base.gd"

var fx: Node = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		fx = tree.root.get_node_or_null("Fx")
		game_state_node = tree.root.get_node_or_null("GameState")

func after_each() -> void:
	if game_state_node != null:
		game_state_node.is_paused = false
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func test_01_paused_by_him_the_games_sound_holds_and_a_click_does_not() -> void:
	var main = await _level()
	fx.start_ambience()
	await wait_frames(2)
	assert_false(fx.is_holding(), "Playing, nothing is held")
	game_state_node.is_paused = true
	await wait_frames(2)
	assert_true(fx.is_holding(), "Paused, the game's sound holds")
	assert_true(fx._ambience.stream_paused and fx._ambience_night.stream_paused, "the valley's ambience among it")
	assert_eq(int(fx._world.process_mode), int(Node.PROCESS_MODE_PAUSABLE), "and the world's sounds, mid-note")
	# A click on the pause menu is heard.
	assert_true(fx.play_ui("ui_click"), "A click is still played")
	var clicked: bool = false
	for v in fx._voices:
		if v.stream != null and not v.stream_paused:
			clicked = true
	assert_true(clicked, "on a voice that is not held")
	game_state_node.is_paused = false
	await wait_frames(2)
	assert_false(fx.is_holding(), "Let go, it goes on")
	assert_false(fx._ambience.stream_paused, "the ambience with it")
	assert_not_null(main, "(the level)")

func test_02_under_a_scene_that_holds_the_game_it_goes_on() -> void:
	var main = await _level()
	var scene := Node.new()
	_cleanup_nodes.append(scene)
	tree.root.add_child(scene)
	fx.play_through_pause(scene, true)
	game_state_node.is_paused = true
	await wait_frames(2)
	assert_false(fx.is_holding(), "Held for a scene of its own, the sound goes on")
	assert_false(fx._ambience.stream_paused, "the ambience")
	assert_eq(int(fx._world.process_mode), int(Node.PROCESS_MODE_ALWAYS), "and the world's sounds it plays")
	scene.free()
	await wait_frames(2)
	assert_true(fx.is_holding(), "The scene gone, a pause holds the sound again")
	assert_eq(int(fx._world.process_mode), int(Node.PROCESS_MODE_PAUSABLE), "the world's with it")
	assert_not_null(main, "(the level)")

func test_03_the_start_screen_and_the_crash_play_through() -> void:
	var main = await _level()
	main.hud.show_start_screen(false)
	await wait_frames(2)
	assert_true(game_state_node.is_paused, "(the start screen holds the game)")
	assert_false(fx.is_holding(), "Under the start screen the valley is heard")
	main.hud.start_screen.close()
	game_state_node.is_paused = false
	await wait_frames(2)
	main.station_jump.crash(main)
	await wait_frames(2)
	assert_true(game_state_node.is_paused, "(the crash holds the game)")
	assert_false(fx.is_holding(), "and the crash is heard as it is seen")
	assert_eq(int(fx._world.process_mode), int(Node.PROCESS_MODE_ALWAYS), "its sounds in the world played")
	main.station_jump.finish_now()
	await wait_frames(2)
	assert_false(game_state_node.is_paused, "(the run begun)")
	game_state_node.is_paused = true
	await wait_frames(2)
	assert_true(fx.is_holding(), "Paused by him after it, the sound holds")
