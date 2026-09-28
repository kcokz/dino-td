# res://tests/test_v06_boss_bar.gd
# v0.6 round three: "往精致游戏上靠近，比如学习暗黑破坏神4的那种界面风格，或者艾尔登环，界面质感在于细节".
#
# Those games give a boss its own bar. Here, when a leader or the map's boss takes the field
# (EventBus.boss_arrived), its name and a long bar run low across the field (BossBar): full on
# arrival; a hit leaves the part it took lit a moment (Config.THEME.boss_trail_hold) before it
# drains; when it falls the empty bar stays a moment (boss_bar_linger) and goes; an ordinary
# raider brings none.
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
	unlock_all()

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

## One of the map's animals, standing still where it is put, announced the way WaveManager
## announces a boss when `boss`.
func _animal(main: Node, species: String, boss: bool) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	main.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.global_position = main.hero.global_position + Vector3(8.0, 0.0, 8.0)
	var eb = tree.root.get_node("EventBus")
	eb.dino_spawned.emit(d)
	if boss:
		eb.boss_arrived.emit(d)
	return d

## Frames go by until `done` says so, or twice `seconds` of real time and a second more.
func _until(done: Callable, seconds: float) -> void:
	var give_up: int = Time.get_ticks_msec() + int((seconds * 2.0 + 1.0) * 1000.0)
	while not done.call() and Time.get_ticks_msec() < give_up:
		await wait_frames(1)

func test_01_no_bar_until_a_boss_comes() -> void:
	var main = await _level()
	var bar = main.hud.boss_bar
	assert_not_null(bar, "The HUD has a boss's bar")
	assert_false(bar.visible, "and shows none on a quiet field")
	_animal(main, String(config_node.map_data()["raiders"].keys()[0]), false)
	await wait_frames(2)
	assert_false(bar.visible, "nor for an ordinary raider")

func test_02_a_boss_comes_with_its_name_and_a_full_bar() -> void:
	var main = await _level()
	var species: String = String(config_node.map_data()["boss"])
	_animal(main, species, true)
	await wait_frames(2)
	var bar = main.hud.boss_bar
	assert_true(bar.visible, "The map's boss is out: its bar shows")
	assert_eq(bar.name_label.text, String(config_node.get_dino_name(species)), "under its own name")
	assert_almost_eq(bar.ratio, 1.0, 0.001, "full")
	assert_eq((UiTheme.get_theme().get_stylebox("fill", "BossLifeBar") as StyleBoxTexture).modulate_color,
		config_node.THEME["colors"]["boss"], "in the boss's own crimson, not a low bar's red")

func test_03_a_hit_leaves_a_lit_trail_that_drains() -> void:
	var main = await _level()
	var boss = _animal(main, String(config_node.map_data()["minor_boss"]), true)
	await wait_frames(2)
	var bar = main.hud.boss_bar
	boss.take_damage(boss.max_hp * 0.5)
	await wait_frames(2)
	assert_almost_eq(bar.ratio, 0.5, 0.01, "Hit for half, half is left")
	assert_gt(bar.trail, bar.ratio + 0.1, "and what the blow took is still lit behind it")
	var wait: float = float(config_node.THEME["boss_trail_hold"]) + 1.0 / float(config_node.THEME["boss_trail_drain"])
	await _until(func(): return bar.trail <= bar.ratio + 0.0001, wait)
	assert_almost_eq(bar.trail, bar.ratio, 0.001, "A moment later it has drained down to what is left")

func test_04_fallen_its_bar_stays_a_moment_and_goes() -> void:
	var main = await _level()
	var boss = _animal(main, String(config_node.map_data()["boss"]), true)
	await wait_frames(2)
	var bar = main.hud.boss_bar
	boss.take_damage(boss.max_hp * 2.0)
	await wait_frames(2)
	assert_true(bar.visible, "Down, its bar is still there a moment")
	assert_almost_eq(bar.ratio, 0.0, 0.001, "empty")
	var gone: float = float(config_node.THEME["boss_bar_linger"]) + float(config_node.THEME["fade_seconds"])
	await _until(func(): return not bar.visible, gone)
	assert_false(bar.visible, "and then goes")

func test_05_the_last_to_come_is_followed_then_whoever_still_stands() -> void:
	var main = await _level()
	var leader = _animal(main, String(config_node.map_data()["minor_boss"]), true)
	var boss_species: String = String(config_node.map_data()["boss"])
	var boss = _animal(main, boss_species, true)
	await wait_frames(2)
	var bar = main.hud.boss_bar
	assert_eq(bar.boss, boss, "Two out: the bar is the last to come")
	boss.take_damage(boss.max_hp * 2.0)
	await wait_frames(2)
	assert_eq(bar.boss, leader, "It down, the bar is the other still standing")
	assert_eq(bar.name_label.text, String(config_node.get_dino_name(String(config_node.map_data()["minor_boss"]))), "by its name")

func test_06_it_clears_his_corner_and_the_card() -> void:
	# Found at 1280x720: fed, the meal's chip beside his medallion ran under the boss's name.
	var main = await _level()
	var hud = main.hud
	_animal(main, String(config_node.map_data()["boss"]), true)
	hud.fed_chip.visible = true
	hud.fed_label.text = "Fed: +2 max health · walks ×1.2 · 1:20 · and then some more words"
	await wait_frames(3)
	var bar: Rect2 = hud.boss_bar.get_global_rect()
	var corner: Rect2 = hud.find_child("HeroSide", true, false).get_global_rect()
	assert_gt(bar.size.x, 0.0, "The bar has a width")
	assert_false(bar.intersects(corner), "and stays clear of his medallion and the meal chip (%s vs %s)" % [bar, corner])
	assert_false(bar.intersects(hud.option_panel.get_global_rect()), "and of the card")
