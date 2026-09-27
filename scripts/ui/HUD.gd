# res://scripts/ui/HUD.gd
class_name HUD
extends CanvasLayer

## The heads-up display: everything drawn over the world while a run is played.
##
## Laid out the way strategy games lay it out, in corners, with the middle of the screen
## left to the game (UI-POLISH T7-T10, T14, T15):
##   * top left   -- the materials, an icon and a count each; under them, the meal he is
##                   living on;
##   * top centre -- the cabin's health (lose it and the run is lost) and the Hero's, as
##                   bars; the cabin's pulses when it is nearly gone;
##   * top right  -- game speed, pause, the menu; under them the run's goal, the beacon;
##   * centre     -- what just happened (a toast) and what is coming (the raid banner);
##   * bottom right -- the command card (OptionPanel).
##
## All of it is built here in code, and all of it is styled by the one theme (UiTheme)
## set on the root: nothing below picks a colour or a size of its own. Every value it
## shows arrives over the EventBus; it never reaches into the game to find one.

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
## One chip per resource -- its icon and its count -- built from Config.RESOURCES: a new
## resource is a new chip without anyone writing one (v0.6 T2).
var resource_bar: Container = null
var resource_labels: Dictionary = {}     # res_id -> the count Label
var resource_chips: Dictionary = {}      # res_id -> the chip (icon + count)
# The readouts every older caller asks for by name. They are entries of resource_labels.
var wood_label: Label = null
var stone_label: Label = null
var water_label: Label = null
var food_label: Label = null
var bone_label: Label = null
## What he last ate and how long it has left (v0.6 T3); hidden while he is not fed.
var fed_label: Label = null
var fed_chip: Control = null
## Where the beacon has got to (v0.6 T7): stages repaired, ready, or charging. Always on
## screen -- it is the run's main line (GAME-DESIGN 14.3, 6: how far is the goal).
var beacon_label: Label = null
var objective_panel: Control = null
var beacon_pips: HBoxContainer = null
var beacon_bar: ProgressBar = null
var wave_label: Label = null
var core_hp_label: Label = null
var core_hp_bar: ProgressBar = null
var core_vital: Control = null
var hero_hp_label: Label = null
var hero_hp_bar: ProgressBar = null
var deploy_timer_label: Label = null
var phase_label: Label = null
var version_label: Label = null
## The line on the game-over screen. Kept as a reference for the same reason as the
## one in the corner: it shows a version, so it has to be filled from AppInfo.
var version_badge: Label = null

var end_action_btn: Button = null
var pause_btn: Button = null
## The game speed, as a row of segments with the chosen one lit (UI-POLISH T9). `speed_btn`
## is the first of them, for callers that knew the old single button.
var speed_btn: Button = null
var speed_buttons: Array[Button] = []
var menu_btn: Button = null
var raid_warning_banner: Label = null
var raid_warning_panel: Control = null
var option_panel: Node = null
var pause_menu: Node = null
## Inside the cabin: every bench at once (CabinScreen).
var cabin_screen: Control = null
var paused_overlay: Control = null
var _raid_horn_sounded: bool = false

var current_speed: float = 1.0
const SPEEDS: Array[float] = [1.0, 2.0, 3.0]

var game_over_panel: Control = null
var game_over_card: PanelContainer = null
var result_icon: TextureRect = null
var result_label: Label = null
var details_label: Label = null
var stats_row: HBoxContainer = null
var time_share_bar: HBoxContainer = null
var time_share_legend: Label = null
var restart_btn: Button = null
var quit_btn: Button = null

var hint_label: Label = null
var hint_toast: Control = null
var hint_icon: TextureRect = null
var _hint_timer: Timer = null
var selected_build_type: String = ""

var _core_ratio: float = 1.0
var _pulse_time: float = 0.0

# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_ensure_ui_components()
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
	if eb == null:
		return
	for pair in _bus_handlers(eb):
		if not (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).connect(pair[1])

func _disconnect_event_bus() -> void:
	var eb = _get_event_bus()
	if eb == null or not is_instance_valid(eb):
		return
	for pair in _bus_handlers(eb):
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])

## Every signal the HUD listens to, and who answers it.
func _bus_handlers(eb: Node) -> Array:
	var out: Array = []
	for pair in [["resources_changed", _on_resources_changed], ["wave_started", _on_wave_started],
			["core_hp_changed", _on_core_hp_changed], ["phase_changed", _on_phase_changed],
			["game_won", _on_game_won], ["game_lost", _on_game_lost],
			["deploy_time_changed", _on_deploy_time_changed], ["pause_toggled", _on_pause_toggled],
			["hero_hp_changed", _on_hero_hp_changed], ["locale_changed", _on_locale_changed],
			["raid_warning", _on_raid_warning], ["fed_changed", _on_fed_changed],
			["boss_warning", _on_boss_warning], ["boss_arrived", _on_boss_arrived],
			["beacon_changed", _on_beacon_changed], ["beacon_launched", _on_beacon_launched],
			["raid_summary", _on_raid_summary], ["resource_picked_up", _on_resource_picked_up],
			["unlock_granted", _on_unlock_granted], ["cabin_view_changed", _on_cabin_view_changed]]:
		if eb.has_signal(pair[0]):
			out.append([Signal(eb, pair[0]), pair[1]])
	return out

func _on_locale_changed(_new_locale: String) -> void:
	reset_hud()

