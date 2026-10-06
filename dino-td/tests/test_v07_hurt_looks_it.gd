# res://tests/test_v07_hurt_looks_it.gd
# The player, 2026-10-05: "掉血的建筑应该有损坏的样子，cabin也需要有三个损坏阶段的样子".
#
# A BUILDING HURT LOOKS IT (Building._show_damage; Config.DAMAGE_LOOK): soot and cracks over its body past `from`,
# smoke out of its top past `smoke_from`, gone when it is mended. The cabin shows three stages besides
# (Config.CABIN.damage_stages; CabinArt "damage_<n>" parts of its model): scorched, its plates torn, holed through.
#
# Everything expected is read from Config.
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
	main.wave_manager.auto_raid_enabled = false
	await wait_frames(2)
	return main

func _build(main: Node, type_id: String, off: Vector3) -> Node:
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var b = main.build_system.place_at(type_id, main.grid_manager.world_to_build_cell(door + off), main.buildings_container)
	assert_not_null(b, "(a %s goes down by the cabin)" % type_id)
	if b != null:
		b.complete_construction()
	return b

func _overlaid(b: Node) -> bool:
	for mi in b._body_meshes():
		if mi.material_overlay != null:
			return true
	return false

func test_01_hurt_it_is_sooted_and_cracked_and_mended_it_is_not() -> void:
	var main = await _level()
	var tower = _build(main, "bow_tower", Vector3(0.0, 0.0, 4.0))
	if tower == null:
		return
	var look: Dictionary = config_node.DAMAGE_LOOK
	assert_false(_overlaid(tower), "Whole, nothing over it")
	tower.take_damage(float(tower.max_hp) * (float(look["from"]) * 0.5))
	assert_false(_overlaid(tower), "a scratch, nothing")
	tower.take_damage(float(tower.max_hp) * 0.4)
	assert_true(_overlaid(tower), "Hurt, soot and cracks over its body")
	var scars: ShaderMaterial = tower._body_meshes()[0].material_overlay as ShaderMaterial
	assert_not_null(scars, "(the overlay)")
	if scars:
		assert_almost_eq(float(scars.get_shader_parameter("damage")), float(tower.hurt()), 0.001, "as hurt as it is")
		assert_eq(scars.shader.resource_path, "res://assets/shaders/damage_overlay.gdshader", "(the soot's shader)")
	tower.heal(float(tower.max_hp))
	assert_false(_overlaid(tower), "Mended, gone")

func test_02_badly_hurt_it_smokes() -> void:
	var main = await _level()
	var tower = _build(main, "bow_tower", Vector3(0.0, 0.0, 4.0))
	if tower == null:
		return
	var from: float = float(config_node.DAMAGE_LOOK["smoke_from"])
	tower.take_damage(float(tower.max_hp) * (from - 0.1))
	var smoke: GPUParticles3D = tower.get_node_or_null("HurtSmoke") as GPUParticles3D
	assert_true(smoke == null or not smoke.emitting, "Less than smoke_from hurt: no smoke")
	tower.take_damage(float(tower.max_hp) * 0.25)
	smoke = tower.get_node_or_null("HurtSmoke") as GPUParticles3D
	assert_true(smoke != null and smoke.emitting, "More: smoke out of its top")
	tower.heal(float(tower.max_hp))
	assert_false(smoke.emitting, "Mended: none")

func test_03_the_cabins_three_stages() -> void:
	assert_eq(CabinArt.damage_stage_of("damage_2"), 2, "A part named for a stage of hurt")
	assert_eq(CabinArt.damage_stage_of("fade_damage_3"), 3, "faded with the roof or not")
	assert_eq(CabinArt.damage_stage_of("damage_3_spark"), 3, "(where its sparks are struck)")
	assert_eq(CabinArt.damage_stage_of("hull"), 0, "anything else is none")
	var main = await _level()
	var core = main.current_core
	var stages: Array = config_node.CABIN["damage_stages"]
	assert_eq(stages.size(), 3, "Three stages")
	var body: Node = core._body()
	var parts: Dictionary = {}
	for mi in CabinArt.parts(body):
		var n: int = CabinArt.damage_stage_of(String(mi.name))
		if n > 0:
			parts[n] = parts.get(n, []) + [mi]
	for n in [1, 2, 3]:
		assert_true(parts.has(n), "Its model has stage %d's parts" % n)
	for k in range(-1, 3):
		var share: float = 1.0 if k < 0 else float(stages[k]) - 0.01
		core.current_hp = float(core.max_hp) * share
		core._show_damage()
		var stage: int = k + 1
		assert_eq(core.hurt_stage(), stage, "At %d%% of its health, stage %d" % [int(share * 100.0), stage])
		for n in parts:
			for mi in parts[n]:
				assert_eq((mi as Node3D).visible, stage >= int(n), "%s shown at stage %d: %s" % [mi.name, stage, stage >= int(n)])
	var sparks: Node = body.find_child("Sparks", true, false)
	assert_true(sparks != null and sparks.emitting, "At its last stage, sparks out of its hole")
