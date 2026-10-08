class_name Call
extends Node3D
## A mating call let loose on the field (求偶叫声, GAME-DESIGN 5.2): every plant-eater that hears it comes to
## it -- the other way from a noise. It calls a few times, then stops.

const LIFE := 12.0
const REACH := 40.0          # metres it is heard at
const EVERY := 3.0

var battle: Node
## Round the call, where the ones that came mill about (Dino, as round the smell of meat).
var radius := 4.0

var _born := 0.0
var _next := 0.0
var _gone := false


func setup(p_battle: Node, at: Vector3) -> void:
	battle = p_battle
	position = at
	_born = battle.clock
	_next = _born


func _physics_process(_delta: float) -> void:
	if _gone:
		return
	var now: float = battle.clock
	if now >= _next:
		_next = now + EVERY
		battle.sound("triceratops_call_%d" % (1 + randi() % 2), global_position, 4.0)
		var ring := Fx.dust_ring(global_position, 6.0, Color(0.8, 0.76, 0.62))
		battle.add_child(ring)
		ring.emitting = true
		ring.finished.connect(ring.queue_free)
	if now - _born > LIFE:
		_gone = true
		battle.calls.erase(self)
		queue_free()
