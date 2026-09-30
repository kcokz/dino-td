# res://tests/test_v06_the_fog.gd
# v0.6 round three (GAME-DESIGN 9.3): "游戏要加上战争迷雾，人不能一开始就知道恐龙巢穴"; "先在现在这张图上
# 做迷雾和找巢".
#
# The field in three states -- never seen (dark), seen but out of sight (the land dimmed, no
# animals), in sight (everything); what sees is the Hero, the cabin and what he has built, less
# far at night. The nest is not known until it is seen: found, its raids are seen setting out and
# warned of sooner. Until then the warning says only which side the calls come from.
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
	await _settle()
	return main

func _fog() -> Dictionary:
	return config_node.FOG

## Long enough for the fog to look twice and its shade to ease all the way.
func _settle() -> void:
	var seconds: float = float(_fog()["every"]) * 2.0 + float(_fog()["ease"]) * 3.0
	await wait_physics_frames(int(ceil(seconds * float(Engine.physics_ticks_per_second))) + 2)

func _raptor(main: Node, at: Vector3) -> Node:
	var species: String = String(game_state_node.map_data()["raiders"].keys()[0])
	var d = load(String(config_node.get_dino_script_path(species))).new()
	main.dinos_container.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.global_position = at
	return d

func test_01_at_the_start_the_cabins_ground_is_in_sight_and_the_nest_is_not_known() -> void:
	var main = await _level()
	var fog: FogOfWar = main.fog
	var cabin: Vector3 = main.current_core.global_position
	var nest: Vector3 = main.current_nest.global_position
	assert_true(fog.is_in_sight(cabin), "The cabin's ground is in sight")
	assert_false(fog.is_seen(nest), "The nest has never been seen")
	assert_false(main.current_nest.visible, "and is not drawn")
	assert_false(bool(game_state_node.nest_found), "nor found")
	assert_gt(fog.shade_at(nest), float(_fog()["unseen"]) - 0.05, "The fog over it is dark")
	assert_lt(fog.shade_at(cabin), 0.1, "and clear over the cabin")

func test_02_walking_up_to_the_nest_finds_it_and_it_stays_known() -> void:
	var main = await _level()
	var fog: FogOfWar = main.fog
	var nest: Vector3 = main.current_nest.global_position
	var found = watch_signal(tree.root.get_node("EventBus"), "nest_found")
	main.hero.global_position = nest + Vector3(0.0, 0.0, float(_fog()["sight"]["hero"]) * 0.6)
	await _settle()
	assert_eq(found.emit_count, 1, "In sight, the nest is found -- once")
	assert_true(bool(game_state_node.nest_found), "and the run knows it")
	assert_true(main.current_nest.visible, "It is drawn")
	main.hero.global_position = main.current_core.door_outside()
	await _settle()
	assert_true(fog.is_seen(nest) and not fog.is_in_sight(nest), "Back home, it is out of sight but seen")
	assert_true(main.current_nest.visible, "and still drawn, as the land is")
	assert_almost_eq(fog.shade_at(nest), float(_fog()["seen"]), 0.05, "dimmed")
	for g in tree.get_nodes_in_group("guard_dinos"):
		if is_instance_valid(g) and g is Node3D:
			assert_false((g as Node3D).visible, "Its guards, out of sight, are not")
	assert_eq(found.emit_count, 1, "and it is not found a second time")

func test_03_an_animal_out_of_sight_is_hidden_and_cannot_be_pointed_at() -> void:
	var main = await _level()
	# Both away from the cabin, out of its gun's reach, and he held still: only the fog is asked.
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(-12.0, 0.0, 12.0)
	var far: Vector3 = main.current_core.global_position + Vector3(float(_fog()["sight"]["core"]) + 6.0, 0.0, -8.0)
	var d = _raptor(main, far)
	await _settle()
	assert_false(d.visible, "Out of sight, it is not drawn")
	assert_false(main._is_hoverable(d), "nor can it be pointed at")
	d.global_position = main.hero.global_position + Vector3(2.0, 0.0, 0.0)
	await _settle()
	assert_true(d.visible, "In sight, it is")
	assert_true(main._is_hoverable(d), "and can")

