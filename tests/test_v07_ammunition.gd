# res://tests/test_v07_ammunition.gd
# The 2026-10-02 rebuild, the player: "工作台做，专门的弹药系统，每个塔都可以放不同的弹药，不同的数量，还能升级扩张数量".
# And why there is loading at all: "现在已经有的小机关其实也是自动化的……它就自己能自己重新trigger了，似乎有点自欺欺人了"
# -- "我觉得我们这个游戏没有别的建筑，只有一个cabin，这个简化使得防御本身变得简单了，所以需要增加防御的难度和复杂度，装填
# 也许是一个方向".
#
# AMMUNITION is made at the workbench, a batch at a time, as often as there is the stuff for it -- each kind once its
# materials have turned up -- and kept in the stock. A tower holds one kind at a time, as much as its store takes;
# he loads it walking past or sent to it; a bigger store is an upgrade; what was in it goes back to the stock when
# it is set to another kind or taken down. Its card offers its kinds and the loading.
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

func _stock(res_id: String) -> int:
	return int(game_state_node.resources.get(res_id, 0))

func _set_stock(res_id: String, n: int) -> void:
	game_state_node.resources[res_id] = n

func _bench() -> Node:
	var bench = load("res://scripts/entities/CraftingStation.gd").new("workbench")
	_cleanup_nodes.append(bench)
	tree.root.add_child(bench)
	return bench

func _ammo_recipes() -> Array[String]:
	var out: Array[String] = []
	for rid in config_node.recipes_at("workbench"):
		if config_node.makes_ammo(String(rid)):
			out.append(String(rid))
	return out

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	await nav_settled(main)
	return main

## A finished `type_id` out in front of the cabin's door, `ahead` metres out and `aside` to the east.
func _tower_by_door(main: Node, type_id: String, ahead: float = 5.0, aside: float = 0.0) -> Node:
	stock_everything()
	var door: Vector3 = main.current_core.door_outside()
	var cell: Vector2i = main.grid_manager.world_to_build_cell(door + Vector3(aside, 0.0, ahead))
	var t = main.build_system.place_at(type_id, cell, main.buildings_container, false)
	assert_not_null(t, "%s goes down by the door" % type_id)
	if t != null:
		t.complete_construction()
	for id in config_node.AMMO:
		_set_stock(String(id), 0)
	return t

# ==============================================================================
# 1. Made at the workbench
# ==============================================================================

func test_01_the_workbench_makes_ammunition_a_batch_at_a_time_as_often_as_wanted() -> void:
	var recipes: Array[String] = _ammo_recipes()
	assert_false(recipes.is_empty(), "the workbench makes ammunition")
	var made_for: Dictionary = {}
	for rid in recipes:
		for id in config_node.RECIPES[rid]["makes"]:
			assert_true(config_node.AMMO.has(id), "%s makes ammunition (%s)" % [rid, id])
			made_for[String(id)] = true
	for id in config_node.AMMO:
		if String(id) != "food":
			assert_true(made_for.has(String(id)), "%s is made at the workbench" % id)
	stock_everything(0)
	know_everything()
	var bench = _bench()
	var rid: String = "arrow_wood"
	assert_true(bench.is_ammo(rid), "a batch of wooden arrows is ammunition")
	assert_true(bench.can_offer(rid), "on offer")
	var inputs: Dictionary = bench.inputs_of(rid)
	for twice in 2:
		game_state_node.add_resources(inputs)
		assert_true(bench.begin(rid), "begun (%d)" % (twice + 1))
		for res_id in inputs:
			assert_eq(_stock(String(res_id)), 0, "%s spent at the start" % res_id)
		assert_eq(bench.work(bench.time_of(rid)), "", "a batch is no tool of his")
		var makes: int = int(config_node.RECIPES[rid]["makes"][rid])
		assert_eq(_stock(rid), makes * (twice + 1), "a batch into the stock")
		assert_true(bench.can_offer(rid), "and still on offer: made as often as there is the stuff")
		assert_false(bench.job_done(rid), "never done for good")
	assert_true(bench.recipe_name(rid).contains(str(int(config_node.RECIPES[rid]["makes"][rid]))),
		"its card says how many a batch makes: %s" % bench.recipe_name(rid))

