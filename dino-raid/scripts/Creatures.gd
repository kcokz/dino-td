class_name Creatures
## Creatures on screen (GAME-DESIGN 23): ours as Nintendo-style dinosaurs (assets/models/toon, tools/toon_dinos.py) --
## each kind a species in its nest's colours, scaled to its size by its height, turned to look along +z as the blocks
## do, lit in soft steps with a bright rim (toon shading), an elite's edges glowing gold -- moving as it moves:
## standing, running, biting, struck, falling. An elite is its species evolved (<species>_e1, _e2): spines down its
## back, horns behind its eyes, a deeper back, a heavier build, gold the second time -- on the same skeleton, moving
## with the plain one's clips. Theirs are cartoon aliens (Aliens), moved the same way; anything else is a block
## (Blocks.creature). Whatever builds or moves a creature asks here, so a block and a model are told apart in one place.

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
## The star dinosaurs that wear something their portraits show (_dress_star).
const WORN := ["queen", "doctor", "scar", "fisher", "horn", "spitter", "sickle", "shield", "firstbird"]

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

const TOON_TONE := 0.86            # a creature's colours, under the soft light

static var _scenes := {}           # file (species, or species_e1 / _e2) -> PackedScene
static var _boxes := {}            # species -> its plain one's bounds, as it stands at rest
static var _clips := {}            # species -> its plain one's clips (AnimationLibrary)
static var _heads := {}            # star -> its head's shape, to fit what it wears to (_head)
static var _shader: Shader


## A creature: one of ours as its dinosaur, anything else as a block (Blocks.creature). Its root stands at its feet and
## looks along +z; meta "edge" is its size. `boost` makes what its affixes grow bigger (a card's picture of one).
static func make(edge: float, color: Color, theirs: bool, affixes: Array, kind: String, elite := 0, boost := 1.0) -> Node3D:
	if theirs and Aliens.has(kind):
		return Aliens.make(edge, kind)
	if theirs or not MODELS.has(kind):
		return Blocks.creature(edge, color, theirs, affixes, kind, elite)
	var root := Node3D.new()
	root.set_meta("edge", edge)
	root.set_meta("model", true)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var species: String = MODELS[kind][0]
	var level := clampi(elite, 0, 2)
	var model := _scene(species + ("_e%d" % level if level > 0 else "")).instantiate() as Node3D
	body.add_child(model)
	# Sized by the plain one, so an elite's body is as big as its size says and its spines and horns stand above it.
	var box := _plain_box(species)
	var s := edge * float(MODELS[kind][1]) / maxf(0.01, box.size.y)
	model.scale = Vector3.ONE * s
	model.rotation.y = PI
	model.position = Vector3(0, -box.position.y * s, (box.position.z + box.size.z * 0.5) * s)
	var own := Geo.bounds(model) if level > 0 else box
	root.set_meta("height", (own.end.y - box.position.y) * s)
	if level > 0:
		_lend_clips(model, species)
	var paint := ShaderMaterial.new()
	paint.shader = _overlay()
	paint.set_shader_parameter("mark_color", color)
	paint.set_shader_parameter("mark_amount", 0.0)
	paint.set_shader_parameter("body_len", box.size.z)
	paint.set_shader_parameter("elite", [0.0, 0.6, 0.9][level])
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


## A star dinosaur (Content.STARS) as its own model (toon/star_<id>.gltf, tools/toon_dinos.py), `length` from its nose
## to its tail's tip (or its width, if more): its root at its feet, looking along +z, standing idle. null while it has
## no model of its own.
static func star(id: String, length: float) -> Node3D:
	var file := "star_" + id
	if not ResourceLoader.exists(DINOS + file + ".gltf"):
		return null
	var root := Node3D.new()
	root.set_meta("model", true)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var model := _scene(file).instantiate() as Node3D
	body.add_child(model)
	var box := _plain_box(file)
	var s := length / maxf(0.01, maxf(box.size.z, box.size.x))
	model.scale = Vector3.ONE * s
	model.rotation.y = PI
	model.position = Vector3(0, -box.position.y * s, (box.position.z + box.size.z * 0.5) * s)
	root.set_meta("edge", box.size.y * s)
	root.set_meta("height", box.size.y * s)
	_dress_star(model, id)
	_lay_by_star(body, id, length)
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


