# res://tests/test_v06_his_kit.gd
# v0.6 round three: "人还是倒下下会死，但是我们可以增加皮和护甲的一些制作，还有食物的制作，使得人不容易死。人
# 身上现在的能力也可以作为装备栏，增强血量……简单化也是可以的"; "能力和装备栏两个都在又有点过于复杂……不能让玩家
# 觉得复杂"; "武器和鞋子也可以有一格……精英就掉落皮可以做护甲和鞋子就行了"; "骨镐有升级版吗".
#
# One row of what he has made for good, a slot a kind -- pick, axe, weapon, armour, boots
# (Config.KIT_SLOTS). The best of a slot is the one he has, and only its effect counts: armour
# is hit points over his own, boots his stride, a weapon his blows, the stone pick stone twice as
# fast. The bench does not offer what is outclassed. Armour and boots are of hide, which only the
# map's elites leave. His bar shows the armour's part in leather.
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

func _hero() -> Node:
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	return hero

## Makes `recipe_id`: its flag granted, as the bench does when the job is done.
func _make(recipe_id: String) -> void:
	game_state_node.grant_unlock(String(config_node.RECIPES[recipe_id]["unlocks"]))

## The recipes of `slot`, lesser first.
func _of(slot: String) -> Array[String]:
	var out: Array[String] = []
	for recipe_id in config_node.RECIPES:
		if String(config_node.RECIPES[recipe_id].get("slot", "")) == slot:
			out.append(String(recipe_id))
	out.sort_custom(func(a, b): return int(config_node.RECIPES[a]["tier"]) < int(config_node.RECIPES[b]["tier"]))
	return out

func test_01_every_slot_has_something_to_make() -> void:
	for slot in config_node.KIT_SLOTS:
		assert_gt(_of(String(slot)).size(), 0, "Something goes in the %s slot" % slot)
	assert_gt(_of("pick").size(), 1, "The pick has a better one after the bone pick (「骨镐有升级版吗」)")

func test_02_armour_is_hit_points_for_good_and_the_better_replaces_the_lesser() -> void:
	var hero = _hero()
	await wait_frames(1)
	var own: float = float(config_node.HERO["hp"])
	assert_almost_eq(hero.max_hp, own, 0.001, "Bare, his own")
	var armour: Array[String] = _of("armor")
	assert_gt(armour.size(), 1, "Armour, and better armour")
	_make(armour[0])
	await wait_frames(1)
	var first: float = float(config_node.RECIPES[armour[0]]["max_hp"])
	assert_almost_eq(hero.max_hp, own + first, 0.001, "Armour on: more hit points for good")
	assert_almost_eq(hero.current_hp, own + first, 0.001, "and he has them, whole")
	_make(armour[1])
	await wait_frames(1)
	var second: float = float(config_node.RECIPES[armour[1]]["max_hp"])
	assert_almost_eq(hero.max_hp, own + second, 0.001, "The better one in its place -- not both")
	assert_gt(second, first, "and it is better")

func test_03_boots_quicken_his_stride_and_a_weapon_his_blows() -> void:
	var hero = _hero()
	await wait_frames(1)
	var boots: String = _of("boots")[0]
	_make(boots)
	await wait_frames(1)
	assert_almost_eq(hero.walk_speed(), float(config_node.HERO["move_speed"]) * float(config_node.RECIPES[boots]["move_speed"]), 0.001,
		"Boots on: he walks faster")
	var weapons: Array[String] = _of("weapon")
	_make(weapons[0])
	await wait_frames(1)
	assert_almost_eq(hero.damage, float(config_node.HERO["damage"]) * float(config_node.RECIPES[weapons[0]]["damage"]), 0.001,
		"A weapon: he hits harder")
	_make(weapons[weapons.size() - 1])
	await wait_frames(1)
	assert_almost_eq(hero.damage, float(config_node.HERO["damage"]) * float(config_node.RECIPES[weapons[weapons.size() - 1]]["damage"]), 0.001,
		"The better weapon alone -- not the two multiplied")

func test_04_the_stone_pick_quarries_twice_as_fast() -> void:
	var picks: Array[String] = _of("pick")
	_make(picks[0])
	var bare: float = float(config_node.harvest_speed("stone", game_state_node.unlocks))
	_make(picks[1])
	var better: float = float(config_node.harvest_speed("stone", game_state_node.unlocks))
	assert_almost_eq(better, bare * float(config_node.RECIPES[picks[1]]["harvest_speed"]["stone"]), 0.001,
		"Stone comes out as much faster as the stone pick says")
	assert_true(String(config_node.harvest_note("stone", game_state_node.unlocks)).contains(tr(String(config_node.RECIPES[picks[1]]["name"]))),
		"and the pile says it was the stone pick")

