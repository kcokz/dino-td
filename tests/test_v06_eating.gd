# res://tests/test_v06_eating.gd
# v0.6 feedback, round two, 8: "肉的作用非常不明显，做完之后也没有吃的动作，哪怕是自动吃了，人也没有明显吃了肉之后的
# 状态转化效果" -- and, asked what to do about it: "吃饭的逻辑要彻底改一下。我觉得人的面板需要重新设计：Build 可以作为
# 一个图标。吃饭也是一个图标，点进去呢就有吃的东西。然后在人的界面面板上还要有显示血量、建造速度、移动速度，分别都有一个
# 血条。然后吃了饭之后会有一个 boost，那个 boost 要比较清楚地显示在移动速度、血量上面".
#
# THE KITCHEN COOKS, HE EATS WHEN HE IS TOLD. A meal is put by in his stock (GameState.meals) and
# eaten from his panel, wherever he is: he stands, the meat in his hand at his mouth, for a while,
# and then its boost is his -- hit points over his own, a quicker stride, and with a pot faster
# hands -- drawn gold on the end of his three bars, with what he ate and how long it lasts under
# them, and a ring at his feet.
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

func _hero() -> Node:
	var h = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(h)
	tree.root.add_child(h)
	return h

func _roast() -> String:
	return String(config_node.COOKING_METHODS.back()["id"])

func _roast_meat() -> String:
	return game_state_node.meal_key("meat", _roast())

func _eat_seconds() -> float:
	return float(config_node.EATING["eat_seconds"])

## The Hero's card: an option panel in the tree, showing him.
func _card(hero: Node) -> Node:
	var panel = load("res://scripts/ui/OptionPanel.gd").new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	panel.select_target(hero)
	return panel

func _stat(panel: Node, key: String) -> Node:
	return panel.find_child(key.capitalize() + "Stat", true, false)

# ==============================================================================
# 1. A stock of cooked meals
# ==============================================================================

func test_01_a_meal_is_put_by_the_way_it_was_cooked_and_eaten_from_the_stock() -> void:
	var key: String = game_state_node.stock_meal("meat")
	assert_eq(key, _roast_meat(), "Cooked with no pot, it is roast meat")
	game_state_node.stock_meal("meat")
	assert_eq(game_state_node.meal_count(key), 2, "Two of them")
	# A pot made since does not make roast meat seared.
	game_state_node.grant_unlock(String(config_node.COOKING_METHODS[0]["vessel"]))
	var seared: String = game_state_node.stock_meal("meat")
	assert_ne(seared, key, "Meat cooked now is cooked the better way")
	assert_eq(game_state_node.meal_count(key), 2, "And the roast is still roast")
	assert_eq(game_state_node.meals_in_stock().size(), 2, "Two kinds of meal in the stock")

	var meal: Dictionary = game_state_node.eat_meal(key)
	assert_eq(String(meal.get("method", "")), _roast(), "Eaten as it was cooked")
	assert_eq(game_state_node.meal_count(key), 1, "One fewer")
	game_state_node.eat_meal(key)
	assert_true(game_state_node.eat_meal(key).is_empty(), "There is none left to eat")

func test_02_a_new_run_starts_with_nothing_cooked() -> void:
	game_state_node.stock_meal("meat")
	game_state_node.reset_game()
	assert_true(game_state_node.meals.is_empty(), "Nothing put by")

# ==============================================================================
# 2. He eats: it takes a while, and it is seen
# ==============================================================================

func test_03_he_eats_standing_the_meat_in_his_hand_and_it_is_his_when_he_is_done() -> void:
	var hero = _hero()
	await wait_frames(1)
	var key: String = game_state_node.stock_meal("meat")
	hero.current_hp = 2.0
	assert_true(hero.order_eat(key), "He is told to eat")
	assert_true(hero.is_eating(), "He is eating")
	assert_not_null(hero.find_child("MealInHand", true, false), "The meat in his hand")
	hero._process_eating(_eat_seconds() * 0.5)
	assert_eq(game_state_node.meal_count(key), 1, "Half eaten is not eaten")
	assert_true(game_state_node.fed.is_empty(), "And no boost yet")

	hero._process_eating(_eat_seconds() * 0.5 + 0.01)
	assert_false(hero.is_eating(), "Done")
	assert_eq(game_state_node.meal_count(key), 0, "The meal is gone from the stock")
	var meal: Dictionary = config_node.meal_cooked("meat", _roast())
	assert_almost_eq(hero.current_hp, 2.0 + float(meal["max_hp"]) + float(meal["heal"]), 0.001,
		"And into him: the heal, and any hit points over his own the meal gives")
	assert_false(game_state_node.fed.is_empty(), "He is fed")
	await wait_frames(1)
	assert_null(hero.find_child("MealInHand", true, false), "His hand is empty again")

