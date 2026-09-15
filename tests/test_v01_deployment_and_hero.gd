# res://tests/test_v01_deployment_and_hero.gd
# Comprehensive Verification Suite for Defend Dinosaur v0.1:
# 1. Real-Time Deployment (DEPLOY phase countdown, auto-advance, zero AP requirement).
# 2. In-Game Pause System (freezes timer, movement, construction without freezing SceneTree).
# 3. Modern Hero Entity (CharacterBody3D, click-to-move, walk-to-build, combat).
# 4. Hero Death triggers immediate Game Over (game_lost).
# 5. Semi-finished buildings (progress retention, layer 0 no-collision during ATTACK).
# 6. Hero invisibility & invulnerability during ATTACK phase.
# 7. Dinosaur Nest blackbox & Guard Dinosaur AI (roam, aggro chase, leash back).
# 8. Large flock (10+ dinos) dynamic flanking & surround pathing.
extends "res://tests/test_base.gd"

var config_node: Node = null
var event_bus_node: Node = null
var game_state_node: Node = null

var hero_script: GDScript = null
var guard_dino_script: GDScript = null
var dino_script: GDScript = null
var nest_script: GDScript = null
var building_script: GDScript = null
var wall_script: GDScript = null
var tower_script: GDScript = null
var lumber_script: GDScript = null
var grid_manager_script: GDScript = null
var build_system_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if ResourceLoader.exists("res://scripts/entities/Hero.gd"):
		hero_script = load("res://scripts/entities/Hero.gd")
	if ResourceLoader.exists("res://scripts/entities/GuardDino.gd"):
		guard_dino_script = load("res://scripts/entities/GuardDino.gd")
	if ResourceLoader.exists("res://scripts/entities/Dino.gd"):
		dino_script = load("res://scripts/entities/Dino.gd")
	if ResourceLoader.exists("res://scripts/entities/Nest.gd"):
		nest_script = load("res://scripts/entities/Nest.gd")
	if ResourceLoader.exists("res://scripts/entities/Building.gd"):
		building_script = load("res://scripts/entities/Building.gd")
	if ResourceLoader.exists("res://scripts/entities/Wall.gd"):
		wall_script = load("res://scripts/entities/Wall.gd")
	if ResourceLoader.exists("res://scripts/entities/Tower.gd"):
		tower_script = load("res://scripts/entities/Tower.gd")
	if ResourceLoader.exists("res://scripts/entities/LumberHut.gd"):
		lumber_script = load("res://scripts/entities/LumberHut.gd")
	if ResourceLoader.exists("res://scripts/core/GridManager.gd"):
		grid_manager_script = load("res://scripts/core/GridManager.gd")
	if ResourceLoader.exists("res://scripts/core/BuildSystem.gd"):
		build_system_script = load("res://scripts/core/BuildSystem.gd")

func after_each() -> void:
	for node in _cleanup_nodes:
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.get_parent().remove_child(node)
			node.free()
	_cleanup_nodes.clear()

	if game_state_node:
		if "infinite_ap" in game_state_node:
			game_state_node.infinite_ap = false
		if game_state_node.has_method("reset_game"):
			game_state_node.reset_game()

# ==============================================================================
# 1. Configuration Constants Integrity (v0.1)
# ==============================================================================

