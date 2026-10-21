class_name Kit
## What the homeland's buildings are made of (GAME-DESIGN 24): shaped parts -- rounded blocks, turned shapes (a basin, a
## dome, a vat, an egg), roofs, posts and planks, stones -- in a few materials (painted wood and stone with a grain in
## them, brass, glass, a glowing fluid), each building's gathered into one mesh. Every part darkens toward the ground, as
## a painter shades a thing standing in grass, so a building sits in the ground rather than on it.

const SHADE_LOW := 0.72            # how dark a part is where it meets the ground...
const SHADE_UP := 1.3              # ...growing light over this many metres

static var _mats := {}
static var _meshes := {}


## A building's parts gathered: a surface for each material.
class Maker:
	var _parts := {}               # material's id -> Part
	var dry := false               # the mesh is made already: parts are not gathered again

	class Part:
		var mat: Material
		var v := PackedVector3Array()
		var n := PackedVector3Array()
		var uv := PackedVector2Array()
		var c := PackedColorArray()
		var i := PackedInt32Array()

	## `mesh` (its first surface) placed by `xf`, in `mat`, coloured `tint` (multiplied into the material's colour) and
	## shaded toward the ground.
	func put(mesh: Mesh, xf: Transform3D, mat: Material, tint := Color.WHITE) -> void:
		if dry:
			return
		var key := mat.get_instance_id()
		if not _parts.has(key):
			var made := Part.new()
			made.mat = mat
			_parts[key] = made
		var p: Part = _parts[key]
		var arr := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: Variant = arr[Mesh.ARRAY_TEX_UV]
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		var base := p.v.size()
		var nb := xf.basis.inverse().transposed()
		var has_uv := uvs != null and (uvs as PackedVector2Array).size() == verts.size()
		for k in verts.size():
			var at := xf * verts[k]
			p.v.append(at)
			p.n.append((nb * norms[k]).normalized())
			p.uv.append((uvs as PackedVector2Array)[k] if has_uv else Vector2.ZERO)
			p.c.append(tint * Color(1, 1, 1).darkened(1.0 - lerpf(SHADE_LOW, 1.0, smoothstep(0.0, SHADE_UP, at.y))))
		if idx == null or (idx as PackedInt32Array).is_empty():
			for k in verts.size():
				p.i.append(base + k)
		else:
			for k: int in idx:
				p.i.append(base + k)

	## All of it as one mesh.
	func mesh() -> ArrayMesh:
		var out := ArrayMesh.new()
		for key in _parts:
			var p: Part = _parts[key]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = p.v
			arr[Mesh.ARRAY_NORMAL] = p.n
			arr[Mesh.ARRAY_TEX_UV] = p.uv
			arr[Mesh.ARRAY_COLOR] = p.c
			arr[Mesh.ARRAY_INDEX] = p.i
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(out.get_surface_count() - 1, p.mat)
		return out


## How a part is shaded at height `y` (metres above the ground): dark where it meets the grass, its own colour higher up.
static func shade(y: float) -> Color:
	var k := lerpf(SHADE_LOW, 1.0, smoothstep(0.0, SHADE_UP, y))
	return Color(k, k, k)


static func at(pos: Vector3, turn := 0.0, size := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, turn).scaled(size), pos)


## `xf` tilted about its own x (forward, +) and z.
static func tilt(xf: Transform3D, x: float, z := 0.0) -> Transform3D:
	return Transform3D(xf.basis * Basis.from_euler(Vector3(x, 0.0, z)), xf.origin)


# -- Materials ------------------------------------------------------------------------------------------------------

## Painted matter -- wood, stone, cloth, thatch: the part's own colour (its tint), a fine grain laid on from the world's
## three sides, no gloss, a faint rim of light.
static func paint() -> StandardMaterial3D:
	if not _mats.has("paint"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.albedo_texture = Ground.grain()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.45
		m.roughness = 0.88
		m.metallic_specular = 0.25
		m.rim_enabled = true
		m.rim = 0.12
		m.rim_tint = 0.6
		_mats["paint"] = m
	return _mats["paint"]


## Brass and copper: a soft metal shine, its tint the metal's colour.
static func metal() -> StandardMaterial3D:
	if not _mats.has("metal"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.metallic = 0.7
		m.roughness = 0.36
		m.rim_enabled = true
		m.rim = 0.2
		m.rim_tint = 0.3
		_mats["metal"] = m
	return _mats["metal"]


## Glass: clear, a little blue-green, shining where it turns from the eye.
static func glass() -> StandardMaterial3D:
	if not _mats.has("glass"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.78, 0.95, 1.0, 0.24)
		m.roughness = 0.06
		m.metallic_specular = 0.9
		m.rim_enabled = true
		m.rim = 0.7
		m.rim_tint = 0.2
		m.cull_mode = BaseMaterial3D.CULL_BACK
		_mats["glass"] = m
	return _mats["glass"]


## Still water: deep blue-green, a little gloss.
static func water() -> StandardMaterial3D:
	if not _mats.has("water"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.42, 0.5)
		m.roughness = 0.12
		m.metallic_specular = 0.7
		m.rim_enabled = true
		m.rim = 0.3
		_mats["water"] = m
	return _mats["water"]


## A gene fluid in glass: glowing its colour `c`, half seen through.
static func fluid(c: Color, strength := 0.9) -> StandardMaterial3D:
	var key := "fluid%s%.2f" % [c.to_html(), strength]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(c, 0.6)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = strength
		m.roughness = 0.2
		_mats[key] = m
	return _mats[key]


## Something glowing its colour `c` (a gene fluid, an egg, a lamp).
static func glow(c: Color, strength := 1.2) -> StandardMaterial3D:
	var key := "glow%s%.2f" % [c.to_html(), strength]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = strength
		m.roughness = 0.4
		_mats[key] = m
	return _mats[key]


# -- Shapes (each made once, shared) ---------------------------------------------------------------------------------

static func box(size: Vector3) -> Mesh:
	return Blocks.rounded(size)


## A round post or drum: `bottom` and `top` its radii.
static func cyl(bottom: float, top: float, h: float, seg := 16) -> Mesh:
	var key := "cyl%.3f/%.3f/%.3f/%d" % [bottom, top, h, seg]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.bottom_radius = bottom
		m.top_radius = top
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


## A ball `r` across its middle, `squash` as tall as wide.
static func ball(r: float, squash := 1.0, seg := 16) -> Mesh:
	var key := "ball%.3f/%.3f/%d" % [r, squash, seg]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0 * squash
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		_meshes[key] = m
	return _meshes[key]


## A ring lying flat: `r` to its tube's middle, the tube `thick` across.
static func ring(r: float, thick: float, seg := 24) -> Mesh:
	var key := "ring%.3f/%.3f/%d" % [r, thick, seg]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = r - thick * 0.5
		m.outer_radius = r + thick * 0.5
		m.rings = seg
		m.ring_segments = 8
		_meshes[key] = m
	return _meshes[key]


## A gable roof: a ridge along x, `size` its width (x), height and depth (z).
static func gable(size: Vector3) -> Mesh:
	var key := "gable%.3f/%.3f/%.3f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var m := PrismMesh.new()
		m.size = Vector3(size.z, size.y, size.x)
		_meshes[key] = _turned(m, Basis(Vector3.UP, PI * 0.5))
	return _meshes[key]


## A shape turned about the upright from `profile` -- (radius, height) from the bottom up -- with `seg` sides; a cap
## where a radius closes to nought is the profile's own point.
static func lathe(profile: PackedVector2Array, seg := 20) -> ArrayMesh:
	var key := "lathe%s/%d" % [str(profile), seg]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := profile.size()
	# The profile's slope at each point (for smooth normals along it).
	for i in n:
		var a := profile[maxi(i - 1, 0)]
		var b := profile[mini(i + 1, n - 1)]
		var along := (b - a).normalized()
		var out := Vector2(along.y, -along.x)          # outward, in (radius, height)
		for j in seg + 1:
			var t := TAU * float(j) / seg
			var dir := Vector3(cos(t), 0.0, sin(t))
			verts.append(dir * profile[i].x + Vector3.UP * profile[i].y)
			norms.append((dir * out.x + Vector3.UP * out.y).normalized())
			uvs.append(Vector2(float(j) / seg, float(i) / maxi(n - 1, 1)))
	for i in n - 1:
		for j in seg:
			var a := i * (seg + 1) + j
			var b := a + seg + 1
			idx.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes[key] = m
	return m


## An egg standing on its end, `r` across its middle.
static func egg(r: float) -> ArrayMesh:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * float(i) / 12.0          # from the bottom point up to the top one
		var y := -cos(a)
		var w := sin(a) * (1.0 - 0.18 * y)    # broader below than above
		pts.append(Vector2(w * r, (y + 1.0) * r * 1.25))
	return lathe(pts, 14)


## A rock of a few broad facets, `size` across.
static func rock() -> Mesh:
	return Ground.stone_mesh()


## `mesh` turned by `basis`, as a mesh of its own.
static func _turned(mesh: Mesh, basis: Basis) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = basis * verts[i]
		norms[i] = basis * norms[i]
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


# -- The buildings ---------------------------------------------------------------------------------------------------
# Each after its card's painting (tools/paint_cards.py), standing on its plot (about 3 m across), its front to the
# south (+z, the camera's side). A level up makes it a little bigger and adds to it.

const STONE := Color(0.8, 0.77, 0.7)
const STONE_DARK := Color(0.56, 0.54, 0.5)
const WOOD := Color(0.5, 0.35, 0.22)
const WOOD_LIGHT := Color(0.74, 0.57, 0.37)
const THATCH := Color(0.84, 0.7, 0.42)
const MOSS := Color(0.42, 0.6, 0.26)
const LEAF := Color(0.32, 0.56, 0.24)
const BRASS := Color(0.92, 0.7, 0.34)
const COPPER := Color(0.84, 0.5, 0.32)
const IRON := Color(0.42, 0.42, 0.45)
const BONE := Color(0.94, 0.91, 0.8)
const SOIL := Color(0.46, 0.34, 0.24)
const GOLD := Color(1.0, 0.8, 0.28)
const DARK := Color(0.08, 0.07, 0.06)

static var _built := {}            # "kind/level" -> ArrayMesh


## A small node that turns about its upright (the stabilizer's rings).
class Spin extends Node3D:
	var speed := 0.6

	func _process(delta: float) -> void:
		rotate_y(speed * delta)


## Building `kind` at level `lv` (1..Content.LEVEL_MAX), as its painting shows it: one mesh (shared by every one of
## that kind and level), and what moves as nodes of its own. Its height, for what is shown over it, in meta "height".
static func building(kind: String, lv: int) -> Node3D:
	var root := Node3D.new()
	var key := "%s/%d" % [kind, lv]
	var m := Maker.new()
	m.dry = _built.has(key)
	var h := 1.5
	match kind:
		"nest_red": h = _nest_red(m, lv)
		"nest_blue": h = _nest_blue(m, lv)
		"nest_green": h = _nest_green(m, lv)
		"nest_gold": h = _nest_gold(m, lv)
		"nest_white": h = _nest_white(m, lv)
		"nest_scav": h = _nest_scav(m, lv)
		"nest_mutant": h = _nest_mutant(m, lv)
		"pool": h = _pool(m, lv, false)
		"spore_pool": h = _pool(m, lv, true)
		"horde_totem": h = _totem(m, lv)
		"sampler": h = _sampler(m, lv)
		"stabilizer": h = _stabilizer(m, root, lv)
		"gene_bank": h = _gene_bank(m, lv)
		"mine": h = _mine(m, lv)
		"forge": h = _forge(m, lv)
		"vault": h = _vault(m, lv)
		"market": h = _market(m, lv)
		"champion_hall": h = _hall(m, lv)
		"watchtower": h = _watchtower(m, lv)
		"vanguard": h = _vanguard(m, lv)
	if not _built.has(key):
		_built[key] = m.mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _built[key]
	root.add_child(mi)
	root.set_meta("height", h)
	return root


## Glowing eggs in a cluster round `c`, `r` each across their middle.
static func _eggs(m: Maker, c: Vector3, count: int, r: float, col: Color) -> void:
	var mat := glow(col, 0.7)
	for i in count:
		var a := TAU * i / maxi(count, 1) + 0.6
		var off := Vector3(cos(a), 0.0, sin(a)) * (r * 1.3 if count > 1 else 0.0)
		m.put(egg(r), tilt(at(c + off, a), 0.18 * sin(a * 3.0), 0.18 * cos(a * 2.0)), mat)


## A pole with a cloth hanging from its top, `h` tall.
static func _banner(m: Maker, pos: Vector3, h: float, col: Color, turn := 0.0) -> void:
	var p := paint()
	m.put(cyl(0.05, 0.04, h), at(pos + Vector3(0, h * 0.5, 0)), p, WOOD)
	m.put(ball(0.07), at(pos + Vector3(0, h + 0.04, 0)), metal(), BRASS)
	var side := Basis(Vector3.UP, turn) * Vector3(0.28, 0, 0)
	m.put(box(Vector3(0.52, 0.72, 0.04)), at(pos + side + Vector3(0, h - 0.42, 0), turn), p, col)
	m.put(box(Vector3(0.6, 0.06, 0.06)), at(pos + side + Vector3(0, h - 0.05, 0), turn), p, WOOD)


## A fern: broad leaves fanning out of the ground at `pos`, `s` long.
static func _fern(m: Maker, pos: Vector3, s: float, turn: float) -> void:
	var p := paint()
	for i in 6:
		var a := turn + TAU * i / 6.0
		var leaf := Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.55).scaled(Vector3(0.22, 0.05, 1.0) * s),
			pos + Basis(Vector3.UP, a) * Vector3(0, 0.12 * s, 0.32 * s))
		m.put(ball(0.5, 1.0, 8), leaf, p, LEAF.lightened(0.08 * (i % 2)))


