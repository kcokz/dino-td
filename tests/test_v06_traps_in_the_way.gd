# res://tests/test_v06_traps_in_the_way.gd
# The player, v0.6 round six: "防御太单调，木头石头都是bow（而且bow不是很flexible，如果前方被墙挡住了就不能进攻）" --
# chosen: traps by what they do (GAME-DESIGN 6.0 rule 3). Three more slots on the menu, each laid on the ground
# of one cell, in nobody's way, taking what walks onto it -- spikes stab and slow, a deadfall comes down on
# what is under it, a snare holds the first to step in -- each of wood alone, and each taken up by its one
# material. The Hero walks over his own; nothing hunts them.
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
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	if main.night_prowl != null:
		main.night_prowl.enabled = false
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	return main

func _row(t: String) -> Dictionary:
	return config_node.BUILDINGS[t]

func _lay(main: Node, type_id: String, off: Vector3 = Vector3(-3.0, 0.0, 4.0)) -> Node:
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var b = main.build_system.place_at(type_id, main.grid_manager.world_to_build_cell(door + off), main.buildings_container)
	assert_not_null(b, "(a %s is laid by the cabin)" % type_id)
	if b != null:
		b.complete_construction()
	return b

## A raider standing still where it is put, soft enough to count its hurts, hard enough to live.
func _animal(main: Node, at: Vector3, species: String = "coelophysis") -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new(species)
	main.dinos_container.add_child(d)
	d.setup(species)
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = at
	d.set_physics_process(false)
	return d

func test_01_the_menu_is_seven_jobs_and_each_new_one_is_taken_up_by_its_one_material() -> void:
	assert_eq(config_node.BUILDABLE_TYPES,
		["wall", "gate", "trip_bow", "ground_spikes", "log_deadfall", "grass_snare", "campfire"] as Array[String],
		"Fence, gate, shoot, spike, crush, snare, fire -- one slot a job")
	for pair in [["ground_spikes", "bone"], ["log_deadfall", "stone"], ["grass_snare", "hide"]]:
		var t: String = String(pair[0])
		assert_eq(_row(t)["cost"].keys(), ["wood"], "%s is wood alone" % t)
		assert_true(bool(_row(t).get("walk_over", false)), "%s is in nobody's way" % t)
		var ups: Array = config_node.upgrade_targets(t)
		assert_eq(ups.size(), 1, "(%s has one way up)" % t)
		if ups.size() == 1:
			assert_eq(config_node.upgrade_cost(t, String(ups[0])).keys(), [String(pair[1])],
				"%s is taken up by %s, its one material" % [t, pair[1]])

func test_02_spikes_stab_what_steps_on_them_once_slow_it_and_are_blunted() -> void:
	var main = await _level()
	var spikes = _lay(main, "ground_spikes")
	if spikes == null:
		return
	var d = _animal(main, spikes.global_position)
	await wait_physics_frames(3)
	var hurt: float = 999.0 - float(d.current_hp)
	assert_almost_eq(hurt, float(_row("ground_spikes")["damage"]), 0.001, "Stepped on, it is stabbed once")
	assert_almost_eq(float(d.trap_pace), float(_row("ground_spikes")["slow"]), 0.001, "and slowed while on it")
	assert_almost_eq(float(spikes.current_hp), float(_row("ground_spikes")["hp"]) - float(_row("ground_spikes")["wear"]), 0.001,
		"and the spikes are the blunter for it")
	d.global_position = spikes.global_position + Vector3(3.0, 0.0, 0.0)
	await wait_physics_frames(2)
	# (Standing still for the count, its own step is off: its clock is moved on by hand.)
	d._tick_traps(float(config_node.TRAPS["slow_linger"]) + 0.05)
	assert_almost_eq(float(d.trap_pace), 1.0, 0.001, "Off them, its pace comes back")
	d.global_position = spikes.global_position
	await wait_physics_frames(3)
	assert_almost_eq(999.0 - float(d.current_hp), hurt * 2.0, 0.001, "Back on them, stabbed again")
	var hero = main.hero
	var hero_hp: float = float(hero.current_hp)
	hero.global_position = spikes.global_position + Vector3(0.1, 0.0, 0.0)
	await wait_physics_frames(3)
	assert_eq(float(hero.current_hp), hero_hp, "He walks over his own unharmed")

