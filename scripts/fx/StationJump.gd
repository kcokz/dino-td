# res://scripts/fx/StationJump.gd
class_name StationJump
extends CanvasLayer

## THE JUMP BETWEEN STATIONS (the player, 2026-10-02: "把第一关先做完，做完之后可以试着做第二关，把这个串联动画也做出来";
## GAME-DESIGN 8.3, 9.2). At full charge the beacon throws the capsule through time -- in our game, on to its next
## station (Config.GAMES.campaign.stations), where it lands. Two halves, with the next station's level built afresh
## between them (GameState.jump_to_next_station, the scene built again):
##
##   DEPART  -- the run won with a station still ahead. The field goes quiet under it; the view swings in to the
##              cabin; a column of light stands up out of the beacon and the hull shakes, then lifts; the screen
##              goes white; and on the white, where it is going: the station, its age, its place, how long ago --
##              and what goes with it and what stays (the cabin and his tools; not the base, not the stock).
##   ARRIVE  -- the level the jump built. White, the same card; the view over the landing; the capsule comes down
##              out of the sky onto its spot with a blow of dust as the white clears -- and the run begins, the
##              card's line kept a while as a hint. The game is held still till it is down.
##
## The last station's jump is the end of the game as far as it goes: the HUD's victory card, not this.
## Its timings and sizes are Config.STATION_JUMP. Shown on a layer over everything (the HUD hidden meanwhile).

signal departed
signal landed

var _white: ColorRect = null
var _card: VBoxContainer = null
var _title: Label = null
var _subtitle: Label = null
var _line: Label = null
var _main: Node = null
var _running: bool = false

func _init() -> void:
	name = "StationJump"
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build()

func _jump(key: String, fallback: Variant) -> Variant:
	var cfg = get_node_or_null("/root/Config")
	return cfg.STATION_JUMP.get(key, fallback) if (cfg and "STATION_JUMP" in cfg) else fallback

func _seconds(key: String, fallback: float) -> float:
	return float(_jump(key, fallback))

func _build() -> void:
	if _white != null:
		return
	_white = ColorRect.new()
	_white.name = "White"
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.color = Color(_jump("white", Color.WHITE), 0.0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_white)
	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.add_child(centre)
	_card = VBoxContainer.new()
	_card.name = "Card"
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", UiTheme.space("m"))
	_card.modulate.a = 0.0
	centre.add_child(_card)
	_title = _label("Title", "display", "title", _jump("ink", Color(0.12, 0.10, 0.08)))
	_subtitle = _label("Subtitle", "medium", "heading", _jump("ink", Color(0.12, 0.10, 0.08)))
	_line = _label("Line", "regular", "body", _jump("ink_faint", Color(0.3, 0.27, 0.22)))
	_card.add_child(_title)
	_card.add_child(_subtitle)
	_card.add_child(_line)

func _label(node_name: String, face: String, size_key: String, colour: Color) -> Label:
	var l := Label.new()
	l.name = node_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.display_font("black") if face == "display" else UiTheme.font(face))
	l.add_theme_font_size_override("font_size", UiTheme.font_size(size_key))
	l.add_theme_color_override("font_color", colour)
	return l

## The card for station `index` of our game: its name, its age and place and how long ago, and what came with him.
func show_card(index: int) -> void:
	_build()
	var gs = get_node_or_null("/root/GameState")
	var row: Dictionary = gs.station_row(index) if (gs and gs.has_method("station_row")) else {}
	_title.text = tr(String(row.get("name", "")))
	_subtitle.text = tr("STATION_CARD_SUBTITLE") % [tr(String(row.get("age", ""))), tr(String(row.get("place", ""))),
		tr(String(row.get("when", "")))]
	_line.text = tr("STATION_CARD_CARRIED")

## Whether it is playing either half.
func is_running() -> bool:
	return _running

# ==============================================================================
# Departing
# ==============================================================================

