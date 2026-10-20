class_name Style
## The game's one look (GAME-DESIGN 21, 23): deep ink panels with cut corners -- a lacquer with a faint grain, lit from
## above, bevelled at its inner edge -- in a rim of old gold that catches the light at its top and left, a finer rule
## inside it, small flourishes where the corners are cut, a soft shadow under it all; parchment for words; amber for
## what matters most; jade for good, coral for bad. Built in code -- styleboxes that draw themselves, one Theme every
## screen inherits -- so it is the same everywhere and crisp at any size. Buttons swell a little when pointed at and
## give when pressed (juice).

const INK := Color(0.06, 0.08, 0.085)
const INK_DEEP := Color(0.025, 0.035, 0.04)
const PARCHMENT := Color(0.96, 0.91, 0.8)
const PARCHMENT_DIM := Color(0.78, 0.73, 0.63)
const GOLD := Color(0.84, 0.69, 0.42)
const GOLD_BRIGHT := Color(1.0, 0.89, 0.62)
const GOLD_DIM := Color(0.5, 0.41, 0.26)
const AMBER := Color(0.98, 0.66, 0.24)
const JADE := Color(0.52, 0.87, 0.65)
const CORAL := Color(0.96, 0.47, 0.4)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.85)

static var _theme: Theme
static var _blur: Shader
static var _vignette: Shader
static var _edges: Shader
static var _grain: Texture2D


## A panel or a plate: a cut-cornered shape filled top to bottom, ringed by a gold rule with a finer one inside it,
## a diamond on each cut corner; a soft shadow under it, and a glow round it when lit.
class Ornate extends StyleBox:
	var top := Color(0.085, 0.11, 0.115, 0.95)
	var bottom := Color(0.028, 0.036, 0.042, 0.95)
	var edge := GOLD
	var rule := Color(GOLD, 0.34)
	var cut := 9.0
	var inset := 4.0
	var studs := true
	var crest := false            # a bigger diamond on the top edge's middle (a heading's panel)
	var glow := Color(0, 0, 0, 0)
	var shade := 0.45
	var edge_width := 1.8
	var sheen := 0.05             # the light from above on the fill's upper middle
	var grain := 0.035            # how much the lacquer's grain shows
	var gloss := 0.0              # a button's shine over its upper half
	var sunk := false             # pressed in: the bevel turned over

	func _init(margin := 12.0) -> void:
		content_margin_left = margin
		content_margin_right = margin
		content_margin_top = margin * 0.75
		content_margin_bottom = margin * 0.75

	func _draw(ci: RID, rect: Rect2) -> void:
		if shade > 0.0:
			for i in 6:
				var g := 0.5 + i * 1.8
				Style.fill(ci, rect.grow(g), cut + g * 0.7, Color(0, 0, 0, shade * 0.1 * (1.0 - i / 6.0)),
					Color(0, 0, 0, shade * 0.16 * (1.0 - i / 6.0)), Vector2(0, 2.5 + i * 0.6))
		if glow.a > 0.0:
			for i in 6:
				var g := 1.0 + i * 1.9
				Style.ring(ci, rect.grow(g), cut + g * 0.6, Color(glow, glow.a * pow(1.0 - i / 6.0, 1.6)), 2.2)
		Style.fill(ci, rect, cut, top, bottom)
		if grain > 0.0:
			Style.grain(ci, rect, cut, grain)
		if sheen > 0.0:
			Style.sheen(ci, rect, cut, sheen)
		if gloss > 0.0:
			Style.gloss(ci, rect.grow(-edge_width), maxf(1.0, cut - edge_width * 0.5), gloss)
		var lit := Color(1, 1, 1, 0.09)
		var dark := Color(0, 0, 0, 0.42)
		Style.bevel(ci, rect.grow(-edge_width * 0.5 - 1.0), maxf(1.0, cut - edge_width * 0.5), dark if sunk else lit, lit if sunk else dark, 1.6)
		Style.ring(ci, rect.grow(1.2), cut + 0.5, Color(0, 0, 0, 0.7), 1.2)
		Style.metal(ci, rect, cut, edge, edge_width)
		if inset > 0.0 and rule.a > 0.0:
			Style.ring(ci, rect.grow(-inset), maxf(1.0, cut - inset * 0.6), rule, 1.0)
		if studs:
			Style.flourishes(ci, rect, cut, edge)
		if crest:
			Style.diamond(ci, Vector2(rect.get_center().x, rect.position.y), 6.5, edge.lightened(0.25), INK_DEEP)
			for side in [-1.0, 1.0]:
				Style.diamond(ci, Vector2(rect.get_center().x + side * 11.0, rect.position.y), 2.4, edge.lightened(0.1))


