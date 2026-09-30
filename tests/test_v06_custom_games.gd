# res://tests/test_v06_custom_games.gd
# The player, 2026-09-30: "v0.6还有自定义地图机制没做呢，这个功能很重要，我的想法是，把自定义地图需要的参数列出来，玩家就能选
# 这些参数自定义游戏（自定义的cabin是完整的）。正式通关版的游戏是我们自定义的游戏，只不过加了一些玩家不能调的内部参数，比如
# 有没有tutorial（教学机制），cabin的版本，信标机制" -- and "自定义地图有还有难度调整（难度高的恐龙巢穴多，波次厉害），恐龙纪元
# 等". Chosen: a custom game is won by holding out so many days; its cabin whole, the beacon mended and calling; the
# game opens on a start screen.
#
# Every run is a game (Config.GAMES): its settings (Config.CUSTOM_GAME -- ours keeps its own) and what only ours sets
# (tutorial, cabin, goal). GameState works the run out of them: its map with the settings' keys over it, the
# multipliers the systems read, the switches.
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
	_no_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	_no_game()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

## A level a script builds plays no game of its own (and GameState is kept between tests).
func _no_game() -> void:
	if game_state_node != null:
		game_state_node.game = {}
		game_state_node.chosen_map_id = ""
		game_state_node.launch_straight_in = false
		game_state_node.set_paused(false)
		game_state_node.reset_game()

func _play(game_id: String, chosen: Dictionary = {}, seed_value: int = -1) -> void:
	game_state_node.play(game_id, chosen, seed_value)
	game_state_node.reset_game()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func _choice(setting_id: String, choice_id: String) -> Dictionary:
	return config_node.custom_choice(setting_id, choice_id)

func _map_id(size: String) -> String:
	return String(_choice("map", size)["map_id"])

func test_01_every_setting_offers_its_choices_named() -> void:
	var settings: Array = config_node.CUSTOM_GAME["settings"]
	assert_gt(settings.size(), 8, "The custom game has its settings (%d)" % settings.size())
	for want in ["era", "difficulty", "map", "days"]:
		assert_false(config_node.custom_setting(want).is_empty(), "Among them %s" % want)
	for s in settings:
		var ids: Array = []
		for c in s["choices"]:
			ids.append(String(c["id"]))
			assert_ne(tr(String(c["name"])), String(c["name"]), "%s / %s is named" % [s["id"], c["id"]])
			if c.has("note"):
				assert_ne(tr(String(c["note"])), String(c["note"]), "and says what it does")
		assert_gte(ids.size(), 2, "%s is a choice" % s["id"])
		assert_true(ids.has(String(s["default"])), "%s's default is one of its choices" % s["id"])
		assert_ne(tr(String(s["name"])), String(s["name"]), "%s is named" % s["id"])
	# The eras are the ages the cast was built for; the difficulties grow in nests.
	var nests: Array = []
	for c in config_node.custom_setting("difficulty")["choices"]:
		nests.append(int(c.get("map", {}).get("nests", 1)))
	for i in range(1, nests.size()):
		assert_gte(nests[i], nests[i - 1], "A harder game has as many nests or more (%s)" % str(nests))
	assert_gt(nests.back(), nests.front(), "and the hardest more than the easiest")

func test_02_our_game_is_the_settings_defaults_on_the_large_valley() -> void:
	_play("campaign")
	var own: Dictionary = config_node.GAMES["campaign"].get("settings", {})
	for s in config_node.CUSTOM_GAME["settings"]:
		var id: String = String(s["id"])
		assert_eq(String(game_state_node.settings[id]), String(own.get(id, s["default"])), "Ours plays %s as it keeps it" % id)
	assert_eq(String(game_state_node.map_id), _map_id(String(own["map"])), "on the large valley")
	assert_true(bool(game_state_node.internal("tutorial")), "It teaches")
	assert_eq(String(game_state_node.internal("cabin")), "wrecked", "its cabin wrecked")
	assert_eq(String(game_state_node.goal_kind()), "beacon", "and it is won by the beacon")
	assert_eq(int(game_state_node.beacon_steps), 0, "The beacon to mend from nothing")
	assert_false(game_state_node.is_beacon_launched(), "(not launched)")
	assert_true(Array(config_node.beacon_jobs(game_state_node.map_data())).has(String(config_node.BEACON_LAUNCH)),
		"and launched at the end")
	# A player's choices do not change ours.
	_play("campaign", {"difficulty": "nightmare", "map": "small"})
	assert_eq(String(game_state_node.settings["difficulty"]), String(config_node.custom_setting("difficulty")["default"]),
		"Ours keeps its own difficulty whatever is asked")
	assert_eq(String(game_state_node.map_id), _map_id(String(own["map"])), "and its own map")

