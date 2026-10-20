class_name Effects
## A battle's effects (GAME-DESIGN 23), drawn as a cartoon draws them -- small solid shapes, not glare: where a blow
## lands a quick white ring and a few sparks; a shot flying from the shooter to what it hits -- a glob of spit, a stone
## thrown high, a ball of poison, their violet bolts -- with a short trail; a puff of dust where one of ours falls and
## of dark spores where one of theirs does; a burst's fireball, its smoke and a ring of dust running out along the
## ground, the camera shaken; a heal's green motes rising. Each is made, plays once and is gone; none of them changes
## the battle. All of them Godot's own particles (CPUParticles3D) on one of three round shapes (a solid dot, a soft
## dot, a ring), coloured as they live, so three materials serve them all.

## How each kind of shot looks: its colour, its size, how fast it flies (metres a second), how high it arcs (of the
## way it goes), whether it glows and trails (a stone does not).
const SHOTS := {
	"ours": {"color": Color(1.0, 0.86, 0.45), "size": 0.13, "speed": 24.0, "arc": 0.05, "glow": true},
	"spit": {"color": Color(0.45, 0.95, 1.0), "size": 0.14, "speed": 22.0, "arc": 0.08, "glow": true},
	"stone": {"color": Color(0.5, 0.45, 0.38), "size": 0.14, "speed": 15.0, "arc": 0.3, "glow": false},
	"poison": {"color": Color(0.62, 1.0, 0.3), "size": 0.17, "speed": 16.0, "arc": 0.14, "glow": true},
	"theirs": {"color": Color(0.85, 0.45, 1.0), "size": 0.14, "speed": 20.0, "arc": 0.06, "glow": true},
	"fire": {"color": Color(1.0, 0.55, 0.16), "size": 0.16, "speed": 18.0, "arc": 0.1, "glow": true},
	"heal": {"color": Color(0.5, 1.0, 0.55), "size": 0.11, "speed": 16.0, "arc": 0.2, "glow": true},
}
const DUST := Color(0.7, 0.62, 0.5)
const SPORES := Color(0.3, 0.18, 0.4)

static var _solid_mat: StandardMaterial3D
static var _soft_mat: StandardMaterial3D
static var _ring_mat: StandardMaterial3D
static var _quad: QuadMesh
static var _fading: Curve
static var _swelling: Curve
static var _opening: Curve


