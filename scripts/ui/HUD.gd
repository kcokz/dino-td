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
signal pause_clicked()

# ==============================================================================
# UI Node References
# ==============================================================================
var root_control: Control = null
var ap_label: Label = null
var wood_label: Label = null
var stone_label: Label = null
var water_label: Label = null
var food_label: Label = null
var wave_label: Label = null
var core_hp_label: Label = null
var hero_hp_label: Label = null
var deploy_timer_label: Label = null
var phase_label: Label = null
var version_label: Label = null

var end_action_btn: Button = null
var pause_btn: Button = null
var speed_btn: Button = null
var raid_warning_banner: Label = null
var option_panel: Node = null
var pause_menu: Node = null
var _raid_horn_sounded: bool = false

var current_speed: float = 1.0
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

var game_over_panel: Control = null
var result_label: Label = null
var details_label: Label = null
var restart_btn: Button = null

var hint_label: Label = null
var _hint_timer: Timer = null
var selected_build_type: String = ""

# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_ensure_ui_components()
	_apply_ui_scale()
	_hide_legacy_phase_controls()
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
		if eb.has_signal("deploy_time_changed") and not eb.deploy_time_changed.is_connected(_on_deploy_time_changed):
			eb.deploy_time_changed.connect(_on_deploy_time_changed)
		if eb.has_signal("pause_toggled") and not eb.pause_toggled.is_connected(_on_pause_toggled):
			eb.pause_toggled.connect(_on_pause_toggled)
		if eb.has_signal("hero_hp_changed") and not eb.hero_hp_changed.is_connected(_on_hero_hp_changed):
			eb.hero_hp_changed.connect(_on_hero_hp_changed)
		if eb.has_signal("locale_changed") and not eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.connect(_on_locale_changed)
		if eb.has_signal("raid_warning") and not eb.raid_warning.is_connected(_on_raid_warning):
			eb.raid_warning.connect(_on_raid_warning)

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
		if eb.has_signal("deploy_time_changed") and eb.deploy_time_changed.is_connected(_on_deploy_time_changed):
			eb.deploy_time_changed.disconnect(_on_deploy_time_changed)
		if eb.has_signal("pause_toggled") and eb.pause_toggled.is_connected(_on_pause_toggled):
			eb.pause_toggled.disconnect(_on_pause_toggled)
		if eb.has_signal("hero_hp_changed") and eb.hero_hp_changed.is_connected(_on_hero_hp_changed):
			eb.hero_hp_changed.disconnect(_on_hero_hp_changed)
		if eb.has_signal("locale_changed") and eb.locale_changed.is_connected(_on_locale_changed):
			eb.locale_changed.disconnect(_on_locale_changed)
		if eb.has_signal("raid_warning") and eb.raid_warning.is_connected(_on_raid_warning):
			eb.raid_warning.disconnect(_on_raid_warning)

func _on_locale_changed(_new_locale: String) -> void:
	reset_hud()

func _on_ap_changed(cur: int, max_val: int) -> void:
	if ap_label:
		ap_label.text = tr("HUD_AP") % [cur, max_val]
		ap_label.visible = false
	var vsep1 = find_child("VSeparator1", true, false)
	if vsep1:
		vsep1.visible = false

func _on_deploy_time_changed(remaining: float, _total: float) -> void:
	if deploy_timer_label:
		deploy_timer_label.text = tr("HUD_DEPLOY_TIMER") % remaining

func _on_pause_toggled(is_paused: bool) -> void:
	if pause_btn:
		pause_btn.text = tr("HUD_RESUME_BTN") if is_paused else tr("HUD_PAUSE_BTN")

func _on_hero_hp_changed(cur: float, max_val: float) -> void:
	if hero_hp_label:
		hero_hp_label.text = tr("HUD_HERO_HP") % [int(ceil(cur)), int(ceil(max_val))]

func _on_resources_changed(res: Dictionary) -> void:
	if wood_label:
		wood_label.text = tr("HUD_WOOD") % int(res.get("wood", 0))
	if stone_label:
		stone_label.text = tr("HUD_STONE") % int(res.get("stone", 0))
	if water_label:
		water_label.text = tr("HUD_WATER") % int(res.get("water", 0))
	# Meat exists as of v0.3 (dinosaurs drop it), so it has a readout like the rest.
	if food_label:
		food_label.text = tr("HUD_FOOD") % int(res.get("food", 0))

func _on_wave_started(n: int, is_big: bool) -> void:
	if wave_label:
		wave_label.text = tr("HUD_BIG_WAVE") % n if is_big else tr("HUD_WAVE") % n
	if raid_warning_banner:
		raid_warning_banner.visible = false

