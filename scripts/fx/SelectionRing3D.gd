# res://scripts/fx/SelectionRing3D.gd
class_name SelectionRing3D
extends Node3D

## The ring drawn on the ground under whatever the player has selected.
##
## Deliberately a different thing from a building's coverage ring: this one is a
## fixed small size and says "this is what you clicked", while a coverage ring is
## sized by the building's actual reach and says "this is what it affects". Drawing
## them the same size, or in the same colour, would make one unreadable.

var _mesh: MeshInstance3D = null

func _ready() -> void:
	_build()
	visible = false

func _build() -> void:
	if _mesh != null:
		return
	var radius: float = 0.85
	var colour := Color(0.35, 1.0, 0.5, 0.9)
	var cfg := _config()
	if cfg and "FEEDBACK" in cfg:
		radius = float(cfg.FEEDBACK.get("selection_ring_radius", radius))
		colour = cfg.FEEDBACK.get("selection_ring_color", colour)

	_mesh = MeshInstance3D.new()
	_mesh.name = "RingMesh"
	var torus := TorusMesh.new()
	torus.outer_radius = radius
	torus.inner_radius = radius * 0.86 # a thin outline, not a filled disc
	_mesh.mesh = torus
	_mesh.position = Vector3(0.0, 0.06, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)

func set_shown(on: bool) -> void:
	_build()
	visible = on

func _config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
