extends SceneTree
## tools/build_ui_textures.gd -- the interface's materials, drawn by rule.
##
## v0.6 feedback, twice: "我想要的主题是那种远古时代质感的菜单界面，状态栏", and then -- of slabs of
## stone and planks of wood -- "还是没到优秀游戏的质感". What the good ones do (Northgard, Age of
## Empires IV, Horizon's tribes) is FRAME things: a quiet fill that what a panel holds reads
## on, a rim of a different material round it, ornament kept to the corners and the headings,
## icons sat in sockets, bars capped at their ends. So a panel here is dark tanned leather in a
## rim of bone, pegged at each corner with a knuckle of it; the ship's own things -- the
## beacon, what it knows -- are slate in steel with a line of cyan light; a button is leather
## in a thinner rim, the one thing to press painted ochre; a portrait sits in a sunk socket; a
## toast is a stroke of ink from a broad brush; a bar is a
## trough capped with bone with pigment in it; a title stands over a rule with a tooth of bone
## at its middle. Cards and tooltips stay a stitched hide.
##
##   godot --headless --path . --script res://tools/build_ui_textures.gd [-- frame button ...]
##
## What the game needs to know about a surface -- its size, where it is cut into nine, how far
## its shadow reaches -- is Config.THEME.surfaces, and is read from there. How it LOOKS (the
## noise, the colours, the rim) is here, as a model's look is in tools/generate_props.py.
##
## UiTheme cuts each into nine (StyleBoxTexture) and tiles the middle and the edges to fit, so
## every surface is drawn to tile: its middle is seamless, and each edge repeats over exactly
## the length of the middle beside it, starting where the corner piece leaves off. Whatever
## depends on how far a pixel is from the edge -- a rim, its shadow, the fill darkening towards
## it -- is over before the middle begins (_framed checks), and whatever is drawn once -- a
## knuckle, a brush's ragged end -- lives in the corner or end pieces. One small image covers a
## panel of any size without stretching its grain.
##
## v0.6 round three: "界面格局还是不够精致……往精致游戏上靠近，比如学习暗黑破坏神4的那种界面风格，或者艾尔登
## 环，界面质感在于细节，要和网页游戏区分开". The leather stays -- this is still a world of hides and
## hand work -- but it is framed the way those are: darker, and quieter, so what it holds reads;
## a rim of hammered bronze that takes a gilt sheen where the light crosses it, not pale bone; a
## gilt pinstripe a hair inside the rim; the corners held by filigree brackets instead of pegs;
## the one thing to press dyed oxblood; cards and tooltips a dark vellum written in pale ink;
## rules of gilt that fade out at their ends, a lozenge at their middle. The detail is in the
## edges -- a bevel, a highlight, a shadow the rim throws -- and the fills are left quiet.
##
## Each is drawn in its natural colour and handed to the theme at its design size though drawn
## at Config.THEME.surface_scale times it: crisp on a 1440p screen, where the 1280x720 design is
## drawn at 2x. The theme only tints them for a state (Config.THEME.tints): lit under the
## cursor, dimmed when it cannot be pressed.

const CONFIG := "res://scripts/autoload/Config.gd"
## Light falls from the top left and a little in front.
const LIGHT := Vector3(-0.42, -0.62, 0.66)

## The materials' own colours.
const BONE := Color(0.85, 0.79, 0.66)            # a knuckle of bone, where one is still pegged
const BRONZE := Color(0.46, 0.34, 0.19)          # a rim, a bracket, a bar's cap: hammered bronze
const GILT := Color(0.83, 0.67, 0.40)            # the pinstripe inside a rim, a rule, an ornament
const STEEL := Color(0.57, 0.61, 0.65)           # the ship's rim and rivets
const EDGE := Color(0.03, 0.024, 0.019)          # the dark line round everything
const LEATHER := Color(0.082, 0.068, 0.056)      # a panel's fill: dark, so what it holds reads
const TOOLED := Color(0.125, 0.101, 0.08)        # a button's: a shade up from the panel under it
const OCHRE := Color(0.36, 0.095, 0.06)          # the one thing to press: oxblood
const HOLLOW := Color(0.04, 0.033, 0.027)        # a socket's floor
const SLATE := Color(0.085, 0.105, 0.125)        # the ship's panel
const CYAN := Color(0.42, 0.78, 0.88, 0.85)      # the ship's light
const INK := Color(0.075, 0.06, 0.048, 0.93)     # a toast's brush stroke

var _k: int = 2          # Config.THEME.surface_scale: pixels drawn per design pixel

func _init() -> void:
	var theme: Dictionary = (load(CONFIG) as GDScript).get_script_constant_map()["THEME"]
	_k = int(theme.get("surface_scale", 2))
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var surfaces: Dictionary = theme.get("surfaces", {})
	for name in surfaces:
		if not wanted.is_empty() and not wanted.has(String(name)):
			continue
		var spec: Dictionary = surfaces[name]
		var img: Image = call("_draw_" + String(name), spec)
		var path: String = String(spec["image"])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		img.save_png(path)
		_stub(path)
		print("[OK] ", path, " ", img.get_size())
	quit()

## An import stub, the first time: a surface comes in as an Image, and UiTheme makes the
## texture from it at its design size -- not a texture of its own at twice that.
func _stub(path: String) -> void:
	var stub: String = path + ".import"
	if FileAccess.file_exists(stub):
		return
	var f := FileAccess.open(stub, FileAccess.WRITE)
	f.store_string('[remap]\n\nimporter="image"\ntype="Image"\n')
	f.close()

# ==============================================================================
# The shape of a surface
# ==============================================================================

## A surface's outline: a rounded rectangle `pad` in from the image's edge, each side wandering
## inward -- a few whole waves over the length of the middle it runs beside, and a few chips
## near its ends.
class Outline:
	const BORDER := 24          # samples kept past each end, for shadows and slopes
	var w: int
	var h: int
	var pad: float
	var radius: float
	var top: PackedFloat32Array
	var bottom: PackedFloat32Array
	var left: PackedFloat32Array
	var right: PackedFloat32Array

	## How far pixel (x, y) is inside the outline, in pixels; negative outside.
	func inside(x: int, y: int) -> float:
		var xi: int = clampi(x, -BORDER, w + BORDER - 1) + BORDER
		var yi: int = clampi(y, -BORDER, h + BORDER - 1) + BORDER
		var px: float = float(x) + 0.5
		var py: float = float(y) + 0.5
		var ex: float = minf(px - pad - left[yi], float(w) - pad - right[yi] - px)
		var ey: float = minf(py - pad - top[xi], float(h) - pad - bottom[xi] - py)
		if ex < radius and ey < radius:
			return radius - Vector2(radius - ex, radius - ey).length()
		return minf(ex, ey)

	## How far below the top side (x, y) is.
	func from_top(x: int, y: int) -> float:
		var xi: int = clampi(x, -BORDER, w + BORDER - 1) + BORDER
		return float(y) + 0.5 - pad - top[xi]

	## How far in from the nearer of the two upright sides, and of the two level ones.
	func sides(x: int, y: int) -> Vector2:
		var xi: int = clampi(x, -BORDER, w + BORDER - 1) + BORDER
		var yi: int = clampi(y, -BORDER, h + BORDER - 1) + BORDER
		var px: float = float(x) + 0.5
		var py: float = float(y) + 0.5
		return Vector2(minf(px - pad - left[yi], float(w) - pad - right[yi] - px),
			minf(py - pad - top[xi], float(h) - pad - bottom[xi] - py))

