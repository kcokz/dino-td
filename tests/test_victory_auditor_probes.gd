# res://tests/test_victory_auditor_probes.gd
# Independent Victory Auditor Verification Suite for Defend Dinosaur v0.0.
# Evaluates strictly against ORIGINAL_REQUEST.md requirements R1 ~ R6.
extends SceneTree

var total_probes_run: int = 0
var total_probes_passed: int = 0
var total_probes_failed: int = 0
var failure_details: Array[String] = []

func _init() -> void:
	await process_frame
	print("============================================================")
	print("INDEPENDENT VICTORY AUDITOR PROBE SUITE")
	print("Target: Defend Dinosaur v0.0 (Godot 4.7 Headless)")
	print("============================================================")

	await run_probe("PROBE R1: Autoloads & Centralized Config", probe_r1_autoloads_and_config)
	await run_probe("PROBE R2: Grid Mathematics & Building Placement", probe_r2_grid_and_placement)
	await run_probe("PROBE R3: Turn State Machine & Economy Cycle", probe_r3_turn_loop_and_economy)
	await run_probe("PROBE R4: Dinosaur AI, Tower Combat & Wave Scaling", probe_r4_combat_and_waves)
	await run_probe("PROBE R5: Win/Loss Conditions, HUD Reactivity & Restart", probe_r5_win_loss_hud_restart)

	print("============================================================")
	print("VICTORY AUDITOR PROBE SUMMARY")
	print("Probes Run:    %d" % total_probes_run)
	print("Probes Passed: %d" % total_probes_passed)
	print("Probes Failed: %d" % total_probes_failed)
	print("============================================================")

	if total_probes_failed > 0:
		printerr("FAILURES RECORDED:")
		for f in failure_details:
			printerr("  - %s" % f)
		print("VERDICT: INDEPENDENT PROBES FAILED (exit code 1)")
		quit(1)
	else:
		print("VERDICT: ALL INDEPENDENT PROBES PASSED (exit code 0)")
		quit(0)

func run_probe(probe_name: String, callable: Callable) -> void:
	total_probes_run += 1
	print("\n>>> Executing %s..." % probe_name)
	var pre_fails = failure_details.size()
	await callable.call()
	if failure_details.size() == pre_fails:
		total_probes_passed += 1
		print("  [PASS] %s" % probe_name)
	else:
		total_probes_failed += 1
		printerr("  [FAIL] %s" % probe_name)

func probe_assert(condition: bool, msg: String) -> void:
	if not condition:
		failure_details.append(msg)
		printerr("    Assertion Failed: %s" % msg)

# ==============================================================================
# PROBE R1: Autoloads & Centralized Config
# ==============================================================================
func probe_r1_autoloads_and_config() -> void:
	var cfg = root.get_node_or_null("Config")
	var eb = root.get_node_or_null("EventBus")
	var gs = root.get_node_or_null("GameState")

	probe_assert(cfg != null, "Config autoload must exist at /root/Config")
	probe_assert(eb != null, "EventBus autoload must exist at /root/EventBus")
	probe_assert(gs != null, "GameState autoload must exist at /root/GameState")
	if cfg == null or eb == null or gs == null:
		return

	# Verify numerical constants centrally defined in Config
	probe_assert(cfg.get("BASE_AP") == 3, "Config.BASE_AP must be 3")
	probe_assert(cfg.get("TILE_SIZE") == 2.0, "Config.TILE_SIZE must be 2.0")
	var res_array = cfg.get("RESOURCES")
	probe_assert(res_array is Array and res_array.has("wood") and res_array.has("stone") and res_array.has("food"), "Config.RESOURCES must contain wood, stone, food")

	var buildings = cfg.get("BUILDINGS")
	probe_assert(buildings is Dictionary, "Config.BUILDINGS must be a Dictionary")
	probe_assert(buildings.has("core") and buildings["core"].get("hp") == 10.0, "Config core HP must be 10")
	probe_assert(buildings.has("tower") and buildings["tower"].get("cost", {}).get("wood") == 4, "Config tower wood cost must be 4")
	probe_assert(buildings.has("wall") and buildings["wall"].get("hp") == 30.0, "Config wall HP must be 30")
	probe_assert(buildings.has("lumber_hut") and buildings["lumber_hut"].get("produces", {}).get("wood") == 2, "Config lumber hut produces 2 wood")

	var dinos = cfg.get("DINOS")
	probe_assert(dinos is Dictionary and dinos.has("raptor"), "Config.DINOS must have raptor")
	probe_assert(dinos["raptor"].get("hp") == 3.0, "Config raptor HP must be 3")
	probe_assert(dinos["raptor"].get("speed") == 4.0, "Config raptor speed must be 4")

	var waves = cfg.get("WAVES")
	probe_assert(waves is Dictionary and waves.get("big_every") == 3, "Config waves big_every must be 3")
	probe_assert(waves.get("big_multiplier") == 2.0, "Config waves big_multiplier must be 2.0")

	var nest = cfg.get("NEST")
	probe_assert(nest is Dictionary and nest.get("hp") == 30.0, "Config nest HP must be 30")

	# Verify EventBus signals
	var required_signals = [
		"phase_changed", "ap_changed", "resources_changed",
		"building_placed", "building_destroyed", "core_hp_changed",
		"wave_started", "wave_ended", "produce_phase",
		"dino_spawned", "dino_died", "dino_reached_core",
		"nest_destroyed", "game_won", "game_lost"
	]
	for s_name in required_signals:
		probe_assert(eb.has_signal(s_name), "EventBus must declare signal '%s'" % s_name)

