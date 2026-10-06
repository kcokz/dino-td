# res://tests/test_v07_the_rules.gd
# The player, 2026-10-03/04: "我认为系统咬合一定要简单清晰。逻辑上能扣住……玩家一想就能明白" (GAME-DESIGN 3.0).
#
# THE THREE RULES, and the table of what each animal is. Played, the game was held by five bow towers and wooden
# arrows made without end, the night's hunters shot down one by one by torchlight. So:
#   1. timber is one valley's worth (the trees do not grow back) -- towers, arrows and fires all take it;
#   2. bone and meat come only off what is killed;
#   3. in the dark a tower sees only what a light is on.
# And what pierces -- an arrow -- goes into an armoured animal for a quarter of itself: the armoured are for what
# crushes.
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
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

func _field() -> Array:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	return [gm, bs]

func _tower(bs: Node, type_id: String, cell: Vector2i, ammo: String) -> Node:
	stock_everything()
	var t = bs.place_at(type_id, cell, _world, false, 0)
	assert_not_null(t, "%s goes down" % type_id)
	if t == null:
		return null
	if not t.is_constructed:
		t.complete_construction()
	t.set_ammo(ammo)
	t.load_from_stock()
	return t

func _animal(species: String, at: Vector3) -> Node:
	var d = load(String(config_node.get_dino_script_path(species))).new()
	_cleanup_nodes.append(d)
	_world.add_child(d)
	d.setup(species)
	d.max_hp = 999.0
	d.current_hp = 999.0
	d.global_position = Vector3(at.x, 0.0, at.z)
	d.set_physics_process(false)
	return d

## The clock at `part` of the day (Config.DAY.parts), a little into it.
func _at(part: String) -> void:
	game_state_node.day_clock = float(config_node.DAY["parts"][part]) + 2.0

# ==============================================================================

func test_01_in_the_dark_a_tower_sees_only_what_a_light_is_on() -> void:
	var f: Array = await _field()
	var bow = _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_wood")
	var reach: float = float(config_node.BUILDINGS["bow_tower"]["range"])
	var d = _animal("coelophysis", bow.global_position + Vector3(reach * 0.6, 0.0, 0.0))
	var dark: Array = config_node.TOWERS["dark_parts"]
	assert_true(dark.has("night"), "the night is dark")
	_at("day")
	assert_eq(bow.target_in_reach(), d, "by day it sees what it reaches")
	_at("night")
	assert_true(bow.is_dark(), "(night)")
	assert_null(bow.target_in_reach(), "in the dark, with no light on it, nothing to shoot at")
	# A light on it -- a fire pot's burning ground is a light like any fire (FirePatch, ProwlerDino.lights).
	var patch = FirePatch.ignite(_world, d.global_position, config_node.AMMO["fire_pot"])
	_cleanup_nodes.append(patch)
	await wait_physics_frames(1)
	assert_gt(float(patch.light_radius()), 0.0, "the burning ground lights round it")
	assert_false(ProwlerDino.light_over(tree, d.global_position).is_empty(), "the animal is in its light")
	assert_eq(bow.target_in_reach(), d, "and in the light, the tower sees it")

func test_02_an_arrow_goes_into_armour_a_quarter() -> void:
	var f: Array = await _field()
	var bow = _tower(f[1], "bow_tower", Vector2i(0, 0), "arrow_wood")
	var armoured: String = ""
	for id in config_node.DINOS:
		if bool(config_node.DINOS[id].get("armored", false)):
			armoured = String(id)
			break
	assert_ne(armoured, "", "there is an armoured animal")
	var plain = _animal("coelophysis", bow.global_position + Vector3(3.0, 0.0, 0.0))
	var plated = _animal(armoured, bow.global_position + Vector3(-3.0, 0.0, 0.0))
	var arrow: Dictionary = config_node.AMMO["arrow_wood"]
	var stone: Dictionary = config_node.AMMO["shot_stone"]
	bow.strike(plain, arrow)
	bow.strike(plated, arrow)
	assert_almost_eq(999.0 - float(plain.current_hp), float(arrow["damage"]), 0.001, "an arrow's whole damage into the unarmoured")
	assert_almost_eq(999.0 - float(plated.current_hp), float(arrow["damage"]) * float(config_node.ARMOR["pierce"]), 0.001,
		"a quarter of it into the armoured")
	var before: float = float(plated.current_hp)
	bow.strike(plated, stone)
	assert_almost_eq(before - float(plated.current_hp), float(stone["damage"]), 0.001, "a stone's whole weight: armour does not turn it")
