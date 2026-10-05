# res://tests/test_v07_the_save.gd
# The player, 2026-10-04: "需要加一个保存功能游戏的功能".
#
# The run saved in a lull -- no raid, no raider or prowler about, not over -- from the pause menu, and played on from the
# start screen's Continue: the level built afresh for the same game and laid over with what was saved (SaveGame). What
# comes back: the stock, the tools, the clock, the beacon, the cabin's power; him; the cabin; every building, built or not,
# with its health, facing and ammunition; what is left in the trees; the piles on the ground; the nests' guards that
# lived; the mist seen through; the benches' work; the next raid's clock; the journal; the dice.
#
# The tests' save is their own (tests/test_runner.gd: SaveGame.path_override), never the player's.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	_forget_the_save()
	if game_state_node != null:
		game_state_node.game = {}
		game_state_node.reset_game()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	_forget_the_save()
	if game_state_node != null:
		game_state_node.is_paused = false
		game_state_node.game = {}
		game_state_node.reset_game()
	super.after_each()

func _forget_the_save() -> void:
	if FileAccess.file_exists(SaveGame.path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path()))

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	await nav_settled(main)
	return main

func _put(main: Node, type_id: String, near: Vector3, blueprint: bool = false, facing: int = 0) -> Node:
	var cell: Vector2i = main.grid_manager.world_to_build_cell(main.current_core.global_position + near)
	return main.build_system.place_at(type_id, cell, main.buildings_container, blueprint, facing)

func _count_seen(main: Node) -> int:
	var n: int = 0
	for b in main.fog.seen_cells():
		n += int(b)
	return n

func test_01_saved_only_in_a_lull() -> void:
	assert_ne(SaveGame.path(), "user://save.json", "(the tests write their own save, never the player's)")
	var main = await _level()
	assert_eq(SaveGame.why_not(main), "", "A quiet moment: it can be saved")
	main.wave_manager.is_wave_active = true
	assert_eq(SaveGame.why_not(main), "SAVE_NOT_RAID", "Not with a raid out")
	main.wave_manager.is_wave_active = false
	var raider = load(String(config_node.get_dino_script_path("coelophysis"))).new()
	raider.setup("coelophysis")
	main.dinos_container.add_child(raider)
	raider.setup("coelophysis")
	raider.global_position = main.current_core.global_position + Vector3(20.0, 0.0, 20.0)
	assert_eq(SaveGame.why_not(main), "SAVE_NOT_DINOS", "Not with a raider about")
	raider.get_parent().remove_child(raider)
	raider.free()
	assert_gt(tree.get_nodes_in_group("dinos").size(), 0, "(a nest's guards are about)")
	assert_eq(SaveGame.why_not(main), "", "and they are part of the valley")
	game_state_node.is_game_over = true
	assert_eq(SaveGame.why_not(main), "SAVE_NOT_OVER", "Not when the run is over")
	assert_false(SaveGame.save(main), "and nothing is written")
	assert_false(SaveGame.exists(), "(no file)")
	game_state_node.is_game_over = false

