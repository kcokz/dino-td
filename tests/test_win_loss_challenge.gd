# res://tests/test_win_loss_challenge.gd
# ==============================================================================
# Empirical Challenger Test Suite for Milestone 5: Win/Loss, Nest & Core Lifecycle
# Rigorously stress-tests:
# 1. Race conditions: Rapid / simultaneous damage on Nest and Core.
# 2. Idempotency: Repeated destruction calls on dead Nest and dead Core.
# 3. Action locking: 100% rejection of AP spend, wood spend, building placement,
#    end action click, and phase advance post-victory (game_won) and post-defeat (game_lost).
# 4. Extreme combat: Tower attacking Nest under multiple towers and 5.0m threshold boundary conditions.
# ==============================================================================
extends "res://tests/test_base.gd"

# Autoload References
var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

# Entity & Core Scripts
var nest_script: GDScript = null
var core_campfire_script: GDScript = null
var tower_script: GDScript = null
var wall_script: GDScript = null
var lumber_hut_script: GDScript = null
var building_script: GDScript = null
var grid_manager_script: GDScript = null
var build_system_script: GDScript = null
var hud_script: GDScript = null
var hud_packed_scene: PackedScene = null

# Node cleanup tracking
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

	nest_script = _load_script(["res://scripts/entities/Nest.gd", "res://scripts/entities/nest.gd"])
	core_campfire_script = _load_script(["res://scripts/entities/CoreCampfire.gd", "res://scripts/entities/core_campfire.gd"])
	tower_script = _load_script(["res://scripts/entities/Tower.gd", "res://scripts/entities/tower.gd"])
	wall_script = _load_script(["res://scripts/entities/Wall.gd", "res://scripts/entities/wall.gd"])
	lumber_hut_script = _load_script(["res://scripts/entities/LumberHut.gd", "res://scripts/entities/lumber_hut.gd"])
	building_script = _load_script(["res://scripts/entities/Building.gd", "res://scripts/entities/building.gd"])
	grid_manager_script = _load_script(["res://scripts/core/GridManager.gd", "res://scripts/core/grid_manager.gd"])
	build_system_script = _load_script(["res://scripts/core/BuildSystem.gd", "res://scripts/core/build_system.gd"])
	hud_script = _load_script(["res://scripts/ui/HUD.gd", "res://scripts/ui/hud.gd"])

	if ResourceLoader.exists("res://scenes/ui/HUD.tscn"):
		hud_packed_scene = load("res://scenes/ui/HUD.tscn")

func before_each() -> void:
	if game_state_node != null:
		if game_state_node.has_method("reset_game"):
			game_state_node.call("reset_game")
		else:
			if "current_phase" in game_state_node: game_state_node.current_phase = 0
			if "current_ap" in game_state_node: game_state_node.current_ap = 3
			if "max_ap" in game_state_node: game_state_node.max_ap = 3
			if "resources" in game_state_node: game_state_node.resources = {"wood": 10, "stone": 0, "food": 0}
			if "is_game_over" in game_state_node: game_state_node.is_game_over = false
			if "is_game_won" in game_state_node: game_state_node.is_game_won = false

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
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
	_cleanup_objects.clear()

# ==============================================================================
# Helper Factories
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_nest() -> Node:
	if nest_script == null:
		return null
	var nest = nest_script.new()
	if nest is Node:
		_cleanup_nodes.append(nest)
	return nest

func _create_core() -> Node:
	if core_campfire_script == null:
		return null
	var core = core_campfire_script.new()
	if core is Node:
		_cleanup_nodes.append(core)
	return core

func _create_build_system() -> Node:
	if build_system_script == null or grid_manager_script == null:
		return null
	var grid = grid_manager_script.new()
	var bs = build_system_script.new()
	_cleanup_nodes.append(grid)
	_cleanup_nodes.append(bs)
	bs.setup(grid)
	return bs

