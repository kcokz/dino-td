# res://scripts/autoload/Fx.gd
extends Node

## Presentation feedback for Defend Dinosaur v0.3.
##
## Everything here is about making an event legible: a hit flashes, a death throws
## debris, an impact makes a noise. None of it changes what happens in the game, so
## any of it failing must never break the simulation -- every entry point is safe to
## call from a headless run, where there is no renderer and no audio device.
##
## Sounds are files, made by tools/build_sounds.gd and listed in Config.SOUNDS (v0.6 round
## three: "你就做音效吧"). They started as six blips synthesised here at startup; an animal's
## voice is too much work to make on every launch, so it is made once, offline, and imported
## like any other asset. They are loaded on the engine's own threads as the game starts
## (ResourceLoader.load_threaded_request) and a sound asked for before its files are in is
## simply not heard -- never waited for.
##
## Almost everything is played in the world (play_at): positional, falling off with distance,
## heard from the side it is on. A limiter per class (Config.SOUNDS.classes) keeps a pack from
## becoming a wall of noise. `played` says what was decided on, heard or not -- what the tests
## listen for, since a headless run has no audio device to hear with.

signal played(id: String, at: Vector3)

enum Sound { HIT, DEATH, BUILD_DONE, RAID_WARNING, PICKUP, TWANG }

## The old names, for a caller with no place in the world to play one: which sound of
## Config.SOUNDS each is.
const SOUND_IDS: Dictionary = {
	Sound.HIT: "wood_hit", Sound.DEATH: "wood_break", Sound.BUILD_DONE: "build_done",
	Sound.RAID_WARNING: "raid_warning", Sound.PICKUP: "pickup", Sound.TWANG: "trap_twang",
}

## Players heard everywhere at once: the interface, and what has no place.
const VOICE_COUNT: int = 8

var _streams: Dictionary = {}          # sound id -> AudioStreamRandomizer over its files, once they are in
var _files: Dictionary = {}            # sound id -> its file paths
var _loaded: Dictionary = {}           # file path -> AudioStream
var _pending: Array[String] = []       # asked for on the loader threads, not yet taken
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _world: Node3D = null
var _players: Array[AudioStreamPlayer3D] = []
var _next_player: int = 0
var _class_of: Dictionary = {}         # player -> the class of what it is playing
var _last_in_class: Dictionary = {}    # class -> Time.get_ticks_msec() it last played
var _listener: AudioListener3D = null
var _ambience: AudioStreamPlayer = null
## The valley after dark, faded in and out against the day's (Config.SOUNDS.ambience_night).
var _ambience_night: AudioStreamPlayer = null
var _want_ambience: bool = false
var _debris_root: Node3D = null

## Dice of its own: where debris flies and how a thud crackles are decoration, and
## drawing them from the run's dice (GameState.rng) would make a replayed seed diverge
## the moment the screen shook differently.
var _dice: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# The interface's sounds and the valley's ambience go on while the game is paused; the world's
	# own sounds hold where they are, mid-note, and go on with it (_build_world_players).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request_sounds()
	_build_voices()
	_build_world_players()

## Quitting: whatever is still on the loader threads is waited for and let go, and nothing is
## held -- a file half-loaded when the game closes is otherwise still in use at exit.
func _exit_tree() -> void:
	for path in _pending:
		ResourceLoader.load_threaded_get(path)
	_pending.clear()
	var was_playing: bool = false
	for p in _players:
		if is_instance_valid(p):
			was_playing = was_playing or p.playing
			p.stop()
			p.stream = null
	for v in _voices:
		if is_instance_valid(v):
			was_playing = was_playing or v.playing
			v.stop()
			v.stream = null
	for amb in [_ambience, _ambience_night]:
		if amb != null:
			was_playing = was_playing or amb.playing
			amb.stop()
			amb.stream = null
	_streams.clear()
	_loaded.clear()
	# A stop is only asked of the audio thread: it lets the playback go on its next mix, and at quit
	# there may be no next mix -- the valley's loop was held to the end (debug-agent BUG-003: "1
	# resources still in use at exit"). The level stops it as it goes, a moment before this, so it is
	# the time since any sound of ours was started or stopped that is waited out.
	if was_playing:
		_touched_audio()
	var wait: int = AUDIO_RELEASE_MS - (Time.get_ticks_msec() - _last_audio_ms)
	if wait > 0:
		OS.delay_msec(wait)

