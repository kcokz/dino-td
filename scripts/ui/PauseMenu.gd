# res://scripts/ui/PauseMenu.gd
class_name PauseMenu
extends Control

## ESC menu for Defend Dinosaur v0.2.
##
## Two pages: the root menu (Resume / Settings / Quit) and a Settings page: the language,
## the window, the sound's volumes (Fx, Config.AUDIO), and the keys. Opening the menu pauses the game through
## GameState so the world stops behind it; closing restores whatever the pause
## state was before, so the menu never un-pauses a game the player had paused.

signal resumed()
signal quit_requested()
## "New game": the start screen, to choose what to play next (HUD.show_start_screen).
signal new_game_requested()

enum Page { ROOT = 0, SETTINGS = 1 }

var current_page: int = Page.ROOT
var is_open: bool = false

var centerer: CenterContainer = null
var panel: PanelContainer = null
var page_vbox: VBoxContainer = null
var title_label: Label = null
var resume_btn: Button = null
var settings_btn: Button = null
var new_game_btn: Button = null
var quit_btn: Button = null
var back_btn: Button = null
var language_row: HBoxContainer = null
var language_label: Label = null
var window_row: HBoxContainer = null
var camera_row: VBoxContainer = null
var camera_label: Label = null
var camera_keys_label: Label = null
var commands_label: Label = null
var command_keys_label: Label = null
var window_label: Label = null
var window_picker: OptionButton = null
## The sound (the player, 2026-10-03: "设置里加一个audio，可以调整音量"): a slider to each of the mix's buses
## (Fx.buses, Config.AUDIO), its name before it and its figure after.
var sound_row: VBoxContainer = null
var sound_label: Label = null
var volume_sliders: Dictionary = {}    # bus -> HSlider
var volume_names: Dictionary = {}      # bus -> Label
var volume_figures: Dictionary = {}    # bus -> Label
var language_picker: OptionButton = null
var version_caption: Label = null
## THE SETTINGS PAGE IN TWO TABS (the player, 2026-10-04: "Settings界面还不够专业，camera和command应该有单独的tab？每个tab应该
## 还能调整这些按键吧，按照专业游戏界面制作方式来，General，Key shortcut之类的两个tab"): General -- language, window, sound --
## and Keys -- every key the player can set (Config.KEY_BINDINGS, Keys), under the camera's heading and the card's, each
## set by clicking it and pressing the new key, and all of them back to Config's at once. One of a set, the tab chosen
## sunk and lit (SegmentButton), as the game's speeds are.
var tabs_row: HBoxContainer = null
var general_tab: Button = null
var keys_tab: Button = null
var general_box: VBoxContainer = null
var keys_scroll: ScrollContainer = null
var keys_box: VBoxContainer = null
var keys_reset_btn: Button = null
var key_buttons: Dictionary = {}       # Keys name -> its Button
var key_names: Dictionary = {}         # Keys name -> its Label
## "general" or "keys": the tab shown.
var settings_tab: String = "general"
## The key waiting for a press (its Keys name), or "".
var listening: String = ""

var _was_paused_before_open: bool = false
## Opened on its settings page alone -- from the start screen (open_settings_only): its "back" closes it.
var _settings_only: bool = false

func _init() -> void:
	name = "PauseMenu"
	visible = false
	# Open over a paused game, and answering (GameState.is_paused, the engine's pause).
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	if eb and is_instance_valid(eb) and eb.has_signal("keys_changed"):
		if eb.keys_changed.is_connected(_refresh_keys):
			eb.keys_changed.disconnect(_refresh_keys)

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("locale_changed"):
		if not eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.connect(_on_locale_changed)
	# A key set anew (Keys) -- here, or anywhere: the rows say so.
	if eb and eb.has_signal("keys_changed"):
		if not eb.keys_changed.is_connected(_refresh_keys):
			eb.keys_changed.connect(_refresh_keys)

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
	_show_volumes()
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
	_settings_only = false
	current_page = Page.ROOT
	# Only lift the pause the menu itself applied.
	var gs = _get_game_state()
	if gs and gs.has_method("set_paused") and not _was_paused_before_open:
		gs.set_paused(false)
	resumed.emit()

## Open, the menu is what the keys speak to: the number keys that press the card's commands
## (Config.CONTROLS.command_keys, BaseButton.shortcut) stop here, in front of the card -- the
## menu is later in the tree, so it hears them first. The cancel key goes on to close it.
func _shortcut_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	var keys: Array = Keys.command_keys()
	if keys.has(int((event as InputEventKey).keycode)):
		get_viewport().set_input_as_handled()

