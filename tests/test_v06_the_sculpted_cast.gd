# res://tests/test_v06_the_sculpted_cast.gd
# The player, 2026-09-30: "恐龙目前模型做的都粗糙，我需要它们更精致". The first map's cast is drawn anew round the
# bones it was animated on (tools/triassic_bodies.py, tools/sculpt.py): a smooth body lofted from the snout to
# the tail, coloured by its vertices -- a dark back, pale belly, each species' marks -- eyes, teeth and claws of
# its own, and every clip the game plays still there.
#
# Everything expected is read from the models and Config.
extends "res://tests/test_base.gd"

## The species the valley's raids and nights are made of, and the herds on its walls.
const CAST := ["coelophysis", "coelophysis_alpha", "hesperosuchus", "phytosaur", "postosuchus"]

var config_node: Object = null
var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _art(key: String) -> Node3D:
	var art: Node3D = VisualLibrary.make(key)
	_cleanup_nodes.append(art)
	return art

func _meshes(art: Node) -> Array:
	return art.find_children("*", "MeshInstance3D", true, false)

func test_01_each_reads_the_colours_it_is_painted_in() -> void:
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var meshes: Array = _meshes(art)
		assert_gt(meshes.size(), 0, "%s has its model" % species)
		var colours: Dictionary = {}
		var dark: int = 0
		for m in meshes:
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
				assert_true(mat != null and mat.vertex_color_use_as_albedo,
					"%s's %s reads its vertex colours (VISUALS material \"skin\")" % [species, String(mat.resource_name) if mat else "?"])
				var cols: PackedColorArray = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
				for k in range(0, cols.size(), 7):
					var c: Color = cols[k]
					colours[Color(snappedf(c.r, 0.05), snappedf(c.g, 0.05), snappedf(c.b, 0.05))] = true
					if c.get_luminance() < 0.2:
						dark += 1
		# Painted, not one flat colour: a dark back, pale belly, marks.
		assert_gt(colours.size(), 20, "%s is painted in many shades (%d)" % [species, colours.size()])
		assert_gt(dark, 0, "%s has its dark back and marks" % species)

func test_02_each_has_two_eyes_of_their_own() -> void:
	# The eyes a material of their own ("Eye"), which the night's eye-shine lights (ProwlerDino), in a mesh
	# of their own -- one material reading the same colours as the skin's came out of the exporter white.
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var sides: Array = [0, 0]
		for m in _meshes(art):
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var mat: Material = mi.mesh.surface_get_material(i)
				if mat == null or not String(mat.resource_name).begins_with("Eye"):
					continue
				var verts: PackedVector3Array = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
				var mid: float = 0.0
				for v in verts:
					mid += v.x
				mid /= maxf(1.0, float(verts.size()))
				for v in verts:
					sides[0 if v.x < mid else 1] += 1
				var cols: PackedColorArray = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
				var pupil: bool = false
				for c in cols:
					if c.get_luminance() < 0.05:
						pupil = true
				assert_true(pupil, "%s's eyes have a pupil" % species)
		assert_gt(sides[0], 20, "%s has a left eye" % species)
		assert_gt(sides[1], 20, "%s has a right eye" % species)

func test_03_every_clip_is_still_there() -> void:
	var wanted: Array = []
	for state in config_node.ANIMATIONS["dino"]:
		var clip: String = String(config_node.ANIMATIONS["dino"][state])
		if clip != "" and not wanted.has(clip) and clip != "sleep":
			wanted.append(clip)
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var players: Array = art.find_children("*", "AnimationPlayer", true, false)
		assert_gt(players.size(), 0, "%s is animated" % species)
		if players.is_empty():
			continue
		var player := players[0] as AnimationPlayer
		for clip in wanted:
			assert_true(player.has_animation(clip), "%s plays %s" % [species, clip])

func test_04_they_are_drawn_round_not_faceted() -> void:
	# The stretched Quaternius animals were a few thousand flat facets; these are smooth, and many times that.
	for species in CAST:
		var art: Node3D = _art("dino/" + species)
		var verts: int = 0
		for m in _meshes(art):
			var mi := m as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				verts += (mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		assert_gt(verts, 6000, "%s is drawn in some detail (%d vertices)" % [species, verts])
