class_name Garden
extends Node3D
## Our ground (GAME-DESIGN 5): a sandy clearing in plots, each taking one nest or one building. The plots
## show only while a card is being put down; the rest of the time it is just ground.

const ROWS := 4          # along x, from the back
const COLS := 6          # along z
const PLOT := 4.5        # metres a side
const CORNER := Vector3(-34.0, 0.0, -13.5)
const NOWHERE := Vector2i(-1, -1)

const SAND := """
shader_type spatial;
render_mode blend_mix, cull_back;
uniform vec3 sand : source_color = vec3(0.64, 0.56, 0.41);
uniform vec3 damp : source_color = vec3(0.49, 0.42, 0.3);
varying vec2 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
// Gradient noise, about 0 to 1: soft, with nothing lined up on the grid it is built on.
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i) * 6.2831853;
	float b = hash(i + vec2(1.0, 0.0)) * 6.2831853;
	float c = hash(i + vec2(0.0, 1.0)) * 6.2831853;
	float d = hash(i + vec2(1.0, 1.0)) * 6.2831853;
	float va = dot(vec2(cos(a), sin(a)), f);
	float vb = dot(vec2(cos(b), sin(b)), f - vec2(1.0, 0.0));
	float vc = dot(vec2(cos(c), sin(c)), f - vec2(0.0, 1.0));
	float vd = dot(vec2(cos(d), sin(d)), f - vec2(1.0, 1.0));
	return 0.5 + 0.75 * mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
}
float fbm(vec2 p) {
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 4; k++) {
		v += amp * gnoise(p);
		p = turn * p * 2.03;
		amp *= 0.5;
	}
	return v / 0.9375;
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	ALBEDO = mix(damp, sand, smoothstep(0.3, 0.7, fbm(world * 0.16)));
	ROUGHNESS = 1.0;
	vec2 e = min(UV, 1.0 - UV);
	ALPHA = smoothstep(0.0, 0.08, min(e.x, e.y) + (fbm(world * 0.45) - 0.5) * 0.08);
}
"""

## What stands in each plot: Vector2i -> Nest or Building.
var things := {}

var _grid: MeshInstance3D
var _here: MeshInstance3D
var _here_mat: StandardMaterial3D
var _reach: Array[MeshInstance3D] = []


func setup() -> void:
	_lay_sand()
	_grid = MeshInstance3D.new()
	_grid.mesh = _grid_mesh()
	_grid.material_override = _flat(Color(1, 1, 1, 0.22))
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.visible = false
	add_child(_grid)
	var square := PlaneMesh.new()
	square.size = Vector2(PLOT, PLOT) * 0.94
	_here_mat = _flat(Color(0.5, 1.0, 0.5, 0.3))
	_here = _square(square, _here_mat)
	var lit := _flat(Color(1.0, 0.9, 0.45, 0.16))
	for i in 8:
		_reach.append(_square(square, lit))


func centre(p: Vector2i) -> Vector3:
	return CORNER + Vector3((p.x + 0.5) * PLOT, 0.0, (p.y + 0.5) * PLOT)


## The plot under a point on the ground, or NOWHERE.
func plot_at(at: Vector3) -> Vector2i:
	var p := Vector2i(floori((at.x - CORNER.x) / PLOT), floori((at.z - CORNER.z) / PLOT))
	return p if has_plot(p) else NOWHERE


func has_plot(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < ROWS and p.y >= 0 and p.y < COLS


## The plots round `p`, up to eight.
func around(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var q := p + Vector2i(dx, dz)
			if q != p and has_plot(q):
				out.append(q)
	return out


## Whether a building of `kind` stands in a plot round `p`.
func beside(p: Vector2i, kind: String) -> bool:
	for q in around(p):
		var t: Node = things.get(q)
		if t is Building and (t as Building).kind == kind:
			return true
	return false


## The plots, while a card is being put down: the one it would go in, green or red, and for a building the
## plots round it that it would work on.
func show_placing(at: Variant, building: bool, ok: bool) -> void:
	_grid.visible = true
	var p: Vector2i = plot_at(at) if at != null else NOWHERE
	_here.visible = p != NOWHERE
	for r in _reach:
		r.visible = false
	if p == NOWHERE:
		return
	_here.position = centre(p) + Vector3.UP * 0.06
	_here_mat.albedo_color = Color(0.5, 1.0, 0.5, 0.3) if ok else Color(1.0, 0.35, 0.3, 0.3)
	if building and ok:
		var near := around(p)
		for i in near.size():
			_reach[i].position = centre(near[i]) + Vector3.UP * 0.05
			_reach[i].visible = true


func hide_placing() -> void:
	_grid.visible = false
	_here.visible = false
	for r in _reach:
		r.visible = false


func _lay_sand() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(ROWS * PLOT + 5.0, COLS * PLOT + 5.0)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SAND
	mat.render_priority = -10  # under every other see-through thing: drawn first
	var sand := MeshInstance3D.new()
	sand.mesh = plane
	sand.material_override = mat
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sand.position = CORNER + Vector3(ROWS * PLOT, 0.0, COLS * PLOT) * 0.5 + Vector3.UP * 0.03
	add_child(sand)


func _grid_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.06
	var y := 0.07
	var x0 := CORNER.x
	var x1 := CORNER.x + ROWS * PLOT
	var z0 := CORNER.z
	var z1 := CORNER.z + COLS * PLOT
	for i in ROWS + 1:
		var x := x0 + i * PLOT
		_strip(st, Vector3(x - w, y, z0), Vector3(x + w, y, z0), Vector3(x + w, y, z1), Vector3(x - w, y, z1))
	for j in COLS + 1:
		var z := z0 + j * PLOT
		_strip(st, Vector3(x0, y, z - w), Vector3(x1, y, z - w), Vector3(x1, y, z + w), Vector3(x0, y, z + w))
	return st.commit()


func _strip(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


func _square(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m