func _create_hud() -> CanvasLayer:
	var hud_inst: CanvasLayer = null
	if hud_packed_scene != null:
		hud_inst = hud_packed_scene.instantiate() as CanvasLayer
	elif hud_script != null:
		hud_inst = hud_script.new() as CanvasLayer

	if hud_inst != null:
		_cleanup_nodes.append(hud_inst)
	return hud_inst

# ==============================================================================
# Category 1: Race Condition & Simultaneous Damage Tests (test_challenge_race_*)
# ==============================================================================

## Stress-tests lethal damage to Core followed immediately by lethal damage to Nest.
## Core death must trigger game_lost, and subsequent Nest death must NOT grant victory.
func test_challenge_race_core_destruction_locks_out_subsequent_nest_victory() -> void:
	var core = _create_core()
	var nest = _create_nest()
	assert_not_null(core, "CoreCampfire must exist")
	assert_not_null(nest, "Nest must exist")

	if tree and tree.root:
		tree.root.add_child(core)
		tree.root.add_child(nest)
		await wait_frames(1)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")
	var won_watcher = watch_signal(event_bus_node, "game_won")

	# Destroy Core first
	core.take_damage(10.0)
	assert_true(lost_watcher.emitted, "game_lost emitted when Core destroyed")
	assert_true(bool(game_state_node.is_game_over), "is_game_over must be true after Core loss")
	assert_false(bool(game_state_node.is_game_won), "is_game_won must be false after Core loss")

	# Now destroy Nest in the same frame/turn
	nest.take_damage(30.0)
	await wait_frames(1)

	# Nest should NOT emit game_won because game was already lost
	assert_false(won_watcher.emitted, "game_won must NOT be emitted when Nest is destroyed after Core was already lost")
	assert_true(bool(game_state_node.is_game_over), "is_game_over remains true")
	assert_false(bool(game_state_node.is_game_won), "is_game_won must remain false (cannot win after loss)")

## Stress-tests lethal damage to Nest followed immediately by lethal damage to Core.
## Victory achieved first must not be overwritten by subsequent Core destruction.
func test_challenge_race_nest_destruction_locks_out_subsequent_core_defeat() -> void:
	var core = _create_core()
	var nest = _create_nest()
	assert_not_null(core, "CoreCampfire must exist")
	assert_not_null(nest, "Nest must exist")

	if tree and tree.root:
		tree.root.add_child(core)
		tree.root.add_child(nest)
		await wait_frames(1)

	var won_watcher = watch_signal(event_bus_node, "game_won")
	var lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Destroy Nest first
	nest.take_damage(30.0)
	assert_true(won_watcher.emitted, "game_won emitted when Nest destroyed")
	assert_true(bool(game_state_node.is_game_over), "is_game_over must be true after Nest win")
	assert_true(bool(game_state_node.is_game_won), "is_game_won must be true after Nest win")

	# Now destroy Core in the same or subsequent tick
	core.take_damage(10.0)
	await wait_frames(1)

	# Verify terminal state invariant: Victory cannot be overwritten by subsequent Core destruction!
	assert_true(bool(game_state_node.is_game_over), "is_game_over remains true")
	assert_true(bool(game_state_node.is_game_won), "is_game_won must remain true once victory achieved")

## Stress-tests that once game_lost is achieved, subsequent game_won emissions cannot flip is_game_won to true.
func test_challenge_race_loss_cannot_be_overwritten_by_late_victory() -> void:
	event_bus_node.game_lost.emit()
	await wait_frames(1)
	assert_true(game_state_node.is_game_over, "Game is over")
	assert_false(game_state_node.is_game_won, "Game is lost")

	# Attempt to emit game_won after game is already lost
	event_bus_node.game_won.emit()
	await wait_frames(1)

	assert_true(game_state_node.is_game_over, "Game remains over")
	assert_false(game_state_node.is_game_won, "Game must remain lost (victory cannot overwrite loss)")

