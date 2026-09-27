# res://tests/test_v06_rings_and_orders.gd
# v0.6 feedback: "当前选中的单位……需要下面有一圈很细的圈表示选中了，点击移动也需要有一个点击之后的
# 画圈反馈，跟很多即时战略游戏一样，点走到哪会有反馈".
#
# A unit is ringed by a thin circle at its feet (a building keeps its frame), and an order
# leaves two closing rings where it was given, coloured by what it was: walk, work, fight.
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
	clear_drops()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

## A right-click at a point on the ground, through the level's own input handling.
func _right_click(main: Node, world: Vector3) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = int(config_node.CONTROLS.get("hero_move_button", MOUSE_BUTTON_RIGHT)) if "CONTROLS" in config_node else MOUSE_BUTTON_RIGHT
	e.pressed = true
	var at: Vector2 = main.camera.unproject_position(world)
	e.position = at
	e.global_position = at
	main._unhandled_input(e)

func _marker(main: Node) -> Node:
	for child in main.get_children():
		if child is OrderMarker and not child.is_queued_for_deletion():
			return child
	return null

func test_01_a_unit_is_ringed_by_a_thin_circle_and_a_building_by_its_frame() -> void:
	var main = await _level()
	var ring = main.hero.selection_ring
	assert_eq(int(ring.shape), int(SelectionRing3D.Shape.ROUND), "The Hero is ringed by a circle")
	var thin: float = float(config_node.FEEDBACK["unit_ring_thickness"])
	assert_lt(thin, float(config_node.FEEDBACK["selection_ring_thickness"]), "Thinner than a building's frame")
	var torus := (ring._parts[0] as MeshInstance3D).mesh as TorusMesh
	assert_not_null(torus, "Drawn as a ring")
	if torus:
		assert_almost_eq(torus.outer_radius - torus.inner_radius, thin, 0.001, "As thin as Config says")
		assert_almost_eq(torus.outer_radius * 2.0,
			float(config_node.HERO["width"]) + float(config_node.FEEDBACK["unit_ring_margin"]) * 2.0, 0.01,
			"And just round his feet")
	var bench = main.cabin_interior.stations[0]
	assert_eq(int(bench.selection_ring.shape), int(SelectionRing3D.Shape.BOX), "A bench keeps the frame round its base")

func test_02_a_move_order_leaves_closing_rings_where_it_was_given() -> void:
	var main = await _level()
	await wait_frames(4)
	var spot: Vector3 = main.hero.global_position + Vector3(3.0, 0.0, 2.0)
	_right_click(main, spot)
	var marker = _marker(main)
	assert_not_null(marker, "The click is answered on the ground")
	if marker == null:
		return
	assert_eq(marker.kind, "move", "In the walking colour")
	var flat: Vector3 = marker.global_position - spot
	flat.y = 0.0
	assert_lt(flat.length(), 0.3, "Where he was sent")
	await wait_seconds(float(config_node.FEEDBACK["order_marker_seconds"]) + 0.2)
	assert_null(_marker(main), "And it closes and is gone")

func test_03_an_order_on_a_tree_marks_it_in_the_work_colour() -> void:
	var main = await _level()
	await wait_frames(4)
	var best: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) == "wood" and (best == null or n.global_position.distance_to(main.hero.global_position) < best.global_position.distance_to(main.hero.global_position)):
			best = n
	assert_not_null(best, "There is a tree")
	if best == null:
		return
	_right_click(main, best.global_position + Vector3(0.0, 0.2, 0.0))
	var marker = _marker(main)
	assert_not_null(marker, "The order is answered")
	if marker:
		assert_eq(marker.kind, "work", "In the working colour")
		assert_lt(marker.global_position.distance_to(best.global_position), 0.3, "On the tree")
	assert_eq(main.hero.target_resource_node, best, "And he is sent to it")
