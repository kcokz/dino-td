# res://tests/test_v06_kitchen.gd
# v0.6 T3: the kitchen cooks for him, and a fed man works faster.
#
# GAME-DESIGN 4.5: meat cannot only heal. Once every building is up the raids still leave
# meat, and it has to be worth fetching -- so a meal heals, and a good one leaves him faster
# for a while. THE VESSEL DECIDES WHAT A MEAL DOES, THE MEAT DECIDES HOW MUCH: a better pot
# is a new kind of meal, a better cut a bigger one. Every magnitude here is read from Config.
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
	clear_drops()
	super.after_each()

func _spawn(node: Node) -> Node:
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	return node

func _hero() -> Node:
	return _spawn(load("res://scripts/entities/Hero.gd").new())

## The best cooking method, and the vessel that makes it -- whatever Config calls them.
func _best() -> Dictionary:
	return config_node.COOKING_METHODS[0]

func _bare() -> Dictionary:
	return config_node.COOKING_METHODS.back()

# ==============================================================================
# 1. The tables
# ==============================================================================

func test_01_every_dish_is_one_piece_of_meat_cooked_at_the_kitchen() -> void:
	assert_gt(config_node.DISHES.size(), 0, "There is something to cook")
	for dish_id in config_node.DISHES:
		var dish: Dictionary = config_node.DISHES[dish_id]
		for key in ["name", "station", "inputs", "time", "heal", "build_speed", "move_speed", "fed_seconds"]:
			assert_has(dish, key, "%s declares '%s'" % [dish_id, key])
		assert_has(config_node.STATIONS, String(dish["station"]), "%s is cooked at a station that exists" % dish_id)
		assert_eq(dish["inputs"].size(), 1, "%s is one kind of meat" % dish_id)
		for res_id in dish["inputs"]:
			assert_has(config_node.RESOURCES, String(res_id), "%s is paid for in a real resource" % dish_id)
			assert_eq(int(dish["inputs"][res_id]), 1, "%s is one piece of it" % dish_id)
		assert_gt(float(dish["time"]), 0.0, "%s takes real seconds to cook" % dish_id)

func test_02_a_boss_s_meat_is_clearly_better_on_every_count() -> void:
	# The acceptance line for v0.6: a meal off a boss is clearly better than one off a raptor,
	# or killing the boss was not worth it. "Clearly" is taken as: every speed bonus at least
	# half as big again.
	var meat: Dictionary = config_node.DISHES["meat"]
	var prime: Dictionary = config_node.DISHES["prime_meat"]
	assert_has(prime["inputs"], "prime_meat", "The better dish is the boss's cut")
	for key in ["heal", "fed_seconds"]:
		assert_gt(float(prime[key]), float(meat[key]), "More %s off a boss" % key)
	for key in ["build_speed", "move_speed"]:
		assert_gte(float(prime[key]) - 1.0, (float(meat[key]) - 1.0) * 1.5,
			"A boss's %s is clearly better (%.2f against %.2f)" % [key, float(prime[key]), float(meat[key])])

func test_03_there_is_always_a_way_to_eat_and_every_pot_adds_something() -> void:
	var methods: Array = config_node.COOKING_METHODS
	assert_gt(methods.size(), 1, "More than one way to cook")
	assert_eq(String(_bare()["vessel"]), "", "The last needs no vessel, so meat can always be eaten")
	for i in range(methods.size() - 1):
		var better: Dictionary = methods[i]
		var worse: Dictionary = methods[i + 1]
		for effect in worse["effects"]:
			assert_has(better["effects"], effect, "%s keeps what %s does" % [better["id"], worse["id"]])
		assert_gt(better["effects"].size(), worse["effects"].size(), "And %s adds something" % better["id"])
		var made_in_kitchen: bool = false
		for recipe_id in config_node.RECIPES:
			var r: Dictionary = config_node.RECIPES[recipe_id]
			if String(r["unlocks"]) == String(better["vessel"]) and String(r["station"]) == "kitchen":
				made_in_kitchen = true
		assert_true(made_in_kitchen, "The %s's vessel is made in the kitchen" % better["id"])

# ==============================================================================
# 2. Eating
# ==============================================================================

