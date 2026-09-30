# res://tests/test_v06_fire.gd
# GAME-DESIGN 9.3, "火与夜"; v0.6 round four, the player: "火把我觉得在夜里是很有用，但需要不只是照明的作用，比如
# 不用火把，晚上更多的夜行动物袭击（怕火把但是不怕暗淡灯光的船舱）".
#
# In the night he sees a few metres by the moon; a fire lights further. A campfire (wood) and a
# brazier (stone, lighting further) burn from dusk to first light on a night's wood from the stock,
# taken as they light -- no wood, no fire, until there is. The torch in his hand is a wood, burns a
# minute and lights the dark round him; its tile is there in the dark, to the left of Build and Eat,
# which do not move.
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
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _fire_cfg() -> Dictionary:
	return config_node.FIRE

func _torch() -> Dictionary:
	return config_node.FIRE["torch"]

func _at(part: String) -> float:
	return float(config_node.DAY["parts"][part])

## Sets the clock to `t` seconds into day `day`, and says the part of the day that is.
func _set_clock(t: float, day: int = 1) -> void:
	game_state_node.day_clock = float(day - 1) * float(config_node.DAY["length"]) + t
	game_state_node._run_the_day(0.0)

func _wood(n: int) -> void:
	game_state_node.resources["wood"] = n

## A `type_id` built a few metres off the cabin's door, finished.
func _build(main: Node, type_id: String, off: Vector3 = Vector3(-3.0, 0.0, 3.0)) -> Node:
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var b = main.build_system.place_at(type_id, main.grid_manager.world_to_build_cell(door + off), main.buildings_container)
	assert_not_null(b, "(a %s goes down by the cabin)" % type_id)
	return b

func test_01_the_fires_are_built_and_burn_wood() -> void:
	var fires: Array = []
	for type_id in config_node.BUILDABLE_TYPES:
		if String(config_node.get_building_kind(type_id)) == "fire":
			fires.append(type_id)
	assert_true(fires.has("campfire"), "The campfire is in his build menu")
	assert_has(config_node.upgrade_targets("campfire"), "brazier", "and stone raises it into the brazier (GAME-DESIGN 6.0)")
	fires.append("brazier")
	var camp: Dictionary = config_node.BUILDINGS["campfire"]
	var brazier: Dictionary = config_node.BUILDINGS["brazier"]
	assert_eq(camp["cost"].keys(), ["wood"], "A campfire is wood alone: made with his hands by the first dusk")
	assert_true(brazier["cost"].has("stone"), "A brazier is stone")
	assert_gt(float(brazier["light"]), float(camp["light"]), "and lights further (\"夜里照得更远\")")
	for type_id in fires:
		assert_gt(int(config_node.BUILDINGS[type_id]["fuel"]), 0, "%s burns wood every night" % type_id)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	var made: Node = bs._instantiate_building("campfire")
	assert_true(made is Fire, "A fire is made a Fire (Fire.gd)")
	made.free()
	bs.free()

func test_02_it_lights_at_dusk_on_the_nights_wood_and_goes_out_at_first_light() -> void:
	var main = await _level()
	_set_clock(_at("day") + 100.0)
	var fire = _build(main, "campfire")
	var fuel: int = int(config_node.BUILDINGS["campfire"]["fuel"])
	_wood(10)
	fire._tend(1.0)
	assert_false(fire.lit, "By day it is not lit")
	assert_eq(int(game_state_node.resources["wood"]), 10, "and burns nothing")
	_set_clock(_at("dusk") + 1.0)
	fire._tend(1.0)
	assert_true(fire.lit, "At dusk it lights")
	assert_eq(int(game_state_node.resources["wood"]), 10 - fuel, "on its night's wood, from the stock")
	assert_almost_eq(fire.light_radius(), float(config_node.BUILDINGS["campfire"]["light"]), 0.001, "lighting as far as it says")
	_set_clock(_at("night") + 60.0)
	fire._tend(1.0)
	assert_true(fire.lit, "It burns through the night")
	assert_eq(int(game_state_node.resources["wood"]), 10 - fuel, "on the one night's wood")
	_set_clock(_at("day") + 5.0, 2)
	fire._tend(1.0)
	assert_false(fire.lit, "At first light it goes out")
	assert_almost_eq(fire.light_radius(), 0.0, 0.001, "and lights nothing")
	_set_clock(_at("dusk") + 1.0, 2)
	fire._tend(float(_fire_cfg()["retry_seconds"]) + 0.1)
	assert_eq(int(game_state_node.resources["wood"]), 10 - 2 * fuel, "The next night takes its own wood")

