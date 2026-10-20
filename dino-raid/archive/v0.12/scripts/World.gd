class_name World
extends Node3D
## Where it all stands (GAME-DESIGN 12, 17): the ground all round, the homeland's bare ground, a road north out of it,
## and at the road's end the field where battles are fought -- dressed for the place the ark has landed in: tall green
## and water in the rainforest, ash, rock and glowing cracks at the volcano. Flat colours for now.

const ARENA := Vector3(0, 0, -80)       # the battle field's middle; Fight's (x, z) are measured from here
const FIELD := Vector2(36, 20)
const GROUND_TOP := 0.05                # the homeland's ground and the field stand this high

var _grass: StandardMaterial3D
var _home_ground: StandardMaterial3D
var _road: StandardMaterial3D
var _field: StandardMaterial3D
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _decor: Node3D
var _env: Environment
var _motes: GPUParticles3D
var _level := 0
var _dusk := false


func _ready() -> void:
	_environment()
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, -30, 0)
	_sun.light_energy = 1.3
	_sun.light_color = Color(1.0, 0.96, 0.88)
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_max_distance = 110.0
	add_child(_sun)
	_grass = _own(Blocks.box(Vector3(600, 0.2, 600), Color.WHITE, Vector3(0, -0.1, -40)))
	_home_ground = _own(Blocks.box(Vector3(27, 0.1, 27), Color.WHITE, Vector3(0, 0, 3)))
	_road = _own(Blocks.box(Vector3(4, 0.06, 60), Color.WHITE, Vector3(0, 0, -40)))
	_field = _own(Blocks.box(Vector3(FIELD.x, 0.1, FIELD.y), Color.WHITE, ARENA))
	add_child(Blocks.box(Vector3(0.24, 0.12, FIELD.y), Color(0.42, 0.35, 0.25), ARENA))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := ARENA + Vector3(sx * FIELD.x * 0.5, 0, sz * FIELD.y * 0.5)
			add_child(Blocks.box(Vector3(0.6, 2.4, 0.6), Color(0.45, 0.36, 0.26), post + Vector3(0, 1.2, 0)))
			var flag := Color(0.85, 0.3, 0.25) if sx > 0 else Color(0.3, 0.55, 0.9)
			add_child(Blocks.box(Vector3(0.05, 0.7, 1.0), flag, post + Vector3(0, 2.1, 0.55 * -sz)))
	var run: Run = Run.current
	dress(run.level if run != null else 0)


## Dusk over the place -- the title's light: a low warm sun, a deepening sky, a haze -- or its own day again.
func dusk(on: bool) -> void:
	_dusk = on
	dress(_level)


func _light() -> void:
	if _dusk:
		_sun.rotation_degrees = Vector3(-17, -64, 0)
		_sun.light_color = Color(1.0, 0.72, 0.46)
		_sun.light_energy = 1.35
		_sky.sky_top_color = Color(0.15, 0.19, 0.34)
		_sky.sky_horizon_color = Color(0.98, 0.64, 0.42)
		_sky.ground_horizon_color = Color(0.86, 0.56, 0.4)
		_env.fog_enabled = true
		_env.fog_light_color = Color(0.62, 0.5, 0.48)
		_env.fog_density = 0.0016
		_env.fog_sky_affect = 0.15
		_env.ambient_light_energy = 0.4
	else:
		_sun.rotation_degrees = Vector3(-52, -30, 0)
		_sun.light_energy = 1.3
		_env.fog_enabled = false
		_env.ambient_light_energy = 0.45


## Motes of light drifting up over the homeland (the title's), or none.
func motes(on: bool) -> void:
	if not on:
		if _motes != null:
			_motes.queue_free()
			_motes = null
		return
	if _motes != null:
		return
	_motes = GPUParticles3D.new()
	_motes.amount = 160
	_motes.lifetime = 8.0
	_motes.preprocess = 8.0
	_motes.visibility_aabb = AABB(Vector3(-45, -4, -45), Vector3(90, 24, 90))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(32, 2.5, 26)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3(0, 0.04, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7
	pm.turbulence_noise_scale = 5.0
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 0.8))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	_motes.process_material = pm
	var dot := Gradient.new()
	dot.set_color(0, Color(1, 1, 1, 1))
	dot.set_color(1, Color(1, 1, 1, 0))
	var dot_tex := GradientTexture2D.new()
	dot_tex.gradient = dot
	dot_tex.fill = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to = Vector2(0.5, 0.0)
	dot_tex.width = 32
	dot_tex.height = 32
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot_tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.82, 0.5)
	q.material = m
	_motes.draw_pass_1 = q
	_motes.position = Vector3(0, 1.5, 6)
	add_child(_motes)


