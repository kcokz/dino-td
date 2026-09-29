# res://tests/test_v06_what_can_be_worked.gd
# UI-POLISH T21 (v0.6 round four, the player): "能点的和不能点的要分得开……比如石头，树木，能点的个背景现在
# 很像" -- and "要还原真实": no ring or mark on them, told apart by what they are.
#
# The tree he cuts is a young conifer (Araucarioxylon, the Chinle's timber), where the forest round the
# field is tree ferns and cycads; the stone he quarries is a red-brown sandstone outcrop, where the
# valley's rocks are grey. Nothing the valley's scenery is drawn with is what he works. And what can be
# worked lifts a little under the cursor.
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
	super.after_each()

## Every model file named anywhere in `data`, however deep.
func _models_in(data: Variant, out: Dictionary) -> void:
	if data is Dictionary:
		for k in data:
			_models_in(data[k], out)
	elif data is Array:
		for v in data:
			_models_in(v, out)
	elif data is String and String(data).ends_with(".glb"):
		out[String(data)] = true

## What the valley's scenery is drawn with: the land's rocks and river, and everything that grows.
func _scenery() -> Dictionary:
	var out: Dictionary = {}
	_models_in(config_node.TERRAIN, out)
	_models_in(config_node.GROUND_COVER, out)
	for map_id in config_node.MAPS:
		_models_in(config_node.terrain_of(String(map_id)), out)
	return out

func _worked(res_id: String) -> Array:
	var row: Dictionary = config_node.VISUALS["node/" + res_id]
	var out: Array = [String(row["scene"])]
	if row.has("scene_depleted"):
		out.append(String(row["scene_depleted"]))
	return out

func test_01_the_tree_he_cuts_is_nothing_the_forest_is_drawn_with() -> void:
	var scenery: Dictionary = _scenery()
	assert_gt(scenery.size(), 5, "(the valley's scenery is found: %d models)" % scenery.size())
	for path in _worked("wood"):
		assert_false(scenery.has(path), "The tree he cuts is not the forest's: %s" % path)
		assert_true(ResourceLoader.exists(path), "(%s is there)" % path)

func test_02_the_stone_he_quarries_is_no_rock_the_valley_is_strewn_with() -> void:
	var scenery: Dictionary = _scenery()
	for path in _worked("stone"):
		assert_false(scenery.has(path), "The stone he quarries is not the valley's rocks: %s" % path)
		assert_true(ResourceLoader.exists(path), "(%s is there)" % path)

func test_03_what_can_be_worked_lifts_under_the_cursor_and_nothing_else() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var node: Node = null
	for n in tree.get_nodes_in_group("resource_nodes"):
		node = n
		break
	assert_not_null(node, "A tree or a rock")
	main._show_hover(node)
	var lifted: Array = main.lifted()
	assert_gt(lifted.size(), 0, "Pointed at, it lifts")
	for m in lifted:
		assert_true(node.find_child("Body", false, false).is_ancestor_of(m), "its body, not its ring or its bar")
		assert_not_null((m as MeshInstance3D).material_overlay, "(washed)")
	main._show_hover(null)
	assert_eq(main.lifted().size(), 0, "Pointed away, it does not")
	for m in lifted:
		assert_null((m as MeshInstance3D).material_overlay, "and nothing is left on it")
	main._show_hover(main.current_core)
	assert_eq(main.lifted().size(), 0, "The cabin -- a thing to click but not to work -- does not lift")
	main._show_hover(null)