func test_04_told_to_do_something_else_he_puts_it_down_uneaten() -> void:
	var hero = _hero()
	await wait_frames(1)
	var key: String = game_state_node.stock_meal("meat")
	hero.order_eat(key)
	hero._process_eating(_eat_seconds() * 0.5)
	hero.move_to(hero.global_position + Vector3(4.0, 0.0, 0.0))
	assert_false(hero.is_eating(), "He has stopped eating")
	assert_eq(game_state_node.meal_count(key), 1, "And the meal is still in the stock")
	assert_true(game_state_node.fed.is_empty(), "Uneaten")
	await wait_frames(1)
	assert_null(hero.find_child("MealInHand", true, false), "Put down")

func test_05_he_cannot_eat_what_has_not_been_cooked() -> void:
	var hero = _hero()
	await wait_frames(1)
	assert_false(hero.order_eat(_roast_meat()), "Nothing cooked, nothing to eat")
	assert_false(hero.is_eating(), "So he does not stand there eating nothing")

func test_06_eating_is_his_hand_to_his_mouth() -> void:
	# The eat clip is made for him (tools/build_hero.py): the library had none.
	var hero = _hero()
	await wait_frames(2)
	var player: AnimationPlayer = hero.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer \
		if not hero.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	assert_not_null(player, "He is animated")
	if player == null:
		return
	assert_true(player.has_animation(String(config_node.ANIMATIONS["hero"]["EATING"])), "He has a clip for eating")
	hero.order_eat(game_state_node.stock_meal("meat"))
	await wait_frames(2)
	assert_eq(String(player.current_animation), String(config_node.ANIMATIONS["hero"]["EATING"]), "And plays it while he eats")

# ==============================================================================
# 3. The boost: how much, how long, and that it shows
# ==============================================================================

func test_07_every_meal_is_a_boost_and_a_pot_adds_to_it() -> void:
	# v0.6 round three: his stride is his boots' now (RECIPES hide_boots); a meal heals him and he
	# works faster for a while, and the pot heals more and holds him up with hit points over his own.
	var roast: Dictionary = config_node.meal_cooked("meat", _roast())
	assert_gt(float(roast["build_speed"]), 1.0, "Even a roast quickens his work")
	assert_gt(float(roast["fed_seconds"]), 0.0, "For a while")
	var best: Dictionary = config_node.meal_cooked("meat", String(config_node.COOKING_METHODS[0]["id"]))
	assert_gt(float(best["heal"]), float(roast["heal"]), "The pot heals more")
	assert_gt(float(best["max_hp"]), float(roast["max_hp"]), "and holds him up over his own hit points")
	for method in config_node.COOKING_METHODS:
		for dish in config_node.DISHES:
			assert_eq(float(config_node.meal_cooked(dish, String(method["id"]))["move_speed"]), 1.0,
				"No meal changes his stride (%s, %s)" % [dish, method["id"]])

func test_08_when_it_wears_off_he_is_his_own_size_again() -> void:
	var hero = _hero()
	await wait_frames(1)
	var own: float = hero.max_hp
	# The pot's meal: the one that holds him up over his own hit points (COOKING_METHODS).
	game_state_node.grant_unlock(String(config_node.COOKING_METHODS[0]["vessel"]))
	game_state_node.eat("meat")
	assert_gt(hero.max_hp, own, "Fed, he has more to lose")
	var aura: Node3D = hero.find_child("FedAura", false, false) as Node3D
	assert_true(aura != null and aura.visible, "And a ring at his feet says so")
	game_state_node.wear_off(float(config_node.DISHES["meat"]["fed_seconds"]) + 1.0)
	assert_almost_eq(hero.max_hp, own, 0.001, "Worn off, he is back to his own")
	assert_lte(hero.current_hp, hero.max_hp, "And no more hit points than that")
	assert_false(aura.visible, "The ring goes")

