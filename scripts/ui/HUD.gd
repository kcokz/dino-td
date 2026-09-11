# res://scripts/ui/HUD.gd
class_name HUD
extends CanvasLayer

## Reactive Heads-Up Display for Defend Dinosaur v0.0.
## Listens strictly to EventBus signals to reflect runtime game state.
## Headless-safe: Supports running in headless mode and via direct HUD.new() tests.

# ==============================================================================
# Signals
# ==============================================================================
signal build_requested(building_type: String)
signal end_action_clicked()
signal restart_clicked()
signal restart_requested()

# ==============================================================================
# UI Node References
# ==============================================================================
var root_control: Control = null
var ap_label: Label = null
var wood_label: Label = null
var wave_label: Label = null
var core_hp_label: Label = null
var phase_label: Label = null

var build_tower_btn: Button = null
var build_wall_btn: Button = null
var build_lumber_btn: Button = null
var end_action_btn: Button = null

var game_over_panel: Control = null
var result_label: Label = null
var details_label: Label = null
var restart_btn: Button = null

var selected_build_type: String = ""

# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_ensure_ui_components()
	_update_building_button_labels()
	_connect_event_bus()
	_connect_buttons()
	reset_hud()

func _exit_tree() -> void:
	_disconnect_event_bus()

# ==============================================================================
# EventBus Listeners
# ==============================================================================

func _connect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb:
		if eb.has_signal("ap_changed") and not eb.ap_changed.is_connected(_on_ap_changed):
			eb.ap_changed.connect(_on_ap_changed)
		if eb.has_signal("resources_changed") and not eb.resources_changed.is_connected(_on_resources_changed):
			eb.resources_changed.connect(_on_resources_changed)
		if eb.has_signal("wave_started") and not eb.wave_started.is_connected(_on_wave_started):
			eb.wave_started.connect(_on_wave_started)
		if eb.has_signal("core_hp_changed") and not eb.core_hp_changed.is_connected(_on_core_hp_changed):
			eb.core_hp_changed.connect(_on_core_hp_changed)
		if eb.has_signal("phase_changed") and not eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.connect(_on_phase_changed)
		if eb.has_signal("game_won") and not eb.game_won.is_connected(_on_game_won):
			eb.game_won.connect(_on_game_won)
		if eb.has_signal("game_lost") and not eb.game_lost.is_connected(_on_game_lost):
			eb.game_lost.connect(_on_game_lost)

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
		if eb.has_signal("ap_changed") and eb.ap_changed.is_connected(_on_ap_changed):
			eb.ap_changed.disconnect(_on_ap_changed)
		if eb.has_signal("resources_changed") and eb.resources_changed.is_connected(_on_resources_changed):
			eb.resources_changed.disconnect(_on_resources_changed)
		if eb.has_signal("wave_started") and eb.wave_started.is_connected(_on_wave_started):
			eb.wave_started.disconnect(_on_wave_started)
		if eb.has_signal("core_hp_changed") and eb.core_hp_changed.is_connected(_on_core_hp_changed):
			eb.core_hp_changed.disconnect(_on_core_hp_changed)
		if eb.has_signal("phase_changed") and eb.phase_changed.is_connected(_on_phase_changed):
			eb.phase_changed.disconnect(_on_phase_changed)
		if eb.has_signal("game_won") and eb.game_won.is_connected(_on_game_won):
			eb.game_won.disconnect(_on_game_won)
		if eb.has_signal("game_lost") and eb.game_lost.is_connected(_on_game_lost):
			eb.game_lost.disconnect(_on_game_lost)

func _on_ap_changed(cur: int, max_val: int) -> void:
	if ap_label:
		ap_label.text = "AP: %d / %d" % [cur, max_val]

func _on_resources_changed(res: Dictionary) -> void:
	if wood_label:
		var wood = res.get("wood", 0)
		wood_label.text = "Wood: %d" % wood

func _on_wave_started(n: int, is_big: bool) -> void:
	if wave_label:
		wave_label.text = "Wave: %d%s" % [n, " (大波!)" if is_big else ""]

func _on_core_hp_changed(cur: float, max_val: float) -> void:
	if core_hp_label:
		core_hp_label.text = "Core HP: %d / %d" % [int(ceil(cur)), int(ceil(max_val))]

func _on_phase_changed(phase_idx: int) -> void:
	var phase_names = ["PLAN", "ATTACK", "PRODUCE"]
	var p_str = phase_names[phase_idx] if (phase_idx >= 0 and phase_idx < phase_names.size()) else "UNKNOWN"
	if phase_label:
		phase_label.text = "Phase: %s" % p_str

	var gs = _get_game_state()
	var is_game_over = gs and "is_game_over" in gs and gs.is_game_over
	var is_plan: bool = (phase_idx == 0) and not is_game_over
	_set_action_buttons_enabled(is_plan)

func _on_game_won() -> void:
	var gs = _get_game_state()
	if gs and gs.is_game_over and not gs.is_game_won:
		return
	if is_game_over_visible():
		return
	_show_game_over("VICTORY!", "恐龙巢穴已被消灭！")

