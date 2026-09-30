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
	# v0.6 round six (GAME-DESIGN 6.0): the menu is one slot a job; bone stakes and the stone wall are
	# what a fence becomes where it stands.
	assert_has(config_node.upgrade_targets("wall"), "bone_stake", "A fence becomes bone stakes")
	assert_has(config_node.upgrade_targets("wall"), "stone_wall", "or a stone wall")
	assert_false(config_node.BUILDABLE_TYPES.has("bone_stake") or config_node.BUILDABLE_TYPES.has("stone_wall"),
		"neither an entry of the menu")
	var target: String = String(config_node.upgrade_target("set_crossbow"))
	assert_ne(target, "", "A tower has somewhere to go")
	assert_false(config_node.BUILDABLE_TYPES.has(target), "But that is reached by upgrading, not from the menu")

# ==============================================================================
# 2. A bone stake is a stake that bites harder
# ==============================================================================

func test_02_a_bone_stake_is_a_stake_that_bites_harder() -> void:
	var wood: Dictionary = _row("wall")
	var bone: Dictionary = _row("bone_stake")
	assert_eq(String(bone["kind"]), String(wood["kind"]), "It is the same kind of thing")
	for key in ["cells", "height"]:
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
# 3. A stone wall fills its cell and takes a long time to break
# ==============================================================================

func test_03_a_stone_wall_fills_its_cell_and_outlasts_a_palisade() -> void:
	# A metre of each since v0.6 round two, so they compare metre for metre.
	var row: Dictionary = _row("stone_wall")
	assert_eq(String(config_node.get_building_kind("stone_wall")), "wall", "It is a wall: a row of them is a wall")
	assert_almost_eq(config_node.get_building_footprint("stone_wall"), float(config_node.BUILD_CELL), 0.001,
		"The whole cell")
	assert_almost_eq(config_node.get_contact_dps("stone_wall"), 0.0, 0.0001, "It bites nothing")
	assert_gte(float(row["hp"]), float(_row("wall")["hp"]) * 2.0, "It outlasts a palisade more than twice over")
	assert_eq(row["cost"].keys(), ["stone"], "It is stone and nothing else")

func test_04_a_stone_wall_stops_the_hero_and_a_dinosaur_alike() -> void:
	# "石墙恐龙能穿过，不合理……而且人不能再穿过墙了" (v0.6 round two): it stood in nobody's way but a
	# dinosaur's, and the player saw the animals walk through it. Every body stops at it now.
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
	assert_ne(int(hero.collision_mask) & wall_layer, 0, "The Hero is stopped by it")
	assert_ne(int(dino.collision_mask) & wall_layer, 0, "And so is a dinosaur's body")

# ==============================================================================
# 4. Improving a set crossbow where it stands
# ==============================================================================

func test_05_an_upgrade_costs_the_difference_between_the_two_prices() -> void:
	var target: String = String(config_node.upgrade_target("set_crossbow"))
	assert_eq(config_node.get_building_kind(target), "trap", "A trap becomes a better trap")
	assert_almost_eq(config_node.get_building_footprint(target), config_node.get_building_footprint("set_crossbow"), 0.001,
		"On exactly the same ground, so nothing on the grid moves")
	var have: Dictionary = _row("set_crossbow")["cost"]
	var want: Dictionary = _row(target)["cost"]
	var cost: Dictionary = config_node.upgrade_cost("set_crossbow")
	assert_false(cost.is_empty(), "It costs something")
	for res_id in want:
		var more: int = int(want[res_id]) - int(have.get(res_id, 0))
		assert_eq(int(cost.get(res_id, 0)), maxi(0, more), "Its %s is the difference" % res_id)
	assert_lt(float(_row(target)["rearm_seconds"]), float(_row("set_crossbow")["rearm_seconds"]), "And it re-arms faster")
	assert_gt(config_node.get_upgrade_time("set_crossbow"), 0.0, "Upgrading is work")

