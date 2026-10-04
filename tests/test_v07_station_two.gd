# res://tests/test_v07_station_two.gd
# The player, 2026-10-02: "把第一关先做完，做完之后可以试着做第二关，把这个串联动画也做出来".
#
# STATION 2, A FIRST VERSION: the Late Jurassic, the Morrison Formation (GAME-DESIGN 7.2). Our game goes on to it:
# the beacon's jump at the end of the first station lands the capsule there (StationJump) -- the cabin and his
# tools with him, the stock and the base left behind (the map's kit). Its cast is its own: Ornitholestes raiding,
# Harpactognathus FLYING in from the second day -- over the walls, past everything on the ground, reached only by
# the bow tower -- Ceratosaurus and Allosaurus. Its new craft: clay, dug from the river bank with a bone shovel, made
# into fire pots the catapult throws -- the ground burns where they break.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _world: Node3D = null

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
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

func _stations() -> Array:
	return config_node.GAMES["campaign"].get("stations", [])

func _morrison() -> Dictionary:
	return config_node.map_data("morrison")

## A grid and a bare field with a mesh over it, and a BuildSystem on them.
func _field() -> Array:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	return [gm, bs]

func _animal(species: String, at: Vector3, still: bool = true) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	d.setup(species)
	_world.add_child(d)
	d.global_position = at
	if still:
		d.set_physics_process(false)
	return d

func _until(done: Callable, seconds: float) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < seconds and not bool(done.call()):
		await tree.physics_frame
		t += dt

# ==============================================================================
# 1. Our game goes on to a second station
# ==============================================================================

func test_01_our_game_goes_on_to_a_second_station() -> void:
	var stations: Array = _stations()
	assert_gte(stations.size(), 2, "our game has a second station")
	for s in stations:
		for key in ["id", "name", "age", "place", "when", "settings"]:
			assert_has(s, key, "station %s says its %s" % [s.get("id", "?"), key])
		for key in ["name", "age", "place", "when"]:
			assert_ne(tr(String(s[key])), String(s[key]), "its %s is worded (%s)" % [key, s[key]])
	var two: Dictionary = stations[1]
	var map_choice: Dictionary = config_node.custom_choice("map", String(two["settings"]["map"]))
	assert_eq(String(map_choice.get("map_id", "")), "morrison", "the second is played on the Morrison map")
	game_state_node.play("campaign")
	game_state_node.reset_game()
	assert_eq(int(game_state_node.station), 0, "a game begins at its first station")
	assert_ne(String(game_state_node.map_id), "morrison", "on the first station's map")
	assert_true(game_state_node.has_next_station(), "with a station after it")
	assert_true(game_state_node.jump_to_next_station(), "the jump goes on")
	assert_eq(int(game_state_node.station), 1, "to the second")
	assert_true(game_state_node.arrived_by_jump, "its level opens on the landing")
	assert_true(game_state_node.launch_straight_in, "not on the start screen")
	game_state_node.reset_game()
	assert_eq(String(game_state_node.map_id), "morrison", "the second station's run is on its map")
	assert_false(game_state_node.has_next_station(), "it is the last, for now")
	assert_false(game_state_node.jump_to_next_station(), "and its jump goes nowhere further")
	game_state_node.play("campaign")
	assert_eq(int(game_state_node.station), 0, "a game chosen again begins at the first")

func test_02_he_lands_with_his_tools_and_without_the_base() -> void:
	game_state_node.play("campaign")
	game_state_node.jump_to_next_station()
	stock_everything()
	game_state_node.reset_game()
	var kit: Array = _morrison().get("kit", [])
	assert_false(kit.is_empty(), "the second station says what he lands with")
	for flag in kit:
		assert_true(game_state_node.has_unlock(String(flag)), "he has %s" % flag)
		var made_by: String = ""
		for rid in config_node.RECIPES:
			if String(config_node.RECIPES[rid].get("unlocks", "")) == String(flag):
				made_by = String(rid)
		assert_ne(made_by, "", "%s is something made" % flag)
	assert_true(game_state_node.has_unlock(String(config_node.RECIPES["stone_pick"]["unlocks"])), "he can quarry stone")
	for res_id in config_node.INITIAL_RESOURCES:
		assert_eq(int(game_state_node.resources.get(res_id, 0)), int(config_node.INITIAL_RESOURCES[res_id]),
			"the stock stayed behind (%s)" % res_id)
	assert_eq(int(game_state_node.beacon_steps), 0, "and the beacon is to mend again here")

