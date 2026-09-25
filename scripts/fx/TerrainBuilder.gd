# res://scripts/fx/TerrainBuilder.gd
class_name TerrainBuilder

## Builds the ground and the hills as meshes, from the numbers Config declares.
##
## Two problems, and the first one is what made the game look like a diorama rather
## than a place: the ground was a 40x40 plane, and the camera could see its edge. Past
## that line was nothing. No amount of fog fixes a world that visibly stops.
##
## So the ground is now a valley floor. The playable field stays PERFECTLY FLAT --
## everything in this game lives on a grid at y = 0, and ground that undulated under
## the buildings would put them in the air or in the dirt -- and past the field the
## land climbs away into highlands that run further than the camera can see. That gives
## the boundary a reason to exist in the world instead of hiding it: you are defending
## the bottom of a valley.
##
## The second is the hills, which were boxes. They are now domes cut from a shared
## height field, which is what makes them meet without a seam.
##
## Nothing here produces collision. Collision comes from the declared cell -- see
## Main.spawn_terrain -- because the grid is the truth about who can walk where, and a
## collider measured off a mesh is how art starts quietly deciding gameplay.

# ==============================================================================
# The ground
# ==============================================================================

## Grounds already built, newest last: [the terrain, its grass, its rock, the mesh]. The
## ground is the same every time for the same numbers, and building it -- the river's
## cells especially -- is the slowest thing the level does, so a restart or a second level
## hands back the one already made. Only for read-only terrain (Config's own); anything
## else could be edited between two calls and is built fresh.
static var _built: Array = []

## The valley floor and the land around it, as one mesh centred on the origin.
##
## Quads `quad_size` metres across -- except where the river's channel runs, where each is
## cut into an 8 x 8 grid. A channel a few metres wide cannot be drawn on four-metre quads:
## it came out as a zigzag trench. A quad beside a cut one is drawn as a fan from its middle
## through every point along the shared edge, so the two sides of that edge are the same
## points and there is no crack between them (tests/test_v05_the_river.gd).
##
## Each point is worked out once and shared by every triangle that meets there; the normals
## are the height field's own slope, measured over the same three metres as the colour.
static func build_ground(cfg: Node) -> Mesh:
	var t: Dictionary = _terrain(cfg)
	var grass: Color = _colour(cfg, "ground", Color(0.28, 0.32, 0.24))
	var rock: Color = _colour(cfg, "hill", Color(0.36, 0.33, 0.28))
	if t.is_read_only():
		for entry in _built:
			if is_same(entry[0], t) and entry[1] == grass and entry[2] == rock:
				return entry[3]
	var mesh: Mesh = _Ground.new(t, _noise(cfg), river_of(t), grass, rock).build()
	if t.is_read_only():
		_built.append([t, grass, rock, mesh])
		if _built.size() > 3:
			_built.pop_front()
	return mesh

