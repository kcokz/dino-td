# res://tests/test_v06_how_the_run_was_lost.gd
# The debug-agent's BUG-011: the engineer killed by the nest's guards while he quarried, the cabin at
# 100/100 -- and the defeat screen said "The cabin was destroyed or the hero was killed!". The game
# knows which, and says so: the cabin broken open, or him killed -- by what, when it was at his side
# (Config.HERO.killer_within), and whether it was guarding its nest.
#
# Everything expected is read from Config and the strings.
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

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

## An animal of `kind` at his side, held still: one guarding its nest, or one out raiding.
func _beside_him(main: Node, kind: String, guard: bool) -> Node:
	var path: String = "res://scripts/entities/GuardDino.gd" if guard else String(config_node.get_dino_script_path(kind))
	var d = load(path).new()
	_cleanup_nodes.append(d)
	main.add_child(d)
	d.setup(kind)
	var at: Vector3 = main.hero.global_position + Vector3(1.0, 0.0, 0.0)
	if guard:
		d.setup_post(at)
	d.global_position = at
	d.set_physics_process(false)
	return d

func _title(main: Node) -> String:
	return String(main.hud.result_label.text)

func _details(main: Node) -> String:
	return String(main.hud.details_label.text)

func test_01_the_cabin_broken_open_says_so() -> void:
	var main = await _level()
	var cabin = main.current_core
	cabin.take_damage(cabin.max_hp * 2.0)
	await wait_frames(2)
	assert_eq(String(game_state_node.lost_to), "cabin", "The game knows it was the cabin")
	assert_eq(_title(main), tr("GAME_DEFEAT_TITLE"), "The defeat")
	assert_eq(_details(main), tr("GAME_DEFEAT_CABIN"), "said as the cabin broken open")

func test_02_killed_by_a_guard_it_says_what_and_that_it_guarded_its_nest() -> void:
	var main = await _level()
	var kind: String = "coelophysis"
	_beside_him(main, kind, true)
	main.hero.take_damage(main.hero.max_hp * 2.0)
	await wait_frames(2)
	assert_eq(String(game_state_node.lost_to), "hero", "The game knows it was him")
	assert_eq(_title(main), tr("GAME_DEFEAT_HERO_TITLE"), "He fell")
	assert_eq(_details(main), tr("GAME_DEFEAT_HERO_BY_GUARD") % config_node.get_dino_name(kind),
		"killed by what guards its nest -- named")
	assert_ne(_details(main), tr("GAME_DEFEAT_DESC"), "not the line that said both")

func test_03_killed_by_a_raider_it_says_what() -> void:
	var main = await _level()
	var kind: String = "raptor"
	_beside_him(main, kind, false)
	main.hero.take_damage(main.hero.max_hp * 2.0)
	await wait_frames(2)
	assert_eq(_details(main), tr("GAME_DEFEAT_HERO_BY") % config_node.get_dino_name(kind), "Killed by a raider, named")

func test_04_with_nothing_at_his_side_it_says_he_fell() -> void:
	var main = await _level()
	main.hero.take_damage(main.hero.max_hp * 2.0)
	await wait_frames(2)
	assert_eq(_title(main), tr("GAME_DEFEAT_HERO_TITLE"), "He fell")
	assert_eq(_details(main), tr("GAME_DEFEAT_HERO"), "and that is all it knows")

func test_05_a_new_run_forgets_how_the_last_was_lost() -> void:
	game_state_node.lost_to = "hero"
	game_state_node.hero_killer = {"type": "raptor", "guard": true}
	game_state_node.reset_game()
	assert_eq(String(game_state_node.lost_to), "", "Nothing lost yet")
	assert_true(game_state_node.hero_killer.is_empty(), "nothing killed him")
