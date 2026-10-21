class_name CardView
extends Control
## An offer on the shop's shelf, drawn as a card (GAME-DESIGN 15, 17, 21, 23): its painting (tools/paint_cards.py; the
## model's portrait, Portraits, until there is one) filling the most of it; its name under it on the dark of the card,
## a hairline in its rarity's metal (bronze, silver, gold) with a diamond on it under the name; its price on a coin
## laid over the painting's corner, what else it costs (research points) on the other. What it does is told only when
## it is pointed at or taken up (the player, 2026-10-20: "数字，文字都尽量去除……具体信息基本上都靠hover"); at rest its
## foot says only what kind it is. A good already had -- kept in the stash -- shows a jade token instead of a price: 存.
## A place on the shelf already bought from shows an empty outline. A star dinosaur on offer (after the shelf) is a
## card too: its painting (or a medallion of its colour), what it eats a round on the other corner. Dealt, it comes
## face down and turns over.

signal clicked(view: CardView)
signal hovered(view: CardView, on: bool)

const SIZE := Vector2(150, 212)
const METAL := [Color(0.76, 0.55, 0.33), Color(0.82, 0.85, 0.9), Color(1.0, 0.82, 0.38), Color(0.85, 0.55, 1.0)]
const RARITY := ["普通", "少见", "稀有", "传说"]
const FOOD := Color(0.55, 0.85, 0.35)
const GENES := Color(0.3, 0.85, 0.75)
const ART := Rect2(5, 5, 140, 128)        # where the painting shows
const BODY_TOP := Color(0.075, 0.085, 0.09)
const BODY_BOTTOM := Color(0.03, 0.035, 0.04)

var ci: Dictionary = {}
var c: Dictionary = {}
var sold := false
var sold_label := "已买"
var kept := false                 # had already (in the stash): no price
var affordable := true
var chosen := false
var marked := false               # its kind is about to be taken out of the shop: veiled red
var genes_shown := -1             # the genes it costs here (Home.genes_cost), or -1 for what it says
var purse := {}                   # what the homeland has ({gold, genes}); {} for none
var turn := 1.0                   # which way it faces: 1 its face, -1 its back; between, turning over
var star := ""                    # a star dinosaur on offer (Content.STARS) instead of a good
var _hover := false
var _framed := false

static var _arts := {}            # painting key -> Texture2D (or null: there is none)


func setup(p_ci: Dictionary, p_kept := false) -> void:
	ci = p_ci
	kept = p_kept
	c = Content.offer(ci)
	_frame()


## A star dinosaur on offer: its card.
func setup_star(id: String) -> void:
	star = id
	var s: Dictionary = Content.STARS[id]
	c = {"name": Lang.t(s.name), "rarity": int(s.rarity), "price": int(s.price), "type": "star", "plus": false}
	if not _framed:
		_frame()
	queue_redraw()


## The token a good already had shows instead of a price: "" for one still to buy.
func token() -> String:
	return "存" if kept else ""


## A place on the shelf already bought from (or its kind taken out of the shop: `label`).
func setup_sold(label := "已买") -> void:
	sold = true
	sold_label = label
	_frame()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _frame() -> void:
	_framed = true
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


## Dealt face down, it turns over after `delay` seconds, taking `time` -- lifting a little as it turns.
func turn_over(delay := 0.0, time := 0.32) -> void:
	turn = -1.0
	queue_redraw()
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_set_turn, -1.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_turn(t: float) -> void:
	turn = t
	queue_redraw()


