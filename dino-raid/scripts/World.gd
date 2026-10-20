class_name World
extends Node3D
## Where it all stands (GAME-DESIGN 12, 17): the ground all round, the homeland's bare ground, a road north out of it,
## and at the road's end the field where battles are fought -- dressed for the place the ark has landed in: tall green
## and water in the rainforest, ash, rock and glowing cracks at the volcano, dead trees and reeds in the swamp, ice and
## pines on the ice fields, dunes and cacti in the desert, rocks and palms by the sea. Flat colours for now.

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


## The light, as dino-td's (the player, 2026-10-19: "光影色彩之前你在做dino td的时候做的就不错，要有那种光影色彩效果"): a
## warm sun a little low, raking across the ground and throwing long soft shadows; the sky's light filling the shadows;
## a haze in the air that catches the sun and softens the distance into the sky; AgX tone, so nothing bright blows out
## to white and the colours stay soft.
const SUN_ANGLE := Vector3(-36, 40, 0)
const SUN_COLOR := Color(1.0, 0.93, 0.8)
const SUN_ENERGY := 1.4


func _ready() -> void:
	_environment()
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = SUN_ANGLE
	_sun.light_energy = SUN_ENERGY
	_sun.light_color = SUN_COLOR
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.03
	_sun.shadow_normal_bias = 1.2
	_sun.shadow_blur = 1.2
	_sun.light_angular_distance = 1.2
	_sun.light_volumetric_fog_energy = 1.6
	_sun.directional_shadow_max_distance = 90.0
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
	dress(run.place if run != null else 0)


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
		_env.fog_light_color = Color(0.7, 0.54, 0.5)
		_env.volumetric_fog_albedo = Color(0.95, 0.82, 0.74)
		_env.ambient_light_energy = 0.45
	else:
		var lv: Dictionary = Content.LEVELS[_level]
		_sun.rotation_degrees = SUN_ANGLE
		_sun.light_energy = SUN_ENERGY
		# The haze the colour of the place's own horizon, a little greyed: humid air.
		_env.fog_light_color = (lv.sky[1] as Color).lerp(Color(0.78, 0.8, 0.76), 0.35)
		_env.volumetric_fog_albedo = (lv.sky[1] as Color).lerp(Color(0.92, 0.94, 0.9), 0.6)
		_env.ambient_light_energy = 0.55


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
	# Each place's own sky, drawn toward a humid one (dino-td's): a deep teal overhead, a warm white haze at the horizon.
	_sky.sky_top_color = (lv.sky[0] as Color).lerp(Color(0.28, 0.46, 0.62), 0.4)
	_sky.sky_horizon_color = (lv.sky[1] as Color).lerp(Color(0.84, 0.82, 0.7), 0.5)
	_sky.ground_horizon_color = (lv.sky[1] as Color).lerp(Color(0.52, 0.56, 0.44), 0.5)
	_sun.light_color = Color(1.0, 0.86, 0.7) if r == 1 else Color(1.0, 0.96, 0.88)
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
		match r:
			1:
				_volcanic(at, rng)
			2:
				_swamp(at, rng)
			3:
				_frozen(at, rng)
			4:
				_desert(at, rng)
			5:
				_coast(at, rng)
			_:
				_lush(at, rng)


