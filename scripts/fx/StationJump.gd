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
##
## And THE OPENING (crash): a run chosen on the start screen opens on how it began -- the capsule's fall into the
## first station's valley, burning, and the valley answering it.
##
## Its timings and sizes are Config.STATION_JUMP. Shown on a layer over everything (the HUD hidden meanwhile).

signal departed
signal landed
signal crashed

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

## The view eased from `from` to `to` (focus, distance, tilt -- and its bearing, where both say one), `t` of the way.
func _view(t: float, from: Dictionary, to: Dictionary) -> void:
	if _main == null or not is_instance_valid(_main) or not ("camera_rig" in _main):
		return
	var rig: Object = _main.camera_rig
	if rig == null:
		return
	rig.focus = (from["focus"] as Vector3).lerp(to["focus"], t)
	rig.distance = lerpf(float(from["distance"]), float(to["distance"]), t)
	rig.tilt = lerpf(float(from["tilt"]), float(to["tilt"]), t)
	if from.has("yaw") and to.has("yaw"):
		rig.yaw = rad_to_deg(lerp_angle(deg_to_rad(float(from["yaw"])), deg_to_rad(float(to["yaw"])), t))
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
	_sound_through(true)
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
	_sound_through(false)
	if gs and "arrived_by_jump" in gs:
		gs.arrived_by_jump = false
	_hide_the_hud(false)
	_running = false
	if _main != null and is_instance_valid(_main) and _main.has_method("_hint"):
		_main._hint("HINT_STATION_ARRIVED", [_title.text])
	landed.emit()

# ==============================================================================
# The crash: the opening
# ==============================================================================

## Whether the crash is playing, and when it began (a press a moment after is the one that chose the game); its
## tween; what it lit -- the trail's flames and smoke, the fire's light, the dust (each its own process while the
## game is held, its world's after); and whether it is being ended at once (skip), when the valley's cries are not
## let out all together.
var _crashing: bool = false
var _crash_began_at: int = 0
var _crash_tween: Tween = null
var _lit: Array[Node3D] = []
var _skipping: bool = false
var _shake_dice := RandomNumberGenerator.new()

