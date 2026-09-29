# res://scripts/fx/WreckSmoke.gd
class_name WreckSmoke
extends GPUParticles3D

## The smoke over one of the ship's wrecks while it has not been searched (Config.WRECKS; GAME-DESIGN
## 9.3, the player: "烟柱，远处看得见"): a column of the engine's particles rising off it, leaning on
## the wind, some twenty metres of it. It is drawn over the fog of war -- one step after the mist
## (FogOfWar), so it rises out of the mist where nothing else on unseen ground is drawn: where the
## wrecks lie is known from the cabin from the first, and what is on the way to them is not. It is
## not the wreck's own child, which the fog hides until it is seen; the level raises it beside it
## (Main.spawn_resource_nodes). Searched, it stops, and what is in the air thins away.

## Drawn after everything, the mist included (FogOfWar draws at one less).
const PRIORITY: int = Material.RENDER_PRIORITY_MAX
const GROUP: String = "wreck_smoke"

## The wreck it rises off.
var wreck: Node3D = null

## Smoke for `over`, from Config.WRECKS.smoke, already risen: the column is there when the level is.
static func make(over: Node3D) -> WreckSmoke:
	var cfg = Engine.get_main_loop().root.get_node_or_null("Config") if Engine.get_main_loop() is SceneTree else null
	var s: Dictionary = cfg.WRECKS.get("smoke", {}) if (cfg and "WRECKS" in cfg) else {}
	var p := WreckSmoke.new()
	p.name = "Smoke_%s" % String(over.name)
	p.wreck = over
	p.amount = int(s.get("amount", 56))
	p.lifetime = float(s.get("lifetime", 16.0))
	p.preprocess = p.lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = float(s.get("spread", 0.5))
	m.direction = Vector3.UP
	m.spread = 8.0
	var rise: float = float(s.get("rise", 1.6))
	m.initial_velocity_min = rise * 0.8
	m.initial_velocity_max = rise * 1.2
	m.gravity = s.get("wind", Vector3(0.04, 0.0, 0.02))
	m.damping_min = float(s.get("damping", 0.05))
	m.damping_max = float(s.get("damping", 0.05)) * 1.5
	# No turbulence: it turns each puff's way towards its noise a little every frame, and in a few
	# seconds the rise was turned into drifting about at the height of a man -- smoke lying on the
	# ground. The wind and the spread are what vary it.
	m.angle_min = 0.0
	m.angle_max = 360.0
	# Each puff grows from `puff` to `billow` times it as it rises.
	var billow: float = maxf(1.0, float(s.get("billow", 4.0)))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 1.0 / billow))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	# Thin where it leaves the wreck, thickest some way up, thinning away at the top.
	var c: Color = s.get("colour", Color(0.46, 0.44, 0.42))
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	var colours := PackedColorArray()
	for key in s.get("alpha", [[0.0, 0.0], [0.35, 0.34], [1.0, 0.0]]):
		offsets.append(float(key[0]))
		colours.append(Color(c.r, c.g, c.b, float(key[1])))
	ramp.offsets = offsets
	ramp.colors = colours
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	var quad := QuadMesh.new()
	var puff: float = float(s.get("puff", 1.2)) * billow
	quad.size = Vector2(puff, puff)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	# Its colours as they are written (WRECKS.smoke.colour), not as linear light: taken as linear,
	# the dark grey came out pale, the mist's own grey.
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = Fire._soft_disc()
	mat.disable_receive_shadows = true
	# As bright as the valley is lit at the hour (_process), not by the sun on each puff -- lit, the
	# sun turned it to cotton -- and soft where it meets the ground.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 1.0
	mat.render_priority = PRIORITY
	quad.material = mat
	p.draw_pass_1 = quad
	p._material = mat
	p._light = s.get("light", Vector2(0.45, 0.6))
	var high: float = rise * p.lifetime * 1.2
	p.visibility_aabb = AABB(Vector3(-high * 0.4, -1.0, -high * 0.4), Vector3(high * 0.8, high + 2.0, high * 0.8))
	return p

func _ready() -> void:
	add_to_group(GROUP)
	if wreck != null and is_instance_valid(wreck) and wreck.is_inside_tree():
		global_position = wreck.global_position

## Its puffs' material, and how much of the sun's energy and the sky's light it takes (WRECKS.smoke.light).
var _material: StandardMaterial3D = null
var _light: Vector2 = Vector2(0.45, 0.6)
var _lit_clock: float = 0.0

## As bright as the valley is lit now: the sun's energy and the sky's at the hour (Config.DAY.light).
func _tint() -> void:
	var cfg = get_node_or_null("/root/Config")
	var gs = get_node_or_null("/root/GameState")
	if _material == null or cfg == null or not ("DAY" in cfg) or gs == null or not gs.has_method("time_of_day"):
		return
	var now: Dictionary = SceneEnvironment.light_at(cfg.DAY.get("light", []), float(cfg.DAY.get("length", 360.0)),
		float(gs.time_of_day()))
	var k: float = clampf(float(now.get("sun_energy", 1.0)) * _light.x + float(now.get("ambient_energy", 0.5)) * _light.y, 0.05, 1.0)
	_material.albedo_color = Color(k, k, k)

## Searched, or gone with its level: no more smoke, and once what is in the air has thinned away
## (a lifetime on), nothing. Tinted to the hour every half second.
func _process(delta: float) -> void:
	_lit_clock -= delta
	if _lit_clock <= 0.0:
		_lit_clock = 0.5
		_tint()
	if not emitting:
		_thinning -= delta
		if _thinning <= 0.0:
			queue_free()
		return
	var searched: bool = wreck == null or not is_instance_valid(wreck) or ("is_depleted" in wreck and bool(wreck.is_depleted))
	if searched:
		emitting = false
		_thinning = lifetime

var _thinning: float = 0.0

## Whether it is still rising.
func is_smoking() -> bool:
	return emitting