func test_02_the_run_comes_back_as_it_was() -> void:
	var main = await _level()
	var gs = game_state_node
	stock_everything(200)
	# The run, moved on.
	var bow: Node = _put(main, "bow_tower", Vector3(8.0, 0.0, -6.0))
	assert_not_null(bow, "(a bow tower)")
	bow.ammo_type = "arrow_wood"
	bow.uses_left = 7
	bow.current_hp = bow.max_hp * 0.5
	var wall: Node = _put(main, "wall", Vector3(-6.0, 0.0, 6.0), false, 1)
	var fire: Node = _put(main, "campfire", Vector3(6.0, 0.0, 6.0))
	fire._paid_night = 2
	var half_built: Node = _put(main, "drop_tower", Vector3(-9.0, 0.0, -7.0), true)
	half_built.build_progress = 0.4
	var tree_node: Node = null
	for n in main.resource_nodes_container.get_children():
		if String(n.resource_type) == "wood":
			tree_node = n
			break
	tree_node.current_amount = 2
	# Out of his way, or he would pick it up.
	DropItem.spawn(main, main.current_core.global_position + Vector3(-12.0, 0.0, 10.0), "bone", 3)
	var guard0: Node = main.current_nest.guard_dinos[0]
	guard0.get_parent().remove_child(guard0)
	guard0.free()
	main.fog.mark_seen(main.current_core.global_position + Vector3(25.0, 0.0, 0.0), 6.0)

	var wb = main.current_core.station("workbench")
	wb.active_recipe = "arrow_wood"
	wb.progress = 2.0
	main.wave_manager.raid_timer = 42.0
	main.hud._journal = [{"title": "JOURNAL_CRASH_TITLE", "text": "JOURNAL_CRASH_TEXT", "args": []}]
	gs.grant_unlock(String(config_node.RECIPES["stone_pick"]["unlocks"]))
	gs.resources["wood"] = 37
	gs.resources["bone"] = 5
	gs.day_clock = float(config_node.DAY["length"]) + 100.0
	gs.power_used = 500.0
	gs.beacon_steps = 1
	# A stage mended tells where the next part's wreck lies (Main._on_wreck_located), as the game does on the bus.
	for n in main.resource_nodes_container.get_children():
		if config_node.RESOURCE_NODES.get(String(n.resource_type), {}).has("found") and gs.wreck_located(String(n.resource_type)):
			main._on_wreck_located(String(n.resource_type))
	main.current_core.current_hp = 300.0
	var hero = main.hero
	hero.global_position = main.current_core.global_position + Vector3(3.0, 0.0, 8.0)
	hero.current_hp = 30.0
	hero.stamina = 22.0
	var dice_next: int = 0
	main.fog._look()
	var seen_before: int = _count_seen(main)
	assert_true(SaveGame.save(main), "Saved")
	var copy := RandomNumberGenerator.new()
	copy.state = gs.rng.state
	dice_next = copy.randi()
	var saved_seed: int = gs.run_seed
	# A fresh start, and the save laid over a level built afresh.
	main.get_parent().remove_child(main)
	main.free()
	_cleanup_nodes.clear()
	gs.reset_game()
	var again = await _level()
	SaveGame.apply(again, SaveGame.read())
	var seen_after: int = _count_seen(again)
	await wait_frames(2)
	assert_eq(int(gs.resources["wood"]), 37, "The stock as it was")
	assert_eq(int(gs.resources["bone"]), 5, "")
	assert_true(gs.has_unlock(String(config_node.RECIPES["stone_pick"]["unlocks"])), "the pick made")
	assert_almost_eq(float(gs.day_clock), float(config_node.DAY["length"]) + 100.0, 0.5, "the clock")
	assert_eq(int(gs.day_number()), 2, "day 2")
	assert_almost_eq(float(gs.power_used), 500.0, 0.5, "the cabin's power used")
	assert_eq(int(gs.beacon_steps), 1, "the beacon's stage")
	assert_almost_eq(float(again.current_core.current_hp), 300.0, 0.001, "the cabin's health")
	assert_true(again.hero.global_position.distance_to(again.current_core.global_position + Vector3(3.0, 0.0, 8.0)) < 0.1, "him where he stood")
	assert_almost_eq(float(again.hero.current_hp), 30.0, 0.001, "his health")
	assert_almost_eq(float(again.hero.stamina), 22.0, 0.05, "his stamina")
	var by_type: Dictionary = {}
	for b in again.buildings_container.get_children():
		if b != again.current_core and "building_type" in b:
			by_type[String(b.building_type)] = b
	assert_true(by_type.has("bow_tower") and by_type.has("wall") and by_type.has("campfire") and by_type.has("drop_tower"),
		"Every building put up again: %s" % str(by_type.keys()))
	if by_type.has("bow_tower"):
		var b2: Node = by_type["bow_tower"]
		assert_eq(String(b2.ammo_type), "arrow_wood", "the bow tower's arrows")
		assert_eq(int(b2.uses_left), 7, "as many")
		assert_almost_eq(float(b2.current_hp), float(b2.max_hp) * 0.5, 0.01, "its health")
		assert_true(bool(b2.is_constructed), "built")
	if by_type.has("wall"):
		assert_eq(int(by_type["wall"].facing), 1, "the fence's facing")
	if by_type.has("campfire"):
		assert_eq(int(by_type["campfire"]._paid_night), 2, "tonight's wood paid, not again")
	if by_type.has("drop_tower"):
		assert_false(bool(by_type["drop_tower"].is_constructed), "the drop tower still a blueprint")
		assert_almost_eq(float(by_type["drop_tower"].build_progress), 0.4, 0.001, "this far built")
	var tree_again: Node = null
	for n in again.resource_nodes_container.get_children():
		if String(n.resource_type) == "wood":
			tree_again = n
			break
	assert_eq(int(tree_again.current_amount), 2, "The tree as much cut")
	var piles: Array = tree.get_nodes_in_group(DropItem.GROUP).filter(func(p): return String(p.resource_type) == "bone")
	assert_eq(piles.size(), 1, "the pile of bone on the ground")
	assert_true(piles.size() == 1 and int(piles[0].amount) == 3, "three of it")
	var alive: int = 0
	for g in again.current_nest.guard_dinos:
		if g != null and is_instance_valid(g):
			alive += 1
	assert_eq(alive, int(config_node.NEST_GUARDS["count"]) - 1, "The guard that was killed, gone still")
	assert_eq(seen_after, seen_before, "the mist seen through")
	var wb2 = again.current_core.station("workbench")
	assert_eq(String(wb2.active_recipe), "arrow_wood", "the bench's work")
	assert_almost_eq(float(wb2.progress), 2.0, 0.001, "as far on")
	assert_almost_eq(float(again.wave_manager.raid_timer), 42.0, 0.001, "the next raid's clock")
	assert_eq(again.hud.journal_entries().size(), 1, "the journal")
	assert_eq(gs.run_seed, saved_seed, "the run's seed")
	assert_eq(gs.rng.randi(), dice_next, "and its dice where they had got to")

