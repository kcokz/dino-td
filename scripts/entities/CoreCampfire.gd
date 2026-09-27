# res://scripts/entities/CoreCampfire.gd
class_name CoreCampfire
extends "res://scripts/entities/Tower.gd"

## The cabin: the run's objective -- its loss is the game lost -- and, since v0.6, a turret
## of its own. The wreck's second turret head is on its roof (tools/generate_props.py cabin)
## and it shoots like any tower, by its own numbers (Config BUILDINGS.core: range, damage,
## fire rate), covering the ground round the cabin: enough for the first raptors, not for
## a raid. Emits core_hp_changed on initialization and whenever damaged.

var _last_emitted_hp: float = -1.0

func _init() -> void:
	super()             # a turret's machinery -- the range, the fire timer, the head to turn
	setup("core")       # and the cabin's own numbers
	_load_tower_config()

func _ready() -> void:
	super._ready()
	_emit_core_hp_changed()

func _emit_core_hp_changed() -> void:
	if _last_emitted_hp == current_hp:
		return
	_last_emitted_hp = current_hp
	var eb = _get_event_bus()
	if eb and eb.has_signal("core_hp_changed"):
		eb.core_hp_changed.emit(current_hp, max_hp)

func _on_damaged(_amount: float) -> void:
	_emit_core_hp_changed()

func _on_before_destroy() -> void:
	super._on_before_destroy()      # its gun stops
	_emit_core_hp_changed()
	var gs = _get_game_state()
	if gs != null and gs.is_game_over:
		return
	var eb = _get_event_bus()
	if eb and eb.has_signal("game_lost"):
		eb.game_lost.emit()

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
