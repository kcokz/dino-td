# res://scripts/entities/ProducerBuilding.gd
class_name ProducerBuilding
extends "res://scripts/entities/Building.gd"

## Economic producer building base class for Defend Dinosaur v0.2.
##
## Machinery must draw from real ResourceNodes: while operating it seeks the nearest
## non-depleted node of the resource it produces within `harvest_range`, and every unit
## it banks is taken out of that node's remaining amount. A producer with no node in
## range produces nothing, so placement matters.
##
## Also supports tending (timed autonomous operation) and the legacy turn-based
## `produce_phase` payout kept for v0.0 compatibility.

var produces: Dictionary = {}
var production: Dictionary:
	get: return produces
	set(v): produces = v

var produces_per_sec: Dictionary = {}
var tend_duration: float = 40.0
var tend_time: float = 2.0
var harvest_range: float = 12.0

# v0.2 Machinery Tending State
var is_operating: bool = false
var operation_timer: float = 0.0
var payout_timer: float = 0.0
var _accumulated_production: Dictionary = {}
var _last_label_second: int = -1

# v0.2 Node-backed harvesting state
var _sources: Dictionary = {}            # res_id -> ResourceNode currently drawn from
var _source_scan_cooldown: float = 0.0   # throttles the O(N) group scan

const SOURCE_SCAN_INTERVAL: float = 0.4

## The node this machine is currently drawing from (null when none in range).
var target_source: Node:
	get:
		for res_id in _sources:
			var n = _sources[res_id]
			if n != null and is_instance_valid(n):
				return n
		return null

func _init(p_type: String = "lumber_hut") -> void:
	super(p_type)
	building_type = p_type
	_load_production_config()
	_connect_produce_signal()

func _ready() -> void:
	super._ready()
	set_process(true)
	_load_production_config()
	_connect_produce_signal()
	_update_info_label()

func _exit_tree() -> void:
	super._exit_tree()
	_disconnect_produce_signal()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_produce_signal()

func _on_before_destroy() -> void:
	_disconnect_produce_signal()

func setup(type_id: String, p_cell: Vector2i = Vector2i.ZERO) -> void:
	super.setup(type_id, p_cell)
	_load_production_config()

func _load_production_config() -> void:
	var cfg = _get_config()
	if cfg and "BUILDINGS" in cfg and cfg.BUILDINGS.has(building_type):
		var b_cfg: Dictionary = cfg.BUILDINGS[building_type]
		produces = b_cfg.get("produces", {}).duplicate(true)
		produces_per_sec = b_cfg.get("produces_per_sec", {}).duplicate(true)
		tend_duration = float(b_cfg.get("tend_duration", 40.0))
		tend_time = float(b_cfg.get("tend_time", 2.0))
		harvest_range = float(b_cfg.get("harvest_range", 12.0))

# ==============================================================================
# Legacy turn-based production (v0.0 produce_phase)
# ==============================================================================

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
		gs.add_resources(produces)

# ==============================================================================
# Tending
# ==============================================================================

func get_tend_time() -> float:
	return tend_time

func get_tend_duration() -> float:
	return tend_duration

func tend(duration: float = -1.0) -> void:
	if is_destroyed or not is_constructed:
		return
	is_operating = true
	operation_timer = duration if duration >= 0.0 else get_tend_duration()
	payout_timer = 0.0
	_accumulated_production.clear()
	_source_scan_cooldown = 0.0
	_last_label_second = int(ceil(operation_timer))

	var eb = _get_event_bus()
	if eb and eb.has_signal("building_tended"):
		eb.building_tended.emit(self)
	_update_info_label()

# ==============================================================================
# Node-backed harvesting
# ==============================================================================

## True when this resource is something that exists on the map as harvestable nodes,
## and therefore may not be produced out of thin air.
func requires_source(res_id: String) -> bool:
	var cfg = _get_config()
	return cfg != null and "RESOURCE_NODES" in cfg and cfg.RESOURCE_NODES.has(res_id)

## Nearest non-depleted resource node of `res_id` within harvest_range, or null.
func find_nearest_source(res_id: String) -> Node:
	if not is_inside_tree():
		return null
	var nearest: Node = null
	var min_dist: float = harvest_range + 0.001
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if not ("resource_type" in n) or n.resource_type != res_id:
			continue
		if "is_depleted" in n and n.is_depleted:
			continue
		if "current_amount" in n and n.current_amount <= 0:
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d <= harvest_range and d < min_dist:
			min_dist = d
			nearest = n
	return nearest

func _is_source_usable(n) -> bool:
	if n == null or not is_instance_valid(n) or n.is_queued_for_deletion():
		return false
	if "is_depleted" in n and n.is_depleted:
		return false
	return global_position.distance_to(n.global_position) <= harvest_range

## Returns a usable source for res_id, re-acquiring only when needed (scan is throttled).
func _acquire_source(res_id: String, force_rescan: bool = false) -> Node:
	var cached = _sources.get(res_id, null)
	if not force_rescan and _is_source_usable(cached):
		return cached
	if not force_rescan and _source_scan_cooldown > 0.0:
		return null
	var found := find_nearest_source(res_id)
	_sources[res_id] = found
	if found == null:
		_source_scan_cooldown = SOURCE_SCAN_INTERVAL
	return found

