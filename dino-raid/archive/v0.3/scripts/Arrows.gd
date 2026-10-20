class_name Arrows
extends MeshInstance3D
## The coming turn on the ground: where each piece will walk (an arrow along its tiles), who it will strike
## (a line to its mark), where a frightened plant-eater will bolt -- warm for ours, red for theirs. Rebuilt
## whenever the plan changes (Battle.refresh).

const Y := 0.18

var _mesh := ImmediateMesh.new()


func _ready() -> void:
	mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## paths: [{points: [Vector3...], colour, width, head}], lines: [{from, to, colour, width}]
func show_plan(paths: Array, lines: Array) -> void:
	_mesh.clear_surfaces()
	if paths.is_empty() and lines.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in paths:
		var pts: Array = p.points
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			if i == pts.size() - 2 and p.head:
				b = b - (b - a).normalized() * 1.2
			_ribbon(a, b, p.width, p.colour)
		if p.head and pts.size() >= 2:
			_head(pts[pts.size() - 2], pts[pts.size() - 1], p.width * 3.0, p.colour)
	for l in lines:
		_dashes(l.from, l.to, l.width, l.colour)
	_mesh.surface_end()


func _ribbon(a: Vector3, b: Vector3, w: float, c: Color) -> void:
	a.y = Y
	b.y = Y
	var d := (b - a)
	if d.length() < 0.01:
		return
	var side := d.normalized().cross(Vector3.UP) * w * 0.5
	_tri(a - side, a + side, b + side, c)
	_tri(a - side, b + side, b - side, c)


func _head(a: Vector3, b: Vector3, w: float, c: Color) -> void:
	a.y = Y
	b.y = Y
	var d := (b - a).normalized()
	var base := b - d * 1.6
	var side := d.cross(Vector3.UP) * w * 0.5
	_tri(base - side, base + side, b, c)


func _dashes(a: Vector3, b: Vector3, w: float, c: Color) -> void:
	a.y = Y + 0.05
	b.y = Y + 0.05
	var d := b - a
	var n := maxi(1, int(d.length() / 0.9))
	for i in n:
		if i % 2 == 1:
			continue
		_ribbon(a + d * (float(i) / n), a + d * (float(i + 1) / n), w, c)


func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(v)
