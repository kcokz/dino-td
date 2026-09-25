# res://tests/test_v03_drops.gd
# v0.3: every resource enters the warehouse through the Hero's hands.
#
# Stage A -- the drop itself and picking it up:
#   * a drop carries a type and an amount, and lies on the ground without
#     occupying it (it must never block building or pathing);
#   * the Hero sweeps up anything within reach, no clicking involved;
#   * piles merge rather than carpeting the field, and the ground cap limits
#     piles without ever deleting what the player earned.
extends "res://tests/test_base.gd"

var config_node: Object = null
var event_bus_node: Object = null
var game_state_node: Object = null
var fx_node: Object = null

var drop_script: GDScript = null
var hero_script: GDScript = null
var build_system_script: GDScript = null
var grid_manager_script: GDScript = null
var dino_script: GDScript = null
var guard_script: GDScript = null
var resource_node_script: GDScript = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		event_bus_node = tree.root.get_node_or_null("EventBus")
		game_state_node = tree.root.get_node_or_null("GameState")
		fx_node = tree.root.get_node_or_null("Fx")
	drop_script = _load_script("res://scripts/entities/DropItem.gd")
	hero_script = _load_script("res://scripts/entities/Hero.gd")
	build_system_script = _load_script("res://scripts/core/BuildSystem.gd")
	grid_manager_script = _load_script("res://scripts/core/GridManager.gd")
	dino_script = _load_script("res://scripts/entities/Dino.gd")
	guard_script = _load_script("res://scripts/entities/GuardDino.gd")
	resource_node_script = _load_script("res://scripts/entities/ResourceNode.gd")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	_clear_ground()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	_clear_ground()
	super.after_each()

func _load_script(path: String) -> GDScript:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is GDScript:
			return res
	return null

## Drops park themselves under a shared container, so one test's litter would
## otherwise turn up in the next one's sweep.
func _clear_ground() -> void:
	for d in tree.get_nodes_in_group("drops"):
		if is_instance_valid(d):
			if d.is_inside_tree():
				d.get_parent().remove_child(d)
			if not d.is_queued_for_deletion():
				d.free()
	# The ad-hoc container a bare tree gets goes too, so a test that expects the
	# level to own the container is not shadowed by an earlier test's leftovers.
	var holder = tree.root.get_node_or_null(DropItem.CONTAINER_NAME)
	if holder != null and is_instance_valid(holder):
		tree.root.remove_child(holder)
		holder.free()

func _piles() -> Array:
	var out: Array = []
	for d in tree.get_nodes_in_group("drops"):
		if is_instance_valid(d) and not d.is_queued_for_deletion():
			out.append(d)
	return out

func _ground_total(res_id: String = "") -> int:
	var sum: int = 0
	for d in _piles():
		if res_id == "" or d.resource_type == res_id:
			sum += int(d.amount)
	return sum

func _wallet(res_id: String = "wood") -> int:
	return int(game_state_node.resources.get(res_id, 0))

func _drop_cfg(key: String, fallback: float) -> float:
	return float(config_node.DROPS.get(key, fallback))

func _spawn_hero(pos: Vector3 = Vector3.ZERO) -> Node:
	var h = hero_script.new()
	_cleanup_nodes.append(h)
	tree.root.add_child(h)
	h.position = pos
	h.continuous_mode = true
	return h

# ==============================================================================
# 1. The drop itself
# ==============================================================================

func test_01_a_drop_carries_what_it_is_and_how_much() -> void:
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var drop = DropItem.spawn(hero, Vector3(5.0, 0.0, 5.0), "wood", 3)
	await wait_frames(1)

	assert_not_null(drop, "A drop is created on the ground")
	assert_eq(drop.resource_type, "wood", "It knows what it is")
	assert_eq(drop.amount, 3, "And how much of it there is")
	assert_true(drop.is_in_group("drops"), "It is findable by anything sweeping the ground")
	assert_almost_eq(drop.global_position.x, 5.0, 0.01, "It lies where it fell")

