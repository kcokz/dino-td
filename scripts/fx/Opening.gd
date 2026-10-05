# res://scripts/fx/Opening.gd
class_name Opening
extends Node3D

## THE OPENING FILM (the player, 2026-10-04: "开场动画还要精致化一点，甚至你可以做一个完整飞船穿越，出现故障，人在船舱中睡眠，然后
## 船舱解体，掉落，震动山谷，把各个被惊吓得恐龙刻画出来，它们躁动不安，追寻着烟去了，人惊醒，打开舱门，从船舱爬出来（人脸可以有
## 特写），然后开始……这个开场动画要有大片感，专业游戏的精致度，然后配音你可以想办法"). Our own game's first station opens on it
## (Main.open_on_the_crash), shot by shot (Config.OPENING):
##
##   the jump      space; the ship running through the time tunnel, its drive's ring alight. The ship's voice: all well.
##   the failure   the ring guttering red, sparks off it, the tunnel tearing, the view shaken. Drive failure.
##   asleep        in the crew module, him asleep in the pod under the alarm's red light, the view drawing in to his
##                 face. Hull breach; the module separating.
##   the break-up  out over the world below: the module blown free, the ship coming apart behind it -- its dish, a
##                 battery bay, its control unit tumbling away -- what lies in the valley as wrecks.
##   the fall      the module down into the valley, burning, and its blow (StationJump.crash, as before).
##   the valley    the nest's pack startled, at the strange smoke; the grazers on the walls bolting; the armoured ones
##                 snorting, then off towards the smoke.
##   awake         his eyes opening, the module's room swimming into sight; out of the pod, the hatch, out into the
##                 light, the smoke over the valley -- the game's name over it, and the run begins.
##
## Letterboxed, the ship's voice speaking its own words under them (Config.OPENING.lines; the files are
## assets/audio/voice_ship_*.wav, tools/make_ship_voice.py). Everything it moves it puts back; everything it brings it
## takes away. A click or a key ends it at once (skip): then the briefing says what it would have (HUD.brief).
##
## The game is held still through it (GameState.set_paused), as for the crash; what plays, plays through the pause.

signal finished

## Whether the player ended it at once.
var was_skipped: bool = false
## How fast it runs (1 as shot): a test's quicker.
var pace: float = 1.0

var _main: Node = null
var _core: Node3D = null
var _hero: Node3D = null
var _running: bool = false
var _skipping: bool = false
## Whether the shots above the world are over (the fall begun).
var _fell: bool = false
var _began_at: int = 0
var _tw: Tween = null
var _cam: Camera3D = null
var _cabin_home: Transform3D = Transform3D.IDENTITY
var _set: Node3D = null
var _ship: Node3D = null
var _tunnel_mat: ShaderMaterial = null
var _glows: Array[ShaderMaterial] = []
var _planet: MeshInstance3D = null
var _alarm: OmniLight3D = null
var _env_was: Environment = null
var _sun_was: Dictionary = {}
var _fog_was: bool = true
var _overlay: CanvasLayer = null
var _bars: Array[ColorRect] = []
var _subtitle: Label = null
var _title: Label = null
var _lids: Array[ColorRect] = []
var _flash: ColorRect = null
## What it put in the world (gone after), and what it moved or set going (put back after): [node, what it was].
var _actors: Array[Node] = []
var _moved: Array = []
var _always: Array = []
## His head bowed asleep (Skeleton3D pose on HEAD_BONE), and how it stands otherwise.
var _sk: Skeleton3D = null
var _head: int = -1
var _head_rest: Quaternion = Quaternion.IDENTITY
var _floated: bool = false
var _shake: float = 0.0
var _shake_at: Vector3 = Vector3.ZERO
var _dice := RandomNumberGenerator.new()

const HEAD_BONE: String = "Head"
const NECK_BONE: String = "neck_01"

func _init() -> void:
	name = "Opening"
	process_mode = Node.PROCESS_MODE_ALWAYS

## Whether it is playing.
func is_playing() -> bool:
	return _running

# ==============================================================================
# Begun, and ended
# ==============================================================================

## The film, from the jump to the run's first moment. Not twice at once.
func play(main: Node) -> void:
	if _running or main == null or not is_instance_valid(main):
		return
	var core: Node3D = main.current_core if ("current_core" in main) else null
	if core == null or not is_instance_valid(core) or not core.is_inside_tree():
		return
	_main = main
	_core = core
	_hero = main.hero if ("hero" in main) else null
	_running = true
	_skipping = false
	_fell = false
	was_skipped = false
	_began_at = Time.get_ticks_msec()
	_dice.seed = int(_opening("seed", 7))
	_cabin_home = core.global_transform
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("set_paused"):
		gs.set_paused(true)
	_sound_through(true)
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("hush"):
		fx.hush()
	_hide_the_hud(true)
	_build_overlay()
	_build_the_set()
	_use_camera()
	# Its first frame the jump's: up out of black onto the ship in the tunnel.
	_point(_s(Vector3(42.0, 7.0, 20.0)), _s(Vector3(8.0, 1.0, 0.0)))
	_fov(52.0)
	_tunnel_mat.set_shader_parameter("strength", 1.0)
	_flash.color = Color(0.0, 0.0, 0.0, 1.0)
	_tween().tween_property(_flash, "color:a", 0.0, _secs("fade_in", 1.4)).set_ease(Tween.EASE_IN)
	_tw = _tween()
	_tw.tween_method(_bars_at, 0.0, 1.0, _secs("bars_in", 0.8)).set_trans(Tween.TRANS_SINE)
	_shot_jump()
	_shot_failure()
	_shot_asleep()
	_shot_breakup()
	_tw.tween_callback(_to_the_fall)

## The fall over (StationJump.crash, its blow and shaking): the valley startled, and him awake.
func after_the_blow() -> void:
	if not _running:
		return
	if _skipping or _station_skipped():
		was_skipped = true
		_finish()
		return
	_lift_the_mist(true)
	_tw = _tween()
	_shot_valley()
	_shot_awake()
	_tw.tween_callback(_finish)

## Ended at once: what it would have shown done -- the module down, him out of it -- and the briefing to say why.
func skip() -> void:
	if not _running or _skipping:
		return
	_skipping = true
	was_skipped = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not _fell:
		_to_the_fall()
		var jump: Node = _station()
		if jump != null and jump.has_method("skip"):
			jump.skip()
	else:
		_finish()

