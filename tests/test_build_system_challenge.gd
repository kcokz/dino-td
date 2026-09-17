# res://tests/test_build_system_challenge.gd
# Challenger 2 Milestone 2 Empirical Stress & Challenge Test Suite:
# Rigorously stress-tests BuildSystem and Building Lifecycles against edge cases:
# 1. Duplicate building placement & rapid duplicate attempts across all types and quadrants.
# 2. Placement phase enforcement (blocked in ATTACK, blocked in PRODUCE, allowed only in PLAN).
# 3. Placement AP constraints (blocked when AP=0, negative AP, boundary step-downs).
# 4. Placement resource constraints (partial wood, multi-resource shortage, atomic rollback).
# 5. Re-placement reclamation on cells after building destruction (lethal damage, direct destroy, stale free).
# 6. CoreCampfire lifecycle, game_lost emission, and absolute halting of all future placements.
extends "res://tests/test_base.gd"

## Wood this suite seeds in before_each. It asserts exact balances, so it owns
## its wallet rather than inheriting Config.INITIAL_RESOURCES (production tuning).
const SEED_WOOD: int = 10

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var grid_manager_script: GDScript = null
var build_system_script: GDScript = null
var building_script: GDScript = null
var core_campfire_script: GDScript = null
var wall_script: GDScript = null
var tower_script: GDScript = null

var _cleanup_nodes: Array[Node] = []
var _cleanup_objects: Array[Object] = []

# ==============================================================================
# 1. Lifecycle Hooks
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

	grid_manager_script = _load_script(["res://scripts/core/GridManager.gd"])
	build_system_script = _load_script(["res://scripts/core/BuildSystem.gd"])
	building_script = _load_script(["res://scripts/entities/Building.gd"])
	core_campfire_script = _load_script(["res://scripts/entities/CoreCampfire.gd"])
	wall_script = _load_script(["res://scripts/entities/Wall.gd"])
	tower_script = _load_script(["res://scripts/entities/Tower.gd"])

func before_each() -> void:
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		# reset_game() seeds Config.INITIAL_RESOURCES, which is production tuning.
		# This suite asserts exact balances, so pin its own wallet and stay decoupled
		# from whatever the opening balance happens to be.
		if "current_ap" in game_state_node: game_state_node.current_ap = 3
		if "resources" in game_state_node: game_state_node.resources = {"wood": SEED_WOOD, "stone": 0, "water": 0, "food": 0}
		if "is_game_over" in game_state_node: game_state_node.is_game_over = false
		if "current_phase" in game_state_node: game_state_node.current_phase = 0
	# v0.4 gates the turret behind a blueprint and stone behind a pick. This suite is
	# about something else, so it starts with the cabin's work already done rather
	# than walking that chain in every test.
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
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
				if obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
				obj.free()
			elif obj is RefCounted:
				pass
	_cleanup_objects.clear()

# ==============================================================================
# 2. Helpers & Factory Utilities
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_grid_manager() -> Object:
	assert_not_null(grid_manager_script, "GridManager.gd script must exist")
	if grid_manager_script == null: return null
	var instance = grid_manager_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)
	return instance

func _create_build_system(grid_mgr: Object) -> Object:
	assert_not_null(build_system_script, "BuildSystem.gd script must exist")
	if build_system_script == null: return null
	var instance = build_system_script.new()
	if instance is Node:
		_cleanup_nodes.append(instance)
	else:
		_cleanup_objects.append(instance)

	if "grid_manager" in instance:
		instance.grid_manager = grid_mgr
	elif instance.has_method("setup"):
		instance.call("setup", grid_mgr)
	elif instance.has_method("set_grid_manager"):
		instance.call("set_grid_manager", grid_mgr)
	return instance

func _get_wood() -> int:
	if game_state_node != null and "resources" in game_state_node:
		return game_state_node.resources.get("wood", 0)
	return -1

func _get_stone() -> int:
	if game_state_node != null and "resources" in game_state_node:
		return game_state_node.resources.get("stone", 0)
	return -1

func _get_ap() -> int:
	if game_state_node != null and "current_ap" in game_state_node:
		return game_state_node.current_ap
	return -1

# ==============================================================================
# Category 1: Duplicate Placement Adversarial Challenges
# ==============================================================================

