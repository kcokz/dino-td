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


## A creature as a block: a body of its colour, two eyes on the face that looks along +z, and what its gene affixes
## grow on it -- a shell plate, blades, an acid sac, wings, a plasma orb. The body has its own material (it flashes
## when hit) and is the root's child, to lunge and hop while the root keeps its place.
static func creature(edge: float, c: Color, theirs := false, affixes: Array = []) -> Node3D:
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
	return root


## The body of a creature made by creature().
static func body_of(n: Node3D) -> MeshInstance3D:
	return n.get_node("Body") as MeshInstance3D


static func _put(mesh: Mesh, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c)
	mi.position = at
	return mi
