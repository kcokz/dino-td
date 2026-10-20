class_name CardView
extends Control
## A card, drawn (GAME-DESIGN 12): a dark frame edged in its rarity's metal, a picture of what it builds or
## does (blocks for now), its cost in an amber stone, its name on a band and what it does on a parchment slip.
## Upgraded, its name ends in + and shows green.

signal clicked(view: CardView)
signal hovered(view: CardView, on: bool)

const SIZE := Vector2(150, 212)
const METAL := [Color(0.72, 0.53, 0.3), Color(0.8, 0.83, 0.88), Color(1.0, 0.82, 0.38)]
const RARITY := ["普通", "少见", "稀有"]
const GROUND := {
	"build": [Color(0.66, 0.8, 0.58), Color(0.2, 0.3, 0.16)],
	"buff": [Color(0.98, 0.78, 0.5), Color(0.5, 0.33, 0.2)],
	"upgrade": [Color(0.5, 0.58, 0.9), Color(0.14, 0.15, 0.3)],
}
const TYPE := {"build": Color(0.55, 0.8, 0.42), "buff": Color(0.95, 0.68, 0.32), "upgrade": Color(0.62, 0.7, 1.0)}

static var _grounds := {}

var ci: Dictionary = {}
var c: Dictionary = {}
var affordable := true
var chosen := false
var _hover := false


func setup(p_ci: Dictionary) -> void:
	ci = p_ci
	c = Content.card(ci)
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = Vector2(SIZE.x * 0.5, SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		hovered.emit(self, true)
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		hovered.emit(self, false)
		queue_redraw())
	queue_redraw()


## Shows `p_ci` instead (an upgrade looked at), drawn again.
func show_as(p_ci: Dictionary) -> void:
	ci = p_ci
	c = Content.card(ci)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


func set_state(p_affordable: bool, p_chosen: bool) -> void:
	if affordable != p_affordable or chosen != p_chosen:
		affordable = p_affordable
		chosen = p_chosen
		queue_redraw()


func _draw() -> void:
	if c.is_empty():
		return
	var metal: Color = METAL[int(c.rarity)]
	var full := Rect2(Vector2.ZERO, SIZE)
	if chosen or _hover:
		var halo := StyleBoxFlat.new()
		halo.bg_color = Color(1.0, 0.85, 0.45, 0.0)
		halo.set_corner_radius_all(14)
		halo.shadow_color = Color(1.0, 0.8, 0.35, 0.75 if chosen else 0.35)
		halo.shadow_size = 12 if chosen else 7
		halo.draw(get_canvas_item(), full)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.11, 0.095, 0.08)
	frame.border_color = metal
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(11)
	frame.shadow_color = Color(0, 0, 0, 0.55)
	frame.shadow_size = 5
	frame.shadow_offset = Vector2(0, 3)
	frame.draw(get_canvas_item(), full)
	draw_rect(Rect2(6, 6, SIZE.x - 12, SIZE.y - 12), Color(metal, 0.18), false, 1.0)
	var pic := Rect2(10, 30, SIZE.x - 20, 84)
	draw_texture_rect(_ground(c.type), pic, false)
	_picture(pic)
	draw_rect(pic, Color(0, 0, 0, 0.6), false, 1.5)
	draw_line(pic.position + Vector2(0, -1), Vector2(pic.end.x, pic.position.y - 1), TYPE[c.type], 2.0)
	var band := Rect2(6, 116, SIZE.x - 12, 24)
	draw_rect(band, Color(0.05, 0.045, 0.04))
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(metal, 0.7), 1.0)
	var name_col := Color(0.72, 1.0, 0.62) if ci.get("up", false) else Color(0.97, 0.93, 0.84)
	_text(Vector2(SIZE.x * 0.5, band.position.y + 18), c.name, 16, name_col, Fonts.serif(700), HORIZONTAL_ALIGNMENT_CENTER)
	var slip := Rect2(10, 144, SIZE.x - 20, 50)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.9, 0.85, 0.72)
	paper.set_corner_radius_all(4)
	paper.draw(get_canvas_item(), slip)
	draw_multiline_string(Fonts.serif(500), slip.position + Vector2(5, 13), Content.text(c), HORIZONTAL_ALIGNMENT_LEFT,
		slip.size.x - 10, 11, 4, Color(0.2, 0.14, 0.08))
	_text(Vector2(SIZE.x * 0.5, SIZE.y - 6), "%s · %s" % [Content.TYPES[c.type], RARITY[int(c.rarity)]], 10,
		Color(metal, 0.9), Fonts.serif(600), HORIZONTAL_ALIGNMENT_CENTER)
	var gem := Vector2(17, 17)
	var amber := Color(1.0, 0.68, 0.22) if affordable else Color(0.45, 0.42, 0.4)
	draw_circle(gem, 16.5, Color(0.08, 0.06, 0.04))
	draw_circle(gem, 14.0, amber.darkened(0.35))
	draw_circle(gem + Vector2(-1.5, -1.5), 11.5, amber)
	draw_circle(gem + Vector2(-4.5, -5.0), 3.5, Color(1, 1, 1, 0.45))
	_text(gem + Vector2(0, 7.5), "%d" % c.cost, 22, Color.WHITE if affordable else Color(1.0, 0.45, 0.4),
		Fonts.numbers(), HORIZONTAL_ALIGNMENT_CENTER, 4)
	if not affordable:
		draw_rect(full.grow(-3), Color(0, 0, 0, 0.35))


