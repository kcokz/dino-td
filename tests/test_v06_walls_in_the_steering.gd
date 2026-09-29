# res://tests/test_v06_walls_in_the_steering.gd
# The debug-agent's BUG-009, second part: with the traps spread about, a raid at a full ring of fence
# still twitched at its corners -- the engine's avoidance steers raiders round each other and knew
# nothing of walls, so a raptor squeezed at a corner was steered into the fence, pressed there and
# swung its head. A finished building is in the raiders' steering now: an outline of its box, on
# its own avoidance layers (Config.DINO_AI.building_avoidance_layers), which their agents avoid and
# the Hero's does not -- he goes through his gates -- nor a siege animal's, which goes through walls.
#
# And BUG-010: held up at the crowd's edge short of its place, a raider faces what it came for,
# rather than the cabin while it waits and the way in while it tries, by turns.
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

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _layers() -> int:
	return int(config_node.DINO_AI["building_avoidance_layers"])

## A section of fence at `at`, as a blueprint or finished.
func _fence(main: Node, at: Vector3, finished: bool = true) -> Node:
	var cell: Vector2i = main.grid_manager.world_to_build_cell(at)
	var wall = main.build_system.place_at("wall", cell, main.buildings_container, true)
	if finished:
		wall.complete_construction()
	return wall

func _raider(main: Node, kind: String, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(kind))).new()
	_cleanup_nodes.append(d)
	main.add_child(d)
	d.setup(kind)
	d.global_position = at
	return d

## Where it is looking, on the ground (its forward is -Z).
func _heading(d: Node3D) -> Vector3:
	return Vector3(-sin(d.rotation.y), 0.0, -cos(d.rotation.y))

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func test_01_a_finished_building_is_in_the_raiders_steering_and_a_blueprint_is_not() -> void:
	var main = await _level()
	stock_everything()
	var wall = _fence(main, main.hero.global_position + Vector3(4.0, 0.0, 4.0), false)
	var outline := wall.find_child("AvoidObstacle", false, false) as NavigationObstacle3D
	assert_true(outline == null or not outline.avoidance_enabled, "A blueprint is in nobody's way")
	wall.complete_construction()
	outline = wall.find_child("AvoidObstacle", false, false) as NavigationObstacle3D
	assert_not_null(outline, "Finished, it is in the steering")
	if outline == null:
		return
	assert_true(outline.avoidance_enabled, "on")
	assert_eq(outline.avoidance_layers, _layers(), "on the buildings' own layers")
	assert_false(outline.affect_navigation_mesh, "and not in the navigation bake: that is the collider's")
	var half: Vector2 = config_node.get_building_half("wall") - Vector2.ONE * float(config_node.DINO_AI["avoid_margin"])
	var box := AABB(outline.vertices[0], Vector3.ZERO)
	for v in outline.vertices:
		box = box.expand(v)
	assert_almost_eq(box.size.x, half.x * 2.0, 0.001, "Its box less the steering's margin, east to west")
	assert_almost_eq(box.size.z, half.y * 2.0, 0.001, "and north to south: a body still comes up against it")
	wall.destroy()
	assert_false(outline.avoidance_enabled, "Pulled down, it is out of the way at once")

func test_02_raiders_steer_round_buildings_and_he_and_a_siege_animal_do_not() -> void:
	var main = await _level()
	var raider = _raider(main, "raptor", main.hero.global_position + Vector3(6.0, 0.0, 6.0))
	await wait_physics_frames(2)
	assert_eq(NavigationServer3D.agent_get_avoidance_mask(raider._agent) & _layers(), _layers(),
		"A raider steers round buildings")
	assert_almost_eq(NavigationServer3D.agent_get_time_horizon_obstacles(raider._agent),
		float(config_node.DINO_AI["obstacle_horizon"]), 0.0001, "looking this far ahead for them")
	assert_eq(NavigationServer3D.agent_get_avoidance_mask(main.hero._agent) & _layers(), 0,
		"He does not: he goes through his gates")
	var siege_kind: String = ""
	for kind in config_node.DINOS:
		if String(config_node.DINOS[kind].get("behaviour", "")) == "siege":
			siege_kind = String(kind)
			break
	assert_ne(siege_kind, "", "(a siege animal to ask)")
	if siege_kind == "":
		return
	var siege = _raider(main, siege_kind, main.hero.global_position + Vector3(-6.0, 0.0, 6.0))
	await wait_physics_frames(2)
	assert_eq(NavigationServer3D.agent_get_avoidance_mask(siege._agent) & _layers(), 0,
		"Nor does a siege animal: it goes through them")

func test_03_the_steering_does_not_carry_a_raider_into_a_wall() -> void:
	# Asked to go straight at a section of fence from its place a hand's breadth off the face, the
	# steering holds it there, or slides it along -- it does not send it on into the fence.
	var main = await _level()
	stock_everything()
	var wall = _fence(main, main.hero.global_position + Vector3(5.0, 0.0, 5.0))
	var centre: Vector3 = wall.global_position
	var half: Vector2 = config_node.get_building_half("wall")
	var raider = _raider(main, "raptor", centre + Vector3(0.0, 0.0, half.y + float(config_node.DINO_STANDOFF_INNER)))
	raider.set_physics_process(false)
	var into := Vector3(0.0, 0.0, -float(raider.speed))
	var answer := Vector3.ZERO
	for i in 12:
		answer = raider._avoid(into)
		await wait_physics_frames(1)
	answer = raider._avoid(into)
	assert_gt(answer.z, into.z * 0.25, "The steering does not carry it on into the fence (asked %.2f, given %.2f)" % [into.z, answer.z])

func test_04_held_up_at_the_crowds_edge_it_faces_what_it_came_for() -> void:
	# BUG-010: at the crowd's edge, short of its place and getting nowhere, it faced the cabin while it
	# waited and the way in while it tried, by turns.
	var main = await _level()
	stock_everything()
	var wall = _fence(main, main.hero.global_position + Vector3(6.0, 0.0, 6.0))
	var centre: Vector3 = wall.global_position
	var standoff: float = float(config_node.DINO_AI["queue_standoff"])
	# Its place east of the fence; it is held up nearly the queue's distance south of it, where the
	# way in and the fence are nearly forty degrees apart.
	var place: Vector3 = centre + Vector3(2.0, 0.0, 0.0)
	var held: Vector3 = place + Vector3(0.0, 0.0, standoff - 0.2)
	var raider = _raider(main, "raptor", held)
	raider.set_physics_process(false)
	raider.current_target = wall
	raider.assigned_slot = place
	raider._stuck_count = 1
	raider._patience = 0.0
	for i in 30:
		raider._travel(place, 1.0 / 60.0)
		raider.global_position = held   # the crowd holds it
		await wait_physics_frames(1)
	var to_wall: Vector3 = _flat(centre - held)
	var to_place: Vector3 = _flat(place - held)
	assert_gt(rad_to_deg(to_place.angle_to(to_wall)), 20.0, "(the way in and the fence are well apart)")
	assert_lt(rad_to_deg(_heading(raider).angle_to(to_wall)), 5.0, "Held up at the crowd's edge, it faces the fence it came for")
	raider._stuck_count = 0
	for i in 30:
		raider._travel(place, 1.0 / 60.0)
		raider.global_position = held
		await wait_physics_frames(1)
	assert_lt(rad_to_deg(_heading(raider).angle_to(to_place)), 5.0, "Getting somewhere, it faces its way")