## What a star wears, as its portrait shows it (assets/art/s_<id>.jpg): the queen's gold crown; the doctor's hat, bow
## tie and flask; a scar over the scarface's eye; the horn's fan of a crest and the spitter's two spiky ones; a fish
## across the fisher's jaws; the sickle's long claws; the shield's spiked back and club tail; the first bird's rainbow
## crest and tail. Each held by its bone, so it moves with it, and fitted to its skin as it stands at rest (_head).
static func _dress_star(model: Node3D, id: String) -> void:
	if not WORN.has(id):
		return
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty() or (found[0] as Skeleton3D).find_bone("Head_end") < 0:
		return
	var skel := found[0] as Skeleton3D
	var head := _head(model, skel, id)
	var at: Vector3 = head.at
	var ax: Vector3 = head.ax
	var sup: Vector3 = head.sup
	var side: Vector3 = head.side
	var fwd: Vector3 = head.fwd
	var right := fwd.cross(Vector3.UP).normalized()
	var w: float = head.wide
	var brow: float = head.brow
	var hl: float = head.bone * 2.4
	var gold := _mat(Color(1.0, 0.78, 0.26), 0.8, 0.3)
	match id:
		"queen":
			# A gold crown set with red stones: its band flaring, five points each with a ball on it.
			var r := w * 0.62
			var foot := _top_at(head, brow - head.len * 0.08) - sup * r * 0.12
			var band := _mat(Color(1.0, 0.78, 0.26), 0.8, 0.3)
			band.cull_mode = BaseMaterial3D.CULL_DISABLED
			_put(skel, "Head", foot + sup * r * 0.2, _aim(sup), _band(r, r * 0.42), band)
			for k in 5:
				var out := ax * cos(TAU * k / 5.0) + side * sin(TAU * k / 5.0)
				_put(skel, "Head", foot + out * r * 0.97 + sup * r * 0.62, _aim(sup + out * 0.15), _cone(r * 0.2, r * 0.45), gold)
				_put(skel, "Head", foot + out * r * 1.0 + sup * r * 0.88, Basis(), _ball(r * 0.08, 1.0), gold)
			var ruby := _glow(Color(0.9, 0.1, 0.16), 0.5)
			for k in 3:
				var out := ax * cos(k - 1.0) + side * sin(k - 1.0)
				_put(skel, "Head", foot + out * r * 1.02 + sup * r * 0.2, Basis(), _ball(r * 0.11, 1.0), ruby)
		"doctor":
			# A grey hat with a dark band; an orange bow tie at its throat; a green flask in the hand it shows.
			var r := w * 0.7
			var foot := _top_at(head, brow - head.len * 0.12) - sup * r * 0.1
			var felt := _mat(Color(0.52, 0.53, 0.56), 0.0, 0.85)
			_put(skel, "Head", foot, _aim(sup), _cylinder(r * 1.35, r * 0.07), felt)
			_put(skel, "Head", foot + sup * r * 0.4, _aim(sup), _cylinder(r * 0.82, r * 0.8), felt)
			_put(skel, "Head", foot + sup * r * 0.14, _aim(sup), _cylinder(r * 0.86, r * 0.24), _mat(Color(0.16, 0.13, 0.12), 0.0, 0.7))
			var out := (fwd - Vector3.UP * 0.8).normalized()
			var knot := _furthest(model, skel, ["Neck1", "Neck2"], out)
			var tie := _mat(Color(0.98, 0.5, 0.1), 0.0, 0.6)
			for s in [-1.0, 1.0]:
				_put(skel, "Neck1", knot + side * s * w * 0.46 + out * w * 0.1, _blade(-side * s, out, 0.4), _cone(w * 0.4, w * 0.9), tie)
			_put(skel, "Neck1", knot + out * w * 0.14, Basis(), _ball(w * 0.2, 1.0), tie)
			var hand := _shown_hand(skel, side, at)
			if hand != "":
				var p := skel.get_bone_global_rest(skel.find_bone(hand)).origin + fwd * w * 0.3
				var glass := _glow(Color(0.35, 0.95, 0.45), 0.6)
				_put(skel, hand, p, Basis(), _ball(w * 0.55, 1.0), glass)
				_put(skel, hand, p + Vector3.UP * w * 0.62, Basis(), _cylinder(w * 0.18, w * 0.4), glass)
				_put(skel, hand, p + Vector3.UP * w * 0.88, Basis(), _cylinder(w * 0.21, w * 0.18), _mat(Color(0.6, 0.42, 0.25), 0.0, 0.9))
		"scar":
			# A pale scar down over the eye it shows.
			var eye: Vector3 = head.eyes[1]
			var r: float = head.eye
			_put(skel, "Head", eye + side * r * 1.15, _blade(sup + ax * 0.35, side, 0.3), _cylinder(r * 0.2, r * 3.4),
				_mat(Color(0.96, 0.76, 0.76), 0.0, 0.6))
		"fisher":
			# An orange fish held across its jaws: its forked tail out on the side it shows, its head out the other.
			var along: float = head.tip - head.len * 0.3
			var cut := _section(head, along)
			var mouth: Vector3 = at + ax * along + sup * (cut.x + cut.y) * 0.5
			var long := w * 2.4
			var dir := (side * 0.8 - ax * 0.6).normalized()
			var flank := dir.cross(sup)
			if flank.dot(side + ax) < 0.0:
				flank = -flank
			_put(skel, "Head", mouth, _blade(dir, flank, 0.18, 0.34), _ball(long * 0.5, 1.0), _mat(Color(1.0, 0.52, 0.12), 0.1, 0.45))
			var fin := _mat(Color(1.0, 0.74, 0.32), 0.0, 0.5)
			for s in [-1.0, 1.0]:
				var spread: Vector3 = (dir * 0.8 + sup * s * 0.6).normalized()
				_put(skel, "Head", mouth + dir * long * 0.46 + spread * long * 0.13, _blade(-spread, flank, 0.2), _cone(long * 0.09, long * 0.28), fin)
			_put(skel, "Head", mouth - dir * long * 0.36 + flank * long * 0.05 + sup * long * 0.03, Basis(), _ball(long * 0.04, 1.0),
				_mat(Color(0.08, 0.06, 0.06), 0.0, 0.3))
		"horn":
			# A pink fan of a crest on the top of its head: spines with a skin between.
			var foot := _top_at(head, brow - head.len * 0.15) - sup * w * 0.12
			_put(skel, "Head", foot + sup * w * 0.2 - ax * w * 0.25, _blade(sup, side, 0.12), _ball(w * 0.62, 1.0), _mat(Color(0.98, 0.58, 0.74), 0.0, 0.6))
			for k in 5:
				var t := -0.2 + k * 0.3
				var dir := sup * cos(t) - ax * sin(t)
				var long := w * (1.3 + 0.35 * sin(PI * k / 4.0))
				_put(skel, "Head", foot + dir * long * 0.5, _blade(dir, side, 0.35), _cone(w * 0.2, long), _mat(Color(0.8, 0.2, 0.45), 0.0, 0.55))
		"spitter":
			# Its two crests: red spikes in two rows along the top of its head, a little apart.
			var red := _mat(Color(0.92, 0.26, 0.14), 0.0, 0.55)
			for s in [-1.0, 1.0]:
				var dir: Vector3 = (sup - ax * 0.35 + side * s * 0.2).normalized()
				for k in 4:
					var long := w * (0.75 + 0.2 * sin(PI * (k + 0.5) / 4.0))
					var foot: Vector3 = _top_at(head, brow + head.len * (0.12 - k * 0.14)) - sup * w * 0.12 + side * s * w * 0.2
					_put(skel, "Head", foot + dir * long * 0.5, _blade(dir, side, 0.3), _cone(w * 0.22, long), red)
		"sickle":
			# Long claws on its hands.
			var ivory := _mat(Color(0.96, 0.92, 0.8), 0.0, 0.5)
			for hand in ["Hand.L", "Hand.R"]:
				for k in 3:
					_grow(skel, hand, fwd * 0.1 * hl + right * (k - 1) * 0.05 * hl, _aim(fwd - Vector3.UP * 0.6), _cone(0.035 * hl, 0.5 * hl), ivory)
		"shield":
			# Spikes along its back; a club at its tail's end.
			if skel.find_bone("Tail_end") >= 0:
				_grow(skel, "Tail_end", Vector3.ZERO, Basis(), _ball(0.3 * hl, 0.75), _mat(Color(0.42, 0.42, 0.45), 0.0, 0.7))
			var spike := _mat(Color(0.95, 0.86, 0.55), 0.0, 0.5)
			for bone in ["Spine1", "Spine2", "Spine3", "Spine4", "Hips"]:
				for s in [-1.0, 1.0]:
					_grow(skel, bone, Vector3.UP * 0.35 * hl + right * s * 0.25 * hl, _aim(Vector3.UP + right * s * 0.6), _cone(0.07 * hl, 0.16 * hl), spike)
		"firstbird":
			# Rainbow feathers: a crest swept back from its head, a fan spread at its tail's end.
			var rainbow := [Color(1.0, 0.3, 0.3), Color(1.0, 0.62, 0.2), Color(1.0, 0.9, 0.3), Color(0.35, 0.9, 0.4),
				Color(0.3, 0.6, 1.0), Color(0.7, 0.35, 1.0)]
			var foot := _top_at(head, brow - head.len * 0.2) - sup * w * 0.25
			for k in 4:
				var dir := (sup * (0.9 - k * 0.15) - ax * (0.5 + k * 0.25)).normalized()
				var long := w * (1.0 + k * 0.15)
				_put(skel, "Head", foot + dir * long * 0.42, _blade(dir, side, 0.25, 0.35), _ball(long * 0.5, 1.0), _glow(rainbow[k], 0.4))
			var tail := skel.find_bone("Tail_end")
			if tail >= 0:
				var end := skel.get_bone_global_rest(tail).origin
				var back := (end - skel.get_bone_global_rest(skel.get_bone_parent(tail)).origin).normalized()
				var long := hl * 1.2
				for k in 6:
					var t := (k - 2.5) * 0.22
					var dir := back * cos(t) + side * sin(t)
					_put(skel, "Tail_end", end + dir * long * 0.45, _blade(dir, Vector3.UP, 0.15, 0.3), _ball(long * 0.5, 1.0), _glow(rainbow[k], 0.5))


