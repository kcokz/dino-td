# res://tests/test_v06_the_faces.gd
# v0.6 feedback: "我觉得字体也需要改，需要有优秀游戏的质感".
#
# Three faces (Config.THEME): titles, names and buttons cut in Cinzel's inscriptional capitals,
# Chinese in the same places in Noto Serif SC -- cut down to the characters the game says
# (tools/subset_fonts.py) -- and running text in Alegreya Sans, with the player's own system
# face for Chinese running text. All three bundled, their licences beside them.
#
# Everything expected is read from Config and translations/strings.csv.
extends "res://tests/test_base.gd"

var config_node: Object = null

func before_all() -> void:
	if tree != null and tree.root != null:
		config_node = tree.root.get_node_or_null("Config")

## Every character a column of the strings uses.
func _characters(column: String) -> Dictionary:
	var out: Dictionary = {}
	var file := FileAccess.open("res://translations/strings.csv", FileAccess.READ)
	if file == null:
		return out
	var header: PackedStringArray = file.get_csv_line()
	var at: int = Array(header).find(column)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if at < 0 or row.size() <= at:
			continue
		for c in row[at]:
			if c.strip_edges() != "":
				out[c] = true
	return out

func _path_of(font: Font) -> String:
	return font.resource_path if font else ""

func test_01_titles_are_cut_in_capitals_and_chinese_in_the_serif_beside_them() -> void:
	var tokens: Dictionary = config_node.THEME
	var f: Font = UiTheme.display_font("bold")
	assert_true(f is FontVariation, "The title face is a variation, weighted")
	if not (f is FontVariation):
		return
	var v := f as FontVariation
	assert_eq(_path_of(v.base_font), String(tokens["display_font"]), "Cut in Config's display face")
	assert_ne(v.base_font, ThemeDB.fallback_font, "not the engine's")
	assert_eq(int(v.variation_opentype.get("wght", 0)), int(tokens["weights"]["bold"]), "at the weight asked for")
	assert_gt(v.fallbacks.size(), 1, "Chinese, and what the capitals lack, have somewhere to go")
	if v.fallbacks.size() > 1:
		var cjk: Font = v.fallbacks[0]
		assert_true(cjk is FontVariation, "first the cut serif")
		if cjk is FontVariation:
			assert_eq(_path_of((cjk as FontVariation).base_font), String(tokens["display_cjk_font"]), "Config's cut face")
			assert_eq(int((cjk as FontVariation).variation_opentype.get("wght", 0)), int(tokens["weights"]["bold"]), "at the same weight")
		assert_true(v.fallbacks[1] is SystemFont, "then the player's own face")

func test_02_running_text_is_the_text_face_with_lining_figures() -> void:
	var tokens: Dictionary = config_node.THEME
	for weight in tokens["text_fonts"]:
		var f: Font = UiTheme.font(String(weight))
		assert_true(f is FontVariation, "%s is a variation" % weight)
		if not (f is FontVariation):
			continue
		var v := f as FontVariation
		assert_eq(_path_of(v.base_font), String(tokens["text_fonts"][weight]), "%s is Config's file for it" % weight)
		assert_eq(int(v.opentype_features.get("lnum", 0)), 1, "Figures stand on the line, not hang below it")
		assert_true(v.fallbacks.size() > 0 and v.fallbacks[0] is SystemFont, "Chinese running text is the player's system face")
		if v.fallbacks.size() > 0 and v.fallbacks[0] is SystemFont:
			assert_eq(Array((v.fallbacks[0] as SystemFont).font_names), Array(tokens["fallback_fonts"]), "the ones Config names, in order")
	var counts := UiTheme.font("bold", true) as FontVariation
	assert_eq(int(counts.opentype_features.get("tnum", 0)), 1, "A count's figures are all one width")

