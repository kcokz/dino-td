# res://tests/test_v06_the_night.gd
# GAME-DESIGN 9.3: "夜里：……危险换成了河边：植龙沿岸巡，基地离河近就会被摸上来"; "火光照到的黑暗边上能看见眼睛反光";
# v0.6 round four, the player: "火把我觉得在夜里是很有用，但需要不只是照明的作用，比如不用火把，晚上更多的夜行动物
# 袭击（怕火把但是不怕暗淡灯光的船舱）".
#
# At night phytosaurs come up out of the river, at the field's river side, for the Hero and the cabin:
# a few while a fire burns by the cabin, more while it is dark. They will not come into a fire's light
# or the torch's: they wait at its edge, eyes shining, and back out as the torch comes at them. At
# first light they go back to the river. A raid counts only its own.
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

func _prowl() -> Dictionary:
	return config_node.PROWL

func _species() -> String:
	return String(game_state_node.map_data()["prowlers"].keys()[0])

func _at(part: String) -> float:
	return float(config_node.DAY["parts"][part])

func _set_clock(t: float, day: int = 1) -> void:
	game_state_node.day_clock = float(day - 1) * float(config_node.DAY["length"]) + t
	game_state_node._run_the_day(0.0)

func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## A lit campfire `off` from the cabin's door.
func _campfire(main: Node, off: Vector3) -> Node:
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var fire = main.build_system.place_at("campfire", main.grid_manager.world_to_build_cell(door + off), main.buildings_container)
	fire._tend(99.0)
	return fire

## A phytosaur put down at `at`, driven by hand.
func _phytosaur(main: Node, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(_species()))).new()
	d.setup(_species())
	d.home = at
	d.waypoints = [at, main.current_core.global_position] as Array[Vector3]
	d.position = at
	main.dinos_container.add_child(d)
	d.setup(_species())
	d.set_physics_process(false)
	return d

## `d` thinking and walking for `seconds`, a physics frame at a time.
func _drive(d: Node, seconds: float) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < seconds and is_instance_valid(d):
		d.advance_towards_waypoint(dt)
		t += dt
		await tree.physics_frame

func test_01_the_phytosaur_hunts_by_night_up_from_the_river() -> void:
	var s: String = _species()
	assert_eq(s, "phytosaur", "The valley's night hunter is the phytosaur")
	assert_true(config_node.keeps_hours(s, "night") and not config_node.keeps_hours(s, "day"), "out at night, not by day")
	var made: Node = load(String(config_node.get_dino_script_path(s))).new()
	assert_true(made is ProwlerDino, "a prowler (ProwlerDino)")
	made.free()
	assert_true(config_node.VISUALS.has("dino/" + s), "with a model of its own")
	for kind in ["call", "alert", "bite", "hurt", "death"]:
		assert_true(config_node.SOUNDS["sounds"].has("%s_%s" % [s, kind]), "and a %s of its own" % kind)

func test_02_its_ways_up_are_on_the_river_side_and_reach_the_cabin() -> void:
	var main = await _level()
	await nav_settled(main)
	var origins: Array = main.night_prowl.origins
	assert_gt(origins.size(), 0, "It has places to come up")
	var cabin: Vector3 = main.current_core.global_position
	for at in origins:
		assert_lt(float((at as Vector3).x), cabin.x - 15.0, "%s is on the river side, west" % at)
		var route: PackedVector3Array = main.nav_maps.path(at, main.current_core.door_outside(), 0)
		assert_gt(route.size(), 1, "and there is a way from %s to the cabin" % at)
		if route.size() > 1:
			assert_lt(_flat_gap(route[route.size() - 1], main.current_core.door_outside()), 1.5, "all the way")

