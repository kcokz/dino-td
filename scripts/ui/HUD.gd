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
## One readout per resource, built from Config.RESOURCES rather than written into the
## scene: there were five labels there, one per resource, and a sixth resource would
## have been a sixth node, a sixth variable and a sixth line in every handler (v0.6 T2).
var resource_bar: Container = null
var resource_labels: Dictionary = {}     # res_id -> Label
# The readouts every older caller asks for by name. They are entries of resource_labels.
var wood_label: Label = null
var stone_label: Label = null
var water_label: Label = null
var food_label: Label = null
var bone_label: Label = null
## What he last ate and how long it has left (v0.6 T3); hidden while he is not fed.
var fed_label: Label = null
## Where the beacon has got to (v0.6 T7): stages repaired, ready, or charging. Always on
## screen -- it is the run's main line (GAME-DESIGN 14.3, 6: how far is the goal).
var beacon_label: Label = null
var wave_label: Label = null
var core_hp_label: Label = null
var hero_hp_label: Label = null
var deploy_timer_label: Label = null
var phase_label: Label = null
var version_label: Label = null
## The line on the game-over screen. Kept as a reference for the same reason as the
## one in the top bar: it shows a version, so it has to be filled from AppInfo.
var version_badge: Label = null

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
		if eb.has_signal("fed_changed") and not eb.fed_changed.is_connected(_on_fed_changed):
			eb.fed_changed.connect(_on_fed_changed)
		if eb.has_signal("boss_warning") and not eb.boss_warning.is_connected(_on_boss_warning):
			eb.boss_warning.connect(_on_boss_warning)
		if eb.has_signal("boss_arrived") and not eb.boss_arrived.is_connected(_on_boss_arrived):
			eb.boss_arrived.connect(_on_boss_arrived)
		if eb.has_signal("beacon_changed") and not eb.beacon_changed.is_connected(_on_beacon_changed):
			eb.beacon_changed.connect(_on_beacon_changed)
		if eb.has_signal("beacon_launched") and not eb.beacon_launched.is_connected(_on_beacon_launched):
			eb.beacon_launched.connect(_on_beacon_launched)
		if eb.has_signal("raid_summary") and not eb.raid_summary.is_connected(_on_raid_summary):
			eb.raid_summary.connect(_on_raid_summary)
		if eb.has_signal("resource_picked_up") and not eb.resource_picked_up.is_connected(_on_resource_picked_up):
			eb.resource_picked_up.connect(_on_resource_picked_up)
		if eb.has_signal("unlock_granted") and not eb.unlock_granted.is_connected(_on_unlock_granted):
			eb.unlock_granted.connect(_on_unlock_granted)

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
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
		if eb.has_signal("fed_changed") and eb.fed_changed.is_connected(_on_fed_changed):
			eb.fed_changed.disconnect(_on_fed_changed)
		if eb.has_signal("boss_warning") and eb.boss_warning.is_connected(_on_boss_warning):
			eb.boss_warning.disconnect(_on_boss_warning)
		if eb.has_signal("boss_arrived") and eb.boss_arrived.is_connected(_on_boss_arrived):
			eb.boss_arrived.disconnect(_on_boss_arrived)
		if eb.has_signal("beacon_changed") and eb.beacon_changed.is_connected(_on_beacon_changed):
			eb.beacon_changed.disconnect(_on_beacon_changed)
		if eb.has_signal("beacon_launched") and eb.beacon_launched.is_connected(_on_beacon_launched):
			eb.beacon_launched.disconnect(_on_beacon_launched)
		if eb.has_signal("raid_summary") and eb.raid_summary.is_connected(_on_raid_summary):
			eb.raid_summary.disconnect(_on_raid_summary)
		if eb.has_signal("resource_picked_up") and eb.resource_picked_up.is_connected(_on_resource_picked_up):
			eb.resource_picked_up.disconnect(_on_resource_picked_up)
		if eb.has_signal("unlock_granted") and eb.unlock_granted.is_connected(_on_unlock_granted):
			eb.unlock_granted.disconnect(_on_unlock_granted)

func _on_locale_changed(_new_locale: String) -> void:
	reset_hud()

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
	for res_id in resource_labels:
		var lbl: Label = resource_labels[res_id]
		if lbl and is_instance_valid(lbl):
			lbl.text = tr("HUD_%s" % String(res_id).to_upper()) % int(res.get(res_id, 0))

## He ate, or the meal wore off. The countdown itself is _process's.
func _on_fed_changed(_fed: Dictionary) -> void:
	_refresh_fed_label()

