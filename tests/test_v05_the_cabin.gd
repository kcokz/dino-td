# res://tests/test_v05_the_cabin.gd
# The cabin: the crew module the Hero lives in, and the thing the raid is trying to reach.
#
# Reported as "船舱模型太小" -- it was a 1 m pod in one tile, no taller than the man who
# lives in it. It is a module seven cells of the building grid long and three deep now
# (Config.BUILDINGS.core.size), with a room inside it he walks into (v0.6 round three). A
# building bigger than a tile broke every place that measured a building as a circle of half its
# width or as one tile: its corner attack slots stood inside its walls, a raptor at its corner
# could not bite it, and the Hero could not get close enough to its walls to repair it. These
# hold all of that.
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

## Cells of the building grid it takes, east-west and north-south.
func _span() -> Vector2i:
	return config_node.get_building_size("core")

## Half its box on the ground, in metres: x east-west, y north-south.
func _half() -> Vector2:
	return config_node.get_building_half("core")

## The cells of the building grid it holds.
func _block(main: Node) -> Array[Vector2i]:
	var gm = main.grid_manager
	return gm.footprint_cells("core", gm.world_to_build_cell(main.current_core.global_position))

func test_01_it_is_a_room_not_a_pod() -> void:
	var main = await _level()
	var core: Node3D = main.current_core
	var body: Node3D = core.find_child("Body", false, false)
	var drawn: AABB = VisualLibrary.visual_bounds(body)     # its geometry: not the reach of its lamp
	var hero_h: float = float(config_node.HERO["height"])
	assert_gt(_span().x * _span().y, 1, "It takes more than one cell")
	assert_gte(drawn.size.y / hero_h, 2.0, "It stands twice the Hero's height (%.2fx)" % (drawn.size.y / hero_h))
	assert_gte(minf(drawn.size.x, drawn.size.z), 2.0 * hero_h, "And is wider than two of him")
	# Drawn inside its own box, nothing hanging over the ground round it.
	assert_lte(drawn.size.x, _half().x * 2.0 + 0.05, "No wider than its box east-west")
	assert_lte(drawn.size.z, _half().y * 2.0 + 0.05, "Nor north-south")

func test_02_it_holds_its_block_and_nothing_more() -> void:
	var main = await _level()
	var gm = main.grid_manager
	var core: Node = main.current_core
	var block: Array[Vector2i] = _block(main)
	assert_eq(block.size(), _span().x * _span().y, "A block of cells")
	for c in block:
		assert_true(gm.building_in_build_cell(c) == core, "Cell %s is the cabin's" % str(c))
		assert_false(main.build_system.can_place_at("wall", c), "Nor is anything built on it")
	# Its room is ground only he walks on: a raid's nearest ground to its middle is outside it.
	var middle: Vector3 = (core as Node3D).global_position
	var nearest: Vector3 = main.nav_maps.closest_point(middle, NavMaps.For.RAID)
	assert_gt(float(config_node.gap_to_building(nearest, "core", middle)), 0.0,
		"And no raid stands in it: its nearest ground is outside the walls")
	var around: int = 0
	for c in block:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if block.has(n):
				continue
			around += 1
			assert_false(gm.building_in_build_cell(n) == core, "Cell %s beside it is not" % str(n))
	assert_eq(around, 2 * (_span().x + _span().y), "It is ringed by cells that are not its")
	assert_eq(core.cell_pos, main.core_cell, "It is registered at the tile it was placed at")

func test_03_its_north_wall_stands_where_the_pods_did() -> void:
	# The block runs south, so a raid coming down from the nest meets the same line it always
	# met: the pod's wall was half a metre into its tile. Its middle is where the three-metre
	# cabin's was, the module running out either side.
	var main = await _level()
	var core: Node3D = main.current_core
	var origin: Vector3 = main.grid_manager.cell_to_world_origin(main.core_cell)
	assert_almost_eq(core.global_position.z - _half().y, origin.z + 0.5, 0.001, "The north wall")
	assert_almost_eq(core.global_position.x, origin.x + 0.5 + _half().y, 0.001, "Its middle")