func has_source_in_range() -> bool:
	for res_id in produces_per_sec:
		if float(produces_per_sec[res_id]) <= 0.0:
			continue
		if not requires_source(res_id):
			continue
		if _is_source_usable(_sources.get(res_id, null)):
			return true
	return false

# ==============================================================================
# Continuous production
# ==============================================================================

func _process(delta: float) -> void:
	if not is_operating or not is_constructed or is_destroyed:
		return
	var gs = _get_game_state()
	if gs and ("is_paused" in gs and gs.is_paused or "is_game_over" in gs and gs.is_game_over):
		return

	operation_timer = maxf(0.0, operation_timer - delta)
	payout_timer += delta
	_source_scan_cooldown = maxf(0.0, _source_scan_cooldown - delta)

	for res_id in produces_per_sec:
		var rate: float = float(produces_per_sec[res_id])
		if rate <= 0.0:
			continue
		var needs_source: bool = requires_source(res_id)
		# Keep a source warm so the label reflects reality even before a unit is banked.
		if needs_source:
			_acquire_source(res_id)

		var acc: float = float(_accumulated_production.get(res_id, 0.0)) + rate * delta
		while acc >= 1.0:
			var gained: int = 0
			if needs_source:
				var src = _acquire_source(res_id, not _is_source_usable(_sources.get(res_id, null)))
				if src == null:
					# Nothing to draw from: do not bank progress, do not invent resources.
					acc = 0.0
					break
				gained = int(src.harvest(1))
			else:
				gained = 1
			acc -= 1.0
			if gained > 0:
				_deposit(gs, res_id, gained)
		_accumulated_production[res_id] = acc

	if operation_timer <= 0.0:
		operation_timer = 0.0
		is_operating = false
		_sources.clear()

	var cur_sec: int = int(ceil(operation_timer))
	if cur_sec != _last_label_second or not is_operating:
		_last_label_second = cur_sec
		_update_info_label()

func _deposit(gs, res_id: String, amount: int) -> void:
	if gs == null or amount <= 0:
		return
	if gs.has_method("add_resource"):
		gs.add_resource(res_id, amount)
	elif "resources" in gs:
		gs.resources[res_id] = gs.resources.get(res_id, 0) + amount
		var eb = _get_event_bus()
		if eb and eb.has_signal("resources_changed"):
			eb.resources_changed.emit(gs.resources)

# ==============================================================================
# Coverage ring overrides (ring itself lives in Building)
# ==============================================================================

func _get_display_range() -> float:
	return harvest_range

## Tints the ring with the colour of the resource this machine harvests.
func _get_range_indicator_color() -> Color:
	var cfg = _get_config()
	if cfg and "RESOURCE_NODES" in cfg:
		for res_id in produces_per_sec:
			if cfg.RESOURCE_NODES.has(res_id):
				var c: Color = cfg.RESOURCE_NODES[res_id].get("color", Color(0.2, 0.8, 0.3))
				return Color(c.r, c.g, c.b, 0.16)
	return Color(0.2, 0.8, 0.3, 0.16)

# ==============================================================================
# Status display
# ==============================================================================

## Subclasses override to give the harvesting line resource-specific wording.
func _source_status_text(src: Node) -> String:
	var raw := tr("STATUS_HARVESTING_SOURCE")
	if "%" in raw:
		return raw % [src.current_amount, src.max_capacity]
	return raw

func _no_source_status_text() -> String:
	return tr("STATUS_NO_SOURCE_IN_RANGE")

func _get_extra_status_text() -> String:
	if not is_constructed:
		return ""
	if not is_operating:
		return tr("STATUS_NEEDS_TENDING")

	var raw_op := tr("STATUS_OPERATING")
	var time_str: String = (raw_op % int(ceil(operation_timer))) if ("%" in raw_op) else raw_op

	var src := target_source
	if src != null:
		return "%s\n%s" % [time_str, _source_status_text(src)]
	if _needs_any_source():
		return "%s\n%s" % [time_str, _no_source_status_text()]
	return time_str

func _needs_any_source() -> bool:
	for res_id in produces_per_sec:
		if float(produces_per_sec[res_id]) > 0.0 and requires_source(res_id):
			return true
	return false

func _update_info_label() -> void:
	super._update_info_label()
	if label_3d and is_operating and is_constructed:
		if target_source == null and _needs_any_source():
			label_3d.modulate = Color(1.0, 0.65, 0.2) # Amber: idle, nothing to harvest
		else:
			label_3d.modulate = Color(0.4, 0.9, 0.4) # Green: actively producing

func get_display_info() -> Dictionary:
	var info = super.get_display_info()
	info["is_operating"] = is_operating
	info["operation_timer"] = operation_timer
	info["harvest_range"] = harvest_range
	info["target_source"] = target_source
	info["status"] = _get_extra_status_text()
	return info
