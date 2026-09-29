# res://tests/test_v06_the_map_size.gd
# v0.6 round four, the player: "地图放大做成可自定义（也为了通关以后解锁自定义），这样，测试的时候可以用小地图，
# 我玩的时候用大地图" -- and GAME-DESIGN 9.3: three to five times the ground, places rather than paths.
#
# A map is `like` another with its own keys over it: the large valley is the valley, four times the
# ground, the nest twice as far, a ridge, a stone forest and a stand of trees between, its river past
# its own edge (Config.terrain_of: the land, merged a table deep). The settings page chooses the size;
# only the game the player launched plays it (Main._choose_the_map) -- a level a test or a tool
# builds plays the small valley. And a bake of the bigger ground takes three fifths of a second: it
# is done in the background in play (NavMaps.rebake_in_background), never stopping the game.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

const LARGE := "valley_large"

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null:
		game_state_node.chosen_map_id = ""
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null:
		game_state_node.chosen_map_id = ""
		game_state_node.reset_game()
	super.after_each()

func _level_on(map_id: String) -> Node:
	game_state_node.chosen_map_id = map_id
	game_state_node.reset_game()
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _small() -> String:
	return String(config_node.MAP_SIZES["small"])

func _field_half(map_id: String) -> float:
	return float(config_node.terrain_of(map_id)["field_half"])

## Where a map's cell is on the ground, as the level puts it (GridManager.cell_to_world).
func _at(cell: Vector2i) -> Vector2:
	var tile: float = float(config_node.TILE_SIZE)
	return Vector2((float(cell.x) + 0.5) * tile, (float(cell.y) + 0.5) * tile)

func test_01_the_sizes_are_the_small_valley_and_the_large() -> void:
	assert_eq(String(config_node.MAP_SIZES["small"]), String(config_node.DEFAULT_MAP_ID),
		"The small valley is the default: the tests' and the tools'")
	assert_eq(String(config_node.MAP_SIZES["large"]), LARGE, "The large is its own map")
	assert_eq(String(config_node.DEFAULT_MAP_SIZE), "large", "and the player's until they choose")

func test_02_the_large_valley_is_the_valley_bigger() -> void:
	var small: Dictionary = config_node.map_data(_small())
	var large: Dictionary = config_node.map_data(LARGE)
	for key in ["raiders", "guards", "beacon", "opening_stock", "beats", "minor_boss", "boss"]:
		assert_eq(large.get(key), small.get(key), "Its %s are the valley's" % key)
	assert_false(large.has("like"), "(the map it is like, resolved)")
	assert_true(large.is_read_only(), "and it cannot be changed under a run")
	var area: float = pow(_field_half(LARGE) / _field_half(_small()), 2.0)
	assert_gte(area, 3.0, "Three to five times the ground (GAME-DESIGN 9.3): %.1f" % area)
	assert_lte(area, 5.0, "not more")
	var nest_small: float = _at(small["default_nest_cell"]).distance_to(_at(small["default_core_cell"]))
	var nest_large: float = _at(large["default_nest_cell"]).distance_to(_at(large["default_core_cell"]))
	assert_gte(nest_large, nest_small * 1.8, "The nest much further off")
	assert_gt(large["default_resource_nodes"].size(), small["default_resource_nodes"].size(), "More to gather")

func test_03_its_land_is_the_valleys_with_its_own_over_it() -> void:
	assert_true(is_same(config_node.terrain_of(_small()), config_node.TERRAIN),
		"A map with no land of its own has the valley's, itself")
	var land: Dictionary = config_node.terrain_of(LARGE)
	assert_true(land.is_read_only(), "The large valley's land cannot change under the ground built for it")
	assert_true(is_same(land, config_node.terrain_of(LARGE)), "and is made once")
	assert_eq(float(land["field_half"]), _field_half(LARGE), "Its own field")
	var river: Dictionary = land["river"]
	assert_ne(river["course"], config_node.TERRAIN["river"]["course"], "Its own river's course")
	for key in ["seed", "margin", "water", "reeds"]:
		assert_eq(river.get(key), config_node.TERRAIN["river"].get(key), "the rest of the river the valley's: %s" % key)
	# The river runs past the field's edge, as the valley's does: never across the flat.
	var flat: float = _field_half(LARGE) + float(land.get("flat_apron", 0.0))
	for point in river["course"]:
		var at: Vector2 = point["at"]
		assert_gt(maxf(absf(at.x), absf(at.y)), flat, "The river at %s is off the field" % str(at))

func test_04_everything_on_the_large_valley_stands_on_its_field() -> void:
	var map: Dictionary = config_node.map_data(LARGE)
	var half: float = _field_half(LARGE)
	var blocked: Dictionary = {}
	for cell in map["default_blocked_cells"]:
		assert_false(blocked.has(cell), "No hill set down twice: %s" % str(cell))
		blocked[cell] = true
		assert_lt(maxf(absf(_at(cell).x), absf(_at(cell).y)), half, "Hill %s on the field" % str(cell))
	var taken: Dictionary = {}
	for node in map["default_resource_nodes"]:
		var cell: Vector2i = node["cell"]
		assert_false(blocked.has(cell), "No %s on a hill: %s" % [node["type"], str(cell)])
		assert_false(taken.has(cell), "No two on one cell: %s" % str(cell))
		taken[cell] = true
		assert_lt(maxf(absf(_at(cell).x), absf(_at(cell).y)), half, "%s at %s on the field" % [node["type"], str(cell)])
	for cell in [map["default_core_cell"], map["default_nest_cell"]] + Array(map["entries"]):
		assert_false(blocked.has(cell) or taken.has(cell), "%s is clear" % str(cell))
		assert_lt(maxf(absf(_at(cell).x), absf(_at(cell).y)), half, "%s on the field" % str(cell))

