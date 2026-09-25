# res://scripts/fx/GroundCover.gd
class_name GroundCover

## Everything growing on and lying about the ground.
##
## The landform was fixed first -- the map stopped having a visible edge and the hills
## stopped being boxes -- and the ground still did not read as ground, because it was a
## flat wash of one colour. No amount of shading fixes that. Real ground reads as real
## because it is COVERED IN THINGS: tufts, ferns, pebbles, fallen wood. That is what
## this file makes.
##
## Two rules it lives under:
##
##   1. NONE OF IT COLLIDES, and none of it is on the grid. It is scenery. The Hero
##      walks through a fern the way you walk through long grass, and a tuft never
##      decides whether a stake can be planted. Cover that blocked anything would be
##      the old lie in a new costume -- something you can see but the rules disagree
##      about.
##   2. IT IS PLACED FROM A FIXED SEED, so the same meadow comes back every launch.
##      A world that reshuffles itself cannot be photographed twice, and the whole
##      point of the playtest harness is that two runs are comparable.
##
## Everything is drawn through MultiMeshInstance3D: ten thousand tufts cost one draw
## call, which is the only reason a density that actually looks like a meadow is
## affordable at all.

# ==============================================================================
# The pieces
# ==============================================================================

## A clump of blades. Built as crossed, tapered strips rather than as a billboard,
## because the camera looks down at forty degrees -- a flat card would show its edge
## and vanish, which is exactly how cheap grass gives itself away from above.
static func blade_clump(height: float, width: float, blades: int, base: Color, tip: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in range(blades):
		var yaw: float = TAU * (float(i) / float(blades)) + rng.randf_range(-0.3, 0.3)
		var lean: float = rng.randf_range(0.12, 0.45)
		var h: float = height * rng.randf_range(0.65, 1.2)
		var w: float = width * rng.randf_range(0.7, 1.1)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x) * w * 0.5
		var tip_at := dir * (h * lean) + Vector3(0.0, h, 0.0)
		# A blade is two triangles narrowing to a point, bent along its length.
		var mid_at := dir * (h * lean * 0.35) + Vector3(0.0, h * 0.55, 0.0)
		var mid: Color = base.lerp(tip, 0.55)
		_tri(st, Vector3.ZERO - side, Vector3.ZERO + side, mid_at + side * 0.6, base, base, mid)
		_tri(st, Vector3.ZERO - side, mid_at + side * 0.6, mid_at - side * 0.6, base, mid, mid)
		_tri(st, mid_at - side * 0.6, mid_at + side * 0.6, tip_at, mid, mid, tip)
	st.generate_normals()
	return st.commit()

