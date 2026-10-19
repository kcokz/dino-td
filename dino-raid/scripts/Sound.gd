class_name Sound
extends Node
## The few sounds there are (GAME-DESIGN 21): a click for a button pressed, and the valley's air under the title and
## over the homeland -- quiet, from the shared library (common/assets/audio, CREDITS.md).

const CLICK := "res://common/assets/audio/ui_click.wav"
const AIR := "res://common/assets/audio/ambience_valley.wav"
const AIR_DB := -16.0

static var me: Sound

var _click: AudioStreamPlayer
var _air: AudioStreamPlayer
var _air_tween: Tween


func _ready() -> void:
	me = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click = AudioStreamPlayer.new()
	_click.stream = load(CLICK) if ResourceLoader.exists(CLICK) else null
	_click.volume_db = -8.0
	add_child(_click)
	_air = AudioStreamPlayer.new()
	_air.stream = load(AIR) if ResourceLoader.exists(AIR) else null
	_air.volume_db = -60.0
	_air.finished.connect(func() -> void: _air.play())
	add_child(_air)


## A button pressed.
static func click() -> void:
	if me != null and Settings.clicks and me._click.stream != null:
		me._click.play()


## The air coming up (or going away) over `time` seconds.
static func air(on: bool, time := 2.0) -> void:
	if me == null or me._air.stream == null:
		return
	if on and not me._air.playing:
		me._air.play()
	if me._air_tween:
		me._air_tween.kill()
	me._air_tween = me.create_tween()
	me._air_tween.tween_property(me._air, "volume_db", AIR_DB if on else -60.0, time)
	if not on:
		me._air_tween.tween_callback(me._air.stop)


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_added)


## Every button anywhere clicks when pressed.
func _on_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("clicks"):
		n.set_meta("clicks", true)
		(n as BaseButton).pressed.connect(func() -> void: Sound.click())
