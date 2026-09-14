# res://scripts/entities/LumberHut.gd
class_name LumberHut
extends "res://scripts/entities/Building.gd"

## Economic producer building. Deposits wood into GameState during PRODUCE phase.

var production: Dictionary = {"wood": 2}
var produces: Dictionary:
	get: return production
	set(v): production = v

# v0.2 Machinery Tending
var is_operating: bool = false
var operation_timer: float = 0.0
var payout_timer: float = 0.0
const TEND_DURATION: float = 40.0

func _init() -> void:
	super("lumber_hut")
	building_type = "lumber_hut"
	max_hp = 10.0
	current_hp = 10.0
	_load_production_config()
	_connect_produce_signal()

func _ready() -> void:
	super._ready()
	set_process(true)
	_load_production_config()
	_connect_produce_signal()
	_update_info_label()

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
	if is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion():
		return
	var gs = _get_game_state()
	if gs and gs.has_method("add_resources"):
		gs.add_resources(production)

func tend(duration: float = TEND_DURATION) -> void:
	if is_destroyed or not is_constructed:
		return
	is_operating = true
	operation_timer = duration
	payout_timer = 0.0
	var eb = _get_event_bus()
	if eb and eb.has_signal("building_tended"):
		eb.building_tended.emit(self)
	_update_info_label()

func _process(delta: float) -> void:
	if not is_operating or not is_constructed or is_destroyed:
		return
	var gs = _get_game_state()
	if gs and ("is_paused" in gs and gs.is_paused or "is_game_over" in gs and gs.is_game_over):
		return

	operation_timer -= delta
	payout_timer += delta

	if payout_timer >= 1.0:
		payout_timer -= 1.0
		if gs and gs.has_method("add_resource"):
			gs.add_resource("wood", 1)

	if operation_timer <= 0.0:
		operation_timer = 0.0
		is_operating = false

	_update_info_label()

func _get_extra_status_text() -> String:
	if not is_constructed:
		return ""
	if is_operating:
		return TranslationServer.translate("STATUS_OPERATING") % int(ceil(operation_timer))
	return TranslationServer.translate("STATUS_NEEDS_TENDING")

func get_display_info() -> Dictionary:
	var info = super.get_display_info()
	info["is_operating"] = is_operating
	info["operation_timer"] = operation_timer
	info["status"] = _get_extra_status_text()
	return info

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null