func test_02_a_drop_is_not_one_more_thing_to_click() -> void:
	# Collection is by walking over it. Making drops selectable would turn "click
	# the tree" into "click the thing the tree left", which is not an improvement.
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var drop = DropItem.spawn(hero, Vector3(5.0, 0.0, 5.0), "wood", 1)
	await wait_frames(1)

	assert_false(drop.is_in_group("selectable"), "A drop is not a selection target")
	assert_false(drop is CollisionObject3D, "And has no body for a click to land on")

func test_03_a_drop_does_not_occupy_the_ground_it_lies_on() -> void:
	# This is the constraint that decides the whole entity: a pile of wood must
	# never block a building or push pathing around it.
	var grid = grid_manager_script.new()
	_cleanup_nodes.append(grid)
	tree.root.add_child(grid)
	var builder = build_system_script.new()
	_cleanup_nodes.append(builder)
	tree.root.add_child(builder)
	builder.setup(grid, null)
	await wait_frames(1)

	var cell := Vector2i(2, -2)
	var at: Vector3 = grid.cell_to_world(cell)
	DropItem.spawn(grid, at, "wood", 5)
	await wait_frames(1)

	assert_false(grid.is_cell_occupied(cell), "The cell under a drop is still free")
	game_state_node.resources["wood"] = cost_of("wall") * 2
	assert_true(builder.can_place_building("wall", cell),
		"And a building can still go there")

func test_04_spawning_announces_itself_on_the_bus() -> void:
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var watcher = watch_signal(event_bus_node, "resource_dropped")
	DropItem.spawn(hero, Vector3(6.0, 0.0, 6.0), "stone", 2)
	await wait_frames(1)

	assert_true(watcher.emitted, "Anything watching the ground hears about a new drop")
	assert_eq(watcher.last_args[0], "stone", "It says what was dropped")
	assert_eq(watcher.last_args[1], 2, "And how much")

# ==============================================================================
# 2. Picking things up
# ==============================================================================

func test_05_the_hero_sweeps_up_what_he_walks_over() -> void:
	var hero = _spawn_hero(Vector3.ZERO)
	await wait_frames(1)

	# No frame between dropping and sweeping: the Hero's own physics step would
	# otherwise have picked it up already, which is the point of test 09.
	var before: int = _wallet("wood")
	var radius: float = _drop_cfg("pickup_radius", 1.6)
	DropItem.spawn(hero, Vector3(radius * 0.5, 0.0, 0.0), "wood", 4)

	var banked: int = hero.sweep_for_drops()
	assert_eq(banked, 4, "The whole pile goes in at once")
	assert_eq(_wallet("wood"), before + 4, "And lands in the warehouse")
	assert_eq(_piles().size(), 0, "Nothing is left on the ground")

func test_06_a_pile_out_of_reach_stays_where_it_is() -> void:
	var hero = _spawn_hero(Vector3.ZERO)
	var before: int = _wallet("wood")
	var radius: float = _drop_cfg("pickup_radius", 1.6)
	DropItem.spawn(hero, Vector3(radius * 3.0, 0.0, 0.0), "wood", 4)
	await wait_frames(1)

	assert_eq(hero.sweep_for_drops(), 0, "Out of reach is out of reach")
	assert_eq(_wallet("wood"), before, "The warehouse does not fill itself")
	assert_eq(_ground_total("wood"), 4, "The pile is still there to be fetched")

func test_07_a_pile_is_banked_once_and_only_once() -> void:
	var hero = _spawn_hero(Vector3.ZERO)
	await wait_frames(1)

	var before: int = _wallet("wood")
	var drop = DropItem.spawn(hero, Vector3(0.2, 0.0, 0.0), "wood", 5)
	assert_eq(drop.collect(hero), 5, "First collector takes it")
	assert_eq(drop.collect(hero), 0, "A second attempt finds it already gone")
	assert_eq(_wallet("wood"), before + 5, "So the wood cannot be banked twice")

