# res://scripts/entities/CellTrap.gd
class_name CellTrap
extends "res://scripts/entities/Building.gd"

## 地刺 THE SPIKES LAID IN THE WAY (Config.BUILDINGS kind "spikes": ground_spikes, bone_spikes; GAME-DESIGN 6.0). On
## the ground of one cell and in nobody's way (Config.walk_over): whatever steps on it is stabbed as it steps on
## (`damage`) and goes at `slow` of its pace while it is on it; every stab blunts it (`wear` of its hit points),
## mended at its price. Always set -- nothing to re-arm, so nothing re-arms itself. Kept in the 2026-10-02 rebuild
## (the player: "地刺：暂时保留，和墙一样可以连着造，和camp fire一样，不会block"); the deadfall and the snare that were laid
## in the way beside it went, their jobs the log tower's and the bait rack's.
##
## The Hero walks over his own: he knows where he set them. Nothing hunts them (Dino._is_target_valid): an animal
## does not see a trap for a thing to bite.

## What is on it now, by instance id: a stab is once a stepping-on.
var _on_it: Dictionary = {}

func _row() -> Dictionary:
	var cfg = _get_config()
	return cfg.BUILDINGS.get(building_type, {}) if (cfg and "BUILDINGS" in cfg) else {}

func _number(key: String, fallback: float) -> float:
	return float(_row().get(key, fallback))

func _traps(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.TRAPS.get(key, fallback)) if (cfg and "TRAPS" in cfg) else fallback

func _physics_process(_delta: float) -> void:
	if is_destroyed or not is_constructed or current_hp <= 0.0 or is_queued_for_deletion():
		return
	var now_on: Dictionary = {}
	for animal in animals_on_it():
		var id: int = (animal as Object).get_instance_id()
		now_on[id] = true
		if animal.has_method("slow_for"):
			animal.slow_for(_number("slow", 0.5), _traps("slow_linger", 0.25))
		if not _on_it.has(id):
			stab(animal)
	_on_it = now_on

## Every animal whose middle is on its cell -- the cell, and TRAPS.cell_reach past its edge: a foot is ahead of a
## middle.
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
		# What flies is over them (FlyerDino).
		if d.has_method("is_flying") and d.is_flying():
			continue
		var at: Vector3 = (d as Node3D).global_position
		if absf(at.x - here.x) <= half and absf(at.z - here.z) <= half:
			out.append(d)
	return out

## It is stabbed, and the spikes are the blunter for it.
func stab(animal: Node) -> void:
	animal.take_damage(_number("damage", 2.4))
	var wear: float = _number("wear", 1.0)
	if wear > 0.0:
		take_damage(wear)
