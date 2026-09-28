# res://scripts/entities/Trap.gd
class_name Trap
extends "res://scripts/entities/Building.gd"

## A trap: set along a lane of ground in front of it, and loosed by whatever walks into its wire
## (Config.BUILDINGS kind "trap", Config.TRAPS; GAME-DESIGN 6.2).
##
## v0.6 round two: "Bow tower作为初始防御太过于强大……想一个能攻击但不是tower的防御……防御装置自动可以攻击
## 需要合理解释". Nothing the player builds aims. A trap faces one of four ways -- R turns it while
## it is being placed -- and its LANE is the cells in front of it, as far as Config's `lane`, or as
## far as the wire can run before something built or standing stops it. An animal stepping into
## the wire looses it, the way a trip bow or a set crossbow on a game trail is loosed: the trip
## bow's arrow at the first animal on the wire, the set crossbow's bolt the whole length of the
## lane, through every animal on it. Then it has to be re-armed -- `rearm_seconds` of the string
## being drawn back, which the player sees happen (the model's String and Arrow or Bolt,
## tools/generate_props.py) and reads on its panel.
##
## A trap is a building like any other: it fills its cell, stops whoever walks into it, and a pack
## goes for the traps near it (Dino._is_shooter). The Hero does not trip his own wires -- he set
## them, and steps over them -- and a trap still only being built has no wire yet.

## The four ways a trap can face, clockwise from north, as steps on the building grid.
const FACINGS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Which way it faces: an index into FACINGS. Given before it enters the tree (BuildSystem.place_at).
@export var facing: int = 0

var damage: float = 1.0
## Whether what it looses flies the whole lane, through everything on it, or stops in the first.
var pierce: bool = false
var rearm_seconds: float = 3.0
## How many cells of wire it is set with, at most.
var lane_length: int = 4

## Whether it is set: the string drawn and a shot on it.
var armed: bool = true
## Seconds of re-arming left, while it is not.
var rearm_left: float = 0.0

## The cells its wire runs through, nearest first.
var lane: Array[Vector2i] = []

var _wire: Area3D = null
var _wire_shape: CollisionShape3D = null
var _wire_line: MeshInstance3D = null
var _wire_peg: MeshInstance3D = null
var _string: Node3D = null
var _string_drawn: Vector3 = Vector3.ZERO
var _shot: Node3D = null

func _init() -> void:
	super("trip_bow")
	_load_trap_config()

func _ready() -> void:
	super._ready()
	_load_trap_config()
	_face_body()
	_find_parts()
	_ensure_wire()
	_connect_lane_events()
	refresh_lane.call_deferred()

func _exit_tree() -> void:
	super._exit_tree()
	var eb = _get_event_bus()
	if eb == null or not is_instance_valid(eb):
		return
	for sig in ["building_placed", "building_destroyed", "building_completed"]:
		if eb.has_signal(sig) and eb.is_connected(sig, _on_something_built):
			eb.disconnect(sig, _on_something_built)

func setup(type_id: String = "trip_bow", p_cell: Vector2i = Vector2i.ZERO) -> void:
	super.setup(type_id, p_cell)
	_load_trap_config()

func _load_trap_config() -> void:
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(building_type):
		return
	var data: Dictionary = cfg.BUILDINGS[building_type]
	damage = float(data.get("damage", 1.0))
	pierce = bool(data.get("pierce", false))
	rearm_seconds = maxf(0.1, float(data.get("rearm_seconds", 3.0)))
	lane_length = maxi(1, int(data.get("lane", 4)))

func _trap_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	if cfg and "TRAPS" in cfg:
		return float(cfg.TRAPS.get(key, fallback))
	return fallback

# ==============================================================================
# Which way it faces, and the lane in front of it
# ==============================================================================

## Turns the trap to face `f` (an index into FACINGS, taken round), and lays its wire again.
func set_facing(f: int) -> void:
	facing = posmod(f, FACINGS.size())
	_face_body()
	refresh_lane()

## The step on the building grid its lane runs in.
func facing_step() -> Vector2i:
	return FACINGS[posmod(facing, FACINGS.size())]

