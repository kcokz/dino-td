# res://scripts/entities/Fire.gd
class_name Fire
extends "res://scripts/entities/Building.gd"

## A fire he built (GAME-DESIGN 9.3, "火与夜"; v0.6 round four, the player: "火把我觉得在夜里是很有用，但需要
## 不只是照明的作用，比如不用火把，晚上更多的夜行动物袭击（怕火把但是不怕暗淡灯光的船舱）"): a campfire or a
## brazier (Config.BUILDINGS, kind "fire").
##
## It burns from dusk to first light (Config.FIRE.burns), and what it burns is wood from the stock, a
## night's worth taken as it lights (GAME-DESIGN 5.4 rule 4: "燃料和弹药直接从仓库扣，不用人跑过去添。添柴
## 就是照料"). No wood, no fire: it tries again every little while (FIRE.retry_seconds), so wood
## brought in lights it, and says so once a night (EventBus.fire_starved). Lit, it lights the ground
## round it (BUILDINGS.<id>.light): seen at night as far as its light reaches (FogOfWar), and what
## hunts by night will not come into it (Dino, DINOS.<id>.fears_fire).
##
## Its flame is the engine's own -- particles rising off the wood and a light that wavers
## (make_flame, which the torch in his hand shares); the stones and the wood are its model
## (tools/generate_props.py campfire, brazier).

## Every fire, for what asks where the light is (Dino: keeping out of it; WaveManager: whether the
## camp is lit).
const GROUP: String = "fires"

## Whether it burns now.
var lit: bool = false
## The night its wood was taken for (GameState.day_number): a night is paid for once.
var _paid_night: int = -1
## The night it said it had no wood, so it is said once.
var _starved_night: int = -1
var _retry: float = 0.0
var _clock: float = 0.0
var _light: OmniLight3D = null
var _flame: GPUParticles3D = null

func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	_make_the_flame()
	_show_the_flame()

func _process(delta: float) -> void:
	_clock += delta
	_tend(delta)
	if lit and _light != null:
		_light.light_energy = Fire.flicker_energy(_fire_cfg(), _clock + float(get_instance_id() % 97))

# ==============================================================================
# Burning
# ==============================================================================

## Lit when the dark comes and there is wood for it; put out at first light.
func _tend(delta: float) -> void:
	var want: bool = burns_now()
	if want and not lit:
		_retry -= delta
		if _retry > 0.0:
			return
		_retry = float(_fire_cfg().get("retry_seconds", 2.0))
		if _take_the_nights_wood():
			_set_lit(true)
		else:
			_say_it_is_starved()
	elif not want and lit:
		_set_lit(false)

## Whether it should be burning: finished, standing, and the dark part of the day (Config.FIRE.burns).
func burns_now() -> bool:
	if not is_constructed or is_destroyed:
		return false
	var gs = _get_game_state()
	if gs == null or not gs.has_method("day_part"):
		return false
	return String(gs.day_part()) in _fire_cfg().get("burns", ["dusk", "night"])

## The night's wood, from the stock (BUILDINGS.<id>.fuel): taken once a night, and true once taken.
func _take_the_nights_wood() -> bool:
	var gs = _get_game_state()
	if gs == null:
		return false
	var night: int = int(gs.day_number()) if gs.has_method("day_number") else 0
	if _paid_night == night:
		return true
	var fuel: Dictionary = fuel_cost()
	if fuel.is_empty() or (gs.has_method("spend_resources") and gs.spend_resources(fuel)):
		_paid_night = night
		return true
	return false

## What a night of it burns: {"wood": n}.
func fuel_cost() -> Dictionary:
	var n: int = int(_row().get("fuel", 0))
	return {"wood": n} if n > 0 else {}

func _say_it_is_starved() -> void:
	var gs = _get_game_state()
	var night: int = int(gs.day_number()) if (gs and gs.has_method("day_number")) else 0
	if _starved_night == night:
		return
	_starved_night = night
	var eb = _get_event_bus()
	if eb and eb.has_signal("fire_starved"):
		eb.fire_starved.emit(self)

func _set_lit(on: bool) -> void:
	if lit == on:
		return
	lit = on
	_show_the_flame()
	var eb = _get_event_bus()
	if eb and eb.has_signal("fire_changed"):
		eb.fire_changed.emit(self, lit)

## How far its light reaches now, in metres: its own (BUILDINGS.<id>.light) while it burns, else none.
func light_radius() -> float:
	return float(_row().get("light", 0.0)) if lit else 0.0

