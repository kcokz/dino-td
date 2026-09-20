# res://tests/test_v04_wall_blocking.gd
# A wall is a wall: dinosaurs go round it if they can, and bite it if they cannot.
#
# The rule, in the words it was asked for: "wall 类型需要能 block 通路的能力，恐龙进攻
# 优先级低于建筑，高于人，所以一旦路 block 了，恐龙才会攻击 wall，不然就会绕过去."
#
# It overturns a v0.4 decision that had it backwards. Dinosaurs used to ignore buildings
# when routing, on the theory that politely going round a fence made the fence
# pointless. The opposite is true:
#
#   * a fence that can be walked round FUNNELS the raid, so where the player puts it
#     finally decides something;
#   * a fence that seals the way is the thing the raid has to chew through.
#
# Before this every fence was the second kind whether the player wanted it or not, and
# a raid that met one with a gap in it would stand there eating the gatepost.
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

## The fixture, which since v0.5 has a NAVIGATION MESH over it. "Is the way sealed" is
## answered by a bake now, and a bake is made of colliders, so a grid holding nothing but
## cell data answers "the way is open" to everything.
func _grid(blocked: Array = []) -> Node:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	_world = await nav_fixture()
	_cleanup_nodes.append(_world)
	for c in blocked:
		if c is Vector2i:
			block_out_a_hill(_world, gm, c)
	await rebake_fixture()
	return gm

func _wall_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_world.add_child(w)
	w.setup("wall", cell)
	w.position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

func _tower_at(gm: Node, cell: Vector2i) -> Node:
	var t = load("res://scripts/entities/Tower.gd").new()
	_world.add_child(t)
	t.setup("tower", cell)
	t.position = gm.cell_to_world(cell)
	t.complete_construction()
	gm.occupy_cell(cell, t)
	return t

func _dino_at(gm: Node, cell: Vector2i, goal_cell: Vector2i) -> Node:
	var d = load("res://scripts/entities/Dino.gd").new()
	_cleanup_nodes.append(d)
	tree.root.add_child(d)
	d.setup("raptor")
	d.global_position = gm.cell_to_world(cell)
	d.set_waypoints([gm.cell_to_world(goal_cell)])
	return d

## A fence all the way round `centre`, so whatever is inside it really is sealed off.
##
## Laid as four RUNS of stakes on the fine grid rather than one stake per tile. Eight
## cones at tile spacing leave 1.38m of open ground between them, which seals nothing and
## which the mesh says so about -- see test_base.run_of_stakes.
func _enclose(gm: Node, centre: Vector2i, radius: int = 1) -> void:
	var half: float = float(gm.tile_size) * (float(radius) + 0.5)
	var mid: Vector3 = gm.cell_to_world(centre)
	var corners: Array[Vector3] = [
		mid + Vector3(-half, 0.0, -half), mid + Vector3(half, 0.0, -half),
		mid + Vector3(half, 0.0, half), mid + Vector3(-half, 0.0, half)]
	for i in range(4):
		for w in run_of_stakes(_world, gm, corners[i], corners[(i + 1) % 4]):
			_cleanup_nodes.append(w)
	await rebake_fixture()

# ==============================================================================
# 1. Which things are walls
# ==============================================================================

func test_01_wall_is_a_kind_not_a_single_building() -> void:
	# The rule is written against a CATEGORY, so anything declared kind "wall" obeys it
	# -- stakes today, whatever palisade or barricade comes later without a code change.
	assert_eq(String(config_node.BUILDINGS["wall"]["kind"]), "wall", "Stakes are of kind wall")
	assert_ne(String(config_node.BUILDINGS["tower"]["kind"]), "wall", "A turret is not")
	assert_ne(String(config_node.BUILDINGS["core"]["kind"]), "wall", "Nor is the wreck")

func test_02_a_dinosaur_can_tell_a_wall_from_anything_else() -> void:
	var gm = await _grid([])
	await wait_frames(1)
	var d = _dino_at(gm, Vector2i(0, 5), Vector2i(0, -5))
	var stake = _wall_at(gm, Vector2i(0, 0))
	var turret = _tower_at(gm, Vector2i(3, 0))
	await wait_frames(1)

	assert_true(d._is_wall(stake), "A stake is a wall")
	assert_false(d._is_wall(turret), "A turret is not")
	assert_false(d._is_wall(null), "And nothing is not")