## Stones in a ring round `c`, `r` from it.
static func _stones(m: Maker, c: Vector3, r: float, count: int, size: float, col: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var a := TAU * i / count + rng.randf_range(-0.12, 0.12)
		var s := size * rng.randf_range(0.75, 1.25)
		m.put(rock(), at(c + Vector3(cos(a) * r, s * 0.18, sin(a) * r), rng.randf() * TAU, Vector3(s, s * 0.7, s)), paint(),
			col.lerp(STONE_DARK, rng.randf() * 0.35))


## A post leaning by `lean` toward `toward` (radians), standing on `pos`.
static func _post(m: Maker, pos: Vector3, h: float, r: float, col: Color, toward := 0.0, lean := 0.0, top := -1.0) -> void:
	var axis := Vector3(-sin(toward), 0.0, cos(toward))
	var b := Basis(axis, -lean) if lean != 0.0 else Basis()
	m.put(cyl(r, r if top < 0.0 else top, h, 8), Transform3D(b, pos + b * Vector3(0, h * 0.5, 0)), paint(), col)


## The raptors' den: a mound of earth, a ring of tall stone fangs leaning out round a woven nest of red eggs, a brass
## heat lamp bent over it, a red banner, ferns.
static func _nest_red(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.08 * (lv - 1)
	m.put(lathe(PackedVector2Array([Vector2(1.5, 0.0), Vector2(1.42, 0.16), Vector2(1.1, 0.28), Vector2(0.7, 0.24),
		Vector2(0.0, 0.2)])), at(Vector3.ZERO, 0.0, Vector3(k, 1.0, k)), p, SOIL.lightened(0.12))
	m.put(ring(0.62, 0.28), at(Vector3(0, 0.3, 0.1), 0.0, Vector3(k, 0.8, k)), p, WOOD_LIGHT)
	_eggs(m, Vector3(0, 0.27, 0.1), 3 + lv, 0.16, Color(1.0, 0.36, 0.24))
	var fangs := 7 + 2 * lv
	for i in fangs:
		var a := TAU * i / fangs + 0.3
		var front := sin(a) * 0.5 + 0.5                   # 1 at the front (+z), 0 at the back
		var h := (1.7 - 0.9 * front) * (1.0 + 0.1 * (lv - 1))
		var pos := Vector3(cos(a), 0.0, sin(a)) * 1.25 * k
		_post(m, pos, h, 0.17, STONE.lerp(STONE_DARK, 0.3 * (i % 3) / 2.0), a, 0.28, 0.0)
		if lv >= 3:
			m.put(cyl(0.06, 0.0, 0.22, 6), at(pos + Vector3(cos(a), 0, sin(a)) * h * 0.27 + Vector3(0, h * 0.96, 0)), metal(), GOLD)
	# The heat lamp: a brass post at the back, its arm over the nest, a lamp glowing under its shade.
	m.put(cyl(0.05, 0.05, 1.8, 8), at(Vector3(-0.75, 0.9, -0.55)), metal(), BRASS)
	m.put(cyl(0.04, 0.04, 0.95, 8), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3.UP, 0.6), Vector3(-0.4, 1.78, -0.28)), metal(), BRASS)
	m.put(cyl(0.08, 0.26, 0.22, 12), at(Vector3(-0.05, 1.66, 0.0)), metal(), COPPER)
	m.put(ball(0.11), at(Vector3(-0.05, 1.52, 0.0)), glow(Color(1.0, 0.6, 0.3), 2.0))
	_banner(m, Vector3(0.95, 0.0, -0.85), 2.2 + 0.2 * lv, Color(0.8, 0.22, 0.18), 0.4)
	_fern(m, Vector3(-1.2, 0.0, 1.05), 0.9, 0.3)
	_fern(m, Vector3(1.3, 0.0, 0.9), 0.75, 1.2)
	return 2.4 + 0.2 * lv


