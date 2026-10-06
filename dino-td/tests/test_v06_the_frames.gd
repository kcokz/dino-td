# res://tests/test_v06_the_frames.gd
# v0.6 feedback: "现在的菜单界面还是像网页游戏……我想要的主题是那种远古时代质感的菜单界面，状态栏",
# and then "还是没到优秀游戏的质感，你可能需要参考一下别的优秀游戏面板怎么做的".
#
# The interface is FRAMED, as the good ones are (Config.THEME.surfaces, drawn by
# tools/build_ui_textures.gd): leather in a rim of bone for every panel, the ship's slate in
# steel for its own things, a studded button, a sunk socket, a brush stroke for a toast, a
# trough capped with bone for a bar, a rule with a tooth under a title, a stitched hide for a
# card. Each is one image cut into nine and tiled, so each must be drawn to tile, and what sits
# on one must sit clear of what is drawn round its edge.
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

## Whether a surface is cut into nine (the ornament is drawn whole).
func _is_cut(spec: Dictionary) -> bool:
	return Vector2i(spec["margin"]) != Vector2i.ZERO

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

## How a middle from `m` to `end` (exclusive) runs from its last line into its first, against
## how it runs from any line into the next: [seam, the usual step].
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
		["panel", "HudPanel", "frame"], ["panel", "ModalPanel", "frame"], ["panel", "SolidPanel", "frame"],
		["panel", "PillPanel", "plate"], ["panel", "TechPanel", "frame_tech"], ["panel", "VictoryPanel", "frame_tech"],
		["panel", "DefeatPanel", "frame"], ["panel", "ToastPanel", "brush"],
		["panel", "TooltipPanel", "hide"], ["panel", "CardPanel", "hide"],
		["panel", "InsetPanel", "socket"], ["panel", "InsetTechPanel", "socket_tech"],
		["normal", "Button", "button"], ["normal", "DangerButton", "button"], ["normal", "OptionButton", "button"],
		["normal", "AccentButton", "button_accent"], ["normal", "CardButton", "hide"],
		["pressed", "SegmentButton", "socket"], ["hover", "GhostButton", "groove"],
		["background", "HealthBar", "trough"], ["fill", "HealthBar", "paint"], ["fill", "DangerBar", "paint"],
		["fill", "BeaconBar", "paint"], ["fill", "BuildBar", "hatch"],
	]
	for row in made_of:
		var tex: Texture2D = _texture_of(theme.get_stylebox(row[0], row[1]))
		assert_not_null(tex, "%s's %s is a material, not a flat box" % [row[1], row[0]])
		assert_eq(tex, UiTheme.surface_texture(row[2]), "%s's %s is %s" % [row[1], row[0], row[2]])

func test_03_a_state_is_a_tint_of_the_same_material() -> void:
	var theme: Theme = UiTheme.get_theme()
	var tints: Dictionary = config_node.THEME["tints"]
	for row in [["normal", "Button", "plain"], ["hover", "Button", "hover"], ["pressed", "Button", "down"],
			["disabled", "Button", "off"], ["hover", "AccentButton", "hover"], ["hover", "DangerButton", "rust"],
			["panel", "DefeatPanel", "lost"], ["normal", "CardButton", "hide"], ["disabled", "CardButton", "hide_off"]]:
		var box: StyleBox = theme.get_stylebox(row[0], row[1])
		assert_true(box is StyleBoxTexture, "%s's %s is a material" % [row[1], row[0]])
		if box is StyleBoxTexture:
			assert_eq((box as StyleBoxTexture).modulate_color, tints[row[2]], "%s's %s is tinted %s" % [row[1], row[0], row[2]])
	assert_gt(tints["hover"].get_luminance(), tints["plain"].get_luminance(), "Under the cursor a button catches more light")
	assert_lt(tints["down"].get_luminance(), tints["plain"].get_luminance(), "and pressed, less")
	assert_lt(tints["off"].a, 1.0, "One that cannot be pressed lets the world through")
	assert_ne(_texture_of(theme.get_stylebox("panel", "VictoryPanel")), _texture_of(theme.get_stylebox("panel", "DefeatPanel")),
		"A jump home and a fall are not the same frame")

func test_04_a_material_is_cut_where_config_says_and_its_shadow_reaches_past_it() -> void:
	for name in _surfaces():
		var spec: Dictionary = _surfaces()[name]
		if not _is_cut(spec):
			continue
		var box: StyleBox = UiTheme.surface(String(name), Color.WHITE, 0, 0)
		assert_true(box is StyleBoxTexture, "%s is cut into nine" % name)
		if not (box is StyleBoxTexture):
			continue
		var b := box as StyleBoxTexture
		var m: Vector2i = spec["margin"]
		assert_eq(Vector2i(int(b.texture_margin_left), int(b.texture_margin_top)), m, "%s is cut at its margin" % name)
		assert_eq(Vector2i(int(b.texture_margin_right), int(b.texture_margin_bottom)), m, "on all four sides")
		# All round, unless Config says where (the strip lies against the screen's edges, so
		# its shadow falls below it only).
		var pad: int = int(spec.get("pad", 0))
		var reach: Vector4i = spec.get("expand", Vector4i(pad, pad, pad, pad))
		assert_eq(Vector4i(int(b.expand_margin_left), int(b.expand_margin_top), int(b.expand_margin_right),
			int(b.expand_margin_bottom)), reach, "%s's shadow reaches past what it is drawn behind" % name)
		assert_eq(b.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT,
			"%s is tiled along, a whole number of times" % name)
		var down: int = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT if bool(spec.get("tile_v", true)) \
			else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		assert_eq(b.axis_stretch_vertical, down, "%s is tiled or stretched top to bottom as Config says" % name)

func test_05_each_material_is_drawn_to_tile() -> void:
	# A tiled middle is followed by its own first line: its last must run on into its first as
	# smoothly as any line runs into the next, or every panel shows a seam once a tile -- across
	# its rim too, which has to carry on round the whole panel.
	for name in _surfaces():
		var spec: Dictionary = _surfaces()[name]
		if not _is_cut(spec):
			continue
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
	# Ink, not bone: the pale hide would swallow the text the leather carries.
	assert_eq(theme.get_color("font_color", "CardButton"), colors["ink"], "A card's name is in ink")
	assert_eq(theme.get_color("font_color", "CardNumberLabel"), colors["ink"], "and its figures")
	assert_eq(theme.get_color("font_color", "CardShortLabel"), colors["ink_short"], "a count he is short of in red ink")
	assert_eq(theme.get_color("font_color", "TooltipLabel"), colors["ink"], "and a tooltip, on the same hide")
	assert_eq(theme.get_color("icon_normal_color", "CardButton"), Color.WHITE, "Its icon keeps its own colours")

func test_07_a_buttons_word_sits_clear_of_its_rim_and_studs() -> void:
	# The rim and the stud at each end live in a button's end pieces: its word starts past them.
	var theme: Theme = UiTheme.get_theme()
	for pair in [["Button", "button"], ["AccentButton", "button_accent"], ["DangerButton", "button"], ["OptionButton", "button"]]:
		var ends: float = float(Vector2i(_surfaces()[pair[1]]["margin"]).x)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBox = theme.get_stylebox(state, pair[0])
			assert_gte(box.content_margin_left, ends, "%s (%s) starts its word past the stud" % [pair[0], state])
			assert_gte(box.content_margin_right, ends, "and ends it before the far one")
	assert_gte(float(theme.get_constant("arrow_margin", "OptionButton")), float(Vector2i(_surfaces()["button"]["margin"]).x),
		"A dropdown's arrow is clear of the stud too")
	var down: StyleBox = theme.get_stylebox("pressed", "Button")
	var up: StyleBox = theme.get_stylebox("normal", "Button")
	assert_gt(down.content_margin_top, up.content_margin_top, "Pressed, a button's word sinks")
	var toast: StyleBox = theme.get_stylebox("panel", "ToastPanel")
	assert_gte(toast.content_margin_left, float(Vector2i(_surfaces()["brush"]["margin"]).x),
		"A toast's words sit inside the brush stroke's ragged ends")

