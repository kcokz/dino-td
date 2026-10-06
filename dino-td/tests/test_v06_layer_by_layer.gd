# res://tests/test_v06_layer_by_layer.gd
# v0.6 feedback: "需要有隐藏，层层打开机制，目前所有可以造的都被显示，一览无余，缺什么也能看到，不够好玩，
# 需要一开始只显示能造的东西，能采集的，每当有新的材料出现（比如恐龙骨头掉落）再显示可以用这个骨头能做的
# 事情，资源栏同理".
#
# The run unfolds a material at a time (GameState.known): at first only what the map hands
# out is known, and only what is made of known materials is on show -- in the build menu,
# at the benches, on the resource bar, and in what a material is said to be for. The first
# bone brings what is made of bone. The beacon, the run's goal, always says what it needs.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var event_bus_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
		event_bus_node = tree.root.get_node_or_null("EventBus")

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
	clear_drops()
	if game_state_node != null:
		game_state_node.reset_game()
	super.after_each()

func _opening() -> Array:
	return game_state_node.map_data().get("opening_stock", {}).keys()

## The buildables made only of materials in `known`, in the menu's order.
func _built_of(known: Array) -> Array:
	var out: Array = []
	for b_type in config_node.BUILDABLE_TYPES:
		var fits: bool = true
		for res_id in config_node.BUILDINGS[b_type].get("cost", {}):
			fits = fits and known.has(String(res_id))
		if fits:
			out.append(String(b_type))
	return out

## What the Hero's build menu shows, by name -- every tab of it (v0.7: the menu in tabs), in the menu's own order.
func _menu(main: Node) -> Array:
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._on_build_pressed()
	var names: Array = []
	for b_type in config_node.BUILDABLE_TYPES:
		var card: Button = panel.build_card(String(b_type))
		if card != null:
			names.append(String(card.text))
	return names

func _names(types: Array) -> Array:
	var out: Array = []
	for t in types:
		out.append(String(config_node.get_building_name(String(t))))
	return out

func test_01_a_new_run_knows_only_what_it_is_handed() -> void:
	assert_gt(_opening().size(), 0, "The map hands something out at the start")
	for res_id in config_node.RESOURCES:
		assert_eq(game_state_node.knows(String(res_id)), _opening().has(String(res_id)),
			"%s is known at the start exactly when the map hands it out" % res_id)

func test_02_the_build_menu_shows_what_the_known_materials_build_and_no_more() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var shown: Array = _menu(main)
	var expected: Array = _names(_built_of(_opening()))
	assert_gt(expected.size(), 1, "More than one thing can be built at the start (the stakes are not alone)")
	assert_eq(shown, expected, "Only what the opening's materials build: %s" % [shown])

func test_03_a_new_material_brings_what_is_made_of_it() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var told = watch_signal(event_bus_node, "material_discovered")
	var menu_before: Array = _menu(main)
	game_state_node.add_resource("bone", 1)
	await wait_frames(1)
	assert_eq(told.emit_count, 1, "The first bone is news")
	assert_eq(String(told.last_args[0]), "bone", "About bone")
	var now_known: Array = _opening() + ["bone"]
	var shown: Array = _menu(main)
	# v0.6 round six (GAME-DESIGN 6.0): the menu is one slot a job and never grows by a material --
	# what bone brings is ways up for what stands (the fence's bone stakes, the bow's crossbow).
	assert_eq(shown, menu_before, "The menu stays one slot a job: %s" % [shown])
	var ways: Array = []
	for b_type in config_node.player_building_types():
		for target in config_node.upgrade_targets(String(b_type)):
			if config_node.upgrade_cost(String(b_type), String(target)).has("bone"):
				ways.append(String(target))
	assert_gt(ways.size(), 0, "What is made with bone is a way up for what stands: %s" % [ways])
	game_state_node.add_resource("bone", 1)
	assert_eq(told.emit_count, 1, "The second bone is not")

