# res://scripts/entities/Catapult.gd
class_name Catapult
extends "res://scripts/entities/AmmoTower.gd"

## 投石塔 THE CATAPULT (Config.BUILDINGS kind "thrower"; GAME-DESIGN 6.0, the 2026-10-02 rebuild): a throwing arm
## through a twisted rope on a log frame (tools/generate_props.py catapult: the Arm, a Stone in its cup, a Pile of
## shots beside it). It throws at one patch of ground ahead of it -- `zone_distance` metres from its middle the way
## it faces, `zone_radius` metres round -- whenever something on the ground is in the patch and it has a shot: the
## arm swings up, the shot flies in an arc (Projectile) and comes down `flight_seconds` later in the middle of the
## patch, and everything within the shot's `splash` of where it lands is hit and knocked down (Config.AMMO). What
## has run on is not where the stone falls -- a patch, not a target: it is for a crowd, at a gap or on a wall. Not
## what flies. A throw every `throw_seconds`.

## Seconds before it can throw again.
var cooldown: float = 0.0
## The arm's rest, and how far it swings to throw (Config.TOWERS.catapult_swing_degrees, about its axle's X).
var _arm_rest: Vector3 = Vector3.INF

func _number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.BUILDINGS.get(building_type, {}).get(key, fallback)) if (cfg and "BUILDINGS" in cfg) else fallback

## The middle of the patch it throws at, on the ground.
func zone_centre() -> Vector3:
	var c: Vector3 = global_position + forward() * _number("zone_distance", 9.0)
	return Vector3(c.x, global_position.y, c.z)

func zone_radius() -> float:
	return _number("zone_radius", 2.0)

## It sees to the far side of its patch.
func sight_radius() -> float:
	return _number("zone_distance", 9.0) + zone_radius()

## The animals on the ground in its patch.
func animals_in_zone() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var c := Vector2(zone_centre().x, zone_centre().z)
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d) or flies(d):
			continue
		var at: Vector3 = (d as Node3D).global_position
		if c.distance_to(Vector2(at.x, at.z)) <= zone_radius():
			out.append(d)
	return out

func _physics_process(delta: float) -> void:
	if not _is_live():
		return
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0 or not has_ammo():
		return
	if not animals_in_zone().is_empty():
		throw()

## Throws a shot at its patch. False with none in it.
func throw() -> bool:
	var row: Dictionary = ammo_row()
	var model: Node3D = _flying_model()
	if not take_use():
		model.free()
		return false
	cooldown = _number("throw_seconds", 6.0)
	var from: Vector3 = _release_point()
	var stone: Node3D = part("Stone")
	if stone != null:
		stone.visible = false
	_swing()
	var shot := Projectile.launch(get_parent(), model, from)
	shot.to = zone_centre() + Vector3(0.0, 0.25, 0.0)
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

## Where the shot leaves the cup, in the world: the stone's place in the cup at rest, swung up with the arm about
## its axle as far as a throw swings it (Config.TOWERS.catapult_swing_degrees). Worked out from the arm at rest, so
## it is the same whether or not the swing is drawn.
func _release_point() -> Vector3:
	var arm: Node3D = part("Arm")
	var stone: Node3D = part("Stone")
	if arm == null or stone == null or not arm.is_inside_tree():
		return global_position + Vector3(0.0, _building_height(), 0.0)
	var holder: Node3D = arm.get_parent() as Node3D
	if holder == null:
		return stone.global_position
	var rest: Basis = Basis.from_euler(_arm_rest) if _arm_rest != Vector3.INF else arm.transform.basis
	var axle: Vector3 = arm.position
	var cup: Vector3 = holder.to_local(stone.global_position)
	var swing: float = deg_to_rad(float(_towers("catapult_swing_degrees", -96.0)))
	var turned: Vector3 = axle + (cup - axle).rotated(rest.x.normalized(), swing)
	return holder.to_global(turned)

## The arm swings up and over to throw, and is wound back down -- the stone in its cup again while it has shots.
func _swing() -> void:
	var arm: Node3D = part("Arm")
	if arm == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		_show_ammo()
		return
	if _arm_rest == Vector3.INF:
		_arm_rest = arm.rotation
	var swing: float = deg_to_rad(float(_towers("catapult_swing_degrees", -96.0)))
	var times: Array = _towers("swing_seconds", [0.18, 0.4, 0.5])
	var tw := arm.create_tween()
	tw.tween_property(arm, "rotation", _arm_rest + Vector3(swing, 0.0, 0.0), float(times[0]))
	tw.tween_interval(float(times[1]))
	tw.tween_property(arm, "rotation", _arm_rest, maxf(float(times[2]), _number("throw_seconds", 6.0) * 0.5))
	tw.tween_callback(_show_ammo)

## Shots by it: a stone in the cup and the pile, while it has any.
func _show_ammo() -> void:
	var stone: Node3D = part("Stone")
	if stone != null:
		stone.visible = has_ammo()
	var pile: Node3D = part("Pile")
	if pile != null:
		pile.visible = rounds() > 1