# ==============================================================================
# 2. Round it if you can
# ==============================================================================

func test_03_a_fence_with_a_way_round_is_not_worth_biting() -> void:
	# The reported bug, as a rule. A line of stakes with open ground past the end of it
	# is something to walk round, and a dinosaur that stops to eat it is wrong.
	var gm = await _grid([])
	await wait_frames(1)
	var d = _dino_at(gm, Vector2i(0, 4), Vector2i(0, -4))
	for x in range(-3, 4):
		_wall_at(gm, Vector2i(x, 0))
	await wait_frames(1)

	var stake = gm.get_building_at(Vector2i(0, 0))
	assert_not_null(stake, "There is a fence in the way")
	assert_false(d._way_is_sealed(), "But the ground past its end is open")
	assert_false(d._should_bite(stake), "So the fence is walked round, not eaten")

func test_04_a_turret_is_attacked_whether_or_not_it_blocks() -> void:
	# The other half of the rule. Only WALLS are judged by whether they are in the way;
	# a turret is a target on its own merits, because it is shooting back.
	var gm = await _grid([])
	await wait_frames(1)
	var d = _dino_at(gm, Vector2i(0, 4), Vector2i(0, -4))
	var turret = _tower_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	assert_false(d._way_is_sealed(), "There is plenty of room round it")
	assert_true(d._should_bite(turret), "A turret is still worth attacking")

# ==============================================================================
# 3. Bite it if you cannot
# ==============================================================================

func test_05_a_sealed_way_makes_the_wall_the_target() -> void:
	# Wall the goal in completely and the fence stops being scenery: it becomes the
	# thing standing between the raid and what it came for.
	var gm = await _grid([])
	await wait_frames(1)
	var goal := Vector2i(0, -4)
	await _enclose(gm, goal, 1)
	var d = _dino_at(gm, Vector2i(0, 4), goal)
	await wait_frames(1)

	assert_true(d._way_is_sealed(), "There is no way in")
	var blocker = d._building_in_the_way()
	assert_not_null(blocker, "So something is named as the thing in the way")
	assert_true(d._is_wall(blocker), "And it is one of the stakes")
	assert_true(d._should_bite(blocker), "Which is now worth biting")

func test_06_a_dinosaur_that_is_blocked_never_just_stands_there() -> void:
	# The symptom this began as: neither moving nor attacking. Whatever else happens, a
	# dinosaur facing a sealed way has to come out of the decision DOING one of them.
	#
	# It used to have to be attacking on the spot, which was wrong in its own way: the
	# fence here is sixteen metres off, and biting something you are nowhere near is the
	# same standing still by another name.
	var gm = await _grid([])
	await wait_frames(1)
	var goal := Vector2i(0, -4)
	await _enclose(gm, goal, 1)
	var d = _dino_at(gm, Vector2i(0, 4), goal)
	await wait_frames(1)

	var was_at: Vector3 = d.global_position
	d.advance_towards_waypoint(0.05)
	assert_not_null(d.current_target, "It commits to something")
	assert_true(d._is_target_valid(d.current_target), "And that something is real")
	assert_true(d._is_wall(d.current_target), "Which is the fence in its way")
	assert_gt(was_at.distance_to(d.global_position), 0.0, "And it is moving towards it")

func test_06b_it_bites_once_it_gets_there() -> void:
	# The other end of the same walk. Put it against the fence and it stops walking and
	# starts eating, because now there is something in reach worth eating.
	var gm = await _grid([])
	await wait_frames(1)
	var goal := Vector2i(0, -4)
	await _enclose(gm, goal, 1)
	# Right up against the northern face of the ring, where the next stake is in reach.
	#
	# Placed from the dinosaur's OWN reach rather than a guessed 1.5m. Reach is the
	# attacker's body plus its strike plus the target's since v0.5, and for a raptor
	# against a 0.62m stake that is about a metre -- 1.5m used to be "against it" and is
	# now well clear.
	#
	# Placed off the STAKE rather than off a cell, because the two are barely compatible
	# now: a stake sits at its cell's centre, the next cell starts 1.0m away, and a
	# raptor's reach against it is 1.06m. Standing in the next cell and being able to bite
	# is a six-centimetre window.
	var d = _dino_at(gm, Vector2i(0, -7), goal)
	var near = gm.get_building_at(Vector2i(0, -5))
	assert_not_null(near, "There is a stake on the northern face")
	var bite: float = d.attack_reach() + float(config_node.get_building_footprint("wall")) * 0.5
	d.global_position = near.global_position + Vector3(0.0, 0.0, -bite * 0.95)
	d._route_checked_at = -999.0
	await wait_frames(1)
	assert_true(d._way_is_sealed(), "The goal is walled in")

	d.advance_towards_waypoint(0.05)
	assert_eq(int(d.current_state), int(d.State.ATTACKING), "In reach, so it commits to biting")
	assert_true(d._is_wall(d.current_target), "The stake in the way")

