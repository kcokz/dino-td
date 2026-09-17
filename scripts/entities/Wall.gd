# res://scripts/entities/Wall.gd
class_name Wall
extends "res://scripts/entities/Building.gd"

## Sharpened wooden stakes.
##
## They do not only block: whatever presses up against them is taking damage the
## whole time it is there. That is what makes a stake worth a wood rather than
## being a sack of hit points -- getting past one has a price, even when the
## dinosaur wins in the end.
##
## Three things this deliberately is not:
##   * not a turret -- the reach only covers what is standing against the stake,
##     and it cannot pick a target or lead one;
##   * not a kill -- see the balance note in Config.BUILDINGS.wall;
##   * not frame-rate-dependent -- damage lands on a fixed tick, so the rate is
##     the same however fast the machine runs, and Engine.time_scale (the HUD's
##     speed control) scales it exactly like every other simulated thing.
##
## Every number lives in Config.BUILDINGS.wall.

var contact_damage: float = 0.0
var contact_tick: float = 0.5
var contact_range: float = 0.0

var _tick_accum: float = 0.0

func _init() -> void:
	super("wall")
	building_type = "wall"
	_load_contact_config()

func _ready() -> void:
	super._ready()
	_load_contact_config()
	set_physics_process(contact_damage > 0.0 and contact_range > 0.0)
	_connect_fence_events()
	fit_to_fence()

func _exit_tree() -> void:
	super._exit_tree()
	var eb = _get_event_bus()
	if eb and is_instance_valid(eb):
		if eb.has_signal("building_placed") and eb.building_placed.is_connected(_on_fence_changed):
			eb.building_placed.disconnect(_on_fence_changed)
		if eb.has_signal("building_destroyed") and eb.building_destroyed.is_connected(_on_fence_changed):
			eb.building_destroyed.disconnect(_on_fence_changed)

func _connect_fence_events() -> void:
	var eb = _get_event_bus()
	if eb == null:
		return
	if eb.has_signal("building_placed") and not eb.building_placed.is_connected(_on_fence_changed):
		eb.building_placed.connect(_on_fence_changed)
	if eb.has_signal("building_destroyed") and not eb.building_destroyed.is_connected(_on_fence_changed):
		eb.building_destroyed.connect(_on_fence_changed)

## A stake beside this one going up or coming down changes which way the run goes.
func _on_fence_changed(_building: Node) -> void:
	if is_inside_tree() and not is_destroyed:
		fit_to_fence.call_deferred()

# ==============================================================================
# Shape: a fence panel, not a block
# ==============================================================================

## Which way the run goes, from the stakes next door: "x" for an east-west fence,
## "z" for north-south, "both" for a corner or a stake standing on its own.
##
## A stake only lines up along one axis once it is part of a run, because only then
## do its neighbours cover the rest of the tile. On its own it puts cones both ways
## -- a single stake dropped in a doorway has to close that doorway, or the player
## would plant one and watch a raptor walk past it. Since v0.4 that case is a small
## cross of cones rather than a filled tile, so "alone" no longer means "big".
func fence_axis() -> String:
	if not is_inside_tree():
		return "both"
	return axis_at(get_tree().get_first_node_in_group("grid_manager"), cell_pos, building_type)

## The same question asked about a cell that has nothing on it yet, so the build
## preview can show the shape the stake would actually take there.
##
## Static and grid-driven on purpose: hover and result come out of one function, so
## the ghost cannot promise a shape the placed stake does not have. That mismatch
## was the bug -- the ghost was always drawn full-tile whatever it was about to
## become.
static func axis_at(gm: Node, cell: Vector2i, type_id: String = "wall") -> String:
	var along_x: bool = _same_stake_at(gm, Vector2i(cell.x - 1, cell.y), type_id) or _same_stake_at(gm, Vector2i(cell.x + 1, cell.y), type_id)
	var along_z: bool = _same_stake_at(gm, Vector2i(cell.x, cell.y - 1), type_id) or _same_stake_at(gm, Vector2i(cell.x, cell.y + 1), type_id)
	if along_x == along_z:
		return "both"      # a corner, a cluster, or standing alone
	return "x" if along_x else "z"

static func _same_stake_at(gm: Node, cell: Vector2i, type_id: String) -> bool:
	if gm == null or not is_instance_valid(gm) or not gm.has_method("get_building_at"):
		return false
	var b = gm.get_building_at(cell)
	return b != null and is_instance_valid(b) and "building_type" in b and String(b.building_type) == type_id

## Re-cuts the collision and the cones to match the run.
func fit_to_fence() -> void:
	if not is_inside_tree() or is_destroyed:
		return
	_apply_shape(fence_axis())

