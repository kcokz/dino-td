# res://scripts/entities/CellTrap.gd
class_name CellTrap
extends "res://scripts/entities/Building.gd"

## THE TRAPS LAID IN THE WAY (GAME-DESIGN 6.0 rule 3: 刺、砸、困; v0.6 round six, the player: "防御太单调，木头石头
## 都是bow（而且bow不是很flexible，如果前方被墙挡住了就不能进攻）"). On the ground of one cell and in nobody's way
## (Config.walk_over): what walks onto it is what it takes, and no wall in front of it stops it.
##
##   spikes    (BUILDINGS kind "spikes": ground_spikes, bone_spikes) -- whatever steps on it is stabbed as it steps
##             on (`damage`) and goes at `slow` of its pace while it is on it; every stab blunts it (`wear` of its
##             hit points), mended at its price. Always set: the answer to what is too quick for a bow.
##   deadfall  (kind "deadfall": log_deadfall, stone_deadfall) -- the first thing to walk under it brings the
##             weight down on everything in its cell (`damage`), whatever it is: the answer to the big and the
##             armoured. Propped again over `rearm_seconds`, the weight seen rising about its foot.
##   snare     (kind "snare": grass_snare, hide_snare) -- the first thing to step in is caught and held where it
##             stands (`hold_seconds`; a boss `boss_hold_seconds`, which may be none), the sapling seen springing
##             up; set again over `rearm_seconds` once it lets go. The answer to what has to be made to stand
##             still: on a bow's lane.
##
## The Hero walks over his own: he knows where he set them (Trap.gd: "人不会踩响自己的绊索"). Nothing hunts
## them (Dino._is_target_valid): an animal does not see a trap for a thing to bite.

## Whether it will take the next thing that walks onto it; seconds until it is set again.
var armed: bool = true
var rearm_left: float = 0.0
## What is on it now, by instance id: a stab, a fall, a catch is once a stepping-on.
var _on_it: Dictionary = {}
## The part that moves -- the deadfall's Weight, the snare's Sapling -- and its pose when set.
var _mover: Node3D = null
var _mover_set: Basis = Basis.IDENTITY

func _ready() -> void:
	super._ready()
	_find_parts()
	_show_set(1.0)

func _row() -> Dictionary:
	var cfg = _get_config()
	return cfg.BUILDINGS.get(building_type, {}) if (cfg and "BUILDINGS" in cfg) else {}

func _number(key: String, fallback: float) -> float:
	return float(_row().get(key, fallback))

func _kind() -> String:
	return String(_row().get("kind", ""))

func _traps(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.TRAPS.get(key, fallback)) if (cfg and "TRAPS" in cfg) else fallback

# ==============================================================================
# What walks onto it
# ==============================================================================

func _physics_process(delta: float) -> void:
	if is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion():
		return
	if not armed:
		rearm_left = maxf(0.0, rearm_left - delta)
		var rearm: float = maxf(0.01, _number("rearm_seconds", 6.0))
		_show_set(1.0 - clampf(rearm_left / rearm, 0.0, 1.0))
		if rearm_left <= 0.0:
			armed = true
			_show_set(1.0)
			_update_info_label()
	var now_on: Dictionary = {}
	var fresh: Array = []
	for animal in animals_on_it():
		var id: int = (animal as Object).get_instance_id()
		now_on[id] = true
		if not _on_it.has(id):
			fresh.append(animal)
		if _kind() == "spikes" and animal.has_method("slow_for"):
			animal.slow_for(_number("slow", 0.5), _traps("slow_linger", 0.25))
	_on_it = now_on
	if fresh.is_empty():
		return
	match _kind():
		"spikes":
			for animal in fresh:
				stab(animal)
		"deadfall":
			if armed:
				drop()
		"snare":
			if armed:
				catch(fresh[0])

