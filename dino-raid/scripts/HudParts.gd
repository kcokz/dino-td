class_name HudParts
## The HUD's pieces, drawn with restraint (GAME-DESIGN 23; the player, 2026-10-20: "粗框还不如没有，请借鉴埃尔登环的界面框
## 怎么做的，什么是精致感，就是不突兀，简明扼要"; "数字，文字都尽量去除，界面只要简单的图标，具体信息基本上都靠hover";
## "应该突出需要知道的东西，淡化不需要知道的东西，清晰很重要"). No boxes: a picture and, where it must be, a figure, on a
## soft dark veil that fades into the land; hairlines of old gold where a line is wanted at all. What a picture means,
## and every number behind it, is told when it is pointed at (the HUD's panel).

const INK := Color(0.0, 0.0, 0.0, 0.0)
const VEIL := Color(0.02, 0.025, 0.03, 0.6)
const LINE := Color(0.84, 0.69, 0.42, 0.55)         # a hairline of old gold
const FAINT := Color(0.84, 0.69, 0.42, 0.25)


# -- Drawing ------------------------------------------------------------------------------------------------------

## A soft dark veil over `r`, fading out at its edges (behind words or pictures on the land).
static func veil(item: CanvasItem, r: Rect2, alpha := 0.6, feather := 14.0) -> void:
	Style.veil(item.get_canvas_item(), r, Color(VEIL, alpha), Color(VEIL, alpha * 0.9), feather)


## A thin ring of `col` round `c`.
static func ring(item: CanvasItem, c: Vector2, r: float, col := LINE, width := 1.0) -> void:
	item.draw_arc(c, r, 0.0, TAU, maxi(32, int(r * 2.0)), col, width, true)


## `text` centred on `at.y`, its middle (`align` 0), its left (-1) or its right (1) at `at.x`; its width.
static func words(item: CanvasItem, at: Vector2, text: String, px: int, col: Color, f: Font = null, align := 0,
		outline := 4) -> float:
	if f == null:
		f = Fonts.serif(700)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var x := at.x - w * 0.5 if align == 0 else (at.x if align < 0 else at.x - w)
	var y := at.y + (f.get_ascent(px) - f.get_descent(px)) * 0.5
	if outline > 0:
		item.draw_string_outline(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(0, 0, 0, 0.8 * col.a))
	item.draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	return w


## A picture seen through a round window `r` across its middle (the texture's height filling it, `zoom` closer).
static func window(item: CanvasItem, c: Vector2, r: float, tex: Texture2D, zoom := 1.0, focus := Vector2(0.5, 0.5),
		modulate := Color.WHITE) -> void:
	var ts := tex.get_size()
	var s := 2.0 * r * zoom / ts.y
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 48:
		var d := Vector2.from_angle(TAU * i / 48.0) * r
		pts.append(c + d)
		uvs.append(focus + Vector2(d.x / (ts.x * s), d.y / (ts.y * s)))
	item.draw_polygon(pts, PackedColorArray([modulate]), uvs, tex)


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
	item.draw_colored_polygon(pts, col)


