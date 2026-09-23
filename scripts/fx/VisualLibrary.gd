# res://scripts/fx/VisualLibrary.gd
class_name VisualLibrary

## The one place that answers "what does this thing look like?", so that no entity
## has geometry in it any more.
##
## Before this, every entity built its own body out of primitives inside
## `_ensure_components()` -- a box for the Hero, a box for a dinosaur, a cylinder for
## a tree, a box for the nest. Each of those was a place that would have to be opened
## and rewritten when a model arrived, and each carried naked numbers that contradicted
## what Config declared. `Config.DINOS.big_theropod.size` said 1.6 metres and had said
## so for versions; the code drew it at 0.8 and nobody could see the difference,
## because the number was never read.
##
## Two jobs here, and the second is the one that makes buying art possible:
##
##   1. Hand back the art Config declares for a key, or a placeholder primitive while
##      there is no art. A model arriving is one line of Config -- no logic moves.
##   2. FIT that art to the size Config declares, whatever scale and origin the file
##      happens to use.
##
## Job 2 is the point. Bought models arrive at arbitrary scale with arbitrary origins:
## one centred, the next with its feet at zero, the next authored in centimetres. Doing
## that reconciliation once, here, is the difference between dropping a model in and
## fighting every model. It also keeps the promise the rest of this codebase keeps
## being bitten by: the size Config declares is the size that collides AND the size you
## see, so art can never quietly grow wider than the thing that stops a raptor.
##
## What this deliberately does NOT do is produce collision. Collision is gameplay -- it
## decides who can walk where and what a bite can reach -- so it is built from the same
## declared size, by the entity, and never from the art. Art that disagrees with its
## collider is the bug this project has spent three versions fixing.

# ==============================================================================
# The public surface
# ==============================================================================

## The visible body for `key`, as a node the caller parents wherever it likes.
##
## `variant` is passed through to the placeholder for keys whose shape depends on
## something: a fence's arrangement ("x" / "z" / "both"), a resource node's state
## ("full" / "depleted"). Art scenes ignore it until there is art with variants.
static func make(key: String, variant: String = "") -> Node3D:
	var holder := Node3D.new()
	holder.name = "Body"

	var scene_path: String = declared_scene(key)
	# A variant with art of its own -- a felled tree's stump. Fitted with the FULL art's
	# factor rather than to the box on its own: it is the stump of that tree, and a
	# sixty-centimetre stump fitted to a tree-sized box would be stretched to a tree.
	var variant_path: String = declared_variant_scene(key, variant)
	if variant_path != "" and ResourceLoader.exists(variant_path) and scene_path != "" 			and ResourceLoader.exists(scene_path):
		var full_packed = load(scene_path)
		var var_packed = load(variant_path)
		if full_packed is PackedScene and var_packed is PackedScene:
			var full: Node = (full_packed as PackedScene).instantiate()
			var factor: float = fit_factor(full as Node3D, declared_size(key), declared_fit(key)) if full is Node3D else 1.0
			full.free()
			var piece: Node = (var_packed as PackedScene).instantiate()
			if piece is Node3D:
				holder.add_child(piece)
				place(piece as Node3D, factor, declared_anchor(key))
				_dress(piece, key)
				return holder
			piece.free()

	if scene_path != "" and ResourceLoader.exists(scene_path):
		var packed = load(scene_path)
		if packed is PackedScene:
			var art: Node = packed.instantiate()
			if art is Node3D:
				holder.add_child(art)
				fit(art as Node3D, declared_size(key), declared_anchor(key), declared_fit(key))
				_dress(art, key)
				return holder
			# A scene that is not 3D is a mistake worth seeing rather than hiding, but
			# not worth crashing the game over: fall through to the placeholder.
			art.free()

	_build_placeholder(holder, key, variant)
	return holder

## Whether `key` is being drawn by real art rather than by a placeholder. The build
## preview and the tests ask this so neither has to guess.
static func has_art(key: String) -> bool:
	var path: String = declared_scene(key)
	return path != "" and ResourceLoader.exists(path)

## Scales and shifts `art` so that it occupies exactly `size` metres and sits on the
## ground the way `anchor` says.
##
## One uniform scale factor, never three: a non-uniform fit would squash a bought
## model to fit a box it was not drawn for, which looks worse than a model that is
## slightly the wrong size. The factor is chosen so the model fits INSIDE the declared
## box on every axis -- so a declared size is a bound rather than a stretch target.
static func fit(art: Node3D, size: Vector3, anchor: String = "feet", mode: String = "box") -> void:
	var factor: float = fit_factor(art, size, mode)
	if factor <= 0.0:
		return    # nothing measurable; leave the author's own transform alone
	place(art, factor, anchor)

