# res://tests/test_full_loop_stress.gd
# ==============================================================================
# Milestone 6 Final Headless E2E Acceptance Challenge Test Suite:
# Empirically stress-tests the complete integrated game loop:
# 1. Start game in Main scene.
# 3. Trigger End Action -> transitions to ATTACK (WaveManager activates).
# 5. Reach wave 3 (horde wave, 8 dinos), verify horde multiplier and post-horde stat enhancement.
# 6. Defeat all dinos, place Tower within 5.0m of Nest, destroy Nest -> triggers Victory.
# 7. Verify action lockout on victory.
# 8. Trigger restart_game(), verify pristine state.
# 9. Allow dinos to destroy Core Campfire -> triggers Defeat.
# 10. Verify action lockout on defeat.
# 11. Trigger restart_game() again, verify pristine state.
# ==============================================================================
extends "res://tests/test_base.gd"

# Autoload References
var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

# Scene & Script References
var main_scene_packed: PackedScene = null
var dino_script: GDScript = null
var tower_script: GDScript = null
var wall_script: GDScript = null
var core_campfire_script: GDScript = null
var nest_script: GDScript = null

# Cleanup Tracking
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

	if ResourceLoader.exists("res://scenes/Main.tscn"):
		main_scene_packed = load("res://scenes/Main.tscn")

	dino_script = _load_script(["res://scripts/entities/Dino.gd"])
	tower_script = _load_script(["res://scripts/entities/Tower.gd"])
	wall_script = _load_script(["res://scripts/entities/Wall.gd"])
	core_campfire_script = _load_script(["res://scripts/entities/CoreCampfire.gd"])
	nest_script = _load_script(["res://scripts/entities/Nest.gd"])

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	# v0.4 gates the turret behind a blueprint and stone behind a pick. This suite is
	# about something else, so it starts with the cabin's work already done rather
	# than walking that chain in every test.
	unlock_all()

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
# Helper Factories
# ==============================================================================

func _load_script(paths: Array[String]) -> GDScript:
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is GDScript:
				return res
	return null

func _create_main_scene() -> Node:
	assert_not_null(main_scene_packed, "Main.tscn must exist and be loadable")
	if main_scene_packed == null:
		return null
	var inst = main_scene_packed.instantiate()
	_cleanup_nodes.append(inst)
	if tree != null and tree.root != null:
		tree.root.add_child(inst)
	return inst

# ==============================================================================
# Test 1: Complete End-to-End Game Loop Integration Stress Test
# ==============================================================================

