# res://tests/test_v04_pointing_at_things.gd
# Clicking a stake, and seeing which one you are about to click.
#
# Three reports, one cause between the first two: A STAKE IS SMALL AND SEVERAL SHARE A
# TILE, and nothing in the click path knew that.
#
#   1. "人造建筑造到一半，就走开的话，就点不回木栅栏继续造了" -- a blueprint was given
#      collision_layer 0 with its shape disabled. That does stop it blocking anyone, and
#      also makes it invisible to the CLICK raycast, so unfinished work could not be
#      pointed at to carry on with.
#
#   2. "pending 很多木栅栏，竟然恐龙会被挡住" -- the fine grid counted a blueprint as
#      occupying its cell, and the seal test counted occupied as solid. So a fence you
#      had only ORDERED stopped a raid dead.
#
#   3. "hover 能高亮当前的 hover 单位" -- at eighteen metres up, with a 0.62m stake, there
#      was no way to tell which one a click would land on, or whether it would land on
#      one at all rather than the ground behind it.
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

func _divisions() -> int:
	return int(config_node.get_cell_divisions("wall"))

func _step() -> float:
	return float(config_node.TILE_SIZE) / float(_divisions())

## A stake at a fine cell. `pending` leaves it as a blueprint, the way an order does.
func _stake(gm: Node, bs: Node, fine: Vector2i, pending: bool = false) -> Node:
	var at: Vector3 = gm.fine_cell_to_world(fine, _divisions())
	var s = bs.place_building("wall", gm.world_to_cell(at), gm, pending, at)
	if s != null:
		_cleanup_nodes.append(s)
	return s

# ==============================================================================
# 1. Unfinished work can still be pointed at
# ==============================================================================

func test_01_a_blueprint_is_on_a_layer_the_click_ray_looks_at() -> void:
	# The whole of the first report. Layer 0 with a disabled shape is unclickable, and
	# unclickable work is work you cannot go back to.
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", Vector2i(0, 0))
	w.start_construction(4.0)
	await wait_frames(1)

	assert_false(w.is_constructed, "It is a blueprint")
	assert_gt(w.collision_layer, 0, "It is on SOME layer -- layer 0 is invisible to the ray")
	assert_true(config_node.FEEDBACK != null and "LAYER_BLUEPRINT" in config_node,
		"And Config says which layer that is")
	assert_eq(w.collision_layer, int(config_node.LAYER_BLUEPRINT), "Which is the one it uses")

	var shape: CollisionShape3D = null
	for child in w.get_children():
		if child is CollisionShape3D:
			shape = child
			break
	assert_not_null(shape, "It has a collider")
	assert_false(shape.disabled, "And it is enabled, or the ray goes straight through")

func test_02_and_is_still_solid_to_nobody() -> void:
	# The half that must not be lost buying the half above.
	var blueprint_layer: int = int(config_node.LAYER_BLUEPRINT)
	assert_eq(blueprint_layer & 2, 0, "Not the buildings layer, which dinosaurs ray against")
	assert_eq(blueprint_layer & 3, 0, "Not in the Hero's collision mask (layer 1 | 2)")
	assert_eq(blueprint_layer & 12, 0, "Not in the turret's detection mask (layers 3 | 4)")

func test_03_finishing_it_makes_it_solid_again() -> void:
	var w = load("res://scripts/entities/Wall.gd").new()
	_cleanup_nodes.append(w)
	tree.root.add_child(w)
	w.setup("wall", Vector2i(0, 0))
	w.start_construction(4.0)
	await wait_frames(1)
	assert_ne(w.collision_layer, 2, "A blueprint is not on the buildings layer")

	w.complete_construction()
	await wait_frames(1)
	assert_eq(w.collision_layer, 2, "Finished work is")

# ==============================================================================
# 2. A fence you have only ordered stops nobody
# ==============================================================================

func test_04_a_row_of_pending_stakes_does_not_seal_a_tile() -> void:
	# The second report. Ordering a fence is not the same as having one, and the raid was
	# being stopped by stakes that did not exist yet.
	#
	# One BUILT and the rest pending, which is what a fence actually looks like while it
	# goes up -- and the only arrangement that tests anything. All-pending is caught by
	# the tile-level blueprint check before the fine grid is ever consulted.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	var built = _stake(gm, bs, Vector2i(0, 0))
	assert_not_null(built, "One stake is up")
	for i in range(1, d):
		assert_not_null(_stake(gm, bs, Vector2i(i, 0), true), "Stake %d only ordered" % i)
	await wait_frames(1)

	assert_true(gm.is_cell_walkable(Vector2i(0, 0)),
		"One stake and two orders is not a wall, whatever the row looks like")

	for i in range(1, d):
		assert_true(gm.is_fine_cell_occupied(Vector2i(i, 0)), "The spot is taken, so nothing else goes there")
		assert_false(gm.is_fine_cell_solid(Vector2i(i, 0)), "But there is nothing standing in it yet")

func test_05_and_seals_it_the_moment_it_is_built() -> void:
	# The same fence, finished. This is the test that keeps the fix above from being a
	# hole: pending must not block, and built must.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	var stakes: Array[Node] = []
	for i in range(d):
		stakes.append(_stake(gm, bs, Vector2i(i, 0), true))
	await wait_frames(1)
	assert_true(gm.is_cell_walkable(Vector2i(0, 0)), "Open while it is only ordered")

	for s in stakes:
		s.complete_construction()
	await wait_frames(1)
	assert_false(gm.is_cell_walkable(Vector2i(0, 0)), "Closed once it is actually there")

