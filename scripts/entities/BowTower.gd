# res://scripts/entities/BowTower.gd
class_name BowTower
extends "res://scripts/entities/AmmoTower.gd"

## 弩塔 THE BOW TOWER (Config.BUILDINGS kind "bow"; GAME-DESIGN 6.0, the 2026-10-02 rebuild): a platform on four legs
## with eight bows round its edge, one to each point of the compass (tools/generate_props.py bow_tower: Bow0..Bow7
## from north round by east, an Arrow0..Arrow7 nocked on each). Whatever is within `range` metres of its middle --
## on the ground or in the air -- the bow facing it shoots, an arrow every `fire_seconds` while it has arrows; the
## arrow flies (Projectile) and hits where it gets to: what it does is the arrow's (Config.AMMO). Nothing on it turns
## to aim -- the player: "弩塔八面是造型，但实际上范围就是一个圆圈内的都射的到……做出来的动画效果不能像箭塔就行":
## a ring of bows, the one facing it let go, its arrow gone off the string a moment and nocked again.

## Seconds before it can shoot again.
var cooldown: float = 0.0
## Seconds each bow has still to show without its arrow, after it has shot (Config.TOWERS.renock_seconds).
var _renock: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

func _row_number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.BUILDINGS.get(building_type, {}).get(key, fallback)) if (cfg and "BUILDINGS" in cfg) else fallback

## How far round its middle it reaches, in metres.
func reach() -> float:
	return _row_number("range", 7.0)

## It sees as far as it shoots.
func sight_radius() -> float:
	return reach()

func _get_display_range() -> float:
	return reach()

func _physics_process(delta: float) -> void:
	for i in _renock.size():
		if _renock[i] > 0.0:
			_renock[i] = maxf(0.0, _renock[i] - delta)
			if _renock[i] <= 0.0:
				var arrow: Node3D = part("Arrow%d" % i)
				if arrow != null:
					arrow.visible = has_ammo()
	if not _is_live():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0 or not has_ammo():
		return
	var t: Node3D = target_in_reach()
	if t != null:
		loose_at(t)

## The nearest animal within its reach (flat, from its middle), on the ground or in the air -- or null.
func target_in_reach() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d: float = reach()
	var here := Vector2(global_position.x, global_position.z)
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d):
			continue
		var at: Vector3 = (d as Node3D).global_position
		var gap: float = here.distance_to(Vector2(at.x, at.z))
		if gap <= best_d:
			best_d = gap
			best = d as Node3D
	return best

## Which of its eight bows faces `point`: 0 north, round by east.
func bow_facing(point: Vector3) -> int:
	var off: Vector3 = point - global_position
	var bearing: float = atan2(off.x, -off.z)
	return posmod(int(round(bearing / (PI * 0.25))), 8)

## Lets an arrow go at `target` from the bow facing it. False with no arrow to let go.
func loose_at(target: Node3D) -> bool:
	if not AmmoTower.is_quarry(target):
		return false
	var row: Dictionary = ammo_row()
	var model: Node3D = _flying_model()
	if not take_use():
		model.free()
		return false
	cooldown = _row_number("fire_seconds", 1.5)
	var i: int = bow_facing(target.global_position)
	var bow: Node3D = part("Bow%d" % i)
	var arrow: Node3D = part("Arrow%d" % i)
	var from: Vector3 = (arrow.global_position if arrow != null else (bow.global_position if bow != null
		else global_position + Vector3(0.0, _building_height() * 0.8, 0.0)))
	if arrow != null:
		arrow.visible = false
	_renock[i] = float(_towers("renock_seconds", 0.6))
	_recoil(bow)
	var shot := Projectile.launch(get_parent(), model, from)
	shot.target = target
	shot.aim_height = _aim_height(target)
	shot.speed = float(_towers("arrow_speed", 24.0))
	var dir: Vector3 = target.global_position - global_position
	dir.y = 0.0
	shot.arrived = _arrive.bind(target, row, dir.normalized())
	_sound("bow_loose")
	return true

## Half way up `target`'s body: where an arrow is aimed.
func _aim_height(target: Node3D) -> float:
	var cfg = _get_config()
	if cfg == null or not ("dino_type" in target):
		return 0.0
	return float(cfg.get_visual_size("dino/" + String(target.dino_type)).y) * 0.5

## The arrow comes down at `at`: it hits what it was let go at, if it is there -- and a bone point goes on through
## the next behind it (AMMO "pierce": so many in all, in a line along its flight, within a stride of it).
func _arrive(at: Vector3, target: Node, row: Dictionary, dir: Vector3) -> void:
	var hit_first: bool = AmmoTower.is_quarry(target) and Vector2(at.x, at.z).distance_to(
		Vector2((target as Node3D).global_position.x, (target as Node3D).global_position.z)) <= float(_towers("arrow_hit_reach", 1.2))
	if hit_first:
		strike(target, row)
	var more: int = int(row.get("pierce", 1)) - 1
	if more <= 0 or not is_inside_tree():
		return
	var behind: Array = []
	var reach_on: float = float(_towers("pierce_reach", 3.0))
	var reach_aside: float = float(_towers("pierce_aside", 0.6))
	for d in get_tree().get_nodes_in_group("dinos"):
		if d == target or not AmmoTower.is_quarry(d):
			continue
		var off: Vector3 = (d as Node3D).global_position - at
		off.y = 0.0
		var along: float = off.dot(dir)
		var aside: float = (off - dir * along).length()
		if along > 0.0 and along <= reach_on and aside <= reach_aside:
			behind.append([along, d])
	behind.sort_custom(func(a, b): return a[0] < b[0])
	for k in mini(more, behind.size()):
		strike(behind[k][1], row)

## The bow that shot shudders: a quick shake of its limbs, out and back, as a bow does let go (its arrow's absence
## shows the rest -- _renock).
func _recoil(bow: Node3D) -> void:
	if bow == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var rest: Vector3 = bow.scale
	var tw := bow.create_tween()
	tw.tween_property(bow, "scale", rest * Vector3(1.0, 1.0, 0.9), float(_towers("renock_seconds", 0.6)) * 0.1)
	tw.tween_property(bow, "scale", rest, float(_towers("renock_seconds", 0.6)) * 0.4)

## Arrows on it: the quiver shows while it has any, and each bow's arrow nocked.
func _show_ammo() -> void:
	var quiver: Node3D = part("Quiver")
	if quiver != null:
		quiver.visible = has_ammo()
	for i in 8:
		var arrow: Node3D = part("Arrow%d" % i)
		if arrow != null and _renock[i] <= 0.0:
			arrow.visible = has_ammo()
