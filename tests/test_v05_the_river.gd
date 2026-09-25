# res://tests/test_v05_the_river.gd
# v0.5: a river runs past the field (Config.TERRAIN.river, scripts/fx/River.gd).
#
# It is scenery, and scenery that cuts into the ground -- so most of what is held here is
# that it stays scenery: the channel never reaches the square the game is played on, the
# water never floats or runs uphill, nothing stands in it, nothing about it collides, and
# the ground it is cut into is still one surface with no cracks where the fine quads meet
# the coarse ones. And the one place it touches the game: the water spot sits on its bank.
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

func _level() -> Node:
	var main = await fresh_level()
	_cleanup_nodes.append(main)
	return main

func _t() -> Dictionary:
	return config_node.TERRAIN

func _river() -> River:
	return TerrainBuilder.river_of(_t())

func _half() -> float:
	return float(_t()["field_half"])

## The ground as drawn: its wobble, and the channel.
func _ground(x: float, z: float) -> float:
	var t: Dictionary = _t()
	return TerrainBuilder.ground_height(x, z, float(t["field_half"]), float(t["outskirts_half"]), t,
		TerrainBuilder.ground_noise(config_node))

## The land as it would be without the river.
func _natural(x: float, z: float) -> float:
	var t: Dictionary = _t()
	return TerrainBuilder.natural_height(x, z, float(t["field_half"]), float(t["outskirts_half"]), t,
		TerrainBuilder.ground_noise(config_node))

func _water_node(main: Node) -> Node3D:
	for n in main.resource_nodes_container.get_children():
		if "resource_type" in n and n.resource_type == "water":
			return n as Node3D
	return null

# ==============================================================================
# 1. It stays out of the game
# ==============================================================================

func test_01_the_channel_never_reaches_the_square_the_game_is_played_on() -> void:
	# Not just "the ground there is level": no part of the channel's reach -- bed, water or
	# bank -- lies over a cell anybody can build on or walk across.
	var river := _river()
	assert_not_null(river, "The valley has a river")
	if river == null:
		return
	var half: float = _half()
	var inside: int = 0
	for i in range(river.sample_count()):
		var p: Vector2 = river.point(i)
		var f: Vector2 = river.flow(i)
		var nrm := Vector2(-f.y, f.x)
		for side in [1.0, -1.0]:
			var l: float = 0.0
			while l <= river.reach(i, side):
				var q: Vector2 = p + nrm * (l * side)
				if maxf(absf(q.x), absf(q.y)) <= half:
					inside += 1
				l += 0.25
	assert_eq(inside, 0, "Nothing of the channel lies inside the square")
	# And the ground there says the same, point by point.
	var worst: float = 0.0
	var x: float = -half
	while x <= half + 0.001:
		var z: float = -half
		while z <= half + 0.001:
			worst = maxf(worst, absf(_ground(x, z) - _natural(x, z)))
			z += 0.5
		x += 0.5
	assert_eq(worst, 0.0, "Inside the square the channel changes the ground by nothing at all")

func test_02_the_water_runs_downhill_and_lies_below_both_banks() -> void:
	var river := _river()
	var rising: int = 0
	var lowest_bank: float = INF
	var buried_edge: float = INF
	for i in range(river.sample_count()):
		if i > 0 and river.level(i) > river.level(i - 1) + 0.000001:
			rising += 1
		var p: Vector2 = river.point(i)
		var f: Vector2 = river.flow(i)
		var nrm := Vector2(-f.y, f.x)
		for side in [1.0, -1.0]:
			var edge: Vector2 = p + nrm * (river.half_width(i) * side)
			lowest_bank = minf(lowest_bank, _natural(edge.x, edge.y) - river.level(i))
			# Where the surface runs in under the bank, the bank is above it: the edge of
			# the water mesh is always inside the ground, never hanging in the air.
			var under: float = minf(river.half_width(i) + float(_t()["river"].get("overhang", 0.8)), river.reach(i, side))
			var tucked: Vector2 = p + nrm * (under * side)
			buried_edge = minf(buried_edge, _ground(tucked.x, tucked.y) - river.level(i))
	assert_eq(rising, 0, "Never uphill, anywhere along it")
	assert_gte(lowest_bank, float(_t()["river"].get("margin", 0.35)) - 0.001,
		"The land on both banks stands clear of the water (lowest %.3f m)" % lowest_bank)
	assert_gt(buried_edge, 0.0, "The water's own edge is always under the bank (%.3f m)" % buried_edge)

