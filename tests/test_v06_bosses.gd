# res://tests/test_v06_bosses.gd
# v0.6 T10: bosses -- an alpha at the head of every big wave, the map's boss last of all in the
# beacon's final wave (and in no raid before it: v0.6 round three, "中段的小boss不应该把最后的大boss
# 形象暴露"), both announced, and both paying in prime meat.
#
# GAME-DESIGN 7.5: every map has a boss, and a lesser one comes with the big waves the game
# already had (WAVES.big_every) rather than on a rhythm of its own. A boss is the only thing
# that leaves prime meat, and prime meat is the best meal there is (test_v06_kitchen) -- so
# killing one is worth the risk. Everything here is read from Config and the run's map.
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
	super.after_each()

func _map() -> Dictionary:
	return game_state_node.map_data()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

func _row(species: String) -> Dictionary:
	return config_node.DINOS[species]

## The animal the map raids with: the pack its alpha leads.
func _pack() -> String:
	return String(_map()["raiders"].keys()[0])

## The first wave number that is a big one.
func _big_wave(wm: Node) -> int:
	for n in range(1, 50):
		if wm.is_big_wave(n):
			return n
	return -1

# ==============================================================================
# 1. Who they are
# ==============================================================================

func test_00_the_first_map_is_the_late_triassic() -> void:
	# "第一关还应该是三叠纪" (GAME-DESIGN 7.2, station 1): Coelophysis raid, their alpha leads the
	# big waves, and the boss is Postosuchus -- not a dinosaur, and not a tyrannosaur.
	assert_eq(_pack(), "coelophysis", "Coelophysis raid the valley")
	assert_eq(String(_map()["minor_boss"]), "coelophysis_alpha", "their alpha leads the big waves")
	assert_eq(String(_map()["boss"]), "postosuchus", "and the boss is Postosuchus")
	assert_eq(String(_map().get("guards", "")), "coelophysis", "Coelophysis guard the nest")
	for species in [_pack(), String(_map()["minor_boss"]), String(_map()["boss"])]:
		assert_true(VisualLibrary.has_art("dino/" + species), "%s is a model of its own" % species)
		assert_ne(tr(String(_row(species)["name"])), String(_row(species)["name"]), "%s is named" % species)

func test_01_the_alpha_is_a_bigger_harder_one_of_its_pack() -> void:
	var alpha_id: String = String(_map()["minor_boss"])
	var alpha: Dictionary = _row(alpha_id)
	var raptor: Dictionary = _row(_pack())
	assert_eq(String(alpha["behaviour"]), String(raptor["behaviour"]), "It hunts the way the pack does")
	assert_almost_eq(alpha["size"].x, raptor["size"].x, 0.0001, "As wide: it has to fit the same gaps")
	assert_gt(alpha["size"].y, raptor["size"].y, "But it stands taller")
	assert_gte(float(alpha["hp"]), float(raptor["hp"]) * 3.0, "And takes a good deal more killing")
	assert_eq(String(alpha.get("boss", "")), "minor", "It is the lesser boss")

func test_02_the_map_s_elites_leave_hide_and_only_they_do() -> void:
	# v0.6 round three: "精英就掉落皮可以做护甲和鞋子就行了" -- an elite's hide, not a prime cut: what
	# his armour and boots are made of (RECIPES).
	var boss_id: String = String(_map()["boss"])
	assert_eq(String(_row(boss_id).get("boss", "")), "major", "The map's boss is the major one")
	for species in [String(_map()["minor_boss"]), boss_id]:
		var drops: Dictionary = _row(species).get("drops", {})
		assert_gt(int(drops.get("hide", 0)), 0, "%s is an elite, and pays in hide" % species)
		assert_gt(int(drops.get("bone", 0)), 0, "%s leaves bone too" % species)
		assert_eq(int(drops.get("prime_meat", 0)), 0, "and no prime cut")
	for species in _map()["raiders"].keys() + [String(_map()["guards"])]:
		assert_eq(int(_row(String(species)).get("drops", {}).get("hide", 0)), 0, "%s is not an elite, and leaves none" % species)

