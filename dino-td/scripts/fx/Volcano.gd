# res://scripts/fx/Volcano.gd
class_name Volcano

## A volcano on the skyline: the cone and its smoke, built from one Config.VOLCANOES entry.
##
## The one silhouette that says "the age of dinosaurs" before anything on the field
## moves. It is scenery at the far end of what the camera can see, and lives under the
## same rules as the ground cover: NOTHING HERE COLLIDES and nothing is on the grid. It
## stands well past the valley rim, with its foot below the valley floor, so it rises
## out of the land beyond the rim and nothing a raid or the Hero can reach is ever near it.
##
## Everything is the engine's own: a mesh built like the valley floor is, and
## GPUParticles3D for the smoke.

# ==============================================================================
# Where
# ==============================================================================

## The centre of the cone's foot, in the world.
##
## `bearing` is on the camera rig's compass -- the yaw at which the view looks straight
## at it (CameraRig.offset) -- so a number in Config can be checked by turning the camera.
static func centre_of(spec: Dictionary, cfg: Node) -> Vector3:
	var bearing: float = deg_to_rad(float(spec.get("bearing", 0.0)))
	var distance: float = float(spec.get("distance", 250.0))
	return Vector3(-sin(bearing) * distance, _num(cfg, "base_y", -14.0), -cos(bearing) * distance)

# ==============================================================================
# The cone
# ==============================================================================

## Height of the cone above its foot, `r` metres out from the centre at angle `theta`.
##
## A crater bowl inside the lip; outside it, flanks that steepen towards the top (a
## power curve, not a straight line -- a straight cone reads as a traffic cone at any
## distance), cut by radial gullies where the ash runs off, and roughened a little.
## Gullies and roughness both fade out at the lip and at the foot, so neither the rim of
## the crater nor the line where the cone meets the land beyond the valley is ragged.
## One side of the top has fallen away (the breach), and that notch fades out down the
## flank the same way.
static func height_at(spec: Dictionary, cfg: Node, r: float, theta: float, noise: FastNoiseLite = null) -> float:
	var height: float = float(spec.get("height", 80.0))
	var radius: float = float(spec.get("radius", 180.0))
	var crater: float = float(spec.get("crater", 15.0))
	if r >= radius:
		return 0.0
	var notch: float = height * _num(cfg, "breach_depth", 0.07) * _breach(spec, cfg, theta)
	if r <= crater:
		var depth: float = height * _num(cfg, "crater_depth", 0.09)
		var k: float = r / maxf(0.001, crater)
		return height - depth * (1.0 - k * k) - notch * k * k

	var t: float = (r - crater) / maxf(0.001, radius - crater)       # 0 at the lip, 1 at the foot
	var h: float = height * pow(1.0 - t, _num(cfg, "profile_power", 2.4))
	var flank: float = sin(PI * t)                                  # 0 at the lip and the foot
	h -= notch * pow(1.0 - t, 3.0)

	if noise == null:
		noise = _noise(spec)
	var gullies: float = _num(cfg, "gullies", 13.0)
	# The gullies wander a little rather than running dead straight down the cone.
	var wander: float = noise.get_noise_2d(r * 0.05, 7.0) * 0.6
	var gully: float = 0.5 + 0.5 * cos(gullies * theta + wander)
	h -= height * _num(cfg, "gully_depth", 0.05) * flank * gully
	h += height * _num(cfg, "roughness", 0.05) * flank * noise.get_noise_2d(cos(theta) * r, sin(theta) * r)
	return maxf(0.0, h)

## How much of the breach is at angle `theta`: 1 in the middle of it, easing to 0 at
## its edges.
static func _breach(spec: Dictionary, cfg: Node, theta: float) -> float:
	if not spec.has("breach"):
		return 0.0
	var off: float = absf(angle_difference(theta, deg_to_rad(float(spec["breach"]))))
	var half: float = deg_to_rad(_num(cfg, "breach_width", 55.0)) * 0.5
	if off >= half:
		return 0.0
	return 0.5 + 0.5 * cos(PI * off / half)

