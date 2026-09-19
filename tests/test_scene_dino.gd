# res://tests/test_scene_dino.gd
# SCENE-POLISH S3: Dinosaur Models & Animation Rigging Verification Suite.
#
# Acceptance criteria from SCENE-POLISH.md:
# 1. VISUALS.scene non-empty and files exist on disk for raptor, big_theropod, pterosaur.
# 2. test_v05_visual_library.gd scale invariants preserved (big theropod is larger than raptor).
# 3. All 3 species resolve real AnimationPlayers with idle, run/walk, attack, death clips.
# 4. Graceful degradation and state transition verification across species.
# 5. assets/CREDITS.md covers all 3 models.
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

func _spawn_dino(type_id: String, pos: Vector3 = Vector3.ZERO) -> Dino:
	var d = Dino.new(type_id)
	_keep(d)
	tree.root.add_child(d)
	d.position = pos
	d.setup(type_id)
	return d

# ==============================================================================
# 1. Asset Manifest & File Existence
# ==============================================================================

func test_01_all_three_dinos_have_declared_scene_and_files_exist() -> void:
	assert_true(config_node != null and ("VISUALS" in config_node), "Config.VISUALS is available")
	var visuals: Dictionary = config_node.VISUALS

	var species_keys = ["dino/raptor", "dino/big_theropod", "dino/pterosaur"]
	for k in species_keys:
		assert_true(visuals.has(k), "Config.VISUALS has entry for %s" % k)
		var entry: Dictionary = visuals[k]
		var scene_path: String = String(entry.get("scene", ""))
		assert_false(scene_path.is_empty(), "Scene path for %s must not be empty" % k)
		assert_true(FileAccess.file_exists(scene_path), "File exists on disk for %s: %s" % [k, scene_path])

# ==============================================================================
# 2. Animation Players & Clip Completeness
# ==============================================================================

func test_02_all_three_dinos_have_real_animation_players_and_clips() -> void:
	var species_list = ["raptor", "big_theropod", "pterosaur"]
	var required_clips = ["idle", "attack", "death"]

	for species in species_list:
		var dino = _spawn_dino(species)
		await wait_frames(2)

		assert_not_null(dino.animator, "%s has ActorAnimator component" % species)
		var anim_player: AnimationPlayer = dino.animator.animation_player
		assert_not_null(anim_player, "%s visual model has real AnimationPlayer" % species)

		var clips: PackedStringArray = anim_player.get_animation_list()
		assert_gt(clips.size(), 3, "%s has at least 4 animations (has %d)" % [species, clips.size()])

		var clips_lower: Array = []
		for c in clips:
			clips_lower.append(c.to_lower())

		for req in required_clips:
			assert_has(clips_lower, req, "%s model possesses '%s' clip" % [species, req])

		# Locomotion clip: either 'run' or 'walk'
		var has_locomotion: bool = ("run" in clips_lower) or ("walk" in clips_lower)
		assert_true(has_locomotion, "%s possesses locomotion clip ('run' or 'walk')" % species)

# ==============================================================================
# 3. Scale Invariants (Big Theropod > Raptor)
# ==============================================================================

func test_03_scale_invariants_big_theropod_strictly_larger_than_raptor() -> void:
	var raptor = _spawn_dino("raptor", Vector3(-4.0, 0.0, 0.0))
	var big_t = _spawn_dino("big_theropod", Vector3(4.0, 0.0, 0.0))
	await wait_frames(2)

	# 1. Declared config size verification
	var raptor_cfg_size: Vector3 = config_node.DINOS["raptor"]["size"]
	var big_t_cfg_size: Vector3 = config_node.DINOS["big_theropod"]["size"]
	assert_gt(big_t_cfg_size.x, raptor_cfg_size.x, "Config big_theropod X > raptor X")
	assert_gt(big_t_cfg_size.y, raptor_cfg_size.y, "Config big_theropod Y > raptor Y")
	assert_gt(big_t_cfg_size.z, raptor_cfg_size.z, "Config big_theropod Z > raptor Z")

	# 2. Fitted VisualLibrary bounds verification
	var raptor_body = raptor.find_child("Body", false, false)
	var big_t_body = big_t.find_child("Body", false, false)
	assert_not_null(raptor_body, "Raptor has Body node")
	assert_not_null(big_t_body, "Big Theropod has Body node")

	var raptor_bounds: AABB = VisualLibrary.visual_bounds(raptor_body)
	var big_t_bounds: AABB = VisualLibrary.visual_bounds(big_t_body)

	# The fitted art in world units scales with the declared size
	assert_gt(big_t_bounds.size.y * big_t_body.scale.y, raptor_bounds.size.y * raptor_body.scale.y,
		"Big Theropod fitted height is taller than Raptor fitted height")

# ==============================================================================
# 4. State Transitions across all 3 Species
# ==============================================================================

func test_04_state_transitions_drive_animations_on_all_three_species() -> void:
	var species_list = ["raptor", "big_theropod", "pterosaur"]

	for species in species_list:
		var dino = _spawn_dino(species)
		await wait_frames(2)
		dino.set_physics_process(false)

		var anim_player: AnimationPlayer = dino.animator.animation_player

		# Walking
		dino.current_state = Dino.State.WALKING
		await wait_frames(2)
		assert_true(anim_player.is_playing(), "%s is playing animation on WALKING" % species)
		assert_has(["run", "walk"], anim_player.current_animation.to_lower(),
			"%s plays locomotion animation on WALKING" % species)

		# Attacking
		dino.current_state = Dino.State.ATTACKING
		await wait_frames(2)
		assert_true(anim_player.is_playing(), "%s is playing animation on ATTACKING" % species)
		assert_has(["attack", "bite"], anim_player.current_animation.to_lower(),
			"%s plays attack animation on ATTACKING" % species)

		# Dead
		dino.current_state = Dino.State.DEAD
		await wait_frames(2)
		assert_true(anim_player.is_playing(), "%s is playing animation on DEAD" % species)
		assert_has(["death", "die", "dead"], anim_player.current_animation.to_lower(),
			"%s plays death animation on DEAD" % species)

# ==============================================================================
# 5. Credits Ledger Completeness
# ==============================================================================

func test_05_credits_ledger_covers_all_three_dinosaur_models() -> void:
	var credits_path: String = "res://assets/CREDITS.md"
	assert_true(FileAccess.file_exists(credits_path), "assets/CREDITS.md exists")
	var f = FileAccess.open(credits_path, FileAccess.READ)
	assert_not_null(f, "Can read assets/CREDITS.md")
	var text = f.get_as_text()
	f.close()

	assert_true(text.contains("t_rex.glb"), "CREDITS.md records t_rex.glb")
	assert_true(text.contains("raptor.glb"), "CREDITS.md records raptor.glb")
	assert_true(text.contains("pterosaur.glb"), "CREDITS.md records pterosaur.glb")
	assert_true(text.contains("CC0"), "CREDITS.md documents CC0 licensing")
