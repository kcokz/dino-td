# res://tests/test_v06_beacon.gd
# v0.6 T7: the beacon and the end of a run.
#
# GAME-DESIGN 8.3: the beacon is repaired at the cabin a stage at a time, launched when the
# player chooses, and charged through a final wave that comes from every side with the
# map's boss last of all. Full charge is the jump, and the jump is the only way to win: the
# nest cannot be destroyed. Everything here is read from Config and the run's map.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var event_bus_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
		event_bus_node = tree.root.get_node_or_null("EventBus")

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
	clear_drops()
	if game_state_node != null:
		game_state_node.is_paused = false
		game_state_node.reset_game()
	super.after_each()

func _map() -> Dictionary:
	return game_state_node.map_data()

func _beacon() -> Dictionary:
	return _map()["beacon"]

func _jobs() -> Array[String]:
	return config_node.beacon_jobs(_map())

func _spawn(node: Node) -> Node:
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	return node

## A beacon bench on its own, for everything that needs no level.
func _bench() -> Node:
	return _spawn(load("res://scripts/entities/CraftingStation.gd").new(String(config_node.BEACON_STATION)))

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(6)
	return main

## Works the next `steps` of the beacon at `bench`, paying for each, the way the Hero would.
func _work_steps(bench: Node, steps: int) -> void:
	stock_everything()
	for i in range(steps):
		var job: String = String(game_state_node.beacon_next_job())
		assert_true(bench.begin(job), "The bench takes %s" % job)
		bench.work(bench.time_of(job) + 0.01)

func _launch(bench: Node) -> void:
	_work_steps(bench, _jobs().size())

func _assert_between(value: float, low: float, high: float, message: String) -> void:
	assert_gte(value, low, message)
	assert_lte(value, high, message)

# ==============================================================================
# 1. What it asks for
# ==============================================================================

func test_01_the_stages_climb_the_map_from_what_is_lying_about_to_what_only_a_fight_brings() -> void:
	var stages: Array = _beacon()["stages"]
	assert_gte(stages.size(), 2, "More than one stage: it is repaired over the run, not at once")
	for i in range(stages.size()):
		var inputs: Dictionary = stages[i]["inputs"]
		_assert_between(inputs.size(), 1, 2, "Stage %d asks for one or two materials" % (i + 1))
		for res_id in inputs:
			assert_has(config_node.RESOURCES, String(res_id), "Stage %d's %s is a material" % [i + 1, res_id])
			_assert_between(int(inputs[res_id]), 1, 9, "Single figures (GAME-DESIGN 4.6): %d %s" % [int(inputs[res_id]), res_id])
		assert_gt(float(stages[i]["time"]), 0.0, "And takes time at the bench")
	# The first stage belongs to the opening, the last to the fighting.
	for res_id in stages[0]["inputs"]:
		assert_eq(String(config_node.harvest_requires_unlock(String(res_id))), "",
			"The first stage needs no tool: %s is there for bare hands" % res_id)
	var fought_for: bool = false
	for res_id in stages.back()["inputs"]:
		if not config_node.RESOURCE_NODES.has(String(res_id)):
			fought_for = true
	assert_true(fought_for, "The last stage needs something no tree or rock gives: what a raid leaves")

func test_02_launched_it_charges_for_minutes_and_the_stream_leaves_the_boss_time_to_arrive() -> void:
	assert_gte(float(_beacon()["charge_seconds"]), 60.0, "A charge of minutes: the fight of the run")
	var share: float = float(_beacon()["stream_share"])
	_assert_between(share, 0.1, 0.95, "The stream stops short of the jump, so the last one out has time to get there")
	assert_gt(float(_beacon()["final_raids"]), 1.0, "And it is more than one raid's worth")

func test_03_its_materials_count_it_among_what_they_are_for() -> void:
	for job in _jobs():
		var row: Dictionary = config_node.beacon_job(_map(), job)
		for res_id in row["inputs"]:
			var found: bool = false
			for use in config_node.uses_of(String(res_id), _map()):
				if String(use["kind"]) == "beacon" and String(use["id"]) == job:
					found = true
			assert_true(found, "%s is for %s" % [res_id, job])

# ==============================================================================
# 2. At the bench
# ==============================================================================

