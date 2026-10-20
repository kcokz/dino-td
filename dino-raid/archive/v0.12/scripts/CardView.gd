class_name CardView
extends Control
## An offer on the shop's shelf, drawn as a card (GAME-DESIGN 15, 17, 21): ink with cut corners, edged in its rarity's
## metal (bronze, silver, gold) with a finer rule inside and a diamond at each corner; a window with its picture taken
## from the model (Portraits) -- drawn flat until the picture is ready; its price set in amber and what else it costs
## (genes, alien genes) beside it; its name on a dark ribbon, what it does on a parchment slip, what kind it is at its
## foot. A good already had -- kept in the stash, given, or carried from the last place -- shows a jade token instead of
## a price: 存, 送, 带. A place on the shelf already bought from shows an empty frame.

signal clicked(view: CardView)
signal hovered(view: CardView, on: bool)

const SIZE := Vector2(150, 212)
const METAL := [Color(0.72, 0.53, 0.3), Color(0.8, 0.83, 0.88), Color(1.0, 0.82, 0.38)]
const RARITY := ["普通", "少见", "稀有"]
const GROUND := {
	"build": [Color(0.66, 0.8, 0.58), Color(0.2, 0.3, 0.16)],
	"raise": [Color(0.5, 0.58, 0.9), Color(0.14, 0.15, 0.3)],
	"affix": [Color(0.75, 0.55, 0.95), Color(0.22, 0.12, 0.3)],
}
const TYPE := {"build": Color(0.55, 0.8, 0.42), "raise": Color(0.62, 0.7, 1.0), "affix": Color(0.8, 0.6, 1.0)}
const GENES := Color(0.3, 0.85, 0.75)
const ALIEN := Color(0.75, 0.4, 0.95)

static var _grounds := {}

var ci: Dictionary = {}
var c: Dictionary = {}
var sold := false
var sold_label := "已买"
var kept := false                 # had already (in the stash): no price
var affordable := true
var chosen := false
var marked := false               # its kind is about to be taken out of the shop: ringed red
var genes_shown := -1             # the genes it costs here (Home.genes_cost), or -1 for what it says
var _hover := false


func setup(p_ci: Dictionary, p_kept := false) -> void:
	ci = p_ci
	kept = p_kept
	c = Content.offer(ci)
	_frame()


## The token a good already had shows instead of a price: "" for one still to buy.
func token() -> String:
	if ci.has("packed"):
		return "带"
	if ci.get("gift", false):
		return "送"
	return "存" if kept else ""


## A place on the shelf already bought from (or its kind taken out of the shop: `label`).
func setup_sold(label := "已买") -> void:
	sold = true
	sold_label = label
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


func set_marked(on: bool) -> void:
	if marked != on:
		marked = on
		queue_redraw()


