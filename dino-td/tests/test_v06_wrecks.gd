# res://tests/test_v06_wrecks.gd
# v0.6 round four, the ship's wrecks and the beacon's parts (GAME-DESIGN 9.3, "信标变成冒险"). The
# player chose: "翻找几秒，直接入库" -- a few seconds' search and the part goes into the stock; "烟柱，远处
# 看得见" -- smoke seen from afar; "河边 / 巢后 / 东南边缘" -- by the river, behind the nest, at the south-
# east edge where raids come in.
#
# Each stage of the beacon takes one part -- the antenna, the battery, the control board -- and each
# part is in one wreck (Config.WRECKS, RESOURCE_NODES). A wreck is worked like a tree: its strokes'
# search, and the part falls at his feet. Until it is searched its smoke rises over the mist
# (WreckSmoke). What a repaired stage stirs up comes in by the valley's ways in, in turn.
#
# Found one from another (the player, 2026-10-02: "第一个信标有烟，第二个信标需要第一个信标给位置，第三个需要
# 第二个"): only the first stage's wreck smokes at the start; a stage mended locates the next one's.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

const LARGE := "valley_large"
const PARTS: Array[String] = ["antenna", "battery", "board"]

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

## The wreck holding `part` on the level.
func _wreck(part: String) -> Node:
	for n in tree.get_nodes_in_group("resource_nodes"):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and String(n.resource_type) == part:
			return n
	return null