## A line of words to pick (the title screen's, the pause menu's): nothing at rest; lit, a band of light fading to
## both ends, a hairline above and under it, a diamond at each end.
class Band extends StyleBox:
	var light := Color(GOLD_BRIGHT, 0.0)

	func _init(margin := 10.0) -> void:
		content_margin_left = margin * 3.0
		content_margin_right = margin * 3.0
		content_margin_top = margin * 0.6
		content_margin_bottom = margin * 0.6

	func _draw(ci: RID, rect: Rect2) -> void:
		if light.a <= 0.0:
			return
		var mid := rect.get_center().x
		var clear := Color(light, 0.0)
		var soft := Color(light, light.a * 0.22)
		for half in [[rect.position.x, mid], [rect.end.x, mid]]:
			var a: float = half[0]
			var b: float = half[1]
			RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(a, rect.position.y), Vector2(b, rect.position.y),
				Vector2(b, rect.end.y), Vector2(a, rect.end.y)]), PackedColorArray([clear, soft, soft, clear]))
			for y in [rect.position.y, rect.end.y]:
				RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([Vector2(a, y), Vector2(b, y)]),
					PackedColorArray([clear, Color(light, light.a * 0.9)]), 1.0, true)
		for x in [rect.position.x + 14.0, rect.end.x - 14.0]:
			Style.diamond(ci, Vector2(x, rect.get_center().y), 4.0, light)


## A band of shade across, fading out at both ends, a gold hairline above and under it -- behind words over the land
## (a banner, a hint).
class Streak extends StyleBox:
	var shade := Color(0.02, 0.025, 0.03, 0.72)
	var line := Color(GOLD, 0.75)

	func _init(margin := 10.0) -> void:
		content_margin_left = margin * 5.0
		content_margin_right = margin * 5.0
		content_margin_top = margin * 0.7
		content_margin_bottom = margin * 0.7

	func _draw(ci: RID, rect: Rect2) -> void:
		var mid := rect.get_center().x
		for half in [[rect.position.x, mid], [rect.end.x, mid]]:
			var a: float = half[0]
			var b: float = half[1]
			RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(a, rect.position.y), Vector2(b, rect.position.y),
				Vector2(b, rect.end.y), Vector2(a, rect.end.y)]), PackedColorArray([Color(shade, 0.0), shade, shade, Color(shade, 0.0)]))
			for y in [rect.position.y, rect.end.y]:
				RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([Vector2(a, y), Vector2(b, y)]),
					PackedColorArray([Color(line, 0.0), line]), 1.0, true)


## A slider's track: a sunken groove with a gold rule, filled with amber as far as it goes.
class Groove extends StyleBox:
	var fill := Color(0, 0, 0, 0)

	func _draw(ci: RID, rect: Rect2) -> void:
		var r := Rect2(rect.position.x, rect.get_center().y - 3.0, rect.size.x, 6.0)
		if fill.a > 0.0:
			Style.fill(ci, r, 2.0, fill.lightened(0.15), fill.darkened(0.2))
		else:
			Style.fill(ci, r, 2.0, INK_DEEP, Color(0.08, 0.1, 0.1))
			Style.ring(ci, r.grow(1.0), 3.0, GOLD_DIM, 1.0)


# -- Drawing ---------------------------------------------------------------------------------------------------

