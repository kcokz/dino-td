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
## The view back over the cabin, as the scene opened it: its medallion clicked (Main.reset_camera).
signal home_view_requested()
signal pause_clicked()

# ==============================================================================
# UI Node References
# ==============================================================================
var root_control: Control = null
## One chip per resource -- its icon and its count -- built from Config.RESOURCES: a new
## resource is a new chip without anyone writing one (v0.6 T2).
var resource_bar: Container = null
var resource_labels: Dictionary = {}     # res_id -> the count Label
## The hand-drawn map at the top left, once he has made it (MiniMap; RECIPES.hide_map).
var minimap: MiniMap = null
## The pinned goal's line under the beacon's (GameState.goal).
var goal_label: Label = null
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
## What he says, over his head (HeroVoice, EventBus.hero_spoke).
var speech_bubble: PanelContainer = null
var speech_label: Label = null
var _speech_until_ms: int = 0
var beacon_pips: HBoxContainer = null
var beacon_bar: ProgressBar = null
var wave_label: Label = null
var core_hp_label: Label = null
var core_hp_bar: TextureProgressBar = null
var core_vital: Control = null
## The day (_refresh_day_dial): its dial, the ring going round it, and the plate with the day on it.
var day_dial: Control = null
var day_ring: TextureProgressBar = null
var day_label: Label = null
var hero_hp_label: Label = null
var hero_hp_bar: TextureProgressBar = null
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
## A raid on its way, said quietly in the goal's card -- "Raid in 12 s", or the final wave's count -- and
## counted down. The alarm itself is the pack's call, heard from the nest's side, and his word on where they
## come from (HeroVoice): a red banner across the screen was too much (v0.6 round six: "红字提醒太突兀了").
var raid_line: Label = null
## The line with its mark, shown and hidden as one.
var raid_row: Control = null
var option_panel: Node = null
## His two commands, Build and Eat, in the corner under the card (v0.6 round four).
var hero_commands: HeroCommands = null
var pause_menu: Node = null
## What to play (StartScreen): over the stopped valley at the launch, and again for a new game.
var start_screen: Node = null
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

## The interface answers while the game is paused (GameState.is_paused): the pause menu, the
## speed and pause buttons, the cards.
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_ensure_ui_components()
	_hide_legacy_phase_controls()
	_connect_event_bus()
	_connect_buttons()
	reset_hud()
	# Every button of the interface, now and to come, clicks when pressed (Fx "ui_click"): the
	# card's commands are made and unmade as it changes, so they are caught as they arrive.
	for b in find_children("*", "BaseButton", true, false):
		_click_when_pressed(b)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	_disconnect_event_bus()
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node):
		_click_when_pressed(node)

func _click_when_pressed(button: Node) -> void:
	if not button.pressed.is_connected(_click):
		button.pressed.connect(_click)

func _click() -> void:
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("play_ui"):
		fx.play_ui("ui_click")

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

