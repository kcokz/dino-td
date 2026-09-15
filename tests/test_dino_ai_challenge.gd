# res://tests/test_dino_ai_challenge.gd
# Empirical Challenger Test Suite for Milestone 4: Dino AI Navigation, Obstacle Collision, and Combat.
# Comprehensive stress tests covering:
# 1. Complex waypoint routes (zig-zag, 180-degree hairpin, redundant/identical waypoints).
# 2. Dense wall configurations (multi-wall sequential blocking along routes, corner walls).
# 3. Rapid building destruction mid-attack (queue_free, hard free(), rapid churning).
# 4. Multiple concurrent dinos attacking the exact same wall.
# 5. Overlapping & inside-bounds edge cases (spawned inside wall box, high-speed tunneling).
# 6. Zero-length waypoints and destination signal spam oracle.
# 7. Extreme and adversarial stat multipliers (zero, negative, huge, malformed/null).
# 8. Damage boundary resilience (NaN/INF damage handling).
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var dino_script: GDScript = null
var wall_script: GDScript = null
var core_campfire_script: GDScript = null
var tower_script: GDScript = null
var wave_manager_script: GDScript = null

var _allocated_nodes: Array[Node] = []
var _allocated_objects: Array[Object] = []

# ==============================================================================
# Lifecycle
# ==============================================================================

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if config_node == null and ResourceLoader.exists("res://scripts/autoload/Config.gd"):
		config_node = load("res://scripts/autoload/Config.gd").new()
		_allocated_objects.append(config_node)

	if event_bus_node == null and ResourceLoader.exists("res://scripts/autoload/EventBus.gd"):
		event_bus_node = load("res://scripts/autoload/EventBus.gd").new()
		_allocated_objects.append(event_bus_node)

	if game_state_node == null and ResourceLoader.exists("res://scripts/autoload/GameState.gd"):
		game_state_node = load("res://scripts/autoload/GameState.gd").new()
		_allocated_objects.append(game_state_node)

	dino_script = load("res://scripts/entities/Dino.gd")
	wall_script = load("res://scripts/entities/Wall.gd")
	core_campfire_script = load("res://scripts/entities/CoreCampfire.gd")
	tower_script = load("res://scripts/entities/Tower.gd")
	wave_manager_script = load("res://scripts/core/WaveManager.gd")

func after_each() -> void:
	for n in _allocated_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_allocated_nodes.clear()

	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	for obj in _allocated_objects:
		if is_instance_valid(obj):
			if obj is Node:
				if obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
				if not obj.is_queued_for_deletion():
					obj.free()
	_allocated_objects.clear()

# ==============================================================================
# Helper Factories
# ==============================================================================

func _create_dino(type_id: String = "raptor", multipliers: Dictionary = {}) -> Object:
	assert_not_null(dino_script, "Dino.gd must exist")
	var dino = dino_script.new()
	if dino is Node:
		_allocated_nodes.append(dino)
		if tree != null and tree.root != null:
			tree.root.add_child(dino)
	else:
		_allocated_objects.append(dino)
	if dino.has_method("setup"):
		dino.call("setup", type_id, multipliers)
	return dino

func _create_wall(pos: Vector3 = Vector3.ZERO) -> Object:
	assert_not_null(wall_script, "Wall.gd must exist")
	var wall = wall_script.new()
	if wall is Node:
		_allocated_nodes.append(wall)
		if tree != null and tree.root != null:
			tree.root.add_child(wall)
		if "global_position" in wall:
			wall.global_position = pos
	else:
		_allocated_objects.append(wall)
	return wall

func _create_core(pos: Vector3 = Vector3.ZERO) -> Object:
	assert_not_null(core_campfire_script, "CoreCampfire.gd must exist")
	var core = core_campfire_script.new()
	if core is Node:
		_allocated_nodes.append(core)
		if tree != null and tree.root != null:
			tree.root.add_child(core)
		if "global_position" in core:
			core.global_position = pos
	else:
		_allocated_objects.append(core)
	return core

# ==============================================================================
# 1. Complex Waypoint Routes
# ==============================================================================

