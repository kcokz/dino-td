# res://tests/test_v05_nobody_gets_walled_in.gd
# You cannot build on top of a person, and a person inside a building gets out.
#
# Reported as "人是完全不动了" -- standing still with a route plainly available. It was
# not pathfinding, and measuring it is what showed that: the Hero reported state MOVING
# and velocity 4.0 while covering 0.13m in eight seconds. He was walking on the spot.
#
# A stake had been built INSIDE HIM. A finished building is a static body, and a body
# already overlapping one cannot be pushed out by move_and_collide -- so he pressed
# against it at full speed for ever, with a perfectly good path in hand. No amount of
# replanning helps, because the route was never the problem.
#
# It became easy to do by accident in v0.5: a stake is 0.62m wide and snaps to a third
# of a tile, so "just beside me" and "on me" are about half a metre apart.
#
# Two fixes, because one of them is a rule and the other is a net:
#   * placement REFUSES to put a building where somebody is standing;
#   * a Hero who ends up inside one anyway is pushed clear.
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

func _rig() -> Array:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	var bs = load("res://scripts/core/BuildSystem.gd").new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, gm)
	return [gm, bs]

func _hero_at(at: Vector3) -> Node:
	var h = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(h)
	tree.root.add_child(h)
	h.global_position = at
	return h

func _divisions() -> int:
	return int(config_node.get_cell_divisions("wall"))

# ==============================================================================
# 1. Nobody is built on top of
# ==============================================================================

func test_01_a_stake_cannot_be_placed_on_the_hero() -> void:
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)
	var spot: Vector3 = gm.cell_to_world(Vector2i(3, 3))
	var hero = _hero_at(spot)
	await wait_frames(1)

	assert_false(bs.can_place_building("wall", gm.world_to_cell(spot), false, spot),
		"A stake may not be driven through the man standing there")
	assert_null(bs.place_building("wall", gm.world_to_cell(spot), gm, false, spot),
		"And asking anyway gets nothing")

func test_02_the_check_is_about_where_it_would_LAND() -> void:
	# A stake snaps to a fine cell, so the click and the stake are up to half a cell
	# apart. Checking the click let one land on the Hero anyway -- which is how this bug
	# survived its first fix.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)
	var d: int = _divisions()
	var fine := Vector2i(9, 9)
	var lands_at: Vector3 = gm.fine_cell_to_world(fine, d)
	# Stand him ON the fine cell's centre, then click slightly off it.
	var hero = _hero_at(lands_at)
	await wait_frames(1)
	var clicked: Vector3 = lands_at + Vector3(0.3, 0.0, 0.0)

	assert_eq(gm.world_to_fine_cell(clicked, d), fine, "The click still snaps to that cell")
	assert_false(bs.can_place_building("wall", gm.world_to_cell(clicked), false, clicked),
		"So it is refused, because of where it would END UP rather than where the cursor was")

func test_03_a_dinosaur_cannot_be_built_on_either() -> void:
	# The same trap, sprung on something that cannot complain.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)
	var spot: Vector3 = gm.cell_to_world(Vector2i(5, 5))
	var dino = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	dino.global_position = spot
	await wait_frames(1)

	assert_false(bs.can_place_building("wall", gm.world_to_cell(spot), false, spot),
		"Nor through a dinosaur")

func test_04_open_ground_a_step_away_is_still_buildable() -> void:
	# The rule must not be so wide that the player cannot lay a fence near himself.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)
	var hero = _hero_at(gm.cell_to_world(Vector2i(0, 0)))
	await wait_frames(1)

	var away: Vector3 = gm.cell_to_world(Vector2i(2, 0))
	assert_gt(hero.global_position.distance_to(away), 1.0, "Two tiles off is not on top of him")
	assert_true(bs.can_place_building("wall", gm.world_to_cell(away), false, away),
		"And is perfectly buildable")

# ==============================================================================
# 2. And anyone already inside one gets out
# ==============================================================================

func test_05_a_hero_inside_a_finished_building_is_pushed_clear() -> void:
	# The net under the rule. A building can finish while he stands next to it, and
	# "should never happen" is what the first version of this was too.
	var rig := _rig()
	var gm = rig[0]
	await wait_frames(1)
	var spot: Vector3 = gm.cell_to_world(Vector2i(4, 4))
	var hero = _hero_at(spot)

	var stake = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(stake)
	tree.root.add_child(stake)
	stake.setup("wall", gm.world_to_cell(spot))
	stake.global_position = spot
	stake.complete_construction()
	gm.occupy_cell(gm.world_to_cell(spot), stake)
	await wait_frames(1)

	assert_lt(hero.global_position.distance_to(stake.global_position), 0.1,
		"He is standing inside it to begin with")
	assert_true(hero._push_out_of_anything_solid(), "Which is noticed")

	var clearance: float = (float(config_node.HERO.get("width", 0.8))
		+ float(config_node.get_building_footprint("wall"))) * 0.5
	assert_gte(hero.global_position.distance_to(stake.global_position), clearance,
		"And he ends up clear of it rather than inside it")

func test_06_and_a_blueprint_never_traps_anyone() -> void:
	# Unfinished work is not solid, so there is nothing to be pushed out of -- and being
	# shoved around by something that is not there yet would be its own bug.
	var rig := _rig()
	var gm = rig[0]
	await wait_frames(1)
	var spot: Vector3 = gm.cell_to_world(Vector2i(6, 6))
	var hero = _hero_at(spot)

	var stake = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(stake)
	tree.root.add_child(stake)
	stake.setup("wall", gm.world_to_cell(spot))
	stake.global_position = spot
	stake.start_construction(5.0)
	gm.occupy_cell(gm.world_to_cell(spot), stake)
	await wait_frames(1)

	assert_false(stake.is_constructed, "It is only ordered")
	assert_false(hero._push_out_of_anything_solid(), "So he is left exactly where he is")
	assert_lt(hero.global_position.distance_to(spot), 0.01, "Not moved at all")

# ==============================================================================
# 3. All buildings means all of them
# ==============================================================================

func test_07_the_grid_reports_every_stake_not_one_per_tile() -> void:
	# occupied_cells holds ONE building per tile. Everything that asks the grid "what is
	# on the map" was getting a fraction of a fence -- including the Hero's build queue,
	# which is why blueprints sharing a tile with something already up sat at 0%.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	var made: Array[Node] = []
	for i in range(d):
		var at: Vector3 = gm.fine_cell_to_world(Vector2i(i, 0), d)
		var b = bs.place_building("wall", gm.world_to_cell(at), gm, false, at)
		if b != null:
			_cleanup_nodes.append(b)
			made.append(b)
	await wait_frames(1)

	assert_eq(made.size(), d, "A full row of stakes went up in one tile")
	var listed: Array = gm.get_all_buildings()
	for b in made:
		assert_true(listed.has(b), "Every one of them is on the map as far as the grid is concerned")
	assert_gte(listed.size(), d, "All %d, not the one that happens to hold the tile" % d)