## The turn about the vertical that points a body built facing north at `f` (FACINGS order).
static func facing_yaw(f: int) -> float:
	return -float(posmod(f, FACINGS.size())) * PI * 0.5

## The cells in front of `cell` facing `f`, nearest first, as far as `length` -- stopping at the
## first one something is built in or standing on: a wire does not run through a wall, a tree or
## a hillside. Static, so the build preview lays out exactly the lane the trap will.
static func lane_from(gm: Node, cell: Vector2i, f: int, length: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if gm == null:
		return out
	var step: Vector2i = FACINGS[posmod(f, FACINGS.size())]
	for k in range(1, length + 1):
		var c: Vector2i = cell + step * k
		if gm.is_build_cell_taken(c) or not gm.is_build_cell_ground(c):
			break
		out.append(c)
	return out

## Works the lane out again, and lays the wire along it.
func refresh_lane() -> void:
	if not is_inside_tree():
		return
	var gm = _grid()
	lane = lane_from(gm, gm.world_to_build_cell(global_position), facing, lane_length) if gm != null else ([] as Array[Vector2i])
	_lay_wire()

func _connect_lane_events() -> void:
	var eb = _get_event_bus()
	if eb == null:
		return
	for sig in ["building_placed", "building_destroyed", "building_completed"]:
		if eb.has_signal(sig) and not eb.is_connected(sig, _on_something_built):
			eb.connect(sig, _on_something_built)

## Something went up or came down: if it is on the line of the lane, the wire is laid again --
## deferred, so the grid has taken it in or let it go first.
func _on_something_built(other: Node) -> void:
	if other == null or not is_instance_valid(other) or not (other is Node3D) or not is_inside_tree():
		return
	if other == self:
		_lay_wire.call_deferred()      # finished: the wire goes out
		return
	var gm = _grid()
	if gm == null:
		return
	var here: Vector2i = gm.world_to_build_cell(global_position)
	var there: Vector2i = gm.world_to_build_cell((other as Node3D).global_position)
	var step: Vector2i = facing_step()
	var off: Vector2i = there - here
	# Anywhere along its line, as far as the longest lane could reach, give or take the other's
	# own half width.
	var reach: int = lane_length + 2
	var along: int = off.x * step.x + off.y * step.y
	var across: int = absi(off.x * step.y - off.y * step.x)
	if along >= 0 and along <= reach and across <= 2:
		refresh_lane.call_deferred()

func _grid() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("grid_manager")

# ==============================================================================
# The wire
# ==============================================================================

func _ensure_wire() -> void:
	if _wire != null:
		return
	_wire = Area3D.new()
	_wire.name = "Tripwire"
	_wire.collision_layer = 0
	_wire.collision_mask = _dino_layer()
	_wire.monitorable = false
	_wire_shape = CollisionShape3D.new()
	_wire_shape.shape = BoxShape3D.new()
	_wire.add_child(_wire_shape)
	add_child(_wire)

	var vine := StandardMaterial3D.new()
	vine.albedo_color = _wire_colour()
	_wire_line = MeshInstance3D.new()
	_wire_line.name = "WireLine"
	_wire_line.mesh = BoxMesh.new()
	_wire_line.material_override = vine
	_wire_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wire_line)
	# The peg at the far end the wire is tied to.
	_wire_peg = MeshInstance3D.new()
	_wire_peg.name = "WirePeg"
	var peg := CylinderMesh.new()
	peg.top_radius = 0.012
	peg.bottom_radius = 0.02
	peg.height = _trap_number("wire_height", 0.18) + 0.06
	_wire_peg.mesh = peg
	_wire_peg.material_override = vine
	add_child(_wire_peg)