## The eight corners of `r` with corners cut by `c`.
static func octagon(r: Rect2, c: float) -> PackedVector2Array:
	c = clampf(c, 0.0, minf(r.size.x, r.size.y) * 0.5)
	return PackedVector2Array([Vector2(r.position.x + c, r.position.y), Vector2(r.end.x - c, r.position.y),
		Vector2(r.end.x, r.position.y + c), Vector2(r.end.x, r.end.y - c), Vector2(r.end.x - c, r.end.y),
		Vector2(r.position.x + c, r.end.y), Vector2(r.position.x, r.end.y - c), Vector2(r.position.x, r.position.y + c)])


## `r`, corners cut by `c`, filled from `top` at its top to `bottom` at its foot (moved by `off`).
static func fill(ci: RID, r: Rect2, c: float, top: Color, bottom: Color, off := Vector2.ZERO) -> void:
	var pts := octagon(Rect2(r.position + off, r.size), c)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y - off.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(ci, pts, cols)


## The edge of `r`, corners cut by `c`, as a line.
static func ring(ci: RID, r: Rect2, c: float, col: Color, width := 1.0) -> void:
	var pts := octagon(r, c)
	pts.append(pts[0])
	RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([col]), width, true)


## The rim of `r` (corners cut by `c`) as metal: bright where the light falls, at the top and the left, darker under.
static func metal(ci: RID, r: Rect2, c: float, col: Color, width := 1.8) -> void:
	var pts := octagon(r, c)
	pts.append(pts[0])
	var mid := r.get_center()
	var cols := PackedColorArray()
	for p in pts:
		var d := (p - mid) / Vector2(maxf(1.0, r.size.x * 0.5), maxf(1.0, r.size.y * 0.5))
		var lit := clampf(-(d.x * 0.45 + d.y * 0.9) * 0.6 + 0.5, 0.0, 1.0)
		cols.append(col.darkened(0.38).lerp(col.lightened(0.42), lit))
	RenderingServer.canvas_item_add_polyline(ci, pts, cols, width, true)


## The inner edge of `r` turned to the light: `upper` along the top (and the upper sides), `lower` along the foot.
static func bevel(ci: RID, r: Rect2, c: float, upper: Color, lower: Color, width := 1.5) -> void:
	var pts := octagon(r, c)
	pts.append(pts[0])
	var cols := PackedColorArray()
	for p in pts:
		cols.append(upper.lerp(lower, clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polyline(ci, pts, cols, width, true)


## A soft light on the upper middle of `r`, fading to nothing at its edges.
static func sheen(ci: RID, r: Rect2, c: float, amount: float) -> void:
	var pts := octagon(r, c)
	var centre := Vector2(r.get_center().x, r.position.y + r.size.y * 0.18)
	var all := PackedVector2Array([centre])
	all.append_array(pts)
	var cols := PackedColorArray([Color(1, 1, 1, amount)])
	for p in pts:
		cols.append(Color(1, 1, 1, 0.0))
	var idx := PackedInt32Array()
	for i in pts.size():
		idx.append_array([0, 1 + i, 1 + (i + 1) % pts.size()])
	RenderingServer.canvas_item_add_triangle_array(ci, idx, all, cols)


## A button's shine: its upper half lighter, fading down to nothing at its middle.
static func gloss(ci: RID, r: Rect2, c: float, amount: float) -> void:
	var half := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5))
	var pts := octagon(r, c)
	var upper := PackedVector2Array()
	for p in pts:
		upper.append(Vector2(p.x, minf(p.y, half.end.y)))
	var cols := PackedColorArray()
	for p in upper:
		cols.append(Color(1, 1, 1, amount * clampf(1.0 - (p.y - r.position.y) / maxf(1.0, half.size.y), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(ci, upper, cols)


## The lacquer's grain: a faint noise laid over `r`, tiled, so a panel of any size has the same fine grain.
static func grain(ci: RID, r: Rect2, c: float, amount: float) -> void:
	if _grain == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.16
		noise.fractal_octaves = 2
		var img := noise.get_seamless_image(128, 128)
		img.convert(Image.FORMAT_RGBA8)
		_grain = ImageTexture.create_from_image(img)
	var pts := octagon(r, c)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append((p - r.position) / 128.0)
	RenderingServer.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([Color(1, 1, 1, amount)]), uvs, _grain.get_rid())


## At each cut corner a small flourish: a diamond on the cut, a short rule running from it along each edge and fading.
static func flourishes(ci: RID, r: Rect2, c: float, col: Color) -> void:
	c = minf(c, minf(r.size.x, r.size.y) * 0.5)
	var bright := col.lightened(0.3)
	var clear := Color(col, 0.0)
	for k in 4:
		var sx := 1.0 if k == 0 or k == 3 else -1.0
		var sy := 1.0 if k < 2 else -1.0
		var corner := Vector2(r.position.x if sx > 0.0 else r.end.x, r.position.y if sy > 0.0 else r.end.y)
		var at := corner + Vector2(sx, sy) * c * 0.5
		diamond(ci, at, 2.8, bright)
		var reach := minf(16.0, minf(r.size.x, r.size.y) * 0.22)
		if reach > 6.0:
			var along_x := corner + Vector2(sx * (c + 2.0), sy * 3.5)
			var along_y := corner + Vector2(sx * 3.5, sy * (c + 2.0))
			RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([along_x, along_x + Vector2(sx * reach, 0)]),
				PackedColorArray([Color(bright, 0.9), clear]), 1.0, true)
			RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([along_y, along_y + Vector2(0, sy * reach)]),
				PackedColorArray([Color(bright, 0.9), clear]), 1.0, true)


