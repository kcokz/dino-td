# res://tests/test_v06_the_goal.gd
# The player, v0.6 round six: "材料各种各样……总感觉有点confuse哪个材料是用来做什么，也很难做规划" -- chosen:
# "钉住一个目标" (GAME-DESIGN 6.0 rule 4). Right-click on an entry with a price -- a building off the
# menu, a way up on a building's card, a job at a bench -- pins it; the material bar counts against its
# price, "have/need", gold once there is enough; the beacon's panel says what it is and what is short.
# Made, a recipe is no longer the goal; a beacon step done, the next one is.
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

func _right_click(btn: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	btn.gui_input.emit(click)

func _button_with_goal(panel: Node, goal: Dictionary) -> Control:
	for child in panel.command_buttons():
		if child is Control and child.has_meta("goal"):
			var g: Dictionary = child.get_meta("goal")
			if String(g.get("kind", "")) == String(goal["kind"]) and String(g.get("id", "")) == String(goal["id"]):
				return child
	return null

func test_01_a_building_pinned_off_the_menu_is_counted_on_the_bar() -> void:
	var main = await _level()
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	await wait_frames(2)
	var bow: String = "bow_tower"
	var btn: Control = _button_with_goal(panel, {"kind": "build", "id": bow})
	assert_not_null(btn, "(the bow tower's entry)")
	if btn == null:
		return
	game_state_node.resources["wood"] = 1
	_right_click(btn)
	assert_true(game_state_node.is_pinned({"kind": "build", "id": bow}), "A right-click pins it as the goal")
	await wait_frames(2)
	var need: int = int(config_node.BUILDINGS[bow]["cost"]["wood"])
	var lbl: Label = main.hud.resource_labels.get("wood")
	assert_eq(lbl.text, "1/%d" % need, "The wood on the bar says what the goal takes")
	assert_true(main.hud.goal_label.visible, "and the goal is named under the beacon")
	assert_true(main.hud.goal_label.text.contains(String(config_node.get_building_name(bow))), "(by name)")
	game_state_node.add_resource("wood", need)
	await wait_frames(2)
	assert_true(main.hud.goal_label.text.contains(tr("GOAL_MET")), "Enough, it says so")
	_right_click(btn)
	assert_true(game_state_node.goal.is_empty(), "Right-clicked again, it is unpinned")
	await wait_frames(2)
	assert_eq(main.hud.resource_labels.get("wood").text, str(int(game_state_node.resources["wood"])), "and the bar is a count again")

func test_02_a_way_up_is_pinned_at_its_difference() -> void:
	var main = await _level()
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var fence = main.build_system.place_at("wall", main.grid_manager.world_to_build_cell(door + Vector3(-3.0, 0.0, 3.0)), main.buildings_container)
	fence.complete_construction()
	var panel = main.hud.option_panel
	panel.select_target(fence)
	await wait_frames(2)
	var btn: Control = _button_with_goal(panel, {"kind": "upgrade", "id": "stone_wall"})
	assert_not_null(btn, "(the fence's way up to stone)")
	if btn == null:
		return
	_right_click(btn)
	assert_eq(game_state_node.goal_price(), config_node.upgrade_cost("wall", "stone_wall"), "Pinned, it costs what the step up does")

func test_04_a_building_ordered_or_a_way_up_begun_is_no_longer_the_goal() -> void:
	# The player, v0.6 round six, asked whether a building pinned should go once it is paid for: "下单就取消".
	var main = await _level()
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	game_state_node.pin_goal({"kind": "build", "id": "wall"})
	var fence = main.build_system.place_at("wall", main.grid_manager.world_to_build_cell(door + Vector3(-3.0, 0.0, 3.0)), main.buildings_container, true)
	assert_not_null(fence, "(a fence ordered)")
	assert_true(game_state_node.goal.is_empty(), "Ordered, the building pinned is no longer the goal")
	game_state_node.pin_goal({"kind": "build", "id": "bow_tower"})
	main.build_system.place_at("wall", main.grid_manager.world_to_build_cell(door + Vector3(-5.0, 0.0, 3.0)), main.buildings_container, true)
	assert_true(game_state_node.is_pinned({"kind": "build", "id": "bow_tower"}), "(something else ordered, it stays)")
	fence.complete_construction()
	game_state_node.pin_goal({"kind": "upgrade", "id": "stone_wall", "from": "wall"})
	assert_true(fence.begin_upgrade("stone_wall"), "(the fence's way up to stone, begun)")
	assert_true(game_state_node.goal.is_empty(), "Begun, the way up pinned is no longer the goal")

func test_03_a_recipe_made_is_no_longer_the_goal_and_a_beacon_step_done_hands_on_to_the_next() -> void:
	var main = await _level()
	game_state_node.pin_goal({"kind": "job", "id": "stone_pick"})
	assert_eq(game_state_node.goal_price(), config_node.recipe_price("stone_pick", game_state_node.unlocks), "(the pick, at its price)")
	game_state_node.grant_unlock(String(config_node.RECIPES["stone_pick"]["unlocks"]))
	assert_true(game_state_node.goal.is_empty(), "Made, it is no longer the goal")
	var first: String = String(game_state_node.beacon_next_job())
	game_state_node.pin_goal({"kind": "job", "id": first})
	assert_false(game_state_node.goal_price().is_empty(), "(the beacon's first stage, with its price)")
	assert_true(game_state_node.finish_beacon_job(first), "(repaired)")
	var next: String = String(game_state_node.beacon_next_job())
	if not config_node.beacon_job(game_state_node.map_data(), next).get("inputs", {}).is_empty():
		assert_true(game_state_node.is_pinned({"kind": "job", "id": next}), "the next stage is the goal now")
	game_state_node.pin_goal({"kind": "build", "id": "wall"})
	game_state_node.reset_game()
	assert_true(game_state_node.goal.is_empty(), "A new run starts with none")