## A click or a key ends it -- not the press that chose the game, a moment before -- and goes no further. Through the
## fall it is the fall's to end (StationJump), and the film ends with it.
func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if not pressed:
		return
	var jump: Node = _station()
	if jump != null and jump.has_method("is_crashing") and bool(jump.is_crashing()):
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _began_at >= int(_secs("skip_after", 0.6) * 1000.0):
		skip()

## Done: everything it moved put back, everything it brought gone; him out of the module at its door; the run's own
## view and the game let go (StationJump.end_crash).
func _finish() -> void:
	if not _running:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	_strike_the_set()
	_lift_the_mist(false)
	_put_back()
	for a in _actors:
		if is_instance_valid(a):
			a.queue_free()
	_actors.clear()
	_wake(1.0)
	if _floated and _hero != null and is_instance_valid(_hero) and _hero.has_method("_float"):
		_hero._float(false)
	_floated = false
	if _hero != null and is_instance_valid(_hero):
		_hero.visible = true
		if _core != null and is_instance_valid(_core) and _core.has_method("door_outside"):
			_hero.global_position = _core.door_outside()
			var away: Vector3 = _core.door_outside() + _flat_dir(_core.door_outside() - _core.global_position)
			away.y = _hero.global_position.y
			if _hero.global_position.distance_to(away) > 0.01:
				_hero.look_at(away, Vector3.UP)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	if _cam != null and is_instance_valid(_cam):
		_cam.current = false
		_cam.queue_free()
	_cam = null
	_home_view()
	var jump: Node = _station()
	if jump != null and jump.has_method("end_crash"):
		jump.end_crash()
	else:
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.has_method("set_paused"):
			gs.set_paused(false)
		_hide_the_hud(false)
	_sound_through(false)
	if _core != null and is_instance_valid(_core) and _core.has_method("set_door_open"):
		_core.set_door_open(false)
	_running = false
	finished.emit()

## Done at once, the whole of it: for a test.
func finish_now() -> void:
	skip()

# ==============================================================================
# The shots above the world
# ==============================================================================

## THE JUMP: the ship in the time tunnel, the view passing along it from its engines to the module, the ring alight.
func _shot_jump() -> void:
	var secs: float = _secs("jump", 6.5)
	_tw.tween_callback(func():
		_use_camera()
		_tunnel_mat.set_shader_parameter("strength", 1.0))
	_move(Vector3(42.0, 7.0, 20.0), Vector3(8.0, 1.0, 0.0), Vector3(-6.0, 3.0, 15.0), Vector3(3.0, 1.0, 0.0), secs, 52.0, 46.0)
	_say_in("jump", secs)

## THE FAILURE: the ring guttering red, sparks off it, the tunnel tearing red, the view shaking; the alarm; then the
## white of it, and out of the tunnel over the world.
func _shot_failure() -> void:
	var secs: float = _secs("failure", 4.5)
	_tw.tween_callback(func():
		_sound("film_fault")
		_sound("film_alarm")
		_sparks_round_the_ring())
	_tw.tween_method(_fault, 0.0, 1.0, secs * 0.7).set_trans(Tween.TRANS_SINE)
	_tw.parallel().tween_method(_shaken, 0.0, 1.0, secs)
	_tw.parallel().tween_method(_look.bind(_s(Vector3(11.5, 1.0, 0.0))), _s(Vector3(9.0, 2.0, 17.0)), _s(Vector3(10.5, 1.5, 11.0)), secs)
	_say_in("failure", secs)
	_tw.tween_callback(func():
		_flash_white(0.45)
		_shake = 0.0
		_tunnel_mat.set_shader_parameter("strength", 0.0)
		if _planet != null:
			_planet.visible = true)