func _draw() -> void:
	# Turning over: drawn narrowed about its middle (edge-on at 0), a little taller and higher mid-turn; its back while
	# the back is towards us.
	var sx := absf(turn)
	var turning := sx < 0.999
	if turning:
		var lift := 1.0 - sx
		draw_set_transform_matrix(Transform2D(0.0, Vector2(maxf(0.02, sx), 1.0 + 0.06 * lift), 0.0,
			Vector2(SIZE.x * 0.5 * (1.0 - sx), -SIZE.y * 0.06 * lift)))
	if turn < 0.0:
		_draw_back()
	elif sold:
		_draw_sold()
	elif not c.is_empty():
		_draw_face()
	if turning:
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Its back: the dark of a card, a hairline round it, a diamond in a ring at its middle.
func _draw_back() -> void:
	var rid := get_canvas_item()
	var full := Rect2(Vector2.ZERO, SIZE)
	_body(full)
	Style.hairline_rect(rid, full.grow(-4.0), Color(Style.GOLD, 0.35), Color(Style.GOLD, 0.8), 9.0)
	var mid := full.get_center()
	draw_arc(mid, 26.0, 0.0, TAU, 64, Color(Style.GOLD, 0.5), 1.0, true)
	draw_arc(mid, 20.0, 0.0, TAU, 64, Color(Style.GOLD, 0.25), 1.0, true)
	Style.diamond(rid, mid, 9.0, Color(Style.AMBER, 0.9), Style.INK_DEEP)


## An empty place: an outline in the dark, what it was (已买) faint in it.
func _draw_sold() -> void:
	var rid := get_canvas_item()
	var full := Rect2(Vector2.ZERO, SIZE)
	Style.veil(rid, full, Color(0, 0, 0, 0.35), Color(0, 0, 0, 0.35), 8.0)
	Style.hairline_rect(rid, full.grow(-2.0), Color(Style.GOLD_DIM, 0.4), Color(Style.GOLD_DIM, 0.6), 8.0)
	_text(Vector2(SIZE.x * 0.5, 112), Lang.t(sold_label), 16, Color(Style.PARCHMENT_DIM, 0.6), Fonts.serif(700),
		HORIZONTAL_ALIGNMENT_CENTER, 3)


func _draw_face() -> void:
	var rid := get_canvas_item()
	var full := Rect2(Vector2.ZERO, SIZE)
	var metal: Color = METAL[clampi(int(c.rarity), 0, METAL.size() - 1)]
	if chosen or _hover:
		Style.veil(rid, full.grow(14.0), Color(Style.GOLD_BRIGHT, 0.32 if chosen else 0.2), Color(Style.AMBER, 0.2 if chosen else 0.12), 16.0)
	_body(full)
	# The painting, its corners rounded, a soft shade at its foot where the name begins.
	var tex := _art()
	if tex != null:
		_rounded_texture(tex, ART, 6.0)
	elif star != "":
		# No painting yet: its colours, its first word.
		var s: Dictionary = Content.STARS[star]
		Style.fill(rid, ART, 6.0, (s.back as Color).lightened(0.1), (s.back as Color).darkened(0.35))
		_text(ART.get_center() + Vector2(0, 22), str(c.name).left(1), 60, s.belly, Fonts.serif(900), HORIZONTAL_ALIGNMENT_CENTER, 6)
	else:
		Style.fill(rid, ART, 6.0, Color(0.2, 0.24, 0.2), Color(0.08, 0.1, 0.09))
	Style.veil(rid, Rect2(ART.position.x, ART.end.y - 26.0, ART.size.x, 34.0), Color(BODY_TOP, 0.0), Color(BODY_TOP, 0.95), 1.0)
	# Its name, and under it a hairline of its metal with a diamond.
	var name_size := 16
	var nf := Fonts.serif(800)
	var name_text: String = c.name
	while name_size > 11 and nf.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > SIZE.x - 16:
		name_size -= 1
	_text(Vector2(SIZE.x * 0.5, 150), name_text, name_size, Style.JADE if c.plus else Style.PARCHMENT, nf, HORIZONTAL_ALIGNMENT_CENTER, 4)
	Style.hairline(rid, Vector2(14, 160), Vector2(SIZE.x - 14, 160), Color(metal, 0.75))
	Style.diamond(rid, Vector2(SIZE.x * 0.5, 160), 3.0, metal)
	# What it does -- pointed at or taken up; else only what kind it is.
	if _hover or chosen:
		var says := Lang.t(Content.STARS[star].says) if star != "" else Content.offer_text(c)
		draw_multiline_string(Fonts.serif(600), Vector2(10, 176), says, HORIZONTAL_ALIGNMENT_CENTER,
			SIZE.x - 20, 11, 3, Color(Style.PARCHMENT, 0.92))
	else:
		_text(Vector2(SIZE.x * 0.5, 184), footer(), 10, Color(metal, 0.8), Fonts.serif(700), HORIZONTAL_ALIGNMENT_CENTER)
	Style.hairline_rect(rid, full.grow(-0.5), Color(metal, 0.45), Color(metal, 0.9), 10.0)
	if marked:
		Style.fill(rid, full, 8.0, Color(0.45, 0.05, 0.03, 0.45), Color(0.3, 0.02, 0.02, 0.55))
		_text(Vector2(SIZE.x * 0.5, 98), Lang.t("去掉"), 28, Color(1.0, 0.88, 0.82), Fonts.serif(900), HORIZONTAL_ALIGNMENT_CENTER, 7)
	if token() != "":
		_token(Vector2(22, 22), Lang.t(token()))
	else:
		_price(Vector2(22, 22))
	if star != "":
		_food()
	else:
		_genes()
	if not affordable:
		Style.fill(rid, full.grow(-1.0), 8.0, Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.5))