func test_07_the_way_opening_lets_the_dinosaur_go() -> void:
	# Chewing through one stake, or the player demolishing one, has to release it. The
	# alternative is a dinosaur that eats an entire fence it no longer needs to.
	var gm = await _grid([])
	await wait_frames(1)
	var goal := Vector2i(0, -4)
	await _enclose(gm, goal, 1)
	var d = _dino_at(gm, Vector2i(0, 4), goal)
	await wait_frames(1)
	assert_true(d._way_is_sealed(), "Sealed to begin with")

	# Knock a hole in it, and give the cache its moment to notice.
	#
	# A HOLE HAS TO BE WIDER THAN WHAT GOES THROUGH IT, which is a consequence of the
	# finer grid worth stating: stakes stand 0.67m apart, so taking one out leaves a gap
	# narrower than a raptor and the fence still holds. It takes a few. That is also why
	# a fence is worth repairing -- one chewed stake does not open it.
	var near_side: float = gm.cell_to_world(goal).z + float(gm.tile_size) * 1.5
	var holed: int = 0
	for w in _world.get_children():
		if not ("building_type" in w) or String(w.building_type) != "wall":
			continue
		if absf((w as Node3D).global_position.z - near_side) > 0.4:
			continue
		if absf((w as Node3D).global_position.x - gm.cell_to_world(goal).x) > 1.2:
			continue
		w.destroy()
		holed += 1
	assert_gt(holed, 1, "A gap was opened in the near side, wide enough to walk through")
	await wait_seconds(float(d.ROUTE_RECHECK_SECONDS) + 0.1)
	await rebake_fixture()

	assert_false(d._way_is_sealed(), "A hole in the fence is a way in")
	assert_null(d._building_in_the_way(), "So nothing is in the way any more")

# ==============================================================================
# 4. The road being built on
# ==============================================================================

func test_08_a_waypoint_buried_in_a_building_is_skipped() -> void:
	# What a wall across the road used to do: the route runs down the path column, a
	# stake lands on a waypoint, and the whole raid walks to the near side of it and
	# stops -- not attacking, because there was a way round, and not moving, because
	# where it was told to go is inside a building.
	var gm = await _grid([])
	await wait_frames(1)
	var d = _dino_at(gm, Vector2i(0, 4), Vector2i(0, -4))
	d.set_waypoints([
		gm.cell_to_world(Vector2i(0, 2)),
		gm.cell_to_world(Vector2i(0, 0)),
		gm.cell_to_world(Vector2i(0, -4)),
	])
	_wall_at(gm, Vector2i(0, 2))     # the first waypoint is now inside a stake
	await wait_frames(1)

	d.current_waypoint_index = 0
	d._skip_unwalkable_waypoints()
	assert_gt(d.current_waypoint_index, 0, "It does not aim at a spot inside a building")
	assert_true(gm.is_cell_walkable(gm.world_to_cell(d.waypoints[d.current_waypoint_index])),
		"The one it aims at instead can actually be stood on")

func test_09_the_last_waypoint_is_never_skipped() -> void:
	# The destination is the destination. If the player has walled the core in, that
	# wall is exactly what the raid should be chewing -- and it will be, because the way
	# really is sealed.
	var gm = await _grid([])
	await wait_frames(1)
	var d = _dino_at(gm, Vector2i(0, 4), Vector2i(0, -4))
	_wall_at(gm, Vector2i(0, -4))
	await wait_frames(1)

	d.current_waypoint_index = 0
	d._skip_unwalkable_waypoints()
	assert_eq(d.current_waypoint_index, 0, "It keeps heading for where it was going")
	assert_eq(d.waypoints.size(), 1, "Which was the only waypoint it had")