## The spitters' hatchery: a pond ringed with stones and reeds, a reed nest of blue eggs high on four stilts over it, a
## ladder up, a copper pipe down to the water; a thatched hood over it as it grows.
static func _nest_blue(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.08 * (lv - 1)
	m.put(cyl(1.4, 1.4, 0.06, 28), at(Vector3(0, 0.03, 0)), water())
	_stones(m, Vector3.ZERO, 1.42, 16, 0.42, STONE, 11)
	var top := 1.5 * k
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			_post(m, Vector3(sx, 0, sz) * k, top, 0.07, WOOD, atan2(sz, sx), 0.06)
	m.put(cyl(0.82, 0.78, 0.12, 16), at(Vector3(0, top, 0), 0.0, Vector3(k, 1, k)), p, WOOD_LIGHT)
	m.put(ring(0.6, 0.26), at(Vector3(0, top + 0.12, 0), 0.0, Vector3(k, 0.9, k)), p, THATCH)
	_eggs(m, Vector3(0, top + 0.08, 0), 3 + lv, 0.15, Color(0.4, 0.7, 1.0))
	# The ladder, leaning on the platform's front.
	for sx in [-0.2, 0.2]:
		m.put(cyl(0.035, 0.035, top + 0.2, 6), tilt(at(Vector3(sx, top * 0.5, 0.95 * k)), -0.32), p, WOOD_LIGHT)
	for i in 5:
		var y := 0.25 + i * top / 5.5
		m.put(cyl(0.025, 0.025, 0.42, 6), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0, y, 0.95 * k + (top * 0.5 - y) * 0.33)), p, WOOD_LIGHT)
	m.put(cyl(0.05, 0.05, top, 8), tilt(at(Vector3(0.78, top * 0.5, -0.25)), 0.0, 0.12), metal(), COPPER)
	for i in 12:
		var a := TAU * i / 12.0 + 0.4
		if sin(a) > 0.55:
			continue                                      # the front left open, the nest to be seen
		var h := 0.7 + 0.35 * fmod(i * 0.37, 1.0)
		var pos := Vector3(cos(a), 0, sin(a)) * 1.2
		m.put(cyl(0.025, 0.012, h, 5), at(pos + Vector3(0, h * 0.5, 0)), p, Color(0.5, 0.62, 0.3))
		if i % 3 == 0:
			m.put(cyl(0.05, 0.05, 0.2, 6), at(pos + Vector3(0, h - 0.05, 0)), p, Color(0.45, 0.3, 0.2))
	if lv >= 2:
		for a in [0.5, 2.6, 4.7]:
			_post(m, Vector3(cos(a), 0, sin(a)) * 0.7 * k + Vector3(0, top, 0), 0.75, 0.035, WOOD)
		m.put(cyl(1.0 * k, 0.05, 0.6, 12), at(Vector3(0, top + 1.0, 0)), p, THATCH)
	if lv >= 3:
		m.put(ring(0.82 * k, 0.05), at(Vector3(0, top + 0.07, 0)), metal(), BRASS)
	return top + (1.4 if lv >= 2 else 0.6)


## The armoured ones' burrow: a squat dome of green stone plates like a tortoise's shell, edged in cream, a low round
## door at the front, green eggs on moss before it; spikes on its plates as it grows, gold on them at the last.
static func _nest_green(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.08 * (lv - 1)
	var shell := Color(0.3, 0.55, 0.3)
	m.put(lathe(PackedVector2Array([Vector2(1.42, 0.0), Vector2(1.4, 0.18), Vector2(1.26, 0.55), Vector2(1.0, 0.86),
		Vector2(0.6, 1.06), Vector2(0.0, 1.14)]), 24), at(Vector3.ZERO, 0.0, Vector3(k, k, k)), p, shell.darkened(0.25))
	m.put(ring(1.4 * k, 0.16), at(Vector3(0, 0.06, 0)), p, Color(0.92, 0.88, 0.72))
	# The plates: six-sided, each laid on the dome where it lies, paler than the seams between them.
	var rows := [[0.0, 1, 0.0], [0.62, 6, 0.0], [1.08, 9, 0.3]]
	for row: Array in rows:
		var polar: float = row[0]
		for i in int(row[1]):
			var a: float = TAU * i / float(row[1]) + float(row[2])
			var n := Vector3(sin(polar) * cos(a), cos(polar), sin(polar) * sin(a))
			var pos := Vector3(n.x * 1.18, n.y * 1.06, n.z * 1.18) * k + Vector3(0, 0.04, 0)
			var b := Basis(Quaternion(Vector3.UP, n.normalized()))
			var size := 0.36 if polar > 0.0 else 0.4
			m.put(cyl(size, size * 0.86, 0.12, 6), Transform3D(b.scaled(Vector3(k, 1, k)), pos), p, shell.lightened(0.12 + 0.05 * (i % 2)))
			if lv >= 2 and polar < 1.0:
				m.put(cyl(0.07, 0.0, 0.24 + 0.08 * (lv - 2), 6), Transform3D(b, pos + n * 0.14), metal() if lv >= 3 else p,
					GOLD if lv >= 3 else Color(0.95, 0.92, 0.8))
	# The door, facing the camera: dark inside, a ring of cream stone round it.
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	m.put(cyl(0.42, 0.42, 0.1, 18), Transform3D(face, Vector3(0, 0.36, 1.26 * k)), p, DARK)
	m.put(ring(0.47, 0.14), Transform3D(face, Vector3(0, 0.36, 1.3 * k)), p, Color(0.9, 0.86, 0.7))
	m.put(cyl(0.6, 0.6, 0.06, 16), at(Vector3(0, 0.03, 1.7)), p, MOSS)
	_eggs(m, Vector3(0, 0.06, 1.68), 2 + lv, 0.14, Color(0.45, 0.95, 0.4))
	return 1.3 * k + 0.3


## The crushers' den: big boulders heaped round a dark cave mouth, bones hung as trophies, golden eggs on straw before
## it; a gold banner on its top as it grows.
static func _nest_gold(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.08 * (lv - 1)
	# The cave's mouth: dark, its round top framed by the boulders heaped about it.
	m.put(cyl(0.52, 0.52, 0.12, 18), Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(k, k, k)), Vector3(0, 0.42, 0.55 * k)), p, DARK)
	var heap := [[Vector3(-0.85, 0, -0.2), 1.7], [Vector3(0.9, 0, -0.15), 1.6], [Vector3(0.05, 0, -0.6), 2.0],
		[Vector3(-0.95, 0, 0.55), 1.15], [Vector3(1.0, 0, 0.6), 1.1], [Vector3(0.0, 0.85, 0.15), 1.3],
		[Vector3(-0.5, 0.7, -0.3), 1.0], [Vector3(0.55, 0.75, -0.35), 0.95], [Vector3(-0.62, 0.35, 0.62), 0.7],
		[Vector3(0.66, 0.3, 0.62), 0.65]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for r: Array in heap:
		var s: float = r[1] * k
		m.put(rock(), at((r[0] as Vector3) * k + Vector3(0, s * 0.3, 0), rng.randf() * TAU, Vector3(s, s * 0.8, s)), p,
			Color(0.72, 0.62, 0.48).lerp(STONE_DARK, rng.randf() * 0.4))
	m.put(cyl(0.7, 0.66, 0.08, 16), at(Vector3(0, 0.04, 1.15)), p, THATCH)
	_eggs(m, Vector3(0, 0.07, 1.15), 2 + lv, 0.18, Color(1.0, 0.78, 0.25))
	# Two great curved horns either side of the mouth, and a skull over it.
	for sx in [-1.0, 1.0]:
		for j in 3:
			var y := 0.25 + j * 0.32
			m.put(cyl(0.11 - j * 0.03, 0.08 - j * 0.03, 0.36, 8), Transform3D(Basis(Vector3(0, 0, 1), sx * (0.2 + j * 0.35)),
				Vector3(sx * (0.78 + j * 0.06 + j * j * 0.05), y, 0.95)), p, BONE)
	m.put(ball(0.26, 0.8), at(Vector3(0, 1.62 * k, 0.35), 0.0, Vector3(1.0, 1.0, 1.4)), p, BONE)
	for sx in [-0.1, 0.1]:
		m.put(ball(0.06), at(Vector3(sx, 1.66 * k, 0.6)), p, DARK)
	if lv >= 2:
		_banner(m, Vector3(0.35, 1.5 * k, -0.4), 1.2, Color(0.95, 0.75, 0.22), 0.3)
	return 2.0 * k + (1.0 if lv >= 2 else 0.0)


## The menders' greenhouse: a glass dome ribbed with brass on a ring of pale stone; inside, a soft nest of moss and
## white eggs; white flowers round it, a little spring at its side.
static func _nest_white(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.08 * (lv - 1)
	var r := 1.05 * k
	m.put(lathe(PackedVector2Array([Vector2(r + 0.22, 0.0), Vector2(r + 0.22, 0.24), Vector2(r + 0.1, 0.3),
		Vector2(0.0, 0.3)]), 24), at(Vector3.ZERO), p, STONE)
	m.put(ring(0.45, 0.2), at(Vector3(0, 0.38, 0)), p, Color(0.66, 0.78, 0.5))
	_eggs(m, Vector3(0, 0.34, 0), 2 + lv, 0.14, Color(0.98, 0.97, 0.92))
	var dome := PackedVector2Array()
	for i in 9:
		var a := PI * 0.5 * i / 8.0
		dome.append(Vector2(cos(a) * r, sin(a) * r))
	m.put(lathe(dome, 24), at(Vector3(0, 0.3, 0)), glass())
	for a in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		m.put(ring(r, 0.05, 32), Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.3, 0)), metal(), BRASS)
	m.put(ring(r, 0.06, 32), at(Vector3(0, 0.33, 0)), metal(), BRASS)
	m.put(ball(0.09), at(Vector3(0, 0.3 + r + 0.05, 0)), metal(), BRASS)
	for i in 12:
		var a := TAU * i / 12.0
		var pos := Vector3(cos(a), 0, sin(a)) * (r + 0.42)
		m.put(cyl(0.012, 0.012, 0.3, 4), at(pos + Vector3(0, 0.15, 0)), p, LEAF)
		m.put(ball(0.07, 0.6, 8), at(pos + Vector3(0, 0.31, 0)), p, Color(0.98, 0.97, 0.94))
	m.put(cyl(0.32, 0.32, 0.04, 16), at(Vector3(1.1, 0.03, 1.05)), water())
	_stones(m, Vector3(1.1, 0, 1.05), 0.36, 7, 0.16, STONE, 5)
	return 0.3 + r + 0.3


