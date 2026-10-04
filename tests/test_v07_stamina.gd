# res://tests/test_v07_stamina.gd
# The player, 2026-10-04: "加一个疲劳值（或者叫精力），人会逐步疲劳这样就需要去睡觉，精力掉完，就开始掉血"; "睡觉用治疗仓，回血回精
# 力，晚上精力掉的稍微快一点，显示数值400太高，显示数值低一些，code里的数值和界面分开" (GAME-DESIGN 3.0).
#
# 精力 STAMINA: awake, he tires -- faster in the dark; asleep in the healing pod, it comes back as his health does; run
# out, his health goes for want of sleep (not a bite), and that is what the defeat says if it kills him. And the
# numbers the player reads are the code's at Config.SHOWN.
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
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

func _s(key: String) -> float:
	return float(config_node.STAMINA[key])

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

## The day's clock set to `at` seconds into a day (Config.DAY.parts).
func _clock_to(part: String) -> void:
	var parts: Dictionary = config_node.DAY["parts"]
	game_state_node.day_clock = float(parts[part]) + 5.0
	assert_eq(String(game_state_node.day_part()), part, "(it is %s)" % part)

func test_01_he_starts_rested_and_tires_awake() -> void:
	var main = await _level()
	var hero = main.hero
	assert_almost_eq(hero.max_stamina, _s("max"), 0.001, "His most is Config's")
	# (the level's first frames gone by: a moment's tiring)
	assert_almost_eq(hero.stamina, hero.max_stamina, _s("drain_per_second") * 2.0, "and he starts rested")
	_clock_to("day")
	var was: float = hero.stamina
	hero._tire(10.0)
	assert_almost_eq(was - hero.stamina, _s("drain_per_second") * 10.0, 0.001, "By day it runs down at its rate")
	# A whole day takes about three quarters of it: tired once a day, not every raid.
	var day: Dictionary = config_node.DAY
	var light: float = float(day["parts"]["dusk"])
	var dark: float = float(day["length"]) - light
	var a_day: float = _s("drain_per_second") * (light + dark * _s("night_factor"))
	assert_gt(a_day / _s("max"), 0.5, "A whole day takes most of it")
	assert_lt(a_day / _s("max"), 0.95, "not all")

func test_02_in_the_dark_it_runs_down_faster() -> void:
	var main = await _level()
	var hero = main.hero
	assert_gt(_s("night_factor"), 1.0, "Faster in the dark")
	_clock_to("night")
	var was: float = hero.stamina
	hero._tire(10.0)
	assert_almost_eq(was - hero.stamina, _s("drain_per_second") * _s("night_factor") * 10.0, 0.001,
		"by night, night_factor times the day's")
	_clock_to("dusk")
	was = hero.stamina
	hero._tire(10.0)
	assert_almost_eq(was - hero.stamina, _s("drain_per_second") * _s("night_factor") * 10.0, 0.001, "and at dusk")

func test_03_run_out_his_health_goes_and_it_is_not_a_bite() -> void:
	var main = await _level()
	var hero = main.hero
	hero.stamina = 0.0
	var hp: float = hero.current_hp
	var state: int = int(hero.current_state)
	hero._tire(2.0)
	assert_almost_eq(hp - hero.current_hp, _s("exhausted_hp_per_second") * 2.0, 0.001, "Run out, his health goes at its rate")
	assert_eq(int(hero.current_state), state, "not a bite: he does not turn to fight")
	assert_true(hero.is_spent(), "he is spent")
	assert_true(hero.is_tired(), "and tired")

func test_04_worn_out_to_nothing_the_defeat_says_so() -> void:
	var main = await _level()
	var hero = main.hero
	hero.stamina = 0.0
	hero.current_hp = 0.5
	hero._tire(1.0)
	assert_eq(int(hero.current_state), int(Hero.State.DEAD), "Worn out to nothing, he falls")
	assert_true(bool(game_state_node.hero_killer.get("exhausted", false)), "for want of sleep, and it is said")
	if main.hud and main.hud.has_method("_defeat_text"):
		game_state_node.lost_to = "hero"
		assert_eq(main.hud._defeat_text(game_state_node), tr("GAME_DEFEAT_HERO_EXHAUSTED"), "the defeat says he worked himself into the ground")

