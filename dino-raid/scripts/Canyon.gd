class_name Canyon
extends Node3D
## The battlefield (GAME-DESIGN 9): a narrow canyon with our nesting sand at the near end, a river behind it,
## and the robots' burnt ground at the far end, under a warm low sun. The board's tiles are drawn faintly
## into the canyon floor and lit from a little picture, one pixel a tile (mark): where a card can go, where
## the cursor is.

const EXTENT := Rect2(-75.0, -95.0, 150.0, 160.0)   # x, z of the ground mesh
const STEP := 1.5
const FLOOR_HALF := 13.6                              # the canyon floor's half-width
const RIVER_Z := 31.0

const GROUND := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D tiles : filter_nearest;
uniform vec4 board;           // x, z of the board's -x,-z corner; its width and depth
uniform vec2 count;           // tiles across, tiles deep
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i) * 6.2831853;
	float b = hash(i + vec2(1.0, 0.0)) * 6.2831853;
	float c = hash(i + vec2(0.0, 1.0)) * 6.2831853;
	float d = hash(i + vec2(1.0, 1.0)) * 6.2831853;
	float va = dot(vec2(cos(a), sin(a)), f);
	float vb = dot(vec2(cos(b), sin(b)), f - vec2(1.0, 0.0));
	float vc = dot(vec2(cos(c), sin(c)), f - vec2(0.0, 1.0));
	float vd = dot(vec2(cos(d), sin(d)), f - vec2(1.0, 1.0));
	return 0.5 + 0.75 * mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}
float fbm(vec2 p) {
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 5; k++) {
		v += amp * gnoise(p);
		p = turn * p * 2.03;
		amp *= 0.5;
	}
	return v / 0.97;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float n = fbm(wpos.xz * 0.11);
	float fine = fbm(wpos.xz * 0.9);
	vec3 grass = vec3(0.2, 0.3, 0.09);
	vec3 dirt = vec3(0.38, 0.28, 0.17);
	vec3 sand = vec3(0.6, 0.49, 0.33);
	vec3 rock = vec3(0.42, 0.36, 0.3);
	vec3 burnt = vec3(0.16, 0.145, 0.135);
	vec3 col = mix(dirt, grass, smoothstep(0.38, 0.68, n));
	col = mix(col, dirt * 0.78, smoothstep(0.55, 0.8, fbm(wpos.xz * 0.35)) * 0.6);
	col *= 0.86 + 0.28 * fine;
	// Our sand: the nesting rows and the bank down to the river.
	float sandy = smoothstep(8.0, 10.5, wpos.z + (n - 0.5) * 2.0) * (1.0 - smoothstep(28.0, 30.0, wpos.z));
	col = mix(col, sand * (0.9 + 0.2 * fine), sandy);
	float wet = smoothstep(26.0, 29.5, wpos.z) * (1.0 - smoothstep(33.0, 36.0, wpos.z));
	col = mix(col, vec3(0.30, 0.27, 0.20), wet * 0.8);
	// The robots' end, burnt where they came through.
	float scorch = 1.0 - smoothstep(-14.0, -8.5, wpos.z + (n - 0.5) * 4.0);
	col = mix(col, burnt * (0.85 + 0.3 * fine), scorch * 0.85);
	// The walls: rock in beds, grass again on top.
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float beds = sin(wpos.y * 1.7 + n * 4.0) * 0.5 + 0.5;
	vec3 stone = mix(rock * 0.72, rock * 1.18, beds) * (0.85 + 0.3 * fine);
	col = mix(col, stone, smoothstep(0.18, 0.42, slope));
	col = mix(col, grass * (0.8 + 0.3 * fine), smoothstep(7.0, 10.0, wpos.y) * (1.0 - smoothstep(0.2, 0.42, slope)));
	// The board: faint seams between tiles, and each tile's mark.
	vec2 b = (wpos.xz - board.xy) / board.zw;
	if (b.x > 0.0 && b.x < 1.0 && b.y > 0.0 && b.y < 1.0) {
		vec2 t = b * count;
		vec2 f = fract(t);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		col *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.03, edge));
		col *= 1.0 + 0.04 * (mod(floor(t.x) + floor(t.y), 2.0) - 0.5);
		vec4 mark = texture(tiles, (floor(t) + 0.5) / count);
		float rim = 1.0 - smoothstep(0.02, 0.1, edge);
		col = mix(col, mark.rgb, mark.a * (0.28 + 0.6 * rim));
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

