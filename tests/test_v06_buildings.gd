# res://tests/test_v06_buildings.gd
# v0.6 T5: bone stakes, a stone wall, and a crossbow tower improved where it stands.
#
# GAME-DESIGN 6: every building answers a question -- a bone stake bites a swarm harder at
# the mouth of a funnel, a stone wall holds a big predator that walks through stakes -- and
# a line of buildings upgrades in place (6.1), paid for like a blueprint, built by the
# Hero, and never a hole in the defence while he works. Everything is read from Config.
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

## A grid and a builder, the way BuildSystem is tested everywhere.
func _rig() -> Array:
	var grid = _spawn(load("res://scripts/core/GridManager.gd").new())
	var builder = _spawn(load("res://scripts/core/BuildSystem.gd").new())
	builder.setup(grid, null)
	return [grid, builder]

## A finished building of `type_id`, paid for with exactly its price.
func _built(rig: Array, type_id: String, cell: Vector2i) -> Node:
	pay_for([type_id])
	var b = rig[1].place_building(type_id, cell, rig[0])
	if b != null and b.has_method("complete_construction"):
		b.complete_construction()
	return b

func _row(type_id: String) -> Dictionary:
	return config_node.BUILDINGS[type_id]

# ==============================================================================
# 1. The build menu
# ==============================================================================

func test_01_the_menu_offers_bone_stakes_and_a_stone_wall_but_not_tower_ii() -> void:
	assert_has(config_node.BUILDABLE_TYPES, "bone_stake", "Bone stakes are on the build menu")
	assert_has(config_node.BUILDABLE_TYPES, "stone_wall", "So is the stone wall")
	var target: String = String(config_node.upgrade_target("tower"))
	assert_ne(target, "", "A tower has somewhere to go")
	assert_false(config_node.BUILDABLE_TYPES.has(target), "But that is reached by upgrading, not from the menu")

# ==============================================================================
# 2. A bone stake is a stake that bites harder
# ==============================================================================

func test_02_a_bone_stake_is_a_stake_that_bites_harder() -> void:
	var wood: Dictionary = _row("wall")
	var bone: Dictionary = _row("bone_stake")
	assert_eq(String(bone["kind"]), String(wood["kind"]), "It is the same kind of thing")
	for key in ["spike_diameter", "height", "cell_divisions"]:
		assert_eq(bone[key], wood[key], "The same %s: laid the same way, the same size" % key)
	assert_gt(config_node.get_contact_dps("bone_stake"), config_node.get_contact_dps("wall"),
		"And it bites harder")
	assert_has(bone["cost"], "bone", "Because it is tipped with bone")

	var b = _built(_rig(), "bone_stake", Vector2i(3, 3))
	assert_not_null(b, "It can be put up")
	if b == null:
		return
	await wait_frames(1)
	assert_almost_eq(float(b.contact_damage), float(bone["contact_damage"]), 0.0001,
		"And standing, it bites by its own row -- it is a stake, with a stake's script")

# ==============================================================================
# 3. A stone wall fills its tile and takes a long time to break
# ==============================================================================

func test_03_a_stone_wall_fills_its_tile_and_outlasts_a_stake_many_times() -> void:
	var row: Dictionary = _row("stone_wall")
	assert_true(config_node.is_barrier_building("stone_wall"), "It fills its tile: a row of them is a wall")
	assert_almost_eq(config_node.get_building_footprint("stone_wall"), float(config_node.TILE_SIZE), 0.001,
		"The whole tile")
	assert_almost_eq(config_node.get_contact_dps("stone_wall"), 0.0, 0.0001, "It bites nothing")
	assert_gte(float(row["hp"]), float(_row("wall")["hp"]) * 3.0, "It outlasts a stake several times over")
	assert_eq(row["cost"].keys(), ["stone"], "It is stone and nothing else")

func test_04_the_hero_climbs_a_stone_wall_and_a_dinosaur_does_not() -> void:
	var w = _built(_rig(), "stone_wall", Vector2i(3, 3))
	assert_not_null(w, "It can be put up")
	if w == null:
		return
	await wait_frames(1)
	var wall_layer: int = int(config_node.LAYER_WALL)
	assert_eq(int(w.collision_layer), wall_layer, "It stands on the wall layer, with the stakes")
	var hero = _spawn(load("res://scripts/entities/Hero.gd").new())
	var dino = _spawn(load(String(config_node.get_dino_script_path("big_theropod"))).new())
	dino.setup("big_theropod")
	dino.set_physics_process(false)
	await wait_frames(1)
	assert_eq(int(hero.collision_mask) & wall_layer, 0, "The Hero is not stopped by it (a v0.6 decision)")
	assert_ne(int(dino.collision_mask) & wall_layer, 0, "A dinosaur's body is stopped by it")

# ==============================================================================
# 4. Upgrading a tower where it stands
# ==============================================================================