func test_08_picking_up_announces_itself_and_moves_the_readout() -> void:
	var hero = _spawn_hero(Vector3.ZERO)
	var picked = watch_signal(event_bus_node, "resource_picked_up")
	var changed = watch_signal(event_bus_node, "resources_changed")
	DropItem.spawn(hero, Vector3(0.3, 0.0, 0.0), "stone", 2)
	await wait_frames(1)

	hero.sweep_for_drops()
	assert_true(picked.emitted, "Collection is broadcast rather than silently banked")
	assert_eq(picked.last_args[0], "stone", "It says what was collected")
	assert_eq(picked.last_args[1], 2, "And how much")
	assert_true(changed.emitted, "The HUD's resource readout is told to update")

func test_09_walking_is_enough_no_order_is_needed() -> void:
	# The Hero sweeps as part of his ordinary physics step, whatever else he is
	# doing -- so a pile passed on the way to a build site still gets picked up.
	var hero = _spawn_hero(Vector3.ZERO)
	await wait_frames(1)
	var before: int = _wallet("wood")
	DropItem.spawn(hero, Vector3(0.4, 0.0, 0.0), "wood", 1)

	hero._physics_process(0.016)
	assert_eq(_wallet("wood"), before + 1, "It went in without anyone being told to fetch it")
	assert_eq(_piles().size(), 0, "Off the ground as he walked")

func test_10_a_dead_hero_picks_nothing_up() -> void:
	var hero = _spawn_hero(Vector3.ZERO)
	DropItem.spawn(hero, Vector3(0.3, 0.0, 0.0), "wood", 2)
	await wait_frames(1)

	hero.current_state = hero.State.DEAD
	var before: int = _wallet("wood")
	assert_eq(hero.sweep_for_drops(), 0, "A corpse does no fetching")
	assert_eq(_wallet("wood"), before, "And the wallet stays put")

# ==============================================================================
# 3. Merging and the ground cap
# ==============================================================================

func test_11_piles_of_the_same_thing_merge_instead_of_carpeting_the_field() -> void:
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var merge: float = _drop_cfg("merge_radius", 1.1)
	assert_gt(merge, 0.0, "Merging is on, or a long fight buries the map in singles")

	var first = DropItem.spawn(hero, Vector3(5.0, 0.0, 5.0), "wood", 1)
	var second = DropItem.spawn(hero, Vector3(5.0 + merge * 0.5, 0.0, 5.0), "wood", 2)
	await wait_frames(1)

	assert_eq(second, first, "The second drop joins the pile already there")
	assert_eq(_piles().size(), 1, "One pile, not two")
	assert_eq(_ground_total("wood"), 3, "Carrying everything that was dropped")

func test_12_different_resources_never_share_a_pile() -> void:
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	DropItem.spawn(hero, Vector3(5.0, 0.0, 5.0), "wood", 1)
	DropItem.spawn(hero, Vector3(5.0, 0.0, 5.0), "stone", 1)
	await wait_frames(1)

	assert_eq(_piles().size(), 2, "Wood and stone stay separate piles")
	assert_eq(_ground_total("wood"), 1, "Wood is wood")
	assert_eq(_ground_total("stone"), 1, "Stone is stone")

func test_13_a_pile_far_enough_away_is_its_own_pile() -> void:
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var merge: float = _drop_cfg("merge_radius", 1.1)
	DropItem.spawn(hero, Vector3(5.0, 0.0, 5.0), "wood", 1)
	DropItem.spawn(hero, Vector3(5.0 + merge * 3.0, 0.0, 5.0), "wood", 1)
	await wait_frames(1)

	assert_eq(_piles().size(), 2, "Distance means two piles, not one")

func test_14_the_ground_cap_limits_piles_never_resources() -> void:
	# The cap is a performance guard. Deleting the oldest drop to respect it would
	# quietly destroy what the player earned, so at the cap a new drop merges into
	# the nearest pile of its kind instead.
	var hero = _spawn_hero(Vector3(80.0, 0.0, 80.0))
	var cap: int = int(_drop_cfg("max_on_ground", 200))
	var spacing: float = _drop_cfg("merge_radius", 1.1) * 4.0

	for i in range(cap):
		DropItem.spawn(hero, Vector3(float(i) * spacing, 0.0, 0.0), "wood", 1)
	await wait_frames(1)
	assert_eq(_piles().size(), cap, "The ground is full")
	assert_eq(_ground_total("wood"), cap, "Holding one unit per pile")

	DropItem.spawn(hero, Vector3(-500.0, 0.0, -500.0), "wood", 7)
	assert_eq(_piles().size(), cap, "One more drop does not add a pile")
	assert_eq(_ground_total("wood"), cap + 7, "But every unit of it is still on the ground")

