# res://tests/test_v06_one_grid.gd
# v0.6 feedback, round two, 4: "重新设计墙，让墙体逻辑简单清晰，墙必须让它们和别的建筑能更贴合，比如bow
# tower只能离栅栏很远才能造（可能因为bow tower的建筑space太大），木栅栏成本太高，用处太小（因为要围起来需要
# 的木头太多了）石墙恐龙能穿过，不合理，木栅栏可以稍微大一点，而且人不能再穿过墙了，所有单位都不能重叠".
#
# ONE GRID. Every building stands on whole cells of the building grid (Config.BUILD_CELL) and fills
# them; a cell is taken or it is free, and that is all there is to where anything can go. A wall is
# one cell a section -- a run of them has nothing to slip between, and it stands flush against
# whatever is in the next cell. A wall stops everybody, the Hero too; his way through his own wall
# is a gate, which stops everybody else. A palisade joins what is beside it.
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
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

var _world: Node3D = null

## A grid and a bare field with a mesh over it (nav_fixture), and a BuildSystem on them.
func _field() -> Array:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, _world)
	return [gm, bs]

## `type_id` put up whole with its middle in build cell `cell`, paid for.
func _put(bs: Node, type_id: String, cell: Vector2i) -> Node:
	stock_everything()
	var b = bs.place_at(type_id, cell, _world, false)
	if b != null and not b.is_constructed:
		b.complete_construction()
	return b

func _box_of(b: Node) -> Vector3:
	for child in b.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size
	return Vector3.ZERO

# ==============================================================================
# 1. One grid, whole cells
# ==============================================================================

func test_01_everything_fills_whole_cells_of_one_grid() -> void:
	# A building fills a block of whole cells and stands at the middle of it: an odd side on its middle
	# cell, an even one -- the 2026-10-02 towers, two and four cells a side -- on the line between the two
	# middle ones (GridManager.footprint_centre). What is laid in a line is one cell; a tower is a wall's
	# multiple, square, so it stands flush in a line of wall and turning it never changes its cells.
	var cell: float = float(config_node.BUILD_CELL)
	var gm = load("res://scripts/core/GridManager.gd").new()
	for type_id in config_node.BUILDINGS:
		var size: Vector2i = config_node.get_building_size(String(type_id))
		var n: int = int(config_node.get_building_cells(String(type_id)))
		assert_almost_eq(float(config_node.get_building_footprint(String(type_id))), float(n) * cell, 0.0001,
			"%s is as wide as its cells" % type_id)
		var cells: Array[Vector2i] = gm.footprint_cells(String(type_id), Vector2i.ZERO)
		assert_eq(cells.size(), size.x * size.y, "%s takes a whole block of cells" % type_id)
		if cells.is_empty():
			continue
		var lo: Vector2i = cells[0]
		var hi: Vector2i = cells[0]
		for c in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		assert_eq(hi - lo + Vector2i.ONE, size, "%s's cells are its box, with no gap in it" % type_id)
		var middle: Vector3 = (gm.build_cell_to_world(lo) + gm.build_cell_to_world(hi)) * 0.5
		assert_true(gm.footprint_centre(String(type_id), Vector2i.ZERO).is_equal_approx(middle),
			"%s stands at the middle of its cells" % type_id)
	gm.free()
	for type_id in config_node.BUILDABLE_TYPES:
		var size: Vector2i = config_node.get_building_size(String(type_id))
		assert_eq(size.x, size.y, "What the player builds is square (%s)" % type_id)
		# A workshop out in the open stands on a tower's plot (v0.7: the kiln, the bloomery -- Workshop).
		if int(config_node.ammo_capacity(String(type_id))) <= 0 and String(config_node.get_building_kind(String(type_id))) != "workshop":
			assert_eq(size.x, 1, "What the player builds that is not a tower is one cell (%s)" % type_id)