func test_03_continue_on_the_start_screen_while_there_is_a_save() -> void:
	var main = await _level()
	main.hud.show_start_screen(false)
	await wait_frames(1)
	var screen = main.hud.start_screen
	assert_false(screen.continue_btn.visible, "No save: no Continue")
	assert_eq(screen.campaign_btn.theme_type_variation, &"AccentButton", "our game the lit one")
	screen.close()
	game_state_node.is_paused = false
	assert_true(SaveGame.save(main), "(saved)")
	main.hud.show_start_screen(false)
	await wait_frames(1)
	assert_true(screen.continue_btn.visible, "A save: Continue")
	assert_eq(screen.continue_btn.theme_type_variation, &"AccentButton", "lit")
	assert_true(screen._continue_note.text.contains(str(int(game_state_node.day_number()))), "with its day: %s" % screen._continue_note.text)
	screen.close()

func test_04_the_pause_menu_saves_and_says_why_it_cannot() -> void:
	var main = await _level()
	var menu = main.hud.pause_menu
	main.hud.toggle_pause_menu()
	await wait_frames(1)
	assert_true(menu.save_btn.is_visible_in_tree(), "Save on the menu")
	assert_false(menu.save_btn.disabled, "and it can be pressed")
	menu._on_save_pressed()
	assert_true(SaveGame.exists(), "Pressed, the run is saved")
	assert_eq(menu.save_note.text, tr("SAVE_DONE") % int(game_state_node.day_number()), "and it says so")
	main.hud.toggle_pause_menu()
	main.wave_manager.is_wave_active = true
	main.hud.toggle_pause_menu()
	await wait_frames(1)
	assert_true(menu.save_btn.disabled, "With a raid on, greyed out")
	assert_eq(menu.save_note.text, tr("SAVE_NOT_RAID"), "and it says why")
	main.wave_manager.is_wave_active = false
	main.hud.toggle_pause_menu()

## Continued: the save waiting for the next level built (GameState.pending_load, as SaveGame.continue_game leaves it),
## which lays it over itself as it is built, and opens on the run as it was -- not on the crash, not on the start screen.
func test_05_continued_the_level_built_next_is_the_saved_run() -> void:
	var main = await _level()
	stock_everything(200)
	var gs = game_state_node
	gs.resources["wood"] = 61
	gs.day_clock = float(config_node.DAY["length"]) * 2.0 + 30.0
	main.current_core.current_hp = 250.0
	assert_true(SaveGame.save(main), "(saved)")
	main.get_parent().remove_child(main)
	main.free()
	_cleanup_nodes.clear()
	gs.reset_game()
	gs.pending_load = SaveGame.read()
	var again = await _level()
	assert_true((gs.pending_load as Dictionary).is_empty(), "Laid over, the save is not waiting any more")
	assert_eq(int(gs.resources["wood"]), 61, "The run as it was: the stock")
	assert_eq(int(gs.day_number()), 3, "the day")
	assert_almost_eq(float(again.current_core.current_hp), 250.0, 0.001, "the cabin")
	assert_false(again.station_jump.is_running(), "no crash")
	assert_true(again.hud.is_objective_given(), "and the goal his")