func test_complex_zig_zag_waypoint_navigation() -> void:
	# Test a 4-point zig-zag route: (0,0,0) -> (4,0,0) -> (4,0,4) -> (0,0,4) -> (0,0,8)
	var dino = _create_dino("raptor")
	var wps: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 4.0),
		Vector3(0.0, 0.0, 4.0),
		Vector3(0.0, 0.0, 8.0)
	]
	dino.set_waypoints(wps)
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	# Simulate 100 physics steps of delta = 0.1s (total 10 seconds of movement at speed 4.0)
	for i in range(100):
		dino.advance_towards_waypoint(0.1)
		if dino.current_waypoint_index >= wps.size():
			break

	# Dino should have navigated through all 5 waypoints and reached the end
	assert_gte(dino.current_waypoint_index, wps.size(), "Dino should advance past all waypoints in zig-zag route")
	assert_almost_eq(dino.global_position.x, 0.0, 0.5, "Dino final X should be near 0.0")
	assert_almost_eq(dino.global_position.z, 8.0, 0.5, "Dino final Z should be near 8.0")

func test_hairpin_180_degree_turn_navigation() -> void:
	# Test sharp reversal: (0,0,0) -> (4,0,0) -> (0,0,0)
	var dino = _create_dino("raptor")
	var wps: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0)
	]
	dino.set_waypoints(wps)
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	# Step towards (4,0,0)
	for i in range(20):
		dino.advance_towards_waypoint(0.1)
		if dino.current_waypoint_index == 2:
			break

	assert_eq(dino.current_waypoint_index, 2, "Dino reaches waypoint 1 and targets waypoint 2 (0,0,0)")

	# Step back towards (0,0,0)
	for i in range(20):
		dino.advance_towards_waypoint(0.1)
		if dino.current_waypoint_index >= wps.size():
			break

	assert_gte(dino.current_waypoint_index, 3, "Dino completes 180-degree hairpin turn and reaches final waypoint")
	assert_almost_eq(dino.global_position.x, 0.0, 0.5, "Dino returned to origin X=0.0")

func test_redundant_consecutive_identical_waypoints() -> void:
	# Duplicate waypoints at identical coordinates: [(0,0,0), (0,0,0), (3,0,0), (3,0,0)]
	var dino = _create_dino("raptor")
	var wps: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(3.0, 0.0, 0.0),
		Vector3(3.0, 0.0, 0.0)
	]
	dino.set_waypoints(wps)
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	for i in range(40):
		dino.advance_towards_waypoint(0.1)
		if dino.current_waypoint_index >= wps.size():
			break

	assert_gte(dino.current_waypoint_index, wps.size(), "Dino handles consecutive identical waypoints without hanging")
	assert_almost_eq(dino.global_position.x, 3.0, 0.5, "Dino reaches final position X=3.0")

# ==============================================================================
# 2. Dense Wall Configurations
# ==============================================================================