func test_15_scattering_splits_an_amount_without_losing_any_of_it() -> void:
	var hero = _spawn_hero(Vector3(80.0, 0.0, 80.0))
	var piles: Array = DropItem.spawn_scattered(hero, Vector3(10.0, 0.0, 10.0), "wood", 9, 3)
	await wait_frames(1)

	assert_gt(piles.size(), 0, "Scattering puts something on the ground")
	assert_eq(_ground_total("wood"), 9, "And exactly what it was asked to scatter")

	var radius: float = _drop_cfg("scatter_radius", 0.8)
	for p in _piles():
		assert_lte(Vector2(p.global_position.x - 10.0, p.global_position.z - 10.0).length(),
			radius + 0.001, "Each pile lands inside the scatter radius")

# ==============================================================================
# 4. Rotting is off, and is a number rather than a shape
# ==============================================================================

func test_16_drops_do_not_rot_by_default() -> void:
	# A raid fought at the far end of the map would otherwise be work for nothing.
	assert_eq(_drop_cfg("lifetime", 0.0), 0.0, "Config leaves drops on the ground")

	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var drop = DropItem.spawn(hero, Vector3(9.0, 0.0, 9.0), "wood", 1)
	await wait_frames(1)
	drop._process(999.0)
	assert_false(drop.is_collected, "Time alone does not take it away")
	assert_eq(_ground_total("wood"), 1, "It is still there to be fetched")

func test_17_a_lifetime_above_zero_does_make_them_rot() -> void:
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var drop = DropItem.spawn(hero, Vector3(9.0, 0.0, 9.0), "wood", 1)
	await wait_frames(1)

	drop.lifetime = 2.0
	drop._process(1.0)
	assert_false(drop.is_collected, "Still fresh")
	drop._process(1.5)
	assert_true(drop.is_collected, "Past its time it is gone")
	assert_false(drop.is_in_group("drops"), "And out of everyone's sweep")

func test_18_a_paused_game_does_not_age_the_ground() -> void:
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var drop = DropItem.spawn(hero, Vector3(9.0, 0.0, 9.0), "wood", 1)
	await wait_frames(1)
	drop.lifetime = 1.0

	game_state_node.is_paused = true
	drop._process(5.0)
	assert_false(drop.is_collected, "Reading the map does not spoil the meat")
	game_state_node.is_paused = false
	drop._process(5.0)
	assert_true(drop.is_collected, "Unpausing resumes the clock")

# ==============================================================================
# 5. Feedback
# ==============================================================================

func test_19_there_is_a_sound_for_picking_something_up() -> void:
	assert_true(fx_node.Sound.has("PICKUP"), "Collection has a voice of its own")
	var stream = fx_node._streams.get(fx_node.Sound.PICKUP, null)
	assert_not_null(stream, "Synthesised at startup like the rest")
	assert_gt(stream.data.size(), 0, "With actual samples in it")

func test_20_a_single_unit_carries_no_label_but_a_pile_does() -> void:
	# A field of "1"s is noise; "12" is information.
	var hero = _spawn_hero(Vector3(40.0, 0.0, 40.0))
	var min_amount: int = int(_drop_cfg("label_min_amount", 2))
	var single = DropItem.spawn(hero, Vector3(20.0, 0.0, 20.0), "wood", 1)
	await wait_frames(1)
	assert_false(single.label_3d.visible, "One unit needs no caption")

	single.add_amount(min_amount)
	assert_true(single.label_3d.visible, "A pile says how big it is")
	assert_eq(single.label_3d.text, str(single.amount), "And the number is the amount")

