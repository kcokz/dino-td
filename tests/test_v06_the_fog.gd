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

func test_07_the_warning_says_which_side_the_calls_come_from_until_the_nest_is_found() -> void:
	var main = await _level()
	var hud = main.hud
	var side: String = hud._side_of_the_nest()
	assert_eq(side, "N", "The first map's nest is north of the cabin")
	hud._on_raid_warning(10.0)
	assert_true(String(hud.raid_warning_banner.text).contains(tr("HUD_RAID_FROM") % tr("DIR_" + side)),
		"The warning says where the calls come from")
	game_state_node.nest_found = true
	hud._render_raid_banner()
	assert_true(String(hud.raid_warning_banner.text).contains(tr("HUD_RAID_SEEN")), "Found: they are seen setting out")

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
