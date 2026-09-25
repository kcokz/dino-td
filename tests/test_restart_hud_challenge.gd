# res://tests/test_restart_hud_challenge.gd
# ==============================================================================
# Challenger 2 Milestone 5 Empirical Stress & Challenge Test Suite:
# Rigorously stress-tests Main Level Reset and HUD Reactive Robustness:
# 1. Mid-wave restart with 10+ active dinos and 10+ player buildings (purged, no zombies).
# 2. 20 consecutive restarts in a loop (zero state drift, zero node leak, grid restoration).
# 3. Rapid-fire HUD signal bombardment (100+ signals in a single frame, no desync/hang).
# 4. HUD button clicks in illegal phases (ATTACK, PRODUCE, DEFEAT, VICTORY safe rejection).
# ==============================================================================
extends "res://tests/test_base.gd"

## Wood this suite seeds in before_each. It asserts exact balances, so it owns
## its wallet rather than inheriting Config.INITIAL_RESOURCES (production tuning).
const SEED_WOOD: int = 10

# Autoload Singletons
var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

# Entity & Core Scripts
var main_scene_packed: PackedScene = null
var hud_scene_packed: PackedScene = null
var dino_script: GDScript = null
var tower_script: GDScript = null
var wall_script: GDScript = null
var core_campfire_script: GDScript = null
var nest_script: GDScript = null

# Cleanup tracking
var _cleanup_nodes: Array[Node] = []

# ==============================================================================
# 1. Lifecycle Hooks
# ==============================================================================

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")

	if ResourceLoader.exists("res://scenes/Main.tscn"):
		main_scene_packed = load("res://scenes/Main.tscn")
	if ResourceLoader.exists("res://scenes/ui/HUD.tscn"):
		hud_scene_packed = load("res://scenes/ui/HUD.tscn")

	dino_script = _load_script(["res://scripts/entities/Dino.gd"])
	tower_script = _load_script(["res://scripts/entities/Tower.gd"])
	wall_script = _load_script(["res://scripts/entities/Wall.gd"])
	core_campfire_script = _load_script(["res://scripts/entities/CoreCampfire.gd"])
	nest_script = _load_script(["res://scripts/entities/Nest.gd"])

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	# reset_game() seeds Config.INITIAL_RESOURCES, which is production tuning.
	# This suite asserts exact balances, so pin its own wallet.
	if game_state_node != null and "resources" in game_state_node:
		game_state_node.resources = {"wood": SEED_WOOD, "stone": 0, "water": 0, "food": 0}

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

	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

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

func _create_main() -> Node:
	assert_not_null(main_scene_packed, "Main.tscn must exist")
	if main_scene_packed == null:
		return null
	var inst = main_scene_packed.instantiate()
	_cleanup_nodes.append(inst)
	if tree and tree.root:
		tree.root.add_child(inst)
	return inst

func _create_hud() -> Node:
	var hud: Node = null
	if hud_scene_packed != null:
		hud = hud_scene_packed.instantiate()
	else:
		var hud_script = _load_script(["res://scripts/ui/HUD.gd"])
		if hud_script:
			hud = hud_script.new()
	if hud != null:
		_cleanup_nodes.append(hud)
	return hud

# ==============================================================================
# Category 1: Mid-Wave Restart Stress Testing (10+ Dinos & 10+ Buildings)
# ==============================================================================

