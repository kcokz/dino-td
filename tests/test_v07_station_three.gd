# res://tests/test_v07_station_three.gd
# The player, 2026-10-05: "把后面几关都先做起来，主要是科技树升级部分".
#
# STATION 3 (GAME-DESIGN 7.2: 早白垩世 · 热河生物群): our game goes on from the Morrison to the Jehol lake country of
# Liaoning -- he lands with every tool he has made (the bone shovel too), the stock and the base left behind; its cast
# is its own, feathered (Dilong, Sinornithosaurus, Sinocalliopteryx, Yutyrannus), each heard in a voice of its own; its
# lake's edge has clay and bog iron for the shovel; the custom game can play its age and its map; and the day's turns
# are told in its animals.
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
		game_state_node.reset_game()

func after_each() -> void:
	if game_state_node != null:
		if "is_paused" in game_state_node:
			game_state_node.is_paused = false
		game_state_node.game = {}
		game_state_node.station = 0
		game_state_node.arrived_by_jump = false
		game_state_node.launch_straight_in = false
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

func _stations() -> Array:
	return config_node.GAMES["campaign"].get("stations", [])

func _jehol() -> Dictionary:
	return config_node.map_data("jehol")

## Every species the map puts on the field: its raiders, day by day, its guards and its two bosses.
func _cast(map: Dictionary) -> Array:
	var cast: Array = []
	for species in map["raiders"]:
		cast.append(String(species))
	for step in map.get("raiders_by_day", []):
		for species in step["raiders"]:
			if not cast.has(String(species)):
				cast.append(String(species))
	for key in ["guards", "minor_boss", "boss"]:
		if not cast.has(String(map[key])):
			cast.append(String(map[key]))
	return cast

func test_01_our_game_goes_on_to_a_third_station() -> void:
	var stations: Array = _stations()
	assert_gte(stations.size(), 3, "our game has a third station")
	var three: Dictionary = stations[2]
	assert_eq(String(three["id"]), "jehol", "the Jehol")
	for key in ["name", "age", "place", "when"]:
		assert_ne(tr(String(three[key])), String(three[key]), "its %s is worded (%s)" % [key, three[key]])
	var map_choice: Dictionary = config_node.custom_choice("map", String(three["settings"]["map"]))
	assert_eq(String(map_choice.get("map_id", "")), "jehol", "played on the Jehol map")
	game_state_node.play("campaign")
	game_state_node.reset_game()
	assert_true(game_state_node.jump_to_next_station(), "station 1 to 2")
	game_state_node.reset_game()
	assert_true(game_state_node.has_next_station(), "the second has a station after it")
	assert_true(game_state_node.jump_to_next_station(), "and its jump goes on")
	assert_eq(int(game_state_node.station), 2, "to the third")
	game_state_node.reset_game()
	assert_eq(String(game_state_node.map_id), "jehol", "whose run is on its map")
	assert_eq(String(game_state_node.map_data()["boss"]), String(_jehol()["boss"]), "with its cast")

func test_02_he_lands_with_every_tool_he_has_made_and_without_the_base() -> void:
	game_state_node.play("campaign")
	game_state_node.jump_to_next_station()
	game_state_node.reset_game()
	game_state_node.jump_to_next_station()
	stock_everything()
	game_state_node.reset_game()
	var kit: Array = _jehol().get("kit", [])
	for flag in config_node.map_data("morrison").get("kit", []):
		assert_has(kit, flag, "what he brought to the second station he brings on (%s)" % flag)
	assert_has(kit, String(config_node.RECIPES["bone_shovel"]["unlocks"]), "and the bone shovel he made there")
	for flag in kit:
		assert_true(game_state_node.has_unlock(String(flag)), "he has %s" % flag)
	for res_id in config_node.INITIAL_RESOURCES:
		assert_eq(int(game_state_node.resources.get(res_id, 0)), int(config_node.INITIAL_RESOURCES[res_id]),
			"the stock stayed behind (%s)" % res_id)