## ASLEEP: in the module, him in the pod under the alarm's red light, the view drawing in to his face.
func _shot_asleep() -> void:
	var secs: float = _secs("asleep", 6.0)
	_tw.tween_callback(func():
		_put_him_in_the_pod()
		_alarm_on(true)
		_sound("film_alarm"))
	var pod: Vector3 = _pod_at()
	var face: Vector3 = pod + Vector3(0.0, _num("face_height", 1.32), 0.0)
	var out: Vector3 = _pod_facing()
	_tw.tween_method(_look.bind(face), face + out * 2.1 + Vector3(0.35, 0.2, 0.0), face + out * 0.78 + Vector3(0.06, 0.02, 0.0), secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.parallel().tween_method(_fov, 50.0, 34.0, secs)
	# Asleep the whole shot: his head held bowed, whatever his skeleton was last left at.
	_tw.parallel().tween_method(_wake, 0.0, 0.0, secs)
	_say_in("asleep", secs)

## THE BREAK-UP: out over the world below; the clamps blown, the module drifting free and falling away, the ring
## bursting behind it and the ship coming apart -- its dish, a battery bay, its control unit tumbling away.
func _shot_breakup() -> void:
	var secs: float = _secs("breakup", 5.0)
	_tw.tween_callback(func():
		_alarm_on(false)
		_hide_him()
		_sound("film_separation")
		_burst(_set.to_global(Vector3(3.45, 1.0, 0.0)), Color(1.0, 0.75, 0.4), 6.0, 0.5)
		var clamps: Node3D = _part("Clamps")
		if clamps != null:
			clamps.visible = false)
	_move(Vector3(-14.0, 9.0, 26.0), Vector3(2.0, 0.0, 0.0), Vector3(-20.0, 4.0, 30.0), Vector3(-6.0, -2.0, 0.0), secs, 55.0, 50.0)
	var home: Vector3 = _set.global_position
	_tw.parallel().tween_method(_drift_the_module.bind(home), 0.0, 1.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_callback(_break_up).set_delay(secs * 0.18)
	_tw.tween_callback(func(): _flash_white(0.5))

## Out of the shots above the world: the set struck, the module back over its spot, and the fall (StationJump.crash),
## which hands the valley back to the film when its blow has shaken it (after_the_blow).
func _to_the_fall() -> void:
	if _fell:
		return
	_fell = true
	_strike_the_set()
	_hide_him()
	var cam: Camera3D = _main.camera if ("camera" in _main) else null
	if cam != null and is_instance_valid(cam):
		cam.current = true
	var jump: Node = _station()
	if jump != null and jump.has_method("crash"):
		jump.crash(_main, self)
	else:
		_finish()

# ==============================================================================
# The shots in the valley
# ==============================================================================

## THE VALLEY: the nest's pack startled at the smoke, then off towards it; the grazers on the walls bolting; the
## armoured ones snorting, then off towards it too.
func _shot_valley() -> void:
	var smoke: Vector3 = _core.global_position + Vector3.UP * 4.0
	var nest: Node3D = get_tree().get_first_node_in_group("nest") as Node3D if is_inside_tree() else null
	var part: float = _secs("valley_shot", 2.3)
	_tw.tween_callback(_use_camera)
	if nest != null:
		var guards: Array = _nearest_of(get_tree().get_nodes_in_group("guard_dinos"), nest.global_position, 3)
		var back: Vector3 = _flat_dir(nest.global_position - _core.global_position)
		var eye: Vector3 = nest.global_position + back * float(_opening("nest_view", 6.5)) + Vector3.UP * 1.7
		_tw.tween_callback(_startle.bind(guards, smoke, "alert"))
		_tw.tween_method(_look.bind(nest.global_position + Vector3.UP * 1.0), eye, eye + back * -1.5, part)
		_tw.parallel().tween_callback(_set_off.bind(guards, smoke, 4.5, 1.4)).set_delay(part * 0.45)
	var herd: Array = _a_herd()
	if not herd.is_empty():
		var mid: Vector3 = Vector3.ZERO
		for a in herd:
			mid += (a as Node3D).global_position
		mid /= float(herd.size())
		var toward: Vector3 = _flat_dir(_core.global_position - mid)
		var eye2: Vector3 = mid + toward * 11.0 + Vector3.UP * 3.0
		_tw.tween_callback(_bolt.bind(herd, mid - toward * 6.0))
		_tw.tween_method(_look.bind(mid + Vector3.UP * 1.0), eye2, eye2 + Vector3.UP * 0.8, part)
	var chargers: Array = _chargers(smoke)
	if not chargers.is_empty():
		var at: Vector3 = (chargers[0] as Node3D).global_position
		var on: Vector3 = _flat_dir(smoke - at)
		var side := Vector3(-on.z, 0.0, on.x)
		var eye3: Vector3 = at - on * 5.0 + side * 3.0 + Vector3.UP * 1.4
		_tw.tween_callback(_startle.bind(chargers, smoke, "snort"))
		_tw.tween_method(_look.bind(at + on * 6.0 + Vector3.UP * 1.5), eye3, eye3 + on * 1.5, part)
		_tw.parallel().tween_callback(_set_off.bind(chargers, smoke, 5.0, 1.6)).set_delay(part * 0.35)

## AWAKE: his eyes opening on the module's room; his face, lifting; out of the pod to the hatch, the hatch open, out
## into the light -- the smoke over the valley -- and the view drawing back to the run's own, the game's name over it.
func _shot_awake() -> void:
	var pod: Vector3 = _pod_at()
	var out: Vector3 = _pod_facing()
	var face: Vector3 = pod + Vector3(0.0, _num("face_height", 1.32), 0.0)
	var secs: float = _secs("awake_eyes", 3.2)
	_tw.tween_callback(func():
		_put_him_in_the_pod()
		_alarm_on(true, 0.35)
		_lids_at(1.0))
	# Through his eyes: the room from inside the pod, swimming into sight as they open, close, and open.
	_tw.tween_method(_look.bind(face + out * 3.0 + Vector3(0.0, -0.25, 0.0)), face + out * 0.12, face + out * 0.18, secs)
	_say_in("awake", secs + _secs("awake_face", 2.6))
	_tw.parallel().tween_method(_fov, 70.0, 64.0, secs)
	_tw.parallel().tween_method(_lids_at, 1.0, 0.55, secs * 0.35).set_delay(secs * 0.15)
	_tw.parallel().tween_method(_lids_at, 0.55, 1.0, secs * 0.12).set_delay(secs * 0.52)
	_tw.parallel().tween_method(_lids_at, 1.0, 0.0, secs * 0.3).set_delay(secs * 0.66)
	# His face: lifting.
	var face_secs: float = _secs("awake_face", 2.6)
	_tw.tween_callback(func(): _lids_at(0.0))
	_tw.tween_method(_look.bind(face), face + out * 0.7 + Vector3(-0.2, 0.0, 0.0), face + out * 0.62 + Vector3(0.12, 0.03, 0.0), face_secs)
	_tw.parallel().tween_method(_fov, 30.0, 28.0, face_secs)
	_tw.parallel().tween_method(_wake, 0.0, 1.0, face_secs * 0.6).set_delay(face_secs * 0.25).set_trans(Tween.TRANS_SINE)
	# Out of the pod, to the hatch.
	var walk: float = _secs("awake_walk", 2.4)
	var inside: Vector3 = _core.door_inside() if _core.has_method("door_inside") else _core.global_position
	var outside: Vector3 = _core.door_outside() if _core.has_method("door_outside") else _core.global_position
	_tw.tween_callback(func():
		_alarm_on(false)
		_unfloat()
		_walk_to(inside, walk)
		_sound("film_pod_open"))
	# Seen from by the hatch, coming to it across the room.
	var into: Vector3 = _flat_dir(pod - inside)
	var side := Vector3(-into.z, 0.0, into.x)
	var room_eye: Vector3 = inside + into * 0.35 + side * 0.9 + Vector3.UP * 1.35
	_tw.tween_method(_look_at_him.bind(Vector3.UP * 0.95), room_eye + side * 0.2, room_eye, walk)
	_tw.parallel().tween_method(_fov, 55.0, 50.0, walk)
	_tw.parallel().tween_callback(_open_the_hatch).set_delay(walk * 0.6)
	# Out into the light: from outside, low by the door; then the view drawing back and up to the run's own.
	var step: float = _secs("awake_out", 1.6)
	var door_out: Vector3 = _flat_dir(outside - inside)
	var eye_out: Vector3 = outside + door_out * 3.2 + Vector3(1.6, 0.9, 0.0)
	_tw.tween_callback(func(): _walk_to(outside, step))
	_tw.tween_method(_look_at_him.bind(Vector3.UP * 0.9), eye_out, eye_out + Vector3(0.2, 0.15, 0.0), step)
	_tw.parallel().tween_method(_fov, 45.0, 45.0, step)
	var crane: float = _secs("awake_crane", 4.0)
	var home: Transform3D = _home_camera()
	var start_at: Vector3 = eye_out + Vector3(0.2, 0.15, 0.0)
	_tw.tween_callback(func(): _look_around())
	_tw.tween_method(_crane.bind(start_at, outside + Vector3.UP * 0.9, home), 0.0, 1.0, crane) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.parallel().tween_method(_fov, 45.0, _home_fov(), crane)
	_tw.parallel().tween_method(_title_at, 0.0, 1.0, crane * 0.35).set_delay(crane * 0.2)
	_tw.parallel().tween_method(_title_at, 1.0, 0.0, crane * 0.25).set_delay(crane * 0.75)
	_tw.parallel().tween_method(_bars_at, 1.0, 0.0, crane * 0.3).set_delay(crane * 0.7)

# ==============================================================================
# The set above the world
# ==============================================================================

## The shots above the world, set far over the valley (OPENING.set_at), out of its sight: the ship with the module at its
## nose (the cabin itself, moved there), the tunnel round its way, the world below, space's own sky and light.
func _build_the_set() -> void:
	_set = Node3D.new()
	_set.name = "OpeningSet"
	_main.add_child(_set)
	_set.global_position = _opening("set_at", Vector3(0.0, 4000.0, 0.0))
	_core.global_transform = Transform3D(_cabin_home.basis, _set.global_position)
	_ship = VisualLibrary.make("film/ship")
	if _ship != null:
		_ship.name = "Ship"
		_set.add_child(_ship)
		_light_the_glows(_ship)
	# The time tunnel: a tube round the ship's way, the streaks rushing back along it.
	var tube := MeshInstance3D.new()
	tube.name = "Tunnel"
	var cyl := CylinderMesh.new()
	cyl.top_radius = float(_opening("tunnel_radius", 34.0))
	cyl.bottom_radius = cyl.top_radius
	cyl.height = float(_opening("tunnel_length", 520.0))
	cyl.radial_segments = 48
	cyl.rings = 8
	cyl.cap_top = false
	cyl.cap_bottom = false
	tube.mesh = cyl
	_tunnel_mat = ShaderMaterial.new()
	_tunnel_mat.shader = load("res://assets/shaders/film_tunnel.gdshader") as Shader
	_tunnel_mat.set_shader_parameter("strength", 0.0)
	tube.material_override = _tunnel_mat
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tube.rotation = Vector3(0.0, 0.0, PI * 0.5)
	tube.position = Vector3(8.0, 1.0, 0.0)
	_set.add_child(tube)
	# The world below, seen once out of the tunnel.
	_planet = MeshInstance3D.new()
	_planet.name = "World"
	var ball := SphereMesh.new()
	var r: float = float(_opening("world_radius", 900.0))
	ball.radius = r
	ball.height = r * 2.0
	ball.radial_segments = 96
	ball.rings = 48
	_planet.mesh = ball
	var world_mat := ShaderMaterial.new()
	world_mat.shader = load("res://assets/shaders/film_planet.gdshader") as Shader
	_planet.material_override = world_mat
	_planet.position = _opening("world_at", Vector3(-300.0, -1250.0, -600.0))
	_planet.visible = false
	_set.add_child(_planet)
	_cam = Camera3D.new()
	_cam.name = "FilmCamera"
	_cam.far = float(_opening("camera_far", 3000.0))
	_set.add_child(_cam)
	_into_space(true)

## Space's sky and its sun in place of the valley's, the mist off -- or the valley's back.
func _into_space(on: bool) -> void:
	var we: WorldEnvironment = _main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = _main.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var fog: Node = _main.get("fog") as Node
	if on:
		if we != null:
			_env_was = we.environment
			we.environment = _space_environment()
		if sun != null:
			_sun_was = {"basis": sun.global_transform.basis, "energy": sun.light_energy, "color": sun.light_color}
			sun.global_rotation = Vector3(deg_to_rad(-18.0), deg_to_rad(-60.0), 0.0)
			sun.light_energy = float(_opening("space_sun", 2.2))
			sun.light_color = Color(1.0, 0.97, 0.92)
		if fog != null and "visible" in fog:
			_fog_was = bool(fog.visible)
			fog.visible = false
		return
	if we != null and _env_was != null:
		we.environment = _env_was
	_env_was = null
	if sun != null and not _sun_was.is_empty():
		sun.global_transform = Transform3D(_sun_was["basis"], sun.global_position)
		sun.light_energy = float(_sun_was["energy"])
		sun.light_color = _sun_was["color"]
	_sun_was = {}
	if fog != null and "visible" in fog:
		fog.visible = _fog_was

func _space_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/film_stars.gdshader") as Shader
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.26)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = false
	return env

## The set struck: space's sky and light gone, the module back over its spot, the set gone.
func _strike_the_set() -> void:
	if _env_was != null or not _sun_was.is_empty():
		_into_space(false)
	if _core != null and is_instance_valid(_core):
		_core.global_transform = _cabin_home
	_alarm_on(false)
	if _set != null and is_instance_valid(_set):
		if _cam != null and is_instance_valid(_cam) and _cam.get_parent() == _set:
			_cam.reparent(_main)
		_set.queue_free()
	_set = null
	_ship = null
	_planet = null

## The ship's parts lit by themselves ("_glow"): the film's glow (assets/shaders/film_glow.gdshader), each its own.
func _light_the_glows(ship: Node) -> void:
	_glows.clear()
	var shader: Shader = load("res://assets/shaders/film_glow.gdshader") as Shader
	for m in ship.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not String(mi.name).to_lower().ends_with("_glow") and not String(mi.get_parent().name).to_lower().ends_with("_glow"):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("energy", float(_opening("glow_energy", 3.0)))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glows.append(mat)

## `v` in the set's frame, in the world's.
func _s(v: Vector3) -> Vector3:
	return _set.to_global(v) if (_set != null and is_instance_valid(_set)) else v

func _part(part_name: String) -> Node3D:
	if _ship == null or not is_instance_valid(_ship):
		return null
	return _ship.find_child(part_name, true, false) as Node3D

## The drive failing, `k` of the way: the ring and the tunnel going red and guttering.
func _fault(k: float) -> void:
	var flicker: float = 1.0 - k * 0.7 * float(_dice.randf() < 0.35)
	for m in _glows:
		m.set_shader_parameter("fault", k)
		m.set_shader_parameter("energy", float(_opening("glow_energy", 3.0)) * flicker)
	if _tunnel_mat != null:
		_tunnel_mat.set_shader_parameter("fault", k)

## Sparks thrown off the ring at a few points round it.
func _sparks_round_the_ring() -> void:
	if _set == null:
		return
	var r: float = 5.2
	for k in 5:
		var a: float = TAU * float(k) / 5.0 + 0.4
		var at: Vector3 = _set.to_global(Vector3(11.5, 1.0 + sin(a) * r, cos(a) * r))
		var p := _sparks(at, 40)
		p.emitting = true
		_hold(p)

## The ship coming apart: the ring bursting, its glow out; the dish, a battery bay, the control unit flung off
## tumbling; what is left drifting.
func _break_up() -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	_sound("film_breakup")
	_burst(_set.to_global(Vector3(11.5, 1.0, 0.0)), Color(0.9, 0.95, 1.0), 14.0, 0.9)
	for m in _glows:
		var fade := _tween()
		fade.tween_method(func(e: float): m.set_shader_parameter("energy", e), 3.0, 0.0, 0.6)
	var flung: Dictionary = {"Dish": Vector3(-0.4, 1.0, 0.5), "Bay": Vector3(0.3, 0.2, 1.0), "Board": Vector3(-0.6, 0.9, -0.4),
		"Ring": Vector3(0.2, -0.3, -0.2), "Radiators": Vector3(0.6, -0.2, 0.7)}
	for part_name in flung:
		var part: Node3D = _part(String(part_name))
		if part == null:
			continue
		var dir: Vector3 = (flung[part_name] as Vector3).normalized()
		var speed: float = 6.0 if String(part_name) != "Ring" else 1.5
		var spin := Vector3(_dice.randf_range(-2.0, 2.0), _dice.randf_range(-2.0, 2.0), _dice.randf_range(-2.0, 2.0))
		var from: Vector3 = part.position
		var tw := _tween()
		tw.set_parallel(true)
		tw.tween_property(part, "position", from + dir * speed * 4.0, 4.0)
		tw.tween_property(part, "rotation", part.rotation + spin, 4.0)
		if String(part_name) != "Ring":
			var flame := Fire.make_flame(_fire(), 0.9)
			flame.process_mode = Node.PROCESS_MODE_ALWAYS
			part.add_child(flame)

## The module drifting free of the collar and falling away towards the world, turning a little: `t` of the way.
func _drift_the_module(t: float, home: Vector3) -> void:
	if _core == null or not is_instance_valid(_core):
		return
	var away: Vector3 = Vector3(-22.0, -9.0, 3.0) * t
	_core.global_transform = Transform3D(_cabin_home.basis * Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(14.0) * t)), home + away)