## A fern: fronds radiating from one point and drooping. The plant that says "before
## flowers existed" more cheaply than anything else -- a meadow of these reads as
## prehistoric where the same meadow of round bushes would read as a park.
static func fern(height: float, fronds: int, stem: Color, leaf: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4177
	for i in range(fronds):
		var yaw: float = TAU * (float(i) / float(fronds)) + rng.randf_range(-0.15, 0.15)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var reach: float = height * rng.randf_range(0.75, 1.15)
		var lift: float = height * rng.randf_range(0.55, 0.9)
		var segments: int = 5
		var prev_l: Vector3 = Vector3.ZERO
		var prev_r: Vector3 = Vector3.ZERO
		for s in range(segments + 1):
			var t: float = float(s) / float(segments)
			# Arc up then over: the droop is what makes it a frond and not a spike.
			var y: float = lift * sin(t * PI * 0.62)
			var out: float = reach * t
			var half_w: float = height * 0.17 * sin(t * PI) + 0.004
			var centre := dir * out + Vector3(0.0, y, 0.0)
			var l: Vector3 = centre - side * half_w
			var r: Vector3 = centre + side * half_w
			if s > 0:
				var c0: Color = stem.lerp(leaf, float(s - 1) / float(segments))
				var c1: Color = stem.lerp(leaf, t)
				_tri(st, prev_l, prev_r, r, c0, c0, c1)
				_tri(st, prev_l, r, l, c0, c1, c1)
			prev_l = l
			prev_r = r
	st.generate_normals()
	return st.commit()

## A pebble or a boulder, depending on the radius handed in: a subdivided box pushed
## around by noise so no two are the same shape.
static func stone(radius: float, seed_value: int, colour: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.4
	var rings: int = 7
	var segs: int = 9
	var grid: Array = []
	for i in range(rings + 1):
		var row: Array = []
		var phi: float = PI * float(i) / float(rings)
		for j in range(segs + 1):
			var theta: float = TAU * float(j) / float(segs)
			var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var r: float = radius * (1.0 + noise.get_noise_3d(n.x * 2.0, n.y * 2.0, n.z * 2.0) * 0.38)
			# Flattened and sunk a little, so it sits in the ground rather than on it.
			row.append(Vector3(n.x * r, maxf(n.y * r * 0.72, -radius * 0.15), n.z * r))
		grid.append(row)
	for i in range(rings):
		for j in range(segs):
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j + 1]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i + 1][j]
			var shade: float = 0.85 + 0.3 * (float(i) / float(rings))
			var col := Color(colour.r * shade, colour.g * shade, colour.b * shade, 1.0)
			_tri(st, a, b, c, col, col, col)
			_tri(st, a, c, d, col, col, col)
	st.generate_normals()
	return st.commit()

## A fallen log: a tapered, slightly bent trunk lying on its side, with the broken end
## lighter than the bark. Scattered thinly -- one every so often reads as a forest that
## has been here a long time; a field of them reads as a lumber yard.
static func fallen_log(length: float, radius: float, bark: Color, core: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 8
	var rings: int = 6
	var prev: Array = []
	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		var r: float = radius * lerp(1.0, 0.68, t)
		var centre := Vector3(length * (t - 0.5), r * 0.85 + sin(t * PI) * radius * 0.25, sin(t * PI) * radius * 0.5)
		var row: Array = []
		for j in range(segs + 1):
			var a: float = TAU * float(j) / float(segs)
			row.append(centre + Vector3(0.0, cos(a) * r, sin(a) * r))
		if i > 0:
			for j in range(segs):
				var col := bark if (j % 3 != 0) else bark.lerp(core, 0.35)
				_tri(st, prev[j], prev[j + 1], row[j + 1], col, col, col)
				_tri(st, prev[j], row[j + 1], row[j], col, col, col)
		prev = row
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)

# ==============================================================================
# Scattering
# ==============================================================================

## Lays `count` copies of `mesh` across the valley, skipping anything too close to a
## cell the level has claimed, and hands back one MultiMeshInstance3D.
##
## Scattered well PAST the flat field and thinned out with distance, which matters more
## than it sounds: cover that stopped at the field edge drew a hard line across the
## ground and put back exactly the visible boundary the valley was built to remove. It
## reappeared the first time this ran, in a new costume.
##
## Pieces past the field sit on the valley wall at its real height, so nothing floats
## and nothing is buried in the slope.
##
## Deterministic from `seed_value`: the same meadow every launch, which is what makes a
## screenshot worth comparing to yesterday's.
static func scatter(cfg: Node, mesh: Mesh, material: Material, count: int, field_half: float,
		keep_clear: Array, clear_radius: float, seed_value: int,
		scale_range: Vector2, shadows: bool) -> MultiMeshInstance3D:
	var placements: Array[Transform3D] = scatter_placements(cfg, count, field_half, keep_clear,
		clear_radius, seed_value, scale_range)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = placements.size()
	for i in range(placements.size()):
		mm.set_instance_transform(i, placements[i])

	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Where scatter's pieces go, worked out apart from the MultiMesh they end up in, for the
