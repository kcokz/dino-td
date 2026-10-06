# res://scripts/fx/ModelLibrary.gd
class_name ModelLibrary

## The things in the world, built as meshes in code.
##
## VisualLibrary answers "what does this look like" and hands back whatever Config
## names. Until now every answer was a primitive: a box for the Hero, a box for a
## dinosaur, a cylinder for a tree. This is where those become shapes that read as what
## they are.
##
## Built rather than modelled because the alternative was hand-painting realistic
## textures, which is the one part of this the project cannot do. Code can do
## proportion, silhouette and colour, and at a fixed camera forty degrees up and never
## closer, PROPORTION AND SILHOUETTE ARE ALMOST ALL OF IT. Nobody will ever see a
## raptor's pores. They will absolutely see that its neck is too short.
##
## Every model is built to the size Config declares for its key, and nothing here
## produces collision -- the collider comes from the declared size, as always, so art
## can never quietly change what a thing blocks.

# ==============================================================================
# The dispatcher
# ==============================================================================

## A model by name, or null when the name is not one of these -- VisualLibrary then
## falls back to its primitives, so an unknown name is a plain box rather than nothing.
static func build(name: String, size: Vector3, colour: Color, variant: String) -> Node3D:
	match name:
		"ship_wreck":
			return ship_wreck(size)
		"cycad":
			return cycad(size, variant == "depleted")
		"outcrop":
			return outcrop(size, variant == "depleted")
		"pool":
			return pool(size)
		"nest_mound":
			return nest_mound(size)
		"raptor":
			return raptor(size, colour)
		"hero":
			return hero(size)
	return null

# ==============================================================================
# The wreck: the thing the whole game is defending
# ==============================================================================

## A modern vessel, down hard and a long time ago.
##
## This is the story object -- the only evidence the Hero is from anywhere else, and the
## thing that ends the game if the dinosaurs get it -- so it is worth more triangles than
## anything else on the map. It has to read at a glance as MANUFACTURED: straight lines,
## flat panels and a hull that is a surface of revolution, because every other thing in
## frame is organic and lumpy. That contrast is what sells "this does not belong here"
## far more than any amount of detail would.
##
## Down at an angle with the nose dug in, the spine broken behind the cabin, one strut
## sheared off and lying where it fell, and scorch running back from the belly.
static func ship_wreck(size: Vector3) -> Node3D:
	var root := Node3D.new()
	var hull_col := Color(0.62, 0.63, 0.65)
	var shade_col := Color(0.34, 0.35, 0.38)
	var scorch := Color(0.13, 0.12, 0.12)
	var rust := Color(0.45, 0.28, 0.18)

	var length: float = size.z * 1.9
	var radius: float = size.x * 0.52

	# The main hull, nose buried and tail up. Lofted rings, so it is a real fuselage
	# rather than a capsule: the taper is what makes it read as built.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 9
	var prev: Array = []
	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		# Nose low and dug in, tail lifted -- a crash, not a parking job.
		var along: float = (t - 0.35) * length
		# Nose down in the dirt, tail up, but only a little: the first version lifted the
		# tail almost a full body height and the hull came out a blade on its end.
		var lift: float = pow(t, 1.7) * size.y * 0.42 + size.y * 0.16
		var r: float = radius * (0.3 + 1.05 * sin(clampf(t, 0.0, 1.0) * PI * 0.88))
		var centre := Vector3(0.0, lift, along)
		var row: Array = []
		for j in range(9):
			var a: float = TAU * float(j) / 9.0
			row.append(centre + Vector3(cos(a) * r, sin(a) * r * 0.78, 0.0))
		if i > 0:
			for j in range(9):
				var k: int = (j + 1) % 9
				# Belly scorched, flanks panelled, one band of rust along the seam.
				var down: float = -sin(TAU * float(j) / 9.0)
				var col: Color = hull_col
				if down > 0.45:
					col = scorch.lerp(rust, 0.35)
				elif j % 3 == 0:
					col = shade_col
				# The spine snaps two thirds back: a gap in the loft, not a decal.
				if i == 7:
					col = scorch
				_tri(st, prev[j], prev[k], row[k], col, col, col)
				_tri(st, prev[j], row[k], row[j], col, col, col)
		prev = row
	st.generate_normals()
	root.add_child(_mesh_node(st.commit()))

	# The cabin block: flat panels and a dark window band, which is the single clearest
	# "somebody built this" signal in the silhouette.
	root.add_child(_box(Vector3(radius * 1.5, radius * 1.1, radius * 1.9),
		Vector3(0.0, size.y * 0.52, length * 0.12), hull_col))
	root.add_child(_box(Vector3(radius * 1.56, radius * 0.3, radius * 1.1),
		Vector3(0.0, size.y * 0.66, length * 0.16), Color(0.08, 0.11, 0.14)))

	# A sheared strut, still attached and bent; and its twin, lying in the dirt where it
	# tore off. The loose one is what makes the crash read as violent.
	var strut := _box(Vector3(radius * 0.28, radius * 0.24, length * 0.5),
		Vector3(radius * 1.25, size.y * 0.30, length * 0.05), shade_col)
	strut.rotation = Vector3(0.0, 0.0, -0.42)
	root.add_child(strut)
	var torn := _box(Vector3(radius * 0.26, radius * 0.2, length * 0.42),
		Vector3(-radius * 2.3, radius * 0.16, -length * 0.22), shade_col.lerp(rust, 0.4))
	torn.rotation = Vector3(0.1, 0.55, 1.35)
	root.add_child(torn)

	# Debris thrown clear, and a plate half-buried nose-first.
	root.add_child(_box(Vector3(radius * 0.5, radius * 0.1, radius * 0.6),
		Vector3(radius * 1.9, radius * 0.06, -length * 0.34), rust))
	var plate := _box(Vector3(radius * 0.8, radius * 0.08, radius * 0.9),
		Vector3(-radius * 1.1, radius * 0.22, length * 0.36), hull_col.lerp(scorch, 0.3))
	plate.rotation = Vector3(-0.9, 0.3, 0.0)
	root.add_child(plate)
	return root