## Lays the wire along the lane -- the trigger that feels for animals, the vine that shows where
## it is, and the peg it is tied to -- or takes it up while there is no lane or the trap is
## still being built.
func _lay_wire() -> void:
	if _wire == null:
		return
	var n: int = lane.size()
	var set_up: bool = n > 0 and is_constructed and not is_destroyed
	# Deferred: a trap can be finished or knocked down from inside a physics step, and an area's
	# monitoring may not change while the engine is flushing its queries.
	_wire.set_deferred("monitoring", set_up)
	_wire_shape.set_deferred("disabled", not set_up)
	_wire_line.visible = set_up
	_wire_peg.visible = set_up
	if n == 0:
		return
	var s: float = _cell_size()
	var step := Vector3(float(facing_step().x), 0.0, float(facing_step().y))
	var length: float = float(n) * s
	# From the front of its own cell to the far side of the last cell of the lane.
	var middle: Vector3 = step * (s * 0.5 + length * 0.5)
	var width: float = _trap_number("wire_width", 0.8)
	var tall: float = _trap_number("trigger_height", 1.0)
	var runs_x: bool = step.x != 0.0
	(_wire_shape.shape as BoxShape3D).size = Vector3(length if runs_x else width, tall, width if runs_x else length)
	_wire_shape.position = middle + Vector3(0.0, tall * 0.5, 0.0)
	var thread: float = 0.012
	var high: float = _trap_number("wire_height", 0.18)
	(_wire_line.mesh as BoxMesh).size = Vector3(length if runs_x else thread, thread, thread if runs_x else length)
	_wire_line.position = middle + Vector3(0.0, high, 0.0)
	var far: Vector3 = step * (s * 0.5 + length - 0.06)
	_wire_peg.position = far + Vector3(0.0, (high + 0.06) * 0.5, 0.0)

## The wire goes out when the trap is finished, and is taken up if it is knocked back to a
## blueprint.
func _update_construction_state() -> void:
	super._update_construction_state()
	_lay_wire()

func _cell_size() -> float:
	var cfg = _get_config()
	return float(cfg.BUILD_CELL) if (cfg and "BUILD_CELL" in cfg) else 1.0

func _dino_layer() -> int:
	var cfg = _get_config()
	return int(cfg.LAYER_DINO) if (cfg and "LAYER_DINO" in cfg) else 8

func _wire_colour() -> Color:
	var cfg = _get_config()
	if cfg and "TRAPS" in cfg:
		return cfg.TRAPS.get("lane_color", Color(0.95, 0.8, 0.35))
	return Color(0.95, 0.8, 0.35)

# ==============================================================================
# Loosing, and re-arming
# ==============================================================================

func _physics_process(delta: float) -> void:
	if not _is_live():
		return
	if not armed:
		rearm_left = maxf(0.0, rearm_left - delta)
		_show_draw(1.0 - rearm_left / rearm_seconds)
		if rearm_left <= 0.0:
			_arm()
		return
	var on_wire: Array = animals_on_wire()
	if not on_wire.is_empty():
		loose(on_wire)

## Finished, standing, and not paused -- a paused game must not have its traps going off while
## the player reads the map.
func _is_live() -> bool:
	if is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion():
		return false
	var gs = _get_game_state()
	return not (gs != null and "is_paused" in gs and bool(gs.is_paused))

## Every animal whose body is on the wire, nearest the trap first.
func animals_on_wire() -> Array:
	var out: Array = []
	if _wire == null or not _wire.monitoring or lane.is_empty():
		return out
	for body in _wire.get_overlapping_bodies():
		if _is_quarry(body):
			out.append(body)
	var here: Vector3 = global_position
	out.sort_custom(func(a, b): return here.distance_squared_to((a as Node3D).global_position) \
		< here.distance_squared_to((b as Node3D).global_position))
	return out

func _is_quarry(body: Variant) -> bool:
	if body == null or typeof(body) != TYPE_OBJECT or not is_instance_valid(body):
		return false
	if not (body is Node3D) or body.is_queued_for_deletion() or not body.is_in_group("dinos"):
		return false
	if "is_dead" in body and body.is_dead:
		return false
	return body.has_method("take_damage")