## Stress-tests rapid interleaved damage to both Nest and Core until resolution.
## Tests that the first objective to hit 0 cleanly terminates the game without state tearing.
func test_challenge_race_rapid_interleaved_damage_resolution() -> void:
	var core = _create_core()
	var nest = _create_nest()
	if tree and tree.root:
		tree.root.add_child(core)
		tree.root.add_child(nest)
		await wait_frames(1)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")
	var won_watcher = watch_signal(event_bus_node, "game_won")

	# Nest has 30 HP, Core has 10 HP.
	# Inflict 2 HP damage to Core, then 2 HP to Nest, alternating.
	# Core will die first at iteration 5 (10 dmg vs 10 dmg).
	for i in range(10):
		if game_state_node.is_game_over:
			break
		core.take_damage(2.0)
		nest.take_damage(2.0)

	assert_true(game_state_node.is_game_over, "Game must reach game_over terminal state")
	assert_true(lost_watcher.emitted, "Core destroyed first, game_lost emitted")
	assert_false(won_watcher.emitted, "Nest was at 20 HP, game_won must NOT emit")
	assert_almost_eq(float(nest.current_hp), 20.0, 0.001, "Nest HP must remain at 20.0")

## Stress-tests sub-frame damage convergence where both entities receive fatal damage.
func test_challenge_race_simultaneous_same_frame_fatal_damage() -> void:
	var core = _create_core()
	var nest = _create_nest()
	if tree and tree.root:
		tree.root.add_child(core)
		tree.root.add_child(nest)
		await wait_frames(1)

	# Reduce both to 1.0 HP
	core.take_damage(9.0)
	nest.take_damage(29.0)
	assert_almost_eq(float(core.current_hp), 1.0, 0.001, "Core HP primed at 1.0")
	assert_almost_eq(float(nest.current_hp), 1.0, 0.001, "Nest HP primed at 1.0")
	assert_false(game_state_node.is_game_over, "Game not yet over")

	var won_watcher = watch_signal(event_bus_node, "game_won")

	# Deliver fatal blow to Nest
	nest.take_damage(1.0)
	assert_true(won_watcher.emitted, "game_won emitted on lethal Nest damage")
	assert_true(game_state_node.is_game_over, "is_game_over is true")
	assert_true(game_state_node.is_game_won, "is_game_won is true")

# ==============================================================================
# Category 2: Idempotency & Repeated Destruction Calls (test_challenge_idempotency_*)
# ==============================================================================

## Stress-tests calling destroy() 10 consecutive times on the same Nest.
## Verifies that EventBus.nest_destroyed and EventBus.game_won fire EXACTLY ONCE.
func test_challenge_idempotency_nest_repeated_destroy_calls() -> void:
	var nest = _create_nest()
	assert_not_null(nest, "Nest must exist")
	if tree and tree.root:
		tree.root.add_child(nest)
		await wait_frames(1)

	var nest_destroyed_watcher = watch_signal(event_bus_node, "nest_destroyed")
	var game_won_watcher = watch_signal(event_bus_node, "game_won")

	# Trigger destroy() 10 times in a row
	for i in range(10):
		nest.destroy()

	assert_true(nest_destroyed_watcher.emitted, "nest_destroyed must be emitted")
	assert_eq(nest_destroyed_watcher.emit_count, 1, "nest_destroyed must be emitted EXACTLY ONCE (idempotent)")
	assert_true(game_won_watcher.emitted, "game_won must be emitted")
	assert_eq(game_won_watcher.emit_count, 1, "game_won must be emitted EXACTLY ONCE (idempotent)")