# ==============================================================================
# Plants, rock and water
# ==============================================================================

## A cycad: a stout scaly trunk under a crown of fronds.
##
## The tree of this period, and a very different silhouette from the lollipop that says
## "modern forest" -- no branching, all the mass in a rosette at the top. `cut` is the
## harvested state: the crown gone, a splintered stump left.
static func cycad(size: Vector3, cut: bool) -> Node3D:
	var root := Node3D.new()
	var bark := Color(0.29, 0.24, 0.17)
	var bark_dark := Color(0.19, 0.16, 0.12)
	var frond := Color(0.25, 0.40, 0.17)
	var frond_old := Color(0.36, 0.42, 0.19)

	var height: float = size.y * (0.3 if cut else 0.58)
	var radius: float = size.x * 0.3

	# Trunk: rings of overlapping scars, which is what a cycad trunk actually is.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 7
	var prev: Array = []
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var r: float = radius * (1.15 - 0.3 * t) * (1.0 + 0.09 * sin(t * 18.0))
		var lean := Vector3(sin(t * 2.1) * radius * 0.25, height * t, cos(t * 1.7) * radius * 0.2)
		var row: Array = []
		for j in range(8):
			var a: float = TAU * float(j) / 8.0
			row.append(lean + Vector3(cos(a) * r, 0.0, sin(a) * r))
		if i > 0:
			for j in range(8):
				var k: int = (j + 1) % 8
				var col: Color = bark if (i % 2 == 0) else bark_dark
				_tri(st, prev[j], prev[k], row[k], col, col, col)
				_tri(st, prev[j], row[k], row[j], col, col, col)
		prev = row
	st.generate_normals()
	root.add_child(_mesh_node(st.commit()))

	if cut:
		# Splintered top: a few shards, so a harvested tree reads as cut rather than as
		# a short tree.
		for i in range(5):
			var a: float = TAU * float(i) / 5.0
			var shard := _box(Vector3(radius * 0.22, radius * 0.9, radius * 0.22),
				Vector3(cos(a) * radius * 0.5, height + radius * 0.35, sin(a) * radius * 0.5), bark.lerp(frond_old, 0.25))
			shard.rotation = Vector3(cos(a) * 0.4, a, sin(a) * 0.4)
			root.add_child(shard)
		return root

	# A wide crown: on a cycad nearly all the mass is up here, and it is the whole read
	# from above. Sized off the trunk height rather than off the box, so a short tree has
	# a proportionate head instead of a hat.
	var crown := GroundCover.fern(height * 0.85, 11, frond_old, frond)
	var crown_node := _mesh_node(crown)
	crown_node.position = Vector3(sin(2.1) * radius * 0.25, height, cos(1.7) * radius * 0.2)
	root.add_child(crown_node)
	return root

