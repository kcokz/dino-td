class_name Aliens
## Their monsters on screen (GAME-DESIGN 23): each kind a cartoon alien made of smooth round shapes, lit as our
## dinosaurs are (soft steps of light, a bright rim), in its own colour (Content.ENEMIES) with a darker back and a paler
## belly, its eyes glowing -- on one of seven body plans: a crawler on six legs (jaws, a shell, spikes, pincers, a
## stinger, as its kind has them), a beast on four (a tail, fangs, horns, rocks and embers, fur), a frog (a tongue), a
## worm of segments (a sucker, a ring of teeth, fangs and a fin), a moth, a blob (spore balls, ice crystals,
## tentacles, eggs, legs), a jellyfish. Each kind is built once -- its shapes under each moving part made one mesh --
## and copied; it moves with clips made here (idle, run, attack, batter, death) through an AnimationPlayer, so
## Creatures moves it as it moves a dinosaur (meta "model", "player", "height"; a "Body" that lunges). A blow flashes
## it by wearing one bright material for a moment.

const TONE := 0.8                          # their colours under the toon light (Creatures.TOON_TONE: ours)
## How big one looks (the larger of its length and its width, in metres): its size (Content.ENEMIES) times FOOT -- but
## an ordinary one never bigger than PLAIN_MAX, a mini-boss or a boss never smaller than ELITE_MIN (the player, 2026-10-19:
## "基础怪大小要有个上限a，精英怪大小有个下限b，b>a"), so which are the strong ones reads at a glance whatever their shape.
const FOOT := 1.1
const PLAIN_MAX := 1.3
const ELITE_MIN := 2.0
const EYE := Color(1.0, 0.34, 0.14)
const BONE := Color(0.93, 0.88, 0.74)
const ICE := Color(0.72, 0.9, 1.0)
const LAVA := Color(1.0, 0.45, 0.1)
const PINK := Color(0.95, 0.45, 0.55)

## Each kind's body plan and what it has.
const KINDS := {
	# The rainforest.
	"grey": {"plan": "crawler", "eyes": 2, "jaws": 1.0, "antennae": true},
	"purple": {"plan": "crawler", "eyes": 3, "jaws": 0.6, "sac": true, "antennae": true},
	"black": {"plan": "crawler", "eyes": 2, "jaws": 1.3, "shell": true},
	"spore": {"plan": "blob", "eyes": 2, "spores": 6},
	"mite": {"plan": "crawler", "eyes": 2, "jaws": 0.5, "round": true},
	"mini_rain": {"plan": "crawler", "eyes": 4, "jaws": 2.3, "shell": true},
	"mini_rain2": {"plan": "crawler", "eyes": 2, "jaws": 1.2, "spikes": 5, "antennae": true},
	"boss_rain": {"plan": "blob", "eyes": 5, "legs": true, "eggs": 7, "crown": true},
	# The volcano.
	"beetle": {"plan": "crawler", "eyes": 2, "jaws": 0.8, "shell": true, "horn": true, "embers": true},
	"salamander": {"plan": "beast", "eyes": 2, "tail": 1.1, "flame": true, "slim": true},
	"mini_lava": {"plan": "beast", "eyes": 2, "tail": 0.5, "bulk": 1.25, "rocks": true, "embers": true},
	"mini_lava2": {"plan": "beast", "eyes": 2, "tail": 1.2, "spikes": 6, "slim": true},
	"boss_lava": {"plan": "beast", "eyes": 2, "tail": 0.7, "bulk": 1.35, "rocks": true, "embers": true, "horns": true},
	# The swamp.
	"leech": {"plan": "worm", "segments": 5, "mouth": "sucker", "eyes": 2, "bands": true},
	"moth": {"plan": "moth", "eyes": 2},
	"mini_bog": {"plan": "frog", "eyes": 2},
	"mini_bog2": {"plan": "frog", "eyes": 2, "warts": true, "sacs": true},
	"boss_bog": {"plan": "blob", "eyes": 3, "tentacles": 7, "warts": true},
	# The ice fields.
	"frostfang": {"plan": "beast", "eyes": 2, "tail": 0.8, "fangs": true, "frost": true, "slim": true},
	"shard": {"plan": "blob", "eyes": 1, "crystals": 7},
	"mini_ice": {"plan": "crawler", "eyes": 2, "jaws": 1.0, "shell": true, "frost": true},
	"mini_ice2": {"plan": "beast", "eyes": 2, "tail": 0.4, "bulk": 1.3, "fur": true, "horns": true},
	"boss_ice": {"plan": "crawler", "eyes": 4, "jaws": 1.4, "shell": true, "frost": true, "crown": true},
	# The desert.
	"sandworm": {"plan": "worm", "segments": 5, "mouth": "teeth", "eyes": 3, "bands": true},
	"scorpion": {"plan": "crawler", "eyes": 2, "jaws": 0.5, "pincers": 1.0, "stinger": true},
	"mini_sand": {"plan": "worm", "segments": 7, "mouth": "teeth", "eyes": 3, "spikes": true},
	"mini_sand2": {"plan": "crawler", "eyes": 4, "jaws": 0.6, "pincers": 1.3, "stinger": true, "shell": true},
	"boss_sand": {"plan": "worm", "segments": 8, "mouth": "teeth", "eyes": 5, "spikes": true, "crown": true},
	# The coast.
	"crab": {"plan": "crawler", "eyes": 2, "jaws": 0.3, "pincers": 1.1, "flat": true, "stalks": true},
	"jelly": {"plan": "jelly"},
	"mini_sea": {"plan": "crawler", "eyes": 2, "jaws": 0.3, "pincers": 1.7, "flat": true, "stalks": true, "shell": true},
	"mini_sea2": {"plan": "worm", "segments": 8, "mouth": "fangs", "eyes": 2, "fin": true},
	"boss_sea": {"plan": "blob", "eyes": 5, "tentacles": 8, "crown": true},
}

static var _scenes := {}           # kind -> PackedScene, built the first time it is wanted
static var _heights := {}          # kind -> how tall it stands, as built
static var _feet := {}             # kind -> the larger of its length and width, as built
static var _mats := {}             # a material for each colour (and look)
static var _shapes := {}           # "ball", "cone", "ring" -> mesh


static func has(kind: String) -> bool:
	return KINDS.has(kind)


## One of theirs, `edge` its size: its root stands at its feet and looks along +z.
static func make(edge: float, kind: String) -> Node3D:
	var root := Node3D.new()
	root.set_meta("edge", edge)
	root.set_meta("model", true)
	root.set_meta("alien", true)
	root.set_meta("turn", 0.6)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var model := _scene(kind).instantiate() as Node3D
	var s := looks(edge, kind) / float(_feet[kind])
	model.scale = Vector3.ONE * s
	body.add_child(model)
	root.set_meta("height", float(_heights[kind]) * s)
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	root.set_meta("player", player)
	player.play("idle")
	player.seek(randf() * player.current_animation_length, true)
	return root


## How big one of `kind` and size `edge` looks (FOOT, PLAIN_MAX, ELITE_MIN).
static func looks(edge: float, kind: String) -> float:
	var foot := edge * FOOT
	if kind.begins_with("mini_") or kind.begins_with("boss_"):
		return maxf(foot, ELITE_MIN)
	return minf(foot, PLAIN_MAX)


## A short glow of `c` over the whole of one: each of its shapes wears it for a moment.
static func flash(n: Node3D, c: Color, strength: float) -> void:
	var mat := _flash_mat(c)
	var shapes: Array = n.find_children("*", "MeshInstance3D", true, false)
	for mi in shapes:
		(mi as MeshInstance3D).material_override = mat
	var back := func() -> void:
		for mi in shapes:
			if is_instance_valid(mi):
				(mi as MeshInstance3D).material_override = null
	var tw := n.create_tween()
	tw.tween_interval(0.05 + 0.08 * clampf(strength, 0.0, 1.0))
	tw.tween_callback(back)


# -- Building a kind once ---------------------------------------------------------------------------------------------

static func _scene(kind: String) -> PackedScene:
	if _scenes.has(kind):
		return _scenes[kind]
	var k: Dictionary = KINDS[kind]
	var c: Color = Content.ENEMIES[kind].color
	var model := Node3D.new()
	model.name = kind
	var clips: Dictionary
	match String(k.plan):
		"crawler":
			clips = _crawler(model, k, c)
		"beast":
			clips = _beast(model, k, c)
		"frog":
			clips = _frog(model, k, c)
		"worm":
			clips = _worm(model, k, c)
		"moth":
			clips = _moth(model, k, c)
		"blob":
			clips = _blob_plan(model, k, c)
		_:
			clips = _jelly(model, k, c)
	var pivots: Array = [model]
	for n in model.find_children("*", "Node3D", true, false):
		if not (n is MeshInstance3D):
			pivots.append(n)
	for p in pivots:
		_merge(p)
	var lib := AnimationLibrary.new()
	for clip_name in clips:
		lib.add_animation(clip_name, clips[clip_name])
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	player.add_animation_library("", lib)
	# Measured standing as it stands (a frog's tongue in, a moth's wings up), not as it was built.
	player.play("idle")
	player.seek(0.0, true)
	var box := Geo.bounds(model)
	_heights[kind] = box.end.y
	_feet[kind] = maxf(box.size.x, box.size.z)
	for n in model.find_children("*", "", true, false):
		n.owner = model
	var scene := PackedScene.new()
	scene.pack(model)
	model.free()
	_scenes[kind] = scene
	return scene