## Inside, the room and its dock take the screen: the command card and the beacon card step
## aside -- the beacon's own bench says the same -- and the top row stays, raid warnings and
## all, because the world does not stop while he is in there.
func _on_cabin_view_changed(inside: bool) -> void:
	if option_panel and is_instance_valid(option_panel):
		option_panel.visible = not inside and not is_game_over_visible()
	if objective_panel:
		objective_panel.visible = not inside and beacon_label != null and beacon_label.text != ""
	# The dock runs along the bottom inside, where the version sits.
	if version_label:
		version_label.visible = not inside

func _on_leave_cabin() -> void:
	var main = get_parent()
	if main and main.has_method("leave_cabin"):
		main.leave_cabin()

func _on_deploy_time_changed(remaining: float, _total: float) -> void:
	if deploy_timer_label:
		deploy_timer_label.text = tr("HUD_DEPLOY_TIMER") % remaining

## Paused: the button says what pressing it will do, and the whole screen says the game is
## stopped -- a frame and a word, not just a changed button (UI-POLISH T9).
func _on_pause_toggled(is_paused: bool) -> void:
	if pause_btn:
		pause_btn.text = tr("HUD_RESUME") if is_paused else tr("HUD_PAUSE")
		pause_btn.icon = UiTheme.icon("play" if is_paused else "pause")
		pause_btn.tooltip_text = tr("HUD_RESUME_BTN") if is_paused else tr("HUD_PAUSE_BTN")
	_refresh_paused_overlay()

func _refresh_paused_overlay() -> void:
	if paused_overlay == null:
		return
	var gs = _get_game_state()
	var paused: bool = gs != null and "is_paused" in gs and bool(gs.is_paused)
	var over: bool = gs != null and "is_game_over" in gs and bool(gs.is_game_over)
	# The menu dims the screen itself; the frame is for a game paused with the menu shut.
	paused_overlay.visible = paused and not over and not is_pause_menu_open()

func _on_hero_hp_changed(cur: float, max_val: float) -> void:
	if hero_hp_label:
		hero_hp_label.text = UiKit.fraction_text(cur, max_val)
	if hero_hp_bar:
		var ratio: float = clampf(cur / max_val, 0.0, 1.0) if max_val > 0.0 else 0.0
		hero_hp_bar.value = ratio
		hero_hp_bar.theme_type_variation = UiTheme.health_bar(ratio)

## The counts, and income made visible: a count that went up flashes the accent colour and
## fades back, so a pickup is seen rather than searched for; an empty one is dimmed.
func _on_resources_changed(res: Dictionary) -> void:
	for res_id in resource_labels:
		var lbl: Label = resource_labels[res_id]
		if lbl == null or not is_instance_valid(lbl):
			continue
		var n: int = int(res.get(res_id, 0))
		var before: int = int(lbl.text) if lbl.text.is_valid_int() else n
		lbl.text = str(n)
		var chip: Control = resource_chips.get(res_id)
		if chip and is_instance_valid(chip):
			chip.modulate.a = 1.0 if n > 0 else 0.5
		if n > before and lbl.is_inside_tree():
			lbl.modulate = UiTheme.color("accent")
			var tw := lbl.create_tween()
			tw.tween_property(lbl, "modulate", Color.WHITE, UiTheme.number("flash_seconds"))

## He ate, or the meal wore off. The countdown itself is _process's.
func _on_fed_changed(_fed: Dictionary) -> void:
	_refresh_fed_label()

func _process(delta: float) -> void:
	if fed_label and fed_chip and fed_chip.visible:
		_refresh_fed_label()
	var gs = _get_game_state()
	if gs and gs.has_method("is_beacon_launched") and gs.is_beacon_launched():
		_refresh_beacon_label()
	# The cabin nearly gone: its readout pulses, a warning that does not depend on colour.
	if core_vital:
		if _core_ratio < UiTheme.number("hp_low_ratio"):
			_pulse_time += delta
			var floor_a: float = UiTheme.number("pulse_floor")
			core_vital.modulate.a = floor_a + (1.0 - floor_a) * (0.5 + 0.5 * cos(_pulse_time * UiTheme.number("pulse_speed")))
		else:
			_pulse_time = 0.0
			core_vital.modulate.a = 1.0

## A stage repaired, or the launch. The charge's countdown is _process's.
func _on_beacon_changed(_steps_done: int) -> void:
	_refresh_beacon_label()

## Launched: everything in the valley is on its way, from every side (GAME-DESIGN 8.3).
func _on_beacon_launched() -> void:
	_refresh_beacon_label()
	show_hint(tr("HUD_BEACON_LAUNCHED"), UiTheme.toast_seconds("long"), "warning")

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
		show_hint(tr("HINT_NEW_MATERIAL") % [tr("RESOURCE_%s" % res_id.to_upper()), uses], UiTheme.toast_seconds("long"), res_id)

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
			show_hint(tr("HINT_MADE") % [tr(String(cfg.RECIPES[recipe_id].get("name", recipe_id))), effect], UiTheme.toast_seconds("read"), "check")
		return

func _uses_text(res_id: String) -> String:
	var cfg = _get_config()
	return String(cfg.uses_text(res_id, _run_map())) if (cfg and cfg.has_method("uses_text")) else ""

## Hovering a material on the bar says what it is for (GAME-DESIGN 4.3 rule 3).
func _refresh_resource_tooltips() -> void:
	for res_id in resource_chips:
		var chip: Control = resource_chips[res_id]
		if chip == null or not is_instance_valid(chip):
			continue
		var uses: String = _uses_text(String(res_id))
		var res_name: String = tr("RESOURCE_%s" % String(res_id).to_upper())
		chip.tooltip_text = (tr("USES_OF") % [res_name, uses]) if uses != "" else res_name