# ==============================================================================
# PROBE R2: Grid Mathematics & Building Placement
# ==============================================================================
func probe_r2_grid_and_placement() -> void:
	var gm_script = load("res://scripts/core/GridManager.gd")
	var bs_script = load("res://scripts/core/BuildSystem.gd")
	probe_assert(gm_script != null and bs_script != null, "GridManager and BuildSystem scripts must load")
	if gm_script == null or bs_script == null: return

	var gm = gm_script.new()
	var bs = bs_script.new()
	var container = Node3D.new()
	root.add_child(gm)
	root.add_child(bs)
	root.add_child(container)
	bs.setup(gm, container)

	# 1. Coordinate conversion tests across 4 quadrants
	probe_assert(gm.world_to_cell(Vector3(0.0, 0.0, 0.0)) == Vector2i(0, 0), "World (0,0) -> Cell (0,0)")
	probe_assert(gm.world_to_cell(Vector3(2.5, 0.0, 4.5)) == Vector2i(1, 2), "World (2.5, 4.5) -> Cell (1,2)")
	probe_assert(gm.world_to_cell(Vector3(-0.5, 0.0, -0.5)) == Vector2i(-1, -1), "World (-0.5, -0.5) -> Cell (-1,-1)")
	probe_assert(gm.world_to_cell(Vector3(-2.5, 0.0, 3.5)) == Vector2i(-2, 1), "World (-2.5, 3.5) -> Cell (-2,1)")

	var world_center = gm.cell_to_world(Vector2i(1, 2))
	probe_assert(world_center.is_equal_approx(Vector3(3.0, 0.0, 5.0)), "Cell (1,2) -> Center (3.0, 0.0, 5.0)")

	# 2. Building placement validation
	var gs = root.get_node("GameState")
	gs.reset_game()
	probe_assert(gs.current_ap == 3, "Starting AP is 3")
	probe_assert(gs.resources["wood"] == 10, "Starting wood is 10")

	# Place tower at (5, 5) costing 1 AP, 4 wood
	var target_cell = Vector2i(5, 5)
	probe_assert(bs.can_place_building("tower", target_cell), "Can place tower on empty cell (5,5)")
	var tower_node = bs.place_building("tower", target_cell)
	probe_assert(tower_node != null, "Tower placed successfully")
	probe_assert(gm.is_cell_occupied(target_cell), "Cell (5,5) is now occupied")
	probe_assert(gs.current_ap == 2, "AP deducted from 3 to 2")
	probe_assert(gs.resources["wood"] == 6, "Wood deducted from 10 to 6")

	# Duplicate placement check on same tile
	probe_assert(not bs.can_place_building("tower", target_cell), "Cannot place tower on occupied cell (5,5)")
	var dup_node = bs.place_building("tower", target_cell)
	probe_assert(dup_node == null, "Duplicate placement returns null")
	probe_assert(gs.current_ap == 2, "AP remains 2 on rejected placement")
	probe_assert(gs.resources["wood"] == 6, "Wood remains 6 on rejected placement")

	# Insufficient wood check: spend remaining wood
	gs.resources["wood"] = 1
	var cell_nowood = Vector2i(6, 6)
	probe_assert(not bs.can_place_building("tower", cell_nowood), "Cannot place tower with only 1 wood")
	probe_assert(bs.place_building("tower", cell_nowood) == null, "Placement rejected due to lack of wood")

	# Insufficient AP check
	gs.resources["wood"] = 10
	gs.current_ap = 0
	var cell_noap = Vector2i(7, 7)
	probe_assert(not bs.can_place_building("tower", cell_noap), "Cannot place tower with 0 AP")
	probe_assert(bs.place_building("tower", cell_noap) == null, "Placement rejected due to 0 AP")

	# Destroy tower and verify grid cell becomes unoccupied
	tower_node.take_damage(tower_node.max_hp)
	await process_frame
	probe_assert(not gm.is_cell_occupied(target_cell), "Cell (5,5) vacated after tower destroyed")

	gm.queue_free()
	bs.queue_free()
	container.queue_free()
	await process_frame