const WATER := """
shader_type spatial;
render_mode cull_back, depth_draw_always;
uniform float time_scale = 1.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 flow = wpos.xz * 0.35 + vec2(TIME * 0.35, TIME * 0.05);
	float a = vnoise(flow);
	float b = vnoise(flow * 2.3 - vec2(TIME * 0.2, 0.0));
	vec3 n = normalize(vec3((a - 0.5) * 0.5, 1.0, (b - 0.5) * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = mix(vec3(0.05, 0.13, 0.13), vec3(0.12, 0.24, 0.22), a);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = 0.88;
}
"""

var _tiles: Image
var _tiles_tex: ImageTexture
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func build(scene_of: Callable) -> void:
	_noise.seed = 11
	_noise.frequency = 0.035
	_noise.fractal_octaves = 4
	_rng.seed = 23
	_ground()
	_water()
	_sky()
	_dress(scene_of)


## Tints tile p (alpha: how strongly; 0 clears it). Call show_marks() once done.
func mark(p: Vector2i, colour: Color) -> void:
	_tiles.set_pixel(p.x, Rules.ROWS - 1 - p.y, colour)


func clear_marks() -> void:
	_tiles.fill(Color(0, 0, 0, 0))


func show_marks() -> void:
	_tiles_tex.update(_tiles)


## The ground's height at x, z: the board and the canyon floor flat, walls rising either side, the river's
## channel behind our sand, open ground beyond the robots.
func height(x: float, z: float) -> float:
	var ax := absf(x)
	var n := _noise.get_noise_2d(x, z)
	var wall := smoothstep(FLOOR_HALF, FLOOR_HALF + 7.0 + n * 3.0, ax)
	var h := wall * (10.5 + n * 5.0)
	h += smoothstep(28.0, 46.0, ax) * (3.0 + _noise.get_noise_2d(x * 0.5, z * 0.5) * 4.0)
	# The walls fall back round our end, down to the river.
	var open := smoothstep(24.0, 42.0, z)
	h *= 1.0 - open * 0.75
	var channel := exp(-pow((z - RIVER_Z) / 3.6, 2.0))
	h -= channel * 1.6
	# And far beyond the robots, the ground falls away to hills.
	h += smoothstep(-34.0, -75.0, z) * (6.0 + n * 6.0)
	if ax < FLOOR_HALF and z > -34.0 and z < 25.0:
		h = maxf(h, 0.0) * smoothstep(FLOOR_HALF - 1.0, FLOOR_HALF, ax)
	return h


