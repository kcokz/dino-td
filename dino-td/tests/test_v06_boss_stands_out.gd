# res://tests/test_v06_boss_stands_out.gd
# v0.6 round three: "血槽不要画大，这个commit不要，真实感的游戏，你可以把boss恐龙通过一些方法突出出来，比如
# 掉血的时候血量大点".
#
# No bar across the screen for a boss: it is told apart in the world. The bar over an animal,
# shown once it is hurt, is longer over a boss -- by its rank (Config.FEEDBACK.boss_bar_scale) --
# and stands clear over the top of it, however tall it is (health_bar_lift).
#
# Everything expected is read from Config.
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

## One of the map's animals, standing where it is put, hit once so its bar is made.
func _hurt(species: String) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.take_damage(d.max_hp * 0.25)
	return d

func _length(d: Node) -> float:
	var span: Vector2 = d.status_bar.plate_span()
	return span.y - span.x

func test_01_a_boss_bar_is_longer_by_its_rank() -> void:
	var map: Dictionary = config_node.map_data()
	var plain = _hurt(String(map["raiders"].keys()[0]))
	var leader = _hurt(String(map["minor_boss"]))
	var boss = _hurt(String(map["boss"]))
	await wait_frames(1)
	var usual: float = float(config_node.FEEDBACK["health_bar_width"])
	var scale: Dictionary = config_node.FEEDBACK["boss_bar_scale"]
	assert_almost_eq(_length(plain), usual, 0.001, "A raider's bar is the usual length")
	assert_almost_eq(_length(leader), usual * float(scale["minor"]), 0.001, "a leader's longer")
	assert_almost_eq(_length(boss), usual * float(scale["major"]), 0.001, "the map's boss's longest")
	assert_gt(float(scale["major"]), float(scale["minor"]), "the boss above the leader")
	assert_true(boss.status_bar.visible, "Hurt, it shows")

func test_02_the_bar_stands_over_the_animal_however_tall() -> void:
	var map: Dictionary = config_node.map_data()
	for species in [String(map["raiders"].keys()[0]), String(map["boss"])]:
		var d = _hurt(species)
		var tall: float = float(config_node.get_visual_size("dino/" + species).y)
		assert_gt(d.status_bar.position.y, tall, "%s's bar is over its head, not in its back" % species)
		assert_almost_eq(d.status_bar.position.y, tall + float(config_node.FEEDBACK["health_bar_lift"]), 0.001,
			"by the lift")
