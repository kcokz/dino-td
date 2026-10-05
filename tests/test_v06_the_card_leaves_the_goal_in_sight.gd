# res://tests/test_v06_the_card_leaves_the_goal_in_sight.gd
# v0.6 round six. The player: "升级建筑单位图标应该跟build里面的建造图标一样，这样比较统一" -- a building's ways up are
# the build menu's cards for what it becomes, two to a row. And, found in the screenshot of it: a fence's card,
# three ways up tall, grew up over the goal's card at the top right -- over the beacon's line and the raid's count
# under it. The card grows no further than the goal's card's foot; past that its commands scroll.
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

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

func _fence(main: Node) -> Node:
	var door: Vector3 = main.current_core.door_outside()
	var fence = main.build_system.place_at("wall", main.grid_manager.world_to_build_cell(door + Vector3(-3.0, 0.0, 3.0)), main.buildings_container)
	fence.complete_construction()
	fence.current_hp = fence.max_hp * 0.5
	return fence

func test_01_its_ways_up_are_the_build_menus_cards() -> void:
	var main = await _level()
	stock_everything()
	var panel = main.hud.option_panel
	panel.select_target(_fence(main))
	await wait_frames(2)
	var ways: GridContainer = panel.button_container.get_node_or_null(String(panel.UPGRADES_NAME)) as GridContainer
	assert_not_null(ways, "The ways up stand together")
	if ways == null:
		return
	assert_eq(ways.get_child_count(), (config_node.upgrade_targets("wall") as Array).size(), "one card for each")
	assert_gt(ways.columns, 1, "more than one to a row, as in the build menu")
	for card in ways.get_children():
		assert_eq(String((card as Button).theme_type_variation), "CardButton", "%s is a card, as in the build menu" % (card as Button).text)

func test_02_the_card_grows_no_further_than_the_goals_card_and_its_commands_scroll() -> void:
	var main = await _level()
	stock_everything()
	var hud = main.hud
	# A goal pinned: its plate up at the top right.
	game_state_node.pin_goal({"kind": "build", "id": "bow_tower"})
	var panel = hud.option_panel
	panel.select_target(_fence(main))
	for i in 6:
		await wait_frames(1)
	var card: Rect2 = panel.get_global_rect()
	var goal: Rect2 = hud.objective_panel.get_global_rect()
	assert_true(hud.objective_panel.visible, "(the pinned goal's plate is up)")
	assert_false(card.intersects(goal), "The card stays below the pinned goal (%s, %s)" % [card, goal])
	var shown: float = panel.command_scroll.size.y
	var all: float = panel.button_container.get_combined_minimum_size().y
	if all > shown + 1.0:
		assert_eq(panel.command_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "Its commands scroll for the rest")
	assert_gt(panel.command_buttons().size(), 3, "(every command still on it)")
