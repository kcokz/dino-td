# res://tests/test_v04_repair_and_actions.gd
# v0.4 follow-ups:
#   * a damaged building can be mended instead of only replaced;
#   * right-click does the one obvious thing, and asks when there is more than one.
#
# The second is the interesting rule. Right-click has always acted immediately and
# that is worth keeping for the common case -- but a damaged building has several
# sensible answers, and silently picking one of them is guessing.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var wall_script: GDScript = null
var tower_script: GDScript = null
var hero_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
	wall_script = load("res://scripts/entities/Wall.gd")
	tower_script = load("res://scripts/entities/Tower.gd")
	hero_script = load("res://scripts/entities/Hero.gd")

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
	clear_drops()
	super.after_each()

func _spawn(script: GDScript, pos: Vector3 = Vector3.ZERO) -> Node:
	var n = script.new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = pos
	return n

func _turret(pos: Vector3 = Vector3.ZERO) -> Node:
	var t = _spawn(tower_script, pos)
	t.complete_construction()
	return t

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

# ==============================================================================
# 1. Mending
# ==============================================================================

func test_01_only_a_damaged_finished_building_wants_repair() -> void:
	var turret = _turret()
	await wait_frames(1)
	assert_false(turret.needs_repair(), "At full health there is nothing to mend")
	assert_eq(turret.repair_cost(), 0, "And nothing to pay")

	turret.take_damage(turret.max_hp * 0.5)
	assert_true(turret.needs_repair(), "Damaged, it does")
	assert_gt(turret.repair_cost(), 0, "And it quotes a price")

	var blueprint = _spawn(tower_script, Vector3(20.0, 0.0, 0.0))
	blueprint.start_construction()
	await wait_frames(1)
	assert_false(blueprint.needs_repair(), "A blueprint is raised, not mended")

func test_02_the_quoted_price_is_what_it_actually_costs() -> void:
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 1.0)
	var quoted: int = turret.repair_cost()
	game_state_node.resources["wood"] = 999

	var before: int = int(game_state_node.resources["wood"])
	var guard: int = 0
	while turret.needs_repair() and guard < 200:
		turret.repair_tick()
		guard += 1
	var spent: int = before - int(game_state_node.resources["wood"])
	assert_eq(spent, quoted, "The menu's figure and the bill are the same number")
	assert_almost_eq(turret.current_hp, turret.max_hp, 0.001, "And it ends up full")

func test_03_one_step_is_one_wood_so_stopping_half_way_is_clean() -> void:
	# Whole-wood transactions: walk away mid-repair and you keep exactly what you
	# paid for, with no fractional change owed either way.
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 1.0)
	game_state_node.resources["wood"] = 99

	var hp_before: float = turret.current_hp
	var wood_before: int = int(game_state_node.resources["wood"])
	turret.repair_tick()
	assert_eq(int(game_state_node.resources["wood"]), wood_before - 1, "One step costs one wood")
	assert_almost_eq(turret.current_hp, hp_before + float(config_node.REPAIR["hp_per_wood"]), 0.001,
		"And buys exactly what a wood buys")

func test_04_an_empty_warehouse_stops_the_job_where_it_stands() -> void:
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 1.0)
	game_state_node.resources["wood"] = 0

	var hp_before: float = turret.current_hp
	assert_true(turret.repair_tick(), "With nothing to spend, the job is over")
	assert_almost_eq(turret.current_hp, hp_before, 0.001, "And nothing was mended for free")

func test_05_repairing_is_cheaper_than_rebuilding_what_is_worth_repairing() -> void:
	# Otherwise nobody would ever mend anything. It is deliberately the other way
	# round for a one-wood stake: replacing that is correct.
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 0.01)
	assert_lt(turret.repair_cost(), cost_of("tower"),
		"A gutted turret costs less to mend than to build again")

func test_06_the_hero_mends_with_the_same_order_that_builds() -> void:
	# One verb: he walks over and works on it. What the hammer is for is the
	# building's business.
	var hero = _spawn(hero_script, Vector3.ZERO)
	hero.continuous_mode = true
	var turret = _turret(Vector3(1.0, 0.0, 0.0))
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 1.0)
	game_state_node.resources["wood"] = 99

	hero.order_repair(turret)
	assert_eq(int(hero.current_state), int(hero_script.State.BUILDING), "He sets to work")

	var hp_before: float = turret.current_hp
	hero._physics_process(float(config_node.REPAIR["seconds_per_wood"]) + 0.01)
	assert_gt(turret.current_hp, hp_before, "And the building comes back up")

