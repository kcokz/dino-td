class_name HudParts
## The HUD's own pieces, in the game's shapes rather than boxes of lines (GAME-DESIGN 23; the player, 2026-10-20:
## "出战的框，左上角介绍的框都显得像网页游戏……我需要契合游戏，又美观精致的专业游戏的框和表达"): a crest for the place
## with its rounds ringed round it; a bar of sockets for what the homeland has; round buttons with their pictures; a
## great seal to send the army out; the wave to come as the monsters' own faces; the battle's count between two
## shields. What each is, or what a figure means, is told when it is pointed at (the HUD's panel), so the screen shows
## pictures and numbers, not sentences. All in the house style (Style): ink, old gold, parchment.

const FACE_TOP := Color(0.13, 0.16, 0.165)
const FACE_BOTTOM := Color(0.025, 0.033, 0.038)
const WAR_TOP := Color(0.6, 0.2, 0.1)         # the great seal's face
const WAR_BOTTOM := Color(0.2, 0.045, 0.025)
const PLATE_TOP := Color(0.12, 0.15, 0.155, 0.96)
const PLATE_BOTTOM := Color(0.03, 0.04, 0.045, 0.96)


# -- Shapes ---------------------------------------------------------------------------------------------------------

## A round plate: a soft shadow under it, its face shaded from `top` (lit from the upper left) to `bottom`, a fine rule
## inside its rim, a rim of old gold -- bright where the light falls, darker below it.
static func disc(item: CanvasItem, c: Vector2, r: float, top: Color, bottom: Color, rim := Style.GOLD, width := -1.0,
		shadow := true) -> void:
	if width < 0.0:
		width = clampf(r * 0.085, 1.6, 4.0)
	if shadow:
		for i in 6:
			item.draw_circle(c + Vector2(0, 1.5 + i * 0.7), r + width + i * 1.3, Color(0, 0, 0, 0.1 * (1.0 - i / 6.0)), true, -1.0, true)
	item.draw_circle(c, r + width * 0.5 + 1.0, Color(0, 0, 0, 0.8), true, -1.0, true)
	for i in 10:
		var k := i / 9.0
		item.draw_circle(c + Vector2(-0.16, -0.22) * r * k, r * (1.0 - 0.62 * k), bottom.lerp(top, k), true, -1.0, true)
	item.draw_arc(c, r * 0.84, 0.0, TAU, 72, Color(rim, 0.32), 1.0, true)
	item.draw_arc(c, r, 0.0, TAU, 72, rim.darkened(0.35), width, true)
	item.draw_arc(c, r, PI * 0.7, PI * 1.8, 48, rim.lightened(0.3), width * 0.75, true)
	item.draw_arc(c, r + width * 0.45, PI * 0.95, PI * 1.45, 24, Color(1, 1, 1, 0.3), 1.0, true)


## A plate pointed at both ends (a nameplate): a soft shadow, its face shaded top to bottom with light on its upper half,
## a gold edge with a finer rule inside it.
static func plate(item: CanvasItem, r: Rect2, top := PLATE_TOP, bottom := PLATE_BOTTOM, edge := Style.GOLD, tip := -1.0) -> void:
	if tip < 0.0:
		tip = r.size.y * 0.42
	_shaped(item, _plate_points(r, tip), r, top, bottom, edge)
	var inner := r.grow(-4.0)
	if inner.size.y > 6.0:
		var rule := _plate_points(inner, maxf(1.0, tip - 2.5))
		rule.append(rule[0])
		item.draw_polyline(rule, Color(edge, 0.3), 1.0, true)


## A bar with round ends (a capsule): the same, its ends round.
static func capsule(item: CanvasItem, r: Rect2, top := PLATE_TOP, bottom := PLATE_BOTTOM, edge := Style.GOLD) -> void:
	_shaped(item, _capsule_points(r), r, top, bottom, edge)
	var inner := r.grow(-3.5)
	if inner.size.y > 6.0:
		var rule := _capsule_points(inner)
		rule.append(rule[0])
		item.draw_polyline(rule, Color(edge, 0.28), 1.0, true)


