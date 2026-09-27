extends SceneTree
## tools/build_ui_textures.gd -- the interface's materials, drawn by rule (v0.6 feedback: "我想要
## 的主题是那种远古时代质感的菜单界面，状态栏"): a slab of stone for every panel, a plank lashed
## with rawhide for every button, a stitched hide for every card, toast and tooltip, a groove cut
## in the stone under every bar and chosen tab, and a smear of pigment to fill a bar. The
## valley's own materials, so the interface reads as made of the same world as the game.
##
##   godot --headless --path . --script res://tools/build_ui_textures.gd [-- stone plank ...]
##
## What the game needs to know about a surface -- its size, where it is cut into nine, how far
## its shadow reaches -- is Config.THEME.surfaces, and is read from there. How it LOOKS (the
## noise, the colours, the bevel) is here, as a model's look is in tools/generate_props.py.
##
## UiTheme cuts each into nine (StyleBoxTexture) and tiles the middle and the edges to fit, so
## every surface is drawn to tile: its middle is seamless, and each edge -- its wander, its
## chips, its stitches -- repeats over exactly the length of the middle beside it, starting
## where the corner piece leaves off. One small image covers a panel of any size without
## stretching its grain.
##
## Each is drawn light and near its natural colour; the theme tints it (Config.THEME.colors),
## so one stone is a panel, a slate and a victory, and one hide is a card and a dark leather
## toast. And each is drawn at Config.THEME.surface_scale times its size and handed to the
## theme at its size: crisp on a 1440p screen, where the 1280x720 design is drawn at 2x.

const CONFIG := "res://scripts/autoload/Config.gd"
## Light falls from the top left and a little in front.
const LIGHT := Vector3(-0.42, -0.62, 0.66)

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
# Stone: every panel
# ==============================================================================