## Where a blow lands: a quick white ring opening, and sparks of `c` thrown out, white at first, falling and
## shrinking; `size` scales them (a heavy blow's are bigger).
static func sparks(parent: Node3D, at: Vector3, c: Color, size := 1.0, count := 8) -> void:
	var ring := _particles(1, 0.14, _ring())
	ring.position = at
	ring.gravity = Vector3.ZERO
	ring.initial_velocity_min = 0.0
	ring.initial_velocity_max = 0.0
	ring.scale_amount_min = 0.9 * size
	ring.scale_amount_max = 0.9 * size
	ring.scale_amount_curve = _open_curve()
	ring.color_ramp = _ramp([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0)], [0.0, 1.0])
	_play(parent, ring)
	var p := _particles(count, 0.3, _solid())
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06 * size
	p.direction = Vector3.UP
	p.spread = 85.0
	p.initial_velocity_min = 2.0 * size
	p.initial_velocity_max = 3.8 * size
	p.gravity = Vector3(0, -12.0, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	p.scale_amount_min = 0.09 * size
	p.scale_amount_max = 0.16 * size
	p.scale_amount_curve = _fade_curve()
	p.color_ramp = _ramp([Color(1, 1, 1), c, c], [0.0, 0.3, 1.0])
	_play(parent, p)


## A puff of `c` -- dust, smoke, spores -- swelling, rising a little and thinning out.
static func puff(parent: Node3D, at: Vector3, c: Color, size := 1.0, count := 7, life := 0.8) -> void:
	var p := _particles(count, life, _soft())
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25 * size
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.4 * size
	p.initial_velocity_max = 1.1 * size
	p.gravity = Vector3(0, 0.3, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.35 * size
	p.scale_amount_max = 0.6 * size
	p.scale_amount_curve = _swell_curve()
	var thick := c
	thick.a = 0.6
	var clear := c
	clear.a = 0.0
	p.color_ramp = _ramp([thick, clear], [0.0, 1.0])
	_play(parent, p)


## Motes of `c` rising round something (a heal), `height` tall.
static func motes(parent: Node3D, at: Vector3, c: Color, height: float) -> void:
	var p := _particles(10, 0.7, _solid())
	p.position = at + Vector3.UP * height * 0.3
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, height * 0.3, 0.3)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.1
	p.scale_amount_curve = _fade_curve()
	p.color_ramp = _ramp([c.lightened(0.5), c], [0.0, 1.0])
	_play(parent, p)


## A shot of kind `look` (SHOTS) flying from `from` to `to`, arcing; it lands in `time` seconds.
static func fly(parent: Node3D, from: Vector3, to: Vector3, look: String, time: float) -> void:
	var s: Dictionary = SHOTS.get(look, SHOTS.ours)
	var c: Color = s.color
	var glows: bool = s.glow
	var shot := Node3D.new()
	parent.add_child(shot)
	shot.position = from
	var core := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = float(s.size)
	ball.height = float(s.size) * 2.0
	ball.radial_segments = 10 if glows else 6
	ball.rings = 5 if glows else 3
	core.mesh = ball
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	if glows:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c.lightened(0.3)
	else:
		m.albedo_color = c
		m.roughness = 1.0
	core.material_override = m
	shot.add_child(core)
	if glows:
		# A short trail of its colour: dots left where it was, each shrinking.
		var trail := _particles(24, 0.13, _solid())
		trail.one_shot = false
		trail.explosiveness = 0.0
		trail.initial_velocity_min = 0.0
		trail.initial_velocity_max = 0.2
		trail.spread = 180.0
		trail.gravity = Vector3.ZERO
		# Each dot wide enough to reach the next: one frame's flight apart, they run together into a streak.
		trail.scale_amount_min = float(s.size) * 2.2
		trail.scale_amount_max = float(s.size) * 2.6
		trail.scale_amount_curve = _fade_curve()
		trail.color_ramp = _ramp([c, Color(c.r, c.g, c.b, 0.0)], [0.0, 1.0])
		shot.add_child(trail)
		trail.emitting = true
	var height := from.distance_to(to) * float(s.arc)
	var spin := Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), 0.0)
	var move := func(t: float) -> void:
		shot.position = from.lerp(to, t) + Vector3.UP * height * 4.0 * t * (1.0 - t)
		if not glows:
			core.rotation = spin * t
	# Landed: the ball gone at once, its trail left to fade.
	var land := func() -> void:
		core.hide()
		for k in shot.get_children():
			if k is CPUParticles3D:
				(k as CPUParticles3D).emitting = false
	var tw := shot.create_tween()
	tw.tween_method(move, 0.0, 1.0, maxf(0.04, time))
	tw.tween_callback(land)
	tw.tween_interval(0.2)
	tw.tween_callback(shot.queue_free)


## How long a shot of kind `look` takes from `from` to `to` (at the battle's `pace`).
static func flight(from: Vector3, to: Vector3, look: String, pace := 1.0) -> float:
	var s: Dictionary = SHOTS.get(look, SHOTS.ours)
	return clampf(from.distance_to(to) / float(s.speed), 0.08, 0.45) / maxf(0.1, pace)


## A burst `radius` across: a fireball and its smoke, a ring of dust running out along the ground.
static func fireball(parent: Node3D, at: Vector3, ground: Vector3, radius: float) -> void:
	var p := _particles(22, 0.5, _solid())
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.15
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = radius * 1.4
	p.initial_velocity_max = radius * 2.8
	p.gravity = Vector3(0, 2.0, 0)
	p.damping_min = 4.0
	p.damping_max = 6.0
	p.scale_amount_min = radius * 0.22
	p.scale_amount_max = radius * 0.4
	p.scale_amount_curve = _fade_curve()
	p.color_ramp = _ramp([Color(1.0, 0.95, 0.7), Color(1.0, 0.58, 0.16), Color(0.75, 0.18, 0.05)], [0.0, 0.3, 1.0])
	_play(parent, p)
	puff(parent, at + Vector3.UP * 0.2, Color(0.24, 0.21, 0.2), radius * 0.7, 9, 1.0)
	ring(parent, ground, radius, Color(0.85, 0.7, 0.48))