## A panel with cut corners (the house panel, Style.Ornate), drawn straight onto `item`.
static func panel(item: CanvasItem, r: Rect2, edge := Style.GOLD, cut := 8.0) -> void:
	var ci := item.get_canvas_item()
	for i in 5:
		var g := 0.5 + i * 1.8
		Style.fill(ci, r.grow(g), cut + g * 0.7, Color(0, 0, 0, 0.05 * (1.0 - i / 5.0)), Color(0, 0, 0, 0.08 * (1.0 - i / 5.0)),
			Vector2(0, 2.5 + i * 0.6))
	Style.fill(ci, r, cut, PLATE_TOP, PLATE_BOTTOM)
	Style.grain(ci, r, cut, 0.03)
	Style.sheen(ci, r, cut, 0.05)
	Style.ring(ci, r.grow(1.2), cut + 0.5, Color(0, 0, 0, 0.7), 1.2)
	Style.metal(ci, r, cut, edge, 1.6)
	Style.ring(ci, r.grow(-4.0), maxf(1.0, cut - 2.4), Color(edge, 0.3), 1.0)
	Style.flourishes(ci, r, cut, edge)


## A small round badge with `text` in it (a count, a price) -- a pill when the text is too wide for a circle.
static func badge(item: CanvasItem, c: Vector2, text: String, fill: Color, px := 13, ink := Style.INK_DEEP) -> void:
	var f := Fonts.numbers() if text.is_valid_int() else Fonts.serif(900)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := px * 0.82
	if w * 0.5 + 4.0 > r:
		capsule(item, Rect2(c - Vector2(w * 0.5 + 7.0, r), Vector2(w + 14.0, r * 2.0)), fill.lightened(0.2), fill.darkened(0.3),
			Style.GOLD_BRIGHT)
	else:
		disc(item, c, r, fill.lightened(0.25), fill.darkened(0.3), Style.GOLD_BRIGHT, 1.4, false)
	words(item, c, text, px, ink, f, 0, 0)


## A price: a coin and how much -- the figure coral when there is not enough.
static func price(item: CanvasItem, c: Vector2, amount: int, enough := true, px := 14) -> void:
	var text := str(amount)
	var f := Fonts.numbers()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var coin := px + 4.0
	var r := Rect2(c - Vector2((coin + w) * 0.5 + 8.0, px * 0.82), Vector2(coin + w + 16.0, px * 1.64))
	capsule(item, r, Color(0.16, 0.13, 0.08), Color(0.05, 0.04, 0.025), Style.GOLD)
	Icons.draw(item, Icons.GOLD, Vector2(r.position.x + 6.0 + coin * 0.5, c.y), coin)
	words(item, Vector2(r.position.x + 9.0 + coin, c.y), text, px, Style.GOLD_BRIGHT if enough else Style.CORAL, f, -1, 3)


## `text` centred on `at.y`, its middle (`align` 0), its left (-1) or its right (1) at `at.x`; its width.
static func words(item: CanvasItem, at: Vector2, text: String, px: int, col: Color, f: Font = null, align := 0,
		outline := 4) -> float:
	if f == null:
		f = Fonts.serif(800)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := at.x - w * 0.5 if align == 0 else (at.x if align < 0 else at.x - w)
	var y := at.y + (f.get_ascent(px) - f.get_descent(px)) * 0.5
	if outline > 0:
		item.draw_string_outline(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(0, 0, 0, 0.85 * col.a))
	item.draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	return w


## A picture seen through a round window `r` across its middle (the texture's height filling it, `zoom` closer).
static func window(item: CanvasItem, c: Vector2, r: float, tex: Texture2D, zoom := 1.0, focus := Vector2(0.5, 0.5)) -> void:
	var ts := tex.get_size()
	var s := 2.0 * r * zoom / ts.y
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 40:
		var d := Vector2.from_angle(TAU * i / 40.0) * r
		pts.append(c + d)
		uvs.append(focus + Vector2(d.x / (ts.x * s), d.y / (ts.y * s)))
	item.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)