## THE OPENING (GAME-DESIGN 3.0; the player, 2026-10-04: "可以在v0.7做一个开场动画，船舱坠落，山谷受到震动，恐龙进攻船舱
## 是出于对不明物体的恐惧"). A run chosen on the start screen opens on how it began (Main.open_on_the_crash). The view,
## low over the valley on the run's own bearing, finds the capsule high in the sky, burning, smoke streaming off it,
## and follows it down; the blow -- the view shaken, dust thrown up, a ring of it running out along the ground -- and
## the valley answers out of the mist: a grazer on its walls bellowing, the nest's animals calling at the strange thing
## come down among them. Then the view the run has, the hull smoking a while, and he climbs out; the hint says what it
## was. A click or a key ends it at once (skip).
##
## The game is held still meanwhile, as for a landing, and the mist is not lifted: the capsule comes down steeply,
## inside what the cabin sees (Config.FOG.sight) -- seen before it goes up -- so the mist does not swallow it; its
## flames and smoke are drawn over the mist, as a wreck's smoke is. Heard and not seen, the nest stays unfound.
func crash(main: Node) -> void:
	if _running or main == null or not is_instance_valid(main):
		return
	var core: Node3D = main.current_core if ("current_core" in main) else null
	if core == null or not is_instance_valid(core) or not core.is_inside_tree():
		return
	_running = true
	_crashing = true
	_main = main
	_crash_began_at = Time.get_ticks_msec()
	_see_round_the_spot(main)
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.set_paused(true)
	# Heard as it is seen: its fall, its blow, the valley's cries -- the game held for it, not by the player -- and on
	# its own: whatever the world was sounding before is stopped.
	_sound_through(true)
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("hush"):
		fx.hush()
	_hide_the_hud(true)
	var hero: Node3D = main.hero if ("hero" in main) else null
	if hero != null and is_instance_valid(hero):
		hero.visible = false
	var rest: Transform3D = core.global_transform
	var spot: Vector3 = rest.origin
	var rig: Object = main.camera_rig if ("camera_rig" in main) else null
	var home: Dictionary = rig.home() if rig != null else {}
	if home.is_empty() and rig != null:
		home = {"focus": rig.focus, "yaw": rig.yaw, "tilt": rig.tilt, "distance": rig.distance}
	var yaw: float = deg_to_rad(float(home.get("yaw", 0.0)))
	var low: float = deg_to_rad(float(_jump("crash_view_tilt", 12.0)))
	var away: float = float(_jump("crash_distance", 34.0))
	# Where the view stands: low over the valley, on the run's bearing. Where the capsule comes from: high over its spot
	# and a little across the view, its nose down and rolled; it levels as it nears the ground.
	var eye: Vector3 = spot + Vector3(sin(yaw) * cos(low), sin(low), cos(yaw) * cos(low)) * away
	var across := Vector3(cos(yaw), 0.0, -sin(yaw))
	var high: Vector3 = across * float(_jump("crash_side", 4.0)) + Vector3.UP * float(_jump("crash_height", 80.0))
	var lean := Vector3(deg_to_rad(float(_jump("crash_pitch", 22.0))), 0.0, deg_to_rad(float(_jump("crash_roll", -12.0))))
	_light_the_trail(core)
	_fall(0.0, core, rest, high, lean, eye)
	_sound("crash_fall", spot + high * 0.5)
	var tw := create_tween()
	_crash_tween = tw
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# At its own pace, whatever speed the last run was left at (HUD.set_game_speed: Engine.time_scale outlives a level).
	tw.set_ignore_time_scale(true)
	tw.tween_method(_fall.bind(core, rest, high, lean, eye), 0.0, 1.0, _seconds("crash_fall_seconds", 2.4)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_blow.bind(core, rest))
	tw.tween_method(_shaken.bind(eye, spot), 1.0, 0.0, _seconds("crash_shake_seconds", 0.8))
	tw.tween_interval(_seconds("crash_calls_after", 0.4))
	for crier in _criers(main, spot):
		tw.tween_callback(_cry.bind(crier))
		tw.tween_interval(_seconds("crash_calls_gap", 0.55))
	tw.tween_interval(_seconds("crash_hold", 1.2))
	tw.tween_callback(_climb_out.bind(hero))
	# From the view it was left at -- from the eye, on the hull -- to the run's own.
	var on_it: Vector3 = spot + Vector3.UP * float(_jump("crash_look_up", 1.5))
	var back: Vector3 = eye - on_it
	var down_view := {"focus": on_it, "yaw": rad_to_deg(atan2(back.x, back.z)),
		"tilt": rad_to_deg(asin(clampf(back.y / maxf(0.01, back.length()), -1.0, 1.0))), "distance": back.length()}
	tw.tween_method(_view.bind(down_view, home), 0.0, 1.0, _seconds("crash_view_seconds", 1.4)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_crash_over)

## Whether the opening is playing.
func is_crashing() -> bool:
	return _crashing

## What the cabin and he see, seen before it goes up: the ground round its spot clear of the mist, as the run's first
## moment would have it. The mist holds still with the game meanwhile (FogOfWar), so the hull high over its spot finds
## nothing new.
func _see_round_the_spot(main: Node) -> void:
	var fog: Node = main.get("fog") as Node
	if fog == null or not is_instance_valid(fog) or not fog.has_method("_look"):
		return
	fog._look()
	fog._paint(1.0)
	fog._hide_the_unseen()

## `t` of the way down: the capsule on its slant -- burning, nose down, levelling as it nears the ground -- and the view
## following it from where it stands.
func _fall(t: float, core: Node3D, rest: Transform3D, high: Vector3, lean: Vector3, eye: Vector3) -> void:
	if not is_instance_valid(core):
		return
	var at: Vector3 = rest.origin + high * (1.0 - t)
	core.global_transform = Transform3D(rest.basis * Basis.from_euler(lean * (1.0 - t)), at)
	_look_from(eye, at + Vector3.UP * float(_jump("crash_look_up", 1.5)))

