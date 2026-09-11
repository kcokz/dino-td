# res://scripts/entities/LumberHut.gd
class_name LumberHut
extends "res://scripts/entities/Building.gd"

## Economic producer building. Deposits wood into GameState during PRODUCE phase.

var production: Dictionary = {"wood": 2}
var produces: Dictionary:
	get: return production
	set(v): production = v

func _init() -> void:
	super("lumber_hut")
	building_type = "lumber_hut"
	max_hp = 10.0
	current_hp = 10.0
	_load_production_config()
	_connect_produce_signal()

func _ready() -> void:
	super._ready()
	_load_production_config()
	_connect_produce_signal()

func _exit_tree() -> void:
	_disconnect_produce_signal()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_produce_signal()

func _on_before_destroy() -> void:
	_disconnect_produce_signal()

func _load_production_config() -> void:
	var cfg = _get_config()
	if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has("lumber_hut"):
		production = cfg.BUILDINGS["lumber_hut"].get("produces", {"wood": 2}).duplicate(true)

func _connect_produce_signal() -> void:
	var eb = _get_event_bus()
	if eb and eb.has_signal("produce_phase"):
		if not eb.produce_phase.is_connected(_on_produce_phase):
			eb.produce_phase.connect(_on_produce_phase)

func _disconnect_produce_signal() -> void:
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb) and eb.has_signal("produce_phase"):
		if eb.produce_phase.is_connected(_on_produce_phase):
			eb.produce_phase.disconnect(_on_produce_phase)

func _on_produce_phase() -> void:
	if is_destroyed or current_hp <= 0.0 or is_queued_for_deletion():
		return
	var gs = _get_game_state()
	if gs and gs.has_method("add_resources"):
		gs.add_resources(production)

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
