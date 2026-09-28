# res://tests/test_v06_the_beacon_is_heard.gd
# v0.6 round three: "信标要有更明确的意义，每次信标修复一格，船舱的样式要看得出信标做出来了的部分，也有小的
# 灯，每次信标造成都会有一小波……发送之后应该等等恐龙出现，人可以走出去继续建造，但要有明显的".
#
# The beacon is seen and heard. Its mast on the cabin's roof goes back up a stage at a time -- the
# bent antenna, then a pole, its stays, the dish -- each stage with a lamp of its own that blinks,
# and the dish's throat alight at the launch. Each stage repaired is heard down the valley, and a
# small raid comes of it. Launched, the valley does not answer at once: a countdown on the
# screen, no raids, time to build -- then the final wave.
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

func _beacon() -> Dictionary:
	return config_node.map_data()["beacon"]

func _part(main: Node, part: String) -> GeometryInstance3D:
	return main.current_core.find_child(part, true, false) as GeometryInstance3D

func _next_step() -> void:
	game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))

# ==============================================================================
# 1. Seen: the mast on the roof
# ==============================================================================

func test_01_the_roof_shows_how_far_the_beacon_is() -> void:
	var main = await _level()
	var stages: int = int(game_state_node.beacon_stage_count())
	assert_gt(stages, 0, "The map's beacon has stages")
	assert_true(_part(main, "fade_before_beacon_1").visible, "A new run: the antenna the crash bent over")
	for k in range(1, stages + 1):
		assert_false(_part(main, "fade_beacon_%d" % k).visible, "no stage %d of the mast yet" % k)
		assert_false(_part(main, "lamp_beacon_%d_glow" % k).visible, "nor its lamp")
	for k in range(1, stages + 1):
		_next_step()
		await wait_frames(1)
		assert_true(_part(main, "fade_beacon_%d" % k).visible, "Stage %d repaired: it stands on the roof" % k)
		assert_true(_part(main, "lamp_beacon_%d_glow" % k).visible, "with its lamp")
		assert_false(_part(main, "fade_before_beacon_1").visible, "and the bent antenna is gone")
	assert_false(_part(main, "lamp_beacon_launch_glow").visible, "Not launched: the dish is dark")
	_next_step()
	await wait_frames(1)
	assert_true(_part(main, "lamp_beacon_launch_glow").visible, "Launched: its throat alight")

func test_02_the_lamps_blink_each_on_its_own_beat() -> void:
	var main = await _level()
	for k in range(int(game_state_node.beacon_stage_count())):
		_next_step()
	await wait_frames(1)
	var lamp: GeometryInstance3D = _part(main, "lamp_beacon_1_glow")
	var light: OmniLight3D = lamp.find_child(CabinArt.LIGHT_NAME, false, false) as OmniLight3D
	assert_not_null(light, "The lamp lights the roof round it")
	var spec: Dictionary = config_node.CABIN["glow_lights"]["lamp_beacon_1_glow"]
	var seen_on: bool = false
	var seen_off: bool = false
	var lights: Array[OmniLight3D] = CabinArt.lights_under(main.current_core)
	for i in 40:
		CabinArt.animate(lights, float(i) / (float(spec["blink"]) * 20.0))
		if light.light_energy > 0.0 and lamp.transparency == 0.0:
			seen_on = true
		if light.light_energy == 0.0 and lamp.transparency > 0.0:
			seen_off = true
	assert_true(seen_on and seen_off, "Over a couple of flashes it is lit and dark, lamp and light together")

# ==============================================================================
# 2. Heard: each stage stirs the valley
# ==============================================================================

func test_03_a_stage_repaired_brings_a_small_raid_of_its_own() -> void:
	# On top of the raids the clock sends, not in place of the next one (debug-agent BUG-001).
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = true
	wm.raid_timer = 999.0
	var count_before: int = wm.current_wave
	_next_step()
	var delay: float = float(_beacon()["stage_wave_delay"])
	assert_almost_eq(wm.raid_timer, 999.0, 0.001, "The clock's next raid is not brought in")
	var started = watch_signal(tree.root.get_node("EventBus"), "wave_started")
	var stirred = watch_signal(tree.root.get_node("EventBus"), "stage_wave_started")
	wm._process(delay + 0.1)
	assert_true(wm.is_wave_active and wm.stage_wave, "A raid of its own comes, %.0fs on" % delay)
	assert_eq(wm.wave_roster.size(), int(_beacon()["stage_waves"][0]), "as small as the first stage says, and no leader")
	assert_eq(started.emit_count, 1, "one raid")
	assert_eq(stirred.emit_count, 1, "said to be the beacon's")
	assert_eq(wm.current_wave, count_before, "The raid count is where it was")
	assert_almost_eq(wm.raid_timer, 999.0, 0.001, "and the clock's next raid still to come")