func _draw() -> void:
	var rid := get_canvas_item()
	var full := Rect2(Vector2.ZERO, SIZE)
	if sold:
		Style.fill(rid, full, 12.0, Color(0.03, 0.04, 0.045, 0.5), Color(0.02, 0.025, 0.03, 0.5))
		Style.ring(rid, full.grow(-1.0), 12.0, Color(Style.GOLD_DIM, 0.55), 1.2)
		Style.ring(rid, full.grow(-6.0), 9.0, Color(Style.GOLD_DIM, 0.25), 1.0)
		_text(Vector2(SIZE.x * 0.5, 108), sold_label, 20, Style.PARCHMENT_DIM, Fonts.serif(800), HORIZONTAL_ALIGNMENT_CENTER, 4)
		return
	if c.is_empty():
		return
	var metal: Color = METAL[int(c.rarity)]
	if chosen or _hover:
		for i in 4:
			var g := 2.0 + i * 2.6
			Style.ring(rid, full.grow(g), 12.0 + g * 0.6, Color(Style.GOLD_BRIGHT, (0.55 if chosen else 0.3) * (1.0 - i / 4.0)), 2.6)
	Style.fill(rid, full, 12.0, Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), Vector2(0, 4))
	Style.fill(rid, full, 12.0, Color(0.1, 0.12, 0.125), Color(0.035, 0.045, 0.05))
	Style.ring(rid, full.grow(-1.0), 12.0, metal, 2.0)
	Style.ring(rid, full.grow(-5.5), 9.0, Color(metal, 0.4), 1.0)
	for corner in [Vector2(6, 6), Vector2(SIZE.x - 6, 6), Vector2(SIZE.x - 6, SIZE.y - 6), Vector2(6, SIZE.y - 6)]:
		Style.diamond(rid, corner, 2.6, metal.lightened(0.2))
	# The window and its picture.
	var art := Rect2(12, 30, SIZE.x - 24, 80)
	Style.fill(rid, art, 6.0, (GROUND[c.type][0] as Color).darkened(0.45), (GROUND[c.type][1] as Color).darkened(0.35))
	var tex := Portraits.of_offer(c, func(_t: Texture2D) -> void:
		if is_instance_valid(self):
			queue_redraw())
	if tex != null:
		var k := minf(art.size.x / tex.get_width(), art.size.y / tex.get_height())
		var sz := Vector2(tex.get_width(), tex.get_height()) * k
		draw_texture_rect(tex, Rect2(art.get_center() - sz * 0.5, sz), false)
		if c.type == "raise":
			_arrow(art.get_center() + Vector2(36, 8), Style.GOLD_BRIGHT)
	else:
		_picture(art)
	Style.ring(rid, art, 6.0, Color(metal, 0.8), 1.2)
	if c.type == "build" and Content.is_nest(c.builds):
		# Its gift's name on a little tab across the window's top edge.
		var gift: String = Content.TRAITS[Content.BUILDINGS[c.builds].trait].name
		var gw := Fonts.serif(800).get_string_size(gift, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tab := Rect2(art.get_center().x - gw * 0.5 - 10, art.position.y - 9, gw + 20, 18)
		Style.fill(rid, tab, 5.0, Color(0.09, 0.11, 0.115), Color(0.03, 0.04, 0.045))
		Style.ring(rid, tab, 5.0, Color(metal, 0.9), 1.0)
		_text(Vector2(tab.get_center().x, tab.position.y + 13.5), gift, 12, Style.GOLD_BRIGHT, Fonts.serif(800),
			HORIZONTAL_ALIGNMENT_CENTER)
	# The name on its ribbon.
	var band := Rect2(8, 114, SIZE.x - 16, 24)
	Style.fill(rid, band, 4.0, Color(0.06, 0.07, 0.075), Color(0.025, 0.03, 0.035))
	for y in [band.position.y, band.end.y]:
		draw_line(Vector2(band.position.x + 6, y), Vector2(band.end.x - 6, y), Color(metal, 0.75), 1.0, true)
	var name_size := 16
	while name_size > 10 and Fonts.serif(800).get_string_size(c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > band.size.x - 8:
		name_size -= 1
	_text(Vector2(SIZE.x * 0.5, band.position.y + 17.5), c.name, name_size, Style.PARCHMENT, Fonts.serif(800),
		HORIZONTAL_ALIGNMENT_CENTER)
	# What it does, on parchment.
	var slip := Rect2(11, 142, SIZE.x - 22, 52)
	Style.fill(rid, slip, 4.0, Color(0.95, 0.9, 0.78), Color(0.85, 0.79, 0.66))
	Style.ring(rid, slip, 4.0, Color(0.42, 0.31, 0.18, 0.55), 1.0)
	draw_multiline_string(Fonts.serif(600), slip.position + Vector2(6, 15), Content.offer_text(c), HORIZONTAL_ALIGNMENT_LEFT,
		slip.size.x - 12, 11, 3, Color(0.22, 0.14, 0.07))
	_text(Vector2(SIZE.x * 0.5, SIZE.y - 6), footer(), 10, Color(metal, 0.95), Fonts.serif(700), HORIZONTAL_ALIGNMENT_CENTER)
	if marked:
		Style.fill(rid, full, 12.0, Color(0.45, 0.05, 0.03, 0.42), Color(0.3, 0.02, 0.02, 0.5))
		Style.ring(rid, full.grow(-1.0), 12.0, Style.CORAL, 3.0)
		_text(Vector2(SIZE.x * 0.5, 98), "去掉", 28, Color(1.0, 0.88, 0.82), Fonts.serif(900), HORIZONTAL_ALIGNMENT_CENTER, 7)
	if token() != "":
		_gem(Vector2(21, 21), token(), Style.JADE, Fonts.serif(900), 16, true)
	else:
		var price_text := ("%d+" % c.price) if c.type == "raise" else ("%d" % c.price)
		_gem(Vector2(21, 21), price_text, Style.AMBER, Fonts.display(900), 19 if price_text.length() < 2 else 15, affordable)
	_extras(full)


## A cut stone in a dark setting, ringed in gold, with its figure on it: amber for a price, jade for a good had already
## -- grey when it cannot be paid.
func _gem(at: Vector2, text: String, col: Color, f: Font, size_px: int, lit: bool) -> void:
	var rid := get_canvas_item()
	if not lit:
		col = Color(0.48, 0.45, 0.42)
	draw_circle(at + Vector2(0, 2), 18.0, Color(0, 0, 0, 0.5))
	draw_circle(at, 18.0, Style.INK_DEEP)
	draw_arc(at, 16.5, 0.0, TAU, 40, Style.GOLD if lit else Style.GOLD_DIM, 1.6, true)
	var body := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 8:
		var p := at + Vector2.from_angle(PI / 8.0 + i * PI / 4.0) * 14.5
		body.append(p)
		cols.append(col.lightened(0.35).lerp(col.darkened(0.35), clampf((p.y - at.y + 14.5) / 29.0, 0.0, 1.0)))
	draw_polygon(body, cols)
	var table := PackedVector2Array()
	for i in 8:
		table.append(at + Vector2(-1.5, -1.5) + Vector2.from_angle(PI / 8.0 + i * PI / 4.0) * 8.5)
	draw_colored_polygon(table, Color(col.lightened(0.5), 0.35))
	Style.diamond(rid, at + Vector2(-6, -7), 2.0, Color(1, 1, 1, 0.5))
	_text(at + Vector2(0, size_px * 0.36 + 1.0), text, size_px, Color(1.0, 0.97, 0.88, 0.45), f, HORIZONTAL_ALIGNMENT_CENTER)
	_text(at + Vector2(0, size_px * 0.36), text, size_px, Color(0.2, 0.1, 0.02) if lit else Color(0.2, 0.18, 0.16), f,
		HORIZONTAL_ALIGNMENT_CENTER)


## What kind of good it is, said at its foot: a building's part of the homeland and its school, how rare it is.
func footer() -> String:
	var bits: Array = [Content.TYPES[c.type]]
	if c.type == "build":
		var b: Dictionary = Content.BUILDINGS[c.builds]
		bits = ["巢 · 阵地"] if b.has("nest") else ["后方"]
		if b.has("school"):
			bits.append(Content.SCHOOLS[b.school].name)
	bits.append(RARITY[int(c.rarity)])
	return " · ".join(bits)


## What else it costs (genes -- as many as it costs here -- and alien genes) beside the price -- not for a good had
## already -- and the shade over a card that cannot be bought now.
func _extras(full: Rect2) -> void:
	var x := SIZE.x - 10.0
	var rid := get_canvas_item()
	for extra in [["alien", "外星", ALIEN], ["genes", "基因", GENES]]:
		if token() != "":
			break
		var n := genes_shown if extra[0] == "genes" and genes_shown >= 0 else int(c.get(extra[0], 0))
		if n <= 0:
			continue
		var label := "%s %d" % [extra[1], n]
		var w := Fonts.serif(800).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
		var pill := Rect2(x - w, 9, w, 17)
		Style.fill(rid, pill, 4.0, (extra[2] as Color).lightened(0.15), (extra[2] as Color).darkened(0.25))
		Style.ring(rid, pill, 4.0, Color(0, 0, 0, 0.55), 1.0)
		_text(Vector2(pill.get_center().x, 21.5), label, 11, Color(0.04, 0.05, 0.07), Fonts.serif(800), HORIZONTAL_ALIGNMENT_CENTER)
		x -= w + 4.0
	if not affordable:
		Style.fill(rid, full.grow(-2.0), 11.0, Color(0, 0, 0, 0.42), Color(0, 0, 0, 0.42))


## The picture: a building as blocks of its colour; a raise as a block with an arrow; an affix as what it grows.
func _picture(r: Rect2) -> void:
	var mid := r.get_center()
	var gold := Color(1.0, 0.86, 0.45)
	match c.type:
		"build":
			var b: Dictionary = Content.BUILDINGS[c.builds]
			var col: Color = b.color
			if b.has("nest"):
				var sp := Content.species(b.nest, c.get("affixes", []))
				_block(mid + Vector2(0, 8), 30.0, 34.0, col)
				_block(mid + Vector2(38, 22), 12.0, 12.0, Content.UNITS[sp.kind].color)
				for k in c.get("affixes", []).size():
					draw_circle(mid + Vector2(-34, 24 - k * 13), 5.5, Content.AFFIXES[c.affixes[k]].color)
					draw_arc(mid + Vector2(-34, 24 - k * 13), 5.5, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 1.0, true)
				# Its gift's name, flown over it.
				_text(Vector2(mid.x, r.position.y + 15), "「%s」" % Content.TRAITS[b.trait].name, 13, Color(1.0, 0.93, 0.72),
					Fonts.serif(800), HORIZONTAL_ALIGNMENT_CENTER, 4)
			else:
				match c.builds:
					"pool", "spore_pool":
						_block(mid + Vector2(0, 14), 52.0, 14.0, col.darkened(0.4))
						draw_rect(Rect2(mid + Vector2(-24, 2), Vector2(48, 6)), col.lightened(0.2))
						if c.builds == "spore_pool":
							for k in 3:
								draw_circle(mid + Vector2(-14 + k * 14, -4 - (k % 2) * 6), 6.0, Color(0.78, 0.82, 0.38))
					"horde_totem":
						draw_rect(Rect2(mid + Vector2(-4, -30), Vector2(8, 58)), Color(0.35, 0.25, 0.18))
						for k in 3:
							_block(mid + Vector2(0, 16 - k * 14), 16.0, 11.0, Color(0.9, 0.85, 0.75))
						draw_rect(Rect2(mid + Vector2(4, -30), Vector2(20, 14)), col)
					"gene_bank":
						_block(mid + Vector2(0, 24), 40.0, 8.0, col.darkened(0.45))
						draw_rect(Rect2(mid + Vector2(-14, -26), Vector2(28, 46)), Color(col, 0.75))
						for k in 4:
							draw_circle(mid + Vector2(-8 + (k % 2) * 16, -18 + k * 11), 3.5, Color(1, 1, 1))
					"vault":
						_block(mid + Vector2(0, 10), 50.0, 30.0, Color(0.42, 0.4, 0.38))
						draw_circle(mid + Vector2(0, 10), 10.0, col)
						draw_circle(mid + Vector2(0, 10), 4.0, col.darkened(0.4))
					"market":
						_block(mid + Vector2(0, 18), 46.0, 14.0, Color(0.5, 0.36, 0.22))
						for k in 4:
							draw_rect(Rect2(mid + Vector2(-26 + k * 13, -22), Vector2(13, 10)), col if k % 2 == 0 else Color(0.95, 0.92, 0.85))
						for sx in [-24.0, 22.0]:
							draw_rect(Rect2(mid + Vector2(sx, -12), Vector2(3, 24)), Color(0.4, 0.3, 0.2))
					"champion_hall":
						_block(mid + Vector2(0, 22), 52.0, 8.0, Color(0.85, 0.82, 0.78))
						for k in 4:
							draw_rect(Rect2(mid + Vector2(-22 + k * 13, -8), Vector2(5, 26)), Color(0.92, 0.9, 0.86))
						_block(mid + Vector2(0, -12), 54.0, 7.0, col)
						draw_colored_polygon(PackedVector2Array([mid + Vector2(-10, -18), mid + Vector2(-10, -30), mid + Vector2(-4, -24),
							mid + Vector2(0, -32), mid + Vector2(4, -24), mid + Vector2(10, -30), mid + Vector2(10, -18)]), HomeView.ELITE_GOLD)
					"watchtower":
						draw_rect(Rect2(mid + Vector2(-6, -14), Vector2(12, 42)), Color(0.45, 0.4, 0.36))
						_block(mid + Vector2(0, -18), 22.0, 12.0, col)
						draw_colored_polygon(PackedVector2Array([mid + Vector2(-14, -24), mid + Vector2(0, -36), mid + Vector2(14, -24)]),
							col.darkened(0.3))
					"vanguard":
						draw_colored_polygon(PackedVector2Array([mid + Vector2(-26, 24), mid + Vector2(0, -28), mid + Vector2(26, 24)]), col)
						for k in 3:
							draw_rect(Rect2(mid + Vector2(-18 + k * 13, 12), Vector2(9, 13)), Color(0.62, 0.64, 0.7))
					"forge":
						_block(mid + Vector2(-4, 12), 40.0, 28.0, Color(0.3, 0.26, 0.24))
						draw_rect(Rect2(mid + Vector2(-12, 12), Vector2(14, 10)), Color(1.0, 0.55, 0.15))
						draw_rect(Rect2(mid + Vector2(8, -24), Vector2(9, 24)), col.darkened(0.3))
					"sampler":
						_block(mid + Vector2(0, 20), 26.0, 12.0, col.darkened(0.3))
						draw_rect(Rect2(mid + Vector2(-5, -22), Vector2(10, 36)), col)
						draw_circle(mid + Vector2(0, -24), 13.0, col.lightened(0.3))
					"mine":
						_block(mid + Vector2(0, 12), 36.0, 26.0, Color(0.32, 0.32, 0.34))
						draw_circle(mid + Vector2(0, -12), 11.0, col)
					"stabilizer":
						draw_rect(Rect2(mid + Vector2(-5, -26), Vector2(10, 50)), col.darkened(0.2))
						for k in 2:
							draw_rect(Rect2(mid + Vector2(-20, -12 + k * 16), Vector2(40, 4)), col.lightened(0.2))
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
				"poison":
					draw_colored_polygon(PackedVector2Array([mid + Vector2(14, 0), mid + Vector2(40, -26), mid + Vector2(22, 4)]), col)
					draw_circle(mid + Vector2(40, -26), 3.5, col.darkened(0.3))
				"flame":
					draw_colored_polygon(PackedVector2Array([mid + Vector2(-12, -2), mid + Vector2(0, -34), mid + Vector2(12, -2)]), col)
					draw_colored_polygon(PackedVector2Array([mid + Vector2(-6, -2), mid + Vector2(0, -20), mid + Vector2(6, -2)]),
						Color(1.0, 0.85, 0.3))
				"haste":
					for sx in [-1.0, 1.0]:
						draw_colored_polygon(PackedVector2Array([mid + Vector2(sx * 15, 4), mid + Vector2(sx * 34, -10),
							mid + Vector2(sx * 15, 16)]), col)
					for k in 3:
						draw_line(mid + Vector2(-40, -18 + k * 8), mid + Vector2(-24, -18 + k * 8), Color(col, 0.8), 2.0)
				"hide":
					for sx in [-1.0, 1.0]:
						draw_rect(Rect2(mid + Vector2(sx * 17 - 4, -4), Vector2(8, 30)), col)
				"horn":
					draw_colored_polygon(PackedVector2Array([mid + Vector2(10, 0), mid + Vector2(38, -6), mid + Vector2(10, 10)]), col)


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
