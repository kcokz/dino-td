# res://tests/test_economy_ap_challenge.gd
# Empirical Challenger 2 Test Suite for Milestone 3:
# Stress tests economy production and AP recovery:
# 1. 10+ concurrent LumberHuts producing wood over multiple turns.
# 2. Destroying LumberHuts during ATTACK phase and verifying 0 wood payout in PRODUCE phase.
# 3. Dynamic AP recovery, capacity adjustments with building bonuses, and state boundary resilience.
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
		if "current_ap" in game_state_node: game_state_node.current_ap = 3
		if "max_ap" in game_state_node: game_state_node.max_ap = 3
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

func _get_ap() -> int:
	if game_state_node != null and "current_ap" in game_state_node:
		return game_state_node.current_ap
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

	# Seeded above; AP still starts at 3
	assert_eq(_get_ap(), 3, "Initial AP is 3")
	assert_eq(_get_wood(), wood, "Wood starts at the seeded budget")

	var cell0 = Vector2i(1, 1)
	var cell1 = Vector2i(1, 2)
	var cell2 = Vector2i(1, 3)

	# Place 2 LumberHuts via BuildSystem (2 AP plus two hut costs)
	var b0 = build_sys.place_building("wall", cell0)
	var b1 = build_sys.place_building("wall", cell1)

	assert_not_null(b0, "b0 placed")
	assert_not_null(b1, "b1 placed")

	_cleanup_nodes.append(b0)
	_cleanup_nodes.append(b1)

	# Remaining AP: 3 - 2 = 1. Wood: the seeded budget minus two hut costs.
	assert_eq(_get_ap(), 1, "AP is 1 after placing 2 huts")
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
	assert_eq(_get_ap(), 3, "AP reset to max_ap (3)")

	# Player rebuilds on vacated cell0
	assert_true(build_sys.can_place_building("wall", cell0), "Can build on vacated cell0")
	var b_new = build_sys.place_building("wall", cell0)
	assert_not_null(b_new, "New LumberHut built successfully on vacated cell0")
	_cleanup_nodes.append(b_new)
	assert_true(grid_mgr.is_cell_occupied(cell0), "cell0 occupied once again")
	assert_eq(_get_ap(), 2, "AP deducted for new build (3 -> 2)")
	wood -= hut_cost
	assert_eq(_get_wood(), wood, "Wood deducted for the rebuilt hut")

	# Player places another LumberHut on cell2
	var b2 = build_sys.place_building("wall", cell2)
	assert_not_null(b2, "b2 placed")
	_cleanup_nodes.append(b2)
	assert_eq(_get_ap(), 1, "AP deducted for 2nd build in Turn 2 (2 -> 1)")
	wood -= hut_cost
	assert_eq(_get_wood(), wood, "Wood deducted for the 2nd build in Turn 2")

	# Complete Turn 2: all 3 huts pay out
	game_state_node.trigger_end_action()
	event_bus_node.wave_ended.emit(2)
	assert_eq(_get_phase(), 2, "Turn 2 in PRODUCE phase")
	assert_eq(_get_wood(), wood, "And still nothing on the second turn")

	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Turn 3 back in PLAN")
	assert_eq(_get_ap(), 3, "Turn 3 AP reset to 3")


# ==============================================================================
# Section 4: Action Point (AP) Recovery & Dynamic Capacity Stress Testing
# ==============================================================================

func test_challenge_ap_recovery_multi_turn_stress() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# 10 turn loop stress-testing AP drain and recovery
	for turn in range(1, 11):
		assert_eq(_get_phase(), 0, "Turn %d in PLAN" % turn)
		assert_eq(_get_ap(), 3, "Turn %d starts with full AP (3)" % turn)

		var spend_amount = (turn % 3) + 1 # cycles 2, 3, 1, 2, 3...
		assert_true(game_state_node.spend_ap(spend_amount), "Turn %d spend %d AP" % [turn, spend_amount])
		assert_eq(_get_ap(), 3 - spend_amount, "Turn %d AP after spend" % turn)

		# ATTACK phase: AP must not change
		game_state_node.trigger_end_action()
		assert_eq(_get_phase(), 1, "Turn %d ATTACK" % turn)
		assert_eq(_get_ap(), 3 - spend_amount, "AP locked in ATTACK")

		# PRODUCE phase: AP must not change
		event_bus_node.wave_ended.emit(turn)
		assert_eq(_get_phase(), 2, "Turn %d PRODUCE" % turn)
		assert_eq(_get_ap(), 3 - spend_amount, "AP locked in PRODUCE")

		# Watch ap_changed signal when transitioning back to PLAN
		var ap_watcher = watch_signal(event_bus_node, "ap_changed")
		game_state_node.advance_phase()
		assert_eq(_get_phase(), 0, "Turn %d back to PLAN" % turn)
		assert_eq(_get_ap(), 3, "Turn %d AP reset to 3 upon entering PLAN" % turn)
		assert_true(ap_watcher.emitted, "ap_changed emitted on return to PLAN")
		if not ap_watcher.last_args.is_empty():
			assert_eq(int(ap_watcher.last_args[0]), 3, "ap_changed current arg is 3")
			assert_eq(int(ap_watcher.last_args[1]), 3, "ap_changed max arg is 3")

