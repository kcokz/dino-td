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
	var holder = tree.root.get_node_or_null(DropItem.CONTAINER_NAME)
	if holder != null and is_instance_valid(holder):
		for child in holder.get_children():
			holder.remove_child(child)
			if not child.is_queued_for_deletion():
				child.free()

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
