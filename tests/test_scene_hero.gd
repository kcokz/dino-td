# res://tests/test_scene_hero.gd
# SCENE-POLISH S4: Humanoid Hero Model & Gameplay Animation Rigging Verification Suite.
#
# Acceptance criteria from SCENE-POLISH.md:
# 1. Config.VISUALS["hero"]["scene"] is non-empty and points to a model that exists -- since
#    v0.5 Quaternius' worker, assets/models/quaternius/worker.glb (tools/convert_quaternius.py).
# 2. Hero model exists on disk, imports cleanly, and instantiates an AnimationPlayer.
# 3. Full animation coverage for all 6 Hero.State enum states:
#    - IDLE -> idle
#    - MOVING -> walk (or run)
#    - BUILDING -> build (distinct dedicated clip)
#    - HARVESTING -> harvest (distinct dedicated clip)
#    - ATTACKING -> attack
#    - DEAD -> death
# 4. Hero dimensions strictly respect Config.HERO.width (0.8m) and height (1.6m).
#    Collider shape and physical hitbox are completely unaffected.
# 5. assets/CREDITS.md contains Hero model entry with CC0 dedication.
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

func _spawn_hero(pos: Vector3 = Vector3.ZERO) -> Hero:
	var h = Hero.new()
	_keep(h)
	tree.root.add_child(h)
	h.position = pos
	return h

# ==============================================================================
# 1. Asset Manifest & File Existence
# ==============================================================================

func test_01_hero_has_declared_scene_and_file_exists() -> void:
	assert_true(config_node != null and ("VISUALS" in config_node), "Config.VISUALS is available")
	var visuals: Dictionary = config_node.VISUALS
	assert_true(visuals.has("hero"), "Config.VISUALS has entry for hero")

	var entry: Dictionary = visuals["hero"]
	var scene_path: String = String(entry.get("scene", ""))
	assert_false(scene_path.is_empty(), "Hero scene path must not be empty")
	assert_eq(scene_path, "res://assets/models/quaternius/hero.glb", "Hero scene path points to the Hero (tools/build_hero.py)")
	assert_true(FileAccess.file_exists(scene_path), "File exists on disk: %s" % scene_path)
	assert_true(VisualLibrary.has_art("hero"), "VisualLibrary recognizes hero has real art")

# ==============================================================================
# 2. Animation Players & Clip Completeness
# ==============================================================================

func test_02_hero_instantiates_animator_and_has_real_animation_player() -> void:
	var hero = _spawn_hero()
	await wait_frames(2)

	assert_not_null(hero.animator, "Hero has ActorAnimator component")
	var anim_player: AnimationPlayer = hero.animator.animation_player
	assert_not_null(anim_player, "Hero visual model has real AnimationPlayer")

	var clips: PackedStringArray = anim_player.get_animation_list()
	assert_gt(clips.size(), 5, "Hero has at least 6 animations (has %d)" % clips.size())

	var clips_lower: Array = []
	for c in clips:
		clips_lower.append(c.to_lower())

	var required_clips = ["idle", "walk", "build", "harvest", "attack", "death"]
	for req in required_clips:
		assert_has(clips_lower, req, "Hero model possesses '%s' clip" % req)

# ==============================================================================
# 3. Full Coverage: All 6 Hero States Drive Dedicated Animations
# ==============================================================================

func test_03_all_six_hero_states_mapped_and_drive_animations() -> void:
	var hero = _spawn_hero()
	await wait_frames(2)
	hero.set_physics_process(false)

	var anim_player: AnimationPlayer = hero.animator.animation_player
	assert_not_null(anim_player, "Hero has AnimationPlayer")

	# 1. IDLE
	hero.current_state = Hero.State.IDLE
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "Playing animation on IDLE")
	assert_eq(anim_player.current_animation.to_lower(), "idle", "Plays idle on IDLE")

	# 2. MOVING
	hero.current_state = Hero.State.MOVING
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "Playing animation on MOVING")
	assert_has(["walk", "run"], anim_player.current_animation.to_lower(), "Plays walk/run on MOVING")

	# 3. BUILDING
	hero.current_state = Hero.State.BUILDING
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "Playing animation on BUILDING")
	assert_eq(anim_player.current_animation.to_lower(), "build", "Plays build on BUILDING")

	# 4. HARVESTING
	hero.current_state = Hero.State.HARVESTING
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "Playing animation on HARVESTING")
	assert_eq(anim_player.current_animation.to_lower(), "harvest", "Plays harvest on HARVESTING")

	# 5. ATTACKING
	hero.current_state = Hero.State.ATTACKING
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "Playing animation on ATTACKING")
	assert_eq(anim_player.current_animation.to_lower(), "attack", "Plays attack on ATTACKING")

	# 6. DEAD
	hero.current_state = Hero.State.DEAD
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "Playing animation on DEAD")
	assert_has(["death", "die"], anim_player.current_animation.to_lower(), "Plays death on DEAD")

	# Verify BUILDING and HARVESTING are distinctly different clips, not stubs or fallbacks
	assert_ne(config_node.ANIMATIONS["hero"]["BUILDING"], config_node.ANIMATIONS["hero"]["IDLE"],
		"BUILDING is distinct from IDLE")
	assert_ne(config_node.ANIMATIONS["hero"]["HARVESTING"], config_node.ANIMATIONS["hero"]["IDLE"],
		"HARVESTING is distinct from IDLE")
	assert_ne(config_node.ANIMATIONS["hero"]["BUILDING"], config_node.ANIMATIONS["hero"]["HARVESTING"],
		"BUILDING is distinct from HARVESTING")

