# res://tests/test_v05_the_cabin.gd
# The cabin: the crew module the Hero lives in, and the thing the raid is trying to reach.
#
# Reported as "船舱模型太小" -- it was a 1 m pod in one tile, no taller than the man who
# lives in it. One tile cannot hold a room and still leave a way past it, so it now takes
# a 2 x 2 block (Config.BUILDINGS.core.span). A building bigger than a tile broke every
# place that measured a building as a circle of half its width or as one tile: its corner
# attack slots stood inside its walls, a raptor at its corner could not bite it, and the
# Hero could not get close enough to its walls to repair it. These hold all of that.
extends "res://tests/test_base.gd"

var config_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	var dino_script = load("res://scripts/entities/Dino.gd")
	dino_script.clear_all_attack_slots()
	super.after_each()

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _span() -> int:
	return int(config_node.get_building_span("core"))

func _half() -> float:
	return float(config_node.get_building_footprint("core")) * 0.5

func _block(main: Node) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dz in range(_span()):
		for dx in range(_span()):
			out.append(main.core_cell + Vector2i(dx, dz))
	return out

func test_01_it_is_a_room_not_a_pod() -> void:
	var main = await _level()
	var core: Node3D = main.current_core
	var body: Node3D = core.find_child("Body", false, false)
	var drawn: AABB = VisualLibrary.visual_bounds(body)
	var hero_h: float = float(config_node.HERO["height"])
	assert_gt(_span(), 1, "It takes more than one tile")
	assert_gte(drawn.size.y / hero_h, 2.0, "It stands twice the Hero's height (%.2fx)" % (drawn.size.y / hero_h))
	assert_gte(minf(drawn.size.x, drawn.size.z), 2.0 * hero_h, "And is wider than two of him")
	# Drawn inside its own box, nothing hanging over the ground round it.
	var fp: float = float(config_node.get_building_footprint("core"))
	assert_lte(drawn.size.x, fp + 0.05, "No wider than its box east-west")
	assert_lte(drawn.size.z, fp + 0.05, "Nor north-south")

func test_02_it_holds_its_block_and_nothing_more() -> void:
	var main = await _level()
	var gm = main.grid_manager
	var core: Node = main.current_core
	var block: Array[Vector2i] = _block(main)
	for c in block:
		assert_true(gm.get_building_at(c) == core, "Tile %s is the cabin's" % str(c))
		assert_false(gm.is_cell_walkable(c), "And nobody walks through it")
		assert_false(main.build_system.can_place_building("wall", c), "Nor builds on it")
	var around: int = 0
	for c in block:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if block.has(n):
				continue
			around += 1
			assert_false(gm.get_building_at(n) == core, "Tile %s beside it is not" % str(n))
	assert_eq(around, 4 * _span(), "It is ringed by free tiles")
	assert_eq(core.cell_pos, main.core_cell, "It is registered at the tile it was placed at")

func test_03_its_north_and_west_walls_stand_where_the_pods_did() -> void:
	# The block runs south and east, so a raid coming down from the nest meets the same
	# line it always met: the pod's walls were half a metre into its tile.
	var main = await _level()
	var core: Node3D = main.current_core
	var origin: Vector3 = main.grid_manager.cell_to_world_origin(main.core_cell)
	assert_almost_eq(core.global_position.x - _half(), origin.x + 0.5, 0.001, "The west wall")
	assert_almost_eq(core.global_position.z - _half(), origin.z + 0.5, 0.001, "The north wall")

func test_04_there_is_a_way_past_it_on_every_side() -> void:
	# As wide as its block allows while leaving the Hero a way past: whatever is built on
	# the tiles beside it, the gap is wider than he is.
	var block_edge: float = float(_span()) * float(config_node.TILE_SIZE) * 0.5
	var slack: float = block_edge - _half()
	var tower_slack: float = (float(config_node.TILE_SIZE) - float(config_node.get_building_footprint("tower"))) * 0.5
	assert_gte(slack + tower_slack, float(config_node.HERO["width"]), "A turret beside it leaves him a way through")
	assert_false(config_node.is_barrier_building("core"), "It is not a wall")
	# And the mesh agrees: he can walk from one side of it to the other.
	var main = await _level()
	var c: Vector3 = main.current_core.global_position
	var south := c + Vector3(0.0, 0.0, block_edge + 1.0)
	var north := c + Vector3(0.0, 0.0, -block_edge - 1.0)
	assert_true(main.nav_maps.is_reachable(south, north, true), "Round it from the door to the back")

