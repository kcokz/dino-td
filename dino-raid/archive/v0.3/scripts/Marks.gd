class_name Marks
extends Control
## The battle's marks, drawn over the scene each frame: every piece's health; and, while the player plans, what
## ending the turn will do -- the coming blows on each piece's bar and as numbers, a skull on whatever will
## fall, who will strike and how hard, the eggs about to hatch. Numbers float up off what was just hit.

const DINO := Color(0.47, 0.86, 0.36)
const ROBOT := Color(0.96, 0.42, 0.26)
const LOSS := Color(1.0, 0.92, 0.85)
const AMBER := Color(1.0, 0.76, 0.3)

var battle: Node
var font: Font
var bold: Font
var shown := {}                  # from Battle: what the coming turn does (see Battle._read_preview)
var _floats: Array = []          # {at: Vector3, text, colour, born}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## A number rising off a piece: "-8" in red, "+3" in green.
func float_text(at: Vector3, text: String, colour: Color) -> void:
	_floats.append({"at": at, "text": text, "colour": colour, "born": Time.get_ticks_msec()})


func _draw() -> void:
	var cam: Camera3D = battle.camera
	if cam == null:
		return
	var planning: bool = battle.planning
	for v in battle.views.values():
		if not is_instance_valid(v) or v.hp <= 0:
			continue
		var at3: Vector3 = v.global_position + Vector3.UP * (v.top * v.scale.y + 0.4)
		if cam.is_position_behind(at3):
			continue
		var at := cam.unproject_position(at3)
		var hit: int = shown.get("dmg", {}).get(v.id, 0) if planning else 0
		_bar(at, v, hit)
		if planning:
			var deal: int = shown.get("deal", {}).get(v.id, 0)
			if deal > 0:
				_badge(at + Vector2(-_width(v) * 0.5 - 16.0, 0.0), deal, v.side == "robot")
			if hit > 0:
				var dies: bool = shown.get("dies", {}).has(v.id)
				_shadowed(at + Vector2(0, -18), ("-%d" % hit), Color(1.0, 0.3, 0.25), 20, bold)
				if dies:
					_skull(at + Vector2(_width(v) * 0.5 + 14.0, -4.0))
	for nv in battle.nest_views.values():
		if not is_instance_valid(nv):
			continue
		var at3: Vector3 = nv.global_position + Vector3.UP * 1.6
		if cam.is_position_behind(at3):
			continue
		var at := cam.unproject_position(at3)
		_nest(at, nv, planning)
	var now := Time.get_ticks_msec()
	for f in _floats.duplicate():
		var age := (now - int(f.born)) / 1000.0
		if age > 1.2:
			_floats.erase(f)
			continue
		var p: Vector3 = f.at + Vector3.UP * age * 2.2
		if cam.is_position_behind(p):
			continue
		var c: Color = f.colour
		c.a = 1.0 - maxf(0.0, age - 0.7) / 0.5
		_shadowed(cam.unproject_position(p), f.text, c, 24, bold)


func _width(v: Node) -> float:
	return clampf(26.0 + v.max_hp * 0.9, 34.0, 84.0)


## A health bar: the blows to come shown pale at its end.
func _bar(at: Vector2, v: Node, hit: int) -> void:
	var w := _width(v)
	var r := Rect2(at - Vector2(w * 0.5, 4.0), Vector2(w, 8.0))
	draw_rect(r.grow(1.5), Color(0.04, 0.04, 0.04, 0.85))
	var frac := clampf(float(v.hp) / maxf(1.0, v.max_hp), 0.0, 1.0)
	var after := clampf(float(v.hp - hit) / maxf(1.0, v.max_hp), 0.0, 1.0)
	var fill: Color = DINO if v.side == "dino" else ROBOT
	draw_rect(Rect2(r.position, Vector2(w * after, r.size.y)), fill)
	if after < frac:
		var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
		draw_rect(Rect2(r.position + Vector2(w * after, 0), Vector2(w * (frac - after), r.size.y)), Color(LOSS, blink))
	# A pack: a notch between each animal.
	if v.side == "dino" and Rules.DINOS[v.kind].get("small", false):
		var body: float = Rules.DINOS[v.kind].hp
		var n := int(ceil(v.max_hp / body))
		for i in range(1, n):
			var x := r.position.x + w * i / n
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.8), 1.5)
	if font:
		_shadowed(at + Vector2(0, 15), "%d" % v.hp, Color(1, 1, 1, 0.85), 12, font)


