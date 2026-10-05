# res://scripts/ui/StartScreen.gd
class_name StartScreen
extends Control

## THE START SCREEN (GAME-DESIGN 11; the player, 2026-09-30: "v0.6还有自定义地图机制没做呢……玩家就能选这些参数自定义
## 游戏"; chosen: "启动时先出开始界面"). Over the valley, stopped behind frosted glass: what to play --
##   OUR GAME        station 1, the Late Triassic valley, the beacon to mend (Config.GAMES.campaign)
##   A CUSTOM GAME   its own page: every setting of Config.CUSTOM_GAME a row -- its name, its choices, what the one
##                   chosen does -- and the seed; the whole cabin, the beacon calling, rescue after the days chosen
##   SETTINGS, QUIT  the pause menu's settings page; out
## The game launched opens on it (Main); "new game" in the pause menu brings it back (HUD.show_start_screen).
## Choosing plays the game from a fresh level (GameState.play, then the scene built afresh, straight in) -- except
## our game on the level the launch has just built for it, which is simply let go.
## The custom game's last choices are kept (I18n's settings file, "custom"), so it opens as it was left.

signal chosen(game_id: String)

enum Page { TITLE = 0, CUSTOM = 1 }

var current_page: int = Page.TITLE
## Whether the level under it is fresh -- just built for our game at the launch -- so playing it needs no new one.
var fresh_level: bool = false

var _title_box: VBoxContainer = null
var _custom_box: VBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
## Play on from the save (SaveGame), first and lit while there is one; under it its day and when it was saved.
var continue_btn: Button = null
var _continue_note: Label = null
var campaign_btn: Button = null
var custom_btn: Button = null
var settings_btn: Button = null
var quit_btn: Button = null
var _campaign_note: Label = null
var _custom_note: Label = null
var _custom_title: Label = null
var start_btn: Button = null
var back_btn: Button = null
var seed_edit: LineEdit = null
var _seed_label: Label = null
var _seed_note: Label = null
## A setting's row: its picker (OptionButton, the choices in Config's order) and the note under it.
var pickers: Dictionary = {}
var _names: Dictionary = {}
var _notes: Dictionary = {}

func _init() -> void:
	name = "StartScreen"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build()
	_connect_event_bus()
	_refresh_texts()

func _exit_tree() -> void:
	var eb = _autoload("EventBus")
	if eb and eb.has_signal("locale_changed") and eb.locale_changed.is_connected(_on_locale_changed):
		eb.locale_changed.disconnect(_on_locale_changed)

func _connect_event_bus() -> void:
	var eb = _autoload("EventBus")
	if eb and eb.has_signal("locale_changed") and not eb.locale_changed.is_connected(_on_locale_changed):
		eb.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()

# ==============================================================================
# Open / close
# ==============================================================================

## Shows it over the stopped valley: `fresh`, the level under it was just built for our game (the launch).
func open(fresh: bool = false) -> void:
	_build()
	fresh_level = fresh
	visible = true
	current_page = Page.TITLE
	var gs = _autoload("GameState")
	if gs and gs.has_method("set_paused"):
		gs.set_paused(true)
	# The valley's sound goes on under it: the game is held for the screen, not by the player (Fx.play_through_pause).
	var fx = _autoload("Fx")
	if fx and fx.has_method("play_through_pause"):
		fx.play_through_pause(self, true)
	_refresh_texts()
	_show_page()

func close() -> void:
	visible = false
	var fx = _autoload("Fx")
	if fx and fx.has_method("play_through_pause"):
		fx.play_through_pause(self, false)

func show_custom() -> void:
	current_page = Page.CUSTOM
	_load_choices()
	_show_page()

func show_title() -> void:
	current_page = Page.TITLE
	_show_page()

func _show_page() -> void:
	# A page's whole panel, not only what is in it: an empty frame stood where the other page was.
	if _title_box:
		(_title_box.get_parent() as Control).visible = current_page == Page.TITLE
	if _custom_box:
		(_custom_box.get_parent() as Control).visible = current_page == Page.CUSTOM

# ==============================================================================
# Choosing
# ==============================================================================