func test_04_at_night_he_sees_less_far() -> void:
	var main = await _level()
	var fog: FogOfWar = main.fog
	var sight: float = float(_fog()["sight"]["hero"])
	# Far from the cabin, so only he sees there.
	main.hero.global_position = main.current_core.global_position + Vector3(-12.0, 0.0, 12.0)
	var probe: Vector3 = main.hero.global_position + Vector3(sight * 0.8, 0.0, 0.0)
	await _settle()
	assert_true(fog.is_in_sight(probe), "By day, %.0f m off is in sight" % (sight * 0.8))
	game_state_node.day_clock = float(config_node.DAY["parts"]["night"]) + 10.0
	await _settle()
	assert_false(fog.is_in_sight(probe), "At night it is not: he sees %.0f%% as far" % (float(_fog()["night"]) * 100.0))

func test_05_what_he_builds_sees_round_itself() -> void:
	var main = await _level()
	var fog: FogOfWar = main.fog
	stock_everything()
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.current_core.global_position + Vector3(14.0, 0.0, 12.0))
	var trap = main.build_system.place_at("set_crossbow", cell, main.buildings_container, true)
	assert_not_null(trap, "A trap put up away from the cabin")
	trap.complete_construction()
	var near: Vector3 = (trap as Node3D).global_position + Vector3(float(_fog()["sight"]["trap"]) * 0.7, 0.0, 0.0)
	await _settle()
	assert_true(fog.is_in_sight(near), "Finished, it sees down its lane")

func test_06_found_the_raids_are_warned_of_sooner() -> void:
	var main = await _level()
	var wm = main.wave_manager
	var before: float = wm._warning_lead()
	game_state_node.nest_found = true
	assert_almost_eq(wm._warning_lead(), before + float(_fog()["found_nest_warning"]), 0.001,
		"The nest found, its raids are seen setting out, and warned of sooner")

func test_07_he_says_which_side_the_calls_come_from_until_the_nest_is_found() -> void:
	# The warning is his to tell (HeroVoice; no banner since v0.6 round six).
	var main = await _level()
	var voice: HeroVoice = main.hero.find_child("Voice", false, false) as HeroVoice
	var side: String = voice.nest_side()
	assert_eq(side, "N", "The first map's nest is north of the cabin")
	var eb = tree.root.get_node("EventBus")
	var said: Array = []
	var ear := func(key: String, _s: float, args: Array = []) -> void: said.append([key, args])
	eb.hero_spoke.connect(ear)
	eb.raid_warning.emit(10.0)
	var from: Array = said.filter(func(line: Array) -> bool: return String(line[0]).begins_with("BARK_RAID_FROM_"))
	assert_eq(from.size(), 1, "He says where the calls come from, as they come (%s)" % [said])
	if from.size() == 1:
		assert_eq(from[0][1], [tr("DIR_" + side)], "-- the north")
	game_state_node.nest_found = true
	said.clear()
	eb.raid_warning.emit(10.0)
	assert_true(said.any(func(line: Array) -> bool: return String(line[0]).begins_with("BARK_RAID_SEEN_")),
		"Found: he sees them set out (%s)" % [said])
	eb.hero_spoke.disconnect(ear)

func test_08_a_view_that_must_show_the_whole_field_can_lift_it() -> void:
	var main = await _level()
	var fog: FogOfWar = main.fog
	fog.reveal_all()
	assert_true(fog.is_in_sight(main.current_nest.global_position), "Lifted, everything is in sight")
	assert_true(main.current_nest.visible, "and drawn")

func test_09_the_first_maps_nest_is_its_own_species_nesting_ground() -> void:
	# "巢穴也不能长一个样，应该不同的恐龙巢穴也不一样": Coelophysis nested in crowds -- a field of scrapes,
	# not the mound with a burrow, which stays for the species it suits (GAME-DESIGN 9.3).
	var main = await _level()
	var species: String = String(game_state_node.map_data()["guards"])
	var key: String = "nest/" + species
	assert_true(config_node.VISUALS.has(key), "The first map's raiders have a nest of their own")
	assert_eq(String(main.current_nest.art_key()), key, "and it is the one drawn")
	assert_true(ResourceLoader.exists(String(config_node.VISUALS[key]["scene"])), "from its own model")
	assert_ne(config_node.get_visual_size(key), config_node.get_visual_size("nest"), "not the mound's size: a spread of scrapes")

