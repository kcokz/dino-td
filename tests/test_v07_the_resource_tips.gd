# res://tests/test_v07_the_resource_tips.gd
# The player, 2026-10-04: "左上角的资源，hover上去以后会有一串非常长的解释，我觉得界面需要更精致，根据专业游戏的best practice界面做".
#
# A material's chip says, in three short lines, what it is, where it comes from and what KINDS of thing it is for
# (Config.resource_tip) -- not every building and recipe by name, which ran to a paragraph.
extends "res://tests/test_base.gd"

var config_node: Object = null

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func _tip(res_id: String) -> String:
	return String(config_node.resource_tip(res_id, config_node.map_data(String(config_node.DEFAULT_MAP_ID))))

func test_01_three_short_lines() -> void:
	for res_id in ["wood", "stone", "bone", "food", "hide", "arrow_wood", "log_round", "shot_stone"]:
		var tip: String = _tip(res_id)
		var lines: PackedStringArray = tip.split("\n")
		assert_true(lines.size() >= 2 and lines.size() <= 3, "%s: two or three lines (%s)" % [res_id, tip])
		assert_eq(lines[0], tr("RESOURCE_%s" % res_id.to_upper()), "%s: its name first" % res_id)
		for line in lines:
			assert_lt(line.length(), 48, "%s: no line runs on (%s)" % [res_id, line])

func test_02_where_it_comes_from() -> void:
	assert_true(_tip("wood").contains(tr("RES_FROM") % tr("RES_FROM_GATHER")), "Wood is gathered")
	assert_true(_tip("stone").contains(tr(String(config_node.RECIPES["stone_pick"]["name"]))), "stone takes the pick, which is named")
	assert_true(_tip("bone").contains(tr("RES_FROM_DEAD")), "bone is the dead's")
	assert_true(_tip("arrow_wood").contains(tr("RES_FROM_BENCH")), "arrows are made at the workbench")

func test_03_what_kinds_of_thing_it_is_for_not_each_by_name() -> void:
	var wood: String = _tip("wood")
	for kind in ["USE_KIND_BUILD", "USE_KIND_AMMO", "USE_KIND_FUEL"]:
		assert_true(wood.contains(tr(kind)), "Wood is for %s" % tr(kind))
	assert_false(wood.contains(String(config_node.get_building_name("bow_tower"))), "and does not name every building")
	assert_true(_tip("food").contains(tr("USE_KIND_BAIT")), "meat is bait")
	assert_true(_tip("arrow_wood").contains(String(config_node.get_building_name("bow_tower"))), "arrows go into the bow tower, named")
