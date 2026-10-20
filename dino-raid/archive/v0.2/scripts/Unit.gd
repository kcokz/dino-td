class_name Unit
extends Node3D
## Anything on the field that can be hurt: a dinosaur, a robot, a nest. Keeps its health and a small bar.

signal died(unit: Unit)

var battle: Node
var team := ""
var hp := 100.0
var max_hp := 100.0
## How far its body reaches out from its middle, metres -- what an attacker must close to.
var radius := 1.0
## Where on it a shot lands, metres above its feet.
var aim_height := 1.0
var dead := false

var _bar: MeshInstance3D
var _bar_always := false
var _bar_until := 0.0

static var _bar_shader: Shader


func alive() -> bool:
	return not dead and is_instance_valid(self) and is_inside_tree()


## Whether `u` is a unit still standing: not null, not freed, not dead. Safe on a reference to one that has
## been freed, where calling it is not.
static func standing(u: Variant) -> bool:
	return is_instance_valid(u) and u is Unit and not (u as Unit).dead and (u as Unit).is_inside_tree()


func hurt(amount: float, from: Unit) -> void:
	if dead or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_bar_until = _now() + 3.0
	_update_bar()
	if hp <= 0.0:
		dead = true
		_on_die()
		died.emit(self)
	else:
		_on_hurt(from)


func _on_hurt(_from: Unit) -> void:
	pass


func _on_die() -> void:
	pass


func _now() -> float:
	return battle.clock if battle else 0.0


## A thin bar over it: always shown for buildings, for a dinosaur only a moment after it is hurt.
func make_bar(height: float, width: float, always: bool) -> void:
	if _bar_shader == null:
		_bar_shader = Shader.new()
		_bar_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
instance uniform float ratio = 1.0;
instance uniform vec4 fill : source_color = vec4(0.45, 0.85, 0.35, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float edge = step(0.04, UV.y) * step(UV.y, 0.96) * step(0.01, UV.x) * step(UV.x, 0.99);
	ALBEDO = mix(vec3(0.05), UV.x < ratio ? fill.rgb : vec3(0.18), edge);
}
"""
	var quad := QuadMesh.new()
	quad.size = Vector2(width, maxf(0.12, width * 0.09))
	var mat := ShaderMaterial.new()
	mat.shader = _bar_shader
	_bar = MeshInstance3D.new()
	_bar.mesh = quad
	_bar.material_override = mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.position.y = height
	add_child(_bar)
	_bar_always = always
	_update_bar()


func set_bar_colour(c: Color) -> void:
	if _bar:
		_bar.set_instance_shader_parameter("fill", c)


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_instance_shader_parameter("ratio", hp / max_hp)
	_bar.visible = not dead and (_bar_always or _now() < _bar_until)


func tick_bar() -> void:
	if _bar and not _bar_always and _bar.visible and _now() >= _bar_until:
		_bar.visible = false
