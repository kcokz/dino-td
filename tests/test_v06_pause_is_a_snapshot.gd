# res://tests/test_v06_pause_is_a_snapshot.gd
# v0.6 round three: "pause就得像take snapshot一样，不能有任何状态在改变，我发现这个逻辑没写好，应该写成每个
# 单位都继承的，之后写新的单位都可以直接继承，我就发现pause的时候cabin的塔还在进攻恐龙，有的恐龙还在抽搐".
#
# The pause was a flag each unit asked for itself (GameState.is_paused), and what did not ask went
# on: the cabin's gun fires on a timer of its own, and the animations played on. Now the flag is
# the engine's pause: the tree is paused, and everything in the level that does not say otherwise
# holds where it is -- a unit added later too, with nothing of its own to check (Main pauses every
# child of the level unless it says otherwise). What answers while paused says so: the interface,
# the camera and the player's orders (Main), the interface's sounds.
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
	if game_state_node != null:
		game_state_node.is_paused = false
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

## One of the map's raiders in the level's raid, marching on the cabin from `at`.
func _raider(main: Node, at: Vector3) -> Node:
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var d = load(String(config_node.get_dino_script_path(species))).new()
	main.dinos_container.add_child(d)
	d.setup(species)
	d.global_position = at
	d.set_waypoints([main.current_core.global_position])
	return d

func test_01_paused_the_world_holds_and_the_interface_answers() -> void:
	var main = await _level()
	var d = _raider(main, main.current_core.global_position + Vector3(0.0, 0.0, -12.0))
	await wait_physics_frames(10)
	game_state_node.set_paused(true)
	assert_true(bool(game_state_node.is_paused), "Paused")
	assert_true(tree.paused, "and it is the engine's pause")
	for node in [main.hero, d, main.current_core, main.wave_manager, main.buildings_container, main.dinos_container]:
		assert_false(node.can_process(), "%s holds" % node.name)
	assert_true(main.can_process(), "The camera and the player's orders answer")
	assert_true(main.hud.can_process(), "and so does the interface")
	var fx: Node = tree.root.get_node_or_null("Fx")
	if fx:
		assert_true(fx.can_process(), "Its sounds answer a click")
		assert_false(fx.get_node("WorldSound").can_process(), "while the world's hold, mid-note")
	var held: Vector3 = d.global_position
	var hero_at: Vector3 = main.hero.global_position
	await wait_physics_frames(30)
	assert_almost_eq(d.global_position.distance_to(held), 0.0, 0.0001, "The raid stands exactly where it was")
	assert_almost_eq(main.hero.global_position.distance_to(hero_at), 0.0, 0.0001, "and so does he")
	game_state_node.set_paused(false)
	assert_false(tree.paused, "Unpaused")
	await wait_physics_frames(20)
	assert_gt(d.global_position.distance_to(held), 0.05, "and it marches on")

func test_02_what_is_added_later_holds_too_without_a_line_of_its_own() -> void:
	# "之后写新的单位都可以直接继承": a new kind of thing in the level pauses because it is in the level.
	var main = await _level()
	game_state_node.is_paused = true
	var late := Node3D.new()
	main.add_child(late)
	assert_false(late.can_process(), "Something new in the level holds")
	var d = _raider(main, main.current_core.global_position + Vector3(0.0, 0.0, -12.0))
	assert_false(d.can_process(), "and a raider that came in during the pause")
	var asks := Control.new()
	asks.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(asks)
	assert_true(asks.can_process(), "Only what says so answers -- as the interface does")

func test_03_the_cabins_gun_holds_its_fire() -> void:
	# The report: paused, the cabin's gun went on shooting the raid (its fire timer ran on).
	var main = await _level()
	main.hero.process_mode = Node.PROCESS_MODE_DISABLED
	main.hero.global_position = main.current_core.global_position + Vector3(20.0, 0.0, 20.0)
	var reach: float = float(config_node.BUILDINGS["core"]["range"])
	# In the gun's reach from the start. Not disabled: a disabled body is taken out of the physics
	# the gun sees by -- a pause is not (it holds everything where it is, the bodies included).
	var d = _raider(main, main.current_core.global_position + Vector3(0.0, 0.0, config_node.get_building_half("core").y + reach * 0.4))
	await wait_physics_frames(1)
	game_state_node.is_paused = true
	var hp: float = d.current_hp
	await wait_physics_frames(int(4.0 / float(config_node.BUILDINGS["core"]["fire_rate"]) * float(Engine.physics_ticks_per_second)))
	assert_eq(d.current_hp, hp, "Paused, the cabin's gun does not fire")
	game_state_node.is_paused = false
	for i in range(int(6.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if not is_instance_valid(d) or d.current_hp < hp:
			break
	assert_true(not is_instance_valid(d) or d.current_hp < hp, "Unpaused, it does")
