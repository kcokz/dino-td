class_name Lure
extends Node3D
## What a help card leaves on the board until it is spent: the smell of meat (a lump and a red haze), volcanic
## ash (a grey cloud over 3x3 tiles), a noise or a mating call waiting for the end of the turn (dust thrown up,
## again and again). Shown from the state; it does nothing itself.

var kind := ""
var tile := Vector2i.ZERO
var _p: GPUParticles3D
var _pulse := 0.0


func setup(scene_of: Callable, p_kind: String, p: Vector2i) -> void:
	kind = p_kind
	tile = p
	position = Board.world(p)
	var mat := ParticleProcessMaterial.new()
	match kind:
		"scent":
			var lump := (scene_of.call("res://common/assets/models/props/drop_food_a.glb") as PackedScene).instantiate() as Node3D
			lump.scale = Vector3.ONE * 3.2
			ArtDress.prop(lump)
			add_child(lump)
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 2.4
			mat.emission_shape_scale = Vector3(1.0, 0.1, 1.0)
			mat.direction = Vector3.UP
			mat.spread = 40.0
			mat.initial_velocity_min = 0.2
			mat.initial_velocity_max = 0.6
			mat.gravity = Vector3(0.3, 0.05, 0.1)
			mat.scale_min = 1.8
			mat.scale_max = 3.4
			mat.color_ramp = Fx.ramp(Color(0.6, 0.17, 0.1), 0.3)
			_p = Fx.particles(mat, 70, 3.5)
			_p.position.y = 0.4
		"ash":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(Board.TILE * 1.4, 1.0, Board.TILE * 1.4)
			mat.direction = Vector3.UP
			mat.spread = 60.0
			mat.initial_velocity_min = 0.1
			mat.initial_velocity_max = 0.4
			mat.gravity = Vector3(0.2, -0.05, 0.0)
			mat.scale_min = 5.0
			mat.scale_max = 9.0
			mat.color_ramp = Fx.ramp(Color(0.34, 0.33, 0.31), 0.55)
			_p = Fx.particles(mat, 150, 4.0)
			_p.position.y = 2.2
		_:
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_axis = Vector3.UP
			mat.emission_ring_radius = 1.0
			mat.emission_ring_inner_radius = 0.6
			mat.emission_ring_height = 0.1
			mat.direction = Vector3(1, 0, 0)
			mat.spread = 180.0
			mat.flatness = 1.0
			mat.initial_velocity_min = 4.0
			mat.initial_velocity_max = 6.0
			mat.damping_min = 3.0
			mat.damping_max = 4.0
			mat.scale_min = 1.0
			mat.scale_max = 2.0
			mat.color_ramp = Fx.ramp(Color(0.66, 0.58, 0.44) if kind == "noise" else Color(0.85, 0.8, 0.62), 0.5)
			_p = Fx.particles(mat, 40, 1.2)
			_p.position.y = 0.4
	add_child(_p)
	_p.emitting = true


## A noise, as it goes off: a ring of dust thrown far out.
static func bang(parent: Node, at: Vector3, reach: float) -> void:
	var dust := Fx.dust_ring(at, reach)
	parent.add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


func spend() -> void:
	_p.emitting = false
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(queue_free)
