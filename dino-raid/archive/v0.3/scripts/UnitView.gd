class_name UnitView
extends Node3D
## A piece on the board as the player sees it -- a dinosaur, a pack, a robot -- acting out what the battle
## says it did (Battle plays Sim's events through these). It keeps its own count of hit points as it is shown
## being hurt; the battle puts it right from the state when the turn has been played.

const RUN := 10.0                # metres a second, tile to tile

var id := 0
var kind := ""
var side := ""
var hp := 0
var max_hp := 0
var bodies := 1
var tile := Vector2i.ZERO
var aim := 1.5                   # where on it a blow lands, metres up
var top := 2.5                   # how tall it stands: its marks go above this
var battle: Node

var _flash: StandardMaterial3D

static var _blob_mat: StandardMaterial3D


func setup_base(p_battle: Node, u: Dictionary) -> void:
	battle = p_battle
	id = u.id
	kind = u.kind
	side = u.side
	hp = u.hp
	max_hp = u.max
	bodies = int(u.bodies)
	tile = u.pos
	position = Board.world(tile)


func aim_point() -> Vector3:
	return global_position + Vector3.UP * aim


func face(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() > 0.01:
		rotation.y = atan2(-dir.x, -dir.z)


## Along the tiles of `path`, turning to each.
func walk(path: Array) -> void:
	_moving(true)
	for p in path:
		var to := Board.world(p)
		var dir := to - position
		var turn_to := atan2(-dir.x, -dir.z)
		var tw := create_tween()
		tw.tween_property(self, "rotation:y", lerp_angle(rotation.y, turn_to, 1.0), 0.08)
		tw.tween_property(self, "position", to, dir.length() / _speed())
		await tw.finished
		tile = p
	_moving(false)


func _speed() -> float:
	return RUN


func _moving(_on: bool) -> void:
	pass


## A blow lands: the count goes down, and it shows.
func take(dmg: int) -> void:
	hp = maxi(0, hp - dmg)
	flash(Color(1.0, 0.25, 0.2, 0.55))


func heal(n: int) -> void:
	hp = mini(max_hp, hp + n)
	flash(Color(0.4, 1.0, 0.45, 0.45))


func flash(c: Color) -> void:
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = c
	var meshes := find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = _flash
	await get_tree().create_timer(0.14).timeout
	for mi in meshes:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).material_overlay = null


## A soft dark patch under a body where it meets the ground: it sits on the sand rather than over it.
func blob(at: Vector3, radius: float, parent: Node3D = null) -> void:
	if _blob_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.55))
		g.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.albedo_texture = tex
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.render_priority = -1
	var quad := PlaneMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3.UP * 0.05
	(parent if parent else self).add_child(mi)


## Put right to what the state says.
func sync(u: Dictionary) -> void:
	hp = u.hp
	max_hp = u.max
	tile = u.pos
	position = Board.world(tile)
