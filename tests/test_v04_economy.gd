# res://tests/test_v04_economy.gd
# v0.4: the Hero is the only economy, and buildings are only defence.
#
# Tending made the building the worker and the Hero a maintenance man, which is
# backwards for a game whose premise is that one body holds up a whole base. The
# producers are gone; these are the invariants that keep them gone, stated so that
# adding one back is a decision somebody has to make rather than something that
# quietly happens.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null

var hero_script: GDScript = null
var build_system_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")
	hero_script = _load_script("res://scripts/entities/Hero.gd")
	build_system_script = _load_script("res://scripts/core/BuildSystem.gd")

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

func _load_script(path: String) -> GDScript:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is GDScript:
			return res
	return null

# ==============================================================================
# 1. No building makes resources
# ==============================================================================

func test_01_nothing_buildable_produces_anything() -> void:
	for b_type in config_node.BUILDINGS:
		var data: Dictionary = config_node.BUILDINGS[b_type]
		for key in ["produces", "produces_per_sec", "tend_duration", "tend_time", "harvest_range"]:
			assert_false(data.has(key),
				"%s must not declare '%s' -- v0.4 has no production buildings" % [b_type, key])

func test_02_the_build_menu_is_defence_only() -> void:
	assert_gt(config_node.BUILDABLE_TYPES.size(), 0, "There is something to build")
	for b_type in config_node.BUILDABLE_TYPES:
		var kind: String = String(config_node.BUILDINGS[b_type].get("kind", ""))
		assert_ne(kind, "producer", "%s is not a production building" % b_type)
		assert_has(build_system_script.SCRIPT_PATHS, b_type,
			"Buildable type '%s' must have an entity script registered" % b_type)

func test_03_no_producer_scripts_are_left_in_the_project() -> void:
	# A file left behind is a file somebody re-registers by accident.
	for path in ["res://scripts/entities/ProducerBuilding.gd", "res://scripts/entities/LumberHut.gd"]:
		assert_false(ResourceLoader.exists(path), "%s is gone" % path)
	for path in build_system_script.SCRIPT_PATHS.values():
		assert_true(ResourceLoader.exists(String(path)),
			"BuildSystem points at a script that exists: %s" % path)

# ==============================================================================
# 2. The Hero has no machine to look after
# ==============================================================================

func test_04_the_hero_takes_no_tending_orders() -> void:
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	await wait_frames(1)

	assert_false(hero.has_method("order_tend"), "There is nothing to tend")
	assert_false("target_tend_building" in hero, "And nothing to remember tending")
	assert_false(hero_script.State.has("TENDING"), "The state itself is gone")

func test_05_the_hero_still_harvests_by_hand() -> void:
	# The thing tending replaced. Hand-harvesting is now the whole economy, so it
	# had better still be there.
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	var node = load("res://scripts/entities/ResourceNode.gd").new("wood", Vector2i(1, 0))
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	node.position = Vector3(1.0, 0.0, 0.0)
	node.setup("wood", Vector2i(1, 0), 20)
	await wait_frames(1)

	hero.order_harvest(node)
	assert_eq(int(hero.current_state), int(hero_script.State.HARVESTING), "He sets to work")

	var secs: float = 1.0 / maxf(float(node.harvest_rate), 0.01)
	var before: int = earned_total("wood")
	hero._physics_process(secs + 0.05)
	assert_gt(earned_total("wood"), before, "And wood comes out of the tree")
	assert_lt(node.current_amount, node.max_capacity, "Out of that tree in particular")

func test_06_the_bus_no_longer_announces_tending() -> void:
	assert_false(event_bus_node.has_signal("building_tended"), "Nothing tends anything")
	# The signals the economy actually runs on are still there.
	for sig in ["resource_dropped", "resource_picked_up", "resources_changed"]:
		assert_true(event_bus_node.has_signal(sig), "%s survives" % sig)

# ==============================================================================
# 3. Every resource still has exactly one way in
# ==============================================================================

func test_07_the_only_way_into_the_warehouse_is_the_hero() -> void:
	# Hand-harvesting, dinosaur meat, demolition rubble and the opening stock all
	# land on the ground; nothing banks a number behind the player's back.
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	hero.position = Vector3(40.0, 0.0, 40.0)
	await wait_frames(1)

	var before: int = int(game_state_node.resources.get("wood", 0))
	DropItem.spawn(hero, Vector3(10.0, 0.0, 10.0), "wood", 5)
	assert_eq(int(game_state_node.resources.get("wood", 0)), before,
		"A pile on the far side of the map is not in the warehouse")

	hero.global_position = Vector3(10.0, 0.0, 10.0)
	assert_eq(hero.sweep_for_drops(), 5, "Walking over it is what collects it")
	assert_eq(int(game_state_node.resources.get("wood", 0)), before + 5, "And that is the only way in")

# ==============================================================================
# 4. A carcass is worth meat and bone
# ==============================================================================

func _ground(res_id: String) -> int:
	return ground_total(res_id)

func test_08_a_dead_dinosaur_leaves_bone_as_well_as_meat() -> void:
	var dino = load("res://scripts/entities/Dino.gd").new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.position = Vector3(40.0, 0.0, 40.0)
	dino.setup("raptor")
	await wait_frames(1)

	var want_bone: int = int(config_node.DINOS["raptor"].get("drops", {}).get("bone", 0))
	var want_food: int = int(config_node.DINOS["raptor"].get("drops", {}).get("food", 0))
	assert_gt(want_bone, 0, "A raptor is worth bone")

	dino.take_damage(dino.max_hp)
	assert_eq(_ground("bone"), want_bone, "It leaves exactly the configured bone")
	assert_eq(_ground("food"), want_food, "And the meat alongside it")

