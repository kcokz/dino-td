# res://tests/test_win_loss_challenge.gd
# ==============================================================================
# Empirical Challenger Test Suite for Milestone 5: Win/Loss & Core Lifecycle
# Rigorously stress-tests:
# 1. Race conditions: the beacon charging while the Core takes damage. (It was the nest
#    taking damage until v0.6; the nest cannot be destroyed now, and the beacon wins.)
# 2. Idempotency: Repeated destruction calls on a dead Core.
#    end action click, and phase advance post-victory (game_won) and post-defeat (game_lost).
# ==============================================================================
extends "res://tests/test_base.gd"

# Autoload References
var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

# Entity & Core Scripts
var core_campfire_script: GDScript = null
var tower_script: GDScript = null
var wall_script: GDScript = null
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

	core_campfire_script = _load_script(["res://scripts/entities/CoreCampfire.gd", "res://scripts/entities/core_campfire.gd"])
	tower_script = _load_script(["res://scripts/entities/Tower.gd", "res://scripts/entities/tower.gd"])
	wall_script = _load_script(["res://scripts/entities/Wall.gd", "res://scripts/entities/wall.gd"])
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

## Stress-tests lethal damage to Core followed immediately by the beacon charging.
## Core death must trigger game_lost, and the beacon charged after it must NOT grant victory.
func test_challenge_race_core_destruction_locks_out_a_later_jump() -> void:
	var core = _create_core()
	assert_not_null(core, "CoreCampfire must exist")

	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var lost_watcher = watch_signal(event_bus_node, "game_lost")
	var won_watcher = watch_signal(event_bus_node, "game_won")

	# Destroy Core first
	core.take_damage(core_hp())
	assert_true(lost_watcher.emitted, "game_lost emitted when Core destroyed")
	assert_true(bool(game_state_node.is_game_over), "is_game_over must be true after Core loss")
	assert_false(bool(game_state_node.is_game_won), "is_game_won must be false after Core loss")

	# Now the beacon, in the same frame/turn
	win_the_run()
	await wait_frames(1)

	# No jump: the game was already lost
	assert_false(won_watcher.emitted, "game_won must NOT be emitted when the beacon charges after Core was already lost")
	assert_true(bool(game_state_node.is_game_over), "is_game_over remains true")
	assert_false(bool(game_state_node.is_game_won), "is_game_won must remain false (cannot win after loss)")

## Stress-tests the jump followed immediately by lethal damage to Core.
## Victory achieved first must not be overwritten by subsequent Core destruction.
func test_challenge_race_the_jump_locks_out_a_later_core_defeat() -> void:
	var core = _create_core()
	assert_not_null(core, "CoreCampfire must exist")

	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var won_watcher = watch_signal(event_bus_node, "game_won")

	# The jump first
	win_the_run()
	assert_true(won_watcher.emitted, "game_won emitted when the beacon has charged")
	assert_true(bool(game_state_node.is_game_over), "is_game_over must be true after the jump")
	assert_true(bool(game_state_node.is_game_won), "is_game_won must be true after the jump")

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

## Stress-tests the beacon charging while the Core is being chewed, until one of them ends
## the run. Tests that the first to finish cleanly terminates the game without state tearing.
func test_challenge_race_rapid_interleaved_damage_resolution() -> void:
	var core = _create_core()
	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var gs = game_state_node
	for i in range(int(gs.beacon_stage_count()) + 1):
		gs.finish_beacon_job(String(gs.beacon_next_job()))
	assert_true(gs.is_beacon_launched(), "The beacon is charging")
	var total: float = float(gs.map_data()["beacon"]["charge_seconds"])

	var lost_watcher = watch_signal(event_bus_node, "game_lost")
	var won_watcher = watch_signal(event_bus_node, "game_won")

	# A fifth of the core's HP a round kills it in the fifth, when the beacon has had four
	# tenths of its charge -- and the fifth tenth comes after the core is gone.
	for i in range(10):
		if gs.is_game_over:
			break
		core.take_damage(core_hp() / 5.0)
		gs.charge_beacon(total * 0.1)

	assert_true(gs.is_game_over, "Game must reach game_over terminal state")
	assert_true(lost_watcher.emitted, "Core destroyed first, game_lost emitted")
	assert_false(won_watcher.emitted, "The beacon was not charged, game_won must NOT emit")
	assert_almost_eq(gs.beacon_charge_ratio(), 0.4, 0.0001, "The charge stopped where the run ended")