func test_challenge_duplicate_placement_identical_type() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null: return

	var cell = Vector2i(5, 5)
	var b1 = build_sys.place_building("wall", cell)
	if b1 is Node: _cleanup_nodes.append(b1)
	assert_not_null(b1, "Initial wall placement must succeed")
	assert_eq(_get_ap(), 2, "AP decremented to 2 after initial placement")
	assert_eq(_get_wood(), SEED_WOOD - cost_of("wall"), "Wood decremented by the wall cost")

	var watcher = watch_signal(event_bus_node, "building_placed")
	assert_false(build_sys.can_place_building("wall", cell), "can_place_building must return false for occupied cell")

	var b2 = build_sys.place_building("wall", cell)
	if b2 is Node: _cleanup_nodes.append(b2)
	assert_null(b2, "Duplicate placement of same type must return null")
	assert_eq(_get_ap(), 2, "AP must NOT be deducted on duplicate placement attempt")
	assert_eq(_get_wood(), SEED_WOOD - cost_of("wall"), "Wood must NOT be deducted again on duplicate placement")
	assert_false(watcher.emitted, "building_placed signal must NOT be emitted for duplicate attempt")
	assert_eq(grid_mgr.get_building_at(cell), b1, "Cell must retain original building instance")

func test_challenge_duplicate_placement_different_types() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null: return

	var cell = Vector2i(2, 3)
	var initial_wall = build_sys.place_building("wall", cell)
	if initial_wall is Node: _cleanup_nodes.append(initial_wall)
	assert_not_null(initial_wall, "Initial wall placement succeeds")

	var ap_before = _get_ap()
	var wood_before = _get_wood()

	var types_to_test = ["tower", "wall", "core"]
	for t in types_to_test:
		var watcher = watch_signal(event_bus_node, "building_placed")
		assert_false(build_sys.can_place_building(t, cell), "can_place_building for type '%s' on occupied cell must be false" % t)
		var rejected = build_sys.place_building(t, cell)
		if rejected is Node: _cleanup_nodes.append(rejected)
		assert_null(rejected, "place_building for type '%s' on occupied cell must return null" % t)
		assert_eq(_get_ap(), ap_before, "AP unchanged after attempting type '%s'" % t)
		assert_eq(_get_wood(), wood_before, "Wood unchanged after attempting type '%s'" % t)
		assert_false(watcher.emitted, "No building_placed signal emitted for type '%s'" % t)
		watcher.disconnect_watcher()

	assert_eq(grid_mgr.get_building_at(cell), initial_wall, "Cell still holds initial wall")

func test_challenge_duplicate_placement_preoccupied_grid() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var cell = Vector2i(8, 8)
	var manual_blocker = Node3D.new()
	_cleanup_nodes.append(manual_blocker)
	var occupied = grid_mgr.occupy_cell(cell, manual_blocker)
	assert_true(occupied, "Manual occupation of cell succeeds")

	assert_false(build_sys.can_place_building("wall", cell), "BuildSystem must respect manual GridManager occupancy")
	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)
	assert_null(b, "place_building must return null when cell is preoccupied")
	assert_eq(_get_ap(), 3, "AP remains unspent")
	assert_eq(_get_wood(), SEED_WOOD, "Wood remains unspent")

func test_challenge_duplicate_placement_extreme_quadrants() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var test_coords = [
		Vector2i(-999, -999),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(1000, 1000)
	]

	for c in test_coords:
		game_state_node.current_ap = 3
		game_state_node.resources["wood"] = 10

		var b = build_sys.place_building("wall", c)
		if b is Node: _cleanup_nodes.append(b)
		assert_not_null(b, "First placement at %s must succeed" % str(c))

		assert_false(build_sys.can_place_building("wall", c), "can_place_building duplicate at %s rejected" % str(c))
		var b_dup = build_sys.place_building("wall", c)
		if b_dup is Node: _cleanup_nodes.append(b_dup)
		assert_null(b_dup, "Duplicate placement at %s rejected" % str(c))
		assert_eq(grid_mgr.get_building_at(c), b, "Cell %s retains original building" % str(c))

func test_challenge_rapid_duplicate_placement_loop() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var cell = Vector2i(15, 15)
	var successful_count = 0
	var rejected_count = 0

	for i in range(50):
		var b = build_sys.place_building("wall", cell)
		if b != null:
			successful_count += 1
			_cleanup_nodes.append(b)
		else:
			rejected_count += 1

	assert_eq(successful_count, 1, "Exactly 1 placement must succeed in rapid loop on same cell")
	assert_eq(rejected_count, 49, "Exactly 49 duplicate attempts must be rejected")
	assert_eq(_get_ap(), 2, "AP decremented exactly once (3 -> 2)")
	assert_eq(_get_wood(), SEED_WOOD - cost_of("wall"), "Wood decremented exactly once")

