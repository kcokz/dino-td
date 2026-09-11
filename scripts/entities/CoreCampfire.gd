# res://scripts/entities/CoreCampfire.gd
class_name CoreCampfire
extends "res://scripts/entities/Building.gd"

## Campfire base objective. Loss of this structure triggers game_lost.
## Emits core_hp_changed on initialization and whenever damaged.

var _last_emitted_hp: float = -1.0

func _init() -> void:
	super("core")
	building_type = "core"
	var cfg = _get_config()
	if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has("core"):
		var data: Dictionary = cfg.BUILDINGS["core"]
		max_hp = float(data.get("hp", 10.0))
	else:
		max_hp = 10.0
	current_hp = max_hp

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