## A rock outcrop: several boulders shouldered together rather than one lump, because a
## single stone at this size reads as a prop and a cluster reads as bedrock coming
## through. `cut` is the quarried state -- lower, broken open, pale rubble around it.
static func outcrop(size: Vector3, cut: bool) -> Node3D:
	var root := Node3D.new()
	var stone_col := Color(0.44, 0.43, 0.41)
	var pale := Color(0.58, 0.56, 0.52)
	var big: float = size.x * (0.22 if cut else 0.36)

	var lumps: Array = [
		[Vector3(0.0, 0.0, 0.0), 1.0],
		[Vector3(size.x * 0.24, -size.y * 0.06, size.z * 0.18), 0.66],
		[Vector3(-size.x * 0.26, -size.y * 0.08, size.z * 0.1), 0.58],
		[Vector3(size.x * 0.06, -size.y * 0.1, -size.z * 0.26), 0.5],
	]
	for i in range(lumps.size()):
		var at: Vector3 = lumps[i][0]
		var scale: float = float(lumps[i][1])
		var col: Color = stone_col if not cut else stone_col.lerp(pale, 0.35 * float(i))
		var node := _mesh_node(GroundCover.stone(big * scale, 3300 + i * 17, col))
		node.position = at + Vector3(0.0, big * scale * 0.55, 0.0)
		root.add_child(node)

	if cut:
		for i in range(7):
			var a: float = TAU * float(i) / 7.0
			var chip := _mesh_node(GroundCover.stone(big * 0.2, 5100 + i, pale))
			chip.position = Vector3(cos(a) * size.x * 0.42, big * 0.1, sin(a) * size.z * 0.42)
			root.add_child(chip)
	return root

## A water pool: a dark dish sunk into the ground with a wet rim. Barely any height, so
## it is nearly all silhouette from above.
static func pool(size: Vector3) -> Node3D:
	var root := Node3D.new()
	var water := Color(0.13, 0.24, 0.29)
	var mud := Color(0.24, 0.21, 0.17)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 18
	for j in range(segs):
		var a0: float = TAU * float(j) / float(segs)
		var a1: float = TAU * float(j + 1) / float(segs)
		var wobble0: float = 1.0 + sin(a0 * 3.0) * 0.12
		var wobble1: float = 1.0 + sin(a1 * 3.0) * 0.12
		var r: float = size.x * 0.5
		# Water surface, wound so it faces UP. The first version wound the other way and
		# the pool showed as a bare outline from above -- the only thing visible was the
		# edge of a disc pointing at the ground.
		var w0 := Vector3(cos(a0) * r * wobble0 * 0.86, 0.03, sin(a0) * r * wobble0 * 0.86)
		var w1 := Vector3(cos(a1) * r * wobble1 * 0.86, 0.03, sin(a1) * r * wobble1 * 0.86)
		_tri(st, Vector3(0.0, 0.03, 0.0), w1, w0, water, water, water)
		# And a mud rim around it, so the water sits in something.
		var m0 := Vector3(cos(a0) * r * wobble0, -0.02, sin(a0) * r * wobble0)
		var m1 := Vector3(cos(a1) * r * wobble1, -0.02, sin(a1) * r * wobble1)
		_tri(st, w0, w1, m1, water.lerp(mud, 0.6), water.lerp(mud, 0.6), mud)
		_tri(st, w0, m1, m0, water.lerp(mud, 0.6), mud, mud)
	st.generate_normals()
	var node := _mesh_node(st.commit())
	var mat := node.material_override as StandardMaterial3D
	mat.roughness = 0.18          # the one wet thing on the map
	mat.metallic = 0.1
	root.add_child(node)
	return root

# ==============================================================================
# Creatures and the nest
# ==============================================================================

