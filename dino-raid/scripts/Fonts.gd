class_name Fonts
## The game's faces: Noto Serif SC cut to the characters the game says (tools/subset_font.py), at any weight
## between regular and black; Alegreya Sans for the big numbers; Cinzel, Roman capitals, for the game's name and a
## coin's or a gem's figures (GAME-DESIGN 21).

const SERIF := "res://assets/fonts/NotoSerifSC-Raid.ttf"
const NUMBERS := "res://common/assets/fonts/AlegreyaSans-ExtraBold.ttf"
const DISPLAY := "res://common/assets/fonts/Cinzel.ttf"

static var _cache := {}


static func serif(weight := 400) -> Font:
	var key := "serif%d" % weight
	if not _cache.has(key):
		var fv := FontVariation.new()
		fv.base_font = load(SERIF) if ResourceLoader.exists(SERIF) else ThemeDB.fallback_font
		fv.variation_opentype = {"wght": weight}
		_cache[key] = fv
	return _cache[key]


static func numbers() -> Font:
	if not _cache.has("numbers"):
		_cache["numbers"] = load(NUMBERS) if ResourceLoader.exists(NUMBERS) else serif(800)
	return _cache["numbers"]


static func display(weight := 700) -> Font:
	var key := "display%d" % weight
	if not _cache.has(key):
		var fv := FontVariation.new()
		fv.base_font = load(DISPLAY) if ResourceLoader.exists(DISPLAY) else serif(800)
		fv.variation_opentype = {"wght": weight}
		_cache[key] = fv
	return _cache[key]