# ==============================================================================
# Him
# ==============================================================================

## In the pod, afloat, asleep: his head bowed (the pose of his skeleton's head; his clip held still with the game).
func _put_him_in_the_pod() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	_hero.visible = true
	_hero.global_position = _pod_at()
	var facing: Vector3 = _hero.global_position + _pod_facing()
	_hero.look_at(Vector3(facing.x, _hero.global_position.y, facing.z), Vector3.UP)
	# Faced -Z at the point: his model faces -Z too (tools/build_hero.py).
	if not _floated and _hero.has_method("_float"):
		_hero._float(true)
		_floated = true
	_find_his_head()
	_wake(0.0)

func _hide_him() -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.visible = false

func _unfloat() -> void:
	if _floated and _hero != null and is_instance_valid(_hero) and _hero.has_method("_float"):
		_hero._float(false)
	_floated = false

func _find_his_head() -> void:
	if _sk != null and is_instance_valid(_sk):
		return
	var body: Node = _hero.find_child("Body", false, false) if _hero != null else null
	var found: Array = body.find_children("*", "Skeleton3D", true, false) if body != null else []
	if found.is_empty():
		return
	_sk = found[0] as Skeleton3D
	_head = _sk.find_bone(HEAD_BONE)
	if _head >= 0:
		_head_rest = _sk.get_bone_pose_rotation(_head)
	# His skeleton kept drawing its pose through the pause -- held, it drew none of what was set on it -- his clips
	# still held with the game.
	_go_always(_sk)