func test_04_roast_meat_heals_holds_him_up_and_quickens_him() -> void:
	# It healed and did nothing else until v0.6 round two ("肉的作用非常不明显……吃了饭之后会有一个
	# boost"): even the first meal of a run is a boost now -- hit points over his own and a quicker
	# stride for a while -- and the pot is what makes him build faster too.
	var hero = _hero()
	await wait_frames(1)
	hero.current_hp = 1.0
	var meal: Dictionary = game_state_node.eat("meat")
	var dish: Dictionary = config_node.DISHES["meat"]
	assert_eq(String(meal["method"]), String(_bare()["id"]), "With no pot, meat is roasted")
	assert_almost_eq(hero.max_hp, float(config_node.HERO["hp"]) + float(dish["max_hp"]), 0.001,
		"It holds him up: hit points over his own while he is fed")
	assert_almost_eq(hero.current_hp, 1.0 + float(dish["max_hp"]) + float(dish["heal"]), 0.001,
		"And heals him -- the meal's own hit points full, and the heal on top")
	assert_almost_eq(game_state_node.move_multiplier(), float(dish["move_speed"]), 0.0001, "He walks the quicker for it")
	assert_almost_eq(hero.work_rate(), 1.0, 0.0001, "But builds at his own pace: that is the pot's")
	assert_almost_eq(float(game_state_node.fed["seconds_left"]), float(dish["fed_seconds"]), 0.0001, "For a while")

func test_05_seared_on_a_stone_pot_he_also_builds_faster_for_a_while() -> void:
	var hero = _hero()
	await wait_frames(1)
	game_state_node.grant_unlock(String(_best()["vessel"]))
	var meal: Dictionary = game_state_node.eat("meat")
	var dish: Dictionary = config_node.DISHES["meat"]
	assert_eq(String(meal["method"]), String(_best()["id"]), "With the pot, it is cooked the better way")
	assert_almost_eq(game_state_node.build_multiplier(), float(dish["build_speed"]), 0.0001,
		"He builds faster by what the meat gives")
	var walks: float = float(dish["move_speed"]) if _best()["effects"].has("move_speed") else 1.0
	assert_almost_eq(game_state_node.move_multiplier(), walks, 0.0001, "And walks as fast as the method allows")
	assert_almost_eq(float(game_state_node.fed["seconds_left"]), float(dish["fed_seconds"]), 0.0001,
		"For as long as the meat lasts")
	assert_almost_eq(hero.work_rate(), float(dish["build_speed"]), 0.0001, "Which is his work rate now")

func test_06_one_meal_at_a_time() -> void:
	game_state_node.grant_unlock(String(_best()["vessel"]))
	game_state_node.eat("meat")
	game_state_node.eat("prime_meat")
	assert_eq(String(game_state_node.fed["dish"]), "prime_meat", "The new meal replaces the old")
	assert_almost_eq(game_state_node.build_multiplier(), float(config_node.DISHES["prime_meat"]["build_speed"]), 0.0001,
		"Rather than stacking on it")

func test_07_it_wears_off() -> void:
	game_state_node.grant_unlock(String(_best()["vessel"]))
	var watcher = watch_signal(event_bus_node, "fed_changed")
	game_state_node.eat("meat")
	var seconds: float = float(config_node.DISHES["meat"]["fed_seconds"])
	game_state_node.wear_off(seconds * 0.5)
	assert_false(game_state_node.fed.is_empty(), "Half way through, still fed")
	game_state_node.wear_off(seconds * 0.5 + 0.01)
	assert_true(game_state_node.fed.is_empty(), "And then it is gone")
	assert_almost_eq(game_state_node.build_multiplier(), 1.0, 0.0001, "His pace is his own again")
	assert_eq(watcher.emit_count, 2, "Said once when he ate and once when it wore off")

func test_08_a_fed_man_raises_a_building_faster() -> void:
	# The whole point of the meal, measured on the Hero's own build tick rather than on
	# the factor: the same second of work puts up more of a blueprint.
	var grid = _spawn(load("res://scripts/core/GridManager.gd").new())
	var builder = _spawn(load("res://scripts/core/BuildSystem.gd").new())
	builder.setup(grid, null)
	await wait_frames(1)
	stock_everything()
	var b = builder.place_building("wall", Vector2i(4, 4), grid, true)
	assert_not_null(b, "A blueprint to work on")
	if b == null:
		return
	var hero = _hero()
	# Beside it, body to body: standing IN a blueprint he steps out of it first (Hero._step_out_of).
	var beside: float = (float(config_node.get_building_footprint("wall")) + float(config_node.HERO["width"])) * 0.5 + 0.05
	hero.global_position = b.global_position + Vector3(beside, 0.0, 0.0)
	await wait_frames(1)
	hero.target_building = b

	var before: float = float(b.build_progress)
	hero._process_building(0.1)
	var hungry: float = float(b.build_progress) - before
	assert_gt(hungry, 0.0, "He works on it")

	game_state_node.grant_unlock(String(_best()["vessel"]))
	game_state_node.eat("meat")
	before = float(b.build_progress)
	hero._process_building(0.1)
	var fed: float = float(b.build_progress) - before
	assert_almost_eq(fed / hungry, float(config_node.DISHES["meat"]["build_speed"]), 0.01,
		"Fed, the same tenth of a second does that much more")

