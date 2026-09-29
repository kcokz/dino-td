# res://tests/test_v06_tools.gd
# v0.6 T4: a tool makes every stroke count for more, and says so.
#
# GAME-DESIGN 4.6: gathering must not eat the Hero's whole day, so how fast he works has to
# be something he can raise -- tools for good, meals for a while. And the rise has to be
# seen: a pile brought in with the stone axe says "+2 (Stone Axe x2)", or the axe is a
# number nobody ever notices. What a tool does is part of its recipe, so the next tool is a
# line of Config and no code.
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
	clear_drops()
	super.after_each()

func _spawn(node: Node) -> Node:
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	return node

## A tool that speeds up cutting wood, whatever Config calls it.
func _axe() -> String:
	for recipe_id in config_node.RECIPES:
		if float(config_node.RECIPES[recipe_id].get("harvest_speed", {}).get("wood", 1.0)) > 1.0:
			return String(recipe_id)
	return ""

## One stroke of the Hero on a tree standing right beside him. Returns the pile it left.
func _one_stroke_on_a_tree() -> DropItem:
	var hero = _spawn(load("res://scripts/entities/Hero.gd").new())
	var tree_node = _spawn(load("res://scripts/entities/ResourceNode.gd").new("wood", Vector2i(1, 0)))
	tree_node.position = Vector3(1.0, 0.0, 0.0)
	tree_node.setup("wood", Vector2i(1, 0), 50)
	await wait_frames(1)
	hero.order_harvest(tree_node)
	var rate: float = float(config_node.RESOURCE_NODES["wood"]["harvest_rate"])
	hero._process_harvesting(1.0 / rate + 0.001)
	for pile in tree.get_nodes_in_group(DropItem.GROUP):
		if pile is DropItem and pile.resource_type == "wood":
			return pile
	return null

func test_01_a_tool_s_speed_is_part_of_its_recipe() -> void:
	var tools: int = 0
	for recipe_id in config_node.RECIPES:
		var speeds: Dictionary = config_node.RECIPES[recipe_id].get("harvest_speed", {})
		for res_id in speeds:
			tools += 1
			assert_true(config_node.RESOURCE_NODES.has(res_id),
				"%s speeds up %s, which is something the Hero cuts" % [recipe_id, res_id])
			assert_gt(float(speeds[res_id]), 1.0, "%s makes it faster, not slower" % recipe_id)
	assert_gt(tools, 0, "At least one tool does something for gathering")
	assert_ne(_axe(), "", "And one of them works wood")

func test_02_bare_hands_bring_in_one_a_stroke_and_say_nothing_more() -> void:
	var pile: DropItem = await _one_stroke_on_a_tree()
	assert_not_null(pile, "A stroke left a pile")
	if pile == null:
		return
	assert_eq(pile.amount, 1, "One by hand")
	assert_eq(pile.note, "", "Nothing to explain")
	assert_eq(pile.pickup_text(), "+1", "So the number is all it says")

func test_02b_a_tool_says_what_it_does_when_it_is_made() -> void:
	# GAME-DESIGN 14.2 path 4: making the axe says "Wood ×2", making the pick says stone can
	# be gathered now -- from the recipes, not from anything written for them.
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	tree.root.add_child(hud)
	await wait_frames(1)
	var axe: String = _axe()
	game_state_node.grant_unlock(String(config_node.RECIPES[axe]["unlocks"]))
	var factor: String = String(config_node.factor_text(float(config_node.RECIPES[axe]["harvest_speed"]["wood"])))
	assert_true(hud.hint_label.visible and hud.hint_label.text.contains(tr(String(config_node.RECIPES[axe]["name"]))),
		"Making the axe is said: %s" % hud.hint_label.text)
	assert_true(hud.hint_label.text.contains("×%s" % factor), "With what it does, with the times sign: %s" % hud.hint_label.text)
	var opener: String = String(config_node.harvest_requires_unlock("stone"))
	game_state_node.grant_unlock(opener)
	assert_true(hud.hint_label.text.contains(tr("RESOURCE_STONE")), "The pick says stone can be gathered now: %s" % hud.hint_label.text)
	hud.get_parent().remove_child(hud)
	hud.free()

func test_03_the_axe_makes_every_stroke_count_for_more() -> void:
	game_state_node.grant_unlock(String(config_node.RECIPES[_axe()]["unlocks"]))
	var factor: float = float(config_node.RECIPES[_axe()]["harvest_speed"]["wood"])
	var pile: DropItem = await _one_stroke_on_a_tree()
	assert_not_null(pile, "A stroke left a pile")
	if pile == null:
		return
	assert_eq(pile.amount, int(factor), "The same stroke brings in %s" % config_node.factor_text(factor))

func test_04_and_the_pile_says_which_tool_did_it() -> void:
	game_state_node.grant_unlock(String(config_node.RECIPES[_axe()]["unlocks"]))
	var pile: DropItem = await _one_stroke_on_a_tree()
	assert_not_null(pile, "A stroke left a pile")
	if pile == null:
		return
	var tool_name: String = tr(String(config_node.RECIPES[_axe()]["name"]))
	assert_true(pile.note.contains(tool_name), "The note names the axe (%s)" % pile.note)
	assert_true(pile.pickup_text().contains(tool_name), "And so does what floats up when it is picked up")
	assert_true(pile.pickup_text().begins_with("+%d" % pile.amount), "After the number")

func test_05_tools_on_the_same_resource_multiply() -> void:
	# The rule that lets an iron axe later be "another x2" rather than a new mechanism.
	var owned: Dictionary = {}
	var expected: float = 1.0
	for recipe_id in config_node.RECIPES:
		var data: Dictionary = config_node.RECIPES[recipe_id]
		owned[String(data["unlocks"])] = true
		expected *= float(data.get("harvest_speed", {}).get("wood", 1.0))
	assert_almost_eq(config_node.harvest_speed("wood", owned), expected, 0.0001,
		"Every tool held multiplies in")
	assert_almost_eq(config_node.harvest_speed("wood", {}), 1.0, 0.0001, "And none is bare hands")
