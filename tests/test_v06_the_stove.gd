# res://tests/test_v06_the_stove.gd
# v0.6 round seven, the player: "kitchen的石锅目的是升级kitchen（应该叫灶台），roast meat是功能，这两个不应该放在一起，对于
# 灶台的升级应该有个不一样的layout形式".
#
# The kitchen is the stove. On its card what it cooks are its jobs, a card each; the pot -- which makes the stove
# itself better, every meal after it cooked on it -- is not one of them: it stands apart under them in a sunken
# block of its own, under a heading, with what it changes before and after, and the card that makes it.
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

## The level, everything in stock and known, and the stove's card up: [level, card, stove].
func _stove_card() -> Array:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	main.wave_manager.auto_raid_enabled = false
	stock_everything()
	know_everything()
	var stove: Node = main.current_core.station("kitchen")
	var panel = main.hud.option_panel
	panel.select_target(stove)
	await wait_frames(1)
	return [main, panel, stove]

## The stove's upgrades, as Config has them: what is made at it and makes it better.
func _pots() -> Array[String]:
	var out: Array[String] = []
	for recipe_id in config_node.RECIPES:
		if String(config_node.RECIPES[recipe_id].get("station", "")) == "kitchen" and config_node.improves_bench(String(recipe_id)):
			out.append(String(recipe_id))
	return out

## The cooking method a vessel brings, and the one there is with none.
func _method_of(vessel: String) -> String:
	for method in config_node.COOKING_METHODS:
		if String(method.get("vessel", "")) == vessel:
			return String(method["id"])
	return ""

func test_01_the_kitchen_is_called_the_stove() -> void:
	var names: Dictionary = {"zh_CN": "灶台", "en": "Stove"}
	for locale in names:
		var said: Translation = TranslationServer.get_translation_object(locale)
		assert_not_null(said, "(the %s words)" % locale)
		if said == null:
			continue
		assert_eq(String(said.get_message("STATION_KITCHEN_NAME")), String(names[locale]), "In %s it is the %s" % [locale, names[locale]])
		# And nothing the game says calls it the kitchen any more.
		for key in said.get_message_list():
			var text: String = String(said.get_message(key))
			assert_false(text.contains("厨房") or text.to_lower().contains("kitchen"), "%s no longer says kitchen (%s)" % [key, text])

func test_02_its_pot_is_its_upgrade_not_one_of_its_jobs() -> void:
	var pots: Array[String] = _pots()
	assert_false(pots.is_empty(), "The stove has a pot to be made better by")
	for recipe_id in config_node.RECIPES:
		var rid: String = String(recipe_id)
		if String(config_node.RECIPES[rid].get("station", "")) != "kitchen":
			assert_false(config_node.improves_bench(rid), "%s is what its bench is for, not the bench made better" % rid)
	for dish_id in config_node.DISHES:
		assert_false(config_node.improves_bench(String(dish_id)), "A meal is what the stove is for (%s)" % dish_id)
	var got: Array = await _stove_card()
	var panel = got[1]
	var stove: Node = got[2]
	var block: Control = panel.button_container.get_node_or_null(String(panel.BENCH_UPGRADE_NAME)) as Control
	assert_not_null(block, "On its card the upgrade is a block of its own")
	if block == null:
		return
	for pot in pots:
		assert_null(panel.button_container.get_node_or_null("Job_%s" % pot), "%s is not among its jobs" % pot)
		assert_not_null(block.find_child("Job_%s" % pot, true, false), "but in the block, as its card")
	var meals: int = 0
	for dish_id in stove.dishes():
		var card: Node = panel.button_container.get_node_or_null("Job_%s" % dish_id)
		assert_not_null(card, "What it cooks are its jobs (%s)" % dish_id)
		if card != null:
			meals += 1
			assert_lt(card.get_index(), block.get_index(), "and stand above the upgrade (%s)" % dish_id)
	assert_gt(meals, 0, "(its meals on offer)")
	assert_eq(String(block.theme_type_variation), "InsetPanel", "Set apart: sunk in the card, not a card among cards")
	var title: Label = block.find_child("UpgradeTitle", true, false) as Label
	assert_not_null(title, "Under a heading")
	if title != null:
		assert_eq(title.text, tr("STATION_UPGRADE") % String(stove.get_localized_name()), "that says it upgrades the stove")

