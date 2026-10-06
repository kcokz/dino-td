# res://tests/test_economy_build_cycle.gd
# The place / destroy / rebuild loop, and what it costs.
#
# This was test_economy_ap_challenge.gd, and three of its four tests were about action
# points. AP is gone, so they are too. What is left is the part that still decides
# something: a building is paid for out of the wallet, and a cell freed by destruction
# can be built on again.
extends "res://tests/test_base.gd"

## Wood this suite seeds in before_each. It asserts exact balances, so it owns
## its wallet rather than inheriting Config.INITIAL_RESOURCES (production tuning).
const SEED_WOOD: int = 10

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var building_script: GDScript = null
var grid_manager_script: GDScript = null
var build_system_script: GDScript = null

var _cleanup_nodes: Array[Node] = []
var _cleanup_objects: Array[Object] = []

# ==============================================================================
# Lifecycle Hooks
# ==============================================================================

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if config_node == null and ResourceLoader.exists("res://scripts/autoload/Config.gd"):
		config_node = load("res://scripts/autoload/Config.gd").new()
		_cleanup_objects.append(config_node)

	if event_bus_node == null and ResourceLoader.exists("res://scripts/autoload/EventBus.gd"):
		event_bus_node = load("res://scripts/autoload/EventBus.gd").new()
		_cleanup_objects.append(event_bus_node)

	if game_state_node == null and ResourceLoader.exists("res://scripts/autoload/GameState.gd"):
		game_state_node = load("res://scripts/autoload/GameState.gd").new()
		_cleanup_objects.append(game_state_node)

	building_script = _load_script([
		"res://scripts/entities/Building.gd",
		"res://scripts/entities/building.gd"
	])
	grid_manager_script = _load_script([
		"res://scripts/core/GridManager.gd",
		"res://scripts/core/grid_manager.gd"
	])
	build_system_script = _load_script([
		"res://scripts/core/BuildSystem.gd",
		"res://scripts/core/build_system.gd"
	])

func before_each() -> void:
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		# reset_game() seeds Config.INITIAL_RESOURCES, which is production tuning.
		# This suite asserts exact balances, so pin its own wallet and stay decoupled
		# from whatever the opening balance happens to be.
		if "current_phase" in game_state_node: game_state_node.current_phase = 0
		if "resources" in game_state_node: game_state_node.resources = {"wood": SEED_WOOD, "stone": 0, "water": 0, "food": 0}
		if "is_game_over" in game_state_node: game_state_node.is_game_over = false
		if "active_buildings" in game_state_node: game_state_node.active_buildings.clear()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if not n.is_queued_for_deletion():
				if n.is_inside_tree():
					n.get_parent().remove_child(n)
				n.free()
	_cleanup_nodes.clear()

	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	for obj in _cleanup_objects:
		if is_instance_valid(obj):
			if obj is Node:
				if not obj.is_queued_for_deletion():
					if obj.is_inside_tree():
						obj.get_parent().remove_child(obj)
					obj.free()
	_cleanup_objects.clear()

# ==============================================================================
# Helper Utilities
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_grid_manager() -> Object:
	if grid_manager_script == null:
		return null
	var instance = grid_manager_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)
	return instance

func _create_build_system(grid_mgr: Object) -> Object:
	if build_system_script == null:
		return null
	var instance = build_system_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)
	if "grid_manager" in instance:
		instance.grid_manager = grid_mgr
	elif instance.has_method("setup"):
		instance.call("setup", grid_mgr)
	return instance

func _get_wood() -> int:
	if game_state_node != null and "resources" in game_state_node:
		return game_state_node.resources.get("wood", 0)
	return -1

func _get_phase() -> int:
	if game_state_node != null and "current_phase" in game_state_node:
		return int(game_state_node.current_phase)
	return -1

# ==============================================================================
# Section 1: 10+ Concurrent LumberHuts Producing Wood Over Multiple Turns
# ==============================================================================