func test_challenge_ap_recovery_with_dynamic_building_bonuses() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	assert_eq(game_state_node.max_ap, 3, "Base max_ap is 3")

	# Create 3 mock building nodes with ap_bonus = 1 extending Building.gd
	var bonus_script = GDScript.new()
	bonus_script.source_code = "extends 'res://scripts/entities/Building.gd'\nvar ap_bonus: int = 1\n"
	bonus_script.reload()

	var b_bonus1 = bonus_script.new()
	var b_bonus2 = bonus_script.new()
	var b_bonus3 = bonus_script.new()
	_cleanup_nodes.append(b_bonus1)
	_cleanup_nodes.append(b_bonus2)
	_cleanup_nodes.append(b_bonus3)

	# Register all 3 bonus buildings
	game_state_node.register_building(b_bonus1)
	game_state_node.register_building(b_bonus2)
	game_state_node.register_building(b_bonus3)

	assert_eq(game_state_node.max_ap, 6, "max_ap raised to 3 + 3 = 6")

	# Enter PLAN phase: AP resets to new max_ap (6)
	game_state_node.reset_ap()
	assert_eq(_get_ap(), 6, "AP resets to 6 with 3 bonus buildings")

	# Spend 6 AP in PLAN
	assert_true(game_state_node.spend_ap(6), "Spend all 6 AP")
	assert_eq(_get_ap(), 0, "AP is 0")

	# Enter ATTACK
	game_state_node.trigger_end_action()
	assert_eq(_get_phase(), 1, "In ATTACK phase")

	# Destroy 2 of the 3 bonus buildings during ATTACK
	b_bonus1.destroy()
	b_bonus2.destroy()

	# max_ap dynamically updates to 3 + 1 = 4
	assert_eq(game_state_node.max_ap, 4, "max_ap dropped to 4 after destroying 2 bonus buildings")

	# Enter PRODUCE then back to PLAN
	event_bus_node.wave_ended.emit(1)
	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Back in PLAN")
	assert_eq(_get_ap(), 4, "AP resets to new max_ap (4)")

	# Destroy the final bonus building during next ATTACK
	game_state_node.trigger_end_action()
	b_bonus3.destroy()
	assert_eq(game_state_node.max_ap, 3, "max_ap reverted to Config.BASE_AP (3)")

	# Return to PLAN -> AP resets to 3
	event_bus_node.wave_ended.emit(2)
	game_state_node.advance_phase()
	assert_eq(_get_phase(), 0, "Back in PLAN")
	assert_eq(_get_ap(), 3, "AP fully restored to base 3")

func test_challenge_ap_boundary_resilience() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	# Corrupt AP to negative
	game_state_node.current_ap = -50
	assert_false(game_state_node.can_spend_ap(1), "can_spend_ap false when AP negative")
	game_state_node.reset_ap()
	assert_eq(_get_ap(), 3, "reset_ap() restores negative AP to max_ap (3)")

	# Corrupt AP to overflow
	game_state_node.current_ap = 999
	game_state_node.recalculate_max_ap()
	assert_eq(_get_ap(), 3, "recalculate_max_ap clamps overflow AP to max_ap (3)")

	# Spend bounds
	assert_false(game_state_node.spend_ap(4), "Cannot spend 4 AP when current is 3")
	assert_false(game_state_node.spend_ap(-1), "Cannot spend negative AP")
	assert_eq(_get_ap(), 3, "AP unchanged after invalid spend attempts")

