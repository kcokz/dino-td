# res://tests/test_v04_gap_beside_a_stake.gd
# A gap you can see is a gap you can walk through.
#
# The report: "圆锥和丘陵之间明显有缝隙的情况下，人就没法走过去了." A stake beside a
# hillside, plainly a stride of clear ground between them, and the Hero would not go.
#
# Two separate things were saying no, and both were the same mistake -- A STAKE WAS
# DECLARED THE SIZE OF ITS TILE RATHER THAN THE SIZE OF THE STAKE:
#
#   * its collider was a 2m box for a 0.62m cone, so he was held off by something
#     nobody could see;
#   * the grid marked the whole 2m tile occupied the moment the first stake landed in
#     it, so pathing would not even try.
#
# What closes a way now is a RUN of stakes wide enough to cross a tile, which is the
# thing the player can see is a fence. One stake is something to walk round.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var grid_script: GDScript = null
var build_script: GDScript = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")
	grid_script = load("res://scripts/core/GridManager.gd")
	build_script = load("res://scripts/core/BuildSystem.gd")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 500

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _rig(blocked: Array = []) -> Array:
	var gm = grid_script.new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	var bs = build_script.new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, gm)
	return [gm, bs]

func _divisions() -> int:
	return int(config_node.get_cell_divisions("wall"))

func _step() -> float:
	return float(config_node.TILE_SIZE) / float(_divisions())

## A stake at the fine cell (fx, fz), placed the way the player places one.
func _stake(gm: Node, bs: Node, fx: int, fz: int) -> Node:
	var step: float = _step()
	var at := Vector3((float(fx) + 0.5) * step, 0.0, (float(fz) + 0.5) * step)
	var s = bs.place_building("wall", gm.world_to_cell(at), gm, false, at)
	if s != null:
		_cleanup_nodes.append(s)
	return s

# ==============================================================================
# 1. The stake is the size of the stake
# ==============================================================================

func test_01_the_box_that_stops_you_is_the_cone_you_can_see() -> void:
	# The invisible half of the bug. Even once pathing agreed to route through the gap,
	# a 2m collider on a 0.62m cone would have bounced him out of it.
	var wall = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.setup("wall", Vector2i(0, 0))
	await wait_frames(1)

	var shape: CollisionShape3D = null
	for child in wall.get_children():
		if child is CollisionShape3D:
			shape = child
			break
	assert_not_null(shape, "A stake has a collider")
	var cone: float = float(config_node.get_spike_diameter("wall"))
	assert_almost_eq(shape.shape.size.x, cone, 0.001, "As wide as the cone")
	assert_almost_eq(shape.shape.size.z, cone, 0.001, "On both axes")
	assert_lt(shape.shape.size.x, float(config_node.TILE_SIZE) * 0.5,
		"Which is nowhere near the tile it stands in")

func test_02_one_number_decides_how_big_a_stake_is() -> void:
	# There were two -- `footprint` at 2.0 and `spike_diameter` at 0.62 -- and a number
	# that can disagree with the art is a number that eventually will.
	assert_almost_eq(float(config_node.get_building_footprint("wall")),
		float(config_node.get_spike_diameter("wall")), 0.001,
		"The ground a stake claims is the cone that is drawn")
	assert_almost_eq(float(config_node.get_building_thickness("wall")),
		float(config_node.get_spike_diameter("wall")), 0.001,
		"And so is how deep the fence line is")
	assert_false(config_node.BUILDINGS["wall"].has("footprint"),
		"With nothing left in Config for either of them to disagree with")

# ==============================================================================
# 2. The reported case: a stake next to a hillside
# ==============================================================================

func test_03_a_stake_beside_a_hill_leaves_the_way_open() -> void:
	# Exactly what was reported. Tile (0,0) holds ONE stake, tile (1,0) is hillside,
	# and the ground between them is clear -- so it has to be walkable.
	var rig := _rig([Vector2i(1, 0)])
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	assert_false(gm.is_cell_walkable(Vector2i(1, 0)), "The hill is not walkable, as ever")
	var stake = _stake(gm, bs, 0, 0)
	assert_not_null(stake, "A stake goes in beside it")
	await wait_frames(1)

	assert_true(gm.is_cell_occupied(Vector2i(0, 0)), "It claims the tile it stands in")
	assert_true(gm.is_cell_walkable(Vector2i(0, 0)),
		"But the rest of that tile is open ground, which is what the player was looking at")

func test_04_he_is_sent_through_the_gap_rather_than_refused() -> void:
	# The symptom, rather than the rule: click past the stake and a route comes back.
	var rig := _rig([Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)])
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)
	_stake(gm, bs, 0, 3)
	await wait_frames(1)

	var from_pos: Vector3 = gm.cell_to_world(Vector2i(0, 0))
	var to_pos: Vector3 = gm.cell_to_world(Vector2i(0, 3))
	assert_true(gm.is_reachable(from_pos, to_pos), "There is a way past the stake")
	var path: Array = gm.find_path(from_pos, to_pos)
	assert_gt(path.size(), 0, "And a route is handed back")
	assert_lt(path[path.size() - 1].distance_to(to_pos), float(config_node.TILE_SIZE),
		"That ends where he was sent, not short of it")