# ==============================================================================
# 6. Stage B: the three things that used to bank numbers
# ==============================================================================

func _spawn(script: GDScript, pos: Vector3 = Vector3.ZERO) -> Node:
	var n = script.new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = pos
	return n

func _dino_drops(type_id: String) -> Dictionary:
	return config_node.DINOS[type_id].get("drops", {})

func test_21_a_dead_dinosaur_leaves_meat() -> void:
	var dino = _spawn(dino_script, Vector3(12.0, 0.0, 12.0))
	dino.setup("raptor")
	await wait_frames(1)

	var expected: int = int(_dino_drops("raptor").get("food", 0))
	assert_gt(expected, 0, "A raptor is worth something dead")

	dino.take_damage(dino.max_hp)
	assert_true(dino.is_dead, "The raptor is down")
	assert_eq(_ground_total("food"), expected, "And left exactly what Config says it does")

func test_22_meat_is_the_only_source_of_food() -> void:
	# `food` was dead data before this: a column in the wallet with no way to fill
	# it. Dinosaurs are now the one and only tap.
	assert_has(config_node.RESOURCES, "food", "Food is a real resource")
	assert_eq(int(config_node.INITIAL_RESOURCES.get("food", 0)), 0, "Nobody starts with meat")
	var any_dino_drops_food: bool = false
	for type_id in config_node.DINOS:
		if int(config_node.DINOS[type_id].get("drops", {}).get("food", 0)) > 0:
			any_dino_drops_food = true
	assert_true(any_dino_drops_food, "Every kind of dinosaur is worth meat")
	for b_type in config_node.BUILDINGS:
		assert_eq(int(config_node.BUILDINGS[b_type].get("produces_per_sec", {}).get("food", 0)), 0,
			"%s does not conjure meat -- it comes off dinosaurs or not at all" % b_type)

func test_23_meat_has_to_be_fetched_like_everything_else() -> void:
	var hero = _spawn_hero(Vector3.ZERO)
	var dino = _spawn(dino_script, Vector3(30.0, 0.0, 30.0))
	dino.setup("raptor")
	await wait_frames(1)

	var before: int = _wallet("food")
	dino.take_damage(dino.max_hp)
	assert_eq(_wallet("food"), before, "Killing it does not feed anyone by itself")
	assert_gt(_ground_total("food"), 0, "The meat is out there where it fell")

func test_24_a_nest_guard_is_worth_meat_too() -> void:
	var guard = _spawn(guard_script, Vector3(25.0, 0.0, 25.0))
	guard.setup("raptor")
	await wait_frames(1)

	guard.take_damage(guard.max_hp)
	assert_gt(_ground_total("food"), 0, "A guard leaves a carcass like any other dinosaur")

func test_26_the_hero_is_what_turns_a_pile_into_a_wallet() -> void:
	# The rule that survived v0.4 and is now the whole economy: a pile on the ground
	# is not money. Nothing banks itself, however it got there.
	#
	# It used to be driven by a producer building. Those are gone, so the pile now
	# comes off a dead dinosaur -- which is the source that matters today.
	var hero = _spawn_hero(Vector3(60.0, 0.0, 60.0))
	var dino = _spawn(dino_script, Vector3(20.0, 0.0, 0.0))
	dino.setup("raptor")
	await wait_frames(1)

	var before: int = _wallet("food")
	dino.take_damage(dino.max_hp)
	var meat: int = _ground_total("food")
	var everything: int = _ground_total()      # a carcass is bone as well as meat
	assert_gt(meat, 0, "There is a pile to fetch")
	assert_eq(_wallet("food"), before, "And it has not banked itself")

	hero.global_position = Vector3(20.0, 0.0, 0.0)
	assert_eq(hero.sweep_for_drops(), everything, "Walking over it collects the lot")
	assert_eq(_wallet("food"), before + meat, "Which is how it reaches the warehouse")

