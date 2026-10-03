# res://tests/test_v06_traps_in_the_way.gd
# The player, v0.6 round six: "防御太单调，木头石头都是bow（而且bow不是很flexible，如果前方被墙挡住了就不能进攻）" --
# chosen: traps by what they do (GAME-DESIGN 6.0 rule 3). SPIKES, a slot on the menu: laid on the ground of one
# cell, in nobody's way, they stab and slow what walks onto them -- wood alone, and taken up by bone, their one
# material. The Hero walks over his own; nothing hunts them. The deadfall and the snare laid beside them went in
# the 2026-10-02 rebuild of the defences (the player: "地刺：暂时保留，和墙一样可以连着造，和camp fire一样，不会block"):
# what they did, the log tower and the bait rack do (test_v07_the_towers).
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

func test_01_the_menu_is_one_slot_a_job_and_the_spikes_are_taken_up_by_bone() -> void:
	assert_eq(config_node.BUILDABLE_TYPES,
		["wall", "gate", "ground_spikes", "campfire", "bow_tower", "log_tower", "bait_rack", "catapult"] as Array[String],
		"Fence, gate, spike, fire, and the towers: shoot, roll, bait, smash -- one slot a job")
	for pair in [["ground_spikes", "bone"]]:
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

func test_05_nothing_hunts_them() -> void:
	var main = await _level()
	var d = _animal(main, main.current_core.global_position + Vector3(0.0, 0.0, 12.0))
	var spikes = _lay(main, "ground_spikes")
	if spikes != null:
		assert_false(d._is_target_valid(spikes), "An animal does not see the spikes for a thing to bite")

func test_06_the_spikes_are_taken_up_where_they_lie() -> void:
	var main = await _level()
	var pair: Array = ["ground_spikes", "bone_spikes"]
	var spikes = _lay(main, String(pair[0]), Vector3(-3.0, 0.0, 6.0))
	if spikes == null:
		return
	assert_true(spikes.begin_upgrade(String(pair[1])), "(%s is taken up)" % pair[0])
	var guard: int = 0
	while not spikes.add_upgrade_progress(1.0) and guard < 100:
		guard += 1
	assert_eq(String(spikes.building_type), String(pair[1]), "%s becomes %s where it lies" % pair)
