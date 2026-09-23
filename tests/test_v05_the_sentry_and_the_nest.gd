# res://tests/test_v05_the_sentry_and_the_nest.gd
# The two landmarks that were still placeholders: the auto turret, which was a box, and
# the nest the raid comes out of, which was a lump of stone with a black box stuck on it.
#
# Asked for as "之前做的不够精致的模型都重做" -- every model that was not up to standard
# gets redone. The art is tools/generate_props.py (sentry, nest); what is tested here is
# what the game does with it.
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

func _keep(n: Node) -> Node:
	_cleanup_nodes.append(n)
	return n

func _tower(at: Vector3 = Vector3(30.0, 0.0, 30.0)) -> Node:
	var tower = _keep(load("res://scripts/entities/Tower.gd").new())
	tree.root.add_child(tower)
	tower.global_position = at
	if tower.has_method("complete_construction") and not tower.is_constructed:
		tower.complete_construction()
	return tower

func _raptor(at: Vector3) -> Node:
	var dino = _keep(load("res://scripts/entities/Dino.gd").new())
	tree.root.add_child(dino)
	dino.setup("raptor")
	dino.global_position = at
	return dino

## Which way the head's barrels point, flat on the ground.
func _facing(head: Node3D) -> Vector3:
	var f: Vector3 = -head.global_transform.basis.z
	f.y = 0.0
	return f.normalized()

## The furthest any vertex under `root` reaches from `centre`, sideways, in the world.
func _reach(root: Node3D, centre: Vector3) -> float:
	var widest: float = 0.0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for surface in range(mi.mesh.get_surface_count()):
			for v in mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = mi.global_transform * v - centre
				widest = maxf(widest, maxf(absf(p.x), absf(p.z)))
	return widest

# ==============================================================================
# 1. The sentry
# ==============================================================================

func test_01_the_sentry_has_a_head_to_turn_and_barrels_to_fire_from() -> void:
	assert_true(VisualLibrary.has_art("building/tower"), "The turret has a model now")
	var tower = _tower()
	await wait_frames(1)
	var head: Node3D = tower._turret_head()
	assert_not_null(head, "Its model has a head that turns")
	if head == null:
		return
	assert_not_null(head.find_child("Muzzle", true, false), "With a muzzle at the end of its barrels")

func test_02_it_turns_to_face_what_it_shoots() -> void:
	var tower = _tower()
	var dino = _raptor(tower.global_position + Vector3(3.0, 0.0, 1.5))
	await wait_frames(1)
	var head: Node3D = tower._turret_head()
	if head == null:
		_record_fail("No head to turn")
		return
	head.rotation.y = PI      # looking the wrong way to start with
	tower.fire_at(dino)
	var want: Vector3 = (dino.global_position - tower.global_position)
	want.y = 0.0
	assert_gt(_facing(head).dot(want.normalized()), 0.999,
		"The barrels point at the dinosaur it has just shot")

func test_03_it_follows_its_target_round_at_its_own_speed() -> void:
	# Swinging round rather than snapping is what shows the player which dinosaur a
	# turret has picked -- so it must actually take time, and it must actually get there.
	var tower = _tower()
	var dino = _raptor(tower.global_position + Vector3(-2.0, 0.0, 3.0))
	await wait_frames(1)
	var head: Node3D = tower._turret_head()
	if head == null:
		_record_fail("No head to turn")
		return
	var want: Vector3 = dino.global_position - tower.global_position
	want.y = 0.0
	want = want.normalized()
	tower.current_target = dino
	head.rotation.y = tower._heading_to(head, dino.global_position) + PI    # facing directly away

	var step: float = 0.05
	var half_turn: float = 180.0 / float(config_node.BUILDINGS["tower"]["turn_speed"])
	tower._track_target(step)
	assert_lt(_facing(head).dot(want), 0.9, "One short step is not enough to turn right round")
	var elapsed: float = step
	while elapsed < half_turn + step:
		tower._track_target(step)
		elapsed += step
	assert_gt(_facing(head).dot(want), 0.999, "But half a turn's worth of time is")

func test_04_the_shot_leaves_from_the_barrels() -> void:
	var tower = _tower()
	await wait_frames(1)
	var head: Node3D = tower._turret_head()
	if head == null:
		_record_fail("No head")
		return
	var muzzle := head.find_child("Muzzle", true, false) as Node3D
	assert_almost_eq(tower.shot_origin().distance_to(muzzle.global_position), 0.0, 0.001,
		"The tracer starts at the muzzle")
	assert_gt(tower.shot_origin().y - tower.global_position.y, 1.5,
		"Up on the stand, not out of the middle of it the way the box fired")

func test_05_however_the_head_turns_it_stays_over_the_stand() -> void:
	# The barrels swing round with the head. They must never reach past the footprint the
	# turret occupies, or the art hangs over ground the rules say is free.
	var tower = _tower()
	await wait_frames(1)
	var head: Node3D = tower._turret_head()
	if head == null:
		_record_fail("No head")
		return
	var half: float = float(config_node.get_building_footprint("tower")) * 0.5
	for step in range(12):
		head.rotation.y = TAU * float(step) / 12.0
		assert_lte(_reach(head, tower.global_position), half + 0.001,
			"Turned to %d degrees, the head is still inside the footprint" % (step * 30))

func test_06_a_blueprint_does_not_track_anything() -> void:
	var tower = _tower()
	var dino = _raptor(tower.global_position + Vector3(2.0, 0.0, 0.0))
	await wait_frames(1)
	var head: Node3D = tower._turret_head()
	if head == null:
		_record_fail("No head")
		return
	tower.is_constructed = false
	tower.current_target = dino
	head.rotation.y = 0.0
	tower._track_target(0.5)
	assert_almost_eq(head.rotation.y, 0.0, 0.0001, "A turret that is not built yet does not move")

# ==============================================================================
# 2. The nest
# ==============================================================================

func test_07_the_nest_has_one_mouth_not_two() -> void:
	# The placeholder's mouth was a black box stuck on its front. The model has a burrow
	# of its own, and the box beside it was a second, square mouth.
	assert_true(VisualLibrary.has_art("nest"), "The nest has a model now")
	var nest = _keep(load("res://scripts/entities/Nest.gd").new())
	tree.root.add_child(nest)
	nest.global_position = Vector3(-40.0, 0.0, -40.0)
	await wait_frames(1)
	assert_null(nest.get_node_or_null("EntranceMarker"), "No black box on the front of the modelled nest")

func test_08_the_nest_stays_inside_its_own_box() -> void:
	# Its collider is its declared size; its art has to stay inside that, and fill it
	# across -- a nest drawn smaller than the ground it blocks is ground that stops
	# things at nothing.
	var nest = _keep(load("res://scripts/entities/Nest.gd").new())
	tree.root.add_child(nest)
	nest.global_position = Vector3(-40.0, 0.0, 40.0)
	await wait_frames(1)
	var size: Vector3 = config_node.get_visual_size("nest")
	var reach: float = _reach(nest.find_child("Body", false, false), nest.global_position)
	assert_lte(reach, size.x * 0.5 + 0.001, "The nest never reaches past its footprint")
	assert_gt(reach, size.x * 0.5 * 0.9, "And fills it: nearly all of the footprint is nest")
