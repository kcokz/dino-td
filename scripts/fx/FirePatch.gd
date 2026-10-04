# res://scripts/fx/FirePatch.gd
class_name FirePatch
extends Node3D

## A PATCH OF GROUND ON FIRE where a fire pot came down (Catapult; Config.AMMO.fire_pot "burn"; GAME-DESIGN 6.0, station
## 2: "火挪到第 2 站，做成投石塔扔的火罐"). The pot breaks and its burning resin spreads: for `seconds` the patch burns,
## `radius` metres round, and everything on the ground in it is burnt `dps` a second -- what flies is above it. It
## lights the ground round it as a fire does (`light` metres), and dies down over its last `fade` seconds. It burns
## where it fell: nothing is set alight beyond it (GAME-DESIGN 13: no spreading fire).

const GROUP: String = "fire_patches"

## Its numbers (AMMO.<id>.burn): seconds, radius, dps, light, fade.
var burn: Dictionary = {}
var _left: float = 0.0
var _tick: float = 0.0
var _light: OmniLight3D = null
var _flames: Array[GPUParticles3D] = []
## Its light's strength and how it wavers (Fire.flicker_energy), and how long it has burnt.
var _glow: Dictionary = {}
var _age: float = 0.0

## A patch burning at `at` under `parent`, as `row` (AMMO) says.
static func ignite(parent: Node, at: Vector3, row: Dictionary) -> FirePatch:
	var p := FirePatch.new()
	p.name = "FirePatch"
	p.burn = (row.get("burn", {}) as Dictionary).duplicate()
	parent.add_child(p)
	p.global_position = Vector3(at.x, 0.0, at.z)
	return p

func _ready() -> void:
	add_to_group(GROUP)
	_left = float(burn.get("seconds", 6.0))
	_build()

func _number(key: String, fallback: float) -> float:
	return float(burn.get(key, fallback))

func radius() -> float:
	return _number("radius", 2.0)

## Seconds of burning left.
func seconds_left() -> float:
	return _left

## How far round it its fire lights the ground while it burns (AMMO.<id>.burn "light"): a light like a campfire's
## (ProwlerDino.lights) -- the towers see by it in the dark, and what keeps out of firelight keeps out of it.
func light_radius() -> float:
	return _number("light", 5.0) if _left > 0.0 else 0.0

func _build() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cfg = get_node_or_null("/root/Config")
	var look: Dictionary = cfg.FIRE_PATCH if (cfg and "FIRE_PATCH" in cfg) else {}
	var fire: Dictionary = cfg.FIRE if (cfg and "FIRE" in cfg) else {}
	# A fire's light, wavering as a fire's does (Fire.flicker_energy), at its own strength.
	_glow = {"light_energy": float(look.get("light_energy", 2.0)), "flicker": fire.get("flicker", 0.2),
		"flicker_speed": fire.get("flicker_speed", 7.0)}
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = look.get("light_color", Color(1.0, 0.6, 0.3))
	_light.light_energy = float(_glow["light_energy"])
	_light.omni_range = _number("light", 5.0)
	_light.omni_attenuation = float(fire.get("light_attenuation", 1.0))
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, float(look.get("light_height", 0.8)), 0.0)
	add_child(_light)
	# The resin splashed about burning in clumps, each a fire's flame (Fire.make_flame): one where the pot broke, the
	# rest round it a golden angle apart and each further out -- spread, never in a row.
	var clumps: int = maxi(1, int(look.get("clumps", 6)))
	var out: float = radius() * float(look.get("ring", 0.7))
	for i in clumps:
		var flame: GPUParticles3D = Fire.make_flame(fire, float(look.get("flame_size", 1.0)))
		flame.name = "Flames%d" % i
		var at := Vector3.ZERO
		if i > 0:
			var reach: float = out * sqrt(float(i) / float(maxi(1, clumps - 1)))
			at = Vector3(cos(float(i) * 2.39996), 0.0, sin(float(i) * 2.39996)) * reach
		# Each tongue starts half its height up: started on the ground, the ground cut its lower half off, and
		# the patch was a field of white domes.
		var tongue := flame.draw_pass_1 as QuadMesh
		if tongue != null:
			at.y = tongue.size.y * 0.5
		flame.position = at
		add_child(flame)
		_flames.append(flame)

func _physics_process(delta: float) -> void:
	_left -= delta
	_age += delta
	if _left <= 0.0:
		queue_free()
		return
	# Dying down over its last seconds: the light and the flames go with it.
	var fade: float = _number("fade", 1.5)
	var strength: float = clampf(_left / maxf(0.01, fade), 0.0, 1.0)
	if _light != null:
		_light.light_energy = Fire.flicker_energy(_glow, _age) * strength
	if _left < fade:
		for flame in _flames:
			flame.emitting = false
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	for d in animals_in_it():
		d.take_damage(_number("dps", 1.0))

## What is on the ground in it: alive, and not up in the air.
func animals_in_it() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var here := Vector2(global_position.x, global_position.z)
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d):
			continue
		if d.has_method("is_flying") and d.is_flying():
			continue
		var at: Vector3 = (d as Node3D).global_position
		if here.distance_to(Vector2(at.x, at.z)) <= radius():
			out.append(d)
	return out