func test_04_the_bar_grows_as_the_run_does() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	await wait_frames(1)
	var hud = main.hud
	for res_id in config_node.RESOURCES:
		var useful: bool = not config_node.uses_of(String(res_id)).is_empty()
		assert_eq(hud.resource_chips[String(res_id)].visible, useful and _opening().has(String(res_id)),
			"At the start the bar shows %s exactly when it is handed out" % res_id)
	game_state_node.add_resource("bone", 1)
	await wait_frames(1)
	assert_true(hud.resource_chips["bone"].visible, "The first bone puts bone on the bar")
	game_state_node.spend_resources({"bone": 1})
	await wait_frames(1)
	assert_true(hud.resource_chips["bone"].visible, "And it stays when the bone is spent")

func test_05_a_bench_waits_on_its_materials_and_the_beacon_does_not() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	var bench: Node = main.current_core.station("workbench")
	var beacon: Node = main.current_core.station(String(config_node.BEACON_STATION))
	# One that bone is all it still waits on: the rest of what it takes has turned up already (the
	# bone armour waits on hide as well, v0.6 round three).
	var needs_bone: String = ""
	for recipe_id in bench.recipes():
		var rest: Dictionary = bench.inputs_of(recipe_id).duplicate()
		if needs_bone == "" and rest.has("bone"):
			rest.erase("bone")
			if game_state_node.knows_all(rest):
				needs_bone = recipe_id
	assert_ne(needs_bone, "", "Something at the workbench is made of bone")
	assert_false(bench.can_offer(needs_bone), "Not offered before bone has turned up")
	assert_true(bench.waiting_on_materials(), "The bench says it waits on a material, not that it is done")
	assert_true(beacon.can_offer(String(game_state_node.beacon_next_job())), "The beacon always says what it needs next")
	game_state_node.add_resource("bone", 1)
	assert_true(bench.can_offer(needs_bone), "The first bone brings it")
	var panel = main.hud.option_panel
	panel.select_target(bench)
	await wait_frames(1)
	var offered: bool = false
	for btn in panel.button_container.get_children():
		if btn is Button and (btn as Button).text == bench.recipe_name(needs_bone):
			offered = true
	assert_true(offered, "And the bench's menu offers it")

func test_06_what_a_material_is_for_names_only_what_has_turned_up() -> void:
	var map: Dictionary = game_state_node.map_data()
	var wood_now: String = String(config_node.uses_text("wood", map, game_state_node.knows))
	for b_type in config_node.BUILDABLE_TYPES:
		var cost: Dictionary = config_node.BUILDINGS[b_type].get("cost", {})
		if not cost.has("wood"):
			continue
		var all_known: bool = game_state_node.knows_all(cost)
		assert_eq(wood_now.contains(config_node.get_building_name(String(b_type))), all_known,
			"Wood is for %s as far as the run knows (%s)" % [b_type, wood_now])
	game_state_node.add_resource("bone", 1)
	var wood_later: String = String(config_node.uses_text("wood", map, game_state_node.knows))
	assert_gt(wood_later.length(), wood_now.length(), "The first bone makes wood good for more")

func test_07_the_rock_does_not_name_the_pick_before_the_bone() -> void:
	var map_known := func(_r): return false
	var pick_name: String = ""
	var flag: String = String(config_node.harvest_requires_unlock("stone"))
	for recipe_id in config_node.RECIPES:
		if String(config_node.RECIPES[recipe_id].get("unlocks", "")) == flag:
			pick_name = tr(String(config_node.RECIPES[recipe_id]["name"]))
	assert_ne(pick_name, "", "Stone waits on a tool")
	var early: String = String(config_node.missing_tool_hint("stone", game_state_node.knows))
	assert_ne(early, "", "A rock says something before its tool can be made")
	assert_false(early.contains(pick_name), "But does not name the tool before its materials turn up: %s" % early)
	game_state_node.add_resource("bone", 1)
	var later: String = String(config_node.missing_tool_hint("stone", game_state_node.knows))
	assert_true(later.contains(pick_name), "Once they have, it names the tool and where it is made: %s" % later)
	assert_ne(String(config_node.missing_tool_hint("stone", map_known)), later, "It is the knowing that changes it")