## An outline for a surface `w` x `h` pixels cut at `m`: `radius` its corners, `depth` how far
## its long sides wander in and `end_depth` its short ones, `chips` bites out of each side --
## all in design pixels.
func _outline(w: int, h: int, m: Vector2i, pad: float, radius: float, depth: float, end_depth: float, chips: int, seed: int) -> Outline:
	var o := Outline.new()
	o.w = w
	o.h = h
	o.pad = pad
	o.radius = radius * _k
	o.top = _side(w, m.x, depth, chips, seed)
	o.bottom = _side(w, m.x, depth, chips, seed + 1)
	o.left = _side(h, m.y, end_depth, chips, seed + 2)
	o.right = _side(h, m.y, end_depth, chips, seed + 3)
	return o

## How far one side runs in at each pixel along it -- `n` of them, the middle starting at `m`:
## a sum of whole waves over the middle's length, so the side of a tiled middle tiles too; and
## `chips` bites out of it, all in the two end pieces. Those are drawn once at each corner of a
## panel however long it is, where a chip on the middle's stretch would come round again every
## tile and read as a pattern down a wide panel.
func _side(n: int, m: int, depth: float, chips: int, seed: int) -> PackedFloat32Array:
	var period: float = maxf(1.0, float(n - 2 * m))
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var waves: Array[Vector3] = []
	var total: float = 0.0
	for k in [1, 2, 3, 5, 8, 13]:
		var a: float = r.randf_range(0.35, 1.0) / sqrt(float(k))
		total += a
		waves.append(Vector3(float(k), a, r.randf_range(0.0, TAU)))
	var bites: Array[Vector3] = []
	for i in chips:
		# Where along the side (in the first end piece or the last, past the rounded corner and
		# clear of the middle), how deep, how wide.
		var wide: float = r.randf_range(2.0, 4.0) * _k
		var at: float = r.randf_range(0.45, 0.8) * float(m)
		bites.append(Vector3(at if i % 2 == 0 else float(n) - at, r.randf_range(0.8, 1.5) * depth * _k, wide))
	var out := PackedFloat32Array()
	out.resize(n + 2 * Outline.BORDER)
	for i in out.size():
		var x: float = float(i - Outline.BORDER) + 0.5
		var t: float = fposmod(x - float(m), period)
		var v: float = 0.0
		for wv in waves:
			v += wv.y * sin(TAU * wv.x * t / period + wv.z)
		var d: float = (v / total * 0.5 + 0.5) * depth * _k
		# A bite fades out before the middle begins, so the end piece still meets it cleanly.
		var in_end: float = 1.0 - smoothstep(float(m) * 0.85, float(m), minf(x, float(n) - x))
		for b in bites:
			var off: float = absf(x - b.x)
			d += b.y * exp(-(off / b.z) * (off / b.z)) * in_end
		out[i] = d
	return out

# ==============================================================================
# What a surface is made of
# ==============================================================================

## A field of values 0..1 laid over a surface's middle and repeating from it, so a tiled
## middle meets its tiled edges without a seam.
class Field:
	var w: int
	var h: int
	var ox: int
	var oy: int
	var data: PackedByteArray

	func at(x: int, y: int) -> float:
		return float(data[posmod(y - oy, h) * w + posmod(x - ox, w)]) / 255.0

func _field(img: Image, origin: Vector2i) -> Field:
	img.convert(Image.FORMAT_L8)
	var f := Field.new()
	f.w = img.get_width()
	f.h = img.get_height()
	f.ox = origin.x
	f.oy = origin.y
	f.data = img.get_data()
	return f

## Noise the size of a middle that repeats exactly across it; `frequency` in waves per design
## pixel, rounded to a whole number of waves across the middle (at least two: a feature as big
## as the middle would show as a pattern, repeated panel after panel).
##
## Gradient noise on a lattice whose gradients repeat, not the engine's seamless image: that
## one blends a skirt of the noise back over itself, and the blend leaves a pale cross through
## the middle -- invisible in one tile, a grid of crosses across a panel.
func _noise(size: Vector2i, seed: int, frequency: float, octaves: int) -> Image:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var cells := Vector2i(maxi(2, int(round(float(size.x) * frequency / float(_k)))),
		maxi(2, int(round(float(size.y) * frequency / float(_k)))))
	var layers: Array[TileNoise] = []
	var weights: Array[float] = []
	for i in octaves:
		layers.append(TileNoise.new(cells * int(pow(2.0, float(i))), r))
		weights.append(pow(0.5, float(i)))
	var values := PackedFloat32Array()
	values.resize(size.x * size.y)
	var lo: float = INF
	var hi: float = -INF
	for y in size.y:
		for x in size.x:
			var v: float = 0.0
			for i in layers.size():
				var l: TileNoise = layers[i]
				v += weights[i] * l.at(float(x) / float(size.x) * float(l.cells.x), float(y) / float(size.y) * float(l.cells.y))
			values[y * size.x + x] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	var span: float = maxf(hi - lo, 0.0001)
	for y in size.y:
		for x in size.x:
			var n: float = (values[y * size.x + x] - lo) / span
			img.set_pixel(x, y, Color(n, n, n))
	return img

## Gradient noise over a lattice `cells` across whose gradients wrap round: sampled over
## 0..cells it repeats exactly.
class TileNoise:
	var cells: Vector2i
	var grads: PackedVector2Array

	func _init(c: Vector2i, r: RandomNumberGenerator) -> void:
		cells = c
		grads.resize(c.x * c.y)
		for i in grads.size():
			grads[i] = Vector2.from_angle(r.randf_range(0.0, TAU))

	func _grad(i: int, j: int) -> Vector2:
		return grads[posmod(j, cells.y) * cells.x + posmod(i, cells.x)]

	func at(u: float, v: float) -> float:
		var i: int = floori(u)
		var j: int = floori(v)
		var fx: float = u - float(i)
		var fy: float = v - float(j)
		var a: float = _grad(i, j).dot(Vector2(fx, fy))
		var b: float = _grad(i + 1, j).dot(Vector2(fx - 1.0, fy))
		var c: float = _grad(i, j + 1).dot(Vector2(fx, fy - 1.0))
		var d: float = _grad(i + 1, j + 1).dot(Vector2(fx - 1.0, fy - 1.0))
		var sx: float = fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0)
		var sy: float = fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0)
		return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)