## The nest: a dug mound with a dark mouth and a clutch of eggs.
##
## Earth rather than architecture. It is the thing the raid pours out of, so the mouth
## has to be legible from above -- a dark opening facing the map is the whole read.
static func nest_mound(size: Vector3) -> Node3D:
	var root := Node3D.new()
	var earth := Color(0.26, 0.20, 0.15)
	var earth_dark := Color(0.15, 0.12, 0.09)
	var shell := Color(0.72, 0.68, 0.56)

	var mound := _mesh_node(GroundCover.stone(size.x * 0.52, 8801, earth))
	mound.scale = Vector3(1.0, 0.72, 1.0)
	mound.position = Vector3(0.0, size.y * 0.3, 0.0)
	root.add_child(mound)

	# The mouth: a dark recess, not a painted square.
	var mouth := _box(Vector3(size.x * 0.36, size.y * 0.42, size.z * 0.3),
		Vector3(0.0, size.y * 0.21, size.z * 0.34), earth_dark.lerp(Color.BLACK, 0.6))
	root.add_child(mouth)
	root.add_child(_box(Vector3(size.x * 0.52, size.y * 0.12, size.z * 0.18),
		Vector3(0.0, size.y * 0.44, size.z * 0.3), earth_dark))

	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + 0.6
		var egg := _mesh_node(GroundCover.stone(size.x * 0.1, 9100 + i, shell))
		egg.scale = Vector3(0.85, 1.35, 0.85)
		egg.position = Vector3(cos(a) * size.x * 0.3, size.y * 0.12, sin(a) * size.z * 0.3 - size.z * 0.1)
		root.add_child(egg)
	return root

## A theropod: tail, body, neck, head, two legs.
##
## Everything is in the balance -- a long tail held level behind a body tipped forward
## over the hips, counterweighted by a neck carried in an S. Get that and it reads as a
## predator at any size. Miss it and no amount of scales will help.
static func raptor(size: Vector3, colour: Color) -> Node3D:
	var root := Node3D.new()
	var hide: Color = colour
	var belly: Color = colour.lerp(Color(0.86, 0.80, 0.62), 0.55)
	var claw := Color(0.12, 0.11, 0.10)

	var body_len: float = size.z * 1.5
	var hip: float = size.y * 0.55

	# Spine: tail tip, hips, shoulders, neck, head. Lofted as one piece so it flows.
	var spine: Array = [
		Vector3(0.0, hip * 0.72, -body_len * 0.62),
		Vector3(0.0, hip * 0.86, -body_len * 0.3),
		Vector3(0.0, hip, 0.0),
		Vector3(0.0, hip * 1.04, body_len * 0.2),
		Vector3(0.0, hip * 1.22, body_len * 0.34),
		Vector3(0.0, hip * 1.16, body_len * 0.46),
	]
	var radii: Array = [size.x * 0.05, size.x * 0.16, size.x * 0.29, size.x * 0.2, size.x * 0.11, size.x * 0.13]
	root.add_child(_mesh_node(_loft(spine, radii, hide, belly)))

	# Head: a wedge, and a jaw under it. A blunt box would make it a lizard.
	var head := _box(Vector3(size.x * 0.2, size.y * 0.17, size.z * 0.4),
		Vector3(0.0, hip * 1.16, body_len * 0.55), hide)
	head.rotation = Vector3(-0.15, 0.0, 0.0)
	root.add_child(head)
	root.add_child(_box(Vector3(size.x * 0.16, size.y * 0.07, size.z * 0.34),
		Vector3(0.0, hip * 1.06, body_len * 0.56), belly))

	# Legs: thigh back, shin forward, foot flat. The zig-zag is the whole silhouette.
	for side in [-1.0, 1.0]:
		var thigh := _box(Vector3(size.x * 0.13, size.y * 0.34, size.z * 0.18),
			Vector3(side * size.x * 0.24, hip * 0.66, -size.z * 0.04), hide)
		thigh.rotation = Vector3(0.38, 0.0, 0.0)
		root.add_child(thigh)
		var shin := _box(Vector3(size.x * 0.09, size.y * 0.36, size.z * 0.12),
			Vector3(side * size.x * 0.24, hip * 0.32, size.z * 0.12), hide.lerp(belly, 0.3))
		shin.rotation = Vector3(-0.35, 0.0, 0.0)
		root.add_child(shin)
		root.add_child(_box(Vector3(size.x * 0.11, size.y * 0.05, size.z * 0.26),
			Vector3(side * size.x * 0.24, size.y * 0.03, size.z * 0.24), claw))
		# Arms, small and held in -- the detail that says theropod and not lizard.
		var arm := _box(Vector3(size.x * 0.06, size.y * 0.16, size.z * 0.07),
			Vector3(side * size.x * 0.2, hip * 1.0, size.z * 0.2), hide)
		arm.rotation = Vector3(0.7, 0.0, 0.0)
		root.add_child(arm)
	return root

