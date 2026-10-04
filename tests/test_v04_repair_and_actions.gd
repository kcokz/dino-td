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
	# The turret once needed a blueprint from the kitchen and stone needs a pick, and the
	# tests here that go through the real build path were silently failing to place
	# anything without them -- place_building_at_cell() returned null and the test
	# died on the next line, still reporting PASS because it never reached an
	# assertion. This suite is about repair and orders, not about the cabin chain.
	unlock_all()

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

## A catapult, finished: the dear thing, wood and stone, that repair is really for.
func _catapult(pos: Vector3 = Vector3.ZERO, finished: bool = true) -> Node:
	var t = load("res://scripts/entities/Catapult.gd").new()
	t.setup("catapult")
	_cleanup_nodes.append(t)
	tree.root.add_child(t)
	t.position = pos
	if finished:
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
	var turret = _catapult()
	await wait_frames(1)
	assert_false(turret.needs_repair(), "At full health there is nothing to mend")
	assert_eq(turret.repair_cost(), {}, "And nothing to pay")

	turret.take_damage(turret.max_hp * 0.5)
	assert_true(turret.needs_repair(), "Damaged, it does")
	# repair_cost() is a bill per resource, not a number. Comparing it with 0 was a
	# runtime error, which aborted this test silently and left it counted as a pass.
	var bill: Dictionary = turret.repair_cost()
	assert_gt(bill.size(), 0, "And it quotes a price")
	for res_id in bill:
		assert_gt(int(bill[res_id]), 0, "Which asks for some %s" % res_id)

	var blueprint = _catapult(Vector3(20.0, 0.0, 0.0), false)
	blueprint.start_construction()
	await wait_frames(1)
	assert_false(blueprint.needs_repair(), "A blueprint is raised, not mended")

func test_02_the_bill_is_the_price_scaled_by_the_damage() -> void:
	# Never more than building it again, and a scratch costs the minimum rather
	# than a flat fee.
	var turret = _catapult()
	await wait_frames(1)
	var price: Dictionary = config_node.BUILDINGS["catapult"]["cost"]

	turret.take_damage(turret.max_hp * 0.5)
	for res_id in price:
		var want: int = int(ceil(int(price[res_id]) * turret.damage_fraction()))
		assert_eq(int(turret.repair_cost().get(res_id, 0)), want,
			"Half gone costs half the %s, rounded up" % res_id)

func test_03_mending_never_costs_more_than_building_it_again() -> void:
	var turret = _catapult()
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 0.001)   # all but destroyed
	var price: Dictionary = config_node.BUILDINGS["catapult"]["cost"]
	for res_id in price:
		assert_lte(int(turret.repair_cost().get(res_id, 0)), int(price[res_id]),
			"Even gutted, the %s bill is capped at what it cost to build" % res_id)
	assert_lte(turret.repair_price_total(), total_price_of("catapult"),
		"So repair is never the worse deal")

func test_04_a_scratch_costs_the_minimum_not_a_flat_fee() -> void:
	var turret = _catapult()
	await wait_frames(1)
	turret.take_damage(0.5)
	assert_eq(turret.repair_price_total(), turret.repair_cost().size(),
		"One unit of each resource it is short of, and no more")
	assert_lt(turret.repair_price_total(), total_price_of("catapult"),
		"Which is far less than rebuilding it")

func test_05_the_bill_is_charged_once_at_the_end() -> void:
	# One transaction: walking away costs the time spent and nothing else, so there
	# is never a half-paid building to explain.
	var turret = _catapult()
	await wait_frames(1)
	turret.take_damage(turret.max_hp * 0.5)
	pay_for(["catapult"], 99)
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
	var turret = _catapult()
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
	# Half a metre off its west side.
	var turret = _catapult(Vector3(float(config_node.get_building_half("catapult").x) + 0.5, 0.0, 0.0))
	await wait_frames(1)
	turret.take_damage(turret.max_hp - 1.0)
	# A catapult is mended with wood and stone -- and the stock holds nothing to load it with, or he would load
	# it before mending it (Hero._process_building).
	pay_for(["catapult"])

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
	# Its price and nothing over: nothing in the stock to load it with, so a right-click is not a loading.
	pay_for(["catapult"])
	var turret = main.place_building_at_cell("catapult", Vector2i(4, 4))
	assert_not_null(turret, "A catapult is down")
	if turret == null:
		return
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
	await wait_frames(8)
	main.hero.global_position = main.cabin_door() + Vector3(2.0, 0.0, 1.0)
	await wait_physics_frames(2)

	main.right_click_building(main.current_core, main.current_core.global_position)
	var inside: Vector3 = main.current_core.door_inside()
	var end: Vector3 = main.hero.target_destination
	assert_almost_eq(Vector2(end.x, end.z).distance_to(Vector2(inside.x, inside.z)), 0.0, 0.3,
		"Right-clicking the cabin sends him in, just inside its door")

func test_10_mending_is_offered_on_the_panel_when_there_is_damage() -> void:
	var panel = load("res://scripts/ui/OptionPanel.gd").new()
	_cleanup_nodes.append(panel)
	tree.root.add_child(panel)
	var turret = _catapult(Vector3(6.0, 0.0, 0.0))
	await wait_frames(1)
	game_state_node.resources["wood"] = 99

	panel.select_target(turret)
	var labels_healthy: Array = _button_labels(panel)
	assert_false(_any_contains(labels_healthy, tr("CMD_REPAIR").split(" ")[0]),
		"Nothing to mend at full health, so nothing is offered")

	turret.take_damage(turret.max_hp * 0.5)
	panel.select_target(turret)
	var labels: Array = _button_labels(panel)
	# The bill is listed in what it actually costs -- a catapult is mended with wood
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
	var turret = _catapult(Vector3(6.0, 0.0, 0.0))
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
	pay_for(["catapult"], 99)
	var turret = main.place_building_at_cell("catapult", Vector2i(5, 5))
	assert_not_null(turret, "A catapult is down")
	if turret == null:
		return
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