## His head `k` of the way up from bowed in sleep (0) to as it stands (1).
func _wake(k: float) -> void:
	if _sk == null or not is_instance_valid(_sk) or _head < 0:
		return
	var bow := Quaternion(Vector3.RIGHT, deg_to_rad(float(_opening("head_bow_degrees", 32.0))) * (1.0 - clampf(k, 0.0, 1.0)))
	_sk.set_bone_pose_rotation(_head, _head_rest * bow)

## Walking to `to` over `seconds`: his walk played through the pause, facing where he goes.
func _walk_to(to: Vector3, seconds: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	var ap: AnimationPlayer = _his_player()
	if ap != null:
		_go_always(ap)
		var walk: String = "walk" if ap.has_animation("walk") else ""
		if walk != "":
			ap.play(walk, 0.25)
	var flat := Vector3(to.x, _hero.global_position.y, to.z)
	if _hero.global_position.distance_to(flat) > 0.05:
		_hero.look_at(flat, Vector3.UP)
	var tw := _tween()
	tw.tween_property(_hero, "global_position", Vector3(to.x, _hero.global_position.y, to.z), seconds)
	tw.tween_callback(func():
		if ap != null and is_instance_valid(ap) and ap.has_animation("idle"):
			ap.play("idle", 0.3))

## Out in the light, he looks about him: towards the smoke, then the valley.
func _look_around() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	var tw := _tween()
	tw.tween_property(_hero, "rotation:y", _hero.rotation.y + 0.6, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_hero, "rotation:y", _hero.rotation.y - 0.4, 1.2).set_trans(Tween.TRANS_SINE)

func _his_player() -> AnimationPlayer:
	if _hero == null or not ("animator" in _hero) or _hero.animator == null:
		return null
	return _hero.animator.animation_player

## The hatch slid open (the cabin's own door, played through the pause a moment).
func _open_the_hatch() -> void:
	if _core == null or not is_instance_valid(_core) or not _core.has_method("set_door_open"):
		return
	_go_always(_core)
	_core.set_door_open(true)
	_sound("film_door")

## Where the pod stands (the cabin's HealingPod), and the way it faces -- into the room.
func _pod_at() -> Vector3:
	var pod: Node3D = HealingPod.of(get_tree()) as Node3D if is_inside_tree() else null
	if pod != null and is_instance_valid(pod):
		return pod.global_position
	return _core.global_position if _core != null else Vector3.ZERO

func _pod_facing() -> Vector3:
	var pod: Node3D = HealingPod.of(get_tree()) as Node3D if is_inside_tree() else null
	if pod != null and is_instance_valid(pod) and _core != null:
		var into := pod.global_position - _core.global_position
		into.y = 0.0
		# The pod stands at the back wall: it faces the front, across the room.
		return Vector3(0.0, 0.0, -signf(into.z) if absf(into.z) > 0.01 else 1.0)
	return Vector3(0.0, 0.0, 1.0)

# ==============================================================================
# The valley's animals
# ==============================================================================

## `who`, startled: turned to the smoke, their own cry, a snap of the jaws -- played through the pause.
func _startle(who: Array, smoke: Vector3, cry: String) -> void:
	for d in who:
		if not is_instance_valid(d):
			continue
		_keep(d)
		var n := d as Node3D
		var look := Vector3(smoke.x, n.global_position.y, smoke.z)
		if n.global_position.distance_to(look) > 0.05:
			n.look_at(look, Vector3.UP)
		var ap: AnimationPlayer = d.animator.animation_player if ("animator" in d and d.animator != null) else null
		if ap != null:
			_go_always(ap)
			for clip in ["attack", "idle"]:
				if ap.has_animation(clip):
					ap.play(clip, 0.15)
					break
		if d.has_method("say"):
			d.say(cry)

## `who` off towards the smoke: `metres` of it at a run, over `seconds`.
func _set_off(who: Array, smoke: Vector3, metres: float, seconds: float) -> void:
	for d in who:
		if not is_instance_valid(d):
			continue
		var n := d as Node3D
		var ap: AnimationPlayer = d.animator.animation_player if ("animator" in d and d.animator != null) else null
		if ap != null:
			for clip in ["run", "walk"]:
				if ap.has_animation(clip):
					ap.play(clip, 0.2)
					break
		var to: Vector3 = n.global_position + _flat_dir(smoke - n.global_position) * metres
		var tw := _tween()
		tw.tween_property(n, "global_position", to, seconds)

## A herd on the valley walls, bolting away from the smoke up the slope, at a hurried walk.
func _bolt(herd: Array, to: Vector3) -> void:
	for a in herd:
		if not is_instance_valid(a):
			continue
		_keep(a)
		var n := a as Node3D
		var ap: AnimationPlayer = null
		var found: Array = n.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			ap = found[0] as AnimationPlayer
		if ap != null:
			_go_always(ap)
			if ap.has_animation("walk"):
				ap.play("walk", 0.15)
				ap.speed_scale = float(_opening("bolt_pace", 2.2))
		var mine: Vector3 = to + (n.global_position - to) * 0.3
		mine.y = n.global_position.y
		if n.global_position.distance_to(mine) > 0.05:
			n.look_at(mine, Vector3.UP)
		var tw := _tween()
		tw.tween_property(n, "global_position", mine, _secs("valley_shot", 2.3))
		var sound: String = String(n.get_meta(&"species", "")) + "_call"
		var fx = get_node_or_null("/root/Fx")
		if fx and fx.has_method("play_at"):
			fx.play_at(sound, n.global_position + Vector3.UP)

## The nearest herd's animals of one kind, up to three.
func _a_herd() -> Array:
	var herds: Node = _main.get_node_or_null("Herds")
	if herds == null:
		return []
	var all: Array = []
	for a in herds.get_children():
		if a is Node3D and a.has_meta(&"species"):
			all.append(a)
	if all.is_empty():
		return []
	var first: Array = _nearest_of(all, _core.global_position, 1)
	var kind: String = String((first[0] as Node).get_meta(&"species", ""))
	var same: Array = all.filter(func(a): return String(a.get_meta(&"species", "")) == kind)
	return _nearest_of(same, (first[0] as Node3D).global_position, 3)

## The frightened plant-eaters of this map (its raiders that charge: Desmatosuchus at the first station), put down
## for the film a way off the cabin, on the side from the nest: two of them. Gone after.
func _chargers(smoke: Vector3) -> Array:
	var cfg = get_node_or_null("/root/Config")
	var gs = get_node_or_null("/root/GameState")
	if cfg == null or gs == null or not gs.has_method("map_data"):
		return []
	var species: String = ""
	for step in gs.map_data().get("raiders_by_day", []):
		for id in (step.get("raiders", {}) as Dictionary):
			if species == "" and String(cfg.DINOS.get(String(id), {}).get("behaviour", "")) == "charger":
				species = String(id)
	if species == "":
		return []
	var nest: Node3D = get_tree().get_first_node_in_group("nest") as Node3D
	var away: Vector3 = _flat_dir(_core.global_position - nest.global_position) if nest != null else Vector3(0.0, 0.0, 1.0)
	var side := Vector3(-away.z, 0.0, away.x)
	var out: Array = []
	for k in 2:
		var d = load(String(cfg.get_dino_script_path(species))).new()
		d.setup(species)
		d.position = _core.global_position + away * float(_opening("chargers_off", 20.0)) + side * (float(k) * 3.0 - 1.5)
		_main.add_child(d)
		d.setup(species)
		d.set_physics_process(false)
		d.set_process(false)
		_actors.append(d)
		out.append(d)
	return out

## Kept as it is, to be put back after: where it stands, which way it faces.
func _keep(n: Node) -> void:
	for pair in _moved:
		if pair[0] == n:
			return
	_moved.append([n, (n as Node3D).global_transform])

## Played through the pause for the film, its own way back after.
func _go_always(n: Node) -> void:
	for pair in _always:
		if pair[0] == n:
			return
	_always.append([n, n.process_mode])
	n.process_mode = Node.PROCESS_MODE_ALWAYS

func _put_back() -> void:
	for pair in _moved:
		if is_instance_valid(pair[0]):
			(pair[0] as Node3D).global_transform = pair[1]
	_moved.clear()
	for pair in _always:
		if is_instance_valid(pair[0]):
			(pair[0] as Node).process_mode = pair[1]
			if pair[0] is AnimationPlayer:
				(pair[0] as AnimationPlayer).speed_scale = 1.0
	_always.clear()

func _nearest_of(nodes: Array, to: Vector3, count: int) -> Array:
	var live: Array = nodes.filter(func(n): return n is Node3D and is_instance_valid(n))
	live.sort_custom(func(a, b): return (a as Node3D).global_position.distance_squared_to(to) < (b as Node3D).global_position.distance_squared_to(to))
	return live.slice(0, count)

# ==============================================================================
# The camera
# ==============================================================================

func _use_camera() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	if not _cam.is_inside_tree():
		return
	_cam.current = true

## A move: from `from` looking at `at_from` to `to` looking at `at_to`, `fov_from` to `fov_to` degrees, over `seconds` --
## all in the set's own frame.
func _move(from: Vector3, at_from: Vector3, to: Vector3, at_to: Vector3, seconds: float, fov_from: float, fov_to: float) -> void:
	_tw.tween_method(func(t: float):
		if _set == null or _cam == null:
			return
		var eye: Vector3 = _set.to_global(from.lerp(to, t))
		var at: Vector3 = _set.to_global(at_from.lerp(at_to, t))
		_point(eye, at), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.parallel().tween_method(_fov, fov_from, fov_to, seconds)

## The view at `eye` -- in the set's frame while the set stands, the world's otherwise -- looking at `at`.
func _look(eye: Vector3, at: Vector3) -> void:
	_point(eye, at)

func _look_at_him(eye: Vector3, lift: Vector3) -> void:
	var at: Vector3 = (_hero.global_position if _hero != null and is_instance_valid(_hero) else eye + Vector3.FORWARD) + lift
	_point(eye, at)

func _point(eye: Vector3, at: Vector3) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var j := Vector3.ZERO
	if _shake > 0.0:
		j = Vector3(_dice.randf_range(-1.0, 1.0), _dice.randf_range(-1.0, 1.0), _dice.randf_range(-1.0, 1.0)) * _shake
	_cam.global_position = eye + j * 0.5
	if eye.distance_to(at) > 0.01:
		_cam.look_at(at + j, Vector3.UP)

func _fov(deg: float) -> void:
	if _cam != null and is_instance_valid(_cam):
		_cam.fov = deg

func _shaken(k: float) -> void:
	_shake = float(_opening("shake", 0.35)) * k

## From `start` (looking at `at`) to the run's own view, `t` of the way.
func _crane(t: float, start: Vector3, at: Vector3, home: Transform3D) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var from := Transform3D(Basis.looking_at(at - start, Vector3.UP), start)
	_cam.global_transform = from.interpolate_with(home, t)

## Where the run's own view stands (the camera rig's home), as a camera's transform.
func _home_camera() -> Transform3D:
	var rig: Object = _main.camera_rig if ("camera_rig" in _main) else null
	if rig == null or not rig.has_method("home"):
		return _cam.global_transform if _cam != null else Transform3D.IDENTITY
	var home: Dictionary = rig.home()
	var was := {"focus": rig.focus, "yaw": rig.yaw, "tilt": rig.tilt, "distance": rig.distance}
	for k in home:
		rig.set(k, home[k])
	var probe := Camera3D.new()
	_main.add_child(probe)
	rig.apply_to(probe)
	var out: Transform3D = probe.global_transform
	probe.queue_free()
	for k in was:
		rig.set(k, was[k])
	return out

func _home_fov() -> float:
	var cam: Camera3D = _main.camera if ("camera" in _main) else null
	return cam.fov if cam != null else 50.0

## The run's own view back: the rig at its home, its camera the one drawn.
func _home_view() -> void:
	var rig: Object = _main.camera_rig if ("camera_rig" in _main) else null
	var cam: Camera3D = _main.camera if ("camera" in _main) else null
	if rig != null and rig.has_method("home"):
		var home: Dictionary = rig.home()
		for k in home:
			rig.set(k, home[k])
		if cam != null:
			rig.apply_to(cam)
	if cam != null and is_instance_valid(cam):
		cam.current = true

# ==============================================================================
# The screen over it: the bars, the words, his eyelids, the flash
# ==============================================================================

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "OpeningOverlay"
	_overlay.layer = 90
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	_overlay.add_child(root)
	_lids.clear()
	_bars.clear()
	for k in 2:
		var lid := ColorRect.new()
		lid.name = "Lid%d" % k
		lid.color = Color.BLACK
		lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lid)
		_lids.append(lid)
	for k in 2:
		var bar := ColorRect.new()
		bar.name = "Bar%d" % k
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)
		_bars.append(bar)
	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.theme_type_variation = &"SubtitleLabel"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root.add_child(_subtitle)
	_title = Label.new()
	_title.name = "FilmTitle"
	_title.theme_type_variation = &"DisplayLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.text = tr(String(_opening("title", "START_TITLE")))
	_title.modulate = Color(1.0, 1.0, 1.0, 0.0)
	root.add_child(_title)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.resized.connect(_lay_out_overlay)
	_lay_out_overlay()
	_bars_at(0.0)
	_lids_at(0.0)