func test_04_a_stage_repaired_in_a_raid_brings_its_own_after_it() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = true
	wm.start_next_raid()
	assert_true(wm.is_wave_active, "A raid is out")
	_next_step()
	wm._process(float(_beacon()["stage_wave_delay"]) + 0.1)
	assert_false(wm.stage_wave, "The stage's raid does not set out while one is out")
	wm._end_wave()
	assert_gt(wm._stirred, 0, "still to come")
	var drawn: float = wm.raid_timer
	wm._process(float(_beacon()["stage_wave_delay"]) + 0.1)
	assert_true(wm.stage_wave, "Over, the stirred one comes after it")
	assert_almost_eq(wm.raid_timer, drawn, 0.001, "and the clock's next raid waits where it was")

func test_04b_a_stage_repaired_in_a_big_raids_warning_leaves_the_big_raid_whole() -> void:
	# BUG-001 (debug-agent): repaired in the warning of the third raid -- the big one, its leader at
	# the head -- the stage's small raid stood in for it, and six became three.
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = true
	var big: int = int(config_node.WAVES["big_every"])
	game_state_node.wave_number = big - 1
	wm.current_wave = big - 1
	wm.raid_timer = 12.0
	_next_step()
	wm._process(12.1)
	assert_true(wm.is_wave_active and not wm.stage_wave, "The big raid sets out on time")
	assert_eq(wm.current_wave, big, "as raid %d" % big)
	assert_has(wm.wave_roster, String(game_state_node.map_data()["minor_boss"]), "its leader at its head")
	assert_gt(wm.wave_roster.size() - 1, int(_beacon()["stage_waves"][0]), "and its whole count, not the stage's")
	wm._end_wave()
	wm._process(float(_beacon()["stage_wave_delay"]) + 0.1)
	assert_true(wm.stage_wave, "The stage's raid comes after it, on top")
	var hp: float = float(game_state_node.dino_stat_multipliers["hp"])
	wm._end_wave()
	assert_almost_eq(float(game_state_node.dino_stat_multipliers["hp"]), hp, 0.0001,
		"and its end, with the big raid's number, is not a second big raid")

func test_05_the_screen_says_the_valley_heard_it() -> void:
	var main = await _level()
	_next_step()
	await wait_frames(1)
	assert_eq(String(main.hud.hint_label.text), tr("HINT_BEACON_STIRS"), "Its hum carried down the valley")

# ==============================================================================
# 3. Launched: a grace, counted down, before the final wave
# ==============================================================================

func test_06_launched_there_is_time_before_they_come() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = true
	for i in range(int(game_state_node.beacon_stage_count()) + 1):
		_next_step()
	var grace: float = float(_beacon()["launch_grace"])
	assert_gt(grace, 0.0, "The map gives a grace")
	assert_false(wm.final_wave, "Launched: not yet")
	wm.raid_timer = 0.5
	wm._process(1.0)
	assert_false(wm.is_wave_active, "and no ordinary raid comes in the grace, however its clock stands")
	assert_almost_eq(float(game_state_node.final_wave_in), grace - 1.0, 0.01, "The time till they come, counted")
	wm._process(grace)
	assert_true(wm.final_wave, "Then the final wave")

func test_07_the_countdown_is_on_the_screen() -> void:
	var main = await _level()
	for i in range(int(game_state_node.beacon_stage_count()) + 1):
		_next_step()
	await wait_frames(1)
	var hud = main.hud
	assert_true(hud.raid_warning_banner.visible, "The banner is up")
	var secs: int = int(ceil(float(game_state_node.final_wave_in)))
	assert_eq(String(hud.raid_warning_banner.text), tr("HUD_FINAL_WAVE") % secs, "counting to the final wave (%s)" % hud.raid_warning_banner.text)
	main.wave_manager._process(float(_beacon()["launch_grace"]) + 0.1)
	await wait_frames(2)
	assert_false(hud.raid_warning_banner.visible, "and gone when it sets out")

func test_08_the_fight_after_the_grace_is_as_long_as_it_was() -> void:
	var fight: float = float(_beacon()["charge_seconds"]) - float(_beacon()["launch_grace"])
	assert_gte(fight, 150.0, "The charge is the grace longer than the fight it holds (%.0fs of fight)" % fight)