func open_settings() -> void:
	current_page = Page.SETTINGS
	_show_page()

## Open on the settings page alone, for the start screen: its "back" closes it, back to that screen.
func open_settings_only() -> void:
	open()
	_settings_only = true
	open_settings()

func back_to_root() -> void:
	current_page = Page.ROOT
	_show_page()

func _show_page() -> void:
	var root_page: bool = current_page == Page.ROOT
	if resume_btn: resume_btn.visible = root_page
	if settings_btn: settings_btn.visible = root_page
	if new_game_btn: new_game_btn.visible = root_page
	if quit_btn: quit_btn.visible = root_page
	if back_btn: back_btn.visible = not root_page
	# Settings only, in its two tabs. Leaving one off this list is why a row appeared on the main menu too -- every row
	# added to page_vbox shows on every page unless it is told otherwise.
	if tabs_row: tabs_row.visible = not root_page
	# The two tabs one height, the keys' list scrolling in it: the panel does not jump as the tab changes.
	if keys_scroll and general_box:
		keys_scroll.custom_minimum_size.y = general_box.get_combined_minimum_size().y
	if general_box: general_box.visible = not root_page and settings_tab == "general"
	if keys_scroll: keys_scroll.visible = not root_page and settings_tab == "keys"
	if general_tab: general_tab.set_pressed_no_signal(settings_tab == "general")
	if keys_tab: keys_tab.set_pressed_no_signal(settings_tab == "keys")
	if root_page or settings_tab != "keys":
		_stop_listening()
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
	if _settings_only:
		close()
		return
	back_to_root()

## A new game: the menu closes onto the start screen, the run still paused under it.
func _on_new_game_pressed() -> void:
	var gs = _get_game_state()
	_was_paused_before_open = true     # the start screen holds the pause now
	close()
	if gs and gs.has_method("set_paused"):
		gs.set_paused(true)
	new_game_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()
	if is_inside_tree():
		get_tree().quit()

## A volume moved: the bus set to it at once -- heard as it moves -- and remembered (Fx.set_volume).
func _on_volume_changed(value: float, bus: String) -> void:
	var fx = _autoload("Fx")
	if fx and fx.has_method("set_volume"):
		fx.set_volume(bus, int(round(value)))
	_show_figure(bus, int(round(value)))

## Each slider where its bus is (Fx.volume), without moving anything.
func _show_volumes() -> void:
	var fx = _autoload("Fx")
	for bus in volume_sliders:
		var at: int = int(fx.volume(String(bus))) if (fx and fx.has_method("volume")) else 100
		(volume_sliders[bus] as HSlider).set_value_no_signal(at)
		_show_figure(String(bus), at)

