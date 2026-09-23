# res://tests/test_v05_herds_on_the_valley_walls.gd
# Plant-eaters grazing on the lower valley walls (scripts/fx/Herds.gd): what makes the
# valley a place where dinosaurs live, rather than a stage a raid walks onto. Scenery --
# and scenery the game must never mistake for anything else.
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
	super.after_each()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(4)
	return main

func _animals(main: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var herds: Node = main.get_node_or_null("Herds")
	if herds != null:
		for child in herds.get_children():
			out.append(child as Node3D)
	return out

func test_01_every_herd_the_valley_declares_is_there() -> void:
	var main = await _level()
	var want: int = 0
	for spec in config_node.HERDS["herds"]:
		assert_true(ResourceLoader.exists(String(spec["scene"])), "%s has a model" % spec["species"])
		want += int(spec["count"])
	assert_eq(_animals(main).size(), want, "Every animal Config declares is grazing")

func test_02_they_graze_off_the_field_on_the_ground_as_drawn() -> void:
	var main = await _level()
	var t: Dictionary = config_node.TERRAIN
	var field_half: float = float(t["field_half"])
	var noise := TerrainBuilder.ground_noise(config_node)
	for a in _animals(main):
		var p: Vector3 = a.global_position
		assert_gt(maxf(absf(p.x), absf(p.z)), field_half, "%s is off the field" % a.name)
		var ground: float = TerrainBuilder.ground_height(p.x, p.z, field_half, float(t["outskirts_half"]), t, noise)
		assert_almost_eq(p.y, ground, 0.05, "%s stands on the ground" % a.name)

func test_03_nothing_in_the_game_can_mistake_them_for_anything() -> void:
	# No collider to walk into, no group for a turret or a raid to find, nothing with
	# hit points: a turret that shot at a grazing sauropod would be the old lie again.
	var main = await _level()
	var herds: Node = main.get_node_or_null("Herds")
	assert_not_null(herds, "The herds are there")
	if herds == null:
		return
	var bodies: int = 0
	var grouped: int = 0
	for n in herds.find_children("*", "", true, false):
		if n is CollisionObject3D or n is CollisionShape3D:
			bodies += 1
		if not n.get_groups().is_empty():
			grouped += 1
		assert_false(n.has_method("take_damage"), "%s cannot be hurt" % n.name)
	assert_eq(bodies, 0, "Not one collider among them")
	assert_eq(grouped, 0, "And not one in any group the game looks things up by")

func test_04_they_amble_but_stay_near_where_they_graze() -> void:
	var main = await _level()
	var start: Dictionary = {}
	for a in _animals(main):
		start[a.name] = a.global_position
	# Long enough for every one to have grazed and moved at least once.
	var longest: float = (config_node.HERDS["graze_time"] as Vector2).y
	await wait_physics_frames(int((longest + 8.0) * 60.0))
	var moved: int = 0
	var reach: float = float(config_node.HERDS["wander_radius"]) * 2.0 + 0.1
	for a in _animals(main):
		var d: float = Vector2(a.global_position.x - start[a.name].x, a.global_position.z - start[a.name].z).length()
		if d > 0.2:
			moved += 1
		assert_lte(d, reach, "%s wanders, but not off" % a.name)
	assert_gt(moved, 0, "They do amble")
