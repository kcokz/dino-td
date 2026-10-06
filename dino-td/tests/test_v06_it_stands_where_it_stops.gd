# res://tests/test_v06_it_stands_where_it_stops.gd
# The debug-agent's BUG-005 ("背后半圈栅栏时，来袭挤在船舱开口的一头原地打转"), as the twitch watch
# (TwitchWatch) took it apart: a raptor sent to a spot went a step past it every frame, the steering
# solver's answer being a frame behind its asking -- three places, six frames round, for as long as it
# waited there; and crowded against the fence it turned to the fence and back each frame the solver
# changed its mind, going nowhere.
#
# So: a walker stops on the spot it is sent to and stays there; the solver may slow it or turn it,
# never carry it on past what it asks this frame; it turns to the way it goes, not to where it is
# shoved; and waiting at its place it faces what it came for.
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

## A raider on open ground well away from the cabin, its own mind stopped: the test drives it.
func _raider(main: Node) -> Node3D:
	var species: String = String(game_state_node.map_data()["raiders"].keys()[0])
	var d = load(String(config_node.get_dino_script_path(species))).new()
	main.dinos_container.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.global_position = main.current_core.global_position + Vector3(-10.0, 0.0, 8.0)
	return d

func _dt() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)

func test_01_sent_to_a_spot_it_stops_on_it_and_stays() -> void:
	var main = await _level()
	var d = _raider(main)
	await wait_physics_frames(2)
	var spot: Vector3 = d.global_position + Vector3(1.3, 0.0, 0.4)
	for i in 90:
		await wait_physics_frames(1)
		d._travel(spot, _dt())
	var at: Vector3 = d.global_position
	var furthest: float = 0.0
	for i in 60:
		await wait_physics_frames(1)
		d._travel(spot, _dt())
		furthest = maxf(furthest, Vector2(d.global_position.x - at.x, d.global_position.z - at.z).length())
	assert_lt(Vector2(at.x - spot.x, at.z - spot.z).length(), 0.06, "It gets to its spot")
	assert_lt(furthest, 0.001, "and stands there: not a step past it and back, a second on")

func test_02_the_solver_can_slow_it_or_turn_it_but_never_carry_it_on() -> void:
	# Its answer comes a frame after the asking: an answer to "go" arrives on the frame it asks to stop.
	var main = await _level()
	var d = _raider(main)
	await wait_physics_frames(2)
	var at: Vector3 = d.global_position
	d._safe_velocity = Vector3(float(d.speed), 0.0, 0.0)
	d._answered = d._requests
	d._drive(Vector3.ZERO, _dt(), Vector3.INF)
	assert_lt(d.global_position.distance_to(at), 0.001, "Asked to stop, it stops, whatever the solver last said")
	d._safe_velocity = Vector3(float(d.speed), 0.0, 0.0)
	d._answered = d._requests
	var slow: float = float(d.speed) * 0.25
	d._drive(Vector3(slow, 0.0, 0.0), _dt(), Vector3.INF)
	assert_lt(d.global_position.distance_to(at), slow * _dt() + 0.001, "Asked to amble, it ambles")

func test_03_waiting_at_its_place_it_faces_what_it_came_for() -> void:
	var main = await _level()
	var d = _raider(main)
	await wait_physics_frames(2)
	d.current_target = main.current_core
	d.rotation.y = 0.0
	for i in 60:
		await wait_physics_frames(1)
		d._travel(d.global_position, _dt())
	var to: Vector3 = main.current_core.global_position - d.global_position
	var facing: float = atan2(-to.x, -to.z)
	assert_lt(absf(wrapf(d.rotation.y - facing, -PI, PI)), deg_to_rad(5.0), "It faces the cabin, not the spot it stands on")

func test_04_pushed_into_a_fence_it_goes_nowhere_and_does_not_turn_to_it() -> void:
	var main = await _level()
	var d = _raider(main)
	stock_everything()
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(d.global_position + Vector3(1.0, 0.0, 0.0))
	var stake = main.build_system.place_at("wall", cell, main.buildings_container, true)
	assert_not_null(stake, "A stake beside it")
	if stake == null:
		return
	stake.complete_construction()
	await wait_physics_frames(4)
	# Against the stake's face, facing along it; sent straight into it.
	var face: float = (stake as Node3D).global_position.x - float(config_node.get_building_half("wall").x)
	d.global_position = Vector3(face - float(d._avoid_radius) - 0.02, d.global_position.y, (stake as Node3D).global_position.z)
	d.rotation.y = 0.0
	# Up against it first: the step it has room for, it takes, and turns with.
	for i in 10:
		await wait_physics_frames(1)
		d._drive(Vector3(float(d.speed), 0.0, 0.0), _dt(), Vector3.INF)
	var at: Vector3 = d.global_position
	var heading: float = d.rotation.y
	for i in 30:
		await wait_physics_frames(1)
		d._drive(Vector3(float(d.speed), 0.0, 0.0), _dt(), Vector3.INF)
	assert_lt(Vector2(d.global_position.x - at.x, d.global_position.z - at.z).length(), 0.05, "The stake holds it")
	assert_lt(absf(wrapf(d.rotation.y - heading, -PI, PI)), deg_to_rad(1.0), "and going nowhere, it does not turn to the stake")
