# res://tests/test_v07_the_workshops.gd
# The player, 2026-10-05: "把后面几关都先做起来，主要是科技树升级部分".
#
# THE WORKSHOPS OUT IN THE OPEN (Workshop; GAME-DESIGN 5.2-5.4): the kiln (station 2) fires the river's clay into bricks,
# the brick wall is the stone wall's next step; the bloomery (station 3), of bricks and a hide, smelts bog iron into
# iron, and iron heads the arrows that go through armour. A workshop is a building he raises and a bench he works at:
# a job is paid for when begun and he is sent to it; it goes on only while he works at it; what it makes goes into the
# stock. Each new material is for one or two things.
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
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	load("res://scripts/entities/Dino.gd").clear_all_attack_slots()
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	return main

## `type_id` standing finished a few cells off the cabin's door, paid for out of a full stock.
func _standing(main: Node, type_id: String, off: Vector2i = Vector2i(5, 5)) -> Node:
	stock_everything()
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_build_cell(main.hero.global_position) + off
	var b = main.build_system.place_at(type_id, cell, main.buildings_container, false)
	assert_not_null(b, "%s goes down" % type_id)
	if b != null and not b.is_constructed:
		b.complete_construction()
	return b

## The stock set to exactly `amounts` of what is named, the rest as it is.
func _stock(amounts: Dictionary) -> void:
	for res_id in amounts:
		game_state_node.resources[res_id] = int(amounts[res_id])

func _recipe(id: String) -> Dictionary:
	return config_node.RECIPES[id]

func test_01_the_workshops_are_built_of_what_they_are_named_for_and_stand_in_the_camp_tab() -> void:
	for type_id in ["kiln", "furnace"]:
		var row: Dictionary = config_node.BUILDINGS[type_id]
		assert_has(config_node.BUILDABLE_TYPES, type_id, "%s is on his build menu" % type_id)
		assert_eq(String(config_node.build_tab_of(type_id)), "camp", "in the camp tab")
		assert_eq(String(row["kind"]), "workshop", "a workshop")
		assert_lte(row["cost"].size(), 2, "of two materials at most (4.1 rule 2)")
		assert_false(String(row.get("station", "")) == "", "with a bench of its own")
		assert_gt(config_node.recipes_at(String(row["station"])).size(), 0, "and work at it")
		assert_true(ResourceLoader.exists(String(config_node.ICON_DIR) + type_id + ".svg"), "drawn in the menu")
	assert_has(config_node.BUILDINGS["kiln"]["cost"], "clay", "The kiln: clay")
	assert_has(config_node.BUILDINGS["kiln"]["cost"], "stone", "on stone")
	assert_has(config_node.BUILDINGS["furnace"]["cost"], "brick", "The bloomery: bricks")
	assert_has(config_node.BUILDINGS["furnace"]["cost"], "hide", "and a hide for its bellows")
	assert_eq(String(_recipe("brick")["station"]), "kiln", "Bricks are fired in the kiln")
	assert_eq(String(_recipe("iron")["station"]), "furnace", "iron smelted in the bloomery")
	for rid in ["brick", "iron"]:
		assert_true(config_node.makes_batch(rid), "%s is a batch into the stock" % rid)
		assert_false(config_node.makes_ammo(rid), "and no ammunition")
		assert_has(_recipe(rid)["inputs"], "wood", "%s burns wood (5.4 rule 5: two materials, the fuel one)" % rid)
		assert_lte(_recipe(rid)["inputs"].size(), 2, "and one other")

func test_02_a_job_begun_at_the_kiln_is_paid_and_sends_him_to_it() -> void:
	var main = await _level()
	var kiln = _standing(main, "kiln")
	if kiln == null:
		return
	await wait_frames(1)
	assert_not_null(kiln.station, "The kiln has a bench")
	assert_has(kiln.station.jobs(), "brick", "that fires bricks")
	_stock({"clay": 10, "wood": 10, "brick": 0})
	var inputs: Dictionary = _recipe("brick")["inputs"]
	assert_true(kiln.begin("brick"), "A job begun")
	assert_eq(int(game_state_node.resources["clay"]), 10 - int(inputs["clay"]), "its clay paid as it is begun")
	assert_eq(int(game_state_node.resources["wood"]), 10 - int(inputs["wood"]), "and its wood")
	assert_eq(main.hero.target_building, kiln, "and he is sent to it")
	assert_false(kiln.begin("brick") and String(kiln.station.active_recipe) != "brick", "One job at a time")