func _lay_out_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var root: Control = _overlay.get_node("Root") as Control
	var size: Vector2 = root.size if root.size.x > 0.0 else get_viewport().get_visible_rect().size
	var bar_h: float = size.y * float(_opening("letterbox", 0.11))
	_subtitle.position = Vector2(size.x * 0.12, size.y - bar_h - size.y * 0.11)
	_subtitle.size = Vector2(size.x * 0.76, size.y * 0.1)
	for k in 2:
		_lids[k].size = Vector2(size.x, size.y * 0.5 + 2.0)

## The letterbox in, `k` of the way (0 none, 1 the bars in).
func _bars_at(k: float) -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var root: Control = _overlay.get_node("Root") as Control
	var size: Vector2 = root.size if root.size.x > 0.0 else get_viewport().get_visible_rect().size
	var h: float = size.y * float(_opening("letterbox", 0.11)) * clampf(k, 0.0, 1.0)
	_bars[0].position = Vector2(0.0, 0.0)
	_bars[0].size = Vector2(size.x, h)
	_bars[1].position = Vector2(0.0, size.y - h)
	_bars[1].size = Vector2(size.x, h)

## His eyelids, `k` closed (1 shut, 0 open): the screen's top and bottom halves closing in on its middle.
func _lids_at(k: float) -> void:
	if _overlay == null or not is_instance_valid(_overlay) or _lids.is_empty():
		return
	var root: Control = _overlay.get_node("Root") as Control
	var size: Vector2 = root.size if root.size.x > 0.0 else get_viewport().get_visible_rect().size
	var half: float = size.y * 0.5 + 2.0
	var shut: float = clampf(k, 0.0, 1.0)
	_lids[0].position = Vector2(0.0, -half + half * shut)
	_lids[1].position = Vector2(0.0, size.y - half * shut)