## A skull `k` times the size of the waves' (how dangerous a wave looks).
static func skull(item: CanvasItem, at: Vector2, col: Color, k := 1.0) -> void:
	item.draw_circle(at + Vector2(0, -1.5) * k, 6.5 * k, col, true, -1.0, true)
	item.draw_rect(Rect2(at + Vector2(-4, 2) * k, Vector2(8, 5) * k), col)
	for sx in [-2.6, 2.6]:
		item.draw_circle(at + Vector2(sx, -1.5) * k, 1.9 * k, Style.INK_DEEP, true, -1.0, true)
	item.draw_colored_polygon(PackedVector2Array([at + Vector2(0, 0.8) * k, at + Vector2(-1.2, 2.8) * k, at + Vector2(1.2, 2.8) * k]),
		Style.INK_DEEP)
	for tx in [-2.0, 0.0, 2.0]:
		item.draw_line(at + Vector2(tx, 4.6) * k, at + Vector2(tx, 7.0) * k, Style.INK_DEEP, maxf(1.0, k))


## A crown `s` across (the last round's: the boss).
static func crown(item: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var h := s * 0.62
	var pts := PackedVector2Array([at + Vector2(-s * 0.5, h * 0.5), at + Vector2(-s * 0.5, -h * 0.3), at + Vector2(-s * 0.25, h * 0.05),
		at + Vector2(0, -h * 0.55), at + Vector2(s * 0.25, h * 0.05), at + Vector2(s * 0.5, -h * 0.3), at + Vector2(s * 0.5, h * 0.5)])
	var outline := pts.duplicate()
	outline.append(pts[0])
	item.draw_colored_polygon(pts, col)
	item.draw_polyline(outline, Style.INK_DEEP, 1.2, true)


## A shield `w` wide and `h` tall, its middle at `c`, its face `col`.
static func shield(item: CanvasItem, c: Vector2, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var top := c.y - h * 0.5
	pts.append(Vector2(c.x - w * 0.5, top))
	pts.append(Vector2(c.x, top + h * 0.06))
	pts.append(Vector2(c.x + w * 0.5, top))
	for i in 9:
		var t := i / 8.0
		# Down the right side, rounding in to the point at the bottom.
		pts.append(Vector2(c.x + w * 0.5 * (1.0 - t * t), top + h * (0.22 + 0.78 * t)))
	for i in range(7, -1, -1):
		var t := i / 8.0
		pts.append(Vector2(c.x - w * 0.5 * (1.0 - t * t), top + h * (0.22 + 0.78 * t)))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(col.lightened(0.25).lerp(col.darkened(0.35), (p.y - top) / h))
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, 3))
	item.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	item.draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	item.draw_polyline(loop, Color(0, 0, 0, 0.75), 3.0, true)
	item.draw_polyline(loop, Style.GOLD, 1.5, true)


static func _shaped(item: CanvasItem, pts: PackedVector2Array, r: Rect2, top: Color, bottom: Color, edge: Color) -> void:
	for i in 4:
		var shade := PackedVector2Array()
		for p in pts:
			shade.append(r.get_center() + (p - r.get_center()) * (1.0 + i * 0.012) + Vector2(0, 2.0 + i * 0.8))
		item.draw_colored_polygon(shade, Color(0, 0, 0, 0.12 * (1.0 - i / 4.0)))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	item.draw_polygon(pts, cols)
	# The light on its upper half.
	var lit := PackedColorArray()
	for p in pts:
		var k := clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)
		lit.append(Color(1, 1, 1, 0.07 * maxf(0.0, 1.0 - k * 2.0)))
	item.draw_polygon(pts, lit)
	var loop := pts.duplicate()
	loop.append(pts[0])
	item.draw_polyline(loop, Color(0, 0, 0, 0.75), 3.2, true)
	item.draw_polyline(loop, edge, 1.6, true)


static func _plate_points(r: Rect2, tip: float) -> PackedVector2Array:
	var y := r.get_center().y
	return PackedVector2Array([Vector2(r.position.x + tip, r.position.y), Vector2(r.end.x - tip, r.position.y), Vector2(r.end.x, y),
		Vector2(r.end.x - tip, r.end.y), Vector2(r.position.x + tip, r.end.y), Vector2(r.position.x, y)])


