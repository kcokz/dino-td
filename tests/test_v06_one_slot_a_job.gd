# res://tests/test_v06_one_slot_a_job.gd
# The player, v0.6 round six: "当新的材料出现，老的材料又在，可选的建造物一下子变太多，有点杂乱无章"; "材料各种各样，
# 每次造东西都需要各种各样的材料，装备，建筑都需要各种材料，总感觉有点confuse哪个材料是用来做什么，也很难做规划".
# Chosen (GAME-DESIGN 6.0): the build menu is one slot a job, each its first form, of wood alone; every
# other material is an upgrade where a building stands, one material a step; a building is made of two
# materials at most. A fence becomes bone stakes or a stone wall; the card names each way up with its
# price; a campfire raised into a brazier stands in the way.
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
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func _build(main: Node, type_id: String, off: Vector3) -> Node:
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var b = main.build_system.place_at(type_id, main.grid_manager.world_to_build_cell(door + off), main.buildings_container)
	assert_not_null(b, "(a %s goes down by the cabin)" % type_id)
	if b != null:
		b.complete_construction()
	return b

func test_01_the_menu_is_one_slot_a_job_each_of_wood_alone() -> void:
	var menu: Array = config_node.BUILDABLE_TYPES
	for b_type in menu:
		assert_eq(config_node.BUILDINGS[b_type]["cost"].keys(), ["wood"], "%s: its first form is wood alone" % b_type)
	var reached: Array = config_node.player_building_types()
	for b_type in reached:
		if menu.has(b_type):
			continue
		var from_menu: bool = false
		for other in reached:
			if (config_node.upgrade_targets(String(other)) as Array).has(b_type):
				from_menu = true
		assert_true(from_menu, "%s is not an entry of its own: it is what something becomes" % b_type)
	for b_type in menu:
		for other in menu:
			if b_type != other:
				assert_false((config_node.upgrade_targets(String(b_type)) as Array).has(other),
					"%s and %s are different jobs, not one's upgrade of the other" % [b_type, other])

func test_02_each_step_up_adds_one_material_and_none_is_made_of_three() -> void:
	var steps: int = 0
	for b_type in config_node.player_building_types():
		assert_lte(config_node.BUILDINGS[b_type]["cost"].size(), 2, "%s is made of two materials at most" % b_type)
		for target in config_node.upgrade_targets(String(b_type)):
			var cost: Dictionary = config_node.upgrade_cost(String(b_type), String(target))
			assert_eq(cost.size(), 1, "%s -> %s adds one material (%s)" % [b_type, target, cost])
			assert_false(cost.has("wood") and String(b_type) != "", "and it is not more wood: wood is the body (%s -> %s)" % [b_type, target])
			steps += 1
	assert_gt(steps, 3, "(there are ways up)")
	assert_eq(config_node.upgrade_targets("wall"), ["bone_stake", "rock_fence", "stone_wall"] as Array[String],
		"The fence goes three ways: bone, a rock on it, or stone")

func test_03_a_fence_becomes_bone_stakes_or_a_stone_wall_where_it_stands() -> void:
	var main = await _level()
	var a = _build(main, "wall", Vector3(-3.0, 0.0, 3.0))
	var b = _build(main, "wall", Vector3(-5.0, 0.0, 3.0))
	if a == null or b == null:
		return
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = 50
	var before: Dictionary = game_state_node.resources.duplicate()
	assert_true(a.begin_upgrade("stone_wall"), "One fence is set to become a stone wall")
	for res_id in before:
		var spent: int = int(before[res_id]) - int(game_state_node.resources[res_id])
		assert_eq(spent, int(config_node.upgrade_cost("wall", "stone_wall").get(res_id, 0)), "(paying %s for it)" % res_id)
	assert_true(b.begin_upgrade("bone_stake"), "and the other bone stakes")
	assert_false(a.can_upgrade("bone_stake"), "(one way at a time)")
	for building in [a, b]:
		var guard: int = 0
		while not building.add_upgrade_progress(1.0) and guard < 100:
			guard += 1
	assert_eq(String(a.building_type), "stone_wall", "It stands a stone wall")
	assert_eq(String(b.building_type), "bone_stake", "and the other bone stakes")
	assert_false(b.begin_upgrade("stone_wall"), "What it became is not a fence to become something else")

func test_04_its_card_names_each_way_up_with_its_price() -> void:
	var main = await _level()
	var fence = _build(main, "wall", Vector3(-3.0, 0.0, 3.0))
	if fence == null:
		return
	var panel = main.hud.option_panel
	panel.select_target(fence)
	await wait_frames(2)
	var cards: Dictionary = {}
	for btn in panel.command_buttons():
		cards[String(btn.text)] = btn
	# Each the build menu's card for it: its name and icon, its price in the chips under it (v0.6 round six).
	for target in config_node.upgrade_targets("wall"):
		var want: String = String(config_node.get_building_name(String(target)))
		assert_true(cards.has(want), "The card offers \"%s\" (got %s)" % [want, cards.keys()])
		if cards.has(want):
			assert_eq((cards[want] as Button).icon, UiTheme.icon(String(target)), "%s wears its build-menu icon" % want)
			var row: Node = (cards[want] as Button).get_node_or_null("PriceRow")
			assert_true(row != null and row.get_child_count() > 0, "and its price")

func test_05_a_campfire_raised_into_a_brazier_stands_in_the_way() -> void:
	var main = await _level()
	var fire = _build(main, "campfire", Vector3(-3.0, 0.0, 3.0))
	if fire == null:
		return
	var solid: int = int(config_node.LAYER_BUILDING)
	assert_eq(int(fire.collision_layer) & solid, 0, "(a campfire is stepped over)")
	assert_true(fire.begin_upgrade("brazier"), "Stone raises it into a brazier")
	var guard: int = 0
	while not fire.add_upgrade_progress(1.0) and guard < 100:
		guard += 1
	assert_eq(String(fire.building_type), "brazier", "(a brazier now)")
	assert_ne(int(fire.collision_layer) & solid, 0, "It stands in the way, as stone does")
	await wait_physics_frames(2)
	main.nav_maps.rebake()
	await wait_physics_frames(3)     # the server takes a new mesh on its next sync
	var at: Vector3 = fire.global_position
	var route: PackedVector3Array = main.nav_maps.path(at + Vector3(-2.5, 0.0, 0.0), at + Vector3(2.5, 0.0, 0.0), NavMaps.For.RAID)
	var near: float = INF
	var c := Vector2(at.x, at.z)
	for i in range(1, route.size()):
		near = minf(near, Geometry2D.get_closest_point_to_segment(c, Vector2(route[i - 1].x, route[i - 1].z),
			Vector2(route[i].x, route[i].z)).distance_to(c))
	assert_gt(near, 0.45, "and the way across goes round it")
	var flame: Node3D = fire.get_node_or_null("Flame") as Node3D
	assert_not_null(flame, "Its flame is lit again")
	if flame != null:
		assert_almost_eq(flame.position.y, float(config_node.BUILDINGS["brazier"]["flame_height"]), 0.001,
			"at the brazier's height")