## What a star has by it, as its portrait shows it, laid on the ground (`ground`: its body, `length` how long it
## stands) on the side it shows in its pen (its left, HomeView.YARD_TURN), by its head: the mother's nest of eggs, the
## hoarder's eggs, the trader's satchel, the saver's coins heaped on a stump.
static func _lay_by_star(ground: Node3D, id: String, length: float) -> void:
	var gold := _mat(Color(1.0, 0.78, 0.26), 0.8, 0.3)
	var spot := Vector3(-0.4, 0.0, 0.22) * length
	match id:
		"mother":
			# Her nest of eggs.
			var twigs := _mat(Color(0.62, 0.46, 0.28), 0.0, 0.95)
			_lay(ground, spot + Vector3(0.0, 0.03, 0.0) * length, Basis(), _ball(0.15 * length, 0.25), twigs)
			_lay(ground, spot + Vector3(0.0, 0.045, 0.0) * length, Basis(), _torus(0.15 * length, 0.07 * length), twigs)
			var shells := [Color(0.62, 0.86, 0.92), Color(0.98, 0.66, 0.32), Color(0.96, 0.95, 0.88)]
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				_lay(ground, spot + Vector3(cos(a) * 0.055, 0.085, sin(a) * 0.055) * length, Basis(), _ball(0.045 * length, 1.3), _mat(shells[k], 0.0, 0.45))
		"hoarder":
			# Two eggs it keeps.
			_lay(ground, spot + Vector3(0.0, 0.075, 0.0) * length, Basis(), _ball(0.06 * length, 1.3), _mat(Color(0.98, 0.55, 0.15), 0.0, 0.45))
			_lay(ground, spot + Vector3(0.1, 0.06, 0.13) * length, Basis(), _ball(0.048 * length, 1.3), _mat(Color(0.3, 0.75, 0.78), 0.0, 0.45))
		"trader":
			# Its leather satchel, the flap buckled, a handle on top.
			var u := length * 0.75
			var leather := _mat(Color(0.5, 0.31, 0.17), 0.0, 0.8)
			var bag := Vector3(0.09, 0.13, 0.14) * u
			_lay(ground, spot + Vector3(0.0, bag.y * 0.5, 0.0), Basis(), _box(bag), leather)
			var flap := _mat(Color(0.42, 0.25, 0.13), 0.0, 0.8)
			_lay(ground, spot + Vector3(-bag.x * 0.5 - 0.005 * u, bag.y * 0.72, 0.0), Basis(), _box(Vector3(0.01, 0.075, 0.145) * u), flap)
			_lay(ground, spot + Vector3(0.0, bag.y + 0.005 * u, 0.0), Basis(), _box(Vector3(0.095, 0.01, 0.145) * u), flap)
			_lay(ground, spot + Vector3(-bag.x * 0.5 - 0.012 * u, bag.y * 0.62, 0.0), Basis(), _box(Vector3(0.008, 0.025, 0.03) * u), gold)
			_lay(ground, spot + Vector3(0.0, bag.y, 0.0), _aim(Vector3.RIGHT), _torus(0.05 * u, 0.012 * u), leather)
		"saver":
			# Its coins heaped on a stump, and a few dropped by it.
			var stump := 0.08 * length
			_lay(ground, spot + Vector3(0.0, stump * 0.5, 0.0), Basis(), _cylinder(0.1 * length, stump), _mat(Color(0.45, 0.3, 0.18), 0.0, 0.95))
			_lay(ground, spot + Vector3(0.0, stump + 0.002 * length, 0.0), Basis(), _cylinder(0.095 * length, 0.004 * length), _mat(Color(0.82, 0.66, 0.45), 0.0, 0.9))
			var coin := _cylinder(0.026 * length, 0.007 * length)
			for layer in [[8, 0.055, 0.0], [5, 0.03, 0.012], [2, 0.01, 0.024]]:
				for k in layer[0]:
					var a: float = TAU * k / layer[0] + layer[1] * 20.0
					var p := Vector3(cos(a) * layer[1], 0.0, sin(a) * layer[1]) * length + Vector3(0.0, stump + (0.008 + layer[2]) * length, 0.0)
					_lay(ground, spot + p, Basis(Vector3(-sin(a), 0.0, cos(a)), 0.35 if layer[1] > 0.02 else 0.1), coin, gold)
			for k in 3:
				_lay(ground, spot + Vector3(-0.06 + k * 0.05, 0.004, 0.13 + k * 0.02) * length, Basis(), coin, gold)