# ==============================================================================
# 4. His card: three bars, the boost gold on them, and his commands as icons
# ==============================================================================

func test_09_his_card_has_his_three_bars_and_the_boost_is_gold_on_them() -> void:
	var hero = _hero()
	await wait_frames(1)
	var panel = _card(hero)
	await wait_frames(1)
	for key in ["hp", "build", "move"]:
		assert_not_null(_stat(panel, key), "A bar for his %s" % key)
	var boost_row: Control = panel.find_child("BoostRow", true, false) as Control
	panel._update_status_display()
	assert_false(_stat(panel, "hp").get_node("Bar").has_boost(), "Unfed: no gold on his health")
	assert_false(_stat(panel, "move").get_node("Bar").has_boost(), "Nor on his stride")
	assert_false(boost_row.visible, "And no meal to speak of")

	# The pot's meal (v0.6 round three): hit points over his own and quicker hands; his stride is
	# his boots', and no meal touches it.
	game_state_node.grant_unlock(String(config_node.COOKING_METHODS[0]["vessel"]))
	game_state_node.eat("meat")
	panel._update_status_display()
	assert_true(_stat(panel, "hp").get_node("Bar").has_boost(), "Fed: the meal's hit points gold on the end of his health")
	assert_true(_stat(panel, "build").get_node("Bar").has_boost(), "And on his hands")
	assert_false(_stat(panel, "move").get_node("Bar").has_boost(), "Not on his stride")
	assert_eq(String((_stat(panel, "build").get_node("Figure") as Label).theme_type_variation), "BoostNumberLabel",
		"His building speed's figure is gold")
	assert_true(boost_row.visible, "What he ate, and for how long")
	var meat: String = tr(String(config_node.DISHES["meat"]["name"]))
	assert_true(String((boost_row.get_node("Text") as Label).text).contains(meat), "Named")

func test_10_build_and_eat_are_icons_and_eat_counts_what_is_cooked() -> void:
	var hero = _hero()
	await wait_frames(1)
	var panel = _card(hero)
	await wait_frames(1)
	var build: Button = panel.find_child("BuildCommand", true, false) as Button
	var eat: Button = panel.find_child("EatCommand", true, false) as Button
	assert_not_null(build, "Build is a command on his card")
	assert_not_null(eat, "And so is Eat")
	if build == null or eat == null:
		return
	assert_not_null(build.icon, "Build is an icon")
	assert_not_null(eat.icon, "And Eat")
	assert_true(eat.disabled, "Nothing cooked: nothing to press")

	game_state_node.stock_meal("meat")
	game_state_node.stock_meal("meat")
	await wait_frames(1)
	eat = panel.find_child("EatCommand", true, false) as Button
	assert_false(eat.disabled, "Cooked: it can be pressed")
	var badge: Label = eat.get_node_or_null("Badge") as Label
	assert_not_null(badge, "With a count on it")
	if badge:
		assert_eq(badge.text, "2", "Of the meals cooked")

func test_11_the_eat_page_lists_the_meals_and_one_is_eaten_from_it() -> void:
	var hero = _hero()
	await wait_frames(1)
	var key: String = game_state_node.stock_meal("meat")
	game_state_node.stock_meal("prime_meat")
	var panel = _card(hero)
	await wait_frames(1)
	panel._on_eat_pressed()
	var cards: Array = []
	for child in panel.button_container.get_children():
		if child is Button and String(child.theme_type_variation) == "CardButton":
			cards.append(child)
	assert_eq(cards.size(), 2, "A card for each meal cooked")
	var roast_name: String = panel._meal_name("meat", _roast())
	var pressed: bool = false
	for card in cards:
		if String(card.text).begins_with(roast_name):
			card.emit_signal("pressed")
			pressed = true
			break
	assert_true(pressed, "The roast meat's card is there to press")
	assert_true(hero.is_eating(), "And pressing it sets him eating")
	assert_eq(String(panel.current_menu), "default", "His card goes back to his commands")
	hero._process_eating(_eat_seconds() + 0.01)
	assert_eq(game_state_node.meal_count(key), 0, "The roast is eaten")
