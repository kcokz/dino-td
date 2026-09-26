# res://tests/test_v06_material_route.gd
# v0.6: tools decide what the Hero can gather, materials decide what he can build.
#
# There were blueprints: the kitchen turned two meat into the knowledge of how to put a
# turret together, and a building could be locked behind a flag. The design book took
# that out (GAME-DESIGN 4.1 rule 1) -- he is a master builder, and what he lacks is never
# how, only what with. The only unlocks left are tools, made at the cabin. These are the
# invariants that keep it that way, stated so that bringing a blueprint back is a
# decision somebody has to make.
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

func test_01_no_building_waits_on_anything_but_its_materials() -> void:
	for b_type in config_node.BUILDINGS:
		assert_false(config_node.BUILDINGS[b_type].has("requires_unlock"),
			"%s is locked by its materials alone, never by a flag" % b_type)

	# And in play: with a tower's materials in the warehouse and nothing made at the
	# cabin, a tower goes up.
	var grid = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(grid)
	tree.root.add_child(grid)
	var builder = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(builder)
	tree.root.add_child(builder)
	builder.setup(grid, null)
	await wait_frames(1)
	pay_for(["tower"], 1)
	assert_true(game_state_node.unlocks.is_empty(), "Nothing has been made at the cabin")
	assert_true(builder.can_place_building("tower", Vector2i(2, 2)),
		"The materials are all a tower asks for")

func test_02_a_building_is_two_materials_at_most() -> void:
	# One material says which tier it is, and at most one more is a working part: a
	# stone plinth with bone bolt heads is stone and bone (GAME-DESIGN 4.1 rule 2).
	for b_type in config_node.BUILDINGS:
		var cost: Dictionary = config_node.BUILDINGS[b_type].get("cost", {})
		assert_lte(cost.size(), 2, "%s is built of two materials at most" % b_type)

func test_02b_a_rock_he_cannot_cut_says_what_it_takes() -> void:
	# Right-clicking stone before the pick: the tool, the bench it is made at and its price,
	# every word of it from Config -- the chain, where the player meets the wall.
	var flag: String = String(config_node.harvest_requires_unlock("stone"))
	assert_ne(flag, "", "Stone needs a tool")
	var hint: String = String(config_node.missing_tool_hint("stone"))
	for recipe_id in config_node.RECIPES:
		var row: Dictionary = config_node.RECIPES[recipe_id]
		if String(row["unlocks"]) != flag:
			continue
		assert_true(hint.contains(tr(String(row["name"]))), "It names the tool: %s" % hint)
		assert_true(hint.contains(tr("STATION_%s_NAME" % String(row["station"]).to_upper())), "And where it is made")
		for res_id in row["inputs"]:
			assert_true(hint.contains("%d %s" % [int(row["inputs"][res_id]), tr("RESOURCE_%s" % String(res_id).to_upper())]),
				"And what it costs in %s" % res_id)
	assert_eq(String(config_node.missing_tool_hint("wood")), "", "Bare hands cut wood: nothing to say")

func test_02c_every_material_on_the_bar_is_for_one_or_two_things() -> void:
	# GAME-DESIGN 4.3 rule 6: a material shown is for at least one thing and at most two
	# -- making, building, cooking -- as Config works it out. The beacon is on top of that
	# for every tier by design (8.3: each stage is the next tier's material), so it is not
	# counted against the limit.
	var map: Dictionary = game_state_node.map_data()
	for res_id in config_node.RESOURCES:
		var kinds: Dictionary = {}
		for use in config_node.uses_of(String(res_id), map):
			if String(use["kind"]) != "beacon":
				kinds[String(use["kind"])] = true
		if config_node.uses_of(String(res_id), map).is_empty():
			continue   # not shown at all (rule 1; test_v02_followups)
		assert_gte(kinds.size(), 1, "%s is for something besides the beacon" % res_id)
		assert_lte(kinds.size(), 2, "%s is for at most two things: %s" % [res_id, kinds.keys()])

func test_02d_what_a_material_is_for_and_where_it_comes_from_are_said_in_words() -> void:
	var map: Dictionary = game_state_node.map_data()
	var bone_uses: String = String(config_node.uses_text("bone", map))
	for use in config_node.uses_of("bone", map):
		if String(use["kind"]) == "building":
			assert_true(bone_uses.contains(String(config_node.get_building_name(String(use["id"])))),
				"What bone builds is named: %s" % bone_uses)
		elif String(use["kind"]) == "recipe":
			assert_true(bone_uses.contains(tr(String(config_node.RECIPES[use["id"]]["name"]))),
				"What bone makes is named: %s" % bone_uses)
	# Where it comes from: the tool, until he has it; then nothing stands in the way.
	var flag: String = String(config_node.harvest_requires_unlock("stone"))
	assert_eq(String(config_node.source_hint("stone", {})), String(config_node.missing_tool_hint("stone")),
		"Short of stone and without the pick: the pick is the answer")
	assert_eq(String(config_node.source_hint("stone", {flag: true})), "", "With it, stone is just work")
	# Bone: every raider leaves it. Prime meat: only a boss does (test_v06_bosses).
	assert_eq(String(config_node.source_hint("bone", {})), tr("SOURCE_DINOSAURS") % tr("RESOURCE_BONE"), "Bone: the dead leave it")
	assert_eq(String(config_node.source_hint("prime_meat", {})), tr("SOURCE_BOSSES") % tr("RESOURCE_PRIME_MEAT"),
		"Prime meat: only a boss does")

func test_02e_the_first_of_each_material_says_what_it_is_for_once() -> void:
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	_cleanup_nodes.append(hud)
	tree.root.add_child(hud)
	await wait_frames(1)
	var bus = tree.root.get_node("EventBus")
	bus.resource_picked_up.emit("bone", 1, null)
	assert_true(hud.hint_label.visible, "The first bone says something")
	assert_true(hud.hint_label.text.contains(String(config_node.uses_text("bone", game_state_node.map_data()))),
		"What bone is for: %s" % hud.hint_label.text)
	hud.hint_label.visible = false
	bus.resource_picked_up.emit("bone", 1, null)
	assert_false(hud.hint_label.visible, "The second says nothing")
	var label: Label = hud.resource_labels.get("bone")
	assert_true(label != null and label.tooltip_text.contains(String(config_node.uses_text("bone", game_state_node.map_data()))),
		"And the bar says it on hover")

func test_03_a_recipe_is_two_materials_at_most() -> void:
	# GAME-DESIGN 5.4 rule 5: a recipe has at most two ingredients.
	for recipe_id in config_node.RECIPES:
		assert_lte(config_node.RECIPES[recipe_id]["inputs"].size(), 2,
			"%s is made of two materials at most" % recipe_id)

func test_04_every_unlock_the_cabin_makes_is_a_tool_or_a_vessel() -> void:
	# The workbench makes tools and the kitchen makes the vessels he cooks in: nothing
	# the cabin makes is the right to build something.
	var stations: Array = config_node.STATIONS
	assert_has(stations, "workbench", "There is a workbench")
	assert_has(stations, "kitchen", "And a kitchen")
	for recipe_id in config_node.RECIPES:
		var unlock: String = String(config_node.RECIPES[recipe_id]["unlocks"])
		for b_type in config_node.BUILDINGS:
			for key in config_node.BUILDINGS[b_type]:
				var value = config_node.BUILDINGS[b_type][key]
				if value is String:
					assert_ne(String(value), unlock,
						"%s: no building is gated by what %s makes" % [b_type, recipe_id])