func test_02_its_collider_is_its_cells() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	for type_id in ["wall", "stone_wall", "gate", "bow_tower"]:
		var b = _put(bs, type_id, Vector2i(0, 4 * ["wall", "stone_wall", "gate", "bow_tower"].find(type_id)))
		assert_not_null(b, "%s goes up" % type_id)
		if b == null:
			continue
		var box: Vector3 = _box_of(b)
		var fp: float = float(config_node.get_building_footprint(type_id))
		assert_almost_eq(box.x, fp, 0.001, "%s blocks exactly its cells across" % type_id)
		assert_almost_eq(box.z, fp, 0.001, "and exactly its cells deep")

func test_03_a_click_lands_in_the_cell_under_it_and_a_tile_in_its_middle() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	stock_everything()
	var at := Vector3(3.3, 0.0, -1.8)
	var b = bs.place_building("wall", gm.world_to_cell(at), _world, false, at)
	assert_not_null(b, "It goes up where he clicked")
	assert_eq(gm.world_to_build_cell(b.global_position), gm.world_to_build_cell(at), "in the cell under the click")
	var tile := Vector2i(-3, 2)
	var t = bs.place_building("bow_tower", tile, _world, false)
	assert_not_null(t, "Placed by tile")
	if t:
		# Two cells a side, it has no middle cell: it stands round the cell in the tile's middle.
		assert_almost_eq(t.global_position.distance_to(gm.footprint_centre("bow_tower", gm.tile_centre_build_cell(tile))), 0.0, 0.001,
			"it stands with the tile's middle cell as its own")
		assert_eq(gm.building_in_build_cell(gm.tile_centre_build_cell(tile)), t, "which it takes")

func test_04_a_cell_holds_one_thing() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	assert_not_null(_put(bs, "wall", Vector2i(2, 2)), "The first goes up")
	assert_null(_put(bs, "bow_tower", Vector2i(2, 2)), "and nothing else in its cell")
	assert_not_null(_put(bs, "bow_tower", Vector2i(3, 2)), "but right beside it, yes")

# ==============================================================================
# 2. Flush: nothing between a wall and what is beside it
# ==============================================================================

func test_05_a_turret_stands_flush_against_a_wall() -> void:
	# The reported case: a tower could only go up a tile away from a fence. On one grid it goes in
	# the very next cell, and their sides meet.
	var pair: Array = await _field()
	var bs = pair[1]
	var wall = _put(bs, "wall", Vector2i(0, 0))
	var tower = _put(bs, "bow_tower", Vector2i(1, 0))
	assert_not_null(tower, "A turret goes up in the next cell to a wall")
	if wall == null or tower == null:
		return
	var gap: float = absf(tower.global_position.x - wall.global_position.x) \
		- float(config_node.get_building_footprint("wall")) * 0.5 - float(config_node.get_building_footprint("bow_tower")) * 0.5
	assert_almost_eq(gap, 0.0, 0.001, "and their sides meet: nothing between them")

func test_06_a_run_of_wall_across_the_way_shuts_it_and_one_missing_cell_opens_it() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var run: Array[Node] = run_of_stakes(_world, gm, Vector3(-12.0, 0.0, 0.0), Vector3(12.0, 0.0, 0.0))
	for w in run:
		_cleanup_nodes.append(w)
	# Closed off at both ends too, so the only way across is through the line.
	for w in run_of_stakes(_world, gm, Vector3(-12.0, 0.0, 0.0), Vector3(-12.0, 0.0, -12.0)):
		_cleanup_nodes.append(w)
	for w in run_of_stakes(_world, gm, Vector3(12.0, 0.0, 0.0), Vector3(12.0, 0.0, -12.0)):
		_cleanup_nodes.append(w)
	for w in run_of_stakes(_world, gm, Vector3(-12.0, 0.0, -12.0), Vector3(12.0, 0.0, -12.0)):
		_cleanup_nodes.append(w)
	await rebake_fixture()
	var maps = maps_of()
	var inside := Vector3(0.0, 0.0, -6.0)
	var outside := Vector3(0.0, 0.0, 6.0)
	assert_false(maps.is_reachable(outside, inside, NavMaps.For.RAID), "A line of whole cells has nothing to slip between")
	# One section out: a cell-wide way in, which a raptor fits.
	var middle: Node = gm.building_at_point(Vector3(0.0, 0.0, 0.0))
	assert_not_null(middle, "There is a section in the middle of the line")
	middle.destroy()
	await rebake_fixture()
	assert_true(maps.is_reachable(outside, inside, NavMaps.For.RAID), "One cell open is a way through")