func test_01_full_loop_multi_cycle_integration_e2e() -> void:
	# --------------------------------------------------------------------------
	# Phase A: Start game in Main scene & Verify pristine baseline
	# --------------------------------------------------------------------------
	var main = _create_main_scene()
	assert_not_null(main, "Main scene instantiated successfully")
	if main == null: return
	await wait_frames(2)

	# Verify Initial GameState
	assert_eq(int(game_state_node.current_phase), 0, "Initial Phase must be PLAN (0)")
	assert_eq(int(game_state_node.resources.get("wood", 0)), opening_banked_wood(), "Wood starts at the Config opening balance")
	assert_eq(int(game_state_node.wave_number), 0, "Initial wave_number must be 0")
	assert_false(bool(game_state_node.get("is_game_over")), "Initial is_game_over must be false")
	assert_false(bool(game_state_node.get("is_game_won")), "Initial is_game_won must be false")

	# Verify Level Entities
	assert_not_null(main.current_core, "CoreCampfire must exist in Main")
	assert_not_null(main.current_nest, "Nest must exist in Main")
	assert_almost_eq(float(main.current_core.current_hp), 10.0, 0.001, "Core HP initialized to 10.0")
	assert_almost_eq(float(main.current_nest.current_hp), 30.0, 0.001, "Nest HP initialized to 30.0")

	# Verify GridManager Occupancy
	assert_true(main.grid_manager.is_cell_occupied(Vector2i(0, 0)), "Core cell (0, 0) is occupied")
	assert_true(main.grid_manager.is_cell_occupied(Vector2i(0, -9)), "Nest cell (0, -9) is occupied")
	assert_eq(main.grid_manager.occupied_cells.size(), 2, "Grid tracks exactly 2 occupied cells")

	# Verify HUD Initial State
	var hud = main.hud
	assert_not_null(hud, "HUD exists in Main")
	assert_eq(hud.get_wood_text(), tr("HUD_WOOD") % opening_banked_wood(), "HUD displays the opening wood balance")
	assert_eq(hud.get_core_hp_text(), "Core HP: 10 / 10", "HUD displays Core HP: 10 / 10")
	assert_eq(hud.get_phase_text(), "Phase: PLAN", "HUD displays Phase: PLAN")
	assert_false(hud.is_game_over_visible(), "GameOver modal is hidden initially")
	assert_false(hud.end_action_btn.disabled, "End Action button enabled in PLAN")

	# --------------------------------------------------------------------------
	# Phase B: Plan Phase Building Placement (Wall, LumberHut, Tower)
	# --------------------------------------------------------------------------
	# Fund the placements from Config so this test measures the loop, not the
	# balance. A turret is bought with wood and stone as of v0.4, so the stone side
	# of its bill is paid separately and the running total tracks wood only.
	var expected_wood: int = total_cost_of(["wall", "tower", "wall"]) + 1
	game_state_node.resources["wood"] = expected_wood
	game_state_node.resources["stone"] = int(config_node.BUILDINGS["tower"]["cost"].get("stone", 0))
	await wait_frames(1)

	var wall_node = main.place_building_at_cell("wall", Vector2i(1, 1))
	assert_not_null(wall_node, "Wall placed successfully at (1, 1)")
	expected_wood -= cost_of("wall")
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Wood deducted by the wall cost")
	assert_true(main.grid_manager.is_cell_occupied(Vector2i(1, 1)), "Cell (1, 1) is occupied")

	# 2. Place LumberHut at (2, 2)
	# A stake rather than a second turret: a turret is bought with wood and stone
	# now, and this test tracks a wood budget through the whole loop.
	var lumber_node = main.place_building_at_cell("wall", Vector2i(2, 2))
	assert_not_null(lumber_node, "Stake placed successfully at (2, 2)")
	expected_wood -= cost_of("wall")
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Wood deducted by the stake cost")
	assert_true(main.grid_manager.is_cell_occupied(Vector2i(2, 2)), "Cell (2, 2) is occupied")

	# 3. Place Tower at (1, -1)
	var tower_node = main.place_building_at_cell("tower", Vector2i(1, -1))
	assert_not_null(tower_node, "Tower placed successfully at (1, -1)")
	expected_wood -= cost_of("tower")
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Wood deducted by the tower cost")
	assert_true(main.grid_manager.is_cell_occupied(Vector2i(1, -1)), "Cell (1, -1) is occupied")

	var rejected_building = main.place_building_at_cell("wall", Vector2i(-1, 1))
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Wood unchanged by the rejected placement")

	# Verify HUD reflections
	await wait_frames(1)
	assert_eq(hud.get_wood_text(), tr("HUD_WOOD") % expected_wood, "HUD reflects the remaining wood")

	# --------------------------------------------------------------------------
	# Phase C: Trigger End Action -> transitions to ATTACK
	# --------------------------------------------------------------------------
	hud.simulate_end_action_click()
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 1, "Phase transitioned to ATTACK (1)")
	assert_eq(hud.get_phase_text(), "Phase: ATTACK", "HUD displays Phase: ATTACK")
	assert_true(hud.end_action_btn.disabled, "End Action button disabled during ATTACK")

	# Verify Wave 1 started
	var wave_mgr = main.wave_manager
	assert_true(wave_mgr.is_wave_active, "WaveManager is_wave_active is true")
	assert_eq(wave_mgr.current_wave, 1, "WaveManager current_wave is 1")
	assert_eq(game_state_node.wave_number, 1, "GameState wave_number is 1")
	assert_eq(wave_mgr.dinos_alive_count, 2, "Wave 1 spawns 2 dinos (base_count 2)")

	# --------------------------------------------------------------------------
	# --------------------------------------------------------------------------
	# --- Wave 1 Combat & Resolution ---
	# Eliminate the 2 dinos of wave 1
	event_bus_node.dino_died.emit(null)
	event_bus_node.dino_died.emit(null)
	await wait_frames(1)

	assert_false(wave_mgr.is_wave_active, "Wave 1 ended")
	assert_eq(int(game_state_node.current_phase), 2, "Transitioned to PRODUCE (2)")
	assert_eq(hud.get_phase_text(), "Phase: PRODUCE", "HUD displays Phase: PRODUCE")

	# v0.4: buildings produce nothing, so a produce phase moves no numbers at all.
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "A produce phase pays out nothing")
	assert_eq(hud.get_wood_text(), tr("HUD_WOOD") % expected_wood, "And the HUD agrees")

	# Advance PRODUCE -> PLAN
	game_state_node.end_produce_phase()
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 0, "Transitioned to PLAN (0)")
	assert_false(hud.end_action_btn.disabled, "End Action button re-enabled for new turn")

	# --- Wave 2 Execution ---
	hud.simulate_end_action_click()
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 1, "Phase transitioned to ATTACK (1)")
	assert_eq(wave_mgr.current_wave, 2, "WaveManager current_wave is 2")
	assert_eq(wave_mgr.dinos_alive_count, 3, "Wave 2 spawns 3 dinos (base 2 + 1)")

	# Eliminate 3 dinos of wave 2
	event_bus_node.dino_died.emit(null)
	event_bus_node.dino_died.emit(null)
	event_bus_node.dino_died.emit(null)
	await wait_frames(1)

	assert_false(wave_mgr.is_wave_active, "Wave 2 ended")
	assert_eq(int(game_state_node.current_phase), 2, "Transitioned to PRODUCE (2)")

	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Still nothing produced")
	assert_eq(hud.get_wood_text(), tr("HUD_WOOD") % expected_wood, "And the HUD still agrees")

	# Advance PRODUCE -> PLAN
	game_state_node.end_produce_phase()
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 0, "Transitioned to PLAN (0)")

	# --------------------------------------------------------------------------
	# Phase E: Reach Wave 3 (Horde Wave, 8 dinos), verify horde multiplier & buff
	# --------------------------------------------------------------------------
	hud.simulate_end_action_click()
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 1, "Phase transitioned to ATTACK (1)")
	assert_eq(wave_mgr.current_wave, 3, "WaveManager current_wave is 3")
	assert_true(wave_mgr.is_big_wave(3), "Wave 3 is flagged as big horde wave")

	# Verify horde count: (base_count 2 + 2) * 2.0 = 8 dinos
	assert_eq(wave_mgr.dinos_alive_count, 8, "Wave 3 horde spawns exactly 8 dinos")
	assert_true("大波" in hud.get_wave_text() or "Horde" in hud.get_wave_text(), "HUD wave label announces horde wave: '%s'" % hud.get_wave_text())

	# Initial multipliers before wave 3 ends
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.0, 0.001, "Pre-horde HP multiplier is 1.0")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.0, 0.001, "Pre-horde damage multiplier is 1.0")

	# Eliminate all 8 dinos of wave 3 horde
	for i in range(8):
		event_bus_node.dino_died.emit(null)
	await wait_frames(1)

	assert_false(wave_mgr.is_wave_active, "Wave 3 horde ended")

	# Verify post-horde stat enhancement applied: Config.WAVES.enhance_after_big (hp 1.3, damage 1.2)
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.3, 0.001, "Post-horde HP mult scaled to 1.3")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.2, 0.001, "Post-horde damage mult scaled to 1.2")

	assert_eq(int(game_state_node.current_phase), 2, "Transitioned to PRODUCE (2)")
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Nothing produced on turn 3 either")

	# Advance to PLAN
	game_state_node.end_produce_phase()
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 0, "Transitioned to PLAN (0)")
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Player wood matches the running total")

	# --------------------------------------------------------------------------
	# Phase F: Place Tower within 5.0m of Nest, destroy Nest -> triggers Victory
	# --------------------------------------------------------------------------
	# Nest is at cell (0, -9) / world (0, 0, -18).
	# Placing Tower at cell (0, -8) / world (0, 0, -16) gives distance 2.0m <= 5.0m attack range!
	# Fund the assault tower from Config rather than from the old balance.
	expected_wood = cost_of("tower") + 2
	game_state_node.resources["wood"] = expected_wood
	game_state_node.resources["stone"] = int(config_node.BUILDINGS["tower"]["cost"].get("stone", 0))
	await wait_frames(1)
	var assault_tower = main.place_building_at_cell("tower", Vector2i(0, -8))
	assert_not_null(assault_tower, "Assault Tower successfully placed at (0, -8)")
	expected_wood -= cost_of("tower")
	assert_eq(int(game_state_node.resources["wood"]), expected_wood, "Wood drops by the tower cost")

	var nest = main.current_nest
	assert_not_null(nest, "Nest is present")
	var dist_to_nest = assault_tower.global_position.distance_to(nest.global_position)
	assert_lte(dist_to_nest, 5.0, "Assault Tower is within 5.0m range of Nest (actual: %.2f m)" % dist_to_nest)

	# Register Nest in tower detection and engage assault
	if assault_tower.has_method("on_target_entered"):
		assault_tower.on_target_entered(nest)

	var target = assault_tower.acquire_target() if assault_tower.has_method("acquire_target") else null
	assert_eq(target, nest, "Assault Tower successfully acquires Nest as target")

	var game_won_watcher = watch_signal(event_bus_node, "game_won")

	# Tower inflicts 30 attacks @ 1.0 dmg to destroy 30 HP Nest
	for i in range(30):
		if not is_instance_valid(nest) or nest.current_hp <= 0.0:
			break
		assault_tower.fire_at(nest)

	await wait_frames(2)

	# Verify Victory
	assert_true(game_won_watcher.emitted, "EventBus.game_won emitted upon Nest destruction")
	assert_true(bool(game_state_node.get("is_game_won")), "GameState.is_game_won is true")
	assert_true(bool(game_state_node.get("is_game_over")), "GameState.is_game_over is true")
	assert_true(hud.is_game_over_visible(), "HUD GameOver panel visible on victory")
	assert_true("VICTORY" in hud.get_game_over_title() or "胜" in hud.get_game_over_title(),
		"HUD GameOver title indicates Victory (got '%s')" % hud.get_game_over_title())

	# --------------------------------------------------------------------------
	# Phase G: Verify Action Lockout on Victory
	# --------------------------------------------------------------------------
	var pre_phase = int(game_state_node.current_phase)
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), pre_phase, "trigger_end_action blocked under victory")

	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), pre_phase, "advance_phase blocked under victory")


	assert_false(main.build_system.can_place_building("wall", Vector2i(-2, -2)), "can_place_building false under victory")
	var illegal_b = main.place_building_at_cell("wall", Vector2i(-2, -2))
	assert_null(illegal_b, "place_building returns null under victory")

	assert_true(hud.end_action_btn.disabled, "HUD End Action disabled under victory")
	assert_true(hud.end_action_btn.disabled, "HUD action controls disabled under victory")

	# --------------------------------------------------------------------------
	# Phase H: Trigger restart_game(), verify pristine state
	# --------------------------------------------------------------------------
	main.restart_game()
	await wait_frames(2)

	# Verify complete state purge and baseline restoration
	assert_false(bool(game_state_node.get("is_game_over")), "is_game_over reset to false")
	assert_false(bool(game_state_node.get("is_game_won")), "is_game_won reset to false")
	assert_eq(int(game_state_node.current_phase), 0, "Phase reset to PLAN (0)")
	assert_eq(int(game_state_node.resources["wood"]), opening_banked_wood(), "Wood reset to the Config opening balance")
	assert_eq(int(game_state_node.wave_number), 0, "wave_number reset to 0")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("hp", 1.0)), 1.0, 0.001, "HP mult reset to 1.0")
	assert_almost_eq(float(game_state_node.dino_stat_multipliers.get("damage", 1.0)), 1.0, 0.001, "Damage mult reset to 1.0")

	# Verify pristine entities
	assert_not_null(main.current_core, "Pristine Core exists after restart")
	assert_not_null(main.current_nest, "Pristine Nest exists after restart")
	assert_almost_eq(float(main.current_core.current_hp), 10.0, 0.001, "Core HP restored to full 10.0")
	assert_almost_eq(float(main.current_nest.current_hp), 30.0, 0.001, "Nest HP restored to full 30.0")

	# Verify grid and container purging
	assert_eq(main.buildings_container.get_child_count(), 1, "Buildings container contains only 1 building (Core)")
	assert_eq(main.dinos_container.get_child_count(), 0, "Dinos container has 0 dinos")
	assert_eq(main.grid_manager.occupied_cells.size(), 2, "Grid occupancy restored to 2")
	assert_false(main.grid_manager.is_cell_occupied(Vector2i(1, 1)), "Old Wall cell vacated")
	assert_false(main.grid_manager.is_cell_occupied(Vector2i(2, 2)), "Old Lumber cell vacated")
	assert_false(main.grid_manager.is_cell_occupied(Vector2i(1, -1)), "Old Tower cell vacated")
	assert_false(main.grid_manager.is_cell_occupied(Vector2i(0, -8)), "Old Assault Tower cell vacated")

	# Verify HUD re-initialization
	assert_false(hud.is_game_over_visible(), "GameOver modal hidden after restart")
	assert_false(hud.end_action_btn.disabled, "End Action re-enabled after restart")
	assert_eq(hud.get_wood_text(), tr("HUD_WOOD") % opening_banked_wood(), "HUD displays the opening wood balance")
	assert_eq(hud.get_core_hp_text(), "Core HP: 10 / 10", "HUD displays Core HP: 10 / 10")
	assert_eq(hud.get_phase_text(), "Phase: PLAN", "HUD displays Phase: PLAN")

	# --------------------------------------------------------------------------
	# Phase I: Allow dinos to destroy Core Campfire -> triggers Defeat
	# --------------------------------------------------------------------------
	# Start Wave 1
	hud.simulate_end_action_click()
	await wait_frames(1)

	assert_eq(int(game_state_node.current_phase), 1, "Phase is ATTACK (1)")
	var game_lost_watcher = watch_signal(event_bus_node, "game_lost")

	# Dinosaurs breach defenses and inflict lethal 10.0 damage on Core
	main.current_core.take_damage(10.0)
	await wait_frames(2)

	# Verify Defeat
	assert_true(game_lost_watcher.emitted, "EventBus.game_lost emitted upon Core destruction")
	assert_true(bool(game_state_node.get("is_game_over")), "GameState.is_game_over is true on defeat")
	assert_false(bool(game_state_node.get("is_game_won")), "GameState.is_game_won is false on defeat")
	assert_true(hud.is_game_over_visible(), "HUD GameOver modal visible on defeat")
	assert_true("DEFEAT" in hud.get_game_over_title() or "败" in hud.get_game_over_title(),
		"HUD GameOver title indicates Defeat (got '%s')" % hud.get_game_over_title())

	# --------------------------------------------------------------------------
	# Phase J: Verify Action Lockout on Defeat
	# --------------------------------------------------------------------------
	var loss_phase = int(game_state_node.current_phase)
	game_state_node.trigger_end_action()
	assert_eq(int(game_state_node.current_phase), loss_phase, "trigger_end_action blocked under defeat")

	game_state_node.advance_phase()
	assert_eq(int(game_state_node.current_phase), loss_phase, "advance_phase blocked under defeat")


	var illegal_loss_b = main.place_building_at_cell("wall", Vector2i(2, 2))
	assert_null(illegal_loss_b, "place_building returns null under defeat")

	assert_true(hud.end_action_btn.disabled, "HUD End Action disabled under defeat")
	assert_true(hud.end_action_btn.disabled, "HUD action controls disabled under defeat")

	# --------------------------------------------------------------------------
	# Phase K: Trigger restart_game() again, verify pristine state
	# --------------------------------------------------------------------------
	hud.simulate_restart_click()
	await wait_frames(2)

	assert_false(bool(game_state_node.get("is_game_over")), "is_game_over reset to false after 2nd restart")
	assert_false(bool(game_state_node.get("is_game_won")), "is_game_won reset to false after 2nd restart")
	assert_eq(int(game_state_node.current_phase), 0, "Phase reset to PLAN (0)")
	assert_eq(int(game_state_node.resources["wood"]), opening_banked_wood(), "Wood reset to the Config opening balance")
	assert_eq(int(game_state_node.wave_number), 0, "wave_number reset to 0")

	assert_not_null(main.current_core, "Pristine Core exists after 2nd restart")
	assert_not_null(main.current_nest, "Pristine Nest exists after 2nd restart")
	assert_almost_eq(float(main.current_core.current_hp), 10.0, 0.001, "Core HP is 10.0")
	assert_almost_eq(float(main.current_nest.current_hp), 30.0, 0.001, "Nest HP is 30.0")

	assert_false(hud.is_game_over_visible(), "GameOver modal hidden after 2nd restart")
	assert_false(hud.end_action_btn.disabled, "End Action re-enabled after 2nd restart")
	assert_eq(hud.get_wood_text(), tr("HUD_WOOD") % opening_banked_wood(), "HUD displays the opening wood balance")
	assert_eq(hud.get_core_hp_text(), "Core HP: 10 / 10", "HUD displays Core HP: 10 / 10")