func _on_raid_warning(time_left: float) -> void:
	if raid_warning_banner == null:
		return
	if time_left <= 0.0:
		raid_warning_banner.visible = false
		_raid_horn_sounded = false
		return
	# Sound the horn once as the warning appears, not on every countdown tick.
	if not _raid_horn_sounded:
		_raid_horn_sounded = true
		var fx = get_node_or_null("/root/Fx")
		if fx:
			fx.play(fx.Sound.RAID_WARNING)
	raid_warning_banner.visible = true
	raid_warning_banner.text = tr("HUD_RAID_WARNING") % int(ceil(time_left))

func _on_speed_btn_pressed() -> void:
	var cur_idx = SPEEDS.find(current_speed)
	if cur_idx == -1:
		cur_idx = 0
	var next_idx = (cur_idx + 1) % SPEEDS.size()
	set_game_speed(SPEEDS[next_idx])

func set_game_speed(multiplier: float) -> void:
	current_speed = multiplier
	Engine.time_scale = current_speed
	_update_speed_btn_label()
	var eb = _get_event_bus()
	if eb and eb.has_signal("game_speed_changed"):
		eb.game_speed_changed.emit(current_speed)

func _update_speed_btn_label() -> void:
	if speed_btn:
		speed_btn.text = tr("HUD_SPEED_BTN") % str(int(current_speed))

func _on_core_hp_changed(cur: float, max_val: float) -> void:
	if core_hp_label:
		core_hp_label.text = tr("HUD_CORE_HP") % [int(ceil(cur)), int(ceil(max_val))]

func _on_phase_changed(phase_idx: int) -> void:
	var phase_names = ["PLAN", "ATTACK", "PRODUCE"]
	var p_str = phase_names[phase_idx] if (phase_idx >= 0 and phase_idx < phase_names.size()) else "UNKNOWN"
	if phase_label:
		phase_label.text = tr("HUD_PHASE") % p_str

	var gs = _get_game_state()
	var is_game_over = gs and "is_game_over" in gs and gs.is_game_over
	var is_plan: bool = (phase_idx == 0) and not is_game_over
	_set_action_buttons_enabled(is_plan)
	if pause_btn:
		pause_btn.disabled = not is_plan

func _on_game_won() -> void:
	var gs = _get_game_state()
	if gs and gs.is_game_over and not gs.is_game_won:
		return
	if is_game_over_visible():
		return
	_show_game_over(tr("GAME_VICTORY_TITLE"), tr("GAME_VICTORY_DESC"))

func _on_game_lost() -> void:
	var gs = _get_game_state()
	if gs and gs.is_game_won:
		return
	if is_game_over_visible():
		return
	_show_game_over(tr("GAME_DEFEAT_TITLE"), tr("GAME_DEFEAT_DESC"))

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
	if end_action_btn and not end_action_btn.pressed.is_connected(_on_end_action_pressed):
		end_action_btn.pressed.connect(_on_end_action_pressed)
	if restart_btn and not restart_btn.pressed.is_connected(_on_restart_pressed):
		restart_btn.pressed.connect(_on_restart_pressed)
	if pause_btn and not pause_btn.pressed.is_connected(_on_pause_pressed):
		pause_btn.pressed.connect(_on_pause_pressed)

func _on_pause_pressed() -> void:
	pause_clicked.emit()
	var gs = _get_game_state()
	if gs and gs.has_method("toggle_pause"):
		gs.toggle_pause()

func _on_speed_button_pressed() -> void:
	_on_speed_btn_pressed()

func _check_ap_hint() -> void:
	var gs = _get_game_state()
	if gs and "infinite_ap" in gs and gs.infinite_ap:
		return
	if gs and "current_ap" in gs and gs.current_ap <= 0:
		show_hint(tr("HINT_NO_AP"))

func select_build_type(type_id: String) -> void:
	selected_build_type = type_id
	build_requested.emit(type_id)