## The scavengers' nest: a short gnarled tree, a big untidy nest in its fork built of scrap -- brass gears, rope, shiny
## things -- brown eggs in it.
static func _nest_scav(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.08 * (lv - 1)
	var bark := Color(0.42, 0.32, 0.24)
	m.put(cyl(0.34, 0.22, 1.5 * k, 10), tilt(at(Vector3(0.05, 0.75 * k, -0.05)), 0.05, 0.06), p, bark)
	for a in [0.4, 2.5, 4.4]:
		_post(m, Vector3(cos(a), 0, sin(a)) * 0.3, 0.6, 0.1, bark, a, 1.0, 0.05)
	for b in [[-0.75, 0.0], [0.7, 0.3], [0.1, -0.7]]:
		var pos := Vector3(0.0, 1.35 * k, 0.0)
		m.put(cyl(0.11, 0.06, 1.0, 8), Transform3D(Basis(Vector3(b[1], 0, -b[0]).normalized(), 0.85), pos + Vector3(b[0], 0.4, b[1]) * 0.5), p, bark)
		m.put(ball(0.42, 0.7, 10), at(pos + Vector3(b[0] * 1.25, 0.85, b[1] * 1.25)), p, LEAF.lightened(0.05))
	var nest := Vector3(0.05, 1.55 * k, 0.0)
	m.put(ring(0.62, 0.36), at(nest, 0.0, Vector3(1.0, 0.75, 1.0)), p, Color(0.5, 0.42, 0.32))
	m.put(cyl(0.5, 0.5, 0.1, 12), at(nest - Vector3(0, 0.08, 0)), p, Color(0.4, 0.33, 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var a := TAU * i / 9.0
		m.put(cyl(0.02, 0.02, 0.7, 4), Transform3D(Basis(Vector3(cos(a + 1.6), 0, sin(a + 1.6)), rng.randf_range(0.9, 1.4)),
			nest + Vector3(cos(a), 0.05, sin(a)) * 0.62), p, WOOD_LIGHT)
	for i in 3 + lv:
		var a := TAU * i / (3 + lv) + 0.5
		var g := Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 1.2) , nest + Vector3(cos(a), 0.12, sin(a)) * 0.66)
		m.put(cyl(0.16, 0.16, 0.04, 10), g, metal(), BRASS if i % 2 == 0 else COPPER)
		m.put(ring(0.16, 0.05, 10), g, metal(), BRASS if i % 2 == 0 else COPPER)
	for i in 4:
		m.put(ball(0.06), at(nest + Vector3(rng.randf_range(-0.5, 0.5), 0.2, rng.randf_range(-0.5, 0.5))), metal(), Color(0.85, 0.88, 0.92))
	_eggs(m, nest + Vector3(0, 0.02, 0), 2 + lv, 0.13, Color(0.82, 0.62, 0.42))
	# A rope down to the ground, a basket on it.
	m.put(cyl(0.015, 0.015, 1.1, 4), at(Vector3(0.62, 1.0 * k, 0.35)), p, THATCH)
	m.put(cyl(0.16, 0.12, 0.18, 10), at(Vector3(0.62, 0.42, 0.35)), p, WOOD_LIGHT)
	return 2.3 * k + 0.3


## The mutants' incubator: on a stone floor edged with brass, glass vats of glowing pink fluid with something growing
## in each, brass caps, copper pipes joining them to a valve -- a vat more each level.
static func _nest_mutant(m: Maker, lv: int) -> float:
	var p := paint()
	m.put(box(Vector3(2.7, 0.28, 2.1)), at(Vector3(0, 0.14, 0)), p, STONE_DARK)
	for z in [-1.05, 1.05]:
		m.put(box(Vector3(2.76, 0.08, 0.08)), at(Vector3(0, 0.29, z)), metal(), BRASS)
	for x in [-1.35, 1.35]:
		m.put(box(Vector3(0.08, 0.08, 2.16)), at(Vector3(x, 0.29, 0)), metal(), BRASS)
	var pink := Color(1.0, 0.42, 0.72)
	var vats := 2 + lv
	var h := 1.05 + 0.1 * (lv - 1)
	var tops: Array[Vector3] = []
	for i in vats:
		var t := (i - (vats - 1) * 0.5) / maxf(vats - 1, 1.0)
		var pos := Vector3(t * 2.0, 0.3, -0.25 + absf(t) * 0.75)
		m.put(cyl(0.36, 0.38, 0.18, 16), at(pos + Vector3(0, 0.09, 0)), metal(), BRASS)
		m.put(ball(0.12, 1.3, 10), at(pos + Vector3(0, 0.18 + h * 0.45, 0)), p, Color(0.55, 0.16, 0.36))
		m.put(cyl(0.27, 0.27, h - 0.08, 16), at(pos + Vector3(0, 0.18 + h * 0.48, 0)), fluid(pink, 0.8))
		m.put(cyl(0.3, 0.3, h, 16), at(pos + Vector3(0, 0.18 + h * 0.5, 0)), glass())
		m.put(cyl(0.33, 0.24, 0.16, 16), at(pos + Vector3(0, 0.26 + h, 0)), metal(), BRASS)
		tops.append(pos + Vector3(0, 0.4 + h, 0))
	# The pipes: from each cap up and over to a valve on a stand behind them.
	var hub := Vector3(0, h + 0.85, -0.75)
	m.put(cyl(0.06, 0.06, hub.y - 0.3, 8), at(Vector3(0, 0.3 + (hub.y - 0.3) * 0.5, -0.75)), metal(), COPPER)
	m.put(ring(0.16, 0.04, 12), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hub + Vector3(0, 0, 0.12)), metal(), Color(0.85, 0.25, 0.2))
	for top in tops:
		var d := hub - top
		var mid := top + d * 0.5
		m.put(cyl(0.04, 0.04, d.length(), 6), Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), mid), metal(), COPPER)
	for i in vats - 1:
		var a: Vector3 = tops[i] - Vector3(0, h + 0.15, 0)
		m.put(cyl(0.03, 0.03, 0.8, 6), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3.UP, 0.3), a + Vector3(0.35, 0.0, 0.3)), p, Color(0.15, 0.13, 0.14))
	return hub.y + 0.3