# ==============================================================================
# Test 2: Consecutive Horde Progression & Multiplier Compounding Stress
# ==============================================================================

func test_02_horde_progression_and_stat_compounding_stress() -> void:
	var main = _create_main_scene()
	if main == null: return
	await wait_frames(2)

	var wm = main.wave_manager

	# Track progression across 6 full waves (Wave 3 and Wave 6 are Horde waves)
	for w in range(1, 7):
		assert_eq(int(game_state_node.current_phase), 0, "Turn %d starts in PLAN" % w)

		# Trigger ATTACK
		main.hud.simulate_end_action_click()
		assert_eq(int(game_state_node.current_phase), 1, "Turn %d enters ATTACK" % w)

		var is_horde: bool = (w % 3 == 0)
		assert_eq(wm.is_big_wave(w), is_horde, "Wave %d horde flag check" % w)

		var expected_count: int = 0
		var base = 2 + (w - 1) * 1
		if is_horde:
			expected_count = int(base * 2.0)
		else:
			expected_count = base

		assert_eq(wm.dinos_alive_count, expected_count, "Wave %d dinos count is %d" % [w, expected_count])

		# Specific horde wave checks
		if w == 3:
			assert_eq(expected_count, 8, "Wave 3 horde has exactly 8 dinos")
		elif w == 6:
			assert_eq(expected_count, 14, "Wave 6 horde has exactly 14 dinos ((2+5)*2)")

		# Eliminate all dinos
		for d in range(expected_count):
			event_bus_node.dino_died.emit(null)

		assert_eq(int(game_state_node.current_phase), 2, "Turn %d enters PRODUCE" % w)

		# Check stat enhancement compounding after horde waves
		if w == 3:
			# Post-wave 3: 1.0 * 1.3 = 1.3 HP, 1.0 * 1.2 = 1.2 Damage
			assert_almost_eq(float(game_state_node.dino_stat_multipliers["hp"]), 1.3, 0.001, "Post-wave 3 HP mult is 1.3")
			assert_almost_eq(float(game_state_node.dino_stat_multipliers["damage"]), 1.2, 0.001, "Post-wave 3 damage mult is 1.2")
		elif w == 6:
			# Post-wave 6: 1.3 * 1.3 = 1.69 HP, 1.2 * 1.2 = 1.44 Damage
			assert_almost_eq(float(game_state_node.dino_stat_multipliers["hp"]), 1.69, 0.001, "Post-wave 6 HP mult is 1.69")
			assert_almost_eq(float(game_state_node.dino_stat_multipliers["damage"]), 1.44, 0.001, "Post-wave 6 damage mult is 1.44")

		# Advance PRODUCE -> PLAN
		game_state_node.end_produce_phase()
		assert_eq(int(game_state_node.current_phase), 0, "Turn %d returns to PLAN" % w)