## Continue there while there is a save, with its day and when it was saved -- the one thing lit; our game, plain.
func _refresh_continue() -> void:
	if continue_btn == null:
		return
	var saved: Dictionary = SaveGame.read()
	continue_btn.visible = not saved.is_empty()
	_continue_note.visible = continue_btn.visible
	if not saved.is_empty():
		var stamp: String = String(saved.get("saved_at", ""))
		_continue_note.text = tr("SAVE_CAPTION") % [int(saved.get("day", 1)), stamp.substr(5, 11) if stamp.length() >= 16 else stamp]
	campaign_btn.theme_type_variation = &"" if continue_btn.visible else &"AccentButton"

## On from the save (SaveGame.continue_game): its game, its seed, the level built afresh and the run laid over it.
func continue_game() -> void:
	close()
	chosen.emit(String(SaveGame.read().get("game", {}).get("id", "campaign")))
	SaveGame.continue_game(get_tree() if is_inside_tree() else null)

## Our game: the level under it played as it is when the launch has just built it for our game; else a fresh one.
func play_campaign() -> void:
	var gs = _autoload("GameState")
	if gs == null:
		return
	if fresh_level and String(gs.game_id()) == "campaign":
		close()
		if gs.has_method("set_paused"):
			gs.set_paused(false)
		chosen.emit("campaign")
		# And it opens on how it began (Main.open_on_the_crash): the capsule's fall into the valley.
		var level: Node = get_tree().current_scene if is_inside_tree() else null
		if level != null and level.has_method("open_on_the_crash"):
			level.open_on_the_crash()
		return
	gs.play("campaign")
	chosen.emit("campaign")
	_start_afresh()

## The custom game, as its page is set: remembered, and played from a fresh level.
func play_custom() -> void:
	var gs = _autoload("GameState")
	if gs == null:
		return
	var picks: Dictionary = current_choices()
	_save_choices(picks)
	gs.play("custom", picks, seed_value())
	chosen.emit("custom")
	_start_afresh()

## Every setting's choice as the page shows it (setting id -> choice id).
func current_choices() -> Dictionary:
	var out: Dictionary = {}
	var cfg = _autoload("Config")
	if cfg == null:
		return out
	for s in cfg.CUSTOM_GAME["settings"]:
		var id: String = String(s["id"])
		var picker: OptionButton = pickers.get(id)
		if picker != null and picker.selected >= 0:
			out[id] = String(picker.get_item_metadata(picker.selected))
		else:
			out[id] = String(s.get("default", ""))
	return out

## The seed the page was given: a whole number, or -1 for none -- a new one each run.
func seed_value() -> int:
	if seed_edit == null:
		return -1
	var text: String = seed_edit.text.strip_edges()
	return int(text) if text.is_valid_int() and int(text) >= 0 else -1

## The game chosen is played from a level built afresh for it, straight in -- no start screen on it
## (GameState.launch_straight_in).
func _start_afresh() -> void:
	var gs = _autoload("GameState")
	if gs:
		gs.launch_straight_in = true
	# The game's own scene, built afresh; a level a script built (a test) has none to build again.
	if is_inside_tree() and get_tree().current_scene != null:
		get_tree().reload_current_scene()

# ==============================================================================
# The custom game's choices, kept
# ==============================================================================

func _load_choices() -> void:
	var cfg = _autoload("Config")
	var i18n = _autoload("I18n")
	if cfg == null:
		return
	for s in cfg.CUSTOM_GAME["settings"]:
		var id: String = String(s["id"])
		var picker: OptionButton = pickers.get(id)
		if picker == null:
			continue
		var want: String = String(s.get("default", ""))
		if i18n and i18n.has_method("load_setting"):
			want = String(i18n.load_setting("custom", id, want))
		for i in picker.item_count:
			if String(picker.get_item_metadata(i)) == want:
				picker.select(i)
		_show_note(id)
	if seed_edit and i18n and i18n.has_method("load_setting"):
		seed_edit.text = String(i18n.load_setting("custom", "seed", ""))

func _save_choices(picks: Dictionary) -> void:
	var i18n = _autoload("I18n")
	if i18n == null or not i18n.has_method("save_setting"):
		return
	for id in picks:
		i18n.save_setting("custom", String(id), String(picks[id]))
	if seed_edit:
		i18n.save_setting("custom", "seed", seed_edit.text.strip_edges())

# ==============================================================================
# Building it
# ==============================================================================

