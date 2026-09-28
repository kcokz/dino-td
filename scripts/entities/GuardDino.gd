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
##   AGGRO_CHASE  after the Hero, or a building put up by the nest, along the mesh
##   ATTACKING    standing at it, biting -- letting go only past its reach (reach_release)
##   RETURNING    home, deaf to him on the way, and settling a moment once there
##                (reaggro_seconds) before it will start after anyone again
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
	RETURNING = 3
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

# ==============================================================================
# Lifecycle & Initialization
# ==============================================================================

func _init(p_type: String = "raptor") -> void:
	super(p_type)

func _ready() -> void:
	super._ready()
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
	if _is_paused():
		velocity = Vector3.ZERO
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

## The decisions that are not the frame's business: whether to start after somebody, whether to
## give up.
func _guard_think() -> void:
	_unstack()
	match guard_state:
		GuardState.POST_ROAM:
			var threat: Node3D = _detect_threat()
			if threat != null:
				_begin_chase(threat)
		GuardState.AGGRO_CHASE, GuardState.ATTACKING:
			if not _is_threat_valid(chase_target) or not _worth_chasing(chase_target) \
					or global_position.distance_to(post_position) > leash_radius \
					or not _can_get_at(chase_target):
				_go_home()

func _begin_chase(threat: Node3D) -> void:
	chase_target = threat
	current_target = threat
	guard_state = GuardState.AGGRO_CHASE
	current_state = State.WALKING
	_headway_clock = 0.0
	_headway_from = global_position
	_stuck_count = 0

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
	if _flat(global_position).distance_to(_flat(roam_target)) > _ai("target_desired_distance", 0.3):
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

## The run's dice (GameState.rng), or a throwaway set outside a run.
func _guard_dice() -> RandomNumberGenerator:
	return _dice()