func deselect_build() -> void:
	selected_build_type = ""
	build_requested.emit("")

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
	if raid_warning_banner:
		raid_warning_banner.visible = false
	_update_speed_btn_label()
	if option_panel and is_instance_valid(option_panel) and option_panel.has_method("clear_selection"):
		option_panel.clear_selection()

	# Synchronize baseline values from GameState & Config
	var gs = _get_game_state()
	var cfg = _get_config()


	var default_ap: int = cfg.BASE_AP if (cfg and "BASE_AP" in cfg) else 3
	var cur_ap: int = gs.current_ap if (gs and "current_ap" in gs) else default_ap
	var max_ap: int = gs.max_ap if (gs and "max_ap" in gs) else default_ap
	_on_ap_changed(cur_ap, max_ap)

	if ap_label:
		ap_label.visible = false
	var vsep1 = find_child("VSeparator1", true, false)
	if vsep1:
		vsep1.visible = false

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

	var rem_time: float = float(gs.remaining_deploy_time) if (gs and "remaining_deploy_time" in gs) else 90.0
	var tot_time: float = float(gs.deploy_length) if (gs and "deploy_length" in gs) else 90.0
	_on_deploy_time_changed(rem_time, tot_time)

	var is_p: bool = bool(gs.is_paused) if (gs and "is_paused" in gs) else false
	_on_pause_toggled(is_p)

	_on_hero_hp_changed(10.0, 10.0)

	if end_action_btn:
		end_action_btn.text = tr("HUD_END_DEPLOY_BTN")

	if restart_btn:
		restart_btn.text = tr("BTN_RESTART")

	_hide_legacy_phase_controls()

func show_hint(msg: String, duration: float = 2.5) -> void:
	if hint_label == null:
		_ensure_ui_components()
	if hint_label == null:
		return
	hint_label.text = msg
	hint_label.visible = true
	if _hint_timer == null or not is_instance_valid(_hint_timer):
		_hint_timer = Timer.new()
		_hint_timer.name = "HintTimer"
		_hint_timer.one_shot = true
		_hint_timer.timeout.connect(func(): if hint_label and is_instance_valid(hint_label): hint_label.visible = false)
		add_child(_hint_timer)
	_hint_timer.start(duration)

func get_hint_text() -> String:
	return hint_label.text if (hint_label and hint_label.visible) else ""

func _set_action_buttons_enabled(enabled: bool) -> void:
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

func get_version_text() -> String:
	return version_label.text if version_label else ""

# ==============================================================================
# Procedural Component Fallbacks (Headless & Scene Support)
# ==============================================================================

func _ensure_ui_components() -> void:
	# Search existing scene tree first
	ap_label = find_child("APLabel", true, false) as Label
	wood_label = find_child("WoodLabel", true, false) as Label
	stone_label = find_child("StoneLabel", true, false) as Label
	water_label = find_child("WaterLabel", true, false) as Label
	food_label = find_child("FoodLabel", true, false) as Label
	wave_label = find_child("WaveLabel", true, false) as Label
	core_hp_label = find_child("CoreHPLabel", true, false) as Label
	phase_label = find_child("PhaseLabel", true, false) as Label
	hint_label = find_child("HintLabel", true, false) as Label
	version_label = find_child("VersionLabel", true, false) as Label
	deploy_timer_label = find_child("DeployTimerLabel", true, false) as Label
	hero_hp_label = find_child("HeroHPLabel", true, false) as Label

	end_action_btn = find_child("EndActionBtn", true, false) as Button
	pause_btn = find_child("PauseBtn", true, false) as Button

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

	if stone_label == null:
		stone_label = Label.new()
		stone_label.name = "StoneLabel"
		root_control.add_child(stone_label)

	if water_label == null:
		water_label = Label.new()
		water_label.name = "WaterLabel"
		root_control.add_child(water_label)

	if food_label == null:
		food_label = Label.new()
		food_label.name = "FoodLabel"
		root_control.add_child(food_label)

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

	if version_label == null:
		version_label = Label.new()
		version_label.name = "VersionLabel"
		root_control.add_child(version_label)

	var app_info_script = load("res://scripts/core/AppInfo.gd")
	var v_str: String = "v0.0"
	if app_info_script and app_info_script.has_method("get_version"):
		v_str = app_info_script.get_version()
	version_label.text = v_str

	if hint_label == null:
		hint_label = Label.new()
		hint_label.name = "HintLabel"
		hint_label.visible = false
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		hint_label.position = Vector2(0, 70)
		root_control.add_child(hint_label)

	if end_action_btn == null:
		end_action_btn = Button.new()
		end_action_btn.name = "EndActionBtn"
		root_control.add_child(end_action_btn)
	end_action_btn.text = tr("HUD_END_DEPLOY_BTN")

	if deploy_timer_label == null:
		deploy_timer_label = Label.new()
		deploy_timer_label.name = "DeployTimerLabel"
		root_control.add_child(deploy_timer_label)
	var init_dep: float = 90.0
	var cfg = _get_config()
	if cfg and "MAP" in cfg and cfg.MAP is Dictionary:
		init_dep = float(cfg.MAP.get("deploy_length", 90.0))
	deploy_timer_label.text = tr("HUD_DEPLOY_TIMER") % init_dep

	if hero_hp_label == null:
		hero_hp_label = Label.new()
		hero_hp_label.name = "HeroHPLabel"
		root_control.add_child(hero_hp_label)
	hero_hp_label.text = tr("HUD_HERO_HP") % [10, 10]

	if pause_btn == null:
		pause_btn = Button.new()
		pause_btn.name = "PauseBtn"
		root_control.add_child(pause_btn)
	pause_btn.text = tr("HUD_PAUSE_BTN")

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

	if speed_btn == null:
		speed_btn = find_child("SpeedBtn", true, false) as Button
	if speed_btn == null:
		speed_btn = Button.new()
		speed_btn.name = "SpeedBtn"
		root_control.add_child(speed_btn)
	if not speed_btn.pressed.is_connected(_on_speed_btn_pressed):
		speed_btn.pressed.connect(_on_speed_btn_pressed)
	_update_speed_btn_label()

	if raid_warning_banner == null:
		raid_warning_banner = find_child("RaidWarningBanner", true, false) as Label
	if raid_warning_banner == null:
		raid_warning_banner = Label.new()
		raid_warning_banner.name = "RaidWarningBanner"
		raid_warning_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		raid_warning_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		raid_warning_banner.position = Vector2(0, 110)
		raid_warning_banner.add_theme_color_override("font_color", Color(1.0, 0.45, 0.1))
		raid_warning_banner.add_theme_font_size_override("font_size", 18)
		raid_warning_banner.visible = false
		root_control.add_child(raid_warning_banner)

	if pause_menu == null:
		pause_menu = find_child("PauseMenu", true, false)
	if pause_menu == null:
		var menu_script = load("res://scripts/ui/PauseMenu.gd")
		if menu_script:
			pause_menu = menu_script.new()
			root_control.add_child(pause_menu)

	if option_panel == null:
		option_panel = find_child("OptionPanel", true, false)
	if option_panel == null:
		var opt_script = load("res://scripts/ui/OptionPanel.gd")
		if opt_script:
			option_panel = opt_script.new()
			option_panel.name = "OptionPanel"
			root_control.add_child(option_panel)
			if option_panel.has_signal("build_option_selected"):
				option_panel.build_option_selected.connect(select_build_type)

	if ap_label:
		ap_label.visible = false
	var vsep1 = find_child("VSeparator1", true, false)
	if vsep1:
		vsep1.visible = false


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

