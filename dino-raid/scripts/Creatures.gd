class_name Creatures
## Creatures on screen (GAME-DESIGN 23): ours as Nintendo-style dinosaurs (assets/models/toon, tools/toon_dinos.py) --
## each kind a species in its nest's colours, scaled to its size by its height, turned to look along +z as the blocks
## do, lit in soft steps with a bright rim (toon shading), an elite's edges glowing gold -- moving as it moves:
## standing, running, biting, struck, falling. Theirs are still blocks (Blocks.creature) until they have models of
## their own. Whatever builds or moves a creature asks here, so a block and a model are told apart in one place.

const DINOS := "res://assets/models/toon/"
## Each of our kinds: its species, and how tall it stands for each metre of its size.
const MODELS := {
	"red": ["velociraptor", 1.3], "blue": ["coelophysis", 1.35], "green": ["desmatosuchus", 1.0],
	"gold": ["allosaurus", 1.3], "white": ["psittacosaurus", 1.3], "scav": ["dilong", 1.3],
	"mutant": ["sinornithosaurus", 1.3], "falcon": ["pterosaur", 1.3], "thunder": ["stegosaurus", 1.1],
	"miasma": ["sinocalliopteryx", 1.3], "magma": ["ceratosaurus", 1.3], "titan": ["tyrannosaurus", 1.2],
}
## A picture's turn for a model: side on, its head to the right and a little toward the camera.
const PORTRAIT_TURN := 1.45
const LOOPS := ["idle", "run", "walk", "sleep", "graze"]
const ELITE_GLOW := Color(1.0, 0.8, 0.32)

