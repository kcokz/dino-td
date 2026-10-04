# res://scripts/entities/Catapult.gd
class_name Catapult
extends "res://scripts/entities/AmmoTower.gd"

## 投石塔 THE CATAPULT (Config.BUILDINGS kind "thrower"; GAME-DESIGN 3.0 -- the player: "投石干脆和滚木都做成一个圈内都
## 能进攻，然后基座模型一样大"): a small throwing engine on a turntable on the towers' plinth (tools/generate_props.py
## catapult: the Turn it aims with, its Arm, a Stone in the cup, a Pile of shots on the deck). It throws all round it,
## at the ground between `min_range` and `range` metres from its middle -- too close in, the arm cannot bring a shot
## down -- turning to where most of them are: the animal with the most others within the shot's `splash` of it. The arm
## swings, the shot flies in an arc (Projectile) and comes down `flight_seconds` later where that animal was, and
## everything within its splash is hit and knocked down (Config.AMMO). It crushes: the armoured take all of it. What
## has run on is not where the stone falls -- it is for a crowd. Not what flies. A throw every `throw_seconds`.

## Seconds before it can throw again.
var cooldown: float = 0.0
## The arm at its padded stop, as the model has it -- where a throw ends; loaded, it is wound back from there
## (Config.TOWERS.catapult_wound_degrees, about its axle's X).
var _arm_rest: Vector3 = Vector3.INF
## Where it is turning to throw at, and how long until it faces it (Vector3.INF: not turning).
var _aim_at: Vector3 = Vector3.INF
var _aim_left: float = 0.0

func _number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.BUILDINGS.get(building_type, {}).get(key, fallback)) if (cfg and "BUILDINGS" in cfg) else fallback

## How far it throws, in metres from its middle; and how near is too near to bring a shot down.
func reach() -> float:
	return _number("range", 9.0)

func min_reach() -> float:
	return _number("min_range", 3.0)

## Its ring, picked and as a ghost (Building's coverage ring): as far as it throws. The ground too near to throw at
## is told by its own ring inside it (_show_zone).
func _get_display_range() -> float:
	return reach()

## Too near to throw at, picked (AmmoTower.set_range_visible): a dimmer ring inside its reach.
func _show_zone() -> bool:
	var disc := CylinderMesh.new()
	disc.top_radius = min_reach()
	disc.bottom_radius = min_reach()
	disc.height = 0.03
	var zone: MeshInstance3D = _zone_mesh(disc)
	zone.global_position = global_position + Vector3(0.0, 0.06, 0.0)
	var mat := zone.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(0.0, 0.0, 0.0, 0.25)
	return true

## It sees as far as it throws.
func sight_radius() -> float:
	return reach()

## The animals on the ground it can throw at: seen (AmmoTower.can_see), between its least and its most reach.
func animals_in_reach() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var here := Vector2(global_position.x, global_position.z)
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d) or flies(d) or not can_see(d):
			continue
		var at: Vector3 = (d as Node3D).global_position
		var gap: float = here.distance_to(Vector2(at.x, at.z))
		if gap >= min_reach() and gap <= reach():
			out.append(d)
	return out

## Where to throw: at the animal with the most of the others within its shot's splash -- the crowd's middle -- the
## nearer of two as crowded; Vector3.INF with nothing to throw at.
func aim_point() -> Vector3:
	var all: Array = animals_in_reach()
	if all.is_empty():
		return Vector3.INF
	var splash: float = float(ammo_row().get("splash", 1.8))
	var best: Vector3 = Vector3.INF
	var best_n: int = -1
	var best_gap: float = INF
	for d in all:
		var at: Vector3 = (d as Node3D).global_position
		var n: int = 0
		for e in all:
			var p: Vector3 = (e as Node3D).global_position
			if Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z)) <= splash:
				n += 1
		var gap: float = Vector2(at.x - global_position.x, at.z - global_position.z).length()
		if n > best_n or (n == best_n and gap < best_gap):
			best_n = n
			best_gap = gap
			best = at
	return best

func _physics_process(delta: float) -> void:
	if not _is_live():
		return
	cooldown = maxf(0.0, cooldown - delta)
	# Turning to what it chose (TOWERS.turn_seconds): it throws once it faces it.
	if _aim_at != Vector3.INF:
		_aim_left -= delta
		if _aim_left <= 0.0:
			var at: Vector3 = _aim_at
			_aim_at = Vector3.INF
			throw_at(at)
		return
	if cooldown > 0.0 or not has_ammo():
		return
	var target: Vector3 = aim_point()
	if target != Vector3.INF:
		_aim_at = target
		_aim_left = float(_towers("turn_seconds", 0.35))
		turn_to(target, _aim_left)