# ==============================================================================
# 2. Its cast
# ==============================================================================

func test_03_its_cast_is_its_own() -> void:
	var map: Dictionary = _morrison()
	var cast: Array = []
	for species in map["raiders"]:
		cast.append(String(species))
	for step in map.get("raiders_by_day", []):
		for species in step["raiders"]:
			cast.append(String(species))
	cast.append(String(map["guards"]))
	cast.append(String(map["minor_boss"]))
	cast.append(String(map["boss"]))
	for species in cast:
		assert_true(config_node.DINOS.has(species), "%s is an animal of the game" % species)
		assert_true(config_node.VISUALS.has("dino/" + species), "%s has its model's row" % species)
		assert_ne(tr(String(config_node.DINOS[species]["name"])), String(config_node.DINOS[species]["name"]), "%s is named" % species)
	var first: Dictionary = config_node.map_data("valley_large")
	for species in [first["guards"], first["minor_boss"], first["boss"]]:
		assert_false(cast.has(String(species)), "the first station's %s is not in the Jurassic" % species)
	assert_true(map.get("prowlers", {}).is_empty(), "nothing hunts its river by night yet")
	var flies: bool = false
	for step in map.get("raiders_by_day", []):
		for species in step["raiders"]:
			if bool(config_node.DINOS[String(species)].get("flies", false)):
				flies = true
	assert_true(flies, "something comes on the wing")
	assert_true(bool(config_node.DINOS[String(map["boss"])].get("heavy", false)), "its boss is one of the heavy ones")

# ==============================================================================
# 3. On the wing
# ==============================================================================

func _flyer() -> String:
	for species in config_node.DINOS:
		if bool(config_node.DINOS[species].get("flies", false)):
			return String(species)
	return ""

func test_04_what_flies_is_over_everything_on_the_ground() -> void:
	var f: Array = await _field()
	var species: String = _flyer()
	assert_ne(species, "", "something flies")
	var flight: Dictionary = config_node.DINO_AI["flight"]
	var d = _animal(species, Vector3(0.0, 0.0, -1.0), false)
	await wait_physics_frames(2)
	d.set_physics_process(false)
	d.global_position.y = float(flight["cruise_height"])
	assert_true(d.is_flying(), "it is in the air")
	assert_eq(int(d.collision_mask), 0, "it bumps into nothing")
	stock_everything()
	var wall = f[1].place_at("bone_stake", Vector2i(0, -1), _world, false)
	wall.complete_construction()
	assert_false(wall.touches(d), "a stake's points do not reach it")
	var spikes = f[1].place_at("ground_spikes", Vector2i(2, -1), _world, false)
	spikes.complete_construction()
	d.global_position = Vector3(spikes.global_position.x, d.global_position.y, spikes.global_position.z)
	assert_false(spikes.animals_on_it().has(d), "nor do the spikes")
	var logs = f[1].place_at("log_tower", Vector2i(0, 6), _world, false, 0)
	logs.complete_construction()
	d.global_position = logs.lane_origin() + logs.forward() * 2.0 + Vector3(0.0, d.global_position.y, 0.0)
	assert_false(logs.animals_in_lane(0.0, logs.lane_length()).has(d), "nor a log tower's lane")
	var cat = f[1].place_at("catapult", Vector2i(10, 0), _world, false, 0)
	cat.complete_construction()
	d.global_position = cat.zone_centre() + Vector3(0.0, d.global_position.y, 0.0)
	assert_false(cat.animals_in_zone().has(d), "nor the catapult's patch")

