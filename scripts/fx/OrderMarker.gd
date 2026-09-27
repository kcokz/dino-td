# res://scripts/fx/OrderMarker.gd
class_name OrderMarker
extends Node3D

## Where the Hero was just sent: a thin ring on the ground at the spot, closing in on it
## and fading, the way a real-time strategy game answers an order -- the click was heard,
## and this is where he is going. Its colour says what the order was: to walk there, to
## work something (a tree, a rock, a building), or to fight (Config.FEEDBACK.order_marker_*).
##
## One at a time: a new order's marker replaces the last one's.

static var _last: OrderMarker = null

var kind: String = "move"

## A marker for an order of `kind` ("move", "work", "attack") at `at`, under `parent`.
static func spawn(parent: Node, at: Vector3, order_kind: String = "move") -> OrderMarker:
	if parent == null or not parent.is_inside_tree():
		return null
	if _last != null and is_instance_valid(_last):
		_last.queue_free()
	var m := OrderMarker.new()
	m.name = "OrderMarker"
	m.kind = order_kind
	parent.add_child(m)
	m.global_position = at
	_last = m
	return m

func _ready() -> void:
	var fb: Dictionary = _feedback()
	var colours: Dictionary = fb.get("order_marker_colors", {})
	var colour: Color = colours.get(kind, colours.get("move", Color.WHITE))
	var radius: float = float(fb.get("order_marker_radius", 0.6))
	var thickness: float = float(fb.get("unit_ring_thickness", 0.03))
	var seconds: float = float(fb.get("order_marker_seconds", 0.45))
	# Two rings, the inner a little smaller: one ring reads as a selection, two as a target.
	var mats: Array[StandardMaterial3D] = []
	for k in 2:
		var torus := TorusMesh.new()
		var r: float = radius * (1.0 - float(fb.get("order_marker_inner", 0.4)) * k)
		torus.outer_radius = r
		torus.inner_radius = maxf(0.01, r - thickness)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = colour
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, float(fb.get("order_marker_lift", 0.06)), 0.0)
		add_child(mi)
		mats.append(mat)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * float(fb.get("order_marker_end_scale", 0.3)), seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for mat in mats:
		tw.tween_property(mat, "albedo_color:a", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _feedback() -> Dictionary:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	return cfg.FEEDBACK if (cfg and "FEEDBACK" in cfg) else {}