func test_dense_sequential_walls_along_route() -> void:
	# 3 walls placed sequentially along a straight path at X=2.0, X=4.0, X=6.0
	# Dino starts at X=0.0 with waypoint at (8.0, 0.0, 0.0)
	# Dino must sequentially encounter Wall 1, attack it until destroyed, resume, encounter Wall 2, etc.
	await wait_frames(2)
	var dino = _create_dino("raptor")
	var wall1 = _create_wall(Vector3(2.0, 0.0, 0.0))
	var wall2 = _create_wall(Vector3(4.0, 0.0, 0.0))
	var wall3 = _create_wall(Vector3(6.0, 0.0, 0.0))
	await wait_frames(2)

	dino.set_waypoints([Vector3(0.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0)])
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	# Simulate movement until blocked by Wall 1
	var blocked_wall1 = false
	for step in range(30):
		dino.advance_towards_waypoint(0.05)
		if dino.current_state == 1: # State.ATTACKING
			blocked_wall1 = true
			break
	assert_true(blocked_wall1, "Dino is blocked by first wall")
	assert_eq(dino.current_target, wall1, "Dino current_target is wall1")

	# Destroy wall1
	wall1.take_damage(30.0)
	assert_true(wall1.is_destroyed, "Wall 1 is destroyed")
	dino._process_attacking(0.0)
	assert_eq(int(dino.current_state), 0, "Dino resumes WALKING after Wall 1 destroyed")

	# Simulate movement until blocked by Wall 2
	var blocked_wall2 = false
	for step in range(40):
		dino.advance_towards_waypoint(0.05)
		if dino.current_state == 1:
			blocked_wall2 = true
			break
	assert_true(blocked_wall2, "Dino is blocked by second wall")
	assert_eq(dino.current_target, wall2, "Dino current_target is wall2")

	# Destroy wall2
	wall2.take_damage(30.0)
	assert_true(wall2.is_destroyed, "Wall 2 is destroyed")
	dino._process_attacking(0.0)
	assert_eq(int(dino.current_state), 0, "Dino resumes WALKING after Wall 2 destroyed")

	# Simulate movement until blocked by Wall 3
	var blocked_wall3 = false
	for step in range(40):
		dino.advance_towards_waypoint(0.05)
		if dino.current_state == 1:
			blocked_wall3 = true
			break
	assert_true(blocked_wall3, "Dino is blocked by third wall")
	assert_eq(dino.current_target, wall3, "Dino current_target is wall3")

	# Destroy wall3
	wall3.take_damage(30.0)
	assert_true(wall3.is_destroyed, "Wall 3 is destroyed")
	dino._process_attacking(0.0)
	assert_eq(int(dino.current_state), 0, "Dino resumes WALKING after Wall 3 destroyed")

	# Continue to final destination
	for step in range(40):
		dino.advance_towards_waypoint(0.05)
		if dino.current_waypoint_index >= dino.waypoints.size():
			break

	assert_gte(dino.current_waypoint_index, dino.waypoints.size(), "Dino successfully navigated all 3 sequential walls to destination")

func test_wall_placed_directly_at_waypoint_node() -> void:
	# Wall placed directly on the exact waypoint coordinate (4.0, 0.0, 0.0)
	await wait_frames(2)
	var dino = _create_dino("raptor")
	var wall = _create_wall(Vector3(4.0, 0.0, 0.0))
	await wait_frames(2)

	dino.set_waypoints([Vector3(0.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0), Vector3(8.0, 0.0, 0.0)])
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	# Move towards waypoint 1 (which has the wall)
	for step in range(30):
		dino.advance_towards_waypoint(0.05)
		if dino.current_state == 1:
			break

	assert_eq(int(dino.current_state), 1, "Dino enters ATTACKING when encountering wall at waypoint")
	assert_eq(dino.current_target, wall, "Dino target is wall at waypoint")

	# Destroy the wall
	wall.take_damage(30.0)
	dino._process_attacking(0.0)
	assert_eq(int(dino.current_state), 0, "Dino returns to WALKING")

	# Dino should now pass waypoint 1 and proceed to waypoint 2
	for step in range(50):
		dino.advance_towards_waypoint(0.05)
		if dino.current_waypoint_index >= dino.waypoints.size():
			break

	assert_gte(dino.current_waypoint_index, dino.waypoints.size(), "Dino advanced past the waypoint that was blocked by wall")

# ==============================================================================
# 3. Multiple Concurrent Dinos & Rapid Destruction Mid-Attack
# ==============================================================================

func test_multiple_concurrent_dinos_attacking_same_wall() -> void:
	# 8 dinos all attacking the exact same wall simultaneously
	await wait_frames(2)
	var wall = _create_wall(Vector3(2.0, 0.0, 0.0))
	var dinos: Array[Object] = []
	for i in range(8):
		var d = _create_dino("raptor")
		d.global_position = Vector3(0.0, 0.0, -1.0 + float(i) * 0.25)
		d.set_waypoints([d.global_position, Vector3(5.0, 0.0, d.global_position.z)])
		dinos.append(d)
	await wait_frames(2)

	# Put all dinos into attack state on this wall
	for d in dinos:
		d.on_obstacle_detected(wall)
		assert_eq(int(d.current_state), 1, "Dino is in ATTACKING state")
		assert_eq(d.current_target, wall, "Dino target is the shared wall")

	# This test is about damage accumulating from many attackers, not about balance,
	# so give the wall enough hp to survive the barrage whatever a stake costs.
	wall.max_hp = 30.0
	wall.current_hp = 30.0

	# Each dino performs 2 attacks (8 * 2 = 16 damage total)
	for d in dinos:
		d.perform_attack()
		d.perform_attack()

	assert_almost_eq(float(wall.current_hp), 30.0 - 16.0, 0.01, "Wall took combined damage from all 8 dinos (30 - 16 = 14)")

	# Dino 0 delivers fatal strike
	wall.take_damage(14.0)
	assert_true(wall.is_destroyed, "Shared wall is destroyed")

	# Now process attacking on all dinos - all should safely transition back to WALKING
	for d in dinos:
		d._process_attacking(0.0)
		assert_eq(int(d.current_state), 0, "Dino transitions back to WALKING after shared wall destroyed")
		assert_null(d.current_target, "Dino current_target cleared to null")
		assert_false(d.is_blocked, "Dino is_blocked reset to false")

