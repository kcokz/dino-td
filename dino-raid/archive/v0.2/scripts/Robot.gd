class_name Robot
extends Unit
## The other side: exact, and blind to everything but range. A turret shoots the nearest dinosaur in reach;
## a walker musters at the gate with its wave (waiting), then marches on the nearest nest and shoots what
## stands in its way; the core is their base -- break it and the battle is won. In volcanic ash (Ash) they
## can hardly see. Placeholder bodies, built from boxes, until there are models.

enum Kind { TURRET, WALKER, CORE }

const STATS := {
	Kind.TURRET: {"hp": 900.0, "radius": 1.4, "range": 13.0, "damage": 18.0, "every": 1.0, "aim": 2.4},
	Kind.WALKER: {"hp": 140.0, "radius": 0.7, "range": 9.0, "damage": 9.0, "every": 0.7, "aim": 1.4, "speed": 2.4},
	Kind.CORE: {"hp": 2500.0, "radius": 4.0, "range": 11.0, "damage": 40.0, "every": 1.2, "aim": 4.0},
}
const STEEL := Color(0.55, 0.58, 0.62)
const DARK := Color(0.18, 0.2, 0.23)
const GLOW := Color(0.35, 0.9, 1.0)

var kind := Kind.TURRET
## A walker at the gate, mustered for the next wave: it holds its ground until the wave goes.
var waiting := false
var _st: Dictionary
var _ready_at := 0.0
var _head: Node3D
var _muzzle: Node3D
var _legs: Array[Node3D] = []
var _avoid: Avoider
var _stride := 0.0
var _delta := 1.0 / 60.0


func setup(p_battle: Node, p_kind: Kind, at: Vector3) -> void:
	battle = p_battle
	kind = p_kind
	team = "robot"
	_st = STATS[kind]
	max_hp = _st.hp
	hp = max_hp
	radius = _st.radius
	aim_height = _st.aim
	position = at
	match kind:
		Kind.TURRET:
			_build_turret()
		Kind.WALKER:
			_build_walker()
		Kind.CORE:
			_build_core()
	if kind == Kind.WALKER:
		_avoid = Avoider.new(self, radius, _move)
		make_bar(2.6, 1.0, false)
	else:
		var block := NavigationObstacle3D.new()
		block.radius = radius
		block.avoidance_enabled = true
		add_child(block)
		make_bar(_st.aim * 1.6 + 0.8, radius * 1.6, true)
	set_bar_colour(Color(0.95, 0.45, 0.3))


## The wave goes: off to the nests.
func march() -> void:
	waiting = false


func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_bar()
	_delta = delta
	if battle.over:
		if _avoid:
			_avoid.ask(global_position, Vector3.ZERO)
		return
	var aim: Unit = battle.nearest_dino(global_position, _st.range)
	if kind == Kind.WALKER:
		if aim == null and not waiting:
			var nest: Unit = battle.nearest_nest(global_position)
			if nest:
				var to := nest.global_position - global_position
				to.y = 0.0
				if to.length() - nest.radius > _st.range * 0.8:
					_avoid.ask(global_position, to.normalized() * _st.speed)
					return
				aim = nest
		_avoid.ask(global_position, Vector3.ZERO)
	if aim:
		_aim_at(aim)
		_shoot(aim)


## The avoidance's answer: move by it. Nothing moves while the battle waits for the player.
func _move(v: Vector3) -> void:
	if dead or not can_process():
		return
	v.y = 0.0
	position += v * _delta
	position = battle.clamp_to_field(position, radius)
	if v.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-v.x, -v.z), minf(1.0, 8.0 * _delta))
		_stride += v.length() * _delta * 3.0
	for i in _legs.size():
		_legs[i].rotation.x = sin(_stride + PI * i) * 0.5 * minf(1.0, v.length())


func _aim_at(u: Unit) -> void:
	var to := u.global_position - global_position
	var yaw := atan2(-to.x, -to.z)
	var turner: Node3D = _head if _head else self
	turner.global_rotation.y = lerp_angle(turner.global_rotation.y, yaw, minf(1.0, 6.0 * _delta))


