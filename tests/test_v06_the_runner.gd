# res://tests/test_v06_the_runner.gd
# The player, v0.6 round six: "恐龙每次都是从一个地方来进攻，物种到day 4也就一种，太单调" -- chosen "快跑的黄昏鳄"
# and "更多来袭方向" (GAME-DESIGN 7.2 station one). From the third day the raids have Hesperosuchus in them -- a
# runner, quick and brittle, for the man and past the traps -- and come in by the east as well as from the
# nest; from the fifth, by the south too. The warning says every side.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game(7)

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func _to_day(day: int) -> void:
	game_state_node.day_clock = float(config_node.DAY["length"]) * float(day - 1) + float(config_node.DAY["start"])
	game_state_node._run_the_day(0.0)

func _step(from_day: int) -> Dictionary:
	for s in game_state_node.map_data().get("raiders_by_day", []):
		if int(s["from_day"]) == from_day:
			return s
	return {}

func test_01_from_the_third_day_the_raids_have_runners_in_them() -> void:
	var main = await _level()
	var waves = main.wave_manager
	var runner: String = "hesperosuchus"
	var from_day: int = int(_step(3).get("from_day", 0))
	assert_gt(from_day, 0, "(the map says from which day)")
	_to_day(from_day - 1)
	var seen: Dictionary = {}
	for i in 60:
		seen[waves._species_to_spawn()] = true
	assert_false(seen.has(runner), "Before it, only the pack")
	_to_day(from_day)
	seen.clear()
	for i in 60:
		seen[waves._species_to_spawn()] = true
	assert_true(seen.has(runner), "From then, runners among them")
	var row: Dictionary = config_node.DINOS[runner]
	var pack: Dictionary = config_node.DINOS["coelophysis"]
	assert_gt(float(row["speed"]), float(pack["speed"]) * 1.3, "A runner is much the quicker")
	assert_lt(float(row["hp"]), float(pack["hp"]), "and the more brittle")
	assert_eq(Array(row.get("hours", [])), Array(pack.get("hours", [])), "and keeps its raid's hours")

func test_02_a_runner_goes_for_the_man_and_past_the_traps() -> void:
	var main = await _level()
	var d = load(String(config_node.get_dino_script_path("hesperosuchus"))).new("hesperosuchus")
	_cleanup_nodes.append(d)
	main.dinos_container.add_child(d)
	d.setup("hesperosuchus")
	d.global_position = main.hero.global_position + Vector3(float(config_node.DINO_AI["runner_hunts_within"]) * 0.8, 0.0, 0.0)
	await wait_physics_frames(2)
	assert_eq(d._preferred_target(), main.hero, "Within its reach of him, it is him it wants")
	assert_eq(d.trap_interest_range(), 0.0, "and no trap turns it aside")

func test_03_from_the_third_day_a_raid_comes_in_by_the_east_as_well() -> void:
	var main = await _level()
	var waves = main.wave_manager
	_to_day(1)
	assert_true(waves.ways_now().is_empty(), "At first, only from the nest")
	_to_day(3)
	assert_eq(waves.ways_now(), ["E"] as Array[String], "From the third day, the east as well")
	_to_day(5)
	assert_eq(waves.ways_now(), ["E", "S"] as Array[String], "From the fifth, the south too")
	_to_day(3)
	var east: Vector3 = waves.entry_toward("E")
	assert_gt(east.x - main.current_core.global_position.x, 0.0, "(the way in on the east)")
	waves.start_wave(1, 6)
	var origins: Array = []
	for i in 4:
		origins.append(waves._next_origin())
	var from_east: int = 0
	for o in origins:
		if not o.is_empty() and (o[0] as Vector3).distance_to(east) < 0.1:
			from_east += 1
	assert_gt(from_east, 0, "A raid is shared out: some of it comes in by the east")
	assert_lt(from_east, origins.size(), "and some from the nest")

func test_04_the_warning_names_every_side() -> void:
	var main = await _level()
	_to_day(3)
	var hud = main.hud
	hud._on_raid_warning(20.0)
	await wait_frames(1)
	assert_true(String(hud.raid_warning_banner.text).contains(tr("DIR_E")), "The warning says the east too: %s" % hud.raid_warning_banner.text)

func test_05_a_way_he_watches_is_not_said() -> void:
	# The debug-agent's TASK-028: a way into the valley he is watching gives its turn to the nest's, and none
	# comes in by it -- yet the banner said a party would.
	var main = await _level()
	_to_day(3)
	# Him at the east way in, seeing it.
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.wave_manager.entry_toward("E")
	await wait_seconds(float(config_node.FOG["every"]) * 3.0 + 0.1)
	assert_false(main.wave_manager.way_open("E"), "(he is watching the east)")
	var hud = main.hud
	hud._on_raid_warning(20.0)
	await wait_frames(1)
	assert_false(String(hud.raid_warning_banner.text).contains(tr("HUD_RAID_ALSO") % tr("DIR_E")),
		"Watched, the east is not said: %s" % hud.raid_warning_banner.text)