## A star's head as its skin has it at rest, in its skeleton's space, to fit what it wears to (_dress_star): its Head
## bone's place (at) and the skull's own frame (ax along it to the snout, sup its top, side the side it shows in its
## pen, fwd ax made level); its skin's points round it (pts: how far along ax, up sup and out side from `at`); its
## eyes' middles (eyes: the one away from side, then the one toward it), their size (eye) and how far along the skull
## they are (brow); its half-width (wide), its length (len) and where its snout ends (tip, along ax); its bone's length
## (bone). Measured once for each star.
static func _head(model: Node3D, skel: Skeleton3D, id: String) -> Dictionary:
	if _heads.has(id):
		return _heads[id]
	var h := skel.get_bone_global_rest(skel.find_bone("Head")).origin
	var e := skel.get_bone_global_rest(skel.find_bone("Head_end")).origin
	var ax := (e - h).normalized()
	var sup := (Vector3.UP - ax * ax.dot(Vector3.UP)).normalized()
	var side := ax.cross(sup).normalized()
	var pts := PackedVector3Array()
	var eye_pts := [PackedVector3Array(), PackedVector3Array()]
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).get_active_material(0)
		var is_eye := mat != null and mat.resource_name == "Eye"
		for p in _skin_points(skel, m, ["Head", "Jaw"]):
			var d := p - h
			var q := Vector3(d.dot(ax), d.dot(sup), d.dot(side))
			if is_eye:
				eye_pts[1 if q.z > 0.0 else 0].append(p)
			else:
				pts.append(q)
	var bone := h.distance_to(e)
	var shape := {"at": h, "ax": ax, "sup": sup, "side": side, "fwd": Vector3(ax.x, 0.0, ax.z).normalized(), "pts": pts,
		"bone": bone, "wide": bone * 0.6, "len": bone * 2.4, "tip": bone * 1.5, "eyes": [h, h], "eye": bone * 0.2,
		"brow": bone * 0.5}
	if not pts.is_empty():
		var wide := 0.0
		var lo := INF
		var hi := -INF
		for q: Vector3 in pts:
			wide = maxf(wide, absf(q.z))
			lo = minf(lo, q.x)
			hi = maxf(hi, q.x)
		shape.wide = wide
		shape.tip = hi
		shape.len = hi - lo
	for k in 2:
		var eye: PackedVector3Array = eye_pts[k]
		if eye.is_empty():
			continue
		var middle := Vector3.ZERO
		for p: Vector3 in eye:
			middle += p
		middle /= eye.size()
		var r := 0.0
		for p: Vector3 in eye:
			r = maxf(r, p.distance_to(middle))
		shape.eyes[k] = middle
		shape.eye = r
		shape.brow = (middle - h).dot(ax)
	_heads[id] = shape
	return shape