## Lets it go at what is on the wire: the first animal, or -- a bolt that flies the whole lane --
## every one of them. Then it has to be re-armed. Returns how many it struck.
func loose(on_wire: Array) -> int:
	if on_wire.is_empty() or not armed:
		return 0
	var struck: Array = on_wire if pierce else [on_wire[0]]
	var end_point: Vector3 = _lane_end() if pierce else (struck[0] as Node3D).global_position
	var hit: int = 0
	for animal in struck:
		if _is_quarry(animal):
			animal.take_damage(damage)
			hit += 1
	armed = false
	rearm_left = rearm_seconds
	_show_draw(0.0)
	_fly_shot(end_point)
	var fx = _get_fx()
	if fx:
		fx.play(fx.Sound.TWANG)
	_update_info_label()
	return hit

func _arm() -> void:
	armed = true
	rearm_left = 0.0
	_show_draw(1.0)
	_update_info_label()

## How far drawn the string is, 0 let go to 1 drawn, shown on the model: the String slides back
## from the chord of the bow to the nock, and the shot is on it only once it is drawn.
func _show_draw(drawn: float) -> void:
	if _string == null or not is_instance_valid(_string):
		_find_parts()
	var travel: float = _trap_number("string_travel", 0.26)
	if _string != null and is_instance_valid(_string):
		# Along the body's own forward (-Z): the body turns, the string's travel turns with it.
		_string.position = _string_drawn + Vector3(0.0, 0.0, -travel * (1.0 - clampf(drawn, 0.0, 1.0)))
	if _shot != null and is_instance_valid(_shot):
		_shot.visible = drawn >= 1.0

## The far end of the wire, where a bolt that flew the whole lane comes to rest.
func _lane_end() -> Vector3:
	var step := Vector3(float(facing_step().x), 0.0, float(facing_step().y))
	return global_position + step * (_cell_size() * (0.5 + float(maxi(1, lane.size()))))

## A copy of the shot flying from the string to `to`, and gone when it gets there. The hit has
## already landed (loose); this is only what is seen.
func _fly_shot(to: Vector3) -> void:
	if not is_inside_tree() or _shot == null or not is_instance_valid(_shot):
		return
	if DisplayServer.get_name() == "headless":
		return
	var flying: Node3D = _shot.duplicate() as Node3D
	if flying == null:
		return
	var from: Transform3D = _shot.global_transform
	get_parent().add_child(flying)
	flying.global_transform = from
	flying.visible = true
	var target: Vector3 = Vector3(to.x, from.origin.y, to.z)
	var speed: float = maxf(1.0, _trap_number("shot_speed", 32.0))
	var tw := flying.create_tween()
	tw.tween_property(flying, "global_position", target, from.origin.distance_to(target) / speed)
	tw.tween_callback(flying.queue_free)

# ==============================================================================
# Its body
# ==============================================================================

## The body is built pointing north; it is turned the way the trap faces. Only the body: the
## collider fills the cell whichever way it faces.
func _face_body() -> void:
	var body: Node3D = get_node_or_null("Body") as Node3D
	if body != null:
		body.rotation.y = facing_yaw(facing)

## The String and the shot on it (an Arrow or a Bolt), found on the art by name.
func _find_parts() -> void:
	var body: Node = get_node_or_null("Body")
	if body == null:
		return
	_string = body.find_child("String", true, false) as Node3D
	if _string != null:
		_string_drawn = _string.position
	_shot = body.find_child("Arrow", true, false) as Node3D
	if _shot == null:
		_shot = body.find_child("Bolt", true, false) as Node3D

## Upgraded to a different model: the new one turned the same way, and drawn as far as the old.
func _rebuild_body(old_type: String) -> void:
	super._rebuild_body(old_type)
	_load_trap_config()
	_face_body()
	_find_parts()
	_show_draw(1.0 if armed else 1.0 - rearm_left / rearm_seconds)
	refresh_lane()

# ==============================================================================
# Presentation
# ==============================================================================

## A trap's line: set and waiting, or being re-armed and for how long.
func _panel_status() -> String:
	if not is_constructed:
		return ""
	if armed:
		return tr("STATUS_TRAP_ARMED")
	var raw: String = tr("STATUS_TRAP_REARMING")
	return (raw % rearm_left) if "%" in raw else raw

func get_display_info() -> Dictionary:
	var info: Dictionary = super.get_display_info()
	info["armed"] = armed
	info["rearm_left"] = rearm_left
	info["lane"] = lane.size()
	return info