# ==============================================================================
# 3. Walls stop everybody; a gate stops everybody but him
# ==============================================================================

func test_07_a_wall_stops_the_hero_and_a_gate_does_not() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	var wall = _put(bs, "wall", Vector2i(0, 0))
	var gate = _put(bs, "gate", Vector2i(2, 0))
	assert_not_null(gate, "A gate goes up")
	var hero = load("res://scripts/entities/Hero.gd").new()
	_world.add_child(hero)
	_cleanup_nodes.append(hero)
	hero.global_position = Vector3(0.0, 0.0, 6.0)
	await wait_frames(1)
	assert_eq(int(wall.collision_layer), int(config_node.LAYER_WALL), "A wall is on the wall layer")
	assert_eq(int(gate.collision_layer), int(config_node.LAYER_GATE), "a gate on the gate layer")
	assert_ne(int(hero.collision_mask) & int(config_node.LAYER_WALL), 0, "His body is stopped by a wall")
	assert_eq(int(hero.collision_mask) & int(config_node.LAYER_GATE), 0, "and not by a gate")
	var maps = maps_of()
	assert_ne(maps._mask_for(NavMaps.For.HERO) & int(config_node.LAYER_WALL), 0, "His mesh is carved by walls")
	assert_eq(maps._mask_for(NavMaps.For.HERO) & int(config_node.LAYER_GATE), 0, "and not by gates")
	assert_ne(maps._mask_for(NavMaps.For.RAID) & int(config_node.LAYER_GATE), 0, "A raid's is carved by both")

func test_08_he_walks_through_his_gate_and_a_raid_does_not() -> void:
	# A wall right across the field with a gate in it: he has a way through, a raptor has none.
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	stock_everything()
	for x in range(-14, 15):
		if x == 0:
			continue
		var w = bs.place_at("wall", Vector2i(x, 0), _world, false)
		if w != null and not w.is_constructed:
			w.complete_construction()
	var gate = _put(bs, "gate", Vector2i(0, 0))
	assert_not_null(gate, "The gate stands in the line")
	await rebake_fixture()
	var maps = maps_of()
	var north := Vector3(0.0, 0.0, -5.0)
	var south := Vector3(0.0, 0.0, 5.0)
	# The field is 60 m and the wall 29: the raid's way round is the long way, never through.
	var raid_path: PackedVector3Array = maps.path(south, north, NavMaps.For.RAID)
	var through: bool = false
	for i in range(raid_path.size() - 1):
		if absf(raid_path[i].x) < 1.0 and signf(raid_path[i].z) != signf(raid_path[i + 1].z):
			through = true
	assert_false(through, "A raid's way does not go through the gate")
	var his: PackedVector3Array = maps.path(south, north, NavMaps.For.HERO)
	var length: float = 0.0
	for i in range(his.size() - 1):
		length += his[i].distance_to(his[i + 1])
	assert_lt(length, south.distance_to(north) + 1.0, "His goes straight through it")

func test_09_the_gate_opens_as_he_comes_up_and_shuts_behind_him() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	var gate = _put(bs, "gate", Vector2i(0, 0))
	var hero = load("res://scripts/entities/Hero.gd").new()
	_world.add_child(hero)
	_cleanup_nodes.append(hero)
	hero.set_physics_process(false)
	hero.global_position = Vector3(0.0, 0.0, 8.0)
	await wait_physics_frames(3)
	assert_false(gate.is_open(), "Shut while he is away")
	hero.global_position = Vector3(0.0, 0.0, float(config_node.GATE["open_radius"]) * 0.5)
	await wait_physics_frames(3)
	assert_true(gate.is_open(), "Open as he comes up to it")
	hero.global_position = Vector3(0.0, 0.0, 8.0)
	await wait_physics_frames(3)
	assert_false(gate.is_open(), "Shut behind him")

# ==============================================================================
# 4. A palisade joins what is beside it
# ==============================================================================

