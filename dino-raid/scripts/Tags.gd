class_name Tags
extends Control
## Words and marks drawn over the blocks each frame (GAME-DESIGN 14, 17): over each building its level as dots, over a
## nest how many it hatches this round -- and of what species, when it has evolved -- (and how many the biomass could
## not pay for); while a good is held over a plot, what it would change for each building -- "+1 只", "血 +25%";
## while packing, whether the ark takes each building or leaves it; in a battle each fighter's health; numbers that
## rise off what was hit. What a building is and does, the panel says when it is pointed at.

const OURS := Color(0.47, 0.86, 0.36)
const THEIRS := Color(0.96, 0.36, 0.26)
const GOLD := Color(1.0, 0.82, 0.3)
const GOOD := Color(0.75, 1.0, 0.45)
const BAD := Color(1.0, 0.45, 0.38)

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
	if game.phase == Game.Phase.MOVE:
		return
	var home: Home = game.home
	var hv: HomeView = game.home_view
	var made := {}
	for u in home.army():
		made[u.nest] = int(made.get(u.nest, 0)) + 1
	var effects: Dictionary = game.effects
	var packing: bool = game.phase == Game.Phase.PACK
	for p in home.buildings:
		var b: Dictionary = home.buildings[p]
		var at3 := hv.top(p) + Vector3.UP * 0.25
		if cam.is_position_behind(at3):
			continue
		var at := cam.unproject_position(at3)
		_dots(at + Vector2(0, -6), int(b.level))
		var y := -22.0
		if packing:
			var taken: bool = game.pack_plots.has(p)
			_text(at + Vector2(0, y), "带走" if taken else "留下", GOLD if taken else Color(0.72, 0.7, 0.66), 18 if taken else 14,
				Fonts.serif(900))
			continue
		if Content.is_nest(b.kind):
			var want := home.count(p)
			var got := int(made.get(p, 0))
			var sp := Content.species(Content.BUILDINGS[b.kind].nest, b.affixes)
			var col: Color = GOLD if sp.used.is_empty() else (Content.UNITS[sp.kind].color as Color).lightened(0.45)
			var stars: int = b.path.count("elite")
			_text(at + Vector2(0, y), "孵 %d%s" % [got, (" " + "★".repeat(stars)) if stars > 0 else ""], col, 15, Fonts.serif(900))
			y -= 17.0
			if got < want:
				_text(at + Vector2(0, y), "少孵 %d" % (want - got), BAD, 14, Fonts.serif(900))
				y -= 16.0
		for line in effects.get(p, []):
			var s: String = line
			_text(at + Vector2(0, y), s, BAD if s.contains("-") or s.contains("−") else GOOD, 15, Fonts.serif(900))
			y -= 17.0
	for p in effects:
		if home.buildings.has(p):
			continue
		var at3 := HomeView.plot_pos(p) + Vector3.UP * 1.0
		if cam.is_position_behind(at3):
			continue
		var y := 0.0
		for line in effects[p]:
			var s: String = line
			_text(cam.unproject_position(at3) + Vector2(0, y), s, BAD if s.contains("-") or s.contains("−") else GOOD, 15,
				Fonts.serif(900))
			y -= 17.0


## The level as dots: filled up to it, of the most there can be.
func _dots(at: Vector2, level: int) -> void:
	var n := Content.LEVEL_MAX
	for i in n:
		var c := at + Vector2((i - (n - 1) * 0.5) * 9.0, 0)
		draw_circle(c, 3.6, Color(0, 0, 0, 0.75))
		draw_circle(c, 2.6, GOLD if i < level else Color(0.35, 0.33, 0.3))


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


func _text(at: Vector2, text: String, c: Color, size: int, f: Font) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, size * 0.35)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, c.a * 0.85))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