func test_03_a_script_built_level_plays_ours_on_the_small_valley() -> void:
	assert_eq(String(game_state_node.game_id()), "", "No game chosen")
	assert_eq(String(game_state_node.map_id), String(config_node.DEFAULT_MAP_ID), "The small valley")
	assert_eq(String(game_state_node.goal_kind()), "beacon", "Won by the beacon, as ours is")
	assert_true(is_same(game_state_node.map_data(), config_node.map_data(config_node.DEFAULT_MAP_ID)),
		"The map itself: no setting of ours changes it")

func test_04_a_custom_game_lays_its_settings_over_its_map() -> void:
	_play("custom", {"map": "small", "difficulty": "hard", "stock": "much"})
	var map: Dictionary = game_state_node.map_data()
	assert_eq(String(game_state_node.map_id), _map_id("small"), "Played on the map chosen")
	assert_true(map.is_read_only(), "Its map cannot change under the run")
	var hard: Dictionary = _choice("difficulty", "hard")
	assert_eq(int(map["nests"]), int(hard["map"]["nests"]), "The nests the difficulty opens")
	assert_eq(int(map["raid_most"]), int(hard["map"]["raid_most"]), "the raids the valley holds")
	assert_almost_eq(float(map["beats"]["first_raid"]), float(hard["map"]["beats"]["first_raid"]), 0.001, "the first raid's beat")
	for key in config_node.map_data(_map_id("small"))["beats"]:
		assert_true(map["beats"].has(key), "and the map's other beats kept (%s)" % key)
	assert_eq(map["opening_stock"], _choice("stock", "much")["map"]["opening_stock"], "What lies by the cabin")
	for key in hard["scale"]:
		assert_almost_eq(float(game_state_node.run_scale(key)), float(hard["scale"][key]), 0.001, "Its %s" % key)
	assert_almost_eq(float(game_state_node.dino_stat_multipliers["hp"]),
		float(config_node.INITIAL_DINO_MULTIPLIERS.get("hp", 1.0)) * float(hard["scale"]["dino_hp"]), 0.001,
		"The raiders start as tough as it says")
	assert_false(bool(game_state_node.internal("tutorial")), "A custom game does not teach")

func test_05_the_custom_cabin_is_whole_and_its_beacon_calls() -> void:
	_play("custom", {"map": "small", "days": "3"})
	assert_eq(String(game_state_node.internal("cabin")), "whole", "The cabin whole")
	assert_eq(int(game_state_node.beacon_stages_done()), int(game_state_node.beacon_stage_count()), "Every stage mended")
	assert_gt(int(game_state_node.beacon_stage_count()), 0, "(the beacon's own stages)")
	assert_false(game_state_node.is_beacon_launched(), "Nothing to launch")
	assert_eq(String(game_state_node.beacon_next_job()), "", "and no step left at its bench")
	assert_eq(int(game_state_node.rescue_days()), int(_choice("days", "3")["days"]), "The days the rescue takes")
	assert_eq(String(game_state_node.objective_status()), tr("RESCUE_STATUS") % int(game_state_node.rescue_days()),
		"The goal's card says them")
	var main = await _level()
	for n in tree.get_nodes_in_group("resource_nodes"):
		assert_false(bool(config_node.RESOURCE_NODES.get(String(n.resource_type), {}).get("smoke", false)),
			"No wreck lies about: the beacon wants no part (%s)" % String(n.resource_type))
	assert_eq(String(main.hud.find_child("ObjectiveTitle", true, false).text), tr("HUD_OBJECTIVE_RESCUE"), "Its card is the rescue's")

func test_06_held_out_the_rescue_comes() -> void:
	_play("custom", {"map": "small", "days": "3"})
	var length: float = float(config_node.DAY["length"])
	var days: int = int(game_state_node.rescue_days())
	var won = watch_signal(tree.root.get_node("EventBus"), "game_won")
	game_state_node.day_clock = float(days) * length - 5.0
	game_state_node._run_the_day(1.0)
	assert_eq(won.emit_count, 0, "Not on the last day")
	assert_eq(int(game_state_node.rescue_days_left()), 1, "(the last of them)")
	assert_eq(String(game_state_node.objective_status()), tr("RESCUE_STATUS_LAST"), "which it says")
	game_state_node._run_the_day(10.0)
	assert_eq(won.emit_count, 1, "With the first light after it, the rescue")
	assert_true(bool(game_state_node.is_game_won), "and the run won")