## The picture: a building as a block of its colour; a unit's card as its unit; a buff or upgrade as a sign.
func _picture(r: Rect2) -> void:
	var mid := r.get_center()
	if c.type == "build":
		var b: Dictionary = Content.BUILDINGS[c.builds]
		_block(mid + Vector2(0, 8), 30.0, 36.0, b.color)
		var l: Dictionary = b.levels[0]
		if l.has("makes"):
			_block(mid + Vector2(40, 22), 12.0, 12.0, Content.UNITS[l.makes].color)
		return
	var gold := Color(1.0, 0.86, 0.45)
	if c.has("battle"):
		var b: Dictionary = c.battle
		if b.has("atk"):
			_arrow(mid, gold)
		elif b.has("armor"):
			_shield(mid, Color(0.82, 0.86, 0.92))
		else:
			_bolt(mid, gold)
	elif c.has("mend"):
		draw_circle(mid + Vector2(-9, -4), 12.0, Color(0.9, 0.25, 0.25))
		draw_circle(mid + Vector2(9, -4), 12.0, Color(0.9, 0.25, 0.25))
		draw_colored_polygon(PackedVector2Array([mid + Vector2(-20, 1), mid + Vector2(20, 1), mid + Vector2(0, 24)]),
			Color(0.9, 0.25, 0.25))
	elif c.has("unit"):
		_block(mid + Vector2(-10, 8), 20.0, 20.0, Content.UNITS.red.color)
		_arrow(mid + Vector2(22, 0), gold)
	elif c.has("level_up"):
		_block(mid + Vector2(-14, 12), 26.0, 18.0, Color(0.6, 0.6, 0.62))
		_block(mid + Vector2(-14, -8), 26.0, 18.0, Color(0.8, 0.8, 0.82))
		_arrow(mid + Vector2(26, 0), gold)
	elif c.has("star_up"):
		_star(mid, 26.0, gold)
	elif c.has("make_now"):
		_block(mid + Vector2(-12, 8), 28.0, 28.0, Content.BUILDINGS.hatch_red.color)
		for k in 2:
			_block(mid + Vector2(16 + k * 14, 22), 10.0, 10.0, Content.UNITS.red.color)


## A block seen from a little above: front face, lit top, edge.
func _block(at: Vector2, w: float, h: float, col: Color) -> void:
	var top := w * 0.35
	var front := Rect2(at.x - w * 0.5, at.y - h * 0.5, w, h)
	draw_rect(front, col.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([front.position, front.position + Vector2(top * 0.5, -top),
		Vector2(front.end.x + top * 0.5, front.position.y - top), Vector2(front.end.x, front.position.y)]), col.lightened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(front.end.x, front.position.y), Vector2(front.end.x + top * 0.5, front.position.y - top),
		Vector2(front.end.x + top * 0.5, front.end.y - top), front.end]), col.darkened(0.4))
	draw_rect(front, Color(0, 0, 0, 0.5), false, 1.0)


func _arrow(at: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -26), at + Vector2(18, -4), at + Vector2(7, -4),
		at + Vector2(7, 22), at + Vector2(-7, 22), at + Vector2(-7, -4), at + Vector2(-18, -4)]), col)


func _shield(at: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(-20, -22), at + Vector2(20, -22), at + Vector2(20, 2),
		at + Vector2(0, 26), at + Vector2(-20, 2)]), col)
	draw_line(at + Vector2(0, -20), at + Vector2(0, 22), col.darkened(0.3), 3.0)


func _bolt(at: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(4, -28), at + Vector2(-14, 4), at + Vector2(-1, 4),
		at + Vector2(-6, 28), at + Vector2(14, -6), at + Vector2(1, -6)]), col)


func _star(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


func _text(at: Vector2, text: String, size_px: int, col: Color, f: Font, align: int, outline := 0) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	if outline > 0:
		draw_string_outline(f, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, outline, Color(0, 0, 0, 0.9))
	draw_string(f, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


static func _ground(type: String) -> Texture2D:
	if not _grounds.has(type):
		var g := Gradient.new()
		g.set_color(0, GROUND[type][0])
		g.set_color(1, GROUND[type][1])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		t.width = 8
		t.height = 64
		_grounds[type] = t
	return _grounds[type]