static func _capsule_points(r: Rect2, n := 12) -> PackedVector2Array:
	var rad := r.size.y * 0.5
	var lc := Vector2(r.position.x + rad, r.get_center().y)
	var rc := Vector2(r.end.x - rad, r.get_center().y)
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(rc + Vector2.from_angle(-PI * 0.5 + PI * i / n) * rad)
	for i in n + 1:
		out.append(lc + Vector2.from_angle(PI * 0.5 + PI * i / n) * rad)
	return out


# -- Pieces ----------------------------------------------------------------------------------------------------------

## The place's crest (top left): a round seal with the place's own picture, its rounds ringed round it -- those done
## lit amber, this one bright, those to come dark; a mini-boss's marked with a coral diamond, the boss's with a crown --
## its name on a nameplate beside it; under that the round, and the place's rule by name (pointed at: told in full).
class Crest extends Control:
	const SEAL := Vector2(54, 62)
	const R := 34.0
	var place_name := ""
	var glyph := ""
	var round := 1
	var rounds := 12
	var minis: Array = []
	var rule_name := ""

	func _init() -> void:
		custom_minimum_size = Vector2(336, 116)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var plate := Rect2(76, 30, 244, 44)
		HudParts.plate(self, plate)
		HudParts.words(self, Vector2(108, plate.get_center().y), place_name, 27, Style.GOLD_BRIGHT, Fonts.serif(900), -1)
		var w := HudParts.words(self, Vector2(102, 92), Lang.t("第 %d / %d 轮") % [round, rounds], 16, Style.PARCHMENT, Fonts.serif(800), -1)
		if rule_name != "":
			var rf := Fonts.serif(800)
			var rw := rf.get_string_size(rule_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var chip := Rect2(Vector2(102 + w + 12, 92 - 11), Vector2(rw + 22, 22))
			HudParts.capsule(self, chip, Color(0.22, 0.14, 0.07), Color(0.07, 0.045, 0.02), Style.AMBER.darkened(0.15))
			HudParts.words(self, chip.get_center(), rule_name, 14, Style.AMBER, rf, 0, 3)
		# The rounds, round the seal, from the top clockwise; the last ends at the top again: the boss's crown there.
		var ring := R + 9.5
		var gap := 0.075
		for i in rounds:
			var a0 := -PI * 0.5 + TAU * i / rounds + gap * 0.5
			var a1 := -PI * 0.5 + TAU * (i + 1) / rounds - gap * 0.5
			var col := Color(0.19, 0.21, 0.21)
			if i + 1 < round:
				col = Style.AMBER.darkened(0.08)
			elif i + 1 == round:
				col = Style.GOLD_BRIGHT
			draw_arc(SEAL, ring, a0, a1, 10, Color(0, 0, 0, 0.75), 8.0, true)
			draw_arc(SEAL, ring, a0, a1, 10, col, 5.2, true)
			if i + 1 == round:
				draw_arc(SEAL, ring, a0, a1, 10, Color(Style.GOLD_BRIGHT, 0.35), 10.0, true)
		for m in minis:
			var a := -PI * 0.5 + TAU * (float(m) - 0.5) / rounds
			Style.diamond(get_canvas_item(), SEAL + Vector2.from_angle(a) * (ring + 9.0), 4.2, Style.CORAL, Style.INK_DEEP)
		var top := -PI * 0.5 + TAU * (rounds - 0.5) / rounds
		HudParts.crown(self, SEAL + Vector2.from_angle(top) * (ring + 9.5), 12.0, Style.CORAL)
		HudParts.disc(self, SEAL, R, HudParts.FACE_TOP, HudParts.FACE_BOTTOM, Style.GOLD)
		if glyph != "":
			Icons.draw(self, glyph, SEAL, R * 1.3)


## What the homeland has (under the crest): its health, its biomass, its research points -- each a picture in a socket,
## how much there is and (biomass, research) what comes in each round -- on a bar with round ends. `hover` names the
## one pointed at ("hp", "biomass", "research"; "" none).
class Purse extends Control:
	signal pointed(which: String)
	const CELL := 122.0
	var hp := 0
	var hp_max := 1
	var biomass := 0
	var biomass_in := 0
	var research := 0
	var research_in := 0
	var hover := ""

	func _init() -> void:
		custom_minimum_size = Vector2(CELL * 3.0 + 6.0, 48)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var which: String = ["hp", "biomass", "research"][clampi(int((event as InputEventMouseMotion).position.x / CELL), 0, 2)]
			if which != hover:
				hover = which
				pointed.emit(hover)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover != "":
			hover = ""
			pointed.emit(hover)

	func _draw() -> void:
		HudParts.capsule(self, Rect2(2, 6, size.x - 4.0, 36))
		for i in 3:
			var x := i * CELL
			if i > 0:
				draw_line(Vector2(x + 2, 13), Vector2(x + 2, 35), Color(Style.GOLD, 0.25), 1.0, true)
			var c := Vector2(x + 26, 24)
			HudParts.disc(self, c, 17.0, HudParts.FACE_TOP, HudParts.FACE_BOTTOM, Style.GOLD, 2.0, false)
			Icons.draw(self, [Icons.HEALTH, Icons.BIOMASS, Icons.RESEARCH][i], c, 25.0)
			var nf := Fonts.numbers()
			if i == 0:
				var low := float(hp) / maxf(1.0, hp_max) < 0.35
				var w := HudParts.words(self, Vector2(x + 50, 21), str(hp), 21, Style.CORAL if low else Style.PARCHMENT, nf, -1, 4)
				HudParts.words(self, Vector2(x + 52 + w, 23), "/%d" % hp_max, 14, Style.PARCHMENT_DIM, nf, -1, 3)
				# A thin bar under the figure: how much is left.
				var bar := Rect2(x + 50, 33, 62, 4)
				draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.7))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(hp) / maxf(1.0, hp_max), 0.0, 1.0), bar.size.y)),
					Style.CORAL if low else Color(0.42, 0.78, 0.5))
			else:
				var have := biomass if i == 1 else research
				var comes := biomass_in if i == 1 else research_in
				var w := HudParts.words(self, Vector2(x + 50, 24), str(have), 21, Style.PARCHMENT, nf, -1, 4)
				HudParts.words(self, Vector2(x + 54 + w, 25), "+%d" % comes, 14, Style.JADE, nf, -1, 3)
		if hover != "":
			var i := ["hp", "biomass", "research"].find(hover)
			draw_arc(Vector2(i * CELL + 26, 24), 20.0, 0.0, TAU, 48, Color(Style.GOLD_BRIGHT, 0.55), 1.5, true)