## The view standing at `eye` and looking at `at`: the camera rig's focus, bearing, tilt and distance so (CameraRig.offset).
func _look_from(eye: Vector3, at: Vector3) -> void:
	if _main == null or not is_instance_valid(_main) or not ("camera_rig" in _main):
		return
	var rig: Object = _main.camera_rig
	if rig == null:
		return
	var back: Vector3 = eye - at
	var dist: float = maxf(0.01, back.length())
	rig.focus = at
	rig.distance = dist
	rig.tilt = rad_to_deg(asin(clampf(back.y / dist, -1.0, 1.0)))
	rig.yaw = rad_to_deg(atan2(back.x, back.z))
	if "camera" in _main and _main.camera != null:
		rig.apply_to(_main.camera)

## The capsule's trail as it comes down: flames streaming off the hull (the campfire's own, Fire.make_flame, many times
## over), the smoke they leave hanging in the sky, and the fire's light on the land under it.
func _light_the_trail(core: Node3D) -> void:
	_lit.clear()
	var cfg = get_node_or_null("/root/Config")
	var flame: GPUParticles3D = Fire.make_flame(cfg.FIRE if (cfg and "FIRE" in cfg) else {}, float(_jump("trail_flame", 8.0)))
	flame.name = "CrashFlame"
	flame.amount = int(_jump("trail_flames", 110))
	_stretch(flame)
	_over_the_mist(flame)
	_hold(core, flame, Vector3.ZERO)
	var smoke: GPUParticles3D = _puffs("CrashSmoke", int(_jump("trail_puffs", 360)), _seconds("trail_seconds", 4.0),
		float(_jump("trail_puff", 1.6)), 3.0, 0.8, _jump("trail_colour", Color(0.2, 0.19, 0.18, 0.85)))
	_stretch(smoke)
	_hold(core, smoke, Vector3.ZERO)
	var light := OmniLight3D.new()
	light.name = "CrashLight"
	light.light_color = _jump("fire_colour", Color(1.0, 0.55, 0.18))
	light.omni_range = float(_jump("crash_light_range", 26.0))
	light.light_energy = float(_jump("crash_light", 6.0))
	_hold(core, light, Vector3(0.0, 2.0, 0.0))

## `node` on the hull, at `offset` from its middle: running while the game is held (and the world's again once the run
## begins, _crash_over).
func _hold(core: Node3D, node: Node3D, offset: Vector3) -> void:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	core.add_child(node)
	node.position = offset
	_lit.append(node)