## The shapes hung straight under `pivot` (not those under its own moving parts) made one mesh, a surface for each
## material -- normals turned as a squashed shape turns them -- so a kind is drawn in few pieces.
static func _merge(pivot: Node) -> void:
	var parts: Array = []
	for ch in pivot.get_children():
		if ch is MeshInstance3D:
			parts.append(ch)
	if parts.size() < 2:
		return
	var groups := {}                 # material -> [vertices, normals, indices]
	var order: Array = []
	for mi: MeshInstance3D in parts:
		var arr := mi.mesh.surface_get_arrays(0)
		var xf := mi.transform
		var turn := xf.basis.inverse().transposed()
		var m: Material = mi.material_override
		if not groups.has(m):
			groups[m] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
			order.append(m)
		var g: Array = groups[m]
		var verts: PackedVector3Array = g[0]
		var norms: PackedVector3Array = g[1]
		var idx: PackedInt32Array = g[2]
		var base := verts.size()
		for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
			verts.append(xf * v)
		for nv: Vector3 in arr[Mesh.ARRAY_NORMAL]:
			norms.append((turn * nv).normalized())
		for i: int in arr[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
		groups[m] = [verts, norms, idx]
	var mesh := ArrayMesh.new()
	for m: Material in order:
		var g: Array = groups[m]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g[0]
		arrays[Mesh.ARRAY_NORMAL] = g[1]
		arrays[Mesh.ARRAY_INDEX] = g[2]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	var merged := MeshInstance3D.new()
	merged.name = "Shape"
	merged.mesh = mesh
	pivot.add_child(merged)
	for mi in parts:
		pivot.remove_child(mi)
		mi.free()


# -- The crawler: six legs ---------------------------------------------------------------------------------------------

static func _crawler(model: Node3D, k: Dictionary, c: Color) -> Dictionary:
	var flat: bool = k.get("flat", false)
	var roundish: bool = k.get("round", false)
	var hip := 0.34 if flat else 0.42
	var main := _skin(c)
	var dark := _skin(_shade(c, -0.42))
	var pale := _skin(_shade(c, 0.35))
	var torso := _pivot(model, "Torso", Vector3(0, hip, 0))
	# The body: a big round back end and a smaller middle (a crab's wide and flat), a paler belly under.
	if roundish:
		_ball(torso, Vector3(0, 0.04, -0.06), Vector3(0.8, 0.7, 0.84), main)
	elif flat:
		_ball(torso, Vector3(0, 0.02, -0.04), Vector3(1.02, 0.44, 0.84), main)
	else:
		_ball(torso, Vector3(0, 0.04, -0.3), Vector3(0.72, 0.56, 0.82), main)
		_ball(torso, Vector3(0, 0.0, 0.12), Vector3(0.5, 0.42, 0.46), main)
	_ball(torso, Vector3(0, -0.1, -0.1), Vector3(0.9 if flat else 0.6, 0.3, 0.72), pale)
	if k.get("shell", false):
		# A shell: a dark dome over the back, plates' edges paler.
		var at := Vector3(0, 0.12, -0.06) if flat or roundish else Vector3(0, 0.14, -0.26)
		var size := Vector3(1.06, 0.36, 0.88) if flat else Vector3(0.78, 0.42, 0.86)
		_ball(torso, at, size, dark)
		for i in 3:
			_ball(torso, at + Vector3(0, size.y * 0.32 - i * 0.02, size.z * (0.28 - i * 0.26)),
				Vector3(size.x * (0.72 - i * 0.08), 0.05, 0.06), pale)
	if k.get("spikes", 0) > 0:
		for i in int(k.spikes):
			var z := 0.12 - i * 0.12
			_cone(torso, Vector3(0, 0.26 - absf(z + 0.18) * 0.25, z), Vector3(0, 1, -0.35), 0.18, 0.1, _skin(BONE))
	if k.get("frost", false):
		for i in 5:
			var a := -0.7 + i * 0.35
			_cone(torso, Vector3(sin(a) * 0.26, 0.24, -0.22 + cos(a * 2.0) * 0.12), Vector3(sin(a), 1.4, -0.3), 0.2,
				0.09, _glow(ICE, 0.5))
	if k.get("embers", false):
		for p in [Vector3(-0.2, 0.26, -0.3), Vector3(0.18, 0.28, -0.12), Vector3(0.05, 0.3, -0.42), Vector3(-0.1, 0.27, 0.0)]:
			_ball(torso, p, Vector3.ONE * 0.08, _glow(LAVA, 2.0))
	if k.get("sac", false):
		_ball(torso, Vector3(0, 0.28, -0.42), Vector3(0.34, 0.3, 0.32), _glow(_shade(c, 0.4), 0.9))
	# The head, its eyes, its jaws.
	var head := _pivot(torso, "Head", Vector3(0, 0.04, 0.32 if roundish or flat else 0.38))
	_ball(head, Vector3.ZERO, Vector3(0.42, 0.36, 0.38), main)
	if k.get("stalks", false):
		for side in [-1.0, 1.0]:
			_limb(head, Vector3(side * 0.1, 0.1, 0.05), Vector3(side * 0.16, 0.34, 0.1), 0.06, dark)
			_ball(head, Vector3(side * 0.16, 0.36, 0.1), Vector3.ONE * 0.11, _glow(EYE, 1.8))
	else:
		_eyes(head, int(k.get("eyes", 2)), Vector3(0.21, 0.18, 0.19), 1.0)
	if k.get("horn", false):
		_cone(head, Vector3(0, 0.12, 0.1), Vector3(0, 1, 0.55), 0.38, 0.13, dark)
	if k.get("crown", false):
		for i in 6:
			var a := TAU * i / 6.0
			_cone(head, Vector3(sin(a) * 0.12, 0.15, cos(a) * 0.1 - 0.02), Vector3(sin(a) * 0.4, 1, cos(a) * 0.3), 0.2,
				0.07, _glow(ICE if k.get("frost", false) else _shade(c, 0.5), 0.8))
	var jaws := float(k.get("jaws", 1.0))
	for side in [-1.0, 1.0]:
		var jaw := _pivot(head, "Jaw" + ("L" if side < 0 else "R"), Vector3(side * 0.09, -0.06, 0.15))
		_cone(jaw, Vector3.ZERO, Vector3(-side * 0.4, -0.1, 1.0), 0.16 * jaws, 0.07 * minf(jaws, 1.4), _skin(BONE))
	if k.get("antennae", false):
		for side in [-1.0, 1.0]:
			var ant := _pivot(head, "Ant" + ("L" if side < 0 else "R"), Vector3(side * 0.07, 0.14, 0.08))
			_limb(ant, Vector3.ZERO, Vector3(side * 0.12, 0.22, 0.14), 0.035, dark)
			_ball(ant, Vector3(side * 0.12, 0.23, 0.15), Vector3.ONE * 0.06, pale)
	var pincers := float(k.get("pincers", 0.0))
	if pincers > 0.0:
		for side in [-1.0, 1.0]:
			var claw := _pivot(torso, "Claw" + ("L" if side < 0 else "R"), Vector3(side * 0.24, -0.02, 0.26))
			var wrist := Vector3(side * 0.18, 0.02, 0.24) * pincers
			_limb(claw, Vector3.ZERO, wrist, 0.1 * pincers, dark)
			_ball(claw, wrist + Vector3(0, 0, 0.1) * pincers, Vector3(0.2, 0.16, 0.26) * pincers, main)
			var finger := _pivot(claw, "Finger", wrist + Vector3(-side * 0.04, -0.02, 0.2) * pincers)
			_cone(finger, Vector3.ZERO, Vector3(-side * 0.25, 0, 1), 0.16 * pincers, 0.08 * pincers, dark)
	if k.get("stinger", false):
		var tail := _pivot(torso, "Tail", Vector3(0, 0.12, -0.6))
		var pts := [Vector3(0, 0.0, 0.0), Vector3(0, 0.16, -0.08), Vector3(0, 0.34, -0.06), Vector3(0, 0.48, 0.04),
			Vector3(0, 0.56, 0.18)]
		for i in pts.size():
			_ball(tail, pts[i], Vector3.ONE * (0.2 - i * 0.025), main if i % 2 == 0 else dark)
		_cone(tail, pts[-1] + Vector3(0, 0, 0.06), Vector3(0, -0.6, 1), 0.2, 0.08, _glow(_shade(c, 0.5), 1.2))
	# Six legs, three a side, each bent at the knee, its foot on the ground.
	var legs: Array = []
	for i in 3:
		var z: float = ([0.2, 0.02, -0.18] if not roundish else [0.14, 0.0, -0.14])[i]
		for side in [-1.0, 1.0]:
			var leg_name := "Leg%s%d" % ["L" if side < 0 else "R", i]
			var leg := _pivot(torso, leg_name, Vector3(side * (0.32 if flat else 0.2), -0.04, z))
			var knee := Vector3(side * 0.3, 0.16, [0.06, 0.0, -0.06][i])
			var foot := Vector3(side * 0.46, 0.07 - hip, [0.18, 0.0, -0.18][i])
			_limb(leg, Vector3.ZERO, knee, 0.09, dark)
			_limb(leg, knee, foot, 0.075, dark)
			legs.append({"path": "Torso/" + leg_name, "side": side, "group": (i + (0 if side < 0 else 1)) % 2})
	return _crawler_clips(hip, legs, k)


static func _crawler_clips(hip: float, legs: Array, k: Dictionary) -> Dictionary:
	var rest := {"Torso:position": Vector3(0, hip, 0), "Torso:rotation": Vector3.ZERO, "Torso:scale": Vector3.ONE,
		"Torso/Head:rotation": Vector3.ZERO, "Torso/Head/JawL:rotation": Vector3.ZERO,
		"Torso/Head/JawR:rotation": Vector3.ZERO}
	if k.get("antennae", false):
		rest["Torso/Head/AntL:rotation"] = Vector3.ZERO
		rest["Torso/Head/AntR:rotation"] = Vector3.ZERO
	if k.get("pincers", 0.0) > 0.0:
		for s in ["L", "R"]:
			rest["Torso/Claw%s:rotation" % s] = Vector3.ZERO
			rest["Torso/Claw%s/Finger:rotation" % s] = Vector3.ZERO
	if k.get("stinger", false):
		rest["Torso/Tail:rotation"] = Vector3.ZERO
	for leg in legs:
		rest[leg.path + ":rotation"] = Vector3.ZERO
	var clips := {}
	# Standing: breathing, looking about, its jaws working.
	var idle := _holds(rest)
	idle["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.012 * sin(TAU * t), 0)
	idle["Torso:scale"] = func(t: float) -> Vector3: return Vector3(1, 1, 1) + Vector3(0.015, -0.015, 0.015) * sin(TAU * t)
	idle["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(0.05 * sin(TAU * t), 0.14 * sin(TAU * t + 0.6), 0)
	idle["Torso/Head/JawL:rotation"] = func(t: float) -> Vector3: return Vector3(0, -0.12 - 0.1 * sin(TAU * 2.0 * t), 0)
	idle["Torso/Head/JawR:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.12 + 0.1 * sin(TAU * 2.0 * t), 0)
	if k.get("antennae", false):
		idle["Torso/Head/AntL:rotation"] = func(t: float) -> Vector3: return Vector3(0.2 * sin(TAU * t), 0, 0.12 * sin(TAU * t + 1.0))
		idle["Torso/Head/AntR:rotation"] = func(t: float) -> Vector3: return Vector3(0.2 * sin(TAU * t + 0.5), 0, -0.12 * sin(TAU * t + 1.5))
	if k.get("stinger", false):
		idle["Torso/Tail:rotation"] = func(t: float) -> Vector3: return Vector3(0.08 * sin(TAU * t), 0.1 * sin(TAU * t + 0.4), 0)
	clips["idle"] = _clip(2.0, true, idle)
	# Running: three legs swing forward lifted while the other three push back, by turns; the body bobs at each.
	var run := _holds(rest)
	for leg in legs:
		var side: float = leg.side
		var phase := 0.5 * float(leg.group)
		run[leg.path + ":rotation"] = func(t: float) -> Vector3:
			var a := TAU * (t + phase)
			return Vector3(0, -side * 0.4 * sin(a), side * 0.32 * maxf(0.0, cos(a)))
	run["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.022 * (0.5 + 0.5 * cos(TAU * 2.0 * t)), 0)
	run["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(0.04, 0, 0.05 * sin(TAU * t))
	run["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(0.06 * sin(TAU * 2.0 * t), 0.05 * sin(TAU * t), 0)
	if k.get("antennae", false):
		run["Torso/Head/AntL:rotation"] = func(t: float) -> Vector3: return Vector3(-0.45 + 0.1 * sin(TAU * 2.0 * t), 0, 0)
		run["Torso/Head/AntR:rotation"] = func(t: float) -> Vector3: return Vector3(-0.45 + 0.1 * sin(TAU * 2.0 * t + 1.0), 0, 0)
	clips["run"] = _clip(0.42, true, run, 16)
	# A bite: it rears its head, jaws wide, and strikes down, snapping them shut; claws swing up and in; a stinger
	# cocks back and stabs over its head.
	var attack := _holds(rest)
	attack["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(-0.3 * _bump(t, 0.16, 0.16) + 0.38 * _bump(t, 0.32, 0.14), 0, 0)
	attack["Torso/Head/JawL:rotation"] = func(t: float) -> Vector3: return Vector3(0, -0.6 * _bump(t, 0.2, 0.16) + 0.06 * _bump(t, 0.34, 0.08), 0)
	attack["Torso/Head/JawR:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.6 * _bump(t, 0.2, 0.16) - 0.06 * _bump(t, 0.34, 0.08), 0)
	attack["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip, 0.08 * _bump(t, 0.32, 0.18))
	attack["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(-0.08 * _bump(t, 0.16, 0.14) + 0.1 * _bump(t, 0.32, 0.14), 0, 0)
	if k.get("pincers", 0.0) > 0.0:
		for s in ["L", "R"]:
			var turn_sign := -1.0 if s == "L" else 1.0
			attack["Torso/Claw%s:rotation" % s] = func(t: float) -> Vector3: return Vector3(-0.6 * _bump(t, 0.16, 0.16) + 0.25 * _bump(t, 0.32, 0.12), turn_sign * 0.25 * _bump(t, 0.32, 0.14), 0)
			attack["Torso/Claw%s/Finger:rotation" % s] = func(t: float) -> Vector3: return Vector3(0, turn_sign * 0.5 * _bump(t, 0.18, 0.14), 0)
	if k.get("stinger", false):
		attack["Torso/Tail:rotation"] = func(t: float) -> Vector3: return Vector3(-0.35 * _bump(t, 0.16, 0.16) + 0.9 * _bump(t, 0.32, 0.14), 0, 0)
	clips["attack"] = _clip(0.5, false, attack, 20)
	var batter := _holds(rest)
	batter["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.14, -0.18, 0.14) * _bump(t, 0.18, 0.18) - Vector3(0.03, -0.04, 0.03) * _bump(t, 0.5, 0.2)
	batter["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(-0.14 * _bump(t, 0.2, 0.2), 0, 0)
	batter["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(-0.25 * _bump(t, 0.2, 0.2), 0, 0)
	clips["batter"] = _clip(0.3, false, batter, 12)
	# Falling: it hops, rolls over onto its back, its legs curl up and twitch.
	var death := _holds(rest)
	death["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, lerpf(hip, hip * 0.6, smoothstep(0.25, 0.6, t)) + 0.16 * _bump(t, 0.2, 0.2), 0)
	death["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, PI * 0.96 * smoothstep(0.1, 0.55, t))
	death["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(-0.3 * smoothstep(0.3, 0.7, t), 0, 0)
	death["Torso/Head/JawL:rotation"] = func(t: float) -> Vector3: return Vector3(0, -0.45 * smoothstep(0.3, 0.6, t), 0)
	death["Torso/Head/JawR:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.45 * smoothstep(0.3, 0.6, t), 0)
	for leg in legs:
		var side: float = leg.side
		var phase := 0.3 * float(leg.group)
		death[leg.path + ":rotation"] = func(t: float) -> Vector3:
			var curl := smoothstep(0.35, 0.7, t)
			return Vector3(0, 0.25 * sin(TAU * 3.0 * (t + phase)) * curl * (1.0 - smoothstep(0.75, 1.0, t)), -side * 0.9 * curl)
	clips["death"] = _clip(0.9, false, death, 24)
	return clips


# -- The beast: four legs, a tail ----------------------------------------------------------------------------------------

static func _beast(model: Node3D, k: Dictionary, c: Color) -> Dictionary:
	var bulk := float(k.get("bulk", 1.0))
	var slim: bool = k.get("slim", false)
	var hip := 0.44 if not slim else 0.36
	var main := _skin(c)
	var dark := _skin(_shade(c, -0.42))
	var pale := _skin(_shade(c, 0.35))
	var torso := _pivot(model, "Torso", Vector3(0, hip, 0))
	var w := (0.46 if slim else 0.6) * bulk
	var h := (0.38 if slim else 0.48) * bulk
	_ball(torso, Vector3(0, 0.03, -0.06), Vector3(w, h, 1.0), main)
	_ball(torso, Vector3(0, 0.06, 0.28), Vector3(w * 1.02, h * 1.06, 0.5), main)
	_ball(torso, Vector3(0, -h * 0.22, 0.02), Vector3(w * 0.84, h * 0.62, 0.84), pale)
	var top := h * 0.5 + 0.03
	if k.get("spikes", 0) > 0:
		for i in int(k.spikes):
			var z := 0.36 - i * 0.16
			_cone(torso, Vector3(0, top - 0.02 - absf(z) * 0.08, z), Vector3(0, 1, -0.4), 0.2 - absf(z) * 0.1, 0.11, dark)
	if k.get("rocks", false):
		for p in [Vector3(-0.15, top, 0.18), Vector3(0.16, top + 0.02, -0.02), Vector3(-0.05, top + 0.01, -0.24),
				Vector3(0.12, top - 0.02, 0.3), Vector3(-0.2, top - 0.04, -0.12)]:
			_ball(torso, p, Vector3(0.24, 0.17, 0.22) * bulk, _skin(Color(0.22, 0.18, 0.16)))
	if k.get("embers", false):
		for p in [Vector3(0.0, top + 0.05, 0.06), Vector3(-0.08, top + 0.04, -0.12), Vector3(0.1, top + 0.04, 0.2),
				Vector3(0.05, top + 0.02, -0.3)]:
			_ball(torso, p, Vector3.ONE * 0.08, _glow(LAVA, 2.2))
	if k.get("fur", false):
		var fur := _skin(_shade(c, 0.15))
		for p in [Vector3(-0.2, top - 0.04, 0.3), Vector3(0.2, top - 0.04, 0.3), Vector3(0, top + 0.02, 0.22),
				Vector3(-0.16, top - 0.02, 0.06), Vector3(0.16, top - 0.02, 0.06)]:
			_ball(torso, p, Vector3(0.3, 0.26, 0.3) * bulk, fur)
	if k.get("frost", false):
		for i in 4:
			_cone(torso, Vector3(0, top - 0.02, 0.24 - i * 0.16), Vector3(0, 1, -0.5), 0.16, 0.09, _glow(ICE, 0.5))
	# The head: a round skull, a snout, a lower jaw that opens; eyes; fangs or horns, as it has them.
	var head := _pivot(torso, "Head", Vector3(0, 0.12 * bulk, 0.58 + 0.04 * bulk))
	_ball(head, Vector3(0, 0.02, 0), Vector3(0.42, 0.36, 0.4) * minf(bulk, 1.15), main)
	_ball(head, Vector3(0, -0.04, 0.2), Vector3(0.3, 0.22, 0.32) * minf(bulk, 1.15), main)
	_eyes(head, int(k.get("eyes", 2)), Vector3(0.2, 0.17, 0.2) * minf(bulk, 1.15), 1.0, Vector3(0, 0.03, 0.0))
	var jaw := _pivot(head, "Jaw", Vector3(0, -0.1, 0.04))
	_ball(jaw, Vector3(0, -0.01, 0.16), Vector3(0.26, 0.1, 0.32) * minf(bulk, 1.15), pale)
	if k.get("fangs", false):
		for side in [-1.0, 1.0]:
			_cone(head, Vector3(side * 0.07, -0.1, 0.3), Vector3(0, -1, 0.15), 0.12, 0.05, _skin(BONE))
	if k.get("horns", false):
		for side in [-1.0, 1.0]:
			_cone(head, Vector3(side * 0.12, 0.14, -0.04), Vector3(side * 0.6, 0.9, -0.6), 0.34 * bulk, 0.11 * bulk, _skin(BONE))
	# The tail, in two parts so it can whip; a salamander's tip burning.
	var tail_k := float(k.get("tail", 0.8))
	var tail := _pivot(torso, "Tail", Vector3(0, 0.03, -0.5))
	_ball(tail, Vector3(0, 0, -0.16 * tail_k), Vector3(w * 0.55, h * 0.55, 0.42 * tail_k), main)
	var tip := _pivot(tail, "Tip", Vector3(0, -0.01, -0.32 * tail_k))
	_ball(tip, Vector3(0, 0, -0.16 * tail_k), Vector3(w * 0.32, h * 0.32, 0.4 * tail_k), main)
	if k.get("flame", false):
		_ball(tip, Vector3(0, 0.04, -0.36 * tail_k), Vector3(0.2, 0.26, 0.2), _glow(LAVA, 2.4))
		_ball(tip, Vector3(0, 0.1, -0.38 * tail_k), Vector3(0.11, 0.18, 0.11), _glow(Color(1.0, 0.85, 0.35), 2.4))
	# Four legs under it, a round foot each.
	var legs: Array = []
	for front in [true, false]:
		for side in [-1.0, 1.0]:
			var leg_name := "Leg%s%s" % ["F" if front else "B", "L" if side < 0 else "R"]
			var leg := _pivot(torso, leg_name, Vector3(side * w * 0.42, -0.06, 0.3 if front else -0.3))
			var knee := Vector3(side * 0.05, -(hip - 0.06) * 0.5, 0.02 if front else -0.04)
			var foot := Vector3(side * 0.04, 0.05 - (hip - 0.06), 0.05)
			_limb(leg, Vector3(0, 0.02, 0), knee, 0.17 * bulk, main)
			_limb(leg, knee, foot, 0.12 * bulk, dark)
			_ball(leg, foot + Vector3(0, -0.01, 0.04), Vector3(0.15, 0.08, 0.2) * bulk, dark)
			legs.append({"path": "Torso/" + leg_name, "side": side, "group": (1 if front else 0) ^ (1 if side > 0 else 0)})
	return _beast_clips(hip, legs)


static func _beast_clips(hip: float, legs: Array) -> Dictionary:
	var rest := {"Torso:position": Vector3(0, hip, 0), "Torso:rotation": Vector3.ZERO, "Torso:scale": Vector3.ONE,
		"Torso/Head:rotation": Vector3.ZERO, "Torso/Head/Jaw:rotation": Vector3.ZERO,
		"Torso/Tail:rotation": Vector3.ZERO, "Torso/Tail/Tip:rotation": Vector3.ZERO}
	for leg in legs:
		rest[leg.path + ":rotation"] = Vector3.ZERO
	var clips := {}
	var idle := _holds(rest)
	idle["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.02, 0.025, 0.0) * sin(TAU * t)
	idle["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(0.05 * sin(TAU * t), 0.22 * sin(TAU * t + 0.8), 0)
	idle["Torso/Head/Jaw:rotation"] = func(t: float) -> Vector3: return Vector3(0.08 + 0.06 * sin(TAU * 2.0 * t), 0, 0)
	idle["Torso/Tail:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.25 * sin(TAU * t), 0)
	idle["Torso/Tail/Tip:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.3 * sin(TAU * t - 0.8), 0)
	clips["idle"] = _clip(2.4, true, idle)
	# Running: legs swinging in diagonal pairs, the body bobbing and pitching, the tail swinging behind.
	var run := _holds(rest)
	for leg in legs:
		var phase := 0.5 * float(leg.group)
		run[leg.path + ":rotation"] = func(t: float) -> Vector3: return Vector3(0.6 * sin(TAU * (t + phase)), 0, 0)
	run["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.03 * absf(cos(TAU * t)), 0)
	run["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(0.05 * sin(TAU * 2.0 * t), 0, 0.03 * sin(TAU * t))
	run["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(-0.05 * sin(TAU * 2.0 * t), 0, 0)
	run["Torso/Tail:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.35 * sin(TAU * t), 0)
	run["Torso/Tail/Tip:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.4 * sin(TAU * t - 1.0), 0)
	clips["run"] = _clip(0.5, true, run, 16)
	var attack := _holds(rest)
	attack["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(-0.35 * _bump(t, 0.16, 0.16) + 0.3 * _bump(t, 0.32, 0.12), 0, 0)
	attack["Torso/Head/Jaw:rotation"] = func(t: float) -> Vector3: return Vector3(0.6 * _bump(t, 0.2, 0.14), 0, 0)
	attack["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.04 * _bump(t, 0.16, 0.14), 0.12 * _bump(t, 0.32, 0.16))
	attack["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(-0.1 * _bump(t, 0.16, 0.14) + 0.12 * _bump(t, 0.32, 0.12), 0, 0)
	attack["Torso/Tail:rotation"] = func(t: float) -> Vector3: return Vector3(0.2 * _bump(t, 0.3, 0.2), 0, 0)
	clips["attack"] = _clip(0.55, false, attack, 22)
	var batter := _holds(rest)
	batter["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.1, -0.14, 0.04) * _bump(t, 0.18, 0.18)
	batter["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(-0.12 * _bump(t, 0.2, 0.2), 0, 0)
	batter["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(-0.3 * _bump(t, 0.2, 0.2), 0, 0)
	clips["batter"] = _clip(0.3, false, batter, 12)
	# Falling: it topples onto its side, its legs stiff, its head and tail limp.
	var death := _holds(rest)
	death["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, lerpf(hip, hip * 0.65, smoothstep(0.2, 0.6, t)), 0)
	death["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, 1.45 * smoothstep(0.1, 0.55, t))
	death["Torso/Head:rotation"] = func(t: float) -> Vector3: return Vector3(0.2 * smoothstep(0.4, 0.8, t), 0, 0.3 * smoothstep(0.4, 0.8, t))
	death["Torso/Head/Jaw:rotation"] = func(t: float) -> Vector3: return Vector3(0.4 * smoothstep(0.4, 0.7, t), 0, 0)
	death["Torso/Tail:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0.3 * smoothstep(0.4, 0.9, t), 0)
	for leg in legs:
		var side: float = leg.side
		death[leg.path + ":rotation"] = func(t: float) -> Vector3: return Vector3(0.3 * smoothstep(0.4, 0.8, t), 0, -side * 0.25 * smoothstep(0.4, 0.8, t))
	clips["death"] = _clip(1.0, false, death, 24)
	return clips


# -- The frog: it hops, its tongue lashes ---------------------------------------------------------------------------------

static func _frog(model: Node3D, k: Dictionary, c: Color) -> Dictionary:
	var hip := 0.3
	var main := _skin(c)
	var dark := _skin(_shade(c, -0.42))
	var pale := _skin(_shade(c, 0.38))
	var torso := _pivot(model, "Torso", Vector3(0, hip, 0))
	_ball(torso, Vector3(0, 0.06, -0.08), Vector3(0.86, 0.6, 0.82), main)
	_ball(torso, Vector3(0, 0.12, 0.24), Vector3(0.82, 0.42, 0.46), main)
	_ball(torso, Vector3(0, -0.06, 0.06), Vector3(0.74, 0.44, 0.7), pale)
	# A wide mouth: a dark line round the front.
	_ball(torso, Vector3(0, 0.05, 0.36), Vector3(0.66, 0.04, 0.24), dark)
	for side in [-1.0, 1.0]:
		_ball(torso, Vector3(side * 0.22, 0.33, 0.24), Vector3(0.24, 0.24, 0.24), main)
		_ball(torso, Vector3(side * 0.22, 0.36, 0.32), Vector3(0.16, 0.16, 0.12), _glow(EYE, 1.8))
		# The big back legs folded at its sides, their feet before them; the small front ones.
		_ball(torso, Vector3(side * 0.38, -0.06, -0.2), Vector3(0.28, 0.32, 0.46), main)
		_ball(torso, Vector3(side * 0.4, 0.04 - hip, 0.02), Vector3(0.22, 0.07, 0.3), dark)
		_limb(torso, Vector3(side * 0.24, -0.08, 0.26), Vector3(side * 0.28, 0.05 - hip, 0.36), 0.1, main)
		_ball(torso, Vector3(side * 0.28, 0.04 - hip, 0.4), Vector3(0.14, 0.06, 0.16), dark)
	if k.get("warts", false):
		for p in [Vector3(-0.2, 0.32, -0.1), Vector3(0.15, 0.34, -0.2), Vector3(0.0, 0.36, -0.02), Vector3(0.25, 0.26, 0.02),
				Vector3(-0.28, 0.24, -0.28), Vector3(0.05, 0.3, -0.34)]:
			_ball(torso, p, Vector3.ONE * 0.1, dark)
	if k.get("sacs", false):
		for side in [-1.0, 1.0]:
			_ball(torso, Vector3(side * 0.36, 0.06, 0.26), Vector3(0.22, 0.2, 0.22), _glow(Color(0.7, 1.0, 0.25), 0.9))
	var tongue := _pivot(torso, "Tongue", Vector3(0, 0.04, 0.36))
	_ball(tongue, Vector3(0, 0, 0.45), Vector3(0.12, 0.08, 0.9), _skin(PINK))
	_ball(tongue, Vector3(0, 0, 0.9), Vector3(0.16, 0.12, 0.16), _skin(PINK))
	var rest := {"Torso:position": Vector3(0, hip, 0), "Torso:rotation": Vector3.ZERO, "Torso:scale": Vector3.ONE,
		"Torso/Tongue:scale": Vector3(1, 1, 0.02)}
	var clips := {}
	var idle := _holds(rest)
	idle["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.03, -0.02, 0.0) * sin(TAU * 2.0 * t)
	clips["idle"] = _clip(2.0, true, idle)
	# A hop: crouch, leap (stretched), land (squashed).
	var run := _holds(rest)
	run["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.38 * sin(PI * t), 0.0)
	run["Torso:scale"] = func(t: float) -> Vector3:
		var air := sin(PI * t)
		var land := _bump(t, 0.0, 0.12) + _bump(t, 1.0, 0.12)
		return Vector3.ONE + Vector3(-0.06, 0.12, 0.08) * air + Vector3(0.12, -0.18, 0.0) * land
	run["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(-0.2 * sin(TAU * t), 0, 0)
	clips["run"] = _clip(0.6, true, run, 16)
	var attack := _holds(rest)
	attack["Torso/Tongue:scale"] = func(t: float) -> Vector3: return Vector3(1, 1, maxf(0.02, _bump(t, 0.24, 0.2)))
	attack["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(0.12 * _bump(t, 0.24, 0.2), 0, 0)
	attack["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.06, -0.06, 0.06) * _bump(t, 0.1, 0.1)
	clips["attack"] = _clip(0.5, false, attack, 20)
	var batter := _holds(rest)
	batter["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.14, -0.2, 0.14) * _bump(t, 0.18, 0.18)
	clips["batter"] = _clip(0.3, false, batter, 12)
	var death := _holds(rest)
	death["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.25 * _bump(t, 0.2, 0.2) + 0.08 * smoothstep(0.3, 0.6, t), 0)
	death["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, PI * 0.95 * smoothstep(0.1, 0.55, t))
	clips["death"] = _clip(0.9, false, death, 20)
	return clips


# -- The worm: a run of segments --------------------------------------------------------------------------------------------

static func _worm(model: Node3D, k: Dictionary, c: Color) -> Dictionary:
	var n := int(k.get("segments", 5))
	var main := _skin(c)
	var dark := _skin(_shade(c, -0.42))
	var pale := _skin(_shade(c, 0.35))
	var torso := _pivot(model, "Torso", Vector3.ZERO)
	var radii: Array = []
	for i in n:
		radii.append(lerpf(0.27, 0.12, pow(float(i) / maxf(1.0, n - 1.0), 1.3)) if i > 0 else 0.25)
	var places: Array = []
	var z := 0.5
	for i in n:
		var r: float = radii[i]
		if i > 0:
			z -= (r + float(radii[i - 1])) * 0.78
		var at := Vector3(0, r * 0.95, z)
		places.append(at)
		var seg := _pivot(torso, "Seg%d" % i, at)
		_ball(seg, Vector3.ZERO, Vector3(2.0 * r, 1.8 * r, 2.2 * r), main)
		_ball(seg, Vector3(0, -r * 0.42, 0), Vector3(1.8 * r, 0.9 * r, 2.0 * r), pale)
		if k.get("bands", false) and i > 0:
			_ring(seg, Vector3.ZERO, Vector3(2.08 * r, 0.6 * r, 2.08 * r), Vector3(PI * 0.5, 0, 0), dark)
		if k.get("spikes", false) and i > 0:
			_cone(seg, Vector3(0, r * 0.8, 0), Vector3(0, 1, -0.4), r * 0.9, r * 0.5, _skin(BONE))
		if k.get("fin", false) and i > 0 and i < n - 1:
			_ball(seg, Vector3(0, r * 1.0, -r * 0.2), Vector3(0.06, r * 1.3, r * 1.8), dark)
		if k.get("crown", false) and i == 1:
			for j in 5:
				var a := TAU * j / 5.0
				_cone(seg, Vector3(sin(a) * r * 0.6, r * 0.7, cos(a) * r * 0.6), Vector3(sin(a) * 0.5, 1, cos(a) * 0.5), r * 0.9,
					r * 0.35, _glow(_shade(c, 0.5), 0.8))
	# The head's face: a sucker, a ring of teeth, or fangs; eyes above.
	var head := torso.get_node("Seg0") as Node3D
	var r0: float = radii[0]
	var mouth := _pivot(head, "Mouth", Vector3(0, -r0 * 0.05, r0 * 0.85))
	match String(k.get("mouth", "teeth")):
		"sucker":
			_ring(mouth, Vector3.ZERO, Vector3(1.3 * r0, 0.7 * r0, 1.3 * r0), Vector3(PI * 0.5, 0, 0), _skin(PINK))
			_ball(mouth, Vector3(0, 0, -0.03), Vector3(0.9 * r0, 0.9 * r0, 0.2 * r0), _skin(Color(0.2, 0.06, 0.08)))
		"fangs":
			_ball(mouth, Vector3(0, 0.02, 0.06), Vector3(1.5 * r0, 1.0 * r0, 1.3 * r0), main)
			for side in [-1.0, 1.0]:
				_cone(mouth, Vector3(side * r0 * 0.3, -r0 * 0.3, r0 * 0.5), Vector3(0, -1, 0.3), r0 * 0.7, r0 * 0.25, _skin(BONE))
		_:
			_ring(mouth, Vector3.ZERO, Vector3(1.6 * r0, 0.8 * r0, 1.6 * r0), Vector3(PI * 0.5, 0, 0), dark)
			_ball(mouth, Vector3(0, 0, -0.04), Vector3(1.05 * r0, 1.05 * r0, 0.2 * r0), _skin(Color(0.25, 0.08, 0.06)))
			for j in 6:
				var a := TAU * j / 6.0
				var p := Vector3(sin(a), cos(a), 0) * r0 * 0.6
				_cone(mouth, p, -p.normalized() + Vector3(0, 0, 0.5), r0 * 0.4, r0 * 0.2, _skin(BONE))
	_eyes(head, int(k.get("eyes", 2)), Vector3(r0, r0 * 0.9, r0 * 1.1), 0.8, Vector3(0, r0 * 0.35, 0))
	var rest := {"Torso:rotation": Vector3.ZERO, "Torso/Seg0/Mouth:scale": Vector3.ONE}
	for i in n:
		rest["Torso/Seg%d:position" % i] = places[i]
		rest["Torso/Seg%d:rotation" % i] = Vector3.ZERO
		rest["Torso/Seg%d:scale" % i] = Vector3.ONE
	var clips := {}
	var idle := _holds(rest)
	for i in n:
		var at: Vector3 = places[i]
		var lag := 0.12 * i
		idle["Torso/Seg%d:position" % i] = func(t: float) -> Vector3: return at + Vector3(0.04 * sin(TAU * (t - lag)), (0.06 if i == 0 else 0.0) * (0.5 + 0.5 * sin(TAU * t)), 0)
		idle["Torso/Seg%d:scale" % i] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.03, 0.03, -0.03) * sin(TAU * (t - lag))
	clips["idle"] = _clip(2.4, true, idle)
	# Slithering: a wave running from the head down the body; the head leads.
	var run := _holds(rest)
	for i in n:
		var at: Vector3 = places[i]
		var lag := 0.16 * i
		var amp := 0.06 + 0.02 * i
		run["Torso/Seg%d:position" % i] = func(t: float) -> Vector3: return at + Vector3(amp * sin(TAU * (t - lag)), 0.02 * absf(sin(TAU * (t - lag))), 0)
		run["Torso/Seg%d:rotation" % i] = func(t: float) -> Vector3: return Vector3(0, 0.35 * cos(TAU * (t - lag)), 0)
	clips["run"] = _clip(0.7, true, run, 16)
	# A strike: the head rears up, its mouth opening wide, and lunges down and forward; the next segment follows.
	var attack := _holds(rest)
	var a0: Vector3 = places[0]
	var a1: Vector3 = places[1]
	attack["Torso/Seg0:position"] = func(t: float) -> Vector3: return a0 + Vector3(0, 0.34 * _bump(t, 0.18, 0.18) + 0.04 * _bump(t, 0.34, 0.1), 0.24 * _bump(t, 0.34, 0.14))
	attack["Torso/Seg0:rotation"] = func(t: float) -> Vector3: return Vector3(-0.7 * _bump(t, 0.18, 0.16) + 0.35 * _bump(t, 0.34, 0.12), 0, 0)
	attack["Torso/Seg1:position"] = func(t: float) -> Vector3: return a1 + Vector3(0, 0.14 * _bump(t, 0.2, 0.2), 0.08 * _bump(t, 0.34, 0.14))
	attack["Torso/Seg0/Mouth:scale"] = func(t: float) -> Vector3: return Vector3.ONE * (1.0 + 0.45 * _bump(t, 0.22, 0.14))
	clips["attack"] = _clip(0.55, false, attack, 22)
	var batter := _holds(rest)
	for i in n:
		var lag := 0.05 * i
		batter["Torso/Seg%d:scale" % i] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.12, -0.16, 0.0) * _bump(t, 0.2 + lag, 0.16)
	clips["batter"] = _clip(0.35, false, batter, 14)
	# Falling: the segments sag flat, the head flops over.
	var death := _holds(rest)
	for i in n:
		var at: Vector3 = places[i]
		var r: float = radii[i]
		death["Torso/Seg%d:position" % i] = func(t: float) -> Vector3: return at + Vector3(0.05 * sin(TAU * 2.0 * t + i) * (1.0 - t), -r * 0.4 * smoothstep(0.2, 0.7, t), 0)
		death["Torso/Seg%d:scale" % i] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.15, -0.4, 0.0) * smoothstep(0.2, 0.7, t)
	death["Torso/Seg0:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, 1.2 * smoothstep(0.2, 0.6, t))
	clips["death"] = _clip(0.9, false, death, 20)
	return clips


# -- The moth: four wings, hovering ----------------------------------------------------------------------------------------

static func _moth(model: Node3D, k: Dictionary, c: Color) -> Dictionary:
	var hover := 0.78
	var main := _skin(c)
	var dark := _skin(_shade(c, -0.45))
	var pale := _skin(_shade(c, 0.4))
	var torso := _pivot(model, "Torso", Vector3(0, hover, 0))
	_ball(torso, Vector3(0, 0, 0.04), Vector3(0.3, 0.3, 0.36), pale)
	_ball(torso, Vector3(0, -0.04, -0.3), Vector3(0.26, 0.24, 0.52), main)
	for i in 2:
		_ring(torso, Vector3(0, -0.04, -0.22 - i * 0.14), Vector3(0.27, 0.12, 0.25), Vector3(PI * 0.5, 0, 0), dark)
	var head := _pivot(torso, "Head", Vector3(0, 0.03, 0.26))
	_ball(head, Vector3.ZERO, Vector3(0.24, 0.22, 0.22), main)
	for side in [-1.0, 1.0]:
		_ball(head, Vector3(side * 0.1, 0.03, 0.06), Vector3.ONE * 0.13, _glow(EYE, 1.8))
		_limb(head, Vector3(side * 0.05, 0.08, 0.06), Vector3(side * 0.16, 0.3, 0.22), 0.03, dark)
		_ball(head, Vector3(side * 0.16, 0.3, 0.22), Vector3(0.1, 0.05, 0.14), dark)
	# The wings: a fore and a hind on each side, each with a glowing eye-spot.
	var spot := _glow(Color(1.0, 0.85, 0.3), 1.0)
	for side in [-1.0, 1.0]:
		var wing := _pivot(torso, "Wing" + ("L" if side < 0 else "R"), Vector3(side * 0.1, 0.08, 0.04))
		_ball(wing, Vector3(side * 0.38, 0.0, 0.1), Vector3(0.72, 0.04, 0.46), main)
		_ball(wing, Vector3(side * 0.3, -0.02, -0.22), Vector3(0.5, 0.04, 0.36), main)
		_ball(wing, Vector3(side * 0.46, 0.022, 0.12), Vector3(0.24, 0.02, 0.18), dark)
		_ball(wing, Vector3(side * 0.46, 0.035, 0.12), Vector3(0.14, 0.02, 0.1), spot)
	var rest := {"Torso:position": Vector3(0, hover, 0), "Torso:rotation": Vector3.ZERO,
		"Torso/WingL:rotation": Vector3(0, 0, -0.25), "Torso/WingR:rotation": Vector3(0, 0, 0.25),
		"Torso/Head:rotation": Vector3.ZERO}
	var clips := {}
	var flap := func(speed: float, lift: float) -> Dictionary:
		var tr := _holds(rest)
		tr["Torso/WingL:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, -(0.25 + 0.65 * sin(TAU * speed * t)))
		tr["Torso/WingR:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, 0.25 + 0.65 * sin(TAU * speed * t))
		tr["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hover + lift * sin(TAU * speed * t - 0.6), 0)
		return tr
	clips["idle"] = _clip(1.0, true, flap.call(2.0, 0.05), 24)
	var run: Dictionary = flap.call(2.0, 0.04)
	run["Torso:rotation"] = func(_t: float) -> Vector3: return Vector3(0.2, 0, 0)
	clips["run"] = _clip(0.5, true, run, 20)
	var attack: Dictionary = flap.call(1.0, 0.0)
	attack["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(-0.45 * _bump(t, 0.18, 0.16) + 0.35 * _bump(t, 0.36, 0.14), 0, 0)
	attack["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hover + 0.1 * _bump(t, 0.18, 0.16), 0.15 * _bump(t, 0.36, 0.14))
	clips["attack"] = _clip(0.5, false, attack, 20)
	var batter: Dictionary = flap.call(1.0, 0.0)
	batter["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(-0.2 * _bump(t, 0.2, 0.2), 0, 0.3 * _bump(t, 0.2, 0.2))
	clips["batter"] = _clip(0.3, false, batter, 12)
	# Falling: its wings fold up and it drops, turning onto its side.
	var death := _holds(rest)
	death["Torso/WingL:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, -lerpf(0.25, 1.3, smoothstep(0.0, 0.4, t)))
	death["Torso/WingR:rotation"] = func(t: float) -> Vector3: return Vector3(0, 0, lerpf(0.25, 1.3, smoothstep(0.0, 0.4, t)))
	death["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, lerpf(hover, 0.16, smoothstep(0.1, 0.6, t)), 0)
	death["Torso:rotation"] = func(t: float) -> Vector3: return Vector3(0.2 * smoothstep(0.1, 0.6, t), 0, 1.2 * smoothstep(0.2, 0.7, t))
	clips["death"] = _clip(0.9, false, death, 20)
	return clips


# -- The blob: round and soft; spore balls, crystals, tentacles, eggs, legs -------------------------------------------------

static func _blob_plan(model: Node3D, k: Dictionary, c: Color) -> Dictionary:
	var hip := 0.42
	var main := _skin(c)
	var dark := _skin(_shade(c, -0.42))
	var pale := _skin(_shade(c, 0.35))
	var legged: bool = k.get("legs", false)
	if legged:
		hip = 0.5
	var torso := _pivot(model, "Torso", Vector3(0, hip, 0))
	_ball(torso, Vector3(0, 0.02, 0), Vector3(0.9, 0.8, 0.9), main)
	_ball(torso, Vector3(0, -0.16, 0.04), Vector3(0.82, 0.44, 0.8), pale)
	# A face: eyes, and a wide dark grin.
	_eyes(torso, int(k.get("eyes", 2)), Vector3(0.45, 0.4, 0.45), 0.62, Vector3(0, 0.06, 0))
	_ball(torso, Vector3(0, -0.12, 0.4), Vector3(0.36, 0.05, 0.12), dark)
	if k.get("spores", 0) > 0:
		var puff := _glow(_shade(c, 0.55), 0.5)
		for i in int(k.spores):
			var a := TAU * i / float(k.spores) + 0.3
			var up := 0.55 + 0.25 * sin(a * 2.0)
			var d := Vector3(sin(a) * (1.0 - up), up, cos(a) * (1.0 - up) - 0.15).normalized()
			_limb(torso, d * 0.36, d * 0.5, 0.05, dark)
			_ball(torso, d * 0.53, Vector3.ONE * 0.16, puff)
	if k.get("crystals", 0) > 0:
		var ice := _glow(ICE, 0.6)
		for i in int(k.crystals):
			var a := TAU * i / float(k.crystals)
			var d := Vector3(sin(a) * 0.7, 0.8 + 0.3 * cos(a * 3.0), cos(a) * 0.7 - 0.2).normalized()
			_cone(torso, d * 0.3, d, 0.32 + 0.08 * sin(a * 2.0), 0.13, ice)
	if k.get("warts", false):
		for p in [Vector3(-0.22, 0.3, -0.1), Vector3(0.2, 0.32, -0.16), Vector3(0.0, 0.38, 0.0), Vector3(0.3, 0.16, 0.12),
				Vector3(-0.3, 0.18, 0.14), Vector3(0.08, 0.28, -0.3)]:
			_ball(torso, p, Vector3.ONE * 0.11, dark)
	if k.get("eggs", 0) > 0:
		var egg := _clear(Color(0.85, 1.0, 0.45), 0.75)
		for i in int(k.eggs):
			var a := TAU * i / float(k.eggs)
			_ball(torso, Vector3(sin(a) * 0.2, 0.36 + 0.04 * cos(a * 2.0), cos(a) * 0.16 - 0.18), Vector3.ONE * 0.17, egg)
	if k.get("crown", false):
		for i in 7:
			var a := TAU * i / 7.0
			_cone(torso, Vector3(sin(a) * 0.16, 0.34, cos(a) * 0.16), Vector3(sin(a) * 0.5, 1, cos(a) * 0.5), 0.24, 0.09,
				_glow(_shade(c, 0.6), 0.9))
	var tents: Array = []
	for i in int(k.get("tentacles", 0)):
		var a := TAU * i / float(k.tentacles) + 0.2
		var root_at := Vector3(sin(a) * 0.36, -0.2, cos(a) * 0.34)
		var tent := _pivot(torso, "Tent%d" % i, root_at)
		var out := Vector3(sin(a), 0, cos(a))
		var p0 := Vector3.ZERO
		var p1 := out * 0.18 + Vector3(0, -0.12, 0)
		var p2 := out * 0.34 + Vector3(0, 0.04 - hip + 0.06, 0)
		_limb(tent, p0, p1, 0.11, main)
		_limb(tent, p1, p2, 0.08, main)
		_ball(tent, p2, Vector3.ONE * 0.08, pale)
		tents.append({"path": "Torso/Tent%d" % i, "angle": a})
	var legs: Array = []
	if legged:
		for i in 3:
			var z: float = [0.22, 0.0, -0.22][i]
			for side in [-1.0, 1.0]:
				var leg_name := "Leg%s%d" % ["L" if side < 0 else "R", i]
				var leg := _pivot(torso, leg_name, Vector3(side * 0.3, -0.12, z))
				var knee := Vector3(side * 0.32, 0.18, z * 0.3)
				var foot := Vector3(side * 0.48, 0.19 - hip, z * 0.8)
				_limb(leg, Vector3.ZERO, knee, 0.1, dark)
				_limb(leg, knee, foot, 0.08, dark)
				legs.append({"path": "Torso/" + leg_name, "side": side, "group": (i + (0 if side < 0 else 1)) % 2})
	var rest := {"Torso:position": Vector3(0, hip, 0), "Torso:rotation": Vector3.ZERO, "Torso:scale": Vector3.ONE}
	for tent in tents:
		rest[tent.path + ":rotation"] = Vector3.ZERO
	for leg in legs:
		rest[leg.path + ":rotation"] = Vector3.ZERO
	var clips := {}
	var sway := func(tr: Dictionary, speed: float, amount: float) -> void:
		for tent in tents:
			var a: float = tent.angle
			tr[tent.path + ":rotation"] = func(t: float) -> Vector3: return Vector3(amount * sin(TAU * speed * t + a), 0, amount * cos(TAU * speed * t + a * 1.3))
	var idle := _holds(rest)
	idle["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.04, -0.05, 0.04) * sin(TAU * t)
	sway.call(idle, 1.0, 0.18)
	clips["idle"] = _clip(1.6, true, idle, 16)
	var run := _holds(rest)
	if legged:
		for leg in legs:
			var side: float = leg.side
			var phase := 0.5 * float(leg.group)
			run[leg.path + ":rotation"] = func(t: float) -> Vector3:
				var a := TAU * (t + phase)
				return Vector3(0, -side * 0.35 * sin(a), side * 0.28 * maxf(0.0, cos(a)))
		run["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.02 * cos(TAU * 2.0 * t), 0)
		run["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.02, -0.02, 0.02) * cos(TAU * 2.0 * t)
		clips["run"] = _clip(0.6, true, run, 16)
	else:
		# A hop: stretched in the air, squashed where it lands.
		run["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip + 0.2 * sin(PI * t), 0)
		run["Torso:scale"] = func(t: float) -> Vector3:
			var land := _bump(t, 0.0, 0.14) + _bump(t, 1.0, 0.14)
			return Vector3.ONE + Vector3(-0.06, 0.1, -0.06) * sin(PI * t) + Vector3(0.14, -0.2, 0.14) * land
		sway.call(run, 2.0, 0.3)
		clips["run"] = _clip(0.5, true, run, 16)
	var attack := _holds(rest)
	attack["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.08, 0.08, -0.12) * _bump(t, 0.14, 0.12) + Vector3(-0.1, -0.1, 0.3) * _bump(t, 0.32, 0.14)
	attack["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hip, 0.14 * _bump(t, 0.32, 0.14))
	for tent in tents:
		attack[tent.path + ":rotation"] = func(t: float) -> Vector3: return Vector3(0.7 * _bump(t, 0.3, 0.16), 0, 0)
	clips["attack"] = _clip(0.5, false, attack, 20)
	var batter := _holds(rest)
	batter["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.16, -0.2, 0.16) * _bump(t, 0.18, 0.18)
	clips["batter"] = _clip(0.3, false, batter, 12)
	# Falling: it goes flat, like a ball with the air let out.
	var death := _holds(rest)
	death["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE.lerp(Vector3(1.35, 0.3, 1.35), smoothstep(0.1, 0.7, t)) + Vector3(0.05, 0.05, 0.05) * sin(TAU * 3.0 * t) * (1.0 - t)
	death["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, lerpf(hip, 0.14, smoothstep(0.1, 0.7, t)), 0)
	clips["death"] = _clip(0.9, false, death, 20)
	return clips


# -- The jellyfish: a glowing bell, hanging tentacles ------------------------------------------------------------------------

static func _jelly(model: Node3D, _k: Dictionary, c: Color) -> Dictionary:
	var hover := 0.62
	var torso := _pivot(model, "Torso", Vector3(0, hover, 0))
	_ball(torso, Vector3(0, 0.08, 0), Vector3(0.84, 0.6, 0.84), _clear(c, 0.72))
	_ball(torso, Vector3(0, 0.04, 0), Vector3(0.34, 0.3, 0.34), _glow(_shade(c, 0.4), 1.2))
	_ring(torso, Vector3(0, -0.16, 0), Vector3(0.8, 0.5, 0.8), Vector3.ZERO, _skin(_shade(c, -0.3)))
	for side in [-1.0, 1.0]:
		_ball(torso, Vector3(side * 0.1, 0.08, 0.17), Vector3.ONE * 0.1, _glow(EYE, 1.8))
	var tents: Array = []
	var soft := _clear(_shade(c, 0.3), 0.8)
	for i in 7:
		var a := TAU * i / 7.0
		var tent := _pivot(torso, "Tent%d" % i, Vector3(sin(a) * 0.26, -0.16, cos(a) * 0.26))
		_limb(tent, Vector3.ZERO, Vector3(0, -0.24, 0.0), 0.06, soft)
		_limb(tent, Vector3(0, -0.22, 0), Vector3(sin(a) * 0.05, -0.48, cos(a) * 0.05), 0.045, soft)
		tents.append({"path": "Torso/Tent%d" % i, "angle": a})
	var rest := {"Torso:position": Vector3(0, hover, 0), "Torso:rotation": Vector3.ZERO, "Torso:scale": Vector3.ONE}
	for tent in tents:
		rest[tent.path + ":rotation"] = Vector3.ZERO
	var pulse := func(tr: Dictionary, beats: float, amount: float, sway: float) -> void:
		tr["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(amount, -amount * 1.3, amount) * sin(TAU * beats * t)
		tr["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, hover + 0.05 * sin(TAU * beats * t - 1.2), 0)
		for tent in tents:
			var a: float = tent.angle
			tr[tent.path + ":rotation"] = func(t: float) -> Vector3: return Vector3(sway * sin(TAU * beats * t + a), 0, sway * cos(TAU * beats * t + a))
	var clips := {}
	var idle := _holds(rest)
	pulse.call(idle, 1.0, 0.06, 0.2)
	clips["idle"] = _clip(1.4, true, idle, 16)
	var run := _holds(rest)
	pulse.call(run, 1.0, 0.09, 0.3)
	run["Torso:rotation"] = func(_t: float) -> Vector3: return Vector3(0.25, 0, 0)
	clips["run"] = _clip(0.8, true, run, 16)
	var attack := _holds(rest)
	attack["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(-0.1, 0.15, -0.1) * _bump(t, 0.15, 0.12) + Vector3(0.12, -0.14, 0.12) * _bump(t, 0.32, 0.12)
	for tent in tents:
		attack[tent.path + ":rotation"] = func(t: float) -> Vector3: return Vector3(-0.7 * _bump(t, 0.3, 0.16), 0, 0)
	clips["attack"] = _clip(0.5, false, attack, 20)
	var batter := _holds(rest)
	batter["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE + Vector3(0.14, -0.18, 0.14) * _bump(t, 0.18, 0.18)
	clips["batter"] = _clip(0.3, false, batter, 12)
	var death := _holds(rest)
	death["Torso:position"] = func(t: float) -> Vector3: return Vector3(0, lerpf(hover, 0.12, smoothstep(0.1, 0.6, t)), 0)
	death["Torso:scale"] = func(t: float) -> Vector3: return Vector3.ONE.lerp(Vector3(1.3, 0.35, 1.3), smoothstep(0.4, 0.8, t))
	for tent in tents:
		var a: float = tent.angle
		death[tent.path + ":rotation"] = func(t: float) -> Vector3: return Vector3(cos(a), 0, -sin(a)) * 1.2 * smoothstep(0.4, 0.8, t)
	clips["death"] = _clip(0.9, false, death, 20)
	return clips


# -- Clips ----------------------------------------------------------------------------------------------------------------

## A clip `length` long: each of `tracks` (a path -> a function of how far through the clip, 0 to 1, giving the value
## there) keyed `samples` times along it -- smoothly between when it loops.
static func _clip(length: float, loop: bool, tracks: Dictionary, samples := 12) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for path: String in tracks:
		var tr := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tr, NodePath(path))
		a.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC if loop else Animation.INTERPOLATION_LINEAR)
		var f: Callable = tracks[path]
		for i in samples + 1:
			var t := float(i) / samples
			a.track_insert_key(tr, t * length, f.call(t))
	return a


## Every path in `rest` held at its value (each clip moves all of them, so none is left where another clip put it).
static func _holds(rest: Dictionary) -> Dictionary:
	var out := {}
	for path in rest:
		out[path] = _hold(rest[path])
	return out


static func _hold(v: Variant) -> Callable:
	return func(_t: float) -> Variant: return v


## 0, rising smoothly to 1 at `at` and back to 0, `width` either side of it.
static func _bump(t: float, at: float, width: float) -> float:
	var x := 1.0 - absf(t - at) / width
	return 0.0 if x <= 0.0 else x * x * (3.0 - 2.0 * x)


# -- Shapes -----------------------------------------------------------------------------------------------------------------

static func _pivot(parent: Node3D, pivot_name: String, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = pivot_name
	p.position = at
	parent.add_child(p)
	return p


## A round shape `size` across each way, its middle at `at`.
static func _ball(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return _shape(parent, _mesh("ball"), Transform3D(Basis.from_scale(size), at), mat)


## A rounded limb from `a` to `b`, `thick` across.
static func _limb(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	return _shape(parent, _mesh("ball"), Transform3D(_along(d) * Basis.from_scale(Vector3(thick, d.length() * 1.2, thick)),
		(a + b) * 0.5), mat)


## A cone standing on `foot`, pointing along `dir`, `length` long and `width` across at its foot.
static func _cone(parent: Node3D, foot: Vector3, dir: Vector3, length: float, width: float, mat: Material) -> MeshInstance3D:
	var u := dir.normalized()
	return _shape(parent, _mesh("cone"), Transform3D(_along(u) * Basis.from_scale(Vector3(width, length, width)),
		foot + u * length * 0.5), mat)


## A ring `size` across (its hole round y), turned by `turn`.
static func _ring(parent: Node3D, at: Vector3, size: Vector3, turn: Vector3, mat: Material) -> MeshInstance3D:
	return _shape(parent, _mesh("ring"), Transform3D(Basis.from_euler(turn) * Basis.from_scale(size), at), mat)


## `count` glowing eyes on the front of a head `radii` across each way (its middle at `centre`), each in a dark socket:
## two side by side, a third above them, more in rows above.
static func _eyes(parent: Node3D, count: int, radii: Vector3, size: float, centre := Vector3.ZERO) -> void:
	var spots: Array
	match count:
		1:
			spots = [Vector2(0, 0.3)]
		2:
			spots = [Vector2(-0.42, 0.25), Vector2(0.42, 0.25)]
		3:
			spots = [Vector2(-0.42, 0.18), Vector2(0.42, 0.18), Vector2(0, 0.6)]
		4:
			spots = [Vector2(-0.45, 0.12), Vector2(0.45, 0.12), Vector2(-0.22, 0.52), Vector2(0.22, 0.52)]
		_:
			spots = [Vector2(-0.5, 0.08), Vector2(0.5, 0.08), Vector2(-0.28, 0.45), Vector2(0.28, 0.45), Vector2(0, 0.72)]
	var eye := _glow(EYE, 2.0)
	var socket := _skin(Color(0.1, 0.08, 0.08))
	var e := minf(radii.x, radii.y) * 0.46 * size * (0.85 if count > 3 else 1.0)
	for s: Vector2 in spots:
		var d := Vector3(s.x, s.y, sqrt(maxf(0.15, 1.0 - s.x * s.x - s.y * s.y)))
		var on := centre + Vector3(d.x * radii.x, d.y * radii.y, d.z * radii.z)
		# Out along the head's own surface there: the socket sunk a little, the eye standing out of it.
		var out := Vector3(d.x / radii.x, d.y / radii.y, d.z / radii.z).normalized()
		_ball(parent, on - out * e * 0.2, Vector3.ONE * e * 1.2, socket)
		_ball(parent, on + out * e * 0.08, Vector3.ONE * e, eye)


static func _shape(parent: Node3D, mesh: Mesh, xf: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi


## A turn taking up (+y) to `dir`.
static func _along(dir: Vector3) -> Basis:
	var u := dir.normalized()
	if u.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, u))


static func _mesh(shape: String) -> Mesh:
	if not _shapes.has(shape):
		match shape:
			"ball":
				var m := SphereMesh.new()
				m.radius = 0.5
				m.height = 1.0
				m.radial_segments = 20
				m.rings = 10
				_shapes[shape] = m
			"cone":
				var m := CylinderMesh.new()
				m.top_radius = 0.0
				m.bottom_radius = 0.5
				m.height = 1.0
				m.radial_segments = 12
				m.rings = 1
				_shapes[shape] = m
			_:
				var m := TorusMesh.new()
				m.inner_radius = 0.36
				m.outer_radius = 0.5
				m.rings = 20
				m.ring_segments = 8
				_shapes[shape] = m
	return _shapes[shape]


# -- Materials --------------------------------------------------------------------------------------------------------------

## Skin of colour `c`, lit as a cartoon is (as our dinosaurs: Creatures._toon).
static func _skin(c: Color) -> StandardMaterial3D:
	var key := "s" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r * TONE, c.g * TONE, c.b * TONE)
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_TOON
		m.roughness = 0.5
		m.metallic_specular = 0.3
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.5
		_mats[key] = m
	return _mats[key]


## Something glowing of its own: eyes, sacs, embers, crystals.
static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var key := "g%s%.2f" % [c.to_html(), energy]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		m.roughness = 0.3
		_mats[key] = m
	return _mats[key]


## See-through and faintly glowing: a jellyfish's bell, eggs.
static func _clear(c: Color, alpha: float) -> StandardMaterial3D:
	var key := "c%s%.2f" % [c.to_html(), alpha]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.35
		m.roughness = 0.2
		m.rim_enabled = true
		m.rim = 0.5
		_mats[key] = m
	return _mats[key]


## What one wears for a moment when struck (or healed): `c`, bright.
static func _flash_mat(c: Color) -> StandardMaterial3D:
	var key := "f" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		_mats[key] = m
	return _mats[key]


static func _shade(c: Color, k: float) -> Color:
	return c.lightened(k) if k > 0.0 else c.darkened(-k)
