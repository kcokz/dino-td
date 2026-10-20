class_name Blocks
## Coloured blocks: the framework's stand-ins for what will be modelled (GAME-DESIGN 14).

static var _mats := {}


## A plain material of one colour, shared by everything of that colour.
static func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.8
		m.metallic_specular = 0.3
		m.rim_enabled = true
		m.rim = 0.1
		m.rim_tint = 0.6
		_mats[key] = m
	return _mats[key]


## A material that glows its colour.
static func glow(c: Color, strength := 1.6) -> StandardMaterial3D:
	var key := "glow%s%.1f" % [c.to_html(), strength]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = strength
		_mats[key] = m
	return _mats[key]


static func box(size: Vector3, c: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(mesh, c, at)


static func cylinder(radius: float, height: float, c: Color, at := Vector3.ZERO, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	return _put(mesh, c, at)


static func ball(radius: float, c: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _put(mesh, c, at)


static func dome(radius: float, c: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius
	mesh.is_hemisphere = true
	mesh.radial_segments = 24
	mesh.rings = 8
	return _put(mesh, c, at)


## A creature as a block: a body of its colour, two eyes on the face that looks along +z, what its gene affixes grow
## on it -- a shell plate, blades, an acid sac, wings, a plasma orb, a stinger, a flame, fins of speed, thick hide, a
## charging horn -- a gold band for each time its nest was made elite, and what marks its kind (an evolved species of
## ours, the titan, or one of theirs: Content.UNITS, Content.ENEMIES). The body has its own material (it flashes when
## hit) and is the root's child, to lunge and hop while the root keeps its place.
static func creature(edge: float, c: Color, theirs := false, affixes: Array = [], kind := "", elite := 0) -> Node3D:
	var root := Node3D.new()
	root.set_meta("edge", edge)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * edge
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	body.material_override = m
	body.position.y = edge * 0.5
	root.add_child(body)
	var eye := Color(1.0, 0.2, 0.12) if theirs else Color(0.06, 0.05, 0.05)
	var k := edge / 0.9
	for side in [-1.0, 1.0]:
		var e := box(Vector3(0.15, 0.2, 0.06) * k, eye, Vector3(side * edge * 0.22, edge * 0.12, edge * 0.5 + 0.02))
		if theirs:
			e.material_override = glow(eye)
		body.add_child(e)
	if theirs:
		# A brow: they come looking for trouble.
		body.add_child(box(Vector3(edge * 0.7, 0.07 * k, 0.07), c.darkened(0.55), Vector3(0, edge * 0.28, edge * 0.5 + 0.03)))
	for a in affixes:
		var ac: Color = Content.AFFIXES[a].color
		match a:
			"shell":
				body.add_child(box(Vector3(edge * 1.05, edge * 0.18, edge * 1.05), ac, Vector3(0, edge * 0.55, 0)))
			"blade":
				for side in [-1.0, 1.0]:
					var b := box(Vector3(0.08, edge * 0.35, edge * 0.6), ac, Vector3(side * edge * 0.55, edge * 0.05, edge * 0.2))
					b.rotation.x = -0.5
					body.add_child(b)
			"acid":
				body.add_child(ball(edge * 0.28, ac, Vector3(0, edge * 0.25, -edge * 0.55)))
			"wings":
				for side in [-1.0, 1.0]:
					var w := box(Vector3(edge * 0.9, 0.05, edge * 0.55), ac, Vector3(side * edge * 0.85, edge * 0.42, -edge * 0.05))
					w.rotation.z = side * 0.35
					body.add_child(w)
			"plasma":
				var orb := ball(edge * 0.22, ac, Vector3(0, edge * 0.72, -edge * 0.1))
				orb.material_override = glow(ac, 2.2)
				body.add_child(orb)
			"poison":
				var sting := box(Vector3(0.08, 0.08, edge * 0.6), ac, Vector3(0, edge * 0.3, -edge * 0.65))
				sting.rotation.x = -0.7
				body.add_child(sting)
				body.add_child(ball(edge * 0.1, ac.darkened(0.3), Vector3(0, edge * 0.12, -edge * 0.5)))
			"flame":
				var fire := cylinder(edge * 0.2, edge * 0.45, ac, Vector3(0, edge * 0.74, edge * 0.15), 0.0)
				fire.material_override = glow(ac, 2.4)
				body.add_child(fire)
			"haste":
				for side in [-1.0, 1.0]:
					var fin := box(Vector3(0.06, edge * 0.4, edge * 0.45), ac, Vector3(side * edge * 0.53, edge * 0.1, -edge * 0.35))
					fin.rotation.x = 0.6
					fin.material_override = glow(ac, 0.9)
					body.add_child(fin)
			"hide":
				for side in [-1.0, 1.0]:
					body.add_child(box(Vector3(edge * 0.12, edge * 0.72, edge * 0.82), ac, Vector3(side * edge * 0.55, -edge * 0.02, 0)))
			"horn":
				var horn := cylinder(edge * 0.14, edge * 0.5, ac, Vector3(0, edge * 0.22, edge * 0.7), 0.0)
				horn.rotation.x = PI * 0.5
				body.add_child(horn)
	for step in elite:
		var band := box(Vector3(edge * 1.07, edge * 0.08, edge * 1.07), Color(1.0, 0.8, 0.25), Vector3(0, edge * (0.36 - step * 0.14), 0))
		band.material_override = glow(Color(1.0, 0.8, 0.25), 0.7)
		body.add_child(band)
	_marks(body, edge, c, kind)
	return root


## What marks a kind: our evolved species (a beak and crest, glowing spikes, a poison haze, cracks of fire), the
## scavenger's sack, the mutant's third eye, and the monsters of each place (spore sacs, a beetle's plate and horn, a
## salamander's tail; a leech's rings and mouth, a moth's wings, a frog's eyes, a toad's poison sacs; fangs and frost,
## ice crystals; a sandworm's teeth, a scorpion's tail and pincers; a crab's claws, a jellyfish's bell, a sea serpent's
## fin; the bosses').
static func _marks(body: MeshInstance3D, edge: float, c: Color, kind: String) -> void:
	match kind:
		"falcon":
			body.add_child(box(Vector3(edge * 0.22, edge * 0.15, edge * 0.32), Color(1.0, 0.8, 0.3), Vector3(0, -edge * 0.05, edge * 0.64)))
			body.add_child(box(Vector3(0.08, edge * 0.32, edge * 0.45), Color(0.85, 0.2, 0.12), Vector3(0, edge * 0.64, 0)))
		"thunder":
			for i in 3:
				var spike := box(Vector3(0.14, edge * 0.28, 0.14), Color(0.55, 0.85, 1.0), Vector3(0, edge * 0.68, -edge * 0.3 + i * edge * 0.3))
				spike.material_override = glow(Color(0.55, 0.85, 1.0), 1.6)
				body.add_child(spike)
		"miasma":
			for side in [-1.0, 1.0]:
				var puff := ball(edge * 0.2, Color(0.6, 0.9, 0.3), Vector3(side * edge * 0.62, edge * 0.3, -edge * 0.15))
				puff.material_override = glow(Color(0.6, 0.9, 0.3), 0.8)
				body.add_child(puff)
		"magma", "boss_lava":
			var hot := Color(1.0, 0.45, 0.1)
			for side in [-1.0, 1.0]:
				var crack := box(Vector3(0.05, edge * 0.75, 0.1), hot, Vector3(side * edge * 0.51, 0, edge * 0.1 * side))
				crack.material_override = glow(hot, 2.0)
				body.add_child(crack)
			var front := box(Vector3(edge * 0.5, 0.06, 0.05), hot, Vector3(0, -edge * 0.2, edge * 0.51))
			front.material_override = glow(hot, 2.0)
			body.add_child(front)
			if kind == "boss_lava":
				body.add_child(box(Vector3(edge * 1.08, edge * 0.2, edge * 1.08), c.darkened(0.4), Vector3(0, edge * 0.55, 0)))
				for side in [-1.0, 1.0]:
					var horn := box(Vector3(0.18, edge * 0.4, 0.18), Color(0.2, 0.15, 0.12), Vector3(side * edge * 0.32, edge * 0.7, edge * 0.3))
					horn.rotation.x = 0.4
					body.add_child(horn)
		"scav":
			# A sack of what it picked up, on its back.
			body.add_child(ball(edge * 0.34, Color(0.58, 0.46, 0.3), Vector3(0, edge * 0.5, -edge * 0.42)))
			body.add_child(box(Vector3(edge * 0.5, 0.06, 0.06), Color(0.35, 0.26, 0.16), Vector3(0, edge * 0.62, -edge * 0.1)))
		"mutant":
			# A third eye, and lumps where it keeps changing.
			var third := ball(edge * 0.12, Color(0.65, 1.0, 0.45), Vector3(0, edge * 0.34, edge * 0.5))
			third.material_override = glow(Color(0.65, 1.0, 0.45), 1.4)
			body.add_child(third)
			for i in 3:
				body.add_child(ball(edge * (0.15 + i * 0.04), c.lightened(0.3), Vector3(edge * (0.48 - i * 0.42),
					edge * (0.48 - i * 0.12), edge * (-0.3 + i * 0.22))))
		"titan":
			body.add_child(box(Vector3(edge * 1.08, edge * 0.22, edge * 1.08), c.darkened(0.4), Vector3(0, edge * 0.55, 0)))
			for side in [-1.0, 1.0]:
				var horn := cylinder(edge * 0.1, edge * 0.5, Color(0.9, 0.86, 0.75), Vector3(side * edge * 0.35, edge * 0.75, edge * 0.2), 0.0)
				horn.rotation.z = -side * 0.4
				body.add_child(horn)
		"spore", "boss_rain":
			var sacs := 3 if kind == "spore" else 7
			for i in sacs:
				var a := TAU * i / sacs
				body.add_child(ball(edge * (0.17 if kind == "spore" else 0.13), c.lightened(0.35),
					Vector3(cos(a) * edge * 0.28, edge * 0.55, sin(a) * edge * 0.28)))
		"beetle":
			body.add_child(box(Vector3(edge * 1.1, edge * 0.25, edge * 1.1), c.darkened(0.45), Vector3(0, edge * 0.55, -0.05)))
			var horn := box(Vector3(0.12, 0.12, edge * 0.45), Color(0.15, 0.1, 0.08), Vector3(0, edge * 0.22, edge * 0.66))
			horn.rotation.x = 0.4
			body.add_child(horn)
		"salamander":
			body.add_child(box(Vector3(edge * 0.32, edge * 0.26, edge * 0.95), c.darkened(0.2), Vector3(0, -edge * 0.24, -edge * 0.92)))
			for i in 2:
				var spot := box(Vector3(0.12, 0.05, 0.12), Color(1.0, 0.85, 0.3), Vector3(-0.15 + i * 0.3, edge * 0.51, -edge * 0.1))
				spot.material_override = glow(Color(1.0, 0.85, 0.3), 1.4)
				body.add_child(spot)
		"leech", "boss_bog":
			# A ringed body and a round sucking mouth; the swamp's mother carries her young on her back.
			for i in 3:
				body.add_child(box(Vector3(edge * 1.04, edge * 1.04, edge * 0.07), c.darkened(0.35), Vector3(0, 0, -edge * 0.3 + i * edge * 0.25)))
			var mouth := cylinder(edge * 0.18, 0.05, Color(0.3, 0.08, 0.08), Vector3(0, -edge * 0.2, edge * 0.52))
			mouth.rotation.x = PI * 0.5
			body.add_child(mouth)
			if kind == "boss_bog":
				for i in 3:
					body.add_child(ball(edge * 0.14, c.lightened(0.25), Vector3(-edge * 0.3 + i * edge * 0.3, edge * 0.56, -edge * 0.1)))
		"moth":
			# Broad dusty wings, a pale eye on each, and feelers.
			for side in [-1.0, 1.0]:
				var w := box(Vector3(edge * 1.1, 0.04, edge * 0.9), c.lightened(0.15), Vector3(side * edge * 0.95, edge * 0.35, -edge * 0.05))
				w.rotation.z = side * 0.3
				var spot := box(Vector3(edge * 0.3, 0.02, edge * 0.3), Color(0.95, 0.9, 0.6), Vector3(side * edge * 0.12, 0.03, 0))
				spot.material_override = glow(Color(0.95, 0.9, 0.6), 0.8)
				w.add_child(spot)
				body.add_child(w)
				var feeler := box(Vector3(0.04, 0.04, edge * 0.5), c.darkened(0.4), Vector3(side * edge * 0.15, edge * 0.55, edge * 0.55))
				feeler.rotation.x = -0.6
				body.add_child(feeler)
		"mini_bog":
			# A frog's eyes up on top, a wide mouth.
			for side in [-1.0, 1.0]:
				body.add_child(ball(edge * 0.17, c.lightened(0.2), Vector3(side * edge * 0.28, edge * 0.55, edge * 0.25)))
				var pupil := ball(edge * 0.08, Color(1.0, 0.7, 0.1), Vector3(side * edge * 0.28, edge * 0.6, edge * 0.38))
				pupil.material_override = glow(Color(1.0, 0.7, 0.1), 1.2)
				body.add_child(pupil)
			body.add_child(box(Vector3(edge * 0.8, 0.05, 0.05), Color(0.15, 0.1, 0.08), Vector3(0, -edge * 0.12, edge * 0.51)))
		"mini_bog2":
			# Poison sacs on its sides and back -- they burst when it falls.
			for i in 4:
				var sac := ball(edge * 0.18, Color(0.7, 0.95, 0.2), Vector3((-1.0 if i % 2 == 0 else 1.0) * edge * 0.5,
					edge * (0.1 + 0.25 * (i / 2)), edge * (0.1 - 0.3 * (i / 2))))
				sac.material_override = glow(Color(0.7, 0.95, 0.2), 0.9)
				body.add_child(sac)
		"frostfang", "mini_ice2":
			# Long white fangs, a ridge of frost along the back -- and a shaggy coat on the big one.
			for side in [-1.0, 1.0]:
				body.add_child(box(Vector3(0.07, edge * 0.32, 0.07), Color(0.95, 0.97, 1.0), Vector3(side * edge * 0.18, -edge * 0.38, edge * 0.5)))
			for i in 3:
				var spike := box(Vector3(0.1, edge * 0.25, 0.1), Color(0.8, 0.92, 1.0), Vector3(0, edge * 0.6, edge * (0.25 - i * 0.28)))
				spike.material_override = glow(Color(0.8, 0.92, 1.0), 0.7)
				body.add_child(spike)
			if kind == "mini_ice2":
				for side in [-1.0, 1.0]:
					body.add_child(box(Vector3(edge * 0.14, edge * 0.85, edge * 0.95), Color(0.95, 0.95, 0.97), Vector3(side * edge * 0.55, -edge * 0.05, 0)))
		"shard", "mini_ice", "boss_ice":
			# Crystals of ice growing out of it -- a crown of them on the queen; a plate of ice on the armoured one.
			var ice := Color(0.7, 0.9, 1.0)
			if kind == "mini_ice":
				body.add_child(box(Vector3(edge * 1.08, edge * 0.2, edge * 1.08), Color(0.6, 0.72, 0.85), Vector3(0, edge * 0.5, 0)))
			var n: int = {"shard": 3, "mini_ice": 4, "boss_ice": 7}[kind]
			for i in n:
				var a := TAU * i / n
				var crystal := box(Vector3(0.12, edge * 0.35, 0.12), ice, Vector3(cos(a) * edge * 0.3, edge * 0.62, sin(a) * edge * 0.3))
				crystal.rotation = Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)
				crystal.material_override = glow(ice, 1.2)
				body.add_child(crystal)
		"sandworm", "mini_sand":
			# A ringed body, a round mouth ringed with teeth.
			for i in 3:
				body.add_child(box(Vector3(edge * 1.04, edge * 1.04, edge * 0.07), c.darkened(0.25), Vector3(0, 0, -edge * 0.35 + i * edge * 0.25)))
			var maw := cylinder(edge * 0.2, 0.05, Color(0.3, 0.12, 0.1), Vector3(0, -edge * 0.2, edge * 0.52))
			maw.rotation.x = PI * 0.5
			body.add_child(maw)
			for i in 6:
				var a := TAU * i / 6
				body.add_child(box(Vector3(0.05, 0.05, edge * 0.12), Color(0.95, 0.92, 0.82),
					Vector3(cos(a) * edge * 0.15, -edge * 0.2 + sin(a) * edge * 0.15, edge * 0.56)))
		"scorpion", "mini_sand2":
			# A tail curled up over its back with a glowing sting, and two pincers.
			var tail := box(Vector3(edge * 0.18, edge * 0.7, edge * 0.18), c.darkened(0.15), Vector3(0, edge * 0.6, -edge * 0.45))
			tail.rotation.x = 0.5
			body.add_child(tail)
			var sting := box(Vector3(edge * 0.14, edge * 0.14, edge * 0.3), Color(0.9, 0.3, 0.6), Vector3(0, edge * 0.98, -edge * 0.2))
			sting.material_override = glow(Color(0.9, 0.3, 0.6), 1.3)
			body.add_child(sting)
			for side in [-1.0, 1.0]:
				body.add_child(box(Vector3(edge * 0.22, edge * 0.2, edge * 0.42), c.darkened(0.1), Vector3(side * edge * 0.45, -edge * 0.25, edge * 0.62)))
		"boss_sand":
			# A crust of sandstone, a mane of spines.
			body.add_child(box(Vector3(edge * 1.08, edge * 0.2, edge * 1.08), c.darkened(0.35), Vector3(0, edge * 0.55, 0)))
			for i in 5:
				var spine := box(Vector3(0.14, edge * 0.35, 0.14), Color(0.9, 0.78, 0.5), Vector3(-edge * 0.4 + i * edge * 0.2, edge * 0.78, -edge * 0.2))
				spine.rotation.x = -0.3
				body.add_child(spine)
		"crab", "mini_sea":
			# Two big claws in front, a shell flat and wide.
			body.add_child(box(Vector3(edge * 1.3, edge * 0.14, edge * 1.1), c.darkened(0.2), Vector3(0, edge * 0.5, -edge * 0.05)))
			for side in [-1.0, 1.0]:
				var claw := box(Vector3(edge * 0.32, edge * 0.28, edge * 0.45), c.lightened(0.1), Vector3(side * edge * 0.62, -edge * 0.1, edge * 0.55))
				claw.rotation.y = -side * 0.35
				body.add_child(claw)
		"jelly", "boss_sea":
			# A glowing bell on top, tentacles hanging round it.
			var bell := dome(edge * 0.62, c.lightened(0.3), Vector3(0, edge * 0.5, 0))
			bell.material_override = glow(c.lightened(0.3), 0.8)
			body.add_child(bell)
			var arms := 6 if kind == "jelly" else 10
			for i in arms:
				var a := TAU * i / arms
				body.add_child(box(Vector3(0.05, edge * 0.6, 0.05), c.lightened(0.15), Vector3(cos(a) * edge * 0.55, -edge * 0.15, sin(a) * edge * 0.55)))
		"mini_sea2":
			# A fin all along its back, gills on its neck.
			body.add_child(box(Vector3(0.06, edge * 0.4, edge * 1.0), Color(0.3, 0.75, 0.7), Vector3(0, edge * 0.7, 0)))
			for side in [-1.0, 1.0]:
				for i in 3:
					body.add_child(box(Vector3(0.04, edge * 0.2, 0.05), c.darkened(0.4), Vector3(side * edge * 0.51, edge * 0.05, edge * (0.3 - i * 0.1))))


## The body of a creature made by creature().
static func body_of(n: Node3D) -> MeshInstance3D:
	return n.get_node("Body") as MeshInstance3D


static func _put(mesh: Mesh, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = at
	return mi
