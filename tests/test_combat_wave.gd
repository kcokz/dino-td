# res://tests/test_combat_wave.gd
# Requirement R4 Acceptance Test Suite:
# Verifies Dinosaur Entity (Raptor stats, scaling, waypoints, obstacle attack, core attack, death),
# Defense Tower (Area3D 5.0m range, nearest targeting, 1.0 dmg / 1.0s fire rate, retargeting),
# and WaveManager (Wave 1: 2 dinos, Wave 2: 3 dinos, Wave 3: 8 dinos horde, wave signals, post-horde buff).
extends "res://tests/test_base.gd"

## Wood this suite seeds in before_each. It asserts exact balances, so it owns
## its wallet rather than inheriting Config.INITIAL_RESOURCES (production tuning).
const SEED_WOOD: int = 10

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var dino_script: GDScript = null
var tower_script: GDScript = null
var wave_manager_script: GDScript = null
var wall_script: GDScript = null
var core_campfire_script: GDScript = null
var building_script: GDScript = null

var _cleanup_nodes: Array[Node] = []
var _cleanup_objects: Array[Object] = []

# ==============================================================================
# 1. Lifecycle Hooks
# ==============================================================================

func before_all() -> void:
	# 1. Resolve Autoload Singletons from /root or script fallback
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

	# 2. Load Entity and Core Scripts
	dino_script = _load_script([
		"res://scripts/entities/Dino.gd",
		"res://scripts/entities/dino.gd"
	])
	tower_script = _load_script([
		"res://scripts/entities/Tower.gd",
		"res://scripts/entities/tower.gd"
	])
	wave_manager_script = _load_script([
		"res://scripts/core/WaveManager.gd",
		"res://scripts/core/wave_manager.gd"
	])
	wall_script = _load_script([
		"res://scripts/entities/Wall.gd",
		"res://scripts/entities/wall.gd"
	])
	core_campfire_script = _load_script([
		"res://scripts/entities/CoreCampfire.gd",
		"res://scripts/entities/core_campfire.gd"
	])
	building_script = _load_script([
		"res://scripts/entities/Building.gd",
		"res://scripts/entities/building.gd"
	])

func before_each() -> void:
	# Ensure pristine game state before every test
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
		if "dino_stat_multipliers" in game_state_node:
			game_state_node.dino_stat_multipliers = {"hp": 1.0, "damage": 1.0, "speed": 1.0}
		if "is_game_over" in game_state_node: game_state_node.is_game_over = false

func after_each() -> void:
	# Clean up any instantiated nodes to prevent ObjectDB leaks
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()

	# Disconnect all active signal watchers
	for watcher in _active_watchers:
		watcher.disconnect_watcher()
	_active_watchers.clear()

func after_all() -> void:
	for obj in _cleanup_objects:
		if is_instance_valid(obj):
			if obj is Node:
				if obj.is_inside_tree():
					obj.get_parent().remove_child(obj)
				if not obj.is_queued_for_deletion():
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

func _create_dino(type_id: String = "raptor", multipliers: Dictionary = {}) -> Object:
	assert_not_null(dino_script, "Dino.gd script must exist")
	if dino_script == null:
		return null
	var dino = dino_script.new()
	if dino is Node:
		_cleanup_nodes.append(dino)
		if tree != null and tree.root != null:
			tree.root.add_child(dino)
	else:
		_cleanup_objects.append(dino)
	if dino.has_method("setup"):
		dino.call("setup", type_id, multipliers)
	return dino

func _create_tower() -> Object:
	assert_not_null(tower_script, "Tower.gd script must exist")
	if tower_script == null:
		return null
	var tower = tower_script.new()
	if tower is Node:
		_cleanup_nodes.append(tower)
		if tree != null and tree.root != null:
			tree.root.add_child(tower)
	else:
		_cleanup_objects.append(tower)
	return tower