func test_challenge_01_mid_wave_restart_purges_10_plus_dinos_and_buildings() -> void:
	var main = _create_main()
	assert_not_null(main, "Main scene instantiated")
	if main == null: return
	await wait_frames(2)

	var dinos_container = main.find_child("Dinos", true, false) as Node3D
	var buildings_container = main.find_child("Buildings", true, false) as Node3D
	var grid_mgr = main.grid_manager
	var wave_mgr = main.wave_manager

	assert_not_null(dinos_container, "Dinos container exists")
	assert_not_null(buildings_container, "Buildings container exists")
	assert_not_null(grid_mgr, "GridManager exists")
	assert_not_null(wave_mgr, "WaveManager exists")

	# 1. Place 12 active player buildings across grid
	var tracked_buildings: Array[Node] = []
	var building_cells: Array[Vector2i] = []
	var types = ["wall", "tower"]

	for i in range(12):
		# East of the cabin's block, which is (0, 0) to (1, 1).
		var cell = Vector2i((i % 4) + 3, (i / 4) + 1)
		building_cells.append(cell)
		var b_type = types[i % types.size()]
		var b: Node = null
		match b_type:
			"wall": b = wall_script.new()
			"tower": b = tower_script.new()
		b.setup(b_type, cell)
		b.position = grid_mgr.cell_to_world(cell)
		buildings_container.add_child(b)
		grid_mgr.occupy_cell(cell, b)
		tracked_buildings.append(b)

	# Total buildings: 12 player + 1 Core = 13
	assert_eq(buildings_container.get_child_count(), 13, "Buildings container has 13 nodes (12 player + 1 Core)")
	assert_eq(grid_mgr.occupied_cells.size(), 12 + level_tiles_at_start(), "Grid tracks 12 player tiles, the cabin's and the nest's")

	# 2. Spawn 12 active dinos in Dinos container
	var tracked_dinos: Array[Node] = []
	for i in range(12):
		var dino = dino_script.new()
		dino.setup("raptor", {})
		dino.waypoints = main.waypoints.duplicate()
		dino.position = Vector3(0.0, 0.0, -18.0 + float(i))
		dinos_container.add_child(dino)
		tracked_dinos.append(dino)

	assert_eq(dinos_container.get_child_count(), 12, "Dinos container has 12 active dinos")

	# 3. Simulate mid-wave state: wave 2 active with running spawn timer
	game_state_node.current_phase = 1 # ATTACK
	game_state_node.wave_number = 2
	wave_mgr.current_wave = 2
	wave_mgr.dinos_to_spawn = 12
	wave_mgr.dinos_alive_count = 12
	wave_mgr.is_wave_active = true
	if wave_mgr.spawn_timer:
		wave_mgr.spawn_timer.start(0.8)

	assert_true(wave_mgr.is_wave_active, "Wave is currently active")
	if wave_mgr.spawn_timer:
		assert_false(wave_mgr.spawn_timer.is_stopped(), "Spawn timer is ticking mid-wave")

	# Capture references to old Core and Nest
	var old_core = main.current_core
	var old_nest = main.current_nest
	assert_not_null(old_core, "Old core exists before restart")
	assert_not_null(old_nest, "Old nest exists before restart")

	# 4. Trigger mid-wave restart
	main.restart_game()
	await wait_frames(2)

	# 5. Verify all active dinos and player buildings are purged
	assert_eq(dinos_container.get_child_count(), 0, "Dinos container must be completely empty after restart")
	assert_eq(buildings_container.get_child_count(), 1, "Buildings container has exactly 1 building (Core)")
	var remaining_building = buildings_container.get_child(0)
	assert_true(remaining_building.get_script() == core_campfire_script, "Remaining building is CoreCampfire")

	# 6. Verify WaveManager state and timer cancellation
	assert_false(wave_mgr.is_wave_active, "WaveManager.is_wave_active must be false")
	assert_eq(wave_mgr.current_wave, 0, "WaveManager.current_wave reset to 0")
	assert_eq(wave_mgr.dinos_alive_count, 0, "WaveManager.dinos_alive_count reset to 0")
	assert_eq(wave_mgr.dinos_to_spawn, 0, "WaveManager.dinos_to_spawn reset to 0")
	if wave_mgr.spawn_timer:
		assert_true(wave_mgr.spawn_timer.is_stopped(), "WaveManager spawn_timer must be stopped")

	# 7. Verify GameState reset
	assert_eq(int(game_state_node.wave_number), 0, "GameState.wave_number reset to 0")
	assert_eq(int(game_state_node.current_phase), 0, "GameState.current_phase reset to PLAN (0)")
	assert_eq(int(game_state_node.resources.get("wood", 0)), opening_banked_wood(), "GameState wood reset to the Config opening balance")
	assert_false(bool(game_state_node.get("is_game_over")), "GameState.is_game_over is false")

	# 8. Verify GridManager occupancy accurately restored
	assert_eq(grid_mgr.occupied_cells.size(), level_tiles_at_start(), "Grid occupancy restored to the level's own tiles")
	assert_true(grid_mgr.is_cell_occupied(Vector2i(0, 0)), "Core cell (0, 0) is occupied")
	assert_true(grid_mgr.is_cell_occupied(Vector2i(0, -9)), "Nest cell (0, -9) is occupied")
	for cell in building_cells:
		assert_false(grid_mgr.is_cell_occupied(cell), "Cell %s must be vacant after restart" % str(cell))

	# 9. Verify no zombie objects remain
	for d in tracked_dinos:
		assert_false(is_instance_valid(d), "Dino must be freed with zero zombie retention")
	for b in tracked_buildings:
		assert_false(is_instance_valid(b), "Player building must be freed with zero zombie retention")
	assert_false(is_instance_valid(old_core), "Old Core must be freed")
	assert_false(is_instance_valid(old_nest), "Old Nest must be freed")

