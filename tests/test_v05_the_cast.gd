# res://tests/test_v05_the_cast.gd
# The animated cast from Quaternius (CC0; tools/convert_quaternius.py): what each of them
# has to be for the game to use it, all of which went wrong once on the way in.
#
#   * The FBX materials came in with an alpha of 0, alpha-masked: every pixel of the raptor
#     and the T-Rex was cut away, and they walked the field skinned, animated -- invisible.
#     Nothing checked that a model can actually be SEEN.
#   * Every one of them faced backwards, and everything in the game turns with look_at.
#   * A long-tailed animal fitted inside its collider box by length stood a third of its
#     declared height; the raptor was 33 cm tall and lost in the ferns.
#   * No clip looped. A walk played once and froze mid-stride.
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

## Every material a mesh is drawn with: its override, else each surface's own.
func _materials_of(mi: MeshInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if mi.material_override != null:
		out.append(mi.material_override)
		return out
	for s in range(mi.mesh.get_surface_count()):
		var m: Material = mi.get_active_material(s)
		if m != null:
			out.append(m)
	return out

func _dino(kind: String) -> Node:
	var d = _keep(load("res://scripts/entities/Dino.gd").new())
	tree.root.add_child(d)
	d.setup(kind)
	d.set_physics_process(false)
	return d

# ==============================================================================

func test_01_every_model_the_game_loads_can_be_seen() -> void:
	# For every model Config names: no surface drawn fully transparent, and none cut away
	# by an alpha scissor its own colour cannot pass.
	var checked: int = 0
	for key in config_node.VISUALS:
		if not VisualLibrary.has_art(String(key)):
			continue
		var body: Node3D = _keep(VisualLibrary.make(String(key)))
		for node in body.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for m in _materials_of(mi):
				var sm := m as BaseMaterial3D
				if sm == null:
					continue
				checked += 1
				var alpha: float = sm.albedo_color.a
				if sm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					assert_gte(alpha, sm.alpha_scissor_threshold, "%s: a surface is not cut away by its own scissor" % key)
				elif sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					assert_gt(alpha, 0.05, "%s: a surface is not drawn fully transparent" % key)
	assert_gt(checked, 10, "There were materials to check (%d)" % checked)

func test_02_every_dinosaur_faces_the_way_it_walks() -> void:
	# look_at points a node's -Z at where it is going, so the head has to be out along -Z.
	for kind in ["raptor", "big_theropod"]:
		var d = _dino(kind)
		await wait_frames(1)
		var skel: Skeleton3D = null
		for s in d.find_children("*", "Skeleton3D", true, false):
			skel = s as Skeleton3D
		assert_not_null(skel, "The %s has a skeleton" % kind)
		if skel == null:
			continue
		var head: int = skel.find_bone("Head")
		assert_gte(head, 0, "And a head")
		if head < 0:
			continue
		var head_at: Vector3 = d.to_local(skel.global_transform * skel.get_bone_global_pose(head).origin)
		assert_lt(head_at.z, -0.05, "The %s's head is out in front, along -Z (%.2f)" % [kind, head_at.z])

func test_03_every_dinosaur_stands_as_tall_as_declared() -> void:
	for kind in ["raptor", "big_theropod"]:
		var d = _dino(kind)
		await wait_frames(1)
		var body: Node3D = d.find_child("Body", false, false)
		var bounds: AABB = VisualLibrary.visual_bounds(body)
		var want: float = (config_node.DINOS[kind]["size"] as Vector3).y
		assert_almost_eq(bounds.size.y, want, want * 0.02, "The %s is %.2f m tall" % [kind, want])
		assert_almost_eq(bounds.position.y, 0.0, 0.02, "Standing on the ground")

func test_04_what_should_loop_loops_and_what_should_not_does_not() -> void:
	var d = _dino("raptor")
	await wait_frames(1)
	var player: AnimationPlayer = d.animator.animation_player
	assert_not_null(player, "The raptor is animated")
	if player == null:
		return
	d.animator.play_state("WALKING")
	var walking: String = player.current_animation
	assert_eq(player.get_animation(walking).loop_mode, Animation.LOOP_LINEAR, "Its walk goes round (%s)" % walking)
	d.animator.play_state("DEAD")
	var dying: String = player.current_animation
	assert_eq(player.get_animation(dying).loop_mode, Animation.LOOP_NONE, "Its death plays once (%s)" % dying)
