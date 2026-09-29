# res://tests/test_v06_the_day.gd
# v0.6 round three (GAME-DESIGN 9.3): "一天六分钟OK，但是黄昏和夜晚，我不知道恐龙是不是应该进攻。恐龙的正常
# 习性黄昏和夜晚就会进攻吗？白天不进攻吗？这是我们要做到跟恐龙的习性一样".
#
# A day of six minutes -- day, dusk, night -- run on game time, so a pause holds it. Its light
# changes through it. Each species keeps its own hours (Config.DINOS.<id>.hours): Coelophysis
# hunted by day, so the first map's raids set out only by day, and at dusk the raid out goes back
# to its nest. The beacon's last wave comes whatever the hour. The HUD shows the day and its part.
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
		game_state_node.reset_game()

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
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _day() -> Dictionary:
	return config_node.DAY

func _at(part: String) -> float:
	return float(_day()["parts"][part])

## Sets the clock to `t` seconds into day `day` and says the part of the day that is, as the clock
## running into it would.
func _set_clock(t: float, day: int = 1) -> void:
	game_state_node.day_clock = float(day - 1) * float(_day()["length"]) + t
	game_state_node._run_the_day(0.0)

func test_01_a_day_is_its_length_and_its_parts_begin_where_config_says() -> void:
	var length: float = float(_day()["length"])
	assert_almost_eq(length, 360.0, 0.001, "Six minutes, a day and its night (「一天六分钟OK」)")
	for part in ["day", "dusk", "night"]:
		_set_clock(_at(part) + 1.0)
		assert_eq(String(game_state_node.day_part()), part, "%s begins at %.0fs" % [part, _at(part)])
	_set_clock(length - 1.0)
	assert_eq(int(game_state_node.day_number()), 1, "The last of the night is still the first day")
	_set_clock(1.0, 2)
	assert_eq(int(game_state_node.day_number()), 2, "and the first light the second")
	assert_eq(String(game_state_node.day_part()), "day", "by day")
	game_state_node.reset_game()
	assert_almost_eq(float(game_state_node.time_of_day()), float(_day()["start"]), 0.001,
		"A new run lands where the first morning begins")

func test_02_it_runs_on_game_time_and_a_pause_holds_it() -> void:
	await _level()
	var t0: float = float(game_state_node.day_clock)
	await wait_physics_frames(30)
	assert_gt(float(game_state_node.day_clock), t0, "The clock runs")
	game_state_node.is_paused = true
	var held: float = float(game_state_node.day_clock)
	await wait_physics_frames(30)
	assert_almost_eq(float(game_state_node.day_clock), held, 0.0001, "and holds while the game is paused")

func test_03_the_light_follows_the_day() -> void:
	var main = await _level()
	var env = main.find_child("WorldEnvironment", false, false)
	env.set_process(false)
	var sun := main.find_child("DirectionalLight3D", false, false) as DirectionalLight3D
	var noon: float = (float(_day()["light"][2]["at"]) + float(_day()["light"][3]["at"])) * 0.5
	env.apply_time_of_day(noon)
	assert_almost_eq(sun.light_energy, float(config_node.ENVIRONMENT["sun_light_energy"]), 0.001,
		"The middle of the day is the valley's own light")
	var day_energy: float = sun.light_energy
	var day_ambient: float = float(env.environment.ambient_light_energy)
	env.apply_time_of_day(_at("night") + 30.0)
	assert_lt(sun.light_energy, day_energy * 0.3, "The night is dark")
	assert_lt(float(env.environment.ambient_light_energy), day_ambient, "its shadows darker")
	assert_gt(sun.light_color.b, sun.light_color.r, "and its light the moon's, blue")
	env.apply_time_of_day(_at("dusk") + 5.0)
	assert_gt(sun.light_color.r - sun.light_color.b, 0.4, "Dusk is red")

func test_03b_the_light_at_a_moment_is_its_keyframes_blended() -> void:
	# SceneEnvironment.light_at: what the light is at a moment, for anything that follows it (the mist).
	var keys: Array = _day()["light"]
	var length: float = float(_day()["length"])
	var k: Dictionary = keys[2]
	var at_k: Dictionary = SceneEnvironment.light_at(keys, length, float(k["at"]))
	assert_almost_eq(float(at_k["sun_energy"]), float(k["sun_energy"]), 0.0001, "At a keyframe it is that keyframe")
	assert_eq(at_k["fog_color"], k["fog_color"], "(its colours too)")
	var last: Dictionary = keys[keys.size() - 1]
	var first: Dictionary = keys[0]
	var mid: float = (float(last["at"]) + float(first["at"]) + length) * 0.5
	var across: Dictionary = SceneEnvironment.light_at(keys, length, mid)
	assert_almost_eq(float(across["mist"]), (float(last["mist"]) + float(first["mist"])) * 0.5, 0.0001,
		"Between the last keyframe and the next first light it is half of each")
	assert_true(SceneEnvironment.light_at([], length, 10.0).is_empty(), "No keyframes, no light")