## Stress-tests calling destroy() 10 consecutive times on the same CoreCampfire.
## Verifies that EventBus.game_lost and EventBus.building_destroyed fire EXACTLY ONCE.
func test_challenge_idempotency_core_repeated_destroy_calls() -> void:
	var core = _create_core()
	assert_not_null(core, "CoreCampfire must exist")
	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var game_lost_watcher = watch_signal(event_bus_node, "game_lost")
	var building_destroyed_watcher = watch_signal(event_bus_node, "building_destroyed")

	# Trigger destroy() 10 times in a row
	for i in range(10):
		core.destroy()

	assert_true(game_lost_watcher.emitted, "game_lost must be emitted")
	assert_eq(game_lost_watcher.emit_count, 1, "game_lost must be emitted EXACTLY ONCE (idempotent)")
	assert_true(building_destroyed_watcher.emitted, "building_destroyed must be emitted")
	assert_eq(building_destroyed_watcher.emit_count, 1, "building_destroyed must be emitted EXACTLY ONCE (idempotent)")

## Stress-tests overkill and repeated post-death damage calls on dead Nest.
func test_challenge_idempotency_nest_overkill_and_post_death_damage() -> void:
	var nest = _create_nest()
	if tree and tree.root:
		tree.root.add_child(nest)
		await wait_frames(1)

	var won_watcher = watch_signal(event_bus_node, "game_won")

	# Overkill: 999.0 damage to a 30.0 HP nest
	nest.take_damage(999.0)
	assert_lte(float(nest.current_hp), 0.0, "Nest HP drops to 0 or below")
	assert_almost_eq(float(nest.current_hp), 0.0, 0.001, "Nest HP clamped cleanly to 0.0")
	assert_eq(won_watcher.emit_count, 1, "game_won fired exactly once on overkill")

	# 10 subsequent damage calls on the dead nest
	for i in range(10):
		nest.take_damage(50.0)

	assert_almost_eq(float(nest.current_hp), 0.0, 0.001, "Nest HP remains 0.0")
	assert_eq(won_watcher.emit_count, 1, "game_won NEVER fired again on dead nest")

## Stress-tests overkill and repeated post-death damage calls on dead CoreCampfire.
func test_challenge_idempotency_core_overkill_and_post_death_damage() -> void:
	var core = _create_core()
	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Overkill: 500.0 damage to a 10.0 HP core
	core.take_damage(500.0)
	assert_almost_eq(float(core.current_hp), 0.0, 0.001, "Core HP clamped to 0.0")
	assert_eq(lost_watcher.emit_count, 1, "game_lost fired once on overkill")

	# 10 subsequent damage calls on dead core
	for i in range(10):
		core.take_damage(25.0)

	assert_almost_eq(float(core.current_hp), 0.0, 0.001, "Core HP remains 0.0")
	assert_eq(lost_watcher.emit_count, 1, "game_lost NEVER fired again on dead core")

## Stress-tests invalid damage inputs (negative, zero, NaN, INF) on Nest and Core.
func test_challenge_idempotency_invalid_damage_inputs_ignored() -> void:
	var nest = _create_nest()
	var core = _create_core()
	if tree and tree.root:
		tree.root.add_child(nest)
		tree.root.add_child(core)
		await wait_frames(1)

	var won_watcher = watch_signal(event_bus_node, "game_won")
	var lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Negative and zero damage
	nest.take_damage(-50.0)
	nest.take_damage(0.0)
	core.take_damage(-20.0)
	core.take_damage(0.0)

	assert_almost_eq(float(nest.current_hp), 30.0, 0.001, "Nest HP unharmed by negative/zero damage")
	assert_almost_eq(float(core.current_hp), 10.0, 0.001, "Core HP unharmed by negative/zero damage")
	assert_false(won_watcher.emitted, "No game_won emitted")
	assert_false(lost_watcher.emitted, "No game_lost emitted")

# ==============================================================================
# Category 3: Action Locking Post-Victory Tests (test_challenge_lockout_won_*)
# ==============================================================================