func test_05_the_waypoint_is_not_the_stake_itself() -> void:
	# A tile that is walkable-with-something-in-it must not be aimed at dead centre when
	# that is where the something is standing, or he grinds against a cone he had room
	# to step around.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	var middle: int = d / 2
	var stake = _stake(gm, bs, middle, middle)
	assert_not_null(stake, "A stake stands in the middle of tile (0,0)")
	await wait_frames(1)

	var aim: Vector3 = gm.walkable_point_in_cell(Vector2i(0, 0))
	assert_gt(aim.distance_to(stake.global_position), float(config_node.get_spike_diameter("wall")) * 0.5,
		"What he is aimed at is clear of the stake")
	assert_eq(gm.world_to_cell(aim), Vector2i(0, 0), "And still inside the tile he is crossing")

# ==============================================================================
# 3. And a fence is still a fence
# ==============================================================================

func test_06_a_run_of_stakes_across_the_tile_closes_it() -> void:
	# The other half. Giving the player his gap back must not cost him the fence: a run
	# of cones with nothing between them is what stops people, and it still does.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	for i in range(d):
		assert_not_null(_stake(gm, bs, i, 0), "Stake %d of the run goes in" % i)
	await wait_frames(1)

	assert_false(gm.occupant_leaves_a_way_through(Vector2i(0, 0)),
		"A complete row is a fence crossing the tile")
	assert_false(gm.is_cell_walkable(Vector2i(0, 0)), "So nobody walks through it")

func test_07_a_run_one_short_is_a_gap() -> void:
	# The line the rule draws, from the other side. Leave one out and it is a gate --
	# which is the player's decision to make, and now it is one he can make.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	for i in range(d - 1):
		_stake(gm, bs, i, 0)
	await wait_frames(1)

	assert_true(gm.occupant_leaves_a_way_through(Vector2i(0, 0)), "One short of a full row")
	assert_true(gm.is_cell_walkable(Vector2i(0, 0)), "Is a gate rather than a wall")

func test_08_a_column_of_stakes_closes_it_too() -> void:
	# A fence running the other way is still a fence. Rows and columns both, or a fence
	# drawn north-south would be scenery.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	for i in range(d):
		_stake(gm, bs, 0, i)
	await wait_frames(1)

	assert_false(gm.is_cell_walkable(Vector2i(0, 0)), "A column closes the tile as a row does")

func test_09_a_building_registered_at_tile_level_still_fills_its_tile() -> void:
	# The trap in the new rule, nailed down. "No fine cells occupied" must mean "nothing
	# finer is on record", never "there must be a way through" -- otherwise every turret,
	# every piece of the wreck, and every wall put down by a test opens a hole in the map.
	var rig := _rig()
	var gm = rig[0]
	await wait_frames(1)

	var tower = load("res://scripts/entities/Tower.gd").new()
	_cleanup_nodes.append(tower)
	tree.root.add_child(tower)
	tower.setup("tower", Vector2i(4, 4))
	tower.complete_construction()
	gm.occupy_cell(Vector2i(4, 4), tower)
	await wait_frames(1)
	assert_false(gm.is_cell_walkable(Vector2i(4, 4)), "A turret fills the tile it is in")

	var wall = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(wall)
	tree.root.add_child(wall)
	wall.setup("wall", Vector2i(5, 5))
	wall.complete_construction()
	gm.occupy_cell(Vector2i(5, 5), wall)
	await wait_frames(1)
	assert_false(gm.is_cell_walkable(Vector2i(5, 5)),
		"And so does a stake nobody told the fine grid about")

# ==============================================================================
# 4. What the dinosaurs make of it
# ==============================================================================

func test_10_a_raid_walks_through_a_gate_and_chews_a_sealed_fence() -> void:
	# The rule from test_v04_wall_blocking, now that "sealed" means what it looks like.
	# A fence with a stake missing is walked through; the same fence completed is bitten.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	var tile_size: float = float(config_node.TILE_SIZE)
	# A wall of stakes right across tile row 0, but with the last one left out.
	for tile_x in range(-1, 2):
		for i in range(d):
			if tile_x == 0 and i == d - 1:
				continue
			_stake(gm, bs, tile_x * d + i, 0)
	await wait_frames(1)

	var from_pos := Vector3(tile_size * 0.5, 0.0, tile_size * 2.5)
	var to_pos := Vector3(tile_size * 0.5, 0.0, -tile_size * 2.5)
	assert_true(gm.is_reachable(from_pos, to_pos), "The gate is a way through")

	_stake(gm, bs, d - 1, 0)
	await wait_frames(1)
	assert_false(gm.is_cell_walkable(Vector2i(0, 0)), "Closing the gate seals that tile")