func test_03_a_deadfall_comes_down_on_all_under_it_and_is_propped_again() -> void:
	var main = await _level()
	var fall = _lay(main, "log_deadfall")
	if fall == null:
		return
	var a = _animal(main, fall.global_position + Vector3(-0.2, 0.0, 0.0))
	var b = _animal(main, fall.global_position + Vector3(0.25, 0.0, 0.1))
	await wait_physics_frames(3)
	var dmg: float = float(_row("log_deadfall")["damage"])
	assert_almost_eq(999.0 - float(a.current_hp), dmg, 0.001, "The first under it is struck")
	assert_almost_eq(999.0 - float(b.current_hp), dmg, 0.001, "and everything else on its cell with it")
	assert_false(fall.armed, "It is down")
	var c = _animal(main, fall.global_position)
	await wait_physics_frames(3)
	assert_almost_eq(999.0 - float(c.current_hp), 0.0, 0.001, "Down, it takes nothing more")
	for d in [a, b, c]:
		d.global_position += Vector3(4.0, 0.0, 0.0)
	await wait_seconds(float(_row("log_deadfall")["rearm_seconds"]) + 0.3)
	assert_true(fall.armed, "Propped again after its while")

func test_04_a_snare_holds_the_first_where_it_stands_and_a_boss_as_its_cord_allows() -> void:
	var main = await _level()
	var snare = _lay(main, "grass_snare")
	if snare == null:
		return
	var d = _animal(main, snare.global_position)
	d.set_physics_process(true)
	d.waypoints = [snare.global_position + Vector3(8.0, 0.0, 0.0)] as Array[Vector3]
	await wait_physics_frames(2)
	assert_almost_eq(float(d.held_left), float(_row("grass_snare")["hold_seconds"]), 0.1, "The first to step in is held")
	var at: Vector3 = d.global_position
	await wait_seconds(float(_row("grass_snare")["hold_seconds"]) * 0.6)
	assert_lt(Vector2(d.global_position.x - at.x, d.global_position.z - at.z).length(), 0.1, "where it stands")
	assert_false(snare.armed, "(sprung)")
	# A boss: grass cord does not hold one; a thong of hide holds it a while.
	var boss_species: String = String(game_state_node.map_data()["minor_boss"])
	var other = _lay(main, "grass_snare", Vector3(-6.0, 0.0, 4.0))
	var boss = _animal(main, other.global_position, boss_species)
	await wait_physics_frames(2)
	assert_almost_eq(float(boss.held_left), float(_row("grass_snare")["boss_hold_seconds"]), 0.001, "Grass does not hold a boss")
	var thong = _lay(main, "hide_snare", Vector3(-9.0, 0.0, 4.0))
	var boss2 = _animal(main, thong.global_position, boss_species)
	await wait_physics_frames(2)
	assert_almost_eq(float(boss2.held_left), float(_row("hide_snare")["boss_hold_seconds"]), 0.1, "Hide holds one a while")

func test_05_nothing_hunts_them() -> void:
	var main = await _level()
	var d = _animal(main, main.current_core.global_position + Vector3(0.0, 0.0, 12.0))
	for t in ["ground_spikes", "log_deadfall", "grass_snare"]:
		var trap = _lay(main, t, Vector3(-3.0 - 2.0 * ["ground_spikes", "log_deadfall", "grass_snare"].find(t), 0.0, 4.0))
		if trap != null:
			assert_false(d._is_target_valid(trap), "An animal does not see %s for a thing to bite" % t)

func test_06_each_is_taken_up_where_it_lies_and_its_moving_part_found_again() -> void:
	var main = await _level()
	for pair in [["ground_spikes", "bone_spikes"], ["log_deadfall", "stone_deadfall"], ["grass_snare", "hide_snare"]]:
		var trap = _lay(main, String(pair[0]), Vector3(-3.0 - 2.0 * ["ground_spikes", "log_deadfall", "grass_snare"].find(String(pair[0])), 0.0, 6.0))
		if trap == null:
			continue
		assert_true(trap.begin_upgrade(String(pair[1])), "(%s is taken up)" % pair[0])
		var guard: int = 0
		while not trap.add_upgrade_progress(1.0) and guard < 100:
			guard += 1
		assert_eq(String(trap.building_type), String(pair[1]), "%s becomes %s where it lies" % pair)
		if String(_row(String(pair[1]))["kind"]) != "spikes":
			assert_not_null(trap._mover, "and what moves on it is found again (%s)" % pair[1])