# ==============================================================================
# 2. One action happens, several ask
# ==============================================================================

func test_07_a_blueprint_has_exactly_one_answer() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var blueprint = main.place_building_at_cell("wall", Vector2i(3, 3))
	assert_not_null(blueprint, "A blueprint is down")
	blueprint.start_construction()
	await wait_frames(1)

	var actions: Array = main.available_actions_for(blueprint)
	assert_eq(actions.size(), 1, "There is one thing to do with an unfinished building")
	assert_eq(String(actions[0]), "build", "Namely finish it")

func test_08_the_cabin_has_exactly_one_answer_too() -> void:
	var main = _level()
	await wait_frames(2)
	var actions: Array = main.available_actions_for(main.current_core)
	assert_eq(actions.size(), 1, "The cabin is one thing you do with it")
	assert_eq(String(actions[0]), "enter", "You go inside")

func test_09_a_healthy_building_offers_demolish_or_walking_over() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var turret = main.place_building_at_cell("tower", Vector2i(4, 4))
	turret.complete_construction()
	await wait_frames(1)

	var actions: Array = main.available_actions_for(turret)
	assert_gt(actions.size(), 1, "More than one sensible answer, so it must ask")
	assert_has(actions, "demolish", "Pulling it down is one")
	assert_has(actions, "move", "Just walking over there is another")
	assert_not_has(actions, "repair", "Nothing to mend on a building at full health")

func test_10_a_damaged_building_adds_repair_to_the_list() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var turret = main.place_building_at_cell("tower", Vector2i(4, 5))
	turret.complete_construction()
	turret.take_damage(turret.max_hp * 0.5)
	await wait_frames(1)

	var actions: Array = main.available_actions_for(turret)
	assert_has(actions, "repair", "Mending is on the menu")
	assert_eq(String(actions[0]), "repair", "And it leads, being the most specific")

func test_11_repair_is_not_offered_when_it_cannot_be_paid_for() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var turret = main.place_building_at_cell("tower", Vector2i(4, 6))
	turret.complete_construction()
	turret.take_damage(turret.max_hp * 0.5)
	game_state_node.resources["wood"] = 0
	await wait_frames(1)

	assert_not_has(main.available_actions_for(turret), "repair",
		"An option that cannot be taken is not an option")

func test_12_a_single_action_happens_without_asking() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var blueprint = main.place_building_at_cell("wall", Vector2i(5, 5))
	assert_not_null(blueprint, "A blueprint is down")
	blueprint.start_construction()
	await wait_frames(1)

	main.right_click_building(blueprint, blueprint.global_position, Vector2(10.0, 10.0))
	assert_eq(main.hero.target_building, blueprint, "The one thing to do just happens")
	assert_true(main.action_menu == null or not main.action_menu.visible,
		"And nothing is put up to click through")

func test_13_several_actions_put_up_a_menu_and_choosing_one_acts() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var turret = main.place_building_at_cell("tower", Vector2i(6, 6))
	turret.complete_construction()
	turret.take_damage(turret.max_hp * 0.5)
	await wait_frames(1)

	main.right_click_building(turret, turret.global_position, Vector2(40.0, 40.0))
	assert_not_null(main.action_menu, "A menu is offered")
	assert_eq(main.action_menu.item_count, main.available_actions_for(turret).size(),
		"With one entry per available action")

	# Choosing "repair" is what starts the work -- nothing happened before the click.
	var idx: int = main.available_actions_for(turret).find("repair")
	assert_gte(idx, 0, "Repair is in the list")
	main._on_action_menu_id(idx)
	assert_eq(main.hero.target_building, turret, "Picking it sends the Hero to work")

func test_14_the_menu_quotes_what_the_repair_will_cost() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var turret = main.place_building_at_cell("tower", Vector2i(7, 7))
	turret.complete_construction()
	turret.take_damage(turret.max_hp * 0.75)
	await wait_frames(1)

	var label: String = main._action_label("repair", turret)
	assert_true(label.contains(str(turret.repair_cost())),
		"The player is told the price before choosing it (got '%s')" % label)
