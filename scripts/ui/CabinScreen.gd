# res://scripts/ui/CabinScreen.gd
class_name CabinScreen
extends Control

## Inside the cabin, as a screen: every bench at once, side by side (v0.6 UI).
##
## The room was three coloured boxes to click one at a time, each opening the command card in
## the corner -- a menu buried in a menu, in the one place the player comes to decide. Now
## the benches are laid out as cards across the room: what each is for, the job under way
## and how far along, what it has to say, and every job it offers with its price and its
## time. The room itself stays behind them, dimmed: this is still the inside of the capsule,
## and the world still runs -- the top of the screen, raid warnings and all, stays up.
##
## It builds nothing of its own: the benches are CraftingStation, the cards and prices are
## UiKit's, the look is UiTheme's.

signal leave_requested()

var is_open: bool = false
var cards: Dictionary = {}          # station_id -> {"panel", "status", "work_row", "work_bar", "work_text", "jobs", "signature"}
var _hovering: Dictionary = {}      # station_id -> the job the cursor is over
var _tick: float = 0.0
var _title: Label = null
var _subtitle: Label = null
var _leave_btn: Button = null
var _row: HBoxContainer = null

func _init() -> void:
	name = "CabinScreen"
	visible = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	var eb = _bus()
	if eb:
		for pair in _handlers(eb):
			if not (pair[0] as Signal).is_connected(pair[1]):
				(pair[0] as Signal).connect(pair[1])

func _exit_tree() -> void:
	var eb = _bus()
	if eb == null:
		return
	for pair in _handlers(eb):
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])

func _handlers(eb: Node) -> Array:
	var out: Array = []
	for pair in [["cabin_view_changed", set_open], ["resources_changed", _on_resources_changed],
			["unlock_granted", _on_changed], ["beacon_changed", _on_changed], ["locale_changed", _on_locale_changed]]:
		if eb.has_signal(pair[0]):
			out.append([Signal(eb, pair[0]), pair[1]])
	return out

## Shown while the Hero is inside, and built fresh each time: what a bench offers changes
## while he is out (a first bone makes the pick affordable; a finished tool leaves the list).
func set_open(open: bool) -> void:
	is_open = open
	visible = open
	if open:
		_refresh_all(true)
		_fade_in()

func _on_resources_changed(_res: Dictionary) -> void:
	if is_open:
		_refresh_all(false)

func _on_changed(_arg = null) -> void:
	if is_open:
		_refresh_all(false)

func _on_locale_changed(_locale: String) -> void:
	_refresh_texts()
	if is_open:
		_refresh_all(true)

func _process(delta: float) -> void:
	if not is_open:
		return
	_tick += delta
	if _tick >= UiTheme.number("refresh_seconds"):
		_tick = 0.0
		_refresh_all(false)

# ==============================================================================
# Construction
# ==============================================================================

func _build() -> void:
	# The room behind, frosted: it is still the inside of the capsule, but the benches' cards
	# are what is read.
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.material = UiTheme.frost_material(UiTheme.number("cabin_frost_tint"))
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var edge: float = float(UiTheme.space("xl"))
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = edge
	column.offset_right = -edge
	column.offset_top = float(_ui("cabin_screen_top", 76))
	column.offset_bottom = -edge
	column.add_theme_constant_override("separation", UiTheme.space("l"))
	add_child(column)

	var header := VBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 0)
	column.add_child(header)
	_title = Label.new()
	_title.name = "CabinTitle"
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_title)
	_subtitle = Label.new()
	_subtitle.name = "CabinSubtitle"
	_subtitle.theme_type_variation = &"LeadLabel"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_subtitle)

	_row = HBoxContainer.new()
	_row.name = "Benches"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", UiTheme.space("l"))
	column.add_child(_row)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)

	_leave_btn = Button.new()
	_leave_btn.name = "LeaveBtn"
	_leave_btn.icon = UiTheme.icon("back")
	_leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave_btn.custom_minimum_size = Vector2(UiTheme.width("button"), UiTheme.height("command"))
	_leave_btn.pressed.connect(func(): leave_requested.emit())
	column.add_child(_leave_btn)
	_refresh_texts()