func test_wall_destroyed_mid_attack_via_queue_free() -> void:
	# Wall queued for deletion while dino is actively attacking
	var dino = _create_dino("raptor")
	var wall = _create_wall(Vector3(1.0, 0.0, 0.0))

	dino.on_obstacle_detected(wall)
	assert_eq(int(dino.current_state), 1, "Dino is ATTACKING")

	# Building destroyed via standard destroy() which calls queue_free()
	wall.destroy()
	assert_true(wall.is_destroyed, "Wall marked is_destroyed")
	assert_true(wall.is_queued_for_deletion(), "Wall is queued for deletion")

	# Dino processes attacking next frame
	dino._process_attacking(0.0)
	assert_eq(int(dino.current_state), 0, "Dino cleared obstacle when target was queued for deletion")
	assert_null(dino.current_target, "current_target reset to null")

func test_wall_freed_immediately_mid_attack_hard_free() -> void:
	# Wall freed immediately with Object.free() (dangling pointer scenario)
	var dino = _create_dino("raptor")
	var wall = _create_wall(Vector3(1.0, 0.0, 0.0))

	dino.on_obstacle_detected(wall)
	assert_eq(dino.current_target, wall, "Target set to wall")

	# Immediately free wall
	_allocated_nodes.erase(wall)
	wall.free()

	# Verify dino._is_target_valid handles previously freed instance safely
	var is_valid = dino._is_target_valid(wall)
	assert_false(is_valid, "Freed wall must be reported as NOT valid")

	# Call _process_attacking and perform_attack - must not crash
	dino._process_attacking(0.0)
	assert_eq(int(dino.current_state), 0, "Dino returned to WALKING after hard-freed target")
	assert_null(dino.current_target, "current_target cleaned to null")

func test_rapid_fire_wall_destruction_churn() -> void:
	# 15 consecutive cycles of spawn wall -> dino attacks -> destroy wall
	var dino = _create_dino("raptor")
	for cycle in range(15):
		var wall = _create_wall(Vector3(1.0, 0.0, 0.0))
		dino.on_obstacle_detected(wall)
		assert_eq(int(dino.current_state), 1, "Cycle %d: Dino entered ATTACKING" % cycle)

		dino.perform_attack()
		wall.destroy()

		dino._process_attacking(0.0)
		assert_eq(int(dino.current_state), 0, "Cycle %d: Dino returned to WALKING" % cycle)

# ==============================================================================
# 4. Overlapping & Inside Building Bounds Edge Cases
# ==============================================================================

