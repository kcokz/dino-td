# res://scripts/ui/Briefing.gd
class_name Briefing
extends Control

## THE BRIEFING (the player, 2026-10-04: "开场故事如果玩家跳过的话，在第一关我们要有明确的类似tutorial的停止方式来告诉玩家这个
## 事情，包括船舱的电池会用完"): the opening skipped in our own game, the game is held on a card that says what has happened
## and what he must do -- the beacon, the capsule's battery, what will come for it -- and where it is all written again
## (the journal). Only what he must know (GAME-DESIGN 1, pillar 6): nothing of how to play it well. "Got it", and the run
## goes on (HUD.brief gives him the goal). Over a paused game; it lifts only the pause it put on.

signal closed

## The rows it says, in order: [the icon, the words' key]. Each its own line, short.
const ROWS: Array = [["wreck", "BRIEFING_CRASH"], ["beacon", "BRIEFING_BEACON"], ["battery", "BRIEFING_POWER"],
	["dino", "BRIEFING_DINOS"]]

var panel: PanelContainer = null
var title_label: Label = null
var note_label: Label = null
var ok_btn: Button = null
## Each row's words, by its key.
var row_labels: Dictionary = {}
var _was_paused: bool = false

func _init() -> void:
	name = "Briefing"
	visible = false
	# Over a paused game, and answering.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build()
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("locale_changed") and not eb.locale_changed.is_connected(_on_locale_changed):
		eb.locale_changed.connect(_on_locale_changed)

func _exit_tree() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb and is_instance_valid(eb) and eb.has_signal("locale_changed") and eb.locale_changed.is_connected(_on_locale_changed):
		eb.locale_changed.disconnect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()

func is_open() -> bool:
	return visible

## Up, and the game held while it is read.
func open() -> void:
	if panel == null:
		_build()
	_refresh_texts()
	visible = true
	var gs = get_node_or_null("/root/GameState")
	if gs:
		_was_paused = bool(gs.is_paused) if "is_paused" in gs else false
		if gs.has_method("set_paused"):
			gs.set_paused(true)
	if ok_btn and ok_btn.is_inside_tree():
		ok_btn.grab_focus()

## Read: down, the pause it put on lifted, and said so.
func close() -> void:
	if not visible:
		return
	visible = false
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused") and not _was_paused:
		gs.set_paused(false)
	closed.emit()

## Enter or Esc read it as "Got it" too.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()

func _build() -> void:
	if panel != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The world behind it frosted, as behind the menu: stopped, still there.
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.material = UiTheme.frost_material()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)
	var centre := CenterContainer.new()
	centre.name = "Centerer"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	panel = PanelContainer.new()
	panel.name = "BriefingPanel"
	panel.theme_type_variation = &"ModalPanel"
	panel.custom_minimum_size = Vector2(_width(), 0.0)
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "BriefingBox"
	box.add_theme_constant_override("separation", UiTheme.space("m"))
	panel.add_child(box)
	title_label = Label.new()
	title_label.name = "BriefingTitle"
	title_label.theme_type_variation = &"TitleLabel"
	title_label.uppercase = true
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var rule := HSeparator.new()
	rule.name = "TitleRule"
	rule.theme_type_variation = &"TitleRule"
	box.add_child(rule)
	for row in ROWS:
		var line := HBoxContainer.new()
		line.name = "Row_" + String(row[1])
		line.add_theme_constant_override("separation", UiTheme.space("m"))
		box.add_child(line)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.texture = UiTheme.icon(String(row[0]))
		icon.custom_minimum_size = Vector2.ONE * float(UiTheme.icon_size("l"))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(icon)
		var words := Label.new()
		words.name = "Words"
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(words)
		row_labels[String(row[1])] = words
	note_label = Label.new()
	note_label.name = "BriefingNote"
	note_label.theme_type_variation = &"CaptionLabel"
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note_label)
	ok_btn = Button.new()
	ok_btn.name = "BriefingOk"
	ok_btn.theme_type_variation = &"AccentButton"
	ok_btn.custom_minimum_size = Vector2(float(UiTheme.width("button")), float(UiTheme.height("command")))
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(close)
	box.add_child(ok_btn)
	_refresh_texts()

## Its words, in the language of the moment; the battery's days from the run's own (Config.POWER.lasts_days).
func _refresh_texts() -> void:
	if panel == null:
		return
	title_label.text = tr("BRIEFING_TITLE")
	var cfg = get_node_or_null("/root/Config")
	var days: int = int(round(float(cfg.POWER.get("lasts_days", 8.0)))) if (cfg and "POWER" in cfg) else 8
	for key in row_labels:
		var text: String = tr(String(key))
		(row_labels[key] as Label).text = (text % days) if String(key) == "BRIEFING_POWER" else text
	note_label.text = tr("BRIEFING_JOURNAL") % Keys.text("journal_key")
	ok_btn.text = tr("BRIEFING_OK")

## As wide as Config.UI.briefing_width: a short line a row.
func _width() -> float:
	var cfg = get_node_or_null("/root/Config")
	return float(cfg.UI.get("briefing_width", 520)) if (cfg and "UI" in cfg) else 520.0