# ==============================================================================
# Category 2: Phase Enforcement Challenges (ATTACK, PRODUCE, Invalid Phases)
# ==============================================================================

func test_challenge_placement_blocked_during_attack_phase() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Switch to ATTACK phase
	game_state_node.change_phase(1)
	assert_eq(int(game_state_node.current_phase), 1, "Phase is ATTACK (1)")

	var cell = Vector2i(1, 1)
	var watcher = watch_signal(event_bus_node, "building_placed")

	assert_false(build_sys.can_place_building("wall", cell), "can_place_building must return false during ATTACK phase")
	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_null(b, "place_building must return null during ATTACK phase")
	assert_eq(_get_ap(), 3, "AP must remain unchanged during ATTACK attempt")
	assert_eq(_get_wood(), SEED_WOOD, "Wood must remain unchanged during ATTACK attempt")
	assert_false(watcher.emitted, "No building_placed signal during ATTACK phase")
	assert_false(grid_mgr.is_cell_occupied(cell), "Cell must remain empty")

func test_challenge_placement_blocked_during_produce_phase() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Switch to PRODUCE phase
	game_state_node.change_phase(2)
	assert_eq(int(game_state_node.current_phase), 2, "Phase is PRODUCE (2)")

	var cell = Vector2i(2, 2)
	var watcher = watch_signal(event_bus_node, "building_placed")

	assert_false(build_sys.can_place_building("tower", cell), "can_place_building must return false during PRODUCE phase")
	var b = build_sys.place_building("tower", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_null(b, "place_building must return null during PRODUCE phase")
	assert_eq(_get_ap(), 3, "AP must remain unchanged during PRODUCE attempt")
	assert_eq(_get_wood(), SEED_WOOD, "Wood must remain unchanged during PRODUCE attempt")
	assert_false(watcher.emitted, "No building_placed signal during PRODUCE phase")
	assert_false(grid_mgr.is_cell_occupied(cell), "Cell must remain empty")

func test_challenge_placement_lifecycle_across_turn_cycle() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# 1. PLAN Phase: Building allowed
	assert_eq(int(game_state_node.current_phase), 0, "Initial phase is PLAN")
	var c1 = Vector2i(10, 10)
	var b1 = build_sys.place_building("wall", c1)
	if b1 is Node: _cleanup_nodes.append(b1)
	assert_not_null(b1, "Placement in PLAN phase succeeds")
	assert_eq(_get_ap(), 2, "AP is 2")

	# 2. Advance to ATTACK: Building blocked
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 1, "Phase advanced to ATTACK")
	var c2 = Vector2i(10, 11)
	assert_false(build_sys.can_place_building("wall", c2), "Placement in ATTACK phase blocked")
	var b2 = build_sys.place_building("wall", c2)
	if b2 is Node: _cleanup_nodes.append(b2)
	assert_null(b2, "place_building returns null in ATTACK phase")

	# 3. Advance to PRODUCE: Building blocked
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 2, "Phase advanced to PRODUCE")
	assert_false(build_sys.can_place_building("wall", c2), "Placement in PRODUCE phase blocked")
	var b3 = build_sys.place_building("wall", c2)
	if b3 is Node: _cleanup_nodes.append(b3)
	assert_null(b3, "place_building returns null in PRODUCE phase")

	# 4. Advance back to PLAN: AP resets to max (3), Building allowed again
	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), 0, "Phase advanced back to PLAN")
	assert_eq(_get_ap(), 3, "AP automatically resets to max (3) on returning to PLAN")
	assert_true(build_sys.can_place_building("wall", c2), "Placement in new PLAN phase permitted")
	var b4 = build_sys.place_building("wall", c2)
	if b4 is Node: _cleanup_nodes.append(b4)
	assert_not_null(b4, "Placement succeeds in new PLAN phase")
	assert_eq(_get_ap(), 2, "AP decremented to 2")

func test_challenge_placement_rejected_on_corrupted_phase() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Simulate invalid phase value
	game_state_node.current_phase = 99 as GameState.Phase
	var cell = Vector2i(3, 3)

	assert_false(build_sys.can_place_building("wall", cell), "Corrupted phase 99 must be rejected")
	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)
	assert_null(b, "place_building must return null on corrupted phase")

