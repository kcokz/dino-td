# res://tests/test_v07_the_iron_palisade.gd
# The player, 2026-10-05: "把后面几关都先做起来，主要是科技树升级部分".
#
# THE IRON PALISADE (GAME-DESIGN 5.3's fence line: "木栅栏 → 骨尖栅栏 → 铁蒺藜（铁 + 木，4）"): the bone palisade's points
# forged in iron where it stands -- the iron its only new price; the same section, biting harder and lasting longer;
# offered once he has made iron, not before.
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

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

func _row(type_id: String) -> Dictionary:
	return config_node.BUILDINGS[type_id]

func test_01_the_bone_palisade_is_forged_in_iron_where_it_stands() -> void:
	assert_true(config_node.BUILDINGS.has("iron_stake"), "There is an iron palisade")
	if not config_node.BUILDINGS.has("iron_stake"):
		return
	assert_has(config_node.upgrade_targets("bone_stake"), "iron_stake", "The bone palisade becomes it")
	assert_false(config_node.BUILDABLE_TYPES.has("iron_stake"), "where it stands -- no entry of the build menu")
	var bone: Dictionary = _row("bone_stake")
	var iron: Dictionary = _row("iron_stake")
	var more: Dictionary = {}
	for res_id in iron["cost"]:
		var extra: int = int(iron["cost"][res_id]) - int(bone["cost"].get(res_id, 0))
		if extra > 0:
			more[res_id] = extra
	assert_eq(config_node.upgrade_cost("bone_stake", "iron_stake"), more, "The difference is its price")
	assert_eq(more.keys(), ["iron"], "and that is iron alone: the wood and the bone are there already")
	for key in ["kind", "cells", "height"]:
		assert_eq(iron[key], bone[key], "The same section (%s)" % key)
	assert_gt(config_node.get_contact_dps("iron_stake"), config_node.get_contact_dps("bone_stake"), "It bites harder")
	assert_gt(float(iron["hp"]), float(bone["hp"]), "and lasts longer")
	assert_eq(String(config_node.upgrade_target("iron_stake")), "", "The last of its line")

func test_02_offered_once_he_has_made_iron() -> void:
	var price: Dictionary = config_node.upgrade_cost("bone_stake", "iron_stake")
	game_state_node.known.erase("iron")
	assert_false(game_state_node.within_reach(price), "Before he has made iron, there is no iron palisade to be had")
	game_state_node.known["iron"] = true
	assert_true(game_state_node.within_reach(price), "Once he has, there is")

func test_03_standing_it_bites_by_its_own_row() -> void:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	stock_everything()
	var b = bs.place_at("bone_stake", Vector2i(2, 2), _world, false)
	assert_not_null(b, "A bone palisade goes down")
	if b == null:
		return
	if not b.is_constructed:
		b.complete_construction()
	game_state_node.known["iron"] = true
	var iron_before: int = int(game_state_node.resources.get("iron", 0))
	assert_true(b.begin_upgrade("iron_stake"), "It is set to be forged")
	assert_eq(iron_before - int(game_state_node.resources.get("iron", 0)), int(config_node.upgrade_cost("bone_stake", "iron_stake")["iron"]),
		"paid for in iron")
	var guard: int = 0
	while not b.add_upgrade_progress(1.0) and guard < 100:
		guard += 1
	assert_eq(String(b.building_type), "iron_stake", "It stands an iron palisade")
	await wait_frames(1)
	assert_almost_eq(float(b.contact_damage), float(_row("iron_stake")["contact_damage"]), 0.0001, "and bites by its own row")
	assert_almost_eq(float(b.max_hp), float(_row("iron_stake")["hp"]), 0.0001, "and lasts by it")
