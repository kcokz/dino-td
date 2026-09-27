# res://scripts/ui/UiTheme.gd
class_name UiTheme
extends RefCounted

## The one Theme the whole interface is drawn with (UI-POLISH T1), and the fonts and icons
## that go with it -- built from Config.THEME's design tokens, so every colour, size, gap
## and corner has one home, and a change there restyles everything.
##
## Before this, every panel styled itself: forty-odd add_theme_*_override calls and a
## StyleBoxFlat.new() in each file, each a slightly different grey with a slightly
## different corner. That, more than any one colour, is what read as a student project.
##
## Now the HUD's root carries this theme and everything under it inherits. A control asks
## for a KIND of thing -- a type variation: "HudLabel" for text standing on the world,
## "AccentButton" for the one thing to press, "HealthBar" -- and the theme answers.
##
## And it answers in the valley's own materials (v0.6: "远古时代质感的菜单界面，状态栏" -- it
## read as a web page): a panel is a slab of stone, a button a plank lashed with rawhide, a
## card a stitched hide, a bar a groove with pigment in it. Each is an image cut into nine
## (Config.THEME.surfaces, drawn by tools/build_ui_textures.gd) and tinted where it is used
## (Config.THEME.tints), so the whole interface is a handful of materials, not a box per panel.

static var _theme: Theme = null
static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}
static var _surfaces: Dictionary = {}

## The theme, built once and shared.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme

# ==============================================================================
# Tokens
# ==============================================================================

static func tokens() -> Dictionary:
	var cfg = _config()
	return cfg.THEME if (cfg and "THEME" in cfg) else {}

static func color(key: String) -> Color:
	return tokens().get("colors", {}).get(key, Color.MAGENTA)

## How a material is tinted where it is used (Config.THEME.tints).
static func tint(key: String) -> Color:
	return tokens().get("tints", {}).get(key, Color.WHITE)

static func font_size(key: String) -> int:
	return int(tokens().get("font_sizes", {}).get(key, 16))

static func space(key: String) -> int:
	return int(tokens().get("spacing", {}).get(key, 8))

static func radius(key: String) -> int:
	return int(tokens().get("radius", {}).get(key, 6))

static func icon_size(key: String) -> int:
	return int(tokens().get("icon_sizes", {}).get(key, 20))

static func height(key: String) -> int:
	return int(tokens().get("control_heights", {}).get(key, 40))

static func width(key: String) -> int:
	return int(tokens().get("widths", {}).get(key, 40))

static func thickness(key: String) -> int:
	return int(tokens().get("thickness", {}).get(key, 8))

## A token that is one number: a duration, an alpha, a scale.
static func number(key: String) -> float:
	return float(tokens().get(key, 0.0))

static func toast_seconds(key: String) -> float:
	return float(tokens().get("toast_seconds", {}).get(key, 3.0))

## How far in from a hide's edge what it holds begins -- a card's name, its price row, a
## toast's line: inside its stitches, and clear of them.
static func card_inset() -> Vector2i:
	var stitch: int = int(tokens().get("surfaces", {}).get("hide", {}).get("stitch", 0))
	return Vector2i(stitch + space("s"), stitch + space("xs"))

## How far in from a plank's end a button's word begins: past the rawhide lashed round it.
static func plank_clear() -> int:
	var lash: Vector2 = tokens().get("surfaces", {}).get("plank", {}).get("lash", Vector2.ZERO)
	return int(ceil(lash.x + lash.y)) + space("xs")

## Green, amber or red for a share of hit points left -- one reading of the thresholds for
## every bar in the game, so the cabin and a stake mean the same thing by amber.
static func health_color(ratio: float) -> Color:
	if ratio < float(tokens().get("hp_low_ratio", 0.3)):
		return color("danger")
	if ratio < float(tokens().get("hp_warn_ratio", 0.6)):
		return color("warning")
	return color("success")

## The bar kind for a share of hit points left: the same three steps as health_color.
static func health_bar(ratio: float) -> StringName:
	if ratio < float(tokens().get("hp_low_ratio", 0.3)):
		return &"DangerBar"
	if ratio < float(tokens().get("hp_warn_ratio", 0.6)):
		return &"WarnBar"
	return &"HealthBar"

# ==============================================================================
# Fonts and icons
# ==============================================================================

