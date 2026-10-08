class_name Scent
extends Node3D
## The smell of meat the player scatters: a lump of meat on the ground and a reddish haze drifting off it,
## spreading for a few seconds and gone after LIFE. The hunters that smell it come (Dino._think_hunter).

const LIFE := 12.0
const START := 3.0
const FULL := 12.0

var battle: Node
## How far round the meat the smell lies thick -- where a hunter that came noses about.
var radius := START

var _born := 0.0
var _haze: GPUParticles3D
var _mat: ParticleProcessMaterial
var _gone := false


func setup(p_battle: Node, at: Vector3, meat: PackedScene) -> void:
	battle = p_battle
	position = at
	_born = battle.clock
	if meat:
		var lump := meat.instantiate() as Node3D
		lump.scale = Vector3.ONE * 1.6
		ArtDress.prop(lump)
		add_child(lump)
	_mat = ParticleProcessMaterial.new()
	_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_mat.emission_sphere_radius = START
	_mat.emission_shape_scale = Vector3(1.0, 0.08, 1.0)
	_mat.direction = Vector3.UP
	_mat.spread = 40.0
	_mat.initial_velocity_min = 0.15
	_mat.initial_velocity_max = 0.5
	_mat.gravity = Vector3(0.35, 0.04, 0.1)
	_mat.scale_min = 1.6
	_mat.scale_max = 3.2
	_mat.color_ramp = Fx.ramp(Color(0.55, 0.16, 0.1), 0.28)
	_haze = Fx.particles(_mat, 90, 3.5)
	_haze.position.y = 0.4
	add_child(_haze)


func _physics_process(_delta: float) -> void:
	var age: float = battle.clock - _born
	radius = lerpf(START, FULL, clampf(age / 3.0, 0.0, 1.0))
	_mat.emission_sphere_radius = radius * 0.7
	if age > LIFE and not _gone:
		_gone = true
		battle.scents.erase(self)
		_haze.emitting = false
		var tw := create_tween()
		tw.tween_interval(3.5)
		tw.tween_callback(queue_free)