func test_03_it_goes_on_only_while_he_works_at_it_and_its_bricks_go_into_the_stock() -> void:
	var main = await _level()
	var kiln = _standing(main, "kiln")
	if kiln == null:
		return
	_stock({"clay": 10, "wood": 10, "brick": 0})
	assert_true(kiln.begin("brick"), "(begun)")
	main.hero.order_stop()
	var time: float = float(_recipe("brick")["time"])
	# Nobody at it: nothing moves, and its card says why.
	await wait_seconds(0.4)
	assert_almost_eq(float(kiln.station.progress), 0.0, 0.0001, "Left alone, the kiln does nothing")
	assert_false(kiln.is_working(), "its fire out")
	assert_eq(String(kiln.get_display_info().get("status", "")), tr("STATION_ONLY_BESIDE_HIM"), "and its card says it waits on him")
	# He works at it: it goes on, its fire showing, and finished, its bricks are in the stock.
	assert_false(kiln.work(time * 0.5), "Half done")
	assert_true(kiln.is_working(), "its fire going while he works it")
	assert_true(kiln.work(time * 0.6), "and done")
	var makes: Dictionary = _recipe("brick")["makes"]
	assert_eq(int(game_state_node.resources["brick"]), int(makes["brick"]), "its bricks in the stock")
	assert_false(kiln.has_job(), "nothing under way")

func test_04_at_it_he_tends_the_fire_and_does_not_hammer() -> void:
	var main = await _level()
	var kiln = _standing(main, "kiln", Vector2i(3, 3))
	if kiln == null:
		return
	_stock({"clay": 10, "wood": 10, "brick": 0})
	assert_true(kiln.begin("brick"), "(begun, he sent)")
	var spent: int = 0
	while not kiln.is_tended() and spent < 600:
		await tree.physics_frame
		spent += 1
	assert_true(kiln.is_tended(), "He walks to it and works it")
	assert_false(main.hero.has_hammer_out(), "tending its fire, no hammer in his hand")
	var before: float = float(kiln.station.progress)
	await wait_frames(10)
	assert_gt(float(kiln.station.progress), before, "and the job goes on while he is at it")

func test_05_the_stone_wall_is_coursed_in_brick() -> void:
	assert_has(config_node.upgrade_targets("stone_wall"), "brick_wall", "The stone wall becomes a brick wall")
	var cost: Dictionary = config_node.upgrade_cost("stone_wall", "brick_wall")
	assert_eq(cost.keys(), ["brick"], "for bricks")
	assert_gt(float(config_node.BUILDINGS["brick_wall"]["hp"]), float(config_node.BUILDINGS["stone_wall"]["hp"]),
		"and stands more bites than stone")
	assert_eq(String(config_node.get_building_kind("brick_wall")), "wall", "a wall, as the stone one is")
	assert_eq(int(config_node.get_building_cells("brick_wall")), int(config_node.get_building_cells("stone_wall")),
		"in the same cell")
	assert_false(config_node.BUILDABLE_TYPES.has("brick_wall"), "an upgrade, not another entry on the menu")

func test_06_the_bloomery_smelts_bog_iron_dug_with_the_shovel() -> void:
	var main = await _level()
	var furnace = _standing(main, "furnace")
	if furnace == null:
		return
	var node_row: Dictionary = config_node.RESOURCE_NODES["iron_ore"]
	var shovel_flag: String = String(config_node.RECIPES["bone_shovel"]["unlocks"])
	assert_eq(String(node_row["requires_unlock"]), shovel_flag, "Bog iron is dug with the bone shovel")
	assert_has(config_node.recipe_opens_all("bone_shovel"), "iron_ore", "which says so")
	assert_true(String(config_node.recipe_use_text("bone_shovel")).contains(tr(String(node_row["name"]))),
		"in its own words")
	_stock({"iron_ore": 6, "wood": 10, "iron": 0})
	assert_true(furnace.begin("iron"), "Smelting begun")
	var time: float = float(_recipe("iron")["time"])
	assert_true(furnace.work(time + 0.1), "and done while he works the bellows")
	assert_eq(int(game_state_node.resources["iron"]), int(_recipe("iron")["makes"]["iron"]), "iron in the stock")

