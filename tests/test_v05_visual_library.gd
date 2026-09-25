# res://tests/test_v05_visual_library.gd
# v0.5, first code prerequisite: the code stops caring what things look like.
#
# Until now every entity built its own body out of primitives inside
# `_ensure_components()`. That meant five different files to open when a model
# arrived, and -- worse -- five sets of naked numbers that could contradict what
# Config declared. `Config.DINOS.big_theropod.size` said 1.6 metres and had said so
# since v0.2; the code drew and collided it at 0.8, and nobody could tell, because
# nothing read the number.
#
# Now `Config.VISUALS` says where the art is and `VisualLibrary` hands it back, fitted
# to the size the thing declares. Two invariants are what this suite is really for:
#
#   1. **One size, used twice.** The collider and the body are both built from the
#      declared size. Art is never measured to produce collision. That is what stops
#      art from quietly growing wider than the thing that blocks a raptor -- the class
#      of bug this project has spent three versions fixing.
#   2. **A bought model drops in.** Assets arrive at arbitrary scale with arbitrary
#      origins. Fitting them is done once, here, not per model.
extends "res://tests/test_base.gd"

var config_node: Object = null
var game_state_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")
		game_state_node = tree.root.get_node_or_null("GameState")

func before_each() -> void:
	if game_state_node != null and game_state_node.has_method("reset_game"):
		game_state_node.reset_game()
	unlock_all()

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _spawn(script_path: String, pos: Vector3 = Vector3.ZERO) -> Node:
	var n = load(script_path).new()
	_cleanup_nodes.append(n)
	tree.root.add_child(n)
	n.position = pos
	return n

func _keep(n: Node) -> Node:
	_cleanup_nodes.append(n)
	return n

func _meshes(node: Node) -> Array:
	var out: Array = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		out.append(child)
	return out

func _collider_size(node: Node) -> Vector3:
	for child in node.find_children("*", "CollisionShape3D", true, false):
		var col := child as CollisionShape3D
		if col == null or col.shape == null:
			continue
		if col.shape is BoxShape3D:
			return (col.shape as BoxShape3D).size
		if col.shape is CylinderShape3D:
			var cyl := col.shape as CylinderShape3D
			return Vector3(cyl.radius * 2.0, cyl.height, cyl.radius * 2.0)
	return Vector3.ZERO

# ==============================================================================
# 1. The table itself
# ==============================================================================

func test_01_every_visual_is_fully_declared() -> void:
	assert_gt(config_node.VISUALS.size(), 0, "There is a visuals table")
	# The primitives, plus every model ModelLibrary knows how to build.
	var known_placeholders: Array = ["box", "cylinder", "cone", "spikes",
		"ship_wreck", "cycad", "outcrop", "pool", "nest_mound", "raptor", "hero"]
	for key in config_node.VISUALS:
		var entry: Dictionary = config_node.VISUALS[key]
		assert_true(entry.has("scene"), "%s says where its art is (or that there is none)" % key)
		assert_true(entry.has("anchor"), "%s says how it sits on the ground" % key)
		assert_has(known_placeholders, String(entry.get("placeholder", "")),
			"%s stands in with a primitive this library can actually build" % key)
		assert_has(["feet", "center"], String(entry["anchor"]),
			"%s anchors somewhere meaningful" % key)

func test_02_every_visual_resolves_to_a_real_size() -> void:
	# The size is NOT in the visuals table on purpose -- it comes from wherever the
	# thing declares its own dimensions, so there is only ever one place to change it.
	# This asserts that resolution actually finds something for every key.
	for key in config_node.VISUALS:
		var size: Vector3 = config_node.get_visual_size(String(key))
		assert_gt(size.x, 0.0, "%s has a real width" % key)
		assert_gt(size.y, 0.0, "%s has a real height" % key)
		assert_gt(size.z, 0.0, "%s has a real depth" % key)

func test_03_a_size_is_declared_once_not_copied_into_the_visuals_table() -> void:
	# If the table carried sizes too, the two copies would drift. Spot-check that the
	# resolver is reading the real homes rather than a duplicate.
	var hero: Vector3 = config_node.get_visual_size("hero")
	assert_almost_eq(hero.x, float(config_node.HERO["width"]), 0.001, "The Hero's width is the Hero's width")
	assert_almost_eq(hero.y, float(config_node.HERO["height"]), 0.001, "And his height is his height")

	var stake: Vector3 = config_node.get_visual_size("building/wall")
	assert_almost_eq(stake.x, config_node.get_building_footprint("wall"), 0.001, "A building's width is its footprint")
	assert_almost_eq(stake.y, config_node.get_building_height("wall"), 0.001, "And its height is its height")

	var raptor: Vector3 = config_node.get_visual_size("dino/raptor")
	assert_almost_eq(raptor.y, float(config_node.DINOS["raptor"]["size"].y), 0.001, "A dinosaur's size is its own")

	for key in config_node.VISUALS:
		assert_false(config_node.VISUALS[key].has("size"),
			"%s must not carry a second copy of its size" % key)