## A raid held: what it cost, said as it ends (v0.6 T8).
func _on_raid_summary(summary: Dictionary) -> void:
	show_hint(raid_summary_text(summary), UiTheme.toast_seconds("long"), "check")

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

## "Beacon: 1/3 stages repaired", "... ready to launch", "Beacon charging 45% · 1:39" --
## Config.beacon_status, which the beacon's bench says too -- with a pip per stage and, once
## it is charging, the charge as a bar. Hidden on a map without one.
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
	if objective_panel:
		objective_panel.visible = text != "" and not (cabin_screen and cabin_screen.is_open)
	if text == "" or gs == null:
		return
	var stages: int = int(gs.beacon_stage_count()) if gs.has_method("beacon_stage_count") else 0
	var done: int = int(gs.beacon_stages_done()) if gs.has_method("beacon_stages_done") else 0
	_draw_pips(stages, done)
	var launched: bool = gs.has_method("is_beacon_launched") and gs.is_beacon_launched()
	if beacon_bar:
		beacon_bar.visible = launched
		if launched:
			beacon_bar.value = float(gs.beacon_charge_ratio())

## One pip per stage: lit when it stands repaired.
func _draw_pips(stages: int, done: int) -> void:
	if beacon_pips == null:
		return
	if beacon_pips.get_child_count() != stages:
		for child in beacon_pips.get_children():
			beacon_pips.remove_child(child)
			child.queue_free()
		for i in range(stages):
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(UiTheme.width("pip"), UiTheme.thickness("pip"))
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			beacon_pips.add_child(pip)
	for i in range(beacon_pips.get_child_count()):
		(beacon_pips.get_child(i) as Panel).theme_type_variation = &"PipOn" if i < done else &"PipOff"

## "Fed: builds x1.3 · 1:25" while a meal's speeds last -- how much faster, and for how
## long (GAME-DESIGN 4.6: make the gain visible). Nothing at all when he is not fed.
func _refresh_fed_label() -> void:
	if fed_label == null or not is_instance_valid(fed_label):
		return
	var gs = _get_game_state()
	var cfg = _get_config()
	var fed: Dictionary = gs.fed if (gs and "fed" in gs) else {}
	var shown: bool = not fed.is_empty() and cfg != null and cfg.has_method("describe_meal")
	if shown:
		var left: int = int(ceil(maxf(0.0, float(fed.get("seconds_left", 0.0)))))
		fed_label.text = tr("HUD_FED") % [cfg.describe_meal(fed, false), left / 60, left % 60]
	fed_label.visible = shown
	if fed_chip:
		fed_chip.visible = shown

func _on_wave_started(n: int, is_big: bool) -> void:
	if wave_label:
		wave_label.text = tr("HUD_BIG_WAVE") % n if is_big else tr("HUD_WAVE") % n
	if raid_warning_banner:
		raid_warning_banner.visible = false
	if raid_warning_panel:
		raid_warning_panel.visible = false
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
		text += "\n" + tr("HUD_RAID_BOSS") % ", ".join(_bosses_coming)
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
	show_hint(tr("HUD_BOSS_ARRIVED") % boss_name, UiTheme.toast_seconds("read"), "warning")

func _on_raid_warning(time_left: float) -> void:
	if raid_warning_banner == null:
		return
	if time_left <= 0.0:
		raid_warning_banner.visible = false
		if raid_warning_panel:
			raid_warning_panel.visible = false
		_raid_horn_sounded = false
		return
	# Sound the horn once as the warning appears, not on every countdown tick.
	var appearing: bool = not _raid_horn_sounded
	if not _raid_horn_sounded:
		_raid_horn_sounded = true
		var fx = get_node_or_null("/root/Fx")
		if fx:
			fx.play(fx.Sound.RAID_WARNING)
	raid_warning_banner.visible = true
	if raid_warning_panel:
		raid_warning_panel.visible = true
		if appearing:
			_pop_in(raid_warning_panel)
	_raid_seconds = int(ceil(time_left))
	_render_raid_banner()

func _on_speed_btn_pressed() -> void:
	var cur_idx = _speeds().find(current_speed)
	if cur_idx == -1:
		cur_idx = 0
	var next_idx = (cur_idx + 1) % _speeds().size()
	set_game_speed(_speeds()[next_idx])

func set_game_speed(multiplier: float) -> void:
	current_speed = multiplier
	Engine.time_scale = current_speed
	_update_speed_btn_label()
	var eb = _get_event_bus()
	if eb and eb.has_signal("game_speed_changed"):
		eb.game_speed_changed.emit(current_speed)

## The chosen speed lit, the others not.
func _update_speed_btn_label() -> void:
	var speeds: Array = _speeds()
	for i in range(speed_buttons.size()):
		if is_instance_valid(speed_buttons[i]):
			speed_buttons[i].set_pressed_no_signal(i < speeds.size() and is_equal_approx(float(speeds[i]), current_speed))

## The speeds on offer (Config.UI.game_speeds).
func _speeds() -> Array:
	var cfg = _get_config()
	if cfg and "UI" in cfg and cfg.UI.has("game_speeds"):
		return cfg.UI["game_speeds"]
	return SPEEDS