func test_09_bone_comes_off_dinosaurs_or_nowhere() -> void:
	# The gate onto stone only works if bone cannot be farmed any other way.
	assert_has(config_node.RESOURCES, "bone", "Bone is a real resource")
	assert_eq(int(config_node.INITIAL_RESOURCES.get("bone", 0)), 0, "Nobody starts with bone")
	assert_eq(int(config_node.get_opening_stock("bone")), 0, "And none is scattered at the cabin")
	for b_type in config_node.BUILDINGS:
		assert_false(config_node.BUILDINGS[b_type].has("produces"),
			"%s produces nothing at all, bone included" % b_type)
	var any: bool = false
	for type_id in config_node.DINOS:
		if int(config_node.DINOS[type_id].get("drops", {}).get("bone", 0)) > 0:
			any = true
	assert_true(any, "Every kind of dinosaur is worth bone")

func test_10_bone_has_a_readout_like_every_other_resource() -> void:
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	_cleanup_nodes.append(hud)
	tree.root.add_child(hud)
	await wait_frames(1)

	hud._on_resources_changed({"wood": 1, "stone": 2, "bone": 7, "water": 3, "food": 4})
	assert_eq(hud.bone_label.text, tr("HUD_BONE") % 7, "Bone has its own line in the top bar")
	assert_true(hud.bone_label.visible, "And it is on screen")
	for res_id in config_node.RESOURCES:
		if res_id == "water":
			continue   # no sink yet; see the open question in VERSION.md
		assert_not_null(hud.find_child("%sLabel" % res_id.capitalize(), true, false),
			"%s has a readout" % res_id)

# ==============================================================================
# 5. The two gates: a pick for stone, a blueprint for the turret
# ==============================================================================

func test_11_bare_hands_do_not_cut_rock() -> void:
	var hero = hero_script.new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	var rock = load("res://scripts/entities/ResourceNode.gd").new("stone", Vector2i(1, 0))
	_cleanup_nodes.append(rock)
	tree.root.add_child(rock)
	rock.position = Vector3(1.0, 0.0, 0.0)
	rock.setup("stone", Vector2i(1, 0), 20)
	await wait_frames(1)

	assert_false(hero.can_harvest(rock), "Without a pick there is nothing he can do with rock")
	hero.order_harvest(rock)
	assert_ne(int(hero.current_state), int(hero_script.State.HARVESTING), "So the order does nothing")

	game_state_node.grant_unlock(String(config_node.harvest_requires_unlock("stone")))
	assert_true(hero.can_harvest(rock), "With the pick made, rock is his")
	hero.order_harvest(rock)
	assert_eq(int(hero.current_state), int(hero_script.State.HARVESTING), "And he sets to work")

func test_12_wood_is_never_gated() -> void:
	# The opening has to be playable with nothing made yet, or there is no way to
	# start the chain at all.
	assert_eq(config_node.harvest_requires_unlock("wood"), "", "Trees need no tool")
	assert_ne(config_node.harvest_requires_unlock("stone"), "", "Rock does")

func test_13_a_turret_cannot_be_reached_on_materials_alone() -> void:
	var grid = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(grid)
	tree.root.add_child(grid)
	var builder = build_system_script.new()
	_cleanup_nodes.append(builder)
	tree.root.add_child(builder)
	builder.setup(grid, null)
	await wait_frames(1)
	pay_for(["tower"], 99)

	assert_false(builder.can_place_building("tower", Vector2i(2, 2)),
		"All the materials in the world do not make a turret you have not worked out")
	game_state_node.grant_unlock(String(config_node.building_requires_unlock("tower")))
	assert_true(builder.can_place_building("tower", Vector2i(2, 2)),
		"The blueprint is what opens it")

func test_14_stakes_are_never_gated() -> void:
	assert_eq(config_node.building_requires_unlock("wall"), "",
		"Stakes are what the player has on the first morning")
	assert_ne(config_node.building_requires_unlock("tower"), "",
		"A turret is not")

func test_15_the_chain_closes() -> void:
	# The whole point of v0.4, stated once: every link is reachable from the one
	# before it, and the first raid is in the middle of it.
	var pick: String = String(config_node.harvest_requires_unlock("stone"))
	var blueprint: String = String(config_node.building_requires_unlock("tower"))

	var pick_recipe: Dictionary = {}
	var blueprint_recipe: Dictionary = {}
	for recipe_id in config_node.RECIPES:
		var data: Dictionary = config_node.RECIPES[recipe_id]
		if String(data.get("unlocks", "")) == pick:
			pick_recipe = data
		if String(data.get("unlocks", "")) == blueprint:
			blueprint_recipe = data

	assert_false(pick_recipe.is_empty(), "The pick is something the cabin can make")
	assert_false(blueprint_recipe.is_empty(), "So is the turret's blueprint")
	assert_has(pick_recipe["inputs"], "bone", "And the pick is made of bone, which only a dinosaur has")
	assert_has(config_node.BUILDINGS["tower"]["cost"], "stone",
		"While the turret is built of the stone the pick cuts")