func test_03_it_says_in_a_line_what_the_upgrade_changes_before_and_after() -> void:
	# The way a building's upgrade says it (STAT_*): only what changes, before and after -- in one line, so the
	# block and its card stand on the card whole.
	var got: Array = await _stove_card()
	var panel = got[1]
	var stove: Node = got[2]
	var pot: String = _pots()[0]
	var vessel: String = String(config_node.RECIPES[pot]["unlocks"])
	var dish: String = String(stove.dishes()[0])
	var block: Control = panel.button_container.get_node_or_null(String(panel.BENCH_UPGRADE_NAME)) as Control
	assert_not_null(block, "(its block)")
	if block == null:
		return
	var said: Label = block.find_child("UpgradeChange", true, false) as Label
	assert_not_null(said, "A line says what it changes")
	if said == null:
		return
	var text: String = said.text
	var now: Dictionary = config_node.meal_of(dish, game_state_node.unlocks)
	var upgraded: Dictionary = game_state_node.unlocks.duplicate()
	upgraded[vessel] = true
	var then: Dictionary = config_node.meal_of(dish, upgraded)
	assert_eq(String(now["method"]), _method_of(""), "(with no pot, the meal is cooked the way that needs none)")
	assert_eq(String(then["method"]), _method_of(vessel), "(with it, the pot's way)")
	assert_true(text.begins_with(config_node.meal_name(dish, String(now["method"]))), "From the meal as it comes now (%s)" % text)
	assert_true(text.contains(config_node.meal_name(dish, String(then["method"]))), "to the meal as it would")
	assert_ne(float(now["heal"]), float(then["heal"]), "(the pot heals more)")
	assert_true(text.contains(tr("MEAL_STAT_HEAL") % [config_node.factor_text(float(now["heal"])), config_node.factor_text(float(then["heal"]))]),
		"what it heals, before and after (%s)" % text)
	if float(now["max_hp"]) <= 0.0 and float(then["max_hp"]) > 0.0:
		assert_true(text.contains(tr("EFFECT_MAX_HP") % int(round(float(then["max_hp"])))), "and what it brings that was not there")
	if is_equal_approx(float(now["build_speed"]), float(then["build_speed"])):
		assert_false(text.contains(tr("EFFECT_BUILD_SPEED") % config_node.factor_text(float(then["build_speed"]))),
			"and nothing about what stays as it was")
	assert_eq(text.split("\n").size(), 1, "One line of words")

func test_04_its_keys_go_to_its_meals_first_and_then_to_the_upgrade() -> void:
	var got: Array = await _stove_card()
	var panel = got[1]
	var stove: Node = got[2]
	var pot: String = _pots()[0]
	var buttons: Array = panel.command_buttons()
	var names: Array[String] = []
	for b in buttons:
		names.append(String(b.name))
	var at: int = names.find("Job_%s" % pot)
	assert_gt(at, -1, "The upgrade is one of its commands")
	assert_eq(at, names.size() - 1, "the last of them: its meals come first (%s)" % ", ".join(names))
	var keys: Array = config_node.CONTROLS["command_keys"]
	if at < keys.size():
		var cap: Label = (buttons[at] as Button).get_node_or_null("Keycap") as Label
		assert_not_null(cap, "It wears its key as a job does")
		if cap != null:
			assert_eq(cap.text, OS.get_keycode_string(int(keys[at])), "(the next key after its meals')")

func test_05_pressed_it_makes_the_pot_and_once_made_the_block_is_gone() -> void:
	var got: Array = await _stove_card()
	var panel = got[1]
	var stove: Node = got[2]
	var pot: String = _pots()[0]
	var block: Control = panel.button_container.get_node_or_null(String(panel.BENCH_UPGRADE_NAME)) as Control
	var card: Button = block.find_child("Job_%s" % pot, true, false) as Button if block != null else null
	assert_not_null(card, "(the upgrade's card)")
	if card == null:
		return
	assert_false(card.disabled, "With the stock for it, it can be pressed")
	card.emit_signal("pressed")
	assert_eq(String(stove.active_recipe), pot, "Pressed, the stove sets to making it")
	stove.work(float(stove.time_of(pot)) + 0.01)
	assert_true(game_state_node.has_unlock(String(config_node.RECIPES[pot]["unlocks"])), "(made)")
	panel.select_target(stove)
	await wait_frames(1)
	assert_null(panel.button_container.get_node_or_null(String(panel.BENCH_UPGRADE_NAME)), "Made, there is no upgrade left to show")
	var dish: String = String(stove.dishes()[0])
	var meal: Button = panel.button_container.get_node_or_null("Job_%s" % dish) as Button
	assert_not_null(meal, "and its meals are still its jobs")
	if meal != null:
		assert_eq(meal.text, stove.recipe_name(dish), "now cooked on the pot (%s)" % meal.text)

func test_06_the_workbench_has_no_such_block() -> void:
	var got: Array = await _stove_card()
	var main = got[0]
	var panel = got[1]
	panel.select_target(main.current_core.station("workbench"))
	await wait_frames(1)
	assert_null(panel.button_container.get_node_or_null(String(panel.BENCH_UPGRADE_NAME)),
		"What the workbench makes is for him, not the bench made better")
	assert_gt(panel.command_buttons().size(), 0, "(its jobs are there)")