func test_04_no_raid_sets_out_out_of_the_raiders_hours() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = true
	var species: String = String(game_state_node.map_data()["raiders"].keys()[0])
	assert_false(config_node.keeps_hours(species, "night"), "The first map's raiders keep to the day")
	_set_clock(_at("night") + 10.0)
	wm.raid_timer = 5.0
	wm._process(10.0)
	assert_false(wm.is_wave_active, "At night no raid sets out")
	assert_almost_eq(wm.raid_timer, 5.0, 0.001, "and none is counted down to")
	_set_clock(_at("day") + 10.0, 2)
	wm._process(10.0)
	assert_true(wm.is_wave_active, "By day it does")

func test_05_at_dusk_the_raid_goes_home() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = false
	_set_clock(_at("dusk") - 30.0)
	wm.start_wave(1, 3)
	for i in range(int(3.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if wm.dinos_spawned_count >= wm.dinos_to_spawn:
			break
	assert_eq(wm.dinos_spawned_count, wm.dinos_to_spawn, "The raid is out")
	var drops_before: int = tree.get_nodes_in_group("drops").size()
	var died = watch_signal(tree.root.get_node("EventBus"), "dino_died")
	_set_clock(_at("dusk") + 0.1)
	var home: bool = false
	for i in range(int(10.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if not wm.is_wave_active:
			home = true
			break
	assert_true(home, "At dusk the raid goes back to its nest, and is over")
	assert_eq(died.emit_count, 0, "not killed")
	assert_eq(tree.get_nodes_in_group("drops").size(), drops_before, "and nothing left behind")

func test_05b_at_dusk_those_still_in_the_nest_stay_there() -> void:
	# debug-agent BUG-006: a raid setting out just before dusk went on stepping out after it, and
	# those came for the cabin into the night.
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = false
	_set_clock(_at("dusk") - 30.0)
	var size: int = 6
	wm.start_wave(1, size)
	var raid: int = wm.dinos_to_spawn
	for i in range(int(10.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if wm.dinos_spawned_count >= 2:
			break
	var out: int = wm.dinos_spawned_count
	assert_true(out >= 2 and out < raid, "Dusk comes with %d of the %d out" % [out, raid])
	_set_clock(_at("dusk") + 0.1)
	assert_eq(wm.wave_roster.size(), 0, "The rest are kept in the nest")
	assert_eq(wm.dinos_alive_count, out, "and the raid counts only those out")
	var home: bool = false
	var stepped_out: int = out
	for i in range(int(20.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		stepped_out = maxi(stepped_out, wm.dinos_spawned_count)
		if not wm.is_wave_active:
			home = true
			break
	assert_eq(stepped_out, out, "Nobody steps out after dusk")
	assert_true(home, "The raid is over when those out are home")
	for d in tree.get_nodes_in_group("dinos"):
		if is_instance_valid(d) and not d.is_in_group("guard_dinos") and not d.is_queued_for_deletion():
			assert_true(false, "No raider is left on the field: %s at %s" % [d.name, d.global_position])

func test_06_the_beacons_last_wave_comes_whatever_the_hour() -> void:
	var main = await _level()
	var wm = main.wave_manager
	_set_clock(_at("night") + 10.0)
	assert_false(wm.raiders_out(), "Night: the raiders are asleep")
	wm.start_final_wave()
	assert_true(wm.is_wave_active and wm.final_wave, "The beacon woke the valley: the last wave comes all the same")

func test_07_the_screen_shows_the_day_and_says_each_part_as_it_begins() -> void:
	var main = await _level()
	var hud = main.hud
	_set_clock(_at("day") + 60.0, 2)
	await wait_frames(2)
	var label: Label = hud.root_control.find_child("DayLabel", true, false) as Label
	assert_not_null(label, "A dial for the day")
	assert_eq(label.text, tr("HUD_DAY") % 2, "which says which day")
	var ring: TextureProgressBar = hud.root_control.find_child("DayRing", true, false) as TextureProgressBar
	assert_almost_eq(ring.value, float(game_state_node.time_of_day()) / float(_day()["length"]), 0.01,
		"its ring as far round as the day")
	var by_day: Color = ring.tint_progress
	_set_clock(_at("dusk") + 1.0, 2)
	await wait_frames(2)
	assert_ne(ring.tint_progress, by_day, "At dusk the ring turns")
	# The run's first dusk says, with that, what the dark is and what fire is for (test_v06_fire), with
	# the key of the torch's tile -- which comes with it, the first after Build: the second key.
	var key: String = hud.hero_commands.key_of("torch")
	assert_eq(key, OS.get_keycode_string(int(config_node.CONTROLS["command_keys"][1])), "(the torch's the second key)")
	assert_eq(String(hud.hint_label.text), tr("HINT_DUSK_FIRST") % key, "and the screen says the raiders are going home")