func test_09_a_fed_man_walks_faster_when_the_meal_says_so() -> void:
	# No v0.6 pot makes him walk faster (the clay pot will, GAME-DESIGN 4.5), but the
	# wiring is there and this is what keeps it honest.
	var hero = _hero()
	await wait_frames(1)
	var pace: float = hero.walk_speed()
	game_state_node.fed = {"move_speed": 1.5, "build_speed": 1.0, "seconds_left": 10.0, "seconds_total": 10.0}
	assert_almost_eq(hero.walk_speed(), pace * 1.5, 0.0001, "His pace goes up by the meal's factor")
	game_state_node.fed = {}

# ==============================================================================
# 3. The kitchen
# ==============================================================================

func test_10_the_kitchen_cooks_a_meal_into_his_stock() -> void:
	# It used to be eaten there and then. Since v0.6 round two a meal is cooked and kept, and he
	# eats it when the player says, wherever he is (test_v06_eating).
	var hero = _hero()
	var kitchen = _spawn(load("res://scripts/entities/CraftingStation.gd").new("kitchen"))
	await wait_frames(1)
	hero.current_hp = 1.0
	game_state_node.resources["food"] = 1
	game_state_node.known["food"] = true      # meat has turned up in this run
	var eaten = watch_signal(event_bus_node, "meal_eaten")
	var stocked = watch_signal(event_bus_node, "meals_changed")

	assert_has(kitchen.dishes(), "meat", "Meat is on the kitchen's menu")
	assert_true(kitchen.begin("meat"), "It takes the job")
	assert_eq(int(game_state_node.resources["food"]), 0, "The meat goes on the fire when the work starts")
	var needed: float = float(config_node.DISHES["meat"]["time"])
	kitchen.work(needed * 0.5)
	assert_false(stocked.emitted, "Half cooked is not a meal")
	kitchen.work(needed * 0.5 + 0.01)
	var key: String = game_state_node.meal_key("meat", String(_bare()["id"]))
	assert_eq(game_state_node.meal_count(key), 1, "Cooked, it is put by: roast meat, one")
	assert_false(eaten.emitted, "Not eaten")
	assert_almost_eq(hero.current_hp, 1.0, 0.001, "And he is none the better for it yet")
	assert_eq(kitchen.active_recipe, "", "The kitchen is free again")
	assert_true(kitchen.can_offer("meat"), "And meat is still on the menu: a meal is not a one-off")

func test_11_a_meal_is_named_for_how_it_will_be_cooked() -> void:
	var kitchen = _spawn(load("res://scripts/entities/CraftingStation.gd").new("kitchen"))
	await wait_frames(1)
	var meat: String = tr(String(config_node.DISHES["meat"]["name"]))
	assert_eq(kitchen.recipe_name("meat"), tr(String(_bare()["name"])) % meat, "Before the pot, roast meat")
	game_state_node.grant_unlock(String(_best()["vessel"]))
	assert_eq(kitchen.recipe_name("meat"), tr(String(_best()["name"])) % meat, "After it, the better way")

# ==============================================================================
# 4. It shows
# ==============================================================================

func test_12_the_top_bar_says_how_much_faster_and_for_how_long() -> void:
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	_spawn(hud)
	await wait_frames(1)
	assert_not_null(hud.fed_label, "There is a place for it")
	assert_false(hud.fed_label.visible, "Nothing to say while he is not fed")

	game_state_node.grant_unlock(String(_best()["vessel"]))
	game_state_node.eat("meat")
	await wait_frames(1)
	assert_true(hud.fed_label.visible, "Fed, it says so")
	assert_true(hud.fed_label.text.contains(config_node.describe_meal(game_state_node.fed, false)),
		"How much faster (%s)" % hud.fed_label.text)

	game_state_node.wear_off(float(config_node.DISHES["meat"]["fed_seconds"]) + 1.0)
	await wait_frames(1)
	assert_false(hud.fed_label.visible, "And goes quiet when it wears off")

func test_13_the_top_bar_has_a_readout_for_every_resource() -> void:
	# Built from Config.RESOURCES: a sixth resource was going to be a sixth hand-placed
	# label, and prime meat is exactly that sixth resource.
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	_spawn(hud)
	await wait_frames(1)
	var res: Dictionary = {}
	for i in range(config_node.RESOURCES.size()):
		res[String(config_node.RESOURCES[i])] = i + 3
	hud._on_resources_changed(res)
	for res_id in config_node.RESOURCES:
		assert_readout(hud, String(res_id), int(res[res_id]), "Showing what %s there is" % res_id)
