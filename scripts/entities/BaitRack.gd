# res://scripts/entities/BaitRack.gd
class_name BaitRack
extends "res://scripts/entities/AmmoTower.gd"

## 诱饵台 THE BAIT RACK (Config.BUILDINGS kind "bait"; GAME-DESIGN 6.0, the 2026-10-02 rebuild; the player: "诱饵台，
## 不错，但是需要大一点，中等高度"): raw meat hung on a drying rack (tools/generate_props.py bait_rack: Meat0..Meat3).
## It shoots nothing. What eats meat (Config.BAIT.eaters, by habit) within `range` metres of it goes to it and eats
## -- stood at it, a bite at a time, as it would bite anything -- until it is full (BAIT.bites_to_eat), and then
## goes on its way and does not turn for meat again a while (Dino: the bait). So a raid is held at one spot, where
## the other towers can get at it, as long as the meat lasts: a piece is AMMO.food.uses bites. Loaded with raw
## meat from the stock, as the towers are with what they shoot.

const BAIT_GROUP: String = "bait_racks"

func _ready() -> void:
	add_to_group(BAIT_GROUP)
	super._ready()

## How far round it the smell of it carries, in metres from its middle.
func reach() -> float:
	var cfg = _get_config()
	return float(cfg.BUILDINGS.get(building_type, {}).get("range", 12.0)) if (cfg and "BUILDINGS" in cfg) else 12.0

func _get_display_range() -> float:
	return reach()

## Whether it is worth going to: standing, finished, meat on it.
func has_meat() -> bool:
	return _is_live() and has_ammo()

## A bite of its meat, eaten by `eater`. False with none left.
func feed(_eater: Node) -> bool:
	if not has_meat():
		return false
	return take_use()

## The nearest rack with meat on it within its reach of `at` -- or null. Asked by an animal that eats meat (Dino).
static func nearest_with_meat(tree: SceneTree, at: Vector3) -> Node3D:
	if tree == null:
		return null
	var best: Node3D = null
	var best_d: float = INF
	for r in tree.get_nodes_in_group(BAIT_GROUP):
		if not is_instance_valid(r) or not r.has_method("has_meat") or not r.has_meat():
			continue
		var p: Vector3 = (r as Node3D).global_position
		var d: float = Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z))
		if d <= float(r.reach()) and d < best_d:
			best_d = d
			best = r as Node3D
	return best

## Meat on the rack, as much as it has.
func _show_ammo() -> void:
	_show_share("Meat", 4)