# ==============================================================================
# 4. Dimensions & Collider Invariants
# ==============================================================================

func test_04_hero_dimensions_fit_and_collider_unchanged() -> void:
	var hero = _spawn_hero()
	await wait_frames(2)

	# 1. Physical collider verification
	var col_shape: CollisionShape3D = hero.collision_shape
	assert_not_null(col_shape, "Hero has collision shape")
	assert_true(col_shape.shape is BoxShape3D, "Collision shape is BoxShape3D")
	var box: BoxShape3D = col_shape.shape as BoxShape3D

	var expected_width: float = float(config_node.HERO.get("width", 0.8))
	var expected_height: float = float(config_node.HERO.get("height", 1.6))
	assert_almost_eq(box.size.x, expected_width, 0.01, "Collider width X == %.1fm" % expected_width)
	assert_almost_eq(box.size.y, expected_height, 0.01, "Collider height Y == %.1fm" % expected_height)
	assert_almost_eq(box.size.z, expected_width, 0.01, "Collider depth Z == %.1fm" % expected_width)
	assert_almost_eq(col_shape.position.y, expected_height * 0.5, 0.01, "Collider centered vertically")

	# 2. Visual mesh fitted inside declared boundary -- measured STANDING. The worker is
	# rigged in a T-pose, arms straight out, which is his rest shape and never on screen:
	# in play he is always in a clip. So he is put in his idle and the mesh measured as
	# posed (_posed_bounds).
	var body = hero.find_child("Body", false, false)
	assert_not_null(body, "Hero has Body node")
	if body == null:
		return
	var player: AnimationPlayer = hero.animator.animation_player if hero.animator else null
	assert_not_null(player, "He has clips to stand in")
	if player != null:
		player.play("idle")
		player.seek(0.0, true)
	await wait_frames(2)
	var into_body: Transform3D = (body as Node3D).global_transform.affine_inverse()
	var bounds := AABB()
	var first: bool = true
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var part: AABB = _posed_bounds(mi, into_body)
		bounds = part if first else bounds.merge(part)
		first = false

	var fitted_width: float = bounds.size.x
	var fitted_height: float = bounds.size.y
	var fitted_depth: float = bounds.size.z

	assert_lte(fitted_width, expected_width + 0.05, "Fitted visual width <= declared width (%.1fm)" % expected_width)
	assert_lte(fitted_height, expected_height + 0.05, "Fitted visual height <= declared height (%.1fm)" % expected_height)
	assert_lte(fitted_depth, expected_width + 0.05, "Fitted visual depth <= declared width (%.1fm)" % expected_width)
	# Standing in his idle he is a little shorter than his rest pose, and no more: a fit
	# that went wrong would show here as a man half his height.
	assert_gt(fitted_height, expected_height * 0.9,
		"Posed, he stands nearly all of his declared height (%.2f of %.2f m)" % [fitted_height, expected_height])

# ==============================================================================
# 5. Credits Ledger Completeness
# ==============================================================================

func test_05_credits_ledger_covers_hero_model() -> void:
	var credits_path: String = "res://assets/CREDITS.md"
	assert_true(FileAccess.file_exists(credits_path), "assets/CREDITS.md exists")
	var f = FileAccess.open(credits_path, FileAccess.READ)
	assert_not_null(f, "Can read assets/CREDITS.md")
	var text = f.get_as_text()
	f.close()

	assert_true(text.contains("hero.glb"), "CREDITS.md records hero.glb")
	assert_true(text.contains("hero.blend"), "CREDITS.md records hero.blend")
	assert_true(text.contains("Hero / Explorer"), "CREDITS.md records Hero / Explorer")
	assert_true(text.contains("CC0"), "CREDITS.md documents CC0 licensing")

## The bounds of `mi` as the skeleton poses it RIGHT NOW, in the space `into` maps to:
## every vertex moved by its bones -- current global pose times bind pose, weighted --
## which is the sum the renderer does. By hand, because the engine's own
## bake_mesh_from_current_skeleton_pose needs a skin registered with a real renderer, and
## these tests run headless. An unskinned mesh is just its box.
func _posed_bounds(mi: MeshInstance3D, into: Transform3D) -> AABB:
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if mi.skin == null or skel == null:
		return (into * mi.global_transform) * mi.get_aabb()
	var skin: Skin = mi.skin
	var bone_of: Array[Transform3D] = []
	for b in range(skin.get_bind_count()):
		var bone: int = skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		bone_of.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
	var to_space: Transform3D = into * skel.global_transform
	var out := AABB()
	var first: bool = true
	for s in range(mi.mesh.get_surface_count()):
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if verts.is_empty() or bones.is_empty():
			continue
		var per: int = bones.size() / verts.size()
		for i in range(verts.size()):
			var p := Vector3.ZERO
			for k in range(per):
				var w: float = weights[i * per + k]
				if w > 0.0:
					p += (bone_of[bones[i * per + k]] * verts[i]) * w
			var at: Vector3 = to_space * p
			if first:
				out = AABB(at, Vector3.ZERO)
				first = false
			else:
				out = out.expand(at)
	return out