# ==============================================================================
# PROBE R3: Turn State Machine & Economy Cycle
# ==============================================================================
func probe_r3_turn_loop_and_economy() -> void:
	var gs = root.get_node("GameState")
	var eb = root.get_node("EventBus")
	var gm_script = load("res://scripts/core/GridManager.gd")
	var bs_script = load("res://scripts/core/BuildSystem.gd")
	var gm = gm_script.new()
	var bs = bs_script.new()
	root.add_child(gm)
	root.add_child(bs)
	bs.setup(gm)
	gs.reset_game()

	probe_assert(gs.current_phase == 0, "Phase begins in PLAN (0)")

	# Spend 2 AP during PLAN
	probe_assert(gs.spend_ap(2), "Spend 2 AP in PLAN phase")
	probe_assert(gs.current_ap == 1, "Remaining AP is 1")

	# Transition to ATTACK
	gs.trigger_end_action()
	probe_assert(gs.current_phase == 1, "Phase transitioned to ATTACK (1)")

	# Verify building placement blocked during ATTACK phase
	probe_assert(not bs.can_place_building("wall", Vector2i(3, 3)), "Cannot place building during ATTACK phase")

	# Place a LumberHut and test PRODUCE phase harvest
	var lumber_script = load("res://scripts/entities/LumberHut.gd")
	var lumber = lumber_script.new()
	root.add_child(lumber)
	await process_frame

	var wood_before = gs.resources.get("wood", 0)
	# Advance to PRODUCE phase
	gs.set_phase(2) # Phase.PRODUCE
	probe_assert(gs.current_phase == 2, "Phase transitioned to PRODUCE (2)")
	await process_frame

	var wood_after = gs.resources.get("wood", 0)
	probe_assert(wood_after == wood_before + 2, "Lumber hut added 2 wood during PRODUCE (before: %d, after: %d)" % [wood_before, wood_after])

	# Advance back to PLAN phase and verify AP reset
	gs.end_produce_phase()
	probe_assert(gs.current_phase == 0, "Phase transitioned back to PLAN (0)")
	probe_assert(gs.current_ap == gs.max_ap, "AP reset back to max_ap (%d)" % gs.max_ap)

	# Test AP capacity boost with dynamic building script
	var bonus_script = GDScript.new()
	bonus_script.source_code = "extends 'res://scripts/entities/Building.gd'\nvar ap_bonus: int = 2\n"
	bonus_script.reload()
	var bonus_building = bonus_script.new()
	root.add_child(bonus_building)
	await process_frame

	gs.register_building(bonus_building)
	probe_assert(gs.max_ap == 5, "max_ap boosted from 3 to 5 with ap_bonus=2")
	gs.reset_ap()
	probe_assert(gs.current_ap == 5, "current_ap reset to boosted max_ap 5")

	# Unregister building
	gs.unregister_building(bonus_building)
	probe_assert(gs.max_ap == 3, "max_ap returned to 3 after unregistering bonus building")

	lumber.queue_free()
	bonus_building.queue_free()
	gm.queue_free()
	bs.queue_free()
	await process_frame