func test_27_hand_harvesting_goes_through_the_ground_as_well() -> void:
	# It looks the same to the player -- the Hero is standing on what he cut, so
	# his next sweep takes it -- but there is now one rule rather than two.
	var hero = _spawn_hero(Vector3.ZERO)
	var node = resource_node_script.new("wood", Vector2i(1, 0))
	_cleanup_nodes.append(node)
	tree.root.add_child(node)
	node.position = Vector3(1.0, 0.0, 0.0)
	node.setup("wood", Vector2i(1, 0), 20)
	await wait_frames(1)

	var before: int = _wallet("wood")
	hero.order_harvest(node)
	var secs: float = 1.0 / maxf(float(node.harvest_rate), 0.01)
	hero._physics_process(secs + 0.05)

	assert_eq(_wallet("wood"), before, "The cut wood is on the floor for a moment")
	assert_gt(_ground_total("wood"), 0, "Lying at his feet")

	hero._physics_process(0.016)   # the sweep at the top of his next step
	assert_gt(_wallet("wood"), before, "And he picks up what he cut")
	assert_eq(_ground_total("wood"), 0, "Leaving nothing behind")

# ==============================================================================
# 7. Stage B4: the opening stock lies by the cabin
# ==============================================================================

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

func test_28_a_new_game_banks_nothing_at_all() -> void:
	# The first thing the game teaches is that resources are carried. A number in
	# the wallet at frame zero is a second, silent way to get rich.
	for res_id in config_node.RESOURCES:
		assert_eq(int(config_node.INITIAL_RESOURCES.get(res_id, 0)), 0,
			"Nobody starts with %s in hand" % res_id)
	assert_gt(config_node.get_opening_stock("wood"), 0,
		"But there is real wood to go and fetch")

func test_29_the_opening_stock_is_on_the_ground_by_the_cabin() -> void:
	var main = _level()
	await wait_frames(2)

	var expected: int = config_node.get_opening_stock("wood")
	assert_eq(_ground_total("wood"), expected,
		"Exactly the configured opening stock is lying about")
	assert_eq(_wallet("wood"), 0, "And none of it is in the warehouse yet")

	var centre: Vector3 = main.current_core.global_position
	# From the cabin's walls: it is a block of tiles across.
	var radius: float = float(config_node.get_building_footprint("core")) * 0.5 + _drop_cfg("opening_ring_gap", 4.0)
	for pile in _piles():
		assert_almost_eq(pile.global_position.distance_to(centre), radius, 0.5,
			"Each pile is laid around the cabin, not dumped on it")

func test_30_the_first_wood_has_to_be_walked_to() -> void:
	# If a pile started inside the Hero's pickup radius he would sweep it up on
	# frame one, and the lesson would be free.
	var main = _level()
	await wait_frames(2)

	var hero = main.hero
	assert_not_null(hero, "The level has a Hero")
	var reach: float = _drop_cfg("pickup_radius", 1.6)
	var piles: Array = _piles()
	assert_gt(piles.size(), 1, "The stock is split into several piles")
	for pile in piles:
		assert_gt(pile.global_position.distance_to(hero.global_position), reach,
			"Nothing is free: every pile needs a walk")

func test_31_walking_the_ring_banks_the_whole_opening() -> void:
	var main = _level()
	await wait_frames(2)

	var expected: int = config_node.get_opening_stock("wood")
	var hero = main.hero
	for pile in _piles():
		hero.global_position = pile.global_position
		hero.sweep_for_drops()
	assert_eq(_wallet("wood"), expected, "Fetching it all is what the opening wallet used to be")
	assert_eq(_piles().size(), 0, "And the ground is clear")

func test_32_restarting_sweeps_the_ground_and_lays_it_out_again() -> void:
	var main = _level()
	await wait_frames(2)

	# Litter the map, then restart.
	DropItem.spawn(main, main.current_core.global_position + Vector3(9.0, 0.0, 9.0), "stone", 5)
	var before: int = _piles().size()
	assert_gt(before, 0, "There is something on the ground to clear")

	main.restart_game()
	await wait_frames(2)

	assert_eq(_ground_total("stone"), 0, "Yesterday's stone is gone")
	assert_eq(_ground_total("wood"), config_node.get_opening_stock("wood"),
		"And a fresh opening stock is laid out")
	assert_eq(_wallet("wood"), 0, "With an empty warehouse to start from again")