# ==============================================================================
# 2. When they come
# ==============================================================================

func test_03_every_big_wave_is_led_by_the_alpha() -> void:
	var main = _level()
	await wait_frames(2)
	var wm = main.wave_manager
	var big: int = _big_wave(wm)
	assert_gt(big, 0, "There are big waves")
	var alpha_id: String = String(_map()["minor_boss"])
	var roster: Array = wm.roster_for(big, 4)
	assert_eq(String(roster[0]), alpha_id, "A big wave has the alpha at its head")
	assert_eq(roster.size(), 5, "On top of the wave's own")
	assert_false(wm.roster_for(big - 1, 4).has(alpha_id), "An ordinary wave has none")

func test_04_the_boss_comes_in_no_raid_only_last_in_the_final_wave() -> void:
	var main = _level()
	await wait_frames(2)
	var wm = main.wave_manager
	var boss_id: String = String(_map()["boss"])
	# Raid after raid, well into the run: never the boss.
	wm.auto_raid_enabled = false
	for i in range(8):
		wm.elapsed_time = 120.0 * float(i + 1)
		wm.start_next_raid()
		assert_false(wm.wave_roster.has(boss_id), "Raid %d at %.0fs brings no boss" % [i + 1, wm.elapsed_time])
		wm.is_wave_active = false
		game_state_node.wave_number += 1
	wm.start_final_wave()
	assert_eq(String(wm.wave_roster.back()), boss_id, "The final wave brings it, last of all")

func test_05_the_warning_names_the_alpha() -> void:
	var main = _level()
	await wait_frames(2)
	var wm = main.wave_manager
	var boss_id: String = String(_map()["minor_boss"])
	var watcher = watch_signal(event_bus_node, "boss_warning")
	game_state_node.wave_number = _big_wave(wm) - 1
	wm.auto_raid_enabled = true
	wm.raid_timer = wm.warning_lead_time - 0.01
	wm.warning_emitted = false
	await wait_frames(2)
	assert_true(watcher.emitted, "The warning says a boss is coming")
	var named: bool = false
	for args in watcher.emission_args:
		if not args.is_empty() and String(args[0]) == boss_id:
			named = true
	assert_true(named, "And which one")
	var hud = main.hud
	if hud and hud.raid_warning_banner:
		assert_true(hud.raid_warning_banner.text.contains(String(config_node.get_dino_name(boss_id))),
			"On the banner, by name: %s" % hud.raid_warning_banner.text)

func test_06_a_raider_is_the_species_it_was_drawn_as() -> void:
	# It was always set up as a raptor, whatever came out of the nest.
	var main = _level()
	await wait_frames(2)
	var wm = main.wave_manager
	var boss_id: String = String(_map()["boss"])
	var watcher = watch_signal(event_bus_node, "boss_arrived")
	var roster: Array[String] = [boss_id]
	wm.wave_roster = roster
	var dino = wm._spawn_single_dino()
	assert_not_null(dino, "It stepped out")
	if dino == null:
		return
	_cleanup_nodes.append(dino)
	assert_eq(String(dino.dino_type), boss_id, "As the species it was drawn as")
	var mult: float = float(game_state_node.dino_stat_multipliers.get("hp", 1.0))
	assert_almost_eq(float(dino.max_hp), float(_row(boss_id)["hp"]) * mult, 0.01, "With that species' hit points")
	assert_true(watcher.emitted, "And a boss stepping out is announced")

# ==============================================================================
# 3. What they leave
# ==============================================================================

func test_07_a_dead_alpha_leaves_its_hide_on_the_ground() -> void:
	var alpha_id: String = String(_map()["minor_boss"])
	var dino = load(String(config_node.get_dino_script_path(alpha_id))).new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup(alpha_id)
	dino.set_physics_process(false)
	await wait_frames(1)
	dino.spawn_death_drops()
	await wait_frames(1)
	assert_eq(ground_total("hide"), int(_row(alpha_id)["drops"]["hide"]),
		"What his armour is made of, where it fell")
