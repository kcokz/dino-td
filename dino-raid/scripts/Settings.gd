class_name Settings
## What the player set (GAME-DESIGN 21), kept between runs in user://settings.cfg: full screen (from the first time
## on, as a game opens; F11 or Alt+Enter switches it, Menu), the volume, the buttons' click, battles starting at the
## faster speed, the language (Lang).

const PATH := "user://settings.cfg"

static var fullscreen := true
static var volume := 80                 # 0 to 100
static var clicks := true
static var fast := false                # a battle starts at the faster speed
static var language := ""               # "zh" or "en" (Lang.LOCALES); "" until known
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		fullscreen = bool(cf.get_value("screen", "fullscreen", true))
		volume = clampi(int(cf.get_value("sound", "volume", 80)), 0, 100)
		clicks = bool(cf.get_value("sound", "clicks", true))
		fast = bool(cf.get_value("play", "fast", false))
		language = str(cf.get_value("play", "language", ""))
	if not Lang.LOCALES.has(language):
		language = "zh"
	apply()


## Kept for next time -- not by a tool (playtest.gd, a screenshot), whose settings are its own.
static func save() -> void:
	if "--script" in OS.get_cmdline_args():
		return
	var cf := ConfigFile.new()
	cf.set_value("screen", "fullscreen", fullscreen)
	cf.set_value("sound", "volume", volume)
	cf.set_value("sound", "clicks", clicks)
	cf.set_value("play", "fast", fast)
	cf.set_value("play", "language", language)
	cf.save(PATH)


## The settings put into effect -- the window left alone under a tool (playtest.gd) that sets its own, and when the
## game is run inside the editor's own panel (its window is the editor's: run on its own, it goes full screen).
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volume / 100.0) if volume > 0 else -80.0)
	if "--script" in OS.get_cmdline_args():
		Lang.use("zh")
		return
	Lang.use(language)
	if "--wid" in OS.get_cmdline_args():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Full screen switched (F11, Alt+Enter), and kept.
static func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save()
