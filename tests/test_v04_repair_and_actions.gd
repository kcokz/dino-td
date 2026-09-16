# res://tests/test_v04_repair_and_actions.gd
# v0.4 follow-ups:
#   * a damaged building can be mended instead of only replaced;
#   * right-click does the one obvious thing, and asks when there is more than one.
#
# The second is the interesting rule. Right-click has always acted immediately and
# that is worth keeping for the common case -- but a damaged building has several
# sensible answers, and silently picking one of them is guessing.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var wall_script: GDScript = null
var tower_script: GDScript = null
var hero_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
	wall_script = load("res://scripts/entities/Wall.gd")
	tower_script = load("res://scripts/entities/Tower.gd")
	hero_script = load("res://scripts/entities/Hero.gd")

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

func _spawn(script: GDScript, pos: Vector3 = Vector3.ZERO) -> Node:
	var n = script.new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = pos
	return n

func _turret(pos: Vector3 = Vector3.ZERO) -> Node:
	var t = _spawn(tower_script, pos)
	t.complete_construction()
	return t

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

# ==============================================================================
# 1. Mending
# ==============================================================================

func test_01_only_a_damaged_finished_building_wants_repair() -> void:
	var turret = _turret()
	await wait_frames(1)
	assert_false(turret.needs_repair(), "At full health there is nothing to mend")
	assert_eq(turret.repair_cost(), 0, "And nothing to pay")

	turret.take_damage(turret.max_hp * 0.5)
	assert_true(turret.needs_repair(), "Damaged, it does")
	assert_gt(turret.repair_cost(), 0, "And it quotes a price")

	var blueprint = _spawn(tower_script, Vector3(20.0, 0.0, 0.0))
	blueprint.start_construction()
	await wait_frames(1)
	assert_false(blueprint.needs_repair(), "A blueprint is raised, not mended")

func test_02_the_bill_is_the_price_scaled_by_the_damage() -> void:
	# Never more than building it again, and a scratch costs the minimum rather
	# than a flat fee.
	var turret = _turret()
	await wait_frames(1)
	var price: Dictionary = config_node.BUILDINGS["tower"]["cost"]

	turret.take_damage(turret.max_hp * 0.5)
	for res_id in price:
		var want: int = int(ceil(int(price[res_id]) * turret.damage_fraction()))
		assert_eq(int(turret.repair_cost().get(res_id, 0)), want,
			"Half gone costs half the %s, rounded up" % res_id)

func test_03_mending_never_costs_more_than_building_it_again() -> void:
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 0.001)   # all but destroyed
	var price: Dictionary = config_node.BUILDINGS["tower"]["cost"]
	for res_id in price:
		assert_lte(int(turret.repair_cost().get(res_id, 0)), int(price[res_id]),
			"Even gutted, the %s bill is capped at what it cost to build" % res_id)
	assert_lte(turret.repair_price_total(), total_price_of("tower"),
		"So repair is never the worse deal")

func test_04_a_scratch_costs_the_minimum_not_a_flat_fee() -> void:
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(0.5)
	assert_eq(turret.repair_price_total(), turret.repair_cost().size(),
		"One unit of each resource it is short of, and no more")
	assert_lt(turret.repair_price_total(), total_price_of("tower"),
		"Which is far less than rebuilding it")

func test_05_the_bill_is_charged_once_at_the_end() -> void:
	# One transaction: walking away costs the time spent and nothing else, so there
	# is never a half-paid building to explain.
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(turret.max_hp * 0.5)
	pay_for(["tower"], 99)
	var owed: Dictionary = turret.repair_cost()
	var before: Dictionary = {}
	for res_id in owed:
		before[res_id] = int(game_state_node.resources.get(res_id, 0))

	assert_true(turret.finish_repair(), "The job completes")
	for res_id in owed:
		assert_eq(int(game_state_node.resources.get(res_id, 0)), before[res_id] - int(owed[res_id]),
			"Exactly the quoted %s left the warehouse" % res_id)
	assert_almost_eq(turret.current_hp, turret.max_hp, 0.001, "And it is whole again")

func test_05b_an_unpayable_bill_mends_nothing() -> void:
	var turret = _turret()
	await wait_frames(1)
	turret.take_damage(turret.max_hp * 0.5)
	for res_id in config_node.RESOURCES:
		game_state_node.resources[res_id] = 0

	var hp_before: float = turret.current_hp
	assert_false(turret.finish_repair(), "With nothing to spend there is no repair")
	assert_almost_eq(turret.current_hp, hp_before, 0.001, "And nothing was mended for free")

func test_06_the_hero_mends_with_the_same_order_that_builds() -> void:
	# One verb: he walks over and works on it. What the hammer is for is the
	# building's business.
	var hero = _spawn(hero_script, Vector3.ZERO)
	hero.continuous_mode = true
	var turret = _turret(Vector3(1.0, 0.0, 0.0))
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 1.0)
	pay_for(["tower"], 99)   # a turret is mended with wood and stone

	hero.order_repair(turret)
	assert_eq(int(hero.current_state), int(hero_script.State.BUILDING), "He sets to work")

	var hp_before: float = turret.current_hp
	var needed: float = turret.repair_seconds()
	hero._physics_process(needed * 0.5)
	assert_almost_eq(turret.current_hp, hp_before, 0.001, "Half the work mends nothing yet")
	hero._physics_process(needed * 0.5 + 0.01)
	assert_almost_eq(turret.current_hp, turret.max_hp, 0.001, "Finishing it puts the building back up")

