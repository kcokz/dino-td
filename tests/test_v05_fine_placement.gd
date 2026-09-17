# res://tests/test_v05_fine_placement.gd
# Stakes are placed on a finer grid than everything else.
#
# The complaint that led here, after four rounds of arguing about the cone: "one stake
# is right, but they sit miles apart." They did -- two metres apart, because that is a
# tile, and a tile is what every building was placed on. THE CONE WAS NEVER THE PROBLEM.
# THE GRID WAS.
#
# So a stake now snaps to Config.BUILDINGS.wall.cell_divisions positions per tile edge
# and a row of them closes up into something that reads as a fence. Everything here
# exists to hold the two halves of that:
#
#   * finely-placed things really can share a tile, and really do land where the click
#     was rather than in the middle of the tile;
#   * NOTHING ELSE CHANGED. The tile is still what gets blocked, so pathing, the
#     barrier rule, and the rule that you cannot build on top of the wreck all give the
#     answers they always gave.
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
		game_state_node.resources["stone"] = 500
	if game_state_node and "infinite_ap" in game_state_node:
		game_state_node.infinite_ap = true

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
	var gm = grid_script.new()
	_cleanup_nodes.append(gm)
	tree.root.add_child(gm)
	var bs = build_script.new()
	_cleanup_nodes.append(bs)
	tree.root.add_child(bs)
	bs.setup(gm, gm)
	return [gm, bs]

func _divisions() -> int:
	return int(config_node.get_cell_divisions("wall"))

func _step() -> float:
	return float(config_node.TILE_SIZE) / float(_divisions())

# ==============================================================================
# 1. The finer grid itself
# ==============================================================================

func test_01_only_stakes_are_placed_finely() -> void:
	# A turret goes in the middle of its tile and that is that. If everything were fine
	# the change would be far larger than it needs to be.
	assert_gt(_divisions(), 1, "Stakes are placed more finely than one per tile")
	assert_eq(int(config_node.get_cell_divisions("tower")), 1, "A turret is one per tile")
	assert_eq(int(config_node.get_cell_divisions("core")), 1, "So is the wreck")
	assert_eq(int(config_node.get_cell_divisions("no_such_building")), 1, "And so is anything unknown")

func test_02_fine_cells_are_a_whole_number_of_them_per_tile() -> void:
	# The arithmetic that makes a fine cell belong to exactly one tile. Worth asserting
	# because it has to hold on the negative side of the origin too, where Godot's
	# integer division truncates towards zero and would put fine cell -1 in tile 0.
	var rig := _rig()
	var gm = rig[0]
	await wait_frames(1)
	var d: int = _divisions()

	for tile_x in [-3, -1, 0, 2]:
		for i in range(d):
			var fine := Vector2i(tile_x * d + i, 0)
			assert_eq(gm.fine_cell_to_cell(fine, d).x, tile_x,
				"Fine cell %d belongs to tile %d" % [fine.x, tile_x])

	# And a round trip: the centre of a fine cell falls back into that same fine cell.
	for fine_x in [-7, -1, 0, 5]:
		var fine := Vector2i(fine_x, fine_x)
		var world: Vector3 = gm.fine_cell_to_world(fine, d)
		assert_eq(gm.world_to_fine_cell(world, d), fine, "A fine cell's centre is in it")

func test_03_the_spacing_is_what_makes_a_fence_close_up() -> void:
	# The whole complaint, as a number. Neighbouring stakes have to end up closer
	# together than a stake is wide, or the fence has holes in it.
	var step: float = _step()
	var diameter: float = float(config_node.get_spike_diameter("wall"))
	assert_lt(step, float(config_node.TILE_SIZE),
		"Stakes go closer together than one per tile")
	assert_lt(step - diameter, diameter,
		"And the daylight between two of them is less than a stake is wide")

# ==============================================================================
# 2. Several stakes to a tile
# ==============================================================================

func test_04_a_tile_holds_several_stakes() -> void:
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	var step: float = _step()
	var placed: Array[Node] = []
	for i in range(d):
		var at := Vector3(step * (float(i) + 0.5), 0.0, step * 0.5)
		var b = bs.place_building("wall", gm.world_to_cell(at), gm, false, at)
		if b != null:
			_cleanup_nodes.append(b)
			placed.append(b)
	await wait_frames(1)

	assert_eq(placed.size(), d, "All %d fit in the one tile" % d)
	# And they are in different places, which is the point.
	for i in range(1, placed.size()):
		assert_ne(placed[i].global_position, placed[i - 1].global_position,
			"Each one stands where it was put, not in the middle of the tile")

func test_05_two_stakes_cannot_share_the_same_fine_cell() -> void:
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var at := Vector3(_step() * 0.5, 0.0, _step() * 0.5)
	var cell: Vector2i = gm.world_to_cell(at)
	var first = bs.place_building("wall", cell, gm, false, at)
	_cleanup_nodes.append(first)
	assert_not_null(first, "The first one goes in")
	await wait_frames(1)

	assert_false(bs.can_place_building("wall", cell, false, at), "The same spot is taken")
	var second = bs.place_building("wall", cell, gm, false, at)
	assert_null(second, "And a second one is refused")