## The card's body: its dark, shaded top to bottom, its corners rounded; a soft shadow under it.
func _body(full: Rect2) -> void:
	var rid := get_canvas_item()
	for i in 4:
		var g := 1.0 + i * 2.0
		Style.fill(rid, full.grow(g), 8.0 + g, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.12 * (1.0 - i / 4.0)), Vector2(0, 3.0 + i))
	Style.fill(rid, full, 8.0, BODY_TOP, BODY_BOTTOM)


## Its painting (tools/paint_cards.py), or else the model's portrait; null while neither is to hand.
func _art() -> Texture2D:
	var key := ""
	match str(c.get("type", "")):
		"build":
			key = "b_" + str(c.builds)
		"affix":
			key = "a_" + str(c.affix)
		"raise":
			key = "raise"
		"star":
			key = "s_" + star
	if key != "" and not _arts.has(key):
		_arts[key] = Art.of(key)
		# A texture loaded while drawing is not ready to show until the next frames: drawn again then.
		_redraw_soon()
	if _arts.get(key) != null:
		return _arts[key]
	if star != "":
		return null
	return Portraits.of_offer(c, func(_t: Texture2D) -> void:
		if is_instance_valid(self):
			queue_redraw())


func _redraw_soon() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		queue_redraw()


## `tex` filling `r` (its middle, cropped to `r`'s shape), its corners cut round by `radius`.
func _rounded_texture(tex: Texture2D, r: Rect2, radius: float) -> void:
	var ts := tex.get_size()
	var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
	var shown := r.size / k                     # how much of the texture shows, in its own pixels
	var origin := (ts - shown) * 0.5
	origin.y *= 0.7                             # a little nearer its top: heads are high
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var corners := [[r.position + Vector2(radius, radius), PI], [Vector2(r.end.x - radius, r.position.y + radius), PI * 1.5],
		[r.end - Vector2(radius, radius), 0.0], [Vector2(r.position.x + radius, r.end.y - radius), PI * 0.5]]
	for corner in corners:
		for i in 5:
			var p: Vector2 = (corner[0] as Vector2) + Vector2.from_angle(float(corner[1]) + PI * 0.5 * i / 4.0) * radius
			pts.append(p)
			uvs.append((origin + (p - r.position) / k) / ts)
	draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)


