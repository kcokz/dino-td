# res://scripts/entities/DropTower.gd
class_name DropTower
extends "res://scripts/entities/AmmoTower.gd"

## 落木塔 THE DROP TOWER (Config.BUILDINGS kind "drop"; GAME-DESIGN 3.0, in the log tower's place -- the player: "投石干脆和
## 滚木都做成一个圈内都能进攻，然后基座模型一样大"): a mast on the towers' plinth with a boom pinned across its head, as a
## well sweep's is (tools/generate_props.py drop_tower: the Turn it swings round on, the Boom it nods, the Load slung
## from its long end, a Pile of logs on the deck). Whatever on the ground it can see within `range` metres of its middle
## -- at its foot -- it swings round to (TOWERS.turn_seconds) and drops its log on, a drop every `drop_seconds`: the
## log comes down `fall_seconds` after the boom nods, and everything within the log's `splash` of where it lands is
## crushed (Config.AMMO: what the log is), knocked flat (`knockdown`) and shoved off away from the tower (`push`) --
## the heavy ones (DINOS.<id>.heavy) only by a log weighted with stone (`moves_heavy`). It crushes: the armoured take
## all of it. What it holds at its foot, the bow and the catapult can get at. Not what flies: a log falls, it does
## not fly up.

## Seconds before it can drop again.
var cooldown: float = 0.0
## Where it is swinging round to drop on, and how long until it faces it (Vector3.INF: not swinging).
var _aim_at: Vector3 = Vector3.INF
var _aim_left: float = 0.0
var _boom_rest: Vector3 = Vector3.INF

func _number(key: String, fallback: float) -> float:
	var cfg = _get_config()
	return float(cfg.BUILDINGS.get(building_type, {}).get(key, fallback)) if (cfg and "BUILDINGS" in cfg) else fallback

## How far round its middle it reaches, in metres.
func reach() -> float:
	return _number("range", 2.5)

func _get_display_range() -> float:
	return reach()

## It sees as far as it reaches.
func sight_radius() -> float:
	return reach()

## The nearest animal on the ground it can see within its reach, or null.
func target_in_reach() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d: float = reach()
	var here := Vector2(global_position.x, global_position.z)
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d) or flies(d) or not can_see(d):
			continue
		var at: Vector3 = (d as Node3D).global_position
		var gap: float = here.distance_to(Vector2(at.x, at.z))
		if gap <= best_d:
			best_d = gap
			best = d as Node3D
	return best

func _physics_process(delta: float) -> void:
	if not _is_live():
		return
	cooldown = maxf(0.0, cooldown - delta)
	# Swinging round to what it chose: it lets go once it faces it.
	if _aim_at != Vector3.INF:
		_aim_left -= delta
		if _aim_left <= 0.0:
			var at: Vector3 = _aim_at
			_aim_at = Vector3.INF
			drop_on(at)
		return
	if cooldown > 0.0 or not has_ammo():
		return
	var t: Node3D = target_in_reach()
	if t != null:
		_aim_at = t.global_position
		_aim_left = float(_towers("turn_seconds", 0.35))
		turn_to(_aim_at, _aim_left)

## Swings round to `at` and drops its log there. False with nothing to drop.
func drop_on(at: Vector3) -> bool:
	var row: Dictionary = ammo_row()
	var model: Node3D = _flying_model()
	if not take_use():
		model.free()
		return false
	cooldown = _number("drop_seconds", 2.5)
	turn_to(at)
	var where: Vector3 = Vector3(at.x, global_position.y, at.z)
	var load: Node3D = part("Load")
	var from: Vector3 = load.global_position if load != null else where + Vector3(0.0, _building_height(), 0.0)
	if load != null:
		load.visible = false
	_tip()
	var fall: float = _number("fall_seconds", 0.35)
	if not is_inside_tree() or fall <= 0.0:
		model.free()
		_land(where, row)
		return true
	var falling := Projectile.launch(get_parent(), model, from)
	falling.to = where + Vector3(0.0, float(_towers("log_radius", 0.14)), 0.0)
	falling.seconds = fall
	falling.arc = 0.0
	falling.points = false
	falling.spin = 0.6
	falling.arrived = _land.bind(row)
	_sound("log_roll")
	return true

## The log comes down at `at`: everything on the ground within its splash is crushed, knocked flat, and shoved off away
## from the tower -- the heavy ones only by a weighted log.
func _land(at: Vector3, row: Dictionary) -> void:
	if not is_inside_tree():
		return
	var splash: float = float(row.get("splash", 1.2))
	for d in get_tree().get_nodes_in_group("dinos"):
		if not AmmoTower.is_quarry(d) or flies(d):
			continue
		var p: Vector3 = (d as Node3D).global_position
		if Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z)) > splash:
			continue
		strike(d, row)
		if not AmmoTower.is_quarry(d):
			continue
		if d.has_method("hold_for"):
			d.hold_for(float(row.get("knockdown", 0.0)))
		if d.has_method("knock_back") and (bool(row.get("moves_heavy", false)) or not is_heavy(d)):
			var away := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
			if away.length_squared() < 0.0001:
				away = Vector3.FORWARD
			d.knock_back(away.normalized() * float(row.get("push", 1.5)), float(row.get("push_seconds", 0.35)))
	var fx = _get_fx()
	if fx and fx.has_method("play_at"):
		fx.play_at("stone_impact", at)
	if fx and fx.has_method("debris"):
		fx.debris(at, _towers("impact_debris", Color.SADDLE_BROWN))

## The boom nods its long end down to let the log go (TOWERS.drop_tip_degrees) and comes back up -- a log in its sling
## again while it has any.
func _tip() -> void:
	var boom: Node3D = part("Boom")
	if boom == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		_show_ammo()
		return
	if _boom_rest == Vector3.INF:
		_boom_rest = boom.rotation
	var tip: float = deg_to_rad(float(_towers("drop_tip_degrees", -14.0)))
	var times: Array = _towers("drop_tip_seconds", [0.15, 0.6])
	var tw := boom.create_tween()
	tw.tween_property(boom, "rotation", _boom_rest + Vector3(tip, 0.0, 0.0), float(times[0]))
	tw.tween_property(boom, "rotation", _boom_rest, float(times[1]))
	tw.tween_callback(_show_ammo)

## A log in its sling while it has any, and the pile on its deck.
func _show_ammo() -> void:
	var load: Node3D = part("Load")
	if load != null:
		load.visible = has_ammo()
	var pile: Node3D = part("Pile")
	if pile != null:
		pile.visible = rounds() > 1