## He said something: the words over his head for as long as the voice says, as wide as they
## are up to UI.speech_max_width.
func _on_hero_spoke(line_key: String, seconds: float, args: Array = []) -> void:
	if speech_bubble == null or speech_label == null:
		return
	speech_label.text = tr(line_key) % args if not args.is_empty() else tr(line_key)
	var font: Font = speech_label.get_theme_font("font")
	var size_px: int = speech_label.get_theme_font_size("font_size")
	var wide: float = font.get_string_size(speech_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x if font else 200.0
	var most: float = float(_ui("speech_max_width", 300))
	# One line when it fits -- no wrapping, so nothing about its height waits on a layout -- and
	# wrapped at the most when it does not (its height settles a frame later: _place_speech).
	speech_label.autowrap_mode = TextServer.AUTOWRAP_OFF if wide <= most else TextServer.AUTOWRAP_WORD_SMART
	speech_label.custom_minimum_size.x = minf(ceilf(wide) + 1.0, most)
	speech_label.size = Vector2.ZERO
	speech_bubble.size = Vector2.ZERO
	speech_bubble.reset_size()
	_speech_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	if not speech_bubble.visible:
		speech_bubble.modulate.a = 0.0
		speech_bubble.visible = true
		var tw := speech_bubble.create_tween()
		tw.tween_property(speech_bubble, "modulate:a", 1.0, UiTheme.number("fade_seconds"))
	_place_speech()

## Over his head, wherever he is on the screen; kept on the screen; faded out when its time is
## up. Hidden while his head is behind the camera or he is gone.
func _place_speech() -> void:
	if speech_bubble == null or not speech_bubble.visible:
		return
	if Time.get_ticks_msec() >= _speech_until_ms:
		speech_bubble.visible = false
		return
	var hero: Node3D = get_tree().get_first_node_in_group("hero") as Node3D if is_inside_tree() else null
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if hero == null or cam == null:
		speech_bubble.visible = false
		return
	var head: Vector3 = hero.global_position + Vector3(0.0, float(_ui("speech_above", 1.8)), 0.0)
	if cam.is_position_behind(head):
		speech_bubble.visible = false
		return
	var at: Vector2 = cam.unproject_position(head)
	# As small as its words, every frame: a wrapped line's height is only known after a layout at
	# its width, and a bubble sized before that stood as tall as the screen.
	speech_bubble.reset_size()
	var box: Vector2 = speech_bubble.size
	var pos: Vector2 = at - Vector2(box.x * 0.5, box.y + float(UiTheme.space("xs")))
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var edge: float = float(UiTheme.space("s"))
	pos.x = clampf(pos.x, edge, maxf(edge, screen.x - box.x - edge))
	pos.y = clampf(pos.y, edge, maxf(edge, screen.y - box.y - edge))
	speech_bubble.position = pos

## Every signal the HUD listens to, and who answers it.
func _bus_handlers(eb: Node) -> Array:
	var out: Array = []
	for pair in [["resources_changed", _on_resources_changed], ["wave_started", _on_wave_started],
			["stage_wave_started", _on_stage_wave_started], ["day_part_changed", _on_day_part_changed],
			["nest_found", _on_nest_found], ["fog_explained", _on_fog_explained],
			["guards_warned", _on_guards_warned], ["fire_starved", _on_fire_starved],
			["torch_changed", _on_torch_changed],
			["core_hp_changed", _on_core_hp_changed], ["phase_changed", _on_phase_changed],
			["game_won", _on_game_won], ["game_lost", _on_game_lost],
			["deploy_time_changed", _on_deploy_time_changed], ["pause_toggled", _on_pause_toggled],
			["hero_hp_changed", _on_hero_hp_changed], ["locale_changed", _on_locale_changed],
			["raid_warning", _on_raid_warning], ["fed_changed", _on_fed_changed],
			["boss_arrived", _on_boss_arrived],
			["beacon_changed", _on_beacon_changed], ["beacon_launched", _on_beacon_launched],
			["raid_summary", _on_raid_summary], ["resource_picked_up", _on_resource_picked_up],
			["unlock_granted", _on_unlock_granted], ["hero_spoke", _on_hero_spoke],
			["final_wave_warning", _on_final_wave_warning],
			["material_discovered", _on_material_discovered], ["goal_changed", _on_goal_changed],
			["din_carried", _on_din_carried], ["wreck_located", _on_wreck_located]]:
		if eb.has_signal(pair[0]):
			out.append([Signal(eb, pair[0]), pair[1]])
	return out

func _on_locale_changed(_new_locale: String) -> void:
	reset_hud(false)

func _on_deploy_time_changed(remaining: float, _total: float) -> void:
	if deploy_timer_label:
		deploy_timer_label.text = tr("HUD_DEPLOY_TIMER") % remaining

## Paused: the button says what pressing it will do, and the whole screen says the game is
## stopped -- a frame and a word, not just a changed button (UI-POLISH T9).
func _on_pause_toggled(is_paused: bool) -> void:
	if pause_btn:
		# A round button says it with its glyph; the words are its tooltip.
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
	# Hurt, he says so -- once in a while, not at every bite: the player may be looking anywhere
	# (v0.6 round three: found playing, he was bitten to death by the nest's guards at the far end
	# of the valley with nothing on the screen to say so). Config.FEEDBACK.hero_hurt_alert_seconds.
	# A hit, not a meal wearing off: when a boost to his most ends, what he has comes down with it.
	if cur < _hero_hp_before - 0.001 and cur > 0.0 and absf(max_val - _hero_max_before) < 0.001:
		var now: float = Time.get_ticks_msec() / 1000.0
		var cfg = _get_config()
		var every: float = float(cfg.FEEDBACK.get("hero_hurt_alert_seconds", 10.0)) if (cfg and "FEEDBACK" in cfg) else 10.0
		if now - _hero_hurt_said_at >= every:
			_hero_hurt_said_at = now
			show_hint(tr("HINT_HERO_HURT") % [UiKit.fraction_text(cur, max_val)], UiTheme.toast_seconds("read"), "warning")
	_hero_hp_before = cur
	_hero_max_before = max_val
	if hero_hp_label:
		hero_hp_label.text = UiKit.fraction_text(cur, max_val)
	if hero_hp_bar:
		var ratio: float = clampf(cur / max_val, 0.0, 1.0) if max_val > 0.0 else 0.0
		hero_hp_bar.value = ratio
		hero_hp_bar.tint_progress = UiTheme.health_color(ratio)

var _hero_hp_before: float = INF
var _hero_max_before: float = -1.0
var _hero_hurt_said_at: float = -INF

## The counts, and income made visible: a count that went up flashes the accent colour and
## fades back, so a pickup is seen rather than searched for; an empty one is dimmed.
func _on_resources_changed(res: Dictionary) -> void:
	for res_id in resource_labels:
		var lbl: Label = resource_labels[res_id]
		if lbl == null or not is_instance_valid(lbl):
			continue
		var n: int = int(res.get(res_id, 0))
		_show_chip(String(res_id), n > 0)
		var before: int = int(lbl.text) if lbl.text.is_valid_int() else n
		lbl.text = str(n)
		var chip: Control = resource_chips.get(res_id)
		if chip and is_instance_valid(chip):
			chip.modulate.a = 1.0 if n > 0 else 0.5
		if n > before and lbl.is_inside_tree():
			lbl.modulate = UiTheme.color("accent")
			var tw := lbl.create_tween()
			tw.tween_property(lbl, "modulate", Color.WHITE, UiTheme.number("flash_seconds"))
	_refresh_goal(res)
	_fit_stock()

## THE PINNED GOAL (GameState.goal; GAME-DESIGN 6.0 rule 4): what it takes of each material is on that
## material's count, "3/5" -- gold once there is enough -- and under the beacon's line, what it is and
## what is still short, or that there is enough; clicking that line unpins it.
## `res` is the stock as said (EventBus.resources_changed), or the stock itself with nothing said.
func _refresh_goal(res: Dictionary = {}) -> void:
	var gs = _get_game_state()
	var price: Dictionary = gs.goal_price() if (gs and gs.has_method("goal_price")) else {}
	var stock: Dictionary = res if not res.is_empty() else (gs.resources if gs else {})
	for res_id in resource_labels:
		var lbl: Label = resource_labels[res_id]
		if lbl == null or not is_instance_valid(lbl):
			continue
		var n: int = int(stock.get(res_id, 0))
		var need: int = int(price.get(res_id, 0))
		if need > 0:
			lbl.text = "%d/%d" % [n, need]
			_show_chip(String(res_id), true)
			lbl.add_theme_color_override("font_color", UiTheme.color("accent") if n >= need else UiTheme.color("text"))
		elif lbl.text.contains("/"):
			# A count the goal took over, handed back.
			lbl.text = str(n)
			lbl.remove_theme_color_override("font_color")
	if goal_label == null or not is_instance_valid(goal_label):
		return
	var has_goal: bool = gs != null and "goal" in gs and not (gs.goal as Dictionary).is_empty()
	goal_label.visible = has_goal
	if not has_goal:
		_refresh_beacon_label()
		return
	var short: Dictionary = gs.goal_short()
	var parts: PackedStringArray = []
	for res_id in short:
		parts.append("%d %s" % [int(short[res_id]), tr("RESOURCE_%s" % String(res_id).to_upper())])
	var state: String = tr("GOAL_MET") if short.is_empty() else (tr("GOAL_SHORT") % ", ".join(parts))
	goal_label.text = tr("GOAL_LABEL") % [String(gs.goal_name()), state]
	goal_label.modulate = UiTheme.color("accent") if short.is_empty() else Color.WHITE
	_refresh_objective_panel()

## A wreck's din has brought something (Din): what the noise did, once a search -- with the face of what came.
func _on_din_carried(_wreck: Node, draws: String, species: String = "") -> void:
	show_hint(tr("HINT_DIN_" + draws.to_upper()), UiTheme.toast_seconds("read"), "warning",
		UiTheme.portrait("dino/" + species) if species != "" else null)

## The hand-drawn map's ground drawn afresh (a new run, something made). Whether it is shown at all is the
## map's own to ask (MiniMap._process).
func _refresh_minimap() -> void:
	if minimap != null and is_instance_valid(minimap) and minimap.visible:
		minimap.redraw_ground()

func _on_goal_changed(_goal: Dictionary) -> void:
	_refresh_goal()

func _on_goal_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var gs = _get_game_state()
		if gs and gs.has_method("unpin_goal"):
			gs.unpin_goal()

## The stock's gaps close up when it would reach the cabin's medallion -- a map with more
## materials, counts in the thousands, a narrow window -- rather than running under it; and when even
## the closest gaps are not enough, its chips go a size down (_squeeze_chips): smaller icons, smaller
## figures. Back to full size as soon as it fits again.
func _fit_stock() -> void:
	if resource_bar == null or core_vital == null or not core_vital.is_inside_tree():
		return
	var room: float = core_vital.get_global_rect().position.x - resource_bar.get_global_rect().position.x - UiTheme.space("m")
	for squeezed in [false, true]:
		_squeeze_chips(squeezed)
		for gap in [UiTheme.space("l"), UiTheme.space("s"), UiTheme.space("xs")]:
			resource_bar.add_theme_constant_override("separation", gap)
			if resource_bar.get_combined_minimum_size().x <= room:
				return

## Whether the stock's chips are a size down (_fit_stock).
var _chips_squeezed: bool = false

func _squeeze_chips(on: bool) -> void:
	if on == _chips_squeezed:
		return
	_chips_squeezed = on
	var px: int = UiTheme.icon_size("s" if on else "m")
	var width: float = float(_ui("resource_count_width_squeezed" if on else "resource_count_width", 30))
	for res_id in resource_chips:
		var chip: Control = resource_chips[res_id]
		if chip == null or not is_instance_valid(chip):
			continue
		var icon: Control = chip.find_child("%sIcon" % String(res_id).to_pascal_case(), true, false) as Control
		if icon != null:
			icon.custom_minimum_size = Vector2(px, px)
		var lbl: Label = resource_labels.get(res_id)
		if lbl == null or not is_instance_valid(lbl):
			continue
		lbl.custom_minimum_size = Vector2(width, 0)
		# The theme's own small figures (UI-POLISH T1: a size is a step on the theme's ladder).
		lbl.theme_type_variation = &"SmallNumberLabel" if on else &"NumberLabel"

## He ate, or the meal wore off. The countdown itself is _process's.
func _on_fed_changed(_fed: Dictionary) -> void:
	_refresh_fed_label()

func _process(delta: float) -> void:
	_place_speech()
	_tick_raid_line()
	if fed_label and fed_chip and fed_chip.visible:
		_refresh_fed_label()
	_refresh_day_dial()
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
func _on_beacon_changed(steps_done: int) -> void:
	_refresh_beacon_label()
	# A stage stands: its hum is heard down the valley, and something comes of it (WaveManager).
	var gs = _get_game_state()
	if gs and gs.has_method("beacon_stage_count") and steps_done >= 1 and steps_done <= int(gs.beacon_stage_count()) \
			and not gs.map_data().get("beacon", {}).get("stage_waves", []).is_empty():
		show_hint(tr("HINT_BEACON_STIRS"), UiTheme.toast_seconds("long"), "warning")

## A stage mended has heard where the next part's wreck lies (Config.WRECKS): said, with the stage's own news
## -- its hum carried, something heard it -- since it comes after it. Nothing when the part is in hand already
## or its wreck searched: he walked onto it.
func _on_wreck_located(part: String) -> void:
	var gs = _get_game_state()
	if gs == null or int(gs.resources.get(part, 0)) > 0:
		return
	var wreck: Node3D = null
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if n is Node3D and is_instance_valid(n) and String(n.get("resource_type")) == part:
			wreck = n as Node3D
	if wreck == null or bool(wreck.get("is_depleted")):
		return
	var waves = get_tree().get_first_node_in_group("wave_manager")
	var side: String = String(waves.side_of(wreck.global_position)) if (waves != null and waves.has_method("side_of")) else ""
	var where: String = tr("DIR_" + side) if side != "" and side != "here" else ""
	show_hint(tr("HINT_WRECK_LOCATED") % [tr("RESOURCE_%s" % part.to_upper()), where], UiTheme.toast_seconds("long"), part)

## The signal is out and the valley will answer: the raid line counts down to the final wave
## (GameState.final_wave_in, _render_final_line) and a hint says to build what he can meanwhile.
func _on_final_wave_warning(seconds: float) -> void:
	show_hint(tr("HINT_FINAL_WAVE_SOON") % int(ceil(seconds)), UiTheme.toast_seconds("long"), "warning")
	_raid_horn_sounded = false
	_on_raid_warning(seconds)
	_render_final_line()

func _render_final_line() -> void:
	var gs = _get_game_state()
	if raid_line == null or gs == null or float(gs.final_wave_in) < 0.0:
		return
	raid_line.text = tr("HUD_FINAL_WAVE") % int(ceil(float(gs.final_wave_in)))

## The raid line, second by second: to the final wave while the valley's answer is on its way
## (GameState.final_wave_in), gone as it sets out; otherwise to the raid warned of, on the raid's own
## clock (WaveManager.warned_raid_in) -- so a pause holds it and the game's speed runs it.
func _tick_raid_line() -> void:
	var gs = _get_game_state()
	var final_in: float = float(gs.final_wave_in) if (gs != null and "final_wave_in" in gs) else -1.0
	if raid_line != null and raid_line.visible:
		if final_in >= 0.0:
			_render_final_line()
		elif _final_line_up:
			_on_raid_warning(0.0)
		else:
			var waves = get_tree().get_first_node_in_group("wave_manager") if is_inside_tree() else null
			var left: float = float(waves.warned_raid_in()) if (waves != null and waves.has_method("warned_raid_in")) else -1.0
			if left >= 0.0:
				_raid_seconds = int(ceil(left))
				_render_raid_line()
	_final_line_up = final_in >= 0.0

## Launched: everything in the valley is on its way, from every side (GAME-DESIGN 8.3).
func _on_beacon_launched() -> void:
	_refresh_beacon_label()
	# With a grace before the valley answers, the countdown says it (_on_final_wave_warning).
	var gs = _get_game_state()
	if gs and float(gs.map_data().get("beacon", {}).get("launch_grace", 0.0)) > 0.0:
		return
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
	# A part of the beacon is said as found, with the stage it is for (Config.WRECKS).
	var cfg = _get_config()
	if cfg and cfg.has_method("is_part") and cfg.is_part(res_id):
		show_hint(tr("HINT_FOUND_PART") % [tr("RESOURCE_%s" % res_id.to_upper()), _stage_taking(res_id)],
			UiTheme.toast_seconds("long"), res_id)
		return
	var uses: String = _uses_text(res_id)
	if uses != "":
		show_hint(tr("HINT_NEW_MATERIAL") % [tr("RESOURCE_%s" % res_id.to_upper()), uses], UiTheme.toast_seconds("long"), res_id)

## Something made at the cabin: what it does, said as it is done -- "Made: Stone Axe --
## Wood x2" (GAME-DESIGN 14.2, path 4: did I get stronger).
func _on_unlock_granted(unlock_id: String) -> void:
	_refresh_minimap()
	if unlock_id == "hide_map":
		show_hint(tr("HINT_MAP_MADE"), UiTheme.toast_seconds("read"), "check")
		return
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

## What `res_id` is for, as far as the run has turned things up (GameState.knows): the bar
## and the first-pickup line never name what is still to come.
func _uses_text(res_id: String) -> String:
	var cfg = _get_config()
	var gs = _get_game_state()
	var known: Callable = gs.knows if (gs and gs.has_method("knows")) else Callable()
	return String(cfg.uses_text(res_id, _run_map(), known)) if (cfg and cfg.has_method("uses_text")) else ""

## A material has turned up: its chip comes onto the bar, and what the others are for may
## have grown.
func _on_material_discovered(res_id: String) -> void:
	_show_chip(res_id, true)
	_refresh_resource_tooltips()

## The stage of this run's beacon that takes `res_id`, counted from 1; 0 for none.
func _stage_taking(res_id: String) -> int:
	var cfg = _get_config()
	return int(cfg.part_stage(_run_map(), res_id)) if (cfg and cfg.has_method("part_stage")) else 0

## A material's chip is on the bar when the material is for something in this game (GAME-
## DESIGN 4.3 rule 1) and the run has turned it up -- or `holding` says it is in the stock
## now, which is the same thing (v0.6: the bar grows as the run does, from wood alone). A part of
## the beacon only while it is held: it is found once and goes into the beacon, and a chip
## at nought after that would be a thing to look for that is not there.
func _show_chip(res_id: String, holding: bool = false) -> void:
	var chip: Control = resource_chips.get(res_id)
	var count: Control = resource_labels.get(res_id)
	if chip == null or not is_instance_valid(chip):
		return
	var cfg = _get_config()
	var gs = _get_game_state()
	var useful: bool = not (cfg and cfg.has_method("uses_of")) or not cfg.uses_of(res_id, _run_map()).is_empty()
	var known: bool = holding or gs == null or not gs.has_method("knows") or gs.knows(res_id)
	var part: bool = cfg != null and cfg.has_method("is_part") and cfg.is_part(res_id)
	if part:
		known = holding
	chip.visible = useful and known
	if count and is_instance_valid(count):
		# A part is one or none: its icon says it is held, and a count beside it would only ever
		# say 1 -- and take the room the materials' counts need.
		count.visible = chip.visible and not part

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
	var text: String = ""
	if gs and gs.has_method("objective_status"):
		text = String(gs.objective_status())
	beacon_label.text = text
	beacon_label.visible = text != ""
	_refresh_objective_panel()
	if text == "" or gs == null:
		return
	var title = find_child("ObjectiveTitle", true, false) as Label
	var rescue: bool = gs.has_method("goal_kind") and String(gs.goal_kind()) == "rescue"
	if title:
		title.text = tr("HUD_OBJECTIVE_RESCUE" if rescue else "HUD_OBJECTIVE_BEACON")
	# Held out for rescue (GameState "rescue" goal): the days gone of the days to go, as the charge is drawn.
	if rescue:
		_draw_pips(0, 0)
		if beacon_bar:
			beacon_bar.visible = true
			beacon_bar.value = float(gs.rescue_ratio())
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
	_show_raid_line(false)

## The day's dial, from the clock (GameState.time_of_day): how far round today is, in the colour of
## its part; the sun, or at night the moon; the day of the run; and on hover, how long this part has
## left.
func _refresh_day_dial() -> void:
	if day_dial == null or not is_instance_valid(day_dial):
		return
	var gs = _get_game_state()
	var cfg = _get_config()
	if gs == null or not gs.has_method("time_of_day") or cfg == null or not ("DAY" in cfg):
		day_dial.visible = false
		return
	day_dial.visible = true
	var length: float = float(cfg.DAY.get("length", 360.0))
	var t: float = float(gs.time_of_day())
	var part: String = String(gs.day_part())
	day_ring.value = t / maxf(1.0, length)
	day_ring.tint_progress = UiTheme.color("day_" + part)
	var face := day_dial.find_child("Portrait", true, false) as TextureRect
	if face:
		face.texture = UiTheme.icon("moon" if part == "night" else "sun")
	day_label.text = tr("HUD_DAY") % int(gs.day_number())
	var next_at: float = length
	for p in cfg.DAY.get("parts", {}):
		var at: float = float(cfg.DAY["parts"][p])
		if at > t and at < next_at:
			next_at = at
	# In the game's own time (CUSTOM_GAME "day_length": a longer day, a slower clock).
	var pace: float = float(gs.run_scale("day_length")) if gs.has_method("run_scale") else 1.0
	var left: int = int(ceil((next_at - t) * pace))
	day_dial.tooltip_text = tr("HUD_DAY_TIP") % [int(gs.day_number()), tr("DAY_PART_" + part.to_upper()),
		"%d:%02d" % [left / 60, left % 60]]

## A part of the day begun: said, with what the raiders do in it (GAME-DESIGN 9.3). The run's first
## dusk says too what the dark is and what fire is for (9.2's timeline: "第一个黄昏：生火"), with the
## torch's key.
func _on_day_part_changed(part: String, day: int) -> void:
	var key: String = {"day": "HINT_DAWN", "dusk": "HINT_DUSK", "night": "HINT_NIGHT"}.get(part, "")
	# In the words of this run's animals (MAPS.<id>.day_hints: the Morrison's raiders, no hunters in its river).
	var words: Dictionary = _day_hints()
	if key != "":
		key = String(words.get("dawn" if part == "day" else part, key))
	# A day gone: the days still to hold out for rescue are one fewer.
	_refresh_beacon_label()
	# The first dusk teaches what the dark is and what fire is for -- in a game that teaches (GameState "tutorial").
	if part == "dusk" and not _first_dusk_said and _teaches():
		_first_dusk_said = true
		# The torch's tile comes with this dusk, and the key it comes with is the one said.
		if hero_commands:
			hero_commands.refresh()
		show_hint(tr(String(words.get("dusk_first", "HINT_DUSK_FIRST"))) % _torch_key_text(), UiTheme.toast_seconds("read"), "sun")
	elif key != "":
		show_hint(tr(key), -1.0, "moon" if part == "night" else "sun")
	_refresh_day_dial()

## What the day's turns are said in for this run's animals (MAPS.<id>.day_hints, carried with an age's cast): "dawn",
## "dusk", "night", "dusk_first" to a string's key; {} for the Chinle's own (HINT_DAWN and the rest).
func _day_hints() -> Dictionary:
	var gs = _get_game_state()
	var words: Variant = gs.map_data().get("day_hints", {}) if (gs and gs.has_method("map_data")) else {}
	return words if words is Dictionary else {}

## Whether the first dusk's word on fire has been said this run.
var _first_dusk_said: bool = false
## The night a fire's having no wood was last said (GameState.day_number): once a night.
var _starved_said_night: int = -1

## A fire with no wood for its night (Fire.gd): said once a night, whichever fire it is.
func _on_fire_starved(fire: Node) -> void:
	var gs = _get_game_state()
	var night: int = int(gs.day_number()) if (gs and gs.has_method("day_number")) else 0
	if night == _starved_said_night:
		return
	_starved_said_night = night
	var fire_name: String = String(fire.get_localized_name()) if (fire and fire.has_method("get_localized_name")) else ""
	show_hint(tr("HINT_FIRE_STARVED") % fire_name, UiTheme.toast_seconds("read"), "warning")

## The torch burnt out: said while it is still dark, when another is what he may want.
func _on_torch_changed(lit: bool) -> void:
	if hero_commands:
		hero_commands.refresh()
	if lit:
		return
	var gs = _get_game_state()
	var cfg = _get_config()
	var burns: Array = cfg.FIRE.get("burns", ["dusk", "night"]) if (cfg and "FIRE" in cfg) else ["dusk", "night"]
	if gs and gs.has_method("day_part") and String(gs.day_part()) in burns:
		var cost: int = int(cfg.FIRE.get("torch", {}).get("cost", {}).get("wood", 1)) if (cfg and "FIRE" in cfg) else 1
		show_hint(tr("HINT_TORCH_OUT") % [cost, _torch_key_text()], -1.0, "info")

## The torch tile pressed: he lights one, if he can.
## The torch's tile (or its key): a torch lit if he has none burning, and the one burning put out if he has
## (v0.6 round six, the player: "火把点燃了就不能取消（再按一下就取消）").
func _light_his_torch() -> void:
	var hero: Node = get_tree().get_first_node_in_group("hero") if is_inside_tree() else null
	if hero != null:
		if float(hero.get("torch_left")) > 0.0 and hero.has_method("put_out_torch"):
			hero.put_out_torch()
		elif hero.has_method("light_torch"):
			hero.light_torch()
	if hero_commands:
		hero_commands.refresh()

## The key that lights the torch, as the keyboard writes it: its tile's, which is its place in the
## corner (HeroCommands.key_of).
func _torch_key_text() -> String:
	return hero_commands.key_of("torch") if hero_commands else ""

## A raid a repaired beacon stage stirred up: said as that, not as the raid count again.
func _on_stage_wave_started(_size: int) -> void:
	if wave_label:
		wave_label.text = tr("HUD_STAGE_WAVE")

## The seconds the raid line gives, and whether it was counting to the final wave last frame.
var _raid_seconds: int = 0
var _final_line_up: bool = false

func _render_raid_line() -> void:
	if raid_line != null:
		raid_line.text = tr("HUD_RAID_WARNING") % _raid_seconds

## The raid line up or down, and the goal's card with it when nothing else keeps it up.
func _show_raid_line(on: bool) -> void:
	if raid_line != null:
		raid_line.visible = on
	if raid_row != null:
		raid_row.visible = on
	_refresh_objective_panel()

## The goal's card is up while it has something to say: the beacon, a pinned goal, a raid on its way.
func _refresh_objective_panel() -> void:
	if objective_panel == null:
		return
	var beacon: bool = beacon_label != null and is_instance_valid(beacon_label) and beacon_label.visible
	var goal: bool = goal_label != null and is_instance_valid(goal_label) and goal_label.visible
	objective_panel.visible = beacon or goal or (raid_row != null and raid_row.visible)

## Whether the game being played teaches as it goes (GameState.internal "tutorial": ours does).
func _teaches() -> bool:
	var gs = _get_game_state()
	return gs == null or not gs.has_method("internal") or bool(gs.internal("tutorial", true))

## A moment into the run (FogOfWar): what the mist is -- ground not yet seen, cleared by going
## there or building near it -- so it is not taken for the weather.
func _on_fog_explained() -> void:
	show_hint(tr("HINT_FOG"), UiTheme.toast_seconds("read"), "info")

## A nest's guards warning him off (GuardDino): what it means and what to do, the first time in a
## run -- he has two seconds to take it in, and the next time he knows the look of it.
var _guards_warning_said: bool = false

func _on_guards_warned(_guard: Node) -> void:
	if _guards_warning_said:
		return
	_guards_warning_said = true
	show_hint(tr("HINT_GUARDS_WARN"), UiTheme.toast_seconds("read"), "warning")

## The nest found (FogOfWar): said, with what it is good for.
func _on_nest_found(_nest: Node) -> void:
	show_hint(tr("HINT_NEST_FOUND"), UiTheme.toast_seconds("read"), "check")

func _on_boss_arrived(dino: Node) -> void:
	var cfg = _get_config()
	var species: String = String(dino.dino_type) if (dino and "dino_type" in dino) else ""
	var boss_name: String = String(cfg.get_dino_name(species)) if (cfg and cfg.has_method("get_dino_name")) else species
	show_hint(tr("HUD_BOSS_ARRIVED") % boss_name, UiTheme.toast_seconds("read"), "warning", UiTheme.portrait("dino/" + species))

## A raid on its way (WaveManager, or the final wave's grace): the pack's call, once, from the nest's side, far
## off -- that and his word are the warning (HeroVoice) -- and the quiet line in the goal's card. Nothing
## flashes: time_left 0 takes the line down.
func _on_raid_warning(time_left: float) -> void:
	if raid_line == null:
		return
	if time_left <= 0.0:
		_show_raid_line(false)
		_raid_horn_sounded = false
		return
	if not _raid_horn_sounded:
		_raid_horn_sounded = true
		var fx = get_node_or_null("/root/Fx")
		if fx:
			var nest: Node3D = get_tree().get_first_node_in_group("nest") as Node3D
			if nest != null:
				fx.play_at("raid_warning", nest.global_position + Vector3(0.0, 2.0, 0.0))
			else:
				fx.play(fx.Sound.RAID_WARNING)
	_raid_seconds = int(ceil(time_left))
	_render_raid_line()
	_show_raid_line(true)

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
		core_hp_bar.tint_progress = UiTheme.health_color(_core_ratio)
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
	# The beacon's jump goes on to our game's next station (StationJump): no verdict, the run goes on there.
	if gs and gs.has_method("has_next_station") and gs.has_next_station():
		return
	# Held out till the rescue came (GameState "rescue" goal), or jumped home on the beacon.
	if gs and gs.has_method("goal_kind") and String(gs.goal_kind()) == "rescue":
		_show_game_over(tr("GAME_RESCUED_TITLE"), tr("GAME_RESCUED_DESC") % int(gs.rescue_days()), true)
		return
	_show_game_over(tr("GAME_VICTORY_TITLE"), tr("GAME_VICTORY_DESC"), true)

func _on_game_lost() -> void:
	var gs = _get_game_state()
	if gs and gs.is_game_won:
		return
	if is_game_over_visible():
		return
	var fell: bool = gs != null and "lost_to" in gs and String(gs.lost_to) == "hero"
	_show_game_over(tr("GAME_DEFEAT_HERO_TITLE" if fell else "GAME_DEFEAT_TITLE"), _defeat_text(gs), false)

## How the run was lost, in words (the debug-agent's BUG-011: one line, "the cabin was destroyed or the
## hero was killed", over a cabin at full health). The cabin broken open; or the engineer killed -- by
## what, when it was at his side, and whether it was guarding its nest; or, when nothing said, both.
func _defeat_text(gs: Node) -> String:
	var to: String = String(gs.lost_to) if (gs != null and "lost_to" in gs) else ""
	if to == "cabin":
		return tr("GAME_DEFEAT_CABIN")
	if to != "hero":
		return tr("GAME_DEFEAT_DESC")
	var killer: Dictionary = gs.hero_killer if "hero_killer" in gs else {}
	if killer.is_empty():
		return tr("GAME_DEFEAT_HERO")
	var cfg = _get_config()
	var kind: String = String(killer.get("type", ""))
	var named: String = String(cfg.get_dino_name(kind)) if cfg else kind
	return tr("GAME_DEFEAT_HERO_BY_GUARD" if bool(killer.get("guard", false)) else "GAME_DEFEAT_HERO_BY") % named

## What killed him, by its face (UiTheme.portrait) -- or null: the cabin lost, nothing said, no face.
func _killer_portrait() -> Texture2D:
	var gs = _get_game_state()
	if gs == null or not ("lost_to" in gs) or String(gs.lost_to) != "hero":
		return null
	var killer: Dictionary = gs.hero_killer if "hero_killer" in gs else {}
	var kind: String = String(killer.get("type", ""))
	return UiTheme.portrait("dino/" + kind) if kind != "" else null

## The end of the run: the verdict, told apart by more than colour -- a different icon, a
## different word, a different stone under them -- and the run's account under it (UI-POLISH
## T15).
func _show_game_over(title: String, details: String, won: bool = true) -> void:
	if result_label:
		result_label.text = title
	if details_label:
		details_label.text = details
	if game_over_card:
		game_over_card.theme_type_variation = &"VictoryPanel" if won else &"DefeatPanel"
	if result_icon:
		# Killed: the face of what killed him (UiTheme.portrait), where there is one, over the verdict.
		var face: Texture2D = null if won else _killer_portrait()
		result_icon.texture = face if face != null else UiTheme.icon("beacon" if won else "warning")
		result_icon.modulate = Color.WHITE if (won or face != null) else UiTheme.color("danger")
	var stats = get_tree().get_first_node_in_group(RunStats.GROUP) if is_inside_tree() else null
	_fill_run_stats(stats)
	if game_over_panel:
		game_over_panel.visible = true
		# On top of everything else on the screen -- and the selection panel out of the way:
		# once the run is over there is nothing left to select.
		game_over_panel.move_to_front()
		_pop_in(game_over_card if game_over_card else game_over_panel)
	if option_panel and is_instance_valid(option_panel):
		option_panel.set_shut(true)
	if hero_commands:
		hero_commands.visible = false
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

## Appears rather than blinks on (UiKit.pop_in).
func _pop_in(node: Control) -> void:
	UiKit.pop_in(node)

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

## `new_run`: what is said once a run, and his commands in the corner, start over -- not when the
## words are only put in another language (_on_locale_changed), which is the same run: a torch tile
## that had come would go until the next dusk, and come back on another key.
func reset_hud(new_run: bool = true) -> void:
	selected_build_type = ""
	if new_run and minimap != null:
		minimap.forget()
	_refresh_minimap()
	if new_run:
		_guards_warning_said = false
		_first_dusk_said = false
		_starved_said_night = -1
		if hero_commands:
			hero_commands.reset()
	if game_over_panel:
		game_over_panel.visible = false
	_show_raid_line(false)
	_update_speed_btn_label()
	if hero_commands:
		hero_commands.visible = true
	if option_panel and is_instance_valid(option_panel) and option_panel.has_method("clear_selection"):
		option_panel.set_shut(false)
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
	var hero_emblem = find_child("HeroEmblem", true, false)
	if hero_emblem:
		hero_emblem.tooltip_text = tr("HUD_HERO_TIP") % _details_key_text()
	var title = find_child("ObjectiveTitle", true, false) as Label
	if title:
		var gs_title = _get_game_state()
		var rescue_title: bool = gs_title and gs_title.has_method("goal_kind") and String(gs_title.goal_kind()) == "rescue"
		title.text = tr("HUD_OBJECTIVE_RESCUE" if rescue_title else "HUD_OBJECTIVE_BEACON")
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
## `picture`, where the line is about an animal -- a boss on the field, what a wreck's din brought -- is its
## face (UiTheme.portrait), shown bigger than an icon, in the icon's place.
func show_hint(msg: String, duration: float = -1.0, icon_name: String = "info", picture: Texture2D = null) -> void:
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
		hint_icon.texture = picture if picture != null else UiTheme.icon(icon_name)
		var px: int = UiTheme.icon_size("xl" if picture != null else "m")
		hint_icon.custom_minimum_size = Vector2(px, px)
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
			chip.add_theme_constant_override("separation", UiTheme.space("s"))
			resource_bar.add_child(chip)
			# Its icon sits in a socket sunk in the strip.
			var socket := _panel("%sSocket" % key, &"SocketPanel")
			socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
			socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.add_child(socket)
			socket.add_child(_icon("%sIcon" % key, String(res_id), UiTheme.icon_size("m")))
			var lbl := Label.new()
			lbl.name = "%sLabel" % key
			lbl.theme_type_variation = &"NumberLabel"
			lbl.text = "0"
			lbl.custom_minimum_size = Vector2(_ui("resource_count_width", 30), 0)
			chip.add_child(lbl)
		var count: Label = chip.get_node("%sLabel" % key) as Label
		resource_labels[String(res_id)] = count
		resource_chips[String(res_id)] = chip
		_show_chip(String(res_id))
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

	# --- The status bar -------------------------------------------------------------------
	# v0.6: "状态栏的那个版面还是显得像网页游戏". Three plates floating along the top were a web
	# page's navigation, whatever they were made of. A game hangs its status off one strip along
	# the top edge: the materials in round sockets at its left, the speeds, pause and menu as
	# round buttons at its right, and from its middle -- over everything -- the medallion of
	# what the run is lost with: the cabin, its health a ring round its portrait. The Hero's
	# own medallion stands at the bottom left, where a party's portraits stand.
	var top_bar := PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.theme_type_variation = &"StripPanel"
	top_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = float(_ui("strip_height", 44))
	root_control.add_child(top_bar)
	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", UiTheme.space("l"))
	top_bar.add_child(top_row)

	# Its left: the materials, each in its socket, its count beside it.
	var res_panel := HBoxContainer.new()
	res_panel.name = "ResourcePanel"
	res_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(res_panel)
	resource_bar = HBoxContainer.new()
	resource_bar.name = "ResourceBar"
	resource_bar.add_theme_constant_override("separation", UiTheme.space("l"))
	res_panel.add_child(resource_bar)
	_ensure_resource_labels()
	var middle := Control.new()
	middle.name = "Middle"
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(middle)

	# Its right: the speeds, the one it runs at lit; pause; the menu.
	var controls := HBoxContainer.new()
	controls.name = "ControlsPanel"
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_theme_constant_override("separation", UiTheme.space("xs"))
	top_row.add_child(controls)
	var round_px: Vector2 = Vector2(UiTheme.tokens().get("surfaces", {}).get("round_button", {}).get("size", Vector2i(34, 34)))
	var speed_group := HBoxContainer.new()
	speed_group.name = "SpeedGroup"
	speed_group.add_theme_constant_override("separation", UiTheme.space("xs"))
	controls.add_child(speed_group)
	var group := ButtonGroup.new()
	speed_buttons.clear()
	for s in _speeds():
		var seg := Button.new()
		seg.name = "Speed%dBtn" % int(s)
		seg.theme_type_variation = &"RoundButton"
		seg.toggle_mode = true
		seg.button_group = group
		seg.text = "%s×" % (("%d" % int(s)) if is_equal_approx(float(s), round(float(s))) else ("%.1f" % float(s)))
		seg.custom_minimum_size = round_px
		seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var speed: float = float(s)
		seg.pressed.connect(func(): set_game_speed(speed))
		speed_group.add_child(seg)
		speed_buttons.append(seg)
	speed_btn = speed_buttons[0] if not speed_buttons.is_empty() else null
	var apart := Control.new()
	apart.custom_minimum_size = Vector2(UiTheme.space("s"), 0)
	apart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(apart)
	pause_btn = Button.new()
	pause_btn.name = "PauseBtn"
	pause_btn.theme_type_variation = &"RoundButton"
	pause_btn.icon = UiTheme.icon("pause")
	pause_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_btn.custom_minimum_size = round_px
	pause_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(pause_btn)
	menu_btn = Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.theme_type_variation = &"RoundButton"
	menu_btn.icon = UiTheme.icon("menu")
	menu_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_btn.custom_minimum_size = round_px
	menu_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls.add_child(menu_btn)

	# From its middle, over everything: the cabin's medallion, its figures on a plate under it.
	var cabin := _medallion("CabinEmblem", "building/core", "core")
	core_vital = cabin[0]
	core_hp_bar = cabin[1]
	core_hp_label = cabin[2]
	core_hp_bar.name = "CoreHPBar"
	core_hp_label.name = "CoreHPLabel"
	root_control.add_child(core_vital)
	core_vital.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE)
	core_vital.grow_horizontal = Control.GROW_DIRECTION_BOTH
	core_vital.offset_top = float(_ui("emblem_top", 2))
	core_vital.offset_bottom = core_vital.offset_top
	# Clicked, it takes the view home to the cabin, as its key does -- out exploring there was no
	# plain way back (the player's report, 2026-09-29: "当人在外面explore 的时候，没法用简单直接的方式把视角回到
	# cabin那里"). The key is on a chip at its shoulder, as the Hero's details key is on his.
	core_vital.mouse_filter = Control.MOUSE_FILTER_STOP
	core_vital.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	core_vital.gui_input.connect(_on_cabin_emblem_input)
	_shoulder_keycap(core_vital, _home_key_text())
	root_control.resized.connect(_fit_stock, CONNECT_DEFERRED)

	# Beside it, the day (GAME-DESIGN 9.3): a dial going round once a day -- gold by day, red at
	# dusk, blue in the night -- the sun or the moon in it, and which day of the run it is.
	var dial := _medallion("DayDial", "day", "sun", float(_ui("day_dial_scale", 0.55)))
	day_dial = dial[0]
	day_ring = dial[1]
	day_label = dial[2]
	day_ring.name = "DayRing"
	day_label.name = "DayLabel"
	root_control.add_child(day_dial)
	day_dial.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE)
	day_dial.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var beside: float = float(_ui("day_dial_offset", 104.0))
	day_dial.offset_left += beside
	day_dial.offset_right += beside
	day_dial.offset_top = float(_ui("emblem_top", 2))
	day_dial.offset_bottom = day_dial.offset_top
	_refresh_day_dial()

	# Under the strip at its right: the goal.
	objective_panel = _panel("ObjectivePanel", &"TechPanel")
	objective_panel.custom_minimum_size = Vector2(_ui("objective_width", 280), 0)
	objective_panel.visible = false
	root_control.add_child(objective_panel)
	objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	objective_panel.offset_right = -edge
	objective_panel.offset_left = -edge - float(_ui("objective_width", 280))
	objective_panel.offset_top = float(_ui("strip_height", 44)) + UiTheme.space("m")
	objective_panel.offset_bottom = objective_panel.offset_top
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
	# The hand-drawn map, once made (MiniMap): at the top left under the strip, level with the goal's panel
	# at the right. Under that panel it was pushed down onto the cards that come up at the right as the
	# panel grew (a goal pinned); here nothing else is. Its size is its own (MINIMAP.size).
	minimap = MiniMap.new()
	minimap.name = "MiniMap"
	minimap.visible = false
	root_control.add_child(minimap)
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	minimap.offset_left = edge
	minimap.offset_right = edge
	minimap.offset_top = objective_panel.offset_top
	minimap.offset_bottom = objective_panel.offset_top
	# The pinned goal, under the beacon's line (GameState.goal): what it is, what is short; a click
	# unpins it.
	goal_label = _label("GoalLabel", &"MutedLabel", "")
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	goal_label.tooltip_text = tr("GOAL_UNPIN")
	goal_label.visible = false
	goal_label.gui_input.connect(_on_goal_label_input)
	objective.add_child(goal_label)
	# A raid on its way, quietly, last in the card (raid_line): the words muted, the mark small -- it is
	# heard and said first; this is only how long.
	raid_row = HBoxContainer.new()
	raid_row.name = "RaidRow"
	raid_row.visible = false
	raid_row.add_theme_constant_override("separation", UiTheme.space("xs"))
	objective.add_child(raid_row)
	raid_row.add_child(_icon("RaidIcon", "dino", UiTheme.icon_size("s")))
	raid_line = _label("RaidLine", &"MutedLabel", "")
	raid_line.visible = false
	raid_row.add_child(raid_line)

	# Bottom left: the Hero's medallion -- click it to pick him -- his figures and the meal he
	# is living on beside it.
	var hero_side := HBoxContainer.new()
	hero_side.name = "HeroSide"
	hero_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_side.alignment = BoxContainer.ALIGNMENT_END
	hero_side.add_theme_constant_override("separation", UiTheme.space("s"))
	root_control.add_child(hero_side)
	var hero := _medallion("HeroEmblem", "hero", "hero", float(_ui("hero_emblem_scale", 0.8)))
	hero_hp_bar = hero[1]
	hero_hp_label = hero[2]
	hero_hp_bar.name = "HeroHPBar"
	hero_hp_label.name = "HeroHPLabel"
	hero[0].mouse_filter = Control.MOUSE_FILTER_STOP
	hero[0].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hero[0].gui_input.connect(_on_hero_emblem_input)
	# The key that opens his card in full, on a chip at the medallion's shoulder, as a command wears
	# its key.
	_shoulder_keycap(hero[0], _details_key_text())
	hero_side.add_child(hero[0])
	fed_chip = _panel("FedChip", &"PillPanel")
	fed_chip.size_flags_vertical = Control.SIZE_SHRINK_END
	fed_chip.visible = false
	hero_side.add_child(fed_chip)
	var fed_row := HBoxContainer.new()
	fed_row.name = "FedRow"
	fed_chip.add_child(fed_row)
	var fed_icon := _icon("FedIcon", "fed", UiTheme.icon_size("s"))
	fed_icon.modulate = UiTheme.color("accent")
	fed_row.add_child(fed_icon)
	fed_label = _label("FedLabel", &"SmallNumberLabel", "")
	fed_row.add_child(fed_label)
	hero_side.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	hero_side.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hero_side.offset_left = edge
	hero_side.offset_bottom = -(edge + UiTheme.font_size("caption") + UiTheme.space("xs"))
	hero_side.offset_top = hero_side.offset_bottom


	# --- Over his head: what he says (HeroVoice) --------------------------------------------
	# A small card of the dark vellum, as wide as its words up to a limit, placed each frame over
	# where his head is on the screen (_place_speech).
	speech_bubble = _panel("SpeechBubble", &"CardPanel")
	speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_bubble.visible = false
	speech_label = _label("SpeechText", &"SpeechLabel", "")
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_bubble.add_child(speech_label)
	root_control.add_child(speech_bubble)

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
	version_label.position = Vector2(edge, -(UiTheme.space("xs") + UiTheme.font_size("caption") + UiTheme.space("xs")))
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
	# His two commands in the corner, where they always are; the card stands on them.
	hero_commands = HeroCommands.new()
	root_control.add_child(hero_commands)
	hero_commands.build_pressed.connect(func(): _open_hero_menu("build"))
	hero_commands.eat_pressed.connect(func(): _open_hero_menu("eat"))
	hero_commands.torch_pressed.connect(_light_his_torch)
	if option_panel:
		option_panel.card_changed.connect(_on_card_changed)
		option_panel.stand_on(hero_commands)
		option_panel.keep_below(objective_panel)
		_on_card_changed()
	var menu_script = load("res://scripts/ui/PauseMenu.gd")
	if menu_script:
		pause_menu = menu_script.new()
		root_control.add_child(pause_menu)
		if pause_menu.has_signal("resumed"):
			pause_menu.resumed.connect(_refresh_paused_overlay)
		if pause_menu.has_signal("new_game_requested"):
			pause_menu.new_game_requested.connect(show_start_screen.bind(false))

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

