# res://tests/test_v06_from_the_edge.gd
# v0.6 round four, the player: "我认为巢穴不应该出来太多，如果需要很多恐龙，比如信标恐龙就应该来自边界，这样即使恐龙走
# 一会儿到也符合一大波的效果，而且从边界出来的你可以先加速后正常速度".
#
# A raid is a hunting party of the nest, not all of it: at most Config.RAIDS.nest_most of one step
# out of the nest, and the rest come in from the valley's edge behind it (MAPS.reinforce_from) -- in
# the beacon's final wave from every edge. One come in from the edge hurries (RAIDS.edge_hurry) while
# nobody sees it and it is far from the cabin, then goes at its own pace for good.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

const LARGE := "valley_large"

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
		game_state_node.chosen_map_id = ""
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null:
		game_state_node.chosen_map_id = ""
		game_state_node.reset_game()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

func _level_on(map_id: String = "") -> Node:
	game_state_node.chosen_map_id = map_id
	game_state_node.reset_game()
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func _nest_most() -> int:
	return int(config_node.RAIDS["nest_most"])

## The raid under way, stepped out one at a time as the timer would -- stopped, so the test does it.
func _step_out(wm: Node, n: int) -> Array:
	if wm.spawn_timer:
		wm.spawn_timer.stop()
	var out: Array = []
	for i in n:
		var d = wm.spawn_dino()
		if d == null:
			break
		_cleanup_nodes.append(d)
		d.set_physics_process(false)
		out.append(d)
	return out

func _near(a: Vector3, b: Vector3, slack: float = 1.0) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() <= slack

func _out_of(at: Vector3, points: Array) -> int:
	for i in points.size():
		if _near(at, points[i]):
			return i
	return -1

## One come in from `edge`, hurrying, marching for the cabin.
func _come_in(main: Node, edge: Vector3) -> Node:
	var kind: String = String(config_node.map_data()["raiders"].keys()[0])
	var d = load(String(config_node.get_dino_script_path(kind))).new()
	_cleanup_nodes.append(d)
	main.dinos_container.add_child(d)
	d.setup(kind)
	d.global_position = edge
	d.set_waypoints([edge, main.wave_manager.waypoints.back()])
	d.hurry_in(float(config_node.RAIDS["edge_hurry"]))
	return d

func test_01_a_raid_is_a_party_from_the_nest_and_the_rest_come_from_the_edge() -> void:
	var main = await _level_on()
	var wm = main.wave_manager
	var edges: Array = wm.reinforce_positions
	assert_gt(edges.size(), 0, "The valley has an edge behind the nest to come in from")
	wm.start_wave(1, _nest_most() + 3)
	var dinos: Array = _step_out(wm, wm.dinos_to_spawn)
	assert_eq(dinos.size(), _nest_most() + 3, "The whole raid stepped out")
	var turns: Dictionary = {}
	for i in dinos.size():
		var d = dinos[i]
		if i < _nest_most():
			assert_true(_near(d.global_position, wm.nest_spawn_position), "#%d of the party steps out of the nest" % i)
			assert_eq(float(d.hurry), 1.0, "at its own pace")
		else:
			var j: int = _out_of(d.global_position, edges)
			assert_gte(j, 0, "#%d comes in from the edge behind the nest" % i)
			turns[j] = true
			assert_gt(float(d.hurry), 1.0, "hurrying")
			assert_eq(d.waypoints.back(), wm.waypoints.back(), "straight for the cabin")
	assert_eq(turns.size(), mini(3, edges.size()), "each of the edge's ways in, in turn")

func test_02_the_beacons_final_wave_comes_from_every_edge() -> void:
	var main = await _level_on()
	var wm = main.wave_manager
	# The final wave, big enough to need every edge (at the run's start one is a handful).
	wm.final_wave = true
	var edges: Array = wm.edge_origins()
	wm.start_wave(wm._next_wave_number(), _nest_most() + edges.size() * 2, true)
	assert_eq(edges.size(), wm.reinforce_positions.size() + wm.entry_positions.size(),
		"Every edge: behind the nest, and every way into the valley")
	var n: int = mini(wm.dinos_to_spawn, _nest_most() + edges.size() * 2)
	var dinos: Array = _step_out(wm, n)
	var from_nest: int = 0
	var used: Dictionary = {}
	for d in dinos:
		if _near(d.global_position, wm.nest_spawn_position):
			from_nest += 1
		var j: int = _out_of(d.global_position, edges)
		if j >= 0:
			used[j] = true
	assert_lte(from_nest, _nest_most(), "No more than the nest's party from the nest")
	assert_eq(used.size(), edges.size(), "and every edge sends its share")

