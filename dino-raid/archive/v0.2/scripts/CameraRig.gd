class_name CameraRig
extends Node3D
## Looks down on the field at a slant. Arrow keys or WASD pan, the wheel zooms, the middle button drags.

const PITCH := 55.0
const NEAR := 16.0
const FAR := 85.0
const PAN := 32.0

var camera: Camera3D
var bounds := Rect2(-40, -20, 80, 40)
var distance := 62.0
var _drag := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 600.0
	add_child(camera)
	_place()


func _place() -> void:
	var a := deg_to_rad(PITCH)
	camera.position = Vector3(0.0, sin(a), cos(a)) * distance
	camera.rotation = Vector3(-a, 0.0, 0.0)


func _process(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if v != Vector2.ZERO:
		_pan(v.normalized() * PAN * delta * distance / 60.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed:
			distance = maxf(NEAR, distance * 0.9)
			_place()
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed:
			distance = minf(FAR, distance * 1.1)
			_place()
		elif b.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = b.pressed
	elif event is InputEventMouseMotion and _drag:
		var m := event as InputEventMouseMotion
		_pan(-m.relative * distance * 0.0018)


func _pan(d: Vector2) -> void:
	position.x = clampf(position.x + d.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z + d.y, bounds.position.y, bounds.end.y)