# ==============================================================================
# 2. Right-click acts; the panel is where costly things are chosen
# ==============================================================================
#
# Right-click was briefly a menu when a building had several sensible answers, and
# that was worse: right-click is easy to hit by accident, and a box appearing under
# the cursor on every misclick is a bad trade for the rare case where the second
# option was wanted. So right-click stays immediate and free of consequences, and
# anything that spends or destroys is chosen on the panel, on purpose.

func test_07_right_click_never_puts_anything_up_to_click_through() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var turret = main.place_building_at_cell("tower", Vector2i(4, 4))
	turret.complete_construction()
	turret.take_damage(turret.max_hp * 0.5)
	await wait_frames(1)

	# A damaged building is exactly the case that used to raise a menu.
	main.right_click_building(turret, turret.global_position)
	assert_eq(int(main.hero.current_state), int(main.hero.State.MOVING),
		"It simply walks him over there")
	assert_false("action_menu" in main, "There is no menu to pop any more")

func test_08_right_clicking_a_blueprint_finishes_it() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var blueprint = main.place_building_at_cell("wall", Vector2i(3, 3))
	assert_not_null(blueprint, "A blueprint is down")
	blueprint.start_construction()
	await wait_frames(1)

	main.right_click_building(blueprint, blueprint.global_position)
	assert_eq(main.hero.target_building, blueprint, "He goes to finish it")

func test_09_right_clicking_the_cabin_still_walks_him_home() -> void:
	var main = _level()
	await wait_frames(2)
	main.hero.global_position = main.current_core.global_position + Vector3(1.0, 0.0, 0.0)

	main.right_click_building(main.current_core, main.current_core.global_position)
	assert_true(main.in_cabin, "Arriving at the cabin puts him inside")

func test_10_mending_is_offered_on_the_panel_when_there_is_damage() -> void:
	var panel = load("res://scripts/ui/OptionPanel.gd").new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	var turret = _turret(Vector3(6.0, 0.0, 0.0))
	await wait_frames(1)
	game_state_node.resources["wood"] = 99

	panel.select_target(turret)
	var labels_healthy: Array = _button_labels(panel)
	assert_false(_any_contains(labels_healthy, tr("CMD_REPAIR").split(" ")[0]),
		"Nothing to mend at full health, so nothing is offered")

	turret.take_damage(turret.max_hp * 0.5)
	panel.select_target(turret)
	var labels: Array = _button_labels(panel)
	# The bill is listed in what it actually costs -- a turret is mended with wood
	# and stone -- so every line of it has to be on the button.
	for res_id in turret.repair_cost():
		assert_true(_any_contains(labels, str(int(turret.repair_cost()[res_id]))),
			"The %s it costs is on the button (got %s)" % [res_id, str(labels)])
		assert_true(_any_contains(labels, tr("RESOURCE_%s" % String(res_id).to_upper())),
			"Named as %s rather than as a bare number" % res_id)
	assert_true(_any_contains(labels, tr("CMD_DEMOLISH")), "Alongside demolish")

func test_11_an_unaffordable_repair_is_offered_but_disabled() -> void:
	# Greyed out rather than missing: the player should be able to see what it
	# would cost them, and why they cannot do it yet.
	var panel = load("res://scripts/ui/OptionPanel.gd").new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	var turret = _turret(Vector3(6.0, 0.0, 0.0))
	await wait_frames(1)
	turret.take_damage(turret.max_hp * 0.5)
	game_state_node.resources["wood"] = 0

	panel.select_target(turret)
	var repair_btn: Button = _find_repair_button(panel)
	assert_not_null(repair_btn, "The option is shown")
	assert_true(repair_btn.disabled, "But cannot be taken with an empty warehouse")

func test_12_choosing_it_sends_the_hero_to_work() -> void:
	var main = _level()
	await wait_frames(2)
	game_state_node.resources["wood"] = 99
	var turret = main.place_building_at_cell("tower", Vector2i(5, 5))
	turret.complete_construction()
	turret.take_damage(turret.max_hp * 0.5)
	var panel = load("res://scripts/ui/OptionPanel.gd").new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	await wait_frames(1)

	panel.select_target(turret)
	var btn: Button = _find_repair_button(panel)
	assert_not_null(btn, "The option is there to pick")
	btn.pressed.emit()
	assert_eq(main.hero.target_building, turret, "Picking it is what starts the job")

## The repair entry, found by its own wording rather than by whatever number
## happens to be in it.
func _find_repair_button(panel: Node) -> Button:
	var prefix: String = tr("CMD_REPAIR").split("%")[0].strip_edges()
	for child in panel.button_container.get_children():
		if child is Button and str(child.text).begins_with(prefix):
			return child
	return null

func _button_labels(panel: Node) -> Array:
	var out: Array = []
	if panel.button_container == null:
		return out
	for child in panel.button_container.get_children():
		if child is Button:
			out.append(str(child.text))
	return out

func _any_contains(labels: Array, needle: String) -> bool:
	for l in labels:
		if str(l).contains(needle):
			return true
	return false
