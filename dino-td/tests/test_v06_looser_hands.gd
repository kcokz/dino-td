# res://tests/test_v06_looser_hands.gd
# v0.6 round three: "木头和石头太紧就影响建造的乐趣，守卫也难了很多，你可以想想怎么解决，或者平衡调整，肉骨太
# 多可以让死了的恐龙随机掉落解决".
#
# A run was short of wood and stone and long on meat and bone. Now the rank and file leave meat and
# bone only by chance (Config.DINOS[..].drop_chance) -- but never missing the first of a run, and
# never more than DROPS.pity_after times running, so chance may leave him more, never stuck; a
# boss always leaves its own. And stone need not mean a fight with the nest's guards: an outcrop
# stands on the cabin's far side.
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
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game(4242)
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	for d in tree.get_nodes_in_group("drops"):
		if is_instance_valid(d):
			d.free()
	super.after_each()

func _ground(res_id: String) -> int:
	var n: int = 0
	for d in tree.get_nodes_in_group("drops"):
		if is_instance_valid(d) and not d.is_queued_for_deletion() and String(d.resource_type) == res_id:
			n += int(d.amount)
	return n

func _kill(species: String, at: Vector3) -> void:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup(species)
	d.set_physics_process(false)
	d.global_position = at
	d.take_damage(d.max_hp * 10.0)

func test_01_the_rank_and_file_leave_meat_and_bone_by_chance() -> void:
	var species: String = String(config_node.map_data()["raiders"].keys()[0])
	var chances: Dictionary = config_node.DINOS[species].get("drop_chance", {})
	assert_true(chances.has("bone") and chances.has("food"), "%s leaves its meat and bone by chance" % species)
	var pity: int = int(config_node.DROPS["pity_after"])
	var kills: int = 40
	var bone_before: int = 0
	var misses_running: int = 0
	var worst_run: int = 0
	var first: int = -1
	for i in kills:
		_kill(species, Vector3(40.0 + float(i % 8) * 3.0, 0.0, 40.0 + float(i / 8) * 3.0))
		await wait_frames(1)
		var got: int = _ground("bone") - bone_before
		bone_before = _ground("bone")
		if first < 0:
			first = got
		misses_running = 0 if got > 0 else misses_running + 1
		worst_run = maxi(worst_run, misses_running)
	var per_kill: int = int(config_node.DINOS[species]["drops"]["bone"])
	assert_gt(first, 0, "The first of a run always leaves its bone -- the first raid's bone is the pick")
	assert_lte(worst_run, pity, "Never more than %d missed running" % pity)
	assert_lt(bone_before, kills * per_kill, "Fewer than every one (%d of %d)" % [bone_before, kills * per_kill])
	assert_gte(bone_before, int(float(kills * per_kill) / float(pity + 1)), "and at least one in %d" % (pity + 1))

func test_02_a_boss_always_leaves_its_own() -> void:
	var leader: String = String(config_node.map_data()["minor_boss"])
	assert_false(config_node.DINOS[leader].has("drop_chance"), "The leader is not left to chance")
	_kill(leader, Vector3(50.0, 0.0, 50.0))
	await wait_frames(1)
	for res_id in config_node.DINOS[leader]["drops"]:
		assert_eq(_ground(String(res_id)), int(config_node.DINOS[leader]["drops"][res_id]), "All its %s" % res_id)

func test_03_a_new_run_starts_the_chance_over() -> void:
	game_state_node.drop_misses["bone"] = 0
	game_state_node.reset_game(7)
	assert_true(game_state_node.drop_misses.is_empty(), "A new run: nothing missed yet")
	assert_true(game_state_node.roll_drop("bone", 0.0), "and its first falls whatever the chance")
	assert_false(game_state_node.roll_drop("bone", 0.0), "the next only by chance")
	assert_true(game_state_node.roll_drop("bone", 0.0), "and never missed more than %d running" % int(config_node.DROPS["pity_after"]))

func test_04_stone_that_is_not_by_the_nest() -> void:
	var map: Dictionary = config_node.map_data()
	var nest: Vector2i = map["default_nest_cell"]
	var cabin: Vector2i = map["default_core_cell"]
	var cabin_to_nest: float = Vector2(cabin - nest).length()
	var far_side: bool = false
	for node in map["default_resource_nodes"]:
		if String(node["type"]) == "stone" and Vector2(Vector2i(node["cell"]) - nest).length() > cabin_to_nest:
			far_side = true
	assert_true(far_side, "An outcrop further from the nest than the cabin is: stone without the guards")
	var trees: int = 0
	for node in map["default_resource_nodes"]:
		if String(node["type"]) == "wood":
			trees += 1
	assert_gte(trees, 3, "and more than two trees to cut")
