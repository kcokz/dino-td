# res://scripts/ui/OptionPanel.gd
class_name OptionPanel
extends PanelContainer

## RTS-style Command Card & Unit Option Panel (v0.2).
## Docked at the bottom-right corner of the HUD.
## Displays selected unit information (Name, HP/Reserves, Operating status)
## and dynamic action buttons (Hero 2-level build menu, Building demolish, Resource harvest).

signal build_option_selected(building_type: String)
signal action_triggered(action_name: String, target_node: Node)

var selected_unit: Node = null
var current_menu: String = "default" # "default" or "build"

## Inside the cabin the panel stops resting on the Hero: there is nothing to order
## him to do in there, and offering his build menu at the bench would be a second
## way to do something the room is not for.
var in_cabin: bool = false

# UI Nodes
var title_label: Label = null
var status_label: Label = null
var button_container: Container = null
var _last_refresh_time: float = 0.0

func _init() -> void:
	custom_minimum_size = _panel_size()

func _ready() -> void:
	_ensure_components()
	_connect_event_bus()
	_refresh_ui()

func _exit_tree() -> void:
	_disconnect_event_bus()

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb:
		if eb.has_signal("unit_selected") and not eb.unit_selected.is_connected(_on_unit_selected):
			eb.unit_selected.connect(_on_unit_selected)
		if eb.has_signal("unit_deselected") and not eb.unit_deselected.is_connected(_on_unit_deselected):
			eb.unit_deselected.connect(_on_unit_deselected)
		if eb.has_signal("locale_changed") and not eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.connect(_on_locale_changed)
		if eb.has_signal("resources_changed") and not eb.resources_changed.is_connected(_on_resources_changed):
			eb.resources_changed.connect(_on_resources_changed)
		if eb.has_signal("cabin_view_changed") and not eb.cabin_view_changed.is_connected(_on_cabin_view_changed):
			eb.cabin_view_changed.connect(_on_cabin_view_changed)

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
		if eb.has_signal("unit_selected") and eb.unit_selected.is_connected(_on_unit_selected):
			eb.unit_selected.disconnect(_on_unit_selected)
		if eb.has_signal("unit_deselected") and eb.unit_deselected.is_connected(_on_unit_deselected):
			eb.unit_deselected.disconnect(_on_unit_deselected)
		if eb.has_signal("locale_changed") and eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.disconnect(_on_locale_changed)
		if eb.has_signal("resources_changed") and eb.resources_changed.is_connected(_on_resources_changed):
			eb.resources_changed.disconnect(_on_resources_changed)
		if eb.has_signal("cabin_view_changed") and eb.cabin_view_changed.is_connected(_on_cabin_view_changed):
			eb.cabin_view_changed.disconnect(_on_cabin_view_changed)

## Left-click is the only thing that changes what the panel shows. Right-click
## gives the Hero an order and deliberately leaves the panel alone, so inspecting
## and commanding never interfere with each other.
func _on_unit_selected(unit: Node) -> void:
	set_selected_unit(unit)

func _on_unit_deselected() -> void:
	clear_selection()

func _on_locale_changed(_locale: String) -> void:
	_refresh_ui()

func _on_cabin_view_changed(inside: bool) -> void:
	in_cabin = inside
	selected_unit = null
	current_menu = "default"
	_refresh_ui()

## The wallet changed, so what the player can afford changed with it. Only the
## enabled state is touched -- rebuilding the menu here would throw away whichever
## entry the cursor is currently over, and with it the detail line.
func _on_resources_changed(_res: Dictionary) -> void:
	refresh_build_affordability()

func refresh_build_affordability() -> void:
	if current_menu != "build" or button_container == null:
		return
	var cfg = _get_config()
	var buildable: Array = cfg.BUILDABLE_TYPES if (cfg and "BUILDABLE_TYPES" in cfg) else []
	var children: Array = button_container.get_children()
	for i in range(buildable.size()):
		if i >= children.size():
			break
		var btn = children[i]
		if btn is Button:
			btn.disabled = not _can_afford(String(buildable[i]))

func set_selected_unit(unit: Node) -> void:
	selected_unit = unit
	current_menu = "default"
	_refresh_ui()

func select_target(target: Node) -> void:
	set_selected_unit(target)

func clear_selection() -> void:
	if in_cabin:
		selected_unit = null
		current_menu = "default"
		_refresh_ui()
		return
	# Fallback to hero if present
	var hero = _get_hero()
	if hero != null and is_instance_valid(hero) and not hero.is_queued_for_deletion():
		selected_unit = hero
	else:
		selected_unit = null
	current_menu = "default"
	_refresh_ui()