func test_01_config_v01_parameters_integrity() -> void:
	assert_not_null(config_node, "Config autoload must exist")
	assert_true("TIME" in config_node, "Config must define TIME dictionary")
	var time_cfg: Dictionary = config_node.get("TIME")
	assert_almost_eq(float(time_cfg.get("deploy_length", 0.0)), 90.0, 0.01, "deploy_length must be 90.0s")
	assert_almost_eq(float(time_cfg.get("build_range", 0.0)), 1.5, 0.01, "build_range must be 1.5m")
	assert_true(bool(time_cfg.get("allow_pause", false)), "allow_pause must be true")

	assert_true("HERO" in config_node, "Config must define HERO dictionary")
	var hero_cfg: Dictionary = config_node.get("HERO")
	assert_almost_eq(float(hero_cfg.get("hp", 0.0)), 10.0, 0.01, "HERO hp must be 10.0")
	assert_almost_eq(float(hero_cfg.get("move_speed", 0.0)), 4.0, 0.01, "HERO move_speed must be 4.0 m/s")
	assert_almost_eq(float(hero_cfg.get("damage", 0.0)), 1.0, 0.01, "HERO damage must be 1.0")
	assert_almost_eq(float(hero_cfg.get("attack_range", 0.0)), 2.0, 0.01, "HERO attack_range must be 2.0m")

	assert_true("NEST_GUARDS" in config_node, "Config must define NEST_GUARDS dictionary")
	var guards_cfg: Dictionary = config_node.get("NEST_GUARDS")
	assert_eq(int(guards_cfg.get("count", 0)), 3, "NEST_GUARDS count must be 3")
	assert_almost_eq(float(guards_cfg.get("post_radius", 0.0)), 3.0, 0.01, "post_radius must be 3.0m")
	assert_almost_eq(float(guards_cfg.get("aggro_radius", 0.0)), 6.0, 0.01, "aggro_radius must be 6.0m")
	assert_almost_eq(float(guards_cfg.get("leash_radius", 0.0)), 12.0, 0.01, "leash_radius must be 12.0m")

	var buildings: Dictionary = config_node.get("BUILDINGS")
	# Build time is derived from price rather than stated per building.
	for b_type in ["wall", "tower", "lumber_hut"]:
		assert_true(buildings.has(b_type), "%s is in the catalog" % b_type)
		assert_gt(config_node.get_build_time(b_type), 0.0, "%s has a positive derived build time" % b_type)

# ==============================================================================
# 2. Real-Time Deployment Countdown & Auto-Advance
# ==============================================================================

func test_02_deploy_timer_countdown_and_phase_transition() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	game_state_node.reset_game()

	assert_eq(int(game_state_node.current_phase), 0, "Phase must start at DEPLOY (0)")
	assert_almost_eq(float(game_state_node.remaining_deploy_time), 90.0, 0.01, "remaining_deploy_time is 90.0")

	# Simulate 10 seconds of deployment
	game_state_node._process(10.0)
	assert_almost_eq(float(game_state_node.remaining_deploy_time), 80.0, 0.01, "Timer ticks down to 80.0s")
	assert_eq(int(game_state_node.current_phase), 0, "Phase remains DEPLOY")

	# Simulate remaining 80 seconds down to 0
	game_state_node._process(80.0)
	assert_almost_eq(float(game_state_node.remaining_deploy_time), 0.0, 0.01, "Timer reaches 0.0s")
	assert_eq(int(game_state_node.current_phase), 1, "Phase automatically transitions to ATTACK (1)")

# ==============================================================================
# 3. In-Game Pause System
# ==============================================================================

func test_03_pause_system_toggling_and_timer_freezing() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	game_state_node.reset_game()

	var pause_watcher = watch_signal(event_bus_node, "pause_toggled")
	assert_false(bool(game_state_node.is_paused), "is_paused starts false")

	var new_p = game_state_node.toggle_pause()
	assert_true(new_p, "toggle_pause returns true")
	assert_true(bool(game_state_node.is_paused), "is_paused is true")
	assert_true(pause_watcher.emitted, "pause_toggled signal emitted")

	# Process while paused: timer should not advance
	game_state_node._process(15.0)
	assert_almost_eq(float(game_state_node.remaining_deploy_time), 90.0, 0.01, "Timer does NOT tick down while paused")

	# Unpause
	game_state_node.toggle_pause()
	assert_false(bool(game_state_node.is_paused), "is_paused is false after second toggle")
	game_state_node._process(5.0)
	assert_almost_eq(float(game_state_node.remaining_deploy_time), 85.0, 0.01, "Timer resumes ticking after unpause")

# ==============================================================================
# 4. Early End Deployment API
# ==============================================================================

func test_04_early_end_deployment() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	game_state_node.reset_game()

	assert_eq(int(game_state_node.current_phase), 0, "Starts at DEPLOY")
	game_state_node.trigger_early_end_deploy()
	assert_eq(int(game_state_node.current_phase), 1, "trigger_early_end_deploy advances to ATTACK")

# ==============================================================================
# 5. Modern Hero Entity Creation & Movement
# ==============================================================================