## How far above the screen's bottom edge the room's free space ends: the top of the way
## out, and a gap above it (the column's own bottom inset, the button, the column's
## separation). The HUD stands its toasts there while the cabin is open.
func toast_bottom() -> float:
	return float(UiTheme.space("xl") + UiTheme.height("command") + UiTheme.space("l"))

func _refresh_texts() -> void:
	if _title:
		_title.text = tr("CABIN_TITLE")
	if _subtitle:
		_subtitle.text = tr("CABIN_SUBTITLE")
	if _leave_btn:
		_leave_btn.text = tr("CABIN_LEAVE")
	for station_id in cards:
		var c: Dictionary = cards[station_id]
		(c["name"] as Label).text = tr("STATION_%s_NAME" % String(station_id).to_upper())
		(c["purpose"] as Label).text = tr("STATION_%s_DESC" % String(station_id).to_upper())

## One card per bench in the cabin, in the order they stand (Config.STATIONS).
func _card_for(station: Node) -> Dictionary:
	var station_id: String = String(station.station_id)
	if cards.has(station_id):
		return cards[station_id]
	var panel := PanelContainer.new()
	panel.name = "Bench_%s" % station_id
	panel.theme_type_variation = &"SolidTechPanel" if station_id == _beacon_station() else &"SolidPanel"
	panel.custom_minimum_size = Vector2(_ui("cabin_card_width", 372), 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_row.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiTheme.space("s"))
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.space("m"))
	box.add_child(head)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"InsetPanel"
	head.add_child(frame)
	frame.add_child(UiKit.icon_rect(station_id, UiTheme.icon_size("xl")))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	var title := Label.new()
	title.theme_type_variation = &"HeadingLabel"
	names.add_child(title)
	var purpose := Label.new()
	purpose.theme_type_variation = &"CaptionLabel"
	purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(purpose)
	var work := UiKit.bar_row("Work", &"BuildBar")
	work[2].theme_type_variation = &"CaptionLabel"
	work[2].custom_minimum_size.x = 0
	box.add_child(work[0])
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = &"MutedLabel"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	box.add_child(HSeparator.new())
	var jobs := VBoxContainer.new()
	jobs.name = "Jobs"
	jobs.add_theme_constant_override("separation", UiTheme.space("s"))
	box.add_child(jobs)
	var c: Dictionary = {"panel": panel, "name": title, "purpose": purpose, "status": status,
		"work_row": work[0], "work_bar": work[1], "work_text": work[2], "jobs": jobs, "signature": ""}
	cards[station_id] = c
	title.text = tr("STATION_%s_NAME" % station_id.to_upper())
	purpose.text = tr("STATION_%s_DESC" % station_id.to_upper())
	return c

# ==============================================================================
# What is shown
# ==============================================================================

func _refresh_all(rebuild: bool) -> void:
	for station in _stations():
		_refresh_card(station, rebuild)