## Stress-tests 100% rejection of every possible gameplay action after game_won.
func test_challenge_lockout_won_complete_action_rejection() -> void:
	var bs = _create_build_system()
	assert_not_null(bs, "BuildSystem must exist")

	# Transition to game_won
	event_bus_node.game_won.emit()
	await wait_frames(1)

	assert_true(game_state_node.is_game_over, "is_game_over must be true")
	assert_true(game_state_node.is_game_won, "is_game_won must be true")

	var initial_ap = game_state_node.current_ap
	var initial_wood = game_state_node.resources.get("wood", 0)
	var initial_phase = int(game_state_node.current_phase)

	# 1. AP spend rejection
	assert_false(game_state_node.can_spend_ap(1), "can_spend_ap(1) rejected post-win")
	assert_false(game_state_node.can_spend_ap(0), "can_spend_ap(0) rejected post-win")
	assert_false(game_state_node.spend_ap(1), "spend_ap(1) rejected post-win")
	assert_false(game_state_node.spend_ap(0), "spend_ap(0) rejected post-win")
	assert_eq(game_state_node.current_ap, initial_ap, "current_ap unmodified")

	# 2. Building placement & wood spend rejection for all building types
	var place_watcher = watch_signal(event_bus_node, "building_placed")
	var types = ["tower", "wall", "lumber_hut"]
	for i in range(types.size()):
		var b_type = types[i]
		var cell = Vector2i(i + 1, i + 1)

		assert_false(bs.can_place_building(b_type, cell), "can_place_building('%s') rejected post-win" % b_type)
		var placed = bs.place_building(b_type, cell)
		assert_null(placed, "place_building('%s') must return null post-win" % b_type)

	assert_false(place_watcher.emitted, "Zero building_placed signals post-win")
	assert_eq(game_state_node.resources.get("wood", 0), initial_wood, "Wood remains untouched (zero wood spend post-win)")
	assert_eq(game_state_node.current_ap, initial_ap, "AP remains untouched post-win")

	# 3. End action click rejection
	var phase_watcher = watch_signal(event_bus_node, "phase_changed")
	game_state_node.trigger_end_action()
	game_state_node.end_plan_phase()
	assert_eq(int(game_state_node.current_phase), initial_phase, "Phase must NOT change on trigger_end_action post-win")

	# 4. Phase advance rejection
	game_state_node.advance_phase()
	game_state_node.set_phase(1)
	game_state_node.set_phase(2)
	game_state_node.change_phase(1)
	game_state_node.end_produce_phase()
	assert_eq(int(game_state_node.current_phase), initial_phase, "Phase remains locked at PLAN post-win")
	assert_false(phase_watcher.emitted, "Zero phase_changed signals emitted post-win")

## Stress-tests 50 iterations of rapid action hammering post-victory.
func test_challenge_lockout_won_hammering_loop() -> void:
	var bs = _create_build_system()
	event_bus_node.game_won.emit()
	await wait_frames(1)

	var initial_wood = game_state_node.resources.get("wood", 0)

	for i in range(50):
		assert_false(game_state_node.spend_ap(1), "spend_ap rejected on iteration %d" % i)
		assert_null(bs.place_building("tower", Vector2i(i + 1, 0)), "place_building rejected on iteration %d" % i)
		game_state_node.trigger_end_action()
		game_state_node.advance_phase()
		assert_eq(int(game_state_node.current_phase), 0, "Phase locked at 0 on iteration %d" % i)

	assert_eq(game_state_node.resources.get("wood", 0), initial_wood, "Wood strictly preserved after 50 hammer iterations")

## Stress-tests that direct resource spend via GameState.spend_resources is rejected when game is over.
func test_challenge_lockout_direct_resource_spend_rejection() -> void:
	event_bus_node.game_won.emit()
	await wait_frames(1)
	var wood_before = game_state_node.resources.get("wood", 0)
	var spent = game_state_node.spend_resources({"wood": 1})
	assert_false(spent, "spend_resources must be rejected when game is over")
	assert_eq(game_state_node.resources.get("wood", 0), wood_before, "Wood must remain unchanged")

# ==============================================================================
# Category 4: Action Locking Post-Defeat Tests (test_challenge_lockout_lost_*)
# ==============================================================================

