# res://scripts/fx/StatusBar3D.gd
class_name StatusBar3D
extends Node3D

## A small world-space bar drawn above a unit: health once it is built, build
## progress while it is not.
##
## It shares the info layer with the Label3D that carries the name, so the two are
## positioned together rather than each picking its own height and drifting apart.
## Sizing comes from Config.FEEDBACK.

var _back: MeshInstance3D = null
var _fill: MeshInstance3D = null
var _fill_mat: StandardMaterial3D = null
var _width: float = 1.1
var _height: float = 0.13
var _last_ratio: float = -1.0
var _last_colour: Color = Color.BLACK

func _ready() -> void:
	_build()

func _build() -> void:
	if _back != null:
		return
	var cfg := _config()
	if cfg:
		_width = float(cfg.FEEDBACK.get("health_bar_width", _width))
		_height = float(cfg.FEEDBACK.get("health_bar_height", _height))

	_back = _make_quad(Color(0.05, 0.05, 0.06, 0.75), _width, _height, 0.0)
	add_child(_back)
	# The fill is anchored to the left edge so scaling it on X drains it rightwards
	# instead of shrinking towards the middle.
	_fill = _make_quad(Color(0.3, 0.85, 0.35, 0.95), _width, _height * 0.78, 0.002)
	_fill.position.x = -_width * 0.5
	var holder := Node3D.new()
	holder.name = "FillAnchor"
	holder.add_child(_fill)
	add_child(holder)
	_fill_mat = _fill.material_override

func _make_quad(colour: Color, w: float, h: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	mi.mesh = quad
	mi.position = Vector3(w * 0.5, 0.0, z) if z > 0.0 else Vector3(0.0, 0.0, z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mi.material_override = mat
	return mi

## `ratio` is 0..1. `colour` tints the fill, so the caller decides whether this bar
## is reading as health or as construction progress.
func set_ratio(ratio: float, colour: Color) -> void:
	_build()
	var r: float = clampf(ratio, 0.0, 1.0)
	if is_equal_approx(r, _last_ratio) and colour == _last_colour:
		return
	_last_ratio = r
	_last_colour = colour
	if _fill:
		_fill.scale.x = maxf(0.0001, r)
		_fill.position.x = -_width * 0.5 + (_width * r) * 0.5
	if _fill_mat:
		_fill_mat.albedo_color = colour

func _config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
