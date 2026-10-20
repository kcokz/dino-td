class_name UiArt
## The frames as made things (GAME-DESIGN 23; tools/ui_art.py): mouldings of old gold with amber stones over their cut
## corners (copper ones for danger, dark bronze for what is quiet or cannot be had), finer ones for buttons;
## nameplates and bars of slate in gold rims; round rims, round plates of slate, the great seal; small stones in gold;
## enamelled shields -- modelled and lit, rendered at twice the size they are shown at, drawn here stretched only along
## their straight parts (nine-patch) so their corners and stones keep their shape at any size.

const DIR := "res://assets/ui/"
const SCALE := 0.5                 # shown at half the size they were rendered at
const SQ := 0.5857864              # how much a cut corner's cut shrinks for each pixel moved in (2 - sqrt 2)

static var _info := {}
static var _tex := {}


## What tools/ui_art.py says of piece `name`: its size, how far its picture runs past its edge (`pad`, its shadow), its
## nine-patch margins, its rim's radius and band...
static func info(name: String) -> Dictionary:
	if _info.is_empty():
		var f := FileAccess.open(DIR + "ui_art.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_info = parsed
	return _info.get(name, {})


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png") if ResourceLoader.exists(DIR + name + ".png") else null
	return _tex[name]


## How wide piece `name`'s rim is, and how much its corners are cut, as shown.
static func band(name: String) -> float:
	return float(info(name).get("band", 0.0)) * SCALE


static func cut(name: String) -> float:
	return float(info(name).get("cut", 0.0)) * SCALE


## The frame, plate or bar `name` round `r` (on canvas item `ci`): its outer edge on `r`'s edge, its own shadow past it;
## its corners (or ends) whole, the rest stretched to fit.
static func frame(ci: RID, name: String, r: Rect2, modulate := Color.WHITE) -> void:
	var i := info(name)
	var t := tex(name)
	if t == null or i.is_empty():
		return
	var pad := float(i.get("pad", 0.0))
	var mx := float(i.get("margin", i.get("margin_x", 0.0)))
	var my := float(i.get("margin", i.get("margin_y", 0.0)))
	var k := 1.0 / SCALE
	var big := Rect2(r.position * k - Vector2(pad, pad), r.size * k + Vector2(pad, pad) * 2.0)
	# Never smaller than its corners: a frame too small for them is drawn as small as they allow, round its middle.
	var least := Vector2(mx * 2.0 + 2.0, my * 2.0 + 2.0 if my > 0.0 else 0.0)
	if big.size.x < least.x or big.size.y < least.y:
		var c := big.get_center()
		big.size = big.size.max(least)
		big.position = c - big.size * 0.5
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2.ZERO))
	RenderingServer.canvas_item_add_nine_patch(ci, big, Rect2(Vector2.ZERO, t.get_size()), t.get_rid(), Vector2(mx, my),
		Vector2(mx, my), RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, modulate)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)


## The round piece `name` (a rim, a round plate, the seal, a stone) with its outside `radius` from `c` (on `item`).
static func disc(item: CanvasItem, name: String, c: Vector2, radius: float, modulate := Color.WHITE) -> void:
	var i := info(name)
	var t := tex(name)
	if t == null or i.is_empty():
		return
	var k := radius / maxf(1.0, float(i.get("radius", t.get_size().x * 0.5)))
	var size := t.get_size() * k
	item.draw_texture_rect(t, Rect2(c - size * 0.5, size), false, modulate)


## The jewel on a heading panel's top edge (UiArt "crest"), its middle at `c`, `size` across (on canvas item `ci`).
static func jewel(ci: RID, c: Vector2, size: float) -> void:
	var t := tex("crest")
	if t == null:
		return
	var i := info("crest")
	var k := size / maxf(1.0, t.get_size().x - float(i.get("pad", 0.0)) * 2.0)
	var s := t.get_size() * k
	RenderingServer.canvas_item_add_texture_rect(ci, Rect2(c - s * 0.5, s), t.get_rid())


## Piece `name` drawn whole over `r` -- its edge on `r`'s, its shadow past it (a card's frame: always one size).
static func whole(item: CanvasItem, name: String, r: Rect2, modulate := Color.WHITE) -> void:
	var t := tex(name)
	if t == null:
		return
	var pad := float(info(name).get("pad", 0.0)) * SCALE
	item.draw_texture_rect(t, Rect2(r.position - Vector2(pad, pad), r.size + Vector2(pad, pad) * 2.0), false, modulate)


## Piece `name` drawn whole, its middle at `c`, `height` tall as shown (a shield, the crest's jewel).
static func piece(item: CanvasItem, name: String, c: Vector2, height: float, modulate := Color.WHITE) -> void:
	var i := info(name)
	var t := tex(name)
	if t == null or i.is_empty():
		return
	var inner := t.get_size().y - float(i.get("pad", 0.0)) * 2.0
	var k := height / maxf(1.0, inner)
	var size := t.get_size() * k
	item.draw_texture_rect(t, Rect2(c - size * 0.5, size), false, modulate)