## A box whose material is its own, to colour again when the place changes.
func _own(b: MeshInstance3D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	b.material_override = m
	add_child(b)
	return m


## Dressed for place `r` (Content.LEVELS): the ground's colours, the sky, and what stands round about.
func dress(r: int) -> void:
	_level = r
	var lv: Dictionary = Content.LEVELS[r]
	var grass: Color = lv.grass
	var ground: Color = lv.ground
	_grass.albedo_color = grass
	_home_ground.albedo_color = ground
	_road.albedo_color = ground.lightened(0.12)
	_field.albedo_color = ground.lightened(0.2)
	if r == 1:
		_sky.sky_top_color = Color(0.42, 0.4, 0.44)
		_sky.sky_horizon_color = Color(0.82, 0.62, 0.48)
		_sky.ground_horizon_color = Color(0.82, 0.62, 0.48)
		_sun.light_color = Color(1.0, 0.86, 0.7)
	else:
		_sky.sky_top_color = Color(0.36, 0.55, 0.82)
		_sky.sky_horizon_color = Color(0.74, 0.82, 0.88)
		_sky.ground_horizon_color = Color(0.74, 0.82, 0.88)
		_sun.light_color = Color(1.0, 0.96, 0.88)
	_sky.ground_bottom_color = grass.darkened(0.2)
	_light()
	if _decor:
		_decor.queue_free()
	_decor = Node3D.new()
	add_child(_decor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12 + r
	for i in 80:
		var at := Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-120, 40))
		if absf(at.x) < 16 and at.z > -12 and at.z < 20:
			continue
		if absf(at.x - ARENA.x) < FIELD.x * 0.5 + 3 and absf(at.z - ARENA.z) < FIELD.y * 0.5 + 3:
			continue
		if absf(at.x) < 4:
			continue
		if r == 1:
			_volcanic(at, rng)
		else:
			_lush(at, rng)


## The rainforest: tall trees with broad tops, ferns, still water.
func _lush(at: Vector3, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.6:
		var h := rng.randf_range(3.0, 6.5)
		_decor.add_child(Blocks.box(Vector3(0.6, h, 0.6), Color(0.33, 0.24, 0.16), at + Vector3(0, h * 0.5, 0)))
		var w := rng.randf_range(2.4, 3.8)
		var top := Blocks.box(Vector3(w, 1.2, w), Color(0.17, 0.36, 0.17).lerp(Color(0.26, 0.46, 0.2), rng.randf()),
			at + Vector3(0, h + 0.4, 0))
		top.rotation.y = rng.randf() * TAU
		_decor.add_child(top)
	elif roll < 0.85:
		var f := Blocks.box(Vector3(1.4, 0.7, 1.4), Color(0.22, 0.48, 0.2), at + Vector3(0, 0.35, 0))
		f.rotation.y = rng.randf() * TAU
		_decor.add_child(f)
	else:
		var water := Blocks.box(Vector3(rng.randf_range(3, 6), 0.06, rng.randf_range(2, 4)), Color(0.3, 0.5, 0.62), at + Vector3(0, 0.03, 0))
		water.material_override = Blocks.glow(Color(0.3, 0.5, 0.62), 0.15)
		_decor.add_child(water)


## The volcano: dark rock, dead trunks, cracks glowing with what runs underneath.
func _volcanic(at: Vector3, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.55:
		var h := rng.randf_range(0.8, 2.6)
		var w := rng.randf_range(1.4, 3.2)
		var rock := Blocks.box(Vector3(w, h, w * rng.randf_range(0.7, 1.2)), Color(0.22, 0.2, 0.2).lerp(Color(0.34, 0.3, 0.28), rng.randf()),
			at + Vector3(0, h * 0.5, 0))
		rock.rotation.y = rng.randf() * TAU
		_decor.add_child(rock)
	elif roll < 0.8:
		var crack := Blocks.box(Vector3(rng.randf_range(2.5, 6), 0.05, rng.randf_range(0.3, 0.7)), Color(0.9, 0.22, 0.04), at + Vector3(0, 0.03, 0))
		crack.material_override = Blocks.glow(Color(0.9, 0.22, 0.04), 0.9)
		crack.rotation.y = rng.randf() * TAU
		_decor.add_child(crack)
	else:
		var h := rng.randf_range(2.0, 4.0)
		_decor.add_child(Blocks.box(Vector3(0.4, h, 0.4), Color(0.18, 0.14, 0.12), at + Vector3(0, h * 0.5, 0)))
		var arm := Blocks.box(Vector3(1.4, 0.25, 0.25), Color(0.18, 0.14, 0.12), at + Vector3(0.4, h * 0.75, 0))
		arm.rotation.z = 0.5
		_decor.add_child(arm)


func _environment() -> void:
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	# A soft bloom on what glows, and the colours drawn a little together (GAME-DESIGN 21).
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)