func test_05_hero_entity_creation_and_movement() -> void:
	assert_not_null(hero_script, "Hero.gd script must exist")
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)

	assert_almost_eq(hero.max_hp, 10.0, 0.01, "Hero max_hp is 10.0")
	assert_almost_eq(hero.current_hp, 10.0, 0.01, "Hero current_hp is 10.0")
	assert_almost_eq(hero.speed, 4.0, 0.01, "Hero speed is 4.0")
	assert_true(hero.is_in_group("hero"), "Hero in 'hero' group")

	# Click to move
	hero.position = Vector3(0.0, 0.0, 0.0)
	hero.move_to(Vector3(4.0, 0.0, 0.0))
	assert_eq(int(hero.current_state), 1, "Hero state is MOVING (1)")

	# Physics tick 0.5s: moves speed 4.0 * 0.5s = 2.0m
	hero._physics_process(0.5)
	assert_almost_eq(hero.global_position.x, 2.0, 0.15, "Hero moved 2.0m along X axis")

# ==============================================================================
# 6. Hero Walk-to-Build & Construction Progress
# ==============================================================================

func test_06_hero_walk_to_build_and_construction() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")

	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = Vector3(0.0, 0.0, 0.0)

	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.position = Vector3(2.0, 0.0, 0.0) # 2.0m away (> build_range 1.5m)
	wall.start_construction(2.0)           # 2.0s construction time

	assert_false(wall.is_constructed, "Wall starts unconstructed")
	assert_almost_eq(wall.build_progress, 0.0, 0.01, "Wall build_progress is 0.0")
	assert_eq(wall.collision_layer, 0, "Unfinished building has collision_layer 0")

	# Order hero to build
	hero.order_build(wall)
	assert_eq(int(hero.current_state), 1, "Hero enters MOVING towards building")

	# Walk closer (0.2s * 4m/s = 0.8m) -> pos becomes ~0.8m, distance to wall is 1.2m (<= 1.5m build_range)
	hero._physics_process(0.25)
	hero._physics_process(0.01) # Switch to BUILDING
	assert_eq(int(hero.current_state), 2, "Hero enters BUILDING (2) when within build_range")

	# Advance construction 1.0s (50% of 2.0s)
	hero._physics_process(1.0)
	assert_almost_eq(wall.build_progress, 0.5, 0.05, "Wall build_progress is 50%")
	assert_false(wall.is_constructed, "Wall still unfinished at 50%")

	# Advance remaining 1.0s
	hero._physics_process(1.0)
	assert_almost_eq(wall.build_progress, 1.0, 0.01, "Wall build_progress reached 100%")
	assert_true(wall.is_constructed, "Wall is now fully constructed")
	assert_eq(wall.collision_layer, 2, "Wall collision_layer restored to 2 (Buildings)")
	assert_eq(int(hero.current_state), 0, "Hero returns to IDLE after completing construction")

# ==============================================================================
# 7. Semi-finished Buildings Ignored in ATTACK Phase
# ==============================================================================

func test_07_semifinished_buildings_have_no_collision_or_production() -> void:
	assert_not_null(tower_script, "Tower.gd must exist")
	assert_not_null(lumber_script, "LumberHut.gd must exist")

	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	tower.start_construction(6.0)
	assert_false(tower.is_constructed, "Tower is unconstructed")
	assert_eq(tower.collision_layer, 0, "Unfinished tower collision_layer is 0")
	assert_null(tower.acquire_target(), "Unfinished tower cannot acquire targets")

	var lumber = lumber_script.new()
	_cleanup_nodes.append(lumber)
	tree.root.add_child(lumber)
	lumber.start_construction(4.0)
	assert_false(lumber.is_constructed, "LumberHut is unconstructed")

	var init_wood = game_state_node.resources.get("wood", 10)
	event_bus_node.produce_phase.emit()
	assert_eq(game_state_node.resources.get("wood", 10), init_wood, "Unfinished lumber hut produces nothing")

# ==============================================================================
# 8. Hero Death Triggers Immediate Game Over (game_lost)
# ==============================================================================

