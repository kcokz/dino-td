class_name Building
extends Node3D
## A building in its tile (GAME-DESIGN 9): ferns a three-horn's eggs want beside them, the carrion pit that
## feeds a tyrannosaur, the compost heap whose warmth hatches the eggs beside it sooner.

const FLORA := "res://common/assets/models/flora/%s.glb"
const PROPS := "res://common/assets/models/props/%s.glb"

var id := 0
var kind := ""
var tile := Vector2i.ZERO


func setup(scene_of: Callable, b: Dictionary) -> void:
	id = b.id
	kind = b.kind
	tile = b.pos
	position = Board.world(tile)
	add_child(look(kind, scene_of, randi()))
	match kind:
		"carrion":
			add_child(_flies())
		"compost":
			add_child(_steam())


func lost() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 0.5)
	tw.tween_callback(queue_free)


## What it looks like -- the card's picture is taken of this too. `scene_of` loads a scene by its path.
static func look(p_kind: String, scene_of: Callable, seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	match p_kind:
		"ferns":
			_put(root, scene_of, FLORA % ["tree_fern_a", "tree_fern_b", "tree_fern_c"][rng.randi() % 3],
				Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), 0.7, rng, true)
			for i in 9:
				var a := TAU * i / 9.0 + rng.randf_range(-0.3, 0.3)
				var r := rng.randf_range(1.2, 2.3)
				_put(root, scene_of, FLORA % ["ground_fern_a", "ground_fern_b", "ground_fern_c"][rng.randi() % 3],
					Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(1.5, 2.1), rng, true)
			for i in 4:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.9, 2.0)
				_put(root, scene_of, FLORA % ["horsetail_a", "horsetail_b"][rng.randi() % 2],
					Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(1.0, 1.4), rng, true)
		"carrion":
			_disc(root, 2.0, 0.06, Color(0.15, 0.1, 0.07))
			_rim(root, 2.0, Color(0.42, 0.32, 0.2))
			for i in 6:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.1, 1.3)
				_put(root, scene_of, PROPS % "drop_food_a", Vector3(cos(a) * r, 0.05, sin(a) * r), 3.0, rng, false)
			for i in 5:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.3, 1.7)
				_put(root, scene_of, PROPS % "drop_bone_a", Vector3(cos(a) * r, 0.05, sin(a) * r), 3.4, rng, false)
		"compost":
			var heap := MeshInstance3D.new()
			var dome := SphereMesh.new()
			dome.radius = 2.0
			dome.height = 2.0
			heap.mesh = dome
			heap.scale = Vector3(1.0, 0.72, 1.0)
			heap.material_override = _matte(Color(0.33, 0.27, 0.15))
			root.add_child(heap)
			var top := MeshInstance3D.new()
			var cap := SphereMesh.new()
			cap.radius = 1.45
			cap.height = 1.3
			top.mesh = cap
			top.position.y = 0.42
			top.scale = Vector3(1.0, 0.8, 1.0)
			top.material_override = _matte(Color(0.43, 0.39, 0.19))
			root.add_child(top)
			var dead := _matte(Color(0.42, 0.3, 0.12))
			dead.cull_mode = BaseMaterial3D.CULL_DISABLED
			for i in 7:
				var a := TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
				var frond := _put(root, scene_of, FLORA % ["ground_fern_a", "ground_fern_b"][rng.randi() % 2],
					Vector3(cos(a) * 1.1, 0.7, sin(a) * 1.1), 1.3, rng, false)
				for mi in frond.find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_override = dead
	return root


static func _put(root: Node3D, scene_of: Callable, path: String, at: Vector3, size: float,
		rng: RandomNumberGenerator, plant: bool) -> Node3D:
	var art := (scene_of.call(path) as PackedScene).instantiate() as Node3D
	art.position = at
	art.rotation.y = rng.randf() * TAU
	art.scale = Vector3.ONE * size
	if plant:
		ArtDress.flora(art)
	else:
		ArtDress.prop(art)
	root.add_child(art)
	return art


static func _disc(root: Node3D, r: float, h: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r * 1.05
	cyl.height = h
	mi.mesh = cyl
	mi.position.y = h * 0.5
	mi.material_override = _matte(c)
	root.add_child(mi)


static func _rim(root: Node3D, r: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.92
	ring.outer_radius = r * 1.25
	mi.mesh = ring
	mi.scale = Vector3(1.0, 0.45, 1.0)
	mi.position.y = 0.05
	mi.material_override = _matte(c)
	root.add_child(mi)


static func _matte(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _flies() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.5
	mat.emission_shape_scale = Vector3(1.0, 0.4, 1.0)
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.12
	mat.scale_max = 0.18
	mat.color_ramp = Fx.ramp(Color(0.04, 0.04, 0.03), 1.0)
	var p := Fx.particles(mat, 50, 1.4)
	p.position.y = 1.0
	return p


func _steam() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.2
	mat.emission_shape_scale = Vector3(1.0, 0.2, 1.0)
	mat.direction = Vector3.UP
	mat.spread = 15.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0.05, 0.12, 0.0)
	mat.scale_min = 0.9
	mat.scale_max = 1.8
	mat.color_ramp = Fx.ramp(Color(0.92, 0.92, 0.9), 0.24)
	var p := Fx.particles(mat, 26, 3.0)
	p.position.y = 1.3
	return p
