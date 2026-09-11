# res://tests/test_gameplay_fixes.gd
# Targeted Verification Suite for Gameplay Fixes:
# 1. Wooden Wall collision & obstacle detection along grid column path.
# 2. PRODUCE phase auto-advance timer unlocking player for the next turn.
# 3. Config centralized parameters & Scene-First + Config-Fallback alignment.
extends "res://tests/test_base.gd"

var config_node: Node = null
var event_bus_node: Node = null
var game_state_node: Node = null

var dino_script: GDScript = null
var wall_script: GDScript = null
var main_scene_packed: PackedScene = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if ResourceLoader.exists("res://scripts/entities/Dino.gd"):
		dino_script = load("res://scripts/entities/Dino.gd")
	if ResourceLoader.exists("res://scripts/entities/Wall.gd"):
		wall_script = load("res://scripts/entities/Wall.gd")
	if ResourceLoader.exists("res://scenes/Main.tscn"):
		main_scene_packed = load("res://scenes/Main.tscn")

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
# 1. Configuration & Architecture Integrity Tests
# ==============================================================================

func test_01_config_centralized_map_and_produce_parameters() -> void:
	assert_not_null(config_node, "Config singleton must exist")
	assert_true("MAP" in config_node, "Config must define MAP dictionary")
	var map_cfg: Dictionary = config_node.get("MAP")
	assert_true(map_cfg.has("default_core_cell"), "Config.MAP must specify default_core_cell")
	assert_true(map_cfg.has("default_nest_cell"), "Config.MAP must specify default_nest_cell")
	assert_true(map_cfg.has("path_column_x"), "Config.MAP must specify path_column_x")
	assert_true(map_cfg.has("produce_duration"), "Config.MAP must specify produce_duration")
	assert_eq(map_cfg.get("path_column_x"), 0, "path_column_x should be 0")
	assert_true(float(map_cfg.get("produce_duration")) > 0.0, "produce_duration must be positive")
	assert_true("PRODUCE_DELAY" in config_node, "Config must define PRODUCE_DELAY constant")

func test_02_wall_hp_driven_by_config_without_hardcoding() -> void:
	assert_not_null(wall_script, "Wall script must exist")
	var expected_hp: float = float(config_node.BUILDINGS["wall"].get("hp", 30.0))
	var wall = wall_script.new()
	_cleanup_nodes.append(wall)
	assert_eq(wall.max_hp, expected_hp, "Wall max_hp should match Config.BUILDINGS['wall']['hp']")
	assert_eq(wall.current_hp, expected_hp, "Wall current_hp should match Config.BUILDINGS['wall']['hp']")

# ==============================================================================
# 2. Main Scene Waypoints & Spawns Grid Alignment
# ==============================================================================

func test_03_main_scene_waypoints_align_to_grid_column_0_center() -> void:
	assert_not_null(main_scene_packed, "Main.tscn must exist and load")
	var main_inst = main_scene_packed.instantiate()
	_cleanup_nodes.append(main_inst)
	tree.root.add_child(main_inst)

	var path_node = main_inst.find_child("Path", true, false)
	assert_not_null(path_node, "Main scene must have Map/Path")

	for child in path_node.get_children():
		if child is Marker3D:
			assert_almost_eq(child.position.x, 1.0, 0.05, "Marker %s X must be 1.0 (center of column 0)" % child.name)

	var nest_spawn = main_inst.find_child("NestSpawn", true, false)
	assert_not_null(nest_spawn, "Main scene must have NestSpawn marker")
	assert_almost_eq(nest_spawn.position.x, 1.0, 0.05, "NestSpawn X must be 1.0")

	var core_spawn = main_inst.find_child("CoreSpawn", true, false)
	assert_not_null(core_spawn, "Main scene must have CoreSpawn marker")
	assert_almost_eq(core_spawn.position.x, 1.0, 0.05, "CoreSpawn X must be 1.0")

# ==============================================================================
# 3. Bug 1: Wooden Wall Obstacle Detection & Blocking
# ==============================================================================

