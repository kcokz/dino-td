# res://tests/test_v06_found_playing.gd
# What playing the game turned up (v0.6 round three: tools/playtest.gd play:<minutes>, a bot that
# plays the opening through the orders a click gives).
#
# Quarrying stone by the nest, the Hero was bitten from twelve hit points to none by its guards
# while he went on swinging at the rock -- only an idle man hit back -- and nothing on the screen
# said so. Now, bitten at his work, he turns on what bites him, fights what else is in his reach,
# and goes back to the work; and the HUD says he is under attack, once in a while.
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

func _nearest_tree(main: Node) -> Node:
	var best: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood" and main.hero.can_harvest(n):
			if best == null or (n as Node3D).global_position.distance_to(main.hero.global_position) \
					< (best as Node3D).global_position.distance_to(main.hero.global_position):
				best = n
	return best

func _raptor_at(main: Node, at: Vector3) -> Node:
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	main.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.global_position = at
	return d

func test_01_bitten_at_his_work_he_turns_on_it_and_goes_back_to_it() -> void:
	var main = await _level()
	var hero = main.hero
	var tree_node: Node = _nearest_tree(main)
	assert_not_null(tree_node, "A tree to cut")
	hero.order_harvest(tree_node)
	for i in range(int(8.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if int(hero.current_state) == int(hero.State.HARVESTING):
			break
	assert_eq(int(hero.current_state), int(hero.State.HARVESTING), "He is at the tree")
	var biter = _raptor_at(main, hero.global_position + Vector3(hero.attack_range * 0.6, 0.0, 0.0))
	await wait_physics_frames(1)
	hero.take_damage(0.5)
	assert_eq(int(hero.current_state), int(hero.State.ATTACKING), "Bitten, he turns on it")
	assert_eq(hero.target_enemy, biter, "on what bit him")
	biter.take_damage(9999.0)
	for i in 10:
		await wait_physics_frames(1)
		if hero.target_resource_node == tree_node:
			break
	assert_eq(hero.target_resource_node, tree_node, "It dead, he goes back to the tree")

func test_02_a_walk_he_was_sent_on_is_not_broken_off() -> void:
	var main = await _level()
	var hero = main.hero
	hero.move_to(hero.global_position + Vector3(6.0, 0.0, 0.0))
	await wait_physics_frames(2)
	_raptor_at(main, hero.global_position + Vector3(hero.attack_range * 0.6, 0.0, 0.0))
	await wait_physics_frames(1)
	hero.take_damage(0.5)
	assert_eq(int(hero.current_state), int(hero.State.MOVING), "Sent somewhere, he keeps going: that is the player's call")

func test_03_the_hud_says_he_is_under_attack_once_in_a_while() -> void:
	var main = await _level()
	var hero = main.hero
	var hud = main.hud
	hero.take_damage(0.5)
	await wait_frames(1)
	var said: String = String(hud.hint_label.text)
	assert_true(hud.hint_toast.visible, "Hurt, it is said on the screen")
	assert_true(said.begins_with(tr("HINT_HERO_HURT").split("(")[0].strip_edges()), "that he is under attack (%s)" % said)
	hud.show_hint("something else")
	hero.take_damage(0.5)
	await wait_frames(1)
	assert_eq(String(hud.hint_label.text), "something else",
		"Not again at the next bite: once in %.0fs" % float(config_node.FEEDBACK["hero_hurt_alert_seconds"]))