func _on_core_hp_changed(cur: float, max_val: float) -> void:
	if core_hp_label:
		core_hp_label.text = UiKit.fraction_text(cur, max_val)
	_core_ratio = clampf(cur / max_val, 0.0, 1.0) if max_val > 0.0 else 0.0
	if core_hp_bar:
		var dropped: bool = _core_ratio < core_hp_bar.value - 0.0001
		core_hp_bar.value = _core_ratio
		core_hp_bar.theme_type_variation = UiTheme.health_bar(_core_ratio)
		# A hit is felt: the readout jolts sideways and settles (UI-POLISH T8).
		if dropped and core_vital and core_vital.is_inside_tree():
			var tw := core_vital.create_tween()
			var at: float = core_vital.position.x
			for dx in [5.0, -4.0, 2.0, 0.0]:
				tw.tween_property(core_vital, "position:x", at + dx, 0.04)

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
	_show_game_over(tr("GAME_VICTORY_TITLE"), tr("GAME_VICTORY_DESC"), true)

func _on_game_lost() -> void:
	var gs = _get_game_state()
	if gs and gs.is_game_won:
		return
	if is_game_over_visible():
		return
	_show_game_over(tr("GAME_DEFEAT_TITLE"), tr("GAME_DEFEAT_DESC"), false)

## The end of the run: the verdict, told apart by more than colour -- a different icon, a
## different band across the card -- and the run's account under it (UI-POLISH T15).
func _show_game_over(title: String, details: String, won: bool = true) -> void:
	if result_label:
		result_label.text = title
	if details_label:
		details_label.text = details
	if game_over_card:
		game_over_card.theme_type_variation = &"VictoryPanel" if won else &"DefeatPanel"
	if result_icon:
		result_icon.texture = UiTheme.icon("beacon" if won else "warning")
		result_icon.modulate = Color.WHITE if won else UiTheme.color("danger")
	var stats = get_tree().get_first_node_in_group(RunStats.GROUP) if is_inside_tree() else null
	_fill_run_stats(stats)
	if game_over_panel:
		game_over_panel.visible = true
		# On top of everything else on the screen -- and the selection panel out of the way:
		# once the run is over there is nothing left to select.
		game_over_panel.move_to_front()
		_pop_in(game_over_card if game_over_card else game_over_panel)
	if option_panel and is_instance_valid(option_panel):
		option_panel.visible = false
	_set_action_buttons_enabled(false)
	_refresh_paused_overlay()

## How long, how many raids held, how many killed -- and where his time went, as one bar
## in proportion and a line naming the parts (v0.6 T9).
func _fill_run_stats(stats: Node) -> void:
	if stats_row == null:
		return
	stats_row.visible = stats != null
	if time_share_bar:
		time_share_bar.get_parent().visible = stats != null
	if stats == null:
		return
	var secs: int = int(stats.run_seconds)
	var values: Array = ["%d:%02d" % [secs / 60, secs % 60], str(int(stats.raids_held)), str(int(stats.killed))]
	for i in range(mini(values.size(), stats_row.get_child_count())):
		var block := stats_row.get_child(i)
		(block.get_node("Value") as Label).text = String(values[i])
	for child in time_share_bar.get_children():
		time_share_bar.remove_child(child)
		child.queue_free()
	var shares: Dictionary = stats.time_shares()
	var parts: PackedStringArray = []
	var tints: Array = [UiTheme.color("text_muted"), UiTheme.color("success"), UiTheme.color("warning"),
		UiTheme.color("danger"), UiTheme.color("tech"), UiTheme.color("text_faint")]
	var activities: Array = stats.ACTIVITIES
	for i in range(activities.size()):
		var share: float = float(shares.get(activities[i], 0.0))
		var percent: int = int(round(share * 100.0))
		if percent <= 0:
			continue
		var seg := ColorRect.new()
		seg.color = tints[i % tints.size()]
		seg.custom_minimum_size = Vector2(0, UiTheme.thickness("bar"))
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = maxf(0.001, share)
		time_share_bar.add_child(seg)
		parts.append(tr("ACTIVITY_%s" % String(activities[i]).to_upper()) % percent)
	time_share_legend.text = tr("RUN_TIME_SHARE") % " · ".join(parts) if not parts.is_empty() else ""

## Appears rather than blinks on: a quick fade and a little growth (UI-POLISH T10, T14).
func _pop_in(node: Control) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	node.modulate.a = 0.0
	node.scale = Vector2.ONE * UiTheme.number("pop_scale")
	var tw := node.create_tween().set_parallel(true)
	var t: float = UiTheme.number("pop_seconds")
	tw.tween_property(node, "modulate:a", 1.0, t)
	tw.tween_property(node, "scale", Vector2.ONE, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	if menu_btn and not menu_btn.pressed.is_connected(toggle_pause_menu):
		menu_btn.pressed.connect(toggle_pause_menu)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)

func _on_pause_pressed() -> void:
	pause_clicked.emit()
	var gs = _get_game_state()
	if gs and gs.has_method("toggle_pause"):
		gs.toggle_pause()

func _on_quit_pressed() -> void:
	if is_inside_tree():
		get_tree().quit()

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
	if raid_warning_panel:
		raid_warning_panel.visible = false
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
	_refresh_texts()

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

	var hero_max: float = float(cfg.HERO.get("hp", 10.0)) if (cfg and "HERO" in cfg) else 10.0
	_on_hero_hp_changed(hero_max, hero_max)

	if end_action_btn:
		end_action_btn.text = tr("HUD_END_DEPLOY_BTN")

	_hide_legacy_phase_controls()