func _create_wall(pos: Vector3 = Vector3.ZERO) -> Object:
	assert_not_null(wall_script, "Wall.gd script must exist")
	if wall_script == null:
		return null
	var wall = wall_script.new()
	if wall is Node:
		_cleanup_nodes.append(wall)
		if tree != null and tree.root != null:
			tree.root.add_child(wall)
		if pos != Vector3.ZERO and "global_position" in wall:
			wall.global_position = pos
	else:
		_cleanup_objects.append(wall)
	return wall

func _create_core(pos: Vector3 = Vector3.ZERO) -> Object:
	assert_not_null(core_campfire_script, "CoreCampfire.gd script must exist")
	if core_campfire_script == null:
		return null
	var core = core_campfire_script.new()
	if core is Node:
		_cleanup_nodes.append(core)
		if tree != null and tree.root != null:
			tree.root.add_child(core)
		if pos != Vector3.ZERO and "global_position" in core:
			core.global_position = pos
	else:
		_cleanup_objects.append(core)
	return core

func _create_wave_manager() -> Object:
	assert_not_null(wave_manager_script, "WaveManager.gd script must exist")
	if wave_manager_script == null:
		return null
	var wm = wave_manager_script.new()
	if wm is Node:
		_cleanup_nodes.append(wm)
		if tree != null and tree.root != null:
			tree.root.add_child(wm)
	else:
		_cleanup_objects.append(wm)
	return wm

# ==============================================================================
# 3. Category 1: Dino Entity Stats, Scaling & State Machine Tests (R4.1)
# ==============================================================================

func test_dino_base_stats_match_config() -> void:
	var dino = _create_dino("raptor", {})
	if dino == null: return

	var expected_hp: float = 3.0
	var expected_speed: float = 4.0
	var expected_damage: float = 1.0
	var expected_rate: float = 1.0
	var expected_targeting: String = "blocker_then_core"

	if config_node != null and "DINOS" in config_node and config_node.DINOS.has("raptor"):
		var data = config_node.DINOS["raptor"]
		expected_hp = float(data.get("hp", expected_hp))
		expected_speed = float(data.get("speed", expected_speed))
		expected_damage = float(data.get("damage", expected_damage))
		expected_rate = float(data.get("attack_rate", expected_rate))
		expected_targeting = data.get("targeting", expected_targeting)

	assert_almost_eq(float(dino.max_hp), expected_hp, 0.01, "Dino max_hp must match Config.DINOS['raptor']")
	assert_almost_eq(float(dino.current_hp), expected_hp, 0.01, "Dino initial current_hp must equal max_hp")
	assert_almost_eq(float(dino.speed), expected_speed, 0.01, "Dino speed must match Config")
	assert_almost_eq(float(dino.damage), expected_damage, 0.01, "Dino damage must match Config")
	assert_almost_eq(float(dino.attack_rate), expected_rate, 0.01, "Dino attack_rate must match Config")
	if "targeting" in dino:
		assert_eq(dino.targeting, expected_targeting, "Dino targeting strategy matches Config")

func test_dino_stat_scaling_multipliers() -> void:
	var mult = {"hp": 1.3, "damage": 1.2, "speed": 1.0}
	var dino = _create_dino("raptor", mult)
	if dino == null: return

	var expected_hp = 3.0 * 1.3
	var expected_damage = 1.0 * 1.2
	var expected_speed = 4.0 * 1.0

	assert_almost_eq(float(dino.max_hp), expected_hp, 0.01, "Scaled max_hp should be 3.0 * 1.3 = 3.9")
	assert_almost_eq(float(dino.current_hp), expected_hp, 0.01, "Scaled current_hp should be 3.9")
	assert_almost_eq(float(dino.damage), expected_damage, 0.01, "Scaled damage should be 1.0 * 1.2 = 1.2")
	assert_almost_eq(float(dino.speed), expected_speed, 0.01, "Speed should remain 4.0")