## The culture pool (and the spore pool): a round basin of pale stone rimmed with brass, glowing fluid in it, a brass
## pump at its back; the spore pool's fluid yellow-green and giant puffballs growing round it.
static func _pool(m: Maker, lv: int, spores: bool) -> float:
	var p := paint()
	var k := 1.0 + 0.06 * (lv - 1)
	m.put(lathe(PackedVector2Array([Vector2(1.38, 0.0), Vector2(1.42, 0.3), Vector2(1.36, 0.42), Vector2(1.24, 0.42),
		Vector2(1.2, 0.22), Vector2(0.0, 0.2)]), 28), at(Vector3.ZERO, 0.0, Vector3(k, 1, k)), p, STONE)
	m.put(ring(1.3 * k, 0.07, 32), at(Vector3(0, 0.43, 0)), metal(), BRASS)
	var col := Color(0.8, 0.92, 0.3) if spores else Color(0.35, 0.95, 0.55)
	m.put(cyl(1.22 * k, 1.22 * k, 0.04, 28), at(Vector3(0, 0.36, 0)), glow(col, 0.55))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 5 + 2 * lv:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.1, 0.95) * k
		m.put(ball(rng.randf_range(0.04, 0.09), 0.8, 8), at(Vector3(cos(a) * d, 0.39, sin(a) * d)), glow(col.lightened(0.4), 0.9))
	if spores:
		for i in 2 + lv:
			var a := TAU * i / (2 + lv) - 0.9
			var s := 0.85 + 0.25 * (i % 2)
			var pos := Vector3(cos(a), 0, sin(a)) * 1.55 * k
			m.put(cyl(0.1 * s, 0.13 * s, 0.6 * s, 10), at(pos + Vector3(0, 0.3 * s, 0)), p, Color(0.95, 0.92, 0.8))
			m.put(lathe(PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.48, 0.12), Vector2(0.36, 0.28), Vector2(0.0, 0.34)]), 16),
				at(pos + Vector3(0, 0.56 * s, 0), 0.0, Vector3(s, s, s)), p, Color(0.98, 0.82, 0.3))
	else:
		m.put(box(Vector3(0.5, 0.3, 0.4)), at(Vector3(0, 0.15, -1.6)), p, STONE_DARK)
		m.put(cyl(0.07, 0.07, 1.1, 10), at(Vector3(0, 0.85, -1.6)), metal(), BRASS)
		m.put(cyl(0.05, 0.05, 0.75, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.35, -1.3)), metal(), BRASS)
		m.put(cyl(0.07, 0.04, 0.16, 8), at(Vector3(0, 1.28, -0.95)), metal(), BRASS)
		m.put(box(Vector3(0.06, 0.06, 0.6)), tilt(at(Vector3(0.12, 1.45, -1.75)), -0.6), metal(), IRON)
		if lv >= 2:
			for a in [0.9, 2.2]:
				m.put(cyl(0.06, 0.06, 0.5, 8), at(Vector3(cos(a), 0, -sin(a)) * 1.5 + Vector3(0, 0.25, 0)), metal(), COPPER)
	return 1.6 if not spores else 1.3


## The horde totem: a tall pole of carved drums, red and wood, a dinosaur's skull on its top, red war banners from a
## crossbar, a big hide drum at its foot -- a drum more each level.
static func _totem(m: Maker, lv: int) -> float:
	var p := paint()
	_stones(m, Vector3.ZERO, 0.75, 9, 0.32, STONE, 13)
	m.put(cyl(0.48, 0.44, 0.55, 16), at(Vector3(0.75, 0.28, 0.6)), p, WOOD)
	m.put(cyl(0.46, 0.46, 0.04, 16), at(Vector3(0.75, 0.57, 0.6)), p, Color(0.88, 0.8, 0.62))
	var y := 0.0
	var segs := 3 + lv
	for i in segs:
		var h := 0.5
		var r := 0.32 if i % 2 == 0 else 0.27
		var col: Color = [WOOD, Color(0.74, 0.3, 0.24), WOOD_LIGHT][i % 3]
		m.put(cyl(r, r * 0.92, h, 12), at(Vector3(0, y + h * 0.5, 0)), p, col)
		for sx in [-0.11, 0.11]:
			m.put(ball(0.055), at(Vector3(sx, y + h * 0.62, r * 0.95)), p, DARK if i % 2 == 0 else Color(0.95, 0.85, 0.4))
		m.put(box(Vector3(0.1, 0.16, 0.12)), at(Vector3(0, y + h * 0.36, r * 0.98)), p, col.darkened(0.3))
		y += h
	m.put(box(Vector3(1.7, 0.12, 0.14)), at(Vector3(0, y - 0.3, 0)), p, WOOD)
	for sx in [-0.72, 0.72]:
		m.put(box(Vector3(0.36, 0.95, 0.03)), at(Vector3(sx, y - 0.85, 0.02), sx * 0.15), p, Color(0.78, 0.2, 0.17))
	m.put(ball(0.3, 0.8), at(Vector3(0, y + 0.2, 0.1), 0.0, Vector3(1.0, 1.0, 1.5)), p, BONE)
	m.put(box(Vector3(0.36, 0.08, 0.4)), at(Vector3(0, y + 0.02, 0.32)), p, BONE.darkened(0.08))
	for sx in [-0.12, 0.12]:
		m.put(ball(0.06), at(Vector3(sx, y + 0.27, 0.46)), p, DARK)
		m.put(cyl(0.06, 0.0, 0.36, 6), Transform3D(Basis(Vector3(0, 0, 1), -sx * 4.0), Vector3(sx * 1.6, y + 0.45, 0.0)), p, BONE)
	return y + 0.7


## The field research station: a round hut of timber banded with brass on a deck, a verdigris roof, a glass dome at
## its side with something glowing in it, a dish antenna up high, a rack of glowing sample tubes.
static func _sampler(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.07 * (lv - 1)
	m.put(box(Vector3(2.7, 0.2, 2.4)), at(Vector3(0, 0.1, 0)), p, WOOD)
	var hut := Vector3(-0.4, 0.2, -0.3)
	m.put(cyl(0.78 * k, 0.78 * k, 1.15 * k, 18), at(hut + Vector3(0, 0.58 * k, 0)), p, WOOD_LIGHT)
	for y in [0.15, 1.05]:
		m.put(ring(0.79 * k, 0.05, 24), at(hut + Vector3(0, y * k, 0)), metal(), BRASS)
	m.put(cyl(0.22, 0.22, 0.05, 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hut + Vector3(0.25, 0.75 * k, 0.76 * k)), glow(Color(0.7, 0.95, 1.0), 0.6))
	m.put(box(Vector3(0.42, 0.7, 0.06)), at(hut + Vector3(-0.3, 0.38, 0.76 * k)), p, WOOD)
	m.put(cyl(1.02 * k, 0.12, 0.6, 18), at(hut + Vector3(0, 1.45 * k, 0)), metal(), Color(0.5, 0.74, 0.62))
	m.put(cyl(0.035, 0.035, 0.9, 6), at(hut + Vector3(0, 2.0 * k, 0)), metal(), BRASS)
	var dish := Transform3D(Basis(Vector3.RIGHT, 0.7) * Basis(Vector3.UP, 0.3), hut + Vector3(0, 2.5 * k, 0.05))
	m.put(lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.22, 0.03), Vector2(0.4, 0.11), Vector2(0.5, 0.2)]), 18), dish, metal(), Color(0.86, 0.86, 0.82))
	var annex := Vector3(0.65, 0.2, 0.45)
	m.put(ring(0.52, 0.06, 24), at(annex + Vector3(0, 0.03, 0)), metal(), BRASS)
	var dome := PackedVector2Array()
	for i in 7:
		var a := PI * 0.5 * i / 6.0
		dome.append(Vector2(cos(a) * 0.5, sin(a) * 0.5))
	m.put(lathe(dome, 18), at(annex), glass())
	m.put(ball(0.14), at(annex + Vector3(0, 0.2, 0)), glow(Color(0.5, 1.0, 0.85), 1.2))
	m.put(box(Vector3(0.7, 0.08, 0.3)), at(Vector3(-0.75, 0.62, 0.95)), p, WOOD)
	for i in 3 + lv:
		m.put(cyl(0.04, 0.04, 0.32, 8), at(Vector3(-1.0 + i * 0.12, 0.8, 0.95)), glow([Color(0.45, 1.0, 0.8), Color(0.5, 0.8, 1.0)][i % 2], 1.0))
	for sx in [-1.05, -0.45]:
		m.put(box(Vector3(0.05, 0.62, 0.05)), at(Vector3(sx, 0.51, 0.95)), p, WOOD)
	return 2.9 * k


