# res://scripts/fx/River.gd
class_name River
extends RefCounted

## The river that runs past the field, and the channel it cuts in the ground.
##
## It comes down the north-west wall as white water, winds along the valley floor just
## outside the square the game is played on -- closest where the Hero draws water -- and
## leaves through a canyon in the south-west wall that bends out of sight behind the rim.
## A river has to come from somewhere and go somewhere; one that stopped in a pond at the
## field's edge would be a moat.
##
## The channel is part of the GROUND, not a thing laid on it: TerrainBuilder.ground_height
## carves it, so every tree, herd and camera that asks where the ground is gets the river
## bank for free, and nothing needs to know there is a river to stand beside it rather than
## over it. The water is a separate surface lying in that channel.
##
## Scenery, like the herds and the volcanoes: nothing here collides, nothing is on the grid,
## and the channel never reaches the square the game is played on -- it stops short of it by
## construction, and tests/test_v05_the_river.gd holds it there.
##
## The water level is not declared anywhere. It is worked out from the ground the river runs
## through: always below both banks, and never rising downstream. So the water cannot float
## above a dip in the land, and cannot run uphill -- where the land rises across its course,
## the channel cuts through the rise instead, which is how a gorge gets made.

const STEP := 0.5          # metres between samples along the course
const SOFT := 0.3          # how softly a bank rounds over into the land beside it, in metres
const NEAR := 6.0          # how far past the channel's edge the lookup grid still answers

var curve: Curve2D = null
var length: float = 0.0
var _pos := PackedVector2Array()     # the middle of the river at each sample
var _tan := PackedVector2Array()     # the way it flows there
var _w := PackedFloat32Array()       # half the width of the water
var _level := PackedFloat32Array()   # the height of the water's surface
var _bank := PackedFloat32Array()    # how steeply the banks rise, metres up per metre across
var _depth := PackedFloat32Array()   # how far below the surface the middle of the bed is
var _reach_pos := PackedFloat32Array()  # how far out the channel reaches, on each side
var _reach_neg := PackedFloat32Array()
var _rough: FastNoiseLite = null
var _roughness: float = 0.0
var _overhang: float = 0.8
var _natural: Callable
# The lookup grid, in the ground mesh's own cells so a cell here IS a quad there.
var _grid_origin: float = -110.0
var _grid_cell: float = 4.0
var _carve_cells: Dictionary = {}    # cells the channel touches: refined in the ground mesh
var _near_cells: Dictionary = {}     # those, and every cell NEAR metres past them

## The river `spec` describes (Config.TERRAIN.river), cut into the ground `natural(x, z)`
## returns -- the land as it would be without it. `grid_origin` / `grid_cell` are the
## ground mesh's own corner and quad size. Null if there is no course to follow.
static func build(spec: Dictionary, natural: Callable, grid_origin: float, grid_cell: float) -> River:
	var course: Array = spec.get("course", [])
	if course.size() < 2:
		return null
	var r := River.new()
	r._natural = natural
	r._grid_origin = grid_origin
	r._grid_cell = maxf(0.5, grid_cell)
	r._overhang = float(spec.get("overhang", 0.8))
	r._roughness = float(spec.get("roughness", 0.3))
	if r._roughness > 0.0:
		r._rough = FastNoiseLite.new()
		r._rough.seed = int(spec.get("seed", 1))
		r._rough.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		r._rough.frequency = float(spec.get("roughness_scale", 0.12))
		r._rough.fractal_octaves = 2
	r._lay_the_course(course)
	r._find_the_water(float(spec.get("margin", 0.35)), float(spec.get("fall", 0.002)))
	r._find_the_banks()
	return r

# ==============================================================================
# Building it
# ==============================================================================

