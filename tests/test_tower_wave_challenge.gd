# res://tests/test_tower_wave_challenge.gd
# Milestone 4 Adversarial Empirical Challenge Suite:
# Stress tests Tower combat targeting and WaveManager progression:
# 1. High density dinosaur swarms (20-100 dinos) crossing 5.0m threshold simultaneously.
# 2. Nearest-target sorting accuracy oracle & retargeting jitter safety.
# 3. WaveManager 10+ consecutive wave progression, horde multiplier (3, 6, 9),
#    post-horde stat compounding, and turn loop lifecycle event timing.
# 4. Chaos injections, freed object handling, boundary precision tests,
#    and lifecycle stat persistence verification.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var dino_script: GDScript = null
var tower_script: GDScript = null
var wave_manager_script: GDScript = null
var wall_script: GDScript = null
var core_campfire_script: GDScript = null

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

	dino_script = _load_script(["res://scripts/entities/Dino.gd"])
	tower_script = _load_script(["res://scripts/entities/Tower.gd"])
	wave_manager_script = _load_script(["res://scripts/core/WaveManager.gd"])
	wall_script = _load_script(["res://scripts/entities/Wall.gd"])
	core_campfire_script = _load_script(["res://scripts/entities/CoreCampfire.gd"])

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
# Helpers & Factories
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_dino(pos: Vector3 = Vector3.ZERO, mults: Dictionary = {}) -> Object:
	assert_not_null(dino_script, "Dino.gd script must exist")
	if dino_script == null:
		return null
	var dino = dino_script.new()
	if dino is Node:
		_cleanup_nodes.append(dino)
		if tree != null and tree.root != null:
			tree.root.add_child(dino)
		if pos != Vector3.ZERO and "global_position" in dino:
			dino.global_position = pos
	if dino.has_method("setup"):
		dino.call("setup", "raptor", mults)
	return dino

func _create_tower(pos: Vector3 = Vector3.ZERO) -> Object:
	assert_not_null(tower_script, "Tower.gd script must exist")
	if tower_script == null:
		return null
	var tower = tower_script.new()
	if tower is Node:
		_cleanup_nodes.append(tower)
		if tree != null and tree.root != null:
			tree.root.add_child(tower)
		if pos != Vector3.ZERO and "global_position" in tower:
			tower.global_position = pos
	return tower

func _create_wave_manager() -> Object:
	assert_not_null(wave_manager_script, "WaveManager.gd script must exist")
	if wave_manager_script == null:
		return null
	var wm = wave_manager_script.new()
	if wm is Node:
		_cleanup_nodes.append(wm)
		if tree != null and tree.root != null:
			tree.root.add_child(wm)
	return wm

# ==============================================================================
# Category 1: High-Density Swarm Stress Tests (20-100 Dinos Crossing 5m)
# ==============================================================================

func test_challenge_tower_swarm_25_dinos_crossing_5m_threshold() -> void:
	var tower = _create_tower(Vector3.ZERO)
	if tower == null: return

	var dinos: Array[Object] = []
	# Spawn 25 dinos surrounding tower at radius ~4.8m
	for i in range(25):
		var angle = float(i) / 25.0 * TAU
		var r = 4.8
		var pos = Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		var d = _create_dino(pos)
		dinos.append(d)

	# Designate dino #7 as the strictly closest dino (radius 2.1m)
	dinos[7].global_position = Vector3(2.1, 0.0, 0.0)
	# Designate dino #18 as the second closest (radius 3.0m)
	dinos[18].global_position = Vector3(0.0, 0.0, 3.0)

	# Feed all 25 dinos simultaneously (simulating simultaneous crossing)
	for d in dinos:
		tower.on_target_entered(d)

	assert_gte(tower.targets_in_range.size(), 25, "All 25 dinos must be registered in targets_in_range")

	# Target acquisition must select dino #7
	var target = tower.acquire_target()
	assert_not_null(target, "Tower must acquire a valid target")
	assert_eq(target, dinos[7], "Nearest target among 25 swarm dinos must be dino #7 (2.1m)")

	# Tower fires at target
	var initial_hp = float(dinos[7].current_hp)
	tower.fire()
	assert_almost_eq(float(dinos[7].current_hp), initial_hp - 1.0, 0.01, "Target dino #7 took 1.0 damage")

	# Eliminate dino #7
	dinos[7].take_damage(dinos[7].current_hp)
	tower.on_target_died(dinos[7])

	# Next acquisition must select dino #18 (second nearest at 3.0m)
	var next_target = tower.acquire_target()
	assert_not_null(next_target, "Tower must reacquire after nearest dies")
	assert_eq(next_target, dinos[18], "Next target must be dino #18 (3.0m)")