func test_challenge_02_mid_wave_restart_with_damaged_entities_and_active_physics() -> void:
	var main = _create_main()
	if main == null: return
	await wait_frames(2)

	# Damage Core and Nest heavily
	main.current_core.take_damage(8.0)
	main.current_nest.take_damage(25.0)
	assert_almost_eq(float(main.current_core.current_hp), 2.0, 0.001, "Core HP reduced to 2.0")
	assert_almost_eq(float(main.current_nest.current_hp), 5.0, 0.001, "Nest HP reduced to 5.0")

	# Spawn 10 dinos marching towards Core
	for i in range(10):
		var dino = dino_script.new()
		dino.setup("raptor", {})
		dino.waypoints = main.waypoints.duplicate()
		dino.position = main.waypoints[mini(i % main.waypoints.size(), main.waypoints.size() - 1)]
		main.dinos_container.add_child(dino)

	# Tick physics frames
	await wait_frames(3)

	# Restart
	main.restart_game()
	await wait_frames(2)

	# Verify fresh pristine Core and Nest with full HP
	assert_not_null(main.current_core, "Pristine Core exists")
	assert_not_null(main.current_nest, "Pristine Nest exists")
	assert_almost_eq(float(main.current_core.current_hp), 10.0, 0.001, "Core restored to full 10.0 HP")
	assert_almost_eq(float(main.current_nest.current_hp), 30.0, 0.001, "Nest restored to full 30.0 HP")

	# Verify HUD shows full HP
	var hud = main.hud
	if hud and hud.has_method("get_core_hp_text"):
		assert_eq(hud.get_core_hp_text(), "Core HP: 10 / 10", "HUD displays full Core HP")

func test_challenge_03_mid_wave_restart_cancels_wave_progression_and_economy() -> void:
	var main = _create_main()
	if main == null: return
	await wait_frames(2)

	# Three buildings standing when the restart comes. Lumber huts, until the building
	# was deleted from the game -- after which this loaded a script that was not there,
	# called new() on null, and stopped the test dead. It went on being counted as a
	# pass, because the runner only sees assertions and this one had made some already.
	for i in range(3):
		var cell = Vector2i(i + 1, 2)
		var b = tower_script.new()
		b.setup("tower", cell)
		main.buildings_container.add_child(b)
		main.grid_manager.occupy_cell(cell, b)

	# Start wave 3 (big horde wave)
	main.wave_manager.start_wave(3)
	assert_eq(main.wave_manager.current_wave, 3, "Wave 3 active")

	var wave_end_watcher = watch_signal(event_bus_node, "wave_ended")
	var produce_watcher = watch_signal(event_bus_node, "produce_phase")

	# Mid-wave restart
	main.restart_game()
	await wait_frames(3)

	# Verify wave progression was abruptly stopped without triggering end/produce
	assert_eq(wave_end_watcher.emit_count, 0, "wave_ended was NOT emitted on restart")
	assert_eq(produce_watcher.emit_count, 0, "produce_phase was NOT emitted on restart")
	assert_eq(int(game_state_node.resources.get("wood", 0)), opening_banked_wood(), "Wood remains at the opening balance, no illegitimate payout")

# ==============================================================================
# Category 2: 20 Consecutive Restarts (Zero Leaks, Zero Drift, Grid Restored)
# ==============================================================================