func test_05_an_upgrade_costs_the_difference_between_the_two_prices() -> void:
	var target: String = String(config_node.upgrade_target("tower"))
	assert_eq(config_node.get_building_kind(target), "tower", "A tower becomes a better tower")
	assert_almost_eq(config_node.get_building_footprint(target), config_node.get_building_footprint("tower"), 0.001,
		"On exactly the same ground, so nothing on the grid moves")
	var have: Dictionary = _row("tower")["cost"]
	var want: Dictionary = _row(target)["cost"]
	var cost: Dictionary = config_node.upgrade_cost("tower")
	assert_false(cost.is_empty(), "It costs something")
	for res_id in want:
		var more: int = int(want[res_id]) - int(have.get(res_id, 0))
		assert_eq(int(cost.get(res_id, 0)), maxi(0, more), "Its %s is the difference" % res_id)
	assert_gt(float(_row(target)["fire_rate"]), float(_row("tower")["fire_rate"]), "And it looses faster")
	assert_gt(config_node.get_upgrade_time("tower"), 0.0, "Upgrading is work")

func test_06_upgrading_is_paid_up_front_and_the_tower_keeps_shooting() -> void:
	var t = _built(_rig(), "tower", Vector2i(4, 4))
	assert_not_null(t, "A tower")
	if t == null:
		return
	await wait_frames(1)
	var cost: Dictionary = config_node.upgrade_cost("tower")
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = int(cost.get(res_id, 0))
	assert_true(t.can_upgrade(), "A finished tower can be upgraded")
	assert_true(t.begin_upgrade(), "And the upgrade is ordered")
	for res_id in cost:
		assert_eq(int(game_state_node.resources[res_id]), 0, "Its %s is spent when it is ordered" % res_id)
	assert_true(t.is_upgrading(), "The work is waiting")
	assert_true(t.is_constructed, "And the tower is still a tower, not a blueprint")
	assert_almost_eq(float(t.fire_rate), float(_row("tower")["fire_rate"]), 0.0001, "Shooting as it did")
	assert_false(t.can_upgrade(), "It cannot be ordered twice")
	assert_false(t.begin_upgrade(), "Or paid for twice")

func test_07_the_hero_builds_it_and_it_becomes_the_next_tower() -> void:
	var t = _built(_rig(), "tower", Vector2i(4, 4))
	assert_not_null(t, "A tower")
	if t == null:
		return
	await wait_frames(1)
	var target: String = String(config_node.upgrade_target("tower"))
	t.current_hp = t.max_hp * 0.5
	stock_everything()
	assert_true(t.begin_upgrade(), "Ordered")
	var watcher = watch_signal(event_bus_node, "building_upgraded")

	var hero = _spawn(load("res://scripts/entities/Hero.gd").new())
	hero.global_position = t.global_position + Vector3(0.9, 0.0, 0.0)
	await wait_frames(1)
	hero.order_upgrade(t)
	var needed: float = config_node.get_upgrade_time("tower")
	hero._process_building(needed * 0.5)
	assert_true(t.is_upgrading(), "Half the work is not the thing")
	hero._process_building(needed * 0.5 + 0.01)

	assert_false(t.is_upgrading(), "Done")
	assert_eq(String(t.building_type), target, "It is the next tower now")
	assert_almost_eq(float(t.fire_rate), float(_row(target)["fire_rate"]), 0.0001, "With its rate of fire")
	assert_almost_eq(float(t.max_hp), float(_row(target)["hp"]), 0.0001, "Its hit points")
	assert_almost_eq(float(t.current_hp), float(_row(target)["hp"]) * 0.5, 0.01,
		"And as much of them as the old tower had left")
	assert_true(watcher.emitted, "The bus says so")
	assert_false(t.can_upgrade(), "It is the end of its line in v0.6")

func test_08_an_upgrade_under_way_is_work_that_waits_for_him() -> void:
	var t = _built(_rig(), "tower", Vector2i(4, 4))
	assert_not_null(t, "A tower")
	if t == null:
		return
	await wait_frames(1)
	var hero = _spawn(load("res://scripts/entities/Hero.gd").new())
	await wait_frames(1)
	assert_false(hero._is_unfinished_work(t), "A finished tower is not work")
	stock_everything()
	t.begin_upgrade()
	assert_true(hero._is_unfinished_work(t), "An upgrade paid for and not built is")

func test_09_the_panel_offers_the_upgrade_with_what_it_changes() -> void:
	var t = _built(_rig(), "tower", Vector2i(4, 4))
	assert_not_null(t, "A tower")
	if t == null:
		return
	var panel = _spawn(load("res://scripts/ui/OptionPanel.gd").new())
	await wait_frames(1)
	stock_everything()
	panel.select_target(t)
	await wait_frames(1)
	var target: String = String(config_node.upgrade_target("tower"))
	var target_name: String = String(config_node.get_building_name(target))
	var button_text: String = tr("CMD_UPGRADE") % panel._amounts_text(config_node.upgrade_cost("tower"))
	var offered: bool = false
	for child in panel.button_container.get_children():
		if child is Button and String(child.text) == button_text:
			offered = true
	assert_true(offered, "The tower's panel offers the upgrade, price on the button (%s)" % button_text)
	var detail: String = panel.upgrade_detail_text(t)
	assert_true(detail.contains(target_name), "Hovering it names what the tower becomes")
	var rate: String = tr("STAT_FIRE_RATE") % [config_node.factor_text(float(_row("tower")["fire_rate"])),
		config_node.factor_text(float(_row(target)["fire_rate"]))]
	assert_true(detail.contains(rate), "And says what it changes: %s" % detail)