func _on_game_lost() -> void:
	var gs = _get_game_state()
	if gs and gs.is_game_won:
		return
	if is_game_over_visible():
		return
	_show_game_over("DEFEAT!", "核心营火已被摧毁！")

func _show_game_over(title: String, details: String) -> void:
	if result_label:
		result_label.text = title
	if details_label:
		details_label.text = details
	if game_over_panel:
		game_over_panel.visible = true
	_set_action_buttons_enabled(false)

# ==============================================================================
# Button Callbacks & Actions
# ==============================================================================

func _connect_buttons() -> void:
	if build_tower_btn and not build_tower_btn.pressed.is_connected(_on_tower_btn_pressed):
		build_tower_btn.pressed.connect(_on_tower_btn_pressed)
	if build_wall_btn and not build_wall_btn.pressed.is_connected(_on_wall_btn_pressed):
		build_wall_btn.pressed.connect(_on_wall_btn_pressed)
	if build_lumber_btn and not build_lumber_btn.pressed.is_connected(_on_lumber_btn_pressed):
		build_lumber_btn.pressed.connect(_on_lumber_btn_pressed)
	if end_action_btn and not end_action_btn.pressed.is_connected(_on_end_action_pressed):
		end_action_btn.pressed.connect(_on_end_action_pressed)
	if restart_btn and not restart_btn.pressed.is_connected(_on_restart_pressed):
		restart_btn.pressed.connect(_on_restart_pressed)

func _on_tower_btn_pressed() -> void:
	select_build_type("tower")

func _on_wall_btn_pressed() -> void:
	select_build_type("wall")

func _on_lumber_btn_pressed() -> void:
	select_build_type("lumber_hut")

func select_build_type(type_id: String) -> void:
	selected_build_type = type_id
	build_requested.emit(type_id)

func _on_end_action_pressed() -> void:
	end_action_clicked.emit()
	var gs = _get_game_state()
	if gs and gs.has_method("trigger_end_action"):
		gs.trigger_end_action()

func _on_restart_pressed() -> void:
	restart_clicked.emit()
	restart_requested.emit()
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("restart_game"):
		parent_node.restart_game()

# ==============================================================================
# State Reset & Inspection API
# ==============================================================================

func reset_hud() -> void:
	selected_build_type = ""
	if game_over_panel:
		game_over_panel.visible = false

	# Synchronize baseline values from GameState & Config
	var gs = _get_game_state()
	var cfg = _get_config()

	_update_building_button_labels()

	var default_ap: int = cfg.BASE_AP if (cfg and "BASE_AP" in cfg) else 3
	var cur_ap: int = gs.current_ap if (gs and "current_ap" in gs) else default_ap
	var max_ap: int = gs.max_ap if (gs and "max_ap" in gs) else default_ap
	_on_ap_changed(cur_ap, max_ap)

	var default_res: Dictionary = cfg.INITIAL_RESOURCES if (cfg and "INITIAL_RESOURCES" in cfg) else {"wood": 10}
	var res_dict: Dictionary = gs.resources if (gs and "resources" in gs) else default_res
	_on_resources_changed(res_dict)

	var w_num: int = gs.wave_number if (gs and "wave_number" in gs) else 0
	_on_wave_started(w_num, false)

	var core_cfg: Dictionary = cfg.BUILDINGS.get("core", {}) if (cfg and "BUILDINGS" in cfg) else {}
	var c_hp: float = float(core_cfg.get("hp", 10.0))
	_on_core_hp_changed(c_hp, c_hp)

	var p_val: int = int(gs.current_phase) if (gs and "current_phase" in gs) else 0
	_on_phase_changed(p_val)

func _update_building_button_labels() -> void:
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not (cfg.BUILDINGS is Dictionary):
		return

	if build_wall_btn and cfg.BUILDINGS.has("wall"):
		var wall_data: Dictionary = cfg.BUILDINGS["wall"]
		var wall_name: String = wall_data.get("name", "木墙")
		var wall_cost: int = int(wall_data.get("cost", {}).get("wood", 2))
		build_wall_btn.text = "%s (%d木)" % [wall_name, wall_cost]

	if build_lumber_btn and cfg.BUILDINGS.has("lumber_hut"):
		var lumber_data: Dictionary = cfg.BUILDINGS["lumber_hut"]
		var lumber_name: String = lumber_data.get("name", "伐木屋")
		var lumber_cost: int = int(lumber_data.get("cost", {}).get("wood", 3))
		build_lumber_btn.text = "%s (%d木)" % [lumber_name, lumber_cost]

	if build_tower_btn and cfg.BUILDINGS.has("tower"):
		var tower_data: Dictionary = cfg.BUILDINGS["tower"]
		var tower_name: String = tower_data.get("name", "自动哨位")
		var tower_cost: int = int(tower_data.get("cost", {}).get("wood", 4))
		build_tower_btn.text = "%s (%d木)" % [tower_name, tower_cost]