func test_04_the_bench_offers_one_step_at_a_time_and_in_order() -> void:
	var bench = _bench()
	await wait_frames(1)
	var jobs: Array[String] = _jobs()
	stock_everything()
	assert_has(bench.jobs(), jobs[0], "The first stage is on offer")
	assert_not_has(bench.jobs(), jobs[1], "The second is not, yet")
	assert_false(bench.begin(jobs[1]), "And cannot be started out of turn")

	var price: Dictionary = config_node.beacon_job(_map(), jobs[0])["inputs"]
	assert_true(bench.begin(jobs[0]), "The first stage is started")
	for res_id in price:
		assert_eq(int(game_state_node.resources[res_id]), 9999 - int(price[res_id]),
			"Paid for up front, like every job at a bench: %s" % res_id)
	bench.work(bench.time_of(jobs[0]) * 0.5)
	assert_eq(int(game_state_node.beacon_steps), 0, "Half the work is not a stage repaired")
	bench.work(bench.time_of(jobs[0]) * 0.5 + 0.01)
	assert_eq(int(game_state_node.beacon_steps), 1, "The whole of it is")
	assert_has(bench.jobs(), jobs[1], "And the next stage comes on offer")
	assert_not_has(bench.jobs(), jobs[0], "While the finished one does not come back")

func test_05_a_step_counts_once_and_only_in_turn() -> void:
	var jobs: Array[String] = _jobs()
	assert_false(game_state_node.finish_beacon_job(jobs[1]), "A stage out of turn changes nothing")
	assert_true(game_state_node.finish_beacon_job(jobs[0]), "The next one counts")
	assert_false(game_state_node.finish_beacon_job(jobs[0]), "And counts once")
	assert_eq(int(game_state_node.beacon_steps), 1, "One stage stands repaired")

func test_06_repaired_it_waits_for_the_player() -> void:
	var bench = _bench()
	await wait_frames(1)
	_work_steps(bench, game_state_node.beacon_stage_count())
	assert_eq(String(game_state_node.beacon_next_job()), String(config_node.BEACON_LAUNCH), "Next is the launch")
	assert_has(bench.jobs(), String(config_node.BEACON_LAUNCH), "Which the bench offers")
	assert_false(game_state_node.is_beacon_launched(), "But nothing starts until the player says so")
	game_state_node.charge_beacon(10000.0)
	assert_almost_eq(float(game_state_node.beacon_charge), 0.0, 0.0001, "A beacon that is not on does not charge")
	assert_false(game_state_node.is_game_won, "And nobody jumps")

func test_07_launched_it_charges_and_the_bench_has_nothing_more() -> void:
	var bench = _bench()
	await wait_frames(1)
	var watcher = watch_signal(event_bus_node, "beacon_launched")
	_launch(bench)
	assert_true(game_state_node.is_beacon_launched(), "It is on")
	assert_eq(watcher.emit_count, 1, "And said so, once")
	for job in _jobs():
		assert_not_has(bench.jobs(), job, "The bench has no more of the beacon to do: %s" % job)

func test_08_the_launch_says_what_is_coming() -> void:
	var panel = _spawn(load("res://scripts/ui/OptionPanel.gd").new())
	await wait_frames(1)
	var text: String = panel._launch_detail()
	var boss_name: String = String(config_node.get_dino_name(String(_map()["boss"])))
	assert_true(text.contains(boss_name), "The launch names who comes last: %s" % text)

# ==============================================================================
# 3. The charge, and the jump
# ==============================================================================

func test_09_full_charge_is_the_jump_and_the_run_is_won() -> void:
	var bench = _bench()
	await wait_frames(1)
	_launch(bench)
	game_state_node.is_paused = true    # the clock is this test's
	var total: float = float(_beacon()["charge_seconds"])
	var won = watch_signal(event_bus_node, "game_won")
	game_state_node.charge_beacon(total - 1.0)
	assert_false(game_state_node.is_game_won, "A second short is not the jump")
	assert_almost_eq(game_state_node.beacon_charge_ratio(), (total - 1.0) / total, 0.0001, "It is that far charged")
	game_state_node.charge_beacon(2.0)
	assert_true(game_state_node.is_game_won, "Full charge: he jumps, and the run is won")
	assert_eq(won.emit_count, 1, "Once")
	assert_almost_eq(float(game_state_node.beacon_charge), total, 0.0001, "The charge stops at full")
	game_state_node.charge_beacon(5.0)
	assert_eq(won.emit_count, 1, "And a finished run is not won again")