func test_08_hero_death_triggers_game_lost() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	game_state_node.reset_game()

	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)

	var hero_died_watcher = watch_signal(event_bus_node, "hero_died")
	var game_lost_watcher = watch_signal(event_bus_node, "game_lost")

	hero.take_damage(5.0)
	assert_almost_eq(hero.current_hp, 5.0, 0.01, "Hero HP drops to 5.0")
	assert_false(hero_died_watcher.emitted, "Hero not dead yet")

	hero.take_damage(5.0)
	assert_almost_eq(hero.current_hp, 0.0, 0.01, "Hero HP reaches 0.0")
	assert_true(hero_died_watcher.emitted, "hero_died signal emitted")
	assert_true(game_lost_watcher.emitted, "game_lost signal emitted upon Hero death")
	assert_true(game_state_node.is_game_over, "GameState marked is_game_over")
	assert_false(game_state_node.is_game_won, "GameState is_game_won is false (Defeat)")

# ==============================================================================
# 9. Hero Invisibility & Invulnerability in ATTACK Phase
# ==============================================================================

func test_09_hero_hidden_during_attack_phase() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)

	assert_true(hero.visible, "Hero visible in DEPLOY phase")
	assert_eq(hero.collision_layer, 4, "Hero collision_layer is 4")

	# Enter ATTACK phase (phase 1)
	event_bus_node.phase_changed.emit(1)
	assert_false(hero.visible, "Hero becomes hidden during ATTACK phase")
	assert_eq(hero.collision_layer, 0, "Hero collision_layer disabled in ATTACK phase")

	# Enter DEPLOY phase (phase 0)
	event_bus_node.phase_changed.emit(0)
	assert_true(hero.visible, "Hero becomes visible again in DEPLOY phase")
	assert_eq(hero.collision_layer, 4, "Hero collision_layer restored in DEPLOY phase")

# ==============================================================================
# 10. Guard Dinosaur AI: Roam, Aggro Chase & Leash Back
# ==============================================================================

func test_10_guard_dino_roam_aggro_and_leash() -> void:
	assert_not_null(guard_dino_script, "GuardDino.gd must exist")
	assert_not_null(hero_script, "Hero.gd must exist")

	var guard = guard_dino_script.new()
	_cleanup_nodes.append(guard)
	tree.root.add_child(guard)
	guard.setup_post(Vector3(0.0, 0.0, -15.0))
	assert_eq(int(guard.guard_state), 0, "Guard starts in POST_ROAM (0)")

	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = Vector3(0.0, 0.0, -11.0) # 4.0m away (within aggro_radius 6.0m)

	# Physics tick detects Hero
	guard._physics_process(0.1)
	assert_eq(int(guard.guard_state), 1, "Guard enters AGGRO_CHASE (1) upon detecting Hero")
	assert_eq(guard.chase_target, hero, "Guard targets Hero")

	# Move Hero beyond leash_radius (> 12m from post at -15)
	hero.position = Vector3(0.0, 0.0, 0.0) # 15m away
	guard.global_position = Vector3(0.0, 0.0, -1.0) # Chased 14m from post

	guard._physics_process(0.1)
	assert_eq(int(guard.guard_state), 3, "Guard enters RETURNING (3) when chased beyond leash_radius")
	assert_null(guard.chase_target, "Guard clears chase_target when leashing")

# ==============================================================================
# 11. Hero Can Attack Nest & Guard Dinos in DEPLOY Phase
# ==============================================================================

func test_11_hero_can_attack_guard_and_nest() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(nest_script, "Nest.gd must exist")

	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = Vector3(0.0, 0.0, 0.0)

	var nest = nest_script.new()
	_cleanup_nodes.append(nest)
	tree.root.add_child(nest)
	nest.position = Vector3(1.0, 0.0, 0.0) # 1.0m away (within attack_range 2.0m)

	var init_hp = nest.current_hp
	hero.order_attack(nest)
	hero._physics_process(0.05)
	assert_eq(int(hero.current_state), 3, "Hero enters ATTACKING state")

	hero._physics_process(0.05) # Deals damage
	assert_lt(nest.current_hp, init_hp, "Nest took damage from Hero attack")

# ==============================================================================
# 12. 10+ Dinosaur Flock Dynamic Flanking & Surround
# ==============================================================================