## A round button: a plate with its picture, a word on a little nameplate under it, a count in a badge at its shoulder
## or a price -- `primary` the great seal that sends the army out: bigger, red-bronze, its glow breathing while it can
## be pressed.
class RoundButton extends BaseButton:
	var glyph := ""
	var caption := ""
	var count := ""
	var cost := -1            # a price in gold at its shoulder (-1: none)
	var enough := true        # ...that can be paid
	var radius := 26.0
	var primary := false
	var _t := 0.0

	func _init(p_glyph: String, p_caption: String, p_radius: float, p_primary := false) -> void:
		glyph = p_glyph
		caption = p_caption
		radius = p_radius
		primary = p_primary
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(maxf(radius * 2.0 + 30.0, 96.0 if primary else 72.0), radius * 2.0 + (34.0 if p_caption != "" else 12.0))
		size = custom_minimum_size

	func _process(delta: float) -> void:
		if primary and not disabled and is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var mode := get_draw_mode()
		var hot := mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED
		var down := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
		var c := Vector2(size.x * 0.5, radius + 6.0 + (1.5 if down else 0.0))
		var top := HudParts.WAR_TOP if primary else HudParts.FACE_TOP
		var bottom := HudParts.WAR_BOTTOM if primary else HudParts.FACE_BOTTOM
		if hot and not disabled:
			top = top.lightened(0.14)
		if down:
			top = top.darkened(0.2)
		if disabled:
			top = top.lerp(Color(0.14, 0.14, 0.14), 0.75)
			bottom = bottom.lerp(Color(0.05, 0.05, 0.05), 0.75)
		var glow := 0.0
		if not disabled:
			glow = 0.6 if hot else (0.3 + 0.22 * sin(_t * 2.6) if primary else 0.0)
		if glow > 0.0:
			for i in 7:
				draw_arc(c, radius + 5.0 + i * 2.3, 0.0, TAU, 64, Color(Style.AMBER, glow * 0.2 * (1.0 - i / 7.0)), 2.6, true)
		var rim := Style.GOLD_BRIGHT if primary else Style.GOLD
		if disabled:
			rim = Style.GOLD_DIM
		HudParts.disc(self, c, radius, top, bottom, rim)
		if primary:
			for k in 16:
				Style.diamond(get_canvas_item(), c + Vector2.from_angle(TAU * k / 16.0) * radius * 0.9, 1.6, Color(rim, 0.7))
		Icons.draw(self, glyph, c, radius * (1.15 if primary else 1.2), not disabled)
		if caption != "":
			var px := 22 if primary else 15
			var f := Fonts.serif(900)
			var said := Lang.t(caption)
			var w := f.get_string_size(said, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var h := px + 10.0
			var r := Rect2(Vector2(c.x - w * 0.5 - 16.0, c.y + radius - h * 0.35), Vector2(w + 32.0, h))
			if primary:
				HudParts.plate(self, r, Color(0.5, 0.12, 0.06), Color(0.2, 0.04, 0.02), rim)
			else:
				HudParts.plate(self, r)
			HudParts.words(self, r.get_center() + Vector2(0, 0.5), said, px,
				Style.PARCHMENT_DIM if disabled else (Style.GOLD_BRIGHT if primary else Style.PARCHMENT), f, 0, 4)
		var shoulder := c + Vector2(radius * 0.78, -radius * 0.74)
		if cost >= 0:
			if cost == 0:
				HudParts.badge(self, shoulder + Vector2(4, 0), Lang.t("免费"), Style.JADE, 12)
			else:
				HudParts.price(self, shoulder + Vector2(6, 0), cost, enough, 13)
		elif count != "":
			HudParts.badge(self, shoulder, count, Style.AMBER, 13)


## The army that goes out this round (over the seal): a raptor's head and how many, a drop and how much biomass they
## eat -- coral when there is not that much.
class ArmyTag extends Control:
	var count := 0
	var food := 0
	var short := false

	func _init() -> void:
		custom_minimum_size = Vector2(150, 34)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		HudParts.capsule(self, Rect2(2, 3, size.x - 4.0, 28))
		var nf := Fonts.numbers()
		Icons.draw(self, Icons.ARMY, Vector2(22, 17), 26.0)
		HudParts.words(self, Vector2(38, 17), str(count), 18, Style.PARCHMENT, nf, -1, 4)
		Icons.draw(self, Icons.BIOMASS, Vector2(90, 17), 20.0)
		HudParts.words(self, Vector2(102, 17), "−%d" % food, 18, Style.CORAL if short else Style.PARCHMENT, nf, -1, 4)


## A wave to come (top right): which (this round's or the next; a mini-boss's, a boss's), how dangerous it looks
## (skulls), and the monsters in it -- each one's own face in a round window, how many in a badge. `hover` the kind
## pointed at.
class WaveCard extends Control:
	signal pointed(kind: String)
	const PER_ROW := 5
	var title := ""
	var tag := ""
	var danger := 0
	var now := true
	var kinds: Array = []          # [[kind, how many], ...]
	var hover := ""
	var _pics := {}

	func setup(p_title: String, p_tag: String, p_danger: int, p_now: bool, wave: Array) -> void:
		title = p_title
		tag = p_tag
		danger = p_danger
		now = p_now
		var counts := {}
		for k in wave:
			counts[k] = int(counts.get(k, 0)) + 1
		kinds = []
		for k in counts:
			kinds.append([k, counts[k]])
		mouse_filter = Control.MOUSE_FILTER_STOP
		var rows := maxi(1, ceili(kinds.size() / float(PER_ROW)))
		var cols := mini(kinds.size(), PER_ROW)
		custom_minimum_size = Vector2(maxf(250.0, cols * _pitch() + 28.0), 44.0 + rows * _pitch() + 8.0)
		size = custom_minimum_size
		for pair in kinds:
			var kind: String = pair[0]
			var tex := Portraits.picture("e:" + kind, func(t: Texture2D) -> void:
				_pics[kind] = t
				if is_instance_valid(self):
					queue_redraw())
			if tex != null:
				_pics[kind] = tex

	func _r() -> float:
		return 21.0 if now else 15.0

	func _pitch() -> float:
		return _r() * 2.0 + 12.0

	func _centre(i: int) -> Vector2:
		var cols := mini(kinds.size(), PER_ROW)
		var x0 := size.x - 14.0 - cols * _pitch()
		return Vector2(x0 + (i % PER_ROW + 0.5) * _pitch(), 44.0 + (i / PER_ROW + 0.5) * _pitch())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var at := (event as InputEventMouseMotion).position
			var which := ""
			for i in kinds.size():
				if at.distance_to(_centre(i)) <= _r() + 3.0:
					which = kinds[i][0]
			if which != hover:
				hover = which
				queue_redraw()
				pointed.emit(hover)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover != "":
			hover = ""
			queue_redraw()
			pointed.emit("")

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		HudParts.panel(self, r, Style.CORAL if now else Style.GOLD_DIM, 8.0)
		var head := 22.0
		var x := 14.0
		x += HudParts.words(self, Vector2(x, head), title, 17 if now else 15, Style.PARCHMENT if now else Style.PARCHMENT_DIM,
			Fonts.serif(900), -1) + 8.0
		if tag != "":
			var f := Fonts.serif(900)
			var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var chip := Rect2(Vector2(x, head - 10.0), Vector2(tw + 20.0, 20.0))
			HudParts.plate(self, chip, Color(0.5, 0.12, 0.08), Color(0.2, 0.04, 0.03), Style.CORAL)
			HudParts.words(self, chip.get_center(), tag, 13, Style.GOLD_BRIGHT, f, 0, 3)
		var sc := Style.CORAL if now else Color(Style.CORAL, 0.65)
		for i in danger:
			HudParts.skull(self, Vector2(size.x - 18.0 - i * 17.0, head), sc)
		draw_line(Vector2(12, 38), Vector2(size.x - 12, 38), Color(Style.GOLD, 0.22), 1.0, true)
		for i in kinds.size():
			var kind: String = kinds[i][0]
			var c := _centre(i)
			var col: Color = Content.ENEMIES[kind].color
			var boss := kind.begins_with("boss_") or kind.begins_with("mini_")
			HudParts.disc(self, c, _r(), col.darkened(0.45), col.darkened(0.8), Style.CORAL if boss else Style.GOLD, 2.0, false)
			if _pics.has(kind) and _pics[kind] != null:
				HudParts.window(self, c, _r() - 2.0, _pics[kind], 1.25, Vector2(0.5, 0.52))
			if kind == hover:
				draw_arc(c, _r() + 2.5, 0.0, TAU, 48, Style.GOLD_BRIGHT, 2.0, true)
			HudParts.badge(self, c + Vector2(_r() * 0.72, _r() * 0.72), str(kinds[i][1]), Style.PARCHMENT, 12 if now else 11)


## A wonder on offer: its picture in a square frame, its price at its foot; built, ringed in gold with no price.
class WonderTile extends BaseButton:
	var id := ""
	var cost := 0
	var enough := true
	var built := false
	var _pic: Texture2D

	func _init(p_id: String) -> void:
		id = p_id
		cost = int(Content.WONDERS[id].price)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(78, 88)
		size = custom_minimum_size
		_pic = Portraits.picture("w:" + id, func(t: Texture2D) -> void:
			_pic = t
			if is_instance_valid(self):
				queue_redraw())

	func _draw() -> void:
		var mode := get_draw_mode()
		var hot := (mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED) and not disabled
		var frame := Rect2(7, 4, 64, 64)
		var ci := get_canvas_item()
		var c: Color = Content.WONDERS[id].color
		Style.fill(ci, frame, 6.0, c.darkened(0.55), c.darkened(0.82))
		if _pic != null:
			var ts := _pic.get_size()
			var side := minf(ts.x, ts.y)
			draw_texture_rect_region(_pic, frame.grow(-3.0), Rect2((ts.x - side) * 0.5, (ts.y - side) * 0.5, side, side),
				Color.WHITE if not disabled or built else Color(0.6, 0.6, 0.6))
		if hot:
			Style.ring(ci, frame.grow(3.0), 8.0, Color(Style.AMBER, 0.6), 2.0)
		Style.ring(ci, frame.grow(1.2), 6.5, Color(0, 0, 0, 0.7), 1.2)
		Style.metal(ci, frame, 6.0, Style.GOLD_BRIGHT if built else Style.GOLD, 2.0 if built else 1.6)
		Style.flourishes(ci, frame, 6.0, Style.GOLD)
		if built:
			HudParts.badge(self, Vector2(39, 76), Lang.t("已造"), Style.GOLD, 12)
		else:
			HudParts.price(self, Vector2(39, 76), cost, enough, 13)


## A small bar of words (the stash's count, what the homeland's schools give): a picture, the words.
class Tag extends Control:
	var text := ""
	var glyph := ""
	var colour := Style.PARCHMENT
	var px := 15

	func _init(p_glyph := "", p_colour := Style.PARCHMENT, p_px := 15) -> void:
		glyph = p_glyph
		colour = p_colour
		px = p_px
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_text(t: String) -> void:
		text = t
		var f := Fonts.serif(800)
		custom_minimum_size = Vector2(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + (44.0 if glyph != "" else 26.0), px + 14.0)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		if text == "":
			return
		HudParts.capsule(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)))
		var x := 13.0
		if glyph != "":
			Icons.draw(self, glyph, Vector2(x + 8.0, size.y * 0.5), px + 5.0)
			x += 20.0
		HudParts.words(self, Vector2(x, size.y * 0.5), text, px, colour, Fonts.serif(800), -1, 3)