func test_challenge_tower_swarm_30_dinos_identical_radial_distance() -> void:
	var tower = _create_tower(Vector3.ZERO)
	if tower == null: return

	var dinos: Array[Object] = []
	# 30 dinos all at exactly 3.5m radius
	for i in range(30):
		var angle = float(i) / 30.0 * TAU
		var pos = Vector3(cos(angle) * 3.5, 0.0, sin(angle) * 3.5)
		var d = _create_dino(pos)
		dinos.append(d)
		tower.on_target_entered(d)

	# Verify sort_custom handles identical distances without crashing or hanging
	var start_ms = Time.get_ticks_msec()
	var target = tower.acquire_target()
	var elapsed_ms = Time.get_ticks_msec() - start_ms

	assert_not_null(target, "Must acquire a valid dino among 30 identical distance candidates")
	assert_true(target in dinos, "Target must be one of the spawned dinos")
	assert_lte(elapsed_ms, 50, "Target sorting 30 identical dinos must execute well under 50ms")

	# Kill 5 consecutive targets and verify clean transitions
	for k in range(5):
		var cur = tower.current_target
		assert_not_null(cur, "Current target must be valid at step %d" % k)
		cur.take_damage(cur.current_hp)
		tower.on_target_died(cur)
		var nxt = tower.acquire_target()
		assert_not_null(nxt, "Must successfully select next target at step %d" % k)
		assert_ne(nxt, cur, "New target must not be the dead dino")

func test_challenge_tower_boundary_threshold_precision_grid() -> void:
	var tower = _create_tower(Vector3.ZERO)
	if tower == null: return

	# Tower range is 5.0, tolerance is 0.1 (effective 5.10)
	var d_in_1 = _create_dino(Vector3(4.90, 0.0, 0.0))
	var d_in_2 = _create_dino(Vector3(5.00, 0.0, 0.0))
	var d_in_3 = _create_dino(Vector3(5.08, 0.0, 0.0))
	var d_out_1 = _create_dino(Vector3(5.15, 0.0, 0.0))
	var d_out_2 = _create_dino(Vector3(5.50, 0.0, 0.0))
	var d_out_3 = _create_dino(Vector3(8.00, 0.0, 0.0))

	assert_true(tower._is_target_valid(d_in_1), "4.90m is valid target")
	assert_true(tower._is_target_valid(d_in_2), "5.00m is valid target")
	assert_true(tower._is_target_valid(d_in_3), "5.08m is valid target (within 5.0+0.1)")
	assert_false(tower._is_target_valid(d_out_1), "5.15m is strictly OUT of range")
	assert_false(tower._is_target_valid(d_out_2), "5.50m is strictly OUT of range")
	assert_false(tower._is_target_valid(d_out_3), "8.00m is strictly OUT of range")

	# Register all
	for d in [d_in_1, d_in_2, d_in_3, d_out_1, d_out_2, d_out_3]:
		tower.on_target_entered(d)

	# Target must be d_in_1 (4.90m)
	assert_eq(tower.acquire_target(), d_in_1, "Closest is 4.90m")
	d_in_1.take_damage(3.0)
	tower.on_target_died(d_in_1)

	# Next is d_in_2 (5.00m)
	assert_eq(tower.acquire_target(), d_in_2, "Next closest is 5.00m")
	d_in_2.take_damage(3.0)
	tower.on_target_died(d_in_2)

	# Next is d_in_3 (5.08m)
	assert_eq(tower.acquire_target(), d_in_3, "Next closest is 5.08m")
	d_in_3.take_damage(3.0)
	tower.on_target_died(d_in_3)

	# Out of range candidates must NOT be acquired
	var no_target = tower.acquire_target()
	assert_null(no_target, "No target acquired when remaining dinos are > 5.10m away")