func test_12_dino_flock_flanking_and_surround() -> void:
	assert_not_null(dino_script, "Dino.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")

	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.position = Vector3(0.0, 0.0, 0.0)

	var dino_front = dino_script.new()
	_cleanup_nodes.append(dino_front)
	tree.root.add_child(dino_front)
	dino_front.position = Vector3(0.0, 0.0, -1.0)
	dino_front.on_obstacle_detected(wall)
	assert_eq(int(dino_front.current_state), 1, "Front dino is ATTACKING")

	var dino_back = dino_script.new()
	_cleanup_nodes.append(dino_back)
	tree.root.add_child(dino_back)
	dino_back.position = Vector3(0.0, 0.0, -2.5) # Behind front dino
	var wps: Array[Vector3] = [Vector3(0.0, 0.0, -2.5), Vector3(0.0, 0.0, 0.0)]
	dino_back.set_waypoints(wps)
	dino_back.current_waypoint_index = 1

	# Back dino advances: detects front attacking ally and initiates flanking steer
	dino_back.advance_towards_waypoint(0.1)
	assert_true(absf(dino_back.velocity.x) > 0.001 or dino_back.current_state == 1,
		"Back dino performs lateral flanking steer or attacks target directly instead of stalling")

# ==============================================================================
# 13. Hero Physics Collision with Buildings (Cannot Penetrate Walls)
# ==============================================================================

func test_13_hero_physics_collision_with_walls_cannot_penetrate() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")

	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.position = Vector3(2.0, 0.0, 0.0)
	wall.complete_construction() # collision_layer = 2

	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = Vector3(0.0, 0.0, 0.0)

	# Verify hero collision mask includes Layer 2 (Buildings)
	assert_true((hero.collision_mask & 2) != 0, "Hero collision_mask must include Layer 2 (Buildings)")

	# Wait for physics engine broadphase synchronization
	await wait_frames(2)

	# Command hero to move past the wall to X=5.0
	hero.move_to(Vector3(5.0, 0.0, 0.0))
	assert_eq(int(hero.current_state), 1, "Hero is MOVING towards destination")

	# Simulate multiple physics frames
	for _frame in range(30):
		await wait_frames(1)
		hero._physics_process(0.05)

	# Hero must be stopped by the wall and cannot penetrate through it (X must remain < 1.6)
	assert_lt(hero.global_position.x, 1.6, "Hero is physically blocked by Wall and cannot penetrate it")

# ==============================================================================
# 14. Infinite AP Mode Allows Building Gated Strictly by Resources
# ==============================================================================

func test_14_infinite_ap_mode_allows_continuous_building_with_resources() -> void:
	assert_not_null(game_state_node, "GameState must exist")
	assert_not_null(grid_manager_script, "GridManager must exist")
	assert_not_null(build_system_script, "BuildSystem must exist")

	var grid_mgr = grid_manager_script.new()
	_cleanup_nodes.append(grid_mgr)
	tree.root.add_child(grid_mgr)

	var build_sys = build_system_script.new()
	_cleanup_nodes.append(build_sys)
	tree.root.add_child(build_sys)
	build_sys.setup(grid_mgr)

	game_state_node.reset_game()
	game_state_node.infinite_ap = true
	game_state_node.resources = {"wood": cost_of("wall") * 4, "stone": 0, "water": 0, "food": 0}

	# Infinite AP: can_spend_ap returns true regardless of amount
	assert_true(game_state_node.can_spend_ap(99), "infinite_ap mode allows can_spend_ap for any amount")

	# Place exactly as many walls as the seeded wood affords
	for i in range(4):
		var cell = Vector2i(20 + i, 20)
		var b = build_sys.place_building("wall", cell)
		if b is Node: _cleanup_nodes.append(b)
		assert_not_null(b, "Wall %d placed successfully under infinite AP" % (i + 1))

	assert_eq(game_state_node.resources["wood"], 0, "All seeded wood consumed across 4 walls")
	# 5th placement fails due to 0 wood, not AP
	var fail_b = build_sys.place_building("wall", Vector2i(25, 20))
	assert_null(fail_b, "5th placement rejected due to wood shortage")

# ==============================================================================
# 15. Dinosaur Perimeter Attack Slots Encircle & Anti-Jitter Lock
# ==============================================================================