func _refresh_card(station: Node, rebuild: bool) -> void:
	var c: Dictionary = _card_for(station)
	var station_id: String = String(station.station_id)
	var info: Dictionary = station.get_display_info()
	var busy: bool = String(info.get("active_recipe", "")) != ""
	(c["work_row"] as Control).visible = busy
	if busy:
		(c["work_bar"] as ProgressBar).value = float(info.get("work", 0.0))
		(c["work_text"] as Label).text = UiKit.work_text(String(info.get("work_label", "")), float(info.get("work", 0.0)))
	if not _hovering.has(station_id):
		(c["status"] as Label).text = String(info.get("status", ""))
		(c["status"] as Label).modulate = Color.WHITE
	# The jobs themselves are only rebuilt when the list changes -- rebuilding them on every
	# tick would throw away the one the cursor is on, and its detail with it.
	var offered: Array = []
	for job in station.jobs():
		if station.can_offer(String(job)):
			offered.append(String(job))
	var signature: String = "%s|%s|%s" % [",".join(offered), String(info.get("active_recipe", "")), TranslationServer.get_locale()]
	var jobs: VBoxContainer = c["jobs"]
	if rebuild or signature != String(c["signature"]):
		c["signature"] = signature
		for child in jobs.get_children():
			jobs.remove_child(child)
			child.queue_free()
		for job_id in offered:
			_add_job(station, job_id, jobs, busy)
		if offered.is_empty():
			var none := Label.new()
			none.theme_type_variation = &"CaptionLabel"
			none.text = tr("STATION_NOTHING")
			jobs.add_child(none)
	else:
		var i: int = 0
		for child in jobs.get_children():
			if child is Button and i < offered.size():
				var job_id: String = offered[i]
				child.disabled = busy or not station.can_afford(job_id)
				UiKit.fill_price_row(child, station.inputs_of(job_id), _time_text(station, job_id))
				i += 1

## A job's card: pressing it starts the job (a bench does one at a time), the cursor on it
## says what it costs, takes and does. A job that costs nothing and takes no time is not a
## purchase but a decision -- the beacon's launch -- and is drawn as the one thing to press.
func _add_job(station: Node, job_id: String, into: Container, busy: bool) -> void:
	var station_id: String = String(station.station_id)
	var start := func():
		if is_instance_valid(station) and station.begin(job_id):
			_hovering.erase(station_id)
			_refresh_card(station, true)
	var decision: bool = station.inputs_of(job_id).is_empty() and float(station.time_of(job_id)) <= 0.0
	var btn: Button = UiKit.action_button(station.recipe_name(job_id), UiTheme.icon("signal"), start, &"AccentButton") \
		if decision else UiKit.card_button(station.recipe_name(job_id), UiKit.job_icon(station, job_id), start)
	btn.name = "Job_%s" % job_id
	into.add_child(btn)
	btn.disabled = busy or not station.can_afford(job_id)
	UiKit.fill_price_row(btn, station.inputs_of(job_id), _time_text(station, job_id))
	btn.mouse_entered.connect(func(): _show_detail(station, job_id))
	btn.focus_entered.connect(func(): _show_detail(station, job_id))
	btn.mouse_exited.connect(func(): _clear_detail(station))

func _time_text(station: Node, job_id: String) -> String:
	var t: float = float(station.time_of(job_id))
	return UiKit.seconds_text(t) if t > 0.0 else ""

func _show_detail(station: Node, job_id: String) -> void:
	var station_id: String = String(station.station_id)
	_hovering[station_id] = job_id
	var c: Dictionary = _card_for(station)
	var detail: Array = UiKit.job_detail(station, job_id)
	(c["status"] as Label).text = String(detail[0])
	(c["status"] as Label).modulate = UiKit.tone_color(String(detail[1]))

func _clear_detail(station: Node) -> void:
	_hovering.erase(String(station.station_id))
	if is_instance_valid(station):
		_refresh_card(station, false)

func _fade_in() -> void:
	if not is_inside_tree():
		return
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, UiTheme.number("pop_seconds"))

# ==============================================================================
# Resolvers
# ==============================================================================

## The benches, in the order they stand in the cabin.
func _stations() -> Array:
	var room = get_tree().get_first_node_in_group("cabin_interior") if is_inside_tree() else null
	if room == null or not ("stations" in room):
		return []
	var out: Array = []
	for st in room.stations:
		if is_instance_valid(st):
			out.append(st)
	return out

func _beacon_station() -> String:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	return String(cfg.BEACON_STATION) if (cfg and "BEACON_STATION" in cfg) else ""

func _ui(key: String, fallback: Variant) -> Variant:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	return cfg.UI.get(key, fallback) if (cfg and "UI" in cfg) else fallback

func _bus() -> Node:
	return get_node_or_null("/root/EventBus") if is_inside_tree() else null
