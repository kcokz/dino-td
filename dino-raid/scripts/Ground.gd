class_name Ground
## The ground of a place (GAME-DESIGN 23), made as dino-td's valley floor was (the player, 2026-10-19: "战斗场地和家园场地的
## 样貌也要改，也需要专业游戏的精致感"): one mesh, each of its points coloured for where it lies -- the place's grass in
## patches lighter and darker, lusher and drier; the homeland's terrace of bare earth; the road of trodden earth; the
## battle field a trampled clearing with the earth showing through, a darker furrow down its middle where the two sides
## meet -- each fading into the grass round it over an uneven edge, the land rising gently beyond where the game is played.
## Over it a fine grain in its colour and in its light (detail and normal maps laid on from above), so close up it is soil
## and turf rather than paint. And on it, tufts of grass, flowers and pebbles, thousands of each drawn at once (MultiMesh),
## kept off the plots and thinned where the fighting is.

const MIN := Vector2(-96.0, -150.0)     # the mesh's extent (x, z); past it the flat far ground (World) to the horizon
const MAX := Vector2(96.0, 62.0)
const STEP := 1.5
const HOME := Rect2(-13.5, -16.5, 27.0, 39.0)       # the homeland's terrace (x, z): its map and the yard south of it
const ROAD_HALF := 2.1
const ROAD := Vector2(-70.0, -15.0)                 # the road north, from z to z
const SEED := 20261019

## What grows on each place's ground: [tuft colour at the root, at the tip, how many tufts, flower colours, pebble colour].
const COVER := {
	0: [Color(0.2, 0.34, 0.14), Color(0.48, 0.66, 0.3), 9000, [Color(0.98, 0.86, 0.3), Color(0.95, 0.5, 0.6), Color(0.85, 0.85, 1.0)], Color(0.5, 0.48, 0.44)],
	1: [Color(0.2, 0.17, 0.14), Color(0.36, 0.3, 0.22), 900, [], Color(0.18, 0.16, 0.15)],
	2: [Color(0.18, 0.24, 0.12), Color(0.42, 0.46, 0.24), 7000, [Color(0.86, 0.9, 0.55)], Color(0.32, 0.3, 0.24)],
	3: [Color(0.5, 0.56, 0.6), Color(0.82, 0.86, 0.9), 900, [], Color(0.62, 0.68, 0.74)],
	4: [Color(0.5, 0.42, 0.24), Color(0.8, 0.7, 0.42), 1400, [Color(0.95, 0.55, 0.3)], Color(0.66, 0.46, 0.32)],
	5: [Color(0.36, 0.44, 0.26), Color(0.7, 0.72, 0.44), 4000, [Color(0.95, 0.95, 0.9)], Color(0.7, 0.68, 0.62)],
}

## Grass and flowers stirring in the wind (GAME-DESIGN 24): each blade bends from its root, the more toward its tip, in
## slow waves rolling over the meadow and now and then a stronger gust; the colours as the eye takes them (sRGB), as
## the plain material had them; lit from above and a little through the blades.
const SWAY := """
shader_type spatial;
render_mode cull_disabled;
uniform float sway = 0.8;
void vertex() {
	COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92),
		lessThan(COLOR.rgb, vec3(0.04045)));
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wave = sin(root.x * 0.32 + TIME * 1.6) * 0.6 + sin(root.z * 0.23 - TIME * 1.1) * 0.4;
	float gust = smoothstep(0.25, 1.0, sin(root.x * 0.04 + root.z * 0.03 + TIME * 0.45) * 0.5 + 0.5);
	float bend = VERTEX.y * VERTEX.y * sway * (0.45 + gust) * (0.6 + 0.4 * wave);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * (vec3(1.0, 0.0, 0.45) * bend);
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	BACKLIGHT = ALBEDO * 0.35;
}
"""

static var _noise: FastNoiseLite
static var _material: StandardMaterial3D
static var _grain: NoiseTexture2D
static var _bumps: NoiseTexture2D
static var _stone: Mesh