func test_03_a_beacon_stage_raid_comes_in_by_the_valleys_ways_in() -> void:
	# What a repaired stage stirs up is the beacon's, and comes in from the valley's ends ("信标恐龙
	# 就应该来自边界"; the ship's wrecks, v0.6 round four: GAME-DESIGN 8.3, test_v06_wrecks 8) --
	# none of it out of the nest, however many.
	var main = await _level_on()
	var wm = main.wave_manager
	wm._stirred = _nest_most() + 2
	wm.start_stage_wave()
	var dinos: Array = _step_out(wm, wm.dinos_to_spawn)
	assert_eq(dinos.size(), _nest_most() + 2, "All of it steps out")
	for d in dinos:
		assert_false(_near(d.global_position, wm.nest_spawn_position), "none out of the nest")
		assert_gte(_out_of(d.global_position, wm.entry_positions), 0, "each by one of the valley's ways in")

func test_04_come_in_from_the_edge_it_hurries_while_nobody_sees_it() -> void:
	# The large valley: its edge is far enough off for the walk in to be worth hurrying.
	var main = await _level_on(LARGE)
	var wm = main.wave_manager
	var edge: Vector3 = wm.reinforce_positions[0]
	assert_false(main.fog.is_in_sight(edge), "(nobody sees the edge)")
	var d = _come_in(main, edge)
	var from: Vector3 = d.global_position
	await wait_seconds(0.5)
	var went: float = Vector2(d.global_position.x - from.x, d.global_position.z - from.z).length()
	assert_gt(float(d.hurry), 1.0, "Unseen and far off, it hurries")
	assert_gt(went, float(d.speed) * 0.5 * 1.3, "faster than its own pace: %.2f m in half a second" % went)
	# In sight: the Hero beside it.
	main.hero.global_position = d.global_position + Vector3(2.0, 0.0, 0.0)
	await wait_seconds(float(config_node.FOG["every"]) * 3.0 + 0.1)
	assert_eq(float(d.hurry), 1.0, "Seen, it goes at its own pace")
	main.hero.global_position = main.current_core.global_position + Vector3(0.0, 0.0, 4.0)
	await wait_seconds(float(config_node.FOG["every"]) * 3.0 + 0.1)
	assert_eq(float(d.hurry), 1.0, "and does from then on, out of sight again")

func test_05_near_the_cabin_it_goes_at_its_own_pace() -> void:
	var main = await _level_on(LARGE)
	var core: Vector3 = main.current_core.global_position
	var near: float = float(config_node.RAIDS["edge_hurry_until"])
	# Unseen -- past the cabin's own sight and his -- but near.
	main.hero.global_position = core + Vector3(0.0, 0.0, 8.0)
	var at: Vector3 = core + Vector3(-near * 0.8, 0.0, 0.0)
	var d = _come_in(main, at)
	await wait_physics_frames(2)
	assert_eq(float(d.hurry), 1.0, "Within %.0f m of the cabin, it goes at its own pace" % near)

func test_07_one_that_let_go_further_along_marches_on_not_back() -> void:
	# It went for something else from its first thought -- a sealed ring's wall -- so it never came
	# within reach of the edge it set out from; let go of that twelve metres on, it marched all the way
	# back to the edge before turning for the cabin (the large valley's final wave).
	var main = await _level_on(LARGE)
	var wm = main.wave_manager
	var edge: Vector3 = wm.reinforce_positions[0]
	var cabin: Vector3 = wm.waypoints.back()
	var d = _come_in(main, edge)
	d.set_physics_process(false)
	d._set_mode(d.Mode.BREACH)      # gone for a wall from its first thought
	var on_the_way: Vector3 = edge + (cabin - edge).normalized() * 12.0
	d.global_position = on_the_way
	d.current_waypoint_index = 0
	d._set_mode(d.Mode.MARCH)       # and let go of it twelve metres on
	assert_eq(int(d.current_waypoint_index), d.waypoints.size() - 1, "It rejoins its road on the last leg")
	assert_true(_near(d._journey_goal(), cabin, 2.0), "which leads on to the cabin, not back to the edge")