## How long the audio thread is given, in milliseconds, to let go of a sound stopped at quit: a few
## of its mixes.
const AUDIO_RELEASE_MS: int = 200
## When a sound of ours was last started or stopped (Time.get_ticks_msec).
var _last_audio_ms: int = -1000000

func _touched_audio() -> void:
	_last_audio_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	_place_listener()
	_take_what_is_in()
	if _want_ambience and _ambience != null and not _ambience.playing:
		_start_ambience_now()
	_fade_ambience()

# ==============================================================================
# Hit flash
# ==============================================================================

## Briefly whitens `mesh` to show it was struck. Safe to call repeatedly; a second
## hit simply restarts the flash rather than stacking.
func flash(mesh: MeshInstance3D, strength: float = -1.0, duration: float = -1.0) -> void:
	if mesh == null or not is_instance_valid(mesh) or not mesh.is_inside_tree():
		return
	if duration < 0.0:
		duration = _cfg("hit_flash_duration", 0.12)
	if strength < 0.0:
		strength = _cfg("hit_flash_strength", 0.85)
	if duration <= 0.0:
		return

	# An IMPORTED MODEL has no material_override: its materials live on the mesh's own
	# surfaces, eight of them on a raptor. This used to give up here and return, so the
	# moment real models arrived every hit flash in the game silently stopped again --
	# the second time that has happened, and the second time nothing failed to say so.
	#
	# Overlay rather than override, because an override would replace all eight surfaces
	# with one material and repaint the whole animal for the duration of the flash.
	var mat := mesh.material_override as StandardMaterial3D
	if mat == null:
		_flash_overlay(mesh, strength, duration)
		return

	# Work on a copy so the flash can never leak into the shared material the
	# building uses for its own colour or highlight state.
	var flashing: StandardMaterial3D = mat.duplicate()

	# EMISSION, not albedo. Since v0.5 the models carry their colours per vertex and
	# leave albedo at white, so lerping albedo towards white did precisely nothing --
	# every hit flash in the game had silently stopped being visible. Emission works
	# whatever the colour is coming from, and a struck thing glowing for a moment is
	# closer to what this was always trying to say.
	flashing.emission_enabled = true
	flashing.emission = Color(1, 1, 1)
	flashing.emission_energy_multiplier = clampf(strength, 0.0, 1.0)
	mesh.material_override = flashing

	# Bound to the MESH, not to this autoload: a tween owned by the autoload outlived the
	# thing it was flashing, and when that died mid-flash -- a stake bitten to pieces --
	# the tween still finished and ran its callback on a freed mesh. A tween bound to the
	# node it animates is killed with it, by the engine.
	var tw := mesh.create_tween()
	tw.tween_property(flashing, "emission_energy_multiplier", 0.0, duration)
	tw.finished.connect(func():
		if is_instance_valid(mesh) and mesh.material_override == flashing:
			mesh.material_override = mat
	)

## The same flash for a mesh that carries its own materials: a white wash drawn OVER
## whatever the model already looks like, fading out and then removed.
##
## material_overlay is an extra pass, so the model keeps every one of its surfaces and
## its colours while it is lit. Restoring means putting the overlay back to null, not
## putting a material back -- there was never one here to begin with.
func _flash_overlay(mesh: MeshInstance3D, strength: float, duration: float) -> void:
	if mesh.material_overlay != null:
		return                      # already flashing; let the one in flight finish
	var wash := StandardMaterial3D.new()
	wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wash.albedo_color = Color(1.0, 1.0, 1.0, clampf(strength, 0.0, 1.0))
	mesh.material_overlay = wash

	var tw := mesh.create_tween()      # dies with the mesh -- see _flash
	tw.tween_property(wash, "albedo_color:a", 0.0, duration)
	tw.finished.connect(func():
		if is_instance_valid(mesh) and mesh.material_overlay == wash:
			mesh.material_overlay = null
	)

