# res://tests/test_v07_the_work_seen.gd
# The player, 2026-10-04 ("改进2"): "造的塔首先要有造的阶段样子，不能直接就成型，至少要有四个阶段的成型前样子，升级也要有两个阶
# 段"; "塔在升级的时候不能进攻"; "人在造塔的时候要有敲打的动作，而不是跪下来，维修也是".
#
# A tower going up is drawn in stages (Config.CONSTRUCTION): ordered and not begun, its ghost; then four stages, each as
# much more of it standing from the ground up and nothing above, inside scaffolding that climbs with it; whole when
# done, the scaffolding gone. Built onto -- an upgrade -- its scaffolding in two stages. A stake is cut in stages too,
# with no scaffolding round it. And he works at it standing, his hammer in his hand, its knock on its blow.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _world: Node3D = null

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
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _field() -> Node:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	return bs

func _spec() -> Dictionary:
	return config_node.CONSTRUCTION

## The height `b` is cut at now (the world's), or INF where nothing of it is cut.
func _cut(b: Node) -> float:
	var lowest: float = INF
	for mi in b._body_meshes():
		var sm := (mi as MeshInstance3D).material_override as ShaderMaterial
		if sm != null and sm.shader == Building._cut_shader():
			lowest = minf(lowest, float(sm.get_shader_parameter("cut")))
	return lowest

func _scaffold_top(b: Node) -> float:
	var frame: Node = b.get_node_or_null("Scaffold")
	if frame == null or frame.is_queued_for_deletion():
		return 0.0
	var top: float = 0.0
	for pole in frame.get_children():
		if pole is MeshInstance3D and (pole as MeshInstance3D).mesh is CylinderMesh and absf((pole as MeshInstance3D).rotation.z) < 0.01 \
				and absf((pole as MeshInstance3D).rotation.x) < 0.01:
			top = maxf(top, float(((pole as MeshInstance3D).mesh as CylinderMesh).height))
	return top

func test_01_a_tower_goes_up_in_four_stages_inside_its_scaffolding() -> void:
	var bs = await _field()
	stock_everything()
	var bow = bs.place_at("bow_tower", Vector2i(0, 0), _world, true)
	assert_not_null(bow, "(a bow tower ordered)")
	var height: float = float(config_node.get_building_height("bow_tower"))
	var stages: Array = _spec()["stages"]
	assert_gte(stages.size(), 4, "At least four stages before it is whole")
	assert_eq(int(bow.work_stage()), 0, "Ordered, not begun: no stage")
	assert_eq(_cut(bow), INF, "its ghost, not cut")
	assert_eq(_scaffold_top(bow), 0.0, "no scaffolding yet")
	var last_cut: float = -INF
	var last_top: float = 0.0
	for k in stages.size():
		bow.build_progress = (float(k) + 0.5) / float(stages.size())
		bow._update_visuals_progress()
		assert_eq(int(bow.work_stage()), k + 1, "a share of the work: stage %d" % (k + 1))
		var cut: float = _cut(bow)
		assert_almost_eq(cut - bow.global_position.y, height * float(stages[k]), 0.001,
			"stage %d: as much of it standing as the stage says, nothing above" % (k + 1))
		assert_gt(cut, last_cut, "more of it each stage")
		var top: float = _scaffold_top(bow)
		assert_gt(top, last_top, "its scaffolding climbing with it (%.2f m)" % top)
		assert_gt(top, cut - bow.global_position.y, "over the work")
		last_cut = cut
		last_top = top
	bow.complete_construction()
	await wait_frames(1)
	assert_eq(int(bow.work_stage()), 0, "Done: no stage")
	assert_eq(_cut(bow), INF, "whole")
	assert_eq(_scaffold_top(bow), 0.0, "the scaffolding gone")
	for mi in bow._body_meshes():
		var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null:
			assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "its own material, solid")

