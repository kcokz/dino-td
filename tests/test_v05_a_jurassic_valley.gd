# res://tests/test_v05_a_jurassic_valley.gd
# The plants of the valley: what they are made of, where they grow, and what they are not
# allowed to do.
#
# Asked for as "远古恐龙时代的风貌，让人身临其境之感" -- the feel of the dinosaur age,
# immersive. The lever for that is not texture resolution, it is the FLORA: a Jurassic
# valley is carpeted with ferns and horsetails where a modern one has grass, and above it
# stand tree ferns, cycads and the monkey-puzzle araucaria. None of that exists in any
# free nature pack worth using -- they are all temperate -- so tools/generate_flora.py
# grows them in Blender.
extends "res://tests/test_base.gd"

var config_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _all_flora_paths() -> Array:
	var gc: Dictionary = config_node.GROUND_COVER
	var out: Array = []
	for key in ["flora_ground_ferns", "flora_horsetails", "flora_edge_trees", "flora_skyline_trees"]:
		for p in gc.get(key, []):
			out.append(String(p))
	return out

# ==============================================================================
# 1. What the plants are made of
# ==============================================================================

func test_01_every_plant_the_valley_asks_for_exists() -> void:
	var paths: Array = _all_flora_paths()
	assert_gt(paths.size(), 8, "The valley asks for a real variety of plants")
	for p in paths:
		assert_true(ResourceLoader.exists(p), "%s is there" % p)
		assert_not_null(GroundCover.flora_mesh(p), "And has a mesh in it")

func test_02_every_plant_is_one_surface_coloured_by_its_vertices() -> void:
	# The bug this was built through. A plant used to be two surfaces -- trunk and leaf --
	# and the glTF export filled the SECOND surface's vertex colours with 1.0. Measured on
	# the imported mesh: the trunk r 0.11-0.28, the leaves exactly 1.0 everywhere. Every
	# tree fern, cycad and monkey-puzzle stood round the valley with a crown of white
	# fronds like palms under snow, while the single-surface ground ferns were green.
	for p in _all_flora_paths():
		var m: Mesh = GroundCover.flora_mesh(p)
		if m == null:
			continue
		assert_eq(m.get_surface_count(), 1, "%s is one surface" % p.get_file())
		var cols = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		assert_true(cols != null and (cols as PackedColorArray).size() > 0,
			"%s carries its colour in its vertices" % p.get_file())
		var white: int = 0
		var pc: PackedColorArray = cols
		for c in pc:
			if c.r > 0.98 and c.g > 0.98 and c.b > 0.98:
				white += 1
		assert_lt(float(white) / float(maxi(1, pc.size())), 0.01,
			"And almost none of it is white -- %s" % p.get_file())

func test_03_the_greens_are_green() -> void:
	# Not a style test: a check that the colour that came through is the one authored.
	for p in config_node.GROUND_COVER["flora_ground_ferns"]:
		var m: Mesh = GroundCover.flora_mesh(String(p))
		if m == null:
			continue
		var pc: PackedColorArray = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var greener: int = 0
		for c in pc:
			if c.g > c.r and c.g > c.b:
				greener += 1
		assert_gt(float(greener) / float(pc.size()), 0.8, "%s is mostly green" % String(p).get_file())

# ==============================================================================
# 2. Where they grow
# ==============================================================================

func test_04_nothing_tall_grows_on_the_field() -> void:
	# Tall plants inside the playfield would stand over the fight, would be walked through
	# (none of this collides), and would read as trees to be chopped when they are not.
	# Only low cover is scattered on the field; tree ferns, cycads and monkey-puzzles
	# start past its edge.
	#
	# Asked of the placements themselves, not of the MultiMesh they go into: headless,
	# a MultiMesh reads every instance back as the origin -- see band_placements.
	var gc: Dictionary = config_node.GROUND_COVER
	assert_gt(float(gc["flora_edge_from"]), 0.0, "The forest starts past the edge")
	assert_gt(float(gc["flora_skyline_from"]), float(gc["flora_edge_from"]),
		"And the monkey-puzzles further out than the tree ferns")

	var field_half: float = float(config_node.TERRAIN["field_half"])
	var total: int = 0
	var inside: int = 0
	var bands := [
		[int(gc["flora_edge_count"]), float(gc["flora_edge_from"]), float(gc["flora_edge_to"])],
		[int(gc["flora_skyline_count"]), float(gc["flora_skyline_from"]), float(gc["flora_skyline_to"])],
	]
	var seed_value: int = 100
	for band in bands:
		for pl in GroundCover.band_placements(config_node, band[0], field_half, band[1], band[2],
				seed_value, Vector2(1.0, 1.0), 1.6):
			total += 1
			var o: Vector3 = pl.origin
			if maxf(absf(o.x), absf(o.z)) < field_half + band[1] - 0.001:
				inside += 1
		seed_value += 1
	assert_gt(total, 30, "There is a forest round the valley")
	assert_eq(inside, 0, "And not one tall plant stands on the playfield, or short of where its band begins")