func test_05_a_level_on_the_large_valley_is_the_large_valley() -> void:
	var main = await _level_on(LARGE)
	assert_eq(String(game_state_node.map_id), LARGE, "The run is on the large valley")
	var map: Dictionary = config_node.map_data(LARGE)
	var nest_at: Vector3 = main.current_nest.global_position
	var want: Vector2 = _at(map["default_nest_cell"])
	assert_almost_eq(Vector2(nest_at.x, nest_at.z).distance_to(want), 0.0, 0.5,
		"Its nest where the map puts it, not where the small valley's scene marks it")
	assert_almost_eq(float(main.fog.half), _field_half(LARGE) + float(config_node.FOG["margin"]), 0.01,
		"The fog over all of its field")
	var nav = main.nav_maps
	var core: Vector3 = main.current_core.global_position
	assert_true(nav.is_reachable(main.wave_manager.nest_spawn_position, core, NavMaps.For.RAID),
		"The raid has a way from the nest to the cabin")
	for cell in map["entries"]:
		var e: Vector2 = _at(cell)
		assert_true(nav.is_reachable(Vector3(e.x, 0.0, e.y), core, NavMaps.For.RAID), "and from the entry at %s" % str(cell))
	var nodes: Array = tree.get_nodes_in_group("resource_nodes")
	assert_eq(nodes.size(), map["default_resource_nodes"].size(), "Every node the map lists is in the level")
	for node in nodes:
		assert_true(_beside(nav, main.hero.global_position, (node as Node3D).global_position),
			"He can walk up to the %s at %s" % [str(node.get("resource_type")), str((node as Node3D).global_position)])

## Whether he can walk to one side or another of `at` -- a trunk or a rock is itself solid.
func _beside(nav: Node, from: Vector3, at: Vector3) -> bool:
	var step: float = float(config_node.TILE_SIZE) * 0.6
	for side in [Vector3(step, 0.0, 0.0), Vector3(-step, 0.0, 0.0), Vector3(0.0, 0.0, step), Vector3(0.0, 0.0, -step)]:
		if nav.is_reachable(from, at + side, NavMaps.For.HERO):
			return true
	return false

func test_06_a_level_a_script_builds_plays_the_small_valley() -> void:
	# Whatever the player chose: only the game they launched plays it.
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	assert_false(main._plays_the_players_map(), "A level a script built is not the game the player launched")
	assert_eq(String(game_state_node.map_id), String(config_node.DEFAULT_MAP_ID), "It plays the small valley")

func test_07_the_settings_page_offers_the_sizes() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var menu = main.hud.pause_menu
	main.hud.toggle_pause_menu()
	menu.open_settings()
	await wait_frames(1)
	var picker: OptionButton = menu.find_child("MapPicker", true, false) as OptionButton
	assert_not_null(picker, "The settings page has a map picker")
	if picker == null:
		main.hud.toggle_pause_menu()
		return
	assert_true(picker.is_visible_in_tree(), "on the settings page")
	var sizes: Array = config_node.MAP_SIZES.keys()
	assert_eq(picker.item_count, sizes.size(), "A size each")
	for i in sizes.size():
		assert_eq(picker.get_item_text(i), tr("MENU_MAP_" + String(sizes[i]).to_upper()), "named")
	var note: Label = menu.find_child("MapNote", true, false) as Label
	assert_true(note != null and note.text == tr("MENU_MAP_NOTE") and note.is_visible_in_tree(),
		"and it says a new map is for the next run")
	main.hud.toggle_pause_menu()

func test_08_a_stake_finished_in_play_is_baked_in_the_background() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	stock_everything()
	var nav = main.nav_maps
	var before: NavigationMesh = nav._regions[0].navigation_mesh
	var cell: Vector2i = main.grid_manager.world_to_build_cell(main.current_core.global_position + Vector3(0.0, 0.0, 6.0))
	var wall = main.build_system.place_at("wall", cell, main.buildings_container, true)
	wall.complete_construction()
	await wait_frames(1)
	assert_gt(int(nav._baking), 0, "Finished in play, it is baking on the worker threads")
	var frames: int = 0
	while int(nav._baking) > 0 and frames < 240:
		await wait_frames(1)
		frames += 1
	assert_eq(int(nav._baking), 0, "and done within four seconds (%d frames)" % frames)
	assert_ne(nav._regions[0].navigation_mesh, before, "The raid's map has the stake in it")

func test_09_a_bake_the_level_waits_for_is_not_undone_by_an_older_one() -> void:
	# A bake at once (rebake: a fixture, a test) while one is still in the background: the older one
	# finishing after it is not put in.
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var nav = main.nav_maps
	nav.rebake_in_background()
	nav.rebake()
	var now: NavigationMesh = nav._regions[0].navigation_mesh
	var frames: int = 0
	while int(nav._baking) > 0 and frames < 240:
		await wait_frames(1)
		frames += 1
	assert_eq(nav._regions[0].navigation_mesh, now, "The bake at once stands")