## same reason as band_placements: headless, a MultiMesh reads back every instance at the
## origin, and a test has to be able to see where the meadow really is.
static func scatter_placements(cfg: Node, count: int, field_half: float, keep_clear: Array,
		clear_radius: float, seed_value: int, scale_range: Vector2) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var t: Dictionary = cfg.TERRAIN if (cfg and "TERRAIN" in cfg) else {}
	var cover_reach: float = float(t.get("cover_reach", 34.0))
	var outer: float = field_half + float(t.get("flat_apron", 3.0)) + cover_reach
	var outer_half: float = float(t.get("outskirts_half", 110.0))
	# The ground as drawn: its wobble, and the river's channel. On the valley's smooth shape
	# instead, the meadow hung over the channel and stood in the air over every hollow of
	# the wall -- the same fault band_placements had for the trees.
	var ground := TerrainBuilder.ground_noise(cfg)
	var river: River = TerrainBuilder.river_of(t)

	var placements: Array[Transform3D] = []
	var attempts: int = 0
	while placements.size() < count and attempts < count * 8:
		attempts += 1
		var x: float = rng.randf_range(-outer, outer)
		var z: float = rng.randf_range(-outer, outer)
		# Thinning, not stopping: past the flat valley floor the odds of keeping a piece
		# fall away, so the meadow runs out gradually instead of along an edge. Measured
		# from the floor's own edge (TerrainBuilder.past_the_flat): measured from a circle
		# as wide as the field, the corners of the square it is played on came out bald.
		var past: float = TerrainBuilder.past_the_flat(x, z, field_half, t)
		if past > cover_reach:
			continue
		if past > 0.0:
			var keep: float = 1.0 - smoothstep(0.0, cover_reach, past)
			if rng.randf() > keep * keep:
				continue
		# Nothing growing in the river; right down to its edge is fine.
		if river != null and river.water_clearance(x, z) < 0.15:
			continue
		var y: float = TerrainBuilder.ground_height(x, z, field_half, outer_half, t, ground)
		var at := Vector3(x, y, z)
		if _too_close(at, keep_clear, clear_radius):
			continue
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.scaled(Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y))
		placements.append(Transform3D(basis, at))
	return placements

