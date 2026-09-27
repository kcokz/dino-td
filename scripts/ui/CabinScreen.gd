# res://scripts/ui/CabinScreen.gd
class_name CabinScreen
extends Control

## Inside the cabin: the room is the screen, and a dock along the bottom works it (v0.6).
##
## The room -- the crew module cut away along the front, the Hero's three benches along its
## back wall, the tools on the board and the pot on the fire and the beacon's mast showing
## how far the run has got (CabinArt) -- fills the screen above the dock. The dock has a tab
## for each bench; the chosen bench is ringed in the room, and the dock shows it: what it is
## for, the job under way and how far along, what it has to say, and every job it offers as
## a card with its price and its time. Clicking a bench in the room chooses it too. The world
## still runs -- the top of the screen, raid warnings and all, stays up.
##
## It builds nothing of its own: the benches are CraftingStation, the cards and prices are
## UiKit's, the look is UiTheme's.

signal leave_requested()

var is_open: bool = false
## The bench whose tab is chosen (its station_id).
var selected: String = ""
var cards: Dictionary = {}          # station_id -> {"panel", "tab", "tab_bar", "name", "purpose", "status", "work_row", "work_bar", "work_text", "jobs", "signature"}
var _hovering: Dictionary = {}      # station_id -> the job the cursor is over
var _tick: float = 0.0
var _dock: PanelContainer = null
var _tab_row: HBoxContainer = null
var _benches: VBoxContainer = null
var _subtitle: Label = null
var _leave_btn: Button = null
var _tab_group := ButtonGroup.new()

func _init() -> void:
	name = "CabinScreen"
	visible = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The room itself is under this screen and is clicked through it: only the dock stops
	# the mouse.
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
			["unlock_granted", _on_changed], ["beacon_changed", _on_changed], ["locale_changed", _on_locale_changed],
			["unit_selected", _on_unit_selected], ["material_discovered", _on_changed]]:
		if eb.has_signal(pair[0]):
			out.append([Signal(eb, pair[0]), pair[1]])
	return out

## Shown while the Hero is inside, and refreshed each time: what a bench offers changes
## while he is out (a first bone makes the pick affordable; a finished tool leaves the list).
func set_open(open: bool) -> void:
	is_open = open
	visible = open
	if open:
		_refresh_all(true)
		var stations: Array = _stations()
		if not stations.is_empty() and not cards.has(selected):
			selected = String(stations[0].station_id)
		select(selected)
		_fade_in()
	else:
		for st in _stations():
			_ring(st, false)

## Chooses the bench `station_id`: its tab pressed, its panel shown, and it ringed in the room.
func select(station_id: String) -> void:
	if not cards.has(station_id):
		return
	selected = station_id
	for id in cards:
		var c: Dictionary = cards[id]
		(c["panel"] as Control).visible = id == station_id
		(c["tab"] as Button).set_pressed_no_signal(id == station_id)
	for st in _stations():
		_ring(st, is_open and String(st.station_id) == station_id)

func _on_unit_selected(unit: Node) -> void:
	if is_open and unit != null and is_instance_valid(unit) and "station_id" in unit:
		select(String(unit.station_id))

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
	# A shade rising from the bottom edge behind the dock, so it reads against whatever is
	# on the floor, and fading out well below the benches.
	var shade := TextureRect.new()
	shade.name = "Shade"
	var ramp := Gradient.new()
	ramp.set_color(0, Color(UiTheme.color("scrim"), 0.0))
	ramp.set_color(1, UiTheme.color("scrim"))
	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -float(_ui("cabin_shade_height", 260))
	shade.offset_bottom = 0.0
	add_child(shade)

	# The dock: pinned along the bottom by a zero-height rect, as tall as what it holds.
	var edge: float = float(UiTheme.space("l"))
	_dock = PanelContainer.new()
	_dock.name = "Dock"
	_dock.theme_type_variation = &"HudPanel"
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dock.offset_left = edge
	_dock.offset_right = -edge
	_dock.offset_top = -edge
	_dock.offset_bottom = -edge
	add_child(_dock)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", UiTheme.space("m"))
	_dock.add_child(column)

	# Along the top of the dock: a tab per bench, what the cabin costs him, the way out.
	var top := HBoxContainer.new()
	top.name = "TopRow"
	top.add_theme_constant_override("separation", UiTheme.space("m"))
	column.add_child(top)
	_tab_row = HBoxContainer.new()
	_tab_row.name = "Tabs"
	_tab_row.add_theme_constant_override("separation", UiTheme.space("xs"))
	top.add_child(_tab_row)
	_subtitle = Label.new()
	_subtitle.name = "CabinSubtitle"
	_subtitle.theme_type_variation = &"MutedLabel"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(_subtitle)
	_leave_btn = Button.new()
	_leave_btn.name = "LeaveBtn"
	_leave_btn.theme_type_variation = &"GhostButton"
	_leave_btn.icon = UiTheme.icon("back")
	_leave_btn.custom_minimum_size = Vector2(0, UiTheme.height("command"))
	_leave_btn.pressed.connect(func(): leave_requested.emit())
	top.add_child(_leave_btn)

	column.add_child(HSeparator.new())
	# The chosen bench's panel; the others are there, hidden, and keep their state.
	_benches = VBoxContainer.new()
	_benches.name = "Benches"
	column.add_child(_benches)
	_refresh_texts()

