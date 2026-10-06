# res://tests/test_v06_run_stats.gd
# v0.6 T8, T9: what a run has been, told back to the player.
#
# A raid ends with its account -- how many were killed, what they left, what went down --
# and a run ends with its own: how long, how many raids held and killed, and where the
# Hero's time went (GAME-DESIGN 4.6's target is gathering under four tenths of it).
# Everything expected is read from Config.
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
	if game_state_node != null:
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

func _keep(node: Node) -> Node:
	_cleanup_nodes.append(node)
	return node

func _stats() -> Node:
	var stats = _keep(RunStats.new())
	tree.root.add_child(stats)
	return stats

func _raptor() -> Node:
	var dino = _keep(load(String(config_node.get_dino_script_path("raptor"))).new())
	dino.setup("raptor")
	return dino

## A building as the bus reports it going down: its type, and what it had left.
func _building(type_id: String, hp_left: float) -> Node:
	var b = _keep(load("res://scripts/entities/Building.gd").new())
	b.building_type = type_id
	b.current_hp = hp_left
	return b

# ==============================================================================
# 1. A raid's account
# ==============================================================================

func test_01_a_raid_ends_with_its_account() -> void:
	var stats = _stats()
	var told = watch_signal(event_bus_node, "raid_summary")
	event_bus_node.wave_started.emit(4, false)
	event_bus_node.dino_died.emit(_raptor())
	event_bus_node.dino_died.emit(_raptor())
	event_bus_node.building_destroyed.emit(_building("wall", 0.0))
	event_bus_node.wave_ended.emit(4)
	assert_eq(told.emit_count, 1, "The raid's end is told")
	if told.emit_count != 1:
		return
	var summary: Dictionary = told.last_args[0]
	assert_eq(int(summary["wave"]), 4, "Which raid")
	assert_eq(int(summary["killed"]), 2, "How many were killed")
	var drops: Dictionary = config_node.DINOS["raptor"]["drops"]
	for res_id in drops:
		assert_eq(int(summary["drops"].get(res_id, 0)), 2 * int(drops[res_id]), "What they left: %s" % res_id)
	assert_eq(int(summary["lost"].get("wall", 0)), 1, "And what went down")
	assert_eq(int(stats.raids_held), 1, "One raid held")

func test_02_pulled_down_is_not_lost_and_guards_are_not_the_raid() -> void:
	var stats = _stats()
	var told = watch_signal(event_bus_node, "raid_summary")
	event_bus_node.wave_started.emit(1, false)
	event_bus_node.building_destroyed.emit(_building("wall", 5.0))   # demolished: hit points to spare
	var guard = _raptor()
	guard.add_to_group("guard_dinos")
	event_bus_node.dino_died.emit(guard)
	event_bus_node.wave_ended.emit(1)
	var summary: Dictionary = told.last_args[0] if told.emitted else {}
	assert_true(summary.get("lost", {"x": 1}).is_empty(), "A building he pulled down is not a loss")
	assert_eq(int(summary.get("killed", -1)), 0, "A guard of the nest is not one of the raid")

func test_03_the_hud_says_it_in_words() -> void:
	var hud = _keep(load("res://scenes/ui/HUD.tscn").instantiate())
	tree.root.add_child(hud)
	await wait_frames(1)
	var text: String = hud.raid_summary_text({"wave": 3, "killed": 5, "drops": {"bone": 5}, "lost": {"wall": 2}})
	assert_true(text.contains("5 %s" % tr("RESOURCE_BONE")), "What they left, by name: %s" % text)
	assert_true(text.contains("2 %s" % config_node.get_building_name("wall")), "What went down, by name: %s" % text)
	var quiet: String = hud.raid_summary_text({"wave": 1, "killed": 0, "drops": {}, "lost": {}})
	assert_true(quiet.contains(tr("HUD_NOTHING")), "And says so when there was nothing: %s" % quiet)

# ==============================================================================
# 2. Where his time went
# ==============================================================================

func test_04_his_time_is_counted_by_what_he_is_doing() -> void:
	var stats = _stats()
	var hero = _keep(load("res://scripts/entities/Hero.gd").new())
	tree.root.add_child(hero)
	hero.global_position = Vector3(90.0, 0.0, 90.0)
	hero.set_physics_process(false)
	hero.set_process(false)
	hero.current_state = Hero.State.HARVESTING
	await wait_frames(3)
	assert_gt(float(stats.seconds_by_activity["gather"]), 0.0, "Harvesting counts as gathering")
	event_bus_node.cabin_view_changed.emit(true)
	var cabin_before: float = float(stats.seconds_by_activity["cabin"])
	await wait_frames(3)
	assert_gt(float(stats.seconds_by_activity["cabin"]), cabin_before, "Inside, it is time in the cabin")
	game_state_node.is_paused = true
	var total: float = float(stats.run_seconds)
	await wait_frames(3)
	assert_almost_eq(float(stats.run_seconds), total, 0.0001, "Paused, no time passes")
	var sum: float = 0.0
	for share in stats.time_shares().values():
		sum += float(share)
	assert_almost_eq(sum, 1.0, 0.0001, "And the shares add up to all of it")

# ==============================================================================
# 3. The run's account
# ==============================================================================

func test_05_the_result_screen_carries_the_run() -> void:
	var main = _keep(load("res://scenes/Main.tscn").instantiate())
	tree.root.add_child(main)
	await wait_frames(6)
	assert_not_null(main.run_stats, "The level keeps the run's account")
	main.run_stats.raids_held = 3
	main.run_stats.killed = 7
	win_the_run()
	# Under the verdict, the account as three figures: how long, raids held, killed.
	var secs: int = int(main.run_stats.run_seconds)
	var row: Node = main.hud.stats_row
	assert_true(row != null and row.visible, "The results card carries the run's account")
	if row == null:
		return
	assert_eq((row.get_node("StatTime/Value") as Label).text, "%d:%02d" % [secs / 60, secs % 60], "How long it lasted")
	assert_eq((row.get_node("StatRaids/Value") as Label).text, "3", "How many raids were held")
	assert_eq((row.get_node("StatKilled/Value") as Label).text, "7", "How many were killed")

func test_06_a_new_run_starts_a_new_account() -> void:
	var main = _keep(load("res://scenes/Main.tscn").instantiate())
	tree.root.add_child(main)
	await wait_frames(6)
	main.run_stats.killed = 5
	main.run_stats.raids_held = 2
	main.restart_game()
	await wait_frames(1)
	assert_eq(int(main.run_stats.killed), 0, "Nobody killed yet")
	assert_eq(int(main.run_stats.raids_held), 0, "No raid held yet")
