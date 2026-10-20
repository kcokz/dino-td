class_name Ash
extends Node3D
## Volcanic ash let loose on the field (火山灰, GAME-DESIGN 5.2): a grey cloud hanging low for a while. A
## robot in it, or shooting into it, can hardly see: most of its shots go wide (Robot._shoot).

const LIFE := 15.0
const RADIUS := 10.0
const MISS := 0.7

var battle: Node
var _born := 0.0
var _cloud: GPUParticles3D
var _gone := false


func setup(p_battle: Node, at: Vector3) -> void:
	battle = p_battle
	position = at
	_born = battle.clock
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = RADIUS * 0.85
	mat.emission_shape_scale = Vector3(1.0, 0.25, 1.0)
	mat.direction = Vector3.UP
	mat.spread = 60.0
	mat.initial_velocity_min = 0.1
	mat.initial_velocity_max = 0.4
	mat.gravity = Vector3(0.2, -0.05, 0.0)
	mat.scale_min = 4.5
	mat.scale_max = 8.0
	mat.color_ramp = Fx.ramp(Color(0.34, 0.33, 0.31), 0.5)
	_cloud = Fx.particles(mat, 140, 4.0)
	_cloud.position.y = 1.8
	add_child(_cloud)


func _physics_process(_delta: float) -> void:
	if not _gone and battle.clock - _born > LIFE:
		_gone = true
		battle.clouds.erase(self)
		_cloud.emitting = false
		var tw := create_tween()
		tw.tween_interval(4.0)
		tw.tween_callback(queue_free)
