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
	# inside the field would put a building in the air or in the dirt. ALL of the square,
	# corners and edges included: only a circle as wide as it was flat once, and the wall
	# began climbing inside the corners, under cells anyone could build on.
	var field_half: float = float(_terrain()["field_half"])
	var noise := TerrainBuilder.ground_noise(config_node)
	var t: Dictionary = _terrain()
	var worst: float = 0.0
	var at := Vector2.ZERO
	var x: float = -field_half
	while x <= field_half + 0.001:
		var z: float = -field_half
		while z <= field_half + 0.001:
			for n in [null, noise]:
				var h: float = absf(TerrainBuilder.ground_height(x, z, field_half, float(t["outskirts_half"]), t, n))
				if h > worst:
					worst = h
					at = Vector2(x, z)
			z += 0.5
		x += 0.5
	assert_eq(worst, 0.0, "The whole square is dead level (worst %.4f m at %s)" % [worst, str(at)])

func test_01b_the_floor_runs_on_past_the_edge_before_the_wall_starts() -> void:
	# The edge of the field is not where the valley wall starts: it curled up right there,
	# so anything built along the edge stood on the start of the slope. The floor runs on
	# flat for `flat_apron` metres all round -- out to the corners too -- before climbing.
	var t: Dictionary = _terrain()
	var field_half: float = float(t["field_half"])
	var apron: float = float(t["flat_apron"])
	assert_gt(apron, 1.0, "There is an apron of flat ground past the field's edge")
	var worst: float = 0.0
	for k in range(0, 360, 3):
		var a: float = deg_to_rad(float(k))
		var dir := Vector2(cos(a), sin(a))
		# The field's edge in this direction, then a metre and a half on.
		var edge: float = field_half / maxf(absf(dir.x), absf(dir.y))
		var p: Vector2 = dir * (edge + 1.5)
		worst = maxf(worst, absf(TerrainBuilder.natural_height(p.x, p.y, field_half,
			float(t["outskirts_half"]), t, TerrainBuilder.ground_noise(config_node))))
	assert_eq(worst, 0.0, "A step and a half past the edge, all the way round, it is still level")
	# And past the apron there is no wall: the plain runs on level (test_03b has all of it).
	assert_eq(_height(field_half + apron + 20.0, 0.0), 0.0, "Further out, still the level plain")

func test_02_the_flat_field_covers_every_cell_the_level_uses() -> void:
	# The guard that matters when somebody tunes the field down, or moves the nest further
	# out: every cell the level puts something on stands on level ground -- measured under
	# the whole of its tile, with the ground as drawn, rather than by a rule of thumb about
	# how far out its corner is.
	var t: Dictionary = _terrain()
	var field_half: float = float(t["field_half"])
	var tile: float = float(config_node.TILE_SIZE)
	var noise := TerrainBuilder.ground_noise(config_node)

	var used: Array[Vector2i] = []
	used.append(config_node.MAP["default_core_cell"])
	used.append(config_node.MAP["default_nest_cell"])
	for c in config_node.MAP.get("default_blocked_cells", []):
		used.append(c)
	for item in config_node.MAP.get("default_resource_nodes", []):
		used.append(item["cell"])

	for cell in used:
		var worst: float = 0.0
		for i in range(5):
			for j in range(5):
				var x: float = (float(cell.x) + float(i) * 0.25) * tile
				var z: float = (float(cell.y) + float(j) * 0.25) * tile
				worst = maxf(worst, absf(TerrainBuilder.ground_height(x, z, field_half,
					float(t["outskirts_half"]), t, noise)))
		assert_eq(worst, 0.0, "Cell %s stands on dead level ground" % str(cell))

