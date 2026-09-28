# res://tests/test_v06_what_you_see_is_built.gd
# v0.6 feedback, round three, 1 and 2.
#
# "人在pending建筑的地方pending建筑就不能放了，比如我要造一排栅栏，人在中间就那人在的那一格就没法造了。
# hover pending建筑的时候，人，恐龙单位都不应该影响除非有没法建造的通路（如果人没法完成这个pending建造，
# 会被block之类的，那就提示没法建造的原因）"
#
# "栅栏建造的逻辑有问题，pending对着空地是X形状，但点下去又不是X形状了，贴着船舱建造就会变成有拐角的栅栏。
# 横着的栅栏如果想拐弯造成竖的，会没法对上，合理的效果应该是pending的样子就是造下去的样子（所有建筑都应该
# 遵循这个原则）"
#
# So: an order goes down whoever is standing there, and it is the last stroke that waits for them
# (Building.add_build_progress); he steps out of one he is standing in, the open way; an order he
# could never get to is refused, and why is said. A section of palisade joins the WALLS beside it
# and nothing else; alone, it is a straight one along the way it faces; and the ghost is dressed by
# the same code as the thing, with the sections beside it shown as they will stand.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null
var _cleanup_nodes: Array[Node] = []
var _world: Node3D = null

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

## `type_id` put up whole in build cell `cell`, facing `facing`, paid for.
func _put(bs: Node, type_id: String, cell: Vector2i, facing: int = 0) -> Node:
	stock_everything()
	var b = bs.place_at(type_id, cell, _world, false, facing)
	if b != null and not b.is_constructed:
		b.complete_construction()
	return b

func _hero_at(at: Vector3) -> Node:
	var hero = load("res://scripts/entities/Hero.gd").new()
	_world.add_child(hero)
	_cleanup_nodes.append(hero)
	hero.global_position = at
	return hero

## Which of a palisade's runs a body shows.
func _shown(b: Node) -> Dictionary:
	var out: Dictionary = {}
	var body: Node = b if String(b.name) == "Body" else b.find_child("Body", false, false)
	for run in Wall.RUNS:
		var part: Node = body.find_child(run, true, false) if body else null
		out[run] = part != null and (part as Node3D).visible
	return out

# ==============================================================================
# 1. Nobody standing there stops an order; the Hero steps out of it and builds it
# ==============================================================================

