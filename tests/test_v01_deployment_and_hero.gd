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

func after_each() -> void:
	for node in _cleanup_nodes:
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.get_parent().remove_child(node)
			node.free()
	_cleanup_nodes.clear()

	if game_state_node and game_state_node.has_method("reset_game"):
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
	assert_true(buildings.has("wall") and buildings["wall"].has("build_time"), "Wall has build_time")
	assert_true(buildings.has("tower") and buildings["tower"].has("build_time"), "Tower has build_time")
	assert_true(buildings.has("lumber_hut") and buildings["lumber_hut"].has("build_time"), "LumberHut has build_time")

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
