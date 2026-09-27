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
## And it answers as the good ones do (v0.6: "还是没到优秀游戏的质感" -- Northgard, Age of Empires
## IV, Horizon's tribes): FRAMED. A panel is dark tanned leather in a rim of bone, pegged at its
## corners; the ship's own things are slate in steel with a line of cyan light; a button is
## leather in a thinner rim, the one thing to press painted ochre; a portrait sits in a sunk
## socket; a toast is a stroke of ink; a bar is a trough capped with bone with pigment in it;
## a title stands over a rule with a tooth at its middle. Each material is an image cut into
## nine (Config.THEME.surfaces, drawn by tools/build_ui_textures.gd), tinted only for a state.
## And the lettering is cut too: titles, names and buttons in Cinzel's inscriptional capitals
## (Chinese in Noto Serif SC), running text in Alegreya Sans.

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

## How a material is tinted for a state (Config.THEME.tints).
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

## Extra pixels between letters for a kind of capitals (Config.THEME.letter_spacing).
static func letter_spacing(key: String) -> int:
	return int(tokens().get("letter_spacing", {}).get(key, 0))

## A token that is one number: a duration, an alpha, a scale.
static func number(key: String) -> float:
	return float(tokens().get(key, 0.0))

static func toast_seconds(key: String) -> float:
	return float(tokens().get("toast_seconds", {}).get(key, 3.0))

## How far in from a hide's edge what it holds begins -- a card's name, its price row: inside
## its stitches, and clear of them.
static func card_inset() -> Vector2i:
	var stitch: int = int(tokens().get("surfaces", {}).get("hide", {}).get("stitch", 0))
	return Vector2i(stitch + space("s"), stitch + space("xs"))

## How wide a trough's bone cap is at each end: a bar's pigment runs between them.
static func bar_cap() -> int:
	return int(tokens().get("surfaces", {}).get("trough", {}).get("cap", 0))

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