func test_03_the_land_runs_on_to_mountains_that_hide_its_end() -> void:
	# The reason any of this exists: the old plane ended, and the camera could see it. The
	# ground runs far past the field, and before its end there are mountains to stand in
	# front of it.
	var t: Dictionary = _terrain()
	var field_half: float = float(t["field_half"])
	var outer_half: float = float(t["outskirts_half"])
	var rise: float = float(t["mountains_rise"])

	assert_gt(outer_half, field_half * 3.0,
		"The ground runs far past the field, so no edge is ever in frame")
	assert_almost_eq(_height(field_half, 0.0), 0.0, 0.001, "Still level at the field edge")
	assert_gt(_height(outer_half * 0.9, 0.0), rise * 0.5,
		"And there are mountains by the far edge")
	assert_lt(float(t["mountains_from"]) + float(t["mountains_span"]), outer_half,
		"Their crest stands inside the ground, in front of where it ends")

	# Level, then climbing: sampled outwards, the land never dips back down.
	var last: float = 0.0
	for d in range(int(field_half), int(outer_half), 8):
		var h: float = _height(float(d), 0.0)
		assert_gte(h, last - 0.001, "The land does not dip back down at %dm" % d)
		last = h

func test_03b_past_the_field_the_ground_stays_level_until_the_mountains() -> void:
	# Reported as "地图到边界还是卷曲上翘的": the ground was a bowl, climbing a few metres
	# past the field, and from the game's camera the map curled up at its edge. Now it is a
	# plain -- as drawn, swell and all, never more than `plain_swell` off level -- out to
	# where the mountains begin, all the way round.
	var t: Dictionary = _terrain()
	var field_half: float = float(t["field_half"])
	var outer_half: float = float(t["outskirts_half"])
	var noise := TerrainBuilder.ground_noise(config_node)
	var swell: float = float(t["plain_swell"])
	var worst: float = 0.0
	var at := Vector2.ZERO
	for k in range(0, 360, 3):
		var a: float = deg_to_rad(float(k))
		var dir := Vector2(cos(a), sin(a))
		var r: float = field_half
		while r < float(t["mountains_from"]):
			var p: Vector2 = dir * r
			var h: float = absf(TerrainBuilder.natural_height(p.x, p.y, field_half, outer_half, t, noise))
			if h > worst:
				worst = h
				at = p
			r += 2.0
	assert_lte(worst, swell + 0.001, "Level to within its swell right out to the mountains (worst %.2f m at %s)" % [worst, str(at)])

func test_04_the_mountains_stand_in_the_haze_not_behind_it() -> void:
	# A skyline that only gets tall past the fog is a skyline nobody ever sees -- which is
	# exactly what the first attempt at a valley built, and why the horizon was flat grey.
	var t: Dictionary = _terrain()
	var field_half: float = float(t["field_half"])
	var fog_end: float = float(config_node.ENVIRONMENT["fog_depth_end"])
	assert_gt(float(t["mountains_from"]), field_half * 2.5, "A long way past the field")
	assert_lt(float(t["mountains_from"]) + float(t["mountains_span"]), fog_end * 1.1,
		"Their crest is where the haze softens it, not past where it would swallow it")
	assert_lt(float(config_node.ENVIRONMENT["fog_density"]), 1.0, "And the haze never quite closes")

	var fog_begin: float = float(config_node.ENVIRONMENT["fog_depth_begin"])
	assert_gt(fog_begin, field_half * 2.0,
		"And the fog starts past the playfield rather than hazing the fight")

# ==============================================================================
# 2. The hills
# ==============================================================================

func test_05_a_hill_never_leaves_its_own_cell() -> void:
	# Art that overhangs a free cell would be rock that things walk straight through. The
	# collider is the cell; everything drawn for the hill has to stay inside it.
	#
	# Measured vertex by vertex, where each one actually ends up in the hill's space. The
	# first version of this read every mesh's box in the mesh's own space, which was fine
	# while hills were meshes built in place -- and then the crags arrived, scaled to fit
	# and turned when they are put down, and the check never saw either.
	var main = _level()
	await wait_frames(2)
	var half: float = float(config_node.TILE_SIZE) * 0.5

	var checked: int = 0
	for hill in main.terrain_container.get_children():
		var into_hill: Transform3D = (hill as Node3D).global_transform.affine_inverse()
		var widest: float = 0.0
		for node in hill.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var t: Transform3D = into_hill * mi.global_transform
			for surface in range(mi.mesh.get_surface_count()):
				for v in mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var p: Vector3 = t * v
					widest = maxf(widest, maxf(absf(p.x), absf(p.z)))
			checked += 1
		assert_lte(widest, half + 0.001, "Nothing drawn for %s reaches past its cell (%.3f m out)" % [hill.name, widest])
	assert_gt(checked, 0, "There are hills to check")