## Who strikes this turn and how hard: claws for a dinosaur, a gunsight for a robot.
func _badge(at: Vector2, n: int, robot: bool) -> void:
	var c := ROBOT if robot else AMBER
	draw_circle(at, 13.0, Color(0.05, 0.05, 0.05, 0.9))
	draw_arc(at, 13.0, 0.0, TAU, 24, c, 2.0, true)
	if robot:
		draw_arc(at, 6.0, 0.0, TAU, 16, c, 1.6, true)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(at + d * 3.0, at + d * 9.5, c, 1.6, true)
	else:
		for k in 3:
			var x := (k - 1) * 4.5
			draw_line(at + Vector2(x - 2.5, -7.0), at + Vector2(x + 2.5, 7.0), c, 2.2, true)
	_shadowed(at + Vector2(0, 26), "%d" % n, c, 17, bold)


func _skull(at: Vector2) -> void:
	var bone := Color(0.95, 0.93, 0.88)
	draw_circle(at, 9.0, bone)
	draw_rect(Rect2(at + Vector2(-5.5, 4.0), Vector2(11.0, 6.0)), bone)
	draw_circle(at + Vector2(-3.4, -0.5), 2.6, Color(0.05, 0.05, 0.05))
	draw_circle(at + Vector2(3.4, -0.5), 2.6, Color(0.05, 0.05, 0.05))
	for k in 3:
		draw_line(at + Vector2(-3.0 + k * 3.0, 6.0), at + Vector2(-3.0 + k * 3.0, 10.0), Color(0.05, 0.05, 0.05), 1.2)


## A nest: an egg with the turns until the next hatches -- "孵" when it is this turn, "停" when a robot near
## keeps a tyrannosaur's eggs still; its health when it has been hit.
func _nest(at: Vector2, nv: Node, planning: bool) -> void:
	var s: BattleState = battle.state
	var n: Variant = s.nest(nv.id)
	if n == null:
		return
	var hit: int = shown.get("nest_dmg", {}).get(nv.id, 0) if planning else 0
	if nv.hp < nv.max_hp or hit > 0:
		var w := 44.0
		var r := Rect2(at + Vector2(-w * 0.5, 22.0), Vector2(w, 6.0))
		draw_rect(r.grow(1.5), Color(0.04, 0.04, 0.04, 0.85))
		var after := clampf(float(nv.hp - hit) / nv.max_hp, 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(w * after, r.size.y)), Color(0.9, 0.78, 0.45))
		if hit > 0:
			_shadowed(at + Vector2(0, 46), "-%d" % hit, Color(1.0, 0.3, 0.25), 18, bold)
			if shown.get("nest_lost", {}).has(nv.id):
				_skull(at + Vector2(32, 25))
	if int(n.eggs) <= 0:
		return
	var egg := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		egg.append(at + Vector2(cos(a) * 10.0, sin(a) * 13.0 + (2.0 if sin(a) > 0 else 0.0)))
	draw_colored_polygon(egg, Color(0.95, 0.9, 0.78))
	draw_polyline(egg + PackedVector2Array([egg[0]]), Color(0.25, 0.18, 0.1), 1.5, true)
	var left := Sim.turns_left(s, n)
	var text := "%d" % left
	var c := Color(0.25, 0.16, 0.08)
	if Sim.paused(s, n):
		text = "停"
		c = Color(0.75, 0.15, 0.1)
	elif left == 0:
		text = "孵"
		c = Color(0.1, 0.45, 0.1)
	_centred(at + Vector2(0, 6), text, c, 15, bold)


func _shadowed(at: Vector2, text: String, c: Color, size: int, f: Font) -> void:
	if f == null:
		return
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, size * 0.35)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, c.a * 0.85))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _centred(at: Vector2, text: String, c: Color, size: int, f: Font) -> void:
	if f == null:
		return
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, at + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