func test_05_the_low_cover_is_knee_high_at_most() -> void:
	for key in ["flora_ground_ferns", "flora_horsetails"]:
		for p in config_node.GROUND_COVER[key]:
			var m: Mesh = GroundCover.flora_mesh(String(p))
			if m == null:
				continue
			assert_lt(m.get_aabb().size.y, 1.6,
				"%s is low enough to be walked through without it reading as a wall" % String(p).get_file())

func test_06_none_of_it_is_solid() -> void:
	# GroundCover's first rule: scenery never collides and is never on the grid. A fern
	# that stopped the Hero would be the old lie -- something you can see that the rules
	# disagree about -- in a new costume.
	var main = load("res://scenes/Main.tscn").instantiate()
	_cleanup_nodes.append(main)
	tree.root.add_child(main)
	await wait_frames(4)
	var holder: Node = main.get_node_or_null("GroundCover")
	var bodies: int = 0
	var stack: Array = [holder]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionObject3D or n is CollisionShape3D:
			bodies += 1
		for c in n.get_children():
			stack.append(c)
	assert_eq(bodies, 0, "Not one collider among all the plants")

# ==============================================================================
# 3. How they are drawn
# ==============================================================================

func test_07_a_plant_glows_when_the_sun_is_behind_it() -> void:
	# Backlight: light coming through a frond from behind, the engine's own translucency
	# term. Without it a fern between the camera and the sun goes flat and dark.
	var mat := GroundCover.flora_material()
	assert_true(mat.backlight_enabled, "Fronds let light through")
	assert_eq(mat.cull_mode, BaseMaterial3D.CULL_DISABLED, "And have two sides")
	assert_true(mat.vertex_color_use_as_albedo, "And are coloured by their vertices")

func test_08_tall_plants_dissolve_when_the_camera_comes_close() -> void:
	# The player can turn the view now, and a tree fern at the edge of the field would
	# otherwise fill the screen with trunk the moment it came between the camera and the
	# fight.
	var near: float = float(config_node.GROUND_COVER["flora_fade_near"])
	var mat := GroundCover.flora_material(near)
	assert_ne(mat.distance_fade_mode, BaseMaterial3D.DISTANCE_FADE_DISABLED, "Tall plants fade")
	assert_almost_eq(mat.distance_fade_max_distance, near, 0.001, "At the distance Config says")
	assert_lt(near, float(config_node.CAMERA["min_distance"]) * 2.0,
		"Close enough that only a plant in the way ever fades")

# ==============================================================================
# 4. The land the plants grow on
# ==============================================================================

## The cliffs as Main draws them: every variant, each placed by its own mesh's bounds.
## Pairs of [placement, the bounds of the mesh drawn there].
func _cliffs(seed_value: int) -> Array:
	var out: Array = []
	var n: int = 0
	for p in config_node.GROUND_COVER.get("cliff_rocks", []):
		var m: Mesh = GroundCover.flora_mesh(String(p))
		if m != null:
			for pl in GroundCover.cliff_placements(config_node, float(config_node.TERRAIN["field_half"]),
					seed_value + n, m.get_aabb()):
				out.append([pl, m.get_aabb()])
		n += 1
	return out

var _ground_noise: FastNoiseLite = null

func _drawn_ground(x: float, z: float) -> float:
	var t: Dictionary = config_node.TERRAIN
	if _ground_noise == null:
		_ground_noise = TerrainBuilder.ground_noise(config_node)
	return TerrainBuilder.ground_height(x, z, float(t["field_half"]), float(t["outskirts_half"]), t, _ground_noise)

func test_09_the_mountains_have_cliffs() -> void:
	# The brief named them (VERSION.md: 火山、河流、峭壁). Stretches of columnar basalt in a
	# broken band up the mountainside, each facing into the valley and set into the slope
	# rather than stood on it -- nowhere under one open to the daylight.
	var gc: Dictionary = config_node.GROUND_COVER
	var paths: Array = gc.get("cliff_rocks", [])
	assert_gt(paths.size(), 0, "The valley declares its cliffs")
	for p in paths:
		assert_not_null(GroundCover.flora_mesh(String(p)), "%s is there" % p)

	var foot: float = float(config_node.TERRAIN["mountains_from"])
	var cliffs: Array = _cliffs(501)
	assert_gt(cliffs.size(), 0, "Some stretches of cliff are placed")
	var aired: int = 0
	for c in cliffs:
		var pl: Transform3D = c[0]
		var bounds: AABB = c[1]
		var o: Vector3 = pl.origin
		var r: float = Vector2(o.x, o.z).length()
		assert_gte(r, foot + float(gc["cliff_from"]) - 0.001, "Up on the mountains, not out on the plain")
		assert_lte(r, foot + float(gc["cliff_to"]) + 0.001, "And no higher up them than the band says")
		var front: Vector3 = pl.basis.z.normalized()
		var inward: Vector3 = Vector3(-o.x, 0.0, -o.z).normalized()
		assert_gt(front.dot(inward), 0.9, "Facing into the valley")
		assert_lt(o.y, _drawn_ground(o.x, o.z) - 0.4, "Set into the slope, not stood on it")
		# Finer than the grid the placement itself looks at: a front corner over a dip in the
		# ground, where the slope fell away sideways, stood in the air.
		for i in range(9):
			for k in range(9):
				var local := Vector3(lerpf(bounds.position.x, bounds.end.x, i / 8.0), 0.0,
					lerpf(bounds.position.z, bounds.end.z, k / 8.0))
				var p: Vector3 = o + pl.basis * local
				if o.y > _drawn_ground(p.x, p.z) + 0.02:
					aired += 1
	assert_eq(aired, 0, "No part of any stretch of cliff stands in the air")

