# res://scripts/ui/PauseMenu.gd
class_name PauseMenu
extends Control

## ESC menu for Defend Dinosaur v0.2.
##
## Two pages: the root menu (Resume / Settings / Quit) and a Settings page that
## currently holds the language picker. Opening the menu pauses the game through
## GameState so the world stops behind it; closing restores whatever the pause
## state was before, so the menu never un-pauses a game the player had paused.

signal resumed()
signal quit_requested()

enum Page { ROOT = 0, SETTINGS = 1 }

var current_page: int = Page.ROOT
var is_open: bool = false

var centerer: CenterContainer = null
var panel: PanelContainer = null
var page_vbox: VBoxContainer = null
var title_label: Label = null
var resume_btn: Button = null
var settings_btn: Button = null
var quit_btn: Button = null
var back_btn: Button = null
var language_row: HBoxContainer = null
var language_label: Label = null
var window_row: HBoxContainer = null
var camera_row: VBoxContainer = null
var camera_label: Label = null
var camera_keys_label: Label = null
var window_label: Label = null
var window_picker: OptionButton = null
var language_picker: OptionButton = null

var _was_paused_before_open: bool = false

func _init() -> void:
	name = "PauseMenu"
	visible = false

func _ready() -> void:
	_ensure_components()
	_connect_event_bus()
	_refresh_texts()
	close()

func _exit_tree() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("locale_changed"):
		if eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.disconnect(_on_locale_changed)

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("locale_changed"):
		if not eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()

# ==============================================================================
# Open / close
# ==============================================================================

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	_ensure_components()
	is_open = true
	visible = true
	current_page = Page.ROOT
	var gs = _get_game_state()
	if gs:
		_was_paused_before_open = bool(gs.is_paused) if "is_paused" in gs else false
		if gs.has_method("set_paused"):
			gs.set_paused(true)
	_refresh_texts()
	_show_page()

func close() -> void:
	is_open = false
	visible = false
	current_page = Page.ROOT
	# Only lift the pause the menu itself applied.
	var gs = _get_game_state()
	if gs and gs.has_method("set_paused") and not _was_paused_before_open:
		gs.set_paused(false)
	resumed.emit()

func open_settings() -> void:
	current_page = Page.SETTINGS
	_show_page()

func back_to_root() -> void:
	current_page = Page.ROOT
	_show_page()

func _show_page() -> void:
	var root_page: bool = current_page == Page.ROOT
	if resume_btn: resume_btn.visible = root_page
	if settings_btn: settings_btn.visible = root_page
	if quit_btn: quit_btn.visible = root_page
	if back_btn: back_btn.visible = not root_page
	if language_row: language_row.visible = not root_page
	# Settings only. Leaving it off this list is why it appeared on the main menu too --
	# every row added to page_vbox shows on every page unless it is told otherwise.
	if window_row: window_row.visible = not root_page
	if camera_row: camera_row.visible = not root_page
	if title_label:
		title_label.text = tr("MENU_TITLE") if root_page else tr("MENU_SETTINGS_TITLE")

# ==============================================================================
# Actions
# ==============================================================================

func _on_resume_pressed() -> void:
	close()

func _on_settings_pressed() -> void:
	open_settings()

func _on_back_pressed() -> void:
	back_to_root()

func _on_quit_pressed() -> void:
	quit_requested.emit()
	if is_inside_tree():
		get_tree().quit()

func _on_language_selected(index: int) -> void:
	if language_picker == null:
		return
	var loc: String = String(language_picker.get_item_metadata(index))
	var i18n = _get_i18n()
	if i18n and i18n.has_method("set_locale"):
		i18n.set_locale(loc)

# ==============================================================================
# Construction
# ==============================================================================