# ==============================================================================
# Death debris
# ==============================================================================

## Throws a handful of small cubes out of `position`, which then fall and fade.
## Gives a death a moment of presence instead of the thing simply vanishing.
func debris(world_pos: Vector3, colour: Color = Color(0.8, 0.8, 0.8), count: int = -1) -> void:
	var root := _get_debris_root()
	if root == null:
		return
	if count < 0:
		count = int(_cfg("debris_count", 7))
	var size: float = _cfg("debris_size", 0.16)
	var speed: float = _cfg("debris_speed", 3.4)
	var life: float = _cfg("debris_lifetime", 0.7)

	for i in range(count):
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * size
		piece.mesh = box

		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		piece.material_override = mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		piece.position = world_pos + Vector3(0.0, size, 0.0)
		root.add_child(piece)

		var dir := Vector3(_dice.randf_range(-1.0, 1.0), _dice.randf_range(0.6, 1.4), _dice.randf_range(-1.0, 1.0)).normalized()
		var target: Vector3 = piece.position + dir * speed * life * 0.5
		target.y = maxf(0.05, target.y - speed * life * 0.35) # let gravity win

		# The piece's own tween, which the engine kills if the piece goes first (the level
		# being torn down under it), rather than one that then calls back into nothing.
		var tw := piece.create_tween()
		tw.set_parallel(true)
		tw.tween_property(piece, "position", target, life)
		tw.tween_property(piece, "rotation", piece.rotation + Vector3(_dice.randf(), _dice.randf(), _dice.randf()) * TAU, life)
		tw.tween_property(mat, "albedo_color:a", 0.0, life)
		tw.chain().tween_callback(piece.queue_free)

# ==============================================================================
# Floating text
# ==============================================================================

## Floats a short string up out of `world_pos` and fades it. Used when something is
## collected: the drop itself disappears and only a HUD number moves, which is easy
## to miss -- a figure rising off the spot says "that went in" where the player is
## already looking.
func floating_text(world_pos: Vector3, text: String, colour: Color = Color.WHITE) -> void:
	if text.is_empty():
		return
	var root := _get_debris_root()
	if root == null:
		return
	var rise: float = _cfg("pickup_text_rise", 1.0)
	var life: float = _cfg("pickup_text_duration", 0.7)
	if life <= 0.0:
		return

	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = colour
	lbl.no_depth_test = true
	UiTheme.style_world_label(lbl)
	lbl.position = world_pos + Vector3(0.0, 0.6, 0.0)
	root.add_child(lbl)

	var tw := lbl.create_tween()       # dies with the label -- see debris
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector3(0.0, rise, 0.0), life)
	tw.tween_property(lbl, "modulate:a", 0.0, life)
	tw.chain().tween_callback(lbl.queue_free)

# ==============================================================================
# Sound
# ==============================================================================

## One of the old names (Sound), heard everywhere: for a caller with no place for it.
func play(which: int) -> void:
	if SOUND_IDS.has(which):
		play_ui(String(SOUND_IDS[which]))

## Sound `id` (Config.SOUNDS.sounds), in the world at `where`: heard from its side, fainter with
## distance. False if it was not played -- sound off, no such sound, or its class is full or
## too soon after the last (Config.SOUNDS.classes).
func play_at(id: String, where: Vector3) -> bool:
	var spec: Dictionary = _spec(id)
	if spec.is_empty() or not _admit(spec):
		return false
	played.emit(id, where)
	var stream: AudioStream = _stream_for(id)
	if stream == null or _players.is_empty():
		return true
	var p: AudioStreamPlayer3D = _free_player()
	if p == null:
		return true
	var table: Dictionary = _sounds_table()
	p.stream = stream
	p.global_position = where
	p.unit_size = float(spec.get("unit", table.get("unit", 7.0)))
	p.max_distance = float(spec.get("reach", table.get("reach", 70.0)))
	p.volume_db = _master_db() + float(spec.get("db", 0.0))
	_class_of[p] = String(spec.get("class", ""))
	p.play()
	_touched_audio()
	return true