func test_04_dino_detects_and_attacks_wooden_wall_on_path() -> void:
	assert_not_null(dino_script, "Dino script must exist")
	assert_not_null(wall_script, "Wall script must exist")

	var main_inst = main_scene_packed.instantiate()
	_cleanup_nodes.append(main_inst)
	tree.root.add_child(main_inst)

	# Place wall at cell (0, -4) -> world (1, 0, -7)
	var wall_cell = Vector2i(0, -4)
	var wall = main_inst.place_building_at_cell("wall", wall_cell)
	assert_not_null(wall, "Wall must be successfully placed at cell (0, -4)")
	assert_almost_eq(wall.global_position.x, 1.0, 0.05, "Wall world position X must be 1.0")
	assert_almost_eq(wall.global_position.z, -7.0, 0.05, "Wall world position Z must be -7.0")

	# Spawn dino at (1, 0, -8.5), moving towards core at (1, 0, 1)
	var dino = dino_script.new("raptor")
	_cleanup_nodes.append(dino)
	main_inst.dinos_container.add_child(dino)
	dino.global_position = Vector3(1.0, 0.0, -8.5)
	dino.set_waypoints([Vector3(1.0, 0.0, -7.0), Vector3(1.0, 0.0, 1.0)])

	# Wait a frame for physics state to update
	await wait_frames(2)

	# Advance dino towards the wall
	dino.advance_towards_waypoint(0.1)

	# Dino should detect obstacle
	var detected_obstacle = dino.check_obstacle()
	assert_not_null(detected_obstacle, "Dino must detect the wooden wall as an obstacle")
	assert_true(dino.is_blocked, "Dino must be flagged as blocked")
	assert_eq(dino.current_state, 1, "Dino state must be ATTACKING (1)")
	assert_eq(dino.velocity, Vector3.ZERO, "Dino velocity must be zero when blocked")

	# Test attack
	var initial_wall_hp: float = wall.current_hp
	dino.perform_attack()
	assert_true(wall.current_hp < initial_wall_hp, "Wall HP must decrease after dino attack")

	# If wall is destroyed, dino should unblock and resume WALKING
	wall.take_damage(wall.current_hp)
	await wait_frames(2)
	dino._process_attacking(0.0)
	assert_false(dino.is_blocked, "Dino must no longer be blocked after wall is destroyed")
	assert_eq(dino.current_state, 0, "Dino state must return to WALKING (0)")

# ==============================================================================
# 4. Bug 2: PRODUCE Phase Auto-Advance & Action Unlock
# ==============================================================================

func test_05_produce_phase_auto_advances_to_plan_after_delay() -> void:
	assert_not_null(game_state_node, "GameState must exist")

	game_state_node.reset_game()
	assert_eq(game_state_node.current_phase, 0, "Initial phase must be PLAN (0)")

	# Enter ATTACK phase
	game_state_node.set_phase(1)
	assert_eq(game_state_node.current_phase, 1, "Phase must be ATTACK (1)")

	# Simulate wave ended signal from EventBus
	event_bus_node.wave_ended.emit(1)

	# GameState should immediately transition to PRODUCE (2)
	assert_eq(game_state_node.current_phase, 2, "Phase must be PRODUCE (2)")

	# Wait for produce duration (1.0s) + safety margin
	await wait_seconds(1.2)

	# GameState must have auto-advanced back to PLAN (0)
	assert_eq(game_state_node.current_phase, 0, "Phase must automatically transition to PLAN (0)")
	assert_eq(game_state_node.current_ap, game_state_node.max_ap, "AP must be reset to max_ap")
	assert_true(game_state_node.can_spend_ap(1), "Player must be able to spend AP again")

func test_06_manual_end_produce_cancels_timer_and_avoids_double_advance() -> void:
	assert_not_null(game_state_node, "GameState must exist")

	game_state_node.reset_game()
	game_state_node.set_phase(2) # Directly enter PRODUCE
	assert_eq(game_state_node.current_phase, 2, "Phase must be PRODUCE (2)")

	# Manually advance or end produce phase
	game_state_node.end_produce_phase()
	assert_eq(game_state_node.current_phase, 0, "Phase must immediately be PLAN (0)")

	# Wait past the auto-advance timer duration
	await wait_seconds(1.2)

	# It must still be in PLAN phase, not pushed to ATTACK
	assert_eq(game_state_node.current_phase, 0, "Phase must remain in PLAN (0) without ghost advance")