## A battle's count (top middle): our side's shield and how many stand, a clock in the middle and how long is left
## (its ring running down), theirs.
class Versus extends Control:
	var ours := 0
	var theirs := 0
	var left := 0.0
	var limit := 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(400, 74)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var mid := Vector2(size.x * 0.5, 36)
		HudParts.plate(self, Rect2(22, 16, size.x - 44.0, 40))
		var nf := Fonts.numbers()
		HudParts.shield(self, Vector2(64, 36), 36, 42, Color(0.3, 0.62, 0.42))
		HudParts.words(self, Vector2(64, 34), str(ours), 20, Color.WHITE, nf, 0, 4)
		HudParts.shield(self, Vector2(size.x - 64.0, 36), 36, 42, Color(0.72, 0.26, 0.2))
		HudParts.words(self, Vector2(size.x - 64.0, 34), str(theirs), 20, Color.WHITE, nf, 0, 4)
		HudParts.disc(self, mid, 28.0, HudParts.FACE_TOP, HudParts.FACE_BOTTOM, Style.GOLD)
		var k := clampf(left / maxf(0.01, limit), 0.0, 1.0)
		draw_arc(mid, 22.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Style.AMBER if k > 0.25 else Style.CORAL, 3.0, true)
		HudParts.words(self, mid, str(ceili(left)), 20, Style.GOLD_BRIGHT, nf, 0, 4)
		HudParts.words(self, Vector2(94, 36), Lang.t("我方"), 16, Style.JADE, Fonts.serif(900), -1, 3)
		HudParts.words(self, Vector2(size.x - 94.0, 36), Lang.t("敌方"), 16, Style.CORAL, Fonts.serif(900), 1, 3)