func test_04_there_is_a_way_past_it_on_every_side() -> void:
	# Nothing is built into the cabin's walls by the level; a way past it is a free cell beside
	# it, which is wider than he is -- whatever the player later builds flush against it is his
	# own choice (v0.6 round two: everything stands flush, on one grid).
	assert_gte(float(config_node.BUILD_CELL), float(config_node.HERO["width"]),
		"One free cell beside it is a way past it")
	assert_ne(String(config_node.get_building_kind("core")), "wall", "It is not a wall")
	# And the mesh agrees: he can walk from one side of it to the other.
	var main = await _level()
	var c: Vector3 = main.current_core.global_position
	var south := c + Vector3(0.0, 0.0, _half().y + 2.0)
	var north := c + Vector3(0.0, 0.0, -_half().y - 2.0)
	assert_true(main.nav_maps.is_reachable(south, north, NavMaps.For.RAID), "Round it from the door to the back")

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
	# A place every slot_spacing along each face and one off each corner, in each of two rings (a
	# long face has a place for every body that fits along it -- the debug-agent's BUG-005).
	var half: Vector2 = config_node.get_building_half("core")
	var spacing: float = float(config_node.DINO_AI["slot_spacing"])
	var per_ring: int = 2 * (maxi(1, int(floor(half.x * 2.0 / spacing + 0.001))) + maxi(1, int(floor(half.y * 2.0 / spacing + 0.001)))) + 4
	# Less those in front of the door (Config.CABIN.doorstep, v0.7: his way out is always open).
	var at_door: Array = [0, 0]
	for k in 2:
		var standoff: float = float(config_node.DINO_STANDOFF_INNER) if k == 0 else float(config_node.DINO_STANDOFF_OUTER)
		for offset in dino_script.ring_round(half, standoff, spacing):
			if core.at_the_door(core.global_position + offset):
				at_door[k] += 1
	assert_gt(int(at_door[0]), 0, "(some of the inner ring would be in front of the door)")
	assert_eq(slots.size(), per_ring * 2 - int(at_door[0]) - int(at_door[1]),
		"%d places to stand, two rings of %d, less those at the door" % [per_ring * 2 - int(at_door[0]) - int(at_door[1]), per_ring])
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
	assert_eq(inner, per_ring - int(at_door[0]), "The whole inner ring close enough to bite from")
	assert_eq(out_of_reach, 0, "And from every one of those, it can")
	# And the corner: touching it there is touching it.
	raptor.global_position = core.global_position + Vector3(_half().x + 0.3, 0.0, _half().y + 0.3)
	assert_true(raptor._target_in_reach(core), "Standing at its corner, it can bite")

func test_06_he_gets_in_from_any_side_by_the_door() -> void:
	# From every side of it there is a way in -- round to the door, the only way in.
	var main = await _level()
	var cabin = main.current_core
	var c: Vector3 = cabin.global_position
	var inside: Vector3 = cabin.door_inside()
	for spot in [Vector3(0, 0, _half().y + 1.0), Vector3(0, 0, -_half().y - 1.0),
			Vector3(_half().x + 1.0, 0, 0), Vector3(-_half().x - 1.0, 0, 0)]:
		assert_true(main.nav_maps.is_reachable(c + spot, inside, NavMaps.For.HERO),
			"From %s he can get inside" % str(spot))

func test_07_he_can_reach_its_walls_to_repair_it() -> void:
	var main = await _level()
	var core: Node3D = main.current_core
	var route: PackedVector3Array = main.nav_maps.path(main.hero.global_position, core.global_position, true)
	assert_gt(route.size(), 0, "He has a way to it")
	if route.size() > 0:
		assert_true(main.hero._is_in_build_range(route[route.size() - 1], core),
			"Where his way to it ends, he can work on it")

func test_08_when_it_falls_every_cell_it_held_comes_free() -> void:
	var main = await _level()
	var gm = main.grid_manager
	var core = main.current_core
	var block: Array[Vector2i] = _block(main)
	core.take_damage(core.max_hp * 2.0)
	await wait_frames(2)
	for c in block:
		# Not `== core` alone: a freed object compares equal to null, so an empty cell would
		# pass for one the fallen cabin still held.
		var holder: Node = gm.building_in_build_cell(c)
		assert_false(holder != null and holder == core,
			"Cell %s is not held by a cabin that is gone" % str(c))

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
