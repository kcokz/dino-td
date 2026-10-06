# res://scripts/fx/Projectile.gd
class_name Projectile
extends Node3D

## Something a tower sends flying -- an arrow, a stone -- and what happens where it comes down (the 2026-10-02
## rebuild: an arrow that hit the moment it was let go, its flight only a picture, was one of the reasons the old
## traps read as nothing): the hit is where it lands, when it lands. It flies from where it was let go to `to` --
## or, after a `target` that moves, to wherever that is (`aim_height` up its body) -- straight at `speed` metres a
## second, or in an arc `arc` metres high over `seconds`; then `arrived` is called with where it came down, and it
## is gone. Paused with the game: it moves on the physics step.

## Called with the point it came down at.
var arrived: Callable = Callable()
var target: Node3D = null
var aim_height: float = 0.5
var to: Vector3 = Vector3.ZERO
## Straight, this fast; or, with `seconds` above nothing, along an arc this long and this high.
var speed: float = 20.0
var seconds: float = 0.0
var arc: float = 0.0
## Turned to point along its flight (an arrow), or spun about its own X as it goes (`spin` turns a second).
var points: bool = true
var spin: float = 0.0

var _from: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _done: bool = false

## Sends `model` flying from `from`: added under `parent`, it moves itself and frees itself.
static func launch(parent: Node, model: Node3D, from: Vector3) -> Projectile:
	var p := Projectile.new()
	p.name = "Projectile"
	if model != null:
		p.add_child(model)
	parent.add_child(p)
	p.global_position = from
	p._from = from
	return p

func _physics_process(delta: float) -> void:
	if _done:
		return
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		to = target.global_position + Vector3(0.0, aim_height, 0.0)
	var was: Vector3 = global_position
	if seconds > 0.0:
		_t = minf(1.0, _t + delta / seconds)
		var p: Vector3 = _from.lerp(to, _t)
		p.y += arc * 4.0 * _t * (1.0 - _t)
		global_position = p
		if _t >= 1.0:
			_land()
			return
	else:
		var left: Vector3 = to - global_position
		var step: float = speed * delta
		if left.length() <= step:
			global_position = to
			_land()
			return
		global_position += left.normalized() * step
	var went: Vector3 = global_position - was
	if points and went.length_squared() > 0.000001:
		var up: Vector3 = Vector3.UP if absf(went.normalized().y) < 0.99 else Vector3.FORWARD
		look_at(global_position + went, up)
	if spin != 0.0:
		rotate_object_local(Vector3.RIGHT, spin * TAU * delta)

func _land() -> void:
	_done = true
	if arrived.is_valid():
		arrived.call(global_position)
	queue_free()