func test_08_a_bar_is_pigment_in_a_trough_between_its_caps() -> void:
	var theme: Theme = UiTheme.get_theme()
	var inset: float = float(config_node.THEME["fill_inset"])
	var cap: float = float(_surfaces()["trough"]["cap"])
	for type in ["HealthBar", "WarnBar", "DangerBar", "BeaconBar", "BuildBar"]:
		var fill: StyleBox = theme.get_stylebox("fill", type)
		assert_true(fill is StyleBoxTexture, "%s's fill is pigment" % type)
		if not (fill is StyleBoxTexture):
			continue
		var f := fill as StyleBoxTexture
		assert_eq(f.expand_margin_top, -inset, "%s's pigment sits inside the trough's walls" % type)
		assert_eq(f.expand_margin_bottom, -inset, "top and bottom")
		assert_eq(f.expand_margin_left, -cap, "%s's pigment starts past the bone cap" % type)
		assert_eq(f.expand_margin_right, -cap, "and ends before the other")
		assert_eq(f.content_margin_left + f.content_margin_right, 2.0 * cap,
			"A bar's fill is as wide as its caps before it holds anything, so empty draws nothing and full runs cap to cap")
	assert_gt(UiTheme.thickness("bar"), int(inset) * 2, "A bar is thicker than its two walls, or there is no pigment to see")
	var colors: Dictionary = config_node.THEME["colors"]
	assert_eq((theme.get_stylebox("fill", "DangerBar") as StyleBoxTexture).modulate_color, colors["danger"],
		"A bar's pigment is its colour")

func test_09_a_title_stands_on_a_shadow_over_a_rule_with_a_tooth() -> void:
	var theme: Theme = UiTheme.get_theme()
	var drop: Vector2i = config_node.THEME["title_shadow"]
	for type in ["TitleLabel", "DisplayLabel"]:
		assert_eq(Vector2i(theme.get_constant("shadow_offset_x", type), theme.get_constant("shadow_offset_y", type)), drop,
			"%s stands on a shadow" % type)
	var plain: StyleBox = theme.get_stylebox("separator", "HSeparator")
	var under_title: StyleBox = theme.get_stylebox("separator", "TitleRule")
	assert_true(plain is UiRule and under_title is UiRule, "A rule across a panel is a line of bone")
	if plain is UiRule and under_title is UiRule:
		assert_null((plain as UiRule).ornament, "A plain rule carries no flourish")
		assert_eq((under_title as UiRule).ornament, UiTheme.surface_texture("ornament"), "The one under a title carries the tooth")
		assert_gte(under_title.get_minimum_size().y, UiTheme.surface_texture("ornament").get_size().y,
			"and is tall enough to show it")
	var menu = load("res://scripts/ui/PauseMenu.gd").new()
	_cleanup_nodes.append(menu)
	tree.root.add_child(menu)
	await wait_frames(1)
	var rule: Node = menu.find_child("TitleRule", true, false)
	assert_not_null(rule, "The menu's title has its rule")
	if rule:
		assert_eq(rule.theme_type_variation, &"TitleRule", "with the tooth")

## The pause menu's words line up (the player, 2026-10-04: "resume和其他的按钮字体没对齐"): no button gives its words' room
## to an icon -- Resume's play mark stands apart, at its left end (PauseMenu._glyph).
func test_99_the_pause_menus_words_line_up() -> void:
	var main = await fresh_level()
	main.hud.toggle_pause_menu()
	await wait_frames(3)
	var menu = main.hud.pause_menu
	for btn in [menu.resume_btn, menu.settings_btn, menu.new_game_btn, menu.quit_btn]:
		assert_null(btn.icon, "%s's words have the whole button" % btn.name)
		assert_eq(int(btn.alignment), int(HORIZONTAL_ALIGNMENT_CENTER), "centred")
	assert_not_null(menu.resume_btn.get_node_or_null("Glyph"), "Resume keeps its play mark, apart")
	main.hud.toggle_pause_menu()
	main.queue_free()
	await wait_frames(2)