## Smoke: `amount` soft puffs living `lifetime` seconds, each from `size` metres to `billow` times it, rising at `rise`
## and carried on the wind -- left in the world where they were let go, and drawn over the mist.
func _puffs(node_name: String, amount: int, lifetime: float, size: float, billow: float, rise: float, colour: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = size * 0.5
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = rise * 0.6
	m.initial_velocity_max = rise * 1.2
	m.gravity = _jump("smoke_wind", Vector3(0.25, 0.1, 0.12))
	m.damping_min = 0.2
	m.damping_max = 0.4
	m.angle_min = 0.0
	m.angle_max = 360.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 1.0 / maxf(1.0, billow)))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.08, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(colour, 0.0), colour, Color(colour, colour.a * 0.6), Color(colour, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size * billow
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = Fire._soft_disc()
	mat.disable_receive_shadows = true
	quad.material = mat
	p.draw_pass_1 = quad
	_over_the_mist(p)
	return p

## Let go along a stretch of the way it falls rather than at one point: falling as fast as it does by the end, a frame
## apart the puffs were beads on a string (Config.STATION_JUMP.trail_stretch, about a frame's fall).
func _stretch(p: GPUParticles3D) -> void:
	var m := p.process_material as ParticleProcessMaterial
	if m == null:
		return
	var across: float = float(_jump("trail_puff", 1.6)) * 0.4
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(across, float(_jump("trail_stretch", 2.0)), across)

## Drawn after the mist (FogOfWar draws at one less), as a wreck's smoke is: the fall reads against the haze. And never
## culled while any of it is in the air: the puffs are left where they were let go, the hull long gone on.
func _over_the_mist(p: GPUParticles3D) -> void:
	var quad := p.draw_pass_1 as PrimitiveMesh
	if quad != null and quad.material is BaseMaterial3D:
		(quad.material as BaseMaterial3D).render_priority = Material.RENDER_PRIORITY_MAX
	var reach: float = float(_jump("crash_height", 80.0)) + 30.0
	p.visibility_aabb = AABB(Vector3(-reach, -reach, -reach), Vector3.ONE * reach * 2.0)

## The blow: the hull on its spot, level; its flames out, the smoke it trailed left hanging and its own rising off it;
## dust thrown up all round it and a ring of it running out along the ground; the boom; the fire's light dying.
func _blow(core: Node3D, rest: Transform3D) -> void:
	var spot: Vector3 = rest.origin
	if core == null or not is_instance_valid(core):
		_sound("crash", spot)
		return
	core.global_transform = rest
	for n in _lit:
		if not is_instance_valid(n):
			continue
		if n is GPUParticles3D:
			(n as GPUParticles3D).emitting = false
			_gone_after(n, (n as GPUParticles3D).lifetime)
		elif n is OmniLight3D:
			var fade := n.create_tween()
			fade.tween_property(n, "light_energy", 0.0, _seconds("crash_light_fade", 1.2))
			fade.tween_callback(n.queue_free)
	var half := Vector2(3.5, 1.5)
	var cfg = get_node_or_null("/root/Config")
	if cfg and "building_type" in core:
		half = cfg.get_building_half(String(core.building_type))
	var dust: Color = _jump("dust_colour", Color(0.62, 0.52, 0.38))
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("debris"):
		for corner in [Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y), Vector3(half.x, 0, -half.y), Vector3(-half.x, 0, -half.y)]:
			fx.debris(spot + corner, dust, int(_jump("crash_dust", 24)))
	# The dust thrown up all round it, settling.
	var cloud: GPUParticles3D = _puffs("CrashDust", int(_jump("crash_dust_puffs", 40)), _seconds("crash_dust_seconds", 3.0),
		1.4, 3.0, 5.0, _jump("crash_dust_colour", Color(0.58, 0.52, 0.45, 0.6)))
	var m := cloud.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(half.x, 0.3, half.y)
	m.spread = 75.0
	m.damping_min = 2.5
	m.damping_max = 3.5
	m.gravity = Vector3(0.0, -0.4, 0.0)
	cloud.one_shot = true
	cloud.explosiveness = 0.9
	_hold(core, cloud, Vector3(0.0, 0.4, 0.0))
	_gone_after(cloud, cloud.lifetime + 0.5)
	_ring(core, dust)
	# And it smokes a while where it lies (Config.STATION_JUMP.smoulder_*).
	var smoulder: GPUParticles3D = _puffs("CrashSmoulder", int(_jump("smoulder_puffs", 36)), _seconds("smoulder_life", 9.0),
		float(_jump("smoulder_puff", 0.9)), 4.0, float(_jump("smoulder_rise", 1.8)),
		_jump("smoulder_colour", Color(0.44, 0.42, 0.4, 0.42)))
	_hold(core, smoulder, Vector3(0.0, float(_jump("smoulder_height", 2.6)), 0.0))
	var out := smoulder.create_tween()
	out.tween_interval(_seconds("smoulder_seconds", 45.0))
	out.tween_callback(func(): smoulder.emitting = false)
	out.tween_interval(smoulder.lifetime)
	out.tween_callback(smoulder.queue_free)
	_sound("crash", spot)

## `node` freed `seconds` on, by its own clock.
func _gone_after(node: Node, seconds: float) -> void:
	var tw := node.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(node.queue_free)

## A ring of dust running out along the ground from the blow: the valley shaken.
func _ring(core: Node3D, dust: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "CrashRing"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	ring.mesh = plane
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 0.86, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.albedo_texture = tex
	mat.albedo_color = Color(dust, 0.8)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hold(core, ring, Vector3(0.0, 0.15, 0.0))
	var reach: float = float(_jump("crash_ring", 16.0))
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(reach, 1.0, reach), _seconds("crash_ring_seconds", 0.9)) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, _seconds("crash_ring_seconds", 0.9)).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)

