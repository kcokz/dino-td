# res://tests/test_v04_cabin.gd
# v0.4: the cabin is a workshop, and it is the only place the Hero gains anything.
#
# Two claims are load-bearing and both are tested here:
#   * stepping inside moves the camera, it does NOT swap the scene -- the world
#     outside keeps running, which is the cost that makes going home a decision;
#   * what a bench makes is a permanent flag, never an object, so there is no bag,
#     no durability and nothing to carry.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var station_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")
	station_script = load("res://scripts/entities/CraftingStation.gd")

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

func _spawn(node: Node) -> Node:
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	return node

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

func _pay(recipe_id: String) -> void:
	for res_id in config_node.RECIPES[recipe_id]["inputs"]:
		game_state_node.resources[res_id] = int(config_node.RECIPES[recipe_id]["inputs"][res_id])

# ==============================================================================
# 1. Recipes are one shape, whatever bench they belong to
# ==============================================================================

func test_01_every_recipe_has_the_same_shape() -> void:
	assert_gt(config_node.RECIPES.size(), 0, "There is something to make")
	for recipe_id in config_node.RECIPES:
		var data: Dictionary = config_node.RECIPES[recipe_id]
		for key in ["station", "inputs", "time", "unlocks", "name"]:
			assert_has(data, key, "%s declares '%s'" % [recipe_id, key])
		assert_has(config_node.STATIONS, String(data["station"]),
			"%s is made at a station that exists" % recipe_id)
		assert_gt(float(data["time"]), 0.0, "%s takes real seconds" % recipe_id)
		assert_gt(data["inputs"].size(), 0, "%s costs something" % recipe_id)
		for res_id in data["inputs"]:
			assert_has(config_node.RESOURCES, String(res_id),
				"%s is paid for in a real resource (%s)" % [recipe_id, res_id])

func test_02_a_recipe_grants_a_flag_and_nothing_else() -> void:
	# The line that keeps the cabin from becoming an inventory screen: what comes
	# out is a permanent flag, so there is nothing to carry, stack or lose.
	for recipe_id in config_node.RECIPES:
		var data: Dictionary = config_node.RECIPES[recipe_id]
		assert_ne(String(data["unlocks"]), "", "%s unlocks something" % recipe_id)
		for key in ["amount", "count", "durability", "stack", "item"]:
			assert_false(data.has(key), "%s must not carry '%s' -- unlocks are not items" % [recipe_id, key])

func test_03_stations_only_offer_their_own_recipes() -> void:
	for station_id in config_node.STATIONS:
		var here: Array = config_node.recipes_at(String(station_id))
		assert_gt(here.size(), 0, "%s has something to make" % station_id)
		for recipe_id in here:
			assert_eq(String(config_node.RECIPES[recipe_id]["station"]), String(station_id),
				"%s belongs to %s" % [recipe_id, station_id])

# ==============================================================================
# 2. Making something
# ==============================================================================

func test_04_work_costs_its_inputs_up_front_and_takes_real_time() -> void:
	var bench = _spawn(station_script.new("workbench"))
	await wait_frames(1)
	_pay("stone_pick")

	var bone_before: int = int(game_state_node.resources.get("bone", 0))
	assert_true(bench.begin("stone_pick"), "The bench takes the job")
	assert_lt(int(game_state_node.resources.get("bone", 0)), bone_before,
		"Materials are spent when work starts, so walking away costs something")

	var needed: float = float(config_node.RECIPES["stone_pick"]["time"])
	assert_eq(bench.work(needed * 0.5), "", "Half the work is not the thing")
	assert_false(game_state_node.has_unlock("harvest_stone"), "And grants nothing yet")
	assert_eq(bench.work(needed * 0.5 + 0.01), "harvest_stone", "Finishing it grants the flag")
	assert_true(game_state_node.has_unlock("harvest_stone"), "Which GameState now holds")

func test_05_what_cannot_be_paid_for_cannot_be_started() -> void:
	var bench = _spawn(station_script.new("workbench"))
	await wait_frames(1)
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = 0

	assert_false(bench.can_afford("stone_pick"), "An empty warehouse affords nothing")
	assert_false(bench.begin("stone_pick"), "So the job does not start")
	assert_eq(bench.active_recipe, "", "And the bench is still idle")

func test_06_a_bench_makes_one_thing_at_a_time() -> void:
	var bench = _spawn(station_script.new("kitchen"))
	await wait_frames(1)
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = 99

	assert_true(bench.begin("roast_meat"), "It takes the job")
	assert_true(bench.begin("roast_meat"), "Asking for the same job again is harmless")
	assert_eq(bench.active_recipe, "roast_meat", "Still the one job")

func test_07_a_finished_unlock_is_not_offered_again() -> void:
	var bench = _spawn(station_script.new("workbench"))
	await wait_frames(1)
	assert_true(bench.can_offer("stone_pick"), "Before it is made, it is on the menu")

	game_state_node.grant_unlock("harvest_stone")
	assert_false(bench.can_offer("stone_pick"), "Once made it is permanent, so it leaves the menu")

