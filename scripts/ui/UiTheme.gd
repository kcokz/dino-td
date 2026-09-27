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

static var _theme: Theme = null
static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}

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
## everything beside it sideways (UI-POLISH T7).
static func font(weight: String = "regular", tabular: bool = false) -> Font:
	var key: String = "%s/%s" % [weight, tabular]
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
# The theme
# ==============================================================================

static func build() -> Theme:
	var t := Theme.new()
	var r_s: int = radius("s")
	var r_m: int = radius("m")
	var r_l: int = radius("l")
	var bw: int = int(tokens().get("border", 1))
	var clear := Color(0, 0, 0, 0)

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
	_label(t, "TitleLabel", "black", "title", color("text"))
	_label(t, "DisplayLabel", "black", "display", color("text"), 8)
	_label(t, "NumberLabel", "semibold", "label", color("text"), 0, true)
	_label(t, "SmallNumberLabel", "semibold", "small", color("text"), 0, true)
	_label(t, "AccentLabel", "bold", "small", color("accent"))
	_label(t, "TechLabel", "semibold", "small", color("tech"))
	_label(t, "LeadLabel", "regular", "body", color("text_muted"))
	_label(t, "ShortNumberLabel", "semibold", "small", color("danger_text"), 0, true)
	_label(t, "StatLabel", "black", "title", color("text"), 0, true)

	# --- Panels -----------------------------------------------------------------
	var panel := _box(color("panel"), color("panel_border"), bw, r_l, space("l"), space("m"), true)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	_panel(t, "HudPanel", panel)
	_panel(t, "PillPanel", _box(color("panel"), color("panel_border"), bw, radius("pill"), space("m"), space("xs"), true))
	_panel(t, "CardPanel", _box(color("panel_raised"), color("panel_border"), bw, r_m, space("m"), space("s")))
	_panel(t, "InsetPanel", _box(Color(color("bg"), 0.55), clear, 0, r_s, space("s"), space("xs")))
	_panel(t, "ToastPanel", _box(Color(color("bg"), 0.92), color("panel_border_hover"), bw, r_m, space("l"), space("s"), true))
	_panel(t, "BannerPanel", _box(Color(color("danger").darkened(0.55), 0.92), color("danger"), bw * 2, r_m, space("xl"), space("s"), true))
	_panel(t, "TechPanel", _box(color("panel"), Color(color("tech"), 0.55), bw, r_l, space("l"), space("m"), true))
	_panel(t, "ModalPanel", _box(color("panel_raised"), color("panel_border_hover"), bw, r_l, space("xl"), space("xl"), true))
	# Cards standing on a frosted screen: solid, so nothing behind shows through their text.
	var solid: Color = Color(color("panel_raised"), 1.0)
	_panel(t, "SolidPanel", _box(solid, color("panel_border"), bw, r_l, space("l"), space("m"), true))
	_panel(t, "SolidTechPanel", _box(solid, Color(color("tech"), 0.6), bw, r_l, space("l"), space("m"), true))
	# Victory and defeat are told apart by the band across the top of the panel as well as
	# by its colour: the band is a shape.
	var won := _box(color("panel_raised"), color("tech"), bw, r_l, space("xl"), space("xl"), true)
	won.border_width_top = 6
	_panel(t, "VictoryPanel", won)
	var lost := _box(color("panel_raised"), color("danger"), bw, r_l, space("xl"), space("xl"), true)
	lost.border_width_top = 6
	_panel(t, "DefeatPanel", lost)
	# The beacon's stages, one pip each: lit when it stands repaired.
	for pair in [["PipOn", color("tech")], ["PipOff", Color(color("text_faint"), 0.45)]]:
		t.set_type_variation(pair[0], "Panel")
		t.set_stylebox("panel", pair[0], _box(pair[1], clear, 0, 3, 0, 0))
	# Paused with the menu shut: a frame round the whole screen.
	var frame := _box(clear, Color(color("accent"), 0.55), 4, 0, 0, 0)
	frame.draw_center = false
	t.set_type_variation("ScreenFrame", "Panel")
	t.set_stylebox("panel", "ScreenFrame", frame)

	# --- Buttons ----------------------------------------------------------------
	var raised: Color = color("panel_raised")
	_buttons(t, "Button",
		_box(raised, color("panel_border"), bw, r_m, space("m"), space("s")),
		_box(raised.lightened(0.07), color("panel_border_hover"), bw, r_m, space("m"), space("s")),
		_box(color("panel"), color("accent"), bw, r_m, space("m"), space("s")),
		_box(Color(raised, 0.45), Color(color("panel_border"), 0.45), bw, r_m, space("m"), space("s")),
		color("text"), color("text"), color("accent"), color("text_faint"))
	t.set_font("font", "Button", font("semibold"))
	t.set_font_size("font_size", "Button", font_size("label"))
	t.set_constant("h_separation", "Button", space("s"))
	t.set_constant("icon_max_width", "Button", icon_size("m"))
	var focus := _box(clear, Color(color("accent"), 0.7), bw, r_m, 0, 0)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)

	# The one thing to press: resume, restart, launch.
	t.set_type_variation("AccentButton", "Button")
	_buttons(t, "AccentButton",
		_box(color("accent"), color("accent"), bw, r_m, space("l"), space("s")),
		_box(color("accent").lightened(0.1), color("accent").lightened(0.2), bw, r_m, space("l"), space("s")),
		_box(color("accent").darkened(0.15), color("accent"), bw, r_m, space("l"), space("s")),
		_box(Color(color("accent"), 0.3), clear, 0, r_m, space("l"), space("s")),
		color("accent_text"), color("accent_text"), color("accent_text"), Color(color("accent_text"), 0.6))
	t.set_font("font", "AccentButton", font("bold"))

	# Something that cannot be undone: red text and a red edge on hover, not a red slab.
	t.set_type_variation("DangerButton", "Button")
	_buttons(t, "DangerButton",
		_box(raised, color("panel_border"), bw, r_m, space("m"), space("s")),
		_box(Color(color("danger"), 0.16), color("danger"), bw, r_m, space("m"), space("s")),
		_box(Color(color("danger"), 0.28), color("danger"), bw, r_m, space("m"), space("s")),
		_box(Color(raised, 0.45), Color(color("panel_border"), 0.45), bw, r_m, space("m"), space("s")),
		color("danger_text"), color("danger_text").lightened(0.1), color("text"), color("text_faint"))

	# Chrome on the HUD itself -- pause, menu -- has no slab until the cursor is on it.
	t.set_type_variation("GhostButton", "Button")
	_buttons(t, "GhostButton",
		_box(clear, clear, 0, r_m, space("s"), space("xs")),
		_box(Color(raised, 0.85), color("panel_border"), bw, r_m, space("s"), space("xs")),
		_box(Color(color("accent"), 0.18), color("accent"), bw, r_m, space("s"), space("xs")),
		_box(clear, clear, 0, r_m, space("s"), space("xs")),
		color("text"), color("text"), color("accent"), color("text_faint"))

	# One of a set, where the chosen one stays lit: the game speed.
	t.set_type_variation("SegmentButton", "Button")
	_buttons(t, "SegmentButton",
		_box(clear, clear, 0, r_s, space("s"), space("xs")),
		_box(Color(raised, 0.85), clear, 0, r_s, space("s"), space("xs")),
		_box(Color(color("accent"), 0.2), color("accent"), bw, r_s, space("s"), space("xs")),
		_box(clear, clear, 0, r_s, space("s"), space("xs")),
		color("text_muted"), color("text"), color("accent"), color("text_faint"))
	t.set_color("font_hover_pressed_color", "SegmentButton", color("accent"))
	t.set_font("font", "SegmentButton", font("bold", true))

	# A command card entry: its name up top, its price along the bottom inside the button
	# (the extra bottom margin is where the price row sits).
	t.set_type_variation("CardButton", "Button")
	var card_bottom: int = space("m") + font_size("small") + space("xs")
	var cards: Array = []
	for pair in [[raised, color("panel_border")], [raised.lightened(0.07), color("panel_border_hover")],
			[color("panel"), color("accent")], [Color(raised, 0.5), Color(color("panel_border"), 0.5)]]:
		var b := _box(pair[0], pair[1], bw, r_m, space("m"), space("s"))
		b.content_margin_bottom = card_bottom
		cards.append(b)
	_buttons(t, "CardButton", cards[0], cards[1], cards[2], cards[3],
		color("text"), color("text"), color("accent"), color("text_muted"))

	# --- Dropdowns --------------------------------------------------------------
	for state in ["normal", "hover", "pressed", "disabled"]:
		var b: StyleBox = t.get_stylebox(state, "Button")
		t.set_stylebox(state, "OptionButton", b)
		t.set_stylebox(state + "_mirrored", "OptionButton", b)
	t.set_stylebox("focus", "OptionButton", focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", t.get_color(c, "Button"))
	t.set_font("font", "OptionButton", font("medium"))
	t.set_font_size("font_size", "OptionButton", font_size("body"))
	var popup := _box(color("panel_raised"), color("panel_border_hover"), bw, r_m, space("xs"), space("xs"), true)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", _box(Color(color("accent"), 0.2), clear, 0, r_s, space("s"), space("xs")))
	t.set_color("font_color", "PopupMenu", color("text"))
	t.set_color("font_hover_color", "PopupMenu", color("text"))
	t.set_font("font", "PopupMenu", font("medium"))
	t.set_font_size("font_size", "PopupMenu", font_size("body"))
	t.set_constant("v_separation", "PopupMenu", space("s"))

	# --- Bars -------------------------------------------------------------------
	var trough := _box(Color(color("bg"), 0.85), Color(color("panel_border"), 0.9), bw, r_s, 0, 0)
	t.set_stylebox("background", "ProgressBar", trough)
	t.set_stylebox("fill", "ProgressBar", _box(color("success"), clear, 0, r_s, 0, 0))
	t.set_font("font", "ProgressBar", font("semibold", true))
	t.set_font_size("font_size", "ProgressBar", font_size("caption"))
	t.set_color("font_color", "ProgressBar", color("text"))
	for pair in [["HealthBar", color("success")], ["WarnBar", color("warning")], ["DangerBar", color("danger")],
			["BeaconBar", color("tech")]]:
		t.set_type_variation(pair[0], "ProgressBar")
		t.set_stylebox("background", pair[0], trough)
		t.set_stylebox("fill", pair[0], _box(pair[1], clear, 0, r_s, 0, 0))
	# Work in progress is a slanted bar: told from health by its shape, not only its colour.
	t.set_type_variation("BuildBar", "ProgressBar")
	t.set_stylebox("background", "BuildBar", trough)
	var build_fill := _box(color("warning"), clear, 0, 2, 0, 0)
	build_fill.skew = Vector2(0.35, 0.0)
	t.set_stylebox("fill", "BuildBar", build_fill)

	# --- Lines and tooltips ------------------------------------------------------
	var line := StyleBoxLine.new()
	line.color = color("panel_border")
	line.thickness = bw
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", space("s"))
	var vline := StyleBoxLine.new()
	vline.color = color("panel_border")
	vline.thickness = bw
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)
	t.set_constant("separation", "VSeparator", space("m"))
	t.set_stylebox("panel", "TooltipPanel", _box(Color(color("bg"), 0.96), color("panel_border_hover"), bw, r_s, space("m"), space("s")))
	t.set_color("font_color", "TooltipLabel", color("text"))
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

static func _box(bg: Color, border: Color, border_w: int, corner: int, margin_h: int, margin_v: int, shadow: bool = false) -> StyleBoxFlat:
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
	if shadow:
		b.shadow_color = color("shadow")
		b.shadow_size = int(tokens().get("shadow_size", 8))
		b.shadow_offset = Vector2(0, 3)
	return b

static func _label(t: Theme, name: String, weight: String, size_key: String, col: Color, outline: int = 0, tabular: bool = false) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font(weight, tabular))
	t.set_font_size("font_size", name, font_size(size_key))
	t.set_color("font_color", name, col)
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