func test_03_the_water_surface_never_folds_over_itself() -> void:
	# Round a bend the inside edge of the surface is closer to the middle of the bend than
	# the river is. If it ever reached past that middle the surface would fold back over
	# itself, and see-through water twice over is a dark blot.
	var river := _river()
	var folds: int = 0
	for i in range(1, river.sample_count() - 1):
		var turn: float = absf(river.flow(i - 1).angle_to(river.flow(i + 1)))
		if turn < 0.00001:
			continue
		var radius: float = (2.0 * River.STEP) / turn
		var out: float = river.half_width(i) + float(_t()["river"].get("overhang", 0.8))
		if out >= radius:
			folds += 1
	assert_eq(folds, 0, "Every bend is wider than the water is")

func test_04_the_ground_is_one_surface_with_no_cracks() -> void:
	# The channel's quads are cut eight to a side and the rest are not. Where the two meet,
	# every edge inside the ground has to be shared by exactly two triangles: an edge used
	# once is a crack the sky shows through.
	var mesh: Mesh = TerrainBuilder.build_ground(config_node)
	var arrays: Array = mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uses: Dictionary = {}
	for k in range(0, idx.size(), 3):
		for e in [Vector2i(idx[k], idx[k + 1]), Vector2i(idx[k + 1], idx[k + 2]), Vector2i(idx[k + 2], idx[k])]:
			var key := Vector2i(mini(e.x, e.y), maxi(e.x, e.y))
			uses[key] = int(uses.get(key, 0)) + 1
	var outer: float = float(_t()["outskirts_half"])
	var cracks: int = 0
	for key in uses:
		if int(uses[key]) == 2:
			continue
		var a: Vector3 = verts[key.x]
		var b: Vector3 = verts[key.y]
		var on_rim: bool = (absf(a.x) > outer - 0.01 and absf(b.x) > outer - 0.01) \
			or (absf(a.z) > outer - 0.01 and absf(b.z) > outer - 0.01)
		if int(uses[key]) != 1 or not on_rim:
			cracks += 1
	assert_eq(cracks, 0, "No edge inside the ground is open or shared three ways")
	# And the channel really is drawn in the fine quads: a point on its bed is within a
	# small quad's reach of a vertex.
	var river := _river()
	var near: Dictionary = {}
	for v in verts:
		near[Vector2i(int(floor(v.x * 2.0)), int(floor(v.z * 2.0)))] = true
	var coarse: int = 0
	for i in range(0, river.sample_count(), 10):
		var p: Vector2 = river.point(i)
		if absf(p.x) > outer - 1.0 or absf(p.y) > outer - 1.0:
			continue
		if not near.has(Vector2i(int(floor(p.x * 2.0)), int(floor(p.y * 2.0)))):
			coarse += 1
	assert_eq(coarse, 0, "The whole course is drawn in half-metre quads")

# ==============================================================================
# 2. Nothing stands in it
# ==============================================================================

func test_05_nothing_grows_in_the_water_and_the_meadow_stands_on_the_bank() -> void:
	var river := _river()
	var gc: Dictionary = config_node.GROUND_COVER
	var half: float = _half()
	var placements: Array[Transform3D] = GroundCover.scatter_placements(config_node,
		int(gc.get("grass_count", 2600)), half, [], 0.0, int(gc.get("seed", 7723)), Vector2(0.7, 1.5))
	assert_gt(placements.size(), 100, "The meadow was placed")
	var wet: int = 0
	var off_ground: float = 0.0
	for pl in placements:
		var o: Vector3 = pl.origin
		if river.water_clearance(o.x, o.z) < 0.0:
			wet += 1
		off_ground = maxf(off_ground, absf(o.y - _ground(o.x, o.z)))
	assert_eq(wet, 0, "Not one tuft of it in the river")
	assert_lt(off_ground, 0.0001, "Every piece stands on the ground as drawn, channel and all")

