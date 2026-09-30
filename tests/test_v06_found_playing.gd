# res://tests/test_v06_found_playing.gd
# What playing the game turned up (v0.6 round three: tools/playtest.gd play:<minutes>, a bot that
# plays the opening through the orders a click gives).
#
# Quarrying stone by the nest, the Hero was bitten from twelve hit points to none by its guards
# while he went on swinging at the rock -- only an idle man hit back -- and nothing on the screen
# said so. Now, bitten at his work, he turns on what bites him, fights what else is in his reach,
# and goes back to the work; and the HUD says he is under attack, once in a while.
#
# Sheltering at the workbench in a raid, he went out after a raptor biting the cabin's back wall
# -- it was in his reach through the wall -- and the pack killed him. Now he fights on his own
# only what is on his side of the wall; to go out is the player's call.
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

func test_01b_bitten_on_his_way_to_work_he_turns_on_it_too() -> void:
	# The debug-agent's BUG-019: sent out at night to cut wood, a phytosaur stood across his way and bit
	# him from ten hit points to none while he walked on the spot, never hitting back.
	var main = await _level()
	var hero = main.hero
	var tree_node: Node = _nearest_tree(main)
	assert_not_null(tree_node, "A tree to cut")
	hero.order_harvest(tree_node)
	await wait_physics_frames(2)
	assert_eq(int(hero.current_state), int(hero.State.MOVING), "(on his way to it)")
	var biter = _raptor_at(main, hero.global_position + Vector3(hero.attack_range * 0.6, 0.0, 0.0))
	await wait_physics_frames(1)
	hero.take_damage(0.5)
	assert_eq(int(hero.current_state), int(hero.State.ATTACKING), "Bitten on his way, he turns on it")
	assert_eq(hero.target_enemy, biter, "on what bit him")
	biter.take_damage(9999.0)
	for i in 10:
		await wait_physics_frames(1)
		if hero.target_resource_node == tree_node:
			break
	assert_eq(hero.target_resource_node, tree_node, "It dead, he goes on to the tree")

func test_02_a_walk_he_was_sent_on_is_not_broken_off() -> void:
	var main = await _level()
	var hero = main.hero
	hero.move_to(hero.global_position + Vector3(6.0, 0.0, 0.0))
	await wait_physics_frames(2)
	_raptor_at(main, hero.global_position + Vector3(hero.attack_range * 0.6, 0.0, 0.0))
	await wait_physics_frames(1)
	hero.take_damage(0.5)
	assert_eq(int(hero.current_state), int(hero.State.MOVING), "Sent somewhere, he keeps going: that is the player's call")

func test_02b_held_on_a_walk_and_bitten_he_turns_on_it_and_walks_on() -> void:
	# The debug-agent's BUG-022: sent home at night past a phytosaur lying across the way at the
	# cabin's end, he walked on the spot and was bitten to death. Held -- walking and getting nowhere
	# for a while -- he turns on what bites him whatever he was sent to do, and walks on after.
	var main = await _level()
	var hero = main.hero
	var to: Vector3 = hero.global_position + Vector3(6.0, 0.0, 0.0)
	hero.move_to(to)
	await wait_physics_frames(2)
	var biter = _raptor_at(main, hero.global_position + Vector3(hero.attack_range * 0.6, 0.0, 0.0))
	await wait_physics_frames(1)
	hero._held_for = float(config_node.HERO["fight_when_held"]) + 0.1
	hero.take_damage(0.5)
	assert_eq(int(hero.current_state), int(hero.State.ATTACKING), "Held on his walk, bitten, he turns on it")
	biter.take_damage(9999.0)
	for i in 10:
		await wait_physics_frames(1)
		if int(hero.current_state) == int(hero.State.MOVING):
			break
	assert_eq(int(hero.current_state), int(hero.State.MOVING), "It dead, he walks on")
	assert_lt(Vector2(hero.target_destination.x - to.x, hero.target_destination.z - to.z).length(), 0.3, "where he was going")

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

func test_04_a_drop_that_falls_in_a_wall_lands_where_he_can_pick_it_up() -> void:
	# A raptor killed against the fence dropped its bone in the fence's cell, and he walked on the
	# spot beside it for ever.
	var main = await _level()
	stock_everything()
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.hero.global_position) + Vector2i(4, 4)
	var wall = main.build_system.place_at("wall", cell, main.buildings_container, false)
	assert_not_null(wall, "A section of fence")
	if wall == null:
		return
	if not wall.is_constructed:
		wall.complete_construction()
	main.nav_maps.rebake()
	await wait_frames(8)
	var pile = DropItem.spawn(main, gm.build_cell_to_world(cell), "bone", 1)
	assert_not_null(pile, "The bone falls")
	var at: Vector3 = (pile as Node3D).global_position
	assert_null(gm.building_at_point(at), "not in the fence's cell")
	var reachable: Vector3 = main.nav_maps.closest_point(at, NavMaps.For.HERO)
	assert_lt(Vector2(at.x - reachable.x, at.z - reachable.z).length(), 0.05, "but on ground he walks")
	assert_lt(at.distance_to(gm.build_cell_to_world(cell)), 1.5, "right beside where it fell")