## A ring of scenery BEYOND the playfield: the forest edge and the valley walls.
##
## Measured as distance outside the field's SQUARE, not from its centre -- the field is
## square and a ring measured from the middle would put tall trees in its corners, which
## is ground the game is played on. `from_edge` / `to_edge` are metres past that square.
## Stands at the terrain's real height, so a tree on the valley wall grows out of it.
static func scatter_band(cfg: Node, mesh: Mesh, material: Material, count: int, field_half: float,
		from_edge: float, to_edge: float, seed_value: int, scale_range: Vector2,
		shadows: bool, bias_outward: float = 1.0, sink: float = 0.0,
		face_in: bool = false, river_clear: float = 0.5) -> MultiMeshInstance3D:
	var placements: Array[Transform3D] = band_placements(cfg, count, field_half, from_edge,
		to_edge, seed_value, scale_range, bias_outward, sink, face_in, river_clear)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = placements.size()
	for i in range(placements.size()):
		mm.set_instance_transform(i, placements[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Where a band's plants go, worked out apart from the MultiMesh they end up in.
##
## Separate because a MultiMesh cannot be read back without a GPU behind it: under the
## headless test runner get_instance_transform answers (0, 0, 0) for every instance,
## whatever was set. Measured -- set (30, 0, 40), read back the origin -- and a test that
## trusted it concluded every tree in the valley was standing in the middle of the field.
##
## `sink` buries each one by that many metres per unit of its scale. A tree needs none;
## a crag several metres across, stood on a slope, floats on its downhill side unless a
## good part of it is under the ground.
##
## `face_in` turns each one so its +Z -- the front of a stretch of cliff -- faces the
## middle of the valley, give or take a few degrees, rather than any old way.
##
## `river_clear` keeps each one that many metres back from the top of the river's bank:
## a tree fern can lean over the water from the rim of the channel, but nothing stands on
## the bank's slope or in the water, and a cliff eight metres long needs more room than a
## tree.
static func band_placements(cfg: Node, count: int, field_half: float, from_edge: float,
		to_edge: float, seed_value: int, scale_range: Vector2,
		bias_outward: float = 1.0, sink: float = 0.0, face_in: bool = false,
		river_clear: float = 0.5) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var t: Dictionary = cfg.TERRAIN if (cfg and "TERRAIN" in cfg) else {}
	var outer_half: float = float(t.get("outskirts_half", 110.0))
	var reach: float = field_half + to_edge
	var ground := TerrainBuilder.ground_noise(cfg)     # the wall as drawn, not its smooth shape
	var river: River = TerrainBuilder.river_of(t)
	var placements: Array[Transform3D] = []
	var attempts: int = 0
	while placements.size() < count and attempts < count * 20:
		attempts += 1
		var x: float = rng.randf_range(-reach, reach)
		var z: float = rng.randf_range(-reach, reach)
		var past: float = maxf(absf(x), absf(z)) - field_half
		if past < from_edge or past > to_edge:
			continue
		# Denser further out when asked, so the forest thickens up the valley wall
		# rather than standing in a line along the field's edge.
		var u: float = (past - from_edge) / maxf(0.01, to_edge - from_edge)
		if rng.randf() > lerpf(1.0, u, clampf(bias_outward - 1.0, 0.0, 1.0)) + 0.15:
			continue
		if river != null and river.bank_clearance(x, z) < river_clear:
			continue
		var y: float = TerrainBuilder.ground_height(x, z, field_half, outer_half, t, ground)
		# Drawn either way, so asking for the face to turn in never reshuffles what comes
		# after it: the same seed still grows the same forest.
		var spin: float = rng.randf_range(0.0, TAU)
		var yaw: float = atan2(-x, -z) + (spin - PI) * 0.08 if face_in else spin
		var basis := Basis(Vector3.UP, yaw)
		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		basis = basis.scaled(Vector3.ONE * s)
		placements.append(Transform3D(basis, Vector3(x, y - 0.05 - sink * s, z)))
	return placements

## The mesh inside one of tools/generate_flora.py's plants, for scattering by the thousand.
##
## Loaded from the GLB rather than rebuilt here: the plant is authored ONCE, in Blender,
## and the same file is what a resource node shows up close and what the meadow is made
## of from far away. Null if the file is missing, so a fixture without the art still runs.
static func flora_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var scene = load(path)
	if not (scene is PackedScene):
		return null
	var inst: Node = (scene as PackedScene).instantiate()
	var found: Mesh = null
	var stack: Array = [inst]
	while not stack.is_empty() and found == null:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			found = (n as MeshInstance3D).mesh
		for c in n.get_children():
			stack.append(c)
	inst.free()
	return found

## The material a plant is drawn with: its own vertex colours, both faces of every frond,
## and BACKLIGHT -- light coming through a leaf from behind, which is what makes a fern
## glow when the sun is on the far side of it instead of going flat and dark. The
## engine's own translucency term, not a shader.
##
## `fade_near` > 0 dissolves the plant as the camera comes close. A tree fern at the
## edge of the field would otherwise stand between the camera and the fight the moment
## the player turned the view, and there is nothing to be done about a tree trunk that
## fills the screen except not draw it.
static func flora_material(fade_near: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	mat.metallic = 0.0
	mat.backlight_enabled = true
	mat.backlight = Color(0.22, 0.30, 0.10)
	if fade_near > 0.0:
		mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		mat.distance_fade_min_distance = fade_near * 0.5
		mat.distance_fade_max_distance = fade_near
	return mat

static func _too_close(at: Vector3, keep_clear: Array, radius: float) -> bool:
	for p in keep_clear:
		if p is Vector3 and at.distance_to(p) < radius:
			return true
	return false

## The material every piece of cover shares: its own vertex colours, lit, and drawn
## from both sides because a blade of grass has no back.
static func cover_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat
