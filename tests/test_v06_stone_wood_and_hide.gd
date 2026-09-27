# res://tests/test_v06_stone_wood_and_hide.gd
# v0.6 feedback: "现在的菜单界面还是像网页游戏，没有单机游戏的那种有主题和质感的精致感，我想要的主题
# 是那种远古时代质感的菜单界面，状态栏".
#
# The interface is made of the valley's materials (Config.THEME.surfaces, drawn by
# tools/build_ui_textures.gd): stone for every panel, a lashed plank for every button, a
# stitched hide for every card, toast and tooltip, a groove with pigment in it for every bar.
# Each is one image cut into nine and tiled, so each must be drawn to tile -- and what sits on
# one must sit clear of its edges: inside a hide's stitches, past a plank's lashing.
#
# Everything expected is read from Config.
extends "res://tests/test_base.gd"

var config_node: Object = null

var _cleanup_nodes: Array[Node] = []

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

func after_each() -> void:
	for n in _cleanup_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.get_parent().remove_child(n)
			if not n.is_queued_for_deletion():
				n.free()
	_cleanup_nodes.clear()
	super.after_each()

func _surfaces() -> Dictionary:
	return config_node.THEME["surfaces"]

func _scale() -> int:
	return int(config_node.THEME["surface_scale"])

func _texture_of(box: StyleBox) -> Texture2D:
	return (box as StyleBoxTexture).texture if box is StyleBoxTexture else null

## How different line `a` of an image is from line `b` (columns, or rows if `rows`), on
## average over every pixel along them.
func _difference(img: Image, a: int, b: int, rows: bool) -> float:
	var n: int = img.get_width() if rows else img.get_height()
	var total: float = 0.0
	for i in n:
		var p: Color = img.get_pixel(i, a) if rows else img.get_pixel(a, i)
		var q: Color = img.get_pixel(i, b) if rows else img.get_pixel(b, i)
		total += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a)
	return total / float(n * 4)

## Whether the middle of `img` between `m` and `end` (exclusive) runs from its last line into
## its first as smoothly as from any line into the next: [seam, the usual step].
func _seam(img: Image, m: int, end: int, rows: bool) -> Array:
	var usual: float = 0.0
	for i in range(m, end - 1):
		usual += _difference(img, i, i + 1, rows)
	usual /= float(maxi(1, end - 1 - m))
	return [_difference(img, end - 1, m, rows), usual]

# ==============================================================================
# The materials
# ==============================================================================

func test_01_every_material_is_drawn_at_its_scale_and_shown_at_its_size() -> void:
	assert_gt(_surfaces().size(), 0, "The interface has materials")
	for name in _surfaces():
		var spec: Dictionary = _surfaces()[name]
		var path: String = String(spec["image"])
		assert_true(ResourceLoader.exists(path), "%s is there (%s)" % [name, path])
		var img: Image = load(path) as Image
		assert_not_null(img, "%s comes in as an image, for the theme to make its texture from" % name)
		if img == null:
			continue
		assert_eq(img.get_size(), Vector2i(spec["size"]) * _scale(),
			"%s is drawn at %dx its size: sharp where the screen draws the interface bigger" % [name, _scale()])
		var tex: Texture2D = UiTheme.surface_texture(String(name))
		assert_not_null(tex, "%s has a texture" % name)
		if tex:
			assert_eq(Vector2i(tex.get_size()), Vector2i(spec["size"]), "%s is shown at its design size" % name)

func test_02_each_kind_of_thing_is_made_of_its_material() -> void:
	var theme: Theme = UiTheme.get_theme()
	var made_of: Array = [
		["panel", "HudPanel", "stone"], ["panel", "PillPanel", "stone"], ["panel", "ModalPanel", "stone"],
		["panel", "TechPanel", "stone"], ["panel", "VictoryPanel", "stone"], ["panel", "DefeatPanel", "stone"],
		["panel", "ToastPanel", "hide"], ["panel", "BannerPanel", "hide"], ["panel", "TooltipPanel", "hide"],
		["panel", "InsetPanel", "groove"], ["panel", "InsetTechPanel", "groove"],
		["normal", "Button", "plank"], ["normal", "AccentButton", "plank"], ["normal", "DangerButton", "plank"],
		["normal", "OptionButton", "plank"], ["normal", "CardButton", "hide"], ["pressed", "SegmentButton", "groove"],
		["background", "HealthBar", "groove"], ["fill", "HealthBar", "paint"], ["fill", "DangerBar", "paint"],
		["fill", "BeaconBar", "paint"], ["fill", "BuildBar", "hatch"],
	]
	for row in made_of:
		var box: StyleBox = theme.get_stylebox(row[0], row[1])
		var tex: Texture2D = _texture_of(box)
		assert_not_null(tex, "%s's %s is a material, not a flat box" % [row[1], row[0]])
		assert_eq(tex, UiTheme.surface_texture(row[2]), "%s's %s is %s" % [row[1], row[0], row[2]])

func test_03_one_material_is_tinted_to_what_it_is_there() -> void:
	var theme: Theme = UiTheme.get_theme()
	var tints: Dictionary = config_node.THEME["tints"]
	for row in [["panel", "HudPanel", "stone"], ["panel", "TechPanel", "slate"], ["panel", "ToastPanel", "leather"],
			["panel", "BannerPanel", "blood"], ["normal", "CardButton", "hide"], ["disabled", "CardButton", "hide_off"],
			["normal", "AccentButton", "ochre"], ["hover", "DangerButton", "rust"], ["panel", "VictoryPanel", "won"],
			["panel", "DefeatPanel", "lost"]]:
		var box: StyleBox = theme.get_stylebox(row[0], row[1])
		assert_true(box is StyleBoxTexture, "%s's %s is a material" % [row[1], row[0]])
		if box is StyleBoxTexture:
			assert_eq((box as StyleBoxTexture).modulate_color, tints[row[2]], "%s's %s is tinted %s" % [row[1], row[0], row[2]])
	# A card and a toast are one hide: the tint is all that tells a pale tag from dark leather.
	assert_ne(tints["hide"], tints["leather"], "A card and a toast are told apart")
	assert_ne(tints["won"], tints["lost"], "And a jump home from a fall")

func test_04_a_material_is_cut_where_config_says_and_its_shadow_reaches_past_it() -> void:
	for name in _surfaces():
		var spec: Dictionary = _surfaces()[name]
		var box: StyleBox = UiTheme.surface(String(name), Color.WHITE, 0, 0)
		assert_true(box is StyleBoxTexture, "%s is cut into nine" % name)
		if not (box is StyleBoxTexture):
			continue
		var b := box as StyleBoxTexture
		var m: Vector2i = spec["margin"]
		assert_eq(Vector2i(int(b.texture_margin_left), int(b.texture_margin_top)), m, "%s is cut at its margin" % name)
		assert_eq(Vector2i(int(b.texture_margin_right), int(b.texture_margin_bottom)), m, "on all four sides")
		var pad: float = float(spec.get("pad", 0))
		assert_eq(b.expand_margin_left, pad, "%s's shadow reaches past what it is drawn behind" % name)
		assert_eq(b.expand_margin_bottom, pad, "all round")
		assert_eq(b.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT,
			"%s is tiled along, a whole number of times" % name)
		var down: int = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT if bool(spec.get("tile_v", true)) \
			else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		assert_eq(b.axis_stretch_vertical, down, "%s is tiled or stretched top to bottom as Config says" % name)

func test_05_each_material_is_drawn_to_tile() -> void:
	# A tiled middle is followed by its own first line: its last must run on into its first as
	# smoothly as any line runs into the next, or every panel shows a seam once a tile -- across
	# its edges too, where the chipped outline and the stitches have to carry on.
	for name in _surfaces():
		var spec: Dictionary = _surfaces()[name]
		var img: Image = load(String(spec["image"])) as Image
		if img == null:
			assert_not_null(img, "%s is there to look at" % name)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var m: Vector2i = Vector2i(spec["margin"]) * _scale()
		var along: Array = _seam(img, m.x, img.get_width() - m.x, false)
		assert_lt(along[0], along[1] * 2.5 + 0.004, "%s runs on into itself along (seam %.4f, a step %.4f)" % [name, along[0], along[1]])
		if bool(spec.get("tile_v", true)):
			var down: Array = _seam(img, m.y, img.get_height() - m.y, true)
			assert_lt(down[0], down[1] * 2.5 + 0.004, "%s runs on into itself down (seam %.4f, a step %.4f)" % [name, down[0], down[1]])

# ==============================================================================
# What sits on them
# ==============================================================================

func test_06_what_a_card_holds_sits_inside_its_stitches_in_ink() -> void:
	var theme: Theme = UiTheme.get_theme()
	var colors: Dictionary = config_node.THEME["colors"]
	var stitch: int = int(_surfaces()["hide"]["stitch"])
	var inset: Vector2i = UiTheme.card_inset()
	assert_gt(inset.x, stitch, "A card's name starts inside the stitches")
	assert_gt(inset.y, stitch, "top and bottom too")
	var card: StyleBox = theme.get_stylebox("normal", "CardButton")
	assert_gte(card.content_margin_left, float(inset.x), "The card's name is held inside them")
	assert_gte(card.content_margin_top, float(inset.y), "from the top")
	var btn: Button = UiKit.card_button("Stakes", UiTheme.icon("wall"), func() -> void: pass)
	_cleanup_nodes.append(btn)
	var row: Control = btn.get_node_or_null("PriceRow")
	assert_not_null(row, "A card has a price row")
	if row:
		assert_gte(row.offset_left, float(inset.x), "Its price row starts inside the stitches")
		assert_lte(row.offset_right, -float(inset.x), "and ends inside them")
		assert_lte(row.offset_bottom, -float(inset.y), "and sits above the bottom row of them")
		UiKit.fill_price_row(btn, {"wood": 99999})
		var figures: int = 0
		for child in row.get_children():
			if child is Label:
				figures += 1
				assert_true(String(child.theme_type_variation).begins_with("Card"),
					"A figure on a hide is inked (%s)" % child.theme_type_variation)
		assert_gt(figures, 0, "The price is written on it")
	# Ink, not bone: the pale hide would swallow the text the stone carries.
	assert_eq(theme.get_color("font_color", "CardButton"), colors["ink"], "A card's name is in ink")
	assert_eq(theme.get_color("font_color", "CardNumberLabel"), colors["ink"], "and its figures")
	assert_eq(theme.get_color("font_color", "CardShortLabel"), colors["ink_short"], "a count he is short of in red ink")
	assert_eq(theme.get_color("font_color", "TooltipLabel"), colors["ink"], "and a tooltip, on the same hide")
	assert_eq(theme.get_color("icon_normal_color", "CardButton"), Color.WHITE, "Its icon keeps its own colours")

func test_07_a_buttons_word_starts_past_its_lashing() -> void:
	var theme: Theme = UiTheme.get_theme()
	var lash: Vector2 = _surfaces()["plank"]["lash"]
	for type in ["Button", "AccentButton", "DangerButton", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBox = theme.get_stylebox(state, type)
			assert_gte(box.content_margin_left, lash.x + lash.y, "%s (%s) starts its word past the lashing" % [type, state])
			assert_gte(box.content_margin_right, lash.x + lash.y, "and ends it before the far one")
	assert_gte(float(theme.get_constant("arrow_margin", "OptionButton")), lash.x + lash.y, "A dropdown's arrow is inside the lashing too")
	var down: StyleBox = theme.get_stylebox("pressed", "Button")
	var up: StyleBox = theme.get_stylebox("normal", "Button")
	assert_gt(down.content_margin_top, up.content_margin_top, "Pressed, a plank's word sinks")

func test_08_a_bar_is_pigment_in_a_groove() -> void:
	var theme: Theme = UiTheme.get_theme()
	var inset: float = float(config_node.THEME["fill_inset"])
	for type in ["HealthBar", "WarnBar", "DangerBar", "BeaconBar", "BuildBar"]:
		var fill: StyleBox = theme.get_stylebox("fill", type)
		assert_true(fill is StyleBoxTexture, "%s's fill is pigment" % type)
		if fill is StyleBoxTexture:
			assert_eq((fill as StyleBoxTexture).expand_margin_top, -inset, "%s's pigment sits inside the groove's walls" % type)
			assert_eq((fill as StyleBoxTexture).expand_margin_bottom, -inset, "top and bottom")
	assert_gt(UiTheme.thickness("bar"), int(inset) * 2, "A bar is thicker than its two walls, or there is no pigment to see")
	var colors: Dictionary = config_node.THEME["colors"]
	assert_eq((theme.get_stylebox("fill", "DangerBar") as StyleBoxTexture).modulate_color, colors["danger"],
		"A bar's pigment is its colour")

func test_09_titles_stand_proud() -> void:
	var theme: Theme = UiTheme.get_theme()
	var drop: Vector2i = config_node.THEME["title_shadow"]
	for pair in [["TitleLabel", "title"], ["DisplayLabel", "display"]]:
		assert_eq(Vector2i(theme.get_constant("shadow_offset_x", pair[0]), theme.get_constant("shadow_offset_y", pair[0])), drop,
			"%s stands on a shadow" % pair[0])
		var f: Font = theme.get_font("font", pair[0])
		assert_true(f is FontVariation, "%s is a variation of the face" % pair[0])
		if f is FontVariation:
			assert_eq((f as FontVariation).spacing_glyph, int(config_node.THEME["title_spacing"][pair[1]]),
				"%s is set wide" % pair[0])