# ==============================================================================
# Presentation: Config-driven font sizing & legacy control retirement
# ==============================================================================

## Applies Config.UI font sizes to every HUD control, overriding whatever the
## scene happens to specify. Keeps sizing in one place instead of per-node .tscn
## overrides, and keeps the scene and the headless fallback identical.
func _apply_ui_scale() -> void:
	var cfg = _get_config()
	if cfg == null or not ("UI" in cfg):
		return
	var label_size: int = int(cfg.UI.get("hud_font_size", 26))
	var button_size: int = int(cfg.UI.get("hud_button_font_size", 24))
	var title_size: int = int(cfg.UI.get("gameover_title_font_size", 48))

	for lbl in [ap_label, wood_label, stone_label, water_label, food_label, wave_label, core_hp_label, hero_hp_label,
			deploy_timer_label, phase_label, version_label, hint_label, raid_warning_banner]:
		if lbl and is_instance_valid(lbl):
			lbl.add_theme_font_size_override("font_size", label_size)

	for btn in [end_action_btn, pause_btn, speed_btn, restart_btn]:
		if btn and is_instance_valid(btn):
			btn.add_theme_font_size_override("font_size", button_size)

	if result_label and is_instance_valid(result_label):
		result_label.add_theme_font_size_override("font_size", title_size)
	if details_label and is_instance_valid(details_label):
		details_label.add_theme_font_size_override("font_size", label_size)

## v0.2 removed the deploy/attack/produce phases and made raids continuous/random,
## so phase-era top-bar controls (AP, deploy countdown, phase name, "end deployment")
## and the wave counter no longer describe anything the player acts on directly.
## They stay instantiated for API compatibility until legacy systems are deleted,
## but are hidden from the player.
func _hide_legacy_phase_controls() -> void:
	for ctrl in [ap_label, deploy_timer_label, phase_label, end_action_btn, wave_label]:
		if ctrl and is_instance_valid(ctrl):
			ctrl.visible = false
	var vsep3 = find_child("VSeparator3", true, false)
	if vsep3 and is_instance_valid(vsep3):
		vsep3.visible = false

## ESC handling lives in Main; this is the HUD's side of it.
func toggle_pause_menu() -> void:
	if pause_menu and is_instance_valid(pause_menu) and pause_menu.has_method("toggle"):
		pause_menu.toggle()

func is_pause_menu_open() -> bool:
	if pause_menu and is_instance_valid(pause_menu) and "is_open" in pause_menu:
		return bool(pause_menu.is_open)
	return false