func _build() -> void:
	if _title_box != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The valley behind, stopped and frosted.
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.material = UiTheme.frost_material()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)
	var centerer := CenterContainer.new()
	centerer.name = "Centerer"
	centerer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centerer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centerer)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	centerer.add_child(stack)

	# THE TITLE PAGE.
	var title_panel := PanelContainer.new()
	title_panel.name = "TitlePanel"
	title_panel.theme_type_variation = &"ModalPanel"
	title_panel.custom_minimum_size = Vector2(_ui("start_width", 460.0), 0)
	stack.add_child(title_panel)
	_title_box = VBoxContainer.new()
	_title_box.name = "TitlePage"
	_title_box.add_theme_constant_override("separation", UiTheme.space("m"))
	title_panel.add_child(_title_box)
	_title_label = _label("GameTitle", &"TitleLabel", _title_box)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := HSeparator.new()
	rule.theme_type_variation = &"TitleRule"
	_title_box.add_child(rule)
	_subtitle_label = _label("Subtitle", &"MutedLabel", _title_box)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continue_btn = _button("ContinueBtn", continue_game, &"AccentButton", "play", _title_box)
	_continue_note = _label("ContinueNote", &"CaptionLabel", _title_box)
	campaign_btn = _button("CampaignBtn", play_campaign, &"AccentButton", "play", _title_box)
	_campaign_note = _label("CampaignNote", &"CaptionLabel", _title_box)
	_campaign_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	custom_btn = _button("CustomBtn", show_custom, &"", "", _title_box)
	_custom_note = _label("CustomNote", &"CaptionLabel", _title_box)
	_custom_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_btn = _button("StartSettingsBtn", _open_settings, &"", "", _title_box)
	quit_btn = _button("StartQuitBtn", _quit, &"DangerButton", "", _title_box)

	# THE CUSTOM GAME'S PAGE: a row a setting, scrolling when the window is short.
	var custom_panel := PanelContainer.new()
	custom_panel.name = "CustomPanel"
	custom_panel.theme_type_variation = &"ModalPanel"
	custom_panel.custom_minimum_size = Vector2(_ui("custom_width", 560.0), 0)
	stack.add_child(custom_panel)
	_custom_box = VBoxContainer.new()
	_custom_box.name = "CustomPage"
	_custom_box.add_theme_constant_override("separation", UiTheme.space("s"))
	custom_panel.add_child(_custom_box)
	_custom_title = _label("CustomTitle", &"TitleLabel", _custom_box)
	_custom_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule2 := HSeparator.new()
	rule2.theme_type_variation = &"TitleRule"
	_custom_box.add_child(rule2)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, _ui("custom_height", 440.0))
	_custom_box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "SettingsRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", UiTheme.space("s"))
	scroll.add_child(rows)
	var cfg = _autoload("Config")
	if cfg:
		for s in cfg.CUSTOM_GAME["settings"]:
			_setting_row(s, rows)
	# The seed: a number, or none.
	var seed_row := VBoxContainer.new()
	seed_row.name = "SeedRow"
	seed_row.add_theme_constant_override("separation", UiTheme.space("hair"))
	rows.add_child(seed_row)
	var line := HBoxContainer.new()
	seed_row.add_child(line)
	_seed_label = _label("SeedLabel", &"", line)
	_seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit = LineEdit.new()
	seed_edit.name = "SeedEdit"
	seed_edit.custom_minimum_size = Vector2(_ui("menu_picker_width", 190.0), UiTheme.height("command"))
	line.add_child(seed_edit)
	_seed_note = _label("SeedNote", &"MutedLabel", seed_row)
	_seed_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	buttons.name = "CustomButtons"
	buttons.add_theme_constant_override("separation", UiTheme.space("m"))
	_custom_box.add_child(buttons)
	back_btn = _button("CustomBackBtn", show_title, &"GhostButton", "back", buttons)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn = _button("CustomStartBtn", play_custom, &"AccentButton", "play", buttons)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_show_page()

## A setting's row: its name and its picker on one line, what the choice does under them.
func _setting_row(s: Dictionary, parent: Control) -> void:
	var id: String = String(s["id"])
	var row := VBoxContainer.new()
	row.name = "Row_" + id
	row.add_theme_constant_override("separation", UiTheme.space("hair"))
	parent.add_child(row)
	var line := HBoxContainer.new()
	row.add_child(line)
	var name_label := _label("Name_" + id, &"", line)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var picker := OptionButton.new()
	picker.name = "Picker_" + id
	picker.custom_minimum_size = Vector2(_ui("menu_picker_width", 190.0), UiTheme.height("command"))
	line.add_child(picker)
	picker.item_selected.connect(func(_i: int) -> void: _show_note(id))
	var note := _label("Note_" + id, &"MutedLabel", row)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pickers[id] = picker
	_names[id] = name_label
	_notes[id] = note