## Every word the HUD shows that does not come with a value: filled again on a change of
## language.
func _refresh_texts() -> void:
	if restart_btn:
		restart_btn.text = tr("BTN_RESTART")
	if quit_btn:
		quit_btn.text = tr("MENU_QUIT")
	if menu_btn:
		menu_btn.tooltip_text = tr("HUD_MENU_TIP")
	if core_vital:
		core_vital.tooltip_text = tr("HUD_CABIN_TIP")
	var hero_vital = find_child("HeroVital", true, false)
	if hero_vital:
		hero_vital.tooltip_text = tr("HUD_HERO_TIP")
	var title = find_child("ObjectiveTitle", true, false) as Label
	if title:
		title.text = tr("HUD_OBJECTIVE_BEACON")
	if paused_overlay:
		(paused_overlay.find_child("PausedWord", true, false) as Label).text = tr("HUD_PAUSED")
	if stats_row:
		var captions: Array = ["RUN_STAT_TIME", "RUN_STAT_RAIDS", "RUN_STAT_KILLED"]
		for i in range(mini(captions.size(), stats_row.get_child_count())):
			(stats_row.get_child(i).get_node("Caption") as Label).text = tr(captions[i])
	for i in range(speed_buttons.size()):
		if is_instance_valid(speed_buttons[i]):
			speed_buttons[i].tooltip_text = tr("HUD_SPEED_TIP")

## A line in the middle of the screen for a few seconds -- what just happened. `icon_name`
## says what kind of news it is (a material's icon for a first pickup, a warning, a tick).
## A line in the toast under the top row, for `duration` seconds (a glance, unless the
## caller says it is worth longer: Config.THEME.toast_seconds).
func show_hint(msg: String, duration: float = -1.0, icon_name: String = "info") -> void:
	if duration < 0.0:
		duration = UiTheme.toast_seconds("glance")
	if hint_label == null:
		_ensure_ui_components()
	if hint_label == null:
		return
	hint_label.text = msg
	hint_label.visible = true
	# A short line sits on one row; a long one wraps inside a bounded width instead of
	# running the width of the screen.
	var width: float = UiTheme.font("regular").get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.font_size("body")).x
	var wrap_at: float = float(_ui("toast_max_width", 560))
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if width > wrap_at else TextServer.AUTOWRAP_OFF
	hint_label.custom_minimum_size.x = wrap_at if width > wrap_at else 0.0
	if hint_icon:
		hint_icon.texture = UiTheme.icon(icon_name)
		hint_icon.visible = hint_icon.texture != null
	if hint_toast:
		var was_shown: bool = hint_toast.visible
		hint_toast.visible = true
		if not was_shown:
			_pop_in(hint_toast)
	if _hint_timer == null or not is_instance_valid(_hint_timer):
		_hint_timer = Timer.new()
		_hint_timer.name = "HintTimer"
		_hint_timer.one_shot = true
		_hint_timer.timeout.connect(_hide_hint)
		add_child(_hint_timer)
	_hint_timer.start(duration)

func _hide_hint() -> void:
	if hint_label and is_instance_valid(hint_label):
		hint_label.visible = false
	if hint_toast and is_instance_valid(hint_toast):
		hint_toast.visible = false

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
# Construction
# ==============================================================================

## The map this run is played on (GameState.map_data), or {} before there is one.
func _run_map() -> Dictionary:
	var gs = _get_game_state()
	return gs.map_data() if (gs and gs.has_method("map_data")) else {}

## A chip per resource in Config.RESOURCES, in that order: its icon and its count, the
## count in figures of one width so it does not jostle its neighbours as it changes.
##
## A resource that is for nothing in this game is not shown at all (GAME-DESIGN 4.3
## rule 1) -- in v0.6 that is water: the river is scenery until it has a use. Showing a
## counter the player can do nothing with is a question the game cannot answer.
func _ensure_resource_labels() -> void:
	resource_labels.clear()
	resource_chips.clear()
	var cfg = _get_config()
	var ids: Array = cfg.RESOURCES if (cfg and "RESOURCES" in cfg) else []
	for res_id in ids:
		var key: String = String(res_id).to_pascal_case()
		var chip: HBoxContainer = resource_bar.get_node_or_null("%sChip" % key) as HBoxContainer
		if chip == null:
			chip = HBoxContainer.new()
			chip.name = "%sChip" % key
			chip.mouse_filter = Control.MOUSE_FILTER_PASS
			chip.add_theme_constant_override("separation", UiTheme.space("xs") + UiTheme.space("hair"))
			resource_bar.add_child(chip)
			chip.add_child(_icon("%sIcon" % key, String(res_id), UiTheme.icon_size("m")))
			var lbl := Label.new()
			lbl.name = "%sLabel" % key
			lbl.theme_type_variation = &"NumberLabel"
			lbl.text = "0"
			lbl.custom_minimum_size = Vector2(_ui("resource_count_width", 30), 0)
			chip.add_child(lbl)
		chip.visible = not cfg.has_method("uses_of") or not cfg.uses_of(String(res_id), _run_map()).is_empty()
		var count: Label = chip.get_node("%sLabel" % key) as Label
		count.visible = chip.visible
		resource_labels[String(res_id)] = count
		resource_chips[String(res_id)] = chip
	wood_label = resource_labels.get("wood")
	stone_label = resource_labels.get("stone")
	water_label = resource_labels.get("water")
	food_label = resource_labels.get("food")
	bone_label = resource_labels.get("bone")

