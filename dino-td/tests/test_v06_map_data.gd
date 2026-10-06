# res://tests/test_v06_map_data.gd
# v0.6 T6: a map is data, and a run is one seed.
#
# GAME-DESIGN 12: custom maps and difficulty come after the campaign, but the structure has
# to be there from the start. A map is the CONTENT of a run -- where things stand, what the
# player starts with, who raids and when -- and it lives in Config.MAPS; the run's map is
# GameState.map_data(). Every chance in play is drawn from the run's own dice, so one seed
# replays one run: a seed can be shared, and a bug replayed.
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
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _waves() -> Node:
	var wm = load("res://scripts/core/WaveManager.gd").new()
	_cleanup_nodes.append(wm)
	tree.root.add_child(wm)
	return wm

func test_01_a_run_is_played_on_a_map_from_config() -> void:
	assert_eq(game_state_node.map_id, String(config_node.DEFAULT_MAP_ID), "A run starts on the default map")
	var run_map: Dictionary = game_state_node.map_data()
	assert_eq(run_map, config_node.map_data(), "And the run's map is that map's data")
	for key in ["name", "default_core_cell", "default_nest_cell", "default_blocked_cells",
			"default_resource_nodes", "opening_stock", "beats", "raiders"]:
		assert_has(run_map, key, "A map declares its %s" % key)
	assert_has(run_map["beats"], "first_raid", "And when its first raid comes")
	for res_id in run_map["opening_stock"]:
		assert_eq(config_node.get_opening_stock(String(res_id)), int(run_map["opening_stock"][res_id]),
			"The opening stock of %s is the map's" % res_id)

func test_02_the_first_raid_comes_when_the_map_says() -> void:
	var wm = _waves()
	await wait_frames(1)
	wm.reset_raid_state()
	assert_almost_eq(float(wm.raid_timer), float(game_state_node.map_data()["beats"]["first_raid"]), 0.0001,
		"The first raid is on the map's beat table")

func test_03_raiders_are_drawn_from_the_map_s_table() -> void:
	var wm = _waves()
	await wait_frames(1)
	var raiders: Dictionary = game_state_node.map_data()["raiders"]
	for i in range(40):
		var species: String = wm._species_to_spawn()
		assert_true(raiders.has(species) and float(raiders[species]) > 0.0,
			"%s is one of the map's raiders" % species)

func test_04_one_seed_replays_a_run() -> void:
	var wm = _waves()
	await wait_frames(1)
	var runs: Array = []
	for seed_value in [1234, 1234, 4321]:
		game_state_node.reset_game(seed_value)
		assert_eq(int(game_state_node.run_seed), seed_value, "The run keeps its seed")
		var draws: Array = []
		for i in range(6):
			wm._reset_raid_timer()
			draws.append(snappedf(float(wm.raid_timer), 0.0001))
			draws.append(wm._species_to_spawn())
		runs.append(draws)
	assert_eq(runs[0], runs[1], "The same seed, the same raids at the same times")
	assert_ne(runs[0], runs[2], "Another seed, another run")

func test_05_a_run_without_a_seed_gets_a_fresh_one() -> void:
	game_state_node.reset_game()
	var first: int = int(game_state_node.run_seed)
	game_state_node.reset_game()
	assert_ne(int(game_state_node.run_seed), first, "Two runs started without a seed are not the same run")

func test_06_nothing_in_play_rolls_the_engine_s_own_dice() -> void:
	# The rule that makes test_04 true everywhere rather than in one file: no script calls
	# the global randf / randi family. Play draws from GameState.rng; decoration keeps dice
	# of its own (Fx._dice, the ground cover's scatter).
	var bare := RegEx.new()
	bare.compile("(^|[^.\\w])(randf|randi|randf_range|randi_range|randfn|randomize)\\(")
	var offenders: Array = []
	var scanned: int = 0
	var stack: Array = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub in dir.get_directories():
			stack.append(dir_path.path_join(sub))
		for file_name in dir.get_files():
			if not file_name.ends_with(".gd"):
				continue
			scanned += 1
			var path: String = dir_path.path_join(file_name)
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for i in range(lines.size()):
				var code: String = lines[i].get_slice("#", 0)
				if bare.search(code) != null:
					offenders.append("%s:%d" % [path, i + 1])
	assert_gt(scanned, 20, "The whole of scripts/ was read")
	assert_eq(offenders, [], "No script rolls the global dice")