## The ground of place `r` (Content.LEVELS) -- its mesh and what grows on it -- under one node.
static func make(r: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Ground"
	var lv: Dictionary = Content.LEVELS[r]
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(lv)
	mi.material_override = _ground_material()
	root.add_child(mi)
	_cover(root, r, lv)
	return root


## How high the ground stands at (x, z): level where the game is played, rising gently beyond it, and down again to
## the far ground (World's) at the mesh's own edge.
static func height_at(x: float, z: float) -> float:
	var away := _away(x, z)
	var n := _n().get_noise_2d(x * 0.6, z * 0.6)
	var edge := minf(minf(x - MIN.x, MAX.x - x), minf(z - MIN.y, MAX.y - z))
	return World.GROUND_TOP + smoothstep(6.0, 34.0, away) * smoothstep(0.0, 18.0, edge) * (1.6 + 1.4 * n)


# -- The mesh ---------------------------------------------------------------------------------------------------------

static func _mesh(lv: Dictionary) -> ArrayMesh:
	var nx := int(ceil((MAX.x - MIN.x) / STEP)) + 1
	var nz := int(ceil((MAX.y - MIN.y) / STEP)) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = height_at(MIN.x + ix * STEP, MIN.y + iz * STEP)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for iz in nz:
		for ix in nx:
			var x := MIN.x + ix * STEP
			var z := MIN.y + iz * STEP
			verts.append(Vector3(x, heights[iz * nx + ix], z))
			var hl := heights[iz * nx + maxi(ix - 1, 0)]
			var hr := heights[iz * nx + mini(ix + 1, nx - 1)]
			var hd := heights[maxi(iz - 1, 0) * nx + ix]
			var hu := heights[mini(iz + 1, nz - 1) * nx + ix]
			norms.append(Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized())
			cols.append(_colour(lv, x, z))
	var idx := PackedInt32Array()
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			# Clockwise seen from above (Godot's front).
			idx.append_array(PackedInt32Array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The ground's colour at (x, z), as the eye takes it in (sRGB): grass in patches; the terrace, the road and the field
## laid over it, each with an uneven edge.
static func _colour(lv: Dictionary, x: float, z: float) -> Color:
	var n := _n()
	var grass: Color = lv.grass
	var earth: Color = lv.ground
	var big := n.get_noise_2d(x * 0.9, z * 0.9)
	var small := n.get_noise_2d(x * 3.1 + 40.0, z * 3.1)
	var c := grass.lerp(grass.lightened(0.16), maxf(0.0, big) * 1.4).lerp(grass.darkened(0.22), maxf(0.0, -big) * 1.4)
	c = c.lerp(grass.lerp(earth.lightened(0.12), 0.5), smoothstep(0.2, 0.55, small) * 0.55)
	# The battle field: grass trampled down to the earth in patches; the furrow where the sides meet.
	var tread := n.get_noise_2d(x * 2.2 - 90.0, z * 2.2)
	var worn := grass.lerp(earth.lightened(0.18), 0.35).lerp(earth.lightened(0.2), smoothstep(-0.15, 0.35, tread))
	var furrow := 1.0 - smoothstep(0.35, 0.9, absf(x - World.ARENA.x) + 0.25 * n.get_noise_2d(x * 6.0, z * 6.0))
	worn = worn.lerp(earth.darkened(0.25), furrow * _inside_field(x, z, -0.5))
	c = c.lerp(worn, _field_mask(x, z))
	# The road: trodden earth, pale in its middle.
	var wiggle := 0.5 * n.get_noise_2d(x * 1.5, z * 1.5)
	var road := 1.0 - smoothstep(ROAD_HALF - 0.6, ROAD_HALF + 0.6, absf(x) + wiggle)
	road *= smoothstep(ROAD.x - 1.0, ROAD.x + 1.0, z) * (1.0 - smoothstep(ROAD.y - 1.0, ROAD.y + 1.0, z))
	c = c.lerp(earth.lightened(0.22).lerp(earth.lightened(0.32), 1.0 - absf(x) / ROAD_HALF), clampf(road, 0.0, 1.0))
	# The homeland's terrace: a close-cropped lawn the beds stand in (the player chose a Zelda-like homeland,
	# 2026-10-20), trodden to earth where the army stands in the yard, a little darker where the ground is damp.
	var soil := earth.lightened(0.14).lerp(earth.darkened(0.08), smoothstep(-0.2, 0.5, small))
	var lawn := grass.lightened(0.14).lerp(Color(0.6, 0.66, 0.3), 0.14)
	lawn = lawn.lerp(lawn.darkened(0.12), smoothstep(-0.3, 0.6, big))
	var yard_mid := HomeView.YARD_Z + HomeView.YARD_ROW * 0.5
	var yard := 1.0 - smoothstep(2.2, 3.4, absf(z - yard_mid) + 0.6 * n.get_noise_2d(x * 1.7, z * 1.7))
	c = c.lerp(lawn.lerp(soil, yard), _home_mask(x, z))
	return c


static func _home_mask(x: float, z: float) -> float:
	var d := _rect_distance(Vector2(x, z), HOME, 2.5) + 0.9 * _n().get_noise_2d(x * 2.4, z * 2.4)
	return 1.0 - smoothstep(-0.6, 0.9, d)


static func _field_mask(x: float, z: float) -> float:
	return _inside_field(x, z, 1.2 * _n().get_noise_2d(x * 1.8 + 30.0, z * 1.8))


static func _inside_field(x: float, z: float, wobble: float) -> float:
	var field := Rect2(World.ARENA.x - World.FIELD.x * 0.5, World.ARENA.z - World.FIELD.y * 0.5, World.FIELD.x, World.FIELD.y)
	var d := _rect_distance(Vector2(x, z), field, 3.0) + wobble
	return 1.0 - smoothstep(-1.5, 2.0, d)


## How far (x, z) is from where the game is played: the terrace, the road, the field.
static func _away(x: float, z: float) -> float:
	var field := Rect2(World.ARENA.x - World.FIELD.x * 0.5, World.ARENA.z - World.FIELD.y * 0.5, World.FIELD.x, World.FIELD.y)
	var road := Rect2(-ROAD_HALF - 2.0, ROAD.x, (ROAD_HALF + 2.0) * 2.0, ROAD.y - ROAD.x)
	return maxf(0.0, minf(_rect_distance(Vector2(x, z), HOME.grow(4.0), 3.0), minf(_rect_distance(Vector2(x, z), field.grow(5.0), 4.0),
		_rect_distance(Vector2(x, z), road, 1.0))))


## How far `p` is outside a rectangle with corners rounded by `round` (less than nought inside it).
static func _rect_distance(p: Vector2, r: Rect2, round_by: float) -> float:
	var c := r.get_center()
	var h := r.size * 0.5 - Vector2.ONE * round_by
	var q := (p - c).abs() - h
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - round_by


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = SEED
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.04
		_noise.fractal_octaves = 3
	return _noise


## The ground's material, as dino-td's: its colour the mesh's own, no gloss, a fine grain of noise in its colour and its
## light laid on from above in the world's own space (so it runs on unbroken over the slopes).
static func _ground_material() -> StandardMaterial3D:
	if _material == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		m.detail_enabled = true
		m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.detail_albedo = grain()
		m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
		m.normal_enabled = true
		m.normal_scale = 0.85
		m.normal_texture = bumps()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / 2.4
		_material = m
	return _material


## The ground's fine grain in its colour (laid over a colour, multiplied), shared by all that wants to look like earth.
static func grain() -> NoiseTexture2D:
	if _grain == null:
		_grain = _noise_texture(SEED + 11, 1.0 / 2.4, false, 0.35)
	return _grain


## The ground's fine grain in its light (a normal map).
static func bumps() -> NoiseTexture2D:
	if _bumps == null:
		_bumps = _noise_texture(SEED + 29, 1.0 / 2.4, true, 1.0)
	return _bumps


## Earth that takes the world's light as the ground does -- its colour `c`, grained -- for what is laid on the ground.
static func earth_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.detail_enabled = true
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = grain()
	m.normal_enabled = true
	m.normal_scale = 0.7
	m.normal_texture = bumps()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 1.6
	return m


## Stones at `at` (each a transform: where, how big, which way), coloured round `c`, drawn at once.
static func stones(at: Array[Transform3D], c: Color, seed_value: int) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cols: Array[Color] = []
	for i in at.size():
		cols.append(c.lerp(Color(0.62, 0.6, 0.56), rng.randf() * 0.35).darkened(rng.randf() * 0.12))
	return _many(stone_mesh(), at, cols, true)


## A seeded noise texture (as dino-td's): a normal map, or a grey one pulled toward white by `contrast` so that laid
## over a colour it varies it rather than darkens it all.
static func _noise_texture(seed_value: int, frequency: float, as_normal: bool, contrast: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency * 0.04
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.as_normal_map = as_normal
	if not as_normal:
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 1.0, 1.0).lerp(Color(0.45, 0.42, 0.36), contrast))
		ramp.set_color(1, Color.WHITE)
		tex.color_ramp = ramp
	return tex


# -- What grows on it -------------------------------------------------------------------------------------------------

## Tufts of grass, flowers and pebbles over the ground of place `r`: thick on the open ground, thinning toward the field
## and the terrace, none on the terrace's plots or down the field's middle.
static func _cover(root: Node3D, r: int, lv: Dictionary) -> void:
	var look: Array = COVER.get(r, COVER[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + r
	var tufts: Array[Transform3D] = []
	var tuft_cols: Array[Color] = []
	var want: int = look[2]
	var tries := 0
	while tufts.size() < want and tries < want * 6:
		tries += 1
		var p := Vector2(rng.randf_range(-48.0, 48.0), rng.randf_range(-108.0, 34.0))
		var keep := _growth(p.x, p.y)
		if rng.randf() > keep:
			continue
		var s := rng.randf_range(0.9, 1.7) * (0.8 + 0.4 * keep)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s)),
			Vector3(p.x, height_at(p.x, p.y) - 0.02, p.y))
		tufts.append(xf)
		tuft_cols.append(Color.WHITE.lerp(Color(0.85, 0.9, 0.75), rng.randf()))
	root.add_child(_many(_tuft_mesh(look[0], look[1]), tufts, tuft_cols, false, 0.8))
	var flowers: Array = look[3]
	if not flowers.is_empty():
		var at: Array[Transform3D] = []
		var cols: Array[Color] = []
		for i in int(want / 8.0):
			var p := Vector2(rng.randf_range(-48.0, 48.0), rng.randf_range(-108.0, 34.0))
			if rng.randf() > _growth(p.x, p.y) * 0.9:
				continue
			var s := rng.randf_range(0.8, 1.2)
			at.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, height_at(p.x, p.y), p.y)))
			cols.append(flowers[rng.randi() % flowers.size()])
		root.add_child(_many(_flower_mesh(), at, cols, false, 0.5))
	var stones: Array[Transform3D] = []
	var stone_cols: Array[Color] = []
	for i in 420:
		var p := Vector2(rng.randf_range(-48.0, 48.0), rng.randf_range(-108.0, 34.0))
		var keep := _growth(p.x, p.y)
		if keep < 0.15 and rng.randf() < 0.85:
			continue
		var s := rng.randf_range(0.12, 0.42) * (2.2 if rng.randf() < 0.08 else 1.0)
		stones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.2))),
			Vector3(p.x, height_at(p.x, p.y) - s * 0.15, p.y)))
		stone_cols.append((look[4] as Color).lerp(Color(0.62, 0.6, 0.56), rng.randf() * 0.35))
	root.add_child(_many(stone_mesh(), stones, stone_cols, true))