func test_06_nothing_may_be_squeezed_in_beside_a_full_tile_building() -> void:
	# The bug the first version of this shipped with: replacing the tile check instead
	# of adding to it, so a stake could be driven straight through the wreck.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var cell := Vector2i(4, 4)
	var turret = bs.place_building("tower", cell, gm)
	_cleanup_nodes.append(turret)
	assert_not_null(turret, "A turret is standing here")
	await wait_frames(1)

	# Every fine cell inside that tile must refuse a stake.
	var d: int = _divisions()
	var step: float = _step()
	for i in range(d):
		for j in range(d):
			var at := Vector3((float(cell.x * d + i) + 0.5) * step, 0.0, (float(cell.y * d + j) + 0.5) * step)
			assert_false(bs.can_place_building("wall", cell, false, at),
				"No room beside a turret at fine offset (%d, %d)" % [i, j])

func test_07_placing_by_tile_still_works_and_lands_in_the_middle() -> void:
	# Tests and the Hero's own code place by tile with no world point. That has to keep
	# working, and it has to put the stake somewhere sensible.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var cell := Vector2i(2, -3)
	var stake = bs.place_building("wall", cell, gm)
	_cleanup_nodes.append(stake)
	assert_not_null(stake, "A stake placed by tile alone still goes in")
	await wait_frames(1)

	var centre: Vector3 = gm.cell_to_world(cell)
	assert_almost_eq(stake.global_position.x, centre.x, _step(), "Near the middle of its tile")
	assert_almost_eq(stake.global_position.z, centre.z, _step(), "On both axes")
	assert_eq(stake.cell_pos, cell, "And it knows which tile it is in")

# ==============================================================================
# 3. Everything the tile still decides
# ==============================================================================

func test_08_one_stake_blocks_its_tile_exactly_as_before() -> void:
	# The finer grid decides where a stake may be PUT. What it blocks is unchanged, so
	# pathing and the barrier rule keep the answers they had.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var at := Vector3(_step() * 0.5, 0.0, _step() * 0.5)
	var cell: Vector2i = gm.world_to_cell(at)
	assert_true(gm.is_cell_walkable(cell), "Open ground to begin with")

	var stake = bs.place_building("wall", cell, gm)
	_cleanup_nodes.append(stake)
	await wait_frames(1)

	assert_true(gm.is_cell_occupied(cell), "One stake claims the tile")
	assert_false(gm.is_cell_walkable(cell), "And blocks it, the same as it always did")
	assert_eq(gm.get_building_at(cell), stake, "And is what you get when you ask the tile")

func test_09_losing_one_stake_hands_the_tile_to_another() -> void:
	# Several stakes share a tile but only one of them is registered as its occupant.
	# Losing that one must NOT open the tile up while a fence is still standing in it.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var d: int = _divisions()
	var step: float = _step()
	var first_at := Vector3(step * 0.5, 0.0, step * 0.5)
	var cell: Vector2i = gm.world_to_cell(first_at)
	var first = bs.place_building("wall", cell, gm, false, first_at)
	_cleanup_nodes.append(first)
	var second_at := Vector3(step * (float(d) - 0.5), 0.0, step * 0.5)
	var second = bs.place_building("wall", gm.world_to_cell(second_at), gm, false, second_at)
	_cleanup_nodes.append(second)
	await wait_frames(1)

	assert_eq(gm.get_building_at(cell), first, "The first one holds the tile")
	first.destroy()
	await wait_frames(1)

	assert_true(gm.is_cell_occupied(cell), "The tile is still held")
	assert_eq(gm.get_building_at(cell), second, "By the stake that is still standing in it")
	assert_false(gm.is_cell_walkable(cell), "So the fence has not quietly opened up")

func test_10_the_last_stake_leaving_frees_the_tile() -> void:
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var at := Vector3(_step() * 0.5, 0.0, _step() * 0.5)
	var cell: Vector2i = gm.world_to_cell(at)
	var stake = bs.place_building("wall", cell, gm, false, at)
	_cleanup_nodes.append(stake)
	await wait_frames(1)
	stake.destroy()
	await wait_frames(1)

	assert_false(gm.is_cell_occupied(cell), "Nothing left holding the tile")
	assert_true(gm.is_cell_walkable(cell), "So it is open ground again")
	assert_false(gm.is_fine_cell_occupied(gm.world_to_fine_cell(at, _divisions())),
		"And its fine cell is free for a new stake")

func test_11_clearing_the_grid_takes_the_fine_cells_with_it() -> void:
	# A restart that left fine cells behind would refuse to let the player rebuild a
	# fence where the last one stood, with nothing on screen to explain why.
	var rig := _rig()
	var gm = rig[0]
	var bs = rig[1]
	await wait_frames(1)

	var at := Vector3(_step() * 0.5, 0.0, _step() * 0.5)
	var stake = bs.place_building("wall", gm.world_to_cell(at), gm, false, at)
	_cleanup_nodes.append(stake)
	await wait_frames(1)
	assert_true(gm.is_fine_cell_occupied(gm.world_to_fine_cell(at, _divisions())), "Taken")

	gm.clear_grid()
	assert_false(gm.is_fine_cell_occupied(gm.world_to_fine_cell(at, _divisions())),
		"A cleared grid has no fine cells left in it either")
