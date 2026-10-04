# res://tests/test_v07_the_pod.gd
# The player, 2026-10-04: "睡觉就能回血不错，但不吃东西不喝水能活下来还是有点怪……如果是合理简化，就把未来船舱的睡觉
# 装置科幻化，有类似泡营养液式的身体完全恢复（七龙珠的泡水装置），这样就不用吃东西喝水" (GAME-DESIGN 3.0).
#
# THE HEALING POD, where the kitchen stood: a tank of nutrient fluid. Hurt, he is sent to it, climbs in through its
# hatch and floats there, mending POD.heal_per_second a second, till he is whole -- and while he is in it nothing
# else in the cabin is worked. Whole, it lets him out in front of its hatch; sent anywhere else, he climbs out,
# keeping what it mended. There is no eating and no drinking: the kitchen, its meals and being fed went.
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

func _rate() -> float:
	return float(config_node.POD["heal_per_second"])

## Him inside the cabin, at its door, and the room told.
func _inside(main: Node) -> void:
	main.hero.global_position = main.current_core.door_inside()
	main.current_core.recheck_hero()
	await wait_physics_frames(2)

## Until he floats in `pod`, or `seconds` of physics have gone.
func _until_in(main: Node, pod: Node, seconds: float = 12.0) -> bool:
	for i in range(int(seconds * float(Engine.physics_ticks_per_second))):
		if main.hero.is_resting_in(pod):
			return true
		await wait_physics_frames(1)
	return main.hero.is_resting_in(pod)

func test_01_the_pod_stands_where_the_kitchen_did() -> void:
	assert_has(config_node.STATIONS, "pod", "The cabin's benches have the healing pod")
	assert_false(config_node.STATIONS.has("kitchen"), "and no kitchen")
	assert_gt(_rate(), 0.0, "It mends")
	var main = await _level()
	var pod = main.current_core.station(HealingPod.STATION)
	assert_true(pod is HealingPod, "The cabin's pod is a healing pod")
	assert_true(VisualLibrary.has_art("station/pod"), "drawn as its model")
	assert_eq(int(pod.collision_layer), int(config_node.LAYER_PICK), "Clicked, not walked round: he climbs into it")

func test_02_a_rest_is_offered_while_he_is_hurt_and_costs_only_time() -> void:
	var main = await _level()
	var pod = main.current_core.station(HealingPod.STATION)
	var hero = main.hero
	hero.stamina = hero.max_stamina
	assert_false(pod.can_offer(HealingPod.REST), "Whole and rested, there is no need of it")
	assert_eq(pod.get_display_info()["status"], tr("POD_WHOLE"), "and it says so")
	hero.current_hp = hero.max_hp - 4.0
	assert_true(pod.can_offer(HealingPod.REST), "Hurt, a rest is on offer")
	assert_true(pod.inputs_of(HealingPod.REST).is_empty(), "for nothing")
	assert_almost_eq(float(pod.time_of(HealingPod.REST)), 4.0 / _rate(), 0.001, "and as long as mending what is missing takes")

func test_03_begun_he_climbs_in_and_floats_on_its_floor_facing_out() -> void:
	var main = await _level()
	var pod = main.current_core.station(HealingPod.STATION)
	var hero = main.hero
	await _inside(main)
	hero.current_hp = hero.max_hp * 0.4
	assert_true(pod.begin(HealingPod.REST), "The rest begins")
	assert_eq(hero.rest_pod(), pod, "and he is sent to the pod")
	assert_true(await _until_in(main, pod), "He gets there and climbs in")
	var flat := Vector2(hero.global_position.x - pod.global_position.x, hero.global_position.z - pod.global_position.z)
	assert_lt(flat.length(), 0.05, "at its middle")
	var body: Node3D = hero.find_child("Body", false, false) as Node3D
	if body:
		assert_almost_eq(body.position.y, float(config_node.POD["floor"]), 0.001, "drawn standing on the tank's floor")
	var facing: Vector3 = -hero.global_transform.basis.z
	assert_gt(facing.dot(pod.global_transform.basis.z), 0.9, "facing out through its hatch")

