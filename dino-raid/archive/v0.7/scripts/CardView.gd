class_name CardView
extends Control
## An offer on the shop's shelf, drawn as a card (GAME-DESIGN 15): a dark frame edged in its rarity's metal, a picture
## of what it builds or does (blocks for now), its price on a gold coin and what else it costs (genes, alien genes)
## beside it, its name on a band and what it does on a parchment slip. A place on the shelf already bought from shows
## an empty frame.

signal clicked(view: CardView)
signal hovered(view: CardView, on: bool)

const SIZE := Vector2(150, 212)
const METAL := [Color(0.72, 0.53, 0.3), Color(0.8, 0.83, 0.88), Color(1.0, 0.82, 0.38)]
const RARITY := ["普通", "少见", "稀有"]
const GROUND := {
	"build": [Color(0.66, 0.8, 0.58), Color(0.2, 0.3, 0.16)],
	"raise": [Color(0.5, 0.58, 0.9), Color(0.14, 0.15, 0.3)],
	"affix": [Color(0.75, 0.55, 0.95), Color(0.22, 0.12, 0.3)],
	"gain": [Color(0.98, 0.78, 0.5), Color(0.5, 0.33, 0.2)],
	"potion": [Color(0.95, 0.7, 0.85), Color(0.35, 0.15, 0.3)],
}
const TYPE := {"build": Color(0.55, 0.8, 0.42), "raise": Color(0.62, 0.7, 1.0), "affix": Color(0.8, 0.6, 1.0),
	"gain": Color(0.95, 0.68, 0.32), "potion": Color(1.0, 0.6, 0.85)}
const GENES := Color(0.3, 0.85, 0.75)
const ALIEN := Color(0.75, 0.4, 0.95)

static var _grounds := {}

var ci: Dictionary = {}
var c: Dictionary = {}
var sold := false
var affordable := true
var chosen := false
var _hover := false


func setup(p_ci: Dictionary) -> void:
	ci = p_ci
	c = Content.offer(ci)
	_frame()


## A place on the shelf already bought from.
func setup_sold() -> void:
	sold = true
	_frame()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _frame() -> void:
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
	c = Content.offer(ci)
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
	if sold:
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0.08, 0.07, 0.06, 0.55)
		empty.border_color = Color(0.45, 0.38, 0.3, 0.6)
		empty.set_border_width_all(2)
		empty.set_corner_radius_all(11)
		empty.draw(get_canvas_item(), Rect2(Vector2.ZERO, SIZE))
		_text(Vector2(SIZE.x * 0.5, 70), "已买", 22, Color(0.75, 0.68, 0.58), Fonts.serif(800), HORIZONTAL_ALIGNMENT_CENTER)
		return
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
	draw_multiline_string(Fonts.serif(500), slip.position + Vector2(5, 13), Content.offer_text(c), HORIZONTAL_ALIGNMENT_LEFT,
		slip.size.x - 10, 11, 4, Color(0.2, 0.14, 0.08))
	_text(Vector2(SIZE.x * 0.5, SIZE.y - 6), "%s · %s" % [Content.TYPES[c.type], RARITY[int(c.rarity)]], 10,
		Color(metal, 0.9), Fonts.serif(600), HORIZONTAL_ALIGNMENT_CENTER)
	var coin := Vector2(18, 18)
	if ci.get("gift", false):
		# A gift: a green token, free.
		draw_circle(coin, 17.0, Color(0.05, 0.1, 0.04))
		draw_circle(coin, 14.5, Color(0.45, 0.85, 0.4) if affordable else Color(0.4, 0.45, 0.4))
		_text(coin + Vector2(0, 6.5), "送", 17, Color(0.08, 0.2, 0.05), Fonts.serif(900), HORIZONTAL_ALIGNMENT_CENTER)
		_extras(full)
		return
	var gold := Color(1.0, 0.82, 0.25) if affordable else Color(0.5, 0.47, 0.42)
	draw_circle(coin, 17.0, Color(0.1, 0.07, 0.02))
	draw_circle(coin, 15.0, gold.darkened(0.3))
	draw_circle(coin, 12.0, gold)
	draw_arc(coin, 9.5, 0.0, TAU, 24, gold.darkened(0.25), 1.5, true)
	var price_text := ("%d+" % c.price) if c.type == "raise" else ("%d" % c.price)
	_text(coin + Vector2(0, 7.5), price_text, 20 if price_text.length() < 2 else 17, Color(0.25, 0.15, 0.0) if affordable
		else Color(0.9, 0.35, 0.3), Fonts.numbers(), HORIZONTAL_ALIGNMENT_CENTER)
	_extras(full)


## What else it costs (genes, alien genes) beside the price -- not for a gift, which costs nothing -- and the shade
## over a card that cannot be bought now.
func _extras(full: Rect2) -> void:
	var x := SIZE.x - 10.0
	for extra in [["alien", "外星", ALIEN], ["genes", "基因", GENES]]:
		if ci.get("gift", false):
			break
		var n := int(c.get(extra[0], 0))
		if n <= 0:
			continue
		var label := "%s %d" % [extra[1], n]
		var w := Fonts.serif(800).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
		var pill := Rect2(x - w, 8, w, 17)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(extra[2], 0.9)
		sb.set_corner_radius_all(8)
		sb.draw(get_canvas_item(), pill)
		_text(Vector2(pill.get_center().x, 21), label, 11, Color(0.05, 0.05, 0.08), Fonts.serif(800), HORIZONTAL_ALIGNMENT_CENTER)
		x -= w + 4.0
	if not affordable:
		draw_rect(full.grow(-3), Color(0, 0, 0, 0.35))