## The smoke over `wreck`.
func _smoke_of(wreck: Node) -> WreckSmoke:
	for s in tree.get_nodes_in_group(WreckSmoke.GROUP):
		if is_instance_valid(s) and (s as WreckSmoke).wreck == wreck:
			return s as WreckSmoke
	return null

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## How far `p` is from the segment `a`-`b`, on the ground.
func _off_the_way(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t: float = clampf(ap.dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return (ap - ab * t).length()

# ==============================================================================
# 1. What the beacon takes, and where it is
# ==============================================================================

func test_01_each_stage_takes_one_part_and_each_part_is_in_one_wreck() -> void:
	for map_id in ["valley", LARGE]:
		var map: Dictionary = config_node.map_data(map_id)
		var stages: Array = map["beacon"]["stages"]
		assert_eq(stages.size(), PARTS.size(), "%s: a part for each stage" % map_id)
		for i in stages.size():
			var parts: Array = []
			for res_id in stages[i]["inputs"]:
				if config_node.is_part(String(res_id)):
					parts.append(String(res_id))
			assert_eq(parts, [PARTS[i]], "%s: stage %d takes the %s, and only that part" % [map_id, i + 1, PARTS[i]])
			assert_eq(int(stages[i]["inputs"][PARTS[i]]), 1, "one of it")
		for part in PARTS:
			var wrecks: int = 0
			for item in map["default_resource_nodes"]:
				if String(item["type"]) == part:
					wrecks += 1
			assert_eq(wrecks, 1, "%s: the %s is in one wreck" % [map_id, part])
			var row: Dictionary = config_node.RESOURCE_NODES[part]
			assert_eq(int(row["capacity"]), 1, "which gives the one")
			assert_true(bool(row.get("smoke", false)), "and smokes till it is searched")
			assert_has(config_node.RESOURCES, part, "The %s is held in the stock, as a material is" % part)

func test_02_the_wrecks_lie_where_their_dangers_are_and_he_can_reach_them() -> void:
	for map_id in ["valley", LARGE]:
		var main = await _level_on(map_id)
		await nav_settled(main)
		var map: Dictionary = game_state_node.map_data()
		var gm = main.grid_manager
		var nav = main.nav_maps
		var door: Vector3 = main.current_core.door_outside()
		for part in PARTS:
			var w: Node3D = _wreck(part) as Node3D
			assert_not_null(w, "%s: the %s's wreck is on the field" % [map_id, part])
			if w == null:
				continue
			var ground: Vector3 = nav.closest_point(w.global_position, NavMaps.For.HERO)
			assert_true(nav.is_reachable(door, ground, NavMaps.For.HERO), "%s: he can walk to the %s's wreck" % [map_id, part])
		# By the river: where a phytosaur come up at night hunts him at it (PROWL.hunts_within).
		var river: float = INF
		for c in map["prowl_from"]:
			river = minf(river, _flat(gm.cell_to_world(c), (_wreck("antenna") as Node3D).global_position))
		assert_lte(river, float(config_node.PROWL["hunts_within"]), "%s: the antenna's wreck is by the phytosaurs' landing" % map_id)
		# Behind the nest, in its guards' reach while they are awake.
		var nest: Vector3 = gm.cell_to_world(map["default_nest_cell"])
		var battery: Vector3 = (_wreck("battery") as Node3D).global_position
		var guards: Dictionary = config_node.NEST_GUARDS
		assert_lte(_flat(nest, battery), float(guards["post_radius"]) + float(guards["aggro_radius"]),
			"%s: the battery's wreck is in the guards' reach" % map_id)
		assert_gt(_flat(door, battery), _flat(door, nest), "%s: behind the nest, from the cabin" % map_id)
		# On the way in from the south-east: close by the straight way from it to the cabin.
		var board: Vector3 = (_wreck("board") as Node3D).global_position
		var way_in: Vector3 = Vector3.ZERO
		var best: float = INF
		for c in map["entries"]:
			var at: Vector3 = gm.cell_to_world(c)
			if _flat(at, board) < best:
				best = _flat(at, board)
				way_in = at
		var cabin: Vector3 = main.current_core.global_position
		assert_true(way_in.x > cabin.x and way_in.z > cabin.z, "%s: the board's wreck is by the south-east way in" % map_id)
		assert_lte(_off_the_way(board, way_in, cabin), float(config_node.TILE_SIZE) * 2.0,
			"%s: on the way from it to the cabin" % map_id)
		_cleanup_nodes.erase(main)
		main.get_parent().remove_child(main)
		main.free()

# ==============================================================================
# 2. The search
# ==============================================================================

func test_03_a_search_takes_its_strokes_and_brings_out_its_one_part() -> void:
	var node = ResourceNode.new("antenna", Vector2i.ZERO)
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	await wait_frames(1)
	var strokes: int = int(config_node.RESOURCE_NODES["antenna"]["strokes"])
	assert_gt(strokes, 1, "More than one stroke: a search, not a pick-up")
	var info: Dictionary = node.get_display_info()
	assert_eq(String(info.get("kind_text", "")), String(config_node.RESOURCE_NODES["antenna"]["kind"]), "It is a wreck of the ship")
	assert_true(String(info["status"]).contains(tr("RESOURCE_ANTENNA")), "Its card says what is in it")
	var seconds: int = int(round(float(strokes) / float(config_node.RESOURCE_NODES["antenna"]["harvest_rate"])))
	assert_true(String(info["status"]).contains(str(seconds)), "and how long the search is")
	for i in strokes - 1:
		assert_eq(node.harvest(1), 0, "Nothing out at stroke %d" % (i + 1))
		assert_eq(int(node.get_display_info()["current_amount"]), strokes - (i + 1), "Its card counts the search down")
	assert_false(node.is_depleted, "Not done before its last stroke")
	assert_eq(node.harvest(1), 1, "The last brings out its part")
	assert_true(node.is_depleted, "and it is searched")
	assert_eq(node.harvest(strokes), 0, "and there is no second")
	assert_eq(String(node.get_display_info()["status"]), tr("STATUS_SEARCHED"), "Its card says so")

func test_04_he_searches_it_and_the_part_goes_into_the_stock() -> void:
	var main = await _level_on()
	var w: Node3D = _wreck("antenna") as Node3D
	var hero = main.hero
	hero.global_position = w.global_position + Vector3(w.block_radius() + 0.4, 0.0, 0.0)
	hero.order_harvest(w)
	assert_eq(int(hero.current_state), int(hero.State.HARVESTING), "At it, he searches it")
	var strokes: int = w.strokes_each()
	var interval: float = 1.0 / float(w.harvest_rate)
	for i in strokes - 1:
		hero._physics_process(interval)
	assert_eq(int(game_state_node.resources["antenna"]), 0, "Nothing yet, a stroke short")
	hero._physics_process(interval + 0.01)
	hero._physics_process(0.016)
	assert_eq(int(game_state_node.resources["antenna"]), 1, "Searched, the antenna is in the stock")
	assert_true(w.is_depleted, "and the wreck has nothing more")

# ==============================================================================
# 3. The smoke
# ==============================================================================

func test_05_its_smoke_rises_over_the_mist_where_the_wreck_is_not_drawn() -> void:
	var main = await _level_on()
	await wait_frames(3)
	var shroud_priority: int = (main.fog.shroud.mesh as QuadMesh).material.render_priority
	var map: Dictionary = game_state_node.map_data()
	assert_true(bool(config_node.WRECKS["in_turn"]), "(the wrecks are found one from another)")
	for part in PARTS:
		var w: Node3D = _wreck(part) as Node3D
		var smoke: WreckSmoke = _smoke_of(w)
		if int(config_node.part_stage(map, part)) > 1:
			assert_null(smoke, "The %s's wreck, not located yet, does not smoke" % part)
			assert_false(w.is_visible_in_tree(), "and is not drawn in the mist")
			continue
		assert_not_null(smoke, "The %s's wreck -- the first stage's -- smokes from the start" % part)
		if smoke == null:
			continue
		assert_lt(_flat(smoke.global_position, w.global_position), 0.1, "over it")
		assert_true(smoke.is_smoking(), "while it is not searched")
		assert_false(main.fog.is_seen(w.global_position), "(it lies on ground not seen yet)")
		assert_false(w.is_visible_in_tree(), "The wreck itself is not drawn in the mist")
		assert_true(smoke.is_visible_in_tree(), "its smoke is")
		var puff: Material = (smoke.draw_pass_1 as QuadMesh).material
		assert_gt(puff.render_priority, shroud_priority, "drawn over the mist")
	var searched: Node3D = _wreck("antenna") as Node3D
	searched.harvest(searched.strokes_each())
	var gone: WreckSmoke = _smoke_of(searched)
	gone._process(0.016)
	assert_false(gone.is_smoking(), "Searched, it stops")
	gone._process(gone.lifetime + 0.1)
	assert_true(gone.is_queued_for_deletion(), "and what was in the air has thinned away a lifetime on")

func test_09_each_wreck_is_located_by_the_stage_before_it() -> void:
	# The player, 2026-10-02: "第一个信标有烟，第二个信标需要第一个信标给位置，第三个需要第二个".
	var main = await _level_on()
	await wait_frames(3)
	var map: Dictionary = game_state_node.map_data()
	var order: Array[String] = []
	for stage in range(1, int(game_state_node.beacon_stage_count()) + 1):
		var part: String = String(config_node.stage_part(map, stage))
		assert_ne(part, "", "Stage %d takes a part" % stage)
		assert_eq(int(config_node.part_stage(map, part)), stage, "and that part is stage %d's" % stage)
		order.append(part)
	assert_true(game_state_node.wreck_located(order[0]), "The first stage's wreck is located from the start")
	for i in range(1, order.size()):
		assert_false(game_state_node.wreck_located(order[i]), "The %s's is not" % order[i])
	var heard: Array = []
	var eb = tree.root.get_node("EventBus")
	var listen := func(part: String) -> void: heard.append(part)
	eb.wreck_located.connect(listen)
	for i in range(1, order.size()):
		var w: Node3D = _wreck(order[i]) as Node3D
		assert_false(main.fog.is_seen(w.global_position), "(the %s's wreck lies in the mist)" % order[i])
		heard.clear()
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
		assert_eq(heard, [order[i]], "Stage %d mended locates the %s's wreck, and only it" % [i, order[i]])
		assert_true(game_state_node.wreck_located(order[i]), "located for good")
		var smoke: WreckSmoke = _smoke_of(w)
		assert_not_null(smoke, "Its smoke goes up")
		if smoke != null:
			assert_almost_eq(float(smoke.preprocess), 0.0, 0.001, "seen going up, not already risen")
		assert_true(main.fog.is_seen(w.global_position), "and the mist over it becomes seen ground: its place shows")
		var where: String = tr("DIR_" + String(main.wave_manager.side_of(w.global_position)))
		assert_eq(String(main.hud.hint_label.text), tr("HINT_WRECK_LOCATED") % [tr("RESOURCE_%s" % order[i].to_upper()), where],
			"The screen says what is there and which way, last")
	heard.clear()
	game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
	assert_true(heard.is_empty(), "The last stage locates nothing")
	assert_eq(String(main.hud.hint_label.text), tr("HINT_BEACON_STIRS"), "and only its hum is said")
	eb.wreck_located.disconnect(listen)
	# A new run starts the chain over.
	game_state_node.reset_game()
	assert_false(game_state_node.wreck_located(order[1]), "A new run: the second is not located again")

func test_10_found_by_walking_onto_it_it_is_not_located_again() -> void:
	var main = await _level_on()
	await wait_frames(3)
	var map: Dictionary = game_state_node.map_data()
	var second: String = String(config_node.stage_part(map, 2))
	var w = _wreck(second)
	w.harvest(w.strokes_each())
	game_state_node.add_resources({second: 1})
	main.hud.show_hint("(before)")
	game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
	assert_null(_smoke_of(w), "A wreck searched before it was located raises no smoke")
	assert_ne(String(main.hud.hint_label.text), tr("HINT_WRECK_LOCATED") % [tr("RESOURCE_%s" % second.to_upper()),
		tr("DIR_" + String(main.wave_manager.side_of((w as Node3D).global_position)))], "and is not said as found")

func test_11_each_wreck_is_called_and_shown_by_what_it_holds() -> void:
	# The player, 2026-10-02: "拿了哪个也不知道".
	var names: Dictionary = {}
	for part in PARTS:
		var row: Dictionary = config_node.RESOURCE_NODES[part]
		assert_eq(String(row["icon"]), part, "The %s's wreck shows the %s's icon" % [part, part])
		names[tr(String(row["name"]))] = true
	assert_eq(names.size(), PARTS.size(), "Each is called by its own name")

# ==============================================================================
# 4. What is said
# ==============================================================================

func test_06_the_beacon_says_what_a_stage_lacks_and_where_it_is() -> void:
	var main = await _level_on()
	var hint: String = String(config_node.source_hint("antenna", {}))
	assert_eq(hint, tr("SOURCE_ANTENNA") % tr("RESOURCE_ANTENNA"), "Where the antenna is, said where its price is")
	assert_true(String(config_node.beacon_status(game_state_node.map_data(), 0, 0.0)).contains(tr("RESOURCE_ANTENNA")),
		"The beacon's line names the part the next stage takes")
	var bench = main.current_core.station(String(config_node.BEACON_STATION))
	var first: String = String(game_state_node.beacon_next_job())
	for res_id in config_node.beacon_job(game_state_node.map_data(), first)["inputs"]:
		if not config_node.is_part(String(res_id)):
			game_state_node.resources[res_id] = int(config_node.beacon_job(game_state_node.map_data(), first)["inputs"][res_id])
	assert_false(bench.can_afford(first), "The materials alone do not repair it")
	game_state_node.add_resources({"antenna": 1})
	assert_true(bench.can_afford(first), "With the antenna they do")

func test_07_the_bar_shows_a_part_only_while_he_has_it_and_its_find_is_said() -> void:
	var main = await _level_on()
	var hud = main.hud
	var chip: Control = hud.resource_chips["antenna"]
	assert_false(chip.visible, "No antenna on the bar before it is found")
	game_state_node.add_resources({"antenna": 1})
	assert_true(chip.visible, "Found, it is")
	assert_false((hud.resource_labels["antenna"] as Control).visible, "its icon alone: a part is one or none")
	tree.root.get_node("EventBus").resource_picked_up.emit("antenna", 1, main.hero)
	assert_eq(String(hud.hint_label.text), tr("HINT_FOUND_PART") % [tr("RESOURCE_ANTENNA"), 1],
		"and said as found, for the beacon's first stage")
	game_state_node.spend_resources({"antenna": 1})
	assert_false(chip.visible, "Gone into the beacon, it is off the bar")

# ==============================================================================
# 5. What a repaired stage stirs up
# ==============================================================================

func test_08_what_a_stage_stirs_up_comes_in_by_the_ways_in_each_in_turn() -> void:
	var main = await _level_on()
	var wm = main.wave_manager
	var entries: Array = wm.entry_positions
	assert_gt(entries.size(), 1, "The valley has its ways in")
	var seen: Array = []
	for size in [2, 3]:
		wm._stirred = size
		wm.start_stage_wave()
		if wm.spawn_timer:
			wm.spawn_timer.stop()
		for i in size:
			var d = wm.spawn_dino()
			assert_not_null(d, "One steps out")
			if d == null:
				continue
			_cleanup_nodes.append(d)
			d.set_physics_process(false)
			var at: Vector3 = (d as Node3D).global_position
			assert_gt(_flat(at, wm.nest_spawn_position), float(config_node.TILE_SIZE) * 2.0, "not out of the nest")
			var which: int = -1
			for k in entries.size():
				if _flat(at, entries[k]) <= float(config_node.TILE_SIZE):
					which = k
			assert_gte(which, 0, "in by a way in")
			seen.append(which)
		wm.is_wave_active = false
		wm.stage_wave = false
	var expected: Array = []
	for k in seen.size():
		expected.append(k % entries.size())
	assert_eq(seen, expected, "each way in in turn, from one stage's raid to the next")