func test_03_at_night_one_comes_up_and_makes_for_the_cabin() -> void:
	var main = await _level()
	var prowl: NightProwl = main.night_prowl
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	_set_clock(_at("day") + 100.0)
	prowl._process(float(_prowl()["first_after"]) + 1.0)
	assert_eq(prowl.out_now(), 0, "By day none comes")
	_set_clock(_at("night") + 1.0)
	prowl._process(0.0)
	prowl._process(float(_prowl()["first_after"]) + 0.1)
	# In pairs since v0.6 round five ("成对出现"): the first up, and the second beside it.
	assert_eq(prowl.out_now(), mini(int(_prowl()["pair"]), prowl.most_now()), "A while into the night a pair comes up")
	var d: Node = tree.get_nodes_in_group(ProwlerDino.GROUP)[0]
	var near_one: bool = false
	for at in prowl.origins:
		near_one = near_one or _flat_gap(d.global_position, at) < 1.5
	assert_true(near_one, "out of the river, where it comes up")
	assert_eq(String(d.dino_type), _species(), "a %s" % _species())
	assert_true(_flat_gap(d.waypoints[d.waypoints.size() - 1], main.current_core.global_position) < 0.5, "making for the cabin")

func test_04_dark_more_come_lit_a_few() -> void:
	var main = await _level()
	var prowl: NightProwl = main.night_prowl
	_set_clock(_at("night") + 10.0)
	assert_false(prowl.camp_lit(), "No fire, the camp is dark")
	assert_eq(prowl.most_now(), int(_prowl()["most_dark"]), "and as many as %d may be out" % int(_prowl()["most_dark"]))
	_campfire(main, Vector3(-2.0, 0.0, 3.0))
	assert_true(prowl.camp_lit(), "A fire burning by the cabin lights it")
	assert_eq(prowl.most_now(), int(_prowl()["most_lit"]), "and only %d may be out" % int(_prowl()["most_lit"]))
	assert_lt(int(_prowl()["most_lit"]), int(_prowl()["most_dark"]), "(\"不点火，夜里摸上来的就多\")")

func test_05_it_will_not_come_into_a_fires_light() -> void:
	var main = await _level()
	await nav_settled(main)
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(25.0, 0.0, 12.0)
	var fire = _campfire(main, Vector3(-3.0, 0.0, 4.0))
	var light: float = float(fire.light_radius())
	# Put down on the far side of the fire from the cabin, the fire between it and where it is going.
	var out: Vector3 = (fire.global_position - main.current_core.global_position)
	out.y = 0.0
	var d = _phytosaur(main, fire.global_position + out.normalized() * (light + 3.0))
	var nearest: float = INF
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	for i in int(12.0 / dt):
		d.advance_towards_waypoint(dt)
		nearest = minf(nearest, _flat_gap(d.global_position, fire.global_position))
		if i % 4 == 0:
			await tree.physics_frame
	assert_gt(nearest, light - float(_prowl()["flee_inside"]) - 0.3, "It never came further into the light than it stands")
	# The cabin has sides the fire does not light: it goes round the light to one (v0.7, the player: "有篝火处植龙就不会
	# 靠近了"). Where everything it wants is lit it waits at the edge (test_06, the torch; ProwlerDino._act).
	assert_eq(d.current_target, main.current_core, "It goes for the cabin")
	assert_true(ProwlerDino.light_over(tree, d._engage_spot()).is_empty(), "at a side of it the fire does not light")

func test_06_the_torch_drives_it_back() -> void:
	var main = await _level()
	await nav_settled(main)
	_set_clock(_at("night") + 10.0)
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = main.current_core.global_position + Vector3(-8.0, 0.0, 8.0)
	var d = _phytosaur(main, hero.global_position + Vector3(-2.5, 0.0, 0.0))
	d._think()
	assert_eq(d.current_target, hero, "In the dark it goes for him")
	stock_everything()
	hero.light_torch()
	var torch: float = float(hero.torch_light())
	await _drive(d, 4.0)
	assert_gt(_flat_gap(d.global_position, hero.global_position), torch - float(_prowl()["flee_inside"]) - 0.2,
		"His torch lit, it backs out of its light")
	assert_true(d.is_wary(), "and waits at its edge")