## The height of the cone at a point in the world, or -INF where the cone is not.
static func world_height_at(spec: Dictionary, cfg: Node, x: float, z: float) -> float:
	var c: Vector3 = centre_of(spec, cfg)
	var d := Vector2(x - c.x, z - c.z)
	if d.length() >= float(spec.get("radius", 180.0)):
		return -INF
	return c.y + height_at(spec, cfg, d.length(), atan2(d.y, d.x))

## The cone as one mesh, in its own space: origin at the centre of its foot.
static func cone_mesh(spec: Dictionary, cfg: Node) -> Mesh:
	var radius: float = float(spec.get("radius", 180.0))
	var crater: float = float(spec.get("crater", 15.0))
	var height: float = float(spec.get("height", 80.0))
	var rings: int = maxi(4, int(_num(cfg, "rings", 26.0)))
	var segments: int = maxi(12, int(_num(cfg, "segments", 72.0)))

	# Radii from the middle of the crater out to the foot: a few across the bowl, then
	# rings that space out down the flanks, where there is less going on.
	var radii: Array[float] = [0.0, crater * 0.45, crater * 0.8, crater]
	for i in range(1, rings + 1):
		radii.append(crater + (radius - crater) * pow(float(i) / float(rings), 1.3))

	var noise := _noise(spec)
	var grid: Array = []
	var tints: Array = []
	for r in radii:
		var ring: Array[Vector3] = []
		var tint: Array[Color] = []
		for k in range(segments):
			var theta: float = TAU * float(k) / float(segments)
			var h: float = height_at(spec, cfg, r, theta, noise)
			ring.append(Vector3(cos(theta) * r, h, sin(theta) * r))
			tint.append(_colour_at(spec, cfg, r, h))
		grid.append(ring)
		tints.append(tint)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(grid.size() - 1):
		for k in range(segments):
			var k2: int = (k + 1) % segments
			# Clockwise seen from above, which is the engine's front face: wound the other
			# way round, the cone is culled from every side anyone can see it from.
			for v in [[i, k], [i + 1, k], [i, k2], [i, k2], [i + 1, k], [i + 1, k2]]:
				st.set_color(tints[v[0]][v[1]])
				st.add_vertex(grid[v[0]][v[1]])
	st.generate_normals()
	return st.commit()

## Forest low on the flanks, ash above the treeline, dark rock at the top, and scorched
## inside the crater.
static func _colour_at(spec: Dictionary, cfg: Node, r: float, h: float) -> Color:
	var height: float = float(spec.get("height", 80.0))
	var crater: float = float(spec.get("crater", 15.0))
	var forest: Color = _col(cfg, "forest", Color(0.13, 0.19, 0.09))
	var ash: Color = _col(cfg, "ash", Color(0.36, 0.33, 0.30))
	var summit: Color = _col(cfg, "summit", Color(0.21, 0.19, 0.18))
	if r < crater:
		return _col(cfg, "scorched", Color(0.30, 0.15, 0.09))
	var up: float = clampf(h / maxf(0.001, height), 0.0, 1.0)     # 0 at the foot, 1 at the lip
	var treeline: float = _num(cfg, "treeline", 0.42)
	if up < treeline:
		return forest.lerp(ash, smoothstep(treeline * 0.6, treeline, up))
	return ash.lerp(summit, smoothstep(0.7, 1.0, up))

static func cone_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true      # authored the way COLORS are
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat

# ==============================================================================
# The smoke
# ==============================================================================