## The top of a star's head (shape: _head) `along` its skull from its Head bone, near its middle line: a point in its
## skeleton's space.
static func _top_at(shape: Dictionary, along: float) -> Vector3:
	var half: float = shape.len * 0.06
	var wide: float = shape.wide
	var best := -INF
	for q: Vector3 in shape.pts:
		if absf(q.x - along) < half and absf(q.z) < wide * 0.4:
			best = maxf(best, q.y)
	if best == -INF:
		best = shape.bone * 0.5
	return shape.at + shape.ax * along + shape.sup * best


## A star's head cut across `along` its skull (shape: _head): its lowest and highest there (up its skull from its Head
## bone), and its half-width.
static func _section(shape: Dictionary, along: float) -> Vector3:
	var half: float = shape.len * 0.06
	var cut := Vector3(INF, -INF, 0.0)
	for q: Vector3 in shape.pts:
		if absf(q.x - along) < half:
			cut = Vector3(minf(cut.x, q.y), maxf(cut.y, q.y), maxf(cut.z, absf(q.z)))
	if cut.x == INF:
		return Vector3(-0.3, 0.3, 0.3) * shape.bone
	return cut


## The point of a star's skin held by `bones` furthest toward `dir`, in its skeleton's space as it stands at rest.
static func _furthest(model: Node3D, skel: Skeleton3D, bones: Array, dir: Vector3) -> Vector3:
	var best := -INF
	var at := Vector3.ZERO
	for m in model.find_children("*", "MeshInstance3D", true, false):
		for p in _skin_points(skel, m, bones):
			if p.dot(dir) > best:
				best = p.dot(dir)
				at = p
	return at