## The view shaken by the blow, `k` of its strength left.
func _shaken(k: float, eye: Vector3, spot: Vector3) -> void:
	var amp: float = float(_jump("crash_shake", 0.5)) * k
	var j := Vector3(_shake_dice.randf_range(-1.0, 1.0), _shake_dice.randf_range(-1.0, 1.0), _shake_dice.randf_range(-1.0, 1.0)) * amp
	_look_from(eye + j * 0.4, spot + Vector3.UP * float(_jump("crash_look_up", 1.5)) + j)

## Who answers the blow, in turn, out of the mist -- heard, not seen: the nearest grazer on the valley's walls, the
## nest's animals, the nearest first, and another grazer (Config.STATION_JUMP.crash_calls of them at most).
func _criers(main: Node, spot: Vector3) -> Array:
	var nearest := func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(spot) < b.global_position.distance_squared_to(spot)
	var grazers: Array = []
	var herds: Node = main.get_node_or_null("Herds")
	if herds != null:
		for a in herds.get_children():
			if a is Node3D and a.has_meta(&"species"):
				grazers.append(a)
	grazers.sort_custom(nearest)
	var guards: Array = []
	if is_inside_tree():
		for g in get_tree().get_nodes_in_group("guard_dinos"):
			if g is Node3D and is_instance_valid(g) and g.has_method("say"):
				guards.append(g)
	guards.sort_custom(nearest)
	var out: Array = []
	if not grazers.is_empty():
		out.append(grazers[0])
	out.append_array(guards.slice(0, 3))
	if grazers.size() > 1:
		out.append(grazers[1])
	out.append_array(guards.slice(3))
	return out.slice(0, int(_jump("crash_calls", 5)))

## One cry: a nest's animal calls the alarm (Dino.say); a grazer, its own call. Not when the crash is being ended at
## once -- they would all cry out together.
func _cry(who: Node) -> void:
	if _skipping or who == null or not is_instance_valid(who) or not (who is Node3D) or not who.is_inside_tree():
		return
	if who.has_method("say"):
		who.say("alert")
	else:
		_sound(String(who.get_meta(&"species", "")) + "_call", (who as Node3D).global_position + Vector3.UP)

## He climbs out of it.
func _climb_out(hero: Node3D) -> void:
	if hero != null and is_instance_valid(hero):
		hero.visible = true

## Over: the game let go, the HUD back, and what happened said once as a hint; the hull smokes on a while, with the
## world's clock now.
func _crash_over() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.set_paused(false)
	_sound_through(false)
	_hide_the_hud(false)
	for n in _lit:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_INHERIT
	_lit.clear()
	_running = false
	_crashing = false
	_crash_tween = null
	if _main != null and is_instance_valid(_main) and _main.has_method("_hint"):
		_main._hint("HINT_CRASHED")
	crashed.emit()

## The crash ended at once: the capsule down, the view the run's, the run begun -- what was still to cry out, not.
func skip() -> void:
	if not _crashing or _crash_tween == null or not _crash_tween.is_valid():
		return
	_skipping = true
	_crash_tween.custom_step(1000.0)
	_skipping = false

## A click or a key while the crash plays ends it (skip) -- not the press that chose the game, a moment before -- and
## goes no further: not to the level's own keys (the pause, the menu) meanwhile.
func _unhandled_input(event: InputEvent) -> void:
	if not _crashing:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _crash_began_at >= int(_seconds("crash_skip_after", 0.5) * 1000.0):
		skip()

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

## While it holds the game, its sound -- and the valley's -- goes on under it (Fx.play_through_pause): the crash was
## seen and not heard, the world's sounds held with the pause it had put the game in.
func _sound_through(on: bool) -> void:
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("play_through_pause"):
		fx.play_through_pause(self, on)

## Done at once, any of it: for a test, and for a level a script built -- the tweens' ends, without the waits (and
## without the crash's cries all at once).
func finish_now() -> void:
	_skipping = true
	for t in get_tree().get_processed_tweens():
		if is_instance_valid(t) and t.is_valid():
			t.custom_step(1000.0)
	_skipping = false