## The middle of the river as a smooth curve through the declared points -- Catmull-Rom,
## so it passes through every one of them -- and the widths and bank slopes between them.
func _lay_the_course(course: Array) -> void:
	var pts := PackedVector2Array()
	var widths := PackedFloat32Array()
	var banks := PackedFloat32Array()
	for c in course:
		pts.append(c["at"])
		widths.append(float(c.get("half_width", 2.0)))
		banks.append(float(c.get("bank", 0.8)))
	curve = Curve2D.new()
	curve.bake_interval = STEP
	for i in range(pts.size()):
		var handle: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]) / 6.0
		curve.add_point(pts[i], -handle, handle)
	length = curve.get_baked_length()
	var at := PackedFloat32Array()
	for p in pts:
		at.append(curve.get_closest_offset(p))
	var n: int = int(ceil(length / STEP)) + 1
	var k: int = 0
	for i in range(n):
		var s: float = minf(float(i) * STEP, length)
		_pos.append(curve.sample_baked(s, true))
		var ahead: Vector2 = curve.sample_baked(minf(length, s + STEP * 0.5), true)
		var behind: Vector2 = curve.sample_baked(maxf(0.0, s - STEP * 0.5), true)
		_tan.append((ahead - behind).normalized())
		while k < at.size() - 2 and s > at[k + 1]:
			k += 1
		var u: float = clampf((s - at[k]) / maxf(0.001, at[k + 1] - at[k]), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		var w: float = lerpf(widths[k], widths[k + 1], u)
		_w.append(w)
		_bank.append(lerpf(banks[k], banks[k + 1], u))
		_depth.append(clampf(w * 0.32, 0.35, 1.0))

## The surface: a little below the lowest ground on either bank, and never higher than it
## was upstream. `fall` is the least it drops per metre, so there is always a current.
func _find_the_water(margin: float, fall: float) -> void:
	var upstream: float = INF
	for i in range(_pos.size()):
		var nrm := Vector2(-_tan[i].y, _tan[i].x)
		var reach: float = _w[i] + 1.0
		var lowest: float = INF
		var l: float = -reach
		while l <= reach + 0.001:
			var q: Vector2 = _pos[i] + nrm * l
			lowest = minf(lowest, float(_natural.call(q.x, q.y)))
			l += 0.5
		var surface: float = minf(upstream - fall * STEP, lowest - margin)
		_level.append(surface)
		upstream = surface

## How far out from the middle the channel changes the ground, on each side: out to where
## its bank has risen clear of the land. Past that the land is left exactly as it was --
## including where the valley wall climbs faster than the bank does, which would otherwise
## let the bank's slope carry on cutting a terrace all the way up the wall.
func _find_the_banks() -> void:
	for i in range(_pos.size()):
		var nrm := Vector2(-_tan[i].y, _tan[i].x)
		for side in [1.0, -1.0]:
			var l: float = _w[i]
			while l < _w[i] + 40.0:
				var q: Vector2 = _pos[i] + nrm * (l * side)
				if _channel(float(i), l, q.x, q.y) > float(_natural.call(q.x, q.y)) + SOFT:
					break
				l += 0.25
			if side > 0.0:
				_reach_pos.append(l)
			else:
				_reach_neg.append(l)
			# The cells this stretch of bank lies across, and the ones near it.
			var d: float = 0.0
			while d <= l + NEAR:
				var q2: Vector2 = _pos[i] + nrm * (d * side)
				var cell := cell_of(q2.x, q2.y)
				_near_cells[cell] = true
				if d <= l + 1.5:
					_carve_cells[cell] = true
				d += 0.5

# ==============================================================================
# Asking it things
# ==============================================================================

## The ground mesh's cell (x, z) falls in.
func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor((x - _grid_origin) / _grid_cell)), int(floor((z - _grid_origin) / _grid_cell)))

## Whether the channel reaches into this cell of the ground mesh. Those cells are drawn
## finer: a channel a few metres wide cannot be drawn on quads four metres across.
func is_carve_cell(cell: Vector2i) -> bool:
	return _carve_cells.has(cell)

## Where (x, z) is from the river: x = how far along the course, in samples; y = how far
## to one side of the middle, in metres (signed); z = 1 when it is anywhere near, else 0.
func locate(x: float, z: float) -> Vector3:
	if not _near_cells.has(cell_of(x, z)):
		return Vector3.ZERO
	var p := Vector2(x, z)
	var s: float = curve.get_closest_offset(p)
	var c: Vector2 = curve.sample_baked(s, false)
	var f: float = clampf(s / STEP, 0.0, float(_pos.size() - 1))
	var t: Vector2 = _tan[int(round(f))]
	var d: Vector2 = p - c
	var lateral: float = d.length()
	if d.dot(Vector2(-t.y, t.x)) < 0.0:
		lateral = -lateral
	return Vector3(f, lateral, 1.0)