func test_15_dino_attack_slots_encircle_and_anti_jitter_lock() -> void:
	assert_not_null(dino_script, "Dino.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")

	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.position = Vector3(0.0, 0.0, 0.0)

	# Claim distinct attack slots for 4 dinos around the wall
	var claimed_slots: Array[Vector3] = []
	for i in range(4):
		var dino = dino_script.new()
		_cleanup_nodes.append(dino)
		tree.root.add_child(dino)
		dino.position = Vector3(float(i) * 0.5, 0.0, -3.0)

		var slot = dino_script.claim_attack_slot(wall, dino)
		assert_true(slot != Vector3.ZERO, "Dino %d claimed a valid attack slot" % i)
		assert_false(claimed_slots.has(slot), "Dino %d claimed a unique attack slot" % i)
		claimed_slots.append(slot)

	# Verify attacking state locks velocity to ZERO (Anti-Jitter)
	var attacker = dino_script.new()
	_cleanup_nodes.append(attacker)
	tree.root.add_child(attacker)
	attacker.position = Vector3(0.0, 0.0, -1.2)
	attacker.on_obstacle_detected(wall)

	assert_eq(int(attacker.current_state), 1, "Attacker state is ATTACKING (1)")
	assert_eq(attacker.velocity, Vector3.ZERO, "Attacker velocity locked at ZERO")

	# Running _process_attacking preserves ZERO velocity (no separation jitter)
	attacker._process_attacking(0.1)
	assert_eq(attacker.velocity, Vector3.ZERO, "Attacker velocity remains ZERO without jitter")

# ==============================================================================
# 16. Controls Configuration SSoT & RTS Right-Click Move Default
# ==============================================================================

func test_16_controls_configuration_and_rts_defaults() -> void:
	assert_not_null(config_node, "Config autoload must exist")
	assert_true("CONTROLS" in config_node, "Config must define CONTROLS dictionary")

	var controls: Dictionary = config_node.CONTROLS
	assert_eq(controls.get("hero_move_button"), MOUSE_BUTTON_RIGHT, "hero_move_button must default to MOUSE_BUTTON_RIGHT")
	assert_eq(controls.get("build_place_button"), MOUSE_BUTTON_LEFT, "build_place_button must default to MOUSE_BUTTON_LEFT")
	assert_eq(controls.get("cancel_key"), KEY_ESCAPE, "cancel_key must default to KEY_ESCAPE")
	assert_eq(controls.get("pause_key"), KEY_SPACE, "pause_key must default to KEY_SPACE")

# ==============================================================================
# 17. Defense Tower Never Targets or Attacks Hero
# ==============================================================================

func test_17_tower_never_targets_or_attacks_hero() -> void:
	assert_not_null(tower_script, "Tower.gd must exist")
	assert_not_null(hero_script, "Hero.gd must exist")

	var tower = tower_script.new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	tower.position = Vector3(0.0, 0.0, 0.0)
	tower.complete_construction()

	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = Vector3(1.0, 0.0, 0.0) # 1.0m away (well within 5.0m attack range)

	await wait_frames(2)

	# Verify tower target validation explicitly rejects Hero
	assert_false(tower._is_target_valid(hero), "Tower._is_target_valid must return false for Hero")

	# Target scanning should not select Hero
	var acquired = tower.acquire_target()
	assert_null(acquired, "Tower must not acquire Hero as a target")

	# Attempt to force fire at Hero
	var initial_hp = hero.current_hp
	tower.fire_at(hero)
	assert_eq(hero.current_hp, initial_hp, "Hero HP must not decrease when Tower attempts fire")

	# Simulating fire timer timeout with Hero in range
	tower._on_fire_timer_timeout()
	assert_eq(hero.current_hp, initial_hp, "Tower periodic attack tick must not damage Hero")

# ==============================================================================
# 18. HUD Hides AP Label and Displays Resource Costs on Buttons
# ==============================================================================

func test_18_hud_hides_ap_in_v01() -> void:
	var hud_packed = load("res://scenes/ui/HUD.tscn")
	assert_not_null(hud_packed, "HUD.tscn must exist")
	var hud = hud_packed.instantiate()
	_cleanup_nodes.append(hud)
	tree.root.add_child(hud)
	await wait_frames(1)

	assert_false(hud.ap_label.visible, "APLabel must be invisible on the UI")

	# Build costs moved to the Hero Option Panel in v0.2; they must still quote
	# wood and never AP, which no longer exists.
	var panel = hud.find_child("OptionPanel", true, false)
	assert_not_null(panel, "OptionPanel must exist in the HUD")
	panel.current_menu = "build"
	panel._populate_hero_buttons()
	var saw_wood: bool = false
	for btn in panel.button_container.get_children():
		var t: String = str(btn.text)
		assert_false(t.contains("AP"), "Build button must not show AP cost (got '%s')" % t)
		if t.contains("木") or t.contains("Wood"):
			saw_wood = true
	assert_true(saw_wood, "Build buttons show wood cost")