func test_04_every_visual_can_actually_be_built() -> void:
	for key in config_node.VISUALS:
		var body: Node3D = VisualLibrary.make(String(key))
		_keep(body)
		assert_eq(body.name, StringName("Body"), "%s comes back in a body holder" % key)
		assert_gt(_meshes(body).size(), 0, "%s is drawn as something" % key)

# ==============================================================================
# 2. Placeholders are built to measure
# ==============================================================================

func test_05_a_placeholder_is_exactly_the_declared_size() -> void:
	# Built to measure rather than fitted, so this is an equality and not a bound.
	# Only the plain primitives: a real model is built to fit INSIDE its declared size,
	# not to fill it exactly -- a raptor that stretched to fill its box would be wrong.
	#
	# Asked of the fallback directly. Every key has art now, and the placeholder is what a
	# key falls back to when its art is missing; the tower's box is the last plain
	# primitive any key declares.
	for key in ["building/tower"]:
		var body := Node3D.new()
		VisualLibrary._build_placeholder(body, key, "")
		_keep(body)
		tree.root.add_child(body)
		var want: Vector3 = config_node.get_visual_size(key)
		var got: AABB = VisualLibrary.visual_bounds(body)
		assert_almost_eq(got.size.x, want.x, 0.01, "%s is drawn as wide as declared" % key)
		assert_almost_eq(got.size.y, want.y, 0.01, "%s is drawn as tall as declared" % key)
		assert_almost_eq(got.position.y, 0.0, 0.01, "%s stands on the ground, not in it" % key)

func test_06_the_big_theropod_is_finally_big() -> void:
	# The bug this seam existed to make impossible: Config declared 1.6 metres from
	# v0.2 onward and the code drew 0.8, because the declared number was never read.
	var small: Vector3 = config_node.get_visual_size("dino/raptor")
	var large: Vector3 = config_node.get_visual_size("dino/big_theropod")
	assert_gt(large.y, small.y, "Config says the big one is bigger")

	var raptor = _spawn("res://scripts/entities/Dino.gd", Vector3(20.0, 0.0, 20.0))
	raptor.setup("raptor")
	var theropod = _spawn("res://scripts/entities/Dino.gd", Vector3(40.0, 0.0, 40.0))
	theropod.setup("big_theropod")
	await wait_frames(1)

	assert_almost_eq(_collider_size(raptor).y, small.y, 0.01, "And the raptor collides at its own size")
	assert_almost_eq(_collider_size(theropod).y, large.y, 0.01, "And the big one at its own")
	assert_gt(_collider_size(theropod).y, _collider_size(raptor).y,
		"So in play, the big one really is the bigger thing")

func test_07_the_collider_comes_from_the_declared_size_for_everything() -> void:
	# Invariant 1, stated once per kind of entity. This is what keeps art honest: it
	# holds whether a key is drawn by a placeholder or by a model.
	var hero = _spawn("res://scripts/entities/Hero.gd", Vector3(60.0, 0.0, 60.0))
	await wait_frames(1)
	var hero_size: Vector3 = config_node.get_visual_size("hero")
	assert_almost_eq(_collider_size(hero).x, hero_size.x, 0.01, "The Hero collides at his declared width")
	assert_almost_eq(_collider_size(hero).y, hero_size.y, 0.01, "And his declared height")

	var nest = _spawn("res://scripts/entities/Nest.gd", Vector3(80.0, 0.0, 80.0))
	await wait_frames(1)
	var nest_size: Vector3 = config_node.get_visual_size("nest")
	assert_almost_eq(_collider_size(nest).y, nest_size.y, 0.01, "The nest collides at its declared height")

	var tree_node = load("res://scripts/entities/ResourceNode.gd").new("wood", Vector2i(9, 9))
	_keep(tree_node)
	tree.root.add_child(tree_node)
	await wait_frames(1)
	var wood_size: Vector3 = config_node.get_visual_size("node/wood")
	assert_almost_eq(_collider_size(tree_node).y, wood_size.y, 0.01, "And a tree at its declared height")
	assert_gt(wood_size.y, hero_size.y, "Which is taller than the Hero, so it reads as a tree")