## The points of mesh `m`'s skin held mostly (over half) by bones `names` of `skel`, where they are at rest in the
## skeleton's space.
static func _skin_points(skel: Skeleton3D, m: MeshInstance3D, names: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if m.skin == null or m.mesh == null:
		return out
	var poses := {}
	for b in m.skin.get_bind_count():
		var bone := skel.find_bone(m.skin.get_bind_name(b))
		if bone >= 0 and skel.get_bone_name(bone) in names:
			poses[b] = skel.get_bone_global_rest(bone) * m.skin.get_bind_pose(b)
	if poses.is_empty():
		return out
	for s in m.mesh.get_surface_count():
		var arrays := m.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var per := int(bones.size() / maxi(1, verts.size()))
		for v in verts.size():
			var held := 0.0
			var pose := Transform3D()
			for k in per:
				var b := int(bones[v * per + k])
				if poses.has(b):
					held += float(weights[v * per + k])
					pose = poses[b]
			if held > 0.5:
				out.append(pose * verts[v])
	return out


## Its hand (its Fingers bone) on the side it shows in its pen; "" if it has none.
static func _shown_hand(skel: Skeleton3D, side: Vector3, head: Vector3) -> String:
	for hand in ["Fingers.L", "Fingers.R"]:
		var i := skel.find_bone(hand)
		if i >= 0 and (skel.get_bone_global_rest(i).origin - head).dot(side) > 0.0:
			return hand
	return ""


## `mesh` held by `bone`, at `at` in the skeleton's space as it stands at rest, turned by `turn`.
static func _put(skel: Skeleton3D, bone: String, at: Vector3, turn: Basis, mesh: Mesh, mat: Material) -> void:
	var i := skel.find_bone(bone)
	if i >= 0:
		_grow(skel, bone, at - skel.get_bone_global_rest(i).origin, turn, mesh, mat)


## `mesh` laid on the ground by a star (`ground`: its body), at `at`, turned by `turn`.
static func _lay(ground: Node3D, at: Vector3, turn: Basis, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(turn, at)
	ground.add_child(mi)


## A basis whose up points along `dir`, made thin (by `thin`) toward `flat`, and `wide` across both.
static func _blade(dir: Vector3, flat: Vector3, thin: float, wide := 1.0) -> Basis:
	var y := dir.normalized()
	var x := (flat - y * flat.dot(y)).normalized()
	return Basis(x * thin, y, x.cross(y) * wide)


## A crown's band: a short open tube, a little narrower at its foot.
static func _band(radius: float, height: float) -> CylinderMesh:
	var m := _cylinder(radius, height)
	m.bottom_radius = radius * 0.9
	m.cap_top = false
	m.cap_bottom = false
	return m


static func _torus(r: float, thick: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = r - thick * 0.5
	m.outer_radius = r + thick * 0.5
	m.rings = 24
	m.ring_segments = 8
	return m


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


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
	if n.has_meta("alien"):
		Aliens.flash(n, c, strength)
		return
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


static func _scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		var scene := load(DINOS + file + ".gltf") as PackedScene
		_toon(scene)
		_scenes[file] = scene
	return _scenes[file]


## The plain one's bounds, as it stands at rest.
static func _plain_box(species: String) -> AABB:
	if not _boxes.has(species):
		var probe := _scene(species).instantiate() as Node3D
		_boxes[species] = Geo.bounds(probe)
		var players := probe.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			_clips[species] = (players[0] as AnimationPlayer).get_animation_library("")
		probe.free()
	return _boxes[species]


## An elite has no clips of its own: on the plain one's skeleton (its bones named the same), the plain one's move it.
static func _lend_clips(model: Node3D, species: String) -> void:
	_plain_box(species)
	if not _clips.has(species) or not model.find_children("*", "AnimationPlayer", true, false).is_empty():
		return
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", _clips[species])
	model.add_child(player)


## A species' materials (shared by every one of it): its colours are the mesh's own (Godot leaves them unused on
## import), lit softly -- light falling off smoothly round the body, a faint rim where it turns away, a glint in the
## eyes -- in the world's own light (World), so it sits in the scene rather than on it.
static func _toon(scene: PackedScene) -> void:
	var probe := scene.instantiate()
	for mi in probe.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			if m == null:
				continue
			m.vertex_color_use_as_albedo = true
			if m.resource_name == "Eye":
				continue
			# Its colours a little under what they are painted: the sun and the sky's light together put a bright
			# yellow past white.
			m.albedo_color = Color(TOON_TONE, TOON_TONE, TOON_TONE)
			m.roughness = 0.62
			m.metallic_specular = 0.35
			m.rim_enabled = true
			m.rim = 0.18
			m.rim_tint = 0.6
	probe.free()


static func _overlay() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OVERLAY
	return _shader