# ==============================================================================
# 19. Hero A* Pathfinding Navigates Around Wall Obstacles
# ==============================================================================

func test_19_hero_pathfinding_around_wall_obstacle() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")
	assert_not_null(grid_manager_script, "GridManager.gd must exist")

	var grid_mgr = grid_manager_script.new()
	_cleanup_nodes.append(grid_mgr)
	tree.root.add_child(grid_mgr)

	# Place an intervening wall blocking direct movement at cell (1, 0)
	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.position = grid_mgr.cell_to_world(Vector2i(1, 0))
	wall.complete_construction()
	grid_mgr.occupy_cell(Vector2i(1, 0), wall)

	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = grid_mgr.cell_to_world(Vector2i(0, 0))

	# Move to cell (2, 0) on the other side of the wall
	var dest = grid_mgr.cell_to_world(Vector2i(2, 0))
	hero.move_to(dest)

	# Pathfinding must route around cell (1, 0)
	assert_gt(hero.current_path.size(), 1, "Hero path must contain intermediate waypoints around the wall")
	for pt in hero.current_path:
		var c = grid_mgr.world_to_cell(pt)
		assert_ne(c, Vector2i(1, 0), "Waypoint must not route directly through occupied cell (1, 0)")

	# Simulate movement over time
	for _i in range(50):
		hero._physics_process(0.05)
		if hero.current_state == hero_script.State.IDLE:
			break

	var end_cell = grid_mgr.world_to_cell(hero.global_position)
	assert_eq(end_cell, Vector2i(2, 0), "Hero successfully reached cell (2, 0) on opposite side of wall")

# ==============================================================================
# 20. Hero Builds Blueprint Placed Directly Adjacent to Wall
# ==============================================================================

func test_20_hero_builds_blueprint_adjacent_to_wall() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")
	assert_not_null(grid_manager_script, "GridManager.gd must exist")

	var grid_mgr = grid_manager_script.new()
	_cleanup_nodes.append(grid_mgr)
	tree.root.add_child(grid_mgr)

	# Completed wall at (1, 0)
	var completed_wall = wall_script.new()
	_cleanup_nodes.append(completed_wall)
	tree.root.add_child(completed_wall)
	completed_wall.position = grid_mgr.cell_to_world(Vector2i(1, 0))
	completed_wall.complete_construction()
	grid_mgr.occupy_cell(Vector2i(1, 0), completed_wall)

	# Unfinished blueprint directly adjacent at (2, 0)
	var blueprint = wall_script.new()
	_cleanup_nodes.append(blueprint)
	tree.root.add_child(blueprint)
	blueprint.position = grid_mgr.cell_to_world(Vector2i(2, 0))
	blueprint.start_construction(1.0)
	grid_mgr.occupy_cell(Vector2i(2, 0), blueprint)

	# Hero starts on opposite side at (0, 0)
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = grid_mgr.cell_to_world(Vector2i(0, 0))

	# Order hero to build blueprint
	hero.order_build(blueprint)
	assert_eq(int(hero.current_state), 1, "Hero enters MOVING towards blueprint")

	# Simulate frames until hero starts building
	for _i in range(50):
		hero._physics_process(0.05)
		if hero.current_state == hero_script.State.BUILDING:
			break

	assert_eq(int(hero.current_state), 2, "Hero successfully navigated around wall and entered BUILDING")

	# Continue building until completion
	for _i in range(30):
		hero._physics_process(0.05)
		if blueprint.is_constructed:
			break

	assert_true(blueprint.is_constructed, "Blueprint successfully finished construction")
	assert_almost_eq(blueprint.build_progress, 1.0, 0.01, "Blueprint progress reached 100%")

