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

## The valley floor and the land around it, as one mesh centred on the origin.
static func build_ground(cfg: Node) -> Mesh:
	var t: Dictionary = _terrain(cfg)
	var field_half: float = float(t.get("field_half", 22.0))
	var outer_half: float = float(t.get("outskirts_half", 110.0))
	var quad: float = maxf(1.0, float(t.get("quad_size", 4.0)))
	var steps: int = int(ceil((outer_half * 2.0) / quad))
	var noise := _noise(cfg)

	var grass: Color = _colour(cfg, "ground", Color(0.28, 0.32, 0.24))
	var rock: Color = _colour(cfg, "hill", Color(0.36, 0.33, 0.28))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(steps):
		for ix in range(steps):
			var x0: float = -outer_half + float(ix) * quad
			var z0: float = -outer_half + float(iz) * quad
			var x1: float = x0 + quad
			var z1: float = z0 + quad
			_ground_quad(st, x0, z0, x1, z1, field_half, outer_half, t, noise, grass, rock)
	st.generate_normals()
	return st.commit()

static func _ground_quad(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite, grass: Color, rock: Color) -> void:
	var corners: Array[Vector3] = [
		_ground_point(x0, z0, field_half, outer_half, t, noise),
		_ground_point(x1, z0, field_half, outer_half, t, noise),
		_ground_point(x1, z1, field_half, outer_half, t, noise),
		_ground_point(x0, z1, field_half, outer_half, t, noise),
	]
	var tint: Array[Color] = []
	for p in corners:
		tint.append(_ground_colour(p, field_half, outer_half, t, noise, grass, rock))
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(tint[i])
		st.add_vertex(corners[i])

## Grass where the ground is flat, rock where it is steep, with the valley floor broken
## up a little so it is not one flat wash of green.
##
## Slope-blended vertex colour, because without it the rising land is exactly the same
## green as the field and the whole thing reads as an endless lawn rather than as a
## valley. It costs one extra float per vertex and no textures at all, which is the best
## trade available before real materials arrive.
static func _ground_colour(p: Vector3, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite, grass: Color, rock: Color) -> Color:
	var slope: float = _slope_at(p.x, p.z, field_half, outer_half, t, noise)
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

## Height of the ground at a world point.
##
## Flat and exactly zero anywhere the game is played, then climbing. The transition
## uses smoothstep so there is no crease where the field ends -- a hard ring would read
## as a wall around an arena, which is the opposite of what this is for.
static func ground_height(x: float, z: float, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite) -> float:
	var d: float = sqrt(x * x + z * z)
	if d <= field_half:
		return 0.0
	# The climb is measured over `rim_span`, not over the whole ground. Tying it to the
	# outer extent made the valley wall rise so gently that the fog swallowed it before
	# it was tall enough to see -- the ground just faded to grey and the valley was a
	# claim rather than a thing on screen.
	var span: float = maxf(1.0, float(t.get("rim_span", 38.0)))
	var climb: float = smoothstep(field_half, field_half + span, d)
	var rise: float = float(t.get("rim_rise", 18.0)) * climb * climb
	var wobble: float = 0.0
	if noise != null:
		# Scaled by the climb as well, so the wobble fades out to nothing rather than
		# rippling the last metre of flat ground the player builds on.
		wobble = noise.get_noise_2d(x, z) * float(t.get("rim_noise", 4.0)) * climb
	return rise + wobble

static func _ground_point(x: float, z: float, field_half: float, outer_half: float, t: Dictionary, noise: FastNoiseLite) -> Vector3:
	return Vector3(x, ground_height(x, z, field_half, outer_half, t, noise), z)

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

## Seeded from Config so two runs produce the same landscape. A world that reshuffles
## itself every launch cannot be photographed, compared, or balanced against.
static func _noise(cfg: Node) -> FastNoiseLite:
	var t: Dictionary = _terrain(cfg)
	var n := FastNoiseLite.new()
	n.seed = int(t.get("noise_seed", 20260917))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = float(t.get("noise_frequency", 0.018))
	n.fractal_octaves = 3
	return n
