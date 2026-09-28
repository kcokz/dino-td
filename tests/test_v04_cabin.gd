# res://tests/test_v04_cabin.gd
# v0.4: the cabin is a workshop, and it is the only place the Hero gains anything.
#
# Two claims are load-bearing and both are tested here:
#   * going inside is walking in -- through the door, into a room on the map -- and it does
#     NOT swap the scene: the world outside keeps running, which is the cost that makes going
#     home a decision (v0.6 round three: it was a camera moved to a room under the map);
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

## Lets the physics run until `done` says so, or `seconds` pass.
func _until(done: Callable, seconds: float) -> void:
	for i in range(int(seconds * float(Engine.physics_ticks_per_second))):
		if done.call():
			return
		await wait_physics_frames(1)

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
		# The beacon's bench makes nothing to keep: its work is the beacon's steps, which come
		# from the run's map (test_v06_beacon).
		var steps: Array = config_node.beacon_jobs(game_state_node.map_data()) \
			if String(station_id) == String(config_node.BEACON_STATION) else []
		assert_gt(here.size() + config_node.dishes_at(String(station_id)).size() + steps.size(), 0,
			"%s has something to do" % station_id)
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

	var job: String = String(config_node.recipes_at("kitchen")[0])
	assert_true(bench.begin(job), "It takes the job")
	assert_true(bench.begin(job), "Asking for the same job again is harmless")
	assert_eq(bench.active_recipe, job, "Still the one job")

func test_07_a_finished_unlock_is_not_offered_again() -> void:
	var bench = _spawn(station_script.new("workbench"))
	await wait_frames(1)
	know_everything()      # its materials have turned up
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
# 3. The room: walked into, not a scene swap
# ==============================================================================

func test_10_the_benches_stand_in_the_cabin() -> void:
	var main = _level()
	await wait_frames(8)
	var cabin = main.current_core
	assert_eq(cabin.stations.size(), config_node.STATIONS.size(), "One bench per station in Config")
	for st in cabin.stations:
		assert_true(cabin.is_ancestor_of(st), "The %s is part of the cabin" % st.station_id)
		assert_true(cabin.is_inside(st.global_position), "and stands in its room")

func test_11_he_walks_in_through_the_door_and_the_world_runs_on() -> void:
	var main = _level()
	await wait_frames(8)
	var watcher = watch_signal(event_bus_node, "cabin_view_changed")
	var dinos_before: int = tree.get_nodes_in_group("dinos").size()
	main.hero.global_position = main.cabin_door() + Vector3(4.0, 0.0, 3.0)
	await wait_physics_frames(2)

	assert_true(main.order_enter_cabin(), "Right-clicking the cabin sends him in")
	assert_false(main.in_cabin, "He is not in yet: he walks there")
	await _until(func(): return main.in_cabin, 10.0)
	assert_true(main.in_cabin, "Walking in is what gets him in")
	assert_true(watcher.emitted, "Which is announced")
	assert_true(main.current_core.is_inside(main.hero.global_position), "He is in the room, on the map")
	assert_true(main.camera.current, "The same camera, looking at the same world")
	assert_true(is_instance_valid(main.current_nest), "The nest is still there")
	assert_eq(tree.get_nodes_in_group("dinos").size(), dinos_before, "And whatever was on the map")

func test_12_he_walks_back_out() -> void:
	var main = _level()
	await wait_frames(8)
	main.hero.global_position = main.current_core.door_inside()
	main.current_core.recheck_hero()
	assert_true(main.in_cabin, "Inside")
	assert_true(main.order_leave_cabin(), "Sent out")
	await _until(func(): return not main.in_cabin, 10.0)
	assert_false(main.in_cabin, "He walks out of the door")
	assert_false(main.current_core.is_inside(main.hero.global_position), "and is outside")