func test_06_trees_and_cliffs_keep_back_from_the_bank() -> void:
	var river := _river()
	var gc: Dictionary = config_node.GROUND_COVER
	var half: float = _half()
	var trees: Array[Transform3D] = GroundCover.band_placements(config_node, 60, half,
		float(gc["flora_edge_from"]), float(gc["flora_edge_to"]), 61, Vector2(1.0, 1.0), 1.6)
	var cliffs: Array[Transform3D] = GroundCover.band_placements(config_node, 30, half,
		float(gc["cliff_from"]), float(gc["cliff_to"]), 101, gc["cliff_scale"], 1.0,
		float(gc["cliff_sink"]), true, float(gc["cliff_river_clear"]))
	var on_bank: int = 0
	for pl in trees:
		if river.bank_clearance(pl.origin.x, pl.origin.z) < 0.5:
			on_bank += 1
	assert_eq(on_bank, 0, "No tree on the bank's slope or in the water")
	var too_close: int = 0
	for pl in cliffs:
		if river.bank_clearance(pl.origin.x, pl.origin.z) < float(gc["cliff_river_clear"]):
			too_close += 1
	assert_eq(too_close, 0, "No stretch of cliff hanging out over the channel")

func test_07_reeds_line_the_banks_and_boulders_stand_in_the_white_water() -> void:
	var river := _river()
	var spec: Dictionary = _t()["river"]
	var half: float = _half()
	var reeds: Array[Transform3D] = river.bank_placements(99, 200, float(spec["reed_from"]),
		float(spec["reed_to"]), half, Vector2(0.8, 1.3))
	assert_gt(reeds.size(), 100, "The banks are lined")
	var on_field: int = 0
	var too_deep: int = 0
	var far_off: int = 0
	for pl in reeds:
		var o: Vector3 = pl.origin
		if maxf(absf(o.x), absf(o.z)) <= half:
			on_field += 1
		var loc: Vector3 = river.locate(o.x, o.z)
		if loc.z != 0.0 and river.level_at(loc) - (o.y + 0.05) > 0.26:
			too_deep += 1
		if river.water_clearance(o.x, o.z) > float(spec["reed_to"]) + 0.01:
			far_off += 1
	assert_eq(on_field, 0, "Not one on the square the game is played on")
	assert_eq(too_deep, 0, "None standing deeper than a horsetail grows")
	assert_eq(far_off, 0, "All of them along the water")
	var rocks: Array[Transform3D] = river.boulder_placements(7, 30, spec["boulder_scale"])
	assert_eq(rocks.size(), 30, "The boulders were placed")
	var dry: int = 0
	for pl in rocks:
		if river.water_clearance(pl.origin.x, pl.origin.z) > 0.0:
			dry += 1
	assert_eq(dry, 0, "Every boulder is in the stream")

func test_08_the_herds_graze_clear_of_the_channel() -> void:
	var main = await _level()
	var river := _river()
	var herds: Node = main.get_node_or_null("Herds")
	assert_not_null(herds, "The herds are there")
	if herds == null:
		return
	var lengths: Dictionary = {}
	for spec in config_node.HERDS["herds"]:
		lengths[String(spec["species"])] = float(spec["length"])
	var wading: int = 0
	for animal in herds.get_children():
		var species: String = String(animal.name).rsplit("_", true, 1)[0]
		var clear: float = float(lengths.get(species, 2.5)) * 0.5 + 0.5
		var p: Vector3 = (animal as Node3D).global_position
		if river.bank_clearance(p.x, p.z) < clear - 0.01:
			wading += 1
	assert_eq(wading, 0, "No animal stands in the channel or on its bank")

# ==============================================================================
# 3. The water spot
# ==============================================================================