func test_challenge_04_20_consecutive_restarts_grid_restoration_and_zero_drift() -> void:
	var main = _create_main()
	if main == null: return
	await wait_frames(2)

	var grid_mgr = main.grid_manager
	var buildings_container = main.buildings_container
	var dinos_container = main.dinos_container

	# Execute 20 consecutive dirty-and-restart cycles
	for cycle in range(20):
		# 1. Dirty GameState values
		game_state_node.resources["wood"] = cycle * 10
		game_state_node.wave_number = cycle + 1
		game_state_node.current_phase = 1 if (cycle % 2 == 1) else 2
		game_state_node.dino_stat_multipliers = {"hp": 2.5, "damage": 2.0, "speed": 1.5}

		# 2. Place dirty buildings on grid
		var wall = wall_script.new()
		wall.setup("wall", FREE_TILE)
		buildings_container.add_child(wall)
		grid_mgr.occupy_cell(FREE_TILE, wall)

		var tower = tower_script.new()
		tower.setup("tower", Vector2i(-1, 2))
		buildings_container.add_child(tower)
		grid_mgr.occupy_cell(Vector2i(-1, 2), tower)

		# 3. Add dino
		var dino = dino_script.new()
		dino.setup("raptor", {})
		dinos_container.add_child(dino)

		# 4. Alternating win/loss flags
		if cycle % 3 == 0:
			event_bus_node.game_won.emit()
		elif cycle % 4 == 0:
			event_bus_node.game_lost.emit()

		# 5. Call restart_game()
		main.restart_game()
		await wait_frames(1)

		# 6. Verify Grid restoration at every cycle
		assert_eq(grid_mgr.occupied_cells.size(), level_tiles_at_start(), "Cycle %d: Grid holds only the level's own tiles" % cycle)
		assert_true(grid_mgr.is_cell_occupied(Vector2i(0, 0)), "Cycle %d: Core cell (0, 0) occupied" % cycle)
		assert_true(grid_mgr.is_cell_occupied(Vector2i(0, -9)), "Cycle %d: Nest cell (0, -9) occupied" % cycle)
		assert_eq(grid_mgr.get_building_at(Vector2i(0, 0)), main.current_core, "Cycle %d: Core is registered at (0, 0)" % cycle)
		assert_eq(grid_mgr.get_building_at(Vector2i(0, -9)), main.current_nest, "Cycle %d: Nest is registered at (0, -9)" % cycle)
		assert_false(grid_mgr.is_cell_occupied(FREE_TILE), "Cycle %d: Dirty cell vacated" % cycle)
		assert_false(grid_mgr.is_cell_occupied(Vector2i(-1, 2)), "Cycle %d: Dirty cell (-1, 2) vacated" % cycle)

		# 7. Verify zero state drift
		assert_eq(int(game_state_node.current_phase), 0, "Cycle %d: Phase is PLAN (0)" % cycle)
		assert_eq(int(game_state_node.resources.get("wood", 0)), opening_banked_wood(), "Cycle %d: Wood is back to Config.INITIAL_RESOURCES" % cycle)
		assert_eq(int(game_state_node.wave_number), 0, "Cycle %d: wave_number is 0" % cycle)
		assert_false(bool(game_state_node.get("is_game_over")), "Cycle %d: is_game_over is false" % cycle)
		assert_false(bool(game_state_node.get("is_game_won")), "Cycle %d: is_game_won is false" % cycle)
		assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.0, 0.001, "Cycle %d: dino hp multiplier reset" % cycle)
		assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.0, 0.001, "Cycle %d: dino damage multiplier reset" % cycle)

func test_challenge_05_20_consecutive_restarts_zero_node_leak() -> void:
	var main = _create_main()
	if main == null: return
	await wait_frames(2)

	var buildings_container = main.buildings_container
	var dinos_container = main.dinos_container
	var nest_holder = main.nest_holder

	for cycle in range(20):
		main.restart_game()
		await wait_frames(1)

		# Child count invariants
		assert_eq(buildings_container.get_child_count(), 1, "Cycle %d: Buildings container child count must remain 1" % cycle)
		assert_eq(dinos_container.get_child_count(), 0, "Cycle %d: Dinos container child count must remain 0" % cycle)
		assert_eq(nest_holder.get_child_count(), 1, "Cycle %d: NestHolder child count must remain 1" % cycle)

# ==============================================================================
# Category 3: Rapid-Fire HUD Event Emissions (100+ Signals)
# ==============================================================================