func test_03_no_wood_no_fire_until_there_is() -> void:
	var main = await _level()
	_set_clock(_at("day") + 100.0)
	var fire = _build(main, "campfire")
	_wood(0)
	var said: Array = []
	var eb = tree.root.get_node("EventBus")
	var heard := func(f: Node): said.append(f)
	eb.fire_starved.connect(heard)
	_set_clock(_at("dusk") + 1.0)
	fire._tend(1.0)
	assert_false(fire.lit, "With no wood in the stock it does not light")
	assert_eq(said.size(), 1, "and says so")
	fire._tend(float(_fire_cfg()["retry_seconds"]) + 0.1)
	assert_eq(said.size(), 1, "once a night")
	assert_true(String(fire.get_display_info()["status"]) != "", "Its card says why it is dark")
	_wood(int(config_node.BUILDINGS["campfire"]["fuel"]))
	fire._tend(float(_fire_cfg()["retry_seconds"]) + 0.1)
	assert_true(fire.lit, "Wood brought in, it lights")
	assert_eq(int(game_state_node.resources["wood"]), 0, "and burns it")
	eb.fire_starved.disconnect(heard)

func test_04_its_light_is_seen_in_the_night() -> void:
	var main = await _level()
	var fog: FogOfWar = main.fog
	_set_clock(_at("night") + 10.0)
	var fire = _build(main, "campfire", Vector3(-4.0, 0.0, 6.0))
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(30.0, 0.0, 0.0)
	var light: float = float(config_node.BUILDINGS["campfire"]["light"])
	var away: Vector3 = fire.global_position + (fire.global_position - main.current_core.global_position).normalized() * (light - 1.0)
	_wood(0)
	fire._tend(1.0)
	fog._look()
	assert_false(fog.sees(away), "Dark, the ground %.0f m from it is not seen in the night" % (light - 1.0))
	_wood(10)
	fire._tend(float(_fire_cfg()["retry_seconds"]) + 0.1)
	fog._look()
	assert_true(fog.sees(away), "Lit, it is: its light is seen as far as it reaches")

func test_05_the_night_is_short_sighted_and_fire_is_what_widens_it() -> void:
	var sight: Dictionary = config_node.FOG["sight"]
	var night: float = float(config_node.FOG["night"])
	assert_lt(float(sight["hero"]) * night, float(_torch()["light"]), "His torch lights further than he sees by the moon")
	assert_lt(float(sight["core"]) * night, float(config_node.BUILDINGS["campfire"]["light"]),
		"and a campfire further than the cabin's dim windows")

func test_06_the_torch_is_a_wood_a_minute_and_the_dark_round_him() -> void:
	var main = await _level()
	var hero = main.hero
	var fog: FogOfWar = main.fog
	_wood(5)
	_set_clock(_at("day") + 100.0)
	assert_false(hero.can_light_torch(), "By day there is nothing for a torch to do")
	assert_false(hero.light_torch(), "(and he lights none)")
	_set_clock(_at("night") + 10.0)
	var cost: int = int(_torch()["cost"]["wood"])
	var changed: Array = []
	var eb = tree.root.get_node("EventBus")
	var heard := func(lit: bool): changed.append(lit)
	eb.torch_changed.connect(heard)
	assert_true(hero.light_torch(), "In the dark he lights one")
	assert_eq(int(game_state_node.resources["wood"]), 5 - cost, "for its wood")
	assert_almost_eq(float(hero.torch_left), float(_torch()["seconds"]), 0.001, "and it has its time to burn")
	assert_almost_eq(float(hero.torch_light()), float(_torch()["light"]), 0.001, "lighting as far as it says")
	assert_not_null(hero.find_child("Torch", true, false), "It is in his hand")
	assert_false(hero.can_light_torch(), "One at a time")
	var reach: float = float(_torch()["light"]) - 0.8
	var there: Vector3 = hero.global_position + Vector3(reach, 0.0, 0.0)
	fog._look()
	assert_true(fog.sees(there), "He sees %.1f m off in the night by it" % reach)
	hero._burn_the_torch(float(_torch()["seconds"]) + 0.5)
	assert_almost_eq(float(hero.torch_left), 0.0, 0.001, "It burns out")
	assert_almost_eq(float(hero.torch_light()), 0.0, 0.001, "and lights nothing")
	await wait_physics_frames(2)
	assert_null(hero.find_child("Torch", true, false), "and is gone from his hand")
	assert_eq(changed, [true, false], "Lit and burnt out, each said")
	eb.torch_changed.disconnect(heard)
	fog._look()
	assert_false(fog.sees(there), "Burnt out, the dark closes in again")