func test_01_he_steps_out_of_an_order_laid_on_him_and_builds_it() -> void:
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var spot: Vector3 = gm.build_cell_to_world(Vector2i(3, 3))
	var hero = _hero_at(spot)
	await wait_physics_frames(2)
	stock_everything()
	var order = bs.place_at("wall", Vector2i(3, 3), _world, true)
	assert_not_null(order, "The order goes down where he stands")
	hero.order_build(order, true)
	var seconds: float = order.build_time / maxf(0.01, float(hero.work_rate())) + 3.0
	for i in range(int(seconds * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if order.is_constructed:
			break
	assert_true(order.is_constructed, "He built it")
	var half_me: float = float(config_node.HERO["width"]) * 0.5
	assert_gte(float(config_node.gap_to_building(hero.global_position, "wall", order.global_position)), half_me - 0.01,
		"standing clear of it, not inside it")

func test_02_in_the_middle_of_a_row_he_steps_out_the_open_way() -> void:
	# The sections either side are up: straight out along the row is into one of them.
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	_put(bs, "wall", Vector2i(-1, 0))
	_put(bs, "wall", Vector2i(1, 0))
	var hero = _hero_at(gm.build_cell_to_world(Vector2i(0, 0)) + Vector3(0.05, 0.0, 0.0))
	await wait_physics_frames(2)
	stock_everything()
	var order = bs.place_at("wall", Vector2i(0, 0), _world, true)
	hero.order_build(order, true)
	var half_me: float = float(config_node.HERO["width"]) * 0.5
	for i in range(int(3.0 * float(Engine.physics_ticks_per_second))):
		await wait_physics_frames(1)
		if not hero._inside_of(order):
			break
	assert_false(hero._inside_of(order), "He got out of it")
	assert_gte(absf(hero.global_position.z - order.global_position.z),
		float(config_node.get_building_footprint("wall")) * 0.5 + half_me - 0.01, "across the row, the way that was open")

func test_03_an_order_he_could_never_reach_is_refused() -> void:
	# A closed ring of wall, him outside it, and its middle further in than he can reach across it.
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	var r: int = 4
	for x in range(-r, r + 1):
		for z in range(-r, r + 1):
			if absi(x) == r or absi(z) == r:
				_put(bs, "wall", Vector2i(x, z))
	await rebake_fixture()
	var hero = _hero_at(Vector3(0.0, 0.0, float(r) + 4.0))
	await wait_physics_frames(2)
	var inside: Vector3 = gm.build_cell_to_world(Vector2i.ZERO)
	var reach: float = float(config_node.TIME["build_range"]) + float(config_node.HERO["width"])
	assert_gt(float(r) - 0.5, reach, "The middle is further in than he can reach across the ring")
	assert_false(hero.can_reach_to_build("wall", inside), "He cannot get to the middle of it")
	assert_true(hero.can_reach_to_build("wall", Vector3(3.0, 0.0, float(r) + 3.0)), "but he can to open ground beside him")

# ==============================================================================
# 2. A palisade joins walls; alone, it is straight, the way it faces
# ==============================================================================

func test_04_a_lone_section_runs_the_way_it_faces() -> void:
	var pair: Array = await _field()
	var bs = pair[1]
	var along = _put(bs, "wall", Vector2i(-5, -5), 0)
	var across = _put(bs, "wall", Vector2i(5, 5), 1)
	await wait_frames(2)
	var a: Dictionary = _shown(along)
	assert_true(a["Run_E"] and a["Run_W"] and not a["Run_N"] and not a["Run_S"], "Facing north, it runs east to west")
	var b: Dictionary = _shown(across)
	assert_true(b["Run_N"] and b["Run_S"] and not b["Run_E"] and not b["Run_W"], "facing east, north to south")

func test_05_it_joins_walls_and_nothing_else() -> void:
	# "贴着船舱建造就会变成有拐角的栅栏": a trap or the cabin beside it is not a wall to join.
	var pair: Array = await _field()
	var bs = pair[1]
	_put(bs, "set_crossbow", Vector2i(0, -1))
	var section = _put(bs, "wall", Vector2i(0, 0), 0)
	await wait_frames(2)
	var shown: Dictionary = _shown(section)
	assert_false(shown["Run_N"], "It does not reach out to the trap beside it")
	assert_true(shown["Run_E"] and shown["Run_W"], "and stays the straight section it faces")
	var gate = _put(bs, "gate", Vector2i(0, 1))
	await wait_frames(2)
	assert_not_null(gate, "A gate goes up south of it")
	shown = _shown(section)
	assert_true(shown["Run_S"] and shown["Run_N"] and not shown["Run_E"], "A gate is a wall: joined, the line turned to meet it")

func test_06_turning_a_corner_meets_the_line() -> void:
	# "横着的栅栏如果想拐弯造成竖的，会没法对上": a line along X, then one down from its end.
	var pair: Array = await _field()
	var gm = pair[0]
	var bs = pair[1]
	for x in range(0, 4):
		_put(bs, "wall", Vector2i(x, 0), 0)
	for z in range(1, 4):
		_put(bs, "wall", Vector2i(3, z), 1)
	await wait_frames(2)
	var corner: Dictionary = _shown(gm.building_in_build_cell(Vector2i(3, 0)))
	assert_true(corner["Run_W"] and corner["Run_S"], "The corner reaches along both lines")
	assert_false(corner["Run_E"] or corner["Run_N"], "and past neither")
	var foot: Dictionary = _shown(gm.building_in_build_cell(Vector2i(3, 3)))
	assert_true(foot["Run_N"] and foot["Run_S"] and not foot["Run_E"], "The end of the new line is straight along it")

# ==============================================================================
# 3. The ghost is what goes up
# ==============================================================================

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(6)
	unlock_all()
	stock_everything()
	return main

## The corner of a block of open ground on the level, `size` cells a side, that the Hero can get to:
## the nearest one to the south of the cabin, as a build cell.
func _open_cell(main: Node, size: int = 6) -> Vector2i:
	var core: Vector2i = config_node.map_data()["default_core_cell"]
	var from: Vector2i = main.grid_manager.world_to_build_cell(main.grid_manager.cell_to_world(core))
	for ring in range(4, 30):
		for dx in range(-ring, ring + 1):
			var corner: Vector2i = from + Vector2i(dx, ring)
			if _block_is_open(main, corner, size):
				return corner
	assert_true(false, "Open ground near the cabin")
	return from

func _block_is_open(main: Node, corner: Vector2i, size: int) -> bool:
	for x in range(size):
		for z in range(size):
			if not main.build_system.can_place_at("wall", corner + Vector2i(x, z)):
				return false
	return main._can_reach_cell(corner)

func test_07_a_ghost_is_dressed_as_the_section_that_goes_down() -> void:
	var main = await _level()
	main.on_build_selected("wall")
	var gm = main.grid_manager
	var base: Vector2i = _open_cell(main)
	var cases: Array = [
		{"cell": base, "faces": 1, "why": "alone, turned"},
		{"cell": base + Vector2i(1, 0), "faces": 1, "why": "beside the first, turned the other way"},
		{"cell": base + Vector2i(1, 1), "faces": 0, "why": "turning the corner"},
	]
	for c in cases:
		var cell: Vector2i = c["cell"]
		var ghost: Node3D = Building.make_body("wall")
		_cleanup_nodes.append(ghost)
		main._placement_facing = int(c["faces"])
		main._dress_ghost(ghost, cell)
		var wanted: Dictionary = _shown(ghost)
		var placed = main.try_place_at_cell(gm.world_to_cell(gm.build_cell_to_world(cell)), gm.build_cell_to_world(cell))
		assert_not_null(placed, "It goes down (%s)" % c["why"])
		await wait_frames(2)
		assert_eq(_shown(placed), wanted, "and stands as its ghost showed (%s)" % c["why"])

func test_08_the_walls_beside_it_are_shown_as_they_will_stand() -> void:
	var main = await _level()
	main.on_build_selected("wall")
	var gm = main.grid_manager
	var base: Vector2i = _open_cell(main)
	var standing = main.try_place_at_cell(gm.world_to_cell(gm.build_cell_to_world(base)), gm.build_cell_to_world(base))
	assert_not_null(standing, "A lone section goes down, running east to west")
	await wait_frames(2)
	var before: Dictionary = _shown(standing)
	assert_true(before["Run_E"] and not before["Run_S"], "east to west, on its own")

	var below: Vector2i = base + Vector2i(0, 1)
	main._preview_neighbours([below])
	var previewed: Dictionary = _shown(standing)
	assert_true(previewed["Run_S"] and previewed["Run_N"] and not previewed["Run_E"],
		"With a ghost south of it, it is shown as the end of a north-south line")
	main._restore_neighbours()
	assert_eq(_shown(standing), before, "Taken away, it is put back")

	main._preview_neighbours([below])
	main._restore_neighbours()
	var placed = main.try_place_at_cell(gm.world_to_cell(gm.build_cell_to_world(below)), gm.build_cell_to_world(below))
	assert_not_null(placed, "The section goes down")
	await wait_frames(2)
	assert_eq(_shown(standing), previewed, "and the one beside it stands as it was shown")

func test_09_a_dragged_run_faces_along_the_drag() -> void:
	var main = await _level()
	main.on_build_selected("wall")
	var gm = main.grid_manager
	var base: Vector2i = _open_cell(main)
	# A run with a gap in it: the lone section left over faces the way the run does.
	var cells: Array[Vector2i] = [base, base + Vector2i(0, 2), base + Vector2i(0, 3)]
	for c in cells:
		assert_true(main.build_system.can_place_at("wall", c), "Open ground at %s" % c)
	var ghost: Node3D = Building.make_body("wall")
	_cleanup_nodes.append(ghost)
	main._dress_ghost(ghost, base, cells, 1)
	var wanted: Dictionary = _shown(ghost)
	assert_true(wanted["Run_N"] and wanted["Run_S"], "The lone ghost of a north-south run runs north to south")
	assert_eq(main._commit_run(cells, 1), cells.size(), "The run goes down")
	await wait_frames(2)
	assert_eq(_shown(gm.building_in_build_cell(base)), wanted, "and its lone section stands as its ghost did")

func test_10_r_turns_a_section_in_hand() -> void:
	var main = await _level()
	main.on_build_selected("wall")
	assert_true(main._turns("wall"), "A wall in hand turns")
	assert_true(main._turns("gate"), "a gate too")
	var was: int = main._placement_facing
	main.turn_placement(1)
	assert_eq(main._placement_facing, posmod(was + 1, Trap.FACINGS.size()), "a quarter at a press")
	assert_false(main._turns("workbench"), "A workbench faces no way that matters")

func test_11_the_reasons_are_in_the_string_table() -> void:
	for key in ["STATUS_WAITING_CLEAR", "HINT_UNREACHABLE", "HINT_WALL_TURN"]:
		assert_ne(tr(key), key, "%s is written down" % key)