## Sound `id` heard everywhere, at no place: the interface.
func play_ui(id: String) -> bool:
	var spec: Dictionary = _spec(id)
	if spec.is_empty() or not _admit(spec):
		return false
	played.emit(id, Vector3.INF)
	var stream: AudioStream = _stream_for(id)
	if stream == null or _voices.is_empty():
		return true
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	if not is_instance_valid(voice):
		return true
	voice.stream = stream
	voice.volume_db = _master_db() + float(spec.get("db", 0.0))
	voice.play()
	_touched_audio()
	return true

## The valley under everything (Config.SOUNDS.ambience), looping, from now on -- as soon as its
## file is in, if it is not yet.
func start_ambience() -> void:
	_want_ambience = true
	_start_ambience_now()

func stop_ambience() -> void:
	_want_ambience = false
	for amb in [_ambience, _ambience_night]:
		if amb != null and amb.playing:
			amb.stop()
			_touched_audio()

func _start_ambience_now() -> void:
	if _ambience == null or not bool(_cfg("audio_enabled", true)):
		return
	var id: String = String(_sounds_table().get("ambience", ""))
	var files: Array = _files.get(id, [])
	if files.is_empty():
		return
	var wav := _file_stream(String(files[0])) as AudioStreamWAV
	if wav == null:
		return
	# Looped here rather than in its import: the file is one ten-second take that joins itself
	# (tools/build_sounds.gd _seamless).
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	_ambience.stream = wav
	_ambience.volume_db = _master_db() + float(_sounds_table().get("ambience_db", -21.0))
	_ambience.play()
	var night := _looped(String(_sounds_table().get("ambience_night", "")))
	if night != null and _ambience_night != null:
		_ambience_night.stream = night
		_ambience_night.play()
	_fade_ambience()
	_touched_audio()

## A sound's first file, set to loop over its whole length -- one take that joins itself
## (tools/build_sounds.gd _seamless) -- or null while it is not in.
func _looped(id: String) -> AudioStreamWAV:
	var files: Array = _files.get(id, [])
	if files.is_empty():
		return null
	var wav := _file_stream(String(files[0])) as AudioStreamWAV
	if wav == null:
		return null
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	return wav

## How far into the night the valley sounds, 0 by day and 1 by night: up through the dusk, down with the
## first light (Config.SOUNDS.night_fade, DAY.parts).
func night_mix() -> float:
	var gs = get_node_or_null("/root/GameState")
	var cfg = get_node_or_null("/root/Config")
	if gs == null or cfg == null or not gs.has_method("time_of_day") or not ("DAY" in cfg):
		return 0.0
	var t: float = float(gs.time_of_day())
	var dusk: float = float(cfg.DAY["parts"].get("dusk", 240.0))
	var fade: Array = _sounds_table().get("night_fade", [50.0, 30.0])
	if t >= dusk:
		return smoothstep(dusk, dusk + float(fade[0]), t)
	return 1.0 - smoothstep(0.0, float(fade[1]), t)

## The day's sound and the night's, each at its share of the mix (an equal-power fade).
func _fade_ambience() -> void:
	if _ambience == null or _ambience_night == null or not _ambience.playing:
		return
	var k: float = night_mix()
	var base: float = _master_db()
	_ambience.volume_db = base + float(_sounds_table().get("ambience_db", -21.0)) + linear_to_db(maxf(0.001, cos(k * PI * 0.5)))
	_ambience_night.volume_db = base + float(_sounds_table().get("ambience_night_db", -20.0)) + linear_to_db(maxf(0.001, sin(k * PI * 0.5)))