## The uniform scale that fits `art` inside `size`, or 0 when it has nothing to measure.
##
## `mode` "height" matches the height alone. For a rigged character whose rest pose is
## not how it stands -- a T-pose, arms straight out, as wide as it is tall -- the box is
## the wrong thing to fit, and fitting it shrank the Hero to half his height. The height
## of a T-pose is the height of the person standing in it.
static func fit_factor(art: Node3D, size: Vector3, mode: String = "box") -> float:
	var bounds: AABB = visual_bounds(art)
	if bounds.size.x <= 0.0001 or bounds.size.y <= 0.0001 or bounds.size.z <= 0.0001:
		return 0.0
	var factor: float = minf(size.x / bounds.size.x, minf(size.y / bounds.size.y, size.z / bounds.size.z))
	if mode == "height":
		factor = size.y / bounds.size.y
	if factor <= 0.0 or is_inf(factor) or is_nan(factor):
		return 0.0
	return factor

## Scales `art` by `factor` and stands it on the origin by `anchor`.
static func place(art: Node3D, factor: float, anchor: String = "feet") -> void:
	var bounds: AABB = visual_bounds(art)
	if factor <= 0.0:
		return
	art.scale = Vector3.ONE * factor

	# Where the scaled model actually sits, so it can be pushed back to the origin.
	# `visual_bounds` deliberately excludes the node's own transform, so the bounds
	# measured above are pre-scale and scaling them here is the whole correction.
	var offset: Vector3 = bounds.position * factor
	var extent: Vector3 = bounds.size * factor
	var centre: Vector3 = offset + extent * 0.5
	if anchor == "center":
		art.position = -centre
	else:
		# Centred horizontally, standing on the ground vertically.
		art.position = Vector3(-centre.x, -offset.y, -centre.z)

## The bounding box of everything visible under `node`, in `node`'s own space and
## ignoring its own transform, so it can be measured before being placed.
static func visual_bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var vis := child as VisualInstance3D
		if vis == null:
			continue
		var box: AABB = vis.get_aabb()
		# Up to `node`'s space, but without `node`'s own transform: the caller is about
		# to set that transform, so including it would measure the previous fit.
		var t: Transform3D = Transform3D.IDENTITY
		if node.is_inside_tree() and vis.is_inside_tree():
			t = node.global_transform.affine_inverse() * vis.global_transform
		else:
			var curr: Node = vis
			while curr != null and curr != node:
				if curr is Node3D:
					t = (curr as Node3D).transform * t
				curr = curr.get_parent()
		box = t * box
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out

# ==============================================================================
# What Config declares
# ==============================================================================

## Path to the art for `key`, or "" while there is none.
static func declared_scene(key: String) -> String:
	var entry: Dictionary = _entry(key)
	return String(entry.get("scene", ""))

## Puts the material Config names for `key` on every mesh of its art.
##
## THE FLORA IS COLOURED BY ITS VERTICES, and a GLB brought in as a scene keeps the
## material the importer gave it -- which does not use vertex colour as albedo. So the
## tree fern that is the choppable wood node stood white in the middle of a green forest
## of the very same model, because the forest is drawn through MultiMesh with
## GroundCover.flora_material and the node was not. Declared per key rather than applied
## to everything: the hero, the wreck and the dinosaurs bring textured materials of
## their own that must be left alone.
static func _dress(art: Node, key: String) -> void:
	var which: String = String(_entry(key).get("material", ""))
	var mat: StandardMaterial3D = null
	match which:
		"flora":
			mat = GroundCover.flora_material()      # plants: backlit, two-sided
		"vertex":
			mat = GroundCover.cover_material()      # props: vertex-coloured, matte
		_:
			return
	# ONE MATERIAL PER PIECE OF ART, never shared: a blueprint fades by changing its own
	# material's alpha (Building._update_visuals_progress), and a shared one would fade
	# every stake on the map at once. That fade also only works on material_override at
	# all -- an imported model without one never went translucent as a blueprint.
	for mi in art.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	if art is MeshInstance3D:
		(art as MeshInstance3D).material_override = mat

