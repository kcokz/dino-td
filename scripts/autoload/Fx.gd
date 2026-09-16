# res://scripts/autoload/Fx.gd
extends Node

## Presentation feedback for Defend Dinosaur v0.3.
##
## Everything here is about making an event legible: a hit flashes, a death throws
## debris, an impact makes a noise. None of it changes what happens in the game, so
## any of it failing must never break the simulation -- every entry point is safe to
## call from a headless run, where there is no renderer and no audio device.
##
## Sounds are synthesised at startup rather than shipped as files: they are simple
## blips, and generating them keeps the repo free of binary assets and of Godot's
## import step (which does not run in a bare headless test).

enum Sound { HIT, DEATH, BUILD_DONE, RAID_WARNING, PICKUP }

const AUDIO_RATE: int = 22050
const VOICE_COUNT: int = 8

var _streams: Dictionary = {}          # Sound -> AudioStreamWAV
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _debris_root: Node3D = null

func _ready() -> void:
	_build_sounds()
	_build_voices()

# ==============================================================================
# Hit flash
# ==============================================================================

## Briefly whitens `mesh` to show it was struck. Safe to call repeatedly; a second
## hit simply restarts the flash rather than stacking.
func flash(mesh: MeshInstance3D, strength: float = -1.0, duration: float = -1.0) -> void:
	if mesh == null or not is_instance_valid(mesh) or not mesh.is_inside_tree():
		return
	var mat := mesh.material_override as StandardMaterial3D
	if mat == null:
		return
	if duration < 0.0:
		duration = _cfg("hit_flash_duration", 0.12)
	if strength < 0.0:
		strength = _cfg("hit_flash_strength", 0.85)
	if duration <= 0.0:
		return

	# Work on a copy so the flash can never leak into the shared material the
	# building uses for its own colour or highlight state.
	var flashing: StandardMaterial3D = mat.duplicate()
	var base: Color = flashing.albedo_color
	flashing.albedo_color = base.lerp(Color(1, 1, 1, base.a), clampf(strength, 0.0, 1.0))
	mesh.material_override = flashing

	var tw := create_tween()
	tw.tween_property(flashing, "albedo_color", base, duration)
	tw.finished.connect(func():
		if is_instance_valid(mesh) and mesh.material_override == flashing:
			mesh.material_override = mat
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

		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.4), randf_range(-1.0, 1.0)).normalized()
		var target: Vector3 = piece.position + dir * speed * life * 0.5
		target.y = maxf(0.05, target.y - speed * life * 0.35) # let gravity win

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(piece, "position", target, life)
		tw.tween_property(piece, "rotation", piece.rotation + Vector3(randf(), randf(), randf()) * TAU, life)
		tw.tween_property(mat, "albedo_color:a", 0.0, life)
		tw.chain().tween_callback(func():
			if is_instance_valid(piece):
				piece.queue_free()
		)

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
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lbl.no_depth_test = true
	var cfg = get_node_or_null("/root/Config")
	if cfg and "UI" in cfg:
		lbl.font_size = int(cfg.UI.get("world_label_font_size", 48))
		lbl.pixel_size = float(cfg.UI.get("world_label_pixel_size", 0.005))
		lbl.fixed_size = bool(cfg.UI.get("world_label_fixed_size", false))
		lbl.outline_size = maxi(1, int(round(lbl.font_size / 6.0)))
	lbl.position = world_pos + Vector3(0.0, 0.6, 0.0)
	root.add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector3(0.0, rise, 0.0), life)
	tw.tween_property(lbl, "modulate:a", 0.0, life)
	tw.chain().tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

# ==============================================================================
# Sound
# ==============================================================================

func play(which: int) -> void:
	if not bool(_cfg("audio_enabled", true)):
		return
	if not _streams.has(which) or _voices.is_empty():
		return
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	if not is_instance_valid(voice):
		return
	voice.stream = _streams[which]
	voice.volume_db = float(_cfg("audio_volume_db", -8.0))
	voice.play()

func _build_voices() -> void:
	for i in range(VOICE_COUNT):
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_voices.append(p)

func _build_sounds() -> void:
	# short, dry thud
	_streams[Sound.HIT] = _make_wav(0.07, func(t: float, n: float) -> float:
		return (randf() * 2.0 - 1.0) * (1.0 - n) * 0.6 + sin(t * TAU * 180.0) * (1.0 - n) * 0.4
	)
	# falling tone
	_streams[Sound.DEATH] = _make_wav(0.32, func(t: float, n: float) -> float:
		return sin(t * TAU * lerpf(420.0, 90.0, n)) * (1.0 - n) * 0.7
	)
	# two rising notes
	_streams[Sound.BUILD_DONE] = _make_wav(0.26, func(t: float, n: float) -> float:
		var freq: float = 520.0 if n < 0.5 else 780.0
		return sin(t * TAU * freq) * (1.0 - n * 0.7) * 0.5
	)
	# low horn
	_streams[Sound.RAID_WARNING] = _make_wav(0.6, func(t: float, n: float) -> float:
		var env: float = minf(n * 6.0, 1.0) * (1.0 - n)
		return (sin(t * TAU * 110.0) * 0.6 + sin(t * TAU * 165.0) * 0.4) * env * 0.8
	)
	# short blip, rising: something went into the bag
	_streams[Sound.PICKUP] = _make_wav(0.11, func(t: float, n: float) -> float:
		return sin(t * TAU * lerpf(620.0, 980.0, n)) * (1.0 - n) * 0.45
	)

## Builds a mono 16-bit stream by sampling `shape(t_seconds, normalised_progress)`.
func _make_wav(seconds: float, shape: Callable) -> AudioStreamWAV:
	var frames: int = maxi(1, int(AUDIO_RATE * seconds))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t: float = float(i) / float(AUDIO_RATE)
		var n: float = float(i) / float(frames)
		var v: float = clampf(float(shape.call(t, n)), -1.0, 1.0)
		var sample: int = int(v * 32767.0)
		bytes.encode_s16(i * 2, sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AUDIO_RATE
	wav.stereo = false
	wav.data = bytes
	return wav

# ==============================================================================
# Helpers
# ==============================================================================

## Parent for short-lived presentation nodes -- debris, floating text. One bucket
## under the running scene, so restarting a level takes all of it along.
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
