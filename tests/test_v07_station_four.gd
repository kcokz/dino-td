# res://tests/test_v07_station_four.gd
# The player, 2026-10-05: "把后面几关都先做起来，主要是科技树升级部分".
#
# STATION 4 (GAME-DESIGN 7.2: 白垩纪末 · 地狱溪组): our game's last station -- the end of the Cretaceous on a warm coastal
# plain; he lands with every tool; its cast is its own (Acheroraptor, Dakotaraptor, Tyrannosaurus last of all); clay and
# bog iron by its river; the custom game can play its age and its map; the day's turns are told in its animals. And the
# catapult's top for iron, the counterweight trebuchet: further, harder, slower (5.2: "第 4 站……把铁用到底").
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

func after_each() -> void:
	if game_state_node != null:
		game_state_node.game = {}
		game_state_node.station = 0
		game_state_node.arrived_by_jump = false
		game_state_node.launch_straight_in = false
		game_state_node.reset_game()
	super.after_each()

func _stations() -> Array:
	return config_node.GAMES["campaign"].get("stations", [])

func _hell_creek() -> Dictionary:
	return config_node.map_data("hell_creek")

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

func test_01_our_game_ends_at_a_fourth_station() -> void:
	var stations: Array = _stations()
	assert_eq(stations.size(), 4, "our game has four stations")
	var four: Dictionary = stations[3]
	assert_eq(String(four["id"]), "hell_creek", "the last at Hell Creek")
	for key in ["name", "age", "place", "when"]:
		assert_ne(tr(String(four[key])), String(four[key]), "its %s is worded (%s)" % [key, four[key]])
	assert_eq(String(config_node.custom_choice("map", String(four["settings"]["map"])).get("map_id", "")), "hell_creek",
		"played on the Hell Creek map")
	game_state_node.play("campaign")
	for k in 3:
		game_state_node.reset_game()
		assert_true(game_state_node.jump_to_next_station(), "station %d jumps on" % (k + 1))
	game_state_node.reset_game()
	assert_eq(int(game_state_node.station), 3, "to the fourth")
	assert_eq(String(game_state_node.map_id), "hell_creek", "on its map")
	assert_false(game_state_node.has_next_station(), "the last station")
	assert_false(game_state_node.jump_to_next_station(), "whose jump goes nowhere further")
	assert_has(_hell_creek().get("kit", []), String(config_node.RECIPES["bone_shovel"]["unlocks"]), "he lands with the shovel")

func test_02_its_cast_is_its_own_and_the_tyrannosaur_comes_last() -> void:
	var map: Dictionary = _hell_creek()
	var cast: Array = _cast(map)
	var before: Array = []
	for id in ["valley_large", "morrison", "jehol"]:
		before += _cast(config_node.map_data(id))
	for species in cast:
		assert_true(config_node.DINOS.has(species), "%s is an animal of the game" % species)
		assert_false(before.has(species), "%s is Hell Creek's own" % species)
		assert_ne(tr(String(config_node.DINOS[species]["name"])), String(config_node.DINOS[species]["name"]), "%s is named" % species)
		assert_true(ResourceLoader.exists(String(config_node.VISUALS["dino/" + species]["scene"])), "%s is drawn" % species)
		var voice: String = String(config_node.DINOS[species].get("voice", species))
		for call in ["call", "alert", "bite", "hurt", "death"]:
			assert_true(config_node.SOUNDS["sounds"].has("%s_%s" % [voice, call]), "%s has its %s" % [species, call])
	var boss: String = String(map["boss"])
	assert_eq(String(config_node.DINOS[boss].get("boss", "")), "major", "the great boss")
	assert_true(bool(config_node.DINOS[boss].get("heavy", false)), "one of the heavy ones")
	assert_eq(tr(String(config_node.DINOS[boss]["name"])), tr("DINO_BIG_THEROPOD_NAME"), "Tyrannosaurus")
	assert_eq(String(config_node.DINOS[String(map["minor_boss"])].get("boss", "")), "minor", "its big raids led by a minor boss")
	assert_gt(int(config_node.DINOS[String(map["minor_boss"])]["drops"].get("hide", 0)), 0, "which leaves a hide")
	var counts: Dictionary = {}
	for node in map["default_resource_nodes"]:
		counts[String(node["type"])] = int(counts.get(String(node["type"]), 0)) + 1
	assert_gt(int(counts.get("iron_ore", 0)), 0, "bog iron by its river")
	assert_gt(int(counts.get("clay", 0)), 0, "and clay")