func test_09_watching_the_nest_and_the_edge_behind_it_they_come_round_the_other_ways() -> void:
	# The debug-agent's BUG-014: in the small valley the edge is two metres behind the nest, and standing
	# before the nest he saw the nest and both ways in behind it -- and the raid stepped out in front of
	# him anyway. Now it comes round by the valley's other ways in; and with every way in watched it
	# waits, unseen, and steps out when one is not.
	var main = await _level_on()
	var wm = main.wave_manager
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.max_hp = 9999.0       # the nest's guards will have a go at him
	main.hero.current_hp = 9999.0
	main.hero.global_position = wm.nest_spawn_position + Vector3(0.3, 0.0, 4.0)
	await wait_seconds(float(config_node.FOG["every"]) * 3.0 + 0.1)
	assert_true(main.fog.sees(wm.nest_spawn_position), "(he is watching the nest)")
	for edge in wm.reinforce_positions:
		assert_true(main.fog.sees(edge), "(and the way in behind it at %s)" % edge)
	wm.start_wave(1, 4)
	var dinos: Array = _step_out(wm, 4)
	assert_eq(dinos.size(), 4, "They still come")
	for d in dinos:
		assert_false(main.fog.sees(d.global_position), "none where he can see it")
		assert_gte(_out_of(d.global_position, wm.entry_positions), 0, "round by the valley's other ways in")
	# Every way in watched -- a fire lit at each, say -- none steps out, and the raid waits.
	for at in wm.entry_positions:
		main.fog._see_round(at, 3.0)
	for edge in wm.reinforce_positions:
		main.fog._see_round(edge, 3.0)
	wm.start_wave(2, 2)
	var none: Array = _step_out(wm, 2)
	assert_eq(none.size(), 0, "Every way in watched, nothing steps out")
	assert_eq(int(wm.dinos_spawned_count), 0, "and the raid waits for one to be free")
	assert_eq(wm.wave_roster.size(), 2, "with nobody taken off its roster")

func test_08_nothing_steps_out_where_he_can_see_it() -> void:
	# "raid的时候直接冒出新的恐龙似乎有点奇怪": the nest watched, its party comes in from the edge behind it;
	# a way in at the edge watched, the next one nobody sees.
	var main = await _level_on(LARGE)
	var wm = main.wave_manager
	var edges: Array = wm.reinforce_positions
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.max_hp = 9999.0       # the nest's guards will have a go at him
	main.hero.current_hp = 9999.0
	main.hero.global_position = wm.nest_spawn_position + Vector3(3.0, 0.0, 0.0)
	await wait_seconds(float(config_node.FOG["every"]) * 3.0 + 0.1)
	assert_true(main.fog.sees(wm.nest_spawn_position), "(he is watching the nest)")
	wm.start_wave(1, 2)
	var dinos: Array = _step_out(wm, 2)
	for d in dinos:
		assert_false(_near(d.global_position, wm.nest_spawn_position), "Nothing steps out of the nest in front of him")
		assert_gte(_out_of(d.global_position, edges), 0, "it comes in from the edge behind it")
	# Now watching one of the edge's ways in.
	main.hero.global_position = edges[0] + Vector3(2.0, 0.0, 0.0)
	await wait_seconds(float(config_node.FOG["every"]) * 3.0 + 0.1)
	assert_true(main.fog.sees(edges[0]), "(he is watching that way in)")
	wm.start_wave(2, _nest_most() + edges.size())
	for d in _step_out(wm, _nest_most() + edges.size()):
		assert_false(_near(d.global_position, edges[0]), "Nothing comes in where he stands")

func test_06_every_edge_is_on_its_field_and_has_a_way_to_the_cabin() -> void:
	for map_id in [String(config_node.DEFAULT_MAP_ID), LARGE]:
		var map: Dictionary = config_node.map_data(map_id)
		var half: float = float(config_node.terrain_of(map_id)["field_half"])
		var blocked: Array = map["default_blocked_cells"]
		var taken: Array = []
		for node in map["default_resource_nodes"]:
			taken.append(node["cell"])
		for cell in map["reinforce_from"]:
			var tile: float = float(config_node.TILE_SIZE)
			var at := Vector2((float(cell.x) + 0.5) * tile, (float(cell.y) + 0.5) * tile)
			assert_lt(maxf(absf(at.x), absf(at.y)), half, "%s: %s on the field" % [map_id, str(cell)])
			assert_false(blocked.has(cell) or taken.has(cell), "%s: %s clear" % [map_id, str(cell)])
	var main = await _level_on(LARGE)
	var core: Vector3 = main.current_core.global_position
	for edge in main.wave_manager.reinforce_positions:
		assert_true(main.nav_maps.is_reachable(edge, core, NavMaps.For.RAID), "From %s there is a way to the cabin" % str(edge))