func test_08_granting_the_same_unlock_twice_changes_nothing() -> void:
	var watcher = watch_signal(event_bus_node, "unlock_granted")
	assert_true(game_state_node.grant_unlock("harvest_stone"), "The first grant takes")
	assert_false(game_state_node.grant_unlock("harvest_stone"), "The second is a no-op")
	assert_eq(watcher.emit_count, 1, "And it is announced exactly once")

func test_09_a_reset_takes_the_unlocks_with_it() -> void:
	game_state_node.grant_unlock("harvest_stone")
	assert_true(game_state_node.has_unlock("harvest_stone"), "Held")
	game_state_node.reset_game()
	assert_false(game_state_node.has_unlock("harvest_stone"), "A new game starts with empty hands")

# ==============================================================================
# 3. The room: a camera move, not a scene swap
# ==============================================================================

func test_10_the_level_carries_an_interior_parked_off_the_map() -> void:
	var main = _level()
	await wait_frames(2)

	assert_not_null(main.cabin_interior, "The level instances the cabin's inside")
	assert_lt(main.cabin_interior.global_position.y, -50.0,
		"Parked well below the map, where it cannot be seen from outside")
	assert_eq(main.cabin_interior.stations.size(), config_node.STATIONS.size(),
		"With one bench per station in Config")

func test_11_stepping_inside_moves_the_camera_and_leaves_the_world_running() -> void:
	var main = _level()
	await wait_frames(2)
	var watcher = watch_signal(event_bus_node, "cabin_view_changed")

	var dinos_before: int = tree.get_nodes_in_group("dinos").size()
	assert_true(main.enter_cabin(), "The player steps inside")
	assert_true(main.in_cabin, "And is inside")
	assert_true(watcher.emitted, "Which is announced")
	assert_true(main.cabin_interior.camera.current, "The cabin's camera is the one in use")

	# The world is not a scene that got swapped out: everything is still here.
	assert_true(is_instance_valid(main.hero), "The Hero still exists")
	assert_true(is_instance_valid(main.current_nest), "So does the nest")
	assert_eq(tree.get_nodes_in_group("dinos").size(), dinos_before, "And whatever was on the map")
	assert_true(main.is_inside_tree(), "The level was never unloaded")

func test_12_leaving_is_instant_and_hands_the_map_back() -> void:
	var main = _level()
	await wait_frames(2)
	main.enter_cabin()

	assert_true(main.leave_cabin(), "Esc steps back out")
	assert_false(main.in_cabin, "And we are outside")
	assert_true(main.camera.current, "The map camera has it back")
	assert_false(main.cabin_interior.camera.current, "And the cabin's does not")

func test_13_right_clicking_the_cabin_walks_there_and_steps_in_on_arrival() -> void:
	var main = _level()
	await wait_frames(2)
	main.hero.global_position = main.current_core.global_position + Vector3(14.0, 0.0, 0.0)

	assert_true(main.order_enter_cabin(), "The order is taken")
	assert_false(main.in_cabin, "He is not there yet, so nothing happens")

	# Walking home is what gets him in -- no second click.
	main.hero.global_position = main.current_core.global_position + Vector3(1.0, 0.0, 0.0)
	main._check_pending_cabin_entry()
	assert_true(main.in_cabin, "Arriving is what opens the door")

func test_14_another_order_on_the_way_cancels_the_trip_home() -> void:
	var main = _level()
	await wait_frames(2)
	main.hero.global_position = main.current_core.global_position + Vector3(14.0, 0.0, 0.0)
	main.order_enter_cabin()

	main._pending_cabin_entry = false   # what a fresh right-click does
	main.hero.global_position = main.current_core.global_position + Vector3(1.0, 0.0, 0.0)
	main._check_pending_cabin_entry()
	assert_false(main.in_cabin, "Changing his orders changes where he ends up")

func test_15_work_only_advances_while_somebody_is_in_the_room() -> void:
	# The whole reason the trip home costs something: standing at the bench is time
	# spent not holding the line.
	var main = _level()
	await wait_frames(2)
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = 99
	var bench = main.cabin_interior.station("workbench")
	assert_not_null(bench, "The workbench is in the room")
	bench.begin("stone_pick")

	main.cabin_interior._process(2.0)
	assert_eq(bench.progress, 0.0, "An empty room makes nothing")

	main.enter_cabin()
	main.cabin_interior._process(2.0)
	assert_gt(bench.progress, 0.0, "Being there is what moves it along")

func test_16_a_restart_puts_the_player_back_outside() -> void:
	var main = _level()
	await wait_frames(2)
	main.enter_cabin()
	main.restart_game()
	await wait_frames(2)

	assert_false(main.in_cabin, "A new game starts outdoors")
	assert_true(main.camera.current, "Looking at the map")