func _show_figure(bus: String, percent: int) -> void:
	var figure: Label = volume_figures.get(bus, null)
	if figure:
		figure.text = tr("MENU_VOLUME_PERCENT") % percent

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
		# The world behind the menu, frosted: stopped, still there, not competing.
		var dimmer := ColorRect.new()
		dimmer.name = "Dimmer"
		dimmer.material = UiTheme.frost_material()
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
		panel.theme_type_variation = &"ModalPanel"
		panel.custom_minimum_size = Vector2(_menu_width(), 0)
		centerer.add_child(panel)

	if page_vbox == null:
		page_vbox = find_child("PageVBox", true, false) as VBoxContainer
	if page_vbox == null:
		page_vbox = VBoxContainer.new()
		page_vbox.name = "PageVBox"
		page_vbox.add_theme_constant_override("separation", UiTheme.space("m"))
		panel.add_child(page_vbox)

	if title_label == null:
		title_label = Label.new()
		title_label.name = "MenuTitle"
		title_label.theme_type_variation = &"TitleLabel"
		title_label.uppercase = true     # cut in capitals, like the other titles
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page_vbox.add_child(title_label)
		var rule := HSeparator.new()
		rule.name = "TitleRule"
		rule.theme_type_variation = &"TitleRule"   # the rule under a title carries the tooth
		page_vbox.add_child(rule)

	resume_btn = _make_button(resume_btn, "ResumeBtn", _on_resume_pressed, &"AccentButton", "play")
	settings_btn = _make_button(settings_btn, "SettingsBtn", _on_settings_pressed)
	new_game_btn = _make_button(new_game_btn, "NewGameBtn", _on_new_game_pressed)
	quit_btn = _make_button(quit_btn, "QuitBtn", _on_quit_pressed, &"DangerButton")

	if tabs_row == null:
		tabs_row = HBoxContainer.new()
		tabs_row.name = "SettingsTabs"
		tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
		page_vbox.add_child(tabs_row)
		var group := ButtonGroup.new()
		general_tab = _tab("GeneralTab", group, "general")
		keys_tab = _tab("KeysTab", group, "keys")

	if general_box == null:
		general_box = VBoxContainer.new()
		general_box.name = "GeneralBox"
		general_box.add_theme_constant_override("separation", UiTheme.space("m"))
		page_vbox.add_child(general_box)

	if language_row == null:
		language_row = HBoxContainer.new()
		language_row.name = "LanguageRow"
		general_box.add_child(language_row)

		language_label = Label.new()
		language_label.name = "LanguageLabel"
		language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		language_row.add_child(language_label)

		language_picker = OptionButton.new()
		language_picker.name = "LanguagePicker"
		language_picker.custom_minimum_size = Vector2(_picker_width(), UiTheme.height("command"))
		language_row.add_child(language_picker)
		if not language_picker.item_selected.is_connected(_on_language_selected):
			language_picker.item_selected.connect(_on_language_selected)

	if window_row == null:
		window_row = HBoxContainer.new()
		window_row.name = "WindowRow"
		general_box.add_child(window_row)

		window_label = Label.new()
		window_label.name = "WindowLabel"
		window_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		window_row.add_child(window_label)

		window_picker = OptionButton.new()
		window_picker.name = "WindowPicker"
		window_picker.custom_minimum_size = Vector2(_picker_width(), UiTheme.height("command"))
		window_row.add_child(window_picker)
		if not window_picker.item_selected.is_connected(_on_window_mode_selected):
			window_picker.item_selected.connect(_on_window_mode_selected)

	if sound_row == null:
		sound_row = VBoxContainer.new()
		sound_row.name = "SoundRow"
		sound_row.add_theme_constant_override("separation", UiTheme.space("xs"))
		general_box.add_child(sound_row)
		sound_label = Label.new()
		sound_label.name = "SoundLabel"
		sound_row.add_child(sound_label)
		var fx = _autoload("Fx")
		var buses: Array = fx.buses() if (fx and fx.has_method("buses")) else []
		for bus in buses:
			var row := HBoxContainer.new()
			row.name = "Volume%s" % String(bus)
			sound_row.add_child(row)
			var bus_name := Label.new()
			bus_name.name = "Name"
			bus_name.theme_type_variation = &"MutedLabel"
			bus_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(bus_name)
			var slider := HSlider.new()
			slider.name = "Slider"
			slider.min_value = 0.0
			slider.max_value = 100.0
			slider.step = _volume_step()
			slider.custom_minimum_size = Vector2(_picker_width(), 0.0)
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(slider)
			var figure := Label.new()
			figure.name = "Figure"
			figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			figure.custom_minimum_size = Vector2(_volume_figure_width(), 0.0)
			row.add_child(figure)
			slider.value_changed.connect(_on_volume_changed.bind(String(bus)))
			volume_sliders[String(bus)] = slider
			volume_names[String(bus)] = bus_name
			volume_figures[String(bus)] = figure

	if keys_scroll == null:
		# The keys themselves, which is the only place the game tells anyone the view can be turned at all -- a control
		# nobody can find is a control nobody has -- and where each is set (Keys). It scrolls in the General tab's
		# height (_show_page), so the panel is one size whichever tab is open.
		keys_scroll = ScrollContainer.new()
		keys_scroll.name = "KeysScroll"
		keys_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		keys_scroll.custom_minimum_size = Vector2(0.0, 0.0)
		page_vbox.add_child(keys_scroll)
		keys_box = VBoxContainer.new()
		keys_box.name = "KeysBox"
		keys_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys_box.add_theme_constant_override("separation", UiTheme.space("xs"))
		keys_scroll.add_child(keys_box)
		camera_row = keys_box
		_build_key_rows()
		keys_reset_btn = Button.new()
		keys_reset_btn.name = "KeysResetBtn"
		keys_reset_btn.theme_type_variation = &"GhostButton"
		keys_reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		keys_reset_btn.pressed.connect(_on_keys_reset_pressed)
		keys_box.add_child(keys_reset_btn)

	back_btn = _make_button(back_btn, "BackBtn", _on_back_pressed, &"GhostButton", "back")

	if version_caption == null:
		version_caption = Label.new()
		version_caption.name = "VersionCaption"
		version_caption.theme_type_variation = &"CaptionLabel"
		version_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page_vbox.add_child(version_caption)
		version_caption.text = "%s  %s" % [AppInfo.APP_NAME, AppInfo.get_version()]
	_populate_languages()
	_populate_window_modes()