## One ground mesh being put together: the grid of points it is made of, each worked out
## once, and the triangles between them.
class _Ground:
	const FINE := 8          # a cut quad is FINE x FINE small ones

	var t: Dictionary
	var noise: FastNoiseLite
	var river: River
	var grass: Color
	var rock: Color
	var field_half: float
	var outer_half: float
	var quad: float
	var steps: int
	var step: float          # the small grid's spacing: every point is on it
	var slope_steps: int     # the colour's and the normal's half-span, in small steps
	var heights: Dictionary = {}    # small-grid point -> height
	var wet: Dictionary = {}        # small-grid point -> the river's surface beside it
	var index_of: Dictionary = {}   # small-grid point -> vertex
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var tris := PackedInt32Array()

	func _init(p_t: Dictionary, p_noise: FastNoiseLite, p_river: River, p_grass: Color, p_rock: Color) -> void:
		t = p_t
		noise = p_noise
		river = p_river
		grass = p_grass
		rock = p_rock
		field_half = float(t.get("field_half", 22.0))
		outer_half = float(t.get("outskirts_half", 110.0))
		quad = maxf(1.0, float(t.get("quad_size", 4.0)))
		steps = int(ceil((outer_half * 2.0) / quad))
		step = quad / float(FINE)
		slope_steps = maxi(1, int(round(1.5 / step)))

	func build() -> ArrayMesh:
		var cut: Dictionary = {}
		if river != null:
			for iz in range(steps):
				for ix in range(steps):
					if river.is_carve_cell(Vector2i(ix, iz)):
						cut[Vector2i(ix, iz)] = true
		for iz in range(steps):
			for ix in range(steps):
				var g0 := Vector2i(ix * FINE, iz * FINE)
				if cut.has(Vector2i(ix, iz)):
					for sz in range(FINE):
						for sx in range(FINE):
							var a := g0 + Vector2i(sx, sz)
							_quad(a, a + Vector2i(1, 0), a + Vector2i(1, 1), a + Vector2i(0, 1))
					continue
				var north: bool = cut.has(Vector2i(ix, iz - 1))
				var east: bool = cut.has(Vector2i(ix + 1, iz))
				var south: bool = cut.has(Vector2i(ix, iz + 1))
				var west: bool = cut.has(Vector2i(ix - 1, iz))
				if not (north or east or south or west):
					_quad(g0, g0 + Vector2i(FINE, 0), g0 + Vector2i(FINE, FINE), g0 + Vector2i(0, FINE))
					continue
				# Beside a cut quad: a fan from the middle, round every point on the edges it
				# shares with one, in the same turning order as a plain quad's corners.
				var ring: Array[Vector2i] = []
				_edge(ring, g0, Vector2i(1, 0), north)
				_edge(ring, g0 + Vector2i(FINE, 0), Vector2i(0, 1), east)
				_edge(ring, g0 + Vector2i(FINE, FINE), Vector2i(-1, 0), south)
				_edge(ring, g0 + Vector2i(0, FINE), Vector2i(0, -1), west)
				var middle: int = vertex(g0 + Vector2i(FINE / 2, FINE / 2))
				for k in range(ring.size()):
					_tri(middle, vertex(ring[k]), vertex(ring[(k + 1) % ring.size()]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = tris
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

	func _edge(ring: Array[Vector2i], from: Vector2i, dir: Vector2i, split: bool) -> void:
		ring.append(from)
		if split:
			for j in range(1, FINE):
				ring.append(from + dir * j)

	func _quad(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> void:
		var ia: int = vertex(a)
		var ic: int = vertex(c)
		_tri(ia, vertex(b), ic)
		_tri(ia, ic, vertex(d))

	func _tri(a: int, b: int, c: int) -> void:
		tris.append(a)
		tris.append(b)
		tris.append(c)

	func _x(g: Vector2i) -> float:
		return -outer_half + float(g.x) * step

	func _z(g: Vector2i) -> float:
		return -outer_half + float(g.y) * step

	## The ground at a point of the small grid, with the river's channel in it.
	func height(g: Vector2i) -> float:
		if heights.has(g):
			return heights[g]
		var x: float = _x(g)
		var z: float = _z(g)
		var y: float = TerrainBuilder.natural_height(x, z, field_half, outer_half, t, noise)
		if river != null:
			var loc: Vector3 = river.locate(x, z)
			if loc.z != 0.0:
				y = river.carve_at(loc, x, z, y)
				wet[g] = river.level_at(loc)
		heights[g] = y
		return y

	func vertex(g: Vector2i) -> int:
		if index_of.has(g):
			return index_of[g]
		var y: float = height(g)
		var span: float = 2.0 * float(slope_steps) * step
		var hx: float = height(g + Vector2i(slope_steps, 0)) - height(g - Vector2i(slope_steps, 0))
		var hz: float = height(g + Vector2i(0, slope_steps)) - height(g - Vector2i(0, slope_steps))
		var slope: float = Vector2(hx, hz).length() / span
		var x: float = _x(g)
		var z: float = _z(g)
		var col: Color = TerrainBuilder._tint(Vector3(x, y, z), slope, t, noise, grass, rock)
		if wet.has(g):
			col = TerrainBuilder.river_tint(col, y - float(wet[g]), t)
		verts.append(Vector3(x, y, z))
		norms.append(Vector3(-hx / span, 1.0, -hz / span).normalized())
		cols.append(col)
		index_of[g] = verts.size() - 1
		return verts.size() - 1

## Grass where the ground is flat, rock where it is steep, with the valley floor broken
## up a little so it is not one flat wash of green.
##
## Slope-blended vertex colour, because without it the rising land is exactly the same
## green as the field and the whole thing reads as an endless lawn rather than as a
## valley. It costs one extra float per vertex and no textures at all, which is the best
## trade available before real materials arrive.
static func _ground_colour(p: Vector3, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite, grass: Color, rock: Color) -> Color:
	return _tint(p, _slope_at(p.x, p.z, field_half, outer_half, t, noise), t, noise, grass, rock)

## The colour for a point whose slope is already known.
static func _tint(p: Vector3, slope: float, t: Dictionary, noise: FastNoiseLite, grass: Color, rock: Color) -> Color:
	var rockiness: float = clampf(slope / maxf(0.05, float(t.get("rock_slope", 0.55))), 0.0, 1.0)
	var col: Color = grass.lerp(rock, rockiness)
	# A slow mottle so the flat field is not a single colour. Kept small: this is
	# variation, not pattern.
	if noise != null:
		var shade: float = 1.0 + noise.get_noise_2d(p.x * 2.3, p.z * 2.3) * float(t.get("ground_mottle", 0.07))
		col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
	return col

## How steep the ground is here, by finite difference on the height function.
static func _slope_at(x: float, z: float, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite) -> float:
	var e: float = 1.5
	var hx: float = ground_height(x + e, z, field_half, outer_half, t, noise) - ground_height(x - e, z, field_half, outer_half, t, noise)
	var hz: float = ground_height(x, z + e, field_half, outer_half, t, noise) - ground_height(x, z - e, field_half, outer_half, t, noise)
	return Vector2(hx, hz).length() / (2.0 * e)

static func _colour(cfg: Node, key: String, fallback: Color) -> Color:
	if cfg and "COLORS" in cfg and cfg.COLORS.has(key):
		return cfg.COLORS[key]
	return fallback

## Height of the ground at a world point: the valley, with the river's channel cut into it.
##
## What everything that stands on the ground asks -- trees, herds, the camera -- so all of
## them find the river bank without knowing there is a river. The channel never reaches
## the square the game is played on, so inside it this is natural_height exactly.
static func ground_height(x: float, z: float, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite) -> float:
	var y: float = natural_height(x, z, field_half, outer_half, t, noise)
	var river: River = river_of(t)
	if river != null:
		y = river.carve(x, z, y)
	return y

## Height of the land as it would be without the river.
##
## Flat and exactly zero everywhere the game is played and a little way past it. Past that,
## a plain -- level ground running on towards the horizon, with only a slow swell in it --
## and far out, where the haze takes the edge off them, a ring of mountains.
##
## It was a bowl: the ground began climbing a few metres past the field and curled up all
## round it, and from the game's camera that read as the map itself curling up at its edge
## -- which no strategy game does. Ground that stays level and a skyline of separate
## mountains is the usual way; the edge of the playable ground is left to the river, the
## forest and the rocks, as it would be anywhere real.
static func natural_height(x: float, z: float, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite) -> float:
	var past: float = past_the_flat(x, z, field_half, t)
	if past <= 0.0:
		return 0.0
	var y: float = 0.0
	if noise != null:
		# The plain's swell, eased in from the flat so the last of the field is not rippled.
		# Upward only: a hollow below the field's own level drew the river down into it, and
		# a river lower than the field cuts wider banks -- into the square it must stay out of.
		var swell_in: float = smoothstep(0.0, maxf(0.1, float(t.get("plain_blend", 12.0))), past)
		y += (noise.get_noise_2d(x, z) * 0.5 + 0.5) * float(t.get("plain_swell", 0.8)) * swell_in
	# The mountains: a ring round the whole valley, far enough out to be a skyline rather
	# than a wall, near enough to stand in front of the end of the ground. Their crest is
	# broken into peaks and saddles, and their faces are rough.
	var d: float = sqrt(x * x + z * z)
	var from_d: float = float(t.get("mountains_from", 72.0))
	var rise: float = smoothstep(from_d, from_d + maxf(1.0, float(t.get("mountains_span", 26.0))), d)
	if rise > 0.0:
		var ridge: float = 1.0
		var rock: float = 0.0
		if noise != null:
			ridge += float(t.get("mountains_ridge", 0.35)) * noise.get_noise_2d(x * 0.6 + 311.0, z * 0.6 - 173.0)
			rock = noise.get_noise_2d(x * 3.1 - 77.0, z * 3.1 + 29.0) * float(t.get("mountains_rock", 2.0)) * rise
		y += float(t.get("mountains_rise", 18.0)) * pow(rise, 1.35) * ridge + rock
	return y

## How far (x, z) is past the flat valley floor, in metres: 0 anywhere on it.
##
## The floor is the square the game is played on, `flat_apron` metres wider all round, with
## its corners rounded off `flat_corner` metres. It was a circle as wide as the square, so
## the wall began climbing inside the square's corners and along its edges -- on ground a
## building could stand on -- and the edge of the field curled up. The rounded corners
## are what keep the valley a valley rather than a box: every step further out, the
## contour it climbs along is rounder.
static func past_the_flat(x: float, z: float, field_half: float, t: Dictionary) -> float:
	var half: float = field_half + maxf(0.0, float(t.get("flat_apron", 3.0)))
	var r: float = clampf(float(t.get("flat_corner", 5.0)), 0.0, half)
	var qx: float = absf(x) - (half - r)
	var qz: float = absf(z) - (half - r)
	return maxf(0.0, Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0) - r)

# ==============================================================================
# The river
# ==============================================================================

## Rivers already worked out, newest last: [the terrain, its river spec, its shape, river].
static var _rivers: Array = []

## The river `t` declares (Config.TERRAIN.river), cut to the land `t` describes, or null.
##
## Worked out once per terrain and kept: ground_height asks this for every point anyone
## asks about. Terrain that is not read-only is checked against its numbers each time,
## because a test's copy can be changed between two calls.
static func river_of(t: Dictionary) -> River:
	var spec = t.get("river")
	if not (spec is Dictionary):
		return null
	for entry in _rivers:
		if is_same(entry[0], t) and is_same(entry[1], spec) and (t.is_read_only() or entry[2] == _shape_of(t)):
			return entry[3]
	var field_half: float = float(t.get("field_half", 22.0))
	var outer_half: float = float(t.get("outskirts_half", 110.0))
	var noise := _noise_from(t)
	var natural := func(x: float, z: float) -> float:
		return natural_height(x, z, field_half, outer_half, t, noise)
	var river: River = River.build(spec, natural, -outer_half, maxf(1.0, float(t.get("quad_size", 4.0))))
	_rivers.append([t, spec, _shape_of(t), river])
	if _rivers.size() > 4:
		_rivers.pop_front()
	return river

## The numbers the river's course is cut from.
static func _shape_of(t: Dictionary) -> Array:
	return [t.get("field_half"), t.get("flat_apron"), t.get("flat_corner"), t.get("outskirts_half"),
		t.get("plain_blend"), t.get("plain_swell"), t.get("mountains_from"), t.get("mountains_span"),
		t.get("mountains_rise"), t.get("mountains_ridge"), t.get("mountains_rock"), t.get("noise_seed"),
		t.get("noise_frequency"), t.get("quad_size")]

## The ground's colour near the river, `above` metres over the water's surface: dark silt
## under the water, where the see-through water shows its bed, and wet mud up the bank a
## little way, fading into whatever the bank would otherwise be.
static func river_tint(col: Color, above: float, t: Dictionary) -> Color:
	var spec: Dictionary = t.get("river", {})
	if above < 0.0:
		var silt: Color = spec.get("silt", Color(0.16, 0.14, 0.10))
		return silt.darkened(clampf(-above * 0.35, 0.0, 0.4))
	var mud: Color = spec.get("mud", Color(0.26, 0.22, 0.15))
	return col.lerp(mud, 1.0 - smoothstep(0.0, maxf(0.05, float(spec.get("wet_band", 0.6))), above))

# ==============================================================================
# The hills
# ==============================================================================

## How far in from open ground a hill takes to reach its full height, in cells.
##
## Not a tuning number: it is what keeps neighbouring hills flush. Every open cell within
## half a cell of a point is a neighbour of every hill cell touching that point, so all of
## them see the same open cells and work out the same height there. Any further and two
## hills could disagree along the edge they share, and a crack would open between them.
const HILL_REACH := 0.5

## One hill cell's visible body, in the cell's own space (origin at the cell centre).
##
## `blocked` is the whole set of hill cells, because a hill's shape depends on its
## neighbours -- see hill_height_at.
##
## The mesh never leaves its own cell. Where a neighbour is open ground the surface comes
## down to ground level exactly at the cell edge, so nothing overhangs a cell the grid
## says is free: something you can see a slope on but cannot walk on is the exact lie
## this project keeps having to undo.
##
## `origin` is where the cell's centre is in the world. The mound is the valley floor
## rising, so every vertex is coloured by the valley floor's own function at the same
## world position: where the two meet they agree to the last digit, and there is no
## outline to see. A flat albedo, however carefully matched, drew a square round every
## hill, because the ground beside it is mottled and this was not.
static func build_hill_cell(cell: Vector2i, blocked: Dictionary, tile: float, height: float, cfg: Node, origin: Vector3 = Vector3.ZERO) -> Mesh:
	var t: Dictionary = _terrain(cfg)
	var subdivisions: int = maxi(2, int(t.get("hill_subdivisions", 6)))
	var noise := _noise(cfg)
	var bump: float = float(t.get("hill_noise", 0.12))

	var field_half: float = float(t.get("field_half", 22.0))
	var outer_half: float = float(t.get("outskirts_half", 110.0))
	var grass: Color = _colour(cfg, "ground", Color(0.28, 0.32, 0.24))
	var rock: Color = _colour(cfg, "hill", Color(0.36, 0.33, 0.28))
	var tint := func(p: Vector3) -> Color:
		return _ground_colour(origin + p, field_half, outer_half, t, noise, grass, rock)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half: float = tile * 0.5
	var step: float = tile / float(subdivisions)

	# Top surface.
	for iz in range(subdivisions):
		for ix in range(subdivisions):
			var u0: float = float(ix) / float(subdivisions)
			var u1: float = float(ix + 1) / float(subdivisions)
			var v0: float = float(iz) / float(subdivisions)
			var v1: float = float(iz + 1) / float(subdivisions)
			_quad(st,
				_hill_point(cell, blocked, u0, v0, half, step, ix, iz, height, noise, bump, tile),
				_hill_point(cell, blocked, u1, v0, half, step, ix + 1, iz, height, noise, bump, tile),
				_hill_point(cell, blocked, u1, v1, half, step, ix + 1, iz + 1, height, noise, bump, tile),
				_hill_point(cell, blocked, u0, v1, half, step, ix, iz + 1, height, noise, bump, tile),
				tint)

	st.generate_normals()
	return st.commit()

## Surface height inside a hill cell, at local (u, v) in 0..1.
##
## The mound is the ground rising: nothing where the hill meets open ground, `height`
## once it is HILL_REACH in from it. It is a product of falloffs, one for each open cell
## near the point, each a smoothstep of the distance to that cell. Two things follow from
## that, and nothing else is needed to keep them true:
##
## - Where a hill meets open ground it is at ground level, and level, so there is no step
##   and no crease to draw an outline. The old shape stood a lone hill on a plinth a
##   quarter of its height, with a vertical skirt to close the gap; once crags stood on
##   the mounds, that square rim was what showed round every rock on the field.
## - The height at a point depends only on the point and on which cells near it are
##   open -- not on which cell is asking. Two hills sharing an edge work out the same
##   height all along it, so they meet without a crack, and a ridge of hills is one
##   continuous rise rather than a row of bumps.
static func hill_height_at(cell: Vector2i, blocked: Dictionary, u: float, v: float, height: float) -> float:
	var p := Vector2(u, v)
	var rise: float = 1.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if blocked.has(cell + Vector2i(dx, dz)):
				continue
			# The nearest point of that open cell, in this cell's (u, v).
			var nearest := Vector2(clampf(p.x, float(dx), float(dx) + 1.0), clampf(p.y, float(dz), float(dz) + 1.0))
			rise *= smoothstep(0.0, HILL_REACH, p.distance_to(nearest))
	return height * rise

static func _hill_point(cell: Vector2i, blocked: Dictionary, u: float, v: float, half: float, _step: float, _ix: int, _iz: int, height: float, noise: FastNoiseLite, bump: float, tile: float) -> Vector3:
	var x: float = -half + u * tile
	var z: float = -half + v * tile
	var y: float = hill_height_at(cell, blocked, u, v, height)
	if noise != null and y > 0.001:
		# Scaled by how high this point already is, so the rubble never lifts the base
		# off the ground or pokes through a neighbour's shared edge.
		y += noise.get_noise_2d((float(cell.x) + u) * tile, (float(cell.y) + v) * tile) * bump * (y / height)
	return Vector3(x, y, z)

# ==============================================================================
# Plumbing
# ==============================================================================

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Callable) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_color(tint.call(p))
		st.add_vertex(p)

static func _terrain(cfg: Node) -> Dictionary:
	if cfg and "TERRAIN" in cfg:
		return cfg.TERRAIN
	return {}

## The noise the ground mesh is built with, for anything that has to stand ON that
## ground: pass it to ground_height. Without it, ground_height is the valley's smooth
## shape, and the wall the player sees wobbles up to two metres either side of that --
## measured, 2.18 m at worst and 0.39 m on average 30-50 m out. The forest and the cliffs
## were placed on the smooth shape and floated or sank by exactly that much.
static func ground_noise(cfg: Node) -> FastNoiseLite:
	return _noise(cfg)

## Seeded from Config so two runs produce the same landscape. A world that reshuffles
## itself every launch cannot be photographed, compared, or balanced against.
static func _noise(cfg: Node) -> FastNoiseLite:
	return _noise_from(_terrain(cfg))

static func _noise_from(t: Dictionary) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = int(t.get("noise_seed", 20260917))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = float(t.get("noise_frequency", 0.018))
	n.fractal_octaves = 3
	return n