func _refresh_texts() -> void:
	if _subtitle:
		_subtitle.text = tr("CABIN_SUBTITLE")
	if _leave_btn:
		_leave_btn.text = tr("CABIN_LEAVE")
	for station_id in cards:
		var c: Dictionary = cards[station_id]
		var bench_name: String = tr("STATION_%s_NAME" % String(station_id).to_upper())
		(c["name"] as Label).text = bench_name
		(c["tab"] as Button).text = bench_name
		(c["purpose"] as Label).text = tr("STATION_%s_DESC" % String(station_id).to_upper())

## A bench's tab and its panel, made the first time it is asked for, in the order the benches
## stand (Config.STATIONS).
func _card_for(station: Node) -> Dictionary:
	var station_id: String = String(station.station_id)
	if cards.has(station_id):
		return cards[station_id]
	# The tab: the bench's icon and name, and a thin bar under it while a job there is under
	# way -- so work at a bench not on show is still seen going on.
	var tab_box := VBoxContainer.new()
	tab_box.add_theme_constant_override("separation", UiTheme.space("hair"))
	_tab_row.add_child(tab_box)
	var tab := Button.new()
	tab.name = "Tab_%s" % station_id
	tab.theme_type_variation = &"SegmentButton"
	tab.toggle_mode = true
	tab.button_group = _tab_group
	tab.icon = UiTheme.icon(station_id)
	tab.custom_minimum_size = Vector2(0, UiTheme.height("command"))
	tab.pressed.connect(func(): select(station_id))
	tab.mouse_entered.connect(func(): _ring(station, true))
	tab.mouse_exited.connect(func(): _ring(station, is_open and selected == station_id))
	tab_box.add_child(tab)
	var tab_bar := ProgressBar.new()
	tab_bar.theme_type_variation = &"BuildBar"
	tab_bar.show_percentage = false
	tab_bar.max_value = 1.0
	tab_bar.step = 0.0
	tab_bar.custom_minimum_size = Vector2(0, UiTheme.thickness("pip"))
	tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_bar.modulate.a = 0.0
	tab_box.add_child(tab_bar)

	# The panel: what the bench is and says on the left, its jobs across the right.
	var panel := HBoxContainer.new()
	panel.name = "Bench_%s" % station_id
	panel.add_theme_constant_override("separation", UiTheme.space("l"))
	panel.visible = false
	_benches.add_child(panel)
	var info := VBoxContainer.new()
	info.name = "Info"
	info.custom_minimum_size = Vector2(_ui("cabin_info_width", 300), 0)
	info.add_theme_constant_override("separation", UiTheme.space("xs"))
	panel.add_child(info)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.space("m"))
	info.add_child(head)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"SolidTechPanel" if station_id == _beacon_station() else &"InsetPanel"
	head.add_child(frame)
	frame.add_child(UiKit.icon_rect(station_id, UiTheme.icon_size("l")))
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
	info.add_child(work[0])
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = &"MutedLabel"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(status)
	panel.add_child(VSeparator.new())
	var jobs := HFlowContainer.new()
	jobs.name = "Jobs"
	jobs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jobs.add_theme_constant_override("h_separation", UiTheme.space("s"))
	jobs.add_theme_constant_override("v_separation", UiTheme.space("s"))
	panel.add_child(jobs)

	var c: Dictionary = {"panel": panel, "tab": tab, "tab_bar": tab_bar, "name": title, "purpose": purpose,
		"status": status, "work_row": work[0], "work_bar": work[1], "work_text": work[2], "jobs": jobs, "signature": ""}
	cards[station_id] = c
	var bench_name: String = tr("STATION_%s_NAME" % station_id.to_upper())
	title.text = bench_name
	tab.text = bench_name
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
	var work: float = float(info.get("work", 0.0))
	(c["work_row"] as Control).visible = busy
	(c["tab_bar"] as ProgressBar).modulate.a = 1.0 if busy else 0.0
	if busy:
		(c["work_bar"] as ProgressBar).value = work
		(c["tab_bar"] as ProgressBar).value = work
		(c["work_text"] as Label).text = UiKit.work_text(String(info.get("work_label", "")), work)
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
	var jobs: Container = c["jobs"]
	if rebuild or signature != String(c["signature"]):
		c["signature"] = signature
		for child in jobs.get_children():
			jobs.remove_child(child)
			child.queue_free()
		for job_id in offered:
			_add_job(station, job_id, jobs, busy)
		if offered.is_empty():
			# Nothing yet -- the bench waits on a material to turn up -- or nothing left.
			var none := Label.new()
			none.theme_type_variation = &"CaptionLabel"
			var waiting: bool = station.has_method("waiting_on_materials") and station.waiting_on_materials()
			none.text = tr("STATION_NOTHING_YET" if waiting else "STATION_NOTHING")
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
	# Side by side at one width, not stretched across the dock: one job is a card, not a bar.
	# Wider when its name needs it -- the dock has the room, and a name cut short is not read.
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.custom_minimum_size.x = float(_ui("cabin_job_width", 230))
	btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if decision:
		btn.custom_minimum_size.y = UiTheme.height("card")
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

## The bench's ring in the room: on for the chosen one and the one under the cursor.
func _ring(station: Node, on: bool) -> void:
	if is_instance_valid(station) and station.has_method("set_selected_visual"):
		station.set_selected_visual(on)

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