func _ensure_ui_components() -> void:
	if root_control != null:
		return
	root_control = find_child("Root", false, false) as Control
	if root_control == null:
		root_control = Control.new()
		root_control.name = "Root"
		add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The one theme, set once here and inherited by everything below -- the command card
	# and the menus included.
	root_control.theme = UiTheme.get_theme()
	var edge: float = float(UiTheme.space("l"))

	# --- The cabin: first, so it is drawn under the rest. Its frosted backdrop blurs what is
	# behind it, and what is behind it should be the room -- not the stock, the vitals or a
	# raid's warning, which he needs to read while he chooses what to make.
	cabin_screen = CabinScreen.new()
	root_control.add_child(cabin_screen)
	cabin_screen.leave_requested.connect(_on_leave_cabin)

	# --- The top row: three columns in one container ------------------------------------
	# The two sides share what the middle leaves equally, so the vitals sit in the middle of
	# the screen -- and when the stock grows wider than its half, the row pushes them over
	# rather than letting the two run into each other.
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = edge
	top_bar.offset_right = -edge
	top_bar.offset_top = float(_ui("top_bar_top", 14))
	top_bar.offset_bottom = top_bar.offset_top
	top_bar.add_theme_constant_override("separation", UiTheme.space("s"))
	root_control.add_child(top_bar)

	# --- Top left: materials, and the meal he is living on ---------------------------
	var top_left := _vbox("TopLeft")
	top_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_left)
	var res_panel := _panel("ResourcePanel", &"PillPanel")
	res_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_left.add_child(res_panel)
	resource_bar = HBoxContainer.new()
	resource_bar.name = "ResourceBar"
	resource_bar.add_theme_constant_override("separation", UiTheme.space("l"))
	res_panel.add_child(resource_bar)
	_ensure_resource_labels()
	fed_chip = _panel("FedChip", &"PillPanel")
	fed_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fed_chip.visible = false
	top_left.add_child(fed_chip)
	var fed_row := HBoxContainer.new()
	fed_row.name = "FedRow"
	fed_chip.add_child(fed_row)
	var fed_icon := _icon("FedIcon", "fed", UiTheme.icon_size("s"))
	fed_icon.modulate = UiTheme.color("accent")
	fed_row.add_child(fed_icon)
	fed_label = _label("FedLabel", &"SmallNumberLabel", "")
	fed_row.add_child(fed_label)

	# --- Top centre: the cabin and the Hero -------------------------------------------
	var top_center := HBoxContainer.new()
	top_center.name = "TopCenter"
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_bar.add_child(top_center)
	var vitals_panel := _panel("VitalsPanel", &"PillPanel")
	top_center.add_child(vitals_panel)
	var vitals := HBoxContainer.new()
	vitals.name = "Vitals"
	vitals.add_theme_constant_override("separation", UiTheme.space("m"))
	vitals_panel.add_child(vitals)
	var core := _vital("CoreVital", "core", float(_ui("cabin_bar_width", 150)))
	vitals.add_child(core[0])
	core_vital = core[0]
	core_hp_bar = core[1]
	core_hp_label = core[2]
	core_hp_label.name = "CoreHPLabel"
	core_hp_bar.name = "CoreHPBar"
	vitals.add_child(VSeparator.new())
	var hero := _vital("HeroVital", "hero", float(_ui("hero_bar_width", 90)))
	vitals.add_child(hero[0])
	hero_hp_bar = hero[1]
	hero_hp_label = hero[2]
	hero_hp_label.name = "HeroHPLabel"
	hero_hp_bar.name = "HeroHPBar"

	# --- Top right: speed, pause, menu; and the goal under them ------------------------
	var top_right := VBoxContainer.new()
	top_right.name = "TopRight"
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_right.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_right.add_theme_constant_override("separation", UiTheme.space("s") + UiTheme.space("hair"))
	top_bar.add_child(top_right)
	var controls_panel := _panel("ControlsPanel", &"PillPanel")
	controls_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_right.add_child(controls_panel)
	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation", UiTheme.space("xs"))
	controls_panel.add_child(controls)
	var speed_group := HBoxContainer.new()
	speed_group.name = "SpeedGroup"
	speed_group.add_theme_constant_override("separation", UiTheme.space("hair"))
	controls.add_child(speed_group)
	var group := ButtonGroup.new()
	speed_buttons.clear()
	for s in _speeds():
		var seg := Button.new()
		seg.name = "Speed%dBtn" % int(s)
		seg.theme_type_variation = &"SegmentButton"
		seg.toggle_mode = true
		seg.button_group = group
		seg.text = "%s×" % (("%d" % int(s)) if is_equal_approx(float(s), round(float(s))) else ("%.1f" % float(s)))
		seg.custom_minimum_size = Vector2(UiTheme.width("segment"), UiTheme.height("bar"))
		var speed: float = float(s)
		seg.pressed.connect(func(): set_game_speed(speed))
		speed_group.add_child(seg)
		speed_buttons.append(seg)
	speed_btn = speed_buttons[0] if not speed_buttons.is_empty() else null
	controls.add_child(VSeparator.new())
	pause_btn = Button.new()
	pause_btn.name = "PauseBtn"
	pause_btn.theme_type_variation = &"GhostButton"
	pause_btn.icon = UiTheme.icon("pause")
	pause_btn.custom_minimum_size = Vector2(0, UiTheme.height("bar"))
	controls.add_child(pause_btn)
	menu_btn = Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.theme_type_variation = &"GhostButton"
	menu_btn.icon = UiTheme.icon("menu")
	menu_btn.custom_minimum_size = Vector2(UiTheme.width("segment"), UiTheme.height("bar"))
	controls.add_child(menu_btn)

	objective_panel = _panel("ObjectivePanel", &"TechPanel")
	objective_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	objective_panel.custom_minimum_size = Vector2(_ui("objective_width", 280), 0)
	objective_panel.visible = false
	top_right.add_child(objective_panel)
	var objective := _vbox("Objective")
	objective.add_theme_constant_override("separation", UiTheme.space("xs") + UiTheme.space("hair"))
	objective_panel.add_child(objective)
	var header := HBoxContainer.new()
	header.name = "ObjectiveHeader"
	objective.add_child(header)
	header.add_child(_icon("ObjectiveIcon", "beacon", UiTheme.icon_size("m")))
	header.add_child(_label("ObjectiveTitle", &"TechLabel", ""))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	beacon_pips = HBoxContainer.new()
	beacon_pips.name = "BeaconPips"
	beacon_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	beacon_pips.add_theme_constant_override("separation", UiTheme.space("hair"))
	header.add_child(beacon_pips)
	beacon_label = _label("BeaconLabel", &"MutedLabel", "")
	beacon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(beacon_label)
	beacon_bar = ProgressBar.new()
	beacon_bar.name = "BeaconBar"
	beacon_bar.theme_type_variation = &"BeaconBar"
	beacon_bar.show_percentage = false
	beacon_bar.max_value = 1.0
	beacon_bar.step = 0.0
	beacon_bar.custom_minimum_size = Vector2(0, UiTheme.thickness("bar"))
	beacon_bar.visible = false
	objective.add_child(beacon_bar)

	# --- Centre: what just happened, what is coming ------------------------------------
	# No size of its own: as wide and as tall as what it holds, growing out from the middle
	# of the screen, down from under the top row. The anchors are set keeping the offsets
	# and the offsets outright -- re-anchoring a control already in the tree otherwise keeps
	# it where it stood, and it stood at the left edge.
	var toasts := _vbox("Toasts")
	root_control.add_child(toasts)
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.offset_left = 0.0
	toasts.offset_right = 0.0
	toasts.offset_top = float(_ui("toast_top", 66))
	toasts.offset_bottom = toasts.offset_top
	raid_warning_panel = _panel("RaidWarning", &"BannerPanel")
	raid_warning_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	raid_warning_panel.visible = false
	toasts.add_child(raid_warning_panel)
	var raid_row := HBoxContainer.new()
	raid_row.name = "RaidRow"
	raid_row.add_theme_constant_override("separation", UiTheme.space("m"))
	raid_warning_panel.add_child(raid_row)
	raid_row.add_child(_icon("RaidIcon", "warning", UiTheme.icon_size("l")))
	raid_warning_banner = _label("RaidWarningBanner", &"HeadingLabel", "")
	raid_warning_banner.visible = false
	raid_row.add_child(raid_warning_banner)
	hint_toast = _panel("HintToast", &"ToastPanel")
	hint_toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_toast.visible = false
	toasts.add_child(hint_toast)
	var hint_row := HBoxContainer.new()
	hint_row.name = "HintRow"
	hint_row.add_theme_constant_override("separation", UiTheme.space("s") + UiTheme.space("hair"))
	hint_toast.add_child(hint_row)
	hint_icon = _icon("HintIcon", "info", UiTheme.icon_size("m"))
	hint_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hint_row.add_child(hint_icon)
	hint_label = _label("HintLabel", &"", "")
	hint_label.visible = false
	hint_row.add_child(hint_label)

	# --- Paused: a frame round the screen and the word, under the menu ----------------------
	paused_overlay = Control.new()
	paused_overlay.name = "PausedOverlay"
	paused_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paused_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paused_overlay.visible = false
	root_control.add_child(paused_overlay)
	var frame := Panel.new()
	frame.name = "PausedFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.theme_type_variation = &"ScreenFrame"
	paused_overlay.add_child(frame)
	var word := _label("PausedWord", &"DisplayLabel", "")
	word.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	word.grow_horizontal = Control.GROW_DIRECTION_BOTH
	word.grow_vertical = Control.GROW_DIRECTION_BEGIN
	word.position.y = -float(_ui("paused_word_bottom", 150))
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.modulate.a = UiTheme.number("paused_alpha")
	paused_overlay.add_child(word)

	# --- Bottom left: the version, small -----------------------------------------------
	version_label = _label("VersionLabel", &"CaptionLabel", "")
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version_label.position = Vector2(edge, -(edge + UiTheme.font_size("caption")))
	root_control.add_child(version_label)

	# --- Retired controls: kept for the older API, never shown ---------------------------
	var legacy := Control.new()
	legacy.name = "Legacy"
	legacy.visible = false
	legacy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(legacy)
	wave_label = _label("WaveLabel", &"", "")
	legacy.add_child(wave_label)
	phase_label = _label("PhaseLabel", &"", "")
	legacy.add_child(phase_label)
	deploy_timer_label = _label("DeployTimerLabel", &"", "")
	legacy.add_child(deploy_timer_label)
	end_action_btn = Button.new()
	end_action_btn.name = "EndActionBtn"
	legacy.add_child(end_action_btn)
	var init_dep: float = 90.0
	var cfg = _get_config()
	if cfg and "TIME" in cfg and cfg.TIME is Dictionary:
		init_dep = float(cfg.TIME.get("deploy_length", 90.0))
	deploy_timer_label.text = tr("HUD_DEPLOY_TIMER") % init_dep
	end_action_btn.text = tr("HUD_END_DEPLOY_BTN")

	# --- The end of the run ----------------------------------------------------------------
	_build_game_over()

	# --- The command card and the menu ------------------------------------------------------
	var opt_script = load("res://scripts/ui/OptionPanel.gd")
	if opt_script:
		option_panel = opt_script.new()
		option_panel.name = "OptionPanel"
		root_control.add_child(option_panel)
		if option_panel.has_signal("build_option_selected"):
			option_panel.build_option_selected.connect(select_build_type)
	var menu_script = load("res://scripts/ui/PauseMenu.gd")
	if menu_script:
		pause_menu = menu_script.new()
		root_control.add_child(pause_menu)
		if pause_menu.has_signal("resumed"):
			pause_menu.resumed.connect(_refresh_paused_overlay)

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
	if version_badge != null:
		version_badge.text = title_str