func test_02_each_kind_waits_on_its_materials() -> void:
	stock_everything(0)
	var bench = _bench()
	for rid in _ammo_recipes():
		assert_eq(bench.can_offer(rid), game_state_node.knows_all(config_node.RECIPES[rid]["inputs"]),
			"%s is on offer once what it is made of has turned up" % rid)
	game_state_node.add_resources({"wood": 1})
	assert_true(bench.can_offer("arrow_wood"), "wooden arrows with wood")
	assert_false(bench.can_offer("arrow_bone"), "bone-tipped ones not before the bone")
	assert_false(bench.can_offer("shot_stone"), "nor stone shot before the stone")
	game_state_node.add_resources({"bone": 1})
	assert_true(bench.can_offer("arrow_bone"), "bone-tipped arrows once the bone has turned up")

# ==============================================================================
# 2. Loaded by him
# ==============================================================================

func test_03_he_loads_a_tower_walking_past_it() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower")
	var cap: int = int(config_node.ammo_capacity("bow_tower"))
	_set_stock("arrow_wood", cap + 5)
	var hero = main.hero
	hero.global_position = bow.global_position + Vector3(float(config_node.get_building_half("bow_tower").x) + 0.6, 0.0, 0.0)
	hero.current_state = hero.State.IDLE
	await wait_physics_frames(3)
	assert_eq(bow.rounds(), cap, "standing by it, he loads it as full as it holds")
	assert_eq(_stock("arrow_wood"), 5, "out of the stock")
	assert_eq(String(bow.ammo_type), "arrow_wood", "with what the stock had")

func test_04_not_while_he_is_at_other_work() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower")
	_set_stock("arrow_wood", 10)
	var hero = main.hero
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = bow.global_position + Vector3(float(config_node.get_building_half("bow_tower").x) + 0.6, 0.0, 0.0)
	hero.current_state = hero.State.HARVESTING
	hero._load_in_passing(1.0)
	assert_eq(bow.rounds(), 0, "at other work he does not stop to load it")
	hero.current_state = hero.State.IDLE
	hero._load_in_passing(1.0)
	assert_eq(bow.rounds(), 10, "about nothing else, he does")
	assert_eq(_stock("arrow_wood"), 0, "all the stock had")

func test_05_sent_to_it_he_walks_over_and_loads_it() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower", 8.0)
	_set_stock("arrow_wood", 7)
	var hero = main.hero
	hero.global_position = main.current_core.door_outside() + Vector3(0.0, 0.0, 1.0)
	assert_true(bow.wants_load(), "it wants loading, and the stock has some")
	hero.order_load(bow)
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var t: float = 0.0
	while t < 20.0 and bow.rounds() == 0:
		await tree.physics_frame
		t += dt
	assert_eq(bow.rounds(), 7, "he went over and loaded it")
	assert_eq(_stock("arrow_wood"), 0, "out of the stock")
	assert_gte(t, float(config_node.AMMO_LOADING["order_seconds"]), "and it took him a moment")

func test_06_a_right_click_on_a_tower_wanting_loading_loads_it() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower", 8.0)
	_set_stock("arrow_wood", 3)
	main.hero.global_position = main.current_core.door_outside() + Vector3(0.0, 0.0, 1.0)
	main.right_click_building(bow, bow.global_position)
	assert_eq(main.hero.target_building, bow, "a right-click sends him to it")
	await wait_seconds(8.0)
	assert_eq(bow.rounds(), 3, "and he loads it")

# ==============================================================================
# 3. One kind at a time; a bigger store; taken down
# ==============================================================================