# ==============================================================================
# Test 3: Multiple Lumber Huts Economy Compounding & Clean Restart
# ==============================================================================


# ==============================================================================
# Test 4: Rapid Alternating Victory-Defeat-Restart Stress Loop
# ==============================================================================

func test_04_rapid_alternating_victory_defeat_restart_stress() -> void:
	var main = _create_main_scene()
	if main == null: return
	await wait_frames(2)

	for cycle in range(6):
		if cycle % 2 == 0:
			# Trigger Victory via Nest destruction
			main.current_nest.take_damage(30.0)
			await wait_frames(1)
			assert_true(bool(game_state_node.get("is_game_won")), "Cycle %d: Game won" % cycle)
			assert_true(main.hud.is_game_over_visible(), "Cycle %d: Modal visible" % cycle)
		else:
			# Trigger Defeat via Core destruction
			main.current_core.take_damage(10.0)
			await wait_frames(1)
			assert_true(bool(game_state_node.get("is_game_over")), "Cycle %d: Game over" % cycle)
			assert_false(bool(game_state_node.get("is_game_won")), "Cycle %d: Not won" % cycle)

		# Restart
		main.restart_game()
		await wait_frames(1)

		# Invariants check
		assert_false(bool(game_state_node.get("is_game_over")), "Cycle %d: is_game_over cleared" % cycle)
		assert_false(bool(game_state_node.get("is_game_won")), "Cycle %d: is_game_won cleared" % cycle)
		assert_eq(int(game_state_node.current_phase), 0, "Cycle %d: Phase is PLAN" % cycle)
		assert_almost_eq(float(main.current_core.current_hp), 10.0, 0.001, "Cycle %d: Core HP is 10.0" % cycle)
		assert_almost_eq(float(main.current_nest.current_hp), 30.0, 0.001, "Cycle %d: Nest HP is 30.0" % cycle)
		assert_eq(main.grid_manager.occupied_cells.size(), 2, "Cycle %d: Grid size is 2" % cycle)
		assert_false(main.hud.is_game_over_visible(), "Cycle %d: HUD modal hidden" % cycle)

# ==============================================================================
# Test 5: Full Lockout Bombardment Oracle
# ==============================================================================

func test_05_strict_lockout_adversarial_hammering_oracle() -> void:
	var main = _create_main_scene()
	if main == null: return
	await wait_frames(2)

	# Trigger Defeat
	main.current_core.take_damage(10.0)
	await wait_frames(1)
	assert_true(bool(game_state_node.get("is_game_over")), "Defeat active")

	for i in range(30):
		var b = main.place_building_at_cell("wall", Vector2i(i + 1, 1))
		assert_null(b, "Bombard %d: placement rejected" % i)
		main.hud.simulate_end_action_click()

	assert_eq(int(game_state_node.resources["wood"]), opening_banked_wood(), "Wood untouched through bombardment")
	assert_eq(main.buildings_container.get_child_count(), 0, "No buildings placed")