## A button that swells a little when pointed at and gives when pressed (once each; any button may be given it).
static func juice(b: BaseButton) -> void:
	if b.has_meta("juiced"):
		return
	b.set_meta("juiced", true)
	var centre := func() -> void: b.pivot_offset = b.size * 0.5
	b.resized.connect(centre)
	centre.call()
	var to := func(s: float, t: float) -> void:
		var old: Variant = b.get_meta("juice_tween") if b.has_meta("juice_tween") else null
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * s, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		b.set_meta("juice_tween", tw)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			to.call(1.035, 0.12))
	b.mouse_exited.connect(func() -> void: to.call(1.0, 0.16))
	b.button_down.connect(func() -> void: to.call(0.965, 0.06))
	b.button_up.connect(func() -> void: to.call(1.035 if b.is_hovered() else 1.0, 0.12))


## A diamond of half-size `s` at `at` -- with `core`, a darker one inside it.
static func diamond(ci: RID, at: Vector2, s: float, col: Color, core := Color(0, 0, 0, 0)) -> void:
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s),
		at + Vector2(-s, 0)]), PackedColorArray([col]))
	if core.a > 0.0:
		var k := s * 0.45
		RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([at + Vector2(0, -k), at + Vector2(k, 0), at + Vector2(0, k),
			at + Vector2(-k, 0)]), PackedColorArray([core]))


## A rule across `width` at `at` (its middle): fading in from both ends, a diamond in the middle and one each side of it.
static func rule(item: CanvasItem, at: Vector2, width: float, col := GOLD) -> void:
	var ci := item.get_canvas_item()
	var clear := Color(col, 0.0)
	for side in [-1.0, 1.0]:
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([at + Vector2(side * width * 0.5, 0), at + Vector2(side * 14.0, 0)]),
			PackedColorArray([clear, col]), 1.2, true)
		diamond(ci, at + Vector2(side * 9.0, 0), 2.2, col)
	diamond(ci, at, 4.5, col, INK_DEEP)


# -- Pieces ----------------------------------------------------------------------------------------------------

## A panel: ink, gold-ruled.
static func panel(margin := 14.0, crested := false) -> Ornate:
	var b := Ornate.new(margin)
	b.crest = crested
	return b