func test_03_the_custom_game_plays_its_age_and_its_map_and_the_day_is_told_in_its_animals() -> void:
	game_state_node.play("custom", {"map": "large", "era": "end_cretaceous"})
	game_state_node.reset_game()
	assert_eq(game_state_node.map_data()["boss"], _hell_creek()["boss"], "the end of the Cretaceous on the valley: Hell Creek's animals")
	game_state_node.play("custom", {"map": "hell_creek", "era": "late_triassic"})
	game_state_node.reset_game()
	assert_eq(String(game_state_node.map_id), "hell_creek", "the Hell Creek map")
	var words: Dictionary = _hell_creek().get("day_hints", {})
	for part in ["dawn", "dusk", "night", "dusk_first"]:
		for locale in ["en", "zh_CN"]:
			var t: Translation = TranslationServer.get_translation_object(locale)
			assert_true(t != null and String(t.get_message(String(words.get(part, "")))) != "", "its %s in %s" % [part, locale])

func test_04_the_catapults_top_is_the_trebuchet_for_iron() -> void:
	var tops: Array = config_node.upgrade_targets("catapult_3")
	assert_has(tops, "catapult_trebuchet", "The catapult's third level becomes the trebuchet")
	assert_eq(config_node.upgrade_cost("catapult_3", "catapult_trebuchet").keys(), ["iron"], "for iron alone")
	assert_eq(int(config_node.tower_level("catapult_trebuchet")), 4, "a fourth level")
	var three: Dictionary = config_node.BUILDINGS["catapult_3"]
	var top: Dictionary = config_node.BUILDINGS["catapult_trebuchet"]
	assert_eq(String(top["kind"]), "thrower", "still a thrower")
	assert_gt(float(top["range"]), float(three["range"]), "It throws further")
	assert_gt(float(top["damage_factor"]), float(three["damage_factor"]), "harder")
	assert_gt(float(top["throw_seconds"]), float(three["throw_seconds"]), "and slower")
	assert_gte(float(top["min_range"]), float(three["min_range"]), "its foot no nearer")
	assert_gt(float(top.get("wound_degrees", 0.0)), float(config_node.TOWERS["catapult_wound_degrees"]), "its long arm drawn further round")
	assert_true(ResourceLoader.exists(String(config_node.VISUALS["building/catapult_trebuchet"]["scene"])), "drawn as itself")
	assert_ne(tr(String(top["name"])), String(top["name"]), "and named")

func test_05_a_catapult_raised_to_a_trebuchet_draws_its_own_long_arm_and_its_weight_hangs_plumb() -> void:
	var gm = load("res://scripts/core/GridManager.gd").new()
	tree.root.add_child(gm)
	var world: Node3D = await nav_fixture()
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	tree.root.add_child(bs)
	bs.setup(gm, world)
	stock_everything()
	var cat = bs.place_at("catapult_3", Vector2i(0, 0), world, false)
	assert_not_null(cat, "(a third-level catapult)")
	if cat != null:
		cat.complete_construction()
		cat.set_ammo("shot_stone")
		cat.load_from_stock()
		var catapult_degrees: float = rad_to_deg(cat._wound().x - cat._stop().x)
		assert_almost_eq(catapult_degrees, float(config_node.TOWERS["catapult_wound_degrees"]), 0.01, "(the catapult's arm, wound)")
		assert_true(cat.begin_upgrade("catapult_trebuchet"), "Raised to the trebuchet")
		var spent: int = 0
		while cat.is_upgrading() and spent < 100:
			cat.add_upgrade_progress(1.0)
			spent += 1
		assert_eq(String(cat.building_type), "catapult_trebuchet", "it is one")
		assert_not_null(cat.part("Weight"), "with its counterweight")
		var degrees: float = rad_to_deg(cat._wound().x - cat._stop().x)
		assert_almost_eq(degrees, float(config_node.BUILDINGS["catapult_trebuchet"]["wound_degrees"]), 0.01,
			"its long arm drawn its own way round, not the catapult's")
		await wait_frames(2)
		var arm: Node3D = cat.part("Arm")
		var weight: Node3D = cat.part("Weight")
		if arm != null and weight != null:
			assert_almost_eq(weight.global_transform.basis.y.dot(Vector3.UP), 1.0, 0.02, "and the weight hangs plumb under it")
	for n in [bs, world, gm]:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