func _shown(b: Node) -> Dictionary:
	var out: Dictionary = {}
	var body: Node = b.find_child("Body", false, false)
	for run in ["Run_E", "Run_W", "Run_N", "Run_S"]:
		var part: Node = body.find_child(run, true, false) if body else null
		out[run] = part != null and (part as Node3D).visible
	return out

func test_10_a_palisade_joins_the_walls_beside_it() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	var lone = _put(bs, "wall", Vector2i(-6, -6))
	await wait_frames(2)
	var alone: Dictionary = _shown(lone)
	assert_true(alone["Run_E"] and alone["Run_W"], "Alone, it is a straight section, along the way it faces")
	assert_false(alone["Run_N"] or alone["Run_S"], "not a cross of stakes (v0.6 round three)")
	var a = _put(bs, "wall", Vector2i(0, 0))
	var b = _put(bs, "wall", Vector2i(1, 0))
	var c = _put(bs, "wall", Vector2i(2, 0))
	await wait_frames(2)
	var mid: Dictionary = _shown(b)
	assert_true(mid["Run_E"] and mid["Run_W"], "In a line, it reaches both ways along it")
	assert_false(mid["Run_N"] or mid["Run_S"], "and not across it")
	var end: Dictionary = _shown(a)
	assert_true(end["Run_E"] and end["Run_W"], "At the end of a line, it is a straight section")
	# A corner: a wall to its north as well.
	_put(bs, "wall", Vector2i(2, -1))
	await wait_frames(2)
	var corner: Dictionary = _shown(c)
	assert_true(corner["Run_W"] and corner["Run_N"], "At a corner it reaches both neighbours")
	assert_false(corner["Run_E"] or corner["Run_S"], "and nowhere else")

func test_11_a_gate_turns_across_the_line_it_stands_in() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	_put(bs, "wall", Vector2i(0, -1))
	_put(bs, "wall", Vector2i(0, 1))
	var gate = _put(bs, "gate", Vector2i(0, 0))
	await wait_frames(2)
	var body: Node3D = gate.find_child("Body", false, false) as Node3D
	assert_almost_eq(absf(body.rotation.y), PI * 0.5, 0.001, "In a wall running north to south, it turns a quarter")
	var other = _put(bs, "gate", Vector2i(5, 0))
	_put(bs, "wall", Vector2i(4, 0))
	await wait_frames(2)
	assert_almost_eq((other.find_child("Body", false, false) as Node3D).rotation.y, 0.0, 0.001, "and none in one running east to west")

# ==============================================================================
# 5. Spikes hurt what is against them, not what walks past
# ==============================================================================

func test_12_a_sharpened_wall_reaches_only_what_is_against_it() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	var wall = _put(bs, "wall", Vector2i(0, 0))
	var d = load(String(config_node.get_dino_script_path("raptor"))).new("raptor")
	_world.add_child(d)
	_cleanup_nodes.append(d)
	d.setup("raptor")
	d.set_physics_process(false)
	var half: float = float(config_node.get_visual_size("dino/raptor").x) * 0.5
	var face: float = float(config_node.get_building_footprint("wall")) * 0.5
	d.global_position = Vector3(face + half + float(config_node.CONTACT_REACH) * 0.5, 0.0, 0.0)
	assert_true(wall.touches(d), "Pressed against it, body to body: touched")
	d.global_position = Vector3(face + half + float(config_node.CONTACT_REACH) + 0.3, 0.0, 0.0)
	assert_false(wall.touches(d), "A stride off, walking past: not")

func test_13_a_metre_of_wall_is_cheaper_than_the_stakes_it_replaced() -> void:
	# "木栅栏成本太高": a ring round the cabin, a cell of wall out from it all round, priced.
	var size: Vector2i = config_node.get_building_size("core")
	var cells: int = (size.x + 2 + size.y + 2) * 2 - 4
	var per: int = int(config_node.BUILDINGS["wall"]["cost"].get("wood", 0))
	assert_gt(per, 0, "A section costs wood")
	assert_lte(cells * per, opening_wood(),
		"A ring round the cabin costs no more than the wood a run opens with (%d)" % (cells * per))