## A ring of `c` running out along the ground from `at` to `radius` and fading.
static func ring(parent: Node3D, at: Vector3, radius: float, c: Color, time := 0.45) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	var r := MeshInstance3D.new()
	r.mesh = torus
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, 0.65)
	r.material_override = m
	r.position = at + Vector3.UP * 0.05
	r.scale = Vector3(0.2, 0.12, 0.2)
	parent.add_child(r)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "scale", Vector3(radius, 0.12, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


## The camera shaken by `strength` metres, dying away over `time` seconds (its own place untouched: its offsets).
static func shake(cam: Camera3D, strength: float, time := 0.3) -> void:
	if cam == null:
		return
	if cam.has_meta("shake"):
		var old: Tween = cam.get_meta("shake")
		if old != null and old.is_valid():
			old.kill()
	var tw := cam.create_tween()
	cam.set_meta("shake", tw)
	var steps := 7
	for i in steps:
		var k := strength * (1.0 - float(i) / steps)
		tw.tween_property(cam, "h_offset", randf_range(-k, k), time / steps)
		tw.parallel().tween_property(cam, "v_offset", randf_range(-k, k), time / steps)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)


# -- Making them ------------------------------------------------------------------------------------------------------

static func _particles(count: int, life: float, mat: Material) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.mesh = _quad_mesh()
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _play(parent: Node3D, p: CPUParticles3D) -> void:
	parent.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(p.lifetime + 0.2)
	tw.tween_callback(p.queue_free)


static func _ramp(colours: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colours)
	return g


## A round shape, white, its alpha by how far out from the middle (0 at the middle, 1 at the edge).
static func _round(alphas: Array, offsets: Array) -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.gradient = _ramp(alphas.map(func(a: float) -> Color: return Color(1, 1, 1, a)), offsets)
	return t


## A solid dot with a crisp edge (sparks, motes, trails, fire).
static func _solid() -> StandardMaterial3D:
	if _solid_mat == null:
		_solid_mat = _dot_material(_round([1.0, 1.0, 0.0], [0.0, 0.62, 0.8]))
	return _solid_mat


## A soft dot (dust, smoke, spores).
static func _soft() -> StandardMaterial3D:
	if _soft_mat == null:
		_soft_mat = _dot_material(_round([1.0, 0.7, 0.0], [0.0, 0.45, 1.0]))
	return _soft_mat


## A thin ring (a blow's flash).
static func _ring() -> StandardMaterial3D:
	if _ring_mat == null:
		_ring_mat = _dot_material(_round([0.0, 0.0, 1.0, 1.0, 0.0], [0.0, 0.6, 0.7, 0.8, 0.9]))
	return _ring_mat


static func _dot_material(shape: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true          # each dot its own size (without it, all a metre across)
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = shape
	return m


static func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## 1 to 0 over a life: sparks and motes going out.
static func _fade_curve() -> Curve:
	if _fading == null:
		_fading = Curve.new()
		_fading.add_point(Vector2(0.0, 1.0))
		_fading.add_point(Vector2(1.0, 0.0))
	return _fading


## Half to whole over a life: a puff spreading.
static func _swell_curve() -> Curve:
	if _swelling == null:
		_swelling = Curve.new()
		_swelling.add_point(Vector2(0.0, 0.5))
		_swelling.add_point(Vector2(1.0, 1.0))
	return _swelling


## A third to whole, quickly: a blow's ring opening.
static func _open_curve() -> Curve:
	if _opening == null:
		_opening = Curve.new()
		_opening.add_point(Vector2(0.0, 0.3))
		_opening.add_point(Vector2(0.5, 0.85))
		_opening.add_point(Vector2(1.0, 1.0))
	return _opening