func _process(_delta: float) -> void:
	if fed_label and fed_label.visible:
		_refresh_fed_label()
	var gs = _get_game_state()
	if gs and gs.has_method("is_beacon_launched") and gs.is_beacon_launched():
		_refresh_beacon_label()

## A stage repaired, or the launch. The charge's countdown is _process's.
func _on_beacon_changed(_steps_done: int) -> void:
	_refresh_beacon_label()

## Launched: everything in the valley is on its way, from every side (GAME-DESIGN 8.3).
func _on_beacon_launched() -> void:
	_refresh_beacon_label()
	show_hint(tr("HUD_BEACON_LAUNCHED"), 6.0)

## The materials he has picked up at least once this run, and which run that is: the first
## of each is when the game says what it is for (GAME-DESIGN 4.3 rule 2). Kept by seed, so
## a new run starts over and a change of language does not.
var _materials_seen: Dictionary = {}
var _materials_seen_run: int = -1

func _on_resource_picked_up(res_id: String, _amount: int, _by: Node) -> void:
	var gs = _get_game_state()
	var run: int = int(gs.run_seed) if (gs and "run_seed" in gs) else 0
	if run != _materials_seen_run:
		_materials_seen.clear()
		_materials_seen_run = run
	if _materials_seen.has(res_id):
		return
	_materials_seen[res_id] = true
	var uses: String = _uses_text(res_id)
	if uses != "":
		show_hint(tr("HINT_NEW_MATERIAL") % [tr("RESOURCE_%s" % res_id.to_upper()), uses], 6.0)

## Something made at the cabin: what it does, said as it is done -- "Made: Stone Axe --
## Wood x2" (GAME-DESIGN 14.2, path 4: did I get stronger).
func _on_unlock_granted(unlock_id: String) -> void:
	var cfg = _get_config()
	if cfg == null or not ("RECIPES" in cfg) or not cfg.has_method("recipe_effect_text"):
		return
	for recipe_id in cfg.RECIPES:
		if String(cfg.RECIPES[recipe_id].get("unlocks", "")) != unlock_id:
			continue
		var effect: String = String(cfg.recipe_effect_text(String(recipe_id)))
		if effect != "":
			show_hint(tr("HINT_MADE") % [tr(String(cfg.RECIPES[recipe_id].get("name", recipe_id))), effect], 5.0)
		return

func _uses_text(res_id: String) -> String:
	var cfg = _get_config()
	return String(cfg.uses_text(res_id, _run_map())) if (cfg and cfg.has_method("uses_text")) else ""

## Hovering a material on the bar says what it is for (GAME-DESIGN 4.3 rule 3).
func _refresh_resource_tooltips() -> void:
	for res_id in resource_labels:
		var lbl: Label = resource_labels[res_id]
		if lbl == null or not is_instance_valid(lbl):
			continue
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		var uses: String = _uses_text(String(res_id))
		lbl.tooltip_text = (tr("USES_OF") % [tr("RESOURCE_%s" % String(res_id).to_upper()), uses]) if uses != "" else ""

## A raid held: what it cost, said as it ends (v0.6 T8).
func _on_raid_summary(summary: Dictionary) -> void:
	show_hint(raid_summary_text(summary), 6.0)

## "Raid 4 over -- 7 killed · left 7 Bone, 7 Meat · lost 2 Wooden Stake".
func raid_summary_text(summary: Dictionary) -> String:
	var cfg = _get_config()
	var drops: PackedStringArray = []
	for res_id in summary.get("drops", {}):
		drops.append("%d %s" % [int(summary["drops"][res_id]), tr("RESOURCE_%s" % String(res_id).to_upper())])
	var lost: PackedStringArray = []
	for type_id in summary.get("lost", {}):
		var type_name: String = String(cfg.get_building_name(String(type_id))) if cfg else String(type_id)
		lost.append("%d %s" % [int(summary["lost"][type_id]), type_name])
	return tr("HUD_RAID_SUMMARY") % [int(summary.get("wave", 0)), int(summary.get("killed", 0)),
		", ".join(drops) if not drops.is_empty() else tr("HUD_NOTHING"),
		", ".join(lost) if not lost.is_empty() else tr("HUD_NOTHING")]