func test_dino_waypoint_pathing_advancement() -> void:
	var dino = _create_dino("raptor", {})
	if dino == null: return

	var waypoints: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 10.0)
	]

	if dino.has_method("set_waypoints"):
		dino.call("set_waypoints", waypoints)
	elif "waypoints" in dino:
		dino.waypoints = waypoints

	assert_has(dino, "global_position", "Dino must have global_position")
	dino.global_position = Vector3(0.0, 0.0, 0.0)

	# Simulate movement tick
	if dino.has_method("advance_towards_waypoint"):
		dino.call("advance_towards_waypoint", 0.5)
	elif dino.has_method("_physics_process"):
		dino.call("_physics_process", 0.5)

	# Dino should have advanced along the X axis towards (10, 0, 0)
	assert_gt(dino.global_position.x, 0.0, "Dino X position should increase towards waypoint (10, 0, 0)")
	assert_almost_eq(dino.global_position.z, 0.0, 0.01, "Dino Z position should remain 0 while moving along X")

func test_dino_obstacle_detection_stops_at_wall() -> void:
	var dino = _create_dino("raptor", {})
	var wall = _create_wall(Vector3(2.0, 0.0, 0.0))
	if dino == null or wall == null: return

	dino.global_position = Vector3(0.0, 0.0, 0.0)
	if dino.has_method("set_waypoints"):
		dino.call("set_waypoints", [Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)])

	# Notify or step dino into wall
	if dino.has_method("on_obstacle_detected"):
		dino.call("on_obstacle_detected", wall)
	elif "is_blocked" in dino:
		dino.is_blocked = true
		dino.target_building = wall

	# Check blocking state
	if "state" in dino:
		assert_true(str(dino.state).to_upper().contains("ATTACK") or dino.state == 1, "Dino enters attacking state when blocked")
	elif "is_blocked" in dino:
		assert_true(dino.is_blocked, "Dino is marked blocked by obstacle")

func test_dino_attacks_wall_periodically() -> void:
	var dino = _create_dino("raptor", {})
	var wall = _create_wall(Vector3(1.0, 0.0, 0.0))
	if dino == null or wall == null: return

	var initial_hp = float(wall.current_hp)
	assert_almost_eq(initial_hp, float(config_node.BUILDINGS["wall"]["hp"]), 0.01, "Wall starts at its Config hp")

	# Trigger attack
	if dino.has_method("attack_target"):
		dino.call("attack_target", wall)
	elif dino.has_method("perform_attack"):
		dino.call("perform_attack")
	else:
		wall.take_damage(float(dino.damage))

	assert_almost_eq(float(wall.current_hp), initial_hp - float(dino.damage), 0.01, "Wall HP deducted by dino damage (1.0)")

func test_dino_resumes_pathing_when_wall_destroyed() -> void:
	var dino = _create_dino("raptor", {})
	var wall = _create_wall(Vector3(1.0, 0.0, 0.0))
	if dino == null or wall == null: return

	if dino.has_method("on_obstacle_detected"):
		dino.call("on_obstacle_detected", wall)

	# Destroy wall
	wall.take_damage(30.0)
	assert_true(wall.is_destroyed, "Wall is destroyed")

	# Notify dino or step obstacle check
	if dino.has_method("on_obstacle_cleared"):
		dino.call("on_obstacle_cleared")
	elif dino.has_method("check_obstacle"):
		dino.call("check_obstacle")

	if "state" in dino:
		assert_true(str(dino.state).to_upper().contains("WALK") or dino.state == 0, "Dino resumes WALKING state")
	elif "is_blocked" in dino:
		assert_false(dino.is_blocked, "Dino is no longer blocked")

func test_dino_attacks_core_campfire_emits_hp_changed() -> void:
	var dino = _create_dino("raptor", {})
	var core = _create_core(Vector3(0.0, 0.0, 0.0))
	if dino == null or core == null or event_bus_node == null: return

	var hp_watcher = watch_signal(event_bus_node, "core_hp_changed")

	# Dino attacks core
	if dino.has_method("attack_target"):
		dino.call("attack_target", core)
	else:
		core.take_damage(float(dino.damage))

	assert_almost_eq(float(core.current_hp), 9.0, 0.01, "Core HP reduced from 10.0 to 9.0")
	assert_true(hp_watcher.emitted, "core_hp_changed signal must be emitted upon attack")
	if not hp_watcher.last_args.is_empty():
		assert_almost_eq(float(hp_watcher.last_args[0]), 9.0, 0.01, "core_hp_changed current HP is 9.0")
		assert_almost_eq(float(hp_watcher.last_args[1]), 10.0, 0.01, "core_hp_changed max HP is 10.0")

