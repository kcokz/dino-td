# res://scripts/entities/GuardDino.gd
class_name GuardDino
extends "res://scripts/entities/Dino.gd"

## A guard at the nest: it keeps to its post, goes for the Hero when he comes close, and goes
## home when he has led it too far.
##
## The same body as every dinosaur (Dino: the engine's walker, a body that collides, turning at
## a turning speed) with its own mind. The one before walked in a straight line with nothing to
## stop it -- through walls, into turrets -- and turned with look_at every frame; reported as
## "守卫恐龙攻击人之后，人开始逃跑，恐龙会追，追到一个地方就会回去，有的恐龙会回去，但有的会卡在一些
## 防御不动了，或者直接在防御的周围抽搐".
##
## The mind (GuardState):
##   POST_ROAM    about its post, a few steps at a time, at an amble (Config.NEST_GUARDS)
##   THREATENING  standing, facing the Hero, warning him off -- before any chase (threat_seconds)
##   AGGRO_CHASE  after the Hero, or a building put up by the nest, along the mesh
##   ATTACKING    standing at it, biting -- letting go only past its reach (reach_release)
##   RETURNING    home, deaf to him on the way, and settling a moment once there
##                (reaggro_seconds) before it will start after anyone again
##   SLEEPING     lying down about its post, out of its hours -- the Coelophysis's are the day's, so
##                the dusk and the night (Config.DINOS.<id>.hours) -- woken only by what is AT it:
##                the Hero right beside it (NEST_GUARDS.wake_within), a light on it (a fire's, his
##                torch: ProwlerDino.lights), a blow, the din of a wreck searched near it (wake).
##
## ASLEEP AT NIGHT (v0.6 round five, the player's choice: "夜里睡，靠太近或火光照到会醒" -- "举火把防植龙、
## 却会弄醒守卫，成了取舍"; the debug-agent's BUG-023: day and night the same, while the night's hint said
## the Coelophysis slept). Woken, it is up alone: a call does not wake a sleeping guard -- only what is at
## it -- so they come one at a time, the longer he stays the more. Up, it is a guard as by day, and lies
## down again once nothing has kept it up for a while (NEST_GUARDS.stay_up).
##
## A nest is defended by all its guards at once: the first to go for him calls, and the others
## come (_rally); one that is hurt goes for him too (take_damage). But they WARN before they come
## (v0.6 round four, the player's choice for the debug-agent's DOC-004): the first to see him inside
## its aggro_radius stands, faces him, snaps at the air and calls, and the guards of its nest turn to
## him too (_begin_threat). Backed off past the radius and a margin, he is let be; closer than
## threat_close, or striking one, or staying out the warning, and they all come.
##
## Every way out of a chase is a clean one, and none can bounce straight back:
##   * he is further from its post than its leash, or it is -- home;
##   * there is no way to him (a wall between them: NavMaps.is_reachable), or it has made no
##     headway at him for a while -- home;
##   * and a guard that cannot get home at all -- walled off from its post -- makes its post where
##     it stands rather than pushing at the wall for ever.

enum GuardState {
	POST_ROAM = 0,
	AGGRO_CHASE = 1,
	ATTACKING = 2,
	RETURNING = 3,
	THREATENING = 4,
	SLEEPING = 5
}

# ==============================================================================
# Configuration & Properties
# ==============================================================================
@export var post_radius: float = 3.0
@export var aggro_radius: float = 6.0
@export var leash_radius: float = 12.0

var guard_state: GuardState = GuardState.POST_ROAM
var post_position: Vector3 = Vector3.ZERO
var roam_target: Vector3 = Vector3.ZERO
var roam_timer: float = 0.0
var chase_target: Node3D = null
var guard_attack_timer: float = 0.0
## Seconds before it will take up a chase again, after coming home.
var _calm: float = 0.0
## Seconds of warning left (THREATENING), and of the snap at the air it warns with.
var _threat_left: float = 0.0
var _snap_left: float = 0.0
## Woken from its sleep and warning him off: the whole warning, however near he is (wake).
var _roused: bool = false
## Seconds it stays up, woken out of its hours, before it lies down again (NEST_GUARDS.stay_up).
var _up_for: float = 0.0

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init(p_type: String = "raptor") -> void:
	super(p_type)