func test_06_a_dinosaur_walks_through_a_fence_that_is_only_ordered() -> void:
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	# A fence across the route with one stake up in each tile and the rest merely
	# ordered. Mixed, because that is what a fence being built looks like.
	var d: int = _divisions()
	for tile_x in range(-1, 2):
		for i in range(d):
			_stake(gm, bs, Vector2i(tile_x * d + i, 0), i != 0)
	await wait_frames(1)

	for tile_x in range(-1, 2):
		assert_true(gm.is_cell_walkable(Vector2i(tile_x, 0)),
			"Tile %d is still open, because most of that fence is not there yet" % tile_x)

	var dino = load("res://scripts/entities/Dino.gd").new()
	_cleanup_nodes.append(dino)
	tree.root.add_child(dino)
	dino.setup("raptor")
	dino.global_position = gm.cell_to_world(Vector2i(0, 3))
	dino.set_waypoints([gm.cell_to_world(Vector2i(0, -3))])
	await wait_frames(1)

	assert_false(dino._way_is_sealed(), "An ordered fence seals nothing")
	assert_null(dino._find_threat_priority_target(), "So there is nothing there worth stopping for")

# ==============================================================================
# 3. Which stake is under the cursor
# ==============================================================================

func test_07_the_building_at_a_point_is_the_one_you_pointed_at() -> void:
	# Asking the TILE gets you whichever stake happens to be registered as its occupant.
	# With a fence, that is almost never the one under the cursor -- so right-clicking a
	# half-built stake acted on a finished one beside it, and did nothing.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var first = _stake(gm, bs, Vector2i(0, 0))
	var second = _stake(gm, bs, Vector2i(2, 0), true)
	await wait_frames(1)

	assert_eq(gm.get_building_at(Vector2i(0, 0)), first, "The tile is held by the first one")
	assert_eq(gm.building_at_point(first.global_position), first, "Point at the first, get the first")
	assert_eq(gm.building_at_point(second.global_position), second,
		"Point at the second, get the SECOND -- which the tile lookup never would")

func test_08_which_is_what_makes_resuming_the_right_stake_possible() -> void:
	# The first report, end to end: a finished stake and a half-built one in the same
	# tile, and pointing at the half-built one has to find the half-built one.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	_stake(gm, bs, Vector2i(0, 0))
	var pending = _stake(gm, bs, Vector2i(2, 0), true)
	await wait_frames(1)

	var found = gm.building_at_point(pending.global_position)
	assert_eq(found, pending, "Pointing at the unfinished stake finds it")
	assert_false(found.is_constructed, "And it is the unfinished one, which is what can be resumed")

# ==============================================================================
# 4. The hover outline
# ==============================================================================

func test_09_the_hover_ring_is_a_different_colour_from_the_selection_ring() -> void:
	# Two outlines that look the same say nothing. "What I am pointing at" and "what I
	# have selected" have to be tellable apart at a glance.
	assert_true(config_node.FEEDBACK.has("hover_ring_color"), "There is a hover colour")
	assert_ne(config_node.FEEDBACK["hover_ring_color"], config_node.FEEDBACK["selection_ring_color"],
		"And it is not the selection colour")

func test_10_a_ring_can_be_drawn_in_another_colour() -> void:
	var ring = SelectionRing3D.new()
	_cleanup_nodes.append(ring)
	tree.root.add_child(ring)
	ring.configure(SelectionRing3D.Shape.BOX, 0.62)
	await wait_frames(1)

	ring.override_color(Color(1.0, 1.0, 1.0, 0.55))
	await wait_frames(1)
	var painted: int = 0
	for child in ring.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mat = child.mesh.surface_get_material(0) if child.mesh.get_surface_count() > 0 else null
			if mat == null:
				mat = child.material_override
			if mat is StandardMaterial3D:
				assert_almost_eq(mat.albedo_color.r, 1.0, 0.01, "Repainted white")
				painted += 1
	assert_gt(painted, 0, "The override reaches the mesh rather than being remembered and ignored")

func test_11_the_level_outlines_what_the_cursor_is_over() -> void:
	# The behaviour itself, driven through Main rather than asserted about a colour.
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(3)

	assert_true(main.has_method("_show_hover"), "The level knows how to outline something")
	var target = main.current_core
	assert_not_null(target, "There is something to point at")

	main._show_hover(target)
	await wait_frames(1)
	assert_not_null(main._hover_ring, "Pointing at it makes a ring")
	assert_true(main._hover_ring.visible, "Which is shown")
	assert_almost_eq(main._hover_ring.global_position.x, target.global_position.x, 0.01, "On the thing")
	assert_almost_eq(main._hover_ring.global_position.z, target.global_position.z, 0.01, "On both axes")

	main._show_hover(null)
	await wait_frames(1)
	assert_false(main._hover_ring.visible, "And pointing at nothing puts it away")

func test_12_the_hover_ring_matches_what_it_outlines() -> void:
	# A fixed-radius ring vanishes inside a big building and swamps a small one. It has
	# to take its size from the thing, which for a stake is 0.62m.
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(3)
	if game_state_node and "resources" in game_state_node:
		game_state_node.resources["wood"] = 500

	var stake = main.place_building_at_cell("wall", Vector2i(3, 3))
	assert_not_null(stake, "A stake to point at")
	await wait_frames(1)

	main._show_hover(stake)
	await wait_frames(1)
	assert_almost_eq(main._hover_ring.base_size, float(config_node.get_building_footprint("wall")), 0.01,
		"The ring is the size of the stake")
	assert_eq(int(main._hover_ring.shape), int(SelectionRing3D.Shape.BOX), "And the shape of its base")