func test_04_he_mends_at_its_rate_and_nothing_else_is_worked() -> void:
	var main = await _level()
	var cabin = main.current_core
	var pod = cabin.station(HealingPod.STATION)
	var bench = cabin.station("workbench")
	var hero = main.hero
	stock_everything()
	know_everything()
	await _inside(main)
	assert_true(bench.begin("stone_pick") or bench.begin("arrow_wood"), "Something is under way at the workbench")
	hero.current_hp = hero.max_hp * 0.4
	pod.begin(HealingPod.REST)
	assert_true(await _until_in(main, pod), "He is in the pod")
	# Driven by hand, in one frame: what a second in it does.
	var hp: float = hero.current_hp
	var worked: float = bench.progress
	cabin._process(1.0)
	assert_almost_eq(hero.current_hp, minf(hero.max_hp, hp + _rate()), 0.001, "A second in it mends POD.heal_per_second")
	assert_almost_eq(bench.progress, worked, 0.0001, "and the workbench stands still meanwhile")

func test_05_whole_it_lets_him_out_in_front_of_its_hatch() -> void:
	var main = await _level()
	var cabin = main.current_core
	var pod = cabin.station(HealingPod.STATION)
	var hero = main.hero
	await _inside(main)
	hero.current_hp = hero.max_hp - _rate() * 0.5
	pod.begin(HealingPod.REST)
	assert_true(await _until_in(main, pod), "He is in the pod")
	pod.work(1.0)
	assert_almost_eq(hero.current_hp, hero.max_hp, 0.001, "Whole")
	assert_false(hero.is_resting(), "and out")
	assert_null(hero.rest_pod(), "the pod done with him")
	assert_eq(String(pod.active_recipe), "", "and idle")
	var to: Vector3 = hero.target_destination
	var front: Vector3 = pod.front()
	assert_lt(Vector2(to.x - front.x, to.z - front.z).length(), 0.3, "He steps out in front of its hatch")
	var body: Node3D = hero.find_child("Body", false, false) as Node3D
	if body:
		assert_almost_eq(body.position.y, 0.0, 0.001, "drawn on the room's floor again")

func test_06_sent_elsewhere_he_climbs_out_keeping_what_it_mended() -> void:
	var main = await _level()
	var cabin = main.current_core
	var pod = cabin.station(HealingPod.STATION)
	var hero = main.hero
	await _inside(main)
	hero.current_hp = hero.max_hp * 0.3
	pod.begin(HealingPod.REST)
	assert_true(await _until_in(main, pod), "He is in the pod")
	pod.work(2.0)
	var mended: float = hero.current_hp
	assert_gt(mended, hero.max_hp * 0.3, "It has mended some")
	hero.move_to(cabin.door_inside())
	await wait_frames(2)
	assert_false(hero.is_resting(), "Sent to the door, he is out")
	assert_eq(String(pod.active_recipe), "", "and the rest is over")
	assert_almost_eq(hero.current_hp, mended, 0.001, "what it mended is his")

func test_07_no_eating_and_no_drinking() -> void:
	# The kitchen went, and its meals, its pot and being fed with it (GAME-DESIGN 3.0).
	for key in ["DISHES", "COOKING_METHODS", "EATING"]:
		assert_false(key in config_node, "Config has no %s" % key)
	for key in ["fed", "meals"]:
		assert_false(key in game_state_node, "nor the run its %s" % key)
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	assert_false(hero.has_method("order_eat"), "and he has no meal to eat")
	assert_false(config_node.RESOURCES.has("prime_meat"), "The boss's cut went with them: meat is meat")
	for species in config_node.DINOS:
		assert_false(config_node.DINOS[species].get("drops", {}).has("prime_meat"), "%s leaves meat, if anything" % species)
