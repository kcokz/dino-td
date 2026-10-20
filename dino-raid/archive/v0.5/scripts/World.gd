class_name World
extends Node3D
## Where it all stands (GAME-DESIGN 12): grass all round, the homeland's bare ground, a road north out of it, and
## at the road's end the field where battles are fought. Flat colours for now.

const ARENA := Vector3(0, 0, -80)       # the battle field's middle; Fight's (x, z) are measured from here
const FIELD := Vector2(36, 20)
const GROUND_TOP := 0.05                # the homeland's ground and the field stand this high


func _ready() -> void:
	_environment()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)
	add_child(Blocks.box(Vector3(600, 0.2, 600), Color(0.33, 0.47, 0.25), Vector3(0, -0.1, -40)))
	add_child(Blocks.box(Vector3(27, 0.1, 31), Color(0.47, 0.38, 0.28), Vector3(0, 0, 5)))
	add_child(Blocks.box(Vector3(4, 0.06, 60), Color(0.52, 0.44, 0.32), Vector3(0, 0, -40)))
	add_child(Blocks.box(Vector3(FIELD.x, 0.1, FIELD.y), Color(0.56, 0.49, 0.36), ARENA))
	add_child(Blocks.box(Vector3(0.24, 0.12, FIELD.y), Color(0.42, 0.35, 0.25), ARENA))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := ARENA + Vector3(sx * FIELD.x * 0.5, 0, sz * FIELD.y * 0.5)
			add_child(Blocks.box(Vector3(0.6, 2.4, 0.6), Color(0.45, 0.36, 0.26), post + Vector3(0, 1.2, 0)))
			var flag := Color(0.85, 0.3, 0.25) if sx > 0 else Color(0.3, 0.55, 0.9)
			add_child(Blocks.box(Vector3(0.05, 0.7, 1.0), flag, post + Vector3(0, 2.1, 0.55 * -sz)))
	# Some blocks of rock and green round about, so the ground is somewhere.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 70:
		var at := Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-120, 40))
		if absf(at.x) < 16 and at.z > -12 and at.z < 24:
			continue
		if absf(at.x - ARENA.x) < FIELD.x * 0.5 + 3 and absf(at.z - ARENA.z) < FIELD.y * 0.5 + 3:
			continue
		if absf(at.x) < 4:
			continue
		var tree := rng.randf() < 0.65
		var h := rng.randf_range(1.5, 4.5) if tree else rng.randf_range(0.6, 1.6)
		var w := rng.randf_range(1.2, 2.6)
		var c := Color(0.25, 0.42, 0.22).lerp(Color(0.33, 0.5, 0.25), rng.randf()) if tree \
			else Color(0.5, 0.48, 0.44).lerp(Color(0.62, 0.58, 0.5), rng.randf())
		var b := Blocks.box(Vector3(w, h, w * rng.randf_range(0.8, 1.2)), c, at + Vector3(0, h * 0.5, 0))
		b.rotation.y = rng.randf() * TAU
		add_child(b)


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.55, 0.82)
	sky_mat.sky_horizon_color = Color(0.74, 0.82, 0.88)
	sky_mat.ground_horizon_color = Color(0.74, 0.82, 0.88)
	sky_mat.ground_bottom_color = Color(0.35, 0.4, 0.32)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