func test_05_a_bitten_fence_shows_its_bar_not_its_name() -> void:
	# In the final wave every bitten section hung "Palisade 2 / 8 HP" in red over itself, overlapping.
	var main = await _level()
	stock_everything()
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.hero.global_position) + Vector2i(3, 5)
	var wall = main.build_system.place_at("wall", cell, main.buildings_container, false)
	if not wall.is_constructed:
		wall.complete_construction()
	wall.take_damage(wall.max_hp * 0.5)
	await wait_frames(1)
	assert_true(wall.status_bar.visible, "Bitten, its bar shows how much is left")
	assert_false(wall.label_3d.visible, "and no words hang over it")
	tree.root.get_node("EventBus").unit_selected.emit(wall)
	await wait_frames(1)
	assert_true(wall.label_3d.visible, "Picked, it says what it is")

func test_06_a_meal_wearing_off_is_not_an_attack() -> void:
	# The warning came up at the start of a game nobody had touched: a meal's boost to his most ran
	# out, and what he had came down with it.
	var main = await _level()
	var hud = main.hud
	var eb = tree.root.get_node("EventBus")
	eb.hero_hp_changed.emit(12.0, 12.0)
	hud.show_hint("before")
	eb.hero_hp_changed.emit(10.0, 10.0)
	await wait_frames(1)
	assert_eq(String(hud.hint_label.text), "before", "His most coming down with what he has is a meal ending, not a bite")

func test_07_in_the_cabin_he_does_not_go_out_after_what_bites_its_wall() -> void:
	var main = await _level()
	var hero = main.hero
	var cabin = main.current_core
	var room: Vector2 = cabin.room_half()
	# At the west end of the room, clear of the benches, and a raptor at the end wall's other side,
	# in his reach through it.
	hero.global_position = cabin.global_position + Vector3(-room.x + 0.4, 0.0, 0.0)
	cabin.recheck_hero()
	var biter = _raptor_at(main, cabin.global_position + Vector3(-room.x - 0.5, 0.0, 0.0))
	assert_true(cabin.hero_inside, "He is in the cabin")
	assert_false(cabin.is_inside(biter.global_position), "and it is outside")
	assert_lt(hero.global_position.distance_to(biter.global_position), float(hero.attack_range),
		"in his reach but for the wall")
	await wait_physics_frames(10)
	assert_eq(int(hero.current_state), int(hero.State.IDLE), "He stays in")
	assert_null(hero.target_enemy, "and has not taken it on")
	# The same raptor with him outside, the wall not between them: he takes it on.
	hero.global_position = cabin.door_outside()
	cabin.recheck_hero()
	biter.global_position = hero.global_position + Vector3(float(hero.attack_range) * 0.6, 0.0, 0.0)
	await wait_physics_frames(3)
	assert_eq(hero.target_enemy, biter, "Out here he takes on what is in his reach")

func test_08_a_walk_that_gets_him_nowhere_is_given_up() -> void:
	# The player's report, 2026-09-29: "人会一直有跑的动作但会一直卡着进不去" -- held at something his route
	# did not know was in the way, he ran on the spot for good.
	var main = await _level()
	var hero = main.hero
	hero.move_to(hero.global_position + Vector3(6.0, 0.0, 0.0))
	await wait_physics_frames(2)
	assert_eq(int(hero.current_state), int(hero.State.MOVING), "(walking)")
	hero._held_for = float(config_node.HERO["give_up_after"]) - 0.1
	assert_false(hero._give_up_the_walk(), "Not before he has got nowhere the while")
	hero._held_for = float(config_node.HERO["give_up_after"]) + 0.1
	assert_true(hero._give_up_the_walk(), "Getting nowhere that long on a plain walk, he gives it up")
	assert_eq(int(hero.current_state), int(hero.State.IDLE), "and stands")

func test_09_what_is_by_the_cabin_is_built_from_outside_it() -> void:
	# The player's report, 2026-09-29: "造上面两个bow的时候人会走到cabin里造它们".
	var main = await _level()
	stock_everything()
	var gm = main.grid_manager
	var cabin = main.current_core
	var c: Vector2i = gm.world_to_build_cell(cabin.global_position)
	var half: Vector2 = config_node.get_building_half("core")
	var bow = main.build_system.place_at("trip_bow", Vector2i(c.x + int(ceil(half.x)), c.y), main.buildings_container, true)
	assert_not_null(bow, "(a trap goes down against the cabin's end)")
	if bow == null:
		return
	main.nav_maps.rebake()
	await wait_physics_frames(3)
	var hero = main.hero
	hero.global_position = bow.global_position + Vector3(4.0, 0.0, 0.0)
	hero.order_build(bow, true)
	assert_false(hero.current_path.is_empty(), "(he has a way there)")
	var end: Vector3 = hero.current_path[hero.current_path.size() - 1]
	assert_gt(float(config_node.gap_to_building(end, "core", cabin.global_position)), 0.0,
		"He stands outside the cabin to build what is outside it, not in its room through the wall")