func test_07_its_eyes_shine_at_the_edge_of_the_light() -> void:
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(25.0, 0.0, 12.0)
	var fire = _campfire(main, Vector3(-3.0, 0.0, 4.0))
	var light: float = float(fire.light_radius())
	var d = _phytosaur(main, fire.global_position + Vector3(-(light - 0.5), 0.0, 0.0))
	d._face_now(fire.global_position)
	assert_gt(d._eyes.size(), 0, "It has eyes of their own to shine (the model's \"Eye\")")
	var worn: bool = false
	for m in d.find_child("Body", false, false).find_children("*", "MeshInstance3D", true, false):
		for i in (m as MeshInstance3D).get_surface_override_material_count():
			worn = worn or d._eyes.has((m as MeshInstance3D).get_surface_override_material(i))
	assert_true(worn, "on the body it has now -- set up twice, as it is sent, it is a new body")
	d._shine()
	assert_almost_eq(float(d.eye_shine), 1.0, 0.01, "At the light's edge they shine")
	assert_gt(float(d._eyes[0].emission_energy_multiplier), 0.0, "(lit)")
	d.global_position = fire.global_position + Vector3(-(light + float(_prowl()["eye_reach"]) + 2.0), 0.0, 0.0)
	d._shine()
	assert_almost_eq(float(d.eye_shine), 0.0, 0.001, "Far from any light they are dark")

func test_08_at_first_light_it_goes_back_to_the_river() -> void:
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	var home: Vector3 = main.night_prowl.origins[0]
	var d = _phytosaur(main, home)
	d.global_position = main.current_core.global_position + Vector3(-6.0, 0.0, 6.0)
	_set_clock(_at("day") + 2.0, 2)
	assert_true(bool(d.going_home), "At first light it goes home")
	assert_lt(_flat_gap(d.waypoints[d.waypoints.size() - 1], home), 0.5, "to the river it came up from, not the nest")

func test_09_a_raid_counts_only_its_own() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.start_wave(1, 3)
	var alive: int = int(wm.dinos_alive_count)
	var d = _phytosaur(main, main.current_core.global_position + Vector3(-10.0, 0.0, 6.0))
	d.take_damage(9999.0)
	assert_eq(int(wm.dinos_alive_count), alive, "A phytosaur killed in the middle of a raid is not one of the raid")
	for g in tree.get_nodes_in_group("guard_dinos"):
		g.take_damage(9999.0)
		break
	assert_eq(int(wm.dinos_alive_count), alive, "nor is a nest's guard")

func test_10_none_comes_up_where_he_can_see_it() -> void:
	var main = await _level()
	var prowl: NightProwl = main.night_prowl
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = prowl.origins[0] + Vector3(1.5, 0.0, 0.0)
	await wait_seconds(float(config_node.FOG["every"]) * 3.0 + 0.1)
	assert_true(main.fog.sees(prowl.origins[0]), "(he is watching one of the ways up)")
	_set_clock(_at("night") + 10.0)
	for i in prowl.origins.size():
		var d = prowl.send_one()
		if d != null:
			assert_gt(_flat_gap(d.global_position, prowl.origins[0]), 1.5, "Nothing comes up where he stands")

func test_11_cornered_by_the_torch_it_finds_a_way_round_or_turns_at_bay() -> void:
	# The debug-agent's BUG-018: walked at with the torch into the field's corner, it stood in the
	# torchlight at his feet, still, for seven seconds. Now it backs out round the light's edge where it
	# can, and with nowhere to go turns at bay on him -- it is never stood still in the light for long.
	var main = await _level()
	await nav_settled(main)
	_set_clock(_at("night") + 10.0)
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	var half: float = float(config_node.terrain()["field_half"])
	var corner: Vector3 = Vector3(-half + 1.5, 0.0, -half + 1.5)
	var d = _phytosaur(main, corner)
	hero.global_position = corner + Vector3(7.5, 0.0, 7.5)
	stock_everything()
	hero.light_torch()
	var torch: float = float(hero.torch_light())
	var deep: float = torch - float(_prowl()["flee_inside"])
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var still_in_light: float = 0.0
	var longest: float = 0.0
	var turned: bool = false
	for i in int(12.0 / dt):
		var to: Vector3 = d.global_position - hero.global_position
		to.y = 0.0
		if to.length() > 1.2:
			hero.global_position += to.normalized() * 3.0 * dt
		var was: Vector3 = d.global_position
		d.advance_towards_waypoint(dt)
		d.at_bay_left = maxf(0.0, d.at_bay_left - dt)
		turned = turned or d.at_bay_left > 0.0
		var in_deep: bool = _flat_gap(d.global_position, hero.global_position) < deep
		if in_deep and d.at_bay_left <= 0.0 and _flat_gap(d.global_position, was) < 0.002:
			still_in_light += dt
			longest = maxf(longest, still_in_light)
		else:
			still_in_light = 0.0
		if i % 4 == 0:
			await tree.physics_frame
	assert_lt(longest, float(_prowl()["cornered_seconds"]) + 0.5,
		"Never stood still deep in the torchlight longer than it takes to find itself cornered (%.2fs)" % longest)
	assert_true(turned or _flat_gap(d.global_position, hero.global_position) >= deep - 0.3,
		"It got out of the light, or turned at bay on him")