func test_dino_spawned_inside_building_bounds_detection() -> void:
	# A wall is placed at (0, 0, 0). Wall CollisionShape3D box is 1.8x1.0x1.8 (extents [-0.9, 0.9]).
	# Dino is spawned at (0, 0, 0), completely inside the wall bounding box.
	await wait_frames(2)
	var wall = _create_wall(Vector3(0.0, 0.0, 0.0))
	var dino = _create_dino("raptor")
	dino.global_position = Vector3(0.0, 0.0, 0.0)
	dino.set_waypoints([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	await wait_frames(2)

	# Does raycast detect the wall when originating INSIDE the wall?
	var detected_obstacle = dino.check_obstacle()

	# In Godot Physics, RayCast3D has hit_from_inside=false by default!
	# An obstacle bounding a Dino must be detected to prevent ghosting through defenses.
	if detected_obstacle == null:
		_record_fail("VULNERABILITY: Dino spawned inside wall bounds fails to detect obstacle (hit_from_inside=false). Dino will walk through wall.")
	else:
		_record_pass("Dino successfully detected obstacle while inside building bounds.")

func test_dino_extreme_speed_wall_tunneling() -> void:
	# A wall is placed at X = 2.0 (width 1.8, extents [1.1, 2.9]).
	# Dino starts at X = 0.0 with extreme speed multiplier (e.g. speed = 100.0 m/s).
	# In one 0.1s tick, Dino moves 10.0m, jumping from X=0.0 to X=10.0, bypassing the wall!
	await wait_frames(2)
	var wall = _create_wall(Vector3(2.0, 0.0, 0.0))
	var dino = _create_dino("raptor", {"speed": 25.0}) # 4.0 * 25.0 = 100.0 m/s
	dino.global_position = Vector3(0.0, 0.0, 0.0)
	dino.set_waypoints([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	await wait_frames(2)

	# Advance 1 tick of 0.1s (leap distance = 10.0m)
	dino.advance_towards_waypoint(0.1)

	# Did Dino tunnel through the wall?
	if dino.global_position.x > 3.0:
		_record_fail("VULNERABILITY: Dino with high speed tunneled through wall without collision. Pos X=%.2f" % dino.global_position.x)
	else:
		_record_pass("Dino did not tunnel through wall at high speed.")

# ==============================================================================
# 5. Zero-Length Waypoints & Destination Reached Signal Behavior
# ==============================================================================

func test_empty_waypoints_array_handling() -> void:
	# Empty waypoints array: waypoints = []
	var dino = _create_dino("raptor")
	dino.set_waypoints([])
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	# Call advance_towards_waypoint: current_waypoint_index (0) >= waypoints.size() (0)
	# Must not throw GDScript error or crash
	var safe = true
	dino.advance_towards_waypoint(0.1)
	assert_true(safe, "Dino handles empty waypoints without crashing")

func test_single_waypoint_at_spawn_position() -> void:
	# Single waypoint at spawn position: [(0,0,0)]
	var dino = _create_dino("raptor")
	dino.set_waypoints([Vector3(0.0, 0.0, 0.0)])
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	dino.advance_towards_waypoint(0.1)
	assert_gte(dino.current_waypoint_index, 1, "Dino reaches single waypoint immediately")

func test_destination_reached_signal_spam_when_no_core_present() -> void:
	# Stress test: When Dino reaches destination and NO Campfire Core is in the scene,
	# does it emit dino_reached_core ONCE or EVERY SINGLE FRAME?
	var dino = _create_dino("raptor")
	dino.set_waypoints([Vector3(0.0, 0.0, 0.0)])
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	var watcher = watch_signal(event_bus_node, "dino_reached_core")

	# Simulate 10 physics steps at destination
	for step in range(10):
		dino.advance_towards_waypoint(0.05)

	# An event-driven architecture should emit dino_reached_core ONCE per arrival, not spam every frame
	if watcher.emit_count > 1:
		_record_fail("VULNERABILITY: dino_reached_core was emitted %d times in 10 frames (signal spam loop)." % watcher.emit_count)
	elif watcher.emit_count == 1:
		_record_pass("dino_reached_core emitted exactly once upon arrival.")
	else:
		_record_fail("dino_reached_core was not emitted at all.")

func test_destination_reached_signal_spam_after_core_destroyed() -> void:
	# Stress test: Dino attacks Core. Core is destroyed.
	# Next frames: Does Dino re-emit dino_reached_core repeatedly?
	var dino = _create_dino("raptor")
	var core = _create_core(Vector3(0.0, 0.0, 0.0))
	dino.set_waypoints([Vector3(0.0, 0.0, 0.0)])
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	var watcher = watch_signal(event_bus_node, "dino_reached_core")

	# Step 1: Arrive and detect core
	dino.advance_towards_waypoint(0.05)
	var initial_emits = watcher.emit_count

	# Core takes fatal damage
	core.take_damage(10.0)
	assert_true(core.is_destroyed, "Core is destroyed")

	# Dino processes obstacle cleared
	dino._process_attacking(0.0)

	# Simulate next 10 frames
	for step in range(10):
		dino.advance_towards_waypoint(0.05)

	var total_emits = watcher.emit_count
	if total_emits > initial_emits + 1:
		_record_fail("VULNERABILITY: dino_reached_core re-emitted %d times after core destroyed." % (total_emits - initial_emits))
	else:
		_record_pass("dino_reached_core did not spam after core destruction.")

# ==============================================================================
# 6. Extreme & Adversarial Stat Multipliers
# ==============================================================================

func test_zero_stat_multipliers() -> void:
	# {"hp": 0.0, "damage": 0.0, "speed": 0.0}
	var dino = _create_dino("raptor", {"hp": 0.0, "damage": 0.0, "speed": 0.0})
	assert_almost_eq(float(dino.max_hp), 0.0, 0.01, "max_hp scaled to 0.0")
	assert_almost_eq(float(dino.current_hp), 0.0, 0.01, "current_hp scaled to 0.0")
	assert_almost_eq(float(dino.damage), 0.0, 0.01, "damage scaled to 0.0")
	assert_almost_eq(float(dino.speed), 0.0, 0.01, "speed scaled to 0.0")

	# With speed=0, Dino should not move and not crash on division by zero
	dino.set_waypoints([Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])
	dino.advance_towards_waypoint(0.1)
	assert_almost_eq(dino.global_position.x, 0.0, 0.001, "Dino remains at 0.0 with speed 0")

func test_negative_stat_multipliers() -> void:
	# Negative multiplier: damage should not heal buildings
	var dino = _create_dino("raptor", {"hp": -1.0, "damage": -5.0, "speed": -2.0})
	var wall = _create_wall(Vector3(1.0, 0.0, 0.0))

	var initial_wall_hp = float(wall.current_hp)

	# Dino attacks wall with negative damage (-5.0)
	dino.attack_target(wall)

	# Wall current_hp must NOT increase (Building.take_damage guards amount <= 0.0)
	assert_almost_eq(float(wall.current_hp), initial_wall_hp, 0.01, "Wall HP does not increase from negative damage")

func test_huge_stat_multipliers() -> void:
	# Huge multipliers: 1,000,000 HP and Damage
	var dino = _create_dino("raptor", {"hp": 1000000.0, "damage": 1000000.0, "speed": 1.0})
	assert_almost_eq(float(dino.max_hp), 3000000.0, 1.0, "Scaled max_hp is 3,000,000")
	assert_almost_eq(float(dino.damage), 1000000.0, 1.0, "Scaled damage is 1,000,000")

	var wall = _create_wall(Vector3(1.0, 0.0, 0.0))
	dino.attack_target(wall)
	assert_lte(float(wall.current_hp), 0.0, "Wall instantly crushed by 1,000,000 damage")

func test_null_stat_multiplier_crash_vulnerability() -> void:
	# Passing null for a stat multiplier dictionary key: {"speed": null}
	# In GDScript, float(null) raises a fatal runtime error: Nonexistent 'float' constructor
	var dino = dino_script.new()
	_allocated_nodes.append(dino)
	if tree != null and tree.root != null:
		tree.root.add_child(dino)

	var crashed = false
	# We test calling setup with null speed and hp: 2.0
	dino.setup("raptor", {"hp": 2.0, "speed": null})
	# If Dino.gd line 82 crashed, max_hp (lines 84-85) was aborted and remains 3.0 instead of 6.0
	if dino.max_hp != 6.0:
		_record_fail("VULNERABILITY: Dino.setup aborted execution on float(null) crash at line 82; max_hp was not updated.")
	else:
		_record_pass("Dino safely handled null multiplier.")

func test_nan_damage_immortal_zombie_vulnerability() -> void:
	# If Dino takes NaN damage, current_hp becomes NaN.
	# Does Dino become an unkillable zombie that cannot be destroyed by subsequent fatal damage?
	var dino = _create_dino("raptor")
	dino.take_damage(NAN)

	# Now inflict 1000.0 legitimate fatal damage
	dino.take_damage(1000.0)

	if dino.is_dead or dino.current_state == 2:
		_record_pass("Dino died properly despite prior NaN damage.")
	else:
		_record_fail("VULNERABILITY: Dino became immortal zombie after NaN damage; failed to die from 1000 damage.")