func test_05_only_the_bow_tower_brings_it_down() -> void:
	var f: Array = await _field()
	var species: String = _flyer()
	stock_everything()
	var bow = f[1].place_at("bow_tower", Vector2i(0, 0), _world, false)
	bow.complete_construction()
	bow.set_ammo("arrow_wood")
	bow.load_from_stock()
	var d = _animal(species, bow.global_position + Vector3(0.0, float(config_node.DINO_AI["flight"]["cruise_height"]), -3.0))
	assert_eq(bow.target_in_reach(), d, "the bow tower reaches it")
	assert_lte(float(config_node.DINOS[species]["hp"]), float(config_node.AMMO["arrow_wood"]["damage"]), "one wooden arrow is enough")
	var died: Array = [false]
	d.tree_exiting.connect(func(): died[0] = true)
	await _until(func(): return died[0], float(config_node.BUILDINGS["bow_tower"]["fire_seconds"]) * 2.0)
	assert_true(died[0], "an arrow brings it down")

## It swoops on what it is after -- the man who strikes at it, here (the cabin otherwise: Dino._think) -- bites once,
## and climbs away.
func test_06_it_swoops_on_him_bites_and_climbs_away() -> void:
	await _field()
	var species: String = _flyer()
	var flight: Dictionary = config_node.DINO_AI["flight"]
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	_world.add_child(hero)
	hero.global_position = Vector3(0.0, 0.0, 0.0)
	hero.set_physics_process(false)
	var hp: float = float(hero.current_hp)
	var d = _animal(species, Vector3(0.0, float(flight["cruise_height"]), -10.0), false)
	# He has just struck at it (Hero.has_provoked_dinos): within his reach of it, it answers him. Kept so while it
	# comes round (provoke_timer is his to run down; his physics is held).
	hero.has_provoked_dinos = true
	hero.provoke_timer = 30.0
	var radius: float = float(config_node.HERO.get("provoke_radius", 4.0))
	d.global_position = Vector3(0.0, float(flight["cruise_height"]), -radius * 0.25)
	await _until(func(): return float(hero.current_hp) < hp, 12.0)
	assert_almost_eq(hp - float(hero.current_hp), float(config_node.DINOS[species]["damage"]), 0.001, "it came down and bit him")
	var low: float = d.global_position.y
	await wait_seconds(float(flight["climb_seconds"]) * 0.8)
	assert_gt(d.global_position.y, low, "and climbs away")

func test_06b_its_hours_over_it_flies_home_and_is_gone() -> void:
	await _field()
	var species: String = _flyer()
	var d = _animal(species, Vector3(0.0, float(config_node.DINO_AI["flight"]["cruise_height"]), 0.0), false)
	var nest := Vector3(0.0, 0.0, -12.0)
	var home: Array = [false]
	var eb = tree.root.get_node("EventBus")
	var went := func(who: Node) -> void:
		if who == d:
			home[0] = true
	eb.dino_went_home.connect(went)
	d.go_home(nest)
	var gone: Array = [false]
	d.tree_exiting.connect(func(): gone[0] = true)
	await _until(func(): return gone[0], 12.0 / float(config_node.DINOS[species]["speed"]) + 3.0)
	eb.dino_went_home.disconnect(went)
	assert_true(home[0], "it flew home to the nest")
	assert_true(gone[0], "and is gone there")

# ==============================================================================
# 4. Clay, the bone shovel, fire pots
# ==============================================================================

func test_07_clay_takes_the_bone_shovel() -> void:
	assert_has(config_node.RESOURCES, "clay", "clay is kept in the stock")
	var needs: String = String(config_node.harvest_requires_unlock("clay"))
	assert_ne(needs, "", "bare hands do not dig it")
	assert_eq(String(config_node.RECIPES["bone_shovel"]["unlocks"]), needs, "the bone shovel does")
	assert_eq(config_node.RECIPES["bone_shovel"]["inputs"].keys(), ["bone"], "a shovel of bone, named for it")
	var banks: int = 0
	for node in _morrison()["default_resource_nodes"]:
		if String(node["type"]) == "clay":
			banks += 1
	assert_gt(banks, 0, "the second station's river bank has clay")
	assert_true(config_node.RECIPES["fire_pot"]["inputs"].has("clay"), "fire pots are made of it")
	assert_true(config_node.ammo_accepts("catapult").has("fire_pot"), "and the catapult throws them")