func test_05_the_bench_does_not_offer_what_is_outclassed() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	stock_everything()
	var bench = main.current_core.station("workbench")
	var armour: Array[String] = _of("armor")
	assert_true(bench.can_offer(armour[0]), "The vest is on offer")
	_make(armour[1])
	assert_false(bench.can_offer(armour[0]), "Not once the better armour is his")
	assert_false(bench.can_offer(armour[1]), "nor the armour he has")

func test_05b_one_step_of_a_slot_at_a_time_at_the_difference() -> void:
	# The player, v0.6 round six: "bone armer，皮革armer直接冲突了，一起出现（而且很容易一起出现），却只能造
	# 更好的那个". Every slot shows only its next step; a step up costs the difference.
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	stock_everything()
	var bench = main.current_core.station("workbench")
	for slot in config_node.KIT_SLOTS:
		var line: Array[String] = _of(String(slot))
		if line.size() < 2 or String(config_node.RECIPES[line[0]].get("station", "")) != "workbench":
			continue
		assert_true(bench.can_offer(line[0]), "%s: its first step is on the bench" % slot)
		assert_false(bench.can_offer(line[1]), "%s: and not the next one with it" % slot)
		_make(line[0])
		assert_true(bench.can_offer(line[1]), "%s: made, the next step is" % slot)
		var whole: Dictionary = config_node.RECIPES[line[1]]["inputs"]
		var first: Dictionary = config_node.RECIPES[line[0]]["inputs"]
		var price: Dictionary = bench.inputs_of(line[1])
		for res_id in whole:
			assert_eq(int(price.get(res_id, 0)), maxi(0, int(whole[res_id]) - int(first.get(res_id, 0))),
				"%s: the step up costs the difference in %s" % [slot, res_id])
		for res_id in price:
			assert_true(whole.has(res_id), "%s: and nothing it is not made of" % slot)
	var armour: Array[String] = _of("armor")
	assert_eq(bench.inputs_of(armour[1]).keys(), ["hide"], "The armour over the vest is more hide, and only hide")

func test_05c_a_tool_is_made_of_what_it_is_named_for_and_only_that() -> void:
	# The player, v0.6 round six: "材料各种各样，每次造东西都需要各种各样的材料，装备，建筑都需要各种材料，总感觉
	# 有点confuse哪个材料是用来做什么，也很难做规划" -- chosen: a tool or a piece of gear is made of one
	# material, the one in its name (GAME-DESIGN 6.0 rule 1).
	for recipe_id in config_node.RECIPES:
		var row: Dictionary = config_node.RECIPES[recipe_id]
		if String(row.get("slot", "")) == "" and String(row.get("station", "")) != "kitchen":
			continue
		assert_eq((row["inputs"] as Dictionary).size(), 1, "%s is made of one material" % recipe_id)
	for slot in ["armor", "boots"]:
		for recipe_id in _of(slot):
			assert_eq(config_node.RECIPES[recipe_id]["inputs"].keys(), ["hide"], "%s is hide (what he wears binds)" % recipe_id)
	for recipe_id in _of("weapon"):
		assert_false(config_node.RECIPES[recipe_id]["inputs"].has("wood"), "%s: no wood for its haft any more" % recipe_id)

func test_06_hide_comes_off_the_map_s_elites() -> void:
	var map: Dictionary = config_node.map_data()
	for species in [String(map["minor_boss"]), String(map["boss"])]:
		assert_gt(int(config_node.DINOS[species]["drops"].get("hide", 0)), 0, "%s leaves hide" % species)
	for slot in ["armor", "boots"]:
		assert_has(config_node.RECIPES[_of(slot)[0]]["inputs"], "hide", "The %s is made of hide" % slot)
	assert_eq(String(config_node.source_hint("hide", {})), tr("SOURCE_BOSSES") % tr("RESOURCE_HIDE"),
		"Short of it, he is told where it comes from")

func test_07_his_bar_shows_the_armour_in_leather() -> void:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	_make(_of("armor")[0])
	var panel = main.hud.option_panel
	panel.select_target(main.hero)
	panel._update_status_display()
	await wait_frames(2)
	var bar: StatBar = panel.find_child("HpStat", true, false).get_node("Bar") as StatBar
	assert_gt(bar.worn_ratio, bar.base_ratio + 0.01, "His armour's part, past his own")
	assert_almost_eq(bar.worn_ratio - bar.base_ratio, float(config_node.RECIPES[_of("armor")[0]]["max_hp"]) / main.hero.max_hp, 0.01,
		"as long as its hit points")
	assert_not_null(UiTheme.get_theme().get_stylebox("fill", "ArmorBar"), "painted in leather")