func test_10_never_seen_is_unknown_to_the_valleys_far_walls() -> void:
	# v0.6 round four: "迷雾没有遮挡远景只遮挡了近景很奇怪，而且没去过的地方应该完全看不到".
	var main = await _level()
	var fog: FogOfWar = main.fog
	assert_almost_eq(float(_fog()["unseen"]), 1.0, 0.001, "Never seen is wholly unknown")
	var cabin: Vector3 = main.current_core.global_position
	var far_wall: Vector3 = cabin + Vector3(0.0, 0.0, -(fog.half + 20.0))
	assert_almost_eq(fog.shade_at(far_wall), 1.0, 0.001, "Past the field, the valley's far walls are never seen")
	assert_almost_eq(fog.shade_at(cabin + Vector3(fog.half - 1.0, 0.0, 0.0)), 1.0, 0.05, "and the field's far side, till he goes there")
	# Drawn over the whole screen, last: what a decal on the ground left -- the river, the far haze --
	# it covers.
	assert_true(fog.shroud is MeshInstance3D and fog.shroud.mesh is QuadMesh, "One quad over the screen")
	var mat: ShaderMaterial = fog.shroud.mesh.material as ShaderMaterial
	assert_not_null(mat, "with the fog's own shader")
	if mat != null:
		assert_eq(String(mat.shader.resource_path), "res://assets/shaders/fog_of_war.gdshader", "(assets/shaders/fog_of_war.gdshader)")
		assert_eq(mat.render_priority, WreckSmoke.PRIORITY - 1,
			"drawn after everything see-through but the wrecks' smoke, which rises over it (test_v06_wrecks)")
		assert_eq(mat.get_shader_parameter("shroud"), fog._texture, "from what is seen")
	fog.reveal_all()
	assert_false(fog.shroud.visible, "Lifted, it is not drawn at all")

func test_11_it_is_the_valleys_own_mist_at_the_hour() -> void:
	# "全黑是不是有点不真实": mist in the colour of the valley's haze -- pale by day, dark blue at night.
	var main = await _level()
	var fog: FogOfWar = main.fog
	var env: Environment = fog.get_world_3d().environment
	assert_not_null(env, "The valley has its haze")
	if env == null:
		return
	var mist: Dictionary = _fog()["mist"]
	assert_lt(float(mist["never"]), 1.0, "Never seen is thick mist, the lie of the land a shade through it -- not black")
	assert_gt(float(mist["never"]), float(mist["veil"]), "thicker than over ground seen before")
	for haze in [Color(0.76, 0.80, 0.74), Color(0.12, 0.14, 0.22)]:
		env.fog_light_color = haze
		fog._match_the_haze()
		var want: Vector3 = FogOfWar.mist_hue(haze, float(mist["saturation"]))
		var got: Vector3 = fog._material.get_shader_parameter("mist_hue")
		assert_almost_eq(got.z, want.z, 0.001, "The mist takes the haze's colour at the hour (%s)" % haze)
		assert_almost_eq(got.x, want.x, 0.001, "(red too)")
		# As a hue alone, as bright as white: how bright it is is the land's under it.
		assert_almost_eq(0.2126 * got.x + 0.7152 * got.y + 0.0722 * got.z, 1.0, 0.001, "as bright as white (%s)" % haze)
	var night: Vector3 = FogOfWar.mist_hue(Color(0.12, 0.14, 0.22), float(mist["saturation"]))
	assert_gt(night.z, night.x, "The night's mist is blue")