func test_05_the_pod_is_where_he_sleeps() -> void:
	var main = await _level()
	var pod = main.current_core.station(HealingPod.STATION)
	var hero = main.hero
	hero.stamina = hero.max_stamina
	assert_false(pod.can_offer(HealingPod.REST), "Whole and rested, there is no need of it")
	hero.stamina = hero.max_stamina * 0.5
	assert_true(pod.can_offer(HealingPod.REST), "Tired but whole, a sleep is on offer")
	assert_almost_eq(float(pod.time_of(HealingPod.REST)), hero.max_stamina * 0.5 / _s("rest_per_second"), 0.001,
		"as long as resting him takes")
	hero.current_hp = hero.max_hp - 30.0
	var mend: float = 30.0 / float(config_node.POD["heal_per_second"])
	assert_almost_eq(float(pod.time_of(HealingPod.REST)), maxf(mend, hero.max_stamina * 0.5 / _s("rest_per_second")), 0.001,
		"hurt as well, as long as the longer of the two")
	hero.global_position = main.current_core.door_inside()
	main.current_core.recheck_hero()
	await wait_physics_frames(2)
	pod.begin(HealingPod.REST)
	var got_in: bool = false
	for i in range(int(12.0 * float(Engine.physics_ticks_per_second))):
		if hero.is_resting_in(pod):
			got_in = true
			break
		await wait_physics_frames(1)
	assert_true(got_in, "He climbs in")
	var hp: float = hero.current_hp
	var rested: float = hero.stamina
	pod.work(1.0)
	assert_almost_eq(hero.current_hp - hp, float(config_node.POD["heal_per_second"]), 0.001, "Asleep, he mends")
	assert_almost_eq(hero.stamina - rested, _s("rest_per_second"), 0.001, "and rests")
	var before: float = hero.stamina
	hero._tire(5.0)
	assert_almost_eq(hero.stamina, before, 0.0001, "and tires none while he sleeps")
	for i in 60:
		if not hero.is_resting():
			break
		pod.work(1.0)
	assert_almost_eq(hero.stamina, hero.max_stamina, 0.001, "Out, rested")
	assert_almost_eq(hero.current_hp, hero.max_hp, 0.001, "and whole")
	assert_false(hero.is_resting(), "and out of it")

func test_06_tired_he_says_so_and_the_card_shows_it() -> void:
	var main = await _level()
	var hero = main.hero
	var said: Array = []
	var hear := func(key: String, _s2: float, _a: Array) -> void:
		said.append(key)
	var eb = tree.root.get_node("EventBus")
	eb.hero_spoke.connect(hear)
	hero.stamina = hero.max_stamina * _s("tired_below") + 0.05
	hero._tell_stamina()
	await wait_frames(1)
	hero._tire(2.0)
	await wait_frames(1)
	var tired: bool = false
	for k in said:
		if String(k).begins_with("BARK_TIRED"):
			tired = true
	assert_true(tired, "Gone under tired_below, he says he must sleep")
	eb.hero_spoke.disconnect(hear)
	var info: Dictionary = hero.get_display_info()
	assert_almost_eq(float(info["stamina"]), hero.stamina, 0.001, "His card is told his stamina")
	assert_almost_eq(float(info["max_stamina"]), hero.max_stamina, 0.001, "and its most")

func test_07_the_numbers_shown_are_the_codes_at_a_quarter() -> void:
	var shown: float = float(config_node.SHOWN["points"])
	assert_almost_eq(config_node.shown(400.0), 400.0 * shown, 0.001, "The interface shows a quarter of the code's")
	var cabin_hp: float = float(config_node.BUILDINGS["core"]["hp"])
	assert_eq(config_node.shown_pair(cabin_hp, cabin_hp), "%d / %d" % [int(round(cabin_hp * shown)), int(round(cabin_hp * shown))],
		"the cabin whole")
	assert_eq(config_node.shown_pair(0.1, 40.0), "1 / %d" % int(round(40.0 * shown)), "What is alive shows at least 1")
	assert_eq(config_node.shown_pair(0.0, 40.0), "0 / %d" % int(round(40.0 * shown)), "and what is not, none")
	var main = await _level()
	var hero = main.hero
	await wait_frames(2)
	if main.hud and main.hud.hero_hp_label:
		assert_eq(main.hud.hero_hp_label.text, config_node.shown_pair(hero.current_hp, hero.max_hp), "His medallion shows it so")
	assert_not_null(main.hud.hero_stamina_bar, "and his stamina under it")
	var detail: String = UiKit.ammo_detail("arrow_wood")
	var hit: float = float(config_node.AMMO["arrow_wood"]["damage"])
	assert_true(detail.find(config_node.shown_text(hit)) >= 0, "An arrow's damage is said as shown")
	assert_eq(detail.find(config_node.factor_text(hit)), -1, "not as the code keeps it")