## The swamp: dead trees leaning, reeds, dark pools.
func _swamp(at: Vector3, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.4:
		var h := rng.randf_range(2.5, 5.0)
		var trunk := Blocks.box(Vector3(0.45, h, 0.45), Color(0.24, 0.2, 0.15), at + Vector3(0, h * 0.5, 0))
		trunk.rotation.z = rng.randf_range(-0.25, 0.25)
		_decor.add_child(trunk)
		var arm := Blocks.box(Vector3(1.6, 0.2, 0.2), Color(0.24, 0.2, 0.15), at + Vector3(0.5, h * 0.7, 0))
		arm.rotation.z = rng.randf_range(0.3, 0.8)
		_decor.add_child(arm)
	elif roll < 0.75:
		for i in 6:
			_decor.add_child(Blocks.box(Vector3(0.08, rng.randf_range(0.7, 1.4), 0.08), Color(0.4, 0.46, 0.22),
				at + Vector3(rng.randf_range(-0.8, 0.8), 0.5, rng.randf_range(-0.8, 0.8))))
	else:
		var pool := Blocks.box(Vector3(rng.randf_range(3, 6), 0.06, rng.randf_range(2, 4)), Color(0.2, 0.26, 0.18), at + Vector3(0, 0.03, 0))
		pool.material_override = Blocks.glow(Color(0.2, 0.26, 0.18), 0.1)
		_decor.add_child(pool)


## The ice fields: blocks of ice, snowy pines, drifts.
func _frozen(at: Vector3, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.4:
		var h := rng.randf_range(2.5, 4.5)
		_decor.add_child(Blocks.box(Vector3(0.35, h * 0.5, 0.35), Color(0.3, 0.22, 0.16), at + Vector3(0, h * 0.25, 0)))
		for i in 3:
			var w := 2.0 - i * 0.55
			_decor.add_child(Blocks.box(Vector3(w, 0.8, w), Color(0.2, 0.36, 0.3).lerp(Color(0.92, 0.95, 0.98), 0.35 + i * 0.2),
				at + Vector3(0, h * 0.4 + i * 0.75, 0)))
	elif roll < 0.75:
		var w := rng.randf_range(1.2, 3.0)
		var ice := Blocks.box(Vector3(w, rng.randf_range(0.8, 2.2), w * 0.8), Color(0.72, 0.85, 0.95), at + Vector3(0, 0.6, 0))
		ice.material_override = Blocks.glow(Color(0.72, 0.85, 0.95), 0.15)
		ice.rotation.y = rng.randf() * TAU
		_decor.add_child(ice)
	else:
		var drift := Blocks.box(Vector3(rng.randf_range(2, 4), 0.4, rng.randf_range(1.5, 3)), Color(0.94, 0.96, 0.98), at + Vector3(0, 0.2, 0))
		drift.rotation.y = rng.randf() * TAU
		_decor.add_child(drift)


## The desert: dunes, cacti, red rocks.
func _desert(at: Vector3, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.4:
		var dune := Blocks.box(Vector3(rng.randf_range(4, 8), rng.randf_range(0.6, 1.4), rng.randf_range(2, 4)), Color(0.86, 0.72, 0.48),
			at + Vector3(0, 0.4, 0))
		dune.rotation.y = rng.randf() * TAU
		_decor.add_child(dune)
	elif roll < 0.7:
		var h := rng.randf_range(1.6, 3.0)
		_decor.add_child(Blocks.box(Vector3(0.5, h, 0.5), Color(0.32, 0.5, 0.26), at + Vector3(0, h * 0.5, 0)))
		for side in [-1.0, 1.0]:
			_decor.add_child(Blocks.box(Vector3(0.35, 0.8, 0.35), Color(0.32, 0.5, 0.26), at + Vector3(side * 0.55, h * 0.6, 0)))
	else:
		var rock := Blocks.box(Vector3(rng.randf_range(1.2, 3.0), rng.randf_range(1.0, 2.6), rng.randf_range(1.2, 2.4)),
			Color(0.66, 0.4, 0.28), at + Vector3(0, 0.8, 0))
		rock.rotation.y = rng.randf() * TAU
		_decor.add_child(rock)


## The coast: grey rocks, palms, sandbars in the shallows.
func _coast(at: Vector3, rng: RandomNumberGenerator) -> void:
	var roll := rng.randf()
	if roll < 0.35:
		var h := rng.randf_range(3.0, 5.0)
		var trunk := Blocks.box(Vector3(0.35, h, 0.35), Color(0.5, 0.38, 0.24), at + Vector3(0, h * 0.5, 0))
		trunk.rotation.z = rng.randf_range(-0.2, 0.2)
		_decor.add_child(trunk)
		for i in 5:
			var frond := Blocks.box(Vector3(2.0, 0.1, 0.5), Color(0.24, 0.5, 0.22), at + Vector3(0, h, 0))
			frond.rotation = Vector3(0.35, i * TAU / 5.0, 0.0)
			_decor.add_child(frond)
	elif roll < 0.7:
		var rock := Blocks.box(Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.6, 1.8), rng.randf_range(1.0, 2.2)),
			Color(0.5, 0.5, 0.48), at + Vector3(0, 0.5, 0))
		rock.rotation.y = rng.randf() * TAU
		_decor.add_child(rock)
	else:
		var bar := Blocks.box(Vector3(rng.randf_range(3, 6), 0.08, rng.randf_range(1.5, 3)), Color(0.86, 0.8, 0.62), at + Vector3(0, 0.04, 0))
		bar.rotation.y = rng.randf() * TAU
		_decor.add_child(bar)


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
	_sky.sun_angle_max = 30.0
	_sky.sun_curve = 0.15
	# AgX: bright things roll off softly instead of going to chalk; the colours stay gentle.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	# The sky's light in the shadows, so a shadow is cool and soft, not black.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.85, 0.9, 0.95)
	env.ambient_light_energy = 0.55
	env.ambient_light_sky_contribution = 0.55
	# Feet, walls and roots set down onto the ground.
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.8
	env.ssao_power = 1.5
	env.ssao_detail = 0.5
	# A restrained bloom, laid on softly: what glows glows, nothing turns to neon.
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Haze in the distance only: where the game is played stays clear, what lies beyond fades into the sky.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.76, 0.8, 0.74)
	env.fog_light_energy = 0.85
	env.fog_density = 0.45
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.15
	env.fog_depth_begin = 80.0
	env.fog_depth_end = 170.0
	env.fog_depth_curve = 1.0
	# The air itself: a little haze that catches the sun.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0025
	env.volumetric_fog_albedo = Color(0.9, 0.94, 0.9)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.12
	# A touch more contrast and colour (GAME-DESIGN 21).
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.18
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)