## A sound that goes on where it is -- a fire's crackle (Fire) -- as a player of its own, looping, set up as
## Config.SOUNDS says; not yet playing, the caller's to keep, start and stop. Null while the sound is not in.
func make_loop(id: String) -> AudioStreamPlayer3D:
	var spec: Dictionary = _spec(id)
	var wav := _looped(id)
	if spec.is_empty() or wav == null:
		return null
	var table: Dictionary = _sounds_table()
	var p := AudioStreamPlayer3D.new()
	p.stream = wav
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = float(spec.get("unit", table.get("unit", 7.0)))
	p.max_distance = float(spec.get("reach", table.get("reach", 70.0)))
	p.volume_db = _master_db() + float(spec.get("db", 0.0))
	p.pitch_scale = float(spec.get("pitch", 1.0))
	return p

func is_ambience_playing() -> bool:
	return _want_ambience

# ------------------------------------------------------------------------------

func _sounds_table() -> Dictionary:
	var cfg = get_node_or_null("/root/Config")
	return cfg.SOUNDS if (cfg and "SOUNDS" in cfg) else {}

func _spec(id: String) -> Dictionary:
	if not bool(_cfg("audio_enabled", true)):
		return {}
	return _sounds_table().get("sounds", {}).get(id, {})

func _master_db() -> float:
	return float(_cfg("audio_volume_db", -8.0))

## Whether its class has room for one more now: fewer than its most playing, and long enough
## since the last. Letting it in marks the time.
func _admit(spec: Dictionary) -> bool:
	var klass: String = String(spec.get("class", ""))
	var rule: Dictionary = _sounds_table().get("classes", {}).get(klass, {})
	if rule.is_empty():
		return true
	var now: int = Time.get_ticks_msec()
	if now - int(_last_in_class.get(klass, -100000)) < int(float(rule.get("gap", 0.0)) * 1000.0):
		return false
	var playing: int = 0
	for p in _class_of:
		if is_instance_valid(p) and _class_of[p] == klass and (p as AudioStreamPlayer3D).playing:
			playing += 1
	if playing >= int(rule.get("max", 99)):
		return false
	_last_in_class[klass] = now
	return true

## Every file of every sound, asked for on the engine's loader threads.
func _request_sounds() -> void:
	var table: Dictionary = _sounds_table()
	var dir: String = String(table.get("dir", "res://assets/audio/"))
	for id in table.get("sounds", {}):
		var paths: Array = []
		for f in table["sounds"][id].get("files", []):
			var path: String = dir + String(f) + ".wav"
			paths.append(path)
			if ResourceLoader.load_threaded_request(path, "AudioStream") == OK:
				_pending.append(path)
		_files[id] = paths

## Every file the loader threads have finished, taken off them: what is asked for and never
## taken stays the loader's, and is still there -- leaked -- when the game quits.
func _take_what_is_in() -> void:
	for i in range(_pending.size() - 1, -1, -1):
		var path: String = _pending[i]
		var status: int = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded[path] = ResourceLoader.load_threaded_get(path) as AudioStream
			_pending.remove_at(i)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_pending.remove_at(i)

## A file's stream, if it is in; null while it is still loading or if it could not be.
func _file_stream(path: String) -> AudioStream:
	if _loaded.has(path):
		return _loaded[path]
	var status: int = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_loaded[path] = ResourceLoader.load_threaded_get(path) as AudioStream
		_pending.erase(path)
		return _loaded[path]
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		# Not asked for (a file added to Config after the start) or already taken: load it now.
		if ResourceLoader.exists(path):
			_loaded[path] = load(path) as AudioStream
			return _loaded[path]
	return null