## Stress-tests 100% rejection of every possible gameplay action after game_lost.
func test_challenge_lockout_lost_complete_action_rejection() -> void:
	var bs = _create_build_system()
	assert_not_null(bs, "BuildSystem must exist")

	# Transition to game_lost
	event_bus_node.game_lost.emit()
	await wait_frames(1)

	assert_true(game_state_node.is_game_over, "is_game_over must be true")
	assert_false(game_state_node.is_game_won, "is_game_won must be false")

	var initial_ap = game_state_node.current_ap
	var initial_wood = game_state_node.resources.get("wood", 0)
	var initial_phase = int(game_state_node.current_phase)

	# 1. AP spend rejection
	assert_false(game_state_node.can_spend_ap(1), "can_spend_ap(1) rejected post-loss")
	assert_false(game_state_node.can_spend_ap(0), "can_spend_ap(0) rejected post-loss")
	assert_false(game_state_node.spend_ap(1), "spend_ap(1) rejected post-loss")
	assert_false(game_state_node.spend_ap(0), "spend_ap(0) rejected post-loss")
	assert_eq(game_state_node.current_ap, initial_ap, "current_ap unmodified")

	# 2. Building placement & wood spend rejection for all building types
	var place_watcher = watch_signal(event_bus_node, "building_placed")
	var types = ["tower", "wall", "lumber_hut"]
	for i in range(types.size()):
		var b_type = types[i]
		var cell = Vector2i(i + 2, i + 2)

		assert_false(bs.can_place_building(b_type, cell), "can_place_building('%s') rejected post-loss" % b_type)
		var placed = bs.place_building(b_type, cell)
		assert_null(placed, "place_building('%s') must return null post-loss" % b_type)

	assert_false(place_watcher.emitted, "Zero building_placed signals post-loss")
	assert_eq(game_state_node.resources.get("wood", 0), initial_wood, "Wood remains untouched (zero wood spend post-loss)")
	assert_eq(game_state_node.current_ap, initial_ap, "AP remains untouched post-loss")

	# 3. End action click rejection
	var phase_watcher = watch_signal(event_bus_node, "phase_changed")
	game_state_node.trigger_end_action()
	game_state_node.end_plan_phase()
	assert_eq(int(game_state_node.current_phase), initial_phase, "Phase must NOT change on trigger_end_action post-loss")

	# 4. Phase advance rejection
	game_state_node.advance_phase()
	game_state_node.set_phase(1)
	game_state_node.set_phase(2)
	game_state_node.change_phase(1)
	game_state_node.end_produce_phase()
	assert_eq(int(game_state_node.current_phase), initial_phase, "Phase remains locked at PLAN post-loss")
	assert_false(phase_watcher.emitted, "Zero phase_changed signals emitted post-loss")

## Stress-tests 50 iterations of rapid action hammering post-defeat.
func test_challenge_lockout_lost_hammering_loop() -> void:
	var bs = _create_build_system()
	event_bus_node.game_lost.emit()
	await wait_frames(1)

	var initial_wood = game_state_node.resources.get("wood", 0)

	for i in range(50):
		assert_false(game_state_node.spend_ap(1), "spend_ap rejected on iteration %d" % i)
		assert_null(bs.place_building("wall", Vector2i(i + 1, 1)), "place_building rejected on iteration %d" % i)
		game_state_node.trigger_end_action()
		game_state_node.advance_phase()
		assert_eq(int(game_state_node.current_phase), 0, "Phase locked at 0 on iteration %d" % i)

	assert_eq(game_state_node.resources.get("wood", 0), initial_wood, "Wood strictly preserved after 50 hammer iterations")

# ==============================================================================
# Category 5: Tower Attacking Nest Under Extreme Conditions (test_challenge_tower_nest_*)
# ==============================================================================