# ==============================================================================
# Category 3: Placement when AP = 0 and AP Boundaries
# ==============================================================================

func test_challenge_placement_rejected_when_ap_zero() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	game_state_node.current_ap = 0
	var test_types = ["wall", "tower"]

	for i in range(test_types.size()):
		var t = test_types[i]
		var cell = Vector2i(20 + i, 20)
		var watcher = watch_signal(event_bus_node, "building_placed")

		assert_false(build_sys.can_place_building(t, cell), "can_place_building for '%s' when AP=0 must return false" % t)
		var b = build_sys.place_building(t, cell)
		if b is Node: _cleanup_nodes.append(b)

		assert_null(b, "place_building for '%s' when AP=0 must return null" % t)
		assert_eq(_get_ap(), 0, "AP must remain 0")
		assert_eq(_get_wood(), SEED_WOOD, "Wood must remain 10")
		assert_false(watcher.emitted, "building_placed must not emit when AP=0")
		assert_false(grid_mgr.is_cell_occupied(cell), "Cell %s must remain unoccupied" % str(cell))
		watcher.disconnect_watcher()

func test_challenge_placement_negative_ap_rejection() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Corrupted negative AP state
	game_state_node.current_ap = -5
	var cell = Vector2i(30, 30)

	assert_false(build_sys.can_place_building("wall", cell), "Negative AP (-5) must be rejected")
	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)
	assert_null(b, "place_building with negative AP must return null")
	assert_eq(_get_ap(), -5, "AP remains untouched")
	assert_eq(_get_wood(), SEED_WOOD, "Wood remains untouched")

func test_challenge_ap_depletion_boundary_enforcement() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Set AP to exactly 1, Wood to 10
	game_state_node.current_ap = 1
	var cell_success = Vector2i(40, 40)
	var cell_fail = Vector2i(40, 41)

	# 1. First placement consumes last AP
	assert_true(build_sys.can_place_building("wall", cell_success), "Placement with AP=1 should be allowed")
	var b1 = build_sys.place_building("wall", cell_success)
	if b1 is Node: _cleanup_nodes.append(b1)
	assert_not_null(b1, "Placement consumes final 1 AP")
	assert_eq(_get_ap(), 0, "AP reaches 0")

	# 2. Subsequent placements immediately blocked
	assert_false(build_sys.can_place_building("wall", cell_fail), "Immediate subsequent placement blocked with AP=0")
	var b2 = build_sys.place_building("wall", cell_fail)
	if b2 is Node: _cleanup_nodes.append(b2)
	assert_null(b2, "place_building returns null with AP=0")
	assert_eq(_get_ap(), 0, "AP does not go below 0")

# ==============================================================================
# Category 4: Partial Resources & Transaction Atomicity Challenges
# ==============================================================================

func test_challenge_partial_wood_rejection_tower() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Tower costs 4 wood. Test insufficient wood levels: 3, 2, 1, 0
	var wood_levels = [3, 2, 1, 0]
	for idx in range(wood_levels.size()):
		var w = wood_levels[idx]
		game_state_node.resources["wood"] = w
		game_state_node.current_ap = 3
		var cell = Vector2i(50, 50 + idx)

		var watcher = watch_signal(event_bus_node, "building_placed")
		assert_false(build_sys.can_place_building("tower", cell), "Tower requires 4 wood, %d wood must fail validation" % w)
		var b = build_sys.place_building("tower", cell)
		if b is Node: _cleanup_nodes.append(b)

		assert_null(b, "Tower placement with %d wood must return null" % w)
		assert_eq(_get_wood(), w, "Wood remains %d (no partial deduction)" % w)
		assert_eq(_get_ap(), 3, "AP remains 3 (no AP deduction or leak)")
		assert_false(watcher.emitted, "No building_placed signal")
		assert_false(grid_mgr.is_cell_occupied(cell), "Cell %s remains unoccupied" % str(cell))
		watcher.disconnect_watcher()