func test_03_its_cast_is_its_own_feathered_and_heard() -> void:
	var map: Dictionary = _jehol()
	var cast: Array = _cast(map)
	var before: Array = _cast(config_node.map_data("valley_large")) + _cast(config_node.map_data("morrison"))
	for species in cast:
		assert_true(config_node.DINOS.has(species), "%s is an animal of the game" % species)
		assert_false(before.has(species), "%s is the Jehol's own, not an earlier station's" % species)
		assert_ne(tr(String(config_node.DINOS[species]["name"])), String(config_node.DINOS[species]["name"]), "%s is named" % species)
		var voice: String = String(config_node.DINOS[species].get("voice", species))
		for call in ["call", "alert", "bite", "hurt", "death"]:
			var sound: Dictionary = config_node.SOUNDS["sounds"].get("%s_%s" % [voice, call], {})
			assert_false(sound.is_empty(), "%s has its %s" % [species, call])
			for file in sound.get("files", []):
				assert_true(FileAccess.file_exists("res://assets/audio/%s.wav" % String(file)), "%s.wav is made" % file)
	assert_true(bool(config_node.DINOS[String(map["boss"])].get("heavy", false)), "its boss is one of the heavy ones")
	assert_true(config_node.SOUNDS["sounds"].has("%s_roar" % String(map["boss"])), "heard over the valley as it comes")
	assert_eq(String(config_node.DINOS[String(map["minor_boss"])].get("boss", "")), "minor", "its big raids led by a minor boss")
	assert_gt(int(config_node.DINOS[String(map["minor_boss"])]["drops"].get("hide", 0)), 0,
		"which leaves a hide -- the bloomery's bellows")
	var runs: bool = false
	for step in map.get("raiders_by_day", []):
		for species in step["raiders"]:
			if String(config_node.DINOS[String(species)].get("behaviour", "")) == "runner":
				runs = true
	assert_true(runs, "from the second day something runs past the towers for him")
	assert_true(map.get("prowlers", {}).is_empty(), "nothing hunts its lake by night yet")

func test_04_its_lake_has_clay_and_bog_iron_for_the_shovel() -> void:
	var map: Dictionary = _jehol()
	var counts: Dictionary = {}
	for node in map["default_resource_nodes"]:
		counts[String(node["type"])] = int(counts.get(String(node["type"]), 0)) + 1
	assert_gt(int(counts.get("iron_ore", 0)), 0, "bog iron at its lake's edge")
	assert_gt(int(counts.get("clay", 0)), 0, "and clay for the kiln")
	for part in ["antenna", "battery", "board"]:
		assert_eq(int(counts.get(part, 0)), 1, "one wreck holds the %s" % part)
	var shovel: String = String(config_node.RECIPES["bone_shovel"]["unlocks"])
	assert_eq(String(config_node.harvest_requires_unlock("iron_ore")), shovel, "the shovel digs the ore")
	assert_has(map.get("kit", []), shovel, "and he lands with it")
	var morrison: Dictionary = config_node.map_data("morrison")
	for node in morrison["default_resource_nodes"]:
		assert_ne(String(node["type"]), "iron_ore", "there is no iron before the third station")

func test_05_the_custom_game_plays_its_age_and_its_map() -> void:
	game_state_node.play("custom", {"map": "large", "era": "early_cretaceous"})
	game_state_node.reset_game()
	assert_eq(game_state_node.map_data()["boss"], _jehol()["boss"], "the Early Cretaceous on the valley: the Jehol's animals")
	assert_eq(game_state_node.map_data().get("day_hints", {}), _jehol()["day_hints"], "and its words for the day")
	game_state_node.play("custom", {"map": "jehol", "era": "late_triassic"})
	game_state_node.reset_game()
	assert_eq(String(game_state_node.map_id), "jehol", "the Jehol map")
	assert_eq(game_state_node.map_data()["boss"], config_node.map_data("valley")["boss"], "with the Late Triassic's animals on it")
	for setting in ["era", "map"]:
		var ids: Array = []
		for choice in config_node.custom_setting(setting)["choices"]:
			ids.append(String(choice["id"]))
		assert_has(ids, "early_cretaceous" if setting == "era" else "jehol", "a choice on the custom game's page")

func test_06_the_day_is_told_in_its_animals() -> void:
	var words: Dictionary = _jehol().get("day_hints", {})
	for part in ["dawn", "dusk", "night", "dusk_first"]:
		assert_true(words.has(part), "its own word for the %s" % part)
		for locale in ["en", "zh_CN"]:
			var t: Translation = TranslationServer.get_translation_object(locale)
			assert_true(t != null and String(t.get_message(String(words.get(part, "")))) != "", "in %s (%s)" % [locale, part])
	var raider: String = tr(String(config_node.DINOS[String(_jehol()["guards"])]["name"])).to_lower()
	assert_true(tr(String(words["dusk"])).to_lower().contains(raider) or tr(String(words["dusk"])).contains(tr(String(config_node.DINOS[String(_jehol()["guards"])]["name"]))),
		"the dusk names its raiders going home")
