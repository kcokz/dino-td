# res://tests/test_v06_ability_slots.gd
# v0.6 feedback, round three, 4: "人获得的物品，目前都是能力，也显示在任务面板，作为一个小正方形图标，比如stone
# pick就是能开石的能力，hover上去就知道，而且能力槽要可扩展，之后还能放下更多能力".
#
# What he has made for good is an ability (Config.abilities: every recipe whose unlock he holds),
# and each is a square on his card under his bars: the tool's own icon, and on hover its name and
# what it does. The row is slots -- at least THEME.ability_slots of them, the empty ones saying
# where the next comes from -- and it grows as he gains more.
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
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

## The Hero's card: an option panel in the tree, showing him.
func _card() -> Node:
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	var panel = load("res://scripts/ui/OptionPanel.gd").new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	panel.select_target(hero)
	return panel

func _slots(panel: Node) -> Array[Node]:
	var out: Array[Node] = []
	var row: Node = panel.find_child("Abilities", true, false)
	if row != null:
		for child in row.get_children():
			if not child.is_queued_for_deletion():
				out.append(child)
	return out

## Every recipe that grants something, in the order Config lists them.
func _tools() -> Array[String]:
	var out: Array[String] = []
	for recipe_id in config_node.RECIPES:
		if String(config_node.RECIPES[recipe_id].get("unlocks", "")) != "":
			out.append(String(recipe_id))
	return out

func test_01_an_ability_is_a_tool_he_has_made() -> void:
	assert_eq(config_node.abilities({}), [] as Array[String], "A new run: none")
	var tools := _tools()
	assert_gt(tools.size(), 1, "There are tools to make")
	var first: String = tools[0]
	game_state_node.grant_unlock(String(config_node.RECIPES[first]["unlocks"]))
	assert_eq(config_node.abilities(game_state_node.unlocks), [first] as Array[String], "Made one: that one")
	for recipe_id in tools:
		game_state_node.grant_unlock(String(config_node.RECIPES[recipe_id]["unlocks"]))
	assert_eq(config_node.abilities(game_state_node.unlocks), tools, "Made them all: all of them, in the order they are listed")

func test_02_his_card_has_a_row_of_empty_slots_to_begin_with() -> void:
	var panel = _card()
	await wait_frames(2)
	var slots := _slots(panel)
	assert_eq(slots.size(), int(config_node.THEME["ability_slots"]), "A row of slots")
	for slot in slots:
		assert_eq((slot as Control).tooltip_text, tr("ABILITY_EMPTY"), "each empty one saying what goes there")

func test_03_a_tool_made_is_a_square_with_its_icon_and_what_it_does() -> void:
	var panel = _card()
	await wait_frames(2)
	var pick: String = _tools()[0]
	game_state_node.grant_unlock(String(config_node.RECIPES[pick]["unlocks"]))
	panel._refresh_ui()
	await wait_frames(2)
	var slot: Node = panel.find_child("Ability_" + pick, true, false)
	assert_not_null(slot, "Its square is on his card")
	var icon: TextureRect = slot.find_child("Icon", true, false) as TextureRect
	assert_not_null(icon, "with an icon")
	assert_eq(icon.texture, UiTheme.icon(pick), "its own, drawn for it")
	assert_not_null(UiTheme.icon(pick), "which exists")
	var tip: String = (slot as Control).tooltip_text
	assert_true(tip.contains(tr(String(config_node.RECIPES[pick]["name"]))), "Hovered, it says what it is")
	assert_true(tip.contains(String(config_node.recipe_effect_text(pick))), "and what it does")
	assert_ne(String(config_node.recipe_effect_text(pick)), "", "which is something")
	assert_eq(_slots(panel).size(), int(config_node.THEME["ability_slots"]), "It takes a slot; the row is no longer")

func test_04_the_row_grows_past_its_slots() -> void:
	var panel = _card()
	await wait_frames(2)
	var tools := _tools()
	for recipe_id in tools:
		game_state_node.grant_unlock(String(config_node.RECIPES[recipe_id]["unlocks"]))
	panel._show_abilities(true)
	await wait_frames(2)
	assert_eq(_slots(panel).size(), maxi(tools.size(), int(config_node.THEME["ability_slots"])),
		"As many squares as he has abilities, or the row's slots if more")
	assert_true(panel.find_child("Abilities", true, false) is HFlowContainer, "and a row that wraps as it fills")

func test_05_every_tool_has_an_icon_of_its_own() -> void:
	for recipe_id in _tools():
		assert_not_null(UiTheme.icon(recipe_id), "%s has an icon" % recipe_id)
		assert_true(ResourceLoader.exists(String(config_node.ICON_DIR) + recipe_id + ".svg"), "drawn for it")
