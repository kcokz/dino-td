# res://scripts/core/Keys.gd
class_name Keys
extends RefCounted

## THE PLAYER'S KEYS (the player, 2026-10-04: "Settings界面还不够专业，camera和command应该有单独的tab？每个tab应该还能调整
## 这些按键吧，按照专业游戏界面制作方式来，General，Key shortcut之类的两个tab"): the key each thing the keyboard does
## answers to -- the camera's, the card's -- is Config.CONTROLS's, or the one the player set on the settings page's Keys
## tab (PauseMenu), kept in the settings file (section "keys"; I18n.SETTINGS_PATH) and read back at the next start.
## Everything that reads a key reads it here (Main, HeroCommands, OptionPanel, PauseMenu, HUD); what can be set is
## Config.KEY_BINDINGS. The mouse's buttons and Esc stay as they are.
##
## A key taken from another thing gives that thing the key it had (bind): nothing is ever left on no key, and no key
## does two things -- but the two Config.KEY_BINDINGS says share one, which are never both live (the camera's reset and
## the placement's turn: R).

const SECTION: String = "keys"

## What the player set: {name: keycode}. Read from the settings file the first time a key is asked for.
static var _bound: Dictionary = {}
static var _loaded: bool = false
## Whether a change is written to the settings file: off for the tests (tests/test_runner.gd), which must leave the
## player's file as they found it.
static var saves: bool = true

## The key `name` (a Config.CONTROLS key: "camera_reset_key", "details_key", "command_key_3") answers to now.
static func key(name: String) -> int:
	_load()
	if _bound.has(name):
		return int(_bound[name])
	return default_key(name)

## Its key as Config.CONTROLS has it: "command_key_<n>" the n'th of command_keys (from 1).
static func default_key(name: String) -> int:
	var cfg: Node = _config()
	if cfg == null or not ("CONTROLS" in cfg):
		return 0
	if name.begins_with("command_key_"):
		var keys: Array = cfg.CONTROLS.get("command_keys", [])
		var at: int = int(name.substr(12)) - 1
		return int(keys[at]) if at >= 0 and at < keys.size() else 0
	return int(cfg.CONTROLS.get(name, 0))

## The card's command keys, in order (Config.CONTROLS.command_keys, as the player set them).
static func command_keys() -> Array:
	var cfg: Node = _config()
	var n: int = (cfg.CONTROLS.get("command_keys", []) as Array).size() if (cfg and "CONTROLS" in cfg) else 0
	var out: Array = []
	for i in n:
		out.append(key("command_key_%d" % (i + 1)))
	return out

## Its key as the keyboard writes it: "W", "Space", "1".
static func text(name: String) -> String:
	return OS.get_keycode_string(key(name))

## Every name the settings page lists (Config.KEY_BINDINGS), in its order.
static func names() -> Array[String]:
	var out: Array[String] = []
	var cfg: Node = _config()
	if cfg == null or not ("KEY_BINDINGS" in cfg):
		return out
	for row in cfg.KEY_BINDINGS:
		out.append(String(row["name"]))
	return out

## Sets `name` to `keycode`. Another thing on that key gets the key `name` had (a swap), unless the two are set to
## share one (Config.KEY_BINDINGS "shares"). Returns the name of what was given the old key, or "". Remembered in the
## settings file, unless `remember` is false or the tests are running (saves).
static func bind(name: String, keycode: int, remember: bool = true) -> String:
	_load()
	var was: int = key(name)
	if keycode == was or keycode == 0:
		return ""
	var swapped: String = ""
	for other in names():
		if other == name or key(other) != keycode or _share(name, other):
			continue
		_put(other, was)
		swapped = other
	_put(name, keycode)
	if remember:
		_save()
	_tell()
	return swapped

## Every key back to Config.CONTROLS's.
static func reset(remember: bool = true) -> void:
	_bound.clear()
	_loaded = true
	if remember:
		_save()
	_tell()

## Whether `a` and `b` may stand on one key (Config.KEY_BINDINGS "shares": never both live at once).
static func _share(a: String, b: String) -> bool:
	var cfg: Node = _config()
	if cfg == null or not ("KEY_BINDINGS" in cfg):
		return false
	for row in cfg.KEY_BINDINGS:
		if (String(row["name"]) == a and String(row.get("shares", "")) == b) or (String(row["name"]) == b and String(row.get("shares", "")) == a):
			return true
	return false

static func _put(name: String, keycode: int) -> void:
	if keycode == default_key(name):
		_bound.erase(name)
	else:
		_bound[name] = keycode

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(_path()) != OK or not file.has_section(SECTION):
		return
	for name in file.get_section_keys(SECTION):
		_bound[String(name)] = int(file.get_value(SECTION, name, 0))

static func _save() -> void:
	if not saves:
		return
	var file := ConfigFile.new()
	file.load(_path())          # what else the file holds, kept
	if file.has_section(SECTION):
		file.erase_section(SECTION)
	for name in _bound:
		file.set_value(SECTION, String(name), int(_bound[name]))
	file.save(_path())

static func _path() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var i18n: Node = tree.root.get_node_or_null("I18n") if tree else null
	return String(i18n.SETTINGS_PATH) if (i18n and "SETTINGS_PATH" in i18n) else "user://settings.cfg"

## Everything wearing a key is told (EventBus.keys_changed): the card's keycaps, the medallions' chips.
static func _tell() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var eb: Node = tree.root.get_node_or_null("EventBus") if tree else null
	if eb and eb.has_signal("keys_changed"):
		eb.keys_changed.emit()

static func _config() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Config") if tree else null
