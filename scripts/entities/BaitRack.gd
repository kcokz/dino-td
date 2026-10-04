# res://scripts/entities/BaitRack.gd
class_name BaitRack
extends "res://scripts/entities/AmmoTower.gd"

## 诱饵台 THE BAIT RACK (Config.BUILDINGS kind "bait"; GAME-DESIGN 3.0 -- the player: "诱引建筑感觉逻辑有点复杂，恐龙如果
## 全部凑上去显得太厉害了，而且容易出bug，有什么简化的方法吗"): raw meat hung on a drying rack on the towers' plinth
## (tools/generate_props.py bait_rack: Meat0..Meat3). It draws nothing to it and shoots nothing. What eats meat
## (Config.BAIT.eaters, by habit) and passes within `range` metres of its middle stops and eats for BAIT.eat_seconds --
## a bite of the meat -- and then goes on; once each (EATEN_META). So it holds a raid on its way, a few seconds an
## animal, where the other towers can get at it, as long as the meat lasts: a piece is AMMO.food.uses bites. Its meat
## is smelled, not seen: it holds them in the dark as well. Loaded with raw meat from the stock.

const BAIT_GROUP: String = "bait_racks"
## Set on an animal that has eaten at a rack: it does not stop for meat again.
const EATEN_META: StringName = &"ate_at_rack"

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

## Each step: what eats meat and has not, within its reach, stops and eats -- a bite of its meat each.
func _physics_process(_delta: float) -> void:
	if not has_meat() or not is_inside_tree():
		return
	var here := Vector2(global_position.x, global_position.z)
	for d in get_tree().get_nodes_in_group("dinos"):
		if not has_meat():
			return
		if not BaitRack.would_eat(d):
			continue
		var at: Vector3 = (d as Node3D).global_position
		if here.distance_to(Vector2(at.x, at.z)) <= reach():
			feed(d)

## Whether `d` would stop for meat: alive, on the ground, of a kind that eats it (Config.takes_bait), not yet eaten.
static func would_eat(d: Node) -> bool:
	if not AmmoTower.is_quarry(d) or (d as Node).has_meta(EATEN_META):
		return false
	if d.has_method("is_flying") and d.is_flying():
		return false
	var cfg = (d as Node).get_node_or_null("/root/Config")
	return cfg != null and cfg.has_method("takes_bait") and bool(cfg.takes_bait(String(d.dino_type)))

## `eater` stops and eats a bite of its meat (Config.BAIT.eat_seconds), and does not stop for meat again. False with
## none left.
func feed(eater: Node) -> bool:
	if not has_meat() or not take_use():
		return false
	if eater != null and is_instance_valid(eater):
		eater.set_meta(EATEN_META, true)
		var cfg = _get_config()
		var bait: Dictionary = cfg.BAIT if (cfg and "BAIT" in cfg) else {}
		if eater.has_method("eat_for"):
			eater.eat_for(float(bait.get("eat_seconds", 3.0)), global_position)
	return true

## Meat on the rack, as much as it has.
func _show_ammo() -> void:
	_show_share("Meat", 4)
