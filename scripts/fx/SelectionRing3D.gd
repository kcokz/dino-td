# res://scripts/fx/SelectionRing3D.gd
class_name SelectionRing3D
extends Node3D

## The outline drawn on the ground under whatever the player has selected.
##
## It traces the unit's own base rather than being a fixed circle: a square
## building gets a square outline sized to its footprint, a round unit gets a ring.
## A fixed radius does not work -- wooden stakes are 1.9m across and a 0.85m ring
## simply disappeared inside them.
##
## Deliberately a different thing from a building's coverage ring: this one hugs
## the base and says "this is what you clicked", while a coverage ring is sized by
## the building's actual reach and says "this is what it affects".

enum Shape { BOX = 0, ROUND = 1 }

var shape: int = Shape.BOX
var base_size: float = 1.0   # side length for BOX, diameter for ROUND

var _parts: Array[MeshInstance3D] = []
var _built_for: Vector2 = Vector2(-1.0, -1.0)  # (shape, size) the current mesh was built for

## Set to draw this ring in something other than the selection colour. The hover ring
## uses it: "what I am pointing at" and "what I have selected" have to be tellable apart
## at a glance, or the outline says nothing.
var _colour_override: Variant = null

func _ready() -> void:
	rebuild()
	visible = false

## Draws this ring in `tint` instead of the configured selection colour.
func override_color(tint: Color) -> void:
	_colour_override = tint
	_built_for = Vector2(-1.0, -1.0)   # force a rebuild, the colour is baked into the mesh
	rebuild()

## Tells the ring what it is outlining. Call before showing it; rebuilding is
## skipped when nothing changed.
func configure(p_shape: int, p_base_size: float) -> void:
	shape = p_shape
	base_size = maxf(0.1, p_base_size)
	rebuild()

func rebuild() -> void:
	var want := Vector2(float(shape), base_size)
	if want.is_equal_approx(_built_for) and not _parts.is_empty():
		return
	for m in _parts:
		if is_instance_valid(m):
			m.queue_free()
	_parts.clear()
	_built_for = want

	var margin: float = _cfg("selection_ring_margin", 0.18)
	var thickness: float = _cfg("selection_ring_thickness", 0.09)
	var colour: Color = _colour_override if _colour_override is Color else _cfg("selection_ring_color", Color(0.35, 1.0, 0.5, 0.9))
	var outer: float = base_size + margin * 2.0

	if shape == Shape.ROUND:
		_parts.append(_add_torus(outer * 0.5, thickness, colour))
	else:
		# Four thin bars laid out as a frame: reads as an outline at any size, and
		# needs no mesh generation beyond boxes.
		var half: float = outer * 0.5
		for spec in [
			[Vector3(0.0, 0.0, -half), Vector3(outer, thickness, thickness)],
			[Vector3(0.0, 0.0,  half), Vector3(outer, thickness, thickness)],
			[Vector3(-half, 0.0, 0.0), Vector3(thickness, thickness, outer)],
			[Vector3( half, 0.0, 0.0), Vector3(thickness, thickness, outer)],
		]:
			_parts.append(_add_bar(spec[0], spec[1], colour))

func _add_bar(offset: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = offset + Vector3(0.0, 0.05, 0.0)
	mi.material_override = _make_material(colour)
	# A selection marker must never darken the ground it sits on.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _add_torus(radius: float, thickness: float, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = radius
	torus.inner_radius = maxf(0.01, radius - thickness)
	mi.mesh = torus
	mi.position = Vector3(0.0, 0.05, 0.0)
	mi.material_override = _make_material(colour)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _make_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func set_shown(on: bool) -> void:
	rebuild()
	visible = on

func _cfg(key: String, fallback):
	var cfg = _config()
	if cfg and "FEEDBACK" in cfg:
		return cfg.FEEDBACK.get(key, fallback)
	return fallback

func _config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