# ==============================================================================
# Section 2: Destroying LumberHuts During ATTACK Phase & Verifying 0 Wood Payout
# ==============================================================================


# ==============================================================================
# Section 3: Full Simulation & Rebuilding
# ==============================================================================

func test_challenge_grid_integrated_placement_attack_destruction_and_rebuilding() -> void:
	# Track wood as a running total derived from Config, so the balance can change
	# without invalidating what this test is really about: the place/destroy/rebuild loop.
	# Stakes, not turrets: a turret is bought with wood and stone as of v0.4, and
	# this test is about the place/destroy/rebuild loop rather than about paying
	# two bills at once.
	var hut_cost: int = cost_of("wall")
	var hut_budget: int = hut_cost * 4 + 4
	var wood: int = hut_budget
	if game_state_node: game_state_node.resources["wood"] = hut_budget
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	assert_not_null(grid_mgr, "GridManager must exist")
	assert_not_null(build_sys, "BuildSystem must exist")

	assert_eq(_get_wood(), wood, "Wood starts at the seeded budget")

	var cell0 = Vector2i(1, 1)
	var cell1 = Vector2i(1, 2)
	var cell2 = Vector2i(1, 3)

	var b0 = build_sys.place_building("wall", cell0)
	var b1 = build_sys.place_building("wall", cell1)

	assert_not_null(b0, "b0 placed")
	assert_not_null(b1, "b1 placed")

	_cleanup_nodes.append(b0)
	_cleanup_nodes.append(b1)

	wood -= hut_cost * 2
	assert_eq(_get_wood(), wood, "Wood reduced by two hut costs")
	assert_true(grid_mgr.is_cell_occupied(cell0), "cell0 occupied")
	assert_true(grid_mgr.is_cell_occupied(cell1), "cell1 occupied")

	# Transition to ATTACK phase
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "Now in ATTACK phase")

	# Destroy b0 in ATTACK phase
	b0.take_damage(b0.max_hp)   # enough to level it, whatever it is made of
	assert_true(b0.is_destroyed, "b0 destroyed")

	# Verify GridManager vacated cell0, but cell1 remains occupied
	assert_false(grid_mgr.is_cell_occupied(cell0), "cell0 vacated by GridManager upon destruction")
	assert_true(grid_mgr.is_cell_occupied(cell1), "cell1 remains occupied")

	# Transition to PRODUCE phase
	event_bus_node.wave_ended.emit(1)
	assert_eq(_get_phase(), 2, "In PRODUCE phase")

	# v0.4: buildings produce nothing at all, so a turn passing moves no numbers.
	assert_eq(_get_wood(), wood, "A completed turn pays out nothing")

	# Conclude turn -> return to PLAN phase (Turn 2)
	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Returned to PLAN phase")

	# Player rebuilds on vacated cell0
	assert_true(build_sys.can_place_building("wall", cell0), "Can build on vacated cell0")
	var b_new = build_sys.place_building("wall", cell0)
	assert_not_null(b_new, "New LumberHut built successfully on vacated cell0")
	_cleanup_nodes.append(b_new)
	assert_true(grid_mgr.is_cell_occupied(cell0), "cell0 occupied once again")
	wood -= hut_cost
	assert_eq(_get_wood(), wood, "Wood deducted for the rebuilt hut")

	# Player places another LumberHut on cell2
	var b2 = build_sys.place_building("wall", cell2)
	assert_not_null(b2, "b2 placed")
	_cleanup_nodes.append(b2)
	wood -= hut_cost
	assert_eq(_get_wood(), wood, "Wood deducted for the 2nd build in Turn 2")

	# Complete Turn 2: all 3 huts pay out
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(2)
	assert_eq(_get_phase(), 2, "Turn 2 in PRODUCE phase")
	assert_eq(_get_wood(), wood, "And still nothing on the second turn")

	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Turn 3 back in PLAN")


# ==============================================================================
# ==============================================================================
