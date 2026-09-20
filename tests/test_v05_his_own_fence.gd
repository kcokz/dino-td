# res://tests/test_v05_his_own_fence.gd
# The Hero walks through his own fence. Nothing else does.
#
# Fences began sealing properly in v0.5, and they sealed against everybody -- including
# the man who built them, in a game with no gate in it. Laying stakes around your own
# camp shut you out of it, and the only way back in was to demolish your own work.
#
# So a wall is on a layer of its own (Config.LAYER_WALL), which the Hero's collision mask
# leaves out and nothing else does, and his pathfinding asks with `walls_are_open`. Both
# halves are needed and neither is sufficient: physics without routing sends him the long
# way round something he could have walked through, and routing without physics walks him
# into it.
#
# WHAT THIS MUST NOT COST: a fence is still a fence. A dinosaur sees no difference at
# all, which is the entire reason to build one.
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

func _grid(blocked: Array = []) -> Node:
	var gm = load("res://scripts/core/GridManager.gd").new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	gm.set_blocked_cells(blocked)
	return gm

func _wall_at(gm: Node, cell: Vector2i) -> Node:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", cell)
	w.global_position = gm.cell_to_world(cell)
	w.complete_construction()
	gm.occupy_cell(cell, w)
	return w

func _tower_at(gm: Node, cell: Vector2i) -> Node:
	var t = load("res://scripts/entities/Tower.gd").new()
	_cleanup_nodes.append(t)
	tree.root.add_child(t)
	t.setup("tower", cell)
	t.global_position = gm.cell_to_world(cell)
	t.complete_construction()
	gm.occupy_cell(cell, t)
	return t

## Stakes all the way round `centre`, which is the only shape that actually seals: the
## grid is unbounded, so a fence in a line always has ends to walk round.
func _fence_around(gm: Node, centre: Vector2i) -> void:
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx != 0 or dz != 0:
				_wall_at(gm, centre + Vector2i(dx, dz))

# ==============================================================================
# 1. A wall is not an ordinary building
# ==============================================================================

func test_01_a_finished_wall_sits_on_its_own_layer() -> void:
	var gm = _grid([])
	await wait_frames(1)
	var wall = _wall_at(gm, Vector2i(0, 0))
	var tower = _tower_at(gm, Vector2i(4, 0))
	await wait_frames(1)

	assert_eq(wall.collision_layer, int(config_node.LAYER_WALL), "A stake is on the wall layer")
	assert_eq(tower.collision_layer, 2, "A turret is an ordinary building")
	assert_eq(int(config_node.LAYER_WALL) & 2, 0, "And the two layers are different")

func test_02_the_heros_mask_leaves_out_that_layer_and_only_that_one() -> void:
	var hero = load("res://scripts/entities/Hero.gd").new()
	_cleanup_nodes.append(hero)
	tree.root.add_child(hero)
	await wait_frames(1)

	assert_eq(hero.collision_mask & int(config_node.LAYER_WALL), 0, "His own fence does not stop him")
	assert_ne(hero.collision_mask & 2, 0, "The wreck and the turrets still do")
	assert_ne(hero.collision_mask & 1, 0, "And so does the landscape")

func test_03_a_dinosaur_still_rays_against_walls() -> void:
	# The half that must not be lost. A fence a raid can ignore is not a fence.
	var gm = _grid([])
	await wait_frames(1)
	var dino = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	await wait_frames(2)

	assert_not_null(dino.raycast, "It has its forward ray")
	assert_ne(dino.raycast.collision_mask & int(config_node.LAYER_WALL), 0,
		"Which sees walls")
	assert_ne(dino.raycast.collision_mask & 2, 0, "And everything else it always saw")

# ==============================================================================
# 2. And his route agrees with the physics
# ==============================================================================

func test_04_a_walled_tile_is_open_ground_to_him_and_solid_to_everyone_else() -> void:
	var gm = _grid([])
	await wait_frames(1)
	_wall_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	assert_true(gm.is_cell_walkable(Vector2i(0, 0), null, false, true),
		"Open ground, asked the way the Hero asks")
	assert_false(gm.is_cell_walkable(Vector2i(0, 0)),
		"Solid, asked the way everyone else does")

func test_05_a_turret_is_solid_to_him_too() -> void:
	# `walls_are_open` opens WALLS. Opening every building would let him walk through
	# the wreck, which is a different game.
	var gm = _grid([])
	await wait_frames(1)
	_tower_at(gm, Vector2i(0, 0))
	await wait_frames(1)

	assert_false(gm.is_cell_walkable(Vector2i(0, 0), null, false, true),
		"A turret stops him however he asks")

func test_06_a_stake_sharing_a_tile_with_something_else_opens_nothing() -> void:
	# The trap in "is everything here a wall": a stake standing in the wreck's tile must
	# not make the wreck walk-through-able.
	var gm = _grid([])
	await wait_frames(1)
	var tower = _tower_at(gm, Vector2i(0, 0))
	# A stake registered in the same tile, finely.
	var stake = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(stake)
	tree.root.add_child(stake)
	stake.setup("wall", Vector2i(0, 0))
	stake.global_position = gm.cell_to_world(Vector2i(0, 0))
	stake.complete_construction()
	gm.occupy_fine_cell(Vector2i(1, 1), stake, int(config_node.get_cell_divisions("wall")))
	await wait_frames(1)

	assert_false(gm.is_cell_walkable(Vector2i(0, 0), null, false, true),
		"The turret is still in there, so the tile is still shut")

func test_07_he_routes_straight_through_a_fence_across_his_way() -> void:
	# Both halves together. A fence right across the map, no way round it at all, and he
	# is told to go to the other side.
	var gm = _grid([])
	await wait_frames(1)
	var inside := Vector2i(0, -4)
	_fence_around(gm, inside)
	await wait_frames(1)

	var from_pos: Vector3 = gm.cell_to_world(Vector2i(0, 4))
	var to_pos: Vector3 = gm.cell_to_world(inside)
	assert_false(gm.is_reachable(from_pos, to_pos), "Nobody else is getting through that")
	assert_true(gm.is_reachable(from_pos, to_pos, 400, true), "He is")

	var path: Array = gm.find_path(from_pos, to_pos, null, false, true)
	assert_gt(path.size(), 0, "And he is given a route")
	assert_lt(path[path.size() - 1].distance_to(to_pos), float(config_node.TILE_SIZE),
		"That ends where he was sent rather than short of the fence")

func test_08_a_raid_is_still_stopped_by_the_same_fence() -> void:
	# The whole point, asserted against the same wall in the same place: what the Hero
	# walks through, a raid has to chew.
	var gm = _grid([])
	await wait_frames(1)
	var inside := Vector2i(0, -4)
	_fence_around(gm, inside)
	await wait_frames(1)

	var dino = load(String(config_node.get_dino_script_path("raptor"))).new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	dino.global_position = gm.cell_to_world(Vector2i(0, 4))
	dino.set_waypoints([gm.cell_to_world(inside)])
	await wait_frames(1)

	assert_true(dino._way_is_sealed(), "The fence seals the way for it")
	# _building_in_the_way rather than the threat target: from fourteen metres off the
	# fence is not yet within anything's interest range, and what the rule has to say at
	# that distance is "there is something between you and where you are going".
	assert_not_null(dino._building_in_the_way(), "And names what is between it and the goal")
	assert_true(dino._is_wall(dino._building_in_the_way()), "Which is one of the stakes")