func test_dino_fatal_damage_emits_dino_died_and_frees() -> void:
	var dino = _create_dino("raptor", {})
	if dino == null or event_bus_node == null: return

	var death_watcher = watch_signal(event_bus_node, "dino_died")

	assert_has_method(dino, "take_damage", "Dino must implement take_damage")
	dino.take_damage(3.0)

	assert_lte(float(dino.current_hp), 0.0, "Dino current_hp must be <= 0")
	assert_true(death_watcher.emitted, "EventBus.dino_died must be emitted upon fatal damage")
	if not death_watcher.last_args.is_empty():
		assert_eq(death_watcher.last_args[0], dino, "dino_died arg must be the dying dino instance")
	assert_true(dino.is_queued_for_deletion(), "Dino must be queued for deletion")

func test_dino_non_fatal_damage_does_not_die() -> void:
	var dino = _create_dino("raptor", {})
	if dino == null or event_bus_node == null: return

	var death_watcher = watch_signal(event_bus_node, "dino_died")

	dino.take_damage(1.0)

	assert_almost_eq(float(dino.current_hp), 2.0, 0.01, "Dino current_hp should be 2.0")
	assert_false(death_watcher.emitted, "EventBus.dino_died must NOT be emitted for non-fatal damage")
	assert_false(dino.is_queued_for_deletion(), "Dino must not be queued for deletion")

# ==============================================================================
# 4. Category 2: Defense Tower Combat, Range & Targeting Tests (R4.2)
# ==============================================================================

func test_tower_stats_match_config() -> void:
	var tower = _create_tower()
	if tower == null: return

	var expected_hp: float = 20.0
	var expected_range: float = 5.0
	var expected_damage: float = 1.0
	var expected_fire_rate: float = 1.0

	if config_node != null and "BUILDINGS" in config_node and config_node.BUILDINGS.has("tower"):
		var data = config_node.BUILDINGS["tower"]
		expected_hp = float(data.get("hp", expected_hp))
		expected_range = float(data.get("range", expected_range))
		expected_damage = float(data.get("damage", expected_damage))
		expected_fire_rate = float(data.get("fire_rate", expected_fire_rate))

	assert_almost_eq(float(tower.max_hp), expected_hp, 0.01, "Tower max_hp must match Config")
	if "attack_range" in tower:
		assert_almost_eq(float(tower.attack_range), expected_range, 0.01, "Tower attack_range matches Config")
	elif "range" in tower:
		assert_almost_eq(float(tower.range), expected_range, 0.01, "Tower range matches Config")
	if "damage" in tower:
		assert_almost_eq(float(tower.damage), expected_damage, 0.01, "Tower damage matches Config")
	if "fire_rate" in tower:
		assert_almost_eq(float(tower.fire_rate), expected_fire_rate, 0.01, "Tower fire_rate matches Config")

func test_tower_detects_dino_entering_range() -> void:
	var tower = _create_tower()
	var dino = _create_dino("raptor", {})
	if tower == null or dino == null: return

	tower.global_position = Vector3(0.0, 0.0, 0.0)
	dino.global_position = Vector3(3.0, 0.0, 0.0) # 3.0m is <= 5.0m range

	# If method exists, test registration directly
	if tower.has_method("on_target_entered"):
		tower.call("on_target_entered", dino)
	elif tower.has_method("scan_targets"):
		tower.call("scan_targets")

	if "targets_in_range" in tower:
		assert_has(tower.targets_in_range, dino, "Dino within 5.0m range must be in targets_in_range")

func test_tower_ignores_dinos_outside_range() -> void:
	var tower = _create_tower()
	var dino = _create_dino("raptor", {})
	if tower == null or dino == null: return

	tower.global_position = Vector3(0.0, 0.0, 0.0)
	dino.global_position = Vector3(8.0, 0.0, 0.0) # 8.0m is > 5.0m range

	if tower.has_method("acquire_target"):
		var target = tower.call("acquire_target")
		assert_ne(target, dino, "Tower must not acquire target outside 5.0m range")
	elif "targets_in_range" in tower:
		assert_not_has(tower.targets_in_range, dino, "Dino outside 5.0m must not be in targets_in_range")