## The plume, rising out of the crater and bending over in the wind.
##
## Fully formed from the first frame (`preprocess` runs a whole lifetime before anything
## is drawn): a volcano whose smoke visibly starts when the level loads is a set piece
## being switched on, not a mountain that has been smoking for a thousand years.
static func smoke(spec: Dictionary, cfg: Node) -> GPUParticles3D:
	var s: Dictionary = cfg.VOLCANOES.get("smoke", {}) if cfg != null and "VOLCANOES" in cfg else {}
	var crater: float = float(spec.get("crater", 15.0))
	var height: float = float(spec.get("height", 80.0))
	var lifetime: float = float(s.get("lifetime", 50.0))
	var speed: float = float(s.get("speed", 2.6))
	var size_max: float = float(s.get("size_max", 52.0))
	var spread: float = float(s.get("spread", 7.0))
	var wind: Vector3 = s.get("wind", Vector3(0.055, 0.0, 0.02))

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = crater * 0.5
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.8
	pm.initial_velocity_max = speed * 1.2
	# The wind is the only force on it, and a steady one, so it acts exactly like gravity
	# turned on its side. No turbulence: the engine blends a share of every particle's
	# heading into the noise field EVERY FRAME, and at any share big enough to see, the
	# puffs forgot which way was up within a few frames and milled about the vent.
	pm.gravity = wind
	pm.damping_min = float(s.get("slowing", 0.02))
	pm.damping_max = float(s.get("slowing", 0.02))
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = float(s.get("size_min", 13.0))
	pm.scale_max = size_max
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, float(s.get("start_scale", 0.35))))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var low: Color = s.get("colour", Color(0.30, 0.28, 0.27, 0.85))
	var high: Color = s.get("colour_high", Color(0.56, 0.54, 0.51, 0.5))
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.06, 0.55, 1.0])
	ramp.colors = PackedColorArray([Color(low, 0.0), low, high, Color(high, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex

	var puff := StandardMaterial3D.new()
	puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.vertex_color_use_as_albedo = true
	puff.albedo_texture = _puff_texture()
	puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.billboard_keep_scale = true
	puff.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.material = puff

	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = int(s.get("amount", 70))
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.randomness = 0.3
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.process_material = pm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, height, 0.0)
	# Where the plume can get to, so it is not culled whenever the crater itself is off
	# the edge of the screen: as high as the fastest puff could climb in a lifetime, as far
	# sideways as its spread and the wind could carry it, and a fully grown puff's width
	# round all of that. Upper bounds -- the slowing only ever makes the real plume smaller.
	var v_max: float = speed * 1.2
	var rise: float = v_max * lifetime + 0.5 * maxf(0.0, wind.y) * lifetime * lifetime
	var drift: float = v_max * sin(deg_to_rad(spread)) * lifetime \
		+ 0.5 * Vector2(wind.x, wind.z).length() * lifetime * lifetime
	var reach: float = drift + size_max
	p.visibility_aabb = AABB(Vector3(-reach, -size_max, -reach), Vector3(reach * 2.0, rise + size_max * 2.0, reach * 2.0))
	return p

## A soft, uneven puff: a round falloff broken up by noise, so a column of them reads as
## billowing smoke rather than as a stack of discs. Made once and shared.
static var _puff: Texture2D = null

static func _puff_texture() -> Texture2D:
	if _puff != null:
		return _puff
	var size: int = 64
	var noise := FastNoiseLite.new()
	noise.seed = 4051
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x) + 0.5 - size * 0.5, float(y) + 0.5 - size * 0.5).length() / (size * 0.5)
			var fall: float = clampf(1.0 - d, 0.0, 1.0)
			fall = fall * fall * (3.0 - 2.0 * fall)
			var a: float = fall * clampf(0.65 + 0.55 * noise.get_noise_2d(x, y), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	img.generate_mipmaps()
	_puff = ImageTexture.create_from_image(img)
	return _puff

# ==============================================================================
# Put together
# ==============================================================================

## The whole volcano, placed.
static func build(spec: Dictionary, cfg: Node) -> Node3D:
	var root := Node3D.new()
	root.name = "Volcano_%d" % int(spec.get("seed", 0))
	root.position = centre_of(spec, cfg)
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = cone_mesh(spec, cfg)
	cone.material_override = cone_material()
	# Far past the sun's shadow distance: it would cast nothing anyone could see, and
	# the shadow pass would still have to draw it.
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cone)
	root.add_child(smoke(spec, cfg))
	return root

# ==============================================================================
# Plumbing
# ==============================================================================

static func _noise(spec: Dictionary) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = int(spec.get("seed", 11))
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_octaves = 3
	return n

static func _num(cfg: Node, key: String, fallback: float) -> float:
	if cfg != null and "VOLCANOES" in cfg:
		return float(cfg.VOLCANOES.get(key, fallback))
	return fallback

static func _col(cfg: Node, key: String, fallback: Color) -> Color:
	if cfg != null and "VOLCANOES" in cfg:
		return cfg.VOLCANOES.get(key, fallback)
	return fallback