## Cracks over a middle `size`: the borders between `cells` cells scattered over it, measured
## round the middle as round a torus so they tile, and bent by noise so they wander like cracks
## rather than run straight like a honeycomb's. 1 on a crack, falling to 0 over `width` design
## pixels either side.
func _cracks(size: Vector2i, origin: Vector2i, cells: int, width: float, bend: float, seed: int) -> Field:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var points: Array[Vector2] = []
	for i in cells:
		points.append(Vector2(r.randf_range(0.0, size.x), r.randf_range(0.0, size.y)))
	var bend_x := _field(_noise(size, seed + 1, 0.02, 2), Vector2i.ZERO)
	var bend_y := _field(_noise(size, seed + 2, 0.02, 2), Vector2i.ZERO)
	var data := PackedByteArray()
	data.resize(size.x * size.y)
	var fw: float = float(size.x)
	var fh: float = float(size.y)
	var reach: float = bend * _k
	for y in size.y:
		for x in size.x:
			var p := Vector2(float(x) + (bend_x.at(x, y) - 0.5) * reach, float(y) + (bend_y.at(x, y) - 0.5) * reach)
			var f1: float = INF
			var f2: float = INF
			for q in points:
				var dx: float = absf(p.x - q.x)
				dx = fposmod(dx, fw)
				dx = minf(dx, fw - dx)
				var dy: float = absf(p.y - q.y)
				dy = fposmod(dy, fh)
				dy = minf(dy, fh - dy)
				var dd: float = sqrt(dx * dx + dy * dy)
				if dd < f1:
					f2 = f1
					f1 = dd
				elif dd < f2:
					f2 = dd
			var v: float = 1.0 - smoothstep(0.0, width * _k, f2 - f1)
			data[y * size.x + x] = int(clampf(v, 0.0, 1.0) * 255.0)
	var f := Field.new()
	f.w = size.x
	f.h = size.y
	f.ox = origin.x
	f.oy = origin.y
	f.data = data
	return f

# ==============================================================================
# Light and shadow
# ==============================================================================

## The light on the surface at (x, y), 0 where it is flat: its height rises by `rise` over the
## `bevel` in from its outline (design pixels; a negative rise is a hollow), and the slope that
## faces the light is lit and the one that faces away is shaded.
func _light(o: Outline, x: int, y: int, bevel: float, rise: float) -> float:
	var b: float = bevel * _k
	var r: float = rise * _k
	if o.inside(x, y) > b + 2.0:
		return 0.0
	var gx: float = (r * smoothstep(0.0, b, o.inside(x + 1, y)) - r * smoothstep(0.0, b, o.inside(x - 1, y))) * 0.5
	var gy: float = (r * smoothstep(0.0, b, o.inside(x, y + 1)) - r * smoothstep(0.0, b, o.inside(x, y - 1))) * 0.5
	var n := Vector3(-gx, -gy, 1.0).normalized()
	var l: Vector3 = LIGHT.normalized()
	return n.dot(l) - l.z

## The surface drawn whole: the outline smoothed, `paint` colouring each pixel inside (given
## x, y, how far in, the light there), over the shadow it casts -- `shadow` being its offset
## (x, y) and reach (z) in design pixels and its darkness (w).
func _compose(o: Outline, shadow: Vector4, bevel: float, rise: float, paint: Callable) -> Image:
	var img := Image.create(o.w, o.h, false, Image.FORMAT_RGBA8)
	var sx: int = int(round(shadow.x * _k))
	var sy: int = int(round(shadow.y * _k))
	var reach: float = maxf(1.0, shadow.z * _k)
	for y in o.h:
		for x in o.w:
			var d: float = o.inside(x, y)
			var a: float = clampf(d + 0.5, 0.0, 1.0)
			var c := Color(0, 0, 0, 0)
			if a > 0.0:
				c = paint.call(x, y, d, _light(o, x, y, bevel, rise))
			var sa: float = 0.0
			if shadow.w > 0.0 and a < 1.0:
				var out: float = -o.inside(x - sx, y - sy)
				sa = shadow.w * pow(clampf(1.0 - out / reach, 0.0, 1.0), 2.0) if out > 0.0 else shadow.w
			var total: float = a + sa * (1.0 - a)
			if total <= 0.0:
				continue
			img.set_pixel(x, y, Color(c.r * a / total, c.g * a / total, c.b * a / total, total))
	return img

## A colour lit by `lit` (from _light): brighter towards the light, darker away.
func _shade(c: Color, lit: float, strength: float) -> Color:
	var f: float = 1.0 + lit * strength
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0))

## [width, height, margin, pad] of a surface, in pixels.
func _geo(spec: Dictionary) -> Array:
	var size: Vector2i = Vector2i(spec["size"]) * _k
	var m: Vector2i = Vector2i(spec["margin"]) * _k
	return [size.x, size.y, m, float(int(spec.get("pad", 0)) * _k)]

# ==============================================================================
# Frames: every panel, plate, button and socket
# ==============================================================================

func _draw_frame(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": LEATHER, "rim": 2.6, "rim_color": BRONZE, "metal": true, "glow": Color(GILT, 0.38),
		"brackets": 13.0, "bracket_w": 1.5, "radius": 2.0, "vignette": 0.55, "falloff": 11.0, "top_light": 0.07,
		"seed": 71, "shadow": Vector4(0.0, 3.0, 9.0, 0.7)})

func _draw_frame_tech(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": SLATE, "rim": 2.6, "rim_color": STEEL, "metal": true, "knuckle": 2.6,
		"glow": CYAN, "radius": 3.0, "vignette": 0.4, "falloff": 11.0, "top_light": 0.08, "seed": 72})

func _draw_plate(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": LEATHER, "rim": 1.7, "rim_color": BRONZE, "metal": true, "glow": Color(GILT, 0.3),
		"edge": 0.9, "brackets": 5.0, "bracket_w": 1.1, "radius": 2.0, "vignette": 0.4, "falloff": 4.0,
		"top_light": 0.06, "seed": 73, "shadow": Vector4(0.0, 2.0, 5.0, 0.6)})

func _draw_button(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": TOOLED, "rim": 1.3, "rim_color": BRONZE, "metal": true, "glow": Color(GILT, 0.22),
		"edge": 0.9, "radius": 2.0, "vignette": 0.3, "falloff": 6.0, "top_light": 0.1, "seed": 74,
		"shadow": Vector4(0.0, 1.5, 3.5, 0.55)})

func _draw_button_accent(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": OCHRE, "rim": 1.3, "rim_color": BRONZE, "metal": true, "glow": Color(GILT, 0.45),
		"edge": 0.9, "radius": 2.0, "vignette": 0.35, "falloff": 6.0, "top_light": 0.12, "seed": 75,
		"shadow": Vector4(0.0, 1.5, 3.5, 0.55)})

## The status bar's strip: leather along the top edge of the screen, a rim of bone along its
## bottom, its shadow thrown on the world below.
func _draw_strip(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": LEATHER, "rim": 2.2, "rim_color": BRONZE, "metal": true, "glow": Color(GILT, 0.3),
		"edge": 1.0, "vignette": 0.4, "falloff": 3.5, "top_light": 0.0, "bottom_only": true, "seed": 91,
		"shadow": Vector4(0.0, 2.0, 8.0, 0.7)})

## A round button: a disc of leather in a rim of bone, domed to the light.
func _draw_round_button(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": TOOLED, "rim": 1.4, "rim_color": BRONZE, "metal": true, "edge": 0.9,
		"radius": _round(spec), "vignette": 0.35, "falloff": 6.0, "top_light": 0.12, "seed": 92,
		"shadow": Vector4(0.0, 1.5, 2.5, 0.6)})