# ==============================================================================
# 3. The promise that makes buying art possible
# ==============================================================================

## A stand-in for a bought model: a mesh at the wrong scale, in the wrong place, with
## a transform of its own on the root. All three are normal in real asset files.
func _fake_asset(mesh_size: Vector3, offset: Vector3, root_scale: float) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = mesh_size
	mi.mesh = box
	mi.position = offset
	root.add_child(mi)
	root.scale = Vector3.ONE * root_scale
	_keep(root)
	return root

func test_08_a_model_at_the_wrong_scale_and_origin_is_fitted() -> void:
	# Authored ten times too big, a long way off the origin, and with a stray scale on
	# the root -- the three things that make dropping in a bought model a fight.
	var art := _fake_asset(Vector3(10.0, 20.0, 10.0), Vector3(37.0, 5.0, -12.0), 3.0)
	var holder := Node3D.new()
	_keep(holder)
	tree.root.add_child(holder)
	holder.add_child(art)

	var want := Vector3(2.0, 4.0, 2.0)
	VisualLibrary.fit(art, want, "feet")

	var got: AABB = VisualLibrary.visual_bounds(holder)
	assert_almost_eq(got.size.y, want.y, 0.01, "It comes out the declared height")
	assert_almost_eq(got.position.y, 0.0, 0.01, "Standing on the ground rather than floating or sunk")
	assert_almost_eq(got.position.x + got.size.x * 0.5, 0.0, 0.01, "Centred over its own origin")
	assert_almost_eq(got.position.z + got.size.z * 0.5, 0.0, 0.01, "On both horizontal axes")

func test_09_fitting_never_squashes() -> void:
	# One uniform factor, never three. A model stretched to fill a box it was not drawn
	# for looks worse than one that is slightly the wrong size, so the declared size is
	# a bound: the model fits inside it, keeping its proportions.
	var art := _fake_asset(Vector3(4.0, 1.0, 4.0), Vector3.ZERO, 1.0)
	var holder := Node3D.new()
	_keep(holder)
	tree.root.add_child(holder)
	holder.add_child(art)

	VisualLibrary.fit(art, Vector3(2.0, 2.0, 2.0), "feet")
	assert_almost_eq(art.scale.x, art.scale.y, 0.0001, "Scaled the same on every axis")
	assert_almost_eq(art.scale.y, art.scale.z, 0.0001, "On all three")

	var got: AABB = VisualLibrary.visual_bounds(holder)
	assert_lte(got.size.x, 2.0 + 0.01, "And it fits inside the declared box")
	assert_lte(got.size.y, 2.0 + 0.01, "On every axis")
	assert_almost_eq(got.size.x / got.size.y, 4.0, 0.01, "With its proportions intact")

func test_10_center_anchored_art_sits_half_buried() -> void:
	# What a boulder wants, and getting it wrong is why bought props float or sink.
	var art := _fake_asset(Vector3(2.0, 2.0, 2.0), Vector3(11.0, 11.0, 11.0), 1.0)
	var holder := Node3D.new()
	_keep(holder)
	tree.root.add_child(holder)
	holder.add_child(art)

	VisualLibrary.fit(art, Vector3(2.0, 2.0, 2.0), "center")
	var got: AABB = VisualLibrary.visual_bounds(holder)
	assert_almost_eq(got.position.y + got.size.y * 0.5, 0.0, 0.01, "Its middle is on the ground")
	assert_lt(got.position.y, 0.0, "So half of it is below")

func test_11_art_that_cannot_be_measured_is_left_alone() -> void:
	# An empty scene, or one with nothing visible in it. Fitting must not divide by zero
	# and must not silently move something it could not measure.
	var empty := Node3D.new()
	_keep(empty)
	empty.position = Vector3(1.0, 2.0, 3.0)
	VisualLibrary.fit(empty, Vector3(2.0, 2.0, 2.0), "feet")
	assert_almost_eq(empty.position.y, 2.0, 0.001, "Untouched rather than snapped to nowhere")
	assert_almost_eq(empty.scale.x, 1.0, 0.001, "And unscaled")

# ==============================================================================
# 4. The migration state, and the seam the fence still needs
# ==============================================================================