func _title_at(a: float) -> void:
	if _title != null and is_instance_valid(_title):
		_title.modulate.a = clampf(a, 0.0, 1.0)

func _flash_white(seconds: float) -> void:
	if _flash == null or not is_instance_valid(_flash):
		return
	_flash.color = Color(1.0, 1.0, 1.0, 1.0)
	var tw := _tween()
	tw.tween_property(_flash, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)

## A line of the ship's voice in the shot `shot` (OPENING.lines): heard, and its words under it, `at` seconds in, for as
## long as it is said or `hold`.
func _say_in(shot: String, shot_secs: float) -> void:
	var line: Dictionary = _opening("lines", {}).get(shot, {})
	if line.is_empty():
		return
	var at: float = float(line.get("at", 0.5))
	var hold: float = minf(float(line.get("hold", 3.5)), maxf(0.5, shot_secs - at))
	_tw.parallel().tween_callback(func():
		_sound(String(line.get("sound", "")))
		_subtitle.text = tr(String(line.get("text", "")))
		var tw := _tween()
		tw.tween_property(_subtitle, "modulate:a", 1.0, 0.25)
		tw.tween_interval(hold)
		tw.tween_property(_subtitle, "modulate:a", 0.0, 0.35)).set_delay(at)

# ==============================================================================
# Light, fire and sound
# ==============================================================================