func test_challenge_tower_massive_100_dinos_sorting_stress() -> void:
	var tower = _create_tower(Vector3.ZERO)
	if tower == null: return

	var closest_dino: Object = null
	var min_dist: float = 999.0

	# 100 dinos: 50 inside range (0.5 to 5.0m), 50 outside range (5.2 to 15.0m)
	for i in range(100):
		var dist = 0.5 + float(i) * 0.14 # 0.5 to 14.36m
		var pos = Vector3(dist, 0.0, 0.0)
		var d = _create_dino(pos)
		tower.on_target_entered(d)
		if dist <= 5.1 and dist < min_dist:
			min_dist = dist
			closest_dino = d

	var start_ms = Time.get_ticks_msec()
	var selected = tower.acquire_target()
	var elapsed_ms = Time.get_ticks_msec() - start_ms

	assert_not_null(selected, "Must acquire a target among 100 dinos")
	assert_eq(selected, closest_dino, "Must accurately select minimum distance dino (0.5m)")
	assert_lte(elapsed_ms, 100, "100-dino sort and filter must finish in <100ms")

# ==============================================================================
# Category 2: Sorting Oracle & Retargeting Jitter Safety
# ==============================================================================

func test_challenge_tower_nearest_sorting_oracle_complete_drain() -> void:
	var tower = _create_tower(Vector3.ZERO)
	if tower == null: return

	# Unsorted distances: 10 dinos
	var test_distances: Array[float] = [4.5, 1.2, 3.8, 0.5, 2.7, 4.9, 1.9, 3.1, 0.8, 2.2]
	var sorted_distances: Array[float] = test_distances.duplicate()
	sorted_distances.sort() # [0.5, 0.8, 1.2, 1.9, 2.2, 2.7, 3.1, 3.8, 4.5, 4.9]

	var dist_to_dino: Dictionary = {}
	for dist in test_distances:
		var d = _create_dino(Vector3(dist, 0.0, 0.0))
		dist_to_dino[dist] = d
		tower.on_target_entered(d)

	# Verify complete drain order matches the mathematical ascending sort
	for expected_dist in sorted_distances:
		var target = tower.acquire_target()
		var expected_dino = dist_to_dino[expected_dist]
		assert_not_null(target, "Target must exist for distance %.2f" % expected_dist)
		assert_eq(target, expected_dino, "Target must strictly match expected distance %.2f" % expected_dist)

		# Eliminate this target
		target.take_damage(target.current_hp)
		tower.on_target_died(target)

	assert_null(tower.acquire_target(), "Target must be null after draining all 10 dinos")

func test_challenge_tower_retargeting_jitter_prevention() -> void:
	var tower = _create_tower(Vector3.ZERO)
	if tower == null: return

	# Dino A at 3.5m
	var dino_a = _create_dino(Vector3(3.5, 0.0, 0.0))
	tower.on_target_entered(dino_a)
	assert_eq(tower.acquire_target(), dino_a, "Tower initially targets Dino A at 3.5m")

	# Dino B enters at 1.5m (closer than Dino A)
	var dino_b = _create_dino(Vector3(1.5, 0.0, 0.0))
	tower.on_target_entered(dino_b)

	# Trigger periodic fire timeout: Tower must NOT drop Dino A mid-burst (jitter safety)
	tower._on_fire_timer_timeout()
	assert_almost_eq(float(dino_a.current_hp), 2.0, 0.01, "Dino A shot, HP: 3.0 -> 2.0")
	assert_almost_eq(float(dino_b.current_hp), 3.0, 0.01, "Dino B untouched (no jitter switch)")
	assert_eq(tower.current_target, dino_a, "Tower current_target remains Dino A")

	# Finish killing Dino A
	dino_a.take_damage(2.0)
	tower.on_target_died(dino_a)

	# Once Dino A dies, Tower immediately acquires Dino B
	tower._on_fire_timer_timeout()
	assert_eq(tower.current_target, dino_b, "Tower smoothly retargeted to Dino B after Dino A died")
	assert_almost_eq(float(dino_b.current_hp), 2.0, 0.01, "Dino B shot by tower")