## Every animal whose middle is on its cell -- the cell, and TRAPS.cell_reach past its edge: a foot is
## ahead of a middle.
func animals_on_it() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var cfg = _get_config()
	var half: float = (float(cfg.BUILD_CELL) if (cfg and "BUILD_CELL" in cfg) else 1.0) * 0.5 + _traps("cell_reach", 0.2)
	var here: Vector3 = global_position
	for d in get_tree().get_nodes_in_group("dinos"):
		if not (d is Node3D) or not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		if ("is_dead" in d and d.is_dead) or not d.has_method("take_damage"):
			continue
		var at: Vector3 = (d as Node3D).global_position
		if absf(at.x - here.x) <= half and absf(at.z - here.z) <= half:
			out.append(d)
	return out

## Spikes: it is stabbed, and they are the blunter for it.
func stab(animal: Node) -> void:
	animal.take_damage(_number("damage", 0.6))
	var wear: float = _number("wear", 1.0)
	if wear > 0.0:
		take_damage(wear)

## A deadfall: the weight comes down on everything on it.
func drop() -> int:
	var hit: int = 0
	for animal in animals_on_it():
		animal.take_damage(_number("damage", 2.5))
		hit += 1
	_spring()
	_sound("trap_thud")
	return hit

## A snare: `animal` is held where it stands -- a boss as long as the cord holds one, which may be not
## at all -- and the snare is set again once it lets go.
func catch(animal: Node) -> void:
	var hold: float = _number("boss_hold_seconds", 0.0) if _is_boss(animal) else _number("hold_seconds", 2.5)
	if hold > 0.0 and animal.has_method("hold_for"):
		animal.hold_for(hold)
	_spring(hold)
	_sound("trap_snap")

func _spring(extra: float = 0.0) -> void:
	armed = false
	rearm_left = maxf(0.0, extra) + _number("rearm_seconds", 6.0)
	_show_set(0.0)
	_update_info_label()

func _is_boss(animal: Node) -> bool:
	var cfg = _get_config()
	if cfg == null or not ("dino_type" in animal) or not cfg.DINOS.has(String(animal.dino_type)):
		return false
	return String(cfg.DINOS[String(animal.dino_type)].get("boss", "")) != ""

# ==============================================================================
# Its body: the part that moves
# ==============================================================================

func _find_parts() -> void:
	var body: Node = get_node_or_null("Body")
	_mover = null
	if body == null:
		return
	for part in ["Weight", "Sapling"]:
		var found: Node3D = body.find_child(part, true, false) as Node3D
		if found != null:
			_mover = found
			_mover_set = found.transform.basis
			return

## How far set it is, 0 sprung to 1 set, shown on the model: the deadfall's weight turned down about its
## foot and raised again, the snare's sapling sprung up and bent down again -- `swing_degrees` about the
## axis BUILDINGS says (`swing_axis`), from its pose as set.
func _show_set(t: float) -> void:
	if _mover == null or not is_instance_valid(_mover):
		_find_parts()
	if _mover == null:
		return
	var axis: Vector3 = _row().get("swing_axis", Vector3(0.0, 0.0, 1.0))
	var swing: float = deg_to_rad(_number("swing_degrees", 0.0)) * (1.0 - clampf(t, 0.0, 1.0))
	_mover.transform.basis = _mover_set * Basis(axis.normalized(), swing)

## Upgraded to a different model: its moving part found again on it, shown as set as it is.
func _rebuild_body(old_type: String) -> void:
	super._rebuild_body(old_type)
	_find_parts()
	var rearm: float = maxf(0.01, _number("rearm_seconds", 6.0))
	_show_set(1.0 if armed else 1.0 - clampf(rearm_left / rearm, 0.0, 1.0))

# ==============================================================================
# Presentation
# ==============================================================================

## Set and waiting, or being set again and for how long. Spikes are always set.
func _panel_status() -> String:
	if not is_constructed or _kind() == "spikes":
		return ""
	if armed:
		return tr("STATUS_TRAP_ARMED")
	var raw: String = tr("STATUS_TRAP_REARMING")
	return (raw % rearm_left) if "%" in raw else raw

func get_display_info() -> Dictionary:
	var info: Dictionary = super.get_display_info()
	info["armed"] = armed
	info["rearm_left"] = rearm_left
	return info