## The gene stabilizer: a bronze pylon on an eight-sided plinth, its tip glowing; three rings of light turning round it
## (nodes of their own, to turn).
static func _stabilizer(m: Maker, root: Node3D, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.08 * (lv - 1)
	m.put(cyl(1.05, 0.95, 0.35, 8), at(Vector3(0, 0.18, 0)), p, STONE)
	m.put(cyl(0.72, 0.66, 0.25, 8), at(Vector3(0, 0.47, 0)), p, STONE_DARK)
	var h := 2.4 * k
	m.put(cyl(0.3, 0.12, h, 12), at(Vector3(0, 0.6 + h * 0.5, 0)), metal(), Color(0.78, 0.56, 0.3))
	for y in [0.3, 0.6, 0.85]:
		m.put(ring(0.3 - 0.18 * y + 0.04, 0.06, 16), at(Vector3(0, 0.6 + h * y, 0)), metal(), BRASS)
	var light := Color(0.6, 0.8, 1.0)
	m.put(ball(0.17), at(Vector3(0, 0.7 + h, 0)), glow(light, 2.0))
	for i in 3:
		var spin := Spin.new()
		spin.speed = [0.5, -0.7, 0.9][i]
		spin.position = Vector3(0, 0.6 + h * (0.3 + 0.25 * i), 0)
		var ring_node := MeshInstance3D.new()
		ring_node.mesh = ring(0.85 - 0.15 * i, 0.05, 32)
		ring_node.material_override = glow(light, 1.4)
		ring_node.rotation = Vector3(0.35 * (i - 1), 0.0, 0.25 * (1 - i))
		spin.add_child(ring_node)
		root.add_child(spin)
	return 0.9 + h


## The gene bank -- the research institute: a round hall of pale stone under a great glass dome ribbed with brass, the
## gene helixes glowing inside, a round door of light at the front, a brass spire.
static func _gene_bank(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.07 * (lv - 1)
	m.put(cyl(1.55, 1.58, 0.18, 28), at(Vector3(0, 0.09, 0)), p, STONE_DARK)
	m.put(cyl(1.45, 1.45, 0.1, 28), at(Vector3(0, 0.23, 0)), p, STONE)
	var r := 1.2 * k
	var wall := 1.0 * k
	m.put(cyl(r, r, wall, 28), at(Vector3(0, 0.28 + wall * 0.5, 0)), p, STONE)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		m.put(box(Vector3(0.18, wall, 0.12)), at(Vector3(cos(a), 0, sin(a)) * r + Vector3(0, 0.28 + wall * 0.5, 0), -a + PI * 0.5), p, STONE.lightened(0.1))
	var top := 0.28 + wall
	m.put(ring(r + 0.02, 0.08, 32), at(Vector3(0, top, 0)), metal(), BRASS)
	var dome := PackedVector2Array()
	for i in 9:
		var a := PI * 0.5 * i / 8.0
		dome.append(Vector2(cos(a) * r * 0.96, sin(a) * r * 0.96))
	m.put(lathe(dome, 28), at(Vector3(0, top, 0)), glass())
	for a in [0.0, PI / 4.0, PI / 2.0, PI * 3.0 / 4.0]:
		m.put(ring(r * 0.96, 0.045, 32), Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, top, 0)), metal(), BRASS)
	# The helixes: two strands of glowing beads winding up together.
	for strand in 2:
		for i in 14:
			var t := i / 13.0
			var a := t * TAU * 1.5 + strand * PI
			m.put(ball(0.06, 1.0, 8), at(Vector3(cos(a) * 0.22, top - 0.15 + t * 0.9 * k, sin(a) * 0.22)), glow([Color(0.4, 1.0, 0.8), Color(0.5, 0.75, 1.0)][strand], 1.6))
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	m.put(cyl(0.38, 0.38, 0.06, 20), Transform3D(face, Vector3(0, 0.75, r + 0.02)), glow(Color(0.45, 0.95, 1.0), 1.0))
	m.put(ring(0.42, 0.08, 24), Transform3D(face, Vector3(0, 0.75, r + 0.04)), metal(), BRASS)
	m.put(box(Vector3(0.9, 0.12, 0.4)), at(Vector3(0, 0.3, r + 0.22)), p, STONE_DARK)
	m.put(cyl(0.06, 0.02, 0.6, 8), at(Vector3(0, top + r * 0.96 + 0.25, 0)), metal(), BRASS)
	m.put(ball(0.07), at(Vector3(0, top + r * 0.96 + 0.58, 0)), glow(Color(0.5, 1.0, 0.85), 2.0))
	for sx in [-1.0, 1.0]:
		m.put(cyl(0.07, 0.07, 0.9, 8), tilt(at(Vector3(sx * (r + 0.1), 0.55, -0.3)), 0.0, sx * 0.15), metal(), COPPER)
	return top + r + 0.7


## The gold mine: a mossy rock, a timber-framed tunnel cut into it, a gold vein glowing on its face, rails out of the
## tunnel to a cart heaped with nuggets.
static func _mine(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.07 * (lv - 1)
	var rock_col := Color(0.6, 0.57, 0.52)
	for r: Array in [[Vector3(0, 0, -0.55), Vector3(2.6, 1.9, 1.6)], [Vector3(-0.95, 0, -0.1), Vector3(1.3, 1.2, 1.3)],
			[Vector3(1.0, 0, -0.15), Vector3(1.2, 1.4, 1.2)]]:
		var s: Vector3 = r[1] * k
		m.put(rock(), at(r[0] + Vector3(0, s.y * 0.3, 0), 0.4, s), p, rock_col)
	m.put(rock(), at(Vector3(0.1, 1.55 * k, -0.6), 1.3, Vector3(1.7, 0.45, 1.1) * k), p, MOSS)
	for sx in [-0.45, 0.45]:
		m.put(box(Vector3(0.16, 1.1, 0.16)), at(Vector3(sx, 0.55, 0.32)), p, WOOD)
	m.put(box(Vector3(1.2, 0.18, 0.22)), at(Vector3(0, 1.15, 0.32)), p, WOOD)
	m.put(box(Vector3(0.74, 1.0, 0.1)), at(Vector3(0, 0.5, 0.26)), p, DARK)
	for i in 4 + lv:
		var a := 0.5 + i * 0.4
		m.put(cyl(0.07, 0.0, 0.28, 6), tilt(at(Vector3(0.75 + 0.12 * cos(a * 3.0), 0.45 + i * 0.13, 0.45)), 0.6, cos(a) * 0.5), glow(GOLD, 1.2))
	for sx in [-0.22, 0.22]:
		m.put(box(Vector3(0.05, 0.05, 1.5)), at(Vector3(sx, 0.05, 1.0)), metal(), IRON)
	for i in 5:
		m.put(box(Vector3(0.62, 0.04, 0.1)), at(Vector3(0, 0.02, 0.4 + i * 0.3)), p, WOOD)
	var cart := Vector3(0, 0.0, 1.35)
	m.put(box(Vector3(0.62, 0.36, 0.46)), at(cart + Vector3(0, 0.34, 0)), p, WOOD_LIGHT)
	for sx in [-0.3, 0.3]:
		for sz in [-0.16, 0.16]:
			m.put(cyl(0.1, 0.1, 0.05, 10), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), cart + Vector3(sx, 0.12, sz)), metal(), IRON)
	for i in 6 + lv:
		m.put(ball(0.09, 0.8, 8), at(cart + Vector3(-0.2 + (i % 3) * 0.2, 0.55 + (i / 3) * 0.06, -0.1 + (i % 2) * 0.2)), glow(GOLD, 0.8))
	return 2.2 * k


## The forge: a heavy stone hearth glowing at its mouth under a lean-to roof, a tall brick chimney, an anvil, bellows.
static func _forge(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.07 * (lv - 1)
	m.put(box(Vector3(2.1, 1.1, 1.6) * Vector3(k, 1, 1)), at(Vector3(0, 0.55, -0.4)), p, STONE_DARK)
	m.put(box(Vector3(2.2 * k, 0.16, 1.7)), at(Vector3(0, 1.12, -0.4)), p, Color(0.3, 0.28, 0.27))
	m.put(box(Vector3(0.8, 0.55, 0.1)), at(Vector3(0, 0.42, 0.42)), glow(Color(1.0, 0.5, 0.15), 2.2))
	m.put(ring(0.45, 0.12, 16), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.5, 0.42)), p, STONE)
	var ch := 1.6 + 0.3 * lv
	m.put(box(Vector3(0.55, ch, 0.55)), at(Vector3(0.65 * k, 1.1 + ch * 0.5, -0.75)), p, Color(0.6, 0.34, 0.26))
	m.put(box(Vector3(0.68, 0.14, 0.68)), at(Vector3(0.65 * k, 1.1 + ch, -0.75)), p, STONE_DARK)
	m.put(cyl(0.16, 0.16, 0.05, 10), at(Vector3(0.65 * k, 1.2 + ch, -0.75)), glow(Color(1.0, 0.45, 0.15), 1.5))
	m.put(box(Vector3(2.4 * k, 0.08, 1.2)), Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(0, 1.55, 0.5)), p, WOOD)
	for sx in [-1.1, 1.1]:
		m.put(box(Vector3(0.1, 1.5, 0.1)), at(Vector3(sx * k, 0.75, 0.95)), p, WOOD)
	var anvil := Vector3(-0.85, 0, 1.15)
	m.put(box(Vector3(0.3, 0.42, 0.3)), at(anvil + Vector3(0, 0.21, 0)), p, WOOD)
	m.put(box(Vector3(0.5, 0.16, 0.24)), at(anvil + Vector3(0.05, 0.5, 0)), metal(), IRON)
	m.put(cyl(0.08, 0.0, 0.25, 8), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), anvil + Vector3(0.4, 0.52, 0)), metal(), IRON)
	m.put(gable(Vector3(0.6, 0.3, 0.4)), at(Vector3(1.0, 0.2, 0.85), 0.3), p, Color(0.45, 0.3, 0.2))
	m.put(cyl(0.18, 0.15, 0.2, 12), at(Vector3(0.3, 0.1, 1.05)), metal(), IRON)
	m.put(cyl(0.14, 0.14, 0.03, 12), at(Vector3(0.3, 0.21, 1.05)), glow(Color(1.0, 0.6, 0.2), 2.0))
	return 1.3 + ch