func _shoot(u: Unit) -> void:
	var now: float = battle.clock
	if now < _ready_at:
		return
	_ready_at = now + _st.every
	var from: Vector3 = _muzzle.global_position if _muzzle else global_position + Vector3.UP * _st.aim
	var to := u.global_position + Vector3.UP * u.aim_height
	# In ash, or shooting into it, it can hardly see: most shots go wide.
	var blind: bool = battle.in_ash(global_position) or battle.in_ash(u.global_position)
	var wide := blind and randf() < Ash.MISS
	if wide:
		to += Vector3(randf_range(-4.0, 4.0), randf_range(0.5, 3.0), randf_range(-4.0, 4.0))
	battle.shot(from, to, GLOW if kind == Kind.CORE else Color(1.0, 0.6, 0.25))
	battle.sound("impact_bead_1" if kind == Kind.WALKER else "hull_hit", from, -6.0 if kind == Kind.WALKER else 0.0)
	battle.loud(u.global_position)
	if not wide:
		u.hurt(_st.damage, self)


func _on_die() -> void:
	if _avoid:
		_avoid.release()
	battle.unit_gone(self)
	battle.sound("crash" if kind != Kind.WALKER else "wood_break", global_position, 3.0)
	# A wreck: burnt dark (bright steel tipped to the sky shone white), keeled over, half sunk.
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.09, 0.08, 0.08)
	burnt.roughness = 1.0
	for mi in find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override is StandardMaterial3D:
			(mi as MeshInstance3D).material_override = burnt
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.5, 0.5)
	tw.parallel().tween_property(self, "position:y", -0.8 if kind == Kind.WALKER else -1.2, 1.5)
	if kind == Kind.WALKER:
		tw.tween_interval(2.0)
		tw.tween_callback(queue_free)


# -- Bodies ------------------------------------------------------------------------------------------------

func _build_turret() -> void:
	_box(Vector3(2.6, 0.5, 2.6), Vector3(0, 0.25, 0), DARK)
	_cyl(0.9, 1.0, 1.8, Vector3(0, 1.4, 0), STEEL)
	_head = Node3D.new()
	_head.position.y = 2.5
	add_child(_head)
	_box(Vector3(1.5, 0.9, 1.7), Vector3.ZERO, STEEL, _head)
	_box(Vector3(0.9, 0.18, 0.05), Vector3(0, 0.15, -0.86), GLOW, _head, true)
	var barrel := _cyl(0.12, 0.12, 1.6, Vector3(0, -0.05, -1.5), DARK, _head)
	barrel.rotation.x = PI * 0.5
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, -0.05, -2.3)
	_head.add_child(_muzzle)


func _build_walker() -> void:
	var body := Node3D.new()
	body.position.y = 1.35
	add_child(body)
	_box(Vector3(0.9, 0.75, 0.7), Vector3.ZERO, STEEL, body)
	_box(Vector3(0.5, 0.12, 0.05), Vector3(0, 0.15, -0.36), GLOW, body, true)
	_box(Vector3(0.14, 0.14, 0.6), Vector3(0.52, -0.1, -0.25), DARK, body)
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.52, -0.1, -0.6)
	body.add_child(_muzzle)
	for side in [-0.28, 0.28]:
		var hip := Node3D.new()
		hip.position = Vector3(side, 1.0, 0)
		add_child(hip)
		_box(Vector3(0.18, 1.0, 0.22), Vector3(0, -0.5, 0), DARK, hip)
		_legs.append(hip)


func _build_core() -> void:
	_cyl(4.2, 4.6, 1.0, Vector3(0, 0.5, 0), DARK, null, 6)
	_cyl(2.6, 3.4, 6.0, Vector3(0, 4.0, 0), STEEL, null, 6)
	_cyl(2.7, 2.7, 0.35, Vector3(0, 5.2, 0), GLOW, null, 6, true)
	_cyl(1.2, 2.2, 2.0, Vector3(0, 8.0, 0), STEEL, null, 6)
	_muzzle = Node3D.new()
	_muzzle.position.y = 9.2
	add_child(_muzzle)


func _material(c: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.0 if glow else 0.75
	m.roughness = 0.35
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.5
	return m


func _box(size: Vector3, at: Vector3, c: Color, parent: Node3D = null, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _put(mesh, at, c, parent, glow)


func _cyl(top: float, bottom: float, h: float, at: Vector3, c: Color, parent: Node3D = null, sides := 16, glow := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = sides
	return _put(mesh, at, c, parent, glow)


func _put(mesh: Mesh, at: Vector3, c: Color, parent: Node3D, glow: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(c, glow)
	mi.position = at
	(parent if parent else self).add_child(mi)
	return mi