## The valley's mist lifted while its animals are shown -- the nest's among them -- and laid again after as the run
## would have it (FogOfWar: what the cabin and he have seen).
var _mist_was: bool = false

func _lift_the_mist(lift: bool) -> void:
	var fog: Node = _main.get("fog") as Node if _main != null else null
	if fog == null or not is_instance_valid(fog) or not ("revealed" in fog):
		return
	if lift:
		_mist_was = bool(fog.revealed)
		fog.revealed = true
	else:
		fog.revealed = _mist_was
		if fog.has_method("_look"):
			fog._look()
	if fog.has_method("_paint"):
		fog._paint(1.0)
	if fog.has_method("_hide_the_unseen"):
		fog._hide_the_unseen()

## The alarm's red light in the module, pulsing -- on (`energy` its brightest) or off.
func _alarm_on(on: bool, energy: float = -1.0) -> void:
	if energy < 0.0:
		energy = float(_opening("alarm_energy", 6.0))
	if not on:
		if _alarm != null and is_instance_valid(_alarm):
			_alarm.queue_free()
		_alarm = null
		return
	if _alarm == null or not is_instance_valid(_alarm):
		_alarm = OmniLight3D.new()
		_alarm.name = "Alarm"
		_alarm.light_color = Color(1.0, 0.1, 0.05)
		_alarm.omni_range = float(_opening("alarm_range", 7.5))
		_alarm.shadow_enabled = false
		_alarm.process_mode = Node.PROCESS_MODE_ALWAYS
		_core.add_child(_alarm)
		_alarm.position = Vector3(0.0, 2.1, 0.0)
	var tw := _tween(_alarm)
	tw.set_loops()
	tw.tween_property(_alarm, "light_energy", energy, 0.35)
	tw.tween_property(_alarm, "light_energy", energy * 0.1, 0.45)

## A blast of light at `at`: `range` metres of `colour`, out over `seconds`.
func _burst(at: Vector3, colour: Color, range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.omni_range = range
	light.light_energy = 8.0
	light.shadow_enabled = false
	light.process_mode = Node.PROCESS_MODE_ALWAYS
	_main.add_child(light)
	light.global_position = at
	var tw := _tween(light)
	tw.tween_property(light, "light_energy", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)
	var p := _sparks(at, 60)
	p.emitting = true
	_hold(p)

## Sparks: `amount` hot points thrown out from `at`, falling back.
func _sparks(at: Vector3, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 11.0
	m.gravity = Vector3(0.0, -6.0, 0.0)
	m.scale_min = 0.6
	m.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.8, 1.0), Color(1.0, 0.55, 0.15, 1.0), Color(0.8, 0.2, 0.05, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Fire._soft_disc()
	quad.material = mat
	p.draw_pass_1 = quad
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	_main.add_child(p)
	p.global_position = at
	return p

## `node` gone a while after: what it made in the world goes with the film or by its own clock.
func _hold(node: Node) -> void:
	var tw := _tween(node)
	tw.tween_interval(3.0)
	tw.tween_callback(node.queue_free)

func _sound(id: String) -> void:
	if id == "":
		return
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("play_ui"):
		fx.play_ui(id)

## While it holds the game, its sound -- and the valley's -- goes on under it (Fx.play_through_pause).
func _sound_through(on: bool) -> void:
	var fx = get_node_or_null("/root/Fx")
	if fx and fx.has_method("play_through_pause"):
		fx.play_through_pause(self, on)

func _hide_the_hud(hidden: bool) -> void:
	var hud = _main.hud if (_main != null and "hud" in _main) else null
	if hud != null and is_instance_valid(hud) and "visible" in hud:
		hud.visible = not hidden

func _station() -> Node:
	return _main.station_jump if (_main != null and "station_jump" in _main and is_instance_valid(_main.station_jump)) else null

func _station_skipped() -> bool:
	var jump: Node = _station()
	return jump != null and "was_skipped" in jump and bool(jump.was_skipped)

func _fire() -> Dictionary:
	var cfg = get_node_or_null("/root/Config")
	return cfg.FIRE if (cfg and "FIRE" in cfg) else {}

# ==============================================================================
# Its numbers (Config.OPENING)
# ==============================================================================

func _opening(key: String, fallback: Variant) -> Variant:
	var cfg = get_node_or_null("/root/Config")
	return cfg.OPENING.get(key, fallback) if (cfg and "OPENING" in cfg) else fallback

func _secs(key: String, fallback: float) -> float:
	return float((_opening("seconds", {}) as Dictionary).get(key, fallback))

func _num(key: String, fallback: float) -> float:
	return float(_opening(key, fallback))

## A tween of the film's: through the pause, at the film's own pace whatever the game's speed was left at.
func _tween(on: Node = null) -> Tween:
	var tw: Tween = (on if on != null else self).create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.set_speed_scale(pace)
	return tw

static func _flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length() > 0.001 else Vector3(0.0, 0.0, 1.0)