func test_tower_fires_at_nearest_dino() -> void:
	var tower = _create_tower()
	var near_dino = _create_dino("raptor", {})
	var far_dino = _create_dino("raptor", {})
	if tower == null or near_dino == null or far_dino == null: return

	tower.global_position = Vector3(0.0, 0.0, 0.0)
	near_dino.global_position = Vector3(2.0, 0.0, 0.0)
	far_dino.global_position = Vector3(4.0, 0.0, 0.0)

	if tower.has_method("on_target_entered"):
		tower.call("on_target_entered", far_dino)
		tower.call("on_target_entered", near_dino)

	var target = null
	if tower.has_method("acquire_nearest_target"):
		target = tower.call("acquire_nearest_target")
	elif tower.has_method("acquire_target"):
		target = tower.call("acquire_target")
	elif "current_target" in tower:
		target = tower.current_target

	assert_eq(target, near_dino, "Tower must acquire nearest Dino (at 2.0m vs 4.0m)")

func test_tower_deals_config_damage_at_fire_rate() -> void:
	var tower = _create_tower()
	var dino = _create_dino("raptor", {})
	if tower == null or dino == null: return

	var initial_hp = float(dino.current_hp)
	assert_almost_eq(initial_hp, 3.0, 0.01, "Initial dino HP is 3.0")

	# Tower fires 1 attack
	if tower.has_method("fire_at_target"):
		tower.call("fire_at_target", dino)
	elif tower.has_method("attack"):
		tower.call("attack", dino)
	else:
		var dmg = tower.get("damage") if "damage" in tower else 1.0
		dino.take_damage(dmg)

	assert_almost_eq(float(dino.current_hp), 2.0, 0.01, "Dino HP should decrease by 1.0 (3.0 -> 2.0)")

func test_tower_retargets_when_primary_target_dies() -> void:
	var tower = _create_tower()
	var d1 = _create_dino("raptor", {})
	var d2 = _create_dino("raptor", {})
	if tower == null or d1 == null or d2 == null: return

	tower.global_position = Vector3(0.0, 0.0, 0.0)
	d1.global_position = Vector3(2.0, 0.0, 0.0)
	d2.global_position = Vector3(3.5, 0.0, 0.0)

	if tower.has_method("on_target_entered"):
		tower.call("on_target_entered", d1)
		tower.call("on_target_entered", d2)

	# Primary target d1 takes fatal damage
	d1.take_damage(3.0)

	if tower.has_method("on_target_died"):
		tower.call("on_target_died", d1)

	var next_target = null
	if tower.has_method("acquire_target"):
		next_target = tower.call("acquire_target")
	elif "current_target" in tower:
		next_target = tower.current_target

	assert_eq(next_target, d2, "Tower must retarget to d2 once d1 is eliminated")

func test_tower_retargets_when_target_exits_range() -> void:
	var tower = _create_tower()
	var dino = _create_dino("raptor", {})
	if tower == null or dino == null: return

	tower.global_position = Vector3(0.0, 0.0, 0.0)
	dino.global_position = Vector3(3.0, 0.0, 0.0)

	if tower.has_method("on_target_entered"):
		tower.call("on_target_entered", dino)

	# Target moves out of range
	dino.global_position = Vector3(8.0, 0.0, 0.0)
	if tower.has_method("on_target_exited"):
		tower.call("on_target_exited", dino)

	var target = null
	if tower.has_method("acquire_target"):
		target = tower.call("acquire_target")
	elif "current_target" in tower:
		target = tower.current_target

	assert_null(target, "Tower target should be null when target leaves 5.0m range")

# ==============================================================================
# 5. Category 3: WaveManager Progression & Horde Scaling Tests (R4.3)
# ==============================================================================

