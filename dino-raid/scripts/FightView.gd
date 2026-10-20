class_name FightView
extends Node3D
## A battle on screen (GAME-DESIGN 14, 17, 23): every fighter where Fight has it (Creatures: ours as their dinosaurs,
## theirs as blocks), facing the other side or the way it runs, running while it moves and standing when it stops; a
## flier flies. A blow flashes what it hits and its number flies off, and the striker bites or shoots; a long reach draws
## its shot; a heal glows green; the fallen fall -- one that bursts throws out a ball of fire, one that breaks lets out
## the smaller ones it held.

const OUR_SHOT := Color(1.0, 0.92, 0.55)
const THEIR_SHOT := Color(0.85, 0.45, 1.0)
const HEAL := Color(0.45, 1.0, 0.5)

var fight: Fight
var tags: Tags
var pace := 1.0                   # how fast the battle runs (Game.speed): the creatures' clips keep up
var _nodes := {}                  # fighter id -> Node3D


func setup(f: Fight) -> void:
	clear()
	fight = f
	for u in f.units:
		_add(u)


func _add(u: Dictionary) -> Node3D:
	var c: Color = (Content.UNITS if u.side == "ours" else Content.ENEMIES)[u.kind].color
	var n := Creatures.make(float(u.size), c, u.side == "theirs", u.affixes, u.kind, int(u.get("elite", 0)))
	n.rotation.y = _facing(u)
	n.position = place(u)
	add_child(n)
	_nodes[u.id] = n
	return n


func clear() -> void:
	for n in _nodes.values():
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	fight = null


## Where a fighter stands in the world (a flier, in the air).
static func place(u: Dictionary) -> Vector3:
	var p: Vector2 = u.pos
	return World.ARENA + Vector3(p.x, World.GROUND_TOP + (1.4 if u.dive else 0.0), p.y)


func node(id: int) -> Node3D:
	return _nodes.get(id)


## The scavengers standing at the end, each with the gold it brings back over it.
func show_loot() -> void:
	if fight == null:
		return
	for u in fight.alive("ours"):
		var n: Node3D = _nodes.get(u.id)
		if u.get("scavenge", false) and n:
			tags.float_text(n.position + Vector3.UP * (float(u.size) + 0.8), "+%d 金" % Content.SCAVENGE,
				Color(1.0, 0.82, 0.3), 22)


func _process(delta: float) -> void:
	if fight == null:
		return
	var k := 1.0 - exp(-delta * 14.0)
	var turn := 1.0 - exp(-delta * 8.0)
	for u in fight.units:
		if int(u.hp) <= 0:
			continue
		var n: Node3D = _nodes.get(u.id)
		if n == null:
			continue
		var to := place(u)
		var step := to - n.position
		step.y = 0.0
		var moving := step.length() > 0.04
		n.position = n.position.lerp(to, k)
		var want := atan2(step.x, step.z) if moving else _facing(u)
		n.rotation.y = lerp_angle(n.rotation.y, want, turn)
		Creatures.pace(n, moving, pace)


## Which way a fighter looks while it stands: at the other side.
static func _facing(u: Dictionary) -> float:
	return PI * 0.5 if u.side == "ours" else -PI * 0.5


## A step's events, shown.
func show_events(ev: Array) -> void:
	var struck := {}
	for e in ev:
		match e.t:
			"hit":
				var a: Variant = fight.unit(e.from)
				var b: Variant = fight.unit(e.to)
				var na: Node3D = _nodes.get(e.from)
				var nb: Node3D = _nodes.get(e.to)
				if a == null or b == null or na == null or nb == null:
					continue
				Creatures.flash(nb, Color.WHITE, 0.6)
				if Creatures.is_model(nb) and not Creatures.is_busy(nb) and int(b.hp) > 0:
					Creatures.busy(nb, "batter", pace)
				if tags:
					var c := Color(1.0, 0.4, 0.32) if b.side == "ours" else Color(1.0, 0.96, 0.86)
					tags.float_text(nb.position + Vector3.UP * (float(b.size) + 0.5), "-%d" % e.dmg, c, 18)
					if e.get("charge", false):
						tags.float_text(na.position + Vector3.UP * (float(a.size) + 1.2), "冲锋！", Color(1.0, 0.85, 0.4), 20)
				if struck.has(e.from):
					continue
				struck[e.from] = true
				if float(a.range) >= 3.0:
					_shot(na, nb, OUR_SHOT if a.side == "ours" else THEIR_SHOT)
					if Creatures.is_model(na):
						Creatures.busy(na, "attack", pace)
				else:
					Creatures.lunge(na, nb.position - na.position, pace)
			"heal":
				var na: Node3D = _nodes.get(e.from)
				var nb: Node3D = _nodes.get(e.to)
				if na == null or nb == null:
					continue
				_shot(na, nb, HEAL)
				Creatures.flash(nb, HEAL, 0.8)
				if tags:
					tags.float_text(nb.position + Vector3.UP * 1.6, "+%d" % e.amount, HEAL, 18)
			"die":
				var n: Node3D = _nodes.get(e.id)
				if n:
					Creatures.fall(n, pace)
			"burst":
				_burst(World.ARENA + Vector3((e.at as Vector2).x, World.GROUND_TOP + 0.6, (e.at as Vector2).y), float(e.radius))
			"spawn":
				var n := _add(e.unit)
				n.scale = Vector3.ONE * 0.2
				var tw := n.create_tween()
				tw.tween_property(n, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A burst: a ball of fire swelling to its reach and gone.
func _burst(at: Vector3, radius: float) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.55, 0.15, 0.75)
	var ball := Blocks.ball(1.0, Color.WHITE, at)
	ball.material_override = m
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.scale = Vector3.ONE * 0.2
	add_child(ball)
	var tw := ball.create_tween().set_parallel()
	tw.tween_property(ball, "scale", Vector3.ONE * radius, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(ball.queue_free)
	if tags:
		tags.float_text(at + Vector3.UP * 1.5, "炸！", Color(1.0, 0.6, 0.2), 22)


## A long-reach blow (or a heal): a streak from one to the other, gone at once.
func _shot(na: Node3D, nb: Node3D, c: Color) -> void:
	var from := na.position + Vector3.UP * Creatures.height(na) * 0.75
	var to := nb.position + Vector3.UP * Creatures.height(nb) * 0.5
	var length := from.distance_to(to)
	if length < 0.2 or Vector2(to.x - from.x, to.z - from.z).length() < 0.05:
		return                   # a healer mending itself: no streak
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, length)
	var streak := MeshInstance3D.new()
	streak.mesh = mesh
	streak.material_override = m
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(streak)
	streak.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var tw := streak.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(streak.queue_free)