## The results screen: a scrim over the world and a card in the middle.
func _build_game_over() -> void:
	game_over_panel = Control.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.visible = false
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(game_over_panel)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.material = UiTheme.frost_material()
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.add_child(scrim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.add_child(center)
	game_over_card = _panel("GameOverCard", &"VictoryPanel")
	game_over_card.custom_minimum_size = Vector2(_ui("result_card_width", 540), 0)
	center.add_child(game_over_card)
	var column := _vbox("Column")
	column.add_theme_constant_override("separation", UiTheme.space("m"))
	game_over_card.add_child(column)
	result_icon = _icon("ResultIcon", "beacon", UiTheme.icon_size("xxl"))
	result_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(result_icon)
	result_label = _label("ResultTitle", &"DisplayLabel", "")
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(result_label)
	details_label = _label("ResultSubtitle", &"LeadLabel", "")
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details_label)
	stats_row = HBoxContainer.new()
	stats_row.name = "StatsRow"
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", UiTheme.space("xl") * 2)
	column.add_child(stats_row)
	for key in ["Time", "Raids", "Killed"]:
		var block := _vbox("Stat%s" % key)
		block.add_theme_constant_override("separation", 0)
		var value := _label("Value", &"StatLabel", "")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.add_child(value)
		var caption := _label("Caption", &"CaptionLabel", "")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block.add_child(caption)
		stats_row.add_child(block)
	var share := _vbox("TimeShare")
	share.add_theme_constant_override("separation", UiTheme.space("xs"))
	column.add_child(share)
	time_share_bar = HBoxContainer.new()
	time_share_bar.name = "TimeShareBar"
	time_share_bar.add_theme_constant_override("separation", UiTheme.space("hair"))
	share.add_child(time_share_bar)
	time_share_legend = _label("TimeShareLegend", &"CaptionLabel", "")
	time_share_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_share_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	share.add_child(time_share_legend)
	column.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiTheme.space("m"))
	column.add_child(buttons)
	restart_btn = Button.new()
	restart_btn.name = "RestartButton"
	restart_btn.theme_type_variation = &"AccentButton"
	restart_btn.icon = UiTheme.icon("play")
	restart_btn.custom_minimum_size = Vector2(UiTheme.width("button"), UiTheme.height("command"))
	buttons.add_child(restart_btn)
	quit_btn = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.custom_minimum_size = Vector2(UiTheme.width("button"), UiTheme.height("command"))
	buttons.add_child(quit_btn)
	version_badge = _label("VersionBadge", &"CaptionLabel", "")
	version_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(version_badge)