# ==============================================================================
# PROBE R4: Dinosaur AI, Tower Combat & Wave Scaling
# ==============================================================================
func probe_r4_combat_and_waves() -> void:
	var gs = root.get_node("GameState")
	var dino_script = load("res://scripts/entities/Dino.gd")
	var tower_script = load("res://scripts/entities/Tower.gd")
	var wall_script = load("res://scripts/entities/Wall.gd")
	var wm_script = load("res://scripts/core/WaveManager.gd")
	probe_assert(dino_script != null and tower_script != null and wall_script != null and wm_script != null, "Combat scripts must load")
	if dino_script == null or tower_script == null or wall_script == null or wm_script == null: return

	# 1. Dino Navigation & Movement
	var dino = dino_script.new("raptor")
	root.add_child(dino)
	dino.position = Vector3(0.0, 0.0, -10.0)
	dino.set_waypoints([Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, 0.0)])
	await process_frame

	probe_assert(dino.speed == 4.0, "Dino base speed is 4.0")
	var z_before = dino.global_position.z
	dino.advance_towards_waypoint(0.25)
	probe_assert(dino.global_position.z > z_before, "Dino moved forward towards waypoint (z changed from %.2f to %.2f)" % [z_before, dino.global_position.z])

	# 2. Obstacle Detection & Wall Combat
	var wall = wall_script.new()
	root.add_child(wall)
	wall.position = Vector3(0.0, 0.0, dino.global_position.z + 0.8) # Immediately ahead
	await process_frame

	dino.advance_towards_waypoint(0.1)
	probe_assert(dino.current_state == 1 or dino.is_blocked, "Dino detected wall obstacle and entered ATTACKING / blocked state")
	var wall_hp_before = wall.current_hp
	dino.perform_attack()
	probe_assert(wall.current_hp < wall_hp_before, "Dino attack reduced wall HP from %.1f to %.1f" % [wall_hp_before, wall.current_hp])

	# Destroy wall, Dino resumes walking
	wall.destroy()
	await process_frame
	dino._process_attacking(0.0) # Check obstacle cleared
	probe_assert(dino.current_state == 0, "Dino resumed WALKING after obstacle cleared")
	dino.die()
	await process_frame

	# 3. Tower Automated Targeting & Kill
	var tower = tower_script.new()
	root.add_child(tower)
	tower.position = Vector3(0.0, 0.0, 0.0)
	await process_frame

	var target_dino = dino_script.new("raptor")
	root.add_child(target_dino)
	target_dino.position = Vector3(0.0, 0.0, 3.0) # Within 5.0m range
	await process_frame

	tower.on_target_entered(target_dino)
	var acquired = tower.acquire_target()
	probe_assert(acquired == target_dino, "Tower successfully acquired target dino within 5.0m range")
	var dino_hp_before = target_dino.current_hp
	tower.fire_at_target(target_dino)
	probe_assert(target_dino.current_hp == dino_hp_before - tower.damage, "Tower hit dino dealing %.1f damage" % tower.damage)

	# Finish killing dino
	target_dino.take_damage(10.0)
	await process_frame
	tower.on_target_died(target_dino)
	probe_assert(tower.acquire_target() == null, "Tower target cleared after dino eliminated")
	tower.queue_free()
	await process_frame

	# 4. Wave Scaling & Multiplier Logic
	var wm = wm_script.new()
	root.add_child(wm)
	await process_frame

	probe_assert(wm.get_wave_dino_count(1) == 2, "Wave 1 dino count is 2")
	probe_assert(wm.get_wave_dino_count(2) == 3, "Wave 2 dino count is 3")
	probe_assert(wm.get_wave_dino_count(3) == 8, "Wave 3 is big wave with count 8 (base 4 * 2.0)")
	probe_assert(wm.is_big_wave(3) == true, "Wave 3 triggers is_big_wave")
	probe_assert(wm.is_big_wave(4) == false, "Wave 4 is not big wave")

	# Wave 3 completion stat enhancement
	gs.reset_game()
	probe_assert(gs.dino_stat_multipliers["hp"] == 1.0, "Initial dino HP multiplier is 1.0")
	gs._on_wave_ended(3)
	probe_assert(is_equal_approx(gs.dino_stat_multipliers["hp"], 1.3), "After Wave 3 big wave, dino HP multiplier scales to 1.3")
	probe_assert(is_equal_approx(gs.dino_stat_multipliers["damage"], 1.2), "After Wave 3 big wave, dino damage multiplier scales to 1.2")

	wm.queue_free()
	await process_frame