## What the choice picked for setting `id` does, under its row -- nothing for one that says nothing.
func _show_note(id: String) -> void:
	var cfg = _autoload("Config")
	var picker: OptionButton = pickers.get(id)
	var note: Label = _notes.get(id)
	if cfg == null or picker == null or note == null or picker.selected < 0:
		return
	var choice: Dictionary = cfg.custom_choice(id, String(picker.get_item_metadata(picker.selected)))
	var key: String = String(choice.get("note", ""))
	note.text = tr(key) if key != "" else ""
	note.visible = key != ""

func _refresh_texts() -> void:
	if _title_box == null:
		return
	_title_label.text = tr("START_TITLE")
	_subtitle_label.text = tr("START_SUBTITLE")
	continue_btn.text = tr("MENU_CONTINUE")
	_refresh_continue()
	campaign_btn.text = tr("START_CAMPAIGN")
	_campaign_note.text = tr("START_CAMPAIGN_NOTE")
	custom_btn.text = tr("START_CUSTOM")
	_custom_note.text = tr("START_CUSTOM_NOTE")
	settings_btn.text = tr("MENU_SETTINGS")
	quit_btn.text = tr("MENU_QUIT")
	_custom_title.text = tr("CUSTOM_TITLE")
	back_btn.text = tr("MENU_BACK")
	start_btn.text = tr("CUSTOM_START")
	_seed_label.text = tr("CUSTOM_SEED")
	seed_edit.placeholder_text = tr("CUSTOM_SEED_RANDOM")
	_seed_note.text = tr("CUSTOM_SEED_NOTE")
	var cfg = _autoload("Config")
	if cfg == null:
		return
	for s in cfg.CUSTOM_GAME["settings"]:
		var id: String = String(s["id"])
		var picker: OptionButton = pickers.get(id)
		if picker == null:
			continue
		(_names[id] as Label).text = tr(String(s["name"]))
		var keep: String = String(picker.get_item_metadata(picker.selected)) if picker.selected >= 0 else String(s.get("default", ""))
		picker.clear()
		for i in (s["choices"] as Array).size():
			var c: Dictionary = s["choices"][i]
			var text: String = tr(String(c["name"]))
			if c.has("days") and "%" in text:
				text = text % int(c["days"])
			picker.add_item(text, i)
			picker.set_item_metadata(i, String(c["id"]))
			if String(c["id"]) == keep:
				picker.select(i)
		_show_note(id)

# ==============================================================================
# Helpers
# ==============================================================================

func _open_settings() -> void:
	var hud = get_parent()
	while hud != null and not ("pause_menu" in hud):
		hud = hud.get_parent()
	if hud != null and hud.pause_menu and hud.pause_menu.has_method("open_settings_only"):
		hud.pause_menu.open_settings_only()

func _quit() -> void:
	if is_inside_tree():
		get_tree().quit()

func _label(node_name: String, variation: StringName, parent: Control) -> Label:
	var l := Label.new()
	l.name = node_name
	l.theme_type_variation = variation
	parent.add_child(l)
	return l

func _button(node_name: String, cb: Callable, variation: StringName, icon_name: String, parent: Control) -> Button:
	var b := Button.new()
	b.name = node_name
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, UiTheme.height("command"))
	b.pressed.connect(cb)
	parent.add_child(b)
	_glyph(b, icon_name)
	return b

## A button's glyph set at its left end, apart from its words, which stay centred on the whole button with the others'
## (as the pause menu's: PauseMenu._glyph; the player, 2026-10-04: "resume和其他的按钮字体没对齐").
func _glyph(btn: Button, icon_name: String) -> void:
	var tex: Texture2D = UiTheme.icon(icon_name) if icon_name != "" else null
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

func _ui(key: String, fallback: float) -> float:
	var cfg = _autoload("Config")
	return float(cfg.UI.get(key, fallback)) if (cfg and "UI" in cfg) else fallback

func _autoload(n: String) -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/" + n)
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null(n) if loop is SceneTree else null