func test_05_a_raptor_can_bite_it_from_every_side() -> void:
	# Every attack slot is out in the open, and from every one of them the cabin is in
	# reach. Round a circle of half its width, the four corner slots stood inside it.
	var main = await _level()
	var core: Node3D = main.current_core
	var dino_script = load("res://scripts/entities/Dino.gd")
	var raptor = dino_script.new()
	_cleanup_nodes.append(raptor)
	main.add_child(raptor)
	raptor.setup("raptor")
	raptor.set_physics_process(false)
	await wait_frames(1)
	dino_script._init_building_slots(core)
	var slots: Array = dino_script._building_slots[core.get_instance_id()]
	assert_eq(slots.size(), 16, "Sixteen places to stand")
	var inside: int = 0
	var inner: int = 0
	var out_of_reach: int = 0
	for s in slots:
		var at: Vector3 = s["pos"]
		var gap: float = float(config_node.gap_to_building(at, "core", core.global_position))
		if gap < 0.4:
			inside += 1
		# The inner ring is where they stand to bite; the outer one is where they wait.
		if gap < float(config_node.DINO_STANDOFF_INNER) + 0.01:
			inner += 1
			raptor.global_position = at
			if not raptor._target_in_reach(core):
				out_of_reach += 1
	assert_eq(inside, 0, "None of them inside its walls, or too close to stand at")
	assert_eq(inner, 8, "Eight of them close enough to bite from")
	assert_eq(out_of_reach, 0, "And from every one of those, it can")
	# And the corner: touching it there is touching it.
	raptor.global_position = core.global_position + Vector3(_half() + 0.3, 0.0, _half() + 0.3)
	assert_true(raptor._target_in_reach(core), "Standing at its corner, it can bite")

func test_06_the_hero_steps_inside_from_any_side() -> void:
	var main = await _level()
	var c: Vector3 = main.current_core.global_position
	var out: float = _half() + 1.0
	for spot in [Vector3(0, 0, out), Vector3(0, 0, -out), Vector3(out, 0, 0), Vector3(-out, 0, 0),
			Vector3(out, 0, out) * 0.85]:
		main.hero.global_position = c + spot
		assert_true(main._hero_is_at_cabin(), "Close to its wall at %s, he can go in" % str(spot))
	main.hero.global_position = c + Vector3(0.0, 0.0, _half() + 3.0)
	assert_false(main._hero_is_at_cabin(), "Three metres off, he cannot")

func test_07_he_can_reach_its_walls_to_repair_it() -> void:
	var main = await _level()
	var core: Node3D = main.current_core
	var route: PackedVector3Array = main.nav_maps.path(main.hero.global_position, core.global_position, true)
	assert_gt(route.size(), 0, "He has a way to it")
	if route.size() > 0:
		assert_true(main.hero._is_in_build_range(route[route.size() - 1], core),
			"Where his way to it ends, he can work on it")

func test_08_when_it_falls_every_tile_it_held_comes_free() -> void:
	var main = await _level()
	var gm = main.grid_manager
	var core = main.current_core
	var block: Array[Vector2i] = _block(main)
	core.take_damage(core.max_hp * 2.0)
	await wait_frames(2)
	for c in block:
		assert_false(gm.get_building_at(c) != null and gm.get_building_at(c) == core,
			"Tile %s is not held by a cabin that is gone" % str(c))

func test_09_the_hero_and_the_opening_stock_start_outside_it() -> void:
	var main = await _level()
	var c: Vector3 = main.current_core.global_position
	var hero_half: float = float(config_node.HERO["width"]) * 0.5
	assert_gte(float(config_node.gap_to_building(main.hero.global_position, "core", c)), hero_half,
		"The Hero starts clear of its walls")
	var inside: int = 0
	var piles: int = 0
	for d in get_tree_nodes_in_group("drops"):
		piles += 1
		if float(config_node.gap_to_building((d as Node3D).global_position, "core", c)) < 0.3:
			inside += 1
	assert_gt(piles, 0, "The opening stock was laid out")
	assert_eq(inside, 0, "None of it inside the cabin")

func get_tree_nodes_in_group(group: String) -> Array:
	return tree.root.get_tree().get_nodes_in_group(group)
