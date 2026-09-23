# res://tests/test_v05_piles_on_the_ground.gd
# What a drop looks like lying on the ground.
#
# Every resource reaches the warehouse through a pile the Hero walks over (v0.3), so the
# field is always scattered with them -- and every one was a cube in its resource's
# colour. A green cube was wood. Each resource has a pile of its own now
# (tools/generate_props.py drop_*): split logs, quarried stone, bones, a haunch of meat,
# a clay pot of water.
extends "res://tests/test_base.gd"

var config_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	clear_drops()
	super.after_each()

## A pile of `res_id` on the ground at `at`, dropped the way the game drops one.
func _drop(res_id: String, at: Vector3, amount: int = 3) -> Node:
	var context := Node3D.new()
	_cleanup_nodes.append(context)
	tree.root.add_child(context)
	return DropItem.spawn(context, at, res_id, amount)

func test_01_every_resource_has_a_pile_of_its_own() -> void:
	for res in config_node.RESOURCES:
		assert_true(VisualLibrary.has_art("drop/" + String(res)), "%s has a pile model" % res)

func test_02_a_drop_is_its_pile_not_a_cube() -> void:
	for res in config_node.RESOURCES:
		var drop = _drop(String(res), Vector3(60.0 + 3.0 * float(config_node.RESOURCES.find(res)), 0.0, 60.0))
		assert_not_null(drop, "A %s pile was dropped" % res)
		if drop == null:
			continue
		assert_not_null(drop.get_node_or_null("Pile"), "%s is drawn as its pile" % res)
		var boxes: int = 0
		for node in drop.find_children("*", "MeshInstance3D", true, false):
			if (node as MeshInstance3D).mesh is BoxMesh:
				boxes += 1
		assert_eq(boxes, 0, "And not as a cube -- %s" % res)

func test_03_a_pile_is_the_size_config_declares() -> void:
	var want: Vector3 = config_node.get_visual_size("drop/wood")
	assert_gt(want.x, want.y, "A pile is declared wider than it is tall")
	for res in config_node.RESOURCES:
		var drop = _drop(String(res), Vector3(-60.0 - 3.0 * float(config_node.RESOURCES.find(res)), 0.0, 60.0))
		if drop == null:
			continue
		var pile: Node3D = drop.get_node_or_null("Pile")
		if pile == null:
			continue
		var bounds: AABB = VisualLibrary.visual_bounds(pile)
		var size: Vector3 = config_node.get_visual_size("drop/" + String(res))
		assert_lte(bounds.size.y, size.y + 0.001, "A %s pile is no taller than declared" % res)
		assert_lte(maxf(bounds.size.x, bounds.size.z), size.x + 0.001, "Nor wider -- %s" % res)
		assert_gt(maxf(bounds.size.x, bounds.size.z), size.x * 0.5, "But big enough to see -- %s" % res)
		assert_almost_eq(bounds.position.y, 0.0, 0.01, "Lying on the ground -- %s" % res)

func test_04_a_pile_does_not_darken_the_ground_it_lies_on() -> void:
	var drop = _drop("wood", Vector3(60.0, 0.0, -60.0))
	if drop == null:
		_record_fail("No drop")
		return
	var meshes: Array = drop.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "It is drawn")
	for node in meshes:
		assert_eq((node as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"No part of it casts a shadow")

func test_05_piles_side_by_side_do_not_all_face_the_same_way() -> void:
	# Beyond merging distance of each other, so they stay two piles.
	var gap: float = float(config_node.DROPS["merge_radius"]) * 3.0
	var a = _drop("stone", Vector3(-60.0, 0.0, -60.0))
	var b = _drop("stone", Vector3(-60.0 + gap, 0.0, -60.0))
	if a == null or b == null or a == b:
		_record_fail("Two separate piles were not made")
		return
	var ta: float = (a.get_node("Pile") as Node3D).rotation.y
	var tb: float = (b.get_node("Pile") as Node3D).rotation.y
	assert_gt(absf(angle_difference(ta, tb)), 0.2, "Two piles lie at different angles")

func test_06_the_count_sits_above_the_pile() -> void:
	var drop = _drop("food", Vector3(0.0, 0.0, -70.0), 5)
	if drop == null:
		_record_fail("No drop")
		return
	var label: Label3D = drop.label_3d
	assert_true(label.visible, "A pile of five shows its count")
	var top: float = VisualLibrary.visual_bounds(drop.get_node("Pile")).end.y
	assert_gt(label.position.y, top, "Above the pile, not buried in it")