func test_12_its_eyes_glint_from_the_games_camera() -> void:
	# The debug-agent's TASK-021: the eyes were a few centimetres, two white pixels, lost at twelve metres.
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(25.0, 0.0, 12.0)
	var fire = _campfire(main, Vector3(-3.0, 0.0, 4.0))
	var light: float = float(fire.light_radius())
	var d = _phytosaur(main, fire.global_position + Vector3(-(light - 0.5), 0.0, 0.0))
	d._face_now(fire.global_position)
	await wait_physics_frames(2)
	assert_eq(d.glints.size(), 2, "A glint over each eye")
	d._shine()
	var across: float = (d.glints[0].mesh as QuadMesh).size.x * d.glints[0].global_transform.basis.get_scale().x
	var far: float = main.camera.global_position.distance_to(d.glints[0].global_position)
	var want: float = clampf(far * float(_prowl()["glint_per_metre"]), float(_prowl()["glint_least"]), float(_prowl()["glint_size"]))
	assert_almost_eq(across, want, 0.02, "as big across as the camera is far, whatever the body's fit (%.2f m at %.0f m)" % [across, far])
	assert_true(d.glints[0].visible and d.glints[1].visible, "At the light's edge they show")
	var eye_mid: Vector3 = (d.glints[0].global_position + d.glints[1].global_position) * 0.5
	assert_gt(eye_mid.y, float(config_node.DINOS[_species()]["size"].y) * 0.4, "up on its head")
	d.global_position = fire.global_position + Vector3(-(light + float(_prowl()["eye_reach"]) + 2.0), 0.0, 0.0)
	d._shine()
	assert_false(d.glints[0].visible, "Far from any light, none")

func test_13_it_paces_only_where_it_can_stand() -> void:
	# The debug-agent's TASK-022: by the cabin's end a phytosaur walked back and forth along the edge,
	# eight metres in six seconds, at a pacing place inside the cabin it could not reach.
	var main = await _level()
	await nav_settled(main)
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(25.0, 0.0, 12.0)
	var fire = _campfire(main, Vector3(0.0, 0.0, 1.5))
	var d = _phytosaur(main, fire.global_position + Vector3(0.0, 0.0, 6.0))
	d._keep_to({"at": fire.global_position, "radius": float(fire.light_radius())}, false)
	var to_cabin: Vector3 = main.current_core.global_position - fire.global_position
	var into_cabin: float = atan2(to_cabin.z, to_cabin.x)
	# The edge's point towards the cabin is inside it only if the light reaches past its walls.
	var edge: float = float(fire.light_radius()) + float(_prowl()["edge_out"])
	var spot: Vector3 = fire.global_position + Vector3(cos(into_cabin), 0.0, sin(into_cabin)) * edge
	var half: Vector2 = config_node.get_building_half("core")
	var local: Vector3 = spot - main.current_core.global_position
	if absf(local.x) < half.x and absf(local.z) < half.y:
		assert_false(d._can_stand_on_the_edge(into_cabin), "Not in the cabin")
	assert_true(d._can_stand_on_the_edge(into_cabin + PI), "and on the open ground the other side")
	d._edge_angle = into_cabin + PI * 0.5
	for i in 24:
		d._edge_angle = d._next_edge_angle()
		var at: Vector3 = fire.global_position + Vector3(cos(d._edge_angle), 0.0, sin(d._edge_angle)) * edge
		assert_true(d._can_stand_on_the_edge(d._edge_angle), "Every place it paces to is ground it can stand on (%s)" % at)

