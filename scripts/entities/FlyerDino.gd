# res://scripts/entities/FlyerDino.gd
class_name FlyerDino
extends "res://scripts/entities/Dino.gd"

## ON THE WING (Config.DINOS.<id>.flies, DINO_BEHAVIOURS "flyer"; GAME-DESIGN 7.2, station 2: "天上：小型喙嘴龙类……第一
## 次要对空"). A pterosaur that raids from the air. Walls are nothing to it: it flies over them, and nothing on the
## ground touches it -- not the spikes, not a stake's points, not a rolling log or a catapult's stone (AmmoTower.flies).
## Only the bow tower's arrows reach it up there, and the man's blows when it comes down to bite.
##
## It cruises at Config.DINO_AI.flight.cruise_height towards what it is after -- the cabin, the thing that fell into
## its valley (Dino._think); or, first, what has just attacked it: the bow tower that shot it, the man who struck at it
## -- comes down on it from `dive_reach` out, bites once when it is in its reach, and climbs away the way it was going
## for `climb_seconds` before it turns and comes round again: a swoop, not a stand -- so the man gets a blow in as it
## comes down, and towers a shot as it goes. Its way is a straight line through the air:
## no navigation mesh, no steering round the others. Hit by an arrow, it drops out of the sky where it was (die).

## Seconds left of climbing away after a bite; where it is climbing away to.
var _climb_left: float = 0.0
var _away: Vector3 = Vector3.ZERO

func _flight(key: String, fallback: float) -> float:
	var cfg = _get_config()
	if cfg == null or not ("DINO_AI" in cfg):
		return fallback
	return float((cfg.DINO_AI.get("flight", {}) as Dictionary).get(key, fallback))

## It bumps into nothing: over the walls and the buildings, through the others.
func _apply_collision_configuration() -> void:
	super._apply_collision_configuration()
	collision_mask = 0

## No agent: nobody steers round it, and it steers round nobody.
func _ensure_walker() -> void:
	pass

func walks_round_walls() -> bool:
	return false

## Whether it is in the air now (TwitchWatch leaves what flies alone: a swoop turns hard by its nature).
func is_flying() -> bool:
	return not is_dead

## Put down where a raid sets out: up in the air over it.
func setup(type_id: String = "raptor", stat_multipliers: Dictionary = {}) -> void:
	super.setup(type_id, stat_multipliers)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

func _ready() -> void:
	super._ready()
	if is_inside_tree():
		global_position.y = maxf(global_position.y, _flight("cruise_height", 3.5))

# ==============================================================================
# The flight
# ==============================================================================

func advance_towards_waypoint(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	_mind_clock += delta
	_think_clock -= delta
	_tick_traps(delta)
	if going_home:
		_fly_home(delta)
		return
	if _think_clock <= 0.0:
		_think_clock = _next_think()
		_choose()
	_bite_clock = maxf(0.0, _bite_clock - delta)
	if _climb_left > 0.0:
		_climb_left -= delta
		_fly_towards(_away, _flight("cruise_height", 3.5), delta)
		return
	var quarry: Node3D = current_target as Node3D if _is_target_valid(current_target) else null
	if quarry == null:
		_fly_towards(_journey_goal(), _flight("cruise_height", 3.5), delta)
		return
	var at: Vector3 = quarry.global_position
	var flat: float = Vector2(at.x - global_position.x, at.z - global_position.z).length()
	var height: float = _flight("cruise_height", 3.5)
	if flat <= _flight("dive_reach", 6.0):
		# Down on it: as low as its head, the nearer the lower.
		height = lerpf(_bite_height(quarry), height, clampf(flat / maxf(0.01, _flight("dive_reach", 6.0)), 0.0, 1.0))
	_fly_towards(at, height, delta)
	if flat <= attack_reach() + _half_width_of(quarry) and absf(global_position.y - _bite_height(quarry)) <= _flight("bite_slack", 0.8):
		_bite(quarry)

## Its hours over (Dino.go_home): back over everything to the nest, and gone there (EventBus.dino_went_home).
func _fly_home(delta: float) -> void:
	if waypoints.is_empty():
		return
	var nest: Vector3 = waypoints[waypoints.size() - 1]
	if Vector2(nest.x - global_position.x, nest.z - global_position.z).length() <= _ai("home_reach", 2.0):
		var eb = _get_event_bus()
		if eb and eb.has_signal("dino_went_home"):
			eb.dino_went_home.emit(self)
		queue_free()
		return
	_fly_towards(nest, _flight("cruise_height", 3.5), delta)

## What it is after now: what has just attacked it -- the bow tower that shot it (Dino._shot_lately), the man who
## struck at it (Dino._provoker) -- else the cabin. It hunted the man within eighteen metres before the cabin; since
## 2026-10-03 (the player: "对人，优先级低一些，优先攻击攻击它们的") he is the least of what it came for.
func _choose() -> void:
	if going_home:
		current_target = null
		return
	var at: Node = _shot_lately()
	if at == null:
		at = _provoker()
	if at != null and _is_target_valid(at):
		current_target = at
		return
	var cabin: Node = _cabin()
	current_target = cabin if _is_target_valid(cabin) else null

## How high its bite is: the middle of what it is biting.
func _bite_height(target: Node3D) -> float:
	var cfg = _get_config()
	var tall: float = 1.0
	if target.is_in_group("hero") and cfg and "HERO" in cfg:
		tall = float(cfg.HERO.get("height", 1.2))
	elif "building_type" in target and cfg and cfg.has_method("get_building_height"):
		tall = float(cfg.get_building_height(String(target.building_type)))
	return target.global_position.y + tall * 0.6

## A straight line through the air at its pace towards `goal`, at `height`, turning as it goes. Nowhere to go (no
## cabin, no target): it holds where it is, at its height.
func _fly_towards(goal: Vector3, height: float, delta: float) -> void:
	if not goal.is_finite():
		goal = global_position
	var want := Vector3(goal.x, height, goal.z)
	var off: Vector3 = want - global_position
	var pace: float = speed * _pace_factor()
	var step: float = pace * delta
	var move: Vector3 = off if off.length() <= step else off.normalized() * step
	# Up and down more gently than along: it glides down, it does not drop.
	move.y = clampf(off.y, -_flight("climb_rate", 2.5) * delta, _flight("climb_rate", 2.5) * delta)
	global_position += move
	velocity = move / maxf(delta, 0.0001)
	_turn_towards(off, delta)
	current_state = State.WALKING

func _pace_factor() -> float:
	return trap_pace if _slow_left > 0.0 else 1.0

## A bite, and away: on, past it, and up, for its climbing seconds.
func _bite(target: Node3D) -> void:
	if _bite_clock > 0.0:
		return
	_bite_clock = _bite_interval()
	current_state = State.ATTACKING
	if target.has_method("take_damage"):
		target.take_damage(_through_armour(target, damage))
	say("bite")
	var on: Vector3 = target.global_position - global_position
	on.y = 0.0
	if on.length_squared() < 0.0001:
		on = -global_transform.basis.z
	_away = global_position + on.normalized() * speed * _flight("climb_seconds", 2.0)
	_climb_left = _flight("climb_seconds", 2.0)

## Shoved by nothing: no log reaches it.
func knock_back(_by: Vector3, _seconds: float) -> void:
	pass

## Killed in the air, it falls where it was: its body comes down to the ground (Dino._leave_body lays it there).
func die() -> void:
	if is_inside_tree():
		global_position.y = 0.0
	super.die()