## The ground at (x, z) with the channel cut into it, `natural` being the land without it.
func carve(x: float, z: float, natural: float) -> float:
	return carve_at(locate(x, z), x, z, natural)

## carve(), for a point already located -- the ground mesh asks several things of each.
func carve_at(loc: Vector3, x: float, z: float, natural: float) -> float:
	if loc.z == 0.0:
		return natural
	var lateral: float = absf(loc.y)
	var reach: float = _sample(_reach_pos if loc.y >= 0.0 else _reach_neg, loc.x)
	if lateral > reach:
		return natural
	return _smin(natural, _channel(loc.x, lateral, x, z), SOFT)

## The height of the water's surface beside a located point.
func level_at(loc: Vector3) -> float:
	return _sample(_level, loc.x)

## How far (x, z) is from the water's edge: negative in the water. NEAR when it is further
## than that from the channel -- the answer is only exact up to there.
func water_clearance(x: float, z: float) -> float:
	var loc := locate(x, z)
	if loc.z == 0.0:
		return NEAR
	return absf(loc.y) - _sample(_w, loc.x)

## How far (x, z) is from the edge of the channel -- the top of its bank: negative on the
## bank or in the water. NEAR when it is further than that.
func bank_clearance(x: float, z: float) -> float:
	var loc := locate(x, z)
	if loc.z == 0.0:
		return NEAR
	return absf(loc.y) - _sample(_reach_pos if loc.y >= 0.0 else _reach_neg, loc.x)

## The ground with the channel in it -- the same answer as TerrainBuilder.ground_height.
func ground_at(x: float, z: float) -> float:
	return carve(x, z, float(_natural.call(x, z)))

## How many samples there are along the course, and what is at each: for the water surface
## and for whatever is placed along the banks.
func sample_count() -> int:
	return _pos.size()

func point(i: int) -> Vector2:
	return _pos[i]

func flow(i: int) -> Vector2:
	return _tan[i]

func half_width(i: int) -> float:
	return _w[i]

func level(i: int) -> float:
	return _level[i]

func reach(i: int, side: float) -> float:
	return _reach_pos[i] if side >= 0.0 else _reach_neg[i]

## How steeply the surface falls at sample i, metres down per metre along.
func fall_at(i: int) -> float:
	var a: int = maxi(0, i - 2)
	var b: int = mini(_pos.size() - 1, i + 2)
	if b <= a:
		return 0.0
	return (_level[a] - _level[b]) / (float(b - a) * STEP)

## The tightest bend on the inside, as a radius in metres, between samples a and b.
func tightest_bend(a: int = 0, b: int = -1) -> float:
	if b < 0:
		b = _pos.size() - 1
	var tightest: float = INF
	for i in range(maxi(1, a), mini(b, _pos.size() - 2) + 1):
		var turn: float = absf(_tan[i - 1].angle_to(_tan[i + 1]))
		if turn > 0.00001:
			tightest = minf(tightest, (2.0 * STEP) / turn)
	return tightest

# ==============================================================================
# The water
# ==============================================================================