func test_07_iron_tipped_arrows_go_through_armour() -> void:
	var row: Dictionary = config_node.AMMO["arrow_iron"]
	assert_eq(String(row["for"]), "bow", "Iron-tipped arrows are the bow tower's")
	for level in ["bow_tower", "bow_tower_2", "bow_tower_3"]:
		assert_has(config_node.ammo_accepts(level), "arrow_iron", "%s takes them" % level)
	assert_has(_recipe("arrow_iron")["inputs"], "iron", "made of iron")
	assert_true(config_node.makes_ammo("arrow_iron"), "a batch of ammunition at the workbench")
	var plated: String = ""
	for species in config_node.DINOS:
		if bool(config_node.DINOS[species].get("armored", false)):
			plated = String(species)
			break
	assert_ne(plated, "", "(an armoured animal to try it on)")
	var d = load(String(config_node.get_dino_script_path(plated))).new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup(plated)
	var iron: float = AmmoTower.armour_factor(d, row)
	var wood: float = AmmoTower.armour_factor(d, config_node.AMMO["arrow_wood"])
	assert_almost_eq(iron, float(row["through_armour"]), 0.0001, "Of an iron head, its own share gets through")
	assert_gt(iron, wood, "more than of a wooden one")
	assert_gt(float(row["damage"]), float(config_node.AMMO["arrow_wood"]["damage"]), "and it hits harder")

func test_08_each_new_material_is_for_one_or_two_things_and_says_where_it_is_made() -> void:
	for res_id in ["brick", "iron", "iron_ore", "clay", "hide"]:
		var kinds: Dictionary = {}
		for use in config_node.uses_of(res_id):
			kinds[String(use["kind"])] = true
		assert_gte(kinds.size(), 1, "%s is for something" % res_id)
		assert_lte(kinds.size(), 2, "%s is for at most two things (4.1 rule 7): %s" % [res_id, kinds.keys()])
	var tip: String = String(config_node.resource_tip("brick"))
	assert_true(tip.contains(tr("STATION_KILN_NAME")), "Bricks come from the kiln, the bar says: %s" % tip)
	var clay_tip: String = String(config_node.resource_tip("clay"))
	assert_true(clay_tip.contains(tr("USE_KIND_AT_KILN") % tr("RESOURCE_BRICK")), "and clay is for firing bricks: %s" % clay_tip)
	for word in ["BUILDING_KILN_NAME", "BUILDING_FURNACE_NAME", "BUILDING_BRICK_WALL_NAME", "RESOURCE_BRICK", "RESOURCE_IRON",
			"RESOURCE_IRON_ORE", "RESOURCE_ARROW_IRON", "STATION_KILN_DESC", "STATION_FURNACE_DESC", "STATION_ONLY_BESIDE_HIM"]:
		for locale in ["en", "zh_CN"]:
			var t: Translation = TranslationServer.get_translation_object(locale)
			assert_true(t != null and String(t.get_message(word)) != "", "%s in %s" % [word, locale])

func test_09_its_card_offers_its_jobs_and_a_press_begins_one() -> void:
	var main = await _level()
	var kiln = _standing(main, "kiln")
	if kiln == null:
		return
	_stock({"clay": 10, "wood": 10, "brick": 0})
	tree.root.get_node("EventBus").unit_selected.emit(kiln)
	await wait_frames(1)
	var panel = main.hud.option_panel
	var job: Button = panel.button_container.find_child("Job_brick", true, false) as Button
	assert_not_null(job, "The kiln's card offers its bricks")
	if job == null:
		return
	assert_false(job.disabled, "affordable, the card is live")
	job.pressed.emit()
	await wait_frames(1)
	assert_eq(String(kiln.station.active_recipe), "brick", "A press begins it")
	assert_eq(main.hero.target_building, kiln, "and sends him")
	var again: Button = panel.button_container.find_child("Job_brick", true, false) as Button
	assert_true(again != null and again.disabled, "while it is under way, the card is greyed")