func test_challenge_tower_despawn_freed_mid_stream_safety() -> void:
	var tower = _create_tower(Vector3.ZERO)
	if tower == null: return

	var dinos: Array[Object] = []
	for i in range(15):
		var d = _create_dino(Vector3(1.0 + float(i) * 0.25, 0.0, 0.0))
		dinos.append(d)
		tower.on_target_entered(d)

	var primary = tower.acquire_target()
	assert_eq(primary, dinos[0], "Primary is dinos[0]")

	# Simulate unexpected node freeing / despawn WITHOUT calling death callbacks
	_cleanup_nodes.erase(dinos[0])
	dinos[0].free() # freed immediately

	_cleanup_nodes.erase(dinos[2])
	dinos[2].free()

	_cleanup_nodes.erase(dinos[4])
	dinos[4].free()

	# Operations must survive without crashing, memory errors, or null exceptions
	var new_target = tower.acquire_target()
	assert_not_null(new_target, "Tower acquires living target after freed nodes")
	assert_eq(new_target, dinos[1], "Next nearest living dino is dinos[1]")

	# Fire must safely hit new target
	tower.fire()
	assert_almost_eq(float(dinos[1].current_hp), 2.0, 0.01, "dinos[1] successfully damaged")

func test_challenge_tower_destroyed_stops_firing() -> void:
	var tower = _create_tower(Vector3.ZERO)
	var dino = _create_dino(Vector3(2.0, 0.0, 0.0))
	if tower == null or dino == null: return

	tower.on_target_entered(dino)
	tower.acquire_target()

	# Destroy the tower
	tower.take_damage(tower.current_hp)
	assert_true(tower.is_destroyed, "Tower is destroyed")

	# Fire timer timeout should be early-exited
	var dino_hp_before = float(dino.current_hp)
	tower._on_fire_timer_timeout()
	assert_almost_eq(float(dino.current_hp), dino_hp_before, 0.01, "Destroyed tower cannot fire")

# ==============================================================================
# Category 3: WaveManager Progression & Horde Scaling (15 Waves)
# ==============================================================================

func test_challenge_wavemanager_progression_math_15_waves() -> void:
	var wm = _create_wave_manager()
	if wm == null: return

	# Exact mathematical specification:
	# base_count = 2, count_per_wave = 1, big_every = 3, big_multiplier = 2.0
	var expected_counts = [
		0,   # index 0 unused
		2,   # 1
		3,   # 2
		8,   # 3 (Horde)
		5,   # 4
		6,   # 5
		14,  # 6 (Horde)
		8,   # 7
		9,   # 8
		20,  # 9 (Horde)
		11,  # 10
		12,  # 11
		26,  # 12 (Horde)
		14,  # 13
		15,  # 14
		32   # 15 (Horde)
	]

	for w in range(1, 16):
		var count = wm.get_wave_dino_count(w)
		var is_big = wm.is_big_wave(w)
		var expected_count = expected_counts[w]
		var expected_is_big = (w % 3 == 0)

		assert_eq(is_big, expected_is_big, "Wave %d is_big_wave flag" % w)
		assert_eq(count, expected_count, "Wave %d dino count: expected %d, got %d" % [w, expected_count, count])