func test_challenge_multi_resource_partial_affordability() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# The turret is the game's one multi-resource building, so it is the honest
	# fixture for this. Both prices come from Config: a test that restates them
	# stops testing the transaction and starts testing a copy of the price list.
	#
	# It used to use "barracks", a building nobody could ever put up -- it was not in
	# BUILDABLE_TYPES -- so this suite was exercising the transaction against a
	# phantom. The barracks is gone; the turret actually costs wood and stone.
	var wood_price: int = cost_of("tower", "wood")
	var stone_price: int = cost_of("tower", "stone")
	assert_gt(wood_price, 0, "The turret costs wood")
	assert_gt(stone_price, 0, "And stone, which is what makes a multi-resource test possible")
	game_state_node.current_ap = 3

	# Case A: enough wood, one stone short.
	game_state_node.resources = {"wood": wood_price, "stone": stone_price - 1, "food": 0}
	var cell_a = Vector2i(60, 60)

	assert_false(build_sys.can_place_building("tower", cell_a), "One stone short must fail")
	var b_a = build_sys.place_building("tower", cell_a)
	if b_a is Node: _cleanup_nodes.append(b_a)

	assert_null(b_a, "Placement returns null when stone is insufficient")
	assert_eq(_get_wood(), wood_price, "Wood must NOT be partially deducted")
	assert_eq(_get_stone(), stone_price - 1, "Nor stone")
	assert_eq(_get_ap(), 3, "Nor AP")

	# Case B: enough stone, one wood short.
	game_state_node.resources = {"wood": wood_price - 1, "stone": stone_price, "food": 0}
	var cell_b = Vector2i(60, 61)

	assert_false(build_sys.can_place_building("tower", cell_b), "One wood short must fail too")
	var b_b = build_sys.place_building("tower", cell_b)
	if b_b is Node: _cleanup_nodes.append(b_b)

	assert_null(b_b, "Placement returns null when wood is insufficient")
	assert_eq(_get_wood(), wood_price - 1, "Wood untouched")
	assert_eq(_get_stone(), stone_price, "Stone untouched")
	assert_eq(_get_ap(), 3, "AP untouched")

	# Case C: exactly enough of both, which must go through and take all of it.
	game_state_node.resources = {"wood": wood_price, "stone": stone_price, "food": 0}
	assert_true(build_sys.can_place_building("tower", cell_b), "Exactly the price must pass")
	var b_c = build_sys.place_building("tower", cell_b)
	if b_c is Node: _cleanup_nodes.append(b_c)

	assert_not_null(b_c, "Placement with exactly the price succeeds")
	assert_eq(_get_wood(), 0, "Wood spent to the last unit")
	assert_eq(_get_stone(), 0, "And stone with it")
	assert_eq(_get_ap(), 2, "AP decremented (3 -> 2)")