## A weight of the running-text face (Config.THEME.text_fonts: Alegreya Sans) -- "regular",
## "medium", "semibold", "bold", "black" -- with Chinese falling back to the player's own system
## UI face at the same weight. Its figures are lining, and `tabular` gives every digit one
## width, so a count going 9 -> 10 -> 11 does not shuffle everything beside it sideways
## (UI-POLISH T7). `spacing` sets the letters that many pixels further apart.
static func font(weight: String = "regular", tabular: bool = false, spacing: int = 0) -> Font:
	var key: String = "text/%s/%s/%d" % [weight, tabular, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var f := FontVariation.new()
	f.base_font = _face(String(tokens().get("text_fonts", {}).get(weight, "")))
	var features: Dictionary = {"lnum": 1}
	if tabular:
		features["tnum"] = 1
	f.opentype_features = features
	if spacing != 0:
		f.spacing_glyph = spacing
	f.fallbacks = [_system_face(weight)]
	_fonts[key] = f
	return f

## The face titles, names and buttons are cut in (Config.THEME.display_font: Cinzel, whose
## lowercase is small capitals), at a weight and set `spacing` pixels wider. Chinese falls back
## to the cut Noto Serif SC at the same weight, then -- for a character the cut lacks -- to the
## player's own system face.
static func display_font(weight: String = "semibold", spacing: int = 0) -> Font:
	var key: String = "display/%s/%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var wght: int = _weight(weight)
	var f := FontVariation.new()
	f.base_font = _face(String(tokens().get("display_font", "")))
	f.variation_opentype = {"wght": wght}
	if spacing != 0:
		f.spacing_glyph = spacing
	var cjk := FontVariation.new()
	cjk.base_font = _face(String(tokens().get("display_cjk_font", "")))
	cjk.variation_opentype = {"wght": wght}
	f.fallbacks = [cjk, _system_face(weight)]
	_fonts[key] = f
	return f

static func _weight(weight: String) -> int:
	return int(tokens().get("weights", {}).get(weight, 400))

## A bundled face by path, loaded once; the engine's own where it is missing.
static func _face(path: String) -> Font:
	var key: String = "face:" + path
	if _fonts.has(key):
		return _fonts[key]
	var face: Font = load(path) as Font if (path != "" and ResourceLoader.exists(path)) else ThemeDB.fallback_font
	_fonts[key] = face
	return face

## The player's own system UI face for Chinese, at a weight (Config.THEME.fallback_fonts).
static func _system_face(weight: String) -> SystemFont:
	var key: String = "system/" + weight
	if _fonts.has(key):
		return _fonts[key]
	var cjk := SystemFont.new()
	cjk.font_names = PackedStringArray(tokens().get("fallback_fonts", []))
	cjk.font_weight = _weight(weight)
	_fonts[key] = cjk
	return cjk

## An icon by name: the one rendered from the thing itself where there is one
## (Config.RENDERED_ICONS: a material, from its pile), else the drawn one (Config.ICON_DIR
## /<name>.svg, a DPITexture drawn from the vector at whatever scale the screen needs) -- or
## null when there is neither.
static func icon(name: String) -> Texture2D:
	if name == "":
		return null
	if _icons.has(name):
		return _icons[name]
	var cfg = _config()
	var tex: Texture2D = null
	if cfg and "RENDERED_ICONS" in cfg:
		var shot: String = String(cfg.RENDERED_ICONS.get("dir", "")) + name + ".png"
		if ResourceLoader.exists(shot):
			tex = load(shot) as Texture2D
	var dir: String = String(cfg.ICON_DIR) if (cfg and "ICON_DIR" in cfg) else "res://assets/icons/"
	var path: String = dir + name + ".svg"
	if tex == null and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icons[name] = tex
	return tex

## The portrait of `key` -- a Config.VISUALS key: "hero", "building/wall", "station/kitchen"
## -- rendered from its model by tools/render_portraits.gd, or null where there is none.
static func portrait(key: String) -> Texture2D:
	var slot: String = "portrait:" + key
	if _icons.has(slot):
		return _icons[slot]
	var cfg = _config()
	var dir: String = String(cfg.PORTRAITS.get("dir", "")) if (cfg and "PORTRAITS" in cfg) else ""
	var path: String = dir + key.replace("/", "_") + ".png"
	var tex: Texture2D = load(path) as Texture2D if (dir != "" and key != "" and ResourceLoader.exists(path)) else null
	_icons[slot] = tex
	return tex

## How big a portrait is shown (Config.PORTRAITS.size, design pixels).
static func portrait_size() -> int:
	var cfg = _config()
	return int(cfg.PORTRAITS.get("size", 64)) if (cfg and "PORTRAITS" in cfg) else 64

## What a resource node is drawn as in the panel: its row says (a tree is not "wood").
static func node_icon(res_type: String) -> Texture2D:
	var cfg = _config()
	if cfg and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(res_type):
		return icon(String(cfg.RESOURCE_NODES[res_type].get("icon", res_type)))
	return icon(res_type)

## Text standing in the world over a thing -- a rock's name and what is left in it, a
## building's state, a count picked up: sized by Config.UI so it reads at any zoom, and set in
## the interface's own running face with a dark edge, as HudLabel is on the screen, so the
## world's words and the panels' are one lettering.
static func style_world_label(lbl: Label3D) -> void:
	var cfg = _config()
	var ui: Dictionary = cfg.UI if (cfg and "UI" in cfg) else {}
	lbl.font = font("bold")
	lbl.font_size = int(ui.get("world_label_font_size", 48))
	lbl.pixel_size = float(ui.get("world_label_pixel_size", 0.005))
	lbl.fixed_size = bool(ui.get("world_label_fixed_size", false))
	lbl.outline_size = maxi(1, int(round(lbl.font_size / 6.0)))
	lbl.outline_modulate = Color(color("bg"), 0.9)
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
## what it holds. Its shadow reaches past the rect it is drawn behind ("pad"), so the frame's
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
	# Its shadow reaches past the rect all round -- or, for one that runs off the screen, only
	# where it does not ("expand": left, top, right, bottom).
	var pad: float = float(spec.get("pad", 0))
	var reach: Vector4i = spec.get("expand", Vector4i(int(pad), int(pad), int(pad), int(pad)))
	b.expand_margin_left = reach.x
	b.expand_margin_top = reach.y
	b.expand_margin_right = reach.z
	b.expand_margin_bottom = reach.w
	# Tiled, each run fitted to a whole number of repeats, so a rim meets the corner piece
	# where it left it. What is stretched top to bottom instead says so ("tile_v").
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
	_label(t, "HudLabel", font("bold"), "label", color("text"), 6)
	_label(t, "MutedLabel", font("regular"), "small", color("text_muted"))
	_label(t, "CaptionLabel", font("medium"), "caption", color("text_faint"))
	_label(t, "LeadLabel", font("regular"), "body", color("text_muted"))
	_label(t, "NumberLabel", font("bold", true), "label", color("text"))
	_label(t, "SmallNumberLabel", font("bold", true), "small", color("text"))
	_label(t, "ShortNumberLabel", font("bold", true), "small", color("danger_text"))
	_label(t, "AccentLabel", font("bold"), "small", color("accent"))
	# Cut in capitals: a heading, a small capital label naming a card (the beacon's), a title,
	# the verdict, a figure on the results.
	_label(t, "HeadingLabel", display_font("bold", letter_spacing("heading")), "heading", color("text"))
	_label(t, "TechLabel", display_font("bold", letter_spacing("button")), "small", color("tech"))
	_title(t, "TitleLabel", display_font("black", letter_spacing("title")), "title")
	_title(t, "DisplayLabel", display_font("black", letter_spacing("display")), "display", 8)
	_title(t, "StatLabel", display_font("black"), "title")
	# The same figures on a pale hide -- a card's price and time -- in ink.
	_label(t, "CardNumberLabel", font("bold", true), "small", color("ink"))
	_label(t, "CardShortLabel", font("black", true), "small", color("ink_short"))
	_label(t, "CardCaptionLabel", font("medium"), "caption", color("ink_faint"))

	# --- Panels: leather framed in bone, and the ship's slate in steel -------------------
	var frame := surface("frame", "plain", space("l") + space("xs"), space("l"))
	t.set_stylebox("panel", "PanelContainer", frame)
	t.set_stylebox("panel", "Panel", frame)
	_panel(t, "HudPanel", frame)
	# The top row's slim plates: they sit over the world.
	_panel(t, "PillPanel", surface("plate", "plain", space("m") + space("xs"), space("xs") + space("hair")))
	# The status bar: one strip along the top edge; what it holds sits clear of its rim.
	var strip := surface("strip", "plain", space("l"), space("xs"))
	strip.content_margin_bottom = space("s") + space("hair")
	_panel(t, "StripPanel", strip)
	# A round socket for a material's icon on the strip.
	_panel(t, "SocketPanel", surface("socket_round", "plain", space("xs"), space("xs")))
	_panel(t, "CardPanel", surface("hide", "hide", inset.x, inset.y))
	# Round a portrait or a bench's icon: a socket sunk in the leather.
	_panel(t, "InsetPanel", surface("socket", "plain", space("s"), space("s")))
	_panel(t, "InsetTechPanel", surface("socket_tech", "plain", space("s"), space("s")))
	# A toast is a stroke of ink -- news, not an alarm; a raid is the same in red ochre. Their
	# words sit inside the stroke's ragged ends.
	var brush_h: int = int(tokens().get("surfaces", {}).get("brush", {}).get("margin", Vector2i.ZERO).x)
	_panel(t, "ToastPanel", surface("brush", "plain", brush_h, space("s") + space("xs")))
	_panel(t, "BannerPanel", surface("brush_blood", "plain", brush_h, space("s") + space("xs")))
	_panel(t, "TechPanel", surface("frame_tech", "plain", space("l") + space("xs"), space("l")))
	_panel(t, "ModalPanel", surface("frame", "plain", space("xl") + space("s"), space("xl")))
	_panel(t, "SolidPanel", frame)
	# The verdict: the ship's slate for a jump home, the leather gone red for a fall -- and its
	# icon and its word differ too, so it is never told by colour alone.
	_panel(t, "VictoryPanel", surface("frame_tech", "plain", space("xl") + space("s"), space("xl")))
	_panel(t, "DefeatPanel", surface("frame", "lost", space("xl") + space("s"), space("xl")))
	# The beacon's stages, one pip each: lit when it stands repaired.
	for pair in [["PipOn", color("tech")], ["PipOff", Color(color("text_faint"), 0.45)]]:
		t.set_type_variation(pair[0], "Panel")
		t.set_stylebox("panel", pair[0], _box(pair[1], clear, 0, 3, 0, 0))
	# Paused with the menu shut: a frame round the whole screen.
	var screen := _box(clear, Color(color("accent"), 0.55), 4, 0, 0, 0)
	screen.draw_center = false
	t.set_type_variation("ScreenFrame", "Panel")
	t.set_stylebox("panel", "ScreenFrame", screen)

	# --- Buttons: leather in a rim of bone, studded at each end ------------------------
	# Its word is cut in capitals and sits clear of the studs; pressed, it sinks a pixel.
	var bh: int = space("l") + space("xs")
	var bv: int = space("s")
	_buttons(t, "Button",
		surface("button", "plain", bh, bv), surface("button", "hover", bh, bv),
		_sunk(surface("button", "down", bh, bv)), surface("button", "off", bh, bv),
		color("text"), color("text"), color("accent"), color("text_faint"))
	t.set_font("font", "Button", display_font("bold", letter_spacing("button")))
	t.set_font_size("font_size", "Button", font_size("label"))
	t.set_constant("h_separation", "Button", space("s"))
	t.set_constant("icon_max_width", "Button", icon_size("m"))
	var focus := _box(clear, Color(color("accent"), 0.7), bw, r_s, 0, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(float(space("hair")))
	t.set_stylebox("focus", "Button", focus)

	# The one thing to press: resume, restart, launch -- painted ochre.
	t.set_type_variation("AccentButton", "Button")
	_buttons(t, "AccentButton",
		surface("button_accent", "plain", bh, bv), surface("button_accent", "hover", bh, bv),
		_sunk(surface("button_accent", "down", bh, bv)), surface("button_accent", "off", bh, bv),
		color("accent_text"), color("accent_text"), color("accent_text"), Color(color("accent_text"), 0.6))
	t.set_font("font", "AccentButton", display_font("black", letter_spacing("button")))

	# Something that cannot be undone: red words on plain leather, reddening under the cursor
	# -- not a red slab.
	t.set_type_variation("DangerButton", "Button")
	_buttons(t, "DangerButton",
		surface("button", "plain", bh, bv), surface("button", "rust", bh, bv),
		_sunk(surface("button", "rust_down", bh, bv)), surface("button", "off", bh, bv),
		color("danger_text"), color("text"), color("text"), color("text_faint"))

	# Chrome on the HUD itself -- pause, menu -- is pressed into the leather only under the
	# cursor.
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

	# One of a set, where the chosen one sits sunk in its socket and lit: the game speed, the
	# benches.
	t.set_type_variation("SegmentButton", "Button")
	_buttons(t, "SegmentButton",
		bare, surface("groove", "groove_faint", space("s"), space("xs")),
		surface("socket", "plain", space("xs"), space("xs")), bare,
		color("text_muted"), color("text"), color("accent"), color("text_faint"))
	t.set_color("font_hover_pressed_color", "SegmentButton", color("accent"))

	# The status bar's buttons: round, their glyph or figure in the middle; the one of a set
	# that is chosen -- the speed the game runs at -- painted ochre.
	t.set_type_variation("RoundButton", "Button")
	_buttons(t, "RoundButton",
		surface("round_button", "plain", 0, 0), surface("round_button", "hover", 0, 0),
		surface("round_button_lit", "plain", 0, 0), surface("round_button", "off", 0, 0),
		color("text"), color("text"), color("accent_text"), color("text_faint"))
	t.set_color("font_hover_pressed_color", "RoundButton", color("accent_text"))
	t.set_color("icon_hover_pressed_color", "RoundButton", color("accent_text"))
	t.set_font("font", "RoundButton", display_font("black"))
	t.set_font_size("font_size", "RoundButton", font_size("small"))
	t.set_constant("icon_max_width", "RoundButton", icon_size("s"))

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
	# A tag is narrow, and Cinzel's capitals are wide: its name is written in the running face,
	# bold, at the body size -- a name inked on a tag, where a command's is cut.
	t.set_font("font", "CardButton", font("bold"))
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
	# Its arrow sits clear of the stud at its end, like its word.
	t.set_constant("arrow_margin", "OptionButton", bh)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		t.set_color(c, "OptionButton", t.get_color(c, "Button"))
	t.set_font("font", "OptionButton", font("medium"))
	t.set_font_size("font_size", "OptionButton", font_size("body"))
	# A dropdown's list is a plate of leather; its entries sit clear of the rim.
	t.set_stylebox("panel", "PopupMenu", surface("plate", "plain", space("s"), space("s")))
	t.set_stylebox("hover", "PopupMenu", surface("groove", "groove", space("s"), space("xs")))
	t.set_color("font_color", "PopupMenu", color("text"))
	t.set_color("font_hover_color", "PopupMenu", color("accent"))
	t.set_font("font", "PopupMenu", font("medium"))
	t.set_font_size("font_size", "PopupMenu", font_size("body"))
	t.set_constant("v_separation", "PopupMenu", space("s"))

	# --- Bars: a trough capped with bone, and pigment between the caps -----------------
	var trough := surface("trough", "plain", 0, 0)
	t.set_stylebox("background", "ProgressBar", trough)
	t.set_stylebox("fill", "ProgressBar", _pigment("paint", color("success")))
	t.set_font("font", "ProgressBar", font("bold", true))
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

	# --- Rules and tooltips --------------------------------------------------------
	# A rule of bone across a panel; under a title, with the tooth at its middle.
	t.set_stylebox("separator", "HSeparator", _rule(false))
	t.set_constant("separation", "HSeparator", space("s"))
	t.set_type_variation("TitleRule", "HSeparator")
	t.set_stylebox("separator", "TitleRule", _rule(true))
	t.set_constant("separation", "TitleRule", space("m"))
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

## A bar's fill: pigment of `col`, laid in the trough between its bone caps and inside its
## walls (Config.THEME.fill_inset). The caps are the fill's own margins, taken back in by its
## expand margins, so an empty bar draws nothing and a full one runs cap to cap.
static func _pigment(name: String, col: Color) -> StyleBox:
	var b: StyleBox = surface(name, col, bar_cap(), 0)
	var sink: float = float(tokens().get("fill_inset", 0))
	if b is StyleBoxTexture:
		(b as StyleBoxTexture).expand_margin_left = -float(bar_cap())
		(b as StyleBoxTexture).expand_margin_right = -float(bar_cap())
		(b as StyleBoxTexture).expand_margin_top = -sink
		(b as StyleBoxTexture).expand_margin_bottom = -sink
	return b

## A rule across a panel, with the tooth at its middle if `ornamented`.
static func _rule(ornamented: bool) -> StyleBox:
	var r := UiRule.new()
	var spec: Dictionary = tokens().get("surfaces", {}).get("rule", {})
	r.line = surface("rule", "plain", 0, 0)
	r.line_height = float(Vector2i(spec.get("size", Vector2i.ZERO)).y)
	var tall: float = r.line_height
	if ornamented:
		r.ornament = surface_texture("ornament")
		if r.ornament:
			tall = maxf(tall, r.ornament.get_size().y)
	r.content_margin_top = ceilf(tall * 0.5)
	r.content_margin_bottom = ceilf(tall * 0.5)
	return r

static func _label(t: Theme, name: String, face: Font, size_key: String, col: Color, outline: int = 0) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, face)
	t.set_font_size("font_size", name, font_size(size_key))
	t.set_color("font_color", name, col)
	if outline > 0:
		t.set_constant("outline_size", name, outline)
		t.set_color("font_outline_color", name, Color(color("bg"), 0.85))

## A title: cut in capitals and standing proud of the leather on a shadow (title_shadow).
static func _title(t: Theme, name: String, face: Font, size_key: String, outline: int = 0) -> void:
	_label(t, name, face, size_key, color("text"), outline)
	var drop: Vector2i = tokens().get("title_shadow", Vector2i.ZERO)
	t.set_color("font_shadow_color", name, color("shadow"))
	t.set_constant("shadow_offset_x", name, drop.x)
	t.set_constant("shadow_offset_y", name, drop.y)

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