## A weight of the interface face -- "regular", "medium", "semibold", "bold", "black" --
## with Chinese falling back to the player's own system UI face at the same weight.
## `tabular` gives every digit one width, so a count going 9 -> 10 -> 11 does not shuffle
## everything beside it sideways (UI-POLISH T7). `spacing` sets the letters that many pixels
## further apart: a title's.
static func font(weight: String = "regular", tabular: bool = false, spacing: int = 0) -> Font:
	var key: String = "%s/%s/%d" % [weight, tabular, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var wght: int = int(tokens().get("weights", {}).get(weight, 400))
	var f := FontVariation.new()
	var base: Font = _base_font()
	f.base_font = base
	if base is FontFile:
		f.variation_opentype = {"wght": wght}
	if tabular:
		f.opentype_features = {"tnum": 1}
	if spacing != 0:
		f.spacing_glyph = spacing
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray(tokens().get("fallback_fonts", []))
	cjk.font_weight = wght
	f.fallbacks = [cjk]
	_fonts[key] = f
	return f

static func _base_font() -> Font:
	if _fonts.has("_base"):
		return _fonts["_base"]
	var path: String = String(tokens().get("font", ""))
	var base: Font = load(path) as Font if (path != "" and ResourceLoader.exists(path)) else ThemeDB.fallback_font
	_fonts["_base"] = base
	return base

## An icon by name (Config.ICON_DIR/<name>.svg), or null when there is none. They are
## DPITextures, drawn from the vector at whatever scale the screen needs.
static func icon(name: String) -> Texture2D:
	if name == "":
		return null
	if _icons.has(name):
		return _icons[name]
	var cfg = _config()
	var dir: String = String(cfg.ICON_DIR) if (cfg and "ICON_DIR" in cfg) else "res://assets/icons/"
	var path: String = dir + name + ".svg"
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icons[name] = tex
	return tex

## What a resource node is drawn as in the panel: its row says (a tree is not "wood").
static func node_icon(res_type: String) -> Texture2D:
	var cfg = _config()
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(res_type):
		return icon(String(cfg.RESOURCE_NODES[res_type].get("icon", res_type)))
	return icon(res_type)

## The frosted backdrop for a full-screen menu: the world behind it blurred and tinted to
## the interface's dark (assets/shaders/ui_frost.gdshader). `tint_alpha` is how far.
static func frost_material(tint_alpha: float = -1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ui_frost.gdshader")
	var scrim: Color = color("scrim")
	mat.set_shader_parameter("blur_lod", float(tokens().get("frost_blur", 3.0)))
	mat.set_shader_parameter("tint", Color(scrim.r, scrim.g, scrim.b, scrim.a if tint_alpha < 0.0 else tint_alpha))
	mat.set_shader_parameter("vignette", float(tokens().get("frost_vignette", 0.35)))
	return mat

# ==============================================================================
# Materials
# ==============================================================================

## A material (Config.THEME.surfaces) cut into nine and tiled to fit, tinted `tinted` -- a
## key of Config.THEME.tints, or a colour -- with `margin_h`, `margin_v` of room inside it for
## what it holds. Its shadow reaches past the rect it is drawn behind ("pad"), so the slab's
## own edge is the control's edge. Until its image has been imported, a flat box stands in.
static func surface(name: String, tinted: Variant, margin_h: int, margin_v: int) -> StyleBox:
	var spec: Dictionary = tokens().get("surfaces", {}).get(name, {})
	var col: Color = tinted if tinted is Color else tint(String(tinted))
	var tex: Texture2D = surface_texture(name)
	if tex == null:
		return _box(color("panel"), color("panel_border"), int(tokens().get("border", 1)), radius("s"), margin_h, margin_v)
	var b := StyleBoxTexture.new()
	b.texture = tex
	var m: Vector2i = spec.get("margin", Vector2i.ZERO)
	b.texture_margin_left = m.x
	b.texture_margin_right = m.x
	b.texture_margin_top = m.y
	b.texture_margin_bottom = m.y
	var pad: float = float(spec.get("pad", 0))
	b.expand_margin_left = pad
	b.expand_margin_right = pad
	b.expand_margin_top = pad
	b.expand_margin_bottom = pad
	# Tiled, each run fitted to a whole number of repeats, so a side's wander and stitches
	# meet the corner piece where they left it. A plank's grain is stretched top to bottom.
	b.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	b.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT if bool(spec.get("tile_v", true)) \
		else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	b.modulate_color = col
	b.content_margin_left = margin_h
	b.content_margin_right = margin_h
	b.content_margin_top = margin_v
	b.content_margin_bottom = margin_v
	return b

## A material's texture, at its design size: drawn at Config.THEME.surface_scale times that,
## so it is sharp where the screen draws the interface bigger than 1280x720. Null until the
## image has been imported.
static func surface_texture(name: String) -> Texture2D:
	if _surfaces.has(name):
		return _surfaces[name]
	var spec: Dictionary = tokens().get("surfaces", {}).get(name, {})
	var path: String = String(spec.get("image", ""))
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		var img: Image = load(path) as Image
		if img != null and not img.is_empty():
			var sized := ImageTexture.create_from_image(img)
			sized.set_size_override(Vector2i(spec.get("size", img.get_size())))
			tex = sized
	_surfaces[name] = tex
	return tex

# ==============================================================================
# The theme
# ==============================================================================

static func build() -> Theme:
	var t := Theme.new()
	var r_s: int = radius("s")
	var bw: int = int(tokens().get("border", 1))
	var clear := Color(0, 0, 0, 0)
	var inset: Vector2i = card_inset()

	t.default_font = font("regular")
	t.default_font_size = font_size("body")

	# --- Text -------------------------------------------------------------------
	t.set_color("font_color", "Label", color("text"))
	t.set_color("font_outline_color", "Label", color("bg"))
	t.set_constant("outline_size", "Label", 0)
	# Text standing on the world rather than on a panel needs an edge, or it vanishes on
	# the pale bits of the valley floor.
	_label(t, "HudLabel", "semibold", "label", color("text"), 6)
	_label(t, "MutedLabel", "regular", "small", color("text_muted"))
	_label(t, "CaptionLabel", "medium", "caption", color("text_faint"))
	_label(t, "HeadingLabel", "semibold", "heading", color("text"))
	_title(t, "TitleLabel", "black", "title", "title")
	_title(t, "DisplayLabel", "black", "display", "display", false, 8)
	_title(t, "StatLabel", "black", "title", "", true)
	_label(t, "NumberLabel", "semibold", "label", color("text"), 0, true)
	_label(t, "SmallNumberLabel", "semibold", "small", color("text"), 0, true)
	_label(t, "AccentLabel", "bold", "small", color("accent"))
	_label(t, "TechLabel", "semibold", "small", color("tech"))
	_label(t, "LeadLabel", "regular", "body", color("text_muted"))
	_label(t, "ShortNumberLabel", "semibold", "small", color("danger_text"), 0, true)
	# The same figures on a pale hide -- a card's price and time -- in ink.
	_label(t, "CardNumberLabel", "semibold", "small", color("ink"), 0, true)
	_label(t, "CardShortLabel", "bold", "small", color("ink_short"), 0, true)
	_label(t, "CardCaptionLabel", "medium", "caption", color("ink_faint"))

	# --- Panels: stone, and a hollow cut in it ----------------------------------------
	var stone := surface("stone", "stone", space("l"), space("m"))
	t.set_stylebox("panel", "PanelContainer", stone)
	t.set_stylebox("panel", "Panel", stone)
	_panel(t, "HudPanel", stone)
	# The top row's slabs: slim, they sit over the world.
	_panel(t, "PillPanel", surface("stone", "stone", space("m") + space("xs"), space("xs") + space("hair")))
	_panel(t, "CardPanel", surface("hide", "hide", inset.x, inset.y))
	# Round a portrait or a bench's icon: a hollow in the stone it sits in.
	_panel(t, "InsetPanel", surface("groove", "groove", space("s"), space("xs")))
	_panel(t, "InsetTechPanel", surface("groove", "groove_tech", space("s"), space("xs")))
	# A toast is dark leather, and quiet: news, not an alarm. A raid is the same hide bloodied.
	_panel(t, "ToastPanel", surface("hide", "leather", inset.x + space("xs"), inset.y))
	_panel(t, "BannerPanel", surface("hide", "blood", space("xl"), inset.y))
	_panel(t, "TechPanel", surface("stone", "slate", space("l"), space("m")))
	_panel(t, "ModalPanel", surface("stone", "stone", space("xl"), space("xl")))
	_panel(t, "SolidPanel", surface("stone", "stone", space("l"), space("m")))
	# The verdict: the ship's slate for a jump home, stone gone red for a fall -- and its icon
	# and its word differ too, so it is never told by colour alone.
	_panel(t, "VictoryPanel", surface("stone", "won", space("xl"), space("xl")))
	_panel(t, "DefeatPanel", surface("stone", "lost", space("xl"), space("xl")))
	# The beacon's stages, one pip each: lit when it stands repaired.
	for pair in [["PipOn", color("tech")], ["PipOff", Color(color("text_faint"), 0.45)]]:
		t.set_type_variation(pair[0], "Panel")
		t.set_stylebox("panel", pair[0], _box(pair[1], clear, 0, 3, 0, 0))
	# Paused with the menu shut: a frame round the whole screen.
	var frame := _box(clear, Color(color("accent"), 0.55), 4, 0, 0, 0)
	frame.draw_center = false
	t.set_type_variation("ScreenFrame", "Panel")
	t.set_stylebox("panel", "ScreenFrame", frame)

	# --- Buttons: planks, lashed at each end --------------------------------------------
	# A button's word starts past the lashing; pressed, it sinks a pixel.
	var lash: int = plank_clear()
	var v: int = space("s")
	_buttons(t, "Button",
		surface("plank", "plank", lash, v), surface("plank", "plank_hover", lash, v),
		_sunk(surface("plank", "plank_down", lash, v)), surface("plank", "plank_off", lash, v),
		color("text"), color("text"), color("accent"), color("text_faint"))
	t.set_font("font", "Button", font("semibold"))
	t.set_font_size("font_size", "Button", font_size("label"))
	t.set_constant("h_separation", "Button", space("s"))
	t.set_constant("icon_max_width", "Button", icon_size("m"))
	var focus := _box(clear, Color(color("accent"), 0.7), bw, r_s, 0, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(float(space("hair")))
	t.set_stylebox("focus", "Button", focus)

	# The one thing to press: resume, restart, launch -- a plank painted ochre.
	t.set_type_variation("AccentButton", "Button")
	_buttons(t, "AccentButton",
		surface("plank", "ochre", lash, v), surface("plank", "ochre_hover", lash, v),
		_sunk(surface("plank", "ochre_down", lash, v)), surface("plank", "ochre_off", lash, v),
		color("accent_text"), color("accent_text"), color("accent_text"), Color(color("accent_text"), 0.6))
	t.set_font("font", "AccentButton", font("bold"))

	# Something that cannot be undone: red words on a plain plank, reddening under the
	# cursor -- not a red slab.
	t.set_type_variation("DangerButton", "Button")
	_buttons(t, "DangerButton",
		surface("plank", "plank", lash, v), surface("plank", "rust", lash, v),
		_sunk(surface("plank", "rust_down", lash, v)), surface("plank", "plank_off", lash, v),
		color("danger_text"), color("text"), color("text"), color("text_faint"))

	# Chrome on the HUD itself -- pause, menu -- is cut into the stone only under the cursor.
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = space("s")
	bare.content_margin_right = space("s")
	bare.content_margin_top = space("xs")
	bare.content_margin_bottom = space("xs")
	t.set_type_variation("GhostButton", "Button")
	_buttons(t, "GhostButton",
		bare, surface("groove", "groove_faint", space("s"), space("xs")),
		_sunk(surface("groove", "groove", space("s"), space("xs"))), bare,
		color("text"), color("text"), color("accent"), color("text_faint"))

	# One of a set, where the chosen one stays cut in and lit: the game speed, the benches.
	t.set_type_variation("SegmentButton", "Button")
	_buttons(t, "SegmentButton",
		bare, surface("groove", "groove_faint", space("s"), space("xs")),
		surface("groove", "groove", space("s"), space("xs")), bare,
		color("text_muted"), color("text"), color("accent"), color("text_faint"))
	t.set_color("font_hover_pressed_color", "SegmentButton", color("accent"))
	t.set_font("font", "SegmentButton", font("bold", true))

	# A command card entry: a hide tag, its name up top and its price along the bottom
	# (the extra bottom margin is where the price row sits), in ink.
	t.set_type_variation("CardButton", "Button")
	var card_bottom: int = inset.y + font_size("small") + space("xs") + space("hair")
	var cards: Array[StyleBox] = []
	for key in ["hide", "hide_hover", "hide_down", "hide_off"]:
		var b: StyleBox = surface("hide", key, inset.x, inset.y)
		b.content_margin_bottom = card_bottom
		cards.append(b)
	_buttons(t, "CardButton", cards[0], cards[1], _sunk(cards[2]), cards[3],
		color("ink"), color("ink"), color("ink_accent"), color("ink_muted"))
	# A tag is narrow: its name is set at the body size, where a command's is a label.
	t.set_font_size("font_size", "CardButton", font_size("body"))
	# Its icon is the thing itself, in its own colours: not inked.
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		t.set_color(c, "CardButton", Color.WHITE)
	t.set_color("icon_disabled_color", "CardButton", Color(1, 1, 1, 0.55))

	# --- Dropdowns --------------------------------------------------------------
	for state in ["normal", "hover", "pressed", "disabled"]:
		var b: StyleBox = t.get_stylebox(state, "Button")
		t.set_stylebox(state, "OptionButton", b)
		t.set_stylebox(state + "_mirrored", "OptionButton", b)
	t.set_stylebox("focus", "OptionButton", focus)
	# Its arrow sits inside the lashing, like its word.
	t.set_constant("arrow_margin", "OptionButton", lash)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", t.get_color(c, "Button"))
	t.set_font("font", "OptionButton", font("medium"))
	t.set_font_size("font_size", "OptionButton", font_size("body"))
	# A dropdown's list is a slab too; its entries sit clear of its chipped edge.
	t.set_stylebox("panel", "PopupMenu", surface("stone", "stone", space("s"), space("s")))
	t.set_stylebox("hover", "PopupMenu", surface("groove", "groove", space("s"), space("xs")))
	t.set_color("font_color", "PopupMenu", color("text"))
	t.set_color("font_hover_color", "PopupMenu", color("accent"))
	t.set_font("font", "PopupMenu", font("medium"))
	t.set_font_size("font_size", "PopupMenu", font_size("body"))
	t.set_constant("v_separation", "PopupMenu", space("s"))

	# --- Bars: a groove, and pigment in it -----------------------------------------
	var trough := surface("groove", "groove", 0, 0)
	t.set_stylebox("background", "ProgressBar", trough)
	t.set_stylebox("fill", "ProgressBar", _pigment("paint", color("success")))
	t.set_font("font", "ProgressBar", font("semibold", true))
	t.set_font_size("font_size", "ProgressBar", font_size("caption"))
	t.set_color("font_color", "ProgressBar", color("text"))
	for pair in [["HealthBar", color("success")], ["WarnBar", color("warning")], ["DangerBar", color("danger")],
			["BeaconBar", color("tech")]]:
		t.set_type_variation(pair[0], "ProgressBar")
		t.set_stylebox("background", pair[0], trough)
		t.set_stylebox("fill", pair[0], _pigment("paint", pair[1]))
	# Work in progress is hatched: told from health by its pattern, not only its colour.
	t.set_type_variation("BuildBar", "ProgressBar")
	t.set_stylebox("background", "BuildBar", trough)
	t.set_stylebox("fill", "BuildBar", _pigment("hatch", color("warning")))

	# --- Lines and tooltips ------------------------------------------------------
	# A line cut in the stone: its shadowed side, then its lit lip.
	var line := StyleBoxFlat.new()
	line.bg_color = Color(color("bg"), 0.85)
	line.border_color = Color(color("text"), 0.14)
	line.border_width_bottom = bw
	line.content_margin_top = bw
	line.content_margin_bottom = bw
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", space("s"))
	var vline := StyleBoxFlat.new()
	vline.bg_color = Color(color("bg"), 0.85)
	vline.border_color = Color(color("text"), 0.14)
	vline.border_width_right = bw
	vline.content_margin_left = bw
	vline.content_margin_right = bw
	t.set_stylebox("separator", "VSeparator", vline)
	t.set_constant("separation", "VSeparator", space("m"))
	t.set_stylebox("panel", "TooltipPanel", surface("hide", "hide", inset.x, inset.y))
	t.set_color("font_color", "TooltipLabel", color("ink"))
	t.set_font("font", "TooltipLabel", font("regular"))
	t.set_font_size("font_size", "TooltipLabel", font_size("small"))

	# --- Containers ---------------------------------------------------------------
	t.set_constant("separation", "HBoxContainer", space("s"))
	t.set_constant("separation", "VBoxContainer", space("s"))
	t.set_constant("h_separation", "GridContainer", space("s"))
	t.set_constant("v_separation", "GridContainer", space("s"))
	return t

# ==============================================================================
# Builders
# ==============================================================================

static func _box(bg: Color, border: Color, border_w: int, corner: int, margin_h: int, margin_v: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_w)
	b.set_corner_radius_all(corner)
	b.content_margin_left = margin_h
	b.content_margin_right = margin_h
	b.content_margin_top = margin_v
	b.content_margin_bottom = margin_v
	b.corner_detail = 8
	b.anti_aliasing = true
	return b

## The same box pressed in: what it holds sits a pixel lower.
static func _sunk(box: StyleBox) -> StyleBox:
	box.content_margin_top += 1
	box.content_margin_bottom -= 1
	return box

## A bar's fill: pigment of `col`, sitting inside the groove's walls (Config.THEME.fill_inset)
## rather than over them.
static func _pigment(name: String, col: Color) -> StyleBox:
	var b: StyleBox = surface(name, col, 0, 0)
	var sink: float = float(tokens().get("fill_inset", 0))
	if b is StyleBoxTexture:
		(b as StyleBoxTexture).expand_margin_top = -sink
		(b as StyleBoxTexture).expand_margin_bottom = -sink
	return b

static func _label(t: Theme, name: String, weight: String, size_key: String, col: Color, outline: int = 0, tabular: bool = false) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font(weight, tabular))
	t.set_font_size("font_size", name, font_size(size_key))
	t.set_color("font_color", name, col)
	if outline > 0:
		t.set_constant("outline_size", name, outline)
		t.set_color("font_outline_color", name, Color(color("bg"), 0.85))

## A title: set wide (Config.THEME.title_spacing[`spacing_key`]) and standing proud of the
## stone on a shadow (title_shadow).
static func _title(t: Theme, name: String, weight: String, size_key: String, spacing_key: String, tabular: bool = false, outline: int = 0) -> void:
	var spacing: int = int(tokens().get("title_spacing", {}).get(spacing_key, 0))
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font(weight, tabular, spacing))
	t.set_font_size("font_size", name, font_size(size_key))
	t.set_color("font_color", name, color("text"))
	var drop: Vector2i = tokens().get("title_shadow", Vector2i.ZERO)
	t.set_color("font_shadow_color", name, color("shadow"))
	t.set_constant("shadow_offset_x", name, drop.x)
	t.set_constant("shadow_offset_y", name, drop.y)
	if outline > 0:
		t.set_constant("outline_size", name, outline)
		t.set_color("font_outline_color", name, Color(color("bg"), 0.85))

static func _panel(t: Theme, name: String, box: StyleBox) -> void:
	t.set_type_variation(name, "PanelContainer")
	t.set_stylebox("panel", name, box)

static func _buttons(t: Theme, name: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox,
		text: Color, hover_text: Color, pressed_text: Color, disabled_text: Color) -> void:
	t.set_stylebox("normal", name, normal)
	t.set_stylebox("hover", name, hover)
	t.set_stylebox("pressed", name, pressed)
	t.set_stylebox("hover_pressed", name, pressed)
	t.set_stylebox("disabled", name, disabled)
	t.set_color("font_color", name, text)
	t.set_color("font_hover_color", name, hover_text)
	t.set_color("font_pressed_color", name, pressed_text)
	t.set_color("font_hover_pressed_color", name, pressed_text)
	t.set_color("font_focus_color", name, text)
	t.set_color("font_disabled_color", name, disabled_text)
	t.set_color("icon_normal_color", name, text)
	t.set_color("icon_hover_color", name, hover_text)
	t.set_color("icon_pressed_color", name, pressed_text)
	t.set_color("icon_hover_pressed_color", name, pressed_text)
	t.set_color("icon_focus_color", name, text)
	t.set_color("icon_disabled_color", name, disabled_text)

static func _config() -> Node:
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