## The Hero: a person, standing. Not a detailed one -- at this distance he is a
## silhouette with a head and shoulders, and what matters is that he reads as upright
## and human next to things that are neither.
static func hero(size: Vector3) -> Node3D:
	var root := Node3D.new()
	var cloth := Color(0.30, 0.42, 0.46)
	var skin := Color(0.66, 0.50, 0.38)
	var pack := Color(0.36, 0.28, 0.18)

	root.add_child(_box(Vector3(size.x * 0.52, size.y * 0.3, size.x * 0.34),
		Vector3(0.0, size.y * 0.62, 0.0), cloth))
	root.add_child(_box(Vector3(size.x * 0.44, size.y * 0.1, size.x * 0.3),
		Vector3(0.0, size.y * 0.79, 0.0), cloth.lerp(skin, 0.3)))
	root.add_child(_box(Vector3(size.x * 0.26, size.y * 0.16, size.x * 0.24),
		Vector3(0.0, size.y * 0.9, 0.0), skin))
	# A pack on his back: the one shape that says this person arrived carrying things.
	root.add_child(_box(Vector3(size.x * 0.38, size.y * 0.22, size.x * 0.18),
		Vector3(0.0, size.y * 0.64, -size.x * 0.26), pack))
	for side in [-1.0, 1.0]:
		root.add_child(_box(Vector3(size.x * 0.14, size.y * 0.28, size.x * 0.16),
			Vector3(side * size.x * 0.33, size.y * 0.6, 0.0), skin))
		root.add_child(_box(Vector3(size.x * 0.18, size.y * 0.46, size.x * 0.2),
			Vector3(side * size.x * 0.14, size.y * 0.23, 0.0), cloth.lerp(Color.BLACK, 0.25)))
	return root

# ==============================================================================
# Plumbing
# ==============================================================================

## Lofts a tube along `points` with `radii`, shading from `top` down to `under`.
static func _loft(points: Array, radii: Array, top: Color, under: Color) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 8
	var prev: Array = []
	for i in range(points.size()):
		var centre: Vector3 = points[i]
		var r: float = float(radii[i])
		var row: Array = []
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			row.append(centre + Vector3(cos(a) * r, sin(a) * r, 0.0))
		if i > 0:
			for j in range(segs):
				var k: int = (j + 1) % segs
				# Lighter underneath, which is how nearly every animal is coloured and
				# what stops a single-colour body reading as a tube.
				var down: float = clampf(-sin(TAU * float(j) / float(segs)), 0.0, 1.0)
				var col: Color = top.lerp(under, down)
				_tri(st, prev[j], prev[k], row[k], col, col, col)
				_tri(st, prev[j], row[k], row[j], col, col, col)
		prev = row
	st.generate_normals()
	return st.commit()

static func _box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: Vector3 = size * 0.5
	var corners: Array = [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces: Array = [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	# A touch of shading per face, so a box has form under flat light instead of reading
	# as one silhouette-less blob.
	var shades: Array = [0.88, 0.8, 0.72, 0.95, 1.06, 0.62]
	for f in range(faces.size()):
		var q: Array = faces[f]
		var s: float = float(shades[f])
		var col := Color(colour.r * s, colour.g * s, colour.b * s, 1.0)
		_tri(st, corners[q[0]], corners[q[1]], corners[q[2]], col, col, col)
		_tri(st, corners[q[0]], corners[q[2]], corners[q[3]], col, col, col)
	st.generate_normals()
	var node := _mesh_node(st.commit())
	node.position = at
	return node

static func _mesh_node(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = GroundCover.cover_material()
	return node

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)