func test_07_the_last_day_brings_the_boss() -> void:
	_play("custom", {"map": "small", "days": "3"})
	var main = await _level()
	var waves = main.wave_manager
	var boss: String = String(game_state_node.map_data()["boss"])
	assert_false(waves._finale_due(), "Not before the last day")
	game_state_node.day_clock = float(int(game_state_node.rescue_days()) - 1) * float(config_node.DAY["length"]) + 30.0
	assert_true(waves._finale_due(), "On the last day, the boss comes")
	assert_true(waves.upcoming_bosses().has(boss), "and the warning names it")
	waves.start_next_raid()
	assert_true(Array(waves.wave_roster).has(boss), "with the raid, last of it")
	assert_false(waves._finale_due(), "once")

func test_08_a_harder_game_has_more_nests_each_with_its_guards() -> void:
	_play("custom", {"map": "small", "difficulty": "nightmare"})
	var main = await _level()
	var want: int = int(_choice("difficulty", "nightmare")["map"]["nests"])
	var nests: Array = tree.get_nodes_in_group("nest")
	assert_eq(nests.size(), want, "As many nests as it opens")
	var guards_each: int = int(config_node.NEST_GUARDS["count"])
	assert_eq(tree.get_nodes_in_group("guard_dinos").size(), guards_each * want, "each with its guards")
	var mouths: Array = main.wave_manager.nests()
	assert_eq(mouths.size(), want, "Every nest a party of each raid")
	for nest in nests:
		assert_true(main.nav_maps.is_reachable((nest as Node3D).global_position, main.current_core.global_position, NavMaps.For.RAID),
			"and a way from it to the cabin")
	var seen: Dictionary = {}
	for i in range(want * 2):
		var next: Array = main.wave_manager._next_origin()
		seen[next[0]] = true
	for mouth in mouths:
		assert_true(seen.has(mouth), "Raiders step out of each in turn")

func test_09_the_ages_bring_their_own_animals() -> void:
	_play("custom", {"map": "small", "era": "late_cretaceous"})
	var era: Dictionary = _choice("era", "late_cretaceous")["map"]
	var map: Dictionary = game_state_node.map_data()
	for key in era:
		assert_eq(map[key], era[key], "The age's %s" % key)
	var main = await _level()
	for g in tree.get_nodes_in_group("guard_dinos"):
		assert_eq(String(g.dino_type), String(era["guards"]), "Its guards at the nest")
	var herds: Node = main.get_node_or_null("Herds")
	assert_true(herds == null or herds.get_child_count() == era["herds"].size(), "and its grazers, or none")
	for species in [era["guards"], era["minor_boss"], era["boss"]] + Array(era["raiders"].keys()):
		assert_true(config_node.DINOS.has(String(species)), "%s is an animal of the game" % species)
		assert_true(String(config_node.VISUALS.get("dino/" + String(species), {}).get("scene", "")).begins_with("res://assets/models/dinos/"),
			"drawn from the new cast (%s)" % species)

func test_10_resources_the_cabin_and_the_days() -> void:
	_play("custom", {"map": "small", "resources": "plenty", "cabin_hp": "sturdy", "day_length": "long", "fog": "off"})
	var main = await _level()
	var tree_node: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood":
			tree_node = n
	assert_not_null(tree_node, "(a tree)")
	if tree_node:
		var cap: int = int(config_node.RESOURCE_NODES["wood"]["capacity"])
		assert_eq(int(tree_node.max_capacity), int(round(float(cap) * float(_choice("resources", "plenty")["scale"]["resource_amount"]))),
			"A tree holds as much more as it says")
	assert_almost_eq(float(main.current_core.max_hp),
		float(config_node.BUILDINGS["core"]["hp"]) * float(_choice("cabin_hp", "sturdy")["scale"]["cabin_hp"]), 0.01,
		"The cabin as sturdy")
	var before: float = float(game_state_node.day_clock)
	game_state_node._run_the_day(3.0)
	assert_almost_eq(float(game_state_node.day_clock) - before, 3.0 / float(_choice("day_length", "long")["scale"]["day_length"]), 0.001,
		"A longer day: the clock that much slower")
	assert_true(bool(main.fog.revealed), "No fog: the valley seen from the start")