## The vault: a heavy hall of carved pale stone on a plinth, a round golden door, gold coins spilling out before it.
static func _vault(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.07 * (lv - 1)
	m.put(box(Vector3(2.9, 0.22, 2.4) * Vector3(k, 1, k)), at(Vector3(0, 0.11, -0.2)), p, STONE_DARK)
	m.put(box(Vector3(2.4, 1.3, 1.8) * Vector3(k, k, k)), at(Vector3(0, 0.22 + 0.65 * k, -0.3)), p, STONE)
	m.put(box(Vector3(2.65, 0.2, 2.05) * Vector3(k, 1, k)), at(Vector3(0, 0.22 + 1.3 * k + 0.1, -0.3)), p, STONE.lightened(0.08))
	m.put(cyl(1.1 * k, 0.7 * k, 0.35, 4), at(Vector3(0, 0.22 + 1.3 * k + 0.37, -0.3), PI * 0.25), p, STONE_DARK)
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	var door := Vector3(0, 0.22 + 0.6 * k, 0.62 * k)
	m.put(cyl(0.56, 0.56, 0.1, 24), Transform3D(face, door), metal(), GOLD)
	m.put(ring(0.42, 0.06, 24), Transform3D(face, door + Vector3(0, 0, 0.06)), metal(), GOLD.darkened(0.2))
	m.put(ball(0.1), at(door + Vector3(0, 0, 0.08)), metal(), GOLD.lightened(0.2))
	for sx in [-0.9, 0.9]:
		m.put(box(Vector3(0.22, 1.3 * k, 0.22)), at(Vector3(sx * k, 0.22 + 0.65 * k, 0.6 * k)), p, STONE.lightened(0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 10 + 4 * lv:
		var pos := Vector3(rng.randf_range(-0.7, 0.7), 0.02, rng.randf_range(0.85, 1.45))
		m.put(cyl(0.09, 0.09, 0.025, 10), tilt(at(pos), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)), metal(), GOLD)
	for i in 3:
		m.put(cyl(0.09, 0.09, 0.12 + 0.05 * i, 10), at(Vector3(-0.9 + i * 0.25, 0.06 + 0.025 * i, 1.2)), metal(), GOLD)
	return 2.4 * k


## The trading post: a wooden stall on a deck under a striped awning, a counter of goods, crates and jars beside it,
## things hung from the awning.
static func _market(m: Maker, lv: int) -> float:
	var p := paint()
	m.put(box(Vector3(2.8, 0.14, 2.1)), at(Vector3(0, 0.07, 0)), p, WOOD)
	for sx in [-1.2, 1.2]:
		for sz in [-0.8, 0.8]:
			m.put(box(Vector3(0.1, 1.9 if sz < 0 else 1.6, 0.1)), at(Vector3(sx, 0.95 if sz < 0 else 0.8, sz)), p, WOOD)
	var stripe := [Color(0.84, 0.3, 0.26), Color(0.96, 0.92, 0.82)]
	for i in 6:
		var x := -1.25 + 0.5 * i
		m.put(box(Vector3(0.5, 0.05, 1.9)), Transform3D(Basis(Vector3.RIGHT, 0.16), Vector3(x + 0.25, 1.75, 0.0)), p, stripe[i % 2])
	for i in 6:
		m.put(ball(0.12, 0.5, 10), at(Vector3(-1.0 + 0.4 * i, 1.58, 0.95)), p, stripe[i % 2])
	m.put(box(Vector3(2.3, 0.7, 0.55)), at(Vector3(0, 0.49, 0.45)), p, WOOD_LIGHT)
	var goods := [Color(0.95, 0.4, 0.3), Color(0.98, 0.8, 0.3), Color(0.5, 0.75, 0.35), Color(0.6, 0.45, 0.85)]
	for i in 4 + 2 * lv:
		m.put(ball(0.09), at(Vector3(-0.95 + i * 0.2, 0.9, 0.45 + (i % 2) * 0.12)), p, goods[i % 4])
	for c: Array in [[Vector3(-1.05, 0, -0.35), 0.5], [Vector3(-0.55, 0, -0.45), 0.42], [Vector3(-1.0, 0.5, -0.35), 0.36]]:
		var s: float = c[1]
		m.put(box(Vector3(s, s, s)), at(c[0] + Vector3(0, s * 0.5 + 0.14, 0), 0.3), p, WOOD_LIGHT.darkened(0.1))
	for i in 2 + lv:
		var pos := Vector3(0.55 + i * 0.28, 0.14, -0.4 + (i % 2) * 0.25)
		m.put(lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.16, 0.14), Vector2(0.1, 0.3),
			Vector2(0.07, 0.34), Vector2(0.0, 0.34)]), 12), at(pos), p, [Color(0.78, 0.45, 0.3), Color(0.35, 0.55, 0.8)][i % 2])
	for i in 3:
		var x := -0.6 + i * 0.6
		m.put(cyl(0.01, 0.01, 0.35, 4), at(Vector3(x, 1.5, 0.2)), p, THATCH)
		m.put(ball(0.1, 1.2, 8), at(Vector3(x, 1.28, 0.2)), p, goods[(i + 1) % 4])
	return 2.2


## The champion hall: a small temple of white marble on stepped plinths, columns before it, a pediment roof with a
## golden crown on its ridge, banners on its front.
static func _hall(m: Maker, lv: int) -> float:
	var p := paint()
	var marble := Color(0.94, 0.92, 0.88)
	var k := 1.0 + 0.06 * (lv - 1)
	m.put(box(Vector3(3.0, 0.18, 2.6)), at(Vector3(0, 0.09, 0)), p, marble.darkened(0.12))
	m.put(box(Vector3(2.7, 0.18, 2.3)), at(Vector3(0, 0.27, 0)), p, marble.darkened(0.05))
	var h := 1.3 * k
	m.put(box(Vector3(2.2, h, 1.35)), at(Vector3(0, 0.36 + h * 0.5, -0.35)), p, marble)
	for i in 4:
		var x := -0.95 + i * 0.633
		m.put(cyl(0.13, 0.12, h, 12), at(Vector3(x, 0.36 + h * 0.5, 0.75)), p, marble)
		m.put(box(Vector3(0.32, 0.1, 0.32)), at(Vector3(x, 0.36 + h - 0.02, 0.75)), p, marble.darkened(0.06))
	m.put(box(Vector3(2.6, 0.22, 2.1)), at(Vector3(0, 0.36 + h + 0.11, 0.1)), p, marble.darkened(0.04))
	m.put(gable(Vector3(2.6, 0.62, 2.1)), at(Vector3(0, 0.36 + h + 0.22 + 0.31, 0.1)), p, Color(0.72, 0.6, 0.86))
	var crown := Vector3(0, 0.36 + h + 0.95, 0.1)
	m.put(ring(0.26, 0.08, 16), at(crown), metal(), GOLD)
	for i in 5:
		var a := TAU * i / 5.0
		m.put(cyl(0.05, 0.0, 0.2, 6), at(crown + Vector3(cos(a) * 0.26, 0.12, sin(a) * 0.26)), metal(), GOLD)
	m.put(ball(0.07), at(crown + Vector3(0, 0.06, 0)), glow(Color(0.85, 0.5, 1.0), 1.5))
	for sx in [-0.55, 0.55]:
		m.put(box(Vector3(0.36, 0.75, 0.03)), at(Vector3(sx, 0.36 + h * 0.55, 0.34)), p, Color(0.62, 0.42, 0.8))
		m.put(box(Vector3(0.12, 0.12, 0.03)), at(Vector3(sx, 0.36 + h * 0.55, 0.36), PI * 0.25), metal(), GOLD)
	return 0.36 + h + 1.3


