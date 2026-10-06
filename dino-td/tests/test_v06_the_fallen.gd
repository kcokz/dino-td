# res://tests/test_v06_the_fallen.gd
# The debug-agent's BUG-029: a dinosaur killed was gone the frame it died -- its debris and its meat left, and
# nothing of it -- so the death clip the sculpted cast was given (TASK-029) was never seen. Now its body falls
# where it died, lies a while, then sinks into the ground and is gone (Fx.lay_down; Config.FEEDBACK.carcass_*).
# The dinosaur itself still goes at once: nothing hunts, counts or steers round the dead.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var fx_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
		fx_node = tree.root.get_node_or_null("Fx")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()

func after_each() -> void:
	tree.current_scene = null
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

## A level running as the game's scene: Fx lays what is left under the running scene.
func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	tree.current_scene = main
	fx_node._debris_root = null
	return main

## A Coelophysis on open ground in the level, standing.
func _animal(main: Node) -> Node:
	var d = load(String(config_node.get_dino_script_path("coelophysis"))).new()
	main.dinos_container.add_child(d)
	d.setup("coelophysis")
	d.set_physics_process(false)
	d.global_position = cabin_at(main) + Vector3(9.0, 0.0, 9.0)
	return d

func _carcass(main: Node) -> Node3D:
	var home: Node = main.find_child("FxDebris", false, false)
	return home.find_child("Carcass", false, false) as Node3D if home != null else null

## Whether `clip` is the death clip, by any name a model may give it (Config.ANIMATIONS.aliases).
func _is_death(clip: String) -> bool:
	return clip == "death" or (config_node.ANIMATIONS["aliases"]["death"] as Array).has(clip)

func test_01_its_body_falls_where_it_died() -> void:
	var main = await _level()
	var d = _animal(main)
	await wait_frames(3)
	var at: Vector3 = d.global_position
	var before: int = main.dinos_container.get_child_count()
	d.die()
	await wait_frames(2)
	assert_false(is_instance_valid(d), "The dinosaur itself is gone at once, as it always was")
	assert_eq(main.dinos_container.get_child_count(), before - 1, "(and what is left is not among the dinosaurs)")
	var carcass: Node3D = _carcass(main)
	assert_not_null(carcass, "Its body is left")
	if carcass == null:
		return
	var body: Node3D = carcass.find_child("Body", false, false) as Node3D
	assert_not_null(body, "-- the body it had")
	assert_lt(Vector2(body.global_position.x - at.x, body.global_position.z - at.z).length(), 0.3, "where it fell")
	var players: Array = body.find_children("*", "AnimationPlayer", true, false)
	assert_false(players.is_empty(), "(its clips with it)")
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		assert_true(_is_death(String(player.current_animation)), "falling as its death clip has it (%s)" % player.current_animation)
		assert_true(player.is_playing(), "-- and seen falling")
	assert_true(body.find_children("*", "CollisionShape3D", true, false).is_empty() \
		and body.find_children("*", "CollisionObject3D", true, false).is_empty(), "Nothing of it is in anybody's way")
	assert_true(tree.get_nodes_in_group("dinos").filter(func(n: Node) -> bool: return carcass.is_ancestor_of(n)).is_empty(),
		"nor hunted, counted or steered round")

func test_02_it_lies_then_sinks_away() -> void:
	var main = await _level()
	var d = _animal(main)
	await wait_frames(3)
	var ground: float = d.global_position.y
	d.die()
	await wait_frames(1)
	var carcass: Node3D = _carcass(main)
	assert_not_null(carcass, "(its body is left)")
	if carcass == null:
		return
	var player := carcass.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var fall: float = player.current_animation_length
	var lie: float = float(config_node.FEEDBACK["carcass_lie"])
	var sink: float = float(config_node.FEEDBACK["carcass_sink"])
	await wait_seconds(fall + lie * 0.5)
	assert_true(is_instance_valid(carcass), "Fallen, it lies there")
	assert_almost_eq(carcass.global_position.y, ground, 0.01, "on the ground")
	await wait_seconds(lie * 0.5 + sink * 0.6)
	assert_true(is_instance_valid(carcass), "Then it sinks")
	if is_instance_valid(carcass):
		assert_lt(carcass.global_position.y, ground - 0.05, "into the ground (%.2f, the ground %.2f)" % [carcass.global_position.y, ground])
	await wait_seconds(sink * 0.4 + 0.4)
	assert_false(is_instance_valid(carcass), "and is gone")

func test_03_killed_in_the_dark_it_lies_unseen() -> void:
	var main = await _level()
	var d = _animal(main)
	await wait_frames(3)
	d.visible = false        # out of his sight (FogOfWar)
	d.die()
	await wait_frames(1)
	var carcass: Node3D = _carcass(main)
	assert_not_null(carcass, "(its body is left)")
	if carcass != null:
		assert_false(carcass.is_visible_in_tree(), "Where he cannot see, he does not see it fall")

func test_04_with_no_scene_to_lay_it_in_it_is_simply_gone() -> void:
	var main = await _level()
	tree.current_scene = null
	fx_node._debris_root = null
	var d = _animal(main)
	await wait_frames(3)
	d.die()
	await wait_frames(2)
	assert_false(is_instance_valid(d), "Gone, as before")
	assert_null(main.find_child("Carcass", true, false), "and nothing is left of it")