func test_08_a_fire_pot_sets_the_ground_burning() -> void:
	var f: Array = await _field()
	stock_everything()
	var cat = f[1].place_at("catapult", Vector2i(0, 0), _world, false, 0)
	cat.complete_construction()
	cat.set_ammo("fire_pot")
	cat.load_from_stock()
	var burn: Dictionary = config_node.AMMO["fire_pot"]["burn"]
	var d = _animal("raptor", cat.zone_centre())
	d.max_hp = 999.0
	d.current_hp = 999.0
	await _until(func(): return not tree.get_nodes_in_group(FirePatch.GROUP).is_empty(), float(config_node.BUILDINGS["catapult"]["flight_seconds"]) + 1.0)
	var patches: Array = tree.get_nodes_in_group(FirePatch.GROUP)
	assert_eq(patches.size(), 1, "where it broke, the ground burns")
	if patches.is_empty():
		return
	# One pot is what is being watched: the catapult would throw again at what is still in its patch.
	cat.uses_left = 0
	var after_the_hit: float = d.current_hp
	assert_almost_eq(999.0 - after_the_hit, float(config_node.AMMO["fire_pot"]["damage"]), 0.001, "the pot's own blow")
	await wait_seconds(2.2)
	assert_lt(d.current_hp, after_the_hit, "and what stands in the fire burns")
	await wait_seconds(float(burn["seconds"]))
	assert_true(tree.get_nodes_in_group(FirePatch.GROUP).is_empty(), "then it burns out")

## The pot flies burning: the rag in its neck keeps the glowing material the art gave it -- the matte vertex colour
## every prop is dressed in (VisualLibrary._dress) is not put over it -- and the rest of the pot is dressed as props are.
func test_08b_the_fire_pot_flies_burning() -> void:
	var key: String = "prop/fire_pot"
	assert_eq(String(config_node.VISUALS[key].get("material", "")), "vertex", "the pot is dressed as a prop")
	var pot: Node3D = VisualLibrary.make(key)
	assert_not_null(pot, "the fire pot has art")
	if pot == null:
		return
	var lit: int = 0
	var dressed: int = 0
	for m in pot.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if VisualLibrary.glows(mi):
			lit += 1
			assert_null(mi.material_override, "%s keeps its own glow" % mi.name)
		else:
			dressed += 1
			assert_not_null(mi.material_override, "%s is dressed as every prop is" % mi.name)
	assert_gt(lit, 0, "something on it glows: the fire in its neck")
	assert_gt(dressed, 0, "and the pot itself is dressed")
	pot.free()

# ==============================================================================
# 5. The jump
# ==============================================================================

func test_09_the_jump_goes_on_and_the_capsule_lands() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	game_state_node.play("campaign")
	assert_not_null(main.station_jump, "the level has the jump")
	# A raider of the beacon's last raid still at the cabin when it is won.
	var raider = load(String(config_node.get_dino_script_path("raptor"))).new()
	main.dinos_container.add_child(raider)
	raider.setup("raptor")
	raider.global_position = main.current_core.global_position + Vector3(6.0, 0.0, 0.0)
	var went: Array = [false]
	main.station_jump.departed.connect(func(): went[0] = true)
	main.station_jump.depart(main)
	assert_true(main.station_jump.is_running(), "the jump is under way")
	assert_false(main.hud.visible, "the HUD out of the way")
	assert_true(bool(raider.going_home), "the field goes quiet: what was at the cabin goes back to its nest")
	main.station_jump.finish_now()
	await wait_frames(2)
	assert_true(went[0], "it went")
	assert_eq(int(game_state_node.station), 1, "on to the second station")
	assert_true(game_state_node.arrived_by_jump, "whose level opens on the landing")
	var core: Node3D = main.current_core
	var rest: Vector3 = core.position
	main.station_jump.arrive(main)
	assert_true(game_state_node.is_paused, "held still while it comes down")
	assert_gt(core.position.y, rest.y + 1.0, "the capsule up in the sky, its benches with it")
	for station in core.find_children("*", "CraftingStation", true, false):
		assert_gt((station as Node3D).global_position.y, rest.y + 1.0, "%s up in it" % station.name)
	main.station_jump.finish_now()
	await wait_frames(2)
	main.station_jump.finish_now()
	await wait_frames(2)
	assert_false(game_state_node.is_paused, "down, the run begins")
	assert_false(game_state_node.arrived_by_jump, "landed")
	assert_true(main.hud.visible, "the HUD back")
	assert_almost_eq(core.position.y, rest.y, 0.01, "the capsule on its spot")
	assert_almost_eq(core.position.x, rest.x, 0.01, "where it was")