## Throws a shot where most of them are (aim_point). False with nothing to throw at, or no shot.
func throw() -> bool:
	var at: Vector3 = aim_point()
	return at != Vector3.INF and throw_at(at)

## Turns to `at` and throws a shot there. False with no shot in it.
func throw_at(at: Vector3) -> bool:
	var row: Dictionary = ammo_row()
	var model: Node3D = _flying_model()
	if not take_use():
		model.free()
		return false
	cooldown = _number("throw_seconds", 6.0)
	turn_to(at)
	var from: Vector3 = _release_point()
	var stone: Node3D = part("Stone")
	if stone != null:
		stone.visible = false
	_swing()
	var shot := Projectile.launch(get_parent(), model, from)
	shot.to = Vector3(at.x, global_position.y, at.z) + Vector3(0.0, 0.25, 0.0)
	shot.seconds = _number("flight_seconds", 1.3)
	shot.arc = float(_towers("throw_arc", 5.0))
	shot.points = false
	shot.spin = float(_towers("throw_spin", 1.5))
	shot.arrived = _land.bind(row)
	_sound("catapult_throw")
	return true

## The shot comes down at `at`: everything on the ground within its splash is hit and knocked flat a moment.
func _land(at: Vector3, row: Dictionary) -> void:
	if not is_inside_tree():
		return
	var reach: float = float(row.get("splash", 1.8))
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d) or flies(d):
			continue
		var p: Vector3 = (d as Node3D).global_position
		if Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z)) <= reach:
			strike(d, row)
			if AmmoTower.is_quarry(d) and d.has_method("hold_for"):
				d.hold_for(float(row.get("knockdown", 0.0)))
	# A fire pot breaks and the ground burns where it fell (FirePatch).
	if row.has("burn") and get_parent() != null:
		FirePatch.ignite(get_parent(), at, row)
	var fx = _get_fx()
	if fx and fx.has_method("play_at"):
		fx.play_at("stone_impact", at)
	if fx and fx.has_method("debris"):
		fx.debris(at, _towers("impact_debris", Color.SADDLE_BROWN))

## The arm at its padded stop (the model's own pose, taken the first time it is asked) and wound back from it.
func _stop() -> Vector3:
	var arm: Node3D = part("Arm")
	if _arm_rest == Vector3.INF and arm != null:
		_arm_rest = arm.rotation
	return _arm_rest if _arm_rest != Vector3.INF else Vector3.ZERO

func _wound() -> Vector3:
	return _stop() + Vector3(deg_to_rad(float(_towers("catapult_wound_degrees", 60.0))), 0.0, 0.0)

## Where the shot leaves the cup, in the world: the stone's place in the cup with the arm at its stop, where a throw
## ends. Worked out from the stop, so it is the same whether or not the swing is drawn.
func _release_point() -> Vector3:
	var arm: Node3D = part("Arm")
	var stone: Node3D = part("Stone")
	if arm == null or stone == null or not arm.is_inside_tree():
		return global_position + Vector3(0.0, _building_height(), 0.0)
	var holder: Node3D = arm.get_parent() as Node3D
	if holder == null:
		return stone.global_position
	return holder.to_global(arm.position + Basis.from_euler(_stop()) * stone.position)

## The arm is let go: forward to its stop, a moment there, and -- with shots left -- wound back, a stone in its cup.
func _swing() -> void:
	var arm: Node3D = part("Arm")
	if arm == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		_show_ammo()
		return
	var times: Array = _towers("swing_seconds", [0.18, 0.4, 0.5])
	var tw := arm.create_tween()
	tw.tween_property(arm, "rotation", _stop(), float(times[0]))
	tw.tween_interval(float(times[1]))
	if has_ammo():
		tw.tween_property(arm, "rotation", _wound(), maxf(float(times[2]), _number("throw_seconds", 6.0) * 0.5))
	tw.tween_callback(_show_ammo)

## Shots by it: wound back, a stone in its cup, while it has any -- seen from any side, a catapult ready to throw --
## and at its stop without; and the pile on its deck.
func _show_ammo() -> void:
	var arm: Node3D = part("Arm")
	if arm != null:
		arm.rotation = _wound() if has_ammo() else _stop()
	var stone: Node3D = part("Stone")
	if stone != null:
		stone.visible = has_ammo()
	var pile: Node3D = part("Pile")
	if pile != null:
		pile.visible = rounds() > 1
