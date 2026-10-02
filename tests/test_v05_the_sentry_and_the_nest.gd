# res://tests/test_v05_the_sentry_and_the_nest.gd
# The two landmarks that were still placeholders: the auto turret, which was a box, and
# the nest the raid comes out of, which was a lump of stone with a black box stuck on it.
#
# Asked for as "之前做的不够精致的模型都重做" -- every model that was not up to standard
# gets redone. The art is tools/generate_props.py (nest, and the turret head); what is tested
# here is what the game does with it.
#
# The sentry is gone since v0.6 round two -- nothing the player builds aims (Trap.gd) -- and its
# head went on the cabin's roof as the ship's own gun; since 2026-10-02 that is dead too and not
# drawn (CoreCampfire: "cabin的自动射击得取消了，太厉害"). What is tested of it is that it is gone.
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

## The cabin (CoreCampfire), whose gun is dead.
func _tower(at: Vector3 = Vector3(30.0, 0.0, 30.0)) -> Node:
	var tower = _keep(load("res://scripts/entities/CoreCampfire.gd").new())
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

func test_01_the_ship_gun_on_the_roof_is_dead_and_not_drawn() -> void:
	# The player, 2026-10-02: "家里不需要任何防御就能顶住，cabin的自动射击得取消了，太厉害".
	assert_true(VisualLibrary.has_art("building/core"), "The cabin has a model")
	var tower = _tower()
	await wait_frames(1)
	assert_false("attack_range" in tower, "The cabin is no turret: no reach")
	assert_null(tower.find_child("DetectionArea", true, false), "nothing that looks for a target")
	assert_null(tower.find_child("FireTimer", true, false), "and nothing that fires")
	assert_eq(float(tower._get_display_range()), 0.0, "No ring round it when it is picked")
	var head := tower.find_child("Head", true, false) as Node3D
	assert_true(head == null or not head.visible, "Its dead gun is not drawn, to say it guards nothing")
	var dino = _raptor(tower.global_position + Vector3(3.0, 0.0, 1.5))
	dino.set_physics_process(false)
	await wait_seconds(1.5)
	assert_almost_eq(float(dino.current_hp), raptor_stat("hp"), 0.001, "A raptor beside it is not shot")
	for key in ["range", "damage", "fire_rate", "turn_speed", "shot"]:
		assert_false(config_node.BUILDINGS["core"].has(key), "Config gives the cabin no gun (%s)" % key)

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
	# Its own species' declared size (Nest.art_key: each species' nest is its own, GAME-DESIGN 9.3).
	var size: Vector3 = config_node.get_visual_size(nest.art_key())
	var reach: float = _reach(nest.find_child("Body", false, false), nest.global_position)
	assert_lte(reach, size.x * 0.5 + 0.001, "The nest never reaches past its footprint")
	assert_gt(reach, size.x * 0.5 * 0.9, "And fills it: nearly all of the footprint is nest")