## A button's look for one state -- `primary` amber, for what sends the round on.
static func button(state: String, primary := false) -> Ornate:
	var b := Ornate.new(10.0)
	b.cut = 7.0
	b.shade = 0.35
	b.top = Color(0.12, 0.145, 0.15, 0.97)
	b.bottom = Color(0.035, 0.045, 0.05, 0.97)
	b.gloss = 0.07
	b.sheen = 0.0
	b.grain = 0.025
	if primary:
		b.top = Color(0.66, 0.4, 0.14, 0.98)
		b.bottom = Color(0.3, 0.15, 0.045, 0.98)
		b.edge = GOLD_BRIGHT
		b.rule = Color(GOLD_BRIGHT, 0.45)
		b.gloss = 0.13
	match state:
		"hover":
			b.top = b.top.lightened(0.12)
			b.bottom = b.bottom.lightened(0.08)
			b.edge = GOLD_BRIGHT
			b.glow = Color(AMBER if primary else GOLD_BRIGHT, 0.36)
			b.gloss *= 1.4
		"pressed":
			b.top = b.bottom.darkened(0.15)
			b.bottom = b.bottom.darkened(0.05)
			b.shade = 0.1
			b.gloss = 0.0
			b.sunk = true
		"disabled":
			b.top = Color(0.09, 0.09, 0.09, 0.8)
			b.bottom = Color(0.05, 0.05, 0.05, 0.8)
			b.edge = Color(0.35, 0.33, 0.3)
			b.rule = Color(0.35, 0.33, 0.3, 0.3)
			b.studs = false
		"focus":
			var f := Ornate.new(10.0)
			f.top = Color(0, 0, 0, 0)
			f.bottom = Color(0, 0, 0, 0)
			f.edge = Color(GOLD_BRIGHT, 0.0)
			f.rule = Color(0, 0, 0, 0)
			f.studs = false
			f.shade = 0.0
			f.cut = 7.0
			f.glow = Color(GOLD_BRIGHT, 0.45)
			return f
	return b


## The one Theme: faces, words, buttons ("Primary" amber, "Choice" for the title and pause menus' lines), panels,
## sliders.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = Fonts.serif(500)
	t.default_font_size = 16
	t.set_color("font_color", "Label", PARCHMENT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 4)
	for type in ["Button", "Primary"]:
		if type != "Button":
			t.set_type_variation(type, "Button")
		var primary: bool = type == "Primary"
		t.set_font("font", type, Fonts.serif(800))
		t.set_font_size("font_size", type, 18)
		t.set_color("font_color", type, GOLD_BRIGHT if primary else PARCHMENT)
		for s in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(s, type, Color(1.0, 0.96, 0.85))
		t.set_color("font_disabled_color", type, Color(PARCHMENT_DIM, 0.4))
		t.set_color("font_outline_color", type, OUTLINE)
		t.set_constant("outline_size", type, 4)
		for s in ["normal", "hover", "pressed", "disabled", "focus"]:
			t.set_stylebox(s, type, button(s, primary))
		t.set_stylebox("hover_pressed", type, button("pressed", primary))
	# Toggle: one of a pair (开 / 关), the one pressed lit.
	t.set_type_variation("Toggle", "Button")
	t.set_font("font", "Toggle", Fonts.serif(800))
	t.set_font_size("font_size", "Toggle", 17)
	t.set_color("font_color", "Toggle", Color(PARCHMENT_DIM, 0.8))
	for s in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(s, "Toggle", Color(1.0, 0.95, 0.82))
	t.set_color("font_outline_color", "Toggle", OUTLINE)
	t.set_constant("outline_size", "Toggle", 4)
	t.set_stylebox("normal", "Toggle", button("normal"))
	t.set_stylebox("hover", "Toggle", button("hover"))
	t.set_stylebox("pressed", "Toggle", button("hover", true))
	t.set_stylebox("hover_pressed", "Toggle", button("hover", true))
	t.set_stylebox("focus", "Toggle", button("focus"))
	t.set_type_variation("Choice", "Button")
	t.set_font("font", "Choice", Fonts.serif(700))
	t.set_font_size("font_size", "Choice", 26)
	t.set_color("font_color", "Choice", Color(PARCHMENT, 0.88))
	for s in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(s, "Choice", Color(1.0, 0.95, 0.8))
	t.set_color("font_disabled_color", "Choice", Color(PARCHMENT_DIM, 0.35))
	t.set_color("font_outline_color", "Choice", OUTLINE)
	t.set_constant("outline_size", "Choice", 6)
	var lit := Band.new(10.0)
	lit.light = Color(GOLD_BRIGHT, 0.9)
	var rest := Band.new(10.0)
	for s in ["normal", "disabled"]:
		t.set_stylebox(s, "Choice", rest)
	for s in ["hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(s, "Choice", lit)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	# Scroll bars: a dark groove, a slim gold grip.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.025, 0.03, 0.7)
	track.set_corner_radius_all(3)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grip := StyleBoxFlat.new()
	grip.bg_color = Color(GOLD, 0.7)
	grip.set_corner_radius_all(3)
	var grip_lit := grip.duplicate() as StyleBoxFlat
	grip_lit.bg_color = GOLD_BRIGHT
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grip)
	t.set_stylebox("grabber_highlight", "VScrollBar", grip_lit)
	t.set_stylebox("grabber_pressed", "VScrollBar", grip_lit)
	t.set_stylebox("slider", "HSlider", Groove.new())
	var filled := Groove.new()
	filled.fill = AMBER
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", knob(false))
	t.set_icon("grabber_highlight", "HSlider", knob(true))
	t.set_icon("grabber_disabled", "HSlider", knob(false))
	_theme = t
	return t