func test_07_one_kind_at_a_time_what_was_in_it_back_to_the_stock() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower")
	_set_stock("arrow_wood", 12)
	_set_stock("arrow_bone", 4)
	assert_eq(bow.kind_to_load(), "arrow_wood", "set to nothing, it takes the first of its kinds the stock has")
	bow.load_from_stock()
	assert_eq(bow.rounds(), 12, "loaded")
	assert_true(bow.set_ammo("arrow_bone"), "set to bone arrows")
	assert_eq(_stock("arrow_wood"), 12, "the wooden ones back to the stock")
	assert_eq(bow.rounds(), 0, "and out of it")
	assert_eq(bow.kind_to_load(), "arrow_bone", "it keeps to what it is set to")
	bow.load_from_stock()
	assert_eq(bow.rounds(), 4, "loaded with bone arrows")
	assert_false(bow.set_ammo("shot_stone"), "it will not take what is not for it")
	assert_eq(String(bow.ammo_type), "arrow_bone", "and keeps what it had")

func test_08_a_bigger_store_is_an_upgrade_and_keeps_what_was_in_it() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower")
	var cap: int = int(config_node.ammo_capacity("bow_tower"))
	_set_stock("arrow_wood", cap)
	bow.load_from_stock()
	var to: String = String(config_node.upgrade_targets("bow_tower")[0])
	var price: Dictionary = bow.upgrade_cost(to)
	for res_id in price:
		assert_eq(int(price[res_id]), int(config_node.BUILDINGS[to]["cost"].get(res_id, 0)) - int(config_node.BUILDINGS["bow_tower"]["cost"].get(res_id, 0)),
			"the bigger store costs the difference in %s" % res_id)
	stock_everything()
	assert_true(bow.begin_upgrade(to), "paid for")
	bow.add_upgrade_progress(999.0)
	assert_eq(String(bow.building_type), to, "it is the bigger one now")
	assert_eq(bow.capacity(), int(config_node.ammo_capacity(to)), "holding more")
	assert_eq(bow.rounds(), cap, "and what was in it is still in it")

func test_09_taken_down_what_was_in_it_goes_back_to_the_stock() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower")
	_set_stock("arrow_wood", 9)
	bow.load_from_stock()
	assert_eq(_stock("arrow_wood"), 0, "all of it in the tower")
	bow.demolish()
	assert_eq(_stock("arrow_wood"), 9, "taken down, he takes the arrows out of it")

func test_10_meat_on_the_rack_is_counted_in_bites() -> void:
	var main = await _level()
	var rack = _tower_by_door(main, "bait_rack")
	_set_stock("food", 1)
	rack.load_from_stock()
	var uses: int = int(config_node.AMMO["food"]["uses"])
	assert_eq(rack.uses_left, uses, "a piece of meat is so many bites")
	assert_eq(rack.rounds(), 1, "one piece on the rack")
	assert_true(rack.feed(null), "a bite")
	assert_eq(rack.rounds(), 1, "half eaten, it is still a piece on the rack")
	assert_eq(_stock("food"), 0, "the meat came out of the stock")

# ==============================================================================
# 4. Its card, and the workbench's
# ==============================================================================