## How deep the fence line is across the run. Derived by Config from the cone
## itself, so this and the art cannot drift apart.
func _thickness() -> float:
	var cfg = _get_config()
	if cfg and cfg.has_method("get_building_thickness"):
		return float(cfg.get_building_thickness(building_type))
	return _footprint()

## Cones and collision, rebuilt together from the same axis.
##
## A run gets one box along it, as deep as a cone is wide. A corner or a lone stake
## gets two crossed boxes -- not a filled tile, which is what used to make a block
## of stakes turn back into big squares. Either way the boxes sit exactly under the
## cones: nothing is stopped by an edge it cannot see, and nothing walks through
## something that looks solid.
func _apply_shape(axis: String) -> void:
	var span: float = _footprint()
	var thin: float = _thickness()
	var h: float = _building_height()

	var sizes: Array[Vector3] = []
	if axis != "z":
		sizes.append(Vector3(span, h, thin))
	if axis != "x":
		sizes.append(Vector3(thin, h, span))

	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	for size in sizes:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		col.position = Vector3(0.0, h * 0.5, 0.0)
		add_child(col)

	var body := find_child("Body", false, false)
	if body != null:
		remove_child(body)
		body.queue_free()
	add_child(Building.make_body(building_type, axis))

	# Fresh shapes come in enabled and fresh meshes come in opaque, so a blueprint
	# that re-fits mid-build would otherwise start blocking and look finished.
	_update_construction_state()

func setup(type_id: String = "wall", p_cell: Vector2i = Vector2i.ZERO) -> void:
	super.setup(type_id, p_cell)
	_load_contact_config()

func _load_contact_config() -> void:
	var cfg = _get_config()
	if cfg == null or not ("BUILDINGS" in cfg) or not cfg.BUILDINGS.has(building_type):
		return
	var data: Dictionary = cfg.BUILDINGS[building_type]
	contact_damage = maxf(0.0, float(data.get("contact_damage", 0.0)))
	contact_tick = maxf(0.05, float(data.get("contact_tick", 0.5)))
	contact_range = maxf(0.0, float(data.get("contact_range", 0.0)))

# ==============================================================================
# Contact damage
# ==============================================================================

func _physics_process(delta: float) -> void:
	if not _stakes_are_live():
		return
	_tick_accum += delta
	if _tick_accum < contact_tick:
		return
	_tick_accum -= contact_tick
	damage_touching_dinos()

## A blueprint has no points on it yet, and a paused game must not grind anyone
## down while the player is reading the map.
func _stakes_are_live() -> bool:
	if contact_damage <= 0.0 or contact_range <= 0.0:
		return false
	if is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion():
		return false
	return not _is_paused()

## One tick of damage to everything of the attacking side within reach. Public so a
## test can drive a tick without waiting on the clock.
##
## Reach is measured in 3D, so something well above the stakes is already out of
## range. That is not the same as handling flyers properly: when the pterosaur
## finally flies (see the v0.x roadmap -- it is meant to ignore ground walls
## entirely), it needs a flag of its own here, not an altitude coincidence.
func damage_touching_dinos() -> int:
	if not is_inside_tree():
		return 0
	var hit_count: int = 0
	for d in get_tree().get_nodes_in_group("dinos"):
		if not _is_contact_target(d):
			continue
		if global_position.distance_to((d as Node3D).global_position) <= contact_range:
			d.take_damage(contact_damage)
			hit_count += 1
	return hit_count

func _is_contact_target(target: Variant) -> bool:
	if target == null or typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return false
	if not (target is Node3D) or target.is_queued_for_deletion() or not target.is_inside_tree():
		return false
	if "is_dead" in target and target.is_dead:
		return false
	if "current_hp" in target and target.current_hp <= 0.0:
		return false
	return target.has_method("take_damage")

## Damage per second while something is against the stakes. The single place that
## figure is worked out: the build menu and the tests both read it from here.
func contact_dps() -> float:
	if contact_tick <= 0.0:
		return 0.0
	return contact_damage / contact_tick

func _is_paused() -> bool:
	var gs = _get_game_state()
	return gs != null and "is_paused" in gs and bool(gs.is_paused)

# ==============================================================================
# Presentation
# ==============================================================================

## Appends the stakes' bite to the usual HP line, so a player who selects a stake
## can see why it is worth planting rather than having to infer it from corpses.
func get_display_info() -> Dictionary:
	var info: Dictionary = super.get_display_info()
	info["contact_dps"] = contact_dps()
	if is_constructed and contact_dps() > 0.0:
		var suffix: String = tr("STATUS_CONTACT_DAMAGE")
		if "%" in suffix:
			info["status"] = "%s  ·  %s" % [info.get("status", ""), suffix % contact_dps()]
	return info