## A slider's knob: a gold diamond with a dark heart, brighter when pointed at.
static func knob(lit: bool) -> Texture2D:
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := absf(x - c) + absf(y - c)
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			var col := (GOLD_BRIGHT if lit else GOLD).lerp(INK_DEEP, 1.0 if d < c * 0.42 else 0.0)
			if d < c * 0.42:
				col = AMBER if lit else INK_DEEP
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


## A label in the house style: a face and size, a colour (parchment by default), an outline to stand out over the land.
static func label(text: String, size_px := 16, weight := 600, col := PARCHMENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Fonts.serif(weight))
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", maxi(4, size_px / 5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A heading: its words over a gold rule with diamonds -- for a panel's or a screen's top.
static func heading(text: String, size_px := 30) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size_px, 900, GOLD_BRIGHT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var line := Control.new()
	line.custom_minimum_size = Vector2(maxf(220.0, size_px * text.length() * 1.3), 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func() -> void: rule(line, Vector2(line.size.x * 0.5, 6), line.size.x))
	box.add_child(line)
	return box


## What is behind, blurred and darkened toward the edges -- under a screen or a panel over the game.
static func blur_shader() -> Shader:
	if _blur == null:
		_blur = Shader.new()
		_blur.code = """
shader_type canvas_item;
uniform sampler2D behind : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 c = textureLod(behind, SCREEN_UV, 3.0).rgb;
	vec2 d = UV - vec2(0.5);
	float edge = smoothstep(0.2, 0.9, length(d));
	COLOR = vec4(mix(c, vec3(0.015, 0.02, 0.025), 0.55 + edge * 0.3), 1.0);
}
"""
	return _blur


## The corners of the screen a little darker -- over the land in play, under everything else.
static func edge_shader() -> Shader:
	if _edges == null:
		_edges = Shader.new()
		_edges.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	d.x *= 1.25;
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.45, 0.95, length(d)) * 0.38);
}
"""
	return _edges


## The land darkened at the edges, and more at the foot -- the title's frame.
static func vignette_shader() -> Shader:
	if _vignette == null:
		_vignette = Shader.new()
		_vignette.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5, 0.45);
	d.x *= 1.3;
	float edge = smoothstep(0.3, 0.95, length(d)) * 0.8;
	float low = smoothstep(0.5, 1.0, UV.y) * 0.5;
	float high = smoothstep(0.32, 0.0, UV.y) * 0.4;
	COLOR = vec4(0.012, 0.016, 0.02, clamp(edge + low + high, 0.0, 0.92));
}
"""
	return _vignette