# ==============================================================================
# PROBE R5: Win/Loss Conditions, HUD Reactivity & Restart
# ==============================================================================
func probe_r5_win_loss_hud_restart() -> void:
	var gs = root.get_node("GameState")
	var eb = root.get_node("EventBus")
	var core_script = load("res://scripts/entities/CoreCampfire.gd")
	var nest_script = load("res://scripts/entities/Nest.gd")
	var hud_script = load("res://scripts/ui/HUD.gd")
	var main_script = load("res://scripts/core/Main.gd")

	# 1. Loss Condition & Action Lockout
	gs.reset_game()
	var core = core_script.new()
	root.add_child(core)
	await process_frame

	var loss_signal_box: Array[bool] = [false]
	var on_loss = func(): loss_signal_box[0] = true
	eb.game_lost.connect(on_loss)

	core.take_damage(core.max_hp)
	await process_frame
	probe_assert(loss_signal_box[0], "EventBus.game_lost emitted when Campfire destroyed")
	probe_assert(gs.is_game_over == true, "GameState.is_game_over is true on defeat")
	probe_assert(gs.is_game_won == false, "GameState.is_game_won is false on defeat")
	probe_assert(not gs.spend_ap(1), "Action spending AP blocked when game over")
	probe_assert(not gs.spend_resources({"wood": 1}), "Spending resources blocked when game over")
	eb.game_lost.disconnect(on_loss)

	# 2. Victory Condition & Exclusion of Overriding Loss
	gs.reset_game()
	var nest = nest_script.new()
	root.add_child(nest)
	await process_frame

	var win_signal_box: Array[bool] = [false]
	var on_win = func(): win_signal_box[0] = true
	eb.game_won.connect(on_win)

	nest.take_damage(nest.max_hp)
	await process_frame
	probe_assert(win_signal_box[0], "EventBus.game_won emitted when Nest destroyed")
	probe_assert(gs.is_game_over == true, "GameState.is_game_over is true on victory")
	probe_assert(gs.is_game_won == true, "GameState.is_game_won is true on victory")

	# Ensure defeat signal cannot overwrite existing victory
	eb.game_lost.emit()
	probe_assert(gs.is_game_won == true, "GameState victory cannot be overwritten by subsequent defeat")
	eb.game_won.disconnect(on_win)

	# 3. HUD Reactivity
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame

	eb.ap_changed.emit(2, 4)
	probe_assert(hud.get_ap_text().contains("2") and hud.get_ap_text().contains("4"), "HUD AP label reactively displays 2 / 4")

	eb.resources_changed.emit({"wood": 7})
	probe_assert(hud.get_wood_text().contains("7"), "HUD Wood label reactively displays Wood: 7")

	eb.core_hp_changed.emit(8.0, 10.0)
	probe_assert(hud.get_core_hp_text().contains("8") and hud.get_core_hp_text().contains("10"), "HUD Core HP label reactively displays 8 / 10")

	eb.game_won.emit()
	probe_assert(hud.is_game_over_visible() == true, "HUD game over overlay visible on victory")
	probe_assert(hud.get_result_text().contains("VICTORY"), "HUD displays VICTORY title")

	hud.queue_free()
	await process_frame

	# 4. Clean Restart Lifecycle via Main
	var main_scene = main_script.new()
	root.add_child(main_scene)
	await process_frame

	# Corrupt state to simulate played/lost game
	gs.is_game_over = true
	gs.is_game_won = false
	gs.current_ap = 0
	gs.wave_number = 5
	main_scene.restart_game()
	await process_frame

	probe_assert(gs.is_game_over == false, "Restart resets is_game_over to false")
	probe_assert(gs.current_ap == 3, "Restart resets AP to 3")
	probe_assert(gs.wave_number == 0, "Restart resets wave to 0")
	probe_assert(gs.resources["wood"] == 10, "Restart resets wood to 10")
	probe_assert(main_scene.current_core != null and is_instance_valid(main_scene.current_core), "Restart reinstantiates valid CoreCampfire")
	probe_assert(main_scene.current_nest != null and is_instance_valid(main_scene.current_nest), "Restart reinstantiates valid Nest")

	main_scene.queue_free()
	await process_frame
