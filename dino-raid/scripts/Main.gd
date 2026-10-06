extends Node3D
## A first look: the shared cast from res://common/ stood nose to tail beside the hero, so we can see
## the copy of common/ works before any game is built on it.

const GAP := 1.5
const CAST := [
	# [model, height in metres; 0 keeps the model's own size -- the dinos are built life-size]
	["res://common/assets/models/hero.glb", 1.2],
	["res://common/assets/models/dinos/velociraptor.gltf", 0.0],
	["res://common/assets/models/dinos/triceratops.gltf", 0.0],
	["res://common/assets/models/dinos/stegosaurus.gltf", 0.0],
	["res://common/assets/models/dinos/tyrannosaurus.gltf", 0.0],
]


func _ready() -> void:
	_stage()
	var x := -17.0
	for entry in CAST:
		var scene := load(entry[0]) as PackedScene
		if scene == null:
			push_error("missing %s -- run: python common/sync.py dino-raid" % entry[0])
			continue
		var model := scene.instantiate() as Node3D
		add_child(model)
		var box := _fit(model, entry[1])
		# Turned side-on, its length runs along x: stand it just past the last one.
		model.rotation.y = PI * 0.5
		model.position.x = x + box.end.z * model.scale.z
		x += box.size.z * model.scale.z + GAP
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.get_animation_list().size() > 0:
			var list := anim.get_animation_list()
			var pick := list[0]
			for a in list:
				if "idle" in a.to_lower():
					pick = a
			anim.play(pick)


## Scales the model to the given height (0: as built), stands its feet on the ground, returns its
## unscaled bounds.
func _fit(model: Node3D, height: float) -> AABB:
	var box := _bounds(model, Transform3D.IDENTITY)
	if height > 0.0 and box.size.y > 0.0:
		model.scale = Vector3.ONE * (height / box.size.y)
	model.position.y = -box.position.y * model.scale.y
	return box


func _bounds(node: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is VisualInstance3D:
		box = xf * (node as VisualInstance3D).get_aabb()
		first = false
	for child in node.get_children():
		var b := _bounds(child, xf)
		if b.size == Vector3.ZERO:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


func _stage() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.36, 0.26)
	ground.material_override = mat
	add_child(ground)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	add_child(env)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 24)
	cam.rotation_degrees = Vector3(-15, 0, 0)
	add_child(cam)
