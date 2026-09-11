# res://tests/test_dino_adversarial_deep.gd
# Additional Empirical Stress Challenges for Dino.gd
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var dino_script: GDScript = null
var wall_script: GDScript = null
var core_campfire_script: GDScript = null

var _allocated_nodes: Array[Node] = []
var _allocated_objects: Array[Object] = []

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

func _create_dino(type_id: String = "raptor", multipliers: Dictionary = {}) -> Object:
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

# 1. Pathological Stat Multiplier Types
func test_adversarial_malformed_stat_multipliers() -> void:
	var malformed = {
		"hp": "3.5",
		"damage": [],
		"speed": {},
		"attack_rate": false,
		"unknown_key": 999.0
	}
	var dino = _create_dino("raptor", malformed)
	assert_not_null(dino, "Dino created successfully with malformed multiplier dictionary")
	# "3.5" string should parse to 3.5 -> hp = 3.0 * 3.5 = 10.5
	assert_almost_eq(float(dino.max_hp), 10.5, 0.01, "String float parsed safely")
	# damage [] should fallback to default 1.0 -> 1.0 * 1.0 = 1.0
	assert_almost_eq(float(dino.damage), 1.0, 0.01, "Array fallback to default multiplier")
	# speed {} should fallback to default 1.0 -> 4.0 * 1.0 = 4.0
	assert_almost_eq(float(dino.speed), 4.0, 0.01, "Dictionary fallback to default multiplier")

# 2. Rapid Re-entrant Take Damage & Lethal Free
func test_adversarial_rapid_reentrant_take_damage() -> void:
	var dino = _create_dino("raptor")
	var watcher = watch_signal(event_bus_node, "dino_died")

	# Inflict multiple damage hits on the same frame, exceeding max_hp
	dino.take_damage(1.0)
	dino.take_damage(2.0)
	# Dino is now dead, next calls must be no-ops
	dino.take_damage(5.0)
	dino.take_damage(100.0)
	dino.die()

	assert_true(dino.is_dead, "Dino marked dead")
	assert_eq(int(dino.current_state), 2, "Dino in DEAD state")
	assert_eq(watcher.emit_count, 1, "dino_died emitted exactly once despite multiple lethal calls")

# 3. Pathological Attack Rate (zero / negative)
func test_adversarial_zero_and_negative_attack_rate() -> void:
	var dino = _create_dino("raptor")
	dino.attack_rate = 0.0
	# Trigger ready again or update timer
	if dino.attack_timer:
		if dino.attack_rate > 0.0:
			dino.attack_timer.wait_time = maxf(0.1, 1.0 / dino.attack_rate)
		else:
			dino.attack_timer.wait_time = 1.0
		assert_gte(dino.attack_timer.wait_time, 0.1, "Attack timer clamped safely on zero attack rate")

	dino.attack_rate = -5.0
	if dino.attack_timer:
		if dino.attack_rate > 0.0:
			dino.attack_timer.wait_time = maxf(0.1, 1.0 / dino.attack_rate)
		else:
			dino.attack_timer.wait_time = 1.0
		assert_gte(dino.attack_timer.wait_time, 0.1, "Attack timer clamped safely on negative attack rate")

# 4. Target validity against malformed objects
func test_adversarial_is_target_valid_robustness() -> void:
	var dino = _create_dino("raptor")
	assert_false(dino._is_target_valid(null), "null is invalid")
	assert_false(dino._is_target_valid(123), "int is invalid")
	assert_false(dino._is_target_valid("wall"), "String is invalid")
	assert_false(dino._is_target_valid([]), "Array is invalid")
	assert_false(dino._is_target_valid({}), "Dictionary is invalid")

	var ref = RefCounted.new()
	assert_false(dino._is_target_valid(ref), "RefCounted (non-Node) is invalid")

	var plain_node = Node.new()
	assert_false(dino._is_target_valid(plain_node), "Plain Node without take_damage is invalid")
	plain_node.free()

# 5. Look_at identical position safety
func test_adversarial_look_at_identical_position() -> void:
	var dino = _create_dino("raptor")
	dino.global_position = Vector3(5.0, 0.0, 5.0)
	# Set identical waypoints
	dino.set_waypoints([Vector3(5.0, 0.0, 5.0), Vector3(5.0, 0.0, 5.0)])
	# Should not crash on zero-length diff
	dino.advance_towards_waypoint(0.1)
	assert_almost_eq(dino.global_position.x, 5.0, 0.01, "Position maintained")
	assert_almost_eq(dino.global_position.z, 5.0, 0.01, "Position maintained")

# 6. Group and Collision Layer Integrity
func test_adversarial_node_groups_and_collision_layers() -> void:
	var dino = _create_dino("raptor")
	assert_true(dino.is_in_group("dinos"), "Dino is in group 'dinos'")
	assert_eq(dino.collision_layer, 12, "Dino collision_layer has bit 2 (dinos) and bit 3 (enemies) set = 12")
	assert_eq(dino.collision_mask, 0, "Dino collision_mask is 0 (handled by raycast)")
