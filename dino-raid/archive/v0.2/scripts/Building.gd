class_name Building
extends Node3D
## A building in its plot (GAME-DESIGN 5.2), working on the eight plots round it (Garden.beside): the ferns a
## three-horn's eggs want, the carrion pit a tyrannosaur's, the compost heap whose warmth hatches any egg
## beside it sooner. Nothing comes for them in this build.

const FLORA := "res://common/assets/models/flora/%s.glb"
const PROPS := "res://common/assets/models/props/%s.glb"

var kind := ""
var plot := Vector2i.ZERO


func setup(battle: Node, p_kind: String, p_plot: Vector2i, at: Vector3) -> void:
	kind = p_kind
	plot = p_plot
	position = at
	add_child(look(kind, Callable(battle, "scene"), randi()))
	match kind:
		"carrion":
			add_child(_flies())
		"compost":
			add_child(_steam())


## What it is for, for the player who points at it.
func describe() -> String:
	var c: Dictionary = Cards.ALL[kind]
	return "%s\n%s" % [c.name, (c.text as String).replace("\n", "")]


## What it looks like -- the card's picture is taken of this too. `scene_of` loads a scene by its path.
static func look(p_kind: String, scene_of: Callable, seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	match p_kind:
		"ferns":
			# A tree fern over a bed of low ferns and horsetail: a patch of food for a young three-horn.
			_put(root, scene_of, FLORA % ["tree_fern_a", "tree_fern_b", "tree_fern_c"][rng.randi() % 3],
				Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)), 0.62, rng, true)
			for i in 8:
				var a := TAU * i / 8.0 + rng.randf_range(-0.3, 0.3)
				var r := rng.randf_range(1.0, 1.85)
				_put(root, scene_of, FLORA % ["ground_fern_a", "ground_fern_b", "ground_fern_c"][rng.randi() % 3],
					Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(1.3, 1.8), rng, true)
			for i in 3:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.8, 1.6)
				_put(root, scene_of, FLORA % ["horsetail_a", "horsetail_b"][rng.randi() % 2],
					Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(0.9, 1.2), rng, true)
		"carrion":
			# A pit with what is rotting in it: meat and bones, flies over it.
			_disc(root, 1.5, 0.06, Color(0.16, 0.11, 0.08))
			_rim(root, 1.5, Color(0.4, 0.31, 0.2))
			for i in 5:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.1, 1.0)
				_put(root, scene_of, PROPS % "drop_food_a", Vector3(cos(a) * r, 0.05, sin(a) * r), 2.4, rng, false)
			for i in 4:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.3, 1.3)
				_put(root, scene_of, PROPS % "drop_bone_a", Vector3(cos(a) * r, 0.05, sin(a) * r), 2.8, rng, false)
		"compost":
			# Cut fern and grass heaped up to rot: it warms whatever lies beside it.
			var heap := MeshInstance3D.new()
			var dome := SphereMesh.new()
			dome.radius = 1.6
			dome.height = 1.7
			heap.mesh = dome
			heap.scale = Vector3(1.0, 0.75, 1.0)
			heap.material_override = _matte(Color(0.33, 0.27, 0.15))
			root.add_child(heap)
			var top := MeshInstance3D.new()
			var cap := SphereMesh.new()
			cap.radius = 1.15
			cap.height = 1.1
			top.mesh = cap
			top.position.y = 0.35
			top.scale = Vector3(1.0, 0.8, 1.0)
			top.material_override = _matte(Color(0.42, 0.38, 0.18))
			root.add_child(top)
			var dead_fern := _matte(Color(0.4, 0.29, 0.12))
			dead_fern.cull_mode = BaseMaterial3D.CULL_DISABLED
			for i in 6:
				var a := TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
				var frond := _put(root, scene_of, FLORA % ["ground_fern_a", "ground_fern_b"][rng.randi() % 2],
					Vector3(cos(a) * 0.9, 0.55, sin(a) * 0.9), 1.1, rng, false)
				for mi in frond.find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_override = dead_fern
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


## Flies over the pit.
func _flies() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.2
	mat.emission_shape_scale = Vector3(1.0, 0.4, 1.0)
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.12
	mat.scale_max = 0.18
	mat.color_ramp = Fx.ramp(Color(0.04, 0.04, 0.03), 1.0)
	var p := Fx.particles(mat, 40, 1.4)
	p.position.y = 0.9
	return p


## The warmth of the heap, rising off it.
func _steam() -> GPUParticles3D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.0
	mat.emission_shape_scale = Vector3(1.0, 0.2, 1.0)
	mat.direction = Vector3.UP
	mat.spread = 15.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3(0.05, 0.12, 0.0)
	mat.scale_min = 0.8
	mat.scale_max = 1.6
	mat.color_ramp = Fx.ramp(Color(0.92, 0.92, 0.9), 0.24)
	var p := Fx.particles(mat, 24, 3.0)
	p.position.y = 1.0
	return p