func test_challenge_wavemanager_12_waves_compounding_stat_verification() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var wm = _create_wave_manager()
	if wm == null: return

	# Initial multipliers
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.0, 0.001)
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.0, 0.001)

	# Compounding rule: enhance_after_big: hp=1.3, damage=1.2, speed=1.0 at waves 3, 6, 9, 12
	var expected_hp_mults = {
		1: 1.0,
		2: 1.0,
		3: 1.0,
		4: 1.3,
		5: 1.3,
		6: 1.3,
		7: 1.69,
		8: 1.69,
		9: 1.69,
		10: 2.197,
		11: 2.197,
		12: 2.197
	}
	var expected_dmg_mults = {
		1: 1.0,
		2: 1.0,
		3: 1.0,
		4: 1.2,
		5: 1.2,
		6: 1.2,
		7: 1.44,
		8: 1.44,
		9: 1.44,
		10: 1.728,
		11: 1.728,
		12: 1.728
	}

	for w in range(1, 13):
		# Start wave
		wm.start_wave(w)
		assert_eq(wm.current_wave, w, "WaveManager current_wave is %d" % w)

		# Verify GameState multipliers before wave completion
		var exp_hp = expected_hp_mults[w]
		var exp_dmg = expected_dmg_mults[w]
		assert_almost_eq(float(game_state_node.dino_stat_multipliers["hp"]), exp_hp, 0.01,
			"Wave %d running HP mult expected %.3f" % [w, exp_hp])
		assert_almost_eq(float(game_state_node.dino_stat_multipliers["damage"]), exp_dmg, 0.01,
			"Wave %d running Damage mult expected %.3f" % [w, exp_dmg])

		# Spawn a dino and verify its actual runtime attributes match compounded stats
		var dino = wm.spawn_dino()
		if dino != null:
			_cleanup_nodes.append(dino)
			var exp_dino_hp = 3.0 * exp_hp
			var exp_dino_dmg = 1.0 * exp_dmg
			assert_almost_eq(float(dino.max_hp), exp_dino_hp, 0.01,
				"Wave %d spawned Dino max_hp expected %.3f, got %.3f" % [w, exp_dino_hp, dino.max_hp])
			assert_almost_eq(float(dino.damage), exp_dino_dmg, 0.01,
				"Wave %d spawned Dino damage expected %.3f, got %.3f" % [w, exp_dino_dmg, dino.damage])

		# End the wave via EventBus (triggers GameState._on_wave_ended)
		event_bus_node.wave_ended.emit(w)

	# After wave 12 ended, multipliers compounded 4 times (1.3^4 = 2.8561, 1.2^4 = 2.0736)
	assert_almost_eq(float(game_state_node.dino_stat_multipliers["hp"]), 2.8561, 0.01,
		"Post-Wave 12 HP mult compounded 4x to 2.8561")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers["damage"]), 2.0736, 0.01,
		"Post-Wave 12 Damage mult compounded 4x to 2.0736")

func test_challenge_wavemanager_10_waves_turn_loop_lifecycle() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(event_bus_node, "EventBus must exist")
	if game_state_node == null or event_bus_node == null: return

	var wm = _create_wave_manager()
	if wm == null: return

	var wave_start_watcher = watch_signal(event_bus_node, "wave_started")
	var wave_end_watcher = watch_signal(event_bus_node, "wave_ended")

	for w in range(1, 11):
		# 1. PLAN Phase -> Trigger End Action to transition to ATTACK Phase
		game_state_node.set_phase(0) # PLAN
		assert_eq(int(game_state_node.current_phase), 0, "Current phase is PLAN before wave %d" % w)

		# End action switches to ATTACK (Phase 1)
		game_state_node.trigger_end_action()
		assert_eq(int(game_state_node.current_phase), 1, "Phase shifted to ATTACK for wave %d" % w)

		# WaveManager._on_phase_changed(1) automatically starts the wave
		assert_true(wm.is_wave_active, "WaveManager is_wave_active must be true for wave %d" % w)
		assert_eq(wm.current_wave, w, "WaveManager current_wave must be %d" % w)
		assert_eq(game_state_node.wave_number, w, "GameState wave_number synchronized to %d" % w)

		# Verify wave_started signal arguments
		assert_true(wave_start_watcher.emitted, "wave_started emitted for wave %d" % w)
		assert_eq(int(wave_start_watcher.last_args[0]), w, "wave_started wave_num is %d" % w)
		assert_eq(bool(wave_start_watcher.last_args[1]), (w % 3 == 0), "wave_started is_big flag for wave %d" % w)
		wave_start_watcher.emitted = false

		# 2. Simulate elimination of all dinos in the wave
		var total_dinos = wm.dinos_alive_count
		assert_gt(total_dinos, 0, "Wave %d must have > 0 dinos alive" % w)

		for i in range(total_dinos):
			event_bus_node.dino_died.emit(null)

		# Wave should now be completed
		assert_false(wm.is_wave_active, "WaveManager is_wave_active is false after all deaths in wave %d" % w)
		assert_true(wave_end_watcher.emitted, "wave_ended emitted for wave %d" % w)
		assert_eq(int(wave_end_watcher.last_args[0]), w, "wave_ended wave_num is %d" % w)
		wave_end_watcher.emitted = false

		# GameState._on_wave_ended automatically switches to PRODUCE phase (Phase 2)
		assert_eq(int(game_state_node.current_phase), 2, "Phase shifted to PRODUCE after wave %d ended" % w)

		# Conclude PRODUCE phase -> returns to PLAN
		game_state_node.end_produce_phase()
		assert_eq(int(game_state_node.current_phase), 0, "Phase returned to PLAN ready for next turn")