## The picture: a building as blocks of its colour; a raise as a block with an arrow; an affix as what it grows; a
## gain as what it gives.
func _picture(r: Rect2) -> void:
	var mid := r.get_center()
	var gold := Color(1.0, 0.86, 0.45)
	match c.type:
		"build":
			var b: Dictionary = Content.BUILDINGS[c.builds]
			var col: Color = b.color
			if b.has("nest"):
				_block(mid + Vector2(0, 8), 30.0, 34.0, col)
				_block(mid + Vector2(38, 22), 12.0, 12.0, Content.UNITS[b.nest].color)
			else:
				match c.builds:
					"pool":
						_block(mid + Vector2(0, 14), 52.0, 14.0, col.darkened(0.4))
						draw_rect(Rect2(mid + Vector2(-24, 2), Vector2(48, 6)), col.lightened(0.2))
					"sampler":
						_block(mid + Vector2(0, 20), 26.0, 12.0, col.darkened(0.3))
						draw_rect(Rect2(mid + Vector2(-5, -22), Vector2(10, 36)), col)
						draw_circle(mid + Vector2(0, -24), 13.0, col.lightened(0.3))
					"mine":
						_block(mid + Vector2(0, 12), 36.0, 26.0, Color(0.32, 0.32, 0.34))
						draw_circle(mid + Vector2(0, -12), 11.0, col)
					"gym":
						_block(mid + Vector2(0, 22), 50.0, 8.0, col)
						draw_rect(Rect2(mid + Vector2(-22, -18), Vector2(6, 36)), col.darkened(0.3))
						draw_rect(Rect2(mid + Vector2(16, -18), Vector2(6, 36)), col.darkened(0.3))
						draw_rect(Rect2(mid + Vector2(-24, -20), Vector2(48, 5)), col.lightened(0.3))
					"stabilizer":
						draw_rect(Rect2(mid + Vector2(-5, -26), Vector2(10, 50)), col.darkened(0.2))
						for k in 2:
							draw_rect(Rect2(mid + Vector2(-20, -12 + k * 16), Vector2(40, 4)), col.lightened(0.2))
					"lab":
						draw_circle(mid + Vector2(0, 16), 24.0, col)
						draw_rect(Rect2(mid + Vector2(-30, 16), Vector2(60, 16)), Color(0, 0, 0, 0))
						draw_rect(Rect2(mid + Vector2(14, -14), Vector2(6, 18)), col.darkened(0.4))
					"store":
						_block(mid + Vector2(0, 10), 50.0, 28.0, col)
					"wall":
						_block(mid + Vector2(0, 10), 56.0, 24.0, col)
						for k in 4:
							draw_rect(Rect2(mid + Vector2(-26 + k * 14, -10), Vector2(8, 8)), col.darkened(0.2))
		"raise":
			_block(mid + Vector2(-14, 12), 26.0, 18.0, Color(0.6, 0.6, 0.62))
			_block(mid + Vector2(-14, -8), 26.0, 18.0, Color(0.8, 0.8, 0.82))
			_arrow(mid + Vector2(26, 0), gold)
		"affix":
			var a: Dictionary = Content.AFFIXES[c.affix]
			var col: Color = a.color
			_block(mid + Vector2(0, 12), 30.0, 28.0, Color(0.9, 0.24, 0.2))
			match c.affix:
				"shell":
					_block(mid + Vector2(0, -6), 40.0, 8.0, col)
				"blade":
					for sx in [-1.0, 1.0]:
						draw_colored_polygon(PackedVector2Array([mid + Vector2(sx * 18, 0), mid + Vector2(sx * 30, -24),
							mid + Vector2(sx * 24, 4)]), col)
				"acid":
					draw_circle(mid + Vector2(-20, -6), 10.0, col)
					draw_circle(mid + Vector2(24, -14), 4.0, col)
					draw_circle(mid + Vector2(32, -8), 3.0, col)
				"wings":
					for sx in [-1.0, 1.0]:
						draw_colored_polygon(PackedVector2Array([mid + Vector2(sx * 14, -4), mid + Vector2(sx * 46, -24),
							mid + Vector2(sx * 40, 4)]), col)
				"plasma":
					draw_circle(mid + Vector2(0, -16), 12.0, Color(col, 0.35))
					draw_circle(mid + Vector2(0, -16), 7.0, col)
		"potion":
			var col: Color = Content.POTIONS[c.potion].color
			draw_circle(mid + Vector2(0, 10), 22.0, col)
			draw_circle(mid + Vector2(-8, 2), 6.0, Color(1, 1, 1, 0.45))
			draw_rect(Rect2(mid + Vector2(-7, -26), Vector2(14, 16)), col.darkened(0.2))
			draw_rect(Rect2(mid + Vector2(-9, -30), Vector2(18, 5)), Color(0.55, 0.4, 0.25))
		"gain":
			if c.has("gain_genes"):
				for k in 3:
					var y := -22.0 + k * 18.0
					draw_line(mid + Vector2(-16, y), mid + Vector2(16, y + 12), GENES, 4.0, true)
					draw_line(mid + Vector2(16, y), mid + Vector2(-16, y + 12), GENES.darkened(0.3), 4.0, true)
			else:
				draw_circle(mid + Vector2(-10, 6), 16.0, Color(0.35, 0.75, 0.4))
				draw_circle(mid + Vector2(12, 0), 13.0, Color(0.45, 0.85, 0.45))
				draw_circle(mid + Vector2(2, -14), 10.0, Color(0.55, 0.9, 0.5))


## A block seen from a little above: front face, lit top, edge.
func _block(at: Vector2, w: float, h: float, col: Color) -> void:
	var top := minf(w, h) * 0.35
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
