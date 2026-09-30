# res://tests/test_v06_walls_take_traps.gd
# The player, v0.6 round six: "墙上挂机关类似升级方向，可以做成升级"; "bow不是很flexible，如果前方被墙挡住了就不能
# 进攻" (GAME-DESIGN 6.0). Most of a wall stays wood, a funnel; where it is bitten it becomes what the place needs:
# bone stakes, a rock set on it that comes down on whatever bites it, or stone -- and stone with bone becomes a
# crossbow set in the wall, shooting out from its face.
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
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	return main

func _row(t: String) -> Dictionary:
	return config_node.BUILDINGS[t]

func _lay(main: Node, type_id: String, cell_off: Vector2i) -> Node:
	stock_everything()
	var gm = main.grid_manager
	var c: Vector2i = gm.world_to_build_cell(main.current_core.global_position) + cell_off
	var b = main.build_system.place_at(type_id, c, main.buildings_container)
	assert_not_null(b, "(a %s goes down)" % type_id)
	if b != null:
		b.complete_construction()
	return b

func _finish(b: Node, to: String) -> Node:
	assert_true(b.begin_upgrade(to), "(%s -> %s begun)" % [b.building_type, to])
	var guard: int = 0
	var gm = b.get_tree().get_first_node_in_group("grid_manager")
	var cell: Vector2i = gm.world_to_build_cell(b.global_position)
	while is_instance_valid(b) and not b.is_queued_for_deletion() and not b.add_upgrade_progress(1.0) and guard < 100:
		guard += 1
	return gm.building_in_build_cell(cell)

func _animal(main: Node, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path("coelophysis"))).new("coelophysis")
	main.dinos_container.add_child(d)
	d.setup("coelophysis")
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = at
	d.set_physics_process(false)
	return d

func test_01_a_fence_goes_three_ways_and_stone_goes_on_to_a_crossbow_in_it() -> void:
	assert_eq(config_node.upgrade_targets("wall"), ["bone_stake", "rock_fence", "stone_wall"] as Array[String],
		"A fence: bone stakes, a rock on it, or stone")
	assert_eq(config_node.upgrade_cost("wall", "rock_fence").keys(), ["stone"], "The rock is stone")
	assert_eq(config_node.upgrade_targets("stone_wall"), ["wall_crossbow"] as Array[String], "Stone with bone: a crossbow in it")
	assert_eq(config_node.upgrade_cost("stone_wall", "wall_crossbow").keys(), ["bone"], "(the bolt is bone)")

func test_02_a_rock_fence_bitten_drops_its_rock_on_the_biter_and_is_set_again() -> void:
	var main = await _level()
	var fence = _lay(main, "wall", Vector2i(-2, 6))
	if fence == null:
		return
	fence = _finish(fence, "rock_fence")
	assert_eq(String(fence.building_type), "rock_fence", "(a rock on it)")
	var d = _animal(main, fence.global_position + Vector3(0.0, 0.0, 0.85))
	assert_true(fence.touches(d), "(the animal is against it)")
	fence.take_damage(0.5)
	assert_almost_eq(999.0 - float(d.current_hp), float(_row("rock_fence")["drop_damage"]), 0.001,
		"Bitten, the rock comes down on what bites it")
	assert_false(fence.rock_set, "and is off")
	fence.take_damage(0.5)
	assert_almost_eq(999.0 - float(d.current_hp), float(_row("rock_fence")["drop_damage"]), 0.001, "Not again while it is off")
	await wait_seconds(float(_row("rock_fence")["drop_rearm_seconds"]) + 0.3)
	assert_true(fence.rock_set, "Set back on after its while")

func test_03_stone_taken_up_into_a_crossbow_shoots_out_of_the_wall() -> void:
	var main = await _level()
	var wall = _lay(main, "stone_wall", Vector2i(0, 6))
	var beside = _lay(main, "wall", Vector2i(1, 6))
	if wall == null or beside == null:
		return
	wall.take_damage(float(wall.max_hp) * 0.5)
	var bow = _finish(wall, "wall_crossbow")
	await wait_frames(2)
	assert_not_null(bow, "A building stands in its cell")
	if bow == null:
		return
	assert_eq(String(bow.building_type), "wall_crossbow", "a crossbow in the wall")
	assert_true(bow.has_method("loose"), "which is a trap")
	assert_almost_eq(float(bow.current_hp) / float(bow.max_hp), 0.5, 0.01, "as whole as the wall was")
	assert_false(is_instance_valid(wall) and not wall.is_queued_for_deletion(), "The wall it was is gone")
	var out: Vector2i = bow.facing_step()
	var from_core: Vector3 = bow.global_position - main.current_core.global_position
	assert_gt(Vector2(float(out.x), float(out.y)).dot(Vector2(from_core.x, from_core.z)), 0.0, "It shoots out, away from the cabin")
	assert_true(Wall.is_wall(bow), "and the fence beside it joins it, as a wall")
	await wait_physics_frames(2)
	bow.refresh_lane()
	assert_gt(bow.lane.size(), 0, "(its lane runs out from the wall's face)")
	var step := Vector3(float(out.x), 0.0, float(out.y))
	var d = _animal(main, bow.global_position + step * 2.0)
	await wait_physics_frames(3)
	assert_lt(float(d.current_hp), 999.0, "What walks its lane is shot")
