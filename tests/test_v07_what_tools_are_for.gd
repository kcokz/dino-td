# res://tests/test_v07_what_tools_are_for.gd
# The player, 2026-10-04: "Bone pick，bone shovel hover上去的时候没有解释这是干嘛的".
#
# A tool says what it is for -- on the bench's line as the cursor is over it, and in its place in his kit -- from its own
# data (Config.recipe_use_text): what it lets him gather, what it brings in faster, or its own words. And a tool with
# nothing to do on this map is not offered here: the bone shovel digs clay, which the first valley has none of.
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
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func _node_name(res_id: String) -> String:
	return tr(String(config_node.RESOURCE_NODES[res_id].get("name", res_id)))

func test_01_each_tool_says_what_it_is_for() -> void:
	var pick: String = String(config_node.recipe_use_text("stone_pick"))
	assert_eq(pick, tr("TOOL_LETS") % _node_name("stone"), "The pick lets him gather stone")
	var shovel: String = String(config_node.recipe_use_text("bone_shovel"))
	assert_eq(shovel, tr("TOOL_LETS") % _node_name("clay"), "the shovel clay")
	var axe: String = String(config_node.recipe_use_text("stone_axe"))
	assert_true(axe.find(tr("RESOURCE_WOOD")) >= 0 and axe.find("×") >= 0, "the axe brings wood in faster (%s)" % axe)
	assert_eq(String(config_node.recipe_use_text("hide_map")), tr("RECIPE_HIDE_MAP_DESC"), "the map in its own words")
	assert_eq(String(config_node.recipe_opens("bone_shovel")), "clay", "(what the shovel opens)")
	assert_eq(String(config_node.recipe_opens("stone_axe")), "", "(the axe opens nothing: it speeds wood)")

func test_02_the_benchs_line_says_it() -> void:
	var main = await _level()
	stock_everything()
	var wb = main.current_core.station("workbench")
	for recipe_id in ["stone_pick", "stone_axe", "hide_map"]:
		var line: String = String(UiKit.job_detail(wb, recipe_id)[0])
		assert_true(line.find(String(config_node.recipe_use_text(recipe_id))) >= 0, "The %s's line says what it is for: %s" % [recipe_id, line])

func test_03_a_tool_with_nothing_to_do_here_is_not_offered() -> void:
	var main = await _level()
	stock_everything()
	var wb = main.current_core.station("workbench")
	var clay_here: bool = false
	for n in tree.get_nodes_in_group("resource_nodes"):
		clay_here = clay_here or String(n.get("resource_type")) == "clay"
	assert_false(clay_here, "(this valley has no clay)")
	assert_false(wb.can_offer("bone_shovel"), "The shovel is not offered where there is no clay to dig")
	assert_true(wb.can_offer("stone_pick"), "the pick, with stone about, is")
	# Clay on the map: the shovel is of use, and offered.
	var bank = load("res://scripts/entities/ResourceNode.gd").new()
	bank.resource_type = "clay"
	_cleanup_nodes.append(bank)
	main.add_child(bank)
	assert_true(wb.can_offer("bone_shovel"), "With clay about, it is")

func test_04_in_his_kit_the_tool_says_it_too() -> void:
	var main = await _level()
	game_state_node.grant_unlock(String(config_node.RECIPES["stone_pick"]["unlocks"]))
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	main.hud.toggle_hero_details()
	await wait_frames(2)
	panel._show_abilities(true)
	var slot: Control = panel.find_child("Ability_stone_pick", true, false) as Control
	assert_not_null(slot, "The pick in his kit")
	if slot:
		assert_true(slot.tooltip_text.find(String(config_node.recipe_use_text("stone_pick"))) >= 0, "says what it is for: %s" % slot.tooltip_text)