func test_11_its_card_offers_its_kinds_and_the_loading() -> void:
	var main = await _level()
	var bow = _tower_by_door(main, "bow_tower")
	know_everything()
	_set_stock("arrow_wood", 6)
	_set_stock("arrow_bone", 2)
	var panel = main.hud.option_panel
	panel.select_target(bow)
	await wait_frames(2)
	var kinds: Container = panel.button_container.get_node_or_null(String(panel.AMMO_KINDS_NAME)) as Container
	assert_not_null(kinds, "its ammunition stands together on its card")
	if kinds == null:
		return
	# Squares, as his abilities are (the player: "可以改成图片，小方块，类似人的能力").
	var squares: Array = kinds.get_children().filter(func(c): return String(c.name).begins_with("Ammo_"))
	assert_eq(squares.size(), config_node.ammo_accepts("bow_tower").size(), "a square for each kind it takes")
	var wood: Button = kinds.get_node_or_null("Ammo_arrow_wood") as Button
	assert_not_null(wood, "wooden arrows")
	assert_eq(wood.theme_type_variation, &"SlotButton", "a square with its icon")
	assert_eq(wood.custom_minimum_size.x, wood.custom_minimum_size.y, "square")
	assert_eq(wood.text, "", "no words on it: its name is in its tooltip")
	assert_true(wood.tooltip_text.begins_with(tr(String(config_node.AMMO["arrow_wood"]["name"]))), "named there")
	assert_true(wood.button_pressed, "set to nothing, the first the stock has is the one lit")
	assert_eq(String((wood.get_node("Figure") as Label).text), "6", "each says in its corner how much the stock holds")
	var load_btn: Button = kinds.get_node_or_null("LoadCommand") as Button
	assert_not_null(load_btn, "and Load, a square too")
	assert_false(load_btn.disabled, "to be pressed while there is some to load")
	assert_eq(load_btn.tooltip_text, tr("TIP_LOAD"), "saying what it does")
	# The magazine: what is in it and how full, empty to begin with.
	var mag: Node = panel.button_container.get_node_or_null("Magazine")
	assert_not_null(mag, "its magazine stands over the squares")
	var figure: Label = panel.button_container.find_child("RoundsText", true, false) as Label
	assert_eq(figure.text, UiKit.fraction_text(0, bow.capacity()), "empty: nothing of its capacity")
	assert_eq(String((panel.button_container.find_child("Loaded", true, false) as Label).text), tr("CARD_MAGAZINE_EMPTY"),
		"and it says so")
	(kinds.get_node("Ammo_arrow_bone") as Button).pressed.emit()
	assert_eq(String(bow.ammo_type), "arrow_bone", "a kind chosen sets it to that")
	assert_eq(main.hero.target_building, bow, "and sends him to load it")
	await wait_frames(1)
	panel._update_status_display()
	var going: Button = panel.button_container.find_child("LoadCommand", true, false) as Button
	assert_true(going.button_pressed, "Load lit while he is on his way")
	assert_eq(going.tooltip_text, tr("TIP_LOAD_GOING"), "and says so")
	assert_gt(bow.load_from_stock(), 0, "loaded")
	panel._update_status_display()
	await wait_frames(1)
	figure = panel.button_container.find_child("RoundsText", true, false) as Label
	assert_eq(figure.text, UiKit.fraction_text(bow.rounds(), bow.capacity()), "the magazine says how full it is")
	var bar: ProgressBar = panel.button_container.find_child("RoundsBar", true, false) as ProgressBar
	assert_almost_eq(bar.value, float(bow.rounds()) / float(bow.capacity()), 0.001, "and its bar shows it")
	assert_eq(String((panel.button_container.find_child("Loaded", true, false) as Label).text),
		tr(String(config_node.AMMO["arrow_bone"]["name"])), "what is in it named")
	var done: Button = panel.button_container.find_child("LoadCommand", true, false) as Button
	assert_true(done.disabled, "the stock of bone arrows used up: nothing more to load")
	assert_eq(done.tooltip_text, tr("TIP_LOAD_NONE"), "and Load says why")

func test_12_the_workbench_keeps_its_ammunition_apart() -> void:
	var main = await _level()
	know_everything()
	stock_everything()
	var bench: Node = null
	for s in tree.get_nodes_in_group("stations"):
		if String(s.station_id) == "workbench":
			bench = s
	assert_not_null(bench, "the cabin has its workbench")
	var panel = main.hud.option_panel
	panel.select_target(bench)
	await wait_frames(2)
	var block: Node = panel.button_container.get_node_or_null(String(panel.AMMO_BLOCK_NAME))
	assert_not_null(block, "its ammunition in a block of its own")
	if block == null:
		return
	for rid in _ammo_recipes():
		assert_not_null(block.find_child("Job_%s" % rid, true, false), "%s in it" % rid)
	var detail: String = String(UiKit.job_detail(bench, "arrow_wood")[0])
	assert_true(detail.contains(str(int(config_node.RECIPES["arrow_wood"]["makes"]["arrow_wood"]))), "on hover, how many a batch makes: %s" % detail)
