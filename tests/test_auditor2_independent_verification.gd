# res://tests/test_auditor2_independent_verification.gd
extends SceneTree

var total_probes: int = 0
var passed_probes: int = 0
var failed_probes: int = 0
var probe_failures: Array[String] = []

func _init() -> void:
	await process_frame
	print('============================================================')
	print('VICTORY AUDITOR 2: INDEPENDENT VERIFICATION PROBES')
	print('Target: Defend Dinosaur v0.0 | Godot 4.7.1 Headless')
	print('============================================================
')

	await run_probe('Probe 1: R1 Autoloads, EventBus Signals, Config Values and Dynamic Mock Binding', probe_r1)
	await run_probe('Probe 2: R2 Grid Conversions and Placement Invariants', probe_r2)
	await run_probe('Probe 3: R3 Turn State Machine and Resource Payout', probe_r3)
	await run_probe('Probe 4: R4 Dino AI, Tower Range and Wave Scaling', probe_r4)
	await run_probe('Probe 5: R5 Win/Loss Mutual Exclusion and Main Restart', probe_r5)

	print('
============================================================')
	print('VICTORY AUDITOR 2 PROBE SUMMARY')
	print('Total Probes: %d | Passed: %d | Failed: %d' % [total_probes, passed_probes, failed_probes])
	print('============================================================
')

	if failed_probes > 0:
		for f in probe_failures:
			printerr('  [X] %s' % f)
		print('VERDICT: INDEPENDENT PROBES FAILED')
		quit(1)
	else:
		print('VERDICT: ALL INDEPENDENT PROBES PASSED')
		quit(0)

func run_probe(probe_name: String, callable: Callable) -> void:
	total_probes += 1
	print('>>> RUNNING %s...' % probe_name)
	var initial_fails = probe_failures.size()
	await callable.call()
	if probe_failures.size() == initial_fails:
		passed_probes += 1
		print('  [PASS] %s
' % probe_name)
	else:
		failed_probes += 1
		printerr('  [FAIL] %s
' % probe_name)

func audit_assert(condition: bool, fail_msg: String) -> void:
	if not condition:
		probe_failures.append(fail_msg)
		printerr('    [ASSERTION FAILED]: %s' % fail_msg)

# Probe 1: R1 Autoloads and Config Dynamic Binding
func probe_r1() -> void:
	var cfg = root.get_node_or_null('Config')
	var eb = root.get_node_or_null('EventBus')
	var gs = root.get_node_or_null('GameState')
	audit_assert(cfg != null, 'Autoload /root/Config exists')
	audit_assert(eb != null, 'Autoload /root/EventBus exists')
	audit_assert(gs != null, 'Autoload /root/GameState exists')
	if cfg == null or eb == null or gs == null: return

	# 1. Config Invariants
	audit_assert(cfg.get('TILE_SIZE') == 2.0, 'Config.TILE_SIZE is 2.0')
	var b_dict = cfg.get('BUILDINGS')
	audit_assert(b_dict is Dictionary, 'Config.BUILDINGS is Dictionary')
	audit_assert(b_dict.has('core') and b_dict['core'].get('hp') == 10.0, 'Config core hp is 10')
	audit_assert(b_dict.has('tower') and b_dict['tower'].get('cost', {}).get('wood') == 4, 'Config tower cost 4 wood')
	audit_assert(b_dict.has('wall') and b_dict['wall'].get('hp') == 30.0, 'Config wall hp is 30')
	audit_assert(b_dict.has('lumber_hut') and b_dict['lumber_hut'].get('produces', {}).get('wood') == 2, 'Config lumber_hut produces 2 wood')

	var d_dict = cfg.get('DINOS')
	audit_assert(d_dict is Dictionary and d_dict.has('raptor'), 'Config raptor exists')
	audit_assert(d_dict['raptor'].get('hp') == 3.0, 'Config raptor hp is 3')
	audit_assert(d_dict['raptor'].get('speed') == 4.0, 'Config raptor speed is 4')

	var w_dict = cfg.get('WAVES')
	audit_assert(w_dict is Dictionary and w_dict.get('big_every') == 3, 'Config waves big_every is 3')
	audit_assert(w_dict.get('big_multiplier') == 2.0, 'Config waves big_multiplier is 2.0')

	# 2. EventBus Signals
	var expected_signals = [
		'phase_changed', 'produce_phase', 'game_won', 'game_lost',
		'resources_changed',
		'building_placed', 'building_destroyed', 'core_hp_changed',
		'wave_started', 'wave_ended',
		'dino_spawned', 'dino_died', 'dino_reached_core',
		'nest_destroyed'
	]
	for sig in expected_signals:
		audit_assert(eb.has_signal(sig), 'EventBus signal %s exists' % sig)

	# 3. Dynamic binding proof via Mock Config
	var mock_script = load('z:/home/zkl-unix/repo/game/dino/.agents/auditor_m6_1/mock_config_m6.gd')
	audit_assert(mock_script != null, 'Mock Config loads')
	if mock_script != null:
		var mock_cfg = mock_script.new()
		mock_cfg.name = 'Config'
		root.remove_child(cfg)
		root.add_child(mock_cfg)
		await process_frame

		gs.reset_game()
		audit_assert(gs.resources.get('wood') == 50, 'GameState.resources.wood dynamically bound to Mock Config 50')

		root.remove_child(mock_cfg)
		mock_cfg.queue_free()
		root.add_child(cfg)
		await process_frame
		gs.reset_game()
		audit_assert(gs.resources.get('wood') == 10, 'Restored original config yields wood=10')

# Probe 2: R2 Grid Conversions and Placement Invariants
func probe_r2() -> void:
	var gm_script = load('res://scripts/core/GridManager.gd')
	var bs_script = load('res://scripts/core/BuildSystem.gd')
	audit_assert(gm_script != null and bs_script != null, 'Grid scripts load')
	if gm_script == null or bs_script == null: return

	var gm = gm_script.new()
	var bs = bs_script.new()
	var container = Node3D.new()
	root.add_child(gm)
	root.add_child(bs)
	root.add_child(container)
	bs.setup(gm, container)

	audit_assert(gm.world_to_cell(Vector3(0.0, 0.0, 0.0)) == Vector2i(0, 0), 'Origin -> 0,0')
	audit_assert(gm.world_to_cell(Vector3(1.99, 0.0, 3.99)) == Vector2i(0, 1), 'Near boundary -> 0,1')
	audit_assert(gm.world_to_cell(Vector3(2.01, 0.0, 4.01)) == Vector2i(1, 2), 'Across boundary -> 1,2')
	audit_assert(gm.world_to_cell(Vector3(-0.01, 0.0, -0.01)) == Vector2i(-1, -1), 'Negative near zero -> -1,-1')
	audit_assert(gm.world_to_cell(Vector3(-2.0, 0.0, -4.0)) == Vector2i(-1, -2), 'Negative exact boundary -> -1,-2')
	audit_assert(gm.world_to_cell(Vector3(-2.01, 0.0, -4.01)) == Vector2i(-2, -3), 'Negative across boundary -> -2,-3')

	var center_neg = gm.cell_to_world(Vector2i(-1, -2))
	audit_assert(center_neg.is_equal_approx(Vector3(-1.0, 0.0, -3.0)), 'Cell -1,-2 center is -1, 0, -3')

	var gs = root.get_node('GameState')
	gs.reset_game()

	var test_cell = Vector2i(10, 10)
	audit_assert(bs.can_place_building('tower', test_cell), 'Can place tower at 10,10')
	var tower = bs.place_building('tower', test_cell)
	audit_assert(tower != null, 'Tower placed')
	audit_assert(gm.is_cell_occupied(test_cell), 'Cell occupied')
	audit_assert(gs.resources['wood'] == 6, 'Wood 10->6')

	audit_assert(not bs.can_place_building('wall', test_cell), 'Duplicate placement blocked')
	audit_assert(bs.place_building('wall', test_cell) == null, 'Duplicate returns null')

	audit_assert(not bs.can_place_building('wall', Vector2i(11, 10)), '0 AP blocked')

	gs.resources['wood'] = 1
	audit_assert(not bs.can_place_building('wall', Vector2i(12, 10)), 'Insufficient wood blocked')

	tower.take_damage(tower.max_hp)
	await process_frame
	audit_assert(not gm.is_cell_occupied(test_cell), 'Cell vacated on destruction')

	gm.queue_free()
	bs.queue_free()
	container.queue_free()
	await process_frame

# Probe 3: R3 Turn State Machine and Resource Payout
func probe_r3() -> void:
	var gs = root.get_node('GameState')
	gs.reset_game()

	audit_assert(gs.current_phase == 0, 'Phase 0 PLAN')

	gs.trigger_end_action()
	audit_assert(gs.current_phase == 1, 'Phase 1 ATTACK')

	gs.trigger_end_action()
	audit_assert(gs.current_phase == 1, 'Spurious trigger_end_action in ATTACK ignored')

	var lumber_script = load('res://scripts/entities/LumberHut.gd')
	var lumber = lumber_script.new()
	root.add_child(lumber)
	await process_frame

	var wood_before = gs.resources.get('wood', 0)
	gs.set_phase(2) # PRODUCE
	audit_assert(gs.current_phase == 2, 'Phase 2 PRODUCE')
	await process_frame
	var wood_after = gs.resources.get('wood', 0)
	audit_assert(wood_after == wood_before + 2, 'LumberHut gave +2 wood')

	gs.end_produce_phase()
	audit_assert(gs.current_phase == 0, 'Phase 0 PLAN')

	lumber.queue_free()
	await process_frame

# Probe 4: R4 Dino AI, Tower Range and Wave Scaling
func probe_r4() -> void:
	var gs = root.get_node('GameState')
	var dino_script = load('res://scripts/entities/Dino.gd')
	var tower_script = load('res://scripts/entities/Tower.gd')
	var wall_script = load('res://scripts/entities/Wall.gd')
	var wm_script = load('res://scripts/core/WaveManager.gd')

	# 1. Dino Navigation and Wall Blocking
	var dino = dino_script.new('raptor')
	root.add_child(dino)
	dino.position = Vector3(0.0, 0.0, -10.0)
	dino.set_waypoints([Vector3(0.0, 0.0, -5.0), Vector3(0.0, 0.0, 0.0)])
	await process_frame

	var wall = wall_script.new()
	root.add_child(wall)
	wall.position = Vector3(0.0, 0.0, -9.0)
	await process_frame

	dino.advance_towards_waypoint(0.25)
	audit_assert(dino.current_state == 1 or dino.is_blocked, 'Dino blocked by wall')

	var wall_hp = wall.current_hp
	dino.perform_attack()
	audit_assert(wall.current_hp < wall_hp, 'Dino attacked wall')

	wall.destroy()
	await process_frame
	dino._process_attacking(0.0)
	audit_assert(dino.current_state == 0, 'Dino resumed walking')

	dino.die()
	await process_frame

	# 2. Tower Range and Nearest Target Acquisition
	var tower = tower_script.new()
	root.add_child(tower)
	tower.position = Vector3(0.0, 0.0, 0.0)
	await process_frame

	var near_dino = dino_script.new('raptor')
	var far_dino = dino_script.new('raptor')
	var out_dino = dino_script.new('raptor')
	root.add_child(near_dino)
	root.add_child(far_dino)
	root.add_child(out_dino)

	near_dino.position = Vector3(0.0, 0.0, 2.0)
	far_dino.position = Vector3(0.0, 0.0, 4.0)
	out_dino.position = Vector3(0.0, 0.0, 8.0)
	await process_frame

	tower.on_target_entered(near_dino)
	tower.on_target_entered(far_dino)
	var acquired = tower.acquire_target()
	audit_assert(acquired == near_dino, 'Tower targeted nearest dino 2m vs 4m')

	tower.on_target_died(near_dino)
	near_dino.die()
	await process_frame

	acquired = tower.acquire_target()
	audit_assert(acquired == far_dino, 'Tower re-targeted next nearest dino 4m')

	tower.on_target_died(far_dino)
	far_dino.die()
	out_dino.die()
	tower.queue_free()
	await process_frame

	# 3. Wave Calculations
	var wm = wm_script.new()
	root.add_child(wm)
	await process_frame

	audit_assert(wm.get_wave_dino_count(1) == 2, 'Wave 1 count = 2')
	audit_assert(wm.get_wave_dino_count(2) == 3, 'Wave 2 count = 3')
	audit_assert(wm.get_wave_dino_count(3) == 8, 'Wave 3 count = 8')
	audit_assert(wm.is_big_wave(3) == true, 'Wave 3 is big')
	audit_assert(wm.get_wave_dino_count(4) == 5, 'Wave 4 count = 5')
	audit_assert(wm.is_big_wave(4) == false, 'Wave 4 not big')
	audit_assert(wm.get_wave_dino_count(6) == 14, 'Wave 6 count = 14')

	gs.reset_game()
	audit_assert(is_equal_approx(gs.dino_stat_multipliers['hp'], 1.0), 'Initial HP mult = 1.0')
	gs._on_wave_ended(3)
	audit_assert(is_equal_approx(gs.dino_stat_multipliers['hp'], 1.3), 'Post wave 3 HP scaled 1.3')
	audit_assert(is_equal_approx(gs.dino_stat_multipliers['damage'], 1.2), 'Post wave 3 dmg scaled 1.2')

	wm.queue_free()
	await process_frame

# Probe 5: R5 Win/Loss Mutual Exclusion and Main Restart
func probe_r5() -> void:
	var gs = root.get_node('GameState')
	var eb = root.get_node('EventBus')
	var core_script = load('res://scripts/entities/CoreCampfire.gd')
	var nest_script = load('res://scripts/entities/Nest.gd')
	var hud_script = load('res://scripts/ui/HUD.gd')
	var main_script = load('res://scripts/core/Main.gd')

	# 1. Defeat condition and action lock
	gs.reset_game()
	var core = core_script.new()
	root.add_child(core)
	await process_frame

	core.take_damage(core.max_hp)
	await process_frame
	audit_assert(gs.is_game_over == true, 'Game over on core death')
	audit_assert(gs.is_game_won == false, 'Game lost on core death')
	audit_assert(not gs.spend_resources({'wood': 1}), 'Resource spend blocked')

	eb.game_won.emit()
	audit_assert(gs.is_game_won == false, 'Defeat cannot be overturned by victory')

	# 2. Victory condition
	gs.reset_game()
	var nest = nest_script.new()
	root.add_child(nest)
	await process_frame

	nest.take_damage(nest.max_hp)
	await process_frame
	audit_assert(gs.is_game_over == true, 'Game over on nest death')
	audit_assert(gs.is_game_won == true, 'Game won on nest death')

	eb.game_lost.emit()
	audit_assert(gs.is_game_won == true, 'Victory cannot be overturned by defeat')

	# 3. HUD Reactivity
	var hud = hud_script.new()
	root.add_child(hud)
	await process_frame


	eb.resources_changed.emit({'wood': 25})
	audit_assert(hud.get_wood_text().contains('25'), 'HUD wood reactive')

	eb.core_hp_changed.emit(6.0, 10.0)
	audit_assert(hud.get_core_hp_text().contains('6') and hud.get_core_hp_text().contains('10'), 'HUD core_hp reactive')

	eb.game_won.emit()
	audit_assert(hud.is_game_over_visible(), 'HUD game over overlay visible')
	audit_assert(hud.get_result_text().contains('VICTORY'), 'HUD shows VICTORY')
	hud.queue_free()
	await process_frame

	# 4. Main Scene Clean Restart
	var main_node = main_script.new()
	root.add_child(main_node)
	await process_frame

	gs.is_game_over = true
	gs.is_game_won = false
	gs.wave_number = 7
	gs.resources['wood'] = 1

	main_node.restart_game()
	await process_frame

	audit_assert(gs.is_game_over == false, 'Restart resets is_game_over')
	audit_assert(gs.resources['wood'] == 10, 'Restart resets wood')
	audit_assert(gs.wave_number == 0, 'Restart resets wave')
	audit_assert(main_node.current_core != null and is_instance_valid(main_node.current_core), 'Restart reinstantiates core')
	audit_assert(main_node.current_nest != null and is_instance_valid(main_node.current_nest), 'Restart reinstantiates nest')

	main_node.queue_free()
	await process_frame
