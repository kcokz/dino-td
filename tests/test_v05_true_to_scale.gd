# res://tests/test_v05_true_to_scale.gd
# Proportion: everything that stands in the valley, sized against the Hero.
#
# Reported as "人模型太大，比恐龙都大了" -- the Hero was 1.6 m, as tall as the tyrannosaur
# and twice the height of a raptor, in a world whose stakes, trees and cabin were built for
# someone about 1.2 m tall. No single portrait looked wrong: each is framed to fill the
# picture. Proportion only shows side by side, so these tests measure it side by side --
# the models as the game draws them, not the numbers Config declares.
#
# And stature is ONLY stature: what the game touches -- the widths fences and lanes are
# built on, where a dinosaur looks for what is in its way -- does not move with it.
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

func _dino(kind: String) -> Node:
	var d = load("res://scripts/entities/Dino.gd").new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup(kind)
	d.set_physics_process(false)
	return d

## How big `node`'s body is drawn, in the world.
func _drawn(node: Node) -> AABB:
	var body: Node3D = node.find_child("Body", false, false)
	return VisualLibrary.visual_bounds(body) if body != null else AABB()

func _hero_height() -> float:
	return float(config_node.HERO["height"])

func test_01_the_hero_is_the_size_a_person_is_here() -> void:
	var h: float = _hero_height()
	var stake: float = float(config_node.get_building_height("wall"))
	var fern: float = (config_node.RESOURCE_NODES["wood"]["size"] as Vector3).y
	assert_between(stake / h, 0.6, 0.9, "A stake comes to his chest (%.2f of his height)" % (stake / h))
	assert_gte(fern / h, 2.5, "A tree fern is well over twice his height (%.1fx)" % (fern / h))

func test_02_the_tyrannosaur_towers_over_him() -> void:
	var d = _dino("big_theropod")
	await wait_frames(1)
	var drawn: AABB = _drawn(d)
	assert_gte(drawn.size.y / _hero_height(), 2.2,
		"It stands at least twice and a bit his height (%.1fx)" % (drawn.size.y / _hero_height()))
	assert_gte(drawn.size.z, 4.0 * _hero_height(), "And is as long as four of him laid end to end")

func test_03_a_raptor_comes_to_his_chest_and_is_longer_than_he_is_tall() -> void:
	var d = _dino("raptor")
	await wait_frames(1)
	var drawn: AABB = _drawn(d)
	var h: float = _hero_height()
	assert_between(drawn.size.y / h, 0.6, 0.9, "Head at his chest (%.2f of his height)" % (drawn.size.y / h))
	assert_gte(drawn.size.z, 1.5 * h, "Nose to tail, longer than he is tall (%.2f m)" % drawn.size.z)

func test_04_stature_changes_nothing_the_game_touches() -> void:
	# Every species looks for what is in its way below the top of a stake -- the lowest
	# thing that stops one. At half its own height a three-metre tyrannosaur looked over a
	# stake and walked into it.
	var stake: float = float(config_node.get_building_height("wall"))
	for kind in config_node.DINOS:
		var d = _dino(String(kind))
		await wait_frames(1)
		var ray: RayCast3D = d.raycast
		assert_not_null(ray, "The %s looks ahead" % kind)
		if ray != null:
			assert_lt(ray.position.y, stake, "The %s looks below the top of a stake (%.2f m)" % [kind, ray.position.y])
	# The Hero's width, not his height, decides how much of a tile a building may fill.
	var default_fp: float = float(config_node.get_default_building_footprint())
	assert_almost_eq(default_fp, float(config_node.TILE_SIZE) - float(config_node.HERO["width"])
		- float(config_node.BUILDING_CLEARANCE), 0.0001, "A building's footprint still comes from his width")

func test_05_the_herds_are_on_the_tyrannosaurs_scale() -> void:
	var rex = _dino("big_theropod")
	await wait_frames(1)
	var ruler: float = _drawn(rex).size.z
	var lengths: Dictionary = {}
	for spec in config_node.HERDS["herds"]:
		lengths[String(spec["species"])] = float(spec["length"])
	assert_gte(lengths["apatosaurus"] / ruler, 1.5, "A sauropod is well over a tyrannosaur's length")
	for species in ["parasaurolophus", "triceratops", "stegosaurus"]:
		assert_between(lengths[species] / ruler, 0.6, 0.95,
			"A %s is most of a tyrannosaur's length (%.2f)" % [species, lengths[species] / ruler])

func test_06_the_hero_is_built_like_a_person_not_a_cartoon() -> void:
	# Reported as "人不应该带个安全帽，显得太卡通了，应该就是写实风格的人物形象": the worker
	# was a big head on a short body -- its head joint two thirds of the way up it, the head
	# a third of the whole figure. A person's head is about an eighth of their height, the
	# joint nine tenths of the way up.
	var body: Node3D = VisualLibrary.make("hero")
	_cleanup_nodes.append(body)
	tree.root.add_child(body)
	await wait_frames(1)
	var drawn: AABB = VisualLibrary.visual_bounds(body)
	var head_y: float = -INF
	for sk in body.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		var i: int = s.find_bone("Head")
		if i >= 0:
			head_y = (s.global_transform * s.get_bone_global_rest(i)).origin.y
	assert_gt(head_y, -INF, "He has a head bone called Head")
	var up: float = (head_y - drawn.position.y) / maxf(0.001, drawn.size.y)
	assert_gte(up, 0.82, "His head is a person's size for his height (joint %.2f of the way up)" % up)
	# And bare-headed.
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var n: String = String(mi.name).to_lower()
		assert_false(n.contains("hat") or n.contains("helmet") or n.contains("cap"), "%s is not headgear" % mi.name)

func assert_between(value: float, lo: float, hi: float, message: String) -> void:
	assert_gte(value, lo, message)
	assert_lte(value, hi, message)