# ==============================================================================
# 21. Hero Automatically Discovers and Builds Queued Blueprints
# ==============================================================================

func test_21_hero_auto_builds_queued_blueprints() -> void:
	assert_not_null(hero_script, "Hero.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")
	assert_not_null(grid_manager_script, "GridManager.gd must exist")

	var grid_mgr = grid_manager_script.new()
	_cleanup_nodes.append(grid_mgr)
	tree.root.add_child(grid_mgr)

	# Blueprint 1 at (1, 0) (0.5s build time)
	var bp1 = wall_script.new()
	_cleanup_nodes.append(bp1)
	tree.root.add_child(bp1)
	bp1.position = grid_mgr.cell_to_world(Vector2i(1, 0))
	bp1.start_construction(0.5)
	grid_mgr.occupy_cell(Vector2i(1, 0), bp1)

	# Blueprint 2 at (2, 0) (0.5s build time)
	var bp2 = wall_script.new()
	_cleanup_nodes.append(bp2)
	tree.root.add_child(bp2)
	bp2.position = grid_mgr.cell_to_world(Vector2i(2, 0))
	bp2.start_construction(0.5)
	grid_mgr.occupy_cell(Vector2i(2, 0), bp2)

	# Hero at (0, 0)
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = grid_mgr.cell_to_world(Vector2i(0, 0))

	# Order build bp1
	hero.order_build(bp1)

	# Simulate until both are built
	for _i in range(70):
		hero._physics_process(0.05)
		if bp1.is_constructed and bp2.is_constructed:
			break

	assert_true(bp1.is_constructed, "Blueprint 1 finished construction")
	assert_true(bp2.is_constructed, "Blueprint 2 automatically finished construction via auto-queue")

# ==============================================================================
# 22. Dinosaurs Never Overlap or Pass Through Each Other After Building Breach
# ==============================================================================

func test_22_dinos_never_overlap_after_building_breach() -> void:
	assert_not_null(dino_script, "Dino.gd must exist")
	assert_not_null(wall_script, "Wall.gd must exist")

	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.position = Vector3(1.0, 0.0, -7.0)
	wall.complete_construction()

	var waypoints_list: Array[Vector3] = [
		Vector3(1.0, 0.0, -18.0),
		Vector3(1.0, 0.0, -7.0),
		Vector3(1.0, 0.0, 0.0)
	]

	# Spawn 4 dinos encircling the wall: North, South, East, West
	var dinos: Array[Node] = []
	var offsets = [
		Vector3(0.0, 0.0, -1.6), # North (behind wall)
		Vector3(0.0, 0.0, 1.6),  # South (in front of wall)
		Vector3(1.6, 0.0, 0.0),  # East (right flank)
		Vector3(-1.6, 0.0, 0.0)  # West (left flank)
	]

	for i in range(4):
		var d = dino_script.new("raptor")
		_cleanup_nodes.append(d)
		tree.root.add_child(d)
		d.position = wall.position + offsets[i]
		d.set_waypoints(waypoints_list)
		d.current_waypoint_index = 2
		d.on_obstacle_detected(wall)
		dinos.append(d)
		assert_eq(int(d.current_state), 1, "Dino %d is initially ATTACKING the wall" % i)

	# Destroy the wall (simulating breach)
	wall.take_damage(999.0)
	assert_true(wall.is_destroyed, "Wall must be destroyed")

	# Simulate 30 physics frames as dinos transition to WALKING and march through
	for frame in range(30):
		for d in dinos:
			d._physics_process(0.05)

		# Strict pairwise anti-penetration invariant:
		# Distance between any two 0.8m dino cube models must NEVER be < 0.8m (no overlapping/clipping)
		for i in range(dinos.size()):
			for j in range(i + 1, dinos.size()):
				var dist = dinos[i].global_position.distance_to(dinos[j].global_position)
				assert_true(dist >= 0.8,
					"Dinos %d and %d must not overlap on frame %d (distance was %f < 0.8m)" % [i, j, frame, dist])

	# Verify all dinos are in WALKING state and have advanced forward
	for i in range(dinos.size()):
		assert_eq(int(dinos[i].current_state), 0, "Dino %d is WALKING after breach" % i)
		assert_gt(dinos[i].global_position.z, -8.6, "Dino %d has advanced forward along path" % i)