# ==============================================================================
# Category 4: Chaos Injections, Lifecycle Bugs & Edge Cases
# ==============================================================================

func test_challenge_dino_ready_lifecycle_wipes_stat_multipliers() -> void:
	assert_not_null(dino_script, "Dino script must exist")
	if dino_script == null: return

	# 1. Instantiate Dino and configure with 2.0x HP multiplier (expected 6.0 HP)
	var dino = dino_script.new()
	_cleanup_nodes.append(dino)
	dino.setup("raptor", {"hp": 2.0, "damage": 2.0})

	assert_almost_eq(float(dino.max_hp), 6.0, 0.01, "Pre-tree: Dino max_hp correctly set to 6.0")
	assert_almost_eq(float(dino.damage), 2.0, 0.01, "Pre-tree: Dino damage correctly set to 2.0")

	# 2. Add dino to scene tree (triggers Godot _ready() lifecycle)
	tree.root.add_child(dino)

	# 3. Assert stats survive _ready() lifecycle
	assert_almost_eq(float(dino.max_hp), 6.0, 0.01,
		"VULNERABILITY DETECTED: Dino max_hp was wiped out by _ready() -> _load_config_stats()")
	assert_almost_eq(float(dino.damage), 2.0, 0.01,
		"VULNERABILITY DETECTED: Dino damage was wiped out by _ready() -> _load_config_stats()")

func test_challenge_wavemanager_anomalous_signals_handling() -> void:
	var wm = _create_wave_manager()
	if wm == null or event_bus_node == null: return

	var end_watcher = watch_signal(event_bus_node, "wave_ended")

	# 1. dino_died signal emitted while no wave is active -> safe no-op
	assert_false(wm.is_wave_active, "No wave active initially")
	event_bus_node.dino_died.emit(null)
	assert_false(end_watcher.emitted, "wave_ended must NOT emit when no wave is active")

	# 2. Start wave with 2 dinos
	wm.start_wave(1)
	assert_true(wm.is_wave_active, "Wave 1 active")
	assert_eq(wm.dinos_alive_count, 2, "Wave 1 starts with 2 dinos")

	# 3. Kill both dinos
	event_bus_node.dino_died.emit(null)
	event_bus_node.dino_died.emit(null)
	assert_true(end_watcher.emitted, "wave_ended emitted on second death")
	assert_false(wm.is_wave_active, "Wave is now inactive")

	# 4. Excess death signal -> dinos_alive_count should clamp at 0 and not emit duplicate wave_ended
	end_watcher.emitted = false
	event_bus_node.dino_died.emit(null)
	assert_eq(wm.dinos_alive_count, 0, "dinos_alive_count clamped at 0")
	assert_false(end_watcher.emitted, "Duplicate wave_ended must NOT be emitted for excess death")

func test_challenge_wavemanager_invalid_wave_number_clamping() -> void:
	var wm = _create_wave_manager()
	if wm == null: return

	var count_zero = wm.get_wave_dino_count(0)
	var count_negative = wm.get_wave_dino_count(-10)

	assert_eq(count_zero, 2, "Wave 0 clamps to Wave 1 (2 dinos)")
	assert_eq(count_negative, 2, "Wave -10 clamps to Wave 1 (2 dinos)")

func test_challenge_tower_target_with_zero_or_negative_hp_rejected() -> void:
	var tower = _create_tower(Vector3.ZERO)
	var dino = _create_dino(Vector3(2.0, 0.0, 0.0))
	if tower == null or dino == null: return

	assert_true(tower._is_target_valid(dino), "Dino with 3.0 HP is valid target")

	dino.current_hp = 0.0
	assert_false(tower._is_target_valid(dino), "Dino with 0.0 HP must be rejected by _is_target_valid")

	dino.current_hp = -5.0
	assert_false(tower._is_target_valid(dino), "Dino with negative HP must be rejected by _is_target_valid")