func test_02_built_onto_its_scaffolding_goes_up_in_two() -> void:
	var bs = await _field()
	stock_everything()
	var bow = bs.place_at("bow_tower", Vector2i(0, 0), _world, false)
	if not bow.is_constructed:
		bow.complete_construction()
	var to: String = String(config_node.upgrade_targets("bow_tower")[0])
	assert_true(bow.begin_upgrade(to), "(an upgrade ordered)")
	var n: int = int(_spec()["upgrade_stages"])
	assert_gte(n, 2, "At least two stages to an upgrade")
	assert_eq(int(bow.work_stage()), 1, "Begun: its first stage")
	var first: float = _scaffold_top(bow)
	assert_gt(first, 0.0, "scaffolding round it")
	assert_eq(_cut(bow), INF, "itself still whole under it")
	bow.add_upgrade_progress(float(config_node.get_upgrade_time("bow_tower", to)) * 0.6)
	assert_eq(int(bow.work_stage()), 2, "then its second")
	assert_gt(_scaffold_top(bow), first, "the scaffolding to its top")
	bow.add_upgrade_progress(1000.0)
	await wait_frames(2)
	for t in tree.get_nodes_in_group(AmmoTower.GROUP):
		if is_instance_valid(t) and String(t.building_type) == to:
			assert_eq(_scaffold_top(t), 0.0, "Done: the scaffolding gone")

func test_03_a_stake_goes_up_in_stages_with_no_scaffolding() -> void:
	var bs = await _field()
	stock_everything()
	var wall = bs.place_at("wall", Vector2i(0, 0), _world, true)
	assert_not_null(wall, "(a stake ordered)")
	assert_lt(float(config_node.get_building_height("wall")), float(_spec()["scaffold_from_height"]), "(lower than scaffolding is put round)")
	wall.build_progress = 0.3
	wall._update_visuals_progress()
	assert_lt(_cut(wall), INF, "Going up, it is cut at its stage")
	assert_eq(_scaffold_top(wall), 0.0, "with no scaffolding round a stake")

func test_04_he_works_standing_his_hammer_in_his_hand_the_knock_on_the_blow() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	var hero = main.hero
	hero.set_physics_process(false)
	hero.current_state = Hero.State.BUILDING
	await wait_frames(2)
	assert_true(hero.has_hammer_out(), "At work, his hammer is out")
	var anim: Animation = hero.animator.animation_for(String(config_node.ANIMATIONS["hero"]["BUILDING"]))
	assert_not_null(anim, "(his build clip)")
	if anim != null:
		# Standing: his hips at the height they are standing idle, not down on one knee.
		var sk: Skeleton3D = hero.find_child("Body", false, false).find_children("*", "Skeleton3D", true, false)[0]
		var hips: int = sk.find_bone("pelvis")
		var idle: Animation = hero.animator.animation_for("idle")
		var keys := {}
		var idle_keys := {}
		for t in anim.get_track_count():
			var path: NodePath = anim.track_get_path(t)
			if path.get_subname_count() > 0 and sk.find_bone(String(path.get_subname(0))) == hips:
				keys[anim.track_get_type(t)] = t
		for t in idle.get_track_count():
			var path: NodePath = idle.track_get_path(t)
			if path.get_subname_count() > 0 and sk.find_bone(String(path.get_subname(0))) == hips:
				idle_keys[idle.track_get_type(t)] = t
		if keys.has(Animation.TYPE_POSITION_3D) and idle_keys.has(Animation.TYPE_POSITION_3D):
			var low: float = INF
			for k in 21:
				low = minf(low, anim.position_track_interpolate(keys[Animation.TYPE_POSITION_3D], anim.length * float(k) / 20.0).y)
			var stand: float = idle.position_track_interpolate(idle_keys[Animation.TYPE_POSITION_3D], 0.0).y
			assert_gt(low, stand * 0.9, "He stands to it: his hips no lower than standing (%.2f of %.2f)" % [low, stand])
		# The knock a blow: the clip as many blows long as the knock's beat goes into it.
		var every: float = float(config_node.SOUNDS["hammer_every"])
		var blows: float = anim.length / every
		assert_almost_eq(blows, round(blows), 0.02, "the knock heard on each blow: %.2f blows to the clip" % blows)
	hero.current_state = Hero.State.IDLE
	await wait_frames(2)
	assert_false(hero.has_hammer_out(), "His work done, it is put away")