func test_10_it_charges_on_game_time_and_not_while_paused() -> void:
	var bench = _bench()
	await wait_frames(1)
	_launch(bench)
	game_state_node.is_paused = true
	var before: float = float(game_state_node.beacon_charge)
	await wait_frames(3)
	assert_almost_eq(float(game_state_node.beacon_charge), before, 0.0001, "Paused, it holds")
	game_state_node.is_paused = false
	await wait_frames(3)
	assert_gt(float(game_state_node.beacon_charge), before, "Running, it charges by itself")

func test_11_the_nest_cannot_be_destroyed_and_nothing_aims_at_it() -> void:
	var nest = _spawn(load("res://scripts/entities/Nest.gd").new())
	nest.global_position = Vector3(70.0, 0.0, 70.0)
	assert_false(nest.has_method("take_damage"), "It has no hit points to take")
	var tower = _spawn(load("res://scripts/entities/Tower.gd").new())
	tower.global_position = Vector3(72.0, 0.0, 70.0)
	var hero = _spawn(load("res://scripts/entities/Hero.gd").new())
	hero.global_position = Vector3(71.0, 0.0, 71.5)
	await wait_frames(2)
	assert_false(tower._is_target_valid(nest), "A tower in reach does not shoot at it")
	assert_null(hero._find_nearest_enemy(5.0), "And the Hero standing beside it does not swing at it")

# ==============================================================================
# 4. The final wave
# ==============================================================================

func test_12_launching_sets_out_one_wave_streamed_over_the_charge_with_the_boss_last() -> void:
	var main = await _level()
	var wm = main.wave_manager
	var bench = main.cabin_interior.station(String(config_node.BEACON_STATION))
	assert_not_null(bench, "The cabin has the beacon's bench")
	if bench == null:
		return
	var started = watch_signal(event_bus_node, "wave_started")
	_launch(bench)
	assert_true(wm.final_wave, "The final wave is under way")
	assert_eq(started.emit_count, 1, "As one wave")
	assert_eq(String(wm.wave_roster.back()), String(_map()["boss"]), "The map's boss last of all")
	var stream: float = float(_beacon()["charge_seconds"]) * float(_beacon()["stream_share"])
	assert_almost_eq(wm.spawn_timer.wait_time * float(wm.dinos_to_spawn), stream, stream * 0.01,
		"Stepping out one after another over the stream's share of the charge")

func test_13_they_come_out_of_the_nest_and_every_entry_in_turn() -> void:
	var main = await _level()
	var wm = main.wave_manager
	var entries: Array = _map()["entries"]
	var origins: Array[Vector3] = [wm.nest_spawn_position]
	for cell in entries:
		origins.append(main.grid_manager.cell_to_world(cell))
	wm.start_final_wave()
	wm.spawn_timer.stop()    # these are stepped out by hand, in order
	var cabin: Vector3 = wm.waypoints.back()
	for i in range(origins.size() + 1):
		var dino = wm._spawn_single_dino()
		assert_not_null(dino, "Raider %d stepped out" % i)
		if dino == null:
			return
		var at: Vector3 = origins[i % origins.size()]
		assert_lt(Vector2(dino.position.x - at.x, dino.position.z - at.z).length(), 1.0,
			"Raider %d came out of way %d" % [i, i % origins.size()])
		assert_eq(dino.waypoints.back(), cabin, "And is headed for the cabin")

func test_14_no_ordinary_raid_comes_while_it_lasts() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.auto_raid_enabled = true
	wm.start_final_wave()
	var wave: int = int(wm.current_wave)
	# Even if every one of them is killed before the jump.
	for i in range(int(wm.dinos_alive_count)):
		event_bus_node.dino_died.emit(null)
	assert_false(wm.is_wave_active, "The final wave was fought off")
	wm.raid_timer = 0.0
	await wait_frames(3)
	assert_eq(int(wm.current_wave), wave, "And no raid sets out after it: there is only the charge left")
	assert_true(wm.final_wave, "It is still the end of the run")

func test_15_putting_the_launch_off_makes_the_final_wave_bigger() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.start_final_wave()
	var early: int = int(wm.dinos_to_spawn)
	wm.reset_raid_state()
	wm.is_wave_active = false
	wm.elapsed_time = 20.0 * 60.0
	wm.start_final_wave()
	assert_gt(int(wm.dinos_to_spawn), early, "Twenty minutes on, the valley sends more")