func destroy() -> void:
	_set_lit(false)
	super.destroy()

## What its card says under its bars: burning and how far it lights; waiting for the dusk and what a
## night of it costs; or that it has no wood tonight.
func _panel_status() -> String:
	if not is_constructed:
		return ""
	if lit:
		return tr("STATUS_FIRE_LIT") % light_radius()
	if burns_now():
		return tr("STATUS_FIRE_STARVED")
	return tr("STATUS_FIRE_DAY") % int(_row().get("fuel", 0))

func _row() -> Dictionary:
	var cfg = _get_config()
	return cfg.BUILDINGS.get(building_type, {}) if (cfg and "BUILDINGS" in cfg) else {}

func _fire_cfg() -> Dictionary:
	var cfg = _get_config()
	return cfg.FIRE if (cfg and "FIRE" in cfg) else {}

# ==============================================================================
# The flame
# ==============================================================================

func _make_the_flame() -> void:
	var fire: Dictionary = _fire_cfg()
	var at: float = float(_row().get("flame_height", 0.3))
	if _flame == null:
		_flame = Fire.make_flame(fire, float(_row().get("flame_size", 1.0)))
		_flame.name = "Flame"
		_flame.position = Vector3(0.0, at, 0.0)
		add_child(_flame)
	if _light == null:
		_light = OmniLight3D.new()
		_light.name = "FireLight"
		_light.position = Vector3(0.0, at + float(fire.get("light_above", 0.4)), 0.0)
		_light.light_color = fire.get("light_color", Color(1.0, 0.6, 0.3))
		# The light reaches a little past where it keeps the night off: the edge of it is dim.
		_light.omni_range = float(_row().get("light", 6.0)) * float(fire.get("light_reach", 1.25))
		_light.omni_attenuation = float(fire.get("light_attenuation", 1.2))
		_light.shadow_enabled = false
		add_child(_light)

func _show_the_flame() -> void:
	if _flame != null:
		_flame.emitting = lit
		_flame.visible = lit
	if _light != null:
		_light.visible = lit

## The flame of a fire, `size` times the campfire's (Config.FIRE.flame): the engine's particles --
## soft tongues rising off the wood, yellow to red to nothing -- drawn over the world and left where
## they rose, so a torch carried trails its flame. Shared with the torch in his hand (Hero).
static func make_flame(fire: Dictionary, size: float = 1.0) -> GPUParticles3D:
	var f: Dictionary = fire.get("flame", {})
	var p := GPUParticles3D.new()
	p.amount = int(f.get("amount", 24))
	p.lifetime = float(f.get("lifetime", 0.7))
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = float(f.get("spread", 0.12)) * size
	m.direction = Vector3.UP
	m.spread = float(f.get("spread_degrees", 12.0))
	m.gravity = Vector3(0.0, float(f.get("rise", 0.6)) * size, 0.0)
	m.initial_velocity_min = float(f.get("speed_min", 0.3)) * size
	m.initial_velocity_max = float(f.get("speed_max", 0.7)) * size
	m.damping_min = 0.5
	m.damping_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.15))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	m.scale_curve = shrink_tex
	var ramp := Gradient.new()
	var colours: Array = f.get("colours", [Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.5, 0.12, 0.85), Color(0.5, 0.1, 0.03, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray(colours)
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	ramp_tex.use_hdr = true
	m.color_ramp = ramp_tex
	p.process_material = m
	var quad := QuadMesh.new()
	var q: float = float(f.get("tongue", 0.3)) * size
	quad.size = Vector2(q, q * 1.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Fire._soft_disc()
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-1.0, -0.5, -1.0) * size, Vector3(2.0, 2.5, 2.0) * size)
	return p

## A soft round spot, white in the middle and clear at the edge: what one tongue of flame is drawn with.
static func _soft_disc() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t

## A fire's light at `t` seconds: its energy (Config.FIRE.light_energy), wavering by `flicker` of it at
## `flicker_speed` -- three waves out of step, so it never repeats in a way anybody sees.
static func flicker_energy(fire: Dictionary, t: float) -> float:
	var base: float = float(fire.get("light_energy", 2.0))
	var amount: float = float(fire.get("flicker", 0.2))
	var speed: float = float(fire.get("flicker_speed", 7.0))
	var wave: float = sin(t * speed) * 0.5 + sin(t * speed * 2.3 + 1.7) * 0.3 + sin(t * speed * 5.1 + 0.4) * 0.2
	return base * (1.0 + amount * wave)