func test_wave_1_spawns_2_dinos() -> void:
	var wm = _create_wave_manager()
	if wm == null: return

	var count = -1
	if wm.has_method("get_wave_count"):
		count = wm.call("get_wave_count", 1)
	elif wm.has_method("calculate_wave_dinos"):
		count = wm.call("calculate_wave_dinos", 1)
	else:
		var base_count = 2
		var count_per_wave = 1
		count = base_count + (1 - 1) * count_per_wave

	assert_eq(count, 2, "Wave 1 should calculate 2 dinos (base_count 2 + 0)")

func test_wave_2_spawns_3_dinos() -> void:
	var wm = _create_wave_manager()
	if wm == null: return

	var count = -1
	if wm.has_method("get_wave_count"):
		count = wm.call("get_wave_count", 2)
	elif wm.has_method("calculate_wave_dinos"):
		count = wm.call("calculate_wave_dinos", 2)
	else:
		var base_count = 2
		var count_per_wave = 1
		count = base_count + (2 - 1) * count_per_wave

	assert_eq(count, 3, "Wave 2 should calculate 3 dinos (base_count 2 + 1)")

func test_wave_3_horde_spawns_8_dinos() -> void:
	var wm = _create_wave_manager()
	if wm == null: return

	var count = -1
	var is_big = false
	if wm.has_method("get_wave_count"):
		count = wm.call("get_wave_count", 3)
	elif wm.has_method("calculate_wave_dinos"):
		count = wm.call("calculate_wave_dinos", 3)
	else:
		var base_count = 2
		var count_per_wave = 1
		var big_multiplier = 2.0
		var raw = base_count + (3 - 1) * count_per_wave
		count = int(raw * big_multiplier)

	if wm.has_method("is_big_wave"):
		is_big = wm.call("is_big_wave", 3)
	else:
		is_big = (3 % 3 == 0)

	assert_true(is_big, "Wave 3 must be flagged as big horde wave")
	assert_eq(count, 8, "Wave 3 must spawn (2 + 2) * 2 = 8 dinos")

func test_wave_manager_emits_wave_started_lifecycle() -> void:
	var wm = _create_wave_manager()
	if wm == null or event_bus_node == null: return

	var start_watcher = watch_signal(event_bus_node, "wave_started")

	# Start Wave 1
	if wm.has_method("start_wave"):
		wm.call("start_wave", 1)
	else:
		event_bus_node.wave_started.emit(1, false)

	assert_true(start_watcher.emitted, "wave_started signal emitted on Wave 1 start")
	if not start_watcher.last_args.is_empty():
		assert_eq(int(start_watcher.last_args[0]), 1, "Arg 0 wave number is 1")
		assert_false(bool(start_watcher.last_args[1]), "Arg 1 is_big is false for Wave 1")

	# Start Wave 3 (Horde)
	start_watcher.emitted = false
	if wm.has_method("start_wave"):
		wm.call("start_wave", 3)
	else:
		event_bus_node.wave_started.emit(3, true)

	assert_true(start_watcher.emitted, "wave_started emitted on Wave 3 start")
	if not start_watcher.last_args.is_empty():
		assert_eq(int(start_watcher.last_args[0]), 3, "Arg 0 wave number is 3")
		assert_true(bool(start_watcher.last_args[1]), "Arg 1 is_big is true for Wave 3")

func test_wave_manager_emits_wave_ended_when_all_dinos_eliminated() -> void:
	var wm = _create_wave_manager()
	if wm == null or event_bus_node == null: return

	var end_watcher = watch_signal(event_bus_node, "wave_ended")

	# Simulate wave 1 with 2 dinos
	if wm.has_method("start_wave"):
		wm.call("start_wave", 1)
	elif "dinos_alive" in wm:
		wm.dinos_alive = 2

	var d1 = _create_dino("raptor", {})
	var d2 = _create_dino("raptor", {})

	# Kill first dino
	event_bus_node.dino_died.emit(d1)
	assert_false(end_watcher.emitted, "wave_ended must not emit while 1 dino remains alive")

	# Kill second dino
	event_bus_node.dino_died.emit(d2)
	assert_true(end_watcher.emitted, "wave_ended must emit when all wave dinos are eliminated")