func test_07_the_torch_dims_before_it_goes_out() -> void:
	var main = await _level()
	var hero = main.hero
	_wood(5)
	_set_clock(_at("night") + 10.0)
	hero.light_torch()
	var fade: float = float(_torch()["fade_seconds"])
	hero._burn_the_torch(float(_torch()["seconds"]) - fade * 0.5)
	assert_almost_eq(float(hero.torch_light()), float(_torch()["light"]) * 0.5, 0.01, "Halfway into its last seconds it lights half as far")

func test_08_its_tile_comes_with_the_first_dusk_and_stays_and_build_does_not_move() -> void:
	var main = await _level()
	var hud = main.hud
	var tiles: HeroCommands = hud.hero_commands
	_wood(5)
	_set_clock(_at("day") + 100.0)
	tiles.refresh()
	await wait_physics_frames(2)
	assert_false(tiles.torch_button.visible, "Before the first dusk there is no torch tile")
	var build_at: Vector2 = _place(tiles.build_button)
	_set_clock(_at("dusk") + 1.0)
	tiles.refresh()
	await wait_physics_frames(2)
	assert_true(tiles.torch_button.visible, "At dusk it is there")
	assert_false(tiles.torch_button.disabled, "to be pressed, with wood in the stock")
	assert_lt(_place(tiles.torch_button).x, _place(tiles.build_button).x, "to the left of Build")
	assert_eq(_place(tiles.build_button), build_at, "Build has not moved")
	tiles.torch_pressed.emit()
	assert_gt(float(main.hero.torch_left), 0.0, "Pressed, he lights one")
	tiles.refresh()
	assert_true(tiles.torch_button.disabled, "and it cannot be pressed while one burns")
	var badge: Label = tiles.torch_button.get_node("Badge") as Label
	assert_eq(badge.text, str(int(ceil(float(main.hero.torch_left)))), "its badge the seconds it has left")
	var keys: Array = config_node.CONTROLS["command_keys"]
	assert_eq(int(tiles.torch_button.shortcut.events[0].keycode), int(keys[1]),
		"The first command to come after Build (nothing cooked yet), the second key lights it")
	# Come, it stays: by day greyed out, not gone, so nothing to its left moves (v0.6 round four).
	var torch_at: Vector2 = _place(tiles.torch_button)
	_set_clock(_at("day") + 100.0, 2)
	tiles.refresh()
	await wait_physics_frames(2)
	assert_true(tiles.torch_button.visible, "By day it is still there")
	assert_true(tiles.torch_button.disabled, "greyed out")
	assert_eq(_place(tiles.torch_button), torch_at, "where it was")

## Where the corner lays `btn` out, on the screen: not where it is drawn while it grows in (UiKit.come_in).
func _place(btn: Control) -> Vector2:
	return (btn.get_parent() as Control).global_position + btn.position

func test_08b_the_tile_answers_at_once() -> void:
	# The debug-agent's check 17: pressed the moment wood came in, the first press on 3 was lost -- the
	# tile was still greyed out until its next refresh; and it came up a moment after the dusk was said.
	var main = await _level()
	var tiles: HeroCommands = main.hud.hero_commands
	tiles.set_process(false)       # no refresh on its clock: only what changes it
	_wood(0)
	_set_clock(_at("day") + 100.0)
	tiles.refresh()
	assert_false(tiles.torch_button.visible, "(before the first dusk, no tile)")
	_set_clock(_at("dusk") + 1.0)
	assert_true(tiles.torch_button.visible, "The dusk come, the tile is there at once")
	assert_true(tiles.torch_button.disabled, "(no wood: nothing to press)")
	game_state_node.add_resources({"wood": 3})
	assert_false(tiles.torch_button.disabled, "Wood in, it can be pressed at once")
	tiles.set_process(true)

func test_09_the_build_menu_says_what_a_fire_does() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	stock_everything()
	panel._show_build_detail("campfire")
	var said: String = String(panel.status_label.text)
	var row: Dictionary = config_node.BUILDINGS["campfire"]
	assert_true(said.contains("%.0f" % float(row["light"])), "How far it lights: %s" % said)
	assert_true(said.contains(str(int(row["fuel"]))), "and the wood it burns a night")

func test_10_the_first_dusk_says_what_fire_is_for() -> void:
	var main = await _level()
	var hud = main.hud
	_set_clock(_at("day") + 100.0)
	_set_clock(_at("dusk") + 1.0)
	var said: String = String(hud.hint_label.text) if "hint_label" in hud and hud.hint_label else ""
	assert_true(said.contains(tr("BUILDING_CAMPFIRE_NAME").to_lower()) or said.contains(tr("BUILDING_CAMPFIRE_NAME")),
		"The first dusk tells him to build a campfire: %s" % said)
	_set_clock(_at("day") + 5.0, 2)
	_set_clock(_at("dusk") + 1.0, 2)
	var then: String = String(hud.hint_label.text) if "hint_label" in hud and hud.hint_label else ""
	assert_eq(then, tr("HINT_DUSK"), "later dusks say only what the raiders do")

