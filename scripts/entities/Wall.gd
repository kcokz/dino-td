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

# ==============================================================================
# Shape: there isn't any
# ==============================================================================
#
# This file used to hold an auto-tiling system: a stake asked its neighbours which way
# the fence ran and redrew itself as a line, an L or a cross, and the build preview
# asked the same question so the ghost would match. It was rebuilt four times and
# produced a new bug every time -- the last of them a blueprint showing five cones that
# became three once a neighbour went up.
#
# It is gone, and with it every function in this file that used to shape anything. ONE
# STAKE IS ONE CONE, whatever is beside it. The collider is the plain box the base class
# builds, so nothing here overrides anything.
#
# The trade that used to be recorded here is gone too. It read: the stake BLOCKS its
# whole tile and is DRAWN as one cone in the middle of it, and shrinking the footprint
# to match the cone "would mean a single stake stops nothing, which is a gameplay change
# nobody asked for". It was asked for, in the only way that counts -- as a bug. A plain
# gap between a stake and a hillside was solid, because the tile was claimed whether or
# not anything stood in the part you were walking through.
#
# So the stake is the size of the stake, and what closes a way is a RUN of them wide
# enough to cross a tile -- GridManager.occupant_leaves_a_way_through. That is the fence
# the player drew, which is the one that ought to stop him.

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
