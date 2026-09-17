# res://tests/test_v05_terrain_shape.gd
# v0.5: the land has a shape, and that shape must not touch the rules.
#
# The ground used to be a 40x40 plane whose edge the camera could see, and the hills
# were boxes. Both are meshes now. Everything here exists to make sure that change
# stayed on the art side of the line:
#
#   * the ground under the game is EXACTLY flat, because every building and every unit
#     sits at y = 0 and a slope under them would stand them in the air or bury them;
#   * a hill's mesh never leaves the cell the grid blocked, because art that overhangs
#     a free cell stops things at nothing visible;
#   * neighbouring hills meet at exactly the same height, because a crack between two
#     cells is a hole in something the game says is solid.
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

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _level() -> Node:
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	return main

func _terrain() -> Dictionary:
	return config_node.TERRAIN

func _height(x: float, z: float) -> float:
	var t: Dictionary = _terrain()
	return TerrainBuilder.ground_height(x, z,
		float(t["field_half"]), float(t["outskirts_half"]), t, null)

func _blocked_set() -> Dictionary:
	var out: Dictionary = {}
	for c in config_node.MAP.get("default_blocked_cells", []):
		if c is Vector2i:
			out[c] = true
	return out

# ==============================================================================
# 1. The ground the game is played on
# ==============================================================================

func test_01_the_playable_field_is_exactly_flat() -> void:
	# Not "nearly" flat. Everything in this game lives on a grid at y = 0, so any slope
	# inside the field would put a building in the air or in the dirt.
	var field_half: float = float(_terrain()["field_half"])
	for x in range(int(-field_half), int(field_half) + 1, 2):
		for z in range(int(-field_half), int(field_half) + 1, 2):
			if Vector2(float(x), float(z)).length() > field_half:
				continue
			assert_eq(_height(float(x), float(z)), 0.0,
				"Ground at (%d, %d) is dead level" % [x, z])

func test_02_the_flat_field_covers_every_cell_the_level_uses() -> void:
	# The guard that matters when somebody tunes field_half down, or moves the nest
	# further out: every cell the level puts something on has to be on flat ground.
	var field_half: float = float(_terrain()["field_half"])
	var tile: float = float(config_node.TILE_SIZE)

	var used: Array[Vector2i] = []
	used.append(config_node.MAP["default_core_cell"])
	used.append(config_node.MAP["default_nest_cell"])
	for c in config_node.MAP.get("default_blocked_cells", []):
		used.append(c)
	for item in config_node.MAP.get("default_resource_nodes", []):
		used.append(item["cell"])

	for cell in used:
		# The far corner of the cell, not its centre: a building fills its tile.
		var corner := Vector2(
			(absf(float(cell.x)) + 1.0) * tile,
			(absf(float(cell.y)) + 1.0) * tile)
		assert_lt(corner.length(), field_half,
			"Cell %s sits comfortably inside the flat field" % str(cell))

func test_03_the_land_climbs_away_and_never_stops() -> void:
	# The reason any of this exists: the old plane ended, and the camera could see it.
	var t: Dictionary = _terrain()
	var field_half: float = float(t["field_half"])
	var outer_half: float = float(t["outskirts_half"])
	var rise: float = float(t["rim_rise"])

	assert_gt(outer_half, field_half * 3.0,
		"The ground runs far past the field, so no edge is ever in frame")
	assert_almost_eq(_height(field_half, 0.0), 0.0, 0.001, "Still level at the field edge")
	assert_gt(_height(outer_half * 0.9, 0.0), rise * 0.5,
		"And well up the valley wall by the far edge")

	# Climbing, not wandering: sampled outwards, the land keeps going up.
	var last: float = 0.0
	for d in range(int(field_half), int(outer_half), 8):
		var h: float = _height(float(d), 0.0)
		assert_gte(h, last - 0.001, "The valley wall does not dip back down at %dm" % d)
		last = h

func test_04_the_climb_finishes_where_the_camera_can_still_see_it() -> void:
	# A wall that only gets tall past the fog is a wall nobody ever sees -- which is
	# exactly what the first attempt built, and why the horizon was flat grey.
	var t: Dictionary = _terrain()
	var span: float = float(t["rim_span"])
	var field_half: float = float(t["field_half"])
	var fog_end: float = float(config_node.ENVIRONMENT["fog_depth_end"])
	assert_lt(field_half + span, fog_end,
		"The valley wall reaches its height before the fog swallows it")

	var fog_begin: float = float(config_node.ENVIRONMENT["fog_depth_begin"])
	assert_gt(fog_begin, field_half * 2.0,
		"And the fog starts past the playfield rather than hazing the fight")

# ==============================================================================
# 2. The hills
# ==============================================================================