func test_14_its_eyes_are_two_points_up_close_and_one_seen_from_afar() -> void:
	# The debug-agent's TASK-022: at six metres the glint was a lamp as big as its head.
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(25.0, 0.0, 12.0)
	var fire = _campfire(main, Vector3(-3.0, 0.0, 4.0))
	var d = _phytosaur(main, fire.global_position + Vector3(-(float(fire.light_radius()) - 0.5), 0.0, 0.0))
	await wait_physics_frames(2)
	var cam: Camera3D = main.camera
	var head: Vector3 = d.glints[0].global_position
	var apart: float = d.glints[0].global_position.distance_to(d.glints[1].global_position)
	for far in [6.0, 25.0]:
		cam.global_position = head + Vector3(0.0, 0.7, 0.7).normalized() * far
		d._shine()
		var across: float = (d.glints[0].mesh as QuadMesh).size.x * d.glints[0].global_transform.basis.get_scale().x
		if far < 10.0:
			assert_lt(across, apart, "Up close each glint is smaller than the eyes are apart: two points (%.3f < %.3f)" % [across, apart])
		else:
			assert_gt(across, 0.1, "From the game's distance, one glint big enough to see (%.2f m)" % across)
			# And no lamp (the player's report, 2026-09-29: "两个眼睛太亮了，有点像两个灯泡").
			assert_lt(across, 0.2, "but a point, not a lamp (%.2f m)" % across)

func test_14b_in_the_light_at_his_feet_its_eyes_are_eyes_not_lamps() -> void:
	# The player, v0.6 round six: "植龙晚上进攻眼睛还是像灯泡" -- up at him in his torchlight its eyes burned full.
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = main.current_core.global_position + Vector3(-8.0, 0.0, 8.0)
	stock_everything()
	hero.light_torch()
	var torch: float = float(hero.torch_light())
	var d = _phytosaur(main, hero.global_position + Vector3(-1.2, 0.0, 0.0))
	d._face_now(hero.global_position)
	await wait_physics_frames(2)
	d._shine()
	assert_almost_eq(float(d.eye_shine), 0.0, 0.001, "At his feet in the torchlight its eyes do not shine: it is lit, and seen")
	assert_false(d.glints[0].visible, "(no glints)")
	d.global_position = hero.global_position + Vector3(-(torch + float(_prowl()["edge_out"])), 0.0, 0.0)
	d._face_now(hero.global_position)
	d._shine()
	assert_almost_eq(float(d.eye_shine), 1.0, 0.01, "Where it waits, in the dark just outside the light's edge, they do")

func test_14c_its_eyes_shine_back_only_the_way_it_looks() -> void:
	var main = await _level()
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(25.0, 0.0, 12.0)
	var fire = _campfire(main, Vector3(-3.0, 0.0, 4.0))
	var d = _phytosaur(main, fire.global_position + Vector3(-float(fire.light_radius()), 0.0, 0.0))
	d._face_now(fire.global_position)
	d._shine()
	var looking: float = float(d.eye_shine)
	d._face_now(d.global_position + Vector3(0.0, 0.0, 5.0))
	d._shine()
	var side_on: float = float(d.eye_shine)
	d._face_now(d.global_position + Vector3(-5.0, 0.0, 0.0))
	d._shine()
	var away: float = float(d.eye_shine)
	assert_almost_eq(looking, 1.0, 0.01, "Looking at the light, they shine")
	assert_almost_eq(side_on, float(_prowl()["eye_side"]), 0.05, "side on, less")
	assert_almost_eq(away, 0.0, 0.001, "looking away, not at all")

func test_15_in_the_dark_it_smells_the_man_from_far_off_and_a_torch_keeps_it_off() -> void:
	# The player's choice, v0.6 round five: "植龙专找黑里的人" -- "没火的人是植龙的首要目标：闻到就来……举着火把就
	# 不敢近身". It was 8 metres, and a man out in the dark was left be.
	var main = await _level()
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	_set_clock(_at("night") + 10.0)
	var reach: float = float(_prowl()["hunts_within"])
	assert_gte(reach, 20.0, "(it smells him from across a good part of the field)")
	var d = _phytosaur(main, main.hero.global_position + Vector3(reach * 0.8, 0.0, 0.0))
	assert_eq(d._preferred_target(), main.hero, "The man in the dark, far off, is what it is out for")
	stock_everything()
	assert_true(main.hero.light_torch(), "(a torch alight in his hand)")
	assert_ne(d._preferred_target(), main.hero, "Lit, he is not")