## The run in two lines, for the result screen: how long, how many raids held and killed,
## and where his time went (v0.6 T9).
func run_summary_text(stats: Node) -> String:
	var secs: int = int(stats.run_seconds)
	var text: String = tr("RUN_SUMMARY") % [secs / 60, secs % 60, int(stats.raids_held), int(stats.killed)]
	var shares: Dictionary = stats.time_shares()
	var parts: PackedStringArray = []
	for activity in stats.ACTIVITIES:
		var percent: int = int(round(float(shares.get(activity, 0.0)) * 100.0))
		if percent > 0:
			parts.append(tr("ACTIVITY_%s" % String(activity).to_upper()) % percent)
	if not parts.is_empty():
		text += "\n" + tr("RUN_TIME_SHARE") % " · ".join(parts)
	return text

## "Beacon: 1/3 stages repaired", "... ready to launch", "Beacon charging 45% · 1:39" --
## Config.beacon_status, which the beacon's bench says too. Hidden on a map without one.
func _refresh_beacon_label() -> void:
	if beacon_label == null or not is_instance_valid(beacon_label):
		return
	var gs = _get_game_state()
	var cfg = _get_config()
	var text: String = ""
	if gs and cfg and cfg.has_method("beacon_status") and gs.has_method("map_data"):
		text = String(cfg.beacon_status(gs.map_data(), int(gs.beacon_steps), float(gs.beacon_charge)))
	beacon_label.text = text
	beacon_label.visible = text != ""

## "Fed: builds x1.3 · 1:25" while a meal's speeds last -- how much faster, and for how
## long (GAME-DESIGN 4.6: make the gain visible). Nothing at all when he is not fed.
func _refresh_fed_label() -> void:
	if fed_label == null or not is_instance_valid(fed_label):
		return
	var gs = _get_game_state()
	var cfg = _get_config()
	var fed: Dictionary = gs.fed if (gs and "fed" in gs) else {}
	if fed.is_empty() or cfg == null or not cfg.has_method("describe_meal"):
		fed_label.visible = false
		return
	var left: int = int(ceil(maxf(0.0, float(fed.get("seconds_left", 0.0)))))
	fed_label.text = tr("HUD_FED") % [cfg.describe_meal(fed, false), left / 60, left % 60]
	fed_label.visible = true

func _on_wave_started(n: int, is_big: bool) -> void:
	if wave_label:
		wave_label.text = tr("HUD_BIG_WAVE") % n if is_big else tr("HUD_WAVE") % n
	if raid_warning_banner:
		raid_warning_banner.visible = false
	_bosses_coming.clear()

## The bosses the coming raid brings, by name, said with its warning (v0.6, GAME-DESIGN
## 7.5: a boss coming is announced) -- and the seconds the warning gave.
var _bosses_coming: PackedStringArray = []
var _raid_seconds: int = 0

func _render_raid_banner() -> void:
	if raid_warning_banner == null:
		return
	var text: String = tr("HUD_RAID_WARNING") % _raid_seconds
	if not _bosses_coming.is_empty():
		text += "  " + tr("HUD_RAID_BOSS") % ", ".join(_bosses_coming)
	raid_warning_banner.text = text

func _on_boss_warning(species_id: String) -> void:
	var cfg = _get_config()
	var boss_name: String = String(cfg.get_dino_name(species_id)) if (cfg and cfg.has_method("get_dino_name")) else species_id
	if not _bosses_coming.has(boss_name):
		_bosses_coming.append(boss_name)
	if raid_warning_banner and raid_warning_banner.visible:
		_render_raid_banner()

func _on_boss_arrived(dino: Node) -> void:
	var cfg = _get_config()
	var species: String = String(dino.dino_type) if (dino and "dino_type" in dino) else ""
	var boss_name: String = String(cfg.get_dino_name(species)) if (cfg and cfg.has_method("get_dino_name")) else species
	show_hint(tr("HUD_BOSS_ARRIVED") % boss_name)

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
	_raid_seconds = int(ceil(time_left))
	_render_raid_banner()

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
	# The run's account under the verdict, when there is one to give.
	var stats = get_tree().get_first_node_in_group(RunStats.GROUP) if is_inside_tree() else null
	if stats != null:
		details += "\n\n" + run_summary_text(stats)
	if details_label:
		details_label.text = details
	if game_over_panel:
		game_over_panel.visible = true
		# On top of everything else on the screen -- and the selection panel out of the way:
		# it was added after the result, drew over it and hid half of the restart button,
		# and once the run is over there is nothing left to select.
		game_over_panel.move_to_front()
	if option_panel and is_instance_valid(option_panel):
		option_panel.visible = false
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
		option_panel.visible = true
		option_panel.clear_selection()

	# Synchronize baseline values from GameState & Config
	var gs = _get_game_state()
	var cfg = _get_config()


	var default_res: Dictionary = cfg.INITIAL_RESOURCES if (cfg and "INITIAL_RESOURCES" in cfg) else {"wood": 10}
	var res_dict: Dictionary = gs.resources if (gs and "resources" in gs) else default_res
	_on_resources_changed(res_dict)
	_refresh_fed_label()
	_refresh_beacon_label()
	_refresh_resource_tooltips()

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