func test_09b_the_cliffs_are_seen_against_the_mountain_never_the_sky() -> void:
	# Laid out in the field's square they stood, at its corners, up on the crest: seen from
	# the field their flat-topped columns made battlements of the skyline. And along its
	# sides they stood on the level, a wall round the map. On the mountainside the slope
	# climbs up each one's back, and the crest behind stands clear above its top.
	var t: Dictionary = config_node.TERRAIN
	var outer: float = float(t["outskirts_half"])
	var checked: int = 0
	for seed_value in [101, 102, 103, 501]:
		for c in _cliffs(seed_value):
			var pl: Transform3D = c[0]
			var bounds: AABB = c[1]
			checked += 1
			var o: Vector3 = pl.origin
			var s: float = pl.basis.x.length()
			var front: Vector3 = pl.basis.z.normalized()
			var ahead: Vector3 = o + front * bounds.end.z * s
			var behind: Vector3 = o + front * bounds.position.z * s
			assert_gt(_drawn_ground(behind.x, behind.z) - _drawn_ground(ahead.x, ahead.z), 1.0,
				"The mountainside climbs up the back of the cliff at (%.0f, %.0f)" % [o.x, o.z])
			var top: float = o.y + bounds.end.y * s
			var out := Vector2(o.x, o.z).normalized()
			var crest: float = -INF
			var r: float = Vector2(o.x, o.z).length()
			while r < outer * 1.5:
				var q: Vector2 = out * r
				if absf(q.x) <= outer and absf(q.y) <= outer:
					crest = maxf(crest, _drawn_ground(q.x, q.y))
				r += 1.0
			assert_gt(crest - top, 2.0,
				"The crest behind the cliff at (%.0f, %.0f) stands clear above its top (by %.1f m)" % [o.x, o.z, crest - top])
	assert_gt(checked, 20, "Enough stretches of cliff to say so")

func test_10_facing_the_cliffs_in_did_not_move_a_single_tree() -> void:
	# The same seed has to grow the same forest whether or not a band asks to face in:
	# screenshots are compared across runs, and a forest that reshuffled because a cliff
	# was added would make every one of them a false difference.
	var gc: Dictionary = config_node.GROUND_COVER
	var field_half: float = float(config_node.TERRAIN["field_half"])
	var plain: Array[Transform3D] = GroundCover.band_placements(config_node, 12, field_half, 3.0, 22.0, 77,
		Vector2(0.8, 1.2), 1.6)
	var turned: Array[Transform3D] = GroundCover.band_placements(config_node, 12, field_half, 3.0, 22.0, 77,
		Vector2(0.8, 1.2), 1.6, 0.0, true)
	assert_eq(plain.size(), turned.size(), "The same number of trees")
	for i in range(mini(plain.size(), turned.size())):
		assert_almost_eq(plain[i].origin.distance_to(turned[i].origin), 0.0, 0.0001,
			"Tree %d stands in the same place" % i)

func test_11_what_grows_on_the_valley_wall_stands_on_the_wall_as_drawn() -> void:
	# The wall the player sees has a wobble in it -- up to two metres either side of the
	# valley's smooth shape -- and the forest was placed on the smooth shape: trees stood
	# in the air over every hollow and were buried to the knees in every rise.
	var gc: Dictionary = config_node.GROUND_COVER
	var t: Dictionary = config_node.TERRAIN
	var field_half: float = float(t["field_half"])
	var noise := TerrainBuilder.ground_noise(config_node)
	var placements: Array[Transform3D] = GroundCover.band_placements(config_node, 40, field_half,
		float(gc["flora_skyline_from"]), float(gc["flora_skyline_to"]), 91, Vector2(1.0, 1.0), 1.8)
	assert_gt(placements.size(), 10, "Trees were placed up the wall")
	var worst: float = 0.0
	for pl in placements:
		var o: Vector3 = pl.origin
		var drawn: float = TerrainBuilder.ground_height(o.x, o.z, field_half, float(t["outskirts_half"]), t, noise)
		worst = maxf(worst, absf(o.y - (drawn - 0.05)))
	assert_lt(worst, 0.001, "Every one of them stands on the ground as drawn (worst %.3f m off)" % worst)
