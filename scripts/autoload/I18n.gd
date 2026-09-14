# res://scripts/autoload/I18n.gd
extends Node

## Internationalization & Localization Manager for Defend Dinosaur.
## Houses translation table loading, locale switching, and preference persistence.
## English ('en') is the default and fallback locale; 'zh_CN' is fully supported.

const SETTINGS_PATH: String = "user://settings.cfg"
const CSV_PATH: String = "res://translations/strings.csv"
const DEFAULT_LOCALE: String = "en"
const SUPPORTED_LOCALES: Array[String] = ["en", "zh_CN"]

var current_locale: String = DEFAULT_LOCALE

func _ready() -> void:
	load_translations()
	var saved_locale = load_saved_locale()
	set_locale(saved_locale)

## Reads strings.csv and builds runtime Translation resources registered to TranslationServer.
func load_translations() -> void:
	if not FileAccess.file_exists(CSV_PATH):
		push_warning("[I18n] CSV translation file not found at: %s" % CSV_PATH)
		return

	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("[I18n] Failed to open translation CSV at: %s" % CSV_PATH)
		return

	# Header: id,en,zh_CN
	var headers = file.get_csv_line()
	if headers.size() < 3:
		push_error("[I18n] Invalid CSV header format")
		return

	var trans_en = Translation.new()
	trans_en.locale = "en"

	var trans_zh = Translation.new()
	trans_zh.locale = "zh_CN"

	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 3:
			continue
		var key = row[0].strip_edges()
		if key.is_empty():
			continue
		var en_val = row[1]
		var zh_val = row[2]

		trans_en.add_message(key, en_val)
		trans_zh.add_message(key, zh_val)

	TranslationServer.add_translation(trans_en)
	TranslationServer.add_translation(trans_zh)
	TranslationServer.set_locale(current_locale)

func get_current_locale() -> String:
	return current_locale

## Returns list of supported locale codes.
static func get_supported_locales() -> Array[String]:
	return SUPPORTED_LOCALES.duplicate()

## Returns user-facing label for a locale code.
static func get_locale_display_name(loc: String) -> String:
	match loc:
		"en":
			return "English"
		"zh_CN", "zh":
			return "简体中文"
		_:
			return loc

## Changes the active locale, saves to settings, and emits signal.
func set_locale(new_locale: String) -> void:
	var target = new_locale
	if target == "zh":
		target = "zh_CN"
	if not (target in SUPPORTED_LOCALES):
		target = DEFAULT_LOCALE

	current_locale = target
	TranslationServer.set_locale(target)
	save_saved_locale(target)

	var eb = _get_event_bus()
	if eb and eb.has_signal("locale_changed"):
		eb.locale_changed.emit(target)

## Returns current active locale.
func get_locale() -> String:
	return current_locale

## Loads user preference from disk.
func load_saved_locale() -> String:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_PATH)
	if err == OK:
		var saved = cfg.get_value("localization", "locale", DEFAULT_LOCALE)
		if saved in SUPPORTED_LOCALES or saved == "zh":
			return "zh_CN" if saved == "zh" else saved
	return DEFAULT_LOCALE

## Saves user preference to disk.
func save_saved_locale(loc: String) -> void:
	var cfg = ConfigFile.new()
	var _err = cfg.load(SETTINGS_PATH) # OK if doesn't exist yet
	cfg.set_value("localization", "locale", loc)
	cfg.save(SETTINGS_PATH)

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("EventBus")
	return null