## The capsule jumps from the level `main` to our game's next station: the beacon's light, the white, the card -- and
## the next level (`go_on`; the scene built afresh when `main` is the game's own scene).
func depart(main: Node) -> void:
	if _running:
		return
	_running = true
	_main = main
	var gs = get_node_or_null("/root/GameState")
	var next: int = int(gs.station) + 1 if gs else 1
	_hide_the_hud(true)
	_quiet_the_field(main)
	var core: Node3D = main.current_core if ("current_core" in main) else null
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if core != null and is_instance_valid(core):
		var rig: Object = main.camera_rig if ("camera_rig" in main) else null
		if rig != null:
			var from := {"focus": rig.focus, "distance": rig.distance, "tilt": rig.tilt}
			var to := {"focus": core.global_position, "distance": float(_jump("view_distance", 16.0)),
				"tilt": float(_jump("view_tilt", 30.0))}
			tw.tween_method(_view.bind(from, to), 0.0, 1.0, _seconds("view_seconds", 1.6)).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_raise_the_beam.bind(core))
		tw.tween_interval(_seconds("beam_seconds", 1.8))
		tw.tween_callback(_lift.bind(core))
	tw.tween_property(_white, "color:a", 1.0, _seconds("white_seconds", 1.2)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(show_card.bind(next))
	tw.tween_property(_card, "modulate:a", 1.0, _seconds("card_fade", 0.6))
	tw.tween_interval(_seconds("card_seconds", 3.0))
	tw.tween_callback(go_on)

## The field goes quiet under it: the run is won, and what was out after the cabin or him breaks off and goes back
## where it came from, as at its hour's end (Dino.go_home) -- a raider to the nearest nest, a night hunter to the river
## (ProwlerDino keeps its own home). The nest's guards are at home already. Left to it, the beacon's last raid went on
## biting the hull as it lifted, and could kill him on the way out of a run already won.
func _quiet_the_field(main: Node) -> void:
	if not is_inside_tree():
		return
	var waves: Node = main.wave_manager if ("wave_manager" in main) else null
	if waves == null or not is_instance_valid(waves) or not waves.has_method("nearest_nest"):
		return
	for d in get_tree().get_nodes_in_group("dinos"):
		if not is_instance_valid(d) or d.is_in_group("guard_dinos") or not d.has_method("go_home"):
			continue
		d.go_home(waves.nearest_nest((d as Node3D).global_position))

## The view eased from `from` to `to` (focus, distance, tilt), `t` of the way.
func _view(t: float, from: Dictionary, to: Dictionary) -> void:
	if _main == null or not is_instance_valid(_main) or not ("camera_rig" in _main):
		return
	var rig: Object = _main.camera_rig
	rig.focus = (from["focus"] as Vector3).lerp(to["focus"], t)
	rig.distance = lerpf(float(from["distance"]), float(to["distance"]), t)
	rig.tilt = lerpf(float(from["tilt"]), float(to["tilt"]), t)
	if "camera" in _main and _main.camera != null:
		rig.apply_to(_main.camera)

## The column of light out of the beacon: up out of the cabin's roof into the sky, the beacon's own sound with it.
func _raise_the_beam(core: Node3D) -> void:
	if not is_instance_valid(core) or not core.is_inside_tree():
		return
	var beam := MeshInstance3D.new()
	beam.name = "JumpBeam"
	var tube := CylinderMesh.new()
	tube.top_radius = float(_jump("beam_radius", 0.8))
	tube.bottom_radius = tube.top_radius
	tube.height = float(_jump("beam_height", 60.0))
	beam.mesh = tube
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = _jump("beam_colour", Color(0.55, 0.85, 1.0, 0.75))
	beam.material_override = glow
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.add_child(beam)
	beam.position = Vector3(0.0, tube.height * 0.5, 0.0)
	beam.scale = Vector3(0.05, 0.01, 0.05)
	var light := OmniLight3D.new()
	light.name = "JumpLight"
	light.light_color = Color(glow.albedo_color, 1.0)
	light.omni_range = float(_jump("light_range", 30.0))
	light.light_energy = 0.0
	light.position = Vector3(0.0, float(_jump("light_height", 4.0)), 0.0)
	core.add_child(light)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(beam, "scale", Vector3.ONE, _seconds("beam_seconds", 1.8)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", float(_jump("light_energy", 6.0)), _seconds("beam_seconds", 1.8))
	_sound("beacon_launch", core.global_position)

## The cabin shakes, then lifts off the ground into the light -- all of it, its benches inside with it. The run is
## won: nothing goes on round it that its place matters to.
func _lift(core: Node3D) -> void:
	if not is_instance_valid(core):
		return
	var rest: Vector3 = core.position
	var shake: float = float(_jump("shake", 0.06))
	var step: float = _seconds("shake_step", 0.05)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in int(_jump("shakes", 6)):
		var side: float = shake if i % 2 == 0 else -shake
		tw.tween_property(core, "position", rest + Vector3(side, 0.0, -side * 0.5), step)
	tw.tween_property(core, "position", rest + Vector3(0.0, float(_jump("lift", 1.5)), 0.0), _seconds("white_seconds", 1.2)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## On to the next station: the run moved on (GameState.jump_to_next_station) and its level built -- the scene afresh
## when `main` is the game's own scene; a level a script built (a test) is told, and builds its own.
func go_on() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("jump_to_next_station"):
		gs.jump_to_next_station()
	_running = false
	departed.emit()
	if _main != null and is_instance_valid(_main) and _main.is_inside_tree() and _main.get_tree().current_scene == _main:
		_main.get_tree().reload_current_scene()

# ==============================================================================
# Arriving
# ==============================================================================

## The level `main` has just been built by the jump: white and the card at once, the game held, the capsule up in the
## sky over its spot -- and then it comes down as the white clears.
func arrive(main: Node) -> void:
	if _running:
		return
	_running = true
	_main = main
	_build()
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.set_paused(true)
	_hide_the_hud(true)
	show_card(int(gs.station) if gs else 0)
	_white.color.a = 1.0
	_card.modulate.a = 1.0
	# The whole cabin up in the sky over its spot -- its benches inside it -- the game held still meanwhile: nothing
	# asks where it is till it is down.
	var core: Node3D = main.current_core if ("current_core" in main) else null
	if core != null and not is_instance_valid(core):
		core = null
	var hero: Node3D = main.hero if ("hero" in main) else null
	if hero != null and is_instance_valid(hero):
		hero.visible = false
	var rest: Vector3 = core.position if core != null else Vector3.ZERO
	var spot: Vector3 = core.global_position if core != null else Vector3.ZERO
	if core != null:
		core.position = rest + Vector3(0.0, float(_jump("drop_height", 40.0)), 0.0)
	if core != null and "camera_rig" in main:
		var rig: Object = main.camera_rig
		rig.focus = spot
		rig.distance = float(_jump("landing_distance", 26.0))
		rig.tilt = float(_jump("landing_tilt", 38.0))
		if "camera" in main and main.camera != null:
			rig.apply_to(main.camera)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(_seconds("card_seconds", 3.0))
	tw.tween_property(_card, "modulate:a", 0.0, _seconds("card_fade", 0.6))
	tw.set_parallel(true)
	tw.tween_property(_white, "color:a", 0.0, _seconds("drop_seconds", 1.6))
	if core != null:
		tw.tween_property(core, "position", rest, _seconds("drop_seconds", 1.6)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(_touch_down.bind(core, hero))
	tw.tween_interval(_seconds("settle_seconds", 0.8))
	tw.tween_callback(_begin)

## Down: a blow of dust round the hull, the thud of it, and he steps out.
func _touch_down(core: Node3D, hero: Node3D) -> void:
	if core != null and is_instance_valid(core):
		var fx = get_node_or_null("/root/Fx")
		var half: Vector2 = Vector2(3.5, 1.5)
		var cfg = get_node_or_null("/root/Config")
		if cfg and "building_type" in core:
			half = cfg.get_building_half(String(core.building_type))
		if fx and fx.has_method("debris"):
			for corner in [Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y), Vector3(half.x, 0, -half.y), Vector3(-half.x, 0, -half.y)]:
				fx.debris(core.global_position + corner, _jump("dust_colour", Color(0.62, 0.52, 0.38)), int(_jump("dust", 14)))
		_sound("landing", core.global_position)
	if hero != null and is_instance_valid(hero):
		hero.visible = true

## The run begins: the game let go, the HUD back, the card's line said once more as a hint.
func _begin() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.set_paused(false)
	if gs and "arrived_by_jump" in gs:
		gs.arrived_by_jump = false
	_hide_the_hud(false)
	_running = false
	if _main != null and is_instance_valid(_main) and _main.has_method("_hint"):
		_main._hint("HINT_STATION_ARRIVED", [_title.text])
	landed.emit()

# ==============================================================================

func _hide_the_hud(hidden: bool) -> void:
	if _main == null or not is_instance_valid(_main) or not ("hud" in _main):
		return
	var hud = _main.hud
	if hud != null and is_instance_valid(hud) and "visible" in hud:
		hud.visible = not hidden

func _sound(id: String, at: Vector3) -> void:
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("play_at"):
		fx.play_at(id, at)

## Done at once, both halves: for a test, and for a level a script built -- the tweens' ends, without the waits.
func finish_now() -> void:
	for t in get_tree().get_processed_tweens():
		if is_instance_valid(t) and t.is_valid():
			t.custom_step(1000.0)