## The one lit in a set -- the speed the game runs at: painted ochre.
func _draw_round_button_lit(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": OCHRE, "rim": 1.4, "rim_color": GILT.darkened(0.25), "metal": true, "edge": 0.9,
		"radius": _round(spec), "vignette": 0.35, "falloff": 6.0, "top_light": 0.14, "seed": 93,
		"shadow": Vector4(0.0, 1.5, 2.5, 0.6)})

## A round socket sunk in the leather, for a material's icon on the strip.
func _draw_socket_round(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": HOLLOW, "rim": 1.2, "rim_color": BRONZE, "metal": true, "edge": 0.8,
		"radius": _round(spec), "sunk": true, "vignette": 0.5, "falloff": 7.0, "top_light": 0.0, "seed": 94,
		"shadow": Vector4(0.0, 1.0, 1.5, 0.4)})

## The corner radius that makes a surface's outline a circle (design pixels).
func _round(spec: Dictionary) -> float:
	var size: Vector2i = spec["size"]
	return float(mini(size.x, size.y)) * 0.5 - float(int(spec.get("pad", 0)))

func _draw_socket(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": HOLLOW, "rim": 1.5, "rim_color": BRONZE, "metal": true, "glow": Color(GILT, 0.16),
		"edge": 0.9, "radius": 2.0, "sunk": true, "vignette": 0.55, "falloff": 10.0, "top_light": 0.0, "seed": 76,
		"shadow": Vector4(0.0, 1.0, 2.0, 0.4)})

func _draw_socket_tech(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": SLATE.darkened(0.3), "rim": 1.8, "rim_color": STEEL, "metal": true, "glow": CYAN,
		"edge": 0.9, "radius": 5.0, "sunk": true, "vignette": 0.5, "falloff": 10.0, "top_light": 0.0, "seed": 77,
		"shadow": Vector4(0.0, 1.0, 2.0, 0.4)})