## A slab of stone: a chipped outline, its edge bevelled towards the light, grained and
## flecked, a few hairline cracks with a lit lip -- quiet in the middle, where text sits on it.
func _draw_stone(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var mid := Vector2i(w - 2 * m.x, h - 2 * m.y)
	var o := _outline(w, h, m, g[3], 3.0, 2.2, 2.2, 4, 11)
	var broad := _field(_noise(mid, 11, 0.006, 3), m)
	var mottle := _field(_noise(mid, 12, 0.03, 3), m)
	var grit := _field(_noise(mid, 13, 0.5, 1), m)
	var fleck := _field(_noise(mid, 14, 0.22, 1), m)
	var warmth := _field(_noise(mid, 15, 0.01, 2), m)
	var crack := _cracks(mid, m, 6, 0.55, 26.0, 16)
	var crack_mask := _field(_noise(mid, 17, 0.012, 2), m)
	var k: int = _k
	var paint := func(x: int, y: int, d: float, lit: float) -> Color:
		var v: float = 0.70 + 0.10 * (broad.at(x, y) - 0.5) + 0.09 * (mottle.at(x, y) - 0.5) + 0.06 * (grit.at(x, y) - 0.5)
		var f: float = fleck.at(x, y)
		if f > 0.78:
			v += 0.07 * smoothstep(0.78, 0.9, f)
		elif f < 0.2:
			v -= 0.08 * smoothstep(0.2, 0.08, f)
		var warm: float = 0.03 * (warmth.at(x, y) - 0.5)
		var c := Color(v * (1.0 + warm), v, v * (1.0 - warm))
		# A crack: a dark hairline, and just below and right of it the lip that catches the light.
		var mask: float = smoothstep(0.52, 0.64, crack_mask.at(x, y))
		var cr: float = crack.at(x, y) * mask
		if cr > 0.0:
			c = c.darkened(0.30 * cr)
		else:
			var lip: float = crack.at(x - k, y - k) * smoothstep(0.52, 0.64, crack_mask.at(x - k, y - k))
			c = c.lightened(0.06 * lip)
		# The chipped face at the very edge is darker than the slab's top.
		c = c.darkened(0.30 * (1.0 - smoothstep(0.0, 1.6 * k, d)))
		return _shade(c, lit, 1.15)
	return _compose(o, Vector4(0.0, 2.0, 6.0, 0.55), 3.5, 2.6, paint)

# ==============================================================================
# Wood: every button
# ==============================================================================

## A split plank: its grain running its length in long wavy lines, its cut ends darker, its
## edges rounded towards the light, and a band of rawhide wrapped round it near each end --
## inside the end margins, so every button, however long, is lashed at both ends and nowhere
## else.
func _draw_plank(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var pad: float = g[3]
	var k: int = _k
	var o := _outline(w, h, m, pad, 4.0, 1.0, 2.2, 0, 23)
	# The lashing: a band where Config says (a button's word starts past it), standing a little
	# proud of the plank's edges.
	var lash: Vector2 = spec.get("lash", Vector2(16.0, 4.5))
	var band_at: float = lash.x * k
	var band_half: float = lash.y * k
	var bands: Array[float] = [pad + band_at, float(w) - pad - band_at]
	for i in o.top.size():
		var x: float = float(i - Outline.BORDER) + 0.5
		for c in bands:
			var off: float = absf(x - c)
			if off < band_half + 1.0 * k:
				var proud: float = 1.0 * k * (1.0 - smoothstep(band_half - 0.5 * k, band_half + 1.0 * k, off))
				o.top[i] -= proud
				o.bottom[i] -= proud
	# Grain: noise read round a cylinder the middle's length about, so it tiles along the plank,
	# and stretched along it.
	var cw: float = float(w - 2 * m.x)
	var streaks := FastNoiseLite.new()
	streaks.seed = 23
	streaks.frequency = 0.08 / float(k)
	streaks.fractal_octaves = 3
	var bends := FastNoiseLite.new()
	bends.seed = 24
	bends.frequency = 0.03 / float(k)
	bends.fractal_octaves = 2
	var grain_at := func(noise: FastNoiseLite, x: int, y: int, stretch: float) -> float:
		var th: float = TAU * float(x - m.x) / cw
		var radius: float = cw / TAU / stretch
		return noise.get_noise_3d(radius * cos(th), radius * sin(th), float(y))
	var line_gap: float = 3.2 * k
	var fine := _field(_noise(Vector2i(int(cw), h), 25, 0.6, 1), Vector2i(m.x, 0))
	var wood := Color(0.86, 0.70, 0.52)
	var cord := Color(0.93, 0.84, 0.64)
	var paint := func(x: int, y: int, d: float, lit: float) -> Color:
		var s: float = grain_at.call(streaks, x, y, 10.0)
		var b: float = grain_at.call(bends, x, y, 4.0)
		var c: Color = wood * (0.93 + 0.10 * s)
		# The grain's lines: thin and dark where the growth rings cut the face.
		var ring: float = sin(TAU * (float(y) / line_gap + 2.2 * b))
		c = c.darkened(0.16 * smoothstep(0.55, 0.95, ring))
		c = c.lightened(0.03 * (fine.at(x, y) - 0.5))
		# The cut ends: end grain, darker.
		var ex: float = o.sides(x, y).x
		c = c.darkened(0.18 * (1.0 - smoothstep(0.0, 5.0 * k, ex)))
		# The lashing: turns of rawhide round the plank, each lit along its crown.
		for bc in bands:
			var off: float = absf(float(x) + 0.5 - bc)
			if off < band_half:
				var turn: float = fposmod(float(x) - bc + (float(y) - float(h) * 0.5) * 0.45, 2.3 * k) / (2.3 * k)
				var crown: float = sin(PI * turn)
				var edge: float = smoothstep(band_half - 1.0 * k, band_half, off)
				c = cord * (0.52 + 0.48 * crown)
				c = c.darkened(0.45 * edge)
				return _shade(c, lit, 0.8)
		c = c.darkened(0.35 * (1.0 - smoothstep(0.0, 1.4 * k, d)))
		return _shade(c, lit, 1.2)
	return _compose(o, Vector4(0.0, 1.5, 3.5, 0.5), 3.5, 2.4, paint)

# ==============================================================================
# Hide: every card, toast and tooltip
# ==============================================================================

## A scraped hide: pale, blotched and pored like skin, its edges darker where they were
## handled, and a row of stitches a little in from the edge -- run along each side, spaced to
## repeat over exactly the middle's length.
func _draw_hide(spec: Dictionary) -> Image:
	var g: Array = _geo(spec)
	var w: int = g[0]
	var h: int = g[1]
	var m: Vector2i = g[2]
	var pad: float = g[3]
	var k: int = _k
	var mid := Vector2i(w - 2 * m.x, h - 2 * m.y)
	var o := _outline(w, h, m, pad, 7.0, 2.4, 2.4, 2, 37)
	var blotch := _field(_noise(mid, 37, 0.012, 3), m)
	var pore := _field(_noise(mid, 38, 0.7, 1), m)
	var fold := _cracks(mid, m, 5, 1.6, 40.0, 39)
	var fold_mask := _field(_noise(mid, 40, 0.01, 2), m)
	var pale := Color(0.87, 0.78, 0.60)
	var thread := Color(0.30, 0.20, 0.12)
	# The stitches: as far in as Config says (what a card holds sits inside them), each this
	# long, spaced so a whole number fit the middle.
	var inset: float = float(spec.get("stitch", 7)) * k
	var period_x: float = float(mid.x) / round(float(mid.x) / (8.0 * k))
	var period_y: float = float(mid.y) / round(float(mid.y) / (8.0 * k))
	var dash: float = 4.6 * k
	var half_thick: float = 0.75 * k
	var paint := func(x: int, y: int, d: float, lit: float) -> Color:
		var v: float = blotch.at(x, y)
		var c: Color = pale.lerp(Color(0.74, 0.60, 0.42), 0.55 * (1.0 - v))
		c = c.darkened(0.05 * pore.at(x, y))
		var fl: float = fold.at(x, y) * smoothstep(0.5, 0.65, fold_mask.at(x, y))
		c = c.darkened(0.07 * fl)
		# Worked darker towards the edge.
		c = c.darkened(0.26 * (1.0 - smoothstep(0.0, 6.0 * k, d)))
		# Stitches along the straight of each side (none round the corners).
		var s: Vector2 = o.sides(x, y)
		var across: float = absf(d - inset)
		if across < half_thick + 1.0:
			var along: float = -1.0
			if s.y < s.x and s.x > inset + 3.0 * k:
				along = fposmod(float(x) + 0.5 - float(m.x), period_x)
			elif s.x <= s.y and s.y > inset + 3.0 * k:
				along = fposmod(float(y) + 0.5 - float(m.y), period_y)
			if along >= 0.0:
				var on: float = clampf(half_thick - across + 0.5, 0.0, 1.0) * clampf(minf(along, dash - along) + 0.5, 0.0, 1.0)
				if on > 0.0:
					var crown: float = 1.0 - across / (half_thick + 1.0)
					c = c.lerp(thread.lightened(0.25 * crown), on)
				# The holes the thread goes through, at each end of a stitch.
				var hole: float = minf(Vector2(along, across).length(), Vector2(along - dash, across).length())
				c = c.darkened(0.45 * (1.0 - smoothstep(0.5 * k, 1.1 * k, hole)))
		c = c.darkened(0.3 * (1.0 - smoothstep(0.0, 1.2 * k, d)))
		return _shade(c, lit, 0.7)
	return _compose(o, Vector4(0.0, 2.0, 5.0, 0.5), 3.0, 1.4, paint)

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
		var v: float = 0.62 + 0.05 * (mottle.at(x, y) - 0.5) + 0.05 * (grit.at(x, y) - 0.5)
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
		var v: float = 0.9 + 0.08 * s
		# Round like a wet stroke: lit along the top, shaded along the bottom.
		var t: float = (float(y) + 0.5) / float(h)
		v += 0.07 * (1.0 - smoothstep(0.0, 0.3, t)) - 0.16 * smoothstep(0.6, 1.0, t)
		if stripes > 0.0 and fposmod(float(x) - float(m.x) + float(y), period) < period * 0.5:
			v *= 0.7
		v *= 1.0 - 0.2 * (1.0 - smoothstep(0.0, 1.5 * k, d))
		return Color(v, v, v)
	return _compose(o, Vector4.ZERO, 1.0, 0.0, paint)