## Its files, as one stream that picks among them and wanders the pitch (the engine's
## AudioStreamRandomizer): null until every file is in.
func _stream_for(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var paths: Array = _files.get(id, [])
	if paths.is_empty():
		return null
	var parts: Array[AudioStream] = []
	for path in paths:
		var one: AudioStream = _file_stream(String(path))
		if one == null:
			return null
		parts.append(one)
	var mix := AudioStreamRandomizer.new()
	for i in parts.size():
		mix.add_stream(i, parts[i], 1.0)
	mix.random_pitch = maxf(1.0, float(_spec(id).get("pitch", 1.0)))
	mix.random_volume_offset_db = 1.5
	_streams[id] = mix
	return mix

func _build_voices() -> void:
	for i in range(VOICE_COUNT):
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_voices.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	add_child(_ambience)
	_ambience_night = AudioStreamPlayer.new()
	_ambience_night.name = "AmbienceNight"
	add_child(_ambience_night)

func _build_world_players() -> void:
	_world = Node3D.new()
	_world.name = "WorldSound"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	for i in range(int(_sounds_table().get("world_players", 16))):
		var p := AudioStreamPlayer3D.new()
		p.name = "Sound%d" % i
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_world.add_child(p)
		_players.append(p)
	_listener = AudioListener3D.new()
	_listener.name = "Listener"
	_world.add_child(_listener)

## The next player not busy, or -- all of them busy -- the one after the last used.
func _free_player() -> AudioStreamPlayer3D:
	for k in _players.size():
		var i: int = (_next_player + k) % _players.size()
		if not _players[i].playing:
			_next_player = (i + 1) % _players.size()
			return _players[i]
	var p: AudioStreamPlayer3D = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return p

## The listener stands between the ground the camera is looking at and the camera
## (Config.SOUNDS.listener_lift), facing as the camera does: what is in the middle of the
## screen is near, what is off its left is heard on the left, and zooming out does not turn the
## world down.
func _place_listener() -> void:
	if _listener == null or not is_inside_tree():
		return
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null or not is_instance_valid(cam):
		return
	if not _listener.is_current():
		_listener.make_current()
	var eye: Vector3 = cam.global_position
	var ahead: Vector3 = -cam.global_transform.basis.z
	var ground: Vector3 = eye
	if ahead.y < -0.05:
		ground = eye + ahead * (eye.y / -ahead.y)
	var lift: float = float(_sounds_table().get("listener_lift", 0.3))
	_listener.global_transform = Transform3D(cam.global_transform.basis, ground.lerp(eye, lift))

# ==============================================================================
# Helpers
# ==============================================================================

## Parent for short-lived presentation nodes -- debris, floating text. One bucket
## under the running scene, so restarting a level takes all of it along.
## A dinosaur's body where it fell (the debug-agent's BUG-029: it went the frame it died, and its fall
## was never seen). The dinosaur itself still goes at once -- nothing hunts, counts or steers round the
## dead -- and its body is handed here, to lie under the running scene with the debris: it falls as its
## death clip has it (playing already, `fall_seconds` of it left), lies (FEEDBACK.carcass_lie), then
## sinks `depth` into the ground (carcass_sink) and is gone. Hidden in the fog as it was. Returns what
## is left, or null -- nothing taken -- with no scene to lay it in.
func lay_down(body: Node3D, fall_seconds: float, depth: float) -> Node3D:
	var root := _get_debris_root()
	if root == null or body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return null
	var carcass := Node3D.new()
	carcass.name = "Carcass"
	carcass.visible = body.is_visible_in_tree()
	root.add_child(carcass)
	carcass.global_position = body.global_position
	body.reparent(carcass, true)
	var sink := carcass.create_tween()
	sink.tween_interval(maxf(0.0, fall_seconds) + float(_cfg("carcass_lie", 2.0)))
	sink.tween_property(carcass, "position:y", carcass.position.y - depth, float(_cfg("carcass_sink", 1.6))) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sink.tween_callback(carcass.queue_free)
	return carcass

func _get_debris_root() -> Node3D:
	if _debris_root != null and is_instance_valid(_debris_root) and _debris_root.is_inside_tree():
		return _debris_root
	if not is_inside_tree():
		return null
	# Debris lives under the current scene so restarting the level takes it with it.
	var scene := get_tree().current_scene
	if scene == null or not (scene is Node3D):
		return null
	_debris_root = scene.find_child("FxDebris", false, false) as Node3D
	if _debris_root == null:
		_debris_root = Node3D.new()
		_debris_root.name = "FxDebris"
		scene.add_child(_debris_root)
	return _debris_root

func _cfg(key: String, fallback):
	var cfg = get_node_or_null("/root/Config")
	if cfg and "FEEDBACK" in cfg:
		return cfg.FEEDBACK.get(key, fallback)
	return fallback