## A small shield `h` tall, its middle at `c`, its face `col`, a hairline round it.
static func shield(item: CanvasItem, c: Vector2, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var top := c.y - h * 0.5
	pts.append(Vector2(c.x - w * 0.5, top))
	pts.append(Vector2(c.x + w * 0.5, top))
	for i in 9:
		var t := i / 8.0
		pts.append(Vector2(c.x + w * 0.5 * (1.0 - t * t), top + h * (0.2 + 0.8 * t)))
	for i in range(7, -1, -1):
		var t := i / 8.0
		pts.append(Vector2(c.x - w * 0.5 * (1.0 - t * t), top + h * (0.2 + 0.8 * t)))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(col.lightened(0.15).lerp(col.darkened(0.35), (p.y - top) / h))
	item.draw_polygon(pts, cols)
	var loop := pts.duplicate()
	loop.append(pts[0])
	item.draw_polyline(loop, LINE, 1.0, true)


## The painting of what `key` names ("e_grey", "u_red"...: tools/paint_cards.py), or else its 3D portrait; null while
## neither is to hand -- `done` told when the portrait is.
static func picture(key: String, portrait: String, done: Callable) -> Texture2D:
	var painted := Art.of(key)
	if painted != null:
		return painted
	return Portraits.picture(portrait, done)


# -- Pieces -------------------------------------------------------------------------------------------------------

## Where we are (top left): the place's own picture in a hairline ring, its name beside it, and under the name the
## rounds as small marks -- those done amber, this one bright, those to come faint, a mini-boss's ringed coral, the
## boss's a crown. Pointed at, the panel tells its rule and the round.
class Crest extends Control:
	var place_name := ""
	var glyph := ""
	var round := 1
	var rounds := 12
	var minis: Array = []
	var rule_name := ""

	func _init() -> void:
		custom_minimum_size = Vector2(300, 74)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		HudParts.veil(self, Rect2(-6, -2, 300, 76), 0.55, 22.0)
		var c := Vector2(34, 36)
		if glyph != "":
			Icons.draw(self, glyph, c, 40.0)
		HudParts.ring(self, c, 27.0, HudParts.LINE, 1.0)
		HudParts.words(self, Vector2(70, 26), place_name, 26, Style.PARCHMENT, Fonts.serif(800), -1, 5)
		# The rounds.
		for i in rounds:
			var at := Vector2(74 + i * 15.0, 54)
			var col := Color(1, 1, 1, 0.18)
			if i + 1 < round:
				col = Color(Style.AMBER, 0.85)
			elif i + 1 == round:
				col = Style.GOLD_BRIGHT
			if i + 1 == rounds:
				HudParts.crown(self, at + Vector2(0, -1), 11.0, Style.CORAL if i + 1 > round else col)
				continue
			if i + 1 == round:
				draw_circle(at, 7.0, Color(Style.GOLD_BRIGHT, 0.18), true, -1.0, true)
			Style.diamond(get_canvas_item(), at, 3.6, col)
			if i + 1 in minis:
				Style.diamond(get_canvas_item(), at, 5.6, Color(Style.CORAL, 0.0))
				draw_polyline(PackedVector2Array([at + Vector2(0, -5.6), at + Vector2(5.6, 0), at + Vector2(0, 5.6),
					at + Vector2(-5.6, 0), at + Vector2(0, -5.6)]), Style.CORAL, 1.0, true)


## What the homeland has (under the crest): its health, its population (taken of its bound: a dinosaur's head), its
## research points -- each a picture and how much there is, no more (what comes in each round, and what each is for,
## are told when it is pointed at). `hover` names the one pointed at ("hp", "pop", "research"; "" none).
class Purse extends Control:
	signal pointed(which: String)
	const CELL := 92.0
	var hp := 0
	var hp_max := 1
	var pop_used := 0             # the population taken...
	var pop_cap := 0              # ...of what the homeland and its pools feed
	var research := 0
	var hover := ""

	func _init() -> void:
		custom_minimum_size = Vector2(CELL * 3.0, 38)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var which: String = ["hp", "pop", "research"][clampi(int((event as InputEventMouseMotion).position.x / CELL), 0, 2)]
			if which != hover:
				hover = which
				queue_redraw()
				pointed.emit(hover)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover != "":
			hover = ""
			queue_redraw()
			pointed.emit(hover)

	func _draw() -> void:
		HudParts.veil(self, Rect2(-6, -2, size.x + 6.0, size.y + 4.0), 0.5, 16.0)
		var nf := Fonts.numbers()
		var low := float(hp) / maxf(1.0, hp_max) < 0.35
		var full := pop_used >= pop_cap
		var cells := [[Icons.HEALTH, str(hp), Style.CORAL if low else Style.PARCHMENT],
			[Icons.ARMY, "%d/%d" % [pop_used, pop_cap], Style.AMBER if full else Style.PARCHMENT],
			[Icons.RESEARCH, str(research), Style.PARCHMENT]]
		for i in 3:
			var x := i * CELL
			var lit: bool = hover == ["hp", "pop", "research"][i]
			Icons.draw(self, cells[i][0], Vector2(x + 16, 19), 24.0 if lit else 22.0)
			HudParts.words(self, Vector2(x + 33, 19), cells[i][1], 22, cells[i][2], nf, -1, 4)


## A round button: its picture in a hairline ring on a dark disc, a word under it in small type; a count or a price
## in small figures at its shoulder. `primary`: the one that sends the army out -- larger, its ring gold and a warm
## light breathing round it while it can be pressed.
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
		custom_minimum_size = Vector2(maxf(radius * 2.0 + 30.0, 72.0), radius * 2.0 + (30.0 if p_caption != "" else 12.0))
		size = custom_minimum_size

	func _process(delta: float) -> void:
		if primary and not disabled and is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var mode := get_draw_mode()
		var hot := (mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED) and not disabled
		var down := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
		var c := Vector2(size.x * 0.5, radius + 6.0 + (1.0 if down else 0.0))
		var glow := 0.0
		if not disabled:
			glow = 0.55 if hot else (0.22 + 0.14 * sin(_t * 2.4) if primary else 0.0)
		if glow > 0.0:
			for i in 8:
				draw_circle(c, radius + 3.0 + i * 2.6, Color(Style.AMBER, glow * 0.05 * (1.0 - i / 8.0)), true, -1.0, true)
		draw_circle(c, radius, Color(0.015, 0.02, 0.025, 0.72 if not down else 0.85), true, -1.0, true)
		var rim := Style.GOLD_BRIGHT if (primary or hot) else Style.GOLD
		HudParts.ring(self, c, radius, Color(rim, 0.35 if disabled else 0.85), 1.4 if primary else 1.0)
		if primary:
			HudParts.ring(self, c, radius - 4.0, Color(rim, 0.3), 1.0)
		Icons.draw(self, glyph, c, radius * (1.05 if primary else 1.1), not disabled)
		if caption != "":
			var px := 18 if primary else 13
			HudParts.words(self, Vector2(c.x, c.y + radius + px * 0.75), Lang.t(caption), px,
				Color(Style.PARCHMENT, 0.45) if disabled else (Style.GOLD_BRIGHT if primary else Color(Style.PARCHMENT, 0.85)),
				Fonts.serif(800), 0, 4)
		var shoulder := c + Vector2(radius * 0.86, -radius * 0.7)
		var nf := Fonts.numbers()
		if cost > 0:
			Icons.draw(self, Icons.GOLD, shoulder + Vector2(-2, 0), 15.0)
			HudParts.words(self, shoulder + Vector2(7, 0), str(cost), 14, Style.GOLD_BRIGHT if enough else Style.CORAL, nf, -1, 3)
		elif count != "":
			HudParts.words(self, shoulder + Vector2(2, 0), count, 14, Style.PARCHMENT, nf, -1, 3)


## The army that goes out this round (over the seal): a raptor's head and how many (what they eat, when pointed at).
class ArmyTag extends Control:
	var count := 0
	var food := 0
	var short := false

	func _init() -> void:
		custom_minimum_size = Vector2(76, 30)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		HudParts.veil(self, Rect2(0, 0, size.x, size.y), 0.5, 12.0)
		Icons.draw(self, Icons.ARMY, Vector2(22, 15), 24.0)
		HudParts.words(self, Vector2(38, 15), str(count), 19, Style.CORAL if short else Style.PARCHMENT, Fonts.numbers(), -1, 4)


## A wave to come (top right): which (this round's or the next; its kind -- boss, mini-boss, big -- in small coral
## type), how dangerous it looks (skulls), and the monsters in it -- each its own picture, large and clear in a hairline
## ring, how many under it. Pointed at, a monster is named.
class WaveCard extends Control:
	signal pointed(kind: String)
	signal mapped(on: bool)        # pointed at or left: how the wave stands to be shown (LaneMap) or put away
	const PER_ROW := 5
	var title := ""
	var tag := ""
	var danger := 0
	var now := true
	var kinds: Array = []          # [[kind, how many], ...]
	var hover := ""
	var plan := ""                 # the plan the wave comes in, in words (Content.FORMATIONS)
	var cells := {}                # [lane, behind] -> {kind: how many}: how the wave stands (Content.lanes)
	var _pics := {}

	func setup(p_title: String, p_tag: String, p_danger: int, p_now: bool, wave: Array, lanes: Array = [], p_plan := "") -> void:
		title = p_title
		tag = p_tag
		danger = p_danger
		now = p_now
		plan = p_plan
		cells = {}
		for i in mini(wave.size(), lanes.size()):
			var key := [int(lanes[i]), float(Content.ENEMIES[wave[i]].range) >= 3.0]
			var cell: Dictionary = cells.get(key, {})
			cell[wave[i]] = int(cell.get(wave[i], 0)) + 1
			cells[key] = cell
		var counts := {}
		for k in wave:
			counts[k] = int(counts.get(k, 0)) + 1
		kinds = []
		for k in counts:
			kinds.append([k, counts[k]])
		mouse_filter = Control.MOUSE_FILTER_STOP
		var rows := maxi(1, ceili(kinds.size() / float(PER_ROW)))
		var cols := mini(kinds.size(), PER_ROW)
		custom_minimum_size = Vector2(maxf(220.0, cols * _pitch() + 12.0), 30.0 + rows * (_pitch() + 10.0))
		size = custom_minimum_size
		for pair in kinds:
			var kind: String = pair[0]
			var tex := HudParts.picture("e_" + kind, "e:" + kind, func(t: Texture2D) -> void:
				_pics[kind] = t
				if is_instance_valid(self):
					queue_redraw())
			if tex != null:
				_pics[kind] = tex
		_redraw_soon()

	## A texture loaded while drawing is not ready to show until the next frames: drawn again then.
	func _redraw_soon() -> void:
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
		if is_instance_valid(self):
			queue_redraw()

	## A monster's picture, if loaded.
	func pic(kind: String) -> Texture2D:
		return _pics.get(kind)

	func _r() -> float:
		return 25.0 if now else 18.0

	func _pitch() -> float:
		return _r() * 2.0 + 10.0

	func _centre(i: int) -> Vector2:
		var cols := mini(kinds.size(), PER_ROW)
		var x0 := size.x - 6.0 - cols * _pitch()
		return Vector2(x0 + (i % PER_ROW + 0.5) * _pitch(), 30.0 + (i / PER_ROW) * (_pitch() + 10.0) + _r() + 4.0)

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
		if what == NOTIFICATION_MOUSE_ENTER and not cells.is_empty():
			mapped.emit(true)
		if what == NOTIFICATION_MOUSE_EXIT:
			mapped.emit(false)
			if hover != "":
				hover = ""
				pointed.emit("")

	func _draw() -> void:
		var dim := 1.0 if now else 0.72
		HudParts.veil(self, Rect2(Vector2(-10, -4), size + Vector2(16, 8)), 0.5 if now else 0.35, 22.0)
		var head := 12.0
		var x := size.x - 6.0
		var sc := Color(Style.CORAL, dim)
		for i in danger:
			HudParts.skull(self, Vector2(x - 7.0 - i * 15.0, head), sc, 0.85)
		x -= danger * 15.0 + 8.0
		if tag != "":
			x -= HudParts.words(self, Vector2(x, head), tag, 13, Color(Style.CORAL, dim), Fonts.serif(800), 1, 3) + 8.0
		HudParts.words(self, Vector2(x, head), title, 15, Color(Style.PARCHMENT, 0.9 * dim), Fonts.serif(700), 1, 3)
		for i in kinds.size():
			var kind: String = kinds[i][0]
			var c := _centre(i)
			var boss := kind.begins_with("boss_") or kind.begins_with("mini_")
			draw_circle(c + Vector2(0, 2), _r() + 1.0, Color(0, 0, 0, 0.45), true, -1.0, true)
			if _pics.has(kind) and _pics[kind] != null:
				HudParts.window(self, c, _r(), _pics[kind], 1.15, Vector2(0.5, 0.5), Color(1, 1, 1, dim))
			else:
				draw_circle(c, _r(), (Content.ENEMIES[kind].color as Color).darkened(0.4), true, -1.0, true)
			var rim := Style.CORAL if boss else Style.GOLD
			HudParts.ring(self, c, _r(), Color(rim, (0.95 if kind == hover else 0.55) * dim), 1.6 if kind == hover else 1.0)
			HudParts.words(self, c + Vector2(_r() * 0.72, _r() * 0.78), "%d" % int(kinds[i][1]), 15 if now else 13,
				Color(Style.PARCHMENT, dim), Fonts.numbers(), 0, 4)


## How a wave stands in the homeland's six lanes (v0.15), shown under the wave cards while one is pointed at: the six
## lanes left to right, a plot's width each, those that reach far behind (above), those that fight close in front
## (below, nearest the homeland) -- in each, its monsters and how many.
class LaneMap extends Control:
	const W := 48.0
	const H := 56.0
	var card: WaveCard

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(W * 6.0 + 20.0, 34.0 + H * 2.0 + 26.0)
		size_flags_horizontal = Control.SIZE_SHRINK_END
		visible = false

	func show_for(p_card: WaveCard) -> void:
		card = p_card
		visible = true
		queue_redraw()

	func put_away() -> void:
		card = null
		visible = false

	func _draw() -> void:
		if card == null or not is_instance_valid(card):
			return
		HudParts.veil(self, Rect2(Vector2(-10, -4), size + Vector2(16, 8)), 0.8, 22.0)
		HudParts.words(self, Vector2(size.x * 0.5, 15.0), "%s · %s" % [card.title, card.plan], 14, Style.GOLD_BRIGHT,
			Fonts.serif(800), 0, 3)
		var top := 32.0
		for j in 6:
			for row in 2:
				var r := Rect2(10.0 + j * W + 2.0, top + row * H + 2.0, W - 4.0, H - 4.0)
				draw_rect(r, Color(Style.GOLD, 0.05 if row == 0 else 0.09), true)
				draw_rect(r, Color(Style.GOLD, 0.16), false, 1.0)
		for row in 2:
			var behind := row == 0
			for j in 6:
				var cell: Dictionary = card.cells.get([j, behind], {})
				var list: Array = cell.keys()
				list.sort_custom(func(a: String, b: String) -> bool: return int(cell[a]) > int(cell[b]))
				for k in mini(list.size(), 2):
					var kind: String = list[k]
					var c := Vector2(10.0 + (j + 0.5) * W - 6.0, top + row * H + (H * 0.5 if list.size() == 1 else 16.0 + k * 24.0))
					var tex := card.pic(kind)
					if tex != null:
						HudParts.window(self, c, 11.0, tex, 1.15)
					else:
						draw_circle(c, 11.0, (Content.ENEMIES[kind].color as Color).darkened(0.3), true, -1.0, true)
					var boss := kind.begins_with("boss_") or kind.begins_with("mini_")
					HudParts.ring(self, c, 11.0, Color(Style.CORAL if boss else Style.GOLD, 0.8), 1.0)
					HudParts.words(self, c + Vector2(14.0, 1.0), "%d" % int(cell[kind]), 13, Style.PARCHMENT, Fonts.numbers(), -1, 3)
		HudParts.words(self, Vector2(size.x * 0.5, top + H * 2.0 + 14.0), Lang.t("↓ 家园（六列和家园的六列对着）"), 12,
			Color(Style.PARCHMENT, 0.75), Fonts.serif(600), 0, 3)


## A thing to choose, shown as itself (a star dinosaur): its picture -- a cut-out object floating over a soft glow of
## light, or a painting in a soft-edged window; with no picture yet, a medallion of its colour with its first word --
## its name under it in small type, a note under that (a price); pointed at, it rises a little and brightens and what it
## does is told under it. Bobbing gently while it waits.
class Showcase extends BaseButton:
	var tex: Texture2D
	var title := ""
	var note := ""
	var note_short := false         # the note in coral (a price that cannot be paid)
	var says := ""
	var cutout := true
	var tint := Color(0.5, 0.5, 0.5)   # the medallion's colour, with no picture
	var glyph := ""                 # ...and its word
	var _t := 0.0
	var _rise := 0.0

	func _init(p_tex: Texture2D, p_title: String, p_note: String, p_says: String, p_cutout: bool, p_size := Vector2(250, 330)) -> void:
		tex = p_tex
		title = p_title
		note = p_note
		says = p_says
		cutout = p_cutout
		_t = randf() * TAU
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = p_size
		size = p_size

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_t += delta
		_rise = lerpf(_rise, 1.0 if is_hovered() and not disabled else 0.0, 1.0 - exp(-delta * 10.0))
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var pic := Rect2(10, 6, w - 20, 214)
		var lift := -12.0 * _rise + sin(_t * 1.5) * 4.0 * (1.0 - _rise)
		var c := pic.get_center() + Vector2(0, lift)
		var dim := Color(0.55, 0.55, 0.55) if disabled else Color(1, 1, 1)
		# The light under it.
		for i in 8:
			var k := 1.0 - i / 8.0
			draw_set_transform(Vector2(c.x, pic.end.y - 10.0), 0.0, Vector2(1.0, 0.32))
			draw_circle(Vector2.ZERO, 30.0 + i * 12.0, Color(Style.AMBER, (0.05 + 0.06 * _rise) * k), true, -1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if tex != null:
			var ts := tex.get_size()
			if cutout:
				var k := minf(pic.size.x / ts.x, pic.size.y / ts.y) * (1.0 + 0.05 * _rise)
				var s := ts * k
				draw_texture_rect(tex, Rect2(c - s * 0.5, s), false, dim.lightened(0.12 * _rise))
			else:
				var r := Rect2(c - Vector2(pic.size.x, pic.size.y * 0.8) * 0.5, Vector2(pic.size.x, pic.size.y * 0.8))
				var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
				var shown := r.size / k
				draw_texture_rect_region(tex, r, Rect2((ts - shown) * 0.5, shown), dim.lightened(0.1 * _rise))
				Style.veil(get_canvas_item(), r.grow(2.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), 1.0)
				Style.hairline_rect(get_canvas_item(), r, Color(Style.GOLD, 0.45 + 0.4 * _rise), Color(Style.GOLD_BRIGHT, 0.9), 10.0)
		elif glyph != "":
			var rad := 74.0 * (1.0 + 0.05 * _rise)
			draw_circle(c + Vector2(0, 6), rad * 1.06, Color(0, 0, 0, 0.4), true, -1.0, true)
			draw_circle(c, rad, tint.darkened(0.1) * dim, true, -1.0, true)
			draw_circle(c + Vector2(-rad * 0.25, -rad * 0.3), rad * 0.35, Color(1, 1, 1, 0.12), true, -1.0, true)
			draw_arc(c, rad, 0.0, TAU, 72, Color(Style.GOLD_BRIGHT, 0.85), 2.0, true)
			HudParts.words(self, c + Vector2(0, 22), glyph, 64, Style.INK_DEEP, Fonts.serif(900), 0, 0)
		var y := pic.end.y + 22.0
		HudParts.words(self, Vector2(w * 0.5, y), title, 21, Style.GOLD_BRIGHT if _rise > 0.5 else Style.PARCHMENT,
			Fonts.serif(800), 0, 5)
		Style.hairline(get_canvas_item(), Vector2(w * 0.2, y + 18.0), Vector2(w * 0.8, y + 18.0), Color(Style.GOLD, 0.5 + 0.4 * _rise))
		if note != "":
			HudParts.words(self, Vector2(w * 0.5, y + 34.0), note, 15, Style.CORAL if note_short else Style.GOLD_BRIGHT,
				Fonts.serif(800), 0, 4)
		if says != "" and _rise > 0.05:
			var f := Fonts.serif(600)
			var top := y + (52.0 if note != "" else 34.0)
			draw_multiline_string_outline(f, Vector2(4, top), says, HORIZONTAL_ALIGNMENT_CENTER, w - 8, 14, -1, 4,
				Color(0, 0, 0, 0.8 * _rise))
			draw_multiline_string(f, Vector2(4, top), says, HORIZONTAL_ALIGNMENT_CENTER, w - 8, 14, -1,
				Color(Style.PARCHMENT, _rise))


## A small line of words with a picture (a passing note): no box, a veil behind it.
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
		var f := Fonts.serif(700)
		custom_minimum_size = Vector2(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + (34.0 if glyph != "" else 14.0), px + 12.0)
		size = custom_minimum_size
		queue_redraw()

	func _draw() -> void:
		if text == "":
			return
		HudParts.veil(self, Rect2(Vector2.ZERO, size), 0.5, 10.0)
		var x := 6.0
		if glyph != "":
			Icons.draw(self, glyph, Vector2(x + 9.0, size.y * 0.5), px + 4.0)
			x += 22.0
		HudParts.words(self, Vector2(x, size.y * 0.5), text, px, colour, Fonts.serif(700), -1, 3)


## A battle's count (top middle): our side's small green shield and how many stand, the seconds left in a hairline
## ring (running down round it), theirs on a red shield.
## One thing on the build bar (GAME-DESIGN 27): a blueprint had -- or the star dinosaur on offer -- as its painting in
## a round window, its rarity's metal round it; under it its price in gold; at its shoulder the population it takes
## (green, +: what it feeds more). Lit when it can be built (or bought) now, all of
## it grey when not (the player, 2026-10-21: "灰不能造的或者用的，亮能造的用的"); taken up, raised and ringed bright;
## pointed at, a little larger.
class Plan extends BaseButton:
	const R := 24.0
	const GREY := """shader_type canvas_item;
uniform float grey = 0.0;
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	COLOR.rgb = mix(COLOR.rgb, vec3(g) * 0.75, grey);
}
"""
	static var _grey: Shader
	var key := ""                 # its painting's (Art: "b_nest_red", "a_shell", "s_queen")
	var glyph := ""               # its first word, while there is no painting
	var price := 0
	var pop := 0
	var rarity := 0
	var lit := true
	var held := false
	var _tex: Texture2D
	var _looked := false

	func _init() -> void:
		custom_minimum_size = Vector2(R * 2.0 + 18.0, R * 2.0 + 30.0)
		size = custom_minimum_size
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		material = ShaderMaterial.new()
		material.shader = grey_shader()

	## The shader that greys a whole picture (its "grey" 0 to 1), made once.
	static func grey_shader() -> Shader:
		if _grey == null:
			_grey = Shader.new()
			_grey.code = GREY
		return _grey

	func _draw() -> void:
		(material as ShaderMaterial).set_shader_parameter("grey", 0.0 if lit else 1.0)
		if not _looked:
			_looked = true
			_tex = Art.of(key)
		var hot := get_draw_mode() in [DRAW_HOVER, DRAW_HOVER_PRESSED]
		var c := Vector2(size.x * 0.5, R + 6.0 - (6.0 if held else 0.0))
		var r := R * (1.1 if hot else 1.0)
		var metal: Color = CardView.METAL[clampi(rarity, 0, CardView.METAL.size() - 1)]
		if held or hot:
			draw_circle(c, r + 7.0, Color(Style.GOLD_BRIGHT, 0.16 if hot and not held else 0.28), true, -1.0, true)
		draw_circle(c + Vector2(0, 2), r + 2.0, Color(0, 0, 0, 0.5), true, -1.0, true)
		if _tex != null:
			HudParts.window(self, c, r, _tex, 1.2, Vector2(0.5, 0.48), Color.WHITE if lit else Color(0.75, 0.75, 0.75))
		else:
			draw_circle(c, r, Color(0.16, 0.19, 0.17), true, -1.0, true)
			HudParts.words(self, c + Vector2(0, 7), glyph, 20, Style.PARCHMENT, Fonts.serif(900), 0, 3)
		draw_arc(c, r, 0.0, TAU, 48, Color(Style.GOLD_BRIGHT if held else metal, 0.95), 2.2 if held else 1.3, true)
		var low := size.y - 11.0
		Icons.draw(self, Icons.GOLD, Vector2(c.x - 9.0, low), 17.0, lit)
		HudParts.words(self, Vector2(c.x + 1.0, low), str(price), 14, Style.PARCHMENT, Fonts.numbers(), -1, 3)
		if pop != 0:
			var at := c + Vector2(r * 0.78, -r * 0.62)
			draw_circle(at, 9.0, Color(0.03, 0.07, 0.03, 0.92), true, -1.0, true)
			draw_arc(at, 9.0, 0.0, TAU, 32, Color(CardView.FOOD, 0.9), 1.0, true)
			var said := ("+%d" % -pop) if pop < 0 else str(pop)
			HudParts.words(self, at + Vector2(0, 4.5), said, 12, Color(0.6, 1.0, 0.5) if pop < 0 else Color(0.9, 1.0, 0.85),
				Fonts.numbers(), 0, 3)


## A tech on the tech tree (GAME-DESIGN 29): its blueprint's painting in a round window, its line's metal round it, its
## name under it, and under that its price in research points (a flask and how many; red when there are not enough) --
## or, had, a jade 已有. Lit when it is had or can be researched, all of it grey while the tech it needs is not had;
## pointed at, a little larger.
class TechNode extends BaseButton:
	const R := 20.0
	var key := ""                 # its painting's (Art)
	var glyph := ""               # its first word, while there is no painting
	var title := ""
	var cost := 0
	var rarity := 0
	var had := false
	var open := false             # the tech it needs is had
	var enough := false           # ...and the research points for it
	var shut := false             # the other of its fork had: never here (v0.15)
	var _tex: Texture2D
	var _looked := false

	func _init() -> void:
		custom_minimum_size = Vector2(60, 82)
		size = custom_minimum_size
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		material = ShaderMaterial.new()
		material.shader = Plan.grey_shader()

	func _draw() -> void:
		var lit := had or open
		(material as ShaderMaterial).set_shader_parameter("grey", 0.0 if lit else 1.0)
		if not _looked:
			_looked = true
			_tex = Art.of(key)
		var hot := get_draw_mode() in [DRAW_HOVER, DRAW_HOVER_PRESSED]
		var c := Vector2(size.x * 0.5, R + 8.0)
		var r := R * (1.08 if hot else 1.0)
		var metal: Color = CardView.METAL[clampi(rarity, 0, CardView.METAL.size() - 1)]
		if had:
			draw_circle(c, r + 7.0, Color(Style.GOLD_BRIGHT, 0.22), true, -1.0, true)
		elif open and enough:
			draw_circle(c, r + 6.0, Color(Style.JADE, 0.16 if hot else 0.1), true, -1.0, true)
		draw_circle(c + Vector2(0, 2), r + 2.0, Color(0, 0, 0, 0.5), true, -1.0, true)
		if _tex != null:
			HudParts.window(self, c, r, _tex, 1.2, Vector2(0.5, 0.48), Color.WHITE if lit else Color(0.7, 0.7, 0.7))
		else:
			draw_circle(c, r, Color(0.16, 0.19, 0.17), true, -1.0, true)
			HudParts.words(self, c + Vector2(0, 7), glyph, 20, Style.PARCHMENT, Fonts.serif(900), 0, 3)
		draw_arc(c, r, 0.0, TAU, 48, Color(Style.GOLD_BRIGHT if had else metal, 0.95), 2.2 if had else 1.3, true)
		if shut:
			draw_line(c + Vector2(-r, -r) * 0.6, c + Vector2(r, r) * 0.6, Color(Style.CORAL, 0.8), 2.0, true)
			draw_line(c + Vector2(r, -r) * 0.6, c + Vector2(-r, r) * 0.6, Color(Style.CORAL, 0.8), 2.0, true)
		HudParts.words(self, Vector2(c.x, c.y + R + 12.0), title, 12, Style.PARCHMENT if lit else Color(Style.PARCHMENT, 0.6),
			Fonts.serif(700), 0, 3)
		var low := size.y - 9.0
		if had:
			HudParts.words(self, Vector2(c.x, low), Lang.t("已有"), 13, Style.JADE, Fonts.serif(800), 0, 3)
		else:
			Icons.draw(self, Icons.RESEARCH, Vector2(c.x - 8.0, low), 15.0, lit)
			HudParts.words(self, Vector2(c.x + 1.0, low), str(cost), 14,
				Style.CORAL if open and not enough else Style.PARCHMENT, Fonts.numbers(), -1, 3)


## The round's parts in a row at the top (Content.phases): the one it is in lit gold, those done dim, those to come
## dimmer, a small diamond between each two.
class Track extends Control:
	var part := ""

	func _init() -> void:
		custom_minimum_size = Vector2(360, 30)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ids: Array = Content.phases()
		var now := ids.find(part)
		var step := size.x / ids.size()
		HudParts.veil(self, Rect2(0, 0, size.x, size.y), 0.45, 16.0)
		for i in ids.size():
			var lit := i == now
			var col := Style.GOLD_BRIGHT if lit else Color(Style.PARCHMENT, 0.62 if i < now else 0.36)
			HudParts.words(self, Vector2(step * (i + 0.5), 15), Lang.t(Content.PHASES[ids[i]].name), 15 if lit else 13, col,
				Fonts.serif(800 if lit else 600), 0, 3)
			if i > 0:
				Style.diamond(get_canvas_item(), Vector2(step * i, 15), 2.5, Color(Style.GOLD_BRIGHT, 0.45))


class Versus extends Control:
	var ours := 0
	var theirs := 0
	var left := 0.0
	var limit := 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(240, 64)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var mid := Vector2(size.x * 0.5, 30)
		HudParts.veil(self, Rect2(0, 0, size.x, size.y), 0.55, 22.0)
		var nf := Fonts.numbers()
		HudParts.shield(self, Vector2(mid.x - 66, 30), 22, 26, Color(0.3, 0.62, 0.42))
		HudParts.words(self, Vector2(mid.x - 48, 30), str(ours), 22, Style.PARCHMENT, nf, -1, 4)
		HudParts.shield(self, Vector2(mid.x + 66, 30), 22, 26, Color(0.72, 0.26, 0.2))
		HudParts.words(self, Vector2(mid.x + 48, 30), str(theirs), 22, Style.PARCHMENT, nf, 1, 4)
		var k := clampf(left / maxf(0.01, limit), 0.0, 1.0)
		HudParts.ring(self, mid, 19.0, HudParts.FAINT, 1.0)
		draw_arc(mid, 19.0, -PI * 0.5, -PI * 0.5 + TAU * k, 48, Style.AMBER if k > 0.25 else Style.CORAL, 2.0, true)
		HudParts.words(self, mid, str(ceili(left)), 17, Style.GOLD_BRIGHT, nf, 0, 4)