## One vital: its icon, its bar, its figures.
func _vital(node_name: String, icon_name: String, bar_width: float) -> Array:
	var box := HBoxContainer.new()
	box.name = node_name
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_icon(node_name.replace("Vital", "Icon"), icon_name, UiTheme.icon_size("m")))
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"HealthBar"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = 1.0
	bar.custom_minimum_size = Vector2(bar_width, UiTheme.thickness("bar"))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var value := _label("Value", &"SmallNumberLabel", "")
	value.custom_minimum_size = Vector2(_ui("vital_value_width", 52), 0)
	box.add_child(value)
	return [box, bar, value]

func _panel(node_name: String, variation: StringName) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = node_name
	p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

func _vbox(node_name: String) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.name = node_name
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _label(node_name: String, variation: StringName, text: String) -> Label:
	var l := Label.new()
	l.name = node_name
	if variation != &"":
		l.theme_type_variation = variation
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _icon(node_name: String, icon_name: String, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.name = node_name
	r.texture = UiTheme.icon(icon_name)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## A layout figure from Config.UI.
func _ui(key: String, fallback: Variant) -> Variant:
	var cfg = _get_config()
	if cfg and "UI" in cfg:
		return cfg.UI.get(key, fallback)
	return fallback

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

## v0.2 removed the deploy/attack/produce phases and made raids continuous/random,
## so phase-era controls (deploy countdown, phase name, "end deployment") and the wave
## counter no longer describe anything the player acts on. They live on under a hidden
## node for the older API, never shown.
func _hide_legacy_phase_controls() -> void:
	for ctrl in [deploy_timer_label, phase_label, end_action_btn, wave_label]:
		if ctrl and is_instance_valid(ctrl):
			ctrl.visible = false

## ESC handling lives in Main; this is the HUD's side of it.
func toggle_pause_menu() -> void:
	if pause_menu and is_instance_valid(pause_menu) and pause_menu.has_method("toggle"):
		pause_menu.toggle()
	_refresh_paused_overlay()

func is_pause_menu_open() -> bool:
	if pause_menu and is_instance_valid(pause_menu) and "is_open" in pause_menu:
		return bool(pause_menu.is_open)
	return false