func test_06_upgrading_is_paid_up_front_and_the_trap_keeps_working() -> void:
	var t = _built(_rig(), "set_crossbow", Vector2i(4, 4))
	assert_not_null(t, "A tower")
	if t == null:
		return
	await wait_frames(1)
	var cost: Dictionary = config_node.upgrade_cost("set_crossbow")
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = int(cost.get(res_id, 0))
	assert_true(t.can_upgrade(), "A finished tower can be upgraded")
	assert_true(t.begin_upgrade(), "And the upgrade is ordered")
	for res_id in cost:
		assert_eq(int(game_state_node.resources[res_id]), 0, "Its %s is spent when it is ordered" % res_id)
	assert_true(t.is_upgrading(), "The work is waiting")
	assert_true(t.is_constructed, "And the trap is still a trap, not a blueprint")
	assert_almost_eq(float(t.rearm_seconds), float(_row("set_crossbow")["rearm_seconds"]), 0.0001, "Working as it did")
	assert_false(t.can_upgrade(), "It cannot be ordered twice")
	assert_false(t.begin_upgrade(), "Or paid for twice")

func test_07_the_hero_builds_it_and_it_becomes_the_next_trap() -> void:
	var t = _built(_rig(), "set_crossbow", Vector2i(4, 4))
	assert_not_null(t, "A tower")
	if t == null:
		return
	await wait_frames(1)
	var target: String = String(config_node.upgrade_target("set_crossbow"))
	t.current_hp = t.max_hp * 0.5
	stock_everything()
	assert_true(t.begin_upgrade(), "Ordered")
	var watcher = watch_signal(event_bus_node, "building_upgraded")

	var hero = _spawn(load("res://scripts/entities/Hero.gd").new())
	hero.global_position = t.global_position + Vector3(0.9, 0.0, 0.0)
	await wait_frames(1)
	hero.order_upgrade(t)
	var needed: float = config_node.get_upgrade_time("set_crossbow")
	hero._process_building(needed * 0.5)
	assert_true(t.is_upgrading(), "Half the work is not the thing")
	hero._process_building(needed * 0.5 + 0.01)

	assert_false(t.is_upgrading(), "Done")
	assert_eq(String(t.building_type), target, "It is the next trap now")
	assert_almost_eq(float(t.rearm_seconds), float(_row(target)["rearm_seconds"]), 0.0001, "Re-arming as fast as it")
	assert_almost_eq(float(t.max_hp), float(_row(target)["hp"]), 0.0001, "Its hit points")
	assert_almost_eq(float(t.current_hp), float(_row(target)["hp"]) * 0.5, 0.01,
		"And as much of them as the old trap had left")
	assert_true(watcher.emitted, "The bus says so")
	assert_false(t.can_upgrade(), "It is the end of its line in v0.6")

func test_08_an_upgrade_under_way_is_work_that_waits_for_him() -> void:
	var t = _built(_rig(), "set_crossbow", Vector2i(4, 4))
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
	var t = _built(_rig(), "set_crossbow", Vector2i(4, 4))
	assert_not_null(t, "A tower")
	if t == null:
		return
	var panel = _spawn(load("res://scripts/ui/OptionPanel.gd").new())
	await wait_frames(1)
	stock_everything()
	panel.select_target(t)
	await wait_frames(1)
	var target: String = String(config_node.upgrade_target("set_crossbow"))
	var target_name: String = String(config_node.get_building_name(target))
	var button_text: String = tr("CMD_UPGRADE_TO") % [target_name, panel._amounts_text(config_node.upgrade_cost("set_crossbow"))]
	var offered: bool = false
	for child in panel.button_container.get_children():
		if child is Button and String(child.text) == button_text:
			offered = true
	assert_true(offered, "The tower's panel offers the upgrade, price on the button (%s)" % button_text)
	var detail: String = panel.upgrade_detail_text(t)
	assert_true(detail.contains(target_name), "Hovering it names what the tower becomes")
	var rate: String = tr("STAT_REARM_SECONDS") % [config_node.factor_text(float(_row("set_crossbow")["rearm_seconds"])),
		config_node.factor_text(float(_row(target)["rearm_seconds"]))]
	assert_true(detail.contains(rate), "And says what it changes: %s" % detail)