## A menu entry: full width, one height, styled by what it does -- the way back to the
## game lit in the accent, the way out of it in red.
func _make_button(existing: Button, node_name: String, cb: Callable, variation: StringName = &"", icon_name: String = "") -> Button:
	var btn: Button = existing
	if btn == null:
		btn = find_child(node_name, true, false) as Button
	if btn == null:
		btn = Button.new()
		btn.name = node_name
		btn.theme_type_variation = variation
		btn.custom_minimum_size = Vector2(0, UiTheme.height("command"))
		page_vbox.add_child(btn)
		_glyph(btn, icon_name)
	if not btn.pressed.is_connected(cb):
		btn.pressed.connect(cb)
	return btn

## A button's glyph -- Resume's play mark, Back's arrow -- set at its left end, apart from its words: as the button's own
## icon it took its width out of the middle, and Resume's word stood off to the right of the others' (the player,
## 2026-10-04: "resume和其他的按钮字体没对齐"). Its words are centred on the whole button, as every other's are.
func _glyph(btn: Button, icon_name: String) -> void:
	var tex: Texture2D = UiTheme.icon(icon_name)
	if tex == null:
		return
	var glyph := TextureRect.new()
	glyph.name = "Glyph"
	glyph.texture = tex
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: float = UiTheme.icon_size("s")
	glyph.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	glyph.offset_left = UiTheme.space("m")
	glyph.offset_right = glyph.offset_left + side
	glyph.offset_top = -side * 0.5
	glyph.offset_bottom = side * 0.5
	btn.add_child(glyph)

func _menu_width() -> float:
	var cfg = _get_config()
	return float(cfg.UI.get("menu_width", 400)) if (cfg and "UI" in cfg) else 400.0

func _picker_width() -> float:
	var cfg = _get_config()
	return float(cfg.UI.get("menu_picker_width", 190)) if (cfg and "UI" in cfg) else 190.0

func _volume_figure_width() -> float:
	var cfg = _get_config()
	return float(cfg.UI.get("menu_volume_figure_width", 56)) if (cfg and "UI" in cfg) else 56.0

func _volume_step() -> float:
	var cfg = _get_config()
	return float(cfg.AUDIO.get("step", 5)) if (cfg and "AUDIO" in cfg) else 5.0

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

## A tab of the settings page: one of a set (`group`), sunk and lit when it is the one shown.
func _tab(node_name: String, group: ButtonGroup, which: String) -> Button:
	var tab := Button.new()
	tab.name = node_name
	tab.theme_type_variation = &"SegmentButton"
	tab.toggle_mode = true
	tab.button_group = group
	tab.custom_minimum_size = Vector2(_picker_width() * 0.7, UiTheme.height("command"))
	tab.pressed.connect(func(): show_settings_tab(which))
	tabs_row.add_child(tab)
	return tab

## The settings page's tab `which`: "general" or "keys".
func show_settings_tab(which: String) -> void:
	settings_tab = which
	_show_page()

## Under each heading -- the camera's, the card's -- a row a key (Config.KEY_BINDINGS): what it does, and its key on a
## button; under each, what stays as it is (the mouse's; Esc).
func _build_key_rows() -> void:
	var cfg = _get_config()
	var rows: Array = cfg.KEY_BINDINGS if (cfg and "KEY_BINDINGS" in cfg) else []
	var heading: String = ""
	for i in rows.size():
		var row: Dictionary = rows[i]
		var group: String = String(row.get("group", ""))
		if group != heading:
			if heading == "camera":
				camera_keys_label = _caption("CameraKeysLabel")
			heading = group
			var header := Label.new()
			header.name = "Header_" + group
			keys_box.add_child(header)
			if group == "camera":
				camera_label = header
			else:
				commands_label = header
		var line := HBoxContainer.new()
		line.name = "KeyRow_" + String(row["name"])
		keys_box.add_child(line)
		var what := Label.new()
		what.name = "Name"
		what.theme_type_variation = &"MutedLabel"
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(what)
		var btn := Button.new()
		btn.name = "Key"
		btn.toggle_mode = true
		btn.theme_type_variation = &"SegmentButton"
		btn.custom_minimum_size = Vector2(_ui_number("menu_key_width", 130.0), 0.0)
		var key_name: String = String(row["name"])
		btn.pressed.connect(func(): _listen(key_name))
		line.add_child(btn)
		key_buttons[key_name] = btn
		key_names[key_name] = what
	if heading == "commands":
		command_keys_label = _caption("CommandKeysLabel")

