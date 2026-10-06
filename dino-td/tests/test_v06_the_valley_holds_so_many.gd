# res://tests/test_v06_the_valley_holds_so_many.gd
# The player, v0.6 round six: "没有及时造信标，恐龙会一直增加吗，那感觉也不符合真实感" -- and, on a cap: "普通来袭封顶的话，
# 玩家不是可以一直不造信标，一直囤积实力？" Chosen: "材料会用完". A raid the clock sends grows to what the valley
# holds and no further (MAPS.<id>.raid_most, toughest); what keeps a run from waiting it out behind its walls
# is that the trees, the rock and the wrecks do not come back.
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
		game_state_node.reset_game(7)

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
	main.wave_manager.auto_raid_enabled = false
	return main

func _map() -> Dictionary:
	return config_node.map_data()

func test_01_a_raid_grows_to_what_the_valley_holds_and_no_further() -> void:
	var main = await _level()
	var wm = main.wave_manager
	var most: int = int(_map()["raid_most"])
	assert_gt(most, 0, "The valley says how many it holds")
	wm.elapsed_time = 60.0
	var first: int = wm.raid_size(1)
	assert_lt(first, most, "The first raids are well under it (%d)" % first)
	var biggest: int = 0
	for n in [12, 24, 40, 80]:
		wm.elapsed_time = 60.0 * float(n) * 3.0
		for i in 5:
			biggest = maxi(biggest, wm.raid_size(n))
	assert_eq(biggest, most, "Hours in, raid after raid, it is what the valley holds and no more (%d)" % biggest)

func test_02_nor_do_they_grow_tougher_past_the_toughest() -> void:
	await _level()
	var toughest: float = float(_map()["toughest"])
	var big: int = int(config_node.WAVES["big_every"])
	for n in range(1, big * 20 + 1):
		game_state_node.wave_number = n
		game_state_node._on_wave_ended(n)
	for stat in ["hp", "damage"]:
		assert_lte(float(game_state_node.dino_stat_multipliers[stat]), toughest + 0.0001,
			"Twenty big raids on, %s is no more than x%.2f" % [stat, toughest])
	assert_almost_eq(float(game_state_node.dino_stat_multipliers["hp"]), toughest, 0.0001, "(and it did grow to it)")

func test_03_what_he_takes_from_the_valley_does_not_come_back() -> void:
	var main = await _level()
	var wood: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood":
			wood = n
			break
	assert_not_null(wood, "(a tree)")
	if wood == null:
		return
	var guard: int = 0
	while not bool(wood.is_depleted) and guard < 10000:
		wood.harvest(5)
		guard += 1
	assert_true(bool(wood.is_depleted), "(felled to the last)")
	game_state_node._run_the_day(float(config_node.DAY["length"]) * 2.0)
	await wait_frames(3)
	assert_true(not is_instance_valid(wood) or bool(wood.is_depleted), "Two days on, it has not grown back")