func test_05_a_hill_never_leaves_its_own_cell() -> void:
	# Art that overhangs a free cell would stop things at nothing visible. The collider
	# is the cell; the mesh has to stay inside it.
	var main = _level()
	await wait_frames(2)
	var tile: float = float(config_node.TILE_SIZE)
	var half: float = tile * 0.5

	var checked: int = 0
	for hill in main.terrain_container.get_children():
		for node in hill.find_children("*", "MeshInstance3D", true, false):
			var aabb: AABB = (node as MeshInstance3D).mesh.get_aabb()
			assert_gte(aabb.position.x, -half - 0.001, "%s does not overhang to the west" % hill.name)
			assert_gte(aabb.position.z, -half - 0.001, "%s does not overhang to the north" % hill.name)
			assert_lte(aabb.position.x + aabb.size.x, half + 0.001, "%s does not overhang to the east" % hill.name)
			assert_lte(aabb.position.z + aabb.size.z, half + 0.001, "%s does not overhang to the south" % hill.name)
			checked += 1
	assert_gt(checked, 0, "There are hills to check")

func test_06_a_hill_reaches_the_declared_height_and_no_higher() -> void:
	var blocked := _blocked_set()
	var height: float = float(config_node.MAP["hill_height"])
	for cell in blocked:
		var peak: float = TerrainBuilder.hill_height_at(cell, blocked, 0.5, 0.5, height)
		assert_almost_eq(peak, height, 0.001, "%s stands exactly as tall as declared" % str(cell))

	# And a hill on its own still comes to full height rather than being a flat lid.
	var lone: Dictionary = {Vector2i(40, 40): true}
	var lone_cell := Vector2i(40, 40)
	assert_almost_eq(TerrainBuilder.hill_height_at(lone_cell, lone, 0.5, 0.5, height), height, 0.001,
		"A lone hill domes up to full height")

	# Its edge sits on a low plinth rather than at ground level -- a corner is as high as
	# the share of hill cells touching it, and only one touches here. What must hold is
	# that the SKIRT closes that gap, so the hill is joined to the ground rather than
	# hovering over it.
	var edge: float = TerrainBuilder.hill_height_at(lone_cell, lone, 0.0, 0.5, height)
	assert_gt(edge, 0.0, "The edge stands on a plinth")
	assert_lt(edge, height * 0.5, "A low one -- it is a rock face, not a second hill")

	var mesh: Mesh = TerrainBuilder.build_hill_cell(lone_cell, lone, float(config_node.TILE_SIZE), height, config_node)
	var aabb: AABB = mesh.get_aabb()
	assert_almost_eq(aabb.position.y, 0.0, 0.001, "And the mesh reaches the ground, so nothing floats")
	assert_almost_eq(aabb.position.y + aabb.size.y, height, 0.05, "Topping out at the declared height")

func test_07_neighbouring_hills_meet_without_a_crack() -> void:
	# Both cells work their shared corners out from the same four cells, so they agree
	# by construction. This is the assertion that keeps it that way.
	var blocked: Dictionary = {Vector2i(0, 0): true, Vector2i(1, 0): true}
	var height: float = float(config_node.MAP["hill_height"])

	for i in range(5):
		var v: float = float(i) / 4.0
		var left: float = TerrainBuilder.hill_height_at(Vector2i(0, 0), blocked, 1.0, v, height)
		var right: float = TerrainBuilder.hill_height_at(Vector2i(1, 0), blocked, 0.0, v, height)
		assert_almost_eq(left, right, 0.001,
			"The two cells agree on their shared edge at v=%.2f" % v)

func test_08_the_grid_still_decides_who_can_walk_where() -> void:
	# The whole point of keeping collision off the art. Reshaping the hills must not
	# have moved a single rule.
	var main = _level()
	await wait_frames(2)
	for c in config_node.MAP.get("default_blocked_cells", []):
		assert_true(main.grid_manager.is_cell_blocked(c), "%s is still hillside" % str(c))
		assert_false(main.grid_manager.is_cell_walkable(c), "And still unwalkable")
	assert_eq(main.terrain_container.get_child_count(),
		config_node.MAP.get("default_blocked_cells", []).size(),
		"One hill per blocked cell, no more and no fewer")

func test_09_the_ground_collider_covers_the_flat_field() -> void:
	# The rising outskirts are scenery nobody reaches, but everything the Hero walks on
	# needs something under it.
	var main = _level()
	await wait_frames(2)
	var field_half: float = float(_terrain()["field_half"])
	var ground := main.find_child("Ground", true, false) as MeshInstance3D
	assert_not_null(ground, "The level has ground")

	var found: bool = false
	for node in ground.find_children("*", "CollisionShape3D", true, false):
		var col := node as CollisionShape3D
		if col != null and col.shape is BoxShape3D:
			var size: Vector3 = (col.shape as BoxShape3D).size
			assert_gte(size.x, field_half * 2.0 - 0.001, "The collider spans the flat field east-west")
			assert_gte(size.z, field_half * 2.0 - 0.001, "And north-south")
			found = true
	assert_true(found, "The ground has a box collider")