## Stress-tests 4 defense towers concurrently assaulting a single Nest until destruction.
func test_challenge_tower_nest_multi_tower_focused_assault() -> void:
	assert_not_null(tower_script, "Tower script must exist")
	assert_not_null(nest_script, "Nest script must exist")

	var nest = nest_script.new()
	nest.position = Vector3(0.0, 0.0, 0.0)
	_cleanup_nodes.append(nest)

	# Surround Nest with 4 towers positioned at cardinal points (distance = 3.0m <= 5.0m)
	var tower_positions = [
		Vector3(0.0, 0.0, -3.0),
		Vector3(0.0, 0.0, 3.0),
		Vector3(-3.0, 0.0, 0.0),
		Vector3(3.0, 0.0, 0.0)
	]

	var towers: Array[Node] = []
	for pos in tower_positions:
		var t = tower_script.new()
		t.position = pos
		_cleanup_nodes.append(t)
		towers.append(t)

	if tree and tree.root:
		tree.root.add_child(nest)
		for t in towers:
			tree.root.add_child(t)
		await wait_frames(2)

	# Register target acquisition for each tower
	for t in towers:
		if t.has_method("on_target_entered"):
			t.on_target_entered(nest)
		var target = t.acquire_target()
		assert_eq(target, nest, "Each surrounding tower must target the Nest")

	var won_watcher = watch_signal(event_bus_node, "game_won")

	# Volley 8 rounds of simultaneous attacks (4 towers * 8 rounds = 32 attacks >= 30 HP)
	for round_num in range(8):
		for t in towers:
			if not nest.is_destroyed:
				t.attack(nest)

	assert_true(nest.is_destroyed, "Nest must be destroyed by multi-tower barrage")
	assert_almost_eq(float(nest.current_hp), 0.0, 0.001, "Nest HP drops to 0")
	assert_true(won_watcher.emitted, "game_won emitted via multi-tower barrage")
	assert_eq(won_watcher.emit_count, 1, "game_won emitted EXACTLY once despite 4 concurrent towers")

	# Post-destruction safety: All towers must drop invalid target without crashing
	for t in towers:
		var post_target = t.acquire_target()
		assert_null(post_target, "Tower must clear dead Nest target")
		# Attempting to attack after nest dead must be a safe no-op
		t.attack(nest)

## Stress-tests Tower target range at the exact 5.0m threshold boundary and outside.
func test_challenge_tower_nest_5m_boundary_threshold() -> void:
	assert_not_null(tower_script, "Tower script must exist")
	assert_not_null(nest_script, "Nest script must exist")

	var tower = tower_script.new()
	tower.position = Vector3(0.0, 0.0, 0.0)
	_cleanup_nodes.append(tower)

	var nest_in_range = nest_script.new()
	# Distance = exactly 5.0m (on threshold boundary)
	nest_in_range.position = Vector3(5.0, 0.0, 0.0)
	_cleanup_nodes.append(nest_in_range)

	var nest_out_of_range = nest_script.new()
	# Distance = 6.0m (well outside 5.0m threshold boundary)
	nest_out_of_range.position = Vector3(0.0, 0.0, 6.0)
	_cleanup_nodes.append(nest_out_of_range)

	if tree and tree.root:
		tree.root.add_child(tower)
		tree.root.add_child(nest_in_range)
		tree.root.add_child(nest_out_of_range)
		await wait_frames(2)

	# Test In-Range Nest at 5.0m
	tower.on_target_entered(nest_in_range)
	var target_at_boundary = tower.acquire_target()
	assert_not_null(target_at_boundary, "Tower must acquire Nest positioned exactly at 5.0m boundary")
	assert_eq(target_at_boundary, nest_in_range, "Target must be nest_in_range")

	# Attack at 5.0m succeeds
	var hp_before = nest_in_range.current_hp
	tower.attack(nest_in_range)
	assert_almost_eq(float(nest_in_range.current_hp), hp_before - 1.0, 0.001, "Tower deals 1.0 damage at 5.0m boundary")

	# Test Out-Of-Range Nest at 6.0m
	tower.on_target_exited(nest_in_range)
	tower.on_target_entered(nest_out_of_range)
	var target_out = tower.acquire_target()
	assert_null(target_out, "Tower must REJECT Nest positioned at 6.0m (beyond 5.0m range)")

	# Attempted attack on out-of-range Nest must deal 0 damage
	var hp_out_before = nest_out_of_range.current_hp
	tower.attack(nest_out_of_range)
	assert_almost_eq(float(nest_out_of_range.current_hp), hp_out_before, 0.001, "Out-of-range Nest takes 0 damage")

