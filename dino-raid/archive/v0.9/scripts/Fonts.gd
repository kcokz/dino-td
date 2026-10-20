class_name Fonts
## The game's faces: Noto Serif SC cut to the characters the game says (tools/subset_font.py), at any weight
## between regular and black; Alegreya Sans for the big numbers.

const SERIF := "res://assets/fonts/NotoSerifSC-Raid.ttf"
const NUMBERS := "res://common/assets/fonts/AlegreyaSans-ExtraBold.ttf"

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
