# res://scripts/fx/StatusBar3D.gd
class_name StatusBar3D
extends Node3D

## A small world-space bar drawn above a unit: health once it is built, build
## progress while it is not. Never both -- a blueprint has no health worth showing.
##
## Two details matter, and both were got wrong first time round:
##
## 1. The bar is billboarded as ONE rigid unit, by turning this node to face the
##    camera. Billboarding each quad through its own material instead makes every
##    quad pivot about its own origin, so the plate and the fill swing apart at any
##    camera angle and the dark plate shows through the gap -- which reads as a
##    shadow beside the unit rather than as a bar.
##
## 2. The fill grows from a fixed anchor on the left edge: the anchor node is
##    scaled and the quad inside it never moves. Moving the quad instead makes its
##    origin travel as the value changes, which is the other half of the drift.
##
## The alternative to all of this is a screen-space overlay projected from the
## unit's position -- sharper and a constant size, which is what most RTS games use
## -- but it needs a UI layer tracking every unit. This stays in world space so it
## sits with the Label3D carrying the name, and the two cannot come apart.
##
## Sizing comes from Config.FEEDBACK. Nothing here casts a shadow.

var _back: MeshInstance3D = null
var _fill: MeshInstance3D = null
var _anchor: Node3D = null
var _fill_mat: StandardMaterial3D = null
var _width: float = 1.1
var _height: float = 0.13
var _last_ratio: float = -1.0
var _last_colour: Color = Color.BLACK

func _ready() -> void:
	_build()

func _process(_delta: float) -> void:
	if visible:
		_face_camera()

func _build() -> void:
	if _back != null:
		return
	var cfg := _config()
	if cfg and "FEEDBACK" in cfg:
		_width = float(cfg.FEEDBACK.get("health_bar_width", _width))
		_height = float(cfg.FEEDBACK.get("health_bar_height", _height))

	_back = _make_quad(Color(0.05, 0.05, 0.06, 0.8), _width, _height, 0.0, 0)
	_back.position = Vector3.ZERO
	add_child(_back)

	# The anchor sits on the left edge and never moves; scaling it drains the bar
	# rightwards without the fill's own origin travelling.
	_anchor = Node3D.new()
	_anchor.name = "FillAnchor"
	_anchor.position = Vector3(-_width * 0.5, 0.0, 0.0)
	add_child(_anchor)

	_fill = _make_quad(Color(0.3, 0.85, 0.35, 0.95), _width, _height * 0.72, 0.004, 1)
	_fill.position = Vector3(_width * 0.5, 0.0, 0.004) # spans 0..width inside the anchor
	_anchor.add_child(_fill)
	_fill_mat = _fill.material_override

	# Sized and hidden: an owner that never refreshes shows nothing at all, rather
	# than a half-drawn bar.
	set_ratio(1.0, Color(0.3, 0.85, 0.35, 0.95))
	visible = false

func _make_quad(colour: Color, w: float, h: float, z: float, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	mi.mesh = quad
	mi.position = Vector3(0.0, 0.0, z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = priority   # the fill must win over its own backing plate
	# Deliberately NOT billboard_mode: this node turns as a whole instead.
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	if _anchor:
		_anchor.scale.x = maxf(0.0001, r)
	if _fill_mat:
		_fill_mat.albedo_color = colour

## Left and right edge of the fill in this bar's own space. Used by tests, and the
## clearest statement of what "anchored on the left" actually means.
func fill_span() -> Vector2:
	if _anchor == null:
		return Vector2.ZERO
	var left: float = _anchor.position.x
	return Vector2(left, left + _width * _anchor.scale.x)

func plate_span() -> Vector2:
	return Vector2(-_width * 0.5, _width * 0.5)

func _face_camera() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam == null:
		return
	# Copy the camera's orientation wholesale: the bar and everything on it turn
	# together, so the fill can never slide off its plate.
	global_transform = Transform3D(cam.global_transform.basis, global_transform.origin)

func _config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