func test_03_the_cut_face_has_every_character_the_game_says_in_chinese() -> void:
	# Add a line with a character the cut lacks and a title shows it in another face: run
	# tools/subset_fonts.py again.
	var cut: Font = load(String(config_node.THEME["display_cjk_font"])) as Font
	assert_not_null(cut, "The cut face is there")
	if cut == null:
		return
	var said: Dictionary = _characters("zh_CN")
	assert_gt(said.size(), 100, "The Chinese strings were read")
	var missing: PackedStringArray = []
	for c in said:
		if not cut.has_char(String(c).unicode_at(0)):
			missing.append(String(c))
	assert_eq(missing.size(), 0, "Every character is cut (missing: %s) -- run tools/subset_fonts.py" % "".join(missing))

func test_04_the_engine_takes_the_cut_face_for_one_that_sets_han() -> void:
	# Before it sets a script in a face, the engine tries the face with that script's sample
	# character (ICU's); a cut without it is passed over for every Chinese title, whatever else
	# it holds -- the titles came out in the system's sans until the cut kept it.
	var cut: Font = load(String(config_node.THEME["display_cjk_font"])) as Font
	assert_not_null(cut, "The cut face is there")
	if cut == null:
		return
	var ts := TextServerManager.get_primary_interface()
	for rid in cut.get_rids():
		assert_true(ts.font_is_script_supported(rid, "Hani"), "The cut face is taken for one that sets Han")
	var title := TextLine.new()
	title.add_string("已暂停", UiTheme.display_font("black"), font_size_of("title"))
	var from_cut: bool = true
	for glyph in ts.shaped_text_get_glyphs(title.get_rid()):
		from_cut = from_cut and cut.get_rids().has(glyph["font_rid"])
	assert_true(from_cut, "and a Chinese title is set in it")

func font_size_of(key: String) -> int:
	return int(config_node.THEME["font_sizes"][key])

func test_05_every_latin_character_has_a_face_to_be_set_in() -> void:
	var text: Font = load(String(config_node.THEME["text_fonts"]["regular"])) as Font
	var display: Font = load(String(config_node.THEME["display_font"])) as Font
	var cut: Font = load(String(config_node.THEME["display_cjk_font"])) as Font
	assert_true(text != null and display != null and cut != null, "The faces are there")
	if text == null or display == null or cut == null:
		return
	for c in _characters("en"):
		var code: int = String(c).unicode_at(0)
		assert_true(text.has_char(code), "Running text has '%s' (U+%04X)" % [c, code])
		assert_true(display.has_char(code) or cut.has_char(code), "and a title has it, cut or in the serif (U+%04X)" % code)

func test_06_each_kind_of_text_is_set_in_its_face() -> void:
	var theme: Theme = UiTheme.get_theme()
	var display: String = String(config_node.THEME["display_font"])
	for type in ["TitleLabel", "DisplayLabel", "HeadingLabel", "StatLabel", "TechLabel", "Button", "AccentButton"]:
		var f: Font = theme.get_font("font", type)
		assert_true(f is FontVariation and _path_of((f as FontVariation).base_font) == display, "%s is cut in capitals" % type)
	for type in ["MutedLabel", "LeadLabel", "CaptionLabel", "NumberLabel", "SmallNumberLabel", "CardButton", "TooltipLabel"]:
		var f: Font = theme.get_font("font", type)
		assert_true(f is FontVariation and _path_of((f as FontVariation).base_font) != display, "%s is running text" % type)
	var spaced := theme.get_font("font", "TitleLabel") as FontVariation
	assert_eq(spaced.spacing_glyph, UiTheme.letter_spacing("title"), "A title is spaced as Config says")

func test_07_each_face_ships_with_its_licence() -> void:
	var paths: Array = [String(config_node.THEME["display_font"]), String(config_node.THEME["display_cjk_font"])]
	for weight in config_node.THEME["text_fonts"]:
		paths.append(String(config_node.THEME["text_fonts"][weight]))
	for path in paths:
		# assets/fonts/<Family>[-<style>].ttf ships beside assets/fonts/<Family>-OFL.txt
		var family: String = String(path).get_file().get_basename().get_slice("-", 0)
		var licence: String = String(path).get_base_dir().path_join(family + "-OFL.txt")
		assert_true(FileAccess.file_exists(licence), "%s ships with its licence (%s)" % [String(path).get_file(), licence])