func test_11_no_night() -> void:
	_play("custom", {"map": "small", "night": "off"})
	var parts: Dictionary = config_node.DAY["parts"]
	var length: float = float(config_node.DAY["length"])
	game_state_node.day_clock = float(parts["dusk"]) - 0.5
	var day: int = int(game_state_node.day_number())
	game_state_node._run_the_day(1.0)
	assert_eq(String(game_state_node.day_part()), "day", "Dusk is the next morning")
	assert_eq(int(game_state_node.day_number()), day + 1, "the next day's")
	assert_almost_eq(float(game_state_node.time_of_day()), float(config_node.DAY.get("start", 0.0)), 0.001, "at its first light")
	assert_lt(float(game_state_node.day_clock), float(day + 1) * length, "(the clock where that is)")

func test_12_a_custom_game_does_not_teach() -> void:
	_play("custom", {"map": "small"})
	var main = await _level()
	assert_false(main.fog._teaches(), "The fog's line is not said")
	assert_false(main.hud._teaches(), "nor the first dusk's")
	_no_game()
	_play("campaign")
	assert_true(main.fog._teaches(), "Ours teaches")

func test_13_a_seed_replays_the_run() -> void:
	_play("custom", {"map": "small"}, 4242)
	assert_eq(int(game_state_node.run_seed), 4242, "The seed given")
	var first: Array = [game_state_node.rng.randf(), game_state_node.rng.randf()]
	game_state_node.reset_game()
	assert_eq([game_state_node.rng.randf(), game_state_node.rng.randf()], first, "The same dice again")
	_play("custom", {"map": "small"}, -1)
	var a: int = int(game_state_node.run_seed)
	game_state_node.reset_game()
	assert_ne(int(game_state_node.run_seed), a, "None given: a new one each run")

func test_14_the_start_screen() -> void:
	var main = await _level()
	main.hud.show_start_screen(true)
	await wait_frames(1)
	var screen = main.hud.start_screen
	assert_true(screen.visible, "Shown over the valley")
	assert_true(bool(game_state_node.is_paused), "the valley stopped behind it")
	for b in [screen.campaign_btn, screen.custom_btn, screen.settings_btn, screen.quit_btn]:
		assert_true(b.is_visible_in_tree(), "%s on its title page" % b.name)
	assert_eq(screen.campaign_btn.text, tr("START_CAMPAIGN"), "Ours first")
	screen.show_custom()
	await wait_frames(1)
	for s in config_node.CUSTOM_GAME["settings"]:
		var picker: OptionButton = screen.pickers.get(String(s["id"]))
		assert_not_null(picker, "A row for %s" % s["id"])
		if picker == null:
			continue
		assert_true(picker.is_visible_in_tree(), "on the custom game's page")
		assert_eq(picker.item_count, (s["choices"] as Array).size(), "its choices")
	assert_false(screen.campaign_btn.is_visible_in_tree(), "(the title page's gone)")
	assert_true(screen.seed_edit.is_visible_in_tree(), "and the seed")
	screen.seed_edit.text = ""
	assert_eq(int(screen.seed_value()), -1, "none given: a new one each run")
	screen.seed_edit.text = "77"
	assert_eq(int(screen.seed_value()), 77, "or the one given")
	var picks: Dictionary = screen.current_choices()
	assert_eq(picks.size(), config_node.CUSTOM_GAME["settings"].size(), "Every setting's choice read off it")
	screen.show_title()
	# Ours, on the level the launch built for it: let go, no new level.
	game_state_node.play("campaign")
	screen.play_campaign()
	assert_false(screen.visible, "Playing ours closes it")
	assert_false(bool(game_state_node.is_paused), "and lets the valley go")

func test_15_new_game_from_the_pause_menu() -> void:
	var main = await _level()
	main.hud.toggle_pause_menu()
	await wait_frames(1)
	var menu = main.hud.pause_menu
	assert_true(menu.new_game_btn.is_visible_in_tree(), "The menu offers a new game")
	assert_eq(menu.new_game_btn.text, tr("MENU_NEW_GAME"), "(named)")
	menu.new_game_btn.pressed.emit()
	await wait_frames(1)
	assert_false(menu.is_open, "It closes")
	assert_true(main.hud.start_screen != null and main.hud.start_screen.visible, "onto the start screen")
	assert_true(bool(game_state_node.is_paused), "the run held under it")
	menu.open_settings()
	assert_null(menu.find_child("MapPicker", true, false), "The map is the custom game's to choose now, not the settings'")
	menu.close()
