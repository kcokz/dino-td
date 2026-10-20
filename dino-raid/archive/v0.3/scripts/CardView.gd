class_name CardView
extends Control
## A card, drawn (GAME-DESIGN 9): a dark frame edged in its rarity's metal -- bronze, silver, gold -- the
## picture of what it makes on a painted ground, its cost in an amber stone, its name on a band and what it
## does on a parchment slip. Upgraded, its name ends in + and shows green.

signal clicked(view: CardView)
signal hovered(view: CardView, on: bool)

const SIZE := Vector2(150, 212)
const METAL := [Color(0.72, 0.53, 0.3), Color(0.8, 0.83, 0.88), Color(1.0, 0.82, 0.38)]
const RARITY := ["普通", "少见", "稀有"]
const GROUND := {
	"egg": [Color(0.98, 0.78, 0.5), Color(0.5, 0.33, 0.2)],
	"building": [Color(0.7, 0.84, 0.6), Color(0.2, 0.3, 0.16)],
	"help": [Color(0.48, 0.55, 0.86), Color(0.13, 0.14, 0.28)],
}
const TYPE := {"egg": Color(0.95, 0.68, 0.32), "building": Color(0.55, 0.8, 0.42), "help": Color(0.62, 0.7, 1.0)}

static var _grounds := {}

var ci: Dictionary = {}
var c: Dictionary = {}
var art: Texture2D
var affordable := true
var chosen := false
var _hover := false


func setup(p_ci: Dictionary, p_art: Texture2D) -> void:
	ci = p_ci
	c = Rules.card(ci)
	art = p_art
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
	# The picture, on its ground.
	var pic := Rect2(10, 30, SIZE.x - 20, 84)
	draw_texture_rect(_ground(c.type), pic, false)
	if art and c.type == "egg":
		# A dinosaur side-on is long and low: the middle band of its square picture, across the whole window.
		var ts := art.get_size()
		var band := ts.x * pic.size.y / pic.size.x
		draw_texture_rect_region(art, pic, Rect2(0, (ts.y - band) * 0.5 + ts.y * 0.04, ts.x, band))
	elif art:
		var tex_size := art.get_size()
		var k := minf(pic.size.x / tex_size.x, pic.size.y / tex_size.y) * 1.08
		var drawn := tex_size * k
		draw_texture_rect(art, Rect2(pic.get_center() - drawn * 0.5 + Vector2(0, 4), drawn), false)
	else:
		Emblem.paint(self, c.id, pic)
	draw_rect(pic, Color(0, 0, 0, 0.6), false, 1.5)
	draw_line(pic.position + Vector2(0, -1), Vector2(pic.end.x, pic.position.y - 1), TYPE[c.type], 2.0)
	if c.type == "egg":
		var latin: String = Rules.DINOS[c.species].latin
		_text(Vector2(pic.end.x - 4, pic.end.y - 6), latin, 10, Color(1, 1, 1, 0.75), Fonts.serif(400), HORIZONTAL_ALIGNMENT_RIGHT)
	# The name.
	var band := Rect2(6, 116, SIZE.x - 12, 24)
	draw_rect(band, Color(0.05, 0.045, 0.04))
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(metal, 0.7), 1.0)
	var named: String = c.name
	var name_col := Color(0.72, 1.0, 0.62) if ci.get("up", false) else Color(0.97, 0.93, 0.84)
	_text(Vector2(SIZE.x * 0.5, band.position.y + 18), named, 16, name_col, Fonts.serif(700), HORIZONTAL_ALIGNMENT_CENTER)
	# What it does.
	var slip := Rect2(10, 144, SIZE.x - 20, 50)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.9, 0.85, 0.72)
	paper.set_corner_radius_all(4)
	paper.draw(get_canvas_item(), slip)
	draw_multiline_string(Fonts.serif(500), slip.position + Vector2(5, 13), Rules.text(c), HORIZONTAL_ALIGNMENT_LEFT,
		slip.size.x - 10, 11, 4, Color(0.2, 0.14, 0.08))
	_text(Vector2(SIZE.x * 0.5, SIZE.y - 6), "%s · %s" % [Rules.TYPES[c.type], RARITY[int(c.rarity)]], 10,
		Color(metal, 0.9), Fonts.serif(600), HORIZONTAL_ALIGNMENT_CENTER)
	# The cost, in amber.
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