## The water's surface: a ribbon down the middle of the channel, level from bank to bank,
## running `overhang` metres in under each bank so its edge is always inside the ground and
## the shoreline the player sees is where water meets earth rather than where a mesh stops.
##
## UV: u across in metres; v along, in metres of TRAVEL rather than of distance -- slowed
## where the river is calm and wide, hurried where it falls -- so one steady scroll of the
## texture makes white water race and the canyon pool drift. The ripples stretch where it
## is fast, which is what fast water looks like.
##
## Vertex colour carries the water's own colour and, where it falls steeply, foam.
func water_mesh(spec: Dictionary, bounds_half: float) -> ArrayMesh:
	var calm: Color = spec.get("colour", Color(0.10, 0.20, 0.18, 0.86))
	var foam: Color = spec.get("foam", Color(0.72, 0.78, 0.74, 0.95))
	var foam_from: float = float(spec.get("foam_from", 0.05))
	var foam_full: float = float(spec.get("foam_full", 0.25))
	var hurry: float = float(spec.get("hurry", 10.0))
	# Streaks: the foam comes and goes along the stream, so white water is broken water.
	var streaks := FastNoiseLite.new()
	streaks.seed = int(spec.get("seed", 1)) + 3
	streaks.frequency = 0.35
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var travel: float = 0.0
	var prev: Array = []
	for i in range(_pos.size()):
		var p: Vector2 = _pos[i]
		if absf(p.x) > bounds_half or absf(p.y) > bounds_half:
			prev = []
			continue
		var nrm := Vector2(-_tan[i].y, _tan[i].x)
		var fall: float = fall_at(i)
		var speed: float = clampf(1.0 + hurry * fall, 1.0, 6.0)
		if i > 0:
			travel += STEP / speed
		var froth: float = smoothstep(foam_from, foam_full, fall) * (0.6 + 0.4 * streaks.get_noise_1d(float(i) * STEP))
		var col: Color = calm.lerp(foam, froth)
		var edge: Color = calm.lerp(foam, froth * 0.35)
		var y: float = _level[i]
		# Never further under a bank than the bend allows, or the inside of a bend folds.
		var out_pos: float = minf(_w[i] + _overhang, _reach_pos[i])
		var out_neg: float = minf(_w[i] + _overhang, _reach_neg[i])
		var left := Vector3(p.x + nrm.x * out_pos, y, p.y + nrm.y * out_pos)
		var right := Vector3(p.x - nrm.x * out_neg, y, p.y - nrm.y * out_neg)
		var mid := Vector3(p.x, y, p.y)
		var row: Array = [
			[left, Vector2(out_pos, travel), edge],
			[mid, Vector2(0.0, travel), col],
			[right, Vector2(-out_neg, travel), edge],
		]
		if prev.size() == 3:
			for k in range(2):
				_water_tri(st, prev[k], row[k], row[k + 1])
				_water_tri(st, prev[k], row[k + 1], prev[k + 1])
		prev = row
	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func _water_tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	for v in [a, c, b]:
		st.set_color(v[2])
		st.set_uv(v[1])
		st.add_vertex(v[0])

## What the water is drawn with: the engine's own material, see-through enough to show the
## bed where it is shallow and fading out altogether against the bank (proximity fade --
## the soft shoreline), glossy for the sky and the sun's glints, with a noise normal map
## for the ripples. The ripples are moved along by a tween on the node that shows it (see
## flow_tween), so there is no shader here to keep in step with the engine.
static func water_material(spec: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = float(spec.get("roughness", 0.07))
	mat.metallic = 0.0
	mat.metallic_specular = float(spec.get("specular", 0.6))
	mat.normal_enabled = true
	mat.normal_scale = float(spec.get("ripple_depth", 0.55))
	var noise := FastNoiseLite.new()
	noise.seed = int(spec.get("seed", 1)) + 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = float(spec.get("ripple_bump", 6.0))
	mat.normal_texture = tex
	var tile: float = maxf(0.5, float(spec.get("ripple_size", 5.0)))
	mat.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = float(spec.get("shore_fade", 0.5))
	return mat

## Sets the ripples moving downstream on `water`, for as long as it exists: one whole tile
## of the seamless texture per loop, so the loop has no seam. Bound to the node, so it
## goes when the node goes (a tween owned by anything else calls into a freed object).
static func flow_tween(water: MeshInstance3D, mat: StandardMaterial3D, spec: Dictionary) -> Tween:
	var tile: float = maxf(0.5, float(spec.get("ripple_size", 5.0)))
	var speed: float = maxf(0.05, float(spec.get("speed", 0.6)))
	var tw := water.create_tween().set_loops()
	tw.tween_property(mat, "uv1_offset", Vector3(0.0, -1.0, 0.0), tile / speed).from(Vector3.ZERO)
	return tw

# ==============================================================================
# What stands along it
# ==============================================================================

## Where the plants along the banks go: `count` of them on the calm, low stretches -- the
## valley floor and the canyon's mouth, where anyone can see them -- from `from_edge` to
## `to_edge` metres out from the water's edge (negative is in the shallows), on either
## side. Nothing inside `keep_out_half` of the middle on either axis: that square is where
## the game is played, and a reed there would stand on a cell the grid says is open.
func bank_placements(seed_value: int, count: int, from_edge: float, to_edge: float,
		keep_out_half: float, scale_range: Vector2) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Transform3D] = []
	var attempts: int = 0
	while out.size() < count and attempts < count * 20:
		attempts += 1
		var i: int = rng.randi_range(0, _pos.size() - 1)
		var side: float = 1.0 if rng.randf() < 0.5 else -1.0
		var off: float = _w[i] + rng.randf_range(from_edge, to_edge)
		var spin: float = rng.randf_range(0.0, TAU)
		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		if fall_at(i) > 0.06 or _level[i] > 3.0:
			continue
		var nrm := Vector2(-_tan[i].y, _tan[i].x) * side
		var at: Vector2 = _pos[i] + nrm * off
		if maxf(absf(at.x), absf(at.y)) < keep_out_half + 0.3:
			continue
		var y: float = ground_at(at.x, at.y)
		if y < _level[i] - 0.25:
			continue         # deeper than a horsetail stands in
		out.append(Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * s), Vector3(at.x, y - 0.05, at.y)))
	return out

