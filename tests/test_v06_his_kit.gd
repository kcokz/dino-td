# res://tests/test_v06_his_kit.gd
# v0.6 round three: "人还是倒下下会死，但是我们可以增加皮和护甲的一些制作，还有食物的制作，使得人不容易死。人
# 身上现在的能力也可以作为装备栏，增强血量……简单化也是可以的"; "能力和装备栏两个都在又有点过于复杂……不能让玩家
# 觉得复杂". And v0.7 (GAME-DESIGN 3.0), the player: "人的装备更加没意义……如果只是鸡肋，那也需要trim".
#
# One row of what he has made for good, a slot a kind (Config.KIT_SLOTS): since v0.7 the pick and the axe
# alone -- the tools that open the valley: the bone pick, without which there is no stone, and the stone
# axe, which halves the felling of the finite trees. The weapon, the armour, the boots and the second pick
# went; nothing he makes changes his own body. Each tool is made of what it is named for. Hide, which only
# the map's elites leave, is what the map is drawn on.
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

## The recipes of `slot`.
func _of(slot: String) -> Array[String]:
	var out: Array[String] = []
	for recipe_id in config_node.RECIPES:
		if String(config_node.RECIPES[recipe_id].get("slot", "")) == slot:
			out.append(String(recipe_id))
	return out

func test_01_every_slot_has_one_thing_to_make() -> void:
	assert_eq(config_node.KIT_SLOTS, ["pick", "axe"] as Array[String], "His row: the pick and the axe")
	for slot in config_node.KIT_SLOTS:
		assert_eq(_of(String(slot)).size(), 1, "One thing goes in the %s slot: no better one to make after it" % slot)
	for recipe_id in config_node.RECIPES:
		var slot: String = String(config_node.RECIPES[recipe_id].get("slot", ""))
		assert_true(slot == "" or config_node.KIT_SLOTS.has(slot), "%s goes in a slot of his row, or none" % recipe_id)

func test_02_nothing_he_makes_changes_his_body() -> void:
	# No armour, no boots, no spear: what holds the line is what he builds (GAME-DESIGN 3.0).
	var hero = _hero()
	await wait_frames(1)
	for recipe_id in config_node.RECIPES:
		game_state_node.grant_unlock(String(config_node.RECIPES[recipe_id].get("unlocks", "")))
	await wait_frames(1)
	assert_almost_eq(hero.max_hp, float(config_node.HERO["hp"]), 0.001, "Everything made, his health is his own")
	assert_almost_eq(hero.walk_speed(), float(config_node.HERO["move_speed"]), 0.001, "and his stride")
	assert_almost_eq(hero.damage, float(config_node.HERO["damage"]), 0.001, "and his blows")
	for recipe_id in config_node.RECIPES:
		var row: Dictionary = config_node.RECIPES[recipe_id]
		for effect in ["max_hp", "move_speed", "damage"]:
			assert_false(row.has(effect), "%s does nothing to his body (%s)" % [recipe_id, effect])

func test_03_the_axe_fells_as_much_faster_as_it_says() -> void:
	var axe: String = _of("axe")[0]
	var bare: float = float(config_node.harvest_speed("wood", game_state_node.unlocks))
	_make(axe)
	var with_it: float = float(config_node.harvest_speed("wood", game_state_node.unlocks))
	assert_almost_eq(with_it, bare * float(config_node.RECIPES[axe]["harvest_speed"]["wood"]), 0.001,
		"Wood comes down as much faster as the axe says")
	assert_true(String(config_node.harvest_note("wood", game_state_node.unlocks)).contains(tr(String(config_node.RECIPES[axe]["name"]))),
		"and the pile says it was the axe")

func test_04_the_pick_opens_the_stone() -> void:
	var pick: String = _of("pick")[0]
	var flag: String = String(config_node.harvest_requires_unlock("stone"))
	assert_eq(String(config_node.RECIPES[pick]["unlocks"]), flag, "The pick is what stone asks for")
	assert_false(game_state_node.has_unlock(flag), "Bare-handed, stone will not give")
	_make(pick)
	assert_true(game_state_node.has_unlock(flag), "Made, it does")

func test_05_a_tool_is_made_of_what_it_is_named_for_and_only_that() -> void:
	# The player, v0.6 round six: "材料各种各样，每次造东西都需要各种各样的材料……总感觉有点confuse哪个材料是用来
	# 做什么，也很难做规划" -- chosen: a tool is made of one material, the one in its name (GAME-DESIGN 6.0 rule 1).
	for recipe_id in config_node.RECIPES:
		var row: Dictionary = config_node.RECIPES[recipe_id]
		if String(row.get("slot", "")) == "" and String(row.get("unlocks", "")) == "":
			continue      # ammunition: a batch of what the towers shoot
		assert_eq((row["inputs"] as Dictionary).size(), 1, "%s is made of one material" % recipe_id)
	assert_eq(config_node.RECIPES["hide_map"]["inputs"].keys(), ["hide"], "The map is drawn on hide")

func test_06_hide_comes_off_the_map_s_elites_and_is_for_the_map() -> void:
	var map: Dictionary = config_node.map_data()
	for species in [String(map["minor_boss"]), String(map["boss"])]:
		assert_gt(int(config_node.DINOS[species]["drops"].get("hide", 0)), 0, "%s leaves hide" % species)
	assert_eq(String(config_node.source_hint("hide", {})), tr("SOURCE_BOSSES") % tr("RESOURCE_HIDE"),
		"Short of it, he is told where it comes from")
	# For the map -- and, from station 3, the bloomery's bellows (v0.7; GAME-DESIGN 4.2: "第 3 站的风箱"): never a defence
	# (2026-10-02, the player: "皮不要用来防御").
	var ids: Array = []
	for use in config_node.uses_of("hide"):
		ids.append(String(use["id"]))
		if String(use["kind"]) == "building":
			assert_eq(String(config_node.get_building_kind(String(use["id"]))), "workshop",
				"Hide goes into no defence: %s is a workshop" % use["id"])
	assert_has(ids, "hide_map", "Hide is for the map")
	assert_has(ids, "furnace", "and the bloomery's bellows")
	assert_eq(ids.size(), 2, "and nothing else")

func test_07_what_went_is_gone() -> void:
	# Ids never change and are never reused (GAME-DESIGN 12.6): these are not in the game any more.
	for recipe_id in ["quarry_pick", "stone_spear", "bone_spear", "hide_vest", "bone_armor", "hide_boots", "stone_pot"]:
		assert_false(config_node.RECIPES.has(recipe_id), "%s went in v0.7" % recipe_id)