## The gene stripes and the glows, laid over the skin: the nest's colour in bands across the back, a golden edge for an
## elite, a flash when struck.
const OVERLAY := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform vec4 mark_color : source_color = vec4(0.9, 0.25, 0.2, 1.0);
uniform float mark_amount = 0.6;
uniform float body_len = 2.0;
uniform float bands = 7.0;
uniform float elite = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
varying vec3 obj_pos;
varying vec3 obj_nrm;
void vertex() {
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}
void fragment() {
	float back = smoothstep(0.15, 0.7, normalize(obj_nrm).y);
	float t = obj_pos.z / max(body_len, 0.01) * bands + sin(obj_pos.x * 23.0) * 0.08;
	float f = fract(t);
	float band = smoothstep(0.45, 0.6, f) * (1.0 - smoothstep(0.8, 0.95, f));
	float mark = back * band * mark_amount;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * elite;
	vec3 col = mix(mark_color.rgb, vec3(1.0, 0.82, 0.38), clamp(rim * 1.5, 0.0, 1.0));
	col = mix(col, flash_color.rgb, clamp(flash, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.75;
	EMISSION = mark_color.rgb * mark * 0.2 + vec3(1.0, 0.72, 0.28) * rim * 0.8 + flash_color.rgb * flash * 0.8;
	ALPHA = clamp(mark + rim * 0.75 + flash, 0.0, 1.0);
}
"""

const TOON_TONE := 0.72            # a creature's colours, under the toon light

static var _scenes := {}           # species -> PackedScene
static var _shader: Shader


## A creature: one of ours as its dinosaur, anything else as a block (Blocks.creature). Its root stands at its feet and
## looks along +z; meta "edge" is its size. `boost` makes what its affixes grow bigger (a card's picture of one).
static func make(edge: float, color: Color, theirs: bool, affixes: Array, kind: String, elite := 0, boost := 1.0) -> Node3D:
	if theirs or not MODELS.has(kind):
		return Blocks.creature(edge, color, theirs, affixes, kind, elite)
	var root := Node3D.new()
	root.set_meta("edge", edge)
	root.set_meta("model", true)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var model := _scene(MODELS[kind][0]).instantiate() as Node3D
	body.add_child(model)
	var box := Geo.bounds(model)
	var s := edge * float(MODELS[kind][1]) / maxf(0.01, box.size.y)
	model.scale = Vector3.ONE * s
	model.rotation.y = PI
	model.position = Vector3(0, -box.position.y * s, (box.position.z + box.size.z * 0.5) * s)
	root.set_meta("height", box.size.y * s)
	var paint := ShaderMaterial.new()
	paint.shader = _overlay()
	paint.set_shader_parameter("mark_color", color)
	paint.set_shader_parameter("mark_amount", 0.0)
	paint.set_shader_parameter("body_len", box.size.z)
	paint.set_shader_parameter("elite", 1.0 if elite > 0 else 0.0)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = paint
	root.set_meta("paint", paint)
	_wear(model, affixes, boost)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		for clip in LOOPS:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		root.set_meta("player", player)
		play(root, "idle")
		if player.current_animation != "":
			player.seek(randf() * player.current_animation_length, true)
	return root


static func is_model(n: Node3D) -> bool:
	return n.has_meta("model")


## How tall a creature stands (a block: its edge).
static func height(n: Node3D) -> float:
	return float(n.get_meta("height", n.get_meta("edge", 1.0)))


## Plays a clip on a creature that has them (blending from what it was doing); `speed` scales it.
static func play(n: Node3D, clip: String, speed := 1.0, blend := 0.18) -> void:
	var player: AnimationPlayer = n.get_meta("player") if n.has_meta("player") else null
	if player == null or not player.has_animation(clip):
		return
	if player.current_animation == clip and player.is_playing():
		player.speed_scale = speed
		return
	player.play(clip, blend)
	player.speed_scale = speed


## The clip a creature is playing ("" for a block).
static func clip(n: Node3D) -> String:
	var player: AnimationPlayer = n.get_meta("player") if n.has_meta("player") else null
	return player.current_animation if player != null else ""


## How long a clip runs, in seconds (0 if the creature has none such).
static func length(n: Node3D, clip_name: String) -> float:
	var player: AnimationPlayer = n.get_meta("player") if n.has_meta("player") else null
	if player == null or not player.has_animation(clip_name):
		return 0.0
	return player.get_animation(clip_name).length


## A short glow of `c` over the whole creature.
static func flash(n: Node3D, c: Color, strength: float) -> void:
	var now := Time.get_ticks_msec()
	if now - int(n.get_meta("flashed", -1000)) < 500:
		return
	n.set_meta("flashed", now)
	if is_model(n):
		var paint: ShaderMaterial = n.get_meta("paint")
		paint.set_shader_parameter("flash_color", c)
		paint.set_shader_parameter("flash", clampf(strength * 0.7, 0.0, 0.85))
		var tw := n.create_tween()
		tw.tween_method(func(v: float) -> void: paint.set_shader_parameter("flash", v),
			clampf(strength * 0.7, 0.0, 0.85), 0.0, 0.18)
		return
	var m := Blocks.body_of(n).material_override as StandardMaterial3D
	m.emission = c
	m.emission_energy_multiplier = strength
	var tw := n.create_tween()
	tw.tween_property(m, "emission_energy_multiplier", 0.0, 0.12)


## A short-reach blow toward world direction `dir`: the body jumps at the foe and back (a model bites as it goes).
static func lunge(n: Node3D, dir: Vector3, speed := 1.0) -> void:
	var body := n.get_node("Body") as Node3D
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var local := n.transform.basis.inverse() * dir.normalized()
	var rest := Vector3.ZERO if is_model(n) else Vector3(0, float(n.get_meta("edge", 1.0)) * 0.5, 0)
	var tw := body.create_tween()
	tw.tween_property(body, "position", rest + local * (0.35 if is_model(n) else 0.5), 0.07 / speed).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "position", rest, 0.16 / speed)
	if is_model(n):
		busy(n, "attack", speed)


## A one-off clip (a bite, a flinch) that the walking and standing wait for.
static func busy(n: Node3D, clip_name: String, speed := 1.0) -> void:
	var l := length(n, clip_name)
	if l <= 0.0:
		return
	play(n, clip_name, speed, 0.08)
	n.set_meta("busy", Time.get_ticks_msec() + int(l / maxf(0.1, speed) * 1000.0))


## Whether a one-off clip is still playing.
static func is_busy(n: Node3D) -> bool:
	return Time.get_ticks_msec() < int(n.get_meta("busy", 0))


## Standing or running, as it moves (not while a one-off plays, nor once fallen).
static func pace(n: Node3D, moving: bool, speed := 1.0) -> void:
	if not is_model(n) or is_busy(n) or n.has_meta("fallen"):
		return
	play(n, "run" if moving else "idle", speed)


## Falls: a model plays its death and sinks away; a block tips over and shrinks.
static func fall(n: Node3D, speed := 1.0) -> void:
	n.set_meta("fallen", true)
	if is_model(n):
		var l := length(n, "death")
		play(n, "death", speed, 0.08)
		var tw := n.create_tween()
		tw.tween_interval(maxf(0.3, l / maxf(0.1, speed)) + 0.35)
		tw.tween_property(n, "position:y", n.position.y - height(n) * 0.9, 0.6).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.6, 0.6)
		tw.tween_callback(n.hide)
		return
	var m := Blocks.body_of(n).material_override as StandardMaterial3D
	var tw := n.create_tween()
	tw.tween_property(n, "rotation:x", -PI * 0.5, 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "albedo_color", m.albedo_color.darkened(0.5), 0.3)
	tw.tween_interval(0.25)
	tw.tween_property(n, "scale", Vector3.ONE * 0.02, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.hide)


## What its gene affixes grow on a dinosaur, each held by a bone so it moves with it: plates of shell along the back,
## blades on the forearms, a glowing acid sac at the throat, wings at the shoulders, a plasma orb over the back, a
## stinger at the tail's tip, a crest of flame along the neck, fins of speed at the thighs, bony scutes of thick hide,
## a horn on the snout. Sized by the skeleton's own length, nose to tail.
static func _wear(model: Node3D, affixes: Array, boost := 1.0) -> void:
	if affixes.is_empty():
		return
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	var skel := found[0] as Skeleton3D
	var head := skel.find_bone("Head")
	var hips := skel.find_bone("Hips")
	var tail := skel.find_bone("Tail_end")
	if head < 0 or hips < 0 or tail < 0:
		return
	var h := skel.get_bone_global_rest(head).origin
	var l := h.distance_to(skel.get_bone_global_rest(tail).origin) * boost
	var fwd := h - skel.get_bone_global_rest(hips).origin
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD
	var up := Vector3.UP
	var right := fwd.cross(up).normalized()
	for a in affixes:
		var c: Color = Content.AFFIXES[a].color
		match a:
			"shell":
				for bone in ["Spine1", "Spine2", "Spine3"]:
					_grow(skel, bone, up * 0.05 * l, Basis(right, up, fwd * 1.5), _ball(0.07 * l, 0.55), _mat(Color(0.3, 0.34, 0.4), 0.35, 0.45))
			"hide":
				for bone in ["Hips", "Spine1", "Spine2", "Spine3", "Tail1", "Tail2"]:
					_grow(skel, bone, up * 0.035 * l, Basis(), _ball(0.035 * l, 0.6), _mat(Color(0.46, 0.36, 0.25), 0.0, 0.85))
			"blade":
				for side in [-1.0, 1.0]:
					var bone := "Forearm.R" if side > 0.0 else "Forearm.L"
					_grow(skel, bone, right * side * 0.025 * l, _aim(fwd * 0.6 - up * 0.8).scaled(Vector3(1.0, 1.0, 0.35)),
						_cone(0.03 * l, 0.11 * l), _mat(Color(0.62, 0.64, 0.7), 0.9, 0.28))
			"acid":
				_grow(skel, "Neck1", -up * 0.045 * l, Basis(), _ball(0.05 * l, 1.0), _glow(c, 0.7))
			"wings":
				for side in [-1.0, 1.0]:
					var wing := _cone(0.13 * l, 0.42 * l)
					_grow(skel, "Spine3", right * side * 0.05 * l + up * 0.04 * l,
						_aim(right * side + up * 0.35 - fwd * 0.25).scaled(Vector3(1.0, 1.0, 0.08)), wing, _mat(c.darkened(0.15), 0.0, 0.7))
			"plasma":
				_grow(skel, "Spine2", up * 0.14 * l, Basis(), _ball(0.06 * l, 1.0), _glow(c, 0.6))
			"poison":
				_grow(skel, "Tail_end", Vector3.ZERO, _aim(-fwd * 0.7 + up * 0.7), _cone(0.025 * l, 0.12 * l), _glow(c, 1.4))
			"flame":
				for bone in ["Neck2", "Neck3", "Neck4", "Spine3"]:
					_grow(skel, bone, up * 0.03 * l, _aim(up - fwd * 0.2), _cone(0.02 * l, 0.08 * l), _glow(c, 2.2))
			"haste":
				for side in [-1.0, 1.0]:
					var bone := "Thigh.R" if side > 0.0 else "Thigh.L"
					_grow(skel, bone, right * side * 0.03 * l, _aim(-fwd + up * 0.5 + right * side * 0.3).scaled(Vector3(1.0, 1.0, 0.15)),
						_cone(0.04 * l, 0.14 * l), _glow(c, 1.3))
			"horn":
				_grow(skel, "Head", fwd * 0.03 * l + up * 0.02 * l, _aim(fwd * 0.8 + up * 0.6), _cone(0.022 * l, 0.1 * l), _mat(Color(0.94, 0.9, 0.78), 0.0, 0.5))


## A mesh held by `bone`, placed (in the skeleton's space, as the creature stands at rest) at the bone plus `offset`,
## turned by `turn`.
static func _grow(skel: Skeleton3D, bone: String, offset: Vector3, turn: Basis, mesh: Mesh, mat: Material) -> void:
	var i := skel.find_bone(bone)
	if i < 0:
		return
	var rest := skel.get_bone_global_rest(i)
	var hold := BoneAttachment3D.new()
	hold.bone_name = bone
	skel.add_child(hold)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = rest.affine_inverse() * Transform3D(turn, rest.origin + offset)
	hold.add_child(mi)


## A basis whose up points along `dir`.
static func _aim(dir: Vector3) -> Basis:
	return Basis(Quaternion(Vector3.UP, dir.normalized()))


static func _ball(radius: float, squash: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * squash
	m.radial_segments = 20
	m.rings = 10
	return m


## A cone, its point up.
static func _cone(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	return m


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


static func _glow(c: Color, strength: float) -> StandardMaterial3D:
	var m := _mat(c, 0.0, 0.4)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = strength
	return m


static func _scene(species: String) -> PackedScene:
	if not _scenes.has(species):
		var scene := load(DINOS + species + ".gltf") as PackedScene
		_toon(scene)
		_scenes[species] = scene
	return _scenes[species]


## A species' materials (shared by every one of it) lit as a cartoon is: light and shade in soft steps, a bright rim on
## the skin, a hard glint in the eyes. Its colours are the mesh's own (Godot leaves them unused on import).
static func _toon(scene: PackedScene) -> void:
	var probe := scene.instantiate()
	for mi in probe.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m == null:
				continue
			m.vertex_color_use_as_albedo = true
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_TOON
			if m.resource_name == "Eye":
				continue
			# Its sunny side whole and bright, so its colours a little under: as they are, the sun and the sky's light
			# together put a yellow past white.
			m.albedo_color = Color(TOON_TONE, TOON_TONE, TOON_TONE)
			m.roughness = 0.45
			m.metallic_specular = 0.3
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.5
	probe.free()


static func _overlay() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OVERLAY
	return _shader