func _set_action_buttons_enabled(enabled: bool) -> void:
	if build_tower_btn: build_tower_btn.disabled = not enabled
	if build_wall_btn: build_wall_btn.disabled = not enabled
	if build_lumber_btn: build_lumber_btn.disabled = not enabled
	if end_action_btn: end_action_btn.disabled = not enabled

# Testing Query API
func get_ap_text() -> String:
	return ap_label.text if ap_label else ""

func get_wood_text() -> String:
	return wood_label.text if wood_label else ""

func get_wave_text() -> String:
	return wave_label.text if wave_label else ""

func get_core_hp_text() -> String:
	return core_hp_label.text if core_hp_label else ""

func get_phase_text() -> String:
	return phase_label.text if phase_label else ""

func is_game_over_visible() -> bool:
	return game_over_panel.visible if game_over_panel else false

func get_game_over_title() -> String:
	return result_label.text if result_label else ""

func get_result_text() -> String:
	return get_game_over_title()

# Testing Simulation API
func simulate_end_action_click() -> void:
	_on_end_action_pressed()

func simulate_build_click(type_id: String) -> void:
	select_build_type(type_id)

func simulate_restart_click() -> void:
	_on_restart_pressed()

func trigger_build(type_id: String) -> void:
	select_build_type(type_id)

func trigger_end_action() -> void:
	_on_end_action_pressed()

func trigger_restart() -> void:
	_on_restart_pressed()

# ==============================================================================
# Procedural Component Fallbacks (Headless & Scene Support)
# ==============================================================================

func _ensure_ui_components() -> void:
	# Search existing scene tree first
	ap_label = find_child("APLabel", true, false) as Label
	wood_label = find_child("WoodLabel", true, false) as Label
	wave_label = find_child("WaveLabel", true, false) as Label
	core_hp_label = find_child("CoreHPLabel", true, false) as Label
	phase_label = find_child("PhaseLabel", true, false) as Label

	build_tower_btn = find_child("BuildTowerBtn", true, false) as Button
	build_wall_btn = find_child("BuildWallBtn", true, false) as Button
	build_lumber_btn = find_child("BuildLumberHutBtn", true, false) as Button
	end_action_btn = find_child("EndActionBtn", true, false) as Button

	game_over_panel = find_child("GameOverPanel", true, false) as Control
	if game_over_panel == null:
		game_over_panel = find_child("GameOverModal", true, false) as Control
	result_label = find_child("ResultTitle", true, false) as Label
	if result_label == null:
		result_label = find_child("ResultLabel", true, false) as Label
	details_label = find_child("ResultSubtitle", true, false) as Label
	if details_label == null:
		details_label = find_child("DetailsLabel", true, false) as Label
	restart_btn = find_child("RestartButton", true, false) as Button
	if restart_btn == null:
		restart_btn = find_child("RestartBtn", true, false) as Button

	# Procedural fallback creation if instantiated programmatically without .tscn
	if root_control == null:
		root_control = find_child("Root", true, false) as Control
	if root_control == null:
		root_control = Control.new()
		root_control.name = "Root"
		root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(root_control)

	if ap_label == null:
		ap_label = Label.new()
		ap_label.name = "APLabel"
		root_control.add_child(ap_label)

	if wood_label == null:
		wood_label = Label.new()
		wood_label.name = "WoodLabel"
		root_control.add_child(wood_label)

	if wave_label == null:
		wave_label = Label.new()
		wave_label.name = "WaveLabel"
		root_control.add_child(wave_label)

	if core_hp_label == null:
		core_hp_label = Label.new()
		core_hp_label.name = "CoreHPLabel"
		root_control.add_child(core_hp_label)

	if phase_label == null:
		phase_label = Label.new()
		phase_label.name = "PhaseLabel"
		root_control.add_child(phase_label)

	if build_tower_btn == null:
		build_tower_btn = Button.new()
		build_tower_btn.name = "BuildTowerBtn"
		root_control.add_child(build_tower_btn)

	if build_wall_btn == null:
		build_wall_btn = Button.new()
		build_wall_btn.name = "BuildWallBtn"
		root_control.add_child(build_wall_btn)

	if build_lumber_btn == null:
		build_lumber_btn = Button.new()
		build_lumber_btn.name = "BuildLumberHutBtn"
		root_control.add_child(build_lumber_btn)

	if end_action_btn == null:
		end_action_btn = Button.new()
		end_action_btn.name = "EndActionBtn"
		root_control.add_child(end_action_btn)

	if game_over_panel == null:
		game_over_panel = PanelContainer.new()
		game_over_panel.name = "GameOverPanel"
		game_over_panel.visible = false
		root_control.add_child(game_over_panel)

	if result_label == null:
		result_label = Label.new()
		result_label.name = "ResultTitle"
		game_over_panel.add_child(result_label)

	if details_label == null:
		details_label = Label.new()
		details_label.name = "ResultSubtitle"
		game_over_panel.add_child(details_label)

	if restart_btn == null:
		restart_btn = Button.new()
		restart_btn.name = "RestartButton"
		game_over_panel.add_child(restart_btn)

	_update_building_button_labels()

# ==============================================================================
# Resolvers
# ==============================================================================

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

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