func test_11_a_custom_game_plays_an_age_on_any_map() -> void:
	var valley: Dictionary = config_node.map_data("valley")
	game_state_node.play("custom", {"map": "morrison", "era": "late_triassic"})
	game_state_node.reset_game()
	assert_eq(String(game_state_node.map_id), "morrison", "station 2's map")
	for key in ["raiders", "guards", "minor_boss", "boss", "prowlers"]:
		assert_eq(game_state_node.map_data()[key], valley[key], "with the Late Triassic's %s" % key)
	assert_eq(game_state_node.map_data()["herds"], config_node.HERDS["herds"], "and its grazers")
	game_state_node.play("custom", {"map": "large", "era": "late_jurassic"})
	game_state_node.reset_game()
	assert_eq(game_state_node.map_data()["boss"], _morrison()["boss"], "and the Late Jurassic's on the valley")
	game_state_node.play("campaign")
	game_state_node.reset_game()
	assert_eq(game_state_node.map_data()["boss"], config_node.map_data("valley_large")["boss"], "our game's first station is its own")

## The day's turns are told in the station's own animals: the Morrison's raiders, and nothing up out of its river by
## night -- not the Chinle's coelophysis and phytosaurs -- and an age carries its words with its animals onto any map.
func test_12_the_day_is_told_in_the_stations_animals() -> void:
	game_state_node.play("campaign")
	game_state_node.jump_to_next_station()
	game_state_node.reset_game()
	assert_eq(String(game_state_node.map_id), "morrison", "station 2")
	var words: Dictionary = game_state_node.map_data().get("day_hints", {})
	for part in ["dawn", "dusk", "night", "dusk_first"]:
		assert_true(words.has(part), "its own word for the %s" % part)
		assert_ne(tr(String(words.get(part, ""))), String(words.get(part, "")), "in the string table")
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.hud._on_day_part_changed("night", 1)
	assert_eq(String(main.hud.hint_label.text), tr(String(words["night"])), "the night said in the Morrison's animals")
	main.hud._on_day_part_changed("day", 2)
	assert_eq(String(main.hud.hint_label.text), tr(String(words["dawn"])), "and the dawn")
	game_state_node.play("custom", {"map": "morrison", "era": "late_triassic"})
	game_state_node.reset_game()
	assert_true(game_state_node.map_data().get("day_hints", {}).is_empty(), "the Late Triassic on it: the Chinle's words")
	game_state_node.play("custom", {"map": "large", "era": "late_jurassic"})
	game_state_node.reset_game()
	assert_eq(game_state_node.map_data().get("day_hints", {}), words, "the Late Jurassic on the valley: the Morrison's")
	assert_eq(game_state_node.map_data()["raiders"], _morrison()["raiders"], "with its raiders")

func test_10_won_with_a_station_ahead_is_not_the_end() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	game_state_node.play("campaign")
	assert_true(game_state_node.has_next_station(), "a station ahead")
	main.hud._on_game_won()
	assert_false(main.hud.is_game_over_visible(), "no verdict: the jump goes on")
	game_state_node.station = _stations().size() - 1
	main.hud._on_game_won()
	assert_true(main.hud.is_game_over_visible(), "won at the last station, the verdict")