func _ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int(EXTENT.size.x / STEP)
	var nz := int(EXTENT.size.y / STEP)
	for j in nz:
		for i in nx:
			var x0 := EXTENT.position.x + i * STEP
			var z0 := EXTENT.position.y + j * STEP
			var a := Vector3(x0, height(x0, z0), z0)
			var b := Vector3(x0 + STEP, height(x0 + STEP, z0), z0)
			var c := Vector3(x0 + STEP, height(x0 + STEP, z0 + STEP), z0 + STEP)
			var d := Vector3(x0, height(x0, z0 + STEP), z0 + STEP)
			for v in [a, b, c, a, c, d]:  # wound to face up: the other way the ground was culled away
				st.add_vertex(v)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	_tiles = Image.create(Rules.COLS, Rules.ROWS, false, Image.FORMAT_RGBA8)
	_tiles.fill(Color(0, 0, 0, 0))
	_tiles_tex = ImageTexture.create_from_image(_tiles)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = GROUND
	var r := Board.rect()
	mat.set_shader_parameter("board", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	mat.set_shader_parameter("count", Vector2(Rules.COLS, Rules.ROWS))
	mat.set_shader_parameter("tiles", _tiles_tex)
	mesh.material_override = mat
	add_child(mesh)


func _water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(EXTENT.size.x, 9.0)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = WATER
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.material_override = mat
	water.position = Vector3(0.0, -0.75, RIVER_Z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _sky() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.47, 0.66)
	sky_mat.sky_horizon_color = Color(0.83, 0.74, 0.62)
	sky_mat.ground_horizon_color = Color(0.55, 0.5, 0.42)
	sky_mat.ground_bottom_color = Color(0.25, 0.22, 0.18)
	sky_mat.sun_angle_max = 20.0
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.68, 0.6)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.25
	env.fog_sun_scatter = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.14
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Rocks and plants on the walls, the canyon's edges and the bank; wreckage at the robots' end. Nothing on the
## board itself.
func _dress(scene_of: Callable) -> void:
	var flora := "res://common/assets/models/flora/%s.glb"
	var props := "res://common/assets/models/props/%s.glb"
	# The walls: big basalt and rock along each side.
	for side in [-1.0, 1.0]:
		var z := -60.0
		while z < 28.0:
			var x: float = side * _rng.randf_range(FLOOR_HALF + 5.0, FLOOR_HALF + 12.0)
			var kind: String = ["basalt_cliff_a", "basalt_cliff_b", "basalt_cliff_c", "rock_formation_a",
				"rock_formation_b", "rock_formation_c"][_rng.randi() % 6]
			_put(scene_of, props % kind, Vector3(x, height(x, z) - 1.0, z), _rng.randf_range(1.3, 2.2), false)
			z += _rng.randf_range(9.0, 15.0)
	# Trees and cycads up on top and along the walls' feet.
	var tall := ["tree_fern_a", "tree_fern_b", "tree_fern_c", "araucaria_a", "araucaria_b", "cycad_a", "cycad_b",
		"cycad_c", "timber_conifer_a"]
	for i in 160:
		var x := _rng.randf_range(-72.0, 72.0)
		var z := _rng.randf_range(-90.0, 60.0)
		if absf(x) < FLOOR_HALF + 1.5 and z > -34.0 and z < 27.0:
			continue
		if absf(z - RIVER_Z) < 4.0:
			continue
		var kind: String = tall[_rng.randi() % tall.size()]
		_put(scene_of, flora % kind, Vector3(x, height(x, z), z), _rng.randf_range(0.8, 1.4), true)
	# Low ferns and horsetail where the floor meets the walls, and on the bank.
	var low := ["ground_fern_a", "ground_fern_b", "ground_fern_c", "horsetail_a", "horsetail_b"]
	for i in 140:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x: float = side * _rng.randf_range(FLOOR_HALF - 0.2, FLOOR_HALF + 4.0)
		var z := _rng.randf_range(-34.0, 26.0)
		if i % 5 == 0:
			x = _rng.randf_range(-40.0, 40.0)
			z = _rng.randf_range(23.0, 27.5)
		_put(scene_of, flora % low[_rng.randi() % low.size()], Vector3(x, height(x, z), z), _rng.randf_range(1.0, 1.8), true)
	# What they left at their end: plates and pieces of machines.
	var junk := ["wreck_board_a", "wreck_battery_a", "wreck_antenna_a", "drop_battery_a", "drop_board_a"]
	for i in 9:
		var x := _rng.randf_range(-FLOOR_HALF + 1.0, FLOOR_HALF - 1.0)
		var z := _rng.randf_range(-30.0, -22.0)
		_put(scene_of, props % junk[_rng.randi() % junk.size()], Vector3(x, 0.0, z), _rng.randf_range(1.0, 1.6), false)
	for i in 10:
		var x := _rng.randf_range(-FLOOR_HALF + 1.0, FLOOR_HALF - 1.0)
		var z := _rng.randf_range(21.0, 26.0)
		_put(scene_of, props % ["outcrop_a", "outcrop_b", "fallen_log_a", "fallen_log_b"][_rng.randi() % 4],
			Vector3(x, height(x, z), z), _rng.randf_range(1.2, 2.0), false)


func _put(scene_of: Callable, path: String, at: Vector3, size: float, plant: bool) -> void:
	var scene: PackedScene = scene_of.call(path)
	if scene == null:
		return
	var art := scene.instantiate() as Node3D
	art.position = at
	art.rotation.y = _rng.randf() * TAU
	art.scale = Vector3.ONE * size
	if plant:
		ArtDress.flora(art)
	else:
		ArtDress.prop(art)
	add_child(art)