## Path to the art `key` wears in `variant` -- "depleted", say -- or "" when that variant
## has none of its own and simply wears the main art.
static func declared_variant_scene(key: String, variant: String) -> String:
	if variant == "":
		return ""
	var entry: Dictionary = _entry(key)
	return String(entry.get("scene_" + variant, ""))

## How the art is fitted to its declared size: "box" (inside it on every axis, the
## default) or "height" (see fit_factor).
static func declared_fit(key: String) -> String:
	return String(_entry(key).get("fit", "box"))

## "feet" puts the model's lowest point on the ground -- almost every character and
## building asset. "center" puts its middle there, which is what a half-buried boulder
## wants.
static func declared_anchor(key: String) -> String:
	var entry: Dictionary = _entry(key)
	return String(entry.get("anchor", "feet"))

## How many metres `key` occupies. Resolved from wherever that thing already declares
## its dimensions, so this introduces no second source for a size.
static func declared_size(key: String) -> Vector3:
	var cfg: Node = _config()
	if cfg == null:
		return Vector3.ONE
	return cfg.get_visual_size(key)

static func declared_color(key: String) -> Color:
	var cfg: Node = _config()
	var entry: Dictionary = _entry(key)
	var name: String = String(entry.get("color", ""))
	if cfg and "COLORS" in cfg and cfg.COLORS.has(name):
		return cfg.COLORS[name]
	return Color(0.6, 0.6, 0.6)

## Which primitive stands in until art arrives.
static func declared_placeholder(key: String) -> String:
	var entry: Dictionary = _entry(key)
	return String(entry.get("placeholder", "box"))

static func _entry(key: String) -> Dictionary:
	var cfg: Node = _config()
	if cfg and "VISUALS" in cfg and cfg.VISUALS.has(key):
		return cfg.VISUALS[key]
	return {}

static func _config() -> Node:
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null

# ==============================================================================
# Placeholders
# ==============================================================================

## Primitives at exactly the declared size -- no fitting, because they are built to
## measure. They are all one material, so a hit flash or a blueprint's transparency
## reaches the whole body at once.
static func _build_placeholder(holder: Node3D, key: String, variant: String) -> void:
	var size: Vector3 = declared_size(key)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = declared_color(key)

	# A named model first. These are built to the declared size like the primitives are,
	# so swapping one in changes nothing about what the thing occupies -- which is the
	# whole reason this seam exists. An unknown name falls through to a primitive rather
	# than to nothing, so a typo makes a box and not an invisible building.
	var model: Node3D = ModelLibrary.build(declared_placeholder(key), size, declared_color(key), variant)
	if model != null:
		holder.add_child(model)
		return

	match declared_placeholder(key):
		"spikes":
			_build_one_spike(holder, key, size, mat)
		"cylinder":
			var cyl := CylinderMesh.new()
			cyl.top_radius = size.x * 0.4
			cyl.bottom_radius = size.x * 0.5
			cyl.height = size.y
			_add_mesh(holder, cyl, Vector3(0.0, size.y * 0.5, 0.0), mat)
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = size.x * 0.5
			cone.height = size.y
			cone.radial_segments = 8
			_add_mesh(holder, cone, Vector3(0.0, size.y * 0.5, 0.0), mat)
		_:
			var box := BoxMesh.new()
			box.size = size
			_add_mesh(holder, box, Vector3(0.0, size.y * 0.5, 0.0), mat)

## One sharpened stake.
##
## There is no arrangement here on purpose. A fence used to work out its shape from its
## neighbours -- a line, an L, a cross -- and the number of cones changed under the
## player as the fence grew. One stake, one cone, always.
static func _build_one_spike(holder: Node3D, key: String, size: Vector3, mat: StandardMaterial3D) -> void:
	var cfg: Node = _config()
	if cfg == null:
		return
	var type_id: String = key.get_slice("/", key.get_slice_count("/") - 1)
	var diameter: float = float(cfg.get_spike_diameter(type_id))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0            # sharpened to a point
	cone.bottom_radius = diameter * 0.5
	cone.height = size.y
	cone.radial_segments = 8         # hewn, not lathe-turned -- and cheap
	_add_mesh(holder, cone, Vector3(0.0, size.y * 0.5, 0.0), mat)

static func _add_mesh(holder: Node3D, mesh: Mesh, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = mat
	holder.add_child(mi)