## A readout per resource in Config.RESOURCES, in that order, named "<Resource>Label"
## (WoodLabel, PrimeMeatLabel). The labels callers already know by name stay as fields.
##
## A resource that is for nothing in this game is not shown at all (GAME-DESIGN 4.3
## rule 1) -- in v0.6 that is water: the river is scenery until it has a use. Showing a
## counter the player can do nothing with is a question the game cannot answer.
## The map this run is played on (GameState.map_data), or {} before there is one.
func _run_map() -> Dictionary:
	var gs = _get_game_state()
	return gs.map_data() if (gs and gs.has_method("map_data")) else {}

func _ensure_resource_labels() -> void:
	resource_labels.clear()
	var cfg = _get_config()
	var ids: Array = cfg.RESOURCES if (cfg and "RESOURCES" in cfg) else []
	for res_id in ids:
		var node_name: String = "%sLabel" % String(res_id).to_pascal_case()
		var lbl: Label = resource_bar.get_node_or_null(node_name) as Label
		if lbl == null:
			lbl = Label.new()
			lbl.name = node_name
			resource_bar.add_child(lbl)
		lbl.visible = not cfg.has_method("uses_of") or not cfg.uses_of(String(res_id), _run_map()).is_empty()
		resource_labels[String(res_id)] = lbl
	wood_label = resource_labels.get("wood")
	stone_label = resource_labels.get("stone")
	water_label = resource_labels.get("water")
	food_label = resource_labels.get("food")
	bone_label = resource_labels.get("bone")

func _ensure_ui_components() -> void:
	# Search existing scene tree first
	resource_bar = find_child("ResourceBar", true, false) as Container
	fed_label = find_child("FedLabel", true, false) as Label
	beacon_label = find_child("BeaconLabel", true, false) as Label
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

	if resource_bar == null:
		resource_bar = HBoxContainer.new()
		resource_bar.name = "ResourceBar"
		root_control.add_child(resource_bar)
	_ensure_resource_labels()

	if fed_label == null:
		fed_label = Label.new()
		fed_label.name = "FedLabel"
		fed_label.visible = false
		root_control.add_child(fed_label)

	if beacon_label == null:
		beacon_label = Label.new()
		beacon_label.name = "BeaconLabel"
		beacon_label.visible = false
		root_control.add_child(beacon_label)

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

	# Both places the player can read a version, filled from the one source.
	#
	# The fallback is AppInfo.VERSION, which is the string "unknown" on purpose. It used
	# to be the literal "v0.0" here, which is the whole problem in miniature: a
	# plausible-looking version is indistinguishable from a real one, so nobody ever
	# notices it is stale. "unknown" is impossible to mistake for the truth.
	var app_info_script = load("res://scripts/core/AppInfo.gd")
	var v_str: String = AppInfo.VERSION
	var title_str: String = AppInfo.APP_NAME
	if app_info_script and app_info_script.has_method("get_version"):
		v_str = app_info_script.get_version()
	if app_info_script and app_info_script.has_method("get_app_title"):
		title_str = app_info_script.get_app_title()
	version_label.text = v_str

	# The badge on the game-over screen. Nothing had ever set it, so it showed whatever
	# the scene file was saved with -- "Defend Dinosaur v0.2", for three versions.
	if version_badge == null:
		version_badge = find_child("VersionBadge", true, false) as Label
	if version_badge != null:
		version_badge.text = title_str

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
	if cfg and "TIME" in cfg and cfg.TIME is Dictionary:
		init_dep = float(cfg.TIME.get("deploy_length", 90.0))
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

	for lbl in resource_labels.values() + [wave_label, core_hp_label, hero_hp_label, fed_label,
			beacon_label, deploy_timer_label, phase_label, version_label, hint_label, raid_warning_banner]:
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
## so phase-era top-bar controls (deploy countdown, phase name, "end deployment") and
## the wave counter no longer describe anything the player acts on directly. They stay
## instantiated for API compatibility until legacy systems are deleted, but are hidden
## from the player.
func _hide_legacy_phase_controls() -> void:
	for ctrl in [deploy_timer_label, phase_label, end_action_btn, wave_label]:
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