func test_challenge_missing_resource_keys_handled_safely() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# GameState resources dictionary missing key "stone" completely
	game_state_node.resources = {"wood": 20} # No stone key
	game_state_node.current_ap = 3
	var cell = Vector2i(65, 65)

	# The turret requires stone. Must return false safely without crashing.
	assert_false(build_sys.can_place_building("tower", cell), "Missing resource key in inventory safely rejected")
	var b = build_sys.place_building("tower", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_null(b, "Placement safely returns null when resource key is missing")
	assert_eq(_get_wood(), 20, "Wood remains untouched")
	assert_eq(_get_ap(), 3, "AP remains untouched")

# ==============================================================================
# Category 5: Re-placement on Vacated Cells (Lifecycle & Reclamation)
# ==============================================================================

func test_challenge_replacement_after_lethal_damage() -> void:
	# Budget generously so this test exercises placement, not affordability.
	if game_state_node: game_state_node.resources = {"wood": 9999, "stone": 9999, "water": 9999, "food": 0}
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null: return

	var cell = Vector2i(70, 70)
	var destroyed_watcher = watch_signal(event_bus_node, "building_destroyed")

	# 1. Place initial Wall
	var wall = build_sys.place_building("wall", cell)
	if wall is Node: _cleanup_nodes.append(wall)
	assert_not_null(wall, "Initial wall placement succeeds")
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell is occupied by wall")

	# 2. Destroy Wall via lethal damage
	assert_has_method(wall, "take_damage", "Wall must have take_damage method")
	wall.take_damage(30.0)
	assert_true(destroyed_watcher.emitted, "building_destroyed emitted on lethal damage")
	assert_false(grid_mgr.is_cell_occupied(cell), "GridManager auto-vacated cell on building_destroyed")

	# 3. Re-place a Tower on the same cell
	game_state_node.current_ap = 3
	game_state_node.resources["wood"] = 9999 # ample under any balance

	assert_true(build_sys.can_place_building("tower", cell), "can_place_building returns true on vacated cell")
	var tower = build_sys.place_building("tower", cell)
	if tower is Node: _cleanup_nodes.append(tower)

	assert_not_null(tower, "Re-placement of Tower on reclaimed cell succeeds")
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell is now occupied by new Tower")
	assert_eq(grid_mgr.get_building_at(cell), tower, "GridManager returns new Tower instance")
	assert_ne(tower, wall, "New building is a distinct instance from destroyed wall")

func test_challenge_rapid_destroy_rebuild_multitype_stress() -> void:
	# Budget generously so this test exercises placement, not affordability.
	if game_state_node: game_state_node.resources = {"wood": 9999, "stone": 9999, "water": 9999, "food": 0}
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var cell = Vector2i(75, 75)
	var sequence = ["wall", "tower", "wall", "tower", "wall", "tower", "wall", "tower"]

	for idx in range(sequence.size()):
		var b_type = sequence[idx]
		# Ensure sufficient AP and wood for each cycle
		game_state_node.current_ap = 3
		game_state_node.resources["wood"] = 9999 # ample under any balance

		assert_true(build_sys.can_place_building(b_type, cell), "Cycle %d: cell %s must be eligible for %s" % [idx, str(cell), b_type])
		var b = build_sys.place_building(b_type, cell)
		if b is Node: _cleanup_nodes.append(b)

		assert_not_null(b, "Cycle %d: placement of %s succeeded" % [idx, b_type])
		assert_true(grid_mgr.is_cell_occupied(cell), "Cycle %d: cell marked occupied" % idx)

		# Destroy building
		if b.has_method("destroy"):
			b.destroy()
		elif b.has_method("take_damage"):
			b.take_damage(100.0)

		assert_false(grid_mgr.is_cell_occupied(cell), "Cycle %d: cell vacated immediately after destruction" % idx)

func test_challenge_replacement_after_direct_destroy_call() -> void:
	# Budget generously so this test exercises placement, not affordability.
	if game_state_node: game_state_node.resources = {"wood": 9999, "stone": 9999, "water": 9999, "food": 0}
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var cell = Vector2i(78, 78)
	var b1 = build_sys.place_building("tower", cell)
	if b1 is Node: _cleanup_nodes.append(b1)
	assert_not_null(b1, "LumberHut placed")

	# Direct call to destroy() without damage
	b1.destroy()
	assert_false(grid_mgr.is_cell_occupied(cell), "Direct destroy() vacates cell")

	# Re-place Wall
	game_state_node.current_ap = 3
	game_state_node.resources["wood"] = 10
	var b2 = build_sys.place_building("wall", cell)
	if b2 is Node: _cleanup_nodes.append(b2)
	assert_not_null(b2, "Wall successfully replaces destroyed LumberHut")

func test_challenge_replacement_after_stale_free() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var cell = Vector2i(79, 79)
	var stale_node = Node3D.new()
	grid_mgr.occupy_cell(cell, stale_node)
	assert_true(grid_mgr.is_cell_occupied(cell), "Cell occupied by manual node")

	# Free node directly without calling destroy() or emitting signal
	stale_node.free()

	# is_cell_occupied self-heals and frees cell
	assert_false(grid_mgr.is_cell_occupied(cell), "is_cell_occupied self-heals on freed node")
	assert_true(build_sys.can_place_building("wall", cell), "Vacated cell can now be built on")

	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)
	assert_not_null(b, "Building placed on self-healed cell")
	assert_eq(grid_mgr.get_building_at(cell), b, "GridManager now tracks new building")

# ==============================================================================
# Category 6: CoreCampfire Lifecycle & Game Lost Halting Challenges
# ==============================================================================

func test_challenge_campfire_partial_damage_allows_placements() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or core_campfire_script == null or event_bus_node == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)
	var origin = Vector2i(0, 0)
	grid_mgr.occupy_cell(origin, core)

	var hp_watcher = watch_signal(event_bus_node, "core_hp_changed")
	var lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Take 9.0 damage (out of 10.0 max_hp) -> 1.0 HP remaining
	core.take_damage(9.0)
	assert_almost_eq(float(core.current_hp), 1.0, 0.01, "Core HP reduced to 1.0")
	assert_true(hp_watcher.emitted, "core_hp_changed emitted on partial damage")
	assert_false(lost_watcher.emitted, "game_lost must NOT be emitted on non-lethal damage")
	assert_false(game_state_node.is_game_over, "is_game_over remains false on partial damage")

	# Verify placements on other cells still work normally
	var cell_other = Vector2i(1, 1)
	assert_true(build_sys.can_place_building("wall", cell_other), "Placement permitted while Core is still alive")
	var wall = build_sys.place_building("wall", cell_other)
	if wall is Node: _cleanup_nodes.append(wall)
	assert_not_null(wall, "Wall placed successfully on adjacent cell while core damaged")