func test_16_a_raid_under_way_is_folded_in() -> void:
	var main = await _level()
	var wm = main.wave_manager
	wm.start_wave(1, 3)
	wm.spawn_timer.stop()
	wm._spawn_single_dino()
	wm._spawn_single_dino()
	var out: int = int(wm.dinos_spawned_count)
	wm.start_final_wave()
	assert_eq(int(wm.dinos_alive_count), int(wm.dinos_to_spawn) + out,
		"Those already out count towards the final wave, and the one still in the nest is part of the stream")

# ==============================================================================
# 5. The ways in
# ==============================================================================

func test_17_every_entry_is_open_ground_with_a_way_to_the_cabin() -> void:
	var main = await _level()
	await wait_frames(6)
	var gm = main.grid_manager
	var maps = main.nav_maps
	assert_true(maps.is_ready(), "The level has its navigation")
	var field_half: float = float(config_node.TERRAIN["field_half"])
	var nodes: Array = []
	for node in _map()["default_resource_nodes"]:
		nodes.append(node["cell"])
	var cabin: Vector3 = main.current_core.global_position
	var entries: Array = _map()["entries"]
	assert_gte(entries.size(), 2, "The final wave has more than one other way in")
	for cell in entries:
		var at: Vector3 = gm.cell_to_world(cell)
		assert_lt(maxf(absf(at.x), absf(at.z)), field_half, "%s is on the field" % cell)
		assert_not_has(_map()["default_blocked_cells"], cell, "%s is not hillside" % cell)
		assert_not_has(nodes, cell, "%s is not under a tree or a rock" % cell)
		var ground: Vector3 = maps.closest_point(at, false)
		assert_lt(Vector2(ground.x - at.x, ground.z - at.z).length(), 0.5, "%s is ground a raider can stand on" % cell)
		assert_true(maps.is_reachable(at, cabin, false), "And from %s there is a way to the cabin" % cell)

# ==============================================================================
# 6. On screen
# ==============================================================================

func test_18_where_the_beacon_has_got_to_is_always_on_screen() -> void:
	var main = await _level()
	var hud = main.hud
	var label: Label = hud.beacon_label
	assert_not_null(label, "The HUD has the beacon's line")
	if label == null:
		return
	assert_true(label.visible, "From the first moment of the run")
	assert_eq(label.text, String(config_node.beacon_status(_map(), 0, 0.0)), "Saying none of it is repaired")
	var first: String = label.text
	game_state_node.finish_beacon_job(_jobs()[0])
	await wait_frames(1)
	assert_ne(label.text, first, "A stage repaired changes it")
	assert_eq(label.text, String(config_node.beacon_status(_map(), 1, 0.0)), "To one repaired")

	for i in range(_jobs().size() - 1):
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
	game_state_node.is_paused = true
	game_state_node.charge_beacon(float(_beacon()["charge_seconds"]) * 0.5)
	await wait_frames(1)
	assert_eq(label.text, String(config_node.beacon_status(_map(), int(game_state_node.beacon_steps), float(game_state_node.beacon_charge))),
		"Launched, it counts the charge down")
	assert_true(label.text.contains("50"), "Half charged: %s" % label.text)

func test_19_the_jump_is_the_victory_screen() -> void:
	var main = await _level()
	var hud = main.hud
	for i in range(_jobs().size()):
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
	game_state_node.charge_beacon(float(_beacon()["charge_seconds"]))
	await wait_frames(1)
	assert_true(hud.is_game_over_visible(), "The end of the run is on screen")
	assert_eq(hud.get_game_over_title(), tr("GAME_VICTORY_TITLE"), "And it is the jump")

# ==============================================================================
# 7. A new run
# ==============================================================================

func test_20_a_new_run_starts_with_the_beacon_broken() -> void:
	var main = await _level()
	for i in range(_jobs().size()):
		game_state_node.finish_beacon_job(String(game_state_node.beacon_next_job()))
	game_state_node.charge_beacon(10.0)
	assert_true(main.wave_manager.final_wave, "Mid-charge")
	main.restart_game()
	await wait_frames(2)
	assert_eq(int(game_state_node.beacon_steps), 0, "A new run: nothing repaired")
	assert_almost_eq(float(game_state_node.beacon_charge), 0.0, 0.0001, "Nothing charged")
	assert_false(main.wave_manager.final_wave, "And no final wave")