func test_09_the_water_spot_is_on_the_bank_and_faces_the_water() -> void:
	var main = await _level()
	var river := _river()
	var spot: Node3D = _water_node(main)
	assert_not_null(spot, "There is a water spot")
	if spot == null:
		return
	var p: Vector3 = spot.global_position
	var half: float = _half()
	assert_lte(maxf(absf(p.x), absf(p.z)), half, "It is on the field")
	assert_eq(_ground(p.x, p.z), 0.0, "On level ground")
	var nearest: Vector2 = river.curve.get_closest_point(Vector2(p.x, p.z))
	var dir: Vector2 = (nearest - Vector2(p.x, p.z)).normalized()
	var d: float = 0.0
	while d < 10.0 and river.water_clearance(p.x + dir.x * d, p.z + dir.y * d) > 0.0:
		d += 0.05
	assert_lt(d, 3.0, "The water's edge is a step or two away (%.2f m)" % d)
	var facing: Vector3 = spot.global_transform.basis.z
	var turned: float = rad_to_deg(absf(Vector2(facing.x, facing.z).normalized().angle_to(dir)))
	assert_lt(turned, 10.0, "And it faces the river (off by %.1f degrees)" % turned)
	# The stepping stones from it down to the water are off the field, and reach the water.
	var stones: Array[Transform3D] = river.landing_placements(p, 3, half)
	assert_eq(stones.size(), 3, "Three stepping stones")
	for s in stones:
		assert_gt(maxf(absf(s.origin.x), absf(s.origin.z)), half, "Each one is off the field")
	assert_lt(river.water_clearance(stones[2].origin.x, stones[2].origin.z), 0.2, "The last is at the water")

func test_10_the_hero_can_walk_to_it_and_draw_water() -> void:
	var main = await _level()
	var spot: Node3D = _water_node(main)
	var hero = main.hero
	assert_not_null(hero, "There is a Hero")
	if spot == null or hero == null:
		return
	hero.order_harvest(spot)
	var drew: bool = false
	for i in range(900):
		await wait_physics_frames(1)
		if int(hero.current_state) == int(Hero.State.HARVESTING):
			drew = true
			break
	assert_true(drew, "He walks there and starts drawing water")

# ==============================================================================
# 4. It is scenery
# ==============================================================================

func test_11_nothing_about_it_collides_or_is_counted() -> void:
	var main = await _level()
	var holder: Node = main.get_node_or_null("River")
	assert_not_null(holder, "The river is in the level")
	if holder == null:
		return
	var bodies: int = 0
	var grouped: int = 0
	for n in holder.find_children("*", "", true, false):
		if n is CollisionObject3D or n is CollisionShape3D:
			bodies += 1
		if not n.get_groups().is_empty():
			grouped += 1
	assert_eq(bodies, 0, "No collider anywhere in it")
	assert_eq(grouped, 0, "And nothing in any group the game looks things up by")
	var water := holder.get_node_or_null("Water") as MeshInstance3D
	assert_not_null(water, "The water is there")
	if water != null:
		assert_not_null(water.mesh, "With a surface")
		assert_eq(water.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Water casts no shadow")

func test_12_the_water_flows() -> void:
	var main = await _level()
	var water := main.get_node_or_null("River/Water") as MeshInstance3D
	assert_not_null(water, "The water is there")
	if water == null:
		return
	var mat := water.material_override as StandardMaterial3D
	assert_not_null(mat, "Drawn with the engine's own material")
	if mat == null:
		return
	var before: Vector3 = mat.uv1_offset
	await wait_frames(20)
	assert_ne(mat.uv1_offset, before, "Its ripples move")

func test_13_the_same_river_every_time() -> void:
	var a := _river()
	assert_true(a == _river(), "Worked out once and kept")
	var copy: Dictionary = _t().duplicate(true)
	var b: River = TerrainBuilder.river_of(copy)
	assert_true(a != b, "A copy of the terrain gets a river of its own")
	assert_eq(b.sample_count(), a.sample_count(), "The same course")
	var differs: int = 0
	for i in range(a.sample_count()):
		if a.level(i) != b.level(i) or a.half_width(i) != b.half_width(i) or a.point(i) != b.point(i):
			differs += 1
	assert_eq(differs, 0, "And the same water, to the last digit")
	assert_true(TerrainBuilder.build_ground(config_node) == TerrainBuilder.build_ground(config_node),
		"The ground is built once for Config's terrain and handed back after")