func test_challenge_campfire_destruction_emits_game_lost_and_halts_all_placements() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or core_campfire_script == null or event_bus_node == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)
	var origin = Vector2i(0, 0)
	grid_mgr.occupy_cell(origin, core)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")
	var hp_watcher = watch_signal(event_bus_node, "core_hp_changed")
	var destroyed_watcher = watch_signal(event_bus_node, "building_destroyed")

	# 1. Deal lethal damage to CoreCampfire
	core.take_damage(10.0)
	assert_lte(float(core.current_hp), 0.0, "Core HP reduced to 0")
	assert_true(destroyed_watcher.emitted, "building_destroyed emitted for Core")
	assert_true(lost_watcher.emitted, "game_lost emitted on CoreCampfire destruction")
	assert_true(game_state_node.is_game_over, "GameState.is_game_over transitioned to true")

	# 2. Assert ALL subsequent placement attempts across all types and cells are strictly rejected
	var test_attempts = [
		{"type": "wall", "cell": Vector2i(1, 1)},
		{"type": "tower", "cell": Vector2i(2, 2)},
		{"type": "tower", "cell": Vector2i(3, 3)},
		{"type": "core", "cell": Vector2i(4, 4)},
		{"type": "wall", "cell": Vector2i(0, 0)}
	]

	for attempt in test_attempts:
		var t: String = attempt["type"]
		var c: Vector2i = attempt["cell"]
		var place_watcher = watch_signal(event_bus_node, "building_placed")

		assert_false(build_sys.can_place_building(t, c), "Placement of '%s' at %s must be blocked after game_lost" % [t, str(c)])
		var b = build_sys.place_building(t, c)
		if b is Node: _cleanup_nodes.append(b)

		assert_null(b, "place_building for '%s' after game_lost must return null" % t)
		assert_false(place_watcher.emitted, "building_placed must not emit after game_lost")
		assert_false(grid_mgr.is_cell_occupied(c), "Cell %s must not be occupied" % str(c))
		place_watcher.disconnect_watcher()

	# Assert AP and resources remained untouched despite attempted placements
	assert_eq(_get_ap(), 3, "AP remains unspent after game_lost")
	assert_eq(_get_wood(), SEED_WOOD, "Wood remains unspent after game_lost")

func test_challenge_game_over_state_blocks_placement_even_with_excess_resources() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# Artificially set game over
	game_state_node.is_game_over = true
	game_state_node.current_ap = 99
	game_state_node.resources = {"wood": 9999, "stone": 9999, "food": 9999}

	var cell = Vector2i(88, 88)
	assert_false(build_sys.can_place_building("wall", cell), "Game over must unconditionally block can_place_building")
	var b = build_sys.place_building("wall", cell)
	if b is Node: _cleanup_nodes.append(b)

	assert_null(b, "Game over must unconditionally block place_building")
	assert_eq(_get_ap(), 99, "AP invariant")
	assert_eq(_get_wood(), 9999, "Wood invariant")

func test_challenge_cannot_overwrite_living_core_campfire() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or core_campfire_script == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)
	var origin = Vector2i(0, 0)
	grid_mgr.occupy_cell(origin, core)

	var place_types = ["wall", "tower", "core"]
	for t in place_types:
		assert_false(build_sys.can_place_building(t, origin), "Cannot place '%s' over living CoreCampfire at (0,0)" % t)
		var b = build_sys.place_building(t, origin)
		if b is Node: _cleanup_nodes.append(b)
		assert_null(b, "place_building for '%s' over living core returns null" % t)

	assert_almost_eq(float(core.current_hp), 10.0, 0.01, "CoreCampfire suffered no damage from overwrite attempts")
	assert_eq(grid_mgr.get_building_at(origin), core, "CoreCampfire remains safely at (0,0)")

func test_challenge_core_campfire_double_destroy_idempotency() -> void:
	assert_not_null(core_campfire_script, "CoreCampfire.gd script must exist")
	if core_campfire_script == null or event_bus_node == null: return

	var core = core_campfire_script.new()
	_cleanup_nodes.append(core)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")

	# First lethal damage
	core.take_damage(10.0)
	assert_true(lost_watcher.emitted, "game_lost emitted on first fatal damage")
	assert_eq(lost_watcher.emit_count, 1, "game_lost emitted exactly once")

	# Attempt second damage / destroy call
	core.take_damage(10.0)
	core.destroy()
	assert_eq(lost_watcher.emit_count, 1, "game_lost MUST NOT be emitted a second time (idempotent)")