func _caption(node_name: String) -> Label:
	var cap := Label.new()
	cap.name = node_name
	cap.theme_type_variation = &"CaptionLabel"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys_box.add_child(cap)
	return cap

## Each row's words and key: what it does (a command its place, from 1), the key it answers to now -- or, waiting for a
## press, saying so.
func _refresh_keys() -> void:
	var cfg = _get_config()
	var rows: Array = cfg.KEY_BINDINGS if (cfg and "KEY_BINDINGS" in cfg) else []
	for row in rows:
		var key_name: String = String(row["name"])
		var what: Label = key_names.get(key_name) as Label
		if what:
			var label: String = tr(String(row.get("label", key_name)))
			what.text = (label % int(key_name.substr(12))) if key_name.begins_with("command_key_") else label
		var btn: Button = key_buttons.get(key_name) as Button
		if btn:
			btn.text = tr("MENU_KEY_LISTEN") if listening == key_name else Keys.text(key_name)
			btn.tooltip_text = tr("MENU_KEY_TIP")
			btn.set_pressed_no_signal(listening == key_name)

## Clicked, a key's button waits for the next press (_input): that key is its, Esc keeps the one it had.
func _listen(key_name: String) -> void:
	listening = key_name
	_refresh_keys()
	# In sight in the list: the row it is.
	var btn: Button = key_buttons.get(key_name) as Button
	if btn and keys_scroll and keys_scroll.is_inside_tree():
		keys_scroll.ensure_control_visible(btn)

func _stop_listening() -> void:
	if listening != "":
		listening = ""
		_refresh_keys()

## Waiting for a key: the press is taken, before anything else hears it -- the card's keys, the menu's Esc.
func _input(event: InputEvent) -> void:
	if listening == "" or not is_open or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	var key_name: String = listening
	listening = ""
	if key_event.keycode != KEY_ESCAPE:
		Keys.bind(key_name, int(key_event.keycode))
	_refresh_keys()

## Every key back to Config's (Keys.reset), remembered.
func _on_keys_reset_pressed() -> void:
	listening = ""
	Keys.reset()
	_refresh_keys()

func _ui_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.UI.get(key, fallback)) if (cfg and "UI" in cfg) else fallback

## The details key as the keyboard writes it (Keys).
func _details_key_text() -> String:
	return Keys.text("details_key")

func _refresh_texts() -> void:
	if resume_btn: resume_btn.text = tr("MENU_RESUME")
	if settings_btn: settings_btn.text = tr("MENU_SETTINGS")
	if new_game_btn: new_game_btn.text = tr("MENU_NEW_GAME")
	if quit_btn: quit_btn.text = tr("MENU_QUIT")
	if back_btn: back_btn.text = tr("MENU_BACK")
	if language_label: language_label.text = tr("MENU_LANGUAGE")
	if window_label: window_label.text = tr("MENU_WINDOW_MODE")
	if sound_label: sound_label.text = tr("MENU_SOUND")
	for bus in volume_names:
		(volume_names[bus] as Label).text = tr("MENU_VOLUME_" + String(bus).to_upper())
	_show_volumes()
	if camera_label: camera_label.text = tr("MENU_CAMERA")
	if camera_keys_label: camera_keys_label.text = tr("MENU_CAMERA_KEYS")
	if commands_label: commands_label.text = tr("MENU_COMMANDS")
	if command_keys_label: command_keys_label.text = tr("MENU_COMMAND_KEYS")
	if general_tab: general_tab.text = tr("MENU_TAB_GENERAL")
	if keys_tab: keys_tab.text = tr("MENU_TAB_KEYS")
	if keys_reset_btn: keys_reset_btn.text = tr("MENU_KEYS_RESET")
	_refresh_keys()
	_populate_window_modes()
	if title_label:
		title_label.text = tr("MENU_TITLE") if current_page == Page.ROOT else tr("MENU_SETTINGS_TITLE")
	_populate_languages()

# ==============================================================================
# Resolvers
# ==============================================================================

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