## A framed surface: the family every panel, plate, button and socket belongs to. From the
## outside in -- a dark edge; a rim (`rim` design pixels of bone, or the ship's steel), half-
## round in section and lit along its crown; the shadow the rim throws on what it holds, along
## the sides the light comes over; and the fill (`fill`), darker towards the rim (`vignette`
## over `falloff`) and lit a little along the top (`top_light`), so what it holds sits in its
## light. A frame may be pegged at each corner (`knuckle`: a knuckle of bone, or on steel a
## rivet), carry a line of light just inside its rim (`glow`: the ship's instruments), or be
## sunk rather than raised (`sunk`: a socket, its floor in the rim's shadow all round). Leather
## may be tooled: a line pressed into it `tooling` design pixels inside the rim, its shadowed
## edge over its lit one, as a saddler finishes an edge. A button may carry a bone stud at each
## end (`studs`), in its end pieces, so it is studded once however long it is.
func _framed(spec: Dictionary, look: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var pad: float = g[3]
	var k: float = float(_k)
	var seed: int = int(look.get("seed", 71))
	var edge: float = float(look.get("edge", 1.0)) * k
	var rim_in: float = edge + float(look.get("rim", 3.0)) * k
	var falloff: float = float(look.get("falloff", 8.0)) * k
	# Everything that depends on how far in a pixel is has to be over before the middle
	# begins, or the tiled middle carries a band of it at every repeat.
	var room: float = float(mini(m.x, m.y)) - pad
	assert(rim_in + falloff <= room, "%s: rim and falloff (%.1f px) run past the margin (%.1f px)" % [spec["image"], rim_in + falloff, room])
	var mid := Vector2i(w - 2 * m.x, h - 2 * m.y)
	var o := _outline(w, h, m, pad, float(look.get("radius", 4.0)), 0.12, 0.12, 0, seed)
	if bool(look.get("bottom_only", false)):
		# A strip along the top of the screen: its top and ends run off it, so the only edge it
		# has -- and the only rim -- is along its bottom.
		o.radius = 0.0
		for i in o.top.size():
			o.top[i] = -100000.0
		for i in o.left.size():
			o.left[i] = -100000.0
			o.right[i] = -100000.0
	var mottle := _field(_noise(mid, seed, 0.025, 3), m)
	var grain := _field(_noise(mid, seed + 1, 0.55, 1), m)
	var streak := _field(_noise(mid, seed + 2, 0.15, 2), m)
	var rim: Color = look.get("rim_color", BONE)
	var metal: bool = bool(look.get("metal", false))
	var sunk: bool = bool(look.get("sunk", false))
	var fill: Color = look["fill"]
	var top_light: float = float(look.get("top_light", 0.1))
	var vignette: float = float(look.get("vignette", 0.35))
	var glow: Color = look.get("glow", Color(0, 0, 0, 0))
	var knuckle: float = float(look.get("knuckle", 0.0)) * k
	# A knuckle sits in the corner, its ring just inside the outline: over the rim's turn. It is
	# drawn once per corner, so it -- and its shadow -- must stay in the corner piece.
	var centre: float = pad + knuckle + 1.2 * k
	if knuckle > 0.0:
		var reach: float = centre + 0.8 * k + knuckle + 0.9 * k + 0.8 * k
		assert(reach <= float(mini(m.x, m.y)), "%s: a knuckle reaches %.1f px, past the corner piece (%d px)" % [spec["image"], reach, mini(m.x, m.y)])
	var knuckles: Array[Vector2] = []
	if knuckle > 0.0:
		knuckles = [Vector2(centre, centre), Vector2(float(w) - centre, centre),
			Vector2(centre, float(h) - centre), Vector2(float(w) - centre, float(h) - centre)]
	var tooling: float = float(look.get("tooling", 0.0)) * k
	assert(rim_in + tooling + 1.5 * k <= room, "%s: the tooled line runs past the margin" % spec["image"])
	# A stud at each end, halfway down: a button is stretched top to bottom, never tiled, so the
	# two stay two.
	var stud: float = float(look.get("studs", 0.0)) * k
	if stud > 0.0:
		assert(not bool(spec.get("tile_v", true)), "%s: studs need the height stretched, not tiled" % spec["image"])
		var at: float = pad + rim_in + stud + 0.8 * k
		# The stud, its ring and the shadow it throws right all stay in the end piece.
		assert(at + 0.8 * k + stud + 0.9 * k + 0.8 * k <= float(m.x), "%s: a stud reaches past the end piece" % spec["image"])
		knuckles.append(Vector2(at, float(h) * 0.5))
		knuckles.append(Vector2(float(w) - at, float(h) * 0.5))
	var peg_size: Array[float] = []
	for i in knuckles.size():
		peg_size.append(knuckle if i < 4 and knuckle > 0.0 else stud)
	# Filigree brackets holding each corner: an L of bronze inside the rim, its arms tapering to a
	# point, a lozenge at its heel -- in the corner pieces, drawn once however big the panel.
	var bracket: float = float(look.get("brackets", 0.0)) * k
	var bracket_w: float = float(look.get("bracket_w", 1.4)) * k
	var bracket_at: float = pad + rim_in + 0.6 * k
	if bracket > 0.0:
		assert(bracket_at + bracket + 1.5 * k <= float(mini(m.x, m.y)), "%s: a bracket reaches past the corner piece" % spec["image"])
	var paint := func(x: int, y: int, d: float, _lit: float) -> Color:
		var p := Vector2(float(x) + 0.5, float(y) + 0.5)
		var col: Color
		if d < edge:
			col = EDGE
		elif d < rim_in:
			var lit: float = _strip_light(o, x, y, d, edge, rim_in, (rim_in - edge) * 0.5)
			var body: Color = rim.darkened(0.1 * (streak.at(x, y) - 0.5) + 0.04 * grain.at(x, y))
			col = _lit(body, lit, 1.05, metal)
			# The rim's own edges, a hair darker where it meets the edge and the fill.
			var across: float = (d - edge) / (rim_in - edge)
			col = col.darkened(0.25 * (1.0 - smoothstep(0.0, 0.18, minf(across, 1.0 - across))))
		else:
			# Tanned unevenly, and grained: pebbled where the hide was.
			col = fill.darkened(0.34 * (mottle.at(x, y) - 0.5) + 0.14 * (grain.at(x, y) - 0.5))
			var into: float = d - rim_in
			if tooling > 0.0:
				var off: float = into - tooling
				col = col.darkened(0.35 * clampf(0.7 * k - absf(off + 0.4 * k) + 0.5, 0.0, 1.0))
				col = col.lightened(0.14 * clampf(0.45 * k - absf(off - 0.7 * k) + 0.5, 0.0, 1.0))
			col = col.darkened(vignette * (1.0 - smoothstep(0.0, falloff, into)))
			var thrown: float = _rim_shadow(o, x, y) * (1.0 - smoothstep(0.0, (0.45 if sunk else 0.22) * falloff, into))
			col = col.darkened((0.6 if sunk else 0.45) * thrown)
			col = col.lightened(top_light * (1.0 - smoothstep(0.0, falloff, o.from_top(x, y) - rim_in)))
			if glow.a > 0.0:
				var line: float = 1.0 - smoothstep(0.35 * k, 0.85 * k, absf(into - 1.6 * k))
				col = col.lerp(Color(glow.r, glow.g, glow.b), glow.a * line)
		for i in knuckles.size():
			col = _knuckle(col, p, knuckles[i], peg_size[i], rim, metal, grain.at(x, y))
		if bracket > 0.0 and d >= rim_in:
			col = _bracket(col, x, y, w, h, bracket_at, bracket, bracket_w, rim)
		return col
	return _compose(o, look.get("shadow", Vector4(0.0, 2.5, 7.0, 0.6)), 0.0, 0.0, paint)

## `under` with a corner's filigree bracket over it where it reaches: an L laid along the rim's
## inside from the corner `at` pixels in, `length` along each side, `width` thick at the heel and
## tapering to a point; a lozenge at the heel; shaded as bronze, lit along its top-left edges,
## and throwing a shadow down and right.
func _bracket(under: Color, x: int, y: int, w: int, h: int, at: float, length: float, width: float, body: Color) -> Color:
	var k: float = float(_k)
	var px: float = float(x) + 0.5
	var py: float = float(y) + 0.5
	# Into the nearest corner's own frame: u along x from it, v along y, both inward.
	var u: float = px - at if px < float(w) * 0.5 else float(w) - at - px
	var v: float = py - at if py < float(h) * 0.5 else float(h) - at - py
	var flip_x: bool = px >= float(w) * 0.5
	var flip_y: bool = py >= float(h) * 0.5
	var col: Color = under
	# The shadow it throws on the leather, one step down and right.
	var su: float = u + (0.7 * k if not flip_x else -0.7 * k)
	var sv: float = v + (1.1 * k if not flip_y else -1.1 * k)
	if _bracket_cover(su, sv, length, width) > 0.0 and _bracket_cover(u, v, length, width) <= 0.0:
		col = col.darkened(0.45 * _bracket_cover(su, sv, length, width))
	var cover: float = _bracket_cover(u, v, length, width)
	if cover <= 0.0:
		return col
	# Lit along its edges that face the light: on the arm along the top, its upper edge; along
	# the side, its left edge -- mirrored at the far corners, where the light meets the other edge.
	var across: float
	if v <= u:
		across = v / maxf(0.001, _bracket_width(u, length, width))
		if flip_y:
			across = 1.0 - across
	else:
		across = u / maxf(0.001, _bracket_width(v, length, width))
		if flip_x:
			across = 1.0 - across
	var lit: float = 0.55 * cos(PI * clampf(across, 0.0, 1.0))
	var face: Color = _lit(body, lit, 1.0, true)
	var heel: float = 1.0 - (absf(u - 2.4 * width) + absf(v - 2.4 * width)) / (1.8 * width)
	if heel > 0.0:
		face = _lit(body.lightened(0.08), 0.5 * signf((2.4 * width - u) + (2.4 * width - v)), 1.0, true)
	var line: Color = EDGE.lerp(face, clampf(cover * 3.0, 0.0, 1.0))
	return col.lerp(line, clampf(cover * 2.0, 0.0, 1.0))

## How thick a bracket's arm is at `s` along it: full at the heel, to a point at its end.
func _bracket_width(s: float, length: float, width: float) -> float:
	return width * clampf(1.0 - 0.75 * s / length, 0.0, 1.0)

## How much of a bracket covers (u, v): its two arms and its heel's lozenge, softened a pixel.
func _bracket_cover(u: float, v: float, length: float, width: float) -> float:
	if u < -0.5 or v < -0.5:
		return 0.0
	var best: float = 0.0
	if u <= length:
		best = maxf(best, clampf(_bracket_width(u, length, width) - v + 0.5, 0.0, 1.0) * clampf(length - u + 0.5, 0.0, 1.0))
	if v <= length:
		best = maxf(best, clampf(_bracket_width(v, length, width) - u + 0.5, 0.0, 1.0) * clampf(length - v + 0.5, 0.0, 1.0))
	var heel: float = 1.8 * width - (absf(u - 2.4 * width) + absf(v - 2.4 * width))
	best = maxf(best, clampf(heel + 0.5, 0.0, 1.0))
	return best

## The light on a strip laid round inside the outline from `from` to `to` pixels in -- half-
## round in section, `height` pixels proud -- at (x, y): 0 where it would be flat.
func _strip_light(o: Outline, x: int, y: int, d: float, from: float, to: float, height: float) -> float:
	var t: float = clampf((d - from) / maxf(to - from, 0.001), 0.0, 1.0)
	var slope: float = height * PI / maxf(to - from, 0.001) * cos(PI * t)
	var g := Vector2(o.inside(x + 1, y) - o.inside(x - 1, y), o.inside(x, y + 1) - o.inside(x, y - 1)) * 0.5
	var n := Vector3(-slope * g.x, -slope * g.y, 1.0).normalized()
	var l: Vector3 = LIGHT.normalized()
	return n.dot(l) - l.z

## A colour lit by `lit`: towards the light it pales towards white -- bone and steel catch the
## light as a sheen, not as more of their own colour, which is what turns bone to brass -- and
## away from it it darkens. Steel takes a sharper highlight on top.
func _lit(c: Color, lit: float, strength: float, metal: bool = false) -> Color:
	var out: Color = c.darkened(clampf(-lit * strength, 0.0, 0.9)) if lit < 0.0 \
		else c.lerp(Color(1.0, 0.99, 0.95), clampf(lit * strength * 0.9, 0.0, 0.85))
	if metal:
		out = out.lightened(0.4 * pow(maxf(0.0, lit + 0.2), 3.0))
	return out

## How much a rim's shadow falls at (x, y): along the sides the light comes over, none along
## the others.
func _rim_shadow(o: Outline, x: int, y: int) -> float:
	var g := Vector2(o.inside(x + 1, y) - o.inside(x - 1, y), o.inside(x, y + 1) - o.inside(x, y - 1))
	if g.length() <= 0.0:
		return 0.0
	return maxf(0.0, g.normalized().dot(Vector2(-LIGHT.x, -LIGHT.y).normalized()))

## `under` with a knuckle of bone pegged through at `centre` -- or, on steel, a rivet -- laid
## over it where it reaches (p), with its dark ring and the shadow it throws down and right.
func _knuckle(under: Color, p: Vector2, centre: Vector2, radius: float, body: Color, metal: bool, noise: float) -> Color:
	var k: float = float(_k)
	var off: Vector2 = p - centre
	var r: float = off.length()
	var ring: float = radius + 0.9 * k
	# Its shadow first, on whatever is under it.
	var thrown: float = (p - centre - Vector2(0.8, 1.6) * k).length()
	var col: Color = under.darkened(0.4 * (1.0 - smoothstep(radius - 0.5 * k, ring + 0.8 * k, thrown)))
	if r >= ring + 0.5:
		return col
	var top: Color = EDGE
	if r < radius + 0.5:
		var z: float = sqrt(maxf(0.0, radius * radius - r * r))
		var n := Vector3(off.x, off.y, z).normalized()
		var l: Vector3 = LIGHT.normalized()
		var face: Color = _lit(body.darkened(0.06 * (noise - 0.5)), n.dot(l) - l.z, 1.1, metal)
		if metal:
			face = face.lightened(0.6 * pow(maxf(0.0, n.dot(l)), 20.0))
		else:
			# The peg's hole: dark, its far wall catching the light.
			var hole: float = radius * 0.32
			if r < hole + 0.5:
				var wall: Color = EDGE.lightened(0.25 * clampf((off.x + off.y) / (hole * 1.4) + 0.3, 0.0, 1.0))
				face = face.lerp(wall, clampf(hole + 0.5 - r, 0.0, 1.0))
		top = EDGE.lerp(face, clampf(radius + 0.5 - r, 0.0, 1.0))
	return col.lerp(top, clampf(ring + 0.5 - r, 0.0, 1.0))

# ==============================================================================
# The medallion: the cabin's, and the Hero's
# ==============================================================================

## The light on a half-round laid round a centre between radii `a` and `b` (pixels), at `u` (the
## way out from the centre): lit where it turns to the top left. `hollow` is a channel cut
## into the surface rather than a rim standing on it.
func _round_light(u: Vector2, r: float, a: float, b: float, hollow: bool) -> float:
	var t: float = clampf((r - a) / maxf(b - a, 0.001), 0.0, 1.0)
	var side: float = cos(PI * t) * (1.0 if hollow else -1.0)
	var n := Vector3(u.x * side, u.y * side, sin(PI * t) + 0.35).normalized()
	var l: Vector3 = LIGHT.normalized()
	return n.dot(l) - l.z

## A medallion: a disc of leather in a rim of bone, pegged at its four diagonals; inside the rim
## a channel cut round it, where a ring of pigment shows what is left (ring_fill lies in it);
## and at its middle a socket, sunk, where its portrait stands. Radii are Config's ("ring": the
## channel's inner and outer; "socket"; "rim").
func _draw_medallion(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var pad: float = g[3]
	var k: float = float(_k)
	var c := Vector2(float(w), float(h)) * 0.5
	var outer: float = float(mini(w, h)) * 0.5 - pad
	var rim_w: float = float(spec.get("rim", 4.0)) * k
	var ring: Vector2 = Vector2(spec.get("ring", Vector2(31.0, 38.0))) * float(k)
	var socket: float = float(spec.get("socket", 30.0)) * k
	var mottle := _field(_noise(Vector2i(w, h), 95, 0.03, 3), Vector2i.ZERO)
	var grain := _field(_noise(Vector2i(w, h), 96, 0.55, 1), Vector2i.ZERO)
	var pegs: Array[Vector2] = []
	for i in 4:
		var ang: float = PI * 0.25 + PI * 0.5 * float(i)
		pegs.append(c + Vector2(cos(ang), sin(ang)) * (outer - rim_w * 0.5 - 0.3 * k))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var off: Vector2 = p - c
			var r: float = off.length()
			var u: Vector2 = off / maxf(r, 0.001)
			var d: float = outer - r
			var a: float = clampf(d + 0.5, 0.0, 1.0)
			var col := Color(0, 0, 0, 0)
			if a > 0.0:
				if d < 1.0 * k:
					col = EDGE
				elif d < rim_w:
					col = _lit(BRONZE.darkened(0.04 * grain.at(x, y)), _round_light(u, r, outer - rim_w, outer - 1.0 * k, false), 1.05, true)
				elif r > ring.y + 0.8 * k:
					col = LEATHER.darkened(0.3 * (mottle.at(x, y) - 0.5))
					col = col.darkened(0.35 * (1.0 - smoothstep(0.0, 2.0 * k, d - rim_w)))
				elif r > ring.x - 0.8 * k:
					# The channel the ring of pigment lies in: dark, shadowed on the side the
					# light comes over.
					col = HOLLOW.darkened(0.2)
					col = _lit(col, _round_light(u, r, ring.x - 0.8 * k, ring.y + 0.8 * k, true), 1.4)
				elif r > socket:
					col = LEATHER.darkened(0.3 * (mottle.at(x, y) - 0.5))
				else:
					# The socket: sunk, darker towards its rim, its far wall catching the light.
					col = HOLLOW.darkened(0.3 * (1.0 - smoothstep(0.0, 6.0 * k, socket - r)))
					col = col.lightened(0.12 * clampf(u.dot(Vector2(0.6, 0.8)), 0.0, 1.0) * (1.0 - smoothstep(0.0, 2.5 * k, socket - r)))
				for pc in pegs:
					col = _knuckle(col, p, pc, 1.9 * k, BRONZE, true, grain.at(x, y))
			var sa: float = 0.0
			if a < 1.0:
				var out_d: float = (p - c - Vector2(0.0, 2.5) * k).length() - outer
				sa = 0.6 * pow(clampf(1.0 - out_d / (6.0 * k), 0.0, 1.0), 2.0) if out_d > 0.0 else 0.6
			var total: float = a + sa * (1.0 - a)
			if total > 0.0:
				img.set_pixel(x, y, Color(col.r * a / total, col.g * a / total, col.b * a / total, total))
	return img

## The cabin's power round its medallion (HUD): the groove it runs in, outside the rim -- dark, sunk, its far wall
## catching the light -- what shows of the power used.
func _draw_power_track(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var k: float = float(_k)
	var c := Vector2(float(w), float(h)) * 0.5
	var ring: Vector2 = Vector2(spec.get("ring", Vector2(47.0, 51.5))) * float(k)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var off: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - c
			var r: float = off.length()
			var a: float = clampf(r - ring.x + 0.5, 0.0, 1.0) * clampf(ring.y - r + 0.5, 0.0, 1.0)
			if a <= 0.0:
				continue
			var u: Vector2 = off / maxf(r, 0.001)
			var col: Color = _lit(HOLLOW.darkened(0.1), _round_light(u, r, ring.x, ring.y, true), 1.3)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.85 * a))
	return img

## The light in the cabin's power groove: pigment like the health ring's, its own radii, to be tinted "power".
func _draw_power_fill(spec: Dictionary) -> Image:
	return _draw_ring_fill(spec)

## The ring of pigment that lies in a medallion's channel: pale, to be tinted the colour of what
## is left; rounded in section like a wet stroke.
func _draw_ring_fill(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var k: float = float(_k)
	var c := Vector2(float(w), float(h)) * 0.5
	var ring: Vector2 = Vector2(spec.get("ring", Vector2(31.0, 38.0))) * float(k)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var off: Vector2 = Vector2(float(x) + 0.5, float(y) + 0.5) - c
			var r: float = off.length()
			var a: float = clampf(r - ring.x + 0.5, 0.0, 1.0) * clampf(ring.y - r + 0.5, 0.0, 1.0)
			if a <= 0.0:
				continue
			var t: float = clampf((r - ring.x) / (ring.y - ring.x), 0.0, 1.0)
			var u: Vector2 = off / maxf(r, 0.001)
			var v: float = 0.82 + 0.16 * sin(PI * t) - 0.1 * u.y
			img.set_pixel(x, y, Color(v, v, v, a))
	return img

# ==============================================================================
# Brush strokes: toasts and a raid's warning
# ==============================================================================

func _draw_brush(spec: Dictionary) -> Image:
	return _brush(spec, INK, 81)

## A stroke laid with a broad brush -- what a toast's line is written on: its ends ragged where
## each bristle touched down and lifted (in the end pieces, drawn once), dry streaks along its
## length, drier towards the ends, and its long edges a little uneven (whole waves over the
## middle, so it tiles along).
func _brush(spec: Dictionary, ink: Color, seed: int) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var k: float = float(_k)
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var cw: float = float(w - 2 * m.x)
	var bristles := FastNoiseLite.new()
	bristles.seed = seed
	bristles.frequency = 0.9 / k
	var lifts := FastNoiseLite.new()
	lifts.seed = seed + 1
	lifts.frequency = 0.25 / k
	var waves: Array[Vector3] = []
	for n in [1, 2, 3, 5]:
		waves.append(Vector3(float(n), r.randf_range(0.3, 1.0), r.randf_range(0.0, TAU)))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var fy: float = float(y) + 0.5
		# This bristle's own touch-down and lift, somewhere in the end pieces, and how dry it ran.
		var start: float = (0.1 + 0.55 * (0.5 + 0.5 * lifts.get_noise_1d(fy * 3.0))) * float(m.x)
		var stop: float = (0.1 + 0.55 * (0.5 + 0.5 * lifts.get_noise_1d(fy * 3.0 + 500.0))) * float(m.x)
		var dry: float = 0.5 + 0.5 * bristles.get_noise_1d(fy * 2.0)
		for x in w:
			var fx: float = float(x) + 0.5
			var t: float = fposmod(fx - float(m.x), cw)
			var wander: float = 0.0
			for wv in waves:
				wander += wv.y * sin(TAU * wv.x * t / cw + wv.z)
			wander *= 0.3 * k
			var a: float = clampf(fy - (1.2 * k + wander), 0.0, 1.0) * clampf(float(h) - 1.2 * k + wander * 0.7 - fy, 0.0, 1.0)
			a *= smoothstep(0.0, 6.0 * k, fx - start) * smoothstep(0.0, 6.0 * k, float(w) - fx - stop)
			var near_end: float = 1.0 - smoothstep(0.0, float(m.x), minf(fx, float(w) - fx))
			a *= 1.0 - 0.45 * pow(dry, 3.0) * (0.35 + 0.65 * near_end)
			if a <= 0.0:
				continue
			var tone: float = 1.0 + 0.2 * (dry - 0.5)
			img.set_pixel(x, y, Color(ink.r * tone, ink.g * tone, ink.b * tone, a * ink.a))
	return img

# ==============================================================================
# A bar's trough
# ==============================================================================

## A bar's trough: a slot sunk in the leather, dark, its top in shadow and its bottom lip lit,
## capped at each end (the end pieces) with a knob of bone.
func _draw_trough(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var k: float = float(_k)
	var cap: float = float(spec.get("cap", 4)) * k
	var radius: float = float(h) * 0.5
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var l: Vector3 = LIGHT.normalized()
	for y in h:
		for x in w:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var axis := Vector2(clampf(p.x, radius, float(w) - radius), radius)
			var d: float = radius - p.distance_to(axis)
			var a: float = clampf(d + 0.5, 0.0, 1.0)
			if a <= 0.0:
				continue
			var t: float = p.y / float(h)
			var col: Color
			var from_end: float = minf(p.x, float(w) - p.x)
			if from_end < cap:
				# The cap: round across the bar and rounded at its end, lit from the top left.
				var n := Vector3((p - axis).x / radius, (p.y - radius) / radius, 0.0)
				n.z = sqrt(maxf(0.0, 1.0 - n.x * n.x - n.y * n.y))
				col = _lit(BRONZE, n.normalized().dot(l) - l.z, 1.1, true)
				col = col.darkened(0.45 * (1.0 - smoothstep(0.0, 0.9 * k, cap - from_end)))
			else:
				col = HOLLOW.darkened(0.35 * (1.0 - smoothstep(0.15, 0.5, t)))
				col = col.lightened(0.28 * smoothstep(0.78, 1.0, t))
			col = col.lerp(EDGE, 1.0 - smoothstep(0.0, 0.9 * k, d))
			img.set_pixel(x, y, Color(col, a))
	return img

# ==============================================================================
# The rule under a title, and its ornament
# ==============================================================================

## A rule cut into the leather: a line of bone, its lit edge over its shadow, even along its
## middle and fading out over its end pieces.
func _draw_rule(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var k: float = float(_k)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var mid_y: float = float(h) * 0.5
	for y in h:
		for x in w:
			var fx: float = float(x) + 0.5
			var fade: float = smoothstep(0.0, float(m.x), minf(fx, float(w) - fx))
			fade *= fade
			var dy: float = float(y) + 0.5 - mid_y
			var line: float = clampf(0.6 * k - absf(dy + 0.3 * k) + 0.5, 0.0, 1.0)
			var under: float = clampf(0.5 * k - absf(dy - 0.8 * k) + 0.5, 0.0, 1.0)
			if line > 0.0:
				img.set_pixel(x, y, Color(GILT.lightened(0.12 * (1.0 - absf(dy) / k)), line * fade * 0.85))
			elif under > 0.0:
				img.set_pixel(x, y, Color(EDGE, under * fade * 0.8))
	return img

## The flourish at a rule's middle: a tooth of bone set point down, cut in four facets that
## catch the light differently, between two small studs.
func _draw_ornament(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var k: float = float(_k)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(float(w) * 0.5, float(h) * 0.5)
	var half := Vector2(5.2, 3.6) * k
	var studs: Array[Vector2] = [c + Vector2(-8.5 * k, 0.0), c + Vector2(8.5 * k, 0.0)]
	var stud_r: float = 1.1 * k
	for y in h:
		for x in w:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var q: Vector2 = p - c
			# A rhombus: inside where |x|/hx + |y|/hy < 1; its distance in, roughly, in pixels.
			var inner: float = (1.0 - (absf(q.x) / half.x + absf(q.y) / half.y)) * minf(half.x, half.y) * 0.8
			var col := Color(0, 0, 0, 0)
			if inner > -1.0 * k:
				var facet := Vector3(signf(q.x) * 0.6, signf(q.y) * 0.5, 0.62).normalized()
				var l: Vector3 = LIGHT.normalized()
				var face: Color = _lit(GILT, facet.dot(l) - l.z, 1.1, true)
				var body: Color = EDGE.lerp(face, clampf(inner + 0.5, 0.0, 1.0))
				col = Color(body, clampf(inner + 1.0 * k + 0.5, 0.0, 1.0))
			for sc in studs:
				var sr: float = p.distance_to(sc)
				if sr < stud_r + 1.0 * k:
					var z: float = sqrt(maxf(0.0, stud_r * stud_r - sr * sr))
					var n := Vector3((p - sc).x, (p - sc).y, z).normalized()
					var l2: Vector3 = LIGHT.normalized()
					var face2: Color = _lit(GILT, n.dot(l2) - l2.z, 1.0, true)
					var body2: Color = EDGE.lerp(face2, clampf(stud_r + 0.5 - sr, 0.0, 1.0))
					col = Color(body2, clampf(stud_r + 1.0 * k + 0.5 - sr, 0.0, 1.0))
			if col.a > 0.0:
				img.set_pixel(x, y, col)
	return img

# ==============================================================================
# Hide: every card, toast and tooltip
# ==============================================================================

## A card, a tooltip: dark vellum in a thin bronze rim with a gilt pinstripe inside it and a
## bracket at each corner -- a smaller panel. It was a pale hide sewn round with a dashed row of
## stitches, and a dashed outline is the one thing every web page has (v0.6 round three: "要和
## 网页游戏区分开"). What a card holds still sits Config's "stitch" in from its edge.
func _draw_hide(spec: Dictionary) -> Image:
	return _framed(spec, {"fill": Color(0.115, 0.095, 0.078), "rim": 1.2, "rim_color": BRONZE, "metal": true,
		"glow": Color(GILT, 0.26), "edge": 0.9, "brackets": 5.0, "bracket_w": 1.0, "radius": 2.0, "vignette": 0.45,
		"falloff": 9.0, "top_light": 0.09, "seed": 37, "shadow": Vector4(0.0, 2.0, 5.0, 0.55)})

# ==============================================================================
# The groove: under a bar, a chosen tab, a portrait
# ==============================================================================

## A hollow cut in the stone: its floor below the rim, the wall under the light in shadow and
## the far one catching it, and a lit lip round the bottom of the cut.
func _draw_groove(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var k: int = _k
	var mid := Vector2i(w - 2 * m.x, h - 2 * m.y)
	var o := _outline(w, h, m, g[3], 3.0, 0.4, 0.4, 0, 51)
	var grit := _field(_noise(mid, 51, 0.5, 1), m)
	var mottle := _field(_noise(mid, 52, 0.05, 2), m)
	var paint := func(x: int, y: int, d: float, lit: float) -> Color:
		var v: float = 0.12 + 0.02 * (mottle.at(x, y) - 0.5) + 0.02 * (grit.at(x, y) - 0.5)
		var c := Color(v, v * 0.98, v * 0.95)
		# Darker into the corners of the floor, where the light does not reach.
		c = c.darkened(0.18 * (1.0 - smoothstep(0.0, 4.0 * k, d)))
		c = _shade(c, lit, 1.4)
		# The lip: the cut's own edge, catching the light along the bottom and right.
		var s: Vector2 = o.sides(x, y)
		if d < 1.0 * k and (float(y) > float(h) * 0.5 or float(x) > float(w) * 0.5) and minf(s.x, s.y) == d:
			c = c.lightened(0.35 * (1.0 - d / (1.0 * k)))
		return c
	return _compose(o, Vector4(0.0, 0.0, 1.0, 0.0), 2.5, -2.0, paint)

# ==============================================================================
# Pigment: a bar's fill
# ==============================================================================

## A stroke of pigment: streaked along its length, wet and lit along its top, its ends
## ragged where the stroke begins and lifts. Drawn pale: the bar's colour tints it.
func _draw_paint(spec: Dictionary) -> Image:
	return _pigment(spec, 0.0, 61)

## Pigment laid in diagonal stripes: work under way, told from health by its pattern.
func _draw_hatch(spec: Dictionary) -> Image:
	return _pigment(spec, 1.0, 62)

func _pigment(spec: Dictionary, stripes: float, seed: int) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var k: int = _k
	var o := _outline(w, h, m, g[3], 1.5, 0.3, 1.2, 0, seed)
	var cw: float = float(w - 2 * m.x)
	var streak := FastNoiseLite.new()
	streak.seed = seed
	streak.frequency = 0.35 / float(k)
	streak.fractal_octaves = 2
	var period: float = cw / round(cw / (10.0 * k))
	var paint := func(x: int, y: int, d: float, _lit: float) -> Color:
		var th: float = TAU * float(x - m.x) / cw
		var radius: float = cw / TAU / 12.0
		var s: float = streak.get_noise_3d(radius * cos(th), radius * sin(th), float(y))
		var v: float = 0.84 + 0.07 * s
		# Round like liquid in a tube (v0.6 round three, the D4 / Elden Ring bars): a thin bright
		# line where the light catches the top of it, the body under that, shaded towards the
		# bottom. The tint can only darken, so the body sits below white and the line is white.
		var t: float = (float(y) + 0.5) / float(h)
		var band: float = smoothstep(0.1, 0.2, t) * (1.0 - smoothstep(0.26, 0.4, t))
		v += 0.16 * band - 0.24 * smoothstep(0.55, 1.0, t)
		# Its leading edge -- inside the fill's right end piece, drawn wherever the bar stops, so
		# the middle still tiles -- is lit: how far it has come reads as a meniscus, not a cut.
		var lead: float = smoothstep(float(w - m.x), float(w - m.x) + 1.5 * k, float(x)) * (1.0 - smoothstep(float(w) - 1.5 * k, float(w), float(x)))
		v += 0.12 * lead * (1.0 - smoothstep(0.5, 1.0, t))
		if stripes > 0.0 and fposmod(float(x) - float(m.x) + float(y), period) < period * 0.5:
			v *= 0.7
		v = minf(v, 1.0)
		v *= 1.0 - 0.2 * (1.0 - smoothstep(0.0, 1.5 * k, d))
		return Color(v, v, v)
	return _compose(o, Vector4.ZERO, 1.0, 0.0, paint)
