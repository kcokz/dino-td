# res://scripts/entities/Gate.gd
class_name Gate
extends "res://scripts/entities/Wall.gd"

## A gate: the section of wall the Hero walks through, and nothing else does.
##
## Since v0.6 round two a wall stops him ("人不能再穿过墙了"), and this is his way in and out of his
## own camp. It is a wall to everything else -- a raid bites it only when it shuts the way, like
## any wall (Dino._should_bite) -- and it stands on a layer of its own (Config.LAYER_GATE) that his
## body and his walking mesh leave out.
##
## It looks it: two posts and a door on a vine hinge (tools/generate_props.py gate), the door
## across the line of the wall it stands in, swinging open as he comes up to it and shut behind
## him (Config.GATE). Which way the line runs is read off its neighbours, like a palisade's runs.

## The door, found on the art (the node called Door), and whether it stands open.
var _door: Node3D = null
var _open: bool = false
var _swing: Tween = null
var _sensor: Area3D = null

func _init() -> void:
	super()
	building_type = "gate"

func _ready() -> void:
	super._ready()
	_ensure_sensor()

## The door and the frame across the line of the wall: along X, unless the wall it stands in
## runs north to south. Read off what is beside it, like a palisade's runs.
func refresh_joins(planned: Array = []) -> void:
	if not is_inside_tree():
		return
	var body: Node = find_child("Body", false, false)
	if body == null or not (body is Node3D):
		return
	var gm: Node = _grid()
	var near: Dictionary = neighbours_of(gm, gm.world_to_build_cell(global_position) if gm else Vector2i.ZERO, self, planned)
	(body as Node3D).rotation.y = across(near, facing)
	_door = body.find_child("Door", true, false) as Node3D

## How a gate turns to stand across the line of the wall `near` says it is in: a quarter turn when
## that line runs north to south, none when it runs east to west -- and, standing in no wall, the
## way it faces (Wall.facing). Static, so the build preview turns its ghost the same way.
static func across(near: Dictionary, faces: int = 0) -> float:
	var east_west: bool = bool(near.get("Run_E", false)) or bool(near.get("Run_W", false))
	var north_south: bool = bool(near.get("Run_N", false)) or bool(near.get("Run_S", false))
	if not east_west and not north_south:
		return PI * 0.5 if posmod(faces, 2) == 1 else 0.0
	return PI * 0.5 if (north_south and not east_west) else 0.0

# ==============================================================================
# The door
# ==============================================================================

## A ring round the gate that notices the Hero -- the engine's Area3D, on his layer and no other.
func _ensure_sensor() -> void:
	if _sensor != null:
		return
	var cfg = _get_config()
	var radius: float = float(cfg.GATE.get("open_radius", 1.4)) if (cfg and "GATE" in cfg) else 1.4
	_sensor = Area3D.new()
	_sensor.name = "HeroSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = int(cfg.LAYER_HERO) if (cfg and "LAYER_HERO" in cfg) else 4
	_sensor.monitorable = false
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = radius
	shape.shape = ball
	shape.position = Vector3(0.0, 0.6, 0.0)
	_sensor.add_child(shape)
	add_child(_sensor)
	_sensor.body_entered.connect(_on_body_entered)
	_sensor.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("hero") and is_constructed:
		set_open(true)

func _on_body_exited(body: Node) -> void:
	if body == null or not body.is_in_group("hero"):
		return
	for other in _sensor.get_overlapping_bodies():
		if other != body and other.is_in_group("hero"):
			return
	set_open(false)

## Swings the door open or shut (Config.GATE: how far, how fast). The door is only art: the gate
## lets him through whether it is drawn open or not, so a door caught half way changes nothing.
func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	if _door == null:
		var body: Node = find_child("Body", false, false)
		_door = body.find_child("Door", true, false) as Node3D if body else null
	if _door == null or not is_inside_tree():
		return
	var cfg = _get_config()
	var gate: Dictionary = cfg.GATE if (cfg and "GATE" in cfg) else {}
	if _swing != null and _swing.is_valid():
		_swing.kill()
	_swing = create_tween()
	_swing.tween_property(_door, "rotation:y", deg_to_rad(float(gate.get("open_degrees", 100.0))) if open else 0.0,
		float(gate.get("swing_seconds", 0.35))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func is_open() -> bool:
	return _open