func test_13_the_door_is_the_only_way_in_and_only_for_him() -> void:
	var main = _level()
	await wait_frames(8)
	var maps = main.nav_maps
	var cabin = main.current_core
	var inside: Vector3 = cabin.door_inside()
	var behind: Vector3 = cabin.global_position + Vector3(0.0, 0.0, -(cabin.room_half().y + 2.5))
	var route: PackedVector3Array = maps.path(behind, inside, NavMaps.For.HERO)
	assert_true(maps.is_reachable(behind, inside, NavMaps.For.HERO), "From behind it he can get in")
	var length: float = 0.0
	for i in range(route.size() - 1):
		length += route[i].distance_to(route[i + 1])
	assert_gt(length, behind.distance_to(inside) + cabin.room_half().x, "the long way round, to the door -- not through the wall")
	var door_z: float = cabin.global_position.z + cabin.room_half().y
	var through_the_door: bool = false
	for p in route:
		if absf(p.z - door_z) < 0.6 and absf(p.x - cabin.door_inside().x) < 0.8:
			through_the_door = true
	assert_true(through_the_door, "and in by the door")
	assert_true(cabin.is_inside(maps.closest_point(inside, NavMaps.For.HERO)), "His map has floor in the room")
	assert_false(cabin.is_inside(maps.closest_point(inside, NavMaps.For.RAID)),
		"a raid's has none: the nearest it can stand is outside the walls")

func test_14_a_fence_round_the_cabin_shuts_him_out() -> void:
	# "栅栏围了一圈船舱之后，人在船舱外面还是能直接进到船舱，这个不合理".
	var main = _level()
	await wait_frames(8)
	unlock_all()
	stock_everything()
	var gm = main.grid_manager
	var centre: Vector2i = gm.world_to_build_cell(main.current_core.global_position)
	var half: Vector2i = Vector2i((config_node.get_building_size("core") - Vector2i.ONE) / 2)
	for x in range(-half.x - 1, half.x + 2):
		for z in range(-half.y - 1, half.y + 2):
			if absi(x) == half.x + 1 or absi(z) == half.y + 1:
				var w = main.build_system.place_at("wall", centre + Vector2i(x, z), main.buildings_container, false)
				if w != null and not w.is_constructed:
					w.complete_construction()
	main.nav_maps.rebake()
	await wait_frames(8)
	main.hero.global_position = main.cabin_door() + Vector3(0.0, 0.0, 4.0)
	await wait_physics_frames(2)
	assert_false(main.order_enter_cabin(), "Fenced off, he is not sent in")
	assert_false(main.nav_maps.is_reachable(main.hero.global_position, main.current_core.door_inside(), NavMaps.For.HERO),
		"because there is no way to the door")

func test_15_work_only_advances_while_he_is_in_the_room() -> void:
	# The whole reason the trip home costs something: standing at the bench is time
	# spent not holding the line.
	var main = _level()
	await wait_frames(8)
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = 99
	var cabin = main.current_core
	var bench = cabin.station("workbench")
	assert_not_null(bench, "The workbench is in the cabin")
	bench.begin("stone_pick")
	main.hero.global_position = cabin.door_outside() + Vector3(0.0, 0.0, 2.0)
	cabin.recheck_hero()
	cabin._process(2.0)
	assert_eq(bench.progress, 0.0, "An empty room makes nothing")
	assert_eq(String(bench.get_display_info()["status"]), tr("STATION_ONLY_WITH_HIM"), "and its bench says why")

	main.hero.global_position = cabin.door_inside()
	cabin.recheck_hero()
	cabin._process(2.0)
	assert_gt(bench.progress, 0.0, "Him being there is what moves it along")

func test_16_a_restart_puts_him_back_outside() -> void:
	var main = _level()
	await wait_frames(8)
	main.hero.global_position = main.current_core.door_inside()
	main.current_core.recheck_hero()
	main.restart_game()
	await wait_frames(4)
	assert_false(main.in_cabin, "A new game starts outdoors")
	assert_false(main.current_core.is_inside(main.hero.global_position), "him at the door, outside")
	assert_true(main.camera.current, "Looking at the map")