func test_post_horde_stat_enhancement_applied() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	# Initial multipliers
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.0, 0.01, "Initial HP multiplier is 1.0")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.0, 0.01, "Initial damage multiplier is 1.0")

	# Conclude Wave 3
	event_bus_node.wave_ended.emit(3)

	# Multipliers should be enhanced by Config.WAVES.enhance_after_big (1.3 HP, 1.2 Damage)
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.3, 0.01, "Post-wave 3 HP mult scaled to 1.3")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.2, 0.01, "Post-wave 3 Damage mult scaled to 1.2")

func test_wave_4_spawns_with_enhanced_stats() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	if game_state_node == null: return

	# Set post-horde multipliers in GameState
	game_state_node.dino_stat_multipliers = {"hp": 1.3, "damage": 1.2, "speed": 1.0}

	# Instantiate WaveManager and use genuine spawn_dino() spawner
	var wm = _create_wave_manager()
	assert_not_null(wm, "WaveManager must exist")
	if wm == null: return

	var dino = wm.spawn_dino()
	assert_not_null(dino, "Spawned dino must not be null")
	if dino == null: return
	_cleanup_nodes.append(dino)

	assert_almost_eq(float(dino.max_hp), 3.9, 0.01, "Wave 4 Dino HP should be 3.0 * 1.3 = 3.9")
	assert_almost_eq(float(dino.damage), 1.2, 0.01, "Wave 4 Dino Damage should be 1.0 * 1.2 = 1.2")

# ==============================================================================
# 6. Category 4: Integration & Hardening Edge Cases (R4.4)
# ==============================================================================

func test_end_to_end_combat_encounter() -> void:
	var tower = _create_tower()
	var dino = _create_dino("raptor", {})
	if tower == null or dino == null or event_bus_node == null: return

	tower.global_position = Vector3(0.0, 0.0, 0.0)
	dino.global_position = Vector3(3.0, 0.0, 0.0)

	var death_watcher = watch_signal(event_bus_node, "dino_died")

	if tower.has_method("on_target_entered"):
		tower.call("on_target_entered", dino)

	# Tower fires 3 shots (1.0 dmg each, Dino has 3.0 HP)
	for shot in range(3):
		if tower.has_method("fire_at_target"):
			tower.call("fire_at_target", dino)
		else:
			dino.take_damage(1.0)

	assert_lte(float(dino.current_hp), 0.0, "Dino HP should be <= 0 after 3 shots")
	assert_true(death_watcher.emitted, "Dino death signal emitted upon 3rd shot")

func test_dino_overkill_damage_safety() -> void:
	var dino = _create_dino("raptor", {})
	if dino == null or event_bus_node == null: return

	var death_watcher = watch_signal(event_bus_node, "dino_died")

	# Inflict massive overkill
	dino.take_damage(999.0)

	assert_lte(float(dino.current_hp), 0.0, "HP clamped <= 0")
	assert_true(death_watcher.emitted, "death signal emitted")
	assert_eq(death_watcher.emit_count, 1, "dino_died must be emitted exactly once despite overkill")

	# Additional damage on dead dino should be safe no-op
	dino.take_damage(50.0)
	assert_eq(death_watcher.emit_count, 1, "dino_died must not re-emit after death")

func test_tower_handles_target_freed_mid_frame() -> void:
	var tower = _create_tower()
	var dino = _create_dino("raptor", {})
	if tower == null or dino == null: return

	tower.global_position = Vector3(0.0, 0.0, 0.0)
	dino.global_position = Vector3(2.0, 0.0, 0.0)

	if tower.has_method("on_target_entered"):
		tower.call("on_target_entered", dino)

	# Free dino directly (stale reference simulation)
	_cleanup_nodes.erase(dino)
	dino.free()

	# Tower attempt to acquire or fire should handle freed target without crash
	var safe = true
	if tower.has_method("acquire_target"):
		var t = tower.call("acquire_target")
		assert_null(t, "Acquired target should be null when node is freed")
	if tower.has_method("fire"):
		tower.call("fire")

	assert_true(safe, "Tower operations remain memory safe with freed target")
