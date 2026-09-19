# res://tests/test_scene_animation.gd
# SCENE-POLISH S2: Animation State Machine Interface & Decoupling Rig.
#
# The Constitution & SCENE-POLISH rules require:
# 1. Decoupling: Entities report their State enum; ActorAnimator resolves the clip via Config.ANIMATIONS.
# 2. Config fidelity: Every mapped state exists in entity State enums; tests derive expectations from Config.
# 3. Graceful degradation: Entities without AnimationPlayers or missing clips work without errors or crashes.
# 4. Rigged model trial: t_rex.glb drives actual animations when state transitions occur.
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

func _spawn_dino(type_id: String = "raptor", pos: Vector3 = Vector3.ZERO) -> Dino:
	var d = Dino.new(type_id)
	_keep(d)
	tree.root.add_child(d)
	d.position = pos
	d.setup(type_id)
	return d

# ==============================================================================
# 1. Config Table Completeness & Enumeration Symmetry
# ==============================================================================

func test_01_config_animations_table_declares_all_entity_states() -> void:
	assert_true(config_node != null and ("ANIMATIONS" in config_node),
		"Config has ANIMATIONS table")
	var anim_cfg: Dictionary = config_node.ANIMATIONS

	assert_true(anim_cfg.has("blend_time"), "Declares animation blend_time")
	assert_gt(float(anim_cfg["blend_time"]), 0.0, "Blend time is positive")

	# Hero states symmetry
	assert_true(anim_cfg.has("hero"), "ANIMATIONS declares hero state mappings")
	var hero_map: Dictionary = anim_cfg["hero"]
	for state_name in hero_map:
		assert_true(Hero.State.has(state_name),
			"Config hero animation state '%s' exists in Hero.State enum" % state_name)
	for state_name in Hero.State.keys():
		assert_true(hero_map.has(state_name),
			"Every Hero.State ('%s') is covered in Config.ANIMATIONS" % state_name)

	# Dino states symmetry
	assert_true(anim_cfg.has("dino"), "ANIMATIONS declares dino state mappings")
	var dino_map: Dictionary = anim_cfg["dino"]
	for state_name in dino_map:
		assert_true(Dino.State.has(state_name),
			"Config dino animation state '%s' exists in Dino.State enum" % state_name)
	for state_name in Dino.State.keys():
		assert_true(dino_map.has(state_name),
			"Every Dino.State ('%s') is covered in Config.ANIMATIONS" % state_name)

# ==============================================================================
# 2. State Reporting & Clip Name Derivation (Decoupling)
# ==============================================================================

func test_02_hero_state_change_updates_requested_clip_from_config() -> void:
	var hero = _spawn_hero()
	await wait_frames(1)

	assert_not_null(hero.animator, "Hero instantiates ActorAnimator")

	var hero_anim_cfg: Dictionary = config_node.ANIMATIONS["hero"]

	for state_name in Hero.State.keys():
		var enum_val: int = Hero.State[state_name]
		hero.current_state = enum_val

		var expected_clip: String = hero_anim_cfg[state_name]
		assert_eq(hero.animator.requested_clip, expected_clip,
			"Hero state '%s' requests clip '%s' derived from Config" % [state_name, expected_clip])

func test_03_dino_state_change_updates_requested_clip_from_config() -> void:
	var dino = _spawn_dino("raptor")
	await wait_frames(1)

	assert_not_null(dino.animator, "Dino instantiates ActorAnimator")

	var dino_anim_cfg: Dictionary = config_node.ANIMATIONS["dino"]

	for state_name in Dino.State.keys():
		var enum_val: int = Dino.State[state_name]
		dino.current_state = enum_val

		var expected_clip: String = dino_anim_cfg[state_name]
		assert_eq(dino.animator.requested_clip, expected_clip,
			"Dino state '%s' requests clip '%s' derived from Config" % [state_name, expected_clip])

# ==============================================================================
# 3. Graceful Degradation (No AnimationPlayer, Missing Clips)
# ==============================================================================

func test_04_entities_without_animation_player_operate_without_errors() -> void:
	# Entity without AnimationPlayer must degrade silently
	var dino = _spawn_dino("raptor")
	await wait_frames(1)

	if dino.animator.animation_player != null:
		dino.animator.stop()
		dino.animator.animation_player.free()
		dino.animator.refresh_animation_player()

	assert_null(dino.animator.animation_player, "Entity has no AnimationPlayer")

	# Cycling through states should not throw errors or fail
	dino.current_state = Dino.State.WALKING
	assert_eq(dino.animator.current_clip, "", "Current clip is empty without animation player")

	dino.current_state = Dino.State.ATTACKING
	assert_eq(dino.animator.current_clip, "", "Current clip remains empty without errors")

	dino.current_state = Dino.State.DEAD
	assert_true(dino.is_dead or dino.current_state == Dino.State.DEAD, "Dino reaches dead state safely")

func test_05_animator_tolerates_invalid_states_and_null_actor() -> void:
	var standalone = ActorAnimator.new()
	_keep(standalone)
	tree.root.add_child(standalone)

	# Setup with dummy/empty
	standalone.setup(null, "unknown")
	standalone.play_state("NON_EXISTENT_STATE")
	assert_eq(standalone.requested_clip, "", "Unknown state results in empty clip request")
	standalone.play_clip("imaginary_clip")
	standalone.stop()

# ==============================================================================
# 4. Verification with Rigged Model (t_rex.glb)
# ==============================================================================

func test_06_t_rex_drives_animation_player_across_states() -> void:
	var dino = _spawn_dino("big_theropod")
	await wait_frames(2)

	var anim_player: AnimationPlayer = dino.animator.animation_player
	assert_not_null(anim_player, "t_rex model contains real AnimationPlayer")

	# Suspend autonomous AI target resolution so manual State assignments are tested cleanly
	dino.set_physics_process(false)

	# WALKING state -> drives walk/run animation
	dino.current_state = Dino.State.WALKING
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "AnimationPlayer is playing during WALKING")
	assert_has(["run", "walk"], anim_player.current_animation.to_lower(),
		"Plays walking/running animation for WALKING")

	# ATTACKING state -> transitions to attack
	dino.current_state = Dino.State.ATTACKING
	await wait_frames(2)
	assert_true(anim_player.is_playing(), "AnimationPlayer is playing during ATTACKING")
	assert_has(["attack", "bite"], anim_player.current_animation.to_lower(),
		"Plays attack animation for ATTACKING")