## How thick things grow at (x, z): 0 on the terrace and down the field's middle, little on the road and the field,
## full over the open ground.
static func _growth(x: float, z: float) -> float:
	var g := 1.0 - _home_mask(x, z) * 0.97
	g *= 1.0 - _field_mask(x, z) * 0.82
	g *= 1.0 - (1.0 - smoothstep(0.5, 2.6, absf(x - World.ARENA.x))) * _inside_field(x, z, 0.0)
	var road := (1.0 - smoothstep(ROAD_HALF - 0.4, ROAD_HALF + 0.8, absf(x))) * smoothstep(ROAD.x, ROAD.x + 1.0, z) \
		* (1.0 - smoothstep(ROAD.y, ROAD.y + 1.0, z))
	g *= 1.0 - road * 0.9
	# In clumps, not evenly: a meadow, not a lawn.
	g *= clampf(0.55 + 0.9 * _n().get_noise_2d(x * 2.0 + 300.0, z * 2.0), 0.0, 1.0)
	return clampf(g, 0.0, 1.0)


## `mesh` drawn at each of `at`, coloured by `cols`; swaying in the wind by `sway` (grass, flowers), or standing still.
static func _many(mesh: Mesh, at: Array[Transform3D], cols: Array[Color], shadows: bool, sway := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = at.size()
	for i in at.size():
		mm.set_instance_transform(i, at[i])
		mm.set_instance_color(i, cols[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	if sway > 0.0:
		var sm := ShaderMaterial.new()
		sm.shader = _sway_shader()
		sm.set_shader_parameter("sway", sway)
		node.material_override = sm
	else:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.95
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static var _sway: Shader


static func _sway_shader() -> Shader:
	if _sway == null:
		_sway = Shader.new()
		_sway.code = SWAY
	return _sway


## A tuft: blades in a clump, each a tapering strip bent outward, darker at the root (as dino-td's: crossed strips
## rather than a flat card, which shows its edge to a camera looking down).
static func _tuft_mesh(base: Color, tip: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in 7:
		var yaw := TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
		var lean := rng.randf_range(0.15, 0.45)
		var h := 0.42 * rng.randf_range(0.65, 1.2)
		var w := 0.07 * rng.randf_range(0.7, 1.1)
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dir.z, 0.0, dir.x) * w * 0.5
		var tip_at := dir * (h * lean) + Vector3(0.0, h, 0.0)
		var mid_at := dir * (h * lean * 0.35) + Vector3(0.0, h * 0.55, 0.0)
		var mid := base.lerp(tip, 0.55)
		_tri(st, -side, side, mid_at + side * 0.6, base, base, mid)
		_tri(st, -side, mid_at + side * 0.6, mid_at - side * 0.6, base, mid, mid)
		_tri(st, mid_at - side * 0.6, mid_at + side * 0.6, tip_at, mid, mid, tip)
	st.generate_normals()
	# Lit as if it faced the sky: a tuft takes its light from above, not from the side its blades turn to.
	var mesh := st.commit()
	return _sky_lit(mesh)


## A flower: a short stalk, a round head (its colour the instance's).
static func _flower_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := Color(0.3, 0.45, 0.2)
	_tri(st, Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0), Vector3(0, 0.26, 0), stalk, stalk, stalk)
	var head := SphereMesh.new()
	head.radius = 0.055
	head.height = 0.08
	head.radial_segments = 8
	head.rings = 4
	var arr := head.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i: int in arr[Mesh.ARRAY_INDEX]:
		st.set_color(Color.WHITE)
		st.add_vertex(verts[i] + Vector3(0, 0.27, 0))
	st.generate_normals()
	return st.commit()


## A pebble: a coarse ball, pushed about by noise so no two look alike when turned, sunk a little.
static func stone_mesh() -> Mesh:
	if _stone != null:
		return _stone
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 1.4
	var rings := 6
	var segs := 8
	var grid: Array = []
	for i in rings + 1:
		var row: Array = []
		var phi := PI * float(i) / rings
		for j in segs + 1:
			var theta := TAU * float(j) / segs
			var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var rad := 0.5 * (1.0 + noise.get_noise_3d(n.x * 2.0, n.y * 2.0, n.z * 2.0) * 0.38)
			row.append(Vector3(n.x * rad, maxf(n.y * rad * 0.72, -0.08), n.z * rad))
		grid.append(row)
	for i in rings:
		for j in segs:
			var shade := 0.85 + 0.3 * (float(i) / rings)
			var col := Color(shade, shade, shade)
			_tri(st, grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], col, col, col)
			_tri(st, grid[i][j], grid[i + 1][j + 1], grid[i + 1][j], col, col, col)
	st.generate_normals()
	_stone = st.commit()
	return _stone


## The same mesh with every normal turned up toward the sky.
static func _sky_lit(mesh: Mesh) -> Mesh:
	var arr := mesh.surface_get_arrays(0)
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in norms.size():
		norms[i] = (norms[i] * 0.25 + Vector3.UP).normalized()
	arr[Mesh.ARRAY_NORMAL] = norms
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)