func test_challenge_06_rapid_fire_hud_signal_bombardment() -> void:
	var hud = _create_hud()
	assert_not_null(hud, "HUD scene instantiated")
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Fire 120 cycles of 5 signals (600 signal emissions in a single frame!)
	for i in range(120):
		event_bus_node.resources_changed.emit({"wood": i * 10, "stone": i})
		event_bus_node.wave_started.emit(i + 1, (i % 3 == 0))
		event_bus_node.core_hp_changed.emit(float((i % 10) + 1), 10.0)
		event_bus_node.phase_changed.emit(i % 3)

	# Conclude with definitive target values in the exact same frame
	event_bus_node.resources_changed.emit({"wood": 888, "stone": 10, "food": 5})
	event_bus_node.wave_started.emit(9, true)
	event_bus_node.core_hp_changed.emit(7.0, 10.0)
	event_bus_node.phase_changed.emit(0)

	# Verify immediate synchronization without crashing or desync
	assert_eq(hud.get_wood_text(), "Wood: 888", "WoodLabel matches final emitted value")
	assert_true("大波" in hud.get_wave_text() or "Horde" in hud.get_wave_text(), "WaveLabel matches final emitted value with big wave text")
	assert_eq(hud.get_core_hp_text(), "Core HP: 7 / 10", "CoreHPLabel matches final emitted value")
	assert_eq(hud.get_phase_text(), "Phase: PLAN", "PhaseLabel matches final emitted phase")

	# Verify action buttons enabled in PLAN
	assert_false(hud.end_action_btn.disabled, "HUD action controls enabled while playing")
	assert_false(hud.end_action_btn.disabled, "EndActionBtn enabled in PLAN")

	# Tick a frame and confirm persistent sync
	await wait_frames(1)
	assert_eq(hud.get_wood_text(), "Wood: 888", "Wood text persistent after tick")

func test_challenge_07_rapid_fire_hud_extreme_values_and_formatting() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Rapidly emit boundary and extreme conditions
	for i in range(50):
		event_bus_node.resources_changed.emit({"wood": 0})
		event_bus_node.core_hp_changed.emit(0.1, 10.0)

	# 0.1 HP should ceil to 1
	assert_eq(hud.get_core_hp_text(), "Core HP: 1 / 10", "Core HP 0.1 properly ceils to 1")
	assert_eq(hud.get_wood_text(), "Wood: 0", "Zero Wood formatted correctly")

	# Massive numbers
	for i in range(50):
		event_bus_node.resources_changed.emit({"wood": 1000000})
		event_bus_node.wave_started.emit(999, false)

	assert_eq(hud.get_wood_text(), "Wood: 1000000", "Large wood formatted correctly")
	assert_eq(hud.get_wave_text(), "Wave: 999", "Wave 999 formatted correctly")

func test_challenge_08_rapid_fire_hud_interleaved_game_over_and_reset() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Alternating victory / defeat signals in rapid succession
	for i in range(50):
		event_bus_node.game_won.emit()
		event_bus_node.game_lost.emit()

	assert_true(hud.is_game_over_visible(), "GameOver modal visible under game over")
	assert_true(hud.end_action_btn.disabled, "End Action disabled under game over")

	# Reset GameState and HUD (simulating complete reset cycle)
	game_state_node.reset_game()
	hud.reset_hud()
	assert_false(hud.is_game_over_visible(), "GameOver modal hidden after reset_hud")
	assert_false(hud.end_action_btn.disabled, "End Action re-enabled after reset_hud")

# ==============================================================================
# Category 4: HUD Button Phase Safety & Wrong-Phase Rejection
# ==============================================================================

func test_challenge_09_hud_end_action_rejected_in_attack_phase() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Advance GameState to ATTACK
	game_state_node.set_phase(game_state_node.Phase.ATTACK)
	assert_eq(int(game_state_node.current_phase), 1, "Phase is ATTACK (1)")

	# Verify button disabled in ATTACK phase
	assert_true(hud.end_action_btn.disabled, "End Action button must be disabled in ATTACK phase")

	# Simulate button press
	hud.simulate_end_action_click()
	await wait_frames(1)

	# Phase must remain ATTACK (1) - click must be safely rejected
	assert_eq(int(game_state_node.current_phase), 1, "Phase must NOT advance when clicking End Action in ATTACK phase")

