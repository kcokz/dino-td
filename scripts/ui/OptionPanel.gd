# res://scripts/ui/OptionPanel.gd
class_name OptionPanel
extends PanelContainer

## RTS-style Command Card & Unit Option Panel (v0.2).
## Docked at the bottom-right corner of the HUD.
## Displays selected unit information (Name, HP/Reserves, Operating status)
## and dynamic action buttons (Hero 2-level build menu, Building tend/demolish, Resource harvest).

signal build_option_selected(building_type: String)
signal action_triggered(action_name: String, target_node: Node)

var selected_unit: Node = null
var current_menu: String = "default" # "default" or "build"

# UI Nodes
var title_label: Label = null
var status_label: Label = null
var button_container: Container = null
var _last_refresh_time: float = 0.0

func _init() -> void:
	custom_minimum_size = Vector2(280, 180)

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

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
		if eb.has_signal("unit_selected") and eb.unit_selected.is_connected(_on_unit_selected):
			eb.unit_selected.disconnect(_on_unit_selected)
		if eb.has_signal("unit_deselected") and eb.unit_deselected.is_connected(_on_unit_deselected):
			eb.unit_deselected.disconnect(_on_unit_deselected)
		if eb.has_signal("locale_changed") and eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.disconnect(_on_locale_changed)

func _on_unit_selected(unit: Node) -> void:
	set_selected_unit(unit)

func _on_unit_deselected() -> void:
	clear_selection()

func _on_locale_changed(_locale: String) -> void:
	_refresh_ui()

func set_selected_unit(unit: Node) -> void:
	selected_unit = unit
	current_menu = "default"
	_refresh_ui()

func select_target(target: Node) -> void:
	set_selected_unit(target)

func clear_selection() -> void:
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
	if selected_unit != null:
		if not is_instance_valid(selected_unit) or selected_unit.is_queued_for_deletion():
			clear_selection()
			return
		_last_refresh_time += delta
		if _last_refresh_time >= 0.25:
			_last_refresh_time = 0.0
			_update_status_display()

func _ensure_components() -> void:
	name = "OptionPanel"
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -300.0
	offset_top = -210.0
	offset_right = -16.0
	offset_bottom = -16.0

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
		title_label.text = "Unit Info"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_vbox.add_child(title_label)

	if status_label == null:
		status_label = find_child("StatusLabel", true, false) as Label
	if status_label == null:
		status_label = Label.new()
		status_label.name = "StatusLabel"
		status_label.text = "Status"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	btn.custom_minimum_size = Vector2(120, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	button_container.add_child(btn)
	return btn

func _populate_hero_buttons() -> void:
	if current_menu == "default":
		# Level 1: [ Build ] and [ Stop ]
		_create_action_button(TranslationServer.translate("CMD_BUILD"), func():
			current_menu = "build"
			_refresh_ui()
		)
		_create_action_button(TranslationServer.translate("CMD_STOP"), func():
			if selected_unit and is_instance_valid(selected_unit) and selected_unit.has_method("order_stop"):
				selected_unit.order_stop()
		)
	elif current_menu == "build":
		# Level 2: [ Wall ], [ Tower ], [ Lumber Hut ], [ Back ]
		var cfg = _get_config()
		for b_type in ["wall", "tower", "lumber_hut"]:
			var b_name = Config.get_building_name(b_type) if (cfg and cfg.has_method("get_building_name")) else b_type
			var cost_wood: int = 2
			if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(b_type):
				cost_wood = int(cfg.BUILDINGS[b_type].get("cost", {}).get("wood", 2))
			var label_str = TranslationServer.translate("BUILD_COST_FORMAT") % [b_name, cost_wood]
			_create_action_button(label_str, func():
				_trigger_build(b_type)
			)
		
		_create_action_button(TranslationServer.translate("CMD_BACK"), func():
			current_menu = "default"
			_refresh_ui()
		)

func _populate_building_buttons() -> void:
	var is_producer: bool = (selected_unit is LumberHut) or ("is_operating" in selected_unit)
	if is_producer:
		_create_action_button(TranslationServer.translate("CMD_TEND"), func():
			var hero = _get_hero()
			if hero and is_instance_valid(hero) and hero.has_method("order_tend") and is_instance_valid(selected_unit):
				hero.order_tend(selected_unit)
				action_triggered.emit("tend", selected_unit)
		)

	_create_action_button(TranslationServer.translate("CMD_DEMOLISH"), func():
		if selected_unit and is_instance_valid(selected_unit) and selected_unit.has_method("demolish"):
			var unit_to_demolish = selected_unit
			clear_selection()
			unit_to_demolish.demolish()
	)

func _populate_resource_buttons() -> void:
	var is_depleted: bool = false
	if "is_depleted" in selected_unit:
		is_depleted = bool(selected_unit.is_depleted)
	
	if not is_depleted:
		_create_action_button(TranslationServer.translate("CMD_HARVEST"), func():
			var hero = _get_hero()
			if hero and is_instance_valid(hero) and hero.has_method("order_harvest") and is_instance_valid(selected_unit):
				hero.order_harvest(selected_unit)
				action_triggered.emit("harvest", selected_unit)
		)

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