func test_33_the_level_owns_the_drops_container() -> void:
	# A drop spawned from a level's own _ready() runs before SceneTree.current_scene
	# is assigned, so the container has to be found by group -- otherwise drops end
	# up under the tree root where a restart would never sweep them.
	var main = _level()
	await wait_frames(2)

	assert_not_null(main.drops_container, "The level keeps a container for drops")
	assert_true(main.drops_container.is_in_group(DropItem.CONTAINER_GROUP),
		"And declares it, so the spawner can find it")
	for pile in _piles():
		assert_eq(pile.get_parent(), main.drops_container,
			"Every pile is parented under the level's container")

# ==============================================================================
# 8. Stage C: the player can see it happen
# ==============================================================================

func test_34_collecting_something_says_so_where_it_happened() -> void:
	# The pile vanishes and a HUD number moves. Without a figure rising off the
	# spot, the gain happens somewhere the player is not looking.
	var main = _level()
	tree.current_scene = main          # Fx parks transient nodes under the running scene
	fx_node._debris_root = null
	await wait_frames(2)

	var hero = main.hero
	var pile = _piles()[0]
	var amount: int = int(pile.amount)
	var at: Vector3 = pile.global_position
	hero.global_position = at
	hero.sweep_for_drops()
	await wait_frames(1)

	var fx_root = main.find_child("FxDebris", false, false)
	assert_not_null(fx_root, "Fx has somewhere to put the figure")
	var floated: Label3D = null
	for child in fx_root.get_children():
		if child is Label3D:
			floated = child
	assert_not_null(floated, "A figure is drawn where the pile was")
	assert_eq(floated.text, "+%d" % amount, "Saying how much went in")
	assert_lte(Vector2(floated.position.x - at.x, floated.position.z - at.z).length(), 0.5,
		"Over the spot it was collected from, not over the HUD")
	tree.current_scene = null

func test_35_floating_text_is_safe_with_nothing_to_draw_on() -> void:
	# Feedback must never be able to break the simulation, headless included.
	fx_node.floating_text(Vector3.ZERO, "")
	fx_node.floating_text(Vector3(1.0, 0.0, 1.0), "+1", Color.WHITE)
	assert_true(true, "Floating text tolerates an empty string and a bare tree")

func test_36_demolition_rubble_is_picked_up_like_anything_else() -> void:
	# The refund was the last path that put resources in the warehouse without the
	# Hero touching them.
	var hero = _spawn_hero(Vector3(70.0, 0.0, 70.0))
	var wall = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.setup("wall")
	wall.position = Vector3(30.0, 0.0, 30.0)
	wall.complete_construction()
	await wait_frames(1)

	var refund: int = int(wall.demolition_refund().get("wood", 0))
	assert_gt(refund, 0, "Taking a stake down gives something back")
	var before: int = _wallet("wood")
	wall.demolish()

	assert_eq(_wallet("wood"), before, "Not as a number")
	assert_eq(_ground_total("wood"), refund, "As rubble on the ground")

	hero.global_position = Vector3(30.0, 0.0, 30.0)
	assert_eq(hero.sweep_for_drops(), refund, "Which the Hero then carries off")
	assert_eq(_wallet("wood"), before + refund, "And only then is it his")

func test_37_every_resource_the_game_makes_has_a_readout() -> void:
	# Meat only became collectable in v0.3, and a resource with no readout is a
	# resource the player cannot see themselves earning.
	var hud = load("res://scenes/ui/HUD.tscn").instantiate()
	_cleanup_nodes.append(hud)
	tree.root.add_child(hud)
	await wait_frames(1)

	hud._on_resources_changed({"wood": 1, "stone": 2, "water": 3, "food": 4})
	assert_eq(hud.food_label.text, tr("HUD_FOOD") % 4, "Meat has its own line in the top bar")
	assert_true(hud.food_label.visible, "And it is on screen")
