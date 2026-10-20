class_name Blocks
## Coloured blocks: the framework's stand-ins for what will be modelled (GAME-DESIGN 14).

static var _mats := {}


## A plain material of one colour, shared by everything of that colour.
static func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.82
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
## on it -- a shell plate, blades, an acid sac, wings, a plasma orb, a stinger, a flame -- and what marks its kind (an
## evolved species of ours, or one of theirs: Content.UNITS, Content.ENEMIES). The body has its own material (it
## flashes when hit) and is the root's child, to lunge and hop while the root keeps its place.
static func creature(edge: float, c: Color, theirs := false, affixes: Array = [], kind := "") -> Node3D:
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
	_marks(body, edge, c, kind)
	return root


## What marks a kind: our evolved species (a beak and crest, glowing spikes, a poison haze, cracks of fire) and the
## monsters of each place (spore sacs, a beetle's plate and horn, a salamander's tail, the bosses').
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


## The body of a creature made by creature().
static func body_of(n: Node3D) -> MeshInstance3D:
	return n.get_node("Body") as MeshInstance3D


static func _put(mesh: Mesh, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = at
	return mi