func test_13_a_campfire_is_in_nobodys_way_and_a_brazier_is() -> void:
	# The player's report, 2026-09-29: "camp fire造着会挡住人的路，让campfire不block比较make sense".
	var main = await _level()
	var fire = _build(main, "campfire")
	fire.complete_construction()
	var stone = _build(main, "brazier", Vector3(3.0, 0.0, 3.0))
	stone.complete_construction()
	for layer in [int(config_node.LAYER_BUILDING), int(config_node.LAYER_WALL), int(config_node.LAYER_GATE)]:
		assert_eq(int(fire.collision_layer) & layer, 0, "A campfire is on no layer anybody is stopped by")
	assert_ne(int(fire.collision_layer) & int(config_node.LAYER_PICK), 0, "(it can still be pointed at)")
	assert_ne(int(stone.collision_layer) & int(config_node.LAYER_BUILDING), 0, "A brazier, stone, stands in the way")
	main.nav_maps.rebake()
	await wait_physics_frames(3)
	var at: Vector3 = fire.global_position
	var west: Vector3 = at + Vector3(-2.5, 0.0, 0.0)
	var east: Vector3 = at + Vector3(2.5, 0.0, 0.0)
	for kind in [NavMaps.For.HERO, NavMaps.For.RAID]:
		var route: PackedVector3Array = main.nav_maps.path(west, east, kind)
		var length: float = 0.0
		for i in range(1, route.size()):
			length += route[i - 1].distance_to(route[i])
		assert_lt(length, west.distance_to(east) * 1.05, "The way across its cell is straight across it (%s)" % kind)

func test_14_a_raider_walks_over_a_campfire_too() -> void:
	# The debug-agent's BUG-026: the Hero stepped straight over a campfire, and a Coelophysis sent across it went a
	# metre round (1.20 m from its middle at the nearest). A campfire's ring is nobody's target now either
	# (Dino._is_target_valid), and nothing is carved or steered round for it.
	var main = await _level()
	main.wave_manager.auto_raid_enabled = false
	var fire = _build(main, "campfire", Vector3(-3.0, 0.0, 5.0))
	fire.complete_construction()
	main.nav_maps.rebake()
	await wait_physics_frames(3)
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(18.0, 0.0, -14.0)
	var at: Vector3 = fire.global_position
	var raptor = load(String(config_node.get_dino_script_path("raptor"))).new()
	raptor.setup("raptor")
	var road: Array[Vector3] = [at + Vector3(4.0, 0.0, 0.0), at + Vector3(8.0, 0.0, 0.0)]
	raptor.waypoints = road
	raptor.position = at + Vector3(-4.0, 0.0, 0.0)
	main.dinos_container.add_child(raptor)
	raptor.setup("raptor")
	var nearest: float = INF
	for i in 300:
		await wait_physics_frames(1)
		nearest = minf(nearest, Vector2(raptor.global_position.x - at.x, raptor.global_position.z - at.z).length())
		if raptor.global_position.x > at.x + 3.0:
			break
	assert_gt(raptor.global_position.x, at.x + 3.0, "(it got across)")
	assert_lt(nearest, 0.5, "A raider walks over a campfire's ring as he does, not round it (%.2f m from its middle)" % nearest)

func test_15_a_fire_is_heard_crackling_while_it_burns() -> void:
	# Sound polish (the player, 2026-09-30: "你有什么界面和声音的精做就开始吧"): a lit fire crackles where it
	# is (Config.SOUNDS.fire_crackle), heard near; out, it is still.
	var main = await _level()
	var spec: Dictionary = config_node.SOUNDS["sounds"]["fire_crackle"]
	var fire = _build(main, "campfire")
	_wood(10)
	_set_clock(_at("dusk") + 1.0)
	fire._tend(1.0)
	assert_true(fire.lit, "(lit at dusk)")
	var crackle: AudioStreamPlayer3D = fire.get_node_or_null("Crackle") as AudioStreamPlayer3D
	assert_not_null(crackle, "A lit fire has its crackle")
	if crackle == null:
		return
	assert_true(crackle.playing, "and it is crackling")
	assert_almost_eq(crackle.max_distance, float(spec["reach"]), 0.01, "heard as far as it says, and no further")
	_set_clock(_at("day") + 5.0, 2)
	fire._tend(1.0)
	assert_false(fire.lit, "(out at first light)")
	assert_false(crackle.playing, "Out, it is still")