func test_12_a_visual_never_comes_back_empty() -> void:
	# Two ways a visual can silently vanish: a declared path that does not resolve, and
	# a key nobody declared at all. Both must fall back to a placeholder, because an
	# invisible entity is far harder to diagnose than an obviously wrong one.
	#
	# The loop below asserts nothing while every scene is still "" -- which is why the
	# unconditional checks are here too. A test that quietly checks nothing is worse
	# than no test, and the runner now fails one that ends with no assertions at all.
	for key in config_node.VISUALS:
		var declared: String = String(config_node.VISUALS[key].get("scene", ""))
		if declared != "":
			assert_true(ResourceLoader.exists(declared),
				"%s points at art that actually exists (%s)" % [key, declared])

	var unknown: Node3D = VisualLibrary.make("no/such/thing")
	_keep(unknown)
	assert_gt(_meshes(unknown).size(), 0, "An undeclared key still draws something")
	assert_eq(VisualLibrary.declared_placeholder("no/such/thing"), "box",
		"Falling back to the plain block rather than to nothing")
	assert_false(VisualLibrary.has_art("no/such/thing"), "And it does not claim to have art")

func test_13_a_stake_is_one_cone_through_every_route() -> void:
	# No visual in this game depends on its neighbours any more. Whichever way the body
	# is asked for, and whatever is passed as a variant, the answer is one cone.
	var direct: Node3D = VisualLibrary.make("building/wall")
	_keep(direct)
	assert_eq(_meshes(direct).size(), 1, "One cone")

	# A variant is still meaningful for other things (a cut-out tree), so it has to be
	# harmless here rather than absent -- passing one must not resurrect an arrangement.
	var with_variant: Node3D = VisualLibrary.make("building/wall", "x")
	_keep(with_variant)
	assert_eq(_meshes(with_variant).size(), 1, "A variant does not bring back a second cone")

	var through_building: Node3D = Building.make_body("wall")
	_keep(through_building)
	assert_eq(_meshes(through_building).size(), 1, "And asking through Building gives the same body")

func test_14_a_depleted_node_is_asked_for_as_a_variant() -> void:
	# Today both variants resolve to the same placeholder and only the colour differs.
	# The point is that the seam exists: when the art lands, a cut-out tree can be a
	# different model rather than a grey one (AGENT-TASKS.md task 3).
	var node = load("res://scripts/entities/ResourceNode.gd").new("wood", Vector2i(7, 7))
	_keep(node)
	tree.root.add_child(node)
	await wait_frames(1)

	# What "cut out" looks like is now a DIFFERENT MODEL -- a stump with splinters where
	# the tree was -- rather than the same cylinder painted grey and squashed. So the
	# thing to assert is that the geometry changed, not that a colour did: a colour test
	# would pass just as happily if the variant had never been asked for.
	var standing_mesh: Mesh = null
	for mi in _meshes(node):
		if (mi as MeshInstance3D).mesh != null:
			standing_mesh = (mi as MeshInstance3D).mesh
			break
	var standing_box: AABB = VisualLibrary.visual_bounds(node.find_child("Body", false, false))

	node.harvest(node.max_capacity)
	await wait_frames(1)

	assert_true(node.is_depleted, "It has been cut out")
	assert_gt(_meshes(node).size(), 0, "And is still drawn")
	var cut_box: AABB = VisualLibrary.visual_bounds(node.find_child("Body", false, false))
	assert_lt(cut_box.size.y, standing_box.size.y,
		"A stump is shorter than the tree it came from")
	# A DIFFERENT MESH, not a different number of them. While the art was built from
	# primitives the stump happened to have fewer pieces than the tree, and counting them
	# stood in for "a different model". With real art each is one mesh -- the tree fern and
	# its stump from tools/generate_flora.py -- so what has to differ is the mesh itself.
	var cut_mesh: Mesh = null
	for mi in _meshes(node):
		if (mi as MeshInstance3D).mesh != null:
			cut_mesh = (mi as MeshInstance3D).mesh
			break
	assert_not_null(cut_mesh, "The stump has a mesh")
	assert_ne(cut_mesh, standing_mesh,
		"And it is a different one, so the variant really was asked for")

# ==============================================================================
# 5. Read from disk once
# ==============================================================================

func test_15_a_model_is_read_from_disk_once() -> void:
	# The engine keeps a loaded resource only while something holds it, and nothing held a
	# model's scene once its instance was made: every dinosaur spawned read its model from
	# disk again -- 20 ms on the drive this project lives on, more than a frame, for a file
	# already in memory -- and every level built read them all.
	var path: String = VisualLibrary.declared_scene("dino/raptor")
	assert_true(ResourceLoader.exists(path), "The raptor has a model to read")
	var body: Node3D = VisualLibrary.make("dino/raptor")
	assert_true(VisualLibrary.has_art("dino/raptor"), "And is drawn with it")
	body.free()
	# No raptor anywhere now.
	assert_true(ResourceLoader.has_cached(path), "Its model is still in memory for the next one")
