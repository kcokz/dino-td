class_name Settings
## What the player set (GAME-DESIGN 21), kept between runs in user://settings.cfg: full screen, the volume, the
## buttons' click, battles starting at the faster speed.

const PATH := "user://settings.cfg"

static var fullscreen := false
static var volume := 80                 # 0 to 100
static var clicks := true
static var fast := false                # a battle starts at the faster speed
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		fullscreen = bool(cf.get_value("screen", "fullscreen", false))
		volume = clampi(int(cf.get_value("sound", "volume", 80)), 0, 100)
		clicks = bool(cf.get_value("sound", "clicks", true))
		fast = bool(cf.get_value("play", "fast", false))
	apply()


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("screen", "fullscreen", fullscreen)
	cf.set_value("sound", "volume", volume)
	cf.set_value("sound", "clicks", clicks)
	cf.set_value("play", "fast", fast)
	cf.save(PATH)


## The settings put into effect -- the window left alone under a tool (playtest.gd) that sets its own.
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volume / 100.0) if volume > 0 else -80.0)
	if "--script" in OS.get_cmdline_args():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