func deselect() -> void:
	selected_unit = null
	current_menu = "default"
	_refresh_ui()

var selected_target: Node:
	get: return selected_unit
	set(v): selected_unit = v

var current_menu_level: int:
	get: return 2 if current_menu == "build" else 1

func _on_build_pressed() -> void:
	current_menu = "build"
	_refresh_ui()

func _on_back_pressed() -> void:
	current_menu = "default"
	_refresh_ui()

func _process(delta: float) -> void:
	# Whatever the panel was showing has gone (destroyed, depleted): fall back to
	# the Hero, who is the resting subject.
	if selected_unit != null and (not is_instance_valid(selected_unit) or selected_unit.is_queued_for_deletion()):
		clear_selection()
		return
	if selected_unit == null:
		if in_cabin:
			return
		# The panel is built before Main spawns the Hero, so the first refresh finds
		# nothing. Keep trying until he exists.
		var hero = _get_hero()
		if hero != null and is_instance_valid(hero):
			set_selected_unit(hero)
		return
	_last_refresh_time += delta
	if _last_refresh_time >= 0.25:
		_last_refresh_time = 0.0
		_update_status_display()

func _is_hero(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return unit.is_in_group("hero") or unit == _get_hero()

func _ensure_components() -> void:
	name = "OptionPanel"
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	var p_size: Vector2 = _panel_size()
	var margin: float = _panel_margin()
	offset_left = -(p_size.x + margin)
	offset_top = -(p_size.y + margin)
	offset_right = -margin
	offset_bottom = -margin
	custom_minimum_size = p_size

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.4, 0.5, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

	var main_vbox = find_child("MainVBox", true, false) as VBoxContainer
	if main_vbox == null:
		main_vbox = VBoxContainer.new()
		main_vbox.name = "MainVBox"
		main_vbox.add_theme_constant_override("separation", 6)
		add_child(main_vbox)

	# Title & Status
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if title_label == null:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = tr("OPTION_UNIT_INFO")
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", _ui_size("panel_title_font_size", 30))
		main_vbox.add_child(title_label)

	if status_label == null:
		status_label = find_child("StatusLabel", true, false) as Label
	if status_label == null:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.text = tr("OPTION_DEFAULT_STATUS")
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", _ui_size("panel_status_font_size", 22))
		status_label.modulate = Color(0.85, 0.85, 0.85)
		main_vbox.add_child(status_label)

	var sep = find_child("HSeparator", true, false)
	if sep == null:
		sep = HSeparator.new()
		sep.name = "HSeparator"
		main_vbox.add_child(sep)

	# Action Buttons Container
	if button_container == null:
		button_container = find_child("ButtonContainer", true, false) as GridContainer
	if button_container == null:
		var grid = GridContainer.new()
		grid.name = "ButtonContainer"
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		main_vbox.add_child(grid)
		button_container = grid

func _update_status_display() -> void:
	if current_menu == "build":
		return # the build page uses this line for the hovered entry's detail
	if selected_unit == null or not is_instance_valid(selected_unit):
		return
	if selected_unit.has_method("get_display_info"):
		var info: Dictionary = selected_unit.get_display_info()
		if title_label:
			title_label.text = info.get("title", "")
		if status_label:
			status_label.text = info.get("status", "")

func _refresh_ui() -> void:
	_ensure_components()
	if selected_unit == null or not is_instance_valid(selected_unit):
		if in_cabin:
			# Standing in the room with nothing picked: say where we are and how to
			# get out, rather than falling back to the Hero's build menu.
			if title_label: title_label.text = tr("CABIN_TITLE")
			if status_label: status_label.text = tr("CABIN_HINT_LEAVE")
			_clear_buttons()
			return
		var hero = _get_hero()
		if hero != null and is_instance_valid(hero):
			selected_unit = hero

	if selected_unit == null or not is_instance_valid(selected_unit):
		if title_label: title_label.text = TranslationServer.translate("OPTION_STATUS")
		if status_label: status_label.text = ""
		_clear_buttons()
		return

	# Query display info
	var info: Dictionary = {}
	if selected_unit.has_method("get_display_info"):
		info = selected_unit.get_display_info()
	else:
		info = {
			"title": selected_unit.name,
			"type": "generic",
			"status": ""
		}

	if title_label:
		title_label.text = info.get("title", selected_unit.name)
	if status_label:
		status_label.text = info.get("status", "")

	_clear_buttons()

	var unit_type = info.get("type", "")
	match unit_type:
		"hero":
			_populate_hero_buttons()
		"building":
			_populate_building_buttons()
		"resource_node":
			_populate_resource_buttons()
		"station":
			_populate_station_buttons()
		_:
			# Default / generic
			pass

func _clear_buttons() -> void:
	if button_container == null:
		return
	for child in button_container.get_children():
		button_container.remove_child(child)
		child.queue_free()

func _create_action_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	var btn_font: int = _ui_size("panel_button_font_size", 24)
	btn.custom_minimum_size = Vector2(150, btn_font * 2)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", btn_font)
	btn.pressed.connect(callback)
	button_container.add_child(btn)
	return btn

func _populate_hero_buttons() -> void:
	if current_menu == "default":
		# Level 1: [ Build ]
		_create_action_button(TranslationServer.translate("CMD_BUILD"), func():
			current_menu = "build"
			_refresh_ui()
		)
	elif current_menu == "build":
		# Level 2: one button per Config.BUILDABLE_TYPES, then [ Back ]
		var cfg = _get_config()
		var buildable: Array = []
		if cfg and "BUILDABLE_TYPES" in cfg:
			buildable = cfg.BUILDABLE_TYPES
		else:
			buildable = ["wall", "tower"]
		_clear_build_detail()
		# Buttons carry only the name. The cost and build time go in the detail line
		# below, shown for whichever button the cursor is over, and a button the
		# player cannot afford is disabled -- so affordability is read at a glance
		# instead of by comparing numbers on every button against the wallet.
		for b_type in buildable:
			var b_name: String = _building_name(b_type)
			var btn := _create_action_button(b_name, func():
				_trigger_build(b_type)
			)
			btn.disabled = not _can_afford(b_type)
			btn.mouse_entered.connect(func(): _show_build_detail(b_type))
			btn.focus_entered.connect(func(): _show_build_detail(b_type))
			btn.mouse_exited.connect(_clear_build_detail)

		
		_create_action_button(TranslationServer.translate("CMD_BACK"), func():
			current_menu = "default"
			_refresh_ui()
		)

## Cost and build time for the hovered entry, or a prompt when nothing is hovered.
## Anything that bites what touches it says so here: a stake fence only reads as a
## weapon rather than a speed bump if the player learns it before paying for it.
func _show_build_detail(b_type: String) -> void:
	if status_label == null:
		return
	var cfg = _get_config()
	if cfg == null or not cfg.BUILDINGS.has(b_type):
		return
	var b_name: String = _building_name(b_type)
	var cost: int = int(cfg.BUILDINGS[b_type].get("cost", {}).get("wood", 0))
	if _can_afford(b_type):
		var secs: float = float(cfg.get_build_time(b_type)) if cfg.has_method("get_build_time") else 0.0
		var dps: float = float(cfg.get_contact_dps(b_type)) if cfg.has_method("get_contact_dps") else 0.0
		if dps > 0.0:
			status_label.text = tr("BUILD_DETAIL_FORMAT_DAMAGE") % [b_name, cost, secs, dps]
		else:
			status_label.text = tr("BUILD_DETAIL_FORMAT") % [b_name, cost, secs]
		status_label.modulate = Color(0.85, 0.85, 0.85)
	else:
		status_label.text = tr("BUILD_DETAIL_UNAFFORDABLE") % [b_name, cost, _wood()]
		status_label.modulate = Color(1.0, 0.45, 0.4)

func _clear_build_detail() -> void:
	if status_label == null:
		return
	status_label.text = tr("BUILD_HINT_PICK")
	status_label.modulate = Color(0.85, 0.85, 0.85)

func _building_name(b_type: String) -> String:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_name"):
		return String(cfg.get_building_name(b_type))
	return b_type

func _wood() -> int:
	var gs = _get_game_state()
	if gs and "resources" in gs:
		return int(gs.resources.get("wood", 0))
	return 0

func _can_afford(b_type: String) -> bool:
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs == null or cfg == null or not cfg.BUILDINGS.has(b_type):
		return false
	if gs.has_method("can_afford"):
		return bool(gs.can_afford(cfg.BUILDINGS[b_type].get("cost", {})))
	return true

## A building's own menu: the things with a cost or a consequence. Right-click
## deliberately does not offer these -- it is too easy to hit by accident -- so
## mending and demolishing are chosen here, on purpose, with the price on the
## button.
func _populate_building_buttons() -> void:
	if selected_unit.has_method("needs_repair") and selected_unit.needs_repair():
		var cost: int = int(selected_unit.repair_cost()) if selected_unit.has_method("repair_cost") else 0
		var raw: String = tr("CMD_REPAIR")
		var btn := _create_action_button((raw % cost) if ("%" in raw) else raw, func():
			var hero = _get_hero()
			if hero and is_instance_valid(hero) and hero.has_method("order_repair") and is_instance_valid(selected_unit):
				hero.order_repair(selected_unit)
				action_triggered.emit("repair", selected_unit)
		)
		btn.disabled = not _can_pay_a_repair_step()

	_create_action_button(TranslationServer.translate("CMD_DEMOLISH"), func():
		if selected_unit and is_instance_valid(selected_unit) and selected_unit.has_method("demolish"):
			var unit_to_demolish = selected_unit
			clear_selection()
			unit_to_demolish.demolish()
	)

## Resource nodes are scenery, not units: they take no orders. Right-clicking one
## while the Hero is selected already sends him to harvest it, so a button here
## would only be a second, slower way to do the same thing.
## One button per recipe this bench still has to offer. A recipe already made is
## not listed at all -- an unlock is permanent, so a finished one is not a choice.
func _populate_station_buttons() -> void:
	var station := selected_unit
	if station == null or not is_instance_valid(station) or not station.has_method("recipes"):
		return
	_clear_craft_detail()
	for recipe_id in station.recipes():
		var rid: String = String(recipe_id)
		if not station.can_offer(rid):
			continue
		var btn := _create_action_button(station.recipe_name(rid), func():
			if is_instance_valid(station):
				station.begin(rid)
				_refresh_ui()
		)
		btn.disabled = not station.can_afford(rid)
		btn.mouse_entered.connect(func(): _show_craft_detail(station, rid))
		btn.focus_entered.connect(func(): _show_craft_detail(station, rid))
		btn.mouse_exited.connect(_clear_craft_detail)

## What a recipe costs and how long it takes, for whichever entry the cursor is
## over -- the same shape as the build menu's detail line, because it answers the
## same question.
func _show_craft_detail(station: Node, recipe_id: String) -> void:
	if status_label == null or station == null or not is_instance_valid(station):
		return
	var costs: PackedStringArray = []
	for res_id in station.inputs_of(recipe_id):
		costs.append("%d %s" % [int(station.inputs_of(recipe_id)[res_id]), _resource_name(String(res_id))])
	var cost_text: String = ", ".join(costs)
	if station.can_afford(recipe_id):
		status_label.text = tr("CRAFT_DETAIL_FORMAT") % [station.recipe_name(recipe_id), cost_text, station.time_of(recipe_id)]
		status_label.modulate = Color(0.85, 0.85, 0.85)
	else:
		status_label.text = tr("CRAFT_DETAIL_UNAFFORDABLE") % [station.recipe_name(recipe_id), cost_text]
		status_label.modulate = Color(1.0, 0.45, 0.4)

func _clear_craft_detail() -> void:
	if status_label == null:
		return
	if selected_unit != null and is_instance_valid(selected_unit) and selected_unit.has_method("get_display_info"):
		status_label.text = String(selected_unit.get_display_info().get("status", ""))
	else:
		status_label.text = tr("CABIN_HINT_PICK_STATION")
	status_label.modulate = Color(0.85, 0.85, 0.85)

## Repair is paid one wood at a time, so one wood is enough to start.
func _can_pay_a_repair_step() -> bool:
	var gs = _get_game_state()
	return gs != null and "resources" in gs and int(gs.resources.get("wood", 0)) >= 1

func _resource_name(res_id: String) -> String:
	return TranslationServer.translate("RESOURCE_%s" % res_id.to_upper())

func _populate_resource_buttons() -> void:
	pass

func _trigger_build(type_id: String) -> void:
	build_option_selected.emit(type_id)
	var hud = _get_hud()
	if hud and is_instance_valid(hud) and hud.has_method("select_build_type"):
		hud.select_build_type(type_id)

func _get_hero() -> Node:
	if is_inside_tree():
		return get_tree().get_first_node_in_group("hero")
	return null

func _get_hud() -> Node:
	if is_inside_tree():
		return get_tree().root.find_child("HUD", true, false)
	return null

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/EventBus")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("EventBus")
	return null

## Reads a font size out of Config.UI so panel sizing lives with the rest of the data.
func _ui_size(key: String, fallback: int) -> int:
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		return int(cfg.UI.get(key, fallback))
	return fallback

func _panel_size() -> Vector2:
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		return cfg.UI.get("option_panel_size", Vector2(430, 300))
	return Vector2(430, 300)

func _panel_margin() -> float:
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		return float(cfg.UI.get("option_panel_margin", 16.0))
	return 16.0

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