func test_11b_it_is_lit_by_what_lights_the_land_under_it() -> void:
	# The debug-agent's TASK-014: a mist of one colour whatever the light was white paper at noon, and at
	# dusk and at night brighter than the ground in sight round the Hero. Now its brightness is the
	# land's under it (the shader reads the scene), lifted by the hour: paler than the land by day,
	# darker at dusk and at night.
	var main = await _level()
	var fog: FogOfWar = main.fog
	var code: String = String((fog.shroud.mesh.material as ShaderMaterial).shader.code)
	assert_true(code.contains("hint_screen_texture"), "The mist reads the land under it, as lit")
	var day: Dictionary = config_node.DAY
	var noon: float = (float(day["light"][2]["at"]) + float(day["light"][3]["at"])) * 0.5
	game_state_node.day_clock = noon
	var by_day: float = fog.mist_lift()
	game_state_node.day_clock = float(day["parts"]["dusk"]) + 5.0
	var at_dusk: float = fog.mist_lift()
	game_state_node.day_clock = float(day["parts"]["night"]) + 30.0
	var at_night: float = fog.mist_lift()
	assert_gt(by_day, 1.0, "By day the mist is paler than the land under it")
	assert_lt(at_dusk, 1.0, "at dusk darker than it")
	assert_lt(at_night, 1.0, "and at night darker than it")
	# Not much darker: the night's land is so dark that the screen's tone curve crushes darker to black
	# (the debug-agent's BUG-016: at half the land's light the never-seen mist was pure black).
	assert_gt(at_night, 0.5, "but not so much darker that the night's mist is black")
	fog._match_the_haze()
	assert_almost_eq(float((fog.shroud.mesh.material as ShaderMaterial).get_shader_parameter("lift")), at_night, 0.001,
		"What it is drawn with is the hour's")

func test_12_nothing_standing_on_never_seen_ground_is_drawn() -> void:
	# Through the mist a tree or a rock showed as its own lighter shape: what stands on ground never
	# seen is not drawn -- and once seen, it is there for good, as the land is.
	var main = await _level()
	var fog: FogOfWar = main.fog
	var far: Node3D = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if n is Node3D and not fog.is_seen((n as Node3D).global_position):
			far = n
			break
	assert_not_null(far, "Something growing out in the unknown")
	if far == null:
		return
	assert_false(far.visible, "Never seen, it is not drawn")
	main.hero.global_position = far.global_position + Vector3(1.5, 0.0, 1.5)
	await _settle()
	assert_true(far.visible, "Seen, it is")
	main.hero.global_position = main.current_core.door_outside()
	await _settle()
	assert_true(far.visible and not fog.is_in_sight(far.global_position), "and out of sight again, it stays drawn")

func test_13_a_moment_in_the_mist_is_explained_once() -> void:
	# "只要玩家能感觉出来这个雾是迷雾不是天气就行".
	var explained = watch_signal(tree.root.get_node("EventBus"), "fog_explained")
	var main = await _level()
	await wait_physics_frames(int(ceil((float(_fog()["hint_after"]) + 1.0) * float(Engine.physics_ticks_per_second))))
	assert_eq(explained.emit_count, 1, "A moment into the run, what the mist is is said")
	await wait_physics_frames(int(ceil(float(_fog()["hint_after"]) * float(Engine.physics_ticks_per_second))))
	assert_eq(explained.emit_count, 1, "once")
	assert_ne(tr("HINT_FOG"), "HINT_FOG", "in words the player reads")

func test_14_what_bites_the_cabin_in_the_dark_is_seen() -> void:
	# The player's report, 2026-09-29: "晚上篝火完全不放，恐龙进攻会有点stealth的状态" -- from its middle, the
	# night's sight did not reach the ends of the cabin, and what bit it there was not drawn.
	var main = await _level()
	game_state_node.day_clock = float(config_node.DAY["parts"]["night"]) + 10.0
	game_state_node._run_the_day(0.0)
	main.hero.global_position = main.current_core.global_position + Vector3(0.0, 0.0, 30.0)
	await _settle()
	var cabin: Vector3 = main.current_core.global_position
	var half: Vector2 = config_node.get_building_half("core")
	var at_its_end: Vector3 = cabin + Vector3(half.x + 0.6, 0.0, 0.0)
	assert_gt(at_its_end.distance_to(cabin), float(_fog()["sight"]["core"]) * float(_fog()["night"]),
		"(further from its middle than it sees at night)")
	assert_true(main.fog.is_in_sight(at_its_end), "At its end, in the dark, what stands at its wall is in sight")
