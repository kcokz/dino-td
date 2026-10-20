class_name RobotView
extends UnitView
## A robot, from its model (common/tools/generate_robots.py): legs that swing as it walks, a turret's head
## that turns to its mark, the time machine's ring turning and its portal swirling. Every part named glow*
## shines. Shooting is a streak of light; dying, a burst and a burnt wreck.

const SPEED := 7.0
const CYAN := Color(0.35, 0.9, 1.0)
const RED := Color(1.0, 0.24, 0.16)

const PORTAL := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
varying vec2 p;
void vertex() { p = VERTEX.xy; }
void fragment() {
	float r = length(p) / 2.12;
	float a = atan(p.y, p.x);
	float swirl = sin(a * 3.0 + r * 9.0 - TIME * 2.2) * 0.5 + 0.5;
	float rim = smoothstep(0.55, 1.0, r);
	float glow = (0.25 + 0.55 * swirl) * (1.0 - r * r * r) + rim * 0.6;
	ALBEDO = tint.rgb * glow + vec3(0.6, 0.9, 1.0) * pow(1.0 - r, 6.0) * 0.8;
}
"""

static var _metal: StandardMaterial3D
static var _glow := {}
static var _burnt: StandardMaterial3D

var _model: Node3D
var _legs: Array[Node3D] = []
var _head: Node3D
var _ring: Node3D
var _walking := false
var _stride := 0.0


func setup(p_battle: Node, u: Dictionary) -> void:
	setup_base(p_battle, u)
	_model = (battle.scene("res://common/assets/models/robots/%s.glb" % kind) as PackedScene).instantiate()
	add_child(_model)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("glow_red"):
			m.material_override = _glow_mat(RED)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif m.name.begins_with("glow"):
			m.material_override = _glow_mat(CYAN)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif m.name.begins_with("portal"):
			var pm := ShaderMaterial.new()
			pm.shader = Shader.new()
			pm.shader.code = PORTAL
			m.material_override = pm
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			m.material_override = _metal_mat()
	for leg in ["leg_l", "leg_r"]:
		var n := _model.find_child(leg, true, false) as Node3D
		if n:
			_legs.append(n)
	_head = _model.find_child("head", true, false) as Node3D
	_ring = _model.find_child("ring", true, false) as Node3D
	match kind:
		"walker":
			aim = 1.4
			top = 2.4
		"turret":
			aim = 2.0
			top = 3.2
		"machine":
			aim = 3.2
			top = 6.6
	face(Vector3.BACK)
	blob(Vector3.ZERO, {"walker": 1.0, "turret": 1.9, "machine": 4.6}.get(kind, 1.2))


func _process(delta: float) -> void:
	if _ring:
		_ring.rotate_object_local(Vector3.FORWARD, delta * 0.35)
	if _walking:
		_stride += delta * 9.0
		for i in _legs.size():
			_legs[i].rotation.x = sin(_stride + PI * i) * 0.55
		_model.position.y = absf(sin(_stride)) * 0.06
	elif not _legs.is_empty():
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, minf(1.0, delta * 8.0))
		_model.position.y = 0.0


func _speed() -> float:
	return SPEED


func _moving(on: bool) -> void:
	_walking = on


## A shot at `at`; returns as it lands.
func fire(at: Vector3) -> void:
	var muzzle := _muzzle()
	if _head:
		var to := at - _head.global_position
		var yaw := atan2(-to.x, -to.z) - rotation.y
		var tw := create_tween()
		tw.tween_property(_head, "rotation:y", lerp_angle(_head.rotation.y, yaw, 1.0), 0.18)
		await tw.finished
		muzzle = _muzzle()
	else:
		face(at - global_position)
		muzzle = _muzzle()
	battle.beam(muzzle, at, Color(1.0, 0.55, 0.2) if kind == "turret" else CYAN)
	battle.sound("impact_bead_1" if kind == "walker" else "hull_hit", muzzle, -4.0)
	await get_tree().create_timer(0.12).timeout


func _muzzle() -> Vector3:
	match kind:
		"walker":
			return to_global(Vector3(0.56, 1.2, -0.85))
		"turret":
			return _head.to_global(Vector3(0.0, 0.3, -1.8)) if _head else global_position + Vector3.UP * 2.1
	return global_position + Vector3.UP * aim


func take(dmg: int) -> void:
	super.take(dmg)
	battle.sparks(aim_point())


## A burst, then the wreck: burnt dark, keeled over, half sunk.
func die() -> void:
	battle.burst(aim_point(), 2.5 if kind == "machine" else 1.0)
	battle.sound("crash" if kind != "walker" else "wood_break", global_position, 4.0)
	_walking = false
	if _burnt == null:
		_burnt = StandardMaterial3D.new()
		_burnt.albedo_color = Color(0.08, 0.075, 0.07)
		_burnt.roughness = 1.0
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("glow") or m.name.begins_with("portal"):
			m.visible = false
		else:
			m.material_override = _burnt
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.45 if kind == "walker" else 0.12, 0.45)
	tw.parallel().tween_property(self, "position:y", -0.9 if kind == "walker" else -1.4, 1.4)
	if kind == "walker":
		tw.tween_interval(1.5)
		tw.tween_callback(queue_free)
	await get_tree().create_timer(0.45).timeout


## Out of the portal: a flash and it is there.
func arrive() -> void:
	battle.flash_at(global_position + Vector3.UP * 1.2, CYAN)
	scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


static func _metal_mat() -> StandardMaterial3D:
	if _metal == null:
		_metal = StandardMaterial3D.new()
		_metal.vertex_color_use_as_albedo = true
		_metal.vertex_color_is_srgb = true
		_metal.metallic = 0.55
		_metal.roughness = 0.36
		_metal.metallic_specular = 0.6
	return _metal


static func _glow_mat(c: Color) -> StandardMaterial3D:
	if not _glow.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 3.0
		_glow[c] = m
	return _glow[c]