## Boulders in the white water: in the stream where it falls fastest, half sunk in its bed,
## so the water runs round rocks rather than down a smooth chute.
func boulder_placements(seed_value: int, count: int, scale_range: Vector2) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Transform3D] = []
	var attempts: int = 0
	while out.size() < count and attempts < count * 40:
		attempts += 1
		var i: int = rng.randi_range(0, _pos.size() - 1)
		var off: float = rng.randf_range(-0.85, 0.85) * _w[i]
		var spin: float = rng.randf_range(0.0, TAU)
		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		if fall_at(i) < 0.08:
			continue
		var at: Vector2 = _pos[i] + Vector2(-_tan[i].y, _tan[i].x) * off
		var y: float = ground_at(at.x, at.y)
		out.append(Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * s), Vector3(at.x, y - 0.1 * s, at.y)))
	return out

## Stepping stones from `from` -- the water spot -- down the bank into the edge of the
## water, along the shortest way to it. None inside `keep_out_half`: the square the game
## is played on stays open ground.
func landing_placements(from: Vector3, count: int, keep_out_half: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var start := Vector2(from.x, from.z)
	var nearest: Vector2 = curve.get_closest_point(start)
	var dir: Vector2 = (nearest - start).normalized()
	if dir == Vector2.ZERO or count <= 0:
		return out
	# From the edge of the square (or the spot, if it is outside) to just into the water.
	var a: float = 0.0
	while maxf(absf(start.x + dir.x * a), absf(start.y + dir.y * a)) < keep_out_half + 0.35 and a < 20.0:
		a += 0.05
	var b: float = a
	while water_clearance(start.x + dir.x * b, start.y + dir.y * b) > -0.3 and b < a + 20.0:
		b += 0.05
	var side := Vector2(-dir.y, dir.x)
	for k in range(count):
		var u: float = (float(k) + 0.5) / float(count)
		var at: Vector2 = start + dir * lerpf(a, b, u) + side * (0.22 if k % 2 == 0 else -0.22)
		var y: float = ground_at(at.x, at.y)
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.y) + float(k) * 0.7).scaled(Vector3(1.25, 0.4, 0.95))
		out.append(Transform3D(basis, Vector3(at.x, y - 0.03, at.y)))
	return out

# ==============================================================================
# Plumbing
# ==============================================================================

## The channel's own shape at `lateral` metres from the middle of sample `f`: a rounded bed
## under the water, then a bank rising from the water's edge. The bank is broken up by
## noise, more the higher it climbs, so a canyon wall has buttresses and bays rather than
## being a ruled slope.
func _channel(f: float, lateral: float, x: float, z: float) -> float:
	var w: float = _sample(_w, f)
	var surface: float = _sample(_level, f)
	if lateral <= w:
		var q: float = lateral / maxf(0.01, w)
		return surface - _sample(_depth, f) * (1.0 - q * q)
	var rise: float = (lateral - w) * _sample(_bank, f)
	if _rough != null:
		rise *= 1.0 + _roughness * _rough.get_noise_2d(x, z)
	return surface + rise

## A per-sample value at a fractional sample, straight-line between the two either side.
func _sample(arr: PackedFloat32Array, f: float) -> float:
	var i: int = int(floor(f))
	if i >= arr.size() - 1:
		return arr[arr.size() - 1]
	if i < 0:
		return arr[0]
	return lerpf(arr[i], arr[i + 1], f - float(i))

## A minimum with the corner rounded off over `k`: where the bank meets the land there is
## no crease. Exactly the plain minimum wherever the two are more than `k` apart.
static func _smin(a: float, b: float, k: float) -> float:
	var h: float = maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25