func test_challenge_10_hud_end_action_rejected_in_produce_phase() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Set phase to PRODUCE
	game_state_node.set_phase(game_state_node.Phase.PRODUCE)
	assert_eq(int(game_state_node.current_phase), 2, "Phase is PRODUCE (2)")

	# Verify button disabled in PRODUCE phase
	assert_true(hud.end_action_btn.disabled, "End Action button must be disabled in PRODUCE phase")

	# Simulate button press
	hud.simulate_end_action_click()
	await wait_frames(1)

	# Phase must remain PRODUCE (2)
	assert_eq(int(game_state_node.current_phase), 2, "Phase must NOT advance when clicking End Action in PRODUCE phase")

func test_challenge_11_hud_action_buttons_rejected_after_defeat() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Trigger Defeat
	event_bus_node.game_lost.emit()
	await wait_frames(1)

	assert_true(bool(game_state_node.get("is_game_over")), "GameState is_game_over is true")
	assert_true(hud.is_game_over_visible(), "GameOver modal is visible")

	# All gameplay action buttons must be disabled
	assert_true(hud.end_action_btn.disabled, "End Action button disabled after defeat")
	assert_true(hud.end_action_btn.disabled, "HUD action controls disabled after defeat")

	# Simulated clicks must be safe no-ops
	var pre_phase = game_state_node.current_phase
	hud.simulate_end_action_click()
	hud.simulate_build_click("tower")
	await wait_frames(1)

	assert_eq(game_state_node.current_phase, pre_phase, "Phase unchanged after illegal click under defeat")
	assert_true(bool(game_state_node.get("is_game_over")), "Game over persists")

func test_challenge_12_hud_action_buttons_rejected_after_victory() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	# Trigger Victory
	event_bus_node.game_won.emit()
	await wait_frames(1)

	assert_true(bool(game_state_node.get("is_game_won")), "GameState is_game_won is true")
	assert_true(bool(game_state_node.get("is_game_over")), "GameState is_game_over is true")

	assert_true(hud.end_action_btn.disabled, "End Action button disabled after victory")
	assert_true(hud.end_action_btn.disabled, "HUD action controls disabled after victory")

	hud.simulate_end_action_click()
	hud.simulate_build_click("wall")
	await wait_frames(1)

	assert_true(bool(game_state_node.get("is_game_won")), "Victory persists unchanged")

func test_challenge_13_hud_end_action_rapid_spam_single_transition() -> void:
	var hud = _create_hud()
	if hud == null: return
	if tree and tree.root:
		tree.root.add_child(hud)
		await wait_frames(2)

	assert_eq(int(game_state_node.current_phase), 0, "Phase starts at PLAN (0)")

	# Rapidly spam End Action click 50 times in a tight loop
	for i in range(50):
		hud.simulate_end_action_click()

	await wait_frames(1)

	# Exactly ONE transition must occur: PLAN (0) -> ATTACK (1)
	# Must not bleed through to PRODUCE (2) or wrap back to PLAN (0)
	assert_eq(int(game_state_node.current_phase), 1, "Rapid spamming End Action triggers exactly 1 transition to ATTACK (1)")

func test_challenge_14_hud_restart_button_triggers_main_restart_lifecycle() -> void:
	var main = _create_main()
	if main == null: return
	await wait_frames(2)

	# Dirty level and trigger Defeat
	main.current_core.take_damage(10.0)
	await wait_frames(2)

	assert_true(bool(game_state_node.get("is_game_over")), "Game is over")
	assert_true(main.hud.is_game_over_visible(), "HUD GameOver panel is visible")

	# Click Restart button via HUD simulation
	main.hud.simulate_restart_click()
	await wait_frames(2)

	# Verify complete restoration
	assert_false(bool(game_state_node.get("is_game_over")), "Game over cleared")
	assert_false(main.hud.is_game_over_visible(), "HUD GameOver panel hidden")
	assert_eq(int(game_state_node.current_phase), 0, "Phase restored to PLAN")
	assert_eq(main.grid_manager.occupied_cells.size(), level_tiles_at_start(), "Grid occupancy restored to the level's own tiles")
	assert_almost_eq(float(main.current_core.current_hp), 10.0, 0.001, "Core HP restored to 10.0")