func test_05b_every_hill_is_a_knot_of_crags_on_a_low_mound() -> void:
	# The hills used to be bare cosine domes cut from a height field, and every lone one
	# stood on the field like a grey tent. Each now wears one of the crag formations
	# tools/generate_props.py makes, and what is left of the dome is a low swell of the
	# valley floor under them.
	var main = _level()
	await wait_frames(2)
	var height: float = float(config_node.MAP["hill_height"])
	var base: float = height * float(config_node.MAP["hill_base_fraction"])
	var bump: float = float(config_node.TERRAIN.get("hill_noise", 0.12))
	var hills: Array = main.terrain_container.get_children()
	assert_gt(hills.size(), 0, "There are hills")
	for hill in hills:
		var rocks := hill.get_node_or_null("Rocks") as Node3D
		assert_not_null(rocks, "%s wears crags" % hill.name)
		if rocks == null:
			continue
		var stone: AABB = VisualLibrary.visual_bounds(hill as Node3D)
		assert_gt(stone.end.y, height * 0.8, "Standing most of the hill's height -- %s" % hill.name)
		assert_lte(stone.end.y, height + 0.001, "And no taller than the collider -- %s" % hill.name)
		var mound := hill.get_node_or_null("Mound") as MeshInstance3D
		assert_not_null(mound, "On a mound -- %s" % hill.name)
		if mound != null:
			assert_lte(mound.mesh.get_aabb().end.y, base + bump + 0.001,
				"A low one: the stone is the hill, the mound only joins it to the ground -- %s" % hill.name)

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

	var mesh: Mesh = TerrainBuilder.build_hill_cell(lone_cell, lone, float(config_node.TILE_SIZE), height, config_node)
	var aabb: AABB = mesh.get_aabb()
	assert_almost_eq(aabb.position.y, 0.0, 0.001, "And the mesh reaches the ground, so nothing floats")
	assert_almost_eq(aabb.position.y + aabb.size.y, height, 0.05, "Topping out at the declared height")

func test_06b_a_hill_rises_out_of_the_ground_with_no_rim() -> void:
	# Once crags stood on the hills, what showed round every one of them was a square: a
	# lone hill used to stand on a plinth a quarter of its height, closed off by a vertical
	# skirt, and that step caught the light on one side and a shadow on the other. The
	# mound is the ground rising now, so wherever it meets open ground it is AT ground
	# level -- all the way round, corners included -- and level there, so there is not
	# even a crease for the light to find.
	var height: float = float(config_node.MAP["hill_height"])
	var tile: float = float(config_node.TILE_SIZE)
	var ridge: Dictionary = {Vector2i(40, 40): true, Vector2i(41, 40): true}
	for cell in [Vector2i(40, 40), Vector2i(41, 40)]:
		var mesh: Mesh = TerrainBuilder.build_hill_cell(cell, ridge, tile, height, config_node)
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var rim: int = 0
		for p in verts:
			# The rim is every edge that faces open ground: all of them, except the one the
			# two cells share.
			var shared_x: float = tile * 0.5 if cell.x == 40 else -tile * 0.5
			var on_open_edge: bool = absf(absf(p.z) - tile * 0.5) < 0.001 				or (absf(absf(p.x) - tile * 0.5) < 0.001 and absf(p.x - shared_x) > 0.001)
			if on_open_edge:
				rim += 1
				assert_almost_eq(p.y, 0.0, 0.001, "%s meets open ground at ground level, at %s" % [str(cell), str(p)])
		assert_gt(rim, 0, "There is a rim to check on %s" % str(cell))

	# And level where it gets there: a step's worth in from the edge it has barely risen.
	var just_in: float = TerrainBuilder.hill_height_at(Vector2i(40, 40), {Vector2i(40, 40): true}, 0.05, 0.5, height)
	assert_lt(just_in, height * 0.05, "It leaves the ground level, not at an angle")

	# While along the ridge it does not dip where the two cells meet: one rise, not two.
	var joint: float = TerrainBuilder.hill_height_at(Vector2i(40, 40), ridge, 1.0, 0.5, height)
	assert_almost_eq(joint, height, 0.001, "The ridge runs on at full height across the joint")

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