## The price on a gold coin at the painting's top left (greyed when it cannot be paid).
func _price(at: Vector2) -> void:
	var price_text := ("%d+" % c.price) if c.type == "raise" else ("%d" % c.price)
	draw_circle(at + Vector2(0, 2), 15.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	Icons.draw(self, Icons.GOLD, at, 32.0, affordable)
	var f := Fonts.numbers()
	var px := 17 if price_text.length() < 2 else 14
	_text(at + Vector2(0, px * 0.36), price_text, px, Color(0.24, 0.12, 0.02) if affordable else Color(0.2, 0.18, 0.16), f,
		HORIZONTAL_ALIGNMENT_CENTER)


## A good had already: its token (存, 带) on a jade stone where the price would be.
func _token(at: Vector2, text: String) -> void:
	draw_circle(at + Vector2(0, 2), 14.0, Color(0, 0, 0, 0.45), true, -1.0, true)
	draw_circle(at, 13.0, Style.JADE.darkened(0.25), true, -1.0, true)
	draw_circle(at + Vector2(-3, -4), 6.0, Color(1, 1, 1, 0.2), true, -1.0, true)
	draw_arc(at, 13.0, 0.0, TAU, 40, Color(Style.GOLD_BRIGHT, 0.9), 1.2, true)
	var px := 15 if not Lang.english() else 11
	_text(at + Vector2(0, px * 0.36), text, px, Color(0.04, 0.12, 0.08), Fonts.serif(900), HORIZONTAL_ALIGNMENT_CENTER)


## What else it costs (research points, as many as it costs here) at the painting's top right: a flask and how many --
## not for a good had already.
func _genes() -> void:
	if token() != "":
		return
	var n := genes_shown if genes_shown >= 0 else int(c.get("genes", 0))
	if n <= 0:
		return
	var short: bool = purse.has("genes") and n > int(purse.genes)
	var at := Vector2(SIZE.x - 20.0, 20.0)
	draw_circle(at + Vector2(0, 2), 13.0, Color(0, 0, 0, 0.5), true, -1.0, true)
	draw_circle(at, 12.0, Color(0.02, 0.06, 0.06, 0.85), true, -1.0, true)
	draw_arc(at, 12.0, 0.0, TAU, 40, Color(GENES, 0.8), 1.0, true)
	Icons.draw(self, Icons.RESEARCH, at + Vector2(0, -1), 18.0)
	_text(at + Vector2(9, 13), str(n), 13, Style.CORAL if short else Color(0.85, 1.0, 0.95), Fonts.numbers(),
		HORIZONTAL_ALIGNMENT_CENTER, 3)


## What a star eats a round, at the painting's top right: a green drop and how much (none: nothing shown).
func _food() -> void:
	var n := int(Content.STARS[star].eat)
	if n <= 0:
		return
	var at := Vector2(SIZE.x - 20.0, 20.0)
	draw_circle(at + Vector2(0, 2), 13.0, Color(0, 0, 0, 0.5), true, -1.0, true)
	draw_circle(at, 12.0, Color(0.03, 0.07, 0.03, 0.85), true, -1.0, true)
	draw_arc(at, 12.0, 0.0, TAU, 40, Color(FOOD, 0.8), 1.0, true)
	Icons.draw(self, Icons.BIOMASS, at + Vector2(0, -1), 18.0)
	_text(at + Vector2(9, 13), str(n), 13, Color(0.9, 1.0, 0.85), Fonts.numbers(), HORIZONTAL_ALIGNMENT_CENTER, 3)


## What kind of good it is, said at its foot: a building's part of the homeland and its school, how rare it is.
func footer() -> String:
	if star != "":
		var s: Dictionary = Content.STARS[star]
		return " · ".join([Lang.t("明星恐龙"), Lang.t(Content.DIETS[s.diet]), Lang.t(RARITY[int(s.rarity)])])
	var bits: Array = [Lang.t(Content.TYPES[c.type])]
	if c.type == "build":
		var b: Dictionary = Content.BUILDINGS[c.builds]
		bits = [Lang.t("巢 · 阵地" if b.has("nest") else "后方")]
		if b.has("school"):
			bits.append(Lang.t(Content.SCHOOLS[b.school].name))
	bits.append(Lang.t(RARITY[int(c.rarity)]))
	return " · ".join(bits)


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
