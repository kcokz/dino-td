class_name Fx
## Particle helpers: soft puffs for the smell of meat and the dust a noise throws up.

static var _puff: StandardMaterial3D


## A soft round puff, coloured by the particles.
static func puff_material() -> StandardMaterial3D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_puff = StandardMaterial3D.new()
		_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_puff.billboard_keep_scale = true  # else every puff is drawn a metre across, whatever its scale
		_puff.vertex_color_use_as_albedo = true
		_puff.albedo_texture = tex
	return _puff


## Fades in to `alpha` of `c`, then out.
static func ramp(c: Color, alpha: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(c, 0.0), Color(c, alpha), Color(c, 0.0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func particles(mat: ParticleProcessMaterial, amount: int, life: float) -> GPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = puff_material()
	var p := GPUParticles3D.new()
	p.process_material = mat
	p.draw_pass_1 = quad
	p.amount = amount
	p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 12, 60))
	return p


## A ring of dust thrown out along the ground: what a noise looks like (a call's, paler).
static func dust_ring(at: Vector3, reach: float, colour := Color(0.62, 0.55, 0.42)) -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 1.0
	mat.emission_ring_inner_radius = 0.6
	mat.emission_ring_height = 0.1
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 180.0
	mat.flatness = 1.0
	mat.initial_velocity_min = reach * 0.9
	mat.initial_velocity_max = reach * 1.2
	mat.damping_min = reach * 0.7
	mat.damping_max = reach * 0.9
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color_ramp = ramp(colour, 0.55)
	var p := particles(mat, 120, 1.4)
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = at + Vector3.UP * 0.5
	return p