## Stress-tests the last second of the charge landing while the Core is one bite from gone.
func test_challenge_race_simultaneous_same_frame_fatal_damage() -> void:
	var core = _create_core()
	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var gs = game_state_node
	for i in range(int(gs.beacon_stage_count()) + 1):
		gs.finish_beacon_job(String(gs.beacon_next_job()))
	var total: float = float(gs.map_data()["beacon"]["charge_seconds"])

	# Both a hair from the end
	core.take_damage(core_hp() - 1.0)
	gs.charge_beacon(total - 1.0)
	assert_almost_eq(float(core.current_hp), 1.0, 0.001, "Core HP primed at 1.0")
	assert_false(gs.is_game_over, "Game not yet over")

	var won_watcher = watch_signal(event_bus_node, "game_won")

	# The last second of the charge
	gs.charge_beacon(1.0)
	assert_true(won_watcher.emitted, "game_won emitted at full charge")
	assert_true(gs.is_game_over, "is_game_over is true")
	assert_true(gs.is_game_won, "is_game_won is true")

# ==============================================================================
# Category 2: Idempotency & Repeated Destruction Calls (test_challenge_idempotency_*)
# ==============================================================================

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

## Stress-tests invalid inputs (negative, zero, NaN) on the Core's damage and the beacon's charge.
func test_challenge_idempotency_invalid_damage_inputs_ignored() -> void:
	var core = _create_core()
	if tree and tree.root:
		tree.root.add_child(core)
		await wait_frames(1)

	var gs = game_state_node
	for i in range(int(gs.beacon_stage_count()) + 1):
		gs.finish_beacon_job(String(gs.beacon_next_job()))

	var won_watcher = watch_signal(event_bus_node, "game_won")
	var lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Negative and zero damage; negative, zero and not-a-number charging
	core.take_damage(-20.0)
	core.take_damage(0.0)
	gs.charge_beacon(-50.0)
	gs.charge_beacon(0.0)
	gs.charge_beacon(NAN)

	assert_almost_eq(float(core.current_hp), core_hp(), 0.001, "Core HP unharmed by negative/zero damage")
	assert_almost_eq(float(gs.beacon_charge), 0.0, 0.0001, "The charge untouched by nonsense")
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

	var initial_wood = game_state_node.resources.get("wood", 0)
	var initial_phase = int(game_state_node.current_phase)


	# 2. Building placement & wood spend rejection for all building types
	var place_watcher = watch_signal(event_bus_node, "building_placed")
	var types = ["set_crossbow", "wall"]
	for i in range(types.size()):
		var b_type = types[i]
		var cell = Vector2i(i + 1, i + 1)

		assert_false(bs.can_place_building(b_type, cell), "can_place_building('%s') rejected post-win" % b_type)
		var placed = bs.place_building(b_type, cell)
		assert_null(placed, "place_building('%s') must return null post-win" % b_type)

	assert_false(place_watcher.emitted, "Zero building_placed signals post-win")
	assert_eq(game_state_node.resources.get("wood", 0), initial_wood, "Wood remains untouched (zero wood spend post-win)")

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
		assert_null(bs.place_building("set_crossbow", Vector2i(i + 1, 0)), "place_building rejected on iteration %d" % i)
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

	var initial_wood = game_state_node.resources.get("wood", 0)
	var initial_phase = int(game_state_node.current_phase)


	# 2. Building placement & wood spend rejection for all building types
	var place_watcher = watch_signal(event_bus_node, "building_placed")
	var types = ["set_crossbow", "wall"]
	for i in range(types.size()):
		var b_type = types[i]
		var cell = Vector2i(i + 2, i + 2)

		assert_false(bs.can_place_building(b_type, cell), "can_place_building('%s') rejected post-loss" % b_type)
		var placed = bs.place_building(b_type, cell)
		assert_null(placed, "place_building('%s') must return null post-loss" % b_type)

	assert_false(place_watcher.emitted, "Zero building_placed signals post-loss")
	assert_eq(game_state_node.resources.get("wood", 0), initial_wood, "Wood remains untouched (zero wood spend post-loss)")

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
		assert_null(bs.place_building("wall", Vector2i(i + 1, 1)), "place_building rejected on iteration %d" % i)
		game_state_node.trigger_end_action()
		game_state_node.advance_phase()
		assert_eq(int(game_state_node.current_phase), 0, "Phase locked at 0 on iteration %d" % i)

	assert_eq(game_state_node.resources.get("wood", 0), initial_wood, "Wood strictly preserved after 50 hammer iterations")
