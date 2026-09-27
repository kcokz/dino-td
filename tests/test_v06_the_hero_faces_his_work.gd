# res://tests/test_v06_the_hero_faces_his_work.gd
# v0.6 feedback: "人在走的时候是倒着走的，挖树的时候也不是对着树挖的，而且离树特别远".
#
# He walked backwards: the game turns everything with look_at, which points -Z at where it
# is going, and his model faced +Z (the dinosaurs had been turned; he had not). And he
# chopped from two metres off, because a tree blocked by its whole crown. Now he faces
# where he walks and what he works on, and stands at the trunk to chop it.
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

## Which way his model faces, on the ground: from his heel to his toes (the rig's foot and
## ball bones, at rest -- a stride swings them, the rest pose does not).
func _facing(hero: Node) -> Vector3:
	var skeleton := hero.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return Vector3.ZERO
	var heel: int = skeleton.find_bone("foot_l")
	var toe: int = skeleton.find_bone("ball_l")
	if heel < 0 or toe < 0:
		return Vector3.ZERO
	var d: Vector3 = skeleton.global_transform.basis * (skeleton.get_bone_global_rest(toe).origin - skeleton.get_bone_global_rest(heel).origin)
	d.y = 0.0
	return d.normalized()

func _nearest_tree(from: Vector3) -> Node:
	var best: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		if String(n.resource_type) != "wood" or n.is_depleted:
			continue
		if best == null or n.global_position.distance_to(from) < best.global_position.distance_to(from):
			best = n
	return best

func test_01_he_faces_where_he_walks() -> void:
	var main = await _level()
	var hero = main.hero
	assert_ne(_facing(hero), Vector3.ZERO, "His model has feet to tell which way he faces")
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		hero.move_to(hero.global_position + dir * 5.0)
		await wait_physics_frames(12)
		var heading: Vector3 = hero.velocity
		heading.y = 0.0
		assert_gt(heading.length(), 0.1, "He is walking (%s)" % dir)
		if heading.length() > 0.1:
			assert_gt(_facing(hero).dot(heading.normalized()), 0.7,
				"Walking %s he looks where he is going, not back the way he came" % dir)

func test_02_he_chops_at_the_trunk_facing_it() -> void:
	var main = await _level()
	var hero = main.hero
	var wood: Node = _nearest_tree(hero.global_position)
	assert_not_null(wood, "There is a tree to chop")
	if wood == null:
		return
	hero.order_harvest(wood)
	var started: bool = false
	for i in 900:
		await wait_physics_frames(1)
		if hero.current_state == Hero.State.HARVESTING:
			started = true
			break
	assert_true(started, "He gets to the tree and starts on it")
	await wait_physics_frames(2)
	var off: Vector3 = hero.global_position - wood.global_position
	off.y = 0.0
	var trunk: float = float(config_node.RESOURCE_NODES["wood"]["trunk_radius"])
	var me: float = float(config_node.HERO["width"]) * 0.5
	var reach: float = float(config_node.HERO["harvest_reach"])
	assert_lte(off.length(), trunk + me + reach + 0.05,
		"He stands at the trunk to chop it (%.2f m from its middle)" % off.length())
	assert_gt(_facing(hero).dot(-off.normalized()), 0.7, "And faces it")

func test_03_a_tree_is_clicked_by_its_crown_and_blocks_by_its_trunk() -> void:
	var main = await _level()
	var wood: Node = _nearest_tree(main.hero.global_position)
	assert_not_null(wood, "There is a tree")
	if wood == null:
		return
	var pick: int = int(config_node.LAYER_PICK)
	assert_eq(wood.collision_layer, pick, "Its crown-sized shape is only there to be clicked")
	var trunk_body := wood.find_child("Trunk", false, false) as StaticBody3D
	assert_not_null(trunk_body, "A trunk stands in the way")
	if trunk_body == null:
		return
	assert_eq(trunk_body.collision_layer, 1, "On the obstacle layer, with the ground and the rocks")
	var shape := (trunk_body.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	assert_almost_eq(shape.radius, float(config_node.RESOURCE_NODES["wood"]["trunk_radius"]), 0.001,
		"As thick as Config says the trunk is")
	# Straight down through the crown, clear of the trunk: the picking ray finds the tree,
	# the obstacle layer does not.
	var size: Vector3 = config_node.get_visual_size("node/wood")
	var above: Vector3 = wood.global_position + Vector3(size.x * 0.35, size.y + 1.0, 0.0)
	var below: Vector3 = above - Vector3(0.0, size.y + 2.0, 0.0)
	var space: PhysicsDirectSpaceState3D = wood.get_world_3d().direct_space_state
	var down_pick := PhysicsRayQueryParameters3D.create(above, below, pick)
	assert_eq(space.intersect_ray(down_pick).get("collider"), wood, "Clicked on its crown, it is the tree")
	var down_block := PhysicsRayQueryParameters3D.create(above, below, 1)
	var hit: Dictionary = space.intersect_ray(down_block)
	assert_ne(hit.get("collider"), wood, "Under its crown is open ground")
	assert_ne(hit.get("collider"), trunk_body, "Not trunk")