func test_challenge_replacement_immediately_after_queue_free_same_frame() -> void:
	# Budget generously so this test exercises placement, not affordability.
	if game_state_node: game_state_node.resources = {"wood": 9999, "stone": 9999, "water": 9999, "food": 0}
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null: return

	var cell = Vector2i(80, 80)
	var b1 = build_sys.place_building("wall", cell)
	if b1 is Node: _cleanup_nodes.append(b1)
	assert_not_null(b1, "Initial wall placed")

	# Call queue_free directly without destroy()
	b1.queue_free()

	# GridManager.is_cell_occupied must recognize is_queued_for_deletion and allow immediate placement
	assert_false(grid_mgr.is_cell_occupied(cell), "Cell vacated immediately upon queue_free in same frame")
	assert_true(build_sys.can_place_building("tower", cell), "Immediate re-placement permitted in same frame")

	game_state_node.current_ap = 3
	game_state_node.resources["wood"] = 9999 # ample under any balance
	var b2 = build_sys.place_building("tower", cell)
	if b2 is Node: _cleanup_nodes.append(b2)
	assert_not_null(b2, "New tower successfully placed over queued-for-deletion cell")
	assert_eq(grid_mgr.get_building_at(cell), b2, "GridManager now tracks new tower")

func test_challenge_rapid_failed_placements_resource_non_leak() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# One wood short of a wall, so every placement below must be rejected.
	var broke: int = maxi(0, cost_of("wall") - 1)
	game_state_node.resources["wood"] = broke
	game_state_node.current_ap = 3

	for i in range(100):
		var dummy_cell = Vector2i(100 + i, 100)
		var b = build_sys.place_building("wall", dummy_cell)
		if b is Node: _cleanup_nodes.append(b)

	assert_eq(_get_wood(), broke, "Wood must be untouched after 100 failed placements (no drift/leak)")
	assert_eq(_get_ap(), 3, "AP must remain exactly 3 after 100 failed placements (no drift/leak)")

func test_challenge_zero_ap_cost_core_placement_boundary() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or game_state_node == null: return

	# When AP = 0, core (ap_cost = 0, cost = {}) can be placed if cell empty
	game_state_node.current_ap = 0
	var core_cell = Vector2i(90, 90)

	assert_true(build_sys.can_place_building("core", core_cell), "Core with 0 AP cost can be placed when AP=0")
	var core = build_sys.place_building("core", core_cell)
	if core is Node: _cleanup_nodes.append(core)

	assert_not_null(core, "Core successfully placed with 0 AP")
	assert_eq(_get_ap(), 0, "AP remains 0")
	assert_true(grid_mgr.is_cell_occupied(core_cell), "Cell occupied by placed core")

	# Normal buildings with ap_cost = 1 must still be blocked
	var wall_cell = Vector2i(90, 91)
	assert_false(build_sys.can_place_building("wall", wall_cell), "Wall with 1 AP cost blocked when AP=0")
	var wall = build_sys.place_building("wall", wall_cell)
	if wall is Node: _cleanup_nodes.append(wall)
	assert_null(wall, "Wall placement fails with 0 AP")

func test_challenge_failed_placement_signal_suppression() -> void:
	var grid_mgr = _create_grid_manager()
	var build_sys = _create_build_system(grid_mgr)
	if grid_mgr == null or build_sys == null or event_bus_node == null or game_state_node == null: return

	var placed_watcher = watch_signal(event_bus_node, "building_placed")
	var ap_watcher = watch_signal(event_bus_node, "ap_changed")
	var res_watcher = watch_signal(event_bus_node, "resources_changed")

	# Drain wood to 0
	game_state_node.resources["wood"] = 0

	var rejected = build_sys.place_building("wall", Vector2i(95, 95))
	if rejected is Node: _cleanup_nodes.append(rejected)

	assert_null(rejected, "Placement rejected")
	assert_false(placed_watcher.emitted, "building_placed MUST NOT emit on rejected placement")
	assert_false(ap_watcher.emitted, "ap_changed MUST NOT emit on rejected placement")
	assert_false(res_watcher.emitted, "resources_changed MUST NOT emit on rejected placement")

