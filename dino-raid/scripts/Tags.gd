class_name Tags
extends Control
## Words and bars drawn over the blocks each frame (GAME-DESIGN 12): over a nest what it makes and when (what a
## building is and does, the panel says when it is pointed at); stars over a unit of two or three; in a battle
## each fighter's health; numbers rising off what was hit.

const OURS := Color(0.47, 0.86, 0.36)
const THEIRS := Color(0.96, 0.36, 0.26)
const GOLD := Color(1.0, 0.82, 0.3)

var game: Game
var _floats: Array = []          # {at: Vector3, text, colour, size, born}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Words rising off a point in the world, fading.
func float_text(at: Vector3, text: String, colour: Color, size := 20) -> void:
	_floats.append({"at": at, "text": text, "colour": colour, "size": size, "born": Time.get_ticks_msec()})


func _draw() -> void:
	if game == null or game.camera == null or game.hud.screen != "":
		return
	var cam := game.camera
	if game.at_home:
		_home(cam)
	elif game.fight != null:
		_battle(cam)
	var now := Time.get_ticks_msec()
	for f in _floats.duplicate():
		var age := (now - int(f.born)) / 1000.0
		if age > 1.3:
			_floats.erase(f)
			continue
		var p: Vector3 = f.at + Vector3.UP * age * 1.8
		if cam.is_position_behind(p):
			continue
		var c: Color = f.colour
		c.a = 1.0 - maxf(0.0, age - 0.8) / 0.5
		_text(cam.unproject_position(p), f.text, c, int(f.size), Fonts.numbers() if f.text.is_valid_int() else Fonts.serif(800))


func _home(cam: Camera3D) -> void:
	var home: Home = game.home
	var hv: HomeView = game.home_view
	# A full yard is said at the top left and when the nests find no room, not over every nest.
	for p in home.buildings:
		var b: Dictionary = home.buildings[p]
		var l := home.level_of(p)
		if not l.has("makes") or home.units.size() >= home.room():
			continue
		var at3 := hv.top(p) + Vector3.UP * 0.3
		if cam.is_position_behind(at3):
			continue
		var at := cam.unproject_position(at3)
		var line := "下轮 +%d" % l.count if int(b.wait) <= 1 else "%d 轮后 +%d" % [b.wait, l.count]
		var col := GOLD
		var f := Fonts.serif(800)
		var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var square := Rect2(at + Vector2(-w * 0.5 - 9.0, -6.0), Vector2(12, 12))
		draw_rect(square.grow(1.5), Color(0, 0, 0, 0.8))
		draw_rect(square, Content.UNITS[l.makes].color)
		_text(at + Vector2(9.0, 0.0), line, col, 14, f)
	for u in home.units:
		if int(u.star) < 2:
			continue
		var n := hv.unit_node(u.id)
		if n == null or not n.visible:
			continue
		var at3 := n.position + Vector3.UP * (float(n.get_meta("edge", 1.0)) + 0.35)
		if not cam.is_position_behind(at3):
			_stars(cam.unproject_position(at3), int(u.star), 6.0)


func _battle(cam: Camera3D) -> void:
	var f: Fight = game.fight
	for u in f.units:
		if int(u.hp) <= 0:
			continue
		var n: Node3D = game.fight_view.node(u.id)
		if n == null:
			continue
		var at3 := n.position + Vector3.UP * (float(u.size) + 0.35)
		if cam.is_position_behind(at3):
			continue
		var at := cam.unproject_position(at3)
		var w := clampf(16.0 + float(u.max) * 0.55, 22.0, 64.0)
		var r := Rect2(at - Vector2(w * 0.5, 3.0), Vector2(w, 6.0))
		draw_rect(r.grow(1.5), Color(0.04, 0.04, 0.04, 0.85))
		var frac := clampf(float(u.hp) / float(u.max), 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(w * frac, r.size.y)), OURS if u.side == "ours" else THEIRS)
		if int(u.star) >= 2:
			_stars(at + Vector2(0, -11), int(u.star), 5.0)


## n small gold stars in a row.
func _stars(at: Vector2, n: int, r: float) -> void:
	for i in n:
		var c := at + Vector2((i - (n - 1) * 0.5) * r * 2.2, 0)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + TAU * k / 10.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_colored_polygon(pts, GOLD)
		draw_polyline(ring, Color(0.25, 0.15, 0.0, 0.9), 1.2, true)


func _text(at: Vector2, text: String, c: Color, size: int, f: Font) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, size * 0.35)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, c.a * 0.85))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