## The watchtower: a tapering tower of stone, a wooden lookout ringed with a rail, a red cone of roof on posts, a red
## flag over it; taller each level.
static func _watchtower(m: Maker, lv: int) -> float:
	var p := paint()
	var h := 2.4 + 0.45 * (lv - 1)
	m.put(cyl(0.78, 0.6, h, 14), at(Vector3(0, h * 0.5, 0)), p, STONE)
	for y in [0.25, 0.55, 0.85]:
		m.put(ring(0.78 - 0.18 * y + 0.01, 0.06, 20), at(Vector3(0, h * y, 0)), p, STONE_DARK)
	m.put(box(Vector3(0.42, 0.7, 0.1)), at(Vector3(0, 0.35, 0.74)), p, DARK)
	m.put(box(Vector3(0.16, 0.26, 0.1)), at(Vector3(0, h * 0.62, 0.62)), p, DARK)
	m.put(cyl(1.0, 0.95, 0.16, 16), at(Vector3(0, h + 0.08, 0)), p, WOOD)
	for i in 10:
		var a := TAU * i / 10.0
		m.put(cyl(0.035, 0.035, 0.42, 6), at(Vector3(cos(a) * 0.92, h + 0.37, sin(a) * 0.92)), p, WOOD_LIGHT)
	m.put(ring(0.92, 0.05, 24), at(Vector3(0, h + 0.58, 0)), p, WOOD_LIGHT)
	for a in [0.785, 2.356, 3.927, 5.498]:
		m.put(cyl(0.05, 0.05, 0.95, 6), at(Vector3(cos(a) * 0.8, h + 0.6, sin(a) * 0.8)), p, WOOD)
	m.put(cyl(1.18, 0.05, 0.85, 14), at(Vector3(0, h + 1.5, 0)), p, Color(0.76, 0.3, 0.24))
	m.put(cyl(0.025, 0.025, 0.9, 6), at(Vector3(0, h + 2.3, 0)), p, WOOD)
	m.put(box(Vector3(0.48, 0.3, 0.03)), at(Vector3(0.26, h + 2.6, 0)), p, Color(0.85, 0.22, 0.18))
	m.put(cyl(0.05, 0.04, 0.4, 8), Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3(0.45, h + 0.6, 0.45)), metal(), BRASS)
	return h + 2.8


## The vanguard camp: a ring of pointed logs with a gate at the front, round shields hung on it, spears leaning by the
## gate, a tent inside, a war flag over it all.
static func _vanguard(m: Maker, lv: int) -> float:
	var p := paint()
	var k := 1.0 + 0.06 * (lv - 1)
	var logs := 16
	for i in logs:
		var a := TAU * i / logs + PI * 0.5
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.3:
			continue                                      # the gate, at the front
		var h := (1.15 + 0.12 * ((i * 7) % 3)) * k
		var pos := Vector3(cos(a), 0, sin(a)) * 1.3 * k
		m.put(cyl(0.12, 0.12, h, 8), at(pos + Vector3(0, h * 0.5, 0)), p, WOOD)
		m.put(cyl(0.12, 0.0, 0.25, 8), at(pos + Vector3(0, h + 0.12, 0)), p, WOOD_LIGHT)
		if i % 3 == 0:
			var out := Vector3(cos(a), 0, sin(a))
			m.put(cyl(0.22, 0.22, 0.05, 14), Transform3D(Basis(Quaternion(Vector3.UP, out)), pos + out * 0.15 + Vector3(0, h * 0.6, 0)), p, [Color(0.7, 0.28, 0.22), Color(0.3, 0.45, 0.7)][(i / 3) % 2])
			m.put(ring(0.22, 0.04, 14), Transform3D(Basis(Quaternion(Vector3.UP, out)), pos + out * 0.17 + Vector3(0, h * 0.6, 0)), metal(), IRON)
	for sx in [-0.42, 0.42]:
		m.put(cyl(0.14, 0.14, 1.7 * k, 8), at(Vector3(sx, 0.85 * k, 1.28 * k)), p, WOOD)
	m.put(box(Vector3(1.1, 0.14, 0.16)), at(Vector3(0, 1.6 * k, 1.28 * k)), p, WOOD)
	for i in 2 + lv:
		m.put(cyl(0.02, 0.02, 1.4, 4), tilt(at(Vector3(0.65 + i * 0.1, 0.65, 1.45)), -0.25, -0.1), p, WOOD_LIGHT)
		m.put(cyl(0.04, 0.0, 0.16, 6), tilt(at(Vector3(0.65 + i * 0.1, 1.38, 1.62)), -0.25, -0.1), metal(), IRON)
	m.put(cyl(0.7, 0.05, 1.1, 6), at(Vector3(-0.2, 0.55, -0.25)), p, Color(0.8, 0.68, 0.5))
	m.put(cyl(0.04, 0.04, 2.6 * k, 6), at(Vector3(0.45, 1.3 * k, -0.4)), p, WOOD)
	m.put(box(Vector3(0.6, 0.4, 0.03)), at(Vector3(0.76, 2.4 * k, -0.4)), p, Color(0.72, 0.5, 0.3))
	return 2.8 * k


# -- The jungle about the homeland -----------------------------------------------------------------------------------

## A broadleaf tree of the jungle's edge as one mesh: a trunk that leans a little and bends back, flaring at its roots;
## a crown of clumped leaf-balls about a dark core -- darker underneath, sunlit on top. `seed` makes each different.
static func tree_mesh(seed_value: int, height: float, crown: float, leaves: Color, bark: Color) -> ArrayMesh:
	var m := Maker.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := paint()
	var lean := Vector3(rng.randf_range(-0.18, 0.18), 1.0, rng.randf_range(-0.18, 0.18)).normalized()
	var mid := lean * height * 0.55
	m.put(cyl(crown * 0.07, crown * 0.11, height * 0.55, 8), Transform3D(Basis(Quaternion(Vector3.UP, lean)), mid * 0.5), p, bark)
	var top := mid + Vector3(-lean.x * 0.6, 1.0, -lean.z * 0.6).normalized() * height * 0.5
	var up := (top - mid).normalized()
	m.put(cyl(crown * 0.05, crown * 0.07, (top - mid).length(), 8), Transform3D(Basis(Quaternion(Vector3.UP, up)), (mid + top) * 0.5), p, bark)
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf() * 0.6
		var out := Vector3(cos(a), 0.0, sin(a))
		m.put(cyl(crown * 0.06, 0.0, crown * 0.42, 6), Transform3D(Basis(out.cross(Vector3.UP).normalized(), -1.1), out * crown * 0.1 + Vector3(0, 0.08, 0)), p, bark.darkened(0.1))
	var c := top + Vector3(0, crown * 0.2, 0)
	m.put(ball(0.5, 0.8, 10), Transform3D(Basis().scaled(Vector3(crown * 1.55, crown * 1.05, crown * 1.55)), c), p, leaves.darkened(0.12))
	var n := 9 + rng.randi() % 4
	for i in n:
		var layer := i % 3                 # 0 below, 1 round the middle, 2 on top
		var a := TAU * i / n + rng.randf_range(-0.35, 0.35)
		var r := crown * (0.62 if layer == 1 else 0.42) * rng.randf_range(0.85, 1.1)
		var y := (layer - 1) * crown * 0.34 + rng.randf_range(-0.08, 0.08) * crown
		var s := crown * rng.randf_range(0.55, 0.78) * (0.85 if layer == 2 else 1.0)
		var tint := leaves.darkened(0.2) if layer == 0 else (leaves if layer == 1 else leaves.lightened(0.16))
		m.put(ball(0.5, 0.85, 10), Transform3D(Basis().scaled(Vector3.ONE * s), c + Vector3(cos(a) * r, y, sin(a) * r)), p,
			tint.lerp(Color(0.55, 0.62, 0.2), rng.randf() * 0.12))
	m.put(ball(0.5, 0.85, 10), Transform3D(Basis().scaled(Vector3.ONE * crown * 0.7), c + Vector3(0, crown * 0.5, 0)), p, leaves.lightened(0.22))
	return m.mesh()


## A bush: three to five leaf-balls heaped low, `size` across.
static func bush_mesh(seed_value: int, size: float, leaves: Color) -> ArrayMesh:
	var m := Maker.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var p := paint()
	var n := 3 + rng.randi() % 3
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.8
		var s := size * rng.randf_range(0.45, 0.65)
		var pos := Vector3(cos(a) * size * 0.28, s * 0.32, sin(a) * size * 0.28)
		m.put(ball(0.5, 0.8, 10), Transform3D(Basis().scaled(Vector3.ONE * s), pos), p,
			(leaves.darkened(0.1) if i % 2 == 0 else leaves.lightened(0.08)).lerp(Color(0.5, 0.6, 0.2), rng.randf() * 0.1))
	m.put(ball(0.5, 0.8, 10), Transform3D(Basis().scaled(Vector3.ONE * size * 0.5), Vector3(0, size * 0.36, 0)), p, leaves.lightened(0.14))
	return m.mesh()