func _ready() -> void:
	super._ready()
	if came_from == "":
		came_from = "guard"
	add_to_group("guard_dinos")
	add_to_group("enemies")
	_load_guard_config()
	if post_position == Vector3.ZERO:
		post_position = global_position
	roam_target = post_position

func _load_guard_config() -> void:
	var cfg = _get_config()
	if cfg and "NEST_GUARDS" in cfg and cfg.NEST_GUARDS is Dictionary:
		post_radius = float(cfg.NEST_GUARDS.get("post_radius", 3.0))
		aggro_radius = float(cfg.NEST_GUARDS.get("aggro_radius", 6.0))
		leash_radius = float(cfg.NEST_GUARDS.get("leash_radius", 12.0))

func setup_post(post_pos: Vector3) -> void:
	post_position = post_pos
	global_position = post_pos
	roam_target = post_pos

# ==============================================================================
# Physics Process & AI State Machine
# ==============================================================================

func _physics_process(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	var was_at: Vector3 = global_position
	_guard_step(delta)
	_report_pace(was_at, delta)

## A guard is not on its way to the cabin: a test driving it by the raid's step drives the guard.
func advance_towards_waypoint(delta: float) -> void:
	_guard_step(delta)

## One step of the guard: think when it is time to, then act. Public for a test to drive.
func _guard_step(delta: float) -> void:
	if is_dead or current_state == State.DEAD:
		return
	_calm = maxf(0.0, _calm - delta)
	_tick_traps(delta)
	# After somebody, or warning him off, or on its way home from it: up, and for a while after.
	if guard_state != GuardState.POST_ROAM and guard_state != GuardState.SLEEPING:
		_up_for = float(_guards().get("stay_up", 20.0))
	else:
		_up_for = maxf(0.0, _up_for - delta)
	_think_clock -= delta
	if _think_clock <= 0.0:
		_think_clock = _next_think()
		_guard_think()
	match guard_state:
		GuardState.POST_ROAM:
			_process_post_roam(delta)
		GuardState.AGGRO_CHASE:
			_process_aggro_chase(delta)
		GuardState.ATTACKING:
			_process_guard_attacking(delta)
		GuardState.RETURNING:
			_process_returning(delta)
		GuardState.THREATENING:
			_process_threatening(delta)
		GuardState.SLEEPING:
			_drive(Vector3.ZERO, delta, Vector3.INF)

## The decisions that are not the frame's business: whether to start after somebody, whether to
## give up.
func _guard_think() -> void:
	_unstack()
	match guard_state:
		GuardState.SLEEPING:
			if _its_hours():
				_get_up()
			elif _stirred():
				wake(get_tree().get_first_node_in_group("hero") as Node3D)
		GuardState.POST_ROAM:
			var threat: Node3D = _detect_threat()
			if threat != null:
				# The man is warned first; a building put up by the nest does not back off.
				if threat.is_in_group("hero"):
					_begin_threat(threat)
				else:
					_begin_chase(threat)
			elif not _its_hours() and _up_for <= 0.0 and not _stirred():
				# Not in a light, nor with him beside it: it would only be woken again at once.
				_lie_down()
		GuardState.THREATENING:
			if not _is_threat_valid(chase_target) or not _worth_chasing(chase_target) or not _can_get_at(chase_target):
				_stand_down()
			else:
				var gap: float = _nearest_warning_gap(chase_target)
				if gap > aggro_radius + float(_guards().get("calm_margin", 1.0)):
					_stand_down()
				elif (gap <= float(_guards().get("threat_close", 3.0)) and not _roused) or _threat_left <= 0.0:
					_begin_chase(chase_target)
		GuardState.AGGRO_CHASE, GuardState.ATTACKING:
			if not _is_threat_valid(chase_target) or not _worth_chasing(chase_target) \
					or global_position.distance_to(post_position) > leash_radius \
					or not _can_get_at(chase_target):
				_go_home()

func _begin_chase(threat: Node3D, call_the_others: bool = true) -> void:
	chase_target = threat
	current_target = threat
	_roused = false
	guard_state = GuardState.AGGRO_CHASE
	current_state = State.WALKING
	_headway_clock = 0.0
	_headway_from = global_position
	_stuck_count = 0
	if call_the_others:
		_alert()
		_rally(threat)

## Warns `threat` off: stands, faces him, snaps at the air, calls (Config.NEST_GUARDS.threat_seconds,
## threat_snap) -- and, the first to see him, turns the guards of its nest to him as well (answer_threat)
## and says so (EventBus.guards_warned: the HUD's hint, once a run).
func _begin_threat(threat: Node3D, call_the_others: bool = true) -> void:
	chase_target = threat
	current_target = null
	guard_state = GuardState.THREATENING
	_threat_left = float(_guards().get("threat_seconds", 2.0))
	_snap_left = float(_guards().get("threat_snap", 0.6))
	velocity = Vector3.ZERO
	current_state = State.ATTACKING      # the snap at the air: the bite clip, standing
	say("alert")
	if not call_the_others or not is_inside_tree():
		return
	var reach: float = float(_guards().get("rally_radius", 8.0))
	for g in get_tree().get_nodes_in_group("guard_dinos"):
		if g != self and is_instance_valid(g) and g.has_method("answer_threat") \
				and _flat(g.post_position).distance_to(_flat(post_position)) <= reach:
			g.answer_threat(threat)
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("guards_warned"):
		eb.guards_warned.emit(self)

## Another guard of its nest is warning `threat` off: it turns to him too -- if it is only about its
## post; one already after somebody, or on its way home, keeps to that.
func answer_threat(threat: Node3D) -> void:
	if is_dead or guard_state != GuardState.POST_ROAM:
		return
	if not _is_threat_valid(threat) or not _worth_chasing(threat):
		return
	_begin_threat(threat, false)

## How near `threat` is to the nearest of its nest's guards warning him, itself among them: the
## warning stands while he is inside any one's radius. Measured from itself alone, a guard turned to
## him by another -- farther off, not having seen him itself -- stood down the moment it turned.
func _nearest_warning_gap(threat: Node3D) -> float:
	var best: float = _flat(global_position).distance_to(_flat(threat.global_position))
	if not is_inside_tree():
		return best
	var reach: float = float(_guards().get("rally_radius", 8.0))
	for g in get_tree().get_nodes_in_group("guard_dinos"):
		if g == self or not is_instance_valid(g) or not ("guard_state" in g):
			continue
		if int(g.guard_state) == int(GuardState.THREATENING) and g.chase_target == threat 				and _flat(g.post_position).distance_to(_flat(post_position)) <= reach:
			best = minf(best, _flat(g.global_position).distance_to(_flat(threat.global_position)))
	return best

## He backed off: back to its post, settling a moment (reaggro_seconds) before it will warn again.
func _stand_down() -> void:
	chase_target = null
	current_target = null
	_roused = false
	guard_state = GuardState.POST_ROAM
	roam_timer = 0.0
	_calm = float(_guards().get("reaggro_seconds", 1.5))
	current_state = State.WALKING

## Standing its ground, facing him; the snap at the air played out, it stands.
func _process_threatening(delta: float) -> void:
	_threat_left -= delta
	if _snap_left > 0.0:
		_snap_left -= delta
		if _snap_left <= 0.0:
			current_state = State.WALKING
	var look: Vector3 = chase_target.global_position if _is_threat_valid(chase_target) else Vector3.INF
	_drive(Vector3.ZERO, delta, look, true)

## A NEST IS DEFENDED BY ALL ITS GUARDS AT ONCE (v0.6 round four: "初始人就能把守卫恐龙巢穴的小龙一个个
## 杀掉，人杀伤力这么强吗"). Each went for him only when he came inside its own aggro_radius, so he could
## draw them off one at a time and win every fight: a Coelophysis is three of his blows, and costs him
## under three of his ten hit points. Now the first to go for him calls, and the guards of its nest --
## posted within Config.NEST_GUARDS.rally_radius of its own post -- come too (answer_call).
func _rally(threat: Node3D) -> void:
	if not is_inside_tree():
		return
	var reach: float = float(_guards().get("rally_radius", 8.0))
	for g in get_tree().get_nodes_in_group("guard_dinos"):
		if g == self or not is_instance_valid(g) or not g.has_method("answer_call"):
			continue
		if _flat(g.post_position).distance_to(_flat(post_position)) <= reach:
			g.answer_call(threat)

## Another guard of its nest has called (_rally): after `threat` as well -- unless it is at somebody
## already, or he is beyond its own leash, or there is no way to him. A call is not its own noticing,
## so it answers even while settling after coming home (reaggro_seconds). Asleep, it does not hear it.
func answer_call(threat: Node3D) -> void:
	if is_dead or guard_state == GuardState.AGGRO_CHASE or guard_state == GuardState.ATTACKING \
			or guard_state == GuardState.SLEEPING:
		return
	if not _is_threat_valid(threat) or not _worth_chasing(threat) or not _can_get_at(threat):
		return
	_begin_chase(threat, false)

## Hurt while it is not after anyone -- struck while settling, or shot from outside its aggro_radius,
## or asleep: it goes for the Hero, if he is inside its leash and there is a way to him, and calls the
## others (those asleep sleep on: answer_call).
func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if is_dead or not is_inside_tree() or guard_state == GuardState.AGGRO_CHASE or guard_state == GuardState.ATTACKING:
		return
	if guard_state == GuardState.SLEEPING:
		_up_for = float(_guards().get("stay_up", 20.0))
		_get_up()
	var hero: Node3D = get_tree().get_first_node_in_group("hero") as Node3D
	if hero != null and _is_threat_valid(hero) and _worth_chasing(hero) and _can_get_at(hero):
		_begin_chase(hero)

# ==============================================================================
# Asleep
# ==============================================================================

## Whether it is its hours (Config.DINOS.<id>.hours): the Coelophysis's are the day's. Without a clock
## -- a level built without one -- always.
func _its_hours() -> bool:
	var gs = get_node_or_null("/root/GameState")
	var cfg = _get_config()
	if gs == null or cfg == null or not gs.has_method("day_part") or not cfg.has_method("keeps_hours"):
		return true
	return bool(cfg.keeps_hours(dino_type, String(gs.day_part())))

## Whether it is lying asleep.
func is_asleep() -> bool:
	return guard_state == GuardState.SLEEPING

## Out of its hours with nothing about: down where it is, about its post, still.
func _lie_down() -> void:
	chase_target = null
	current_target = null
	guard_state = GuardState.SLEEPING
	velocity = Vector3.ZERO
	current_state = State.SLEEPING

## Up, about its post again.
func _get_up() -> void:
	guard_state = GuardState.POST_ROAM
	roam_timer = 0.0
	current_state = State.WALKING

## Whether what is at it wakes it where it lies: the Hero right beside it (NEST_GUARDS.wake_within,
## middle to middle), or a light on it -- a fire's, or his torch (ProwlerDino.lights: the ones the
## phytosaurs keep out of).
func _stirred() -> bool:
	if not is_inside_tree():
		return false
	var hero: Node3D = get_tree().get_first_node_in_group("hero") as Node3D
	if hero != null and _is_threat_valid(hero) \
			and _flat(global_position).distance_to(_flat(hero.global_position)) <= float(_guards().get("wake_within", 2.0)):
		return true
	return not ProwlerDino.light_over(get_tree(), global_position).is_empty()

## Woken -- by the Hero beside it, a light on it, the din of a wreck searched near it: up for a while
## (NEST_GUARDS.stay_up), and, `by` the Hero where it can get at him, warning him off -- alone: the
## rest of its nest sleeps on. Nothing asleep, nothing to do.
##
## THE WHOLE WARNING, however near he is (the debug-agent's BUG-023: "叫醒的守卫不示威，直接扑"). A guard
## up and about comes at once for a man closer than NEST_GUARDS.threat_close -- he walked up to it -- but one
## woken where it lay is woken right beside him: the battery's wreck lies four metres behind the nest, and a
## guard roused by the din of its search bit without a warning, where by day the same guard stands, snaps and
## lets a man who backs off be. Woken, it stands and warns him off for its threat_seconds first: he stops and
## goes, and it lets him be; he searches on, or strikes it, and it comes (take_damage).
func wake(by: Node3D = null) -> void:
	if is_dead or guard_state != GuardState.SLEEPING:
		return
	_up_for = float(_guards().get("stay_up", 20.0))
	_get_up()
	if by != null and _is_threat_valid(by) and _worth_chasing(by) and _can_get_at(by):
		_begin_threat(by, false)
		_roused = true

func _go_home() -> void:
	chase_target = null
	current_target = null
	post_position = _reachable_home()
	guard_state = GuardState.RETURNING
	current_state = State.WALKING
	_headway_clock = 0.0
	_headway_from = global_position
	_stuck_count = 0

## About its post: a few steps somewhere near it, a pause, a few steps more.
func _process_post_roam(delta: float) -> void:
	roam_timer -= delta
	if roam_timer <= 0.0:
		# The run's dice: where a guard wanders is where a fight happens, so a seed has to
		# replay it (GameState.rng).
		var dice: RandomNumberGenerator = _dice()
		var roam: Dictionary = _guards()
		var every: Vector2 = roam.get("roam_seconds", Vector2(2.0, 4.0))
		roam_timer = dice.randf_range(every.x, every.y)
		var angle: float = dice.randf() * TAU
		var dist: float = dice.randf_range(float(roam.get("roam_min_distance", 0.5)), post_radius)
		roam_target = post_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		# Somewhere it can stand: a spot picked inside a rock was walked to the rock's edge and
		# stood at, turning this way and that (found by the twitch watch, v0.6 round four).
		var maps := _nav_maps()
		if maps != null and maps.is_ready():
			var on_mesh: Vector3 = maps.closest_point(roam_target, _map_kind())
			roam_target = Vector3(on_mesh.x, roam_target.y, on_mesh.z)
	if _flat(global_position).distance_to(_flat(roam_target)) > float(_guards().get("roam_reach", 0.8)):
		_travel(roam_target, delta, float(_guards().get("roam_pace", 0.4)))
	else:
		_drive(Vector3.ZERO, delta, Vector3.INF)

## After him, along the mesh. In reach, it stands and bites; getting nowhere at him for a while (a
## crowd at a gap, a corner it cannot get round), it gives up and goes home.
func _process_aggro_chase(delta: float) -> void:
	if not _is_threat_valid(chase_target):
		_go_home()
		return
	if _target_in_reach(chase_target):
		guard_state = GuardState.ATTACKING
		current_state = State.ATTACKING
		guard_attack_timer = _bite_interval() * 0.5
		velocity = Vector3.ZERO
		return
	_travel(chase_target.global_position, delta)
	if _made_no_headway(delta):
		_go_home()

## Standing at him, biting, facing him -- letting go only when he is past its reach by a margin
## (Config.DINO_AI.reach_release), so a step back is not an escape and it does not take hold and
## let go on alternate frames.
func _process_guard_attacking(delta: float) -> void:
	velocity = Vector3.ZERO
	_avoid(Vector3.ZERO)
	if not _is_threat_valid(chase_target):
		_go_home()
		return
	if not _target_in_reach(chase_target, _ai("reach_release", 0.35)):
		guard_state = GuardState.AGGRO_CHASE
		current_state = State.WALKING
		return
	_turn_towards(chase_target.global_position - global_position, delta)
	guard_attack_timer -= delta
	if guard_attack_timer <= 0.0:
		guard_attack_timer += _bite_interval()
		if chase_target.has_method("take_damage"):
			chase_target.take_damage(damage)

## Home, deaf to him on the way. Home is its post; one it cannot get back to any more -- walled off
## from it -- becomes where it stands, rather than something to push at for ever.
func _process_returning(delta: float) -> void:
	if _flat(global_position).distance_to(_flat(post_position)) <= maxf(0.4, post_radius * 0.5):
		guard_state = GuardState.POST_ROAM
		roam_timer = 0.0
		_calm = float(_guards().get("reaggro_seconds", 1.5))
		velocity = Vector3.ZERO
		return
	_travel(post_position, delta)
	if _made_no_headway(delta) and _stuck_count >= 2:
		post_position = global_position
		roam_target = global_position

## Where it can get to that is nearest its post: the post itself -- or, walled off from it by
## something put up since, the end of the way towards it, which becomes its post. Going home to a
## post inside a fence is standing at the fence for ever.
func _reachable_home() -> Vector3:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready() or not is_inside_tree():
		return post_position
	if maps.is_reachable(global_position, post_position, _map_kind()):
		return post_position
	var route: PackedVector3Array = maps.path(global_position, post_position, _map_kind())
	if route.is_empty():
		return post_position
	var end: Vector3 = route[route.size() - 1]
	return Vector3(end.x, post_position.y, end.z)

## Whether a whole headway window (Config.DINO_AI.stuck_window) has passed with nowhere got.
## Counts the windows in a row.
func _made_no_headway(delta: float) -> bool:
	if _headway_from == Vector3.INF:
		_headway_from = global_position
	_headway_clock += delta
	if _headway_clock < _ai("stuck_window", 1.2):
		return false
	var moved: float = _flat(global_position).distance_to(_flat(_headway_from))
	_headway_clock = 0.0
	_headway_from = global_position
	if moved >= _ai("stuck_distance", 0.25):
		_stuck_count = 0
		return false
	_stuck_count += 1
	return true

# ==============================================================================
# Threat Detection & Validity
# ==============================================================================

## The Hero near enough and worth it, or a building put up too near the nest -- or nothing, while
## it is settling after coming home.
func _detect_threat() -> Node3D:
	if not is_inside_tree() or _calm > 0.0:
		return null

	for h in get_tree().get_nodes_in_group("hero"):
		if h is Node3D and _is_threat_valid(h) and _worth_chasing(h):
			if global_position.distance_to(h.global_position) <= aggro_radius and _can_get_at(h):
				return h

	var share: float = float(_guards().get("building_aggro_share", 0.7))
	for b in get_tree().get_nodes_in_group("buildings"):
		# What is stepped over is nothing it sees to go for (Dino._is_walk_over): a campfire, a trap laid in the way.
		if "building_type" in b and _is_walk_over(b):
			continue
		if b is Node3D and _is_threat_valid(b) and _worth_chasing(b) \
				and ("is_constructed" in b and b.is_constructed):
			if global_position.distance_to(b.global_position) <= aggro_radius * share:
				return b

	return null

## A GUARD DOES NOT TAKE UP A CHASE IT MUST IMMEDIATELY ABANDON.
##
## Aggro is measured from the guard and the leash from its post; without this the two disagree at
## the edge and a guard alternates between them -- "守卫恐龙追着人跑了一段之后停下不回去了". Being out
## of reach is a property of the THREAT, not of the state the guard happens to be in.
func _worth_chasing(threat: Node3D) -> bool:
	return threat.global_position.distance_to(post_position) <= leash_radius

## Whether there is a way to `threat` on the raid's mesh: a man behind his own wall is not
## something to run at the wall about.
func _can_get_at(threat: Node3D) -> bool:
	var maps := _nav_maps()
	if maps == null or not maps.is_ready():
		return true
	return maps.is_reachable(global_position, threat.global_position, _map_kind())

func _is_threat_valid(threat: Variant) -> bool:
	if threat == null or typeof(threat) != TYPE_OBJECT or not is_instance_valid(threat):
		return false
	if not (threat is Node3D):
		return false
	if threat.is_queued_for_deletion():
		return false
	if not threat.visible:
		return false
	if "current_state" in threat and threat.is_in_group("hero") and int(threat.current_state) == 4: # Hero.State.DEAD
		return false
	if "is_destroyed" in threat and threat.is_destroyed:
		return false
	if "current_hp" in threat and threat.current_hp <= 0.0:
		return false
	return true

func _guards() -> Dictionary:
	var cfg = _get_config()
	return cfg.NEST_GUARDS if (cfg and "NEST_GUARDS" in cfg) else {}

## A guard's report says what a guard has in mind as well (TwitchWatch).
func debug_state() -> Dictionary:
	var s: Dictionary = super.debug_state()
	s["guard"] = {"state": String(GuardState.keys()[guard_state]), "post": _xz(post_position),
		"roam_target": _xz(roam_target), "chase": _describe(chase_target), "calm": snappedf(_calm, 0.01),
		"up_for": snappedf(_up_for, 0.01)}
	return s

## The run's dice (GameState.rng), or a throwaway set outside a run.
func _guard_dice() -> RandomNumberGenerator:
	return _dice()