func test_15b_set_on_the_cabin_it_turns_to_the_man_in_the_dark() -> void:
	# The player's bug report, 2026-10-01: "篝火范围不知道是不是有点大，我在旁边采石头，植龙就看着，也不来进攻" --
	# two stood at the campfire's edge staring in at the cabin while he quarried four metres off in the dark: the
	# cabin was what they had set out for, and the man, its equal, was never taken over it.
	var main = await _level()
	await nav_settled(main)
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	var fire = _campfire(main, Vector3(-3.0, 0.0, 4.0))
	var light: float = float(fire.light_radius())
	var out: Vector3 = (fire.global_position - main.current_core.global_position)
	out.y = 0.0
	out = out.normalized()
	var d = _phytosaur(main, fire.global_position + out * (light + float(_prowl()["edge_out"])))
	d._take(main.current_core, d.Mode.ENGAGE)
	assert_eq(d.current_target, main.current_core, "(set on the cabin, at the light's edge)")
	# Him out in the dark beside it, at work.
	var side := Vector3(-out.z, 0.0, out.x)
	main.hero.global_position = d.global_position + out * 1.5 + side * 2.5
	assert_true(ProwlerDino.light_over(tree, main.hero.global_position).is_empty(), "(he is in the dark)")
	d._think()
	assert_eq(d.current_target, main.hero, "The man in the dark beside it is what it goes for, not the cabin in the light")
	# Lit, he is not.
	main.hero.global_position = fire.global_position
	assert_false(d._outranks(main.hero, main.current_core), "In the firelight he does not outrank the cabin")

func test_15c_struck_from_the_light_it_strikes_back_then_backs_out() -> void:
	# The player's bug report, 2026-10-01: "这时候我进攻恐龙它们都不会还手？似乎有点不合理" -- standing in the light he
	# could cut at one at its edge as long as he liked.
	var main = await _level()
	await nav_settled(main)
	_set_clock(_at("night") + 10.0)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	var fire = _campfire(main, Vector3(-3.0, 0.0, 4.0))
	var light: float = float(fire.light_radius())
	var out: Vector3 = (fire.global_position - main.current_core.global_position)
	out.y = 0.0
	out = out.normalized()
	var d = _phytosaur(main, fire.global_position + out * (light + float(_prowl()["edge_out"])))
	d._take(main.current_core, d.Mode.ENGAGE)
	main.hero.global_position = d.global_position - out * 1.5
	assert_false(ProwlerDino.light_over(tree, main.hero.global_position).is_empty(), "(he stands in the light)")
	# Hurt by a trap, it does not know who: it keeps to the edge.
	d.take_damage(0.1)
	assert_almost_eq(float(d.at_bay_left), 0.0, 0.001, "A blow from nobody it knows is not his")
	# His blow.
	main.hero.target_enemy = d
	d.take_damage(0.1)
	assert_gt(float(d.at_bay_left), 0.0, "Struck by him, it turns on him")
	assert_eq(d.current_target, main.hero, "him, light or no")
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	for i in int(1.0 / dt):
		d._physics_process(dt)
	assert_lt(float(d.at_bay_left), float(_prowl()["at_bay_seconds"]), "for a while (PROWL.at_bay_seconds), running down")
	main.hero.target_enemy = null

func test_16_they_come_up_in_pairs_tougher_than_they_were() -> void:
	var main = await _level()
	var prowl: NightProwl = main.night_prowl
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position
	_set_clock(_at("night") + 30.0)
	prowl._was_out = true
	prowl._clock = 0.0
	var before: int = prowl.out_now()
	prowl._process(0.01)
	assert_eq(prowl.out_now() - before, int(_prowl()["pair"]), "They come up %d at a time" % int(_prowl()["pair"]))
	var row: Dictionary = config_node.DINOS[_species()]
	var pack: Dictionary = config_node.DINOS["coelophysis"]
	assert_gte(float(row["hp"]), float(pack["hp"]) * 4.0, "Four of a Coelophysis's hit points (\"更抗打\")")
	assert_gte(float(row["damage"]), float(pack["damage"]) * 2.0, "and twice its bite (\"咬得更疼\")")