## A medallion (Config.THEME.surfaces "medallion"): `key`'s portrait -- or `icon_name`'s icon
## where it has none -- in a socket, its health a ring of pigment round it ("ring_fill", a
## TextureProgressBar filling clockwise from the top, tinted as health is), and its figures on
## a plate under it; drawn at `grow` times its size. [medallion, ring, figures]
func _medallion(node_name: String, key: String, icon_name: String, grow: float = 1.0) -> Array:
	var spec: Dictionary = UiTheme.tokens().get("surfaces", {}).get("medallion", {})
	var px: Vector2 = Vector2(spec.get("size", Vector2i(104, 104)))
	var box := VBoxContainer.new()
	box.name = node_name
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -UiTheme.space("s"))
	# The disc is drawn at its own size and scaled; a holder the scaled size keeps the layout
	# honest about how much room it takes.
	var holder := Control.new()
	holder.name = "Disc"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = px * grow
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(holder)
	var disc := Control.new()
	disc.name = "Face"
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.size = px
	disc.scale = Vector2.ONE * grow
	holder.add_child(disc)
	var base := TextureRect.new()
	base.name = "Base"
	base.texture = UiTheme.surface_texture("medallion")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.size = px
	disc.add_child(base)
	var socket: float = float(spec.get("socket", 31.0)) * 2.0
	var face := TextureRect.new()
	face.name = "Portrait"
	var art: Texture2D = UiTheme.portrait(key)
	face.texture = art if art else UiTheme.icon(icon_name)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.position = (px - Vector2.ONE * socket) * 0.5
	face.size = Vector2.ONE * socket
	disc.add_child(face)
	var ring := TextureProgressBar.new()
	ring.name = "Ring"
	ring.texture_progress = UiTheme.surface_texture("ring_fill")
	ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	ring.min_value = 0.0
	ring.max_value = 1.0
	ring.step = 0.0
	ring.value = 1.0
	ring.tint_progress = UiTheme.health_color(1.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = px
	disc.add_child(ring)
	var plate := _panel(node_name + "Plate", &"PillPanel")
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(plate)
	var value := _label("Value", &"SmallNumberLabel", "")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(value)
	return [box, ring, value]

## The key a medallion answers to, on a chip at its shoulder -- the top right of its disc -- the same on the
## Hero's and the cabin's: its corner meets the disc's, and it grows away from it to fit what it says. Its
## offsets are set as well as its anchors: the cabin's disc is already laid out when its chip goes on, and
## anchors moved on their own keep a control where it was -- which left the cabin's key at the disc's top
## LEFT (v0.6 round seven, the player: "现在回到cabin的快捷键显示脱位置了，应该跟人的快捷键一样在人头像旁边").
func _shoulder_keycap(medallion: Control, key_text: String) -> Label:
	var disc: Control = medallion.get_node_or_null("Disc") as Control
	if disc == null:
		return null
	var cap := _label("Keycap", &"KeycapLabel", key_text)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disc.add_child(cap)
	cap.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	cap.offset_left = 0.0
	cap.offset_right = 0.0
	cap.offset_top = 0.0
	cap.offset_bottom = 0.0
	cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	return cap

## The Hero's medallion clicked: he is picked, as a click on him in the world picks him, and his
## card opens in full -- or, open, shuts again.
func _on_cabin_emblem_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		home_view_requested.emit()
		get_viewport().set_input_as_handled()

## The key that takes the view home, as the keyboard writes it (Config.CONTROLS.camera_reset_key).
func _home_key_text() -> String:
	var cfg = _get_config()
	var key: int = int(cfg.CONTROLS.get("camera_reset_key", KEY_R)) if (cfg and "CONTROLS" in cfg) else KEY_R
	return OS.get_keycode_string(key)

func _on_hero_emblem_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_hero_details()
		get_viewport().set_input_as_handled()

## His card in full, or his commands alone again: the details key (Config.CONTROLS.details_key) and
## his medallion, as C opens the character sheet in Diablo IV (v0.6 round four). He is picked if he
## was not.
func toggle_hero_details() -> void:
	var panel_ok: bool = option_panel != null and is_instance_valid(option_panel) and option_panel.has_method("show_details")
	var open: bool = not (panel_ok and option_panel.showing_details())
	_select_hero()
	if panel_ok:
		option_panel.show_details(open)

## Build or Eat pressed: his menu comes up above its tile -- he is picked if he was not -- or, open
## already, goes.
func _open_hero_menu(menu: String) -> void:
	var hero: Node = get_tree().get_first_node_in_group("hero") if is_inside_tree() else null
	if hero == null or option_panel == null or not is_instance_valid(option_panel):
		return
	var open: bool = not option_panel.showing_menu(menu)
	_select_hero()
	option_panel.show_menu(menu if open else "default")

## The card above his commands changed: they take the number keys while it has none on them, and the
## tile whose menu is open stays pressed in.
func _on_card_changed() -> void:
	if hero_commands == null or option_panel == null or not is_instance_valid(option_panel):
		return
	hero_commands.set_keys_live(option_panel.leaves_keys())
	hero_commands.mark_open(String(option_panel.current_menu) if option_panel.shows_him() else "")

## The details key as the keyboard writes it.
func _details_key_text() -> String:
	var cfg = _get_config()
	var key: int = int(cfg.CONTROLS.get("details_key", KEY_C)) if (cfg and "CONTROLS" in cfg) else KEY_C
	return OS.get_keycode_string(key)

func _select_hero() -> void:
	var hero: Node = get_tree().get_first_node_in_group("hero") if is_inside_tree() else null
	var eb = _get_event_bus()
	if hero and eb and eb.has_signal("unit_selected"):
		eb.unit_selected.emit(hero)

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
## The start screen over the stopped valley (StartScreen): `fresh`, the level was just built for our game (the
## launch), so playing it needs no new one. Under the pause menu, whose settings it opens.
func show_start_screen(fresh: bool = false) -> void:
	if start_screen == null or not is_instance_valid(start_screen):
		start_screen = StartScreen.new()
		root_control.add_child(start_screen)
		if pause_menu and is_instance_valid(pause_menu):
			root_control.move_child(start_screen, pause_menu.get_index())
	start_screen.open(fresh)

func toggle_pause_menu() -> void:
	if pause_menu and is_instance_valid(pause_menu) and pause_menu.has_method("toggle"):
		pause_menu.toggle()
	_refresh_paused_overlay()

func is_pause_menu_open() -> bool:
	if pause_menu and is_instance_valid(pause_menu) and "is_open" in pause_menu:
		return bool(pause_menu.is_open)
	return false