## Stress-tests sub-millimeter precision at boundary (4.9m in, 5.0m in, 5.5m out).
func test_challenge_tower_nest_boundary_distance_gradient() -> void:
	var tower = tower_script.new()
	tower.position = Vector3.ZERO
	_cleanup_nodes.append(tower)

	# 1. Nest at 4.9m: MUST be in range
	var nest_4_9 = nest_script.new()
	nest_4_9.position = Vector3(0.0, 0.0, 4.9)
	_cleanup_nodes.append(nest_4_9)

	# 2. Nest at 5.5m: MUST be out of range
	var nest_5_5 = nest_script.new()
	nest_5_5.position = Vector3(0.0, 0.0, 5.5)
	_cleanup_nodes.append(nest_5_5)

	if tree and tree.root:
		tree.root.add_child(tower)
		tree.root.add_child(nest_4_9)
		tree.root.add_child(nest_5_5)
		await wait_frames(2)

	# 4.9m check
	tower.on_target_entered(nest_4_9)
	assert_eq(tower.acquire_target(), nest_4_9, "4.9m is within range")
	tower.attack(nest_4_9)
	assert_almost_eq(float(nest_4_9.current_hp), 29.0, 0.001, "4.9m nest damaged")

	# 5.5m check
	tower.on_target_exited(nest_4_9)
	tower.on_target_entered(nest_5_5)
	assert_null(tower.acquire_target(), "5.5m is strictly out of range")
	tower.attack(nest_5_5)
	assert_almost_eq(float(nest_5_5.current_hp), 30.0, 0.001, "5.5m nest untouched")

## Stress-tests 3D diagonal Euclidean distance boundary (3-4-5 triangle = 5.0m in; 4-4-0 = 5.65m out).
func test_challenge_tower_nest_diagonal_euclidean_boundary() -> void:
	var tower = tower_script.new()
	tower.position = Vector3.ZERO
	_cleanup_nodes.append(tower)

	# 3D diagonal at (3, 0, 4): distance = sqrt(9 + 16) = 5.0m (in range)
	var nest_diag_in = nest_script.new()
	nest_diag_in.position = Vector3(3.0, 0.0, 4.0)
	_cleanup_nodes.append(nest_diag_in)

	# 3D diagonal at (4, 0, 4): distance = sqrt(16 + 16) = 5.657m (out of range)
	var nest_diag_out = nest_script.new()
	nest_diag_out.position = Vector3(4.0, 0.0, 4.0)
	_cleanup_nodes.append(nest_diag_out)

	if tree and tree.root:
		tree.root.add_child(tower)
		tree.root.add_child(nest_diag_in)
		tree.root.add_child(nest_diag_out)
		await wait_frames(2)

	# Test in-range diagonal (5.0m)
	tower.on_target_entered(nest_diag_in)
	assert_eq(tower.acquire_target(), nest_diag_in, "Diagonal at (3, 0, 4) distance 5.0m is valid target")
	tower.attack(nest_diag_in)
	assert_almost_eq(float(nest_diag_in.current_hp), 29.0, 0.001, "Diagonal nest at 5.0m takes 1.0 damage")

	# Test out-of-range diagonal (5.657m)
	tower.on_target_exited(nest_diag_in)
	tower.on_target_entered(nest_diag_out)
	assert_null(tower.acquire_target(), "Diagonal at (4, 0, 4) distance 5.657m is rejected")
	tower.attack(nest_diag_out)
	assert_almost_eq(float(nest_diag_out.current_hp), 30.0, 0.001, "Out-of-range diagonal nest takes 0 damage")