func _ensure_components() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if find_child("Dimmer", true, false) == null:
		var dimmer := ColorRect.new()
		dimmer.name = "Dimmer"
		dimmer.color = Color(0.0, 0.0, 0.0, 0.55)
		dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dimmer)

	# A CenterContainer that fills the screen keeps the panel in the middle at any
	# resolution; anchoring the panel itself leaves it pinned to a corner whenever
	# its size is decided after layout.
	if centerer == null:
		centerer = find_child("Centerer", true, false) as CenterContainer
	if centerer == null:
		centerer = CenterContainer.new()
		centerer.name = "Centerer"
		centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		centerer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(centerer)

	if panel == null:
		panel = find_child("MenuPanel", true, false) as PanelContainer
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "MenuPanel"
		panel.custom_minimum_size = Vector2(360, 260)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.1, 0.13, 0.96)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.35, 0.45, 0.55, 0.9)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 20
		style.content_margin_bottom = 20
		panel.add_theme_stylebox_override("panel", style)
		centerer.add_child(panel)

	if page_vbox == null:
		page_vbox = find_child("PageVBox", true, false) as VBoxContainer
	if page_vbox == null:
		page_vbox = VBoxContainer.new()
		page_vbox.name = "PageVBox"
		page_vbox.add_theme_constant_override("separation", 12)
		panel.add_child(page_vbox)

	if title_label == null:
		title_label = Label.new()
		title_label.name = "MenuTitle"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", _ui_size("gameover_title_font_size", 40))
		page_vbox.add_child(title_label)

	resume_btn = _make_button(resume_btn, "ResumeBtn", _on_resume_pressed)
	settings_btn = _make_button(settings_btn, "SettingsBtn", _on_settings_pressed)
	quit_btn = _make_button(quit_btn, "QuitBtn", _on_quit_pressed)

	if language_row == null:
		language_row = HBoxContainer.new()
		language_row.name = "LanguageRow"
		language_row.add_theme_constant_override("separation", 10)
		page_vbox.add_child(language_row)

		language_label = Label.new()
		language_label.name = "LanguageLabel"
		language_label.add_theme_font_size_override("font_size", _ui_size("hud_font_size", 20))
		language_row.add_child(language_label)

		language_picker = OptionButton.new()
		language_picker.name = "LanguagePicker"
		language_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		language_picker.add_theme_font_size_override("font_size", _ui_size("hud_button_font_size", 18))
		language_row.add_child(language_picker)
		if not language_picker.item_selected.is_connected(_on_language_selected):
			language_picker.item_selected.connect(_on_language_selected)

	if window_row == null:
		window_row = HBoxContainer.new()
		window_row.name = "WindowRow"
		window_row.add_theme_constant_override("separation", 10)
		page_vbox.add_child(window_row)

		window_label = Label.new()
		window_label.name = "WindowLabel"
		window_label.add_theme_font_size_override("font_size", _ui_size("hud_font_size", 20))
		window_row.add_child(window_label)

		window_picker = OptionButton.new()
		window_picker.name = "WindowPicker"
		window_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		window_picker.add_theme_font_size_override("font_size", _ui_size("hud_button_font_size", 18))
		window_row.add_child(window_picker)
		if not window_picker.item_selected.is_connected(_on_window_mode_selected):
			window_picker.item_selected.connect(_on_window_mode_selected)

	if camera_row == null:
		camera_row = VBoxContainer.new()
		camera_row.name = "CameraRow"
		page_vbox.add_child(camera_row)

		camera_label = Label.new()
		camera_label.name = "CameraLabel"
		camera_label.add_theme_font_size_override("font_size", _ui_size("hud_font_size", 20))
		camera_row.add_child(camera_label)

		# The keys themselves, which is the only place the game tells anyone the view can
		# be turned at all. A control nobody can find is a control nobody has.
		camera_keys_label = Label.new()
		camera_keys_label.name = "CameraKeysLabel"
		camera_keys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		camera_keys_label.add_theme_font_size_override("font_size", _ui_size("hud_button_font_size", 18))
		camera_row.add_child(camera_keys_label)

	back_btn = _make_button(back_btn, "BackBtn", _on_back_pressed)
	_populate_languages()
	_populate_window_modes()

func _make_button(existing: Button, node_name: String, cb: Callable) -> Button:
	var btn: Button = existing
	if btn == null:
		btn = find_child(node_name, true, false) as Button
	if btn == null:
		btn = Button.new()
		btn.name = node_name
		btn.custom_minimum_size = Vector2(0, _ui_size("hud_button_font_size", 18) * 2.2)
		btn.add_theme_font_size_override("font_size", _ui_size("hud_button_font_size", 18))
		page_vbox.add_child(btn)
	if not btn.pressed.is_connected(cb):
		btn.pressed.connect(cb)
	return btn

## Fullscreen or windowed. Index 0 is fullscreen, 1 is windowed -- the order is fixed
## rather than derived, because there are exactly two and they are not going to grow.
func _populate_window_modes() -> void:
	if window_picker == null:
		return
	var wm := get_node_or_null("/root/WindowMode")
	window_picker.clear()
	window_picker.add_item(tr("MENU_WINDOW_FULLSCREEN"), 0)
	window_picker.add_item(tr("MENU_WINDOW_WINDOWED"), 1)
	if wm and wm.has_method("is_fullscreen"):
		window_picker.select(0 if wm.is_fullscreen() else 1)

func _on_window_mode_selected(index: int) -> void:
	var wm := get_node_or_null("/root/WindowMode")
	if wm and wm.has_method("set_fullscreen"):
		wm.set_fullscreen(index == 0)

func _populate_languages() -> void:
	if language_picker == null:
		return
	var i18n = _get_i18n()
	var locales: Array = ["en", "zh_CN"]
	if i18n and i18n.has_method("get_supported_locales"):
		locales = i18n.get_supported_locales()
	var current: String = "en"
	if i18n and i18n.has_method("get_current_locale"):
		current = String(i18n.get_current_locale())

	language_picker.clear()
	for i in range(locales.size()):
		var loc: String = String(locales[i])
		var label: String = loc
		if i18n and i18n.has_method("get_locale_display_name"):
			label = String(i18n.get_locale_display_name(loc))
		language_picker.add_item(label, i)
		language_picker.set_item_metadata(i, loc)
		if loc == current:
			language_picker.select(i)

func _refresh_texts() -> void:
	if resume_btn: resume_btn.text = tr("MENU_RESUME")
	if settings_btn: settings_btn.text = tr("MENU_SETTINGS")
	if quit_btn: quit_btn.text = tr("MENU_QUIT")
	if back_btn: back_btn.text = tr("MENU_BACK")
	if language_label: language_label.text = tr("MENU_LANGUAGE")
	if window_label: window_label.text = tr("MENU_WINDOW_MODE")
	if camera_label: camera_label.text = tr("MENU_CAMERA")
	if camera_keys_label: camera_keys_label.text = tr("MENU_CAMERA_KEYS")
	_populate_window_modes()
	if title_label:
		title_label.text = tr("MENU_TITLE") if current_page == Page.ROOT else tr("MENU_SETTINGS_TITLE")
	_populate_languages()

# ==============================================================================
# Resolvers
# ==============================================================================

func _ui_size(key: String, fallback: int) -> int:
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		return int(cfg.UI.get(key, fallback))
	return fallback

func _get_config() -> Node:
	return _autoload("Config")

func _get_game_state() -> Node:
	return _autoload("GameState")

func _get_event_bus() -> Node:
	return _autoload("EventBus")

func _get_i18n() -> Node:
	return _autoload("I18n")

func _autoload(n: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/" + n)
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null(n)
	return null
